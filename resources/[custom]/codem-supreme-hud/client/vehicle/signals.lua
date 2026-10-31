--[[
    TURN SIGNALS SYSTEM
    Left, right, and hazard signal indicators
    Config: shared/config.lua -> Config.VehicleFeatures.Signals
]]

local Cfg = Config.VehicleFeatures.Signals
if not Cfg or not Cfg.Enabled then return end

-- Adaptive intervals
local signalActiveInterval = Utils.CreateAdaptiveInterval({ min = 100, max = 300, step = 50, threshold = 5 })
local signalIdleInterval = Utils.CreateAdaptiveInterval({ min = 300, max = 1000, step = 100, threshold = 3 })

-- STATE
local signalState = { left = false, right = false, hazard = false }
local signalThreadActive = false

-- ═══════════════════════════════════════════════════════════════
-- SIGNAL CONTROLS
-- ═══════════════════════════════════════════════════════════════

--- Set turn signal state and update vehicle lights
---@param left boolean Left signal active
---@param right boolean Right signal active
---@param hazard boolean Hazard lights active
--- Check if local player is the driver
local function IsDriver()
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then return false end
    return GetPedInVehicleSeat(vehicle, -1) == cache.ped
end

local function SetSignalState(left, right, hazard)
    signalState.left = left
    signalState.right = right
    signalState.hazard = hazard

    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then return end

    SetVehicleIndicatorLights(vehicle, 0, right or hazard)
    SetVehicleIndicatorLights(vehicle, 1, left or hazard)

    -- Sync signal state via entity state bag so passengers can see it
    if IsDriver() then
        local state = Entity(vehicle).state
        state:set('signalLeft', left, true)
        state:set('signalRight', right, true)
        state:set('signalHazard', hazard, true)
    end

    NuiMessage('updateSpeedometer', {
        leftSignal = left,
        rightSignal = right,
        hazardActive = hazard
    })
end

local function ToggleLeftSignal()
    if signalState.hazard then return end
    SetSignalState(not signalState.left, false, false)
end

local function ToggleRightSignal()
    if signalState.hazard then return end
    SetSignalState(false, not signalState.right, false)
end

local function ToggleHazards()
    SetSignalState(false, false, not signalState.hazard)
end

-- ═══════════════════════════════════════════════════════════════
-- SIGNAL THREAD
-- ═══════════════════════════════════════════════════════════════

local function StartSignalThread()
    if signalThreadActive then return end
    signalThreadActive = true

    signalState.left = false
    signalState.right = false
    signalState.hazard = false

    local vehicle = Utils.GetCurrentVehicle()
    if vehicle ~= 0 then
        SetVehicleIndicatorLights(vehicle, 0, false)
        SetVehicleIndicatorLights(vehicle, 1, false)
        NuiMessage('updateSpeedometer', { leftSignal = false, rightSignal = false, hazardActive = false })
    end

    CreateThread(function()
        local lastPassengerSignal = { left = false, right = false, hazard = false }

        while signalThreadActive do
            vehicle = Utils.GetCurrentVehicle()
            if vehicle == 0 then
                signalThreadActive = false
                break
            end

            -- Passenger: read driver's signal state from entity state bag
            if not IsDriver() then
                local state = Entity(vehicle).state
                local left = state.signalLeft or false
                local right = state.signalRight or false
                local hazard = state.signalHazard or false

                if left ~= lastPassengerSignal.left or right ~= lastPassengerSignal.right or hazard ~= lastPassengerSignal.hazard then
                    lastPassengerSignal.left = left
                    lastPassengerSignal.right = right
                    lastPassengerSignal.hazard = hazard
                    NuiMessage('updateSpeedometer', {
                        leftSignal = left,
                        rightSignal = right,
                        hazardActive = hazard
                    })
                end
                Wait(200)
            elseif signalState.left or signalState.right or signalState.hazard then
                SetVehicleIndicatorLights(vehicle, 0, signalState.right or signalState.hazard)
                SetVehicleIndicatorLights(vehicle, 1, signalState.left or signalState.hazard)
                signalActiveInterval.onStable()
                Wait(signalActiveInterval.current)
            else
                signalIdleInterval.onStable()
                Wait(signalIdleInterval.current)
            end
        end
    end)
end

local function StopSignalThread()
    signalThreadActive = false
    signalState.left = false
    signalState.right = false
    signalState.hazard = false
end

-- ═══════════════════════════════════════════════════════════════
-- EVENTS & KEYBINDS
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('codem-hud:client:vehicleStateChanged', function(inVehicle)
    if inVehicle then
        StartSignalThread()
    else
        StopSignalThread()
    end
end)

RegisterKeyMapping('+signalLeft', 'Left Turn Signal', 'keyboard', Cfg.LeftKey)
RegisterCommand('+signalLeft', function() if cache.vehicle then ToggleLeftSignal() end end, false)
RegisterCommand('-signalLeft', function() end, false)

RegisterKeyMapping('+signalRight', 'Right Turn Signal', 'keyboard', Cfg.RightKey)
RegisterCommand('+signalRight', function() if cache.vehicle then ToggleRightSignal() end end, false)
RegisterCommand('-signalRight', function() end, false)

RegisterKeyMapping('+signalHazard', 'Hazard Lights', 'keyboard', Cfg.HazardKey or 'DOWN')
RegisterCommand('+signalHazard', function() if cache.vehicle then ToggleHazards() end end, false)
RegisterCommand('-signalHazard', function() end, false)

