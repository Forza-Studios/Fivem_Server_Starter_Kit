-- Minimap module for codem-supreme-hud
-- Handles rectangular and circular minimap styles, placement, and BigMap

local minimapActive = false
local minimapStyle = nil
local hideHealthBarThreadActive = nil
local currentStatusBarType = "supreme-percentage"
local isDetachedMode = false
local pedestrianMode = true
local backgroundEnabled = true
local minimapVisible = nil
local placementOffset = {}
placementOffset.x = 0.0
placementOffset.y = 0.0
placementOffset.scale = 1.0
PlacementEditing = false

local positionAdaptiveInterval = Utils.CreateAdaptiveInterval({
    min = 1000,
    max = 3000,
    step = 200,
    threshold = 3
})
local bigmapAdaptiveInterval = Utils.CreateAdaptiveInterval({
    min = 500,
    max = 2000,
    step = 200,
    threshold = 5
})
local resolutionAdaptiveInterval = Utils.CreateAdaptiveInterval({
    min = 100,
    max = 3000,
    step = 200,
    threshold = 10
})

function HideSatNav()
    EnableSatNavHide()
end

function ShowSatNav()
    DisableSatNavHide()
end

function HideHealthArmourBar()
    if hideHealthBarThreadActive then
        return
    end
    hideHealthBarThreadActive = true
    CreateThread(function()
        local scaleformHandle = RequestScaleformMovie("minimap")
        local loadAttempts = 0
        while true do
            if not (not HasScaleformMovieLoaded(scaleformHandle) and loadAttempts < 50) then
                break
            end
            Wait(100)
            loadAttempts = loadAttempts + 1
        end
        if not HasScaleformMovieLoaded(scaleformHandle) then
            hideHealthBarThreadActive = nil
            return
        end
        BeginScaleformMovieMethod(scaleformHandle, "SETUP_HEALTH_ARMOUR")
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()
        while true do
            if not hideHealthBarThreadActive then
                break
            end
            Wait(positionAdaptiveInterval.current)
            if hideHealthBarThreadActive then
                if HasScaleformMovieLoaded(scaleformHandle) then
                    BeginScaleformMovieMethod(scaleformHandle, "SETUP_HEALTH_ARMOUR")
                    ScaleformMovieMethodAddParamInt(3)
                    EndScaleformMovieMethod()
                    positionAdaptiveInterval.onStable()
                end
            end
        end
    end)
end

function ShowHealthArmourBar()
    hideHealthBarThreadActive = nil
end

local statusBarHeights = {}
statusBarHeights["supreme-percentage"] = 0.047
statusBarHeights.supreme = 0.047
statusBarHeights.mserie = 0.065
local baseMinimapHeight = 0.045
local minimapYBase = -0.044
local minimapWidthBase = 0.1638
local minimapHeightBase = 0.183
local maskHeight = 0.128

function SetMinimapMaskAndBlurPositions(posX, posY, sizeX, sizeY, scale, ultrawideOffset)
    SetMinimapComponentPosition("minimap_mask", "L", "B",
        posX + ultrawideOffset,
        posY + 0.047 * scale,
        0.128 * scale,
        0.2 * scale
    )
    SetMinimapComponentPosition("minimap_blur", "L", "B",
        posX - 0.01 * scale + ultrawideOffset,
        posY + 0.072 * scale,
        0.262 * scale,
        0.3 * scale
    )
end

function GetUltrawideOffset()
    return Positioning.GetUltrawideMinimapOffset()
end

function GetExtraHeightOffset()
    local typeHeight = statusBarHeights[currentStatusBarType]
    if not typeHeight then
        typeHeight = baseMinimapHeight
    end
    local extra = typeHeight - baseMinimapHeight
    if extra <= 0 then
        return 0.0
    end
    return extra + 0.0025
end

function GetGfxToPixelScale()
    return Positioning.GetGfxToPixelScale()
end

function GetRectPixelBounds(posX, posY, sizeX, sizeY, offsetParam)
    local resX, resY = GetActiveScreenResolution()
    local anchorCoords = Positioning.GetAnchorScreenCoords("L", "B", posX + offsetParam, posY, sizeX, sizeY)
    local leftPx = anchorCoords.LeftX * resX
    local topPx = anchorCoords.TopY * resY
    local widthPx = anchorCoords.Width * resX
    local heightPx = anchorCoords.Height * resY
    local bottomMargin = topPx + heightPx
    local bottomPx = resY - bottomMargin
    local result = {}
    result.leftPx = leftPx
    result.bottomPx = bottomPx
    result.widthPx = widthPx
    result.heightPx = heightPx
    return result
end

