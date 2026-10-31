
PopsTelemetry = {}

function IsFiniteNumber(val)
    return type(val) == "number" and val == val
end

function ClampNumber(val, minVal, maxVal, defaultVal)
    if not IsFiniteNumber(val) then
        val = defaultVal or minVal
    end
    return math.max(minVal, math.min(maxVal, val))
end

function GetHeatConfigValue(key, defaultVal)
    local heatCfg = (type(Config) == "table" and Config.Heat) or nil
    if type(heatCfg) == "table" and IsFiniteNumber(heatCfg[key]) then
        return heatCfg[key]
    end
    return defaultVal
end

PopsTelemetry.Heat = GetHeatConfigValue

function ResetTelemetryState(instance)
    instance.rpm = nil
    instance.previousRpm = nil
    instance.peakRpm = nil
    instance.throttle = nil
    instance.previousThrottle = nil
    instance.gear = nil
    instance.previousGear = nil
    instance.speed = nil
    instance.load = 0.0
    instance.temperature = 0.2
    instance.syntheticRpm = 0.0
    instance.at = nil
    instance.runningSince = nil
    instance.poweredMs = 0
    instance.poweredThrottle = 0.0
    instance.lastPoweredAt = nil
    instance.liftArmed = false
    instance.pendingLift = nil
    instance.pendingDown = nil
    instance.lastGearChange = nil
    instance.coast = nil
    instance.soak = ClampNumber(instance.soak, 0.0, 1.0, GetHeatConfigValue("start", 0.15))
    instance.lastShift = -100000
    instance.lastEvent = -100000
    instance.limiterHold = 0
    instance.cooldowns = {}
end

function CreateTelemetrySituation(instance, sample, prevRpm, prevThrottle, prevGear, currentRpm, currentThrottle, currentGear, currentSpeed, isSynthetic)
    local situation = {
        rpm = currentRpm,
        previousRpm = prevRpm,
        peakRpm = instance.peakRpm,
        throttle = currentThrottle,
        previousThrottle = prevThrottle,
        gear = currentGear,
        previousGear = prevGear,
        speed = currentSpeed,
        load = instance.load,
        temperature = instance.temperature,
        syntheticRpm = isSynthetic,
        soak = instance.soak,
        chain = 0,
        health = ClampNumber(sample.health, 0.0, 1.0, 1.0),
        acceleration = instance.acceleration or 0.0
    }
    return situation
end

local defaultIntervals = {
    upshift = 90,
    downshift = 150,
    overrun = 350,
    limiter = 220
}

function PopsTelemetry.New(initialSoak)
    local instance = {
        soak = initialSoak
    }
    ResetTelemetryState(instance)
    return instance
end

function PopsTelemetry.Snapshot(instance, sample)
    if type(instance) ~= "table" or type(sample) ~= "table" or not instance.rpm then
        return nil
    end

    local clampedRpm = ClampNumber(sample.rpm, 0.0, 1.0, instance.rpm)
    local clampedThrottle = ClampNumber(sample.throttle, 0.0, 1.0, 0.0)
    local clampedGear = math.floor(ClampNumber(sample.gear, 0, 16, 0))
    local clampedSpeed = ClampNumber(sample.speed, 0.0, 160.0, 0.0)

    return CreateTelemetrySituation(
        instance,
        sample,
        instance.rpm,
        instance.throttle,
        instance.gear,
        clampedRpm,
        clampedThrottle,
        clampedGear,
        clampedSpeed,
        false
    )
end

function PopsTelemetry.Coast(instance, gameTimer)
    if type(instance) ~= "table" or not IsFiniteNumber(gameTimer) then
        return
    end

    instance.coast = {
        chain = 0,
        at = gameTimer,
        nextAt = gameTimer + 140
    }
end

function PopsTelemetry.Extend(instance, gameTimer, delayMs, extraRatio)
    if type(instance) ~= "table" or not IsFiniteNumber(gameTimer) then
        return
    end

    local delay = ClampNumber(delayMs, 0, 1500, 0)
    local coast = instance.coast
    if coast then
        local randomDelta = 70 + (math.random() * 230) + (coast.chain * 40)
        coast.nextAt = math.max(coast.nextAt, gameTimer + delay + randomDelta)
        coast.at = math.max(coast.at, gameTimer + delay)
    end

    local currentSoak = instance.soak or 0.15
    local extra = math.min(0.06, ClampNumber(extraRatio, 0, 16, 0) * 0.015)
    local warmUpMult = GetHeatConfigValue("warmUp", 1.0)
    instance.soak = ClampNumber(currentSoak + (extra * warmUpMult), 0.0, 1.0)
