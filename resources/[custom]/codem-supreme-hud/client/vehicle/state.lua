lastVehicleState = nil
lastVehicleModel = nil

local radarHideLoopActive = false

function StartRadarHideLoop()
    if radarHideLoopActive then return end
    radarHideLoopActive = true
    CreateThread(function()
        while not (IsPlayerLoaded() and GetHudSettings()) do
            DisplayRadar(false)
            Wait(0)
        end
        radarHideLoopActive = false
    end)
end

StartRadarHideLoop()

local vehicleClasses = {
    [0] = 'Compacts', [1] = 'Sedans', [2] = 'SUVs', [3] = 'Coupes',
    [4] = 'Muscle', [5] = 'Sports Classics', [6] = 'Sports', [7] = 'Super',
    [8] = 'Motorcycles', [9] = 'Off-road', [10] = 'Industrial',
    [11] = 'Utility', [12] = 'Vans', [13] = 'Cycles', [14] = 'Boats',
    [15] = 'Helicopters', [16] = 'Planes', [17] = 'Service', [18] = 'Emergency',
    [19] = 'Military', [20] = 'Commercial', [21] = 'Trains'
}

function VehicleHeadlightGreeting(vehicle)
    if not DoesEntityExist(vehicle) then return end
    local class = GetVehicleClass(vehicle)
    if class == 14 or class == 15 or class == 16 or class == 21 then return end
    if GetIsVehicleEngineRunning(vehicle) then return end

    CreateThread(function()
        local originalLightState = GetVehicleLightsState(vehicle)
        local originalFullbeam = IsVehicleSearchlightOn(vehicle)

        for i = 1, 2 do
            SetVehicleLights(vehicle, 2)
            SetVehicleFullbeam(vehicle, true)
            Wait(150)
            SetVehicleLights(vehicle, 1)
            SetVehicleFullbeam(vehicle, false)
            Wait(150)
        end

        if originalLightState then
            SetVehicleLights(vehicle, 2)
        else
            SetVehicleLights(vehicle, 0)
        end
        SetVehicleFullbeam(vehicle, originalFullbeam)
    end)
end

-- Vehicle state change handler (shared logic)
local function OnVehicleEntered(vehicle, displayName)
    debugPrint('[VehicleState] OnVehicleEntered - PlayerLoaded:', IsPlayerLoaded(), 'HudVisible:', IsHudVisible())

    -- Wait for PlayerLoaded on resource restart (max 10s)
    if not IsPlayerLoaded() then
        local waited = 0
        while not IsPlayerLoaded() and waited < 10000 do
            Wait(200)
            waited = waited + 200
        end
        if not IsPlayerLoaded() then
            debugPrint('[VehicleState] Blocked: PlayerLoaded still false after 10s wait')
            return
        end
        debugPrint('[VehicleState] PlayerLoaded after', waited, 'ms')
    end

    -- Wait for HUD to be visible on restart (max 3s, non-blocking on timeout)
    if not IsHudVisible() then
        local waited = 0
        while not IsHudVisible() and waited < 8000 do
            Wait(100)
            waited = waited + 100
        end
        if waited > 0 then
            debugPrint('[VehicleState] HUD visible after', waited, 'ms (or proceeding without it)')
        end
    end

    local vehicleClass = GetVehicleClass(vehicle)
    local isBicycle = vehicleClass == 13  -- Cycles class
    local isHelicopter = vehicleClass == 15 -- Helicopters class
    local isBoat = vehicleClass == 14 -- Boats class
    local isPlane = vehicleClass == 16 -- Planes class

    lastVehicleState = true

    debugPrint('[VehicleState] Triggering vehicle entered event - isBicycle:', isBicycle, 'isHelicopter:', isHelicopter, 'isBoat:', isBoat, 'isPlane:', isPlane)
    NuiMessage('setVehicleState', {
        inVehicle = true,
        vehicleClass = vehicleClass,
        isBicycle = isBicycle,
        isHelicopter = isHelicopter,
        isBoat = isBoat,
        isPlane = isPlane
    })
    TriggerEvent('codem-hud:client:vehicleStateChanged', true, isBicycle)
    UpdateMinimapVisibility(true)

    if not isBicycle then
        VehicleHeadlightGreeting(vehicle)
    end

    local vf = Config.VehicleFeatures or {}
    NuiMessage('updateSpeedometerConfig', {
        signalsEnabled = vf.Signals and vf.Signals.Enabled or false,
        sirenEnabled = vf.Siren and vf.Siren.Enabled or false,
        nitroEnabled = vf.Nitro and vf.Nitro.Enabled or false,
        driftCounterEnabled = vf.DriftCounter and vf.DriftCounter.Enabled ~= false or true
    })
    TriggerEvent('codem-hud:client:vehicleEntered', isBicycle)

    local model = GetEntityModel(vehicle)
    lastVehicleModel = model
    local make = GetMakeNameFromVehicleModel(model) or 'Unknown'
    local name = displayName or 'Unknown'
    local class = vehicleClasses[vehicleClass] or 'Vehicle'
    NuiMessage('updateVehicleInfo', { make = make, name = name, class = class })
