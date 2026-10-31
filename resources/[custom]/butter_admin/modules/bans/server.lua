local BAN_DURATIONS = {
    ['1 Hour'] = 3600,
    ['6 Hours'] = 21600,
    ['12 Hours'] = 43200,
    ['1 Day'] = 86400,
    ['3 Days'] = 259200,
    ['1 Week'] = 604800,
    ['Permanent'] = 315360000,
}
local MAX_BAN_HOURS = 24 * 365 * 100 -- anything longer is effectively permanent
local BAN_COLUMNS = 'id, banid, name, steam, license, discord, ip, reason, bannedby, expire, bannedon'
local OFFLINE_ID_COLUMNS = { steam = 'steam', license = 'license', discord = 'discord', ip = 'ip' }

-- Hardware tokens mapped to ban row IDs, so a connecting player is not checked
-- by decoding every ban. Rebuilt only after bans change.
local tokenIndex ---@type table<string, number>?

local function invalidateTokenIndex()
    tokenIndex = nil
end

---@return table<string, number>
local function getTokenIndex()
    if tokenIndex then return tokenIndex end

    local index = {}
    local rows = MySQL.query.await("SELECT id, hwid FROM admin_bans WHERE hwid IS NOT NULL AND hwid <> '' AND hwid <> '[]'") or {}
    for _, row in ipairs(rows) do
        for _, token in ipairs(DecodeJson(row.hwid, {})) do
            if type(token) == 'string' then index[token] = row.id end
        end
    end
    tokenIndex = index
    return index
end

