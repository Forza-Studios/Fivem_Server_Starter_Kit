
local EVENT_PREFIX = "oxlyn-popsbangs:"

local localVehicle = {
    vehicle = 0,
    netId = 0,
    level = 0,
    epoch = 0,
    antiLag = false,
    tune = nil,
    valveClosed = false,
    exhaust = nil
}

local cancelledEpochs = {}
local activeBursts = {}
local predictedBursts = {}
local cancelledBursts = {}
local burstCutoffs = {}

local lastListenerEnv = { at = -100000 }
local lastCamPushAt = -100000
local lastFrameCount = -1
local activeAudioDeadline = 0

local stateAntiLagVehicles = {}
local activeTurboVehicles = {}
local stateExhaustVehicles = {}
local lastSyncResult = nil

local vehicleHeatSoak = {}
local lastPedReactionAt = -100000
local cachedAcousticRooms = {}
local cachedEngineProfiles = {}
local alarmTriggeredVehicles = {}
local cachedCabin = { at = -100000, value = 0.0 }
local cachedRain = { at = -100000, rain = 0.0 }
local lastVehicleContext = nil
local exhaustTicksState = nil

local PushListenerToNUI = nil
local ProbeListenerEnvironment = nil

local telemetry = PopsTelemetry.New()
local antiLag = PopsAntiLag.New()

local activeAntiLagVehicles = {}
local antiLagDeadlines = {}
local activeEmitters = {}

local lastAntiLagAt = -10000
local localAntiLagSequence = 0
local localAntiLagMode = "off"
local EmitLocalAntiLagState = nil

local uiReady = false
local resourceStopping = false
local lastInstallCommandAt = -10000
local lastLocalBurstAt = -10000
local maxBurstSequence = 0

local isPlaybackThreadRunning = false
local lastBurstPlaybackTime = nil

local IsFinite = PopsProtocol.Finite
local TimeDifference = PopsProtocol.Difference

function GetAccurateNetworkTime()
    return GetNetworkTimeAccurate() % 4294967296
end

function CloneVector3(vec)
    return {
        x = vec.x + 0.0,
        y = vec.y + 0.0,
        z = vec.z + 0.0
    }
end

function GetDistance3D(v1, v2)
    local dx = v1.x - v2.x
    local dy = v1.y - v2.y
    local dz = v1.z - v2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function StoreVehicleSoak(netId, telemInstance)
    if netId == 0 or type(telemInstance) ~= "table" or not IsFinite(telemInstance.soak) then
        return
    end

    local now = GetGameTimer()
    for id, data in pairs(vehicleHeatSoak) do
        if TimeDifference(now, data.at) > 130000 then
            vehicleHeatSoak[id] = nil
        end
    end

    vehicleHeatSoak[netId] = {
        soak = telemInstance.soak,
        at = now
    }
end

function GetVehicleDecayedSoak(netId)
    local data = vehicleHeatSoak[netId]
    if not data then
        return nil
    end

    local elapsedSec = TimeDifference(GetGameTimer(), data.at) / 1000
    local decayRate = 0.008 * PopsTelemetry.Heat("coolDown", 1)
    local remaining = data.soak - (elapsedSec * decayRate)
    return math.max(0.0, remaining)
end

function ShowNotification(message, kind, title)
    local uiCfg = type(Config.UI) == "table" and Config.UI or {}
    if uiCfg.notifications ~= "framework" and uiReady then
        SendNUIMessage({
            action = "notify",
            message = message,
            kind = kind or "info",
            title = title
        })
        return
    end

    PopsFramework.Notify(message, kind)
end

function CancelBurst(burstId, futureOnly, serverCut, serverTime)
    local burst = activeBursts[burstId]
    cancelledBursts[burstId] = GetGameTimer() + 5000
    activeBursts[burstId] = nil

    local cutTime = serverTime or GetAccurateNetworkTime()
    local cutoffDelay = TimeDifference(cutTime, GetAccurateNetworkTime()) + (burstCutoffs[burstId] or 0)

    SendNUIMessage({
        action = "cancelBurst",
        burstId = burstId,
        futureOnly = (futureOnly == true),
        cutoffDelayMs = cutoffDelay
    })

    if not futureOnly then
        PopsFlames.CancelBurst(burstId)
    end

    if serverCut and burst and burst.predicted then
        TriggerServerEvent(
            EVENT_PREFIX .. "cut",
            burst.packet.netId,
            burst.packet.epoch,
            burst.packet.sequence,
            cutTime
        )
    end
end

function CancelVehicleState(netId, epoch)
    if not IsFinite(netId) or not IsFinite(epoch) then
        return
    end

    local currentCancelled = cancelledEpochs[netId] or 0
    if epoch < currentCancelled then
        return
    end

    cancelledEpochs[netId] = epoch

    for burstId, burst in pairs(activeBursts) do
        if burst.packet.netId == netId then
            activeBursts[burstId] = nil
        end
    end

    PopsFlames.Cancel(netId)

    activeAntiLagVehicles[netId] = nil
    antiLagDeadlines[netId] = nil
    activeEmitters[netId] = nil

    SendNUIMessage({
        action = "cancel",
        vehicle = netId,
        epoch = epoch
    })

    if localVehicle.netId == netId then
        localVehicle.level = 0
        localVehicle.epoch = epoch
        localVehicle.antiLag = false
        localVehicle.tune = nil

        telemetry = PopsTelemetry.New(telemetry.soak)
        antiLag = PopsAntiLag.New()
        localAntiLagMode = "off"
    end
end

function SyncLocalVehicle(vehicle, netId)
    if localVehicle.vehicle == vehicle and localVehicle.netId == netId then
        return
    end

    if EmitLocalAntiLagState and localVehicle.netId ~= 0 and localAntiLagMode ~= "off" then
        EmitLocalAntiLagState({
            mode = "off",
            rpm = 0,
            load = 0,
            boost = 0,
            temperature = 0.3,
            phaseMs = 0,
            seed = 1
        }, true)
    end

    for burstId, burst in pairs(activeBursts) do
        if burst.predicted then
            CancelBurst(burstId, true, true)
        end
    end

    StoreVehicleSoak(localVehicle.netId, telemetry)

    if localVehicle.vehicle ~= 0 and localVehicle.tune then
        lastVehicleContext = {
            vehicle = localVehicle.vehicle,
            netId = localVehicle.netId,
            soak = telemetry.soak or 0.0,
            model = GetEntityModel(localVehicle.vehicle)
        }
    end

    localVehicle = {
        vehicle = vehicle,
        netId = netId,
        level = 0,
        epoch = 0,
        antiLag = false
    }

    lastLocalBurstAt = -10000
    telemetry = PopsTelemetry.New(GetVehicleDecayedSoak(netId))
    antiLag = PopsAntiLag.New()
    localAntiLagMode = "off"
    lastAntiLagAt = -10000
end

function FormatLevelsList()
    local parts = { L("help_remove") }
    for i = 1, PopsProtocol.MaxLevel() do
        parts[#parts + 1] = tostring(i)
    end
    return table.concat(parts, " | ")
end

function GetExhaustPoints(vehicle)
    local points = {}
    local overrides = Config.ExhaustOverrides[GetEntityModel(vehicle)]
    if overrides then
        for _, offset in ipairs(overrides) do
            points[#points + 1] = { offset = offset }
            if #points >= Config.MaxExhausts then
                break
            end
        end
    else
        for i = 1, 16 do
            local boneName = (i == 1) and "exhaust" or ("exhaust_" .. i)
            local bone = GetEntityBoneIndexByName(vehicle, boneName)
            if bone ~= -1 then
                points[#points + 1] = { bone = bone }
            end
            if #points >= Config.MaxExhausts then
                break
            end
        end
    end

    if #points == 0 then
        local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
        local defaultZ = minDim.z + math.max(0.15, (maxDim.z - minDim.z) * 0.16)
        points[1] = {
            offset = {
                x = minDim.x * 0.55,
                y = minDim.y + 0.08,
                z = defaultZ
            }
        }
    end

    return points
end

function GetWorldCoordOfExhaustPoint(vehicle, point)
    if point.bone then
        return GetWorldPositionOfEntityBone(vehicle, point.bone)
    end

    local offset = point.offset
    return GetOffsetFromEntityInWorldCoords(vehicle, offset.x, offset.y, offset.z)
end

function ResolveNetworkVehicle(packet)
    if not NetworkDoesEntityExistWithNetworkId(packet.netId) then
        return 0
    end

    local veh = NetToVeh(packet.netId)
    if veh ~= 0 and DoesEntityExist(veh) and GetEntityModel(veh) == packet.model then
        return veh
    end

    return 0
end

function GetExhaustPositionAndDirection(vehicle, points, index)
    local pt = points[index or 1] or points[1]
    local pos = CloneVector3(GetWorldCoordOfExhaustPoint(vehicle, pt))
    local offset = pt.offset or {}
    local dir = offset.direction

    if not dir then
        dir = {
            x = 0,
            y = offset.reversed and 1 or -1,
            z = 0
        }
    end

    if not IsFinite(dir.x) or not IsFinite(dir.y) or not IsFinite(dir.z) then
        dir = { x = 0, y = -1, z = 0 }
    end

    local p0 = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 0.0, 0.0)
    local p1 = GetOffsetFromEntityInWorldCoords(vehicle, dir.x, dir.y, dir.z)
    local dx = p1.x - p0.x
    local dy = p1.y - p0.y
    local dz = p1.z - p0.z
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)

    local normalizedDir = { x = 0, y = -1, z = 0 }
    if len > 0.001 then
        normalizedDir = {
            x = dx / len,
            y = dy / len,
            z = dz / len
        }
    end

    return pos, normalizedDir
end

function GetEngineBayWorldCoords(vehicle)
    for _, boneName in ipairs({ "engine", "bonnet" }) do
        local bone = GetEntityBoneIndexByName(vehicle, boneName)
        if bone ~= -1 then
            return CloneVector3(GetWorldPositionOfEntityBone(vehicle, bone))
        end
    end

    local _, maxDim = GetModelDimensions(GetEntityModel(vehicle))
    return CloneVector3(GetOffsetFromEntityInWorldCoords(vehicle, 0.0, maxDim.y * 0.6, 0.2))
end

function TriggerPopFeedback(vehicle, pulse, exhaustCoord)
    local feedback = Config.Feedback
    if type(feedback) ~= "table" then
        return
    end

    local playerPed = PlayerPedId()
    local isInVehicle = (GetVehiclePedIsIn(playerPed, false) == vehicle)
    local isBoom = (pulse.kind == "boom")
    local intensity = math.min(1.5, pulse.energy or 0.7) * (isBoom and 1.0 or 0.55)

    if not isInVehicle then
        local distance = GetDistance3D(GetEntityCoords(playerPed), exhaustCoord)
        if not isBoom or distance > 7.0 then
            return
        end
        intensity = intensity * (1.0 - (distance / 7.0)) * 0.6
    end

    if feedback.cameraShake ~= false then
        local shakeFactor = IsFinite(feedback.shake) and feedback.shake or 1.0
        ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 0.045 * intensity * shakeFactor)
    end

    if isInVehicle and feedback.padRumble ~= false then
        local rumbleFreq = math.floor(70 + (90 * intensity))
        local rumbleAmp = math.floor(math.min(255, 70 + (150 * intensity)))
        SetPadShake(0, rumbleFreq, rumbleAmp)
    end
