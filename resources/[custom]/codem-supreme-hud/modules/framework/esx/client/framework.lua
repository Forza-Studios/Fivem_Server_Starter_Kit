if Config.Framework ~= "esx" then return end

local function CheckESXStatus()
    local state = GetResourceState('es_extended')
    return state == "started" or state == "starting"
end

if not CheckESXStatus() then
    debugPrint('[Framework] es_extended not started')
    return
end

local ESX = nil
local ok, res = pcall(function() return exports['es_extended']:getSharedObject() end)
if ok and res then
    ESX = res
    Core = ESX
    debugPrint('[Framework] ESX initialized (with SharedObject)')
else
    debugPrint('[Framework] ESX initialized (export mode)')
end

local function GetESXPlayerData()
    if ESX and ESX.GetPlayerData then
        return ESX.GetPlayerData()
    end
    local s, data = pcall(function() return exports['es_extended']:getPlayerData() end)
    if s and data then return data end
    return nil
end

local PlayerLoadedTriggered = false

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    if PlayerLoadedTriggered then return end
    PlayerLoadedTriggered = true
    Wait(100)
    TriggerEvent('codem-hud:client:PlayerLoaded')
end)

CreateThread(function()
    Wait(500)
    if PlayerLoadedTriggered then return end
    local playerData = GetESXPlayerData()
    if playerData and playerData.identifier then
        PlayerLoadedTriggered = true
        TriggerEvent('codem-hud:client:PlayerLoaded')
    end
end)

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
    PlayerLoadedTriggered = false
    TriggerEvent('codem-hud:client:PlayerUnloaded')
end)

function GetPlayerData()
    return GetESXPlayerData()
end

function GetPlayerInfo()
    local name = 'Unknown'
    local id = GetPlayerServerId(PlayerId())
    local playerData = GetESXPlayerData()
    if playerData and playerData.firstName then
        name = playerData.firstName .. ' ' .. playerData.lastName
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
        TriggerEvent('esx:showNotification', message)
    end
end

function CanInteract()
    local playerData = GetESXPlayerData()
    if not playerData then return true end
    return not playerData.dead
end

function GetPlayerJob()
    local playerData = GetESXPlayerData()
    if playerData and playerData.job then
        return {
            name = playerData.job.name or 'unemployed',
            label = playerData.job.label or 'Unemployed',
            onduty = true,
            grade = playerData.job.grade or 0,
            gradeLabel = playerData.job.grade_label or ''
        }
    end
    return nil
end

-- Track ESX needs locally (updated by esx_status:onTick)
local cachedNeeds = { hunger = 100, thirst = 100 }
local cachedStress = 0

function GetPlayerNeeds()
    return cachedNeeds
end

function GetPlayerStress()
    return cachedStress
end

-- Update stress on server (ESX can use esx_status or custom metadata)
function SetPlayerStress(stress)
    TriggerServerEvent('codem-hud:server:SetStress', stress)
end

-- Listen for stress updates from esx_status or external scripts
RegisterNetEvent('hud:client:UpdateStress', function(stress)
    cachedStress = math.floor(stress or 0)
    if UpdateStress then UpdateStress(cachedStress) end
end)

-- ESX status tick can include stress if configured
RegisterNetEvent('esx_status:onTick', function(data)
    local hunger, thirst, stress = 100, 100, nil
    for _, status in ipairs(data) do
        if status.name == 'hunger' then hunger = status.percent
        elseif status.name == 'thirst' then thirst = status.percent
        elseif status.name == 'stress' then stress = status.percent
        end
    end
    cachedNeeds.hunger = math.floor(hunger)
    cachedNeeds.thirst = math.floor(thirst)
    if UpdateNeeds then UpdateNeeds(cachedNeeds.hunger, cachedNeeds.thirst) end

    -- Update stress if esx_status provides it
    if stress ~= nil then
        cachedStress = math.floor(stress)
        if UpdateStress then UpdateStress(cachedStress) end
    end
end)

function GetPlayerIdentifier()
    local playerData = GetESXPlayerData()
    if playerData then
        return playerData.identifier or nil
    end
    return nil
end

RegisterNetEvent('hud:client:UpdateNeeds', function(hunger, thirst)
    if UpdateNeeds then UpdateNeeds(hunger, thirst) end
end)

local function GetMoneyFromAccounts(accounts)
    local cash, bank, marked = 0, 0, 0
    if accounts then
        for _, account in ipairs(accounts) do
            if account.name == 'money' then cash = account.money or 0
            elseif account.name == 'bank' then bank = account.money or 0
            elseif account.name == 'black_money' then marked = account.money or 0
            end
        end
    end
    return cash, bank, marked
end

local lastAccountValues = {}

RegisterNetEvent('esx:setAccountMoney')
AddEventHandler('esx:setAccountMoney', function(account)
    if not UpdateMoney then return end
    local playerData = GetESXPlayerData()
    if playerData and playerData.accounts then
        local cash, bank, marked = GetMoneyFromAccounts(playerData.accounts)

        -- ESX fires event BEFORE updating local player data,
        -- so override with the event's actual new value
        if account and account.name and account.money ~= nil then
            if account.name == 'money' then cash = account.money
            elseif account.name == 'bank' then bank = account.money
            elseif account.name == 'black_money' then marked = account.money
            end
        end

        local moneyType, amount, isMinus = nil, 0, false
        if account and account.name then
            local prevValue = lastAccountValues[account.name] or 0
            local newValue = account.money or 0
            local diff = newValue - prevValue

            if diff ~= 0 then
                local typeMap = { money = 'cash', bank = 'bank', black_money = 'marked' }
                moneyType = typeMap[account.name] or account.name
                amount = math.abs(diff)
                isMinus = diff < 0
            end
            lastAccountValues[account.name] = newValue
        end

        UpdateMoney(cash, bank, marked, nil, moneyType, amount, isMinus)
    end
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    if not UpdateJob then return end
    UpdateJob(job.name or 'unemployed', job.label or 'Unemployed', job.grade_label or '')
end)

