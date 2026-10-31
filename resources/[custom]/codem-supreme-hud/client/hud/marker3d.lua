local Marker3DEnabled = true
local isDisplaying = false
local targetCoords = {}

local MAX_DRAW_DISTANCE = 99999.0
local LOD_MEDIUM = 350.0
local LOD_FAR = 600.0
local BEAM_MAX_RENDER = 99999.0
local BEAM_HEIGHT = 150.0
local DEFAULT_COLOR = { r = 255, g = 255, b = 255 }

local sin, cos, floor = math.sin, math.cos, math.floor
local DM = DrawMarker

local duiObj = nil
local duiTxdName = "marker3d_txd"
local duiTexName = "marker3d_tex"
local duiReadyAt = 0
local lastDistText = ""
local lastDuiUpdate = 0
local DUI_UPDATE_INTERVAL = 200

function IsMarker3DEnabled() return Marker3DEnabled end

local function InitDui()
    if duiObj then return end
    local resourceName = GetCurrentResourceName()
    local formattedDuiTxdName = 'nui://'..resourceName..'/html/marker3d.html'
    duiObj = CreateDui(formattedDuiTxdName, 512, 512)
    local handle = GetDuiHandle(duiObj)
    local txd = CreateRuntimeTxd(duiTxdName)
    CreateRuntimeTextureFromDuiHandle(txd, duiTexName, handle)
    duiReadyAt = GetGameTimer() + 3000
end

local function pulse(timer, speed, minVal, maxVal)
    return minVal + (maxVal - minVal) * (0.5 + 0.5 * sin(timer * speed))
end

local function FormatDistance(distance)
    if distance < 1000 then
        return string.format("%d m", floor(distance))
    else
        return string.format("%.1f km", distance / 1000)
    end
end

local function IsDuiReady()
    return duiObj and duiReadyAt > 0 and GetGameTimer() >= duiReadyAt
end

local function UpdateDuiDistance(distText)
    if not IsDuiReady() then return end
    if distText == lastDistText then return end
    local now = GetGameTimer()
    if now - lastDuiUpdate < DUI_UPDATE_INTERVAL then return end
    lastDistText = distText
    lastDuiUpdate = now
    SendDuiMessage(duiObj, json.encode({ distance = distText }))
end

local function DrawDuiMarker(x, y, z, distance)
    if not IsDuiReady() then return end

    local size = 0.055
    if distance < 60.0 then
        size = 0.035 + (distance / 60.0) * 0.020
    end

    local markerZ = z + 6.0

    SetDrawOrigin(x, y, markerZ, 0)
    DrawSprite(duiTxdName, duiTexName, 0.0, 0.0, size, size * GetAspectRatio(false), 0.0, 255, 255, 255, 255)
    ClearDrawOrigin()
end

local function DrawBeam(target, distance, timer)
    if distance > BEAM_MAX_RENDER then return end

    local x, y, z = target.coords.x, target.coords.y, target.coords.z
    local color = target.color or DEFAULT_COLOR
    local distFactor = math.min(distance / 100.0, 10.0)

    local beamW = 0.5 + distFactor * 2.0
    local beamInnerW = 0.2 + distFactor * 0.8
    local beamH = BEAM_HEIGHT + distFactor * 30.0
    local beamAlpha = floor(pulse(timer, 0.002, 80, 160))

    DM(1, x, y, z, 0, 0, 0, 0, 0, 0,
        beamW, beamW, beamH,
        color.r, color.g, color.b, beamAlpha,
        false, false, 2, false, nil, nil, false)

    DM(1, x, y, z, 0, 0, 0, 0, 0, 0,
        beamInnerW, beamInnerW, beamH,
        255, 255, 255, floor(beamAlpha * 0.5),
        false, false, 2, false, nil, nil, false)
end