function SendMinimapDimensionsNui(posX, posY, sizeX, sizeY, ultrawideOffset, scale)
    local resX, resY = GetActiveScreenResolution()
    local pixelBounds = GetRectPixelBounds(posX, posY, sizeX, sizeY, ultrawideOffset)
    local typeHeight = statusBarHeights[currentStatusBarType]
    if not typeHeight then
        typeHeight = baseMinimapHeight
    end
    local statusBarPx = typeHeight * resY * scale
    local detachedOffset = 0
    if pedestrianMode and isDetachedMode then
        detachedOffset = 0.008 * resY * scale
    end
    local hudBottomPx = pixelBounds.bottomPx - statusBarPx - detachedOffset
    local safeLeft, safeTop, safeRight, safeBottom = Positioning.GetSafeZoneBoundsPixels()
    NuiMessage("setMinimapDimensions", {
        widthPx = math.floor(pixelBounds.widthPx),
        heightPx = pixelBounds.heightPx,
        leftPx = pixelBounds.leftPx,
        bottomPx = hudBottomPx,
        minimapWidthPx = math.floor(pixelBounds.widthPx),
        minimapHeightPx = pixelBounds.heightPx,
        minimapLeftPx = pixelBounds.leftPx,
        minimapBottomPx = pixelBounds.bottomPx,
        hudWidthPx = math.floor(pixelBounds.widthPx),
        hudHeightPx = pixelBounds.heightPx + statusBarPx,
        hudLeftPx = pixelBounds.leftPx,
        hudBottomPx = hudBottomPx,
        resX = resX,
        resY = resY,
        aspectRatio = -1,
        scale = scale,
        safeZone = {
            left = safeLeft,
            top = safeTop,
            right = safeRight,
            bottom = safeBottom
        }
    })
end

function GetRectMinimapParams()
    local scale = placementOffset.scale
    local ultrawideOffset = GetUltrawideOffset()
    local extraOffset = GetExtraHeightOffset()
    local posX = placementOffset.x
    local posY = minimapYBase - extraOffset + placementOffset.y
    local sizeX = minimapWidthBase * scale
    local sizeY = minimapHeightBase * scale
    return posX, posY, sizeX, sizeY, ultrawideOffset, scale
end

function SetMinimapPositionAndMask(posX, posY, sizeX, sizeY, ultrawideOffset, scale)
    SetMinimapComponentPosition("minimap", "L", "B", posX + ultrawideOffset, posY, sizeX, sizeY)
    SetMinimapMaskAndBlurPositions(posX, posY, sizeX, sizeY, scale, ultrawideOffset)
end

function SetSquareMinimap()
    local posX, posY, sizeX, sizeY, ultrawideOffset, scale = GetRectMinimapParams()
    if not HasStreamedTextureDictLoaded("squaremap") then
        RequestStreamedTextureDict("squaremap", false)
        while true do
            if HasStreamedTextureDictLoaded("squaremap") then
                break
            end
            Wait(100)
        end
    end
    DisplayRadar(true)
    Wait(100)
    SetMinimapClipType(0)
    SetRadarZoom(0)
    RemoveReplaceTexture("platform:/textures/graphics", "radarmasksm")
    RemoveReplaceTexture("platform:/textures/graphics", "radarmask1g")
    Wait(0)
    AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "squaremap", "radarmasksm")
    AddReplaceTexture("platform:/textures/graphics", "radarmask1g", "squaremap", "radarmasksm")
    Wait(100)
    SetMinimapPositionAndMask(posX, posY, sizeX, sizeY, ultrawideOffset, scale)
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
    Wait(0)
    SetMinimapPositionAndMask(posX, posY, sizeX, sizeY, ultrawideOffset, scale)
    SetMinimapClipType(0)
    SetRadarZoom(0)
    SetBlipAlpha(GetNorthRadarBlip(), 0)
    HideHealthArmourBar()
    HideSatNav()
    minimapActive = true
    minimapStyle = "rectangular"
    SendMinimapDimensionsNui(posX, posY, sizeX, sizeY, ultrawideOffset, scale)
    minimapVisible = nil
    UpdateMinimapVisibility()
end

function ResetMinimap()
    if not minimapActive then
        return
    end
    ShowSatNav()
    ShowHealthArmourBar()
    RemoveReplaceTexture("platform:/textures/graphics", "radarmasksm")
    RemoveReplaceTexture("platform:/textures/graphics", "radarmask1g")
    SetMinimapClipType(0)
    SetRadarZoom(0)
    SetBlipAlpha(GetNorthRadarBlip(), 255)
    minimapActive = false
    minimapStyle = nil
end

local settingMinimapStyle = false
local updateCircleMinimapDimensions = nil

