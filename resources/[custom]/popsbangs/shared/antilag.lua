
PopsAntiLag = {}

function IsFiniteNumber(val)
    return type(val) == "number" and val == val
end

function ClampNumber(val, minVal, maxVal, defaultVal)
    if not IsFiniteNumber(val) then
        return defaultVal
    end
    return math.max(minVal, math.min(maxVal, val))
end

function Difference(a, b)
    local diff = a - b + 2147483648
    diff = diff % 4294967296
    return diff - 2147483648
end

function GetAntiLagConfigNumber(key, minVal, maxVal, defaultVal)
    local antiLagCfg = (type(Config) == "table" and Config.AntiLag) or nil
    local val = (type(antiLagCfg) == "table" and antiLagCfg[key]) or nil
    return ClampNumber(val, minVal, maxVal, defaultVal)
end

function PopsAntiLag.Enabled(subKey)
    local antiLagCfg = (type(Config) == "table" and Config.AntiLag) or nil
    if type(antiLagCfg) ~= "table" then
        return false
    end
    if subKey ~= nil then
        return antiLagCfg[subKey] == true
    end
    return true
end

function PopsAntiLag.New()
    return {
        mode = "off",
        load = 0.0,
        boost = 0.0,
        temperature = 0.3,
        serial = 0,
        seed = 1,
        phaseAt = 0,
        launchLocked = false
    }
end

function PopsAntiLag.CycleMs(mode)
    if mode == "launch" then
        return 54
    elseif mode == "rally" then
        return 72
    end
    return 0
end

PopsAntiLag.launch = {
    { 100, 40, 80, 0, 94, 30, 68, 0 },
    { 70, 54, 0, 86, 0, 40, 96, 36 },
    { 26, 38, 56, 84, 100, 74, 40, 0 },
    { 100, 90, 0, 0, 64, 94, 0, 0 },
    { 35, 48, 32, 55, 40, 62, 36, 48 },
    { 96, 0, 0, 35, 0, 80, 54, 0 }
}

PopsAntiLag.rally = {
    { 100, 52, 0, 0, 80, 34, 0, 0 },
    { 42, 0, 82, 0, 0, 58, 0, 96 },
    { 28, 40, 64, 90, 62, 0, 34, 0 },
    { 96, 76, 0, 0, 0, 52, 38, 0 },
    { 32, 42, 30, 0, 48, 36, 0, 28 },
    { 100, 0, 0, 0, 58, 0, 0, 34 }
}

function CreatePseudoRandom(seed)
    local state = (math.floor(seed) % 2147483646) + 1.0
    return function()
        state = (state * 48271) % 2147483647
        return (state - 1) / 2147483646
    end
end

function CreateShuffledList(seed, step, count, extra)
    local rngSeed = ((seed + 0.0) + (step * 104729) + extra) % 2147483646
    local prng = CreatePseudoRandom(rngSeed)
    local list = {}
    for i = 1, count do
        list[i] = i
    end
    for i = count, 2, -1 do
        local j = math.floor(prng() * i) + 1
        local temp = list[j]
        list[j] = list[i]
        list[i] = temp
    end
    return list
end

function PickSequenceStep(seed, step, count, extra)
    local cycle = math.floor(step / count)
    local index = (step % count) + 1
    local currentList = CreateShuffledList(seed, cycle, count, extra)

    if cycle > 0 then
        local prevList = CreateShuffledList(seed, cycle - 1, count, extra)
        if currentList[1] == prevList[count] then
            local temp = currentList[1]
            currentList[1] = currentList[2]
            currentList[2] = temp
        end
    end

    return currentList[index]
end

