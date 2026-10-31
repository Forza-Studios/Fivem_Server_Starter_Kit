local MESSAGE_COOLDOWN_MS = 750

-- The server owns the history: clients send one message and the server stamps
-- the sender, so nobody can rewrite or forge earlier messages.
local history = {} ---@type table[]
local lastMessageAt = {} ---@type table<number, number>

---@param source number
function SyncStaffChatForPlayer(source)
    if not IsAuthorized(source, 'page.staffchat') then return end
    TriggerClientEvent('butter_admin:client:syncStaffChat', source, history)
end

RegisterNetEvent('butter_admin:server:sendStaffMessage', function(message)
    local source = source
    if not IsAuthorized(source, 'page.staffchat') then return end

    message = SanitizeString(message, 512)
    if not message then return end

    local now = GetGameTimer()
    if lastMessageAt[source] and now - lastMessageAt[source] < MESSAGE_COOLDOWN_MS then return end
    lastMessageAt[source] = now

    local entry = { Message = message, Time = os.date('%H:%M'), Sender = GetDisplayName(source) }
    history[#history + 1] = entry
    while #history > Config.StaffChat.MaxHistory do table.remove(history, 1) end

    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        if IsAuthorized(target, 'page.staffchat') then
            TriggerClientEvent('butter_admin:client:staffChatMessage', target, entry)
        end
    end
end)

AddEventHandler('playerDropped', function()
    lastMessageAt[source] = nil
end)
