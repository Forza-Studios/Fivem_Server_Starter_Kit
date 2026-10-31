--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║                      SYSTEM BRIDGES                           ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  Connects HUD with different inventory and lock scripts       ║
    ╚═══════════════════════════════════════════════════════════════╝

    ═══════════════════════════════════════════════════════════════
    ADDING YOUR OWN INVENTORY:
    ═══════════════════════════════════════════════════════════════

    InventoryBridge['your-inventory'] = {
        GetItemCount = function(itemName)
            return exports['your-inventory']:GetCount(itemName) or 0
        end,
        GetMarkedBillsWorth = function(itemName)
            -- Return total worth of all markedbills items
            return 0
        end
    }

    Then set Config.Inventory = 'your-inventory' in config.lua

    ═══════════════════════════════════════════════════════════════
    ADDING YOUR OWN LOCK SCRIPT:
    ═══════════════════════════════════════════════════════════════

    LockBridge['your-locks'] = {
        ToggleLock = function(vehicle)
            exports['your-locks']:Toggle(vehicle)
        end
    }

    Then set Config.VehiclePanel.LockScript = 'your-locks' in config.lua
]]

-- ═══════════════════════════════════════════════════════════════
-- INVENTORY BRIDGES
-- ═══════════════════════════════════════════════════════════════
-- Each bridge has:
--   GetItemCount(itemName) - Returns item count
--   GetItems(itemName) - Returns array of items with metadata (optional)

InventoryBridge = {}

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
-- Get sum of a metadata value across all items with given name
-- If item has no metadata or key doesn't exist, falls back to count
--
-- Usage:
--   GetItemMetadataSum('markedbills', 'worth')     -> sum of all item.info.worth
--   GetItemMetadataSum('markedbills', 'worth', 'metadata') -> sum of item.metadata.worth
--   GetItemMetadataSum('phone')                    -> count (no metadata key)
--
-- @param itemName string - Item name to search
-- @param metaKey string|nil - Key inside metadata (e.g., 'worth', 'value', 'amount')
-- @param metaType string|nil - 'info', 'metadata', or nil for auto-detect
-- @return number - Total sum or count

function GetItemMetadataSum(itemName, metaKey, metaType)
    local bridge = InventoryBridge[Config.Inventory]
    if not bridge then return 0 end

    -- If no metaKey specified, just return item count
    if not metaKey then
        return bridge.GetItemCount and bridge.GetItemCount(itemName) or 0
    end

    -- Get items and calculate sum
    if bridge.GetItems then
        local items = bridge.GetItems(itemName)
        if not items or #items == 0 then return 0 end

        -- Auto-detect metadata type if not specified
        if not metaType then
            local metadataInventories = { ox = true, tgiann = true }
            metaType = metadataInventories[Config.Inventory] and 'metadata' or 'info'
        end

        local total = 0
        for _, item in pairs(items) do
            if item then
                local meta = item[metaType]
                if meta and meta[metaKey] then
                    total = total + (tonumber(meta[metaKey]) or 0)
                end
            end
        end

        -- If no metadata found, fall back to count
        return total > 0 and total or #items
    end

    -- Fallback to count if GetItems not available
    return bridge.GetItemCount and bridge.GetItemCount(itemName) or 0
end

