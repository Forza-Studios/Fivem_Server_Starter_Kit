-- oxlyn-truckjob client (decompiled output, cleaned: names restored, temp registers removed)
-- Names are inferred from behaviour, so rename anything that doesn't match your intent.
-- Relies on globals defined elsewhere: Truck, Config, Notify, Overrides, VehicleKeys, _U

---------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------
local ICON_PICKUP   = "fa-sharp fa-solid fa-pallet-boxes wi-svg"
local ICON_DELIVERY = "fa-sharp fa-solid fa-flag-checkered wi-svg"
local ICON_NPC      = "fa-sharp fa-solid fa-clipboard-check wi-svg"

local TRAILER_LENGTH = 9.0
local TRAILER_WIDTH  = 2.8
local DELIVERY_NPC_MODEL = "s_m_m_dockwork_01"

local WHEEL_BONES = {
    [0] = "wheel_lf",
    [1] = "wheel_rf",
    [4] = "wheel_lr",
    [5] = "wheel_rr",
}

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local promptVisible = false
local iconVisible   = false
local spawningPickupTrailer = false
local busy = false          -- an action (loading, repairing, ...) is in progress
local engineHeat = 0
local smokeFx = nil

-- anti-abuse timers
local idleSince, idleWarned = 0, false
local awaySince, awayWarned = 0, false

-- repair item request tracking
local repairRequestId = 0
local pendingRepairs = {}

---------------------------------------------------------------------
-- Config helpers
---------------------------------------------------------------------
local function cfgLoading()  return Config.Loading or {} end
local function cfgAntiAbuse() return Config.AntiAbuse or {} end
local function cfgTire()     return Config.TireBurst or {} end
local function cfgEngine()   return Config.EngineOverheat or {} end
local function cfgDetach()   return Config.TrailerDetach or {} end

---------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------
local function projectToScreen(coords, dist)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return nil end
    local scale = 4.0 / math.max(1.0, dist)
    scale = math.max(0.35, math.min(1.05, scale))
    return x, y, scale
end

local function showIcon(x, y, scale, icon)
    iconVisible = true
    SendNUIMessage({ action = "show3DIcon", x = x, y = y, scale = scale, icon = icon })
end

local function hideIcon()
    if not iconVisible then return end
    iconVisible = false
    SendNUIMessage({ action = "hide3DIcon" })
end

local function showPrompt(label, hint)
    if promptVisible then return end
    promptVisible = true
    local target = Config.Target or {}
    SendNUIMessage({
        action = "showInteractPrompt",
        label = label,
        hint = hint,
        key = target.keyLabel or "E",
    })
end

local function hidePrompt()
    if not promptVisible then return end
    promptVisible = false
    SendNUIMessage({ action = "hideInteractPrompt" })
end

-- Runs the progress bar. Uses Overrides.Progress if provided, otherwise the built-in NUI one.
local function progress(label, duration)
    if Overrides and type(Overrides.Progress) == "function" then
        local ok, result = pcall(Overrides.Progress, label, duration)
        if ok then return result ~= false end
    end
    SendNUIMessage({ action = "progress", label = label, duration = duration })
    Wait(duration)
    return true
end

---------------------------------------------------------------------
-- Generic helpers
---------------------------------------------------------------------
local function loadModel(model, timeout)
    RequestModel(model)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(model) do
        Wait(10)
        if deadline < GetGameTimer() then return false end
    end
    return true
end

local function loadAnimDict(dict, timeout)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeout or 1500)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if deadline <= GetGameTimer() then break end
    end
    return HasAnimDictLoaded(dict)
end

local function dist2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Registers an entity on the network and tells the server to track it.
local function trackNetworked(entity, kind)
    if not entity or not DoesEntityExist(entity) then return nil end

    local deadline = GetGameTimer() + 1500
    while not NetworkGetEntityIsNetworked(entity) and deadline > GetGameTimer() do
        NetworkRegisterEntityAsNetworked(entity)
        Wait(0)
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId ~= 0 then
        SetNetworkIdCanMigrate(netId, true)
        TriggerServerEvent("oxlyn-truckjob:server:trackVehicle", netId, kind)
        return netId
    end
    return nil
end

-- Freezes / unfreezes the player (or their vehicle) while busy.
local function setPlayerFrozen(frozen)
    if not (Config.Loading and Config.Loading.freezeWhileBusy) then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and DoesEntityExist(veh) then
            FreezeEntityPosition(veh, frozen)
            SetVehicleHandbrake(veh, frozen)
        end
    else
        FreezeEntityPosition(ped, frozen)
    end
end

local function setHazards(on)
    if not (Config.Loading and Config.Loading.hazardsWhileBusy) then return end
    local truck = Truck.truckEntity
    if not (truck and DoesEntityExist(truck)) then return end
    SetVehicleIndicatorLights(truck, 0, on and true or false)
    SetVehicleIndicatorLights(truck, 1, on and true or false)
end

local function deleteVehicleSafe(entity)
    if not (entity and DoesEntityExist(entity)) then return end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId ~= 0 then
        SetNetworkIdCanMigrate(netId, true)
        NetworkRequestControlOfEntity(entity)
        local deadline = GetGameTimer() + 600
        while not NetworkHasControlOfEntity(entity) and deadline > GetGameTimer() do
            NetworkRequestControlOfEntity(entity)
            Wait(20)
        end
    end

    SetEntityAsMissionEntity(entity, true, true)
    SetEntityVisible(entity, false, false)
    SetEntityCollision(entity, false, false)
    if DeleteVehicle then DeleteVehicle(entity) end
    if DoesEntityExist(entity) then DeleteEntity(entity) end
end

