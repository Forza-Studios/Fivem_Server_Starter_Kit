--[[
    Vehicle Music Server
    Uses Entity state bags for sync 
]]

if not Config.VehicleMusic or not Config.VehicleMusic.Enabled then return end

local MusicRegistry = {}
local SERVER_UPDATE_INTERVAL = Config.VehicleMusic.ServerUpdateInterval or 1000

-- Update music time on server for all playing vehicles
CreateThread(function()
    while true do
        Wait(SERVER_UPDATE_INTERVAL)

        for netId, data in pairs(MusicRegistry) do
            if data.playing then
                local elapsed = os.time() - data.serverStartTime
                data.serverCurrentTime = data.serverInitialTime + elapsed

                -- Update vehicle state bag
                local vehicle = NetworkGetEntityFromNetworkId(netId)
                if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                    local currentState = Entity(vehicle).state.music
                    if currentState then
                        currentState.currentTime = data.serverCurrentTime
                        Entity(vehicle).state:set('music', currentState, true)
                    end

                    -- When song reaches duration, loop back to start
                    -- This prevents nearby music from cutting when song ends
                    if data.duration and data.duration > 0 then
                        if data.serverCurrentTime >= data.duration then
                            data.serverCurrentTime = 0
                            data.serverInitialTime = 0
                            data.serverStartTime = os.time()
                        end
                    end
                else
                    -- Vehicle no longer exists
                    MusicRegistry[netId] = nil
                end
            end
        end
    end
end)

-- Music started
RPC.Register('codem-hud:music:started', function(src, data)
    local vehicleNetId = data.vehicleNetId
    if not vehicleNetId then return { success = false } end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 then return { success = false } end

    local initialTime = data.currentTime or 0

    MusicRegistry[vehicleNetId] = {
        url = data.url,
        title = data.title,
        artist = data.artist,
        thumbnail = data.thumbnail,
        duration = data.duration or 0,
        volume = data.volume or 0.5,
        playing = true,
        driverSrc = src,
        serverStartTime = os.time(),
        serverInitialTime = initialTime,
        serverCurrentTime = initialTime
    }

    -- Set vehicle state bag
    Entity(vehicle).state:set('music', {
        url = data.url,
        title = data.title,
        artist = data.artist,
        thumbnail = data.thumbnail,
        duration = data.duration or 0,
        volume = data.volume or 0.5,
        playing = true,
        currentTime = initialTime,
        driverSrc = src
    }, true)

    return { success = true }
end)

-- Music paused
RPC.Register('codem-hud:music:paused', function(src, data)
    local vehicleNetId = data.vehicleNetId
    if not vehicleNetId or not MusicRegistry[vehicleNetId] then return end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 then return end

    MusicRegistry[vehicleNetId].playing = false
    MusicRegistry[vehicleNetId].serverInitialTime = data.currentTime or MusicRegistry[vehicleNetId].serverCurrentTime
    MusicRegistry[vehicleNetId].serverCurrentTime = MusicRegistry[vehicleNetId].serverInitialTime

    local currentState = Entity(vehicle).state.music
    if currentState then
        currentState.playing = false
        currentState.currentTime = MusicRegistry[vehicleNetId].serverCurrentTime
        Entity(vehicle).state:set('music', currentState, true)
    end
end)

-- Music resumed
RPC.Register('codem-hud:music:resumed', function(src, data)
    local vehicleNetId = data.vehicleNetId
    if not vehicleNetId or not MusicRegistry[vehicleNetId] then return end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 then return end

    local currentTime = data.currentTime or MusicRegistry[vehicleNetId].serverCurrentTime

    MusicRegistry[vehicleNetId].playing = true
    MusicRegistry[vehicleNetId].serverInitialTime = currentTime
    MusicRegistry[vehicleNetId].serverCurrentTime = currentTime
    MusicRegistry[vehicleNetId].serverStartTime = os.time()

    local currentState = Entity(vehicle).state.music
    if currentState then
        currentState.playing = true
        currentState.currentTime = currentTime
        Entity(vehicle).state:set('music', currentState, true)
    end
end)

