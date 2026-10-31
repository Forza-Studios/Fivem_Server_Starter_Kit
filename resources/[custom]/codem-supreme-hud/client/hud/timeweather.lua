--[[
    HUD Time & Weather Module
    Time and weather display with adaptive updates
]]

-- Shared state
lastTimeWeather = lastTimeWeather or { time = '', weather = '', isNight = nil }

-- Time mode setting (synced from NUI)
-- 'local' = real local time, 'game' = in-game time
TimeMode = 'local'

-- Local time from JavaScript (updated via NUI callback)
LocalTimeData = { time = '', hour = 0, date = '' }

-- NUI callback to update time mode setting
RegisterNUICallback('SET_TIME_MODE', function(data, cb)
    TimeMode = data.mode or 'local'
    lastTimeWeather.time = '' -- Reset to force update
    TriggerEvent('codem-hud:client:TimeModeChanged', TimeMode)

    -- Immediately send the new time (don't wait for next cycle)
    local time
    if TimeMode == 'local' then
        time = LocalTimeData.time
    else
        local hour = GetClockHours()
        local mins = GetClockMinutes()
        time = string.format('%02d:%02d', hour, mins)
    end
    -- Always send update on mode change, regardless of previous value
    if time and time ~= '' then
        lastTimeWeather.time = time
        NuiMessage('updateTime', { time = time })
    else
        -- If time is empty (e.g. game not fully loaded), send placeholder
        NuiMessage('updateTime', { time = '--:--' })
    end

    cb('ok')
end)

    -- NUI callback to receive local time from JavaScript
RegisterNUICallback('UPDATE_LOCAL_TIME', function(data, cb)
    LocalTimeData.time = data.time or ''
    LocalTimeData.hour = data.hour or 0
    LocalTimeData.date = data.date or ''
    
    -- When using local time, dynamic theme should follow local hour
    if TimeMode == 'local' then
        -- Skip isNight update here, it will be handled by the game time loop to stay consistent with user request
        -- but we still keep the time update
    end
    cb('ok')
end)

local weatherHashToName = {
    ['CLEAR'] = 'clear', ['EXTRASUNNY'] = 'extrasunny', ['CLOUDS'] = 'clouds',
    ['OVERCAST'] = 'clouds', ['RAIN'] = 'rain', ['CLEARING'] = 'clearing',
    ['THUNDER'] = 'thunder', ['SMOG'] = 'smog', ['FOGGY'] = 'fog', ['FOG'] = 'fog',
    ['XMAS'] = 'xmas', ['SNOWLIGHT'] = 'snowlight', ['BLIZZARD'] = 'blizzard',
    ['SNOW'] = 'snow', ['NEUTRAL'] = 'neutral', ['HALLOWEEN'] = 'halloween',
    ['RAINING'] = 'rain', ['SNOWING'] = 'snow', ['CHRISTMAS'] = 'xmas',
}

local hashToWeather = {
    [916995460] = 'CLEAR', [-1750463879] = 'EXTRASUNNY', [821931868] = 'CLOUDS',
    [-1148613331] = 'OVERCAST', [1420204096] = 'RAIN', [1840358669] = 'CLEARING',
    [-1233681761] = 'THUNDER', [282916021] = 'SMOG', [-1368164796] = 'FOGGY',
    [-273223690] = 'SNOW', [603685163] = 'SNOWLIGHT', [669657108] = 'BLIZZARD',
    [-1429616491] = 'XMAS', [-921030142] = 'HALLOWEEN', [-1530260698] = 'NEUTRAL',
}

-- Game Time Thread (HH:MM format - updates every 100ms for instant response)
CreateThread(function()
    local format = string.format
    local lastSentTime = ''

    -- Wait for settings to sync from NUI
    Wait(2000)

    while true do
        if TimeMode == 'game' then
            local _hour = GetClockHours()
            local _mins = GetClockMinutes()
            local time = format('%02d:%02d', _hour, _mins)

            -- Send update if time changed
            if time ~= lastSentTime then
                lastSentTime = time
                lastTimeWeather.time = time
                NuiMessage('updateTime', { time = time })
            end
        end

        Wait(1000) -- 1000ms = 1 check per second, catches minute changes instantly
    end
end)

-- Local Time Thread
CreateThread(function()
    while true do
        Wait(Utils.W(2000))

        if not (IsPlayerLoaded() and GetHudSettings() and IsInfoBarVisible()) then
            Wait(3000)
            goto continue
        end

        if TimeMode == 'local' then
            local time = LocalTimeData.time
            if time ~= '' and time ~= lastTimeWeather.time then
                lastTimeWeather.time = time
                NuiMessage('updateTime', { time = time })
            end
        end

        ::continue::
    end
end)

-- Weather Thread (independent, faster updates)
CreateThread(function()
    local GetClockHours = GetClockHours
    local GetPrevWeatherTypeHashName = GetPrevWeatherTypeHashName

    Wait(2000)

    while true do
        Wait(1000)

        if not IsPlayerLoaded() then
            goto continue
        end

        local gameHour = GetClockHours()
        local isNight = gameHour >= 20 or gameHour < 6

        local weatherStr = GetPrevWeatherTypeHashName()
        if type(weatherStr) == 'number' then
            weatherStr = hashToWeather[weatherStr]
        end
        if type(weatherStr) ~= 'string' then weatherStr = 'CLEAR' end
        weatherStr = string.upper(weatherStr)
        local weather = weatherHashToName[weatherStr] or 'clear'

        if weather ~= lastTimeWeather.weather or isNight ~= lastTimeWeather.isNight then
            lastTimeWeather.weather, lastTimeWeather.isNight = weather, isNight
            NuiMessage('updateWeather', { weather = weather, isNight = isNight })
        end

        ::continue::
    end
end)
