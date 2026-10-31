-- Camera Accessibility - Custom cam (mouse input takeover)

-- Localize natives (resmon optimize - OrbitCam pattern)
local GetGameTimer, Wait = GetGameTimer, Wait
local PlayerId, PlayerPedId = PlayerId, PlayerPedId
local IsPedInAnyVehicle = IsPedInAnyVehicle
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetEntityCoords, GetEntityHeading = GetEntityCoords, GetEntityHeading
local GetGameplayCamCoord, GetGameplayCamRot, GetGameplayCamFov = GetGameplayCamCoord, GetGameplayCamRot, GetGameplayCamFov
local GetFollowPedCamViewMode, GetFollowVehicleCamViewMode = GetFollowPedCamViewMode, GetFollowVehicleCamViewMode
local IsPauseMenuActive, IsCutsceneActive, IsEntityDead = IsPauseMenuActive, IsCutsceneActive, IsEntityDead
local IsPlayerFreeAiming, IsAimCamActive, IsFirstPersonAimCamActive = IsPlayerFreeAiming, IsAimCamActive, IsFirstPersonAimCamActive
local NetworkIsInSpectatorMode = NetworkIsInSpectatorMode
local IsPedRagdoll, IsPedClimbing, IsPedVaulting, IsPedSwimming = IsPedRagdoll, IsPedClimbing, IsPedVaulting, IsPedSwimming
local DisableControlAction, GetDisabledControlNormal = DisableControlAction, GetDisabledControlNormal
local GetRenderingCam, DoesCamExist, DestroyCam = GetRenderingCam, DoesCamExist, DestroyCam
local CreateCamWithParams, SetCamActive, SetCamAffectsAiming = CreateCamWithParams, SetCamActive, SetCamAffectsAiming
local SetCamNearClip, SetCamCoord, SetCamRot, SetCamFov = SetCamNearClip, SetCamCoord, SetCamRot, SetCamFov
local RenderScriptCams = RenderScriptCams
local SetGameplayCamRelativeHeading, SetGameplayCamRelativePitch = SetGameplayCamRelativeHeading, SetGameplayCamRelativePitch
local m_cos, m_sin, m_rad = math.cos, math.sin, math.rad
local m_min, m_max, m_abs = math.min, math.max, math.abs

local CFG = {
    OFFSET_SCALE = 0.008, -- -100..100 -> ±0.8m
    FOV_SCALE    = 0.15,
    OFFSET_LERP  = 6.0,
    FIXED_FOV    = 50.0,
    FOV_MIN      = 10.0,
    FOV_MAX      = 120.0,
    MOUSE_SENS   = 6.0,   -- mouse hassasiyeti
    PITCH_MIN    = -75.0,
    PITCH_MAX    =  50.0,
    EYE_HEIGHT   = 0.65,  -- ped coord'dan cam focus'a dikey (goz seviyesi)
    -- Ayri distance tablolari: foot ve vehicle icin natural feel
    MODES_FOOT   = { [0] = 2.5, [1] = 4.5, [2] = 6.0 },
    MODES_VEH    = { [0] = 3.0, [1] = 5.5, [2] = 7.5 },
    DEFAULT_MODE = 1,
}

local SRV = (Config and Config.CameraAccessibility) or {}
local SRV_ENABLED = SRV.Enabled ~= false
local SRV_SLIDERS = SRV.Sliders or { Vertical = true, Horizontal = true, FOV = true }
local AIM_TRANSITION_MS = 400 -- aim'e gecerken ease suresi (ms)

local targetOff  = { h = 0.0, v = 0.0, f = 0.0 }
local currentOff = { h = 0.0, v = 0.0, f = 0.0 }
local active    = false
local cam       = nil
local bypassing = true
local lastBypassSmooth = false -- ease ile mi cikildi? donus de smooth olsun
local curDist   = CFG.MODES_FOOT[CFG.DEFAULT_MODE]

-- Kendi rotation state'imiz (mouse input'tan)
local camYaw   = 0.0
local camPitch = -10.0
local initialized = false

local function lerp(a, b, t)
    if t > 1 then t = 1 elseif t < 0 then t = 0 end
    return a + (b - a) * t
end

local function clamp(v, mn, mx)
    if v < mn then return mn elseif v > mx then return mx end
    return v
end

-- smooth = true ise aim gibi durumlar icin easy ease-out transition
local function stopRender(smooth)
    if cam and DoesCamExist(cam) then
        if smooth then
            RenderScriptCams(false, true, AIM_TRANSITION_MS, true, false)
            -- Cam'i hemen destroy etme, GTA transition'i yonetecek
            local oldCam = cam
            SetTimeout(AIM_TRANSITION_MS + 50, function()
                if oldCam and DoesCamExist(oldCam) then DestroyCam(oldCam, false) end
            end)
        else
            RenderScriptCams(false, false, 0, false, false)
            DestroyCam(cam, false)
        end
    end
    cam = nil
    initialized = false
    ClearFocus()
