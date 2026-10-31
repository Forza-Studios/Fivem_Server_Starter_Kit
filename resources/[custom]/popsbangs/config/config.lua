
-- ===========================================================================
--  OXLYN · Advanced Anti-Lag Pops & Bangs System
--  config/config.lua — the settings you are most likely to change
-- ===========================================================================
--
--  The configuration is split by subject. This file holds the knobs; the
--  three big catalogues have a file of their own, so a long list never
--  stands between you and a setting:
--
--    config/config.lua            this file: general, framework, inventory,
--                                 commands, levels, anti-lag, heat, feedback,
--                                 interface, items, limits
--    config/exhausts.lua          the exhausts and their flame colours
--    config/flames.lua            the flames: layers, styles, particles
--    config/audio.lua             the sound: mix, reverb, voices, samples
--    config/custom_inventory.lua  hooks for an inventory not supported yet
--    config/custom_framework.lua  hooks for a framework not supported yet
--
--  EVERY TEXT a player reads lives in locales/ (en, pt, br, es, fr, de, pl,
--  lt) — never in this file. Set Config.Locale below and edit the language
--  file; the names of the exhausts come from config/exhausts.lua.
--
--  Sections
--    1. GENERAL
--    2. FRAMEWORK AND INVENTORY
--    3. COMMANDS AND PERMISSIONS
--    4. POWER LEVELS
--    5. ANTI-LAG, TURBO AND TWO-STEP
--    6. EXHAUST HEAT
--    7. WHAT A BANG DOES BESIDES SOUNDING
--    8. THE INTERFACE
--    9. ITEMS AND THE WORKSHOP
--   10. THE VALVE REMOTE
--   11. LIMITS, SYNC AND SECURITY
--   12. PER-MODEL OVERRIDES (advanced)
-- ===========================================================================

Config = {}

-- ===========================================================================
--  1. GENERAL
-- ===========================================================================

-- The language of everything a player reads: notifications, the work bar,
-- the selector, the chat help.
--   'en' | 'pt' | 'br' | 'es' | 'fr' | 'de' | 'pl' | 'lt'
-- A key missing from a language falls back to English, so a half-finished
-- translation still reads. Add your own by copying locales/en.lua.
Config.Locale = 'en'

-- Where an installed tune is kept, so a car still pops after a restart.
-- Resource KVP, by model and plate: no SQL and no database to set up.
-- false forgets everything when the resource stops.
Config.Persistence = true

-- The state bag key the tune travels on. Change it only if another resource
-- happens to use the same name.
Config.StateKey = 'oxlyn:pops'

-- How far away a car's flames are drawn, in metres. The sound carries as far
-- as each level's own `radius` (section 4).
Config.VisualDistance = 150.0

-- Include addon and electric vehicles. An electric car has no revs to read,
-- so they are simulated from speed and throttle.
Config.AllowAllVehicleTypes = true

-- ===========================================================================
--  2. FRAMEWORK AND INVENTORY
-- ===========================================================================
--  Both are detected on their own and printed in the console at start. Pin
--  one by name only when the detection picks the wrong one.

-- 'auto' | 'esx' | 'qbcore' | 'qbox' | 'standalone' | 'custom'
--   The pops and bangs need no framework at all. A framework is used for two
--   things only: the player's job (Config.Items.jobs, section 9) and the
--   framework notifications (Config.UI.notifications, section 8).
--   'standalone' is a complete, supported choice.
--   'custom' reads config/custom_framework.lua.
Config.Framework = 'auto'

-- 'auto' | 'ox' | 'qb' | 'ps' | 'lj' | 'aj' | 'jpr' | 'ak47' | 'hex4' | 'qs'
-- | 'codem' | 'origen' | 'tgiann' | 'core' | 'mf' | 'esx' | 'custom'
--   Which inventory holds the kits and the exhausts (section 9).
--     ox      ox_inventory
--     qb      qb-inventory          ps      ps-inventory
--     lj      lj-inventory          aj      aj-inventory
--     jpr     jpr-inventory         ak47    ak47_inventory
--     hex4    hex_4_inventory       qs      qs-inventory (Quasar)
--     codem   codem-inventory       origen  origen_inventory
--     tgiann  tgiann-inventory      core    core_inventory
--     mf      mf-inventory
--     esx     the framework's own inventory (Chezza / Cheeza lives here)
--     custom  config/custom_inventory.lua
--   'auto' prefers a dedicated inventory over the framework's own, and
--   probes ak47_inventory before ox_inventory (it answers to the ox export
--   names as well). An inventory that cannot answer a call is retried
--   through the framework's own inventory, and the console says so once.
Config.Inventory = 'auto'

