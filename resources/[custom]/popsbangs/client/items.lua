
local activeWorkshopJob = nil
local isStopping = false

local controlKeysNumber = { 157, 158, 159, 160, 161, 162, 163, 164, 165 }
local controlKeysLeft = { 174, 172, 189, 34 }
local controlKeysRight = { 175, 173, 190, 35 }
local controlKeysConfirm = { 18, 191, 201, 217 }
local controlKeysCancel = { 177, 194, 202 }
local controlKeysAll = { 157, 158, 159, 160, 161, 162, 163, 164, 165, 174, 175, 172, 173, 189, 190, 34, 35, 18, 191, 201, 217, 177, 194, 202 }

function PopsWorkshopBusy()
    return activeWorkshopJob ~= nil
end

function NotifyPlayer(message, notifyType)
    if PopsClient and PopsClient.notify then
        PopsClient.notify(message, notifyType)
    end
end

function GetItemsConfig()
    return (type(Config) == "table" and Config.Items) or {}
end

function GetUIConfig()
    return (type(Config) == "table" and Config.UI) or {}
end

function GetExhaustColour(exhaustName)
    local exhausts = (type(Config) == "table" and Config.Exhausts) or {}
    local entry = exhausts[exhaustName or "stock"]
    return (type(entry) == "table" and entry.colour) or nil
end

function GetWorkshopTitle(mode, data)
    if mode == "install" then
        return L("ui_title_install")
    elseif mode == "remove" then
        return L("ui_title_remove")
    elseif mode == "tune" then
        return L("ui_title_tune")
    end

    local labels = (type(data.labels) == "table" and data.labels) or {}
    local exhaustLabel = tostring(labels.exhaust or "")
    return L("ui_title_exhaust", exhaustLabel)
end

function IsAnyControlJustPressed(controls, checkDisabled)
    for _, control in ipairs(controls) do
        if IsControlJustPressed(0, control) then
            return true
        end
        if checkDisabled and IsDisabledControlJustPressed(0, control) then
            return true
        end
    end
    return false
end

function CleanupWorkshop(reasonMessage, keepEngineOn)
    local job = activeWorkshopJob
    if not job then
        return
    end

    activeWorkshopJob = nil

    SendNUIMessage({
        action = "workshop",
        open = false
    })

    if DoesEntityExist(job.vehicle) then
        SetVehicleHandbrake(job.vehicle, false)
        if job.bonnet then
            SetVehicleDoorShut(job.vehicle, 4, false)
        end
        if keepEngineOn and GetVehiclePedIsIn(PlayerPedId(), false) == job.vehicle then
            SetVehicleEngineOn(job.vehicle, true, false, false)
        end
    end

    if reasonMessage then
        NotifyPlayer(reasonMessage, "warning")
    end
end

function CancelWorkshop(reasonMessage)
    local job = activeWorkshopJob
    if not job then
        return
    end

    TriggerServerEvent("oxlyn-popsbangs:workshopCancel", job.token)
    CleanupWorkshop(reasonMessage)
end

function SelectTuneLevel(job, maxLevel, defaultLevel)
    local selectedLevel = math.max(1, math.min(maxLevel, defaultLevel or 2))

    function SendSelectionNUI(isPreview)
        SendNUIMessage({
            action = "workshop",
            select = true,
            token = job.token,
            level = selectedLevel,
            preview = (isPreview == true)
        })
    end

    SendSelectionNUI(false)

    while activeWorkshopJob == job do
        for _, control in ipairs(controlKeysAll) do
            DisableControlAction(0, control, true)
        end

        local pressedNumber = nil
        for numberIdx, control in ipairs(controlKeysNumber) do
            if maxLevel >= numberIdx and (IsDisabledControlJustPressed(0, control) or IsControlJustPressed(0, control)) then
                pressedNumber = numberIdx
                break
            end
        end

        if pressedNumber then
            if pressedNumber == selectedLevel then
                return selectedLevel
            end
            selectedLevel = pressedNumber
            SendSelectionNUI(true)
        elseif IsAnyControlJustPressed(controlKeysLeft, true) then
            if selectedLevel > 1 then
                selectedLevel = selectedLevel - 1
                SendSelectionNUI(true)
            end
        elseif IsAnyControlJustPressed(controlKeysRight, true) then
            if selectedLevel < maxLevel then
                selectedLevel = selectedLevel + 1
                SendSelectionNUI(true)
            end
        elseif IsAnyControlJustPressed(controlKeysConfirm, true) then
            return selectedLevel
        elseif IsAnyControlJustPressed(controlKeysCancel, true) then
            return nil
        end

        Wait(0)
    end

    return nil
end

function UseWorkshopItem(item)
    local itemsCfg = GetItemsConfig()
    if itemsCfg.enabled == false then
        return
    end

    local itemName = (type(item) == "table" and item.name) or item
    if type(itemName) ~= "string" then
        return
    end

    if activeWorkshopJob then
        NotifyPlayer(L("job_busy"), "warning")
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        NotifyPlayer(L("need_driver"), "error")
        return
    end

    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        local driverPed = GetPedInVehicleSeat(vehicle, -1)
        if driverPed == 0 or not DoesEntityExist(driverPed) then
            SetPedIntoVehicle(ped, vehicle, -1)
            Wait(50)
        else
            NotifyPlayer(L("need_driver"), "error")
            return
        end
    end

    if not NetworkGetEntityIsNetworked(vehicle) then
        NotifyPlayer(L("not_synced"), "warning")
        return
    end

    if itemsCfg.requireStopped ~= false and GetEntitySpeed(vehicle) > 1.0 then
        NotifyPlayer(L("stop_first"), "error")
        return
    end

    TriggerServerEvent("oxlyn-popsbangs:workshopBegin", VehToNet(vehicle), itemName)
