
local valveConfig = (type(Config) == "table" and Config.Valve and Config.Valve.engine) or {}
local sceneName = valveConfig.scene or "oxlyn_exhaust_valves"
local openGroup = valveConfig.openGroup or "oxlyn_valve_open"
local closedGroup = valveConfig.closedGroup or "oxlyn_valve_closed"

local trackedVehicles = {}
local activeAudioMix = {}
local activeScenes = {}
local isMixerLoaded = false
local isResourceStopping = false
local hasWarnedMixer = false

function IsValidNetId(netId)
    return type(netId) == "number" and netId == netId and netId >= 1
end

function IsCustomExhaust(exhaust)
    return type(exhaust) == "string" and exhaust ~= "stock"
end

function IsValidVehicle(entity)
    return DoesEntityExist(entity) and GetEntityType(entity) == 2
end

function CleanEntityMismatch(entity, data)
    local netId = data.netId
    local tracked = trackedVehicles[netId]
    if tracked and tracked.entity == entity and tracked.model == data.model then
        trackedVehicles[netId] = nil
    end
end

function RemoveVehicleAudioMix(entity)
    local mixData = activeAudioMix[entity]
    if mixData then
        if IsValidVehicle(entity) then
            RemoveEntityFromAudioMixGroup(entity, 0.0)
        end
        activeAudioMix[entity] = nil
    end
end

function UpdateTrackedState(netId, exhaust, closed, epoch, entityHandle, isAuthoritative)
    if not IsValidNetId(netId) then
        return
    end

    if epoch ~= nil and not PopsProtocol.Finite(epoch) then
        return
    end

    local existing = trackedVehicles[netId]
    local resolvedModel = nil

    if entityHandle and entityHandle ~= 0 and DoesEntityExist(entityHandle) and GetEntityType(entityHandle) == 2 and NetworkGetEntityIsNetworked(entityHandle) and VehToNet(entityHandle) == netId then
        resolvedModel = GetEntityModel(entityHandle)
        if existing and existing.entity and (existing.entity ~= entityHandle or existing.model ~= resolvedModel) then
            existing = nil
        end
    else
        entityHandle = nil
    end

    epoch = epoch or 0

    if existing and epoch < existing.epoch then
        return
    end

    if existing and existing.authoritative and not isAuthoritative and epoch == existing.epoch and existing.exhaust == exhaust and existing.closed == (closed == true) then
        return
    end

    local finalEntity = entityHandle or (existing and existing.entity)
    local finalModel = resolvedModel or (existing and existing.model)
    local finalAuthoritative = isAuthoritative or (existing and existing.epoch == epoch and existing.authoritative)

    trackedVehicles[netId] = {
        exhaust = exhaust,
        closed = (closed == true),
        epoch = epoch,
        received = GetGameTimer(),
        entity = finalEntity,
        model = finalModel,
        authoritative = finalAuthoritative
    }
end

function UpdateVehicleAudioMix(entity)
    local currentMix = activeAudioMix[entity]
    if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 or not NetworkGetEntityIsNetworked(entity) then
        if currentMix then
            CleanEntityMismatch(entity, currentMix)
            activeAudioMix[entity] = nil
        end
        return
    end

    local netId = VehToNet(entity)
    if not IsValidNetId(netId) then
        return
    end

    local entityModel = GetEntityModel(entity)
    if currentMix and (currentMix.netId ~= netId or currentMix.model ~= entityModel) then
        CleanEntityMismatch(entity, currentMix)
        activeAudioMix[entity] = nil
        currentMix = nil
    end

    local tracked = trackedVehicles[netId]
    if tracked and tracked.entity and (tracked.entity ~= entity or tracked.model ~= entityModel) then
        trackedVehicles[netId] = nil
        tracked = nil
    end

    if not tracked or not tracked.entity then
        local stateData = Entity(entity).state[Config.StateKey]
        if type(stateData) == "table" then
            if not tracked or (PopsProtocol.Finite(stateData.epoch) and stateData.epoch > tracked.epoch) then
                UpdateTrackedState(netId, stateData.exhaust, stateData.valveClosed, stateData.epoch, entity)
                tracked = trackedVehicles[netId]
            end
        end
    end

    if tracked then
        tracked.entity = entity
        tracked.model = entityModel
    end

    local engineValveEnabled = (valveConfig.enabled ~= false)
    if not (engineValveEnabled and isMixerLoaded and tracked and IsCustomExhaust(tracked.exhaust)) then
        if currentMix then
            RemoveVehicleAudioMix(entity)
        end
        return
    end

    local targetGroup = tracked.closed and closedGroup or openGroup
    local isEngineRunning = GetIsVehicleEngineRunning(entity)

    if currentMix and currentMix.group == targetGroup and (not isEngineRunning or currentMix.running) then
        currentMix.running = isEngineRunning
        return
    end

    local fadeTime = 0.0
    if currentMix then
        local configuredFade = tonumber(valveConfig.fadeSeconds) or 0.2
        fadeTime = math.max(0.0, math.min(2.0, configuredFade))
    end

    AddEntityToAudioMixGroup(entity, targetGroup, fadeTime)
    activeAudioMix[entity] = {
        netId = netId,
        model = entityModel,
        group = targetGroup,
        running = isEngineRunning
    }
