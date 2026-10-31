if not UseBridge('phone', 'yseries') then return end

---@param citizenId string
---@return string?
function GetPhoneNumber(citizenId)
    local imei = MySQL.scalar.await('SELECT phone_imei FROM yphone_holders WHERE holder_identifier = ? LIMIT 1', { citizenId })
    if not imei then return nil end
    return MySQL.scalar.await('SELECT sim_number FROM yphone_sim_cards WHERE phone_imei = ? LIMIT 1', { imei })
end
