-- 获取最大客户端数量
local maxClients = GetConvarInt("sv_maxclients", 32)

-- 广播玩家计数到所有客户端
function broadcastPlayerCount()
    local currentCount = GetNumPlayerIndices()
    TriggerClientEvent("codem-hud:client:UpdatePlayerCount", -1, currentCount, maxClients)
end

-- RPC: 获取玩家计数
RPC.Register("codem-hud:getPlayerCount", function()
    local result = {}
    result.count = GetNumPlayerIndices()
    result.max = maxClients
    return result
end)

-- 玩家连接时延迟广播玩家计数
AddEventHandler("playerConnecting", function()
    SetTimeout(1000, broadcastPlayerCount)
end)

-- 社团金钱缓存
local societyMoneyCache = {}
local CACHE_DURATION = 5000

-- RPC: 获取社团金钱
RPC.Register("codem-hud:getSocietyMoney", function(playerId)
    -- 检查社团金钱功能是否启用
    if not Config.SocietyMoney or not Config.SocietyMoney.Enabled then
        return false
    end

    -- 检查Core框架是否可用
    if not Core or not Core.Functions then
        return false
    end

    -- 获取玩家职业信息
    local playerJob = Core.Functions.GetPlayerJob(playerId)
    if not playerJob or not playerJob.name or playerJob.name == "unemployed" then
        societyMoneyCache[playerId] = nil
        return false
    end

    -- BossOnly模式：检查玩家是否为老板
    if Config.SocietyMoney.BossOnly then
        local isBoss = playerJob.isboss
        if not isBoss then
            isBoss = playerJob.isBoss
        end

        if not isBoss then
            local gradeLabel = playerJob.gradeLabel
            if not gradeLabel then
                gradeLabel = playerJob.grade_label
                if not gradeLabel then
                    gradeLabel = playerJob.grade_name
                    if not gradeLabel then
                        gradeLabel = ""
                    end
                end
            end

            local bossTitles = {"boss", "owner", "ceo", "chief", "director", "manager", "patron", "sahip"}
            for _, title in ipairs(bossTitles) do
                if string.lower(gradeLabel):find(title) then
                    isBoss = true
                    break
                end
            end
        end

        if not isBoss then
            societyMoneyCache[playerId] = nil
            return false
        end
    end

    -- 检查缓存是否有效
    local currentTime = GetGameTimer()
    local cached = societyMoneyCache[playerId]
    if cached and (currentTime - cached.time) < CACHE_DURATION then
        return cached.amount
    end

    -- 获取社团金钱并更新缓存
    local societyMoney = Core.Functions.GetSocietyMoney(playerJob.name)
    if not societyMoney then
        societyMoney = 0
    end

    societyMoneyCache[playerId] = {
        amount = societyMoney,
        time = currentTime
    }

    return societyMoney
end)

-- 玩家离开时清理社团金钱缓存并广播
AddEventHandler("playerDropped", function()
    local playerSrc = source
    societyMoneyCache[playerSrc] = nil
    broadcastPlayerCount()
end)

-- 转发载具事件给触发者自己（用于HUD状态更新）
RegisterNetEvent("baseevents:enteredVehicle", function(vehicle, seat, displayName, netId)
    local playerSrc = source
    TriggerClientEvent("baseevents:enteredVehicle", playerSrc, vehicle, seat, displayName, netId)
end)

RegisterNetEvent("baseevents:leftVehicle", function(vehicle, seat, displayName, netId)
    local playerSrc = source
    TriggerClientEvent("baseevents:leftVehicle", playerSrc, vehicle, seat, displayName, netId)
end)

RegisterNetEvent("baseevents:enteringVehicle", function(vehicle, seat, displayName, netId)
    local playerSrc = source
    TriggerClientEvent("baseevents:enteringVehicle", playerSrc, vehicle, seat, displayName, netId)
end)

RegisterNetEvent("baseevents:enteringAborted", function()
    local playerSrc = source
    TriggerClientEvent("baseevents:enteringAborted", playerSrc)
end)

-- RPC: 获取玩家RP名称
RPC.Register("codem-hud:getPlayerRpName", function(playerServerId, targetId)
    if not targetId then
        return "Unknown"
    end

    if Core and Core.Functions and Core.Functions.GetName then
        local name = Core.Functions.GetName(targetId)
        if not name then
            name = "Unknown"
        end
        return name
    end

    local name = GetPlayerName(targetId)
    if not name then
        name = "Unknown"
    end
    return name
end)

