
-- ===========================================================================
--  config/exhausts.lua — the exhausts and the colour of their flames
-- ===========================================================================
--
--  Each entry is one exhaust a player can fit from the workshop (the items
--  of section 9 of config/config.lua). Fitting one puts the exhaust that was
--  on the car back into the player's inventory.
--
--  Fields
--    item     the item name in your inventory. The definitions to paste are
--             in setup/ and the images in setup/images/ (one PNG per item,
--             named exactly like the item).
--    label    the name shown on the screen. Translating it: put the text in
--             locales/<language>.lua under the same key and it is picked up.
--    order    position in the workshop list (0 first).
--    colour   the colour of the flames that come out of it, RGB 0-1. The
--             stock exhaust has none and burns by the heat of the pipe.
--    soot     adds black smoke to every report (the black exhaust).
--
--  Adding one of your own: copy a line, give it a new key, a new item name,
--  the next `order`, and an item definition + image in your inventory. The
--  flame colour is yours to choose — nothing else has to change.
--
--  An example, switched off, ready to copy:
--
--    titanium = { item = 'popsbangs_exhaust_titanium', label = 'Titanium',
--                 order = 15, colour = { 0.72, 0.78, 0.86 }, enabled = false },
-- ===========================================================================

Config.Exhausts = {
    stock     = { item = 'popsbangs_exhaust_stock',     label = 'Stainless steel', order = 0 },
    cobalt    = { item = 'popsbangs_exhaust_cobalt',    label = 'Cobalt blue',     order = 1,  colour = { 0.20, 0.42, 1.00 } },
    cyan      = { item = 'popsbangs_exhaust_cyan',      label = 'Cyan',            order = 2,  colour = { 0.15, 0.85, 1.00 } },
    turquoise = { item = 'popsbangs_exhaust_turquoise', label = 'Turquoise',       order = 3,  colour = { 0.15, 0.90, 0.72 } },
    emerald   = { item = 'popsbangs_exhaust_emerald',   label = 'Emerald green',   order = 4,  colour = { 0.12, 0.85, 0.32 } },
    lime      = { item = 'popsbangs_exhaust_lime',      label = 'Lime green',      order = 5,  colour = { 0.62, 1.00, 0.18 } },
    ruby      = { item = 'popsbangs_exhaust_ruby',      label = 'Ruby red',        order = 6,  colour = { 1.00, 0.10, 0.14 } },
    orange    = { item = 'popsbangs_exhaust_orange',    label = 'Orange',          order = 7,  colour = { 1.00, 0.48, 0.08 } },
    yellow    = { item = 'popsbangs_exhaust_yellow',    label = 'Yellow',          order = 8,  colour = { 1.00, 0.88, 0.16 } },
    gold      = { item = 'popsbangs_exhaust_gold',      label = 'Gold',            order = 9,  colour = { 1.00, 0.76, 0.28 } },
    copper    = { item = 'popsbangs_exhaust_copper',    label = 'Copper',          order = 10, colour = { 0.95, 0.46, 0.22 } },
    amethyst  = { item = 'popsbangs_exhaust_amethyst',  label = 'Amethyst purple', order = 11, colour = { 0.66, 0.28, 1.00 } },
    magenta   = { item = 'popsbangs_exhaust_magenta',   label = 'Magenta pink',    order = 12, colour = { 1.00, 0.22, 0.72 } },
    pearl     = { item = 'popsbangs_exhaust_pearl',     label = 'Pearl white',     order = 13, colour = { 0.96, 0.96, 1.00 } },
    -- A flame cannot be black: the black exhaust burns a deep, sooty red.
    black     = { item = 'popsbangs_exhaust_black',     label = 'Black',           order = 14, colour = { 0.62, 0.14, 0.10 }, soot = true }
}
--fivevault_$uOn70TopPV : https://discord.gg/fivevault
--fivevault_#tOnGOTopFF : https://discord.gg/fivevault
--fivevault-fJOnAtTopb@ : https://discord.gg/fivevault
--fivevault-9QOnH1Top8z : https://discord.gg/fivevault
--fivevault-FWOnoJTop3F : https://discord.gg/fivevault
