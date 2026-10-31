-- Manual Transmission System
-- Uses soft speed limiting for natural RPM behavior

if not Config.ManualTransmission.Enabled then return end

local isManualMode = false
local manualGear = 1
local manualRpm = 0.2
local maxGears = 6
local lastVehicleNetId = nil
local vehicleTopSpeed = nil

-- Speed multiplier per gear (percentage of max speed)
local gearSpeedMultiplier = {
    [1] = 0.15,  -- 1. vites: %15 (~27 km/h for 180 km/h car)
    [2] = 0.30,  -- 2. vites: %30 (~54 km/h)
    [3] = 0.50,  -- 3. vites: %50 (~90 km/h)
    [4] = 0.70,  -- 4. vites: %70 (~126 km/h)
    [5] = 0.85,  -- 5. vites: %85 (~153 km/h)
    [6] = 1.00,  -- 6. vites: %100 (max)
}

-- Export for speedometer (3rd return = calculated RPM based on speed/gear ratio)
function GetManualTransmissionState()
    return isManualMode, manualGear, manualRpm
end

exports('GetManualTransmissionState', GetManualTransmissionState)

-- Backfire/Exhaust Pop Effect (all exhaust bones)
local function PlayBackfireEffect(vehicle, intensity)
    if not DoesEntityExist(vehicle) then return end

    local particleDict = 'core'
    if not Utils.EnsureParticleFxAsset(particleDict, 1000) then return end

    local exhaustNames = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4', 'exhaust_5', 'exhaust_6', 'exhaust_7', 'exhaust_8' }
    local bones = {}
    for _, name in ipairs(exhaustNames) do
        local bone = GetEntityBoneIndexByName(vehicle, name)
        if bone ~= -1 then bones[#bones + 1] = bone end
    end

    local heading = GetEntityHeading(vehicle)

    if #bones > 0 then
        for _, bone in ipairs(bones) do
            UseParticleFxAsset(particleDict)
            local bonePos = GetWorldPositionOfEntityBone(vehicle, bone)
            StartParticleFxNonLoopedAtCoord('veh_backfire', bonePos.x, bonePos.y, bonePos.z, 0.0, 0.0, heading, intensity, false, false, false)
        end
    else
        UseParticleFxAsset(particleDict)
        local behindOffset = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.5, 0.3)
        StartParticleFxNonLoopedAtCoord('veh_backfire', behindOffset.x, behindOffset.y, behindOffset.z, 0.0, 0.0, heading, intensity, false, false, false)
    end

    PlaySoundFromEntity(-1, 'EXPLODE', vehicle, 'CARMOD_SHOP_SOUNDS', false, 0)
end

-- Helper: Get current vehicle
local function GetCurrentVehicle()
    local vehicle = Utils.GetCurrentVehicle()
    if not Utils.ValidateVehicle(vehicle) then return nil end
    return vehicle
end

-- Get vehicle's max gears from handling
local function GetVehicleMaxGears(vehicle)
    if not DoesEntityExist(vehicle) then return 6 end
    local gears = GetVehicleHandlingInt(vehicle, 'CHandlingData', 'nInitialDriveGears')
    return gears > 0 and gears or 6
end

