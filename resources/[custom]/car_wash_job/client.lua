local bossPed
local bossBlip
local jobActive = false
local phoneProp
local phoneActive = false

-- ------------------------------------------------------------
--  Notification helper (uses ox_lib, with a native fallback)
-- ------------------------------------------------------------
local function notify(message, nType)
    if GetResourceState('ox_lib') == 'started' then
        local target = Config.Boss.target or {}
        exports.ox_lib:notify({
            title = target.notifyTitle or 'Car Wash',
            description = message,
            type = nType or 'success',
        })
    else
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(false, true)
    end
end

-- ------------------------------------------------------------
--  Phone call animation (phone held to his ear, not looking at it)
-- ------------------------------------------------------------
local function deletePhoneProp()
    if phoneProp and DoesEntityExist(phoneProp) then
        DetachEntity(phoneProp, true, true)
        DeleteEntity(phoneProp)
    end
    phoneProp = nil
end

local function playPhoneCall()
    -- Already on the phone — don't restart the animation every cycle
    if phoneActive then return end

    local phoneCfg = Config.Boss.phone or {}
    local dict = phoneCfg.dict or 'amb@world_human_stand_mobile@male@standing@call@base'
    local clip = phoneCfg.clip or 'base'

    -- Drop whatever he was doing before (clipboard, smoke, ...)
    ClearPedTasks(bossPed)
    deletePhoneProp()

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not HasAnimDictLoaded(dict) then
        print('^1[car_wash_job] Failed to load phone call animation^7')
        return
    end

    -- Loop the "standing, phone to ear" call animation
    TaskPlayAnim(bossPed, dict, clip, 8.0, 1.0, -1, 1, 0.0, false, false, false)

    -- Give him a phone in his right hand
    local propModel = phoneCfg.prop or `prop_npc_phone_02`
    if type(propModel) == 'string' then propModel = GetHashKey(propModel) end

    RequestModel(propModel)
    local propTimeout = GetGameTimer() + 5000
    while not HasModelLoaded(propModel) and GetGameTimer() < propTimeout do
        Wait(10)
    end

    if HasModelLoaded(propModel) then
        local coords = GetEntityCoords(bossPed)
        phoneProp = CreateObject(propModel, coords.x, coords.y, coords.z, true, true, false)

        local bone = GetPedBoneIndex(bossPed, phoneCfg.bone or 28422)
        local off = phoneCfg.offset or vector3(0.0, 0.0, 0.0)
        local rot = phoneCfg.rotation or vector3(0.0, 0.0, 0.0)

        AttachEntityToEntity(phoneProp, bossPed, bone,
            off.x, off.y, off.z,
            rot.x, rot.y, rot.z,
            true, true, false, true, 2, true)

        SetModelAsNoLongerNeeded(propModel)
    end

    phoneActive = true
end

-- Plays either a scenario animation or the special 'PHONE_CALL' animation
local playAnimation

playAnimation = function(name)
    if name == 'PHONE_CALL' then
        playPhoneCall()
        return
    end

    phoneActive = false
    deletePhoneProp()
    TaskStartScenarioInPlace(bossPed, name, 0, true)
end

-- ------------------------------------------------------------
--  Boss ped
-- ------------------------------------------------------------
local function spawnBoss()
    if DoesEntityExist(bossPed) then return end

    local model = Config.Boss.model
    RequestModel(model)

    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not HasModelLoaded(model) then
        print('^1[car_wash_job] Failed to load boss model^7')
        return
    end

    local coords = Config.Boss.coords
    bossPed = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, false, true)

    if bossPed and bossPed ~= 0 then
        SetEntityAsMissionEntity(bossPed, true, true)
        SetEntityInvincible(bossPed, true)
        SetPedCanRagdoll(bossPed, false)
        SetPedDropsWeaponsWhenDead(bossPed, false)
        SetPedFleeAttributes(bossPed, 0, false)          -- doesn't run away
        SetPedCombatAttributes(bossPed, 46, true)        -- stays calm
        SetBlockingOfNonTemporaryEvents(bossPed, true)   -- ignores gunshots etc.
        FreezeEntityPosition(bossPed, true)              -- stays at the spot
        SetModelAsNoLongerNeeded(model)

        -- Start the first animation
        local anims = Config.Boss.animations
        if anims and #anims > 0 then
            playAnimation(anims[1])
        end
    end
