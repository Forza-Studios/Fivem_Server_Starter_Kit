-- ==========================================================
-- vRP Bridge Inject for codem-supreme-hud
-- ==========================================================
-- This file is loaded INTO vRP's Lua context via Proxy.loadScript.
-- It has access to: vRP, Proxy, class, async, and all vRP internals.
-- It registers a vRP Extension to receive events and pushes
-- HUD data to the client via TriggerClientEvent.
-- ==========================================================

if not vRP then
    return
end

-- Prevent double-loading (e.g. on resource restart)
if vRP._codemHudInjected then
    return
end
vRP._codemHudInjected = true

-- ═══════════════════════════════════════════════════════════════
-- DETECT: Does vRP have its own survival module?
-- ═══════════════════════════════════════════════════════════════

local hasExternalSurvival = vRP.modules and vRP.modules.survival

-- ═══════════════════════════════════════════════════════════════
-- PROXY INTERFACE (for on-demand data queries from HUD server)
-- ═══════════════════════════════════════════════════════════════

local hudBridge = {}

function hudBridge.getUserMoney(source)
    local user = vRP.users_by_source[source]
    if user and user:isReady() then
        return user:getWallet(), user:getBank()
    end
    return 0, 0
end

function hudBridge.getUserIdentity(source)
    local user = vRP.users_by_source[source]
    if user and user:isReady() and user.identity then
        return user.identity.firstname or "Unknown", user.identity.lastname or ""
    end
    return "Unknown", ""
end

function hudBridge.getUserJob(source)
    local user = vRP.users_by_source[source]
    if user and user:isReady() then
        local group = user:getGroupByType("job")
        if group then
            local cfg = vRP.EXT.Group.cfg
            local gdata = cfg.groups[group]
            local title = gdata and gdata._config and gdata._config.title or group
            return group, title
        end
    end
    return "citizen", "Citizen"
end

function hudBridge.getUserId(source)
    local user = vRP.users_by_source[source]
    if user then return user.id end
    return nil
end

function hudBridge.isReady(source)
    local user = vRP.users_by_source[source]
    return user and user:isReady() or false
end

-- Get user hunger/thirst (0-100 scale for HUD)
function hudBridge.getUserNeeds(source)
    local user = vRP.users_by_source[source]
    if not user or not user:isReady() then return 100, 100 end

    -- If vRP has survival module, read from vitals (0-1 scale)
    if hasExternalSurvival and user.cdata and user.cdata.vitals then
        local food = user.cdata.vitals["food"]
        local water = user.cdata.vitals["water"]
        if food and water then
            return math.floor(food * 100), math.floor(water * 100)
        end
    end

    -- Built-in survival: read from codem_needs (0-100 scale)
    if user.cdata and user.cdata.codem_needs then
        return math.floor(user.cdata.codem_needs.food or 100),
               math.floor(user.cdata.codem_needs.water or 100)
    end

    return 100, 100
end

-- Set user hunger/thirst (for external scripts / food items)
function hudBridge.setUserNeeds(source, food, water)
    local user = vRP.users_by_source[source]
    if not user or not user:isReady() then return false end

    if not user.cdata.codem_needs then
        user.cdata.codem_needs = { food = 100, water = 100 }
    end

    if food then user.cdata.codem_needs.food = math.max(0, math.min(100, food)) end
    if water then user.cdata.codem_needs.water = math.max(0, math.min(100, water)) end

    TriggerClientEvent("hud:client:UpdateNeeds", source,
        math.floor(user.cdata.codem_needs.food),
        math.floor(user.cdata.codem_needs.water))

    return true
end

-- Vary user hunger/thirst by amount (for food items: positive = feed, negative = consume)
function hudBridge.varyUserNeeds(source, foodAmount, waterAmount)
    local user = vRP.users_by_source[source]
    if not user or not user:isReady() then return false end

    if not user.cdata.codem_needs then
        user.cdata.codem_needs = { food = 100, water = 100 }
    end

    if foodAmount then
        user.cdata.codem_needs.food = math.max(0, math.min(100, user.cdata.codem_needs.food + foodAmount))
    end
    if waterAmount then
        user.cdata.codem_needs.water = math.max(0, math.min(100, user.cdata.codem_needs.water + waterAmount))
    end

    TriggerClientEvent("hud:client:UpdateNeeds", source,
        math.floor(user.cdata.codem_needs.food),
        math.floor(user.cdata.codem_needs.water))

    return true