function SetMinimapStyle(newStyle)
    if PlacementEditing then
        minimapStyle = newStyle
        isCircleMode = false
        CircleMinimapData = nil
        if "circular" == newStyle then
            updateCircleMinimapDimensions(placementOffset.scale)
        elseif "rectangular" == newStyle then
            local posX, posY, sizeX, sizeY, ultrawideOffset, scale = GetRectMinimapParams()
            SendMinimapDimensionsNui(posX, posY, sizeX, sizeY, ultrawideOffset, scale)
        end
        return
    end
    if minimapStyle == newStyle then
        return
    end
    if settingMinimapStyle then
        return
    end
    settingMinimapStyle = true
    debugPrint("[Minimap] SetMinimapStyle:", newStyle, "current:", minimapStyle)
    RemoveReplaceTexture("platform:/textures/graphics", "radarmasksm")
    RemoveReplaceTexture("platform:/textures/graphics", "radarmask1g")
    SetMinimapClipType(0)
    SetRadarZoom(0)
    Wait(0)
    minimapActive = false
    minimapStyle = nil
    isCircleMode = false
    CircleMinimapData = nil
    if "rectangular" == newStyle then
        SetSquareMinimap()
    elseif "circular" == newStyle then
        SetCircleMinimap()
    end
    debugPrint("[Minimap] SetMinimapStyle done, inVehicle:", cache.inVehicle, "radarVisible:", false == IsRadarHidden())
    settingMinimapStyle = false
end

local circleBaseWidth = 181
local circleBaseHeight = 126
local circleAspectRatio = circleBaseWidth / circleBaseHeight
local circleBasePos = {}
circleBasePos.posX = -0.0015
circleBasePos.posY = -0.001
circleBasePos.sizeX = 0.15
circleBasePos.sizeY = 0.1889
local circleMaskPos = {}
circleMaskPos.posX = 0.023
circleMaskPos.posY = 0.029
circleMaskPos.sizeX = 0.111
circleMaskPos.sizeY = 0.159
local circleBlurPos = {}
circleBlurPos.posX = -0.027
circleBlurPos.posY = 0.019
circleBlurPos.sizeX = 0.266
circleBlurPos.sizeY = 0.237
local circleData = nil
local circleModeActive = false

function CalculateCirclePixelBounds(scaleParam)
    if not scaleParam then
        scaleParam = 1.0
    end
    local resX, resY = GetActiveScreenResolution()
    local posX = circleBasePos.posX + placementOffset.x
    local posY = circleBasePos.posY + placementOffset.y
    local sizeX = scaleParam * circleBasePos.sizeX
    local sizeY = scaleParam * circleBasePos.sizeY * circleAspectRatio
    local anchorCoords = Positioning.GetAnchorScreenCoords("L", "B", posX, posY, sizeX, sizeY)
    local baseHeight
    if 1.0 == scaleParam then
        baseHeight = 5.8
    else
        baseHeight = 5.8 + scaleParam * circleBasePos.sizeY
    end
    local heightPx = scaleParam / baseHeight * circleAspectRatio * resY
    local result = {}
    result.widthPx = anchorCoords.Width * resX
    result.heightPx = heightPx
    result.leftPx = anchorCoords.LeftX * resX
    result.topPx = anchorCoords.TopY * resY
    result.bottomPx = resY - anchorCoords.BottomY * resY
    result.resX = resX
    result.resY = resY
    return result
end

local circleHudSizeMultiplier = 1.28

function UpdateCircleMinimapDimensionsInternal(scaleParam)
    local circleBounds = CalculateCirclePixelBounds(scaleParam)
    local resX, resY = GetActiveScreenResolution()
    local hudSize = circleBounds.heightPx * circleHudSizeMultiplier
    local hudCenterX = circleBounds.leftPx + circleBounds.widthPx / 2
    local hudCenterY = circleBounds.topPx + circleBounds.heightPx / 2
    local hudLeft = hudCenterX - hudSize / 2
    local hudBottom = resY - (hudCenterY + hudSize / 2)
    local aspectRatio = GetAspectRatio(false)
    local safeLeft, safeTop, safeRight, safeBottom = Positioning.GetSafeZoneBoundsPixels()
    NuiMessage("setMinimapDimensions", {
        minimapWidthPx = circleBounds.widthPx,
        minimapHeightPx = circleBounds.heightPx,
        minimapLeftPx = circleBounds.leftPx,
        minimapBottomPx = circleBounds.bottomPx,
        hudWidthPx = hudSize,
        hudHeightPx = hudSize,
        hudLeftPx = hudLeft,
        hudBottomPx = hudBottom,
        resX = resX,
        resY = resY,
        aspectRatio = aspectRatio,
        scale = scaleParam,
        safeZone = {
            left = safeLeft,
            top = safeTop,
            right = safeRight,
            bottom = safeBottom
        }
    })
    debugPrint(
        string.format(
            "[CIRCLE] Minimap: %.1fx%.1f, HUD: %.1fx%.1f, Pos: %.1f,%.1f, Res: %dx%d, AR: %.4f",
            circleBounds.widthPx, circleBounds.heightPx,
            hudSize, hudSize,
            hudLeft, hudBottom,
            resX, resY, aspectRatio
        )
    )
