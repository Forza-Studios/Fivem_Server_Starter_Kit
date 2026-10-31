--[[
    Music Playlists Server Module
    Handles playlist CRUD operations with database via RPC
]]

if not Config.VehicleMusic or not Config.VehicleMusic.Enabled then return end

-- Like spam protection
local LikeCooldowns = {} -- [identifier] = { [playlistId] = lastLikeTime }
local LIKE_COOLDOWN_MS = 1000 -- 1 saniye cooldown

--- Check if player is on cooldown for liking a playlist
---@param identifier string Player identifier
---@param playlistId number Playlist ID
---@return boolean True if on cooldown
local function IsLikeOnCooldown(identifier, playlistId)
    if not LikeCooldowns[identifier] then return false end
    local lastLikeTime = LikeCooldowns[identifier][playlistId]
    if not lastLikeTime then return false end
    return (GetGameTimer() - lastLikeTime) < LIKE_COOLDOWN_MS
end

--- Set like cooldown for player
---@param identifier string Player identifier
---@param playlistId number Playlist ID
local function SetLikeCooldown(identifier, playlistId)
    if not LikeCooldowns[identifier] then
        LikeCooldowns[identifier] = {}
    end
    LikeCooldowns[identifier][playlistId] = GetGameTimer()
end

-- Wait for database to be ready
CreateThread(function()
    WaitForDatabase()
    debugPrint('[Playlists] Server module loaded')
end)

local function GetPlayerIdentifier(src)
    if not Core or not Core.Functions then return nil end
    return Core.Functions.GetIdentifier(src)
end

--- Verify playlist ownership (centralized helper to avoid duplicate queries)
---@param playlistId number Playlist ID
---@param identifier string Player identifier
---@return boolean True if player owns the playlist
local function VerifyPlaylistOwnership(playlistId, identifier)
    if not playlistId or not identifier then return false end
    local existing = MySQL.single.await([[
        SELECT id FROM codem_hud_music_playlists
        WHERE id = ? AND identifier = ?
    ]], { playlistId, identifier })
    return existing ~= nil
end

local function FormatPlaylist(row, identifier)
    -- Get owner name: use stored value, fallback to framework lookup
    local ownerName = row.owner_name
    if not ownerName or ownerName == '' or ownerName == 'Unknown' then
        if Core and Core.Functions and Core.Functions.GetName then
            ownerName = Core.Functions.GetName(nil, row.identifier)
        else
            ownerName = 'Unknown'
        end
    end

    return {
        id = row.id,
        identifier = row.identifier,
        name = row.name,
        coverUrl = row.cover_url,
        likes = row.likes or 0,
        songs = {},
        isOwner = row.identifier == identifier,
        ownerName = ownerName
    }
end

local function FormatSong(row)
    return {
        id = row.id,
        playlistId = row.playlist_id,
        url = row.url,
        title = row.title,
        artist = row.artist,
        thumbnail = row.thumbnail,
        duration = row.duration or 0,
        position = row.position or 0
    }
end

