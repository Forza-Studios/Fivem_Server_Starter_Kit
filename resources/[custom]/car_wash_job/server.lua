-- Per-spot cooldown. A spot is stored by key ("x,y") with the os.time() it unlocks at.
local FILE = 'cooldowns.json'
local cooldowns = {}

local function save()
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(cooldowns), -1)
end

local function load()
    local raw = LoadResourceFile(GetCurrentResourceName(), FILE)
    cooldowns = raw and json.decode(raw) or {}
    if type(cooldowns) ~= 'table' then cooldowns = {} end
end

local function activeKeys()
    local now = os.time()
    local keys, changed = {}, false

    for key, expires in pairs(cooldowns) do
        if expires > now then
            keys[#keys + 1] = key
        else
            cooldowns[key] = nil
            changed = true
        end
    end

    if changed then save() end
    return keys
end

load()

RegisterNetEvent('car_wash_job:server:requestCooldowns', function()
    TriggerClientEvent('car_wash_job:client:cooldowns', source, activeKeys())
end)

RegisterNetEvent('car_wash_job:server:completeSpot', function(key)
    if type(key) ~= 'string' or #key > 32 then return end
    -- Only keys that belong to a configured spot are accepted
    if not Config.SpotKeys[key] then return end

    if (cooldowns[key] or 0) > os.time() then return end

    cooldowns[key] = os.time() + (Config.Cooldown or 86400)
    save()

    -- Pay the player (once per spot per cooldown, so the event can't be farmed)
    local payout = Config.Payout or {}
    local amount = payout.amount or 0
    if amount > 0 then
        exports.qbx_core:AddMoney(source, payout.account or 'cash', amount, 'car-wash-job')
    end
end)