end

-- Request handler: client asks for full data refresh (e.g. after resource restart)
function hudBridge.requestPlayerData(source)
    local user = vRP.users_by_source[source]
    if not user or not user:isReady() then return false end

    local firstname = user.identity and user.identity.firstname or "Unknown"
    local lastname = user.identity and user.identity.lastname or ""
    local wallet = user:getWallet()
    local bank = user:getBank()

    local group = user:getGroupByType("job")
    local jobName = group or "citizen"
    local jobTitle = "Citizen"
    if group then
        local cfg = vRP.EXT.Group.cfg
        local gdata = cfg.groups[group]
        jobTitle = gdata and gdata._config and gdata._config.title or group
    end

    TriggerClientEvent("codem-hud:vrp:playerLoaded", source, {
        name = firstname .. " " .. lastname,
        identifier = tostring(user.id),
        wallet = wallet,
        bank = bank,
        jobName = jobName,
        jobTitle = jobTitle
    })

    -- Push hunger/thirst
    local food, water = hudBridge.getUserNeeds(source)
    TriggerClientEvent("hud:client:UpdateNeeds", source, food, water)

    return true
end

Proxy.addInterface("vRP.codem_hud", hudBridge)

-- ═══════════════════════════════════════════════════════════════
-- VRP EXTENSION (event-driven data push to client)
-- ═══════════════════════════════════════════════════════════════

local CodemHud = class("CodemHud", vRP.Extension)

CodemHud.event = {}

-- Track previous money values per user for delta calculation
local userMoneyCache = {}

function CodemHud.event:characterLoad(user)
    -- Wait for identity to be fully loaded
    SetTimeout(1500, function()
        if not user.source or not user:isReady() then return end

        local firstname = user.identity and user.identity.firstname or "Unknown"
        local lastname = user.identity and user.identity.lastname or ""
        local wallet = user:getWallet()
        local bank = user:getBank()

        -- Cache initial money
        userMoneyCache[user.source] = { wallet = wallet, bank = bank }

        local group = user:getGroupByType("job")
        local jobName = group or "citizen"
        local jobTitle = "Citizen"
        if group then
            local cfg = vRP.EXT.Group.cfg
            local gdata = cfg.groups[group]
            jobTitle = gdata and gdata._config and gdata._config.title or group
        end

        TriggerClientEvent("codem-hud:vrp:playerLoaded", user.source, {
            name = firstname .. " " .. lastname,
            identifier = tostring(user.id),
            wallet = wallet,
            bank = bank,
            jobName = jobName,
            jobTitle = jobTitle
        })

        -- Initialize built-in survival (if no external survival module)
        if not hasExternalSurvival then
            if not user.cdata.codem_needs then
                user.cdata.codem_needs = {
                    food = 75,
                    water = 100
                }
            end
        end

        -- Send initial hunger/thirst values
        local food, water = hudBridge.getUserNeeds(user.source)
        TriggerClientEvent("hud:client:UpdateNeeds", user.source, food, water)

        -- Also notify the HUD server bridge
        TriggerEvent("codem-hud:server:PlayerLoaded", user.source)

    end)
end

function CodemHud.event:characterUnload(user)
    if user.source then
        userMoneyCache[user.source] = nil
        TriggerClientEvent("codem-hud:vrp:playerUnloaded", user.source)
        TriggerEvent("codem-hud:server:PlayerUnloaded", user.source)
    end
end

function CodemHud.event:playerMoneyUpdate(user)
    if not user.source then return end

    local wallet = user:getWallet()
    local bank = user:getBank()
    local prev = userMoneyCache[user.source]

    local moneyType, changeAmount, isMinus = nil, 0, false

    if prev then
        if wallet ~= prev.wallet then
            local diff = wallet - prev.wallet
            moneyType = 'cash'
            changeAmount = math.abs(diff)
            isMinus = diff < 0
        elseif bank ~= prev.bank then
            local diff = bank - prev.bank
            moneyType = 'bank'
            changeAmount = math.abs(diff)
            isMinus = diff < 0
        end
    end

    userMoneyCache[user.source] = { wallet = wallet, bank = bank }

    TriggerClientEvent("codem-hud:vrp:moneyUpdate", user.source, wallet, bank, moneyType, changeAmount, isMinus)