---------------------------------------------------------------------
-- Truck spawning
---------------------------------------------------------------------
local function spawnTruck()
    local def = Config.Trucks[math.random(#Config.Trucks)]
    local hash = GetHashKey(def.model)
    if not loadModel(hash) then return nil end

    local spawn = Config.Garage.spawn
    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)

    SetVehicleNumberPlateText(veh, ("%s%s"):format(def.plate or "TRK", math.random(100, 999)))
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleUndriveable(veh, false)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleFuelLevel(veh, def.fuel or 100.0)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleDoorsLocked(veh, (Config.VehicleKeys and Config.VehicleKeys.lockDoors) and 2 or 1)

    if VehicleKeys and VehicleKeys.Give then
        VehicleKeys.Give(veh)
    end

    local state = Entity(veh).state
    if state then
        state:set("fuel", 100.0, true)
        state:set("FUEL", 100.0, true)
    end

    SetModelAsNoLongerNeeded(hash)
    return veh
end

---------------------------------------------------------------------
-- Trailer helpers
---------------------------------------------------------------------

-- Is a vehicle occupying the (x, y, z) trailer slot at the given heading?
local function isSpotBlocked(x, y, z, heading, ignore)
    local rad = math.rad(heading or 0.0)
    local sinH = -math.sin(rad)
    local cosH = math.cos(rad)

    for _, veh in ipairs(GetGamePool("CVehicle")) do
        if veh ~= ignore and DoesEntityExist(veh) then
            local c = GetEntityCoords(veh)
            if math.abs(c.z - z) < 6.0 then
                local dx, dy = c.x - x, c.y - y
                local along  = dx * sinH + dy * cosH
                local across = dx * cosH + dy * -sinH
                if math.abs(along) < TRAILER_LENGTH + 2.0 and math.abs(across) < TRAILER_WIDTH + 1.0 then
                    return true
                end
            end
        end
    end
    return false
end

-- Finds a free spot along the pickup line. Returns x, y, isOriginalSpot (or nil).
local function findFreePickupSpot(route)
    local pickup = route.pickup
    local heading = route.pickupHeading or 0.0
    local rad = math.rad(heading)
    local cosH, sinH = math.cos(rad), math.sin(rad)

    for _, offset in ipairs({ 0.0, 5.5, -5.5, 11.0, -11.0, 16.5, -16.5 }) do
        local x = pickup.x + cosH * offset
        local y = pickup.y + sinH * offset
        if not isSpotBlocked(x, y, pickup.z, heading, nil) then
            return x, y, offset == 0.0
        end
    end
    return nil
end

-- Spawns a frozen trailer at the pickup (or at the given alternate spot).
local function spawnPickupTrailer(route, spot)
    local model = route.trailer or Config.Trailers[math.random(#Config.Trailers)]
    local hash = GetHashKey(model)
    if not loadModel(hash) then return nil end

    local heading = route.pickupHeading or 0.0
    local pickup = route.pickup
    local x, y = pickup.x, pickup.y
    local locked = route.pickupLocked

    if spot then
        x, y = spot.x, spot.y
        if not spot.original then locked = false end
    end

    -- Stream in the area so ground detection works
    NewLoadSceneStart(x, y, pickup.z, 0.0, 0.0, 0.0, 50.0, 0)
    local deadline = GetGameTimer() + 2000
    while not IsNewLoadSceneLoaded() and deadline > GetGameTimer() do
        Wait(50)
    end
    NewLoadSceneStop()
    RequestCollisionAtCoord(x, y, pickup.z)
    Wait(100)

    local z
    if locked then
        z = pickup.z
    else
        local groundZ
        for _, probe in ipairs({ 2.0, 8.0, 25.0, 80.0, 250.0 }) do
            local found, gz = GetGroundZFor_3dCoord(x, y, pickup.z + probe, false)
            if found and gz > -100.0 then
                groundZ = gz
                break
            end
        end
        groundZ = groundZ or pickup.z
        local minDim = GetModelDimensions(hash)
        z = groundZ + math.abs(minDim.z) + 0.1
    end

    local trailer = CreateVehicle(hash, x, y, z + 50.0, heading, true, false)
    if not (trailer and DoesEntityExist(trailer)) then return nil end

    FreezeEntityPosition(trailer, true)
    SetEntityCoordsNoOffset(trailer, x, y, z, true, true, true)
    SetEntityHeading(trailer, heading)
    SetEntityAsMissionEntity(trailer, true, true)
    SetVehicleDoorsLocked(trailer, 2)
    SetVehicleEngineHealth(trailer, 1000.0)
    SetVehicleHandbrake(trailer, true)
    SetModelAsNoLongerNeeded(hash)
    return trailer
end
Truck.SpawnPickupTrailer = spawnPickupTrailer
Truck.LoadModel = loadModel

-- Spawns a trailer directly behind the truck and hitches it (used when not spawning at pickup).
local function spawnTrailerBehindTruck(truck, model)
    if not (truck and DoesEntityExist(truck)) then return nil end

    model = model or Config.Trailers[math.random(#Config.Trailers)]
    local hash = GetHashKey(model)
    if not loadModel(hash) then return nil end

    local coords = GetEntityCoords(truck)
    local fwd = GetEntityForwardVector(truck)
    local heading = GetEntityHeading(truck)
    local x = coords.x - fwd.x * 8.0
    local y = coords.y - fwd.y * 8.0

    if isSpotBlocked(x, y, coords.z, heading, truck) then
        Notify.Send(nil, _U("err_pickup_blocked"), "warning", 5000)
        return nil
    end

    local trailer = CreateVehicle(hash, x, y, coords.z, heading, true, false)
    SetEntityAsMissionEntity(trailer, true, true)
    SetVehicleOnGroundProperly(trailer)
    AttachVehicleToTrailer(truck, trailer, 1.0)
    SetModelAsNoLongerNeeded(hash)
    return trailer
end

-- Unfreezes a pre-spawned trailer and hitches it to the truck.
local function attachSpawnedTrailer(truck, trailer)
    if not (truck and DoesEntityExist(truck) and trailer and DoesEntityExist(trailer)) then
        return false
    end

    if not NetworkHasControlOfEntity(trailer) then
        local deadline = GetGameTimer() + 1000
        repeat
            NetworkRequestControlOfEntity(trailer)
            Wait(20)
            if NetworkHasControlOfEntity(trailer) then break end
        until deadline < GetGameTimer()
    end

    FreezeEntityPosition(trailer, false)
    SetVehicleHandbrake(trailer, false)
    SetVehicleDoorsLocked(trailer, 1)
    AttachVehicleToTrailer(truck, trailer, 1.0)
    return true
end

local function isTrailerAttached(truck, trailer)
    if not (truck and trailer and DoesEntityExist(truck) and DoesEntityExist(trailer)) then
        return false
    end
    local hasTrailer, attached = GetVehicleTrailerVehicle(truck)
    return hasTrailer and attached == trailer
end

-- Pre-spawned trailer waiting at the pickup (resolved via net id if the handle was lost).
local function getPickupTrailer()
    local trailer = Truck.pickupTrailer
    if trailer and DoesEntityExist(trailer) then return trailer end

    local netId = Truck.pickupTrailerNet
    if netId and NetworkDoesNetworkIdExist(netId) then
        local veh = NetToVeh(netId)
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            Truck.pickupTrailer = veh
            return veh
        end
    end
    return nil
end

-- The trailer currently hauled by the player.
local function getTrailer()
    local trailer = Truck.trailerEntity
    if trailer and DoesEntityExist(trailer) then return trailer end

    local netId = Truck.trailerNet
    if netId and NetworkDoesNetworkIdExist(netId) then
        local veh = NetToVeh(netId)
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            Truck.trailerEntity = veh
            return veh
        end
    end
    return nil
end

-- Makes sure the pickup trailer exists (spawning it if needed).
local function ensurePickupTrailer(route)
    local existing = getPickupTrailer()
    if existing then return existing end
    if spawningPickupTrailer then return nil end

    if Truck.pickupTrailerNet then
        local pedCoords = GetEntityCoords(PlayerPedId())
        if #(pedCoords - route.pickup) > 60.0 then return nil end
    end

    spawningPickupTrailer = true
    local trailer = nil
    local x, y, original = findFreePickupSpot(route)
    if x then
        trailer = spawnPickupTrailer(route, { x = x, y = y, original = original })
    elseif not Truck.pickupBlockedWarned then
        Truck.pickupBlockedWarned = true
        Notify.Send(nil, _U("err_pickup_blocked"), "warning", 6000)
    end
    spawningPickupTrailer = false

    if not trailer then return nil end

    -- Job may have changed while we were spawning
    if not (Truck.onDuty and Truck.activeRoute == route and not Truck.pickupReached) then
        SetEntityAsMissionEntity(trailer, true, true)
        DeleteEntity(trailer)
        return nil
    end

    Truck.pickupTrailer = trailer
    Truck.pickupBlockedWarned = false
    Truck.pickupTrailerNet = trackNetworked(trailer, "trailer")
    return trailer
end

-- Is the hauled trailer hitched and close enough to the drop-off?
local function canDeliverHere()
    local truck = Truck.truckEntity
    local trailer = getTrailer()

    if not isTrailerAttached(truck, trailer) then
        return false, "err_trailer_not_hitched"
    end

    local dropoff = Truck.deliveryCoord
    local radius = (Config.Loading and Config.Loading.deliveryTrailerRadius) or 45.0
    if dropoff and #(GetEntityCoords(trailer) - dropoff) > radius then
        return false, "err_trailer_not_at_delivery"
    end
    return true
end

---------------------------------------------------------------------
-- Background threads: damage, driver upkeep, distance, HUD
---------------------------------------------------------------------

-- Count hard collisions
CreateThread(function()
    while true do
        Wait(500)
        if Truck.onDuty and Truck.truckEntity and DoesEntityExist(Truck.truckEntity) then
            if HasEntityCollidedWithAnything(Truck.truckEntity) then
                if GetEntitySpeed(Truck.truckEntity) > 14.0 then
                    Truck.damageHits = Truck.damageHits + 1
                    ClearEntityLastDamageEntity(Truck.truckEntity)
                end
            end
        end
    end
end)

-- When the player gets into the driver seat, keep the truck in perfect shape for a few seconds
CreateThread(function()
    local wasDriver = false
    while true do
        Wait(250)
        local truck = Truck.truckEntity
        if Truck.onDuty and truck and DoesEntityExist(truck) then
            local ped = PlayerPedId()
            local isDriver = GetPedInVehicleSeat(truck, -1) == ped

            if isDriver and not wasDriver then
                CreateThread(function()
                    for _ = 1, 15 do
                        if not truck or not DoesEntityExist(truck) then break end

                        local netId = NetworkGetNetworkIdFromEntity(truck)
                        if netId and netId ~= 0 then
                            NetworkRequestControlOfEntity(truck)
                        end

                        if not Truck.flatTire and not Truck.engineOverheating then
                            SetVehicleFixed(truck)
                        end
                        SetVehicleDeformationFixed(truck)
                        SetVehicleNeedsToBeHotwired(truck, false)
                        SetVehicleUndriveable(truck, false)
                        SetVehicleHasBeenOwnedByPlayer(truck, true)
                        SetVehicleHandbrake(truck, false)
                        SetVehicleBrake(truck, false)
                        if not Truck.engineOverheating then
                            SetVehicleEngineHealth(truck, 1000.0)
                        end
                        SetVehicleBodyHealth(truck, 1000.0)
                        SetVehiclePetrolTankHealth(truck, 1000.0)
                        SetVehicleFuelLevel(truck, 100.0)

                        local state = Entity(truck).state
                        if state then
                            state:set("fuel", 100.0, true)
                            state:set("FUEL", 100.0, true)
                        end

                        SetVehicleEngineOn(truck, true, true, false)
                        Wait(100)
                    end
                end)
            end
            wasDriver = isDriver
        else
            wasDriver = false
        end
    end
end)

-- Distance travelled
CreateThread(function()
    while true do
        Wait(1000)
        if Truck.onDuty and Truck.truckEntity and DoesEntityExist(Truck.truckEntity) then
            local pos = GetEntityCoords(Truck.truckEntity)
            if Truck.lastPos then
                local d = #(pos - Truck.lastPos)
                if d < 200.0 then
                    Truck.distanceM = Truck.distanceM + d
                end
            end
            Truck.lastPos = pos
        end
    end
end)

-- HUD
CreateThread(function()
    while true do
        local sleep = 750

        if Truck.onDuty and Config.UI.showHud then
            sleep = 200
            local route = Truck.activeRoute
            local target = (Truck.pickupReached and route.deliveries[1]) or route.pickup

            local pedCoords = GetEntityCoords(PlayerPedId())
            local remainingKm = #(pedCoords - vector3(target.x, target.y, target.z)) / 1000.0
            local elapsed = math.floor((GetGameTimer() - Truck.startTime) / 1000)
            local speed = Truck.truckEntity and (GetEntitySpeed(Truck.truckEntity) * 3.6) or 0
            local payment = Config.BasePay + (route.value or 0)

            -- First half of the bar = trip to pickup, second half = trip to delivery
            local progressValue = 0
            if Truck.pickupReached then
                if Truck.initialDistM > 0 then
                    local total = Truck.initialDistM / 1000.0
                    progressValue = 0.5 + math.max(0, math.min(1, 1 - remainingKm / total)) * 0.5
                end
            else
                local total = (Truck.initialPickupDistM or 0)
                if total > 0 then
                    total = total / 1000.0
                    progressValue = math.max(0, math.min(1, 1 - remainingKm / total)) * 0.5
                end
            end

            SendNUIMessage({
                action = "hud",
                hud = {
                    route = route.label,
                    cargo = route.cargo,
                    state = Truck.pickupReached and "delivery" or "pickup",
                    remainingKm = string.format("%.2f", remainingKm),
                    payment = payment,
                    currency = Config.Currency,
                    speed = math.floor(speed),
                    elapsed = elapsed,
                    health = math.floor(Truck.GetVehicleHealthPct() * 100),
                    progress = progressValue,
                    level = Truck.level,
                    xp = Truck.xp,
                    xpNext = Truck.xpNext,
                },
            })
        elseif Config.UI.showHud then
            SendNUIMessage({ action = "hud", hud = nil })
        end

        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- Truck removal / job reset / teleport
---------------------------------------------------------------------
local function removeTruck()
    local truck = Truck.truckEntity
    if not (truck and DoesEntityExist(truck)) then
        Truck.truckEntity = nil
        return
    end

    if VehicleKeys and VehicleKeys.Remove then
        VehicleKeys.Remove(truck)
    end

    if NetworkFadeOutEntity then
        NetworkFadeOutEntity(truck, false, true)
    end
    Wait(700)

    -- Get the player out first
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) == truck then
        ClearPedTasksImmediately(ped)
        SetEntityCoords(ped, GetEntityCoords(ped) + vector3(0.0, 0.0, 0.05), false, false, false, false)
    end

    deleteVehicleSafe(truck)
    Truck.truckEntity = nil
end

local function removeDeliveryNpc()
    local npc = Truck.deliveryNpc
    if npc and DoesEntityExist(npc) then
        ClearPedTasksImmediately(npc)
        SetEntityAsMissionEntity(npc, true, true)
        DeleteEntity(npc)
    end
    Truck.deliveryNpc = nil
end

local function resetJobState()
    Truck.onDuty = false
    Truck.pickupReached = false
    Truck.activeRoute = nil
    Truck.deliveryCoord = nil
    Truck.trailerEntity = nil
    Truck.trailerNet = nil
    Truck.pickupTrailer = nil
    Truck.pickupTrailerNet = nil
    Truck.pickupBlockedWarned = false
    Truck.distanceM = 0
    Truck.damageHits = 0
    Truck.flatTire = nil
    Truck.tireBurstAt = nil
    Truck.engineCanOverheat = false
    Truck.engineOverheating = false
    Truck.engineOverheatedOnce = false
    Truck.trailerDetachWanted = false
    Truck.trailerDetachAt = nil
    Truck.trailerDetached = false
    Truck.trailerDetachedOnce = false

    if smokeFx then
        StopParticleFxLooped(smokeFx, false)
        smokeFx = nil
    end
    engineHeat = 0

    removeDeliveryNpc()

    Truck.cooldownUntil = GetGameTimer() + (Config.Cooldown or 0) * 1000
    Truck.ClearRouteBlip()
    hideIcon()
    hidePrompt()
end

-- Optionally teleports the player somewhere after finishing the job
local function teleportOnComplete()
    local cfg = Config.TeleportOnComplete or {}
    if cfg.enabled == false then return end

    local target = cfg.target or "npc"
    local dest
    if type(target) == "vector4" then
        dest = target
    elseif target == "garage" then
        dest = Config.Garage and Config.Garage.spawn
    else
        dest = Config.NPC and Config.NPC.coords
    end
    if not dest then return end

    local ped = PlayerPedId()
    local fade = cfg.fade ~= false

    if fade then
        DoScreenFadeOut(450)
        local deadline = GetGameTimer() + 600
        while not IsScreenFadedOut() and deadline > GetGameTimer() do
            Wait(10)
        end
    end

    SetEntityCoords(ped, dest.x, dest.y, dest.z, false, false, false, false)
    SetEntityHeading(ped, dest.w or 0.0)

    if fade then
        Wait(150)
        DoScreenFadeIn(500)
    end
end

---------------------------------------------------------------------
-- Loading / unloading
---------------------------------------------------------------------

-- Called once the cargo is hitched and loaded
local function onCargoLoaded(route, trailer)
    Truck.trailerEntity = trailer
    Truck.trailerNet = Truck.pickupTrailerNet or trackNetworked(trailer, "trailer")
    Truck.pickupTrailer = nil
    Truck.pickupTrailerNet = nil
    Truck.pickupReached = true

    TriggerServerEvent("oxlyn-truckjob:server:cargoLoaded")

    local dropoff = Truck.deliveryCoord or route.deliveries[1]
    Truck.AddRouteBlip(dropoff, _U("goto_delivery"))
    Notify.Send(nil, _U("cargo_loaded"), "success")

    -- Schedule a random trailer detach, if this job rolled one
    if Truck.trailerDetachWanted then
        local cfg = cfgDetach()
        local minDelay = cfg.minDelay or 90
        local maxDelay = math.max(minDelay + 1, cfg.maxDelay or 480)
        Truck.trailerDetachAt = GetGameTimer() + math.random(minDelay, maxDelay) * 1000
        Truck.trailerDetachWanted = false
    end
end

local function startLoading(route)
    if busy then return end

    local truck = Truck.truckEntity
    if not (truck and DoesEntityExist(truck)) then return end

    local spawnAtPickup = Config.Loading and Config.Loading.spawnTrailerAtPickup

    local pickupTrailer
    if spawnAtPickup then
        pickupTrailer = ensurePickupTrailer(route)
        if not pickupTrailer then return end
    end

    local trailerPos
    if pickupTrailer then
        trailerPos = GetEntityCoords(pickupTrailer)
    else
        trailerPos = vector3(route.pickup.x, route.pickup.y, route.pickup.z)
    end

    local truckPos = GetEntityCoords(truck)
    local playerPos = GetEntityCoords(PlayerPedId())
    local attachDistance = (Config.Loading and Config.Loading.attachDistance) or 14.0
    local playerNearDistance = (Config.Loading and Config.Loading.playerNearDistance) or 4.5

    if dist2D(truckPos, trailerPos) > attachDistance then
        Notify.Send(nil, _U("err_truck_too_far"), "warning")
        return
    end
    if dist2D(playerPos, trailerPos) > playerNearDistance then
        Notify.Send(nil, _U("err_player_too_far"), "warning")
        return
    end

    busy = true
    hideIcon()
    hidePrompt()

    local duration = (Config.Loading and Config.Loading.pickupDuration) or 5000
    setHazards(true)
    setPlayerFrozen(true)
    progress(_U("loading_cargo"), duration)
    setPlayerFrozen(false)
    setHazards(false)

    -- Job may have been cancelled during the progress bar
    if not (Truck.onDuty and Truck.activeRoute == route) then
        busy = false
        return
    end

    local trailer
    if pickupTrailer then
        if DoesEntityExist(pickupTrailer) and attachSpawnedTrailer(truck, pickupTrailer) then
            trailer = pickupTrailer
        end
    else
        trailer = spawnTrailerBehindTruck(truck, route.trailer)
        if trailer then trackNetworked(trailer, "trailer") end
    end

    if trailer then
        local deadline = GetGameTimer() + 1500
        while not isTrailerAttached(truck, trailer) and deadline > GetGameTimer() do
            Wait(100)
            if not isTrailerAttached(truck, trailer) then
                AttachVehicleToTrailer(truck, trailer, attachDistance)
            end
        end

        if not isTrailerAttached(truck, trailer) then
            if pickupTrailer then SetVehicleHandbrake(pickupTrailer, true) end
            trailer = nil
        end
    end

    if not trailer then
        Notify.Send(nil, _U("err_trailer_not_hitched"), "error", 5000)
        busy = false
        return
    end

    onCargoLoaded(route, trailer)
    busy = false
end

-- opts.skipProgress: used when the delivery paper was signed (progress already handled)
local function startUnloading(route, opts)
    if busy then return end

    local ok, reason = canDeliverHere()
    if not ok then
        Notify.Send(nil, _U(reason), "error", 5500)
        return
    end

    busy = true
    hideIcon()
    hidePrompt()

    opts = opts or {}
    if not opts.skipProgress then
        local duration = (Config.Loading and Config.Loading.deliveryDuration) or 5000
        setHazards(true)
        setPlayerFrozen(true)
        progress(_U("unloading_cargo"), duration)
        setPlayerFrozen(false)
        setHazards(false)
    end

    local trailer = Truck.trailerEntity
    if trailer and DoesEntityExist(trailer) then
        DetachVehicleFromTrailer(trailer)
        FreezeEntityPosition(trailer, true)
        SetVehicleAsNoLongerNeeded(trailer)
    end
    Truck.trailerEntity = nil

    TriggerServerEvent("oxlyn-truckjob:server:complete", {
        id = route.id,
        distanceM = Truck.distanceM,
        elapsed = math.floor((GetGameTimer() - Truck.startTime) / 1000),
        damageHits = Truck.damageHits,
        healthPct = Truck.GetVehicleHealthPct(),
    })

    Notify.Send(nil, _U("returning_truck"), "info")

    local despawnDelay = (Config.Loading and Config.Loading.despawnDelay) or 3000
    CreateThread(function()
        Wait(despawnDelay)
        removeTruck()
        if trailer and DoesEntityExist(trailer) then
            deleteVehicleSafe(trailer)
        end
        teleportOnComplete()
        resetJobState()
        busy = false
    end)
end

---------------------------------------------------------------------
-- Main interaction loop (marker, icon, prompt, key press)
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 700

        if Truck.onDuty and Truck.activeRoute and not busy then
            local route = Truck.activeRoute

            -- Work out where the player should go next
            local target
            local isNpc = false
            if Truck.pickupReached then
                if Truck.deliveryNpc and DoesEntityExist(Truck.deliveryNpc) then
                    target = GetEntityCoords(Truck.deliveryNpc)
                    isNpc = true
                else
                    target = Truck.deliveryCoord or route.deliveries[1]
                end
            else
                if getPickupTrailer() then
                    target = GetEntityCoords(Truck.pickupTrailer)
                else
                    target = route.pickup
                end
            end

            local pedCoords = GetEntityCoords(PlayerPedId())
            local dist3D = #(pedCoords - vector3(target.x, target.y, target.z))
            local dist2 = dist2D(pedCoords, target)

            local marker = Config.Marker
            local drawDistance = marker.drawDistance or 25.0
            local interactDist = marker.interactDist or 5.5
            local key = (Config.Target and Config.Target.key) or 38

            if dist3D < drawDistance then
                sleep = 0

                local iconHeight = isNpc and 0.95 or 1.55
                local sx, sy, scale = projectToScreen(vector3(target.x, target.y, target.z + iconHeight), dist2)
                if sx then
                    local icon
                    if Truck.pickupReached then
                        icon = isNpc and ICON_NPC or ICON_DELIVERY
                    else
                        icon = ICON_PICKUP
                    end
                    showIcon(sx, sy, scale, icon)
                end

                if dist2 < interactDist then
                    local label, hint
                    if Truck.pickupReached then
                        if isNpc then
                            label, hint = _U("delivery_npc_label"), _U("delivery_npc_hint")
                        else
                            label, hint = _U("delivery_label"), _U("delivery_hint")
                        end
                    else
                        label, hint = _U("pickup_label"), _U("pickup_hint")
                    end
                    showPrompt(label, hint)

                    if IsControlJustReleased(0, key) then
                        if Truck.pickupReached then
                            if isNpc then
                                openDeliveryPaper(route)
                            else
                                startUnloading(route)
                            end
                        else
                            startLoading(route)
                        end
                    end
                else
                    hidePrompt()
                end
            else
                hideIcon()
                hidePrompt()
            end
        elseif not Truck.onDuty then
            if iconVisible then hideIcon() end
            if promptVisible then hidePrompt() end
        end

        Wait(sleep)
    end
end)

-- Pre-spawn the pickup trailer when the player gets close
CreateThread(function()
    while true do
        Wait(1000)
        local route = Truck.activeRoute
        if Truck.onDuty and route and not Truck.pickupReached and not busy then
            if Config.Loading and Config.Loading.spawnTrailerAtPickup then
                local spawnDistance = Config.Loading.trailerSpawnDistance or 150.0
                local dist = #(GetEntityCoords(PlayerPedId()) - route.pickup)
                if spawnDistance >= dist then
                    ensurePickupTrailer(route)
                end
            end
        end
    end
end)

-- Auto-load when the player hitches the pre-spawned trailer manually
CreateThread(function()
    while true do
        Wait(1000)
        local route = Truck.activeRoute
        if Truck.onDuty and route and not Truck.pickupReached and not busy then
            local truck = Truck.truckEntity
            local trailer = getPickupTrailer()
            if truck and DoesEntityExist(truck) and trailer and isTrailerAttached(truck, trailer) then
                busy = true
                hideIcon()
                hidePrompt()
                setHazards(true)
                progress(_U("loading_cargo"), (Config.Loading and Config.Loading.pickupDuration) or 5000)
                setHazards(false)

                if Truck.onDuty and Truck.activeRoute == route and not Truck.pickupReached
                    and isTrailerAttached(truck, trailer) then
                    onCargoLoaded(route, trailer)
                end
                busy = false
            end
        end
    end
end)

-- Detect the trailer coming loose (warn after it's been detached for 2.5s)
CreateThread(function()
    local detachedSince = 0
    while true do
        Wait(1000)
        local truck = Truck.truckEntity
        local trailer = getTrailer()

        if Truck.onDuty and Truck.pickupReached and not busy and truck and DoesEntityExist(truck)
            and trailer and DoesEntityExist(trailer) then
            if isTrailerAttached(truck, trailer) then
                detachedSince = 0
                if Truck.trailerDetached then
                    Truck.trailerDetached = false
                    Truck.trailerDetachedOnce = true
                    hidePrompt()
                end
            elseif not Truck.trailerDetached then
                if detachedSince == 0 then
                    detachedSince = GetGameTimer()
                elseif GetGameTimer() - detachedSince > 2500 then
                    detachedSince = 0
                    Truck.trailerDetached = true
                    Notify.Send(nil, _U("trailer_detached"), "warning", 7000)
                end
            end
        else
            detachedSince = 0
        end
    end
end)

---------------------------------------------------------------------
-- Delivery NPC
---------------------------------------------------------------------
local function spawnDeliveryNpc()
    if Truck.deliveryNpc and DoesEntityExist(Truck.deliveryNpc) then return end

    local coord = Truck.deliveryCoord
    if not coord then return end

    local hash = GetHashKey(DELIVERY_NPC_MODEL)
    if not IsModelInCdimage(hash) then return end

    RequestModel(hash)
    local deadline = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and deadline > GetGameTimer() do
        Wait(10)
    end
    if not HasModelLoaded(hash) then return end

    RequestCollisionAtCoord(coord.x, coord.y, coord.z)

    local groundZ
    for _, probe in ipairs({ 1.0, 3.0, 10.0, 30.0, 80.0, 200.0 }) do
        local found, gz = GetGroundZFor_3dCoord(coord.x, coord.y, coord.z + probe, false)
        if found and gz > -100.0 then
            groundZ = gz
            break
        end
    end
    groundZ = groundZ or (coord.z - 1.0)

    local ped = CreatePed(4, hash, coord.x, coord.y, groundZ + 1.0, 0.0, true, false)
    if not (ped and DoesEntityExist(ped)) then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedCanBeTargetted(ped, false)
    SetEntityInvincible(ped, true)
    SetPedKeepTask(ped, true)
    SetEntityCoords(ped, coord.x, coord.y, groundZ, false, false, false, false)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, true)

    Truck.deliveryNpc = ped
    SetModelAsNoLongerNeeded(hash)
end

-- Spawn / despawn the NPC based on distance to the delivery point
CreateThread(function()
    while true do
        Wait(2000)
        if Truck.onDuty and Truck.pickupReached and Truck.deliveryCoord then
            local dist = #(GetEntityCoords(PlayerPedId()) - Truck.deliveryCoord)
            if dist < 220.0 then
                if not (Truck.deliveryNpc and DoesEntityExist(Truck.deliveryNpc)) then
                    spawnDeliveryNpc()
                end
            elseif dist > 320.0 then
                if Truck.deliveryNpc and DoesEntityExist(Truck.deliveryNpc) then
                    removeDeliveryNpc()
                end
            end
        else
            if Truck.deliveryNpc and DoesEntityExist(Truck.deliveryNpc) then
                removeDeliveryNpc()
            end
        end
    end
end)

---------------------------------------------------------------------
-- Delivery paper (signing UI)
---------------------------------------------------------------------
function openDeliveryPaper(route)
    if busy then return end
    if not (route and Truck.pickupReached) then return end

    local ok, reason = canDeliverHere()
    if not ok then
        Notify.Send(nil, _U(reason), "error", 5500)
        return
    end

    TriggerServerEvent("oxlyn-truckjob:server:previewDelivery", {
        id = route.id,
        distanceM = Truck.distanceM,
        elapsed = math.floor((GetGameTimer() - Truck.startTime) / 1000),
        damageHits = Truck.damageHits,
        healthPct = Truck.GetVehicleHealthPct(),
    })
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

RegisterNetEvent("oxlyn-truckjob:client:deliveryPaperData", function(data)
    if not (Truck.onDuty and Truck.pickupReached and Truck.activeRoute) then return end
    if not (data and data.breakdown) then return end

    local route = Truck.activeRoute
    local label = data.label or route.label or ""

    -- Labels look like "From → To"
    local from, to = "—", "—"
    local arrowStart = label:find("→")
    if arrowStart then
        from = trim(label:sub(1, arrowStart - 1))
        to = trim(label:sub(arrowStart + #"→"))
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "deliveryPaper",
        payload = {
            routeId = data.routeId or route.id,
            label = label,
            from = from,
            to = to,
            cargo = data.cargo or route.cargo,
            distKm = data.breakdown.distKm,
            elapsed = data.breakdown.elapsed,
            payment = data.breakdown.total,
            currency = data.currency or Config.Currency or "$",
            breakdown = data.breakdown,
        },
    })
end)

RegisterNetEvent("oxlyn-truckjob:client:signDelivery", function()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "deliveryPaperClose" })

    if not (Truck.onDuty and Truck.pickupReached and Truck.activeRoute) then return end
    startUnloading(Truck.activeRoute, { skipProgress = true })
end)

RegisterNetEvent("oxlyn-truckjob:client:cancelDeliveryPaper", function()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "deliveryPaperClose" })
end)

