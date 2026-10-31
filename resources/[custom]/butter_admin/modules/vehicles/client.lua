local PERFORMANCE_MODS = { 11, 12, 13, 15 } -- engine, brakes, transmission, suspension
local TURBO_MOD = 18
local XENON_MOD = 22
local FRONT_WHEELS_MOD = 23
local REAR_WHEELS_MOD = 24
local LIVERY_MOD = 48
local MOTORCYCLE_CLASS = 8
local BIKE_WHEEL_TYPE = 6

--- The vehicle the player sits in, or the closest one within `radius`.
---@param radius? number
---@return number?
local function getTargetVehicle(radius)
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle ~= 0 then return vehicle end
    vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), radius or 5.0)
    return vehicle and vehicle ~= 0 and vehicle or nil
end

---@param vehicle number
---@return string
local function getPlate(vehicle)
    return (GetVehicleNumberPlateText(vehicle):gsub('^%s*(.-)%s*$', '%1'))
end

---@param vehicle number
---@param fuel number
local function setFuelLevel(vehicle, fuel)
    if SetVehicleFuel then SetVehicleFuel(vehicle, fuel) end
    SetVehicleFuelLevel(vehicle, fuel + 0.0)
end

---@param vehicle number
local function applyMaxPerformance(vehicle)
    SetVehicleModKit(vehicle, 0)
    for _, modType in ipairs(PERFORMANCE_MODS) do
        SetVehicleMod(vehicle, modType, GetNumVehicleMods(vehicle, modType) - 1, false)
    end
    ToggleVehicleMod(vehicle, TURBO_MOD, true)
end

---@param vehicle number
local function applyRandomCustomization(vehicle)
    SetVehicleModKit(vehicle, 0)
    SetVehicleColours(vehicle, math.random(0, 159), math.random(0, 159))
    for modType = 0, 48 do
        local count = GetNumVehicleMods(vehicle, modType)
        if count > 0 then SetVehicleMod(vehicle, modType, math.random(-1, count - 1), false) end
    end
    SetVehicleNeonLightsColour(vehicle, math.random(0, 255), math.random(0, 255), math.random(0, 255))
    for side = 0, 3 do SetVehicleNeonLightEnabled(vehicle, side, true) end
end

--- Only the owner of a networked vehicle can delete it, so control is taken first.
---@param vehicle number
local function deleteNetworkedVehicle(vehicle)
    NetworkRequestControlOfEntity(vehicle)
    local deadline = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
        Wait(0)
        NetworkRequestControlOfEntity(vehicle)
    end
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
end

AddEventHandler('butter_admin:client:deleteVehicle', function()
    if not IsAuthorizedRemote('deleteVehicle') then return end
    local vehicle = getTargetVehicle()
    if not vehicle then return Notify(locale('notify.no_vehicle_found'), 'error') end
    deleteNetworkedVehicle(vehicle)
end)

AddEventHandler('butter_admin:client:fixVehicle', function()
    if not IsAuthorizedRemote('fixVehicle') then return end
    local vehicle = getTargetVehicle()
    if not vehicle then return Notify(locale('notify.no_vehicle_found'), 'error') end
    SetVehicleFixed(vehicle)
    setFuelLevel(vehicle, 100.0)
end)

AddEventHandler('butter_admin:client:upgradeVehicle', function(options)
    local maxMods = type(options) == 'table' and options.maxmods
    local randomCustom = type(options) == 'table' and options.randomcustom
    if not maxMods and not randomCustom then maxMods = true end

    if maxMods and not IsAuthorizedRemote('maxVehiclePerf') then return end
    if randomCustom and not IsAuthorizedRemote('randomizeCustomization') then return end

    local vehicle = getTargetVehicle()
    if not vehicle then return Notify(locale('notify.no_vehicle_found'), 'error') end

    if maxMods then
        applyMaxPerformance(vehicle)
        Notify(locale('notify.vehicle_maxed'), 'success')
    end
    if randomCustom then
        applyRandomCustomization(vehicle)
        Notify(locale('notify.vehicle_customized'), 'success')
    end
end)

