-- oxlyn-truckjob routes admin (decompiled output, cleaned: names restored, temp registers removed)
-- Lets admins create / edit / remove routes in-game; routes are persisted to a JSON file
-- and rebuilt into Config.Routes.
-- Relies on globals defined elsewhere: Config, Bridge, Notify, Debug, _U, json

RoutesAdmin = RoutesAdmin or {}

local PERSIST_FILE = (Config.Admin and Config.Admin.persistFile) or "data/routes.json"

local pendingCaptures = {} -- [src] = { pickup = {...}, delivery = {...} } while an admin is creating a route
local adminRoutes = {}     -- routes created by admins (raw saved form)

---------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------
local function loadRoutes()
    local raw = LoadResourceFile(GetCurrentResourceName(), PERSIST_FILE)
    if not raw or raw == "" then
        Debug.info(('routes file "%s" is empty or missing - starting fresh'):format(PERSIST_FILE))
        return {}
    end

    local ok, decoded = pcall(json.decode, raw)
    if not (ok and type(decoded) == "table") then
        Debug.error(('routes file "%s" is corrupt - starting fresh'):format(PERSIST_FILE))
        return {}
    end

    return decoded.routes or {}
end

local function saveRoutes()
    local encoded = json.encode({ routes = adminRoutes, savedAt = os.time() })
    local ok = SaveResourceFile(GetCurrentResourceName(), PERSIST_FILE, encoded, -1)

    if not ok then
        Debug.error(('failed to save routes to "%s" - check resource permissions'):format(PERSIST_FILE))
    else
        Debug.info(('saved %d route(s) to "%s"'):format(#adminRoutes, PERSIST_FILE))
    end
    return ok
end

local function persist()
    saveRoutes()
end

---------------------------------------------------------------------
-- Auto-balance helpers (value / level / difficulty from distance)
---------------------------------------------------------------------
local function distanceKm(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) / 1000.0
end

local function difficultyForKm(km)
    local tiers = (Config.AutoBalance and Config.AutoBalance.difficultyByDistance)
        or { { km = 0, tier = "easy" } }

    local tier = tiers[1].tier
    for _, entry in ipairs(tiers) do
        if km >= entry.km then
            tier = entry.tier
        else
            break
        end
    end
    return tier
end

local function levelForKm(km)
    local tiers = (Config.AutoBalance and Config.AutoBalance.levelByDistance)
        or { { km = 0, level = 1 } }

    local level = tiers[1].level
    for _, entry in ipairs(tiers) do
        if km >= entry.km then
            level = entry.level
        else
            break
        end
    end
    return level
end

local function randomTrailer()
    local trailers = Config.Trailers or { "trailers" }
    return trailers[math.random(#trailers)]
end

local function randomCargo()
    local cargos = (Config.Admin and Config.Admin.defaultCargos) or { "Mercadoria" }
    return cargos[math.random(#cargos)]
end

-- Effective km / value / level / difficulty for a route (manual overrides win over auto-balance)
local function resolveStats(route)
    local km = distanceKm(route.pickup, route.delivery)
    local cfg = Config.AutoBalance or {}
    local overrides = (Config.RouteOverrides and Config.RouteOverrides[route.id]) or {}

    local autoValue
    if cfg.enabled then
        autoValue = math.max(
            cfg.basePrice or 0,
            math.floor((cfg.basePrice or 0) + km * (cfg.pricePerKm or 0))
        )
    else
        autoValue = 250
    end

    local autoLevel = levelForKm(km)
    local autoDifficulty = difficultyForKm(km)

    return {
        km = km,
        value = overrides.value or route.value or autoValue,
        level = overrides.level or route.minLevel or autoLevel,
        difficulty = overrides.difficulty or route.difficulty or autoDifficulty,
    }
end

---------------------------------------------------------------------
-- Building Config.Routes from the saved routes
---------------------------------------------------------------------
local function buildRoute(route)
    local stats = resolveStats(route)

    return {
        id = route.id,
        label = route.label or route.cargo or "Rota", -- "Rota" = "Route"
        cargo = route.cargo or randomCargo(),
        difficulty = stats.difficulty,
        value = stats.value,
        image = route.image or "crate.svg",
        trailer = route.trailer or randomTrailer(),
        pickup = vector3(route.pickup.x, route.pickup.y, route.pickup.z),
        deliveries = { vector3(route.delivery.x, route.delivery.y, route.delivery.z) },
        pickupHeading = route.pickupHeading,
        pickupLocked = route.pickupLocked or false,
        _km = stats.km,
        _minLevel = stats.level,
    }
end

-- Keeps Config.XP.routeMinLevel in sync with the admin routes
local function applyMinLevels()
    Config.XP = Config.XP or {}
    Config.XP.routeMinLevel = Config.XP.routeMinLevel or {}

    for _, route in ipairs(adminRoutes) do
        Config.XP.routeMinLevel[route.id] = resolveStats(route).level
    end
end

local function rebuildRoutes()
    Config.Routes = {}
    for _, route in ipairs(adminRoutes) do
        Config.Routes[#Config.Routes + 1] = buildRoute(route)
    end
    applyMinLevels()
end

RoutesAdmin.Rebuild = function()
    rebuildRoutes()
end

local function generateRouteId()
    return ("route_%d_%04x"):format(os.time(), math.random(0, 65535))
end

---------------------------------------------------------------------
-- Messaging / permissions
---------------------------------------------------------------------
local function sendChat(src, message, kind)
    local color = { 244, 244, 245 }
    if kind == "error" then color = { 239, 68, 68 } end
    if kind == "warning" then color = { 245, 158, 11 } end

    TriggerClientEvent("chat:addMessage", src, {
        color = color,
        multiline = true,
        args = { "[criarrota]", message }, -- "criarrota" = "create route"
    })
end

local function reply(src, message, kind, duration)
    sendChat(src, message, kind or "info")

    if Notify and Notify.Send then
        Notify.Send(src, message, kind or "info", duration or 5000)
    end

    Debug.info(("admin -> %s | %s | %s"):format(src, kind or "info", message))
end

local function requireAdmin(src)
    if Bridge.IsAdmin(src) then
        return true
    end

    Debug.warn(('admin command denied: src=%s, missing ace "%s" and not in admin group'):format(
        src, (Config.Admin and Config.Admin.aceFlag) or "?"))
    reply(src, _U("admin_only"), "error", 7000)
    return false
end

---------------------------------------------------------------------
-- Creating a route (capture pickup, then delivery)
---------------------------------------------------------------------
local function finalizeCapture(src)
    local capture = pendingCaptures[src]
    if not (capture and capture.pickup and capture.delivery) then return end

    local pickupPos = vector3(capture.pickup.x, capture.pickup.y, capture.pickup.z)
    local deliveryPos = vector3(capture.delivery.x, capture.delivery.y, capture.delivery.z)

    if #(pickupPos - deliveryPos) < 200.0 then
        reply(src, _U("admin_too_close"), "warning")
        return
    end

    -- Label = "<pickup zone/street> → <delivery zone/street>"
    local pickupName = (capture.pickup.zone ~= "" and capture.pickup.zone)
        or capture.pickup.street or "Recolha"        -- "Recolha" = "Pickup"
    local deliveryName = (capture.delivery.zone ~= "" and capture.delivery.zone)
        or capture.delivery.street or "Entrega"      -- "Entrega" = "Delivery"
    local label = ("%s → %s"):format(pickupName, deliveryName)

    local cargo = randomCargo()

    local newRoute = {
        id = generateRouteId(),
        label = label,
        cargo = cargo,
        pickup = { x = capture.pickup.x, y = capture.pickup.y, z = capture.pickup.z },
        delivery = { x = capture.delivery.x, y = capture.delivery.y, z = capture.delivery.z },
        pickupHeading = capture.pickup.heading or 0.0,
        zonePickup = capture.pickup.zone or "",
        zoneDelivery = capture.delivery.zone or "",
        streetPickup = capture.pickup.street or "",
        streetDelivery = capture.delivery.street or "",
        createdAt = os.time(),
        createdBy = (Bridge.GetName and Bridge.GetName(src)) or ("admin#" .. src),
    }

    adminRoutes[#adminRoutes + 1] = newRoute
    pendingCaptures[src] = nil

    rebuildRoutes()
    persist()

    -- Report the auto-balanced value / level
    local km = distanceKm(pickupPos, deliveryPos)
    local cfg = Config.AutoBalance or {}
    local value = math.max(
        cfg.basePrice or 0,
        math.floor((cfg.basePrice or 0) + km * (cfg.pricePerKm or 0))
    )
    local level = levelForKm(km)

    reply(src, _U("admin_saved", newRoute.label, Config.Currency or "$", value, level), "success", 7000)
end

RegisterNetEvent("oxlyn-truckjob:server:admin:capture", function(kind, data)
    local src = source
    if not requireAdmin(src) then return end
    if type(data) ~= "table" then return end

    pendingCaptures[src] = pendingCaptures[src] or {}

    if kind == "pickup" then
        pendingCaptures[src].pickup = data

        local where = (data.zone ~= "" and data.zone) or (data.street ~= "" and data.street) or "—"
        reply(src, _U("admin_pickup_set", where), "success")

    elseif kind == "delivery" then
        if not pendingCaptures[src].pickup then
            reply(src, _U("admin_need_pickup"), "warning")
            return
        end

        pendingCaptures[src].delivery = data
        finalizeCapture(src)
    end
end)

RegisterNetEvent("oxlyn-truckjob:server:admin:cancel", function()
    local src = source
    if not requireAdmin(src) then return end

    pendingCaptures[src] = nil
    reply(src, _U("admin_canceled"), "info")
end)

---------------------------------------------------------------------
-- Finding a route by list index, full id, or id suffix
---------------------------------------------------------------------
local function findRoute(query)
    if not query or query == "" then
        return nil, nil
    end

    local index = tonumber(query)
    if index and adminRoutes[index] then
        return adminRoutes[index], index
    end

    for i, route in ipairs(adminRoutes) do
        if route.id == query then
            return route, i
        end
    end

    local lowered = query:lower()
    for i, route in ipairs(adminRoutes) do
        if route.id:lower():sub(-#lowered) == lowered then
            return route, i
        end
    end

    return nil, nil
end

local function replyNotFound(src, query)
    reply(src, _U("admin_not_found", tostring(query)), "warning")
end

---------------------------------------------------------------------
-- Overrides (level / value / difficulty)
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:server:admin:setOverride", function(query, field, value)
    local src = source
    if not requireAdmin(src) then return end

    local route, index = findRoute(query)
    if not route then
        replyNotFound(src, query)
        return
    end

    if field == "level" then
        route.minLevel = math.max(1, math.floor(tonumber(value) or 1))
    elseif field == "value" then
        route.value = math.max(0, math.floor(tonumber(value) or 0))
    elseif field == "difficulty" then
        if value ~= "easy" and value ~= "medium" and value ~= "hard" then
            return
        end
        route.difficulty = value
    else
        return
    end

    rebuildRoutes()
    persist()

    local stats = resolveStats(route)
    reply(src, _U("admin_override_set", index, route.label, stats.level,
        Config.Currency or "$", stats.value, stats.difficulty), "success")
end)

RegisterNetEvent("oxlyn-truckjob:server:admin:clearOverride", function(query)
    local src = source
    if not requireAdmin(src) then return end

    local route, index = findRoute(query)
    if not route then
        replyNotFound(src, query)
        return
    end

    route.minLevel = nil
    route.value = nil
    route.difficulty = nil

    rebuildRoutes()
    persist()

    local stats = resolveStats(route)
    reply(src, _U("admin_override_cleared", index, route.label, stats.level,
        Config.Currency or "$", stats.value), "success")
end)

---------------------------------------------------------------------
-- Removing a route
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:server:admin:remove", function(query)
    local src = source
    if not requireAdmin(src) then return end

    local route, index = findRoute(query)
    if not route then
        replyNotFound(src, query)
        return
    end

    local id = route.id
    table.remove(adminRoutes, index)

    rebuildRoutes()
    persist()

    reply(src, _U("admin_removed", id), "success")
end)

---------------------------------------------------------------------
-- Editing the pickup / trailer of a route
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:server:admin:requestEdit", function(query, trailerOverride)
    local src = source
    if not requireAdmin(src) then return end

    local route, index = findRoute(query)
    if not route then
        replyNotFound(src, query)
        return
    end

    -- Warn (but allow) trailer models that aren't in Config.Trailers
    if trailerOverride and trailerOverride ~= "" then
        local known = false
        for _, model in ipairs(Config.Trailers or {}) do
            if model == trailerOverride then
                known = true
                break
            end
        end
        if not known then
            reply(src, ('Trailer model "%s" is not in Config.Trailers — using anyway.'):format(trailerOverride), "warning")
        end
    end

    TriggerClientEvent("oxlyn-truckjob:client:admin:beginEdit", src, {
        id = route.id,
        index = index,
        label = route.label,
        pickup = { x = route.pickup.x, y = route.pickup.y, z = route.pickup.z },
        pickupHeading = route.pickupHeading or 0.0,
        trailer = route.trailer,
        trailerOverride = trailerOverride,
        pickupLocked = route.pickupLocked or false,
    })
end)

RegisterNetEvent("oxlyn-truckjob:server:admin:saveTrailerPos", function(query, data)
    local src = source
    if not requireAdmin(src) then return end
    if type(data) ~= "table" then return end

    local route, index = findRoute(query)
    if not route then
        replyNotFound(src, query)
        return
    end

    route.pickup = {
        x = tonumber(data.x) or route.pickup.x,
        y = tonumber(data.y) or route.pickup.y,
        z = tonumber(data.z) or route.pickup.z,
    }

    if tonumber(data.heading) then
        route.pickupHeading = tonumber(data.heading)
    end

    if type(data.trailer) == "string" and data.trailer ~= "" then
        route.trailer = data.trailer
    end

    route.pickupLocked = true

    rebuildRoutes()
    persist()

    reply(src, _U("admin_edit_saved",
        index or 0,
        route.label or route.id,
        route.pickup.x, route.pickup.y, route.pickup.z,
        route.pickupHeading or 0.0,
        route.trailer or "—"), "success", 7000)
end)

RegisterNetEvent("oxlyn-truckjob:server:admin:setTrailer", function(query, model)
    local src = source
    if not requireAdmin(src) then return end
    if type(model) ~= "string" or model == "" then return end

    local route, index = findRoute(query)
    if not route then
        replyNotFound(src, query)
        return
    end

    route.trailer = model

    rebuildRoutes()
    persist()

    reply(src, _U("admin_trailer_set", index or 0, route.label or route.id, model), "success")
end)

RegisterNetEvent("oxlyn-truckjob:server:admin:unlockPickup", function(query)
    local src = source
    if not requireAdmin(src) then return end

    local route, index = findRoute(query)
    if not route then
        replyNotFound(src, query)
        return
    end

    route.pickupLocked = nil

    rebuildRoutes()
    persist()

    reply(src, _U("admin_edit_unlocked", index or 0, route.label or route.id), "success")
end)

---------------------------------------------------------------------
-- Listing routes
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:server:admin:list", function()
    local src = source
    if not requireAdmin(src) then return end

    if #adminRoutes == 0 then
        reply(src, _U("admin_list_empty"), "info")
        return
    end

    reply(src, _U("admin_list_header", #adminRoutes), "info")

    for index, route in ipairs(adminRoutes) do
        local stats = resolveStats(route)

        -- " *" marks routes with manual overrides
        local overridden = (route.value or route.minLevel or route.difficulty) and " *" or ""

        local line = _U("admin_list_entry",
            index, route.id, route.label,
            ("%.2f"):format(stats.km),
            stats.level,
            Config.Currency or "$",
            stats.value,
            stats.difficulty)

        reply(src, line .. overridden, "info")
    end
end)

---------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------
AddEventHandler("playerDropped", function()
    pendingCaptures[source] = nil
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    saveRoutes()
end)

-- Load saved routes on start
CreateThread(function()
    Wait(0)
    adminRoutes = loadRoutes()
    rebuildRoutes()
    Debug.info(("admin routes loaded: %d"):format(#adminRoutes))
end)