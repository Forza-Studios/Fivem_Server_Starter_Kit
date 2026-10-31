local settingsOpen = false

-- 返回设置菜单是否打开
function IsSettingsOpen()
    return settingsOpen
end

-- 打开设置菜单
function OpenSettingsMenu()
    if not IsPlayerLoaded() then
        return
    end
    if settingsOpen then
        return
    end
    if CloseNuiFocusIfOpen then
        CloseNuiFocusIfOpen()
    end
    settingsOpen = true
    SetNuiFocus(true, true)
    SendPlayerInfo()
    NuiMessage("OPEN_SETTINGS")
    NuiMessage("setVisible", { visible = false })
    CaptureMugshot()
end

-- 关闭设置菜单
function CloseSettingsMenu()
    if not settingsOpen then
        return
    end
    settingsOpen = false
    SetNuiFocus(false, false)
    NuiMessage("CLOSE_SETTINGS")
    NuiMessage("setVisible", { visible = true })
end

-- 注册设置菜单事件
if Config.Settings then
    if Config.Settings.Event then
        RegisterNetEvent(Config.Settings.Event, OpenSettingsMenu)
    end
end

-- NUI回调：关闭设置
RegisterNUICallback("CLOSE_SETTINGS", function(data, cb)
    CloseSettingsMenu()
    cb("ok")
end)

-- 注册设置命令
if Config.Settings then
    if Config.Settings.Command then
        RegisterCommand(Config.Settings.Command, function()
            OpenSettingsMenu()
        end, false)
    end
end

-- 注册设置快捷键
if Config.Settings then
    if Config.Settings.Keybind then
        RegisterCommand("codem_hud_settings", function()
            OpenSettingsMenu()
        end, false)
        local keybindDesc = Config.Settings.KeybindDescription
        if not keybindDesc then
            keybindDesc = "Open HUD Settings"
        end
        RegisterKeyMapping("codem_hud_settings", keybindDesc, "keyboard", Config.Settings.Keybind)
    end
end

-- NUI回调：设置语言
RegisterNUICallback("SET_LANGUAGE", function(data, cb)
    local language = data.language
    if not language then
        language = "en"
    end
    SetLocale(language)
    cb("ok")
end)

-- NUI回调：获取所有预设
RegisterNUICallback("presets:getAll", function(data, cb)
    local result = RPC.execute("codem-hud:presets:getAll")
    cb(result or {})
end)

-- NUI回调：保存预设
RegisterNUICallback("presets:save", function(data, cb)
    local result = RPC.execute("codem-hud:presets:save", data)
    if not result then
        result = { success = false }
    end
    cb(result)
end)

-- NUI回调：删除预设
RegisterNUICallback("presets:delete", function(data, cb)
    local result = RPC.execute("codem-hud:presets:delete", data.id)
    if not result then
        result = { success = false }
    end
    cb(result)
end)

-- NUI回调：获取通知设置
RegisterNUICallback("GET_NOTIFICATION_SETTINGS", function(data, cb)
    local state = GetResourceState("codem-supreme-notification")
    if state ~= "started" then
        cb({ error = true })
        return
    end
    local result = exports["codem-supreme-notification"]:GetSettings()
    cb(result or {})
end)

-- NUI回调：设置通知设置
RegisterNUICallback("SET_NOTIFICATION_SETTINGS", function(data, cb)
    local state = GetResourceState("codem-supreme-notification")
    if state ~= "started" then
        cb({ error = true })
        return
    end
    exports["codem-supreme-notification"]:UpdateSettings(data)
    cb("ok")
end)

-- NUI回调：获取径向菜单设置
RegisterNUICallback("GET_RADIALMENU_SETTINGS", function(data, cb)
    local state = GetResourceState("codem-supreme-radialmenu")
    if state ~= "started" then
        cb({ error = true })
        return
    end
    local result = exports["codem-supreme-radialmenu"]:GetSettings()
    cb(result or {})
end)

-- NUI回调：设置径向菜单设置
RegisterNUICallback("SET_RADIALMENU_SETTINGS", function(data, cb)
    local state = GetResourceState("codem-supreme-radialmenu")
    if state ~= "started" then
        cb({ error = true })
        return
    end
    exports["codem-supreme-radialmenu"]:UpdateSettings(data)
    cb("ok")
end)

