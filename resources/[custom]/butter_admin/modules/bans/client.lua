RegisterNUICallback('fetchBans', function(_, cb)
    cb(lib.callback.await('butter_admin:server:getBans', false) or {})
end)

RegisterNUICallback('unbanPlayer', function(data, cb)
    if type(data.banId) == 'string' then TriggerServerEvent('butter_admin:server:unbanPlayer', data.banId) end
    cb(true)
end)
