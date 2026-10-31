

Locales = Locales or {}

function _U(key, ...)
    local lang = Config.Locale or 'en'
    local pack = Locales[lang]
    if not pack then return key end

    local str = pack[key]
    if not str then return key end

    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

function GetLocale()
    return Locales[Config.Locale] or Locales.en or {}
end

