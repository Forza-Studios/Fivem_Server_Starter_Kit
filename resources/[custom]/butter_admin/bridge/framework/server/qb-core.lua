if not UseBridge('framework', 'qb-core') then return end

local QBCore = exports['qb-core']:GetCoreObject()

DatabaseTables = {
    players = 'players',
    playerId = 'citizenid',
    playerLicense = 'license',
    vehicles = 'player_vehicles',
}

local VEHICLE_STATES = { [0] = 'Out', [1] = 'Stored', [2] = 'Impounded' }
local VEHICLE_STATE_IDS = { Out = 0, Stored = 1, Impounded = 2 }

---@param value any
---@return table
local function decode(value)
    return DecodeJson(value, {})
end

---@param source number
---@return table?
function GetPlayer(source)
    return QBCore.Functions.GetPlayer(source)
end

---@param source number
---@return table|false
function GetPlayerData(source)
    local player = GetPlayer(source)
    if not player then return false end

    local data = player.PlayerData
    local charinfo = data.charinfo or {}
    local money = data.money or {}

    return {
        source = data.source,
        citizenId = data.citizenid,
        license = data.license,
        name = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''),
        charinfo = charinfo,
        money = { cash = money.cash or 0, bank = money.bank or 0, crypto = money.crypto or 0 },
        job = data.job,
        gang = data.gang,
    }
end

---@param citizenId string
---@return number?
function GetSourceByCitizenId(citizenId)
    local player = QBCore.Functions.GetPlayerByCitizenId(citizenId)
    return player?.PlayerData.source
end

---@param source number
---@return boolean
function HasFrameworkPermission(source)
    return IsPlayerAceAllowed(source, 'butter_admin.admin')
        or QBCore.Functions.HasPermission(source, 'god')
        or QBCore.Functions.HasPermission(source, 'admin')
end

---@return string[]
function GetMoneyTypes()
    return { 'bank', 'cash', 'crypto' }
end

function AddMoney(source, moneyType, amount, reason)
    local player = GetPlayer(source)
    if not player then return false end

    return player.Functions.AddMoney(moneyType, amount, reason) ~= false
end

function SetMoney(source, moneyType, amount, reason)
    local player = GetPlayer(source)
    if not player then return false end

    return player.Functions.SetMoney(moneyType, amount, reason) ~= false
end

function SetPlayerMetadata(source, key, value)
    local player = GetPlayer(source)
    if not player then return end

    player.Functions.SetMetaData(key, value)
end

function SavePlayer(source)
    local player = GetPlayer(source)
    if player then player.Functions.Save() end
end

---@param source number
---@return boolean?
function ToggleJobDuty(source)
    local player = GetPlayer(source)
    local job = player?.PlayerData.job
    if not job then return nil end

    local onDuty = not job.onduty
    player.Functions.SetJobDuty(onDuty)
    return onDuty
end

--- `target` is a server ID or, for offline players, a citizen ID.
---@param column 'job'|'gang'
local function setFaction(column, target, name, grade)
    local player = type(target) == 'number' and GetPlayer(target) or QBCore.Functions.GetPlayerByCitizenId(target)
    if player then
        if column == 'job' then
            player.Functions.SetJob(name, grade)
        else
            player.Functions.SetGang(name, grade)
        end
        return
    end

    local payload = json.encode({ name = name, grade = { level = grade } })
    MySQL.update.await(('UPDATE players SET %s = ? WHERE citizenid = ?'):format(column), { payload, target })
end

function SetJob(target, job, grade) setFaction('job', target, job, grade) end
function SetGang(target, gang, grade) setFaction('gang', target, gang, grade) end

function GetJobs() return QBCore.Shared.Jobs end
function GetGangs() return QBCore.Shared.Gangs end
function GetVehicles() return QBCore.Shared.Vehicles end
function GetFrameworkItems() return QBCore.Shared.Items end

function FormatDbPlayer(row)
    if not row then return nil end
    local charinfo = decode(row.charinfo)
    local money = decode(row.money)

    return {
        citizenId = row.citizenid,
        license = row.license,
        name = charinfo.firstname and ('%s %s'):format(charinfo.firstname, charinfo.lastname or '') or row.name or 'Unknown',
        steam = row.steam or row.license or 'Not Linked',
        cash = money.cash or 0,
        bank = money.bank or 0,
        crypto = money.crypto or 0,
        job = decode(row.job),
        gang = decode(row.gang),
        dob = charinfo.birthdate or 'Unknown',
        bloodgroup = charinfo.bloodtype or 'N/A',
        phone = charinfo.phone or 'N/A',
    }
