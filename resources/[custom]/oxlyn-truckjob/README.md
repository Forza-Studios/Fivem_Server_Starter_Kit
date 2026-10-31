# oxlyn-truckjob

A modern, fully-featured truck delivery job for FiveM with an in-game route
creator, persistent player progression, a bonus rotation event, leaderboard,
and a custom Liquid Glass NUI — all framework-agnostic.

> Works out of the box with **ESX**, **QBCore**, **QBox** and **Standalone**.

---

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Permissions](#permissions)
- [Configuration](#configuration)
- [Creating routes in-game](#creating-routes-in-game)
- [Route tiers (premium duplicates)](#route-tiers-premium-duplicates)
- [Per-route overrides](#per-route-overrides)
- [Resetting player data](#resetting-player-data)
- [Customization layer (`shared/overrides.lua`)](#customization-layer-sharedoverrideslua)
- [Cfx Asset Escrow](#cfx-asset-escrow)
- [Files at a glance](#files-at-a-glance)
- [Troubleshooting](#troubleshooting)

---

## Features

- **In-game route creator** — admins capture pickup + delivery by walking
  to the spot and running two commands. No config edits.
- **Auto-balance** — pay, required level and difficulty derived from route
  distance via tunable curves. Manual per-route overrides supported.
- **Level + XP progression** — persistent across sessions, framework-aware.
  Pay multiplier scales with level (capped via config).
- **Locked routes preview** — players see routes above their level so they
  know what they're working towards.
- **Bonus events** — every `interval` seconds a "happy hour" multiplier
  fires; scope can be all routes / random per-player / specific IDs.
  Random multiplier rolled each cycle.
- **Pre-spawned trailer** — physical trailer waits at the pickup. The
  driver brings the truck close, hops out, and presses E to hitch.
- **Mid-route obstacles** — randomised tire bursts, engine overheat, and
  trailer detach events keep deliveries from being on rails.
- **Anti-abuse** — server-side mission cap, idle-truck detection,
  driver-away detection, truck-destroyed cancels.
- **Ranking / leaderboard** — top-N players, configurable sort + columns.
- **Liquid Glass UI** — translucent layered surfaces, aurora background,
  iOS-style segmented nav, animated bonus pill, redesigned Stats panel.
- **PT / EN / FR** locales, with cargo + zone name translation.

---

## Requirements

- FiveM artifact recent enough to support `lua54`, `escrow_ignore`,
  `RegisterKeyMapping`.
- Optional: `oxmysql` (only if you set `Config.Storage.backend = 'oxmysql'`).
- Optional: `ox_target` or `qb-target` (only if you change
  `Config.Target.system`).

---

## Installation

1. Drop `oxlyn-truckjob` into `resources/[oxlyn-jobs]/` (or any folder
   already started from your `server.cfg`).
2. Add `ensure oxlyn-truckjob` to `server.cfg`.
3. Grant yourself the admin flag (see [Permissions](#permissions)) so you
   can create routes with `/criarrota`.
4. Open the dispatcher menu in-game by walking up to the NPC and pressing
   **E**, or run `/truckjob`.

---

## Permissions

The admin gate uses an ace permission. Drop this into `server.cfg`:

```cfg
add_ace group.admin "oxlyn.truckjob.admin" allow
```

Optionally, framework groups can also act as admin without ace:

```lua
Config.Admin.fallbackToGroup = true
Config.Admin.adminGroups     = { 'admin', 'superadmin', 'god' }
```

For testing only:

```lua
Config.Admin.allowAll = true        -- DEV ONLY
```

---

## Configuration

The whole config lives in [`config/config.lua`](config/config.lua). Every
block is documented inline. Here's the high-level map.

### 1. General
| Key | Default | Notes |
|---|---|---|
| `Config.Locale` | `'en'` | `'pt'`, `'en'` or `'fr'` |
| `Config.Currency` | `'$'` | Shown on every payment |
| `Config.Debug` | `false` | Verbose server console logs |
| `Config.Branding.company` | `'Oxlyn'` | Short brand label |
| `Config.Branding.companyFull` | `'Oxlyn Logistics'` | Printed on receipts |

### 2. Framework
```lua
Config.Framework = 'auto'         -- 'auto' | 'esx' | 'qb' | 'qbox' | 'standalone'
Config.Notify    = 'native'       -- 'native' | 'ox' | 'esx' | 'qb' | 'okok'
Config.Inventory = 'auto'         -- 'auto' | 'ox_inventory' | 'qb-inventory' | 'esx' | 'none'
```

### 3. World interaction
- `Config.Target.system` — `'native'` (built-in icon + interact pill),
  `'ox_target'`, `'qb-target'`, or `'none'` (commands only).
- Distances, key, and label all configurable.

### 4. Job gate
| Key | Default | Effect |
|---|---|---|
| `Config.JobName` | `'trucker'` | Framework job key when `RequireJob = true` |
| `Config.RequireJob` | `false` | Restrict to that framework job |
| `Config.UseLicense` | `false` | Require an inventory item to start |
| `Config.LicenseItem` | `'driver_license'` | Item ID checked when above is `true` |
| `Config.MinPlayers` | `0` | Minimum players online to allow starting |
| `Config.Cooldown` | `0` | Seconds between consecutive deliveries |

### 5. Storage
```lua
Config.Storage = {
    backend      = 'json',                 -- 'json' | 'oxmysql'
    file         = 'players.json',         -- Path under the resource folder
    table        = 'oxlyn_truckjob_players',
    saveDebounce = 4000,                   -- ms, batches writes
}
```

### 6. Route rotation (off by default)
With `enabled = false`, every route the player has access to is always
visible. Variety comes from the bonus event (see below).

If you enable rotation, the per-player pool sizes scale with level via
`unlockedSizeByLevel` / `lockedSizeByLevel`.

### 7. Repeat bonus
Extra payment when you re-do a route under your current level:
`+perGapPct` per level of gap (capped at `maxBonusPct`).

### 8. Admin route creator
ace flag, fallback groups, default cargo names, and the persistent
`routes.json` file path. Players with the flag can:

```
/criarrota                  → starts pickup capture (or completes one)
/criarrota lista            → list saved routes (with IDs)
/criarrota remover <id>     → delete a route
/criarrota nivel <id> <n>   → override min-level for a route
/criarrota valor <id> <n>   → override payment for a route
/criarrota dificuldade <id> <easy|medium|hard>
```

### 9. Auto-balance
Pay = `basePrice + km * pricePerKm`. Min level + difficulty derived from
distance via the `*ByDistance` lookup tables. Per-route overrides win.

### 10. Bonus event ("happy hour")
With rotation off, this is the main source of variety:

```lua
Config.Bonus = {
    enabled    = true,
    duration   = 600,     -- bonus stays active 10 min
    interval   = 1800,    -- new bonus every 30 min
    startDelay = 600,     -- first bonus 10 min after boot
    scope      = 'random',
    randomCount = 2,      -- how many routes get boosted (per player)
    randomMultipliers = { 1.15, 1.20, 1.25, 1.30 },  -- one is rolled each cycle
}
```

The UI shows:
- **Bonus active** → amber pill with `+25% 09:31` (current multiplier + time left)
- **Waiting for next** → muted pill with `Next bonus in 19:12`

### 11. Ranking
Top-N leaderboard with configurable sort key and column visibility.

### 12. Anti-abuse
Mission max duration, idle-truck timeout (with grace window), driver-away
detection, and "cancel on truck destroyed".

### 13. Economy
- `Config.PaymentAccount` — `'cash'` / `'bank'` / `'black_money'`
- `Config.BasePay` — flat per-delivery amount
- `Config.BonusPerKm` — extra per km driven
- `Config.PerfectBonus` — when no damage detected
- `Config.TimeBonus` — legacy lump time bonus (off by default)
- `Config.SpeedMultiplier` — modern ratio-based multiplier
- `Config.DamagePenalty` — % off pay per detected hit (capped)
- `Config.Tax` — final flat tax on the gross

### 14. XP / Level
```lua
Config.XP.baseXp       = 200     -- XP for level 2
Config.XP.growth       = 1.35    -- multiplier per level
Config.XP.maxLevel     = 50
Config.XP.perDelivery  = 35
Config.XP.perKm        = 2.5
Config.XP.perfectBonus = 25
Config.XP.payPerLevel  = 0.02    -- +2% pay per level...
Config.XP.maxPayBonus  = 0.40    -- ...capped at +40%
```

### 15. Teleport on complete
Whether (and where) the player is moved to after the truck despawns.
`target` can be `'npc'`, `'garage'`, or a `vector4(x, y, z, h)`.

### 16. Vehicles
Truck pool (`Config.Trucks`) and trailer pool (`Config.Trailers`). Each
truck row has `{ model, label, plate, fuel }`.

### 16b. Vehicle keys
`Config.VehicleKeys`. QBCore / QBox and most standalone lock resources
refuse to start a vehicle the player has no key for — the job truck is
spawned by this script, so the key system has to be told about it. The
driver is handed a key on spawn and it is taken back on despawn.

`system = 'auto'` detects the installed resource. Supported out of the
box:

| Value | Resource |
|---|---|
| `qbx` | `qbx_vehiclekeys` (QBox) |
| `qb` | `qb-vehiclekeys` (QBCore) |
| `mrnewb` | `MrNewbVehicleKeys` |
| `wasabi` | `wasabi_carlock` |
| `renewed` | `Renewed-Vehiclekeys` |
| `qs` | `qs-vehiclekeys` |
| `ti` | `ti_vehicleKeys` |
| `jaksam` | `vehicles_keys` |
| `cd_garage` | `cd_garage` |
| `okok` | `okokGarage` |
| `none` | no key system installed |

For anything else, add its event names to `extraClientEvents` /
`extraServerEvents`, or implement `Overrides.GiveVehicleKeys` in
`shared/overrides.lua` for full control.

Only a player who is actually on a delivery can be issued a key, and the
server re-reads the plate off the real entity, so the event cannot be
used to mint keys for someone else's vehicle.

### 17. Tire burst
Mid-route random tire pop. `chance` is per-route. Set `enabled = false`
to disable. Optional inventory item gate via `requireItem + item`.

### 18. Engine overheat
Heat builds above `heatSpeed` km/h and bleeds off below. At 100% the
engine overheats and the driver has to walk to the hood to cool it.
Mutually exclusive with trailer detach.

### 19. Trailer detach
Trailer randomly unhitches mid-route. Driver brings the truck within
`hitchDistance` and presses E to re-hitch.

### 20. Loading / unloading
Animation durations for pickup + delivery, despawn delay, hazards-during-
busy, attach/player distances for the pre-spawned trailer.

- `trailerSpawnDistance` — the pickup trailer is spawned when the driver
  gets this close (default 150 m), in the first free bay: if the saved
  spot is taken by another vehicle it is parked side by side instead of
  on top of it.
- `deliveryTrailerRadius` — the delivery can only be signed with the
  trailer hitched to the truck and within this radius of the drop-off
  (default 45 m). The server re-checks it before paying.

### 21–24. Blips, marker, NPC, garage, keys, commands, UI
Cosmetic + control settings. All commented in the file.

---

## Creating routes in-game

1. Grant yourself the admin flag.
2. Walk to the pickup spot. Run `/criarrota`.
3. Walk to the delivery spot. Run `/criarrota` again.
4. The route is saved to `routes.json` and immediately available.

You can list, remove, and override fields per route via `/criarrota lista`,
`/criarrota remover <id>`, etc. (full list in the Admin section above).

---

## Route tiers (optional — premium duplicates)

`routes.json` accepts two optional fields per route entry: `minLevel` and
`value`. If you set them, they win over auto-balance. This lets you create
a **premium tier** for any route by duplicating it with a different ID
(suffix `_t2`, `_premium`, anything unique), a higher `minLevel`, a
beefier `value`, and a fancier cargo string.

Example — same `Paleto Bay → Mar Alamo` route, two flavors:

```json
{
  "id": "route_1778435284_3b5b",
  "cargo": "Containers",
  "minLevel": 1, "value": 350, "difficulty": "easy",
  "label": "Paleto Bay → Mar Alamo",
  "pickup":   { "x": -272.6, "y": 6041.2, "z": 33.6 },
  "delivery": { "x":  889.0, "y": 3650.7, "z": 32.8 },
  ...
},
{
  "id": "route_1778435284_3b5b_t2",
  "cargo": "Reservas Bancárias",
  "minLevel": 10, "value": 3400, "difficulty": "hard",
  "label": "Paleto Bay → Mar Alamo",
  "pickup":   { "x": -272.6, "y": 6041.2, "z": 33.6 },
  "delivery": { "x":  889.0, "y": 3650.7, "z": 32.8 },
  ...
}
```

The server reads `minLevel` and `value` directly from each route entry,
and the UI auto-sorts by level so the list always reads as a clean
progression (Lv 1 → Lv 1 → Lv 2 → ... → Lv 10) and never jumps.

---

## Per-route overrides

`Config.RouteOverrides` lets you pin specific fields per route ID without
editing `routes.json`. It beats both auto-balance and per-route stored
fields:

```lua
Config.RouteOverrides = {
    ['route_1778435284_3b5b'] = {
        level      = 10,
        value      = 2500,
        difficulty = 'hard',
    },
}
```

---

## Resetting player data

Run from the server console (or in-game with admin flag):

```
truckjob_resetall
```

Wipes every player's stats / level / XP / history — both the on-disk
file *and* the in-memory cache, then re-initialises online players to
level 1 and broadcasts fresh data to their UIs. **Routes are untouched.**

---

## Customization layer (`shared/overrides.lua`)

Functions you can override without touching protected code:

- `Hooks.HasLicense(src) → bool` — replace the item check with anything.
- `Hooks.OnDeliveryComplete(src, payload)` — fire on successful delivery
  (give items, run a webhook, trigger an event, etc.).
- `Hooks.OnLevelUp(src, level)` — fire each time a player gains a level.
- `Hooks.GetCustomReward(src, route) → tableOrNil` — return a custom
  reward payload that's merged into the payment breakdown.

---

## Cfx Asset Escrow

When you package this resource through the Cfx asset packer (Tebex
escrow), the following files are kept **open** so buyers can tune the
script without breaking encryption:

| Path | Why open |
|---|---|
| `config/config.lua` | Every configurable knob |
| `config/locales.lua` | Locale dispatch glue |
| `config/routes.lua` | Optional static route list (advanced setups) |
| `locales/pt.lua` | Portuguese translation |
| `locales/en.lua` | English translation |
| `locales/fr.lua` | French translation |
| `shared/overrides.lua` | Extension hooks (license, rewards, events) |
| `web/index.html` | UI structure |
| `web/style.css` | UI styling — full skin freedom |
| `web/script.js` | UI logic |

Everything else (`client/*`, `server/*`, `bridge/**`) is encrypted by the
Cfx packer. The list is declared in `fxmanifest.lua`:

```lua
escrow_ignore {
    'config/config.lua',
    'config/locales.lua',
    'config/routes.lua',
    'locales/pt.lua',
    'locales/en.lua',
    'locales/fr.lua',
    'shared/overrides.lua',
    'web/index.html',
    'web/style.css',
    'web/script.js',
}
```

> Tip: if you fork the resource and add new files to `web/` or `locales/`,
> remember to add them to `escrow_ignore` before re-uploading the asset.

---

## Files at a glance

```
oxlyn-truckjob/
├── fxmanifest.lua
├── README.md
├── config/
│   ├── config.lua          ← main config (this README mirrors it)
│   ├── locales.lua         ← locale dispatch
│   └── routes.lua          ← optional static routes block
├── locales/
│   ├── pt.lua
│   ├── en.lua
│   └── fr.lua
├── shared/
│   ├── debug.lua
│   └── overrides.lua       ← extension hooks for buyers
├── bridge/
│   ├── bridge.lua
│   ├── frameworks/         ← ESX, QB, QBox, Standalone adapters
│   ├── notify/notify.lua
│   ├── inventory/inventory.lua
│   └── target/target.lua
├── client/
│   ├── main.lua
│   ├── npc.lua             ← dispatcher NPC + world prompt
│   ├── job.lua             ← gameplay loop, HUD, tire/heat/detach
│   ├── nui.lua             ← NUI bridge
│   └── admin.lua           ← /criarrota command surface
├── server/
│   ├── storage.lua         ← json / oxmysql persistence + Clear/ClearAll
│   ├── main.lua            ← payment, XP, ranking, anti-abuse
│   └── routes_admin.lua    ← route persistence + auto-balance
├── web/
│   ├── index.html
│   ├── style.css
│   └── script.js
├── routes.json             ← admin-created routes (read on boot)
└── players.json            ← persistent player state (json backend)
```

---

## Troubleshooting

### Job won't start — "you don't have the trucker job"
Either disable `Config.RequireJob`, or assign the job in your framework.

### Trailer never spawns
Check `Config.Loading.spawnTrailerAtPickup = true`. If you use a custom
trailer for the route, make sure the model is streamed.

### Bonus pill never appears
`Config.Bonus.enabled = true`? `Config.Bonus.startDelay` defaults to 600
(10 minutes after boot). The "Next bonus in X" countdown shows during
the start delay; the active "+X%" pill shows during a cycle.

### Updating without losing the ranking
The release zips no longer ship `players.json`, so extracting an update
over the resource folder keeps every player's level, XP and deliveries.
If you delete the folder before updating, back up `players.json` first
(or use `Config.Storage.backend = 'oxmysql'`).

### Player progression won't reset
Don't manually edit `players.json` while the resource is running — the
in-memory cache will flush over it. Use `truckjob_resetall` instead.

### Routes show in wrong order
The server sorts by `minLevel` ascending with payment as a tie-breaker
inside each pool group (unlocked / locked). If you see a jump like
"Lv 2 → Lv 5 → Lv 2", make sure you have the latest server build and
your `routes.json` entries have explicit `minLevel` fields.

---

## License

Sold and supported via Tebex / Cfx asset escrow. Reselling, leaking, or
redistributing the encrypted source is forbidden.
