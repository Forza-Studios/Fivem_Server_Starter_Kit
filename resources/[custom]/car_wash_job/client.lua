local bossPed
local bossBlip
local jobActive = false

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
            TaskStartScenarioInPlace(bossPed, anims[1], 0, true)
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
--  Random dialogue (voice + mouth movement)
-- ------------------------------------------------------------
local function playDialogue(speechName)
    local cfg = Config.Boss.dialogue
    if not cfg or cfg.enabled == false then return end
    if not DoesEntityExist(bossPed) then return end

    if not speechName then
        local lines = cfg.lines
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

local function dialogueLoop()
    local cfg = Config.Boss.dialogue
    if not cfg or cfg.enabled == false then return end

    local interval = cfg.interval or { min = 20000, max = 45000 }

    while true do
        Wait(math.random(interval.min or 20000, interval.max or 45000))
        playDialogue()
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

    local cfg = Config.Boss.dialogue
    if cfg and cfg.greetOnInteract ~= false then
        playDialogue()
    end

    notify(Config.Boss.target.startedMessage or 'You started the car wash job!', 'success')
end

local function stopCarWashJob()
    if not jobActive then return end
    jobActive = false

    -- Hook for other scripts: listen to 'car_wash_job:client:stopJob'
    TriggerEvent('car_wash_job:client:stopJob')

    local cfg = Config.Boss.dialogue
    if cfg and cfg.greetOnInteract ~= false then
        playDialogue()
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
            local anims = Config.Boss.animations
            if anims and #anims > 0 then
                local scenario = anims[math.random(#anims)]
                TaskStartScenarioInPlace(bossPed, scenario, 0, true)
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
    playDialogue()

    -- Chatter runs in its own thread so it keeps going alongside the animations
    CreateThread(dialogueLoop)

    animateBoss()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if bossBlip and DoesBlipExist(bossBlip) then
        RemoveBlip(bossBlip)
        bossBlip = nil
    end
    if bossPed and DoesEntityExist(bossPed) then
        StopPedSpeaking(bossPed, true)
        DeleteEntity(bossPed)
    end
end)
