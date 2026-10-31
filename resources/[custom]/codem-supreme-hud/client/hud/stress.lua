--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║                 STRESS SYSTEM (Optimized)                     ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  Event-driven stress mechanics for better performance         ║
    ║  - Uses state changes instead of constant polling             ║
    ║  - Dirty flag system: only syncs when stress changes          ║
    ║  - Adaptive intervals based on refresh rate settings          ║
    ║  - Seatbelt check: no speed stress when seatbelt is on        ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

if not Config.Stress or not Config.Stress.Enabled then
    return
end

-- ═══════════════════════════════════════════════════════════════
-- STATE & CONFIG
-- ═══════════════════════════════════════════════════════════════

local currentStress = 0
local lastSentStress = -1
local isDirty = false
local lastLocalChange = 0

-- Throttle cooldowns from Config
local Timings = Config.Timings.Stress
local SHOOT_COOLDOWN = Timings.ShootCooldown
local DAMAGE_COOLDOWN = Timings.DamageCooldown
local CRASH_COOLDOWN = Timings.CrashCooldown
local SPEED_COOLDOWN = Timings.SpeedCooldown

-- Throttle timestamps
local lastShootTime = 0
local lastDamageTime = 0
local lastCrashTime = 0
local lastSpeedTime = 0

-- State tracking for change detection
local lastHealth = cache.maxHp
local lastSpeed = 0
local wasRagdoll = false
local wasFalling = false
local effectsActive = false
local isBlackedOut = false

-- ═══════════════════════════════════════════════════════════════
-- ADAPTIVE INTERVALS
-- ═══════════════════════════════════════════════════════════════

-- Adaptive intervals from Config
local Intervals = Config.Timings.Intervals
local weaponInterval = Utils.CreateAdaptiveInterval(Intervals.Weapon)
local damageInterval = Utils.CreateAdaptiveInterval(Intervals.Damage)
local vehicleInterval = Utils.CreateAdaptiveInterval(Intervals.Vehicle)
local mainInterval = Utils.CreateAdaptiveInterval(Intervals.Main)
local hudInterval = Utils.CreateAdaptiveInterval(Intervals.Hud)
local syncInterval = Utils.CreateAdaptiveInterval(Intervals.Sync)

-- ═══════════════════════════════════════════════════════════════
-- UTILITY
-- ═══════════════════════════════════════════════════════════════

-- Use Utils.clampRange for stress clamping (0-100 range)
local function clamp(value, min, max)
    return Utils.clampRange(value, min or 0, max or 100)
end

-- Notification throttle
local lastNotifyTime = 0
local NOTIFY_COOLDOWN = Timings.NotifyCooldown

local function notifyStressChange(delta, reason)
    if not Config.Stress.Notifications then return end

    local now = GetGameTimer()

    -- Throttle all stress notifications regardless of type
    if (now - lastNotifyTime) < NOTIFY_COOLDOWN then
        return
    end

    lastNotifyTime = now

    local stressPercent = math.floor(currentStress)
    if delta > 0 then
        if Notify then
            Notify(L('stress.increased', stressPercent, math.floor(delta)), 'error')
        end
    else
        if Notify then
            Notify(L('stress.decreased', stressPercent, math.floor(math.abs(delta))), 'success')
        end
    end
end

local function addStress(amount, reason)
    if amount <= 0 then return false end
    if IsEntityDead(cache.ped) then return false end
    local newStress = clamp(currentStress + amount, 0, Config.Stress.MaxStress)
    if newStress ~= currentStress then
        currentStress = newStress
        isDirty = true
        lastLocalChange = GetGameTimer()
        debugPrint('[Stress] +' .. amount .. ' (' .. (reason or 'unknown') .. ') -> ' .. math.floor(currentStress) .. '%')
        notifyStressChange(amount, reason)
        return true
    end
    return false
end

