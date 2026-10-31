if not UseBridge('vehiclekeys', 'MrNewbVehicleKeys') then return end

---@param plate string
function GiveVehicleKeys(plate)
    exports.MrNewbVehicleKeys:GiveKeysByPlate(plate)
end
