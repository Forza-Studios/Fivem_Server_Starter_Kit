local Qbox_Bridge = {}

-- Reason string passed to money functions (leftover resource name).
local MONEY_REASON = "oxlyn-truckjob"

-- Qbox exposes everything through exports, so there is nothing to cache here.
function Qbox_Bridge.init()
    if GetResourceState("qbx_core") ~= "started" then
        return
    end
end

-- Does an inventory count satisfy the requested amount?
local function enough(have, required)
    return (tonumber(have) or 0) >= (required or 1)
end

-- QB uses "cash" where other bridges use "money".
local function qbAccount(account)
    return account == "money" and "cash" or account
end

if IsDuplicityVersion() then
    -----------------------------------------------------------------------
    -- SERVER
    -----------------------------------------------------------------------

    function Qbox_Bridge.GetPlayer(source)
        return exports.qbx_core:GetPlayer(source)
    end

    function Qbox_Bridge.GetIdentifier(source)
        local player = Qbox_Bridge.GetPlayer(source)
        return player and player.PlayerData and player.PlayerData.citizenid
    end

    function Qbox_Bridge.GetJob(source)
        local player = Qbox_Bridge.GetPlayer(source)
        return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name
    end

    -- NOTE: argument order is (job, source), unlike most other functions.
    function Qbox_Bridge.HasJob(job, source)
        return Qbox_Bridge.GetJob(source) == job
    end

    function Qbox_Bridge.GetJobGrade(source)
        local player = Qbox_Bridge.GetPlayer(source)
        local job = player and player.PlayerData and player.PlayerData.job
        local grade = job and job.grade
        return (grade and grade.level) or 0
    end

    function Qbox_Bridge.GetName(source)
        local player = Qbox_Bridge.GetPlayer(source)
        if not player then
            return ("Player#%s"):format(source)
        end

        local charinfo = player.PlayerData.charinfo or {}
        local name = (charinfo.firstname or "") .. " " .. (charinfo.lastname or "")
        name = name:gsub("^%s+", ""):gsub("%s+$", "")

        if name == "" then
            return ("Player#%s"):format(source)
        end
        return name
    end

    function Qbox_Bridge.AddMoney(source, account, amount)
        account = qbAccount(account)

        -- Preferred: player object method
        local player = Qbox_Bridge.GetPlayer(source)
        if player and player.Functions and player.Functions.AddMoney then
            local ok = pcall(player.Functions.AddMoney, account, amount, MONEY_REASON)
            if ok then
                return true
            end
        end

        -- Fallback: qbx_core export
        local ok = pcall(function()
            exports.qbx_core:AddMoney(source, account, amount, MONEY_REASON)
        end)
        return ok
    end

    function Qbox_Bridge.RemoveMoney(source, account, amount)
        account = qbAccount(account)

        -- Preferred: player object method
        local player = Qbox_Bridge.GetPlayer(source)
        if player and player.Functions and player.Functions.RemoveMoney then
            local ok, result = pcall(player.Functions.RemoveMoney, account, amount, MONEY_REASON)
            if ok then
                return result and true or false
            end
        end

        -- Fallback: qbx_core export
        local ok, result = pcall(function()
            return exports.qbx_core:RemoveMoney(source, account, amount, MONEY_REASON)
        end)
        return (ok and result) and true or false
    end

    -- Checks ak47_inventory, then ox_inventory, then the Qbox player object.
    function Qbox_Bridge.HasItem(source, item, count)
        if GetResourceState("ak47_inventory") == "started" then
            local ok, result = pcall(function()
                return exports.ak47_inventory:GetItemCount(source, item)
            end)
            if ok and result ~= nil then
                return enough(result, count)
            end

            local ok2, result2 = pcall(function()
                return exports.ak47_inventory:GetAmount(source, item)
            end)
            if ok2 then
                return enough(result2, count)
            end
        end

        if GetResourceState("ox_inventory") == "started" then
            local have = exports.ox_inventory:GetItemCount(source, item) or 0
            return have >= (count or 1)
        end

        local player = Qbox_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        local ok, invItem = pcall(function()
            return player.Functions
                and player.Functions.GetItemByName
                and player.Functions.GetItemByName(item)
        end)

        if ok and invItem then
            return (invItem.amount or invItem.count or 0) >= (count or 1)
        end
        return false
    end

    function Qbox_Bridge.RemoveItem(source, item, count)
        count = count or 1

        if not Qbox_Bridge.HasItem(source, item, count) then
            return false
        end

        local player = Qbox_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        local ok, removed = pcall(function()
            return player.Functions
                and player.Functions.RemoveItem
                and player.Functions.RemoveItem(item, count)
        end)

        return (ok and removed) and true or false
    end

    function Qbox_Bridge.HasLicense(source, license)
        local player = Qbox_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        local metadata = player.PlayerData and player.PlayerData.metadata
        local licenses = metadata and (metadata.licences or metadata.licenses) or {}
        return licenses[license] == true
    end

    -- Tries qbx_core first; otherwise registers with whichever inventory is running.
    function Qbox_Bridge.RegisterUsableItem(item, callback)
        local ok = pcall(function()
            exports.qbx_core:CreateUseableItem(item, callback)
        end)
        if ok then
            return
        end

        if GetResourceState("ak47_inventory") == "started" then
            pcall(function()
                exports.ak47_inventory:CreateUsableItem(item, callback)
            end)
            pcall(function()
                exports.ak47_inventory:RegisterUsableItem(item, callback)
            end)
        end

        if GetResourceState("ox_inventory") == "started" then
            pcall(function()
                exports.ox_inventory:RegisterUsableItem(item, callback)
            end)
        end
    end

    function Qbox_Bridge.Notify(source, message, type, duration)
        local ok = pcall(function()
            exports.qbx_core:Notify(source, message, type or "inform", duration or 5000)
        end)

        if not ok then
            TriggerClientEvent("QBCore:Notify", source, message, type or "primary", duration or 5000)
        end
    end