end

local function OnVehicleExited()
    if not IsPlayerLoaded() then return end

    lastVehicleState = false
    lastVehicleModel = nil

    NuiMessage('setVehicleState', {
        inVehicle = false,
        vehicleClass = -1,
        isBicycle = false,
        isHelicopter = false,
        isBoat = false,
        isPlane = false
    })
    TriggerEvent('codem-hud:client:vehicleStateChanged', false, false)
    TriggerEvent('codem-hud:client:vehicleExited')
    UpdateMinimapVisibility(false)

    NuiMessage('updateVehicleInfo', { make = '', name = '', class = '' })
    CloseNuiFocusIfOpen()
end

AddEventHandler('codem-hud:client:baseevents:enteredVehicle', function(vehicle, seat, displayName, netId)
    debugPrint('[VehicleState] Internal enteredVehicle event - vehicle:', vehicle, 'seat:', seat)
    OnVehicleEntered(vehicle, displayName)
end)

AddEventHandler('codem-hud:client:baseevents:leftVehicle', function()
    debugPrint('[VehicleState] Internal leftVehicle event')
    OnVehicleExited()
end)

AddEventHandler('codem-hud:client:baseevents:vehicleSwapped', function(vehicle, seat, displayName, netId)
    debugPrint('[VehicleState] Vehicle swap - updating info without exit/enter cycle')
    if not IsPlayerLoaded() then return end

    local vehicleClass = GetVehicleClass(vehicle)
    local isBicycle = vehicleClass == 13
    local isHelicopter = vehicleClass == 15
    local isBoat = vehicleClass == 14
    local isPlane = vehicleClass == 16

    lastVehicleState = true
    lastVehicleModel = GetEntityModel(vehicle)

    NuiMessage('setVehicleState', {
        inVehicle = true,
        vehicleClass = vehicleClass,
        isBicycle = isBicycle,
        isHelicopter = isHelicopter,
        isBoat = isBoat,
        isPlane = isPlane
    })

    local vf = Config.VehicleFeatures or {}
    NuiMessage('updateSpeedometerConfig', {
        signalsEnabled = vf.Signals and vf.Signals.Enabled or false,
        sirenEnabled = vf.Siren and vf.Siren.Enabled or false,
        nitroEnabled = vf.Nitro and vf.Nitro.Enabled or false,
        driftCounterEnabled = vf.DriftCounter and vf.DriftCounter.Enabled ~= false or true
    })

    local make = GetMakeNameFromVehicleModel(lastVehicleModel) or 'Unknown'
    local name = displayName or 'Unknown'
    local class = vehicleClasses[vehicleClass] or 'Vehicle'
    NuiMessage('updateVehicleInfo', { make = make, name = name, class = class })

    TriggerEvent('codem-hud:client:vehicleSwapped', vehicle, isBicycle)
    UpdateMinimapVisibility(true)
end)

local minimapState = { hasRequiredItem = false, isInVehicle = false }

function UpdateMinimapVisibility(forceInVehicle)
    if not (IsPlayerLoaded() and GetHudSettings()) then
        SetMinimapVisible(false)
        return
    end

    if IsCinematicModeEnabled() or IsHudManuallyHidden() then
        SetMinimapVisible(false)
        return
    end

    local cfg = Config.Minimap or {}
    local isInVehicle = forceInVehicle ~= nil and forceInVehicle or cache.inVehicle
    minimapState.isInVehicle = isInVehicle

    if isInVehicle then
        SetMinimapVisible(true)
    elseif cfg.ShowOnFoot then
        SetMinimapVisible(true)
    elseif cfg.RequireItem then
        SetMinimapVisible(minimapState.hasRequiredItem)
    else
        SetMinimapVisible(false)
    end
end

AddEventHandler('codem-hud:client:RequiredItemChanged', function(hasAny)
    minimapState.hasRequiredItem = hasAny
    UpdateMinimapVisibility()
end)
