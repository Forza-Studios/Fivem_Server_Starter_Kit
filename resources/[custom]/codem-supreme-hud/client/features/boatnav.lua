--[[
    BoatNav - Boat Navigation System
    Shows marina/dock locations when in boat
]]

local Locations = {}
local BoatNavOpen = false
local currentIndex = 1

-- Load locations using shared utility
local function LoadLocations()
    local data = Utils.Nav.LoadLocationsFromJSON('shared/data/boatnav-locations.json', 'BoatNav')
    if data then
        Locations = Utils.Nav.ParseSimpleLocations(data)
    end
end

LoadLocations()

local function UpdateLocation()
    if not BoatNavOpen then return end

    local coords, distance, name = Utils.Nav.GetLocation(Locations, currentIndex)

    NuiMessage('boatnav:updateLocation', {
        name = name or 'Unknown',
        distance = distance or 0,
        index = currentIndex,
        totalLocations = #Locations
    })
end

RegisterNUICallback('boatnav:opened', function(_, cb)
    BoatNavOpen = true
    currentIndex = 1
    UpdateLocation()
    cb('ok')
end)

RegisterNUICallback('boatnav:closed', function(_, cb)
    BoatNavOpen = false
    cb('ok')
end)

RegisterNUICallback('boatnav:categoryChanged', function(data, cb)
    local index = tonumber(data.category) or 1
    if index >= 1 and index <= #Locations then
        currentIndex = index
        UpdateLocation()
    end
    cb('ok')
end)

RegisterNUICallback('boatnav:setWaypoint', function(data, cb)
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

-- Input thread using shared utility
Utils.Nav.CreateInputThread({
    isOpen = function() return BoatNavOpen end,
    prefix = 'boatnav'
})

debugPrint('[BoatNav] Module loaded with', #Locations, 'locations')
