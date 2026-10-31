if not UseBridge('fuel', 'nd_fuel') then return end

---@param vehicle number
---@param fuel number
function SetVehicleFuel(vehicle, fuel)
    exports['nd_fuel']:SetFuel(vehicle, fuel)
end
