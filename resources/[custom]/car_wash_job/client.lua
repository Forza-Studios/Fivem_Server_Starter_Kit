local bossPed

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

-- Cycle through animations at the configured interval
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

CreateThread(function()
    -- Wait until the player is fully loaded and in game
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end

    Wait(1000)
    spawnBoss()
    animateBoss()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if bossPed and DoesEntityExist(bossPed) then
        DeleteEntity(bossPed)
    end
end)