end

-- ------------------------------------------------------------
--  Map blip
-- ------------------------------------------------------------
local function createBossBlip()
    local blipCfg = Config.Boss.blip
    if not blipCfg or bossBlip then return end

    local coords = Config.Boss.coords
    bossBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(bossBlip, blipCfg.sprite or 100)
    SetBlipColour(bossBlip, blipCfg.color or 37)
    SetBlipScale(bossBlip, blipCfg.scale or 0.75)
    SetBlipAsShortRange(bossBlip, blipCfg.shortRange ~= false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blipCfg.name or 'Car Wash Job')
    EndTextCommandSetBlipName(bossBlip)
end

-- ------------------------------------------------------------
--  Job locations (blinking blips + random customer cars)
-- ------------------------------------------------------------
local jobBlips = {}
local jobCars = {}
local jobCarSet = {}
local jobCarSpot = {}      -- vehicle -> the spot it was taken from
local cleanCars = {}       -- vehicles that finished washing (head back to their spot)
local completedSpots = {}  -- spot key -> true while the spot is on cooldown
local cooldownsLoaded = false

-- Car wash animation state
local washingVehicle = false
local washedCars = {}

RegisterNetEvent('car_wash_job:client:cooldowns', function(keys)
    completedSpots = {}
    for _, key in ipairs(keys or {}) do
        completedSpots[key] = true
    end
    cooldownsLoaded = true
end)

-- Asks the server which spots are still on cooldown (waits up to 3s)
local function fetchCooldowns()
    cooldownsLoaded = false
    TriggerServerEvent('car_wash_job:server:requestCooldowns')

    local timeout = GetGameTimer() + 3000
    while not cooldownsLoaded and GetGameTimer() < timeout do
        Wait(50)
    end
end

-- Config.Car drives everything (locations, models, blips)
local function carCfg()
    return Config.Car or {}
end

-- Where the job car spawns
local function carLocations()
    return carCfg().locations or {}
end

-- Where the car has to be taken (shown while driving the job car)
local function carwashLocations()
    return (Config.Carwash and Config.Carwash.locations) or {}
end

-- Accepts "x, y, z, heading" strings or vec4 values
local function parseLocation(loc)
    if type(loc) == 'string' then
        local x, y, z, heading = loc:match('^%s*([^,]+),%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$')

        if not x then
            x, y, z = loc:match('^%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$')
        end

        if not x then return end
        return tonumber(x), tonumber(y), tonumber(z), tonumber(heading) or 0.0
    end

    if type(loc) == 'table' then
        return loc.x, loc.y, loc.z, loc.w or loc.heading or 0.0
    end

    -- vector4
    return loc.x, loc.y, loc.z, loc.w or 0.0
end

-- Stable id for a spot, used for the 24h cooldown
local function spotKey(loc)
    local x, y = parseLocation(loc)
    return x and string.format('%.2f,%.2f', x, y) or nil
end

