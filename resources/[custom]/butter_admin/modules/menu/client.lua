local PAGE_PERMISSIONS = {
    { page = 'Commands', permission = 'page.commands' },
    { page = 'PlayerList', permission = 'page.playerlist' },
    { page = 'Bans', permission = 'page.bans' },
    { page = 'PlayerLogs', permission = 'page.playerlogs' },
    { page = 'StaffChat', permission = 'page.staffchat' },
    { page = 'Reports', permission = 'page.reports' },
    { page = 'AccessControl', permission = 'page.accesscontrol' },
    { page = 'Options', permission = 'page.options' },
    { page = 'Resources', permission = 'page.resources' },
    { page = 'Database', permission = 'page.database' },
    { page = 'TxAdmin', permission = 'page.txadmin' },
    { page = 'DevMode', permission = 'devmode' },
    { page = 'FullProfile', permission = 'fullprofile' },
    { page = 'Revive', permission = 'reviveplayer' },
    { page = 'Kill', permission = 'killplayer' },
}

if Config.EnableMonitoring then
    PAGE_PERMISSIONS[#PAGE_PERMISSIONS + 1] = { page = 'Monitoring', permission = 'page.monitoring' }
end

-- Choice lists the UI may keep for the whole session.
local CACHEABLE_CHOICES = {
    items = true, jobs = true, gangs = true, jobGrades = true, gangGrades = true, vehicleModels = true,
    moneyTypes = true, weatherTypes = true, deletionTypes = true, pedModels = true, propModels = true,
    sounds = true, animations = true,
}

-- Buttons outside the command list (player profile, reports) and the event each one fires.
local PANEL_ACTIONS = {
    revivePlayer = { event = 'butter_admin:server:revivePlayer', server = true },
    killPlayer = { event = 'butter_admin:server:killPlayer', server = true },
    healPlayer = { event = 'butter_admin:server:healPlayer', server = true },
    freezePlayer = { event = 'butter_admin:server:toggleFreeze', server = true },
    spectatePlayer = { event = 'butter_admin:server:startSpectate', server = true },
    teleportPlayer = { event = 'butter_admin:server:teleportPlayer', server = true },
    teleportPlayerToCoords = { event = 'butter_admin:server:teleportPlayerToCoords', server = true, closeMenu = true },
    teleportPlayerToMarker = { event = 'butter_admin:client:teleportPlayerToMarker' },
    teleportIntoVehicle = { event = 'butter_admin:server:teleportIntoVehicle', server = true },
    toggleNoclip = { event = 'butter_admin:client:toggleNoclip', closeMenu = true },
    warnPlayer = { event = 'butter_admin:server:warnPlayer', server = true },
    kickPlayer = { event = 'butter_admin:server:kickPlayer', server = true },
    banPlayer = { event = 'butter_admin:server:banPlayer', server = true },
    flingPlayer = { event = 'butter_admin:server:flingPlayer', server = true },
    setOnFire = { event = 'butter_admin:server:setOnFire', server = true },
    makeDrunk = { event = 'butter_admin:server:makeDrunk', server = true },
    ufoKidnap = { event = 'butter_admin:server:ufoKidnap', server = true },
    ghostTroll = { event = 'butter_admin:server:ghostTroll', server = true },
    sendToJailbox = { event = 'butter_admin:server:sendToJailbox', server = true },
    damageVehicle = { event = 'butter_admin:server:damageVehicle', server = true },
    kidnapVan = { event = 'butter_admin:server:kidnapVan', server = true },
}

local commandsById = {} ---@type table<string, table>
local menuCommands ---@type table?
local loggedIn = false
local devModeLoop = false

for _, category in ipairs(Config.CommandList) do
    for _, item in ipairs(category.Items) do commandsById[item.Id] = item end
end

---@param list table[]
---@return table[]
local function sortByText(list)
    table.sort(list, function(a, b) return tostring(a.Text) < tostring(b.Text) end)
    return list
end

-- Choice lists built from client-side data. Everything else comes from the server.
local LOCAL_CHOICES = {
    weatherTypes = function()
        local choices = {}
        for _, weather in ipairs(Config.WeatherTypes) do
            choices[#choices + 1] = { Text = weather.value, Label = (' [%s]'):format(weather.label) }
        end
        return sortByText(choices)
    end,

    deletionTypes = function()
        return { { Text = 'Objects' }, { Text = 'Peds' }, { Text = 'Vehicles' }, { Text = 'All' } }
    end,

    pedModels = function()
        local choices = {}
        for _, model in ipairs(Config.Models) do choices[#choices + 1] = { Text = model } end
        return sortByText(choices)
    end,

    propModels = function()
        local choices = {}
        for name, object in pairs(Config.Objects) do
            choices[#choices + 1] = { Text = object.model, Label = (' [%s]'):format(name) }
        end
        return sortByText(choices)
    end,

    sounds = function()
        local choices = {}
        for id, sound in pairs(Config.Sounds) do
            choices[#choices + 1] = { Text = id, Label = (' [%s]'):format(sound.Name or id) }
        end
        return sortByText(choices)
    end,

    animations = function()
        local choices = {}
        if GetAnimationList then
            for key, animation in pairs(GetAnimationList()) do
                local name, label
                if type(animation) == 'table' then
                    name = animation.name or animation.Name or animation.animation or key
                    label = animation.label or animation.Label or name
                else
                    name = type(key) == 'string' and key or animation
                    label = animation
                end
                if name then choices[#choices + 1] = { Text = tostring(name), Label = (' [%s]'):format(label), Source = name } end
            end
            return sortByText(choices)
        end

        for _, animation in ipairs(Config.Fun.Animations) do
            choices[#choices + 1] = { Text = animation.Label, Label = (' [%s]'):format(animation.Label), Source = animation.Label }
        end
        return choices
    end,

    spawnedProps = function()
        return GetSpawnedPropChoices()
    end,
}

--- Commands the player may use, with provider names instead of resolved lists:
--- some providers expand to thousands of entries, so the UI asks on demand.
---@return table[]
local function buildCommands()
    if menuCommands then return menuCommands end

    local categories = {}
    for _, category in ipairs(Config.CommandList) do
        local items = {}
        for _, item in ipairs(category.Items) do
            if IsAuthorizedLocal(item.Id) then
                local options = {}
                for i, option in ipairs(item.Options or {}) do
                    local copy = {}
                    for key, value in pairs(option) do copy[key] = value end
                    if type(option.Choices) == 'string' then
                        copy.ChoicesProvider = option.Choices
                        copy.ChoicesCache = CACHEABLE_CHOICES[option.Choices] == true
                        copy.Choices = nil
                    end
                    options[i] = copy
                end

                items[#items + 1] = {
                    Id = item.Id,
                    Name = item.Name,
                    Collapse = item.Collapse == true,
                    CloseMenu = item.CloseMenu == true,
                    StaticResult = item.StaticResult,
                    Options = options,
                }
            end
        end
        if #items > 0 then categories[#categories + 1] = { Id = category.Id, Name = category.Name, Items = items } end
    end

    menuCommands = categories
    return categories
end

---@return table<string, boolean>
local function buildPages()
    local pages = {}
    for _, entry in ipairs(PAGE_PERMISSIONS) do
        if IsAuthorizedLocal(entry.permission) then pages[entry.page] = true end
    end
    if pages.StaffChat or pages.Reports then pages.Chats = true end
    return pages
end

---@param isOpen boolean full open payload, or a refresh of an open menu
---@return table
local function buildMenuPayload(isOpen)
    local payload = {
        Debug = Config.Debug.Debug,
        Favorited = GetPreference('favorites'),
        PinnedPlayers = GetPreference('pinned'),
        MenuOptions = GetPreference('options'),
        Commands = buildCommands(),
        Name = GetDisplayName(),
        MyId = cache.serverId,
        Pages = buildPages(),
        PlayerName = Config.PlayerName,
        LicenseType = Config.LicenseType,
    }

    -- The locale file only goes out on open; it can't change while the menu is up.
    if isOpen then payload.Locales = GetUiLocales() end
    return payload
end

local function loadMenuPlayers()
    local players = lib.callback.await('butter_admin:server:getPlayers', false, {})
    if players then
        SendNuiAction('updateMenu', { OnlinePlayers = players.Online, DisconnectedPlayers = players.Disconnected })
    end
end

function OpenAdminMenu()
    if not HasPermissions() then RefreshPermissions() end
    if not IsAuthorizedLocal('menuopen') then return Notify(locale('info.no_perm'), 'error') end

    SetNuiFocus(true, true)
    SetCursorLocation(0.87, 0.15)
    SendNuiAction('openMenu', buildMenuPayload(true))

    CreateThread(loadMenuPlayers)
    if IsAuthorizedLocal('page.playerlist') then
        CreateThread(function()
            local notes = lib.callback.await('butter_admin:server:getPlayerNotes', false)
            SendNuiAction('updateMenu', { PlayerNotes = notes or {} })
        end)
    end
end

function CloseAdminMenu()
    SetNuiFocus(false, false)
    SendNuiAction('closeMenu')
end

--- Re-sends pages and commands to an open menu after permissions changed.
local function refreshOpenMenu()
    SendNuiAction('updateMenu', buildMenuPayload(false))
end

---@return boolean
local function canUseKeybind()
    return HasPermissions() and GetPreference('options').BindOpen ~= false
end

RegisterCommand('butter_admin_menu', function()
    if IsPauseMenuActive() or (IsNuiFocused() and not IsPlayerReportOpen()) then return end
    SetPlayerReportOpen(false)

    -- With cached permissions the menu opens on this frame; the server still
    -- re-checks and closes it again if the cache was stale.
    if IsAuthorizedLocal('menuopen') and IsOnDutyOrExemptLocal() then
        if not canUseKeybind() then return end
        OpenAdminMenu()
        TriggerServerEvent('butter_admin:server:requestMenu', true)
    else
        TriggerServerEvent('butter_admin:server:requestMenu', false)
    end
end, false)

RegisterKeyMapping('butter_admin_menu', locale('info.keymapping_desc'), 'keyboard', Config.Menu.OpenKey)

-- Dev mode keys: each command with a DevKey runs while dev mode is on.
for _, item in pairs(commandsById) do
    if item.DevKey then
        local commandName = 'butter_admin_dev_' .. item.Id
        RegisterCommand(commandName, function()
            if not AdminState.devMode or IsPauseMenuActive() or IsNuiFocused() then return end
            if item.EventType == 'Server' then
                TriggerServerEvent(item.Event, item.DevResult or {})
            else
                TriggerEvent(item.Event, item.DevResult or {})
            end
        end, false)
        RegisterKeyMapping(commandName, ('%s (Dev Mode)'):format(item.Name), 'keyboard', item.DevKey)
    end
end

---@param enabled boolean
local function setDevMode(enabled)
    AdminState.devMode = enabled
    LocalPlayer.state:set('devmode', enabled, true)
    SendNuiAction('setItemEnabled', { Name = 'DevMode', State = enabled })
    if Config.DevMode.OnToggle then Config.DevMode.OnToggle(enabled) end

    if not enabled then
        if not AdminState.godmode then SetPlayerInvincible(cache.playerId, false) end
        return
    end

    if not Config.DevMode.Invincible or devModeLoop then return end
    devModeLoop = true
    CreateThread(function()
        while AdminState.devMode do
            SetPlayerInvincible(cache.playerId, true)
            Wait(250)
        end
        devModeLoop = false
    end)
end

local function initialize()
    if loggedIn then return end
    loggedIn = true

    LocalPlayer.state:set('devmode', false, true)
    RefreshPermissions()
    menuCommands = nil

    TriggerEvent('chat:addSuggestion', '/' .. Config.Menu.Commands.Report, locale('info.send_report'))
    if IsAuthorizedLocal('menuopen') then
        TriggerEvent('chat:addSuggestion', '/' .. Config.Menu.Commands.Open, locale('info.keymapping_desc'))
        TriggerEvent('chat:addSuggestion', '/' .. Config.Menu.Commands.Reset, locale('info.reset_data'))
        if IsAuthorizedLocal('page.reports') then TriggerServerEvent('butter_admin:server:requestReports') end
    end
end

AddEventHandler('butter_admin:client:playerLoaded', function()
    Wait(250)
    initialize()
end)

AddEventHandler('butter_admin:client:playerUnloaded', function()
    loggedIn = false
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= cache.resource then return end
    Wait(1000)
    initialize()
end)

RegisterNetEvent('butter_admin:client:openMenu', function()
    OpenAdminMenu()
end)

RegisterNetEvent('butter_admin:client:closeMenu', CloseAdminMenu)

RegisterNetEvent('butter_admin:client:resetPreferences', function()
    ResetPreferences()
    CloseAdminMenu()
    Notify(locale('info.reset_data_success'), 'success')
end)

--- Live update after an Access Control change, so access applies without a relog.
RegisterNetEvent('butter_admin:client:refreshPermissions', function()
    local hadMenu = IsAuthorizedLocal('menuopen')
    RefreshPermissions()
    menuCommands = nil

    if IsAuthorizedLocal('menuopen') then
        if IsNuiFocused() then refreshOpenMenu() end
    elseif hadMenu then
        -- Only for players who had the menu: this reaches everyone, and closing
        -- would steal focus from their phone or inventory.
        CloseAdminMenu()
    end
end)

RegisterNetEvent('butter_admin:client:showPlayerInfo', function(data)
    SendNuiAction('showPlayerInfo', data)
end)

lib.callback.register('butter_admin:client:getWaypoint', function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return nil end
    return GetBlipInfoIdCoord(blip)
end)

RegisterNUICallback('closeMenu', function(_, cb)
    SetNuiFocus(false, false)
    cb(true)
end)

RegisterNUICallback('setPreference', function(data, cb)
    SetPreference(data.type, data.key, data.value)
    if data.type == 'options' then TriggerEvent('butter_admin:client:optionsChanged') end
    cb(true)
end)

RegisterNUICallback('resetPreferences', function(_, cb)
    ResetPreferences()
    Notify(locale('info.reset_data_success'), 'success')
    cb(true)
end)

RegisterNUICallback('toggleDevMode', function(data, cb)
    if not IsAuthorizedLocal('devmode') then return cb(false) end
    setDevMode(data.enabled == true)
    cb(true)
end)

RegisterNUICallback('openUrl', function(data, cb)
    if type(data.url) == 'string' then
        TriggerEvent('chat:addMessage', { color = { 0, 153, 255 }, multiline = true, args = { Config.ServerName, locale('notify.url_opened', data.url) } })
        Notify(locale('notify.url_opened_fallback'), 'success')
    end
    cb(true)
end)

RegisterNUICallback('runCommand', function(data, cb)
    cb(true)
    local item = commandsById[data.id]
    if not item or not IsAuthorizedLocal(item.Id) then return end

    if item.CloseMenu then CloseAdminMenu() end
    if item.EventType == 'Server' then
        TriggerServerEvent(item.Event, data.result)
    else
        TriggerEvent(item.Event, data.result)
    end
end)

RegisterNUICallback('runAction', function(data, cb)
    cb(true)
    local action = PANEL_ACTIONS[data.action]
    if not action then return end

    if action.closeMenu then CloseAdminMenu() end
    if action.server then
        TriggerServerEvent(action.event, data.data)
    else
        TriggerEvent(action.event, data.data)
    end
end)

RegisterNUICallback('getChoices', function(data, cb)
    local provider = data.provider
    if type(provider) ~= 'string' then return cb({}) end

    local builder = LOCAL_CHOICES[provider]
    if not builder then
        return cb(lib.callback.await('butter_admin:server:getChoices', false, provider) or {})
    end

    local ok, choices = pcall(builder)
    if not ok then
        LogError(('Choice provider "%s" failed: %s'):format(provider, choices))
        return cb({})
    end
    cb(choices)
end)

exports('isAdmin', function()
    return IsAuthorizedLocal('menuopen')
end)

exports('isInDevMode', function()
    return AdminState.devMode
end)

exports('openMenu', function()
    ExecuteCommand('butter_admin_menu')
end)