-- Music stopped
RPC.Register('codem-hud:music:stopped', function(src, data)
    local vehicleNetId = data.vehicleNetId
    if not vehicleNetId then return end

    MusicRegistry[vehicleNetId] = nil

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and vehicle ~= 0 then
        Entity(vehicle).state:set('music', nil, true)
    end
end)

-- Music ended
RPC.Register('codem-hud:music:ended', function(src, data)
    local vehicleNetId = data.vehicleNetId
    if not vehicleNetId then return end

    MusicRegistry[vehicleNetId] = nil

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle and vehicle ~= 0 then
        Entity(vehicle).state:set('music', nil, true)
    end
end)

-- Music seek
RPC.Register('codem-hud:music:seek', function(src, data)
    local vehicleNetId = data.vehicleNetId
    if not vehicleNetId or not MusicRegistry[vehicleNetId] then return end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 then return end

    local time = data.time or 0

    MusicRegistry[vehicleNetId].serverCurrentTime = time
    MusicRegistry[vehicleNetId].serverInitialTime = time
    MusicRegistry[vehicleNetId].serverStartTime = os.time()

    local currentState = Entity(vehicle).state.music
    if currentState then
        currentState.currentTime = time
        Entity(vehicle).state:set('music', currentState, true)
    end
end)

-- Volume changed
RPC.Register('codem-hud:music:volumeChanged', function(src, data)
    local vehicleNetId = data.vehicleNetId
    if not vehicleNetId or not MusicRegistry[vehicleNetId] then return end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 then return end

    MusicRegistry[vehicleNetId].volume = data.volume

    local currentState = Entity(vehicle).state.music
    if currentState then
        currentState.volume = data.volume
        Entity(vehicle).state:set('music', currentState, true)
    end
end)

-- Request sync when entering vehicle
RegisterNetEvent('codem-hud:server:music:requestSync', function(vehicleNetId)
    local src = source
    if not vehicleNetId then return end

    local data = MusicRegistry[vehicleNetId]
    if data and data.playing then
        TriggerClientEvent('codem-hud:client:music:sync', src, {
            vehicleNetId = vehicleNetId,
            url = data.url,
            title = data.title,
            artist = data.artist,
            thumbnail = data.thumbnail,
            duration = data.duration,
            currentTime = data.serverCurrentTime,
            playing = data.playing,
            volume = data.volume,
            driverSrc = data.driverSrc
        })
    end
end)

