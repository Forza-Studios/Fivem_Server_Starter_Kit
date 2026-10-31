-- ==========================================================
-- ESX Bridge for codem-hud
-- ==========================================================

if Config.Framework ~= "esx" then
    return
end

local function CheckESXStatus()
    local state = GetResourceState('es_extended')
    return state == "started" or state == "starting"
end

Core = {
    CoreReady = false,
}
Core.__index = Core
Core.Functions = {}

if not CheckESXStatus() then
    -- Wait for es_extended to start (max 15s)
    local waited = 0
    while not CheckESXStatus() and waited < 15000 do
        Wait(500)
        waited = waited + 500
    end
    if not CheckESXStatus() then
        debugPrint('[Framework] es_extended not started after 15s')
        return
    end
end

Core.CoreReady = true

local ESX = nil
local ok, res = pcall(function() return exports['es_extended']:getSharedObject() end)
if ok and res then
    ESX = res
    debugPrint('[Framework] ESX server ready (with SharedObject)')
else
    debugPrint('[Framework] ESX server ready (export mode)')
end

local function getXPlayer(playerId)
    if not playerId then return nil end
    if ESX and ESX.GetPlayerFromId then
        return ESX.GetPlayerFromId(playerId)
    end
    local s, player = pcall(function() return exports['es_extended']:getPlayerFromId(playerId) end)
    if s and player then return player end
    return nil
end

-- Get player object
Core.Functions.GetPlayer = function(playerId)
    return getXPlayer(playerId)
end

-- Get player identifier
Core.Functions.GetIdentifier = function(playerId)
    if not playerId then return nil end

    local xPlayer = getXPlayer(playerId)
    if xPlayer then
        return xPlayer.identifier
    end
    return nil
end

-- Get player name (supports both online playerId and offline identifier)
Core.Functions.GetName = function(playerId, identifier)
    -- Try online player first
    if playerId then
        local xPlayer = getXPlayer(playerId)
        if xPlayer then
            return xPlayer.getName() or 'Unknown'
        end
    end

    -- Fallback to offline lookup by identifier
    if identifier then
        local result = MySQL.single.await([[
            SELECT firstname, lastname FROM users WHERE identifier = ?
        ]], { identifier })

        if result and result.firstname then
            local fullname = ((result.firstname or '') .. ' ' .. (result.lastname or '')):gsub("^%s+", ""):gsub("%s+$", "")
            if fullname ~= '' then return fullname end
        end
    end

    return 'Unknown'
end

-- Get player job
Core.Functions.GetPlayerJob = function(playerId)
    if not playerId then return nil end

    local xPlayer = getXPlayer(playerId)
    if xPlayer then
        local job = xPlayer.getJob()
        if job then
            return {
                name = job.name or 'unemployed',
                label = job.label or 'Unemployed',
                onduty = true,
                grade_name = job.grade_label or 'Unknown',
                grade_level = job.grade or 0,
                isboss = job.grade_name == 'boss'
            }
        end
    end
    return nil
end



-- Player loaded event
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    TriggerEvent('codem-hud:server:PlayerLoaded', playerId)
end)

-- Player logout event
AddEventHandler('esx:playerDropped', function(playerId)
    TriggerEvent('codem-hud:server:PlayerUnloaded', playerId)
end)

-- Get neon installation status from owned_vehicles DB
-- Returns: true (installed), false (not installed), nil (not in DB)
Core.Functions.GetVehicleNeonInstalled = function(plate)
    if not plate then return nil end

    local result = MySQL.Sync.fetchScalar('SELECT vehicle FROM owned_vehicles WHERE plate = ? LIMIT 1', { plate })
    if result == nil then return nil end

    local props = json.decode(result)
    if not props or type(props) ~= 'table' or not next(props) then return nil end

    local r, g, b = 0, 0, 0
    if props.neonColor and type(props.neonColor) == 'table' then
        r = props.neonColor.r or 0
        g = props.neonColor.g or 0
        b = props.neonColor.b or 0
    else
        r = props.neonR or 0
        g = props.neonG or 0
        b = props.neonB or 0
    end

    if r == 0 and g == 0 and b == 0 then return false end
    if r == 255 and g == 0 and b == 255 then return false end
    return true
end

-- Stress tracking for ESX (with database persistence)
local playerStress = {}

-- Load stress from database on player load
local function LoadPlayerStress(playerId, identifier)
    if not identifier then return end

    MySQL.Async.fetchScalar('SELECT stress FROM codem_hud_player_stress WHERE identifier = ?', { identifier }, function(stress)
        if stress then
            playerStress[playerId] = stress
            TriggerClientEvent('hud:client:UpdateStress', playerId, stress)
        else
            playerStress[playerId] = 0
            -- Insert default record
            MySQL.Async.execute('INSERT IGNORE INTO codem_hud_player_stress (identifier, stress) VALUES (?, 0)', { identifier })
        end
    end)
end

