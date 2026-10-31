
RegisterNetEvent("oxlyn-popsbangs:valveOpen", function(netId)
    local src = source
    if not PopsProtocol.Integer(netId, 1, 65535) then
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then
        return
    end

    local tune = GetVehicleTune(vehicle)
    local isClosed = false
    if tune and tune.valveClosed then
        isClosed = true
    end

    TriggerClientEvent("oxlyn-popsbangs:valveUI", src, {
        open = true,
        netId = netId,
        closed = isClosed
    })
end)

RegisterNetEvent("oxlyn-popsbangs:valveSet", function(netId, isClosed)
    local src = source
    if not PopsProtocol.Integer(netId, 1, 65535) or type(isClosed) ~= "boolean" then
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then
        return
    end

    SetVehicleTune(vehicle, { valveClosed = isClosed })

    TriggerClientEvent("oxlyn-popsbangs:valveUI", src, {
        open = true,
        update = true,
        netId = netId,
        closed = isClosed
    })
end)
--fivevaultsraOnVuTope4 : https://discord.gg/fivevault
--fivevault_mqOn1dTopME : https://discord.gg/fivevault
--fivevault-NxOn2_TopWR : https://discord.gg/fivevault
--fivevault-loOnkBTopCU : https://discord.gg/fivevault
--fivevaultwGOnoOTopYB : https://discord.gg/fivevault
