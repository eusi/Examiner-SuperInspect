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

--------------------------------------------------------------------------------------------------------
--                                          Helper Functions                                          --
--------------------------------------------------------------------------------------------------------

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
end

-- Keep core navigation available and respect saved module choices.
function ModuleCore:IsEnabled()
    if self.parentToken then
        local parent = ex:GetModuleFromToken(self.parentToken)
        return parent and parent:IsEnabled() or false
    end
    return self.token == "More"
        or self.token == "Config"
        or self.token == "Cache"
        or self.token == "Modules"
        or self.token == "ItemSlots"
        or not ex.cfg
        or type(ex.cfg.disabledModules) ~= "table"
        or ex.cfg.disabledModules[self.token] ~= true
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
                AzDropDown:ToggleMenu(self, "TOPLEFT", "BOTTOMLEFT")
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
    gtt:SetPoint("BOTTOMLEFT", self, "TOPLEFT")
    gtt:ClearLines()
    gtt:AddLine(module.title)
    if module.help then
        gtt:AddLine(module.help, 1, 1, 1, true)
    end
    local active = ex.modules[ex.cfg.activePage]
    if module.token == "More" and active and active.token == "Cache" then
        gtt:AddLine(ExaminerNS.L["Right-click: filter, sort, or delete saved players."], 1, 1, 1, true)
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
    end
end

-- Rebuild visible tabs and fit their localized labels.
function ex:RefreshModuleButtons()
    local count = 0
    for _, module in ipairs(self.modules) do
        module.button = nil
    end
    for _, module in ipairs(self.modules) do
        if module.hasButton and module:IsEnabled() then
            count = count + 1
            local button = self.buttons[count] or CreateModuleButton()
            button:ClearAllPoints()
            if count == 1 then
                button:SetPoint("BOTTOMLEFT", 24, 13)
            else
                button:SetPoint("LEFT", self.buttons[count - 1], "RIGHT", 1, 0)
            end
            button.id = module.index
            module.button = button
            button:SetText(module.buttonLabel or ExaminerNS.L[module.token])
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
            button:SetWidth(width)
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
    self.showItems = (not full or nil)
    return page
end
