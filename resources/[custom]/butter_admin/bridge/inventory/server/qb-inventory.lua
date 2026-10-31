-- Also covers ps-inventory and lj-inventory, which keep the qb-inventory exports.
local INVENTORY
for _, name in ipairs({ 'qb-inventory', 'ps-inventory', 'lj-inventory' }) do
    if UseBridge('inventory', name) then
        INVENTORY = name
        break
    end
end
if not INVENTORY then return end

local QBCore = exports['qb-core']:GetCoreObject()
local VEHICLE_INVENTORIES = { trunk = true, glovebox = true }
local NOT_VEHICLE_FILTER = "identifier NOT LIKE 'trunk%' AND identifier NOT LIKE 'glovebox%'"

--- Menu inventory refs: 5 / 'player:5' / 'stash:name' / 'trunk:PLATE' / 'glovebox:PLATE'
---@param inventory number|string
---@return number|string
local function resolveInventory(inventory)
    if type(inventory) == 'number' then return inventory end

    local kind, value = inventory:match('^(%w+):(.+)$')
    if not kind then return tonumber(inventory) or inventory end
    if kind == 'player' then return tonumber(value) or value end
    if kind == 'stash' then return value:match('^[^:]+') end
    if VEHICLE_INVENTORIES[kind] then return kind .. '-' .. value end -- qb names them 'trunk-PLATE'

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
                count = item.amount or item.count or 1,
                slot = item.slot or slot,
                metadata = item.info or item.metadata,
                image = item.name .. '.png',
            }
        end
    end
    return list
end

---@param id number|string
---@return table?
local function getOnlinePlayer(id)
    if type(id) == 'number' then return QBCore.Functions.GetPlayer(id) end
    return QBCore.Functions.GetPlayerByCitizenId(id)
end

---@param inventory number|string
---@param item string
---@param amount integer
---@param metadata table?
---@param slot integer?
function AddItem(inventory, item, amount, metadata, slot)
    return exports[INVENTORY]:AddItem(resolveInventory(inventory), item, amount, slot or false, metadata)
end

---@param inventory number|string
---@param item string
---@param amount integer
---@param slot integer?
function RemoveItem(inventory, item, amount, slot)
    return exports[INVENTORY]:RemoveItem(resolveInventory(inventory), item, amount, slot or false)
end

---@param inventory number|string
function ClearInventory(inventory)
    local id = resolveInventory(inventory)
    local player = getOnlinePlayer(id)
    if player then return player.Functions.ClearInventory() end

    return exports[INVENTORY]:ClearStash(id)
end

---@return table<string, table>
function GetItems()
    return QBCore.Shared.Items
end

---@param inventory number|string
---@return table[]
function GetInventoryItems(inventory)
    local id = resolveInventory(inventory)
    local player = getOnlinePlayer(id)
    if player then return formatItems(player.PlayerData.items) end

    local loaded = exports[INVENTORY]:GetInventory(id)
    if loaded then return formatItems(loaded.items or loaded) end

    -- Not loaded right now: read what the inventory saved to the database.
    local raw = MySQL.scalar.await('SELECT items FROM inventories WHERE identifier = ?', { id })
    return formatItems(DecodeJson(raw, {}))
end

---@param source number
---@param inventory number|string
function OpenInventory(source, inventory)
    local id = resolveInventory(inventory)
    if type(id) == 'number' then
        return exports[INVENTORY]:OpenInventoryById(source, id)
    end

    return exports[INVENTORY]:OpenInventory(source, id)
end

---@return string[]
function GetStashes()
    local stashes = {}
    for _, row in ipairs(MySQL.query.await('SELECT identifier FROM inventories WHERE ' .. NOT_VEHICLE_FILTER) or {}) do
        stashes[#stashes + 1] = row.identifier
    end
    return stashes
end

---@param search string
---@param limit integer
---@param offset integer
---@return table[], integer
function GetStashInventories(search, limit, offset)
    local where = NOT_VEHICLE_FILTER .. ' AND identifier LIKE ?'
    local pattern = '%' .. search .. '%'

    local total = MySQL.scalar.await('SELECT COUNT(*) FROM inventories WHERE ' .. where, { pattern }) or 0
    local rows = MySQL.query.await('SELECT identifier FROM inventories WHERE ' .. where .. ' LIMIT ? OFFSET ?', { pattern, limit, offset }) or {}

    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = {
            id = 'stash:' .. row.identifier,
            label = 'Stash: ' .. row.identifier,
            type = 'stash',
        }
    end
    return list, total
end
