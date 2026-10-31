local UNARMED = `WEAPON_UNARMED`

local frozen = false
local infiniteAmmo = false
local infiniteStamina = false

---@param name string command id shown as active in the menu
---@param state boolean
local function setItemEnabled(name, state)
    SendNuiAction('setItemEnabled', { Name = name, State = state })
end

--- ox_inventory tracks ammo in weapon metadata and would override the native
--- refill once its stored count runs out.
local function topUpOxAmmo()
    local weapon = exports.ox_inventory:getCurrentWeapon()
    if weapon?.metadata and weapon.metadata.ammo ~= nil then weapon.metadata.ammo = 250 end
end

RegisterNetEvent('butter_admin:client:setFrozen', function(state)
    frozen = state == true
    FreezeEntityPosition(cache.ped, frozen)
end)

RegisterNetEvent('butter_admin:client:setInfiniteAmmo', function(state)
    infiniteAmmo = state == true
    setItemEnabled('infammo', infiniteAmmo)

    if not infiniteAmmo then
        SetPedInfiniteAmmoClip(cache.ped, false)
        if cache.weapon and cache.weapon ~= UNARMED then SetPedInfiniteAmmo(cache.ped, false, cache.weapon) end
        return
    end

    local usingOxInventory = IsResourceStarted('ox_inventory')
    CreateThread(function()
        local affectedWeapons = {}
        while infiniteAmmo do
            local weapon = cache.weapon
            if weapon and weapon ~= UNARMED then
                SetPedAmmo(cache.ped, weapon, 9999)
                local maxClip = GetMaxAmmoInClip(cache.ped, weapon, true)
                if maxClip > 0 then SetAmmoInClip(cache.ped, weapon, maxClip) end
                SetPedInfiniteAmmoClip(cache.ped, true)
                SetPedInfiniteAmmo(cache.ped, true, weapon)
                affectedWeapons[weapon] = true
                if usingOxInventory then topUpOxAmmo() end
            end
            Wait(250)
        end

        SetPedInfiniteAmmoClip(cache.ped, false)
        for weapon in pairs(affectedWeapons) do SetPedInfiniteAmmo(cache.ped, false, weapon) end
    end)
end)

RegisterNetEvent('butter_admin:client:setInfiniteStamina', function(state)
    infiniteStamina = state == true
    setItemEnabled('infstamina', infiniteStamina)
    if not infiniteStamina then return end

    CreateThread(function()
        while infiniteStamina do
            RestorePlayerStamina(cache.playerId, 1.0)
            Wait(100)
        end
    end)
end)

---@param ped number
local function showPed(ped)
    -- Clearing the network flag re-applies the visibility it stored, so it has
    -- to happen before SetEntityVisible or the ped turns invisible again.
    NetworkSetEntityInvisibleToNetwork(ped, false)
    if not AdminState.noclip then SetEntityVisible(ped, true, false) end
    ResetEntityAlpha(ped)
end

RegisterNetEvent('butter_admin:client:setInvisible', function(state)
    AdminState.invisible = state == true
    setItemEnabled('invisible', AdminState.invisible)

    if not AdminState.invisible then return showPed(cache.ped) end

    CreateThread(function()
        while AdminState.invisible do
            -- Visibility is not a persistent flag: streaming, network resync and
            -- ped changes can flip it back, so it is re-asserted every frame.
            local ped = cache.ped
            NetworkSetEntityInvisibleToNetwork(ped, true)
            if not AdminState.noclip then SetEntityVisible(ped, false, false) end
            SetEntityAlpha(ped, 102, false)
            SetPlayerVisibleLocally(cache.playerId, true)
            Wait(0)
        end

        -- The loop above can run once more after the toggle-off, and resync can
        -- hide the ped again right after, so visibility is restored for a few frames.
        for _ = 1, 10 do
            if AdminState.invisible then return end
            showPed(cache.ped)
            Wait(0)
        end
    end)
end)

RegisterNetEvent('butter_admin:client:setGodmode', function(state)
    AdminState.godmode = state == true
    setItemEnabled('godmode', AdminState.godmode)

    if not AdminState.godmode then
        if not AdminState.noclip and not AdminState.devMode then SetPlayerInvincible(cache.playerId, false) end
        return
    end

    CreateThread(function()
        while AdminState.godmode do
            SetPlayerInvincible(cache.playerId, true)
            Wait(1000)
        end
    end)
end)

RegisterNetEvent('butter_admin:client:setModel', function(model)
    if type(model) ~= 'number' or not IsModelInCdimage(model) or not IsModelAPed(model) then
        return Notify(locale('objects.invalid_model', tostring(model)), 'error')
    end

    lib.requestModel(model)
    SetPlayerModel(cache.playerId, model)
    SetPedDefaultComponentVariation(PlayerPedId())
    SetModelAsNoLongerNeeded(model)
end)

RegisterNetEvent('butter_admin:client:revivePlayer', function()
    if RevivePlayer then RevivePlayer() end
end)

RegisterNetEvent('butter_admin:client:healPlayer', function()
    if RevivePlayer then RevivePlayer() end
    SetEntityHealth(cache.ped, GetEntityMaxHealth(cache.ped))
end)

RegisterNetEvent('butter_admin:client:killPlayer', function()
    if KillPlayer then return KillPlayer() end
    SetEntityHealth(cache.ped, 0)
end)

RegisterNetEvent('butter_admin:client:resetSkin', function(model, skin)
    if ResetSkin then ResetSkin(model, skin) end
end)

RegisterNetEvent('butter_admin:client:openClothing', function()
    CloseAdminMenu()
    Wait(100)
    if OpenClothingMenu then OpenClothingMenu() end
end)

RegisterNetEvent('butter_admin:client:showWarning', function(reason, adminName)
    PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', true)
    SetNuiFocus(true, true)
    SendNuiAction('showWarning', { Reason = reason, AdminName = adminName })
end)

RegisterNUICallback('dismissWarning', function(_, cb)
    SetNuiFocus(false, false)
    cb(true)
end)

-- The loops behind these states die with the resource, so their effects are
-- undone on stop instead of leaving the ped hidden or invincible.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    if AdminState.invisible then showPed(cache.ped) end
    if AdminState.godmode or AdminState.devMode then SetPlayerInvincible(cache.playerId, false) end
    if infiniteAmmo then SetPedInfiniteAmmoClip(cache.ped, false) end
    if frozen then FreezeEntityPosition(cache.ped, false) end
end)
