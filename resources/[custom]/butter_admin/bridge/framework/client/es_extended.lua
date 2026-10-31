if not UseBridge('framework', 'es_extended') then return end

local ESX = exports['es_extended']:getSharedObject()

---@return string?
function GetCharacterName()
    local playerData = ESX.GetPlayerData()
    if not playerData.firstName then return nil end
    return ('%s %s'):format(playerData.firstName, playerData.lastName or '')
end

RegisterNetEvent('esx:playerLoaded', function()
    TriggerEvent('butter_admin:client:playerLoaded')
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    TriggerEvent('butter_admin:client:playerUnloaded')
end)
