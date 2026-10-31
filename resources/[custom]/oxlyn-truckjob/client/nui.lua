-- oxlyn-truckjob menu / NUI bridge (decompiled output, cleaned: names restored, temp registers removed)
-- Opens and closes the NUI menu, forwards server data to the UI and handles NUI callbacks.
-- Relies on globals defined elsewhere: Config, Truck, GetLocale

---------------------------------------------------------------------
-- Locale keys sent to the UI
---------------------------------------------------------------------
local LOCALE_KEYS = {
    -- general
    "app_title", "app_subtitle", "close", "confirm", "cancel", "back",
    -- menu
    "menu_routes", "menu_history", "menu_stats", "menu_ranking", "menu_info", "menu_settings", "menu_quit",
    -- routes
    "route_distance", "route_payment", "route_difficulty", "route_select",
    "route_easy", "route_medium", "route_hard", "route_estimated",
    "no_routes", "route_locked",
    -- hud
    "hud_remaining", "hud_payment", "hud_route", "hud_speed",
    -- stats
    "stats_total_paid", "stats_deliveries", "stats_distance", "stats_avg_pay", "stats_best_run",
    -- progression
    "level", "xp", "xp_progress", "xp_to_next", "xp_max", "level_up", "level_locked", "pay_multiplier",
    -- interaction / misc
    "interact_label", "interact_hint", "delivery_perfect", "pg_processing", "pg_complete",
    "route_repeat", "route_completed", "rotation_in", "rotation_now", "bonus_next_in",
    -- ranking
    "ranking_title", "ranking_subtitle", "ranking_position", "ranking_player", "ranking_level",
    "ranking_xp", "ranking_earned", "ranking_deliveries", "ranking_empty", "ranking_disabled", "ranking_you",
    -- panels
    "routes_info_banner", "routes_panel_title", "routes_panel_sub",
    "history_panel_title", "history_panel_sub", "history_empty",
    "stats_panel_title", "stats_panel_sub", "info_panel_title", "info_panel_sub",
    -- detailed stats
    "stats_records", "stats_records_sub", "stats_per_km", "stats_progression", "stats_progression_sub",
    "stats_to_next", "stats_max_level", "stats_routes", "stats_routes_sub", "stats_unique_routes",
    "stats_most_repeated", "stats_total_completions", "stats_overview_tag",
    -- delivery paper
    "paper_doc_no", "paper_from", "paper_to", "paper_cargo", "paper_distance", "paper_time",
    "paper_payment", "paper_sig_label", "paper_sign", "paper_cancel", "paper_delivered",
    "paper_brand_subtitle", "paper_bd_base", "paper_bd_km", "paper_bd_time", "paper_bd_fast",
    "paper_bd_slow", "paper_bd_perfect", "paper_bd_repeat", "paper_bd_damage", "paper_bd_level",
    "paper_bd_event", "paper_bd_tax",
    -- delivery NPC
    "delivery_npc_label", "delivery_npc_hint",
}

-- Builds the { key = translated text } table for the UI (falls back to the key itself).
local function buildLocale()
    local locale = GetLocale()
    local result = {}
    for _, key in ipairs(LOCALE_KEYS) do
        result[key] = locale[key] or key
    end
    return result
end

---------------------------------------------------------------------
-- Menu state
---------------------------------------------------------------------
local function setMenuOpen(isOpen)
    Truck.menuOpen = isOpen
    TriggerEvent("oxlyn-truckjob:client:menuStateChanged", isOpen)
end

---------------------------------------------------------------------
-- Player avatar (ped headshot)
---------------------------------------------------------------------
local headshotHandle = nil

local function releaseHeadshot()
    if headshotHandle then
        UnregisterPedheadshot(headshotHandle)
        headshotHandle = nil
    end
end

local function sendPlayerAvatar()
    local ped = PlayerPedId()

    releaseHeadshot()

    local handle = RegisterPedheadshot(ped)
    if handle == 0 then return end
    headshotHandle = handle

    CreateThread(function()
        local deadline = GetGameTimer() + 4000
        while not IsPedheadshotReady(handle) and deadline > GetGameTimer() do
            Wait(50)
        end
        if not IsPedheadshotReady(handle) then return end

        local txd = GetPedheadshotTxdString(handle)
        if not txd then return end

        SendNUIMessage({
            action = "profile",
            avatar = ("https://nui-img/%s/%s"):format(txd, txd),
        })
    end)
