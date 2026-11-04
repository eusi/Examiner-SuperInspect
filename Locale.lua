--------------------------------------------------------------------------------------------------------
--
-- Locale.lua
-- Resolves localized interface text with an English fallback.
--
----------------------

local _, ns = ...
if ns.blocked then
    return
end
ns.locales = {}
local globals = {
    Honor = "HONOR",
    Rank = "RANK",
    Today = "HONOR_TODAY",
    Yesterday = "HONOR_YESTERDAY",
    Lifetime = "HONOR_LIFETIME",
}
local locale = GetLocale()
if locale == "enGB" then
    locale = "enUS"
end
ns.L = setmetatable({}, {
    -- Resolve client-language text with an English fallback.
    __index = function(_, key)
        local global = globals[key]
        local text = global and ns.Compat.Text(_G[global])
        return text
            or (ns.locales[locale] and ns.locales[locale][key])
            or (ns.locales.enUS and ns.locales.enUS[key])
            or key
    end,
})
-- Format a localized string with the supplied values.
function ns.F(key, ...)
    return string.format(ns.L[key], ...)
end
