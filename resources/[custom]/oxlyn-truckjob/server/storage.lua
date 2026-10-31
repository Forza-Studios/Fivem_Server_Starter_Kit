Storage = Storage or {}

local cfg          = (Config and Config.Storage) or {}
local backend      = cfg.backend or "json"
local filePath     = cfg.file or "data/players.json"
local tableName    = cfg.table or "oxlyn_truckjob_players"
local saveDebounce = cfg.saveDebounce or 4000

local cache    = {}    -- identifier -> data
local dirty    = {}    -- identifier -> true (pending write)
local saving   = false
local tableReady = false

-- Fall back to JSON if oxmysql isn't running
if backend == "oxmysql" and GetResourceState("oxmysql") ~= "started" then
  Debug.warn("storage: oxmysql not started, falling back to json")
  backend = "json"
end

Debug.info(("storage backend: %s"):format(backend))

function Storage.Backend()
  return backend
end

---------------------------------------------------------------------
-- JSON helpers
---------------------------------------------------------------------

local function readFile()
  local raw = LoadResourceFile(GetCurrentResourceName(), filePath)
  if not raw or raw == "" then
    return {}
  end

  local ok, data = pcall(json.decode, raw)
  if ok and type(data) == "table" then
    return data
  end
  return {}
end

local function writeFile(data)
  local ok, encoded = pcall(json.encode, data)
  if not ok then
    return false
  end

  SaveResourceFile(GetCurrentResourceName(), filePath, encoded, -1)
  return true
end

---------------------------------------------------------------------
-- oxmysql helpers
---------------------------------------------------------------------

local function ensureTable()
  if backend ~= "oxmysql" or tableReady then
    return
  end

  local query = "CREATE TABLE IF NOT EXISTS `" .. tableName .. "` ("
    .. "identifier VARCHAR(100) NOT NULL PRIMARY KEY,"
    .. "data LONGTEXT NOT NULL,"
    .. "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"
    .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"

  local ok = pcall(function()
    exports.oxmysql:execute(query)
  end)

  if ok then
    tableReady = true
  else
    Debug.error("storage: oxmysql ensureTable failed, falling back to json")
    backend = "json"
  end
end

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------

--- Load one player's data. Returns the data directly for cached/json loads;
--- for uncached oxmysql loads it returns nil and delivers the result via cb.
function Storage.Load(identifier, cb)
  if not identifier then
    if cb then cb({}) end
    return {}
  end

  if cache[identifier] then
    if cb then cb(cache[identifier]) end
    return cache[identifier]
  end

  if backend == "oxmysql" then
    ensureTable()

    local query = "SELECT data FROM `" .. tableName .. "` WHERE identifier = ? LIMIT 1"
    exports.oxmysql:execute(query, { identifier }, function(result)
      local decoded
      if result and result[1] and result[1].data then
        local ok, data = pcall(json.decode, result[1].data)
        if ok then
          decoded = data
        end
      end

      cache[identifier] = decoded or {}
      if cb then cb(cache[identifier]) end
    end)

    return nil
  end

  cache[identifier] = readFile()[identifier] or {}
  if cb then cb(cache[identifier]) end
  return cache[identifier]
end

--- Queue a player's data for saving (written on the next flush).
function Storage.Save(identifier, data)
  if not identifier or type(data) ~= "table" then
    return
  end

  cache[identifier] = data
  dirty[identifier] = true
end

--- Write all pending changes to the backend.
local function flush()
  if next(dirty) == nil then return end
  if saving then return end
  saving = true

  if backend == "oxmysql" then
    ensureTable()

    local query = "INSERT INTO `" .. tableName .. "` (identifier, data) VALUES (?, ?) "
      .. "ON DUPLICATE KEY UPDATE data = VALUES(data)"

    for identifier in pairs(dirty) do
      local encoded = json.encode(cache[identifier] or {})
      pcall(function()
        exports.oxmysql:execute(query, { identifier, encoded })
      end)
    end
  else
    local all = readFile()
    for identifier in pairs(dirty) do
      all[identifier] = cache[identifier]
    end
    writeFile(all)
  end

  dirty = {}
  saving = false
end

--- Load every stored player. Pending (cached) data overrides stored data.
function Storage.LoadAll(cb)
  if backend == "oxmysql" then
    ensureTable()

    local query = "SELECT identifier, data FROM `" .. tableName .. "`"
    exports.oxmysql:execute(query, {}, function(rows)
      local all = {}

      for _, row in ipairs(rows or {}) do
        local ok, data = pcall(json.decode, row.data)
        if ok and type(data) == "table" then
          all[row.identifier] = data
        end
      end

      for identifier, data in pairs(cache) do
        all[identifier] = data
      end

      cb(all)
    end)
    return
  end

  local all = readFile()
  for identifier, data in pairs(cache) do
    all[identifier] = data
  end
  cb(all)
end

--- Remove one player's data everywhere.
function Storage.Clear(identifier)
  if not identifier then return end

  cache[identifier] = nil
  dirty[identifier] = nil

  if backend == "oxmysql" then
    ensureTable()
    pcall(function()
      exports.oxmysql:execute("DELETE FROM `" .. tableName .. "` WHERE identifier = ?", { identifier })
    end)
  else
    local all = readFile()
    all[identifier] = nil
    writeFile(all)
  end
end

--- Wipe all stored data.
function Storage.ClearAll()
  cache = {}
  dirty = {}

  if backend == "oxmysql" then
    ensureTable()
    pcall(function()
      exports.oxmysql:execute("DELETE FROM `" .. tableName .. "`")
    end)
  else
    writeFile({})
  end
end

---------------------------------------------------------------------
-- Autosave + flush on stop
---------------------------------------------------------------------

CreateThread(function()
  while true do
    Wait(saveDebounce)
    flush()
  end
end)

AddEventHandler("onResourceStop", function(resource)
  if resource ~= GetCurrentResourceName() then return end
  flush()
end)