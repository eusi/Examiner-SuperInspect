--------------------------------------------------------------------------------------------------------
--
-- Modules/professions.lua
-- Inspects Forever profession skills and opens live recipe links.
--
----------------------


--------------------------------------------------------------------------------------------------------
--                                            Module Setup                                            --
--------------------------------------------------------------------------------------------------------

local _, ns = ...
if
    ns.blocked
    or not ns.Compat.isForever
    or type(GetComparisonStatistic) ~= "function"
    or type(SetAchievementComparisonUnit) ~= "function"
    or type(ClearAchievementComparisonUnit) ~= "function"
then
    return
end
local ex, C, L = ns.ex, ns.Compat, ns.L
local mod = ex:CreateModule("Professions", L.Professions)
mod.buttonLabel = L["Professions short"]
mod.help = L["Shows profession skill levels."]
mod.toggleHelp =
    L["Enable/disable the Professions module, which shows profession skill levels."]
mod.cacheHelp = L["Saves profession skill levels for later viewing. Requires Core Caching."]
mod.icon = "Interface\\Icons\\Trade_BlackSmithing"
mod.canCache = true
mod:CreatePage(false, L.Professions)
mod:HasButton(true)
mod:HasData(nil)
local worker = CreateFrame("Frame")
worker:Hide()
mod.worker = worker
local rows, entries = {}, {}
mod.rows, mod.entries = rows, entries
local ROWS, HEIGHT = 8, 25
local lastRequest = -100
local definitions = {
    { 1527, 2259, 171, "Alchemy", "Trade_Alchemy", true },
    { 1532, 2018, 164, "Blacksmithing", "Trade_BlackSmithing", true },
    { 1535, 7411, 333, "Enchanting", "Trade_Engraving", true },
    { 1544, 4036, 202, "Engineering", "Trade_Engineering", true },
    { 1538, 2366, 182, "Herbalism", "Trade_Herbalism" },
    { 1536, 2108, 165, "Leatherworking", "Trade_LeatherWorking", true },
    { 1537, 2575, 186, "Mining", "Trade_Mining", true },
    { 1541, 8613, 393, "Skinning", "INV_Misc_Pelt_Wolf_01" },
    { 1542, 3908, 197, "Tailoring", "Trade_Tailoring", true },
    { 1524, 2550, 185, "Cooking", "INV_Misc_Food_15", true, true },
    { 1519, 7620, 356, "Fishing", "Trade_Fishing", false, true },
    { 281, 3273, 129, "First Aid", "Spell_Holy_SealOfSacrifice", true, true },
}
local byID = {}
for _, definition in ipairs(definitions) do
    byID[definition[1]] = definition
end
local status = ns.Fonts.Create(mod.page, nil, "ARTWORK", "GameFontHighlightSmall")
mod.status = status
status:SetPoint("TOPLEFT", 10, -34)
status:SetPoint("TOPRIGHT", -10, -34)
status:SetJustifyH("LEFT")


--------------------------------------------------------------------------------------------------------
--                                          Profession Data                                           --
--------------------------------------------------------------------------------------------------------

