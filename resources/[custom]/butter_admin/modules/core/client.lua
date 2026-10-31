local PREFERENCE_PREFIX = 'butter_admin:'
local REMOTE_AUTH_TTL = 300000 -- ms a server-verified permission is trusted locally

local DEFAULT_PREFERENCES = {
    favorites = {},
    pinned = {},
    options = { LargeDefault = false, BindOpen = true, Tooltips = true, Resizer = true },
}

-- Admin states other modules react to (noclip hides the ped, spectate restores it).
AdminState = {
    devMode = false,
    noclip = false,
    invisible = false,
    godmode = false,
}

local permissions ---@type { rank: string, permissions: table<string, boolean> }?
local remoteAuthCache = {} ---@type table<string, number>
local preferences = {} ---@type table<string, table>
local uiLocales

---@param message string
---@param notifyType? 'inform'|'success'|'error'|'warning'
function Notify(message, notifyType)
    lib.notify({ description = message, type = notifyType or 'inform' })
end

---@param action string
---@param data? any
function SendNuiAction(action, data)
    SendNUIMessage({ action = action, data = data })
end

---@param raw any
---@return any
local function decodeJson(raw)
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, value = pcall(json.decode, raw)
    return ok and value or nil
end

---@param source table
---@return table
local function copyTable(source)
    local copy = {}
    for key, value in pairs(source) do copy[key] = value end
    return copy
end

--- Locally stored menu preferences: 'favorites', 'pinned' or 'options'.
---@param name string
---@return table
function GetPreference(name)
    if not preferences[name] then
        local stored = decodeJson(GetResourceKvpString(PREFERENCE_PREFIX .. name))
        preferences[name] = type(stored) == 'table' and stored or copyTable(DEFAULT_PREFERENCES[name] or {})
    end
    return preferences[name]
end

---@param name string
---@param key? string nil replaces the whole value
---@param value any
function SetPreference(name, key, value)
    if not DEFAULT_PREFERENCES[name] then return end

    local preference = GetPreference(name)
    if key then
        preference[key] = value
    else
        preferences[name] = type(value) == 'table' and value or {}
    end
    SetResourceKvp(PREFERENCE_PREFIX .. name, json.encode(preferences[name]))
end

function ResetPreferences()
    for name in pairs(DEFAULT_PREFERENCES) do
        DeleteResourceKvp(PREFERENCE_PREFIX .. name)
        preferences[name] = nil
    end
end

--- Fetches this player's permissions from the server.
function RefreshPermissions()
    permissions = lib.callback.await('butter_admin:server:getPermissions', false)
    remoteAuthCache = {}
end

---@return boolean
function HasPermissions()
    return permissions ~= nil
end

--- UI-side check against the cached permissions. Server handlers always re-check.
---@param permission string
---@return boolean
function IsAuthorizedLocal(permission)
    local list = permissions and permissions.permissions
    return list ~= nil and (list.all == true or list[permission] == true)
end

--- Client-only actions (noclip, vehicle spawns, props) are triggered locally,
--- so the local check alone could be bypassed. This confirms with the server,
--- caching a grant briefly so rapid toggles don't wait on a round trip.
---@param permission string
---@return boolean
function IsAuthorizedRemote(permission)
    if not IsAuthorizedLocal(permission) then return false end

    local expiry = remoteAuthCache[permission]
    if expiry and GetGameTimer() < expiry then return true end

    local allowed, dutyOnly = lib.callback.await('butter_admin:server:verifyPermission', false, permission)
    if not allowed then
        remoteAuthCache[permission] = nil
        Notify(locale(dutyOnly and 'info.not_on_duty' or 'info.no_perm'), 'error')
        return false
    end

    remoteAuthCache[permission] = GetGameTimer() + REMOTE_AUTH_TTL
    return true
end

--- Mirrors the server's IsOnDutyOrExempt with the cached permissions.
---@return boolean
function IsOnDutyOrExemptLocal()
    local duty = Config.DutySystem
    if not (duty.Enabled and duty.RestrictAdminActions) then return true end
    return LocalPlayer.state.adminDuty == true or IsAuthorizedLocal('all')
end

-- Duty changes what the server authorizes, so cached grants are dropped.
AddStateBagChangeHandler('adminDuty', ('player:%s'):format(cache.serverId), function()
    remoteAuthCache = {}
end)

--- "Character(PlayerName)" when a character is loaded, otherwise the player
--- name. Must match GetDisplayName on the server, which stamps chat senders.
---@return string
function GetDisplayName()
    local playerName = GetPlayerName(cache.playerId)
    local characterName = GetCharacterName and GetCharacterName()
    characterName = characterName and characterName:match('^%s*(.-)%s*$')

    if characterName and characterName ~= '' and characterName ~= playerName then
        return ('%s(%s)'):format(characterName, playerName)
    end
    return playerName
end

--- The locale file, sent to the UI with every open.
---@return table
function GetUiLocales()
    if not uiLocales then
        local language = GetConvar('ox:locale', 'en')
        local raw = LoadResourceFile(cache.resource, ('locales/%s.json'):format(language))
            or LoadResourceFile(cache.resource, 'locales/en.json')
        uiLocales = decodeJson(raw) or {}
    end
    return uiLocales
end

---@param text string
function CopyToClipboard(text)
    SendNuiAction('copyText', { text = text })
end

---@param value number
---@param decimals integer
---@return number
function RoundTo(value, decimals)
    local multiplier = 10 ^ decimals
    return math.floor(value * multiplier + 0.5) / multiplier
end
