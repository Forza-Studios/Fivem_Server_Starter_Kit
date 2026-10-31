local GARAGE_CACHE_TTL = 30    -- seconds
local PROPERTY_CACHE_TTL = 30  -- seconds
local ECONOMY_CACHE_TTL = 60   -- seconds
local COUNT_CACHE_TTL = 15     -- seconds

local VEHICLE_COLUMNS = { 'plate', 'vehicle', 'model', 'citizenid', 'identifier', 'owner', 'state', 'stored', 'engine', 'body', 'fuel', 'garage', 'parking' }
local VEHICLE_STATES = { Stored = true, Out = true, Impounded = true }
local ALIGNMENT_TYPES = { job = 'job', jobs = 'job', gang = 'gang', gangs = 'gang' }
local WEALTH_RANGES = { '0 - 10k', '10k - 50k', '50k - 250k', '250k - 1M', '1M+' }

local PROPERTY_SORTS = {
    name = function(a, b) return tostring(a.label):lower() < tostring(b.label):lower() end,
    price_desc = function(a, b) return (tonumber(a.price) or 0) > (tonumber(b.price) or 0) end,
    price_asc = function(a, b) return (tonumber(a.price) or 0) < (tonumber(b.price) or 0) end,
}

local garageCache = { data = nil, time = 0 }
local propertyCache = { data = nil, time = 0 }
local economyCache = { data = nil, time = 0 }
local countCache = {} ---@type table<string, { value: number, time: number }>

---@param source number
---@return boolean
local function canBrowse(source)
    return IsAuthorized(source, 'page.database')
end

---@param row table
---@return table
local function formatVehicleRow(row)
    local model = row.model or row.vehicle
    if type(model) == 'string' and model:sub(1, 1) == '{' then model = DecodeJson(model, {}).model or model end

    local state = 'Out'
    if row.state == 1 or row.stored == 1 then state = 'Stored' elseif row.state == 2 then state = 'Impounded' end

    return {
        plate = row.plate,
        model = model or 'Unknown',
        owner = row.citizenid or row.identifier or row.owner or 'Unknown',
        state = state,
        engine = row.engine or 1000,
        body = row.body or 1000,
        fuel = row.fuel or 100,
        garage = row.garage or row.parking or 'Default',
    }
end

--- COUNT(*) results memoised briefly, since the UI asks again on every page flip.
---@param key string
---@param query string
---@param params table
---@return number
local function cachedCount(key, query, params)
    local now = os.time()
    local entry = countCache[key]
    if entry and now - entry.time < COUNT_CACHE_TTL then return entry.value end

    for cacheKey, cached in pairs(countCache) do
        if now - cached.time >= COUNT_CACHE_TTL then countCache[cacheKey] = nil end
    end

    local value = MySQL.scalar.await(query, params) or 0
    countCache[key] = { value = value, time = now }
    return value
end

