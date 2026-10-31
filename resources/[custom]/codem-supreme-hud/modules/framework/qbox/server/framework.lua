-- ==========================================================
-- QBox Bridge for codem-hud
-- ==========================================================

if Config.Framework ~= "qbox" then
    return
end

local function CheckQBoxStatus()
    local resourceState = GetResourceState('qbx_core')
    return resourceState == "started" or resourceState == "starting"
end

if not CheckQBoxStatus() then
    debugPrint('[Framework] qbx_core not started')
    return
end

Core = {
    CoreReady = true,
}
Core.__index = Core
Core.Functions = {}

local QBX = nil
local success, result = pcall(function() return exports['qbx_core']:GetCoreObject() end)
if success and result then
    QBX = result
    debugPrint('[Framework] QBox server ready (with CoreObject)')
else
    debugPrint('[Framework] QBox server ready (export mode)')
end

local function GetQBXPlayer(playerId)
    if QBX and QBX.Functions and QBX.Functions.GetPlayer then
        local ok, player = pcall(QBX.Functions.GetPlayer, playerId)
        if ok and player then return player end
    end
    local ok, player = pcall(function() return exports['qbx_core']:GetPlayer(playerId) end)
    if ok and player then return player end
    return nil
end

-- Get player object
Core.Functions.GetPlayer = function(playerId)
    if not playerId then return nil end
    return GetQBXPlayer(playerId)
end

Core.Functions.GetIdentifier = function(playerId)
    if not playerId then return nil end
    local player = GetQBXPlayer(playerId)
    if player and player.PlayerData then
        return player.PlayerData.citizenid or nil
    end
    return nil
end

Core.Functions.GetName = function(playerId, identifier)
    if playerId then
        local player = GetQBXPlayer(playerId)
        if player and player.PlayerData and player.PlayerData.charinfo then
            local firstname = player.PlayerData.charinfo.firstname or ""
            local lastname = player.PlayerData.charinfo.lastname or ""
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
    local player = GetQBXPlayer(playerId)
    if player and player.PlayerData and player.PlayerData.job then
        local job = player.PlayerData.job
        local grade = job.grade or {}
        return {
            name = job.name or 'unemployed',
            label = job.label or 'Unemployed',
            onduty = job.onduty or false,
            grade_name = grade.name or 'unemployed',
            grade_level = grade.level or 0,
            isboss = grade.isboss or false
        }
    end
    return nil
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

-- Set player stress (metadata)
Core.Functions.SetPlayerStress = function(playerId, stress)
    if not playerId then return false end

    local Player = GetQBXPlayer(playerId)
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
            ['qb-management'] = function()
                return exports['qb-management']:GetAccount(jobName)
            end,
            ['qb-bossmenu'] = function()
                return exports['qb-bossmenu']:GetAccount(jobName)
            end,
            ['qb-banking'] = function()
                return exports['qb-banking']:GetAccountBalance(jobName)
            end,
            ['renewed-banking'] = function()
                return exports['renewed-banking']:getAccountMoney(jobName)
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
        { resource = 'qb-management', fn = function() return exports['qb-management']:GetAccount(jobName) end },
        { resource = 'qb-bossmenu', fn = function() return exports['qb-bossmenu']:GetAccount(jobName) end },
        { resource = 'qb-banking', fn = function() return exports['qb-banking']:GetAccountBalance(jobName) end },
        { resource = 'renewed-banking', fn = function() return exports['renewed-banking']:getAccountMoney(jobName) end },
    }

    for _, handler in ipairs(tryOrder) do
        if GetResourceState(handler.resource) == 'started' then
            local ok, result = pcall(handler.fn)
            if ok and result then
                return result
            end
        end
    end

    return nil
end
