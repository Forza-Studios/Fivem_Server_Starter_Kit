
local playerInstallCooldowns = {}
local playerSyncCooldowns = {}

function GetVehiclePlate(vehicle)
    if not DoesEntityExist(vehicle) then
        return ""
    end
    local plate = GetVehicleNumberPlateText(vehicle)
    return (type(plate) == "string" and plate:gsub("^%s*(.-)%s*$", "%1")) or ""
end

function GetPersistenceKey(plate, model)
    return string.format("pops:%s:%s", tostring(plate), tostring(model))
end

function LoadPersistedTune(plate, model)
    if not Config.Persistence or plate == "" then
        return nil
    end
    local raw = GetResourceKvpString(GetPersistenceKey(plate, model))
    if type(raw) == "string" and raw ~= "" then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == "table" then
            return data
        end
    end
    return nil
end

function SavePersistedTune(plate, model, tuneData)
    if not Config.Persistence or plate == "" then
        return
    end
    if tuneData then
        SetResourceKvp(GetPersistenceKey(plate, model), json.encode(tuneData))
    else
        DeleteResourceKvp(GetPersistenceKey(plate, model))
    end
end

function GetVehicleTune(vehicle)
    if not DoesEntityExist(vehicle) then
        return nil
    end

    local stateData = Entity(vehicle).state[Config.StateKey]
    if type(stateData) == "table" then
        return stateData
    end

    local plate = GetVehiclePlate(vehicle)
    local model = GetEntityModel(vehicle)
    local persisted = LoadPersistedTune(plate, model)
    if persisted then
        Entity(vehicle).state:set(Config.StateKey, persisted, true)
        return persisted
    end

    return {
        level = 0,
        epoch = 1,
        antiLag = false,
        exhaust = "stock",
        valveClosed = false
    }
end

function SetVehicleTune(vehicle, newTuneData)
    if not DoesEntityExist(vehicle) then
        return
    end

    local current = GetVehicleTune(vehicle)
    local epoch = ((current and current.epoch) or 0) + 1

    local tune = {
        level = (newTuneData.level ~= nil and newTuneData.level) or (current and current.level) or 0,
        epoch = epoch,
        antiLag = (newTuneData.antiLag ~= nil and newTuneData.antiLag) or (current and current.antiLag) or false,
        exhaust = (newTuneData.exhaust ~= nil and newTuneData.exhaust) or (current and current.exhaust) or "stock",
        valveClosed = (newTuneData.valveClosed ~= nil and newTuneData.valveClosed) or (current and current.valveClosed) or false
    }

    Entity(vehicle).state:set(Config.StateKey, tune, true)

    local plate = GetVehiclePlate(vehicle)
    local model = GetEntityModel(vehicle)
    SavePersistedTune(plate, model, tune)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerClientEvent("oxlyn-popsbangs:syncResult", -1, netId, tune.level, tune.epoch, 0, tune.antiLag, tune.exhaust, tune.valveClosed)
end

RegisterCommand(Config.Command, function(source, args, rawCommand)
    if source ~= 0 and not PopsFramework.HasPermission(source) then
        PopsFramework.Notify(source, L("no_permission"), "error")
        return
    end

    local ped = (source ~= 0 and GetPlayerPed(source)) or nil
    if not ped then
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        PopsFramework.Notify(source, L("need_driver"), "error")
        return
    end

    local levelArg = tonumber(args[1])
    if not levelArg or levelArg < 0 or (levelArg > 0 and not Config.Levels[levelArg]) then
        PopsFramework.Notify(source, L("invalid_level"), "error")
        return
    end

    SetVehicleTune(vehicle, { level = levelArg })

    if levelArg == 0 then
        PopsFramework.Notify(source, L("tune_removed"), "success")
    else
        local levelName = Config.Levels[levelArg].name or tostring(levelArg)
        PopsFramework.Notify(source, L("tune_installed", levelName), "success")
    end
end, false)

if Config.AntiLag and Config.AntiLag.command then
    RegisterCommand(Config.AntiLag.command, function(source, args, rawCommand)
        if source ~= 0 and not PopsFramework.HasPermission(source) then
            PopsFramework.Notify(source, L("no_permission"), "error")
            return
        end

        local ped = (source ~= 0 and GetPlayerPed(source)) or nil
        if not ped then
            return
        end

        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
            PopsFramework.Notify(source, L("need_driver"), "error")
            return
        end

        local currentTune = GetVehicleTune(vehicle)
        local newAntiLag = not (currentTune and currentTune.antiLag)
        SetVehicleTune(vehicle, { antiLag = newAntiLag })

        if newAntiLag then
            PopsFramework.Notify(source, L("antilag_installed"), "success")
        else
            PopsFramework.Notify(source, L("antilag_removed"), "success")
        end
    end, false)
