local BASE_ASPECT_RATIO = 1.7777777910233

local screenCache = {
    valid = false,
    safeZone = nil,
    safeZonePixels = nil,
    isUltrawide = nil,
    ultrawideOffset = nil,
    resX = 0,
    resY = 0,
    safeZoneSize = 0,
}

Positioning = {}

function Positioning.InvalidateCache()
    screenCache.valid = false
    screenCache.safeZone = nil
    screenCache.safeZonePixels = nil
    screenCache.isUltrawide = nil
    screenCache.ultrawideOffset = nil
end

local function validateCache()
    if screenCache.valid then
        local currentResX, currentResY = GetActiveScreenResolution()
        local currentSafeZone = GetSafeZoneSize()
        if currentResX == screenCache.resX then
            if currentResY == screenCache.resY then
                if currentSafeZone == screenCache.safeZoneSize then
                    return
                end
            end
        end
    end
    local resX, resY = GetActiveScreenResolution()
    screenCache.resY = resY
    screenCache.resX = resX
    local safeZoneSize = GetSafeZoneSize()
    screenCache.safeZoneSize = safeZoneSize
    screenCache.valid = true
    screenCache.safeZone = nil
    screenCache.safeZonePixels = nil
    screenCache.isUltrawide = nil
    screenCache.ultrawideOffset = nil
end

function Positioning.IsSuperWideScreen()
    local aspectRatio = GetAspectRatio(true)
    return aspectRatio > BASE_ASPECT_RATIO
end

function Positioning.IsUltrawide()
    validateCache()
    if screenCache.isUltrawide ~= nil then
        return screenCache.isUltrawide
    end
    screenCache.isUltrawide = Positioning.IsSuperWideScreen()
    return screenCache.isUltrawide
end

function Positioning.AdjustForUltrawide(posX, posY)
    if not Positioning.IsSuperWideScreen() then
        return posX, posY
    end
    local ratio = BASE_ASPECT_RATIO / GetAspectRatio(false)
    posX = posX * ratio
    posY = posY * ratio
    return posX, posY
end

function Positioning.GetAnchorSize(anchor, height, width, anchorH, anchorV)
    local currentAspect = GetAspectRatio(false)
    local effectiveAspect = currentAspect
    if Positioning.IsSuperWideScreen() then
        effectiveAspect = BASE_ASPECT_RATIO
    end
    local scaleFactor = BASE_ASPECT_RATIO / effectiveAspect
    local offset = 1.0 - scaleFactor
    if math.abs(offset) < 0.001 then
        offset = 0.0
    end
    anchorH = anchorH * scaleFactor
    height = height * scaleFactor
    if anchor == "C" then
        height = height + offset * 0.5
    end
    height, anchorH = Positioning.AdjustForUltrawide(height, anchorH)
    local topLeft = vector2(height, width)
    local bottomRight = vector2(anchorH, anchorV)
    return topLeft, bottomRight
end

function Positioning.GetSafeZoneBounds()
    validateCache()
    if screenCache.safeZone then
        local zone = screenCache.safeZone
        return zone.x0, zone.y0, zone.x1, zone.y1
    end
    local safeSizeH = screenCache.safeZoneSize
    local safeSizeV = screenCache.safeZoneSize
    local aspectRatio = GetAspectRatio(false)
    if aspectRatio < 1.0 then
        local adjustedH = 1.0 - safeSizeH
        local aspectDiff = 1.0 - aspectRatio
        adjustedH = adjustedH + aspectDiff
        safeSizeH = 1.0 - adjustedH
    end
    local resX = screenCache.resX
    local resY = screenCache.resY
    local marginX = resX * safeSizeH
    marginX = resX - marginX
    marginX = marginX * 0.5
    local marginY = resY * safeSizeV
    marginY = resY - marginY
    marginY = marginY * 0.5
    local x0 = math.ceil(marginX) / resX
    local y0 = math.ceil(marginY) / resY
    local x1 = math.floor(resX - marginX) / resX
    local y1 = math.floor(resY - marginY) / resY
    if Positioning.IsSuperWideScreen() then
        local ultraRatio = BASE_ASPECT_RATIO / GetAspectRatio(true)
        local ultraMargin = resX * ultraRatio
        ultraMargin = resX - ultraMargin
        ultraMargin = ultraMargin * 0.5
        ultraMargin = ultraMargin / resX
        x0 = x0 + ultraMargin
        x1 = x1 - ultraMargin
    end
    screenCache.safeZone = {
        x0 = x0,
        y0 = y0,
        x1 = x1,
        y1 = y1,
    }
    return x0, y0, x1, y1