-- Get vehicle's network ID for reliable tracking
local function GetVehicleNetworkId(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return nil end
    if NetworkGetEntityIsNetworked(vehicle) then
        return NetworkGetNetworkIdFromEntity(vehicle)
    end
    return GetEntityModel(vehicle) .. '_' .. tostring(vehicle)
end

-- Get vehicle's top speed (m/s)
local function GetVehicleTopSpeed(vehicle)
    if vehicleTopSpeed then return vehicleTopSpeed end
    if not DoesEntityExist(vehicle) then return 50.0 end

    local topSpeed = GetVehicleEstimatedMaxSpeed(vehicle)
    if not topSpeed or topSpeed < 10 or topSpeed > 100 then
        topSpeed = 50.0
    end

    vehicleTopSpeed = topSpeed
    return topSpeed
end

-- Get gear max speed
local function GetGearMaxSpeed(gear)
    local vehicle = GetCurrentVehicle()
    if not vehicle then return 50.0 end
    local topSpeed = GetVehicleTopSpeed(vehicle)
    local multiplier = gearSpeedMultiplier[gear] or 1.0
    return topSpeed * multiplier
end

-- Engine Over-Rev on Aggressive Downshift
-- GTA motor sesi throttle input'a bağlı, RPM'e değil.
-- Bu yüzden: gaz simüle et (motor bağırsın) + ters kuvvet uygula (hızlanmasın)
local overRevGeneration = 0

local function ApplyDownshiftOverRev(vehicle, speedKmh, newGear)
    if not DoesEntityExist(vehicle) then return end

    local newGearMaxSpeedMs = GetGearMaxSpeed(newGear)
    if newGearMaxSpeedMs <= 0 then return end
    local newGearMaxSpeedKmh = newGearMaxSpeedMs * 3.6

    local overRevRatio = speedKmh / newGearMaxSpeedKmh
    if overRevRatio < 0.5 then return end

    local brakeStrength = math.min(5.0, math.max(1.0, (overRevRatio - 0.5) * 8.0))
    local duration = math.floor(math.min(1500, 400 + (overRevRatio - 0.5) * 2000))

    local shakeIntensity = math.min(0.4, (overRevRatio - 0.5) * 0.8)
    ShakeGameplayCam('ROAD_VIBRATION_SHAKE', shakeIntensity)

    overRevGeneration = overRevGeneration + 1
    local myGen = overRevGeneration

    CreateThread(function()
        local startTime = GetGameTimer()
        local gtaGear = newGear + 1
        local startSpeed = GetEntitySpeed(vehicle)

        SetVehicleHighGear(vehicle, gtaGear)
        SetVehicleCurrentGear(vehicle, gtaGear)
        SetVehicleNextGear(vehicle, gtaGear)

        while myGen == overRevGeneration do
            if not DoesEntityExist(vehicle) then break end
            if not isManualMode then break end

            local elapsed = GetGameTimer() - startTime
            if elapsed >= duration then break end

            -- Cancel over-rev if player is braking
            local braking = GetControlNormal(0, 72) > 0.1 -- S key / brake
            if braking then break end

            local progress = elapsed / duration

            -- Düşük vites zorla (oyun otomatik değiştirmesin)
            SetVehicleCurrentGear(vehicle, gtaGear)
            SetVehicleNextGear(vehicle, gtaGear)

            -- GAZ SİMÜLE ET -> motor SES ÇIKARIR
            -- GTA ses sistemi throttle input'a bakıyor
            local throttle = math.max(0.3, 1.0 - (progress * progress))
            SetControlNormal(0, 71, throttle)   -- VEH_ACCELERATE
            SetVehicleCurrentRpm(vehicle, math.min(1.0, 0.7 + throttle * 0.3))

            -- TERS KUVVET -> araç hızlanmasın, yavaşlasın (engine braking)
            local currentSpeed = GetEntitySpeed(vehicle)
            local brakeFactor = brakeStrength * (1.0 - progress * 0.7)

            -- Hız başlangıçtan fazlaysa ekstra frenle (gaz yüzünden hızlanmasın)
            if currentSpeed > startSpeed then
                brakeFactor = brakeFactor + (currentSpeed - startSpeed) * 2.0
            end

            ApplyForceToEntityCenterOfMass(vehicle, 0, 0.0, -brakeFactor, 0.0, 0, true, true, false)

            Wait(0)
        end

        if myGen == overRevGeneration then
            StopGameplayCamShaking(true)
        end
    end)
end

-- Apply gear: force immediate gear change for natural RPM behavior
local function ApplyGear(vehicle, gear)
    if not DoesEntityExist(vehicle) then return end
    local gtaGear = gear + 1
    SetVehicleHighGear(vehicle, gtaGear)
    -- Force the actual gear change immediately (not just the ceiling)
    -- This makes the engine naturally produce correct RPM for the gear/speed ratio
    -- High speed + low gear = high RPM = engine screams
    SetVehicleCurrentGear(vehicle, gtaGear)
    SetVehicleNextGear(vehicle, gtaGear)
end

-- Remove gear limit
local function RemoveGearLimit(vehicle)
    if not DoesEntityExist(vehicle) then return end
    local gears = GetVehicleHandlingInt(vehicle, 'CHandlingData', 'nInitialDriveGears')
    if gears <= 0 then gears = 6 end
    SetVehicleHighGear(vehicle, gears)
    manualRpm = 0.2
end

-- NUI Callback: Set transmission mode
RegisterNUICallback('setTransmissionMode', function(data, cb)
    if data and data.mode then
        local newMode = (data.mode == 'manuel')
        if newMode == isManualMode then
            cb('ok')
            return
        end

        isManualMode = newMode

        local vehicle = GetCurrentVehicle()
        if vehicle then
            maxGears = GetVehicleMaxGears(vehicle)
            lastVehicleNetId = GetVehicleNetworkId(vehicle)
            vehicleTopSpeed = nil

            if isManualMode then
                manualGear = 1
                ApplyGear(vehicle, manualGear)
            else
                RemoveGearLimit(vehicle)
                lastSuggestion = nil
                SendNUIMessage({ action = 'gearSuggestion', data = { suggestion = nil } })
            end
        end
    end
    cb('ok')
end)

-- Shift Up
RegisterCommand('+shiftUp', function()
    if not isManualMode then return end
    local vehicle = GetCurrentVehicle()
    if not vehicle then return end
    if GetVehicleCurrentGear(vehicle) == 0 then return end

    if manualGear < maxGears then
        manualGear = manualGear + 1
        ApplyGear(vehicle, manualGear)
        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    end
end, false)

RegisterCommand('-shiftUp', function() end, false)
RegisterKeyMapping('+shiftUp', Config.ManualTransmission.ShiftUpDescription, 'keyboard', Config.ManualTransmission.ShiftUpKey)

-- Shift Down
RegisterCommand('+shiftDown', function()
    if not isManualMode then return end
    local vehicle = GetCurrentVehicle()
    if not vehicle then return end
    if GetVehicleCurrentGear(vehicle) == 0 then return end

    if manualGear > 1 then
        manualGear = manualGear - 1
        ApplyGear(vehicle, manualGear)

        local speed = GetEntitySpeed(vehicle) * 3.6

        -- Engine over-rev: RPM spike + engine braking + camera shake
        ApplyDownshiftOverRev(vehicle, speed, manualGear)

        -- Backfire particle + sound at higher speeds
        if speed > 50 then
            local intensity = math.min(1.5, 0.5 + (speed / 200))
            CreateThread(function()
                PlayBackfireEffect(vehicle, intensity)
                SendNUIMessage({ action = 'backfireEffect', data = { intensity = intensity } })
                if speed > 100 then
                    Wait(100)
                    PlayBackfireEffect(vehicle, intensity * 0.7)
                end
            end)
        end

        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    end
end, false)

RegisterCommand('-shiftDown', function() end, false)
RegisterKeyMapping('+shiftDown', Config.ManualTransmission.ShiftDownDescription, 'keyboard', Config.ManualTransmission.ShiftDownKey)

-- Radio wheel disable moved to pausemenu.lua (always active, not just manual mode)

-- Main control thread
local lastSuggestion = nil

CreateThread(function()
    local DisableControlAction = DisableControlAction
    local GetEntitySpeed = GetEntitySpeed
    local DoesEntityExist = DoesEntityExist

    while true do
        local vehicle = GetCurrentVehicle()

        if vehicle then
            local currentNetId = GetVehicleNetworkId(vehicle)

            -- Vehicle changed
            if currentNetId ~= lastVehicleNetId then
                lastVehicleNetId = currentNetId
                vehicleTopSpeed = nil
                maxGears = GetVehicleMaxGears(vehicle)

                if isManualMode then
                    manualGear = 1
                    ApplyGear(vehicle, manualGear)
                end
            end

            if isManualMode and DoesEntityExist(vehicle) then
                if GetVehicleCurrentGear(vehicle) == 0 then
                    if manualGear ~= 1 then
                        manualGear = 1
                    end
                    Wait(100)
                    goto continue
                end

                local currentSpeed = GetEntitySpeed(vehicle)
                local gearMaxSpeed = GetGearMaxSpeed(manualGear)
                local suggestion = nil

                -- Calculate RPM from speed/gear ratio for accurate display
                if gearMaxSpeed > 0 then
                    local speedRatio = math.min(1.0, currentSpeed / gearMaxSpeed)
                    manualRpm = 0.2 + speedRatio * 0.8
                end

                -- Speed limiting
                local throttleBlocked = false

                -- Max hıza ulaştıysa throttle engelle
                if gearMaxSpeed > 0 and currentSpeed >= gearMaxSpeed then
                    throttleBlocked = true
                -- Eğer mevcut vites için hız çok düşükse (motor boğulur)
                elseif manualGear > 1 then
                    local prevGearMaxSpeed = GetGearMaxSpeed(manualGear - 1)
                    -- Bir alt vitesin max hızının %40'ının altındaysa bu viteste ivmelenemez
                    if currentSpeed < prevGearMaxSpeed * 0.40 then
                        throttleBlocked = true
                    end
                end

                if throttleBlocked then
                    DisableControlAction(0, 71, true)  -- VEH_ACCELERATE (W)
                    DisableControlAction(0, 87, true)  -- VEH_FLY_THROTTLE_UP
                    DisableControlAction(0, 327, true) -- VEH_ACCELERATE (alternate)
                end

                -- Gear suggestion based on speed
                if gearMaxSpeed > 0 then
                    local speedRatio = currentSpeed / gearMaxSpeed

                    -- Gear UP: Mevcut vitesin %85'ine ulaştıysa
                    if speedRatio >= 0.85 and manualGear < maxGears then
                        suggestion = "up"
                    -- Gear DOWN: Bir alt vitesin max hızının %70'inin altındaysa
                    elseif manualGear > 1 then
                        local prevGearMaxSpeed = GetGearMaxSpeed(manualGear - 1)
                        if prevGearMaxSpeed > 0 and currentSpeed < prevGearMaxSpeed * 0.70 then
                            suggestion = "down"
                        end
                    end
                end

                -- Only send NUI message when suggestion changes
                if suggestion ~= lastSuggestion then
                    lastSuggestion = suggestion
                    SendNUIMessage({
                        action = 'gearSuggestion',
                        data = { suggestion = suggestion }
                    })
                end

                Wait(0)
                ::continue::
            else
                Wait(500)
            end
        else
            if lastVehicleNetId then
                lastVehicleNetId = nil
                vehicleTopSpeed = nil
            end
            Wait(500)
        end
    end
end)