end

local function startRender(smooth)
    if cam and DoesCamExist(cam) then return end
    local gr = GetGameplayCamRot(2)
    camYaw = gr.z
    camPitch = clamp(gr.x, CFG.PITCH_MIN, CFG.PITCH_MAX)

    local gp = GetGameplayCamCoord()
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', gp.x, gp.y, gp.z, camPitch, 0, camYaw, CFG.FIXED_FOV, false, 2)
    SetCamActive(cam, true)
    SetCamAffectsAiming(cam, false)
    SetCamNearClip(cam, 0.05)
    if smooth then
        RenderScriptCams(true, true, AIM_TRANSITION_MS, true, false)
    else
        RenderScriptCams(true, false, 0, false, false)
    end
    initialized = true
end

RegisterNUICallback('SET_CAMERA_OFFSET', function(data, cb)
    if not SRV_ENABLED then cb({ ok = false, disabled = true }) return end
    local h = tonumber(data and data.horizontalOffset) or 0
    local v = tonumber(data and data.verticalOffset) or 0
    local f = tonumber(data and data.fovOffset) or 0
    h = (h > 100) and 100 or (h < -100) and -100 or h
    v = (v > 100) and 100 or (v < -100) and -100 or v
    f = (f > 100) and 100 or (f < -100) and -100 or f
    -- Disabled slider'lari sifirla
    if not SRV_SLIDERS.Horizontal then h = 0 end
    if not SRV_SLIDERS.Vertical   then v = 0 end
    if not SRV_SLIDERS.FOV        then f = 0 end
    targetOff.h = h * CFG.OFFSET_SCALE
    targetOff.v = v * CFG.OFFSET_SCALE
    targetOff.f = f * CFG.FOV_SCALE
    active = (targetOff.h ~= 0) or (targetOff.v ~= 0) or (targetOff.f ~= 0)
          or (currentOff.h ~= 0) or (currentOff.v ~= 0) or (currentOff.f ~= 0)
    cb({ ok = true })
end)

-- Sunucunun config durumunu frontend'e bildir
RegisterNUICallback('GET_CAMERA_ACCESSIBILITY_CONFIG', function(_, cb)
    cb({
        enabled = SRV_ENABLED,
        sliders = {
            vertical   = SRV_SLIDERS.Vertical ~= false,
            horizontal = SRV_SLIDERS.Horizontal ~= false,
            fov        = SRV_SLIDERS.FOV ~= false,
        },
    })
end)

-- Reset: aninda gameplay cam'e geri don
RegisterNUICallback('RESET_CAMERA_OFFSET', function(data, cb)
    targetOff.h, targetOff.v, targetOff.f = 0, 0, 0
    currentOff.h, currentOff.v, currentOff.f = 0, 0, 0
    active = false
    stopRender()
    bypassing = true
    cb({ ok = true })
end)

local IsNuiFocused = IsNuiFocused
local IsHudPreferenceSwitchedOn = IsHudPreferenceSwitchedOn

-- returns: shouldBypass, isAimTransition (smooth gecis ister)
-- Soft bypass icin: IsNuiFocused -> ayri handle ediyoruz (cam kalsin, sadece mouse okunmasin)
local function shouldBypass(ped, player)
    if IsPauseMenuActive() then return true, false end
    if IsEntityDead(ped) then return true, false end
    if IsCutsceneActive() then return true, false end
    if IsPlayerFreeAiming(player) then return true, true end
    if IsAimCamActive() then return true, true end
    if IsFirstPersonAimCamActive() then return true, true end
    if NetworkIsInSpectatorMode() then return true, false end
    if IsPedRagdoll(ped) then return true, false end
    if IsPedClimbing(ped) or IsPedVaulting(ped) then return true, false end
    if IsPedSwimming(ped) then return true, false end
    if IsPedInAnyVehicle(ped, false) then
        if GetFollowVehicleCamViewMode() == 4 then return true, true end
    else
        if GetFollowPedCamViewMode() == 4 then return true, true end
    end
    local r = GetRenderingCam()
    if r ~= -1 and r ~= cam then return true, false end
    return false, false
end

-- NUI focus: cam'i oldugu yerde tut, sadece mouse input'u okuma
local function isSoftFrozen()
    return IsNuiFocused()
end