-- Accept only complete nonnegative skill counters, preserving unknown values.
local function Skill(value)
    if value == "--" or value == "—" then
        return 0
    end
    if C.IsString(value) then
        value = tonumber((value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[,%.%s]", "")))
    end
    if C.IsNumber(value) and value >= 0 and value < math.huge and value % 1 == 0 then
        return value
    end
end

-- Keep live links and asynchronous replies tied to the current inspection session.
local function Valid(session)
    local I = ns.Inspector
    return mod:IsEnabled()
        and session
        and I.active == session
        and I:Valid(session)
        and not session.cached
        and not ex.isCacheEntry
        and ex.unitType ~= 1
end

-- Report a visible foreign comparison without changing its data.
local function Busy()
    return AchievementFrameComparison and AchievementFrameComparison:IsShown()
end

local guardedComparison

-- Keep unsolicited comparison replies out of Blizzard's hidden summary view.
local function GuardHiddenComparison()
    local comparison = AchievementFrameComparison
    if not comparison then
        return false
    end
    if comparison == guardedComparison then
        return true
    end
    local handler = comparison:GetScript("OnEvent")
    if not handler then
        return false
    end
    -- The native hidden panel otherwise forwards its "summary" category to numeric APIs.
    comparison:SetScript("OnEvent", function(self, event, ...)
        if event == "INSPECT_ACHIEVEMENT_READY" and not self:IsShown() then
            return
        end
        return handler(self, event, ...)
    end)
    guardedComparison = comparison
    return true
end

if not GuardHiddenComparison() then
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("ADDON_LOADED")
    -- Guard the native comparison after its load-on-demand addon creates the frame.
    listener:SetScript("OnEvent", function(self)
        if GuardHiddenComparison() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

-- Stop the worker and release comparison data only while Examiner owns it.
function mod:Stop(release)
    worker:Hide()
    worker:UnregisterEvent("INSPECT_ACHIEVEMENT_READY")
    local owned = self.ownsComparison
    self.ownsComparison = nil
    self.session = nil
    if release and owned then
        self.sending = true
        C.Try(ClearAchievementComparisonUnit)
        self.sending = false
    end
end

-- Discard pending work after another addon changes the shared comparison.
local function ForeignComparison()
    if not mod.sending and mod.session then
        mod:Stop(false)
        mod.state = "unavailable"
        mod:Draw()
    end
end
hooksecurefunc("SetAchievementComparisonUnit", ForeignComparison)
hooksecurefunc("ClearAchievementComparisonUnit", ForeignComparison)

-- Read skill counters after a matching reply, or directly for the player.
function mod:Read(session, own)
    if not Valid(session) then
        return
    end
    local data = { skills = {}, guid = session.guid, time = time(), complete = true }
    for _, definition in ipairs(definitions) do
        local value = Skill(C.Try(own and GetStatistic or GetComparisonStatistic, definition[1]))
        if value == nil then
            data.complete = false
        elseif value > 0 then
            data.skills[#data.skills + 1] = {
                id = definition[1],
                name = L[definition[4]],
                value = value,
            }
        end
    end
    self.data, self.liveSession = data, session
    self.state = data.complete and "ready" or "unavailable"
    self:Stop(true)
    self:Draw()
    self:HasData(true)
    if data.complete then
        ex:CachePlayer()
    end
end

-- Schedule a bounded request with a shared five-second cooldown.
function mod:Start()
    local session = ns.Inspector.active
    if self.state or not Valid(session) or not session.serverReady then
        return
    end
    if ex.isSelf then
        self:Read(session, true)
        return
    end
    GuardHiddenComparison()
    if C.IsTrue(C.Try(UnitCanAttack, "player", session.unit)) then
        self.state = "unavailable"
        self:Draw()
        return
    end
    self.session, self.state = session, "queued"
    self.started = GetTime()
    self:Draw()
    worker:Show()
    self:Step()
end

-- Wait for range and cooldown, then accept a reply within a bounded interval.
function mod:Step()
    if not Valid(self.session) then
        self:Stop(true)
        self.state = "unavailable"
        self:Draw()
        return
    end
    if Busy() then
        self:Stop(false)
        self.state = "busy"
        self:Draw()
        return
    end
    local now = GetTime()
    if now - self.started >= 12 then
        self:Stop(true)
        self.state = "unavailable"
        self:Draw()
    elseif
        self.state == "queued"
        and now - lastRequest >= 5
        and C.IsTrue(C.Try(CheckInteractDistance, self.session.unit, 1))
    then
        self.sending = true
        -- Forever otherwise retains the previously compared player's statistics.
        local cleared = pcall(ClearAchievementComparisonUnit)
        if cleared then
            self.ownsComparison = true
            self.state, self.started, lastRequest = "waiting", now, now
            worker:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
            local ok, accepted = pcall(SetAchievementComparisonUnit, self.session.unit)
            if not ok or accepted == false then
                self:Stop(true)
                self.state = "unavailable"
            end
        else
            self:Stop(false)
            self.state = "unavailable"
        end
        self.sending = false
        self:Draw()
    end
end

-- Ignore replies for an earlier player or a comparison owned by another caller.
worker:SetScript("OnEvent", function(_, _, guid)
    if
        mod.state == "waiting"
        and mod.ownsComparison
        and Valid(mod.session)
        and C.IsString(guid)
        and guid == mod.session.guid
        and not Busy()
    then
        mod:Read(mod.session, false)
    end
end)

-- Advance requests while the inspection remains valid.
worker:SetScript("OnUpdate", function()
    mod:Step()
end)


--------------------------------------------------------------------------------------------------------
--                                         Profession Display                                         --
--------------------------------------------------------------------------------------------------------

-- Permit recipe browsing only for the player's own live professions.
local function CanBrowse(item)
    local definition = item and byID[item.id]
    return definition
        and ex.isSelf
        and definition[6]
        and mod.data
        and not mod.data.cached
        and Valid(mod.liveSession)
        and mod.data.guid == mod.liveSession.guid
end

-- Render primary and secondary skills, keeping unknown and empty data distinct.
function mod:Draw()
    wipe(entries)
    local skills = self.data and self.data.skills or {}
    for group = 1, 2 do
        entries[#entries + 1] = {
            header = true,
            name = group == 1 and L["Primary professions"] or L["Secondary professions"],
        }
        for _, skill in ipairs(skills) do
            local definition = byID[skill.id]
            if definition and (not not definition[7]) == (group == 2) then
                entries[#entries + 1] = skill
            end
        end
    end
    local pending = self.state == "queued" or self.state == "waiting"
    local message =
        pending and L["Loading…"]
            or self.state == "busy" and L["Close the other achievement comparison first."]
            or self.data and self.data.cached and L["Cached profession skills"]
            or self.state ~= "ready" and L["Profession data unavailable"]
            or #skills == 0 and L["No professions reported"]
            or ""
    status:SetText(message)
    -- Start below the title; reserve a status line only while it has content.
    local top = message == "" and 36 or 55
    FauxScrollFrame_Update(self.scroll, #entries, ROWS, HEIGHT)
    for index, row in ipairs(rows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.page, "TOPLEFT", 10, -top - (index - 1) * HEIGHT)
        row:SetPoint("TOPRIGHT", self.page, "TOPRIGHT", -30, -top - (index - 1) * HEIGHT)
        if GameTooltip:IsOwned(row) then
            GameTooltip:Hide()
        end
        local item = entries[(self.scroll.offset or 0) + index]
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            local definition = byID[item.id]
            row.name:SetText(item.name)
            row.name:SetTextColor(
                item.header and 1 or 1,
                item.header and 0.82 or 1,
                item.header and 0 or 1
            )
            row.icon:SetTexture(definition and ("Interface\\Icons\\" .. definition[5]))
            row.icon:SetShown(definition ~= nil)
            row.value:SetText(item.value and C.FormatNumber(item.value) or "")
            row:EnableMouse(not item.header and CanBrowse(item))
        end
    end
end

-- Describe whether the selected skill has a live recipe link.
local function Tooltip(row)
    if not row.item or row.item.header then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:SetText(row.item.name, 1, 0.82, 0)
    GameTooltip:AddLine(
        CanBrowse(row.item) and L["Click to browse your learned recipes."]
            or L["Recipe browsing unavailable for this entry."],
        1,
        1,
        1,
        true
    )
    GameTooltip:Show()
end

-- Open the client's native profession window using the current player's identity.
local function Browse(row)
    if not CanBrowse(row.item) then
        return
    end
    local definition = byID[row.item.id]
    local link = string.format("trade:%s:%d:%d", mod.liveSession.guid, definition[2], definition[3])
    C.Try(SetItemRef, link, "|cffffd000|H" .. link .. "|h[" .. row.item.name .. "]|h|r", "LeftButton")
end

for index = 1, ROWS do
    local row = CreateFrame("Button", nil, mod.page)
    rows[index] = row
    row:SetHeight(HEIGHT)
    row:SetPoint("TOPLEFT", mod.page, "TOPLEFT", 10, -36 - (index - 1) * HEIGHT)
    row:SetPoint("TOPRIGHT", mod.page, "TOPRIGHT", -30, -36 - (index - 1) * HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:SetScript("OnEnter", Tooltip)
    row:SetScript("OnLeave", ex.HideGTT)
    row:SetScript("OnClick", Browse)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT")
    row.name = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 24, 0)
    row.name:SetPoint("RIGHT", -35, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.value = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontNormalSmall")
    row.value:SetPoint("RIGHT")
end
mod.scroll =
    CreateFrame("ScrollFrame", "ExaminerProfessionsScroll", mod.page, "FauxScrollFrameTemplate")
mod.scroll:SetPoint("TOPLEFT", rows[1])
mod.scroll:SetPoint("BOTTOMRIGHT", rows[ROWS], -6, -1)
-- Redraw skill rows after scrolling through the profession snapshot.
mod.scroll:SetScript("OnVerticalScroll", function(self, offset)
    -- Refresh the visible portion after the native scroll offset changes.
    FauxScrollFrame_OnVerticalScroll(self, offset, HEIGHT, function()
        mod:Draw()
    end)
end)


--------------------------------------------------------------------------------------------------------
--                                           Module Events                                            --
--------------------------------------------------------------------------------------------------------

-- Remove stale profession data at every inspection boundary.
function mod:OnClearInspect()
    self:Stop(true)
    self.data, self.liveSession, self.state = nil, nil, nil
    self.scroll.offset = 0
    self.scroll:SetVerticalScroll(0)
    self:Draw()
    self:HasData(nil)
end

-- Prepare a new profession snapshot without reading unconfirmed comparisons.
function mod:OnInspect()
    self:OnClearInspect()
    self:HasData(ex.unitType ~= 1)
end

-- Request profession data once the inspected player is confirmed by the server.
function mod:OnInspectReady()
    self:Start()
end

-- Cancel asynchronous work when Examiner is closed.
function mod:OnInspectHidden()
    self:Stop(true)
    if self.state == "waiting" or self.state == "queued" then
        self.state = nil
    end
end

-- Retry an unavailable request when the player explicitly opens the profession tab.
function mod:OnPageChanged(module, shown)
    if module == self and shown and not ex.isCacheEntry then
        if self.state == "unavailable" or self.state == "busy" then
            self.state = nil
        end
        self:Start()
        self:Draw()
    end
end

-- Save only complete profession skills when both cache switches permit it.
function mod:OnCache(entry)
    if
        self:CanCache()
        and self.data
        and self.data.complete
        and not self.data.cached
        and Valid(self.liveSession)
        and self.data.guid == self.liveSession.guid
    then
        entry.Professions = ns.Cache.Copy(self.data)
    end
end

-- Restore a skill snapshot without enabling stale recipe links.
function mod:OnCacheLoaded(entry)
    self:OnClearInspect()
    local data = C.IsTable(entry.Professions) and entry.Professions
    if data and C.IsTable(data.skills) then
        self.data = ns.Cache.Copy(data)
        self.data.cached = true
        self.state = "ready"
        self:Draw()
        self:HasData(true)
    end
end
