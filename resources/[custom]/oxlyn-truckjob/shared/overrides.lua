

-- =====================================================================
-- shared/overrides.lua
--
-- This is your customization layer. Every function here is OPTIONAL —
-- leave it as `nil` to keep the script's default behavior. When defined,
-- the matching hook is called instead of the built-in path.
--
-- All functions below run on both client and server unless specified
-- otherwise. Use `IsDuplicityVersion()` if you need to branch.
-- =====================================================================

Overrides = Overrides or {}

-- =====================================================================
-- 1) Notification system
--   Replace the native NUI toast with whatever notification system your
--   server uses (qb-notify, esx_notify, mythic_notify, okok, lib.notify…).
--
--   Signature on client:  (nil,    msg, type, duration)
--   Signature on server:  (source, msg, type, duration)
--   `type` is one of: 'info' | 'success' | 'warning' | 'error'
-- =====================================================================
-- Overrides.Notify = function(target, msg, ntype, duration)
--     if IsDuplicityVersion() then
--         -- server: forward to a specific client or use a server-side notify
--         TriggerClientEvent('myNotify:show', target, msg, ntype, duration)
--     else
--         -- client: show locally
--         exports['mythic_notify']:DoHudText(ntype or 'inform', msg)
--     end
-- end

-- =====================================================================
-- 2) Driver-license check
--   By default the script looks for `Config.LicenseItem` in the player's
--   inventory (when Config.UseLicense is true). Override this to check
--   QB metadata, ESX licenses table, or anything custom.
--
--   Signature: (source) -> boolean       -- server only
-- =====================================================================
-- Overrides.HasDriverLicense = function(source)
--     -- QB metadata example:
--     local p = exports['qb-core']:GetCoreObject().Functions.GetPlayer(source)
--     return p and p.PlayerData.metadata.licences
--              and p.PlayerData.metadata.licences.driver == true
-- end

-- =====================================================================
-- 3) Progress bar during loading / unloading
--   Replace the native NUI progress card with ox_lib's progress UI or
--   any other circular/linear progress system.
--
--   Signature: (label, durationMs) -> boolean   -- client only
--   Return `true` once the progress is done. Return `false` if the player
--   cancelled it (the script will then abort the load/unload).
-- =====================================================================
-- Overrides.Progress = function(label, durationMs)
--     return lib.progressBar({
--         label        = label,
--         duration     = durationMs,
--         useWhileDead = false,
--         canCancel    = true,
--         disable      = { car = true, move = true, combat = true },
--     })
-- end

-- =====================================================================
-- 4) Permission check (admin commands)
--   By default uses ace permission OR framework groups. Override this to
--   use your own permission system.
--
--   Signature: (source) -> boolean       -- server only
-- =====================================================================
-- Overrides.IsAdmin = function(source)
--     return exports['my-perms']:hasPermission(source, 'truck.admin')
-- end

-- =====================================================================
-- 5) Reward computation
--   Override the entire pay/XP calculation. Receive the route, the
--   delivery payload, and the auto-computed defaults; return a table
--   with `pay` and `xp`. Return `nil` to fall back to defaults.
--
--   Signature: (route, payload, defaults) -> { pay = number, xp = number }
--                                              | nil      -- server only
-- =====================================================================
-- Overrides.ComputeReward = function(route, payload, defaults)
--     -- Example: 2x pay on weekends
--     if os.date('*t').wday == 1 or os.date('*t').wday == 7 then
--         return { pay = defaults.pay * 2, xp = defaults.xp }
--     end
--     return nil
-- end

-- =====================================================================
-- 6) After-job hook
--   Called after a successful delivery (server side). Useful for logs,
--   webhooks, achievements, or feeding other resources.
--
--   Signature: (source, identifier, route, result)   -- server only
--     result = { pay, xp, perfect, distanceM, elapsed, bonusApplied }
-- =====================================================================
-- Overrides.OnDeliveryComplete = function(src, identifier, route, result)
--     PerformHttpRequest('https://discord.com/api/webhooks/...', function() end,
--         'POST', json.encode({ content = ('%s delivered %s for $%s'):format(
--             GetPlayerName(src), route.label, result.pay) }),
--         { ['Content-Type'] = 'application/json' })
-- end

-- =====================================================================
-- 7) Vehicle keys
--   Config.VehicleKeys already covers qbx_vehiclekeys, qb-vehiclekeys,
--   MrNewbVehicleKeys, wasabi_carlock, Renewed-Vehiclekeys, qs-vehiclekeys,
--   ti_vehicleKeys, vehicles_keys, cd_garage and okokGarage. Use these
--   hooks only for a key system that is not on that list.
--
--   Return `true` to say "handled" — the built-in path is then skipped.
--   Return nil/false to let the built-in path run as well.
--
--   Client:  (vehicle, plate, model) -> boolean
--   Server:  (source, vehicle, plate, model) -> boolean
--            `vehicle` is 0 when the network id could not be resolved.
-- =====================================================================
-- Overrides.GiveVehicleKeys = function(vehicle, plate, model)
--     exports['my-keys']:AddKey(plate)
--     return true
-- end

-- Overrides.RemoveVehicleKeys = function(vehicle, plate, model)
--     exports['my-keys']:RemoveKey(plate)
--     return true
-- end

-- Overrides.GiveVehicleKeysServer = function(src, vehicle, plate, model)
--     TriggerClientEvent('my-keys:add', src, plate)
--     return true
-- end

-- Overrides.RemoveVehicleKeysServer = function(src, vehicle, plate, model)
--     TriggerClientEvent('my-keys:remove', src, plate)
--     return true
-- end

