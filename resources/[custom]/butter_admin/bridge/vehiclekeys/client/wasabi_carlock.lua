if not UseBridge('vehiclekeys', 'wasabi_carlock') then return end

---@param plate string
function GiveVehicleKeys(plate)
    exports.wasabi_carlock:GiveKey(plate)
end
