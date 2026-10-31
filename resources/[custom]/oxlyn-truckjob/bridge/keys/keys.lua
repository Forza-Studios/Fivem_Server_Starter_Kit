VehicleKeys = VehicleKeys or {}

local GIVE_EVENT = "oxlyn-truckjob:server:vehkeys:give"
local REMOVE_EVENT = "oxlyn-truckjob:server:vehkeys:remove"

---------------------------------------------------------------------------
-- Supported key systems
--
-- Each system has:
--   resource     the resource name used for auto-detection
--   client       (vehicle, plate, model)            -> list of attempt functions
--   server       (src, vehicle, plate, model)       -> list of attempt functions (give)
--   serverRemove (src, vehicle, plate, model)       -> list of attempt functions (remove)
-- Each attempt is tried in order until one succeeds (does not error).
---------------------------------------------------------------------------

local systems = {}

systems.qbx = {
    resource = "qbx_vehiclekeys",

    server = function(src, vehicle, plate)
        return {
            function() exports.qbx_vehiclekeys:GiveKeys(src, vehicle) end,
            function() exports.qbx_vehiclekeys:GiveKeys(src, plate) end,
            function() TriggerClientEvent("qbx_vehiclekeys:client:addKeys", src, plate) end,
        }
    end,

    serverRemove = function(src, vehicle, plate)
        return {
            function() exports.qbx_vehiclekeys:RemoveKeys(src, vehicle) end,
            function() exports.qbx_vehiclekeys:RemoveKeys(src, plate) end,
        }
    end,

    client = function(vehicle, plate)
        return {
            function() exports.qbx_vehiclekeys:SetVehicleKeys(vehicle, true) end,
            function() TriggerEvent("vehiclekeys:client:SetOwner", plate) end,
        }
    end,
}

systems.qb = {
    resource = "qb-vehiclekeys",

    client = function(vehicle, plate)
        return {
            function() TriggerEvent("vehiclekeys:client:SetOwner", plate) end,
        }
    end,

    server = function(src, vehicle, plate)
        return {
            function() TriggerClientEvent("vehiclekeys:client:SetOwner", src, plate) end,
        }
    end,

    serverRemove = function(src, vehicle, plate)
        return {
            function() TriggerClientEvent("qb-vehiclekeys:client:RemoveKeys", src, plate) end,
        }
    end,
}

systems.mrnewb = {
    resource = "MrNewbVehicleKeys",

    client = function(vehicle)
        return {
            function() exports.MrNewbVehicleKeys:GiveKeys(vehicle) end,
        }
    end,

    server = function(src, vehicle, plate)
        return {
            function() exports.MrNewbVehicleKeys:GiveKeysByPlate(src, plate) end,
        }
    end,

    serverRemove = function(src, vehicle, plate)
        return {
            function() exports.MrNewbVehicleKeys:RemoveKeysByPlate(src, plate) end,
        }
    end,
}

systems.wasabi = {
    resource = "wasabi_carlock",

    client = function(vehicle, plate)
        return {
            function() exports.wasabi_carlock:GiveKey(plate) end,
        }
    end,

    server = function(src, vehicle, plate)
        return {
            function() exports.wasabi_carlock:GiveKey(src, plate) end,
        }
    end,

    serverRemove = function(src, vehicle, plate)
        return {
            function() exports.wasabi_carlock:RemoveKey(src, plate) end,
        }
    end,
}

systems.renewed = {
    resource = "Renewed-Vehiclekeys",

    client = function(vehicle, plate)
        return {
            function() exports["Renewed-Vehiclekeys"]:addKey(plate) end,
        }
    end,

    server = function(src, vehicle, plate)
        return {
            function() exports["Renewed-Vehiclekeys"]:addKey(src, plate) end,
        }
    end,

    serverRemove = function(src, vehicle, plate)
        return {
            function() exports["Renewed-Vehiclekeys"]:removeKey(src, plate) end,
        }
    end,
}

systems.qs = {
    resource = "qs-vehiclekeys",

    client = function(vehicle, plate, model)
        return {
            function() exports["qs-vehiclekeys"]:GiveKeys(plate, model, true) end,
        }
    end,

    server = function(src, vehicle, plate)
        return {
            function() exports["qs-vehiclekeys"]:GiveKeys(src, plate) end,
        }
    end,

    serverRemove = function(src, vehicle, plate)
        return {
            function() exports["qs-vehiclekeys"]:RemoveKeys(src, plate) end,
        }
    end,
}

