Utils = {}

Utils.RefreshRateMultiplier = 1.0

function Utils.SetRefreshRate(refreshRate)
    if refreshRate == 0 then
        Utils.RefreshRateMultiplier = 0.0
    elseif refreshRate == 60 then
        Utils.RefreshRateMultiplier = 1.0
    elseif refreshRate == 45 then
        Utils.RefreshRateMultiplier = 1.5
    elseif refreshRate == 30 then
        Utils.RefreshRateMultiplier = 2.0
    else
        Utils.RefreshRateMultiplier = 1.0
    end
    debugPrint('Refresh rate set to:', refreshRate, 'Multiplier:', Utils.RefreshRateMultiplier)
end

function Utils.Wait(ms)
    return math.floor(ms * Utils.RefreshRateMultiplier)
end

Utils.W = Utils.Wait

function Utils.clamp(val)
    return math.max(0, math.min(100, math.floor(val)))
end

function Utils.clampRange(val, min, max)
    return math.max(min, math.min(max, val))
end

function Utils.CreateAdaptiveInterval(opts)
    local baseMin = opts.min or 500
    local baseMax = opts.max or 3000
    local baseStep = opts.step or 200

    local interval = {
        current = baseMin,
        min = baseMin,
        max = baseMax,
        step = baseStep,
        baseMin = baseMin,
        baseMax = baseMax,
        baseStep = baseStep,
        threshold = opts.threshold or 3,
        stableCount = 0
    }

    -- Update interval values based on refresh rate multiplier
    function interval.applyMultiplier()
        local mult = Utils.RefreshRateMultiplier
        interval.min = math.floor(interval.baseMin * mult)
        interval.max = math.floor(interval.baseMax * mult)
        interval.step = math.floor(interval.baseStep * mult)
        -- Clamp current to new bounds
        interval.current = math.max(interval.min, math.min(interval.current, interval.max))
    end

    function interval.onChanged()
        interval.applyMultiplier()
        interval.current = interval.min
        interval.stableCount = 0
    end

    function interval.onStable()
        interval.applyMultiplier()
        interval.stableCount = interval.stableCount + 1
        if interval.stableCount >= interval.threshold then
            interval.current = math.min(interval.current + interval.step, interval.max)
        end
    end

    function interval.reset()
        interval.applyMultiplier()
        interval.current = interval.min
        interval.stableCount = 0
    end

    function interval.setMax()
        interval.applyMultiplier()
        interval.current = interval.max
    end

    return interval
end

function Utils.ParamPacker(...)
    local params, pack = { ... }, {}
    for i = 1, #params do
        pack[i] = { param = params[i] }
    end
    return pack
end

function Utils.ParamUnpacker(params, index)
    local idx = index or 1
    if idx <= #params then
        return params[idx]["param"], Utils.ParamUnpacker(params, idx + 1)
    end
end

function debugPrint(...)
    if Config and Config.Debug then
        print('^3[CODEM-HUD]^7', ...)
    end
end

function Utils.GetCurrentVehicle(checkLast)
    if not IsDuplicityVersion() then
        local vehicle = cache.vehicle
        if not vehicle or vehicle == 0 then
            vehicle = GetVehiclePedIsIn(cache.ped, checkLast or false)
        end
        return vehicle or 0
    end
    return 0
end

function Utils.ValidateVehicle(vehicle)
    if IsDuplicityVersion() then return false end
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
end

function Utils.GetNormalizedPlate(vehicle)
    if not vehicle or vehicle == 0 then return '' end
    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate then return '' end
    return plate:gsub('%s+', '')
end

function Utils.EnsureParticleFxAsset(assetName, timeout)
    if not IsDuplicityVersion() then
        if HasNamedPtfxAssetLoaded(assetName) then
            return true
        end

        RequestNamedPtfxAsset(assetName)
        local endTime = GetGameTimer() + (timeout or 2000)

        while not HasNamedPtfxAssetLoaded(assetName) do
            if GetGameTimer() > endTime then
                debugPrint('Failed to load particle asset:', assetName)
                return false
            end
            Wait(10)
        end
        return true
    end
    return false
