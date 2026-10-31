fx_version 'cerulean'
game 'gta5'

name 'codem-supreme-hud'
author 'Codem'
version '1.6'
lua54 'yes'
description 'A comprehensive and customizable HUD for FiveM servers, featuring vehicle systems, player vitals, chat channels, and more.'

-- Shared config and constants
shared_scripts {
    'shared/constants.lua',  -- Load constants first
    'shared/locales/*.lua',  -- Load locale files (init.lua, en.lua, tr.lua, es.lua)
    'shared/*.lua'
}

-- Client scripts
client_scripts {
    -- HUD core (must load first - defines NuiMessage, NuiReady, cache)
    'client/utils/rpc.lua',
    'client/utils/positioning.lua',
    'client/core.lua',
    'client/minimap.lua',
    -- Framework bridges
    'modules/framework/qb/client/*.lua',
    'modules/framework/esx/client/*.lua',
    'modules/framework/qbox/client/*.lua',
    'modules/framework/vrp/client/*.lua',
    -- Integration modules (depend on NuiMessage from core.lua)
    'modules/inventory/client/*.lua',
    'modules/voice/client/*.lua',
    'modules/society/client.lua',
    'client/settings.lua',
    -- HUD modules (player-related threads)
    'client/hud/vitals.lua',
    'client/hud/stress.lua',
    'client/hud/location.lua',
    'client/hud/timeweather.lua',
    'client/hud/ammo.lua',
    'client/hud/pausemenu.lua',
    'client/hud/focus.lua',
    'client/hud/marker3d.lua',
    'client/hud/textui.lua',
    'client/hud/hungersound.lua',
    -- Vehicle modules
    'client/vehicle/state.lua',
    'client/vehicle/speedometer.lua',
    'client/vehicle/lights.lua',
    'client/vehicle/limiter.lua',
    'client/vehicle/transmission.lua',
    'client/vehicle/mods.lua',
    -- Vehicle features (refactored from features.lua)
    'client/vehicle/nitro.lua',
    'client/vehicle/seatbelt.lua',
    'client/vehicle/signals.lua',
    'client/vehicle/siren.lua',
    'client/vehicle/controls.lua',
    -- Optional features
    'client/features/fastnav.lua',
    'client/features/helinav.lua',
    'client/features/planenav.lua',
    'client/features/voiceassistant.lua',
    'client/features/music.lua',
    'client/features/playlists.lua',
    'client/features/progressbar.lua',
    'client/features/boat.lua',
    'client/features/boatnav.lua',
    'client/features/flir.lua',
    'client/features/camera-accessibility.lua',
}

-- Server scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@vrp/lib/utils.lua',
    'server/config.lua',
    -- Framework bridges
    'modules/framework/qb/server/*.lua',
    'modules/framework/esx/server/*.lua',
    'modules/framework/qbox/server/*.lua',
    'modules/framework/vrp/server/framework.lua',
    -- Integration modules
    'modules/society/custom.lua',
    'modules/inventory/server/inventory.lua',
    'modules/inventory/server/stress.lua',
    -- Server utilities
    'server/utils/rpc.lua',
    'server/utils/asql.lua',
    -- Server core
    'server/core/main.lua',
    -- Server vehicle modules
    'server/vehicle/mods.lua',
    'server/vehicle/features.lua',
    -- Server optional modules
    'server/modules/voiceassistant.lua',
    'server/modules/presets.lua',
    'server/modules/playlists.lua',
    'server/vehicle/music.lua',
}

-- NUI
ui_page 'html/index.html'

files {
    'html/*',
    'html/**/*',
    'sql/*.sql',
    'shared/postals.json',
    'shared/data/fastnav-locations.json',
    'shared/data/helinav-locations.json',
    'shared/data/planenav-locations.json',
    'shared/data/boatnav-locations.json',
    'shared/data/locales/*.json',
}

-- Escrow ignore (editable by users)
escrow_ignore {
    -- Config files
    'shared/*.lua',
    'shared/locales/*.lua',
    'server/config.lua',

    -- Custom integrations
    'modules/society/client.lua',
    'modules/society/custom.lua',

    -- Framework bridges
    'modules/framework/qb/client/*.lua',
    'modules/framework/qb/server/*.lua',
    'modules/framework/esx/client/*.lua',
    'modules/framework/esx/server/*.lua',
    'modules/framework/qbox/client/*.lua',
    'modules/framework/qbox/server/*.lua',
    'modules/framework/vrp/client/*.lua',
    'modules/framework/vrp/server/*.lua',

    -- Integration modules
    'modules/inventory/client/*.lua',
    'modules/inventory/server/*.lua',
    'modules/voice/client/*.lua',

    -- Data files
    'shared/data/*.json',

    -- HUD modules (editable)
    'client/hud/*.lua',
    -- Vehicle systems (editable)
    'client/vehicle/*.lua',
    'server/vehicle/*.lua',
    -- Optional features
    'client/features/*.lua',
    'server/modules/*.lua',
}

dependency '/assetpacks'