-- Shared helper: Get items from QBCore-style playerData
local function GetItemsFromPlayerData(itemName)
    if not (Core and Core.Functions and Core.Functions.GetPlayerData) then return {} end
    local playerData = Core.Functions.GetPlayerData()
    if not (playerData and playerData.items) then return {} end
    local result = {}
    for _, item in pairs(playerData.items) do
        if item and item.name == itemName then
            result[#result + 1] = item
        end
    end
    return result
end

-- Shared helper: Count items from playerData (used by QBCore-style inventories)
local function CountItemsFromPlayerData(itemName)
    local items = GetItemsFromPlayerData(itemName)
    local total = 0
    for _, item in pairs(items) do
        total = total + (item.amount or 1)
    end
    return total
end

-- ox_inventory
-- https://overextended.dev/ox_inventory/Functions/Client#search
InventoryBridge['ox'] = {
    GetItemCount = function(itemName)
        local ok, count = pcall(exports.ox_inventory.Search, exports.ox_inventory, 'count', itemName)
        return ok and count or 0
    end,
    GetItems = function(itemName)
        local ok, items = pcall(exports.ox_inventory.Search, exports.ox_inventory, 'slots', itemName)
        return ok and items or {}
    end
}

-- qb-inventory
-- https://docs.qbcore.org/qbcore-documentation/qbcore-resources/qb-inventory
InventoryBridge['qb'] = {
    GetItemCount = function(itemName)
        -- Sum all items with this name across all slots
        if not (Core and Core.Functions and Core.Functions.GetPlayerData) then return 0 end
        local playerData = Core.Functions.GetPlayerData()
        if not (playerData and playerData.items) then return 0 end
        local total = 0
        for _, item in pairs(playerData.items) do
            if item and item.name == itemName then
                total = total + (item.amount or 1)
            end
        end
        return total
    end,
    GetItems = GetItemsFromPlayerData
}

-- esx default inventory
InventoryBridge['esx'] = {
    GetItemCount = function(itemName)
        if not (Core and Core.GetPlayerData) then return 0 end
        local playerData = Core.GetPlayerData()
        if not (playerData and playerData.inventory) then return 0 end
        for _, item in ipairs(playerData.inventory) do
            if item.name == itemName then return item.count or 0 end
        end
        return 0
    end,
    GetItems = function(itemName)
        if not (Core and Core.GetPlayerData) then return {} end
        local playerData = Core.GetPlayerData()
        if not (playerData and playerData.inventory) then return {} end
        local result = {}
        for _, item in ipairs(playerData.inventory) do
            if item.name == itemName then
                result[#result + 1] = item
            end
        end
        return result
    end
}

-- qs-inventory (uses QBCore-style playerData)
-- https://docs.quasar-store.com/assets-and-usage/inventory
InventoryBridge['qs'] = {
    GetItemCount = CountItemsFromPlayerData,
    GetItems = GetItemsFromPlayerData
}

-- codem-inventory (uses QBCore-style playerData)
InventoryBridge['codem'] = {
    GetItemCount = CountItemsFromPlayerData,
    GetItems = GetItemsFromPlayerData
}

-- tgiann-inventory
-- https://docs.tgiann.com/scripts/tgiann-inventory/exports/client
InventoryBridge['tgiann'] = {
    GetItemCount = function(itemName)
        local ok, has = pcall(exports['tgiann-inventory'].HasItem, exports['tgiann-inventory'], itemName, 1)
        return (ok and has) and 1 or 0
    end,
    GetItems = function(itemName)
        local ok, items = pcall(exports['tgiann-inventory'].GetItemsByName, exports['tgiann-inventory'], itemName)
        return ok and items or {}
    end
}

-- ═══════════════════════════════════════════════════════════════
-- VEHICLE LOCK BRIDGES
-- ═══════════════════════════════════════════════════════════════
-- Note: IsLocked uses native GetVehicleDoorLockStatus(vehicle)
-- These bridges only need ToggleLock function

LockBridge = {}

-- ┌─────────────────────────────────────────────────────────────┐
-- │ qb-vehiclekeys                                              │
-- │ Uses server event to toggle lock state                      │
-- │ GitHub: qbcore-framework/qb-vehiclekeys                     │
-- └─────────────────────────────────────────────────────────────┘
LockBridge['qb-vehiclekeys'] = {
    ToggleLock = function(vehicle)
        -- Standard qb-vehiclekeys uses an event
        TriggerEvent('qb-vehiclekeys:client:ToggleVehicleLocks')
    end
}

-- ┌─────────────────────────────────────────────────────────────┐
-- │ wasabi_carlock                                              │
-- │ Export: exports.wasabi_carlock:ToggleLock()                │
-- │ Docs: docs.wasabiscripts.com                               │
-- └─────────────────────────────────────────────────────────────┘
LockBridge['wasabi_carlock'] = {
    ToggleLock = function(vehicle)
        pcall(exports.wasabi_carlock.ToggleLock, exports.wasabi_carlock)
    end
}


-- ┌─────────────────────────────────────────────────────────────┐
-- │ Renewed-Vehiclekeys                                         │
-- │ Uses state bags for lock state                              │
-- │ Docs: renewed.dev/key/exports                              │
-- └─────────────────────────────────────────────────────────────┘
LockBridge['Renewed-Vehiclekeys'] = {
    ToggleLock = function(vehicle)
        local currentState = GetVehicleDoorLockStatus(vehicle)
        local newLock = (currentState == 2) and 1 or 2
        Entity(vehicle).state:set('vehicleLock', { lock = newLock, sound = true }, true)
    end
}

-- ┌─────────────────────────────────────────────────────────────┐
-- │ mk_vehiclekeys (ManKind)                                    │
-- │ Export: exports["mk_vehiclekeys"]:ToggleLocks(vehicle)     │
-- │ Docs: mankind-scripts.gitbook.io                           │
-- └─────────────────────────────────────────────────────────────┘
LockBridge['mk_vehiclekeys'] = {
    ToggleLock = function(vehicle)
        pcall(exports['mk_vehiclekeys'].ToggleLocks, exports['mk_vehiclekeys'], vehicle)
    end
}

-- ┌─────────────────────────────────────────────────────────────┐
-- │ vehicles_keys (jaksam's Vehicles Keys)                     │
-- │ Export: exports["vehicles_keys"]:toggleClosestVehicleLock()│
-- │ Docs: documentation.jaksam-scripts.com                     │
-- └─────────────────────────────────────────────────────────────┘
LockBridge['vehicles_keys'] = {
    ToggleLock = function(vehicle)
        pcall(exports['vehicles_keys'].toggleClosestVehicleLock, exports['vehicles_keys'])
    end
}

-- ┌─────────────────────────────────────────────────────────────┐
-- │ qs-vehiclekeys (Quasar Store)                               │
-- │ Export: exports["qs-vehiclekeys"]:DoorLogic(vehicle, ...)  │
-- │ Docs: docs.quasar-store.com/scripts/vehiclekeys             │
-- └─────────────────────────────────────────────────────────────┘
LockBridge['qs-vehiclekeys'] = {
    ToggleLock = function(vehicle)
        local currentState = exports['qs-vehiclekeys']:GetDoorState(vehicle)
        local newState = (currentState == 2) and 1 or 2
        pcall(exports['qs-vehiclekeys'].DoorLogic, exports['qs-vehiclekeys'], vehicle, false, newState, false, false, false)
    end
}