AddEventHandler('butter_admin:client:giveKeys', function()
    if not IsAuthorizedRemote('givekeys') then return end
    local vehicle = getTargetVehicle()
    if not vehicle then return Notify(locale('notify.no_vehicle_found'), 'error') end
    if not GiveVehicleKeys then return Notify(locale('notify.keys_bridge_not_found'), 'error') end

    local plate = GetVehicleNumberPlateText(vehicle)
    GiveVehicleKeys(plate, vehicle)
    Notify(locale('notify.keys_received', plate), 'success')
end)

RegisterNetEvent('butter_admin:client:setFuel', function(fuel)
    fuel = math.max(0.0, math.min(100.0, tonumber(fuel) or 100.0))
    local vehicle = getTargetVehicle()
    if not vehicle then return Notify(locale('notify.no_vehicle_found'), 'error') end

    setFuelLevel(vehicle, fuel)
    Notify(locale('notify.fuel_set', fuel, getPlate(vehicle)), 'success')
end)

AddEventHandler('butter_admin:client:spawnVehicle', function(options)
    if type(options) ~= 'table' then return end
    local model = (options.custom_model and options.custom_model ~= '') and options.custom_model or options.model
    if type(model) ~= 'string' or model == '' then return Notify(locale('notify.no_vehicle'), 'error') end
    if not IsAuthorizedRemote('spawnCar') then return end
    CloseAdminMenu()

    local modelHash = joaat(model)
    if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) or not pcall(lib.requestModel, modelHash) then
        return Notify(locale('objects.invalid_model', model), 'error')
    end

    local ped = cache.ped
    local coords = options.sit and GetEntityCoords(ped) or GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.5, 0.0)
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(modelHash)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)

    if options.sit then TaskWarpPedIntoVehicle(ped, vehicle, -1) end
    if options.maxmods then applyMaxPerformance(vehicle) end
    if options.randomcustom then applyRandomCustomization(vehicle) end

    local plate = GetVehicleNumberPlateText(vehicle)
    if GiveVehicleKeys then GiveVehicleKeys(plate, vehicle) end
    TriggerServerEvent('butter_admin:server:logVehicleSpawn', model, plate)
end)

AddEventHandler('butter_admin:client:registerAdminCar', function()
    if not IsAuthorizedRemote('admincar') then return end
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle == 0 then return Notify(locale('notify.admin_car_must_be_inside'), 'error') end

    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower()
    TriggerServerEvent('butter_admin:server:registerAdminCar', GetVehicleNumberPlateText(vehicle), model, lib.getVehicleProperties(vehicle))
end)

---@param options any
---@return string?
local function resolveInventoryPlate(options)
    local plate = type(options) == 'table' and options.plate
    if type(plate) == 'string' and plate ~= '' then return plate end

    local vehicle = getTargetVehicle()
    if vehicle then return GetVehicleNumberPlateText(vehicle) end
    Notify(locale('notify.no_vehicle'), 'error')
end

---@param vehicleType 'trunk'|'glovebox'
---@param options any
local function openVehicleStorage(vehicleType, options)
    local plate = resolveInventoryPlate(options)
    if not plate then return end

    -- The ox_inventory bridge needs a temporary vehicle to open it remotely.
    if OpenVehicleInventory then return OpenVehicleInventory(vehicleType, plate) end
    TriggerServerEvent(vehicleType == 'trunk' and 'butter_admin:server:openTrunk' or 'butter_admin:server:openGlovebox', plate)
end

AddEventHandler('butter_admin:client:openTrunk', function(options)
    openVehicleStorage('trunk', options)
end)

AddEventHandler('butter_admin:client:openGlovebox', function(options)
    openVehicleStorage('glovebox', options)
end)

