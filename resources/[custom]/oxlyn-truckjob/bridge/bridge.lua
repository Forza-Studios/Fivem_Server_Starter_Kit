Bridge = {
    name = nil,       -- chosen framework name ("esx", "qb", "qbox", "standalone", ...)
    impl = nil,       -- the registered implementation table for that framework
    registry = {},    -- name -> implementation
    readyCbs = {},    -- callbacks waiting for the bridge to be ready
}

local function debugInfo(...)
    if Debug and Debug.info then
        Debug.info(...)
    end
end

-- Register a framework implementation under a name.
function Bridge.Register(name, impl)
    Bridge.registry[name] = impl
end

-- Resolves Config.Framework, auto-detecting from running resources if "auto".
local function detectFramework()
    local framework = Config.Framework

    if framework == "auto" then
        if GetResourceState("es_extended") == "started" then
            framework = "esx"
        elseif GetResourceState("qbx_core") == "started" then
            framework = "qbox"
        elseif GetResourceState("qb-core") == "started" then
            framework = "qb"
        else
            framework = "standalone"
        end
    end

    return framework
end

-- Pick and initialise the framework implementation once everything has loaded.
CreateThread(function()
    Wait(0)

    local name = detectFramework()
    debugInfo("framework chosen:", name)

    local impl = Bridge.registry[name]
    if not impl then
        Debug.warn(('framework "%s" is not registered, falling back to standalone'):format(name))
        impl = Bridge.registry.standalone
    end

    Bridge.name = name
    Bridge.impl = impl

    if type(impl.init) == "function" then
        impl.init()
    end

    for _, callback in ipairs(Bridge.readyCbs) do
        local ok, err = pcall(callback, Bridge)
        if not ok then
            Debug.error(("ready callback error: %s"):format(err))
        end
    end
end)

-- Runs `callback(Bridge)` now if ready, otherwise once the bridge is ready.
function Bridge.OnReady(callback)
    if Bridge.impl then
        callback(Bridge)
    else
        Bridge.readyCbs[#Bridge.readyCbs + 1] = callback
    end
end

-- Calls a method on the active implementation (nil if unavailable).
local function call(method, ...)
    if not Bridge.impl then
        return
    end

    local fn = Bridge.impl[method]
    if not fn then
        return
    end

    return fn(...)
end

---------------------------------------------------------------------------
-- Thin wrappers around the active framework implementation
---------------------------------------------------------------------------

function Bridge.GetPlayer(source)
    return call("GetPlayer", source)
end

function Bridge.GetIdentifier(source)
    return call("GetIdentifier", source)
end

function Bridge.GetJob(source)
    return call("GetJob", source)
end

function Bridge.HasJob(source, job)
    return call("HasJob", source, job)
end

function Bridge.AddMoney(source, account, amount)
    return call("AddMoney", source, account, amount)
end

function Bridge.RemoveMoney(source, account, amount)
    return call("RemoveMoney", source, account, amount)
end

function Bridge.HasItem(source, item, count)
    return call("HasItem", source, item, count)
end

function Bridge.RemoveItem(source, item, count)
    return call("RemoveItem", source, item, count)
end

function Bridge.RegisterUsableItem(...)
    return call("RegisterUsableItem", ...)
end

function Bridge.GetName(source)
    return call("GetName", source)
end

function Bridge.HasLicense(source, license)
    return call("HasLicense", source, license)
end

function Bridge.GetJobGrade(source)
    return call("GetJobGrade", source)
end

-- Maps to the implementation's "Notify".
function Bridge.NotifyNative(source, message, type, duration)
    return call("Notify", source, message, type, duration)
end

---------------------------------------------------------------------------
-- Admin check (server only)
---------------------------------------------------------------------------

local function listContains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

function Bridge.IsAdmin(source)
    if not IsDuplicityVersion() then
        return false
    end

    local cfg = Config.Admin or {}

    -- 1. Custom override takes priority if it returns a non-nil result
    if Overrides and type(Overrides.IsAdmin) == "function" then
        local ok, result = pcall(Overrides.IsAdmin, source)
        if ok and result ~= nil then
            return result and true or false
        end
    end

    -- 2. Everyone is admin
    if cfg.allowAll then
        return true
    end

    -- 3. ACE permission
    if cfg.aceFlag and cfg.aceFlag ~= "" and IsPlayerAceAllowed(source, cfg.aceFlag) then
        return true
    end

    -- 4. Framework group / permission fallback
    if cfg.fallbackToGroup then
        local adminGroups = cfg.adminGroups or {}
        local player = Bridge.GetPlayer(source)

        if player then
            if player.getGroup then
                if listContains(adminGroups, player.getGroup()) then
                    return true
                end
            end

            if player.PlayerData then
                local role = player.PlayerData.permission or player.PlayerData.role
                if listContains(adminGroups, role) then
                    return true
                end
            end
        end
    end

    return false
end