-- ===========================================================================
--  3. COMMANDS AND PERMISSIONS
-- ===========================================================================

-- /installpops 0 | 1 | 2 | 3 | 4 — install, change or remove a level.
Config.Command = 'installpops'

-- true: only principals holding the ACE below may use the commands. The
-- items of section 9 are governed by Config.Items.jobs instead.
--   server.cfg:  add_ace group.admin oxlyn.pops.install allow
Config.RequireAce = false
Config.AcePermission = 'oxlyn.pops.install'

-- ===========================================================================
--  4. POWER LEVELS
-- ===========================================================================
--  Levels run from 1 upwards without gaps; add a [5] and /installpops 5
--  exists. The names are shown in the selector and the notifications.
--
--    minRpm        revs under which nothing fires (0-1)
--    liftChance    chance of a burst when the throttle closes
--    shiftChance   chance of a burst on an upshift
--    limiter       fires at the rev limiter as well
--    heavyChance   how readily a manoeuvre opens with a bang
--    overrun       follow-up bursts while the car keeps coasting in gear
--                  (0 = only the first burst; a hot pipe adds one)
--    boomChance    how often a heavy report is a full boom (the
--                  gunshot-sized ones). Defaults: 0, 0.22, 0.62, 0.85
--    bangBias      leans the odds towards phrases that open with a bang
--                  (1 = as they are; level 4 uses 1.8)
--    flameScale    flame size on this level
--    volume        relative loudness
--    radius        how far it is heard, in metres
--    echo          how much tail the level carries
--
--  Below Brutal a loud bang needs the revs taken to the limiter under load
--  and then let go; a lift from half throttle at middling revs pops and
--  crackles instead. Brutal keeps its own rules.
Config.Levels = {
    [1] = { level = 1, name = 'Street', minRpm = 0.53, liftChance = 0.72, shiftChance = 0.60,
        limiter = false, heavyChance = 0.12, overrun = 1,
        flameScale = 0.40, volume = 0.50, radius = 90.0, echo = 0.12 },
    [2] = { level = 2, name = 'Sport', minRpm = 0.46, liftChance = 0.90, shiftChance = 0.88,
        limiter = true, heavyChance = 0.35, overrun = 3,
        flameScale = 0.66, volume = 0.76, radius = 175.0, echo = 0.18 },
    [3] = { level = 3, name = 'Extreme', minRpm = 0.38, liftChance = 1.0, shiftChance = 1.0,
        limiter = true, heavyChance = 0.58, overrun = 5,
        flameScale = 1.0, volume = 1.0, radius = 300.0, echo = 0.24 },
    -- Extreme with the loud bangs far more often: most lifts and shifts open
    -- with a bang or a boom, and the overrun keeps a few for later.
    [4] = { level = 4, name = 'Brutal', minRpm = 0.36, liftChance = 1.0, shiftChance = 1.0,
        limiter = true, heavyChance = 0.85, overrun = 5, boomChance = 0.85, bangBias = 1.8,
        flameScale = 1.15, volume = 0.5, radius = 320.0, echo = 0.24 }
}