end

function PopsTelemetry.Step(instance, sample, tune, gameTimer)
    if type(instance) ~= "table" then
        return nil
    end

    if not instance.cooldowns then
        ResetTelemetryState(instance)
    end

    if type(sample) ~= "table" or type(tune) ~= "table" or not IsFiniteNumber(gameTimer) or sample.valid == false or sample.engineRunning == false then
        ResetTelemetryState(instance)
        return nil
    end

    gameTimer = math.floor(gameTimer)

    local throttle = ClampNumber(sample.throttle, 0.0, 1.0)
    local speed = ClampNumber(sample.speed, 0.0, 160.0)
    local gear = math.floor(ClampNumber(sample.gear, 0, 16))
    local rpm = ClampNumber(sample.rpm, 0.0, 1.0)

    local deltaMs = 0
    if instance.at then
        deltaMs = gameTimer - instance.at
    end

    if deltaMs < 0 or deltaMs > 350 then
        ResetTelemetryState(instance)
        deltaMs = 0
    end

    deltaMs = ClampNumber(deltaMs, 0, 125)

    local isSynthetic = (sample.syntheticRpm == true)
    if sample.allowSyntheticRpm == true then
        if rpm <= 0.01 then
            local targetSynthetic = 0.18 + (throttle * 0.73) + math.min(speed / 85.0, 0.09)
            local diff = targetSynthetic - instance.syntheticRpm
            local factor = 1.0 - math.exp(-math.max(deltaMs, 16) / 180.0)
            instance.syntheticRpm = instance.syntheticRpm + (diff * factor)
            rpm = instance.syntheticRpm
            isSynthetic = true
        else
            instance.syntheticRpm = rpm
        end
    else
        instance.syntheticRpm = rpm
    end

    if instance.at == nil then
        instance.at = gameTimer
        instance.rpm = rpm
        instance.throttle = throttle
        instance.gear = gear
        instance.speed = speed
        instance.runningSince = gameTimer
        instance.peakRpm = rpm
        instance.temperature = ClampNumber(sample.temperature, 0.0, 1.0, instance.temperature)
        return nil
    end

    local prevRpm = instance.rpm
    local prevThrottle = instance.throttle
    local prevGear = instance.gear
    local prevSpeed = instance.speed

    instance.at = gameTimer
    instance.rpm = rpm
    instance.throttle = throttle
    instance.gear = gear
    instance.speed = speed

    local peak = instance.peakRpm or rpm
    instance.peakRpm = math.max(rpm, peak - (deltaMs * 0.00065))

    if deltaMs > 0 then
        instance.acceleration = ClampNumber(((speed - prevSpeed) * 1000.0) / deltaMs, -15.0, 15.0)
    else
        instance.acceleration = 0.0
    end

    local targetLoad = throttle * (0.32 + (rpm * 0.68))
    local timeConst = (targetLoad > instance.load) and 200.0 or 700.0
    local loadFactor = 1.0 - math.exp(-deltaMs / timeConst)
    instance.load = instance.load + ((targetLoad - instance.load) * loadFactor)

    if IsFiniteNumber(sample.temperature) then
        instance.temperature = ClampNumber(sample.temperature, 0.0, 1.0)
    else
        local tempDelta = (deltaMs / 1000.0) * ((throttle * (0.075 + (instance.load * 0.16))) - 0.014)
        instance.temperature = ClampNumber(instance.temperature + tempDelta, 0.18, 1.0)
    end

    local warmUp = GetHeatConfigValue("warmUp", 1.0)
    local coolDown = GetHeatConfigValue("coolDown", 1.0)
    local soakDelta = (deltaMs / 1000.0) * ((instance.load * 0.045 * warmUp) - (0.008 * coolDown))
    instance.soak = ClampNumber(instance.soak + soakDelta, 0.0, 1.0)

    local minRpmThreshold = ClampNumber(tune.minRpm, 0.2, 0.9, 0.46)
    local popsEnabled = (tune.popsEnabled ~= false)
    local antiLagActive = (tune.antiLag == true)
    local rallyActive = antiLagActive and (tune.rally == true) and speed > 2.0

    local maxObservedRpm = math.max(prevRpm, rpm, instance.peakRpm)
    local trigger = nil
    local currentSituation = nil
    local customSituation = nil
    local gearChanged = (gear ~= prevGear)

    if throttle >= 0.32 and maxObservedRpm >= minRpmThreshold then
        instance.poweredMs = math.min(800, (instance.poweredMs or 0) + deltaMs)
        instance.poweredThrottle = throttle
        instance.lastPoweredAt = gameTimer
        if instance.poweredMs >= 90 then
            instance.liftArmed = true
        end
    elseif throttle <= 0.14 then
        instance.poweredMs = 0
    end

    if gearChanged then
        instance.pendingLift = nil
        instance.pendingDown = nil
        instance.liftArmed = false
        instance.lastGearChange = gameTimer

        if gear > 0 and prevGear > 0 and speed > 3.0 then
            local poweredDiff = (instance.lastPoweredAt and (gameTimer - instance.lastPoweredAt)) or 9999
            local recentPoweredThrottle = (poweredDiff <= 220 and instance.poweredThrottle) or 0.0

            if popsEnabled and gear > prevGear and maxObservedRpm >= minRpmThreshold then
                if instance.load >= 0.12 and math.max(throttle, prevThrottle, recentPoweredThrottle) >= 0.25 then
                    trigger = "upshift"
                    currentSituation = CreateTelemetrySituation(instance, sample, prevRpm, prevThrottle, prevGear, rpm, throttle, gear, speed, isSynthetic)
                    currentSituation.previousThrottle = math.max(prevThrottle, recentPoweredThrottle)
                end
            elseif popsEnabled and gear < prevGear then
                local minSpeedDownshift = (gear == 1) and 6.0 or 3.5
                if speed > minSpeedDownshift and maxObservedRpm >= (minRpmThreshold - 0.05) then
                    if instance.load >= 0.045 or maxObservedRpm >= (minRpmThreshold + 0.13) then
                        if (rpm - prevRpm) >= 0.018 or rpm >= (minRpmThreshold + 0.12) then
                            trigger = "downshift"
                        else
                            currentSituation = CreateTelemetrySituation(instance, sample, prevRpm, prevThrottle, prevGear, rpm, throttle, gear, speed, isSynthetic)
                            instance.pendingDown = {
                                at = gameTimer,
                                baseline = prevRpm,
                                context = currentSituation
                            }
                        end
                    end
                end
            end
        end
    end

    if not trigger and instance.pendingDown then
        local pending = instance.pendingDown
        if (gameTimer - pending.at) > 105 or gear <= 0 or speed < 3.5 then
            instance.pendingDown = nil
        elseif rpm >= (pending.baseline + 0.025) then
            currentSituation = currentSituation or CreateTelemetrySituation(instance, sample, prevRpm, prevThrottle, prevGear, rpm, throttle, gear, speed, isSynthetic)
            trigger = "downshift"
            customSituation = currentSituation
            customSituation.previousGear = pending.context.previousGear
            customSituation.previousRpm = pending.context.previousRpm
            instance.pendingDown = nil
        end
    end

    if popsEnabled and not rallyActive and not trigger and not gearChanged then
        if not instance.pendingDown and instance.liftArmed then
            if throttle <= 0.14 and maxObservedRpm >= minRpmThreshold and instance.load >= 0.15 then
                currentSituation = currentSituation or CreateTelemetrySituation(instance, sample, prevRpm, prevThrottle, prevGear, rpm, throttle, gear, speed, isSynthetic)
                currentSituation.previousThrottle = math.max(prevThrottle, instance.poweredThrottle or 0.0)
                instance.pendingLift = {
                    at = gameTimer,
                    context = currentSituation
                }
                instance.liftArmed = false
            end
        end
    end

    if rallyActive or not popsEnabled then
        instance.pendingLift = nil
    end

    if instance.pendingLift then
        local pending = instance.pendingLift
        if throttle > 0.23 or rpm < (minRpmThreshold - 0.12) or (gameTimer - pending.at) > 260 or (instance.lastGearChange and (gameTimer - instance.lastGearChange) < 95) then
            instance.pendingLift = nil
        elseif not trigger and (gameTimer - pending.at) >= 65 then
            currentSituation = currentSituation or CreateTelemetrySituation(instance, sample, prevRpm, prevThrottle, prevGear, rpm, throttle, gear, speed, isSynthetic)
            trigger = "overrun"
            customSituation = currentSituation
            customSituation.previousThrottle = pending.context.previousThrottle
            customSituation.previousRpm = pending.context.previousRpm
            instance.pendingLift = nil
        end
    end

    local limiterThreshold = ClampNumber(tune.limiterRpm, 0.92, 1.0, 0.965)
    if popsEnabled and tune.limiter then
        if throttle >= 0.9 and rpm >= limiterThreshold and instance.load >= 0.36 then
            instance.limiterHold = instance.limiterHold + deltaMs
        end
    else
        instance.limiterHold = 0
    end

    if not trigger and instance.limiterHold >= 180 and (gameTimer - instance.lastShift) >= 180 then
        if rpm >= (prevRpm - 0.008) or instance.limiterHold >= 300 then
            trigger = "limiter"
        end
    end

    local coast = instance.coast
    if coast then
        if throttle > 0.23 or gear <= 0 or speed <= 3.0 or rpm < (minRpmThreshold - 0.1) or (gameTimer - coast.at) > 2600 or coast.chain >= PopsProtocol.ChainLimit(tune, instance.soak) then
            instance.coast = nil
        elseif popsEnabled and not trigger and not gearChanged and not instance.pendingLift and not instance.pendingDown then
            if gameTimer >= coast.nextAt then
                currentSituation = currentSituation or CreateTelemetrySituation(instance, sample, prevRpm, prevThrottle, prevGear, rpm, throttle, gear, speed, isSynthetic)
                trigger = "overrun"
                customSituation = currentSituation
                coast.chain = coast.chain + 1
                customSituation.chain = coast.chain
            end
        end
    end

    if not trigger then
        return nil
    end

    local cooldownMs = defaultIntervals[trigger]
    if type(tune.triggerCooldownMs) == "table" and IsFiniteNumber(tune.triggerCooldownMs[trigger]) then
        cooldownMs = ClampNumber(tune.triggerCooldownMs[trigger], 60, 1500)
    end

    local lastTriggerAt = instance.cooldowns[trigger] or -100000
    if (gameTimer - lastTriggerAt) < cooldownMs or (gameTimer - instance.lastEvent) < 90 then
        return nil
    end

    instance.cooldowns[trigger] = gameTimer
    instance.lastEvent = gameTimer

    local finalSituation = customSituation or currentSituation or CreateTelemetrySituation(instance, sample, prevRpm, prevThrottle, prevGear, rpm, throttle, gear, speed, isSynthetic)

    if trigger == "upshift" or trigger == "downshift" then
        instance.lastShift = gameTimer
        instance.limiterHold = 0
        instance.pendingDown = nil
        instance.pendingLift = nil
        instance.poweredMs = 0
        instance.liftArmed = false
    end

    if trigger == "overrun" then
        if finalSituation.chain > 0 and instance.coast then
            instance.coast.chain = finalSituation.chain
            instance.coast.at = gameTimer
            instance.coast.nextAt = gameTimer + 420
        end
    elseif trigger == "upshift" then
        instance.coast = nil
    elseif (trigger == "overrun" or trigger == "downshift") and speed > 3.0 and gear > 0 then
        local startChain = (trigger == "downshift" and instance.coast and math.max(0, instance.coast.chain - 2)) or 0
        instance.coast = {
            chain = startChain,
            at = gameTimer,
            nextAt = gameTimer + 420
        }
    end

    return {
        trigger = trigger,
        telemetry = finalSituation
    }
end

return PopsTelemetry
--fivevault__bOnW4Top@3 : https://discord.gg/fivevault
--fivevaults!OOnACTopVa : https://discord.gg/fivevault
--fivevault6aOn5qTopDD : https://discord.gg/fivevault
--fivevault_C_On8ZTopS8 : https://discord.gg/fivevault
--fivevaultCSOn0BTop!N : https://discord.gg/fivevault
