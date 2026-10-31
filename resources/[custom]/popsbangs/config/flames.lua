
-- ===========================================================================
--  config/flames.lua — the flames: layers, styles and particles
-- ===========================================================================
--
--  Every layer is a stock GTA effect, so nothing here has to be streamed for
--  the flames to work. Set a layer to false to disable it.
--
--  The one streamed part is the coloured copies in stream/: the same flame
--  geometry, density and timing as the stock effect, baked once per supplied
--  exhaust colour (config/exhausts.lua). Switch Config.ColouredFlames off
--  and every exhaust burns in the stock colours instead.
-- ===========================================================================

Config.ColouredFlames = { enabled = true }

-- ---------------------------------------------------------------------------
--  Flames
--    scale        overall flame size multiplier
--    tint         colours: exhaust heat (orange -> yellow-white -> pale
--                 blue) or the style's own
--    purple       the hottest part of the biggest flames turns violet
--    flash        bangs and booms light up the surroundings for an instant
--
--    situational  flame styles follow the situation (see README);
--                 false = the same odds everywhere
--    alternate    lighter pops fire from one bank of pipes at a time;
--                 false = always every pipe
--    glow         the tip of a pipe that has been spitting fire stays
--                 red-hot for seconds
--    wisp         a long burst leaves a wisp of smoke behind
--    rain         rain on a hot pipe turns to steam, and cools its glow
--                 faster
--    dayLight     how much stronger the lights are by day, when the sun
--                 washes them out
-- ---------------------------------------------------------------------------
Config.Particle = {
    asset = 'core', name = 'veh_backfire', narrowName = 'veh_backfire_narrow',
    scale = 1.0, maxScale = 3.6, maxActive = 160, minDurationMs = 85,
    dualLayer = true, tint = true, purple = true, flash = true,
    situational = true, alternate = true, glow = true, glowIntensity = 1.3, wisp = true, rain = true,
    dayLight = 1.45,

    -- Flame styles. One is drawn per ignition from those its energy allows,
    -- so a phrase mixes shapes, sizes and colours; every player sees the
    -- same one.
    --   dart       thin white-yellow lick            ember      short deep-red rich burn
    --   plume      classic orange backfire           blue       lean, hot blue jet
    --   tongue     long amber tongue                 afterburn  pale yellow afterburner cone
    --   fireball   wide, big orange-red ball         rocket     white-hot lance (bangs)
    --   violet     big purple inferno (booms)        inferno    stylised orange-red burst (bangs)
    --   thruster   narrow white-blue jet             pyro       plane afterburner, amber
    --   vigilante  big rocket lance (bangs)          whitehot   brilliant white-blue core
    --   green      rare green flame                  twin       two licks from one ignition
    --   sparkler   small flame with a spray of sparks sooty     dirty orange burn with black smoke
    --   flicker    three quick small licks           lance      long thin jet, drawn out by speed
    --   bloom      wide short ball, standing still
    --
    -- `styles = { rocket = false }` removes one; `{ violet = { big = 30 } }`
    -- makes it more common on booms; `{ blue = { weight = 6 } }` more common
    -- elsewhere; `{ green = { colour = { 1.0, 0.2, 0.8 } } }` changes a
    -- colour (RGB 0-1).
    styles = {},

    -- Effects used by the styles and particles.
    jet = { asset = 'veh_xs_vehicle_mods', name = 'veh_nitrous', scale = 0.55, minEnergy = 0.50 },
    small = { asset = 'core', name = 'veh_sm_car_small_backfire' },
    afterburner = { asset = 'core', name = 'veh_exhaust_afterburner' },
    rocket = { asset = 'veh_impexp_rocket', name = 'veh_rocket_boost' },
    sanctus = { asset = 'veh_sanctus', name = 'veh_sanctus_backfire' },
    thruster = { asset = 'veh_thruster', name = 'veh_xm_thruster_afterburner' },
    pyro = { asset = 'veh_sm_pyro', name = 'veh_exhaust_afterburner_pyro' },
    vigilante = { asset = 'veh_sm_vig', name = 'veh_rocket_boost_vig' },

    -- Particles: sparks and smoke on bangs; embers and heat haze on booms.
    sparks = { asset = 'core', name = 'veh_train_sparks', scale = 0.45, durationMs = 130 },
    wire = { asset = 'core', name = 'ent_brk_sparking_wires', scale = 0.35, durationMs = 160 },
    smoke = { asset = 'core', name = 'veh_exhaust_misfire', scale = 0.9, durationMs = 320 },
    embers = { asset = 'core', name = 'ent_ray_heli_aprtmnt_embers', scale = 0.30, durationMs = 550 },
    haze = { asset = 'core', name = 'ent_amb_foundry_heat_haze', scale = 0.25, durationMs = 900 },
    steam = { asset = 'core', name = 'ent_sht_steam', scale = 0.30, durationMs = 450 },

    light = true, lightRange = 3.4, lightIntensity = 2.6
}
--fivevault-JbOn9gTopWG : https://discord.gg/fivevault
--fivevault_GlOnFcTopin : https://discord.gg/fivevault
--fivevault_8NOnn3Top@@ : https://discord.gg/fivevault
--fivevaults-lOnn_Topm2 : https://discord.gg/fivevault
--fivevaultskBOn32TopJZ : https://discord.gg/fivevault
