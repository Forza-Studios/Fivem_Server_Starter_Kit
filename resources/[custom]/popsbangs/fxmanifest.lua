

fx_version 'cerulean'
game 'gta5'

name 'oxlyn-popsbangs'
author 'OXLYN Software'
description 'Advanced Anti-Lag Pops & Bangs System - three-stage exhaust pops and bangs, anti-lag, two-step, layered coloured flames and spatial audio, with a workshop of items for ESX, QBCore, Qbox and standalone'
version '5.0.2'

-- OXLYN LIB (free, delivered with your OXLYN scripts): start it BEFORE this
-- resource in server.cfg. Both editions connect to it and neither runs
-- without it.
dependencies {
    'oxlyn-lib',
    '/onesync',
}

-- ---------------------------------------------------------------------------
-- Settings and texts. config/config.lua comes first: it creates the Config
-- table the other three fill in. Every language is loaded and Config.Locale
-- picks one at runtime, so switching language needs no manifest change.
-- ---------------------------------------------------------------------------
shared_scripts {
    'config/config.lua',
    'config/exhausts.lua',
    'config/flames.lua',
    'config/audio.lua',
    'config/custom_inventory.lua',
    'config/custom_framework.lua',
    'locales/en.lua',
    'locales/pt.lua',
    'locales/br.lua',
    'locales/es.lua',
    'locales/fr.lua',
    'locales/de.lua',
    'locales/pl.lua',
    'locales/lt.lua',
    'shared/locale.lua',
    'shared/protocol.lua',
    'shared/valve.lua',
    'shared/combustion.lua',
    'shared/antilag.lua',
}

client_scripts {
    'lib/client.lua',          -- OXLYN LIB connector (protected in every edition)
    'bridge/notify.lua',       -- framework notifications, before anything notifies
    'client/telemetry.lua',
    'client/flame-assets.lua',
    'client/flames.lua',
    'client/main.lua',
    'client/items.lua',
    'client/valve.lua',
    'client/engine-valve.lua',
    'client/mixer-diagnostic.lua',
}

server_scripts {
    'lib/server.lua',          -- OXLYN LIB connector (protected in every edition)
    'bridge/framework.lua',    -- ESX / QBCore / Qbox / standalone
    'bridge/inventory.lua',    -- every supported inventory
    'server/main.lua',
    'server/items.lua',
    'server/valve.lua',
}

ui_page 'html/index.html'
-- The page carries the audio engine, so it is created as soon as the
-- resource starts: a late page is one way to miss the first reports.
ui_page_preload 'yes'

files {
    'html/index.html',
    'html/als-pattern.js',
    'html/audio.js',
    'html/workshop.js',
    'html/workshop.css',
    'html/notify.js',
    'html/notify.css',
    'html/valve.js',
    'html/valve.css',
    'html/img/*',
    'html/sounds/*',
    'audio/oxlyn_exhaust_mix.dat15.rel',
    'audio/oxlyn_valve_probe.dat15.rel',
}

-- Native engine/startup audio for the exhaust valve (Config.Valve.engine).
data_file 'AUDIO_DYNAMIXDATA' 'audio/oxlyn_exhaust_mix.dat'
data_file 'AUDIO_DYNAMIXDATA' 'audio/oxlyn_valve_probe.dat'

-- ===========================================================================
--  ESCROW EDITION
--
--  The Cfx portal encrypts every file that is NOT named below. What is named
--  here is exactly what a server owner is meant to change:
--
--    config/*.lua    every setting, in twelve commented sections
--    locales/*.lua   every text a player reads, in eight languages
--
--  Everything else of the resource's own Lua — client/, server/items.lua,
--  server/valve.lua, shared/, bridge/ — ships encrypted. The Open Source
--  edition of this product is the one that ships them readable.
--
--  Three files are protected in BOTH editions and are listed here so the
--  escrow ships them as they are instead of processing them a second time:
--
--    lib/client.lua, lib/server.lua   the OXLYN LIB connector
--    server/main.lua                  the server core
--
--  Do not edit or remove them: without them, or without oxlyn-lib running,
--  the resource stops at its first line.
--
--  html/, audio/, stream/ and setup/ are named for a different reason: an
--  encrypted .ypt, .wav, .rel or .png does not load and fails SILENTLY —
--  no flames, no sound, no item icons, and no error to tell you why.
-- ===========================================================================
escrow_ignore {
    -- protected in every edition, shipped as-is (not re-processed by Cfx):
    'lib/client.lua',
    'lib/server.lua',
    'server/main.lua',
    -- what the server owner may read and edit:
    'config/*.lua',
    'locales/*.lua',
    -- assets: must stay readable to load at all
    'stream/*',
    'stream/**/*',
    'html/*',
    'html/**/*',
    'audio/*',
    -- item definitions to paste into your inventory, and their images
    'setup/*',
    'setup/**/*',
    -- documents
    '*.md',
}