end

function CodemHud.event:playerJoinGroup(user, group, gtype)
    if not user.source or gtype ~= "job" then return end

    local cfg = vRP.EXT.Group.cfg
    local gdata = cfg.groups[group]
    local title = gdata and gdata._config and gdata._config.title or group

    TriggerClientEvent("codem-hud:vrp:jobUpdate", user.source, group, title)
end

function CodemHud.event:playerLeaveGroup(user, group, gtype)
    if not user.source or gtype ~= "job" then return end

    -- Check if user got a new job already (from addGroup replacing)
    SetTimeout(100, function()
        if not user.source or not user:isReady() then return end
        local newGroup = user:getGroupByType("job")
        if newGroup then
            local cfg = vRP.EXT.Group.cfg
            local gdata = cfg.groups[newGroup]
            local title = gdata and gdata._config and gdata._config.title or newGroup
            TriggerClientEvent("codem-hud:vrp:jobUpdate", user.source, newGroup, title)
        else
            TriggerClientEvent("codem-hud:vrp:jobUpdate", user.source, "citizen", "Citizen")
        end
    end)
end

-- Hook into vRP survival module's vital changes (if it exists)
function CodemHud.event:playerVitalChange(user, vital)
    if not user.source then return end
    if not hasExternalSurvival then return end

    if vital == "food" or vital == "water" then
        local food = user.cdata and user.cdata.vitals and user.cdata.vitals["food"] or 0
        local water = user.cdata and user.cdata.vitals and user.cdata.vitals["water"] or 0
        -- Convert from 0-1 scale to 0-100 for HUD
        TriggerClientEvent("hud:client:UpdateNeeds", user.source, math.floor(food * 100), math.floor(water * 100))
    end
end

-- Reset hunger/thirst on death
function CodemHud.event:playerDeath(user)
    if not user.source or hasExternalSurvival then return end

    if user.cdata and user.cdata.codem_needs then
        user.cdata.codem_needs.food = 75
        user.cdata.codem_needs.water = 100
        TriggerClientEvent("hud:client:UpdateNeeds", user.source, 75, 100)
    end
end

function CodemHud.event:playerLeave(user)
    if user.source then
        userMoneyCache[user.source] = nil
    end
end

vRP:registerExtension(CodemHud)

-- ═══════════════════════════════════════════════════════════════
-- BUILT-IN SURVIVAL DECAY TIMER (only if no external survival)
-- ═══════════════════════════════════════════════════════════════

if not hasExternalSurvival then
    -- Read config values from HUD config (passed via global or defaults)
    local survivalEnabled = true
    local foodDecay = 1    -- per minute (0-100 scale)
    local waterDecay = 2   -- per minute (0-100 scale)
    local overflowDmg = 5  -- HP damage when at 0

    -- Try to read from Config (shared config loaded before inject)
    -- Config is in codem-supreme-hud context, not available here directly.
    -- We use a server event to receive config values.
    RegisterNetEvent("codem-hud:vrp:survivalConfig")
    AddEventHandler("codem-hud:vrp:survivalConfig", function(cfg)
        if cfg then
            if cfg.Enabled ~= nil then survivalEnabled = cfg.Enabled end
            foodDecay = cfg.FoodPerMinute or foodDecay
            waterDecay = cfg.WaterPerMinute or waterDecay
            overflowDmg = cfg.OverflowDamage or overflowDmg
        end
    end)

    local function survivalTick()
        SetTimeout(60000, survivalTick)

        if not survivalEnabled then return end

        for id, user in pairs(vRP.users) do
            if user:isReady() and user.source and user.cdata and user.cdata.codem_needs then
                local needs = user.cdata.codem_needs

                -- Decay
                needs.food = math.max(0, (needs.food or 100) - foodDecay)
                needs.water = math.max(0, (needs.water or 100) - waterDecay)

                -- Overflow damage: if at 0, apply HP damage
                if needs.food <= 0 or needs.water <= 0 then
                    TriggerClientEvent("codem-hud:vrp:survivalDamage", user.source, overflowDmg)
                end

                -- Push update to HUD
                TriggerClientEvent("hud:client:UpdateNeeds", user.source,
                    math.floor(needs.food), math.floor(needs.water))
            end
        end
    end

    -- Start decay timer
    survivalTick()

end
