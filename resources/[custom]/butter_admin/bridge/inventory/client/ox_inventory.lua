if not UseBridge('inventory', 'ox_inventory') then return end

-- ox_inventory only opens a trunk/glovebox for a vehicle that exists, so a
-- hidden copy is spawned under the admin and deleted once the inventory closes.
local ghostVehicle

local function deleteGhostVehicle()
    if ghostVehicle and DoesEntityExist(ghostVehicle) then
        SetEntityAsMissionEntity(ghostVehicle, true, true)
        DeleteVehicle(ghostVehicle)
    end
    ghostVehicle = nil
end

---@param plate string
---@return number netId
local function spawnGhostVehicle(plate)
    deleteGhostVehicle()

    local model = joaat(lib.callback.await('butter_admin:server:getVehicleModel', false, plate) or 'sultan')
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then model = `sultan` end
    lib.requestModel(model)

    local coords = GetEntityCoords(cache.ped)
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z - 20.0, 0.0, true, false)
    SetModelAsNoLongerNeeded(model)
    SetVehicleNumberPlateText(vehicle, plate)
    FreezeEntityPosition(vehicle, true)
    SetEntityVisible(vehicle, false, false)
    SetEntityCollision(vehicle, false, false)

    pcall(lib.waitFor, function() return NetworkGetEntityIsNetworked(vehicle) or nil end, nil, 500)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, false)

    ghostVehicle = vehicle
    return netId
end

local function deleteGhostWhenClosed()
    CreateThread(function()
        pcall(lib.waitFor, function() return IsNuiFocused() or nil end, nil, 2000)
        while ghostVehicle and (IsNuiFocused() or IsPauseMenuActive()) do
            Wait(500)
        end
        deleteGhostVehicle()
    end)
end

---@param vehicleType 'trunk'|'glovebox'
---@param plate string
function OpenVehicleInventory(vehicleType, plate)
    local netId = spawnGhostVehicle(plate)
    Wait(200)
    TriggerServerEvent('butter_admin:server:openVehicleInventory', vehicleType, plate, netId)
    deleteGhostWhenClosed()
end

-- ox_inventory closes inventories through this event, both locally and from its server.
RegisterNetEvent('ox_inventory:closeInventory', deleteGhostVehicle)
