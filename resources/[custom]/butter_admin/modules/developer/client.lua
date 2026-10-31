local NAME_SCAN_INTERVAL = 1000 -- ms between nearby-player scans
local LASER_RANGE = 250.0

local namesEnabled = false
local namesLoopRunning = false
local nearbyPlayers = {}
local characterNames = {} ---@type table<string, string>
local gamerTags = {} ---@type table<number, { tag: number, label: string }>
local displayOptions = { Name = true, Id = true, Health = true, Armor = true, Style = 'Butter', Source = 'Player' }

local blipsEnabled = false
local playerBlips = {} ---@type table<string, { blip: number, isStaff: boolean, label: string }>

local coordsEnabled = false

local laser = { enabled = false, locked = false, holdingKey = false, selected = nil }

local function refreshDisplayOptions()
    local options = GetPreference('options')
    local previousSource = displayOptions.Source

    displayOptions.Name = options.OverheadName ~= false
    displayOptions.Id = options.OverheadId ~= false
    displayOptions.Health = options.OverheadHealth ~= false
    displayOptions.Armor = options.OverheadArmor ~= false
    displayOptions.Style = options.OverheadStyle or 'Butter'
    displayOptions.Source = options.NameSource or 'Player'

    -- A different name source invalidates every cached name.
    if previousSource ~= displayOptions.Source then
        characterNames = {}
        nearbyPlayers = {}
    end
end

AddEventHandler('butter_admin:client:optionsChanged', refreshDisplayOptions)

local function clearGamerTags()
    for _, data in pairs(gamerTags) do
        if IsMpGamerTagActive(data.tag) then RemoveMpGamerTag(data.tag) end
    end
    gamerTags = {}
end

---@param serverId number
local function removeGamerTag(serverId)
    local data = gamerTags[serverId]
    if not data then return end
    if IsMpGamerTagActive(data.tag) then RemoveMpGamerTag(data.tag) end
    gamerTags[serverId] = nil
end

--- Peds sharing a vehicle sit on top of each other, so their labels stack
--- above the roof in seat order.
---@param ped number
---@param pedCoords vector3
---@return vector3
local function getLabelCoords(ped, pedCoords)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return vector3(pedCoords.x, pedCoords.y, pedCoords.z + 1.1) end

    local order = 0
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local occupant = GetPedInVehicleSeat(vehicle, seat)
        if occupant == ped then break end
        if occupant ~= 0 then order += 1 end
    end

    local spacing = (displayOptions.Health or displayOptions.Armor) and 0.45 or 0.32
    local vehicleCoords = GetEntityCoords(vehicle)
    local _, max = GetModelDimensions(GetEntityModel(vehicle))
    return vector3(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + max.z + 0.4 + order * spacing)
end

