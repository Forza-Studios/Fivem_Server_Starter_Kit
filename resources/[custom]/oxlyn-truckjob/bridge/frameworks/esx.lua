local ESX_Bridge = {}
local ESX = nil

function ESX_Bridge.init()
    if GetResourceState("es_extended") ~= "started" then
        return
    end
    ESX = exports.es_extended:getSharedObject()
end

-- Shared helper: does an inventory count satisfy the requested amount?
local function enough(have, required)
    return (tonumber(have) or 0) >= (required or 1)
end

if IsDuplicityVersion() then
    -----------------------------------------------------------------------
    -- SERVER
    -----------------------------------------------------------------------

    function ESX_Bridge.GetPlayer(source)
        if not ESX then
            return
        end
        return ESX.GetPlayerFromId(source)
    end

    function ESX_Bridge.GetIdentifier(source)
        local player = ESX_Bridge.GetPlayer(source)
        return player and player.identifier
    end

    function ESX_Bridge.GetJob(source)
        local player = ESX_Bridge.GetPlayer(source)
        return player and player.job and player.job.name
    end

    -- NOTE: argument order is (job, source), unlike most other functions.
    function ESX_Bridge.HasJob(job, source)
        return ESX_Bridge.GetJob(source) == job
    end

    function ESX_Bridge.GetName(source)
        local player = ESX_Bridge.GetPlayer(source)
        return (player and player.getName and player.getName()) or ("Player#" .. source)
    end

    function ESX_Bridge.AddMoney(source, account, amount)
        local player = ESX_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        if account == "cash" or account == "money" then
            player.addMoney(amount)
        else
            player.addAccountMoney(account, amount)
        end
        return true
    end

    function ESX_Bridge.RemoveMoney(source, account, amount)
        local player = ESX_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        if account == "cash" or account == "money" then
            player.removeMoney(amount)
        else
            player.removeAccountMoney(account, amount)
        end
        return true
    end

    -- Checks ak47_inventory, then ox_inventory, then ESX's built-in inventory.
    function ESX_Bridge.HasItem(source, item, count)
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

        local player = ESX_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        local invItem = player.getInventoryItem(item)
        return invItem and (invItem.count or 0) >= (count or 1) or false
    end

    function ESX_Bridge.RemoveItem(source, item, count)
        count = count or 1

        local player = ESX_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        local invItem = player.getInventoryItem(item)
        if not (invItem and count <= (invItem.count or 0)) then
            return false
        end

        player.removeInventoryItem(item, count)
        return true
    end

    function ESX_Bridge.HasLicense(source, license)
        local player = ESX_Bridge.GetPlayer(source)
        if not player then
            return false
        end

        if TriggerEvent and exports.esx_license then
            local hasLicense = false
            local ok = pcall(function()
                exports.esx_license:checkLicense(source, license, function(result)
                    hasLicense = result or false
                end)
            end)
            if ok then
                return hasLicense
            end
        end

        return false
    end

    function ESX_Bridge.RegisterUsableItem(item, callback)
        if not ESX then
            return
        end
        ESX.RegisterUsableItem(item, callback)
    end

    function ESX_Bridge.Notify(source, message, type, duration)
        TriggerClientEvent("esx:showNotification", source, message)
    end
else
    -----------------------------------------------------------------------
    -- CLIENT
    -----------------------------------------------------------------------

    function ESX_Bridge.GetJob()
        if not ESX then
            return nil
        end

        local data = ESX.GetPlayerData()
        return data and data.job and data.job.name
    end

    function ESX_Bridge.HasJob(job)
        return ESX_Bridge.GetJob() == job
    end

    -- First argument (source) is unused on the client.
    function ESX_Bridge.HasItem(_, item, count)
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

        if not ESX then
            return false
        end

        local data = ESX.GetPlayerData()
        for _, invItem in pairs(data.inventory or {}) do
            if invItem.name == item and (invItem.count or 0) >= (count or 1) then
                return true
            end
        end
        return false
    end

    function ESX_Bridge.Notify(_, message)
        if ESX and ESX.ShowNotification then
            ESX.ShowNotification(message)
        end
    end
end

Bridge.Register("esx", ESX_Bridge)