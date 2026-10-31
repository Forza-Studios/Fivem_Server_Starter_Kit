--[[
    SIREN DETECTION SYSTEM
    Detects police/EMS vehicles for siren UI overlay
    Config: shared/config.lua -> Config.VehicleFeatures.Siren
]]

local Cfg = Config.VehicleFeatures.Siren
if not Cfg or not Cfg.Enabled then return end

-- Adaptive interval
local sirenInterval = Utils.CreateAdaptiveInterval({ min = 300, max = 1000, step = 100, threshold = 3 })

-- Pre-hash siren vehicle models for performance
local PoliceSirenModels = {}
local EmsSirenModels = {}
do
    local policeNames = Config.VehicleModels.Police or {}
    local emsNames = Config.VehicleModels.EMS or {}
    for _, name in ipairs(policeNames) do PoliceSirenModels[joaat(name)] = true end
    for _, name in ipairs(emsNames) do EmsSirenModels[joaat(name)] = true end
end

-- STATE
local sirenState = { hasSiren = false, sirenType = 'police', isActive = false }
local sirenThreadActive = false

-- ═══════════════════════════════════════════════════════════════
-- SIREN DETECTION
-- ═══════════════════════════════════════════════════════════════

--- Detect if vehicle is a siren-equipped emergency vehicle
---@param vehicle number Vehicle entity handle
---@return boolean hasSiren, string|nil sirenType ('police' or 'ems')
local function DetectSirenVehicle(vehicle)
    if not vehicle or vehicle == 0 then return false, nil end

    local model = GetEntityModel(vehicle)
    local vehicleClass = GetVehicleClass(vehicle)

    if PoliceSirenModels[model] then return true, 'police' end
    if EmsSirenModels[model] then return true, 'ems' end
    if vehicleClass == Constants.VehicleClass.EMERGENCY then return true, 'police' end

    return false, nil
end

--- Update siren state and send to NUI
---@param vehicle number Vehicle entity handle
local function UpdateSirenState(vehicle)
    local hasSiren, sirenType = DetectSirenVehicle(vehicle)
    local normalizedType = sirenType or 'police'

    if hasSiren ~= sirenState.hasSiren or normalizedType ~= sirenState.sirenType then
        sirenState.hasSiren = hasSiren
        sirenState.sirenType = sirenType or 'police'
        NuiMessage('updateSpeedometer', { isSiren = hasSiren, sirenType = sirenType or 'police' })
    end

    if hasSiren then
        local isActive = IsVehicleSirenOn(vehicle)
        if isActive ~= sirenState.isActive then
            sirenState.isActive = isActive
            NuiMessage('updateSpeedometer', { sirenActive = isActive })
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- SIREN THREAD
-- ═══════════════════════════════════════════════════════════════

local function StartSirenThread()
    if sirenThreadActive then
        sirenThreadActive = false
        Wait(50)
    end
    sirenThreadActive = true

    local vehicle = Utils.GetCurrentVehicle()
    if vehicle ~= 0 then
        local hasSiren, sirenType = DetectSirenVehicle(vehicle)
        sirenState.hasSiren = hasSiren
        sirenState.sirenType = sirenType or 'police'
        sirenState.isActive = hasSiren and IsVehicleSirenOn(vehicle) or false
        NuiMessage('updateSpeedometer', { isSiren = sirenState.hasSiren, sirenType = sirenState.sirenType, sirenActive = sirenState.isActive })
    end

    CreateThread(function()
        while sirenThreadActive do
            vehicle = Utils.GetCurrentVehicle()
            if vehicle == 0 then
                sirenThreadActive = false
                break
            end
            local prevActive = sirenState.isActive
            UpdateSirenState(vehicle)
            if sirenState.isActive ~= prevActive then
                sirenInterval.onChanged()
            else
                sirenInterval.onStable()
            end
            Wait(sirenInterval.current)
        end
    end)
end

local function StopSirenThread()
    sirenThreadActive = false
    sirenState.hasSiren = false
    sirenState.sirenType = 'police'
    sirenState.isActive = false
    NuiMessage('updateSpeedometer', { isSiren = false, sirenType = 'police', sirenActive = false })
end

-- ═══════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('codem-hud:client:vehicleStateChanged', function(inVehicle)
    if inVehicle then
        StartSirenThread()
        UpdateSirenState(cache.vehicle)
    else
        StopSirenThread()
    end
end)
