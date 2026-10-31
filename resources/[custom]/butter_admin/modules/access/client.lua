RegisterNUICallback('fetchAccessControl', function(_, cb)
    cb(lib.callback.await('butter_admin:server:getAccessData', false) or false)
end)

RegisterNUICallback('saveRank', function(data, cb)
    TriggerServerEvent('butter_admin:server:saveRank', data)
    cb(true)
end)

RegisterNUICallback('deleteRank', function(data, cb)
    TriggerServerEvent('butter_admin:server:deleteRank', data.id)
    cb(true)
end)

RegisterNUICallback('saveAdmin', function(data, cb)
    TriggerServerEvent('butter_admin:server:saveAdmin', data)
    cb(true)
end)

RegisterNUICallback('deleteAdmin', function(data, cb)
    TriggerServerEvent('butter_admin:server:deleteAdmin', data.identifier)
    cb(true)
end)

RegisterNUICallback('setDiscordLogs', function(data, cb)
    TriggerServerEvent('butter_admin:server:setDiscordLogs', data.enabled == true)
    cb(true)
end)

RegisterNetEvent('butter_admin:client:updateAccessData', function(data)
    SendNuiAction('updateMenu', {
        Ranks = data.Ranks or {},
        Admins = data.Admins or {},
        AvailablePermissions = data.AvailablePermissions or {},
        DiscordRoles = data.DiscordRoles or {},
        -- Left out of live broadcasts; nil keeps the list the UI already has.
        Characters = data.Characters,
        DiscordLogsEnabled = data.DiscordLogsEnabled,
    })
end)
