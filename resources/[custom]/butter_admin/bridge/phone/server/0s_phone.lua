if not UseBridge('phone', '0s_phone') then return end

---@param citizenId string
---@return string?
function GetPhoneNumber(citizenId)
    return exports['0s_phone']:getPhoneNumberByIdentifier(citizenId)
end
