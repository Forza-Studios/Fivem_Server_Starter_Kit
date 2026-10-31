if not Config.FLIR.Enable then return end
FlirActive = false

DecorRegister('sp_on', 2)
DecorRegister('sp_rx', 3)
DecorRegister('sp_rz', 3)
DecorRegister('sp_dist', 3)
DecorRegister('sp_rad', 3)
DecorRegister('sp_brt', 3)
DecorRegister('sp_hrd', 3)

local function SetInventoryBusy(busy)
    LocalPlayer.state:set('invBusy', busy, false)
    LocalPlayer.state:set('inv_busy', busy, false)
end

exports('IsFlirActive', function()
    return FlirActive
end)
local FlirVisionMode = 'NRM'
local FlirCameraMode = 'HDEO'

-- Build vision modes list from config (only enabled ones)
-- Normal mode is always included
local VM = Config.FLIR and Config.FLIR.VisionModes or {}
local VisionModes = {}
if VM.Thermal ~= false then VisionModes[#VisionModes + 1] = 'THRML' end
VisionModes[#VisionModes + 1] = 'NRM'  -- Always enabled
if VM.Negative ~= false then VisionModes[#VisionModes + 1] = 'NGTV' end

local CameraModes = { 'HDEO', 'FOCUS', 'LOCK' }

local C = Config.FLIR or {}
local FOV = C.FOV or {}
local CAM = C.Camera or {}
local K = C.Keys or {}
local SPOT = C.Spotlight or {}
local TINFO = C.TargetInfo or {}

local FlirCam = nil
local FlirRotX = -30.0
local FlirRotZ = 0.0
local FlirFov = FOV.Default or 60.0
local FlirTargetFov = FlirFov
local FlirFovMin = FOV.Min or 10.0
local FlirFovMax = FOV.Max or 90.0
local FlirSensitivity = C.Sensitivity or 4.0
local FlirLerpSpeed = C.LerpSpeed or 0.85
local FlirZoomSpeed = C.ZoomSpeed or 0.12
local FlirLockSpeed = C.LockSpeed or 0.08
local FlirSounds = C.Sounds ~= false

local LockedEntity = nil
local PendingLockEntity = nil
local SpotlightOn = false
local FlirJPressed = false
local FlirCloseCooldown = 0
local FlirCamIsHigh = false
local FlirKeysDown = {}
local FlirKeysJustDown = {}
local FlirCursorActive = false

-- Normalize JavaScript key names to uppercase labels
local JS_KEY_NORMALIZE = {
    ['Escape'] = 'ESC', ['Tab'] = 'TAB',
    ['ArrowUp'] = 'UP', ['ArrowDown'] = 'DOWN',
    ['ArrowLeft'] = 'LEFT', ['ArrowRight'] = 'RIGHT',
    [' '] = 'SPACE', ['Enter'] = 'ENTER',
}
local function normalizeJsKey(k)
    return JS_KEY_NORMALIZE[k] or string.upper(k)
end

-- Build action map from config keys/labels
local FlirKeyAction = {}
local function registerFlirKey(cfg, action)
    if not cfg then return end
    local label = cfg.key and string.upper(cfg.key) or cfg.label
    if label then FlirKeyAction[label] = action end
end
registerFlirKey(K.Exit, 'exit')
registerFlirKey(K.VisionNext, 'visionNext')
registerFlirKey(K.VisionPrev, 'visionPrev')
registerFlirKey(K.Camera, 'camera')
registerFlirKey(K.ZoomReset, 'zoomReset')
registerFlirKey(K.Lock, 'lock')
registerFlirKey(K.ResetView, 'resetView')
registerFlirKey(K.Spotlight, 'spotlight')
registerFlirKey(K.SpotDistUp, 'spotDistUp')
registerFlirKey(K.SpotDistDown, 'spotDistDown')
registerFlirKey(K.SpotRadiusUp, 'spotRadiusUp')
registerFlirKey(K.SpotRadiusDown, 'spotRadiusDown')
local FlirTargetRotX = -30.0
local FlirTargetRotZ = 0.0
local LockObstructedTime = 0.0  -- How long target has been obstructed
local LockObstructedMax = 3.0   -- Max seconds before losing lock (tolerates trees, poles, etc.)

-- Optimization: Cache raycast results to reduce CPU usage
local LastObstructionCheck = 0
local LastObstructionResult = false
local ObstructionCheckInterval = 150  -- ms between raycast checks

local PitchMin = C.Pitch and C.Pitch.Min or -89.0
local PitchMax = C.Pitch and C.Pitch.Max or 20.0

-- Spotlight config
local SpotDistance = SPOT.Distance or 120.0
local SpotBrightness = SPOT.Brightness or 15.0
local SpotHardness = SPOT.Hardness or 3.0
local SpotRadius = SPOT.Radius or 12.0
local SpotDistStep = SPOT.DistanceStep or 10.0
local SpotRadiusStep = SPOT.RadiusStep or 1.0
local SpotDistMin = SPOT.DistanceMin or 30.0
local SpotDistMax = SPOT.DistanceMax or 300.0
local SpotRadiusMin = SPOT.RadiusMin or 3.0
local SpotRadiusMax = SPOT.RadiusMax or 30.0

-- Street names 3D config
local SNAMES = C.StreetNames or {}
local StreetNamesEnabled = SNAMES.Enable ~= false
local StreetNamesMaxNodes = SNAMES.MaxNodes or 40
local StreetNamesMaxDist = SNAMES.MaxDistance or 350.0
local StreetNamesInterval = SNAMES.UpdateInterval or 1000
local StreetNamesFontScale = SNAMES.FontScale or 0.45
local StreetLabels = {}

-- Target info config
local ShowPlayerName = TINFO.ShowPlayerName ~= false
local ShowPlayerMugshot = TINFO.ShowPlayerMugshot ~= false
local ShowPlayerId = TINFO.ShowPlayerId ~= false
local ShowVehicleModel = TINFO.ShowVehicleModel ~= false
local ShowVehiclePlate = TINFO.ShowVehiclePlate ~= false
local ShowVehicleSpeed = TINFO.ShowVehicleSpeed ~= false
local ShowVehicleHealth = TINFO.ShowVehicleHealth ~= false
local ShowVehicleHeading = TINFO.ShowVehicleHeading ~= false
local ShowDistance = TINFO.ShowDistance ~= false
local ScanDelay = TINFO.ScanDelay or 1.5
local HideMaskedPlayer = TINFO.HideMaskedPlayer ~= false
local SignalJammerCfg = TINFO.SignalJammer or {}
local SignalJammerEnabled = SignalJammerCfg.Enabled ~= false

-- Cache for signal jammer check results (serverId -> { hasJammer, time })
local SignalJammerCache = {}
local JAMMER_CACHE_TIME = 20000  -- Cache result for 20 seconds

-- Non-mask prop IDs (these are NOT masks - glasses, hats, etc.)
local NonMaskProps = {
    [1] = true, [12] = true, [16] = true, [23] = true, [24] = true, [25] = true,
    [26] = true, [27] = true, [28] = true, [29] = true, [31] = true, [32] = true,
    [33] = true, [34] = true, [35] = true, [36] = true, [38] = true, [42] = true,
    [50] = true, [51] = true, [52] = true, [53] = true, [57] = true, [62] = true,
    [63] = true, [64] = true, [65] = true, [66] = true, [67] = true, [68] = true,
    [74] = true, [75] = true, [76] = true, [77] = true, [78] = true, [89] = true,
    [135] = true, [171] = true, [176] = true, [182] = true, [183] = true, [184] = true,
    [210] = true, [294] = true, [300] = true, [301] = true, [302] = true, [306] = true,
    [308] = true, [311] = true, [316] = true, [322] = true, [333] = true, [342] = true,
    [343] = true, [344] = true, [345] = true, [347] = true, [348] = true, [349] = true,
    [352] = true, [353] = true, [354] = true, [355] = true, [356] = true, [357] = true,
    [358] = true, [359] = true, [360] = true, [363] = true, [364] = true, [365] = true,
    [366] = true, [367] = true, [368] = true, [369] = true, [370] = true, [371] = true,
    [372] = true, [373] = true, [374] = true, [375] = true
}

-- Check if ped is wearing a mask
local function IsPedWearingMask(ped)
    if not ped or not DoesEntityExist(ped) then return false end
    local componentId = GetPedDrawableVariation(ped, 1)  -- Component 1 = mask
    if componentId ~= -1 and componentId ~= 0 and not NonMaskProps[componentId] then
        return true
    end
    return false
end

-- Check if player has signal jammer (async with cache)
local function HasSignalJammer(serverId, callback)
    if not SignalJammerEnabled or not serverId then
        callback(false)
        return
    end

    local now = GetGameTimer()
    local cached = SignalJammerCache[serverId]
    if cached and (now - cached.time) < JAMMER_CACHE_TIME then
        callback(cached.hasJammer)
        return
    end

    -- RPC call to server (async in thread)
    CreateThread(function()
        local success, hasJammer = pcall(RPC.execute, 'codem-hud:hasSignalJammer', serverId)
        if success then
            SignalJammerCache[serverId] = { hasJammer = hasJammer, time = GetGameTimer() }
            callback(hasJammer)
        else
            callback(false)
        end
    end)
end

-- Sync version using cache only (for BuildTargetData)
local function HasSignalJammerCached(serverId)
    if not SignalJammerEnabled or not serverId then return false end
    local cached = SignalJammerCache[serverId]
    if cached then return cached.hasJammer end
    return false
end

-- Scan progress tracking
local ScanEntity = nil
local ScanTimer = 0.0
local ScanComplete = false
local ScannedEntities = {}

-- Cached camera offsets
local CAM_HIGH = CAM.High or {}
local CAM_LOW = CAM.Low or {}
local CAM_HIGH_X = CAM_HIGH.x or 0.0
local CAM_HIGH_Y = CAM_HIGH.y or 0.0
local CAM_HIGH_Z = CAM_HIGH.z or -2.0
local CAM_HIGH_PITCH = CAM_HIGH.pitch or -30.0
local CAM_LOW_X = CAM_LOW.x or 0.0
local CAM_LOW_Y = CAM_LOW.y or 2.0
local CAM_LOW_Z = CAM_LOW.z or 0.5
local CAM_LOW_PITCH = CAM_LOW.pitch or -5.0
local CAM_SWITCH_H = CAM.SwitchHeight or 5.0

-- Keybind controls
local KB_EXIT       = K.Exit and K.Exit.control or 200
local KB_VISION     = K.VisionNext and K.VisionNext.control or 182
local KB_CAMERA     = K.Camera and K.Camera.control or 37
local KB_ZOOM_RESET = K.ZoomReset and K.ZoomReset.control or 45
local KB_LOCK       = K.Lock and K.Lock.control or 245
local KB_RESET_VIEW = K.ResetView and K.ResetView.control or 47
local KB_SPOTLIGHT  = K.Spotlight and K.Spotlight.control or 38

-- AllowedModels from config -> hash lookup
local FlirAllowedModels = {}
for _, name in ipairs(C.AllowedModels or {}) do
    FlirAllowedModels[GetHashKey(name)] = true
end

-- Localized math functions
local floor = math.floor
local rad = math.rad
local sin = math.sin
local cos = math.cos
local abs = math.abs
local atan2 = math.atan2
local sqrt = math.sqrt
local max = math.max
local min = math.min
local pi = math.pi

-- Pre-built weather map
local WeatherMap = {
    [`CLEAR`] = 'CLEAR', [`EXTRASUNNY`] = 'SUNNY', [`CLOUDS`] = 'CLOUDY',
    [`OVERCAST`] = 'OVERCAST', [`RAIN`] = 'RAIN', [`CLEARING`] = 'CLEARING',
    [`THUNDER`] = 'STORM', [`SMOG`] = 'SMOG', [`FOGGY`] = 'FOGGY',
    [`XMAS`] = 'SNOW', [`SNOWLIGHT`] = 'SNOW', [`BLIZZARD`] = 'BLIZZARD',
    [`NEUTRAL`] = 'NEUTRAL', [`HALLOWEEN`] = 'HALLOWEEN',
}

-- Player info cache: { [serverId] = { name, mugshot, handle, pending, namePending } }
local PlayerInfoCache = {}

-- Forward declarations
local ResetScan, GetKeybindHints, ClearVisionMode, CreateFlirCamera, PlayFlirSound

function GetKeybindHints()
    local hints = {}
    local order = {
        { k = 'Exit',       l = L('flir.hint_exit') },
        { k = 'VisionNext', l = L('flir.hint_vision') },
        { k = 'Camera',     l = L('flir.hint_camera') },
        { k = 'Zoom',       l = L('flir.hint_zoom') },
        { k = 'ZoomReset',  l = L('flir.hint_zoom_reset') },
        { k = 'Lock',       l = L('flir.hint_lock') },
        { k = 'ResetView',  l = L('flir.hint_reset_view') },
        { k = 'Spotlight',  l = L('flir.hint_spotlight') },
        { k = 'SpotDistUp', l = L('flir.hint_spot_distance') },
        { k = 'SpotRadiusUp', l = L('flir.hint_spot_radius') },
    }
    for _, entry in ipairs(order) do
        local kb = K[entry.k]
        local key = kb and kb.label or entry.k
        if entry.k == 'VisionNext' and K.VisionPrev then
            key = (K.VisionPrev.label or 'J') .. ' / ' .. key
        elseif entry.k == 'SpotDistUp' then
            local up = K.SpotDistUp and K.SpotDistUp.label or 'UP'
            local down = K.SpotDistDown and K.SpotDistDown.label or 'DOWN'
            key = up .. ' / ' .. down
        elseif entry.k == 'SpotRadiusUp' then
            local up = K.SpotRadiusUp and K.SpotRadiusUp.label or 'RIGHT'
            local down = K.SpotRadiusDown and K.SpotRadiusDown.label or 'LEFT'
            key = up .. ' / ' .. down
        end
        hints[#hints + 1] = { key = key, label = entry.l }
    end
    return hints
end

-- Shared FLIR activation logic
-- Returns: 'ok', 'no_vehicle', 'not_heli', 'not_allowed', or 'already_active'
local function ActivateFlir()
    if FlirActive then return 'already_active' end
    local vehicle = cache.vehicle
    if not vehicle then return 'no_vehicle' end
    local model = GetEntityModel(vehicle)
    if not IsThisModelAHeli(model) then return 'not_heli' end
    if not FlirAllowedModels[model] then return 'not_allowed' end

    FlirActive = true
    FlirVisionMode = 'NRM'
    FlirCameraMode = 'HDEO'
    LockedEntity = nil
    ResetScan()
    ClearVisionMode()
    DisplayRadar(false)
    SetInventoryBusy(true)
    SetNuiFocus(true, false)
    SetNuiFocusKeepInput(true)
    CreateFlirCamera(vehicle)
    PlayFlirSound("SELECT")

    -- Hide HUD bars and show big minimap
    NuiMessage('flir:setHudVisibility', { visible = false })
    SetRadarBigmapEnabled(true, false)

    NuiMessage('flir:open', { hints = GetKeybindHints() })
    return 'ok'
end

RegisterCommand('+flir_access', function() ActivateFlir() end, false)
RegisterCommand('-flir_access', function() end, false)
RegisterKeyMapping('+flir_access', 'FLIR Quick Access', 'keyboard', K.Access and K.Access.key or 'f10')

RegisterCommand('+flir_vision_prev', function()
    if FlirActive then FlirJPressed = true end
end, false)
RegisterCommand('-flir_vision_prev', function() end, false)
RegisterKeyMapping('+flir_vision_prev', 'FLIR Vision Previous', 'keyboard', K.VisionPrev and K.VisionPrev.key or 'j')

-- Spotlight adjust commands
RegisterCommand('+flir_spot_dist_up', function()
    if FlirActive and SpotlightOn then
        SpotDistance = min(SpotDistMax, SpotDistance + SpotDistStep)
    end
end, false)
RegisterCommand('-flir_spot_dist_up', function() end, false)
RegisterKeyMapping('+flir_spot_dist_up', 'FLIR Spotlight Distance +', 'keyboard', K.SpotDistUp and K.SpotDistUp.key or 'UP')

RegisterCommand('+flir_spot_dist_down', function()
    if FlirActive and SpotlightOn then
        SpotDistance = max(SpotDistMin, SpotDistance - SpotDistStep)
    end
end, false)
RegisterCommand('-flir_spot_dist_down', function() end, false)
RegisterKeyMapping('+flir_spot_dist_down', 'FLIR Spotlight Distance -', 'keyboard', K.SpotDistDown and K.SpotDistDown.key or 'DOWN')

RegisterCommand('+flir_spot_radius_up', function()
    if FlirActive and SpotlightOn then
        SpotRadius = min(SpotRadiusMax, SpotRadius + SpotRadiusStep)
    end
end, false)
RegisterCommand('-flir_spot_radius_up', function() end, false)
RegisterKeyMapping('+flir_spot_radius_up', 'FLIR Spotlight Radius +', 'keyboard', K.SpotRadiusUp and K.SpotRadiusUp.key or 'RIGHT')

RegisterCommand('+flir_spot_radius_down', function()
    if FlirActive and SpotlightOn then
        SpotRadius = max(SpotRadiusMin, SpotRadius - SpotRadiusStep)
    end
end, false)
RegisterCommand('-flir_spot_radius_down', function() end, false)
RegisterKeyMapping('+flir_spot_radius_down', 'FLIR Spotlight Radius -', 'keyboard', K.SpotRadiusDown and K.SpotRadiusDown.key or 'LEFT')

local function GetWeatherLabel()
    return WeatherMap[GetPrevWeatherTypeHashName()] or 'UNKNOWN'
end

local function GetFlirTime()
    if TimeMode == 'local' and LocalTimeData and LocalTimeData.time ~= '' then
        return LocalTimeData.time
    end
    return string.format('%02d:%02d', GetClockHours(), GetClockMinutes())
end

local function GetFlirDate()
    if LocalTimeData and LocalTimeData.date ~= '' then
        return LocalTimeData.date
    end
    return os.date('%d/%m/%Y')
end

local function ApplyVisionMode(mode)
    SetNightvision(mode == 'NGTV')
    SetSeethrough(mode == 'THRML')
end

function ClearVisionMode()
    SetNightvision(false)
    SetSeethrough(false)
end

function PlayFlirSound(name, set)
    if not FlirSounds then return end
    PlaySoundFrontend(-1, name, set or "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end

local function UpdateCameraAttach(vehicle)
    if not FlirCam or not DoesCamExist(FlirCam) then return end
    local height = GetEntityHeightAboveGround(vehicle)
    local shouldBeHigh = height > CAM_SWITCH_H

    if shouldBeHigh and not FlirCamIsHigh then
        FlirCamIsHigh = true
        AttachCamToEntity(FlirCam, vehicle, CAM_HIGH_X, CAM_HIGH_Y, CAM_HIGH_Z, true)
        SetCamNearClip(FlirCam, 1.5)
    elseif not shouldBeHigh and FlirCamIsHigh then
        FlirCamIsHigh = false
        AttachCamToEntity(FlirCam, vehicle, CAM_LOW_X, CAM_LOW_Y, CAM_LOW_Z, true)
    end

    if not FlirCamIsHigh then
        SetCamNearClip(FlirCam, max(3.0, height * 0.5))
    end
end

local function GetZoomPercent()
    return floor((1.0 - (FlirFov - FlirFovMin) / (FlirFovMax - FlirFovMin)) * 100)
end

function CreateFlirCamera(vehicle)
    if FlirCam and DoesCamExist(FlirCam) then
        DestroyCam(FlirCam, false)
    end

    FlirCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    FlirFov = FOV.Default or 60.0
    FlirTargetFov = FlirFov

    local height = GetEntityHeightAboveGround(vehicle)
    if height > CAM_SWITCH_H then
        FlirCamIsHigh = true
        AttachCamToEntity(FlirCam, vehicle, CAM_HIGH_X, CAM_HIGH_Y, CAM_HIGH_Z, true)
        FlirRotX = CAM_HIGH_PITCH
        SetCamNearClip(FlirCam, 1.5)
    else
        FlirCamIsHigh = false
        AttachCamToEntity(FlirCam, vehicle, CAM_LOW_X, CAM_LOW_Y, CAM_LOW_Z, true)
        FlirRotX = CAM_LOW_PITCH
        SetCamNearClip(FlirCam, max(3.0, height * 0.5))
    end

    SetCamFov(FlirCam, FlirFov)
    FlirRotZ = GetEntityHeading(vehicle)
    FlirTargetRotX = FlirRotX
    FlirTargetRotZ = FlirRotZ
    SetCamRot(FlirCam, FlirRotX, 0.0, FlirRotZ, 2)
    RenderScriptCams(true, true, 500, true, false)
end

local function SetSpotlightDecor(vehicle, on, rotX, rotZ, dist, radius, bright, hard)
    if not vehicle or vehicle == 0 then return end
    DecorSetBool(vehicle, 'sp_on', on)
    if on then
        DecorSetFloat(vehicle, 'sp_rx', rotX or 0.0)
        DecorSetFloat(vehicle, 'sp_rz', rotZ or 0.0)
        DecorSetFloat(vehicle, 'sp_dist', dist or SpotDistance)
        DecorSetFloat(vehicle, 'sp_rad', radius or SpotRadius)
        DecorSetFloat(vehicle, 'sp_brt', bright or SpotBrightness)
        DecorSetFloat(vehicle, 'sp_hrd', hard or SpotHardness)
    end
end

local function ClearPlayerInfoCache()
    if not PlayerInfoCache then PlayerInfoCache = {} return end
    for _, info in pairs(PlayerInfoCache) do
        if info.handle then
            UnregisterPedheadshot(info.handle)
        end
    end
    PlayerInfoCache = {}
end

local function DestroyFlirCamera()
    ClearPlayerInfoCache()
    if FlirCam and DoesCamExist(FlirCam) then
        local cam = FlirCam
        FlirCam = nil
        RenderScriptCams(false, true, 500, true, false)
        SetTimeout(600, function()
            if DoesCamExist(cam) then DestroyCam(cam, false) end
        end)
    end
    ClearTimecycleModifier()
    ClearVisionMode()
    LockedEntity = nil
    ScanEntity = nil
    ScanTimer = 0.0
    ScanComplete = false
    ScannedEntities = {}
    if SpotlightOn then
        SpotlightOn = false
        SetSpotlightDecor(cache.vehicle, false)
    end
end

local function NormalizeAngle(a)
    a = a % 360.0
    if a > 180.0 then a = a - 360.0 end
    return a
end

local function AngleDiff(from, to)
    local d = (to - from) % 360.0
    if d > 180.0 then d = d - 360.0 end
    return d
end

local function SmoothDamp(current, target, speed, dt)
    local diff = AngleDiff(current, target)
    local step = diff * min(1.0, speed * dt * 60.0)
    return NormalizeAngle(current + step)
end

-- Check if entity is within camera FOV (doesn't check obstacles)
local function IsEntityInFov(entity)
    if not entity or not DoesEntityExist(entity) then return false end
    if not FlirCam or not DoesCamExist(FlirCam) then return false end
    local camCoords = GetCamCoord(FlirCam)
    local camRot = GetCamRot(FlirCam, 2)
    local entCoords = GetEntityCoords(entity)
    local dx = entCoords.x - camCoords.x
    local dy = entCoords.y - camCoords.y
    local dz = entCoords.z - camCoords.z
    local distXY = sqrt(dx * dx + dy * dy)
    if distXY < 0.1 then return true end
    local targetZ = atan2(-dx, dy) * (180.0 / pi)
    local targetX = atan2(dz, distXY) * (180.0 / pi)
    local diffZ = abs(AngleDiff(camRot.z, targetZ))
    local diffX = abs(targetX - camRot.x)
    local halfFov = max(15.0, FlirFov * 0.7)
    return diffZ <= halfFov and diffX <= halfFov
end

-- Check if there's a SOLID building/terrain blocking the view (for lock loss)
-- Ignores: trees, fences, poles, transparent objects
-- Only triggers on solid walls/buildings that completely block view
-- Optimized: Uses cached result if called within ObstructionCheckInterval
local function IsEntityObstructed(entity, forceCheck)
    if not entity or not DoesEntityExist(entity) then return true end
    if not FlirCam or not DoesCamExist(FlirCam) then return true end

    -- Use cached result if not enough time has passed (reduces CPU)
    local now = GetGameTimer()
    if not forceCheck and (now - LastObstructionCheck) < ObstructionCheckInterval then
        return LastObstructionResult
    end

    LastObstructionCheck = now
    local camCoords = GetCamCoord(FlirCam)
    local entCoords = GetEntityCoords(entity)
    local ignoreEntity = cache.vehicle or cache.ped

    -- Flag 17 = 1 (world) + 16 (objects but not foliage/trees)
    -- This ignores trees, bushes, fences, poles etc.
    -- Only solid buildings and terrain will block
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        camCoords.x, camCoords.y, camCoords.z,
        entCoords.x, entCoords.y, entCoords.z + 0.5, -- Slightly above ground to avoid terrain glitches
        1, -- Only world geometry (buildings, terrain) - NOT objects/foliage
        ignoreEntity, 4 -- Options: 4 = ignore glass/see-through materials
    )
    local _, hit, _, _, _ = GetShapeTestResult(handle)
    LastObstructionResult = hit ~= 0
    return LastObstructionResult
end

-- Combined check: in FOV and not obstructed (used for scanning/targeting)
local function IsEntityVisible(entity)
    return IsEntityInFov(entity) and not IsEntityObstructed(entity)
end

local function GetTargetEntity()
    if not FlirCam or not DoesCamExist(FlirCam) then return nil end
    local camCoords = GetCamCoord(FlirCam)
    local camRot = GetCamRot(FlirCam, 2)
    local rX = rad(camRot.x)
    local rZ = rad(camRot.z)
    local cosRX = abs(cos(rX))
    local dirX = -sin(rZ) * cosRX
    local dirY = cos(rZ) * cosRX
    local dirZ = sin(rX)

    local ignoreEntity = cache.vehicle or cache.ped
    local endX = camCoords.x + dirX * 500.0
    local endY = camCoords.y + dirY * 500.0
    local endZ = camCoords.z + dirZ * 500.0
    local handle = StartExpensiveSynchronousShapeTestLosProbe(camCoords.x, camCoords.y, camCoords.z, endX, endY, endZ, 31, ignoreEntity, 0)
    local _, hit, hitCoords, _, hitEntity = GetShapeTestResult(handle)
    if hit and hit ~= 0 and hitEntity and hitEntity ~= 0 and DoesEntityExist(hitEntity) then
        local eType = GetEntityType(hitEntity)
        if eType == 2 then return hitEntity end
        if eType == 1 then
            local pedVeh = GetVehiclePedIsIn(hitEntity, false)
            if pedVeh and pedVeh ~= 0 then return pedVeh end
            return hitEntity
        end
    end

    local searchCoords = (hit and hit ~= 0) and hitCoords or (camCoords + vector3(dirX, dirY, dirZ) * 200.0)
    local searchRadius = max(15.0, FlirFov * 0.6)
    local closestVeh = GetClosestVehicle(searchCoords.x, searchCoords.y, searchCoords.z, searchRadius, 0, 71)
    if closestVeh and closestVeh ~= 0 and closestVeh ~= (cache.vehicle or 0) and DoesEntityExist(closestVeh) then
        return closestVeh
    end

    return nil
end

local function GetDistanceToEntity(entity)
    if not entity or not DoesEntityExist(entity) then return 0 end
    if not FlirCam or not DoesCamExist(FlirCam) then return 0 end
    return floor(#(GetCamCoord(FlirCam) - GetEntityCoords(entity)))
end

local function GetPlayerMugshot(ped, serverId)
    if not ShowPlayerMugshot then return '' end
    local cached = PlayerInfoCache[serverId]
    if cached and cached.mugshot then return cached.mugshot end
    if cached and cached.pending then return '' end

    if not cached then PlayerInfoCache[serverId] = {} end
    PlayerInfoCache[serverId].pending = true

    CreateThread(function()
        local handle = RegisterPedheadshot_3(ped)
        local timeout = 60
        while not IsPedheadshotReady(handle) and timeout > 0 do
            Wait(100)
            timeout = timeout - 1
        end
        if not IsPedheadshotReady(handle) then
            UnregisterPedheadshot(handle)
            handle = RegisterPedheadshot(ped)
            timeout = 60
            while not IsPedheadshotReady(handle) and timeout > 0 do
                Wait(100)
                timeout = timeout - 1
            end
        end
        if IsPedheadshotReady(handle) then
            local txd = GetPedheadshotTxdString(handle)
            if PlayerInfoCache[serverId] then
                PlayerInfoCache[serverId].mugshot = txd
                PlayerInfoCache[serverId].handle = handle
                PlayerInfoCache[serverId].pending = false
                -- Mugshot hazır olduğunda entity hala geçerliyse NUI'ya gönder
                if DoesEntityExist(ped) and ScanComplete then
                    local dist = GetDistanceToEntity(ped)
                    NuiMessage('flir:updateTarget', BuildTargetData(ped, dist))
                end
            end
        else
            UnregisterPedheadshot(handle)
            if PlayerInfoCache[serverId] then
                PlayerInfoCache[serverId].pending = false
            end
        end
    end)
    return ''
end

local function GetPlayerRpName(serverId)
    if not ShowPlayerName then return 'Unknown' end
    local cached = PlayerInfoCache[serverId]
    if cached and cached.name then return cached.name end
    if cached and cached.namePending then return nil end

    if not cached then PlayerInfoCache[serverId] = {} end
    PlayerInfoCache[serverId].namePending = true

    CreateThread(function()
        local name = RPC.execute('codem-hud:getPlayerRpName', serverId)
        if PlayerInfoCache[serverId] then
            PlayerInfoCache[serverId].name = name or 'Unknown'
            PlayerInfoCache[serverId].namePending = false
        end
    end)
    return nil
end

local function BuildTargetData(entity, distance)
    local entityType = GetEntityType(entity)
    if entityType == 2 then
        return {
            type = 'vehicle',
            model = ShowVehicleModel and GetDisplayNameFromVehicleModel(GetEntityModel(entity)) or '',
            plate = ShowVehiclePlate and GetVehicleNumberPlateText(entity) or '',
            speed = ShowVehicleSpeed and floor(GetEntitySpeed(entity) * 3.6) or -1,
            distance = ShowDistance and distance or -1,
            health = ShowVehicleHealth and max(0, floor(GetVehicleEngineHealth(entity) / 10)) or -1,
            heading = ShowVehicleHeading and floor(GetEntityHeading(entity)) or -1
        }
    elseif entityType == 1 then
        if IsPedAPlayer(entity) then
            local pid = NetworkGetPlayerIndexFromPed(entity)
            local serverId = GetPlayerServerId(pid)
            -- Check if player is wearing a mask or has signal jammer
            local isMasked = HideMaskedPlayer and IsPedWearingMask(entity)
            local hasJammer = HasSignalJammerCached(serverId)
            local isHidden = isMasked or hasJammer

            -- Trigger async jammer check for next time (updates cache)
            if SignalJammerEnabled and not hasJammer then
                HasSignalJammer(serverId, function() end)
            end

            local rpName = (not isHidden and ShowPlayerName) and (GetPlayerRpName(serverId) or GetPlayerName(pid) or 'Unknown') or ''
            local mugshot = (not isHidden and ShowPlayerMugshot) and GetPlayerMugshot(entity, serverId) or ''
            local showId = (not isHidden and ShowPlayerId)
            return {
                type = 'ped',
                name = rpName,
                id = showId and serverId or -1,
                distance = ShowDistance and distance or -1,
                mugshot = mugshot,
                masked = isMasked or false,
                jammed = hasJammer or false
            }
        else
            return { type = 'ped', name = 'NPC', id = 0, distance = ShowDistance and distance or -1, mugshot = '' }
        end
    end
    return { type = 'none', distance = 0 }
end

local emptyTarget = { type = 'none', distance = 0 }

function ResetScan()
    ScanEntity = nil
    ScanTimer = 0.0
    ScanComplete = false
    NuiMessage('flir:scanProgress', { progress = 0 })
end

local function ScanTarget()
    local entity = GetTargetEntity()
    if not entity or not IsEntityVisible(entity) then
        if ScanEntity then ResetScan() end
        NuiMessage('flir:updateTarget', emptyTarget)
        return nil
    end

    if entity ~= ScanEntity then
        ScanEntity = entity
        if ScannedEntities[entity] then
            -- Already scanned - show info immediately
            ScanComplete = true
            ScanTimer = ScanDelay
            NuiMessage('flir:scanProgress', { progress = 0 })
            NuiMessage('flir:updateTarget', BuildTargetData(entity, GetDistanceToEntity(entity)))
            return entity
        else
            ScanTimer = 0.0
            ScanComplete = false
            NuiMessage('flir:updateTarget', emptyTarget)
        end
    end

    if not ScanComplete then
        ScanTimer = ScanTimer + 0.2
        local progress = min(1.0, ScanTimer / ScanDelay)
        NuiMessage('flir:scanProgress', { progress = progress })
        if progress >= 1.0 then
            ScanComplete = true
            ScannedEntities[entity] = true
        else
            return entity
        end
    end

    NuiMessage('flir:updateTarget', BuildTargetData(entity, GetDistanceToEntity(entity)))
    return entity
end

RegisterNUICallback('heli:accessFlir', function(_, cb)
    cb(ActivateFlir())
end)

RegisterNUICallback('flir:setVisionMode', function(data, cb)
    FlirVisionMode = data.mode or 'NRM'
    ApplyVisionMode(FlirVisionMode)
    cb('ok')
end)

RegisterNUICallback('flir:setCameraMode', function(data, cb)
    FlirCameraMode = data.mode or 'HDEO'
    if FlirCameraMode == 'HDEO' then
        LockedEntity = nil
        ResetScan()
        NuiMessage('flir:updateTarget', emptyTarget)
    end
    cb('ok')
end)

RegisterNUICallback('flir:keydown', function(data, cb)
    local k = data.key
    if k then
        local nk = normalizeJsKey(k)
        -- ALT toggles NUI cursor (mouse capture on/off)
        if nk == 'ALT' then
            FlirCursorActive = not FlirCursorActive
            SetNuiFocus(true, FlirCursorActive)
            if not FlirCursorActive then
                SetNuiFocusKeepInput(true)
            end
            cb('ok')
            return
        end
        if not FlirKeysDown[nk] then
            FlirKeysJustDown[nk] = true
        end
        FlirKeysDown[nk] = true
    end
    cb('ok')
end)

RegisterNUICallback('flir:keyup', function(data, cb)
    local k = data.key
    if k then
        local nk = normalizeJsKey(k)
        if nk ~= 'ALT' then
            FlirKeysDown[nk] = nil
        end
    end
    cb('ok')
end)

RegisterNUICallback('flir:close', function(_, cb)
    FlirActive = false
    DestroyFlirCamera()
    DisplayRadar(true)
    SetNuiFocus(false, false)
    SetInventoryBusy(false)
    FlirKeysDown = {}
    FlirKeysJustDown = {}
    FlirCursorActive = false
    -- Restore HUD bars and hide big minimap
    NuiMessage('flir:setHudVisibility', { visible = true })
    SetRadarBigmapEnabled(false, false)
    cb('ok')
end)

local function CloseFlir()
    FlirActive = false
    FlirCloseCooldown = 50  -- ~200ms to prevent ESC opening pause menu
    DestroyFlirCamera()
    DisplayRadar(true)
    SetNuiFocus(false, false)
    SetInventoryBusy(false)
    FlirKeysDown = {}
    FlirKeysJustDown = {}
    FlirCursorActive = false
    -- Restore HUD bars and hide big minimap
    NuiMessage('flir:setHudVisibility', { visible = true })
    SetRadarBigmapEnabled(false, false)
    PlayFlirSound("BACK")
    NuiMessage('flir:close', {})
end

local function FindIndex(tbl, value)
    for i, v in ipairs(tbl) do if v == value then return i end end
    return 1
end

local function CycleVisionMode(direction)
    local idx = FindIndex(VisionModes, FlirVisionMode)
    idx = ((idx - 1 + direction) % #VisionModes) + 1
    FlirVisionMode = VisionModes[idx]
    ApplyVisionMode(FlirVisionMode)
    PlayFlirSound("NAV_UP_DOWN")
    NuiMessage('flir:setVisionMode', { mode = FlirVisionMode })
end

local function ReleaseLock()
    LockedEntity = nil
    PendingLockEntity = nil
    LockObstructedTime = 0.0
    FlirCameraMode = 'FOCUS'
    ResetScan()
    PlayFlirSound("NAV_LEFT_RIGHT")
    NuiMessage('flir:setCameraMode', { mode = 'FOCUS' })
    NuiMessage('flir:updateTarget', emptyTarget)
    NuiMessage('flir:lockLost', {})
end

local function CycleCameraMode()
    local idx = FindIndex(CameraModes, FlirCameraMode)
    idx = (idx % #CameraModes) + 1
    FlirCameraMode = CameraModes[idx]
    PlayFlirSound("NAV_LEFT_RIGHT")
    if FlirCameraMode == 'HDEO' then
        LockedEntity = nil
        ResetScan()
        NuiMessage('flir:updateTarget', emptyTarget)
    elseif FlirCameraMode == 'LOCK' then
        local entity = GetTargetEntity()
        if entity and IsEntityVisible(entity) then
            PendingLockEntity = entity
            ScanEntity = entity
            ScanTimer = 0.0
            ScanComplete = false
        end
    else
        LockedEntity = nil
    end
    NuiMessage('flir:setCameraMode', { mode = FlirCameraMode })
end

local function LookAtEntity(entity)
    if not entity or not DoesEntityExist(entity) then return false end
    if not FlirCam or not DoesCamExist(FlirCam) then return false end
    local camCoords = GetCamCoord(FlirCam)
    local targetCoords = GetEntityCoords(entity)
    local dx = targetCoords.x - camCoords.x
    local dy = targetCoords.y - camCoords.y
    local dz = targetCoords.z - camCoords.z
    local distXY = sqrt(dx * dx + dy * dy)
    local dist = sqrt(distXY * distXY + dz * dz)
    if dist < 1.0 then return false end
    local targetRotZ = atan2(-dx, dy) * (180.0 / pi)
    local targetRotX = atan2(dz, distXY) * (180.0 / pi)
    local dt = GetFrameTime()
    FlirRotZ = SmoothDamp(FlirRotZ, targetRotZ, FlirLockSpeed, dt)
    FlirRotX = FlirRotX + (targetRotX - FlirRotX) * min(1.0, FlirLockSpeed * dt * 60.0)
    FlirTargetRotZ = FlirRotZ
    FlirTargetRotX = FlirRotX
    return true
end

-- Camera input thread
CreateThread(function()
    while true do
        if FlirActive and FlirCam and DoesCamExist(FlirCam) then
            if FlirCameraMode == 'LOCK' and PendingLockEntity and not LockedEntity then
                if DoesEntityExist(PendingLockEntity) and IsEntityVisible(PendingLockEntity) then
                    LookAtEntity(PendingLockEntity)
                end
            elseif FlirCameraMode == 'LOCK' and LockedEntity then
                local dt = GetFrameTime()
                if DoesEntityExist(LockedEntity) and not IsEntityDead(LockedEntity) then
                    local dist = #(GetCamCoord(FlirCam) - GetEntityCoords(LockedEntity))
                    -- Too far away - immediate release
                    if dist > 400.0 then
                        LockObstructedTime = 0.0
                        ReleaseLock()
                    -- Not in FOV at all - immediate release
                    elseif not IsEntityInFov(LockedEntity) then
                        LockObstructedTime = 0.0
                        ReleaseLock()
                    else
                        -- Check if obstructed by building/terrain
                        if IsEntityObstructed(LockedEntity) then
                            LockObstructedTime = LockObstructedTime + dt
                            -- Only release after sustained obstruction
                            if LockObstructedTime >= LockObstructedMax then
                                LockObstructedTime = 0.0
                                ReleaseLock()
                            else
                                -- Still tracking while temporarily obstructed
                                LookAtEntity(LockedEntity)
                            end
                        else
                            -- Clear obstruction timer when visible
                            LockObstructedTime = 0.0
                            LookAtEntity(LockedEntity)
                        end
                    end
                else
                    LockObstructedTime = 0.0
                    ReleaseLock()
                end
            else
                local mouseX = FlirCursorActive and 0.0 or GetDisabledControlNormal(0, 1)
                local mouseY = FlirCursorActive and 0.0 or GetDisabledControlNormal(0, 2)
                local dynamicSens = FlirSensitivity * (FlirFov / FlirFovMax)
                FlirTargetRotZ = FlirTargetRotZ - (mouseX * dynamicSens)
                FlirTargetRotX = FlirTargetRotX - (mouseY * dynamicSens)

                local pitchLow = PitchMin
                local camCoords = GetCamCoord(FlirCam)
                local found, groundZ = GetGroundZFor_3dCoord(camCoords.x, camCoords.y, camCoords.z, false)
                if found then
                    local h = camCoords.z - groundZ
                    if h < 30.0 then
                        pitchLow = max(pitchLow, -max(0.0, (h - 3.0) * 2.5))
                    end
                end
                FlirTargetRotX = max(pitchLow, min(PitchMax, FlirTargetRotX))
                local dt = GetFrameTime()
                FlirRotZ = SmoothDamp(FlirRotZ, FlirTargetRotZ, FlirLerpSpeed, dt)
                FlirRotX = FlirRotX + (FlirTargetRotX - FlirRotX) * min(1.0, FlirLerpSpeed * dt * 60.0)
            end

            local zoomStep = max(0.5, FlirFov * 0.04)
            if IsDisabledControlPressed(0, 241) then FlirTargetFov = max(FlirFovMin, FlirTargetFov - zoomStep) end
            if IsDisabledControlPressed(0, 242) then FlirTargetFov = min(FlirFovMax, FlirTargetFov + zoomStep) end
            FlirFov = FlirFov + (FlirTargetFov - FlirFov) * FlirZoomSpeed

            SetCamRot(FlirCam, FlirRotX, 0.0, FlirRotZ, 2)
            SetCamFov(FlirCam, FlirFov)

            -- FLIR controls via NUI keyboard (config-based)
            for label, _ in pairs(FlirKeysJustDown) do
                local act = FlirKeyAction[label]
                if not act then goto continueKey end

                -- Exit always works, others blocked while cursor active
                if act == 'exit' then
                    CloseFlir()
                elseif not FlirCursorActive then
                    if act == 'visionNext' then CycleVisionMode(1)
                    elseif act == 'visionPrev' then CycleVisionMode(-1)
                    elseif act == 'camera' then CycleCameraMode()
                    elseif act == 'spotlight' then
                        SpotlightOn = not SpotlightOn
                        PlayFlirSound(SpotlightOn and "SELECT" or "BACK")
                        NuiMessage('flir:spotlightState', { on = SpotlightOn })
                        if SpotlightOn and FlirCam then
                            local camRot = GetCamRot(FlirCam, 2)
                            SetSpotlightDecor(cache.vehicle, true, camRot.x, camRot.z, SpotDistance, SpotRadius)
                        else
                            SetSpotlightDecor(cache.vehicle, false)
                        end
                    elseif act == 'zoomReset' then
                        FlirTargetFov = FOV.Default or 60.0
                        PlayFlirSound("NAV_UP_DOWN")
                    elseif act == 'lock' then
                        if FlirCameraMode ~= 'LOCK' then
                            local entity = GetTargetEntity()
                            if entity and IsEntityVisible(entity) then
                                PendingLockEntity = entity
                                FlirCameraMode = 'LOCK'
                                ScanEntity = entity
                                ScanTimer = 0.0
                                ScanComplete = false
                                NuiMessage('flir:setCameraMode', { mode = 'LOCK' })
                            end
                        else
                            LockedEntity = nil
                            FlirCameraMode = 'FOCUS'
                            ResetScan()
                            PlayFlirSound("NAV_LEFT_RIGHT")
                            NuiMessage('flir:setCameraMode', { mode = 'FOCUS' })
                            NuiMessage('flir:updateTarget', emptyTarget)
                        end
                    elseif act == 'resetView' then
                        local vehicle = cache.vehicle
                        if vehicle then
                            FlirTargetRotZ = GetEntityHeading(vehicle)
                            FlirTargetRotX = FlirCamIsHigh and CAM_HIGH_PITCH or CAM_LOW_PITCH
                            PlayFlirSound("NAV_UP_DOWN")
                        end
                    elseif act == 'spotDistUp' and SpotlightOn then
                        SpotDistance = min(SpotDistMax, SpotDistance + SpotDistStep)
                    elseif act == 'spotDistDown' and SpotlightOn then
                        SpotDistance = max(SpotDistMin, SpotDistance - SpotDistStep)
                    elseif act == 'spotRadiusUp' and SpotlightOn then
                        SpotRadius = min(SpotRadiusMax, SpotRadius + SpotRadiusStep)
                    elseif act == 'spotRadiusDown' and SpotlightOn then
                        SpotRadius = max(SpotRadiusMin, SpotRadius - SpotRadiusStep)
                    end
                end
                ::continueKey::
            end

            SetNuiFocusKeepInput(true)

            -- Block all controls, then re-enable only helicopter flight
            DisableAllControlActions(0)

            EnableControlAction(0, 87, true)   -- VEH_FLY_THROTTLE_UP (W)
            EnableControlAction(0, 88, true)   -- VEH_FLY_THROTTLE_DOWN (S)
            EnableControlAction(0, 89, true)   -- VEH_FLY_YAW_LEFT (A)
            EnableControlAction(0, 90, true)   -- VEH_FLY_YAW_RIGHT (D)
            EnableControlAction(0, 76, true)   -- VEH_HANDBRAKE (Space)
            EnableControlAction(0, 107, true)  -- VEH_FLY_ROLL_LR
            EnableControlAction(0, 108, true)  -- VEH_FLY_ROLL_LEFT_ONLY (Numpad 4)
            EnableControlAction(0, 109, true)  -- VEH_FLY_ROLL_RIGHT_ONLY (Numpad 6)
            EnableControlAction(0, 110, true)  -- VEH_FLY_PITCH_UD
            EnableControlAction(0, 111, true)  -- VEH_FLY_PITCH_UP_ONLY (Numpad 8)
            EnableControlAction(0, 112, true)  -- VEH_FLY_PITCH_DOWN_ONLY (Numpad 5)
            EnableControlAction(0, 249, true)
            EnableControlAction(0, 306, true)

            FlirKeysJustDown = {}

            Wait(0)
        elseif FlirCloseCooldown > 0 then
            DisableControlAction(0, 200, true)
            FlirCloseCooldown = FlirCloseCooldown - 1
            Wait(4)
        else
            Wait(500)
        end
    end
end)

-- Telemetry thread (100ms)
CreateThread(function()
    while true do
        if FlirActive then
            local ped = cache.ped
            local vehicle = cache.vehicle or 0
            local coords = GetEntityCoords(ped)
            if vehicle ~= 0 then UpdateCameraAttach(vehicle) end

            local heading, pitch
            if FlirCam and DoesCamExist(FlirCam) then
                local camRot = GetCamRot(FlirCam, 2)
                heading = floor(camRot.z % 360)
                pitch = floor(camRot.x)
            else
                heading = floor(GetEntityHeading(ped))
                pitch = floor(GetEntityPitch(ped))
            end

            local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)) or 'Unknown'
            local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local street = GetStreetNameFromHashKey(streetHash) or ''
            if crossingHash ~= 0 then
                local crossing = GetStreetNameFromHashKey(crossingHash)
                if crossing and crossing ~= '' then street = street .. ' / ' .. crossing end
            end

            local hour = GetClockHours()
            NuiMessage('flir:updateData', {
                heading = heading,
                pitch = pitch,
                speed = floor(GetEntitySpeed(vehicle > 0 and vehicle or ped) * 3.6),
                altitude = floor(coords.z * 3.28084),
                weather = GetWeatherLabel(),
                date = GetFlirDate(),
                time = GetFlirTime(),
                area = zone,
                street = street,
                zoom = GetZoomPercent(),
                isNight = hour >= 20 or hour < 6,
                spotlight = SpotlightOn and { distance = floor(SpotDistance), radius = floor(SpotRadius) } or nil
            })
            Wait(100)
        else
            Wait(500)
        end
    end
end)

-- Target scan thread (200ms)
CreateThread(function()
    while true do
        if FlirActive and FlirCameraMode == 'LOCK' and PendingLockEntity and not LockedEntity then
            -- Scanning before lock
            if DoesEntityExist(PendingLockEntity) and IsEntityVisible(PendingLockEntity) then
                if ScannedEntities[PendingLockEntity] then
                    LockedEntity = PendingLockEntity
                    PendingLockEntity = nil
                    ScanComplete = true
                    PlayFlirSound("PICK_UP")
                    NuiMessage('flir:scanProgress', { progress = 0 })
                    NuiMessage('flir:updateTarget', BuildTargetData(LockedEntity, GetDistanceToEntity(LockedEntity)))
                else
                ScanTimer = ScanTimer + 0.2
                local progress = min(1.0, ScanTimer / ScanDelay)
                NuiMessage('flir:scanProgress', { progress = progress })
                if progress >= 1.0 then
                    LockedEntity = PendingLockEntity
                    PendingLockEntity = nil
                    ScanComplete = true
                    ScannedEntities[PendingLockEntity or LockedEntity] = true
                    PlayFlirSound("PICK_UP")
                    NuiMessage('flir:scanProgress', { progress = 0 })
                    NuiMessage('flir:updateTarget', BuildTargetData(LockedEntity, GetDistanceToEntity(LockedEntity)))
                end
                end
            else
                PendingLockEntity = nil
                ResetScan()
                ReleaseLock()
            end
            Wait(200)
        elseif FlirActive and FlirCameraMode == 'LOCK' and LockedEntity then
            if DoesEntityExist(LockedEntity) and IsEntityVisible(LockedEntity) then
                NuiMessage('flir:updateTarget', BuildTargetData(LockedEntity, GetDistanceToEntity(LockedEntity)))
            else
                ReleaseLock()
            end
            Wait(200)
        elseif FlirActive and (FlirCameraMode == 'FOCUS' or FlirCameraMode == 'HDEO') then
            ScanTarget()
            Wait(200)
        else
            Wait(500)
        end
    end
end)

-- Auto-close when exiting vehicle
CreateThread(function()
    while true do
        if FlirActive then
            if not IsPedInAnyVehicle(PlayerPedId(), false) then CloseFlir() end
        end
        Wait(500)
    end
end)

-- Street names 3D: scan nearby road nodes and collect unique street names
-- Grid-based cache: same street can appear multiple times but with spacing
local StreetLabelCache = {} -- gridKey -> {x, y, z, name}
local STREET_GRID = 100.0   -- minimum spacing between labels (~100m)

local function ScanNodesFrom(sx, sy, sz, camCoords, count)
    for i = 1, count do
        local found, nodePos = GetNthClosestVehicleNode(sx, sy, sz, i, 1, 3.0, 0.0)
        if found then
            local dist = #(camCoords - nodePos)
            if dist <= StreetNamesMaxDist then
                local streetHash = GetStreetNameAtCoord(nodePos.x, nodePos.y, nodePos.z)
                if streetHash and streetHash ~= 0 then
                    local gx = floor(nodePos.x / STREET_GRID)
                    local gy = floor(nodePos.y / STREET_GRID)
                    local key = gx .. '_' .. gy
                    if not StreetLabelCache[key] then
                        local name = GetStreetNameFromHashKey(streetHash)
                        if name and name ~= '' then
                            StreetLabelCache[key] = { x = nodePos.x, y = nodePos.y, z = nodePos.z + 0.8, name = name }
                        end
                    end
                end
            end
        end
    end
end

local function UpdateStreetLabels()
    if not FlirCam or not DoesCamExist(FlirCam) then
        StreetLabels = {}
        StreetLabelCache = {}
        return
    end

    local camCoords = GetCamCoord(FlirCam)
    local camRot = GetCamRot(FlirCam, 2)

    -- Project camera direction to ground to find look-at center
    local rX = rad(camRot.x)
    local rZ = rad(camRot.z)
    local dirZ = sin(rX)
    local cosRX = abs(cos(rX))
    local dirX = -sin(rZ) * cosRX
    local dirY = cos(rZ) * cosRX

    local lookX, lookY = camCoords.x, camCoords.y
    if dirZ < -0.05 then
        local t = min(400.0, camCoords.z / (-dirZ))
        lookX = camCoords.x + dirX * t
        lookY = camCoords.y + dirY * t
    end

    -- Remove cached labels that are too far
    for key, lbl in pairs(StreetLabelCache) do
        local dist = #(camCoords - vector3(lbl.x, lbl.y, lbl.z))
        if dist > StreetNamesMaxDist * 1.3 then
            StreetLabelCache[key] = nil
        end
    end

    -- Use ground-level Z for node search (high altitude Z makes all nodes equidistant)
    local _, groundZ = GetGroundZFor_3dCoord(camCoords.x, camCoords.y, camCoords.z, false)
    local searchZ = groundZ or 0.0

    -- Scan from look-at center (where camera points) + camera position (below heli)
    local half = floor(StreetNamesMaxNodes / 2)
    ScanNodesFrom(lookX, lookY, searchZ, camCoords, half)
    ScanNodesFrom(camCoords.x, camCoords.y, searchZ, camCoords, half)

    -- Build array from cache
    local labels = {}
    for _, lbl in pairs(StreetLabelCache) do
        labels[#labels + 1] = lbl
    end
    StreetLabels = labels
end

-- Street names: update thread
CreateThread(function()
    while true do
        if FlirActive and StreetNamesEnabled then
            UpdateStreetLabels()
            Wait(StreetNamesInterval)
        else
            StreetLabels = {}
            StreetLabelCache = {}
            Wait(1000)
        end
    end
end)

-- Street names: render thread
CreateThread(function()
    while true do
        if FlirActive and StreetNamesEnabled and #StreetLabels > 0 and FlirCam and DoesCamExist(FlirCam) then
            local camCoords = GetCamCoord(FlirCam)
            for i = 1, #StreetLabels do
                local lbl = StreetLabels[i]
                local dist = #(camCoords - vector3(lbl.x, lbl.y, lbl.z))
                if dist < StreetNamesMaxDist then
                    local t = dist / StreetNamesMaxDist
                    local alpha = floor(max(80, 255 - t * 175))
                    local scale = max(0.25, StreetNamesFontScale * (1.0 - t * 0.5))

                    SetDrawOrigin(lbl.x, lbl.y, lbl.z, 0)
                    SetTextScale(0.0, scale)
                    SetTextFont(0)
                    SetTextProportional(true)
                    SetTextColour(255, 255, 255, alpha)
                    SetTextDropShadow()
                    SetTextOutline()
                    SetTextCentre(true)
                    BeginTextCommandDisplayText('STRING')
                    AddTextComponentSubstringPlayerName(lbl.name)
                    EndTextCommandDisplayText(0.0, 0.0)
                    ClearDrawOrigin()
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Spotlight render + sync thread (Decorator-based)
local lastSyncTime = 0
local SYNC_INTERVAL = 150
local cachedGroundZ = 0.0
local lastGroundCheck = 0

CreateThread(function()
    while true do
        local drawing = false
        local myVeh = cache.vehicle or 0

        -- Local spotlight (FLIR owner)
        if FlirActive and SpotlightOn and FlirCam and DoesCamExist(FlirCam) then
            local now = GetGameTimer()
            local camCoords = GetCamCoord(FlirCam)
            local rX = rad(FlirRotX)
            local rZ = rad(FlirRotZ)
            local cosRX = abs(cos(rX))
            local dirX = -sin(rZ) * cosRX
            local dirY = cos(rZ) * cosRX
            local dirZ = sin(rX)
            if now - lastGroundCheck > 200 then
                lastGroundCheck = now
                local _, gz = GetGroundZFor_3dCoord(camCoords.x, camCoords.y, camCoords.z, false)
                cachedGroundZ = gz or 0.0
            end
            local height = camCoords.z - cachedGroundZ
            local hScale = max(1.0, height / 50.0)
            local eDist = SpotDistance * hScale
            local eBright = SpotBrightness * hScale
            local eRadius = SpotRadius * max(1.0, hScale * 0.5)
            DrawSpotLight(camCoords.x, camCoords.y, camCoords.z, dirX, dirY, dirZ, 255, 255, 255, eDist, eBright, SpotHardness, eRadius, 1.0)
            drawing = true

            if now - lastSyncTime >= SYNC_INTERVAL then
                lastSyncTime = now
                SetSpotlightDecor(myVeh, true, FlirRotX, FlirRotZ, eDist, eRadius, eBright, SpotHardness)
            end
        end

        -- Other players' spotlights via Decorators
        local vehicles = GetGamePool('CVehicle')
        for i = 1, #vehicles do
            local veh = vehicles[i]
            if veh ~= myVeh and DecorExistOn(veh, 'sp_on') and DecorGetBool(veh, 'sp_on') then
                local rx = DecorGetFloat(veh, 'sp_rx')
                local rz = DecorGetFloat(veh, 'sp_rz')
                local rRX = rad(rx)
                local rRZ = rad(rz)
                local cRX = abs(cos(rRX))
                local dX = -sin(rRZ) * cRX
                local dY = cos(rRZ) * cRX
                local dZ = sin(rRX)
                local c = GetEntityCoords(veh)
                local dist = DecorGetFloat(veh, 'sp_dist')
                local brt = DecorGetFloat(veh, 'sp_brt')
                local hrd = DecorGetFloat(veh, 'sp_hrd')
                local rd = DecorGetFloat(veh, 'sp_rad')
                DrawSpotLight(c.x, c.y, c.z - 1.5, dX, dY, dZ, 255, 255, 255, dist, brt, hrd, rd, 1.0)
                drawing = true
            end
        end

        Wait(drawing and 0 or 500)
    end
end)

debugPrint('[FLIR] Module loaded')
