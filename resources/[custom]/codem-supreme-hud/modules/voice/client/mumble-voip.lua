if Config.VoiceSystem ~= 'mumble-voip' then return end

local currentRange = 2
local currentRangeIndex = 2
local voiceRanges = {
    { distance = 5.0, label = 'Whisper', level = 1 },
    { distance = 15.0, label = 'Normal', level = 2 },
    { distance = 30.0, label = 'Shout', level = 3 },
}

-- Voice range command
RegisterCommand('voicerange', function()
    currentRangeIndex = currentRangeIndex % #voiceRanges + 1
    local range = voiceRanges[currentRangeIndex]
    MumbleSetTalkerProximity(range.distance)
    VoiceCurrentDistance = range.distance
    if range.level ~= currentRange then
        currentRange = range.level
        NuiMessage('updateVoiceRange', { range = range.level })
    end
end, false)

-- Track current distance for voice assistant restore
VoiceCurrentDistance = 15.0

-- Talking detection (mHud style - truthy check)
local checkTalkStatus = false
CreateThread(function()
    while true do
        local isTalking = MumbleIsPlayerTalking(PlayerId())
        -- Suppress talking during voice assistant recording
        if VoiceRecording then isTalking = false end
        if isTalking and isTalking ~= 0 then
            if not checkTalkStatus then
                checkTalkStatus = true
                NuiMessage('updateTalking', { talking = true })
            end
        else
            if checkTalkStatus then
                checkTalkStatus = false
                NuiMessage('updateTalking', { talking = false })
            end
        end
        Wait(100)
    end
end)

-- Muted state detection
local micIsOn = true
local firstCheck = true
CreateThread(function()
    while true do
        if not MumbleIsConnected() then
            if micIsOn or firstCheck then
                micIsOn = false
                firstCheck = false
                NuiMessage('updateMuted', { muted = true })
            end
        else
            if not micIsOn or firstCheck then
                micIsOn = true
                firstCheck = false
                NuiMessage('updateMuted', { muted = false })
            end
        end
        Wait(Utils.W(2000))
    end
end)

-- Initialize range and talking state
CreateThread(function()
    Wait(2000)
    NuiMessage('updateVoiceRange', { range = currentRangeIndex })
    -- Send initial talking state (false) to ensure correct UI state on load
    NuiMessage('updateTalking', { talking = false })
end)
