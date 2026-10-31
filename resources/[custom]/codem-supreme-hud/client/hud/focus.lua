-- Focus on Role Play - Activity Detection
-- Sends activity events to NUI to reset the auto-hide timer

local lastHealth = -1
local lastArmor = -1
local lastWeapon = 0
local lastVehicle = 0
local lastSpeed = 0
local lastHunger = -1
local lastThirst = -1
local lastPedCoords = nil

-- Focus setting state (synced from NUI)
local focusOnRolePlayEnabled = false

-- Adaptive interval for activity checking
local activityInterval = Utils.CreateAdaptiveInterval({
    min = 500,
    max = 2000,
    step = 250,
    threshold = 3
})

-- Speed threshold for activity (km/h) - only trigger if speed changes significantly
local SPEED_CHANGE_THRESHOLD = 10

-- Send activity event to NUI
local function SendActivity()
    if not (IsPlayerLoaded() and IsHudVisible()) then return end
    if not focusOnRolePlayEnabled then return end
    NuiMessage('hud:activity')
end

-- NUI callback to update focus setting state
RegisterNUICallback('setFocusOnRolePlay', function(data, cb)
    focusOnRolePlayEnabled = data.enabled or false
    cb({ success = true })
end)

-- Activity detection thread
CreateThread(function()
    local floor = math.floor
    local abs = math.abs
    local GetEntityHealth = GetEntityHealth
    local GetPedArmour = GetPedArmour
    local GetSelectedPedWeapon = GetSelectedPedWeapon
    local GetEntitySpeed = GetEntitySpeed
    local IsPedShooting = IsPedShooting
    local IsPedReloading = IsPedReloading
    local IsPedInMeleeCombat = IsPedInMeleeCombat

    while true do
        -- Skip if focus setting is disabled or HUD not visible
        if focusOnRolePlayEnabled and IsPlayerLoaded() then
            local ped = cache.ped
            local currentHealth = GetEntityHealth(ped)
            local currentArmor = GetPedArmour(ped)
            local currentWeapon = GetSelectedPedWeapon(ped)
            local currentVehicle = cache.vehicle

            local hasActivity = false

            -- Check health change
            if lastHealth ~= -1 and currentHealth ~= lastHealth then
                hasActivity = true
            end
            lastHealth = currentHealth

            -- Check armor change
            if lastArmor ~= -1 and currentArmor ~= lastArmor then
                hasActivity = true
            end
            lastArmor = currentArmor

            -- Check weapon change
            if currentWeapon ~= lastWeapon then
                hasActivity = true
            end
            lastWeapon = currentWeapon

            -- Check vehicle state change (enter/exit vehicle)
            if currentVehicle ~= lastVehicle then
                hasActivity = true
            end
            lastVehicle = currentVehicle

            -- Check speed change (speedometer activity) or on-foot movement
            if currentVehicle and currentVehicle ~= 0 then
                local currentSpeed = GetEntitySpeed(currentVehicle) * 3.6
                if abs(currentSpeed - lastSpeed) > SPEED_CHANGE_THRESHOLD then
                    hasActivity = true
                end
                lastSpeed = currentSpeed
            else
                lastSpeed = 0
                -- On-foot movement detection
                local coords = GetEntityCoords(ped)
                if lastPedCoords then
                    local dist = #(coords - lastPedCoords)
                    if dist > 6.5 then
                        hasActivity = true
                    end
                end
                lastPedCoords = coords
            end

            -- Check if player is shooting
            if IsPedShooting(ped) then
                hasActivity = true
            end

            -- Check if player is reloading
            if IsPedReloading(ped) then
                hasActivity = true
            end

            -- Check if player is in melee combat
            if IsPedInMeleeCombat(ped) then
                hasActivity = true
            end

            -- Check hunger/thirst changes (needs system)
            local needs = GetPlayerNeeds and GetPlayerNeeds() or nil
            if needs then
                local currentHunger = floor(needs.hunger or 0)
                local currentThirst = floor(needs.thirst or 0)
                if lastHunger ~= -1 and currentHunger ~= lastHunger then
                    hasActivity = true
                end
                if lastThirst ~= -1 and currentThirst ~= lastThirst then
                    hasActivity = true
                end
                lastHunger = currentHunger
                lastThirst = currentThirst
            end

            -- Send activity if detected
            if hasActivity then
                SendActivity()
                activityInterval.onChanged()
            else
                activityInterval.onStable()
            end
        elseif not focusOnRolePlayEnabled then
            -- Reset tracking when setting is disabled
            lastHealth = -1
            lastArmor = -1
            lastWeapon = 0
            lastVehicle = 0
            lastSpeed = 0
            lastHunger = -1
            lastThirst = -1
            lastPedCoords = nil
            activityInterval.reset()
        end

        Wait(activityInterval.current)
    end
end)

-- Also trigger activity on specific events
AddEventHandler('codem-hud:client:HudVisibilityChanged', function(visible)
    if visible then
        SetTimeout(100, SendActivity)
    end
end)

-- Big map toggle = activity
AddEventHandler('codem-hud:client:BigMapToggled', function()
    SendActivity()
end)

-- Weapon equip/change = activity (instant, no polling delay)
CreateThread(function()
    local lastWep = 0
    while true do
        Wait(200)
        if focusOnRolePlayEnabled and IsPlayerLoaded() then
            local wep = GetSelectedPedWeapon(cache.ped)
            if wep ~= lastWep then
                lastWep = wep
                SendActivity()
            end
        end
    end
end)
