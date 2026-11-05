--------------------------------------------------------------------------------------------------------
--
-- Modules/talents.lua
-- Displays and caches legacy talent trees on Era, SoD and TBC clients.
--
----------------------


--------------------------------------------------------------------------------------------------------
--                                            Module Setup                                            --
--------------------------------------------------------------------------------------------------------

local _, ExaminerNS = ...
if ExaminerNS.blocked then
    return
end
local ex = Examiner
local C = ExaminerNS.Compat
if ExaminerNS.Compat.talentKind ~= "classic" then
    return
end

-- MODULE

local mod = ex:CreateModule("Talents", TALENTS)
mod.help = ExaminerNS.L["Shows talent trees."]
    .. "\n" .. ExaminerNS.L["Right-click: choose which talents/specialization to view."]
mod.toggleHelp = ExaminerNS.L["Enable/disable the Talents module, which shows talent trees."]
mod.cacheHelp = ExaminerNS.L["Saves talent builds for later viewing. Requires Core Caching."]
mod.page = CreateFrame("Frame", nil, ex)
mod:HasButton(true)
mod.canCache = true
mod.details = ex:CreateDetailObject()

-- VARIABLES

local cfg, cache
local activeTab = 1
local activeSpec
local isInspect
local arrowIndex, branchIndex
local points = {}
local BRANCH_ARRAY = {}
local cached
-- Read the number of available talent groups.
local function GroupCount()
    local count = C.Number(C.Try(GetNumTalentGroups, isInspect))
    return (count == 1 or count == 2) and count or C.ActiveTalentGroup(isInspect)
end

-- Choose the talent group currently being displayed.
local function SelectedGroup()
    if cached then
        return cached.group
    end
    local selected = cfg.shownSpec
    if (selected == 1 or selected == 2) and selected <= GroupCount() then
        return selected
    end
    return C.ActiveTalentGroup(isInspect)
end

-- Read the available legacy talent trees.
local function TabCount()
    return cached and #cached.trees or math.min(3, C.Number(C.Try(GetNumTalentTabs, isInspect, false), 0))
end

-- Read one legacy talent tree through compatibility helpers.
local function ReadTab(index)
    if cached then
        local tree = cached.trees[index]
        if tree then
            return tree.name, tree.icon, tree.points, tree.background
        end
        return
    end
    return C.LegacyTalentTab(index, isInspect, activeSpec)
end

-- Read the number of talents in a legacy tree.
local function TalentCount(tab)
    if cached then
        return cached.trees[tab] and #cached.trees[tab].nodes or 0
    end
    return math.min(40, C.Number(C.Try(GetNumTalents, tab, isInspect, false), 0))
end

-- Read a legacy talent and its inspected rank.
local function ReadTalent(tab, index)
    if cached then
        local node = cached.trees[tab] and cached.trees[tab].nodes[index]
        if node then
            return unpack(node.values, 1, 12)
        end
        return
    end
    return C.LegacyTalentInfo(tab, index, isInspect, activeSpec)
end

-- Read prerequisite positions for a legacy talent.
local function ReadPrereqs(tab, index)
    if cached then
        return unpack(cached.trees[tab].nodes[index].prereqs)
    end
    local values = { C.Try(GetTalentPrereqs, tab, index, isInspect, false, activeSpec) }
    if C.IsNumber(values[1]) and C.IsNumber(values[2]) then
        return unpack(values)
    end
end

-- INIT TALENT BRANCHES

for tier = 1, MAX_NUM_TALENT_TIERS do
    BRANCH_ARRAY[tier] = {}
    for column = 1, NUM_TALENT_COLUMNS do
        BRANCH_ARRAY[tier][column] = {}
    end
end


--------------------------------------------------------------------------------------------------------
--                                           Module Events                                            --
--------------------------------------------------------------------------------------------------------

-- Initialize legacy talent controls and saved preferences.
function mod:OnInitialize()
    cfg = ex.cfg
    cache = ex.cache
end

