local DISCORD_API = 'https://discord.com/api/v10'
local AVATAR_URL = 'https://i.imgur.com/8YlWf6X.png'
local JSON_HEADERS = { ['Content-Type'] = 'application/json' }
local ERROR_COLOR = 15158332

local ROLE_CACHE_TTL = 300        -- seconds
local ROLE_RETRY_DELAY = 30       -- seconds before retrying a failed lookup
local GUILD_ROLE_CACHE_TTL = 600  -- seconds
local PROFILE_CACHE_TTL = 3600    -- seconds

local roleCache = {} ---@type table<string, { roles: string[], time: number }>
local guildRoleCache = { roles = {}, time = 0 }
local discordProfiles = {}
local steamProfiles = {}

-- Persisted so the switch on the Access Control page survives restarts.
local storedLogsSetting = GetResourceKvpString('discordLogsEnabled')
local discordLogsEnabled = storedLogsSetting == nil or storedLogsSetting == 'true'

---@return boolean
function IsDiscordLogsEnabled()
    return discordLogsEnabled
end

---@param enabled boolean
function SetDiscordLogsEnabled(enabled)
    discordLogsEnabled = enabled
    SetResourceKvp('discordLogsEnabled', enabled and 'true' or 'false')
end

--- The convar defaults are empty strings, which are truthy in Lua.
---@return boolean
function IsDiscordConfigured()
    local discord = Config.Discord
    return discord ~= nil and discord.botToken ~= '' and discord.guildId ~= ''
end

---@param token string
---@return table
local function botHeaders(token)
    return { ['Content-Type'] = 'application/json', ['Authorization'] = 'Bot ' .. token }
end

---@param title string
---@param description string
---@param color? number
---@param fields? table[]
---@return table[]
local function buildEmbed(title, description, color, fields)
    -- Discord rejects the whole embed when any field value is empty.
    for _, field in ipairs(fields or {}) do
        if field.value == nil or field.value == '' then
            field.value = 'N/A'
        elseif type(field.value) ~= 'string' then
            field.value = tostring(field.value)
        end
    end

    return {{
        title = title,
        description = description,
        color = color or 3447003,
        fields = fields or {},
        footer = { text = Config.ServerName, icon_url = AVATAR_URL },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }}
end

---@param payloadJson string
---@param filename string
---@param fileData string
---@return string body, table headers
local function buildMultipart(payloadJson, filename, fileData)
    local boundary = '----ButterAdminBoundary' .. math.random(100000, 999999)
    local body = table.concat({
        '--' .. boundary,
        'Content-Disposition: form-data; name="payload_json"',
        '',
        payloadJson,
        '--' .. boundary,
        ('Content-Disposition: form-data; name="files[0]"; filename="%s"'):format(filename),
        'Content-Type: text/html',
        '',
        fileData,
        '--' .. boundary .. '--',
    }, '\r\n')
    return body, { ['Content-Type'] = 'multipart/form-data; boundary=' .. boundary }
end

---@param url string
---@param body string
---@param headers table
local function postWebhook(url, body, headers)
    PerformHttpRequest(url, function(status)
        if status >= 400 then LogWarn(('Discord webhook returned HTTP %s'):format(status)) end
    end, 'POST', body, headers)
end

--- Posts to the configured webhook and to the acting admin's personal
--- webhook when they subscribed to this event.
---@param key string Config.Webhooks key
---@param source? number
---@param body string
---@param headers table
local function deliverWebhook(key, source, body, headers)
    local url = Config.Webhooks[key]
    if url and url ~= '' then postWebhook(url, body, headers) end

    local adminUrl, events = GetAdminWebhookBySource(source)
    if not adminUrl or adminUrl == url then return end
    for _, event in ipairs(events) do
        if event == 'all' or event == key then return postWebhook(adminUrl, body, headers) end
    end
end

---@param key string Config.Webhooks key
---@param title string
---@param description string
---@param color? number
---@param fields? table[]
---@param source? number acting admin
function SendWebhook(key, title, description, color, fields, source)
    if not discordLogsEnabled then return end
    local body = json.encode({ username = Config.ServerName, avatar_url = AVATAR_URL, embeds = buildEmbed(title, description, color, fields) })
    deliverWebhook(key, source, body, JSON_HEADERS)
end

--- Same as SendWebhook with an attached file (report transcripts).
function SendWebhookFile(key, title, description, filename, fileData, color, fields, source)
    if not discordLogsEnabled then return end
    local payload = json.encode({ username = Config.ServerName, avatar_url = AVATAR_URL, embeds = buildEmbed(title, description, color, fields) })
    local body, headers = buildMultipart(payload, filename, fileData)
    deliverWebhook(key, source, body, headers)
end

