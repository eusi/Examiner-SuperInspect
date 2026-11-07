--------------------------------------------------------------------------------------------------------
--
-- Services/ForeverTalents.lua
-- Reads only the active Forever talent build until inactive inspection is verified.
--
----------------------

local _, ns = ...
if ns.blocked or not ns.Compat.isForever then
    return
end

--------------------------------------------------------------------------------------------------------
--                                         Talent Inspection                                          --
--------------------------------------------------------------------------------------------------------

-- Use the native active snapshot without querying experimental talent groups.
function ns.Talents.ReadForever(unit, isSelf)
    return ns.Talents.ReadTraits(unit, isSelf)
end
