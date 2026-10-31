--[[
    Vehicle Features Server: Nitro, Seatbelt sync
]]

local Cfg = Config.VehicleFeatures
local nitroCache = {}
local seatbeltStates = {}

-- NITRO SYSTEM
RPC.Register('vehicleFeatures:getNitroData', function(src, plate)
    if not plate then return { installed = false } end
    if nitroCache[plate] then return nitroCache[plate] end

    local result = MySQL.Sync.fetchScalar([[
        SELECT JSON_OBJECT('installed', true, 'level', level)
        FROM `codem_hud_vehicle_nitro` WHERE `plate` = ? LIMIT 1
    ]], { plate })

    if result then
        local data = json.decode(result)
        nitroCache[plate] = data
        return data
    end

    return { installed = false }
end)

RPC.Register('vehicleFeatures:useNitroKit', function(src, netId, plate, isAlreadyInstalled)
    if not netId or not plate then return { success = false, message = L('mods.invalid_vehicle') } end

    if not ServerInventory.HasItem(src, Cfg.Nitro.Item, 1) then
        return { success = false, message = L('mods.need_nitro_kit') }
    end

    if not ServerInventory.RemoveItem(src, Cfg.Nitro.Item, 1) then
        return { success = false, message = L('mods.nitro_use_failed') }
    end

    local newLevel = 100
    nitroCache[plate] = { installed = true, level = newLevel }

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and vehicle ~= 0 then
        local state = Entity(vehicle).state
        state.nitroInstalled = true
        state.nitroLevel = newLevel
    end

    MySQL.Async.execute([[
        INSERT INTO `codem_hud_vehicle_nitro` (`plate`, `level`, `updated_at`)
        VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE `level` = VALUES(`level`), `updated_at` = NOW()
    ]], { plate, newLevel })

    local message = isAlreadyInstalled and 'Nitro refilled!' or 'Nitro kit installed!'
    return { success = true, message = message, level = newLevel }
end)

RPC.Register('vehicleFeatures:syncNitroState', function(src, netId, isActive, level)
    if not netId then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and vehicle ~= 0 then
        local state = Entity(vehicle).state
        state.nitroActive = isActive
        state.nitroLevel = level

        local plate = GetVehicleNumberPlateText(vehicle)
        if plate and nitroCache[plate] then nitroCache[plate].level = level end
    end
end)

CreateThread(function()
    Wait(2000)
    if not Cfg.Nitro.Enabled then return end

    ServerInventory.CreateUsableItem(Cfg.Nitro.Item or 'nitro_kit', function(src)
        TriggerClientEvent('codem-hud:client:useNitroKit', src)
    end)
end)

-- SEATBELT SYSTEM
RPC.Register('vehicleFeatures:syncSeatbelt', function(src, isWearing)
    seatbeltStates[src] = isWearing

    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle and vehicle ~= 0 then
        local players = GetPlayers()
        -- Early exit if alone
        if #players <= 1 then return end

        for i = 1, #players do
            local targetId = tonumber(players[i])
            if targetId ~= src then
                local targetPed = GetPlayerPed(targetId)
                if GetVehiclePedIsIn(targetPed, false) == vehicle then
                    TriggerClientEvent('vehicleFeatures:receiveSeatbeltSync', targetId, src, isWearing)
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    seatbeltStates[source] = nil
end)

-- FLIR spotlight sync handled via entity state bags (no server events needed)

-- NEON DETECTION
-- Delegates to Core.Functions.GetVehicleNeonInstalled (defined per framework module)
-- Returns: true (installed), false (not installed), nil (not in DB = use client fallback)
RPC.Register('vehicleLights:checkNeonInstalled', function(src, plate)
    if not plate then return nil end
    if not Core or not Core.Functions or not Core.Functions.GetVehicleNeonInstalled then return nil end
    return Core.Functions.GetVehicleNeonInstalled(plate)
end)