-- Spawn spots that are not on cooldown
local function availableCarLocations()
    local available = {}
    for _, loc in ipairs(carLocations()) do
        local key = spotKey(loc)
        if key and not completedSpots[key] then
            available[#available + 1] = loc
        end
    end
    return available
end

local function createJobBlips(locations, blipCfg)
    locations = locations or carLocations()
    blipCfg = blipCfg or carCfg().blip or {}

    for _, loc in ipairs(locations) do
        local x, y, z = parseLocation(loc)

        if x then
            local blip = AddBlipForCoord(x, y, z)
            SetBlipSprite(blip, blipCfg.sprite or 100)
            SetBlipDisplay(blip, 4)
            SetBlipColour(blip, blipCfg.color or 37)
            SetBlipScale(blip, blipCfg.scale or 0.9)
            SetBlipAsShortRange(blip, blipCfg.shortRange == true)

            -- Blink while the job is active
            if blipCfg.flash ~= false then
                SetBlipFlashes(blip, true)
            end

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(blipCfg.name or 'Car Wash Customer')
            EndTextCommandSetBlipName(blip)

            jobBlips[#jobBlips + 1] = blip
        end
    end
end

local function removeJobBlips()
    for i = #jobBlips, 1, -1 do
        local blip = jobBlips[i]
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        jobBlips[i] = nil
    end
end

local function spawnJobCar(loc)
    if not jobActive then return end

    -- Model list is Config.Car.models (a string also works)
    local models = carCfg().models or carCfg().model
    if type(models) == 'string' then models = { models } end
    if type(models) ~= 'table' or #models == 0 then return end

    local x, y, z, heading = parseLocation(loc)
    if not x then return end

    -- Random model from the config list
    local model = models[math.random(#models)]
    if type(model) == 'string' then model = GetHashKey(model) end

    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not HasModelLoaded(model) then
        print('^1[car_wash_job] Failed to load car model^7')
        return
    end

    if not jobActive then
        SetModelAsNoLongerNeeded(model)
        return
    end

    -- Networked so qbx_vehiclekeys can hand the driver keys (net id 0 = undrivable)
    local vehicle = CreateVehicle(model, x, y, z, heading or 0.0, true, false)
    SetModelAsNoLongerNeeded(model)

    if vehicle and vehicle ~= 0 then
        SetVehicleOnGroundProperly(vehicle)
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleHasBeenOwnedByPlayer(vehicle, true)

        -- Force the car to be unlocked (doors + no hotwiring needed)
        SetVehicleDoorsLocked(vehicle, 1)                      -- 1 = unlocked
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
        SetVehicleNeedsToBeHotwired(vehicle, false)
        for door = 0, 5 do
            SetVehicleIndividualDoorsLocked(vehicle, door, 1)  -- 1 = unlocked
        end

        -- IMPORTANT: tell qbx_vehiclekeys it's unlocked. Without this state bag
        -- it randomly locks vehicles (spawnLockedIfParked) when you try to enter.
        Entity(vehicle).state:set('doorslockstate', 1, true)

        SetVehicleUndriveable(vehicle, false)
        SetVehicleKeepEngineOnWhenAbandoned(vehicle, true)
        SetVehicleEngineOn(vehicle, true, true, false)

        -- Keep it unlocked for a moment in case the game re-applies defaults
        CreateThread(function()
            for _ = 1, 10 do
                if not DoesEntityExist(vehicle) then return end
                SetVehicleDoorsLocked(vehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)
                Entity(vehicle).state:set('doorslockstate', 1, true)
                Wait(200)
            end
        end)

        jobCars[#jobCars + 1] = vehicle
        jobCarSet[vehicle] = true
        jobCarSpot[vehicle] = { x = x, y = y, z = z, key = spotKey(loc) }
    end
end

local function removeJobEntities()
    removeJobBlips()
    washedCars = {}
    cleanCars = {}
    jobCarSpot = {}

    for i = #jobCars, 1, -1 do
        local vehicle = jobCars[i]
        jobCarSet[vehicle] = nil
        if DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
        jobCars[i] = nil
    end
end

local function isInJobCar()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    return vehicle ~= 0 and jobCarSet[vehicle] == true
end

-- Blips depend on what the player is doing:
--   in an unwashed job car -> wash spots
--   in a washed job car    -> GPS route back to the spot the car was taken from
--   otherwise              -> the car spots that are not on cooldown
local function startBlipSwitch()
    CreateThread(function()
        local shownState
        local returnBlip

        local function clearReturnBlip()
            if returnBlip and DoesBlipExist(returnBlip) then RemoveBlip(returnBlip) end
            returnBlip = nil
        end

        while jobActive do
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            local state = 'spots'
            local origin

            if vehicle ~= 0 and jobCarSet[vehicle] then
                origin = jobCarSpot[vehicle]
                if cleanCars[vehicle] and origin then
                    state = 'return:' .. origin.key
                elseif #carwashLocations() > 0 then
                    state = 'wash'
                end
            end

            if state ~= shownState then
                shownState = state
                removeJobBlips()
                clearReturnBlip()

                if state == 'wash' then
                    createJobBlips(carwashLocations(), (Config.Carwash and Config.Carwash.blip) or nil)
                elseif origin and state:sub(1, 7) == 'return:' then
                    local cfg = (Config.Return and Config.Return.blip) or {}
                    returnBlip = AddBlipForCoord(origin.x, origin.y, origin.z)
                    SetBlipSprite(returnBlip, cfg.sprite or 225)
                    SetBlipColour(returnBlip, cfg.color or 2)
                    SetBlipScale(returnBlip, cfg.scale or 1.0)
                    SetBlipAsShortRange(returnBlip, false)
                    SetBlipRoute(returnBlip, true)
                    SetBlipRouteColour(returnBlip, cfg.color or 2)

                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentString(cfg.name or 'Return Car Here')
                    EndTextCommandSetBlipName(returnBlip)
                else
                    createJobBlips(availableCarLocations())
                end
            end

            Wait(500)
        end

        clearReturnBlip()
    end)
end

-- Bring a washed car back to its spot: the car is handed in and the spot
-- goes on cooldown (stored on the server).
local function startAutoReturn()
    CreateThread(function()
        local radius = (Config.Return and Config.Return.radius) or 5.0

        while jobActive do
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            local origin = vehicle ~= 0 and jobCarSpot[vehicle]

            if origin and cleanCars[vehicle] and not completedSpots[origin.key]
                and #(GetEntityCoords(vehicle) - vector3(origin.x, origin.y, origin.z)) <= radius then
                completedSpots[origin.key] = true
                TriggerServerEvent('car_wash_job:server:completeSpot', origin.key)

                TaskLeaveVehicle(ped, vehicle, 0)
                local timeout = GetGameTimer() + 4000
                while IsPedInVehicle(ped, vehicle, false) and GetGameTimer() < timeout do
                    Wait(100)
                end

                jobCarSet[vehicle] = nil
                jobCarSpot[vehicle] = nil
                cleanCars[vehicle] = nil
                if DoesEntityExist(vehicle) then
                    SetEntityAsMissionEntity(vehicle, true, true)
                    DeleteVehicle(vehicle)
                end

                notify('Car returned! This spot is available again in 24 hours.', 'success')
            end

            Wait(500)
        end
    end)
end

-- ------------------------------------------------------------
--  Automatic car wash (water particles + spinning roller machines)
--  Particle/prop animation adapted from ixhal-carwash
-- ------------------------------------------------------------
local ptfxData = {
    { dict = 'cut_test',  name = 'exp_hydrant', offset = { 0.0, 0.0, 4.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 0.5 },
    { dict = 'cut_test',  name = 'exp_hydrant', offset = { -0.5, 0.0, 4.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 0.5 },
    { dict = 'cut_test',  name = 'exp_hydrant', offset = { -1.0, 0.0, 4.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 0.5 },
    { dict = 'cut_test',  name = 'exp_hydrant', offset = { -1.5, 0.0, 4.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 0.5 },
    { dict = 'cut_test',  name = 'exp_hydrant', offset = { -2.0, 0.0, 4.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 0.5 },
    { dict = 'cut_test',  name = 'exp_hydrant', offset = { 0.5, 0.0, 4.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 0.5 },
    { dict = 'cut_test',  name = 'exp_hydrant', offset = { 1.0, 0.0, 4.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 0.5 },
    { dict = 'cut_test',  name = 'exp_hydrant', offset = { 1.5, 0.0, 4.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 0.5 },
    { dict = 'cut_test',  name = 'exp_hydrant', offset = { 2.0, 0.0, 4.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 0.5 },

    { dict = 'scr_fbi5a', name = 'scr_tunnel_vent_bubbles', offset = { 0.0, 0.0, 0.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 2.0 },
    { dict = 'scr_fbi5a', name = 'scr_tunnel_vent_bubbles', offset = { 0.0, -1.0, 0.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 1.0 },
    { dict = 'scr_fbi5a', name = 'scr_tunnel_vent_bubbles', offset = { 0.0, 1.0, 0.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 1.0 },
    { dict = 'scr_fbi5a', name = 'scr_tunnel_vent_bubbles', offset = { 0.0, -2.0, 0.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 1.0 },
    { dict = 'scr_fbi5a', name = 'scr_tunnel_vent_bubbles', offset = { 0.0, 2.0, 0.0 }, rot = { 0.0, 180.0, 0.0 }, scale = 1.0 },
}

local function requestParticleFx(dict)
    RequestNamedPtfxAsset(dict)
    local timeout = GetGameTimer() + 5000
    while not HasNamedPtfxAssetLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end
end

local function loadPropModel(model)
    if not IsModelInCdimage(model) then
        print('^1[car_wash_job] Missing prop model for the car wash^7')
        return
    end

    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end
end

local function createWashProp(model, coords)
    if not HasModelLoaded(model) then loadPropModel(model) end

    local prop = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
    SetEntityAsMissionEntity(prop, true, true)
    FreezeEntityPosition(prop, true)
    SetEntityCollision(prop, false, true)
    return prop
end

local function playWashAnimation(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local ptfxHandles = {}
    local sideProps
    local minOffsets, maxOffsets = GetModelDimensions(GetEntityModel(vehicle))

    -- Spinning roller machines on both sides of the car
    if Config.Carwash.useProps ~= false then
        loadPropModel(`prop_carwash_roller_vert`)
        local _, maxPropDim = GetModelDimensions(`prop_carwash_roller_vert`)

        local leftOffset = GetOffsetFromEntityInWorldCoords(vehicle, minOffsets.x, minOffsets.y, minOffsets.z - 0.5)
        leftOffset = vector3(leftOffset.x + maxPropDim.x, leftOffset.y, leftOffset.z)

        local rightOffset = GetOffsetFromEntityInWorldCoords(vehicle, maxOffsets.x, minOffsets.y, minOffsets.z - 0.5)
        rightOffset = vector3(rightOffset.x - maxPropDim.x, rightOffset.y, rightOffset.z)

        sideProps = {
            {
                prop = createWashProp(`prop_carwash_roller_vert`, leftOffset),
                offset = vector3(minOffsets.x - (maxPropDim.x - 0.2), minOffsets.y, maxPropDim.z / 2),
            },
            {
                prop = createWashProp(`prop_carwash_roller_vert`, rightOffset),
                offset = vector3(maxOffsets.x + (maxPropDim.x - 0.2), minOffsets.y, maxPropDim.z / 2),
            },
        }

        for i = 1, #sideProps do
            CreateThread(function()
                while sideProps and sideProps[i] and DoesEntityExist(sideProps[i].prop) do
                    local direction = (i == 1) and 0.75 or -0.75
                    SetEntityHeading(sideProps[i].prop, (GetEntityHeading(sideProps[i].prop) + direction + 360) % 360)
                    Wait(0)
                end
            end)
        end
    end

    -- Water jets / bubbles attached to the car
    for _, ptfx in ipairs(ptfxData) do
        requestParticleFx(ptfx.dict)
        UseParticleFxAssetNextCall(ptfx.dict)

        local handle = StartNetworkedParticleFxLoopedOnEntity(
            ptfx.name, vehicle,
            ptfx.offset[1], ptfx.offset[2], ptfx.offset[3],
            ptfx.rot[1], ptfx.rot[2], ptfx.rot[3],
            ptfx.scale, false, false, false
        )

        ptfxHandles[#ptfxHandles + 1] = handle
    end

    local offset = minOffsets.y
    local propOffset = minOffsets.y

    local function moveEffects()
        for i = 1, #ptfxHandles do
            SetParticleFxLoopedOffsets(ptfxHandles[i], ptfxData[i].offset[1], offset, ptfxData[i].offset[3],
                ptfxData[i].rot[1], ptfxData[i].rot[2], ptfxData[i].rot[3])
        end

        if sideProps then
            for i = 1, #sideProps do
                SetEntityCoordsNoOffset(sideProps[i].prop,
                    GetOffsetFromEntityInWorldCoords(vehicle, sideProps[i].offset.x, propOffset, sideProps[i].offset.z))
            end
        end
    end

    -- Sweep from front to back
    while offset < maxOffsets.y and DoesEntityExist(vehicle) do
        moveEffects()
        offset = offset + 0.0055
        propOffset = propOffset + 0.0055
        Wait(0)
    end

    -- Sweep back again (double clean)
    if Config.Carwash.doubleClean ~= false then
        while minOffsets.y < offset and DoesEntityExist(vehicle) do
            moveEffects()
            offset = offset - 0.0055
            propOffset = propOffset - 0.0055
            Wait(0)
        end
    end

    for i = 1, #ptfxHandles do
        StopParticleFxLooped(ptfxHandles[i], false)
    end

    if sideProps then
        for i = 1, #sideProps do
            if DoesEntityExist(sideProps[i].prop) then
                DeleteEntity(sideProps[i].prop)
            end
        end
        sideProps = nil
    end
end

local function washVehicle(vehicle)
    if washingVehicle or not DoesEntityExist(vehicle) then return end
    washingVehicle = true

    FreezeEntityPosition(vehicle, true)
    playWashAnimation(vehicle)

    SetVehicleDirtLevel(vehicle, 0.0)
    WashDecalsFromVehicle(vehicle, 1.0)
    FreezeEntityPosition(vehicle, false)

    washingVehicle = false
    cleanCars[vehicle] = true
    notify('Vehicle washed! Take it back to where you picked it up.', 'success')
end

-- Watch the job car and wash it automatically when it reaches a wash spot
local function startAutoWash()
    CreateThread(function()
        while jobActive do
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

            if vehicle ~= 0 and jobCarSet[vehicle] and not washingVehicle and not washedCars[vehicle] then
                local coords = GetEntityCoords(vehicle)

                for _, loc in ipairs(carwashLocations()) do
                    local x, y, z = parseLocation(loc)

                    if x and #(coords - vector3(x, y, z)) <= (Config.Carwash.radius or 4.0) then
                        washedCars[vehicle] = true
                        CreateThread(function()
                            washVehicle(vehicle)
                        end)
                        break
                    end
                end
            end

            Wait(500)
        end
    end)
end

local function startJobLocations()
    removeJobEntities()

    -- Spawn in a thread so the target callback never blocks
    CreateThread(function()
        fetchCooldowns()
        if not jobActive then return end

        local locations = availableCarLocations()

        if #locations == 0 then
            jobActive = false
            TriggerEvent('car_wash_job:client:stopJob')
            notify('No cars need washing right now. Come back later.', 'error')
            return
        end

        for _, loc in ipairs(locations) do
            if not jobActive then break end
            spawnJobCar(loc)
        end

        -- Blips switch between car spots, wash spots and the way back
        startBlipSwitch()

        -- Wash the car as soon as it reaches a wash spot
        startAutoWash()

        -- Hand the car in when it is back at its spot
        startAutoReturn()
    end)
end

-- ------------------------------------------------------------
--  Continuous dialogue (voice + mouth movement)
-- ------------------------------------------------------------
local function currentLines()
    local cfg = Config.Boss.dialogue
    if phoneActive and cfg.phoneLines and #cfg.phoneLines > 0 then
        return cfg.phoneLines
    end
    return cfg.lines
end

local function playDialogue(speechName)
    local cfg = Config.Boss.dialogue
    if not cfg or cfg.enabled == false then return end
    if not DoesEntityExist(bossPed) then return end

    if not speechName then
        local lines = currentLines()
        if not lines or #lines == 0 then return end
        speechName = lines[math.random(#lines)]
    end

    -- Only talk when a player is close enough to hear him
    local maxDistance = cfg.maxDistance or 20.0
    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(bossPed)) > maxDistance then
        return
    end

    -- Random voice for every line so he never sounds the same
    local voices = cfg.voices
    if voices and #voices > 0 then
        local voice = voices[math.random(#voices)]
        PlayAmbientSpeechWithVoice(bossPed, speechName, voice, 'SPEECH_PARAMS_FORCE_NORMAL', false)
    else
        PlayAmbientSpeech1(bossPed, speechName, 'SPEECH_PARAMS_FORCE_NORMAL')
    end
end

local lastLine

-- Pick a random line and never repeat the same one twice in a row
local function pickLine()
    local lines = currentLines()
    if not lines or #lines == 0 then return end

    if #lines == 1 then return lines[1] end

    local line
    repeat
        line = lines[math.random(#lines)]
    until line ~= lastLine

    lastLine = line
    return line
end

local function isSpeaking(ped)
    return IsAmbientSpeechPlaying(ped) or IsScriptedSpeechPlaying(ped)
end

local function dialogueLoop()
    local cfg = Config.Boss.dialogue
    if not cfg or cfg.enabled == false then return end

    local delay = cfg.delay or 1000

    while true do
        playDialogue(pickLine())

        -- Keep talking with a short pause between lines
        Wait(delay)

        -- Wait for the current line to finish so it never gets cut off
        local waited = 0
        while DoesEntityExist(bossPed) and isSpeaking(bossPed) and waited < 12000 do
            Wait(100)
            waited = waited + 100
        end
    end
end

-- ------------------------------------------------------------
--  Job actions
-- ------------------------------------------------------------
local function startCarWashJob()
    if jobActive then return end
    jobActive = true

    -- Hook for other scripts: listen to 'car_wash_job:client:startJob'
    TriggerEvent('car_wash_job:client:startJob')

    -- Blinking blips + random car at every configured location
    startJobLocations()

    local cfg = Config.Boss.dialogue
    if cfg and cfg.greetOnInteract ~= false then
        playDialogue(pickLine())
    end

    notify(Config.Boss.target.startedMessage or 'You started the car wash job!', 'success')
end

local function stopCarWashJob()
    if not jobActive then return end
    jobActive = false

    -- Hook for other scripts: listen to 'car_wash_job:client:stopJob'
    TriggerEvent('car_wash_job:client:stopJob')

    -- Remove job blips and despawn the spawned cars
    removeJobEntities()

    local cfg = Config.Boss.dialogue
    if cfg and cfg.greetOnInteract ~= false then
        playDialogue(pickLine())
    end

    notify(Config.Boss.target.stoppedMessage or 'You stopped the car wash job.', 'error')
end

-- ------------------------------------------------------------
--  Target interaction
-- ------------------------------------------------------------
local function addBossTarget()
    if not DoesEntityExist(bossPed) then return end

    local target = Config.Boss.target or {}
    local distance = target.distance or 2.5

    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:addLocalEntity(bossPed, {
            {
                name = 'car_wash_job:start',
                label = target.startLabel or 'Start Car Wash Job',
                icon = target.icon or 'fa-solid fa-soap',
                distance = distance,
                canInteract = function() return not jobActive end,
                onSelect = startCarWashJob,
            },
            {
                name = 'car_wash_job:stop',
                label = target.stopLabel or 'Stop Car Wash Job',
                icon = target.stopIcon or 'fa-solid fa-stop',
                distance = distance,
                canInteract = function() return jobActive end,
                onSelect = stopCarWashJob,
            },
        })
    elseif GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(bossPed, {
            options = {
                {
                    label = target.startLabel or 'Start Car Wash Job',
                    icon = target.icon or 'fa-solid fa-soap',
                    canInteract = function() return not jobActive end,
                    action = startCarWashJob,
                },
                {
                    label = target.stopLabel or 'Stop Car Wash Job',
                    icon = target.stopIcon or 'fa-solid fa-stop',
                    canInteract = function() return jobActive end,
                    action = stopCarWashJob,
                },
            },
            distance = distance,
        })
    end
end

-- ------------------------------------------------------------
--  Animation cycling
-- ------------------------------------------------------------
local function animateBoss()
    while true do
        local interval = Config.Boss.animationInterval or { min = 25000, max = 40000 }
        Wait(math.random(interval.min, interval.max))

        if DoesEntityExist(bossPed) then
            -- If the phone animation was interrupted, allow it to start again
            local phoneCfg = Config.Boss.phone
            if phoneActive and phoneCfg and phoneCfg.dict and phoneCfg.clip
                and not IsEntityPlayingAnim(bossPed, phoneCfg.dict, phoneCfg.clip, 3) then
                phoneActive = false
                deletePhoneProp()
            end

            local anims = Config.Boss.animations
            if anims and #anims > 0 then
                local scenario = anims[math.random(#anims)]
                playAnimation(scenario)
            end
        end
    end
end

-- ------------------------------------------------------------
--  Startup / cleanup
-- ------------------------------------------------------------
CreateThread(function()
    -- Wait until the player is fully loaded and in game
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end

    Wait(1000)
    spawnBoss()
    createBossBlip()
    addBossTarget()

    -- Greet once shortly after spawning (only if a player is nearby)
    Wait(2500)
    playDialogue(pickLine())

    -- Chatter runs in its own thread so it keeps going alongside the animations
    CreateThread(dialogueLoop)

    animateBoss()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeJobEntities()
    if bossBlip and DoesBlipExist(bossBlip) then
        RemoveBlip(bossBlip)
        bossBlip = nil
    end
    if bossPed and DoesEntityExist(bossPed) then
        StopPedSpeaking(bossPed, true)
        deletePhoneProp()
        DeleteEntity(bossPed)
    end
end)