else
    -----------------------------------------------------------------------
    -- CLIENT
    -----------------------------------------------------------------------

    function Qbox_Bridge.GetJob()
        local data = exports.qbx_core:GetPlayerData()
        return data and data.job and data.job.name
    end

    function Qbox_Bridge.HasJob(job)
        return Qbox_Bridge.GetJob() == job
    end

    -- First argument (source) is unused on the client.
    function Qbox_Bridge.HasItem(_, item, count)
        if GetResourceState("ak47_inventory") == "started" then
            local ok, result = pcall(function()
                return exports.ak47_inventory:Search("count", item)
            end)
            if ok and result ~= nil then
                return enough(result, count)
            end
        end

        if GetResourceState("ox_inventory") == "started" then
            local have = exports.ox_inventory:Search("count", item) or 0
            return have >= (count or 1)
        end

        local data = exports.qbx_core:GetPlayerData()
        for _, invItem in pairs(data.items or {}) do
            if invItem.name == item and (invItem.amount or 0) >= (count or 1) then
                return true
            end
        end
        return false
    end

    function Qbox_Bridge.HasLicense(_, license)
        local data = exports.qbx_core:GetPlayerData()
        local metadata = (data and data.metadata) or {}
        local licenses = metadata.licences or metadata.licenses or {}
        return licenses[license] == true
    end

    function Qbox_Bridge.Notify(_, message, type, duration)
        if GetResourceState("ox_lib") == "started" and lib and lib.notify then
            lib.notify({
                description = message,
                type = type or "inform",
                duration = duration or 5000,
            })
        else
            TriggerEvent("QBCore:Notify", message, type or "primary", duration or 5000)
        end
    end
end

Bridge.Register("qbox", Qbox_Bridge)