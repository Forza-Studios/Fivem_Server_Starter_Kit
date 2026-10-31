if not UseBridge('vehiclekeys', 'okokGarage') then return end

---@param plate string
function GiveVehicleKeys(plate)
    TriggerServerEvent('okokGarage:GiveKeys', plate)
end
