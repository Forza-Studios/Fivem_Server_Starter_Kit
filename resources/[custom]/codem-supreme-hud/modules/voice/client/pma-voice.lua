if Config.VoiceSystem ~= 'pma-voice' then return end
if GetResourceState('pma-voice') ~= 'started' then return end

local currentRange = 2

-- Voice range event from pma-voice
RegisterNetEvent('pma-voice:setTalkingMode')
AddEventHandler('pma-voice:setTalkingMode', function(voiceMode)
    if voiceMode == currentRange then return end
    currentRange = voiceMode
    NuiMessage('updateVoiceRange', { range = voiceMode })
end)

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
        Wait(200)
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

-- Get initial range from pma-voice
CreateThread(function()
    Wait(2000)
    local proximity = LocalPlayer.state.proximity
    if proximity then
        local index = type(proximity) == 'table' and proximity.index or proximity
        if index then
            currentRange = index
            NuiMessage('updateVoiceRange', { range = index })
        end
    else
        -- Send default range if no proximity state yet
        NuiMessage('updateVoiceRange', { range = currentRange })
    end

    -- Send initial talking state (false) to ensure correct UI state on load
    NuiMessage('updateTalking', { talking = false })
end)
