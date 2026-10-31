
function GetLocaleTable(lang)
    if type(Locales) == "table" and type(lang) == "string" and type(Locales[lang]) == "table" then
        return Locales[lang]
    end
    return nil
end

function GetActiveLocale()
    local lang = (type(Config) == "table" and Config.Locale) or nil
    local active = GetLocaleTable(lang)
    if not active then
        active = GetLocaleTable("en")
        if not active then
            active = {}
        end
    end
    return active
end

function L(key, ...)
    local active = GetActiveLocale()
    local text = active[key]

    if type(text) ~= "string" then
        local enLocale = GetLocaleTable("en")
        if enLocale then
            text = enLocale[key]
        end
    end

    if type(text) ~= "string" then
        return tostring(key)
    end

    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then
            return formatted
        end
    end

    return text
end

function LocaleTable()
    local combined = {}
    local enLocale = GetLocaleTable("en") or {}
    for k, v in pairs(enLocale) do
        combined[k] = v
    end

    local activeLocale = GetActiveLocale()
    for k, v in pairs(activeLocale) do
        combined[k] = v
    end

    return combined
end
--fivevaultaqOnJ8Top#g : https://discord.gg/fivevault
--fivevaultzaOnUATopnv : https://discord.gg/fivevault
--fivevault-8rOnLSTopSy : https://discord.gg/fivevault
--fivevaultsYKOnWpTopN2 : https://discord.gg/fivevault
--fivevault_JCOn8JTopsm : https://discord.gg/fivevault
