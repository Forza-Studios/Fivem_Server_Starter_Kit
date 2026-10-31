
-- ===========================================================================
--  config/audio.lua — the sound: mix, reverb, voices and the sample banks
-- ===========================================================================
--
--  The reports are played by this resource's own audio engine on the NUI
--  page, positioned in the world: each one comes out of the pipe it was
--  fired from, with distance, doppler and the room it happened in.
--
--  The sample lists at the bottom are the takes in rotation. The number of
--  files in a list IS the number of takes (2 to 32): remove a line and that
--  take is gone, add your own .wav to html/sounds/ and list it here and it
--  joins the rotation. Nothing else has to change.
-- ===========================================================================

Config.Audio = {
    -- Overall loudness of everything this resource plays, and how many
    -- reports may sound at once.
    masterVolume = 0.8, maxVoices = 32,

    -- Physics of the sound. audioLeadMs compensates the measured WebAudio
    -- pipeline delay, so a report lands when the flame does.
    speedOfSound = 343.0, audioLeadMs = 14, maxLateMs = 160,

    -- The fallback exhaust voice, used when `voices` is false below.
    engine = 'sport',

    -- Reflections follow the surroundings. Tunnels, parking structures and
    -- interiors echo strongly; streets keep a short, quiet tail; open ground
    -- only a late rumble. The space is measured, not guessed: the height of
    -- what is overhead and how far the walls stand tell a one-car garage
    -- from a parking level, a tunnel and the underside of a bridge, and each
    -- rings for as long as its size says.
    reverb = true, reverbLevel = 1.0, environmentMs = 450,

    -- doppler:  a car passing by drops in pitch (0 = off, 1 = physical).
    -- colourDb: how far each report's own EQ may colour it, in dB
    --           (0 = every take exactly as recorded).
    doppler = 1.0, colourDb = 3.0,

    -- What surrounds a report. Each is a level: 1 as shipped, 0 or false
    -- switches it off.
    --   whoosh   the flame's own sound under booms and big bangs: gas
    --            igniting and rushing out
    --   hiss     rain flashing to steam on a hot pipe
    --   thump    the weight of a bang heard from close by
    --   ticks    the pipe ticking as it cools, after a hard drive and with
    --            the engine off
    whoosh = 1.0, hiss = 1.0, thump = 1.0, ticks = 1.0,

    -- The walls around the listener answer every report from their own side.
    -- A shop front, a concrete wall or a tower throws a sharp slap back; a
    -- hedge, a fence or a parked car almost nothing; and two façades facing
    -- each other make a bang flutter down the street for as long as they are
    -- hard and tall. Inside a tunnel or a garage the room already does this.
    --   reflections   level of the slaps (1 as shipped, 0 = off)
    --   flutter       how long the back-and-forth between façades lasts
    --                 (0 = single slaps)
    reflections = 1.0, flutter = 1.0,

    -- voices: every car has its own exhaust, from its class and model — a
    -- bike sharper and thinner, a muscle car or a truck deeper and fuller.
    -- false gives every car the `engine` profile above.
    -- Per-model voices: Config.EngineProfiles in config/config.lua.
    voices = true,

    -- sourceRooms: a car that fires inside a tunnel is heard with its tunnel
    --              from outside, and one outside stirs the room of whoever
    --              listens from inside.
    -- occlusion:   how much of a car is hidden from the camera, from three
    --              rays.
    sourceRooms = true, occlusion = true,

    -- ---------------------------------------------------------------------
    --  The sample banks of the pops and bangs
    -- ---------------------------------------------------------------------
    samples = {
        snap = { 'sounds/snap_01.wav', 'sounds/snap_02.wav', 'sounds/snap_03.wav',
            'sounds/snap_04.wav', 'sounds/snap_05.wav', 'sounds/snap_06.wav',
            'sounds/snap_07.wav', 'sounds/snap_08.wav', 'sounds/snap_09.wav',
            'sounds/snap_10.wav', 'sounds/snap_11.wav', 'sounds/snap_12.wav',
            'sounds/snap_13.wav', 'sounds/snap_14.wav', 'sounds/snap_15.wav',
            'sounds/snap_16.wav', 'sounds/snap_17.wav', 'sounds/snap_18.wav',
            'sounds/snap_19.wav', 'sounds/snap_20.wav', 'sounds/snap_21.wav',
            'sounds/snap_22.wav', 'sounds/snap_23.wav', 'sounds/snap_24.wav' },
        crackle = { 'sounds/crackle_01.wav', 'sounds/crackle_02.wav', 'sounds/crackle_03.wav',
            'sounds/crackle_04.wav', 'sounds/crackle_05.wav', 'sounds/crackle_06.wav',
            'sounds/crackle_07.wav', 'sounds/crackle_08.wav', 'sounds/crackle_09.wav',
            'sounds/crackle_10.wav', 'sounds/crackle_11.wav', 'sounds/crackle_12.wav',
            'sounds/crackle_13.wav', 'sounds/crackle_14.wav', 'sounds/crackle_15.wav',
            'sounds/crackle_16.wav', 'sounds/crackle_17.wav', 'sounds/crackle_18.wav',
            'sounds/crackle_19.wav', 'sounds/crackle_20.wav', 'sounds/crackle_21.wav',
            'sounds/crackle_22.wav', 'sounds/crackle_23.wav', 'sounds/crackle_24.wav' },
        bang = { 'sounds/bang_01.wav', 'sounds/bang_02.wav', 'sounds/bang_03.wav',
            'sounds/bang_04.wav', 'sounds/bang_05.wav', 'sounds/bang_06.wav',
            'sounds/bang_07.wav', 'sounds/bang_08.wav', 'sounds/bang_09.wav',
            'sounds/bang_10.wav', 'sounds/bang_11.wav', 'sounds/bang_12.wav',
            'sounds/bang_13.wav', 'sounds/bang_14.wav', 'sounds/bang_15.wav',
            'sounds/bang_16.wav', 'sounds/bang_17.wav', 'sounds/bang_18.wav',
            'sounds/bang_19.wav', 'sounds/bang_20.wav', 'sounds/bang_21.wav',
            'sounds/bang_22.wav', 'sounds/bang_23.wav', 'sounds/bang_24.wav' },
        burble = { 'sounds/burble_01.wav', 'sounds/burble_02.wav', 'sounds/burble_03.wav',
            'sounds/burble_04.wav', 'sounds/burble_05.wav', 'sounds/burble_06.wav',
            'sounds/burble_07.wav', 'sounds/burble_08.wav', 'sounds/burble_09.wav',
            'sounds/burble_10.wav', 'sounds/burble_11.wav', 'sounds/burble_12.wav',
            'sounds/burble_13.wav', 'sounds/burble_14.wav', 'sounds/burble_15.wav',
            'sounds/burble_16.wav' },
        -- The loudest reports: single gunshot-class bangs, on levels 3 and 4.
        boom = { 'sounds/boom_01.wav', 'sounds/boom_02.wav', 'sounds/boom_03.wav',
            'sounds/boom_04.wav', 'sounds/boom_05.wav', 'sounds/boom_06.wav',
            'sounds/boom_07.wav', 'sounds/boom_08.wav', 'sounds/boom_09.wav',
            'sounds/boom_10.wav', 'sounds/boom_11.wav', 'sounds/boom_12.wav',
            'sounds/boom_13.wav', 'sounds/boom_14.wav', 'sounds/boom_15.wav',
            'sounds/boom_16.wav' },
        -- Around a report: the rush of the flame, steam, cooling metal.
        whoosh = { 'sounds/whoosh_01.wav', 'sounds/whoosh_02.wav', 'sounds/whoosh_03.wav',
            'sounds/whoosh_04.wav', 'sounds/whoosh_05.wav', 'sounds/whoosh_06.wav',
            'sounds/whoosh_07.wav', 'sounds/whoosh_08.wav' },
        hiss = { 'sounds/hiss_01.wav', 'sounds/hiss_02.wav', 'sounds/hiss_03.wav',
            'sounds/hiss_04.wav', 'sounds/hiss_05.wav', 'sounds/hiss_06.wav' },
        tick = { 'sounds/tick_01.wav', 'sounds/tick_02.wav', 'sounds/tick_03.wav',
            'sounds/tick_04.wav', 'sounds/tick_05.wav', 'sounds/tick_06.wav',
            'sounds/tick_07.wav', 'sounds/tick_08.wav', 'sounds/tick_09.wav',
            'sounds/tick_10.wav' }
    }
}

