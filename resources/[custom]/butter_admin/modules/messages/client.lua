local lastAdminId ---@type number?

RegisterNetEvent('butter_admin:client:receiveDirectMessage', function(adminId, adminName, message)
    lastAdminId = adminId
    Notify(locale('notify.dm_received_toast', adminName), 'inform')
    TriggerEvent('chat:addMessage', { color = { 255, 100, 0 }, multiline = true, args = { ('ADMIN DM [%s]'):format(adminName), message } })
    SendNuiAction('receiveDirectMessage', { SenderId = adminId, SenderName = adminName, Message = message })
end)

-- A player answering this admin's message.
RegisterNetEvent('butter_admin:client:receiveDirectReply', function(playerId, playerName, message)
    Notify(locale('notify.dm_reply_received', playerName), 'inform')
    SendNuiAction('receiveDirectMessage', { SenderId = playerId, SenderName = playerName, Message = message, IsReply = true })
end)

RegisterCommand(Config.Menu.Commands.DirectMessages, function()
    if not lastAdminId then return Notify(locale('notify.no_dm_session'), 'error') end
    SetNuiFocus(true, true)
    SendNuiAction('openDirectMessages', { Locales = GetUiLocales() })
end, false)

RegisterNUICallback('sendDirectMessage', function(data, cb)
    TriggerServerEvent('butter_admin:server:sendDirectMessage', data.targetId, data.message)
    cb(true)
end)

RegisterNUICallback('replyDirectMessage', function(data, cb)
    TriggerServerEvent('butter_admin:server:replyDirectMessage', data.targetId, data.message)
    cb(true)
end)
