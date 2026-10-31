local SOUND_RADIUS = 30.0
local MAX_KIDNAP_ENTITIES = 12

-- The victim's client spawns the kidnap van and escort and reports their net
-- IDs so the server can delete them. Only a victim the server sent a kidnap
-- to may register, a bounded number of entities, and only entities that
-- client created, so nobody can get the server to delete arbitrary entities.
local pendingKidnaps = {} ---@type table<number, boolean>
local kidnapEntities = {} ---@type table<number, number[]>

---@param eventName string
---@param options { permission: string, clientEvent: string, logType: string, logFormat: string, notifyKey: string, argument?: fun(payload: any): any }
local function registerTroll(eventName, options)
    RegisterNetEvent(eventName, function(payload)
        local source = source
        if not IsAuthorized(source, options.permission, ('Used %s without permission'):format(options.logType)) then return end

        local target = ResolvePayloadTarget(payload)
        if not target then return Notify(source, locale('notify.invalid_player'), 'error') end

        local argument = options.argument and options.argument(payload)
        TriggerClientEvent(options.clientEvent, target, argument)

        local targetName = GetPlayerName(target)
        Notify(source, locale(options.notifyKey, targetName), 'success')
        CreateLog(source, options.logType, options.logFormat:format(targetName), json.encode({ target = target, argument = argument }))
    end)
end

registerTroll('butter_admin:server:makeDrunk', {
    permission = 'drunkplayer', clientEvent = 'butter_admin:client:makeDrunk',
    logType = 'Make Drunk', logFormat = 'Made player %s drunk', notifyKey = 'trolling.drunk_success',
})

registerTroll('butter_admin:server:animalAttack', {
    permission = 'animalattack', clientEvent = 'butter_admin:client:animalAttack',
    logType = 'Animal Attack', logFormat = 'Triggered animal attack on %s', notifyKey = 'trolling.animal_success',
})

registerTroll('butter_admin:server:setOnFire', {
    permission = 'setonfire', clientEvent = 'butter_admin:client:setOnFire',
    logType = 'Set Fire', logFormat = 'Set player %s on fire', notifyKey = 'trolling.fire_success',
})

registerTroll('butter_admin:server:flingPlayer', {
    permission = 'throwplayer', clientEvent = 'butter_admin:client:flingPlayer',
    logType = 'Fling Player', logFormat = 'Flung player %s', notifyKey = 'trolling.fling_success',
})

registerTroll('butter_admin:server:sendToJailbox', {
    permission = 'jailbox', clientEvent = 'butter_admin:client:sendToJailbox',
    logType = 'Send to Jailbox', logFormat = 'Sent %s to the jailbox', notifyKey = 'trolling.jail_success',
})

registerTroll('butter_admin:server:damageVehicle', {
    permission = 'damagevehicle', clientEvent = 'butter_admin:client:damageVehicle',
    logType = 'Damage Vehicle', logFormat = 'Damaged vehicle of %s', notifyKey = 'trolling.veh_damage_success',
})

registerTroll('butter_admin:server:ufoKidnap', {
    permission = 'ufo', clientEvent = 'butter_admin:client:ufoKidnap',
    logType = 'UFO Kidnap', logFormat = 'Triggered UFO kidnap for %s', notifyKey = 'trolling.ufo_success',
})

registerTroll('butter_admin:server:ghostTroll', {
    permission = 'ghost', clientEvent = 'butter_admin:client:ghostTroll',
    logType = 'Ghost Troll', logFormat = 'Triggered Ghost Troll for %s', notifyKey = 'trolling.ghost_success',
    argument = function(payload)
        return math.floor(ClampNumber(ReadField(payload, 'duration'), 0, 3600, 0))
    end,
})

