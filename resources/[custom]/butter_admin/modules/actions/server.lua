--- Per-player toggle state keyed by server ID, so a reconnect starts clean.
local toggles = { freeze = {}, godmode = {}, invisible = {}, stamina = {}, ammo = {} }

AddEventHandler('playerDropped', function()
    for _, states in pairs(toggles) do states[source] = nil end
end)

---@param source number
local function notifyInvalidPlayer(source)
    Notify(source, locale('notify.invalid_player'), 'error')
end

--- Clears death and needs metadata so a client-side revive sticks.
---@param target number
---@param revive boolean also clear the dead/last-stand flags
local function restoreNeeds(target, revive)
    if revive then
        SetPlayerMetadata(target, 'isdead', false)
        SetPlayerMetadata(target, 'inlaststand', false)
    end
    SetPlayerMetadata(target, 'hunger', 100)
    SetPlayerMetadata(target, 'thirst', 100)
end

---@param target number
local function revivePlayer(target)
    restoreNeeds(target, true)
    TriggerClientEvent('butter_admin:client:revivePlayer', target)
end

--- Registers a "do something to a target" command with the standard checks and log.
---@param eventName string
---@param options { permissions: string|string[], logType: string, logFormat: string, selfDefault?: boolean, run: fun(source: number, target: number, targetName: string, payload: any): boolean? }
local function registerTargetAction(eventName, options)
    local permissions = type(options.permissions) == 'table' and options.permissions or { options.permissions }

    RegisterNetEvent(eventName, function(payload)
        local source = source
        if not IsAuthorizedAny(source, permissions, ('Used %s without permission'):format(options.logType)) then return end

        local target = ResolvePayloadTarget(payload, options.selfDefault and source or nil)
        if not target then return notifyInvalidPlayer(source) end

        local targetName = GetPlayerName(target)
        if options.run(source, target, targetName, payload) == false then return end
        CreateLog(source, options.logType, options.logFormat:format(targetName), json.encode({ target = target }))
    end)
end

--- Registers a server-authoritative on/off state applied on the target's client.
---@param eventName string
---@param options { permission: string, kind: string, clientEvent: string, notifyKey: string, onKey: string, offKey: string, logType: string, selfDefault: boolean }
local function registerToggle(eventName, options)
    RegisterNetEvent(eventName, function(payload)
        local source = source
        if not IsAuthorized(source, options.permission, ('Toggled %s without permission'):format(options.logType)) then return end

        local target = ResolvePayloadTarget(payload, options.selfDefault and source or nil)
        if not target then return notifyInvalidPlayer(source) end

        local states = toggles[options.kind]
        local enabled = not states[target]
        states[target] = enabled or nil

        local targetName = GetPlayerName(target)
        TriggerClientEvent(options.clientEvent, target, enabled)
        Notify(source, locale(options.notifyKey, locale(enabled and options.onKey or options.offKey), targetName), enabled and 'success' or 'error')
        CreateLog(source, options.logType, ('%s %s for %s'):format(enabled and 'Enabled' or 'Disabled', options.logType:lower(), targetName),
            json.encode({ target = target, status = enabled }))
    end)
end

registerToggle('butter_admin:server:toggleFreeze', {
    permission = 'freezeplayer', kind = 'freeze', clientEvent = 'butter_admin:client:setFrozen',
    notifyKey = 'notify.success_freeze', onKey = 'commands.enabled', offKey = 'commands.disabled',
    logType = 'Freeze Player', selfDefault = false,
})

registerToggle('butter_admin:server:toggleInfiniteAmmo', {
    permission = 'infammo', kind = 'ammo', clientEvent = 'butter_admin:client:setInfiniteAmmo',
    notifyKey = 'notify.success_ammo', onKey = 'commands.enabled', offKey = 'commands.disabled',
    logType = 'Infinite Ammo', selfDefault = true,
})

registerToggle('butter_admin:server:toggleInfiniteStamina', {
    permission = 'infstamina', kind = 'stamina', clientEvent = 'butter_admin:client:setInfiniteStamina',
    notifyKey = 'notify.success_stamina', onKey = 'commands.enabled', offKey = 'commands.disabled',
    logType = 'Infinite Stamina', selfDefault = true,
})

registerToggle('butter_admin:server:toggleInvisible', {
    permission = 'invisible', kind = 'invisible', clientEvent = 'butter_admin:client:setInvisible',
    notifyKey = 'notify.success_cloak', onKey = 'commands.enabled', offKey = 'commands.disabled',
    logType = 'Invisible', selfDefault = true,
})

