
PopsValveUI = {}

local activeValveSession = nil

function PopsValveUI.IsOpen()
    return activeValveSession ~= nil
end

function PopsValveUI.Close()
    activeValveSession = nil
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "valve",
        open = false
    })
end

function UseValveControl(itemSlot)
    if activeValveSession then
        PopsValveUI.Close()
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        PopsFramework.Notify(L("need_driver"), "error")
        return
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        local driverPed = GetPedInVehicleSeat(vehicle, -1)
        if driverPed == 0 or not DoesEntityExist(driverPed) then
            SetPedIntoVehicle(ped, vehicle, -1)
            Wait(50)
        else
            PopsFramework.Notify(L("need_driver"), "error")
            return
        end
    end

    if not NetworkGetEntityIsNetworked(vehicle) then
        return
    end

    TriggerServerEvent("oxlyn-popsbangs:valveOpen", VehToNet(vehicle))
end

exports("useValveControl", UseValveControl)

RegisterCommand("valve", function()
    UseValveControl()
end, false)

RegisterNetEvent("oxlyn-popsbangs:useValve", function(itemSlot)
    UseValveControl(itemSlot)
end)

RegisterNetEvent("oxlyn-popsbangs:valveUI", function(data)
    if type(data) ~= "table" then
        return
    end

    if data.update and not activeValveSession then
        return
    end

    if not data.open then
        PopsValveUI.Close()
        if data.message and PopsClient and PopsClient.notify then
            PopsClient.notify(data.message, "error")
        end
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped or VehToNet(vehicle) ~= data.netId then
        PopsValveUI.Close()
        return
    end

    activeValveSession = {
        vehicle = vehicle,
        netId = data.netId
    }

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "valve",
        open = true,
        closed = (data.closed == true)
    })
end)

RegisterNUICallback("valveSet", function(data, cb)
    if activeValveSession and type(data) == "table" and type(data.closed) == "boolean" then
        TriggerServerEvent("oxlyn-popsbangs:valveSet", activeValveSession.netId, data.closed)
        cb({ ok = true })
    else
        cb({ ok = false })
    end
end)

RegisterNUICallback("valveClose", function(data, cb)
    PopsValveUI.Close()
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if activeValveSession then
            local ped = PlayerPedId()
            local vehicle = activeValveSession.vehicle
            local shouldClose = false

            if not DoesEntityExist(vehicle) or GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped or IsEntityDead(ped) or IsPauseMenuActive() then
                shouldClose = true
            elseif PopsWorkshopBusy and PopsWorkshopBusy() then
                shouldClose = true
            end

            if shouldClose then
                PopsValveUI.Close()
            end
        end

        Wait(activeValveSession and 100 or 1000)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() and activeValveSession then
        PopsValveUI.Close()
    end
end)
--fivevault-q-OnYxTopRJ : https://discord.gg/fivevault
--fivevault-BOOnaJTopfj : https://discord.gg/fivevault
--fivevault5lOnykTopcO : https://discord.gg/fivevault
--fivevault_u7OnopTopCG : https://discord.gg/fivevault
--fivevault_jgOnQkTopmm : https://discord.gg/fivevault
