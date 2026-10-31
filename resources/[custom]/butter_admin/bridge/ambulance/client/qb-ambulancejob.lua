if not UseBridge('ambulance', 'qb-ambulancejob') then return end

function RevivePlayer()
    TriggerEvent('hospital:client:RevivePlayer')
end

function KillPlayer()
    TriggerEvent('hospital:client:KillPlayer')
end
