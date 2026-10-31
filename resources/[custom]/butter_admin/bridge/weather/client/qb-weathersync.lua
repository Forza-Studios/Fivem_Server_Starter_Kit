if not UseBridge('weather', 'qb-weathersync') then return end

---@param weather string
function SetWeather(weather)
    TriggerServerEvent('qb-weathersync:server:setWeather', weather)
end

---@param hour number
---@param minute number
function SetTime(hour, minute)
    TriggerServerEvent('qb-weathersync:server:setTime', hour, minute)
end
