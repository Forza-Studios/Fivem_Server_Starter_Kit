--[[
    Vehicle Mods System
    Changes speedometer style and vehicle physics based on selected mod
    Comfort → Default speedometer
    Drift → Drift speedometer
    Sport → Yolante speedometer
    Sport Plus → Ferrante speedometer
]]

if not Config.VehicleMods or not Config.VehicleMods.Enabled then return end

-- ═══════════════════════════════════════════════════════════════
-- SPEEDOMETER TYPE MAPPING
-- ═══════════════════════════════════════════════════════════════

local ModSpeedometerMap = {
    ['comfort'] = 'default',
    ['drift'] = 'drift',
    ['sport'] = 'yolante',
    ['sport-plus'] = 'ferrante',
}

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════

local currentMod = 'comfort'
local installedMods = { comfort = true }
local isInstalling = false
local originalHandling = {}
local lastVehicle = nil

-- Global function to check if drift mode is active (used by speedometer for drift counter)
function IsDriftModeActive()
    return currentMod == 'drift'
end

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════

local function GetVehiclePlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    local plate = GetVehicleNumberPlateText(vehicle)
    return plate and plate:gsub('%s+', '') or nil
end

local function ConvertInstalledMods(modsTable)
    -- Convert array to hashmap
    local result = {}
    if type(modsTable) == 'table' then
        for _, mod in ipairs(modsTable) do
            result[mod] = true
        end
    end
    result.comfort = true
    return result
end

