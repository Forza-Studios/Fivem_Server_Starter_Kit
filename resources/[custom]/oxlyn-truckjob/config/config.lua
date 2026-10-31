

----              _  _     _  _     _  _     _  _     _  _     _  _     _  _     _  _
----            _| || |_ _| || |_ _| || |_ _| || |_ _| || |_ _| || |_ _| || |_ _| || |_
----            _  ..  _|_  ..  _|_  ..  _|_  ..  _|_  ..  _|_  ..  _|_  ..  _|_  ..  _|
----           |_      _|_      _|_      _|_      _|_      _|_      _|_      _|_      _|
----             |_||_|   |_||_|   |_||_|   |_||_|   |_||_|   |_||_|   |_||_|   |_||_|
----
----
----                  ___       _               ____         __ _
----                 / _ \__  _| |_   _ _ __   / ___|  ___  / _| |___      ____ _ _ __ ___
----                | | | \ \/ / | | | | '_ \  \___ \ / _ \| |_| __\ \ /\ / / _` | '__/ _ \
----                | |_| |>  <| | |_| | | | |  ___) | (_) |  _| |_ \ V  V / (_| | | |  __/
----                 \___//_/\_\_|\__, |_| |_| |____/ \___/|_|  \__| \_/\_/ \__,_|_|  \___|
----                              |___/
----
----                                   OXLYN SOFTWARE | TRUCK JOB ESX/QBCORE/QBOX
----
----               Thank you for purchasing our script; we greatly appreciate your preference.
----        If you have any questions or any modifications in mind, please contact us via Discord.
----
----                           Support and More: https://discord.gg/Jskkg4h54r
----
----              _  _     _  _     _  _     _  _     _  _     _  _     _  _     _  _
----            _| || |_ _| || |_ _| || |_ _| || |_ _| || |_ _| || |_ _| || |_ _| || |_
----            _  ..  _|_  ..  _|_  ..  _|_  ..  _|_  ..  _|_  ..  _|_  ..  _|_  ..  _|
----           |_      _|_      _|_      _|_      _|_      _|_      _|_      _|_      _|
----             |_||_|   |_||_|   |_||_|   |_||_|   |_||_|   |_||_|   |_||_|   |_||_|
----

-- =============================================================================
--  ██████╗ ██████╗ ███╗   ██╗███████╗██╗ ██████╗
-- ██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔════╝
-- ██║     ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
-- ██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
-- ╚██████╗╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
--  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝
-- =============================================================================
--
--  CONFIGURATION FILE — config/config.lua
--  Edit this file to configure Truck Job for your server.
--
-- =============================================================================
Config = {}

-- =====================================================================
-- 1. GENERAL
-- =====================================================================
Config.Locale   = 'en'                              -- 'pt' | 'en' | 'fr' (or create a custom)
Config.Currency = '$'                               -- Shown on every payment
Config.Debug    = false                             -- Verbose server console logs

-- Company name shown in the UI / on the delivery paper.
-- The brand is locale-independent (stays the same in every language).
Config.Branding = {
    company     = 'Oxlyn',                          -- Short — used internally
    companyFull = 'Oxlyn Logistics',                -- Full — printed on receipts
}

-- =====================================================================
-- 2. FRAMEWORK BRIDGE
--   Set to 'auto' unless you know exactly which framework you're running.
-- =====================================================================
Config.Framework = 'auto'                           -- 'auto' | 'esx' | 'qb' | 'qbox' | 'standalone'
Config.Notify    = 'native'                         -- 'native' | 'ox' | 'esx' | 'qb' | 'qbox' | 'okok'
-- 'ak47_inventory' is detected BEFORE ox_inventory: its ox compat layer can
-- claim the ox_inventory resource name without exposing the ox exports.
Config.Inventory = 'auto'                           -- 'auto' | 'ox_inventory' | 'ak47_inventory' | 'qb-inventory' | 'esx' | 'none'

-- =====================================================================
-- 3. WORLD INTERACTION
--   How the player triggers the dispatcher NPC.
--     native    => floating world icon + interact pill (no extra resource)
--     ox_target => ox_target zones (recommended if already in use)
--     qb-target => qb-target zones
--     none      => disable world prompts (only /truckjob opens the menu)
-- =====================================================================
Config.Target = {
    system        = 'native',
    interactDist  = 2.0,                            -- Distance (m) to fire the pill
    renderDist    = 12.0,                           -- Distance (m) to start rendering the icon
    iconHeight    = 1.05,                           -- Vertical offset above NPC head
    key           = 38,                             -- 38 = E
    keyLabel      = 'E',                            -- Displayed key character
}

-- =====================================================================
-- 4. JOB GATE
--   Optional restrictions to start the job.
-- =====================================================================
Config.JobName     = 'trucker'                      -- Framework job key, when RequireJob = true
Config.RequireJob  = false                          -- Gate the job behind a framework job
Config.UseLicense  = false                          -- Require a license item
Config.LicenseItem = 'driver_license'               -- Inventory item id when UseLicense = true

Config.MinPlayers  = 0                              -- Minimum players online to allow starting
Config.Cooldown    = 0                              -- Seconds between deliveries (0 = disabled)

-- =====================================================================
-- 5. PERSISTENT STORAGE
--     json     => single file written to the resource folder (default)
--     oxmysql  => oxmysql; the table is auto-created on boot
-- =====================================================================
Config.Storage = {
    backend      = 'json',
    file         = 'players.json',
    table        = 'oxlyn_truckjob_players',        -- Used by oxmysql backend
    saveDebounce = 4000,                            -- Batch writes to disk/DB (ms)
}

-- =====================================================================
-- 6. ROUTE ROTATION (disabled by default — all routes are always visible)
--   When `enabled = false`, every route the player has access to is shown
--   in the UI. Variety comes from the Bonus Event (see section 10).
--
--   When `enabled = true`, each player sees a per-level-sized subset that
--   rotates every `refreshEvery` seconds. The pool size scales with level
--   via the *SizeByLevel tables (first matching row wins; keep sorted asc).
-- =====================================================================
Config.RouteRotation = {
    enabled            = false,

    -- Used when *SizeByLevel is empty
    unlockedSize       = 3,
    lockedSize         = 3,

    refreshEvery       = 300,                       -- Seconds; both pools rotate together
    refreshOnComplete  = false,                     -- Swap completed route for a fresh one
    avoidPreviousPool  = true,                      -- Prefer routes that weren't in the last pool

    unlockedSizeByLevel = {
        { lvl = 1,  size = 3 },
        { lvl = 3,  size = 4 },
        { lvl = 5,  size = 5 },
        { lvl = 8,  size = 6 },
    },
    lockedSizeByLevel = {
        { lvl = 1,  size = 3 },
        { lvl = 5,  size = 4 },
        { lvl = 10, size = 5 },
    },
}

-- =====================================================================
-- 7. REPEAT BONUS
--   Extra payment when a driver redoes a route that's beneath their current
--   level (i.e. completed before AND minLevel < driver level). Compensates
--   high-level players for taking on easy rotations they've already mastered.
-- =====================================================================
Config.RepeatBonus = {
    enabled     = true,
    perGapPct   = 0.03,                             -- +3% per level of gap
    maxBonusPct = 0.30,                             -- Hard cap (~10 gap → +30%)
    minRepeats  = 1,                                -- Must have completed at least this many times
}

-- =====================================================================
-- 8. ADMIN — in-game route creator
--   Grant access via an ace permission, framework group, or both.
--     server.cfg:  add_ace group.admin "oxlyn.truckjob.admin" allow
-- =====================================================================
Config.Admin = {
    aceFlag         = 'oxlyn.truckjob.admin',
    fallbackToGroup = true,                         -- Also accept framework groups below
    adminGroups     = { 'admin', 'superadmin', 'god' },
    allowAll        = false,                        -- DEV ONLY: true lets everyone create routes
    persistFile     = 'routes.json',                -- Where saved routes are written

    -- Cargo names suggested when the admin creates a new route.
    -- These are the *stored* names; the UI translates them to English when
    -- locale = 'en' via the PT→EN map in web/script.js.
    defaultCargos   = {
        'Mercadoria Geral', 'Containers', 'Materiais', 'Encomendas', 'Carga Diversa',
    },
}

-- =====================================================================
-- 9. AUTO-BALANCE
--   Derives pay, required level and difficulty from straight-line distance.
--   Per-route fields in routes.json (or Config.RouteOverrides) always win.
-- =====================================================================
Config.AutoBalance = {
    enabled    = true,
    basePrice  = 250,                               -- Floor payment
    pricePerKm = 90,                                -- $ added per km of distance

    -- First row whose `km` <= route distance wins. Keep sorted ascending.
    levelByDistance = {
        { km = 0,  level = 1  },
        { km = 3,  level = 2  },
        { km = 5,  level = 3  },
        { km = 7,  level = 5  },
        { km = 10, level = 8  },
        { km = 14, level = 12 },
        { km = 18, level = 16 },
    },
    difficultyByDistance = {
        { km = 0, tier = 'easy'   },
        { km = 4, tier = 'medium' },
        { km = 8, tier = 'hard'   },
    },
}

-- =====================================================================
-- 9b. ROUTE OVERRIDES — pin specific fields per route ID.
--   Beats auto-balance and any in-game admin field. Useful for "premium"
--   tiers or to nudge a single route without editing routes.json by hand.
--
--   Example:
--     Config.RouteOverrides = {
--         ['route_1778435284_3b5b'] = { level = 10, value = 2500, difficulty = 'hard' },
--     }
-- =====================================================================
Config.RouteOverrides = {}

-- =====================================================================
-- 10. BONUS EVENT — periodic pay multiplier ("happy hour")
--   With route rotation disabled, this is the main source of variety.
--   Every `interval` seconds a new bonus starts, lasts `duration` seconds,
--   and applies a random multiplier from `randomMultipliers` to:
--     'all'      => every visible route
--     'random'   => `randomCount` routes per player (different per player)
--     'specific' => only the IDs listed in `specificIds`
-- =====================================================================
Config.Bonus = {
    enabled    = true,
    multiplier = 1.20,                              -- Fallback when randomMultipliers is empty
    duration   = 600,                               -- Seconds the bonus stays active (10 min)
    interval   = 1800,                              -- Seconds from one start to the next (30 min)
    startDelay = 600,                               -- Seconds after resource boot before the first event
    announce   = true,                              -- Server-wide toast on start/end

    randomMultipliers = { 1.15, 1.20, 1.25, 1.30 },

    scope       = 'random',                         -- 'all' | 'random' | 'specific'
    randomCount = 2,                                -- Routes picked when scope = 'random'
    specificIds = {                                 -- Used only when scope = 'specific'
        -- 'route_1778435402_ec5b',
    },
}

-- =====================================================================
-- 11. RANKING / LEADERBOARD
-- =====================================================================
Config.Ranking = {
    enabled      = true,
    topN         = 10,
    refreshEvery = 60,                              -- Seconds; client auto-refresh interval
    sortBy       = 'level',                         -- 'level' | 'xp' | 'totalPaid' | 'deliveries'
    showSelf     = true,                            -- Highlight the viewer's own row
    columns = {
        rank       = true,
        name       = true,
        level      = true,
        xp         = true,
        deliveries = true,
        earned     = true,
    },
}

-- =====================================================================
-- 12. ANTI-ABUSE
--   Server enforces a hard mission cap; the client cancels if the truck
--   sits abandoned or the driver wanders off.
-- =====================================================================
Config.AntiAbuse = {
    enabled                  = true,
    maxJobDuration           = 1800,                -- Seconds; cancel + no payment if exceeded
    idleTimeout              = 90,                  -- Seconds; truck stationary, nobody driving → warn
    idleGrace                = 30,                  -- Seconds; extra grace after the warning
    driverAwayDistance       = 60.0,                -- Metres; player too far from the truck
    driverAwayTimeout        = 60,                  -- Seconds; trigger window
    driverAwayGrace          = 30,                  -- Seconds; grace after warning
    cancelOnTruckDestroyed   = true,                -- If the truck is destroyed, end the job
    cancelOnTrailerDestroyed = false,               -- If the trailer is destroyed, end the job
}

-- =====================================================================
-- 13. ECONOMY
-- =====================================================================
Config.PaymentAccount = 'cash'                      -- 'cash' | 'bank' | 'black_money'
Config.BasePay        = 250                         -- Flat amount paid per delivery
Config.BonusPerKm     = 14                         -- Extra $ per km driven
Config.PerfectBonus   = 250                         -- Bonus when no damage detected

-- Legacy lump time bonus. The Speed Multiplier below is the modern,
-- ratio-based system; keep this enabled = false unless you want a flat
-- bonus stacked on top.
Config.TimeBonus = {
    enabled  = false,
    maxBonus = 200,                                 -- Max flat $ bonus when delivered under target
    target   = 600,                                 -- Target time (seconds) for full bonus
}

-- =====================================================================
-- 13b. SPEED MULTIPLIER — time-based pay
--   The whole payment is multiplied by `mul` based on delivery time vs an
--   expected baseline. Faster = bigger %, slow = penalty.
--     ratio = expectedTime / actualTime  (>1 = faster than expected)
--   First row whose `ratio >= player's actual ratio` wins; keep sorted desc.
-- =====================================================================
Config.SpeedMultiplier = {
    enabled     = true,
    expectedKmH = 50,                               -- Assumed average truck speed
    minElapsed  = 60,                               -- Floor on actualTime (avoids divide-by-tiny)
    thresholds  = {
        { ratio = 1.60, mul = 1.30 },               -- 60%+ faster → +30%
        { ratio = 1.30, mul = 1.20 },               -- 30% faster → +20%
        { ratio = 1.10, mul = 1.10 },               -- 10% faster → +10%
        { ratio = 0.90, mul = 1.00 },               -- Around expected → no change
        { ratio = 0.70, mul = 0.90 },               -- 30% slower → -10%
        { ratio = 0.50, mul = 0.80 },               -- 50% slower → -20%
        { ratio = 0.00, mul = 0.70 },               -- Floor → -30%
    },
}

Config.DamagePenalty = {
    enabled = true,
    perHit  = 0.05,                                 -- 5% off the gross pay per hit detected
    maxCut  = 0.5,                                  -- Hard cap (50% maximum penalty)
}

Config.Tax = 0.05                                   -- Final flat tax taken off the payment (0..1)

-- =====================================================================
-- 14. XP / LEVEL PROGRESSION
--   xpToLevel(n) = baseXp * (growth ^ (n-1))
-- =====================================================================
Config.XP = {
    enabled      = true,
    baseXp       = 200,                             -- XP needed to reach level 2
    growth       = 1.35,                            -- Multiplier applied per level
    maxLevel     = 50,
    perDelivery  = 35,                              -- Flat XP per completed delivery
    perKm        = 2.5,                             -- XP per km driven
    perfectBonus = 25,                              -- Extra XP if delivery is flawless
    difficultyXp = { easy = 1.0, medium = 1.4, hard = 2.0 },

    -- Pay scales linearly with level: payMultiplier = 1 + (level-1) * payPerLevel
    payPerLevel  = 0.02,                            -- +2% per level
    maxPayBonus  = 0.40,                            -- Cap at +40% from levels alone

    -- Optional per-route minimum level. Anything not listed defaults to 1.
    -- For routes.json-based routes the minLevel field on each route entry
    -- already feeds Config.XP.routeMinLevel on boot, so this table is only
    -- useful if you want to override a route post-hoc.
    routeMinLevel = {},
}

-- =====================================================================
-- 15. TELEPORT ON COMPLETE
--   After delivery, bring the player back so they're not stranded.
-- =====================================================================
Config.TeleportOnComplete = {
    enabled = true,
    target  = 'npc',                                -- 'npc' | 'garage' | vector4(x, y, z, h)
    fade    = true,                                 -- Screen fade-out + in around the teleport
}

-- =====================================================================
-- 16. VEHICLES
-- =====================================================================
Config.Trucks = {
    { model = 'phantom', label = 'Phantom', plate = 'TRK', fuel = 100 },
    { model = 'hauler',  label = 'Hauler',  plate = 'TRK', fuel = 100 },
    { model = 'packer',  label = 'Packer',  plate = 'TRK', fuel = 100 },
}

-- Trailer pool used when a route doesn't define `trailer`
Config.Trailers = {
    'trailers',
    'trailers2',
    'trailers3',
    'tanker',
}

-- ---------------------------------------------------------------------
-- 16b. VEHICLE KEYS
--   QBCore / QBox (and most standalone key resources) refuse to start the
--   engine of a vehicle the player has no key for. The job truck is
--   spawned by this script, so the key system has to be told about it —
--   otherwise the player sits in a truck that will not move.
--
--   `system` picks the key resource:
--     'auto'      detect an installed system (recommended)
--     'qbx'       qbx_vehiclekeys          (QBox)
--     'qb'        qb-vehiclekeys           (QBCore)
--     'mrnewb'    MrNewbVehicleKeys
--     'wasabi'    wasabi_carlock
--     'renewed'   Renewed-Vehiclekeys
--     'qs'        qs-vehiclekeys
--     'ti'        ti_vehicleKeys
--     'jaksam'    vehicles_keys
--     'cd_garage' cd_garage
--     'okok'      okokGarage
--     'none'      no key system on this server
--
--   Anything not on that list: add its event names to the extra*Events
--   lists below, or use the Overrides.GiveVehicleKeys hook in
--   shared/overrides.lua for full control.
-- ---------------------------------------------------------------------
Config.VehicleKeys = {
    enabled         = true,
    system          = 'auto',
    removeOnDespawn = true,                         -- Take the key back when the truck despawns
    lockDoors       = false,                        -- true = truck spawns locked (player still has the key)

    -- Extra events fired ON THE CLIENT when the key is handed out.
    --   TriggerEvent(name, plate, model, vehicle)
    extraClientEvents = {},

    -- Extra events fired ON THE SERVER when the key is handed out.
    --   TriggerEvent(name, source, plate, model, vehicle)
    extraServerEvents = {},

    -- Extra events fired ON THE SERVER when the key is taken back.
    extraServerRemoveEvents = {},
}

-- =====================================================================
-- 17. TIRE BURST  (mid-route random tire pop)
--   While driving, a random tire blows at a random moment. The driver has
--   to stop, walk to the flat, press E to repair. Fires AT MOST ONCE per
--   route. Set enabled = false to disable entirely.
-- =====================================================================
Config.TireBurst = {
    enabled        = true,
    chance         = 0.50,                          -- 0..1; per route (0.50 ≈ half the runs)
    minDelay       = 60,                            -- Earliest pop after route start (seconds)
    maxDelay       = 300,                           -- Latest pop after route start
    repairDuration = 6000,                          -- ms; progress bar length while repairing
    interactDist   = 2.5,                           -- m; how close to the wheel to repair

    requireItem    = false,                         -- Gate the repair on an inventory item
    item           = 'tire_kit',
    itemLabel      = 'Tire Repair Kit',             -- Shown in the missing-item notification

    -- Tyre indices the system may pop. 0=FL 1=FR 4=RL 5=RR is the safe set
    -- across all truck models in Config.Trucks.
    candidates     = { 0, 1, 4, 5 },
}

-- =====================================================================
-- 18. ENGINE OVERHEAT  (heat builds at high speeds)
--   Heat accumulates while the player drives above `heatSpeed` km/h and
--   bleeds off below. At 100% the engine overheats — smoke, power loss —
--   and the driver must walk to the hood to cool it. Fires AT MOST ONCE
--   per route, gated by `chance`.
-- =====================================================================
Config.EngineOverheat = {
    enabled        = true,
    chance         = 0.40,                          -- 0..1; fraction of routes that can overheat at all
    heatSpeed      = 70,                            -- km/h above this builds heat
    heatPerSec     = 1.67,                          -- 100/60 → about 1 min sustained triggers it
    coolPerSec     = 0.50,                          -- Heat bleed when below threshold (~3 min full cool)
    repairDuration = 8000,                          -- ms; progress bar length while cooling
    interactDist   = 3.5,

    requireItem    = false,
    item           = 'engine_coolant',
    itemLabel      = 'Engine Coolant',
}

-- =====================================================================
-- 19. TRAILER DETACH  (mutually exclusive with overheat — rolled at start)
--   The trailer randomly unhitches mid-route. Driver has to come back and
--   re-hitch.
-- =====================================================================
Config.TrailerDetach = {
    enabled       = true,
    chance        = 0.35,                           -- 0..1; per route
    minDelay      = 90,                             -- Seconds after PICKUP (earliest)
    maxDelay      = 480,                            -- Seconds after PICKUP (latest)
    hitchDistance = 12.0,                           -- m; truck must be within this radius to re-hitch
}

-- =====================================================================
-- 20. LOADING / UNLOADING
-- =====================================================================
Config.Loading = {
    pickupDuration       = 5500,                    -- ms; cargo load animation
    deliveryDuration     = 5500,                    -- ms; cargo unload animation
    despawnDelay         = 3500,                    -- ms; truck despawn after delivery
    freezeWhileBusy      = true,                    -- Lock player + vehicle during the action
    spawnTrailerAtPickup = true,                    -- Pre-spawn trailer at pickup (player must hitch)
    attachDistance       = 20.0,                    -- m; max truck-to-trailer distance for hitching
    playerNearDistance   = 12.0,                    -- m; player must be within this radius of the trailer
    hazardsWhileBusy     = true,                    -- Hazard lights ON during load/unload
    trailerSpawnDistance = 150.0,                   -- m; pickup trailer spawns when the driver gets this close
    deliveryTrailerRadius = 45.0,                   -- m; hitched trailer must be this close to the drop-off to deliver
}

-- =====================================================================
-- 21. BLIPS / MARKERS
-- =====================================================================
Config.Blip = {
    sprite  = 477,
    color   = 5,
    scale   = 0.6,
    display = 4,
    label   = 'Truck Job',
}

Config.Marker = {
    type           = 1,
    size           = vector3(2.0, 2.0, 0.5),
    color          = { r = 255, g = 180, b = 0, a = 120 },
    bobUpAndDown   = false,
    faceCamera     = false,
    rotate         = false,
    drawDistance   = 35.0,
    interactDist   = 12.0,                          -- m; press-E radius (2D, generous)
    iconHeight     = 1.40,                          -- m; vertical offset of the floating icon
}

-- =====================================================================
-- 22. NPC (job giver)
-- =====================================================================
Config.NPC = {
    model    = 's_m_m_trucker_01',
    coords   = vector4(37.7099, 6543.7568, 31.7125, 216.4006),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    blip     = true,
}

-- Place where players take / return the truck
Config.Garage = {
    spawn   = vector4(50.34, 6541.25, 31.30, 333.0),
    return_ = vector4(56.20, 6549.55, 31.30, 333.0),
}

-- =====================================================================
-- 23. KEYS / COMMANDS
-- =====================================================================
Config.Keys = {
    cancel = 'X',                                   -- In-vehicle key to cancel a delivery
}

Config.Commands = {
    open        = 'truckjob',                       -- /truckjob opens the menu

    -- false = the command is never registered, so the job can only be started
    -- at the depot (the NPC / target / marker). Nothing else changes: the ped
    -- keeps opening the same menu, and because the command does not exist at
    -- all it cannot be typed or auto-completed either.
    openEnabled = true,
}

-- =====================================================================
-- 24. UI BEHAVIOUR
-- =====================================================================
Config.UI = {
    theme          = 'dark',                        -- 'dark' | 'light'
    accent         = '#f4f4f5',                     -- Neutral silver; CSS reads --accent
    showHud        = true,                          -- Show the in-job HUD
    showRouteOnMap = true,                          -- Draw the GPS line + blip on the map
    autoCloseMenu  = true,                          -- Close the menu after picking a route
}

