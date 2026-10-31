if not UseBridge('phone', 'sd-phone') then return end

---@param citizenId string
---@return string?
function GetPhoneNumber(citizenId)
    local ok, number = pcall(function()
        return exports['sd-phone']:getPhoneNumberByIdentifier(citizenId)
    end)
    return ok and number or nil
end
