--------------------------------------------------------------------------------------------------------
--
-- Modules/equipment.lua
-- Displays an optional equipment list from the current inspection or cached snapshot.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local ex, C, L = ns.ex, ns.Compat, ns.L
local mod = ex:CreateModule("Equipment", L["Gear List"])
mod.defaultDisabled = true
mod.buttonLabel = L["List"]
mod.help = L["Shows equipped items, item levels and available enhancements."]
mod.toggleHelp = L["Enable/disable the Gear List module, which shows equipped items, item levels and available enhancements."]
mod.icon = "Interface\\Icons\\INV_Misc_Note_01"
mod:CreatePage(true)
mod:HasButton(true)
local ROW_HEIGHT = 14
local SIDE_PADDING, SCROLLBAR_SPACE = 8, 18
mod.equipmentRows = {}

--------------------------------------------------------------------------------------------------------
--                                          List Controls                                             --
--------------------------------------------------------------------------------------------------------

local list = CreateFrame("Frame", nil, mod.page, "BackdropTemplate")
list:SetAllPoints(mod.page)
list:SetFrameLevel(mod.page:GetFrameLevel() + 5)
list:EnableMouse(true)
list:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
list:SetBackdropColor(0, 0, 0, 0)
list:Hide()
mod.equipmentPane = list
local summary = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontNormalSmall")
summary:SetJustifyH("LEFT")
summary:SetWordWrap(false)
summary:SetMaxLines(1)
summary:SetTextColor(1, 1, 1)
local summaryTitle = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontNormalSmall")
summaryTitle:SetPoint("TOPLEFT", SIDE_PADDING, -8)
summaryTitle:SetText(L["Average Item Level"] .. ":")
summaryTitle:SetTextColor(1, 0.82, 0)
summaryTitle:SetJustifyH("LEFT")
summaryTitle:SetWordWrap(false)
summaryTitle:SetMaxLines(1)
local summaryMeasure = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontNormalSmall")
summaryMeasure:SetText(L["Average Item Level"] .. ":")
summaryMeasure:Hide()
summary:SetPoint("LEFT", summaryTitle, "RIGHT", 4, 0)
local score = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontNormalSmall")
score:SetPoint("TOPRIGHT", -SIDE_PADDING, -8)
score:SetJustifyH("RIGHT")
score:SetWordWrap(false)
local scoreTitle = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontNormalSmall")
scoreTitle:SetPoint("RIGHT", score, "LEFT", -4, 0)
scoreTitle:SetText("GearScore:")
scoreTitle:SetTextColor(1, 0.82, 0)
mod.equipmentSummary, mod.equipmentScore = summary, score
mod.equipmentSummaryTitle, mod.equipmentScoreTitle = summaryTitle, scoreTitle
local slotHeading = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontNormalSmall")
slotHeading:SetPoint("TOPLEFT", SIDE_PADDING + 58, -27)
slotHeading:SetText(L["Slot"])
local heading = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontNormalSmall")
heading:SetPoint("TOPLEFT", SIDE_PADDING + 144, -27)
heading:SetText(L["Item"])
local levelHeading = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontNormalSmall")
levelHeading:SetPoint("TOPLEFT", SIDE_PADDING, -27)
levelHeading:SetText(L["iLevel"])
mod.equipmentItemHeading, mod.equipmentLevelHeading = heading, levelHeading
local status = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", SIDE_PADDING, -51)
status:SetPoint("TOPRIGHT", -SIDE_PADDING, -51)
status:SetJustifyH("LEFT")
status:SetWordWrap(true)
mod.equipmentStatus = status
local scroll = CreateFrame("ScrollFrame", "ExaminerEquipmentScroll", list, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", SIDE_PADDING, -46)
scroll:SetPoint("BOTTOMRIGHT", -SIDE_PADDING, 8)
scroll:SetSize(mod.page:GetWidth() - 2 * SIDE_PADDING, mod.page:GetHeight() - 54)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(scroll:GetWidth(), 1)
scroll:SetScrollChild(content)
local bar = scroll.ScrollBar or _G[scroll:GetName() .. "ScrollBar"]
local up = bar.ScrollUpButton or _G[bar:GetName() .. "ScrollUpButton"]
local down = bar.ScrollDownButton or _G[bar:GetName() .. "ScrollDownButton"]
bar.scrollStep = ROW_HEIGHT
bar:ClearAllPoints()
bar:SetPoint("TOPRIGHT", list, "TOPRIGHT", -SIDE_PADDING, -62)
bar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -SIDE_PADDING, 24)
mod.equipmentScroll, mod.equipmentContent, mod.equipmentBar = scroll, content, bar