---@param discordId string with or without the "discord:" prefix
---@param onChannel fun(channelId: string)
local function openDirectChannel(discordId, onChannel)
    local token = Config.Discord.botToken
    if token == '' or type(discordId) ~= 'string' then return end

    local userId = discordId:gsub('^discord:', '')
    if not userId:match('^%d+$') then return end

    PerformHttpRequest(DISCORD_API .. '/users/@me/channels', function(status, body)
        local channel = (status == 200 or status == 201) and DecodeJson(body)
        if channel and channel.id then
            onChannel(channel.id)
        else
            LogDebug(('Could not open a Discord DM channel (HTTP %s)'):format(status))
        end
    end, 'POST', json.encode({ recipient_id = userId }), botHeaders(token))
end

---@param discordId string
---@param title string
---@param description string
---@param fields? table[]
function SendDiscordDirectMessage(discordId, title, description, fields)
    local body = json.encode({ embeds = buildEmbed(title, description, ERROR_COLOR, fields) })
    openDirectChannel(discordId, function(channelId)
        postWebhook(('%s/channels/%s/messages'):format(DISCORD_API, channelId), body, botHeaders(Config.Discord.botToken))
    end)
end

---@param discordId string
---@param title string
---@param description string
---@param filename string
---@param fileData string
function SendDiscordDirectFile(discordId, title, description, filename, fileData)
    local payload = json.encode({ embeds = buildEmbed(title, description, ERROR_COLOR) })
    openDirectChannel(discordId, function(channelId)
        local body, headers = buildMultipart(payload, filename, fileData)
        headers['Authorization'] = 'Bot ' .. Config.Discord.botToken
        postWebhook(('%s/channels/%s/messages'):format(DISCORD_API, channelId), body, headers)
    end)
end

--- Discord role IDs of a player, cached per license. Blocks on the first lookup.
---@param source number
---@return string[]
function GetPlayerRoles(source)
    if not IsDiscordConfigured() then return {} end

    local license = GetIdentifier(source, 'license')
    if not license then return {} end

    local cached = roleCache[license]
    if cached and os.time() - cached.time < ROLE_CACHE_TTL then return cached.roles end

    local discordId = GetIdentifier(source, 'discord')
    if not discordId then
        roleCache[license] = { roles = {}, time = os.time() }
        return {}
    end

    local request = promise.new()
    local url = ('%s/guilds/%s/members/%s'):format(DISCORD_API, Config.Discord.guildId, (discordId:gsub('^discord:', '')))
    PerformHttpRequest(url, function(status, body)
        if status == 200 then
            local member = DecodeJson(body)
            return request:resolve(member?.roles or {})
        end
        -- 404 means not in the guild; anything else is a failed lookup.
        request:resolve(status == 404 and {} or false)
    end, 'GET', '', botHeaders(Config.Discord.botToken))

    local roles = Citizen.Await(request)
    if roles == false then
        -- Keep the last known roles so role-based staff keep access, and retry soon.
        LogWarn(('Discord role lookup failed for %s, keeping cached roles'):format(license))
        local previous = cached?.roles or {}
        roleCache[license] = { roles = previous, time = os.time() - ROLE_CACHE_TTL + ROLE_RETRY_DELAY }
        return previous
    end

    roleCache[license] = { roles = roles, time = os.time() }
    return roles
end

