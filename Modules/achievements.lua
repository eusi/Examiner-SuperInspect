--------------------------------------------------------------------------------------------------------
--
-- Modules/achievements.lua
-- Loads achievement comparisons and displays their results in the Achievements tab.
--
----------------------


--------------------------------------------------------------------------------------------------------
--                                            Module Setup                                            --
--------------------------------------------------------------------------------------------------------

local _, ns = ...
if ns.blocked or not (ns.Compat.isRetail or ns.Compat.isMists) then
    return
end
local ex, C, L = ns.ex, ns.Compat, ns.L
local mod = ex:CreateModule("Achievements", L.Achievements)
mod.buttonLabel = L["Achievements short"]
mod.help = L["Shows achievements, completion status, points, and rewards."]
mod.toggleHelp =
    L["Enable/disable the Achievements module, which shows achievements, completion status, points and rewards."]
mod.icon = "Interface\\Icons\\Achievement_General"
mod:CreatePage(false, L.Achievements)
mod:HasButton(true)
mod:HasData(nil)
local page = mod.page
local frame = CreateFrame("Frame")
frame:Hide()
mod.worker = frame
local ROWS, HEIGHT = 8, 27
local rows, list = {}, {}
mod.rows, mod.list = rows, list
local status = ns.Fonts.Create(page, nil, "ARTWORK", "GameFontHighlightSmall")
mod.status = status
status:SetPoint("TOPLEFT", 10, -34)
status:SetPoint("TOPRIGHT", -10, -34)
status:SetJustifyH("LEFT")

-- Accept a finite, nonnegative integer counter.
local function Count(value)
    if C.IsNumber(value) and value >= 0 and value < math.huge and value % 1 == 0 then
        return value
    end
end

-- Sort completed achievements by their completion date.
local function NewestFirst(a, b)
    if a.completed ~= b.completed then
        return a.completed
    end
    local first = a.year and (a.year * 10000 + a.month * 100 + a.day) or 0
    local second = b.year and (b.year * 10000 + b.month * 100 + b.day) or 0
    if first ~= second then
        return first > second
    end
    return a.id < b.id
end

-- Check whether the current player can provide comparison data.
local function Eligible()
    return mod:IsEnabled()
        and not ex.isCacheEntry
        and ex.unitType ~= 1
        and C.IsString(ex.unit)
        and C.IsTrue(C.Try(UnitIsPlayer, ex.unit))
        and not C.IsTrue(C.Try(UnitCanAttack, "player", ex.unit))
        and type(SetAchievementComparisonUnit) == "function"
        and type(GetAchievementComparisonInfo) == "function"
        and type(GetCategoryList) == "function"
        and type(GetCategoryNumAchievements) == "function"
        and type(GetAchievementInfo) == "function"
end

-- Verify ownership of the current achievement comparison.
local function Valid()
    local I = ns.Inspector
    return mod:IsEnabled()
        and mod.session
        and mod.session == I.active
        and I:Valid(mod.session)
        and not ex.isCacheEntry
        and mod.owner == mod.session.guid
        and mod:IsShown()
end

-- Format achievement completion status and date.
local function Completion(item)
    if not item.completed then
        return L["Not completed"]
    end
    local text = L.Completed
    if item.year and item.month and item.day then
        text = text .. " · " .. string.format("%04d-%02d-%02d", item.year, item.month, item.day)
    end
    return text
end