-- Spread equipped rows across the viewport while keeping sparse snapshots compact.
local function LayoutRows(count)
    local height = math.max(ROW_HEIGHT, math.min(22,
        math.floor(scroll:GetHeight() / math.max(1, count) * 100) / 100))
    mod.equipmentRowHeight = height
    bar.scrollStep = height
    for index, row in ipairs(mod.equipmentRows) do
        row:SetSize(content:GetWidth(), height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(index - 1) * height)
    end
    content:SetHeight(math.max(1, count * height))
end

-- Keep native scrollbar controls synchronized with a clamped list position.
local function ScrollTo(value)
    local maximum = math.max(0, content:GetHeight() - scroll:GetHeight())
    -- Reclaim the scrollbar gutter whenever the complete list fits vertically.
    local gutter = maximum > 0 and SCROLLBAR_SPACE or 0
    local width = mod.page:GetWidth() - 2 * SIDE_PADDING - gutter
    if mod.equipmentGutter ~= gutter or scroll:GetWidth() ~= width then
        mod.equipmentGutter = gutter
        scroll:SetPoint("BOTTOMRIGHT", -SIDE_PADDING - gutter, 8)
        scroll:SetWidth(width)
        content:SetWidth(width)
        for _, row in ipairs(mod.equipmentRows) do row:SetWidth(width) end
    end
    value = math.max(0, math.min(maximum, value or 0))
    mod.equipmentMaxScroll = maximum
    bar:SetMinMaxValues(0, maximum)
    if bar:GetValue() ~= value then bar:SetValue(value) end
    if scroll:GetVerticalScroll() ~= value then scroll:SetVerticalScroll(value) end
    bar:SetShown(maximum > 0)
    if up then up:SetEnabled(value > 0) end
    if down then down:SetEnabled(value < maximum) end
end

-- Move the equipment viewport when dragging the native thumb.
bar:SetScript("OnValueChanged", function(_, value) ScrollTo(value) end)
-- Update the scrollbar after late item data changes the content size.
scroll:SetScript("OnScrollRangeChanged", function() ScrollTo(scroll:GetVerticalScroll()) end)
scroll:EnableMouseWheel(true)
-- Scroll one item per wheel step.
scroll:SetScript("OnMouseWheel", function(_, delta)
    ScrollTo(scroll:GetVerticalScroll() - delta * (mod.equipmentRowHeight or ROW_HEIGHT))
end)

