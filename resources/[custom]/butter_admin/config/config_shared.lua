Config = Config or {}

-- Console output. Errors and warnings are worth keeping on; debug is verbose.
Config.Debug = {
    Error = true,
    Warn = true,
    Debug = false,
}

Config.ServerName = 'Butter Admin'
Config.Identifier = 'license' -- 'license' or 'steam', the primary ID shown in the UI

-- How players are labelled in lists: 'Both' = CharName (PlayerName), 'Steam' / 'Fivem' = player name, 'Character' = character name
Config.PlayerName = 'Character'
-- Identifier shown next to names: 'PrimaryId', 'License', 'Discord', 'Steam', 'Fivem', 'SteamName', 'FivemName'
Config.LicenseType = 'Discord'

Config.Menu = {
    OpenKey = 'INSERT',
    Commands = {
        Open = 'menuopen',
        Reset = 'menureset',
        Report = 'report',
        DirectMessages = 'dmchat',
    },
}

Config.DutySystem = {
    Enabled = true,
    Command = 'adminduty',
    Alias = 'duty',
    RestrictAdminActions = true, -- admins must be on duty to use admin actions
}

Config.DevMode = {
    Invincible = true, -- keep the admin invincible while dev mode is on
    -- Runs whenever dev mode is toggled, e.g. to sync other resources.
    OnToggle = function(enabled)
        TriggerEvent('qb-admin:client:ToggleDevmode', enabled)
    end,
}

Config.Noclip = {
    FallInAir = false, -- true keeps you in the air when noclip is turned off
}

Config.EnableMonitoring = false -- Monitoring page (needs the screencapture resource for live view)

Config.PlayerNames = {
    Range = 300.0,
    ShowLines = true,
    LineColor = { r = 255, g = 0, b = 0 },
    NameColor = { r = 255, g = 0, b = 0 },
    NameScale = {
        Near = 0.45,
        Far = 0.20,
        MaxDistance = 100.0, -- distance at which the text reaches the Far scale
    },
}

Config.Blips = {
    Player = {
        Sprite = 1,
        Color = 4,
        Scale = 0.75,
        ShowName = true,
        LabelPrefix = '',
    },
    Staff = {
        Sprite = 1,
        Color = 3,
        Scale = 0.85,
        ShowName = true,
        LabelPrefix = '[Staff] ',
    },
}

Config.WeatherTypes = {
    { label = 'Extra Sunny', value = 'EXTRASUNNY' },
    { label = 'Clear', value = 'CLEAR' },
    { label = 'Neutral', value = 'NEUTRAL' },
    { label = 'Smog', value = 'SMOG' },
    { label = 'Foggy', value = 'FOGGY' },
    { label = 'Overcast', value = 'OVERCAST' },
    { label = 'Clouds', value = 'CLOUDS' },
    { label = 'Clearing', value = 'CLEARING' },
    { label = 'Rain', value = 'RAIN' },
    { label = 'Thunder', value = 'THUNDER' },
    { label = 'Snow', value = 'SNOW' },
    { label = 'Blizzard', value = 'BLIZZARD' },
    { label = 'Snow Light', value = 'SNOWLIGHT' },
    { label = 'Xmas', value = 'XMAS' },
    { label = 'Halloween', value = 'HALLOWEEN' },
}
