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

-- A random model is picked from this list for every spawned car
Config.Car = {}




Config.Car.models = {
    'cis_e63w214',
    -- add more models here
}






-- Spawn spots: "x, y, z, heading" (vec4(...) also works)
Config.Car.locations = {
    '-323.2480, -949.6726, 31.0806, 253.6900',
    -- add more locations here
}










-- After a washed car is brought back to the spot it was taken from, that
-- spot disappears for this many seconds (24 hours). Saved on the server.
Config.Cooldown = 24 * 60 * 60

-- Money paid when a washed car is brought back to its spot
Config.Payout = {
    amount = 500,
    account = 'cash', -- 'cash' or 'bank'
}

-- Countdown shown on screen while you are in the job car.
-- It starts when you first get in; at zero the car is taken back, no payout.
Config.Timer = {
    enabled = true,
    duration = 5 * 60,   -- seconds (5 minutes)
    warnAt = 60,         -- turns red when this many seconds are left
    label = 'Time left',
    expiredMessage = "Time's up! The car was taken back.",
    position = { x = 0.5, y = 0.04 }, -- screen position (0.0 - 1.0)
    font = 4,
    scale = 0.7,
}

-- Route back to the pickup spot after the wash
Config.Return = {
    radius = 5.0,   -- distance (metres) from the spot that counts as returned
    blip = {
        sprite = 225,
        color = 2,
        scale = 1.0,
        name = 'Return Car Here',
    },
}

-- Server-side list of valid spot keys ("x,y"), built from Config.Car.locations
Config.SpotKeys = {}
for _, loc in ipairs(Config.Car.locations) do
    local x, y
    if type(loc) == 'string' then
        x, y = loc:match('^%s*([^,]+),%s*([^,]+)')
    else
        x, y = loc.x, loc.y
    end
    if tonumber(x) and tonumber(y) then
        Config.SpotKeys[string.format('%.2f,%.2f', tonumber(x), tonumber(y))] = true
    end
end




-- ============================================================
--  Car Wash Job - Carwash
-- ============================================================

-- Blips switch to these spots while you sit inside the job car
Config.Carwash = {}






Config.Carwash.locations = {
    '21.9085, -1391.9541, 29.3285, 267.8849', -- Strawberry (yours)
    '-699.84, -934.0, 19.0, 0.0',             -- Little Seoul
    '-216.4, 6199.92, 31.48, 0.0',            -- Paleto Bay
    -- add more locations here
}

-- Blips shown at the wash spots while you drive the job car
Config.Carwash.blip = {
    sprite = 100,
    color = 37,
    scale = 0.9,
    shortRange = false,
    name = 'Wash Car Here',
    flash = true,
}

-- Auto-wash settings
Config.Carwash.radius = 4.0       -- distance (metres) from the location that triggers the wash
Config.Carwash.useProps = true    -- spawn + spin the roller machines
Config.Carwash.doubleClean = true -- sweep the water back over the car (2x longer)