--- Get playlists with songs using JOIN (fixes N+1 query problem)
--- Returns playlists with their songs in a single query
---@param whereClause string SQL WHERE clause (e.g., "identifier = ?")
---@param params table Query parameters
---@param orderBy string SQL ORDER BY clause
---@param limit number Max playlists to return
---@param offset number Pagination offset
---@param identifier string|nil Current player identifier (for isOwner check)
---@return table playlists, boolean hasMore
local function GetPlaylistsWithSongs(whereClause, params, orderBy, limit, offset, identifier)
    -- Get playlists with pagination
    local playlistQuery = string.format([[
        SELECT * FROM codem_hud_music_playlists
        WHERE %s
        ORDER BY %s
        LIMIT ? OFFSET ?
    ]], whereClause, orderBy)

    -- Add limit+1 and offset to params
    local queryParams = {}
    for _, p in ipairs(params) do queryParams[#queryParams + 1] = p end
    queryParams[#queryParams + 1] = limit + 1
    queryParams[#queryParams + 1] = offset
    local playlistRows = MySQL.query.await(playlistQuery, queryParams)

    if not playlistRows or #playlistRows == 0 then
        return {}, false
    end

    -- Check if there are more results
    local hasMore = #playlistRows > limit
    if hasMore then
        table.remove(playlistRows) -- Remove extra row
    end

    -- Collect playlist IDs for batch song query
    local playlistIds = {}
    local playlistMap = {}
    for _, row in ipairs(playlistRows) do
        playlistIds[#playlistIds + 1] = row.id
        playlistMap[row.id] = FormatPlaylist(row, identifier)
    end

    -- Get all songs for these playlists in ONE query (fixes N+1)
    if #playlistIds > 0 then
        local placeholders = string.rep('?,', #playlistIds):sub(1, -2)
        local songRows = MySQL.query.await(string.format([[
            SELECT * FROM codem_hud_music_playlist_songs
            WHERE playlist_id IN (%s)
            ORDER BY playlist_id, position ASC
        ]], placeholders), playlistIds)

        if songRows then
            for _, songRow in ipairs(songRows) do
                local playlist = playlistMap[songRow.playlist_id]
                if playlist then
                    playlist.songs[#playlist.songs + 1] = FormatSong(songRow)
                end
            end
        end
    end

    -- Convert map to array (preserve order)
    local playlists = {}
    for _, row in ipairs(playlistRows) do
        playlists[#playlists + 1] = playlistMap[row.id]
    end

    return playlists, hasMore
end

-- ═══════════════════════════════════════════════════════════════
-- GET MY PLAYLISTS (with pagination)
-- ═══════════════════════════════════════════════════════════════

RPC.Register('codem-hud:playlists:getMyPlaylists', function(src, data)
    local identifier = GetPlayerIdentifier(src)

    if not identifier then
        return { success = false, playlists = {}, hasMore = false }
    end

    local limit = data.limit or 10
    local offset = data.offset or 0

    -- Use optimized helper (fixes N+1 query)
    local playlists, hasMore = GetPlaylistsWithSongs(
        'identifier = ?',
        { identifier },
        'created_at DESC',
        limit,
        offset,
        identifier
    )

    return { success = true, playlists = playlists, hasMore = hasMore }
end)

-- ═══════════════════════════════════════════════════════════════
-- GET ALL PLAYLISTS (with pagination)
-- ═══════════════════════════════════════════════════════════════

RPC.Register('codem-hud:playlists:getAllPlaylists', function(src, data)
    local identifier = GetPlayerIdentifier(src)

    local limit = data.limit or 10
    local offset = data.offset or 0

    -- Use optimized helper (fixes N+1 query)
    local playlists, hasMore = GetPlaylistsWithSongs(
        '1=1',  -- No filter for all playlists
        {},
        'likes DESC, created_at DESC',
        limit,
        offset,
        identifier
    )

    -- Get user's likes in one query
    if identifier and #playlists > 0 then
        local likeRows = MySQL.query.await([[
            SELECT playlist_id FROM codem_hud_music_playlist_likes
            WHERE identifier = ?
        ]], { identifier })

        local likedIds = {}
        if likeRows then
            for _, row in ipairs(likeRows) do
                likedIds[row.playlist_id] = true
            end
        end

        -- Add isLiked to playlists
        for _, playlist in ipairs(playlists) do
            playlist.isLiked = likedIds[playlist.id] or false
        end
    end

    return { success = true, playlists = playlists, hasMore = hasMore }
end)

-- ═══════════════════════════════════════════════════════════════
-- CREATE PLAYLIST
-- ═══════════════════════════════════════════════════════════════

RPC.Register('codem-hud:playlists:createPlaylist', function(src, data)
    local identifier = GetPlayerIdentifier(src)

    if not identifier then
        return { success = false }
    end

    -- Validate data
    if not data.name or type(data.name) ~= 'string' or #data.name < 1 then
        return { success = false }
    end

    local name = data.name:sub(1, 100) -- Max 100 chars
    local coverUrl = data.coverUrl and data.coverUrl:sub(1, 2000) or nil

    -- Get owner name from framework
    local ownerName = 'Unknown'
    if Core and Core.Functions and Core.Functions.GetName then
        ownerName = Core.Functions.GetName(src, identifier)
    end

    -- Insert playlist
    local insertId = MySQL.insert.await([[
        INSERT INTO codem_hud_music_playlists (identifier, owner_name, name, cover_url, likes)
        VALUES (?, ?, ?, ?, 0)
    ]], { identifier, ownerName, name, coverUrl })

    if not insertId then
        return { success = false }
    end

    local playlist = {
        id = insertId,
        identifier = identifier,
        name = name,
        coverUrl = coverUrl,
        likes = 0,
        songs = {},
        isOwner = true,
        ownerName = ownerName
    }

    return { success = true, playlist = playlist }
end)

-- ═══════════════════════════════════════════════════════════════
-- UPDATE PLAYLIST
-- ═══════════════════════════════════════════════════════════════

RPC.Register('codem-hud:playlists:updatePlaylist', function(src, data)
    local identifier = GetPlayerIdentifier(src)

    if not identifier or not data.playlistId then
        return { success = false }
    end

    -- Verify ownership using helper
    if not VerifyPlaylistOwnership(data.playlistId, identifier) then
        return { success = false }
    end

    -- Build update query
    local updates = {}
    local params = {}

    if data.name ~= nil then
        updates[#updates + 1] = 'name = ?'
        params[#params + 1] = tostring(data.name):sub(1, 100)
    end

    if data.coverUrl ~= nil then
        updates[#updates + 1] = 'cover_url = ?'
        params[#params + 1] = data.coverUrl and tostring(data.coverUrl):sub(1, 2000) or nil
    end

    if #updates == 0 then
        return { success = true }
    end

    params[#params + 1] = data.playlistId

    MySQL.update.await(
        'UPDATE codem_hud_music_playlists SET ' .. table.concat(updates, ', ') .. ' WHERE id = ?',
        params
    )

    return { success = true }
end)

-- ═══════════════════════════════════════════════════════════════
-- DELETE PLAYLIST
-- ═══════════════════════════════════════════════════════════════

RPC.Register('codem-hud:playlists:deletePlaylist', function(src, data)
    local identifier = GetPlayerIdentifier(src)

    if not identifier or not data.playlistId then
        return { success = false }
    end
    
    -- Verify ownership using helper
    if not VerifyPlaylistOwnership(data.playlistId, identifier) then
        return { success = false }
    end

    -- Delete songs from playlist first
    MySQL.update.await([[
        DELETE FROM codem_hud_music_playlist_songs
        WHERE playlist_id = ?
    ]], { data.playlistId })

    -- Delete likes
    MySQL.update.await([[
        DELETE FROM codem_hud_music_playlist_likes
        WHERE playlist_id = ?
    ]], { data.playlistId })

    -- Delete the playlist
    local affected = MySQL.update.await([[
        DELETE FROM codem_hud_music_playlists
        WHERE id = ? AND identifier = ?
    ]], { data.playlistId, identifier })

    return { success = affected > 0 }
end)

-- ═══════════════════════════════════════════════════════════════
-- ADD SONG TO PLAYLIST
-- ═══════════════════════════════════════════════════════════════

RPC.Register('codem-hud:playlists:addSongToPlaylist', function(src, data)
    local identifier = GetPlayerIdentifier(src)

    if not identifier or not data.playlistId then
        return { success = false }
    end

    -- Verify ownership using helper
    if not VerifyPlaylistOwnership(data.playlistId, identifier) then
        return { success = false }
    end

    -- Validate song data
    if not data.url or not data.title then
        return { success = false }
    end

    -- Get max position
    local maxPos = MySQL.scalar.await([[
        SELECT COALESCE(MAX(position), -1) FROM codem_hud_music_playlist_songs
        WHERE playlist_id = ?
    ]], { data.playlistId })

    local position = (maxPos or -1) + 1

    -- Insert song
    local insertId = MySQL.insert.await([[
        INSERT INTO codem_hud_music_playlist_songs (playlist_id, url, title, artist, thumbnail, duration, position)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.playlistId,
        tostring(data.url):sub(1, 2000),
        tostring(data.title):sub(1, 255),
        data.artist and tostring(data.artist):sub(1, 255) or 'Unknown',
        data.thumbnail and tostring(data.thumbnail):sub(1, 2000) or nil,
        data.duration or 0,
        position
    })

    if not insertId then
        return { success = false }
    end

    local song = {
        id = insertId,
        playlistId = data.playlistId,
        url = data.url,
        title = data.title,
        artist = data.artist or 'Unknown',
        thumbnail = data.thumbnail,
        duration = data.duration or 0,
        position = position
    }

    return { success = true, song = song }
end)

-- ═══════════════════════════════════════════════════════════════
-- REMOVE SONG FROM PLAYLIST
-- ═══════════════════════════════════════════════════════════════

RPC.Register('codem-hud:playlists:removeSongFromPlaylist', function(src, data)
    local identifier = GetPlayerIdentifier(src)

    if not identifier or not data.playlistId or not data.songId then
        return { success = false }
    end

    -- Verify ownership via join
    local existing = MySQL.single.await([[
        SELECT s.id FROM codem_hud_music_playlist_songs s
        JOIN codem_hud_music_playlists p ON p.id = s.playlist_id
        WHERE s.id = ? AND s.playlist_id = ? AND p.identifier = ?
    ]], { data.songId, data.playlistId, identifier })

    if not existing then
        return { success = false }
    end

    -- Delete song
    MySQL.update.await([[
        DELETE FROM codem_hud_music_playlist_songs
        WHERE id = ?
    ]], { data.songId })

    -- Reorder positions using a subquery approach
    local songs = MySQL.query.await([[
        SELECT id FROM codem_hud_music_playlist_songs
        WHERE playlist_id = ?
        ORDER BY position ASC
    ]], { data.playlistId })

    if songs and #songs > 0 then
        for i, song in ipairs(songs) do
            MySQL.update.await([[
                UPDATE codem_hud_music_playlist_songs
                SET position = ?
                WHERE id = ?
            ]], { i - 1, song.id })
        end
    end

    return { success = true }
end)

-- ═══════════════════════════════════════════════════════════════
-- TOGGLE PLAYLIST LIKE
-- ═══════════════════════════════════════════════════════════════

RPC.Register('codem-hud:playlists:togglePlaylistLike', function(src, data)
    local identifier = GetPlayerIdentifier(src)

    if not identifier or not data.playlistId then
        return { success = false }
    end

    -- Spam protection - check cooldown
    if IsLikeOnCooldown(identifier, data.playlistId) then
        debugPrint('[Playlists] Like cooldown active for ' .. identifier)
        return { success = false, error = 'cooldown' }
    end
    SetLikeCooldown(identifier, data.playlistId)

    -- Check if already liked
    local existing = MySQL.single.await([[
        SELECT playlist_id FROM codem_hud_music_playlist_likes
        WHERE playlist_id = ? AND identifier = ?
    ]], { data.playlistId, identifier })

    local isLiked = false
    local likes = 0

    if existing then
        -- Unlike
        MySQL.update.await([[
            DELETE FROM codem_hud_music_playlist_likes
            WHERE playlist_id = ? AND identifier = ?
        ]], { data.playlistId, identifier })

        MySQL.update.await([[
            UPDATE codem_hud_music_playlists
            SET likes = GREATEST(0, likes - 1)
            WHERE id = ?
        ]], { data.playlistId })

        isLiked = false
    else
        -- Like
        MySQL.insert.await([[
            INSERT INTO codem_hud_music_playlist_likes (playlist_id, identifier)
            VALUES (?, ?)
        ]], { data.playlistId, identifier })

        MySQL.update.await([[
            UPDATE codem_hud_music_playlists
            SET likes = likes + 1
            WHERE id = ?
        ]], { data.playlistId })

        isLiked = true
    end

    -- Get updated like count
    likes = MySQL.scalar.await([[
        SELECT likes FROM codem_hud_music_playlists WHERE id = ?
    ]], { data.playlistId }) or 0

    return { success = true, isLiked = isLiked, likes = likes }
end)
