if not UseBridge('phone', 'high_phone') then return end

---@param _ string citizen ID (unused, high_phone looks numbers up by source)
---@param source? number
---@return string?
function GetPhoneNumber(_, source)
    if not source then return nil end
    return exports.high_phone:getPlayerPhoneNumber(source)
end
