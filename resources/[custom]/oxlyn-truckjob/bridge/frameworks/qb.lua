local QB_Bridge = {}
local QBCore = nil

-- Reason string passed to QBCore money functions (leftover resource name).
local MONEY_REASON = "oxlyn-truckjob"

function QB_Bridge.init()
    if GetResourceState("qb-core") ~= "started" then
        return
    end
    QBCore = exports["qb-core"]:GetCoreObject()
end

-- Does an inventory count satisfy the requested amount?
local function enough(have, required)
    return (tonumber(have) or 0) >= (required or 1)
end

if IsDuplicityVersion() then
    -----------------------------------------------------------------------
    -- SERVER
    -----------------------------------------------------------------------

    function QB_Bridge.GetPlayer(source)
        if QBCore then
            return QBCore.Functions.GetPlayer(source)
        end
    end

    function QB_Bridge.GetIdentifier(source)
        local player = QB_Bridge.GetPlayer(source)
        return player and player.PlayerData and player.PlayerData.citizenid
    end

    function QB_Bridge.GetJob(source)
        local player = QB_Bridge.GetPlayer(source)
        return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name
    end

    -- NOTE: argument order is (job, source), unlike most other functions.
    function QB_Bridge.HasJob(job, source)
        return QB_Bridge.GetJob(source) == job
    end

    function QB_Bridge.GetJobGrade(source)
        local player = QB_Bridge.GetPlayer(source)
        local job = player and player.PlayerData and player.PlayerData.job
        local grade = job and job.grade
        return (grade and grade.level) or 0
    end

    function QB_Bridge.GetName(source)
        local player = QB_Bridge.GetPlayer(source)
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

    -- QB uses "cash" where other bridges use "money".
    local function qbAccount(account)
        return account == "money" and "cash" or account
    end

    function QB_Bridge.AddMoney(source, account, amount)
        local player = QB_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        player.Functions.AddMoney(qbAccount(account), amount, MONEY_REASON)
        return true
    end

    function QB_Bridge.RemoveMoney(source, account, amount)
        local player = QB_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        return player.Functions.RemoveMoney(qbAccount(account), amount, MONEY_REASON) and true or false
    end

    -- Checks ak47_inventory, then ox_inventory, then QBCore's built-in inventory.
    function QB_Bridge.HasItem(source, item, count)
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

        local player = QB_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        local invItem = player.Functions.GetItemByName(item)
        if invItem then
            return (invItem.amount or invItem.count or 0) >= (count or 1)
        end
        return invItem
    end

    function QB_Bridge.RemoveItem(source, item, count)
        count = count or 1

        local player = QB_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        local invItem = player.Functions.GetItemByName(item)
        if not (invItem and count <= (invItem.amount or invItem.count or 0)) then
            return false
        end

        local ok, removed = pcall(function()
            return player.Functions.RemoveItem(item, count)
        end)
        if not ok or removed == false then
            return false
        end

        -- Show the "item removed" box on the client (best effort)
        pcall(function()
            local sharedItem = QBCore and QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[item]
            if sharedItem then
                TriggerClientEvent("qb-inventory:client:ItemBox", source, sharedItem, "remove", count)
            end
        end)

        return true
    end

    function QB_Bridge.HasLicense(source, license)
        local player = QB_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        local metadata = player.PlayerData and player.PlayerData.metadata
        local licenses = metadata and (metadata.licences or metadata.licenses) or {}
        return licenses[license] == true
    end

    function QB_Bridge.RegisterUsableItem(item, callback)
        if not QBCore then
            return
        end
        QBCore.Functions.CreateUseableItem(item, callback)
    end

    function QB_Bridge.Notify(source, message, type, duration)
        TriggerClientEvent("QBCore:Notify", source, message, type or "primary", duration or 5000)
    end
else
    -----------------------------------------------------------------------
    -- CLIENT
    -----------------------------------------------------------------------

    function QB_Bridge.GetJob()
        if not QBCore then
            return nil
        end

        local data = QBCore.Functions.GetPlayerData()
        return data and data.job and data.job.name
    end

    function QB_Bridge.HasJob(job)
        return QB_Bridge.GetJob() == job
    end

    -- First argument (source) is unused on the client.
    function QB_Bridge.HasItem(_, item, count)
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

        if not QBCore then
            return false
        end

        local data = QBCore.Functions.GetPlayerData()
        for _, invItem in pairs(data.items or {}) do
            if invItem.name == item and (invItem.amount or 0) >= (count or 1) then
                return true
            end
        end
        return false
    end

    function QB_Bridge.HasLicense(_, license)
        if not QBCore then
            return false
        end

        local data = QBCore.Functions.GetPlayerData()
        local metadata = (data and data.metadata) or {}
        local licenses = metadata.licences or metadata.licenses or {}
        return licenses[license] == true
    end

    function QB_Bridge.Notify(_, message, type, duration)
        TriggerEvent("QBCore:Notify", message, type or "primary", duration or 5000)
    end
end

Bridge.Register("qb", QB_Bridge)