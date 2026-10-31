if not UseBridge('fuel', 'lc_fuel') then return end

---@param vehicle number
---@param fuel number
function SetVehicleFuel(vehicle, fuel)
    exports['lc_fuel']:SetFuel(vehicle, fuel)
end
