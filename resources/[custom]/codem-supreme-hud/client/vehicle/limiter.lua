--[[
    Vehicle Speed Limiter & Cruise Control
]]

-- ═══════════════════════════════════════════════════════════════
-- STATE (Global for access from speedometer)
-- ═══════════════════════════════════════════════════════════════

limiterState = { enabled = false, speed = 200 }
cruiseState = { enabled = false, speed = 180 }

local function kmhToMs(kmh) return kmh / 3.6 end
local function GetVehicleSpeedKmh(vehicle) return GetEntitySpeed(vehicle) * 3.6 end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

function SetLimiterSpeed(speed)
    limiterState.speed = math.max(10, math.min(300, speed))
    NuiMessage('updateLimiter', { speed = limiterState.speed, enabled = limiterState.enabled })
end

function ToggleLimiter()
    limiterState.enabled = not limiterState.enabled
    NuiMessage('updateLimiter', { speed = limiterState.speed, enabled = limiterState.enabled })
end

function SetCruiseSpeed(speed)
    cruiseState.speed = math.max(10, math.min(300, speed))
    NuiMessage('updateCruise', { speed = cruiseState.speed, enabled = cruiseState.enabled })
end

function ToggleCruise()
    cruiseState.enabled = not cruiseState.enabled
    NuiMessage('updateCruise', { speed = cruiseState.speed, enabled = cruiseState.enabled })
end

-- ═══════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('setLimiterSpeed', function(data, cb)
    SetLimiterSpeed(data.speed or 120)
    cb('ok')
end)

RegisterNUICallback('toggleLimiter', function(data, cb)
    if data.enabled ~= nil then
        if data.enabled ~= limiterState.enabled then ToggleLimiter() end
    else
        ToggleLimiter()
    end
    cb('ok')
end)

RegisterNUICallback('setCruiseSpeed', function(data, cb)
    SetCruiseSpeed(data.speed or 180)
    cb('ok')
end)

RegisterNUICallback('toggleCruise', function(data, cb)
    if data.enabled ~= nil then
        if data.enabled ~= cruiseState.enabled then ToggleCruise() end
    else
        ToggleCruise()
    end
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════
-- LIMITER/CRUISE THREAD
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    local GetEntitySpeed = GetEntitySpeed
    local SetEntityMaxSpeed = SetEntityMaxSpeed
    local SetVehicleCurrentRpm = SetVehicleCurrentRpm
    local GetPedInVehicleSeat = GetPedInVehicleSeat
    local DisableControlAction = DisableControlAction
    local SetControlNormal = SetControlNormal

    local lastMaxSpeedSet = 500.0

    while true do
        if not (IsPlayerLoaded() and IsHudVisible()) or not cache.inVehicle then
            -- Reset states when not in vehicle
            if cache.inVehicle == false then
                if limiterState.enabled then
                    limiterState.enabled = false
                    NuiMessage('updateLimiter', { speed = limiterState.speed, enabled = false })
                end
                if cruiseState.enabled then
                    cruiseState.enabled = false
                    NuiMessage('updateCruise', { speed = cruiseState.speed, enabled = false })
                end
                if lastMaxSpeedSet ~= 500.0 then
                    local v = Utils.GetCurrentVehicle()
                    if v and v ~= 0 then SetEntityMaxSpeed(v, 500.0) end
                    lastMaxSpeedSet = 500.0
                end
            end
            Wait(1000)
            goto continue
        end

        if not limiterState.enabled then
            if lastMaxSpeedSet ~= 500.0 then
                local v = Utils.GetCurrentVehicle()
                if v and v ~= 0 then SetEntityMaxSpeed(v, 500.0) end
                lastMaxSpeedSet = 500.0
            end
            Wait(500)
            goto continue
        end

        -- Limiter active: run every frame
        local vehicle = Utils.GetCurrentVehicle()
        local ped = cache.ped
        if not Utils.ValidateVehicle(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped then
            Wait(100)
            goto continue
        end

        local limiterSpeedMs = kmhToMs(limiterState.speed)
        if lastMaxSpeedSet ~= limiterSpeedMs then
            SetEntityMaxSpeed(vehicle, limiterSpeedMs)
            lastMaxSpeedSet = limiterSpeedMs
        end

        local currentSpeedKmh = GetVehicleSpeedKmh(vehicle)
        if currentSpeedKmh > limiterState.speed then
            DisableControlAction(0, 71, true) -- Disable throttle
            SetVehicleCurrentRpm(vehicle, 0.1)
            if currentSpeedKmh > limiterState.speed + 5 then
                SetControlNormal(0, 72, 0.3) -- Gentle brake
            end
        end

        Wait(0)
        ::continue::
    end
end)

CreateThread(function()
    local SetControlNormal = SetControlNormal
    local DisableControlAction = DisableControlAction
    local GetEntitySpeed = GetEntitySpeed

    local IsDisabledControlPressed = IsDisabledControlPressed

    while true do
        if cruiseState.enabled and cache.inVehicle then
            if IsDisabledControlPressed(0, 72) then
                cruiseState.enabled = false
                NuiMessage('updateCruise', { speed = cruiseState.speed, enabled = false })
            else
                local vehicle = cache.vehicle
                if vehicle and vehicle ~= 0 then
                    local cruiseSpeedMs = kmhToMs(cruiseState.speed)
                    local currentSpeedMs = GetEntitySpeed(vehicle)

                    if currentSpeedMs < cruiseSpeedMs - 0.5 then
                        DisableControlAction(0, 72, true)
                        SetControlNormal(0, 71, 0.8)
                    elseif currentSpeedMs > cruiseSpeedMs + 0.5 then
                        DisableControlAction(0, 71, true)
                        SetControlNormal(0, 72, 0.2)
                    else
                        DisableControlAction(0, 72, true)
                        SetControlNormal(0, 71, 0.3)
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('codem-hud:client:vehicleEntered', function()
    NuiMessage('updateLimiter', { speed = limiterState.speed, enabled = limiterState.enabled })
    NuiMessage('updateCruise', { speed = cruiseState.speed, enabled = cruiseState.enabled })
end)
