--[[
    Music Playlists Client Module
    Handles NUI callbacks and communicates with server for database operations
]]

if not Config.VehicleMusic or not Config.VehicleMusic.Enabled then return end

-- ═══════════════════════════════════════════════════════════════
-- GET MY PLAYLISTS
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('music:getMyPlaylists', function(data, cb)
    local result = RPC.execute('codem-hud:playlists:getMyPlaylists', {
        limit = data.limit or 10,
        offset = data.offset or 0
    })

    if result then
        cb(result)
    else
        cb({ success = false, playlists = {}, hasMore = false })
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- GET ALL PLAYLISTS
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('music:getAllPlaylists', function(data, cb)
    local result = RPC.execute('codem-hud:playlists:getAllPlaylists', {
        limit = data.limit or 10,
        offset = data.offset or 0
    })

    if result then
        cb(result)
    else
        cb({ success = false, playlists = {}, hasMore = false })
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- CREATE PLAYLIST
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('music:createPlaylist', function(data, cb)
    if not data.name or type(data.name) ~= 'string' or #data.name < 1 then
        return cb({ success = false })
    end

    local result = RPC.execute('codem-hud:playlists:createPlaylist', {
        name = data.name,
        coverUrl = data.coverUrl
    })

    if result then
        cb(result)
    else
        cb({ success = false })
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- UPDATE PLAYLIST
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('music:updatePlaylist', function(data, cb)
    if not data.playlistId then
        return cb({ success = false })
    end

    local result = RPC.execute('codem-hud:playlists:updatePlaylist', {
        playlistId = data.playlistId,
        name = data.name,
        coverUrl = data.coverUrl
    })

    if result then
        cb(result)
    else
        cb({ success = false })
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- DELETE PLAYLIST
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('music:deletePlaylist', function(data, cb)
    if not data.playlistId then
        return cb({ success = false })
    end

    local result = RPC.execute('codem-hud:playlists:deletePlaylist', {
        playlistId = data.playlistId
    })

    if result then
        cb(result)
    else
        cb({ success = false })
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ADD SONG TO PLAYLIST
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('music:addSongToPlaylist', function(data, cb)
    if not data.playlistId or not data.url or not data.title then
        return cb({ success = false })
    end

    local result = RPC.execute('codem-hud:playlists:addSongToPlaylist', {
        playlistId = data.playlistId,
        url = data.url,
        title = data.title,
        artist = data.artist,
        thumbnail = data.thumbnail,
        duration = data.duration
    })

    if result then
        cb(result)
    else
        cb({ success = false })
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- REMOVE SONG FROM PLAYLIST
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('music:removeSongFromPlaylist', function(data, cb)
    if not data.playlistId or not data.songId then
        return cb({ success = false })
    end

    local result = RPC.execute('codem-hud:playlists:removeSongFromPlaylist', {
        playlistId = data.playlistId,
        songId = data.songId
    })

    if result then
        cb(result)
    else
        cb({ success = false })
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- TOGGLE PLAYLIST LIKE
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('music:togglePlaylistLike', function(data, cb)
    if not data.playlistId then
        return cb({ success = false })
    end

    local result = RPC.execute('codem-hud:playlists:togglePlaylistLike', {
        playlistId = data.playlistId
    })

    if result then
        cb(result)
    else
        cb({ success = false })
    end
end)

debugPrint('[Playlists] Client module loaded')
