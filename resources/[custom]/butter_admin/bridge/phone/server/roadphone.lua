if not UseBridge('phone', 'roadphone') then return end

---@param citizenId string
---@return string?
function GetPhoneNumber(citizenId)
    return exports['roadphone']:getNumberFromIdentifier(citizenId)
end
