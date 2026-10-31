if not UseBridge('fuel', 'lj-fuel') then return end

---@param vehicle number
---@param fuel number
function SetVehicleFuel(vehicle, fuel)
    exports['lj-fuel']:SetFuel(vehicle, fuel)
end
