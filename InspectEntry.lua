local _, ns = ...;
if ns.blocked then return; end
local ex, C = ns.ex, ns.Compat;
SlashCmdList.INSPECT = function()
    ex:DoInspect("target");
end;
if C.isEra or C.isTBC then return; end -- These clients still use the legacy entry point.

-- Replace the menu responder before Blizzard sends its own inspect request.
local function ConfigureInspectEntry(_, root, context)
    local unit = context and context.unit;
    if not C.IsString(unit) or not UnitExists(unit) then return; end
    local guid = UnitGUID(unit);
    if not C.IsString(guid) then return; end
    local entry;
    for _, description in root:EnumerateElementDescriptions() do entry = description; end
    if not entry or type(entry.SetResponder) ~= "function" then return; end
    entry:SetResponder(function()
        -- The menu may outlive its original unit token.
        local current = UnitExists(unit) and UnitGUID(unit);
        if not C.IsString(current) or current ~= guid then
            ns.Record("inspect-menu", "target changed; ignored");
            return;
        end
        ns.Record("inspect-menu", unit);
        ex:DoInspect(unit);
    end);
end

local function Install()
    local mixin = UnitPopupInspectButtonMixin;
    if type(mixin) ~= "table" or type(mixin.CreateMenuDescription) ~= "function" then return false; end
    hooksecurefunc(mixin, "CreateMenuDescription", ConfigureInspectEntry);
    ns.inspectEntry = "unit popup responder";
    return true;
end

if not Install() then
    -- Some clients load the shared unit-popup implementation on demand.
    local listener = CreateFrame("Frame");
    listener:RegisterEvent("ADDON_LOADED");
    listener:SetScript("OnEvent", function(self)
        if Install() then self:UnregisterEvent("ADDON_LOADED"); end
    end);
    ns.inspectEntryListener = listener;
    ns.inspectEntry = "waiting for unit popup";
end
