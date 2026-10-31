
PopsInventory = PopsInventory or {}

function GetInventoryType()
    local configured = (type(Config) == "table" and Config.Inventory) or "auto"
    if configured ~= "auto" then
        return configured
    end

    local oxState = GetResourceState("ox_inventory")
    if oxState == "started" or oxState == "starting" then
        return "ox"
    end

    local qsState = GetResourceState("qs-inventory")
    if qsState == "started" or qsState == "starting" then
        return "qs"
    end

    if GetResourceState("qb-inventory") == "started" or GetResourceState("ps-inventory") == "started" or GetResourceState("lj-inventory") == "started" then
        return "qb"
    end

    if GetResourceState("es_extended") == "started" then
        return "esx"
    end

    return "standalone"
end

function PopsInventory.AddItem(source, itemName, count)
    count = count or 1
    local ok, success = pcall(function()
        local invType = GetInventoryType()
        if invType == "ox" then
            local res = exports.ox_inventory:AddItem(source, itemName, count)
            return res ~= false
        elseif invType == "qb" then
            local player = PopsFramework.GetPlayer(source)
            if player and player.Functions and player.Functions.AddItem then
                return player.Functions.AddItem(itemName, count)
            end
        elseif invType == "qs" then
            return exports["qs-inventory"]:AddItem(source, itemName, count)
        elseif invType == "esx" then
            local player = PopsFramework.GetPlayer(source)
            if player and player.addInventoryItem then
                player.addInventoryItem(itemName, count)
                return true
            end
        end
        return true
    end)
    if not ok then
        print(("[oxlyn-popsbangs] Warning: AddItem('%s') failed: %s"):format(tostring(itemName), tostring(success)))
        return false
    end
    return success ~= false
end

function PopsInventory.RemoveItem(source, itemName, count)
    count = count or 1
    local ok, success = pcall(function()
        local invType = GetInventoryType()
        if invType == "ox" then
            local res = exports.ox_inventory:RemoveItem(source, itemName, count)
            return res ~= false
        elseif invType == "qb" then
            local player = PopsFramework.GetPlayer(source)
            if player and player.Functions and player.Functions.RemoveItem then
                return player.Functions.RemoveItem(itemName, count)
            end
        elseif invType == "qs" then
            return exports["qs-inventory"]:RemoveItem(source, itemName, count)
        elseif invType == "esx" then
            local player = PopsFramework.GetPlayer(source)
            if player and player.removeInventoryItem then
                player.removeInventoryItem(itemName, count)
                return true
            end
        end
        return true
    end)
    if not ok then
        print(("[oxlyn-popsbangs] Warning: RemoveItem('%s') failed: %s"):format(tostring(itemName), tostring(success)))
        return false
    end
    return success ~= false
end

function PopsInventory.HasItem(source, itemName, count)
    count = count or 1
    local ok, has = pcall(function()
        local invType = GetInventoryType()
        if invType == "ox" then
            local itemCount = exports.ox_inventory:GetItemCount(source, itemName)
            return (itemCount or 0) >= count
        elseif invType == "qb" then
            local player = PopsFramework.GetPlayer(source)
            if player and player.Functions and player.Functions.GetItemByName then
                local item = player.Functions.GetItemByName(itemName)
                return item and (item.amount or item.count or 0) >= count
            end
        elseif invType == "qs" then
            local itemCount = exports["qs-inventory"]:GetItemTotalAmount(source, itemName)
            return (itemCount or 0) >= count
        elseif invType == "esx" then
            local player = PopsFramework.GetPlayer(source)
            if player and player.getInventoryItem then
                local item = player.getInventoryItem(itemName)
                return item and (item.count or 0) >= count
            end
        end
        return true
    end)
    if not ok then
        print(("[oxlyn-popsbangs] Warning: HasItem('%s') failed: %s"):format(tostring(itemName), tostring(has)))
        return false
    end
    return has == true
end

function RegisterAllUsableItems()
    local itemsToRegister = {}

    local itemsCfg = (type(Config) == "table" and Config.Items) or {}
    if itemsCfg.antiLagKit then
        itemsToRegister[itemsCfg.antiLagKit] = "workshop"
    end
    if itemsCfg.antiLagRemover then
        itemsToRegister[itemsCfg.antiLagRemover] = "workshop"
    end

    local valveCfg = (type(Config) == "table" and Config.Valve) or {}
    if valveCfg.item then
        itemsToRegister[valveCfg.item] = "valve"
    end

    local exhaustsCfg = (type(Config) == "table" and Config.Exhausts) or {}
    for _, exhaustData in pairs(exhaustsCfg) do
        if exhaustData.item then
            itemsToRegister[exhaustData.item] = "workshop"
        end
    end

    for itemName, itemType in pairs(itemsToRegister) do
        if GetResourceState("es_extended") == "started" then
            local ok, ESX = pcall(function() return exports["es_extended"]:getSharedObject() end)
            if ok and ESX and ESX.RegisterUsableItem then
                ESX.RegisterUsableItem(itemName, function(source)
                    if itemType == "valve" then
                        TriggerClientEvent("oxlyn-popsbangs:useValve", source)
                    else
                        TriggerClientEvent("oxlyn-popsbangs:useItem", source, itemName)
                    end
                end)
            end
        end

        local invType = GetInventoryType()
        if invType == "qb" and GetResourceState("qb-core") == "started" then
            local ok, QBCore = pcall(function() return exports["qb-core"]:GetCoreObject() end)
            if ok and QBCore and QBCore.Functions and QBCore.Functions.CreateUseableItem then
                QBCore.Functions.CreateUseableItem(itemName, function(source)
                    if itemType == "valve" then
                        TriggerClientEvent("oxlyn-popsbangs:useValve", source)
                    else
                        TriggerClientEvent("oxlyn-popsbangs:useItem", source, itemName)
                    end
                end)
            end
        elseif invType == "qs" and GetResourceState("qs-inventory") == "started" then
            exports["qs-inventory"]:CreateUsableItem(itemName, function(source)
                if itemType == "valve" then
                    TriggerClientEvent("oxlyn-popsbangs:useValve", source)
                else
                    TriggerClientEvent("oxlyn-popsbangs:useItem", source, itemName)
                end
            end)
        end
    end
end

CreateThread(function()
    Wait(1000)
    RegisterAllUsableItems()
end)
--fivevault-G0OnuHTopB8 : https://discord.gg/fivevault
--fivevaultsvzOnh5TopG# : https://discord.gg/fivevault
--fivevault-PZOn4eTopx4 : https://discord.gg/fivevault
--fivevaultsiSOnkmTop#X : https://discord.gg/fivevault
--fivevaultPwOnNoTopew : https://discord.gg/fivevault
