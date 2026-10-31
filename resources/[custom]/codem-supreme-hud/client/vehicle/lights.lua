--[[
    Vehicle Lights Module
    Headlights, neon lights state tracking
]]

local lastLightsState = { headlightsOn = nil, neonColor = nil, anyNeonOn = nil }
local lightsThreadActive = false

-- Cache: plate → true/false/nil
-- true = neon installed (from DB), false = not installed (from DB), nil = not in DB (use color fallback)
local neonInstalledCache = {}

local function StartLightsThread()
    if lightsThreadActive then return end
    lightsThreadActive = true

    CreateThread(function()
        local IsVehicleNeonLightEnabled = IsVehicleNeonLightEnabled
        local GetVehicleNeonLightsColour = GetVehicleNeonLightsColour
        local GetVehicleLightsState = GetVehicleLightsState
        local stringFormat = string.format

        -- Check neon color once at start (rarely changes)
        local lastNeonColorCheck = 0
        local NEON_COLOR_CHECK_INTERVAL = 2000
        local neonSides = { left = false, right = false, front = false, back = false }
        local nuiLightsData = { headlightsOn = false, anyNeonOn = false, neonColor = nil, neonSides = neonSides }

        while lightsThreadActive do
            local vehicle = cache.vehicle
            if not vehicle or vehicle == 0 then
                lightsThreadActive = false
                lastLightsState = { headlightsOn = nil, neonColor = nil, anyNeonOn = nil }
                break
            end

            local _, lightsOn, highbeamsOn = GetVehicleLightsState(vehicle)
            local headlightsOn = lightsOn == true or lightsOn == 1 or highbeamsOn == true or highbeamsOn == 1

            neonSides.left = IsVehicleNeonLightEnabled(vehicle, 0)
            neonSides.right = IsVehicleNeonLightEnabled(vehicle, 1)
            neonSides.front = IsVehicleNeonLightEnabled(vehicle, 2)
            neonSides.back = IsVehicleNeonLightEnabled(vehicle, 3)
            local anyNeonOn = neonSides.left or neonSides.right or neonSides.front or neonSides.back

            local neonColor = lastLightsState.neonColor
            local now = GetGameTimer()
            if anyNeonOn and (now - lastNeonColorCheck > NEON_COLOR_CHECK_INTERVAL) then
                lastNeonColorCheck = now
                local r, g, b = GetVehicleNeonLightsColour(vehicle)
                neonColor = stringFormat('rgb(%d,%d,%d)', r, g, b)
            elseif not anyNeonOn then
                neonColor = nil
            end

            if headlightsOn ~= lastLightsState.headlightsOn or
               neonColor ~= lastLightsState.neonColor or
               anyNeonOn ~= lastLightsState.anyNeonOn then
                lastLightsState.headlightsOn = headlightsOn
                lastLightsState.neonColor = neonColor
                lastLightsState.anyNeonOn = anyNeonOn
                nuiLightsData.headlightsOn = headlightsOn
                nuiLightsData.anyNeonOn = anyNeonOn
                nuiLightsData.neonColor = neonColor
                NuiMessage('updateLightsState', nuiLightsData)
            end

            Wait(Utils.W(500))
        end
    end)
end

local function StopLightsThread()
    lightsThreadActive = false
    lastLightsState = { headlightsOn = nil, neonColor = nil, anyNeonOn = nil }
end

AddEventHandler('codem-hud:client:vehicleStateChanged', function(inVehicle)
    if inVehicle then
        local vehicle = cache.vehicle
        if vehicle and vehicle ~= 0 then
            local plate = Utils.GetNormalizedPlate(vehicle)
            if plate ~= '' and neonInstalledCache[plate] == nil then
                CreateThread(function()
                    local installed = RPC.execute('vehicleLights:checkNeonInstalled', plate)
                    neonInstalledCache[plate] = installed
                end)
            end
        end
        StartLightsThread()
    else
        StopLightsThread()
    end
end)

local NEON_INDICES = {
    neon_left = 0,
    neon_right = 1,
    neon_front = 2,
    neon_back = 3
}

-- Track forced headlight state per vehicle (0=default, 1=forced off, 2=forced on)
local vehicleForcedLightsState = {}

-- Check if neon is installed
-- 1. If any neon side is enabled → definitely installed
-- 2. DB cache for "installed but turned off" case
-- 3. No DB data + no neons enabled → not installed
local function IsNeonInstalled(vehicle)
    -- Check if any neon is currently enabled on the vehicle
    for i = 0, 3 do
        if IsVehicleNeonLightEnabled(vehicle, i) then
            -- Update cache so future checks are consistent
            local plate = Utils.GetNormalizedPlate(vehicle)
            if plate ~= '' then neonInstalledCache[plate] = true end
            return true
        end
    end

    -- No neons enabled, check DB cache (covers "installed but off" case)
    local plate = Utils.GetNormalizedPlate(vehicle)
    local cached = neonInstalledCache[plate]
    if cached ~= nil then return cached end

    -- No DB data, no neons enabled = not installed
    return false
