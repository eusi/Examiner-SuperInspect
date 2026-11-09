--------------------------------------------------------------------------------------------------------
--
-- modcore.lua
-- Registers modules and manages their pages, tabs and shared detail rows.
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
local gtt = GameTooltip

local ModuleCore = {}

ModuleCore.__index = ModuleCore
ex.ModuleCore = ModuleCore

-- TABLES

ex.modules = {}
ex.buttons = {}
local moduleIcons = {
    Stats = "INV_Chest_Plate16", Equipment = "INV_Misc_Note_01", PvP = "INV_BannerPVP_02",
    Talents = "INV_Misc_Book_11", Guild = "INV_Shirt_GuildTabard_01", Runes = "INV_Misc_Rune_06",
    Professions = "Trade_BlackSmithing", Achievements = "Achievement_General", More = "INV_Misc_Gear_01",
    Config = "INV_Misc_Wrench_01", Cache = "INV_Misc_Book_09", Modules = "INV_Misc_EngGizmos_19",
}

--------------------------------------------------------------------------------------------------------
--                                          Helper Functions                                          --
--------------------------------------------------------------------------------------------------------

-- Share menu artwork and use the local player's faction for the PvP navigation banner.
function ex:GetModuleIcon(token, fallback)
    if token == "PvP" then
        local C = ExaminerNS.Compat
        return C.Text(C.Try(UnitFactionGroup, "player")) == "Horde" and "INV_BannerPVP_01" or "INV_BannerPVP_02"
    end
    return moduleIcons[token] or fallback or "INV_Misc_QuestionMark"
end

-- Find a registered module by its stable token.
function ex:GetModuleFromToken(token)
    for index, mod in ipairs(ex.modules) do
        if mod.token == token then
            return mod, index
        end
    end
end

