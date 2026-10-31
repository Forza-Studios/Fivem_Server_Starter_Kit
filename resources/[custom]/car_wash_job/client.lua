local bossPed

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
--  Target interaction
-- ------------------------------------------------------------
local function startCarWashJob()
    local target = Config.Boss.target or {}

    -- Hook for other scripts: listen to 'car_wash_job:client:startJob'
    TriggerEvent('car_wash_job:client:startJob')

    notify(target.startedMessage or 'You started the car wash job!', 'success')
end

local function addBossTarget()
    if not DoesEntityExist(bossPed) then return end

    local target = Config.Boss.target or {}
    local label = target.label or 'Start Car Wash Job'
    local icon = target.icon or 'fa-solid fa-soap'
    local distance = target.distance or 2.5

    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:addLocalEntity(bossPed, {
            {
                name = 'car_wash_job:start',
                label = label,
                icon = icon,
                distance = distance,
                onSelect = startCarWashJob,
            }
        })
    elseif GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(bossPed, {
            options = {
                {
                    label = label,
                    icon = icon,
                    action = startCarWashJob,
                }
            },
            distance = distance
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
    addBossTarget()
    animateBoss()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if bossPed and DoesEntityExist(bossPed) then
        DeleteEntity(bossPed)
    end
end)
