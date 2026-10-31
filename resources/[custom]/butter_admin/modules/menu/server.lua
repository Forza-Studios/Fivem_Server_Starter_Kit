local DYNAMIC_CHOICES_TTL = 30 -- seconds

local staticChoices = {}  ---@type table<string, table[]>
local dynamicChoices = {} ---@type table<string, { list: table[], time: number }>

RegisterNetEvent('butter_admin:server:requestMenu', function(openedLocally)
    local source = source

    local denial
    if not IsAuthorized(source, 'menuopen') then
        denial = 'info.no_perm'
    elseif not IsOnDutyOrExempt(source) then
        denial = 'info.not_on_duty'
    end

    if denial then
        -- The client already opened from its cached permissions; close it again.
        if openedLocally then TriggerClientEvent('butter_admin:client:closeMenu', source) end
        return Notify(source, locale(denial), 'error')
    end

    if not openedLocally then TriggerClientEvent('butter_admin:client:openMenu', source) end
    SyncReportsForPlayer(source)
    SyncStaffChatForPlayer(source)
end)

---@param list table[]
---@return table[]
local function sortByText(list)
    table.sort(list, function(a, b) return tostring(a.Text) < tostring(b.Text) end)
    return list
end

---@param factions table<string, table>?
---@return table[]
local function buildFactionChoices(factions)
    local choices = {}
    for id, faction in pairs(factions or {}) do
        choices[#choices + 1] = { Text = faction.label or id, Source = id, Label = (' [%s]'):format(id) }
    end
    return sortByText(choices)
end

---@param factions table<string, table>?
---@return table[]
local function buildGradeChoices(factions)
    local choices = {}
    for id, faction in pairs(factions or {}) do
        local factionLabel = faction.label or id
        for level, grade in pairs(faction.grades or {}) do
            local gradeLabel = type(grade) == 'table' and (grade.label or grade.name) or tostring(grade)
            local gradeLevel = tonumber(level)
            choices[#choices + 1] = {
                Text = ('%s - %s (%s)'):format(factionLabel, gradeLabel, level),
                Value = gradeLevel,
                Source = gradeLevel,
                Label = (' [%s]'):format(id),
            }
        end
    end
    table.sort(choices, function(a, b)
        if a.Label ~= b.Label then return a.Label < b.Label end
        return (a.Value or 0) < (b.Value or 0)
    end)
    return choices
end

-- Lists that cannot change while the server runs. Built once, and only kept
-- when non-empty: an empty list usually means the framework was still loading.
local STATIC_BUILDERS = {
    items = function()
        local items = GetItems and GetItems() or (GetFrameworkItems and GetFrameworkItems()) or {}
        local choices = {}
        for name, item in pairs(items) do
            choices[#choices + 1] = {
                Text = type(item) == 'table' and item.label or name,
                Source = name,
                Label = (' [%s]'):format(name),
            }
        end
        return sortByText(choices)
    end,

    jobs = function() return buildFactionChoices(GetJobs()) end,
    gangs = function() return buildFactionChoices(GetGangs()) end,
    jobGrades = function() return buildGradeChoices(GetJobs()) end,
    gangGrades = function() return buildGradeChoices(GetGangs()) end,

    vehicleModels = function()
        local choices = {}
        for key, vehicle in pairs(GetVehicles() or {}) do
            if type(vehicle) == 'table' then
                local model = vehicle.model or (type(key) == 'string' and key)
                if model then
                    choices[#choices + 1] = {
                        Text = model,
                        Label = (' [%s %s]'):format(vehicle.brand or '---', vehicle.name or '---'),
                    }
                end
            end
        end
        return sortByText(choices)
    end,

    moneyTypes = function()
        local choices = {}
        for _, moneyType in ipairs(GetMoneyTypes()) do choices[#choices + 1] = { Text = moneyType } end
        return choices
    end,
}

-- Live data, rebuilt at most every DYNAMIC_CHOICES_TTL seconds.
local DYNAMIC_BUILDERS = {
    ownedVehicles = function()
        local choices = {}
        for _, vehicle in ipairs(FetchAllVehicles()) do
            choices[#choices + 1] = { Text = vehicle.plate, Label = (' [%s]'):format(vehicle.model or 'Unknown') }
        end
        return sortByText(choices)
    end,

    stashes = function()
        local choices = {}
        for _, stash in ipairs(GetStashes and GetStashes() or {}) do choices[#choices + 1] = { Text = stash } end
        return sortByText(choices)
    end,
}

-- Never cached: they change with every join, leave and ban.
local LIVE_BUILDERS = {
    players = function()
        local choices, onlineCitizens = {}, {}
        for _, playerId in ipairs(GetPlayers()) do
            local source = tonumber(playerId)
            local playerData = GetPlayerData(source)
            if playerData then onlineCitizens[playerData.citizenId] = true end
            choices[#choices + 1] = {
                Text = ('(%s) %s'):format(source, GetPlayerName(source)),
                Label = ' [ONLINE]',
                Value = source,
                Source = source,
            }
        end
        table.sort(choices, function(a, b) return a.Value < b.Value end)

        for _, character in ipairs(GetAllCharacters()) do
            if not onlineCitizens[character.CitizenId] then
                local value = character.License or character.CitizenId
                choices[#choices + 1] = { Text = character.Name or 'Unknown', Label = ' [OFFLINE]', Value = value, Source = value }
            end
        end
        return choices
    end,

    bans = function()
        local choices = {}
        local rows = MySQL.query.await('SELECT banid, name, reason FROM admin_bans WHERE expire > ? ORDER BY id DESC', { os.time() }) or {}
        for _, row in ipairs(rows) do
            choices[#choices + 1] = { Text = ('%s - %s'):format(row.name or 'Unknown', row.reason or ''), Source = row.banid }
        end
        return choices
    end,
}

---@param provider string
---@return table[]?
local function resolveChoices(provider)
    if STATIC_BUILDERS[provider] then
        if not staticChoices[provider] then
            local list = STATIC_BUILDERS[provider]()
            if #list == 0 then return list end
            staticChoices[provider] = list
        end
        return staticChoices[provider]
    end

    if DYNAMIC_BUILDERS[provider] then
        local cached = dynamicChoices[provider]
        if cached and os.time() - cached.time < DYNAMIC_CHOICES_TTL then return cached.list end
        local list = DYNAMIC_BUILDERS[provider]()
        dynamicChoices[provider] = { list = list, time = os.time() }
        return list
    end

    if LIVE_BUILDERS[provider] then return LIVE_BUILDERS[provider]() end
end

--- Drops cached owned-vehicle and stash lists after they change.
function InvalidateDynamicChoices()
    dynamicChoices = {}
end

lib.callback.register('butter_admin:server:getChoices', function(source, provider)
    if not IsAuthorized(source, 'menuopen') or type(provider) ~= 'string' then return {} end

    local ok, choices = pcall(resolveChoices, provider)
    if not ok then
        LogError(('Choice provider "%s" failed: %s'):format(provider, choices))
        return {}
    end
    return choices or {}
end)

lib.callback.register('butter_admin:server:getCharacterNames', function(source, serverIds)
    if not IsAuthorized(source, 'menuopen') or type(serverIds) ~= 'table' then return {} end

    local names = {}
    for i = 1, math.min(#serverIds, 256) do
        local target = ResolveTarget(serverIds[i])
        if target then
            local name = GetCharacterName(GetPlayerData(target))
            names[tostring(target)] = name ~= 'N/A' and name or GetPlayerName(target)
        end
    end
    return names
end)
