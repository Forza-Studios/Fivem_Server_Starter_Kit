-- txAdmin-style dashboard: server info, a console mirror and the txAdmin
-- event feed. Data is only streamed while someone has the page open.
local CONSOLE_MAX = 300 -- console lines kept in memory
local EVENTS_MAX = 60   -- txAdmin events kept in memory
local FLUSH_MS = 600    -- how often new console lines are pushed to viewers

local consoleLines = {} ---@type { id: number, ch: string, msg: string }[]
local events = {}       ---@type { id: number, kind: string, label: string, time: number }[]
local lineSequence = 0
local eventSequence = 0
local flushedSequence = 0
local subscribers = {}  ---@type table<number, true>
local sessionStartedAt = {} ---@type table<number, number>
local nextRestart
local flushRunning = false

---@param channel string?
---@param message any
local function pushConsoleLine(channel, message)
    if type(message) ~= 'string' then return end
    -- Colour codes (^1, ^2, ...) are stripped so the page renders clean text.
    message = message:gsub('%^%d', ''):gsub('[\r\n]+$', '')
    if message == '' then return end

    lineSequence += 1
    consoleLines[#consoleLines + 1] = { id = lineSequence, ch = channel or 'server', msg = message }
    if #consoleLines > CONSOLE_MAX then table.remove(consoleLines, 1) end
end

---@param kind string
---@param label string
local function pushEvent(kind, label)
    eventSequence += 1
    local entry = { id = eventSequence, kind = kind, label = label, time = os.time() }
    events[#events + 1] = entry
    if #events > EVENTS_MAX then table.remove(events, 1) end

    for subscriber in pairs(subscribers) do
        TriggerClientEvent('butter_admin:client:dashboardPush', subscriber, { kind = 'event', event = entry })
    end
end

-- Catches script and print output routed through the server console. Raw
-- stdout that txAdmin reads directly is not visible here.
RegisterConsoleListener(function(channel, message)
    pushConsoleLine(channel, message)
end)

--- Pushes new console lines to viewers while anyone is subscribed.
local function startFlushLoop()
    if flushRunning then return end
    flushRunning = true

    CreateThread(function()
        while next(subscribers) do
            Wait(FLUSH_MS)
            if lineSequence > flushedSequence then
                local newLines = {}
                for _, line in ipairs(consoleLines) do
                    if line.id > flushedSequence then newLines[#newLines + 1] = line end
                end
                flushedSequence = lineSequence

                for subscriber in pairs(subscribers) do
                    TriggerClientEvent('butter_admin:client:dashboardPush', subscriber, { kind = 'console', lines = newLines })
                end
            end
        end
        flushRunning = false
    end)
end

---@return table
local function buildServerInfo()
    return {
        hostname = GetConvar('sv_hostname', GetConvar('sv_projectName', 'FXServer')),
        players = #GetPlayers(),
        maxPlayers = GetConvarInt('sv_maxClients', 48),
        uptimeMs = GetGameTimer(),
        txVersion = GetConvar('txAdmin-version', 'n/a'),
        txName = GetConvar('txAdmin-serverName', GetConvar('sv_projectName', 'n/a')),
        serverMode = GetConvar('txAdminServerMode', 'unknown'),
        fxVersion = GetConvar('version', 'n/a'),
        nextRestart = nextRestart,
    }
end

---@return table[]
local function buildSessions()
    local now = os.time()
    local list = {}
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        local characterName = GetCharacterName(GetPlayerData(source))
        local joinedAt = sessionStartedAt[source] or now
        list[#list + 1] = {
            id = source,
            name = GetPlayerName(source) or ('#' .. source),
            charName = characterName ~= 'N/A' and characterName or nil,
            ping = GetPlayerPing(source) or 0,
            joinedAt = joinedAt,
            playSec = now - joinedAt,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- Players already connected when the resource (re)starts.
CreateThread(function()
    local now = os.time()
    for _, playerId in ipairs(GetPlayers()) do sessionStartedAt[tonumber(playerId)] = now end
end)

AddEventHandler('playerJoining', function()
    sessionStartedAt[source] = os.time()
end)

AddEventHandler('playerDropped', function()
    sessionStartedAt[source] = nil
    subscribers[source] = nil
end)

lib.callback.register('butter_admin:server:getDashboard', function(source)
    if not IsAuthorized(source, 'page.txadmin') then return nil end
    return {
        info = buildServerInfo(),
        console = consoleLines,
        events = events,
        canRunCommands = IsAuthorized(source, 'txadmin_console'),
        lastSeq = lineSequence,
    }
end)

lib.callback.register('butter_admin:server:getDashboardSessions', function(source)
    if not IsAuthorized(source, 'page.txadmin') then return {} end
    return buildSessions()
end)

RegisterNetEvent('butter_admin:server:subscribeDashboard', function(enabled)
    local source = source
    if not enabled or not IsAuthorized(source, 'page.txadmin') then
        subscribers[source] = nil
        return
    end

    subscribers[source] = true
    TriggerClientEvent('butter_admin:client:dashboardPush', source, {
        kind = 'snapshot',
        info = buildServerInfo(),
        console = consoleLines,
        events = events,
    })
    startFlushLoop()
end)

RegisterNetEvent('butter_admin:server:runConsoleCommand', function(command)
    local source = source
    if not IsAuthorized(source, 'txadmin_console', 'Ran a console command without permission') then return end
    if type(command) ~= 'string' then return end

    command = command:gsub('[\r\n]', ' '):sub(1, 512)
    if command == '' then return end

    pushConsoleLine('admin', ('> [%s] %s'):format(GetPlayerName(source) or source, command))
    ExecuteCommand(command)
    CreateLog(source, 'Console', ('Ran console command: %s'):format(command), json.encode({ cmd = command }))
end)

AddEventHandler('txAdmin:events:scheduledRestart', function(data)
    if type(data) ~= 'table' then return end
    local minutes = data.secondsRemaining and math.floor(data.secondsRemaining / 60)
    nextRestart = { minutes = minutes }
    pushEvent('restart', ('Scheduled restart in %s'):format(minutes and (minutes .. ' min') or 'soon'))
end)

AddEventHandler('txAdmin:events:announcement', function(data)
    local message = type(data) == 'table' and (data.message or data.author) or tostring(data)
    pushEvent('announcement', ('Announcement: %s'):format(message))
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function(data)
    pushEvent('shutdown', type(data) == 'table' and data.message or 'Server shutting down')
end)

AddEventHandler('txAdmin:events:playerKicked', function(data)
    if type(data) ~= 'table' then return end
    pushEvent('kick', ('Kicked %s: %s'):format(data.target or '?', data.reason or 'no reason'))
end)

AddEventHandler('txAdmin:events:playerBanned', function(data)
    if type(data) ~= 'table' then return end
    pushEvent('ban', ('Banned %s: %s'):format(data.targetName or data.target or '?', data.reason or 'no reason'))
end)

AddEventHandler('txAdmin:events:playerWarned', function(data)
    if type(data) ~= 'table' then return end
    pushEvent('warn', ('Warned %s: %s'):format(data.targetName or data.target or '?', data.reason or 'no reason'))
end)
