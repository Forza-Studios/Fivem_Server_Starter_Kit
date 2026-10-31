if not UseBridge('phone', 'gksphone') then return end

---@param citizenId string
---@return string?
function GetPhoneNumber(citizenId)
    local phoneId = MySQL.scalar.await('SELECT unique_id FROM gksphone_settings WHERE setup_owner = ?', { citizenId })
    if not phoneId then return nil end
    return MySQL.scalar.await('SELECT phone_number FROM gksphone_esim WHERE phone_id = ? AND is_active = 1', { phoneId })
end
