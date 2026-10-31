local nextPromiseId = 0

-- 延迟清理Promise（5秒后移除）
function schedulePromiseCleanup(promiseId)
    SetTimeout(5000, function()
        RPC.Promises[promiseId] = nil
    end)
end

-- 触发服务器事件（自动选择普通或latent方式）
function triggerServerEventInternal(eventName, ...)
    local packed = msgpack.pack({...})
    local packedLen = packed:len()
    if packedLen < 5000 then
        TriggerServerEventInternal(eventName, packed, packed:len(), packed)
    else
        TriggerLatentServerEventInternal(eventName, packed, packed:len(), 128000)
    end
end

RPC = {}
RPC.Promises = {}
RPC.Functions = {}

-- 执行RPC请求：向服务器发送请求并等待响应
function RPC.execute(eventName, ...)
    local promiseId = nextPromiseId
    local resolved = false
    nextPromiseId = nextPromiseId + 1
    RPC.Promises[promiseId] = promise.new()
    triggerServerEventInternal("codem-hud:rpc:request", eventName, promiseId, Utils.ParamPacker(GetPlayerServerId(PlayerId()), ...), true)
    SetTimeout(20000, function()
        if not resolved then
            RPC.Promises[promiseId]:resolve({nil})
        end
    end)
    local result = Citizen.Await(RPC.Promises[promiseId])
    resolved = true
    schedulePromiseCleanup(promiseId)
    return Utils.ParamUnpacker(result)
end

-- 注册RPC函数
function RPC.Register(name, func)
    RPC.Functions[name] = func
end

-- 监听服务器RPC响应
RegisterNetEvent("codem-hud:rpc:response")
AddEventHandler("codem-hud:rpc:response", function(promiseId, data)
    local promise = RPC.Promises[promiseId]
    if promise then
        RPC.Promises[promiseId]:resolve(data)
    end
end)

-- 监听服务器RPC请求
RegisterNetEvent("codem-hud:rpc:request")
AddEventHandler("codem-hud:rpc:request", function(eventName, promiseId, params)
    local func = RPC.Functions[eventName]
    if not func then
        return
    end
    local result = nil
    local ok, err = pcall(function()
        result = Utils.ParamPacker(RPC.Functions[eventName](Utils.ParamUnpacker(params)))
    end)
    if not ok then
        debugPrint("[RPC] Error:", eventName, err)
    end
    triggerServerEventInternal("codem-hud:rpc:response", promiseId, result or {}, true)
end)
