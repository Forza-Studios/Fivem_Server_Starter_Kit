Config = {}

-- ═══════════════════════════════════════════════════════════════
-- 框架 & 系统设置
-- ═══════════════════════════════════════════════════════════════

-- 使用哪个框架？
-- 可选: 'qb', 'esx', 'qbox', 'vrp'
Config.Framework = 'qbox'

-- 使用哪个 inventory 背包系统？
-- 可选: 'ox', 'qb', 'esx', 'qs', 'codem', 'tgiann', 'none'
Config.Inventory = 'ox'

-- 使用哪个语音系统？
-- 可选: 'pma-voice', 'saltychat', 'mumble-voip', 'toko-voip'
-- 设置为 false 关闭语音集成
Config.VoiceSystem = 'pma-voice'

-- 使用哪种通知系统？
-- 可选: 'framework' (使用框架自带通知), 'ox', 'custom'
-- 'framework' = QBCore.Functions.Notify / ESX.ShowNotification / QBX Notify / vRP 聊天消息
-- 'ox' = ox_lib 通知 (必须安装 ox_lib)
-- 'custom' = 在下方自定义通知函数
Config.Notification = {
    System = 'ox',

    -- 自定义通知函数 (仅 System = 'custom' 时生效)
    -- @param message string - 通知文本
    -- @param type string - 'success', 'error', 'primary', 'warning'
    Custom = function(message, type)
        -- 示例: exports['mythic_notify']:DoHudText(type, message)
    end,
}

-- vRP 生存系统 (饥饿 & 口渴) - 仅 Config.Framework = 'vrp' 时使用
-- 如果 vRP 已有生存模块, HUD 将自动使用它
-- 如果没有, HUD 会使用内置的生存系统
Config.VRPSurvival = {
    Enabled = true,             -- 启用 vRP 内置饥饿/口渴 (如果 vRP 没有生存模块)
    FoodPerMinute = 1,          -- 每分钟饥饿减少值 (0-100)
    WaterPerMinute = 2,         -- 每分钟口渴减少值 (0-100)
    OverflowDamage = 5,         -- 饥饿/口渴为 0 时每跳造成的伤害
    DefaultFood = 75,           -- 初始饥饿值 (0-100)
    DefaultWater = 100,         -- 初始口渴值 (0-100)
}

-- 自动 HUD 安装: 新玩家加入时自动弹出 HUD 风格选择界面
-- 设置为 false 可手动触发: TriggerClientEvent('codem-hud:client:TriggerSetup', source)
-- 如果你的角色创建界面与自动设置冲突, 建议关闭
Config.AutoHudSetup = true

-- ═══════════════════════════════════════════════════════════════
-- 语言设置 (本地化)
-- ═══════════════════════════════════════════════════════════════
-- 语言文件位于 shared/locales/
-- 可选: 'en' (英语), 'tr' (土耳其语), 'es' (西班牙语), 'fr' (法语)
Config.Locale = {
    -- 使用的语言
    Language = 'en',
}

-- ═══════════════════════════════════════════════════════════════
-- 自定义玩家 ID 函数
-- ═══════════════════════════════════════════════════════════════
-- 重写此函数使用自定义玩家 ID 系统
-- 该 ID 显示在 HUD 设置面板和玩家信息中
-- 返回: string 或 number (自定义玩家 ID)
-- 默认: 使用服务器 ID (GetPlayerServerId)
---@param serverId number 玩家服务器 ID
---@return string|number 要显示的自定义玩家 ID
Config.GetCustomPlayerId = nil

-- 示例
--Config.GetCustomPlayerId = function(serverId)
--    local playerData = GetPlayerData()
--    local citizenid = playerData and playerData.citizenid
--    return citizenid or serverId
--end

-- ═══════════════════════════════════════════════════════════════
-- 载具模型分类
-- ═══════════════════════════════════════════════════════════════
-- 定义哪些载具模型属于特殊类别

Config.VehicleModels = {
    -- 警车 (用于警笛检测)
    Police = {
        'police', 'police2', 'police3', 'police4', 'policeb',
        'sheriff', 'sheriff2', 'pranger', 'fbi', 'fbi2',
    },

    -- 医疗/急救载具 (用于警笛检测)
    EMS = {
        'ambulance', 'firetruk', 'lguard',
    },

    -- 电动车 (氮气无排气火焰)
    Electric = {
        'tezeract', 'cyclone', 'neon', 'raiden', 'voltic', 'voltic2',
        'imorgon', 'iwagen', 'virtue', 'omnisegt',
    },
}

-- ═══════════════════════════════════════════════════════════════
-- 时间间隔 (高级设置 - 懂再改)
-- ═══════════════════════════════════════════════════════════════
-- 所有时间值均为毫秒, 除非另有说明

Config.Timings = {
    -- 压力系统冷却时间 (毫秒)
    Stress = {
        ShootCooldown = 800,      -- 射击压力事件间隔
        DamageCooldown = 2500,    -- 受伤压力事件间隔
        CrashCooldown = 6000,     -- 车祸压力事件间隔
        SpeedCooldown = 5000,     -- 超速压力事件间隔
        NotifyCooldown = 3000,    -- 压力通知间隔
    },

    -- 自适应间隔配置 (性能优化)
    -- 格式: { 最小, 最大, 步长, 阈值 }
    -- min = 最快更新速度, max = 最慢更新速度, step = 增量, threshold = 自适应前的变化次数
    Intervals = {
        Weapon = { min = 200, max = 800, step = 100, threshold = 5 },
        Damage = { min = 300, max = 1500, step = 200, threshold = 3 },
        Vehicle = { min = 500, max = 2000, step = 200, threshold = 3 },
        Main = { min = 2000, max = 6000, step = 400, threshold = 3 },
        Hud = { min = 500, max = 2000, step = 200, threshold = 3 },
        Sync = { min = 30000, max = 120000, step = 15000, threshold = 2 },
        Location = { min = 3000, max = 15000, step = 2000, threshold = 2 },
        Heading = { min = 60, max = 200, step = 20, threshold = 8 },
        Waypoint = { min = 150, max = 500, step = 50, threshold = 5 },
    },

    -- 服务端时间设置
    Server = {
        SocietyCacheTime = 10000,  -- 公会资金缓存时间 (毫秒)
        InitWaitTime = 2000,       -- 初始化等待时间
    },
}

-- ═══════════════════════════════════════════════════════════════
-- UI 效果
-- ═══════════════════════════════════════════════════════════════

Config.UI = {
    -- 启用 HUD 模糊效果 (玻璃态)
    -- 设置为 false 完全关闭模糊以提升性能
    -- 关闭后, 模糊设置不会出现在设置菜单
    BlurEnabled = true,
}

-- ═══════════════════════════════════════════════════════════════
-- 设置菜单
-- ═══════════════════════════════════════════════════════════════