systems.ti = {
    resource = "ti_vehicleKeys",

    server = function(src, vehicle, plate, model)
        return {
            function() TriggerEvent("ti_vehicleKeys:createKey", src, plate, model) end,
        }
    end,

    serverRemove = function(src, vehicle, plate)
        return {
            function() TriggerEvent("ti_vehicleKeys:removeKey", src, plate) end,
        }
    end,
}

systems.jaksam = {
    resource = "vehicles_keys",

    client = function(vehicle, plate)
        return {
            function() TriggerServerEvent("vehicles_keys:selfGiveVehicleKeys", plate) end,
        }
    end,
}

systems.cd_garage = {
    resource = "cd_garage",

    client = function(vehicle, plate)
        return {
            function() TriggerEvent("cd_garage:AddKeys", plate) end,
        }
    end,
}

systems.okok = {
    resource = "okokGarage",

    client = function(vehicle, plate)
        return {
            function() TriggerEvent("okokGarage:GiveKeys", plate) end,
        }
    end,
}

-- Auto-detection order
local detectionOrder = {
    "qbx", "qb", "mrnewb", "wasabi", "renewed", "qs", "ti", "jaksam", "cd_garage", "okok",
}

---------------------------------------------------------------------------
-- System detection (cached after the first call)
---------------------------------------------------------------------------

local activeSystem = nil

function VehicleKeys.System()
    if activeSystem then
        return activeSystem
    end

    local cfg = Config.VehicleKeys or {}
    local configured = cfg.system or "auto"

    if configured ~= "auto" then
        activeSystem = systems[configured] and configured or "none"

        if activeSystem == "none" and configured ~= "none" then
            Debug.warn(('unknown VehicleKeys.system "%s" — keys disabled'):format(tostring(configured)))
        end
        return activeSystem
    end

    for _, name in ipairs(detectionOrder) do
        if GetResourceState(systems[name].resource) == "started" then
            activeSystem = name
            Debug.info("vehicle keys: detected", systems[name].resource)
            return activeSystem
        end
    end

    activeSystem = "none"
    Debug.info("vehicle keys: no key system detected")
    return activeSystem
end

-- Runs each attempt until one succeeds. Returns true on success.
local function tryAttempts(attempts, label)
    if type(attempts) ~= "table" then
        return false
    end

    for _, attempt in ipairs(attempts) do
        local ok, err = pcall(attempt)
        if ok then
            return true
        end
        Debug.info(("vehicle keys: %s attempt failed (%s)"):format(label, tostring(err)))
    end
    return false
end

if not IsDuplicityVersion() then
    -----------------------------------------------------------------------
    -- CLIENT
    -----------------------------------------------------------------------

    local lastGivenPlate = nil

    local function getPlate(vehicle)
        return GetVehicleNumberPlateText(vehicle) or ""
    end

    -- Gives the local player keys for a vehicle.
    function VehicleKeys.Give(vehicle)
        local cfg = Config.VehicleKeys or {}
        if cfg.enabled == false then
            return false
        end

        if not (vehicle and DoesEntityExist(vehicle)) then
            return false
        end

        local plate = getPlate(vehicle)
        local model = GetEntityModel(vehicle)

        -- Custom override
        if Overrides and type(Overrides.GiveVehicleKeys) == "function" then
            local ok, handled = pcall(Overrides.GiveVehicleKeys, vehicle, plate, model)
            if ok and handled then
                return true
            end
        end

        SetVehicleNeedsToBeHotwired(vehicle, false)
        SetVehicleHasBeenOwnedByPlayer(vehicle, true)
        SetVehicleEngineOn(vehicle, true, true, false)

        -- Tag the vehicle as a job truck (best effort)
        pcall(function()
            local state = Entity(vehicle).state
            if state then
                state:set("oxlynTruck", true, true)
            end
        end)

        -- Don't repeat the key grant for the same plate
        if lastGivenPlate == plate then
            return true
        end
        lastGivenPlate = plate

        local system = VehicleKeys.System()
        local adapter = systems[system]
        if adapter and adapter.client then
            tryAttempts(adapter.client(vehicle, plate, model), ("client give (%s)"):format(system))
        end

        for _, eventName in ipairs(cfg.extraClientEvents or {}) do
            pcall(TriggerEvent, eventName, plate, model, vehicle)
        end

        -- Let the server hand out keys for server-side systems
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        TriggerServerEvent(GIVE_EVENT, netId or 0, plate, model)
        return true
    end

    -- Removes keys for a vehicle (e.g. when it despawns).
    function VehicleKeys.Remove(vehicle)
        local cfg = Config.VehicleKeys or {}
        if cfg.enabled == false or cfg.removeOnDespawn == false then
            return false
        end

        if not (vehicle and DoesEntityExist(vehicle)) then
            return false
        end

        local plate = getPlate(vehicle)
        local model = GetEntityModel(vehicle)

        if plate == lastGivenPlate then
            lastGivenPlate = nil
        end

        -- Custom override
        if Overrides and type(Overrides.RemoveVehicleKeys) == "function" then
            local ok, handled = pcall(Overrides.RemoveVehicleKeys, vehicle, plate, model)
            if ok and handled then
                return true
            end
        end

        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        TriggerServerEvent(REMOVE_EVENT, netId or 0, plate, model)
        return true
    end
