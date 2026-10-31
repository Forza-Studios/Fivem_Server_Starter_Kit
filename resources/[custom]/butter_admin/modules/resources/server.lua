local RESOURCE_ACTIONS = { start = true, stop = true, restart = true }

---@return { Name: string, State: string }[]
local function buildResourceList()
    local list = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name then list[#list + 1] = { Name = name, State = GetResourceState(name) } end
    end
    table.sort(list, function(a, b) return a.Name < b.Name end)
    return list
end

lib.callback.register('butter_admin:server:getResources', function(source)
    if not IsAuthorized(source, 'resources_management') then return {} end
    return buildResourceList()
end)

RegisterNetEvent('butter_admin:server:resourceAction', function(data)
    local source = source
    if not IsAuthorized(source, 'resources_management', 'Managed resources without permission') then return end
    if type(data) ~= 'table' then return end

    local name, action = data.resource, data.action
    if type(name) ~= 'string' or not name:match('^[%w_%-]+$') or not RESOURCE_ACTIONS[action] then return end
    if name == cache.resource and action ~= 'start' then
        return Notify(source, locale('notify.cannot_stop_admin'), 'error')
    end

    if action == 'start' then
        StartResource(name)
    elseif action == 'stop' then
        StopResource(name)
    else
        StopResource(name)
        Wait(500)
        StartResource(name)
    end

    CreateLog(source, 'Resource', ('%s resource %s'):format(action, name), json.encode({ resource = name, action = action }))
    TriggerClientEvent('butter_admin:client:updateResources', source, buildResourceList())
end)
