local cfg = Config.HungerSound
if not cfg or not cfg.Enabled then return end

CreateThread(function()
    while true do
        Wait(cfg.Interval)
        if not (IsPlayerLoaded() and GetHudSettings()) then goto continue end
        if IsEntityDead(PlayerPedId()) then goto continue end

        local needs = GetPlayerNeeds and GetPlayerNeeds() or nil
        if needs and needs.hunger <= cfg.Threshold then
            NuiMessage('playHungerGrowl', { file = cfg.SoundFile })
            if cfg.NearbyEnabled then
                TriggerServerEvent('codem-hud:server:HungerGrowl', cfg.NearbyRadius)
            end
        end

        ::continue::
    end
end)

RegisterNetEvent('codem-hud:client:HungerGrowl', function(data)
    local myCoords = GetEntityCoords(PlayerPedId())
    local srcCoords = vector3(data.x, data.y, data.z)
    local dist = #(myCoords - srcCoords)
    if dist > 0.0 and dist <= (cfg.NearbyRadius or 10.0) then
        NuiMessage('playHungerGrowl', {
            file = cfg.SoundFile,
            distance = dist,
            maxRadius = cfg.NearbyRadius or 10.0,
        })
    end
end)
