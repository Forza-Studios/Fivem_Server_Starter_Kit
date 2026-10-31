Notify = {}

-- GTA's built-in notification (client only). Used as the last-resort fallback.
local function nativeNotify(message)
    if IsDuplicityVersion() then
        return
    end

    SetNotificationTextEntry("STRING")
    AddTextComponentString(tostring(message))
    DrawNotification(false, true)
end

-- Sends a notification.
--   Server: source = player id, forwarded to that player's client.
--   Client: source is ignored.
function Notify.Send(source, message, type, duration)
    type = type or "info"
    duration = duration or 4500

    -- Custom override: if it runs without error, it handles the notification
    if Overrides and _G.type(Overrides.Notify) == "function" then
        local ok = pcall(Overrides.Notify, source, message, type, duration)
        if ok then
            return
        end
    end

    -- Server: forward to the client
    if IsDuplicityVersion() then
        TriggerClientEvent("oxlyn-truckjob:client:notify", source, message, type, duration)
        return
    end

    local mode = Config.Notify or "native"

    -- "native" mode uses the resource's own NUI notification
    if mode == "native" then
        SendNUIMessage({
            action = "notify",
            message = message,
            type = type,
            duration = duration,
        })
        return
    end

    if mode == "ox" and GetResourceState("ox_lib") == "started" then
        lib.notify({
            title = "Truck Job",
            description = message,
            type = type,
            duration = duration,
        })
        return
    end

    if mode == "esx" and GetResourceState("es_extended") == "started" then
        local ESX = exports.es_extended:getSharedObject()
        if ESX.ShowNotification then
            ESX.ShowNotification(message)
            return
        end
    end

    if mode == "qb" or mode == "qbox" then
        if GetResourceState("qbx_core") == "started" then
            local ok = pcall(function()
                exports.qbx_core:Notify(message, type, duration)
            end)
            if ok then
                return
            end
        end

        if GetResourceState("qb-core") == "started" then
            TriggerEvent("QBCore:Notify", message, type, duration)
            return
        end
    end

    if mode == "okok" and GetResourceState("okokNotify") == "started" then
        exports.okokNotify:Alert("Truck Job", message, duration, type, false)
        return
    end

    -- Selected system unavailable: fall back to the GTA native notification
    nativeNotify(message)
end

-- Server -> client notification relay
if not IsDuplicityVersion() then
    RegisterNetEvent("oxlyn-truckjob:client:notify", function(message, type, duration)
        Notify.Send(nil, message, type, duration)
    end)
end