end
updateCircleMinimapDimensions = UpdateCircleMinimapDimensionsInternal

function SetCircleMinimap()
    local scale = placementOffset.scale
    if not HasStreamedTextureDictLoaded("circlemask") then
        RequestStreamedTextureDict("circlemask", false)
        while true do
            if HasStreamedTextureDictLoaded("circlemask") then
                break
            end
            Wait(10)
        end
    end
    DisplayRadar(true)
    Wait(100)
    AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "circlemask", "radarmasksm_circle_noblur")
    SetMinimapClipType(1)
    SetRadarZoom(1000)
    Wait(100)
    local posX = circleBasePos.posX + placementOffset.x
    local posY = circleBasePos.posY + placementOffset.y
    local sizeX = scale * circleBasePos.sizeX
    local sizeY = scale * circleBasePos.sizeY * circleAspectRatio
    local maskPosX = circleMaskPos.posX - circleBasePos.posX
    maskPosX = maskPosX * scale
    maskPosX = posX + maskPosX
    local maskPosY = circleMaskPos.posY - circleBasePos.posY
    maskPosY = maskPosY * scale
    maskPosY = posY + maskPosY
    local blurPosX = circleBlurPos.posX - circleBasePos.posX
    blurPosX = blurPosX * scale
    blurPosX = posX + blurPosX
    local blurPosY = circleBlurPos.posY - circleBasePos.posY
    blurPosY = blurPosY * scale
    blurPosY = posY + blurPosY
    local function applyCirclePositions()
        SetMinimapComponentPosition("minimap", "L", "B", posX, posY, sizeX, sizeY)
        SetMinimapComponentPosition("minimap_mask", "L", "B", maskPosX, maskPosY,
            scale * circleMaskPos.sizeX,
            scale * circleMaskPos.sizeY * circleAspectRatio
        )
        SetMinimapComponentPosition("minimap_blur", "L", "B", blurPosX, blurPosY,
            scale * circleBlurPos.sizeX,
            scale * circleBlurPos.sizeY * circleAspectRatio
        )
    end
    applyCirclePositions()
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
    Wait(0)
    applyCirclePositions()
    local newCircleData = {}
    newCircleData.scale = scale
    circleData = newCircleData
    circleModeActive = true
    SetBlipAlpha(GetNorthRadarBlip(), 0)
    HideHealthArmourBar()
    HideSatNav()
    minimapActive = true
    minimapStyle = "circular"
    updateCircleMinimapDimensions(scale)
    minimapVisible = nil
    UpdateMinimapVisibility()
end

local lastResX = 0
local lastResY = 0
local lastAspectRatio = 0

function CheckCircleMinimapResolution()
    if circleModeActive and circleData then
    else
        return
    end
    if PlacementEditing then
        return
    end
    local resX, resY = GetActiveScreenResolution()
    local aspectRatio = GetAspectRatio(false)
    if resX == lastResX and resY == lastResY and aspectRatio == lastAspectRatio then
        return
    end
    local newResX = resX
    local newResY = resY
    lastAspectRatio = aspectRatio
    lastResY = newResY
    lastResX = newResX
    updateCircleMinimapDimensions(circleData.scale)
end

CreateThread(function()
    while true do
        Wait(500)
        CheckCircleMinimapResolution()
    end
end)

function SetMinimapVisible(visible)
    if visible ~= minimapVisible then
        minimapVisible = visible
        if not PlacementEditing then
            DisplayRadar(visible)
            NuiMessage("setMinimapVisible", { visible = visible })
            if visible and minimapStyle then
                RefreshMinimapPosition()
            end
        end
    end
end

function IsMinimapVisible()
    return minimapVisible
end

CreateThread(function()
    while true do
        Wait(bigmapAdaptiveInterval.current)
        if not PlacementEditing then
            if not BigMapActive then
                SetBigmapActive(false, false)
                if "circular" == minimapStyle then
                    SetRadarZoom(1000)
                end
            end
            if minimapActive and "rectangular" == minimapStyle then
                local posX, posY, sizeX, sizeY, ultrawideOffset, scale = GetRectMinimapParams()
                SetMinimapPositionAndMask(posX, posY, sizeX, sizeY, ultrawideOffset, scale)
            end
        end
        bigmapAdaptiveInterval.onStable()
    end
end)

