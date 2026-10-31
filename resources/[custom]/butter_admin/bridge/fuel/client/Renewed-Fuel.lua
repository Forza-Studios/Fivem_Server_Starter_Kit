if not UseBridge('fuel', 'Renewed-Fuel') then return end

---@param vehicle number
---@param fuel number
function SetVehicleFuel(vehicle, fuel)
    exports['Renewed-Fuel']:SetFuel(vehicle, fuel)
end
