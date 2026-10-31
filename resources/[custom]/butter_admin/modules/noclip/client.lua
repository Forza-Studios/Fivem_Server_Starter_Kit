local CAMERA_FOV = 50.0
local EASING_DURATION = 100
local LOOK_SENSITIVITY = 5
local BASE_SPEED = 0.85
local FAST_MULTIPLIER = 6
local SLOW_MULTIPLIER = 6
local SPEED_STEP = 0.25
local MIN_SPEED = 0.1
local MAX_SPEED = 10.0

-- SetFocusArea makes the streamer re-prioritise, which costs a small hitch,
-- so focus moves at most every FOCUS_MIN_INTERVAL ms and FOCUS_MIN_DISTANCE units.
local FOCUS_MIN_DISTANCE_SQR = 60.0 * 60.0
local FOCUS_MIN_INTERVAL = 200

-- The entity found this far from where the freecam put it was moved by
-- something else (e.g. a /tp), and the freecam follows instead of snapping back.
local EXTERNAL_TELEPORT_SQR = 8.0 * 8.0

local camera
local posX, posY, posZ = 0.0, 0.0, 0.0
local rotX, rotY, rotZ = 0.0, 0.0, 0.0
local forwardX, forwardY, forwardZ = 0.0, 0.0, 0.0
local rightX, rightY, rightZ = 0.0, 0.0, 0.0
local hiddenVehicle = 0
local streamingIn = false
local focusX, focusY, focusZ
local lastFocusAt = 0
local speed = BASE_SPEED

---@return boolean
local function isFreecamActive()
    if not camera then return false end
    local active = IsCamActive(camera)
    return active == true or active == 1
end

---@param control integer|integer[]
---@return number
local function getControlNormal(control)
    if type(control) == 'table' then
        return GetDisabledControlNormal(0, control[1]) - GetDisabledControlNormal(0, control[2])
    end
    return GetDisabledControlNormal(0, control)
end

local function setCameraPosition(x, y, z)
    local needsFocus = focusX == nil
    if not needsFocus then
        local dx, dy, dz = x - focusX, y - focusY, z - focusZ
        needsFocus = dx * dx + dy * dy + dz * dz > FOCUS_MIN_DISTANCE_SQR and GetGameTimer() - lastFocusAt >= FOCUS_MIN_INTERVAL
    end

    if needsFocus then
        focusX, focusY, focusZ = x, y, z
        lastFocusAt = GetGameTimer()
        local position = vector3(x, y, z)
        local interior = GetInteriorAtCoords(position)
        if interior ~= 0 then LoadInterior(interior) end
        SetFocusArea(position.x, position.y, position.z, 0.0, 0.0, 0.0)
    end

    LockMinimapPosition(x, y)
    SetCamCoord(camera, x, y, z)
    posX, posY, posZ = x, y, z
end

local function setCameraRotation(x, y, z)
    x = math.max(-90.0, math.min(90.0, x))
    y, z = y % 360, z % 360

    local radX, radY, radZ = math.rad(x), math.rad(y), math.rad(z)
    local sinX, cosX = math.sin(radX), math.cos(radX)
    local sinY, cosY = math.sin(radY), math.cos(radY)
    local sinZ, cosZ = math.sin(radZ), math.cos(radZ)

    -- First two rows of the rotation matrix: the camera's right and forward vectors.
    rightX, rightY, rightZ = cosY * cosZ, cosY * sinZ, -sinY
    forwardX, forwardY, forwardZ = cosZ * sinX * sinY - cosX * sinZ, cosX * cosZ - sinX * sinY * sinZ, cosY * sinX

    LockMinimapAngle(math.floor(z))
    SetCamRot(camera, x, y, z, 2)
    rotX, rotY, rotZ = x, y, z
end

---@param active boolean
local function setFreecamActive(active)
    if active == isFreecamActive() then return end

    if active then
        local position = GetGameplayCamCoord()
        local rotation = GetGameplayCamRot(2)
        focusX, focusY, focusZ = nil, nil, nil
        lastFocusAt = 0
        streamingIn = false
        camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamFov(camera, CAMERA_FOV)
        setCameraPosition(position.x, position.y, position.z)
        setCameraRotation(rotation.x, 0.0, rotation.z)
    else
        DestroyCam(camera, false)
        camera = nil
        ClearFocus()
        UnlockMinimapPosition()
        UnlockMinimapAngle()
    end

    RenderScriptCams(active, true, EASING_DURATION, true, true)