CreateThread(function()
    while true do
        Wait(100)
        if not PlacementEditing then
            if not FlirActive then
                if nil ~= minimapVisible then
                    local radarHidden = IsRadarHidden()
                    if minimapVisible and radarHidden then
                        DisplayRadar(true)
                        if minimapStyle then
                            RefreshMinimapPosition()
                        end
                    elseif not minimapVisible and not radarHidden then
                        DisplayRadar(false)
                    end
                end
            end
        end
    end
end)

local prevResX = 0
local prevResY = 0

CreateThread(function()
    Wait(1000)
    local resX, resY = GetActiveScreenResolution()
    prevResY = resY
    prevResX = resX
    SendNUIMessage({
        action = "setGameResolution",
        width = prevResX,
        height = prevResY
    })
    while true do
        Wait(resolutionAdaptiveInterval.current)
        local resX, resY = GetActiveScreenResolution()
        if resX == prevResX and resY == prevResY then
            resolutionAdaptiveInterval.onStable()
        else
            debugPrint(
                string.format(
                    "[MINIMAP] Resolution changed: %dx%d -> %dx%d",
                    prevResX, prevResY, resX, resY
                )
            )
            local newResX = resX
            prevResY = resY
            prevResX = newResX
            resolutionAdaptiveInterval.onChanged()
            Positioning.InvalidateCache()
            SendNUIMessage({
                action = "setGameResolution",
                width = resX,
                height = resY
            })
            if minimapStyle then
                RefreshMinimapPosition()
            end
            Wait(100)
            NuiMessage("blurRecalculate", {})
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    ResetMinimap()
end)

RegisterNUICallback("SET_STATUSBAR_TYPE", function(data, cb)
    if data and data.type then
    else
        cb({ success = false })
        return
    end
    local newType = data.type
    local changed = false
    if newType ~= currentStatusBarType then
        currentStatusBarType = newType
        changed = true
    end
    local heightData = data.height
    if heightData then
        if type(heightData) == "number" then
            statusBarHeights[newType] = heightData / 100
            changed = true
        end
    end
    if changed then
        if not settingMinimapStyle then
            if "rectangular" == minimapStyle then
                SetSquareMinimap()
            elseif "circular" == minimapStyle then
                SetCircleMinimap()
            end
        end
    end
    cb({ success = true })
end)

RegisterNUICallback("SET_ATTACH_TO_MINIMAP", function(data, cb)
    if nil == data then
        cb({ success = false })
        return
    end
    local newDetached = not data.attached
    if newDetached ~= isDetachedMode then
        isDetachedMode = newDetached
        debugPrint(string.format("[MINIMAP] Detached mode changed: %s", tostring(isDetachedMode)))
        if not settingMinimapStyle then
            RefreshMinimapPosition()
        end
    end
    cb({ success = true })
end)

RegisterNUICallback("SET_VEHICLE_MODE", function(data, cb)
    if nil == data then
        cb({ success = false })
        return
    end
    local newPedestrian = not data.inVehicle
    if newPedestrian ~= pedestrianMode then
        pedestrianMode = newPedestrian
        debugPrint(string.format("[MINIMAP] Pedestrian mode changed: %s", tostring(pedestrianMode)))
        if not settingMinimapStyle then
            RefreshMinimapPosition()
        end
    end
    cb({ success = true })
end)

RegisterNUICallback("SET_BACKGROUND_ENABLED", function(data, cb)
    if nil == data then
        cb({ success = false })
        return
    end
    local newEnabled = data.enabled
    if newEnabled ~= backgroundEnabled then
        backgroundEnabled = newEnabled
        debugPrint(string.format("[MINIMAP] Background enabled changed: %s", tostring(backgroundEnabled)))
        if not settingMinimapStyle then
            RefreshMinimapPosition()
        end
    end
    cb({ success = true })
end)