end

-- Get lights info for circular HUD
RegisterNUICallback('GET_LIGHTS_INFO', function(_, cb)
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then
        cb({ error = 'Not in vehicle' })
        return
    end

    local lights = {}
    local r, g, b = GetVehicleNeonLightsColour(vehicle)
    local hasNeonColor = IsNeonInstalled(vehicle)

    -- Headlights (always installed)
    local _, lightsOn, highbeamsOn = GetVehicleLightsState(vehicle)
    local forcedState = vehicleForcedLightsState[vehicle] or 0
    -- lightsOn and highbeamsOn can be numbers (0/1) or booleans - check both
    local lightsActuallyOn = lightsOn == true or lightsOn == 1
    local highbeamsActuallyOn = highbeamsOn == true or highbeamsOn == 1
    local headlightsActuallyOn = (forcedState == 2) or (forcedState == 0 and (lightsActuallyOn or highbeamsActuallyOn))
    -- If forced off, always show as off
    if forcedState == 1 then headlightsActuallyOn = false end
    table.insert(lights, {
        id = 'headlights',
        name = L('vehicle.headlights'),
        isOn = headlightsActuallyOn,
        isInstalled = true
    })

    -- Interior/Ambiance lights (always installed)
    table.insert(lights, {
        id = 'ambiance',
        name = L('vehicle.interior'),
        isOn = IsVehicleInteriorLightOn(vehicle),
        isInstalled = true
    })

    -- Neon lights
    local neonOrder = {
        { id = 'neon_left', name = L('vehicle.neon_left') },
        { id = 'neon_right', name = L('vehicle.neon_right') },
        { id = 'neon_front', name = L('vehicle.neon_front') },
        { id = 'neon_back', name = L('vehicle.neon_back') }
    }

    for _, neon in ipairs(neonOrder) do
        local index = NEON_INDICES[neon.id]
        table.insert(lights, {
            id = neon.id,
            name = neon.name,
            isOn = hasNeonColor and IsVehicleNeonLightEnabled(vehicle, index) or false,
            isInstalled = hasNeonColor
        })
    end

    local anyNeonOn = false
    for _, light in ipairs(lights) do
        if light.id:find('neon_') and light.isOn then
            anyNeonOn = true
            break
        end
    end

    cb({
        lights = lights,
        neonColor = hasNeonColor and string.format('#%02X%02X%02X', r, g, b) or nil,
        anyNeonOn = anyNeonOn
    })
end)

-- Toggle light
RegisterNUICallback('TOGGLE_LIGHT', function(data, cb)
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then
        cb({ success = false, error = 'Not in vehicle' })
        return
    end

    local lightId = data.lightId
    if not lightId then
        cb({ success = false, error = 'No light ID' })
        return
    end

    if lightId == 'headlights' then
        -- Toggle headlights using our tracked state
        local currentForced = vehicleForcedLightsState[vehicle] or 0

        if currentForced == 0 then
            -- Not forced yet, check actual state
            local _, lightsOn = GetVehicleLightsState(vehicle)
            -- lightsOn can be number (0/1) or boolean - check both
            local isActuallyOn = lightsOn == true or lightsOn == 1
            if isActuallyOn then
                SetVehicleLights(vehicle, 1) -- Force off
                vehicleForcedLightsState[vehicle] = 1
            else
                SetVehicleLights(vehicle, 2) -- Force on
                vehicleForcedLightsState[vehicle] = 2
            end
        elseif currentForced == 1 then
            -- Currently forced off, turn on
            SetVehicleLights(vehicle, 2)
            vehicleForcedLightsState[vehicle] = 2
        else
            -- Currently forced on (2), turn off
            SetVehicleLights(vehicle, 1)
            vehicleForcedLightsState[vehicle] = 1
        end
        cb({ success = true })
    elseif lightId == 'ambiance' then
        -- Toggle interior/ambiance lights
        local isOn = IsVehicleInteriorLightOn(vehicle)
        SetVehicleInteriorlight(vehicle, not isOn)
        cb({ success = true })
    elseif NEON_INDICES[lightId] then
        -- Toggle neon (only if installed)
        if not IsNeonInstalled(vehicle) then
            cb({ success = false, error = 'Neon not installed' })
            return
        end
        local index = NEON_INDICES[lightId]
        local isOn = IsVehicleNeonLightEnabled(vehicle, index)
        SetVehicleNeonLightEnabled(vehicle, index, not isOn)
        cb({ success = true })
    else
        cb({ success = false, error = 'Unknown light ID' })
    end
end)
