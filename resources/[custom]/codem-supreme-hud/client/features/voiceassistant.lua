if not Config.VoiceAssistant or not Config.VoiceAssistant.Enabled then return end

VoicePanelOpen = false
VoiceRecording = false
local Lang = Config.VoiceAssistant.Lang or 'en'
local Commands = Config.VoiceAssistant.Commands[Lang] or {}

-- Parse commands (supports single trigger string or table of triggers)
local TriggerMap = {}
local ParsedCommands = {}

for i, cmd in ipairs(Commands) do
    local triggers = cmd[1]
    local message = cmd[2] or ''
    local action = cmd[3]

    if type(triggers) == 'string' then
        triggers = { triggers }
    end

    local parsed = {
        id = 'cmd_' .. i,
        trigger = triggers[1],
        triggers = triggers,
        message = message,
        action = action
    }

    ParsedCommands[#ParsedCommands + 1] = parsed
    for _, t in ipairs(triggers) do
        TriggerMap[t:lower()] = parsed
    end
end

-- Execute action (supports function or string)
local function ExecuteAction(action)
    if not action then return end

    if type(action) == 'function' then
        action()
    elseif type(action) == 'string' then
        if action:find(':') then
            TriggerEvent(action)
        else
            ExecuteCommand(action)
        end
    end
end

-- Find command
local function FindCommand(text)
    if not text or text == '' then return nil end
    text = text:lower():gsub("^%s*(.-)%s*$", "%1")

    -- Exact match
    if TriggerMap[text] then
        return TriggerMap[text]
    end

    -- Partial match
    for trigger, cmd in pairs(TriggerMap) do
        if text:find(trigger, 1, true) or trigger:find(text, 1, true) then
            return cmd
        end
    end

    return nil
end

-- UI commands list
local function GetUICommands()
    local list = {}
    for _, cmd in ipairs(ParsedCommands) do
        list[#list + 1] = {
            id = cmd.id,
            name = cmd.trigger,
            message = cmd.message
        }
    end
    return list
end

-- Fix any leftover state from previous NetworkSetVoiceActive(false) calls
CreateThread(function()
    Wait(2000)
    NetworkSetVoiceActive(true)
end)

-- Suppress voice chat while voice assistant is open
-- Uses proximity=0 to prevent audio reaching others + VoiceRecording flag for HUD indicator
local function SuppressVoice()
    VoiceRecording = true
    if MumbleIsConnected() then
        MumbleSetTalkerProximity(0.0)
    end
end

local function RestoreVoice()
    VoiceRecording = false
    NetworkSetVoiceActive(true)
    if MumbleIsConnected() then
        if Config.VoiceSystem == 'pma-voice' then
            local prox = LocalPlayer.state.proximity
            local dist = prox and (type(prox) == 'table' and prox.distance or 10.0) or 10.0
            MumbleSetTalkerProximity(dist + 0.0)
        elseif Config.VoiceSystem == 'mumble-voip' then
            local dist = VoiceCurrentDistance or 15.0
            MumbleSetTalkerProximity(dist + 0.0)
        else
            MumbleSetTalkerProximity(10.0)
        end
    end
end

RegisterNUICallback('voice:opened', function(_, cb)
    VoicePanelOpen = true
    SuppressVoice()
    NuiMessage('voice:setCommands', { commands = GetUICommands() })
    cb('ok')
end)

RegisterNUICallback('voice:closed', function(_, cb)
    VoicePanelOpen = false
    RestoreVoice()
    cb('ok')
end)

RegisterNUICallback('voice:getConfig', function(_, cb)
    local config = RPC.execute('codem-hud:getVoiceConfig')
    cb({ token = config and config.token or '' })
end)

RegisterNUICallback('voice:executeCommand', function(data, cb)
    if not data.command then return cb({ success = false }) end

    for _, cmd in ipairs(ParsedCommands) do
        if cmd.id == data.command then
            ExecuteAction(cmd.action)
            cb({ success = true, message = cmd.message })
            return
        end
    end

    cb({ success = false })
end)

RegisterNUICallback('voice:recordingStarted', function(_, cb)
    -- VoiceRecording already true from voice:opened, just ensure it stays
    SuppressVoice()
    cb('ok')
end)

RegisterNUICallback('voice:recordingStopped', function(_, cb)
    -- Don't restore here - panel is still open, restore happens on voice:closed
    -- Keep VoiceRecording = true while panel is open
    cb('ok')
end)

RegisterNUICallback('voice:processText', function(data, cb)
    if not data.text then return cb({ success = false }) end

    local cmd = FindCommand(data.text)
    if cmd then
        ExecuteAction(cmd.action)
        cb({ success = true, command = cmd.id, message = cmd.message })
        return
    end

    cb({ success = false })
end)

local function ToggleVoiceAssistant()
    -- Only allow opening when in vehicle (cache.inVehicle is set by baseevents or fallback polling)
    if not cache.inVehicle then return end

    VoicePanelOpen = not VoicePanelOpen

    if VoicePanelOpen then
        SuppressVoice()
    else
        RestoreVoice()
    end

    -- Rectangular HUD için
    NuiMessage(VoicePanelOpen and 'voiceassistant:show' or 'voiceassistant:hide')
    -- Circular HUD için
    NuiMessage('toggleVoiceAssistant')
end

RegisterCommand('voiceassistant_toggle', ToggleVoiceAssistant, false)
RegisterKeyMapping('voiceassistant_toggle', 'Toggle Voice Assistant', 'keyboard', 'J')
