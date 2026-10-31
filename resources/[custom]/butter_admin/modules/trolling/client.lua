-- The UFO kidnap, ghost and kidnap van trolls are adapted from tgiann-admin-troll
-- (https://github.com/tgiann/fivem-tgiann-admin-troll, GPL-3.0).

local DRUNK_CLIPSET = 'move_m@drunk@verydrunk'
local DRUNK_DURATION = 30000
local DRUNK_DRIVING_ACTIONS = { 1, 7, 8, 23, 4, 5 }
local ANIMAL_LIFETIME = 60000
local FIRE_DURATION_TICKS = 100
local BUSTED_DICT = 'random@arrests@busted'
local KIDNAP_DICT = 'random@kidnap_girl'
local UFO_DANCE_DICT = 'anim@mp_player_intcelebrationmale@the_woogie'

local _, attackGroup = AddRelationshipGroup('BUTTER_ADMIN_ATTACK_ANIMAL')
local isDrunk = false

--- Loads every model, or returns false when one doesn't exist or fails to stream.
---@param models (string|number)[]
---@return boolean
local function loadModels(models)
    for _, model in ipairs(models) do
        if not pcall(lib.requestModel, model) then return false end
    end
    return true
end

---@param isLoaded fun(): boolean
---@param timeout number
---@return boolean
local function waitUntil(isLoaded, timeout)
    local deadline = GetGameTimer() + timeout
    while not isLoaded() do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

RegisterNetEvent('butter_admin:client:flingPlayer', function()
    local vehicle = GetVehiclePedIsUsing(cache.ped)
    if vehicle ~= 0 then
        ApplyForceToEntity(vehicle, 1, 0.0, 0.0, 100000.0, 1.0, 0.0, 0.0, 1, false, true, false, false, false)
    else
        ApplyForceToEntity(cache.ped, 1, 9500.0, 3.0, 7100.0, 1.0, 0.0, 0.0, 1, false, true, false, false, false)
    end
end)

RegisterNetEvent('butter_admin:client:makeDrunk', function()
    if isDrunk then return end
    isDrunk = true

    local ped = cache.ped
    RequestAnimSet(DRUNK_CLIPSET)
    if waitUntil(function() return HasAnimSetLoaded(DRUNK_CLIPSET) end, 5000) then SetPedMovementClipset(ped, DRUNK_CLIPSET, 0.0) end
    ShakeGameplayCam('DRUNK_SHAKE', 3.0)
    SetPedIsDrunk(ped, true)
    SetTransitionTimecycleModifier('spectator5', 10.0)

    -- Erratic steering while driving.
    CreateThread(function()
        while isDrunk do
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                TaskVehicleTempAction(ped, vehicle, DRUNK_DRIVING_ACTIONS[math.random(#DRUNK_DRIVING_ACTIONS)], 500)
            end
            Wait(5000)
        end
    end)

    SetTimeout(DRUNK_DURATION, function()
        isDrunk = false
        SetTransitionTimecycleModifier('default', 10.0)
        StopGameplayCamShaking(true)
        SetPedIsDrunk(ped, false)
        ResetPedMovementClipset(ped, 0.0)
        RemoveAnimSet(DRUNK_CLIPSET)
    end)
end)

RegisterNetEvent('butter_admin:client:animalAttack', function()
    local ped = cache.ped
    local model = Config.Fun.AttackAnimals[math.random(#Config.Fun.AttackAnimals)]
    if not loadModels({ model }) then return end

    local spawn = GetOffsetFromEntityInWorldCoords(ped, 100.0, -15.0, 0.0)
    local _, groundZ = GetGroundZAndNormalFor_3dCoord(spawn.x, spawn.y, spawn.z)
    local animal = CreatePed(1, joaat(model), spawn.x, spawn.y, groundZ, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(model)

    -- A dedicated group, so only this animal hates players instead of every
    -- animal on the map for the rest of the session.
    SetPedFleeAttributes(animal, 0, false)
    SetPedRelationshipGroupHash(animal, attackGroup)
    SetRelationshipBetweenGroups(5, attackGroup, `PLAYER`)
    TaskSetBlockingOfNonTemporaryEvents(animal, true)
    ClearPedTasks(animal)
    TaskPutPedDirectlyIntoMelee(animal, ped, 0.0, -1.0, 0.0, false)

    SetTimeout(ANIMAL_LIFETIME, function()
        if DoesEntityExist(animal) then SetPedAsNoLongerNeeded(animal) end
    end)
end)

RegisterNetEvent('butter_admin:client:setOnFire', function()
    local ped = cache.ped
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 then StartEntityFire(vehicle) end
    StartEntityFire(ped)

    -- Re-lit for a while so other scripts can't put it out straight away.
    CreateThread(function()
        for _ = 1, FIRE_DURATION_TICKS do
            if not IsEntityOnFire(ped) then StartEntityFire(ped) end
            Wait(200)
        end
    end)
end)

RegisterNetEvent('butter_admin:client:forceAnimation', function(label)
    for _, animation in ipairs(Config.Fun.Animations) do
        if animation.Label == label then
            if pcall(lib.requestAnimDict, animation.Dict) then
                TaskPlayAnim(cache.ped, animation.Dict, animation.Name, 8.0, -8.0, -1, 49, 0, false, false, false)
                RemoveAnimDict(animation.Dict)
            end
            return
        end
    end
end)

RegisterNetEvent('butter_admin:client:executeCommand', function(command)
    if type(command) ~= 'string' or command == '' or command:find('[;\r\n]') then return end

    -- Checked again here in case the server check is ever bypassed.
    local first = (command:match('^(%S+)') or ''):lower()
    for _, allowed in ipairs(Config.Fun.ForceCommandWhitelist) do
        if first == allowed then return ExecuteCommand(command) end
    end
end)

RegisterNetEvent('butter_admin:client:sendToJailbox', function()
    local ped = cache.ped
    local coords = Config.Fun.JailboxCoords

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    waitUntil(function() return HasCollisionLoadedAroundEntity(ped) end, 2000)

    Wait(500)
    DoScreenFadeIn(500)
    Notify(locale('trolling.jail_success_target', GetPlayerName(cache.playerId)), 'inform')
end)

RegisterNetEvent('butter_admin:client:damageVehicle', function()
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle == 0 then return end

    SetVehicleEngineHealth(vehicle, -100.0)
    SetVehicleBodyHealth(vehicle, 100.0)
    for wheel = 0, 7 do SetVehicleTyreBurst(vehicle, wheel, true, 1000.0) end
end)

---@param vehicle number
local function makeVehicleInvincible(vehicle)
    SetEntityInvincible(vehicle, true)
    SetEntityProofs(vehicle, true, true, true, true, true, true, true, true)
    SetVehicleTyresCanBurst(vehicle, false)
    SetVehicleDamageModifier(vehicle, 0.0)
    SetVehicleEngineCanDegrade(vehicle, false)
    SetVehicleCanBeTargetted(vehicle, false)
    SetEntityAsMissionEntity(vehicle, true, true)
end

---@param ped number
local function makePedInvincible(ped)
    SetEntityInvincible(ped, true)
    SetEntityProofs(ped, true, true, true, true, true, true, true, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetPedCanBeKnockedOffVehicle(ped, 1)
    SetPedCanBeTargetted(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    TaskSetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityAsMissionEntity(ped, true, true)
end

---@param model string
---@param offset number distance in front of the player
---@param heading number
---@return number vehicle
local function spawnKidnapVehicle(model, offset, heading)
    local coords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, offset, 0.0)
    local _, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
    local vehicle = CreateVehicle(joaat(model), coords.x, coords.y, groundZ ~= 0.0 and groundZ or coords.z, heading, true, false)
    makeVehicleInvincible(vehicle)
    SetVehicleOnGroundProperly(vehicle)
    return vehicle
end

---@param entity number
---@return number
local function getNetId(entity)
    if not DoesEntityExist(entity) then return 0 end
    local ok, netId = pcall(NetworkGetNetworkIdFromEntity, entity)
    return ok and netId or 0
end

---@param waypoint vector3?
---@return vector3
local function resolveDropOff(waypoint)
    if waypoint then return waypoint end
    local blip = GetFirstBlipInfoId(8)
    if DoesBlipExist(blip) then return GetBlipInfoIdCoord(blip) end
    local locations = Config.Fun.Kidnap.DropLocations
    return locations[math.random(#locations)]
end

RegisterNetEvent('butter_admin:client:kidnapVan', function(adminWaypoint)
    local kidnap = Config.Fun.Kidnap
    local playerPed = cache.ped
    local playerCoords = GetEntityCoords(playerPed)
    local weapon = joaat(kidnap.Weapon)

    if not loadModels({ kidnap.VanModel, kidnap.PedModel, kidnap.EscortModel }) then return end
    RequestWeaponAsset(weapon, 31, 0)
    if not waitUntil(function() return HasWeaponAssetLoaded(weapon) end, 10000) then return end

    local heading = GetEntityHeading(playerPed) + 180.0
    local pedModel = joaat(kidnap.PedModel)

    local van = spawnKidnapVehicle(kidnap.VanModel, 45.0, heading)
    local driver = CreatePedInsideVehicle(van, 1, pedModel, -1, true, false)
    local grabbers = { CreatePedInsideVehicle(van, 1, pedModel, 0, true, false), CreatePedInsideVehicle(van, 1, pedModel, 1, true, false) }
    makePedInvincible(driver)
    for _, ped in ipairs(grabbers) do makePedInvincible(ped) end

    local escort = spawnKidnapVehicle(kidnap.EscortModel, 60.0, heading)
    local guards = {}
    for seat = -1, 2 do
        local guard = CreatePedInsideVehicle(escort, 1, pedModel, seat, true, false)
        makePedInvincible(guard)
        SetPedCombatAttributes(guard, 2, true)  -- can drive-by
        SetPedCombatAttributes(guard, 46, true) -- always fight
        GiveWeaponToPed(guard, weapon, 999, false, true)
        SetPedInfiniteAmmo(guard, true, weapon)
        guards[#guards + 1] = guard
    end

    SetModelAsNoLongerNeeded(joaat(kidnap.VanModel))
    SetModelAsNoLongerNeeded(pedModel)
    SetModelAsNoLongerNeeded(joaat(kidnap.EscortModel))

    -- The server deletes these once the kidnap ends.
    local netIds = { getNetId(van), getNetId(driver), getNetId(grabbers[1]), getNetId(grabbers[2]), getNetId(escort) }
    for _, guard in ipairs(guards) do netIds[#netIds + 1] = getNetId(guard) end
    TriggerServerEvent('butter_admin:server:registerKidnapEntities', netIds)

    SetDriverAbility(driver, 1.0)
    SetDriverAggressiveness(driver, 1.0)
    SetVehicleDoorsLocked(van, 1)
    TaskVehicleDriveToCoord(driver, van, playerCoords.x, playerCoords.y, playerCoords.z, 25.0, 0, joaat(kidnap.VanModel), 1074528293, 3.0, true)
    TaskVehicleFollow(guards[1], escort, van, 30.0, 1074528293, 8)

    local escaped = false   -- every guard is dead, the kidnap is called off
    local holding = true    -- player controls stay locked
    local inVan = false     -- the player was put in the van and must stay there
    local arrived = false
    local attacker

    local escortPeds = { [van] = true, [escort] = true, [driver] = true, [grabbers[1]] = true, [grabbers[2]] = true }
    for _, guard in ipairs(guards) do escortPeds[guard] = true end

    -- Remembers who shoots the convoy so the guards fight back.
    local damageHandler = AddEventHandler('gameEventTriggered', function(name, args)
        if name ~= 'CEventNetworkEntityDamage' or not escortPeds[args[1]] then return end
        local culprit = args[2]
        if culprit == 0 or not DoesEntityExist(culprit) then return end
        local culpritPed = IsEntityAVehicle(culprit) and GetPedInVehicleSeat(culprit, -1) or culprit
        if culpritPed ~= 0 and DoesEntityExist(culpritPed) and IsEntityAPed(culpritPed) then attacker = culpritPed end
    end)

    local function finish()
        holding = false
        if damageHandler then
            RemoveEventHandler(damageHandler)
            damageHandler = nil
        end
        TriggerServerEvent('butter_admin:server:cleanupKidnap')
    end

    ---@param ms number
    ---@return boolean escaped
    local function waitOrEscape(ms)
        local deadline = GetGameTimer() + ms
        while GetGameTimer() < deadline do
            if escaped then return true end
            Wait(100)
        end
        return escaped
    end

    local function guardsDead()
        for _, guard in ipairs(guards) do
            if DoesEntityExist(guard) and not IsPedDeadOrDying(guard, true) then return false end
        end
        return true
    end

    -- Escort monitor: ends the kidnap when every guard is down, otherwise retaliates.
    CreateThread(function()
        while holding and not escaped do
            Wait(250)
            if guardsDead() then
                escaped = true
                ClearPedTasksImmediately(playerPed)
                for _, ped in ipairs({ driver, grabbers[1], grabbers[2] }) do
                    if DoesEntityExist(ped) then ClearPedTasksImmediately(ped) end
                end
                for _, vehicle in ipairs({ van, escort }) do
                    if DoesEntityExist(vehicle) then
                        SetVehicleForwardSpeed(vehicle, 0.0)
                        SetVehicleHandbrake(vehicle, true)
                    end
                end
                if IsPedInVehicle(playerPed, van, false) then
                    TaskLeaveVehicle(playerPed, van, 16)
                    Wait(500)
                end
                Wait(3000)
                return finish()
            end

            if attacker and DoesEntityExist(attacker) and not IsPedDeadOrDying(attacker, true) then
                for _, guard in ipairs(guards) do
                    if DoesEntityExist(guard) and not IsPedDeadOrDying(guard, true) and not IsPedInCombat(guard, attacker) then
                        TaskCombatPed(guard, attacker, 0, 16)
                    end
                end
                attacker = nil
            end
        end
    end)

    CreateThread(function()
        for _ = 1, 40 do
            if #(GetEntityCoords(van) - playerCoords) < 8.0 then
                arrived = true
                break
            end
            if waitOrEscape(500) then return end
        end
        if not arrived then SetEntityCoords(van, playerCoords.x + 4.0, playerCoords.y + 4.0, playerCoords.z, false, false, false, false) end

        TaskVehicleTempAction(driver, van, 27, 2000)
        if waitOrEscape(500) then return end
        SetVehicleDoorOpen(van, 2, false, false)
        SetVehicleDoorOpen(van, 3, false, false)

        for _, grabber in ipairs(grabbers) do TaskLeaveVehicle(grabber, van, 0) end
        if waitOrEscape(500) then return end
        for _, grabber in ipairs(grabbers) do TaskGoToEntity(grabber, playerPed, -1, 1.0, 3.0, 1073741824, 0) end

        -- Locks movement and keeps the player in the van once they are inside.
        CreateThread(function()
            while holding do
                for _, control in ipairs({ 30, 31, 21, 22, 24, 25, 75 }) do DisableControlAction(0, control, true) end
                if inVan and DoesEntityExist(van) and not IsPedInVehicle(playerPed, van, false) then
                    SetPedIntoVehicle(playerPed, van, 2)
                    TaskPlayAnim(playerPed, BUSTED_DICT, 'idle_a', 8.0, -8.0, -1, 1, 0, false, false, false)
                end
                Wait(0)
            end
        end)

        RequestAnimDict(KIDNAP_DICT)
        RequestAnimDict(BUSTED_DICT)
        if not waitUntil(function() return escaped or HasAnimDictLoaded(KIDNAP_DICT) end, 10000) or escaped then return end

        local vanCoords, vanRotation = GetEntityCoords(van), GetEntityRotation(van, 2)
        local scene = NetworkCreateSynchronisedScene(vanCoords.x, vanCoords.y, vanCoords.z, vanRotation.x, vanRotation.y, vanRotation.z, 2, false, false, 1.0, 0, 1.0)
        NetworkAddPedToSynchronisedScene(grabbers[1], scene, KIDNAP_DICT, 'ig_1_guy1_drag_into_van', 1.5, -4.0, 1, 16, 1148846080, 0)
        NetworkAddPedToSynchronisedScene(grabbers[2], scene, KIDNAP_DICT, 'ig_1_guy2_drag_into_van', 1.5, -4.0, 1, 16, 1148846080, 0)
        NetworkAddPedToSynchronisedScene(playerPed, scene, KIDNAP_DICT, 'ig_1_girl_drag_into_van', 1.5, -4.0, 1, 16, 1148846080, 0)
        NetworkAddEntityToSynchronisedScene(van, scene, KIDNAP_DICT, 'drag_into_van_burr', 1.0, 1.0, 1)
        NetworkStartSynchronisedScene(scene)

        local escapedDuringScene = waitOrEscape(GetAnimDuration(KIDNAP_DICT, 'drag_into_van_burr') * 1000)
        NetworkStopSynchronisedScene(scene)
        if escapedDuringScene then return end

        ClearPedTasksImmediately(playerPed)
        SetPedIntoVehicle(playerPed, van, 2)
        inVan = true
        TaskWarpPedIntoVehicle(grabbers[1], van, 0)
        TaskWarpPedIntoVehicle(grabbers[2], van, 1)
        TaskPlayAnim(playerPed, BUSTED_DICT, 'idle_a', 8.0, -8.0, -1, 1, 0, false, false, false)

        if waitOrEscape(100) then return end
        SetVehicleDoorShut(van, 2, false)
        SetVehicleDoorShut(van, 3, false)

        TaskVehicleDriveWander(driver, van, 60.0, 1074528293)
        if waitOrEscape(25000) then return end

        DoScreenFadeOut(800)
        while not IsScreenFadedOut() do
            if escaped then return DoScreenFadeIn(10) end
            Wait(10)
        end

        local dropOff = resolveDropOff(adminWaypoint)
        local targetZ = dropOff.z
        for height = 1000, 0, -50 do
            if escaped then return DoScreenFadeIn(10) end
            SetEntityCoords(van, dropOff.x, dropOff.y, height + 0.0, false, false, false, false)
            Wait(10)
            local found, groundZ = GetGroundZFor_3dCoord(dropOff.x, dropOff.y, height + 0.0, false)
            if found then
                targetZ = groundZ + 0.5
                break
            end
        end

        SetEntityCoords(van, dropOff.x, dropOff.y, targetZ, false, false, false, false)
        SetEntityHeading(van, math.random(0, 360) + 0.0)
        RequestCollisionAtCoord(dropOff.x, dropOff.y, targetZ)
        waitUntil(function() return escaped or HasCollisionLoadedAroundEntity(playerPed) end, 1000)

        if waitOrEscape(1000) then return DoScreenFadeIn(10) end
        DoScreenFadeIn(800)
        if waitOrEscape(2000) then return end

        holding = false
        local finalCoords = GetEntityCoords(playerPed)
        TaskLeaveVehicle(playerPed, van, 16)
        Wait(500)
        SetEntityCoords(playerPed, finalCoords.x, finalCoords.y, finalCoords.z + 0.5, false, false, false, false)
        ClearPedTasksImmediately(playerPed)
        finish()
    end)
end)

RegisterNetEvent('butter_admin:client:ufoKidnap', function()
    local ufo = Config.Fun.Ufo
    local ped = cache.ped
    local startCoords = GetEntityCoords(ped)
    local beamRadius = 5.0

    if not loadModels({ ufo.Model }) or not pcall(lib.requestAnimDict, UFO_DANCE_DICT) then return end

    FreezeEntityPosition(ped, true)
    local abducting = true
    CreateThread(function()
        while abducting do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            Wait(0)
        end
    end)

    TaskPlayAnim(ped, UFO_DANCE_DICT, 'the_woogie', 8.0, -8.0, -1, 1, 0, false, false, false)

    local ufoCoords = vector3(startCoords.x, startCoords.y, startCoords.z + ufo.Height)
    local ufoObject = CreateObjectNoOffset(joaat(ufo.Model), ufoCoords.x, ufoCoords.y, ufoCoords.z, false, false, false)
    SetModelAsNoLongerNeeded(joaat(ufo.Model))
    SetEntityHeading(ufoObject, 0.0)
    FreezeEntityPosition(ufoObject, true)

    local drawing = true
    CreateThread(function()
        while drawing do
            DrawMarker(1, ufoCoords.x, ufoCoords.y, ufoCoords.z + 5.0, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, beamRadius, beamRadius, ufo.Height + 5.0, 255, 255, 255, 100, false, true, 2, false, nil, nil, false)
            DrawLightWithRange(startCoords.x, startCoords.y, startCoords.z + 0.1, 255, 255, 190, beamRadius, 1.0)
            Wait(0)
        end
    end)

    Wait(5000)

    -- Lift the player with growing speed until they reach the UFO.
    local liftSpeed, height = 0.001, GetEntityCoords(ped).z
    local maxHeight = startCoords.z + ufo.Height
    while height <= maxHeight do
        height = GetEntityCoords(ped).z + liftSpeed
        SetEntityCoords(ped, startCoords.x, startCoords.y, height, false, false, false, false)
        liftSpeed += 0.0025
        Wait(10)
    end

    DoScreenFadeOut(500)
    Wait(1000)
    DeleteEntity(ufoObject)
    drawing = false

    local landing = ufo.LandingCoords
    SetEntityCoords(ped, landing.x, landing.y, landing.z, false, false, false, false)
    SetPedToRagdoll(ped, 10000, 10000, 0, false, false, false)

    Wait(3000)
    DoScreenFadeIn(500)
    FreezeEntityPosition(ped, false)
    abducting = false
end)

RegisterNetEvent('butter_admin:client:ghostTroll', function(duration)
    local ghost = Config.Fun.Ghost
    local ped = cache.ped
    local model = ghost.Models[math.random(#ghost.Models)]

    if not loadModels({ model }) then return end
    RequestAnimDict(ghost.AnimDict)
    RequestNamedPtfxAsset(ghost.ParticleDict)
    if not waitUntil(function() return HasAnimDictLoaded(ghost.AnimDict) and HasNamedPtfxAssetLoaded(ghost.ParticleDict) end, 10000) then return end

    local hour, minute, second = GetClockHours(), GetClockMinutes(), GetClockSeconds()
    local spawnCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 10.0, 0.0)
    local ghostObject = CreateObject(joaat(model), spawnCoords.x, spawnCoords.y, spawnCoords.z - 1.0, false, false, false)
    SetModelAsNoLongerNeeded(joaat(model))
    SetEntityHeading(ghostObject, GetEntityHeading(ped))
    SetEntityAlpha(ghostObject, 150, false)
    PlayEntityAnim(ghostObject, ghost.AnimName, ghost.AnimDict, 1000.0, true, true, true, 0, 136704)

    UseParticleFxAsset(ghost.ParticleDict)
    local particle = StartParticleFxLoopedOnEntity(ghost.ParticleName, ghostObject, 0.0, 0.0, 0.7, 0.0, 0.0, 0.0, 1.0, false, false, false)
    SetParticleFxLoopedEvolution(particle, 'smoke', 10.0, true)

    local startedAt = GetGameTimer()
    local maxDuration = (tonumber(duration) or 0) > 0 and duration * 1000 or nil

    CreateThread(function()
        while true do
            NetworkOverrideClockTime(0, 0, 0)
            ClearOverrideWeather()
            ClearWeatherTypePersist()
            SetWeatherTypeNowPersist('THUNDER')
            SetWeatherTypeNow('THUNDER')
            SetWeatherTypePersist('THUNDER')

            -- The ghost vanishes when the player gets too close, runs, or time is up.
            local distance = #(GetEntityCoords(ped) - spawnCoords)
            if distance < 5.0 or distance > 25.0 then break end
            if maxDuration and GetGameTimer() - startedAt >= maxDuration then break end
            Wait(100)
        end

        StopParticleFxLooped(particle, true)
        DeleteEntity(ghostObject)
        NetworkOverrideClockTime(hour, minute, second)
        ClearOverrideWeather()
        ClearWeatherTypePersist()
    end)
end)

RegisterNetEvent('butter_admin:client:playSound', function(soundId, volume)
    local sound = Config.Sounds[soundId]
    if not sound then return end
    SendNuiAction('playSound', { soundName = sound.SoundName or soundId, volume = volume or 0.5 })
end)
