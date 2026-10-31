if not UseBridge('weather', 'cad-climate') then return end

---@param weather string
function SetWeather(weather)
    exports['cad-climate']:forceWeather(weather, false)
end

---@param hour number
---@param minute number
function SetTime(hour, minute)
    exports['cad-climate']:forceTime(hour, minute, false)
end