-- Clean up when player disconnects
AddEventHandler('playerDropped', function()
    local src = source

    for netId, data in pairs(MusicRegistry) do
        if data.driverSrc == src then
            MusicRegistry[netId] = nil
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            if vehicle and vehicle ~= 0 then
                Entity(vehicle).state:set('music', nil, true)
            end
            TriggerClientEvent('codem-hud:client:music:driverDisconnected', -1, netId)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUDIO RESOLVER (YouTube → Direct Audio URL)
-- Chain: Custom → RapidAPI → Converter APIs → Piped → Innertube
-- ═══════════════════════════════════════════════════════════════

local PIPED_APIS = {
    'https://pipedapi.kavin.rocks/streams/',
    'https://pipedapi.adminforge.de/streams/',
    'https://pipedapi.r4fo.com/streams/',
    'https://pipedapi.leptons.xyz/streams/',
    'https://api.piped.yt/streams/',
    'https://pipedapi.moomoo.me/streams/',
}

local audioResolveCache = {}
local AUDIO_CACHE_TTL = 25 * 60

local function getMimeFormat(mime)
    if not mime then return 'webm' end
    if mime:find('webm') or mime:find('opus') then return 'webm'
    elseif mime:find('mp4') or mime:find('aac') then return 'mp4'
    elseif mime:find('ogg') then return 'ogg'
    end
    return 'webm'
end

local function findBestAudioStream(streams)
    local bestUrl = nil
    local bestBitrate = 0
    local bestFormat = 'webm'

    for _, stream in ipairs(streams) do
        local url = stream.url
        local mime = stream.mimeType or stream.type or ''
        local bitrate = stream.bitrate or 0

        if type(bitrate) == 'string' then bitrate = tonumber(bitrate) or 0 end

        if url and mime:find('audio') then
            if bitrate > bestBitrate then
                bestBitrate = bitrate
                bestUrl = url
                bestFormat = getMimeFormat(mime)
            end
        end
    end

    return bestUrl, bestFormat
end

-- RapidAPI youtube-mp36 (requires Config.VehicleMusic.RapidApiKey)
local function resolveAudioRapidApi(videoId, cb)
    local apiKey = Config.VehicleMusic and Config.VehicleMusic.RapidApiKey
    if not apiKey then return cb(nil) end

    PerformHttpRequest('https://youtube-mp36.p.rapidapi.com/dl?id=' .. videoId, function(statusCode, responseText)
        if statusCode == 200 and responseText then
            local ok, decoded = pcall(json.decode, responseText)
            if ok and decoded and decoded.status == 'ok' and decoded.link then
                print('[AudioResolve] RapidAPI success')
                return cb({ url = decoded.link, format = 'mp3' })
            end
            if ok and decoded then
                print('[AudioResolve] RapidAPI response: status=' .. (decoded.status or 'nil') .. ' msg=' .. (decoded.msg or 'nil'))
            end
        end
        print('[AudioResolve] RapidAPI failed (' .. (statusCode or 'nil') .. ')')
        cb(nil)
    end, 'GET', '', {
        ['X-RapidAPI-Key'] = apiKey,
        ['X-RapidAPI-Host'] = 'youtube-mp36.p.rapidapi.com'
    })
end

-- Free converter API (download-lagu-mp3.com)
local function resolveAudioConverter(videoId, cb)
    PerformHttpRequest('https://api.download-lagu-mp3.com/@api/json/mp3/' .. videoId, function(statusCode, responseText)
        if statusCode == 200 and responseText then
            local ok, decoded = pcall(json.decode, responseText)
            if ok and decoded and decoded.vidInfo then
                -- Try to find highest quality download URL
                for _, quality in pairs(decoded.vidInfo) do
                    if quality.dloadUrl then
                        local url = quality.dloadUrl
                        -- Fix protocol-relative URLs
                        if url:sub(1, 2) == '//' then url = 'https:' .. url end
                        print('[AudioResolve] Converter API success (bitrate: ' .. (quality.bitrate or '?') .. ')')
                        return cb({ url = url, format = 'mp3' })
                    end
                end
            end
        end
        print('[AudioResolve] Converter API failed (' .. (statusCode or 'nil') .. ')')
        cb(nil)
    end, 'GET', '', {
        ['Accept'] = 'application/json',
        ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    })
end

local function resolveAudioPiped(videoId, apiIndex, cb)
    if apiIndex > #PIPED_APIS then
        return cb(nil)
    end

    PerformHttpRequest(PIPED_APIS[apiIndex] .. videoId, function(statusCode, responseText)
        if statusCode == 200 and responseText then
            local ok, decoded = pcall(json.decode, responseText)
            if ok and decoded and decoded.audioStreams then
                local bestUrl, bestFormat = findBestAudioStream(decoded.audioStreams)
                if bestUrl then
                    print('[AudioResolve] Piped success: ' .. PIPED_APIS[apiIndex])
                    return cb({ url = bestUrl, format = bestFormat })
                end
            end
        end
        print('[AudioResolve] Piped failed (' .. (statusCode or 'nil') .. '): ' .. PIPED_APIS[apiIndex])
        resolveAudioPiped(videoId, apiIndex + 1, cb)
    end, 'GET', '', { ['Accept'] = 'application/json' })
end


-- Innertube API key (public, used by YouTube apps)
local INNERTUBE_API_KEY = 'AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w'
local INNERTUBE_URL = 'https://www.youtube.com/youtubei/v1/player?key=' .. INNERTUBE_API_KEY .. '&prettyPrint=false'

-- Try multiple innertube clients in sequence
-- ANDROID_VR is the most reliable (no PO token, no JS player needed)
local INNERTUBE_CLIENTS = {
    {
        name = 'ANDROID_VR',
        body = function(videoId) return json.encode({
            videoId = videoId,
            params = '8AEByAMkuAQP',
            context = { client = {
                clientName = 'ANDROID_VR', clientVersion = '1.57.29',
                deviceMake = 'Oculus', deviceModel = 'Quest 3',
                osName = 'Android', osVersion = '12',
                androidSdkVersion = 32, hl = 'en', gl = 'US'
            }},
            contentCheckOk = true, racyCheckOk = true,
            playbackContext = { contentPlaybackContext = { html5Preference = 'HTML5_PREF_WANTS' } }
        }) end,
        headers = {
            ['Content-Type'] = 'application/json',
            ['User-Agent'] = 'com.google.android.apps.youtube.vr.oculus/1.57.29 (Linux; U; Android 12; eureka-user Build/SQ3A.220605.009.A1) gzip',
            ['X-Youtube-Client-Name'] = '28',
            ['X-Youtube-Client-Version'] = '1.57.29'
        }
    },
    {
        name = 'ANDROID_TESTSUITE',
        body = function(videoId) return json.encode({
            videoId = videoId,
            params = 'YAHI',
            context = { client = {
                clientName = 'ANDROID_TESTSUITE', clientVersion = '1.9',
                platform = 'MOBILE',
                osName = 'Android', osVersion = '14',
                androidSdkVersion = 34, hl = 'en', gl = 'US'
            }},
            contentCheckOk = true, racyCheckOk = true
        }) end,
        headers = {
            ['Content-Type'] = 'application/json',
            ['User-Agent'] = 'com.google.android.youtube/19.29.37 (Linux; U; Android 14; en_US; ; Build/TP1A;) gzip',
            ['X-Youtube-Client-Name'] = '30',
            ['X-Youtube-Client-Version'] = '1.9'
        }
    },
    {
        name = 'ANDROID_VR_ALT',
        body = function(videoId) return json.encode({
            videoId = videoId,
            params = '8AEByAMkuAQP',
            context = { client = {
                clientName = 'ANDROID_VR', clientVersion = '1.60.19',
                deviceMake = 'Oculus', deviceModel = 'Quest 3',
                osName = 'Android', osVersion = '12L',
                androidSdkVersion = 32, hl = 'en', gl = 'US'
            }},
            contentCheckOk = true, racyCheckOk = true,
            playbackContext = { contentPlaybackContext = { html5Preference = 'HTML5_PREF_WANTS' } }
        }) end,
        headers = {
            ['Content-Type'] = 'application/json',
            ['User-Agent'] = 'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
            ['X-Youtube-Client-Name'] = '28',
            ['X-Youtube-Client-Version'] = '1.60.19'
        }
    },
}

local function tryInnertubeClient(videoId, clientIndex, cb)
    if clientIndex > #INNERTUBE_CLIENTS then
        return cb(nil)
    end

    local client = INNERTUBE_CLIENTS[clientIndex]
    local body = client.body(videoId)

    PerformHttpRequest(INNERTUBE_URL, function(statusCode, responseText)
        if statusCode == 200 and responseText then
            local ok, decoded = pcall(json.decode, responseText)
            if ok and decoded then
                local playability = decoded.playabilityStatus and decoded.playabilityStatus.status or 'nil'
                local hasStreaming = decoded.streamingData ~= nil

                if decoded.streamingData then
                    -- Try adaptiveFormats first (higher quality), then regular formats
                    local allStreams = {}
                    local adaptive = decoded.streamingData.adaptiveFormats or {}
                    local regular = decoded.streamingData.formats or {}
                    for _, f in ipairs(adaptive) do table.insert(allStreams, f) end
                    for _, f in ipairs(regular) do table.insert(allStreams, f) end

                    local audioFormats = {}
                    local cipherCount = 0
                    for _, f in ipairs(allStreams) do
                        if f.mimeType and f.mimeType:find('audio') then
                            if f.url then
                                table.insert(audioFormats, f)
                            elseif f.signatureCipher then
                                cipherCount = cipherCount + 1
                            end
                        end
                    end
                    if #audioFormats > 0 then
                        local bestUrl, bestFormat = findBestAudioStream(audioFormats)
                        if bestUrl then
                            print(('[AudioResolve] Innertube %s success (%d audio streams)'):format(client.name, #audioFormats))
                            return cb({ url = bestUrl, format = bestFormat })
                        end
                    end
                    print(('[AudioResolve] Innertube %s: playability=%s hasStreaming=%s total=%d audioWithUrl=%d cipherOnly=%d'):format(
                        client.name, playability, tostring(hasStreaming), #allStreams, #audioFormats, cipherCount))
                else
                    print(('[AudioResolve] Innertube %s: playability=%s noStreamingData'):format(client.name, playability))
                end
            end
        else
            print(('[AudioResolve] Innertube %s: HTTP %s'):format(client.name, tostring(statusCode)))
        end
        tryInnertubeClient(videoId, clientIndex + 1, cb)
    end, 'POST', body, client.headers)
end

local function cacheAndReturn(videoId, result, cb)
    audioResolveCache[videoId] = { url = result.url, format = result.format, ts = os.time() }
    cb({ success = true, url = result.url, format = result.format })
end

-- Custom resolver (Config.VehicleMusic.AudioResolverUrl)
local function resolveAudioCustom(videoId, cb)
    local customUrl = Config.VehicleMusic and Config.VehicleMusic.AudioResolverUrl
    if not customUrl then return cb(nil) end

    local body = json.encode({
        url = 'https://www.youtube.com/watch?v=' .. videoId,
        downloadMode = 'audio',
        audioFormat = 'opus'
    })

    PerformHttpRequest(customUrl, function(statusCode, responseText)
        if statusCode == 200 and responseText then
            local ok, decoded = pcall(json.decode, responseText)
            if ok and decoded and decoded.url then
                print('[AudioResolve] Custom resolver success: ' .. customUrl)
                return cb({ url = decoded.url, format = 'webm' })
            end
        end
        print('[AudioResolve] Custom resolver failed (' .. (statusCode or 'nil') .. '): ' .. customUrl)
        cb(nil)
    end, 'POST', body, {
        ['Content-Type'] = 'application/json',
        ['Accept'] = 'application/json',
    })
end

-- YouTube page HTML scraping (extract ytInitialPlayerResponse)
local function resolveAudioFromPage(videoId, cb)
    local url = 'https://www.youtube.com/watch?v=' .. videoId
    local headers = {
        ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        ['Accept-Language'] = 'en-US,en;q=0.9',
        ['Cookie'] = 'CONSENT=PENDING+999; SOCS=CAESEwgDEgk0ODE3Nzk3MjQaAmVuIAEaBgiA_LyuBg'
    }

    print('[AudioResolve] Trying page scrape for: ' .. videoId)

    PerformHttpRequest(url, function(statusCode, responseText)
        if statusCode ~= 200 or not responseText then
            print('[AudioResolve] Page scrape HTTP ' .. tostring(statusCode) .. ' (length: ' .. tostring(responseText and #responseText or 0) .. ')')
            return cb(nil)
        end

        -- Find ytInitialPlayerResponse in HTML
        local startPos = responseText:find('ytInitialPlayerResponse')
        if not startPos then
            print('[AudioResolve] Page scrape: no ytInitialPlayerResponse (page: ' .. #responseText .. ' bytes)')
            return cb(nil)
        end

        local jsonStart = responseText:find('{', startPos)
        if not jsonStart then
            print('[AudioResolve] Page scrape: no JSON start found')
            return cb(nil)
        end

        -- Count braces to find matching end (limit to 500KB scan)
        local depth = 0
        local jsonEnd = nil
        local maxScan = math.min(#responseText, jsonStart + 500000)
        for i = jsonStart, maxScan do
            local byte = responseText:byte(i)
            if byte == 123 then depth = depth + 1     -- {
            elseif byte == 125 then                    -- }
                depth = depth - 1
                if depth == 0 then
                    jsonEnd = i
                    break
                end
            end
        end

        if not jsonEnd then
            print('[AudioResolve] Page scrape: could not find JSON end (depth: ' .. depth .. ')')
            return cb(nil)
        end

        local playerJson = responseText:sub(jsonStart, jsonEnd)
        local ok, decoded = pcall(json.decode, playerJson)
        if not ok or not decoded then
            print('[AudioResolve] Page scrape: JSON parse failed (size: ' .. #playerJson .. ')')
            return cb(nil)
        end

        local playability = decoded.playabilityStatus and decoded.playabilityStatus.status or 'nil'

        if decoded.streamingData then
            -- Check for HLS manifest (usually works without signature)
            if decoded.streamingData.hlsManifestUrl then
                print('[AudioResolve] Page scrape: found HLS manifest')
                return cb({ url = decoded.streamingData.hlsManifestUrl, format = 'hls' })
            end

            -- Try adaptiveFormats with direct URL (no signatureCipher)
            local allFormats = decoded.streamingData.adaptiveFormats or {}
            local audioFormats = {}
            local cipherCount = 0
            for _, f in ipairs(allFormats) do
                if f.mimeType and f.mimeType:find('audio') then
                    if f.url then
                        table.insert(audioFormats, f)
                    elseif f.signatureCipher then
                        cipherCount = cipherCount + 1
                    end
                end
            end

            if #audioFormats > 0 then
                local bestUrl, bestFormat = findBestAudioStream(audioFormats)
                if bestUrl then
                    print('[AudioResolve] Page scrape success (' .. #audioFormats .. ' direct audio)')
                    return cb({ url = bestUrl, format = bestFormat })
                end
            end

            print(('[AudioResolve] Page scrape: playability=%s directAudio=%d cipherOnly=%d'):format(
                playability, #audioFormats, cipherCount))
        else
            print('[AudioResolve] Page scrape: playability=' .. playability .. ' noStreamingData')
        end

        cb(nil)
    end, 'GET', '', headers)
end

local function resolveAudio(videoId, cb)
    -- Chain: Piped → Innertube → Custom → RapidAPI → ConverterAPI → PageScrape
    -- Piped/Innertube first: their URLs work in browser <audio> elements
    -- ConverterAPI/RapidAPI URLs (epsilon CDN etc.) fail to load in FiveM browser
    resolveAudioPiped(videoId, 1, function(r1)
        if r1 then return cacheAndReturn(videoId, r1, cb) end
        tryInnertubeClient(videoId, 1, function(r2)
            if r2 then return cacheAndReturn(videoId, r2, cb) end
            resolveAudioCustom(videoId, function(r3)
                if r3 then return cacheAndReturn(videoId, r3, cb) end
                resolveAudioRapidApi(videoId, function(r4)
                    if r4 then return cacheAndReturn(videoId, r4, cb) end
                    resolveAudioConverter(videoId, function(r5)
                        if r5 then return cacheAndReturn(videoId, r5, cb) end
                        resolveAudioFromPage(videoId, function(r6)
                            if r6 then return cacheAndReturn(videoId, r6, cb) end
                            print('[AudioResolve] ALL methods failed for: ' .. videoId)
                            cb({ success = false })
                        end)
                    end)
                end)
            end)
        end)
    end)
end

RPC.Register('codem-hud:music:resolveAudio', function(src, data)
    local videoId = data.videoId
    if not videoId or #videoId ~= 11 then
        return { success = false }
    end

    -- Resolve URL and return
    local p = promise.new()
    resolveAudio(videoId, function(result)
        if not result or not result.success or not result.url then
            p:resolve(result or { success = false })
            return
        end
        p:resolve({ success = true, url = result.url, format = result.format })
    end)
    return Citizen.Await(p)
end)

print('[VehicleMusic] Server module loaded')
