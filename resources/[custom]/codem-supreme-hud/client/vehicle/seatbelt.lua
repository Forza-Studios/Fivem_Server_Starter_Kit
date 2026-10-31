--[[
    SEATBELT SYSTEM
    Manual crash detection with windscreen ejection mechanics
    Config: shared/config.lua -> Config.VehicleFeatures.Seatbelt
]]

local Cfg = Config.VehicleFeatures.Seatbelt
if not Cfg or not Cfg.Enabled then return end

-- STATE
local seatbeltState = {
    isWearing = false,
    lastVehicle = nil,
    lastBeep = 0,
    otherPlayerStates = {},
}

local EjectionPresets = {
    low = { 12.0, 15.0, 3.0, 300.0 },
    medium = { 20.0, 25.0, 8.0, 800.0 },
    realistic = { 17.0, 20.0, 6.0, 600.0 },
    high = { 35.0, 40.0, 17.0, 2000.0 },
}

local crashDetection = {
    lastSpeed = 0,
    lastVelocity = vector3(0, 0, 0),
    recentlyEjected = false,
}

local function IsMotorcycle(vehicle)
    if not vehicle or vehicle == 0 then return false end
    local class = GetVehicleClass(vehicle)
    return class == 8 or class == 13
end

--- Get ejection parameters based on difficulty setting
---@return table|nil Ejection params {minSpeed, maxSpeed, upForce, forwardForce} or nil if disabled
local function GetEjectionParams()
    if not Cfg.Ejection.Enabled then return nil end
    return EjectionPresets[Cfg.Ejection.Difficulty] or EjectionPresets.medium
end

--- Eject player through windscreen on crash (ragdoll physics)
local function EjectThroughWindscreen()
    local ped = cache.ped
    local vehicle = cache.vehicle
    if not ped or ped == 0 or not vehicle or vehicle == 0 then return end
    if crashDetection.recentlyEjected then return end

    crashDetection.recentlyEjected = true
    seatbeltState.lastBeep = 0
    NuiMessage('stopSeatbeltBeep', {})

    local vehCoords = GetEntityCoords(vehicle)
    local vehForward = GetEntityForwardVector(vehicle)
    local lastVelocity = crashDetection.lastVelocity
    local lastSpeed = crashDetection.lastSpeed

    CreateThread(function()
        local ejectionDistance = 3.0 + (lastSpeed * 0.1)
        local targetPos = vector3(
            vehCoords.x + vehForward.x * ejectionDistance,
            vehCoords.y + vehForward.y * ejectionDistance,
            vehCoords.z + 0.5
        )

        TaskLeaveVehicle(ped, vehicle, 4160)
        Wait(100)

        SetEntityCoords(ped, targetPos.x, targetPos.y, targetPos.z, true, true, true, false)
        SetEntityVelocity(ped, lastVelocity.x * 1.2, lastVelocity.y * 1.2, lastVelocity.z + 2.0)
        SetPedToRagdoll(ped, 5000, 5000, 0, false, false, false)

        local damage = math.min(80, math.max(20, math.floor(lastSpeed * 3.6 * 0.5)))
        ApplyDamageToPed(ped, damage, false)
        PlaySoundFrontend(-1, 'CRASH', 'DLC_STUNT_RACE_FRONTEND_SOUNDS', false)

        Wait(3000)
        crashDetection.recentlyEjected = false
    end)
end

--- Check for crash and trigger ejection if conditions met
local function CheckCrashEjection()
    local vehicle = cache.vehicle
    local ped = cache.ped
    if not vehicle or vehicle == 0 or not ped or ped == 0 then return end
    if not Cfg.Ejection.Enabled then return end

    if seatbeltState.isWearing then
        crashDetection.lastSpeed = GetEntitySpeed(vehicle)
        crashDetection.lastVelocity = GetEntityVelocity(vehicle)
        return
    end
    if crashDetection.recentlyEjected then return end

    local currentSpeed = GetEntitySpeed(vehicle)
    local currentVelocity = GetEntityVelocity(vehicle)

    local params = GetEjectionParams()
    if not params then
        crashDetection.lastSpeed = currentSpeed
        crashDetection.lastVelocity = currentVelocity
        return
    end

    local minSpeed = params[1]
    local speedDrop = crashDetection.lastSpeed - currentSpeed
    local dropPercentage = crashDetection.lastSpeed > 0 and (speedDrop / crashDetection.lastSpeed) or 0

    if crashDetection.lastSpeed > minSpeed and dropPercentage > 0.30 then
        local vehHealth = GetVehicleBodyHealth(vehicle)
        if vehHealth < 1000 or IsEntityInWater(vehicle) or HasEntityCollidedWithAnything(vehicle) then
            EjectThroughWindscreen()
        end
    end

    crashDetection.lastSpeed = currentSpeed
    crashDetection.lastVelocity = currentVelocity
end

--- Configure native windscreen ejection parameters
---@param enabled boolean Enable/disable native ejection (we use custom)
local function SetWindscreenEjection(enabled)
    local ped = cache.ped
    if not ped or ped == 0 then return end
    SetPedConfigFlag(ped, 32, false)
    SetFlyThroughWindscreenParams(9999.0, 9999.0, 9999.0, 9999.0)