-- Admin Customs (Bennys): an ox_lib menu with an orbit camera around the vehicle.

local bennys = {
    vehicle = 0,
    lastIndex = {}, ---@type table<string, integer>
    transitioning = false,
    inMenu = false,
    camera = nil,
    dragging = false,
    angleY = 15.0,
    angleZ = 180.0,
    radius = 5.0,
}

local CAMERA_MIN_RADIUS = 2.2
local CAMERA_MAX_RADIUS = 10.0
local CAMERA_ZOOM_STEP = 0.5

local function updateCameraPosition()
    if not DoesEntityExist(bennys.vehicle) then return end

    bennys.angleZ -= GetDisabledControlNormal(0, 1) * 8.0
    bennys.angleY = math.max(-10.0, math.min(85.0, bennys.angleY + GetDisabledControlNormal(0, 2) * 8.0))

    local center = GetEntityCoords(bennys.vehicle)
    local cosY = math.cos(math.rad(bennys.angleY))
    local x = center.x + math.cos(math.rad(bennys.angleZ)) * cosY * bennys.radius
    local y = center.y + math.sin(math.rad(bennys.angleZ)) * cosY * bennys.radius
    local z = center.z + math.sin(math.rad(bennys.angleY)) * bennys.radius

    SetCamCoord(bennys.camera, x, y, z)
    PointCamAtCoord(bennys.camera, center.x, center.y, center.z + 0.4)
end

---@return boolean
local function isMouseHeld()
    return IsDisabledControlPressed(0, 24) or IsControlPressed(0, 24) or IsDisabledControlPressed(0, 25) or IsControlPressed(0, 25)
end

local function startCameraDrag()
    if bennys.dragging then return end
    bennys.dragging = true

    CreateThread(function()
        SetMouseCursorSprite(4)
        while bennys.inMenu and isMouseHeld() do
            updateCameraPosition()
            Wait(0)
        end
        SetMouseCursorSprite(3)
        bennys.dragging = false
    end)
end

local function runMenuControls()
    CreateThread(function()
        while bennys.inMenu do
            SetMouseCursorActiveThisFrame()
            -- Driving, exit, radio and pause stay blocked while customizing.
            for _, control in ipairs({ 71, 72, 75, 81, 82, 83, 84, 85, 106, 200 }) do
                DisableControlAction(0, control, true)
            end

            if IsDisabledControlJustPressed(0, 24) or IsControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 25) then
                startCameraDrag()
            end

            -- Scroll zooms only while a mouse button is held, so plain scrolling still navigates the menu.
            if isMouseHeld() then
                if IsDisabledControlJustReleased(0, 14) or IsControlJustReleased(0, 14) then
                    bennys.radius = math.min(CAMERA_MAX_RADIUS, bennys.radius + CAMERA_ZOOM_STEP)
                    updateCameraPosition()
                elseif IsDisabledControlJustReleased(0, 15) or IsControlJustReleased(0, 15) then
                    bennys.radius = math.max(CAMERA_MIN_RADIUS, bennys.radius - CAMERA_ZOOM_STEP)
                    updateCameraPosition()
                end
            end
            Wait(0)
        end
    end)
end

local function startCamera()
    FreezeEntityPosition(bennys.vehicle, true)

    local min, max = GetModelDimensions(GetEntityModel(bennys.vehicle))
    bennys.radius = math.max(4.0, (max.y - min.y) * 0.85)
    bennys.angleY, bennys.angleZ = 15.0, 180.0
    bennys.camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, true, 500, true, false)
    updateCameraPosition()

    bennys.inMenu = true
    runMenuControls()
end

local function stopCamera()
    if not bennys.inMenu then return end
    bennys.inMenu = false

    RenderScriptCams(false, true, 500, true, false)
    if bennys.camera and DoesCamExist(bennys.camera) then DestroyCam(bennys.camera, true) end
    bennys.camera = nil
    if DoesEntityExist(bennys.vehicle) then FreezeEntityPosition(bennys.vehicle, false) end