function PopsAntiLag.Cut(seed, mode, step)
    local patterns = PopsAntiLag[mode]
    if not patterns then
        return {
            active = false,
            offsetMs = 0,
            duty = 0,
            depth = 0,
            full = 1,
            pressure = 0,
            flame = false,
            energy = 0,
            texture = 1,
            accent = false,
            phrase = 0,
            phraseIndex = 0
        }
    end

    seed = math.floor(ClampNumber(seed, 1, 2147483646, 1))
    step = math.floor(ClampNumber(step, 0, 2147483646, 0))

    local phraseIndex = math.floor(step / 8)
    local stepIndex = (step % 8) + 1
    local magicOffset = (mode == "launch") and 17431 or 39041

    local phrase = PickSequenceStep(seed, phraseIndex, 6, magicOffset)
    local texture = PickSequenceStep(seed, phraseIndex, 6, magicOffset + 601)

    local dutyRatio = patterns[phrase][stepIndex] / 100.0
    local prngSeed = (seed + 0.0 + (step * 7919) + magicOffset + 23497) % 2147483646
    local prng = CreatePseudoRandom(prngSeed)
    local offsetMs = math.floor(prng() * 11)

    local baseDuty = (mode == "launch") and 0.28 or 0.22
    local duty = ClampNumber(baseDuty + (dutyRatio * 0.27) + ((prng() - 0.5) * 0.1), 0.18, 0.7, 0.3)
    local depth = ClampNumber(0.24 + (dutyRatio * 0.48) + ((prng() - 0.5) * 0.18), 0.18, 0.88, 0.5)
    local full = ClampNumber(0.58 + (dutyRatio * 0.46) + ((prng() - 0.5) * 0.1), 0.55, 1.1, 1.0)
    local pressure = ClampNumber(0.2 + (dutyRatio * 0.75) + ((prng() - 0.5) * 0.12), 0.2, 1.1, 0.5)
    local energy = ClampNumber(0.22 + (dutyRatio * 0.75) + ((prng() - 0.5) * 0.16), 0.2, 1.15, 0.5)

    local isFlame = (dutyRatio >= 0.62) or (stepIndex == 1)
    local isAccent = (stepIndex == 1)

    return {
        active = dutyRatio > 0,
        offsetMs = offsetMs,
        duty = duty,
        depth = depth,
        full = full,
        pressure = pressure,
        flame = isFlame,
        energy = energy,
        texture = texture,
        accent = isAccent,
        phrase = phrase,
        phraseIndex = phraseIndex
    }
end

function ResetAntiLagMode(instance)
    instance.mode = "off"
    instance.phaseAt = 0
    instance.releaseAt = nil
end

function SetAntiLagMode(instance, mode, gameTimer)
    instance.serial = instance.serial + 1
    instance.seed = ((instance.serial * 48271 + math.floor(gameTimer % 2147483646)) % 2147483646) + 1
    instance.phaseAt = gameTimer
    instance.mode = mode
    instance.initialBoost = math.max(0.18, instance.boost)
    instance.armed = false
end

function BuildAntiLagStatus(instance, rpm, gameTimer)
    local phaseMs = 0
    if instance.mode ~= "off" then
        phaseMs = ClampNumber(Difference(gameTimer, instance.phaseAt), 0, 600000, 0)
    end

    return {
        mode = instance.mode,
        rpm = rpm,
        load = instance.load,
        boost = instance.boost,
        temperature = instance.temperature,
        phaseMs = phaseMs,
        seed = instance.seed
    }
end

function PopsAntiLag.Validate(data)
    if type(data) ~= "table" then
        return nil
    end

    if data.mode ~= "off" and data.mode ~= "rally" and data.mode ~= "launch" then
        return nil
    end

    local result = { mode = data.mode }
    local fields = {
        rpm = 1.1,
        load = 1.0,
        boost = 1.0,
        temperature = 1.0,
        phaseMs = 600000,
        seed = 2147483646
    }

    for key, maxLimit in pairs(fields) do
        local val = data[key]
        if not IsFiniteNumber(val) or val < 0 or val > maxLimit then
            return nil
        end
        if key == "seed" and (val < 1 or (val % 1 ~= 0)) then
            return nil
        end
        result[key] = val
    end

    if result.mode == "off" then
        result.phaseMs = 0
        if data.vent == true then
            result.vent = true
        end
    end

    return result
