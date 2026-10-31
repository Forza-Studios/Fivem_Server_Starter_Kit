Config = {}

-- ============================================================
--  Car Wash Boss Ped Configuration
-- ============================================================

-- Ped model (businessman in a suit looks like a boss/owner)
Config.Boss = {
    model = `a_m_m_business_01`,

    -- Map blip shown at the boss / car wash location
    blip = {
        sprite = 100,      -- car wash icon (radar_car_wash)
        color = 37,        -- light blue
        scale = 0.75,
        shortRange = true,
        name = 'Car Wash Job',
    },

    -- Position: x, y, z, heading
    coords = vec4(-26.8828, -1089.4662, 25.4220, 99.8171),

    -- Scenario animations the boss cycles through.
    -- The first one is played on spawn.
    animations = {
        'WORLD_HUMAN_CLIPBOARD',   -- holding a clipboard
        'WORLD_HUMAN_STAND_MOBILE', -- checking his phone
        'WORLD_HUMAN_SMOKING',      -- taking a smoke break
    },

    -- How often (in milliseconds) the boss switches animation
    animationInterval = { min = 25000, max = 40000 },

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
