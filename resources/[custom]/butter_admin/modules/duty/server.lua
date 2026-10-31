if not Config.DutySystem.Enabled then return end

local dutyStartedAt = {} ---@type table<number, number> source -> os.time()

-- The adminDuty state bag outlives a resource restart but this table does
-- not, so resume timing anyone still on duty instead of losing their hours.
CreateThread(function()
    local now = os.time()
    for _, playerId in ipairs(GetPlayers()) do
        local source = tonumber(playerId)
        if Player(source).state.adminDuty then dutyStartedAt[source] = now end
    end
end)

---@param seconds number
---@return string
local function formatDuration(seconds)
    return ('%02d:%02d:%02d'):format(seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

--- Closes an open duty session: stores the time and posts the webhook.
---@param source number
---@param disconnected boolean
---@return string? duration
local function endDutySession(source, disconnected)
    local startedAt = dutyStartedAt[source]
    if not startedAt then return nil end
    dutyStartedAt[source] = nil

    local now = os.time()
    local duration = formatDuration(now - startedAt)
    local name = GetPlayerName(source) or 'Unknown'

    AddAdminDutySeconds(source, now - startedAt)
    SendWebhook('duty',
        disconnected and 'Admin Off Duty (Disconnected)' or 'Admin Off Duty',
        ('Admin **%s** has gone off duty%s.'):format(name, disconnected and ' (Disconnected)' or ''),
        15158332, {
            { name = 'Admin', value = name, inline = true },
            { name = 'Sign In Time', value = os.date('%Y-%m-%d %H:%M:%S', startedAt), inline = true },
            { name = 'Sign Out Time', value = os.date('%Y-%m-%d %H:%M:%S', now), inline = true },
            { name = 'Total Time Spent', value = duration, inline = false },
        }, source)
    return duration
end

---@param source number
local function toggleDuty(source)
    if source == 0 then return end

    -- Staff check that ignores the duty restriction itself.
    local resolved = ResolvePermissions(source)
    if not resolved.permissions.all and not resolved.permissions.menuopen then
        return Notify(source, locale('info.no_perm'), 'error')
    end

    local state = Player(source).state
    if state.adminDuty then
        state:set('adminDuty', false, true)
        local duration = endDutySession(source, false) or '00:00:00'
        return Notify(source, locale('duty.off', duration), 'error')
    end

    state:set('adminDuty', true, true)
    dutyStartedAt[source] = os.time()

    local name = GetPlayerName(source) or 'Unknown'
    SendWebhook('duty', 'Admin On Duty', ('Admin **%s** has gone on duty.'):format(name), 3066993, {
        { name = 'Admin', value = name, inline = true },
        { name = 'Sign In Time', value = os.date('%Y-%m-%d %H:%M:%S'), inline = true },
    }, source)
    Notify(source, locale('duty.on'), 'success')
end

lib.addCommand(Config.DutySystem.Command, { help = locale('duty.command_help') }, toggleDuty)

local alias = Config.DutySystem.Alias
if alias and alias ~= '' and alias ~= Config.DutySystem.Command then
    lib.addCommand(alias, { help = locale('duty.command_help') }, toggleDuty)
end

AddEventHandler('playerDropped', function()
    endDutySession(source, true)
end)
