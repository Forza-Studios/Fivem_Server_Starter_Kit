local speedometerActive = false
SpeedoRefreshMs = 50
local lastSpeedoData = { speed = -1, rpm = -1, gear = -1, fuel = -1, engineHealth = -1, engineRunning = nil, hornActive = false, handbrake = false, lowBeam = false, highBeam = false, attitudePitch = 0, attitudeRoll = 0, altitude = 0, liftReady = false, hoverMode = false, stallWarning = false }
local smoothRpm = 0.2
local hoverModeEnabled = false
local hoverActivating = false

-- Stall warning sound
local stallSoundActive = false

local function StartStallSound()
    if stallSoundActive then return end
    stallSoundActive = true
    CreateThread(function()
        while stallSoundActive do
            local id = GetSoundId()
            PlaySoundFrontend(id, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false)
            Wait(300)
            StopSound(id)
            ReleaseSoundId(id)
            Wait(200)
        end
    end)
end

local function StopStallSound()
    stallSoundActive = false
end

-- Engine failure sound
local engineFailSoundActive = false

local function StartEngineFailSound()
    if engineFailSoundActive then return end
    engineFailSoundActive = true
    CreateThread(function()
        while engineFailSoundActive do
            local id = GetSoundId()
            PlaySoundFrontend(id, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', false)
            Wait(600)
            StopSound(id)
            ReleaseSoundId(id)
            Wait(800)
        end
    end)
end

local function StopEngineFailSound()
    engineFailSoundActive = false
end

-- Drift counter config (loaded from Config.VehicleFeatures.DriftCounter)
local driftConfig = nil
local function GetDriftConfig()
    if driftConfig == nil then
        local vf = Config.VehicleFeatures or {}
        local dc = vf.DriftCounter or {}
        driftConfig = {
            enabled = dc.Enabled ~= false,  -- Default true if not specified
            minAngle = dc.MinAngle or 10,   -- Lower = easier to start drifting (arcade)
            minSpeed = dc.MinSpeed or 20,   -- Lower = can drift at slower speeds
            comboTimeout = dc.ComboTimeout or 3000,
            uiGracePeriod = dc.UIGracePeriod or 800,
            resetOnCollision = dc.ResetOnCollision ~= false,  -- Default true
            scoreMultiplier = dc.ScoreMultiplier or 1.5,
            comboGainTime = dc.ComboGainTime or 2000,  -- Faster combo gain
            maxCombo = dc.MaxCombo or 10,
        }
    end
    return driftConfig
end

-- Drift counter state
local driftState = {
    isDrifting = false,
    driftAngle = 0,
    driftScore = 0,
    driftCombo = 1,
    driftMaxAngle = 0,
    lastDriftTime = 0,
    comboTimer = 0,
    showUI = false,           -- Separate UI visibility (with grace period)
    lastUIUpdateTime = 0,
}

-- Calculate drift angle (difference between vehicle heading and velocity direction)
-- Optimized: Cache math functions locally
local mathDeg = math.deg
local mathAtan2 = math.atan2
local mathAbs = math.abs

local function GetDriftAngle(vehicle, velocity, speed)
    -- If not moving, no drift (caller already checked speed >= minSpeed)
    if speed < 5.0 then return 0 end

    -- Get vehicle heading (where the car is pointing)
    local heading = GetEntityHeading(vehicle)

    -- Get velocity direction (where the car is actually moving)
    local velocityHeading = mathDeg(mathAtan2(velocity.y, velocity.x)) - 90
    if velocityHeading < 0 then velocityHeading = velocityHeading + 360 end

    -- Calculate angle difference
    local angleDiff = mathAbs(heading - velocityHeading)
    if angleDiff > 180 then angleDiff = 360 - angleDiff end

    return angleDiff
end

-- Update drift state and scoring
local function UpdateDriftState(vehicle, speed, currentTime, velocity)
    local cfg = GetDriftConfig()

    -- Skip all calculations if drift counter is disabled
    if not cfg.enabled then
        return false
    end

    -- Check for collision/crash - reset score if vehicle collides with anything
    if cfg.resetOnCollision and driftState.driftScore > 0 then
        local hasCollided = HasEntityCollidedWithAnything(vehicle)

        -- Simple collision check - any collision resets drift (like real drift games)
        if hasCollided then
            -- Vehicle crashed - reset drift immediately
            driftState.driftScore = 0
            driftState.driftCombo = 1
            driftState.driftMaxAngle = 0
            driftState.comboTimer = 0
            driftState.isDrifting = false
            driftState.driftAngle = 0
            driftState.showUI = false
            driftState.lastDriftTime = 0
        end
    end

    -- Pass velocity to avoid redundant GetEntityVelocity call
    local angle = GetDriftAngle(vehicle, velocity, speed)
    local wasDrifting = driftState.isDrifting

    -- Check if currently drifting (using config values)
    local nowDrifting = angle >= cfg.minAngle and speed >= cfg.minSpeed

    if nowDrifting then
        driftState.isDrifting = true
        driftState.driftAngle = angle
        driftState.lastDriftTime = currentTime

        -- Update max angle
        if angle > driftState.driftMaxAngle then
            driftState.driftMaxAngle = angle
        end

        -- Calculate score based on angle and speed (with configurable multiplier)
        local angleMultiplier = angle / 45  -- Higher angle = more points
        local speedBonus = speed / 100       -- Faster = more points
        local scoreGain = math.floor(angle * angleMultiplier * speedBonus * driftState.driftCombo * cfg.scoreMultiplier)
        driftState.driftScore = driftState.driftScore + scoreGain

        -- Increase combo over time (configurable timing)
        if driftState.comboTimer == 0 then
            driftState.comboTimer = currentTime
        elseif currentTime - driftState.comboTimer > cfg.comboGainTime and driftState.driftCombo < cfg.maxCombo then
            driftState.driftCombo = driftState.driftCombo + 1
            driftState.comboTimer = currentTime
        end
    else
        driftState.isDrifting = false
        driftState.driftAngle = 0

        -- Check combo timeout - reset everything when drift chain breaks
        if driftState.lastDriftTime > 0 and (currentTime - driftState.lastDriftTime) > cfg.comboTimeout then
            -- Reset all drift data when chain breaks (user friendly - start fresh)
            driftState.driftScore = 0
            driftState.driftCombo = 1
            driftState.driftMaxAngle = 0
            driftState.comboTimer = 0
            driftState.showUI = false
        end
    end

    -- Update UI visibility with grace period (prevents flickering)
    if driftState.isDrifting then
        driftState.showUI = true
        driftState.lastUIUpdateTime = currentTime
    elseif driftState.showUI and (currentTime - driftState.lastUIUpdateTime) > cfg.uiGracePeriod then
        -- Only hide UI after grace period expires AND combo timeout
        if (currentTime - driftState.lastDriftTime) > cfg.comboTimeout then
            driftState.showUI = false
        end
    end

    return driftState.isDrifting ~= wasDrifting or (driftState.isDrifting and angle ~= driftState.driftAngle) or driftState.showUI
end

-- Reset drift state
local function ResetDriftState()
    driftState = {
        isDrifting = false,
        driftAngle = 0,
        driftScore = 0,
        driftCombo = 1,
        driftMaxAngle = 0,
        lastDriftTime = 0,
        comboTimer = 0,
        showUI = false,
        lastUIUpdateTime = 0,
    }
end

local electricModelsSet = {}
do
    local models = Config.VehicleModels.Electric or {}
    for _, name in ipairs(models) do
        electricModelsSet[joaat(name)] = true
    end
end

local cachedVehicleModel = nil
local cachedIsElectric = false

local detectedFuelSystem = nil

local function DetectFuelSystem()
    if Config.FuelSystem and Config.FuelSystem.Script ~= 'auto' then
        return Config.FuelSystem.Script
    end

    if GetResourceState('ox_fuel') == 'started' then return 'ox_fuel'
    elseif GetResourceState('ps-fuel') == 'started' then return 'ps-fuel'
    elseif GetResourceState('cdn-fuel') == 'started' then return 'cdn-fuel'
    elseif GetResourceState('lc_fuel') == 'started' then return 'lc_fuel'
    elseif GetResourceState('LegacyFuel') == 'started' then return 'LegacyFuel'
    elseif GetResourceState('okokGasStation') == 'started' then return 'okokGasStation'
    elseif GetResourceState('qb-fuel') == 'started' then return 'qb-fuel'
    end
    return 'native'
end

local function GetFuelLevel(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return 0 end

    if not detectedFuelSystem then
        detectedFuelSystem = DetectFuelSystem()
    end

    local fuel = 0
    if detectedFuelSystem == 'ox_fuel' or detectedFuelSystem == 'ps-fuel' or detectedFuelSystem == 'cdn-fuel' or detectedFuelSystem == 'lc_fuel' then
        local state = Entity(vehicle).state
        fuel = state.fuel or GetVehicleFuelLevel(vehicle)
    elseif detectedFuelSystem == 'LegacyFuel' then
        if DecorExistOn(vehicle, '_FUEL_LEVEL') then
            fuel = DecorGetFloat(vehicle, '_FUEL_LEVEL')
        else
            fuel = GetVehicleFuelLevel(vehicle)
        end
    elseif detectedFuelSystem == 'okokGasStation' then
        local success, result = pcall(function() return exports['okokGasStation']:GetFuel(vehicle) end)
        fuel = success and result or GetVehicleFuelLevel(vehicle)
    elseif detectedFuelSystem == 'qb-fuel' then
        local success, result = pcall(function() return exports['qb-fuel']:GetFuel(vehicle) end)
        fuel = success and result or GetVehicleFuelLevel(vehicle)
    else
        fuel = GetVehicleFuelLevel(vehicle)
    end
    return math.floor(fuel)
end

local function StartSpeedometerThread()
    if speedometerActive then
        return
    end
    speedometerActive = true
    smoothRpm = 0.2

    CreateThread(function()
        local GetEntitySpeed = GetEntitySpeed
        local GetVehicleCurrentRpm = GetVehicleCurrentRpm
        local GetVehicleCurrentGear = GetVehicleCurrentGear
        local GetVehicleEngineHealth = GetVehicleEngineHealth
        local GetIsVehicleEngineRunning = GetIsVehicleEngineRunning
        local GetVehicleHandbrake = GetVehicleHandbrake
        local GetVehicleLightsState = GetVehicleLightsState
        local GetEntityModel = GetEntityModel
        local floor = math.floor
        local abs = math.abs
        local max = math.max
        local min = math.min

        local fuelCheckCounter = 0
        local lastFuel = 0
        local lastTick = GetGameTimer()
        local cachedVehClass = -1
        local cachedVehicleId = 0
        local engineCheckCounter = 0
        local lastEngineHealthVal = 0
        local lastEngineRunningVal = true
        local lightsCheckCounter = 0
        local lastLowBeam = false
        local engineStartedAt = 0 -- Timestamp when aircraft engine started (for LIFT spool-up)
        local lastHighBeam = false

        while speedometerActive do
            if not (IsPlayerLoaded() and IsHudVisible()) then
                Wait(Utils.W(1000)) -- Longer sleep when HUD not visible
                goto continue
            end

            local ped = cache.ped
            local vehicle = cache.vehicle

            if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
                Wait(Utils.W(500)) -- Increased from 200
                goto continue
            end

            if not IsPedInAnyVehicle(ped, false) then
                Wait(Utils.W(500))
                goto continue
            end

            local speed = floor(GetEntitySpeed(vehicle) * 3.6)
            if vehicle ~= cachedVehicleId then
                cachedVehicleId = vehicle
                cachedVehClass = GetVehicleClass(vehicle)
                cachedVehicleModel = GetEntityModel(vehicle)
                cachedIsElectric = electricModelsSet[cachedVehicleModel] == true
                lastEngineHealthVal = floor((GetVehicleEngineHealth(vehicle) / 10))
                lastEngineRunningVal = GetIsVehicleEngineRunning(vehicle)
                engineCheckCounter = 0
                lightsCheckCounter = 0
            end
            local vehClass = cachedVehClass
            local isAircraft = Constants.IsAircraft(vehClass)

            -- RPM: use GetVehicleCurrentRpm for all vehicles (works for helis/planes in modern FiveM)
            -- For aircraft, blend in throttle input for better responsiveness
            local nativeRpm = GetVehicleCurrentRpm(vehicle)
            local gtaRpm = nativeRpm
            if isAircraft then
                local throttle = GetControlNormal(0, 71) -- W key / accelerate
                gtaRpm = max(nativeRpm, 0.2 + throttle * 0.6)
            end
            local engineRunning = lastEngineRunningVal
            local rawGear = GetVehicleCurrentGear(vehicle)

            -- Check manual transmission mode
            local isManualMode, manualGear, manualRpm = false, nil, nil
            if GetManualTransmissionState then
                isManualMode, manualGear, manualRpm = GetManualTransmissionState()
            end

            -- In manual mode, use calculated RPM from speed/gear ratio
            if isManualMode and manualRpm then
                gtaRpm = manualRpm
            end

            local gear
            if not engineRunning then gear = -2
            elseif rawGear == 0 then gear = -1
            elseif isManualMode and manualGear then gear = manualGear
            else gear = max(1, rawGear - 1) end

            local now = GetGameTimer()

            local targetRpm = engineRunning and (0.2 + ((gtaRpm - 0.2) * 0.85)) or 0.15
            targetRpm = max(0.15, min(0.88, targetRpm))
            local rpmDiff = targetRpm - smoothRpm
            if abs(rpmDiff) > 0.001 then
                local dt = (now - lastTick) / 1000.0
                lastTick = now
                local smoothFactor = 1.0 - (0.0001 ^ dt)
                smoothRpm = smoothRpm + (rpmDiff * smoothFactor)
            else
                smoothRpm = targetRpm
                lastTick = now
            end

            fuelCheckCounter = fuelCheckCounter + 1
            if fuelCheckCounter >= 20 then -- Increased from 10 (less frequent fuel checks)
                fuelCheckCounter = 0
                lastFuel = GetFuelLevel(vehicle)
            end

            engineCheckCounter = engineCheckCounter + 1
            if engineCheckCounter >= 5 then
                engineCheckCounter = 0
                lastEngineHealthVal = floor((GetVehicleEngineHealth(vehicle) / 10))
                lastEngineRunningVal = GetIsVehicleEngineRunning(vehicle)
            end
            local engineHealth = lastEngineHealthVal

            -- Engine failure: health critically low (works even if engine stopped due to damage)
            -- For aircraft, engine failure is critical so show warning regardless of running state
            local engineFailure = engineHealth < 20
            local oilLow = engineHealth >= 20 and engineHealth < 40 and engineRunning

            -- Engine failure sound
            if engineFailure and not engineFailSoundActive then
                StartEngineFailSound()
            elseif not engineFailure and engineFailSoundActive then
                StopEngineFailSound()
            end

            local hornActive, handbrake
            if speed > 0 then
                hornActive = IsControlPressed(0, 86)
                handbrake = GetVehicleHandbrake(vehicle)
            else
                hornActive = lastSpeedoData.hornActive or false
                handbrake = lastSpeedoData.handbrake or false
            end

            lightsCheckCounter = lightsCheckCounter + 1
            if lightsCheckCounter >= 3 then
                lightsCheckCounter = 0
                local _, lightsOn, highBeamsOn = GetVehicleLightsState(vehicle)
                lastHighBeam = highBeamsOn == 1 or highBeamsOn == true
                lastLowBeam = ((lightsOn == 1 or lightsOn == true) or lastHighBeam)
            end
            local lowBeam = lastLowBeam
            local highBeam = lastHighBeam

            -- Update drift state (only when drift mode is active AND at higher speeds)
            local driftChanged = false
            local isDriftMode = IsDriftModeActive and IsDriftModeActive() or false
            local driftVelocity = nil
            if isDriftMode and speed >= 15 then
                driftVelocity = GetEntityVelocity(vehicle)
                driftChanged = UpdateDriftState(vehicle, speed, now, driftVelocity)
            elseif driftState.showUI then
                -- Reset drift UI if we slowed down or exited drift mode
                driftState.showUI = false
                driftChanged = true
            end

            -- Aircraft data (helicopters and planes)
            local attitudePitch = 0
            local attitudeRoll = 0
            local altitude = 0
            local liftReady = false -- Engine running and ready for takeoff
            local hoverMode = false
            local stallWarning = false

            if isAircraft then
                attitudePitch = GetEntityPitch(vehicle)
                attitudeRoll = GetEntityRoll(vehicle)
                local coords = GetEntityCoords(vehicle)
                altitude = coords.z -- Altitude in game units (meters)
                -- LIFT = engine running for at least 3 seconds (rotor spool-up time)
                if engineRunning and engineStartedAt == 0 then
                    engineStartedAt = now
                elseif not engineRunning then
                    engineStartedAt = 0
                end
                liftReady = engineRunning and engineStartedAt > 0 and (now - engineStartedAt) >= 3000

                -- Stall warning detection (realistic aviation rules)
                if altitude > 10 and engineRunning then
                    local velocity = driftVelocity or GetEntityVelocity(vehicle)
                    local verticalSpeed = velocity.z * 3.6 -- km/h

                    if vehClass == 15 then
                        -- Helicopter stall conditions:
                        -- 1. Vortex ring state: descending >10 km/h with low forward speed
                        -- 2. Over-pitch: extreme nose angles (>45° up or down)
                        -- 3. Over-bank: extreme roll (>60°)
                        -- 4. Rapid uncontrolled descent (>30 km/h vertical)
                        local forwardSpeed = speed
                        local absPitch = math.abs(attitudePitch)
                        local absRoll = math.abs(attitudeRoll)

                        local vortexRing = verticalSpeed < -10 and forwardSpeed < 30
                        local overPitch = absPitch > 45
                        local overBank = absRoll > 60
                        local rapidDescent = verticalSpeed < -30

                        stallWarning = vortexRing or overPitch or overBank or rapidDescent
                    else
                        -- Fixed-wing stall conditions:
                        -- 1. Classic stall: high AoA (pitch >18°) with low airspeed (<120 km/h)
                        -- 2. Deep stall: very high pitch (>35°) regardless of speed
                        -- 3. Accelerated stall: high bank (>55°) with moderate pitch (>12°) and low speed
                        -- 4. Low speed warning: airspeed below minimum (<80 km/h) while climbing
                        local classicStall = attitudePitch > 18 and speed < 120
                        local deepStall = attitudePitch > 35
                        local acceleratedStall = math.abs(attitudeRoll) > 55 and attitudePitch > 12 and speed < 150
                        local lowSpeedClimb = speed < 80 and verticalSpeed > 5

                        stallWarning = classicStall or deepStall or acceleratedStall or lowSpeedClimb
                    end
                end

                -- Stall sound
                if stallWarning and not stallSoundActive then
                    StartStallSound()
                elseif not stallWarning and stallSoundActive then
                    StopStallSound()
                end

                -- Hover mode for helicopters
                if vehClass == 15 then
                    hoverMode = hoverModeEnabled
                    if hoverMode ~= lastSpeedoData.hoverMode then
                        debugPrint('[HoverMode] Speedo thread detected change:', hoverMode, 'prev:', lastSpeedoData.hoverMode)
                    end
                end
            else
                hoverModeEnabled = false
                if stallSoundActive then StopStallSound() end
            end

            local limiterActive = limiterState and limiterState.enabled or false
            local curLimiterSpeed = limiterState and limiterState.speed or 0
            local cruiseActive = cruiseState and cruiseState.enabled or false
            local curCruiseSpeed = cruiseState and cruiseState.speed or 0

            local speedChanged = speed ~= lastSpeedoData.speed
            local rpmChanged = floor(smoothRpm * 100) ~= floor((lastSpeedoData.rpm or 0) * 100)
            local gearChanged = gear ~= lastSpeedoData.gear or isManualMode ~= lastSpeedoData.isManualMode
            local fuelChanged = lastFuel ~= lastSpeedoData.fuel
            local engineChanged = engineHealth ~= lastSpeedoData.engineHealth or engineRunning ~= lastSpeedoData.engineRunning
            local hornChanged = hornActive ~= lastSpeedoData.hornActive
            local handbrakeChanged = handbrake ~= lastSpeedoData.handbrake
            local lowBeamChanged = lowBeam ~= lastSpeedoData.lowBeam or highBeam ~= lastSpeedoData.highBeam
            local limiterChanged = limiterActive ~= lastSpeedoData.limiterActive or curLimiterSpeed ~= lastSpeedoData.limiterSpeed
            local cruiseChanged = cruiseActive ~= lastSpeedoData.cruiseActive or curCruiseSpeed ~= lastSpeedoData.cruiseSpeed
            local aircraftChanged = isAircraft and (
                floor(attitudePitch) ~= floor(lastSpeedoData.attitudePitch or 0) or
                floor(attitudeRoll) ~= floor(lastSpeedoData.attitudeRoll or 0) or
                floor(altitude) ~= floor(lastSpeedoData.altitude or 0) or
                liftReady ~= lastSpeedoData.liftReady or
                hoverMode ~= lastSpeedoData.hoverMode or
                stallWarning ~= lastSpeedoData.stallWarning or
                (AutopilotEnabled or false) ~= (lastSpeedoData.autopilot or false)
            )

            if speedChanged or rpmChanged or gearChanged or fuelChanged or engineChanged or hornChanged or handbrakeChanged or lowBeamChanged or limiterChanged or cruiseChanged or driftChanged or aircraftChanged then
                -- Delta update: only send changed fields (reduces JSON serialization ~30 fields → 2-5)
                local delta = {}

                if speedChanged then delta.speed = speed; lastSpeedoData.speed = speed end
                if rpmChanged then delta.rpm = smoothRpm; lastSpeedoData.rpm = smoothRpm end
                if gearChanged then
                    delta.gear = gear; lastSpeedoData.gear = gear
                    delta.isManualTransmission = isManualMode; lastSpeedoData.isManualMode = isManualMode
                    delta.vehicleClass = vehClass
                end
                if fuelChanged then delta.fuel = lastFuel; lastSpeedoData.fuel = lastFuel end
                if engineChanged then
                    local eh = max(0, engineHealth)
                    delta.engineHealth = eh; delta.engineRunning = engineRunning
                    delta.engineFailure = engineFailure; delta.oilLow = oilLow
                    lastSpeedoData.engineHealth = eh; lastSpeedoData.engineRunning = engineRunning
                end
                if hornChanged then delta.hornActive = hornActive; lastSpeedoData.hornActive = hornActive end
                if handbrakeChanged then delta.handbrake = handbrake; lastSpeedoData.handbrake = handbrake end
                if lowBeamChanged then
                    delta.lowBeam = lowBeam; delta.highBeam = highBeam
                    lastSpeedoData.lowBeam = lowBeam; lastSpeedoData.highBeam = highBeam
                end
                if limiterChanged then
                    delta.limiterActive = limiterActive; delta.limiterSpeed = curLimiterSpeed
                    lastSpeedoData.limiterActive = limiterActive; lastSpeedoData.limiterSpeed = curLimiterSpeed
                end
                if cruiseChanged then
                    delta.cruiseActive = cruiseActive; delta.cruiseSpeed = curCruiseSpeed
                    lastSpeedoData.cruiseActive = cruiseActive; lastSpeedoData.cruiseSpeed = curCruiseSpeed
                end
                if driftChanged then
                    delta.isDrifting = driftState.showUI
                    delta.driftAngle = driftState.driftAngle
                    delta.driftScore = driftState.driftScore
                    delta.driftCombo = driftState.driftCombo
                    delta.driftMaxAngle = driftState.driftMaxAngle
                end
                if aircraftChanged then
                    delta.attitudePitch = attitudePitch; delta.attitudeRoll = attitudeRoll
                    delta.altitude = floor(altitude); delta.liftReady = liftReady
                    delta.hoverMode = hoverMode; delta.stallWarning = stallWarning
                    delta.autopilot = AutopilotEnabled or false
                    lastSpeedoData.attitudePitch = attitudePitch
                    lastSpeedoData.attitudeRoll = attitudeRoll
                    lastSpeedoData.altitude = altitude; lastSpeedoData.liftReady = liftReady
                    lastSpeedoData.hoverMode = hoverMode; lastSpeedoData.stallWarning = stallWarning
                    lastSpeedoData.autopilot = AutopilotEnabled or false
                end

                NuiMessage('updateSpeedometer', delta)
            end

            Wait(speed > 0 and SpeedoRefreshMs or (SpeedoRefreshMs * 4))
            ::continue::
        end
    end)
end

local function StopSpeedometerThread()
    speedometerActive = false
    smoothRpm = 0.2
    cachedVehicleModel = nil
    cachedIsElectric = false
    hoverModeEnabled = false
    StopStallSound()
    StopEngineFailSound()
    lastSpeedoData = { speed = -1, rpm = -1, gear = -1, fuel = -1, engineHealth = -1, engineRunning = nil, hornActive = false, handbrake = false, lowBeam = false, highBeam = false, attitudePitch = 0, attitudeRoll = 0, altitude = 0, liftReady = false, hoverMode = false, stallWarning = false }
end

-- Hover mode config
local function IsHoverEnabled()
    local vf = Config.VehicleFeatures or {}
    local hm = vf.HoverMode or {}
    return hm.Enabled ~= false
end

-- Hover mode command (for RegisterKeyMapping)
local hoverVehicle = nil
local hoverAltitude = nil

local function DisableHover()
    if hoverVehicle and DoesEntityExist(hoverVehicle) then
        SetVehicleGravityAmount(hoverVehicle, 9.8)
        SetHeliTurbulenceScalar(hoverVehicle, 1.0)
    end
    hoverModeEnabled = false
    hoverVehicle = nil
    hoverAltitude = nil
end

local function EnableHover(vehicle)
    local activationTime = Config.VehicleFeatures and Config.VehicleFeatures.HoverMode and Config.VehicleFeatures.HoverMode.ActivationTime or 0
    if activationTime > 0 then
        if hoverActivating then return end
        hoverActivating = true
        NuiMessage('hoverActivating', { activating = true, duration = activationTime })
        local steps = math.floor(activationTime / 100)
        for i = 1, steps do
            Wait(100)
            if not hoverActivating then
                NuiMessage('hoverActivating', { activating = false })
                return
            end
            if not IsPedInAnyHeli(PlayerPedId()) then
                hoverActivating = false
                NuiMessage('hoverActivating', { activating = false })
                return
            end
        end
        hoverActivating = false
        NuiMessage('hoverActivating', { activating = false })
    end
    hoverModeEnabled = true
    hoverVehicle = vehicle
    hoverAltitude = GetEntityCoords(vehicle).z
    SetHeliBladesFullSpeed(vehicle)
    SetVehicleGravityAmount(vehicle, 0.0)
    SetHeliTurbulenceScalar(vehicle, 0.0)
end

local function ToggleHoverMode()
    debugPrint('[HoverMode] ToggleHoverMode called')
    if not IsHoverEnabled() then
        debugPrint('[HoverMode] Blocked: HoverMode not enabled in config')
        return
    end

    local ped = PlayerPedId()
    if not IsPedInAnyHeli(ped) then
        debugPrint('[HoverMode] Blocked: Not in helicopter')
        return
    end

    local vehicle = Utils.GetCurrentVehicle()
    if not Utils.ValidateVehicle(vehicle) then
        debugPrint('[HoverMode] Blocked: Invalid vehicle')
        return
    end

    if hoverModeEnabled or hoverActivating then
        debugPrint('[HoverMode] Disabling hover mode')
        hoverActivating = false
        DisableHover()
    else
        debugPrint('[HoverMode] Enabling hover mode')
        EnableHover(vehicle)
    end
    debugPrint('[HoverMode] hoverModeEnabled:', hoverModeEnabled)
end

-- Register keybind (user can change in FiveM settings)
RegisterCommand('+hovermode', ToggleHoverMode, false)
RegisterCommand('-hovermode', function() end, false)
RegisterKeyMapping('+hovermode', 'Helicopter Hover Mode', 'keyboard', Config.VehicleFeatures and Config.VehicleFeatures.HoverMode and Config.VehicleFeatures.HoverMode.Key or '')

-- NUI callback for HeliSettings panel toggle
RegisterNuiCallback('heli:toggleHover', function(data, cb)
    cb('ok')
    if data.enabled then
        local ped = PlayerPedId()
        if not IsPedInAnyHeli(ped) then return end
        local vehicle = Utils.GetCurrentVehicle()
        if not Utils.ValidateVehicle(vehicle) then return end
        EnableHover(vehicle)
    else
        hoverActivating = false
        DisableHover()
    end
    debugPrint('[HoverMode] NUI toggle - hoverModeEnabled:', hoverModeEnabled)
end)

-- Hover mode physics thread (only runs when hover is active)
CreateThread(function()
    while true do
        -- Long sleep when hover mode is not active (saves CPU)
        if not hoverModeEnabled or not hoverVehicle then
            Wait(Utils.W(500))
            goto continue
        end

        -- Config check
        if not IsHoverEnabled() then
            hoverModeEnabled = false
            hoverVehicle = nil
            hoverAltitude = nil
            Wait(Utils.W(500))
            goto continue
        end

        -- Active hover mode
        if hoverVehicle ~= 0 and DoesEntityExist(hoverVehicle) then
            local ped = PlayerPedId()
            if IsPedInAnyHeli(ped) then
                SetHeliBladesFullSpeed(hoverVehicle)
                SetVehicleGravityAmount(hoverVehicle, 0.0)
                SetHeliTurbulenceScalar(hoverVehicle, 0.0)

                local coords = GetEntityCoords(hoverVehicle)
                local velocity = GetEntityVelocity(hoverVehicle)

                -- Altitude correction with force
                local altDiff = hoverAltitude - coords.z
                local correctionZ = (altDiff * 5.0) - (velocity.z * 2.0)
                correctionZ = math.max(-15.0, math.min(15.0, correctionZ))

                -- Dampen horizontal drift
                local dampenX = -velocity.x * 3.0
                local dampenY = -velocity.y * 3.0

                ApplyForceToEntityCenterOfMass(hoverVehicle, 0, dampenX, dampenY, correctionZ, 0, false, true, false)

                -- Stabilize pitch/roll
                local rot = GetEntityRotation(hoverVehicle, 2)
                if math.abs(rot.x) > 2.0 or math.abs(rot.y) > 2.0 then
                    SetEntityRotation(hoverVehicle, rot.x * 0.8, rot.y * 0.8, rot.z, 2, true)
                end

                Wait(0)
            else
                DisableHover()
                Wait(Utils.W(500))
            end
        else
            DisableHover()
            Wait(Utils.W(500))
        end

        ::continue::
    end
end)

RegisterCommand('enginehealth', function(_, args)
    local vehicle = cache.vehicle
    if not vehicle then return end
    local val = tonumber(args[1])
    if not val then return end
    SetVehicleEngineHealth(vehicle, val + 0.0)
end, false)

AddEventHandler('codem-hud:client:vehicleStateChanged', function(inVehicle, isBicycle)
    debugPrint('[Speedometer] vehicleStateChanged event received - inVehicle:', inVehicle, 'isBicycle:', isBicycle)
    if inVehicle then
        if speedometerActive then
            speedometerActive = false
            Wait(Utils.W(50))
        end
        debugPrint('[Speedometer] Starting speedometer thread')
        NuiMessage('setSpeedometerVisible', { inVehicle = true })
        StartSpeedometerThread()
    else
        StopSpeedometerThread()
        NuiMessage('setSpeedometerVisible', { inVehicle = false })
    end
end)
