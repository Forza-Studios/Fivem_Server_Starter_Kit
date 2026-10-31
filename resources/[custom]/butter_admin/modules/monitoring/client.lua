if not Config.EnableMonitoring then return end

-- Monitoring buttons map onto the regular admin actions.
local MONITORING_ACTIONS = {
    bring = function(target) TriggerServerEvent('butter_admin:server:teleportPlayer', { player = target, type = 'Bring' }) end,
    ['goto'] = function(target) TriggerServerEvent('butter_admin:server:teleportPlayer', { player = target, type = 'Goto' }) end,
    freeze = function(target) TriggerServerEvent('butter_admin:server:toggleFreeze', { player = target }) end,
    revive = function(target) TriggerServerEvent('butter_admin:server:revivePlayer', { player = target }) end,
    screenshot = function(target) TriggerServerEvent('butter_admin:server:captureScreenshot', target) end,
}

RegisterNUICallback('fetchPlayerLocations', function(_, cb)
    cb(lib.callback.await('butter_admin:server:getPlayerLocations', false) or {})
end)

RegisterNUICallback('requestLiveStream', function(data, cb)
    if not data.target then return cb(false) end
    cb(lib.callback.await('butter_admin:server:requestLiveStream', false, data.target) or false)
end)

RegisterNUICallback('monitoringAction', function(data, cb)
    local action = MONITORING_ACTIONS[data.action]
    if action and data.target then action(data.target) end
    cb(true)
end)
