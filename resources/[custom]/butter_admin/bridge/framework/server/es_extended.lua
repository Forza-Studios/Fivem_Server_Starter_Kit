if not UseBridge('framework', 'es_extended') then return end

local ESX = exports['es_extended']:getSharedObject()

DatabaseTables = {
    players = 'users',
    playerId = 'identifier',
    playerLicense = 'identifier',
    vehicles = 'owned_vehicles',
}

local ADMIN_GROUPS = { admin = true, superadmin = true, god = true }

---@param value any
---@return table
local function decode(value)
    return DecodeJson(value, {})
end

--- ESX calls cash "money"; the menu uses the QB name.
---@param moneyType string
---@return string
local function toAccountName(moneyType)
    return moneyType == 'cash' and 'money' or moneyType
end

--- Vehicle props are stored as JSON with the model inside.
---@param raw any
---@return string
local function vehicleModelFromProps(raw)
    return decode(raw).model or 'unknown'
end

local garageColumn

--- ESX garage scripts disagree on the column name.
---@return string
local function getGarageColumn()
    if not garageColumn then
        local hasParking = MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'owned_vehicles' AND COLUMN_NAME = 'parking'")
        garageColumn = (tonumber(hasParking) or 0) > 0 and 'parking' or 'garage'
    end
    return garageColumn
end

---@param source number
---@return table?
function GetPlayer(source)
    return ESX.GetPlayerFromId(source)
end

---@param source number
---@return table|false
function GetPlayerData(source)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return false end

    local accounts = {}
    for _, account in ipairs(xPlayer.accounts or {}) do
        accounts[account.name] = account.money
    end

    local variables = xPlayer.variables or {}
    local job = xPlayer.job or {}

    return {
        source = xPlayer.source,
        citizenId = xPlayer.identifier,
        license = xPlayer.identifier,
        name = ('%s %s'):format(variables.firstName or '', variables.lastName or ''),
        charinfo = { firstname = variables.firstName, lastname = variables.lastName },
        money = { cash = accounts.money or 0, bank = accounts.bank or 0, crypto = 0 },
        job = { name = job.name, label = job.label, grade = { name = job.grade_name, level = job.grade } },
    }
end