-- Prepare legacy talent data for a new inspected player.
function mod:OnInspect(unit)
    cached = nil
    if ex.isSelf then
        isInspect = nil
        self:HasData(true)
        self:InitTalents()
    end
end

-- Read legacy talent data after the inspection reply.
function mod:OnInspectReady(unit)
    cached = nil
    isInspect = not ex.isSelf
    self:HasData(true)
    self:InitTalents()
end

-- Restore legacy talent details from the saved player snapshot.
function mod:OnCacheLoaded(entry, unit)
    cached = ExaminerNS.Cache.Copy(entry.ClassicTalents)
    if C.IsTable(cached) and C.IsTable(cached.trees) and #cached.trees > 0 then
        isInspect = true
        activeSpec = cached.group
        self:HasData(true)
        self:InitTalents()
        return
    end
    cached = nil
    self:HasData(nil)
    if (entry.talentPoints or entry.talents) and entry.talentSpec then
        self.details:Clear()
        self.details:Add(ExaminerNS.L["Talents"])
        self.details:Add(ExaminerNS.L["Specialization"], entry.talentSpec or UNKNOWN)
        self.details:Add(ExaminerNS.L["Points"], entry.talentPoints or entry.talents)
        self.details:Update()
    end
end

-- Save available legacy talent details into the player snapshot.
function mod:OnCache(entry, unit)
    if (self:CanCache()) and self.hasData then
        entry.talentSpec = self.talentSpec
        entry.talentPoints = self.talentPoints
        entry.level = ex.info.level
        if not ex.isCacheEntry then
            local snapshot = { group = activeSpec or C.ActiveTalentGroup(isInspect), trees = {} }
            local complete = TabCount() > 0
            for tab = 1, TabCount() do
                local name, icon, spent, background = ReadTab(tab)
                local tree = { name = name, icon = icon, points = spent, background = background, nodes = {} }
                if not name or name == "?" then
                    complete = false
                end
                if spent and spent > 0 and TalentCount(tab) == 0 then
                    complete = false
                end
                for index = 1, TalentCount(tab) do
                    local values = { ReadTalent(tab, index) }
                    if not values[1] then
                        complete = false
                    end
                    tree.nodes[index] = {
                        values = values,
                        prereqs = { ReadPrereqs(tab, index) },
                        link = C.Text(C.Try(GetTalentLink, tab, index, isInspect, false, snapshot.group)),
                    }
                end
                snapshot.trees[tab] = tree
            end
            if complete then
                entry.ClassicTalents = ExaminerNS.Cache.Copy(snapshot)
            end
        end
    end
end

-- Clear legacy talent data and hide stale controls.
function mod:OnClearInspect()
    cached = nil
    self:HasData(nil)
    self.talentSpec, self.talentPoints = nil, nil
    self.details:Clear()
end


--------------------------------------------------------------------------------------------------------
--                                         Talent Group Menu                                          --
--------------------------------------------------------------------------------------------------------

-- Build the legacy talent context menu.
function mod.MenuInit(parent, list)
    local group = cached and cached.group or C.ActiveTalentGroup(isInspect)
    if cached then
        list[1].text = ExaminerNS.L["Shown Spec"]
        list[1].header = 1
        list[2].text = "|cff80ff80" .. ExaminerNS.L["Active"] .. "|r"
        list[2].checked = true
        return
    end
    local groups = GroupCount()
    list[1].text = ExaminerNS.L["Shown Spec"]
    list[1].header = 1
    local selected = (cfg.shownSpec == 1 or cfg.shownSpec == 2) and cfg.shownSpec <= groups and cfg.shownSpec
        or nil
    list[2].text = "|cff80ff80" .. ExaminerNS.L["Active"] .. "|r"
    list[2].value = nil
    list[2].checked = (selected == nil)
    list[3].text = group == 1 and ExaminerNS.F("%s (active)", ExaminerNS.L["Primary"])
        or ExaminerNS.L["Primary"]
    list[3].value = 1
    list[3].checked = (selected == 1)
    if groups > 1 then
        list[4].text = group == 2 and ExaminerNS.F("%s (active)", ExaminerNS.L["Secondary"])
            or ExaminerNS.L["Secondary"]
        list[4].value = 2
        list[4].checked = (selected == 2)
    end
