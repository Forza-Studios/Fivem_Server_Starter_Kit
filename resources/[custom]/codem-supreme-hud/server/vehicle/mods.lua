--[[
    Vehicle Mods Server
    Handles mod persistence and item removal
]]

if not Config.VehicleMods or not Config.VehicleMods.Enabled then return end

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════

-- Session cache (memory-only, resets on server restart)
local sessionCache = {}

-- ═══════════════════════════════════════════════════════════════
-- DATABASE HELPERS
-- ═══════════════════════════════════════════════════════════════

local function SaveToDatabase(plate, currentMod, installedMods)
    if not Config.VehicleMods.PersistMods then return end

    local modsJson = json.encode(installedMods)
    MySQL.Async.execute([[
        INSERT INTO `codem_hud_vehicle_mods` (`plate`, `current_mod`, `installed_mods`, `updated_at`)
        VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            `current_mod` = VALUES(`current_mod`),
            `installed_mods` = VALUES(`installed_mods`),
            `updated_at` = NOW()
    ]], { plate, currentMod, modsJson })
end

local function LoadFromDatabase(plate)
    if not Config.VehicleMods.PersistMods then return nil end

    local result = MySQL.Sync.fetchScalar([[
        SELECT JSON_OBJECT(
            'currentMod', current_mod,
            'installedMods', installed_mods
        ) FROM `codem_hud_vehicle_mods` WHERE `plate` = ? LIMIT 1
    ]], { plate })

    if result then
        local data = json.decode(result)
        if data and type(data.installedMods) == 'string' then
            data.installedMods = json.decode(data.installedMods)
        end
        return data
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- RPC HANDLERS
-- ═══════════════════════════════════════════════════════════════

-- Save mods for a vehicle
RPC.Register('vehicleMods:save', function(src, plate, currentMod, installedMods)
    if not plate then return false end

    -- Always save to session cache
    sessionCache[plate] = {
        currentMod = currentMod or 'comfort',
        installedMods = installedMods or { 'comfort' }
    }

    -- If PersistMods, also save to database
    if Config.VehicleMods.PersistMods then
        SaveToDatabase(plate, currentMod, installedMods)
    end

    return true
end)

-- Load mods for a vehicle
RPC.Register('vehicleMods:load', function(src, plate)
    if not plate then
        return { currentMod = 'comfort', installedMods = { 'comfort' } }
    end

    -- First check session cache
    if sessionCache[plate] then
        return sessionCache[plate]
    end

    -- If PersistMods, check database
    if Config.VehicleMods.PersistMods then
        local data = LoadFromDatabase(plate)
        if data then
            sessionCache[plate] = data
            return data
        end
    end

    -- Default values
    return { currentMod = 'comfort', installedMods = { 'comfort' } }
end)

-- Check if player has required items (without removing)
RPC.Register('vehicleMods:checkItems', function(src, mod)
    if not mod then return false end
    if mod ~= 'drift' and mod ~= 'sport' and mod ~= 'sport-plus' then return false end
    if not Config.VehicleMods.RequireItems then return true end

    local requiredItems = Config.VehicleMods.RequiredItems[mod]
    if not requiredItems then return true end

    for _, item in ipairs(requiredItems) do
        if not ServerInventory.HasItem(src, item.name, item.amount) then
            return false
        end
    end

    return true
end)

-- Remove items for mod installation
RPC.Register('vehicleMods:removeItems', function(src, mod)
    if not mod then return false end
    if mod ~= 'drift' and mod ~= 'sport' and mod ~= 'sport-plus' then return false end
    if not Config.VehicleMods.RequireItems then return true end

    local requiredItems = Config.VehicleMods.RequiredItems[mod]
    if not requiredItems then return true end

    -- Check if player has all items
    for _, item in ipairs(requiredItems) do
        if not ServerInventory.HasItem(src, item.name, item.amount) then
            return false
        end
    end

    -- Remove items that should be consumed
    for _, item in ipairs(requiredItems) do
        if item.remove then
            local success = ServerInventory.RemoveItem(src, item.name, item.amount)
            if not success then return false end
        end
    end

    return true
end)

debugPrint('[VehicleMods] Server module loaded')