-- NUI回调：获取径向菜单命令
RegisterNUICallback("GET_RADIALMENU_COMMANDS", function(data, cb)
    local state = GetResourceState("codem-supreme-radialmenu")
    if state ~= "started" then
        cb({ commands = {}, defaultCommands = {}, commandMenuEnabled = false })
        return
    end
    local customCommands = exports["codem-supreme-radialmenu"]:GetCustomCommands()
    local defaultCommands = exports["codem-supreme-radialmenu"]:GetDefaultCommands()
    local commandMenuEnabled = exports["codem-supreme-radialmenu"]:IsCommandMenuEnabled()
    cb({
        commands = customCommands or {},
        defaultCommands = defaultCommands or {},
        commandMenuEnabled = commandMenuEnabled
    })
end)

-- NUI回调：设置径向菜单命令
RegisterNUICallback("SET_RADIALMENU_COMMANDS", function(data, cb)
    local state = GetResourceState("codem-supreme-radialmenu")
    if state ~= "started" then
        cb({ error = true })
        return
    end
    local commands = data.commands
    if not commands then
        commands = {}
    end
    exports["codem-supreme-radialmenu"]:SetCustomCommands(commands)
    cb("ok")
end)

-- NUI回调：获取聊天设置
RegisterNUICallback("GET_CHAT_SETTINGS", function(data, cb)
    local state = GetResourceState("codem-supreme-chat")
    if state ~= "started" then
        cb({ error = true })
        return
    end
    local result = exports["codem-supreme-chat"]:GetSettings()
    cb(result or {})
end)

-- NUI回调：获取聊天可见频道
RegisterNUICallback("GET_CHAT_VISIBLE_CHANNELS", function(data, cb)
    local state = GetResourceState("codem-supreme-chat")
    if state ~= "started" then
        cb({ dispatch = true, gang = true })
        return
    end
    local restrictedChannels = exports["codem-supreme-chat"]:GetRestrictedChannels()
    local visibleChannels = { dispatch = true, gang = true }
    local playerName = ""
    local gangName = ""

    -- 获取玩家职业和帮派信息
    if Core then
        if Core.Functions then
            if Core.Functions.GetPlayerData then
                local playerData = Core.Functions.GetPlayerData()
                if playerData then
                    if playerData.job then
                        playerName = playerData.job.name or ""
                    end
                    if playerData.gang then
                        gangName = playerData.gang.name or ""
                    end
                end
            end
        end
    else
        if Core.GetPlayerData then
            local playerData = Core.GetPlayerData()
            if playerData then
                if playerData.job then
                    playerName = playerData.job.name or ""
                end
                if playerData.gang then
                    gangName = playerData.gang.name or ""
                end
            end
        end
    end

    -- 检查 dispatch 频道可见性
    if restrictedChannels.dispatch then
        if #restrictedChannels.dispatch > 0 then
            visibleChannels.dispatch = false
            for _, jobName in ipairs(restrictedChannels.dispatch) do
                if jobName == playerName then
                    visibleChannels.dispatch = true
                    break
                end
            end
        end
    end

    -- 检查 gang 频道可见性
    if restrictedChannels.gang then
        local gangJobs = restrictedChannels.gang.jobs
        if not gangJobs then
            gangJobs = {}
        end
        local gangGangs = restrictedChannels.gang.gangs
        if not gangGangs then
            gangGangs = {}
        end
        if #gangJobs > 0 or #gangGangs > 0 then
            visibleChannels.gang = false
            for _, jobName in ipairs(gangJobs) do
                if jobName == playerName then
                    visibleChannels.gang = true
                    break
                end
            end
            if not visibleChannels.gang then
                for _, gang in ipairs(gangGangs) do
                    if gang == gangName then
                        visibleChannels.gang = true
                        break
                    end
                end
            end
        end
    end

    cb(visibleChannels)
end)

-- NUI回调：设置聊天设置
RegisterNUICallback("SET_CHAT_SETTINGS", function(data, cb)
    local state = GetResourceState("codem-supreme-chat")
    if state ~= "started" then
        cb({ error = true })
        return
    end
    exports["codem-supreme-chat"]:UpdateSettings(data)
    cb("ok")
end)

-- Debug命令：重置HUD
if Config.Debug then
    RegisterCommand("resethud", function()
        CloseSettingsMenu()
        NuiMessage("RESET_STORAGE")
        Wait(200)
        NuiMessage("TRIGGER_SETUP")
    end, false)
end
