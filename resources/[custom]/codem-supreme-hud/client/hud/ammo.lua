local interval = Utils.CreateAdaptiveInterval({
    min = 100,
    max = 1000,
    step = 100,
    threshold = 3
})

local lastAmmo, lastTotal, lastWeapon = -1, -1, nil

CreateThread(function()
    local GetCurrentPedWeapon = GetCurrentPedWeapon
    local GetAmmoInClip = GetAmmoInClip
    local GetAmmoInPedWeapon = GetAmmoInPedWeapon

    while true do
        if not (IsPlayerLoaded() and IsHudVisible()) then
            Wait(Utils.W(1000))
            goto continue
        end

        local ped = cache.ped
        local _, currentWeapon = GetCurrentPedWeapon(ped, true)

        if currentWeapon ~= `WEAPON_UNARMED` then
            local _, ammoInClip = GetAmmoInClip(ped, currentWeapon)
            local totalAmmo = GetAmmoInPedWeapon(ped, currentWeapon)

            if ammoInClip ~= lastAmmo or totalAmmo ~= lastTotal or currentWeapon ~= lastWeapon then
                lastAmmo, lastTotal, lastWeapon = ammoInClip, totalAmmo, currentWeapon
                UpdateAmmoDisplay()
                interval.onChanged()
            else
                interval.onStable()
            end
        else
            if lastWeapon ~= `WEAPON_UNARMED` then
                lastWeapon = `WEAPON_UNARMED`
                lastAmmo, lastTotal = -1, -1
                UpdateAmmoDisplay()
            end
            interval.setMax()
        end

        Wait(interval.current)
        ::continue::
    end
end)
