if not UseBridge('phone', 'okokPhone') then return end

---@param citizenId string
---@return string?
function GetPhoneNumber(citizenId)
    return MySQL.scalar.await('SELECT phone_number FROM okokphone_phones WHERE owner = ? ORDER BY created_at DESC LIMIT 1', { citizenId })
end