RegisterNetEvent('butter_admin:server:playSound', function(payload)
    local source = source
    if not IsAuthorized(source, 'playsound', 'Played a sound without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target then return Notify(source, locale('notify.invalid_player'), 'error') end

    local soundId = ReadField(payload, 'sound')
    if type(soundId) ~= 'string' or not Config.Sounds[soundId] then return end

    -- Everyone near the target hears it, fading linearly with distance.
    local origin = GetEntityCoords(GetPlayerPed(target))
    for _, playerId in ipairs(GetPlayers()) do
        local listener = tonumber(playerId)
        local ped = GetPlayerPed(listener)
        if ped ~= 0 then
            local distance = #(origin - GetEntityCoords(ped))
            if distance <= SOUND_RADIUS then
                TriggerClientEvent('butter_admin:client:playSound', listener, soundId, math.max(0.05, 0.5 * (1.0 - distance / SOUND_RADIUS)))
            end
        end
    end

    local targetName = GetPlayerName(target)
    Notify(source, locale('trolling.sound_success', soundId, targetName), 'success')
    CreateLog(source, 'Play Sound', ('Played sound %s for %s'):format(soundId, targetName), json.encode({ target = target, sound = soundId }))
end)

--- The forced command runs on the target with their own permissions, so only
--- whitelisted emote commands pass, and never a separator that chains another.
---@param command string
---@return boolean
local function isForceCommandAllowed(command)
    if command:find('[;\r\n]') then return false end
    local first = command:match('^(%S+)')
    if not first then return false end

    first = first:lower()
    for _, allowed in ipairs(Config.Fun.ForceCommandWhitelist) do
        if first == allowed then return true end
    end
    return false
end

RegisterNetEvent('butter_admin:server:forceAnimation', function(payload)
    local source = source
    if not IsAuthorized(source, 'forceanim', 'Forced an animation without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target then return Notify(source, locale('notify.invalid_player'), 'error') end
    local targetName = GetPlayerName(target)

    local command = SanitizeString(ReadField(payload, 'anim_command'), 128)
    if command then
        command = command:gsub('^/', '')
        if not isForceCommandAllowed(command) then return Notify(source, locale('trolling.anim_invalid'), 'error') end

        TriggerClientEvent('butter_admin:client:executeCommand', target, command)
        Notify(source, locale('trolling.anim_success', command, targetName), 'success')
        return CreateLog(source, 'Force Animation', ("Forced command '%s' on %s"):format(command, targetName), json.encode({ target = target, command = command }))
    end

    local animation = SanitizeString(ReadField(payload, 'anim'), 64)
    if not animation then return Notify(source, locale('trolling.anim_invalid'), 'error') end

    if not (PlayAnimation and PlayAnimation(target, animation)) then
        TriggerClientEvent('butter_admin:client:forceAnimation', target, animation)
    end
    Notify(source, locale('trolling.anim_success', animation, targetName), 'success')
    CreateLog(source, 'Force Animation', ('Forced animation %s on %s'):format(animation, targetName), json.encode({ target = target, anim = animation }))
end)

---@param target number
local function cleanupKidnap(target)
    local entities = kidnapEntities[target]
    kidnapEntities[target] = nil
    pendingKidnaps[target] = nil

    for _, entity in ipairs(entities or {}) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end

RegisterNetEvent('butter_admin:server:kidnapVan', function(payload)
    local source = source
    if not IsAuthorized(source, 'kidnapvan', 'Sent a kidnap van without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target then return Notify(source, locale('notify.invalid_player'), 'error') end

    -- Drop the victim at the admin's waypoint when one is set.
    local ok, waypoint = pcall(lib.callback.await, 'butter_admin:client:getWaypoint', source)
    waypoint = ok and ReadVector3(waypoint) or nil

    cleanupKidnap(target)
    pendingKidnaps[target] = true
    TriggerClientEvent('butter_admin:client:kidnapVan', target, waypoint)

    local targetName = GetPlayerName(target)
    Notify(source, locale('trolling.kidnap_van_success', targetName), 'success')
    CreateLog(source, 'Kidnap Van', ('Triggered kidnap van for %s'):format(targetName), json.encode({ target = target, waypoint = waypoint }))
end)

RegisterNetEvent('butter_admin:server:registerKidnapEntities', function(netIds)
    local source = source
    if not pendingKidnaps[source] or type(netIds) ~= 'table' then return end
    pendingKidnaps[source] = nil

    local entities = {}
    for i = 1, math.min(#netIds, MAX_KIDNAP_ENTITIES) do
        local netId = tonumber(netIds[i])
        local entity = netId and netId > 0 and NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) and NetworkGetFirstEntityOwner(entity) == source then
            entities[#entities + 1] = entity
        end
    end
    kidnapEntities[source] = entities
end)

RegisterNetEvent('butter_admin:server:cleanupKidnap', function()
    cleanupKidnap(source)
end)

AddEventHandler('playerDropped', function()
    cleanupKidnap(source)
end)
