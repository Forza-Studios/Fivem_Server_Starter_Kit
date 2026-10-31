if not UseBridge('framework', 'qbx_core') then return end

---@return string?
function GetCharacterName()
    local charinfo = exports.qbx_core:GetPlayerData().charinfo
    if not charinfo then return nil end
    return ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerEvent('butter_admin:client:playerLoaded')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerEvent('butter_admin:client:playerUnloaded')
end)
