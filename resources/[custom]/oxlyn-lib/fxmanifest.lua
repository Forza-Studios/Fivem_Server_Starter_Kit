

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'oxlyn-lib'
description 'OXLYN LIB - the shared core every OXLYN Series resource connects to. Start it before any OXLYN script.'
author      'Oxlyn'
version     '1.0.0'

shared_scripts {
    'shared/crypto.lua',
    'shared/protocol.lua',
}

client_scripts {
    'client/secret.lua',
    'client/main.lua',
}

server_scripts {
    'server/secret.lua',
    'server/main.lua',
}

-- ═══════════════════════════════════════════════════════════════════════════
--  OXLYN LIB
--
--  There is nothing to configure in this resource. Keep the folder named
--  oxlyn-lib and start it before your OXLYN scripts:
--
--      ensure oxlyn-lib
--      ensure oxlyn-<script>
--
--  Optional convar (server.cfg):  set oxlyn_lib_debug 1   (verbose console)
--  Console command:               oxlynlib                 (connected scripts)
--
--  Every script file of this resource is protected. Only the documentation
--  below stays readable.
-- ═══════════════════════════════════════════════════════════════════════════
escrow_ignore {
    '*.md',
}

dependency '/assetpacks'