end

---@return number
local function getSpeedMultiplier()
    if IsDisabledControlJustPressed(0, 15) then
        speed = math.min(MAX_SPEED, speed + SPEED_STEP)
    elseif IsDisabledControlJustPressed(0, 14) then
        speed = math.max(MIN_SPEED, speed - SPEED_STEP)
    end

    local fast = 1.0 + (FAST_MULTIPLIER - 1) * getControlNormal(21)
    local slow = 1.0 + (SLOW_MULTIPLIER - 1) * getControlNormal(19)
    return speed * fast / slow * GetFrameTime() * 60
end

---@return number?, number?, number?, number? x, y, z, heading
local function updateCamera()
    if not isFreecamActive() or IsPauseMenuActive() then return end

    local multiplier = getSpeedMultiplier()
    local lookX, lookY = getControlNormal(1), getControlNormal(2)
    local moveX, moveY = getControlNormal(30), getControlNormal(31)
    local moveZ = getControlNormal({ 152, 153 })

    local x = posX + (rightX * moveX - forwardX * moveY) * multiplier
    local y = posY + (rightY * moveX - forwardY * moveY) * multiplier
    local z = posZ + (rightZ * moveX - forwardZ * moveY + moveZ) * multiplier
    local heading = rotZ - lookX * LOOK_SENSITIVITY

    setCameraPosition(x, y, z)
    setCameraRotation(rotX - lookY * LOOK_SENSITIVITY, rotY, heading)
    return x, y, z, rotZ
end

--- Where the player lands when noclip ends: the ground right below them, or
--- in the air with FallInAir. Probing starts at the player's height so a
--- bridge or roof overhead is ignored.
---@return number, number, number
local function resolveExitCoords(x, y, z)
    if Config.Noclip.FallInAir then return x, y, z end

    for _, offset in ipairs({ 1.0, 0.0, 5.0, 25.0, 100.0, 1000.0 }) do
        local found, groundZ = GetGroundZFor_3dCoord(x, y, z + offset, false)
        if found and groundZ <= z + 1.0 then return x, y, groundZ end
    end
    return x, y, z
end

---@return number entity the freecam moves
local function getSyncEntity()
    if hiddenVehicle > 0 and DoesEntityExist(hiddenVehicle) then return hiddenVehicle end
    return cache.ped
end

--- Streams the world in after a large jump without freezing the freecam.
local function streamInAround(x, y, z)
    if streamingIn then return end
    streamingIn = true

    CreateThread(function()
        local startedAt = GetGameTimer()
        NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)
        while IsNetworkLoadingScene() and GetGameTimer() - startedAt < 1000 do Wait(0) end
        NewLoadSceneStop()

        local entity = getSyncEntity()
        startedAt = GetGameTimer()
        RequestCollisionAtCoord(x, y, z)
        while not HasCollisionLoadedAroundEntity(entity) and GetGameTimer() - startedAt < 1000 do
            RequestCollisionAtCoord(x, y, z)
            Wait(0)
        end
        streamingIn = false
    end)
end

---@param vehicle number
local function hideVehicle(vehicle)
    NetworkRequestControlOfEntity(vehicle)
    SetEntityVisible(vehicle, false, false)
    NetworkSetEntityInvisibleToNetwork(vehicle, true)
    SetEntityCollision(vehicle, false, false)
    FreezeEntityPosition(vehicle, true)
end

---@param vehicle number
local function showVehicle(vehicle)
    SetEntityVisible(vehicle, true, false)
    NetworkSetEntityInvisibleToNetwork(vehicle, false)
    SetEntityCollision(vehicle, true, true)
    FreezeEntityPosition(vehicle, false)
end

--- Follows the player in and out of vehicles while flying.
local function trackVehicle()
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle == hiddenVehicle then return end

    if hiddenVehicle > 0 and DoesEntityExist(hiddenVehicle) then showVehicle(hiddenVehicle) end
    hiddenVehicle = vehicle
    if vehicle > 0 then hideVehicle(vehicle) end
end

