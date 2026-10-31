if not UseBridge('fuel', 'LegacyFuel') then return end

---@param vehicle number
---@param fuel number
function SetVehicleFuel(vehicle, fuel)
    exports['LegacyFuel']:SetFuel(vehicle, fuel)
end
