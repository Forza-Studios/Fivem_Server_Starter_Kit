if not UseBridge('fuel', 'cdn-fuel') then return end

---@param vehicle number
---@param fuel number
function SetVehicleFuel(vehicle, fuel)
    exports['cdn-fuel']:SetFuel(vehicle, fuel)
end
