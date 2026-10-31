local hudSettings, nuiReady, playerLoaded, nuiQueue, hudFocusActive, hudVisible, hudManuallyHidden, infoBarVisible, newPlayerPending, cinematicMode, streamerMode, voiceAssistant, lastNeeds, mugshotHandle, mugshotTxd, mugshotPed, GetVehicleSeatFunc, adaptiveIntervalPed, adaptiveIntervalVehicle, hasBaseEvents
hudSettings = nil
nuiReady = false
playerLoaded = false
nuiQueue = {}
hudFocusActive = false
hudVisible = false
hudManuallyHidden = false
infoBarVisible = false
newPlayerPending = false
cinematicMode = false
streamerMode = false
voiceAssistant = true
lastNeeds = {}
lastNeeds.hunger = -1
lastNeeds.thirst = -1
mugshotHandle = nil
mugshotTxd = nil
mugshotPed = nil
currentCoin = 0

function GetVehicleSeatFunc(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = -2, maxPassengers, 1 do
        local pedInSeat = GetPedInVehicleSeat(vehicle, seat)
        if pedInSeat == ped then
            return seat
        end
    end
    return -2
end

function IsPlayerLoaded()
    return playerLoaded
end

function IsHudVisible()
    return hudVisible
end

function IsNuiReady()
    return nuiReady
end

function IsCinematicModeEnabled()
    return cinematicMode
end

function IsStreamerModeEnabled()
    return streamerMode
end

function IsVoiceAssistantEnabled()
    return voiceAssistant
end

function GetHudSettings()
    return hudSettings
end

function IsInfoBarVisible()
    return infoBarVisible
end

cache = {
    ped = PlayerPedId(),
    pid = PlayerId(),
    maxHp = 200,
    vehicle = 0,
    seat = -2,
    inVehicle = false
}

adaptiveIntervalPed = Utils.CreateAdaptiveInterval({min = 300, max = 1000, step = 100, threshold = 5})
adaptiveIntervalVehicle = Utils.CreateAdaptiveInterval({min = 100, max = 500, step = 50, threshold = 3})

hasBaseEvents = GetResourceState("baseevents") == "started"
if hasBaseEvents then
    debugPrint("[Core] Using baseevents for vehicle detection")
else
    debugPrint("[Core] Using fallback vehicle detection")
end

CreateThread(function()
    local lastPed = 0
    while true do
        Wait(adaptiveIntervalPed.current)
        local currentPed = PlayerPedId()
        cache.ped = currentPed
        cache.pid = PlayerId()
        cache.maxHp = GetEntityMaxHealth(cache.ped)
        if currentPed ~= lastPed then
            lastPed = currentPed
            adaptiveIntervalPed.onChanged()
        else
            adaptiveIntervalPed.onStable()
        end
    end
end)

if hasBaseEvents then
    RegisterNetEvent("baseevents:enteredVehicle", function(vehicle, seat, displayName, netId)
        debugPrint("[Core] baseevents:enteredVehicle received from server - vehicle:", vehicle, "seat:", seat, "displayName:", displayName)
        cache.inVehicle = true
        cache.vehicle = vehicle
        cache.seat = seat
        TriggerEvent("codem-hud:client:baseevents:enteredVehicle", vehicle, seat, displayName, netId)
    end)

    RegisterNetEvent("baseevents:leftVehicle", function(vehicle, seat, displayName, netId)
        debugPrint("[Core] baseevents:leftVehicle received from server")
        cache.inVehicle = false
        cache.vehicle = 0
        cache.seat = -2
        TriggerEvent("codem-hud:client:baseevents:leftVehicle")
    end)

    RegisterNetEvent("baseevents:enteringVehicle", function(vehicle, seat, displayName, netId)
        debugPrint("[Core] baseevents:enteringVehicle received from server - vehicle:", vehicle, "seat:", seat)
        TriggerEvent("codem-hud:client:baseevents:enteringVehicle", vehicle, seat, displayName, netId)
    end)

    RegisterNetEvent("baseevents:enteringAborted", function()
        debugPrint("[Core] baseevents:enteringAborted received from server")
        TriggerEvent("codem-hud:client:baseevents:enteringAborted")
    end)
else
    debugPrint("^2[Core] Starting fallback vehicle detection thread")
    CreateThread(function()
        while true do
            Wait(adaptiveIntervalVehicle.current)
            local isInVehicle = IsPedInAnyVehicle(cache.ped, false)
            local wasInVehicle = cache.inVehicle
            if isInVehicle ~= wasInVehicle then
                debugPrint("[Core] Fallback detected vehicle state change - inVeh:", isInVehicle)
                adaptiveIntervalVehicle.onChanged()
                cache.inVehicle = isInVehicle
                if isInVehicle then
                    cache.vehicle = Utils.GetCurrentVehicle()
                    cache.seat = GetVehicleSeatFunc(cache.ped)
                    local vehicleModel = GetEntityModel(cache.vehicle)
                    local displayName = GetDisplayNameFromVehicleModel(vehicleModel)
                    local labelText = nil
                    if displayName then
                        labelText = GetLabelText(displayName)
                    end
                    local vehicleName = displayName or labelText
                    if not vehicleName and not displayName then
                        vehicleName = "Unknown"
                    end
                    TriggerEvent("codem-hud:client:baseevents:enteredVehicle", cache.vehicle, cache.seat, vehicleName, 0)
                else
                    cache.vehicle = 0
                    cache.seat = -2
                    TriggerEvent("codem-hud:client:baseevents:leftVehicle")
                end
            else
                adaptiveIntervalVehicle.onStable()
            end
        end
    end)
end

CreateThread(function()
    while true do
        Wait(500)
        if cache.inVehicle then
            if cache.vehicle then
                if cache.vehicle ~= 0 then
                    local currentVehicle = GetVehiclePedIsIn(cache.ped, false)
                    if currentVehicle ~= 0 then
                        if currentVehicle ~= cache.vehicle then
                            debugPrint("[Core] Vehicle swap detected - old:", cache.vehicle, "new:", currentVehicle)
                            cache.vehicle = currentVehicle
                            cache.seat = GetVehicleSeatFunc(cache.ped)
                            local vehicleModel = GetEntityModel(currentVehicle)
                            local displayName = GetDisplayNameFromVehicleModel(vehicleModel)
                            local labelText = nil
                            if displayName then
                                labelText = GetLabelText(displayName)
                            end
                            local vehicleName = displayName or labelText
                            if not vehicleName and not displayName then
                                vehicleName = "Unknown"
                            end
                            TriggerEvent("codem-hud:client:baseevents:vehicleSwapped", currentVehicle, cache.seat, vehicleName, NetworkGetNetworkIdFromEntity(currentVehicle))
                        end
                    end
                end
            end
        end
    end
end)

local nuiMessagePayload = {action = "", data = false}
local emptyData = {}

function NuiMessage(action, data)
    if nuiReady then
        nuiMessagePayload.action = action
        local sendData = data or nuiMessagePayload
        if not data then
            sendData = emptyData
        end
        nuiMessagePayload.data = sendData
        SendNUIMessage(nuiMessagePayload)
    else
        local queueData = {}
        queueData.action = action
        local queuePayload = data or queueData
        if not data then
            queuePayload = {}
        end
        queueData.data = queuePayload
        table.insert(nuiQueue, queueData)
    end
end

function ProcessNuiQueue()
    for _, queuedMessage in ipairs(nuiQueue) do
        SendNUIMessage(queuedMessage)
    end
    nuiQueue = {}
end

function TryStartHud()
    if nuiReady then
        if playerLoaded then
            local identifier = GetPlayerIdentifier()
            NuiMessage("CHECK_SETTINGS", {identifier = identifier})
        end
    end
end

AddEventHandler("codem-hud:client:PlayerLoaded", function()
    playerLoaded = true
    TryStartHud()
end)

AddEventHandler("codem-hud:client:PlayerUnloaded", function()
    playerLoaded = false
    hudSettings = nil
    hudVisible = false
    hudManuallyHidden = false
    infoBarVisible = false
    hudFocusActive = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    TriggerEvent("codem-hud:client:HudVisibilityChanged", false)
    ResetMinimap()
    DisplayRadar(false)
    cache.inVehicle = false
    cache.vehicle = 0
    cache.seat = -2
    lastNeeds = {hunger = -1, thirst = -1}
    lastMoney = {cash = -1, bank = -1, marked = -1}
    lastJob = {name = "", label = "", rank = ""}
    lastAmmo = {current = -1, max = -1, total = -1}
    ammoVisible = false
    currentCoin = 0
    currentSocietyMoney = 0
    if mugshotHandle then
        UnregisterPedheadshot(mugshotHandle)
        mugshotHandle = nil
        mugshotTxd = nil
        mugshotPed = nil
    end
    NuiMessage("HIDE_HUD")
    StartRadarHideLoop()
end)

function StartHud(settings)
    SetMinimapStyle(settings.minimap)
    UpdateMinimapVisibility()
    local configData = {}
    local infoBarsEnabled = Config.InfoBarsEnabled
    if not infoBarsEnabled then
        infoBarsEnabled = {}
    end
    configData.infoBarsEnabled = infoBarsEnabled
    local defaultSettings = Config.DefaultSettings
    if not defaultSettings then
        defaultSettings = nil
    end
    NuiMessage("START_HUD", {
        settings = settings,
        config = configData,
        defaultSettings = defaultSettings
    })
    hudVisible = true
    TriggerEvent("codem-hud:client:HudVisibilityChanged", true)

    CreateThread(function()
        Wait(50)
        local foundVehicle = 0
        for attempt = 1, 8, 1 do
            local ped = cache.ped
            if not ped then
                ped = PlayerPedId()
            end
            cache.ped = ped
            local isInVeh = IsPedInAnyVehicle(ped, false)
            if isInVeh then
                local veh = GetVehiclePedIsIn(ped, false)
                foundVehicle = veh
                if foundVehicle and foundVehicle ~= 0 then
                    break
                end
            end
            foundVehicle = 0
            if attempt <= 3 then
                Wait(100)
            else
                Wait(300)
            end
        end
        if foundVehicle ~= 0 then
            local ped = cache.ped
            local seatFound = -1
            local maxPass = GetVehicleMaxNumberOfPassengers(foundVehicle) - 1
            for seatIdx = -1, maxPass, 1 do
                local pedInSeat = GetPedInVehicleSeat(foundVehicle, seatIdx)
                if pedInSeat == ped then
                    seatFound = seatIdx
                    break
                end
            end
            local vehicleModel = GetEntityModel(foundVehicle)
            local displayName = GetDisplayNameFromVehicleModel(vehicleModel)
            local labelText = nil
            if displayName then
                labelText = GetLabelText(displayName)
            end
            local vehicleName = displayName or labelText
            if not vehicleName and not displayName then
                vehicleName = "Unknown"
            end
            cache.inVehicle = true
            cache.vehicle = foundVehicle
            cache.seat = seatFound
            debugPrint("[Core] Restart vehicle detection - found vehicle:", foundVehicle, "seat:", seatFound)
            TriggerEvent("codem-hud:client:baseevents:enteredVehicle", foundVehicle, seatFound, vehicleName, NetworkGetNetworkIdFromEntity(foundVehicle))
        else
            UpdateMinimapVisibility()
        end
    end)

    CreateThread(function()
        Wait(100)
        SendInitialValues()
        SendPlayerInfo()
        CaptureMugshot()
        SendMoneyInfo()
        SendJobInfo()
        FetchPlayerCount()
        FetchSocietyMoney()
        SendKeybindsConfig()
        SendHudFocusKey()
        SendAvailableResources()
        if Config.Coin then
            if Config.Coin.Enabled then
                if currentCoin > 0 then
                    NuiMessage("updatePlayerInfo", {coin = currentCoin})
                end
            end
        end
    end)
end

function SendAvailableResources()
    local resources = {}
    local notifState = GetResourceState("codem-supreme-notification")
    resources.notification = notifState == "started"
    local radialState = GetResourceState("codem-supreme-radialmenu")
    resources.radialmenu = radialState == "started"
    local chatState = GetResourceState("codem-supreme-chat")
    resources.chat = chatState == "started"
    NuiMessage("SET_AVAILABLE_RESOURCES", resources)
end

function SendPlayerInfo()
    local playerInfo = GetPlayerInfo
    if playerInfo then
        playerInfo = GetPlayerInfo()
    end
    if not playerInfo then
        playerInfo = {}
        playerInfo.name = "Unknown"
        playerInfo.id = GetPlayerServerId(PlayerId())
    end

    local jobInfo = GetPlayerJob
    if jobInfo then
        jobInfo = GetPlayerJob()
    end
    if not jobInfo then
        jobInfo = nil
    end

    local jobDisplay = "Unemployed"
    if jobInfo then
        local jobName = jobInfo.name
        if not jobName then
            jobName = "unemployed"
        end
        local jobLabel = jobInfo.label
        if not jobLabel then
            jobLabel = "Unemployed"
        end
        local gradeLabel = jobInfo.gradeLabel
        if not gradeLabel then
            gradeLabel = ""
        end
        jobDisplay = FormatJobDisplay(jobName, jobLabel, gradeLabel)
    end

    NuiMessage("SET_PLAYER_INFO", {
        name = playerInfo.name,
        id = playerInfo.id,
        job = jobDisplay,
        server = Config.Settings.ServerName
    })
end

function CaptureMugshot()
    CreateThread(function()
        local ped = PlayerPedId()
        if mugshotPed == ped then
            if mugshotHandle then
                if IsPedheadshotValid(mugshotHandle) then
                    if IsPedheadshotReady(mugshotHandle) then
                        if mugshotTxd then
                            debugPrint("[Mugshot] Using cached mugshot for ped:", ped)
                            NuiMessage("SET_MUGSHOT", {txd = mugshotTxd})
                            return
                        end
                    end
                end
            end
        end

        debugPrint("[Mugshot] Starting capture for ped:", ped)
        if not DoesEntityExist(ped) then
            debugPrint("[Mugshot] Invalid ped")
            return
        end
        if not IsPedAPlayer(ped) then
            debugPrint("[Mugshot] Invalid ped")
            return
        end

        if mugshotHandle then
            UnregisterPedheadshot(mugshotHandle)
            mugshotHandle = nil
            mugshotTxd = nil
            mugshotPed = nil
        end

        Wait(50)
        mugshotHandle = RegisterPedheadshot(ped)
        if not mugshotHandle or mugshotHandle == 0 then
            debugPrint("[Mugshot] Invalid handle")
            return
        end

        local attempts = 0
        local maxAttempts = 100
        while true do
            if not (not IsPedheadshotReady(mugshotHandle) and attempts < maxAttempts) then
                break
            end
            Wait(50)
            attempts = attempts + 1
        end

        if not IsPedheadshotReady(mugshotHandle) then
            debugPrint("[Mugshot] Timeout after", attempts * 50, "ms")
            UnregisterPedheadshot(mugshotHandle)
            return
        end

        mugshotPed = ped
        mugshotTxd = GetPedheadshotTxdString(mugshotHandle)
        debugPrint("[Mugshot] Captured & cached TXD:", mugshotTxd)
        NuiMessage("SET_MUGSHOT", {txd = mugshotTxd})
    end)
end

local onlineCount = 0
local maxPlayers = 32

function FetchPlayerCount()
    if not playerLoaded or not hudVisible then
        return
    end

    if Config.InfoBarsEnabled then
        if Config.InfoBarsEnabled.onlineCount == false then
            return
        end
    end

    local result = RPC.execute("codem-hud:getPlayerCount")
    if result then
        local count = result.count
        if not count then
            count = 0
        end
        onlineCount = count
        local max = result.max
        if not max then
            max = 32
        end
        maxPlayers = max
        NuiMessage("updateServerInfo", {
            name = Config.Settings.ServerName,
            discord = Config.Settings.ServerDiscord,
            logo = Config.Settings.ServerLogo,
            onlineCount = onlineCount,
            maxPlayers = maxPlayers,
            moneySeparator = Config.Settings.MoneySeparator or ".",
            moneyPrefix = Config.Settings.MoneyPrefix or "$",
            moneyPosition = Config.Settings.MoneyPosition or "before",
            moneyColors = Config.Settings.MoneyColors
        })
    end
end

RegisterNetEvent("codem-hud:client:UpdatePlayerCount", function(count, max)
    if Config.InfoBarsEnabled then
        if Config.InfoBarsEnabled.onlineCount == false then
            return
        end
    end
    maxPlayers = max
    onlineCount = count
    if hudVisible then
        NuiMessage("updateServerInfo", {
            name = Config.Settings.ServerName,
            discord = Config.Settings.ServerDiscord,
            logo = Config.Settings.ServerLogo,
            onlineCount = onlineCount,
            maxPlayers = maxPlayers,
            moneySeparator = Config.Settings.MoneySeparator or ".",
            moneyPrefix = Config.Settings.MoneyPrefix or "$",
            moneyPosition = Config.Settings.MoneyPosition or "before",
            moneyColors = Config.Settings.MoneyColors
        })
    end
end)

function SendInitialValues()
    local ped = cache.ped
    local pid = cache.pid
    cache.maxHp = GetEntityMaxHealth(ped)
    if cache.maxHp <= 100 then
        cache.maxHp = 200
    end
    local healthPercent = Utils.clamp((GetEntityHealth(ped) - 100) / (cache.maxHp - 100) * 100)
    local armorPercent = Utils.clamp(GetPedArmour(ped))
    local isUnderwater = IsPedSwimmingUnderWater(ped)
    local staminaPercent
    if isUnderwater then
        local underwaterTime = GetPlayerUnderwaterTimeRemaining(pid) * 10
        if underwaterTime and underwaterTime > 0 then
            staminaPercent = underwaterTime
        else
            staminaPercent = 100 - GetPlayerSprintStaminaRemaining(pid)
        end
    else
        staminaPercent = 100 - GetPlayerSprintStaminaRemaining(pid)
    end
    staminaPercent = Utils.clamp(staminaPercent)

    NuiMessage("updateHealth", {health = healthPercent})
    NuiMessage("updateArmor", {armor = armorPercent})
    NuiMessage("updateStamina", {stamina = staminaPercent, isUnderwater = isUnderwater})

    local needs = GetPlayerNeeds
    if needs then
        needs = GetPlayerNeeds()
    end
    if not needs then
        needs = {hunger = 100, thirst = 100}
    end

    NuiMessage("updateNeeds", {hunger = needs.hunger, thirst = needs.thirst})
end

RegisterNUICallback("START_HUD_WITH_SETTINGS", function(data, cb)
    local settings = {}
    settings.hud = data.hud
    if not settings.hud then
        settings.hud = "supreme-default"
    end
    settings.speedometer = data.speedometer
    if not settings.speedometer then
        settings.speedometer = "supreme-rectangular"
    end
    settings.minimap = data.minimap
    if not settings.minimap then
        settings.minimap = "rectangular"
    end
    hudSettings = settings
    debugPrint("[Core] START_HUD_WITH_SETTINGS received - minimap:", data.minimap, "-> HudSettings.minimap:", hudSettings.minimap)
    SetNuiFocus(false, false)
    StartHud(hudSettings)
    cb("ok")
end)

RegisterNUICallback("REQUEST_FOCUS", function(data, cb)
    SetNuiFocus(data.focus or false, data.focus or false)
    cb("ok")
end)

local screenResolution = {width = 0, height = 0}

local function CheckScreenResolution()
    local width, height = GetActiveScreenResolution()
    if width ~= screenResolution.width or height ~= screenResolution.height then
        screenResolution.width = width
        screenResolution.height = height
        NuiMessage("setScreenResolution", {width = width, height = height})
        debugPrint("[Core] Screen resolution changed:", width, "x", height)
        return true
    end
    return false
end

RegisterNUICallback("NUI_READY", function(data, cb)
    local resourceName = GetCurrentResourceName()
    if resourceName ~= "codem-supreme-hud" then
        SendNUIMessage({action = "INVALID_RESOURCE_NAME"})
        cb("error")
        return
    end

    nuiReady = true

    NuiMessage("setDebugMode", {enabled = Config.Debug or false})

    local serverConfig = {}
    if Config.VoiceAssistant and Config.VoiceAssistant.Enabled then
        serverConfig.voiceAssistantEnabled = true
    else
        serverConfig.voiceAssistantEnabled = false
    end
    if Config.UI and Config.UI.BlurEnabled then
        serverConfig.blurEnabled = true
    else
        serverConfig.blurEnabled = false
    end
    if Config.ManualTransmission and Config.ManualTransmission.Enabled then
        serverConfig.manualTransmissionEnabled = true
    else
        serverConfig.manualTransmissionEnabled = false
    end
    if Config.VehicleMods and Config.VehicleMods.Enabled then
        serverConfig.vehicleModsEnabled = true
    else
        serverConfig.vehicleModsEnabled = false
    end
    if Config.VehicleMusic and Config.VehicleMusic.Enabled then
        serverConfig.vehicleMusicEnabled = true
    else
        serverConfig.vehicleMusicEnabled = false
    end
    if Config.Stress and Config.Stress.Enabled then
        serverConfig.stressEnabled = true
    else
        serverConfig.stressEnabled = false
    end
    NuiMessage("setServerConfig", serverConfig)

    NuiMessage("updateServerInfo", {
        name = Config.Settings.ServerName,
        discord = Config.Settings.ServerDiscord,
        logo = Config.Settings.ServerLogo,
        onlineCount = 0,
        maxPlayers = 32,
        moneySeparator = Config.Settings.MoneySeparator or ".",
        moneyPrefix = Config.Settings.MoneyPrefix or "$",
        moneyPosition = Config.Settings.MoneyPosition or "before",
        moneyColors = Config.Settings.MoneyColors
    })

    CheckScreenResolution()
    ProcessNuiQueue()
    TryStartHud()
    cb("ok")
end)

CreateThread(function()
    Wait(2000)
    while true do
        Wait(2000)
        if nuiReady then
            if CheckScreenResolution() then
                Wait(100)
                if hudSettings then
                    if hudSettings.minimap then
                        TriggerEvent("codem-hud:client:RecalculateMinimap")
                    end
                end
            end
        end
    end
end)

RegisterNUICallback("NEW_PLAYER_PENDING_SETUP", function(data, cb)
    newPlayerPending = true
    cb("ok")
    if Config.AutoHudSetup == false then
        return
    end
    CreateThread(function()
        Wait(10000)
        local elapsed = 0
        while true do
            if not (newPlayerPending and elapsed < 600) then
                break
            end
            Wait(500)
            elapsed = elapsed + 1
            local ped = PlayerPedId()
            local isNuiFocused = IsNuiFocused()
            local isFrozen = IsEntityPositionFrozen(ped)
            local isControlOn = IsPlayerControlOn(PlayerId())
            if not isNuiFocused and not isFrozen and isControlOn then
                Wait(1000)
                if not IsNuiFocused() then
                    if not IsEntityPositionFrozen(PlayerPedId()) then
                        newPlayerPending = false
                        NuiMessage("TRIGGER_SETUP")
                    end
                end
            end
        end
        if elapsed >= 600 then
            newPlayerPending = false
            NuiMessage("TRIGGER_SETUP")
        end
    end)
end)

RegisterNetEvent("codem-hud:client:TriggerSetup", function()
    newPlayerPending = false
    NuiMessage("TRIGGER_SETUP")
end)

RegisterNUICallback("SET_INFOBAR_VISIBLE", function(data, cb)
    infoBarVisible = data.visible or false
    if not infoBarVisible then
        lastTimeWeather = {time = "", weather = "", isNight = nil}
    end
    cb("ok")
end)

RegisterNUICallback("SET_CINEMATIC_MODE", function(data, cb)
    cinematicMode = data.enabled or false
    TriggerEvent("codem-hud:client:CinematicModeChanged", cinematicMode)
    UpdateMinimapVisibility()
    cb("ok")
end)

RegisterNUICallback("SET_STREAMER_MODE", function(data, cb)
    streamerMode = data.enabled or false
    TriggerEvent("codem-hud:client:StreamerModeChanged", streamerMode)
    cb("ok")
end)

RegisterNUICallback("SET_VOICE_ASSISTANT", function(data, cb)
    voiceAssistant = data.enabled
    if voiceAssistant == nil then
        voiceAssistant = true
    end
    TriggerEvent("codem-hud:client:VoiceAssistantChanged", voiceAssistant)
    cb("ok")
end)

RegisterNUICallback("SET_STATUSBAR_TYPE", function(data, cb)
    local statusBarType = data.type or "supreme-percentage"
    TriggerEvent("codem-hud:client:StatusBarTypeChanged", statusBarType)
    cb("ok")
end)

RegisterNUICallback("SET_REFRESH_RATE", function(data, cb)
    local refreshRate = data.refreshRate or 0
    Utils.SetRefreshRate(refreshRate)
    TriggerEvent("codem-hud:client:RefreshRateChanged", refreshRate)
    cb("ok")
end)

RegisterNUICallback("SET_SPEEDO_REFRESH_RATE", function(data, cb)
    local refreshRate = data.refreshRate or 60
    if refreshRate == 0 then
        SpeedoRefreshMs = 0
    elseif refreshRate == 60 then
        SpeedoRefreshMs = 50
    elseif refreshRate == 45 then
        SpeedoRefreshMs = 100
    elseif refreshRate == 30 then
        SpeedoRefreshMs = 200
    else
        SpeedoRefreshMs = 50
    end
    cb("ok")
end)

local blockChatInNui = false
local disabledControlsInNui = Constants.DisabledControlsInNui
local CHAT_CONTROL = Constants.Controls.CHAT
local mouseControlActive = false

function DisableMouseControl()
    if mouseControlActive then
        return
    end
    mouseControlActive = true
    CreateThread(function()
        while hudFocusActive do
            for i = 1, #disabledControlsInNui, 1 do
                DisableControlAction(0, disabledControlsInNui[i], true)
            end
            if blockChatInNui then
                DisableControlAction(0, CHAT_CONTROL, true)
            end
            Wait(0)
        end
        mouseControlActive = false
    end)
end

function ToggleHudFocus()
    if IsSettingsOpen then
        if IsSettingsOpen() then
            return
        end
    end
    if PlacementEditorOpen then
        return
    end
    if not cache.inVehicle then
        return
    end
    hudFocusActive = not hudFocusActive
    SetNuiFocus(hudFocusActive, hudFocusActive)
    SetNuiFocusKeepInput(hudFocusActive)
    NuiMessage("setAltPressed", {pressed = hudFocusActive})
    if hudFocusActive then
        DisableMouseControl()
        CreateThread(function()
            while hudFocusActive do
                if IsControlJustPressed(0, 174) then
                    NuiMessage("circularPageNav", {direction = "prev"})
                end
                if IsControlJustPressed(0, 175) then
                    NuiMessage("circularPageNav", {direction = "next"})
                end
                Wait(5)
            end
        end)
    end
end

local controlKeyMap = {
    [0] = "V",
    [10] = "PgUp",
    [11] = "PgDn",
    [18] = "Enter",
    [19] = "Alt",
    [20] = "Z",
    [21] = "Shift",
    [22] = "Space",
    [23] = "F",
    [26] = "C",
    [29] = "B",
    [36] = "Ctrl",
    [37] = "Tab",
    [38] = "E",
    [44] = "Q",
    [45] = "R",
    [47] = "G",
    [51] = "E",
    [56] = "F9",
    [57] = "F10",
    [73] = "X",
    [74] = "H",
    [80] = "R",
    [86] = "E",
    [121] = "Ins",
    [137] = "Caps",
    [157] = "1",
    [158] = "2",
    [159] = "6",
    [160] = "3",
    [161] = "7",
    [162] = "8",
    [163] = "9",
    [164] = "4",
    [165] = "5",
    [166] = "F5",
    [167] = "F6",
    [168] = "F7",
    [169] = "F8",
    [170] = "F3",
    [171] = "Caps",
    [172] = "Up",
    [173] = "Down",
    [174] = "Left",
    [175] = "Right",
    [177] = "Back",
    [178] = "Del",
    [182] = "L",
    [199] = "P",
    [200] = "Esc",
    [243] = "~",
    [244] = "M",
    [245] = "T",
    [246] = "Y",
    [249] = "N"
}
controlKeyMap[288] = "F1"
controlKeyMap[289] = "F2"
controlKeyMap[303] = "U"
controlKeyMap[305] = "B"
controlKeyMap[306] = "N"
controlKeyMap[311] = "K"
controlKeyMap[344] = "F11"

local focusKeyMode = Config.HudFocusKeyMode or "controls"
local focusKey = Config.HudFocusKey or 19
local focusKeyMapLabel = Config.HudFocusKeyMapLabel or "Alt"

if focusKeyMode == "keymapping" then
    RegisterCommand("+codemHudFocus", function()
        if cache.inVehicle then
            ToggleHudFocus()
        end
    end, false)
    RegisterCommand("-codemHudFocus", function()
    end, false)
    RegisterKeyMapping("+codemHudFocus", "Toggle HUD Focus", "keyboard", Config.HudFocusKeyMap or "LMENU")
else
    CreateThread(function()
        while true do
            if cache.inVehicle then
                DisableControlAction(0, focusKey, true)
                if IsDisabledControlJustPressed(0, focusKey) then
                    ToggleHudFocus()
                end
                Wait(0)
            else
                Wait(500)
            end
        end
    end)
end

function SendHudFocusKey()
    local keyLabel = nil
    if focusKeyMode == "keymapping" then
        keyLabel = focusKeyMapLabel
    else
        local mapped = controlKeyMap[focusKey]
        keyLabel = mapped or keyLabel
        if not mapped then
            keyLabel = tostring(focusKey)
        end
    end
    NuiMessage("setHudFocusKey", {key = keyLabel})
end

RegisterNUICallback("INPUT_FOCUS", function(data, cb)
    if IsSettingsOpen then
        if IsSettingsOpen() then
            cb("ok")
            return
        end
    end
    blockChatInNui = data.focused or false
    if hudFocusActive then
        SetNuiFocusKeepInput(not blockChatInNui)
    end
    cb("ok")
end)

RegisterNUICallback("copyToClipboard", function(data, cb)
    cb("ok")
end)

function CloseNuiFocusIfOpen()
    if hudFocusActive then
        hudFocusActive = false
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        NuiMessage("setAltPressed", {pressed = false})
    end
end

function UpdateNeeds(hungerValue, thirstValue)
    if not playerLoaded or not hudSettings then
        return
    end

    local hunger = math.floor(hungerValue or 0)
    local thirst = math.floor(thirstValue or 0)
    if hunger ~= lastNeeds.hunger or thirst ~= lastNeeds.thirst then
        lastNeeds.thirst = thirst
        lastNeeds.hunger = hunger
        NuiMessage("updateNeeds", {hunger = hunger, thirst = thirst})
    end
end

lastMoney = {cash = -1, bank = -1, marked = -1}
currentSocietyMoney = 0

function GetCurrentSocietyMoney()
    return currentSocietyMoney
end

function UpdateMoney(cash, bank, marked, changeType, changeAmount, changeLabel, changeIsMinus)
    if not playerLoaded or not hudVisible then
        return
    end

    cash = math.floor(cash or 0)
    bank = math.floor(bank or 0)
    local hasMarked = marked ~= nil and marked > 0
    if hasMarked then
        marked = math.floor(marked)
    end

    local cashChanged = cash ~= lastMoney.cash
    if hasMarked and not cashChanged then
        cashChanged = marked ~= lastMoney.marked
    end

    if cashChanged then
        lastMoney.bank = bank
        lastMoney.cash = cash
        if hasMarked then
            lastMoney.marked = marked
        end
        local nuiData = {cash = cash, bank = bank}
        if hasMarked then
            nuiData.marked = marked
        end
        if changeType and changeAmount and changeAmount > 0 then
            local changeData = {
                type = changeType,
                amount = math.floor(changeAmount)
            }
            local isMinus = changeIsMinus or changeData
            if not changeIsMinus then
                isMinus = false
            end
            changeData.isMinus = isMinus
            nuiData.change = changeData
        end
        NuiMessage("updatePlayerInfo", nuiData)
    end
end

function SendMoneyInfo()
    if not playerLoaded or not hudVisible then
        return
    end

    local playerData = GetPlayerData
    if playerData then
        playerData = GetPlayerData()
    end
    if not playerData then
        return
    end

    local cash = 0
    local bank = 0
    local marked = 0
    local moneyField = playerData.money
    if moneyField then
        if type(playerData.money) == "table" then
            local cashVal = playerData.money.cash
            cash = cashVal or cash
            if not cashVal then
                cash = 0
            end
            local bankVal = playerData.money.bank
            bank = bankVal or bank
            if not bankVal then
                bank = 0
            end
        end
    else
        local accounts = playerData.accounts
        if accounts then
            for _, account in ipairs(playerData.accounts) do
                if account.name == "money" then
                    local moneyVal = account.money
                    cash = moneyVal or cash
                    if not moneyVal then
                        cash = 0
                    end
                elseif account.name == "bank" then
                    local bankVal = account.money
                    bank = bankVal or bank
                    if not bankVal then
                        bank = 0
                    end
                elseif account.name == "black_money" then
                    local markedVal = account.money
                    marked = markedVal or marked
                    if not markedVal then
                        marked = 0
                    end
                end
            end
        end
    end
    UpdateMoney(cash, bank, marked)
end

function FetchSocietyMoney()
    if not playerLoaded or not hudVisible then
        return
    end

    local result = RPC.execute("codem-hud:getSocietyMoney")
    if result == false or result == nil then
        currentSocietyMoney = 0
        NuiMessage("updatePlayerInfo", {society = -1})
        return
    end
    local newAmount = tonumber(result) or 0
    local oldAmount = currentSocietyMoney
    currentSocietyMoney = newAmount
    local nuiData = {society = newAmount}
    if oldAmount > 0 and newAmount ~= oldAmount then
        local diff = newAmount - oldAmount
        nuiData.change = {
            type = "society",
            amount = math.abs(diff),
            isMinus = diff < 0
        }
    end
    NuiMessage("updatePlayerInfo", nuiData)
end

RegisterNetEvent("codem-hud:RefreshSociety", function()
    if playerLoaded then
        if hudVisible then
            SetTimeout(150, FetchSocietyMoney)
        end
    end
end)

lastJob = {name = "", label = "", rank = ""}

function GetJobAbbreviation(jobName)
    if not Config.JobDisplay.UseAbbreviations then
        return nil
    end
    return Config.JobDisplay.Abbreviations[jobName]
end

function FormatJobDisplay(jobName, jobLabel, gradeLabel)
    local abbreviation = GetJobAbbreviation(jobName)
    local display = abbreviation or jobName
    display = jobLabel or display
    if not abbreviation and not jobLabel then
        display = "Citizen"
    end
    if gradeLabel and gradeLabel ~= "" then
        return display .. " | " .. gradeLabel
    end
    return display
end

function SendJobInfo()
    if not playerLoaded or not hudVisible then
        return
    end

    local jobData = GetPlayerJob
    if jobData then
        jobData = GetPlayerJob()
    end
    if not jobData then
        NuiMessage("updatePlayerInfo", {job = "Citizen"})
        return
    end

    local jobName = jobData.name or "unemployed"
    local jobLabel = jobData.label or "Unemployed"
    local gradeLabel = jobData.gradeLabel
    if not gradeLabel then
        gradeLabel = jobData.grade_label
        if not gradeLabel then
            gradeLabel = ""
        end
    end

    if jobName ~= lastJob.name or gradeLabel ~= lastJob.rank then
        lastJob.rank = gradeLabel
        lastJob.label = jobLabel
        lastJob.name = jobName
        NuiMessage("updatePlayerInfo", {job = FormatJobDisplay(jobName, jobLabel, gradeLabel)})
    end
end

function UpdateJob(jobName, jobLabel, gradeLabel)
    if not playerLoaded or not hudVisible then
        return
    end

    if jobName ~= lastJob.name or gradeLabel ~= lastJob.rank then
        local actualGrade = gradeLabel or ""
        lastJob.rank = actualGrade
        lastJob.label = jobLabel
        lastJob.name = jobName
        NuiMessage("updatePlayerInfo", {job = FormatJobDisplay(jobName, jobLabel, gradeLabel)})
    end
end

function UpdateCoin(amount, changeAmount, isMinus)
    if not playerLoaded or not hudVisible then
        return
    end

    if not Config.Coin.Enabled then
        return
    end

    amount = math.floor(amount or 0)
    if amount == currentCoin and not changeAmount then
        return
    end
    currentCoin = amount
    local nuiData = {coin = amount}
    if changeAmount and changeAmount > 0 then
        nuiData.change = {
            type = "coin",
            amount = math.floor(changeAmount),
            isMinus = isMinus or false
        }
    end
    NuiMessage("updatePlayerInfo", nuiData)
end

function SetCoin(amount)
    amount = math.floor(amount or 0)
    currentCoin = amount
    UpdateCoin(amount)
end

function AddCoin(amount)
    if not Config.Coin.Enabled then
        return
    end
    amount = math.floor(amount or 0)
    if amount <= 0 then
        return
    end
    UpdateCoin(currentCoin + amount, amount, false)
end

function RemoveCoin(amount)
    if not Config.Coin.Enabled then
        return
    end
    amount = math.floor(amount or 0)
    if amount <= 0 then
        return
    end
    UpdateCoin(math.max(0, currentCoin - amount), amount, true)
end

function GetCoin()
    return currentCoin
end

exports("SetCoin", SetCoin)
exports("AddCoin", AddCoin)
exports("RemoveCoin", RemoveCoin)
exports("GetCoin", GetCoin)

RegisterNetEvent("codem-hud:client:SetCoin", function(amount)
    SetCoin(amount)
end)

RegisterNetEvent("codem-hud:client:AddCoin", function(amount)
    AddCoin(amount)
end)

RegisterNetEvent("codem-hud:client:RemoveCoin", function(amount)
    RemoveCoin(amount)
end)

RegisterNetEvent("codem-hud:client:UpdateCoin", function(amount, changeAmount, isMinus)
    UpdateCoin(amount, changeAmount, isMinus)
end)

function SendKeybindsConfig()
    if not playerLoaded or not hudVisible then
        return
    end

    if not Config.Keybinds.Enabled then
        NuiMessage("setKeybindsVisible", {visible = false})
        return
    end
    NuiMessage("updateKeybinds", {items = Config.Keybinds.Items})
    NuiMessage("setKeybindsVisible", {visible = true})
end

function SetKeybindsVisible(visible)
    NuiMessage("setKeybindsVisible", {visible = visible})
end

function SetKeybindVisible(id, visible)
    NuiMessage("setKeybindVisible", {id = id, visible = visible})
end

function UpdateKeybinds(items)
    NuiMessage("updateKeybinds", {items = items})
end

RegisterNetEvent("codem-hud:client:SetKeybindsVisible", function(visible)
    SetKeybindsVisible(visible)
end)

RegisterNetEvent("codem-hud:client:SetKeybindVisible", function(id, visible)
    SetKeybindVisible(id, visible)
end)

RegisterNetEvent("codem-hud:client:UpdateKeybinds", function(items)
    UpdateKeybinds(items)
end)

lastAmmo = {current = -1, max = -1, total = -1}
ammoVisible = false

local function IsWeaponValid(weaponHash)
    if weaponHash == -1569615261 then
        return false
    end
    return GetPedAmmoTypeFromWeapon(cache.ped, weaponHash) ~= 0
end

function UpdateAmmoDisplay()
    if not playerLoaded or not hudVisible then
        return
    end

    local ped = cache.ped
    local weapon = GetSelectedPedWeapon(ped)
    if not IsWeaponValid(weapon) then
        if ammoVisible then
            ammoVisible = false
            NuiMessage("setAmmoVisible", {visible = false})
        end
        return
    end

    local _, clipAmmo = GetAmmoInClip(ped, weapon)
    local maxClip = GetMaxAmmoInClip(ped, weapon, true)
    local totalAmmo = GetAmmoInPedWeapon(ped, weapon) - clipAmmo

    if not ammoVisible then
        ammoVisible = true
        NuiMessage("setAmmoVisible", {visible = true})
    end

    if clipAmmo ~= lastAmmo.current or maxClip ~= lastAmmo.max or totalAmmo ~= lastAmmo.total then
        lastAmmo.current = clipAmmo
        lastAmmo.max = maxClip
        lastAmmo.total = totalAmmo
        NuiMessage("updateAmmo", {current = clipAmmo, max = maxClip, total = math.max(0, totalAmmo)})
    end
end

function HideHud()
    if not hudVisible then
        return
    end
    hudManuallyHidden = true
    hudVisible = false
    NuiMessage("setVisible", {visible = false})
    TriggerEvent("codem-hud:client:HudVisibilityChanged", false)
    UpdateMinimapVisibility()
    debugPrint("[Core] HUD manually hidden")
end

function ShowHud()
    if not hudManuallyHidden then
        return
    end
    if not playerLoaded or not nuiReady then
        return
    end
    hudManuallyHidden = false
    hudVisible = true
    NuiMessage("setVisible", {visible = true})
    TriggerEvent("codem-hud:client:HudVisibilityChanged", true)
    UpdateMinimapVisibility()
    debugPrint("[Core] HUD manually shown")
end

function ToggleHud()
    if not playerLoaded then
        return
    end
    if IsSettingsOpen then
        if IsSettingsOpen() then
            return
        end
    end
    if hudManuallyHidden then
        ShowHud()
    else
        HideHud()
    end
end

function IsHudManuallyHidden()
    return hudManuallyHidden
end

exports("ToggleHud", ToggleHud)
exports("ShowHud", ShowHud)
exports("HideHud", HideHud)
exports("IsHudHidden", IsHudManuallyHidden)

AddEventHandler("codem-hud:client:ToggleHud", ToggleHud)
AddEventHandler("codem-hud:client:ShowHud", ShowHud)
AddEventHandler("codem-hud:client:HideHud", HideHud)

if Config.ToggleHud then
    if Config.ToggleHud.Command then
        RegisterCommand(Config.ToggleHud.Command, function()
            ToggleHud()
        end, false)
    end
    if Config.ToggleHud.Keybind then
        RegisterCommand("codem_hud_toggle", function()
            ToggleHud()
        end, false)
        RegisterKeyMapping("codem_hud_toggle", Config.ToggleHud.KeybindDescription or "Toggle HUD Visibility", "keyboard", Config.ToggleHud.Keybind)
    end
end

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    hudFocusActive = false
    nuiReady = false
    hudVisible = false
    hudManuallyHidden = false
    mouseControlActive = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    debugPrint("[Core] Resource stopped, state cleaned up")
end)

AddEventHandler("codem-phone:onNotification", function(isHidden)
    if isHidden then
        return
    end
    NuiMessage("phoneNotification", {active = true})
    SetTimeout(5000, function()
        NuiMessage("phoneNotification", {active = false})
    end)
end)

CreateThread(function()
    while true do
        Wait(10000)
        if playerLoaded then
            if nuiReady then
                if not hudVisible then
                    if not hudManuallyHidden then
                        debugPrint("[Core] Watchdog: HUD failed to start, resending CHECK_SETTINGS")
                        TryStartHud()
                    end
                end
            end
        end
    end
end)