registerToggle('butter_admin:server:toggleGodmode', {
    permission = 'godmode', kind = 'godmode', clientEvent = 'butter_admin:client:setGodmode',
    notifyKey = 'notify.godmode', onKey = 'commands.enabled', offKey = 'commands.disabled',
    logType = 'Godmode', selfDefault = true,
})

registerTargetAction('butter_admin:server:killPlayer', {
    permissions = { 'kill', 'killplayer' },
    logType = 'Kill Player',
    logFormat = 'Killed player %s',
    run = function(source, target, targetName)
        TriggerClientEvent('butter_admin:client:killPlayer', target)
        Notify(source, locale('notify.success_killed', targetName), 'success')
    end,
})

registerTargetAction('butter_admin:server:revivePlayer', {
    permissions = { 'revive', 'reviveplayer' },
    logType = 'Revive Player',
    logFormat = 'Revived player %s',
    run = function(source, target, targetName)
        revivePlayer(target)
        Notify(source, locale('notify.success_revive', targetName), 'success')
    end,
})

registerTargetAction('butter_admin:server:healPlayer', {
    permissions = { 'heal', 'healplayer', 'revive', 'reviveplayer' },
    logType = 'Heal Player',
    logFormat = 'Healed player %s',
    run = function(source, target)
        restoreNeeds(target, false)
        TriggerClientEvent('butter_admin:client:healPlayer', target)
        Notify(source, locale('notify.success_healed'), 'success')
    end,
})

registerTargetAction('butter_admin:server:restoreNeeds', {
    permissions = 'food-drink',
    logType = 'Set Needs',
    logFormat = 'Set food & drink to 100 for %s',
    run = function(source, target)
        if not GetPlayer(target) then
            notifyInvalidPlayer(source)
            return false
        end
        restoreNeeds(target, false)
        TriggerClientEvent('hud:client:UpdateNeeds', target, 100, 100)
        SavePlayer(target)
        Notify(source, locale('info.gave_needs'), 'success')
    end,
})

registerTargetAction('butter_admin:server:removeStress', {
    permissions = 'removestress',
    logType = 'Remove Stress',
    logFormat = 'Removed stress for %s',
    run = function(source, target)
        if not GetPlayer(target) then
            notifyInvalidPlayer(source)
            return false
        end
        SetPlayerMetadata(target, 'stress', 0)
        TriggerClientEvent('hud:client:UpdateStress', target, 0)
        SavePlayer(target)
        Notify(source, locale('info.removed_stress'), 'success')
    end,
})

registerTargetAction('butter_admin:server:setArmor', {
    permissions = 'givearmor',
    logType = 'Set Armor',
    logFormat = 'Set armor to 100 for %s',
    run = function(source, target)
        SetPedArmour(GetPlayerPed(target), 100)
        Notify(source, locale('info.gave_armor'), 'success')
    end,
})

registerTargetAction('butter_admin:server:resetSkin', {
    permissions = 'resetskin',
    logType = 'Reset Skin',
    logFormat = 'Reset skin for %s',
    run = function(source, target, targetName)
        local playerData = GetPlayerData(target)
        if not playerData then
            notifyInvalidPlayer(source)
            return false
        end
        local model, skin = GetPlayerSavedSkin(playerData.citizenId)
        TriggerClientEvent('butter_admin:client:resetSkin', target, model, skin)
        Notify(source, locale('notify.success_skin', targetName), 'success')
    end,
})

registerTargetAction('butter_admin:server:openClothing', {
    permissions = 'openclothing',
    logType = 'Open Clothing',
    logFormat = 'Opened clothing menu for %s',
    run = function(source, target, targetName)
        TriggerClientEvent('butter_admin:client:openClothing', target)
        Notify(source, locale('notify.success_clothing', targetName), 'success')
    end,
})

RegisterNetEvent('butter_admin:server:selfArmor', function()
    local source = source
    if not IsAuthorized(source, 'selfarmour', 'Used Self Armour without permission') then return end

    SetPedArmour(GetPlayerPed(source), 100)
    Notify(source, locale('info.gave_armor'), 'success')
    CreateLog(source, 'Self Armour', 'Set self armor to 100', json.encode({ target = source }))
end)