local function runCameraLoop()
    CreateThread(function()
        local lastX, lastY, lastZ, lastHeading
        local syncedX, syncedY, syncedZ = 0.0, 0.0, 0.0
        local hasSynced = false
        local travelSqr = 0.0
        local divergedFrames = 0
        local frame = 0

        while isFreecamActive() do
            -- Detect an external teleport. The tolerance scales with how far the
            -- freecam just moved, and the divergence must hold for two frames,
            -- so fast flight and collision pushback don't trigger it.
            local entityCoords = GetEntityCoords(getSyncEntity())
            local dx, dy, dz = entityCoords.x - posX, entityCoords.y - posY, entityCoords.z - posZ
            local allowedSqr = math.max(EXTERNAL_TELEPORT_SQR, travelSqr * 4.0)

            if dx * dx + dy * dy + dz * dz > allowedSqr and not streamingIn then
                divergedFrames += 1
            else
                divergedFrames = 0
            end

            if divergedFrames >= 2 then
                divergedFrames = 0
                setCameraPosition(entityCoords.x, entityCoords.y, entityCoords.z)
                syncedX, syncedY, syncedZ = entityCoords.x, entityCoords.y, entityCoords.z
                hasSynced = true
                travelSqr = 0.0
                streamInAround(entityCoords.x, entityCoords.y, entityCoords.z)
            end

            local previousX, previousY, previousZ = posX, posY, posZ
            local x, y, z, heading = updateCamera()
            travelSqr = x and ((x - previousX) ^ 2 + (y - previousY) ^ 2 + (z - previousZ) ^ 2) or 0.0

            if x then
                lastX, lastY, lastZ, lastHeading = x, y, z, heading
                frame += 1
                if frame % 10 == 0 then trackVehicle() end

                -- Only write the entity when it actually moved, and never while a
                -- divergence awaits confirmation (that would undo a real teleport).
                local sx, sy, sz = syncedX - x, syncedY - y, syncedZ - z
                if divergedFrames == 0 and (not hasSynced or sx * sx + sy * sy + sz * sz > 0.01) then
                    syncedX, syncedY, syncedZ = x, y, z
                    hasSynced = true
                    local entity = getSyncEntity()
                    SetEntityCoords(entity, x, y, z, false, false, false, false)
                    SetEntityHeading(entity, heading)
                end
            end

            Wait(0)
        end

        -- Final placement, honouring FallInAir for players on foot.
        if not lastX then return end
        local entity = getSyncEntity()
        if entity == hiddenVehicle then
            SetEntityCoords(entity, lastX, lastY, lastZ, false, false, false, false)
        else
            local exitX, exitY, exitZ = resolveExitCoords(lastX, lastY, lastZ)
            SetEntityCoords(entity, exitX, exitY, exitZ, false, false, false, false)
        end
        SetEntityHeading(entity, lastHeading)
    end)
end

local function runVisibilityLoop()
    CreateThread(function()
        while isFreecamActive() do
            local ped = cache.ped
            SetEntityLocallyInvisible(ped)
            -- Checked every frame so other scripts or resync can't show the ped even briefly.
            if IsEntityVisible(ped) then SetEntityVisible(ped, false, false) end

            if hiddenVehicle > 0 then
                if DoesEntityExist(hiddenVehicle) then
                    SetEntityLocallyInvisible(hiddenVehicle)
                    if IsEntityVisible(hiddenVehicle) then SetEntityVisible(hiddenVehicle, false, false) end
                else
                    hiddenVehicle = 0
                end
            end
            Wait(0)
        end

        if hiddenVehicle > 0 and DoesEntityExist(hiddenVehicle) then
            showVehicle(hiddenVehicle)
            SetEntityCoords(hiddenVehicle, posX, posY, posZ, false, false, false, false)
            SetPedIntoVehicle(cache.ped, hiddenVehicle, -1)
        end
        hiddenVehicle = 0
    end)
end

