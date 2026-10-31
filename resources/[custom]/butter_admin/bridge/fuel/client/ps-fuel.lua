if not UseBridge('fuel', 'ps-fuel') then return end

---@param vehicle number
---@param fuel number
function SetVehicleFuel(vehicle, fuel)
    exports['ps-fuel']:SetFuel(vehicle, fuel)
end