--- All guild roles except @everyone and bot-managed ones, cached.
---@return { id: string, name: string, color: number }[]
function GetGuildRoles()
    if not IsDiscordConfigured() then return {} end
    if os.time() - guildRoleCache.time < GUILD_ROLE_CACHE_TTL then return guildRoleCache.roles end

    local request = promise.new()
    PerformHttpRequest(('%s/guilds/%s/roles'):format(DISCORD_API, Config.Discord.guildId), function(status, body)
        if status ~= 200 then
            LogWarn(('Discord roles request failed (HTTP %s)'):format(status))
            return request:resolve({})
        end

        local roles = {}
        for _, role in ipairs(DecodeJson(body, {})) do
            if role.name ~= '@everyone' and not role.managed then
                roles[#roles + 1] = { id = role.id, name = role.name, color = role.color }
            end
        end
        request:resolve(roles)
    end, 'GET', '', botHeaders(Config.Discord.botToken))

    -- Stamped even on failure so a broken token is not retried on every rebuild.
    guildRoleCache = { roles = Citizen.Await(request), time = os.time() }
    return guildRoleCache.roles
end

---@param license string
local function clearRoleCache(license)
    roleCache[license] = nil
end

AddEventHandler('playerDropped', function()
    local license = GetIdentifier(source, 'license')
    if license then clearRoleCache(license) end
end)

--- Stale-while-revalidate: returns the cached profile (maybe nil) right away
--- and refreshes it in the background, notifying `onUpdate` when it lands.
---@param cache table
---@param key string
---@param fetch fun(key: string, done: fun(profile: table?))
---@param onUpdate fun()
---@return table?
local function getCachedProfile(cache, key, fetch, onUpdate)
    local entry = cache[key]
    if entry and (entry.loading or os.time() - entry.time <= PROFILE_CACHE_TTL) then
        return entry.data
    end

    local previous = entry?.data
    cache[key] = { data = previous, time = os.time(), loading = true }
    fetch(key, function(profile)
        cache[key] = { data = profile or previous, time = os.time(), loading = false }
        if profile then onUpdate() end
    end)
    return previous
end

---@param userId string
---@param done fun(profile: table?)
local function fetchDiscordProfile(userId, done)
    PerformHttpRequest(('%s/users/%s'):format(DISCORD_API, userId), function(status, body)
        local user = status == 200 and DecodeJson(body)
        if not user then return done(nil) end

        local avatar
        if user.avatar then
            avatar = ('https://cdn.discordapp.com/avatars/%s/%s.png'):format(userId, user.avatar)
        else
            local index = (user.discriminator and user.discriminator ~= '0')
                and (tonumber(user.discriminator) or 0) % 5
                or (tonumber(userId:sub(-10)) or 0) % 6
            avatar = ('https://cdn.discordapp.com/embed/avatars/%d.png'):format(index)
        end
        done({ name = user.global_name or user.username, avatar = avatar })
    end, 'GET', '', botHeaders(Config.Discord.botToken))
end

---@param discordId string
---@param onUpdate fun()
---@return { name: string, avatar: string? }?
function GetDiscordProfile(discordId, onUpdate)
    if Config.Discord.botToken == '' then return nil end
    local userId = discordId:gsub('^discord:', '')
    if not userId:match('^%d+$') then return nil end
    return getCachedProfile(discordProfiles, userId, fetchDiscordProfile, onUpdate)
end

local STEAM_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

---@param body string
---@param tags string[]
---@return string?
local function matchXmlTag(body, tags)
    for _, tag in ipairs(tags) do
        local value = body:match('<' .. tag .. '><!%[CDATA%[(.-)%]%]>') or body:match('<' .. tag .. '>(.-)</' .. tag .. '>')
        if value then return value end
    end
end

---@param steamId64 string
---@param done fun(profile: table?)
local function fetchSteamProfile(steamId64, done)
    PerformHttpRequest(('https://steamcommunity.com/profiles/%s/?xml=1'):format(steamId64), function(status, body)
        if status ~= 200 or type(body) ~= 'string' then return done(nil) end
        local name = matchXmlTag(body, { 'steamID', 'steamid' })
        if not name then return done(nil) end
        done({ name = name, avatar = matchXmlTag(body, { 'avatarFull', 'avatarfull', 'avatarIcon' }) })
    end, 'GET', '', { ['User-Agent'] = STEAM_USER_AGENT })
end

--- Hex to decimal with arbitrary precision; tonumber(hex, 16) loses digits
--- on SteamID64s.
---@param hex string
---@return string?
local function hexToDecimal(hex)
    local digits = {} -- little-endian base-10 digits
    for i = 1, #hex do
        local carry = tonumber(hex:sub(i, i), 16)
        if not carry then return nil end
        for j = 1, #digits do
            local product = digits[j] * 16 + carry
            digits[j] = product % 10
            carry = product // 10
        end
        while carry > 0 do
            digits[#digits + 1] = carry % 10
            carry = carry // 10
        end
    end

    if #digits == 0 then return '0' end
    local out = {}
    for i = #digits, 1, -1 do out[#out + 1] = digits[i] end
    return table.concat(out)
end

---@param steamHex string with or without the "steam:" prefix
---@param onUpdate fun()
---@return { name: string, avatar: string? }?
function GetSteamProfile(steamHex, onUpdate)
    local steamId64 = hexToDecimal(steamHex:gsub('^steam:', ''):gsub('%s+', ''):lower())
    if not steamId64 then return nil end
    return getCachedProfile(steamProfiles, steamId64, fetchSteamProfile, onUpdate)
end

--- Creates a channel and webhook for a new admin in the staff Discord.
---@param adminName string
---@param callback fun(webhookUrl: string?)
function CreateAdminWebhookChannel(adminName, callback)
    local staff = Config.StaffDiscord
    if staff.botToken == '' or staff.guildId == '' then return callback(nil) end

    local channelName = 'admin-' .. adminName:gsub('[^%w]', '-'):lower():sub(1, 20)
    local headers = botHeaders(staff.botToken)

    PerformHttpRequest(('%s/guilds/%s/channels'):format(DISCORD_API, staff.guildId), function(status, body)
        local channel = (status == 200 or status == 201) and DecodeJson(body)
        if not channel or not channel.id then
            LogWarn(('Admin log channel creation failed (HTTP %s)'):format(status))
            return callback(nil)
        end

        PerformHttpRequest(('%s/channels/%s/webhooks'):format(DISCORD_API, channel.id), function(hookStatus, hookBody)
            local hook = (hookStatus == 200 or hookStatus == 201) and DecodeJson(hookBody)
            if not hook or not hook.id or not hook.token then
                LogWarn(('Admin webhook creation failed (HTTP %s)'):format(hookStatus))
                return callback(nil)
            end
            callback(hook.url or ('https://discord.com/api/webhooks/%s/%s'):format(hook.id, hook.token))
        end, 'POST', json.encode({ name = 'Admin Actions' }), headers)
    end, 'POST', json.encode({ name = channelName, type = 0 }), headers)
end