end

function Positioning.GetSafeZoneBoundsPixels()
    validateCache()
    if screenCache.safeZonePixels then
        local pixels = screenCache.safeZonePixels
        return pixels.left, pixels.top, pixels.right, pixels.bottom
    end
    local x0, y0, x1, y1 = Positioning.GetSafeZoneBounds()
    local resX = screenCache.resX
    local resY = screenCache.resY
    local left = x0 * resX
    local top = y0 * resY
    local right = x1 * resX
    local bottom = y1 * resY
    screenCache.safeZonePixels = {
        left = left,
        top = top,
        right = right,
        bottom = bottom,
    }
    return left, top, right, bottom
end

function Positioning.GetUltrawideMinimapOffset()
    validateCache()
    if screenCache.ultrawideOffset ~= nil then
        return screenCache.ultrawideOffset
    end
    local aspectRatio = screenCache.resX / screenCache.resY
    if aspectRatio > BASE_ASPECT_RATIO then
        screenCache.ultrawideOffset = (BASE_ASPECT_RATIO - aspectRatio) / 3.6
    else
        screenCache.ultrawideOffset = 0
    end
    return screenCache.ultrawideOffset
end

function Positioning.SafePosLeftFromBottom(offset, size, anchorH, anchorV)
    local x0, y0, x1, y1 = Positioning.GetSafeZoneBounds()
    local topLeft = vector2(x0, y0)
    local bottomRight = vector2(x1, y1)
    local posX = 0.0
    local posY = 0.0
    if anchorH == "L" then
        posX = topLeft.x
    elseif anchorH == "R" then
        posX = bottomRight.x - size.x
    elseif anchorH == "C" then
        posX = (topLeft.x + bottomRight.x - size.x) * 0.5
    end
    if anchorV == "T" then
        posY = topLeft.y
    elseif anchorV == "B" then
        posY = bottomRight.y - size.y
    elseif anchorV == "C" then
        posY = (topLeft.y + bottomRight.y - size.y) * 0.5
    end
    local result = vector2(posX, posY)
    result = result + offset
    return result
end

function Positioning.GetAnchorScreenCoords(anchor, size, anchorH, anchorV, gWidth, gHeight)
    local anchorSize, anchorPos = Positioning.GetAnchorSize(anchor, anchorH, anchorV, gWidth, gHeight)
    local screenPos = Positioning.SafePosLeftFromBottom(anchorSize, anchorPos, anchor, size)
    local result = {}
    result.LeftX = screenPos.x
    result.TopY = screenPos.y
    result.RightX = screenPos.x + anchorPos.x
    result.BottomY = screenPos.y + anchorPos.y
    result.Width = anchorPos.x
    result.Height = anchorPos.y
    result.CenterX = screenPos.x + anchorPos.x * 0.5
    result.CenterY = screenPos.y + anchorPos.y * 0.5
    result.x = screenPos.x
    result.y = screenPos.y
    return result
end

function Positioning.GetGfxToPixelScale()
    local resX, resY = GetActiveScreenResolution()
    local ratio = BASE_ASPECT_RATIO / GetAspectRatio(false)
    local scaleX = ratio * resX
    local scaleY = resY
    return scaleX, scaleY
end

function Positioning.ConvertScreenCoordsToResolutionCoords(coordX, coordY)
    local resX, resY = GetActualScreenResolution()
    local pixelX = math.floor(coordX * resX + 0.5)
    local pixelY = math.floor(coordY * resY + 0.5)
    return pixelX, pixelY
end

function Positioning.ConvertResolutionCoordsToScreenCoords(coordX, coordY)
    local resX, resY = GetActualScreenResolution()
    local normalX = math.max(0.0, math.min(1.0, coordX / resX))
    local normalY = math.max(0.0, math.min(1.0, coordY / resY))
    return normalX, normalY
end