end

function TriggerPedReactions(vehicle, exhaustCoord)
    local reactions = Config.Reactions
    if type(reactions) ~= "table" or reactions.peds == false then
        return
    end

    local now = GetGameTimer()
    if TimeDifference(now, lastPedReactionAt) < (reactions.cooldownMs or 1500) then
        return
    end

    lastPedReactionAt = now
    local playerPed = PlayerPedId()
    local radius = reactions.radius or 16.0
    local maxPeds = reactions.maxPeds or 6
    local affected = 0

    for _, ped in ipairs(GetGamePool("CPed")) do
        if affected >= maxPeds then
            break
        end

        if ped ~= playerPed and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) then
            if not NetworkGetEntityIsNetworked(ped) or NetworkHasControlOfEntity(ped) then
                if GetDistance3D(GetEntityCoords(ped), exhaustCoord) <= radius then
                    TaskLookAtEntity(ped, vehicle, 1500 + math.random(0, 1200), 2048, 3)
                    affected = affected + 1
                end
            end
        end
    end
end

local materialProperties = {
    hard = { hard = 0.92, bright = 1.0 },
    metal = { hard = 0.7, bright = 1.1 },
    wood = { hard = 0.6, bright = 0.6 },
    soft = { hard = 0.22, bright = 0.35 },
    mesh = { hard = 0.08, bright = 0.8 },
    car = { hard = 0.55, bright = 0.8 },
    water = { hard = 0.75, bright = 0.9 },
    unknown = { hard = 0.75, bright = 0.85 }
}

local materialClassMap = {}
local materialHashCategories = {
    hard = {
        1187676648, 359120722, -1084640111, 282940568, -1301352528, 1886546517, -250168275, -954996747,
        -840216541, -124769592, 765206029, 576169331, 1639053622, 1945073303, 1907048430, 592446772,
        1913209870, -1447280105, -365631240, 752131025, -231260695, -1186320815, 1253270487, -1961571829,
        -956672144, 937503243, 244521486, 1500272081, -1619794068, 1501078253, -1374519069, -1878502447,
        -1476768434, 289630530, 1845676458
    },
    metal = {
        15972667, 1849540536, -583213831, 834144982, 1761524221, -754997699, -1449526186, -1942140720,
        -2020616806, 627123000, 1211430374
    },
    mesh = {
        762193613, 125958708, -426118011, 2100727187, -1497291657, -1597011207, -1401016191
    },
    wood = {
        -399872228, 555004797, 815762359, 119014683, -1797384978, -1266389285, 1686812334, 722686013,
        -1904565532, -1444687652, 1091834564
    },
    soft = {
        -1595148316, 510490462, 909950165, -1907520769, 509508168, 1288448767, 951832588, 2128369009,
        -356706482, 1925605558, -1885547121, -1942898710, 312396330, 1635937914, 1109728704, 223086562,
        1584636462, -700658213, 1144315879, 560985072, -461750719, 1333033863, -1286696947, -1833527165,
        581794674, -913351839, -2041329971, -309121453, -1915425863, -1263620742, -1396780265, -1897374661,
        -1553013689, -1491532413, -1296727959, 122789469, 236511221, -1021797786, 474149820, 808719444,
        1341866303, -1796017732, -1363042296, -1937569590, -878560889, 1619704960, 1550304810, -786060715,
        -1931024423
    },
    car = {
        -93061983, 2137197282, -979647862, 2130571536, 1247281098, 602884284, 1070994698, -1721915930, 513061559
    },
    water = { 435688960 }
}

for category, hashes in pairs(materialHashCategories) do
    for _, hash in ipairs(hashes) do
        materialClassMap[hash] = category
    end
end

function GetMaterialCategory(materialHash)
    if type(materialHash) ~= "number" or materialHash ~= materialHash then
        return "unknown"
    end

    if materialHash >= 2147483648 then
        materialHash = materialHash - 4294967296
    end

    return materialClassMap[math.floor(materialHash)] or "unknown"
end

