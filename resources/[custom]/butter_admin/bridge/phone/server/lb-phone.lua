if not UseBridge('phone', 'lb-phone') then return end

---@param citizenId string
---@return string?
function GetPhoneNumber(citizenId)
    return MySQL.scalar.await('SELECT phone_number FROM phone_phones WHERE owner_id = ? LIMIT 1', { citizenId })
end