local function removeStress(amount, reason)
    if amount <= 0 then return false end
    local newStress = clamp(currentStress - amount, 0, Config.Stress.MaxStress)
    if newStress ~= currentStress then
        currentStress = newStress
        isDirty = true
        lastLocalChange = GetGameTimer()
        debugPrint('[Stress] -' .. amount .. ' (' .. (reason or 'unknown') .. ') -> ' .. math.floor(currentStress) .. '%')
        notifyStressChange(-amount, reason)
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- SEATBELT CHECK
-- ═══════════════════════════════════════════════════════════════

local function isSeatbeltOn()
    -- Try to get seatbelt state from vehicle features
    local ok, result = pcall(function()
        local scriptName = GetCurrentResourceName()
        return exports[scriptName]:IsSeatbeltOn()
    end)
    if ok then return result end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- FRAMEWORK INTEGRATION
-- ═══════════════════════════════════════════════════════════════

function UpdateStress(stress)
    if stress == nil then return end
    local now = GetGameTimer()
    if isDirty or (now - lastLocalChange) < 5000 then
        debugPrint('[Stress] Ignoring framework sync (' .. stress .. ') - local changes pending')
        return
    end
    currentStress = clamp(stress, 0, Config.Stress.MaxStress)
    lastSentStress = math.floor(currentStress)
    isDirty = false
end

local function sendStressToHud()
    if not IsPlayerLoaded() then return end
    local stress = math.floor(currentStress)
    if stress ~= lastSentStress then
        lastSentStress = stress
        -- Use SendNUIMessage directly to ensure message is sent
        SendNUIMessage({
            action = 'updateStress',
            data = { stress = stress }
        })
        debugPrint('[Stress] Sent to HUD: ' .. stress .. '%')
    end
end

-- Sync stress to server (framework)
local function syncToServer(force)
    if not (IsPlayerLoaded() and SetPlayerStress) then return end
    if not isDirty and not force then return end

    SetPlayerStress(math.floor(currentStress))
    isDirty = false
end

-- ═══════════════════════════════════════════════════════════════
-- STRESS EFFECTS (only when stress is high)
-- ═══════════════════════════════════════════════════════════════