-- Show achievement details for the hovered entry.
local function Tooltip(row)
    local item = row.item
    if not item then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(item.name, 1, 0.82, 0)
    if item.category then
        GameTooltip:AddLine(item.category, 0.5, 0.75, 1, true)
    end
    GameTooltip:AddLine(item.description, 1, 1, 1, true)
    GameTooltip:AddLine(
        Completion(item),
        item.completed and 0.4 or 0.7,
        item.completed and 1 or 0.7,
        item.completed and 0.4 or 0.7,
        true
    )
    if item.points then
        GameTooltip:AddLine(L.Points .. ": " .. C.FormatNumber(item.points), 1, 0.82, 0)
    end
    if item.reward and item.reward ~= "" then
        GameTooltip:AddLine(item.reward, 1, 0.82, 0, true)
    end
    if item.accountWide then
        GameTooltip:AddLine(L["Account-wide achievement"], 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end


--------------------------------------------------------------------------------------------------------
--                                        Achievement Display                                         --
--------------------------------------------------------------------------------------------------------

-- Render the available achievement snapshot.
function mod:Draw()
    FauxScrollFrame_Update(self.scroll, #list, ROWS, HEIGHT)
    for index, row in ipairs(rows) do
        local item = list[(self.scroll.offset or 0) + index]
        if row.item ~= item and GameTooltip:IsOwned(row) then
            GameTooltip:Hide()
        end
        row.item = item
        if item then
            row.icon:SetTexture(item.icon)
            row.name:SetText(item.name)
            row.name:SetTextColor(
                item.completed and 1 or 0.65,
                item.completed and 0.82 or 0.65,
                item.completed and 0 or 0.65
            )
            row.detail:SetText(Completion(item))
            row.points:SetText(item.points and C.FormatNumber(item.points) or "")
            row:Show()
        else
            row:Hide()
        end
    end
end

-- Stop achievement comparison requests and release owned data.
function mod:Stop(release)
    frame:Hide()
    frame:UnregisterEvent("INSPECT_ACHIEVEMENT_READY")
    local owner = self.owner
    self.owner = nil
    self.session = nil
    self.categories, self.categoryIndex, self.itemIndex, self.chain, self.seen = nil, nil, nil, nil, nil
    if self.state == "waiting" or self.state == "building" then
        self.state = #list > 0 and "partial" or nil
        status:SetText("")
    end
    if release and owner then
        self.sending = true
        C.Try(ClearAchievementComparisonUnit)
        self.sending = false
    end
end

-- Clear achievement rows and pending comparison state.
function mod:Reset()
    self:Stop(true)
    self.state = nil
    self.points = nil
    wipe(list)
    self.scroll.offset = 0
    self.scroll:SetVerticalScroll(0)
    status:SetText("")
    self:Draw()
end


--------------------------------------------------------------------------------------------------------
--                                        Comparison Lifecycle                                        --
--------------------------------------------------------------------------------------------------------

local guardedComparison

-- Ignore foreign comparison replies in Mists' hidden Blizzard panel.
local function GuardHiddenComparison()
    if not C.isMists then
        return true
    end
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
    -- Its native handler passes the normal view's "summary" string to a numeric API.
    comparison:SetScript("OnEvent", function(self, event, ...)
        if event == "INSPECT_ACHIEVEMENT_READY" and not self:IsShown() then
            return
        end
        return handler(self, event, ...)
    end)
    guardedComparison = comparison
    return true
end

if C.isMists and not GuardHiddenComparison() then
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("ADDON_LOADED")
    -- Guard the native panel after Blizzard's load-on-demand addon creates it.
    listener:SetScript("OnEvent", function(self)
        if GuardHiddenComparison() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

-- Start achievement loading for the current inspected player.
function mod:Start()
    if self.state == "ready" or self.state == "waiting" or self.state == "building" or not Eligible() then
        return
    end
    local I = ns.Inspector
    local session = I.active
    if not session or session.cached or not session.serverReady or not I:Valid(session) then
        return
    end
    if not C.IsTrue(C.Try(CheckInteractDistance, ex.unit, 1)) and not ex.isSelf then
        return
    end
    GuardHiddenComparison()
    if AchievementFrameComparison and AchievementFrameComparison:IsShown() then
        status:SetText(L["Close the other achievement comparison first."])
        return
    end
    self:Reset()
    self.session = session
    self.owner = session.guid
    self.state = "waiting"
    self.started = GetTime()
    status:SetText(L["Loading…"])
    frame:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
    frame:Show()
    self.sending = true
    local ok = pcall(SetAchievementComparisonUnit, session.unit)
    self.sending = false
    if not ok then
        self:Stop(true)
    end
end

-- Comparison state is shared with Blizzard's achievement window and other addons.
if type(SetAchievementComparisonUnit) == "function" then
    -- Invalidate comparison ownership when another caller changes it.
    hooksecurefunc("SetAchievementComparisonUnit", function()
        if not mod.sending then
            mod:Stop(false)
        end
    end)
end
if type(ClearAchievementComparisonUnit) == "function" then
    -- Invalidate comparison ownership when another caller changes it.
    hooksecurefunc("ClearAchievementComparisonUnit", function()
        if not mod.sending then
            mod:Stop(false)
        end
    end)
end


--------------------------------------------------------------------------------------------------------
--                                          Achievement Data                                          --
--------------------------------------------------------------------------------------------------------

-- Read client achievement data for the current inspected player.
function mod:Read(category, index)
    local id, name, points, _, _, _, _, description, flags, icon, reward, isGuild =
        C.Try(GetAchievementInfo, category, index)
    if not Count(id) or self.seen[id] then
        return
    end
    self.seen[id] = true
    if C.IsTrue(isGuild) or not C.IsString(name) then
        return
    end
    local completed, month, day, year = C.Try(GetAchievementComparisonInfo, id)
    if not C.IsSecret(completed) and type(completed) == "boolean" then
        local accountFlag = Count(ACHIEVEMENT_FLAGS_ACCOUNT)
        local accountWide = accountFlag
            and accountFlag > 0
            and Count(flags)
            and math.floor(flags / accountFlag) % 2 == 1
        local item = {
            id = id,
            name = name,
            points = Count(points),
            description = C.Text(description, ""),
            icon = C.Icon(icon),
            reward = C.Text(reward),
            completed = completed,
            category = self.categories[self.categoryIndex].name,
            accountWide = accountWide,
        }
        month, day, year = Count(month), Count(day), Count(year)
        if completed and month and month >= 1 and month <= 12 and day and day >= 1 and day <= 31 and year then
            item.month, item.day, item.year = month, day, year < 100 and year + 2000 or year
        end
        list[#list + 1] = item
    end
    local previous = C.Try(GetPreviousAchievement, id)
    if Count(previous) and previous > 0 and not self.seen[previous] then
        self.chain[#self.chain + 1] = previous
    end
    local following = C.Try(GetNextAchievement, id)
    if Count(following) and following > 0 and not self.seen[following] then
        self.chain[#self.chain + 1] = following
    end
end

-- Advance pending achievement work without blocking the UI.
function mod:Step()
    if not Valid() then
        self:Stop(true)
        return
    end
    if self.state == "waiting" and GetTime() - self.started >= 12 then
        self:Stop(true)
        return
    end
    if self.state ~= "building" then
        return
    end
    for _ = 1, 40 do
        local category = self.categories[self.categoryIndex]
        if not category then
            table.sort(list, NewestFirst)
            self.state = "ready"
            self:Stop(true)
            status:SetText(
                (self.points and (L.Points .. ": " .. C.FormatNumber(self.points) .. " · ") or "")
                    .. ns.F("%d achievements", #list)
            )
            self:Draw()
            return
        elseif #self.chain > 0 then
            self:Read(table.remove(self.chain))
        elseif self.itemIndex <= category.count then
            local index = self.itemIndex
            self.itemIndex = index + 1
            self:Read(category.id, index)
        else
            self.categoryIndex = self.categoryIndex + 1
            self.itemIndex = 1
        end
    end
    self:Draw()
end

-- Dispatch the relevant client event to its inspection handler.
frame:SetScript("OnEvent", function(_, _, guid)
    if mod.state ~= "waiting" or not C.IsString(guid) or not Valid() or guid ~= mod.owner then
        return
    end
    local categories = C.Try(GetCategoryList)
    if not C.IsTable(categories) then
        mod:Stop(true)
        return
    end
    mod.categories = {}
    for _, id in ipairs(categories) do
        if Count(id) then
            local name = C.Try(GetCategoryInfo, id)
            local count = Count(C.Try(GetCategoryNumAchievements, id))
            if count and count > 0 then
                mod.categories[#mod.categories + 1] = { id = id, name = C.Text(name), count = count }
            end
        end
    end
    mod.points = Count(C.Try(GetComparisonAchievementPoints))
    mod.categoryIndex, mod.itemIndex, mod.chain, mod.seen = 1, 1, {}, {}
    mod.state = "building"
    mod.started = GetTime()
end)

-- Refresh pending data or finish the current interaction.
frame:SetScript("OnUpdate", function()
    mod:Step()
end)


--------------------------------------------------------------------------------------------------------
--                                           Module Events                                            --
--------------------------------------------------------------------------------------------------------

-- Prepare achievement data for a new inspected player.
function mod:OnInspect()
    self:Reset()
    self:HasData(Eligible())
end

-- Initialize achievement controls and saved preferences.
function mod:OnInitialize()
    local label = self.button:GetFontString()
    local width = label:GetStringWidth()
    local available = self.button:GetWidth() - 8
    if width > available then
        local font, size, flags = label:GetFont()
        label:SetFont(font, math.max(8, size * available / width), flags)
    end
end

-- Read achievement data after the inspection reply.
function mod:OnInspectReady()
    self:HasData(Eligible())
    if page:IsShown() then
        self:Start()
    end
end

-- Clear achievement data and hide stale controls.
function mod:OnClearInspect()
    self:Reset()
    self:HasData(nil)
end

-- Restore achievement details from the saved player snapshot.
function mod:OnCacheLoaded()
    self:OnClearInspect()
end

-- Stop pending achievement work when inspection closes.
function mod:OnInspectHidden()
    self:Stop(true)
end

-- Update achievement controls when the active page changes.
function mod:OnPageChanged(module, shown)
    if module == self and shown and self:IsShown() then
        self:Start()
    elseif (module == self and not shown) or (module ~= self and shown) then
        self:Stop(true)
    end
end


--------------------------------------------------------------------------------------------------------
--                                          Widget Creation                                           --
--------------------------------------------------------------------------------------------------------

for index = 1, ROWS do
    local row = CreateFrame("Button", nil, page)
    rows[index] = row
    row:SetHeight(HEIGHT)
    row:SetPoint("TOPLEFT", 9, -53 - (index - 1) * HEIGHT)
    row:SetPoint("TOPRIGHT", -28, -53 - (index - 1) * HEIGHT)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:SetScript("OnEnter", Tooltip)
    row:SetScript("OnLeave", ex.HideGTT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.name = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
    row.name:SetPoint("RIGHT", -25, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.detail = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontHighlightSmall")
    row.detail:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 4, 0)
    row.detail:SetTextColor(0.65, 0.65, 0.65)
    row.points = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontNormalSmall")
    row.points:SetPoint("RIGHT")
    row:Hide()
end
mod.scroll = CreateFrame("ScrollFrame", "ExaminerAchievementsScroll", page, "FauxScrollFrameTemplate")
mod.scroll:SetPoint("TOPLEFT", rows[1])
mod.scroll:SetPoint("BOTTOMRIGHT", rows[ROWS], -6, -1)
-- Update visible rows for the new scroll position.
mod.scroll:SetScript("OnVerticalScroll", function(self, offset)
    -- Redraw the visible rows after scrolling.
    FauxScrollFrame_OnVerticalScroll(self, offset, HEIGHT, function()
        mod:Draw()
    end)
end)
