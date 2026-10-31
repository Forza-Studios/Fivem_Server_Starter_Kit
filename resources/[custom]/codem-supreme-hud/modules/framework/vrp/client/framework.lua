-- ==========================================================
-- vRP Bridge (Client) for codem-supreme-hud
-- ==========================================================

if Config.Framework ~= "vrp" then return end

Core = nil -- No client-side core object for vRP

local PlayerLoadedTriggered = false

-- Client-side cache (populated from server events)
local cachedData = {
    name = "Unknown",
    identifier = nil,
    wallet = 0,
    bank = 0,
    jobName = "citizen",
    jobTitle = "Citizen"
}

local cachedStress = 0
local cachedNeeds = { hunger = 100, thirst = 100 }

-- Track previous money for delta detection
local lastWallet = -1
local lastBank = -1

-- debugPrint('[Framework] vRP client bridge loading...')

-- ═══════════════════════════════════════════════════════════════
-- PLAYER LOADED / UNLOADED
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('codem-hud:vrp:playerLoaded', function(data)
    if not data then return end

    cachedData.name = data.name or "Unknown"
    cachedData.identifier = data.identifier or nil
    cachedData.wallet = data.wallet or 0
    cachedData.bank = data.bank or 0
    cachedData.jobName = data.jobName or "citizen"
    cachedData.jobTitle = data.jobTitle or "Citizen"

    lastWallet = cachedData.wallet
    lastBank = cachedData.bank

    -- debugPrint('[Framework] vRP player loaded - ' .. cachedData.name)

    if not PlayerLoadedTriggered then
        PlayerLoadedTriggered = true
        Wait(100)
        TriggerEvent('codem-hud:client:PlayerLoaded')
    end
end)

RegisterNetEvent('codem-hud:vrp:playerUnloaded', function()
    cachedData.name = "Unknown"
    cachedData.identifier = nil
    cachedData.wallet = 0
    cachedData.bank = 0
    cachedData.jobName = "citizen"
    cachedData.jobTitle = "Citizen"
    lastWallet = -1
    lastBank = -1
    cachedStress = 0
    PlayerLoadedTriggered = false
    TriggerEvent('codem-hud:client:PlayerUnloaded')
end)

-- Fallback: if player is already spawned (e.g. resource restart)
CreateThread(function()
    Wait(5000)
    if PlayerLoadedTriggered then return end
    -- Request data from server
    TriggerServerEvent('codem-hud:vrp:requestData')
end)

RegisterNetEvent('codem-hud:vrp:requestDataResponse', function(data)
    if PlayerLoadedTriggered then return end
    if data then
        cachedData.name = data.name or "Unknown"
        cachedData.identifier = data.identifier or nil
        cachedData.wallet = data.wallet or 0
        cachedData.bank = data.bank or 0
        cachedData.jobName = data.jobName or "citizen"
        cachedData.jobTitle = data.jobTitle or "Citizen"
        lastWallet = cachedData.wallet
        lastBank = cachedData.bank
        PlayerLoadedTriggered = true
        TriggerEvent('codem-hud:client:PlayerLoaded')
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- MONEY UPDATES
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('codem-hud:vrp:moneyUpdate', function(wallet, bank, moneyType, changeAmount, isMinus)
    cachedData.wallet = wallet or 0
    cachedData.bank = bank or 0

    if UpdateMoney then
        UpdateMoney(cachedData.wallet, cachedData.bank, 0, nil, moneyType, changeAmount, isMinus)
    end

    lastWallet = cachedData.wallet
    lastBank = cachedData.bank
end)

-- ═══════════════════════════════════════════════════════════════
-- JOB UPDATES
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('codem-hud:vrp:jobUpdate', function(jobName, jobTitle)
    cachedData.jobName = jobName or "citizen"
    cachedData.jobTitle = jobTitle or "Citizen"

    if UpdateJob then
        UpdateJob(cachedData.jobName, cachedData.jobTitle, '')
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- GLOBAL FUNCTIONS (required by HUD core)
-- ═══════════════════════════════════════════════════════════════

function GetPlayerData()
    return {
        money = {
            cash = cachedData.wallet,
            bank = cachedData.bank
        },
        accounts = {
            { name = 'money', money = cachedData.wallet },
            { name = 'bank', money = cachedData.bank }
        },
        identifier = cachedData.identifier
    }
end

function GetPlayerInfo()
    return {
        name = cachedData.name,
        id = GetPlayerServerId(PlayerId())
    }
end

function GetPlayerJob()
    return {
        name = cachedData.jobName,
        label = cachedData.jobTitle,
        onduty = true,
        grade = 0,
        gradeLabel = ''
    }
end

function GetPlayerNeeds()
    return cachedNeeds
end

function GetPlayerStress()
    return cachedStress
end

function SetPlayerStress(stress)
    TriggerServerEvent('codem-hud:server:SetStress', stress)
end

function GetPlayerIdentifier()
    return cachedData.identifier
end

function Notify(message, type)
    local notifConfig = Config.Notification or {}
    local system = notifConfig.System or 'framework'

    if system == 'ox' then
        pcall(function() exports['ox_lib']:notify({ description = message, type = type }) end)
    elseif system == 'custom' and notifConfig.Custom then
        notifConfig.Custom(message, type)
    else
        TriggerEvent('chat:addMessage', {
            args = { 'HUD', message }
        })
    end
end

function CanInteract()
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- STRESS & NEEDS LISTENERS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('hud:client:UpdateStress', function(stress)
    cachedStress = math.floor(stress or 0)
    if UpdateStress then UpdateStress(cachedStress) end
end)

RegisterNetEvent('hud:client:UpdateNeeds', function(hunger, thirst)
    cachedNeeds.hunger = math.floor(hunger or 100)
    cachedNeeds.thirst = math.floor(thirst or 100)
    if UpdateNeeds then UpdateNeeds(cachedNeeds.hunger, cachedNeeds.thirst) end
end)

-- Built-in survival: apply overflow damage when hunger/thirst reaches 0
RegisterNetEvent('codem-hud:vrp:survivalDamage', function(damage)
    local ped = PlayerPedId()
    if ped and DoesEntityExist(ped) then
        local hp = GetEntityHealth(ped)
        SetEntityHealth(ped, math.max(0, hp - (damage or 5)))
    end
end)

-- debugPrint('[Framework] vRP client bridge loaded')
