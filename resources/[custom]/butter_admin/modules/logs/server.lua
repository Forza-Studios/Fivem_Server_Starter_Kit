--- Records a staff action in admin_logs and mirrors it to the admin-log webhook.
---@param source number
---@param logType string
---@param message string
---@param data? string JSON payload
function CreateLog(source, logType, message, data)
    if not source or source == 0 then return end

    local playerData = GetPlayerData(source)
    local adminName = GetPlayerName(source) or (playerData and playerData.name) or 'Unknown'
    local identifier = GetIdentifier(source, Config.Identifier) or GetIdentifier(source, 'license') or adminName

    MySQL.insert('INSERT INTO admin_logs (Type, Steam, AdminName, Log, Cid, Data) VALUES (?, ?, ?, ?, ?, ?)', {
        logType, identifier, adminName, message, playerData and playerData.citizenId or nil, data or '',
    }, function(insertId)
        if not insertId then LogError(('Failed to write audit log "%s"'):format(logType)) end
    end)

    local fields = {
        { name = 'Admin', value = ('%s (ID: %s)'):format(adminName, source), inline = true },
        { name = 'Action', value = logType, inline = true },
        { name = 'Discord', value = GetIdentifier(source, 'discord') or 'N/A', inline = true },
        { name = 'Details', value = message or '-', inline = false },
    }
    if data and data ~= '' then
        local pretty = #data > 1000 and data:sub(1, 1000) .. '...' or data
        fields[#fields + 1] = { name = 'Data', value = ('```%s```'):format(pretty), inline = false }
    end

    SendWebhook('adminlog', ('Admin Action: %s'):format(logType), ('**%s** performed an admin action.'):format(adminName), 10181046, fields, source)
end

--- Logs a suspicious request and optionally kicks the player. Admins denied
--- only because they were off duty are never treated as exploiters.
---@param source number
---@param reason string
---@param kick? boolean
function LogExploit(source, reason, kick)
    if WasDutyDeniedOnly(source) then return end

    local name = GetPlayerName(source) or 'Unknown'
    LogWarn(('Player %s (%s) triggered a protected action: %s'):format(name, source, reason))

    SendWebhook('exploit', 'Exploit Detected', ('Player **%s** (ID: %s) triggered a protected action.'):format(name, source), 15158332, {
        { name = 'Event/Reason', value = reason, inline = false },
        { name = 'License', value = GetIdentifier(source, 'license') or 'N/A', inline = true },
        { name = 'Steam', value = GetIdentifier(source, 'steam') or 'N/A', inline = true },
        { name = 'Discord', value = GetIdentifier(source, 'discord') or 'N/A', inline = true },
        { name = 'Kicked', value = kick and 'Yes' or 'No', inline = true },
    })

    if kick then DropPlayer(source, locale('info.dropped_suspicious')) end
end

---@param words string[]
---@return string
local function typeMatchesAny(words)
    local parts = {}
    for i, word in ipairs(words) do parts[i] = ("LOWER(`Type`) LIKE '%%%s%%'"):format(word) end
    return table.concat(parts, ' OR ')
end

local VEHICLE_TYPES = '(' .. typeMatchesAny({ 'vehicle', 'car' }) .. " OR LOWER(`Type`) IN ('spawn', 'delete', 'fix'))"
local PLAYER_TYPES = '(' .. typeMatchesAny({ 'ban', 'kick', 'job', 'gang', 'money', 'cash', 'bank', 'warn', 'mute' }) .. ')'
local DATABASE_TYPES = '(' .. typeMatchesAny({ 'note', 'prop', 'object', 'database', 'inventory', 'item', 'stash', 'needs', 'stress' }) .. ')'

-- Fixed SQL fragments per category; the category name itself never reaches the query.
local LOG_CATEGORIES = {
    vehicles = VEHICLE_TYPES,
    player = PLAYER_TYPES,
    database = DATABASE_TYPES,
    admin = ('NOT %s AND NOT %s AND NOT %s'):format(VEHICLE_TYPES, PLAYER_TYPES, DATABASE_TYPES),
}

local SEARCH_COLUMNS = { 'Type', 'Steam', 'AdminName', 'Log', 'Cid', 'Data' }

-- Fixed SQL fragments per time range, like LOG_CATEGORIES.
local LOG_RANGES = {
    ['24h'] = '`Date` >= NOW() - INTERVAL 1 DAY',
    ['7d'] = '`Date` >= NOW() - INTERVAL 7 DAY',
    ['30d'] = '`Date` >= NOW() - INTERVAL 30 DAY',
}

--- Rows written before the AdminName column existed only carry the admin's
--- citizen ID, so their names are looked up in one batched query.
---@param rows table[]
---@return table<string, string>
local function resolveLegacyAdminNames(rows)
    local names, missing, seen = {}, {}, {}
    for _, row in ipairs(rows) do
        local citizenId = row.Cid
        if (not row.AdminName or row.AdminName == '') and citizenId and citizenId ~= '' and not seen[citizenId] then
            seen[citizenId] = true
            missing[#missing + 1] = citizenId
        end
    end
    if #missing == 0 then return names end

    local columns = BuildSelectList(DatabaseTables.players, PLAYER_COLUMNS)
    local query = ('SELECT %s FROM `%s` WHERE `%s` IN (%s)'):format(columns, DatabaseTables.players, DatabaseTables.playerId, ('?,'):rep(#missing):sub(1, -2))
    for _, row in ipairs(MySQL.query.await(query, missing) or {}) do
        local player = FormatDbPlayer(row)
        if player and player.citizenId then names[player.citizenId] = player.name end
    end
    return names
end

lib.callback.register('butter_admin:server:getLogs', function(source, data)
    if not IsAuthorized(source, 'page.playerlogs') then return { Logs = {}, TotalCount = 0 } end

    local page, limit, search = ReadPaging(data, 25, 100)
    local conditions, params = {}, {}

    local category = LOG_CATEGORIES[ReadField(data, 'category')]
    if category then conditions[#conditions + 1] = category end

    local range = LOG_RANGES[ReadField(data, 'range')]
    if range then conditions[#conditions + 1] = range end

    if search ~= '' then
        local searchParts = {}
        for _, column in ipairs(SEARCH_COLUMNS) do
            searchParts[#searchParts + 1] = ('`%s` LIKE ?'):format(column)
            params[#params + 1] = '%' .. search .. '%'
        end
        conditions[#conditions + 1] = '(' .. table.concat(searchParts, ' OR ') .. ')'
    end

    local where = #conditions > 0 and (' WHERE ' .. table.concat(conditions, ' AND ')) or ''
    local total = MySQL.scalar.await('SELECT COUNT(*) FROM admin_logs' .. where, params) or 0

    params[#params + 1] = limit
    params[#params + 1] = (page - 1) * limit
    local order = ReadField(data, 'order') == 'oldest' and 'ASC' or 'DESC'
    local rows = MySQL.query.await('SELECT Type, Steam, AdminName, Date, Log, Cid, Data FROM admin_logs' .. where .. ' ORDER BY id ' .. order .. ' LIMIT ? OFFSET ?', params) or {}
    local legacyNames = resolveLegacyAdminNames(rows)

    local logs = {}
    for i, row in ipairs(rows) do
        local adminName = row.AdminName
        if (not adminName or adminName == '') and row.Cid then adminName = legacyNames[row.Cid] end

        logs[i] = {
            Type = row.Type or 'Unknown',
            Steam = row.Steam or 'Unknown',
            AdminName = adminName,
            Desc = row.Log or 'No details',
            Date = row.Date or 'Unknown',
            Cid = row.Cid or 'Unknown',
            Data = row.Data or '',
        }
    end

    return { Logs = logs, TotalCount = total }
end)
