if Config.VoiceSystem ~= 'toko-voip' then return end
if GetResourceState('tokovoip_script') ~= 'started' then return end

local currentRange = 0
local currentMuted = false

-- Global talking state for Voice Assistant
VoiceTalkingState = false

-- TokoVOIP events
AddEventHandler('tokovoip:setRange', function(range)
    if range == currentRange then return end
    currentRange = range
    NuiMessage('updateVoiceRange', { range = range })
end)

-- TokoVOIP talking event
AddEventHandler('tokovoip:setTalking', function(isTalking)
    -- Suppress talking during voice assistant recording
    if VoiceRecording then isTalking = false end
    if isTalking == VoiceTalkingState then return end
    VoiceTalkingState = isTalking
    NuiMessage('updateTalking', { talking = isTalking })
end)

-- TokoVOIP muted event
AddEventHandler('tokovoip:setMute', function(isMuted)
    if isMuted == currentMuted then return end
    currentMuted = isMuted
    NuiMessage('updateMuted', { muted = isMuted })
end)

-- Check connection state
local function IsConnected()
    local success, result = pcall(function()
        return exports['tokovoip_script']:isConnected()
    end)
    return success and result or false
end

-- Muted state detection based on connection
local lastConnected = false
CreateThread(function()
    while true do
        local connected = IsConnected()
        if connected ~= lastConnected then
            lastConnected = connected
            if not connected and not currentMuted then
                currentMuted = true
                NuiMessage('updateMuted', { muted = true })
            end
        end
        Wait(Utils.W(2000))
    end
end)

-- Initialize voice state
CreateThread(function()
    Wait(2000)
    -- Send initial talking state (false) to ensure correct UI state on load
    NuiMessage('updateTalking', { talking = false })
    NuiMessage('updateVoiceRange', { range = currentRange > 0 and currentRange or 2 })
end)