end

function GetOfflinePlayerName(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return 'Unknown' end

    local prefix = identifier:match('^(%w+):')
    local row
    if not prefix then
        row = MySQL.single.await('SELECT charinfo, name FROM players WHERE citizenid = ? LIMIT 1', { identifier })
    elseif prefix == 'license' or prefix == 'license2' then
        row = MySQL.single.await('SELECT charinfo, name FROM players WHERE license = ? LIMIT 1', { identifier })
    end
    if not row then return 'Unknown' end

    local charinfo = decode(row.charinfo)
    if charinfo.firstname or charinfo.lastname then
        return ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
    end
    return row.name or 'Unknown'
end

local function countByFaction(column)
    local rows = MySQL.query.await(("SELECT JSON_VALUE(%s, '$.name') AS faction, COUNT(*) AS count FROM players GROUP BY faction"):format(column)) or {}
    local counts = {}
    for _, row in ipairs(rows) do
        if row.faction then counts[row.faction] = tonumber(row.count) or 0 end
    end
    return counts
end

function GetJobPlayerCounts() return countByFaction('job') end
function GetGangPlayerCounts() return countByFaction('gang') end

function GetFactionRoster(kind, name)
    local column = kind == 'gangs' and 'gang' or 'job'
    local rows = MySQL.query.await(("SELECT citizenid, name, charinfo, job, gang FROM players WHERE JSON_VALUE(%s, '$.name') = ?"):format(column), { name }) or {}

    local roster = {}
    for _, row in ipairs(rows) do
        local player = FormatDbPlayer(row)
        roster[#roster + 1] = { CitizenId = player.citizenId, Name = player.name, job = player.job, gang = player.gang }
    end
    return roster
end

function GetPlayerSavedSkin(citizenId)
    local row = MySQL.single.await('SELECT model, skin FROM playerskins WHERE citizenid = ? AND active = 1', { citizenId })
    if row then return row.model, row.skin end
end

function FetchPlayerVehicles(citizenId, license)
    local rows = MySQL.query.await('SELECT plate, vehicle, state, engine, body, fuel, garage FROM player_vehicles WHERE citizenid = ? OR license = ?', { citizenId, license }) or {}

    local vehicles = {}
    for _, row in ipairs(rows) do
        vehicles[#vehicles + 1] = {
            plate = row.plate,
            model = row.vehicle,
            state = VEHICLE_STATES[row.state] or 'Out',
            engine = row.engine or 1000,
            body = row.body or 1000,
            fuel = row.fuel or 100,
            garage = row.garage or 'Default',
        }
    end
    return vehicles
end

function FetchAllVehicles()
    local rows = MySQL.query.await('SELECT plate, vehicle FROM player_vehicles') or {}
    for _, row in ipairs(rows) do row.model = row.vehicle end
    return rows
end

function IsVehicleOwned(plate)
    return MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ?', { plate }) ~= nil
end

function RegisterVehicleToPlayer(citizenId, license, plate, model, props)
    return MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?, 1)', {
        license, citizenId, model, joaat(model), json.encode(props), plate,
    })
end

function GetVehicleMods(plate)
    return MySQL.scalar.await('SELECT mods FROM player_vehicles WHERE plate = ?', { plate })
end

function GetVehicleModel(plate)
    return MySQL.scalar.await('SELECT vehicle FROM player_vehicles WHERE plate = ?', { plate })
end

function UpdateVehicleModsAndPlate(oldPlate, newPlate, mods)
    return MySQL.update.await('UPDATE player_vehicles SET plate = ?, mods = ? WHERE plate = ?', { newPlate, json.encode(mods), oldPlate }) > 0
end

function UpdateVehiclePlate(oldPlate, newPlate)
    return MySQL.update.await('UPDATE player_vehicles SET plate = ? WHERE plate = ?', { newPlate, oldPlate }) > 0
end

function UpdateVehicleGarage(plate, garage)
    return MySQL.update.await('UPDATE player_vehicles SET garage = ? WHERE plate = ?', { garage, plate }) > 0
end

function UpdateVehicleState(plate, state)
    return MySQL.update.await('UPDATE player_vehicles SET state = ? WHERE plate = ?', { VEHICLE_STATE_IDS[state] or 0, plate }) > 0
end

function DeletePlayerVehicle(plate)
    return MySQL.update.await('DELETE FROM player_vehicles WHERE plate = ?', { plate }) > 0
end
