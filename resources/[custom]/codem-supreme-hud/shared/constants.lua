--[[
    ╔═══════════════════════════════════════════════════════════════╗
    ║                       CONSTANTS                               ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  Centralized constants for the entire HUD system              ║
    ║  Avoids magic numbers and improves code readability           ║
    ╚═══════════════════════════════════════════════════════════════╝
]]

Constants = {}

-- ═══════════════════════════════════════════════════════════════
-- MATH & CONVERSION
-- ═══════════════════════════════════════════════════════════════

Constants.Math = {
    KMH_FACTOR = 3.6,           -- m/s to km/h conversion
    MPH_FACTOR = 2.236936,      -- m/s to mph conversion
    FULL_ROTATION = 360,        -- Full circle in degrees
    HALF_ROTATION = 180,        -- Half circle in degrees
    HEADING_OFFSET = 90,        -- GTA heading system offset
}

-- ═══════════════════════════════════════════════════════════════
-- VEHICLE CLASSES
-- ═══════════════════════════════════════════════════════════════
-- https://docs.fivem.net/natives/?_0x29439776AAA00A62

Constants.VehicleClass = {
    COMPACTS = 0,
    SEDANS = 1,
    SUVS = 2,
    COUPES = 3,
    MUSCLE = 4,
    SPORTS_CLASSICS = 5,
    SPORTS = 6,
    SUPER = 7,
    MOTORCYCLES = 8,
    OFFROAD = 9,
    INDUSTRIAL = 10,
    UTILITY = 11,
    VANS = 12,
    CYCLES = 13,           -- Bicycles
    BOATS = 14,
    HELICOPTERS = 15,
    PLANES = 16,
    SERVICE = 17,
    EMERGENCY = 18,
    MILITARY = 19,
    COMMERCIAL = 20,
    TRAINS = 21,
}

-- Vehicle class name lookup (for display)
Constants.VehicleClassName = {
    [0] = 'Compacts', [1] = 'Sedans', [2] = 'SUVs', [3] = 'Coupes',
    [4] = 'Muscle', [5] = 'Sports Classics', [6] = 'Sports', [7] = 'Super',
    [8] = 'Motorcycles', [9] = 'Off-road', [10] = 'Industrial',
    [11] = 'Utility', [12] = 'Vans', [13] = 'Cycles', [14] = 'Boats',
    [15] = 'Helicopters', [16] = 'Planes', [17] = 'Service', [18] = 'Emergency',
    [19] = 'Military', [20] = 'Commercial', [21] = 'Trains'
}

-- Helper function to check vehicle class categories
Constants.IsAircraft = function(vehicleClass)
    return vehicleClass == Constants.VehicleClass.HELICOPTERS
        or vehicleClass == Constants.VehicleClass.PLANES
end

Constants.IsBicycle = function(vehicleClass)
    return vehicleClass == Constants.VehicleClass.CYCLES
end

Constants.IsBoat = function(vehicleClass)
    return vehicleClass == Constants.VehicleClass.BOATS
end

Constants.IsMotorcycle = function(vehicleClass)
    return vehicleClass == Constants.VehicleClass.MOTORCYCLES
end

Constants.IsEmergency = function(vehicleClass)
    return vehicleClass == Constants.VehicleClass.EMERGENCY
end

-- ═══════════════════════════════════════════════════════════════
-- CONTROL INPUTS
-- ═══════════════════════════════════════════════════════════════
-- https://docs.fivem.net/docs/game-references/controls/

Constants.Controls = {
    -- Player controls
    SPRINT = 21,            -- Shift (also nitro)
    HORN = 86,              -- E
    VEH_EXIT = 75,          -- F
    VEH_HEADLIGHT = 74,     -- H
    ATTACK = 24,            -- Left Mouse
    AIM = 25,               -- Right Mouse
    CHAT = 245,             -- T
    -- Mouse controls
    MOUSE_LOOK_LR = 1,      -- Mouse look left/right
    MOUSE_LOOK_UD = 2,      -- Mouse look up/down
    MOUSE_VEHICLE = 106,    -- Mouse control override (vehicle steering)
    -- Navigation/Menu controls (fastnav, radial menus)
    ARROW_LEFT = 174,       -- Left Arrow
    ARROW_RIGHT = 175,      -- Right Arrow
    ARROW_UP = 172,         -- Up Arrow
    ARROW_DOWN = 173,       -- Down Arrow
    BACKSPACE = 177,        -- Backspace/Cancel
    ENTER = 191,            -- Enter/Select
    RADIO_WHEEL = 85,       -- Q - Radio wheel
}