local function DrawGroundEffects(target, distance, timer)
    if distance > LOD_FAR then return end

    local x, y, z = target.coords.x, target.coords.y, target.coords.z
    local color = target.color or DEFAULT_COLOR
    local distFactor = math.min(distance / 100.0, 8.0)

    local glowBase = 4.0 + distFactor * 1.5
    local glowSize = pulse(timer, 0.002, glowBase * 0.8, glowBase * 1.2)
    DM(25, x, y, z + 0.03, 0, 0, 0, 0, 0, 0,
        glowSize, glowSize, 0.5,
        color.r, color.g, color.b, floor(pulse(timer, 0.003, 30, 70)),
        false, false, 2, false, nil, nil, false)

    local ringBase = 2.0 + distFactor * 0.8
    local ringSize = pulse(timer, 0.003, ringBase * 0.85, ringBase * 1.15)
    local ringAlpha = floor(pulse(timer, 0.004, 100, 200))
    DM(25, x, y, z + 0.05, 0, 0, 0, 0, 0, 0,
        ringSize, ringSize, 0.3,
        color.r, color.g, color.b, ringAlpha,
        false, false, 2, false, nil, nil, false)

    local whiteRing = 1.0 + distFactor * 0.4
    DM(25, x, y, z + 0.06, 0, 0, 0, 0, 0, 0,
        whiteRing, whiteRing, 0.2,
        255, 255, 255, floor(ringAlpha * 0.5),
        false, false, 2, false, nil, nil, false)
end

local function DrawRotatingRings(target, distance, timer)
    if distance > LOD_MEDIUM then return end

    local x, y, z = target.coords.x, target.coords.y, target.coords.z
    local color = target.color or DEFAULT_COLOR
    local distFactor = math.min(distance / 100.0, 5.0)
    local ringScale = 2.0 + distFactor * 0.8
    local rotZ = (timer * 0.06) % 360.0
    local ringAlpha = floor(pulse(timer, 0.003, 50, 120))

    DM(6, x, y, z + 2.5, 0, 0, 0, 0, 0, rotZ,
        ringScale, ringScale, ringScale,
        color.r, color.g, color.b, ringAlpha,
        false, false, 2, false, nil, nil, false)

    DM(6, x, y, z + 2.5, 0, 0, 0, 0, 0, rotZ + 90.0,
        ringScale, ringScale, ringScale,
        color.r, color.g, color.b, floor(ringAlpha * 0.6),
        false, false, 2, false, nil, nil, false)
end

local function DrawMarker3DFull(target, distance, timer)
    local x, y, z = target.coords.x, target.coords.y, target.coords.z

    local distText = FormatDistance(distance)
    UpdateDuiDistance(distText)
    DrawDuiMarker(x, y, z, distance)

    DrawBeam(target, distance, timer)
    DrawGroundEffects(target, distance, timer)
    DrawRotatingRings(target, distance, timer)

    -- Label only (distance is on DUI now)
    if target.label and target.label ~= '' and distance <= (target.labelDistance or 10.0) then
        local distFactor = math.min(distance / 100.0, 10.0)
        local textZ = z + 5.0 + distFactor * 3.0
        SetTextScale(0.0, 0.30)
        SetTextFont(0)
        SetTextProportional(true)
        SetTextColour(255, 255, 255, 230)
        SetTextDropshadow(2, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 255)
        SetTextDropShadow()
        SetTextOutline()
        SetTextCentre(true)
        BeginTextCommandDisplayText("STRING")
        AddTextComponentSubstringPlayerName(target.label)
        SetDrawOrigin(x, y, textZ, 0)
        EndTextCommandDisplayText(0.0, 0.0)
        ClearDrawOrigin()
    end
end

RegisterNUICallback('SET_MARKER3D_ENABLED', function(data, cb)
    Marker3DEnabled = data.enabled
    if Marker3DEnabled == nil then Marker3DEnabled = true end

    if Marker3DEnabled then
        if not isDisplaying then
            isDisplaying = true
            StartShowingMarkers()
        end
    else
        isDisplaying = false
    end
    cb('ok')
end)

function StartShowingMarkers()
    local playerCoords = vector3(0, 0, 0)

    CreateThread(function()
        while isDisplaying do
            playerCoords = GetEntityCoords(cache.ped)
            Wait(1000)
        end
    end)

    CreateThread(function()
        while isDisplaying do
            local drawn = false
            local timer = GetGameTimer()

            for name, target in pairs(targetCoords) do
                if target.show and not target.hide then
                    local distance = #(playerCoords - target.coords)

                    if target.autoCompleteOnArrival and distance <= target.autoCompleteOnArrival then
                        targetCoords[name] = nil
                    elseif distance <= MAX_DRAW_DISTANCE then
                        DrawMarker3DFull(target, distance, timer)
                        drawn = true
                    end
                end
            end

            if drawn then
                Wait(0)
            else
                Wait(500)
            end
        end
    end)