end

---------------------------------------------------------------------
-- Player name (ESX character name if available, otherwise the player name)
---------------------------------------------------------------------
local function getPlayerDisplayName()
    local ok, esx = pcall(function()
        return exports.es_extended:getSharedObject()
    end)

    if ok and esx and esx.GetPlayerData then
        local data = esx.GetPlayerData()
        if data and data.firstName then
            local fullName = data.firstName .. " " .. (data.lastName or "")
            return (fullName:gsub("^%s+", ""):gsub("%s+$", ""))
        end
    end

    return GetPlayerName(PlayerId()) or "Driver"
end

---------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------
local function openMenu()
    if Truck.menuOpen then return end

    setMenuOpen(true)
    SetNuiFocus(true, true)

    local branding = Config.Branding

    SendNUIMessage({
        action = "open",
        locale = buildLocale(),
        lang = Config.Locale or "en",
        branding = {
            company = (branding and branding.company) or "Oxlyn",
            companyFull = (branding and branding.companyFull) or "Oxlyn Logistics",
        },
        player = { name = getPlayerDisplayName() },
        accent = Config.UI.accent,
        theme = Config.UI.theme,
        currency = Config.Currency,
        routes = {}, -- filled in later via the setRoutes event
        progression = {
            level = Truck.level,
            xp = Truck.xp,
            xpNext = Truck.xpNext,
        },
        ranking = {
            enabled = (Config.Ranking and Config.Ranking.enabled) and true or false,
            refreshEvery = (Config.Ranking and Config.Ranking.refreshEvery) or 60,
        },
    })

    sendPlayerAvatar()
    TriggerServerEvent("oxlyn-truckjob:server:getStats")
end

local function closeMenu()
    if not Truck.menuOpen then return end

    setMenuOpen(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
    releaseHeadshot()
end

RegisterNetEvent("oxlyn-truckjob:client:openMenu", openMenu)
RegisterNetEvent("oxlyn-truckjob:client:closeMenu", closeMenu)

---------------------------------------------------------------------
-- Server -> UI data
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:client:setStats", function(stats)
    SendNUIMessage({ action = "stats", stats = stats })
end)

RegisterNetEvent("oxlyn-truckjob:client:setHistory", function(history)
    SendNUIMessage({ action = "history", history = history })
end)

RegisterNetEvent("oxlyn-truckjob:client:setInfo", function(info)
    SendNUIMessage({ action = "info", info = info })
end)

RegisterNetEvent("oxlyn-truckjob:client:setRoutes", function(payload)
    SendNUIMessage({ action = "routes", payload = payload or {} })
end)

RegisterNetEvent("oxlyn-truckjob:client:setRanking", function(payload)
    SendNUIMessage({ action = "ranking", payload = payload or {} })
end)

RegisterNetEvent("oxlyn-truckjob:client:bonus", function(payload)
    SendNUIMessage({ action = "bonus", payload = payload or { active = false } })
end)

---------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------
RegisterNUICallback("close", function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback("selectRoute", function(data, cb)
    closeMenu()
    TriggerEvent("oxlyn-truckjob:client:startRoute", data.id)
    cb({ ok = true })
end)

RegisterNUICallback("cancelJob", function(_, cb)
    TriggerEvent("oxlyn-truckjob:client:cancel")
    cb({ ok = true })
end)

RegisterNUICallback("quitJob", function(_, cb)
    TriggerEvent("oxlyn-truckjob:client:cancel")
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback("refreshStats", function(_, cb)
    TriggerServerEvent("oxlyn-truckjob:server:getStats")
    cb({ ok = true })
end)

RegisterNUICallback("refreshRoutes", function(_, cb)
    TriggerServerEvent("oxlyn-truckjob:server:requestRoutes")
    cb({ ok = true })
end)

RegisterNUICallback("refreshRanking", function(_, cb)
    TriggerServerEvent("oxlyn-truckjob:server:requestRanking")
    cb({ ok = true })
end)

RegisterNUICallback("signDelivery", function(_, cb)
    TriggerEvent("oxlyn-truckjob:client:signDelivery")
    cb({ ok = true })
end)

RegisterNUICallback("cancelDeliveryPaper", function(_, cb)
    TriggerEvent("oxlyn-truckjob:client:cancelDeliveryPaper")
    cb({ ok = true })
end)