-- Free-cam spectate: the admin's ped is parked hidden and frozen under the
-- target while a scripted camera orbits the target.

local CAMERA_FOV = 50.0
local CAMERA_MIN_DISTANCE = 1.5
local CAMERA_MAX_DISTANCE = 15.0
-- Share of the remaining angle the rendered camera closes per frame; lower is smoother.
local CAMERA_SMOOTHING = 0.25
-- State checks (every 500 ms) to tolerate the target not being streamed in.
-- A real disconnect is reported by the server instead.
local STREAM_GRACE_CHECKS = 20
local STATE_CHECK_INTERVAL = 500
local PARK_INTERVAL = 2000
local CYCLE_COOLDOWN = 1000

local spectate = {
    active = false,
    switching = false,
    targetServerId = -1,
    targetPlayer = -1,
    targetPed = nil,
    returnCoords = nil,
    camera = nil,
    yaw = 0.0,
    pitch = -15.0,
    smoothYaw = 0.0,
    smoothPitch = -15.0,
    distance = 4.0,
    gamerTag = nil,
    lostChecks = 0,
}

local requestBusy = false

--- GTA camera rotation (pitch up positive, yaw counter-clockwise) to a direction vector.
---@param pitch number
---@param yaw number
---@return vector3
local function rotationToDirection(pitch, yaw)
    local pitchRad, yawRad = math.rad(pitch), math.rad(yaw)
    local cosPitch = math.abs(math.cos(pitchRad))
    return vector3(-math.sin(yawRad) * cosPitch, math.cos(yawRad) * cosPitch, math.sin(pitchRad))
end

--- Shortest signed difference between two angles, so smoothing never spins the long way.
---@param from number
---@param to number
---@return number
local function angleDelta(from, to)
    return (to - from + 180.0) % 360.0 - 180.0
end

local function clearGamerTag()
    if spectate.gamerTag then
        RemoveMpGamerTag(spectate.gamerTag)
        spectate.gamerTag = nil
    end
end

local function updateGamerTag()
    local ped = spectate.targetPed
    if not ped or not DoesEntityExist(ped) then return end

    if not spectate.gamerTag or not IsMpGamerTagActive(spectate.gamerTag) then
        clearGamerTag()
        local label = ('[%d] %s'):format(spectate.targetServerId, GetPlayerName(spectate.targetPlayer) or 'Unknown')
        spectate.gamerTag = CreateFakeMpGamerTag(ped, label, false, false, '', 0)
    end

    SetMpGamerTagVisibility(spectate.gamerTag, 2, true)
    SetMpGamerTagAlpha(spectate.gamerTag, 2, 255)
    SetMpGamerTagHealthBarColor(spectate.gamerTag, 129)
    SetMpGamerTagVisibility(spectate.gamerTag, 4, NetworkIsPlayerTalking(spectate.targetPlayer))
end

---@param coords vector3
local function waitForCollision(coords)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    for _ = 1, 20 do
        if HasCollisionLoadedAroundEntity(cache.ped) then return end
        Wait(100)
    end
end

---@param duration number
local function fadeOut(duration)
    if IsScreenFadedOut() then return end
    DoScreenFadeOut(duration)
    while not IsScreenFadedOut() do Wait(0) end
end

---@param duration number
local function fadeIn(duration)
    if not IsScreenFadedIn() then DoScreenFadeIn(duration) end
end

local function destroyCamera()
    RenderScriptCams(false, true, 300, true, true)
    if spectate.camera and DoesCamExist(spectate.camera) then DestroyCam(spectate.camera, true) end
    spectate.camera = nil
end

---@param targetPed number
local function createCamera(targetPed)
    -- Start behind the target, looking over their shoulder.
    spectate.yaw = GetEntityHeading(targetPed)
    spectate.pitch = -15.0
    spectate.smoothYaw, spectate.smoothPitch = spectate.yaw, spectate.pitch
    spectate.distance = 4.0

    local focus = GetEntityCoords(targetPed) + vector3(0.0, 0.0, 0.6)
    local position = focus - rotationToDirection(spectate.pitch, spectate.yaw) * spectate.distance

    spectate.camera = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', position.x, position.y, position.z, 0.0, 0.0, 0.0, CAMERA_FOV, true, 0)
    SetCamActive(spectate.camera, true)
    RenderScriptCams(true, true, 300, true, true)
end