end

exports("useItem", UseWorkshopItem)

RegisterNetEvent("oxlyn-popsbangs:useItem", function(item)
    UseWorkshopItem(item)
end)

RegisterNetEvent("oxlyn-popsbangs:workshopOpen", function(data)
    if type(data) ~= "table" or type(data.token) ~= "string" or activeWorkshopJob then
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return
    end

    local mode = data.mode
    if mode ~= "install" and mode ~= "remove" and mode ~= "exhaust" and mode ~= "tune" then
        return
    end

    local seconds = (mode == "tune" and 0) or (PopsProtocol.Finite(data.seconds) and data.seconds) or 5

    if PopsValveUI and PopsValveUI.IsOpen and PopsValveUI.IsOpen() then
        PopsValveUI.Close()
    end

    local uiCfg = GetUIConfig()
    local openBonnet = (uiCfg.bonnet ~= false) and (mode == "install" or mode == "remove")

    activeWorkshopJob = {
        token = data.token,
        mode = mode,
        vehicle = vehicle,
        netId = VehToNet(vehicle),
        since = GetGameTimer(),
        bonnet = openBonnet
    }

    local currentJob = activeWorkshopJob
    local labels = (type(data.labels) == "table" and data.labels) or {}

    SendNUIMessage({
        action = "workshop",
        open = true,
        token = data.token,
        mode = mode,
        seconds = seconds,
        label = GetWorkshopTitle(mode, data),
        colour = GetExhaustColour(data.exhaust),
        item = data.item,
        exhaustLabel = labels.exhaust,
        currentLabel = labels.current,
        returned = labels.returned,
        consumed = labels.consumed
    })

    if DoesEntityExist(vehicle) then
        SetVehicleEngineOn(vehicle, false, true, true)
        SetVehicleHandbrake(vehicle, true)
        if openBonnet then
            SetVehicleDoorOpen(vehicle, 4, false, false)
        end
    end

    CreateThread(function()
        local durationMs = seconds * 1000
        local expiresAt = GetGameTimer() + durationMs

        while activeWorkshopJob == currentJob and GetGameTimer() < expiresAt do
            if IsControlJustPressed(0, 177) and not IsPauseMenuActive() then
                CancelWorkshop(L("job_cancelled"))
                return
            end
            Wait(0)
        end

        if activeWorkshopJob ~= currentJob then
            return
        end

        local chosenLevel = nil

        if mode == "install" or mode == "tune" then
            local levelsTable = (type(data.levels) == "table" and data.levels) or {}
            local maxLevel = math.max(1, math.min(#levelsTable > 0 and #levelsTable or PopsProtocol.MaxLevel(), 9))

            SendNUIMessage({
                action = "workshop",
                pick = true,
                token = currentJob.token,
                levels = data.levels,
                level = data.level
            })

            local defaultLevel = (PopsProtocol.Finite(data.level) and data.level >= 1 and data.level) or 2
            chosenLevel = SelectTuneLevel(currentJob, maxLevel, defaultLevel)

            if activeWorkshopJob ~= currentJob then
                return
            end

            if not chosenLevel then
                CancelWorkshop(L("job_cancelled"))
                return
            end

            SendNUIMessage({
                action = "workshop",
                wait = true,
                token = currentJob.token,
                selected = chosenLevel
            })
        end

        TriggerServerEvent("oxlyn-popsbangs:workshopFinish", currentJob.token, chosenLevel)

        SetTimeout(4000, function()
            if activeWorkshopJob == currentJob then
                CleanupWorkshop(L("job_cancelled"), false)
            end
        end)
    end)
end)

RegisterNetEvent("oxlyn-popsbangs:workshopResult", function(success, message, details)
    if not activeWorkshopJob then
        return
    end

    local job = activeWorkshopJob

    SendNUIMessage({
        action = "workshop",
        result = (success == true),
        message = message,
        details = details
    })

    SetTimeout(1800, function()
        if activeWorkshopJob == job then
            CleanupWorkshop(nil, success == true)
        end
    end)

    if type(message) == "string" then
        local uiCfg = GetUIConfig()
        if uiCfg.notifications == "framework" or not success then
            NotifyPlayer(message, success and "success" or "error")
        end
    end

    if success == true and type(details) == "table" and details.mode == "exhaust" then
        local itemsCfg = GetItemsConfig()
        if itemsCfg.testBang ~= false then
            local vehicle = job.vehicle
            local netId = job.netId
            SetTimeout(2300, function()
                if DoesEntityExist(vehicle) and GetVehiclePedIsIn(PlayerPedId(), false) == vehicle then
                    if PopsClient and PopsClient.localBang then
                        PopsClient.localBang(vehicle, netId)
                    end
                end
            end)
        end
    end
end)

CreateThread(function()
    while not isStopping do
        if activeWorkshopJob then
            local ped = PlayerPedId()
            local vehicle = activeWorkshopJob.vehicle

            if not DoesEntityExist(vehicle) or GetVehiclePedIsIn(ped, false) ~= vehicle then
                CancelWorkshop(L("left_car"))
            elseif GetEntitySpeed(vehicle) > 2.0 then
                CancelWorkshop(L("car_moved"))
            end
        end

        Wait(activeWorkshopJob and 250 or 1000)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    isStopping = true
    if activeWorkshopJob then
        activeWorkshopJob = nil
    end
end)
--fivevault-j6OnIqTop-F : https://discord.gg/fivevault
--fivevault_X4Onq9Top3V : https://discord.gg/fivevault
--fivevaultsYlOnR-TopNH : https://discord.gg/fivevault
--fivevault-efOnpNTophf : https://discord.gg/fivevault
--fivevaultsLwOnSbTopNk : https://discord.gg/fivevault
