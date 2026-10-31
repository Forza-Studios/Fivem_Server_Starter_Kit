Config = Config or {}

Config.Fun = {
    Animations = {
        { Label = 'The Woogie', Dict = 'anim@mp_player_intcelebrationmale@the_woogie', Name = 'the_woogie' },
        { Label = 'Salsa Roll', Dict = 'anim@mp_player_intcelebrationfemale@salsa_roll', Name = 'salsa_roll' },
        { Label = 'Uncle Disco', Dict = 'anim@mp_player_intcelebrationmale@uncle_disco', Name = 'uncle_disco' },
        { Label = 'Disco Fever', Dict = 'anim@mp_player_intcelebrationmale@disco_fever', Name = 'disco_fever' },
        { Label = 'Banging Tunes', Dict = 'anim@mp_player_intcelebrationmale@banging_tunes', Name = 'banging_tunes' },
        { Label = 'Heart Pumping', Dict = 'anim@mp_player_intcelebrationmale@heart_pumping', Name = 'heart_pumping' },
        { Label = 'Slow Clap', Dict = 'anim@mp_player_intcelebrationmale@slow_clap', Name = 'slow_clap' },
        { Label = 'Dog Fight', Dict = 'anim@mp_player_intcelebrationmale@dog_fight', Name = 'dog_fight' },
        { Label = 'Finders Keepers', Dict = 'anim@mp_player_intcelebrationmale@finders_keepers', Name = 'finders_keepers' },
        { Label = 'Flappy Bird', Dict = 'anim@mp_player_intcelebrationmale@flappy_bird', Name = 'flappy_bird' },
        { Label = 'Chicken Taunt', Dict = 'anim@mp_player_intcelebrationmale@chicken_taunt', Name = 'chicken_taunt' },
        { Label = 'Cats Cradle', Dict = 'anim@mp_player_intcelebrationmale@cats_cradle', Name = 'cats_cradle' },
        { Label = 'Air Guitar', Dict = 'anim@mp_player_intcelebrationmale@air_guitar', Name = 'air_guitar' },
        { Label = 'Air Synth', Dict = 'anim@mp_player_intcelebrationmale@air_synth', Name = 'air_synth' },
        { Label = 'Jazz Hands', Dict = 'anim@mp_player_intcelebrationmale@jazz_hands', Name = 'jazz_hands' },
        { Label = 'Snap Fingers', Dict = 'anim@mp_player_intcelebrationmale@snap_fingers', Name = 'snap_fingers' },
        { Label = 'Thumb Up', Dict = 'anim@mp_player_intcelebrationmale@thumbs_up', Name = 'thumbs_up' },
        { Label = 'Peace Out', Dict = 'anim@mp_player_intcelebrationmale@peace', Name = 'peace' },
        { Label = 'Surrender', Dict = 'random@arrests@busted', Name = 'idle_a' },
        { Label = 'Yoga', Dict = 'amb@world_human_yoga@male@base', Name = 'base_a' },
        { Label = 'Workout', Dict = 'amb@world_human_muscle_free_weights@male@barbell@base', Name = 'base' },
        { Label = 'Mechanic', Dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig28@', Name = 'base' },
        { Label = 'Sit', Dict = 'anim@amb@business@bip@base@ig_1@', Name = 'base_ig_1' },
    },

    -- Commands the "Force Animation" custom command may make a player run. Only
    -- the first word is checked. The command runs with the TARGET's permissions,
    -- so keep this to emote commands.
    ForceCommandWhitelist = { 'e', 'emote', 'em', 'walk', 'walkstyle' },

    JailboxCoords = vec3(-76.0167, -821.8925, 222.0004),

    Kidnap = {
        VanModel = 'burrito3',
        EscortModel = 'granger',
        PedModel = 's_m_m_chemsec_01',
        Weapon = 'WEAPON_MICROSMG',
        DropLocations = {
            vec3(2530.0, 4833.0, 34.0),
            vec3(1461.0, 6552.0, 14.0),
            vec3(-2182.3318, 5185.022, 16.8823),
            vec3(2900.0, 4440.0, 48.0),
            vec3(2400.0, 3000.0, 45.0),
            vec3(2840.0, -1440.0, 10.0),
            vec3(-2999.4221, 1500.4246, 27.9133),
        },
    },

    Ufo = {
        Model = 'p_spinning_anus_s',
        Height = 200.0,
        LandingCoords = vec3(-1171.714233, 4926.791016, 224.198486),
    },

    Ghost = {
        Models = {
            'm23_1_prop_m31_ghostsalton_01a',
            'm23_1_prop_m31_ghostskidrow_01a',
            'm23_1_prop_m31_ghostzombie_01a',
            'm23_1_prop_m31_ghostrurmeth_01a',
            'm23_1_prop_m31_ghostjohnny_01a',
        },
        AnimDict = 'ANIM@SCRIPTED@FREEMODE@IG2_GHOST@',
        AnimName = 'float_1',
        ParticleDict = 'scr_srr_hal',
        ParticleName = 'scr_srr_hal_ghost_haze',
    },

    AttackAnimals = { 'a_c_chimp', 'a_c_rottweiler', 'a_c_coyote' },
}