---@param identifier string
---@return number?
function GetSourceByCitizenId(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    return xPlayer?.source
end

---@param source number
---@return boolean
function HasFrameworkPermission(source)
    local xPlayer = GetPlayer(source)
    return xPlayer ~= nil and ADMIN_GROUPS[xPlayer.getGroup()] == true
end

---@return string[]
function GetMoneyTypes()
    return { 'bank', 'cash' }
end

function AddMoney(source, moneyType, amount, reason)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return false end

    xPlayer.addAccountMoney(toAccountName(moneyType), amount, reason)
    return true
end

function SetMoney(source, moneyType, amount, reason)
    local xPlayer = GetPlayer(source)
    if not xPlayer then return false end

    xPlayer.setAccountMoney(toAccountName(moneyType), amount, reason)
    return true
end

function SetPlayerMetadata(source, key, value)
    local xPlayer = GetPlayer(source)
    if xPlayer?.setMeta then
        xPlayer.setMeta(key, value)
    end
end

function SavePlayer(source)
    local xPlayer = GetPlayer(source)
    if xPlayer then ESX.SavePlayer(xPlayer) end
end

-- ESX has no job duty.
function ToggleJobDuty()
    return nil
end

--- `target` is a server ID or, for offline players, an identifier.
function SetJob(target, job, grade)
    local xPlayer = type(target) == 'number' and GetPlayer(target) or ESX.GetPlayerFromIdentifier(target)
    if xPlayer then
        xPlayer.setJob(job, grade)
    elseif type(target) == 'string' then
        MySQL.update.await('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', { job, grade, target })
    end
end

-- ESX has no gangs.
function SetGang() end

function GetJobs() return ESX.GetJobs() or {} end
function GetGangs() return {} end
function GetFrameworkItems() return ESX.GetItems and ESX.GetItems() or {} end

function GetVehicles()
    local vehicles = {}
    for _, row in ipairs(MySQL.query.await('SELECT model, name, category FROM vehicles') or {}) do
        vehicles[row.model] = { model = row.model, name = row.name, brand = row.category }
    end
    return vehicles
end

function FormatDbPlayer(row)
    if not row then return nil end
    local accounts = decode(row.accounts)

    return {
        citizenId = row.identifier,
        license = row.identifier,
        name = row.firstname and ('%s %s'):format(row.firstname, row.lastname or '') or 'Unknown',
        steam = row.identifier or 'Not Linked',
        cash = accounts.money or 0,
        bank = accounts.bank or 0,
        crypto = 0,
        job = { name = row.job, label = row.job, grade = row.job_grade or 0 },
        gang = {},
        dob = row.dateofbirth or 'Unknown',
        bloodgroup = 'N/A',
        phone = row.phone_number or 'N/A',
    }
end

function GetOfflinePlayerName(identifier)
    local row = MySQL.single.await('SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1', { identifier })
    if row?.firstname then
        return ('%s %s'):format(row.firstname, row.lastname or '')
    end
    return 'Unknown'
end

function GetJobPlayerCounts()
    local counts = {}
    for _, row in ipairs(MySQL.query.await('SELECT job, COUNT(*) AS count FROM users GROUP BY job') or {}) do
        if row.job and row.job ~= '' then counts[row.job] = tonumber(row.count) or 0 end
    end
    return counts
end

function GetGangPlayerCounts() return {} end

function GetFactionRoster(kind, name)
    if kind == 'gangs' then return {} end

    local roster = {}
    for _, row in ipairs(MySQL.query.await('SELECT identifier, firstname, lastname, job, job_grade FROM users WHERE job = ?', { name }) or {}) do
        local player = FormatDbPlayer(row)
        roster[#roster + 1] = { CitizenId = player.citizenId, Name = player.name, job = player.job, gang = player.gang }
    end
    return roster
end

function GetPlayerSavedSkin(identifier)
    return nil, MySQL.scalar.await('SELECT skin FROM users WHERE identifier = ?', { identifier })
end

function FetchPlayerVehicles(identifier)
    local column = getGarageColumn()
    local rows = MySQL.query.await(('SELECT plate, vehicle, stored, %s AS garage FROM owned_vehicles WHERE owner = ?'):format(column), { identifier }) or {}

    local vehicles = {}
    for _, row in ipairs(rows) do
        vehicles[#vehicles + 1] = {
            plate = row.plate,
            model = vehicleModelFromProps(row.vehicle),
            state = row.stored == 1 and 'Stored' or 'Out',
            engine = 1000,
            body = 1000,
            fuel = 100,
            garage = row.garage or 'Default',
        }
    end
    return vehicles
end

function FetchAllVehicles()
    local rows = MySQL.query.await('SELECT plate, vehicle FROM owned_vehicles') or {}
    for _, row in ipairs(rows) do row.model = vehicleModelFromProps(row.vehicle) end
    return rows
end

function IsVehicleOwned(plate)
    return MySQL.scalar.await('SELECT 1 FROM owned_vehicles WHERE plate = ?', { plate }) ~= nil
end

function RegisterVehicleToPlayer(identifier, _, plate, _, props)
    return MySQL.insert.await('INSERT INTO owned_vehicles (owner, plate, vehicle, stored) VALUES (?, ?, ?, 1)', {
        identifier, plate, json.encode(props),
    })
end

function GetVehicleMods(plate)
    return MySQL.scalar.await('SELECT vehicle FROM owned_vehicles WHERE plate = ?', { plate })
end

function GetVehicleModel(plate)
    return vehicleModelFromProps(GetVehicleMods(plate))
end

function UpdateVehicleModsAndPlate(oldPlate, newPlate, mods)
    return MySQL.update.await('UPDATE owned_vehicles SET plate = ?, vehicle = ? WHERE plate = ?', { newPlate, json.encode(mods), oldPlate }) > 0
end

function UpdateVehiclePlate(oldPlate, newPlate)
    return MySQL.update.await('UPDATE owned_vehicles SET plate = ? WHERE plate = ?', { newPlate, oldPlate }) > 0
end

function UpdateVehicleGarage(plate, garage)
    return MySQL.update.await(('UPDATE owned_vehicles SET %s = ? WHERE plate = ?'):format(getGarageColumn()), { garage, plate }) > 0
end

function UpdateVehicleState(plate, state)
    return MySQL.update.await('UPDATE owned_vehicles SET stored = ? WHERE plate = ?', { state == 'Stored' and 1 or 0, plate }) > 0
end

function DeletePlayerVehicle(plate)
    return MySQL.update.await('DELETE FROM owned_vehicles WHERE plate = ?', { plate }) > 0
end
