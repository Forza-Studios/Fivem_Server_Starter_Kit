
local activeTokens = {}

function FindExhaustByItem(itemName)
    local exhausts = (type(Config) == "table" and Config.Exhausts) or {}
    for exhaustKey, exhaustData in pairs(exhausts) do
        if exhaustData.item == itemName then
            return exhaustKey, exhaustData
        end
    end
    return nil, nil
end

RegisterNetEvent("oxlyn-popsbangs:workshopBegin", function(netId, itemName)
    local src = source
    if not PopsProtocol.Integer(netId, 1, 65535) or type(itemName) ~= "string" then
        return
    end

    local itemsCfg = (type(Config) == "table" and Config.Items) or {}
    if itemsCfg.enabled == false then
        return
    end

    if not PopsFramework.HasJob(src, itemsCfg.jobs) then
        PopsFramework.Notify(src, L("job_not_allowed"), "error")
        return
    end

    if not PopsInventory.HasItem(src, itemName, 1) then
        PopsFramework.Notify(src, L("missing_item"), "error")
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then
        return
    end

    local currentTune = GetVehicleTune(vehicle)
    local mode = nil
    local duration = 5
    local exhaustKey = nil
    local exhaustData = nil

    if itemName == itemsCfg.antiLagKit then
        if currentTune and currentTune.antiLag then
            PopsFramework.Notify(src, L("antilag_already_installed"), "warning")
            return
        end
        mode = "install"
        duration = (itemsCfg.seconds and itemsCfg.seconds.install) or 5
    elseif itemName == itemsCfg.antiLagRemover then
        if not currentTune or not currentTune.antiLag then
            PopsFramework.Notify(src, L("antilag_not_installed"), "warning")
            return
        end
        mode = "remove"
        duration = (itemsCfg.seconds and itemsCfg.seconds.remove) or 5
    else
        exhaustKey, exhaustData = FindExhaustByItem(itemName)
        if exhaustKey then
            mode = "exhaust"
            duration = (itemsCfg.seconds and itemsCfg.seconds.exhaust) or 5
        end
    end

    if not mode then
        return
    end

    local token = string.format("%d:%d:%d", src, GetGameTimer(), math.random(1000, 9999))

    activeTokens[token] = {
        source = src,
        netId = netId,
        vehicle = vehicle,
        item = itemName,
        mode = mode,
        exhaust = exhaustKey,
        startTime = GetGameTimer(),
        duration = duration
    }

    local labels = {
        exhaust = (exhaustData and exhaustData.label) or exhaustKey or "",
        current = (currentTune and currentTune.exhaust) or "stock",
        returned = (mode == "remove" and itemsCfg.returnKit and itemsCfg.antiLagKit) or nil,
        consumed = itemName
    }

    local levelsPayload = {}
    if mode == "install" then
        for idx, lvl in ipairs(Config.Levels or {}) do
            levelsPayload[idx] = {
                level = idx,
                name = lvl.name or tostring(idx),
                heavyChance = lvl.heavyChance,
                radius = lvl.radius,
                flameScale = lvl.flameScale
            }
        end
    end

    TriggerClientEvent("oxlyn-popsbangs:workshopOpen", src, {
        token = token,
        mode = mode,
        seconds = duration,
        exhaust = exhaustKey,
        item = itemName,
        level = (currentTune and currentTune.level) or 2,
        levels = levelsPayload,
        labels = labels
    })
end)

RegisterNetEvent("oxlyn-popsbangs:workshopCancel", function(token)
    if type(token) == "string" and activeTokens[token] then
        activeTokens[token] = nil
    end
end)

