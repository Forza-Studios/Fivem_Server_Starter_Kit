local DELETE_AREA_TYPES = { all = true, vehicles = true, peds = true, objects = true }
local MAX_DELETE_RADIUS = 500.0
local BLIPS_INTERVAL = 500 -- ms

local blipReceivers = {} ---@type table<number, true>
local blipReceiverCount = 0
local blipLoopRunning = false

RegisterNetEvent('butter_admin:server:deleteArea', function(payload)
    local source = source
    if not IsAuthorized(source, 'resetWorldArea', 'Cleared an area without permission') then return end

    local areaType = ReadField(payload, 'type')
    areaType = type(areaType) == 'string' and areaType:lower() or nil
    if not DELETE_AREA_TYPES[areaType] then return Notify(source, locale('notify.invalid_deletion_type'), 'error') end

    local radius = tonumber(ReadField(payload, 'radius'))
    if not radius or radius <= 0 or radius > MAX_DELETE_RADIUS then
        return Notify(source, locale('notify.invalid_radius', MAX_DELETE_RADIUS), 'error')
    end

    TriggerClientEvent('butter_admin:client:deleteArea', source, areaType, radius)
    CreateLog(source, 'Delete Area', ('Deleted %s within %sm'):format(areaType, radius), json.encode({ type = areaType, radius = radius }))
end)

RegisterNetEvent('butter_admin:server:announce', function(payload)
    local source = source
    if not IsAuthorized(source, 'announce', 'Sent an announcement without permission') then return end

    local message = SanitizeString(ReadField(payload, 'message'), 256)
    if not message then return Notify(source, locale('notify.invalid_message'), 'error') end

    SendChatMessage(-1, locale('info.announcement'), message, { 255, 0, 0 })
    CreateLog(source, 'Announcement', message)
end)

---@param source number
---@param active boolean
local function setBlipReceiver(source, active)
    local registered = blipReceivers[source] ~= nil
    if active and not registered then
        blipReceivers[source] = true
        blipReceiverCount += 1
    elseif not active and registered then
        blipReceivers[source] = nil
        blipReceiverCount -= 1
    end
end

---@return table[]
local function buildBlipList()
    local list = {}
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        local ped = GetPlayerPed(target)
        local isStaff = IsStaff(target)
        -- The noclip flag is client-written, so only staff may hide behind it.
        if ped ~= 0 and not (isStaff and Player(target).state.noclip) then
            local coords = GetEntityCoords(ped)
            list[#list + 1] = {
                serverId = target,
                name = GetPlayerName(target),
                -- One decimal is well below blip resolution and keeps the payload small.
                coords = { x = math.floor(coords.x * 10) / 10, y = math.floor(coords.y * 10) / 10, z = math.floor(coords.z * 10) / 10 },
                isStaff = isStaff,
            }
        end
    end
    return list
end

--- Broadcasts positions only while at least one admin has blips enabled.
local function startBlipLoop()
    if blipLoopRunning then return end
    blipLoopRunning = true

    CreateThread(function()
        while blipReceiverCount > 0 do
            Wait(BLIPS_INTERVAL)
            local list = buildBlipList()
            for receiver in pairs(blipReceivers) do
                TriggerClientEvent('butter_admin:client:updatePlayerBlips', receiver, list)
            end
        end
        blipLoopRunning = false
    end)
end

RegisterNetEvent('butter_admin:server:setBlipsEnabled', function(enabled)
    local source = source
    if not enabled then return setBlipReceiver(source, false) end
    if not IsAuthorized(source, 'toggleblips', 'Enabled player blips without permission') then return end

    setBlipReceiver(source, true)
    -- Push a snapshot now instead of making the toggle wait for the next tick.
    TriggerClientEvent('butter_admin:client:updatePlayerBlips', source, buildBlipList())
    startBlipLoop()
end)

AddEventHandler('playerDropped', function()
    setBlipReceiver(source, false)
end)


-- The Laser Tool fixes vehicles for every client, since the owner may be anyone.
RegisterNetEvent('butter_admin:server:fixVehicleForAll', function(netId)
    local source = source
    if not IsAuthorizedAny(source, { 'devmode', 'fixVehicle' }, 'Fixed a vehicle without permission') then return end

    netId = tonumber(netId)
    if not netId or netId <= 0 then return end

    TriggerClientEvent('butter_admin:client:repairNetworkedVehicle', -1, netId)
    CreateLog(source, 'Laser Tool', 'Fixed a vehicle via the Laser Tool', json.encode({ netId = netId }))
end)

-- Laser Tool actions act client-side; this keeps them in the audit log.
RegisterNetEvent('butter_admin:server:logLaserAction', function(description, data)
    local source = source
    if not IsAuthorized(source, 'devmode') then return end

    description = SanitizeString(description, 128)
    if not description then return end
    CreateLog(source, 'Laser Tool', description, type(data) == 'table' and json.encode(data) or '')
end)
