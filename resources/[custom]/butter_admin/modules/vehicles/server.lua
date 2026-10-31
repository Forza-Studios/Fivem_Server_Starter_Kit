local PLATE_CHARACTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
local MAX_PROPS_SIZE = 32768 -- encoded vehicle props are a few KB at most
local BENNYS_GRANT_TTL = 30 * 60 -- seconds
local BENNYS_MAX_DISTANCE = 15.0

-- The Bennys menu can be opened on a regular player's client by an admin, so
-- that player may save their vehicle's mods for a while afterwards.
local bennysGrants = {} ---@type table<number, number> source -> expiry

AddEventHandler('playerDropped', function()
    bennysGrants[source] = nil
end)

---@param model any
---@return string?
local function readModelName(model)
    if type(model) ~= 'string' then return nil end
    model = model:lower()
    if #model > 64 or not model:match('^[%w_%-]+$') then return nil end
    return model
end

--- Spawn name for a model hash, from the framework's vehicle list.
---@param modelHash number
---@return string?
local function getModelNameFromHash(modelHash)
    local vehicles = GetVehicles() or {}
    if vehicles[modelHash] then return vehicles[modelHash].model end

    for key, vehicle in pairs(vehicles) do
        if type(vehicle) == 'table' and (vehicle.hash == modelHash or (type(key) == 'string' and joaat(key) == modelHash)) then
            return vehicle.model or key
        end
    end
end

