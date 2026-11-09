--------------------------------------------------------------------------------------------------------
--
-- Modules/config.lua
-- Creates the Settings page and saves window, font, item-level and cache preferences.
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
local GetAddOnMetadata = ExaminerNS.Compat.GetAddOnMetadata
local cfg

-- MODULE

local mod = ex:CreateModule("Config", ExaminerNS.L["Settings"])
mod.help = ExaminerNS.L["Various settings can be adjusted here."]
mod:CreatePage(false, ExaminerNS.L["Settings"])

-- CREATE VERSION STRING

local modName = ex:GetName()
local vers = ExaminerNS.Fonts.Create(mod.page, nil, "ARTWORK", "GameFontHighlightSmall")
vers:SetText("Examiner |cffffff80" .. (GetAddOnMetadata(modName, "Version") or "") .. "|r by sAks")
vers:SetPoint("BOTTOM", 0, 14)
mod.versionText = vers

-- VARIABLES

local checkBtns = {}
local CONTENT_LEFT = 10
local SCROLLBAR_MARGIN, SCROLLBAR_WIDTH, CONTENT_GAP = 10, 16, 6
local CONTENT_RIGHT = SCROLLBAR_MARGIN + SCROLLBAR_WIDTH + CONTENT_GAP

--------------------------------------------------------------------------------------------------------
--                                           Config Scripts                                           --
--------------------------------------------------------------------------------------------------------

-- Save a checkbox and notify modules of the changed option.
local function ConfigCheckBox_OnClick(self, button)
    local var = ex.options[self.id].var
    cfg[var] = (self:GetChecked() and true or false)
    -- Special "makeMovable" handling -- Must not invoke the OnHide event!
    if var == "makeMovable" then
        local onHide = ex:GetScript("OnHide")
        ex:SetScript("OnHide", nil)
        ex:SetMovable(cfg.makeMovable)
        if cfg.makeMovable then
            HideUIPanel(ex)
            ex:Show()
        else
            ex:Hide()
            ShowUIPanel(ex)
        end
        ex:SetScript("OnHide", onHide)
    end
    -- POST CHANGE TO MODULES

    ex:SendModuleEvent("OnConfigChanged", var, cfg[var])
end

-- Explain the selected setting in a wrapped tooltip.
local function ConfigCheckBox_OnEnter(self)
    local option = ex.options[self.id]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(option.label, 1, 1, 1)
    GameTooltip:AddLine(option.tip, 1, 1, 1, true)
    GameTooltip:Show()
end

--------------------------------------------------------------------------------------------------------
--                                          Settings Choices                                          --
--------------------------------------------------------------------------------------------------------

