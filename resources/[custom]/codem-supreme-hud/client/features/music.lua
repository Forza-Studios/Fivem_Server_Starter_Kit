--[[
    Vehicle Music Client
]]

if not Config.VehicleMusic or not Config.VehicleMusic.Enabled then return end

local MUSIC_DISTANCE = Config.VehicleMusic.Distance or 15.0
local TIME_UPDATE_INTERVAL = Config.VehicleMusic.TimeUpdateInterval or 200
local TIME_DRIFT_THRESHOLD = Config.VehicleMusic.TimeDriftThreshold or 2.0
local NEARBY_CHECK_INTERVAL = Config.VehicleMusic.NearbyCheckInterval or 2000
local NEARBY_VOLUME_UPDATE_INTERVAL = 200

local WINDOW_EFFECT_ENABLED = Config.VehicleMusic.WindowEffect and Config.VehicleMusic.WindowEffect.Enabled or false
local WINDOW_CLOSED_MULTIPLIER = Config.VehicleMusic.WindowEffect and Config.VehicleMusic.WindowEffect.ClosedWindowMultiplier or 0.35

local SA = Config.VehicleMusic.SpatialAudio or {}
local SPATIAL_AUDIO_ENABLED = SA.Enabled or false
local MUFFLED_ENABLED = SPATIAL_AUDIO_ENABLED and (SA.MuffledEffect ~= false)
local REVERB_ENABLED = SPATIAL_AUDIO_ENABLED and (SA.ReverbEffect ~= false)
local DOPPLER_ENABLED = SPATIAL_AUDIO_ENABLED and (SA.DopplerEffect ~= false)

local MUFFLED_CLOSED_WINDOW = SA.MuffledClosedWindow or 0.75
local MUFFLED_OPEN_WINDOW = SA.MuffledOpenWindow or 0.30
local MUFFLED_DISTANCE_SCALE = SA.MuffledDistanceScale or 0.50
local MUFFLED_MAX = SA.MuffledMax or 0.95

local REVERB_START_DISTANCE = SA.ReverbStartDistance or 3.0
local REVERB_MAX = SA.ReverbMax or 0.25

local V_SOUND = SA.DopplerSpeedOfSound or 80.0
local DOPPLER_MIN = SA.DopplerMin or 0.75
local DOPPLER_MAX = SA.DopplerMax or 1.50
local DOPPLER_MIN_DISTANCE = SA.DopplerMinDistance or 0.5

local function IsVehicleOpen(vehicle)
    if not vehicle or vehicle == 0 then return true end
    -- Check doors (0-5: front left/right, rear left/right, hood, trunk)
    for i = 0, 5 do
        if GetVehicleDoorAngleRatio(vehicle, i) > 0.1 then return true end
    end
    -- Check windows
    for i = 0, 3 do
        if not IsVehicleWindowIntact(vehicle, i) then return true end
    end
    if IsAnyWindowRolledDown and IsAnyWindowRolledDown(vehicle) then return true end
    return false
end

local function GetWindowVolumeMultiplier(sourceVehicle)
    if not WINDOW_EFFECT_ENABLED then return 1.0 end

    local listenerInVehicle = cache.vehicle and cache.vehicle ~= 0
    local sourceWindowsOpen = IsVehicleOpen(sourceVehicle)

    if listenerInVehicle then
        local listenerWindowsOpen = IsVehicleOpen(cache.vehicle)
        if not sourceWindowsOpen and not listenerWindowsOpen then
            return WINDOW_CLOSED_MULTIPLIER * WINDOW_CLOSED_MULTIPLIER
        elseif not sourceWindowsOpen or not listenerWindowsOpen then
            return WINDOW_CLOSED_MULTIPLIER
        end
    else
        if not sourceWindowsOpen then
            return WINDOW_CLOSED_MULTIPLIER
        end
    end

    return 1.0
end

local musicInfo = {}
local isMusicPlaying = false
local nearbyMusic = {}

-- Player Music Audibility setting (synced from NUI)
-- If disabled, player won't hear music from other players' vehicles
local playerMusicAudibilityEnabled = true

RegisterNUICallback('SET_PLAYER_MUSIC_AUDIBILITY', function(data, cb)
    playerMusicAudibilityEnabled = data.enabled
    if playerMusicAudibilityEnabled == nil then playerMusicAudibilityEnabled = true end

    -- If disabled, stop all nearby music
    if not playerMusicAudibilityEnabled then
        for netId, _ in pairs(nearbyMusic) do
            NuiMessage('music:nearbyStop', { netId = netId, src = 'audibility' })
        end
        nearbyMusic = {}
    end

    TriggerEvent('codem-hud:client:PlayerMusicAudibilityChanged', playerMusicAudibilityEnabled)
    cb('ok')
end)

-- Cache network ID to avoid repeated native calls
local cachedVehicleNetId = nil
local lastCachedVehicle = nil