end

-- Apply the selected legacy talent menu action.
function mod.MenuSelect(parent, entry)
    local inspector = ExaminerNS.Inspector
    local session = inspector.active
    if
        cached
        or ex.isCacheEntry
        or not session
        or session.cached
        or not session.serverReady
        or not inspector:Valid(session)
        or (not ex.isSelf and inspector.notificationGUID ~= session.guid)
    then
        return
    end
    if entry.value ~= nil and ((entry.value ~= 1 and entry.value ~= 2) or entry.value > GroupCount()) then
        return
    end
    cfg.shownSpec = entry.value
    mod:InitTalents()
    if not ex.isCacheEntry then
        ex:CachePlayer()
    end
end


--------------------------------------------------------------------------------------------------------
--                                          Control Handlers                                          --
--------------------------------------------------------------------------------------------------------

-- Switch the displayed legacy talent tree.
local function TalentsTab_OnClick(self, button)
    activeTab = self.id
    PanelTemplates_SetTab(ex, activeTab)
    mod:UpdateTalents()
end

-- Handle supported talent-link shortcuts.
local function TalentButton_OnClick(self, button)
    local editBox = ChatEdit_GetActiveWindow()
    if (IsModifiedClick("CHATLINK")) and editBox and (editBox:IsVisible()) then
        local node = cached and cached.trees[activeTab] and cached.trees[activeTab].nodes[self.id]
        local link = node and node.link
            or (not cached and C.Try(GetTalentLink, activeTab, self.id, isInspect, false, activeSpec))
        if C.IsString(link) then
            editBox:Insert(link)
        end
    end
end

-- Show the inspected talent rank and spell tooltip.
local function TalentButton_OnEnter(self, motion)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if activeTab == nil then
        return
    end
    local node = cached and cached.trees[activeTab] and cached.trees[activeTab].nodes[self.id]
    if cached then
        if node and node.link then
            GameTooltip:SetHyperlink(node.link)
        elseif self.talentName then
            GameTooltip:SetText(self.talentName)
        end
    elseif
        self.talentID
        and C_SpecializationInfo
        and type(C_SpecializationInfo.GetTalentInfo) == "function"
    then
        GameTooltip:SetTalent(self.talentID, isInspect or false, false, activeSpec)
    else
        GameTooltip:SetTalent(activeTab, self.id, isInspect, false, activeSpec)
    end
    GameTooltip:Show()
end

-- Create a legacy talent button with a rank overlay.
local function CreateTalentButton(parent, index)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(37)
    btn:SetHeight(37)
    btn:SetScript("OnClick", TalentButton_OnClick)
    btn:SetScript("OnEnter", TalentButton_OnEnter)
    btn:SetScript("OnLeave", ex.HideGTT)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btn.id = index

    btn.icon = btn:CreateTexture(nil, "BORDER")
    btn.icon:SetPoint("TOPLEFT", 1, -1)
    btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)

    btn.slot = btn:CreateTexture(nil, "BACKGROUND")
    btn.slot:SetTexture("Interface\\Buttons\\UI-EmptySlot-White")
    btn.slot:SetWidth(64)
    btn.slot:SetHeight(64)
    btn.slot:SetPoint("CENTER")

    btn.rankBorder = btn:CreateTexture(nil, "OVERLAY")
    btn.rankBorder:SetTexture("Interface\\TalentFrame\\TalentFrame-RankBorder")
    btn.rankBorder:SetWidth(32)
    btn.rankBorder:SetHeight(32)
    btn.rankBorder:SetPoint("CENTER", btn, "BOTTOMRIGHT")

    btn.goldBorder = btn:CreateTexture(nil, "ARTWORK")
    btn.goldBorder:SetTexture("Interface\\TalentFrame\\TalentFrame-Parts")
    btn.goldBorder:SetTexCoord(0.40625000, 0.57812500, 0.68359375, 0.76953125)
    btn.goldBorder:SetWidth(56)
    btn.goldBorder:SetHeight(56)
    btn.goldBorder:SetPoint("CENTER")

    btn.rank = ExaminerNS.Fonts.Create(btn, nil, "OVERLAY", "GameFontNormalSmall")
    btn.rank:SetPoint("CENTER", btn.rankBorder, 0, 1)

    return btn