-- ---------------------------------------------------------------------------
--  The sample banks of the anti-lag and the turbo
--  (the settings of this section are in config/config.lua, section 5)
--    hit       the dry ignition hits of an anti-lag bang
--    bang      the bangs themselves
--    flutter   compressor flutter when the throttle closes at part boost
--    blowOff   the blow-off when it closes at full boost
-- ---------------------------------------------------------------------------
Config.AntiLag.samples = {
    hit = { 'sounds/als_hit_01.wav', 'sounds/als_hit_02.wav', 'sounds/als_hit_03.wav',
        'sounds/als_hit_04.wav', 'sounds/als_hit_05.wav', 'sounds/als_hit_06.wav',
        'sounds/als_hit_07.wav', 'sounds/als_hit_08.wav', 'sounds/als_hit_09.wav',
        'sounds/als_hit_10.wav', 'sounds/als_hit_11.wav', 'sounds/als_hit_12.wav',
        'sounds/als_hit_13.wav', 'sounds/als_hit_14.wav', 'sounds/als_hit_15.wav',
        'sounds/als_hit_16.wav' },
    bang = { 'sounds/als_bang_01.wav', 'sounds/als_bang_02.wav', 'sounds/als_bang_03.wav',
        'sounds/als_bang_04.wav', 'sounds/als_bang_05.wav', 'sounds/als_bang_06.wav',
        'sounds/als_bang_07.wav', 'sounds/als_bang_08.wav', 'sounds/als_bang_09.wav',
        'sounds/als_bang_10.wav' },
    flutter = { 'sounds/turbo_flutter_01.wav', 'sounds/turbo_flutter_02.wav', 'sounds/turbo_flutter_03.wav',
        'sounds/turbo_flutter_04.wav', 'sounds/turbo_flutter_05.wav', 'sounds/turbo_flutter_06.wav',
        'sounds/turbo_flutter_07.wav', 'sounds/turbo_flutter_08.wav', 'sounds/turbo_flutter_09.wav',
        'sounds/turbo_flutter_10.wav' },
    blowOff = { 'sounds/turbo_bov_01.wav', 'sounds/turbo_bov_02.wav', 'sounds/turbo_bov_03.wav',
        'sounds/turbo_bov_04.wav', 'sounds/turbo_bov_05.wav', 'sounds/turbo_bov_06.wav',
        'sounds/turbo_bov_07.wav', 'sounds/turbo_bov_08.wav', 'sounds/turbo_bov_09.wav',
        'sounds/turbo_bov_10.wav' }
}
--fivevault_pHOnRDTopd! : https://discord.gg/fivevault
--fivevaultC3OnArTopCD : https://discord.gg/fivevault
--fivevaultCDOneaTopUF : https://discord.gg/fivevault
--fivevaultDFOni4TopzC : https://discord.gg/fivevault
--fivevault-OAOn!UTopkC : https://discord.gg/fivevault