-- Register a module with its title and page index.
function ex:CreateModule(token, title)
    local mod =
        setmetatable({ token = token, title = title, hasData = true, index = #ex.modules + 1 }, ModuleCore)
    ex.modules[#ex.modules + 1] = mod
    return mod
end

-- Dispatch an event to enabled modules and required cleanup handlers.
function ex:SendModuleEvent(event, ...)
    for index, mod in ipairs(self.modules) do
        if mod[event] and (mod:IsEnabled() or event == "OnClearInspect" or event == "OnInspectHidden") then
            mod[event](mod, ...)
        end
    end
    if event == "OnConfigChanged" and (...) == "font" then
        ExaminerNS.Fonts.Refresh(self)
    end
    if ExaminerNS.Appearance and self.cfg and self.cfg.style ~= "classic" then
        ExaminerNS.Appearance.RefreshLabels()
    end
end

-- Keep core navigation available and respect saved module choices.
function ModuleCore:IsEnabled()
    if self.parentToken then
        local parent = ex:GetModuleFromToken(self.parentToken)
        return parent and parent:IsEnabled() or false
    end
    local required = self.token == "More"
        or self.token == "Config"
        or self.token == "Cache"
        or self.token == "Modules"
        or self.token == "ItemSlots"
    if required then return true end
    local choices = ex.cfg and ex.cfg.disabledModules
    if type(choices) == "table" and type(choices[self.token]) == "boolean" then
        return not choices[self.token]
    end
    return not self.defaultDisabled
end

-- Toggle a feature and synchronize its page and current data.
function ex:SetModuleEnabled(token, enabled)
    local module = self:GetModuleFromToken(token)
    if
        not module
        or not module.page
        or module.parentToken
        or token == "More"
        or token == "Config"
        or token == "Cache"
        or token == "Modules"
    then
        return false
    end
    enabled = not not enabled
    if module:IsEnabled() == enabled then
        return true
    end
    self.cfg.disabledModules[token] = not enabled
    AzDropDown:HideMenu()
    if not enabled then
        if module.OnInspectHidden then
            module:OnInspectHidden()
        end
        if module.OnClearInspect then
            module:OnClearInspect()
        end
        module.page:Hide()
        if self.cfg.activePage == module.index then
            self.cfg.activePage = nil
            self.cfg.activePageToken = nil
            self:SendModuleEvent("OnPageChanged", module, false)
        end
    else
        if module.OnLayoutChanged then module:OnLayoutChanged(self.navigationContentExtra or 0) end
        if module.OnConfigChanged then
            for _, option in ipairs(self.options) do
                module:OnConfigChanged(option.var, self.cfg[option.var])
            end
            module:OnConfigChanged("scale", self.cfg.scale)
        end
        if self.isCacheEntry then
            if module.OnCacheLoaded then
                module:OnCacheLoaded(self.info, self.unit)
            end
        else
            local I = ExaminerNS.Inspector
            local session = I and I.active
            if session and I:Valid(session) and self.unitType ~= 1 then
                if module.OnInspect then
                    module:OnInspect(session.unit, session.guid)
                end
                if session.serverReady and module.OnInspectReady then
                    module:OnInspectReady(session.unit, session.guid)
                end
            end
        end
    end
    self:RefreshModuleButtons()
    if module.parentToken then
        local parent = self:GetModuleFromToken(module.parentToken)
        if parent and parent.page:IsShown() and parent.Draw then
            parent:Draw()
        end
    end
    local manager = self:GetModuleFromToken("More")
    if manager then
        manager:BuildModuleList()
    end
    return true
end

--------------------------------------------------------------------------------------------------------
--                                           Detail Object                                            --
--------------------------------------------------------------------------------------------------------

local DetailObject = {}
DetailObject.__index = DetailObject

-- Create a recyclable collection of detail rows.
function ex:CreateDetailObject()
    return setmetatable({ entries = LibTableRecycler:New() }, DetailObject)
end

-- Notify modules that detail rows need rebuilding.
function DetailObject:Update()
    ex:SendModuleEvent("OnDetailsUpdate")
end

-- Append a detail row using a recycled table.
function DetailObject:Add(label, value, tip)
    local tbl = self.entries:Fetch()
    tbl.label = label
    tbl.value = value
    tbl.tip = tip
end

-- Return detail rows to the recycler.
function DetailObject:Clear()
    self.entries:Recycle()
end

--------------------------------------------------------------------------------------------------------
--                                          Button Functions                                          --
--------------------------------------------------------------------------------------------------------

-- Open a module page and process its button shortcuts.
local function Buttons_OnClick(self, button, down)
    local id = self.id
    local module = ex.modules[id]
    if module and module:IsEnabled() and module.hasData then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) -- "igMainMenuOptionCheckBoxOn"
        -- CALL MODULE ONBUTTONCLICK

        if module.OnButtonClick then
            module:OnButtonClick(self, button, down)
        end
        -- UNMODIFIED LEFT CLICKS

        if not IsModifierKeyDown() then
            if (button == "LeftButton") and module.page then
                ex:ShowModulePage(id)
                AzDropDown:HideMenu()
            elseif module.MenuInit and module.MenuSelect then
                self.initFunc = module.MenuInit
                self.selectValueFunc = module.MenuSelect
                if self.navigationIconMode then
                    AzDropDown:ToggleMenu(self, "TOPRIGHT", "TOPLEFT")
                else
                    AzDropDown:ToggleMenu(self, "TOPLEFT", "BOTTOMLEFT")
                end
            end
        end
    end
end

-- Show the module description and contextual shortcuts.
local function Buttons_OnEnter(self, motion)
    local module = ex.modules[self.id]
    if not module then
        return
    end
    gtt:SetOwner(self, "ANCHOR_NONE")
    gtt:ClearAllPoints()
    if self.navigationIconPosition == "bottom" then
        gtt:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -6)
    elseif self.navigationIconMode then
        gtt:SetPoint("TOPLEFT", self, "TOPRIGHT", 6, 0)
    else
        gtt:SetPoint("BOTTOMLEFT", self, "TOPLEFT")
    end
    gtt:ClearLines()
    gtt:AddLine(module.title)
    if module.help then
        -- Size navigation help to its longest line while preserving explicit shortcut breaks.
        gtt:AddLine(module.help, 1, 1, 1, false)
    end
    local active = ex.modules[ex.cfg.activePage]
    if module.token == "More" and active and active.token == "Cache" then
        gtt:AddLine(ExaminerNS.L["Right-click: filter, sort, or delete saved players."], 1, 1, 1, false)
    end
    gtt:Show()
end

-- Create a footer button with a safe font-label fallback.
local function CreateModuleButton(label, tipHeader, tipText)
    local btn = CreateFrame("Button", nil, ex, "UIPanelButtonGrayTemplate")
    btn:SetSize(75, 21)
    btn:SetFrameLevel(btn:GetFrameLevel() + 2)
    btn:RegisterForClicks("AnyUp")
    btn:SetScript("OnClick", Buttons_OnClick)
    btn:SetScript("OnEnter", Buttons_OnEnter)
    btn:SetScript("OnLeave", ex.HideGTT)
    -- Button labels may not exist until text is assigned.
    btn:SetText(" ")
    local text = btn:GetFontString()
    if not text then
        text = ExaminerNS.Fonts.Create(btn, nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        btn:SetFontString(text)
    end
    btn.labelFont, btn.labelSize, btn.labelFlags = text:GetFont()
    if not btn.labelFont or not btn.labelSize then
        btn.labelFont, btn.labelSize, btn.labelFlags = GameFontNormal:GetFont()
    end

    ex.buttons[#ex.buttons + 1] = btn
    return btn
end

--------------------------------------------------------------------------------------------------------
--                                           Meta Functions                                           --
--------------------------------------------------------------------------------------------------------

-- Register a module option in the shared settings list.
function ModuleCore:AddOption(option)
    ex.options[#ex.options + 1] = option
end

-- Check whether this enabled module is the active page.
function ModuleCore:IsShown()
    return self:IsEnabled() and (ex.cfg.activePage == self.index)
end

-- Require both core caching and the module cache preference.
function ModuleCore:CanCache()
    return self:IsEnabled() and self.canCache and ex.cfg.caching.Core and ex.cfg.caching[self.token]
end

-- Update page and button availability without disabling the feature.
function ModuleCore:HasData(value)
    local changed = (self.hasData and true or false) ~= (value and true or false)
    self.hasData = (value and true or nil)
    if value and self:IsEnabled() then
        if self.button then
            self.button:Enable()
        end
    else
        if self.page then
            self.page:Hide()
        end
        if self.button then
            self.button:Disable()
        end
    end
    if changed and ex.cfg then
        ex:SendModuleEvent("OnDataChanged", self)
        ExaminerNS.Appearance.UpdateSelection()
    end
end

-- Rebuild visible tabs and fit their localized labels.
function ex:RefreshModuleButtons()
    local count = 0
    -- Change presentation order without moving module indices or saved page identities.
    local ordered, gearList = {}, self:GetModuleFromToken("Equipment")
    for _, module in ipairs(self.modules) do
        if module ~= gearList then
            ordered[#ordered + 1] = module
            if module.token == "Stats" and gearList then ordered[#ordered + 1] = gearList end
        end
    end
    local iconsRight = self.cfg and self.cfg.menuStyle == "iconsRight"
    local iconsBottom = self.cfg and self.cfg.menuStyle == "iconsBottom"
    local iconMode = iconsRight or iconsBottom
    local navigationCount = 0
    for _, module in ipairs(self.modules) do
        if module.hasButton and module:IsEnabled() then navigationCount = navigationCount + 1 end
    end
    local iconHeight = math.max(32, math.min(40, math.floor((self:GetHeight() - 86) / math.max(1, navigationCount)) - 2))
    if iconsBottom then iconHeight = math.min(40, math.floor((self.model:GetWidth() - 4) / math.max(1, navigationCount)) - 2) end
    local compactIcons = iconMode and self.cfg.style == "modern"
    local iconGap = compactIcons and 8 or 2
    local iconSize = iconHeight - 8
    if compactIcons then
        -- Leave room for the shared silver frame, grey padding and the icon's own black outline.
        local available = iconsBottom and self.model:GetWidth() or (self:GetHeight() - 86)
        local fitted = math.floor((available - math.max(0, navigationCount - 1) * iconGap) / math.max(1, navigationCount))
        iconSize = math.max(12, math.min(44, fitted) - 12)
    end
    local iconWidth = compactIcons and (iconSize + 12) or iconsBottom and iconHeight or (iconHeight + 6)
    local iconButtonHeight = compactIcons and (iconSize + 12) or iconsBottom and (iconHeight + 6) or iconHeight
    for _, module in ipairs(self.modules) do
        module.button = nil
    end
    for _, module in ipairs(ordered) do
        if module.hasButton and module:IsEnabled() then
            count = count + 1
            local button = self.buttons[count] or CreateModuleButton()
            button:ClearAllPoints()
            if iconsRight then
                button:SetPoint("TOPLEFT", self, "TOPRIGHT", -35, -78 - (count - 1) * (iconButtonHeight + iconGap))
            elseif iconsBottom then
                local totalWidth = navigationCount * (iconWidth + iconGap) - iconGap
                button:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 21 + (self.model:GetWidth() - totalWidth) / 2 + (count - 1) * (iconWidth + iconGap), self.cfg.style == "classic" and 4 or 2)
            elseif count == 1 then
                button:SetPoint("BOTTOMLEFT", 24, 13)
            else
                button:SetPoint("LEFT", self.buttons[count - 1], "RIGHT", 1, 0)
            end
            button.id = module.index
            module.button = button
            button:SetText(module.buttonLabel or ExaminerNS.L[module.token])
            button:SetHeight(iconMode and iconButtonHeight or 21)
            button.navigationIconMode = iconMode
            button.navigationIconPosition = iconsBottom and "bottom" or iconsRight and "right" or nil
            local label = button:GetFontString()
            label:SetShown(not iconMode)
            if not button.navigationIcon then
                button.navigationIcon = button:CreateTexture(nil, "ARTWORK")
            end
            button.navigationIcon:ClearAllPoints()
            button.navigationIcon:SetPoint("CENTER", compactIcons and 0 or iconsBottom and 0 or -2, compactIcons and 0 or iconsBottom and 2 or 0)
            button.navigationIcon:SetSize(iconSize, iconSize)
            button.navigationIcon:SetTexture("Interface\\Icons\\" .. self:GetModuleIcon(module.token))
            button.navigationIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            button.navigationIcon:SetShown(iconMode)
            if module.hasData then
                button:Enable()
            else
                button:Disable()
            end
            button:SetShown(self.unitType ~= 1 or module.token == "More")
        end
    end
    for index, button in ipairs(self.buttons) do
        if index <= count then
            local width = (self.model:GetWidth() - 4) / math.max(1, count) - 1
            button:SetWidth(iconMode and iconWidth or width)
            local label = button:GetFontString()
            label:SetFont(button.labelFont, button.labelSize, button.labelFlags)
            local measured = label:GetStringWidth()
            if measured > width - 8 then
                label:SetFont(
                    button.labelFont,
                    math.max(8, button.labelSize * (width - 8) / measured),
                    button.labelFlags
                )
            end
            label:SetWidth(math.max(1, width - 8))
            label:SetWordWrap(false)
            ExaminerNS.Fonts.Apply(label)
        else
            button.id = nil
            button:Hide()
        end
    end
    if ExaminerNS.Appearance then
        ExaminerNS.Appearance.UpdateLayout()
        ExaminerNS.Appearance.UpdateSelection()
    end
end

-- Set whether this module has a footer tab.
function ModuleCore:HasButton(value)
    self.hasButton = value
    ex:RefreshModuleButtons()
end

-- BACKDROP

local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },

    backdropColor = CreateColor(0.06, 0.132, 0.21, 0.7),
    backdropBorderColor = CreateColor(0.7, 0.7, 0.8, 0.2),
}
ModuleCore.backdrop = backdrop

-- Create the module content frame and optional heading.
function ModuleCore:CreatePage(full, header)
    local page = CreateFrame("Frame", nil, ex.model, "BackdropTemplate")
    page:SetSize(full and 320 or 235, full and 330 or 288)
    page:SetPoint("TOP")

    page:SetBackdrop(backdrop)
    page:SetBackdropColor(backdrop.backdropColor:GetRGBA())
    page:SetBackdropBorderColor(backdrop.backdropBorderColor:GetRGBA())

    page:Hide()
    if header then
        page.header = ExaminerNS.Fonts.Create(page, nil, "ARTWORK")
        page.header:SetFont(GameFontNormal:GetFont(), 16, "THICKOUTLINE")
        page.header:SetTextColor(0.5, 0.75, 1)
        page.header:SetPoint("TOP", 0, -14)
        page.header:SetText(header)
    end
    self.page = page
    ExaminerNS.Appearance.RegisterPage(page)
    self.showItems = (not full or nil)
    return page
end
