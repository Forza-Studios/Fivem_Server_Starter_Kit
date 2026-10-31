RegisterNUICallback('fetchDashboard', function(_, cb)
    cb(lib.callback.await('butter_admin:server:getDashboard', false) or {})
end)

RegisterNUICallback('fetchDashboardSessions', function(_, cb)
    cb(lib.callback.await('butter_admin:server:getDashboardSessions', false) or {})
end)

-- The page subscribes while open, so the server only streams to viewers.
RegisterNUICallback('subscribeDashboard', function(data, cb)
    TriggerServerEvent('butter_admin:server:subscribeDashboard', data.enabled == true)
    cb(true)
end)

RegisterNUICallback('runConsoleCommand', function(data, cb)
    if type(data.command) == 'string' then TriggerServerEvent('butter_admin:server:runConsoleCommand', data.command) end
    cb(true)
end)

RegisterNetEvent('butter_admin:client:dashboardPush', function(payload)
    SendNuiAction('dashboardPush', payload)
end)
