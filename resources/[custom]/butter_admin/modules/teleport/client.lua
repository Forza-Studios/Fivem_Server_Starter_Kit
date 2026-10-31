local GROUND_PROBE_MAX = 800.0
local GROUND_PROBE_STEP = 50.0
local LOAD_TIMEOUT = 1000 -- ms

---@param x number
---@param y number
---@param z number
local function warpTo(x, y, z)
    if AdminState.noclip then return TeleportNoclip(vector3(x, y, z)) end
    SetPedCoordsKeepVehicle(cache.ped, x, y, z)
end

--- Finds the ground at a map position by streaming the area in at increasing
--- heights. Probing upward finds the lowest surface, so a waypoint under a
--- bridge lands on the road rather than the deck.
---@param x number
---@param y number
---@return number? groundZ
local function findGroundZ(x, y)
    for height = 0.0, GROUND_PROBE_MAX, GROUND_PROBE_STEP do
        local startedAt = GetGameTimer()
        NewLoadSceneStart(x, y, height, x, y, height, 20.0, 0)
        while IsNetworkLoadingScene() and GetGameTimer() - startedAt < LOAD_TIMEOUT do Wait(0) end
        NewLoadSceneStop()

        warpTo(x, y, height)
        while not HasCollisionLoadedAroundEntity(cache.ped) and GetGameTimer() - startedAt < LOAD_TIMEOUT do
            RequestCollisionAtCoord(x, y, height)
            Wait(0)
        end

        local found, groundZ = GetGroundZFor_3dCoord(x, y, height, false)
        if found then return groundZ end
        Wait(0)
    end
end

--- Teleports to a waypoint, resolving the ground height behind a screen fade.
---@param coords vector3
---@return boolean found
local function teleportToGround(coords)
    local ped = cache.ped
    local vehicle = GetVehiclePedIsIn(ped, false)
    local frozenEntity = vehicle ~= 0 and vehicle or ped
    local startCoords = GetEntityCoords(ped)

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    FreezeEntityPosition(frozenEntity, true)

    local groundZ = findGroundZ(coords.x, coords.y)
    if groundZ then
        warpTo(coords.x, coords.y, groundZ)
    else
        warpTo(startCoords.x, startCoords.y, startCoords.z)
    end

    FreezeEntityPosition(frozenEntity, false)
    DoScreenFadeIn(500)
    return groundZ ~= nil
end

---@param coords vector3|table
---@param isWaypoint? boolean
local function teleport(coords, isWaypoint)
    if isWaypoint then return teleportToGround(coords) end
    warpTo(coords.x, coords.y, coords.z)
    return true
end

---@return vector3?
local function getWaypointCoords()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return nil end
    return GetBlipInfoIdCoord(blip)
end

AddEventHandler('butter_admin:client:teleportToMarker', function()
    if not IsAuthorizedRemote('teleportToMarker') then return end

    local coords = getWaypointCoords()
    if not coords then return Notify(locale('teleport.no_waypoint'), 'error') end
    if not teleportToGround(coords) then return Notify(locale('teleport.no_waypoint'), 'error') end
    Notify(locale('teleport.waypoint_success'), 'success')
end)

AddEventHandler('butter_admin:client:teleportToCoords', function(options)
    if type(options) ~= 'table' then return end
    local x, y, z = tonumber(options['x-coord']), tonumber(options['y-coord']), tonumber(options['z-coord'])
    if not x or not y or not z then return Notify(locale('notify.invalid_coords'), 'error') end
    if not IsAuthorizedRemote('teleportCoords') then return end

    CloseAdminMenu()
    teleport(vector3(x, y, z))
    Notify(locale('teleport.coords_success', x, y, z), 'success')
end)

-- Sends another player to this admin's waypoint.
AddEventHandler('butter_admin:client:teleportPlayerToMarker', function(options)
    local target = type(options) == 'table' and tonumber(options.player)
    if not target then return end

    local coords = getWaypointCoords()
    if not coords then return Notify(locale('teleport.no_waypoint'), 'error') end
    TriggerServerEvent('butter_admin:server:teleportPlayerToCoords', { player = target, coords = coords, isWaypoint = true })
end)

RegisterNetEvent('butter_admin:client:teleport', function(coords, isWaypoint)
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return end
    teleport(coords, isWaypoint == true)
end)

---@param vehicle number
---@return integer seat
local function findFreeSeat(vehicle)
    if IsVehicleSeatFree(vehicle, -1) then return -1 end
    local passengers = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = 0, passengers - 1 do
        if IsVehicleSeatFree(vehicle, seat) then return seat end
    end
    return passengers > 0 and 0 or -1
end

RegisterNetEvent('butter_admin:client:teleportIntoVehicle', function(netId, coords)
    local ped = cache.ped
    local vehicle = NetworkGetEntityFromNetworkId(netId)

    if IsPedInAnyVehicle(ped, false) then
        ClearPedTasksImmediately(ped)
        Wait(50)
    end

    -- Move next to the target first so their vehicle streams in.
    if not DoesEntityExist(vehicle) and coords then
        if AdminState.noclip then
            TeleportNoclip(coords)
        else
            FreezeEntityPosition(ped, true)
            SetEntityCollision(ped, false, false)
            SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        end

        for _ = 1, 100 do
            vehicle = NetworkGetEntityFromNetworkId(netId)
            if DoesEntityExist(vehicle) then break end
            Wait(50)
        end
    end

    if not DoesEntityExist(vehicle) then
        if not AdminState.noclip then
            FreezeEntityPosition(ped, false)
            SetEntityCollision(ped, true, true)
        end
        return Notify(locale('notify.vehicle_not_found_locally'), 'error')
    end

    -- Warping while in noclip breaks the camera and ped state.
    if AdminState.noclip then
        TriggerEvent('butter_admin:client:toggleNoclip')
        Wait(100)
    end

    -- Collision stays off while warping so a moving vehicle can't ragdoll the ped.
    local vehicleCoords = GetEntityCoords(vehicle)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    SetEntityNoCollisionEntity(ped, vehicle, true)
    SetEntityCoords(ped, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, false, false, false, false)
    Wait(50)

    local seat = findFreeSeat(vehicle)
    SetPedIntoVehicle(ped, vehicle, seat)
    TaskWarpPedIntoVehicle(ped, vehicle, seat)
    Wait(200)

    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityNoCollisionEntity(ped, vehicle, false)
    Notify(locale('notify.teleport_target_vehicle_success'), 'success')
end)