function RefreshMinimapPosition()
    local scale = placementOffset.scale
    if "rectangular" == minimapStyle then
        local posX, posY, sizeX, sizeY, ultrawideOffset, s = GetRectMinimapParams()
        SetMinimapPositionAndMask(posX, posY, sizeX, sizeY, ultrawideOffset, s)
        SendMinimapDimensionsNui(posX, posY, sizeX, sizeY, ultrawideOffset, s)
        SendPlacementDimensions()
    elseif "circular" == minimapStyle then
        AddReplaceTexture("platform:/textures/graphics", "radarmasksm", "circlemask", "radarmasksm_circle_noblur")
        SetMinimapClipType(1)
        SetRadarZoom(1000)
        SetBlipAlpha(GetNorthRadarBlip(), 0)
        local s = placementOffset.scale
        local posX = circleBasePos.posX + placementOffset.x
        local posY = circleBasePos.posY + placementOffset.y
        local sizeX = s * circleBasePos.sizeX
        local sizeY = s * circleBasePos.sizeY * circleAspectRatio
        local maskPosX = circleMaskPos.posX - circleBasePos.posX
        maskPosX = maskPosX * s
        maskPosX = posX + maskPosX
        local maskPosY = circleMaskPos.posY - circleBasePos.posY
        maskPosY = maskPosY * s
        maskPosY = posY + maskPosY
        local blurPosX = circleBlurPos.posX - circleBasePos.posX
        blurPosX = blurPosX * s
        blurPosX = posX + blurPosX
        local blurPosY = circleBlurPos.posY - circleBasePos.posY
        blurPosY = blurPosY * s
        blurPosY = posY + blurPosY
        SetMinimapComponentPosition("minimap", "L", "B", posX, posY, sizeX, sizeY)
        SetMinimapComponentPosition("minimap_mask", "L", "B", maskPosX, maskPosY,
            s * circleMaskPos.sizeX,
            s * circleMaskPos.sizeY * circleAspectRatio
        )
        SetMinimapComponentPosition("minimap_blur", "L", "B", blurPosX, blurPosY,
            s * circleBlurPos.sizeX,
            s * circleBlurPos.sizeY * circleAspectRatio
        )
        updateCircleMinimapDimensions(s)
        SendPlacementDimensions()
    end
end

AddEventHandler("codem-hud:client:RecalculateMinimap", function()
    debugPrint("[MINIMAP] RecalculateMinimap event received")
    if minimapStyle then
        RefreshMinimapPosition()
    end
end)

function ApplyMinimapPositionsOnly()
    local scale = placementOffset.scale
    if "rectangular" == minimapStyle then
        local posX, posY, sizeX, sizeY, ultrawideOffset, s = GetRectMinimapParams()
        SetMinimapPositionAndMask(posX, posY, sizeX, sizeY, ultrawideOffset, s)
    elseif "circular" == minimapStyle then
        local posX = circleBasePos.posX + placementOffset.x
        local posY = circleBasePos.posY + placementOffset.y
        local sizeX = scale * circleBasePos.sizeX
        local sizeY = scale * circleBasePos.sizeY * circleAspectRatio
        local maskPosX = circleMaskPos.posX - circleBasePos.posX
        maskPosX = maskPosX * scale
        maskPosX = posX + maskPosX
        local maskPosY = circleMaskPos.posY - circleBasePos.posY
        maskPosY = maskPosY * scale
        maskPosY = posY + maskPosY
        local blurPosX = circleBlurPos.posX - circleBasePos.posX
        blurPosX = blurPosX * scale
        blurPosX = posX + blurPosX
        local blurPosY = circleBlurPos.posY - circleBasePos.posY
        blurPosY = blurPosY * scale
        blurPosY = posY + blurPosY
        SetMinimapComponentPosition("minimap", "L", "B", posX, posY, sizeX, sizeY)
        SetMinimapComponentPosition("minimap_mask", "L", "B", maskPosX, maskPosY,
            scale * circleMaskPos.sizeX,
            scale * circleMaskPos.sizeY * circleAspectRatio
        )
        SetMinimapComponentPosition("minimap_blur", "L", "B", blurPosX, blurPosY,
            scale * circleBlurPos.sizeX,
            scale * circleBlurPos.sizeY * circleAspectRatio
        )
    end
end

function ApplyMinimapPositionsWithBigmapReset()
    ApplyMinimapPositionsOnly()
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
    Wait(0)
    ApplyMinimapPositionsOnly()
    SendPlacementDimensions()
end
ApplyPlacementToMinimap = ApplyMinimapPositionsWithBigmapReset

function ApplyPlacementToMinimapFast()
    ApplyMinimapPositionsOnly()
    SendPlacementDimensions()
end

function SendPlacementDimensions()
    if "rectangular" == minimapStyle then
        SendMinimapDimensionsNui(GetRectMinimapParams())
    elseif "circular" == minimapStyle then
        updateCircleMinimapDimensions(placementOffset.scale)
    end
end

RegisterNUICallback("placement:resize", function(data, cb)
    if not data then
        cb("ok")
        return
    end
    local newScale = data.scale
    if not newScale then
        newScale = 1.0
    end
    placementOffset.scale = newScale
    ApplyPlacementToMinimapFast()
    cb("ok")
end)

RegisterNUICallback("placement:reset", function(data, cb)
    placementOffset.x = 0
    placementOffset.y = 0
    placementOffset.scale = 1.0
    ApplyPlacementToMinimapFast()
    cb("ok")
end)

local wasRadarVisibleBeforeEdit = false

RegisterNUICallback("placement:open", function(data, cb)
    wasRadarVisibleBeforeEdit = false ~= minimapVisible
    PlacementEditing = true
    DisplayRadar(false)
    cb("ok")
end)

