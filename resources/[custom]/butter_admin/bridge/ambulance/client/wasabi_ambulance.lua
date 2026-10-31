if not UseBridge('ambulance', 'wasabi_ambulance') then return end

function RevivePlayer()
    local ok = pcall(function()
        exports.wasabi_ambulance:reviveTarget()
    end)
    if not ok then TriggerEvent('wasabi_ambulance:revive') end
end

function KillPlayer()
    local ok = pcall(function()
        exports.wasabi_ambulance:killTarget()
    end)
    if not ok then TriggerEvent('wasabi_ambulance:killPlayer') end
    SetEntityHealth(cache.ped, 0)
end