end

-- Saved server-side, and only for owned vehicles.
local function saveVehicleProps()
    if not DoesEntityExist(bennys.vehicle) then return end
    local netId = NetworkGetEntityIsNetworked(bennys.vehicle) and NetworkGetNetworkIdFromEntity(bennys.vehicle) or nil
    TriggerServerEvent('butter_admin:server:saveVehicleProps', lib.getVehicleProperties(bennys.vehicle), netId)
end

---@param modType integer
---@param index integer
---@return string
local function getModLabel(modType, index)
    if index == -1 then return 'Stock' end
    local textLabel = GetModTextLabel(bennys.vehicle, modType, index)
    local label = textLabel and GetLabelText(textLabel)
    if label and label ~= 'NULL' and label ~= '' then return label end
    return ('Level %d'):format(index + 1)
end

---@param price number
---@return string
local function formatPrice(price)
    return ('%s%s'):format(Config.Bennys.Currency, price)
end

local function playNavigationSound()
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

--- Runs a menu switch while ignoring the onClose it triggers.
---@param fn function
local function transition(fn)
    bennys.transitioning = true
    fn()
    SetTimeout(50, function() bennys.transitioning = false end)
end

--- A list entry for a vehicle mod slot: Stock plus every available level.
---@param modType integer
---@param label string
---@return table?
local function buildModEntry(modType, label)
    local count = GetNumVehicleMods(bennys.vehicle, modType)
    if count <= 0 then return nil end

    local values = {}
    for index = -1, count - 1 do values[index + 2] = getModLabel(modType, index) end

    local original = GetVehicleMod(bennys.vehicle, modType)
    return {
        label = label,
        description = formatPrice(Config.Bennys.CosmeticPrice),
        values = values,
        defaultIndex = original + 2,
        set = function(index) SetVehicleMod(bennys.vehicle, modType, index - 2, false) end,
        restore = function() SetVehicleMod(bennys.vehicle, modType, original, false) end,
    }
end

