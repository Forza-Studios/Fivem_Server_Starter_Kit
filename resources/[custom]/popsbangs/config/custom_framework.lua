
-- ===========================================================================
--  config/custom_framework.lua — your own framework
-- ===========================================================================
--
--  Only needed when your framework is NOT ESX, QBCore or Qbox, and you want
--  one of the two things a framework is used for here:
--
--    1. job-locked items   Config.Items.jobs in config/config.lua
--    2. framework notices  Config.UI.notifications = 'framework'
--
--  Everything else — the pops and bangs, the anti-lag, the commands, the
--  valve remote, the persistence — works with no framework at all. Setting
--  `Config.Framework = 'standalone'` is a complete, supported setup, so do
--  not fill this in unless you need jobs or your own notification style.
--
--  To use this file:
--    1. config/config.lua →  Config.Framework = 'custom'
--    2. fill in what you need; leave the rest as nil.
-- ===========================================================================

Config.FrameworkCustom = {

    -- SERVER. The player's job name, used only by Config.Items.jobs.
    -- Return nil when the player has none; the second and third values are
    -- optional (grade, on duty).
    GetJob = function(src)
        -- local player = exports['my-framework']:GetPlayer(src)
        -- return player and player.job, player and player.grade or 0, true
        return nil
    end,

    -- CLIENT. Show a message in your framework's own style. Only called
    -- when Config.UI.notifications = 'framework'.
    -- kind is one of: 'info', 'success', 'warning', 'error'.
    Notify = function(message, kind)
        -- TriggerEvent('my-framework:notify', message, kind)
        return false -- false falls back to the GTA feed, so nothing is lost
    end,

    -- SERVER. Make an item usable, if your framework (and not your
    -- inventory) is what registers usable items. Return true when it was
    -- registered. Leave it alone if config/custom_inventory.lua handles it.
    --
    -- `cb` takes the player's server id and expects nothing back.
    RegisterUsableItem = function(item, cb)
        -- exports['my-framework']:RegisterUsableItem(item, function(src) cb(src) end)
        -- return true
        return false
    end
}
--fivevaultsD7OnfBTopVx : https://discord.gg/fivevault
--fivevaultsWnOn1qToptJ : https://discord.gg/fivevault
--fivevault-lXOnAqTopYw : https://discord.gg/fivevault
--fivevaultrNOnsUTopBh : https://discord.gg/fivevault
--fivevault5LOnTJTopkt : https://discord.gg/fivevault