-- Save stress to database
local function SavePlayerStress(playerId, identifier, stress)
    if not identifier then return end
    MySQL.Async.execute('INSERT INTO codem_hud_player_stress (identifier, stress) VALUES (?, ?) ON DUPLICATE KEY UPDATE stress = ?',
        { identifier, stress, stress })
end

-- Set player stress (ESX - with database persistence)
Core.Functions.SetPlayerStress = function(playerId, stress)
    if not playerId then return false end

    -- Clamp stress value
    stress = math.max(0, math.min(100, math.floor(stress or 0)))

    -- Store in memory
    playerStress[playerId] = stress

    -- Get identifier and save to database
    local xPlayer = getXPlayer(playerId)
    if xPlayer then
        SavePlayerStress(playerId, xPlayer.identifier, stress)
    end

    -- Notify client
    TriggerClientEvent('hud:client:UpdateStress', playerId, stress)
    return true
end

-- Get player stress
Core.Functions.GetPlayerStress = function(playerId)
    return playerStress[playerId] or 0
end

-- Load stress when player loads
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    if xPlayer and xPlayer.identifier then
        LoadPlayerStress(playerId, xPlayer.identifier)
    end
end)

-- Clean up on player drop (stress is already saved to DB)
AddEventHandler('esx:playerDropped', function(playerId)
    playerStress[playerId] = nil
end)

-- Event handler for client stress sync
RegisterNetEvent('codem-hud:server:SetStress', function(stress)
    local src = source
    if Core.Functions.SetPlayerStress then
        Core.Functions.SetPlayerStress(src, stress)
    end
end)

-- =============================================
-- SOCIETY MONEY SYSTEM
-- =============================================

-- Get society/job money for a job name
-- Supports: codem-bossmenuv2, mBossmenu, esx_addonaccount, esx_society, okokBanking, renewed-banking, custom
-- Compatible with both old (callback/event) and new (export) versions
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

    -- Helper: Try export first, fallback to callback for esx_addonaccount
    local function getAddonAccountMoney()
        -- Try new export method first
        local ok, result = pcall(function()
            local account = exports['esx_addonaccount']:GetSharedAccount('society_' .. jobName)
            return account and account.money or nil
        end)
        if ok and result then return result end

        -- Fallback: Old callback method (TriggerEvent with callback)
        local money = nil
        local p = promise.new()
        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. jobName, function(account)
            money = account and account.money or nil
            p:resolve(money)
        end)
        -- Wait max 100ms for callback
        SetTimeout(100, function() p:resolve(nil) end)
        return Citizen.Await(p)
    end

    -- Helper: Try export first, fallback to callback for esx_society
    local function getSocietyMoney()
        -- Try new export method first
        local ok, result = pcall(function()
            local society = exports['esx_society']:GetSociety(jobName)
            return society and society.account or nil
        end)
        if ok and result then return result end

        -- Fallback: Old callback method
        local money = nil
        local p = promise.new()
        TriggerEvent('esx_society:getSociety', jobName, function(society)
            money = society and society.account or nil
            p:resolve(money)
        end)
        -- Wait max 100ms for callback
        SetTimeout(100, function() p:resolve(nil) end)
        return Citizen.Await(p)
    end

    -- Direct script handler (not auto)
    if configScript ~= 'auto' then
        local handlers = {
            -- Universal (work with ESX too)
            ['codem-bossmenuv2'] = function()
                return exports['codem-bossmenuv2']:GetMoneyJob(jobName)
            end,
            ['mBossmenu'] = function()
                return exports['mBossmenu']:GetSocietyMoney(jobName)
            end,
            ['okokBanking'] = function()
                return exports['okokBanking']:GetAccount(jobName)
            end,
            ['renewed-banking'] = function()
                return exports['renewed-banking']:getAccountMoney(jobName)
            end,
            ['g-boss-menu'] = function()
                return exports['g-boss-menu']:GetSocietyMoney(jobName)
            end,
            -- ESX specific (with callback fallback)
            ['esx_addonaccount'] = getAddonAccountMoney,
            ['esx_society'] = getSocietyMoney,
        }

        if handlers[configScript] then
            local ok, result = pcall(handlers[configScript])
            if ok and result then return result end
        end
        return nil
    end

    -- Auto-detect mode: try scripts in order (universal first, then ESX specific)
    local tryOrder = {
        { resource = 'codem-bossmenuv2', fn = function() return exports['codem-bossmenuv2']:GetMoneyJob(jobName) end },
        { resource = 'mBossmenu', fn = function() return exports['mBossmenu']:GetSocietyMoney(jobName) end },
        { resource = 'okokBanking', fn = function() return exports['okokBanking']:GetAccount(jobName) end },
        { resource = 'renewed-banking', fn = function() return exports['renewed-banking']:getAccountMoney(jobName) end },
        { resource = 'g-boss-menu', fn = function() return exports['g-boss-menu']:GetSocietyMoney(jobName) end },
        { resource = 'esx_addonaccount', fn = getAddonAccountMoney },
        { resource = 'esx_society', fn = getSocietyMoney },
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
