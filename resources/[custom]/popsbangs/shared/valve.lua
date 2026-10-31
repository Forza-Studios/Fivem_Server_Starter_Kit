
PopsValve = {}

function PopsValve.Tune(tune, isClosed)
    local result = {}
    for k, v in pairs(tune or {}) do
        result[k] = v
    end

    result.valveClosed = (isClosed == true)
    if not result.valveClosed then
        return result
    end

    local valveConfig = (type(Config) == "table" and Config.Valve) or {}
    local currentVolume = result.volume or 1
    local closedVolume = valveConfig.closedVolume or 0.24
    result.volume = currentVolume * closedVolume

    local currentRadius = result.radius or 90
    local closedRadius = valveConfig.closedRadius or 45
    result.radius = math.min(currentRadius, closedRadius)

    local currentEcho = result.echo or 0
    result.echo = currentEcho * 0.15

    local currentLift = result.liftChance or 1
    result.liftChance = math.min(currentLift, 0.3)

    local currentShift = result.shiftChance or 1
    result.shiftChance = math.min(currentShift, 0.24)

    result.overrun = 0
    result.heavyChance = 0
    result.boomChance = 0
    result.limiter = false
    result.antiLag = false
    result.rally = false

    return result
end

function PopsValve.Pulses(pulses, isClosed, eventType, situation)
    if not isClosed then
        return pulses
    end

    if eventType ~= "launch" and eventType ~= "antilag" and eventType ~= "limiter" then
        if situation and (situation.chain or 0) > 0 then
            return {}
        end
    else
        return {}
    end

    local result = {}
    local maxCount = math.min(#pulses, 2)

    for i = 1, maxCount do
        local pulse = {}
        for k, v in pairs(pulses[i] or {}) do
            pulse[k] = v
        end

        pulse.kind = "burble"
        pulse.heavy = false
        pulse.layers = {}
        pulse.energy = math.min(pulse.energy or 0.3, 0.3)
        pulse.scale = math.min(pulse.scale or 0.2, 0.22)
        pulse.durationMs = 65
        pulse.bodyDb = -3
        pulse.echoScale = 0.1
        pulse.tail = 0.65
        pulse.phrase = "quiet"

        result[#result + 1] = pulse
    end

    return result
end
--fivevault-MUOn-RTopet : https://discord.gg/fivevault
--fivevault_anOnfoTopuw : https://discord.gg/fivevault
--fivevaultwMOnN3ToppD : https://discord.gg/fivevault
--fivevaultR_OnQLTopyt : https://discord.gg/fivevault
--fivevault-$AOn20TopYf : https://discord.gg/fivevault
