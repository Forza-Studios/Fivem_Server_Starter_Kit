local PROP_PERMISSIONS = { 'spawnprop', 'spawnProp', 'manageProp' }
local ENTITY_TIMEOUT = 1000 -- ms to wait for a server-created entity

local spawnedObjects = {} ---@type table<string, table>
local syncedPlayers = {} ---@type table<number, true>

---@param model any
---@return string?
local function readModel(model)
    if type(model) == 'number' then return tostring(model) end
    if type(model) ~= 'string' or #model > 100 or not model:match('^[%w_%-]+$') then return nil end
    return model
end

--- Creates a networked, server-owned object with the given transform.
---@return number? entity
local function spawnServerObject(model, coords, heading, rotation, freeze)
    local entity = CreateObjectNoOffset(tonumber(model) or joaat(model), coords.x, coords.y, coords.z, true, true, false)

    local deadline = GetGameTimer() + ENTITY_TIMEOUT
    while not DoesEntityExist(entity) do
        if GetGameTimer() > deadline then return nil end
        Wait(10)
    end

    SetEntityHeading(entity, heading)
    SetEntityRotation(entity, rotation.x, rotation.y, rotation.z, 2, true)
    if freeze then FreezeEntityPosition(entity, true) end
    return entity
end

---@param objectId string
---@param object table
local function trackObject(objectId, object)
    spawnedObjects[objectId] = object
    TriggerClientEvent('butter_admin:client:objectCreated', -1, objectId, object)
end

MySQL.ready(function()
    AwaitSchema()

    local spawned = 0
    for _, row in ipairs(MySQL.query.await('SELECT id, model, coords, heading, rotation, freeze FROM admin_objects') or {}) do
        local coords, rotation = ReadVector3(DecodeJson(row.coords)), ReadVector3(DecodeJson(row.rotation))
        local freeze = row.freeze == 1 or row.freeze == true
        local entity = coords and rotation and spawnServerObject(row.model, coords, row.heading + 0.0, rotation, freeze)

        if entity then
            spawnedObjects['perm_' .. row.id] = {
                netId = NetworkGetNetworkIdFromEntity(entity),
                model = row.model,
                coords = coords,
                heading = row.heading,
                rotation = rotation,
                freeze = freeze,
                isPermanent = true,
                dbId = row.id,
            }
            spawned += 1
        else
            LogWarn(('Could not spawn saved object %s (%s)'):format(row.id, row.model))
        end
    end
    LogDebug(('Spawned %d saved objects'):format(spawned))
end)

RegisterNetEvent('butter_admin:server:spawnObject', function(model, coords, heading, rotation, freeze, permanent)
    local source = source
    if not IsAuthorizedAny(source, PROP_PERMISSIONS, 'Spawned an object without permission') then return end

    model = readModel(model)
    coords = ReadVector3(coords)
    rotation = ReadVector3(rotation) or vector3(0.0, 0.0, 0.0)
    heading = tonumber(heading) or 0.0
    freeze = freeze == true
    if not model or not coords then return Notify(source, locale('notify.invalid_object_selected'), 'error') end

    local entity = spawnServerObject(model, coords, heading, rotation, freeze)
    if not entity then return Notify(source, locale('objects.invalid_model', model), 'error') end

    local object = {
        netId = NetworkGetNetworkIdFromEntity(entity),
        model = model,
        coords = coords,
        heading = heading,
        rotation = rotation,
        freeze = freeze,
        isPermanent = permanent == true,
    }

    if object.isPermanent then
        local id = MySQL.insert.await('INSERT INTO admin_objects (model, coords, heading, rotation, freeze) VALUES (?, ?, ?, ?, ?)', {
            model, json.encode({ x = coords.x, y = coords.y, z = coords.z }), heading,
            json.encode({ x = rotation.x, y = rotation.y, z = rotation.z }), freeze and 1 or 0,
        })
        if not id then
            DeleteEntity(entity)
            LogError(('Could not save object %s'):format(model))
            return Notify(source, locale('notify.invalid_object_selected'), 'error')
        end

        object.dbId = id
        trackObject('perm_' .. id, object)
        Notify(source, locale('notify.permanent_object_spawned'), 'success')
    else
        trackObject(('temp_%s%s'):format(os.time(), math.random(1000, 9999)), object)
        Notify(source, locale('notify.temporary_object_spawned'), 'success')
    end

    CreateLog(source, 'Spawn Prop', ('Spawned %s prop %s'):format(object.isPermanent and 'permanent' or 'temporary', model),
        json.encode({ model = model, coords = { x = coords.x, y = coords.y, z = coords.z } }))
end)

RegisterNetEvent('butter_admin:server:deleteObject', function(objectId)
    local source = source
    if not IsAuthorizedAny(source, PROP_PERMISSIONS, 'Deleted an object without permission') then return end

    local object = type(objectId) == 'string' and spawnedObjects[objectId]
    if not object then return Notify(source, locale('notify.invalid_object_selected'), 'error') end

    local entity = NetworkGetEntityFromNetworkId(object.netId)
    if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end

    if object.isPermanent then
        MySQL.update('DELETE FROM admin_objects WHERE id = ?', { object.dbId })
        Notify(source, locale('notify.permanent_object_deleted'), 'success')
    else
        Notify(source, locale('notify.temporary_object_deleted'), 'success')
    end

    spawnedObjects[objectId] = nil
    TriggerClientEvent('butter_admin:client:objectDeleted', -1, objectId)
    CreateLog(source, 'Delete Prop', ('Deleted prop %s (%s)'):format(object.model, objectId))
end)

-- Each client asks once after joining and gets every object in one event.
RegisterNetEvent('butter_admin:server:requestObjects', function()
    local source = source
    if syncedPlayers[source] then return end
    syncedPlayers[source] = true
    if next(spawnedObjects) then TriggerClientEvent('butter_admin:client:syncObjects', source, spawnedObjects) end
end)

AddEventHandler('playerDropped', function()
    syncedPlayers[source] = nil
end)

lib.callback.register('butter_admin:server:getObjects', function(source)
    if not IsAuthorizedAny(source, PROP_PERMISSIONS) then return {} end
    return spawnedObjects
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    for _, object in pairs(spawnedObjects) do
        local entity = NetworkGetEntityFromNetworkId(object.netId)
        if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end)
