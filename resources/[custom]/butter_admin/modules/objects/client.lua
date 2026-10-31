local DRAW_GIZMO = 0xEB2EDCA2
local MATRIX_SIZE = 64

local spawnedObjects = {} ---@type table<string, table>
local placing = false
local gizmoMode = 'Translate'
local gizmoRelative = false

---@param model string|number
---@return number? hash
local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then
        Notify(locale('objects.invalid_model', tostring(model)), 'error')
        return nil
    end
    if not pcall(lib.requestModel, hash) then return nil end
    return hash
end

-- The gizmo native edits a 4x4 float matrix in place, so it is kept in a
-- mutable CfxLua blob (string.blob) rather than a regular string.

---@param entity number
---@return string blob
local function createMatrixBlob(entity)
    local forward, right, up, position = GetEntityMatrix(entity)
    local values = {
        right.x, right.y, right.z, 0.0,
        forward.x, forward.y, forward.z, 0.0,
        up.x, up.y, up.z, 0.0,
        position.x, position.y, position.z, 1.0,
    }

    local blob = string.blob(MATRIX_SIZE)
    for i, value in ipairs(values) do
        blob = blob:blob_pack((i - 1) * 4 + 1, '<f', value)
    end
    return blob
end

---@param blob string
---@param index integer 1-based float index
---@return number
local function readMatrixValue(blob, index)
    return (blob:blob_unpack((index - 1) * 4 + 1, '<f'))
end

---@param x number
---@param y number
---@param z number
---@return number, number, number
local function normalize(x, y, z)
    local length = math.sqrt(x * x + y * y + z * z)
    if length == 0 then return 0.0, 0.0, 0.0 end
    return x / length, y / length, z / length
end

---@param entity number
---@param blob string
local function applyMatrixBlob(entity, blob)
    local fx, fy, fz = normalize(readMatrixValue(blob, 5), readMatrixValue(blob, 6), readMatrixValue(blob, 7))
    local rx, ry, rz = normalize(readMatrixValue(blob, 1), readMatrixValue(blob, 2), readMatrixValue(blob, 3))
    local ux, uy, uz = normalize(readMatrixValue(blob, 9), readMatrixValue(blob, 10), readMatrixValue(blob, 11))
    SetEntityMatrix(entity, fx, fy, fz, rx, ry, rz, ux, uy, uz, readMatrixValue(blob, 13), readMatrixValue(blob, 14), readMatrixValue(blob, 15))
end

---@param name string
---@param description string
---@param key string
---@param mapper? string
---@param onPressed fun()
---@param gizmoCommand string
local function addGizmoKeybind(name, description, key, mapper, onPressed, gizmoCommand)
    lib.addKeybind({
        name = name,
        description = description,
        defaultMapper = mapper,
        defaultKey = key,
        onPressed = function()
            if not placing then return end
            onPressed()
            ExecuteCommand('+' .. gizmoCommand)
        end,
        onReleased = function()
            ExecuteCommand('-' .. gizmoCommand)
        end,
    })
end

addGizmoKeybind('butter_admin_gizmo_select', 'Select Gizmo', 'MOUSE_LEFT', 'MOUSE_BUTTON', function() end, 'gizmoSelect')
addGizmoKeybind('butter_admin_gizmo_translate', 'Gizmo Translation', 'W', nil, function() gizmoMode = 'Translate' end, 'gizmoTranslation')
addGizmoKeybind('butter_admin_gizmo_rotate', 'Gizmo Rotation', 'R', nil, function() gizmoMode = 'Rotate' end, 'gizmoRotation')
addGizmoKeybind('butter_admin_gizmo_space', 'Gizmo Toggle Space', 'Q', nil, function() gizmoRelative = not gizmoRelative end, 'gizmoLocal')

---@param object number
---@param cursorActive boolean
local function showPlacementHelp(object, cursorActive)
    local coords = GetEntityCoords(object)
    local rotation = GetEntityRotation(object, 2)
    local lines = {
        ('Current Mode: %s | %s'):format(gizmoMode, gizmoRelative and 'Relative' or 'World'),
        ('Position: %.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z),
        ('Rotation: %.2f, %.2f, %.2f'):format(rotation.x, rotation.y, rotation.z),
        ('[G] - %s'):format(cursorActive and 'Disable Cursor' or 'Enable Cursor'),
        '[W] - Translate Mode',
        '[R] - Rotate Mode',
        '[Q] - Toggle Space',
        '[LALT] - Snap to Ground',
        '[ENTER] - Confirm',
        '[BACKSPACE] - Cancel',
    }
    SendNuiAction('textUiUpdate', { visible = true, text = table.concat(lines, '\n'), icon = 'arrows-alt' })
end

--- Lets the admin place a preview of the model with the gizmo.
---@param model string
---@return vector3? coords, number heading, vector3? rotation
local function choosePlacement(model)
    if placing then
        Notify(locale('objects.preview_active'), 'error')
        return nil, 0.0, nil
    end

    local hash = loadModel(model)
    if not hash then return nil, 0.0, nil end

    placing = true
    gizmoMode, gizmoRelative = 'Translate', false

    local start = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 3.0, 0.0)
    local object = CreateObject(hash, start.x, start.y, start.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAlpha(object, 200, true)
    SetEntityCollision(object, false, false)
    FreezeEntityPosition(object, true)
    SetEntityDrawOutline(object, true)

    EnterCursorMode()
    local cursorActive = true

    CreateThread(function()
        while placing do
            if DoesEntityExist(object) then showPlacementHelp(object, cursorActive) end
            Wait(100)
        end
        SendNuiAction('textUiUpdate', { visible = false })
    end)

    local resultCoords, resultHeading, resultRotation
    while placing and DoesEntityExist(object) do
        if IsControlJustPressed(0, 47) then -- G
            if cursorActive then LeaveCursorMode() else EnterCursorMode() end
            cursorActive = not cursorActive
        end

        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 140, true)
        DisablePlayerFiring(cache.playerId, true)

        local matrix = createMatrixBlob(object)
        if Citizen.InvokeNative(DRAW_GIZMO, matrix, 'Editor1', Citizen.ReturnResultAnyway()) then
            applyMatrixBlob(object, matrix)
        end

        if IsControlJustPressed(0, 19) then PlaceObjectOnGroundProperly_2(object) end -- Left Alt

        if IsControlJustPressed(0, 191) then -- Enter
            resultCoords, resultHeading, resultRotation = GetEntityCoords(object), GetEntityHeading(object), GetEntityRotation(object, 0)
            break
        elseif IsControlJustPressed(0, 177) or IsControlJustPressed(0, 73) then -- Backspace / X
            break
        end
        Wait(0)
    end

    if DoesEntityExist(object) then DeleteEntity(object) end
    if cursorActive then LeaveCursorMode() end
    placing = false
    return resultCoords, resultHeading or 0.0, resultRotation
