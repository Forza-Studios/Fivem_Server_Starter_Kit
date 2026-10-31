if not UseBridge('vehiclekeys', 'jaksam-vehicles-keys') then return end

---@param plate string
function GiveVehicleKeys(plate)
    TriggerServerEvent('vehicles_keys:selfGiveVehicleKeys', plate)
end
