if not UseBridge('vehiclekeys', 'qbx_vehiclekeys') then return end

---@param plate string
function GiveVehicleKeys(plate)
    TriggerEvent('qb-vehiclekeys:client:AddKeys', plate)
end