function ProbeAcousticSpace(origin, ignoreEntity, includeWalls)
    local probeZ = origin.z + 0.6
    local maxDistance = 45.0
    local hitCount = 0
    local totalWeight = 0.0
    local minDistance = 45.0
    local distances = {}
    local walls = includeWalls and {} or nil

    for i = 0, 7 do
        local angle = (i * math.pi) / 4
        local cosA = math.cos(angle)
        local sinA = math.sin(angle)

        local handle = StartExpensiveSynchronousShapeTestLosProbe(
            origin.x, origin.y, probeZ,
            origin.x + (cosA * maxDistance),
            origin.y + (sinA * maxDistance),
            probeZ,
            81, ignoreEntity, 4
        )

        local retval, hit, endCoords, surfaceNormal, materialHash = GetShapeTestResult(handle)
        if hit == 1 or hit == true then
            local hitDist = math.sqrt((endCoords.x - origin.x) ^ 2 + (endCoords.y - origin.y) ^ 2)
            local matType = GetMaterialCategory(materialHash)
            if matType ~= "mesh" then
                hitCount = hitCount + 1
                totalWeight = totalWeight + (1.0 - (hitDist / maxDistance))
                minDistance = math.min(minDistance, hitDist)
                distances[i] = hitDist
            end

            if walls and hitDist >= 1.5 and hitDist < 42.0 then
                local matProp = materialProperties[matType]
                walls[#walls + 1] = {
                    a = i,
                    d = hitDist,
                    h = matProp.hard,
                    b = matProp.bright,
                    t = 0,
                    m = materialHash,
                    x = endCoords.x + 0.0,
                    y = endCoords.y + 0.0,
                    z = endCoords.z + 0.0,
                    dx = cosA,
                    dy = sinA
                }
            end
        end
    end

    if walls and #walls > 0 then
        table.sort(walls, function(a, b)
            return a.d < b.d
        end)

        local maxWalls = math.min(4, #walls)
        for i = 1, maxWalls do
            local wall = walls[i]
            for _, heightOffset in ipairs({ 9.0, 18.0 }) do
                local handle = StartExpensiveSynchronousShapeTestLosProbe(
                    origin.x, origin.y, probeZ + heightOffset,
                    wall.x + (wall.dx * 3.0),
                    wall.y + (wall.dy * 3.0),
                    probeZ + heightOffset,
                    81, ignoreEntity, 4
                )
                local retval, hit, endCoords = GetShapeTestResult(handle)
                if hit ~= 1 and hit ~= true then
                    break
                end

                local hDist = math.sqrt((endCoords.x - origin.x) ^ 2 + (endCoords.y - origin.y) ^ 2)
                if hDist > (wall.d - 3.0) then
                    wall.t = wall.t + 1
                else
                    break
                end
            end
        end
    end

    local roofHits = 0
    local roofHeights = {}
    local roofOffsets = {
        { 0.0, 0.0 },
        { 9.0, 0.0 },
        { -9.0, 0.0 },
        { 0.0, 9.0 },
        { 0.0, -9.0 }
    }

    for _, offset in ipairs(roofOffsets) do
        local handle = StartExpensiveSynchronousShapeTestLosProbe(
            origin.x, origin.y, probeZ,
            origin.x + offset[1],
            origin.y + offset[2],
            probeZ + 22.0,
            1, ignoreEntity, 7
        )
        local retval, hit, endCoords = GetShapeTestResult(handle)
        if hit == 1 or hit == true then
            roofHits = roofHits + 1
            roofHeights[#roofHeights + 1] = math.max(0.5, endCoords.z - probeZ)
        end
    end

    local corridorWidth = 2 * maxDistance
    local corridorLength = 0.0
    for i = 0, 3 do
        local oppositeDist = (distances[i] or maxDistance) + (distances[i + 4] or maxDistance)
        corridorWidth = math.min(corridorWidth, oppositeDist)
        corridorLength = math.max(corridorLength, oppositeDist)
    end

    local ceilingHeight = 0.0
    if roofHits >= 4 then
        table.sort(roofHeights)
        local medianIdx = math.ceil(#roofHeights / 2)
        ceilingHeight = roofHeights[medianIdx] + 1.6
    end

    local enclosure = math.min(1.0, ((hitCount / 8) * 0.45) + ((totalWeight / 8) * 0.95))

    return {
        enclosure = enclosure,
        roof = (roofHits >= 4) and 1.0 or 0.0,
        nearest = minDistance,
        height = ceilingHeight,
        width = corridorWidth,
        length = corridorLength,
        walls = walls
    }
end

function FormatWallReflections(walls)
    if type(walls) ~= "table" then
        return nil
    end

    local formatted = {}
    for _, wall in ipairs(walls) do
        formatted[#formatted + 1] = {
            angle = wall.a,
            distance = wall.d,
            hard = wall.h,
            bright = wall.b,
            tall = wall.t
        }
    end
    return formatted
end

function GetVehicleAcousticRoom(netId, vehicle, timeMs)
    local audioCfg = Config.Audio
    if audioCfg.reverb == false or audioCfg.sourceRooms == false then
        return nil
    end

    local cached = cachedAcousticRooms[netId]
    if cached and TimeDifference(timeMs, cached.at) < 900 then
        return cached.env
    end

    local vehCoords = GetEntityCoords(vehicle)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local room = nil

    if GetDistance3D(vehCoords, playerCoords) >= 12.0 then
        local probe = ProbeAcousticSpace(vehCoords, vehicle, false)
        local speedOfSound = Config.Audio.speedOfSound or 343.0
        local wallDelay = math.max(8, math.min(250, ((2 * probe.nearest) / speedOfSound) * 1000))

        room = {
            enclosure = probe.enclosure,
            roof = probe.roof,
            height = probe.height,
            width = probe.width,
            length = probe.length,
            interior = (GetInteriorFromEntity(vehicle) ~= 0),
            wallMs = wallDelay
        }

        if room.interior then
            room.enclosure = math.max(room.enclosure, 0.8)
            room.roof = 1.0
        end
    end

    for id, data in pairs(cachedAcousticRooms) do
        if TimeDifference(timeMs, data.at) > 5000 then
            cachedAcousticRooms[id] = nil
        end
    end

    cachedAcousticRooms[netId] = {
        at = timeMs,
        env = room
    }

    return room
end

function CalculateOcclusion(vehicle, exhaustCoord)
    if Config.Audio.occlusion == false then
        local hasLos = HasEntityClearLosToEntity(PlayerPedId(), vehicle, 17)
        return hasLos and 0.0 or 1.0
    end

    local camCoord = GetFinalRenderedCamCoord()
    local _, maxDim = GetModelDimensions(GetEntityModel(vehicle))

    local probePoints = {
        exhaustCoord,
        GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 0.0, maxDim.z),
        GetOffsetFromEntityInWorldCoords(vehicle, 0.0, maxDim.y, 0.2)
    }

    local hits = 0
    for _, pt in ipairs(probePoints) do
        local handle = StartExpensiveSynchronousShapeTestLosProbe(
            camCoord.x, camCoord.y, camCoord.z,
            pt.x, pt.y, pt.z,
            1, vehicle, 7
        )
        local retval, hit = GetShapeTestResult(handle)
        if hit == 1 or hit == true then
            hits = hits + 1
        end
    end

    return hits / 3
end

function GetCabinInteriorFactor(timeMs)
    if TimeDifference(timeMs, cachedCabin.at) < 400 then
        return cachedCabin.value
    end

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local cabinFactor = 0.0

    if vehicle ~= 0 and GetFollowVehicleCamViewMode() == 4 then
        local vehClass = GetVehicleClass(vehicle)
        if vehClass ~= 8 and vehClass ~= 13 and vehClass ~= 14 and vehClass ~= 22 then
            cabinFactor = 1.0
            if IsVehicleAConvertible(vehicle, false) then
                if GetConvertibleRoofState(vehicle) ~= 0 then
                    cabinFactor = 0.15
                end
            else
                for i = 0, 3 do
                    if not IsVehicleWindowIntact(vehicle, i) then
                        cabinFactor = cabinFactor - 0.18
                    end
                end
            end
        end
    end

    cachedCabin = {
        at = timeMs,
        value = cabinFactor
    }

    return cabinFactor
end

local vehicleClassAcousticProfiles = {
    [0]  = { 1.05, 330, 1.00, -0.5 },
    [1]  = { 1.00, 280, 1.00,  0.0 },
    [2]  = { 0.95, 220, 0.95,  0.5 },
    [3]  = { 1.01, 290, 1.00,  0.0 },
    [4]  = { 0.91, 160, 0.86,  1.0 },
    [5]  = { 0.97, 240, 0.95,  0.5 },
    [6]  = { 1.03, 310, 1.03,  0.0 },
    [7]  = { 1.07, 360, 1.08, -0.3 },
    [8]  = { 1.14, 470, 1.10, -1.5 },
    [9]  = { 0.94, 200, 0.92,  0.8 },
    [10] = { 0.87, 150, 0.80,  1.5 },
    [11] = { 0.90, 170, 0.84,  1.0 },
    [12] = { 0.93, 210, 0.90,  0.5 },
    [17] = { 0.93, 210, 0.90,  0.5 },
    [18] = { 0.98, 250, 0.98,  0.3 },
    [19] = { 0.87, 150, 0.80,  1.5 },
    [20] = { 0.87, 150, 0.80,  1.5 },
    [22] = { 1.12, 430, 1.12, -1.0 }
}

function GetEngineAcousticProfile(model)
    local cached = cachedEngineProfiles[model]
    if cached == nil then
        local profile = Config.EngineProfiles[model]
        cached = false

        if type(profile) == "table" then
            cached = {
                pitch = profile.pitch,
                body = profile.body,
                bright = profile.bright,
                weight = profile.weight
            }
        elseif profile == nil and Config.Audio.voices ~= false then
            local vehClass = GetVehicleClassFromName(model)
            local classData = vehicleClassAcousticProfiles[vehClass] or vehicleClassAcousticProfiles[1]

            local pitchVariance = 0.97 + (0.06 * ((model % 9973) / 9973))
            local bodyVariance = 0.9 + (0.2 * ((model % 7919) / 7919))
            local brightVariance = 0.96 + (0.08 * ((model % 6007) / 6007))

            cached = {
                pitch = classData[1] * pitchVariance,
                body = classData[2] * bodyVariance,
                bright = classData[3] * brightVariance,
                weight = classData[4]
            }
        end

        cachedEngineProfiles[model] = cached
    end

    return cached or nil
end

function GetEngineAudioType(model)
    local profile = Config.EngineProfiles[model]
    if type(profile) == "string" and profile then
        return profile
    end

    return Config.Audio.engine
end

function GetCachedRainLevel(timeMs)
    if TimeDifference(timeMs, cachedRain.at) > 1000 then
        cachedRain = {
            at = timeMs,
            rain = GetRainLevel()
        }
    end

    return cachedRain.rain
end

function TriggerVehicleAlarmReactions(origin, vehicle, energy)
    local reactions = Config.Reactions
    if type(reactions) ~= "table" or reactions.alarms ~= true then
        return
    end

    local now = GetGameTimer()
    for veh, triggerTime in pairs(alarmTriggeredVehicles) do
        if TimeDifference(now, triggerTime) > 300000 then
            alarmTriggeredVehicles[veh] = nil
        end
    end

    local radius = reactions.alarmRadius or 12.0
    for _, veh in ipairs(GetGamePool("CVehicle")) do
        if veh ~= vehicle and not alarmTriggeredVehicles[veh] then
            if DoesEntityExist(veh) and not IsVehicleAlarmActivated(veh) then
                if GetDistance3D(GetEntityCoords(veh), origin) <= radius then
                    alarmTriggeredVehicles[veh] = now
                    SetVehicleAlarm(veh, true)
                    StartVehicleAlarm(veh)
                end
            end
        end
    end
end

function ResolveVehicleExhaust(netId, vehicle)
    local exhaustName = nil
    if netId ~= 0 then
        local bagKey = "entity:" .. netId
        exhaustName = stateExhaustVehicles[bagKey]
        if not exhaustName and vehicle and vehicle ~= 0 then
            local ok, stateVal = pcall(function()
                return Entity(vehicle).state[Config.StateKey]
            end)
            if ok and type(stateVal) == "table" and type(stateVal.exhaust) == "string" then
                exhaustName = stateVal.exhaust
                stateExhaustVehicles[bagKey] = exhaustName
            end
        end
    end

    local exhaustData = nil
    if exhaustName and type(Config.Exhausts) == "table" then
        exhaustData = Config.Exhausts[exhaustName]
    end

    if type(exhaustData) ~= "table" then
        exhaustData = nil
    end

    return exhaustData, exhaustName
end

function GetExhaustVisualProperties(netId, vehicle)
    local exhaustData, exhaustName = ResolveVehicleExhaust(netId, vehicle)
    if not exhaustData or type(exhaustData.colour) ~= "table" then
        return nil, nil, exhaustName
    end

    return exhaustData.colour, (exhaustData.soot == true), exhaustName
end

function RegisterEmitterVehicle(packet, vehicle, points)
    local emitter = activeEmitters[packet.netId]
    if emitter then
        emitter.vehicle = vehicle
        emitter.points = points
        emitter.model = packet.model
        emitter.epoch = packet.epoch
        emitter.untilAt = GetGameTimer() + 4500
        return
    end

    activeEmitters[packet.netId] = {
        vehicle = vehicle,
        points = points,
        model = packet.model,
        epoch = packet.epoch,
        untilAt = GetGameTimer() + 4500,
        losAt = nil,
        occlusion = 0.0
    }
end

function HandleAntiLagPacket(packet, isLocal)
    if not IsFinite(packet.netId) or not IsFinite(packet.epoch) or not IsFinite(packet.sequence) then
        return
    end

    local state = packet.state
    if not state or not PopsAntiLag.Validate(state) then
        return
    end

    local cancelledEpoch = cancelledEpochs[packet.netId] or 0
    if packet.epoch < cancelledEpoch then
        return
    end

    local existing = activeAntiLagVehicles[packet.netId]
    local nowTime = GetAccurateNetworkTime()
    local packetAge = TimeDifference(nowTime, packet.at)

    if packetAge > (Config.AntiLag.timeoutMs or 4500) then
        return
    end

    if existing then
        if packet.epoch == existing.epoch and packet.sequence <= existing.sequence then
            return
        end
    end

    local deadline = antiLagDeadlines[packet.netId]
    if deadline and packet.epoch == deadline.epoch then
        if deadline.sender == packet.sender and deadline.sequence >= packet.sequence then
            return
        end
    end

    if not isLocal and packet.sender == GetPlayerServerId(PlayerId()) then
        if packet.netId == localVehicle.netId and packet.sequence <= localAntiLagSequence then
            return
        end
    end

    antiLagDeadlines[packet.netId] = {
        epoch = packet.epoch,
        sender = packet.sender,
        sequence = packet.sequence,
        at = packet.at,
        deadline = GetGameTimer() + 5000
    }

    if state.mode == "off" then
        activeAntiLagVehicles[packet.netId] = nil
        PopsFlames.CancelBurst("als:" .. packet.netId)
        SendNUIMessage({
            action = "antilag",
            vehicle = packet.netId,
            epoch = packet.epoch,
            sequence = packet.sequence,
            sender = packet.sender,
            ageMs = math.max(0, packetAge),
            mode = "off",
            vent = (state.vent == true)
        })
        return
    end

    local veh = ResolveNetworkVehicle(packet)
    if veh == 0 or not GetIsVehicleEngineRunning(veh) or IsEntityDead(veh) then
        return
    end

    local points = (existing and existing.vehicle == veh and existing.points) or GetExhaustPoints(veh)
    local exhaustPos, exhaustDir = GetExhaustPositionAndDirection(veh, points)
    local localPedInVeh = GetVehiclePedIsIn(PlayerPedId(), false)

    packet.points = points
    packet.vehicle = veh
    packet.state = state

    local cycle = nil
    if existing and existing.state.mode == state.mode and existing.state.seed == state.seed then
        cycle = existing.cycle
    end
    packet.cycle = cycle

    activeAntiLagVehicles[packet.netId] = packet

    if StartPlaybackThread then
        StartPlaybackThread()
    end

    RegisterEmitterVehicle(packet, veh, points)

    if PushListenerToNUI then
        PushListenerToNUI(true)
    end

    local occlusion = 0.0
    if veh ~= localPedInVeh then
        occlusion = CalculateOcclusion(veh, exhaustPos) or 0.0
    end

    local env = nil
    if veh ~= localPedInVeh then
        env = GetVehicleAcousticRoom(packet.netId, veh, GetGameTimer())
    end

    SendNUIMessage({
        action = "antilag",
        vehicle = packet.netId,
        epoch = packet.epoch,
        sequence = packet.sequence,
        sender = packet.sender,
        mode = state.mode,
        rpm = state.rpm,
        load = state.load,
        boost = state.boost,
        temperature = state.temperature,
        phaseMs = state.phaseMs,
        seed = state.seed,
        ageMs = math.max(0, packetAge),
        position = exhaustPos,
        direction = exhaustDir,
        velocity = CloneVector3(GetEntityVelocity(veh)),
        maxDistance = Config.AntiLag.radius,
        volume = Config.AntiLag.volume,
        occlusion = occlusion,
        env = env,
        cabin = GetCabinInteriorFactor(GetGameTimer())
    })
end

function EmitLocalAntiLag(state, force)
    local now = GetGameTimer()
    if not force and state.mode == localAntiLagMode then
        if state.mode == "off" then
            return
        end
        if TimeDifference(now, lastAntiLagAt) < (Config.AntiLag.updateMs or 100) then
            return
        end
    end

    localAntiLagSequence = localAntiLagSequence + 1
    localAntiLagMode = state.mode
    lastAntiLagAt = now

    local packet = {
        netId = localVehicle.netId,
        epoch = localVehicle.epoch,
        sequence = localAntiLagSequence,
        at = GetAccurateNetworkTime(),
        sender = GetPlayerServerId(PlayerId()),
        model = GetEntityModel(localVehicle.vehicle),
        state = state
    }

    HandleAntiLagPacket(packet, true)

    TriggerServerEvent(EVENT_PREFIX .. "als", {
        netId = packet.netId,
        epoch = packet.epoch,
        sequence = packet.sequence,
        at = packet.at,
        state = state
    })
end
EmitLocalAntiLagState = EmitLocalAntiLag

function HandleBurstPacket(packet, isPredicted)
    if type(packet) ~= "table" or not IsFinite(packet.netId) or not IsFinite(packet.epoch)
        or not IsFinite(packet.sequence) or not IsFinite(packet.startAt) or not IsFinite(packet.seed)
        or type(packet.trigger) ~= "string" or not IsFinite(packet.level) or not Config.Levels[packet.level]
        or type(packet.origin) ~= "table" or not IsFinite(packet.origin.x) or not IsFinite(packet.origin.y)
        or not IsFinite(packet.origin.z) then
        return
    end

    local normTelemetry = PopsProtocol.Normalize(packet.telemetry)
    if not normTelemetry then
        return
    end
    packet.telemetry = normTelemetry

    if type(packet.pulses) ~= "table" then
        local tune = PopsValve.Tune(Config.Levels[packet.level], packet.valveClosed)
        packet.pulses = PopsCombustion.Build(
            tune,
            packet.trigger,
            packet.telemetry,
            packet.seed,
            packet.variant,
            packet.sampleOffsets
        )
    end

    local cancelledEpoch = cancelledEpochs[packet.netId] or 0
    if packet.epoch < cancelledEpoch then
        return
    end

    local burstKey = PopsProtocol.Key(packet.sender, packet.netId, packet.epoch, packet.sequence)
    if predictedBursts[burstKey] or cancelledBursts[burstKey] then
        return
    end

    local age = TimeDifference(packet.startAt, GetAccurateNetworkTime())
    if age > Config.Sync.maxFutureMs or age < -Config.Sync.maxPacketAgeMs then
        return
    end

    if packet.epoch > cancelledEpoch then
        CancelVehicleState(packet.netId, packet.epoch)
    end

    local pulseEntries = {}
    for i, pulse in ipairs(packet.pulses) do
        if i > 16 or not IsFinite(pulse.delay) or pulse.delay < 0 or pulse.delay > 1500
            or not IsFinite(pulse.durationMs) or not IsFinite(pulse.soundDelayMs) then
            return
        end
        pulseEntries[i] = { pulse = pulse }
    end

    local burstCount = 0
    for _ in pairs(activeBursts) do
        burstCount = burstCount + 1
    end
    if burstCount >= 64 then
        return
    end

    predictedBursts[burstKey] = GetGameTimer() + 8000

    local shiftMs = 0
    if not isPredicted then
        local minLead = Config.Sync.minLeadMs or 25
        shiftMs = math.max(0, minLead - age)
    end

    burstCutoffs[burstKey] = shiftMs
    activeBursts[burstKey] = {
        packet = packet,
        entries = pulseEntries,
        predicted = isPredicted,
        key = burstKey,
        shift = shiftMs
    }

    activeAudioDeadline = GetGameTimer() + 2500

    if StartPlaybackThread then
        StartPlaybackThread()
    end

    if PushListenerToNUI then
        PushListenerToNUI(false)
    end
end

function CancelPredictedBursts(allowAll)
    for burstId, burst in pairs(activeBursts) do
        if burst.predicted then
            if allowAll or (burst.packet.trigger ~= "overrun" and burst.packet.trigger ~= "limiter" and burst.packet.trigger ~= "antilag") then
                CancelBurst(burstId, true, true)
            end
        end
    end
end

function EmitLocalBurst(triggerData)
    local tune = localVehicle.tune
    local trigger = triggerData.trigger

    if trigger == "antilag" or trigger == "launch" then
        tune = {}
        for k, v in pairs(Config.Levels[Config.AntiLag.level]) do
            tune[k] = v
        end
        tune.antiLag = localVehicle.antiLag
    end

    if trigger == "launch" then
        tune = PopsValve.Tune(tune, localVehicle.valveClosed)
    end

    local normTelemetry = PopsProtocol.Normalize(triggerData.telemetry)
    if not normTelemetry or not PopsProtocol.Eligible(trigger, normTelemetry, tune) then
        return
    end

    maxBurstSequence = maxBurstSequence + 1
    local seed = math.random(1, 2147483646)

    if not PopsProtocol.ShouldEmit(trigger, tune, seed) then
        return
    end

    CancelPredictedBursts(false)

    localVehicle.variant = ((localVehicle.variant or 0) + 1) % 2147483647

    if not localVehicle.sampleOffsets then
        localVehicle.sampleOffsets = {}
        for _, kind in ipairs({ "snap", "crackle", "bang", "burble", "boom" }) do
            localVehicle.sampleOffsets[kind] = math.random(0, 1000000)
        end
    end

    local offsets = PopsProtocol.SampleOffsets(localVehicle.sampleOffsets)
    local startAt = (GetAccurateNetworkTime() + Config.Sync.leadMs) % 4294967296

    local serverPacket = {
        netId = localVehicle.netId,
        epoch = localVehicle.epoch,
        sequence = maxBurstSequence,
        seed = seed,
        trigger = trigger,
        startAt = startAt,
        telemetry = normTelemetry,
        variant = localVehicle.variant,
        sampleOffsets = offsets
    }

    local localPacket = {
        netId = localVehicle.netId,
        epoch = localVehicle.epoch,
        sequence = maxBurstSequence,
        seed = seed,
        sender = GetPlayerServerId(PlayerId()),
        model = GetEntityModel(localVehicle.vehicle),
        level = tune.level,
        startAt = startAt,
        trigger = trigger,
        telemetry = normTelemetry,
        valveClosed = (localVehicle.valveClosed == true),
        variant = localVehicle.variant,
        sampleOffsets = offsets,
        origin = CloneVector3(GetEntityCoords(localVehicle.vehicle)),
        pulses = PopsCombustion.Build(tune, trigger, normTelemetry, seed, localVehicle.variant, offsets)
    }

    for _, pulse in ipairs(localPacket.pulses) do
        local kind = pulse.kind
        if localVehicle.sampleOffsets[kind] then
            localVehicle.sampleOffsets[kind] = (localVehicle.sampleOffsets[kind] + 1) % 2147483647
        end
    end

    HandleBurstPacket(localPacket, true)
    TriggerServerEvent(EVENT_PREFIX .. "burst", serverPacket)

    local maxDuration = 0
    local totalEnergy = 0
    for _, pulse in ipairs(localPacket.pulses) do
        maxDuration = math.max(maxDuration, pulse.delay + pulse.durationMs)
        totalEnergy = totalEnergy + pulse.energy
    end

    return maxDuration, totalEnergy
end

function HasActiveBurstsOrFlames()
    return (next(activeBursts) ~= nil) or (next(activeAntiLagVehicles) ~= nil) or PopsFlames.HasActive()
end

function StartPlaybackThread()
    if isPlaybackThreadRunning or resourceStopping then
        return
    end

    isPlaybackThreadRunning = true
    lastBurstPlaybackTime = nil

    CreateThread(function()
        while true do
            if resourceStopping then
                break
            end

            local nowTimer = GetGameTimer()
            local nowNetTime = GetAccurateNetworkTime()

            for burstId, burst in pairs(activeBursts) do
                local packet = burst.packet
                local veh = ResolveNetworkVehicle(packet)

                if veh == 0 or not GetIsVehicleEngineRunning(veh) or IsEntityDead(veh) then
                    CancelBurst(burstId, false, false)
                else
                    if veh ~= 0 then
                        if not burst.points or burst.vehicle ~= veh then
                            burst.points = GetExhaustPoints(veh)
                            burst.vehicle = veh
                        end
                    end

                    if not burst.profile then
                        burst.profile = PopsValve.Tune(Config.Levels[packet.level], packet.valveClosed)
                    end

                    local profile = burst.profile
                    local allDone = true

                    for i, entry in ipairs(burst.entries) do
                        if not (entry.audio and entry.visual) then
                            allDone = false
                            local pulse = entry.pulse
                            local pulseTime = TimeDifference(packet.startAt, nowNetTime) + pulse.delay + burst.shift

                            if not entry.outlet and veh ~= 0 then
                                local outlets = PopsFlames.Outlets(packet.seed, i, #burst.points, pulse.heavy == true, false)
                                entry.outlet = outlets[1] or 1
                            end

                            local outletIdx = entry.outlet or 1
                            local exhaustPos = (veh ~= 0) and GetWorldCoordOfExhaustPoint(veh, burst.points[outletIdx] or burst.points[1]) or packet.origin
                            local distToCam = GetDistance3D(GetFinalRenderedCamCoord(), exhaustPos)

                            if not entry.audio and pulseTime <= Config.Sync.audioLookaheadMs then
                                entry.audio = true
                                if veh ~= 0 and distToCam < profile.radius then
                                    local pos, dir = GetExhaustPositionAndDirection(veh, burst.points, outletIdx)
                                    RegisterEmitterVehicle(packet, veh, burst.points)

                                    if pulseTime > 0 then
                                        local vel = GetEntityVelocity(veh)
                                        local dt = pulseTime / 1000
                                        pos.x = pos.x + (vel.x * dt)
                                        pos.y = pos.y + (vel.y * dt)
                                        pos.z = pos.z + (vel.z * dt)
                                    end

                                    local inVeh = GetVehiclePedIsIn(PlayerPedId(), false)
                                    local emitter = activeEmitters[packet.netId]
                                    if veh ~= inVeh and emitter and not emitter.losAt then
                                        emitter.occlusion = CalculateOcclusion(veh, pos)
                                        emitter.losAt = nowTimer
                                    end

                                    if PushListenerToNUI then
                                        PushListenerToNUI(true)
                                    end

                                    local minDur = Config.Particle.minDurationMs or 72
                                    local pulseDur = math.max(pulse.durationMs, math.min(110, math.max(40, minDur)))

                                    local envRoom = (veh ~= inVeh) and GetVehicleAcousticRoom(packet.netId, veh, nowTimer) or nil

                                    SendNUIMessage({
                                        action = "pop",
                                        vehicle = packet.netId,
                                        epoch = packet.epoch,
                                        burstId = burstId,
                                        level = packet.level,
                                        position = pos,
                                        direction = dir,
                                        durationMs = pulseDur,
                                        delayMs = pulseTime,
                                        soundDelayMs = pulse.soundDelayMs or 0,
                                        volume = pulse.volume or 1.0,
                                        maxDistance = profile.radius,
                                        echo = pulse.echo or 0.2,
                                        pitch = pulse.pitch or 1.0,
                                        energy = pulse.energy or 1.0,
                                        heavy = (pulse.heavy == true),
                                        kind = pulse.kind,
                                        sampleIndex = pulse.sampleIndex,
                                        layers = pulse.layers or {},
                                        outlet = outletIdx,
                                        velocity = CloneVector3(GetEntityVelocity(veh)),
                                        bodyDb = pulse.bodyDb,
                                        tail = pulse.tail,
                                        echoScale = pulse.echoScale,
                                        rpm = packet.telemetry.rpm,
                                        temperature = packet.telemetry.temperature,
                                        engine = GetEngineAudioType(packet.model),
                                        voice = GetEngineAcousticProfile(packet.model),
                                        occlusion = (veh ~= inVeh and emitter) and emitter.occlusion or 0.0,
                                        env = envRoom,
                                        cabin = GetCabinInteriorFactor(nowTimer),
                                        seed = packet.seed
                                    })
                                end
                            end

                            if not entry.visual and pulseTime <= 0 then
                                entry.visual = true
                                if veh ~= 0 and distToCam <= Config.VisualDistance then
                                    local tint, soot, exhaustName = GetExhaustVisualProperties(packet.netId, veh)
                                    PopsFlames.Emit(veh, burst.points, pulse, {
                                        netId = packet.netId,
                                        epoch = packet.epoch,
                                        burstId = burstId,
                                        outlet = outletIdx,
                                        ageMs = -pulseTime,
                                        trigger = packet.trigger,
                                        level = packet.level,
                                        tint = tint,
                                        soot = soot,
                                        exhaust = exhaustName,
                                        burstSeed = packet.seed,
                                        index = i,
                                        count = #packet.pulses,
                                        last = (i == #packet.pulses),
                                        temperature = packet.telemetry.temperature,
                                        seed = packet.seed + (i * 7919),
                                        context = PopsFlames.Context(packet.trigger, {
                                            speed = GetEntitySpeed(veh),
                                            soak = packet.telemetry.temperature,
                                            temperature = packet.telemetry.temperature
                                        })
                                    })

                                    if ProbeListenerEnvironment then
                                        ProbeListenerEnvironment(nowTimer)
                                    end

                                    TriggerPopFeedback(veh, pulse, exhaustPos)
                                    TriggerVehicleAlarmReactions(exhaustPos, veh, pulse.energy or 1.0)
                                    TriggerPedReactions(veh, exhaustPos)
                                end
                            end
                        end
                    end

                    if allDone then
                        activeBursts[burstId] = nil
                    end
                end
            end

            for netId, als in pairs(activeAntiLagVehicles) do
                local veh = ResolveNetworkVehicle(als)
                local state = als.state

                if veh == 0 or not GetIsVehicleEngineRunning(veh) or IsEntityDead(veh) then
                    activeAntiLagVehicles[netId] = nil
                else
                    local cycleMs = PopsAntiLag.CycleMs(state.mode)
                    local elapsedSinceStart = TimeDifference(nowNetTime, als.at)
                    local currentCycleIndex = math.floor(elapsedSinceStart / cycleMs)
                    local cycleOffset = elapsedSinceStart % cycleMs
                    local cycleCut = PopsAntiLag.Cut(state.mode, cycleOffset, state.seed + (currentCycleIndex * 1013))

                    local pulseOffset = cycleCut.offsetMs + 2
                    local pulseTimeDiff = elapsedSinceStart - (currentCycleIndex * cycleMs + pulseOffset)

                    if als.cycle ~= currentCycleIndex and pulseTimeDiff >= 0 then
                        als.cycle = currentCycleIndex
                        if cycleCut.active and cycleCut.energy >= 0.42 and pulseTimeDiff <= 60 then
                            local camDist = GetDistance3D(GetFinalRenderedCamCoord(), GetWorldCoordOfExhaustPoint(veh, als.points[1]))
                            if camDist <= Config.VisualDistance then
                                local boostFactor = (0.5 + (state.boost * 0.45)) * cycleCut.energy
                                local flameTemp = math.max(state.temperature, 0.55 + (state.boost * 0.45))
                                local tint, soot, exhaustName = GetExhaustVisualProperties(netId, veh)

                                local flameKind = cycleCut.accent and "bang" or "afterfire"
                                local flameDur = (state.mode == "launch") and 95 or 130
                                local flameScale = (0.62 + (state.boost * 0.4)) * cycleCut.energy * (cycleCut.flame and 1.0 or 0.72)

                                PopsFlames.Emit(veh, als.points, {
                                    kind = flameKind,
                                    heavy = cycleCut.accent,
                                    durationMs = flameDur,
                                    energy = boostFactor,
                                    scale = flameScale
                                }, {
                                    netId = netId,
                                    epoch = als.epoch,
                                    burstId = "als:" .. netId,
                                    tint = tint,
                                    soot = soot,
                                    exhaust = exhaustName,
                                    ageMs = pulseTimeDiff,
                                    level = Config.AntiLag.level,
                                    continuous = true,
                                    temperature = flameTemp,
                                    burstSeed = state.seed,
                                    index = currentCycleIndex,
                                    context = PopsFlames.Context("antilag", {
                                        speed = GetEntitySpeed(veh),
                                        soak = flameTemp,
                                        temperature = flameTemp
                                    }),
                                    seed = state.seed + (currentCycleIndex * 7919)
                                })
                            end
                        end
                    end

                    local launchCfg = Config.AntiLag.launch
                    if state.mode == "launch" and type(launchCfg) == "table" and launchCfg.revLimiter ~= false then
                        local phaseProgress = math.max(0.0, math.min(1.0, (elapsedSinceStart - (currentCycleIndex * cycleMs)) / cycleMs))
                        local energyCut = cycleCut.active and (cycleCut.energy * (1.0 - phaseProgress)) or 0.0

                        local targetRpm = launchCfg.rpm or 0.74
                        local dip = (launchCfg.dip or 0.15) * energyCut
                        local rpmSetting = math.max(0.2, math.min(1.0, targetRpm - dip))
                        SetVehicleCurrentRpm(veh, rpmSetting + 0.0)

                        if launchCfg.clutch ~= false and veh == localVehicle.vehicle then
                            SetVehicleClutch(veh, 0.0)
                        end
                    end
                end
            end

            PopsFlames.Tick(nowTimer)

            if HasActiveBurstsOrFlames() then
                lastBurstPlaybackTime = nil
                Wait(0)
            else
                if not lastBurstPlaybackTime then
                    lastBurstPlaybackTime = nowTimer
                end

                if TimeDifference(nowTimer, lastBurstPlaybackTime) > 1500 then
                    break
                end

                Wait(8)
            end
        end

        isPlaybackThreadRunning = false
    end)
end

function ProbeListenerEnvironment(timeMs)
    local playerPed = PlayerPedId()
    local probe = ProbeAcousticSpace(GetEntityCoords(playerPed), playerPed, true)

    local roof = probe.roof
    local enclosure = probe.enclosure
    local isInterior = (GetInteriorFromEntity(playerPed) ~= 0)

    if isInterior then
        enclosure = math.max(enclosure, 0.8)
        roof = 1.0
    end

    local weight = lastListenerEnv.enclosure and 0.5 or 1.0
    local speedOfSound = Config.Audio.speedOfSound or 343.0
    local wallDelay = math.max(8, math.min(250, ((2 * probe.nearest) / speedOfSound) * 1000))

    lastListenerEnv = {
        at = timeMs,
        sent = false,
        interior = isInterior,
        enclosure = (lastListenerEnv.enclosure or 0) + ((enclosure - (lastListenerEnv.enclosure or 0)) * weight),
        roof = (lastListenerEnv.roof or 0) + ((roof - (lastListenerEnv.roof or 0)) * weight),
        wallMs = wallDelay,
        height = (probe.height > 0) and probe.height or (lastListenerEnv.height or 0.0),
        width = probe.width,
        length = probe.length,
        walls = probe.walls
    }
end

function PushListenerToNUI(force)
    local now = GetGameTimer()
    local frame = GetFrameCount()

    if not uiReady or (frame == lastFrameCount and not force and TimeDifference(now, lastCamPushAt) < 30) then
        return
    end

    lastFrameCount = frame
    lastCamPushAt = now

    local rot = GetFinalRenderedCamRot(2)
    local rx = math.rad(rot.x)
    local rz = math.rad(rot.z)
    local ry = math.rad(rot.y)

    local sinX = math.sin(rx)
    local cosX = math.cos(rx)
    local sinZ = math.sin(rz)
    local cosZ = math.cos(rz)
    local sinY = math.sin(ry)
    local cosY = math.cos(ry)

    local camCoord = GetFinalRenderedCamCoord()
    local listenerData = {
        action = "listener",
        position = CloneVector3(camCoord),
        forward = {
            x = -sinZ * cosX,
            y = cosZ * cosX,
            z = sinX
        },
        up = {
            x = (sinZ * sinX * sinY) + (cosZ * cosY),
            y = (-cosZ * sinX * sinY) + (sinZ * cosY),
            z = cosX * sinY
        },
        muted = IsPauseMenuActive() or not NetworkIsPlayerActive(PlayerId())
    }

    local envInterval = (TimeDifference(now, activeAudioDeadline) < 0) and (Config.Audio.environmentMs or 450) or 3000
    if Config.Audio.reverb ~= false and TimeDifference(now, lastListenerEnv.at) > envInterval then
        ProbeListenerEnvironment(now)
    end

    if lastListenerEnv.enclosure and not lastListenerEnv.sent then
        lastListenerEnv.sent = true
        listenerData.env = {
            enclosure = lastListenerEnv.enclosure,
            roof = lastListenerEnv.roof,
            wallMs = lastListenerEnv.wallMs,
            interior = (lastListenerEnv.interior == true),
            height = lastListenerEnv.height,
            width = lastListenerEnv.width,
            length = lastListenerEnv.length,
            walls = FormatWallReflections(lastListenerEnv.walls)
        }
    end

    SendNUIMessage(listenerData)
end
PushListenerOrientation = PushListenerToNUI

function TriggerLocalTestBang(vehicle, netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    local points = GetExhaustPoints(vehicle)
    local seed = math.random(1, 2147483646)

    local pulse = {
        delay = 0,
        soundDelayMs = 10,
        durationMs = 170,
        energy = 1.25,
        heavy = true,
        pitch = 1.0,
        kind = "boom",
        phrase = "single_bang",
        sampleIndex = (seed % 16) + 1,
        tone = 0.85,
        bodyDb = 2.0,
        tail = 1.0,
        echoScale = 1.05,
        scale = 1.6,
        layers = {}
    }

    local pos, dir = GetExhaustPositionAndDirection(vehicle, points, 1)

    PushListenerToNUI(true)

    SendNUIMessage({
        action = "pop",
        vehicle = netId,
        epoch = cancelledEpochs[netId] or 0,
        burstId = "test:" .. netId,
        level = math.max(1, localVehicle.level > 0 and localVehicle.level or 3),
        position = pos,
        direction = dir,
        durationMs = 170,
        delayMs = 0,
        soundDelayMs = 10,
        volume = 1.0,
        maxDistance = 120.0,
        echo = 0.24,
        pitch = 1.0,
        energy = 1.25,
        heavy = true,
        kind = "boom",
        sampleIndex = pulse.sampleIndex,
        layers = {},
        outlet = 1,
        velocity = CloneVector3(GetEntityVelocity(vehicle)),
        bodyDb = 2.0,
        tail = 1.0,
        echoScale = 1.05,
        rpm = 0.6,
        temperature = 0.8,
        engine = GetEngineAudioType(GetEntityModel(vehicle)),
        voice = GetEngineAcousticProfile(GetEntityModel(vehicle)),
        cabin = GetCabinInteriorFactor(GetGameTimer()),
        seed = seed
    })

    local tint, soot, exhaustName = GetExhaustVisualProperties(netId, vehicle)

    PopsFlames.Emit(vehicle, points, pulse, {
        netId = netId,
        epoch = cancelledEpochs[netId] or 0,
        burstId = "test:" .. netId,
        ageMs = 0,
        trigger = "overrun",
        level = 3,
        tint = tint,
        soot = soot,
        exhaust = exhaustName,
        burstSeed = seed,
        index = 1,
        count = 1,
        last = true,
        temperature = 0.8,
        seed = seed,
        context = PopsFlames.Context("overrun", {
            speed = 0,
            soak = 0.8,
            temperature = 0.8
        })
    })

    ProbeListenerEnvironment(GetGameTimer())
    TriggerPopFeedback(vehicle, pulse, pos)
end

PopsClient = {
    notify = ShowNotification,
    localBang = TriggerLocalTestBang,
    driver = function()
        return localVehicle
    end,
    exhaustOf = ResolveVehicleExhaust,
    pushListener = function()
        PushListenerToNUI(true)
    end
}

function UpdateVehicleTurboAudio(vehicle, netId, isLocal, deltaMs, timeMs)
    local turboState = activeTurboVehicles[netId]
    if not turboState then
        turboState = {
            points = GetExhaustPoints(vehicle),
            boost = 0.0,
            sent = 0.0,
            rpm = 0.0,
            throttle = 0.0
        }
        activeTurboVehicles[netId] = turboState
    end

    local turboCfg = Config.AntiLag.turbo
    local isDriver = (isLocal and localVehicle.vehicle == vehicle)

    local currentRpm = GetVehicleCurrentRpm(vehicle)
    local throttle = 0.0
    if isDriver then
        throttle = math.max(GetControlNormal(0, 71), GetDisabledControlNormal(0, 71))
    elseif GetIsVehicleEngineRunning(vehicle) then
        throttle = currentRpm > 0.4 and 0.8 or 0.0
    end

    local targetBoost = 0.0
    if throttle > 0.15 and currentRpm > 0.3 then
        targetBoost = math.min(1.0, (currentRpm - 0.3) / 0.6)
    end

    local spoolRate = (targetBoost > turboState.boost) and (turboCfg.spoolUp or 1.2) or (turboCfg.spoolDown or 2.0)
    turboState.boost = turboState.boost + ((targetBoost - turboState.boost) * math.min(1.0, (deltaMs / 1000) * spoolRate))

    local pos = GetEngineBayWorldCoords(vehicle)
    local cabinFactor = GetCabinInteriorFactor(timeMs)

    local isSpooling = (turboState.boost > 0.05)
    if isSpooling or turboState.sent > 0 then
        RegisterEmitterVehicle({
            netId = netId,
            epoch = cancelledEpochs[netId] or 0,
            model = GetEntityModel(vehicle)
        }, vehicle, turboState.points)

        PushListenerToNUI(true)

        SendNUIMessage({
            action = "turbo",
            vehicle = netId,
            boost = isSpooling and turboState.boost or 0.0,
            position = pos,
            maxDistance = turboCfg.radius or 70.0,
            volume = 1.0,
            cabin = cabinFactor
        })

        turboState.sent = isSpooling and turboState.boost or 0
    end

    return isSpooling
end

-- Commands
RegisterCommand(Config.Command, function(source, args)
    local levelArg = tonumber(args[1])
    if #args ~= 1 or not PopsProtocol.Integer(levelArg, 0, PopsProtocol.MaxLevel()) then
        ShowNotification(L("usage_pops", Config.Command, FormatLevelsList()), "info")
        return
    end

    local playerPed = PlayerPedId()
    local now = GetGameTimer()
    local veh = GetVehiclePedIsIn(playerPed, false)

    if veh == 0 then
        ShowNotification(L("need_driver"), "error")
        return
    end

    if GetPedInVehicleSeat(veh, -1) ~= playerPed then
        local driverPed = GetPedInVehicleSeat(veh, -1)
        if driverPed == 0 or not DoesEntityExist(driverPed) then
            SetPedIntoVehicle(playerPed, veh, -1)
            Wait(50)
        else
            ShowNotification(L("need_driver"), "error")
            return
        end
    end

    if not NetworkGetEntityIsNetworked(veh) then
        ShowNotification(L("not_synced"), "warning")
        return
    end

    if TimeDifference(now, lastInstallCommandAt) < Config.InstallCooldownMs then
        return
    end

    lastInstallCommandAt = now
    SyncLocalVehicle(veh, VehToNet(veh))
    TriggerServerEvent(EVENT_PREFIX .. "install", localVehicle.netId, levelArg)
end, false)

RegisterCommand(Config.AntiLag.command, function(source, args)
    local stateArg = tonumber(args[1])
    if #args ~= 1 or not PopsProtocol.Integer(stateArg, 0, 1) then
        ShowNotification(L("usage_antilag", Config.AntiLag.command), "info")
        return
    end

    local playerPed = PlayerPedId()
    local now = GetGameTimer()
    local veh = GetVehiclePedIsIn(playerPed, false)

    if veh == 0 then
        ShowNotification(L("need_driver"), "error")
        return
    end

    if GetPedInVehicleSeat(veh, -1) ~= playerPed then
        local driverPed = GetPedInVehicleSeat(veh, -1)
        if driverPed == 0 or not DoesEntityExist(driverPed) then
            SetPedIntoVehicle(playerPed, veh, -1)
            Wait(50)
        else
            ShowNotification(L("need_driver"), "error")
            return
        end
    end

    if not NetworkGetEntityIsNetworked(veh) then
        ShowNotification(L("not_synced"), "warning")
        return
    end

    if TimeDifference(now, lastInstallCommandAt) < Config.InstallCooldownMs then
        return
    end

    lastInstallCommandAt = now
    SyncLocalVehicle(veh, VehToNet(veh))
    TriggerServerEvent(EVENT_PREFIX .. "installAntiLag", localVehicle.netId, stateArg)
end, false)

RegisterCommand("popsflametest", function(source, args)
    local playerPed = PlayerPedId()
    local veh = GetVehiclePedIsIn(playerPed, false)
    if veh == 0 then
        ShowNotification(L("enter_car"), "error")
        return
    end

    local points = GetExhaustPoints(veh)
    local candidateLetter = (type(args) == "table" and args[1]) and tostring(args[1]):upper() or nil
    local descriptions = {
        A = "A: core looped",
        B = "B: plume non-looped",
        C = "C: plume looped",
        D = "D: nitro jet looped",
        E = "E: core non-looped",
        F = "F: afterburner looped"
    }

    CreateThread(function()
        for _, letter in ipairs({ "A", "B", "C", "D", "E", "F" }) do
            if not candidateLetter or candidateLetter == letter then
                local success, err = PopsFlames.Probe(veh, points, letter, { 0.15, 0.85, 1.0 })
                local statusMsg = success and "fired now" or ("failed, " .. tostring(err))
                ShowNotification(string.format("%s: %s", descriptions[letter], statusMsg))
                print(string.format("[oxlyn-popsbangs] flame test %s: %s (%s)", letter, success and "ok" or "failed", tostring(err)))
                Wait(1800)
            end
        end
        ShowNotification("Test over: tell me which letters came out cyan.")
    end)
end, false)

RegisterCommand("popsflametest2", function(source, args)
    local playerPed = PlayerPedId()
    local veh = GetVehiclePedIsIn(playerPed, false)
    if veh == 0 then
        ShowNotification(L("enter_car"), "error")
        return
    end

    local points = GetExhaustPoints(veh)
    local filter = (type(args) == "table" and args[1]) and tostring(args[1]):upper() or nil

    CreateThread(function()
        for _, candidate in ipairs(PopsFlames.ProbeCandidates()) do
            local tag, fxName, scale, asset = candidate[1], candidate[2], candidate[3], candidate[4]
            if not filter or filter == tag then
                local success, err = PopsFlames.ProbeEffect(veh, points, fxName, scale, asset, { 0.15, 0.85, 1.0 })
                print(string.format("[oxlyn-popsbangs] test %s: %s (%s)", tag, success and "ok" or "failed", tostring(err)))
                Wait(1800)
            end
        end
        ShowNotification("Test over: tell me which letters came out cyan.")
    end)
end, false)

RegisterCommand("popsexhaust", function()
    local playerPed = PlayerPedId()
    local veh = GetVehiclePedIsIn(playerPed, false)
    if veh == 0 then
        ShowNotification(L("enter_car"), "error")
        return
    end

    local netId = NetworkGetEntityIsNetworked(veh) and VehToNet(veh) or 0
    local cachedExhaust = stateExhaustVehicles["entity:" .. netId]

    local ok, stateVal = pcall(function()
        return Entity(veh).state[Config.StateKey]
    end)
    local bagExhaust = (ok and type(stateVal) == "table") and stateVal.exhaust or nil

    local exhaustData, resolvedName = ResolveVehicleExhaust(netId, veh)
    local tintStr = "sem tinta"
    if exhaustData and exhaustData.colour then
        tintStr = string.format("%.2f %.2f %.2f", exhaustData.colour[1], exhaustData.colour[2], exhaustData.colour[3])
    end

    local lastSyncStr = "nenhum"
    if lastSyncResult then
        lastSyncStr = string.format(
            "netId %s level %s antiLag %s exhaust %s %d ms ago",
            tostring(lastSyncResult.netId),
            tostring(lastSyncResult.level),
            tostring(lastSyncResult.antiLag),
            tostring(lastSyncResult.exhaust),
            GetGameTimer() - lastSyncResult.at
        )
    end

    local stateBagSummary = ok and (type(stateVal) == "table" and "tabela" or type(stateVal)) or "erro"
    local exhaustLabel = (exhaustData and exhaustData.label) or L("stock_label")

    print(string.format(
        "[oxlyn-popsbangs] car %d netId %d | cache: %s | state bag: %s (%s) | used: %s -> %s | tint=%s | last syncResult: %s",
        veh, netId, tostring(cachedExhaust), tostring(bagExhaust), stateBagSummary,
        exhaustLabel, tintStr, tostring(Config.Particle and Config.Particle.tint), lastSyncStr
    ))

    local timeSince = lastSyncResult and L("exhaust_since", tostring(lastSyncResult.exhaust), math.floor((GetGameTimer() - lastSyncResult.at) / 1000)) or L("none")
    ShowNotification(L("exhaust_debug", exhaustLabel, tintStr, tostring(cachedExhaust), tostring(bagExhaust), timeSince))
end, false)

RegisterCommand("popsrooms", function()
    local playerPed = PlayerPedId()
    local probe = ProbeAcousticSpace(GetEntityCoords(playerPed), playerPed, true)

    local directions = { [0] = "E", [1] = "NE", [2] = "N", [3] = "NW", [4] = "W", [5] = "SW", [6] = "S", [7] = "SE" }
    print(string.format(
        "[oxlyn-popsbangs] space: enclosure %.2f | roof %s | height %.1f m | width %.1f m | length %.1f m | interior %s",
        probe.enclosure, (probe.roof > 0) and "yes" or "no", probe.height, probe.width, probe.length,
        tostring(GetInteriorFromEntity(playerPed) ~= 0)
    ))

    if probe.walls then
        for _, wall in ipairs(probe.walls) do
            local heightDesc = "low"
            if wall.t == 1 then
                heightDesc = "medium (>9 m)"
            elseif wall.t >= 2 then
                heightDesc = "tall (>18 m)"
            end

            print(string.format(
                "  wall %-2s at %5.1f m | material %11s (%s) | reflects %.2f | bright %.2f | height %s",
                directions[wall.a], wall.d, GetMaterialCategory(wall.m), tostring(wall.m), wall.h, wall.b, heightDesc
            ))
        end
    end

    local roofDesc = (probe.roof > 0) and L("rooms_roof_at", probe.height) or L("no")
    ShowNotification(L("rooms_measured", probe.walls and #probe.walls or 0, roofDesc), "info")
end, false)

-- NUI Callbacks
RegisterNUICallback("ready", function(data, cb)
    uiReady = true

    local audioCfg = Config.Audio
    local antiLagSamples = Config.AntiLag.samples

    if type(antiLagSamples) == "table" then
        if not PopsAntiLag.Enabled("bangs") and not PopsAntiLag.Enabled("twoStep") then
            antiLagSamples = {
                flutter = antiLagSamples.flutter,
                blowOff = antiLagSamples.blowOff
            }
        end
    end

    SendNUIMessage({
        action = "locale",
        strings = LocaleTable()
    })

    SendNUIMessage({
        action = "ui",
        settings = (type(Config.UI) == "table") and Config.UI or {}
    })

    SendNUIMessage({
        action = "configure",
        masterVolume = audioCfg.masterVolume,
        maxVoices = audioCfg.maxVoices,
        speedOfSound = audioCfg.speedOfSound,
        samples = audioCfg.samples,
        maxLateMs = audioCfg.maxLateMs,
        audioLeadMs = audioCfg.audioLeadMs,
        reverb = (audioCfg.reverb ~= false),
        reverbLevel = audioCfg.reverbLevel,
        doppler = audioCfg.doppler,
        colourDb = audioCfg.colourDb,
        whoosh = audioCfg.whoosh,
        hiss = audioCfg.hiss,
        thump = audioCfg.thump,
        ticks = audioCfg.ticks,
        reflections = audioCfg.reflections,
        flutter = audioCfg.flutter,
        antiLag = {
            samples = antiLagSamples,
            watchdogMs = Config.AntiLag.timeoutMs,
            maxVehicles = 8,
            turbo = Config.AntiLag.turbo
        }
    })

    cb({ ok = true })
end)

-- Network Events
RegisterNetEvent(EVENT_PREFIX .. "notify", function(message, kind, title)
    if source == 65535 and type(message) == "string" then
        ShowNotification(
            message,
            (type(kind) == "string" and kind) or nil,
            (type(title) == "string" and title) or nil
        )
    end
end)

RegisterNetEvent(EVENT_PREFIX .. "cancel", function(netId, epoch)
    if source == 65535 then
        CancelVehicleState(netId, epoch)
    end
end)

RegisterNetEvent(EVENT_PREFIX .. "syncResult", function(netId, level, epoch, sequence, antiLagState, exhaustName, valveClosed)
    if source ~= 65535 or not IsFinite(netId) or not IsFinite(level) or not IsFinite(epoch) then
        return
    end

    if level ~= 0 and not Config.Levels[level] then
        return
    end

    local currentCancelled = cancelledEpochs[netId] or 0
    if epoch < currentCancelled then
        return
    end

    if epoch > currentCancelled then
        CancelVehicleState(netId, epoch)
    end

    local cleanExhaust = (type(exhaustName) == "string" and exhaustName) or "stock"
    stateExhaustVehicles["entity:" .. netId] = cleanExhaust

    lastSyncResult = {
        netId = netId,
        level = level,
        epoch = epoch,
        antiLag = antiLagState,
        exhaust = exhaustName,
        at = GetGameTimer()
    }

    if localVehicle.netId == netId then
        localVehicle.level = level
        localVehicle.epoch = epoch
        localVehicle.antiLag = (antiLagState == true)
        localVehicle.valveClosed = (valveClosed == true)
        localVehicle.exhaust = (type(exhaustName) == "string" and exhaustName) or nil

        local effectiveLevel = level
        if not (effectiveLevel > 0) and localVehicle.antiLag then
            effectiveLevel = Config.AntiLag.level or 0
        end

        localVehicle.tune = nil
        if effectiveLevel > 0 then
            localVehicle.tune = {}
            for k, v in pairs(Config.Levels[effectiveLevel]) do
                localVehicle.tune[k] = v
            end
            localVehicle.tune.popsEnabled = (level > 0)
            localVehicle.tune.antiLag = localVehicle.antiLag
            localVehicle.tune.rally = localVehicle.antiLag and PopsAntiLag.Enabled("bangs")
            localVehicle.tune = PopsValve.Tune(localVehicle.tune, localVehicle.valveClosed)
        end

        if IsFinite(sequence) then
            maxBurstSequence = math.max(maxBurstSequence, sequence)
        end
    end
end)

RegisterNetEvent(EVENT_PREFIX .. "reject", function(netId, epoch, sequence)
    if source ~= 65535 or not IsFinite(netId) or not IsFinite(epoch) or not IsFinite(sequence) then
        return
    end

    local burstKey = PopsProtocol.Key(GetPlayerServerId(PlayerId()), netId, epoch, sequence)
    CancelBurst(burstKey, false, false)
end)

RegisterNetEvent(EVENT_PREFIX .. "cut", function(netId, epoch, sequence, cutTime, serverTime)
    if source ~= 65535 or not IsFinite(netId) or not IsFinite(epoch) or not IsFinite(sequence) or not IsFinite(cutTime) then
        return
    end

    local burstKey = PopsProtocol.Key(netId, epoch, sequence, cutTime)
    local sTime = (IsFinite(serverTime) and serverTime) or nil
    CancelBurst(burstKey, true, false, sTime)
end)

RegisterNetEvent(EVENT_PREFIX .. "als", function(packet)
    if source == 65535 then
        HandleAntiLagPacket(packet, false)
    end
end)

RegisterNetEvent(EVENT_PREFIX .. "alsReject", function(netId, epoch, sequence)
    if source ~= 65535 then
        return
    end

    if localVehicle.netId == netId and localVehicle.epoch == epoch and sequence == localAntiLagSequence then
        activeAntiLagVehicles[netId] = nil
        PopsFlames.CancelBurst("als:" .. netId)
        SendNUIMessage({
            action = "antilag",
            vehicle = netId,
            epoch = epoch,
            mode = "off",
            sequence = sequence,
            sender = GetPlayerServerId(PlayerId()),
            immediate = true
        })
    end
end)

RegisterNetEvent(EVENT_PREFIX .. "play", function(packet)
    if source == 65535 then
        HandleBurstPacket(packet, false)
    end
end)

-- State Bag Handler
AddStateBagChangeHandler(Config.StateKey, nil, function(bagName, key, value)
    if type(bagName) ~= "string" or bagName:sub(1, 7) ~= "entity:" then
        return
    end

    local antiLagActive = (type(value) == "table") and value.antiLag or value
    stateAntiLagVehicles[bagName] = (antiLagActive == true)

    local exhaustName = (type(value) == "table" and type(value.exhaust) == "string") and value.exhaust or nil
    stateExhaustVehicles[bagName] = exhaustName
end)

-- Threads
CreateThread(function()
    PopsFlames.Init(Config)
    Wait(700)

    TriggerEvent("chat:addSuggestion", "/" .. Config.Command, L("cmd_pops_desc"), {
        { name = L("cmd_pops_arg"), help = FormatLevelsList() }
    })

    TriggerEvent("chat:addSuggestion", "/" .. Config.AntiLag.command, L("cmd_antilag_desc"), {
        { name = L("cmd_antilag_arg"), help = L("cmd_antilag_help") }
    })
end)

CreateThread(function()
    while true do
        if resourceStopping then
            break
        end

        local hasActiveBursts = (next(activeBursts) ~= nil)
        if hasActiveBursts then
            activeAudioDeadline = GetGameTimer() + 2500
        end

        if not hasActiveBursts then
            hasActiveBursts = (TimeDifference(GetGameTimer(), activeAudioDeadline) < 0)
        end

        if uiReady then
            PushListenerToNUI(true)

            local currentPedVeh = GetVehiclePedIsIn(PlayerPedId(), false)
            local now = GetGameTimer()
            local emitterList = {}

            for netId, emitter in pairs(activeEmitters) do
                local veh = emitter.vehicle
                local isExpired = (TimeDifference(now, emitter.untilAt) > 0)

                if not isExpired and DoesEntityExist(veh) and GetEntityModel(veh) == emitter.model
                    and VehToNet(veh) == netId and cancelledEpochs[netId] == emitter.epoch then
                    local pos, dir = GetExhaustPositionAndDirection(veh, emitter.points)

                    if not emitter.losAt or TimeDifference(now, emitter.losAt) > 250 then
                        emitter.occlusion = (veh ~= currentPedVeh) and (CalculateOcclusion(veh, pos) or 0.0) or 0.0
                        emitter.losAt = now
                    end

                    local outlets = {}
                    for idx, pt in ipairs(emitter.points) do
                        outlets[idx] = CloneVector3(GetWorldCoordOfExhaustPoint(veh, pt))
                    end

                    emitterList[#emitterList + 1] = {
                        vehicle = netId,
                        epoch = emitter.epoch,
                        position = pos,
                        direction = dir,
                        occlusion = emitter.occlusion,
                        outlets = outlets,
                        velocity = CloneVector3(GetEntityVelocity(veh)),
                        engine = activeTurboVehicles[netId] and GetEngineBayWorldCoords(veh) or nil,
                        cabin = GetCabinInteriorFactor(now)
                    }
                else
                    activeEmitters[netId] = nil
                end
            end

            if #emitterList > 0 then
                SendNUIMessage({
                    action = "emitters",
                    items = emitterList
                })
            end
        end

        local nowTimer = GetGameTimer()
        for key, expiry in pairs(predictedBursts) do
            if TimeDifference(nowTimer, expiry) > 0 then
                predictedBursts[key] = nil
                burstCutoffs[key] = nil
            end
        end

        for key, expiry in pairs(cancelledBursts) do
            if TimeDifference(nowTimer, expiry) > 0 then
                cancelledBursts[key] = nil
            end
        end

        for netId, data in pairs(antiLagDeadlines) do
            if TimeDifference(nowTimer, data.deadline) > 0 then
                antiLagDeadlines[netId] = nil
            end
        end

        Wait(hasActiveBursts and 33 or 1000)
    end
end)

CreateThread(function()
    local lastTime = GetGameTimer()
    while true do
        if resourceStopping then
            break
        end

        local nowTime = GetGameTimer()
        local deltaMs = math.min(250, nowTime - lastTime)
        lastTime = nowTime

        local isAnyActive = false
        local turboCfg = Config.AntiLag.turbo

        if uiReady and type(turboCfg) == "table" and turboCfg.enabled ~= false then
            local activeSet = {}
            local camCoord = GetFinalRenderedCamCoord()
            local count = 0

            if localVehicle.antiLag and localVehicle.vehicle ~= 0 and DoesEntityExist(localVehicle.vehicle)
                and GetIsVehicleEngineRunning(localVehicle.vehicle) then
                activeSet[localVehicle.netId] = true
                count = 1
                local active = UpdateVehicleTurboAudio(localVehicle.vehicle, localVehicle.netId, true, deltaMs, nowTime)
                isAnyActive = active or isAnyActive
            end

            for bagKey in pairs(stateAntiLagVehicles) do
                local veh = GetEntityFromStateBagName(bagKey)
                if count < 4 and veh ~= 0 and veh ~= localVehicle.vehicle and DoesEntityExist(veh)
                    and GetIsVehicleEngineRunning(veh) then
                    local dist = GetDistance3D(camCoord, GetEntityCoords(veh))
                    if dist < (turboCfg.radius or 70.0) then
                        local netId = NetworkGetNetworkIdFromEntity(veh)
                        activeSet[netId] = true
                        count = count + 1
                        local active = UpdateVehicleTurboAudio(veh, netId, false, deltaMs, nowTime)
                        isAnyActive = active or isAnyActive
                    end
                end
            end

            for netId, data in pairs(activeTurboVehicles) do
                if not activeSet[netId] then
                    if data.sent > 0 then
                        SendNUIMessage({
                            action = "turbo",
                            vehicle = netId,
                            boost = 0.0,
                            position = CloneVector3(GetFinalRenderedCamCoord()),
                            maxDistance = 70.0
                        })
                    end
                    activeTurboVehicles[netId] = nil
                end
            end
        end

        local sleepMs = 1000
        if isAnyActive then
            sleepMs = 50
        elseif localVehicle.antiLag or next(stateAntiLagVehicles) ~= nil then
            sleepMs = 250
        end

        Wait(sleepMs)
    end
end)

CreateThread(function()
    local previousThrottle = 0
    local isAntiLagSupported = PopsAntiLag.Enabled("bangs") or PopsAntiLag.Enabled("twoStep")

    while true do
        if resourceStopping then
            break
        end

        local playerPed = PlayerPedId()
        local currentVeh = GetVehiclePedIsIn(playerPed, false)
        local isDriver = (GetPedInVehicleSeat(currentVeh, -1) == playerPed) and NetworkGetEntityIsNetworked(currentVeh)

        if isDriver then
            SyncLocalVehicle(currentVeh, VehToNet(currentVeh))

            local now = GetGameTimer()
            if TimeDifference(now, lastLocalBurstAt) >= 5000 then
                lastLocalBurstAt = now
                TriggerServerEvent(EVENT_PREFIX .. "sync", localVehicle.netId)
            end

            if localVehicle.tune then
                local throttleInput = math.max(GetControlNormal(0, 71), GetDisabledControlNormal(0, 71))
                local isEngineRunning = GetIsVehicleEngineRunning(currentVeh) and not IsEntityDead(currentVeh)
                local isPaused = IsPauseMenuActive()

                local minThrottleThreshold = math.max(0.25, previousThrottle)
                if not (throttleInput < minThrottleThreshold and isEngineRunning) or isPaused then
                    CancelPredictedBursts(not isEngineRunning)
                end

                local telemPacket = {
                    valid = not isPaused,
                    engineRunning = isEngineRunning,
                    rpm = GetVehicleCurrentRpm(currentVeh),
                    throttle = throttleInput,
                    gear = GetVehicleCurrentGear(currentVeh),
                    speed = GetEntitySpeed(currentVeh),
                    brake = math.max(GetControlNormal(0, 72), GetDisabledControlNormal(0, 72)),
                    health = math.max(0.0, math.min(1.0, GetVehicleEngineHealth(currentVeh) / 1000.0)),
                    allowSyntheticRpm = Config.AllowAllVehicleTypes
                }

                local telemTrigger = PopsTelemetry.Step(telemetry, telemPacket, localVehicle.tune, now)
                telemPacket.temperature = telemetry.temperature

                if Config.AllowAllVehicleTypes and telemPacket.rpm <= 0.01 then
                    telemPacket.rpm = telemetry.syntheticRpm
                end

                local alsTrigger = nil
                if isAntiLagSupported then
                    alsTrigger = PopsAntiLag.Step(antiLag, telemPacket, localVehicle.tune, now)
                end
                alsTrigger = alsTrigger or { mode = "off" }

                local wasLaunching = (localAntiLagMode == "launch")
                if alsTrigger.mode == "off" and wasLaunching and throttleInput < 0.3 then
                    alsTrigger.vent = true
                end

                if alsTrigger.mode == "off" and localAntiLagMode == "rally" and throttleInput < 0.15 and telemPacket.speed > 3.0 then
                    PopsTelemetry.Coast(telemetry, now)
                end

                EmitLocalAntiLagState(alsTrigger, false)
                previousThrottle = throttleInput

                if alsTrigger.mode == "off" and wasLaunching then
                    local snapshot = PopsTelemetry.Snapshot(telemetry, telemPacket)
                    if snapshot then
                        telemTrigger = {
                            trigger = "launch",
                            telemetry = snapshot
                        }
                    end
                end

                if telemTrigger and telemTrigger.trigger ~= "antilag" and alsTrigger.mode ~= "launch" then
                    local canEmit = true
                    if alsTrigger.mode == "rally" and telemTrigger.telemetry.chain > 0 then
                        canEmit = false
                    end

                    if canEmit then
                        local dur, energy = EmitLocalBurst(telemTrigger)
                        if dur then
                            PopsTelemetry.Extend(telemetry, now, dur, energy)
                        end
                    end
                end
            end
        else
            if localVehicle.vehicle ~= 0 then
                SyncLocalVehicle(0, 0)
                previousThrottle = 0
            end
        end

        local sampleInterval = (isDriver and localVehicle.tune) and (Config.Telemetry.sampleMs or 80) or 250
        Wait(sampleInterval)
    end
end)

CreateThread(function()
    local heatAccumulator = 20000
    local lastTickTime = GetGameTimer()

    while true do
        if resourceStopping then
            break
        end

        local nowTime = GetGameTimer()
        local deltaMs = math.max(0, math.min(1000, nowTime - lastTickTime))
        lastTickTime = nowTime

        local tickCfg = Config.Audio.ticks
        if uiReady and tickCfg ~= false and tickCfg ~= 0 then
            local inLocalVeh = (localVehicle.vehicle ~= 0)
            local veh = inLocalVeh and localVehicle.vehicle or (lastVehicleContext and lastVehicleContext.vehicle or 0)
            local netId = inLocalVeh and localVehicle.netId or (lastVehicleContext and lastVehicleContext.netId or 0)
            local soak = inLocalVeh and (localVehicle.tune and telemetry.soak or 0.0) or (lastVehicleContext and lastVehicleContext.soak or 0.0)

            local isEngineOff = (veh ~= 0) and not GetIsVehicleEngineRunning(veh)

            if veh ~= 0 and not isEngineOff then
                heatAccumulator = math.min(20000, heatAccumulator + deltaMs)
            end

            if exhaustTicksState and (not isEngineOff or exhaustTicksState.vehicle ~= veh) then
                exhaustTicksState = nil
            end

            if isEngineOff and not exhaustTicksState then
                local accumulatedHeat = (soak * heatAccumulator) / 20000
                heatAccumulator = 0
                if accumulatedHeat >= 0.4 then
                    exhaustTicksState = {
                        vehicle = veh,
                        netId = netId,
                        heat = accumulatedHeat,
                        from = nowTime,
                        nextAt = nowTime + math.random(500, 1400)
                    }
                end
            end

            local sleepMs = 500
            if exhaustTicksState then
                local elapsed = TimeDifference(nowTime, exhaustTicksState.from)
                local currentHeat = exhaustTicksState.heat * math.exp(-elapsed / 35000)
                sleepMs = 120

                if currentHeat < 0.15 then
                    exhaustTicksState = nil
                else
                    if TimeDifference(nowTime, exhaustTicksState.nextAt) >= 0 then
                        local exhaustCoord = GetWorldCoordOfExhaustPoint(veh, GetExhaustPoints(veh)[1])
                        local dist = GetDistance3D(GetFinalRenderedCamCoord(), exhaustCoord)

                        if dist < 14.0 then
                            PushListenerToNUI(true)
                            SendNUIMessage({
                                action = "tick",
                                vehicle = netId,
                                position = exhaustCoord,
                                level = math.min(1.0, currentHeat),
                                maxDistance = 14.0,
                                cabin = GetCabinInteriorFactor(nowTime),
                                seed = (nowTime % 1000000) + netId
                            })
                        end

                        local heatFraction = 1.0 - math.min(1.0, currentHeat)
                        local nextInterval = math.floor((350 + (4200 * (heatFraction ^ 2))) * (0.6 + (0.8 * math.random())))
                        exhaustTicksState.nextAt = nowTime + nextInterval
                    end
                end
            end

            Wait(sleepMs)
        else
            Wait(500)
        end
    end
end)

-- Resource Stop Handler
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    resourceStopping = true
    activeBursts = {}
    activeAntiLagVehicles = {}
    antiLagDeadlines = {}
    activeEmitters = {}
    burstCutoffs = {}

    PopsFlames.Clear()

    SendNUIMessage({
        action = "reset"
    })

    TriggerEvent("chat:removeSuggestion", "/" .. Config.Command)
    TriggerEvent("chat:removeSuggestion", "/" .. Config.AntiLag.command)
end)
--fivevault_!2OnrrTopcS : https://discord.gg/fivevault
--fivevault-1FOnX@ToplT : https://discord.gg/fivevault
--fivevaultVaOnVQTopBU : https://discord.gg/fivevault
--fivevaultssyOnDTTopp$ : https://discord.gg/fivevault
--fivevault-UnOn2ETop$a : https://discord.gg/fivevault
