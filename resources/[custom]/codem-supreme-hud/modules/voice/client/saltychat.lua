if Config.VoiceSystem ~= 'saltychat' then return end
if GetResourceState('saltychat') ~= 'started' then return end

local currentRange = 0
local currentMuted = false

-- Global talking state for Voice Assistant
VoiceTalkingState = false
local voiceRanges = { [3.0] = 1, [8.0] = 2, [15.0] = 3, [32.0] = 3 }

-- SaltyChat events
AddEventHandler('SaltyChat_VoiceRangeChanged', function(range)
    local rangeLevel = voiceRanges[range] or 2
    if rangeLevel == currentRange then return end
    currentRange = rangeLevel
    NuiMessage('updateVoiceRange', { range = rangeLevel })
end)

-- SaltyChat talking event
AddEventHandler('SaltyChat_TalkStateChanged', function(isTalking)
    -- Suppress talking during voice assistant recording
    if VoiceRecording then isTalking = false end
    if isTalking == VoiceTalkingState then return end
    VoiceTalkingState = isTalking
    NuiMessage('updateTalking', { talking = isTalking })
end)

-- SaltyChat muted events
AddEventHandler('SaltyChat_MicStateChanged', function(isMuted)
    if isMuted == currentMuted then return end
    currentMuted = isMuted
    NuiMessage('updateMuted', { muted = isMuted })
end)

AddEventHandler('SaltyChat_PluginStateChanged', function(state)
    -- state: 0 = not connected, 2 = connected
    local muted = state ~= 2
    if muted == currentMuted then return end
    currentMuted = muted
    NuiMessage('updateMuted', { muted = muted })
end)

-- Initialize voice state
CreateThread(function()
    Wait(2000)
    -- Send initial talking state (false) to ensure correct UI state on load
    NuiMessage('updateTalking', { talking = false })
    NuiMessage('updateVoiceRange', { range = currentRange > 0 and currentRange or 2 })
end)
