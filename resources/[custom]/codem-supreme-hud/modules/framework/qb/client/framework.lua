if Config.Framework ~= "qb" then return end

Core = nil
local QBCore = nil

local function CheckQBCoreStatus()
    local state = GetResourceState('qb-core')
    return state == "started" or state == "starting"
end

if CheckQBCoreStatus() then
    local ok, result = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and result then
        QBCore = result
        Core = QBCore
        debugPrint('[Framework] QBCore initialized')
    else
        debugPrint('[Framework] QBCore object not found')
    end
else
    debugPrint('[Framework] qb-core not started')
    return
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
    if QBCore and QBCore.Functions then
        local playerData = QBCore.Functions.GetPlayerData()
        if playerData and playerData.citizenid then
            PlayerLoadedTriggered = true
            TriggerEvent('codem-hud:client:PlayerLoaded')
        end
    end
end)

RegisterNetEvent("QBCore:Client:OnPlayerUnload", function()
    PlayerLoadedTriggered = false
    lastCash = -1
    lastBank = -1
    TriggerEvent('codem-hud:client:PlayerUnloaded')
end)

function GetPlayerData()
    if QBCore and QBCore.Functions then
        return QBCore.Functions.GetPlayerData()
    end
    return nil
end

function Notify(message, type)
    local notifConfig = Config.Notification or {}
    local system = notifConfig.System or 'framework'

    if system == 'ox' then
        pcall(function() exports['ox_lib']:notify({ description = message, type = type }) end)
    elseif system == 'custom' and notifConfig.Custom then
        notifConfig.Custom(message, type)
    else
        if QBCore and QBCore.Functions then
            QBCore.Functions.Notify(message, type)
        end
    end
end

function GetPlayerInfo()
    local name = 'Unknown'
    local serverId = GetPlayerServerId(PlayerId())
    local id = serverId

    if QBCore and QBCore.Functions then
        local playerData = QBCore.Functions.GetPlayerData()
        if playerData and playerData.charinfo then
            name = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname
        end
    end

    if Config.GetCustomPlayerId then
        local customId = Config.GetCustomPlayerId(serverId)
        if customId then
            id = customId
        end
    end

    return { name = name, id = id }
end

function CanInteract()
    if not QBCore then return false end
    local playerData = QBCore.Functions.GetPlayerData()
    if not playerData or not playerData.metadata then return true end
    local metadata = playerData.metadata
    return not (metadata.ishandcuffed or metadata.isdead or metadata.inlaststand)
end

function GetPlayerJob()
    if not QBCore then return nil end
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData and playerData.job then
        return {
            name = playerData.job.name or 'unemployed',
            label = playerData.job.label or 'Unemployed',
            onduty = playerData.job.onduty or false,
            grade = playerData.job.grade.level or 0,
            gradeLabel = playerData.job.grade.name or ''
        }
    end
    return nil
end

function GetPlayerNeeds()
    if not QBCore then return { hunger = 100, thirst = 100 } end
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData and playerData.metadata then
        return {
            hunger = math.floor(playerData.metadata.hunger or 100),
            thirst = math.floor(playerData.metadata.thirst or 100)
        }
    end
    return { hunger = 100, thirst = 100 }
end

function GetPlayerStress()
    if not QBCore then return 0 end
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData and playerData.metadata then
        return math.floor(playerData.metadata.stress or 0)
    end
    return 0
end

-- Update stress on server (QBCore uses metadata)
function SetPlayerStress(stress)
    if not QBCore then return end
    TriggerServerEvent('codem-hud:server:SetStress', stress)
end

-- Listen for stress updates from qb-smallresources or other scripts
RegisterNetEvent('hud:client:UpdateStress', function(stress)
    if UpdateStress then UpdateStress(stress) end
end)

-- Also listen for QBCore metadata changes that include stress
RegisterNetEvent('QBCore:Player:SetPlayerData', function(playerData)
    if not playerData or not playerData.metadata then return end
    if playerData.metadata.stress ~= nil and UpdateStress then
        UpdateStress(math.floor(playerData.metadata.stress))
    end
end)

function GetPlayerIdentifier()
    if not QBCore then return nil end
    local playerData = QBCore.Functions.GetPlayerData()
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
    if not (QBCore and UpdateMoney and playerData and playerData.money) then return end

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
    if not (QBCore and UpdateMoney) then return end
    local playerData = QBCore.Functions.GetPlayerData()
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

-- Note: Inventory events (ItemBox, closeInv, SetPlayerData) are handled by
-- modules/inventory/client/inventory.lua which already tracks markedbills

-- Society refresh when money changes (banking deposit/withdraw triggers OnMoneyChange)
AddEventHandler('hud:client:OnMoneyChange', function(moneyType, amount, isMinus)
    if FetchSocietyMoney and IsPlayerLoaded() and IsHudVisible() then
        SetTimeout(500, FetchSocietyMoney)
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not UpdateJob then return end
    UpdateJob(job.name or 'unemployed', job.label or 'Unemployed', job.grade and job.grade.name or '')
end)

