if not UseBridge('fuel', 'okokGasStation') then return end

---@param vehicle number
---@param fuel number
function SetVehicleFuel(vehicle, fuel)
    exports['okokGasStation']:SetFuel(vehicle, fuel)
end