end

--- Toggle seatbelt on/off for current player
local function ToggleSeatbelt()
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then return end
    if IsMotorcycle(vehicle) then return end

    seatbeltState.isWearing = not seatbeltState.isWearing

    if seatbeltState.isWearing then
        Notify(L('seatbelt.on'), 'success')
        seatbeltState.lastBeep = 0
        NuiMessage('stopSeatbeltBeep', {})
        SetWindscreenEjection(false)
    else
        Notify(L('seatbelt.off'), 'error')
        SetWindscreenEjection(true)
    end

    NuiMessage('playSeatbeltToggle', { on = seatbeltState.isWearing })
    NuiMessage('updateSpeedometer', { seatbelt = seatbeltState.isWearing })
    RPC.execute('vehicleFeatures:syncSeatbelt', seatbeltState.isWearing)
end

local seatbeltThreadActive = false

local function StartSeatbeltThread()
    if seatbeltThreadActive then return end
    seatbeltThreadActive = true

    seatbeltState.lastBeep = 0
    crashDetection.lastSpeed = 0
    crashDetection.lastVelocity = vector3(0, 0, 0)
    crashDetection.recentlyEjected = false

    if IsMotorcycle(cache.vehicle) then
        seatbeltThreadActive = false
        return
    end

    SetWindscreenEjection(false)

    -- Separate thread for crash detection (needs faster updates)
    CreateThread(function()
        local GetEntitySpeed = GetEntitySpeed
        local GetEntityVelocity = GetEntityVelocity

        while seatbeltThreadActive do
            local vehicle = cache.vehicle
            if not vehicle or vehicle == 0 then
                break
            end

            local currentSpeed = GetEntitySpeed(vehicle) * 3.6
            if currentSpeed > 30 and not seatbeltState.isWearing then
                CheckCrashEjection()
                Wait(100)
            else
                crashDetection.lastSpeed = GetEntitySpeed(vehicle)
                crashDetection.lastVelocity = GetEntityVelocity(vehicle)
                Wait(500)
            end
        end
    end)

    -- Main seatbelt thread (beep and control disable)
    -- Cache config values to avoid repeated table lookups
    local beepEnabled = Cfg.Beep.Enabled
    local beepSpeed = Cfg.Beep.Speed
    local beepInterval = Cfg.Beep.Interval
    local beepVolume = Cfg.Beep.Volume or 0.2

    CreateThread(function()
        local DisableControlAction = DisableControlAction
        local GetEntitySpeed = GetEntitySpeed
        local GetGameTimer = GetGameTimer

        while seatbeltThreadActive do
            local vehicle = cache.vehicle
            if not vehicle or vehicle == 0 then
                seatbeltThreadActive = false
                break
            end

            if seatbeltState.isWearing then
                DisableControlAction(0, 75, true)
                Wait(0) -- Must be every frame for control disable
            else
                local currentSpeed = GetEntitySpeed(vehicle) * 3.6

                if beepEnabled and currentSpeed > beepSpeed then
                    local now = GetGameTimer()
                    if now - seatbeltState.lastBeep >= beepInterval then
                        seatbeltState.lastBeep = now
                        NuiMessage('playSeatbeltBeep', { volume = beepVolume })
                    end
                    Wait(100)
                elseif seatbeltState.lastBeep > 0 then
                    seatbeltState.lastBeep = 0
                    NuiMessage('stopSeatbeltBeep', {})
                    Wait(200)
                else
                    Wait(200)
                end
            end
        end
    end)
end

local function StopSeatbeltThread()
    seatbeltThreadActive = false
    seatbeltState.isWearing = false
    seatbeltState.lastBeep = 0
    NuiMessage('stopSeatbeltBeep', {})
    crashDetection.lastSpeed = 0
    crashDetection.lastVelocity = vector3(0, 0, 0)
    crashDetection.recentlyEjected = false
    ResetFlyThroughWindscreenParams()
    SetPedConfigFlag(cache.ped, 32, false)
end

AddEventHandler('codem-hud:client:vehicleStateChanged', function(inVehicle)
    if inVehicle then
        StartSeatbeltThread()
    else
        StopSeatbeltThread()
    end
end)

AddEventHandler('codem-hud:client:vehicleSwapped', function()
    seatbeltState.isWearing = false
    NuiMessage('updateSpeedometer', { seatbelt = false })
    SetPedConfigFlag(cache.ped, 32, false)
end)

RegisterKeyMapping('+toggleSeatbelt', 'Toggle Seatbelt', 'keyboard', Cfg.Key)
RegisterCommand('+toggleSeatbelt', function()
    if Utils.GetCurrentVehicle() ~= 0 then ToggleSeatbelt() end
end, false)
RegisterCommand('-toggleSeatbelt', function() end, false)

RegisterNetEvent('vehicleFeatures:receiveSeatbeltSync', function(playerId, isWearing)
    seatbeltState.otherPlayerStates[playerId] = isWearing
end)

exports('IsSeatbeltOn', function()
    return seatbeltState.isWearing
end)

exports('GetSeatbeltState', function()
    return seatbeltState.isWearing
end)