---@param targetPed number
local function updateCamera(targetPed)
    if not spectate.camera or not DoesCamExist(spectate.camera) or not DoesEntityExist(targetPed) then return end

    -- Read as disabled controls so the parked ped never moves.
    DisableControlAction(0, 1, true)
    DisableControlAction(0, 2, true)
    spectate.yaw = (spectate.yaw - GetDisabledControlNormal(0, 1) * 5.0) % 360.0
    spectate.pitch = math.max(-70.0, math.min(70.0, spectate.pitch - GetDisabledControlNormal(0, 2) * 5.0))

    DisableControlAction(0, 241, true)
    DisableControlAction(0, 242, true)
    if IsDisabledControlJustPressed(0, 241) then
        spectate.distance = math.max(CAMERA_MIN_DISTANCE, spectate.distance - 0.5)
    elseif IsDisabledControlJustPressed(0, 242) then
        spectate.distance = math.min(CAMERA_MAX_DISTANCE, spectate.distance + 0.5)
    end

    spectate.smoothYaw = (spectate.smoothYaw + angleDelta(spectate.smoothYaw, spectate.yaw) * CAMERA_SMOOTHING) % 360.0
    spectate.smoothPitch += (spectate.pitch - spectate.smoothPitch) * CAMERA_SMOOTHING

    local focus = GetEntityCoords(targetPed) + vector3(0.0, 0.0, 0.6)
    local position = focus - rotationToDirection(spectate.smoothPitch, spectate.smoothYaw) * spectate.distance
    SetCamCoord(spectate.camera, position.x, position.y, position.z)
    PointCamAtCoord(spectate.camera, focus.x, focus.y, focus.z)
end

--- Keeps the hidden ped near the target so they stay streamed in. Not an
--- attachment: attaching to a ped that changes vehicle or ragdolls can pop
--- the admin's ped back into view.
---@param coords vector3
local function parkPedNear(coords)
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z - 50.0, false, false, false, false)
end

local function hideAdminPed()
    local ped = cache.ped
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetPlayerInvincible(cache.playerId, true)
end

local function restoreAdminPed()
    local ped = cache.ped
    SetEntityVisible(ped, not AdminState.invisible, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetPlayerInvincible(cache.playerId, AdminState.godmode or AdminState.devMode)
end

--- Returns the admin to where they started. Teleports while still frozen and
--- waits for the ground, so the ped does not fall before landing.
local function returnToStart()
    local coords = spectate.returnCoords
    if coords then
        SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, false)
        waitForCollision(coords)
    end
    restoreAdminPed()
end

---@param targetServerId number
---@return number? ped, number player
local function waitForTargetPed(targetServerId)
    local player, ped = -1, 0
    for _ = 1, 50 do
        Wait(100)
        player = GetPlayerFromServerId(targetServerId)
        ped = GetPlayerPed(player)
        if ped ~= 0 and DoesEntityExist(ped) then return ped, player end
    end
    return nil, player
end

local function stopSpectate()
    if not spectate.active then return end
    spectate.active = false

    local name = ('%s (%s)'):format(GetPlayerName(spectate.targetPlayer) or 'Unknown', spectate.targetServerId)

    fadeOut(400)
    clearGamerTag()
    destroyCamera()
    returnToStart()

    spectate.targetServerId, spectate.targetPlayer, spectate.targetPed, spectate.returnCoords = -1, -1, nil, nil
    TriggerServerEvent('butter_admin:server:stopSpectate')
    Notify(locale('spectate.toggled', locale('commands.stopped'), name))

    Wait(300)
    fadeIn(400)
end

local function setupInstructionalButtons(scaleform)
    PushScaleformMovieFunction(scaleform, 'CLEAR_ALL')
    PopScaleformMovieFunctionVoid()
    PushScaleformMovieFunction(scaleform, 'SET_CLEAR_SPACE')
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()

    local buttons = {
        { control = 177, label = locale('spectate.hud.exit') },
        { control = 175, label = locale('spectate.hud.next') },
        { control = 174, label = locale('spectate.hud.prev') },
    }
    for slot, button in ipairs(buttons) do
        PushScaleformMovieFunction(scaleform, 'SET_DATA_SLOT')
        PushScaleformMovieFunctionParameterInt(slot - 1)
        PushScaleformMovieMethodParameterButtonName(GetControlInstructionalButton(0, button.control, true))
        PushScaleformMovieMethodParameterString(button.label)
        PopScaleformMovieFunctionVoid()
    end

    PushScaleformMovieFunction(scaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
    PopScaleformMovieFunctionVoid()
end

--- Re-validates the target every few hundred ms; returns false to stop.
---@param now number
---@param lastPark number
---@return boolean keepGoing, number lastPark
local function checkTarget(now, lastPark)
    -- Visibility is not persistent; resync can show the parked ped again.
    local ped = cache.ped
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)

    -- The local player index changes as the target moves in and out of scope,
    -- so it is resolved again from the server ID every time.
    local player = GetPlayerFromServerId(spectate.targetServerId)
    local targetPed = player ~= -1 and GetPlayerPed(player) or 0

    if targetPed == 0 or not DoesEntityExist(targetPed) then
        spectate.lostChecks += 1
        return spectate.lostChecks < STREAM_GRACE_CHECKS, lastPark
    end

    spectate.lostChecks = 0
    spectate.targetPlayer = player
    spectate.targetPed = targetPed
    if now - lastPark > PARK_INTERVAL then
        lastPark = now
        parkPedNear(GetEntityCoords(targetPed))
    end
    updateGamerTag()
    return true, lastPark
end

