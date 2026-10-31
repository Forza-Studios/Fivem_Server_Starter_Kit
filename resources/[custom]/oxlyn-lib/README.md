# OXLYN LIB

The shared core of the OXLYN Series. Every OXLYN script that depends on it connects to it when it starts and keeps verifying the link while it runs. **Version 1.0.0** · ESX / QBCore / Qbox / standalone (it does not touch the framework).

There is nothing to configure. Install it once, start it first, forget about it.

## Installation

1. Extract the zip into your `resources` folder. **Keep the folder named `oxlyn-lib`** - your OXLYN scripts look for it by that name.
2. In `server.cfg`, start it **before** every OXLYN script:

```cfg
ensure oxlyn-lib
ensure oxlyn-garage
ensure oxlyn-cardcollection
# ...the rest of your OXLYN scripts
```

3. Restart the server. The console prints `[oxlyn-lib] v1.0.0 ready` followed by one `connected:` line per OXLYN script.

OXLYN scripts declare `oxlyn-lib` as a dependency, so the server refuses to start them while it is missing, and they stop themselves if it is stopped for more than a few seconds. A plain `restart oxlyn-lib` is fine: the scripts reconnect on their own.

## Console

| What | Where | Does |
|---|---|---|
| `oxlynlib` | server console, or a player with ACE `command.oxlynlib` | lists every connected OXLYN script with its product id, version and when it was last verified |
| `oxlynlib` | F8 console (client) | the same list, from the player's side |
| `set oxlyn_lib_debug 1` | `server.cfg` | verbose log: every verification, every rejected handshake |

## Exports

For your own admin tooling. Both sides.

```lua
-- { [resourceName] = { product = 'oxlyn-garage', version = '1.2.1', since = <unix time>, lastSeen = <unix time> } }
local connected = exports['oxlyn-lib']:GetProducts()

-- true while the resource is connected
local ok = exports['oxlyn-lib']:IsConnected('oxlyn-garage')
```

Each OXLYN script also fires a local event `oxlyn-lib:lost` (`product`, `reason`) when its link drops.

## FAQ

**`[oxlyn-garage] oxlyn-lib: NOT connected - oxlyn-lib is not started`** - the script started before `oxlyn-lib`. Fix the order in `server.cfg`. If `oxlyn-lib` comes up later, the script asks it for a restart and connects on its own.

**`oxlyn-lib did not come back - stopping oxlyn-garage`** - `oxlyn-lib` was stopped and stayed stopped. Start it, then `ensure` the scripts again.

**`the running oxlyn-lib is not genuine`** - another resource is using the name `oxlyn-lib`, or the folder has been altered. Reinstall this resource from your Keymaster download.

**I renamed the folder.** Rename it back to `oxlyn-lib`. The scripts call it by that exact name, and the resource itself warns in the console when the name differs.

**Do I need it with an open-source edition of a script?** Yes. Both editions of every OXLYN script carry a small protected connector (`lib/`) that links to this resource; the open-source edition is the whole script in plain text except that connector.

**Is anything of my server sent anywhere?** No. The link is local to your server: resource to resource, no HTTP, no accounts, no telemetry.

## Editions

Single edition. Every script file is protected by the Cfx escrow; this README and the CHANGELOG are the only readable files, because there is nothing to edit.
