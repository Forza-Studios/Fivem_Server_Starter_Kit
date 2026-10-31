---@param source number
local function notifyNotFound(source)
    Notify(source, locale('spectate.not_found'), 'error')
end

RegisterNetEvent('butter_admin:server:teleportAll', function()
    local source = source
    if not IsAuthorized(source, 'teleportAll', 'Teleported everyone without permission') then return end

    local coords = GetEntityCoords(GetPlayerPed(source))
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        if target ~= source then TriggerClientEvent('butter_admin:client:teleport', target, coords) end
    end

    Notify(source, locale('teleport.all_success'), 'success')
    CreateLog(source, 'Teleport All', 'Teleported all players to self position')
end)

RegisterNetEvent('butter_admin:server:teleportPlayer', function(payload)
    local source = source
    if not IsAuthorized(source, 'teleport', 'Teleported a player without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target or target == source then return notifyNotFound(source) end

    local targetName = GetPlayerName(target)
    local message
    if ReadField(payload, 'type') == 'Bring' then
        message = locale('teleport.bring_success', targetName)
        TriggerClientEvent('butter_admin:client:teleport', target, GetEntityCoords(GetPlayerPed(source)))
    else
        message = locale('teleport.to_success', targetName)
        TriggerClientEvent('butter_admin:client:teleport', source, GetEntityCoords(GetPlayerPed(target)))
    end

    Notify(source, message, 'success')
    CreateLog(source, 'Teleport Player', ('%s. Target: %s'):format(message, targetName), json.encode({ target = target }))
end)

RegisterNetEvent('butter_admin:server:teleportIntoVehicle', function(payload)
    local source = source
    if not IsAuthorized(source, 'teleport', 'Teleported into a vehicle without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target or target == source then return notifyNotFound(source) end

    local targetPed = GetPlayerPed(target)
    local vehicle = GetVehiclePedIsIn(targetPed, false)
    if vehicle == 0 then return Notify(source, locale('notify.target_not_in_vehicle'), 'error') end

    local targetName = GetPlayerName(target)
    TriggerClientEvent('butter_admin:client:teleportIntoVehicle', source, NetworkGetNetworkIdFromEntity(vehicle), GetEntityCoords(targetPed))
    Notify(source, locale('notify.teleporting_into_vehicle', targetName), 'success')
    CreateLog(source, 'Teleport Into Vehicle', ('Teleported into vehicle of player %s'):format(targetName), json.encode({ target = target }))
end)

RegisterNetEvent('butter_admin:server:teleportPlayerToCoords', function(payload)
    local source = source
    if not IsAuthorized(source, 'teleport', 'Teleported a player to coords without permission') then return end

    local coords = ReadVector3(ReadField(payload, 'coords'))
    if not coords then return Notify(source, locale('notify.invalid_coords'), 'error') end

    local target = ResolvePayloadTarget(payload)
    if not target then return notifyNotFound(source) end

    local targetName = GetPlayerName(target)
    TriggerClientEvent('butter_admin:client:teleport', target, coords, ReadField(payload, 'isWaypoint') == true)
    Notify(source, locale('teleport.coords_success_target', targetName, ('%.2f'):format(coords.x), ('%.2f'):format(coords.y), ('%.2f'):format(coords.z)), 'success')
    CreateLog(source, 'Teleport Target to Coords', ('Teleported %s to coords: %.2f, %.2f, %.2f'):format(targetName, coords.x, coords.y, coords.z),
        json.encode({ target = target, coords = { x = coords.x, y = coords.y, z = coords.z } }))
end)