---@return string?
local function generateUniquePlate()
    for _ = 1, 20 do
        local characters = {}
        for i = 1, 8 do
            local index = math.random(#PLATE_CHARACTERS)
            characters[i] = PLATE_CHARACTERS:sub(index, index)
        end
        local plate = table.concat(characters)
        if not IsVehicleOwned(plate) then return plate end
    end
end

---@param props any
---@return boolean
local function isValidProps(props)
    return type(props) == 'table' and #json.encode(props) <= MAX_PROPS_SIZE
end

--- A Bennys grantee may only save the vehicle they are at, so the grant
--- cannot be used to rewrite another owned vehicle's mods by plate.
---@param source number
---@param netId any
---@param plate string
---@return boolean
local function isGrantedVehicle(source, netId, plate)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return false end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return false end

    local trim = '^%s*(.-)%s*$'
    if GetVehicleNumberPlateText(vehicle):match(trim) ~= plate:match(trim) then return false end

    return #(GetEntityCoords(vehicle) - GetEntityCoords(GetPlayerPed(source))) <= BENNYS_MAX_DISTANCE
end

RegisterNetEvent('butter_admin:server:logVehicleSpawn', function(model, plate)
    local source = source
    if not IsAuthorized(source, 'spawnCar') then return end

    model, plate = SanitizeString(tostring(model), 64), SanitizeString(plate, 16)
    CreateLog(source, 'Vehicle Spawn', ('Spawned Vehicle: %s (Plate: %s)'):format(model or '?', plate or '?'), json.encode({ model = model, plate = plate }))
end)

RegisterNetEvent('butter_admin:server:registerAdminCar', function(plate, model, props)
    local source = source
    if not IsAuthorized(source, 'admincar', 'Registered an admin car without permission') then return end

    -- The native plate text is padded to 8 characters; garages look plates up trimmed.
    plate = type(plate) == 'string' and plate:match('^%s*(.-)%s*$') or nil
    if not IsValidPlate(plate) then return Notify(source, locale('notify.invalid_plate'), 'error') end
    if not isValidProps(props) then return Notify(source, locale('notify.invalid_vehicle_data'), 'error') end

    local playerData = GetPlayerData(source)
    if not playerData then return end
    if IsVehicleOwned(plate) then return Notify(source, locale('notify.vehicle_already_owned'), 'error') end

    -- Prefer the framework's spawn name over the client's display name.
    model = (tonumber(props.model) and getModelNameFromHash(tonumber(props.model))) or readModelName(model)
    if not model then return Notify(source, locale('notify.invalid_vehicle_data'), 'error') end

    props.plate = plate
    local license = playerData.license or GetIdentifier(source, 'license') or playerData.citizenId
    if not RegisterVehicleToPlayer(playerData.citizenId, license, plate, model, props) then
        return Notify(source, locale('notify.invalid_vehicle_data'), 'error')
    end
    InvalidateDynamicChoices()

    Notify(source, locale('notify.vehicle_registered_to_you', model:upper(), plate), 'success')
    CreateLog(source, 'Vehicle', ('Registered vehicle %s (%s) as personal car'):format(model, plate))
end)

RegisterNetEvent('butter_admin:server:giveCar', function(payload)
    local source = source
    if not IsAuthorized(source, 'giveCar', 'Gave a car without permission') then return end
    if type(payload) ~= 'table' then return end

    local target = ResolveTarget(payload.player)
    local playerData = target and GetPlayerData(target)
    if not playerData then return Notify(source, locale('notify.invalid_player'), 'error') end

    local customModel = payload.custom_model ~= '' and payload.custom_model or nil
    local model = readModelName(customModel or payload.model)
    if not model then return Notify(source, locale('notify.invalid_vehicle_data'), 'error') end

    local plate = generateUniquePlate()
    if not plate then return Notify(source, locale('notify.invalid_vehicle_data'), 'error') end

    local garage = SanitizeString(payload.garage, 64) or 'pillboxgarage'
    local license = playerData.license or GetIdentifier(target, 'license') or playerData.citizenId
    local registered = RegisterVehicleToPlayer(playerData.citizenId, license, plate, model, {
        model = joaat(model),
        plate = plate,
        engineHealth = 1000.0,
        bodyHealth = 1000.0,
        tankHealth = 1000.0,
        fuelLevel = 100.0,
        dirtLevel = 0.0,
    })
    if not registered then return Notify(source, locale('notify.invalid_vehicle_data'), 'error') end

    UpdateVehicleGarage(plate, garage)
    InvalidateDynamicChoices()

    local targetName = GetPlayerName(target)
    Notify(source, locale('notify.vehicle_given', model:upper(), plate, targetName), 'success')
    CreateLog(source, 'Vehicle', ('Gave vehicle %s (%s) to %s, stored in garage %s'):format(model, plate, targetName, garage),
        json.encode({ target = target, model = model, plate = plate, garage = garage }))
end)

RegisterNetEvent('butter_admin:server:refuelVehicle', function(payload)
    local source = source
    local target = ResolvePayloadTarget(payload, source)
    if not target then return Notify(source, locale('notify.invalid_player'), 'error') end

    -- "ReFuel" and "Self Fuel" share this event.
    local permissions = target == source and { 'refuel', 'selffuel' } or { 'refuel' }
    if not IsAuthorizedAny(source, permissions, 'Refueled a vehicle without permission') then return end

    local fuel = math.floor(ClampNumber(ReadField(payload, 'fuel'), 0, 100, 100))
    TriggerClientEvent('butter_admin:client:setFuel', target, fuel)

    if target == source then
        return CreateLog(source, 'Refuel', ('Refueled own vehicle to %s%%'):format(fuel), json.encode({ target = target, fuel = fuel }))
    end

    local targetName = GetPlayerName(target)
    Notify(source, locale('notify.vehicle_refueled_for_player', targetName), 'success')
    CreateLog(source, 'Refuel', ('Refueled vehicle for player %s to %s%%'):format(targetName, fuel), json.encode({ target = target, fuel = fuel }))
end)

RegisterNetEvent('butter_admin:server:openBennys', function(payload)
    local source = source
    if not IsAuthorized(source, 'adminCustoms', 'Opened Bennys without permission') then return end

    local target = ResolvePayloadTarget(payload, source)
    if not target then return Notify(source, locale('notify.invalid_player'), 'error') end

    bennysGrants[target] = os.time() + BENNYS_GRANT_TTL
    TriggerClientEvent('butter_admin:client:openBennys', target)

    if target == source then
        return CreateLog(source, 'Bennys', 'Opened Bennys for self', json.encode({ target = target }))
    end

    local targetName = GetPlayerName(target)
    Notify(source, locale('notify.bennys_opened_for', targetName), 'success')
    CreateLog(source, 'Bennys', ('Opened Bennys for player %s'):format(targetName), json.encode({ target = target }))
end)

--- Saves Bennys changes to an owned vehicle. Only for players the menu was
--- opened for, or admins holding the permission.
RegisterNetEvent('butter_admin:server:saveVehicleProps', function(props, netId)
    local source = source
    if not isValidProps(props) or type(props.plate) ~= 'string' then return end

    if not IsAuthorized(source, 'adminCustoms') then
        local grant = bennysGrants[source]
        if not grant or grant <= os.time() then return end
        if not isGrantedVehicle(source, netId, props.plate) then return end
    end

    -- Stored plates may or may not keep the native space padding.
    local plate = props.plate
    if not IsVehicleOwned(plate) then
        plate = plate:match('^%s*(.-)%s*$')
        if plate == '' or not IsVehicleOwned(plate) then return end
    end

    props.plate = plate
    UpdateVehicleModsAndPlate(plate, plate, props)
end)