end


--------------------------------------------------------------------------------------------------------
--                                          Widget Creation                                           --
--------------------------------------------------------------------------------------------------------

-- Show the talent tree in place of the character model.
local function OnShow(self)
    mod:UpdateTalents()
    ex.model:Hide()
    ex.details:Hide()
    ex.guild:Hide()
    ex:ShowBackground(true)
end

-- Restore the model and player labels after leaving the talent tree.
local function OnHide(self)
    ex.model:Show()
    ex.details:Show()
    ex.guild:Show()
    ex:ShowBackground()
    ex:SetBackgroundTexture()
end

-- TALENT PAGE

mod.page:SetWidth(320)
mod.page:SetHeight(354)
mod.page:SetPoint("BOTTOM", -11, 10)
mod.page:Hide()
mod.page:SetScript("OnShow", OnShow)
mod.page:SetScript("OnHide", OnHide)

-- SCROLL

local sc = CreateFrame("ScrollFrame", "ExaminerTalentsScrollChild", mod.page, "UIPanelScrollFrameTemplate")
sc:SetPoint("TOPLEFT", ex.model, 0, -2)
sc:SetPoint("BOTTOMRIGHT", ex.model, -25, 25)

-- SCROLL CHILD FRAME

local scf = CreateFrame("Frame", "ExaminerScrollChildFrame")
scf:SetWidth(320)
scf:SetHeight(1)
sc:SetScrollChild(scf)

-- TALENT TABS

for i = 1, 3 do
    local tab = CreateFrame("Button", "ExaminerTab" .. i, mod.page, "TabButtonTemplate")
    tab.id = i
    tab:SetScript("OnClick", TalentsTab_OnClick)
    if i == 1 then
        tab:SetPoint("TOPLEFT", 45, 36)
    else
        tab:SetPoint("LEFT", "ExaminerTab" .. (i - 1), "RIGHT")
    end
end

ex.selectedTab = 1
PanelTemplates_SetNumTabs(ex, 3)
PanelTemplates_UpdateTabs(ex)

-- Create buttons before the arrow overlay to preserve their frame ordering.
local talentBtns = {}
mod.talentButtons = talentBtns
for i = 1, 40 do
    talentBtns[i] = CreateTalentButton(scf, i)
end

-- Draw arrows above talent buttons.
local af = CreateFrame("Frame", nil, scf)
af:SetAllPoints()

-- TALENT WIDGETS

local branches = setmetatable({}, {
    -- Create and retain a missing talent connector texture.
    __index = function(t, k)
        t[k] = scf:CreateTexture(nil, "BACKGROUND", "TalentBranchTemplate")
        return t[k]
    end,
})
local arrows = setmetatable({}, {
    -- Create and retain a missing talent connector texture.
    __index = function(t, k)
        t[k] = af:CreateTexture(nil, "OVERLAY", "TalentArrowTemplate")
        return t[k]
    end,
})


--------------------------------------------------------------------------------------------------------
--                                     Tree Connections And Data                                      --
--------------------------------------------------------------------------------------------------------

-- Place a talent dependency branch segment.
local function SetBranchTexture(coords, x, y)
    local branch = branches[branchIndex]
    branch:SetTexCoord(unpack(coords))
    branch:SetPoint("TOPLEFT", x, y)
    branch:Show()
    branchIndex = (branchIndex + 1)
end

