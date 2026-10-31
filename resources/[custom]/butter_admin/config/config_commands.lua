Config = Config or {}

--[[
    Menu commands, grouped by category. Every item Id is also the permission
    that grants it in Access Control.

    Item fields:
        Id          permission id and internal reference
        Name        label in the menu
        Event       event fired when the command runs
        EventType   'Client' (local event) or 'Server' (server net event), defaults to 'Client'
        Collapse    true opens a form with Options, false runs on click
        CloseMenu   close the menu after running
        DevKey      key that runs the command while dev mode is on
        DevResult   payload sent when the DevKey is used
        StaticResult payload sent when a non-collapsed command is clicked
        Options     form fields (see below)

    Option fields:
        { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true }       online player picker
        { Id = 'mode', Name = 'Mode', Type = 'input-choice', Choices = { { Text = 'A' } } } static list
        { Id = 'item', Name = 'Item', Type = 'input-choice', Choices = 'items' }            provider (see modules/menu)
        { Id = 'amount', Name = 'Amount', Type = 'input', InputType = 'number' }           number / text input
        { Id = 'sit', Name = 'Sit Inside', Type = 'checkbox' }                             checkbox
]]

Config.CommandList = {
    {
        Id = 'player',
        Name = 'Player',
        Items = {
            {
                Id = 'playerinfo',
                Name = 'Player Info',
                Event = 'butter_admin:server:playerInfo',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'noclip',
                Name = 'Noclip',
                Event = 'butter_admin:client:toggleNoclip',
                EventType = 'Client',
                Collapse = false,
                DevKey = 'N',
            },
            {
                Id = 'revive',
                Name = 'Revive',
                Event = 'butter_admin:server:revivePlayer',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'selfrevive',
                Name = 'Self Revive',
                Event = 'butter_admin:server:selfRevive',
                EventType = 'Server',
                Collapse = false,
                DevKey = 'F9',
            },
            {
                Id = 'invisible',
                Name = 'Invisible',
                Event = 'butter_admin:server:toggleInvisible',
                EventType = 'Server',
                Collapse = false,
                DevKey = 'F7',
            },
            {
                Id = 'reviveAll',
                Name = 'Revive All',
                Event = 'butter_admin:server:reviveAll',
                EventType = 'Server',
                Collapse = false,
            },
            {
                Id = 'resetskin',
                Name = 'Reset Model',
                Event = 'butter_admin:server:resetSkin',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'openclothing',
                Name = 'Clothing',
                Event = 'butter_admin:server:openClothing',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'givearmor',
                Name = 'Armor',
                Event = 'butter_admin:server:setArmor',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'selfarmour',
                Name = 'Self Armour',
                Event = 'butter_admin:server:selfArmor',
                EventType = 'Server',
                Collapse = false,
            },
            {
                Id = 'food-drink',
                Name = 'Food & Drink',
                Event = 'butter_admin:server:restoreNeeds',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'openinventory',
                Name = 'Open Inventory',
                Event = 'butter_admin:server:openInventory',
                EventType = 'Server',
                Collapse = true,
                CloseMenu = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'clearinventory',
                Name = 'Clear Inventory',
                Event = 'butter_admin:server:clearInventory',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'kill',
                Name = 'Kill',
                Event = 'butter_admin:server:killPlayer',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'removestress',
                Name = 'Remove Stress',
                Event = 'butter_admin:server:removeStress',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'freezeplayer',
                Name = 'Freeze Player',
                Event = 'butter_admin:server:toggleFreeze',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'godmode',
                Name = 'Godmode',
                Event = 'butter_admin:server:toggleGodmode',
                EventType = 'Server',
                Collapse = false,
                DevKey = 'G',
            },
            {
                Id = 'infammo',
                Name = 'Infinite Ammo',
                Event = 'butter_admin:server:toggleInfiniteAmmo',
                EventType = 'Server',
                Collapse = false,
            },
            {
                Id = 'infstamina',
                Name = 'Infinite Stamina',
                Event = 'butter_admin:server:toggleInfiniteStamina',
                EventType = 'Server',
                Collapse = false,
            },
            {
                Id = 'changeped',
                Name = 'Change Ped',
                Event = 'butter_admin:server:setModel',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'model', Name = 'Model', Type = 'input-choice', Choices = 'pedModels' },
                },
            },
            {
                Id = 'reviveradius',
                Name = 'Revive in Radius',
                Event = 'butter_admin:server:reviveInRadius',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'radius', Name = 'Radius', Type = 'input', InputType = 'number' },
                },
            },
            {
                Id = 'setWeather',
                Name = 'Set Weather',
                Event = 'butter_admin:server:setWeather',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'weather', Name = 'Weather Type', Type = 'input-choice', Choices = 'weatherTypes' },
                },
            },
            {
                Id = 'setTime',
                Name = 'Set Time',
                Event = 'butter_admin:server:setTime',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'hour', Name = 'Hour', Type = 'input', InputType = 'number' },
                    { Id = 'minute', Name = 'Minutes', Type = 'input', InputType = 'number' },
                },
            },
        },
    },
    {
        Id = 'utility',
        Name = 'Utility',
        Items = {
            {
                Id = 'toggleblips',
                Name = 'Toggle Blips',
                Event = 'butter_admin:client:toggleBlips',
                EventType = 'Client',
                Collapse = false,
                DevKey = 'B',
            },
            {
                Id = 'togglenames',
                Name = 'Toggle Names',
                Event = 'butter_admin:client:togglePlayerNames',
                EventType = 'Client',
                Collapse = false,
                DevKey = 'J',
            },
            {
                Id = 'openstash',
                Name = 'Open Stash',
                Event = 'butter_admin:server:openStash',
                EventType = 'Server',
                Collapse = true,
                CloseMenu = true,
                Options = {
                    { Id = 'stashid', Name = 'Select Stash', Type = 'input-choice', Choices = 'stashes' },
                },
            },
            {
                Id = 'opentrunk',
                Name = 'Open Trunk',
                Event = 'butter_admin:client:openTrunk',
                EventType = 'Client',
                Collapse = true,
                CloseMenu = true,
                Options = {
                    { Id = 'plate', Name = 'Select Vehicle', Type = 'input-choice', Choices = 'ownedVehicles' },
                },
            },
            {
                Id = 'openglovebox',
                Name = 'Open Glovebox',
                Event = 'butter_admin:client:openGlovebox',
                EventType = 'Client',
                Collapse = true,
                CloseMenu = true,
                Options = {
                    { Id = 'plate', Name = 'Select Vehicle', Type = 'input-choice', Choices = 'ownedVehicles' },
                },
            },
            {
                Id = 'deleteVehicle',
                Name = 'Delete Vehicle',
                Event = 'butter_admin:client:deleteVehicle',
                EventType = 'Client',
                Collapse = false,
            },
            {
                Id = 'fixVehicle',
                Name = 'Fix Vehicle',
                Event = 'butter_admin:client:fixVehicle',
                EventType = 'Client',
                Collapse = false,
            },
            {
                Id = 'maxVehiclePerf',
                Name = 'Max Performance Mods',
                Event = 'butter_admin:client:upgradeVehicle',
                EventType = 'Client',
                Collapse = false,
                StaticResult = { maxmods = true },
            },
            {
                Id = 'randomizeCustomization',
                Name = 'Randomize Customization',
                Event = 'butter_admin:client:upgradeVehicle',
                EventType = 'Client',
                Collapse = false,
                StaticResult = { randomcustom = true },
            },
            {
                Id = 'givekeys',
                Name = 'Give Keys',
                Event = 'butter_admin:client:giveKeys',
                EventType = 'Client',
                Collapse = false,
            },
            {
                Id = 'refuel',
                Name = 'ReFuel',
                Event = 'butter_admin:server:refuelVehicle',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'selffuel',
                Name = 'Self Fuel',
                Event = 'butter_admin:server:refuelVehicle',
                EventType = 'Server',
                Collapse = false,
            },
            {
                Id = 'teleportAll',
                Name = 'Teleport All',
                Event = 'butter_admin:server:teleportAll',
                EventType = 'Server',
                Collapse = false,
            },
            {
                Id = 'teleportToMarker',
                Name = 'Teleport To Marker',
                Event = 'butter_admin:client:teleportToMarker',
                EventType = 'Client',
                Collapse = false,
            },
            {
                Id = 'showCoords',
                Name = 'Show Coords',
                Event = 'butter_admin:client:toggleCoords',
                EventType = 'Client',
                Collapse = false,
            },
            {
                Id = 'resetWorldArea',
                Name = 'Reset World Area',
                Event = 'butter_admin:server:deleteArea',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'type', Name = 'Type', Type = 'input-choice', Choices = 'deletionTypes' },
                    { Id = 'radius', Name = 'Radius', Type = 'input', InputType = 'number' },
                },
            },
            {
                Id = 'spawnCar',
                Name = 'Spawn Car',
                Event = 'butter_admin:client:spawnVehicle',
                EventType = 'Client',
                Collapse = true,
                Options = {
                    { Id = 'model', Name = 'Model', Type = 'input-choice', Choices = 'vehicleModels' },
                    { Id = 'custom_model', Name = 'Custom Model (Override)', Type = 'input', InputType = 'text' },
                    { Id = 'sit', Name = 'Sit Inside', Type = 'checkbox' },
                    { Id = 'maxmods', Name = 'Max Performance Mods', Type = 'checkbox' },
                    { Id = 'randomcustom', Name = 'Random Customizations', Type = 'checkbox' },
                },
            },
            {
                Id = 'admincar',
                Name = 'Admin Car',
                Event = 'butter_admin:client:registerAdminCar',
                EventType = 'Client',
                Collapse = false,
                DevKey = 'F6',
            },
            {
                Id = 'giveCar',
                Name = 'Give Car',
                Event = 'butter_admin:server:giveCar',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'model', Name = 'Model', Type = 'input-choice', Choices = 'vehicleModels' },
                    { Id = 'custom_model', Name = 'Custom Model (Override)', Type = 'input', InputType = 'text' },
                    { Id = 'garage', Name = 'Garage (optional)', Type = 'input', InputType = 'text' },
                },
            },
            {
                Id = 'teleport',
                Name = 'Teleport',
                Event = 'butter_admin:server:teleportPlayer',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'type', Name = 'Type', Type = 'input-choice', Choices = { { Text = 'Goto' }, { Text = 'Bring' } } },
                },
            },
            {
                Id = 'teleportCoords',
                Name = 'Teleport Coords',
                Event = 'butter_admin:client:teleportToCoords',
                EventType = 'Client',
                Collapse = true,
                Options = {
                    { Id = 'x-coord', Name = 'X Coord', Type = 'input', InputType = 'number' },
                    { Id = 'y-coord', Name = 'Y Coord', Type = 'input', InputType = 'number' },
                    { Id = 'z-coord', Name = 'Z Coord', Type = 'input', InputType = 'number' },
                },
            },
            {
                Id = 'announce',
                Name = 'Announce',
                Event = 'butter_admin:server:announce',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'message', Name = 'Message', Type = 'input', InputType = 'text' },
                },
            },
            {
                Id = 'copyCoords',
                Name = 'Copy Coords',
                Event = 'butter_admin:client:copyCoords',
                EventType = 'Client',
                Collapse = true,
                Options = {
                    {
                        Id = 'type',
                        Name = 'Type',
                        Type = 'input-choice',
                        Choices = {
                            { Text = 'vector3(0.0, 0.0, 0.0)' },
                            { Text = 'vector4(0.0, 0.0, 0.0, 0.0)' },
                            { Text = '0.0, 0.0, 0.0' },
                            { Text = '0.0, 0.0, 0.0, 0.0' },
                            { Text = 'X = 0.0, Y = 0.0, Z = 0.0' },
                            { Text = 'x = 0.0, y = 0.0, z = 0.0' },
                            { Text = 'X = 0.0, Y = 0.0, Z = 0.0, H = 0.0' },
                            { Text = 'x = 0.0, y = 0.0, z = 0.0, h = 0.0' },
                            { Text = '["X"] = 0.0, ["Y"] = 0.0, ["Z"] = 0.0' },
                            { Text = '["x"] = 0.0, ["y"] = 0.0, ["z"] = 0.0' },
                            { Text = '["X"] = 0.0, ["Y"] = 0.0, ["Z"] = 0.0, ["H"] = 0.0' },
                            { Text = '["x"] = 0.0, ["y"] = 0.0, ["z"] = 0.0, ["h"] = 0.0' },
                        },
                    },
                },
            },
            {
                Id = 'spawnProp',
                Name = 'Spawn Prop',
                Event = 'butter_admin:client:spawnProp',
                EventType = 'Client',
                Collapse = true,
                Options = {
                    { Id = 'model', Name = 'Prop Model', Type = 'input-choice', Choices = 'propModels' },
                    { Id = 'custom_model', Name = 'Custom Model', Type = 'input', InputType = 'text' },
                    { Id = 'permanent', Name = 'Save Permanent', Type = 'checkbox' },
                    { Id = 'freeze', Name = 'Freeze Prop', Type = 'checkbox' },
                },
            },
            {
                Id = 'manageProp',
                Name = 'Manage Spawned Prop',
                Event = 'butter_admin:client:manageProp',
                EventType = 'Client',
                Collapse = true,
                Options = {
                    { Id = 'object_id', Name = 'Select Prop', Type = 'input-choice', Choices = 'spawnedProps' },
                    { Id = 'action', Name = 'Action', Type = 'input-choice', Choices = { { Text = 'Teleport' }, { Text = 'Delete' } } },
                },
            },
        },
    },
    {
        Id = 'user',
        Name = 'User',
        Items = {
            {
                Id = 'setgang',
                Name = 'Set Gang',
                Event = 'butter_admin:server:setGang',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'gang', Name = 'Gang', Type = 'input-choice', Choices = 'gangs' },
                    { Id = 'rank', Name = 'Rank', Type = 'input-choice', Choices = 'gangGrades' },
                },
            },
            {
                Id = 'giveJob',
                Name = 'Give Job',
                Event = 'butter_admin:server:setJob',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'job', Name = 'Job', Type = 'input-choice', Choices = 'jobs' },
                    { Id = 'rank', Name = 'Rank', Type = 'input-choice', Choices = 'jobGrades' },
                },
            },
            {
                Id = 'togglejobduty',
                Name = 'Toggle Job Duty',
                Event = 'butter_admin:server:toggleJobDuty',
                EventType = 'Server',
                Collapse = false,
            },
            {
                Id = 'giveitem',
                Name = 'Give Item',
                Event = 'butter_admin:server:giveItem',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'item', Name = 'Item', Type = 'input-choice', Choices = 'items' },
                    { Id = 'amount', Name = 'Amount', Type = 'input', InputType = 'number' },
                },
            },
            {
                Id = 'setmoney',
                Name = 'Set Money',
                Event = 'butter_admin:server:setMoney',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'moneytype', Name = 'Money Type', Type = 'input-choice', Choices = 'moneyTypes' },
                    { Id = 'amount', Name = 'Amount', Type = 'input', InputType = 'number' },
                },
            },
            {
                Id = 'givemoney',
                Name = 'Give Money',
                Event = 'butter_admin:server:giveMoney',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'moneytype', Name = 'Money Type', Type = 'input-choice', Choices = 'moneyTypes' },
                    { Id = 'amount', Name = 'Amount', Type = 'input', InputType = 'number' },
                },
            },
            {
                Id = 'adminCustoms',
                Name = 'Admin Customs',
                Event = 'butter_admin:server:openBennys',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'banplayer',
                Name = 'Ban Player',
                Event = 'butter_admin:server:banPlayer',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', Choices = 'players' },
                    {
                        Id = 'expire',
                        Name = 'Expire',
                        Type = 'input-choice',
                        Choices = {
                            { Text = '1 Hour' }, { Text = '6 Hours' }, { Text = '12 Hours' },
                            { Text = '1 Day' }, { Text = '3 Days' }, { Text = '1 Week' },
                            { Text = 'Permanent' }, { Text = 'Custom' },
                        },
                    },
                    { Id = 'custom_time', Name = 'Custom Duration (Hours)', Type = 'input', InputType = 'number' },
                    { Id = 'reason', Name = 'Reason', Type = 'input', InputType = 'text' },
                },
            },
            {
                Id = 'unbanplayer',
                Name = 'Unban Player',
                Event = 'butter_admin:server:unbanPlayer',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', Choices = 'bans' },
                },
            },
            {
                Id = 'kickplayer',
                Name = 'Kick Player',
                Event = 'butter_admin:server:kickPlayer',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'reason', Name = 'Reason', Type = 'input', InputType = 'text' },
                },
            },
            {
                Id = 'kickall',
                Name = 'Kick All Players',
                Event = 'butter_admin:server:kickAllPlayers',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'reason', Name = 'Reason', Type = 'input', InputType = 'text' },
                },
            },
            {
                Id = 'spectate',
                Name = 'Spectate Player',
                Event = 'butter_admin:server:startSpectate',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
        },
    },
    {
        Id = 'fun',
        Name = 'Fun',
        Items = {
            {
                Id = 'throwplayer',
                Name = 'Throw Player In Sky',
                Event = 'butter_admin:server:flingPlayer',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'drunkplayer',
                Name = 'Make Player Drunk',
                Event = 'butter_admin:server:makeDrunk',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'animalattack',
                Name = 'Animal Attack',
                Event = 'butter_admin:server:animalAttack',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'setonfire',
                Name = 'Set On Fire',
                Event = 'butter_admin:server:setOnFire',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'playsound',
                Name = 'Play Sound',
                Event = 'butter_admin:server:playSound',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'sound', Name = 'Sound', Type = 'input-choice', Choices = 'sounds' },
                },
            },
            {
                Id = 'forceanim',
                Name = 'Force Animation',
                Event = 'butter_admin:server:forceAnimation',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'anim', Name = 'Animation', Type = 'input-choice', Choices = 'animations' },
                    { Id = 'anim_command', Name = 'Custom Command (e.g. e drink, overrides above)', Type = 'input', InputType = 'text' },
                },
            },
            {
                Id = 'jailbox',
                Name = 'Send to Jailbox',
                Event = 'butter_admin:server:sendToJailbox',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'damagevehicle',
                Name = 'Damage Vehicle',
                Event = 'butter_admin:server:damageVehicle',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'kidnapvan',
                Name = 'Kidnap Van',
                Event = 'butter_admin:server:kidnapVan',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'ufo',
                Name = 'UFO Kidnap',
                Event = 'butter_admin:server:ufoKidnap',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                },
            },
            {
                Id = 'ghost',
                Name = 'Ghost Troll',
                Event = 'butter_admin:server:ghostTroll',
                EventType = 'Server',
                Collapse = true,
                Options = {
                    { Id = 'player', Name = 'Player', Type = 'input-choice', PlayerList = true },
                    { Id = 'duration', Name = 'Duration (Seconds)', Type = 'input', InputType = 'number' },
                },
            },
        },
    },
}