local function runInstructionalButtons()
    CreateThread(function()
        local scaleform = RequestScaleformMovie('instructional_buttons')
        while not HasScaleformMovieLoaded(scaleform) do Wait(0) end

        PushScaleformMovieFunction(scaleform, 'CLEAR_ALL')
        PopScaleformMovieFunctionVoid()
        PushScaleformMovieFunction(scaleform, 'SET_CLEAR_SPACE')
        PushScaleformMovieFunctionParameterInt(200)
        PopScaleformMovieFunctionVoid()

        local buttons = {
            { control = 15, label = locale('commands.speed_up') },
            { control = 14, label = locale('commands.speed_down') },
            { control = 21, label = locale('commands.faster') },
            { control = 19, label = locale('commands.slower') },
            { control = 31, label = locale('commands.fwdback') },
            { control = 30, label = locale('commands.leftright') },
            { control = 153, label = locale('commands.down') },
            { control = 152, label = locale('commands.up') },
        }
        for slot, button in ipairs(buttons) do
            PushScaleformMovieFunction(scaleform, 'SET_DATA_SLOT')
            PushScaleformMovieFunctionParameterInt(slot - 1)
            ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(0, button.control, true))
            BeginTextCommandScaleformString('STRING')
            AddTextComponentScaleform(button.label)
            EndTextCommandScaleformString()
            PopScaleformMovieFunctionVoid()
        end

        PushScaleformMovieFunction(scaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
        PopScaleformMovieFunctionVoid()
        PushScaleformMovieFunction(scaleform, 'SET_BACKGROUND_COLOUR')
        for _ = 1, 3 do PushScaleformMovieFunctionParameterInt(0) end
        PushScaleformMovieFunctionParameterInt(80)
        PopScaleformMovieFunctionVoid()

        while isFreecamActive() do
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
            Wait(0)
        end
        SetScaleformMovieAsNoLongerNeeded(scaleform)
    end)
end

---@param enabled boolean
local function setNoclip(enabled)
    AdminState.noclip = enabled
    LocalPlayer.state:set('noclip', enabled, true)
    SendNuiAction('setItemEnabled', { Name = 'noclip', State = enabled })

    local ped = cache.ped
    if enabled then
        SetEntityVisible(ped, false, false)
        SetEntityCollision(ped, false, false)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)

        hiddenVehicle = GetVehiclePedIsIn(ped, false)
        if hiddenVehicle > 0 then hideVehicle(hiddenVehicle) end

        if isFreecamActive() then return end
        Notify(locale('notify.noclip_enabled'), 'success')
        setFreecamActive(true)
        local coords = GetEntityCoords(ped)
        setCameraPosition(coords.x, coords.y, coords.z)
        runCameraLoop()
        runVisibilityLoop()
        runInstructionalButtons()
        return
    end

    -- The network flag re-applies its stored visibility, so it is cleared first.
    if not AdminState.invisible then NetworkSetEntityInvisibleToNetwork(ped, false) end
    SetEntityVisible(ped, not AdminState.invisible, false)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, AdminState.godmode)
    FreezeEntityPosition(ped, false)
    if AdminState.godmode then SetPlayerInvincible(cache.playerId, true) end

    if not isFreecamActive() then return end
    Notify(locale('notify.noclip_disabled'), 'error')
    -- Placement (including FallInAir) happens in the camera loop's exit.
    setFreecamActive(false)
    SetGameplayCamRelativeHeading(0)
end

--- Moves the freecam and the player while noclip is on.
---@param coords vector3|table
function TeleportNoclip(coords)
    if not isFreecamActive() then return end
    setCameraPosition(coords.x, coords.y, coords.z)
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, false)
    if hiddenVehicle > 0 and DoesEntityExist(hiddenVehicle) then
        SetEntityCoords(hiddenVehicle, coords.x, coords.y, coords.z, false, false, false, false)
    end
end

AddEventHandler('butter_admin:client:toggleNoclip', function()
    local enabled = not AdminState.noclip
    -- Turning it off never needs authorizing, which keeps the toggle instant.
    if enabled and not IsAuthorizedRemote('noclip') then return end

    CloseAdminMenu()
    setNoclip(enabled)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not AdminState.noclip then return end

    -- The freecam threads die with the resource, so their cleanup never runs.
    setFreecamActive(false)
    local ped = cache.ped
    NetworkSetEntityInvisibleToNetwork(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetPlayerInvincible(cache.playerId, false)
    if hiddenVehicle > 0 and DoesEntityExist(hiddenVehicle) then showVehicle(hiddenVehicle) end
    LocalPlayer.state:set('noclip', false, true)
end)