-- Place an arrow between dependent talents.
local function SetArrowTexture(coords, x, y)
    local arrow = arrows[arrowIndex]
    arrow:SetTexCoord(unpack(coords))
    arrow:SetPoint("TOPLEFT", x, y)
    arrow:Show()
    arrowIndex = (arrowIndex + 1)
end

-- Build connecting lines for legacy talent prerequisites.
local function CalculateBranchLines(tier, column, rank, ...)
    local type = (rank > 0 and 1 or -1)
    for i = 1, select("#", ...), 4 do
        local preTier, preColumn = select(i, ...)
        local left = min(preColumn, column)
        local right = max(preColumn, column)
        -- SAME COLUMN

        if preColumn == column then
            for i = preTier, tier - 1 do
                BRANCH_ARRAY[i][column].down = type
                if i + 1 <= tier - 1 then
                    BRANCH_ARRAY[i + 1][column].up = type
                end
            end
            BRANCH_ARRAY[tier][column].topArrow = type
        -- SAME TIER

        elseif preTier == tier then
            for i = left, right - 1 do
                BRANCH_ARRAY[tier][i].right = type
                BRANCH_ARRAY[tier][i + 1].left = type
            end
            BRANCH_ARRAY[tier][column][preColumn < column and "leftArrow" or "rightArrow"] = type
        -- DIAGONAL

        else
            local blocked
            for i = preTier, tier - 1 do
                if BRANCH_ARRAY[i][column].id then
                    blocked = true
                    ExaminerNS.Record("talent-layout", "blocked path " .. tier .. " x " .. i)
                    break
                end
            end
            -- Route around the intervening talent.
            if blocked then
                for i = preTier, tier - 1 do
                    BRANCH_ARRAY[i][column].up = type
                    BRANCH_ARRAY[i + 1][column].down = type
                end
                BRANCH_ARRAY[tier][column][preColumn < column and "leftArrow" or "rightArrow"] = type
            -- LEFT/RIGHT CONNECTION

            else
                for i = preTier, tier - 1 do
                    BRANCH_ARRAY[i][column].down = type
                    BRANCH_ARRAY[i + 1][column].up = type
                end
                for i = left, right - 1 do
                    BRANCH_ARRAY[preTier][i].right = type
                    BRANCH_ARRAY[preTier][i + 1].left = type
                end
                BRANCH_ARRAY[tier][column].topArrow = type
            end
        end
    end
end

-- Populate legacy talent buttons and dependency lines.
function mod:InitTalents()
    activeSpec = SelectedGroup()
    self.details:Clear()
    wipe(points)
    self.talentSpec, self.talentPoints = nil, nil
    -- GATHER TALENT INFO

    local maxTree = 1
    local combined = 0
    local complete = TabCount() == 3
    for i = 1, TabCount() do
        local name, _, pointsSpent = ReadTab(i)
        if
            not name
            or name == ""
            or name == "?"
            or not C.IsNumber(pointsSpent)
            or not (pointsSpent >= 0 and pointsSpent < math.huge and pointsSpent % 1 == 0)
        then
            complete = false
        else
            points[i] = pointsSpent
            combined = (combined + pointsSpent)
            if pointsSpent > (points[maxTree] or -1) then
                maxTree = i
            end
        end
    end
    self:HasData(complete)
    if self:IsShown() then
        self:UpdateTalents()
    end
    if not complete then
        self.details:Update()
        return
    end
    local talentPoints = (points[1] or 0) .. "/" .. (points[2] or 0) .. "/" .. (points[3] or 0)
    -- DETAILS

    local talentSpec = ReadTab(maxTree)
    self.details:Add(ExaminerNS.L["Talents"])
    self.details:Add(
        ExaminerNS.L["Specialization"],
        combined > 0 and talentSpec or ExaminerNS.L["No Talents"]
    )
    self.details:Add(ExaminerNS.L["Points"], talentPoints)
    self.details:Update()
    -- CACHE SNAPSHOT

    self.talentSpec = talentSpec
    self.talentPoints = talentPoints