else
    -----------------------------------------------------------------------
    -- SERVER
    -----------------------------------------------------------------------

    -- Server-side permission check for granting keys. Refuses by default;
    -- other scripts are expected to override this (e.g. "has an active job").
    function VehicleKeys.CanGrant(source)
        return false
    end

    local lastRequestAt = {}   -- source -> os.time() of last request (rate limit)
    local lastGrantedPlate = {} -- source -> plate last granted

    -- True if the player sent a request less than 1 second ago.
    local function rateLimited(source)
        local now = os.time()
        local last = lastRequestAt[source]
        if last and (now - last) < 1 then
            return true
        end
        lastRequestAt[source] = now
        return false
    end

    AddEventHandler("playerDropped", function()
        lastRequestAt[source] = nil
        lastGrantedPlate[source] = nil
    end)

    -- Resolves a network id to a vehicle entity (0 if invalid) and its plate.
    local function resolveVehicle(netId, fallbackPlate)
        local vehicle = 0

        if netId and netId ~= 0 then
            local ok, entity = pcall(NetworkGetEntityFromNetworkId, netId)
            if ok and entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 2 then
                vehicle = entity
            end
        end

        local plate = fallbackPlate
        if vehicle ~= 0 then
            local ok, entityPlate = pcall(GetVehicleNumberPlateText, vehicle)
            if ok and entityPlate and entityPlate ~= "" then
                plate = entityPlate
            end
        end

        return vehicle, plate
    end

    local function handleRequest(source, netId, plate, model, action)
        local cfg = Config.VehicleKeys or {}

        if cfg.enabled == false then
            return
        end
        if action == "remove" and cfg.removeOnDespawn == false then
            return
        end
        if rateLimited(source) then
            return
        end

        if action == "give" and not VehicleKeys.CanGrant(source) then
            Debug.info(("vehicle keys: refused %s for %s (no active job)"):format(action, source))
            return
        end

        local vehicle, resolvedPlate = resolveVehicle(netId, plate)
        if type(resolvedPlate) ~= "string" or resolvedPlate == "" then
            return
        end
        plate = resolvedPlate

        -- Skip repeat grants for the same plate; clear the record on remove
        if action == "give" then
            if lastGrantedPlate[source] == plate then
                return
            end
            lastGrantedPlate[source] = plate
        else
            lastGrantedPlate[source] = nil
        end

        -- Custom override
        local overrideName = action == "give" and "GiveVehicleKeysServer" or "RemoveVehicleKeysServer"
        if Overrides and type(Overrides[overrideName]) == "function" then
            local ok, handled = pcall(Overrides[overrideName], source, vehicle, plate, model)
            if ok and handled then
                return
            end
        end

        -- Built-in system adapter
        local system = VehicleKeys.System()
        local adapter = systems[system]
        if adapter then
            local build = action == "give" and adapter.server or adapter.serverRemove
            if build then
                tryAttempts(
                    build(source, vehicle, plate, model),
                    ("server %s (%s)"):format(action, system)
                )
            end
        end

        -- Extra events from config
        local extraEvents
        if action == "give" then
            extraEvents = cfg.extraServerEvents or {}
        else
            extraEvents = cfg.extraServerRemoveEvents or {}
        end

        for _, eventName in ipairs(extraEvents) do
            pcall(TriggerEvent, eventName, source, plate, model, vehicle)
        end
    end

    RegisterNetEvent(GIVE_EVENT, function(netId, plate, model)
        handleRequest(source, netId, plate, model, "give")
    end)

    RegisterNetEvent(REMOVE_EVENT, function(netId, plate, model)
        handleRequest(source, netId, plate, model, "remove")
    end)
end