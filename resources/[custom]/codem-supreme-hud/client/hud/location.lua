local lastLocation = { zone = '', street = '', heading = -1, postalCode = '' }

-- Adaptive intervals from Config
local Intervals = Config.Timings.Intervals
local locationInterval = Utils.CreateAdaptiveInterval(Intervals.Location)
local headingInterval = Utils.CreateAdaptiveInterval(Intervals.Heading)
local waypointInterval = Utils.CreateAdaptiveInterval(Intervals.Waypoint)

-- Compass behaviour setting (synced from NUI)
-- 'mouse' = camera heading, 'player' = player ped heading
local CompassBehaviour = 'mouse'

-- Getter functions for external access
function GetCompassBehaviour() return CompassBehaviour end
function GetLastLocation() return lastLocation end

-- NUI callback to update compass behaviour setting
RegisterNUICallback('SET_COMPASS_BEHAVIOUR', function(data, cb)
    CompassBehaviour = data.behaviour or 'mouse'
    TriggerEvent('codem-hud:client:CompassBehaviourChanged', CompassBehaviour)
    cb('ok')
end)

-- Load postals data with spatial grid for O(1) lookup
local Postals = {}
local PostalGrid = {}
local GRID_SIZE = 250  -- Grid cell size in game units

-- Convert coords to grid key
local function GetGridKey(x, y)
    local gx = math.floor(x / GRID_SIZE)
    local gy = math.floor(y / GRID_SIZE)
    return gx .. ':' .. gy
end