-- ===========================================================================
--  5. ANTI-LAG, TURBO AND TWO-STEP
-- ===========================================================================
--  /antilag adds the TURBO to a car and nothing else: the pops and bangs
--  belong to /installpops and sound exactly the same with or without it.
--
--  The sample lists of this section live in config/audio.lua.
Config.AntiLag = {
    command = 'antilag',

    -- Turbo air, on every car with anti-lag installed, whenever it is
    -- driven: a whistle that spools with throttle and revs, compressor
    -- flutter when the throttle closes at part boost, a blow-off when it
    -- closes at full boost and (shiftVent) a vent on every upshift under
    -- boost. A vent lasts as long as there was pressure to let go.
    --   radius is the audible distance in metres.
    turbo = { enabled = false, volume = 0.9, radius = 70.0, flutter = true, blowOff = true, shiftVent = true },

    -- Optional, off by default. Switching these on lets the anti-lag make
    -- bangs of its own, which then take the place of the pops of the
    -- installed level:
    --   bangs    anti-lag bangs when the throttle closes at speed (they
    --            replace that lift's pops for up to maxActiveMs)
    --   twoStep  brake + throttle standing still: the two-step, with its
    --            bangs, its rev limiter and the launch report
    bangs = false,
    twoStep = false,

    -- Only used by the two options above.
    level = 3, minRpm = 0.55, maxActiveMs = 1500,
    launchMaxActiveMs = 8000, updateMs = 100, timeoutMs = 450,
    volume = 0.92, radius = 240.0,

    -- revLimiter: holds the revs at `rpm` and drops them by up to `dip` on
    --             every ignition cut, so the stock engine note stutters with
    --             the bangs.
    -- clutch:     disengages the clutch while it is armed, so the car builds
    --             revs without a burnout and launches when the brake is let go.
    launch = { revLimiter = true, rpm = 0.74, dip = 0.15, clutch = true }
}

-- ===========================================================================
--  6. EXHAUST HEAT
-- ===========================================================================
--  A cold pipe pops less, duller, with small orange flames and smoke; a hot
--  one crackles more, brighter, with big blue and white flames.
--    start     heat of a car nobody has driven yet, 0 (cold) to 1 (hot)
--    warmUp    how fast driving heats it (1 = about twenty seconds of hard
--              driving)
--    coolDown  how fast it cools (1 = about two minutes)
--  { start = 1.0, coolDown = 0.0 } keeps every pipe hot all the time.
Config.Heat = { start = 0.15, warmUp = 1.0, coolDown = 1.0 }

-- ===========================================================================
--  7. WHAT A BANG DOES BESIDES SOUNDING
-- ===========================================================================
--  Set a table to false to switch all of it off.

--   cameraShake, shake   a short kick of the camera for whoever is in the car
--                        (and, fainter, for someone standing at the pipe of a
--                        boom); shake scales it
--   padRumble            the same kick on a gamepad
Config.Feedback = { cameraShake = true, shake = 1.0, padRumble = true }

--   peds        people within radius metres glance at a car that goes off
--               like a gun
--   alarms      a boom next to a parked, empty car may set off its alarm for
--               a few seconds: within alarmRadius metres, with alarmChance
--               (0-1) per boom
Config.Reactions = { peds = true, radius = 16.0, maxPeds = 6, cooldownMs = 1500,
    alarms = true, alarmRadius = 7.0, alarmChance = 0.25 }

-- ===========================================================================
--  8. THE INTERFACE
-- ===========================================================================
--  The resource's own screens: the work bar, the level selector and the
--  notifications. No mouse and no focus — the game keeps the controls.
--
--   notifications  'own': this resource's notifications, in the style of the
--                  bar (bottom centre, above it)
--                  'framework': ESX / QBCore / Qbox notifications instead
--                  (bridge/framework.lua picks the right one; the GTA feed
--                  is the last resort, so a message is never lost)
--   position       where the bar and the notifications sit: 'bottom' | 'top'
--   scale          size of the screens, 0.8 to 1.4
--   sounds         the sounds of the work, of the selector, of the notices
--   preview        moving through the levels plays one report of each, for
--                  the driver only
--   bonnet         the bonnet opens while the anti-lag kit goes in or out
Config.UI = { notifications = 'own', position = 'bottom', scale = 1.0, sounds = true, preview = true, bonnet = true }

-- ===========================================================================
--  9. ITEMS AND THE WORKSHOP
-- ===========================================================================
--  Using one of these items inside a stopped car opens the workshop screen:
--  the anti-lag kit installs the anti-lag step by step, the removal kit
--  takes it out again, and an exhaust replaces the one on the car. What
--  comes off the car goes into the player's inventory — the stock exhaust
--  the first time a coloured one goes on, the coloured one when another
--  replaces it.
--
--  The item names are the names in your inventory's item list. The
--  definitions to paste are in setup/ (one file per inventory family) and
--  the images in setup/images/. The exhaust items are listed with their
--  colours in config/exhausts.lua.
--
--   enabled          false switches the items off entirely; the commands and
--                    the valve remote keep working
--   jobs             false: anyone may use the items
--                    { 'mechanic', 'tuner' }: only those jobs (needs a
--                    framework — on standalone it cannot be enforced)
--   requireStopped   the car has to stand still
--   consumeRemover   the removal kit is a toolset: false keeps it after use
--   returnKit        removing the anti-lag gives the installation kit back
--   testBang         a fitted exhaust ends with one report out of the new
--                    pipe, for the driver
--   seconds          how long the bar runs for each job. The server refuses
--                    a job finished faster than this, whatever the client says
Config.Items = {
    enabled = true,
    jobs = false,
    requireStopped = true,
    antiLagKit = 'popsbangs_antilag_kit',
    antiLagRemover = 'popsbangs_antilag_remover',
    consumeRemover = false,
    returnKit = true,
    testBang = true,
    seconds = { install = 5, remove = 5, exhaust = 5 }
}

-- ===========================================================================
-- 10. THE VALVE REMOTE
-- ===========================================================================
--  An item that opens a small screen in the car to close or open the
--  exhaust valve. A closed valve is quieter and carries less far.
--    closedVolume   loudness with the valve shut (1 = unchanged)
--    closedRadius   how far it is heard with the valve shut, in metres
Config.Valve = { item = 'popsbangs_valve_control', closedVolume = 0.24, closedRadius = 45 }

--  Native engine and startup audio for custom exhausts only. Keeps each
--  car's own sound bank and GTA positioning.
--  Mixer asset: open +3 dB, closed -9 dB.
Config.Valve.engine = { enabled = true, fadeSeconds = 0.20,
    scene = 'oxlyn_exhaust_valves', openGroup = 'oxlyn_valve_open', closedGroup = 'oxlyn_valve_closed' }

-- ===========================================================================
-- 11. LIMITS, SYNC AND SECURITY
-- ===========================================================================
--  Defaults are tuned for a full server. Raise the cooldowns if you want to
--  be stricter; lower them only with a reason.

-- The shortest gap between two installs by the same player, in ms.
Config.InstallCooldownMs = 600
-- The shortest gap between two synchronisation requests, in ms.
Config.SyncCooldownMs = 2000
-- How many exhaust outlets of one car are used for sound and flames.
Config.MaxExhausts = 6

--  How a burst travels to everyone else.
--    leadMs            local ignition schedule; prediction removes the
--                      driver's server round trip
--    minLeadMs         observers delay a late burst as a whole instead of
--                      clipping its first reports
--    compact           listeners rebuild a burst from its seed and
--                      situation; false sends every pulse over the network
--    maxPacketAgeMs    a burst older than this is dropped instead of played
Config.Sync = {
    leadMs = 30,
    minLeadMs = 25,
    compact = true,
    audioLookaheadMs = 75, maxLateVisualMs = 130, maxPacketAgeMs = 1400,
    maxFutureMs = 300
}

-- How often the driven car is measured while a tune is active.
-- 0 = once per game frame.
Config.Telemetry = { sampleMs = 0 }

-- ===========================================================================
-- 12. PER-MODEL OVERRIDES (advanced)
-- ===========================================================================

-- A model's own voice, instead of the one derived from its class:
--   [joaat('car')] = 'sport', 'muscle' or 'rotary'
--   [joaat('car')] = { pitch = 0.92, body = 160, bright = 0.85, weight = 1.0 }
-- pitch 0.8-1.25 (lower is deeper), body 110-600 Hz (where the report has
-- its chest), bright 0.7-1.2 (how much crack), weight -3 to 3 dB (how much
-- chest). Leave empty to let every car be derived from its class.
Config.EngineProfiles = {}

-- Exact local exhaust positions for unusual addon models, when the bones of
-- the model are not where the pipes are. x = right, y = forward, z = up;
-- overrides take precedence over bones. An optional
-- direction = { x = 1, y = 0, z = 0 } points the audio outward from a side
-- exhaust.
--
-- Config.ExhaustOverrides = { [joaat('mycar')] = {
--     { x = -0.45, y = -2.1, z = 0.25, rx = 0.0, ry = 0.0, rz = 0.0 },
--     { x =  0.45, y = -2.1, z = 0.25, rx = 0.0, ry = 0.0, rz = 0.0 }
-- } }
Config.ExhaustOverrides = {}
--fivevaultsX6OnQuTopw9 : https://discord.gg/fivevault
--fivevault_-nOnZjTopDs : https://discord.gg/fivevault
--fivevaultzbOnuPTopXj : https://discord.gg/fivevault
--fivevault_2FOnumTopNC : https://discord.gg/fivevault
--fivevaultsdEOnb7Top9u : https://discord.gg/fivevault
