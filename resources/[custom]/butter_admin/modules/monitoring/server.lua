if not Config.EnableMonitoring then return end

---@param source number
---@return boolean
local function canMonitor(source)
    return IsAuthorized(source, 'page.monitoring')
end

---@return boolean
local function hasScreenCapture()
    return GetResourceState('screencapture') == 'started'
end

lib.callback.register('butter_admin:server:getPlayerLocations', function(source)
    if not canMonitor(source) then return {} end

    local locations = {}
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        local ped = GetPlayerPed(target)
        if ped ~= 0 then
            local coords = GetEntityCoords(ped)
            locations[#locations + 1] = {
                source = target,
                name = GetPlayerName(target),
                coords = { x = coords.x, y = coords.y, z = coords.z },
                health = GetEntityHealth(ped),
                armor = GetPedArmour(ped),
            }
        end
    end
    return locations
end)

lib.callback.register('butter_admin:server:requestLiveStream', function(source, target)
    if not canMonitor(source) or not hasScreenCapture() then return false end

    target = ResolveTarget(target)
    if not target then return false end

    local stream = promise.new()
    exports.screencapture:startLiveStream(target, { maxWidth = 1280 }, function(data)
        if type(data) == 'table' then
            if data.status == 'error' then
                LogError('Live stream failed to start:', tostring(data.error))
                return stream:resolve(false)
            end
            data.endpoint = GetConvar('screencapture_live_endpoint', '')
        end
        stream:resolve(data or false)
    end)

    CreateLog(source, 'Monitoring', ('Started live stream of %s'):format(GetPlayerName(target)), json.encode({ target = target }))
    return Citizen.Await(stream)
end)

RegisterNetEvent('butter_admin:server:captureScreenshot', function(target)
    local source = source
    if not canMonitor(source) or not hasScreenCapture() then return end

    target = ResolveTarget(target)
    if not target then return end

    exports.screencapture:serverCapture(target, { encoding = 'webp' }, function()
        LogDebug('Captured screenshot of', target)
    end)
    CreateLog(source, 'Monitoring', ('Captured screenshot of %s'):format(GetPlayerName(target)), json.encode({ target = target }))
end)
