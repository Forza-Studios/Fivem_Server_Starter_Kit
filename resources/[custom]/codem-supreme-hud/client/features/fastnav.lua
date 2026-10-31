-- Load locations from JSON file (easier to edit and extend)
local Locations = {}
local CategoryNames = {}

local function LoadLocationsFromJSON()
    local jsonFile = LoadResourceFile(GetCurrentResourceName(), 'shared/data/fastnav-locations.json')
    if not jsonFile then
        print('^1[FastNav] Failed to load fastnav-locations.json^7')
        return
    end

    local data = json.decode(jsonFile)
    if not data then
        print('^1[FastNav] Failed to parse fastnav-locations.json^7')
        return
    end

    -- Convert arrays to vector3
    for category, coords in pairs(data) do
        if category ~= 'categoryNames' and type(coords) == 'table' then
            Locations[category] = {}
            for _, coord in ipairs(coords) do
                if type(coord) == 'table' and #coord >= 3 then
                    Locations[category][#Locations[category] + 1] = vector3(coord[1], coord[2], coord[3])
                end
            end
        end
    end

    -- Load category names
    if data.categoryNames then
        CategoryNames = data.categoryNames
    end
end

LoadLocationsFromJSON()

local function GetNearestLocation(category)
    local locations = Locations[category]
    if not locations then return nil end

    local playerPos = GetEntityCoords(cache.ped)
    local nearestDist = math.huge
    local nearestCoords = nil

    for _, coords in ipairs(locations) do
        local dist = #(playerPos - coords)
        if dist < nearestDist then
            nearestDist = dist
            nearestCoords = coords
        end
    end

    return nearestCoords, nearestDist
end

local function SetWaypointToCoords(coords)
    if not coords then return false end
    SetNewWaypoint(coords.x, coords.y)
    return true
end

RegisterNUICallback('fastnav:setWaypoint', function(data, cb)
    local category = data.category
    if not category then
        return cb({ success = false, message = L('nav.no_category') })
    end

    local coords, distance = GetNearestLocation(category)
    if coords then
        SetWaypointToCoords(coords)
        local name = CategoryNames[category] or category
        local distText = string.format('%.1f', distance)
        Notify(L('nav.gps_set_nearest', name, distText), 'success')
        cb({ success = true, distance = distance })
    else
        cb({ success = false, message = L('nav.no_location_found') })
    end
end)

local FastNavOpen = false
local CircularNavDetailOpen = false

RegisterNUICallback('fastnav:opened', function(_, cb)
    FastNavOpen = true
    cb('ok')
end)

RegisterNUICallback('fastnav:closed', function(_, cb)
    FastNavOpen = false
    cb('ok')
end)

-- Circular HUD navigation detail view state
RegisterNUICallback('circularNavDetail:opened', function(_, cb)
    CircularNavDetailOpen = true
    cb('ok')
end)

RegisterNUICallback('circularNavDetail:closed', function(_, cb)
    CircularNavDetailOpen = false
    cb('ok')
end)


-- Global function for voice command / config.lua usage (bypasses NUI)
function SetFastNavWaypoint(category)
    local coords, distance = GetNearestLocation(category)
    if coords then
        SetWaypointToCoords(coords)
        local name = CategoryNames[category] or category
        local distText = string.format('%.1f', distance)
        Notify(L('nav.gps_set_nearest', name, distText), 'success')
        if VoicePanelOpen then
            NuiMessage('voiceassistant:hide')
        end
        NuiMessage('fastnav:switchToMap', {})
    end
end

debugPrint('[FastNav] Module loaded -', #Locations.gas, 'gas stations,', #Locations.atm, 'ATMs')
