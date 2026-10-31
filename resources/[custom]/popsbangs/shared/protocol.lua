
PopsProtocol = {}

PopsProtocol.Intervals = {
    upshift = 90,
    downshift = 150,
    overrun = 350,
    limiter = 220,
    antilag = 420,
    launch = 1200
}

function PopsProtocol.Finite(value)
    return type(value) == "number" and value == value
end

function PopsProtocol.Integer(value, minVal, maxVal)
    if PopsProtocol.Finite(value) then
        return (value % 1 == 0) and (minVal <= value) and (value <= maxVal)
    end
    return false
end

function PopsProtocol.MaxLevel()
    local levels = (type(Config) == "table" and Config.Levels) or nil
    local count = 0
    while type(levels) == "table" and type(levels[count + 1]) == "table" and count < 9 do
        count = count + 1
    end
    return count
end

function PopsProtocol.Difference(a, b)
    local diff = a - b + 2147483648
    diff = diff % 4294967296
    return diff - 2147483648
end

function PopsProtocol.SampleOffsets(offsets)
    if offsets == nil then
        return {
            snap = 0,
            crackle = 0,
            bang = 0,
            burble = 0,
            boom = 0
        }
    end

    if type(offsets) ~= "table" then
        return nil
    end

    local result = {}
    local keys = { "snap", "crackle", "bang", "burble", "boom" }

    for _, key in ipairs(keys) do
        local val = offsets[key]
        if val == nil and key == "boom" then
            val = 0
        end

        if not PopsProtocol.Integer(val, 0, 2147483646) then
            return nil
        end

        result[key] = val
    end

    return result
end

function PopsProtocol.Normalize(situation)
    if type(situation) ~= "table" then
        return nil
    end

    local result = {}
    local limits = {
        rpm = 1.1,
        previousRpm = 1.1,
        peakRpm = 1.1,
        throttle = 1.0,
        previousThrottle = 1.0,
        gear = 16,
        previousGear = 16,
        speed = 160,
        load = 1.0,
        temperature = 1.0
    }

    for prop, maxLimit in pairs(limits) do
        local val = situation[prop]
        if not PopsProtocol.Finite(val) or val < 0 or val > maxLimit then
            return nil
        end
        if (prop == "gear" or prop == "previousGear") and (val % 1 ~= 0) then
            return nil
        end
        result[prop] = val
    end

    result.syntheticRpm = (situation.syntheticRpm == true)

    local soak = situation.soak
    if soak == nil then
        soak = result.temperature
    end

    local health = situation.health
    if health == nil then
        health = 1.0
    end

    local chain = situation.chain
    if chain == nil then
        chain = 0
    end

    if not PopsProtocol.Finite(soak) or soak < 0 or soak > 1 then
        return nil
    end

    if not PopsProtocol.Finite(health) or health < 0 or health > 1 then
        return nil
    end

    if not PopsProtocol.Integer(chain, 0, 8) then
        return nil
    end

    result.chain = chain
    result.health = health
    result.soak = soak

    return result
end

function PopsProtocol.ChainLimit(tune, soak)
    local level = 2
    if type(tune) == "table" and PopsProtocol.Integer(tune.level, 1, 9) then
        level = tune.level
    end

    local overrun = nil
    if type(tune) == "table" and PopsProtocol.Integer(tune.overrun, 0, 7) then
        overrun = tune.overrun
    end

    if not overrun then
        local defaults = { [1] = 1, [2] = 3, [3] = 5 }
        overrun = defaults[level] or 5
    end

    local extra = 0
    if PopsProtocol.Finite(soak) and soak > 0.6 and overrun > 0 then
        extra = 1
    end

    return overrun + extra
end

function PopsProtocol.Eligible(eventType, situation, tune)
    local interval = PopsProtocol.Intervals[eventType]
    if not interval or not tune then
        return false
    end

    if eventType == "antilag" or eventType == "launch" then
        return tune.antiLag == true
    end

    local chain = (situation and situation.chain) or 0
    if chain > 0 then
        local maxChain = PopsProtocol.ChainLimit(tune, situation.soak)
        return chain <= maxChain
    end

    local highestRpm = math.max(situation.rpm, situation.previousRpm, situation.peakRpm)
    local minRpm = tune.minRpm or 0.5
    if eventType == "downshift" then
        minRpm = minRpm - 0.05
    end

    if highestRpm < minRpm then
        return false
    end

    if eventType == "upshift" then
        return situation.previousGear >= 1
    elseif eventType == "downshift" then
        return situation.previousGear > situation.gear
    elseif eventType == "overrun" then
        return situation.throttle < 0.25
    end

    return tune.limiter == true
end

function PopsProtocol.ShouldEmit(eventType, tune, seed)
    local chance = 0
    if eventType == "antilag" or eventType == "launch" then
        return tune.antiLag == true
    end

    if eventType == "upshift" then
        chance = tune.shiftChance
    elseif eventType == "overrun" then
        chance = tune.liftChance
    elseif eventType == "downshift" then
        chance = math.min(1.0, (tune.shiftChance or 0.7) + 0.12)
    else
        chance = tune.limiter and 1 or 0
    end

    if chance == nil then
        chance = 1.0
    end

    local prng = ((seed + 0.0) * 48271) % 2147483647 / 2147483647
    return prng <= chance
end

function PopsProtocol.Key(netId, epoch, sequence, outlet)
    return string.format("%d:%d:%d:%d", netId, epoch, sequence, outlet)
end
--fivevaultsPBOnFDTopE- : https://discord.gg/fivevault
--fivevaultsDYOn7LTop$d : https://discord.gg/fivevault
--fivevaultsZBOnd_TopsG : https://discord.gg/fivevault
--fivevault-aDOn2hTop-I : https://discord.gg/fivevault
--fivevaultsVeOnHQTop@l : https://discord.gg/fivevault
