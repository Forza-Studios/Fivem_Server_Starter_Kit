local sessions = {} ---@type table<number, number> admin source -> target source

--- Target coords, retried briefly in case the ped has not been created yet.
---@param target number
---@return vector3?
local function getTargetCoords(target)
    for _ = 1, 10 do
        local ped = GetPlayerPed(target)
        if ped ~= 0 then
            local coords = GetEntityCoords(ped)
            if coords.x ~= 0.0 or coords.y ~= 0.0 or coords.z ~= 0.0 then return coords end
        end
        Wait(50)
    end
end

---@param source number
---@return boolean
function IsSpectating(source)
    return sessions[source] ~= nil
end

RegisterNetEvent('butter_admin:server:startSpectate', function(payload)
    local source = source
    if not IsAuthorized(source, 'spectate', 'Spectated without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if target == source then return Notify(source, locale('spectate.self'), 'error') end
    if not target then return Notify(source, locale('spectate.not_found'), 'error') end

    local coords = getTargetCoords(target)
    if not coords then return Notify(source, locale('spectate.not_found'), 'error') end

    sessions[source] = target
    TriggerClientEvent('butter_admin:client:spectate', source, target, coords, false)
    CreateLog(source, 'Spectate', ('Started spectating %s (%s)'):format(GetPlayerName(target), target))
end)

RegisterNetEvent('butter_admin:server:stopSpectate', function()
    local source = source
    -- Only real sessions are logged, so this cannot be used to spam the audit log.
    if not sessions[source] then return end
    sessions[source] = nil
    CreateLog(source, 'Spectate', 'Stopped spectating')
end)

RegisterNetEvent('butter_admin:server:cycleSpectate', function(direction)
    local source = source
    local current = sessions[source]
    if not current then return end
    if not IsAuthorized(source, 'spectate') then return Notify(source, locale('info.unauthorized'), 'error') end

    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        local id = tonumber(playerId)
        if id ~= source then players[#players + 1] = id end
    end
    if #players == 0 then return Notify(source, locale('spectate.no_players_cycle'), 'error') end
    table.sort(players)

    local index = 1
    for i, id in ipairs(players) do
        if id == current then
            index = i + (tonumber(direction) == -1 and -1 or 1)
            break
        end
    end
    if index > #players then index = 1 elseif index < 1 then index = #players end

    local target = players[index]
    local coords = getTargetCoords(target)
    if not coords then return Notify(source, locale('spectate.not_found'), 'error') end

    sessions[source] = target
    TriggerClientEvent('butter_admin:client:spectate', source, target, coords, true)
    CreateLog(source, 'Spectate', ('Switched spectating to %s (%s)'):format(GetPlayerName(target), target))
end)

AddEventHandler('playerDropped', function()
    local source = source
    sessions[source] = nil

    -- Tell admins watching this player; their client cannot tell a disconnect
    -- apart from the target merely streaming out of range.
    for admin, target in pairs(sessions) do
        if target == source then TriggerClientEvent('butter_admin:client:spectateTargetDropped', admin, source) end
    end
end)

exports('isSpectating', IsSpectating)
