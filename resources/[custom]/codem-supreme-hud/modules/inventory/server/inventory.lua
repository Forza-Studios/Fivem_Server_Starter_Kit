--[[
    Server-Side Inventory Bridge
    Provides unified item operations across different inventory systems
]]

-- ═══════════════════════════════════════════════════════════════
-- INVENTORY BRIDGE
-- ═══════════════════════════════════════════════════════════════

ServerInventory = {}

local function GetInventoryType()
    return Config and Config.Inventory or 'qb'
end

-- ═══════════════════════════════════════════════════════════════
-- HAS ITEM
-- ═══════════════════════════════════════════════════════════════

function ServerInventory.HasItem(src, itemName, amount)
    if not src or src <= 0 then return false end
    if not itemName then return false end
    amount = amount or 1

    local inventory = GetInventoryType()
    local player = Core and Core.Functions and Core.Functions.GetPlayer(src)

    local handlers = {
        ox = function()
            local count = exports.ox_inventory:GetItemCount(src, itemName)
            return count >= amount
        end,
        qb = function()
            if not player then return false end
            local item = player.Functions.GetItemByName(itemName)
            return item and item.amount >= amount
        end,
        qs = function()
            local count = exports['qs-inventory']:GetItemTotalAmount(src, itemName)
            return count >= amount
        end,
        codem = function()
            local count = exports['codem-inventory']:GetItemCount(src, itemName)
            return count >= amount
        end,
        esx = function()
            local xPlayer = Core and Core.GetPlayerFromId and Core.GetPlayerFromId(src)
            if not xPlayer then return false end
            local item = xPlayer.getInventoryItem(itemName)
            return item and item.count >= amount
        end,
    }

    local handler = handlers[inventory]
    if handler then
        local ok, result = pcall(handler)
        if ok then return result end
    end

    -- Fallback to qb method
    if player and player.Functions and player.Functions.GetItemByName then
        local item = player.Functions.GetItemByName(itemName)
        return item and item.amount >= amount
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════
-- REMOVE ITEM
-- ═══════════════════════════════════════════════════════════════

function ServerInventory.RemoveItem(src, itemName, amount)
    if not src or src <= 0 then return false end
    if not itemName then return false end
    amount = amount or 1

    local inventory = GetInventoryType()
    local player = Core and Core.Functions and Core.Functions.GetPlayer(src)

    local handlers = {
        ox = function()
            return exports.ox_inventory:RemoveItem(src, itemName, amount)
        end,
        qb = function()
            if not player then return false end
            return player.Functions.RemoveItem(itemName, amount)
        end,
        qs = function()
            return exports['qs-inventory']:RemoveItem(src, itemName, amount)
        end,
        codem = function()
            return exports['codem-inventory']:RemoveItem(src, itemName, amount)
        end,
        esx = function()
            local xPlayer = Core and Core.GetPlayerFromId and Core.GetPlayerFromId(src)
            if not xPlayer then return false end
            xPlayer.removeInventoryItem(itemName, amount)
            return true
        end,
    }

    local handler = handlers[inventory]
    if handler then
        local ok, result = pcall(handler)
        if ok then return result end
    end

    -- Fallback to qb method
    if player and player.Functions and player.Functions.RemoveItem then
        return player.Functions.RemoveItem(itemName, amount)
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════
-- ADD ITEM
-- ═══════════════════════════════════════════════════════════════

