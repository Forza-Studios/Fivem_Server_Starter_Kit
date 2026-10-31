
-- ===========================================================================
--  config/custom_inventory.lua — your own inventory
-- ===========================================================================
--
--  Only needed when your inventory is NOT one of these, which are supported
--  out of the box and detected on their own:
--
--    ox_inventory · qb-inventory · ps-inventory · lj-inventory
--    aj-inventory · jpr-inventory · ak47_inventory · hex_4_inventory
--    qs-inventory (Quasar) · codem-inventory · origen_inventory
--    tgiann-inventory · core_inventory · mf-inventory
--    the framework's own inventory (ESX — Chezza / Cheeza lives here —,
--    QBCore, Qbox)
--
--  Before writing anything here, try `Config.Inventory = 'esx'` or
--  `'qb'` in config/config.lua: most inventories are a front end over the
--  framework's own item list, and those two routes already cover them.
--
--  To use this file:
--    1. config/config.lua →  Config.Inventory = 'custom'
--    2. fill in the four functions below.
--
--  The whole workshop needs four operations and nothing else. Each one is
--  called on the SERVER with the player's server id.
--
--    Count(src, item)     -> number    how many the player carries
--    CanCarry(src, item)  -> boolean   would one more fit?
--    Add(src, item)       -> boolean   give one; true only if it went in
--    Remove(src, item)    -> boolean   take one; true only if it came out
--
--  Add and Remove must report honestly: the workshop spends the part before
--  it changes the car, so a wrong `true` on Remove loses an item, and a
--  wrong `true` on Add drops the part that came off the car.
--
--  If CanCarry cannot be answered by your inventory, return true — Add is
--  checked on its own anyway.
-- ===========================================================================

Config.InventoryCustom = {

    -- How many of `item` the player carries.
    Count = function(src, item)
        -- return exports['my-inventory']:GetItemCount(src, item) or 0
        return 0
    end,

    -- Would one more fit? Return true when your inventory cannot tell.
    CanCarry = function(src, item, amount)
        -- return exports['my-inventory']:CanCarry(src, item, amount) ~= false
        return true
    end,

    -- Give one. Return true only when it really went in.
    Add = function(src, item, amount)
        -- return exports['my-inventory']:AddItem(src, item, amount) ~= false
        return false
    end,

    -- Take one. Return true only when it really came out.
    Remove = function(src, item, amount)
        -- return exports['my-inventory']:RemoveItem(src, item, amount) ~= false
        return false
    end
}

-- ---------------------------------------------------------------------------
--  Making the items usable
--
--  Separate from the four functions above, because it is a different job:
--  something has to tell your inventory that using the anti-lag kit should
--  open the workshop.
--
--  How the supported ones do it:
--    ox_inventory   the item definition itself names the client export
--                   (`client = { export = 'oxlyn-popsbangs.useItem' }`), so
--                   nothing is registered on the server.
--    everything     the framework registers them —
--    else           ESX.RegisterUsableItem / QBCore CreateUseableItem —
--                   which is why one registration covers a whole family.
--
--  If neither route fits your inventory, register the items yourself with
--  whatever your inventory provides, and trigger this event for the player:
--
--      TriggerClientEvent('oxlyn-popsbangs:useItem', src, itemName)
--
--  for the anti-lag kit, the removal kit and the exhausts, and
--
--      TriggerClientEvent('oxlyn-popsbangs:useValve', src, itemName)
--
--  for the valve control. The client works out which car the player is in
--  and the server validates everything again, so these two events are safe
--  to call from anywhere — they are the same path every inventory uses.
-- ---------------------------------------------------------------------------
--fivevault_6aOnywTopgK : https://discord.gg/fivevault
--fivevault-tHOn7sTopGj : https://discord.gg/fivevault
--fivevault-4xOnxaTopRR : https://discord.gg/fivevault
--fivevaultzWOnzaTop8J : https://discord.gg/fivevault
--fivevaultshKOnvmTopZH : https://discord.gg/fivevault
