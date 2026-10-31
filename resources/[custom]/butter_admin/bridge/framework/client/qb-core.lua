if not UseBridge('framework', 'qb-core') then return end

local QBCore = exports['qb-core']:GetCoreObject()

---@return string?
function GetCharacterName()
    local charinfo = QBCore.Functions.GetPlayerData().charinfo
    if not charinfo then return nil end
    return ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerEvent('butter_admin:client:playerLoaded')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerEvent('butter_admin:client:playerUnloaded')
end)
