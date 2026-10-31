local crypto = OxlynCrypto
local protocol = OxlynProtocol

local resourceName = GetCurrentResourceName()
local libVersion = GetResourceMetadata(resourceName, "version", 0) or "?"
local debugEnabled = GetConvarInt("oxlyn_lib_debug", 0) == 1

local function log(message, ...)
    print(("[oxlyn-lib] " .. message):format(...))
end

local function debugLog(message, ...)
    if debugEnabled then
        log(message, ...)
    end
end

---------------------------------------------------------------------
-- Server key (injected as a global, wiped immediately after reading)
---------------------------------------------------------------------

local serverMaster = crypto.fromhex(OXLYN_LIB_MASTER)
OXLYN_LIB_MASTER = nil

if not serverMaster or #serverMaster ~= 32 then
    log("^1server key missing or invalid - oxlyn-lib cannot start^0")
    return
end

if resourceName ~= "oxlyn-lib" then
    log('^3the resource folder must be named oxlyn-lib (it is "%s") - OXLYN scripts will not find it^0', resourceName)
end

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------

local products = {}        -- [callerResource] = connection info
local seenNonces = {}      -- [nonce] = os.time() when first seen (replay protection)
local lastRestart = {}     -- [callerResource] = os.time() of last restart request

-- Per-product key derived from the master key
local function deriveKey(product)
    return crypto.hmac(serverMaster, protocol.DERIVE_SERVER .. product)
end

local function reject(reason, product, caller)
    debugLog("rejected %s from %s: %s", tostring(product), tostring(caller), reason)
    return { ok = false, error = reason }
end

---------------------------------------------------------------------
-- Handshake
---------------------------------------------------------------------

-- A product proves it knows its derived key by sending
-- HMAC(key, "HELLO|product|nonce|callingResource"); the lib answers with
-- a session id and a matching WELCOME proof.
local function handshake(product, nonce, proof, callerFallback, productVersion, protocolVersion)
    local caller = GetInvokingResource() or callerFallback

    if type(caller) ~= "string" or caller == "" then
        return reject("unknown-caller", product, caller)
    end

    -- Product name: 1-64 chars of [A-Za-z0-9_-.]
    if type(product) ~= "string" or #product == 0 or #product > 64
        or product:find("[^%w_%-%.]") then
        return reject("bad-product", product, caller)
    end

    if tostring(protocolVersion) ~= protocol.VERSION then
        return reject("protocol-" .. tostring(protocolVersion), product, caller)
    end

    -- Nonce: 64 hex chars
    if type(nonce) ~= "string" or #nonce ~= 64 or nonce:find("[^%x]") then
        return reject("bad-nonce", product, caller)
    end

    -- Proof: 64 chars
    if type(proof) ~= "string" or #proof ~= 64 then
        return reject("bad-proof", product, caller)
    end

    if seenNonces[nonce] then
        return reject("replay", product, caller)
    end

    local key = deriveKey(product)
    local expected = crypto.hmac(key, table.concat({ protocol.HELLO, product, nonce, caller }, "|"))

    if proof ~= expected then
        return reject("bad-proof", product, caller)
    end

    local now = os.time()
    seenNonces[nonce] = now

    local session = crypto.nonce()

    local entry = products[caller]
    if not entry then
        entry = { since = now, handshakes = 0 }
        products[caller] = entry
    end

    entry.proto = tostring(protocolVersion)
    entry.version = tostring(productVersion or "?")
    entry.product = product
    entry.lastSeen = now
    entry.session = session
    entry.handshakes = entry.handshakes + 1

    if entry.handshakes == 1 then
        log("connected: %s (%s v%s)", caller, product, entry.version)
    else
        debugLog("re-verified: %s (%s)", caller, product)
    end

    return {
        ok = true,
        session = session,
        proof = crypto.hmac(key, table.concat({ protocol.WELCOME, product, nonce, session }, "|")),
        version = protocol.VERSION,
        lib = libVersion,
    }
end

exports("Handshake", handshake)

---------------------------------------------------------------------
-- Restart: a connected resource can ask to be restarted (max once / 60s)
-- so it loads with the lib ready
---------------------------------------------------------------------

exports("Restart", function()
    local caller = GetInvokingResource()
    if not caller or not products[caller] then
        return false
    end

    local now = os.time()
    if lastRestart[caller] and (now - lastRestart[caller]) < 60 then
        return false
    end
    lastRestart[caller] = now

    log("restarting %s so it loads with the lib ready", caller)

    SetTimeout(250, function()
        StopResource(caller)
        SetTimeout(1500, function()
            StartResource(caller)
        end)
    end)

    return true
end)

---------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------

exports("GetProducts", function()
    local list = {}

    for caller, entry in pairs(products) do
        list[caller] = {
            product = entry.product,
            version = entry.version,
            since = entry.since,
            lastSeen = entry.lastSeen,
        }
    end

    return list
end)

exports("IsConnected", function(resource)
    return products[resource] ~= nil
end)

AddEventHandler("onResourceStop", function(resource)
    if products[resource] then
        products[resource] = nil
        log("disconnected: %s", resource)
    end
end)

---------------------------------------------------------------------
-- Housekeeping: drop expired nonces every minute
---------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(60000)

        local cutoff = os.time() - protocol.NONCE_TTL

        for nonce, seenAt in pairs(seenNonces) do
            if seenAt < cutoff then
                seenNonces[nonce] = nil
            end
        end
    end
end)

---------------------------------------------------------------------
-- /oxlynlib: list connected resources (console / ACE restricted)
---------------------------------------------------------------------

RegisterCommand("oxlynlib", function()
    local lines = {}
    local count = 0
    local now = os.time()

    for caller, entry in pairs(products) do
        count = count + 1
        lines[#lines + 1] = ("  %-30s %-28s v%-10s verified %4ds ago"):format(
            caller, entry.product, entry.version, now - entry.lastSeen
        )
    end

    table.sort(lines)

    print(("[oxlyn-lib] v%s · protocol %s · %d connected resource%s"):format(
        libVersion,
        protocol.VERSION,
        count,
        count == 1 and "" or "s"
    ))

    for _, line in ipairs(lines) do
        print(line)
    end

    if count == 0 then
        print("  (no OXLYN resource has connected yet - start them after oxlyn-lib)")
    end
end, true)

log("v%s ready · protocol %s%s", libVersion, protocol.VERSION, debugEnabled and " · debug on" or "")