RegisterNUICallback("placement:quit", function(data, cb)
    if wasRadarVisibleBeforeEdit then
        if "rectangular" == minimapStyle then
            SetSquareMinimap()
        elseif "circular" == minimapStyle then
            SetCircleMinimap()
        end
        DisplayRadar(true)
        PlacementEditing = false
        minimapVisible = nil
        UpdateMinimapVisibility()
        local isVisible = true == minimapVisible
        if "rectangular" == minimapStyle then
            local posX, posY, sizeX, sizeY, ultrawideOffset, scale = GetRectMinimapParams()
            local resX, resY = GetActiveScreenResolution()
            local pixelBounds = GetRectPixelBounds(posX, posY, sizeX, sizeY, ultrawideOffset)
            local typeHeight = statusBarHeights[currentStatusBarType]
            if not typeHeight then
                typeHeight = baseMinimapHeight
            end
            local statusBarPx = typeHeight * resY * scale
            local detachedOffset = 0
            if pedestrianMode and isDetachedMode then
                detachedOffset = 0.008 * resY * scale
            end
            local dims = {
                minimapVisible = isVisible,
                widthPx = math.floor(pixelBounds.widthPx),
                heightPx = pixelBounds.heightPx,
                leftPx = pixelBounds.leftPx,
                bottomPx = pixelBounds.bottomPx - statusBarPx - detachedOffset,
                resX = resX,
                resY = resY,
                aspectRatio = -1,
                scale = scale
            }
            cb({
                minimapVisible = isVisible,
                dims = dims
            })
        else
            cb({
                minimapVisible = isVisible
            })
        end
    else
        PlacementEditing = false
        cb({ minimapVisible = false })
    end
end)

RegisterNUICallback("placement:revert", function(data, cb)
    placementOffset = {
        x = 0.0,
        y = 0.0,
        scale = 1.0
    }
    SendPlacementDimensions()
    local resX, resY = GetActiveScreenResolution()
    local scale = placementOffset.scale
    if "circular" == minimapStyle then
        local circleBounds = CalculateCirclePixelBounds(scale)
        local hudSize = circleBounds.heightPx * circleHudSizeMultiplier
        local hudCenterX = circleBounds.leftPx + circleBounds.widthPx / 2
        local hudCenterY = circleBounds.topPx + circleBounds.heightPx / 2
        cb({
            hudLeftPx = hudCenterX - hudSize / 2,
            hudBottomPx = resY - (hudCenterY + hudSize / 2)
        })
    elseif "rectangular" == minimapStyle then
        local posX, posY, sizeX, sizeY, ultrawideOffset, s = GetRectMinimapParams()
        local pixelBounds = GetRectPixelBounds(posX, posY, sizeX, sizeY, ultrawideOffset)
        local typeHeight = statusBarHeights[currentStatusBarType]
        if not typeHeight then
            typeHeight = baseMinimapHeight
        end
        local statusBarPx = typeHeight * resY * s
        cb({
            hudLeftPx = pixelBounds.leftPx,
            hudBottomPx = pixelBounds.bottomPx - statusBarPx
        })
    else
        cb("ok")
    end
end)

RegisterNUICallback("SET_PLACEMENT_OFFSET", function(data, cb)
    if not data then
        cb("ok")
        return
    end
    local pxPerGfxX, pxPerGfxY = GetGfxToPixelScale()
    local newX = data.x
    if not newX then
        newX = 0
    end
    newX = newX / pxPerGfxX
    placementOffset.x = newX
    local newY = data.y
    if not newY then
        newY = 0
    end
    newY = -newY / pxPerGfxY
    placementOffset.y = newY
    local newScale = data.scale
    if not newScale then
        newScale = 1.0
    end
    placementOffset.scale = newScale
    placementOffset.x = math.max(-1.0, math.min(1.0, placementOffset.x))
    placementOffset.y = math.max(-1.0, math.min(1.0, placementOffset.y))
    local dbgX = data.x
    if not dbgX then
        dbgX = 0
    end
    local dbgY = data.y
    if not dbgY then
        dbgY = 0
    end
    debugPrint(string.format("[SET_PLACEMENT_OFFSET] Vue: %.1f,%.1f px | Lua: %.4f,%.4f norm", dbgX, dbgY, placementOffset.x, placementOffset.y))
    ApplyPlacementToMinimap()
    cb("ok")
end)

RegisterNUICallback("SET_MINIMAP_STYLE", function(data, cb)
    local styleName = "nil"
    if data and data.style then
        styleName = data.style
    end
    debugPrint("[Minimap] SET_MINIMAP_STYLE received - style:", styleName)
    if data and data.style then
        placementOffset.x = 0.0
        placementOffset.y = 0.0
        placementOffset.scale = 1.0
        SetMinimapStyle(data.style)
        Wait(200)
        UpdateMinimapVisibility()
    end
    cb("ok")
end)

