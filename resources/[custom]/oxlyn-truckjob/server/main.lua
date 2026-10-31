-- oxlyn-truckjob server (decompiled output, cleaned: names restored, temp registers removed)
-- Handles jobs, payment, XP/levels, route rotation, bonus events, persistence and ranking.
-- Relies on globals defined elsewhere: Config, Bridge, Inventory, Notify, Storage, Overrides,
-- VehicleKeys, Debug, _U

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local activeJobs = {}      -- [src] = { routeId, startedAt, identifier, entities, cargoLoaded }
local statsCache = {}      -- [identifier] = stats
local progressCache = {}   -- [identifier] = { level, xp }
local historyCache = {}    -- [identifier] = { recent deliveries }
local loadedPlayers = {}   -- [identifier] = true once loaded from storage
local rotationPools = {}   -- [identifier] = { unlocked, locked, prevAll, expiresAt }
local playerNames = {}     -- [identifier] = display name
local netIdOwner = {}      -- [netId] = src that registered the vehicle

-- Bonus event state
local bonusUntil = 0
local bonusNextAt = 0
local bonusMultiplier = 1.0
local bonusScope = "all"   -- "all" | "specific" | "random"
local bonusRoutesByPlayer = {}

if VehicleKeys then
    VehicleKeys.CanGrant = function(src)
        return activeJobs[src] ~= nil
    end
end

---------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------
local function getIdentifier(src)
    return Bridge.GetIdentifier(src)
end

local function newStats()
    return { totalPaid = 0, deliveries = 0, distanceM = 0, bestPay = 0, completed = {} }
end

local function newProgress()
    return { level = 1, xp = 0 }
end

local function rotationCfg()
    return Config.RouteRotation or {}
end

local function routeById(id)
    for _, route in ipairs(Config.Routes) do
        if route.id == id then return route end
    end
end

local function routeMinLevel(routeId)
    local minLevels = (Config.XP and Config.XP.routeMinLevel) or {}
    return minLevels[routeId] or 1
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end

---------------------------------------------------------------------
-- Bonus event
---------------------------------------------------------------------
function IsBonusActive()
    return os.time() < (bonusUntil or 0)
end

function GetBonusMultiplier()
    return bonusMultiplier
end

-- Is this route boosted for this player right now?
function IsRouteBoostedFor(identifier, routeId)
    if not IsBonusActive() then return false end

    if bonusScope == "all" then return true end

    if bonusScope == "specific" then
        for _, id in ipairs((Config.Bonus or {}).specificIds or {}) do
            if id == routeId then return true end
        end
        return false
    end

    local set = bonusRoutesByPlayer[identifier]
    return set ~= nil and set[routeId] == true
end