-- Build spatial grid for fast postal lookup
local function BuildPostalGrid()
    PostalGrid = {}
    for i = 1, #Postals do
        local postal = Postals[i]
        local key = GetGridKey(postal.x, postal.y)
        if not PostalGrid[key] then
            PostalGrid[key] = {}
        end
        PostalGrid[key][#PostalGrid[key] + 1] = postal
    end
end

CreateThread(function()
    local postalsFile = LoadResourceFile(GetCurrentResourceName(), 'shared/postals.json')
    if postalsFile then
        local success, data = pcall(json.decode, postalsFile)
        if success and data then
            Postals = data
            BuildPostalGrid()
            debugPrint(('[codem-supreme-hud] Loaded %d postal codes with spatial grid'):format(#Postals))
        else
            debugPrint('[codem-supreme-hud] Error: Failed to parse postals.json')
        end
    else
        debugPrint('[codem-supreme-hud] Warning: postals.json not found')
    end
end)

-- Find nearest postal code using spatial grid (O(1) average case)
local function GetNearestPostal(coords)
    if #Postals == 0 then return nil end

    local px, py = coords.x, coords.y
    local nearestPostal = nil
    local nearestDist = math.huge

    -- Check current cell and adjacent cells (3x3 grid)
    local gx = math.floor(px / GRID_SIZE)
    local gy = math.floor(py / GRID_SIZE)

    for dx = -1, 1 do
        for dy = -1, 1 do
            local key = (gx + dx) .. ':' .. (gy + dy)
            local cell = PostalGrid[key]
            if cell then
                for i = 1, #cell do
                    local postal = cell[i]
                    local ddx = px - postal.x
                    local ddy = py - postal.y
                    local dist = ddx * ddx + ddy * ddy

                    if dist < nearestDist then
                        nearestDist = dist
                        nearestPostal = postal.code
                    end
                end
            end
        end
    end

    return nearestPostal
end

-- Waypoint tracking for detailed compass
local lastWaypointData = { active = false, angle = 0, distance = 0 }

-- Separate heading thread for smooth compass updates
CreateThread(function()
    local GetEntityHeading = GetEntityHeading
    local GetGameplayCamRot = GetGameplayCamRot
    local floor = math.floor
    local headingNuiData = { heading = 0 }
    local lastSentHeading = -1
    local abs = math.abs

    while true do
        Wait(Utils.W(headingInterval.current))

        if not (IsPlayerLoaded() and GetHudSettings()) then
            Wait(1000)
            goto continue
        end

        local heading
        local inVehicle = cache.inVehicle

        if CompassBehaviour == 'mouse' then
            local camRot = GetGameplayCamRot(2)
            heading = floor((360.0 - camRot.z) % 360)
        elseif inVehicle then
            local vehicle = cache.vehicle
            if vehicle and vehicle ~= 0 then
                heading = floor(GetEntityHeading(vehicle))
            end
        else
            heading = floor(GetEntityHeading(cache.ped))
        end

        if heading and heading ~= lastLocation.heading then
            lastLocation.heading = heading
            headingInterval.onChanged()
            local diff = abs(heading - lastSentHeading)
            if lastSentHeading == -1 or (diff >= 2 and diff <= 358) then
                lastSentHeading = heading
                headingNuiData.heading = heading
                NuiMessage('updateHeading', headingNuiData)
            end
        else
            headingInterval.onStable()
        end

        ::continue::
    end
end)

-- Location and waypoint thread (less frequent updates)
CreateThread(function()
    local GetEntityCoords = GetEntityCoords
    local GetEntitySpeed = GetEntitySpeed
    local GetNameOfZone = GetNameOfZone
    local GetLabelText = GetLabelText
    local GetStreetNameAtCoord = GetStreetNameAtCoord
    local GetStreetNameFromHashKey = GetStreetNameFromHashKey
    local GetFirstBlipInfoId = GetFirstBlipInfoId
    local DoesBlipExist = DoesBlipExist
    local GetBlipCoords = GetBlipCoords
    local GetHeadingFromVector_2d = GetHeadingFromVector_2d
    local abs = math.abs

    -- Adaptive base tick (fast when moving, slow when idle)
    local BASE_TICK_FAST = 100  -- Moving/driving
    local BASE_TICK_SLOW = 300  -- Standing still
    local currentTick = BASE_TICK_SLOW
    local lastCoords = vector3(0, 0, 0)

    -- Counters for staggered updates
    local locationCounter = 0
    local waypointCounter = 0

    while true do
        Wait(Utils.W(currentTick))

        if not (IsPlayerLoaded() and GetHudSettings()) then
            Wait(1000)
            goto continue
        end

        local coords = GetEntityCoords(cache.ped)

        -- Adaptive tick: fast when moving, slow when stationary
        local isMoving = false
        if cache.inVehicle then
            local vehicle = cache.vehicle
            if vehicle and vehicle ~= 0 then
                local speed = GetEntitySpeed(vehicle) * 3.6
                isMoving = speed > 5
            end
        else
            local dist = #(coords - lastCoords)
            isMoving = dist > 0.5
        end
        lastCoords = coords

        local newTick = isMoving and BASE_TICK_FAST or BASE_TICK_SLOW
        if newTick ~= currentTick then
            currentTick = newTick
        end

        locationCounter = locationCounter + currentTick
        waypointCounter = waypointCounter + currentTick

        -- LOCATION UPDATE (every locationInterval.current ms)
        if locationCounter >= locationInterval.current then
            locationCounter = 0
            local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)) or 'Unknown'
            local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local street = GetStreetNameFromHashKey(streetHash) or ''

            if crossingHash ~= 0 then
                local crossing = GetStreetNameFromHashKey(crossingHash)
                if crossing and crossing ~= '' then
                    street = street .. ' / ' .. crossing
                end
            end

            local postalCode = GetNearestPostal(coords) or ''

            if zone ~= lastLocation.zone or street ~= lastLocation.street or postalCode ~= lastLocation.postalCode then
                lastLocation.zone, lastLocation.street, lastLocation.postalCode = zone, street, postalCode
                NuiMessage('updateLocation', { zone = zone, street = street, postalCode = postalCode })
                locationInterval.onChanged()
            else
                locationInterval.onStable()
            end
        end

        -- WAYPOINT UPDATE (every waypointInterval.current ms)
        if waypointCounter >= waypointInterval.current then
            waypointCounter = 0
            local waypoint = GetFirstBlipInfoId(8)
            if DoesBlipExist(waypoint) then
                local wpCoords = GetBlipCoords(waypoint)
                local dx = wpCoords.x - coords.x
                local dy = wpCoords.y - coords.y
                local angle = GetHeadingFromVector_2d(dx, dy)
                local distance = #(vector2(coords.x, coords.y) - vector2(wpCoords.x, wpCoords.y))

                if not lastWaypointData.active or
                   abs(lastWaypointData.angle - angle) > 1 or
                   abs(lastWaypointData.distance - distance) > 5 then
                    lastWaypointData = { active = true, angle = angle, distance = distance }
                    NuiMessage('updateWaypoint', lastWaypointData)
                    waypointInterval.onChanged()
                else
                    waypointInterval.onStable()
                end
            else
                if lastWaypointData.active then
                    lastWaypointData = { active = false, angle = 0, distance = 0 }
                    NuiMessage('updateWaypoint', lastWaypointData)
                end
                waypointInterval.onStable()
            end
        end

        ::continue::
    end
end)
