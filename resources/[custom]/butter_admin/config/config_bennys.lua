Config = Config or {}

-- Admin Customs (Bennys) menu. Prices are only shown as descriptions.
-- Tables keyed by number use the game's own index for that slot, paint or type.
Config.Bennys = {
    Currency = '$',
    CosmeticPrice = 500,
    TurboPrice = 10000,

    -- Mod slots without any options on a vehicle are hidden automatically.
    ModSlots = {
        performance = {
            [11] = 'Engine',
            [12] = 'Brakes',
            [13] = 'Transmission',
            [15] = 'Suspension',
            [16] = 'Armor',
        },
        parts = {
            [0] = 'Spoiler',
            [1] = 'Front Bumper',
            [2] = 'Rear Bumper',
            [3] = 'Side Skirts',
            [4] = 'Exhaust',
            [5] = 'Roll Cage',
            [6] = 'Grille',
            [7] = 'Hood',
            [8] = 'Left Fender',
            [9] = 'Right Fender',
            [10] = 'Roof',
            [14] = 'Horn',
            [19] = 'Subwoofer',
            [21] = 'Hydraulics',
            [25] = 'Plate Holder',
            [26] = 'Vanity Plate',
            [27] = 'Interior Trim',
            [28] = 'Ornaments',
            [29] = 'Dashboard',
            [30] = 'Dials',
            [31] = 'Door Speakers',
            [32] = 'Seats',
            [33] = 'Steering Wheel',
            [34] = 'Shift Knob',
            [35] = 'Plaques',
            [36] = 'Audio Install',
            [37] = 'Trunk',
            [38] = 'Hydraulic Pumps',
            [39] = 'Engine Block',
            [40] = 'Air Intake',
            [41] = 'Strut Brace',
            [42] = 'Arch Covers',
            [43] = 'Antennas',
            [44] = 'Exterior Trim',
            [45] = 'Fuel Tank',
            [46] = 'Left Door',
            [47] = 'Right Door',
            [49] = 'Light Bar',
        },
    },

    -- Order of the finish rows in the primary and secondary paint menus.
    PaintCategories = { 'Metallic', 'Solid', 'Matte', 'Utility', 'Worn', 'Metals', 'Chameleon' },

    Paints = {
        Metallic = {
            [0] = 'Black', [1] = 'Graphite', [2] = 'Black Steel', [3] = 'Dark Silver', [4] = 'Silver', [5] = 'Blue Silver',
            [6] = 'Steel Grey', [7] = 'Shadow Silver', [8] = 'Stone Silver', [9] = 'Midnight Silver', [10] = 'Gunmetal', [11] = 'Anthracite',
            [27] = 'Red', [28] = 'Torino Red', [29] = 'Formula Red', [30] = 'Blaze Red', [31] = 'Graceful Red', [32] = 'Garnet',
            [33] = 'Desert Red', [34] = 'Cabernet', [35] = 'Candy Red', [36] = 'Sunrise Orange', [37] = 'Classic Gold', [38] = 'Orange',
            [49] = 'Dark Green', [50] = 'Racing Green', [51] = 'Sea Green', [52] = 'Olive', [53] = 'Green', [54] = 'Gasoline Teal',
            [61] = 'Midnight Blue', [62] = 'Dark Blue', [63] = 'Saxony Blue', [64] = 'Blue', [65] = 'Mariner Blue', [66] = 'Harbor Blue',
            [67] = 'Diamond Blue', [68] = 'Surf Blue', [69] = 'Nautical Blue', [70] = 'Bright Blue', [71] = 'Purple Blue', [72] = 'Spinnaker Blue',
            [73] = 'Ultra Blue', [74] = 'Sky Blue',
            [88] = 'Taxi Yellow', [89] = 'Race Yellow', [90] = 'Bronze', [91] = 'Canary Yellow', [92] = 'Lime', [93] = 'Champagne',
            [94] = 'Pueblo Beige', [95] = 'Dark Ivory', [96] = 'Chocolate', [97] = 'Golden Brown', [98] = 'Light Brown', [99] = 'Straw',
            [100] = 'Moss Brown', [101] = 'Bistre Brown', [102] = 'Beechwood', [103] = 'Dark Beechwood', [104] = 'Burnt Orange',
            [105] = 'Beach Sand', [106] = 'Bleached Sand', [107] = 'Cream',
            [111] = 'White', [112] = 'Frost White', [125] = 'Security Green', [127] = 'Police Blue', [137] = 'Vermillion Pink',
            [141] = 'Blue Black', [142] = 'Purple Black', [143] = 'Red Black', [145] = 'Purple', [146] = 'Deep Navy',
            [150] = 'Lava Red', [157] = 'Epsilon Blue',
        },
        Solid = {
            [134] = 'Pure White', [135] = 'Hot Pink', [136] = 'Salmon', [138] = 'Bright Orange', [139] = 'Bright Green',
            [140] = 'Bright Blue', [144] = 'Hunter Green', [147] = 'Carbon Black',
        },
        Matte = {
            [12] = 'Black', [13] = 'Grey', [14] = 'Light Grey', [39] = 'Red', [40] = 'Dark Red', [41] = 'Orange', [42] = 'Yellow',
            [55] = 'Lime', [82] = 'Dark Blue', [83] = 'Blue', [84] = 'Midnight Blue', [128] = 'Green', [129] = 'Brown', [131] = 'White',
            [148] = 'Purple', [149] = 'Dark Purple', [151] = 'Forest Green', [152] = 'Olive Drab', [153] = 'Desert Brown',
            [154] = 'Desert Tan', [155] = 'Foliage Green',
        },
        Utility = {
            [15] = 'Black', [16] = 'Black Poly', [17] = 'Dark Silver', [18] = 'Silver', [19] = 'Gunmetal', [20] = 'Shadow Silver',
            [43] = 'Red', [44] = 'Bright Red', [45] = 'Garnet', [56] = 'Dark Green', [57] = 'Green',
            [75] = 'Dark Blue', [76] = 'Midnight Blue', [77] = 'Blue', [78] = 'Sea Foam', [79] = 'Lightning Blue', [80] = 'Maui Blue',
            [81] = 'Bright Blue', [108] = 'Brown', [109] = 'Medium Brown', [110] = 'Light Brown', [122] = 'Off White',
        },
        Worn = {
            [21] = 'Black', [22] = 'Graphite', [23] = 'Silver Grey', [24] = 'Silver', [25] = 'Blue Silver', [26] = 'Shadow Silver',
            [46] = 'Red', [47] = 'Golden Red', [48] = 'Dark Red', [58] = 'Dark Green', [59] = 'Green', [60] = 'Sea Wash',
            [85] = 'Dark Blue', [86] = 'Blue', [87] = 'Light Blue', [113] = 'Honey Beige', [114] = 'Brown', [115] = 'Dark Brown',
            [116] = 'Straw Beige', [121] = 'Off White', [123] = 'Orange', [124] = 'Light Orange', [126] = 'Taxi Yellow',
            [130] = 'Rust Orange', [132] = 'White', [133] = 'Army Green',
        },
        Metals = {
            [117] = 'Brushed Steel', [118] = 'Brushed Black Steel', [119] = 'Brushed Aluminium', [120] = 'Chrome',
            [158] = 'Pure Gold', [159] = 'Brushed Gold', [160] = 'Secret Gold',
        },
        -- Requires a server running game build 3095 or newer.
        Chameleon = {
            [161] = 'Anodized Red', [162] = 'Anodized Wine', [163] = 'Anodized Purple', [164] = 'Anodized Blue', [165] = 'Anodized Green',
            [166] = 'Anodized Lime', [167] = 'Anodized Copper', [168] = 'Anodized Bronze', [169] = 'Anodized Champagne', [170] = 'Anodized Gold',
            [171] = 'Flip Green-Blue', [172] = 'Flip Green-Red', [173] = 'Flip Green-Brown', [174] = 'Flip Green-Turquoise',
            [175] = 'Flip Green-Purple', [176] = 'Flip Teal-Purple', [177] = 'Flip Turquoise-Red', [178] = 'Flip Turquoise-Purple',
            [179] = 'Flip Cyan-Purple', [180] = 'Flip Blue-Pink', [181] = 'Flip Blue-Green', [182] = 'Flip Purple-Red',
            [183] = 'Flip Purple-Green', [184] = 'Flip Magenta-Green', [185] = 'Flip Magenta-Yellow', [186] = 'Flip Burgundy-Green',
            [187] = 'Flip Magenta-Cyan', [188] = 'Flip Copper-Purple', [189] = 'Flip Magenta-Orange', [190] = 'Flip Red-Orange',
            [191] = 'Flip Orange-Purple', [192] = 'Flip Orange-Blue', [193] = 'Flip White-Purple',
            [194] = 'Rainbow Red', [195] = 'Rainbow Blue',
            [196] = 'Pearl Dark Green', [197] = 'Pearl Dark Teal', [198] = 'Pearl Dark Blue', [199] = 'Pearl Dark Purple',
            [200] = 'Pearl Oil Slick', [201] = 'Pearl Light Green', [202] = 'Pearl Light Blue', [203] = 'Pearl Light Purple',
            [204] = 'Pearl Light Pink', [205] = 'Pearl Off White', [206] = 'Pearl Pink', [207] = 'Pearl Baby Yellow',
            [208] = 'Pearl Baby Green', [209] = 'Pearl Baby Blue', [210] = 'Pearl Cream',
            [211] = 'Prismatic White', [212] = 'Prismatic Graphite', [213] = 'Prismatic Blue', [214] = 'Prismatic Purple',
            [215] = 'Prismatic Hot Pink', [216] = 'Prismatic Red', [217] = 'Prismatic Green', [218] = 'Prismatic Black',
            [219] = 'Prismatic Oil Spill', [220] = 'Prismatic Rainbow',
            [221] = 'Holographic Black', [222] = 'Holographic White',
        },
    },

    -- { label, red, green, blue }
    NeonColors = {
        { 'Cool White', 222, 222, 255 },
        { 'Warm White', 255, 214, 170 },
        { 'Royal Blue', 2, 21, 255 },
        { 'Electric Blue', 3, 83, 255 },
        { 'Cyan', 0, 255, 255 },
        { 'Mint', 0, 255, 140 },
        { 'Lime', 94, 255, 1 },
        { 'Yellow', 255, 255, 0 },
        { 'Amber', 255, 150, 0 },
        { 'Orange', 255, 62, 0 },
        { 'Red', 255, 1, 1 },
        { 'Rose', 255, 50, 100 },
        { 'Hot Pink', 255, 5, 190 },
        { 'Violet', 35, 1, 255 },
        { 'Blacklight', 15, 3, 255 },
    },

    -- Starts at game index -1 (factory headlights) and counts up from there.
    XenonColors = {
        'Factory', 'Cool White', 'Royal Blue', 'Electric Blue', 'Mint', 'Lime', 'Yellow',
        'Amber', 'Orange', 'Red', 'Rose', 'Hot Pink', 'Violet', 'Blacklight',
    },

    -- Starts at game index 0.
    WindowTints = { 'Clear', 'Limo Black', 'Dark Tint', 'Light Tint', 'Factory', 'Limo', 'Green' },

    -- Starts at game index 0.
    PlateStyles = { 'San Andreas', 'Yellow on Black', 'Yellow on Blue', 'San Andreas Alt', 'Exempt', 'North Yankton' },

    WheelTypes = {
        [0] = 'Sport',
        [1] = 'Muscle',
        [2] = 'Lowrider',
        [3] = 'SUV',
        [4] = 'Off-Road',
        [5] = 'Tuner',
        [6] = 'Motorcycle',
        [7] = 'High End',
        [8] = "Benny's Originals",
        [9] = "Benny's Bespoke",
        [10] = 'Open Wheel',
        [11] = 'Street',
        [12] = 'Track',
    },
}
