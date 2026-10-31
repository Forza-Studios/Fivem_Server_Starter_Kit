if not UseBridge('inventory', 'ox_inventory') then return end

local VEHICLE_INVENTORIES = { trunk = true, glovebox = true }

--- Menu inventory refs: 5 / 'player:5' / 'stash:name[:owner]' / 'trunk:PLATE' / 'glovebox:PLATE'
---@param inventory number|string
---@return any id, string? vehicleType, string? plate
local function resolveInventory(inventory)
    if type(inventory) == 'number' then return inventory end

    local kind, value = inventory:match('^(%w+):(.+)$')
    if not kind then return tonumber(inventory) or inventory end
    if kind == 'player' then return tonumber(value) or value end

    if kind == 'stash' then
        local name, owner = value:match('^([^:]+):?(.*)$')
        if owner ~= '' then return { id = name, owner = owner } end
        return name
    end

    if VEHICLE_INVENTORIES[kind] then
        return kind .. value, kind, value -- ox names vehicle inventories 'trunkPLATE'
    end

    return inventory
end

---@param items table?
---@return table[]
local function formatItems(items)
    local list = {}
    for slot, item in pairs(items or {}) do
        if type(item) == 'table' and item.name then
            list[#list + 1] = {
                name = item.name,
                label = item.label or item.name,
                count = item.count or item.amount or 1,
                slot = item.slot or slot,
                metadata = item.metadata or item.info,
                image = item.name .. '.png',
            }
        end
    end
    return list
end

---@param inventory number|string
---@param item string
---@param amount integer
---@param metadata table?
---@param slot integer?
function AddItem(inventory, item, amount, metadata, slot)
    return exports.ox_inventory:AddItem(resolveInventory(inventory), item, amount, metadata, slot)
end

---@param inventory number|string
---@param item string
---@param amount integer
---@param slot integer?
---@param metadata table?
function RemoveItem(inventory, item, amount, slot, metadata)
    return exports.ox_inventory:RemoveItem(resolveInventory(inventory), item, amount, metadata, slot)
end

---@param inventory number|string
function ClearInventory(inventory)
    return exports.ox_inventory:ClearInventory(resolveInventory(inventory))
end

---@return table<string, table>
function GetItems()
    -- ox_inventory may still be loading its item list on the first request.
    for _ = 1, 20 do
        local items = exports.ox_inventory:Items()
        if items and next(items) then return items end
        Wait(250)
    end
    return {}
end

---@param inventory number|string
---@return table[]
function GetInventoryItems(inventory)
    local id, vehicleType, plate = resolveInventory(inventory)
    local isOwnedStash = type(id) == 'table'

    local loaded = isOwnedStash
        and exports.ox_inventory:GetInventory(id.id, id.owner)
        or exports.ox_inventory:GetInventory(id)
    if loaded then return formatItems(loaded.items) end

    -- Not loaded right now: read what ox_inventory saved to the database.
    local raw
    if vehicleType then
        raw = MySQL.scalar.await(('SELECT `%s` FROM `%s` WHERE plate = ?'):format(vehicleType, DatabaseTables.vehicles), { plate })
    elseif type(inventory) == 'string' and inventory:find('^stash:') then
        local name = isOwnedStash and id.id or id
        local owner = isOwnedStash and id.owner or nil
        raw = MySQL.scalar.await('SELECT data FROM ox_inventory WHERE name = ? AND (owner = ? OR ? IS NULL)', { name, owner, owner })
    end

    return formatItems(DecodeJson(raw, {}))
end

---@param source number
---@param inventory number|string
function OpenInventory(source, inventory)
    local id, vehicleType, plate = resolveInventory(inventory)

    if vehicleType then
        return exports.ox_inventory:forceOpenInventory(source, vehicleType, plate)
    end

    if type(inventory) == 'string' and inventory:find('^stash:') then
        return exports.ox_inventory:forceOpenInventory(source, 'stash', id)
    end

    return exports.ox_inventory:forceOpenInventory(source, 'player', id)
end

--- ox_inventory only opens a trunk/glovebox for a vehicle that exists, so the
--- client spawns a hidden copy and passes its net ID.
---@param source number
---@param vehicleType 'trunk'|'glovebox'
---@param netId number
function OpenVehicleInventory(source, vehicleType, netId)
    return exports.ox_inventory:forceOpenInventory(source, vehicleType, { netid = netId })
end

---@return string[]
function GetStashes()
    local stashes = {}
    for _, row in ipairs(MySQL.query.await('SELECT name FROM ox_inventory WHERE owner IS NULL') or {}) do
        stashes[#stashes + 1] = row.name
    end
    return stashes
end

---@param search string
---@param limit integer
---@param offset integer
---@return table[], integer
function GetStashInventories(search, limit, offset)
    local where = "name NOT LIKE 'trunk%' AND name NOT LIKE 'glovebox%' AND (name LIKE ? OR owner LIKE ?)"
    local pattern = '%' .. search .. '%'

    local total = MySQL.scalar.await('SELECT COUNT(*) FROM ox_inventory WHERE ' .. where, { pattern, pattern }) or 0
    local rows = MySQL.query.await('SELECT name, owner FROM ox_inventory WHERE ' .. where .. ' LIMIT ? OFFSET ?', { pattern, pattern, limit, offset }) or {}

    local list = {}
    for _, row in ipairs(rows) do
        local owned = row.owner and row.owner ~= ''
        list[#list + 1] = {
            id = 'stash:' .. row.name .. (owned and (':' .. row.owner) or ''),
            label = row.name .. (owned and (' (' .. row.owner .. ')') or ''),
            type = 'stash',
            owner = row.owner,
        }
    end
    return list, total
end
