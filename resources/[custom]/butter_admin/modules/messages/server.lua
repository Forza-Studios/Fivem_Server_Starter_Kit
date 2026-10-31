local REPLY_COOLDOWN_MS = 750

-- Players may only reply to admins who messaged them.
local conversations = {} ---@type table<number, table<number, true>> player -> admins
local lastReplyAt = {} ---@type table<number, number>

RegisterNetEvent('butter_admin:server:sendDirectMessage', function(targetId, message)
    local source = source
    if not IsAuthorized(source, 'menuopen', 'Sent an admin DM without permission') then return end

    local target = ResolveTarget(targetId)
    message = SanitizeString(message, 512)
    if not message or target == source then return end
    if not target then return Notify(source, locale('notify.player_offline'), 'error') end

    conversations[target] = conversations[target] or {}
    conversations[target][source] = true

    local targetName = GetPlayerName(target)
    TriggerClientEvent('butter_admin:client:receiveDirectMessage', target, source, GetPlayerName(source), message)
    Notify(source, locale('notify.dm_sent', targetName), 'success')
    CreateLog(source, 'DM', ('Sent DM to %s (%s): %s'):format(targetName, target, message), json.encode({ target = target, msg = message }))
end)

RegisterNetEvent('butter_admin:server:replyDirectMessage', function(adminId, message)
    local source = source
    local admin = ResolveTarget(adminId)
    if not admin or not (conversations[source] and conversations[source][admin]) then return end

    message = SanitizeString(message, 512)
    if not message then return end

    local now = GetGameTimer()
    if lastReplyAt[source] and now - lastReplyAt[source] < REPLY_COOLDOWN_MS then return end
    lastReplyAt[source] = now

    TriggerClientEvent('butter_admin:client:receiveDirectReply', admin, source, GetPlayerName(source), message)
end)

AddEventHandler('playerDropped', function()
    local source = source
    conversations[source] = nil
    lastReplyAt[source] = nil
    for _, admins in pairs(conversations) do admins[source] = nil end
end)