local function GetInstalledModsArray()
    local mods = {}
    for mod in pairs(installedMods) do
        mods[#mods + 1] = mod
    end
    return mods
end

local function SaveVehicleMods(vehicle)
    local plate = GetVehiclePlate(vehicle)
    if not plate then return end

    CreateThread(function()
        RPC.execute('vehicleMods:save', plate, currentMod, GetInstalledModsArray())
    end)
end

local function LoadVehicleMods(vehicle)
    local plate = GetVehiclePlate(vehicle)
    if not plate then
        currentMod = 'comfort'
        installedMods = { comfort = true }
        return
    end

    local data = RPC.execute('vehicleMods:load', plate)
    if data then
        currentMod = data.currentMod or 'comfort'
        installedMods = ConvertInstalledMods(data.installedMods)
    else
        currentMod = 'comfort'
        installedMods = { comfort = true }
    end
end

local function UpdateNUI()
    NuiMessage('vehicleMods:updateState', {
        currentMod = currentMod,
        installedMods = GetInstalledModsArray(),
    })
    -- Only override speedometer type for special mods (drift, sport, sport-plus)
    -- For 'comfort' mode, let the user's selected speedometer from setup be used
    if currentMod ~= 'comfort' then
        local speedometerType = ModSpeedometerMap[currentMod] or 'default'
        NuiMessage('setSpeedometerType', { type = speedometerType })
    end
end

-- ═══════════════════════════════════════════════════════════════
-- VEHICLE PHYSICS
-- ═══════════════════════════════════════════════════════════════

-- All handling fields used by any mode (drift, sport, sport-plus)
local allHandlingFields = {
    'fInitialDriveMaxFlatVel', 'fDriveInertia', 'fInitialDriveForce',
    'fTractionCurveMax', 'fTractionCurveMin', 'fTractionCurveLateral',
    'fLowSpeedTractionLossMult', 'fTractionLossMult',
    'fTractionBiasFront', 'fSuspensionForce', 'fAntiRollBarForce',
    'fSuspensionReboundDamp', 'fSuspensionCompDamp', 'fSteeringLock',
    'fHandBrakeForce', 'fInitialDragCoeff', 'fBrakeBiasFront'
}

local function StoreOriginalHandling(vehicle)
    if originalHandling[vehicle] or not DoesEntityExist(vehicle) then return end

    originalHandling[vehicle] = {}
    for _, field in ipairs(allHandlingFields) do
        originalHandling[vehicle][field] = GetVehicleHandlingFloat(vehicle, 'CHandlingData', field)
    end
end

local function ApplyPhysics(vehicle, mod)
    if not Config.VehicleMods.ApplyPhysics then return end
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    StoreOriginalHandling(vehicle)
    local original = originalHandling[vehicle]
    if not original then return end

    if mod == 'comfort' then
        -- Reset to original values
        for key, value in pairs(original) do
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', key, value)
        end
        -- Reset engine power
        SetVehicleEnginePowerMultiplier(vehicle, 0.0)

    else
        -- Drift/Sport/Sport-Plus: All use multiplier-based system from config
        local physics = Config.VehicleMods.Physics[mod]
        if physics then
            for key, multiplier in pairs(physics) do
                if original[key] then
                    SetVehicleHandlingFloat(vehicle, 'CHandlingData', key, original[key] * multiplier)
                end
            end
        end
        SetVehicleEnginePowerMultiplier(vehicle, 0.0)
    end
end

local function ResetPhysics(vehicle)
    if not vehicle or vehicle == 0 then return end

    local original = originalHandling[vehicle]
    if original and DoesEntityExist(vehicle) then
        for key, value in pairs(original) do
            SetVehicleHandlingFloat(vehicle, 'CHandlingData', key, value)
        end
    end
    originalHandling[vehicle] = nil
end

-- ═══════════════════════════════════════════════════════════════
-- MOD SELECTION & INSTALLATION
-- ═══════════════════════════════════════════════════════════════

local function SelectMod(mod)
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 or mod == currentMod then return end

    currentMod = mod
    ApplyPhysics(vehicle, mod)
    SaveVehicleMods(vehicle)
    UpdateNUI()
end

local installCancelled = false

local function CancelInstall()
    if isInstalling then
        installCancelled = true
        isInstalling = false
        ClearPedTasks(cache.ped)
        local vehicle = cache.vehicle
        if vehicle and vehicle ~= 0 then
            FreezeEntityPosition(vehicle, false)
        end
        NuiMessage('vehicleMods:installProgress', { progress = 0 })
    end
end

local function InstallMod(mod)
    if isInstalling or mod == 'comfort' or installedMods[mod] then
        return false
    end

    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then
        Notify(L('mods.not_in_vehicle'), 'error')
        return false
    end

    -- Pre-check items on server before starting installation
    if Config.VehicleMods.RequireItems then
        local hasItems = RPC.execute('vehicleMods:checkItems', mod)
        if not hasItems then
            Notify(L('mods.missing_items'), 'error')
            NuiMessage('vehicleMods:installFailed', {})
            return false
        end
    end

    -- Block installation if vehicle is moving
    local speed = GetEntitySpeed(vehicle) * 3.6
    if speed > 5 then
        Notify(L('mods.stop_vehicle'), 'error')
        NuiMessage('vehicleMods:installFailed', {})
        return false
    end

    isInstalling = true
    installCancelled = false
    local installTime = (Config.VehicleMods.InstallTime[mod] or 5) * 1000
    local startTime = GetGameTimer()

    -- Freeze vehicle
    FreezeEntityPosition(vehicle, true)

    -- Play animation
    RequestAnimDict('mini@repair')
    while not HasAnimDictLoaded('mini@repair') do Wait(10) end
    TaskPlayAnim(cache.ped, 'mini@repair', 'fixing_a_player', 8.0, -8.0, -1, 1, 0, false, false, false)

    -- Progress loop (non-blocking with cancel check)
    while isInstalling and not installCancelled do
        local progress = math.min(100, ((GetGameTimer() - startTime) / installTime) * 100)
        NuiMessage('vehicleMods:installProgress', { progress = progress })
        if progress >= 100 then break end
        Wait(50)
    end

    -- Check if cancelled
    if installCancelled then
        isInstalling = false
        return false
    end

    -- Stop animation
    ClearPedTasks(cache.ped)
    FreezeEntityPosition(vehicle, false)

    -- Remove items on server
    local success = RPC.execute('vehicleMods:removeItems', mod)
    if success then
        installedMods[mod] = true
        currentMod = mod
        ApplyPhysics(vehicle, mod)
        SaveVehicleMods(vehicle)
        NuiMessage('vehicleMods:installComplete', { mod = mod })
        Notify(L('mods.installed', mod), 'success')
    else
        Notify(L('mods.installation_failed'), 'error')
        NuiMessage('vehicleMods:installProgress', { progress = 0 })
    end

    isInstalling = false
    return success
end

-- ═══════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('vehicleMods:selectMod', function(data, cb)
    local mod = data.mod
    if not mod then return cb({ success = false }) end

    if installedMods[mod] then
        SelectMod(mod)
        cb({ success = true })
    else
        local success = InstallMod(mod)
        cb({ success = success })
    end
end)

RegisterNUICallback('vehicleMods:installMod', function(data, cb)
    if not data.mod then return cb({ success = false }) end
    cb({ success = InstallMod(data.mod) })
end)

RegisterNUICallback('vehicleMods:cancelInstall', function(data, cb)
    CancelInstall()
    cb({ success = true })
end)

-- ═══════════════════════════════════════════════════════════════
-- VEHICLE EVENTS
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('codem-hud:client:vehicleStateChanged', function(inVehicle)
    if inVehicle then
        local vehicle = cache.vehicle
        lastVehicle = vehicle
        LoadVehicleMods(vehicle)
        ApplyPhysics(vehicle, currentMod)
        UpdateNUI()
    else
        -- Cancel any ongoing installation
        CancelInstall()
        -- Save before exiting
        if lastVehicle and DoesEntityExist(lastVehicle) then
            SaveVehicleMods(lastVehicle)
            ResetPhysics(lastVehicle)
        end
        lastVehicle = nil
        NuiMessage('vehicleMods:reset', {})
    end
end)


-- ═══════════════════════════════════════════════════════════════
-- COMMAND
-- ═══════════════════════════════════════════════════════════════

local function OpenVehicleModsPanel()
    if not cache.inVehicle or not cache.vehicle or cache.vehicle == 0 then
        Notify(L('mods.not_in_vehicle'), 'error')
        return
    end
    NuiMessage('openVehicleMods', {})
    ToggleHudFocus()
end

local cmd = Config.VehicleMods.Command
if cmd and cmd ~= '' then
    RegisterCommand(cmd, OpenVehicleModsPanel, false)

    local key = Config.VehicleMods.Keybind
    if key and key ~= '' and key ~= false then
        RegisterKeyMapping(cmd, Config.VehicleMods.KeybindDescription or 'Open Vehicle Mods Panel', 'keyboard', key)
    end
end

RegisterCommand('testminimap', function()
    DisplayRadar(true)
end)

debugPrint('[VehicleMods] Module loaded')
