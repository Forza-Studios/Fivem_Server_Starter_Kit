if Config.Framework ~= "qbox" then return end

local function CheckQBoxStatus()
    local state = GetResourceState('qbx_core')
    return state == "started" or state == "starting"
end

if not CheckQBoxStatus() then
    debugPrint('[Framework] qbx_core not started')
    return
end

local QBX = nil
local ok, result = pcall(function() return exports['qbx_core']:GetCoreObject() end)
if ok and result then
    QBX = result
    Core = QBX
    debugPrint('[Framework] QBox initialized (with CoreObject)')
else
    debugPrint('[Framework] QBox initialized (export mode)')
end

local function GetQBXPlayerData()
    if QBX and QBX.Functions and QBX.Functions.GetPlayerData then
        return QBX.Functions.GetPlayerData()
    end
    local s, data = pcall(function() return exports['qbx_core']:GetPlayerData() end)
    if s and data then return data end
    return nil
end

local function QBXNotify(message, type)
    if QBX and QBX.Functions and QBX.Functions.Notify then
        QBX.Functions.Notify(message, type)
        return
    end
    pcall(function() exports['qbx_core']:Notify(message, type) end)
end

local PlayerLoadedTriggered = false

RegisterNetEvent("QBCore:Client:OnPlayerLoaded")
AddEventHandler("QBCore:Client:OnPlayerLoaded", function()
    if PlayerLoadedTriggered then return end
    PlayerLoadedTriggered = true
    Wait(100)
    TriggerEvent('codem-hud:client:PlayerLoaded')
end)

CreateThread(function()
    Wait(500)
    if PlayerLoadedTriggered then return end
    local playerData = GetQBXPlayerData()
    if playerData and playerData.citizenid then
        PlayerLoadedTriggered = true
        TriggerEvent('codem-hud:client:PlayerLoaded')
    end
end)

RegisterNetEvent("QBCore:Client:OnPlayerUnload", function()
    PlayerLoadedTriggered = false
    TriggerEvent('codem-hud:client:PlayerUnloaded')
end)

function GetPlayerData()
    return GetQBXPlayerData()
end

function GetPlayerInfo()
    local name = 'Unknown'
    local id = GetPlayerServerId(PlayerId())
    local playerData = GetQBXPlayerData()
    if playerData and playerData.charinfo then
        name = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname
    end
    return { name = name, id = id }
end

function Notify(message, type)
    local notifConfig = Config.Notification or {}
    local system = notifConfig.System or 'framework'

    if system == 'ox' then
        pcall(function() exports['ox_lib']:notify({ description = message, type = type }) end)
    elseif system == 'custom' and notifConfig.Custom then
        notifConfig.Custom(message, type)
    else
        QBXNotify(message, type)
    end
end

function CanInteract()
    local playerData = GetQBXPlayerData()
    if not playerData or not playerData.metadata then return true end
    local metadata = playerData.metadata
    return not (metadata.ishandcuffed or metadata.isdead or metadata.inlaststand)
end

function GetPlayerJob()
    local playerData = GetQBXPlayerData()
    if playerData and playerData.job then
        local grade = playerData.job.grade or {}
        return {
            name = playerData.job.name or 'unemployed',
            label = playerData.job.label or 'Unemployed',
            onduty = playerData.job.onduty or false,
            grade = grade.level or 0,
            gradeLabel = grade.name or ''
        }
    end
    return nil
end

function GetPlayerNeeds()
    local playerData = GetQBXPlayerData()
    if playerData and playerData.metadata then
        return {
            hunger = math.floor(playerData.metadata.hunger or 100),
            thirst = math.floor(playerData.metadata.thirst or 100)
        }
    end
    return { hunger = 100, thirst = 100 }
end

function GetPlayerStress()
    local playerData = GetQBXPlayerData()
    if playerData and playerData.metadata then
        return math.floor(playerData.metadata.stress or 0)
    end
    return 0
end

function SetPlayerStress(stress)
    TriggerServerEvent('codem-hud:server:SetStress', stress)
end

-- Listen for stress updates from external scripts
RegisterNetEvent('hud:client:UpdateStress', function(stress)
    if UpdateStress then UpdateStress(stress) end
end)

-- Also listen for QBCore metadata changes that include stress (QBox uses same events)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(playerData)
    if not playerData or not playerData.metadata then return end
    if playerData.metadata.stress ~= nil and UpdateStress then
        UpdateStress(math.floor(playerData.metadata.stress))
    end
end)

function GetPlayerIdentifier()
    local playerData = GetQBXPlayerData()
    if playerData then
        return playerData.citizenid or nil
    end
    return nil
end

RegisterNetEvent('hud:client:UpdateNeeds', function(hunger, thirst)
    if UpdateNeeds then UpdateNeeds(hunger, thirst) end
end)

-- Track previous money values for change detection
local lastCash = -1
local lastBank = -1

-- Detect money changes from QBCore:Player:SetPlayerData
RegisterNetEvent('QBCore:Player:SetPlayerData', function(playerData)
    if not (UpdateMoney and playerData and playerData.money) then return end

    local cash = playerData.money.cash or 0
    local bank = playerData.money.bank or 0
    -- Marked bills handled separately by inventory module - don't include here

    -- Initialize on first call
    if lastCash == -1 then
        lastCash = cash
        lastBank = bank
        UpdateMoney(cash, bank, 0)
        return
    end

    -- Detect cash change
    if cash ~= lastCash then
        local diff = cash - lastCash
        local changeAmount = math.abs(diff)
        local isMinus = diff < 0
        lastCash = cash
        UpdateMoney(cash, bank, 0, nil, 'cash', changeAmount, isMinus)
        return
    end

    -- Detect bank change
    if bank ~= lastBank then
        local diff = bank - lastBank
        local changeAmount = math.abs(diff)
        local isMinus = diff < 0
        lastBank = bank
        UpdateMoney(cash, bank, 0, nil, 'bank', changeAmount, isMinus)
        return
    end

    -- No money change detected, just update values
    UpdateMoney(cash, bank, 0)
end)

RegisterNetEvent('hud:client:OnMoneyChange', function(moneyType, amount, isMinus)
    if not UpdateMoney then return end
    local playerData = GetQBXPlayerData()
    if playerData and playerData.money then
        local cash = playerData.money.cash or 0
        local bank = playerData.money.bank or 0
        -- Marked bills handled separately by inventory module
        -- Update tracked values
        lastCash = cash
        lastBank = bank
        -- Society is handled separately by FetchSocietyMoney - not included here
        UpdateMoney(cash, bank, 0, nil, moneyType, amount, isMinus)
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not UpdateJob then return end
    UpdateJob(job.name or 'unemployed', job.label or 'Unemployed', job.grade and job.grade.name or '')
end)

