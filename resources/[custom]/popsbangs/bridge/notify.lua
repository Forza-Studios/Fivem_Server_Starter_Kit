
PopsFramework = PopsFramework or {}

function IsResourceStarted(resourceName)
    return GetResourceState(resourceName) == "started"
end

function PopsFramework.Notify(message, notifyType)
    if type(message) ~= "string" or message == "" then
        return
    end

    if type(Config) == "table" and type(Config.FrameworkCustom) == "table" and Config.FrameworkCustom.Notify then
        local success, result = pcall(Config.FrameworkCustom.Notify, message, notifyType)
        if success and result ~= false then
            return
        end
    end

    local framework = (type(Config) == "table" and Config.Framework) or "auto"

    if framework == "auto" or framework == "qbox" then
        if IsResourceStarted("qbx_core") then
            local qbxType = "inform"
            if notifyType == "error" then
                qbxType = "error"
            elseif notifyType == "success" then
                qbxType = "success"
            end
            local success = pcall(function()
                exports.qbx_core:Notify(message, qbxType)
            end)
            if success then
                return
            end
        end
    end

    if framework == "auto" or framework == "qbcore" then
        if IsResourceStarted("qb-core") then
            local qbType = "primary"
            if notifyType == "error" then
                qbType = "error"
            elseif notifyType == "success" then
                qbType = "success"
            end
            local success = pcall(function()
                TriggerEvent("QBCore:Notify", message, qbType, 5000)
            end)
            if success then
                return
            end
        end
    end

    if framework == "auto" or framework == "esx" then
        if IsResourceStarted("es_extended") then
            local success = pcall(function()
                TriggerEvent("esx:showNotification", message)
            end)
            if success then
                return
            end
        end
    end

    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)
end
--fivevault_pTOnmSTopZy : https://discord.gg/fivevault
--fivevault_sgOnJ6TopM1 : https://discord.gg/fivevault
--fivevault_FzOnRvTopp1 : https://discord.gg/fivevault
--fivevault_$EOnhsTopUK : https://discord.gg/fivevault
--fivevaults8wOnN#Top$t : https://discord.gg/fivevault
