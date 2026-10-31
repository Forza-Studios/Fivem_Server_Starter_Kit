--[[
    Localization System - JSON Based
    Reads locale data from shared/data/locales/*.json
    Set Config.Locale.Language in config.lua to change language

    Available languages: 'en', 'tr', 'es'

    Usage:
      L('seatbelt.on')             -> 'Seatbelt: ON'
      L('stress.increased', 75, 5) -> 'Stress: 75% (+5)'
]]

Locales = Locales or {}

local currentLanguage = 'en'

local function LoadLocaleJSON(lang)
    local raw = LoadResourceFile(GetCurrentResourceName(), 'shared/data/locales/' .. lang .. '.json')
    if not raw then return nil end
    local success, data = pcall(json.decode, raw)
    if success and data then
        return data
    end
    return nil
end

local function LoadAllLocales()
    local candidates = {'cs', 'en', 'tr', 'es', 'fr', 'de', 'pt', 'it', 'nl', 'pl', 'ru', 'zh', 'ja', 'ko', 'ar' }
    for _, lang in ipairs(candidates) do
        local data = LoadLocaleJSON(lang)
        if data then
            Locales[lang] = data
        end
    end
end

LoadAllLocales()

CreateThread(function()
    Wait(0)
    if Config and Config.Locale and Config.Locale.Language then
        currentLanguage = Config.Locale.Language
    end
    if NuiMessage then
        NuiMessage('SET_LOCALE_DATA', { locales = Locales })
        NuiMessage('SET_LOCALE', { language = currentLanguage })
    end
end)

local function getNestedValue(tbl, path)
    if not tbl or not path then return nil end
    local current = tbl
    for part in string.gmatch(path, '[^.]+') do
        if type(current) ~= 'table' then return nil end
        current = current[part]
        if current == nil then return nil end
    end
    return current
end

function L(key, ...)
    local locale = Locales[currentLanguage]
    local value = locale and getNestedValue(locale, key)

    if value == nil and currentLanguage ~= 'en' then
        locale = Locales['en']
        value = locale and getNestedValue(locale, key)
    end

    if value == nil then
        return key
    end

    local args = { ... }
    if #args > 0 then
        local success, result = pcall(string.format, value, ...)
        if success then
            return result
        end
    end

    return value
end

function GetLocale()
    return currentLanguage
end

function SetLocale(lang)
    if Locales[lang] then
        currentLanguage = lang
        if NuiMessage then NuiMessage('SET_LOCALE', { language = lang }) end
        return true
    end
    return false
end

function HasLocale(key)
    local locale = Locales[currentLanguage]
    if locale and getNestedValue(locale, key) ~= nil then
        return true
    end
    locale = Locales['en']
    return locale and getNestedValue(locale, key) ~= nil
end

function GetAvailableLocales()
    local langs = {}
    for lang, _ in pairs(Locales) do
        langs[#langs + 1] = lang
    end
    return langs
end