---@param category 'performance'|'parts'
---@return table[]
local function buildModEntries(category)
    local entries = {}
    for modType, label in pairs(Config.Bennys.ModSlots[category]) do
        entries[#entries + 1] = buildModEntry(modType, label)
    end
    return entries
end

local paintCache = {}

--- Paints of one finish as a list ordered by game index.
---@param category string
---@return { id: number, label: string }[]
local function getPaints(category)
    if paintCache[category] then return paintCache[category] end

    local paints = {}
    for id, label in pairs(Config.Bennys.Paints[category] or {}) do paints[#paints + 1] = { id = id, label = label } end
    table.sort(paints, function(a, b) return a.id < b.id end)
    paintCache[category] = paints
    return paints
end

---@param categories string[]
---@param prefixed? boolean prepend the finish name to each label
---@return { id: number, label: string }[]
local function combinePaints(categories, prefixed)
    local paints = {}
    for _, category in ipairs(categories) do
        for _, paint in ipairs(getPaints(category)) do
            paints[#paints + 1] = { id = paint.id, label = prefixed and ('%s - %s'):format(category, paint.label) or paint.label }
        end
    end
    return paints
end

---@param paints { id: number, label: string }[]
---@param current number
---@return number[] ids, string[] labels, integer selected
local function listPaints(paints, current)
    local ids, labels, selected = {}, {}, 1
    for i, paint in ipairs(paints) do
        ids[i], labels[i] = paint.id, paint.label
        if paint.id == current then selected = i end
    end
    return ids, labels, selected
end

---@param entries table[]
local function sortByLabel(entries)
    table.sort(entries, function(a, b) return a.label < b.label end)
end

local MENU_BUILDERS = {}

function MENU_BUILDERS.main()
    local vehicle = bennys.vehicle
    local entries = {}

    local bodyHealth = GetVehicleBodyHealth(vehicle)
    if bodyHealth < 1000.0 then
        entries[#entries + 1] = {
            label = 'Repair Vehicle',
            description = formatPrice(math.ceil(1000 - bodyHealth)),
            action = function()
                local fuel = GetVehicleFuelLevel(vehicle)
                SetVehicleFixed(vehicle)
                SetVehicleFuelLevel(vehicle, fuel)
                Notify(locale('notify.bennys_repaired'), 'success')
            end,
        }
    end

    entries[#entries + 1] = { label = 'Performance', submenu = 'performance' }
    entries[#entries + 1] = { label = 'Cosmetics - Parts', submenu = 'parts' }
    entries[#entries + 1] = { label = 'Cosmetics - Colors', submenu = 'colors' }

    for extra = 1, 14 do
        if DoesExtraExist(vehicle, extra) then
            entries[#entries + 1] = { label = 'Extras', submenu = 'extras' }
            break
        end
    end

    return 'Bennys Customs', entries, nil
end

function MENU_BUILDERS.performance()
    local vehicle = bennys.vehicle
    local entries = buildModEntries('performance')

    local turbo = IsToggleModOn(vehicle, TURBO_MOD)
    entries[#entries + 1] = {
        label = 'Turbo',
        description = formatPrice(Config.Bennys.TurboPrice),
        values = { 'Disabled', 'Enabled' },
        defaultIndex = turbo and 2 or 1,
        set = function(index) ToggleVehicleMod(vehicle, TURBO_MOD, index == 2) end,
        restore = function() ToggleVehicleMod(vehicle, TURBO_MOD, turbo) end,
    }

    sortByLabel(entries)
    return 'Performance', entries, 'main'
end

function MENU_BUILDERS.parts()
    local vehicle = bennys.vehicle
    local entries = buildModEntries('parts')
    entries[#entries + 1] = { label = 'Wheels & Rims', submenu = 'wheels' }

    local plateIndex = GetVehicleNumberPlateTextIndex(vehicle)
    entries[#entries + 1] = {
        label = 'Plate Style',
        description = formatPrice(Config.Bennys.CosmeticPrice),
        values = Config.Bennys.PlateStyles,
        defaultIndex = plateIndex + 1,
        set = function(index) SetVehicleNumberPlateTextIndex(vehicle, index - 1) end,
        restore = function() SetVehicleNumberPlateTextIndex(vehicle, plateIndex) end,
    }

    sortByLabel(entries)
    return 'Cosmetics - Parts', entries, 'main'
end

function MENU_BUILDERS.colors()
    local vehicle = bennys.vehicle
    local entries = {
        { label = 'Paint Primary', submenu = 'paintPrimary' },
        { label = 'Paint Secondary', submenu = 'paintSecondary' },
        { label = 'Neon Customization', submenu = 'neon' },
    }

    local xenonOn = IsToggleModOn(vehicle, XENON_MOD)
    local xenonColor = GetVehicleXenonLightsColor(vehicle)
    if xenonColor == 255 then xenonColor = -1 end
    local xenonLabels = { 'Disabled' }
    for i, label in ipairs(Config.Bennys.XenonColors) do xenonLabels[i + 1] = label end
    entries[#entries + 1] = {
        label = 'Xenon Lights',
        values = xenonLabels,
        defaultIndex = xenonOn and xenonColor + 3 or 1,
        set = function(index)
            ToggleVehicleMod(vehicle, XENON_MOD, index ~= 1)
            if index ~= 1 then SetVehicleXenonLightsColor(vehicle, index - 3) end
        end,
        restore = function()
            ToggleVehicleMod(vehicle, XENON_MOD, xenonOn)
            SetVehicleXenonLightsColor(vehicle, xenonColor)
        end,
    }

    local pearl, wheelColor = GetVehicleExtraColours(vehicle)
    local pearlIds, pearlLabels, pearlSelected = listPaints(combinePaints({ 'Metallic', 'Solid', 'Chameleon' }), pearl)
    entries[#entries + 1] = {
        label = 'Pearlescent Color',
        values = pearlLabels,
        defaultIndex = pearlSelected,
        set = function(index) SetVehicleExtraColours(vehicle, pearlIds[index], wheelColor) end,
        restore = function() SetVehicleExtraColours(vehicle, pearl, wheelColor) end,
    }

    local wheelPaints = combinePaints({ 'Metallic', 'Solid', 'Matte', 'Metals', 'Chameleon' }, true)
    local wheelIds, wheelLabels, wheelSelected = listPaints(wheelPaints, wheelColor)
    entries[#entries + 1] = {
        label = 'Wheel Color',
        values = wheelLabels,
        defaultIndex = wheelSelected,
        set = function(index) SetVehicleExtraColours(vehicle, pearl, wheelIds[index]) end,
        restore = function() SetVehicleExtraColours(vehicle, pearl, wheelColor) end,
    }

    local tint = GetVehicleWindowTint(vehicle)
    entries[#entries + 1] = {
        label = 'Window Tint',
        values = Config.Bennys.WindowTints,
        defaultIndex = tint + 1,
        set = function(index) SetVehicleWindowTint(vehicle, index - 1) end,
        restore = function() SetVehicleWindowTint(vehicle, tint) end,
    }

    local dashboard = GetVehicleDashboardColor(vehicle)
    local dashboardIds, dashboardLabels, dashboardSelected = listPaints(getPaints('Metallic'), dashboard)
    entries[#entries + 1] = {
        label = 'Dashboard Color',
        values = dashboardLabels,
        defaultIndex = dashboardSelected,
        set = function(index) SetVehicleDashboardColor(vehicle, dashboardIds[index]) end,
        restore = function() SetVehicleDashboardColor(vehicle, dashboard) end,
    }

    local interior = GetVehicleInteriorColor(vehicle)
    local interiorIds, interiorLabels, interiorSelected = listPaints(getPaints('Metallic'), interior)
    entries[#entries + 1] = {
        label = 'Interior Color',
        values = interiorLabels,
        defaultIndex = interiorSelected,
        set = function(index) SetVehicleInteriorColor(vehicle, interiorIds[index]) end,
        restore = function() SetVehicleInteriorColor(vehicle, interior) end,
    }

    -- Older vehicles use the livery native, newer ones the livery mod slot.
    local legacyLivery = GetVehicleLivery(vehicle)
    local modLivery = GetVehicleMod(vehicle, LIVERY_MOD)
    local usesLegacy = not (modLivery >= 0 or legacyLivery == -1)
    local liveryLabels = {}
    if usesLegacy then
        for i = 0, GetVehicleLiveryCount(vehicle) - 1 do liveryLabels[i + 1] = ('Livery %d'):format(i + 1) end
    else
        liveryLabels[1] = 'Stock'
        for i = 0, GetNumVehicleMods(vehicle, LIVERY_MOD) - 1 do liveryLabels[i + 2] = getModLabel(LIVERY_MOD, i) end
    end
    if #liveryLabels > 0 then
        local original = usesLegacy and legacyLivery or modLivery
        entries[#entries + 1] = {
            label = 'Vehicle Livery',
            values = liveryLabels,
            defaultIndex = usesLegacy and original + 1 or original + 2,
            set = function(index)
                if usesLegacy then SetVehicleLivery(vehicle, index - 1) else SetVehicleMod(vehicle, LIVERY_MOD, index - 2, false) end
            end,
            restore = function()
                if usesLegacy then SetVehicleLivery(vehicle, original) else SetVehicleMod(vehicle, LIVERY_MOD, original, false) end
            end,
        }
    end

    sortByLabel(entries)
    return 'Cosmetics - Colors', entries, 'main'
end

---@param isPrimary boolean
---@return string, table[], string
local function buildPaintMenu(isPrimary)
    local vehicle = bennys.vehicle
    local primary, secondary = GetVehicleColours(vehicle)
    local entries = {}

    for _, category in ipairs(Config.Bennys.PaintCategories) do
        local ids, labels, selected = listPaints(getPaints(category), isPrimary and primary or secondary)
        entries[#entries + 1] = {
            label = category,
            values = labels,
            defaultIndex = selected,
            set = function(index)
                if isPrimary then
                    SetVehicleColours(vehicle, ids[index], secondary)
                else
                    SetVehicleColours(vehicle, primary, ids[index])
                end
            end,
            restore = function() SetVehicleColours(vehicle, primary, secondary) end,
        }
    end

    return isPrimary and 'Primary Paint' or 'Secondary Paint', entries, 'colors'
end

function MENU_BUILDERS.paintPrimary() return buildPaintMenu(true) end
function MENU_BUILDERS.paintSecondary() return buildPaintMenu(false) end

function MENU_BUILDERS.neon()
    local vehicle = bennys.vehicle
    local entries = {}

    for side, sideLabel in ipairs({ 'Left', 'Right', 'Front', 'Back' }) do
        local enabled = IsVehicleNeonLightEnabled(vehicle, side - 1)
        entries[#entries + 1] = {
            label = ('Neon %s'):format(sideLabel),
            values = { 'Disabled', 'Enabled' },
            defaultIndex = enabled and 2 or 1,
            set = function(index) SetVehicleNeonLightEnabled(vehicle, side - 1, index == 2) end,
            restore = function() SetVehicleNeonLightEnabled(vehicle, side - 1, enabled) end,
        }
    end

    local r, g, b = GetVehicleNeonLightsColour(vehicle)
    local colorLabels, selected = {}, 1
    for i, color in ipairs(Config.Bennys.NeonColors) do
        colorLabels[i] = color[1]
        if color[2] == r and color[3] == g and color[4] == b then selected = i end
    end
    entries[#entries + 1] = {
        label = 'Neon Color',
        values = colorLabels,
        defaultIndex = selected,
        set = function(index)
            local color = Config.Bennys.NeonColors[index]
            if color then SetVehicleNeonLightsColour(vehicle, color[2], color[3], color[4]) end
        end,
        restore = function() SetVehicleNeonLightsColour(vehicle, r, g, b) end,
    }

    return 'Neon Customization', entries, 'colors'
end

function MENU_BUILDERS.wheels()
    local vehicle = bennys.vehicle
    local wheelType = GetVehicleWheelType(vehicle)
    local frontWheel = GetVehicleMod(vehicle, FRONT_WHEELS_MOD)
    local rearWheel = GetVehicleMod(vehicle, REAR_WHEELS_MOD)
    local entries = {}

    local function restore()
        SetVehicleWheelType(vehicle, wheelType)
        SetVehicleMod(vehicle, FRONT_WHEELS_MOD, frontWheel, false)
        SetVehicleMod(vehicle, REAR_WHEELS_MOD, rearWheel, false)
    end

    -- Mod counts depend on the wheel type, so each type is selected to read them.
    for typeId, typeLabel in pairs(Config.Bennys.WheelTypes) do
        SetVehicleWheelType(vehicle, typeId)
        local labels = {}
        for index = 0, GetNumVehicleMods(vehicle, FRONT_WHEELS_MOD) - 1 do labels[index + 1] = getModLabel(FRONT_WHEELS_MOD, index) end

        if #labels > 0 then
            entries[#entries + 1] = {
                label = typeLabel,
                values = labels,
                defaultIndex = (wheelType == typeId and frontWheel >= 0) and frontWheel + 1 or 1,
                set = function(index)
                    SetVehicleWheelType(vehicle, typeId)
                    SetVehicleMod(vehicle, FRONT_WHEELS_MOD, index - 1, false)
                end,
                restore = restore,
            }
        end
    end
    sortByLabel(entries)

    if GetVehicleClass(vehicle) == MOTORCYCLE_CLASS then
        SetVehicleWheelType(vehicle, BIKE_WHEEL_TYPE)
        local labels = {}
        for index = 0, GetNumVehicleMods(vehicle, REAR_WHEELS_MOD) - 1 do labels[index + 1] = getModLabel(REAR_WHEELS_MOD, index) end

        if #labels > 0 then
            entries[#entries + 1] = {
                label = 'Bike Rear Wheel',
                values = labels,
                defaultIndex = (wheelType == BIKE_WHEEL_TYPE and rearWheel >= 0) and rearWheel + 1 or 1,
                set = function(index)
                    SetVehicleWheelType(vehicle, BIKE_WHEEL_TYPE)
                    SetVehicleMod(vehicle, REAR_WHEELS_MOD, index - 1, false)
                end,
                restore = restore,
            }
        end
    end

    SetVehicleWheelType(vehicle, wheelType)
    return 'Wheels & Rims', entries, 'parts'
end

function MENU_BUILDERS.extras()
    local vehicle = bennys.vehicle
    local entries = {}

    for extra = 1, 14 do
        if DoesExtraExist(vehicle, extra) then
            local enabled = IsVehicleExtraTurnedOn(vehicle, extra)
            entries[#entries + 1] = {
                label = ('Extra %d'):format(extra),
                values = { 'Enabled', 'Disabled' },
                defaultIndex = enabled and 1 or 2,
                -- SetVehicleExtra's last argument means "disable".
                set = function(index) SetVehicleExtra(vehicle, extra, index == 2) end,
                restore = function() SetVehicleExtra(vehicle, extra, not enabled) end,
            }
        end
    end

    return 'Vehicle Extras', entries, 'main'
end

---@param name string
---@param index? integer
local function showBennysMenu(name, index)
    local title, entries, parent = MENU_BUILDERS[name]()
    local menuId = 'butter_admin_bennys_' .. name

    -- Handlers stay in `entries`; only plain data goes to the menu UI.
    local options = {}
    for i, entry in ipairs(entries) do
        options[i] = { label = entry.label, description = entry.description, values = entry.values, defaultIndex = entry.defaultIndex, close = true }
    end

    lib.registerMenu({
        id = menuId,
        title = title,
        position = 'top-left',
        canClose = true,
        disableInput = false,
        options = options,
        onSelected = function(selected)
            playNavigationSound()
            bennys.lastIndex[name] = selected
        end,
        onSideScroll = function(selected, scrollIndex)
            playNavigationSound()
            local entry = entries[selected]
            if entry?.set then entry.set(scrollIndex) end
        end,
        onClose = function()
            if bennys.transitioning then return end
            for _, entry in ipairs(entries) do
                if entry.restore then entry.restore() end
            end

            if parent then return transition(function() showBennysMenu(parent) end) end
            stopCamera()
            saveVehicleProps()
        end,
    }, function(selected, scrollIndex)
        local entry = entries[selected]
        if not entry then return end

        transition(function()
            if entry.submenu then return showBennysMenu(entry.submenu, 1) end

            if entry.action then
                entry.action()
            else
                if entry.set then entry.set(scrollIndex) end
                saveVehicleProps()
            end
            showBennysMenu(name)
        end)
    end)

    lib.showMenu(menuId, index or bennys.lastIndex[name] or 1)
end

-- Sent only after the server authorized the admin. The target may be a regular
-- player without permissions, so there is no local check; saving is gated server-side.
RegisterNetEvent('butter_admin:client:openBennys', function()
    local vehicle = getTargetVehicle()
    if not vehicle then return Notify(locale('notify.no_vehicle_found'), 'error') end

    CloseAdminMenu()
    bennys.vehicle = vehicle
    bennys.lastIndex = {}
    bennys.transitioning = false
    SetVehicleModKit(vehicle, 0)

    startCamera()
    showBennysMenu('main', 1)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then stopCamera() end
end)