RegisterNetEvent('butter_admin:server:selfRevive', function()
    local source = source
    if not IsAuthorized(source, 'selfrevive', 'Used Self Revive without permission') then return end

    revivePlayer(source)
    Notify(source, locale('notify.success_revive', GetPlayerName(source)), 'success')
    CreateLog(source, 'Self Revive', 'Revived self', json.encode({ target = source }))
end)

RegisterNetEvent('butter_admin:server:reviveAll', function()
    local source = source
    if not IsAuthorized(source, 'reviveAll', 'Revived all players without permission') then return end

    for _, playerId in ipairs(GetPlayers()) do revivePlayer(tonumber(playerId)) end
    Notify(source, locale('notify.success_revived_all'), 'success')
    CreateLog(source, 'Revive All', 'Revived all players')
end)

RegisterNetEvent('butter_admin:server:reviveInRadius', function(payload)
    local source = source
    if not IsAuthorized(source, 'reviveradius', 'Revived players in radius without permission') then return end

    local origin = GetEntityCoords(GetPlayerPed(source))
    local radius = ClampNumber(ReadField(payload, 'radius'), 0.1, 1000.0, 5.0)

    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        local ped = GetPlayerPed(target)
        if ped ~= 0 and #(GetEntityCoords(ped) - origin) <= radius then revivePlayer(target) end
    end
    Notify(source, locale('notify.success_revived_radius', radius), 'success')
    CreateLog(source, 'Revive Radius', ('Revived players within %sm'):format(radius), json.encode({ radius = radius }))
end)

