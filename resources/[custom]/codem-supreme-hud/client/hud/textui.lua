--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║                         TEXT UI                               ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  Modern TextUI system with blur effect                        ║
    ║  Variants: light, dark, solid                                 ║
    ║  Positions: left, center, right                               ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

local isTextUIVisible = false
local hideTimerToken = 0

---Show TextUI with customizable options
---@param text string The text to display
---@param options? table Optional settings: key, variant ('light'|'dark'|'solid'), position ('left'|'center'|'right'), duration (ms)
local function ShowTextUI(text, options)
    options = options or {}

    hideTimerToken = hideTimerToken + 1

    NuiMessage('TEXTUI_SHOW', {
        text = text,
        key = options.key or nil,
        variant = options.variant or 'light',
        position = options.position or 'right'
    })

    isTextUIVisible = true

    if options.duration and options.duration > 0 then
        local token = hideTimerToken
        SetTimeout(options.duration, function()
            if hideTimerToken == token and isTextUIVisible then
                HideTextUI()
            end
        end)
    end
end

---Hide the TextUI
local function HideTextUI()
    if not isTextUIVisible then return end

    hideTimerToken = hideTimerToken + 1

    NuiMessage('TEXTUI_HIDE')
    isTextUIVisible = false
end

---Check if TextUI is currently visible
---@return boolean
local function IsTextUIVisible()
    return isTextUIVisible
end

-- ═══════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════

exports('ShowTextUI', ShowTextUI)
exports('HideTextUI', HideTextUI)
exports('IsTextUIVisible', IsTextUIVisible)

-- QB-Core compatible exports (qb-core style naming)
exports('DrawText', function(text, position)
    -- QB-Core pozisyon formatı: 'left', 'right' veya table {x, y}
    local pos = 'right'
    if type(position) == 'string' then
        pos = position
    end

    ShowTextUI(text, { position = pos })
end)

exports('HideText', HideTextUI)
exports('KeyPressed', function()
    return false -- Compatibility stub
end)

-- ═══════════════════════════════════════════════════════════════
-- EVENTS (for other resources)
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('codem-hud:client:ShowTextUI', function(text, options)
    ShowTextUI(text, options)
end)

RegisterNetEvent('codem-hud:client:HideTextUI', function()
    HideTextUI()
end)

-- QB-DrawText compatibility events
RegisterNetEvent('qb-core:client:DrawText', function(text, position)
    local pos = 'right'
    if type(position) == 'string' then
        pos = position
    end
    ShowTextUI(text, { position = pos })
end)

RegisterNetEvent('qb-core:client:HideText', function()
    HideTextUI()
end)

-- ox_lib compatibility events
RegisterNetEvent('ox_lib:showTextUI', function(text, options)
    local opts = {
        position = options and options.position or 'right',
        variant = options and options.icon and 'dark' or 'light'
    }
    ShowTextUI(text, opts)
end)

RegisterNetEvent('ox_lib:hideTextUI', function()
    HideTextUI()
end)

-- Global functions (for internal use)
_G.ShowTextUI = ShowTextUI
_G.HideTextUI = HideTextUI
_G.IsTextUIVisible = IsTextUIVisible