end

RegisterNetEvent("oxlyn-popsbangs:install", function(netId, level)
    local src = source
    if not PopsProtocol.Integer(netId, 1, 65535) or not PopsProtocol.Integer(level, 0, 9) then
        return
    end

    local now = GetGameTimer()
    local lastInstall = playerInstallCooldowns[src] or 0
    local minCooldown = Config.InstallCooldownMs or 600
    if (now - lastInstall) < minCooldown then
        return
    end
    playerInstallCooldowns[src] = now

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then
        return
    end

    SetVehicleTune(vehicle, { level = level })
end)

RegisterNetEvent("oxlyn-popsbangs:installAntiLag", function(netId, enabled)
    local src = source
    if not PopsProtocol.Integer(netId, 1, 65535) then
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then
        return
    end

    SetVehicleTune(vehicle, { antiLag = (enabled == true) })
end)

RegisterNetEvent("oxlyn-popsbangs:sync", function(netId)
    local src = source
    if not PopsProtocol.Integer(netId, 1, 65535) then
        return
    end

    local now = GetGameTimer()
    local lastSync = playerSyncCooldowns[src] or 0
    local minCooldown = Config.SyncCooldownMs or 2000
    if (now - lastSync) < minCooldown then
        return
    end
    playerSyncCooldowns[src] = now

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then
        return
    end

    local tune = GetVehicleTune(vehicle)
    if tune then
        TriggerClientEvent("oxlyn-popsbangs:syncResult", src, netId, tune.level, tune.epoch, 0, tune.antiLag, tune.exhaust, tune.valveClosed)
    end
end)

RegisterNetEvent("oxlyn-popsbangs:burst", function(burstPacket)
    local src = source
    if type(burstPacket) ~= "table" or not PopsProtocol.Integer(burstPacket.netId, 1, 65535) then
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(burstPacket.netId)
    if not DoesEntityExist(vehicle) then
        return
    end

    local vehCoords = GetEntityCoords(vehicle)
    local maxDist = Config.VisualDistance or 150.0

    for _, playerId in ipairs(GetPlayers()) do
        local targetSrc = tonumber(playerId)
        if targetSrc ~= src then
            local targetPed = GetPlayerPed(targetSrc)
            if DoesEntityExist(targetPed) then
                local playerCoords = GetEntityCoords(targetPed)
                if #(vehCoords - playerCoords) <= maxDist then
                    TriggerClientEvent("oxlyn-popsbangs:play", targetSrc, burstPacket)
                end
            end
        end
    end
end)

RegisterNetEvent("oxlyn-popsbangs:cut", function(netId, epoch, sequence, delay)
    local src = source
    if not PopsProtocol.Integer(netId, 1, 65535) then
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then
        return
    end

    local vehCoords = GetEntityCoords(vehicle)
    local maxDist = Config.VisualDistance or 150.0

    for _, playerId in ipairs(GetPlayers()) do
        local targetSrc = tonumber(playerId)
        if targetSrc ~= src then
            local targetPed = GetPlayerPed(targetSrc)
            if DoesEntityExist(targetPed) then
                local playerCoords = GetEntityCoords(targetPed)
                if #(vehCoords - playerCoords) <= maxDist then
                    TriggerClientEvent("oxlyn-popsbangs:cut", targetSrc, netId, epoch, sequence, delay)
                end
            end
        end
    end
end)

RegisterNetEvent("oxlyn-popsbangs:als", function(alsPacket)
    local src = source
    if type(alsPacket) ~= "table" or not PopsProtocol.Integer(alsPacket.netId, 1, 65535) then
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(alsPacket.netId)
    if not DoesEntityExist(vehicle) then
        return
    end

    local vehCoords = GetEntityCoords(vehicle)
    local maxDist = Config.VisualDistance or 150.0

    for _, playerId in ipairs(GetPlayers()) do
        local targetSrc = tonumber(playerId)
        if targetSrc ~= src then
            local targetPed = GetPlayerPed(targetSrc)
            if DoesEntityExist(targetPed) then
                local playerCoords = GetEntityCoords(targetPed)
                if #(vehCoords - playerCoords) <= maxDist then
                    TriggerClientEvent("oxlyn-popsbangs:als", targetSrc, alsPacket)
                end
            end
        end
    end
end)
--fivevaultsAwOnTHTopiK : https://discord.gg/fivevault
--fivevaultsFuOnP0TopWF : https://discord.gg/fivevault
--fivevault__TOnj6Top89 : https://discord.gg/fivevault
--fivevault_bUOnyoTopv# : https://discord.gg/fivevault
--fivevaultsZ9Ono-Topj! : https://discord.gg/fivevault
