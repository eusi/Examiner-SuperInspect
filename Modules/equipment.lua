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
mod:CreatePage(false)
mod:HasButton(true)
local ROW_HEIGHT = 48
mod.equipmentRows = {}

--------------------------------------------------------------------------------------------------------
--                                          Item Summaries                                            --
--------------------------------------------------------------------------------------------------------

-- Read confirmed enchant text and gems from the same links used by the gear snapshot.
local function ItemDetails(link, slotName)
    local details = {}
    local enchant = tonumber(link:match("item:%d+:(%d+)"))
    if enchant and enchant > 0 then
        local lines = ns.Gear.Tooltip(link)
        local prefix = (ENCHANTED_TOOLTIP_LINE or "Enchanted: %s"):gsub("%%s", "")
        for _, line in ipairs(lines or {}) do
            local text = C.IsTable(line) and C.Text(line.leftText)
            if text and text:find(prefix, 1, true) then
                details[#details + 1] = text
                break
            end
        end
    end
    local gems = ns.Gear.ReadGems({[slotName] = link})
    local raw = C.Try((C_Item and C_Item.GetItemStats) or GetItemStats, link)
    local sockets = 0
    if C.IsTable(raw) then
        for key, value in pairs(raw) do
            if C.IsString(key) and key:match("^EMPTY_SOCKET_") and C.IsNumber(value)
                and value >= 0 and value <= 8 and value % 1 == 0 then
                sockets = sockets + value
            end
        end
    end
    local names = {}
    for _, gem in ipairs(gems.items) do
        if gem.name then names[#names + 1] = gem.name end
    end
    local socketText = sockets > 0 and ns.F("Sockets: %d", sockets) or nil
    local gemText = #names > 0 and (L["Gems"] .. ": " .. table.concat(names, ", ")) or nil
    if socketText or gemText then
        details[#details + 1] = (socketText or "") .. (socketText and gemText and " | " or "") .. (gemText or "")
    end
    return #details > 0 and table.concat(details, "\n") or (_G[slotName:upper()] or ""), gems.pending
end

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
local heading = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontNormalSmall")
heading:SetPoint("TOPLEFT", 40, -8)
heading:SetText(L["Item"])
local levelHeading = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontNormalSmall")
levelHeading:SetPoint("TOPRIGHT", -26, -8)
levelHeading:SetText(L["iLevel"])
mod.equipmentItemHeading, mod.equipmentLevelHeading = heading, levelHeading
local status = ns.Fonts.Create(list, nil, "ARTWORK", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", 9, -35)
status:SetPoint("TOPRIGHT", -25, -35)
status:SetJustifyH("LEFT")
status:SetWordWrap(true)
mod.equipmentStatus = status
local scroll = CreateFrame("ScrollFrame", "ExaminerEquipmentScroll", list, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 7, -27)
scroll:SetPoint("BOTTOMRIGHT", -25, 10)
scroll:SetSize(mod.page:GetWidth() - 32, mod.page:GetHeight() - 37)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(scroll:GetWidth(), 1)
scroll:SetScrollChild(content)
local bar = scroll.ScrollBar or _G[scroll:GetName() .. "ScrollBar"]
local up = bar.ScrollUpButton or _G[bar:GetName() .. "ScrollUpButton"]
local down = bar.ScrollDownButton or _G[bar:GetName() .. "ScrollDownButton"]
bar.scrollStep = ROW_HEIGHT
bar:ClearAllPoints()
bar:SetPoint("TOPRIGHT", list, "TOPRIGHT", -6, -43)
bar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -6, 26)
mod.equipmentScroll, mod.equipmentContent, mod.equipmentBar = scroll, content, bar

-- Keep native scrollbar controls synchronized with a clamped list position.
local function ScrollTo(value)
    local maximum = math.max(0, content:GetHeight() - scroll:GetHeight())
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
scroll:SetScript("OnMouseWheel", function(_, delta) ScrollTo(scroll:GetVerticalScroll() - delta * ROW_HEIGHT) end)

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
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("TOPLEFT", 0, -3)
    row.name = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", 33, -2)
    row.name:SetPoint("TOPRIGHT", -29, -2)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.level = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontNormalSmall")
    row.level:SetPoint("TOPRIGHT", -1, -2)
    row.level:SetWidth(28)
    row.level:SetJustifyH("RIGHT")
    row.detail = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontHighlightSmall")
    row.detail:SetFont(select(1, GameFontHighlightSmall:GetFont()), 9, "")
    row.detail:SetPoint("TOPLEFT", 33, -17)
    row.detail:SetPoint("BOTTOMRIGHT", -2, 3)
    row.detail:SetJustifyH("LEFT")
    row.detail:SetJustifyV("TOP")
    row.detail:SetWordWrap(true)
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
            local detail, pending
            if name then detail, pending = ItemDetails(link, slotName) end
            row.detail:SetText(detail or (_G[slotName:upper()] or ""))
            for _, missing in ipairs(pending or {}) do
                local itemID = tonumber(missing:match("item:(%d+)"))
                if itemID then self.equipmentPending[itemID] = true end
            end
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
    status:SetText(count == 0 and (ex.gear and ex.gear.state == "loading"
        and L["Item data is still loading."] or L["No equipment available."]) or "")
    content:SetHeight(math.max(1, count * ROW_HEIGHT))
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

-- Resolve only metadata requested by the current list, including cached gem names.
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
    content:SetHeight(1)
    ScrollTo(0)
end

-- Update the optional list when its appearance preference changes.
function mod:OnConfigChanged(var)
    if var == "style" then self:RefreshEquipmentView() end
end

-- Resize the equipment viewport and clamp its scroll range after changing navigation.
function mod:OnLayoutChanged()
    scroll:SetHeight(self.page:GetHeight() - 37)
    ScrollTo(scroll:GetVerticalScroll())
end

-- Refresh metadata and colors whenever the equipment page opens.
mod.page:HookScript("OnShow", function()
    mod:OnLayoutChanged()
    mod:RefreshEquipmentView()
    list:Show()
    mod:BuildEquipmentList()
end)
