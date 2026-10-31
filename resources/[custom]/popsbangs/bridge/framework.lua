
PopsFramework = PopsFramework or {}

local detectedFramework = "standalone"
local ESX = nil
local QBCore = nil

function DetectFramework()
    local configured = (type(Config) == "table" and Config.Framework) or "auto"
    if configured ~= "auto" then
        detectedFramework = configured
        if detectedFramework == "esx" then
            local ok, obj = pcall(function() return exports["es_extended"]:getSharedObject() end)
            if ok and obj then ESX = obj end
        elseif detectedFramework == "qbcore" then
            local ok, obj = pcall(function() return exports["qb-core"]:GetCoreObject() end)
            if ok and obj then QBCore = obj end
        end
        return
    end

    if GetResourceState("qbx_core") == "started" then
        detectedFramework = "qbox"
    elseif GetResourceState("qb-core") == "started" then
        detectedFramework = "qbcore"
        local ok, obj = pcall(function() return exports["qb-core"]:GetCoreObject() end)
        if ok and obj then QBCore = obj end
    elseif GetResourceState("es_extended") == "started" then
        detectedFramework = "esx"
        local ok, obj = pcall(function() return exports["es_extended"]:getSharedObject() end)
        if ok and obj then ESX = obj end
    else
        detectedFramework = "standalone"
    end
end

DetectFramework()

function PopsFramework.GetPlayer(source)
    if detectedFramework == "qbox" then
        return exports.qbx_core:GetPlayer(source)
    elseif detectedFramework == "qbcore" and QBCore then
        return QBCore.Functions.GetPlayer(source)
    elseif detectedFramework == "esx" and ESX then
        return ESX.GetPlayerFromId(source)
    end
    return nil
end

function PopsFramework.GetJob(source)
    local player = PopsFramework.GetPlayer(source)
    if not player then
        return "none"
    end

    if detectedFramework == "qbox" or detectedFramework == "qbcore" then
        if player.PlayerData and player.PlayerData.job then
            return player.PlayerData.job.name
        end
    elseif detectedFramework == "esx" then
        if player.job then
            return player.job.name
        end
    end

    return "none"
end

function PopsFramework.HasJob(source, allowedJobs)
    if not allowedJobs or allowedJobs == false then
        return true
    end

    if detectedFramework == "standalone" then
        return true
    end

    local currentJob = PopsFramework.GetJob(source)
    if type(allowedJobs) == "table" then
        for _, jobName in ipairs(allowedJobs) do
            if jobName == currentJob then
                return true
            end
        end
        return false
    elseif type(allowedJobs) == "string" then
        return currentJob == allowedJobs
    end

    return true
end

function PopsFramework.Notify(source, message, notifyType)
    if type(message) ~= "string" or message == "" then
        return
    end

    if type(Config) == "table" and type(Config.FrameworkCustom) == "table" and Config.FrameworkCustom.Notify then
        local success, result = pcall(Config.FrameworkCustom.Notify, source, message, notifyType)
        if success and result ~= false then
            return
        end
    end

    if detectedFramework == "qbox" then
        local qbxType = "inform"
        if notifyType == "error" then
            qbxType = "error"
        elseif notifyType == "success" then
            qbxType = "success"
        end
        exports.qbx_core:Notify(source, message, qbxType)
    elseif detectedFramework == "qbcore" and QBCore then
        local qbType = "primary"
        if notifyType == "error" then
            qbType = "error"
        elseif notifyType == "success" then
            qbType = "success"
        end
        TriggerClientEvent("QBCore:Notify", source, message, qbType, 5000)
    elseif detectedFramework == "esx" and ESX then
        TriggerClientEvent("esx:showNotification", source, message)
    else
        TriggerClientEvent("oxlyn-popsbangs:notify", source, message, notifyType)
    end
end

function PopsFramework.HasPermission(source)
    if not Config.RequireAce then
        return true
    end
    local perm = Config.AcePermission or "oxlyn.pops.install"
    return IsPlayerAceAllowed(source, perm)
end
--fivevault-KYOnRDTopaf : https://discord.gg/fivevault
--fivevaultsz3OnvvTop98 : https://discord.gg/fivevault
--fivevault_lYOnWGTopHR : https://discord.gg/fivevault
--fivevault_3COngHTop_c : https://discord.gg/fivevault
--fivevault-SlOn$3Toppd : https://discord.gg/fivevault