-- RPC: 检查玩家是否拥有信号干扰器
RPC.Register("codem-hud:hasSignalJammer", function(playerServerId, targetId)
    if not targetId then
        return false
    end

    -- 获取信号干扰器物品列表
    local jammerItems = nil
    if Config.TargetInfo and Config.TargetInfo.SignalJammer then
        jammerItems = Config.TargetInfo.SignalJammer.Items
    end

    if not jammerItems or #jammerItems == 0 then
        return false
    end

    -- 检查玩家是否持有任意干扰器物品
    for _, itemName in ipairs(jammerItems) do
        if ServerInventory.HasItem(targetId, itemName, 1) then
            return true
        end
    end

    return false
end)

-- RPC: 获取玩家压力值
RPC.Register("codem-hud:getPlayerStress", function(playerServerId)
    if not playerServerId then
        return 0
    end

    if Core and Core.Functions and Core.Functions.GetPlayerStress then
        local stress = Core.Functions.GetPlayerStress(playerServerId)
        if not stress then
            stress = 0
        end
        debugPrint("[Stress] RPC getPlayerStress for " .. playerServerId .. ": " .. stress)
        return stress
    end

    return 0
end)

-- 导出: GetPlayerStress
exports("GetPlayerStress", function(playerServerId)
    if not playerServerId then
        return 0
    end

    if Core and Core.Functions and Core.Functions.GetPlayerStress then
        local stress = Core.Functions.GetPlayerStress(playerServerId)
        if not stress then
            stress = 0
        end
        return stress
    end

    return 0
end)

-- 导出: AddPlayerStress
exports("AddPlayerStress", function(playerServerId, amount)
    if not playerServerId or not amount then
        return
    end
    TriggerClientEvent("codem-hud:client:AddStress", playerServerId, amount)
end)

-- 导出: RemovePlayerStress
exports("RemovePlayerStress", function(playerServerId, amount)
    if not playerServerId or not amount then
        return
    end
    TriggerClientEvent("codem-hud:client:RemoveStress", playerServerId, amount)
end)

-- 事件: 饥饿肚子叫声 - 通知附近玩家
RegisterNetEvent("codem-hud:server:HungerGrowl", function(maxDistance)
    local playerSrc = source
    local playerPed = GetPlayerPed(playerSrc)
    if not playerPed or playerPed == 0 then
        return
    end

    local playerCoords = GetEntityCoords(playerPed)
    local allPlayers = GetPlayers()

    for _, otherPlayerId in ipairs(allPlayers) do
        local otherPlayerNum = tonumber(otherPlayerId)
        if otherPlayerNum and otherPlayerNum ~= playerSrc then
            local otherPed = GetPlayerPed(otherPlayerNum)
            if otherPed and otherPed ~= 0 then
                local otherCoords = GetEntityCoords(otherPed)
                local distance = #(playerCoords - otherCoords)
                local distThreshold = maxDistance or 10.0
                if distance <= distThreshold then
                    TriggerClientEvent("codem-hud:client:HungerGrowl", otherPlayerNum, {
                        x = playerCoords.x,
                        y = playerCoords.y,
                        z = playerCoords.z
                    })
                end
            end
        end
    end
end)

-- 导出: SetPlayerStress
exports("SetPlayerStress", function(playerServerId, amount)
    if not playerServerId or amount == nil then
        return
    end
    TriggerClientEvent("codem-hud:client:SetStress", playerServerId, amount)
end)

-- 事件: 添加玩家压力
RegisterNetEvent("codem-hud:server:AddPlayerStress", function(playerServerId, amount)
    TriggerClientEvent("codem-hud:client:AddStress", playerServerId, amount)
end)

-- 事件: 移除玩家压力
RegisterNetEvent("codem-hud:server:RemovePlayerStress", function(playerServerId, amount)
    TriggerClientEvent("codem-hud:client:RemoveStress", playerServerId, amount)
end)

-- 启动时检查资源名称是否正确
CreateThread(function()
    Wait(1000)
    local resourceName = GetCurrentResourceName()
    if resourceName ~= "codem-supreme-hud" then
        print("^1[CODEM-HUD] WARNING: The resource has been renamed to \"" .. resourceName .. "\". The script may not work correctly. Please rename the resource folder back to \"codem-supreme-hud\".^0")
    end
end)

debugPrint("[Core] Server module loaded")
