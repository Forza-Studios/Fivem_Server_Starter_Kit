Config = {}

-- ============================================================
--  Car Wash Boss Ped Configuration
-- ============================================================

-- Ped model (businessman in a suit looks like a boss/owner)
Config.Boss = {
    model = `a_m_m_business_01`,

    -- Map blip shown at the boss / car wash location
    blip = {
        sprite = 380,      -- car wash icon (radar_car_wash)
        color = 37,        -- light blue
        scale = 1.0,
        shortRange = true,
        name = 'Car Wash Job',
    },

    -- Position: x, y, z, heading
    coords = vec4(-26.8828, -1089.4662, 25.4220, 99.8171),

    -- Scenario animations the boss cycles through.
    -- The first one is played on spawn.
    -- 'PHONE_CALL' is a special entry -> he holds the phone to his ear and talks on it.
    animations = {
        'PHONE_CALL', -- talking on his phone
    },

    -- Animation + prop used by the 'PHONE_CALL' entry above
    phone = {
        dict = 'amb@world_human_stand_mobile@male@standing@call@base',
        clip = 'base',
        prop = `prop_npc_phone_02`,
        bone = 28422,                        -- right hand
        offset = vector3(0.0, 0.0, 0.0),
        rotation = vector3(0.0, 0.0, 0.0),
    },

    -- How often (in milliseconds) the boss switches animation
    animationInterval = { min = 25000, max = 40000 },

    -- Continuous chatter: the boss talks non-stop (voice + mouth movement)
    dialogue = {
        enabled = true,

        -- Pause (in milliseconds) between voice lines — 1 second = non-stop talking
        delay = 1000,

        -- Only talk when a player is within this distance (metres)
        maxDistance = 20.0,

        -- Say a random line when someone starts/stops the job
        greetOnInteract = true,

        -- A random voice is picked for every line, so he never sounds the same.
        -- These are all valid GTA V business ped voice sets.
        voices = {
            'A_M_M_BUSINESS_01_WHITE_FULL_01',
           
        },

        -- Real GTA V ambient speech lines (shared by all voices above)
        lines = {
            'GENERIC_HI',                  -- "Hey there"
            'GENERIC_HOWS_IT_GOING',       -- "How's it going?"
            'GENERIC_YES',
            'GENERIC_NO',
            'GENERIC_THANKS',
            'GENERIC_BUY',
            'GENERIC_WHATEVER',
            'CHAT_STATE',
            'CHAT_RESP',
            'CHAT_ACROSS_STREET_STATE',
            'PED_RANT_01',                 -- rambling about something
            'OVER_THERE',
            'UP_THERE',
            'SEE_WEIRDO',
            'APOLOGY_NO_TROUBLE',
            'KIFFLOM_GREET',
            'WON_DISPUTE',
        },

        -- Lines used while he is on the phone (real GTA phone-call dialogue)
        phoneLines = {
            'PHONE_CONV1_INTRO',
            'PHONE_CONV1_CHAT1',
            'PHONE_CONV1_CHAT2',
            'PHONE_CONV1_CHAT3',
            'PHONE_CONV1_OUTRO',
            'PHONE_CONV2_INTRO',
            'PHONE_CONV2_CHAT1',
            'PHONE_CONV2_CHAT2',
            'PHONE_CONV2_CHAT3',
            'PHONE_CONV2_OUTRO',
        },
    },

    -- Interaction shown when pointing at the boss
    target = {
        startLabel = 'Start Car Wash Job',
        stopLabel = 'Stop Car Wash Job',
        icon = 'fa-solid fa-soap',
        stopIcon = 'fa-solid fa-stop',
        distance = 2.5,

        -- Notifications
        notifyTitle = 'Car Wash',
        startedMessage = 'You started the car wash job!',
        stoppedMessage = 'You stopped the car wash job.',
    },
}




-- ============================================================
--  Car Wash Job - Car
-- ============================================================

Config.Car = {
    -- Model spawned when the job starts
    model = 'tiptruck2',

    -- Spawn spots: "x, y, z, heading" (vec4(...) also works)
    locations = {
        '-28.1574, -1082.2430, 26.6245, 61.9880',
        -- add more locations here
    },
}