---@param columns string[]
---@param search string
---@param params any[]
---@return string where clause or ''
local function buildSearchClause(columns, search, params)
    if search == '' or #columns == 0 then return '' end

    local parts = {}
    for _, column in ipairs(columns) do
        parts[#parts + 1] = ('`%s` LIKE ?'):format(column)
        params[#params + 1] = '%' .. search .. '%'
    end
    return ' WHERE (' .. table.concat(parts, ' OR ') .. ')'
end

local function invalidateVehicleCaches()
    garageCache.data = nil
    for state in pairs(VEHICLE_STATES) do countCache['vehicles:' .. state] = nil end
    InvalidateDynamicChoices()
end

lib.callback.register('butter_admin:server:getGarages', function(source)
    if not canBrowse(source) then return {} end
    if garageCache.data and os.time() - garageCache.time < GARAGE_CACHE_TTL then return garageCache.data end

    local tableName = DatabaseTables.vehicles
    local rows = MySQL.query.await(('SELECT %s FROM `%s`'):format(BuildSelectList(tableName, VEHICLE_COLUMNS), tableName)) or {}
    local garages = GetDefinedGarages()

    for _, row in ipairs(rows) do
        local name = row.garage or row.parking or 'Unassigned'
        garages[name] = garages[name] or { Name = name, Vehicles = {} }
        local vehicle = formatVehicleRow(row)
        vehicle.garage = nil
        garages[name].Vehicles[#garages[name].Vehicles + 1] = vehicle
    end

    local list = {}
    for _, garage in pairs(garages) do list[#list + 1] = garage end
    table.sort(list, function(a, b) return tostring(a.Name) < tostring(b.Name) end)

    garageCache.data, garageCache.time = list, os.time()
    return list
end)

--- SQL condition matching formatVehicleRow's state mapping.
---@param tableName string
---@param state 'Stored' | 'Out' | 'Impounded'
---@return string
local function vehicleStateCondition(tableName, state)
    local columns = {}
    for _, column in ipairs(FilterColumns(tableName, { 'state', 'stored' })) do columns[column] = true end

    local storedParts = {}
    if columns.state then storedParts[#storedParts + 1] = 'COALESCE(`state`, 0) = 1' end
    if columns.stored then storedParts[#storedParts + 1] = 'COALESCE(`stored`, 0) = 1' end
    local stored = #storedParts > 0 and '(' .. table.concat(storedParts, ' OR ') .. ')' or '(0 = 1)'
    local impounded = columns.state and '(COALESCE(`state`, 0) = 2)' or '(0 = 1)'

    if state == 'Stored' then return stored end
    if state == 'Impounded' then return ('%s AND NOT %s'):format(impounded, stored) end
    return ('NOT %s AND NOT %s'):format(stored, impounded)
end

lib.callback.register('butter_admin:server:getVehicles', function(source, data)
    if not canBrowse(source) then return { Vehicles = {}, TotalCount = 0, StateCounts = {} } end

    local page, limit, search = ReadPaging(data, 20, 100)
    local tableName = DatabaseTables.vehicles
    local params = {}
    local where = buildSearchClause(FilterColumns(tableName, { 'plate', 'vehicle', 'model', 'citizenid', 'identifier', 'owner' }), search, params)

    local state = ReadField(data, 'state')
    if VEHICLE_STATES[state] then
        where = (where == '' and ' WHERE ' or where .. ' AND ') .. vehicleStateCondition(tableName, state)
    end

    local stateCounts = {}
    for name in pairs(VEHICLE_STATES) do
        stateCounts[name] = cachedCount('vehicles:' .. name, ('SELECT COUNT(*) FROM `%s` WHERE %s'):format(tableName, vehicleStateCondition(tableName, name)), {})
    end

    local total = MySQL.scalar.await(('SELECT COUNT(*) FROM `%s`%s'):format(tableName, where), params) or 0

    params[#params + 1] = limit
    params[#params + 1] = (page - 1) * limit
    local rows = MySQL.query.await(('SELECT %s FROM `%s`%s LIMIT ? OFFSET ?'):format(BuildSelectList(tableName, VEHICLE_COLUMNS), tableName, where), params) or {}

    local vehicles = {}
    for i, row in ipairs(rows) do vehicles[i] = formatVehicleRow(row) end
    return { Vehicles = vehicles, TotalCount = total, StateCounts = stateCounts }
end)

--- Every property from the housing bridges, cached because they read whole tables.
---@return table[]
local function getCachedProperties()
    if propertyCache.data and os.time() - propertyCache.time < PROPERTY_CACHE_TTL then return propertyCache.data end

    local properties = GetAllProperties()
    for _, property in ipairs(properties) do
        property.label = property.label or property.name or 'Property'
        property.address = property.address or property.label
        property.type = property.type or 'Residential'
        property.searchText = ('%s\0%s\0%s'):format(property.label, property.address, property.owner or ''):lower()
    end

    propertyCache.data, propertyCache.time = properties, os.time()
    return properties
end

lib.callback.register('butter_admin:server:getProperties', function(source, data)
    if not canBrowse(source) then return { Properties = {}, TotalCount = 0 } end

    local page, limit, search = ReadPaging(data, 20, 100)
    search = search:lower()
    local filter = ReadField(data, 'filter')
    filter = type(filter) == 'string' and filter:lower() or 'all'

    local matches = {}
    for _, property in ipairs(getCachedProperties()) do
        if (search == '' or property.searchText:find(search, 1, true)) and (filter == 'all' or tostring(property.type):lower() == filter) then
            matches[#matches + 1] = property
        end
    end

    local comparator = PROPERTY_SORTS[ReadField(data, 'sort')]
    if comparator then table.sort(matches, comparator) end

    local pageItems = {}
    local first = (page - 1) * limit + 1
    for i = first, math.min(first + limit - 1, #matches) do
        local property = matches[i]
        pageItems[#pageItems + 1] = {
            id = property.id,
            label = property.label,
            address = property.address,
            owner = property.owner,
            price = property.price,
            type = property.type,
            coords = property.coords,
        }
    end
    return { Properties = pageItems, TotalCount = #matches }
end)

lib.callback.register('butter_admin:server:getEconomy', function(source)
    if not canBrowse(source) then return nil end
    -- These aggregates scan the whole players table and sort on JSON values.
    if economyCache.data and os.time() - economyCache.time < ECONOMY_CACHE_TTL then return economyCache.data end

    local tableName = DatabaseTables.players
    local columns = GetTableColumns(tableName)
    if not columns.money then
        return { TotalCash = 0, TotalBank = 0, TotalCrypto = 0, RichestPlayers = { Total = {}, Bank = {}, Cash = {} }, WealthDistribution = {} }
    end

    local totals = MySQL.single.await(("SELECT SUM(JSON_VALUE(money, '$.cash')) AS cash, SUM(JSON_VALUE(money, '$.bank')) AS bank, SUM(JSON_VALUE(money, '$.crypto')) AS crypto FROM `%s`"):format(tableName)) or {}

    -- JSON_VALUE returns text; without the cast, ORDER BY puts "9999" above "100000".
    local cashExpr = "CAST(COALESCE(JSON_VALUE(money, '$.cash'), 0) AS DECIMAL(20,2))"
    local bankExpr = "CAST(COALESCE(JSON_VALUE(money, '$.bank'), 0) AS DECIMAL(20,2))"
    local nameColumns = BuildSelectList(tableName, { 'charinfo', 'name' })

    local function topBy(expression, label)
        local rows = MySQL.query.await(('SELECT %s, (%s) AS amount FROM `%s` ORDER BY amount DESC LIMIT 15'):format(nameColumns, expression, tableName)) or {}
        local list = {}
        for i, row in ipairs(rows) do
            local charinfo = DecodeJson(row.charinfo)
            local name = charinfo and charinfo.firstname and ('%s %s'):format(charinfo.firstname, charinfo.lastname or '') or row.name or 'Unknown'
            list[i] = { name = name, amount = tonumber(row.amount) or 0, type = label }
        end
        return list
    end

    local distributionRows = MySQL.query.await(([[
        SELECT CASE
            WHEN total <= 10000 THEN '0 - 10k'
            WHEN total <= 50000 THEN '10k - 50k'
            WHEN total <= 250000 THEN '50k - 250k'
            WHEN total <= 1000000 THEN '250k - 1M'
            ELSE '1M+'
        END AS `range`, COUNT(*) AS count
        FROM (SELECT %s + %s AS total FROM `%s`) t
        GROUP BY `range`
    ]]):format(cashExpr, bankExpr, tableName)) or {}

    local counts = {}
    for _, row in ipairs(distributionRows) do counts[row.range] = row.count end
    local distribution = {}
    for i, range in ipairs(WEALTH_RANGES) do distribution[i] = { range = range, count = counts[range] or 0 } end

    local result = {
        TotalCash = tonumber(totals.cash) or 0,
        TotalBank = tonumber(totals.bank) or 0,
        TotalCrypto = tonumber(totals.crypto) or 0,
        RichestPlayers = {
            Total = topBy(cashExpr .. ' + ' .. bankExpr, 'Net Worth'),
            Bank = topBy(bankExpr, 'Bank'),
            Cash = topBy(cashExpr, 'Cash'),
        },
        WealthDistribution = distribution,
    }

    economyCache.data, economyCache.time = result, os.time()
    return result
end)

---@param factions table<string, table>?
---@param counts table<string, number>
---@return table[]
local function formatFactions(factions, counts)
    local list = {}
    for id, faction in pairs(factions or {}) do
        local grades = {}
        for level, grade in pairs(faction.grades or {}) do
            grades[#grades + 1] = { level = tonumber(level), name = grade.name, label = grade.name }
        end
        table.sort(grades, function(a, b) return (a.level or 0) < (b.level or 0) end)

        list[#list + 1] = { id = id, name = id, label = faction.label or id, grades = grades, totalPlayers = counts[id] or 0 }
    end
    table.sort(list, function(a, b) return tostring(a.label) < tostring(b.label) end)
    return list
end

lib.callback.register('butter_admin:server:getJobs', function(source)
    if not canBrowse(source) then return {} end
    return formatFactions(GetJobs(), GetJobPlayerCounts())
end)

lib.callback.register('butter_admin:server:getGangs', function(source)
    if not canBrowse(source) then return {} end
    return formatFactions(GetGangs(), GetGangPlayerCounts())
end)

lib.callback.register('butter_admin:server:getFactionMembers', function(source, data)
    if not canBrowse(source) then return {} end

    local name = ReadField(data, 'name')
    if type(name) ~= 'string' or name == '' then return {} end
    return GetFactionRoster(ReadField(data, 'type') == 'gangs' and 'gangs' or 'jobs', name)
end)

lib.callback.register('butter_admin:server:updateAlignment', function(source, data)
    if not canBrowse(source) or type(data) ~= 'table' then return false end

    local kind = ALIGNMENT_TYPES[data.type]
    local citizenId = SanitizeString(data.citizenid, 64)
    local alignment = SanitizeString(data.alignment, 64)
    if not kind or not citizenId or not alignment then return false end

    local grade = math.floor(ClampNumber(data.grade, 0, 100, 0))
    local onlineSource = GetSourceByCitizenId(citizenId)
    local setter = kind == 'job' and SetJob or SetGang
    setter(onlineSource or citizenId, alignment, grade)

    local who = onlineSource and GetPlayerName(onlineSource) or ('Offline Player ' .. citizenId)
    Notify(source, locale('notify.success_alignment_update', citizenId), 'success')
    CreateLog(source, 'Alignment', ("Updated %s's %s to %s (Grade %s)"):format(who, kind, alignment, grade), json.encode(data))
    return true
end)

--- Splits a menu inventory ref ('player:5', 'player:CID', 'stash:x', 'trunk:PLATE').
---@param inventoryId any
---@return string? kind, number? onlineSource, string? citizenId
local function resolveInventoryTarget(inventoryId)
    if type(inventoryId) ~= 'string' and type(inventoryId) ~= 'number' then return nil end

    local kind, value = tostring(inventoryId):match('^(%w+):(.+)$')
    if kind and kind ~= 'player' then return kind end
    value = value or tostring(inventoryId)

    local onlineSource = ResolveTarget(value)
    if onlineSource then
        local playerData = GetPlayerData(onlineSource)
        return 'player', onlineSource, playerData and playerData.citizenId
    end
    return 'player', GetSourceByCitizenId(value), value
end

---@param citizenId any
---@return boolean
local function isValidCitizenId(citizenId)
    return type(citizenId) == 'string' and citizenId ~= '' and citizenId ~= 'N/A'
end

---@param search string
---@param limit integer
---@param offset integer
---@return table[], integer
local function listPlayerInventories(search, limit, offset)
    local tableName, keyColumn = DatabaseTables.players, DatabaseTables.playerId
    local params = {}
    local where = buildSearchClause(FilterColumns(tableName, { keyColumn, 'charinfo', 'firstname', 'lastname' }), search, params)
    local total = cachedCount('players:' .. search, ('SELECT COUNT(*) FROM `%s`%s'):format(tableName, where), params)

    local pageParams = { table.unpack(params) }
    pageParams[#pageParams + 1] = limit
    pageParams[#pageParams + 1] = offset
    local rows = MySQL.query.await(('SELECT %s FROM `%s`%s LIMIT ? OFFSET ?'):format(BuildSelectList(tableName, PLAYER_COLUMNS), tableName, where), pageParams) or {}

    local list = {}
    for _, row in ipairs(rows) do
        local player = FormatDbPlayer(row)
        local citizenId = player.citizenId
        list[#list + 1] = {
            id = 'player:' .. citizenId,
            label = ('%s (%s)%s'):format(player.name, citizenId, GetSourceByCitizenId(citizenId) and ' [ONLINE]' or ''),
            type = 'player',
            owner = citizenId,
        }
    end
    return list, total
end

---@param kind 'trunk'|'glovebox'
---@return table[], integer
local function listVehicleInventories(kind, search, limit, offset)
    local tableName = DatabaseTables.vehicles
    local pattern = '%' .. search .. '%'
    local total = cachedCount(kind .. ':' .. search, ('SELECT COUNT(*) FROM `%s` WHERE plate LIKE ?'):format(tableName), { pattern })
    local rows = MySQL.query.await(('SELECT plate FROM `%s` WHERE plate LIKE ? LIMIT ? OFFSET ?'):format(tableName), { pattern, limit, offset }) or {}

    local prefix = kind == 'glovebox' and 'Glovebox: ' or 'Trunk: '
    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = { id = kind .. ':' .. row.plate, label = prefix .. row.plate, type = kind }
    end
    return list, total
end

lib.callback.register('butter_admin:server:getInventories', function(source, data)
    local empty = { inventories = {}, totalCount = 0 }
    if not canBrowse(source) then return empty end

    data = type(data) == 'table' and data or {}
    local search = type(data.search) == 'string' and data.search:sub(1, 64) or ''
    local limit = math.floor(ClampNumber(data.limit, 1, 100, 50))
    local offset = math.floor(ClampNumber(data.offset, 0, 1000000, 0))

    local list, total
    if data.type == 'stash' then
        if not GetStashInventories then return empty end
        list, total = GetStashInventories(search, limit, offset)
    elseif data.type == 'trunk' or data.type == 'glovebox' then
        list, total = listVehicleInventories(data.type, search, limit, offset)
    else
        list, total = listPlayerInventories(search, limit, offset)
    end
    return { inventories = list, totalCount = tonumber(total) or #list }
end)

lib.callback.register('butter_admin:server:getInventoryItems', function(source, inventoryId)
    if not canBrowse(source) or not GetInventoryItems then return {} end

    local kind, onlineSource, citizenId = resolveInventoryTarget(inventoryId)
    if not kind then return {} end
    if kind ~= 'player' then return GetInventoryItems(inventoryId) end
    if onlineSource then return GetInventoryItems(onlineSource) end
    return isValidCitizenId(citizenId) and GetOfflinePlayerInventory(citizenId) or {}
end)

---@param source number
---@param key string locale key
---@return false
local function fail(source, key)
    Notify(source, locale(key), 'error')
    return false
end

-- Returns whether the change was applied, so the UI can roll back its optimistic update.
lib.callback.register('butter_admin:server:vehicleAction', function(source, payload)
    if not IsAuthorized(source, 'page.database', 'Edited a vehicle without permission') then return false end
    if type(payload) ~= 'table' then return false end

    local action, plate = payload.action, payload.plate
    local data = type(payload.data) == 'table' and payload.data or {}
    if not IsValidPlate(plate) then return fail(source, 'notify.invalid_plate') end

    if action == 'ChangePlate' then
        local newPlate = data.NewPlate
        if not IsValidPlate(newPlate) then return fail(source, 'notify.invalid_plate') end
        if newPlate == plate then
            Notify(source, locale('notify.plate_already_current'), 'inform')
            return false
        end
        if IsVehicleOwned(newPlate) then return fail(source, 'notify.plate_in_use') end

        local mods = DecodeJson(GetVehicleMods(plate))
        if mods then
            if mods.plate then mods.plate = newPlate end
            UpdateVehicleModsAndPlate(plate, newPlate, mods)
            Notify(source, locale('notify.plate_changed_from_to', plate, newPlate), 'success')
        else
            UpdateVehiclePlate(plate, newPlate)
            Notify(source, locale('notify.plate_changed_to', newPlate), 'success')
        end
        CreateLog(source, 'Vehicle', ('Changed plate from %s to %s'):format(plate, newPlate))
    elseif action == 'ChangeGarage' then
        local garage = SanitizeString(data.NewGarage, 64)
        if not garage then return false end
        UpdateVehicleGarage(plate, garage)
        Notify(source, locale('notify.vehicle_moved_garage', plate, garage), 'success')
        CreateLog(source, 'Vehicle', ('Moved vehicle %s to garage %s'):format(plate, garage))
    elseif action == 'ChangeState' then
        local state = data.NewState
        if not VEHICLE_STATES[state] or not UpdateVehicleState(plate, state) then return false end
        Notify(source, locale('notify.vehicle_state_changed', plate, state), 'success')
        CreateLog(source, 'Vehicle', ('Changed vehicle %s state to %s'):format(plate, state))
    elseif action == 'DeleteVehicle' then
        DeletePlayerVehicle(plate)
        Notify(source, locale('notify.vehicle_deleted', plate), 'error')
        CreateLog(source, 'Vehicle', ('Deleted vehicle %s'):format(plate))
    else
        return false
    end

    invalidateVehicleCaches()
    return true
end)

--- Reads, changes and writes back an offline player's `inventory` column.
---@param citizenId string
---@param mutate fun(items: table[]): table[]
---@return boolean
local function mutateOfflineInventory(citizenId, mutate)
    local tableName, keyColumn = DatabaseTables.players, DatabaseTables.playerId
    local raw = MySQL.scalar.await(('SELECT inventory FROM `%s` WHERE `%s` = ?'):format(tableName, keyColumn), { citizenId })
    if raw == nil then return false end

    -- Saved either as an array or keyed by slot; normalize to an array by slot.
    local items = {}
    for key, entry in pairs(DecodeJson(raw, {})) do
        if type(entry) == 'table' and entry.name then
            entry.slot = tonumber(entry.slot) or tonumber(key)
            items[#items + 1] = entry
        end
    end
    table.sort(items, function(a, b) return (a.slot or 0) < (b.slot or 0) end)

    items = mutate(items)
    MySQL.update.await(('UPDATE `%s` SET inventory = ? WHERE `%s` = ?'):format(tableName, keyColumn), { json.encode(items), citizenId })
    return true
end

-- ox_inventory stores `count`, qb-style inventories store `amount`.
local function getCountKey()
    return IsResourceStarted('ox_inventory') and 'count' or 'amount'
end

---@param citizenId string
---@param item string
---@param count number
---@return boolean
local function addOfflineItem(citizenId, item, count)
    return mutateOfflineInventory(citizenId, function(items)
        local used = {}
        for _, entry in ipairs(items) do used[entry.slot or 0] = true end
        local freeSlot = 1
        while used[freeSlot] do freeSlot += 1 end

        items[#items + 1] = { name = item, [getCountKey()] = count, slot = freeSlot, metadata = {} }
        return items
    end)
end

---@param citizenId string
---@param item string
---@param count number
---@param slot? number
---@return boolean
local function removeOfflineItem(citizenId, item, count, slot)
    return mutateOfflineInventory(citizenId, function(items)
        local remaining = count
        local countKey = getCountKey()
        for i = #items, 1, -1 do
            local entry = items[i]
            local matches = slot and entry.slot == slot or (not slot and entry.name == item)
            if remaining > 0 and matches then
                local current = tonumber(entry.count or entry.amount) or 0
                if current <= remaining then
                    remaining -= current
                    table.remove(items, i)
                else
                    entry[countKey] = current - remaining
                    remaining = 0
                end
            end
        end
        return items
    end)
end

---@param target number|string
---@param slot any
---@return table? metadata of the item in that slot
local function getSlotMetadata(target, slot)
    if not slot then return nil end
    for _, item in ipairs(GetInventoryItems(target)) do
        if tostring(item.slot) == tostring(slot) then return item.metadata end
    end
end

lib.callback.register('butter_admin:server:inventoryAction', function(source, payload)
    if type(payload) ~= 'table' then return false end
    local action, inventoryId = payload.action, payload.invId
    local data = type(payload.data) == 'table' and payload.data or {}

    local kind, onlineSource, citizenId = resolveInventoryTarget(inventoryId)
    if not kind then return false end
    local isPlayer = kind == 'player'
    local isWipe = action == 'Wipe'

    -- page.database covers everything; clearinventory may wipe players only.
    local permissions = (isWipe and isPlayer) and { 'page.database', 'clearinventory' } or { 'page.database' }
    if not IsAuthorizedAny(source, permissions, 'Edited an inventory without permission') then return false end

    local offlinePlayer = isPlayer and not onlineSource
    if offlinePlayer and not isValidCitizenId(citizenId) then return fail(source, 'notify.invalid_player') end
    if not offlinePlayer and not AddItem then return fail(source, 'notify.inventory_bridge_unavailable') end
    local target = onlineSource or inventoryId

    if action == 'AddItem' or action == 'RemoveItem' then
        local item = SanitizeString(data.item, 64)
        local count = math.floor(ClampNumber(data.count, 1, 1000, 1))
        local slot = tonumber(data.slot)
        if not item then return fail(source, 'notify.invalid_item') end

        if offlinePlayer then
            local ok = action == 'AddItem' and addOfflineItem(citizenId, item, count) or removeOfflineItem(citizenId, item, count, slot)
            if not ok then return fail(source, 'notify.invalid_player') end
        elseif action == 'AddItem' then
            AddItem(target, item, count)
        else
            -- ox_inventory matches slot removals against the item's metadata.
            RemoveItem(target, item, count, slot, getSlotMetadata(target, slot))
        end

        local verb = action == 'AddItem' and 'Added' or 'Removed'
        CreateLog(source, 'Inventory', ('%s x%s %s %s %s'):format(verb, count, item, action == 'AddItem' and 'to' or 'from', tostring(inventoryId)))
        return true
    end

    if not isWipe then return false end
    if offlinePlayer then
        mutateOfflineInventory(citizenId, function() return {} end)
    else
        ClearInventory(target)
    end
    Notify(source, locale('notify.inventory_cleared'), 'success')
    CreateLog(source, 'Inventory', 'Cleared inventory: ' .. tostring(inventoryId))
    return true
end)

lib.callback.register('butter_admin:server:propertyAction', function(source, payload)
    if not IsAuthorized(source, 'page.database', 'Edited a property without permission') then return false end

    local action = ReadField(payload, 'action')
    local propertyId = tonumber(ReadField(payload, 'propertyId'))
    if not propertyId then return fail(source, 'notify.invalid_property_id') end

    if action == 'delete' then
        if not DeleteProperty then return fail(source, 'notify.property_delete_unsupported') end
        if not DeleteProperty(propertyId) then return fail(source, 'notify.invalid_property_id') end

        propertyCache.data = nil
        Notify(source, locale('notify.property_seized'), 'error')
        CreateLog(source, 'Property', 'Seized property ID: ' .. propertyId)
        return true
    elseif action == 'teleport' then
        if not GetPropertyCoords then return fail(source, 'notify.property_teleport_unsupported') end
        local coords = GetPropertyCoords(propertyId)
        if not coords then return fail(source, 'notify.invalid_property_id') end

        TriggerClientEvent('butter_admin:client:teleport', source, coords)
        Notify(source, locale('notify.property_teleport_success'), 'success')
        CreateLog(source, 'Property', 'Teleported to property ID: ' .. propertyId)
        return true
    elseif action == 'set_owner' then
        Notify(source, locale('notify.property_transfer_soon'), 'inform')
    end
    return false
end)