Config.Settings = {
    -- 服务器名称 (显示在设置菜单)
    ServerName = 'GlenDale RP',

    -- 服务器 Discord (显示在玩家信息面板)
    ServerDiscord = 'KOOK',

    -- 服务器 Logo 地址 (显示在玩家信息面板)
    -- 设置为 nil 使用默认占位图
    ServerLogo = 'https://img1.guipin.com/image/upload/8242920/59911aa9c2360.jpeg',

    -- 金钱格式: 千位分隔符
    -- '.'  = 点号        (12.500)
    -- ','  = 逗号      (12,500)
    -- ' '  = 空格      (12 500)
    -- '\'' = 撇号 (12'500)
    -- '_'  = 下划线 (12_500)
    -- ''   = 无       (12500)
    MoneySeparator = '.',

    -- 金钱符号
    -- '$' = 美元, '€' = 欧元, '£' = 英镑, 'R$' = 雷亚尔, '₺' = 里拉
    MoneyPrefix = '$',

    -- 货币符号位置
    -- 'before' = $12.500 (前缀)
    -- 'after'  = 12.500$ (后缀)
    MoneyPosition = 'after',

    -- 金钱行文字颜色 (十六进制颜色)
    MoneyColors = {
        cash    = '#5ecb6e',
        bank    = '#74b1e0',
        marked  = '#cb5e5e',
        society = '#e074db',
        coin    = '#e0ce74',
    },

    -- 打开设置的指令 (false 关闭)
    Command = 'hudsettings',
    -- 打开设置的按键 (false 关闭)
    -- 参考: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/
    Keybind = 'F7',
    KeybindDescription = '打开 HUD 设置',
    -- 打开设置的事件
    -- 用法: TriggerEvent('codem-hud:client:OpenSettings')
    Event = 'codem-hud:client:OpenSettings',

}

-- ═══════════════════════════════════════════════════════════════

Config.ToggleHud = {
    -- 切换 HUD 显示的指令 (false 关闭)
    Command = 'togglehud',

    -- 切换 HUD 显示的按键 (false 关闭)
    -- 参考: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/
    Keybind = false,
    KeybindDescription = '切换 HUD 显示',

    -- 切换 HUD 显示的事件
    -- 用法: TriggerEvent('codem-hud:client:ToggleHud')
    -- 用法: TriggerEvent('codem-hud:client:ShowHud')
    -- 用法: TriggerEvent('codem-hud:client:HideHud')
    --
    -- 导出函数:
    -- exports['codem-supreme-hud']:ToggleHud()
    -- exports['codem-supreme-hud']:ShowHud()
    -- exports['codem-supreme-hud']:HideHud()
    -- exports['codem-supreme-hud']:IsHudHidden()
}

-- ═══════════════════════════════════════════════════════════════
-- 小地图
-- ═══════════════════════════════════════════════════════════════

Config.Minimap = {
    -- 玩家步行时显示小地图?
    -- true  = 步行始终显示
    -- false = 步行隐藏 (或需要下方物品)
    ShowOnFoot = true,

    -- 步行时需要物品才能显示小地图?
    -- 仅 ShowOnFoot = false 时生效
    -- true  = 玩家拥有下方任一物品时显示小地图
    -- false = 步行永不显示小地图
    RequireItem = true,

    -- 启用小地图所需物品
    -- 玩家至少需要其中一个
    RequiredItems = { 'phone' },

    -- ─────────────────────────────────────────────────────────────
    -- 大地图切换
    -- ─────────────────────────────────────────────────────────────
    -- 按键展开小地图并隐藏 HUD 元素
    BigMap = {
        -- 启用大地图切换功能
        Enabled = true,

        -- 切换大地图的按键
        -- 参考: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/
        Key = 'Z',
        KeyDescription = '切换大地图',
    },
}

-- ═══════════════════════════════════════════════════════════════
-- 压力系统
-- ═══════════════════════════════════════════════════════════════
-- 真实压力机制, 影响玩家状态
-- 支持 QBCore, QBox, ESX (需 metadata.stress)

Config.Stress = {
    -- 启用压力系统
    Enabled = false,

    -- 压力变化时显示通知
    Notifications = false,

    -- 最大压力值 (0-100)
    MaxStress = 100,

    -- 白名单职业 (这些职业射击不会增加压力)
    -- 适合警察、军人、保安等经常使用武器的职业
    WhitelistedJobs = {
        'police',
        'sheriff',
        'bcso',
        'sasp',
        'fib',
        'doj',
        'military',
        'security',
        'ambulance',    -- 医护人员可能需要自卫
        'hunter',       -- 猎人职业
        -- 在这里添加自定义职业
    },

    -- 压力增加量 (false 关闭该功能)
    Increase = {
        -- 战斗
        Shooting = 1.5,           -- 每开一枪 | false 关闭
        GettingShot = 5,          -- 被子弹击中 | false 关闭
        Melee = 1,                -- 每次近战攻击 | false 关闭
        GettingHit = 3,           -- 被近战击中 | false 关闭

        -- 驾驶
        Speeding = 0.1,           -- 超过速度阈值 | false 关闭
        SpeedThreshold = 120,     -- 超速阈值 (km/h) - 仅 Speeding 开启时使用
        VehicleCrash = 8,         -- 载具碰撞 | false 关闭

        -- 其他
        Falling = 5,              -- 从高处坠落 | false 关闭
        Ragdoll = 2,              -- 布娃娃状态 | false 关闭
        LowHealth = 0.2,          -- 生命值 < 25% | false 关闭
        Drowning = 1,             -- 水下缺氧 | false 关闭
    },

    -- 压力减少量 (false 关闭该功能)
    Decrease = {
        -- 被动恢复 (多种放松方式)
        Sitting = 2,           -- 平稳驾驶 (20-100 km/h) | false 关闭
        Swimming = 2,           -- 游泳 (运动) | false 关闭
        Walking = 1,           -- 行走 | false 关闭
        Running = 2,           -- 慢跑/跑步 (有氧运动) | false 关闭
        Passenger = 2,         -- 载具乘客 | false 关闭

        -- 物品 (设置物品名, false 关闭)
        -- 数值 = 使用物品后减少的压力值
        Items = {
            -- 吸烟/电子烟
            ['joint'] = 20,        -- 烟 (强效)
            ['weed_joint'] = 20,   -- 大麻烟
            ['cigarette'] = 10,    -- 香烟
            ['cigar'] = 12,        -- 雪茄
            ['vape'] = 8,          -- 电子烟
            ['phone'] = 100,          -- 使用手机
            ['WEAPON_PISTOL'] = 100,         -- 啤酒

            -- 酒精
            ['beer'] = 12,         -- 啤酒
            ['whiskey'] = 15,      -- 威士忌
            ['vodka'] = 15,        -- 伏特加
            ['wine'] = 10,         -- 红酒
            ['champagne'] = 12,    -- 香槟
            ['tequila'] = 15,      -- 龙舌兰

            -- 饮料
            ['coffee'] = 8,        -- 咖啡
            ['tea'] = 10,          -- 茶 (镇静)
            ['water'] = 5,         -- 水
            ['cola'] = 5,          -- 可乐/汽水
            ['energydrink'] = 6,   -- 功能饮料

            -- 食物
            ['sandwich'] = 8,      -- 三明治
            ['burger'] = 8,        -- 汉堡
            ['pizza'] = 8,         -- 披萨
            ['donut'] = 6,         -- 甜甜圈
            ['chocolate'] = 10,    -- 巧克力 (情绪提升)
            ['candy'] = 5,         -- 糖果

            -- 医疗
            ['painkiller'] = 15,   -- 止痛药
            ['bandage'] = 5,       -- 绷带 (轻微缓解)
        },
    },

    -- 压力效果 (特定等级触发)
    Effects = {
        -- 高压力时屏幕震动
        ScreenShake = {
            Enabled = true,
            Threshold = 90,        -- 开始震动的压力值
            Intensity = 0.1,       -- 震动强度 (0.0-1.0)
        },
        -- 极高压力时模糊/醉酒效果
        ScreenBlur = {
            Enabled = true,
            Threshold = 95,        -- 开始模糊的压力值
        },
        -- 满压力时随机黑屏
        Blackout = {
            Enabled = false,       -- 默认关闭 (效果较强)
            Threshold = 100,       -- 触发黑屏的压力值
            Duration = 3000,       -- 黑屏持续时间 (毫秒)
        },
    },
}

-- ═══════════════════════════════════════════════════════════════
-- 饥饿音效
-- ═══════════════════════════════════════════════════════════════
-- 饥饿值低时肚子叫音效
-- 附近玩家也能听到

Config.HungerSound = {
    Enabled = true,
    NearbyEnabled = true,      -- true: 附近玩家可听到 | false: 仅自己听到
    Threshold = 25,            -- 开始肚子叫的饥饿值 (0-100)
    Interval = 30000,          -- 叫声间隔 (毫秒) - 默认: 30秒
    NearbyRadius = 10.0,       -- 附近玩家听到的半径 (米)
    SoundFile = 'stomach_growl.mp3', -- 把音效放在 html/sounds/ 并修改名称
}

-- ═══════════════════════════════════════════════════════════════
-- 载具面板
-- ═══════════════════════════════════════════════════════════════

Config.VehiclePanel = {
    -- 使用哪个载具上锁脚本?
    -- 设置为 false 使用默认 GTA 上锁/解锁
    --
    -- 可选:
    --   'qb-vehiclekeys'      - QBCore 默认钥匙
    --   'wasabi_carlock'      - Wasabi Scripts
    --   'Renewed-Vehiclekeys' - Renewed Scripts
    --   'mk_vehiclekeys'      - ManKind Scripts
    --   'vehicles_keys'       - Jaksam Vehicles Keys
    --   'qs-vehiclekeys'      - Quasar Store Vehicle Keys
    --
    -- 或在 shared/bridges.lua 添加自定义
    LockScript = false,

}

-- ═══════════════════════════════════════════════════════════════
-- 手动变速箱
-- ═══════════════════════════════════════════════════════════════
-- 玩家可在 HUD 设置中切换自动/手动变速箱
-- 手动模式下, 玩家通过按键控制换挡

Config.ManualTransmission = {
    -- 启用手动变速箱功能
    Enabled = true,

    -- 升档按键
    -- 参考: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/
    ShiftUpKey = 'E',
    ShiftUpDescription = '升档 (手动变速箱)',

    -- 降档按键
    ShiftDownKey = 'Q',
    ShiftDownDescription = '降档 (手动变速箱)',
}

-- ═══════════════════════════════════════════════════════════════
-- 油量系统
-- ═══════════════════════════════════════════════════════════════

Config.FuelSystem = {
    -- 使用哪个油量脚本?
    --
    -- 可选:
    --   'native'      - 原生 GTA 油量 (GetVehicleFuelLevel)
    --   'LegacyFuel'  - LegacyFuel (使用原生 + decor)
    --   'qb-fuel'     - QBCore 油量
    --   'ps-fuel'     - Project Sloth 油量 (entity state)
    --   'ox_fuel'     - Overextended 油量 (entity state)
    --   'cdn-fuel'    - CDN 油量 (entity state)
    --   'lc_fuel'     - Linden 油量 (entity state)
    --   'okokGasStation' - OKOK 加油站
    --
    -- 设置为 'auto' 自动检测 (推荐)
    Script = 'auto',
}

-- ═══════════════════════════════════════════════════════════════
-- 公会资金 (职业账户)
-- ═══════════════════════════════════════════════════════════════

Config.SocietyMoney = {
    -- 在 HUD 中显示公会资金?
    Enabled = true,

    -- 仅老板可查看公会资金?
    -- true  = 仅老板可见 (默认)
    -- false = 所有员工可见
    BossOnly = true,

    -- 使用哪个公会/职业资金脚本?
    -- 'auto'   = 自动检测 (推荐 - 兼容大多数脚本)
    -- 'custom' = 自定义脚本 (编辑 modules/society/custom.lua)
    --
    -- 自动检测支持:
    --   qb-banking, renewed-banking, g-boss-menu,
    --   esx_society, esx_addonaccount, okokBanking,
    --   codem-bossmenuv2, mBossmenu
    Script = 'auto',
}

-- ═══════════════════════════════════════════════════════════════
-- 职业显示 (玩家信息面板)
-- ═══════════════════════════════════════════════════════════════

Config.JobDisplay = {
    -- 显示缩写如 "LSPD | Officer" 而非完整职业名
    UseAbbreviations = true,

    -- 职业名 → 缩写映射
    Abbreviations = {
        -- 执法部门
        ['police'] = 'LSPD',
        ['lspd'] = 'LSPD',
        ['bcso'] = 'BCSO',
        ['sheriff'] = 'BCSO',
        ['sasp'] = 'SASP',
        ['highway'] = 'SAHP',
        ['fib'] = 'FIB',
        ['doj'] = 'DOJ',

        -- 紧急服务
        ['ambulance'] = 'EMS',
        ['ems'] = 'EMS',
        ['doctor'] = 'EMS',
        ['fire'] = 'LSFD',
        ['firefighter'] = 'LSFD',

        -- 政府 & 服务
        ['mechanic'] = 'LSC',
        ['bennys'] = 'BNY',
        ['bus'] = 'BUS',
        ['trucker'] = 'TRK',
        ['tow'] = 'TOW',
        ['garbage'] = 'SAN',
        ['realestate'] = 'RES',
        ['cardealer'] = 'PDM',

        -- 无业
        ['unemployed'] = 'Citizen',
        ['civilian'] = 'Citizen',
    },

    -- 注意: 不在上表的职业将显示完整名称
    -- (例如: "Real Estate Agent | Senior Agent" 而非缩写)
}

-- ═══════════════════════════════════════════════════════════════
-- 代币系统 (自定义代币/货币)
-- ═══════════════════════════════════════════════════════════════
-- 自定义货币系统, 可通过导出或事件更新
-- 用于显示 VIP 代币、点数、信用等 (仅显示, 不可作为货币使用)
--
-- 使用示例:
--
-- 设置代币值 (无动画):
--   exports['codem-supreme-hud']:SetCoin(100)
--   TriggerEvent('codem-hud:client:SetCoin', 100)
--
-- 增加代币 (带 + 动画):
--   exports['codem-supreme-hud']:AddCoin(50)
--   TriggerEvent('codem-hud:client:AddCoin', 50)
--
-- 减少代币 (带 - 动画):
--   exports['codem-supreme-hud']:RemoveCoin(25)
--   TriggerEvent('codem-hud:client:RemoveCoin', 25)
--
-- 获取当前代币值:
--   local coins = exports['codem-supreme-hudd']:GetCoin()
--
-- 完全控制 (数量, 变化量, 是否减少):
--   exports['codem-supreme-hud']:UpdateCoin(150, 50, false)  -- 设置为 150, 显示 +50
--   TriggerEvent('codem-hud:client:UpdateCoin', 150, 50, false)

Config.Coin = {
    -- 启用代币显示 (仅代币 > 0 时显示)
    Enabled = true,

    -- HUD 显示标签 (默认: "Coin")
    Label = 'Coin',
}

-- ═══════════════════════════════════════════════════════════════
-- 赃款 (黑钱) - (仅 QBCore 或 QBox) (ESX 默认使用账户资金)
-- ═══════════════════════════════════════════════════════════════

Config.MarkedBills = {
    Enabled = false,
    ItemName = 'markedbills',  -- shared/items.lua 中的物品名

    -- 计算总赃款方式:
    -- true  = 累加物品元数据价值 (QB: item.info.worth, ox: item.metadata.worth)
    --         每个 markedbills 物品存储价值在元数据中
    -- false = 使用物品数量 (赃款总数量)
    ItemInfo = true,

    -- 价值存储的元数据键名
    -- QB/QBox: 'worth' (item.info.worth)
    -- ox_inventory: 'worth' (item.metadata.worth)
    MetaKey = 'worth',
}

-- ═══════════════════════════════════════════════════════════════
-- HUD 聚焦键 (载具内鼠标开关)
-- ═══════════════════════════════════════════════════════════════
-- 模式: 'controls' = GTA 控制 ID (DisableControlAction), 'keymapping' = FiveM 注册按键 (可在设置改键)
Config.HudFocusKeyMode = 'keymapping' -- 'controls' 或 'keymapping'

-- 选项 1: 控制模式 - 使用 GTA 控制 ID
-- 19 = Alt, 21 = Shift, 36 = Ctrl, 37 = Tab, 171 = Caps Lock
-- 166 = F5, 167 = F6, 168 = F7, 169 = F8
-- 完整列表: https://docs.fivem.net/docs/game-references/controls/
Config.HudFocusKey = 19

-- 选项 2: 按键映射模式 - 玩家可在 FiveM 设置 > 按键绑定 中改键
-- 使用键盘键名: LMENU (Alt), LSHIFT, LCONTROL, TAB, CAPITAL (Caps Lock), F5-F8
-- 完整列表: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/
Config.HudFocusKeyMap = 'LMENU'
Config.HudFocusKeyMapLabel = 'Alt'

-- ═══════════════════════════════════════════════════════════════
-- 快捷键面板 (快捷操作提示)
-- ═══════════════════════════════════════════════════════════════
-- 在玩家信息面板下方显示快捷键提示
-- 每个快捷键显示图标和按键标签 (如 F1, F2)

Config.Keybinds = {
    -- 启用快捷键面板
    Enabled = false,

    -- 快捷键项目 (顺序决定显示顺序)
    -- id: 唯一标识 (用于显示/隐藏)
    -- key: 图标下方显示的按键
    -- icon: web/src/assets/images/keybinds/ 中的图标文件名
    -- visible: 默认显示状态 (可通过事件/导出修改)
    Items = {
        { id = 'phone', key = 'F1', icon = 'phone.svg', visible = true, order = 1 },
        { id = 'inventory', key = 'F2', icon = 'inventory.svg', visible = true, order = 2 },
        { id = 'radialmenu', key = 'F3', icon = 'radialmenu.svg', visible = true, order = 3 },
        { id = 'settings', key = 'F6', icon = 'settings.svg', visible = true, order = 4 },
    },

}
-- ═══════════════════════════════════════════════════════════════
-- 语音助手
-- ═══════════════════════════════════════════════════════════════
Config.VoiceAssistant = {
    Enabled = true,
    Lang = 'tr', -- 'tr' 或 'en'

    -- 指令格式: { '触发词' 或 {'触发词1','触发词2'}, '提示信息', function() 执行内容 end }
    Commands = {
        en = {
            -- 引擎
            { {'start engine', 'start the engine', 'engine on', 'turn on engine'}, 'Starting engine...', function()
                TriggerEvent('qb-vehiclekeys:client:ToggleEngine')
            end },
            { {'stop engine', 'engine off', 'turn off engine'}, 'Stopping engine...', function()
                TriggerEvent('qb-vehiclekeys:client:ToggleEngine')
            end },

            -- 上锁 / 解锁
            { {'lock doors', 'lock the doors', 'lock car', 'lock vehicle'}, 'Locking doors...', function()
                if cache.vehicle then
                    local status = GetVehicleDoorLockStatus(cache.vehicle)
                    if status ~= 2 then PlayLockEffect(cache.vehicle) SetVehicleDoorsLocked(cache.vehicle, 2) end
                end
            end },
            { {'unlock doors', 'unlock the doors', 'unlock car', 'unlock vehicle'}, 'Unlocking doors...', function()
                if cache.vehicle then
                    local status = GetVehicleDoorLockStatus(cache.vehicle)
                    if status == 2 or status == 3 then PlayLockEffect(cache.vehicle) SetVehicleDoorsLocked(cache.vehicle, 1) end
                end
            end },

            -- 转向灯
            { {'left signal', 'left indicator', 'signal left', 'left blinker'}, 'Left signal...', function()
                ExecuteCommand('+signalLeft') Wait(50) ExecuteCommand('-signalLeft')
            end },
            { {'right signal', 'right indicator', 'signal right', 'right blinker'}, 'Right signal...', function()
                ExecuteCommand('+signalRight') Wait(50) ExecuteCommand('-signalRight')
            end },
            { {'hazards', 'hazard lights', 'hazards on', 'hazards off', 'emergency lights'}, 'Toggling hazards...', function()
                ExecuteCommand('+signalHazard') Wait(50) ExecuteCommand('-signalHazard')
            end },

            -- 安全带
            { {'seatbelt', 'put on seatbelt', 'buckle up', 'belt on', 'belt off'}, 'Toggling seatbelt...', function()
                ExecuteCommand('+toggleSeatbelt') Wait(50) ExecuteCommand('-toggleSeatbelt')
            end },

            -- 车灯
            { {'headlights', 'lights on', 'lights off', 'turn on lights', 'turn off lights'}, 'Toggling headlights...', function()
                if cache.vehicle then
                    local _, lightsOn = GetVehicleLightsState(cache.vehicle)
                    if lightsOn == 1 or lightsOn == true then SetVehicleLights(cache.vehicle, 1) else SetVehicleLights(cache.vehicle, 2) end
                end
            end },

            -- 车窗
            { {'windows down', 'open windows', 'roll down windows'}, 'Opening windows...', function()
                if cache.vehicle then for i = 0, 3 do RollDownWindow(cache.vehicle, i) end end
            end },
            { {'windows up', 'close windows', 'roll up windows'}, 'Closing windows...', function()
                if cache.vehicle then for i = 0, 3 do RollUpWindow(cache.vehicle, i) end end
            end },

            -- 限速
            { {'activate limiter', 'set limiter', 'speed limiter', 'limiter on'}, 'Activating limiter...', function()
                if not limiterState.enabled then ToggleLimiter() end
            end },
            { {'deactivate limiter', 'limiter off', 'remove limiter', 'disable limiter'}, 'Deactivating limiter...', function()
                if limiterState.enabled then ToggleLimiter() end
            end },

            -- 定速巡航
            { {'activate cruise', 'cruise control', 'cruise on', 'set cruise'}, 'Activating cruise control...', function()
                if not cruiseState.enabled then
                    if cache.vehicle then
                        SetCruiseSpeed(math.floor(GetEntitySpeed(cache.vehicle) * 3.6))
                    end
                    ToggleCruise()
                end
            end },
            { {'deactivate cruise', 'cruise off', 'disable cruise', 'stop cruise'}, 'Deactivating cruise control...', function()
                if cruiseState.enabled then ToggleCruise() end
            end },

            -- 快速导航标记
            { {'mark gas', 'mark gas station', 'nearest gas', 'find gas'}, 'Marking nearest gas station...', function()
                SetFastNavWaypoint('gas')
            end },
            { {'mark market', 'mark store', 'nearest market', 'find market'}, 'Marking nearest market...', function()
                SetFastNavWaypoint('market')
            end },
            { {'mark mechanic', 'nearest mechanic', 'find mechanic'}, 'Marking nearest mechanic...', function()
                SetFastNavWaypoint('mechanic')
            end },
            { {'mark atm', 'nearest atm', 'find atm'}, 'Marking nearest ATM...', function()
                SetFastNavWaypoint('atm')
            end },
            { {'mark barber', 'nearest barber', 'find barber'}, 'Marking nearest barber...', function()
                SetFastNavWaypoint('barber')
            end },
            { {'mark clothing', 'nearest clothing', 'find clothing', 'mark clothes'}, 'Marking nearest clothing store...', function()
                SetFastNavWaypoint('clothing')
            end },
        },
        tr = {
            -- 引擎
            { {'motoru çalıştır', 'motoru aç', 'motor çalıştır', 'motoru calistir'}, 'Motor çalıştırılıyor...', function()
                TriggerEvent('qb-vehiclekeys:client:ToggleEngine')
            end },
            { {'motoru kapat', 'motor kapat', 'motoru söndür', 'motoru kapa'}, 'Motor kapatılıyor...', function()
                TriggerEvent('qb-vehiclekeys:client:ToggleEngine')
            end },

            -- 上锁
            { {'kapıları kilitle', 'kilitle', 'arabayı kilitle', 'kapilari kilitle'}, 'Kapılar kilitleniyor...', function()
                if cache.vehicle then
                    local status = GetVehicleDoorLockStatus(cache.vehicle)
                    if status ~= 2 then PlayLockEffect(cache.vehicle) SetVehicleDoorsLocked(cache.vehicle, 2) end
                end
            end },
            { {'kilidi aç', 'kapıları aç', 'kilidi ac', 'kapilari ac'}, 'Kilit açılıyor...', function()
                if cache.vehicle then
                    local status = GetVehicleDoorLockStatus(cache.vehicle)
                    if status == 2 or status == 3 then PlayLockEffect(cache.vehicle) SetVehicleDoorsLocked(cache.vehicle, 1) end
                end
            end },

            -- 转向灯
            { {'sol sinyal', 'sola sinyal', 'sol sinyal aç'}, 'Sol sinyal...', function()
                ExecuteCommand('+signalLeft') Wait(50) ExecuteCommand('-signalLeft')
            end },
            { {'sağ sinyal', 'saga sinyal', 'sağ sinyal aç'}, 'Sağ sinyal...', function()
                ExecuteCommand('+signalRight') Wait(50) ExecuteCommand('-signalRight')
            end },
            { {'dörtlüleri aç', 'dörtlü aç', 'dortluleri ac', 'dörtlüleri kapat', 'dörtlü kapat'}, 'Dörtlüler...', function()
                ExecuteCommand('+signalHazard') Wait(50) ExecuteCommand('-signalHazard')
            end },

            -- 安全带
            { {'kemer tak', 'emniyet kemeri', 'kemeri tak', 'kemer çıkar', 'kemeri cikar'}, 'Emniyet kemeri...', function()
                ExecuteCommand('+toggleSeatbelt') Wait(50) ExecuteCommand('-toggleSeatbelt')
            end },

            -- 车灯
            { {'farları aç', 'ışıkları aç', 'farlari ac', 'farları kapat', 'ışıkları kapat'}, 'Farlar...', function()
                if cache.vehicle then
                    local _, lightsOn = GetVehicleLightsState(cache.vehicle)
                    if lightsOn == 1 or lightsOn == true then SetVehicleLights(cache.vehicle, 1) else SetVehicleLights(cache.vehicle, 2) end
                end
            end },

            -- 车窗
            { {'camları aç', 'camları indir', 'camlari ac'}, 'Camlar açılıyor...', function()
                if cache.vehicle then for i = 0, 3 do RollDownWindow(cache.vehicle, i) end end
            end },
            { {'camları kapat', 'camları kaldır', 'camlari kapat'}, 'Camlar kapatılıyor...', function()
                if cache.vehicle then for i = 0, 3 do RollUpWindow(cache.vehicle, i) end end
            end },
            { {'ön sol cam', 'sol ön cam'}, 'Ön sol cam açılıyor...', function()
                if cache.vehicle then RollDownWindow(cache.vehicle, 0) end
            end },
            { {'ön sağ cam', 'sağ ön cam'}, 'Ön sağ cam açılıyor...', function()
                if cache.vehicle then RollDownWindow(cache.vehicle, 1) end
            end },
            { {'arka sol cam', 'sol arka cam'}, 'Arka sol cam açılıyor...', function()
                if cache.vehicle then RollDownWindow(cache.vehicle, 2) end
            end },
            { {'arka sağ cam', 'sağ arka cam'}, 'Arka sağ cam açılıyor...', function()
                if cache.vehicle then RollDownWindow(cache.vehicle, 3) end
            end },

            -- 限速
            { {'sınırlayıcı aç', 'limiter aç', 'hız sınırla', 'sinirla'}, 'Hız sınırlayıcı açılıyor...', function()
                if not limiterState.enabled then ToggleLimiter() end
            end },
            { {'sınırlayıcı kapat', 'limiter kapat', 'sınırı kaldır'}, 'Hız sınırlayıcı kapatılıyor...', function()
                if limiterState.enabled then ToggleLimiter() end
            end },

            -- 定速巡航
            { {'hız sabitle', 'cruise aç', 'sabitle', 'hizi sabitle'}, 'Hız sabitleniyor...', function()
                if not cruiseState.enabled then
                    if cache.vehicle then
                        SetCruiseSpeed(math.floor(GetEntitySpeed(cache.vehicle) * 3.6))
                    end
                    ToggleCruise()
                end
            end },
            { {'sabitlemeyi kapat', 'cruise kapat', 'sabitleme kapat'}, 'Hız sabitleme kapatılıyor...', function()
                if cruiseState.enabled then ToggleCruise() end
            end },

            -- 快速导航标记
            { {'benzinlik işaretle', 'en yakın benzinlik', 'benzinlige git'}, 'En yakın benzinlik işaretleniyor...', function()
                SetFastNavWaypoint('gas')
            end },
            { {'market işaretle', 'en yakın market', 'markete git'}, 'En yakın market işaretleniyor...', function()
                SetFastNavWaypoint('market')
            end },
            { {'tamirci işaretle', 'en yakın tamirci', 'tamirciye git'}, 'En yakın tamirci işaretleniyor...', function()
                SetFastNavWaypoint('mechanic')
            end },
            { {'atm işaretle', 'en yakın atm'}, 'En yakın ATM işaretleniyor...', function()
                SetFastNavWaypoint('atm')
            end },
            { {'berber işaretle', 'en yakın berber'}, 'En yakın berber işaretleniyor...', function()
                SetFastNavWaypoint('barber')
            end },
            { {'giyim işaretle', 'en yakın giyim', 'kıyafetçi'}, 'En yakın giyim mağazası işaretleniyor...', function()
                SetFastNavWaypoint('clothing')
            end },
        }
    },
}


-- ═══════════════════════════════════════════════════════════════
-- 载具改装 (性能模式)
-- ═══════════════════════════════════════════════════════════════
-- 根据选择的改装改变速度表样式:
--   Comfort → 默认速度表
--   Sport → Yolante 速度表
--   Sport Plus → Ferrante 速度表

Config.VehicleMods = {
    -- 启用载具改装系统
    Enabled = true,

    -- 打开载具改装面板的按键 (在载具内)
    -- 设置为 false 关闭按键
    Keybind = 'F9',
    KeybindDescription = '打开载具改装面板',

    -- 打开载具改装面板的指令
    -- 设置为 false 关闭指令
    Command = 'vehiclemods',

    -- 安装 Sport/Sport Plus/Drift 改装需要物品?
    RequireItems = true,

    -- 每种改装所需物品
    -- 玩家需要列表中所有物品才能安装
    RequiredItems = {
        ['sport'] = {
            { name = 'performance_chip', amount = 1, remove = true },
        },
        ['drift'] = {
            { name = 'drift_chip', amount = 1, remove = true },
        },
        ['sport-plus'] = {
            { name = 'racing_chip', amount = 1, remove = true },
        },

    },

    -- 安装时间 (秒)
    InstallTime = {
        ['sport'] = 5,
        ['drift'] = 5,
        ['sport-plus'] = 8,
    },

    -- 为漂移/运动/运动+模式应用载具物理变化?
    ApplyPhysics = true,

    -- 物理修改器 (应用于载具操控的乘数)
    Physics = {
        ['drift'] = {
            -- ══════════════════════════════════════════════════════════════
            -- 街机漂移模式
            -- 所有值均为乘数以应用于载具原始操控
            -- < 1.0 = 降低, 1.0 = 无变化, > 1.0 = 提升
            -- ══════════════════════════════════════════════════════════════

            -- 动力 & 油门响应
            fInitialDriveForce = 1.15,          -- 扭矩小幅提升 +15% (帮助起飘)
            fDriveInertia = 1.35,               -- 油门响应灵敏 +35% (精准动力控制)

            -- 抓地力 (漂移核心手感)
            fTractionCurveMax = 0.62,           -- 过弯抓地力 -38% (弯中轻松打滑)
            fTractionCurveMin = 0.58,           -- 加速抓地力 -42% (起步轻松甩尾)
            fTractionCurveLateral = 2.20,       -- 滑动角度 +120% (流畅持续漂移)
            fTractionLossMult = 1.90,           -- 更容易打滑 +90%
            fLowSpeedTractionLossMult = 0.65,   -- 低速打滑减少 -35% (仍可驾驶)

            -- 重量分布
            fTractionBiasFront = 0.92,          -- 后驱偏向 (与原始值相乘, 通常 ~0.48-0.52)

            -- 悬挂 (软 = 更多重心转移 = 更好漂移手感)
            fSuspensionForce = 0.65,            -- 软悬挂 -35%
            fAntiRollBarForce = 0.45,           -- 极低防倾杆 -55% (更多车身侧倾)
            fSuspensionReboundDamp = 0.70,      -- 软回弹 -30%
            fSuspensionCompDamp = 0.75,         -- 软压缩 -25%

            -- 转向
            fSteeringLock = 1.55,               -- 更大转向角度 +55% (反打范围)

            -- 手刹 (起飘工具)
            fHandBrakeForce = 2.00,             -- 双倍手刹力度 (瞬间起飘)

            -- 风阻 (小幅提升防止速度失控)
            fInitialDragCoeff = 1.12,           -- 小幅风阻 +12%
        },
        ['sport'] = {
            fInitialDriveMaxFlatVel = 1.15,  -- 最高速度 +15%
            fDriveInertia = 1.10,             -- 加速响应 +10%
            fTractionCurveMax = 1.05,         -- 抓地力 +5%
            fTractionCurveMin = 1.05,
            fSuspensionForce = 1.10,          -- 悬挂硬度 +10%
        },
        ['sport-plus'] = {
            fInitialDriveMaxFlatVel = 1.25,  -- 最高速度 +25%
            fDriveInertia = 1.20,             -- 加速响应 +20%
            fTractionCurveMax = 1.10,         -- 抓地力 +10%
            fTractionCurveMin = 1.10,
            fSuspensionForce = 1.20,          -- 悬挂硬度 +20%
            fBrakeBiasFront = 0.95,           -- 更好制动
        },
    },

    -- 保存每辆车的改装? (需要数据库表)
    -- true  = 改装永久保存 (需要 codem_hud_vehicle_mods 表)
    -- false = 改装仅当前会话有效 (重启服务器重置)
    PersistMods = true,
}

-- ═══════════════════════════════════════════════════════════════
-- 载具功能 (安全带, 氮气, 转向灯, 警笛)
-- ═══════════════════════════════════════════════════════════════

Config.VehicleFeatures = {
    -- ─────────────────────────────────────────────────────────────
    -- 安全带系统
    -- ─────────────────────────────────────────────────────────────
    Seatbelt = {
        Enabled = true,
        Key = 'B',

        -- 未系安全带驾驶时警告声
        Beep = {
            Enabled = true,
            Speed = 30,             -- km/h - 超过此速度开始蜂鸣
            Interval = 2000,        -- ms - 蜂鸣间隔
        },

        -- 车祸时飞出挡风玻璃 (原生 GTA 物理)
        Ejection = {
            Enabled = true,
            -- 'low'       = ~45 km/h (简单, 极易触发)
            -- 'medium'    = ~72 km/h (平衡, 推荐)
            -- 'realistic' = ~60 km/h (现实车祸速度)
            -- 'high'      = ~126 km/h (GTA 默认, 极难触发)
            Difficulty = 'medium',
        },
    },

    -- ─────────────────────────────────────────────────────────────
    -- 氮气系统 (百分比)
    -- ─────────────────────────────────────────────────────────────
    -- 使用氮气物品安装/补充
    Nitro = {
        Enabled = true,
        Key = 'LSHIFT',             -- 按住激活

        -- 物品 (从背包使用安装/补充)
        Item = 'nitrous',

        -- 罐子设置
        UseRate = 5,               -- 每秒消耗百分比 (100/5 = 20秒满罐)
        Cooldown = 1.5,             -- 空罐后再次使用冷却时间

        -- 增压功率
        BoostPower = 1.0,           -- 引擎动力倍数

        -- 视觉效果
        Effects = {
            ExhaustFlame = true,    -- 排气火焰
            Backfire = true,        -- 氮气激活时回火火花
            Purge = true,           -- 引擎盖喷烟
            PurgeWhileMoving = false, -- 行驶时显示喷烟 (false = 仅静止时)
            Sound = true,           -- 氮气激活音效 (原生 GTA 音效)
            SoundType = 'boost',    -- 'boost' (原生载具增压), 'flare' (火焰呼啸), 'turbo' (增压+屏幕效果)
        },
        FlameScale = 1.0,           -- 火焰大小 (0.5 = 小, 1.0 = 正常, 2.0 = 大)
    },

    -- ─────────────────────────────────────────────────────────────
    -- 转向灯 & 双闪
    -- ─────────────────────────────────────────────────────────────
    Signals = {
        Enabled = true,
        LeftKey = 'LEFT',
        RightKey = 'RIGHT',
        HazardKey = 'DOWN',
    },

    -- ─────────────────────────────────────────────────────────────
    -- 警笛检测 (警察/EMS)
    -- ─────────────────────────────────────────────────────────────
    Siren = {
        Enabled = true,
    },

    -- ─────────────────────────────────────────────────────────────
    -- 漂移计分 (漂移速度表覆盖层)
    -- ─────────────────────────────────────────────────────────────
    -- 街机设置 - 易漂移, 快速得分, 宽容
    DriftCounter = {
        Enabled = true,                 -- 启用漂移计分覆盖
        MinAngle = 8,                   -- 开始漂移的最小角度 (度) - 街机简单
        MinSpeed = 15,                  -- 最低速度阈值 (km/h) - 低速可漂移
        ComboTimeout = 4000,            -- 重置前更长超时 (毫秒) - 宽容
        UIGracePeriod = 1000,           -- 漂移后 UI 更长可见时间 (更流畅体验)
        ResetOnCollision = true,        -- 载具碰撞时重置漂移分数
        ScoreMultiplier = 2.0,          -- 更高倍数 = 更快得分
        ComboGainTime = 1500,           -- 更快连击获得 (连续漂移毫秒)
        MaxCombo = 15,                  -- 更高最大连击更刺激
    },

    -- ─────────────────────────────────────────────────────────────
    -- 直升机悬停模式
    -- ─────────────────────────────────────────────────────────────
    HoverMode = {
        Enabled = true,                 -- 启用悬停模式
        Key = 'J',                       -- 默认按键 (可在 FiveM 改键)
        ActivationTime = 3000,           -- 激活悬停模式时间 (毫秒) (0 = 立即)
    },
}

-- ═══════════════════════════════════════════════════════════════
-- 载具音乐系统
-- ═══════════════════════════════════════════════════════════════
-- 载具内同步音乐播放
-- 司机控制音乐, 所有乘客听到相同音乐
-- 附近玩家在距离内也能听到

Config.VehicleMusic = {
    -- 启用载具音乐系统
    Enabled = true,

    -- 从其他载具听到音乐的最大距离 (米)
    Distance = 35.0,

    -- 时间更新间隔 (毫秒) - 同步时间频率
    TimeUpdateInterval = 200,

    -- 时间漂移阈值 (秒) - 漂移超过则重新同步
    TimeDriftThreshold = 2.0,

    -- 附近检测间隔 (毫秒) - 检测距离频率
    NearbyCheckInterval = 2000,

    -- 车窗对音量的影响 (关闭车窗静音)
    WindowEffect = {
        Enabled = true,
        ClosedWindowMultiplier = 0.35,  -- 所有车窗关闭时音量倍数 (0.0 - 1.0)
    },

    -- 附近载具音乐的空间音频效果
    -- 添加真实音频处理: 车门沉闷低音, 回声/混响
    SpatialAudio = {
        Enabled = true,

        -- 沉闷效果: 低通滤波器模拟声音穿过车门/墙壁
        MuffledEffect = true,
        MuffledClosedWindow = 0.75,     -- 车窗关闭时沉闷程度 (0.0 = 无, 1.0 = 完全沉闷)
        MuffledOpenWindow = 0.30,       -- 车窗打开时沉闷程度 (仍听起来"外面")
        MuffledDistanceScale = 0.50,    -- 距离增加沉闷程度 (0.0 = 无, 1.0 = 严重)
        MuffledMax = 0.95,              -- 无论距离最大沉闷程度 (0.0 - 1.0)

        -- 混响效果: 距离处的回声/混响
        ReverbEffect = true,
        ReverbStartDistance = 3.0,      -- 混响开始距离 (米)
        ReverbMax = 0.25,               -- 最大混响量 (0.0 = 无, 1.0 = 最大回声)

        -- 多普勒效应: 载具接近/远离时音高变化
        DopplerEffect = true,
        DopplerSpeedOfSound = 80.0,     -- 虚拟音速 (更低 = 更明显效果)
        DopplerMin = 0.75,              -- 最小音高倍数 (快速接近)
        DopplerMax = 1.50,              -- 最大音高倍数 (快速远离)
        DopplerMinDistance = 0.5,       -- 多普勒激活最小距离 (米)
    },

    -- 司机引擎未熄火下车时, 音乐继续播放时长 (秒)
    -- 司机在此时间内返回, 音乐继续. 否则引擎+音乐停止
    -- 设置为 0 下车立即停止音乐 (旧行为)
    ExitGracePeriod = 60,

    -- 自定义音频解析 API 地址 (可选)
    -- 如果设置, 将优先于内置方法尝试
    -- 支持: 自托管 Cobalt, yt-dlp API, 或任何兼容端点
    -- 格式: POST JSON body {"url": "https://youtube.com/watch?v=VIDEO_ID"}
    -- 预期响应: {"status": "tunnel"|"redirect"|"stream", "url": "https://direct-audio-url"}
    -- 示例: 'http://localhost:9000/' (自托管 cobalt)
    AudioResolverUrl = nil,

    -- youtube-mp36 服务的 RapidAPI 密钥 (可选)
    -- 免费密钥获取: https://rapidapi.com/ytjar/api/youtube-mp36
    -- 免费额度: ~500 请求/月. 启用真实沉闷音频效果 (低通滤波器)
    RapidApiKey = '',
}

-- ═══════════════════════════════════════════════════════════════
-- 信息栏服务端控制
-- 服务端可强制关闭单个信息栏元素
-- 如果为 false, 玩家无法看到该元素及其设置
-- ═══════════════════════════════════════════════════════════════

Config.InfoBarsEnabled = {
    onlineCount = true,    -- 在线玩家数量
    serverDetails = true,  -- 服务器名称 + discord + 地图图标块
    dataWidget = true,     -- 日期 / 时间 / 星期组件
    playerDetails = true,  -- 玩家徽章 (ID + 职业/帮派)
    cashMoney = true,      -- 现金行
    bankMoney = true,      -- 银行行
    markedMoney = true,    -- 赃款/黑钱行
    societyMoney = true,   -- 公会/职业资金行
    coin = true,           -- 代币行
}

-- ═══════════════════════════════════════════════════════════════
-- 默认 HUD 设置
-- 玩家未配置设置时使用
-- ═══════════════════════════════════════════════════════════════

Config.DefaultSettings = {
    general = {
        minimapShape = 'square',  -- 'square' 方形 或 'circle' 圆形
        voiceAssistant = true,  -- 启用语音助手组件
        streamerMode = false,  -- 为直播隐藏敏感信息
        playerMusicAudibility = true,  -- 显示音乐可听范围指示器
        cinematicMode = false,  -- 启动时带电影黑边
        focusOnRolePlay = false,  -- 专注角色扮演时模糊 HUD
        focusOnRolePlayDelay = 5000,  -- 隐藏延迟毫秒 (5000, 10000, 15000, 20000, 30000, 60000)
        refreshRate = 60,  -- HUD 更新频率: 30, 45, 60
        postalCode = true,  -- 显示邮编组件
        marker3D = true,  -- 显示屏幕 3D 标记
    },
    statusBars = {
        type = 'supreme-percentage',  -- 'supreme', 'supreme-percentage', 'mserie'
        theme = 'dynamic',  -- 'dark', 'light', 'dynamic'
        backgroundBlur = false,  -- 状态栏背景模糊
        background = true,  -- 显示状态栏背景
        attachToMinimap = false,  -- 附加到小地图位置
    },
    infoBars = {
        theme = 'dynamic',  -- 'dark', 'light', 'dynamic'
        backgroundBlur = false,  -- 信息栏背景模糊
        background = true,  -- 显示信息栏背景
        compassType = 'detailed',  -- 'widget' 或 'detailed'
        compassBehaviour = 'mouse',  -- 'mouse' 或 'player'
        time = 'local',  -- 'local', 'server', 'game'
        display = {
            hideAll = false,  -- 隐藏所有信息栏元素
            onlineCount = true,  -- 在线玩家数量
            serverDetails = true,  -- 服务器名称和详情
            dataWidget = true,  -- 数据使用/延迟组件
            playerDetails = true,  -- 玩家名称和 ID
            cashMoney = true,  -- 现金
            bankMoney = true,  -- 银行余额
            markedMoney = true,  -- 赃款/黑钱
            societyMoney = true,  -- 公会/职业账户余额
            coin = true,  -- 自定义代币/货币
        },
    },
    hotkeys = {
        theme = 'dynamic',  -- 'dark', 'light', 'dynamic'
        backgroundBlur = false,  -- 快捷键提示背景模糊
        background = true,  -- 显示快捷键背景
        display = true,  -- 显示屏幕快捷键提示
    },
    speedometer = {
        type = 'default',  -- 'default', 'drift', 'yolante', 'ferrante'
        theme = 'dynamic',  -- 'dark', 'light', 'dynamic'
        backgroundBlur = true,  -- 档位和安全带指示器背景模糊
        refreshRate = 60,  -- 速度表更新频率: 30, 45, 60
        speedUnit = 'kmh',  -- 'kmh' 或 'mph'
    },
}

-- ═══════════════════════════════════════════════════════════════
-- FLIR 热成像设置
-- ═══════════════════════════════════════════════════════════════

Config.FLIR = {
    -- 可使用 FLIR 摄像系统的直升机模型
    Enable = true, -- 设置为 false 完全禁用 FLIR 系统
    AllowedModels = {
        'polmav', 'buzzard', 'buzzard2', 'hunter', 'akula',
        'annihilator', 'annihilator2', 'savage', 'valkyrie',
        'valkyrie2', 'maverick',
    },

    Sensitivity = 4.0,    -- 鼠标灵敏度 (更高 = 旋转更快)
    LerpSpeed   = 0.5,    -- 相机平滑速度 (0.1 = 慢, 1.0 = 立即)
    ZoomSpeed   = 0.12,   -- 滚轮缩放速度
    LockSpeed   = 0.08,   -- 锁定模式追踪目标速度
    Sounds      = true,   -- 切换模式时播放音效

    -- 缩放范围 (FOV 值为度数, 更低 = 更放大)
    FOV = { Min = 5.0, Max = 90.0, Default = 60.0 },

    -- 垂直视角限制 (负数 = 下, 正数 = 上)
    Pitch = { Min = -89.0, Max = 20.0 },

    -- 相机相对于载具的偏移
    -- x: 左/右, y: 前/后, z: 上/下, pitch: 初始角度
    Camera = {
        High = { x = 0.0, y = 0.0, z = -2.0, pitch = -30.0 },  -- 空中时
        Low  = { x = 0.0, y = 2.0, z = 0.5, pitch = -5.0 },    -- 地面时
        SwitchHeight = 5.0,  -- 切换高低模式的高度阈值 (米)
    },

    -- 视觉模式设置 (普通模式始终启用)
    VisionModes = {
        Thermal  = true,  -- 启用热成像/红外视觉 (THRML)
        Negative = true,  -- 启用负色/反转视觉 (NGTV)
    },

    -- 探照灯设置
    Spotlight = {
        Distance     = 120.0,  -- 默认探照灯距离
        Brightness   = 15.0,   -- 探照灯亮度
        Hardness     = 3.0,    -- 探照灯边缘硬度
        Radius       = 12.0,   -- 默认探照灯锥形半径
        DistanceStep = 10.0,   -- 每次按键距离变化
        RadiusStep   = 1.0,    -- 每次按键半径变化
        DistanceMin  = 30.0,   -- 最小探照灯距离
        DistanceMax  = 300.0,  -- 最大探照灯距离
        RadiusMin    = 3.0,    -- 最小探照灯半径
        RadiusMax    = 30.0,   -- 最大探照灯半径
    },

    -- 目标信息显示设置
    TargetInfo = {
        ShowPlayerName    = true,   -- 显示玩家 RP 角色名
        ShowPlayerMugshot = true,   -- 显示玩家头像
        ShowPlayerId      = true,   -- 显示玩家服务器 ID
        ShowVehicleModel  = true,   -- 显示载具模型名称
        ShowVehiclePlate  = true,   -- 显示载具牌照
        ShowVehicleSpeed  = true,   -- 显示载具速度
        ShowVehicleHealth = true,   -- 显示载具引擎健康
        ShowVehicleHeading = true,  -- 显示载具朝向
        ShowDistance       = true,  -- 显示与目标距离
        ScanDelay          = 1.5,   -- 扫描后显示信息的秒数 (进度条)
        HideMaskedPlayer   = true,  -- 戴面具时隐藏玩家信息 (名称, 头像, ID)
        SignalJammer = {
            Enabled = true,                      -- 启用信号干扰器功能
            Items   = { 'signal_jammer' },       -- 玩家携带该物品时隐藏信息 (名称, 头像, ID)
        },
    },

    -- FLIR 时绘制在道路上的 3D 街道名称标签
    StreetNames = {
        Enable         = true,   -- 显示浮动街道名称标签
        MaxNodes       = 40,     -- 扫描道路节点数量 (更多 = 更广覆盖, 更重)
        MaxDistance     = 350.0,  -- 最大绘制距离米
        UpdateInterval = 1000,   -- 重新扫描道路节点频率毫秒
        FontScale      = 0.45,   -- 基础文字大小
    },

    -- 按键绑定 (control = FiveM 控制 ID, key = 注册按键)
    Keys = {
        Access        = { key = 'e',   label = 'E' },       -- 快速打开 FLIR (在支持的直升机)
        Exit          = { control = 200, label = 'ESC' },      -- 退出 FLIR 相机
        VisionNext    = { control = 182, label = 'L' },         -- 下一个视觉模式 (THRML/NRM/NGTV)
        VisionPrev    = { key = 'j',     label = 'J' },         -- 上一个视觉模式
        Camera        = { control = 37,  label = 'TAB' },       -- 切换相机模式 (HDEO/FOCUS/LOCK)
        Zoom          = {                label = 'SCROLL' },     -- 缩放 (仅标签)
        ZoomReset     = { control = 45,  label = 'R' },          -- 重置缩放为默认
        Lock          = { control = 245, label = 'T' },          -- 锁定/解锁目标
        ResetView     = { control = 47,  label = 'G' },          -- 重置相机旋转
        Spotlight     = { control = 38,  label = 'E' },          -- 切换探照灯
        SpotDistUp    = { key = 'UP',    label = 'UP' },         -- 增加探照灯距离
        SpotDistDown  = { key = 'DOWN',  label = 'DOWN' },       -- 减少探照灯距离
        SpotRadiusUp  = { key = 'RIGHT', label = 'RIGHT' },      -- 增加探照灯半径
        SpotRadiusDown = { key = 'LEFT', label = 'LEFT' },       -- 减少探照灯半径
    },
}

-- ═══════════════════════════════════════════════════════════════
-- 相机辅助
-- ═══════════════════════════════════════════════════════════════
-- 第三人称相机偏移功能 (通用设置面板 > 相机辅助)
-- 服务端可全局启用/禁用功能并控制
-- 玩家可用的滑块
Config.CameraAccessibility = {
    -- 主开关. false = 功能完全禁用 (隐藏 UI + Lua 禁用)
    Enabled = true,

    -- 单个滑块开关. 服务端可禁用特定轴
    Sliders = {
        Vertical   = true,
        Horizontal = true,
        FOV        = true,
    },
}

-- ═══════════════════════════════════════════════════════════════
-- 高级设置
-- ═══════════════════════════════════════════════════════════════

-- 启用控制台调试打印
Config.Debug = false

-- 启动时自动创建 SQL 表
Config.AutoSql = true