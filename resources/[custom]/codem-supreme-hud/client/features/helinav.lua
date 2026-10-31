--[[
    HeliNav - Helicopter Navigation System
    Shows helipad/landing locations when in helicopter
]]

-- Load locations from JSON file
local Locations = {}

local function LoadLocationsFromJSON()
    local jsonFile = LoadResourceFile(GetCurrentResourceName(), 'shared/data/helinav-locations.json')
    if not jsonFile then
        print('^1[HeliNav] Failed to load helinav-locations.json^7')
        return
    end

    local data = json.decode(jsonFile)
    if not data then
        print('^1[HeliNav] Failed to parse helinav-locations.json^7')
        return
    end

    -- Simple array format: [{ coords: [x,y,z], name: "Location Name" }, ...]
    for i, item in ipairs(data) do
        if item.coords and item.name then
            Locations[i] = {
                coords = vector3(item.coords[1], item.coords[2], item.coords[3]),
                name = item.name
            }
        end
    end
end

LoadLocationsFromJSON()

debugPrint('[HeliNav] Loaded', #Locations, 'locations')

local function GetLocation(index)
    local loc = Locations[index]
    if not loc then return nil, nil, nil end

    local playerPos = GetEntityCoords(PlayerPedId())
    local distance = #(playerPos - loc.coords)

    return loc.coords, distance, loc.name
end

local function SetWaypointToCoords(coords)
    if not coords then return false end
    SetNewWaypoint(coords.x, coords.y)
    return true
end

local HeliNavOpen = false
local currentIndex = 1
local CircularPageOpen = false
local IsInHelicopter = false

RegisterNUICallback('circularPageOpened', function(data, cb)
    CircularPageOpen = true
    cb('ok')
end)

RegisterNUICallback('circularPageClosed', function(data, cb)
    CircularPageOpen = false
    cb('ok')
end)

AddEventHandler('hud:vehicleEntered', function(data)
    IsInHelicopter = data.isHelicopter or false
end)

AddEventHandler('hud:vehicleExited', function()
    IsInHelicopter = false
end)

-- Send location name to NUI when index changes
local function UpdateLocation()
    if not HeliNavOpen then return end

    local coords, distance, name = GetLocation(currentIndex)

    if name then
        NuiMessage('helinav:updateLocation', { name = name, distance = distance, index = currentIndex })
    else
        NuiMessage('helinav:updateLocation', { name = 'Unknown', distance = 0, index = currentIndex })
    end
end

RegisterNUICallback('helinav:opened', function(_, cb)
    HeliNavOpen = true
    currentIndex = 1
    UpdateLocation()
    cb('ok')
end)

RegisterNUICallback('helinav:closed', function(_, cb)
    HeliNavOpen = false
    cb('ok')
end)

RegisterNUICallback('helinav:categoryChanged', function(data, cb)
    -- data.category is now index (1-6)
    local index = tonumber(data.category) or 1
    if index >= 1 and index <= #Locations then
        currentIndex = index
        UpdateLocation()
    end
    cb('ok')
end)

RegisterNUICallback('helinav:setWaypoint', function(data, cb)
    local index = tonumber(data.category) or currentIndex

    local coords, distance, name = GetLocation(index)
    if coords then
        SetWaypointToCoords(coords)
        local distText = string.format('%.1f', distance)
        Notify('GPS set to ' .. name .. ' (' .. distText .. 'm)', 'success')
        cb({ success = true, distance = distance, name = name })
    else
        cb({ success = false, message = 'No location found' })
    end
end)

-- Helikopterdeyken ve circular sayfa açıkken minimap ok göstergesini gizle
CreateThread(function()
    local LockMinimapAngle = LockMinimapAngle
    local UnlockMinimapAngle = UnlockMinimapAngle
    local SetRadarZoom = SetRadarZoom
    local wasLocked = false

    while true do
        if IsInHelicopter and CircularPageOpen then
            -- Minimap'i sabitle, ok göstergesini etkisizleştir
            LockMinimapAngle(0)
            SetRadarZoom(0)
            wasLocked = true
            Wait(0)
        else
            if wasLocked then
                UnlockMinimapAngle()
                wasLocked = false
            end
            Wait(500)
        end
    end
end)

CreateThread(function()
    local IsControlJustPressed = IsControlJustPressed
    local IsDisabledControlJustPressed = IsDisabledControlJustPressed
    local ARROW_LEFT = Constants.Controls.ARROW_LEFT
    local ARROW_RIGHT = Constants.Controls.ARROW_RIGHT
    local ENTER = Constants.Controls.ENTER

    while true do
        if HeliNavOpen then
            if IsDisabledControlJustPressed(0, ARROW_LEFT) then
                NuiMessage('helinav:navigate', { direction = 'left' })
            end
            if IsDisabledControlJustPressed(0, ARROW_RIGHT) then
                NuiMessage('helinav:navigate', { direction = 'right' })
            end
            if IsControlJustPressed(0, ENTER) then
                NuiMessage('helinav:select')
            end
            Wait(5)
        else
            Wait(Utils.W(500))
        end
    end
end)

debugPrint('[HeliNav] Module loaded')
