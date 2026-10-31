-- ==========================================================
-- vRP Bridge (Server) for codem-supreme-hud
-- ==========================================================

if Config.Framework ~= "vrp" then return end

local function CheckVRPStatus()
    local state = GetResourceState('vrp')
    return state == "started" or state == "starting"
end

if not CheckVRPStatus() then
    local waited = 0
    while not CheckVRPStatus() and waited < 15000 do
        Wait(500)
        waited = waited + 500
    end
    if not CheckVRPStatus() then
        -- debugPrint('[Framework] vrp not started after 15s')
        return
    end
end

-- Load vRP Proxy via module() (provided by @vrp/lib/utils.lua)
local Proxy = module("vrp", "lib/Proxy")

-- Get vRP proxy interface (only has loadScript)
local vRPProxy = Proxy.getInterface("vRP")

-- Inject our bridge code into vRP's Lua context
Citizen.CreateThread(function()
    Wait(2000) -- Wait for vRP to fully initialize
    -- debugPrint('[Framework] Loading vRP bridge inject...')
    local ok, err = pcall(function()
        vRPProxy.loadScript("codem-supreme-hud", "modules/framework/vrp/server/bridge_inject")
    end)
    if ok then
        -- debugPrint('[Framework] vRP bridge inject loaded successfully')
        -- Send survival config to inject (it runs in vRP context, can't read Config directly)
        if Config.VRPSurvival then
            TriggerEvent("codem-hud:vrp:survivalConfig", Config.VRPSurvival)
        end
    else
    end
end)

-- Get the bridge proxy interface (available after inject loads)
local hudBridge = nil
Citizen.CreateThread(function()
    Wait(4000) -- Wait for inject to register
    hudBridge = Proxy.getInterface("vRP.codem_hud")
    -- debugPrint('[Framework] vRP hudBridge proxy connected')
end)

-- ═══════════════════════════════════════════════════════════════
-- Core.Functions (standard HUD server bridge interface)
-- ═══════════════════════════════════════════════════════════════

Core = {
    CoreReady = false,
}
Core.__index = Core
Core.Functions = {}

Citizen.CreateThread(function()
    Wait(5000)
    Core.CoreReady = true
    -- debugPrint('[Framework] vRP server ready')
end)

-- Get player (returns user_id or nil)
Core.Functions.GetPlayer = function(playerId)
    if not playerId or not hudBridge then return nil end
    local ok, userId = pcall(function() return hudBridge.getUserId(playerId) end)
    if ok and userId then return userId end
    return nil
end

-- Get player identifier (vRP user_id as string)
Core.Functions.GetIdentifier = function(playerId)
    if not playerId or not hudBridge then return nil end
    local ok, userId = pcall(function() return hudBridge.getUserId(playerId) end)
    if ok and userId then return tostring(userId) end
    return nil
end

-- Get player name
Core.Functions.GetName = function(playerId, identifier)
    if not playerId then return 'Unknown' end

    if hudBridge then
        local ok, firstname, lastname = pcall(function() return hudBridge.getUserIdentity(playerId) end)
        if ok and firstname then
            local fullname = ((firstname or '') .. ' ' .. (lastname or '')):gsub("^%s+", ""):gsub("%s+$", "")
            if fullname ~= '' then return fullname end
        end
    end

    -- Fallback to offline lookup
    if identifier then
        local result = MySQL.single.await([[
            SELECT firstname, lastname FROM vrp_character_identities
            WHERE character_id IN (
                SELECT id FROM vrp_characters WHERE user_id = ?
            ) LIMIT 1
        ]], { tonumber(identifier) })

        if result and result.firstname then
            local fullname = ((result.firstname or '') .. ' ' .. (result.lastname or '')):gsub("^%s+", ""):gsub("%s+$", "")
            if fullname ~= '' then return fullname end
        end
    end

    return GetPlayerName(playerId) or 'Unknown'
end

-- Get player job
Core.Functions.GetPlayerJob = function(playerId)
    if not playerId or not hudBridge then return nil end

    local ok, jobName, jobTitle = pcall(function() return hudBridge.getUserJob(playerId) end)
    if ok and jobName then
        return {
            name = jobName or 'citizen',
            label = jobTitle or 'Citizen',
            onduty = true,
            grade_name = '',
            grade_level = 0,
            isboss = false
        }
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- STRESS SYSTEM (with DB persistence, same pattern as ESX bridge)
-- ═══════════════════════════════════════════════════════════════

local playerStress = {}

local function LoadPlayerStress(playerId, identifier)
    if not identifier then return end

    MySQL.Async.fetchScalar('SELECT stress FROM codem_hud_player_stress WHERE identifier = ?', { identifier }, function(stress)
        if stress then
            playerStress[playerId] = stress
            TriggerClientEvent('hud:client:UpdateStress', playerId, stress)
        else
            playerStress[playerId] = 0
            MySQL.Async.execute('INSERT IGNORE INTO codem_hud_player_stress (identifier, stress) VALUES (?, 0)', { identifier })
        end
    end)
end

local function SavePlayerStress(playerId, identifier, stress)
    if not identifier then return end
    MySQL.Async.execute('INSERT INTO codem_hud_player_stress (identifier, stress) VALUES (?, ?) ON DUPLICATE KEY UPDATE stress = ?',
        { identifier, stress, stress })
end

Core.Functions.GetPlayerStress = function(playerId)
    return playerStress[playerId] or 0
end

Core.Functions.SetPlayerStress = function(playerId, stress)
    if not playerId then return false end

    stress = math.max(0, math.min(100, math.floor(stress or 0)))
    playerStress[playerId] = stress

    -- Get identifier and save
    local identifier = Core.Functions.GetIdentifier(playerId)
    if identifier then
        SavePlayerStress(playerId, identifier, stress)
    end

    TriggerClientEvent('hud:client:UpdateStress', playerId, stress)
    return true
end

-- Event handler for client stress sync
RegisterNetEvent('codem-hud:server:SetStress', function(stress)
    local src = source
    if Core.Functions.SetPlayerStress then
        Core.Functions.SetPlayerStress(src, stress)
    end
end)

-- Player loaded: load stress
AddEventHandler('codem-hud:server:PlayerLoaded', function(src)
    local identifier = Core.Functions.GetIdentifier(src)
    if identifier then
        LoadPlayerStress(src, identifier)
    end
end)

-- Player unloaded: cleanup
AddEventHandler('codem-hud:server:PlayerUnloaded', function(src)
    playerStress[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerStress[src] = nil
end)

-- ═══════════════════════════════════════════════════════════════
-- SOCIETY MONEY SYSTEM
-- ═══════════════════════════════════════════════════════════════

Core.Functions.GetSocietyMoney = function(jobName)
    if not jobName or jobName == '' or jobName == 'citizen' then return nil end

    local configScript = Config.SocietyMoney and Config.SocietyMoney.Script or 'auto'

    if configScript == 'custom' then
        if CustomGetSocietyMoney then
            local ok, result = pcall(CustomGetSocietyMoney, jobName)
            if ok then return result end
        end
        return nil
    end

    local handlers = {
        ['codem-bossmenuv2'] = function() return exports['codem-bossmenuv2']:GetMoneyJob(jobName) end,
        ['mBossmenu'] = function() return exports['mBossmenu']:GetSocietyMoney(jobName) end,
        ['okokBanking'] = function() return exports['okokBanking']:GetAccount(jobName) end,
        ['renewed-banking'] = function() return exports['renewed-banking']:getAccountMoney(jobName) end,
        ['g-boss-menu'] = function() return exports['g-boss-menu']:GetSocietyMoney(jobName) end,
    }

    if configScript ~= 'auto' then
        if handlers[configScript] then
            local ok, result = pcall(handlers[configScript])
            if ok and result then return result end
        end
        return nil
    end

    -- Auto-detect
    local tryOrder = {
        { resource = 'codem-bossmenuv2', fn = handlers['codem-bossmenuv2'] },
        { resource = 'mBossmenu', fn = handlers['mBossmenu'] },
        { resource = 'okokBanking', fn = handlers['okokBanking'] },
        { resource = 'renewed-banking', fn = handlers['renewed-banking'] },
        { resource = 'g-boss-menu', fn = handlers['g-boss-menu'] },
    }

    for _, handler in ipairs(tryOrder) do
        if GetResourceState(handler.resource) == 'started' then
            local ok, result = pcall(handler.fn)
            if ok and result then return result end
        end
    end

    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- VEHICLE NEON (not applicable for vRP default)
-- ═══════════════════════════════════════════════════════════════

Core.Functions.GetVehicleNeonInstalled = function(plate)
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- USEABLE ITEMS (vRP doesn't use this pattern)
-- ═══════════════════════════════════════════════════════════════

Core.Functions.CreateUseableItem = function(itemName, callback)
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- CLIENT DATA REQUEST (for resource restart fallback)
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('codem-hud:vrp:requestData', function()
    local src = source
    if not hudBridge then return end

    local ok, result = pcall(function() return hudBridge.requestPlayerData(src) end)
    if not ok or not result then
        -- Bridge might not be ready yet, try manually
        local userId = Core.Functions.GetIdentifier(src)
        if userId then
            local name = Core.Functions.GetName(src, userId)
            local job = Core.Functions.GetPlayerJob(src)
            TriggerClientEvent('codem-hud:vrp:requestDataResponse', src, {
                name = name or 'Unknown',
                identifier = userId,
                wallet = 0,
                bank = 0,
                jobName = job and job.name or 'citizen',
                jobTitle = job and job.label or 'Citizen'
            })
        end
    end
end)

-- debugPrint('[Framework] vRP server bridge loaded')