end

---@param objectId string
---@param object table
local function trackObject(objectId, object)
    spawnedObjects[objectId] = object

    -- Server-created objects reach clients a moment later; apply the transform once they exist.
    CreateThread(function()
        for _ = 1, 50 do
            if NetworkDoesNetworkIdExist(object.netId) then break end
            Wait(100)
        end
        if not NetworkDoesNetworkIdExist(object.netId) then return end

        local entity = NetworkGetEntityFromNetworkId(object.netId)
        if not DoesEntityExist(entity) then return end
        SetEntityHeading(entity, object.heading)
        if object.rotation then SetEntityRotation(entity, object.rotation.x, object.rotation.y, object.rotation.z, 2, true) end
        if object.freeze then FreezeEntityPosition(entity, true) end
    end)
end

RegisterNetEvent('butter_admin:client:objectCreated', trackObject)

RegisterNetEvent('butter_admin:client:syncObjects', function(objects)
    if type(objects) ~= 'table' then return end
    for objectId, object in pairs(objects) do trackObject(objectId, object) end
end)

RegisterNetEvent('butter_admin:client:objectDeleted', function(objectId)
    spawnedObjects[objectId] = nil
end)

--- Spawned props for the Manage Prop picker, nearest first.
---@return table[]
function GetSpawnedPropChoices()
    local playerCoords = GetEntityCoords(cache.ped)
    local choices = {}
    for objectId, object in pairs(spawnedObjects) do
        if object.coords then
            local distance = #(playerCoords - vector3(object.coords.x, object.coords.y, object.coords.z))
            choices[#choices + 1] = {
                Text = ('ID: %s | %s (%dm)'):format(objectId, object.model, math.floor(distance)),
                Source = objectId,
                Distance = distance,
            }
        end
    end

    if #choices == 0 then return { { Text = locale('objects.none_spawned') } } end
    table.sort(choices, function(a, b) return a.Distance < b.Distance end)
    return choices
end

AddEventHandler('butter_admin:client:spawnProp', function(options)
    if type(options) ~= 'table' then return end
    local model = (options.custom_model and options.custom_model ~= '') and options.custom_model or options.model
    if type(model) ~= 'string' or model == '' then return Notify(locale('objects.no_model'), 'error') end
    if not IsAuthorizedRemote('spawnProp') then return end

    CloseAdminMenu()
    CreateThread(function()
        local coords, heading, rotation = choosePlacement(model)
        if not coords then return end

        TriggerServerEvent('butter_admin:server:spawnObject', model,
            { x = coords.x, y = coords.y, z = coords.z }, heading,
            { x = rotation.x, y = rotation.y, z = rotation.z },
            options.freeze ~= false, options.permanent == true)
    end)
end)

AddEventHandler('butter_admin:client:manageProp', function(options)
    if type(options) ~= 'table' then return end
    local objectId = options.object_id and tostring(options.object_id)
    if not objectId or objectId == '' then return Notify(locale('objects.invalid_selection'), 'error') end

    if not spawnedObjects[objectId] then
        local objects = lib.callback.await('butter_admin:server:getObjects', false) or {}
        spawnedObjects[objectId] = objects[objectId]
    end

    local object = spawnedObjects[objectId]
    if not object then return Notify(locale('objects.invalid_selection'), 'error') end

    if options.action == 'Delete' then
        return TriggerServerEvent('butter_admin:server:deleteObject', objectId)
    end

    if options.action == 'Teleport' then
        local coords = object.coords
        if not coords then return Notify(locale('objects.not_found'), 'error') end

        DoScreenFadeOut(500)
        Wait(500)
        SetEntityCoords(cache.ped, coords.x, coords.y, coords.z + 1.0, false, false, false, true)
        Wait(200)
        DoScreenFadeIn(500)
        Notify(locale('objects.teleport_success', object.model), 'success')
    end
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    TriggerServerEvent('butter_admin:server:requestObjects')
end)
