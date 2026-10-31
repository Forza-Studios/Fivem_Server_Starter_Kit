if not UseBridge('vehiclekeys', 'qb-vehiclekeys') then return end

---@param plate string
function GiveVehicleKeys(plate)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
end