local function runSpectateLoop()
    CreateThread(function()
        -- Bounded wait: a scaleform that never loads must not leave the admin stuck.
        local scaleform = RequestScaleformMovie('instructional_buttons')
        local deadline = GetGameTimer() + 3000
        while not HasScaleformMovieLoaded(scaleform) and GetGameTimer() < deadline do Wait(0) end
        local hasButtons = HasScaleformMovieLoaded(scaleform)
        if hasButtons then setupInstructionalButtons(scaleform) end

        local nextCycleAt, lastCheck, lastPark = 0, 0, 0

        while spectate.active do
            if hasButtons then DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0) end

            -- The parked ped is unattended, so attacks from it are blocked.
            for _, control in ipairs({ 24, 25, 140, 141, 142 }) do DisableControlAction(0, control, true) end

            if not spectate.switching and spectate.targetPed then updateCamera(spectate.targetPed) end

            if IsControlJustPressed(0, 177) then
                stopSpectate()
                break
            end

            local now = GetGameTimer()
            if now > nextCycleAt and (IsControlJustPressed(0, 175) or IsControlJustPressed(0, 174)) then
                nextCycleAt = now + CYCLE_COOLDOWN
                TriggerServerEvent('butter_admin:server:cycleSpectate', IsControlJustPressed(0, 174) and -1 or 1)
            end

            if not spectate.switching and now - lastCheck > STATE_CHECK_INTERVAL then
                lastCheck = now
                local keepGoing
                keepGoing, lastPark = checkTarget(now, lastPark)
                if not keepGoing then
                    Notify(locale('spectate.stopped_not_found'), 'error')
                    stopSpectate()
                    break
                end
            end

            Wait(0)
        end

        SetScaleformMovieAsNoLongerNeeded(scaleform)
    end)
end

---@param targetServerId number
---@param targetCoords vector3
local function switchTarget(targetServerId, targetCoords)
    spectate.switching = true
    fadeOut(400)
    clearGamerTag()
    destroyCamera()
    spectate.targetPed = nil

    parkPedNear(targetCoords)
    waitForCollision(targetCoords)

    local targetPed, targetPlayer = waitForTargetPed(targetServerId)
    if not targetPed then
        spectate.switching = false
        stopSpectate()
        return Notify(locale('spectate.not_found'), 'error')
    end

    hideAdminPed()
    spectate.targetPed, spectate.targetPlayer, spectate.targetServerId = targetPed, targetPlayer, targetServerId
    spectate.lostChecks = 0
    createCamera(targetPed)
    Notify(locale('spectate.toggled', locale('commands.started'), ('%s (%s)'):format(GetPlayerName(targetPlayer) or 'Unknown', targetServerId)))

    Wait(300)
    fadeIn(400)
    spectate.switching = false
end

---@param targetServerId number
---@param targetCoords vector3
local function startSpectate(targetServerId, targetCoords)
    if targetServerId == cache.serverId then return Notify(locale('spectate.self'), 'error') end

    spectate.returnCoords = GetEntityCoords(cache.ped)
    fadeOut(400)

    -- Hidden and frozen before moving, so nobody sees the ped pop or fall.
    hideAdminPed()
    parkPedNear(targetCoords)
    waitForCollision(targetCoords)

    local targetPed, targetPlayer = waitForTargetPed(targetServerId)
    if not targetPed then
        returnToStart()
        spectate.returnCoords = nil
        fadeIn(400)
        return Notify(locale('spectate.not_found'), 'error')
    end

    spectate.active = true
    spectate.targetPed, spectate.targetPlayer, spectate.targetServerId = targetPed, targetPlayer, targetServerId
    spectate.lostChecks = 0
    createCamera(targetPed)
    Notify(locale('spectate.toggled', locale('commands.started'), ('%s (%s)'):format(GetPlayerName(targetPlayer) or 'Unknown', targetServerId)))
    runSpectateLoop()

    Wait(300)
    fadeIn(400)
end

RegisterNetEvent('butter_admin:client:spectate', function(targetServerId, targetCoords, isSwitch)
    -- Starting or switching yields while the target streams in; ignore requests meanwhile.
    if requestBusy then return end
    requestBusy = true

    targetServerId = tonumber(targetServerId)
    local coords = vector3(targetCoords.x, targetCoords.y, targetCoords.z)
    local ok, err = pcall(function()
        if spectate.active then
            if isSwitch then return switchTarget(targetServerId, coords) end
            return stopSpectate()
        end
        startSpectate(targetServerId, coords)
    end)

    requestBusy = false
    if not ok then LogError('Spectate request failed:', err) end
end)

RegisterNetEvent('butter_admin:client:spectateTargetDropped', function(targetServerId)
    if not spectate.active or spectate.targetServerId ~= targetServerId then return end
    Notify(locale('spectate.stopped_not_found'), 'error')
    stopSpectate()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not spectate.active then return end

    clearGamerTag()
    destroyCamera()
    restoreAdminPed()
    if spectate.returnCoords then
        local coords = spectate.returnCoords
        SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, false)
    end
    spectate.active = false
end)

exports('isSpectating', function()
    return spectate.active
end)
