if not UseBridge('vehiclekeys', 't1ger_keys') then return end

---@param plate string
function GiveVehicleKeys(plate)
    TriggerServerEvent('t1ger_keys:updateOwnedKeys', plate, true)
end
