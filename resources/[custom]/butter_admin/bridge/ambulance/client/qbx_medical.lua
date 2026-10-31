if not UseBridge('ambulance', 'qbx_medical') then return end

function RevivePlayer()
    TriggerEvent('qbx_medical:client:playerRevived')
end

function KillPlayer()
    SetEntityHealth(cache.ped, 0)
    TriggerEvent('qbx_medical:client:onPlayerDeath')
end