end

function Utils.LoadStreamedTexture(textureName, timeout)
    if IsDuplicityVersion() then return false end

    if HasStreamedTextureDictLoaded(textureName) then
        return true
    end

    RequestStreamedTextureDict(textureName, false)
    local endTime = GetGameTimer() + (timeout or 2000)

    while not HasStreamedTextureDictLoaded(textureName) do
        if GetGameTimer() > endTime then
            debugPrint('Failed to load texture:', textureName)
            return false
        end
        Wait(100)
    end
    return true
end

function Utils.LoadModel(model, timeout)
    if IsDuplicityVersion() then return false end

    local hash = type(model) == 'string' and joaat(model) or model

    if HasModelLoaded(hash) then
        return true
    end

    if not IsModelValid(hash) then
        debugPrint('Invalid model:', model)
        return false
    end

    RequestModel(hash)
    local endTime = GetGameTimer() + (timeout or 5000)

    while not HasModelLoaded(hash) do
        if GetGameTimer() > endTime then
            debugPrint('Failed to load model:', model)
            return false
        end
        Wait(100)
    end
    return true
end

function Utils.IsDriver()
    if not IsDuplicityVersion() then
        return cache.vehicle and cache.vehicle ~= 0 and cache.seat == -1
    end
    return false
end

function Utils.GetPedVehicleSeat(ped)
    if IsDuplicityVersion() then return -2 end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then return -2 end
    for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) do
        if GetPedInVehicleSeat(vehicle, i) == ped then
            return i
        end
    end
    return -2
end

-- Navigation Utils (shared between boatnav, helinav, fastnav)
Utils.Nav = {}

function Utils.Nav.LoadLocationsFromJSON(jsonPath, moduleName)
    local jsonFile = LoadResourceFile(GetCurrentResourceName(), jsonPath)
    if not jsonFile then
        print('^1[' .. moduleName .. '] Failed to load ' .. jsonPath .. '^7')
        return nil
    end

    local success, data = pcall(json.decode, jsonFile)
    if not success or not data then
        print('^1[' .. moduleName .. '] Failed to parse ' .. jsonPath .. '^7')
        return nil
    end

    return data
end

function Utils.Nav.ParseSimpleLocations(data)
    local locations = {}
    for i, item in ipairs(data) do
        if item.coords and item.name then
            locations[i] = {
                coords = vector3(item.coords[1], item.coords[2], item.coords[3]),
                name = item.name
            }
        end
    end
    return locations
end

function Utils.Nav.GetLocation(locations, index)
    local loc = locations[index]
    if not loc then return nil, nil, nil end

    local playerPos = GetEntityCoords(PlayerPedId())
    local distance = #(playerPos - loc.coords)

    return loc.coords, distance, loc.name
end

function Utils.Nav.SetWaypoint(coords)
    if not coords then return false end
    SetNewWaypoint(coords.x, coords.y)
    return true
end

function Utils.Nav.CreateInputThread(opts)
    local isOpen = opts.isOpen
    local prefix = opts.prefix
    local hasSelect = opts.hasSelect ~= false

    CreateThread(function()
        local IsControlJustPressed = IsControlJustPressed
        local IsDisabledControlJustPressed = IsDisabledControlJustPressed
        local ARROW_LEFT = Constants.Controls.ARROW_LEFT
        local ARROW_RIGHT = Constants.Controls.ARROW_RIGHT
        local ENTER = Constants.Controls.ENTER

        while true do
            if isOpen() then
                if IsDisabledControlJustPressed(0, ARROW_LEFT) then
                    NuiMessage(prefix .. ':navigate', { direction = 'left' })
                end
                if IsDisabledControlJustPressed(0, ARROW_RIGHT) then
                    NuiMessage(prefix .. ':navigate', { direction = 'right' })
                end
                if hasSelect and IsControlJustPressed(0, ENTER) then
                    NuiMessage(prefix .. ':select')
                end
                Wait(5)
            else
                Wait(Utils.W(500))
            end
        end
    end)
end