function ServerInventory.AddItem(src, itemName, amount, metadata)
    if not src or src <= 0 then return false end
    if not itemName then return false end
    amount = amount or 1

    local inventory = GetInventoryType()
    local player = Core and Core.Functions and Core.Functions.GetPlayer(src)

    local handlers = {
        ox = function()
            return exports.ox_inventory:AddItem(src, itemName, amount, metadata)
        end,
        qb = function()
            if not player then return false end
            return player.Functions.AddItem(itemName, amount, nil, metadata)
        end,
        qs = function()
            return exports['qs-inventory']:AddItem(src, itemName, amount, nil, metadata)
        end,
        codem = function()
            return exports['codem-inventory']:AddItem(src, itemName, amount, metadata)
        end,
        esx = function()
            local xPlayer = Core and Core.GetPlayerFromId and Core.GetPlayerFromId(src)
            if not xPlayer then return false end
            xPlayer.addInventoryItem(itemName, amount, metadata)
            return true
        end,
    }

    local handler = handlers[inventory]
    if handler then
        local ok, result = pcall(handler)
        if ok then return result end
    end

    -- Fallback to qb method
    if player and player.Functions and player.Functions.AddItem then
        return player.Functions.AddItem(itemName, amount, nil, metadata)
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════
-- GET ITEM COUNT
-- ═══════════════════════════════════════════════════════════════

function ServerInventory.GetItemCount(src, itemName)
    if not src or src <= 0 then return 0 end
    if not itemName then return 0 end

    local inventory = GetInventoryType()
    local player = Core and Core.Functions and Core.Functions.GetPlayer(src)

    local handlers = {
        ox = function()
            return exports.ox_inventory:GetItemCount(src, itemName)
        end,
        qb = function()
            if not player then return 0 end
            local item = player.Functions.GetItemByName(itemName)
            return item and item.amount or 0
        end,
        qs = function()
            return exports['qs-inventory']:GetItemTotalAmount(src, itemName)
        end,
        codem = function()
            return exports['codem-inventory']:GetItemCount(src, itemName)
        end,
        esx = function()
            local xPlayer = Core and Core.GetPlayerFromId and Core.GetPlayerFromId(src)
            if not xPlayer then return 0 end
            local item = xPlayer.getInventoryItem(itemName)
            return item and item.count or 0
        end,
    }

    local handler = handlers[inventory]
    if handler then
        local ok, result = pcall(handler)
        if ok then return result or 0 end
    end

    -- Fallback to qb method
    if player and player.Functions and player.Functions.GetItemByName then
        local item = player.Functions.GetItemByName(itemName)
        return item and item.amount or 0
    end

    return 0
end

-- ═══════════════════════════════════════════════════════════════
-- CREATE USABLE ITEM
-- ═══════════════════════════════════════════════════════════════

function ServerInventory.CreateUsableItem(itemName, callback)
    if not itemName or not callback then return false end

    local inventory = GetInventoryType()

    local handlers = {
        ox = function()
            -- ox_inventory uses exports instead of usable items
            -- We handle this via ox_inventory:usingItem event
            exports.ox_inventory:registerHook('usingItem', function(payload)
                if payload.item.name == itemName then
                    callback(payload.source)
                end
            end)
            return true
        end,
        qb = function()
            if Core and Core.Functions and Core.Functions.CreateUseableItem then
                Core.Functions.CreateUseableItem(itemName, function(source)
                    callback(source)
                end)
                return true
            end
            return false
        end,
        qs = function()
            -- QS inventory uses QBCore usable items
            if Core and Core.Functions and Core.Functions.CreateUseableItem then
                Core.Functions.CreateUseableItem(itemName, function(source)
                    callback(source)
                end)
                return true
            end
            return false
        end,
        codem = function()
            if exports['codem-inventory'] and exports['codem-inventory'].CreateUsableItem then
                exports['codem-inventory']:CreateUsableItem(itemName, callback)
                return true
            end
            return false
        end,
        esx = function()
            if Core and Core.RegisterUsableItem then
                Core.RegisterUsableItem(itemName, function(playerId)
                    callback(playerId)
                end)
                return true
            end
            return false
        end,
    }

    local handler = handlers[inventory]
    if handler then
        local ok, result = pcall(handler)
        if ok and result then return true end
    end

    -- Fallback: try QBCore method
    if Core and Core.Functions and Core.Functions.CreateUseableItem then
        Core.Functions.CreateUseableItem(itemName, function(source)
            callback(source)
        end)
        return true
    end

    return false
end

ServerInventory.CreateUsableItem('wine', function(source)
    print('use wine')
end)

debugPrint('[Inventory] Server module loaded')
