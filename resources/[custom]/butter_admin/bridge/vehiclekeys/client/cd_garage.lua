if not UseBridge('vehiclekeys', 'cd_garage') then return end

---@param plate string
function GiveVehicleKeys(plate)
    TriggerEvent('cd_garage:AddKeys', plate)
end
