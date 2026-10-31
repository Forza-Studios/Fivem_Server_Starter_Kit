-- oxlyn-truckjob core client state (decompiled output, cleaned: names restored, temp registers removed)
-- Defines the global `Truck` table used by the other client script.
-- Relies on globals defined elsewhere: Config, Notify, _U

---------------------------------------------------------------------
-- Shared state
---------------------------------------------------------------------
Truck = {
    onDuty = false,
    menuOpen = false,
    activeRoute = nil,
    pickupReached = false,
    truckEntity = nil,
    trailerEntity = nil,
    pickupTrailer = nil,
    deliveryCoord = nil,
    routeBlip = nil,
    startTime = 0,
    distanceM = 0,
    initialDistM = 0,
    lastPos = nil,
    damageHits = 0,
    cooldownUntil = 0,
    level = 1,
    xp = 0,
    xpNext = 200,
}

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
function Truck.RouteById(id)
    for _, route in ipairs(Config.Routes) do
        if route.id == id then
            return route
        end
    end
end

-- Truck health as 0.0 - 1.0 (based on engine health)
function Truck.GetVehicleHealthPct()
    local truck = Truck.truckEntity
    if not (truck and DoesEntityExist(truck)) then
        return 0
    end

    local engineHealth = GetVehicleEngineHealth(truck)
    return math.max(0, math.min(1, engineHealth / 1000))
end

function Truck.AddRouteBlip(coords, name)
    if Truck.routeBlip then
        RemoveBlip(Truck.routeBlip)
    end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 1.0)
    SetBlipRoute(blip, Config.UI.showRouteOnMap)
    SetBlipRouteColour(blip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(name or "Destino") -- "Destino" = "Destination"
    EndTextCommandSetBlipName(blip)

    Truck.routeBlip = blip
end

function Truck.ClearRouteBlip()
    if Truck.routeBlip then
        RemoveBlip(Truck.routeBlip)
        Truck.routeBlip = nil
    end
end

---------------------------------------------------------------------
-- Server -> client events
---------------------------------------------------------------------
RegisterNetEvent("oxlyn-truckjob:client:walletUpdate", function(wallet)
    SendNUIMessage({ action = "wallet", wallet = wallet })
end)

RegisterNetEvent("oxlyn-truckjob:client:setProgression", function(progression)
    if not progression then return end

    Truck.level = progression.level or Truck.level
    Truck.xp = progression.xp or 0
    Truck.xpNext = progression.xpNext or 200

    SendNUIMessage({ action = "progression", progression = progression })
end)

RegisterNetEvent("oxlyn-truckjob:client:levelUp", function(level)
    SendNUIMessage({ action = "levelUp", level = level })
    Notify.Send(nil, _U("level_up", level), "success", 5500)
end)

---------------------------------------------------------------------
-- Command
---------------------------------------------------------------------
local commands = Config.Commands or {}
if commands.openEnabled ~= false then
    RegisterCommand(Config.Commands.open or "truckjob", function()
        TriggerEvent("oxlyn-truckjob:client:openMenu")
    end, false)
end

---------------------------------------------------------------------
-- Cleanup when the resource stops
---------------------------------------------------------------------
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, key in ipairs({ "truckEntity", "trailerEntity", "pickupTrailer" }) do
        local entity = Truck[key]
        if entity and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    if Truck.routeBlip then
        RemoveBlip(Truck.routeBlip)
    end

    SetNuiFocus(false, false)
end)