RegisterNUICallback("INIT_PLACEMENT", function(data, cb)
    if not data then
        cb("ok")
        return
    end
    local newX = data.x
    if not newX then
        newX = 0.0
    end
    placementOffset.x = newX
    local newY = data.y
    if not newY then
        newY = 0.0
    end
    placementOffset.y = newY
    local newScale = data.scale
    if not newScale then
        newScale = 1.0
    end
    placementOffset.scale = newScale
    placementOffset.x = math.max(-1.0, math.min(1.0, placementOffset.x))
    placementOffset.y = math.max(-1.0, math.min(1.0, placementOffset.y))
    debugPrint(string.format("[INIT_PLACEMENT] x=%.4f y=%.4f scale=%.2f", placementOffset.x, placementOffset.y, placementOffset.scale))
    if minimapStyle then
        ApplyPlacementToMinimap()
    end
    cb("ok")
end)

RegisterNUICallback("SYNC_PLACEMENT_DRAG", function(data, cb)
    if not data then
        cb("ok")
        return
    end
    local pxPerGfxX, pxPerGfxY = GetGfxToPixelScale()
    local dx = data.dx
    if not dx then
        dx = 0
    end
    dx = dx / pxPerGfxX
    local dy = data.dy
    if not dy then
        dy = 0
    end
    dy = dy / pxPerGfxY
    placementOffset.x = placementOffset.x + dx
    placementOffset.y = placementOffset.y - dy
    local newScale = data.scale
    if not newScale then
        newScale = placementOffset.scale
    end
    placementOffset.scale = newScale
    placementOffset.x = math.max(-1.0, math.min(1.0, placementOffset.x))
    placementOffset.y = math.max(-1.0, math.min(1.0, placementOffset.y))
    local dbgDx = data.dx
    if not dbgDx then
        dbgDx = 0
    end
    local dbgDy = data.dy
    if not dbgDy then
        dbgDy = 0
    end
    debugPrint(string.format(
        "[SYNC_PLACEMENT_DRAG] delta: %.1f,%.1f px | pxPerGfx: %.1f,%.1f | gfxDelta: %.6f,%.6f | final: %.4f,%.4f norm",
        dbgDx, dbgDy, pxPerGfxX, pxPerGfxY, dx, dy, placementOffset.x, placementOffset.y
    ))
    if not PlacementEditing then
        ApplyPlacementToMinimapFast()
    end
    cb("ok")
end)

RegisterNUICallback("SAVE_PLACEMENT", function(data, cb)
    debugPrint(string.format("[SAVE_PLACEMENT] x=%.4f y=%.4f scale=%.2f", placementOffset.x, placementOffset.y, placementOffset.scale))
    cb({
        x = placementOffset.x,
        y = placementOffset.y,
        scale = placementOffset.scale
    })
end)

-- BigMap setup
local bigMapConfig = Config.Minimap
if bigMapConfig and bigMapConfig.BigMap then
else
    bigMapConfig = {}
end
local bigMapEnabled = bigMapConfig.Enabled
bigMapEnabled = false ~= bigMapEnabled
BigMapActive = false

function OpenBigMap()
    if not bigMapEnabled then
        return
    end
    if FlirActive then
        return
    end
    if BigMapActive then
        return
    end
    BigMapActive = true
    SetRadarBigmapEnabled(true, false)
    NuiMessage("bigmap:toggle", { active = true })
    TriggerEvent("codem-hud:client:BigMapToggled")
    debugPrint("[BigMap] Opened")
end

function CloseBigMap()
    if not BigMapActive then
        return
    end
    BigMapActive = false
    SetRadarBigmapEnabled(false, false)
    NuiMessage("bigmap:toggle", { active = false })
    TriggerEvent("codem-hud:client:BigMapToggled")
    debugPrint("[BigMap] Closed")
end

exports("OpenBigMap", OpenBigMap)
exports("CloseBigMap", CloseBigMap)
exports("IsBigMapActive", function()
    return BigMapActive
end)

AddEventHandler("codem-hud:client:flirActivated", function()
    CloseBigMap()
end)

if bigMapEnabled then
    local bigMapKey = bigMapConfig.Key
    if not bigMapKey then
        bigMapKey = "Z"
    end
    local bigMapKeyDesc = bigMapConfig.KeyDescription
    if not bigMapKeyDesc then
        bigMapKeyDesc = "Hold for Big Map"
    end
    RegisterCommand("+bigmap_toggle", function()
        OpenBigMap()
    end, false)
    RegisterCommand("-bigmap_toggle", function()
        CloseBigMap()
    end, false)
    RegisterKeyMapping("+bigmap_toggle", bigMapKeyDesc, "keyboard", bigMapKey)
    debugPrint("[BigMap] Registered key:", bigMapKey)
end