---@param ids number[]
local function purgeExpiredBans(ids)
    if #ids == 0 then return end
    MySQL.query(('DELETE FROM admin_bans WHERE id IN (%s)'):format(('?,'):rep(#ids):sub(1, -2)), ids)
    invalidateTokenIndex()
end

--- Checks a connecting player against identifier, GUID and hardware token bans.
--- Expired matches are removed along the way.
---@param source number
---@return table? activeBan
local function findActiveBan(source)
    local rows = MySQL.query.await(('SELECT %s FROM admin_bans WHERE license = ? OR steam = ? OR discord = ? OR ip = ? OR guid = ?'):format(BAN_COLUMNS), {
        GetIdentifier(source, 'license') or 'invalid',
        GetIdentifier(source, 'steam') or 'invalid',
        GetIdentifier(source, 'discord') or 'invalid',
        GetIdentifier(source, 'ip') or 'invalid',
        GetPlayerGuid(source) or 'invalid',
    }) or {}

    local now, active, expired = os.time(), nil, {}
    for _, ban in ipairs(rows) do
        if (tonumber(ban.expire) or 0) > now then
            active = active or ban
        else
            expired[#expired + 1] = ban.id
        end
    end

    if not active then
        local index = getTokenIndex()
        for i = 0, GetNumPlayerTokens(source) - 1 do
            local banId = index[GetPlayerToken(source, i)]
            if banId then
                local ban = MySQL.single.await(('SELECT %s FROM admin_bans WHERE id = ?'):format(BAN_COLUMNS), { banId })
                if ban and (tonumber(ban.expire) or 0) > now then
                    active = ban
                    break
                elseif ban then
                    expired[#expired + 1] = ban.id
                end
            end
        end
    end

    purgeExpiredBans(expired)
    return active
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local source = source
    deferrals.defer()
    Wait(0)
    deferrals.update(locale('bans.checking'))

    local ok, ban = pcall(findActiveBan, source)
    if not ok then
        -- Never lock players out because the lookup itself failed.
        LogError('Ban check failed:', ban)
        return deferrals.done()
    end

    -- done(nil) still rejects with an empty reason, so only pass one when banned.
    if not ban then return deferrals.done() end
    deferrals.done(locale('bans.temp_banned', ban.reason, os.date('%d/%m/%Y %H:%M', tonumber(ban.expire))))
end)

--- Expiry timestamp from hours or one of the BAN_DURATIONS labels.
---@param expires any
---@return integer
local function resolveExpiry(expires)
    local hours = tonumber(expires)
    if hours and hours == hours and hours > 0 then
        return os.time() + math.floor(math.min(hours, MAX_BAN_HOURS) * 3600)
    end
    return os.time() + (BAN_DURATIONS[expires] or 3600)
end

---@return string
local function generateBanId()
    for _ = 1, 10 do
        local candidate = 'BAN-' .. math.random(11111, 99999)
        if not MySQL.scalar.await('SELECT 1 FROM admin_bans WHERE banid = ? LIMIT 1', { candidate }) then
            return candidate
        end
    end
    return 'BAN-' .. os.time()
end

---@param target number
---@return table
local function collectOnlineBanData(target)
    local tokens = {}
    for i = 0, GetNumPlayerTokens(target) - 1 do tokens[#tokens + 1] = GetPlayerToken(target, i) end

    return {
        name = GetPlayerName(target),
        license = GetIdentifier(target, 'license'),
        steam = GetIdentifier(target, 'steam'),
        discord = GetIdentifier(target, 'discord'),
        ip = GetIdentifier(target, 'ip'),
        guid = GetPlayerGuid(target),
        hwid = json.encode(tokens),
    }
end

--- An offline target is a prefixed identifier, a citizen ID or a raw license.
---@param identifier string
---@return table
local function collectOfflineBanData(identifier)
    local data = { hwid = '[]' }

    local prefix = identifier:match('^(%w+):')
    local column = prefix and OFFLINE_ID_COLUMNS[prefix]
    if column then
        data[column] = identifier
    else
        -- Player pickers hand over citizen IDs; resolve the license from the
        -- players table instead of guessing "license:<cid>".
        local columns = BuildSelectList(DatabaseTables.players, PLAYER_COLUMNS)
        local query = ('SELECT %s FROM `%s` WHERE `%s` = ? LIMIT 1'):format(columns, DatabaseTables.players, DatabaseTables.playerId)
        local row = MySQL.single.await(query, { identifier })
        if row and row[DatabaseTables.playerLicense] then
            data.license = row[DatabaseTables.playerLicense]
            local player = FormatDbPlayer(row)
            data.name = player and player.name
        else
            data.license = identifier:find(':') and identifier or ('license:' .. identifier)
        end
    end

    if not data.name then
        local name = data.license and GetOfflinePlayerName(data.license)
        data.name = (name and name ~= 'Unknown') and name or 'Offline Player'
    end
    return data
end

RegisterNetEvent('butter_admin:server:banPlayer', function(payload)
    local source = source
    if not IsAuthorized(source, 'banplayer', 'Banned a player without permission') then return end
    if type(payload) ~= 'table' then return end

    local customHours = tonumber(payload.custom_time)
    local expires = (customHours and customHours > 0) and customHours or payload.expire
    local reason = SanitizeString(payload.reason, 255) or locale('bans.no_reason')

    local onlineTarget = ResolveTarget(payload.player)
    local ban
    if onlineTarget then
        ban = collectOnlineBanData(onlineTarget)
    else
        local identifier = type(payload.player) == 'string' and SanitizeString(payload.player, 100)
        if not identifier or tonumber(identifier) then return Notify(source, locale('notify.invalid_player'), 'error') end
        ban = collectOfflineBanData(identifier)
    end

    local existing = MySQL.single.await('SELECT reason FROM admin_bans WHERE (license = ? OR steam = ? OR discord = ? OR ip = ?) AND expire > ? LIMIT 1', {
        ban.license or 'invalid', ban.steam or 'invalid', ban.discord or 'invalid', ban.ip or 'invalid', os.time(),
    })
    if existing then return Notify(source, locale('bans.already_banned', ban.name, existing.reason), 'error') end

    local expireAt = resolveExpiry(expires)
    local banId = generateBanId()
    local adminName = GetPlayerName(source) or 'Console'

    local insertId = MySQL.insert.await('INSERT INTO admin_bans (banid, name, steam, license, discord, ip, hwid, guid, reason, bannedby, expire, bannedon) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        banId, ban.name or 'Unknown', ban.steam or '', ban.license or '', ban.discord or '', ban.ip or '',
        ban.hwid, ban.guid or '', reason, adminName, expireAt, os.time(),
    })
    -- Never kick and announce a ban that was not stored.
    if not insertId then
        LogError(('Ban insert failed for %s'):format(ban.name))
        return Notify(source, locale('bans.save_failed'), 'error')
    end
    invalidateTokenIndex()

    local expiryText = os.date('%d/%m/%Y | %H:%M', expireAt)
    local durationText = expires == 'Permanent' and 'Permanent' or (tostring(expires) .. (type(expires) == 'number' and ' hour(s)' or ''))

    SendWebhook('ban', onlineTarget and 'Player Banned' or 'Offline Player Banned', 'A player has been banned from the server.', 15158332, {
        { name = 'Player Name', value = ('%s (%s)'):format(ban.name, onlineTarget or ban.license or '?'), inline = true },
        { name = 'Banned By', value = ('%s (%s)'):format(adminName, source), inline = true },
        { name = 'Ban ID', value = banId, inline = true },
        { name = 'Reason', value = reason, inline = false },
        { name = 'Duration', value = durationText, inline = true },
        { name = 'Expires', value = expiryText, inline = true },
        { name = 'License', value = ban.license or 'N/A', inline = false },
    }, source)

    Notify(source, locale('bans.success_banned', ban.name, reason), 'success')
    CreateLog(source, 'Ban Player', ('Banned player %s for %s (%s)'):format(ban.name, reason, durationText),
        json.encode({ target = payload.player, reason = reason, expires = durationText }))

    if not onlineTarget then return end

    local message = expires == 'Permanent' and locale('bans.perm_banned', reason) or locale('bans.temp_banned', reason, expiryText)
    if Config.Bans.SendDMNotification and ban.discord then
        SendDiscordDirectMessage(ban.discord, 'You have been banned', message, {
            { name = 'Server', value = Config.ServerName, inline = true },
            { name = 'Ban ID', value = banId, inline = true },
        })
    end
    DropPlayer(onlineTarget, message)
end)

RegisterNetEvent('butter_admin:server:unbanPlayer', function(payload)
    local source = source
    if not IsAuthorized(source, 'unbanplayer', 'Unbanned a player without permission') then return end

    local banId = SanitizeString(type(payload) == 'table' and payload.player or payload, 50)
    local ban = banId and MySQL.single.await('SELECT name, license FROM admin_bans WHERE banid = ? LIMIT 1', { banId })
    if not ban then return Notify(source, locale('bans.not_banned'), 'error') end

    MySQL.update.await('DELETE FROM admin_bans WHERE banid = ?', { banId })
    invalidateTokenIndex()
    Notify(source, locale('bans.unbanned'), 'success')

    local adminName = GetPlayerName(source) or 'Console'
    SendWebhook('unban', 'Player Unbanned', 'A player has been unbanned from the server.', 3066993, {
        { name = 'Ban ID', value = banId, inline = true },
        { name = 'Player Name', value = ban.name or 'Unknown', inline = true },
        { name = 'Unbanned By', value = ('%s (%s)'):format(adminName, source), inline = true },
        { name = 'License', value = ban.license or 'N/A', inline = false },
    }, source)
    CreateLog(source, 'Unban Player', ('Unbanned player with Ban ID %s'):format(banId), json.encode({ banid = banId }))
end)

RegisterNetEvent('butter_admin:server:kickPlayer', function(payload)
    local source = source
    if not IsAuthorized(source, 'kickplayer', 'Kicked a player without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target then return Notify(source, locale('notify.invalid_player'), 'error') end

    local reason = SanitizeString(ReadField(payload, 'reason'), 255) or locale('bans.kick_reason')
    local targetName, adminName = GetPlayerName(target), GetPlayerName(source) or 'Console'

    SendWebhook('kick', 'Player Kicked', 'A player has been kicked from the server.', 15105570, {
        { name = 'Player', value = ('%s (%s)'):format(targetName, target), inline = true },
        { name = 'Kicked By', value = ('%s (%s)'):format(adminName, source), inline = true },
        { name = 'Reason', value = reason, inline = false },
    }, source)

    DropPlayer(target, reason)
    Notify(source, locale('info.kicked'), 'success')
    CreateLog(source, 'Kick Player', ('Kicked player %s for: %s'):format(targetName, reason), json.encode({ target = target, reason = reason }))
end)

RegisterNetEvent('butter_admin:server:kickAllPlayers', function(payload)
    local source = source
    if not IsAuthorized(source, 'kickall', 'Kicked all players without permission') then return end

    local reason = SanitizeString(ReadField(payload, 'reason'), 255) or locale('bans.kick_reason')
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        -- The admin stays connected so they see the result.
        if target ~= source then DropPlayer(target, reason) end
    end

    SendWebhook('kick', 'Mass Kick', 'A mass kick was performed on the server.', 15105570, {
        { name = 'Performed By', value = ('%s (%s)'):format(GetPlayerName(source) or 'Console', source), inline = true },
        { name = 'Reason', value = reason, inline = false },
    }, source)
    Notify(source, locale('notify.success_kicked_all'), 'success')
    CreateLog(source, 'Kick All', ('Kicked all players for: %s'):format(reason), json.encode({ reason = reason }))
end)

RegisterNetEvent('butter_admin:server:warnPlayer', function(payload)
    local source = source
    if not IsAuthorizedAny(source, { 'warn', 'warnplayer' }, 'Warned a player without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target then return Notify(source, locale('notify.invalid_player'), 'error') end

    local reason = SanitizeString(ReadField(payload, 'reason'), 255) or locale('bans.no_reason')
    local adminName, targetName = GetPlayerName(source) or 'Console', GetPlayerName(target)

    TriggerClientEvent('butter_admin:client:showWarning', target, reason, adminName)
    SendWebhook('warn', 'Player Warned', 'A player has been warned.', 16753920, {
        { name = 'Player', value = ('%s (%s)'):format(targetName, target), inline = true },
        { name = 'Warned By', value = ('%s (%s)'):format(adminName, source), inline = true },
        { name = 'Reason', value = reason, inline = false },
    }, source)

    Notify(source, locale('bans.warned', targetName, reason), 'success')
    CreateLog(source, 'Warn Player', ('Warned player %s for: %s'):format(targetName, reason), json.encode({ target = target, reason = reason }))
end)

lib.callback.register('butter_admin:server:getBans', function(source)
    if not IsAuthorized(source, 'page.bans') then return {} end

    local bans = {}
    for _, row in ipairs(MySQL.query.await(('SELECT %s FROM admin_bans ORDER BY id DESC'):format(BAN_COLUMNS)) or {}) do
        local expires = tonumber(row.expire) or 0
        local bannedOn = tonumber(row.bannedon) or 0
        -- Permanent bans are stored as a long expiry; the UI shows 0 as permanent.
        if expires - bannedOn >= BAN_DURATIONS.Permanent then expires = 0 end

        bans[#bans + 1] = {
            Text = ('%s (%s)'):format(row.name or 'Unknown', row.banid or '?'),
            BanId = row.banid,
            Name = row.name,
            Reason = row.reason,
            Expires = expires,
            BannedOn = bannedOn,
            BannedBy = row.bannedby,
            Steam = row.steam,
            License = row.license or row.steam,
            Discord = row.discord,
        }
    end
    return bans
end)
