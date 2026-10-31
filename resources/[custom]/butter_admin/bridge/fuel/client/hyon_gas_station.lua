if not UseBridge('fuel', 'hyon_gas_station') then return end

---@param vehicle number
---@param fuel number
function SetVehicleFuel(vehicle, fuel)
    exports['hyon_gas_station']:SetFuel(vehicle, fuel)
end