end

-- Refresh talent ranks for the selected inspected group.
function mod:UpdateTalents()
    activeSpec = SelectedGroup()
    activeTab = math.min(activeTab, math.max(1, TabCount()))
    for _, button in ipairs(talentBtns) do
        button:Hide()
    end
    -- These pools allocate on indexed access; ipairs would keep creating entries.
    for i = 1, #branches do
        branches[i]:Hide()
    end
    for i = 1, #arrows do
        arrows[i]:Hide()
    end
    if not self.hasData then
        for i = 1, 3 do
            _G["ExaminerTab" .. i]:Hide()
        end
        sc:Hide()
        return
    end

    sc:Show()
    for i = 1, 3 do
        _G["ExaminerTab" .. i]:SetShown(i <= TabCount())
    end
    -- UPDATE TABS

    for i = 1, TabCount() do
        local tab = _G["ExaminerTab" .. i]
        local tabName, icon, pointsSpent, background = ReadTab(i)
        if background and i == activeTab then
            ex:SetBackgroundTexture("Interface\\TalentFrame\\" .. background .. "-")
        end
        if pointsSpent == nil then
            pointsSpent = 0
        end
        if tabName == nil then
            tabName = ""
        end
        tab:SetFormattedText("%s |cff00ff00%d", tabName, pointsSpent)
        PanelTemplates_TabResize(tab, -18)
    end
    -- RESET PREREQ

    arrowIndex = 1
    branchIndex = 1
    for tier = 1, MAX_NUM_TALENT_TIERS do
        for column = 1, NUM_TALENT_COLUMNS do
            wipe(BRANCH_ARRAY[tier][column])
        end
    end
    -- TALENTS

    if activeTab == nil then
        return
    end
    local numTalents = TalentCount(activeTab)
    if not numTalents or numTalents <= 0 then
        return
    end

    for i = 1, numTalents do
        local name, iconTexture, tier, column, rank, maxRank, meetsPrereq, previewRank, meetsPreviewPrereq, isExceptional, goldBorder, talentID =
            ReadTalent(activeTab, i)
        local btn = talentBtns[i]
        btn.talentID, btn.talentName = talentID, name
        if
            not name
            or not BRANCH_ARRAY[tier]
            or not BRANCH_ARRAY[tier][column]
            or not C.IsNumber(rank)
            or not C.IsNumber(maxRank)
        then
            btn:Hide()
        else
            BRANCH_ARRAY[tier][column].id = i
            CalculateBranchLines(tier, column, rank, ReadPrereqs(activeTab, i))

            btn:Show()
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", (column - 1) * 63 + 35, (tier - 1) * -63 - 20)
            btn.icon:SetTexture(iconTexture)
            btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

            if isExceptional then
                btn.goldBorder:Show()
            else
                btn.goldBorder:Hide()
            end

            if rank == 0 then
                btn.icon:SetDesaturated(true)
                btn.goldBorder:SetDesaturated(true)
                btn.rankBorder:Hide()
                btn.rank:Hide()
                btn.slot:SetVertexColor(0.5, 0.5, 0.5)
            else
                btn.icon:SetDesaturated(false)
                btn.goldBorder:SetDesaturated(false)
                btn.rankBorder:Show()
                btn.rank:Show()
                btn.rank:SetText(rank)
                if rank < maxRank then
                    btn.slot:SetVertexColor(0.1, 1, 0.1)
                    btn.rank:SetTextColor(0, 1, 0)
                else
                    btn.slot:SetVertexColor(1, 0.82, 0)
                    btn.rank:SetTextColor(1, 0.82, 0)
                end
            end
        end
    end

    for i = numTalents + 1, #talentBtns do
        talentBtns[i]:Hide()
    end
    for i = branchIndex, #branches do
        branches[i]:Hide()
    end
    for i = arrowIndex, #arrows do
        arrows[i]:Hide()
    end
end