end

CreateThread(function()
    while true do
        if NetworkIsPlayerActive(PlayerId()) then break end
        Wait(500)
    end
    Wait(1500)

    -- DUI loads in background, markers start immediately
    CreateThread(InitDui)

    if Marker3DEnabled then
        isDisplaying = true
        StartShowingMarkers()

        -- Detect existing waypoint immediately on restart
        if IsWaypointActive() then
            local waypointBlip = GetFirstBlipInfoId(8)
            if DoesBlipExist(waypointBlip) then
                local wc = GetBlipInfoIdCoord(waypointBlip)
                local _, gz = GetGroundZFor_3dCoord(wc.x, wc.y, 1000.0, false)
                if gz == 0.0 then gz = GetEntityCoords(cache.ped).z end
                targetCoords['playerWaypoint'] = {
                    coords = vector3(wc.x, wc.y, gz),
                    show = true,
                    label = '',
                    labelDistance = 10.0,
                    autoCompleteOnArrival = false
                }
            end
        end
    end
end)

CreateThread(function()
    local lastWaypoint = vector3(0.0, 0.0, 0.0)
    local hasWaypoint = false

    while true do
        Wait(1000)

        if not Marker3DEnabled then
            if hasWaypoint then
                hasWaypoint = false
                lastWaypoint = vector3(0.0, 0.0, 0.0)
                targetCoords['playerWaypoint'] = nil
            end
            goto continue
        end

        if IsWaypointActive() then
            local waypointBlip = GetFirstBlipInfoId(8)
            if DoesBlipExist(waypointBlip) then
                local waypointCoords = GetBlipInfoIdCoord(waypointBlip)

                if #(waypointCoords - lastWaypoint) > 1.0 then
                    lastWaypoint = waypointCoords
                    hasWaypoint = true

                    local _, groundZ = GetGroundZFor_3dCoord(waypointCoords.x, waypointCoords.y, 1000.0, false)
                    if groundZ == 0.0 then
                        groundZ = GetEntityCoords(cache.ped).z
                    end

                    targetCoords['playerWaypoint'] = {
                        coords = vector3(waypointCoords.x, waypointCoords.y, groundZ),
                        show = true,
                        label = '',
                        labelDistance = 10.0,
                        autoCompleteOnArrival = false
                    }
                end
            end
        else
            if hasWaypoint then
                hasWaypoint = false
                lastWaypoint = vector3(0.0, 0.0, 0.0)
                targetCoords['playerWaypoint'] = nil
            end
        end

        ::continue::
    end
end)

RegisterNetEvent('codem-hud:client:addMarker3D')
AddEventHandler('codem-hud:client:addMarker3D', function(markerName, markerData)
    if not Marker3DEnabled then return end
    targetCoords[markerName] = markerData
end)

RegisterNetEvent('codem-hud:client:removeMarker3D')
AddEventHandler('codem-hud:client:removeMarker3D', function(markerName)
    if targetCoords[markerName] then targetCoords[markerName] = nil end
end)

RegisterNetEvent('codem-hud:client:showMarker3D')
AddEventHandler('codem-hud:client:showMarker3D', function(markerName)
    if targetCoords[markerName] then targetCoords[markerName].show = true end
end)

RegisterNetEvent('codem-hud:client:hideMarker3D')
AddEventHandler('codem-hud:client:hideMarker3D', function(markerName)
    if targetCoords[markerName] then targetCoords[markerName].show = false end
end)

exports('AddMarker3D', function(name, data) TriggerEvent('codem-hud:client:addMarker3D', name, data) end)
exports('RemoveMarker3D', function(name) TriggerEvent('codem-hud:client:removeMarker3D', name) end)
exports('ShowMarker3D', function(name) TriggerEvent('codem-hud:client:showMarker3D', name) end)
exports('HideMarker3D', function(name) TriggerEvent('codem-hud:client:hideMarker3D', name) end)
exports('IsMarker3DEnabled', IsMarker3DEnabled)
