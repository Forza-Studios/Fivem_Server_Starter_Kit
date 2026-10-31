RegisterNUICallback('fetchResources', function(_, cb)
    cb(lib.callback.await('butter_admin:server:getResources', false) or {})
end)

RegisterNUICallback('resourceAction', function(data, cb)
    TriggerServerEvent('butter_admin:server:resourceAction', { resource = data.resource, action = data.action })
    cb(true)
end)

RegisterNetEvent('butter_admin:client:updateResources', function(resources)
    SendNuiAction('updateMenu', { Resources = resources })
end)
