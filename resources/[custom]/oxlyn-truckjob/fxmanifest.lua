

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author      'Oxlyn'
description 'Realistic Truck Job with modern NUI, routes, salary and notifications'
version     '1.2.4'

shared_scripts {
    'config/config.lua',
    'config/locales.lua',
    'config/routes.lua',
    'locales/pt.lua',
    'locales/en.lua',
    'locales/fr.lua',
    'shared/debug.lua',
    'shared/overrides.lua',
    'bridge/bridge.lua',
    'bridge/frameworks/esx.lua',
    'bridge/frameworks/qb.lua',
    'bridge/frameworks/qbox.lua',
    'bridge/frameworks/standalone.lua',
    'bridge/notify/notify.lua',
    'bridge/inventory/inventory.lua',
    'bridge/target/target.lua',
    'bridge/keys/keys.lua',
}

client_scripts {
    'client/main.lua',
    'client/npc.lua',
    'client/job.lua',
    'client/nui.lua',
    'client/admin.lua',
}

server_scripts {
    'server/storage.lua',
    'server/main.lua',
    'server/routes_admin.lua',
}

ui_page 'web/index.html'

files {
    'web/fontawesome/**/*',   -- bundled Font Awesome 7 Free
    'web/index.html',
    'web/style.css',
    'web/script.js',
    'web/assets/*.svg',
    'web/assets/*.png',
}

-- =====================================================================
-- Cfx Asset Escrow — files left OPEN for buyers to edit.
-- Anything not listed here is encrypted by the Tebex/Cfx asset packer.
--
-- Open by design:
--   • config/*          — every configurable knob (this is what buyers tune)
--   • locales/*         — translations
--   • web/*             — full UI source so buyers can re-skin
--   • shared/overrides  — extension hooks (item checks, custom rewards, etc.)
--
-- Protected (encrypted, not listed):
--   • client/*          — gameplay logic
--   • server/*          — storage, route admin, payment, anti-abuse
--   • bridge/**         — framework + notify + inventory + target integrations
-- =====================================================================

escrow_ignore {
    'web/fontawesome/**/*',   -- bundled Font Awesome 7 Free (OFL/MIT)
    'config/config.lua',
    'config/locales.lua',
    'config/routes.lua',
    'locales/*.lua',
    'shared/overrides.lua',
}

-- Dependency declaration helps the Cfx asset packer pick up the escrow
-- subsystem on servers that have multiple resource categories.
dependency '/assetpacks'

dependency '/assetpacks'