---@param coords vector3
---@param target table
---@param displayName string
---@param distance number
local function drawClassicLabel(coords, target, displayName, distance)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end

    local text = ''
    if displayOptions.Id then text = ('[%s] '):format(target.serverId) end
    if displayOptions.Name then text = text .. displayName end

    if displayOptions.Health or displayOptions.Armor then
        local maxHealth = GetEntityMaxHealth(target.ped) - 100
        local health = math.max(0, GetEntityHealth(target.ped) - 100) / (maxHealth > 0 and maxHealth or 100) * 100
        text = text .. '\n'
        if displayOptions.Health then text = text .. ('%s: %d%% '):format(locale('commands.health'), math.floor(health)) end
        if displayOptions.Armor then text = text .. ('%s: %d%%'):format(locale('commands.armor'), GetPedArmour(target.ped)) end
    end

    local settings = Config.PlayerNames
    local scale = settings.NameScale
    local t = math.max(0.0, math.min(1.0, distance / scale.MaxDistance))
    local size = scale.Near + (scale.Far - scale.Near) * t
    local color = settings.NameColor

    SetTextScale(size, size)
    SetTextFont(0)
    SetTextProportional(true)
    SetTextColour(color.r, color.g, color.b, 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

---@param target table
---@param label string
local function drawTxLabel(target, label)
    local data = gamerTags[target.serverId]
    if not data or not IsMpGamerTagActive(data.tag) or data.label ~= label then
        removeGamerTag(target.serverId)
        data = { tag = CreateFakeMpGamerTag(target.ped, label, false, false, '', 0), label = label }
        gamerTags[target.serverId] = data
    end

    local talking = NetworkIsPlayerTalking(target.playerId)
    SetMpGamerTagVisibility(data.tag, 0, true)
    SetMpGamerTagVisibility(data.tag, 2, displayOptions.Health or displayOptions.Armor)
    SetMpGamerTagAlpha(data.tag, 2, 255)
    SetMpGamerTagVisibility(data.tag, 4, talking)
    if talking then SetMpGamerTagColour(data.tag, 4, 12) end
    SetMpGamerTagVisibility(data.tag, 6, GetPlayerInvincible(target.playerId))
end

--- Finds nearby players once a second and fetches character names when needed.
local function runNameScanLoop()
    local range = Config.PlayerNames.Range

    CreateThread(function()
        while namesEnabled do
            local found, missingNames = {}, {}
            local myCoords = GetEntityCoords(cache.ped)

            for _, player in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(player)
                if player ~= cache.playerId and DoesEntityExist(ped) and #(myCoords - GetEntityCoords(ped)) < range then
                    local serverId = GetPlayerServerId(player)
                    found[#found + 1] = { serverId = serverId, playerId = player, ped = ped, name = GetPlayerName(player) or ('Player %s'):format(serverId) }
                    if displayOptions.Source == 'Character' and not characterNames[tostring(serverId)] then
                        missingNames[#missingNames + 1] = serverId
                    end
                end
            end

            -- Published first so labels draw with player names until character names arrive.
            nearbyPlayers = found
            if #missingNames > 0 then
                for serverId, name in pairs(lib.callback.await('butter_admin:server:getCharacterNames', false, missingNames) or {}) do
                    characterNames[serverId] = name
                end
            end
            Wait(NAME_SCAN_INTERVAL)
        end

        nearbyPlayers, characterNames = {}, {}
        clearGamerTags()
        namesLoopRunning = false
    end)
end

local function runNameDrawLoop()
    local range = Config.PlayerNames.Range

    CreateThread(function()
        while namesEnabled do
            if #nearbyPlayers == 0 then
                clearGamerTags()
                Wait(500)
            else
                local myCoords = GetEntityCoords(cache.ped)
                local useGamerTags = displayOptions.Style == 'TX'
                if not useGamerTags then clearGamerTags() end

                for _, target in ipairs(nearbyPlayers) do
                    if DoesEntityExist(target.ped) then
                        local pedCoords = GetEntityCoords(target.ped)
                        local distance = #(myCoords - pedCoords)

                        if distance < range then
                            local labelCoords = getLabelCoords(target.ped, pedCoords)
                            if Config.PlayerNames.ShowLines then
                                local color = Config.PlayerNames.LineColor
                                DrawLine(myCoords.x, myCoords.y, myCoords.z, labelCoords.x, labelCoords.y, labelCoords.z, color.r, color.g, color.b, 255)
                            end

                            local displayName = displayOptions.Source == 'Character' and characterNames[tostring(target.serverId)] or target.name
                            if useGamerTags then
                                local label = (displayOptions.Id and ('[%s] '):format(target.serverId) or '') .. (displayOptions.Name and displayName or '')
                                drawTxLabel(target, label)
                            else
                                drawClassicLabel(labelCoords, target, displayName, distance)
                            end
                        else
                            removeGamerTag(target.serverId)
                        end
                    end
                end
                Wait(0)
            end
        end
    end)
end

AddEventHandler('butter_admin:client:togglePlayerNames', function()
    namesEnabled = not namesEnabled
    SendNuiAction('setItemEnabled', { Name = 'togglenames', State = namesEnabled })
    Notify(locale(namesEnabled and 'notify.playernames_enabled' or 'notify.playernames_disabled'), 'inform')

    if not namesEnabled then return clearGamerTags() end
    refreshDisplayOptions()
    if namesLoopRunning then return end
    namesLoopRunning = true
    runNameScanLoop()
    runNameDrawLoop()
end)

local COORD_FORMATS = {
    ['vector3(0.0, 0.0, 0.0)'] = 'vector3(%s, %s, %s)',
    ['vector4(0.0, 0.0, 0.0, 0.0)'] = 'vector4(%s, %s, %s, %s)',
    ['0.0, 0.0, 0.0'] = '%s, %s, %s',
    ['0.0, 0.0, 0.0, 0.0'] = '%s, %s, %s, %s',
    ['X = 0.0, Y = 0.0, Z = 0.0'] = 'X = %s, Y = %s, Z = %s',
    ['x = 0.0, y = 0.0, z = 0.0'] = 'x = %s, y = %s, z = %s',
    ['X = 0.0, Y = 0.0, Z = 0.0, H = 0.0'] = 'X = %s, Y = %s, Z = %s, H = %s',
    ['x = 0.0, y = 0.0, z = 0.0, h = 0.0'] = 'x = %s, y = %s, z = %s, h = %s',
    ['["X"] = 0.0, ["Y"] = 0.0, ["Z"] = 0.0'] = '["X"] = %s, ["Y"] = %s, ["Z"] = %s',
    ['["x"] = 0.0, ["y"] = 0.0, ["z"] = 0.0'] = '["x"] = %s, ["y"] = %s, ["z"] = %s',
    ['["X"] = 0.0, ["Y"] = 0.0, ["Z"] = 0.0, ["H"] = 0.0'] = '["X"] = %s, ["Y"] = %s, ["Z"] = %s, ["H"] = %s',
    ['["x"] = 0.0, ["y"] = 0.0, ["z"] = 0.0, ["h"] = 0.0'] = '["x"] = %s, ["y"] = %s, ["z"] = %s, ["h"] = %s',
}

---@return number x, number y, number z, number heading
local function getRoundedPosition()
    local coords = GetEntityCoords(cache.ped)
    return RoundTo(coords.x, 4), RoundTo(coords.y, 4), RoundTo(coords.z, 4), RoundTo(GetEntityHeading(cache.ped), 4)
end

AddEventHandler('butter_admin:client:copyCoords', function(options)
    local format = COORD_FORMATS[type(options) == 'table' and options.type] or COORD_FORMATS['vector4(0.0, 0.0, 0.0, 0.0)']
    CopyToClipboard(format:format(getRoundedPosition()))
    Notify(locale('notify.coords_format_copied'), 'inform')
end)

AddEventHandler('butter_admin:client:toggleCoords', function()
    coordsEnabled = not coordsEnabled
    SendNuiAction('setItemEnabled', { Name = 'showCoords', State = coordsEnabled })
    if not coordsEnabled then return SendNuiAction('coordsUpdate', { visible = false }) end

    CreateThread(function()
        local lastText
        while coordsEnabled do
            local x, y, z, heading = getRoundedPosition()
            local vec3 = ('vec3(%s, %s, %s)'):format(x, y, z)
            local vec4 = ('vec4(%s, %s, %s, %s)'):format(x, y, z, heading)
            local headingText = tostring(heading)

            -- Only changed positions are sent, to keep NUI messages down.
            local text = vec4
            if text ~= lastText then
                SendNuiAction('coordsUpdate', { visible = true, vec3 = vec3, vec4 = vec4, heading = headingText })
                lastText = text
            end

            if IsControlJustPressed(0, 38) then
                CopyToClipboard(vec3)
                Notify(locale('notify.coords_vec3_copied'), 'inform')
            elseif IsControlJustPressed(0, 47) then
                CopyToClipboard(vec4)
                Notify(locale('notify.coords_vec4_copied'), 'inform')
            elseif IsControlJustPressed(0, 74) then
                CopyToClipboard(headingText)
                Notify(locale('notify.heading_copied'), 'inform')
            end
            Wait(0)
        end
    end)
end)

---@param vehicle number
---@return boolean
local function hasPlayerOccupant(vehicle)
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local occupant = GetPedInVehicleSeat(vehicle, seat)
        if occupant ~= 0 and IsPedAPlayer(occupant) then return true end
    end
    return false
end

---@param origin vector3
---@param radius number
---@return number deleted
local function deleteVehiclesInRadius(origin, radius)
    local targets = {}
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        -- Other players' cars are left alone.
        if not hasPlayerOccupant(vehicle) and #(origin - GetEntityCoords(vehicle)) <= radius then
            targets[#targets + 1] = vehicle
            NetworkRequestControlOfEntity(vehicle)
        end
    end

    -- One shared wait for every control request.
    local deadline = GetGameTimer() + 1000
    local pending = true
    while pending and GetGameTimer() < deadline do
        pending = false
        for _, vehicle in ipairs(targets) do
            if DoesEntityExist(vehicle) and not NetworkHasControlOfEntity(vehicle) then
                pending = true
                break
            end
        end
        if pending then Wait(0) end
    end

    local deleted = 0
    for _, vehicle in ipairs(targets) do
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteEntity(vehicle)
        if not DoesEntityExist(vehicle) then deleted += 1 end
    end
    return deleted
end

---@param pool string
---@param origin vector3
---@param radius number
---@param filter? fun(entity: number): boolean
---@return number deleted
local function deleteFromPool(pool, origin, radius, filter)
    local deleted = 0
    for _, entity in ipairs(GetGamePool(pool)) do
        if (not filter or filter(entity)) and #(origin - GetEntityCoords(entity)) <= radius then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
            deleted += 1
        end
    end
    return deleted
end

RegisterNetEvent('butter_admin:client:deleteArea', function(areaType, radius)
    local origin = GetEntityCoords(cache.ped)
    local deleted = 0

    if areaType == 'all' or areaType == 'vehicles' then deleted += deleteVehiclesInRadius(origin, radius) end
    if areaType == 'all' or areaType == 'peds' then
        deleted += deleteFromPool('CPed', origin, radius, function(ped) return not IsPedAPlayer(ped) end)
    end
    if areaType == 'all' or areaType == 'objects' then deleted += deleteFromPool('CObject', origin, radius) end

    Notify(locale('notify.deleted_entities_radius', deleted, radius, areaType), 'success')
end)

AddEventHandler('butter_admin:client:toggleBlips', function()
    blipsEnabled = not blipsEnabled
    SendNuiAction('setItemEnabled', { Name = 'toggleblips', State = blipsEnabled })
    Notify(locale(blipsEnabled and 'notify.playerblips_enabled' or 'notify.playerblips_disabled'), blipsEnabled and 'success' or 'error')
    TriggerServerEvent('butter_admin:server:setBlipsEnabled', blipsEnabled)

    if blipsEnabled then return end
    for _, data in pairs(playerBlips) do
        if DoesBlipExist(data.blip) then RemoveBlip(data.blip) end
    end
    playerBlips = {}
end)

---@param blip number
---@param settings table
---@param label string
local function styleBlip(blip, settings, label)
    SetBlipSprite(blip, settings.Sprite)
    SetBlipColour(blip, settings.Color)
    SetBlipScale(blip, settings.Scale)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

RegisterNetEvent('butter_admin:client:updatePlayerBlips', function(players)
    if not blipsEnabled then return end

    local seen = {}
    for _, player in ipairs(players) do
        if player.serverId ~= cache.serverId then
            local key = tostring(player.serverId)
            local settings = player.isStaff and Config.Blips.Staff or Config.Blips.Player
            local label = ('%s[%s]'):format(settings.LabelPrefix, player.serverId)
            if settings.ShowName then label = label .. ' ' .. player.name end
            seen[key] = true

            local data = playerBlips[key]
            if not data or not DoesBlipExist(data.blip) then
                local blip = AddBlipForCoord(player.coords.x, player.coords.y, player.coords.z)
                styleBlip(blip, settings, label)
                playerBlips[key] = { blip = blip, isStaff = player.isStaff, label = label }
            else
                SetBlipCoords(data.blip, player.coords.x, player.coords.y, player.coords.z)
                if data.isStaff ~= player.isStaff or data.label ~= label then
                    styleBlip(data.blip, settings, label)
                    data.isStaff, data.label = player.isStaff, label
                end
            end
        end
    end

    for key, data in pairs(playerBlips) do
        if not seen[key] then
            if DoesBlipExist(data.blip) then RemoveBlip(data.blip) end
            playerBlips[key] = nil
        end
    end
end)

RegisterNetEvent('butter_admin:client:repairNetworkedVehicle', function(netId)
    if type(netId) ~= 'number' or not NetworkDoesNetworkIdExist(netId) then return end
    local vehicle = NetToVeh(netId)
    if not DoesEntityExist(vehicle) then return end

    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleDirtLevel(vehicle, 0.0)
end)

---@param entity number
---@return string
local function getEntityTypeName(entity)
    local entityType = GetEntityType(entity)
    if entityType == 1 then return 'Ped' end
    if entityType == 2 then return 'Vehicle' end
    if entityType == 3 then return 'Object' end
    return 'Unknown'
end

---@param entity number
---@return string
local function getEntityLabel(entity)
    local entityType = GetEntityType(entity)
    if entityType == 2 then return GetDisplayNameFromVehicleModel(GetEntityModel(entity)):lower() end
    if entityType == 1 then return IsPedAPlayer(entity) and 'Player' or 'NPC' end

    local ok, archetype = pcall(GetEntityArchetypeName, entity)
    if ok and archetype and archetype ~= '' then return archetype end
    return ('Object (%s)'):format(GetEntityModel(entity))
end

---@param entity number
---@return table
local function buildEntityData(entity)
    local coords = GetEntityCoords(entity)
    local data = {
        type = getEntityTypeName(entity),
        model = GetEntityModel(entity),
        label = getEntityLabel(entity),
        heading = RoundTo(GetEntityHeading(entity), 2),
        coords = { x = RoundTo(coords.x, 2), y = RoundTo(coords.y, 2), z = RoundTo(coords.z, 2) },
    }

    if GetEntityType(entity) == 1 and IsPedAPlayer(entity) then
        local owner = NetworkGetEntityOwner(entity)
        data.playerName = GetPlayerName(owner) or 'Unknown'
        data.serverId = GetPlayerServerId(owner)
        data.steamId = ''
    end
    return data
end

---@param visible boolean
---@param entity? table
---@param coords? table
local function sendLaserUpdate(visible, entity, coords)
    SendNuiAction('laserUpdate', { visible = visible, entity = entity, coords = coords })
end

---@param entity number?
---@param enabled boolean
local function setOutline(entity, enabled)
    if entity and DoesEntityExist(entity) then
        local entityType = GetEntityType(entity)
        if entityType == 2 or entityType == 3 then pcall(SetEntityDrawOutline, entity, enabled) end
    end
end

--- Raycast from the gameplay camera along where the player is aiming.
---@return boolean hit, vector3 endCoords, number entity
local function raycastFromCamera()
    local rotation = GetGameplayCamRot(2)
    local origin = GetGameplayCamCoord()
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local direction = vector3(-math.sin(yaw) * math.abs(math.cos(pitch)), math.cos(yaw) * math.abs(math.cos(pitch)), math.sin(pitch))
    local destination = origin + direction * LASER_RANGE

    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    local ignore = vehicle ~= 0 and vehicle or cache.ped
    local handle = StartShapeTestRay(origin.x, origin.y, origin.z, destination.x, destination.y, destination.z, -1, ignore, 0)
    local _, hit, endCoords, _, entity = GetShapeTestResult(handle)
    return hit == true or hit == 1, endCoords, entity
end

local function runLaserLoop()
    CreateThread(function()
        local hovered, lastSent, lastUpdate = nil, -1, 0

        while laser.enabled and AdminState.devMode do
            if IsControlJustPressed(2, 194) then break end -- frontend back closes the laser
            local now = GetGameTimer()

            if laser.locked then
                -- Locked: the NUI has focus, unlock and close come through its callbacks.
                local entity = laser.selected and laser.selected.handle
                if entity and DoesEntityExist(entity) then
                    setOutline(entity, true)
                    if now - lastUpdate > 200 then
                        laser.selected.data = buildEntityData(entity)
                        sendLaserUpdate(true, laser.selected.data)
                        lastUpdate = now
                    end
                else
                    laser.locked, laser.selected = false, nil
                    SetNuiFocus(false, false)
                    if not laser.holdingKey then break end
                    sendLaserUpdate(true)
                end
            else
                local hit, endCoords, entity = raycastFromCamera()
                local isEntity = hit and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) >= 1 and GetEntityType(entity) <= 3

                if hit then
                    DrawMarker(28, endCoords.x, endCoords.y, endCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2, 0.2, 0, 187, 255, 200, false, false, 2, false, nil, nil, false)
                end

                if hovered ~= (isEntity and entity or nil) then
                    setOutline(hovered, false)
                    hovered = isEntity and entity or nil
                    setOutline(hovered, true)
                end

                if isEntity then
                    if entity ~= lastSent or now - lastUpdate > 100 then
                        sendLaserUpdate(true, buildEntityData(entity))
                        lastSent, lastUpdate = entity, now
                    end

                    if IsControlJustPressed(0, 38) then -- E locks the entity and shows the cursor
                        laser.locked = true
                        laser.selected = { handle = entity, data = buildEntityData(entity) }
                        sendLaserUpdate(true, laser.selected.data)
                        SetNuiFocus(true, true)
                    elseif IsControlJustPressed(0, 47) then -- G copies entity info
                        local coords = GetEntityCoords(entity)
                        CopyToClipboard(('Entity: %s | Model: %s | Coords: vec3(%s, %s, %s)'):format(
                            getEntityTypeName(entity), GetEntityModel(entity), RoundTo(coords.x, 3), RoundTo(coords.y, 3), RoundTo(coords.z, 3)))
                        Notify(locale('notify.entity_info_copied'), 'inform')
                    end
                elseif lastSent ~= -1 or now - lastUpdate > 100 then
                    sendLaserUpdate(true, nil, { x = endCoords.x, y = endCoords.y, z = endCoords.z })
                    lastSent, lastUpdate = -1, now
                end

                if hit and IsControlJustPressed(0, 74) then -- H copies the hit position
                    CopyToClipboard(('vec3(%s, %s, %s)'):format(RoundTo(endCoords.x, 3), RoundTo(endCoords.y, 3), RoundTo(endCoords.z, 3)))
                    Notify(locale('notify.coords_copied'), 'inform')
                end
            end

            Wait(0)
        end

        setOutline(hovered, false)
        setOutline(laser.selected and laser.selected.handle, false)
        laser.enabled, laser.locked, laser.holdingKey, laser.selected = false, false, false, nil
        sendLaserUpdate(false)
        SetNuiFocus(false, false)
    end)
end

RegisterCommand('+butter_admin_laser', function()
    if IsPauseMenuActive() or IsNuiFocused() or not AdminState.devMode then return end
    laser.holdingKey = true
    if laser.enabled then return end

    laser.enabled, laser.locked, laser.selected = true, false, nil
    sendLaserUpdate(true)
    runLaserLoop()
end, false)

RegisterCommand('-butter_admin_laser', function()
    laser.holdingKey = false
    if laser.enabled and laser.locked then return end
    laser.enabled = false
end, false)

RegisterKeyMapping('+butter_admin_laser', locale('info.laser_keymapping'), 'keyboard', 'L')

RegisterNUICallback('laserClose', function(_, cb)
    laser.enabled = false
    cb(true)
end)

RegisterNUICallback('laserUnlock', function(_, cb)
    laser.locked, laser.selected = false, nil
    SetNuiFocus(false, false)
    if laser.holdingKey then sendLaserUpdate(true) else laser.enabled = false end
    cb(true)
end)

RegisterNUICallback('laserCopy', function(data, cb)
    if data.text then
        CopyToClipboard(tostring(data.text))
        Notify(locale('notify.entity_info_copied'), 'inform')
    end
    cb(true)
end)

---@param description string
---@param data? table
local function logLaserAction(description, data)
    TriggerServerEvent('butter_admin:server:logLaserAction', description, data)
end

-- Another player's ped is owned by their client, so these go through the server.
local PLAYER_LASER_ACTIONS = {
    revive = { event = 'butter_admin:server:revivePlayer' },
    freeze = { event = 'butter_admin:server:toggleFreeze' },
    godmode = { event = 'butter_admin:server:toggleGodmode' },
    spectate = { event = 'butter_admin:server:startSpectate' },
    burn = { event = 'butter_admin:server:setOnFire' },
    kick = { event = 'butter_admin:server:kickPlayer', extra = { reason = 'Kicked by admin' } },
    bring = { event = 'butter_admin:server:teleportPlayer', extra = { type = 'Bring' } },
}

---@param entity number
local function setOnFireRepeatedly(entity)
    CreateThread(function()
        NetworkRequestControlOfEntity(entity)
        for _ = 1, 100 do
            if NetworkHasControlOfEntity(entity) then break end
            Wait(10)
        end

        for _ = 1, 50 do
            if not DoesEntityExist(entity) then return end
            if not IsEntityOnFire(entity) then StartEntityFire(entity) end
            Wait(200)
        end
    end)
end

RegisterNUICallback('laserAction', function(data, cb)
    cb(true)
    local selected = laser.selected
    if not selected or not DoesEntityExist(selected.handle) then return Notify(locale('notify.no_entity_selected'), 'error') end

    local entity, action = selected.handle, data.action
    local entityType = GetEntityType(entity)
    local label = getEntityLabel(entity)
    local ped = cache.ped

    if entityType == 1 and IsPedAPlayer(entity) then
        local serverId = GetPlayerServerId(NetworkGetEntityOwner(entity))
        local playerAction = PLAYER_LASER_ACTIONS[action]
        if playerAction then
            local payload = { player = serverId }
            for key, value in pairs(playerAction.extra or {}) do payload[key] = value end
            return TriggerServerEvent(playerAction.event, payload)
        end
        if action == 'tp_to' then
            local coords = GetEntityCoords(entity)
            SetEntityCoords(ped, coords.x, coords.y, coords.z + 0.5, false, false, false, true)
            return Notify(locale('notify.teleported'), 'success')
        end
    end

    if action == 'delete' then
        logLaserAction(('Deleted %s via Laser Tool'):format(label), { model = GetEntityModel(entity) })
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
        laser.selected = nil
        sendLaserUpdate(true)
        Notify(locale('notify.entity_deleted'), 'error')
    elseif action == 'explode' then
        local coords = GetEntityCoords(entity)
        logLaserAction(('Exploded %s via Laser Tool'):format(label), { coords = { x = coords.x, y = coords.y, z = coords.z } })
        AddExplosion(coords.x, coords.y, coords.z, 1, 10.0, true, false, 1.0)
        Notify(locale('notify.entity_exploded'), 'error')
    elseif action == 'burn' then
        logLaserAction(('Set %s on fire via Laser Tool'):format(label))
        setOnFireRepeatedly(entity)
        Notify(locale('notify.entity_on_fire'), 'error')
    elseif action == 'freeze' then
        local frozen = not IsEntityPositionFrozen(entity)
        logLaserAction(('%s %s via Laser Tool'):format(frozen and 'Froze' or 'Unfroze', label))
        FreezeEntityPosition(entity, frozen)
        Notify(locale(frozen and 'notify.entity_frozen' or 'notify.entity_unfrozen'), frozen and 'success' or 'error')
    elseif action == 'teleport' then
        local coords = GetEntityCoords(entity)
        logLaserAction(('Teleported to %s via Laser Tool'):format(label))
        SetEntityCoords(ped, coords.x, coords.y, coords.z + 1.0, false, false, false, true)
        Notify(locale('notify.teleported'), 'success')
    elseif entityType == 2 and action == 'warp' then
        logLaserAction(('Warped into %s via Laser Tool'):format(label))
        TaskWarpPedIntoVehicle(ped, entity, -1)
        Notify(locale('notify.warped_vehicle'), 'success')
    elseif entityType == 2 and action == 'fix' then
        local netId = NetworkGetNetworkIdFromEntity(entity)
        if not netId or netId == 0 then return Notify(locale('notify.entity_not_networked'), 'error') end
        TriggerServerEvent('butter_admin:server:fixVehicleForAll', netId)
        Notify(locale('notify.vehicle_fixed_cleaned'), 'success')
    elseif entityType == 2 and action == 'flip' then
        logLaserAction(('Flipped %s via Laser Tool'):format(label))
        SetVehicleOnGroundProperly(entity)
        Notify(locale('notify.vehicle_flipped'), 'success')
    elseif entityType == 2 and action == 'engine' then
        local running = GetIsVehicleEngineRunning(entity)
        logLaserAction(('Turned %s engine of %s via Laser Tool'):format(running and 'off' or 'on', label))
        SetVehicleEngineOn(entity, not running, true, true)
        Notify(locale(running and 'notify.engine_off' or 'notify.engine_on'), 'success')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if blipsEnabled then TriggerServerEvent('butter_admin:server:setBlipsEnabled', false) end
    for _, data in pairs(playerBlips) do
        if DoesBlipExist(data.blip) then RemoveBlip(data.blip) end
    end
    clearGamerTags()
end)

refreshDisplayOptions()
