--[[
    PlaneNav - Plane Navigation System
    Shows airport locations when in plane
]]

local Locations = {}
local PlaneNavOpen = false
local currentIndex = 1
local IsInPlane = false
local CircularPageOpen = false

-- Load locations using shared utility
local function LoadLocations()
    local data = Utils.Nav.LoadLocationsFromJSON('shared/data/planenav-locations.json', 'PlaneNav')
    if data then
        Locations = Utils.Nav.ParseSimpleLocations(data)
    end
end

LoadLocations()

local function UpdateLocation()
    if not PlaneNavOpen then return end

    local coords, distance, name = Utils.Nav.GetLocation(Locations, currentIndex)

    NuiMessage('planenav:updateLocation', {
        name = name or 'Unknown',
        distance = distance or 0,
        index = currentIndex,
        totalLocations = #Locations
    })
end

RegisterNUICallback('circularPageOpened', function(data, cb)
    CircularPageOpen = true
    IsInPlane = data.isPlane or false
    cb('ok')
end)

RegisterNUICallback('circularPageClosed', function(_, cb)
    CircularPageOpen = false
    cb('ok')
end)

RegisterNUICallback('planenav:opened', function(_, cb)
    PlaneNavOpen = true
    currentIndex = 1
    UpdateLocation()
    cb('ok')
end)

RegisterNUICallback('planenav:closed', function(_, cb)
    PlaneNavOpen = false
    cb('ok')
end)

RegisterNUICallback('planenav:categoryChanged', function(data, cb)
    local index = tonumber(data.category) or 1
    if index >= 1 and index <= #Locations then
        currentIndex = index
        UpdateLocation()
    end
    cb('ok')
end)

RegisterNUICallback('planenav:setWaypoint', function(data, cb)
    local index = tonumber(data.category) or currentIndex

    local coords, distance, name = Utils.Nav.GetLocation(Locations, index)
    if coords then
        Utils.Nav.SetWaypoint(coords)
        local distText = string.format('%.1f', distance)
        Notify(L('nav.gps_set_to', name, distText), 'success')
        cb({ success = true, distance = distance, name = name })
    else
        cb({ success = false, message = L('nav.no_location_found') })
    end
end)