RegisterNetEvent("oxlyn-popsbangs:workshopFinish", function(token, selectedLevel)
    local src = source
    if type(token) ~= "string" or not activeTokens[token] then
        TriggerClientEvent("oxlyn-popsbangs:workshopResult", src, false, L("job_cancelled"))
        return
    end

    local tokenData = activeTokens[token]
    activeTokens[token] = nil

    if tokenData.source ~= src then
        TriggerClientEvent("oxlyn-popsbangs:workshopResult", src, false, L("job_cancelled"))
        return
    end

    local elapsed = GetGameTimer() - tokenData.startTime
    local requiredMs = (tokenData.duration * 1000) - 2000
    if elapsed < requiredMs then
        TriggerClientEvent("oxlyn-popsbangs:workshopResult", src, false, L("job_cancelled"))
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(tokenData.netId)
    if not DoesEntityExist(vehicle) then
        vehicle = tokenData.vehicle
    end

    if not DoesEntityExist(vehicle) then
        TriggerClientEvent("oxlyn-popsbangs:workshopResult", src, false, L("left_car"))
        return
    end

    local itemsCfg = (type(Config) == "table" and Config.Items) or {}
    local mode = tokenData.mode

    local shouldConsume = true
    if mode == "remove" and itemsCfg.consumeRemover == false then
        shouldConsume = false
    end

    if shouldConsume then
        local removed = PopsInventory.RemoveItem(src, tokenData.item, 1)
        if not removed then
            TriggerClientEvent("oxlyn-popsbangs:workshopResult", src, false, L("missing_item"))
            return
        end
    end

    local currentTune = GetVehicleTune(vehicle) or {}

    if mode == "remove" then
        if itemsCfg.returnKit and itemsCfg.antiLagKit then
            PopsInventory.AddItem(src, itemsCfg.antiLagKit, 1)
        end
        SetVehicleTune(vehicle, { antiLag = false })
        TriggerClientEvent("oxlyn-popsbangs:workshopResult", src, true, L("antilag_removed"), {
            mode = "remove",
            consumed = shouldConsume and tokenData.item or nil,
            returned = (itemsCfg.returnKit and itemsCfg.antiLagKit) or nil
        })
    elseif mode == "install" then
        local finalLevel = tonumber(selectedLevel) or 2
        if not Config.Levels[finalLevel] then
            finalLevel = 2
        end
        SetVehicleTune(vehicle, { antiLag = true, level = finalLevel })
        TriggerClientEvent("oxlyn-popsbangs:workshopResult", src, true, L("antilag_installed"), {
            mode = "install",
            level = finalLevel,
            consumed = shouldConsume and tokenData.item or nil
        })
    elseif mode == "exhaust" then
        local oldExhaustKey = currentTune.exhaust or "stock"
        local exhausts = Config.Exhausts or {}
        local oldExhaustData = exhausts[oldExhaustKey]
        local returnedItem = nil
        if oldExhaustKey ~= "stock" and oldExhaustData and oldExhaustData.item then
            PopsInventory.AddItem(src, oldExhaustData.item, 1)
            returnedItem = oldExhaustData.item
        end
        SetVehicleTune(vehicle, { exhaust = tokenData.exhaust })
        TriggerClientEvent("oxlyn-popsbangs:workshopResult", src, true, L("exhaust_installed"), {
            mode = "exhaust",
            consumed = shouldConsume and tokenData.item or nil,
            returned = returnedItem
        })
    end
end)

RegisterCommand("givepops", function(source, args, rawCommand)
    local target = source
    if args[1] then
        local parsedTarget = tonumber(args[1])
        if parsedTarget and parsedTarget > 0 then
            target = parsedTarget
        end
    end

    if target == 0 then
        print("[oxlyn-popsbangs] Commande reservee aux joueurs en jeu ou specifiez un ID : /givepops <id>")
        return
    end

    local itemsCfg = (type(Config) == "table" and Config.Items) or {}
    local valveCfg = (type(Config) == "table" and Config.Valve) or {}
    local exhausts = (type(Config) == "table" and Config.Exhausts) or {}

    local itemsToGive = {}
    if itemsCfg.antiLagKit then
        itemsToGive[#itemsToGive + 1] = itemsCfg.antiLagKit
    end
    if itemsCfg.antiLagRemover then
        itemsToGive[#itemsToGive + 1] = itemsCfg.antiLagRemover
    end
    if valveCfg.item then
        itemsToGive[#itemsToGive + 1] = valveCfg.item
    end

    for _, exhaustData in pairs(exhausts) do
        if exhaustData.item then
            itemsToGive[#itemsToGive + 1] = exhaustData.item
        end
    end

    for _, itemName in ipairs(itemsToGive) do
        PopsInventory.AddItem(target, itemName, 1)
    end

    PopsFramework.Notify(target, "Items Pops & Bangs ajoutes a votre inventaire !", "success")
end, false)

RegisterCommand("popsitems", function(source, args, rawCommand)
    ExecuteCommand("givepops " .. tostring(source))
end, false)
--fivevaultsSUOnRqTopQt : https://discord.gg/fivevault
--fivevault-aCOnghTopGY : https://discord.gg/fivevault
--fivevaultsJ0Onc9TopWW : https://discord.gg/fivevault
--fivevault__2OnHPTop-o : https://discord.gg/fivevault
--fivevaults1QOn4OTop2B : https://discord.gg/fivevault
