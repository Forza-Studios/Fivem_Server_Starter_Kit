local ENVIRONMENT_KEY = 'butter_admin:environment'
local ENVIRONMENT_TICK = 2000 -- ms, also the length of one game minute

local environmentLoopRunning = false

-- The server validated the request; the weather bridge applies it from here.
RegisterNetEvent('butter_admin:client:setEnvironment', function(weather, hour, minute)
    if weather and SetWeather then SetWeather(weather) end
    if hour and minute and SetTime then SetTime(hour, minute) end
end)

---@param environment table
local function applyEnvironment(environment)
    if environment.weather then
        local hash = joaat(environment.weather)
        if GetPrevWeatherTypeHashName() ~= hash or GetNextWeatherTypeHashName() ~= hash then
            ClearOverrideWeather()
            ClearWeatherTypePersist()
            SetWeatherTypeNowPersist(environment.weather)
            SetOverrideWeather(environment.weather)
        end
    end

    if environment.hour and environment.setAt then
        -- Advance from when it was set, so every client shows the same time.
        local elapsed = math.max(0, GetCloudTimeAsInt() - environment.setAt)
        local total = (environment.hour * 60 + (environment.minute or 0) + elapsed * 1000 // ENVIRONMENT_TICK) % 1440
        NetworkOverrideClockTime(total // 60, total % 60, 0)
    end
end

-- Built-in weather and time sync, only used when the server has no weather
-- script. Until an admin sets something the game's own weather is left alone.
local function startEnvironmentLoop()
    if environmentLoopRunning then return end
    environmentLoopRunning = true

    CreateThread(function()
        while type(GlobalState[ENVIRONMENT_KEY]) == 'table' do
            applyEnvironment(GlobalState[ENVIRONMENT_KEY])
            Wait(ENVIRONMENT_TICK)
        end
        environmentLoopRunning = false
    end)
end

AddStateBagChangeHandler(ENVIRONMENT_KEY, 'global', function(_, _, value)
    if type(value) ~= 'table' then return end
    applyEnvironment(value)
    startEnvironmentLoop()
end)

if type(GlobalState[ENVIRONMENT_KEY]) == 'table' then startEnvironmentLoop() end
