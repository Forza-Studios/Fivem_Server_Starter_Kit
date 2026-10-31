# butter_admin

> **butter_admin is finally available for free on [GitHub](https://github.com/kavyasingh8/butter_admin)!**

Admin menu for FiveM with a React UI, rank based access control, player reports, bans, audit logs, a database browser and bridges for the common Qbox, QBCore and ESX resources.

**Authors:** ButterChilly & Guardian
**Version:** 1.0.3
**Game:** GTA V, fx_version `cerulean`, Lua 5.4
**Download:** [github.com/kavyasingh8/butter_admin](https://github.com/kavyasingh8/butter_admin)

> AI tools were used to help with parts of this resource, and everything was reviewed and tested by hand.

## Requirements

| Resource | Why |
|----------|-----|
| [ox_lib](https://github.com/overextended/ox_lib) | Callbacks, commands, locales, notifications, menus |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |
| `qbx_core`, `qb-core` or `es_extended` | Player data, jobs, gangs, money |

Optional resources unlock more features (inventory, fuel, keys, clothing, ambulance, weather, phone, garages, housing, animations). See [Bridges](#bridges).

## Installation

1. Put the folder in your resources, for example `resources/[New Butter]/butter_admin`.
2. Start it after its dependencies and your framework:

   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure qbx_core        # or qb-core / es_extended
   ensure ox_inventory    # and any other bridged resources
   ensure butter_admin
   ```

3. Start the server once. The `admin_*` tables are created automatically and the `superadmin` and `admin` ranks are seeded.
4. Give yourself access, using any one of these:
   - Qbox: the `god` or `admin` framework permission.
   - QBCore: the ace `butter_admin.admin`, for example `add_ace group.admin butter_admin.admin allow`.
   - ESX: the `admin`, `superadmin` or `god` group.
   - SQL, then use Access Control for everyone else:

     ```sql
     INSERT INTO admin_staff (identifier, rank_id, is_temp, expires)
     VALUES ('license:YOUR_LICENSE', 'superadmin', 0, NULL);
     ```

5. Press **INSERT** (or run `/menuopen`) in game.

Each bridge loads only when its resource is started, so there is nothing to configure. On start the console lists what loaded (server bridges in the server console, client bridges in F8), for example:

```text
[butter_admin] [INFO] Loaded server bridges:
[butter_admin] [INFO]   framework    qbx_core
[butter_admin] [INFO]   garages      qbx_garages
[butter_admin] [INFO]   inventory    ox_inventory
[butter_admin] [INFO]   phone        sd-phone
[butter_admin] [INFO]   properties   qbx_properties
```

If two resources of one category are running, a warning names the one that is used. If no framework is running, an error is printed.

## Configuration

| File | Contents |
|------|----------|
| `config/config_shared.lua` | Debug levels, server name, keybind, command names, duty system, dev mode, noclip, player names and blips, weather list |
| `config/config_server.lua` | Discord bot, guild and webhooks (read from convars, server only) |
| `config/config_commands.lua` | Menu commands. Every item `Id` is also its permission |
| `config/config_reports.lua` | Report cooldown, auto close, transcripts, staff chat history size |
| `config/config_bans.lua` | Ban DM notifications |
| `config/config_fun.lua` | Troll animations, force command whitelist, jailbox, kidnap, UFO, ghost |
| `config/config_objects.lua` | Spawnable prop presets |
| `config/config_models.lua` | Ped models for "Change Model" |
| `config/config_sounds.lua` | Sounds for "Play Sound" (`sounds/*.ogg`) |
| `config/config_bennys.lua` | Admin Bennys prices and mod lists |

### Debug output

```lua
Config.Debug = {
    Error = true,  -- failures (bad SQL, missing framework)
    Warn = true,   -- recoverable problems
    Debug = false, -- verbose tracing; also logs NUI messages in the F8/CEF console
}
```

Messages print as `[butter_admin] [ERROR]`, `[WARN]`, `[INFO]` and `[DEBUG]`.

### Discord and webhooks

Secrets stay out of the files. Set them as server convars (`set`, never `setr`):

```cfg
set butter_admin_discord_guild "123456789012345678"
set butter_admin_discord_token "BOT_TOKEN"
set butter_admin_staffdiscord_guild ""   # optional staff server for personal admin log channels
set butter_admin_staffdiscord_token ""
set butter_admin_webhook_report ""
set butter_admin_webhook_ban ""
set butter_admin_webhook_kick ""
set butter_admin_webhook_unban ""
set butter_admin_webhook_exploit ""
set butter_admin_webhook_adminlog ""
set butter_admin_webhook_duty ""
set butter_admin_webhook_warn ""
```

The bot needs the Server Members intent to read roles, and shares a server with players it DMs (ban notices, report transcripts).

## Permissions

Ranks (`admin_ranks`) hold a list of permission ids; staff entries (`admin_staff`) give a rank to an identifier. An identifier can be a license, steam, discord or citizen id, or `role:<discord role id>` for everyone with that Discord role. A player gets every permission from every entry that matches them. Framework admins (see Installation) get `all`.

| Permission | Grants |
|------------|--------|
| `all` | Everything |
| `menuopen` | Open the menu |
| `page.commands`, `page.playerlist`, `page.bans`, `page.playerlogs`, `page.staffchat`, `page.reports`, `page.accesscontrol`, `page.options`, `page.resources`, `page.database`, `page.txadmin`, `page.monitoring` | The matching page |
| `fullprofile` | Full player profile in the player list |
| `devmode` | Dev mode and its keybinds |
| `menureset` | `/menureset` |
| `txadmin_console` | Running console commands from the dashboard |
| `resources_management` | Start, stop and restart resources |
| `clearinventory` | Wiping player inventories from the database page |
| Any command `Id` | That command (`revive`, `banplayer`, `noclip`, ...) |

With `Config.DutySystem.RestrictAdminActions`, staff must be on duty (`/adminduty` or `/duty`) to use admin actions; off duty staff just get a reminder. A staff member missing a permission is told so and logged to the `exploit` webhook. Anyone who is not staff and calls an admin event is logged and kicked.

## Commands and keybinds

| Command | Who | Does |
|---------|-----|------|
| `/menuopen` | Staff | Open the menu |
| `/menureset` | Staff (`menureset`) | Reset menu preferences (favorites, pins, options) |
| `/adminduty`, `/duty` | Staff | Toggle admin duty |
| `/report` | Everyone | Open the report window |
| `/dmchat` | Everyone | Reopen the chat with the admin who last messaged you |

| Keybind | Default | Does |
|---------|---------|------|
| `butter_admin_menu` | INSERT | Open the menu (can be turned off per player in Options) |
| `+butter_admin_laser` | L | Laser tool while in dev mode |
| `butter_admin_dev_<id>` | per command `DevKey` | Dev mode shortcuts, for example N for noclip, F9 for revive |

Keybinds are registered under new names, so players rebind them once in the GTA settings.

## Pages

Commands, Players, Monitoring (`Config.EnableMonitoring`, live view needs `screencapture`), Bans, Audit Logs, Chats (staff chat and private messages), Reports, Access Control, Database (players, garages, vehicles, properties, economy, jobs and gangs, inventories), Options, Dashboard (server info, console mirror, sessions, events) and Resources.

## Bridges

| Category | Supported |
|----------|-----------|
| framework | qbx_core, qb-core, es_extended |
| inventory | ox_inventory, qb-inventory (also ps-inventory, lj-inventory) |
| ambulance | qbx_medical, qb-ambulancejob, wasabi_ambulance |
| clothing | illenium-appearance, qb-clothing |
| fuel | ox_fuel, LegacyFuel, cdn-fuel, ps-fuel, lj-fuel, lc_fuel, Renewed-Fuel, rcore_fuel, nd_fuel, okokGasStation, hyon_gas_station |
| vehiclekeys | qbx_vehiclekeys, qb-vehiclekeys, Renewed-Vehiclekeys, wasabi_carlock, cd_garage, okokGarage, MrNewbVehicleKeys, t1ger_keys, jaksam-vehicles-keys |
| weather | qb-weathersync, Renewed-Weathersync, cad-climate |
| phone | lb-phone, qs-smartphone-pro, gksphone, okokPhone, high_phone, roadphone, yseries, sd-phone, 0s_phone |
| animation | bablo-animations |
| garages | qbx_garages, jg-advancedgarages |
| properties | ps-housing, qbx_properties, qbx_apartments, qb-houses, qs-housing, bcs_housing, bnl-housing, brutal_housing, nolag_properties, origen_housing, sn_properties, tgiann-house, tk_housing, vms_housing |

Each bridge lives in `bridge/<category>/client/<resource>.lua` or `bridge/<category>/server/<resource>.lua`, starts with a `UseBridge(category, resource)` guard and defines plain global functions. The guard only passes for a resource started under that exact name, so names a resource only `provide`s (sd-phone providing yseries) do not count. For example:

```lua
if not UseBridge('inventory', 'ox_inventory') then return end

function AddItem(inventory, item, amount, metadata)
    return exports.ox_inventory:AddItem(
        inventory,
        item,
        amount,
        metadata
    )
end
```

To support another resource, copy the closest bridge file, rename it after the resource, change the names in the `UseBridge` guard and adapt the functions. Run one resource per category: a second one replaces the first one's functions. Bridges are escrow ignored.

## Database

Created on start by `modules/core/server.lua`.

| Table | Holds |
|-------|-------|
| `admin_ranks` | Rank id, name, permissions (JSON) |
| `admin_staff` | Identifier, rank, temporary flag and expiry, personal webhook and its events |
| `admin_bans` | Ban id, identifiers, tokens, reason, admin, expiry |
| `admin_logs` | Audit log |
| `admin_objects` | Persistent spawned props |
| `admin_notes` | Player notes |

## Custom commands

Add items to `Config.CommandList` (the field reference is at the top of `config/config_commands.lua`) and handle the event. Always check the permission on the server:

```lua
RegisterNetEvent('my_resource:server:healPlayer', function(payload)
    local source = source
    -- With a reason, a denial notifies the admin and logs or kicks non-staff.
    if not IsAuthorized(source, 'healplayer', 'Healed a player without permission') then return end

    local target = ResolvePayloadTarget(payload)
    if not target then return Notify(source, locale('notify.invalid_player'), 'error') end
end)
```

Exports, events and the NUI contract are listed in [`[docs]/API.md`]([docs]/API.md).

## UI development

The React app lives in `web-src` and builds into `web`, which `fxmanifest.lua` loads.

```bash
cd web-src
npm ci
npm run build        # type checks, then builds into ../web
npm run start:game   # rebuild on change while testing in game
npm run dev          # browser preview on http://localhost:3000 with mock data
```

Rules the UI follows: no `box-shadow` (including Tailwind `shadow-*` and `ring-*`) and no `backdrop-filter`. The browser mocks are loaded only outside the game, so they never ship in the in-game bundle.

## Security notes

- Every admin event and callback checks permissions on the server. The UI can only run commands and actions from fixed lists in `modules/menu/client.lua`; it cannot trigger arbitrary events.
- Discord tokens and webhooks come from convars and never reach clients.
- "Force Animation" only runs commands listed in `Config.Fun.ForceCommandWhitelist`.
- The Resources page cannot stop or restart `butter_admin` itself.
- Keep `all` and `page.accesscontrol` for trusted staff.

## Credits

- The UFO kidnap, ghost and kidnap van trolls in `modules/trolling/client.lua` (with their values in `config/config_fun.lua`) are adapted from [fivem-tgiann-admin-troll](https://github.com/tgiann/fivem-tgiann-admin-troll) by tgiann, licensed under GPL-3.0. They were ported from TypeScript to Lua and modified.