-- Controls to disable when HUD NUI focus is active (settings panel, music, etc)
Constants.DisabledControlsInNui = {
    Constants.Controls.ATTACK,          -- 24 - Left click shooting
    Constants.Controls.AIM,             -- 25 - Right click aiming
    Constants.Controls.MOUSE_LOOK_LR,   -- 1 - Mouse look horizontal
    Constants.Controls.MOUSE_LOOK_UD,   -- 2 - Mouse look vertical
    Constants.Controls.MOUSE_VEHICLE,   -- 106 - Mouse vehicle steering
}

-- ═══════════════════════════════════════════════════════════════
-- BLIP TYPES
-- ═══════════════════════════════════════════════════════════════

Constants.BlipType = {
    WAYPOINT = 8,
    NORTH = 0,
}

-- ═══════════════════════════════════════════════════════════════
-- DOOR LOCK STATUS
-- ═══════════════════════════════════════════════════════════════

Constants.DoorLock = {
    UNLOCKED = 1,
    LOCKED = 2,
    LOCKED_PLAYER_INSIDE = 3,
    LOCKED_PLAYER_OUTSIDE = 4,
}

-- ═══════════════════════════════════════════════════════════════
-- WEATHER TYPES
-- ═══════════════════════════════════════════════════════════════

Constants.WeatherHash = {
    [916995460] = 'CLEAR',
    [-1750463879] = 'EXTRASUNNY',
    [821931868] = 'CLOUDS',
    [-1148613331] = 'OVERCAST',
    [1420204096] = 'RAIN',
    [1840358669] = 'CLEARING',
    [-1233681761] = 'THUNDER',
    [282916021] = 'FOGGY',
    [-273223690] = 'SMOG',
    [-1429616491] = 'XMAS',
    [603685163] = 'SNOW',
    [669657108] = 'SNOWLIGHT',
    [669657109] = 'BLIZZARD',
}

Constants.WeatherToHudIcon = {
    ['CLEAR'] = 'clear',
    ['EXTRASUNNY'] = 'clear',
    ['CLOUDS'] = 'clouds',
    ['OVERCAST'] = 'clouds',
    ['RAIN'] = 'rain',
    ['CLEARING'] = 'clouds',
    ['THUNDER'] = 'thunder',
    ['SMOG'] = 'fog',
    ['FOGGY'] = 'fog',
    ['XMAS'] = 'snow',
    ['SNOWLIGHT'] = 'snow',
    ['BLIZZARD'] = 'snow',
    ['SNOW'] = 'snow',
    ['NEUTRAL'] = 'clear',
}

-- ═══════════════════════════════════════════════════════════════
-- CACHE & TIMING
-- ═══════════════════════════════════════════════════════════════

Constants.Cache = {
    SOCIETY_TTL = 10000,        -- Society money cache lifetime (ms)
    VEHICLE_TTL = 5000,         -- Vehicle data cache lifetime (ms)
    PLAYER_INFO_TTL = 5000,     -- Player info cache lifetime (ms)
}

Constants.Intervals = {
    HUD_UPDATE = 500,           -- Default HUD update interval (ms)
    LOCATION_UPDATE = 1000,     -- Location/zone update interval (ms)
    MINIMAP_CHECK = 2000,       -- Minimap resolution check interval (ms)
}

-- ═══════════════════════════════════════════════════════════════
-- VEHICLE MUSIC
-- ═══════════════════════════════════════════════════════════════

Constants.Music = {
    DETECTION_DISTANCE = 15.0,  -- Max distance to hear nearby music
    TIME_UPDATE_INTERVAL = 200, -- Music time sync interval (ms)
    TIME_DRIFT_THRESHOLD = 2.0, -- Max allowed time drift (seconds)
    NEARBY_CHECK_INTERVAL = 2000, -- Nearby vehicle scan interval (ms)
}

-- ═══════════════════════════════════════════════════════════════
-- SPEEDOMETER
-- ═══════════════════════════════════════════════════════════════

Constants.Speedometer = {
    RPM_SMOOTHING = 0.85,       -- RPM lerp factor (0-1, higher = smoother)
    FUEL_CHECK_INTERVAL = 20,   -- Fuel check every N frames
}

-- ═══════════════════════════════════════════════════════════════
-- STRESS SYSTEM
-- ═══════════════════════════════════════════════════════════════

Constants.Stress = {
    SCREEN_SHAKE_THRESHOLD = 75, -- Stress level to start screen shake
    SCREEN_BLUR_THRESHOLD = 90,  -- Stress level to start screen blur
    BLACKOUT_THRESHOLD = 100,    -- Stress level for blackout
}
