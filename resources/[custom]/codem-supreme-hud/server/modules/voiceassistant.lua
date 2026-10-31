--[[
    Voice Assistant Server Module
    Provides secure token for Wit.AI integration
]]

if not Config.VoiceAssistant or not Config.VoiceAssistant.Enabled then return end

-- XOR encode for token obfuscation (prevents plain-text token in client)
local function encodeToken(token)
    if not token or token == '' then return '' end
    local key = 0x5A
    local encoded = {}
    for i = 1, #token do
        local byte = string.byte(token, i)
        encoded[#encoded + 1] = string.format('%02x', (byte ~ key) & 0xFF)
    end
    return table.concat(encoded)
end

RPC.Register('codem-hud:getVoiceConfig', function()
    if not ServerConfig or not ServerConfig.WitAI or not ServerConfig.WitAI.Token then
        return { token = '' }
    end
    return { token = encodeToken(ServerConfig.WitAI.Token) }
end)

debugPrint('[VoiceAssistant] Server module loaded')
