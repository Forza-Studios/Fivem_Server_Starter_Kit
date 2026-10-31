-- ==========================================================
-- QBCore Bridge for codem-hud
-- ==========================================================

if Config.Framework ~= "qb" then
    return
end

local function CheckQBCoreStatus()
    local resourceState = GetResourceState('qb-core')
    return resourceState == "started" or resourceState == "starting"
end

Core = {
    CoreReady = false,
}
Core.__index = Core
Core.Functions = {}

local QBCore = nil
if CheckQBCoreStatus() then
    local success, result = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if success and result then
        QBCore = result
        Core.CoreReady = true
        debugPrint('[Framework] QBCore server ready')
    else
        debugPrint('[Framework] QBCore object not found')
        return
    end
else
    debugPrint('[Framework] qb-core not started')
    return
end

-- Get player object
Core.Functions.GetPlayer = function(playerId)
    if not playerId then return nil end
    if QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
        local success, playerData = pcall(QBCore.Functions.GetPlayer, playerId)
        if success and playerData then
            return playerData
        end
    end
    return nil
end

-- Get player identifier (citizenid)
Core.Functions.GetIdentifier = function(playerId)
    if not playerId then return nil end

    if QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
        local success, playerData = pcall(QBCore.Functions.GetPlayer, playerId)
        if success and playerData and playerData.PlayerData then
            return playerData.PlayerData.citizenid or nil
        end
    end
    return nil
end

-- Get player name (supports both online playerId and offline identifier)
Core.Functions.GetName = function(playerId, identifier)
    -- Try online player first
    if playerId and QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
        local success, playerData = pcall(QBCore.Functions.GetPlayer, playerId)
        if success and playerData and playerData.PlayerData and playerData.PlayerData.charinfo then
            local firstname = playerData.PlayerData.charinfo.firstname or ""
            local lastname = playerData.PlayerData.charinfo.lastname or ""
            return (firstname .. " " .. lastname):gsub("^%l", string.upper)
        end
    end

    -- Fallback to offline lookup by identifier
    if identifier then
        local result = MySQL.single.await([[
            SELECT JSON_EXTRACT(charinfo, '$.firstname') as firstname,
                   JSON_EXTRACT(charinfo, '$.lastname') as lastname
            FROM players WHERE citizenid = ?
        ]], { identifier })

        if result and result.firstname then
            local firstname = result.firstname:gsub('"', '') or ''
            local lastname = (result.lastname and result.lastname:gsub('"', '')) or ''
            local fullname = (firstname .. ' ' .. lastname):gsub("^%s+", ""):gsub("%s+$", "")
            if fullname ~= '' then return fullname end
        end
    end

    return 'Unknown'
end

-- Get player job
Core.Functions.GetPlayerJob = function(playerId)
    if not playerId then return nil end

    if QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
        local success, playerData = pcall(QBCore.Functions.GetPlayer, playerId)
        if success and playerData and playerData.PlayerData and playerData.PlayerData.job then
            return {
                name = playerData.PlayerData.job.name or 'unemployed',
                label = playerData.PlayerData.job.label or 'Unemployed',
                onduty = playerData.PlayerData.job.onduty or false,
                grade_name = playerData.PlayerData.job.grade.name or 'unemployed',
                grade_level = playerData.PlayerData.job.grade.level or 0,
                isboss = playerData.PlayerData.job.grade.isboss or false
            }
        end
    end
    return nil
end


-- Create usable item
Core.Functions.CreateUseableItem = function(itemName, callback)
    if not itemName or not callback then return false end

    if QBCore and QBCore.Functions and QBCore.Functions.CreateUseableItem then
        QBCore.Functions.CreateUseableItem(itemName, function(source, item)
            callback(source, item)
        end)

        return true
    end

    debugPrint('[Framework] Failed to register usable item:', itemName)
    return false
end

-- Player loaded event
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src = source
    TriggerEvent('codem-hud:server:PlayerLoaded', src)
end)

-- Player unload event
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    TriggerEvent('codem-hud:server:PlayerUnloaded', src)
end)

-- Get player stress from metadata
Core.Functions.GetPlayerStress = function(playerId)
    if not playerId then return 0 end
    if not QBCore then return 0 end

    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return 0 end

    local stress = Player.PlayerData.metadata and Player.PlayerData.metadata.stress or 0
    return math.floor(stress)
end