-- Create one reusable item row with its original item-link interactions.
local function CreateRow(index)
    local row = CreateFrame("Button", nil, content)
    row:SetSize(content:GetWidth(), ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(12, 12)
    row.icon:SetPoint("LEFT", 40, 0)
    row.slot = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontHighlightSmall")
    row.slot:SetPoint("LEFT", 58, 0)
    row.slot:SetWidth(80)
    row.slot:SetJustifyH("LEFT")
    row.slot:SetWordWrap(false)
    row.slot:SetMaxLines(1)
    row.name = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", 144, 0)
    row.name:SetPoint("RIGHT", -1, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetMaxLines(1)
    row.level = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontNormalSmall")
    row.level:SetPoint("LEFT", 0, 0)
    row.level:SetWidth(32)
    row.level:SetJustifyH("RIGHT")
    local separator = row:CreateTexture(nil, "BORDER")
    separator:SetColorTexture(0.5, 0.5, 0.5, 0.15)
    separator:SetHeight(1)
    separator:SetPoint("BOTTOMLEFT")
    separator:SetPoint("BOTTOMRIGHT")
    -- Show native item tooltips even while item metadata is still loading.
    row:SetScript("OnEnter", function(self)
        local palette = ns.Appearance.Palette()
        local color = palette and palette.accent or {1, 0.82, 0}
        self.hover:SetColorTexture(color[1], color[2], color[3], 0.16)
        self.hover:Show()
        if self.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end
    end)
    -- Remove the full-row highlight and release the native item tooltip.
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        ex.ItemButton_OnLeave(self)
    end)
    -- Preserve chat links, dressing-room shortcuts and right-click comparisons.
    row:SetScript("OnClick", function(self, button)
        if not self.link then return end
        if button == "RightButton" then
            if C.Text(C.Try(C.GetItemInfo, self.link)) then ex.ItemButton_OnClick(self, button) end
        elseif IsModifiedClick("DRESSUP") then
            DressUpItemLink(self.link)
        elseif IsModifiedClick("CHATLINK") then
            local edit = ChatEdit_GetActiveWindow()
            if edit and edit:IsVisible() then edit:Insert(self.link) end
        end
    end)
    mod.equipmentRows[index] = row
    return row
end

-- Build the list from current live or cached links without substituting the player's gear.
function mod:BuildEquipmentList()
    local count = 0
    self.equipmentPending = {}
    for _, slotName in ipairs(LibGearExam.Slots) do
        local link = C.Text(ex.info.Items and ex.info.Items[slotName])
        if link then
            count = count + 1
            local row = self.equipmentRows[count] or CreateRow(count)
            row.hover:Hide()
            if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
            row.slotName, row.id, row.link = slotName, LibGearExam.SlotIDs[slotName], link
            row.slot:SetText(_G[slotName:upper()] or slotName)
            local name, _, quality, baseLevel, _, _, _, _, _, texture = C.Try(C.GetItemInfo, link)
            name, quality = C.Text(name), C.Number(quality)
            row.name:SetText(name or L["Item data is still loading."])
            if not name then
                local itemID = tonumber(link:match("item:(%d+)"))
                if itemID then self.equipmentPending[itemID] = true end
            end
            local r, g, b = C.Try(C.GetItemQualityColor, quality or 0)
            row.name:SetTextColor(C.Number(r, 1), C.Number(g, 1), C.Number(b, 1))
            row.icon:SetTexture(C.Safe(texture) or "Interface\\Icons\\INV_Misc_QuestionMark")
            local level = C.Number(C.Try(C.GetDetailedItemLevelInfo, link), C.Number(baseLevel))
            if level and (level < 0 or level ~= level or level == math.huge) then level = nil end
            row.level:SetText(level and C.FormatNumber(level) or "-")
            row:Show()
        end
    end
    for index = count + 1, #self.equipmentRows do
        local row = self.equipmentRows[index]
        if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        row.link, row.slotName, row.id = nil, nil, nil
        row.hover:Hide()
        row:Hide()
    end
    self.equipmentCount = count
    local average = ex.averageItemLevel or "—"
    if ex.cfg.itemLevelSource == "blizzard" then
        local value = C.Number(ex.info.blizzardItemLevel)
        average = value and value >= 0 and value < math.huge and C.FormatNumber(value) or "—"
    end
    summary:SetText(tostring(average))
    score:SetText(C.IsNumber(ex.gs) and C.FormatNumber(ex.gs) or "—")
    local r, g, b = C.Try(ex.gsQualityColor and ex.gsQualityColor.GetRGB, ex.gsQualityColor)
    score:SetTextColor(C.Number(r, 1), C.Number(g, 0.82), C.Number(b, 0))
    local titleWidth = self.page:GetWidth() - 2 * SIDE_PADDING - scoreTitle:GetStringWidth()
        - score:GetStringWidth() - summary:GetStringWidth() - 16
    summaryTitle:SetWidth(math.max(1, math.min(titleWidth, summaryMeasure:GetStringWidth())))
    status:SetText(count == 0 and (ex.gear and ex.gear.state == "loading"
        and L["Item data is still loading."] or L["No equipment available."]) or "")
    LayoutRows(count)
    ScrollTo(scroll:GetVerticalScroll())
end

-- Listen for item metadata only while the list is visible.
list:SetScript("OnShow", function(self)
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    self:RegisterEvent("ITEM_DATA_LOAD_RESULT")
end)

-- Release item listeners and any tooltip owned by a hidden list row.
list:SetScript("OnHide", function(self)
    self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    self:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
    for _, row in ipairs(mod.equipmentRows) do
        row.hover:Hide()
        if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
    end
end)

-- Resolve only item metadata requested by the current list.
list:SetScript("OnEvent", function(self, event, itemID, success)
    if success ~= false and self:IsVisible() and mod:IsShown()
        and mod.equipmentPending and mod.equipmentPending[itemID] then
        mod:BuildEquipmentList()
    end
end)

--------------------------------------------------------------------------------------------------------
--                                         Module Events                                              --
--------------------------------------------------------------------------------------------------------

-- Apply the selected appearance to the independent equipment page.
function mod:RefreshEquipmentView()
    local palette = ns.Appearance.Palette()
    local forever = ex.cfg.style == "forever"
    list:SetBackdrop({bgFile = forever and "Interface\\FrameGeneral\\UI-Background-Rock" or "Interface\\Buttons\\WHITE8X8",
        tile = forever, tileSize = 128})
    -- The parent page already provides the translucent styled fill; avoid stacking two overlays.
    list:SetBackdropColor(0, 0, 0, 0)
    heading:SetTextColor(unpack(palette and palette.label or {1,0.82,0,1}))
    slotHeading:SetTextColor(unpack(palette and palette.label or {1,0.82,0,1}))
    levelHeading:SetTextColor(unpack(palette and palette.label or {1,0.82,0,1}))
end

-- Present available live gear without requesting another inspection.
function mod:OnInspectReady()
    self:HasData(ex.itemsLoaded)
    if ex.itemsLoaded then self:BuildEquipmentList() end
end
mod.OnInspect = mod.OnInspectReady
mod.OnGearUpdated = mod.OnInspectReady

-- Present the selected cached snapshot, including unresolved item metadata.
function mod:OnCacheLoaded()
    self:HasData(true)
    self:BuildEquipmentList()
end
mod.OnDataTimeout = mod.OnCacheLoaded

-- Discard row identities and tooltips when changing players or disabling the module.
function mod:OnClearInspect()
    self:HasData(nil)
    for _, row in ipairs(self.equipmentRows) do
        if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        row.link, row.slotName, row.id = nil, nil, nil
        row.hover:Hide()
        row:Hide()
    end
    self.equipmentCount = 0
    self.equipmentPending = {}
    summary:SetText("")
    score:SetText("")
    content:SetHeight(1)
    ScrollTo(0)
end

-- Update the optional list when its appearance preference changes.
function mod:OnConfigChanged(var)
    if var == "style" then self:RefreshEquipmentView() end
end

-- Resize the equipment viewport and clamp its scroll range after changing navigation.
function mod:OnLayoutChanged()
    scroll:SetSize(self.page:GetWidth() - 2 * SIDE_PADDING, self.page:GetHeight() - 54)
    content:SetWidth(scroll:GetWidth())
    LayoutRows(self.equipmentCount or 0)
    ScrollTo(scroll:GetVerticalScroll())
end

-- Refresh metadata and colors whenever the equipment page opens.
mod.page:HookScript("OnShow", function()
    mod:OnLayoutChanged()
    mod:RefreshEquipmentView()
    list:Show()
    mod:BuildEquipmentList()
end)