CreateThread(function()
    if not SRV_ENABLED then return end -- feature disabled -> thread baslatma
    local lastTick = GetGameTimer()
    while true do
        if active then
            Wait(0)
            local now = GetGameTimer()
            local dt = (now - lastTick) / 1000.0
            lastTick = now
            if dt <= 0 then dt = 0.0001 end
            if dt > 0.1 then dt = 0.1 end

            local t = math.min(dt * CFG.OFFSET_LERP, 1.0)
            currentOff.h = lerp(currentOff.h, targetOff.h, t)
            currentOff.v = lerp(currentOff.v, targetOff.v, t)
            currentOff.f = lerp(currentOff.f, targetOff.f, t)

            local player = PlayerId()
            local ped = PlayerPedId()

            if targetOff.h == 0 and targetOff.v == 0 and targetOff.f == 0
                and math.abs(currentOff.h) < 0.001
                and math.abs(currentOff.v) < 0.001
                and math.abs(currentOff.f) < 0.01 then
                currentOff.h, currentOff.v, currentOff.f = 0, 0, 0
                active = false
                stopRender()
                bypassing = true
            else
                local bp, smoothExit = shouldBypass(ped, player)
                if bp then
                    if not bypassing then
                        stopRender(smoothExit)
                        lastBypassSmooth = smoothExit
                        bypassing = true
                    end
                else
                    if bypassing or not cam or not DoesCamExist(cam) then
                        startRender(lastBypassSmooth)
                        bypassing = false
                        lastBypassSmooth = false
                    end

                    -- View mode distance (foot / vehicle ayri tablolar)
                    local inVehicle = IsPedInAnyVehicle(ped, false)
                    local modeTable = inVehicle and CFG.MODES_VEH or CFG.MODES_FOOT
                    local vmode = inVehicle and GetFollowVehicleCamViewMode() or GetFollowPedCamViewMode()
                    local targetDist = modeTable[vmode] or modeTable[CFG.DEFAULT_MODE]
                    curDist = lerp(curDist, targetDist, math.min(dt * 5.0, 1.0))

                    -- Soft freeze (NUI focus: phone, settings, inventory): mouse input okuma,
                    -- cam pozisyonu son yaw/pitch'te dondur. Cam destroy edilmez.
                    local frozen = isSoftFrozen()

                    if not frozen then
                        -- MOUSE INPUT TAKEOVER: cam rotation'i dogrudan mouse'dan
                        DisableControlAction(0, 1, true)  -- LookLeftRight
                        DisableControlAction(0, 2, true)  -- LookUpDown
                        local mouseX = GetDisabledControlNormal(0, 1)
                        local mouseY = GetDisabledControlNormal(0, 2)

                        camYaw = camYaw - mouseX * CFG.MOUSE_SENS
                        camPitch = camPitch - mouseY * CFG.MOUSE_SENS
                        camPitch = clamp(camPitch, CFG.PITCH_MIN, CFG.PITCH_MAX)
                    end

                    -- Cam yaw'i 360 araligina normalize
                    while camYaw > 180.0 do camYaw = camYaw - 360.0 end
                    while camYaw < -180.0 do camYaw = camYaw + 360.0 end

                    -- Sync gameplay cam angles (aim, animation, network icin)
                    local refHeading
                    if IsPedInAnyVehicle(ped, false) then
                        refHeading = GetEntityHeading(GetVehiclePedIsIn(ped, false))
                    else
                        refHeading = GetEntityHeading(ped)
                    end
                    local relYaw = camYaw - refHeading
                    while relYaw > 180.0 do relYaw = relYaw - 360.0 end
                    while relYaw < -180.0 do relYaw = relYaw + 360.0 end
                    SetGameplayCamRelativeHeading(relYaw)
                    SetGameplayCamRelativePitch(camPitch, 1.0)

                    -- Cam pozisyonu: base entity (ped veya vehicle) + eye-height
                    local baseEntity = inVehicle and GetVehiclePedIsIn(ped, false) or ped
                    local bc = GetEntityCoords(baseEntity)
                    local eyeH = inVehicle and 0.3 or CFG.EYE_HEIGHT
                    local yawRad, pitchRad = math.rad(camYaw), math.rad(camPitch)
                    local cosY, sinY = math.cos(yawRad), math.sin(yawRad)
                    local cosP, sinP = math.cos(pitchRad), math.sin(pitchRad)

                    local fxw = -sinY * cosP
                    local fyw =  cosY * cosP
                    local fzw =  sinP
                    local rxw, ryw = cosY, sinY
                    local uxw, uyw, uzw = sinY * sinP, -cosY * sinP, cosP

                    local baseX = bc.x
                    local baseY = bc.y
                    local baseZ = bc.z + eyeH

                    local camX = baseX - fxw * curDist + rxw * currentOff.h + uxw * currentOff.v
                    local camY = baseY - fyw * curDist + ryw * currentOff.h + uyw * currentOff.v
                    local camZ = baseZ - fzw * curDist + uzw * currentOff.v

                    SetCamCoord(cam, camX, camY, camZ)
                    SetCamRot(cam, camPitch, 0, camYaw, 2)
                    SetFocusPosAndVel(camX, camY, camZ, 0.0, 0.0, 0.0)

                    local newFov = CFG.FIXED_FOV + currentOff.f
                    if newFov < CFG.FOV_MIN then newFov = CFG.FOV_MIN
                    elseif newFov > CFG.FOV_MAX then newFov = CFG.FOV_MAX end
                    SetCamFov(cam, newFov)
                end
            end
        else
            Wait(500)
            lastTick = GetGameTimer()
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        stopRender()
    end
end)