end

RegisterNetEvent("oxlyn-popsbangs:syncResult", function(netId, level, epoch, antiLag, exhaust, closed, custom)
    if not IsValidNetId(netId) or not PopsProtocol.Finite(level) or (level ~= 0 and not Config.Levels[level]) or not PopsProtocol.Finite(epoch) then
        return
    end

    local vehicle = 0
    if NetworkDoesEntityExistWithNetworkId(netId) then
        vehicle = NetToVeh(netId) or 0
    end

    UpdateTrackedState(netId, exhaust, closed, epoch, vehicle, true)

    if vehicle ~= 0 then
        UpdateVehicleAudioMix(vehicle)
    end
end)

AddStateBagChangeHandler(Config.StateKey, nil, function(bagName, key, value)
    if type(bagName) ~= "string" then
        return
    end

    local netIdStr = bagName:match("^entity:(%d+)$")
    local netId = tonumber(netIdStr)
    if not IsValidNetId(netId) then
        return
    end

    local entity = GetEntityFromStateBagName(bagName)

    if type(value) == "table" then
        UpdateTrackedState(netId, value.exhaust, value.valveClosed, value.epoch, entity)
    else
        trackedVehicles[netId] = nil
        for handle, mix in pairs(activeAudioMix) do
            if mix.netId == netId then
                RemoveVehicleAudioMix(handle)
            end
        end
        return
    end

    if entity ~= 0 then
        UpdateVehicleAudioMix(entity)
    end
end)

CreateThread(function()
    if valveConfig.enabled == false then
        return
    end

    local timeoutAt = GetGameTimer() + 5000
    repeat
        local ok = StartAudioScene(sceneName)
        activeScenes[sceneName] = (ok == true)
        isMixerLoaded = activeScenes[sceneName]

        if not isMixerLoaded then
            Wait(250)
        end

        if isResourceStopping or isMixerLoaded then
            break
        end
    until GetGameTimer() >= timeoutAt

    if isResourceStopping then
        return
    end

    if not isMixerLoaded then
        for name, active in pairs(activeScenes) do
            if active then
                StopAudioScene(name)
            end
        end
        activeScenes = {}
        if not hasWarnedMixer then
            hasWarnedMixer = true
            print("[oxlyn-popsbangs] The valve mixer did not load; native engine sound kept.")
        end
        return
    end

    SetAudioSceneVariable(sceneName, "apply", 1.0)

    local nextCleanupAt = 0

    while not isResourceStopping do
        local now = GetGameTimer()

        if nextCleanupAt <= now then
            nextCleanupAt = now + 750

            for id, data in pairs(trackedVehicles) do
                if data.entity and not IsValidVehicle(data.entity) then
                    trackedVehicles[id] = nil
                end
            end

            for id, data in pairs(trackedVehicles) do
                local veh = data.entity
                if not veh or not DoesEntityExist(veh) then
                    if NetworkDoesEntityExistWithNetworkId(id) then
                        veh = NetToVeh(id) or 0
                    else
                        veh = 0
                    end
                end

                if veh ~= 0 and DoesEntityExist(veh) then
                    if not IsCustomExhaust(data.exhaust) or not activeAudioMix[veh] then
                        UpdateVehicleAudioMix(veh)
                    end
                else
                    if (now - data.received) > 5000 then
                        trackedVehicles[id] = nil
                    end
                end
            end
        end

        local ped = PlayerPedId()
        local currentVeh = GetVehiclePedIsIn(ped, false)
        UpdateVehicleAudioMix(currentVeh)

        local enteringVeh = GetVehiclePedIsTryingToEnter(ped)
        UpdateVehicleAudioMix(enteringVeh)

        for handle in pairs(activeAudioMix) do
            UpdateVehicleAudioMix(handle)
        end

        Wait(100)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    isResourceStopping = true

    for handle in pairs(activeAudioMix) do
        RemoveVehicleAudioMix(handle)
    end

    for name, active in pairs(activeScenes) do
        if active then
            StopAudioScene(name)
        end
    end

    activeAudioMix = {}
    trackedVehicles = {}
    isMixerLoaded = false
end)
--fivevault_N2OnakTopiD : https://discord.gg/fivevault
--fivevaulttXOnyKTopiD : https://discord.gg/fivevault
--fivevaultsYmOn9HTop#s : https://discord.gg/fivevault
--fivevaultpfOn_-Top8V : https://discord.gg/fivevault
--fivevaultsz8OniJTopIu : https://discord.gg/fivevault
