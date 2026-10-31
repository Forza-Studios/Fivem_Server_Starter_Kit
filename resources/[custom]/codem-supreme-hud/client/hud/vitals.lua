lastValues = lastValues or { health = -1, armor = -1, stamina = -1, underwater = false }

local interval = Utils.CreateAdaptiveInterval({
    min = 500,
    max = 3000,
    step = 200,
    threshold = 3
})

CreateThread(function()
    local GetEntityHealth = GetEntityHealth
    local GetPedArmour = GetPedArmour
    local IsPedSwimmingUnderWater = IsPedSwimmingUnderWater
    local GetPlayerUnderwaterTimeRemaining = GetPlayerUnderwaterTimeRemaining
    local GetPlayerSprintStaminaRemaining = GetPlayerSprintStaminaRemaining
    local clamp = Utils.clamp

    while true do
        Wait(interval.current)
        if not (IsPlayerLoaded() and GetHudSettings()) then goto continue end

        local changed = false
        local health = clamp(((GetEntityHealth(cache.ped) - 100) / (cache.maxHp - 100)) * 100)
        local armor = clamp(GetPedArmour(cache.ped))
        local isUnderwater = IsPedSwimmingUnderWater(cache.ped)
        local stamina = clamp(isUnderwater and GetPlayerUnderwaterTimeRemaining(cache.pid) * 10 or (100 - GetPlayerSprintStaminaRemaining(cache.pid)))

        -- Batch updates to reduce NUI message overhead
        local updates = {}

        if health ~= lastValues.health then
            lastValues.health = health
            updates.health = health
            changed = true
        end
        if armor ~= lastValues.armor then
            lastValues.armor = armor
            updates.armor = armor
            changed = true
        end
        if stamina ~= lastValues.stamina or isUnderwater ~= lastValues.underwater then
            lastValues.stamina, lastValues.underwater = stamina, isUnderwater
            updates.stamina = stamina
            updates.isUnderwater = isUnderwater
            changed = true
        end

        if changed then
            NuiMessage('updateVitals', updates)
        end

        if changed then interval.onChanged() else interval.onStable() end
        ::continue::
    end
end)
