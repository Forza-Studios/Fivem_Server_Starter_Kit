-- NUI fetch name -> server callback. Paged fetches forward the UI's paging payload.
local FETCHES = {
    fetchPlayers = 'butter_admin:server:getPlayers',
    fetchPlayerProfile = 'butter_admin:server:getPlayerProfile',
    fetchLogs = 'butter_admin:server:getLogs',
    fetchGarages = 'butter_admin:server:getGarages',
    fetchVehicles = 'butter_admin:server:getVehicles',
    fetchProperties = 'butter_admin:server:getProperties',
    fetchEconomy = 'butter_admin:server:getEconomy',
    fetchJobs = 'butter_admin:server:getJobs',
    fetchGangs = 'butter_admin:server:getGangs',
    fetchFactionMembers = 'butter_admin:server:getFactionMembers',
    fetchInventories = 'butter_admin:server:getInventories',
    updateAlignment = 'butter_admin:server:updateAlignment',
}

for name, callback in pairs(FETCHES) do
    RegisterNUICallback(name, function(data, cb)
        cb(lib.callback.await(callback, false, data) or false)
    end)
end

RegisterNUICallback('fetchInventoryItems', function(data, cb)
    cb(lib.callback.await('butter_admin:server:getInventoryItems', false, data.invId) or {})
end)

-- Edits resolve to whether the server applied them, so the UI can roll back.
local EDITS = {
    vehicleAction = 'butter_admin:server:vehicleAction',
    propertyAction = 'butter_admin:server:propertyAction',
    inventoryAction = 'butter_admin:server:inventoryAction',
}

for name, callback in pairs(EDITS) do
    RegisterNUICallback(name, function(data, cb)
        cb(lib.callback.await(callback, false, data) == true)
    end)
end

RegisterNUICallback('savePlayerNote', function(data, cb)
    TriggerServerEvent('butter_admin:server:savePlayerNote', data.identifier, data.note)
    cb(true)
end)
