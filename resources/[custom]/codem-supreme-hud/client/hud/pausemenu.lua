--[[
    HUD Pause Menu Detection
    Hide HUD when pause menu is open
]]

local wasPaused = false

CreateThread(function()
    local IsPauseMenuActive = IsPauseMenuActive

    while true do
        Wait(Utils.W(750))

        if not (IsPlayerLoaded() and GetHudSettings()) then
            goto continue
        end

        local isPaused = IsPauseMenuActive()
        if isPaused ~= wasPaused then
            wasPaused = isPaused
            if isPaused then
                NuiMessage('setVisible', { visible = false })
                StopHudHideThread()
            else
                Wait(Utils.W(350))
                if not IsPauseMenuActive() and IsPlayerLoaded() and GetHudSettings() then
                    NuiMessage('setVisible', { visible = true })
                    UpdateMinimapVisibility()
                    StartHudHideThread()
                end
            end
        end

        ::continue::
    end
end)

local isHudHideThreadActive = false
local hideSatNav = false
local minimapScaleform = nil

-- Components to hide: 2=WEAPON_ICON, 6=VEHICLE_NAME, 7=AREA_NAME, 8=VEHICLE_CLASS, 9=STREET_NAME
local hiddenComponents = {2, 6, 7, 8, 9}

-- Hide HUD components permanently by moving them off-screen
-- This is more performant than HideHudComponentThisFrame which requires every-frame calls
local function HideHudComponentsPermanent()
    for i = 1, #hiddenComponents do
        SetHudComponentPosition(hiddenComponents[i], -5.0, -5.0)
    end
end

-- Restore HUD components to default position
local function RestoreHudComponents()
    for i = 1, #hiddenComponents do
        ResetHudComponentValues(hiddenComponents[i])
    end
end

function StartHudHideThread()

    if isHudHideThreadActive then return end
    isHudHideThreadActive = true

    -- Hide components once (permanent)
    HideHudComponentsPermanent()

    CreateThread(function()
        local BeginScaleformMovieMethod = BeginScaleformMovieMethod
        local EndScaleformMovieMethod = EndScaleformMovieMethod
        local DisableControlAction = DisableControlAction
        local satnavCounter = 0

        while isHudHideThreadActive do
            local needsFrame = false

            -- DisableControlAction must run every frame
            if cache.vehicle then
                DisableControlAction(0, 85, true)
                needsFrame = true
            end

            -- SatNav hide only needs to run every ~10 frames
            if hideSatNav and minimapScaleform then
                satnavCounter = satnavCounter + 1
                if satnavCounter >= 10 then
                    satnavCounter = 0
                    BeginScaleformMovieMethod(minimapScaleform, "HIDE_SATNAV")
                    EndScaleformMovieMethod()
                end
                needsFrame = true
            end

            Wait(needsFrame and 0 or 2000)
        end
    end)
end

function StopHudHideThread()
    isHudHideThreadActive = false
    RestoreHudComponents()
end

-- Called from minimap.lua when custom minimap is enabled
function EnableSatNavHide()
    if not minimapScaleform then
        minimapScaleform = RequestScaleformMovie("minimap")
        -- Wait for load in background
        CreateThread(function()
            while not HasScaleformMovieLoaded(minimapScaleform) do
                Wait(100)
            end
        end)
    end
    hideSatNav = true
end

function DisableSatNavHide()
    hideSatNav = false
end

AddEventHandler('codem-hud:client:HudVisibilityChanged', function(visible)
    if visible then StartHudHideThread() else StopHudHideThread() end
end)

-- Initial hide on resource start (after player loads)
AddEventHandler('codem-hud:client:PlayerLoaded', function()
    Wait(500)
    StartHudHideThread()
end)

SetUserRadioControlEnabled(false)

AddEventHandler('codem-hud:client:baseevents:enteredVehicle', function(vehicle, seat, displayName, netId)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleRadioEnabled(vehicle, false)
        SetVehRadioStation(vehicle, 'OFF')
    end
end)

AddEventHandler('codem-hud:client:baseevents:vehicleSwapped', function(vehicle)
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleRadioEnabled(vehicle, false)
        SetVehRadioStation(vehicle, 'OFF')
    end
end)

CreateThread(function()
    while true do
        SetUserRadioControlEnabled(false)
        local vehicle = cache.vehicle
        if vehicle and DoesEntityExist(vehicle) then
            DisableControlAction(0, 85, true)
            SetVehicleRadioEnabled(vehicle, false)
            Wait(0)
        else
            Wait(500)
        end
    end
end)