local function pickBonusMultiplier()
    local cfg = Config.Bonus or {}
    if cfg.randomMultipliers and #cfg.randomMultipliers > 0 then
        return cfg.randomMultipliers[math.random(#cfg.randomMultipliers)]
    end
    return cfg.multiplier or 1.2
end

-- Random picks from the player's currently unlocked rotation pool
local function pickRandomUnlocked(identifier, count)
    local pool = rotationPools[identifier]
    if not pool then return {} end

    local copy = {}
    for _, id in ipairs(pool.unlocked or {}) do
        copy[#copy + 1] = id
    end
    shuffle(copy)

    local picked = {}
    for i = 1, math.min(count, #copy) do
        picked[#picked + 1] = copy[i]
    end
    return picked
end

local function buildBonusPayload(identifier)
    local routeIds = {}

    if bonusScope == "all" then
        routeIds = "all"
    elseif bonusScope == "specific" then
        for _, id in ipairs((Config.Bonus or {}).specificIds or {}) do
            routeIds[#routeIds + 1] = id
        end
    else
        for id in pairs(bonusRoutesByPlayer[identifier] or {}) do
            routeIds[#routeIds + 1] = id
        end
    end

    return {
        active = IsBonusActive(),
        multiplier = bonusMultiplier,
        ["until"] = bonusUntil,
        nextAt = bonusNextAt,
        scope = bonusScope,
        routeIds = routeIds,
    }
end

local buildRoutesPayload -- defined further down

local function broadcastBonus()
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local identifier = Bridge.GetIdentifier(src)
        if identifier then
            TriggerClientEvent("oxlyn-truckjob:client:bonus", src, buildBonusPayload(identifier))
        end
    end
end

local function broadcastRoutes()
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local identifier = Bridge.GetIdentifier(src)
        if identifier then
            TriggerClientEvent("oxlyn-truckjob:client:setRoutes", src, buildRoutesPayload(identifier))
        end
    end
end

local function startBonus(manual)
    local cfg = Config.Bonus or {}
    local duration = cfg.duration or 600

    bonusUntil = os.time() + duration
    bonusNextAt = bonusUntil + math.max(60, (cfg.interval or 1800) - duration)
    bonusMultiplier = pickBonusMultiplier()
    bonusScope = cfg.scope or "all"
    bonusRoutesByPlayer = {}

    if bonusScope == "random" then
        local count = cfg.randomCount or 2
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local identifier = Bridge.GetIdentifier(src)
            if identifier then
                local set = {}
                for _, routeId in ipairs(pickRandomUnlocked(identifier, count)) do
                    set[routeId] = true
                end
                bonusRoutesByPlayer[identifier] = set
            end
        end
    end

    broadcastBonus()
    broadcastRoutes()

    if cfg.announce ~= false then
        local percent = math.floor((bonusMultiplier - 1.0) * 100)
        local minutes = math.floor(duration / 60)
        local message
        if bonusScope == "all" then
            message = _U("bonus_started_all", percent, minutes)
        else
            message = _U("bonus_started_routes", percent, cfg.randomCount or 2, minutes)
        end
        TriggerClientEvent("oxlyn-truckjob:client:notify", -1, message, "success", 7000)
    end
end

local function endBonus()
    bonusUntil = 0
    bonusRoutesByPlayer = {}
    broadcastBonus()
    broadcastRoutes()

    if (Config.Bonus or {}).announce ~= false then
        TriggerClientEvent("oxlyn-truckjob:client:notify", -1, _U("bonus_ended"), "info", 5000)
    end
end

-- Called after a player's rotation pool is refreshed (re-rolls their random boosted routes)
function OnPlayerPoolRefreshed(identifier)
    if not IsBonusActive() then return end
    if bonusScope ~= "random" then return end

    local count = (Config.Bonus or {}).randomCount or 2
    local set = {}
    for _, routeId in ipairs(pickRandomUnlocked(identifier, count)) do
        set[routeId] = true
    end
    bonusRoutesByPlayer[identifier] = set

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if Bridge.GetIdentifier(src) == identifier then
            TriggerClientEvent("oxlyn-truckjob:client:bonus", src, buildBonusPayload(identifier))
        end
    end
end

-- Bonus scheduler
CreateThread(function()
    local startDelay = (Config.Bonus and Config.Bonus.startDelay) or 600

    if (Config.Bonus or {}).enabled then
        bonusNextAt = os.time() + startDelay
        broadcastBonus()
    end

    Wait(startDelay * 1000)

    while true do
        local cfg = Config.Bonus or {}
        if not cfg.enabled then
            Wait(60000)
        else
            startBonus(false)
            Wait((cfg.duration or 600) * 1000)
            endBonus()

            local gap = (cfg.interval or 1800) - (cfg.duration or 600)
            if gap < 60 then gap = 60 end
            Wait(gap * 1000)
        end
    end
end)

RegisterNetEvent("oxlyn-truckjob:server:admin:bonus", function()
    local src = source
    if not Bridge.IsAdmin(src) then return end
    if IsBonusActive() then return end
    startBonus(true)
end)

AddEventHandler("playerJoining", function()
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    if identifier then
        TriggerClientEvent("oxlyn-truckjob:client:bonus", src, buildBonusPayload(identifier))
    end
end)

---------------------------------------------------------------------
-- Route rotation (each player sees a rotating pool of unlocked / locked routes)
---------------------------------------------------------------------

-- Splits all route ids into (unlocked at this level, locked at this level)
local function splitRoutesByLevel(level)
    local unlocked, locked = {}, {}
    for _, route in ipairs(Config.Routes) do
        if level >= routeMinLevel(route.id) then
            unlocked[#unlocked + 1] = route.id
        else
            locked[#locked + 1] = route.id
        end
    end
    return unlocked, locked
end

-- Picks up to `count` ids. Ids in `exclude` are skipped; ids in `avoid` are used only as a last resort.
local function pickRoutes(candidates, count, exclude, avoid)
    exclude = exclude or {}
    avoid = avoid or {}

    local fresh, stale = {}, {}
    for _, id in ipairs(candidates) do
        if not exclude[id] then
            if avoid[id] then
                stale[#stale + 1] = id
            else
                fresh[#fresh + 1] = id
            end
        end
    end

    shuffle(fresh)
    shuffle(stale)

    local picked = {}
    for _, id in ipairs(fresh) do
        if count > #picked then picked[#picked + 1] = id end
    end
    for _, id in ipairs(stale) do
        if count > #picked then picked[#picked + 1] = id end
    end
    return picked
end

-- Pool size from a { {lvl=, size=}, ... } table, falling back to a default
local function sizeByLevel(tbl, level, default)
    if type(tbl) ~= "table" or #tbl == 0 then
        return default
    end

    local size = tbl[1].size or default
    for _, entry in ipairs(tbl) do
        if level >= (entry.lvl or 0) then
            size = entry.size or size
        end
    end
    return size
end

local function unlockedPoolSize(level)
    local cfg = rotationCfg()
    return sizeByLevel(cfg.unlockedSizeByLevel, level, cfg.unlockedSize or 3)
end

local function lockedPoolSize(level)
    local cfg = rotationCfg()
    return sizeByLevel(cfg.lockedSizeByLevel, level, cfg.lockedSize or 3)
end

local function refreshPool(identifier)
    local cfg = rotationCfg()
    local previous = rotationPools[identifier]

    -- Avoid repeating the previous pool when possible
    local avoid = {}
    if cfg.avoidPreviousPool ~= false and previous then
        for _, id in ipairs(previous.unlocked or {}) do avoid[id] = true end
        for _, id in ipairs(previous.locked or {}) do avoid[id] = true end
    end

    local level = (progressCache[identifier] and progressCache[identifier].level) or 1
    local unlockedIds, lockedIds = splitRoutesByLevel(level)

    local unlockedCount = math.min(unlockedPoolSize(level), #unlockedIds)
    local lockedCount = math.min(lockedPoolSize(level), #lockedIds)

    rotationPools[identifier] = {
        unlocked = pickRoutes(unlockedIds, unlockedCount, nil, avoid),
        locked = pickRoutes(lockedIds, lockedCount, nil, avoid),
        prevAll = avoid,
        expiresAt = os.time() + (cfg.refreshEvery or 600),
    }

    if OnPlayerPoolRefreshed then
        OnPlayerPoolRefreshed(identifier)
    end

    return rotationPools[identifier]
end

local function getPool(identifier)
    local cfg = rotationCfg()

    -- Rotation disabled: show everything, split by level
    if not cfg.enabled then
        local level = (progressCache[identifier] and progressCache[identifier].level) or 1
        local unlocked, locked = splitRoutesByLevel(level)
        rotationPools[identifier] = {
            unlocked = unlocked,
            locked = locked,
            prevAll = {},
            expiresAt = 0,
        }
        return rotationPools[identifier]
    end

    local existing = rotationPools[identifier]
    if existing and os.time() < (existing.expiresAt or 0) then
        return existing
    end
    return refreshPool(identifier)
end

-- After a level-up, move routes between the unlocked / locked lists
local function reclassifyPool(identifier)
    local pool = rotationPools[identifier]
    if not pool then return end

    local level = (progressCache[identifier] and progressCache[identifier].level) or 1
    local unlocked, locked = {}, {}

    for _, list in ipairs({ pool.unlocked or {}, pool.locked or {} }) do
        for _, id in ipairs(list) do
            if level >= routeMinLevel(id) then
                unlocked[#unlocked + 1] = id
            else
                locked[#locked + 1] = id
            end
        end
    end

    pool.unlocked = unlocked
    pool.locked = locked
end

-- After completing a route, swap it out of the pool for a new one
local function refreshOnComplete(identifier, completedRouteId)
    local cfg = rotationCfg()
    if not (cfg.enabled and cfg.refreshOnComplete) then return end

    local pool = rotationPools[identifier]
    if not pool then return end

    local level = (progressCache[identifier] and progressCache[identifier].level) or 1
    local unlockedIds, lockedIds = splitRoutesByLevel(level)
    local wasUnlocked = level >= routeMinLevel(completedRouteId)

    local function replaceCompleted(list, candidates)
        local newList = {}
        local taken = { [completedRouteId] = true }

        for _, id in ipairs(list) do
            if id ~= completedRouteId then
                newList[#newList + 1] = id
                taken[id] = true
            end
        end

        local replacement = pickRoutes(candidates, 1, taken)
        if replacement[1] then
            newList[#newList + 1] = replacement[1]
        end
        return newList
    end

    if wasUnlocked then
        pool.unlocked = replaceCompleted(pool.unlocked, unlockedIds)
    else
        pool.locked = replaceCompleted(pool.locked, lockedIds)
    end
end

-- Builds the route list shown in the menu
buildRoutesPayload = function(identifier)
    local pool = getPool(identifier)
    local stats = statsCache[identifier] or newStats()
    local completedMap = stats.completed or {}
    local entries = {}

    local function routeValue(id)
        for _, route in ipairs(Config.Routes) do
            if route.id == id then return route.value or 0 end
        end
        return 0
    end

    -- Sort by required level, then by value
    local function sortedIds(ids)
        local copy = {}
        for _, id in ipairs(ids or {}) do copy[#copy + 1] = id end

        table.sort(copy, function(a, b)
            local la, lb = routeMinLevel(a), routeMinLevel(b)
            if la ~= lb then return la < lb end
            return routeValue(a) < routeValue(b)
        end)
        return copy
    end

    local function appendRoutes(ids)
        for _, id in ipairs(ids) do
            for _, route in ipairs(Config.Routes) do
                if route.id == id then
                    entries[#entries + 1] = {
                        id = route.id,
                        label = route.label,
                        cargo = route.cargo,
                        difficulty = route.difficulty,
                        value = route.value,
                        payment = (Config.BasePay or 0) + (route.value or 0),
                        currency = Config.Currency,
                        image = route.image,
                        minLevel = routeMinLevel(route.id),
                        completed = completedMap[route.id] or 0,
                    }
                    break
                end
            end
        end
    end

    appendRoutes(sortedIds(pool.unlocked))
    appendRoutes(sortedIds(pool.locked))

    if IsBonusActive() then
        for _, entry in ipairs(entries) do
            entry.boosted = IsRouteBoostedFor(identifier, entry.id) or false
        end
    end

    return {
        routes = entries,
        expiresAt = pool.expiresAt,
        rotation = rotationCfg().enabled and true or false,
        bonus = IsBonusActive() and { multiplier = GetBonusMultiplier(), scope = bonusScope } or nil,
    }
end

---------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------
local function storageLoad(identifier, cb)
    if Storage and type(Storage.Load) == "function" then
        Storage.Load(identifier, cb)
    elseif cb then
        cb({})
    end
end

local function storageSave(identifier, data)
    if Storage and type(Storage.Save) == "function" then
        Storage.Save(identifier, data)
    end
end

local function storageBackend()
    if Storage and type(Storage.Backend) == "function" then
        return Storage.Backend()
    end
    return "memory"
end

-- Loads a player's data into the caches (once), then calls cb(identifier)
local function ensureLoaded(src, cb)
    local identifier = getIdentifier(src)
    if not identifier then
        if cb then cb(nil) end
        return
    end

    if loadedPlayers[identifier] then
        local name = Bridge.GetName and Bridge.GetName(src)
        if name and name ~= "" then
            playerNames[identifier] = name
        end
        if cb then cb(identifier) end
        return
    end

    storageLoad(identifier, function(data)
        data = data or {}

        statsCache[identifier] = data.stats or newStats()
        progressCache[identifier] = data.progress or newProgress()
        historyCache[identifier] = data.history or {}
        playerNames[identifier] = data.name or (Bridge.GetName and Bridge.GetName(src)) or nil
        loadedPlayers[identifier] = true

        if cb then cb(identifier) end
    end)
end

local function persist(identifier, src)
    if not identifier then return end
    if statsCache[identifier] == nil or progressCache[identifier] == nil then return end

    if src then
        local name = Bridge.GetName and Bridge.GetName(src)
        if name and name ~= "" then
            playerNames[identifier] = name
        end
    end

    storageSave(identifier, {
        name = playerNames[identifier],
        stats = statsCache[identifier],
        progress = progressCache[identifier],
        history = historyCache[identifier],
    })
end

---------------------------------------------------------------------
-- XP / levels
---------------------------------------------------------------------
local function xpForLevel(level)
    local base = (Config.XP and Config.XP.baseXp) or 200
    local growth = (Config.XP and Config.XP.growth) or 1.35
    return math.floor(base * (growth ^ math.max(0, level - 1)))
end

-- Applies pending XP as level-ups (mutates progress) and returns a summary for the client
local function applyLevelUps(progress)
    local maxLevel = (Config.XP and Config.XP.maxLevel) or 50
    local level, xp = progress.level, progress.xp
    local needed = xpForLevel(level)
    local leveled = false

    while maxLevel > level and xp >= needed do
        xp = xp - needed
        level = level + 1
        needed = xpForLevel(level)
        leveled = true
    end

    if maxLevel <= level then
        xp = 0
    end

    progress.level = level
    progress.xp = xp

    return {
        level = level,
        xp = xp,
        xpNext = (maxLevel <= level) and 0 or needed,
        maxed = maxLevel <= level,
        leveled = leveled,
    }
end

local function payMultiplierForLevel(level)
    local cfg = Config.XP
    if not (cfg and cfg.enabled) then
        return 1.0
    end
    local bonus = math.min(cfg.maxPayBonus or 0.0, (level - 1) * (cfg.payPerLevel or 0.0))
    return 1.0 + bonus
end

---------------------------------------------------------------------
-- Info panel
---------------------------------------------------------------------
local function buildInfo()
    local items = {}

    if Config.RequireJob then
        items[#items + 1] = {
            icon = "fa-sharp fa-solid fa-briefcase",
            label = _U("info_job_required"),
            desc = _U("info_job_required_d"),
            value = Config.JobName or "—",
        }
    else
        items[#items + 1] = {
            icon = "fa-sharp fa-solid fa-unlock",
            label = _U("info_no_job_required"),
            desc = _U("info_no_job_d"),
            value = "✓",
            muted = true,
        }
    end

    if Config.AntiAbuse and Config.AntiAbuse.enabled then
        items[#items + 1] = {
            icon = "fa-sharp fa-solid fa-stopwatch",
            label = _U("info_max_duration"),
            desc = _U("info_max_duration_d"),
            value = _U("info_min_value_min", math.floor(Config.AntiAbuse.maxJobDuration / 60)),
        }
        items[#items + 1] = {
            icon = "fa-sharp fa-solid fa-truck",
            label = _U("info_idle"),
            desc = _U("info_idle_d"),
            value = _U("info_min_value", Config.AntiAbuse.idleTimeout),
        }
        items[#items + 1] = {
            icon = "fa-sharp fa-solid fa-arrows-up-down-left-right",
            label = _U("info_away"),
            desc = _U("info_away_d"),
            value = ("%dm"):format(Config.AntiAbuse.driverAwayDistance),
        }
    end

    if (Config.Cooldown or 0) > 0 then
        items[#items + 1] = {
            icon = "fa-sharp fa-solid fa-hourglass-half",
            label = _U("info_cooldown"),
            desc = _U("info_cooldown_d"),
            value = _U("info_min_value", Config.Cooldown),
        }
    end

    items[#items + 1] = {
        icon = "fa-sharp fa-solid fa-database",
        label = _U("info_storage"),
        desc = _U("info_storage_d"),
        value = storageBackend(),
        muted = true,
    }

    return items
end

---------------------------------------------------------------------
-- Start requirements
---------------------------------------------------------------------
local function canStartJob(src)
    if Config.RequireJob and not Bridge.HasJob(Config.JobName, src) then
        Notify.Send(src, _U("err_no_job"), "error")
        return false
    end

    if Config.UseLicense then
        local hasLicense = false

        if Overrides and type(Overrides.HasDriverLicense) == "function" then
            local ok, result = pcall(Overrides.HasDriverLicense, src)
            if ok then
                hasLicense = result and true or false
            end
        elseif Bridge.HasLicense then
            local ok, result = pcall(Bridge.HasLicense, src, "driver")
            if ok and result then
                hasLicense = true
            end
        end

        if not hasLicense then
            hasLicense = Inventory.HasItem(src, Config.LicenseItem)
        end

        if not hasLicense then
            Notify.Send(src, _U("err_no_license"), "error")
            return false
        end
    end

    if Config.MinPlayers > 0 and #GetPlayers() < Config.MinPlayers then
        Notify.Send(src, _U("err_min_players", Config.MinPlayers), "warning")
        return false
    end

    return true
end

local function meetsLevelRequirement(src, routeId)
    local minLevels = (Config.XP and Config.XP.routeMinLevel) or {}
    local required = minLevels[routeId]
    if not required then return true end

    local identifier = getIdentifier(src)
    if not identifier then return false end

    local level = (progressCache[identifier] and progressCache[identifier].level) or 1
    if required > level then
        Notify.Send(src, _U("level_locked", required), "warning")
        return false
    end
    return true
end

---------------------------------------------------------------------
-- Vehicle tracking / cleanup
---------------------------------------------------------------------
local function resolveNetEntity(netId)
    if not netId or netId == 0 then return 0 end

    local ok, entity = pcall(NetworkGetEntityFromNetworkId, netId)
    if ok and entity and entity ~= 0 and DoesEntityExist(entity) then
        return entity
    end
    return 0
end

-- Deletes a tracked vehicle, but only if it's still the same vehicle the player registered
local function deleteTrackedEntity(src, info)
    if not info then return end
    if netIdOwner[info.net] ~= src then return end

    netIdOwner[info.net] = nil

    local entity = resolveNetEntity(info.net)
    if entity == 0 then return end
    if GetEntityType(entity) ~= 2 then return end -- 2 = vehicle
    if info.model and GetEntityModel(entity) ~= info.model then return end

    DeleteEntity(entity)
end

local function cleanupEntities(src, job, delay)
    local entities = job and job.entities
    if not entities then return end

    job.entities = {}

    local list = {}
    for _, info in pairs(entities) do
        list[#list + 1] = info
    end
    if #list == 0 then return end

    local function run()
        for _, info in ipairs(list) do
            deleteTrackedEntity(src, info)
        end
    end

    if (delay or 0) <= 0 then
        run()
    else
        SetTimeout(delay, run)
    end
end

RegisterNetEvent("oxlyn-truckjob:server:trackVehicle", function(netId, kind)
    local src = source
    local job = activeJobs[src]
    if not job then return end
    if kind ~= "truck" and kind ~= "trailer" then return end

    netId = tonumber(netId)
    if not netId or netId == 0 then return end

    job.entities = job.entities or {}

    -- Replacing a previously tracked vehicle of the same kind
    local existing = job.entities[kind]
    if existing and existing.net ~= netId then
        deleteTrackedEntity(src, existing)
    end

    local entity = resolveNetEntity(netId)
    job.entities[kind] = {
        net = netId,
        model = (entity ~= 0) and GetEntityModel(entity) or nil,
    }
    netIdOwner[netId] = src
end)

---------------------------------------------------------------------
-- Repair items (tire / engine)
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:server:useRepairItem", function(kind, requestId)
    local src = source

    local cfg
    if kind == "tire" then
        cfg = Config.TireBurst
    elseif kind == "engine" then
        cfg = Config.EngineOverheat
    end

    local ok = false
    if activeJobs[src] and cfg then
        if not (cfg.requireItem and cfg.item) then
            ok = true
        elseif Inventory.HasItem(src, cfg.item, 1) then
            ok = Inventory.RemoveItem(src, cfg.item, 1)
        end
    end

    TriggerClientEvent("oxlyn-truckjob:client:repairItemResult", src, requestId, ok)
end)

---------------------------------------------------------------------
-- Cancelling jobs
---------------------------------------------------------------------
local function cancelJobByServer(src, reason, ...)
    local job = activeJobs[src]
    if not job then return end

    activeJobs[src] = nil
    cleanupEntities(src, job, 5000)

    if reason then
        TriggerClientEvent("oxlyn-truckjob:client:cancelByServer", src, reason, { ... })
    else
        TriggerClientEvent("oxlyn-truckjob:client:cancelByServer", src, nil, {})
    end
end

-- Cancel jobs that run longer than the allowed duration
CreateThread(function()
    while true do
        Wait(5000)

        if Config.AntiAbuse and Config.AntiAbuse.enabled then
            local maxDuration = Config.AntiAbuse.maxJobDuration or 1800
            local now = os.time()

            for src, job in pairs(activeJobs) do
                if maxDuration < now - job.startedAt then
                    cancelJobByServer(src, "err_max_duration", math.floor(maxDuration / 60))
                end
            end
        end
    end
end)

RegisterNetEvent("oxlyn-truckjob:server:cancel", function(reason)
    local src = source
    local job = activeJobs[src]
    if not job then return end

    activeJobs[src] = nil
    cleanupEntities(src, job, 5000)
end)

---------------------------------------------------------------------
-- Starting a job
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:server:requestStart", function(routeId)
    local src = source

    if activeJobs[src] then
        Notify.Send(src, _U("job_in_progress"), "warning")
        return
    end

    if not canStartJob(src) then return end
    if not meetsLevelRequirement(src, routeId) then return end

    local route = routeById(routeId)
    if not route then
        Notify.Send(src, _U("err_no_truck"), "error")
        return
    end

    local identifier = getIdentifier(src)
    if not identifier then return end

    activeJobs[src] = {
        routeId = routeId,
        startedAt = os.time(),
        identifier = identifier,
    }

    local deliveries = {}
    for _, d in ipairs(route.deliveries or {}) do
        deliveries[#deliveries + 1] = { x = d.x, y = d.y, z = d.z }
    end

    TriggerClientEvent("oxlyn-truckjob:client:onStartConfirmed", src, {
        id = route.id,
        label = route.label,
        cargo = route.cargo,
        difficulty = route.difficulty,
        value = route.value,
        image = route.image,
        trailer = route.trailer,
        pickup = { x = route.pickup.x, y = route.pickup.y, z = route.pickup.z },
        deliveries = deliveries,
        pickupHeading = route.pickupHeading or 0.0,
        pickupLocked = route.pickupLocked or false,
    })
end)

---------------------------------------------------------------------
-- Payment calculation
---------------------------------------------------------------------
-- Returns a full breakdown table (total, bonuses, penalties...) for a finished delivery
local function calculatePayment(src, route, data)
    if not (src and route and data) then return nil end

    local identifier = getIdentifier(src)
    if not identifier then return nil end

    if not progressCache[identifier] then
        progressCache[identifier] = newProgress()
    end

    local km = math.max(0, (data.distanceM or 0) / 1000.0)
    local perKm = route.bonusPerKm or Config.BonusPerKm or 0
    local perfectBonusAmount = route.perfectBonus or Config.PerfectBonus or 0

    local base = (Config.BasePay or 0) + (route.value or 0)
    local kmBonus = math.floor(km * perKm)
    local total = base + kmBonus

    -- Time bonus
    local timeBonus = 0
    if Config.TimeBonus and Config.TimeBonus.enabled then
        local target = route.timeBonusTarget or Config.TimeBonus.target or 600
        local elapsed = data.elapsed or 0
        if elapsed > 0 and target >= elapsed then
            local ratio = 1.0 - (elapsed / target)
            timeBonus = math.floor((Config.TimeBonus.maxBonus or 0) * math.max(0, ratio))
        end
    end
    total = total + timeBonus

    -- Speed multiplier
    local speedMul = 1.0
    local speedBonus = 0
    local speedCfg = Config.SpeedMultiplier
    if speedCfg and speedCfg.enabled and km > 0 then
        local expectedKmH = math.max(1, speedCfg.expectedKmH or 50)
        local expectedSeconds = (km / expectedKmH) * 3600
        local actualSeconds = math.max(speedCfg.minElapsed or 60, data.elapsed or expectedSeconds)
        local ratio = expectedSeconds / actualSeconds

        for _, threshold in ipairs(speedCfg.thresholds or {}) do
            if ratio >= (threshold.ratio or 0) then
                speedMul = threshold.mul or 1.0
                break
            end
        end

        local before = total
        total = math.floor(total * speedMul)
        speedBonus = total - before
    end

    -- Perfect delivery (truck health)
    local perfect = (data.healthPct or 0) >= 0.97
    local perfectBonus = 0
    if perfect then
        perfectBonus = perfectBonusAmount
        total = total + perfectBonus
    end

    -- Level gap vs. route requirement (used for the repeat bonus)
    local playerLevel = (progressCache[identifier] and progressCache[identifier].level) or 1
    local routeLevel = (Config.XP and Config.XP.routeMinLevel and Config.XP.routeMinLevel[route.id]) or 1
    local levelGap = math.max(0, playerLevel - routeLevel)

    -- Repeat bonus
    local repeatBonus = 0
    local repeatCount = 0
    local repeatCfg = Config.RepeatBonus
    if repeatCfg and repeatCfg.enabled then
        local stats = statsCache[identifier] or newStats()
        repeatCount = (stats.completed and stats.completed[route.id]) or 0

        if repeatCount >= (repeatCfg.minRepeats or 1) and levelGap > 0 then
            local pct = math.min(repeatCfg.maxBonusPct or 0.3, levelGap * (repeatCfg.perGapPct or 0.03))
            repeatBonus = math.floor(total * pct)
            total = total + repeatBonus
        end
    end

    -- Damage penalty
    local damagePenalty = 0
    local damageCfg = Config.DamagePenalty
    if damageCfg and damageCfg.enabled then
        local cut = math.min(damageCfg.maxCut or 0.5, (data.damageHits or 0) * (damageCfg.perHit or 0))
        if cut > 0 then
            local before = total
            total = math.floor(total * (1.0 - cut))
            damagePenalty = before - total
        end
    end

    -- Per-route multiplier
    if route.payMultiplier and route.payMultiplier ~= 1 then
        total = math.floor(total * route.payMultiplier)
    end

    -- Player level multiplier
    local levelMul = payMultiplierForLevel(progressCache[identifier].level or 1)
    local levelBonus = 0
    if levelMul ~= 1.0 then
        local before = total
        total = math.floor(total * levelMul)
        levelBonus = total - before
    end

    -- Event bonus
    local eventBonus = 0
    local bonusActive = false
    if IsBonusActive() and IsRouteBoostedFor(identifier, route.id) then
        bonusActive = true
        local before = total
        total = math.floor(total * GetBonusMultiplier())
        eventBonus = total - before
    end

    -- Tax
    local tax = 0
    if Config.Tax and Config.Tax > 0 then
        local before = total
        total = math.floor(total * (1.0 - Config.Tax))
        tax = before - total
    end

    total = math.max(0, total)

    return {
        base = base,
        kmBonus = kmBonus,
        timeBonus = timeBonus,
        speedBonus = speedBonus,
        speedMul = speedMul,
        perfectBonus = perfectBonus,
        perfect = perfect,
        repeatBonus = repeatBonus,
        repeatCount = repeatCount,
        levelGap = levelGap,
        damagePenalty = damagePenalty,
        damageHits = data.damageHits or 0,
        levelBonus = levelBonus,
        eventBonus = eventBonus,
        bonusActive = bonusActive,
        tax = tax,
        total = total,
        distKm = km,
        elapsed = data.elapsed or 0,
    }
end

-- Shows the delivery paper (payment breakdown) before the player signs
RegisterNetEvent("oxlyn-truckjob:server:previewDelivery", function(data)
    local src = source
    local job = activeJobs[src]
    if not (job and data and job.routeId == data.id) then return end

    local route = routeById(job.routeId)
    if not route then return end

    local breakdown = calculatePayment(src, route, data)
    if not breakdown then return end

    TriggerClientEvent("oxlyn-truckjob:client:deliveryPaperData", src, {
        routeId = route.id,
        label = route.label,
        cargo = route.cargo,
        currency = Config.Currency or "$",
        breakdown = breakdown,
    })
end)

---------------------------------------------------------------------
-- Completing a job
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:server:complete", function(data)
    local src = source
    local job = activeJobs[src]
    if not (job and type(data) == "table" and job.routeId == data.id) then return end

    activeJobs[src] = nil

    local route = routeById(job.routeId)
    if not route then return end

    -- Clean up vehicles shortly after the despawn delay
    local despawnDelay = ((Config.Loading and Config.Loading.despawnDelay) or 3000) + 6000
    local trailerInfo = job.entities and job.entities.trailer
    cleanupEntities(src, job, despawnDelay)

    if not job.cargoLoaded then
        Notify.Send(src, _U("err_trailer_not_hitched"), "error", 6500)
        return
    end

    -- Verify the trailer is actually near a delivery point
    local trailerEntity = trailerInfo and resolveNetEntity(trailerInfo.net) or 0
    if trailerEntity ~= 0 then
        local radius = ((Config.Loading and Config.Loading.deliveryTrailerRadius) or 45.0) + 35.0
        local coords = GetEntityCoords(trailerEntity)

        local near = false
        for _, d in ipairs(route.deliveries or {}) do
            if radius >= #(coords - vector3(d.x, d.y, d.z)) then
                near = true
                break
            end
        end

        if not near then
            Debug.warn(("complete rejected: src %s trailer not at the destination"):format(src))
            Notify.Send(src, _U("err_trailer_not_at_delivery"), "error", 6500)
            return
        end
    end

    ensureLoaded(src, function(identifier)
        if not identifier then return end

        local km = math.max(0, (data.distanceM or 0) / 1000.0)

        local breakdown = calculatePayment(src, route, data) or {}
        local pay = breakdown.total or 0
        local perfect = breakdown.perfect or false
        local bonusApplied = breakdown.bonusActive or false

        -- XP reward
        local xp = 0
        if Config.XP and Config.XP.enabled then
            if route.xpReward then
                xp = route.xpReward
            else
                local perDelivery = route.xpPerDelivery or Config.XP.perDelivery or 0
                local perKm = route.xpPerKm or Config.XP.perKm or 0
                local perfectBonus = route.xpPerfectBonus or Config.XP.perfectBonus or 0
                local difficultyMul = (Config.XP.difficultyXp and Config.XP.difficultyXp[route.difficulty]) or 1.0

                xp = perDelivery + math.floor(km * perKm)
                if perfect then xp = xp + perfectBonus end
                xp = math.floor(xp * difficultyMul)
            end
        end

        -- Optional external override of the reward
        if Overrides and type(Overrides.ComputeReward) == "function" then
            local ok, result = pcall(Overrides.ComputeReward, route, data, {
                pay = pay,
                xp = xp,
                perfect = perfect,
                distanceM = data.distanceM,
            })
            if ok and type(result) == "table" then
                if result.pay ~= nil then pay = math.max(0, math.floor(result.pay)) end
                if result.xp ~= nil then xp = math.max(0, math.floor(result.xp)) end
            end
        end

        Bridge.AddMoney(src, Config.PaymentAccount or "bank", pay)

        -- Progression
        local levelResult = nil
        if Config.XP and Config.XP.enabled then
            progressCache[identifier].xp = (progressCache[identifier].xp or 0) + xp
            levelResult = applyLevelUps(progressCache[identifier])
        end

        -- Stats
        local stats = statsCache[identifier]
        stats.totalPaid = stats.totalPaid + pay
        stats.deliveries = stats.deliveries + 1
        stats.distanceM = stats.distanceM + (data.distanceM or 0)
        if pay > stats.bestPay then
            stats.bestPay = pay
        end
        stats.completed = stats.completed or {}
        stats.completed[route.id] = (stats.completed[route.id] or 0) + 1

        -- History (keep the latest 15)
        table.insert(historyCache[identifier], 1, {
            label = route.label,
            payment = pay,
            ts = os.time(),
            perfect = perfect,
            xp = xp,
        })
        while #historyCache[identifier] > 15 do
            table.remove(historyCache[identifier])
        end

        if levelResult and levelResult.leveled then
            reclassifyPool(identifier)
        end

        refreshOnComplete(identifier, route.id)
        persist(identifier, src)

        -- Notify the player
        local currency = Config.Currency or "$"
        if bonusApplied then
            local percent = math.floor((((Config.Bonus and Config.Bonus.multiplier) or 1.0) - 1.0) * 100)
            Notify.Send(src, _U("job_finished_bonus", currency, pay, percent), "success", 6500)
        else
            Notify.Send(src, _U("job_finished", currency, pay), "success")
        end

        TriggerClientEvent("oxlyn-truckjob:client:setStats", src, statsCache[identifier])
        TriggerClientEvent("oxlyn-truckjob:client:setHistory", src, historyCache[identifier])
        TriggerClientEvent("oxlyn-truckjob:client:setRoutes", src, buildRoutesPayload(identifier))

        if levelResult then
            TriggerClientEvent("oxlyn-truckjob:client:setProgression", src, levelResult)
            if levelResult.leveled then
                TriggerClientEvent("oxlyn-truckjob:client:levelUp", src, levelResult.level)
            end
        end

        if Overrides and type(Overrides.OnDeliveryComplete) == "function" then
            pcall(Overrides.OnDeliveryComplete, src, identifier, route, {
                pay = pay,
                xp = xp,
                perfect = perfect,
                distanceM = data.distanceM or 0,
                elapsed = data.elapsed or 0,
                bonusApplied = bonusApplied,
            })
        end
    end)
end)

RegisterNetEvent("oxlyn-truckjob:server:cargoLoaded", function()
    local src = source
    local job = activeJobs[src]
    if job then
        job.cargoLoaded = true
    end
end)

---------------------------------------------------------------------
-- Menu data requests
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:server:getStats", function()
    local src = source
    ensureLoaded(src, function(identifier)
        if not identifier then return end

        local progression = applyLevelUps(progressCache[identifier])

        TriggerClientEvent("oxlyn-truckjob:client:setStats", src, statsCache[identifier])
        TriggerClientEvent("oxlyn-truckjob:client:setHistory", src, historyCache[identifier])
        TriggerClientEvent("oxlyn-truckjob:client:setProgression", src, progression)
        TriggerClientEvent("oxlyn-truckjob:client:setInfo", src, buildInfo())
        TriggerClientEvent("oxlyn-truckjob:client:setRoutes", src, buildRoutesPayload(identifier))
        TriggerClientEvent("oxlyn-truckjob:client:bonus", src, buildBonusPayload(identifier))
    end)
end)

RegisterNetEvent("oxlyn-truckjob:server:requestRoutes", function()
    local src = source
    ensureLoaded(src, function(identifier)
        if not identifier then return end
        TriggerClientEvent("oxlyn-truckjob:client:setRoutes", src, buildRoutesPayload(identifier))
    end)
end)

---------------------------------------------------------------------
-- Ranking
---------------------------------------------------------------------
local function rankingCfg()
    return Config.Ranking or {}
end

local function buildRanking(viewerId, cb)
    local cfg = rankingCfg()
    if not cfg.enabled then
        cb({ enabled = false })
        return
    end

    local function loadAll(done)
        if Storage and type(Storage.LoadAll) == "function" then
            return Storage.LoadAll(done)
        end
        done({})
    end

    loadAll(function(allRecords)
        local rows = {}

        local function addRow(identifier, name, progress, stats)
            if type(progress) ~= "table" then progress = {} end
            if type(stats) ~= "table" then stats = {} end

            local row = {
                identifier = identifier,
                name = name or playerNames[identifier] or "Player",
                level = tonumber(progress.level) or 1,
                xp = tonumber(progress.xp) or 0,
                deliveries = tonumber(stats.deliveries) or 0,
                totalPaid = tonumber(stats.totalPaid) or 0,
            }

            -- Skip players who never did anything
            if row.deliveries > 0 or row.level > 1 or row.xp > 0 then
                rows[#rows + 1] = row
            end
        end

        -- Online players first (live cache), then stored records for everyone else
        local seen = {}
        for identifier in pairs(loadedPlayers) do
            seen[identifier] = true
            addRow(identifier, playerNames[identifier], progressCache[identifier], statsCache[identifier])
        end

        for identifier, record in pairs(allRecords or {}) do
            if not seen[identifier] and type(record) == "table" then
                addRow(identifier, record.name, record.progress, record.stats)
            end
        end

        local sortBy = cfg.sortBy or "level"
        table.sort(rows, function(a, b)
            if sortBy == "level" then
                if a.level == b.level then return a.xp > b.xp end
                return a.level > b.level
            elseif sortBy == "xp" then
                if a.xp == b.xp then return a.level > b.level end
                return a.xp > b.xp
            elseif sortBy == "totalPaid" then
                return (a.totalPaid or 0) > (b.totalPaid or 0)
            elseif sortBy == "deliveries" then
                return (a.deliveries or 0) > (b.deliveries or 0)
            end
            return false
        end)

        local topN = cfg.topN or 10
        local viewerRow = nil
        for index, row in ipairs(rows) do
            row.position = index
            if row.identifier == viewerId then
                viewerRow = row
            end
        end

        local top = {}
        for i = 1, math.min(topN, #rows) do
            top[i] = rows[i]
        end

        cb({
            enabled = true,
            rows = top,
            self = viewerRow,
            sortBy = sortBy,
            columns = cfg.columns or {},
            topN = topN,
            viewer = viewerId,
        })
    end)
end

RegisterNetEvent("oxlyn-truckjob:server:requestRanking", function()
    local src = source
    local identifier = getIdentifier(src)
    buildRanking(identifier, function(payload)
        TriggerClientEvent("oxlyn-truckjob:client:setRanking", src, payload)
    end)
end)

---------------------------------------------------------------------
-- Disconnect / resource stop
---------------------------------------------------------------------
AddEventHandler("playerDropped", function()
    local src = source

    local job = activeJobs[src]
    if job then
        activeJobs[src] = nil
        cleanupEntities(src, job, 0)
    end

    local identifier = getIdentifier(src)
    if identifier and loadedPlayers[identifier] then
        persist(identifier, src)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for identifier in pairs(loadedPlayers) do
        persist(identifier)
    end

    for src, job in pairs(activeJobs) do
        cleanupEntities(src, job, 0)
    end

    activeJobs = {}
end)

---------------------------------------------------------------------
-- Admin: reset everything
---------------------------------------------------------------------
local function resetAllPlayerData()
    statsCache = {}
    progressCache = {}
    historyCache = {}
    rotationPools = {}
    loadedPlayers = {}

    if Storage and Storage.ClearAll then
        Storage.ClearAll()
    end

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local identifier = Bridge.GetIdentifier(src)
        if identifier then
            statsCache[identifier] = newStats()
            progressCache[identifier] = newProgress()
            historyCache[identifier] = {}
            loadedPlayers[identifier] = true

            TriggerClientEvent("oxlyn-truckjob:client:setStats", src, statsCache[identifier])
            TriggerClientEvent("oxlyn-truckjob:client:setHistory", src, historyCache[identifier])
            TriggerClientEvent("oxlyn-truckjob:client:setProgression", src, {
                level = 1,
                xp = 0,
                xpNext = (Config.XP and Config.XP.baseXp) or 200,
                leveled = false,
                maxed = false,
            })
            TriggerClientEvent("oxlyn-truckjob:client:setRoutes", src, buildRoutesPayload(identifier))
            -- "Your data was reset by the administrator."
            Notify.Send(src, "Os teus dados foram reiniciados pelo administrador.", "info", 6000)
        end
    end

    Debug.info(("reset: wiped all player data — %d online players reset to level 1"):format(#GetPlayers()))
end

RegisterCommand("truckjob_resetall", function(source)
    if source ~= 0 then
        if not (Bridge.IsAdmin and Bridge.IsAdmin(source)) then
            if source > 0 then
                Notify.Send(source, _U("admin_only") or "You do not have permission.", "error", 5000)
            end
            return
        end
    end

    resetAllPlayerData()

    if source > 0 then
        -- "All players have been reset."
        Notify.Send(source, "Todos os jogadores foram reiniciados.", "success", 5000)
    else
        print("[oxlyn-truckjob] All player data has been reset.")
    end
end, true)