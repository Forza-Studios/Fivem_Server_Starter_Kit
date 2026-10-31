--[[
    NITRO SYSTEM
    Percentage-based nitro with exhaust flames, purge, and backfire effects
    Config: shared/config.lua -> Config.VehicleFeatures.Nitro
]]

local Cfg = Config.VehicleFeatures.Nitro
if not Cfg or not Cfg.Enabled then return end

-- Adaptive interval for nitro idle checking
local nitroIdleInterval = Utils.CreateAdaptiveInterval({ min = 100, max = 500, step = 50, threshold = 3 })

-- STATE
local nitroState = {
    isInstalled = false,
    currentPlate = nil,
    level = 0,
    isActive = false,
    lastEmptyTime = 0,
    lastBackfire = 0,
    exhaustPtfx = {},
}

local purgePtfxLeft = nil
local purgePtfxRight = nil
local nitroSoundId = nil

-- ═══════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

--- Get normalized license plate from vehicle
---@param vehicle number Vehicle entity handle
---@return string|nil Plate string or nil if invalid
local function GetVehiclePlate(vehicle)
    local plate = Utils.GetNormalizedPlate(vehicle)
    return plate ~= '' and plate or nil
end

--- Get all exhaust bone indices from vehicle model
---@param vehicle number Vehicle entity handle
---@return table Array of bone indices
local function GetExhaustBones(vehicle)
    local bones = {}
    local exhaustNames = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4', 'exhaust_5', 'exhaust_6', 'exhaust_7', 'exhaust_8' }
    for _, name in ipairs(exhaustNames) do
        local bone = GetEntityBoneIndexByName(vehicle, name)
        if bone ~= -1 then bones[#bones + 1] = bone end
    end
    return bones
end

local EnsureParticleAsset = Utils.EnsureParticleFxAsset

--- Check if vehicle is electric (no fuel tank)
---@param vehicle number Vehicle entity handle
---@return boolean True if vehicle is electric
local function IsVehicleElectric(vehicle)
    local fuelTank = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fPetrolTankVolume')
    return fuelTank == 0 or fuelTank == nil
end

-- ═══════════════════════════════════════════════════════════════
-- PARTICLE EFFECTS
-- ═══════════════════════════════════════════════════════════════

--- Start nitro exhaust flame particle effect
---@param vehicle number Vehicle entity handle
local function StartExhaustFlame(vehicle)
    if not Cfg.Effects.ExhaustFlame then return end
    if #nitroState.exhaustPtfx > 0 then return end
    if IsVehicleElectric(vehicle) then return end

    local bones = GetExhaustBones(vehicle)
    local scale = Cfg.FlameScale or 1.0

    if not EnsureParticleAsset('veh_xs_vehicle_mods') then return end

    if #bones > 0 then
        for _, bone in ipairs(bones) do
            UseParticleFxAsset('veh_xs_vehicle_mods')
            local ptfx = StartParticleFxLoopedOnEntityBone('veh_nitrous', vehicle, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bone, scale, false, false, false)
            if ptfx and ptfx ~= 0 then nitroState.exhaustPtfx[#nitroState.exhaustPtfx + 1] = ptfx end
        end
    end
end

--- Stop nitro exhaust flame particle effect
local function StopExhaustFlame()
    for _, ptfx in ipairs(nitroState.exhaustPtfx) do
        if DoesParticleFxLoopedExist(ptfx) then StopParticleFxLooped(ptfx, false) end
    end
    nitroState.exhaustPtfx = {}
end

--- Play backfire spark effect on exhaust (exported for transmission.lua)
---@param vehicle number Vehicle entity handle
local function PlayBackfireEffect(vehicle)
    if not Cfg.Effects.Backfire then return end
    if not EnsureParticleAsset('veh_xs_vehicle_mods') then return end
    UseParticleFxAsset('veh_xs_vehicle_mods')

    local bones = GetExhaustBones(vehicle)
    local heading = GetEntityHeading(vehicle)

    if #bones > 0 then
        for _, bone in ipairs(bones) do
            local bonePos = GetWorldPositionOfEntityBone(vehicle, bone)
            StartParticleFxNonLoopedAtCoord('veh_nitrous', bonePos.x, bonePos.y, bonePos.z, 0.0, 0.0, heading, 0.6, false, false, false)
        end
    else
        StartParticleFxNonLoopedOnEntity('veh_nitrous', vehicle, 0, -2.5, 0.3, 0, 0, 0, 0.6, false, false, false)
    end
end

--- Calculate purge effect position based on vehicle class
---@param vehicle number Vehicle entity handle
---@return table|nil Position {x, y, z} or nil for incompatible vehicles
local function GetPurgePosition(vehicle)
    local model = GetEntityModel(vehicle)
    local min, max = GetModelDimensions(model)
    local vehicleClass = GetVehicleClass(vehicle)
    local vehicleWidth = max.x - min.x

    local xOffset = vehicleWidth * 0.18
    local yOffset = max.y * 0.55
    local zOffset = 0.7

    if vehicleClass == 6 or vehicleClass == 7 then
        yOffset, zOffset, xOffset = max.y * 0.65, 0.0, vehicleWidth * 0.2
    elseif vehicleClass == 5 or vehicleClass == 4 then
        yOffset, zOffset = max.y * 0.5, 0.65
    elseif vehicleClass == 2 or vehicleClass == 9 then
        yOffset, zOffset = max.y * 0.5, 1.1
    elseif vehicleClass == 3 then
        yOffset, zOffset = max.y * 0.6, 0.55
    elseif vehicleClass == 12 then
        yOffset, zOffset = max.y * 0.45, 1.0
    elseif vehicleClass == 10 or vehicleClass == 20 then
        yOffset, zOffset = max.y * 0.4, 1.2
    elseif vehicleClass == 8 or vehicleClass == 13 then
        return nil
    end

    local bonnetBone = GetEntityBoneIndexByName(vehicle, 'bonnet')
    if bonnetBone ~= -1 then
        local bonePos = GetWorldPositionOfEntityBone(vehicle, bonnetBone)
        local vehPos = GetEntityCoords(vehicle)
        local vehForward = GetEntityForwardVector(vehicle)
        local localBoneY = (bonePos.y - vehPos.y) / math.max(0.01, math.abs(vehForward.y))
        if localBoneY > 0 then yOffset = math.min(yOffset, max.y * 0.7) end
    end

    return { x = xOffset, y = yOffset, z = zOffset }
end

--- Start hood purge steam effect
---@param vehicle number Vehicle entity handle
local function StartPurgeEffect(vehicle)
    if not Cfg.Effects.Purge then return end
    if purgePtfxLeft or purgePtfxRight then return end
    if not EnsureParticleAsset('core') then return end

    local pos = GetPurgePosition(vehicle)
    if not pos then return end

    UseParticleFxAsset('core')
    purgePtfxLeft = StartParticleFxLoopedOnEntity('ent_sht_steam', vehicle, -pos.x, pos.y, pos.z, 30.0, 0.0, 0.0, 1.0, false, false, false)
    UseParticleFxAsset('core')
    purgePtfxRight = StartParticleFxLoopedOnEntity('ent_sht_steam', vehicle, pos.x, pos.y, pos.z, 30.0, 0.0, 0.0, 1.0, false, false, false)
end

--- Stop hood purge steam effect
local function StopPurgeEffect()
    if purgePtfxLeft and DoesParticleFxLoopedExist(purgePtfxLeft) then StopParticleFxLooped(purgePtfxLeft, false) end
    if purgePtfxRight and DoesParticleFxLoopedExist(purgePtfxRight) then StopParticleFxLooped(purgePtfxRight, false) end
    purgePtfxLeft, purgePtfxRight = nil, nil
end

-- ═══════════════════════════════════════════════════════════════
-- SOUND EFFECTS
-- ═══════════════════════════════════════════════════════════════

local NitroSounds = {
    flare = { name = 'Flare', ref = 'DLC_HEISTS_BIOLAB_FINALE_SOUNDS' },
}

local useNativeBoost = false
local useScreenEffect = false
local boostTickActive = false

local function StartBoostTick(vehicle)
    if boostTickActive then return end
    boostTickActive = true
    CreateThread(function()
        while boostTickActive and nitroState.isActive do
            if vehicle and DoesEntityExist(vehicle) then
                SetVehicleBoostActive(vehicle, true)
            end
            Wait(0)
        end
        if vehicle and DoesEntityExist(vehicle) then
            SetVehicleBoostActive(vehicle, false)
        end
        boostTickActive = false
    end)
end

local function StartNitroSound(vehicle)
    if not Cfg.Effects.Sound then return end

    local soundType = Cfg.Effects.SoundType or 'boost'

    if soundType == 'boost' then
        useNativeBoost = true
        StartBoostTick(vehicle)
        return
    end

    if soundType == 'turbo' then
        useNativeBoost = true
        StartBoostTick(vehicle)
        StartScreenEffect('RaceTurbo', 0, false)
        useScreenEffect = true
        return
    end

    if nitroSoundId then return end
    local sound = NitroSounds[soundType] or NitroSounds.flare
    nitroSoundId = GetSoundId()
    PlaySoundFromEntity(nitroSoundId, sound.name, vehicle, sound.ref, false, 0)
end

local function StopNitroSound(vehicle)
    boostTickActive = false

    if useScreenEffect then
        StopScreenEffect('RaceTurbo')
        useScreenEffect = false
    end

    useNativeBoost = false

    if nitroSoundId then
        StopSound(nitroSoundId)
        ReleaseSoundId(nitroSoundId)
        nitroSoundId = nil
    end
end

-- ═══════════════════════════════════════════════════════════════
-- NITRO CORE LOGIC
-- ═══════════════════════════════════════════════════════════════

--- Send nitro state to NUI for HUD display
local function UpdateNitroHUD()
    NuiMessage('updateSpeedometer', {
        hasNitro = nitroState.isInstalled,
        nitroLevel = nitroState.level,
        nitroActive = nitroState.isActive,
    })
end

--- Check if vehicle has nitro installed (from state bag or server)
---@param vehicle number Vehicle entity handle
local function CheckNitroInstallation(vehicle)
    if not vehicle or vehicle == 0 then return end

    local plate = GetVehiclePlate(vehicle)
    if not plate then return end
    if nitroState.currentPlate == plate and nitroState.isInstalled then return end

    local vehicleState = Entity(vehicle).state
    if vehicleState and vehicleState.nitroInstalled then
        nitroState.isInstalled = true
        nitroState.level = vehicleState.nitroLevel or 100
        nitroState.currentPlate = plate
        UpdateNitroHUD()
        return
    end

    local result = RPC.execute('vehicleFeatures:getNitroData', plate)
    if result and result.installed then
        nitroState.isInstalled = true
        nitroState.level = result.level or 100
        nitroState.currentPlate = plate
    else
        nitroState.isInstalled = false
        nitroState.level = 0
        nitroState.currentPlate = plate
    end
    UpdateNitroHUD()
end

--- Install or refill nitro on current vehicle (requires nitro kit item)
local function InstallOrRefillNitro()
    local vehicle = Utils.GetCurrentVehicle()
    if vehicle == 0 then
        Notify(L('vehicle.not_in_vehicle'), 'error')
        return
    end

    local seat = cache.seat
    if seat == nil then seat = GetPedInVehicleSeat(vehicle, -1) == cache.ped and -1 or 0 end
    if seat ~= -1 then
        Notify(L('vehicle.nitro_driver_only'), 'error')
        return
    end

    local plate = GetVehiclePlate(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local result = RPC.execute('vehicleFeatures:useNitroKit', netId, plate, nitroState.isInstalled)

    if result and result.success then
        nitroState.isInstalled = true
        nitroState.level = result.level or 100
        nitroState.currentPlate = plate
        Notify(result.message, 'success')
        UpdateNitroHUD()
        PlaySoundFrontend(-1, 'PICK_UP_WEAPON', 'HUD_FRONTEND_WEAPONS_PICKUPS_SOUNDSET', false)
    else
        Notify(result and result.message or L('common.failed'), 'error')
    end
end

--- Sync nitro state to server (for other players to see effects)
---@param vehicle number Vehicle entity handle
local function SyncNitroState(vehicle)
    if not vehicle or vehicle == 0 then return end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    RPC.execute('vehicleFeatures:syncNitroState', netId, nitroState.isActive, nitroState.level)
end

--- Activate nitro boost on vehicle
---@param vehicle number Vehicle entity handle
---@return boolean True if nitro was activated
local function StartNitro(vehicle)
    if nitroState.isActive then return false end
    if nitroState.level <= 0 then return false end

    local now = GetGameTimer()
    if now - nitroState.lastEmptyTime < (Cfg.Cooldown * 1000) then return false end

    nitroState.isActive = true
    nitroState.lastBackfire = 0

    SetVehicleCheatPowerIncrease(vehicle, Cfg.BoostPower)
    SetVehicleEnginePowerMultiplier(vehicle, Cfg.BoostPower * 10.0)
    SetVehicleEngineTorqueMultiplier(vehicle, Cfg.BoostPower * 5.0)
    StartExhaustFlame(vehicle)
    StartNitroSound(vehicle)
    SyncNitroState(vehicle)

    return true
end

--- Deactivate nitro boost on vehicle
---@param vehicle number Vehicle entity handle
---@param wasEmpty boolean Whether tank was depleted (triggers cooldown)
local function StopNitro(vehicle, wasEmpty)
    if not nitroState.isActive then return end

    nitroState.isActive = false
    if wasEmpty then nitroState.lastEmptyTime = GetGameTimer() end

    SetVehicleCheatPowerIncrease(vehicle, 1.0)
    SetVehicleEnginePowerMultiplier(vehicle, 1.0)
    SetVehicleEngineTorqueMultiplier(vehicle, 1.0)
    StopExhaustFlame()
    StopNitroSound(vehicle)
    PlayBackfireEffect(vehicle)
    SyncNitroState(vehicle)
    UpdateNitroHUD()
end

-- ═══════════════════════════════════════════════════════════════
-- NITRO THREAD
-- ═══════════════════════════════════════════════════════════════

local nitroThreadActive = false

local function StartNitroThread()
    if nitroThreadActive then return end
    nitroThreadActive = true

    CreateThread(function()
        local vehicle = Utils.GetCurrentVehicle()
        local lastHudUpdate = 0

        if vehicle ~= 0 then CheckNitroInstallation(vehicle) end

        while nitroThreadActive do
            vehicle = Utils.GetCurrentVehicle()
            if vehicle == 0 then
                nitroThreadActive = false
                break
            end

            local now = GetGameTimer()
            local speed = GetEntitySpeed(vehicle) * 3.6
            local isDriver = Utils.IsDriver()

            if nitroState.isActive then
                if Cfg.Effects.PurgeWhileMoving or speed < 5 then
                    StartPurgeEffect(vehicle)
                else
                    StopPurgeEffect()
                end

                local dt = 100 / 1000
                nitroState.level = nitroState.level - (Cfg.UseRate * dt)
                SetVehicleCurrentRpm(vehicle, math.min(1.0, GetVehicleCurrentRpm(vehicle) + 0.1))

                if Cfg.Effects.Backfire and now - nitroState.lastBackfire > 200 then
                    nitroState.lastBackfire = now
                    PlayBackfireEffect(vehicle)
                end

                if nitroState.level <= 0 then
                    nitroState.level = 0
                    StopNitro(vehicle, true)
                elseif not IsControlPressed(0, 21) then
                    StopNitro(vehicle, false)
                end

                Wait(100)
            else
                -- Nitro not installed = longer sleep
                if not nitroState.isInstalled then
                    Wait(500)
                else
                    local shiftHeld = IsControlPressed(0, 21)
                    if shiftHeld and isDriver and nitroState.level > 0 then
                        StartNitro(vehicle)
                        nitroIdleInterval.onChanged()
                        if Cfg.Effects.PurgeWhileMoving or speed < 5 then StartPurgeEffect(vehicle) end
                    else
                        StopPurgeEffect()
                        nitroIdleInterval.onStable()
                    end
                    Wait(nitroIdleInterval.current)
                end
            end

            if now - lastHudUpdate > 500 then
                lastHudUpdate = now
                UpdateNitroHUD()
            end
        end
    end)
end

local function StopNitroThread()
    nitroThreadActive = false
    local vehicle = cache.vehicle
    StopExhaustFlame()
    StopPurgeEffect()
    StopNitroSound(vehicle)
    if vehicle and vehicle ~= 0 then SetVehicleCheatPowerIncrease(vehicle, 1.0) end
    nitroState.isActive = false
    nitroState.isInstalled = false
    nitroState.level = 0
    nitroState.currentPlate = nil
end

-- ═══════════════════════════════════════════════════════════════
-- NITRO EFFECT SYNC (Other players)
-- ═══════════════════════════════════════════════════════════════

local otherVehicleNitroEffects = {}

AddStateBagChangeHandler('nitroActive', nil, function(bagName, key, value, _reserved, replicated)
    if not bagName:find('entity:') then return end

    local netId = tonumber(bagName:match('entity:(%d+)'))
    if not netId then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or vehicle == cache.vehicle then return end

    if value then
        if not otherVehicleNitroEffects[netId] then
            local dict = 'veh_xs_vehicle_mods'
            if not Utils.EnsureParticleFxAsset(dict, 2000) then return end
            UseParticleFxAsset(dict)

            local exhaustBone = GetEntityBoneIndexByName(vehicle, 'exhaust')
            if exhaustBone == -1 then exhaustBone = GetEntityBoneIndexByName(vehicle, 'exhaust_2') end

            local scale = Cfg.FlameScale or 1.0
            local ptfx
            if exhaustBone ~= -1 then
                ptfx = StartParticleFxLoopedOnEntityBone('veh_nitrous', vehicle, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, exhaustBone, scale, false, false, false)
            else
                ptfx = StartParticleFxLoopedOnEntity('veh_nitrous', vehicle, 0.0, -2.5, 0.3, 0.0, 0.0, 0.0, scale, false, false, false)
            end

            if ptfx then otherVehicleNitroEffects[netId] = ptfx end
        end
    else
        if otherVehicleNitroEffects[netId] then
            StopParticleFxLooped(otherVehicleNitroEffects[netId], false)
            otherVehicleNitroEffects[netId] = nil
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- EVENTS & EXPORTS
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('codem-hud:client:vehicleStateChanged', function(inVehicle)
    if inVehicle then
        StartNitroThread()
    else
        StopNitroThread()
    end
end)

RegisterNetEvent('codem-hud:client:useNitroKit', function() InstallOrRefillNitro() end)

-- Export backfire effect for transmission.lua
exports('PlayBackfireEffect', PlayBackfireEffect)
