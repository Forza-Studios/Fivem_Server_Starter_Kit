local RESOURCE = cache.resource
local IS_SERVER = IsDuplicityVersion()

local LOG_LEVELS = {
    error = { tag = '^1[ERROR]', setting = 'Error' },
    warn = { tag = '^3[WARN]', setting = 'Warn' },
    info = { tag = '^2[INFO]' },
    debug = { tag = '^6[DEBUG]', setting = 'Debug' },
}

---@param value any
---@return string
local function stringify(value)
    if type(value) == 'table' then return json.encode(value) end
    return tostring(value)
end

---@param level 'error'|'warn'|'info'|'debug'
local function writeLog(level, ...)
    local entry = LOG_LEVELS[level]
    if entry.setting and not (Config.Debug and Config.Debug[entry.setting]) then return end

    local count = select('#', ...)
    local parts = { ... }
    for i = 1, count do parts[i] = stringify(parts[i]) end

    print(('^5[%s] %s^7 %s'):format(RESOURCE, entry.tag, table.concat(parts, ' ', 1, count)))
end

function LogError(...) writeLog('error', ...) end
function LogWarn(...) writeLog('warn', ...) end
function LogInfo(...) writeLog('info', ...) end
function LogDebug(...) writeLog('debug', ...) end

--- True only for a resource started under exactly this name. GetResourceState
--- also reports names a resource `provide`s (sd-phone providing yseries,
--- qbx_core providing qb-core), which would load the wrong bridge.
---@param name string
---@return boolean
function IsResourceStarted(name)
    for i = 0, GetNumResources() - 1 do
        if GetResourceByFindIndex(i) == name then
            return GetResourceState(name) == 'started'
        end
    end
    return false
end

local loadedBridges = {} ---@type table<string, string>

--- Bridge guard: true when `resource` is started, and records it for the
--- startup log. A later bridge in the same category replaces the earlier
--- one's functions, so running two of them is warned about.
---@param category string
---@param resource string
---@return boolean
function UseBridge(category, resource)
    if not IsResourceStarted(resource) then return false end

    local previous = loadedBridges[category]
    if previous then
        LogWarn(('%s and %s are both running for %s, %s is used'):format(previous, resource, category, resource))
    end
    loadedBridges[category] = resource
    return true
end

-- Runs once every script has loaded. Server bridges print in the server
-- console, client bridges in F8.
CreateThread(function()
    local categories = {}
    for category in pairs(loadedBridges) do categories[#categories + 1] = category end
    table.sort(categories)

    LogInfo(('Loaded %s bridges:'):format(IS_SERVER and 'server' or 'client'))
    for _, category in ipairs(categories) do
        LogInfo(('  %-12s ^5%s^7'):format(category, loadedBridges[category]))
    end

    if IS_SERVER and not GetPlayerData then
        LogError('No supported framework is running. Start qbx_core, qb-core or es_extended before butter_admin.')
    end
end)