local function applyStressEffects()
    -- Skip if stress is low
    if currentStress < 75 then
        if effectsActive then
            effectsActive = false
            ClearTimecycleModifier()
            StopGameplayCamShaking(true)
        end
        return
    end

    local effects = Config.Stress.Effects

    -- Screen Shake (75+)
    if effects.ScreenShake.Enabled and currentStress >= effects.ScreenShake.Threshold then
        local intensity = effects.ScreenShake.Intensity * ((currentStress - 75) / 25)
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', intensity)
    end

    -- Screen Blur (90+)
    if effects.ScreenBlur.Enabled then
        if currentStress >= effects.ScreenBlur.Threshold then
            if not effectsActive then
                effectsActive = true
                SetTimecycleModifier('spectator5')
                SetTimecycleModifierStrength(0.3)
            end
        elseif effectsActive then
            effectsActive = false
            ClearTimecycleModifier()
        end
    end

    -- Blackout (100)
    if effects.Blackout.Enabled and currentStress >= effects.Blackout.Threshold and not isBlackedOut then
        isBlackedOut = true
        DoScreenFadeOut(500)
        CreateThread(function()
            Wait(effects.Blackout.Duration)
            DoScreenFadeIn(1000)
            isBlackedOut = false
            removeStress(20)
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- JOB WHITELIST CHECK
-- ═══════════════════════════════════════════════════════════════

local cachedJobWhitelisted = false
local lastJobCheck = 0

local function isJobWhitelisted()
    local now = GetGameTimer()
    -- Use cached value if checked recently (10 seconds)
    if now - lastJobCheck < 10000 then
        return cachedJobWhitelisted
    end
    lastJobCheck = now

    -- Get player job from framework
    if not GetPlayerJob then
        cachedJobWhitelisted = false
        return false
    end

    local jobData = GetPlayerJob()
    if not jobData or not jobData.name then
        cachedJobWhitelisted = false
        return false
    end

    local jobName = string.lower(jobData.name)
    local whitelist = Config.Stress.WhitelistedJobs or {}

    for _, whitelistedJob in ipairs(whitelist) do
        if jobName == string.lower(whitelistedJob) then
            cachedJobWhitelisted = true
            return true
        end
    end

    cachedJobWhitelisted = false
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- SHOOTING DETECTION (using control input for reliability)
-- ═══════════════════════════════════════════════════════════════

local shootingMonitorActive = false
local isArmed = false

local function startShootingMonitor()
    if shootingMonitorActive then return end
    shootingMonitorActive = true
    isArmed = true

    CreateThread(function()
        while shootingMonitorActive and IsPlayerLoaded() and isArmed do
            local ped = cache.ped
            -- Only use IsPedShooting - this only returns true when actually firing bullets
            local isShooting = IsPedShooting(ped)

            if isShooting then
                local now = GetGameTimer()
                if now - lastShootTime > SHOOT_COOLDOWN then
                    lastShootTime = now
                    -- Check if shooting stress is enabled and job is NOT whitelisted
                    local shootingStress = Config.Stress.Increase.Shooting
                    if shootingStress and not isJobWhitelisted() then
                        debugPrint('[Stress] Shooting detected, adding ' .. shootingStress)
                        if addStress(shootingStress, 'shooting') then
                            sendStressToHud()
                        end
                    end
                end
            end
            Wait(50)
        end
        shootingMonitorActive = false
    end)
end

local function stopShootingMonitor()
    isArmed = false
    shootingMonitorActive = false
end

-- Weapon watch thread (adaptive)
CreateThread(function()
    local lastWeapon = 0
    while true do
        Wait(weaponInterval.current)
        if not IsPlayerLoaded() then
            weaponInterval.setMax()
            goto continue
        end

        local weapon = GetSelectedPedWeapon(cache.ped)
        if weapon ~= lastWeapon then
            lastWeapon = weapon
            weaponInterval.onChanged()
            if weapon ~= `WEAPON_UNARMED` then
                startShootingMonitor()
            else
                stopShootingMonitor()
            end
        else
            weaponInterval.onStable()
        end
        ::continue::
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- DAMAGE DETECTION (health change based, adaptive)
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(damageInterval.current)
        if not IsPlayerLoaded() then
            damageInterval.setMax()
            goto continue
        end

        local health = GetEntityHealth(cache.ped)
        local increase = Config.Stress.Increase

        -- Only trigger on health decrease
        if health < lastHealth then
            local now = GetGameTimer()
            if now - lastDamageTime > DAMAGE_COOLDOWN then
                lastDamageTime = now
                damageInterval.onChanged()
                local damage = lastHealth - health
                -- Heavy damage (bullet)
                if damage > 10 and increase.GettingShot then
                    if addStress(increase.GettingShot, 'getting_shot') then
                        sendStressToHud()
                    end
                -- Light damage (melee/fall)
                elseif damage > 3 and increase.GettingHit then
                    if addStress(increase.GettingHit, 'getting_hit') then
                        sendStressToHud()
                    end
                end
            end
        else
            damageInterval.onStable()
        end
        lastHealth = health

        ::continue::
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- VEHICLE STRESS (adaptive, with seatbelt check)
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(vehicleInterval.current)
        if not IsPlayerLoaded() then
            vehicleInterval.setMax()
            goto continue
        end

        local ped = cache.ped
        -- Use native check instead of cache for reliability
        if not IsPedInAnyVehicle(ped, false) then
            lastSpeed = 0
            vehicleInterval.setMax()
            goto continue
        end

        local vehicle = Utils.GetCurrentVehicle()
        if not Utils.ValidateVehicle(vehicle) then goto continue end

        -- Skip speed stress for aircraft and boats
        local vClass = GetVehicleClass(vehicle)
        if vClass == 14 or vClass == 15 or vClass == 16 then -- boat, heli, plane
            goto continue
        end

        local speed = GetEntitySpeed(vehicle) * 3.6 -- km/h
        local increase = Config.Stress.Increase
        local stressAdded = false
        local now = GetGameTimer()

        -- Speeding stress (only if enabled and seatbelt is OFF)
        if increase.Speeding then
            local threshold = increase.SpeedThreshold or 80
            if speed > threshold and (now - lastSpeedTime) > SPEED_COOLDOWN then
                vehicleInterval.onChanged()
                local seatbelt = isSeatbeltOn()
                if not seatbelt then
                    lastSpeedTime = now
                    local speedOver = speed - threshold
                    local stressAmount = increase.Speeding * (1 + speedOver / 150)
                    debugPrint('[Stress] Speeding: ' .. math.floor(speed) .. ' km/h, adding ' .. string.format('%.2f', stressAmount))
                    if addStress(stressAmount, 'speeding') then
                        stressAdded = true
                    end
                end
            elseif speed <= threshold then
                vehicleInterval.onStable()
            end
        end

        -- Crash detection (only if enabled)
        if increase.VehicleCrash and lastSpeed > 60 and speed < lastSpeed * 0.4 then
            if now - lastCrashTime > CRASH_COOLDOWN then
                lastCrashTime = now
                vehicleInterval.onChanged()
                local severity = math.min((lastSpeed - speed) / 50, 2)
                local crashStress = increase.VehicleCrash * severity
                if isSeatbeltOn() then
                    crashStress = crashStress * 0.3
                end
                debugPrint('[Stress] Crash detected! Adding ' .. string.format('%.1f', crashStress))
                if addStress(crashStress, 'crash') then
                    stressAdded = true
                end
            end
        end

        -- Update HUD if stress changed
        if stressAdded then
            sendStressToHud()
        end

        lastSpeed = speed
        ::continue::
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- MAIN LOOP (state changes & passive recovery, adaptive)
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    -- Wait for player
    while not IsPlayerLoaded() do Wait(1000) end
    Wait(2000)

    -- Load initial stress from SERVER (not client cache) via RPC
    local serverStress = RPC.execute('codem-hud:getPlayerStress')
    if serverStress and serverStress > 0 then
        currentStress = serverStress
        lastSentStress = currentStress
        sendStressToHud()
    elseif GetPlayerStress then
        -- Fallback to client-side if RPC fails
        currentStress = GetPlayerStress()
        lastSentStress = currentStress
    end

    while true do
        Wait(mainInterval.current)
        if not IsPlayerLoaded() then
            mainInterval.setMax()
            goto continue
        end

        local ped = cache.ped
        local increase = Config.Stress.Increase
        local decrease = Config.Stress.Decrease
        local stressChanged = false

        -- ═══════════════════════════════════════════════════════
        -- STATE-BASED STRESS (check if enabled in config)
        -- ═══════════════════════════════════════════════════════

        -- Ragdoll (only when entering ragdoll)
        local isRagdoll = IsPedRagdoll(ped)
        if increase.Ragdoll and isRagdoll and not wasRagdoll then
            mainInterval.onChanged()
            if addStress(increase.Ragdoll, 'ragdoll') then stressChanged = true end
        end
        wasRagdoll = isRagdoll

        -- Falling (only when starting to fall)
        local isFalling = IsPedFalling(ped)
        if increase.Falling and isFalling and not wasFalling then
            mainInterval.onChanged()
            if addStress(increase.Falling, 'falling') then stressChanged = true end
        end
        wasFalling = isFalling

        -- Low health (only when critically low)
        if increase.LowHealth then
            local healthPercent = ((GetEntityHealth(ped) - 100) / 100) * 100
            if healthPercent > 0 and healthPercent < 25 then
                mainInterval.onChanged()
                if addStress(increase.LowHealth * 5, 'low_health') then stressChanged = true end
            end
        end

        -- Drowning
        if increase.Drowning and IsPedSwimmingUnderWater(ped) then
            local oxygen = GetPlayerUnderwaterTimeRemaining(cache.pid)
            if oxygen < 5 then
                mainInterval.onChanged()
                if addStress(increase.Drowning * 5, 'drowning') then stressChanged = true end
            end
        end

        -- ═══════════════════════════════════════════════════════
        -- PASSIVE RECOVERY (multiple ways to relax)
        -- ═══════════════════════════════════════════════════════

        if currentStress > 0 then
            local inVehicle = IsPedInAnyVehicle(ped, false)
            local intervalMultiplier = mainInterval.current / 1000
            local threshold = increase.SpeedThreshold or 80

            -- Swimming reduces stress (exercise)
            if decrease.Swimming and IsPedSwimming(ped) and not IsPedSwimmingUnderWater(ped) then
                if removeStress(decrease.Swimming * intervalMultiplier, 'swimming') then stressChanged = true end

            -- In vehicle - recovery options (check if enabled in config)
            elseif inVehicle then
                local vehicle = Utils.GetCurrentVehicle()
                local recoveryAmount = 0
                local isDriver = GetPedInVehicleSeat(vehicle, -1) == ped

                -- Calm driving (20 to threshold-20 km/h)
                if decrease.Sitting and isDriver and lastSpeed >= 20 and lastSpeed <= (threshold - 20) then
                    recoveryAmount = recoveryAmount + decrease.Sitting
                end

                -- Passenger (not driving, can relax)
                if decrease.Passenger and not isDriver then
                    recoveryAmount = recoveryAmount + decrease.Passenger
                end

                if recoveryAmount > 0 then
                    if removeStress(recoveryAmount * intervalMultiplier, 'vehicle_relax') then stressChanged = true end
                end

            -- On foot activities (check if enabled in config)
            else
                local isWalking = IsPedWalking(ped)
                local isRunning = IsPedRunning(ped) or IsPedSprinting(ped)

                -- Running/jogging (cardio reduces stress)
                if decrease.Running and isRunning then
                    if removeStress(decrease.Running * intervalMultiplier, 'running') then stressChanged = true end
                -- Walking (light movement)
                elseif decrease.Walking and isWalking then
                    if removeStress(decrease.Walking * intervalMultiplier, 'walking') then stressChanged = true end
                end
            end
        end

        if stressChanged then
            sendStressToHud()
        else
            mainInterval.onStable()
        end

        ::continue::
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- HUD UPDATE LOOP (adaptive)
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    while not IsPlayerLoaded() do Wait(1000) end

    while true do
        Wait(hudInterval.current)
        if IsPlayerLoaded() then
            local oldStress = lastSentStress
            sendStressToHud()
            applyStressEffects()
            if lastSentStress ~= oldStress then
                hudInterval.onChanged()
            else
                hudInterval.onStable()
            end
        else
            hudInterval.setMax()
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- SERVER SYNC LOOP (adaptive, only if dirty)
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(syncInterval.current)
        if isDirty then
            syncInterval.onChanged()
            syncToServer(false)
        else
            syncInterval.onStable()
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ITEM USAGE (Server-side handles inventory events)
-- Server: server/hud/stress.lua listens to all inventory systems
-- ═══════════════════════════════════════════════════════════════

-- Custom event for manual stress relief (from server or other scripts)
RegisterNetEvent('codem-hud:client:StressRelief', function(itemName, amount)
    local relief = amount or (Config.Stress.Decrease.Items and Config.Stress.Decrease.Items[itemName])
    if relief and removeStress(relief, 'item:' .. (itemName or 'unknown')) then
        sendStressToHud()
        applyStressEffects() -- Clear effects immediately when stress is reduced
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- CLIENT API (Exports & Events)
-- ═══════════════════════════════════════════════════════════════
--[[
    STRESS API - For developers who want custom triggers

    EXPORTS:
        exports['codem-supreme-hud']:GetStress()
        exports['codem-supreme-hud']:AddStress(amount)
        exports['codem-supreme-hud']:RemoveStress(amount)
        exports['codem-supreme-hud']:SetStress(amount)
        exports['codem-supreme-hud']:IsStressEnabled()

    EVENTS:
        TriggerEvent('codem-hud:client:AddStress', amount)
        TriggerEvent('codem-hud:client:RemoveStress', amount)

    CALLBACK:
        AddEventHandler('codem-hud:client:StressChanged', function(new, old, delta) end)
]]

exports('GetStress', function()
    return math.floor(currentStress)
end)

exports('AddStress', function(amount)
    local oldStress = currentStress
    if addStress(amount) then
        sendStressToHud()
        syncToServer(true)
        TriggerEvent('codem-hud:client:StressChanged', currentStress, oldStress, amount)
        return true
    end
    return false
end)

exports('RemoveStress', function(amount)
    local oldStress = currentStress
    if removeStress(amount) then
        sendStressToHud()
        applyStressEffects()
        syncToServer(true)
        TriggerEvent('codem-hud:client:StressChanged', currentStress, oldStress, -amount)
        return true
    end
    return false
end)

exports('SetStress', function(amount)
    local oldStress = currentStress
    currentStress = clamp(amount, 0, Config.Stress.MaxStress)
    isDirty = true
    sendStressToHud()
    applyStressEffects()
    syncToServer(true)
    if currentStress ~= oldStress then
        TriggerEvent('codem-hud:client:StressChanged', currentStress, oldStress, currentStress - oldStress)
    end
end)

exports('IsStressEnabled', function()
    return Config.Stress and Config.Stress.Enabled or false
end)

exports('GetStressConfig', function()
    return Config.Stress
end)

-- Events (call exports to avoid duplicate logic)
RegisterNetEvent('codem-hud:client:AddStress', function(amount)
    if addStress(amount, 'event') then
        sendStressToHud()
        syncToServer(true)
    end
end)

RegisterNetEvent('codem-hud:client:RemoveStress', function(amount)
    if removeStress(amount, 'event') then
        sendStressToHud()
        applyStressEffects()
        syncToServer(true)
    end
end)

RegisterNetEvent('codem-hud:client:SetStress', function(amount)
    currentStress = clamp(amount, 0, Config.Stress.MaxStress)
    isDirty = true
    sendStressToHud()
    applyStressEffects()
    syncToServer(true)
end)

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP & SAVE
-- ═══════════════════════════════════════════════════════════════

-- Force save stress to server (bypasses dirty check)
local function saveStressToServer()
    if not SetPlayerStress then
        return false
    end

    local stressValue = math.floor(currentStress)
    SetPlayerStress(stressValue)
    isDirty = false
    return true
end

-- Force sync on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Save stress regardless of dirty flag
    if currentStress > 0 then
        saveStressToServer()
    end

    -- Cleanup effects
    if effectsActive then
        ClearTimecycleModifier()
        StopGameplayCamShaking(true)
    end
end)

-- Force sync on player unload
AddEventHandler('codem-hud:client:PlayerUnloaded', function()
    saveStressToServer()
end)

-- ═══════════════════════════════════════════════════════════════
-- REVIVE / RESPAWN → Reset Stress
-- ═══════════════════════════════════════════════════════════════

local function resetStressOnRevive()
    currentStress = 0
    isDirty = true
    sendStressToHud()
    applyStressEffects()
    syncToServer(true)
    debugPrint('[Stress] Reset to 0 on revive/respawn')
end

-- QBCore / QBox
RegisterNetEvent('hospital:client:Revive', function()
    resetStressOnRevive()
end)

-- ESX
RegisterNetEvent('esx:onPlayerSpawn', function()
    resetStressOnRevive()
end)

if Config.Debug then
    RegisterCommand('stressdown', function(source, args)
        local amount = tonumber(args[1]) or 10
        if removeStress(amount) then
            sendStressToHud()
            applyStressEffects()
        end
    end, false)
    RegisterCommand('stressup', function(source, args)
        local amount = tonumber(args[1]) or 10
        local success = addStress(amount)
        if success then
            sendStressToHud()
        end
    end, false)
end
