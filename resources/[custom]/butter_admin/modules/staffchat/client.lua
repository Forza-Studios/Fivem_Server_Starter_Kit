local history = {} ---@type table[]

RegisterNetEvent('butter_admin:client:syncStaffChat', function(messages)
    history = type(messages) == 'table' and messages or {}
    SendNuiAction('updateChats', { Staffchat = history })
end)

RegisterNetEvent('butter_admin:client:staffChatMessage', function(entry)
    if type(entry) ~= 'table' then return end
    history[#history + 1] = entry
    while #history > Config.StaffChat.MaxHistory do table.remove(history, 1) end
    SendNuiAction('updateChats', { Staffchat = history })
end)

RegisterNUICallback('sendStaffMessage', function(data, cb)
    -- The server stamps the sender and time, then broadcasts it.
    TriggerServerEvent('butter_admin:server:sendStaffMessage', data.message)
    cb(true)
end)