-- Minimap tilt prevention for plane circular page
CreateThread(function()
    while true do
        if IsInPlane and CircularPageOpen then
            DontTiltMinimapThisFrame()
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Input thread using shared utility
Utils.Nav.CreateInputThread({
    isOpen = function() return PlaneNavOpen end,
    prefix = 'planenav'
})

-- ============================================================
-- PLANE SETTINGS - Autopilot & Landing Gear
-- ============================================================

AutopilotEnabled = false
local AutopilotThread = nil

local function GetCurrentPlane()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return 0 end
    if GetVehicleClass(vehicle) ~= 16 then return 0 end
    return vehicle
end

-- Landing Gear: 0 = deployed, 1 = closing, 2 = opening, 3 = retracted
local function ToggleLandingGear(gearDown)
    local vehicle = GetCurrentPlane()
    if vehicle == 0 then return false end

    if gearDown then
        ControlLandingGear(vehicle, 0) -- Deploy
    else
        ControlLandingGear(vehicle, 3) -- Retract
    end
    return true
end

local AUTOPILOT_DEACTIVATE_DISTANCE = 500.0 -- 500 meters from waypoint

local function GetWaypointCoords()
    if not IsWaypointActive() then return nil end
    local blip = GetFirstBlipInfoId(8) -- 8 = waypoint blip
    if not DoesBlipExist(blip) then return nil end
    local coords = GetBlipInfoIdCoord(blip)
    return vector3(coords.x, coords.y, coords.z)
end

local function StopAutopilot(vehicle, reason)
    AutopilotEnabled = false
    if AutopilotThread then
        AutopilotThread = nil
    end
    ClearPedTasks(PlayerPedId())
    NuiMessage('plane:setAutopilotState', { enabled = false })
    if reason then
        Notify(reason, 'primary')
    end
end

local function StartAutopilot(vehicle)
    if vehicle == 0 then return false end
    AutopilotEnabled = true

    if AutopilotThread then return true end

    local autopilotAltitude = GetEntityCoords(vehicle).z
    local autopilotSpeed = GetEntitySpeed(vehicle)

    AutopilotThread = CreateThread(function()
        while AutopilotEnabled do
            local veh = GetCurrentPlane()
            if veh == 0 then
                StopAutopilot(veh, L('autopilot.deactivated_left'))
                break
            end

            local coords = GetEntityCoords(veh)
            local waypointCoords = GetWaypointCoords()
            local targetX, targetY, targetZ

            if waypointCoords then
                local dist = #(vector2(coords.x, coords.y) - vector2(waypointCoords.x, waypointCoords.y))

                if dist <= AUTOPILOT_DEACTIVATE_DISTANCE then
                    StopAutopilot(veh, L('autopilot.deactivated_close'))
                    break
                end

                targetX = waypointCoords.x
                targetY = waypointCoords.y
                targetZ = autopilotAltitude
            else
                local forwardVector = GetEntityForwardVector(veh)
                targetX = coords.x + forwardVector.x * 500.0
                targetY = coords.y + forwardVector.y * 500.0
                targetZ = autopilotAltitude
            end

            TaskPlaneMission(PlayerPedId(), veh, 0, 0, targetX, targetY, targetZ, 4, autopilotSpeed * 3.6, 0.0, GetEntityHeading(veh), autopilotSpeed * 2.0, autopilotSpeed * 0.5, false)

            Wait(1000)
        end
        AutopilotThread = nil
    end)

    -- Separate thread for manual control detection
    CreateThread(function()
        -- Grace period
        Wait(3000)

        while AutopilotEnabled do
            -- Only detect deliberate key presses (W/S/A/D/space)
            if IsControlPressed(0, 32) or IsControlPressed(0, 33) or  -- W/S (throttle)
               IsControlPressed(0, 34) or IsControlPressed(0, 35) then -- A/D (yaw)
                StopAutopilot(GetCurrentPlane(), L('autopilot.deactivated_manual'))
                break
            end
            Wait(0)
        end
    end)
    return true
end

RegisterNUICallback('plane:toggleAutopilot', function(data, cb)
    local vehicle = GetCurrentPlane()
    if vehicle == 0 then
        cb({ success = false })
        return
    end

    local enabled = data.enabled
    if enabled then
        StartAutopilot(vehicle)
    else
        StopAutopilot(vehicle)
    end
    cb({ success = true, enabled = AutopilotEnabled })
end)

RegisterNUICallback('plane:toggleLandingGear', function(data, cb)
    local gearDown = data.gearDown
    local success = ToggleLandingGear(gearDown)
    cb({ success = success, gearDown = gearDown })
end)

RegisterNUICallback('plane:getState', function(_, cb)
    local vehicle = GetCurrentPlane()
    local gearState = 0
    if vehicle ~= 0 then
        gearState = GetLandingGearState(vehicle)
    end
    local gearDown = (gearState == 0 or gearState == 2) -- 0=deployed, 2=opening(deploying)

    NuiMessage('plane:setAutopilotState', { enabled = AutopilotEnabled })
    NuiMessage('plane:setGearState', { gearDown = gearDown })

    cb({ autopilotEnabled = AutopilotEnabled, gearDown = gearDown })
end)

RegisterNetEvent('codem-hud:client:baseevents:leftVehicle', function()
    if AutopilotEnabled then
        StopAutopilot(0)
    end
end)

AddEventHandler('codem-hud:client:baseevents:vehicleSwapped', function()
    if AutopilotEnabled then
        StopAutopilot(0)
    end
end)

debugPrint('[PlaneNav] Module loaded with', #Locations, 'locations')
