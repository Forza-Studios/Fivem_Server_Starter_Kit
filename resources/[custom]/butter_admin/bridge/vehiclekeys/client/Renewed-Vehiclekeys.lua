if not UseBridge('vehiclekeys', 'Renewed-Vehiclekeys') then return end

---@param plate string
function GiveVehicleKeys(plate)
    exports['Renewed-Vehiclekeys']:addKey(plate)
end
