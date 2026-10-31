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

local function createJobBlips()
    local carCfg = Config.Car or {}
    local blipCfg = carCfg.blip or {}

    for _, loc in ipairs(carCfg.locations or {}) do
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

local function spawnJobCar(loc)
    if not jobActive then return end

    local carCfg = Config.Car or {}
    local models = carCfg.models
    if not models or #models == 0 then return end

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

    local vehicle = CreateVehicle(model, x, y, z, heading or 0.0, false, false)
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
            SetVehicleIndividualDoorsLocked(vehicle, door, 0)  -- 0 = unlocked
        end

        SetVehicleEngineOn(vehicle, true, true, false)

        -- Keep it unlocked for a moment in case the game re-applies defaults
        CreateThread(function()
            for _ = 1, 10 do
                if not DoesEntityExist(vehicle) then return end
                SetVehicleDoorsLocked(vehicle, 1)
                SetVehicleDoorsLockedForAllPlayers(vehicle, false)
                Wait(200)
            end
        end)

        jobCars[#jobCars + 1] = vehicle
    end
end

local function removeJobEntities()
    for i = #jobBlips, 1, -1 do
        local blip = jobBlips[i]
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        jobBlips[i] = nil
    end

    for i = #jobCars, 1, -1 do
        local vehicle = jobCars[i]
        if DoesEntityExist(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
        jobCars[i] = nil
    end
end

local function startJobLocations()
    removeJobEntities()
    createJobBlips()

    local locations = (Config.Car or {}).locations or {}

    -- Spawn in a thread so the target callback never blocks
    CreateThread(function()
        for _, loc in ipairs(locations) do
            if not jobActive then break end
            spawnJobCar(loc)
        end
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
