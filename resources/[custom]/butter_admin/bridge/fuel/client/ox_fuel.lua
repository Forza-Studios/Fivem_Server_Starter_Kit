if not UseBridge('fuel', 'ox_fuel') then return end

---@param vehicle number
---@param fuel number
function SetVehicleFuel(vehicle, fuel)
    Entity(vehicle).state:set('fuel', fuel, true)
end