RegisterNetEvent('butter_admin:server:setModel', function(payload)
    local source = source
    if not IsAuthorized(source, 'changeped', 'Changed a model without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target then return notifyInvalidPlayer(source) end

    local model = SanitizeString(ReadField(payload, 'model'), 64)
    if not model then return Notify(source, locale('objects.invalid_model', '?'), 'error') end

    local targetName = GetPlayerName(target)
    TriggerClientEvent('butter_admin:client:setModel', target, joaat(model))
    Notify(source, locale('notify.success_model', targetName, model), 'success')
    CreateLog(source, 'Set Model', ('Set model of %s to %s'):format(targetName, model), json.encode({ target = target, model = model }))
end)

---@param moneyType any
---@return string?
local function readMoneyType(moneyType)
    if type(moneyType) ~= 'string' then return nil end
    for _, allowed in ipairs(GetMoneyTypes()) do
        if allowed == moneyType then return moneyType end
    end
end

---@param eventName string
---@param options { permission: string, setter: fun(source: number, moneyType: string, amount: number, reason: string): boolean, allowZero: boolean, message: fun(amount: number, moneyType: string, targetName: string): string, logType: string, verb: string }
local function registerMoneyAction(eventName, options)
    RegisterNetEvent(eventName, function(payload)
        local source = source
        if not IsAuthorized(source, options.permission, ('Used %s without permission'):format(options.logType)) then return end

        local target = ResolvePayloadTarget(payload)
        if not target or not GetPlayer(target) then return notifyInvalidPlayer(source) end

        local moneyType = readMoneyType(ReadField(payload, 'moneytype'))
        local amount = SanitizeAmount(ReadField(payload, 'amount'))
        if not moneyType or not amount or (not options.allowZero and amount <= 0) then
            return Notify(source, locale('notify.invalid_amount'), 'error')
        end

        if not options.setter(target, moneyType, amount, 'butter_admin-' .. options.logType:gsub('%s', '-')) then
            return Notify(source, locale('notify.invalid_amount'), 'error')
        end

        local targetName = GetPlayerName(target)
        Notify(source, options.message(amount, moneyType, targetName), 'success')
        CreateLog(source, options.logType, ('%s %s %s to %s'):format(options.verb, amount, moneyType, targetName),
            json.encode({ target = target, type = moneyType, amount = amount }))
    end)
end

registerMoneyAction('butter_admin:server:setMoney', {
    permission = 'setmoney', setter = SetMoney, allowZero = true,
    logType = 'Set Money', verb = 'Set',
    message = function(amount, moneyType, targetName)
        return locale('notify.success_set_money', targetName, moneyType, amount)
    end,
})

registerMoneyAction('butter_admin:server:giveMoney', {
    permission = 'givemoney', setter = AddMoney, allowZero = false,
    logType = 'Give Money', verb = 'Gave',
    message = function(amount, moneyType, targetName)
        return locale('notify.success_gave_money', amount, moneyType, targetName)
    end,
})

RegisterNetEvent('butter_admin:server:giveItem', function(payload)
    local source = source
    if not IsAuthorized(source, 'giveitem', 'Gave an item without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target or not GetPlayer(target) then return notifyInvalidPlayer(source) end
    if not AddItem then return Notify(source, locale('notify.inventory_bridge_unavailable'), 'error') end

    local item = SanitizeString(ReadField(payload, 'item'), 64)
    local amount = SanitizeAmount(ReadField(payload, 'amount'))
    if not item then return Notify(source, locale('notify.invalid_item'), 'error') end
    if not amount or amount <= 0 then return Notify(source, locale('notify.invalid_amount'), 'error') end

    if not AddItem(target, item, amount) then return Notify(source, locale('notify.invalid_item'), 'error') end

    local targetName = GetPlayerName(target)
    Notify(source, locale('notify.success_gave_item', amount, item, targetName), 'success')
    CreateLog(source, 'Give Item', ('Gave %sx %s to %s'):format(amount, item, targetName),
        json.encode({ target = target, item = item, amount = amount }))
end)

RegisterNetEvent('butter_admin:server:clearInventory', function(payload)
    local source = source
    if not IsAuthorized(source, 'clearinventory', 'Cleared an inventory without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target or not GetPlayer(target) then return notifyInvalidPlayer(source) end
    if not ClearInventory then return Notify(source, locale('notify.inventory_bridge_unavailable'), 'error') end

    ClearInventory(target)
    local targetName = GetPlayerName(target)
    Notify(source, locale('notify.success_cleared_inventory', targetName), 'success')
    CreateLog(source, 'Clear Inventory', ('Cleared inventory of %s'):format(targetName), json.encode({ target = target }))
end)

---@param eventName string
---@param field 'job'|'gang'
---@param permission string
local function registerFactionAction(eventName, field, permission)
    local label = field == 'job' and 'Job' or 'Gang'
    local setter = field == 'job' and SetJob or SetGang

    RegisterNetEvent(eventName, function(payload)
        local source = source
        if not IsAuthorized(source, permission, ('Set a %s without permission'):format(field)) then return end

        local target = ResolvePayloadTarget(payload)
        if not target or not GetPlayer(target) then return notifyInvalidPlayer(source) end

        local name = SanitizeString(ReadField(payload, field), 64)
        if not name then return end
        local grade = math.floor(ClampNumber(ReadField(payload, 'rank'), 0, 100, 0))

        setter(target, name, grade)
        Notify(source, locale('info.set' .. field, name), 'success')
        CreateLog(source, 'Set ' .. label, ('Set %s of %s to %s (Grade %s)'):format(field, GetPlayerName(target), name, grade),
            json.encode({ target = target, [field] = name, grade = grade }))
    end)
end

registerFactionAction('butter_admin:server:setJob', 'job', 'giveJob')
registerFactionAction('butter_admin:server:setGang', 'gang', 'setgang')

RegisterNetEvent('butter_admin:server:toggleJobDuty', function()
    local source = source
    if not IsAuthorized(source, 'togglejobduty', 'Toggled job duty without permission') then return end

    local onDuty = ToggleJobDuty(source)
    if onDuty == nil then return Notify(source, locale('notify.no_job_duty'), 'error') end

    local status = onDuty and 'ON' or 'OFF'
    Notify(source, locale('notify.job_duty_toggled', status), 'success')
    CreateLog(source, 'Toggle Job Duty', ('Toggled own job duty (%s)'):format(status), json.encode({ target = source, status = status }))
end)

RegisterNetEvent('butter_admin:server:openInventory', function(payload)
    local source = source
    if not IsAuthorized(source, 'openinventory', 'Opened an inventory without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target then return notifyInvalidPlayer(source) end
    if not OpenInventory then return Notify(source, locale('notify.inventory_bridge_unavailable'), 'error') end

    OpenInventory(source, target)
    local targetName = GetPlayerName(target)
    Notify(source, locale('notify.success_inventory', targetName), 'success')
    CreateLog(source, 'Open Inventory', ('Opened inventory of %s'):format(targetName), json.encode({ target = target }))
end)

RegisterNetEvent('butter_admin:server:openStash', function(payload)
    local source = source
    if not IsAuthorized(source, 'openstash', 'Opened a stash without permission') then return end

    local stashId = SanitizeString(ReadField(payload, 'stashid'), 100)
    if not stashId then return Notify(source, locale('notify.invalid_stash_id'), 'error') end
    if not OpenInventory then return Notify(source, locale('notify.inventory_bridge_unavailable'), 'error') end

    OpenInventory(source, 'stash:' .. stashId)
    Notify(source, locale('notify.success_stash', stashId), 'success')
    CreateLog(source, 'Open Stash', ('Opened stash: %s'):format(stashId), json.encode({ stash = stashId }))
end)

---@param plate any
---@return string?
local function readPlate(plate)
    if type(plate) ~= 'string' or plate == '' or #plate > 16 then return nil end
    return plate
end

-- Used when the inventory bridge can open vehicle inventories by plate (qb-inventory).
---@param vehicleType 'trunk'|'glovebox'
---@param permission string
local function registerVehicleInventory(vehicleType, permission)
    local label = vehicleType == 'trunk' and 'Trunk' or 'Glovebox'

    RegisterNetEvent(('butter_admin:server:open%s'):format(label), function(plate)
        local source = source
        if not IsAuthorized(source, permission, ('Opened a %s without permission'):format(vehicleType)) then return end

        plate = readPlate(plate)
        if not plate then return Notify(source, locale('notify.invalid_plate'), 'error') end
        if not OpenInventory then return Notify(source, locale('notify.inventory_bridge_unavailable'), 'error') end

        OpenInventory(source, vehicleType .. ':' .. plate)
        Notify(source, locale('notify.success_' .. vehicleType, plate), 'success')
        CreateLog(source, 'Open ' .. label, ('Opened %s for plate: %s'):format(vehicleType, plate), json.encode({ plate = plate }))
    end)
end

registerVehicleInventory('trunk', 'opentrunk')
registerVehicleInventory('glovebox', 'openglovebox')

-- ox_inventory only opens vehicle inventories for an existing vehicle, so the
-- client spawns a hidden one and hands over its net ID (see the ox bridge).
RegisterNetEvent('butter_admin:server:openVehicleInventory', function(vehicleType, plate, netId)
    local source = source
    if vehicleType ~= 'trunk' and vehicleType ~= 'glovebox' then return end
    if not IsAuthorized(source, vehicleType == 'trunk' and 'opentrunk' or 'openglovebox', 'Opened a vehicle inventory without permission') then return end

    plate, netId = readPlate(plate), tonumber(netId)
    if not plate or not netId or not OpenVehicleInventory then
        return Notify(source, locale('notify.invalid_vehicle_data'), 'error')
    end

    if not pcall(OpenVehicleInventory, source, vehicleType, netId) then
        return Notify(source, locale('notify.failed_open_inventory', vehicleType), 'error')
    end

    local label = vehicleType == 'trunk' and 'Trunk' or 'Glovebox'
    Notify(source, locale('notify.opened_vehicle_inventory', label, plate), 'success')
    CreateLog(source, 'Open ' .. label, ('Opened %s for plate: %s'):format(vehicleType, plate), json.encode({ plate = plate }))
end)

lib.callback.register('butter_admin:server:getVehicleModel', function(source, plate)
    if not IsAuthorizedAny(source, { 'opentrunk', 'openglovebox' }) or not IsValidPlate(plate) then return 'sultan' end

    local model = GetVehicleModel(plate)
    if type(model) == 'string' and model:sub(1, 1) == '{' then model = DecodeJson(model, {}).model end
    return model or 'sultan'
end)

RegisterNetEvent('butter_admin:server:playerInfo', function(payload)
    local source = source
    if not IsAuthorized(source, 'playerinfo', 'Viewed player info without permission') then return end

    local target = ResolvePayloadTarget(payload)
    local playerData = target and GetPlayerData(target)
    if not playerData then return notifyInvalidPlayer(source) end

    local function gradeName(grade)
        if type(grade) == 'table' then return grade.name or grade.level end
        return grade
    end

    local job = playerData.job or {}
    local gang = playerData.gang
    local gangGrade = gang and gradeName(gang.grade)
    local characterName = GetCharacterName(playerData)

    TriggerClientEvent('butter_admin:client:showPlayerInfo', source, {
        ServerId = target,
        CitizenId = playerData.citizenId or 'N/A',
        Name = characterName ~= 'N/A' and characterName or GetPlayerName(target),
        Job = job.label or job.name or 'Unemployed',
        JobGrade = tostring(gradeName(job.grade) or 0),
        Gang = gang and (gang.label or gang.name) or 'None',
        GangGrade = gangGrade and tostring(gangGrade) or nil,
        Cash = math.floor(tonumber(playerData.money.cash) or 0),
        Bank = math.floor(tonumber(playerData.money.bank) or 0),
    })
end)
