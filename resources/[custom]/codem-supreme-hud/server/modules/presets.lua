local function GetPlayerIdentifier(src)
    if not Core or not Core.Functions then return nil end
    return Core.Functions.GetIdentifier(src)
end

-- Get all presets for a player
RPC.Register('codem-hud:presets:getAll', function(src)
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return {} end

    local results = MySQL.Sync.fetchAll([[
        SELECT id, name, settings, source, created_at
        FROM codem_hud_presets
        WHERE identifier = ?
        ORDER BY created_at ASC
    ]], { identifier })

    if not results then return {} end

    local presets = {}
    for _, row in ipairs(results) do
        presets[#presets + 1] = {
            id = row.id,
            name = row.name,
            settings = json.decode(row.settings),
            source = row.source or 'local',
            createdAt = row.created_at
        }
    end

    return presets
end)

-- Save a new preset
RPC.Register('codem-hud:presets:save', function(src, data)
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return { success = false } end
    if not data or not data.id or not data.name or not data.settings then
        return { success = false }
    end

    MySQL.Async.execute([[
        INSERT INTO codem_hud_presets (id, identifier, name, settings, source)
        VALUES (?, ?, ?, ?, ?)
    ]], { data.id, identifier, data.name, json.encode(data.settings), data.source or 'local' })

    return { success = true }
end)

-- Delete a preset
RPC.Register('codem-hud:presets:delete', function(src, presetId)
    local identifier = GetPlayerIdentifier(src)
    if not identifier or not presetId then return { success = false } end

    MySQL.Async.execute([[
        DELETE FROM codem_hud_presets
        WHERE id = ? AND identifier = ?
    ]], { presetId, identifier })

    return { success = true }
end)

debugPrint('[Presets] Server module loaded')
