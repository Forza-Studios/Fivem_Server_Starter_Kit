local nextPromiseId = 0

RPC = {}
RPC.Promises = {}
RPC.Functions = {}
RPC.Callbacks = {}

local rateLimitState = {}
rateLimitState.requests = {}
rateLimitState.config = {}
rateLimitState.config.maxRequests = 30
rateLimitState.config.windowMs = 1000
rateLimitState.config.banThreshold = 100
rateLimitState.config.banDuration = 60000
rateLimitState.violations = {}
rateLimitState.banned = {}

-- [功能] 检查玩家是否超过请求速率限制
function rateLimitState.checkRateLimit(playerId, eventName)
    local currentTimer = GetGameTimer()

    -- [功能] 检查玩家是否被封禁
    if rateLimitState.banned[playerId] then
        if currentTimer < rateLimitState.banned[playerId] then
            return false
        else
            rateLimitState.banned[playerId] = nil
            rateLimitState.violations[playerId] = 0
        end
    end

    -- [功能] 初始化玩家请求记录
    if not rateLimitState.requests[playerId] then
        rateLimitState.requests[playerId] = {}
    end

    -- [功能] 初始化事件请求记录
    if not rateLimitState.requests[playerId][eventName] then
        rateLimitState.requests[playerId][eventName] = {}
        rateLimitState.requests[playerId][eventName].count = 0
        rateLimitState.requests[playerId][eventName].lastReset = currentTimer
    end

    -- [功能] 检查时间窗口是否过期，重置计数
    local elapsed = currentTimer - rateLimitState.requests[playerId][eventName].lastReset
    if elapsed >= rateLimitState.config.windowMs then
        rateLimitState.requests[playerId][eventName].count = 0
        rateLimitState.requests[playerId][eventName].lastReset = currentTimer
    end

    -- [功能] 增加请求计数
    rateLimitState.requests[playerId][eventName].count = rateLimitState.requests[playerId][eventName].count + 1

    -- [功能] 超过最大请求数时记录违规
    if rateLimitState.requests[playerId][eventName].count > rateLimitState.config.maxRequests then
        local currentViolations = rateLimitState.violations[playerId]
        if not currentViolations then
            currentViolations = 0
        end
        rateLimitState.violations[playerId] = currentViolations + 1

        -- [功能] 违规次数达到阈值时封禁玩家
        if rateLimitState.violations[playerId] >= rateLimitState.config.banThreshold then
            rateLimitState.banned[playerId] = currentTimer + rateLimitState.config.banDuration
            debugPrint("[RPC] Player " .. playerId .. " temporarily banned for rate limit abuse")
        end

        return false
    end

    return true
end

-- [功能] 清理玩家的所有速率限制数据
function rateLimitState.clearPlayerData(playerId)
    rateLimitState.requests[playerId] = nil
    rateLimitState.violations[playerId] = nil
    rateLimitState.banned[playerId] = nil
end

-- [功能] 玩家断开连接时清理数据
AddEventHandler("playerDropped", function()
    rateLimitState.clearPlayerData(source)
end)

-- [功能] 延迟清理已完成的 promise
function schedulePromiseCleanup(promiseId)
    SetTimeout(5000, function()
        RPC.Promises[promiseId] = nil
    end)
end

-- [功能] 注册服务端 RPC 函数
function RPC.Register(eventName, handlerFunc)
    RPC.Functions[eventName] = handlerFunc
end

-- [功能] 处理客户端 RPC 请求
RegisterServerEvent("codem-hud:rpc:request")
AddEventHandler("codem-hud:rpc:request", function(eventName, promiseId, packedArgs)
    local playerSrc = source

    -- [功能] 检查请求的函数是否存在
    if not RPC.Functions[eventName] then
        return
    end

    -- [功能] 检查速率限制
    if not rateLimitState.checkRateLimit(playerSrc, eventName) then
        TriggerClientEvent("codem-hud:rpc:response", playerSrc, promiseId, {
            success = false,
            error = "rate_limited"
        })
        return
    end

    -- [功能] 解包参数并验证来源
    local unpackedArgs = { Utils.ParamUnpacker(packedArgs) }

    if unpackedArgs then
        if unpackedArgs[1] then
            if unpackedArgs[1] ~= playerSrc then
                DropPlayer(playerSrc, "Invalid event source")
                return
            end
        end
    end

    -- [功能] 执行 RPC 函数并返回结果
    local resultData = nil
    local pcallOk, pcallErr = pcall(function()
        resultData = Utils.ParamPacker(RPC.Functions[eventName](Utils.ParamUnpacker(packedArgs)))
    end)

    if not pcallOk then
        debugPrint("[RPC] Error:", eventName, pcallErr)
    end

    TriggerClientEvent("codem-hud:rpc:response", playerSrc, promiseId, resultData or {})
end)

-- [功能] 处理客户端 RPC 响应
RegisterServerEvent("codem-hud:rpc:response")
AddEventHandler("codem-hud:rpc:response", function(promiseId, responseData)
    -- [功能] 处理 Promise 响应
    if RPC.Promises[promiseId] then
        RPC.Promises[promiseId].resolve(RPC.Promises[promiseId], responseData)
    else
        -- [功能] 处理 Callback 响应
        if RPC.Callbacks[promiseId] then
            RPC.Callbacks[promiseId](Utils.ParamUnpacker(responseData))
            RPC.Callbacks[promiseId] = nil
        end
    end
end)

-- [功能] 服务端向客户端执行 RPC 调用
function RPC.execute(eventName, targetPlayer, ...)
    local currentPromiseId = nextPromiseId
    local promiseResolved = false
    nextPromiseId = nextPromiseId + 1

    -- [功能] 创建 Promise 并存储
    local newPromise = promise.new()
    RPC.Promises[currentPromiseId] = newPromise

    -- [功能] 触发客户端 RPC 请求
    TriggerClientEvent("codem-hud:rpc:request", targetPlayer, eventName, currentPromiseId, Utils.ParamPacker(...))

    -- [功能] 设置超时自动解决
    SetTimeout(20000, function()
        if not promiseResolved then
            RPC.Promises[currentPromiseId].resolve(RPC.Promises[currentPromiseId], { nil })
        end
    end)

    -- [功能] 等待 Promise 完成并清理
    local awaitResult = Citizen.Await(RPC.Promises[currentPromiseId])
    promiseResolved = true
    schedulePromiseCleanup(currentPromiseId)

    return Utils.ParamUnpacker(awaitResult)
end
