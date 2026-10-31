--[[
    Stress Relief - Item Usage Handler

    Supports all inventory systems.
    Loads the correct handler based on Config.Inventory.

    To add a new inventory:
    1. Add a new function to INVENTORY HANDLERS section
    2. Add it to the handlers table
]]

if not Config.Stress or not Config.Stress.Enabled then return end

-- ═══════════════════════════════════════════════════════════════
-- CORE HANDLER
-- ═══════════════════════════════════════════════════════════════

local function getRelief(itemName)
    if not itemName then return nil end
    local items = Config.Stress.Decrease and Config.Stress.Decrease.Items
    return items and items[itemName]
end

local function applyRelief(src, itemName)
    if not src or src <= 0 then return false end

    local relief = getRelief(itemName)
    if not relief then return false end

    TriggerClientEvent('codem-hud:client:RemoveStress', src, relief)
    debugPrint('[Stress] Item: ' .. itemName .. ' -> -' .. relief .. ' (player ' .. src .. ')')
    return true
end

-- Export
exports('ApplyItemStressRelief', applyRelief)

-- Generic event
RegisterNetEvent('codem-hud:server:ItemUsedForStress', function(itemName)
    applyRelief(source, itemName)
end)

-- ═══════════════════════════════════════════════════════════════
-- INVENTORY HANDLERS
-- ═══════════════════════════════════════════════════════════════

local handlers = {}

handlers.qb = function()
    local QBCore = exports['qb-core']:GetCoreObject()

    RegisterNetEvent('qb-inventory:server:useItem', function(item)
        local src = source
        if not item or not item.slot then return end
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        local itemData = Player.PlayerData.items[item.slot]
        if itemData and itemData.name then
            applyRelief(src, itemData.name)
        end
    end)
end

-- qs-inventory (works with QB, ESX, QBox)
handlers.qs = function()
    local framework = Config.Framework

    -- qs-inventory fires 'inventory:usedItem' when any item is used (UseItem.lua)
    AddEventHandler('inventory:usedItem', function(itemName, src, ...)
        if src and itemName then
            applyRelief(src, itemName)
        end
    end)

    if framework == 'esx' then
        RegisterNetEvent('esx:useItem', function(playerId, itemName)
            applyRelief(playerId, itemName)
        end)
    end
end

-- ox_inventory
handlers.ox = function()
    if GetResourceState('ox_inventory') ~= 'started' then return end

    pcall(function()
        exports.ox_inventory:registerHook('usingItem', function(payload)
            if payload and payload.source and payload.item then
                SetTimeout(100, function()
                    applyRelief(payload.source, payload.item.name)
                end)
            end
        end)
    end)
end

-- ESX
handlers.esx = function()
    RegisterNetEvent('esx:useItem', function(playerId, itemName)
        applyRelief(playerId, itemName)
    end)

    AddEventHandler('esx:onUseItem', function(playerId, itemName)
        applyRelief(playerId, itemName)
    end)
end

-- codem-inventory
handlers.codem = function()
    RegisterNetEvent('codem-inventory:server:useItem', function(itemName)
        applyRelief(source, itemName)
    end)

    AddEventHandler('codem-inventory:server:itemUsed', function(playerId, itemName)
        applyRelief(playerId, itemName)
    end)
end

-- tgiann-inventory (similar to ox_inventory)
handlers.tgiann = function()
    if GetResourceState('tgiann-inventory') ~= 'started' then return end

    -- Define event in tgiann item config
    -- client = { event = "codem-hud:server:ItemUsedForStress" }
end

-- ═══════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(1000)

    local inv = Config.Inventory
    if handlers[inv] then
        handlers[inv]()
    end
end)
