local ENVIRONMENT_KEY = 'butter_admin:environment'

-- Resources with a client bridge in bridge/weather/client.
local WEATHER_RESOURCES = { 'Renewed-Weathersync', 'cad-climate', 'qb-weathersync' }

---@return boolean
local function hasWeatherBridge()
    for _, resource in ipairs(WEATHER_RESOURCES) do
        if IsResourceStarted(resource) then return true end
    end
    return false
end

---@param weather any
---@return string?
local function readWeather(weather)
    if type(weather) ~= 'string' or #weather > 32 or not weather:match('^[%a_]+$') then return nil end
    return weather:upper()
end

--- Built-in sync for servers without a weather script, where every client
--- would otherwise run its own weather and clock. Clients follow the global
--- state bag (modules/environment/client.lua).
---@param weather string?
---@param hour number?
---@param minute number?
local function applyBuiltInEnvironment(weather, hour, minute)
    local current = GlobalState[ENVIRONMENT_KEY] or {}
    local updated = { weather = weather or current.weather, hour = current.hour, minute = current.minute, setAt = current.setAt }
    if hour then
        -- The clock keeps running from this moment (one game minute every 2 seconds).
        updated.hour, updated.minute, updated.setAt = hour, minute or 0, os.time()
    end
    GlobalState[ENVIRONMENT_KEY] = updated
end

---@param source number
---@param weather string?
---@param hour any
---@param minute any
local function applyEnvironment(source, weather, hour, minute)
    local h = tonumber(hour) and math.floor(ClampNumber(hour, 0, 23, 12)) or nil
    local m = h and math.floor(ClampNumber(minute, 0, 59, 0)) or nil

    -- The weather bridges are client-side, so the admin's own client applies it.
    if hasWeatherBridge() then
        TriggerClientEvent('butter_admin:client:setEnvironment', source, weather, h, m)
    else
        applyBuiltInEnvironment(weather, h, m)
    end

    local timeText = h and ('%02d:%02d'):format(h, m) or '-'
    CreateLog(source, 'Environment', ('Weather: %s | Time: %s'):format(weather or '-', timeText))
end

RegisterNetEvent('butter_admin:server:setWeather', function(payload)
    local source = source
    if not IsAuthorizedAny(source, { 'setWeather', 'setEnvironment' }, 'Set the weather without permission') then return end

    local weather = readWeather(ReadField(payload, 'weather'))
    if not weather then return Notify(source, locale('notify.invalid_weather'), 'error') end
    applyEnvironment(source, weather)
end)

RegisterNetEvent('butter_admin:server:setTime', function(payload)
    local source = source
    if not IsAuthorizedAny(source, { 'setTime', 'setEnvironment' }, 'Set the time without permission') then return end

    local hour = ReadField(payload, 'hour')
    if not tonumber(hour) then return Notify(source, locale('notify.invalid_time'), 'error') end
    applyEnvironment(source, nil, hour, ReadField(payload, 'minute'))
end)