-- Set player stress (metadata)
Core.Functions.SetPlayerStress = function(playerId, stress)
    if not playerId then return false end
    if not QBCore then return false end

    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return false end

    -- Clamp stress value
    stress = math.max(0, math.min(100, math.floor(stress or 0)))

    -- Update metadata
    Player.Functions.SetMetaData('stress', stress)
    return true
end

-- Event handler for client stress sync
RegisterNetEvent('codem-hud:server:SetStress', function(stress)
    local src = source
    if Core.Functions.SetPlayerStress then
        Core.Functions.SetPlayerStress(src, stress)
    end
end)

-- Get neon installation status from player_vehicles DB
-- Returns: true (installed), false (not installed), nil (not in DB)
Core.Functions.GetVehicleNeonInstalled = function(plate)
    if not plate then return nil end

    local result = MySQL.Sync.fetchScalar('SELECT mods FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if result == nil then return nil end

    local mods = json.decode(result)
    if not mods or type(mods) ~= 'table' or not next(mods) then return nil end

    local neonColor = mods.neonColor
    if not neonColor or type(neonColor) ~= 'table' then return false end

    local r = neonColor.r or 0
    local g = neonColor.g or 0
    local b = neonColor.b or 0

    if r == 0 and g == 0 and b == 0 then return false end
    if r == 255 and g == 0 and b == 255 then return false end
    return true
end

-- =============================================
-- SOCIETY MONEY SYSTEM
-- =============================================

-- Get society/job money for a job name
-- Supports: codem-bossmenuv2, mBossmenu, okokBanking, qb-management, qb-bossmenu, qb-banking, renewed-banking
Core.Functions.GetSocietyMoney = function(jobName)
    if not jobName or jobName == '' or jobName == 'unemployed' then return nil end

    -- Check config for specific script
    local configScript = Config.SocietyMoney and Config.SocietyMoney.Script or 'auto'

    -- Custom function handler (uses CustomGetSocietyMoney from modules/society/custom.lua)
    if configScript == 'custom' then
        if CustomGetSocietyMoney then
            local ok, result = pcall(CustomGetSocietyMoney, jobName)
            if ok then return result end
        end
        return nil
    end

    -- Direct script handler (not auto)
    if configScript ~= 'auto' then
        local handlers = {
            ['codem-bossmenuv2'] = function()
                return exports['codem-bossmenuv2']:GetMoneyJob(jobName)
            end,
            ['mBossmenu'] = function()
                return exports['mBossmenu']:GetSocietyMoney(jobName)
            end,
            ['okokBanking'] = function()
                return exports['okokBanking']:GetAccount(jobName)
            end,
            ['qb-banking'] = function()
                return exports['qb-banking']:GetAccountBalance(jobName)
            end,
            ['renewed-banking'] = function()
                return exports['renewed-banking']:getAccountMoney(jobName)
            end,
            ['g-boss-menu'] = function()
                return exports['g-boss-menu']:GetSocietyMoney(jobName)
            end,
        }

        if handlers[configScript] then
            local ok, result = pcall(handlers[configScript])
            if ok and result then return result end
        end
        return nil
    end

    -- Auto-detect mode: try scripts in order
    local tryOrder = {
        { resource = 'codem-bossmenuv2', fn = function() return exports['codem-bossmenuv2']:GetMoneyJob(jobName) end },
        { resource = 'mBossmenu', fn = function() return exports['mBossmenu']:GetSocietyMoney(jobName) end },
        { resource = 'okokBanking', fn = function() return exports['okokBanking']:GetAccount(jobName) end },
        { resource = 'qb-banking', fn = function() return exports['qb-banking']:GetAccountBalance(jobName) end },
        { resource = 'qb-management', fn = function() return exports['qb-management']:GetAccount(jobName) end },
        { resource = 'renewed-banking', fn = function() return exports['renewed-banking']:getAccountMoney(jobName) end },
        { resource = 'g-boss-menu', fn = function() return exports['g-boss-menu']:GetSocietyMoney(jobName) end },
    }

    for _, handler in ipairs(tryOrder) do
        if GetResourceState(handler.resource) == 'started' then
            local ok, result = pcall(handler.fn)
            if ok and result then
                return result
            end
        end
    end

    -- Direct DB fallback: query bank_accounts table
    local ok, result = pcall(MySQL.Sync.fetchScalar, 'SELECT account_balance FROM bank_accounts WHERE account_name = ? LIMIT 1', { jobName })
    if ok and result then return result end

    return nil
end
