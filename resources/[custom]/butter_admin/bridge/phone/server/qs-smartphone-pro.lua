if not UseBridge('phone', 'qs-smartphone-pro') then return end

---@param citizenId string
---@return string?
function GetPhoneNumber(citizenId)
    return exports['qs-smartphone-pro']:GetPhoneNumberFromIdentifier(citizenId, true)
end