local function GetVehicleNetId()
    local vehicle = cache.vehicle
    if not vehicle or vehicle == 0 then
        cachedVehicleNetId = nil
        lastCachedVehicle = nil
        return nil
    end
    -- Only recalculate if vehicle changed
    if vehicle ~= lastCachedVehicle then
        lastCachedVehicle = vehicle
        cachedVehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
    end
    return cachedVehicleNetId
end

-- Inline check for performance (called frequently)
local function IsDriver()
    return cache.seat == -1
end

CreateThread(function()
    while true do
        -- Use longer wait when no music playing (saves CPU)
        if not isMusicPlaying then
            Wait(Utils.W(1000))
        else
            Wait(TIME_UPDATE_INTERVAL) -- Keep real-time for music sync accuracy
            if musicInfo.url and musicInfo.duration then
                if musicInfo.currentTime < musicInfo.duration then
                    musicInfo.currentTime = musicInfo.currentTime + (TIME_UPDATE_INTERVAL / 1000)
                end
            end
        end
    end
end)

AddStateBagChangeHandler('music', nil, function(bagName, key, value, _unused1, _unused2)
    -- Skip if player music audibility is disabled
    if not playerMusicAudibilityEnabled then return end

    -- Extract entity netId from bag name (format: "entity:netId")
    local netId = tonumber(bagName:match('entity:(%d+)'))
    if not netId then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        -- Entity not streamed yet, retry after short delay
        if value and value.playing then
            SetTimeout(500, function()
                local v = NetworkGetEntityFromNetworkId(netId)
                if v and v ~= 0 and DoesEntityExist(v) and not nearbyMusic[netId] then
                    local myCoords = GetEntityCoords(cache.ped)
                    local vCoords = GetEntityCoords(v)
                    local dist = #(myCoords - vCoords)
                    local vol = value.volume or 0.5
                    local maxDist = math.max(10, MUSIC_DISTANCE * (0.5 + vol))
                    if dist <= maxDist then
                        nearbyMusic[netId] = {
                            netId = netId,
                            url = value.url,
                            title = value.title,
                            artist = value.artist,
                            thumbnail = value.thumbnail,
                            coords = vCoords,
                            masterVolume = vol,
                            playing = false,
                            wasPlayingBefore = false,
                            currentTime = value.currentTime or 0,
                            duration = value.duration or 0
                        }
                    end
                end
            end)
        end
        return
    end

    -- Ignore if we're the driver (we control the music)
    local myVehicle = cache.vehicle
    if myVehicle and myVehicle ~= 0 then
        local myNetId = NetworkGetNetworkIdFromEntity(myVehicle)
        if myNetId == netId and IsDriver() then
            return
        end
    end

    local myCoords = GetEntityCoords(cache.ped)
    local vehicleCoords = GetEntityCoords(vehicle)
    local distance = #(myCoords - vehicleCoords)

    -- Check if player is in this vehicle (passenger sync)
    local isInThisVehicle = myVehicle and myVehicle == vehicle

    if value and value.playing then
        local vehicleVolume = value.volume or 0.5
        local dynamicMaxDistance = math.max(10, MUSIC_DISTANCE * (0.5 + vehicleVolume))

        -- Passenger in vehicle - sync music to them
        if isInThisVehicle and not IsDriver() then
            NuiMessage('music:syncToVehicle', {
                url = value.url,
                title = value.title,
                artist = value.artist,
                thumbnail = value.thumbnail,
                duration = value.duration,
                currentTime = value.currentTime,
                isPaused = not value.playing
            })
            return
        end

        -- Nearby vehicle music
        if distance <= dynamicMaxDistance then
            local existingMusic = nearbyMusic[netId]

            if existingMusic then
                local newTime = value.currentTime or 0
                local oldTime = existingMusic.currentTime or 0
                local timeDiff = math.abs(newTime - oldTime)
                local volumeChanged = math.abs((existingMusic.masterVolume or 0) - vehicleVolume) > 0.01

                existingMusic.currentTime = newTime
                existingMusic.masterVolume = vehicleVolume
                existingMusic.coords = vehicleCoords

                if existingMusic.playing and timeDiff > TIME_DRIFT_THRESHOLD then
                    NuiMessage('music:nearbySeek', { netId = netId, time = newTime })
                end

                if existingMusic.playing and volumeChanged then
                    local dynamicMax = math.max(10, MUSIC_DISTANCE * (0.5 + vehicleVolume))
                    local distRatio = math.min(1.0, distance / dynamicMax)
                    local volMult = math.pow(1.0 - distRatio, 1.5)
                    NuiMessage('music:nearbyVolume', { netId = netId, volume = vehicleVolume * volMult })
                end
            else
                nearbyMusic[netId] = {
                    netId = netId,
                    url = value.url,
                    title = value.title,
                    artist = value.artist,
                    thumbnail = value.thumbnail,
                    coords = vehicleCoords,
                    masterVolume = vehicleVolume,
                    playing = false,
                    wasPlayingBefore = false,
                    currentTime = value.currentTime or 0,
                    duration = value.duration or 0
                }
            end
        end
    else
        -- Music stopped
        if isInThisVehicle and not IsDriver() then
            NuiMessage('music:vehicleStopped', {})
        end

        if nearbyMusic[netId] then
            nearbyMusic[netId] = nil
            NuiMessage('music:nearbyStop', { netId = netId, src = 'statebag' })
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- NEARBY VEHICLE SCAN (Backup for state bags) - Adaptive Interval
-- ═══════════════════════════════════════════════════════════════

local scanInterval = Utils.CreateAdaptiveInterval({
    min = 2000,   -- Fast when music found nearby
    max = 5000,   -- Slow when no music nearby
    step = 250,
    threshold = 2
})

CreateThread(function()
    while true do
        Wait(scanInterval.current)

        -- Skip scan if player music audibility is disabled
        if not playerMusicAudibilityEnabled then
            scanInterval.onStable()
            goto continue_scan
        end

        -- Skip scan if player is driving (they control their own music)
        if cache.vehicle and IsDriver() then
            scanInterval.onStable()
            goto continue_scan
        end

        local myCoords = GetEntityCoords(cache.ped)
        local vehicles = GetGamePool('CVehicle')

        -- Early exit if no vehicles
        if #vehicles == 0 then
            scanInterval.onStable()
            goto continue_scan
        end

        local foundMusic = false

        for _, vehicle in ipairs(vehicles) do
            if DoesEntityExist(vehicle) and NetworkGetEntityIsNetworked(vehicle) then
                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                if netId == 0 then goto continue end

                local vehicleState = Entity(vehicle).state
                local musicState = vehicleState and vehicleState.music

                if musicState and musicState.playing then
                    local vehicleCoords = GetEntityCoords(vehicle)
                    local distance = #(myCoords - vehicleCoords)
                    local vehicleVolume = musicState.volume or 0.5
                    local dynamicMaxDistance = math.max(10, MUSIC_DISTANCE * (0.5 + vehicleVolume))

                    -- Skip if this is our vehicle and we're driver
                    local myVehicle = cache.vehicle
                    if myVehicle and myVehicle == vehicle and IsDriver() then
                        goto continue
                    end

                    if distance <= dynamicMaxDistance then
                        foundMusic = true
                        if not nearbyMusic[netId] then
                            nearbyMusic[netId] = {
                                netId = netId,
                                url = musicState.url,
                                title = musicState.title,
                                artist = musicState.artist,
                                thumbnail = musicState.thumbnail,
                                coords = vehicleCoords,
                                masterVolume = vehicleVolume,
                                playing = false,
                                wasPlayingBefore = false,
                                currentTime = musicState.currentTime or 0,
                                duration = musicState.duration or 0
                            }
                        else
                            local existingMusic = nearbyMusic[netId]
                            local newTime = musicState.currentTime or 0
                            local oldTime = existingMusic.currentTime or 0
                            local timeDiff = math.abs(newTime - oldTime)

                            existingMusic.currentTime = newTime
                            existingMusic.coords = vehicleCoords

                            if existingMusic.playing and timeDiff > TIME_DRIFT_THRESHOLD then
                                NuiMessage('music:nearbySeek', { netId = netId, time = newTime })
                            end
                        end
                    end
                elseif nearbyMusic[netId] then
                    nearbyMusic[netId] = nil
                    NuiMessage('music:nearbyStop', { netId = netId, src = 'scan-outrange' })
                end
            end
            ::continue::
        end

        -- Adaptive interval based on nearby music
        if foundMusic then scanInterval.onChanged() else scanInterval.onStable() end
        ::continue_scan::
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- NEARBY VOLUME UPDATE THREAD (Only runs when nearbyMusic exists)
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    local lastVolume = {}
    local fadingOut = {}
    local lastSpatial = {}

    while true do
        Wait(NEARBY_VOLUME_UPDATE_INTERVAL)

        -- Skip if no nearby music to process
        if next(nearbyMusic) == nil then
            goto continue_volume
        end

        local myCoords = GetEntityCoords(cache.ped)

        for netId, musicData in pairs(nearbyMusic) do
            if musicData.coords then
                -- Get fresh vehicle coords every tick for accurate 3D audio
                local vehicle = NetworkGetEntityFromNetworkId(netId)
                if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
                    nearbyMusic[netId] = nil
                    lastVolume[netId] = nil
                    fadingOut[netId] = nil
                    lastSpatial[netId] = nil
                    NuiMessage('music:nearbyStop', { netId = netId, src = 'vol-entity' })
                    goto continue
                end
                musicData.coords = GetEntityCoords(vehicle)

                local masterVolume = musicData.masterVolume or 0.5
                local dynamicMaxDistance = math.max(10, MUSIC_DISTANCE * (0.5 + masterVolume))
                local distance = #(myCoords - musicData.coords)
                local fadeZone = dynamicMaxDistance * 0.15
                local cleanupDistance = MUSIC_DISTANCE * 2.5

                if distance > cleanupDistance then
                    -- Don't cleanup own vehicle during grace period
                    local isGraceVehicle = exitGraceTimer and netId == exitedVehicleNetId
                    if not isGraceVehicle then
                        if not musicData.playing or (musicData.playing and lastVolume[netId] == 0) then
                            nearbyMusic[netId] = nil
                            lastVolume[netId] = nil
                            fadingOut[netId] = nil
                            NuiMessage('music:nearbyStop', { netId = netId, src = 'vol-cleanup' })
                            goto continue
                        end
                    end
                end

                if distance <= dynamicMaxDistance then
                    fadingOut[netId] = nil

                    if not musicData.playing and not musicData.isPaused then
                        -- Get fresh currentTime from state bag for accurate sync
                        local vehicle = NetworkGetEntityFromNetworkId(netId)
                        local freshTime = musicData.currentTime or 0
                        if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                            local vehicleState = Entity(vehicle).state
                            local musicState = vehicleState and vehicleState.music
                            if musicState and musicState.currentTime then
                                freshTime = musicState.currentTime
                                musicData.currentTime = freshTime
                            end
                        end

                        -- Always use nearbyStart (not nearbyResume) because:
                        -- When player walks out of range, NUI player is destroyed.
                        -- nearbyResume would fail silently since there's no player.
                        -- nearbyStart creates a new player and handles existing ones.
                        print('[Music] nearbyStart netId:', netId, 'url:', musicData.url, 'time:', freshTime)
                        NuiMessage('music:nearbyStart', {
                            netId = netId,
                            url = musicData.url,
                            currentTime = freshTime
                        })
                        musicData.playing = true
                        musicData.wasPlayingBefore = true
                        lastVolume[netId] = nil
                        lastSpatial[netId] = nil
                    end

                    -- Calculate 3D position: relative angle (radians) from camera heading
                    local angleRad = 0.0
                    if distance > 0.5 then
                        local camRot = GetGameplayCamRot(2)
                        local camHeading = (camRot.z + 360.0) % 360.0
                        local dx = musicData.coords.x - myCoords.x
                        local dy = musicData.coords.y - myCoords.y
                        local angleToVehicle = math.deg(math.atan(dx, dy))
                        if angleToVehicle < 0 then angleToVehicle = angleToVehicle + 360 end
                        local relativeAngleDeg = (angleToVehicle + camHeading) % 360
                        angleRad = math.rad(relativeAngleDeg)
                    end

                    -- Send 3D position (angle + distance) for HRTF PannerNode
                    NuiMessage('music:nearbyPosition', {
                        netId = netId,
                        angle = angleRad,
                        distance = distance
                    })

                    -- Volume: inverse distance falloff
                    local refDist = 2.0
                    local volumeMultiplier = refDist / math.max(refDist, distance)
                    local windowMult = GetWindowVolumeMultiplier(vehicle)
                    local windowFactor = windowMult < 1.0 and 0.35 or 1.0
                    -- Nearby music max 25% of driver's volume (even point blank)
                    local finalVolume = math.min(0.25, masterVolume * volumeMultiplier * windowFactor)
                    local lastVol = lastVolume[netId] or 0

                    if math.abs(lastVol - finalVolume) > 0.001 then
                        NuiMessage('music:nearbyVolume', { netId = netId, volume = finalVolume })
                        lastVolume[netId] = finalVolume
                        debugPrint(('[Music] vol netId:%d dist:%.1f vol:%.3f'):format(netId, distance, finalVolume))
                    end

                    -- Spatial audio effects (muffled + reverb + doppler)
                    if SPATIAL_AUDIO_ENABLED then
                        local windowMult = GetWindowVolumeMultiplier(vehicle)
                        local muffled = 0.0
                        local reverb = 0.0
                        local doppler = 1.0

                        if MUFFLED_ENABLED then
                            local distRatio = math.min(1.0, distance / dynamicMaxDistance)
                            if windowMult < 1.0 then
                                muffled = MUFFLED_CLOSED_WINDOW
                            else
                                muffled = MUFFLED_OPEN_WINDOW
                            end
                            muffled = math.min(MUFFLED_MAX, muffled + (1.0 - muffled) * distRatio * MUFFLED_DISTANCE_SCALE)
                        end

                        if REVERB_ENABLED and distance > REVERB_START_DISTANCE then
                            local reverbRatio = math.min(1.0, (distance - REVERB_START_DISTANCE) / (dynamicMaxDistance - REVERB_START_DISTANCE))
                            reverb = math.min(REVERB_MAX, reverbRatio * REVERB_MAX)
                        end

                        if DOPPLER_ENABLED and distance > DOPPLER_MIN_DISTANCE then
                            local vel = GetEntityVelocity(vehicle)
                            if vel.x ~= 0.0 or vel.y ~= 0.0 then
                                local dx = musicData.coords.x - myCoords.x
                                local dy = musicData.coords.y - myCoords.y
                                local dirX = dx / distance
                                local dirY = dy / distance
                                -- Radial velocity: positive = moving away, negative = approaching
                                local vRadial = vel.x * dirX + vel.y * dirY
                                -- f' = f * (v_sound / (v_sound + v_radial))
                                doppler = V_SOUND / (V_SOUND + vRadial)
                                doppler = math.max(DOPPLER_MIN, math.min(DOPPLER_MAX, doppler))
                            end
                        end

                        local prev = lastSpatial[netId]
                        if not prev
                            or math.abs(prev.m - muffled) > 0.02
                            or math.abs(prev.r - reverb) > 0.02
                            or math.abs((prev.d or 1.0) - doppler) > 0.005
                        then
                            NuiMessage('music:nearbySpatial', {
                                netId = netId,
                                muffled = muffled,
                                reverb = reverb,
                                doppler = doppler
                            })
                            lastSpatial[netId] = { m = muffled, r = reverb, d = doppler }
                        end
                    end
                elseif distance <= dynamicMaxDistance + fadeZone then
                    if musicData.playing and not fadingOut[netId] then
                        fadingOut[netId] = true
                        CreateThread(function()
                            local currentVol = lastVolume[netId] or 0
                            for i = 10, 0, -1 do
                                if not fadingOut[netId] then break end
                                NuiMessage('music:nearbyVolume', { netId = netId, volume = currentVol * (i / 10) })
                                Wait(100)
                            end
                            if fadingOut[netId] then
                                NuiMessage('music:nearbyStop', { netId = netId, src = 'vol-fadeout' })
                                musicData.playing = false
                                -- Keep wasPlayingBefore true so it resumes when player returns
                                lastVolume[netId] = nil
                                fadingOut[netId] = nil
                                lastSpatial[netId] = nil
                            end
                        end)
                    end
                else
                    if musicData.playing and not fadingOut[netId] then
                        NuiMessage('music:nearbyStop', { netId = netId, src = 'vol-outrange' })
                        musicData.playing = false
                        -- Keep wasPlayingBefore true so it resumes when player returns
                        lastVolume[netId] = nil
                        lastSpatial[netId] = nil
                    end
                end
            end
            ::continue::
        end
        ::continue_volume::
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUDIO RESOLVER (YouTube → Direct Audio URL via Server RPC)
-- ═══════════════════════════════════════════════════════════════

local audioCache = {}
local AUDIO_CACHE_TTL = 25 * 60 * 1000

RegisterNUICallback('music:resolveAudio', function(data, cb)
    local videoId = data.videoId
    if not videoId or #videoId ~= 11 then
        return cb({ success = false })
    end

    -- Check cache
    local cached = audioCache[videoId]
    if cached and (GetGameTimer() - cached.ts) < AUDIO_CACHE_TTL then
        return cb({ success = true, url = cached.url, format = cached.format })
    end

    print('[AudioResolve] Requesting server resolve for: ' .. videoId)
    local res = RPC.execute('codem-hud:music:resolveAudio', { videoId = videoId })
    if res and res.success and res.url then
        print('[AudioResolve] Resolved: ' .. (res.format or '?') .. ' ' .. (res.url or ''):sub(1, 80))
        audioCache[videoId] = { url = res.url, format = res.format, ts = GetGameTimer() }
        cb({ success = true, url = res.url, format = res.format })
    else
        print('[AudioResolve] FAILED for: ' .. videoId)
        cb({ success = false })
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- NUI CALLBACKS (Driver Controls)
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('music:started', function(data, cb)
    if not IsDriver() then return cb({ success = false }) end
    local vehicleNetId = GetVehicleNetId()
    if not vehicleNetId then return cb({ success = false }) end

    musicInfo = {
        vehicleNetId = vehicleNetId,
        url = data.url,
        title = data.title or 'Unknown',
        artist = data.artist or 'Unknown',
        thumbnail = data.thumbnail,
        duration = data.duration or 0,
        currentTime = 0,
        volume = data.volume or 0.5
    }
    isMusicPlaying = true

    RPC.execute('codem-hud:music:started', {
        vehicleNetId = vehicleNetId,
        url = musicInfo.url,
        title = musicInfo.title,
        artist = musicInfo.artist,
        thumbnail = musicInfo.thumbnail,
        duration = musicInfo.duration,
        volume = musicInfo.volume
    })
    cb({ success = true })
end)

RegisterNUICallback('music:paused', function(data, cb)
    if not IsDriver() then return cb({ success = false }) end
    local vehicleNetId = GetVehicleNetId()
    if not vehicleNetId then return cb({ success = false }) end

    isMusicPlaying = false
    RPC.execute('codem-hud:music:paused', {
        vehicleNetId = vehicleNetId,
        currentTime = musicInfo.currentTime
    })
    cb({ success = true })
end)

RegisterNUICallback('music:resumed', function(data, cb)
    if not IsDriver() then return cb({ success = false }) end
    local vehicleNetId = GetVehicleNetId()
    if not vehicleNetId then return cb({ success = false }) end

    isMusicPlaying = true
    if data.currentTime then musicInfo.currentTime = data.currentTime end
    RPC.execute('codem-hud:music:resumed', {
        vehicleNetId = vehicleNetId,
        currentTime = musicInfo.currentTime
    })
    cb({ success = true })
end)

RegisterNUICallback('music:stopped', function(data, cb)
    if not IsDriver() then return cb({ success = false }) end
    local vehicleNetId = GetVehicleNetId()

    isMusicPlaying = false
    musicInfo = {}

    if vehicleNetId then
        RPC.execute('codem-hud:music:stopped', { vehicleNetId = vehicleNetId })
    end
    cb({ success = true })
end)

RegisterNUICallback('music:ended', function(data, cb)
    if not IsDriver() then return cb({ success = false }) end
    local vehicleNetId = GetVehicleNetId()

    isMusicPlaying = false
    musicInfo = {}

    if vehicleNetId then
        RPC.execute('codem-hud:music:ended', { vehicleNetId = vehicleNetId })
    end
    cb({ success = true })
end)

RegisterNUICallback('music:seek', function(data, cb)
    if not IsDriver() then return cb({ success = false }) end
    local vehicleNetId = GetVehicleNetId()
    if not vehicleNetId then return cb({ success = false }) end

    if musicInfo.url then musicInfo.currentTime = data.time or 0 end
    RPC.execute('codem-hud:music:seek', {
        vehicleNetId = vehicleNetId,
        time = data.time
    })
    cb({ success = true })
end)

RegisterNUICallback('music:volumeChanged', function(data, cb)
    if not IsDriver() then return cb({ success = false }) end
    local vehicleNetId = GetVehicleNetId()
    if not vehicleNetId then return cb({ success = false }) end

    if musicInfo.url then musicInfo.volume = data.volume end
    RPC.execute('codem-hud:music:volumeChanged', {
        vehicleNetId = vehicleNetId,
        volume = data.volume
    })
    cb({ success = true })
end)

-- ═══════════════════════════════════════════════════════════════
-- ENGINE STATE HANDLER (Stop music when engine turns off)
-- ═══════════════════════════════════════════════════════════════

local wasEngineRunning = false

CreateThread(function()
    while true do
        -- Only check when music is playing and player is driver
        if isMusicPlaying and musicInfo.url and cache.vehicle and cache.seat == -1 then
            local engineRunning = GetIsVehicleEngineRunning(cache.vehicle)

            -- Engine just turned off while music was playing
            if wasEngineRunning and not engineRunning then
                -- Wait and re-check to avoid false positive during exit animation
                -- (FiveM reports engine as off for 3+ seconds during exit)
                Wait(3500)

                -- Re-verify: still in vehicle, still driver, engine still off
                if isMusicPlaying and musicInfo.url and cache.vehicle and cache.seat == -1
                   and IsPedInAnyVehicle(cache.ped, false)
                   and not GetIsVehicleEngineRunning(cache.vehicle) then
                    print('[Music] Engine OFF confirmed - stopping music')
                    local vehicleNetId = musicInfo.vehicleNetId
                    if vehicleNetId then
                        RPC.execute('codem-hud:music:stopped', { vehicleNetId = vehicleNetId })
                    end
                    NuiMessage('music:driverExited', {})
                    isMusicPlaying = false
                    musicInfo = {}
                end
            end

            wasEngineRunning = engineRunning
            Wait(Utils.W(500))
        else
            wasEngineRunning = false
            Wait(Utils.W(1000))
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- VEHICLE DELETED CHECK (entity no longer exists)
-- ═══════════════════════════════════════════════════════════════

local function ForceStopAllMusic(reason)
    print('[Music] ForceStopAllMusic -', reason)

    -- Stop driver music
    if musicInfo.vehicleNetId then
        RPC.execute('codem-hud:music:stopped', { vehicleNetId = musicInfo.vehicleNetId })
    end
    isMusicPlaying = false
    musicInfo = {}

    -- Stop grace period
    if exitedVehicleNetId then
        RPC.execute('codem-hud:music:stopped', { vehicleNetId = exitedVehicleNetId })
    end
    exitGraceTimer = nil
    exitedVehicleNetId = nil
    exitedMusicInfo = nil

    -- Stop all nearby
    for netId, _ in pairs(nearbyMusic) do
        nearbyMusic[netId] = nil
    end

    -- Nuclear NUI cleanup: kills driver player + bridge player + all nearby players
    NuiMessage('music:forceStopAll', {})
end

CreateThread(function()
    while true do
        Wait(200)

        local inVehicle = IsPedInAnyVehicle(cache.ped, false)

        -- Player not in vehicle but music state is active → vehicle was deleted
        if not inVehicle then
            local hasActiveMusic = isMusicPlaying and musicInfo.url
            local hasGrace = exitGraceTimer ~= nil

            if hasActiveMusic or hasGrace then
                -- Check if the vehicle actually exists
                local netId = musicInfo.vehicleNetId or exitedVehicleNetId
                local entityGone = true
                if netId then
                    local v = NetworkGetEntityFromNetworkId(netId)
                    if v and v ~= 0 and DoesEntityExist(v) and IsEntityAVehicle(v) then
                        entityGone = false
                    end
                end

                if hasActiveMusic and entityGone then
                    ForceStopAllMusic('driver vehicle deleted')
                elseif hasGrace and entityGone then
                    ForceStopAllMusic('grace vehicle deleted')
                end
            end
        end
    end
end)

-- ════════════════════════════════════════════════════════���══════
-- VEHICLE ENTER/EXIT HANDLERS (Grace period for driver exit)
-- ═══════════════════════════════════════════════════════════════

local EXIT_GRACE_PERIOD = (Config.VehicleMusic.ExitGracePeriod or 30) * 1000
local exitGraceTimer = nil
local exitedVehicleNetId = nil
local exitedMusicInfo = nil

AddEventHandler('codem-hud:client:vehicleEntered', function()
    -- Driver returned to vehicle during grace period
    if exitGraceTimer and IsDriver() and exitedVehicleNetId then
        local currentNetId = GetVehicleNetId()
        if currentNetId == exitedVehicleNetId then
            exitGraceTimer = nil
            local netId = exitedVehicleNetId
            exitedVehicleNetId = nil

            -- Restore music state
            if exitedMusicInfo then
                musicInfo = exitedMusicInfo
                isMusicPlaying = true
                exitedMusicInfo = nil

                -- Tell NUI to reclaim the nearby player as driver player (no audio gap)
                NuiMessage('music:graceReenter', {
                    netId = netId,
                    url = musicInfo.url,
                    title = musicInfo.title,
                    artist = musicInfo.artist,
                    thumbnail = musicInfo.thumbnail,
                    duration = musicInfo.duration
                })

                -- Remove from nearby tracking
                nearbyMusic[netId] = nil
            end
            return
        end
    end

    exitGraceTimer = nil
    exitedVehicleNetId = nil
    exitedMusicInfo = nil

    if IsDriver() then return end

    -- Request sync from server for passengers
    local vehicleNetId = GetVehicleNetId()
    if vehicleNetId then
        TriggerServerEvent('codem-hud:server:music:requestSync', vehicleNetId)
    end
end)

AddEventHandler('codem-hud:client:vehicleExited', function()
    print('[Music] vehicleExited - isMusicPlaying:', isMusicPlaying, 'hasUrl:', musicInfo.url ~= nil)
    if isMusicPlaying and musicInfo.url then
        local vehicleNetId = musicInfo.vehicleNetId
        local vehicle = vehicleNetId and NetworkGetEntityFromNetworkId(vehicleNetId) or 0
        print('[Music] vehicleExited - netId:', vehicleNetId, 'vehicle:', vehicle, 'gracePeriod:', EXIT_GRACE_PERIOD)

        -- If music is playing, engine WAS running (engine handler would have stopped it otherwise)
        -- FiveM reports engine as OFF during exit animation, so don't check it here
        -- Grace timer will handle engine-off detection after 3 seconds
        if EXIT_GRACE_PERIOD > 0 then
            -- Engine running: start grace period, don't stop music yet
            exitedVehicleNetId = vehicleNetId
            exitedMusicInfo = {
                vehicleNetId = vehicleNetId,
                url = musicInfo.url,
                title = musicInfo.title,
                artist = musicInfo.artist,
                thumbnail = musicInfo.thumbnail,
                duration = musicInfo.duration,
                currentTime = musicInfo.currentTime,
                volume = musicInfo.volume
            }
            isMusicPlaying = false
            musicInfo = {}

            -- Tell NUI driver exited with grace (keeps player alive for seamless transition)
            print('[Music] GRACE PERIOD started - sending driverExitedGrace, netId:', vehicleNetId)
            NuiMessage('music:driverExitedGrace', { netId = vehicleNetId })

            -- Immediately register own vehicle as nearby music source
            -- so the driver hears their car's music from outside
            if vehicleNetId and vehicle ~= 0 and DoesEntityExist(vehicle) then
                nearbyMusic[vehicleNetId] = {
                    netId = vehicleNetId,
                    url = exitedMusicInfo.url,
                    title = exitedMusicInfo.title,
                    artist = exitedMusicInfo.artist,
                    thumbnail = exitedMusicInfo.thumbnail,
                    coords = GetEntityCoords(vehicle),
                    masterVolume = exitedMusicInfo.volume or 0.5,
                    playing = false,
                    wasPlayingBefore = false,
                    currentTime = exitedMusicInfo.currentTime or 0,
                    duration = exitedMusicInfo.duration or 0
                }
            end

            exitGraceTimer = GetGameTimer()

            -- Keep engine running during grace period
            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                SetVehicleEngineOn(vehicle, true, true, false)
            end

            CreateThread(function()
                local startTime = exitGraceTimer
                while exitGraceTimer == startTime do
                    Wait(1000)

                    -- Check if timer was cancelled (driver returned)
                    if exitGraceTimer ~= startTime then return end

                    -- Keep engine alive during grace period
                    if exitedVehicleNetId then
                        local v = NetworkGetEntityFromNetworkId(exitedVehicleNetId)
                        if v and v ~= 0 and DoesEntityExist(v) then
                            SetVehicleEngineOn(v, true, true, false)
                        end
                    end

                    -- Check if grace period expired
                    if GetGameTimer() - startTime >= EXIT_GRACE_PERIOD then
                        -- Stop music and engine
                        if exitedVehicleNetId then
                            -- Stop nearby sound first
                            if nearbyMusic[exitedVehicleNetId] then
                                nearbyMusic[exitedVehicleNetId] = nil
                                NuiMessage('music:nearbyStop', { netId = exitedVehicleNetId, src = 'grace-expired' })
                            end

                            RPC.execute('codem-hud:music:stopped', { vehicleNetId = exitedVehicleNetId })

                            -- Turn off engine
                            local v = NetworkGetEntityFromNetworkId(exitedVehicleNetId)
                            if v and v ~= 0 and DoesEntityExist(v) then
                                SetVehicleEngineOn(v, false, false, true)
                            end
                        end

                        exitGraceTimer = nil
                        exitedVehicleNetId = nil
                        exitedMusicInfo = nil
                        return
                    end

                    -- Check if vehicle no longer exists
                    -- Engine is kept alive by SetVehicleEngineOn above
                    if exitedVehicleNetId then
                        local v = NetworkGetEntityFromNetworkId(exitedVehicleNetId)
                        if not v or v == 0 or not DoesEntityExist(v) then
                            -- Vehicle gone - stop nearby sound
                            if nearbyMusic[exitedVehicleNetId] then
                                nearbyMusic[exitedVehicleNetId] = nil
                                NuiMessage('music:nearbyStop', { netId = exitedVehicleNetId, src = 'grace-entitygone' })
                            end

                            RPC.execute('codem-hud:music:stopped', { vehicleNetId = exitedVehicleNetId })
                            exitGraceTimer = nil
                            exitedVehicleNetId = nil
                            exitedMusicInfo = nil
                            return
                        end
                    end
                end
            end)
        else
            -- Engine off or no grace period: stop immediately
            print('[Music] NO grace period - engine off or disabled, stopping immediately')
            if vehicleNetId then
                RPC.execute('codem-hud:music:stopped', { vehicleNetId = vehicleNetId })
            end
            NuiMessage('music:driverExited', {})
            isMusicPlaying = false
            musicInfo = {}
        end
    else
        print('[Music] vehicleExited - not playing music, sending passengerExited')
        NuiMessage('music:passengerExited', {})
        isMusicPlaying = false
        musicInfo = {}
    end

    -- Stop all nearby music (but NOT during grace period - driver should hear own car as nearby)
    if not exitGraceTimer then
        for netId, _ in pairs(nearbyMusic) do
            nearbyMusic[netId] = nil
            NuiMessage('music:nearbyStop', { netId = netId, src = 'exit-cleanup-all' })
        end
    else
        -- Grace period active: only stop nearby music from OTHER vehicles
        for netId, _ in pairs(nearbyMusic) do
            if netId ~= exitedVehicleNetId then
                nearbyMusic[netId] = nil
                NuiMessage('music:nearbyStop', { netId = netId, src = 'exit-cleanup-other' })
            end
        end
    end
end)

-- Sync event from server (for passengers)
RegisterNetEvent('codem-hud:client:music:sync', function(data)
    if data.driverSrc == GetPlayerServerId(PlayerId()) then return end

    local myVehicle = cache.vehicle
    if not myVehicle or myVehicle == 0 then return end

    local vehicleNetId = NetworkGetNetworkIdFromEntity(myVehicle)
    if vehicleNetId ~= data.vehicleNetId then return end

    if not IsDriver() then
        NuiMessage('music:syncToVehicle', {
            url = data.url,
            title = data.title,
            artist = data.artist,
            thumbnail = data.thumbnail,
            duration = data.duration,
            currentTime = data.currentTime,
            isPaused = not data.playing
        })
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- DRIVER DISCONNECTED (fallback for state bag)
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('codem-hud:client:music:driverDisconnected', function(netId)
    if nearbyMusic[netId] then
        nearbyMusic[netId] = nil
        NuiMessage('music:nearbyStop', { netId = netId, src = 'disconnect' })
    end

    if musicInfo.vehicleNetId == netId then
        NuiMessage('music:vehicleStopped', {})
        isMusicPlaying = false
        musicInfo = {}
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- RESOURCE CLEANUP
-- ═══════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Reset music state
    isMusicPlaying = false
    musicInfo = {}
    wasEngineRunning = false

    -- Stop all nearby music
    for netId, _ in pairs(nearbyMusic) do
        NuiMessage('music:nearbyStop', { netId = netId, src = 'resstop' })
    end
    nearbyMusic = {}

    debugPrint('[VehicleMusic] Resource stopped, music state cleaned up')
end)

debugPrint('[VehicleMusic] Client module loaded')
