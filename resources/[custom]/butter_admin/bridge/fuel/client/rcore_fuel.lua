if not UseBridge('fuel', 'rcore_fuel') then return end

---@param vehicle number
---@param fuel number
function SetVehicleFuel(vehicle, fuel)
    exports['rcore_fuel']:SetVehicleFuel(vehicle, fuel)
end