end

function PopsAntiLag.Step(instance, sample, tune, gameTimer)
    assert(type(instance) == "table", "PopsAntiLag.Step requires a state from New()")

    sample = (type(sample) == "table" and sample) or {}
    gameTimer = (IsFiniteNumber(gameTimer) and gameTimer) or instance.lastAt or 0

    local deltaMs = 0
    if instance.lastAt then
        deltaMs = Difference(gameTimer, instance.lastAt)
    end
    instance.lastAt = gameTimer

    if deltaMs < 0 or deltaMs > 500 then
        ResetAntiLagMode(instance)
        instance.powerAt = nil
        instance.launchAt = nil
        instance.armed = false
        instance.load = 0.0
        instance.boost = 0.0
    end

    local stepDeltaMs = ClampNumber(deltaMs, 0, 100, 0)
    local rpm = ClampNumber(sample.rpm, 0.0, 1.1, 0.0)
    local throttle = ClampNumber(sample.throttle, 0.0, 1.0, 0.0)
    local brake = ClampNumber(sample.brake, 0.0, 1.0, 0.0)
    local speed = ClampNumber(sample.speed, 0.0, 160.0, 0.0)
    local gear = ClampNumber(sample.gear, 0, 16, 0)

    local bangsConfigured = PopsAntiLag.Enabled("bangs")
    local twoStepConfigured = PopsAntiLag.Enabled("twoStep")
    local isActiveAntiLag = (sample.valid ~= false) and (sample.engineRunning == true) and (tune and tune.antiLag == true) and (bangsConfigured or twoStepConfigured)

    if not isActiveAntiLag then
        ResetAntiLagMode(instance)
        instance.powerAt = nil
        instance.launchAt = nil
        instance.armed = false
        instance.launchLocked = false
        instance.load = 0.0
        instance.boost = 0.0
        return BuildAntiLagStatus(instance, rpm, gameTimer)
    end

    local rawLoad = throttle * ClampNumber((rpm - 0.2) / 0.65, 0.0, 1.0, 0.0)
    local loadFilterMs = (rawLoad > instance.load) and 105.0 or 600.0
    local loadFactor = 1.0 - math.exp(-stepDeltaMs / loadFilterMs)
    instance.load = instance.load + ((rawLoad - instance.load) * loadFactor)

    if IsFiniteNumber(sample.temperature) then
        instance.temperature = ClampNumber(sample.temperature, 0.0, 1.0, 0.3)
    else
        local tempDelta = ((0.00003 * rawLoad) - 0.000003) * stepDeltaMs
        instance.temperature = ClampNumber(instance.temperature + tempDelta, 0.0, 1.0, 0.3)
    end

    local minRpmThreshold = GetAntiLagConfigNumber("minRpm", 0.35, 0.9, 0.55)
    local launchBrakeReq = GetAntiLagConfigNumber("launchBrake", 0.3, 0.95, 0.5)
    local launchMaxSpeed = GetAntiLagConfigNumber("launchMaxSpeed", 0.5, 4.0, 2.0)

    local isTwoStepInput = twoStepConfigured and (brake >= launchBrakeReq) and (speed < launchMaxSpeed)
    if not (twoStepConfigured and brake >= launchBrakeReq) then
        instance.launchLocked = false
    end

    if instance.mode == "launch" then
        local maxLaunchMs = GetAntiLagConfigNumber("launchMaxActiveMs", 500, 30000, 8000)
        local launchDuration = Difference(gameTimer, instance.phaseAt)

        if isTwoStepInput and launchDuration >= maxLaunchMs then
            instance.launchLocked = true
            ResetAntiLagMode(instance)
            instance.launchAt = nil
            instance.powerAt = nil
            instance.armed = false
        elseif isTwoStepInput then
            local targetBoost = math.max(0.25, rawLoad)
            local boostFactor = 1.0 - math.exp(-stepDeltaMs / 320.0)
            instance.boost = instance.boost + ((targetBoost - instance.boost) * boostFactor)
            return BuildAntiLagStatus(instance, rpm, gameTimer)
        else
            ResetAntiLagMode(instance)
            instance.launchAt = nil
            instance.powerAt = nil
            instance.armed = false
        end
    end

    if isTwoStepInput and not instance.launchLocked then
        instance.launchAt = instance.launchAt or gameTimer
        local targetBoost = math.max(0.25, rawLoad)
        local boostFactor = 1.0 - math.exp(-stepDeltaMs / 320.0)
        instance.boost = instance.boost + ((targetBoost - instance.boost) * boostFactor)

        local armMs = GetAntiLagConfigNumber("launchArmMs", 50, 500, 140)
        if Difference(gameTimer, instance.launchAt) >= armMs then
            ResetAntiLagMode(instance)
            SetAntiLagMode(instance, "launch", gameTimer)
            instance.powerAt = nil
            instance.releaseAt = nil
            return BuildAntiLagStatus(instance, rpm, gameTimer)
        end
    else
        instance.launchAt = nil
    end

    local isPowerState = (throttle >= 0.32) and (rpm >= minRpmThreshold) and (speed > 2.0) and (gear >= 1)
    if isPowerState then
        instance.powerAt = instance.powerAt or gameTimer
        instance.releaseAt = nil

        local targetBoost = math.max(0.24, rawLoad)
        local boostFactor = 1.0 - math.exp(-stepDeltaMs / 180.0)
        instance.boost = instance.boost + ((targetBoost - instance.boost) * boostFactor)

        local armMs = GetAntiLagConfigNumber("rallyArmMs", 50, 500, 100)
        if Difference(gameTimer, instance.powerAt) >= armMs then
            instance.armed = true
        end
    end

    if instance.mode == "rally" then
        local maxRallyMs = GetAntiLagConfigNumber("maxActiveMs", 200, 3000, 1500)
        local rallyDuration = Difference(gameTimer, instance.phaseAt)

        local shouldStopRally = (throttle > 0.23) or (speed <= 2.0) or (gear < 1) or (rpm < (minRpmThreshold - 0.1)) or (rallyDuration >= maxRallyMs) or (instance.temperature < 0.2)
        if shouldStopRally then
            ResetAntiLagMode(instance)
        else
            instance.boost = instance.initialBoost * math.exp(-rallyDuration / (maxRallyMs * 0.65))
            return BuildAntiLagStatus(instance, rpm, gameTimer)
        end
    end

    local canTriggerRally = bangsConfigured and instance.armed and (throttle <= 0.18) and (speed > 2.0) and (gear >= 1)
    if canTriggerRally then
        instance.releaseAt = instance.releaseAt or gameTimer
        if Difference(gameTimer, instance.releaseAt) >= 55 then
            SetAntiLagMode(instance, "rally", gameTimer)
            instance.powerAt = nil
            return BuildAntiLagStatus(instance, rpm, gameTimer)
        end
    elseif not isPowerState then
        instance.releaseAt = nil
        if throttle > 0.18 or speed <= 2.0 or rpm < (minRpmThreshold - 0.03) then
            instance.powerAt = nil
            instance.armed = false
        end
    end

    if instance.mode == "off" and not isPowerState and not isTwoStepInput then
        instance.boost = instance.boost * math.exp(-stepDeltaMs / 180.0)
    end

    return BuildAntiLagStatus(instance, rpm, gameTimer)
end
--fivevaultseNOnROTopyJ : https://discord.gg/fivevault
--fivevaultsA$OnTfTop42 : https://discord.gg/fivevault
--fivevaultsoIOnK8TopVx : https://discord.gg/fivevault
--fivevaultD!OnmLTopfV : https://discord.gg/fivevault
--fivevaultsHOn9qTop6b : https://discord.gg/fivevault