-- Build the per-module caching choices.
local function MenuInit(parent, list)
    list[1].text = "|cff00c0ff" .. ExaminerNS.L["Examiner Core Caching"]
    list[1].value = "Core"
    list[1].checked = cfg.caching.Core
    list[1].tip = ExaminerNS.L["Automatically saves inspected players' gear and basic details."]
    for index, mod in ipairs(ex.modules) do
        if mod.canCache then
            local tbl = list[#list + 1]
            tbl.text = mod.title
            tbl.value = mod.token
            tbl.checked = cfg.caching[mod.token]
            tbl.tip = mod.cacheHelp
                or ExaminerNS.L["Save this module's data with player profiles. Requires Core Caching."]
        end
    end
end

-- Toggle the selected module cache preference.
local function MenuSelect(parent, entry)
    cfg.caching[entry.value] = not cfg.caching[entry.value]
end

-- Offer the calculated source and the available Blizzard source.
local function SourceMenuInit(parent, list)
    local C, L = ExaminerNS.Compat, ExaminerNS.L
    local available = (C.isRetail or C.isForever)
        and type(C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel) == "function"
    for index, value in ipairs({ "calculated", "blizzard" }) do
        local row = list[index]
        row.text = L[value == "calculated" and "Calculated" or "Blizzard"]
        row.value = value
        row.checked = cfg.itemLevelSource == value
        row.header = value == "blizzard" and not available
        row.tip = row.header and L["Not available in this WoW version."]
            or L[value == "calculated" and "Uses Examiner's equipped item-level calculation." or "Uses Blizzard's equipped item level. Missing values are shown as a dash."]
    end
end

-- Save the item-level source and refresh the current statistics.
local function SourceMenuSelect(parent, entry)
    if entry.header then
        return
    end
    cfg.itemLevelSource = entry.value
    ex:SendModuleEvent("OnConfigChanged", "itemLevelSource", entry.value)
end

-- List fonts compatible with the current client language.
local function FontMenuInit(parent, list)
    for index, choice in ipairs(ExaminerNS.Fonts.GetChoices()) do
        local row = list[index]
        row.text, row.value = choice[2], choice[1]
        row.checked = ExaminerNS.Fonts.IsSelected(choice[1], cfg.font)
        row.header = choice[4]
        row.tip = choice[4] and ExaminerNS.L["Not available"] or nil
        row.font = choice[3] or select(1, GameFontHighlightSmall:GetFont())
    end
end

-- Save and apply the font to Examiner-owned text.
local function FontMenuSelect(parent, entry)
    if entry.header then
        return
    end
    cfg.font = entry.value
    ex:SendModuleEvent("OnConfigChanged", "font", entry.value)
    ex:RefreshModuleButtons()
    local stats = ex:GetModuleFromToken("Stats")
    if stats and stats:IsEnabled() then
        stats:BuildShownList()
    end
end

-- Refresh the settings viewport after the footer space becomes available or is restored.
function mod:OnLayoutChanged()
    if not self.settingsScroll then return end
    self.settingsScroll:SetHeight(self.page:GetHeight() - 44)
    local changed = self.settingsScroll:GetScript("OnSizeChanged")
    if changed then changed(self.settingsScroll) end
end

-- Offer independent style and navigation choices with Classic selected by default.
local function AppearanceMenuInit(parent, list)
    local style = parent.appearanceSetting == "style"
    local choices = style and {{"classic", "Classic"}, {"modern", "Modern"}, {"forever", "Forever"}}
        or {{"classic", "Classic"}, {"iconsRight", "Icons on the right"}, {"iconsBottom", "Icons at the bottom"}}
    for index, choice in ipairs(choices) do
        local row = list[index]
        row.text, row.value = ExaminerNS.L[choice[2]], choice[1]
        row.checked = cfg[parent.appearanceSetting] == choice[1]
    end
end

-- Apply one appearance choice without changing the other dropdown's setting.
local function AppearanceMenuSelect(parent, entry)
    if not entry.header then ExaminerNS.Appearance.Select(parent.appearanceSetting, entry.value) end
end

-- Fill the closed selector behind its label and arrow.
local function AddSelectorBackground(dropdown)
    local background = dropdown:CreateTexture(nil, "BACKGROUND")
    background:SetColorTexture(0, 0, 0, 1)
    background:SetAllPoints(dropdown)
    dropdown.background = background
end

-- Create a single-line selector with its selection shown only in the open menu.
local function CreateSelector(page, y, title, initialize, selectValue)
    local dropdown = AzDropDown:CreateDropDown(page, -190, initialize, selectValue, false, true)
    dropdown:SetWidth(page:GetWidth() - CONTENT_LEFT - CONTENT_RIGHT)
    dropdown:SetPoint("TOPLEFT", CONTENT_LEFT, y)
    dropdown.label:SetJustifyH("LEFT")
    dropdown.label:SetTextColor(1, 0.82, 0)
    dropdown:SetBackdrop(nil)
    AddSelectorBackground(dropdown)
    dropdown.menuFillColor = { 0, 0, 0, 1 }
    dropdown.menuAutoFlip = true
    dropdown.menuBounds = mod.settingsScroll
    dropdown.menuRoot = ex
    dropdown.menuInset = 6
    dropdown.button:SetHitRectInsets(0, 0, 0, 0)
    -- Open the options from the arrow at the right edge.
    dropdown.button:SetScript("OnClick", function(self)
        AzDropDown:ToggleMenu(self:GetParent(), "TOPRIGHT", "BOTTOMRIGHT")
    end)
    dropdown:SetText(title)
    return dropdown
end

--------------------------------------------------------------------------------------------------------
--                                          Widget Creation                                           --
--------------------------------------------------------------------------------------------------------

-- Initialize settings controls and saved preferences.
function mod:OnInitialize()
    cfg = ex.cfg

    -- SCROLLABLE CONTENT

    local scroll =
        CreateFrame("ScrollFrame", "ExaminerSettingsScroll", self.page, "UIPanelScrollFrameTemplate")
    self.settingsScroll = scroll
    scroll:SetSize(self.page:GetWidth(), self.page:GetHeight() - 44)
    scroll:SetPoint("TOPLEFT", 0, -34)
    scroll:SetPoint("BOTTOMRIGHT", 0, 10)
    local content = CreateFrame("Frame", nil, scroll)
    self.settingsContent = content
    content:SetSize(self.page:GetWidth(), 310)
    vers:SetParent(content)
    vers:ClearAllPoints()
    vers:SetPoint("TOP", content, "TOP", 0, -286)
    scroll:SetScrollChild(content)
    local bar = scroll.ScrollBar or _G[scroll:GetName() .. "ScrollBar"]
    self.settingsScrollBar = bar
    local up = bar.ScrollUpButton or _G[bar:GetName() .. "ScrollUpButton"]
    local down = bar.ScrollDownButton or _G[bar:GetName() .. "ScrollDownButton"]
    bar.scrollStep = 24
    bar:ClearAllPoints()
    bar:SetWidth(SCROLLBAR_WIDTH)
    bar:SetPoint("TOPRIGHT", self.page, "TOPRIGHT", -SCROLLBAR_MARGIN, -50)
    bar:SetPoint("BOTTOMRIGHT", self.page, "BOTTOMRIGHT", -SCROLLBAR_MARGIN, 26)

    -- Clamp wheel and slider input to the available settings content.
    local function ScrollTo(value)
        AzDropDown:HideMenu()
        local maximum = math.max(0, content:GetHeight() - scroll:GetHeight())
        value = math.max(0, math.min(maximum, value or 0))
        if scroll:GetVerticalScroll() ~= value then
            scroll:SetVerticalScroll(value)
        end
        bar:SetMinMaxValues(0, maximum)
        if bar:GetValue() ~= value then
            bar:SetValue(value)
        end
        bar:SetShown(maximum > 0)
        if up then
            up:SetEnabled(value > 0)
        end
        if down then
            down:SetEnabled(value < maximum)
        end
    end

    -- Scroll settings when dragging the thumb.
    bar:SetScript("OnValueChanged", function(_, value)
        ScrollTo(value)
    end)
    scroll:EnableMouseWheel(true)
    -- Scroll settings and version credits while keeping the heading fixed.
    scroll:SetScript("OnMouseWheel", function(_, delta)
        ScrollTo(scroll:GetVerticalScroll() - delta * 24)
    end)
    -- Recalculate the scroll range when the settings viewport changes.
    scroll:SetScript("OnSizeChanged", function()
        ScrollTo(scroll:GetVerticalScroll())
    end)
    ScrollTo(0)

    -- DROPDOWN

    self.dropDown = AzDropDown:CreateDropDown(content, -190, MenuInit, MenuSelect, false, false)
    self.dropDown:SetBackdrop(nil)
    AddSelectorBackground(self.dropDown)
    self.dropDown.menuFillColor = { 0, 0, 0, 1 }
    self.dropDown.menuAutoFlip = true
    self.dropDown.menuBounds = scroll
    self.dropDown.menuRoot = ex
    self.dropDown.menuInset = 6
    self.dropDown:SetWidth(self.page:GetWidth() - CONTENT_LEFT - CONTENT_RIGHT)
    self.dropDown:SetPoint("TOPLEFT", CONTENT_LEFT, -4)
    self.dropDown.button:SetHitRectInsets(0, 0, 0, 0)
    self.dropDown.label:SetJustifyH("LEFT")
    self.dropDown.label:SetTextColor(1, 0.82, 0)
    self.dropDown:SetText(ExaminerNS.L["Enabled Module Caching"])

    -- CHECK BOXES

    for index, option in ipairs(ex.options) do
        local chk = CreateFrame("CheckButton", nil, content)
        chk:SetSize(21, 21)
        chk:SetScript("OnClick", ConfigCheckBox_OnClick)
        chk:SetScript("OnEnter", ConfigCheckBox_OnEnter)
        chk:SetScript("OnLeave", ex.HideGTT)

        chk:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        chk:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        chk:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        chk:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
        chk:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

        chk:SetChecked(cfg[option.var])

        chk.text = ExaminerNS.Fonts.Create(chk, "ARTWORK", nil, "GameFontNormalSmall")
        chk.text:SetPoint("LEFT", chk, "RIGHT", 0, 1)
        chk.text:SetText(option.label)
        chk:SetHitRectInsets(0, chk.text:GetWidth() * -1, 0, 0)

        chk.id = index
        chk.var = option.var

        if index == 1 then
            chk:SetPoint("TOPLEFT", CONTENT_LEFT, -34)
        else
            chk:SetPoint("TOP", checkBtns[index - 1], "BOTTOM", 0, 2)
        end

        checkBtns[index] = chk
    end

    local slider = CreateFrame("Slider", nil, content)
    self.scaleSlider = slider
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(self.page:GetWidth() - CONTENT_LEFT - CONTENT_RIGHT, 16)
    slider:SetPoint("TOPLEFT", CONTENT_LEFT, -60 - #checkBtns * 19)
    slider:SetMinMaxValues(0.75, 1.50)
    slider:SetValueStep(0.01)
    slider:SetObeyStepOnDrag(true)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb:SetSize(24, 24)
    slider:SetThumbTexture(thumb)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    track:SetAllPoints(slider)
    local label = ExaminerNS.Fonts.Create(slider, nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 6)
    label:SetText(ExaminerNS.L["Window scale"])
    slider.valueText = ExaminerNS.Fonts.Create(slider, nil, "OVERLAY", "GameFontHighlightSmall")
    slider.valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 6)
    for index, text in ipairs({ "0.75", "1.50" }) do
        local limit = ExaminerNS.Fonts.Create(slider, nil, "OVERLAY", "GameFontHighlightSmall")
        limit:SetPoint(
            index == 1 and "TOPLEFT" or "TOPRIGHT",
            slider,
            index == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT",
            0,
            -2
        )
        limit:SetText(text)
        limit:SetTextColor(0.7, 0.7, 0.7)
    end
    -- Commit the scale preview when dragging ends.
    local function ApplyScale(self)
        local value = self.pendingScale
        self.pendingScale = nil
        self:SetScript("OnUpdate", nil)
        if value then
            ex:SetWindowScale(value)
        end
    end
    -- Synchronize the displayed value with the control.
    slider:SetScript("OnValueChanged", function(self, value)
        if self.syncing then
            return
        end
        value = math.max(0.75, math.min(1.50, math.floor(value * 100 + 0.5) / 100))
        self.valueText:SetText(string.format("%.2f", value))
        if IsMouseButtonDown("LeftButton") then
            self.pendingScale = value
            -- Refresh pending data or finish the current interaction.
            self:SetScript("OnUpdate", function(self)
                if not IsMouseButtonDown("LeftButton") then
                    ApplyScale(self)
                end
            end)
        else
            ex:SetWindowScale(value)
        end
    end)
    -- Finish dragging and commit the pending interaction.
    slider:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            ApplyScale(self)
        end
    end)
    -- Release transient view state when its controls are hidden.
    slider:SetScript("OnHide", function(self)
        mod:OnConfigChanged("scale", cfg.scale)
    end)
    -- Show the control description or unavailable-data explanation.
    slider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ExaminerNS.L["Adjusts the window scale. Default: 100%."], 1, 1, 1)
        GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", ex.HideGTT)
    self:OnConfigChanged("scale", cfg.scale)
    self.sourceDropDown =
        CreateSelector(content, -312, ExaminerNS.L["Average Item Level"], SourceMenuInit, SourceMenuSelect)
    self.fontDropDown = CreateSelector(content, -280, ExaminerNS.L["Font"], FontMenuInit, FontMenuSelect)
    self.styleDropDown = CreateSelector(content, -248, ExaminerNS.L["Style"], AppearanceMenuInit, AppearanceMenuSelect)
    self.styleDropDown.appearanceSetting = "style"
    self.menuDropDown = CreateSelector(content, -216, ExaminerNS.L["Menu"], AppearanceMenuInit, AppearanceMenuSelect)
    self.menuDropDown.appearanceSetting = "menuStyle"
    content:SetHeight(374)
    vers:ClearAllPoints()
    vers:SetPoint("TOP", content, "TOP", 0, -350)
    ScrollTo(scroll:GetVerticalScroll())
    self:OnConfigChanged("itemLevelSource", cfg.itemLevelSource)
    self:OnConfigChanged("font", cfg.font)
    -- Close floating options when the settings page is left.
    self.page:HookScript("OnHide", function()
        AzDropDown:HideMenu()
    end)
end

--------------------------------------------------------------------------------------------------------
--                                       Configuration Updates                                        --
--------------------------------------------------------------------------------------------------------

-- Apply changed preferences to the settings display.
function mod:OnConfigChanged(var, value)
    if var == "scale" and self.scaleSlider then
        local slider = self.scaleSlider
        slider.pendingScale = nil
        slider:SetScript("OnUpdate", nil)
        slider.syncing = true
        slider:SetValue(value)
        slider.valueText:SetText(string.format("%.2f", value))
        slider.syncing = nil
    end
    for index, chk in ipairs(checkBtns) do
        if chk.var == var then
            chk:SetChecked(cfg[var])
        end
    end
end