---------------------------------------------------------------------
-- Starting a route
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:client:startRoute", function(routeId)
    if Truck.onDuty then
        Notify.Send(nil, _U("job_in_progress"), "warning")
        return
    end

    if GetGameTimer() < Truck.cooldownUntil then
        local remaining = math.ceil((Truck.cooldownUntil - GetGameTimer()) / 1000)
        Notify.Send(nil, _U("err_cooldown", remaining), "warning")
        return
    end

    TriggerServerEvent("oxlyn-truckjob:server:requestStart", routeId)
end)

RegisterNetEvent("oxlyn-truckjob:client:onStartConfirmed", function(data)
    if not (type(data) == "table" and data.pickup) then return end

    local route = {
        id = data.id,
        label = data.label,
        cargo = data.cargo,
        difficulty = data.difficulty,
        value = data.value,
        image = data.image,
        trailer = data.trailer,
        pickup = vector3(data.pickup.x, data.pickup.y, data.pickup.z),
        deliveries = {},
        pickupHeading = data.pickupHeading or 0.0,
        pickupLocked = data.pickupLocked or false,
    }

    for _, d in ipairs(data.deliveries or {}) do
        route.deliveries[#route.deliveries + 1] = vector3(d.x, d.y, d.z)
    end

    if #route.deliveries == 0 then
        Notify.Send(nil, _U("err_no_truck"), "error")
        return
    end

    -- Clean up leftovers from a previous run
    if Truck.truckEntity and DoesEntityExist(Truck.truckEntity) then
        DeleteEntity(Truck.truckEntity)
    end
    if Truck.pickupTrailer and DoesEntityExist(Truck.pickupTrailer) then
        DeleteEntity(Truck.pickupTrailer)
    end

    Truck.truckEntity = spawnTruck()
    if not Truck.truckEntity then
        Notify.Send(nil, _U("err_no_truck"), "error")
        return
    end
    trackNetworked(Truck.truckEntity, "truck")

    -- Pick a random delivery point when there are several
    if #route.deliveries >= 2 then
        Truck.deliveryCoord = route.deliveries[math.random(#route.deliveries)]
    else
        Truck.deliveryCoord = route.deliveries[1]
    end

    Truck.trailerEntity = nil
    Truck.trailerNet = nil
    Truck.pickupTrailer = nil
    Truck.pickupTrailerNet = nil
    Truck.pickupBlockedWarned = false

    SetPedIntoVehicle(PlayerPedId(), Truck.truckEntity, -1)

    -- Make sure the truck is in good shape right after spawning
    CreateThread(function()
        for i = 1, 4 do
            Wait(80)
            if Truck.truckEntity and DoesEntityExist(Truck.truckEntity) then
                SetVehicleFixed(Truck.truckEntity)
                SetVehicleUndriveable(Truck.truckEntity, false)
                SetVehicleEngineOn(Truck.truckEntity, true, true, false)
                if i == 1 and VehicleKeys and VehicleKeys.Give then
                    VehicleKeys.Give(Truck.truckEntity)
                end
            end
        end
    end)

    Truck.onDuty = true
    Truck.activeRoute = route
    Truck.startTime = GetGameTimer()
    Truck.distanceM = 0
    Truck.damageHits = 0
    Truck.pickupReached = false
    Truck.lastPos = GetEntityCoords(PlayerPedId())

    local tripDist = #(route.pickup - Truck.deliveryCoord)
    Truck.initialDistM = (tripDist > 100.0 and tripDist) or 1000.0

    local pickupDist = #(GetEntityCoords(PlayerPedId()) - route.pickup)
    Truck.initialPickupDistM = (pickupDist > 50.0 and pickupDist) or 200.0

    Truck.AddRouteBlip(route.pickup, _U("goto_pickup"))
    Notify.Send(nil, _U("job_started"), "success")

    SendNUIMessage({
        action = "route_started",
        route = { id = route.id, label = route.label, cargo = route.cargo },
    })

    -- Roll random events for this job
    Truck.flatTire = nil
    Truck.tireBurstAt = nil

    local tire = Config.TireBurst
    if tire and tire.enabled and math.random() <= (tire.chance or 0.95) then
        local minDelay = tire.minDelay or 30
        local maxDelay = math.max(minDelay + 1, tire.maxDelay or 240)
        Truck.tireBurstAt = GetGameTimer() + math.random(minDelay, maxDelay) * 1000
    end

    Truck.engineCanOverheat = false
    Truck.engineOverheatedOnce = false
    Truck.trailerDetachWanted = false
    Truck.trailerDetachAt = nil
    Truck.trailerDetached = false
    Truck.trailerDetachedOnce = false

    local engineCfg = cfgEngine()
    local detachCfg = cfgDetach()
    local engineChance = (engineCfg.enabled and engineCfg.chance) or 0
    local detachChance = (detachCfg.enabled and detachCfg.chance) or 0

    -- Only one of the two events can happen per job
    local roll = math.random()
    if engineChance > roll then
        Truck.engineCanOverheat = true
    elseif roll < engineChance + detachChance then
        Truck.trailerDetachWanted = true
    end
end)

---------------------------------------------------------------------
-- Cancelling a job
---------------------------------------------------------------------
local function cleanupTrailers()
    local hauled = Truck.trailerEntity
    local waiting = getPickupTrailer()
    Truck.trailerEntity = nil
    Truck.pickupTrailer = nil

    if hauled and DoesEntityExist(hauled) then deleteVehicleSafe(hauled) end
    if waiting and DoesEntityExist(waiting) then deleteVehicleSafe(waiting) end
end

-- Cancels the job client-side and notifies the server. `reason` is a locale key.
local function cancelJob(reason, ...)
    if not Truck.onDuty then return end

    CreateThread(function()
        removeTruck()
        cleanupTrailers()
        resetJobState()
    end)

    if reason then
        Notify.Send(nil, _U(reason, ...), "warning", 6500)
    else
        Notify.Send(nil, _U("job_canceled"), "info")
    end

    SendNUIMessage({ action = "route_canceled" })
    TriggerServerEvent("oxlyn-truckjob:server:cancel", reason or "manual")
end

RegisterNetEvent("oxlyn-truckjob:client:cancel", function()
    if not Truck.onDuty or busy then return end
    cancelJob(nil)
end)

RegisterNetEvent("oxlyn-truckjob:client:cancelByServer", function(reason, args)
    if not Truck.onDuty then return end

    CreateThread(function()
        removeTruck()
        cleanupTrailers()
        resetJobState()
    end)

    if reason then
        Notify.Send(nil, _U(reason, table.unpack(args or {})), "error", 7000)
    else
        Notify.Send(nil, _U("job_canceled"), "info")
    end

    SendNUIMessage({ action = "route_canceled" })
end)

---------------------------------------------------------------------
-- Anti-abuse (destroyed vehicles, idling, wandering off)
---------------------------------------------------------------------
local function resetAbuseTimers()
    idleSince, idleWarned = 0, false
    awaySince, awayWarned = 0, false
end

CreateThread(function()
    while true do
        Wait(1000)

        local cfg = cfgAntiAbuse()
        if busy or not Truck.onDuty or not cfg.enabled then
            resetAbuseTimers()
            goto continue
        end

        do
            local truck = Truck.truckEntity

            -- Truck gone / destroyed
            if not (truck and DoesEntityExist(truck)) then
                if cfg.cancelOnTruckDestroyed then
                    cancelJob("err_truck_destroyed")
                end
                goto continue
            end

            if IsEntityDead(truck) or (IsVehicleWrecked and IsVehicleWrecked(truck)) then
                if cfg.cancelOnTruckDestroyed then
                    cancelJob("err_truck_destroyed")
                    goto continue
                end
            end

            -- Trailer destroyed
            if Truck.pickupReached and cfg.cancelOnTrailerDestroyed then
                local trailer = Truck.trailerEntity
                if trailer and DoesEntityExist(trailer) then
                    if IsEntityDead(trailer) or (IsVehicleWrecked and IsVehicleWrecked(trailer)) then
                        cancelJob("err_trailer_destroyed")
                    end
                end
            end

            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local truckCoords = GetEntityCoords(truck)
            local distToTruck = #(pedCoords - truckCoords)
            local truckSpeed = GetEntitySpeed(truck)
            local hasDriver = GetPedInVehicleSeat(truck, -1) ~= 0

            -- Idle: truck stationary and nobody driving it
            if truckSpeed < 0.4 and not hasDriver then
                if idleSince == 0 then
                    idleSince = GetGameTimer()
                    idleWarned = false
                else
                    local idleFor = (GetGameTimer() - idleSince) / 1000
                    local timeout = cfg.idleTimeout or 90
                    local grace = cfg.idleGrace or 30
                    if not idleWarned and idleFor >= timeout then
                        idleWarned = true
                        Notify.Send(nil, _U("err_idle_warn", math.floor(grace)), "warning", 6000)
                    elseif idleWarned and idleFor >= timeout + grace then
                        cancelJob("err_idle_cancel")
                    end
                end
            else
                idleSince, idleWarned = 0, false
            end

            -- Player wandered too far from the truck
            local awayDistance = cfg.driverAwayDistance or 60.0
            if distToTruck > awayDistance then
                if awaySince == 0 then
                    awaySince = GetGameTimer()
                    awayWarned = false
                else
                    local awayFor = (GetGameTimer() - awaySince) / 1000
                    local timeout = cfg.driverAwayTimeout or 60
                    local grace = cfg.driverAwayGrace or 30
                    if not awayWarned and awayFor >= timeout then
                        awayWarned = true
                        Notify.Send(nil, _U("err_away_warn", math.floor(grace)), "warning", 6000)
                    elseif awayWarned and awayFor >= timeout + grace then
                        cancelJob("err_away_cancel")
                    end
                end
            else
                awaySince, awayWarned = 0, false
            end
        end

        ::continue::
    end
end)

-- Cancel key (X)
CreateThread(function()
    while true do
        Wait(0)
        if Truck.onDuty and not busy and IsControlJustReleased(0, 73) then
            TriggerEvent("oxlyn-truckjob:client:cancel")
        end
    end
end)

---------------------------------------------------------------------
-- Random event: flat tire
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:client:repairItemResult", function(requestId, success)
    local p = pendingRepairs[requestId]
    if not p then return end
    pendingRepairs[requestId] = nil
    p:resolve(success == true)
end)

-- Asks the server whether the player has (and consumes) the repair item. Times out after 8s.
local function requestRepairItem(kind)
    repairRequestId = repairRequestId + 1
    local id = repairRequestId
    local p = promise.new()
    pendingRepairs[id] = p

    TriggerServerEvent("oxlyn-truckjob:server:useRepairItem", kind, id)

    SetTimeout(8000, function()
        if pendingRepairs[id] then
            pendingRepairs[id] = nil
            p:resolve(false)
        end
    end)

    return Citizen.Await(p)
end

local function getWheelPosition(vehicle, wheelIndex)
    if not (vehicle and DoesEntityExist(vehicle)) then return nil end

    local boneName = WHEEL_BONES[wheelIndex]
    if not boneName then return nil end

    local bone = GetEntityBoneIndexByName(vehicle, boneName)
    if bone < 0 then
        -- Fallback: estimate the wheel position from the vehicle's orientation
        local coords = GetEntityCoords(vehicle)
        local fwd = GetEntityForwardVector(vehicle)
        local right = vector3(fwd.y, -fwd.x, 0.0)
        local frontBack = (wheelIndex == 0 or wheelIndex == 1) and 1.0 or -1.0
        local leftRight = (wheelIndex == 0 or wheelIndex == 4) and -1.0 or 1.0
        return vector3(
            coords.x + fwd.x * (2.0 * frontBack) + right.x * (1.0 * leftRight),
            coords.y + fwd.y * (2.0 * frontBack) + right.y * (1.0 * leftRight),
            coords.z - 0.3
        )
    end
    return GetWorldPositionOfEntityBone(vehicle, bone)
end

local function burstRandomTire()
    local truck = Truck.truckEntity
    if not (truck and DoesEntityExist(truck)) then return end

    local candidates = cfgTire().candidates or { 0, 1, 4, 5 }

    -- Prefer a tire that isn't already burst
    local wheel
    for _ = 1, 6 do
        local pick = candidates[math.random(#candidates)]
        if not IsVehicleTyreBurst(truck, pick, false) then
            wheel = pick
            break
        end
    end
    wheel = wheel or candidates[math.random(#candidates)]

    SetVehicleTyreBurst(truck, wheel, true, 1000.0)
    SetVehicleDoorsLocked(truck, 2)
    Truck.flatTire = wheel
    Truck.tireBurstAt = nil

    Notify.Send(nil, _U("tire_blew"), "warning", 6500)
end

local function repairTire()
    if busy then return end

    local cfg = cfgTire()
    local truck = Truck.truckEntity
    if not (truck and DoesEntityExist(truck)) then return end
    if Truck.flatTire == nil then return end

    busy = true
    hidePrompt()

    if cfg.requireItem and not requestRepairItem("tire") then
        Notify.Send(nil, _U("tire_need_item", cfg.itemLabel or cfg.item), "error", 5500)
        busy = false
        return
    end

    local ped = PlayerPedId()

    -- Face the wheel
    local wheelPos = getWheelPosition(truck, Truck.flatTire)
    if wheelPos then
        local pedCoords = GetEntityCoords(ped)
        SetEntityHeading(ped, GetHeadingFromVector_2d(wheelPos.x - pedCoords.x, wheelPos.y - pedCoords.y))
    end

    local dict, anim = "mini@repair", "fixing_a_player"
    local animLoaded = loadAnimDict(dict)
    if animLoaded then
        TaskPlayAnim(ped, dict, anim, 6.0, -6.0, -1, 1, 0.0, false, false, false)
    end

    progress(_U("tire_repairing"), cfg.repairDuration or 6000)

    if animLoaded then StopAnimTask(ped, dict, anim, 3.0) end
    ClearPedTasks(ped)
    RemoveAnimDict(dict)

    if truck and DoesEntityExist(truck) and Truck.flatTire then
        SetVehicleTyreFixed(truck, Truck.flatTire)
        SetVehicleDoorsLocked(truck, 1)
    end
    Truck.flatTire = nil

    Notify.Send(nil, _U("tire_repaired"), "success", 4500)
    busy = false
end

-- Trigger the scheduled tire burst while the player is driving
CreateThread(function()
    while true do
        Wait(800)
        if Truck.onDuty and Truck.tireBurstAt and not Truck.flatTire then
            if GetGameTimer() >= Truck.tireBurstAt then
                local truck = Truck.truckEntity
                if truck and DoesEntityExist(truck) then
                    if GetPedInVehicleSeat(truck, -1) == PlayerPedId() then
                        burstRandomTire()
                    end
                end
            end
        end
    end
end)

-- Keep the tire burst (and the doors locked) if something fixed it
CreateThread(function()
    while true do
        Wait(1500)
        if Truck.onDuty and Truck.flatTire ~= nil then
            local truck = Truck.truckEntity
            if truck and DoesEntityExist(truck) then
                if not IsVehicleTyreBurst(truck, Truck.flatTire, false) then
                    SetVehicleTyreBurst(truck, Truck.flatTire, true, 1000.0)
                    SetVehicleDoorsLocked(truck, 2)
                end
            end
        end
    end
end)

-- Marker + prompt at the flat tire
CreateThread(function()
    while true do
        local sleep = 500

        if Truck.onDuty and Truck.flatTire ~= nil and not busy then
            local truck = Truck.truckEntity
            local ped = PlayerPedId()

            if truck and DoesEntityExist(truck) and not IsPedInAnyVehicle(ped, false) then
                local wheelPos = getWheelPosition(truck, Truck.flatTire)
                if wheelPos then
                    local dist = #(GetEntityCoords(ped) - wheelPos)
                    local interactDist = cfgTire().interactDist or 2.5

                    if dist < 14.0 then
                        sleep = 0
                        DrawMarker(25, wheelPos.x, wheelPos.y, wheelPos.z - 0.25,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            0.85, 0.85, 0.35,
                            239, 68, 68, 140,
                            false, false, 2, false, nil, nil, false)

                        if dist < interactDist then
                            showPrompt(_U("tire_label"), _U("tire_hint"))
                            if IsControlJustReleased(0, 38) then
                                repairTire()
                            end
                        else
                            hidePrompt()
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- Random event: engine overheating
---------------------------------------------------------------------
local function loadCoreParticles()
    if HasNamedPtfxAssetLoaded("core") then return true end
    RequestNamedPtfxAsset("core")
    local deadline = GetGameTimer() + 1200
    while not HasNamedPtfxAssetLoaded("core") and deadline > GetGameTimer() do
        Wait(10)
    end
    return HasNamedPtfxAssetLoaded("core")
end

local function startSmoke(vehicle)
    if smokeFx or not (vehicle and DoesEntityExist(vehicle)) then return end
    if not loadCoreParticles() then return end

    UseParticleFxAsset("core")
    local bone = GetEntityBoneIndexByName(vehicle, "engine")
    if bone < 0 then bone = 0 end

    smokeFx = StartParticleFxLoopedOnEntityBone(
        "exp_grd_grenade_smoke", vehicle,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        bone, 0.6,
        false, false, false)
end

local function stopSmoke()
    if smokeFx then
        StopParticleFxLooped(smokeFx, false)
        smokeFx = nil
    end
end

local function overheatEngine()
    local truck = Truck.truckEntity
    if not (truck and DoesEntityExist(truck)) then return end

    Truck.engineOverheating = true
    SetVehicleEngineHealth(truck, 150.0)
    SetVehicleMaxSpeed(truck, 10.0)
    startSmoke(truck)

    Notify.Send(nil, _U("engine_overheat"), "warning", 7000)
end

local function coolEngine()
    if busy then return end

    local cfg = cfgEngine()
    local truck = Truck.truckEntity
    if not (truck and DoesEntityExist(truck)) then return end
    if not Truck.engineOverheating then return end

    busy = true
    hidePrompt()

    if cfg.requireItem and not requestRepairItem("engine") then
        Notify.Send(nil, _U("engine_need_item", cfg.itemLabel or cfg.item), "error", 5500)
        busy = false
        return
    end

    local ped = PlayerPedId()
    local truckCoords = GetEntityCoords(truck)
    local pedCoords = GetEntityCoords(ped)
    SetEntityHeading(ped, GetHeadingFromVector_2d(truckCoords.x - pedCoords.x, truckCoords.y - pedCoords.y))

    local dict, anim = "mini@repair", "fixing_a_ped"
    local animLoaded = loadAnimDict(dict)
    if animLoaded then
        TaskPlayAnim(ped, dict, anim, 6.0, -6.0, -1, 1, 0.0, false, false, false)
    end

    progress(_U("engine_cooling"), cfg.repairDuration or 8000)

    if animLoaded then StopAnimTask(ped, dict, anim, 3.0) end
    ClearPedTasks(ped)

    if truck and DoesEntityExist(truck) then
        SetVehicleEngineHealth(truck, 1000.0)
        SetVehicleMaxSpeed(truck, 0.0) -- 0.0 removes the speed cap
        stopSmoke()
    end

    Truck.engineOverheating = false
    Truck.engineOverheatedOnce = true
    engineHeat = 0

    Notify.Send(nil, _U("engine_repaired"), "success", 4500)
    busy = false
end

-- Heat builds while driving fast, cools down otherwise
CreateThread(function()
    while true do
        Wait(1000)
        if Truck.onDuty and Truck.truckEntity and DoesEntityExist(Truck.truckEntity)
            and not Truck.engineOverheating and not Truck.engineOverheatedOnce
            and Truck.engineCanOverheat then

            local speedKmh = GetEntitySpeed(Truck.truckEntity) * 3.6
            local cfg = cfgEngine()

            if speedKmh > (cfg.heatSpeed or 70) then
                engineHeat = math.min(100, engineHeat + (cfg.heatPerSec or 0.55))
            else
                engineHeat = math.max(0, engineHeat - (cfg.coolPerSec or 0.4))
            end

            if engineHeat >= 100 then
                overheatEngine()
            end
        end
    end
end)

-- Keep the overheated engine crippled
CreateThread(function()
    while true do
        Wait(1200)
        if Truck.onDuty and Truck.engineOverheating and Truck.truckEntity and DoesEntityExist(Truck.truckEntity) then
            SetVehicleMaxSpeed(Truck.truckEntity, 10.0)
            if GetVehicleEngineHealth(Truck.truckEntity) > 250.0 then
                SetVehicleEngineHealth(Truck.truckEntity, 150.0)
            end
        end
    end
end)

-- Marker + prompt at the front of the overheated truck
CreateThread(function()
    while true do
        local sleep = 500

        if Truck.onDuty and Truck.engineOverheating and not busy then
            local truck = Truck.truckEntity
            local ped = PlayerPedId()

            if truck and DoesEntityExist(truck) and not IsPedInAnyVehicle(ped, false) then
                local coords = GetEntityCoords(truck)
                local fwd = GetEntityForwardVector(truck)
                local hoodPos = vector3(coords.x + fwd.x * 2.4, coords.y + fwd.y * 2.4, coords.z + 0.2)
                local dist = #(GetEntityCoords(ped) - hoodPos)
                local interactDist = cfgEngine().interactDist or 3.5

                if dist < 14.0 then
                    sleep = 0
                    DrawMarker(25, hoodPos.x, hoodPos.y, hoodPos.z - 0.55,
                        0, 0, 0, 0, 0, 0,
                        1.1, 1.1, 0.4,
                        245, 158, 11, 140,
                        false, false, 2, false, nil, nil, false)

                    if dist < interactDist then
                        showPrompt(_U("engine_label"), _U("engine_hint"))
                        if IsControlJustReleased(0, 38) then
                            coolEngine()
                        end
                    else
                        hidePrompt()
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- Random event: trailer comes loose
---------------------------------------------------------------------
local function detachTrailerRandomly()
    local truck = Truck.truckEntity
    local trailer = Truck.trailerEntity
    if not (truck and DoesEntityExist(truck) and trailer and DoesEntityExist(trailer)) then return end
    if not IsVehicleAttachedToTrailer(truck) then return end

    DetachVehicleFromTrailer(trailer)
    SetVehicleHandbrake(trailer, true)
    Truck.trailerDetached = true
    Truck.trailerDetachAt = nil

    Notify.Send(nil, _U("trailer_detached"), "warning", 7000)
end

local function reattachTrailer()
    if busy then return end

    local cfg = cfgDetach()
    local truck = Truck.truckEntity
    local trailer = Truck.trailerEntity
    if not (truck and DoesEntityExist(truck) and trailer and DoesEntityExist(trailer)) then return end

    local dist = #(GetEntityCoords(truck) - GetEntityCoords(trailer))
    if dist > (cfg.hitchDistance or 12.0) then
        Notify.Send(nil, _U("trailer_too_far"), "warning", 4000)
        return
    end

    busy = true
    hidePrompt()

    SetVehicleHandbrake(trailer, false)
    AttachVehicleToTrailer(truck, trailer, 5.0)
    Truck.trailerDetached = false
    Truck.trailerDetachedOnce = true

    Notify.Send(nil, _U("trailer_reattached"), "success", 4500)
    busy = false
end

-- Fire the scheduled detach while the player is driving
CreateThread(function()
    while true do
        Wait(800)
        if Truck.onDuty and Truck.trailerDetachAt and not Truck.trailerDetached and not Truck.trailerDetachedOnce then
            if GetGameTimer() >= Truck.trailerDetachAt then
                local truck = Truck.truckEntity
                local trailer = Truck.trailerEntity
                if truck and DoesEntityExist(truck) and trailer and DoesEntityExist(trailer)
                    and IsVehicleAttachedToTrailer(truck)
                    and GetPedInVehicleSeat(truck, -1) == PlayerPedId() then
                    detachTrailerRandomly()
                end
            end
        end
    end
end)

-- Marker + prompt at the loose trailer
CreateThread(function()
    while true do
        local sleep = 500

        if Truck.onDuty and Truck.trailerDetached and not busy then
            local truck = Truck.truckEntity
            local trailer = Truck.trailerEntity
            local ped = PlayerPedId()

            if truck and DoesEntityExist(truck) and trailer and DoesEntityExist(trailer)
                and not IsPedInAnyVehicle(ped, false) then
                local trailerCoords = GetEntityCoords(trailer)
                local dist = #(GetEntityCoords(ped) - trailerCoords)

                if dist < 30.0 then
                    sleep = 0
                    DrawMarker(25, trailerCoords.x, trailerCoords.y, trailerCoords.z - 0.4,
                        0, 0, 0, 0, 0, 0,
                        2.8, 2.8, 0.5,
                        245, 158, 11, 130,
                        false, false, 2, false, nil, nil, false)

                    if dist < 3.5 then
                        showPrompt(_U("trailer_label"), _U("trailer_hint"))
                        if IsControlJustReleased(0, 38) then
                            reattachTrailer()
                        end
                    else
                        hidePrompt()
                    end
                end
            end
        end

        Wait(sleep)
    end
end)