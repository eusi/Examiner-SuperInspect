--------------------------------------------------------------------------------------------------------
--
-- Examiner.lua
-- Creates the inspection window and coordinates its core controls and events.
--
----------------------

--------------------------------------------------------------------------------------------------------
--                                    Variables And Configuration                                     --
--------------------------------------------------------------------------------------------------------

local _, ExaminerNS = ...
if ExaminerNS.blocked then
    return
end
local gtt = GameTooltip
local Compat = ExaminerNS.Compat
local GetItemInfo = Compat.GetItemInfo
local GetItemQualityColor = Compat.GetItemQualityColor
local GetDetailedItemLevelInfo = Compat.GetDetailedItemLevelInfo
local GetAddOnMetadata = Compat.GetAddOnMetadata
local GetAddOnMemoryUsage = Compat.GetAddOnMemoryUsage
local UpdateAddOnMemoryUsage = Compat.UpdateAddOnMemoryUsage
local UnitPVPName = Compat.UnitPVPName
local GetQuestDifficultyColor = Compat.GetQuestDifficultyColor

-- CREATE EXAMINER FRAME

local modName = ...
local ex = CreateFrame("Frame", modName, UIParent)
ExaminerNS.ex = ex
ex.Compat = Compat
Examiner = ex

-- Print an addon message with the supported color markers.
function AzMsg(msg)
    DEFAULT_CHAT_FRAME:AddMessage(
        tostring(msg):gsub("|1", "|cffffff80"):gsub("|2", "|cffffffff"),
        0.5,
        0.75,
        1.0
    )
end

-- LOCAL SAVED TABLES

local cfg, cache

-- LIBS

local LibFroznFunctions = LibStub("LibFroznFunctions-1.0", true)
if not LibFroznFunctions then
    print("Warning: LibFroznFunctions not available.")
    return
end

-- DATA TABLES

local info = { Sets = {}, Items = {}, Runes = {} }
local unitStats = {}
local statTipStats1, statTipStats2 = {}, {}
ex.compareStats = {}
ex.unitStats = unitStats
ex.info = info

-- MISC CONSTANTS

local HOOK_DEFAULT_INSPECT = Compat.isEra or Compat.isTBC
local CLASSIFICATION_NAMES = {
    worldboss = BOSS,
    rareelite = ITEM_QUALITY3_DESC .. ELITE,
    elite = ELITE,
    rare = ITEM_QUALITY3_DESC,
}

-- COLORS

local CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS

-- TEXTURE MAPPING

local TALENT_BACKGROUNDS = {
    "DeathKnightBlood",
    "DeathKnightFrost",
    "DeathKnightUnholy",
    "DruidBalance",
    "DruidFeralCombat",
    "DruidRestoration",
    "HunterBeastMastery",
    "HunterMarksmanship",
    "HunterSurvival",
    "MageArcane",
    "MageFire",
    "MageFrost",
    "PaladinCombat",
    "PaladinHoly",
    "PaladinProtection",
    "PriestDiscipline",
    "PriestHoly",
    "PriestShadow",
    "RogueAssassination",
    "RogueCombat",
    "RogueSubtlety",
    "ShamanElementalCombat",
    "ShamanEnhancement",
    "ShamanRestoration",
    "WarlockCurses",
    "WarlockDestruction",
    "WarlockSummoning",
    "WarriorArms",
    "WarriorFury",
    "WarriorProtection",
}

-- OPTIONS

ex.options = {
    {
        var = "makeMovable",
        default = true,
        label = ExaminerNS.L["Make Examiner Movable"],
        tip = ExaminerNS.L["Lets you drag the window to a different position."],
    },
    {
        var = "autoInspect",
        default = true,
        label = ExaminerNS.L["Auto Inspect on Target Change"],
        tip = ExaminerNS.L["Automatically inspects new targets while Examiner is open."],
    },
    {
        var = "clearInspectOnHide",
        default = true,
        label = ExaminerNS.L["Clear Inspect Data on Hide"],
        tip = ExaminerNS.L["Clears the current inspection when Examiner closes."],
    },

    {
        var = "combineAdditiveStats",
        default = true,
        label = ExaminerNS.L["Combine Additive Stats"],
        tip = ExaminerNS.L["Combines gear bonuses without including base character stats."],
    },
    {
        var = "tooltipSmartAnchor",
        default = false,
        label = ExaminerNS.L["Smart Tooltip Anchor"],
        tip = ExaminerNS.L["Shows item tooltips beside Examiner instead of beside each item."],
    },
}

-- BINDING NAME

BINDING_HEADER_EXAMINER = modName
BINDING_NAME_EXAMINER_OPEN = ExaminerNS.L["Open Examiner"]
BINDING_NAME_EXAMINER_TARGET = "Ex: " .. INSPECT .. " " .. TARGET
BINDING_NAME_EXAMINER_MOUSEOVER = ExaminerNS.L["Inspect mouseover"]
BINDING_NAME_EXAMINER_SELF = ExaminerNS.L["Inspect yourself"]

UIPanelWindows[modName] = { area = "left", pushable = 1, whileDead = 1 }
-- Allow Escape to close the window.
UISpecialFrames[#UISpecialFrames + 1] = modName

--------------------------------------------------------------------------------------------------------
--                                          Examiner Scripts                                          --
--------------------------------------------------------------------------------------------------------

-- Register a persistent announcement with the native, automatically sized popup system.
local appearanceNoticeKey = modName .. "_APPEARANCE_107"
StaticPopupDialogs[appearanceNoticeKey] = {
    text = "Examiner 1.0.7\n\n" .. ExaminerNS.F("New styles and icon menus are available! The menu has been switched to bottom icons. You can change it at any time and find more options under %s > %s.",
        ExaminerNS.L["More"], ExaminerNS.L["Settings"]),
    button1 = OKAY,
    -- Remember acknowledgement only when the player presses OK.
    OnAccept = function(self, savedConfig)
        savedConfig.appearanceNotice107Acknowledged = true
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
}

-- Apply the one-time menu migration and explain it when the window first opens.
local function Examiner_OnShow(self)
    if cfg then
        if not cfg.appearanceMenu107Migrated then
            ExaminerNS.Appearance.Select("menuStyle", "iconsBottom")
            cfg.appearanceMenu107Migrated = true
        end
        if not cfg.appearanceNotice107Acknowledged and not StaticPopup_Visible(appearanceNoticeKey) then
            StaticPopup_Show(appearanceNoticeKey, nil, nil, cfg)
        end
    end
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("UNIT_MODEL_CHANGED")
    self:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED")
    self:RegisterEvent("MODIFIER_STATE_CHANGED")
end

-- Stop inspection work and apply the clear-on-hide setting.
local function Examiner_OnHide(self)
    ExaminerNS.Inspector:Cancel()
    self:SendModuleEvent("OnInspectHidden")
    self.model.isRotating = nil
    self.model.isPanning = nil
    self:UnregisterEvent("INSPECT_READY")
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("UNIT_MODEL_CHANGED")
    self:UnregisterEvent("UNIT_PORTRAIT_UPDATE")
    self:UnregisterEvent("UNIT_INVENTORY_CHANGED")
    self:UnregisterEvent("MODIFIER_STATE_CHANGED")
    if cfg.clearInspectOnHide then
        ex:ClearInspect()
    else
        self:SetScript("OnUpdate", nil)
    end
end

-- Retry inspection when the player comes within range.
local function Examiner_OnUpdate(self, elapsed)
    if (self:ValidateUnit()) and (CheckInteractDistance(self.unit, 3)) then
        self:DoInspect(self.unit)
    end
end

--------------------------------------------------------------------------------------------------------
--                                           Event Handling                                           --
--------------------------------------------------------------------------------------------------------

-- Clamp saved scale values to the supported range.
local function WindowScale(value)
    if not Compat.IsNumber(value) or value ~= value or value <= 0 or value == math.huge then
        return 1
    end
    return math.max(0.75, math.min(1.50, math.floor(value * 100 + 0.5) / 100))
end

-- Apply and save a validated window scale.
function ex:SetWindowScale(value)
    if not Compat.IsNumber(value) or value ~= value or value <= 0 or value == math.huge then
        return
    end
    cfg.scale = WindowScale(value)
    self:SetScale(cfg.scale)
    self:SendModuleEvent("OnConfigChanged", "scale", cfg.scale)
end

-- Restore preferences, initialize modules and validate the saved page.
function ex:VARIABLES_LOADED(event)
    -- CONFIG

    if type(_G[ExaminerNS.configKey]) ~= "table" then
        _G[ExaminerNS.configKey] = {}
    end
    cfg = _G[ExaminerNS.configKey]
    if type(cfg.caching) ~= "table" then
        -- Apply defaults only before cache preferences have been saved.
        cfg.caching = { Core = true, Talents = false, PvP = false, Guild = false, Glyphs = false, Professions = false }
    end
    self.cfg = cfg
    ExaminerNS.Appearance.Normalize(cfg)
    if cfg.itemLevelSource ~= "blizzard" then
        cfg.itemLevelSource = "calculated"
    end
    ExaminerNS.Fonts.NormalizeSelection(cfg)
    if type(cfg.disabledModules) ~= "table" then
        cfg.disabledModules = {}
    end
    cfg.disabledModules.Config = nil
    cfg.disabledModules.Cache = nil
    cfg.disabledModules.Modules = nil
    cfg.disabledModules.Glyphs = nil
    -- LOAD DEFAULTS

    if cfg.showBackground == nil then
        cfg.showBackground = true
    end
    for _, option in ipairs(self.options) do
        if cfg[option.var] == nil then
            cfg[option.var] = option.default
        end
    end
    -- CACHE

    if type(_G[ExaminerNS.cacheKey]) ~= "table" then
        _G[ExaminerNS.cacheKey] = {}
    end
    cache = _G[ExaminerNS.cacheKey]
    self.cache = cache
    ExaminerNS.Cache.Initialize(self)
    Compat.RestorePage(cfg, self.modules)
    -- WINDOW STATE

    self:ShowBackground()
    cfg.scale = WindowScale(cfg.scale)
    self:SetScale(cfg.scale)
    self:SetMovable(cfg.makeMovable)
    if cfg.makeMovable and Compat.IsNumber(cfg.left) and Compat.IsNumber(cfg.bottom) then
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", cfg.left, cfg.bottom)
    end
    -- LEGACY INSPECT HOOK

    if HOOK_DEFAULT_INSPECT then
        -- Route the legacy inspect entry point through Examiner.
        InspectUnit = function(...)
            ex:DoInspect(...)
        end
    end
    -- INIT MODULES

    for index, mod in ipairs(self.modules) do
        if mod.OnInitialize then
            mod:OnInitialize()
            mod.OnInitialize = nil
        end
    end
    -- Is active page valid?
    for _, module in ipairs(self.modules) do
        if not module:IsEnabled() then
            if module.OnInspectHidden then
                module:OnInspectHidden()
            end
            if module.OnClearInspect then
                module:OnClearInspect()
            end
        end
    end
    self:RefreshModuleButtons()
    ExaminerNS.Appearance.Apply()
    if cfg.activePage and self.modules[cfg.activePage] and not self.modules[cfg.activePage]:IsEnabled() then
        cfg.activePage = nil
        cfg.activePageToken = nil
    end
    if cfg.activePage and (not self.modules[cfg.activePage] or not self.modules[cfg.activePage].page) then
        cfg.activePage = nil
    end
    -- MODULE SETTINGS

    for _, option in ipairs(self.options) do
        self:SendModuleEvent("OnConfigChanged", option.var, cfg[option.var])
    end

    ExaminerNS.Fonts.Refresh(self)
    self:UnregisterEvent(event)
    self[event] = nil
end

-- Follow target changes while automatic inspection is enabled.
function ex:PLAYER_TARGET_CHANGED(event)
    if cfg.autoInspect and (UnitExists("target")) then
        self:DoInspect("target")
    elseif self.unit == "target" then
        ExaminerNS.Inspector:Cancel()
        self.unit = nil
        self:SetScript("OnUpdate", nil)
    end
end

-- Cancel inspection when its temporary mouseover unit changes.
function ex:UPDATE_MOUSEOVER_UNIT(event)
    ExaminerNS.Inspector:Cancel()
    self.unit = nil
    self:SetScript("OnUpdate", nil)
    self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
end

-- Refresh the model when the inspected unit changes appearance.
function ex:UNIT_MODEL_CHANGED(event, unit)
    if unit and self:ValidateUnit() and UnitIsUnit(unit, self.unit) then
        self.model:SetUnit(self.unit)
        SetPortraitTexture(self.portrait, self.unit)
    end
end
ex.UNIT_PORTRAIT_UPDATE = ex.UNIT_MODEL_CHANGED

-- Refresh equipment for the inspected unit.
function ex:UNIT_INVENTORY_CHANGED(event, unit)
    ExaminerNS.Inspector:InventoryChanged(unit)
end

-- Update item-level overlays when modifier keys change.
function ex:MODIFIER_STATE_CHANGED(event)
    if self.tooltipSlot then
        local onEnterFunc = self.tooltipSlot:GetScript("OnEnter")
        if onEnterFunc then
            onEnterFunc(self.tooltipSlot)
        end
    end
end

-- Forward the server reply to the active inspection session.
function ex:INSPECT_READY(event, guid)
    ExaminerNS.Inspector:Ready(guid)
end

-- Forward newly available honor data to its consumer.
function ex:INSPECT_HONOR_UPDATE(event)
    local session = ExaminerNS.Inspector.active
    if
        session
        and ExaminerNS.Inspector:Valid(session)
        and session.serverReady
        and (self.isSelf or ExaminerNS.Inspector.notificationGUID == session.guid)
    then
        session.honorReady = true
        self:SendModuleEvent("OnHonorReady")
        self:CachePlayer()
    end
end

-- Forward newly available achievement comparison data.
function ex:INSPECT_ACHIEVEMENT_READY(event, guid)
    if AchievementFrameComparison then
        AchievementFrameComparison:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
    end
    self:UnregisterEvent("INSPECT_ACHIEVEMENT_READY")
    self:SendModuleEvent("OnAchievementReady", self.unit, guid)
end

--------------------------------------------------------------------------------------------------------
--                                        Model Frame Scripts                                         --
--------------------------------------------------------------------------------------------------------

-- MODEL FRAME WORKAROUND

-- Restore the displayed model when its frame becomes visible.
local function Model_OnShow(self)
    if self.cleared then
        self:ClearModel()
    end
end

-- Apply model rotation and panning while dragging.
local function Model_OnUpdate(self, elapsed)
    if self.isRotating then
        local endx, endy = GetCursorPosition()
        self.rotation = (endx - self.startx) / 34 + self:GetFacing()
        self:SetFacing(self.rotation)
        self.startx, self.starty = GetCursorPosition()
    elseif self.isPanning then
        local endx, endy = GetCursorPosition()
        local z, x, y = self:GetPosition(z, x, y)
        x = (endx - self.startx) / 45 + x
        y = (endy - self.starty) / 45 + y
        self:SetPosition(z, x, y)
        self.startx, self.starty = GetCursorPosition()
    end
end

-- Zoom the character model within its supported limits.
local function Model_OnMouseWheel(self, delta)
    local z, x, y = self:GetPosition()
    local scale = (IsControlKeyDown() and 2 or 0.7)
    z = (delta > 0 and z + scale or z - scale)
    self:SetPosition(z, x, y)
end

-- Start model manipulation or apply its modifier shortcuts.
local function Model_OnMouseDown(self, button)
    self.startx, self.starty = GetCursorPosition()
    if button == "LeftButton" then
        self.isRotating = true
        if IsControlKeyDown() then
            ex:SetBackgroundTexture(true)
        end
    elseif button == "RightButton" then
        self.isPanning = true
        if IsControlKeyDown() then
            cfg.showBackground = not cfg.showBackground
            ex:ShowBackground()
        end
    end
end

-- Stop rotating or panning the model.
local function Model_OnMouseUp(self, button)
    if button == "LeftButton" then
        self.isRotating = nil
    elseif button == "RightButton" then
        self.isPanning = nil
    end
end

--------------------------------------------------------------------------------------------------------
--                                           Init Examiner                                            --
--------------------------------------------------------------------------------------------------------

-- EXAMINER MAIN FRAME

ex:SetSize(384, 440)
ex:SetPoint("CENTER")
ex:EnableMouse(true)
ex:SetToplevel(true)
ex:Hide()
ex:SetHitRectInsets(12, 35, 10, 2)
ex:SetScript("OnShow", Examiner_OnShow)
ex:SetScript("OnHide", Examiner_OnHide)
-- Dispatch the relevant client event to its inspection handler.
ex:SetScript("OnEvent", function(self, event, ...)
    self[event](self, event, ...)
end)

-- Start dragging the movable window.
ex:SetScript("OnMouseDown", function(self, button)
    if self:IsMovable() then
        self:StartMoving()
    end
end)

-- Finish dragging and commit the pending interaction.
ex:SetScript("OnMouseUp", function(self, button)
    if self:IsMovable() then
        self:StopMovingOrSizing()
        cfg.left = self:GetLeft()
        cfg.bottom = self:GetBottom()
    end
end)

-- EVENTS

ex:RegisterEvent("VARIABLES_LOADED")

-- CLOSE BUTTON

ex.close = CreateFrame("Button", nil, ex, "UIPanelCloseButton")
ex.close:SetPoint("TOPRIGHT", -34, -12)

-- PORTRAIT

ex.portrait = ex:CreateTexture(nil, "BACKGROUND")
ex.portrait:SetSize(60, 60)
ex.portrait:SetPoint("TOPLEFT", 7, -6)

-- FONTSTRINGS

ex.title = ExaminerNS.Fonts.Create(ex, nil, "ARTWORK", "GameFontNormal")
ex.title:SetPoint("TOP", 5, -17)
ex.details = ExaminerNS.Fonts.Create(ex, nil, "ARTWORK", "GameFontHighlightSmall")
ex.details:SetPoint("TOP", 5, -44)
ex.guild = ExaminerNS.Fonts.Create(ex, nil, "ARTWORK", "GameFontHighlightSmall")
ex.guild:SetPoint("TOP", ex.details, "BOTTOM", 0, -2)

-- DIALOG TEXTURES

ex.dlgTopLeft = ex:CreateTexture(nil, "ARTWORK")
ex.dlgTopLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
ex.dlgTopLeft:SetPoint("TOPLEFT")
ex.dlgTopLeft:SetSize(256, 256)
ex.dlgTopRight = ex:CreateTexture(nil, "ARTWORK")
ex.dlgTopRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight")
ex.dlgTopRight:SetPoint("TOPRIGHT")
ex.dlgTopRight:SetSize(128, 256)
ex.dlgBottomLeft = ex:CreateTexture(nil, "ARTWORK")
ex.dlgBottomLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft")
ex.dlgBottomLeft:SetPoint("TOPLEFT", 0, -256)
ex.dlgBottomLeft:SetSize(256, 256)
ex.dlgBottomRight = ex:CreateTexture(nil, "ARTWORK")
ex.dlgBottomRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight")
ex.dlgBottomRight:SetPoint("TOPRIGHT", 0, -256)
ex.dlgBottomRight:SetSize(128, 256)

-- Background Textures -- Resize height, so they go beneath module buttons
local bgScale = 1.064
ex.bgTopLeft = ex:CreateTexture(nil, "OVERLAY")
ex.bgTopLeft:SetPoint("TOPLEFT", 21, -76)
ex.bgTopLeft:SetHeight(256 * bgScale)
ex.bgTopRight = ex:CreateTexture(nil, "OVERLAY")
ex.bgTopRight:SetPoint("LEFT", ex.bgTopLeft, "RIGHT")
ex.bgTopRight:SetHeight(256 * bgScale)
ex.bgBottomLeft = ex:CreateTexture(nil, "OVERLAY")
ex.bgBottomLeft:SetPoint("TOP", ex.bgTopLeft, "BOTTOM")
ex.bgBottomLeft:SetHeight(128 * bgScale)
ex.bgBottomRight = ex:CreateTexture(nil, "OVERLAY")
ex.bgBottomRight:SetPoint("LEFT", ex.bgBottomLeft, "RIGHT")
ex.bgBottomRight:SetHeight(128 * bgScale)

-- MODEL

ex.model = CreateFrame("PlayerModel", nil, ex)
ex.model:SetSize(320, 354)
ex.model:SetPoint("BOTTOM", -11, 10)
ex.model:EnableMouse(true)
ex.model:EnableMouseWheel(true)
ex.model:SetScript("OnShow", Model_OnShow)
ex.model:SetScript("OnUpdate", Model_OnUpdate)
ex.model:SetScript("OnMouseDown", Model_OnMouseDown)
ex.model:SetScript("OnMouseUp", Model_OnMouseUp)
ex.model:SetScript("OnMouseWheel", Model_OnMouseWheel)

--------------------------------------------------------------------------------------------------------
--                                            Unit Details                                            --
--------------------------------------------------------------------------------------------------------

local uDetails = {}

-- Build the player level, race and class summary.
function ex:SetUnitDetailString()
    -- LEVEL

    local color = GetQuestDifficultyColor(info.level ~= -1 and info.level or 500)
    uDetails[#uDetails + 1] = format(
        "%s |cff%.2x%.2x%.2x%s|r",
        LEVEL,
        color.r * 255,
        color.g * 255,
        color.b * 255,
        (info.level ~= -1 and info.level or "??")
    )
    -- Classification (non players only, so ok to use ex.unit)
    if not info.raceFixed then
        local classification = UnitClassification(ex.unit)
        if CLASSIFICATION_NAMES[classification] then
            uDetails[#uDetails + 1] = "(" .. CLASSIFICATION_NAMES[classification] .. ")"
        end
    end
    -- Race for Players / Family or Type for NPC's
    if info.race then
        uDetails[#uDetails + 1] = (info.race ~= "Not specified" and info.race or UNKNOWN)
    end
    -- Players Only: Class (+ Realm)
    if info.raceFixed then
        if info.class then
            local color = CLASS_COLORS[info.classFixed] or { r = 1, g = 1, b = 1 }
            uDetails[#uDetails + 1] =
                format("|cff%.2x%.2x%.2x%s|r", color.r * 255, color.g * 255, color.b * 255, info.class)
        end
        if info.realm then
            uDetails[#uDetails + 1] = "[" .. info.realm .. "]"
        end
    end
    -- SET RESULT

    self.details:SetText(table.concat(uDetails, " "))
    wipe(uDetails)
end

-- Display the inspected player guild and rank.
function ex:SetUnitGuildString()
    -- INIT AS EMPTY

    self.guild:SetText("")
    -- PLAYERS

    if info.raceFixed then
        if info.guild then
            self.guild:SetFormattedText(
                "%s%s<%s>",
                info.guildRank or "",
                info.guildRank and info.guildRank ~= "" and ExaminerNS.L[" of "] or "",
                info.guild
            )
        end
    -- NPC's only, so ok to use 'ex.unit' here
    else
        LibGearExamTip:ClearLines()
        LibGearExamTip:SetUnit(ex.unit)
        local line
        for i = 2, LibGearExamTip:NumLines() - 1 do
            line = _G["LibGearExamTipTextLeft" .. i]:GetText()
            if line and TOOLTIP_UNIT_LEVEL and line:find("^" .. TOOLTIP_UNIT_LEVEL:gsub("%%s", ".+")) then
                line = _G["LibGearExamTipTextLeft" .. (i + 1)]:GetText()
                if line ~= PVP_ENABLED then
                    self.guild:SetText(line)
                    return
                end
            end
        end
    end
end

-- Build the realm-qualified cache key for this player.
function ex:GetEntryName()
    return (info.realm and info.name .. "-" .. info.realm or info.name)
end

--------------------------------------------------------------------------------------------------------
--                                          Cache Functions                                           --
--------------------------------------------------------------------------------------------------------

-- Save the current inspection when caching permits it.
function ex:CachePlayer(override)
    return ExaminerNS.Cache.Store(self, override)
end

-- Restore a saved player through the cache service.
function ex:LoadPlayerFromCache(entryName)
    return ExaminerNS.Cache.Load(self, entryName)
end

--------------------------------------------------------------------------------------------------------
--                                         Inspect Functions                                          --
--------------------------------------------------------------------------------------------------------

-- Check whether a unit can be inspected on this client.
function ex:CanInspect(unit)
    return ExaminerNS.Inspector:CanInspect(unit)
end

-- Open or close Examiner using the configured window behavior.
function ex:Display(state)
    state = (state == nil and true or state)
    if not state then
        HideUIPanel(self)
    elseif cfg.makeMovable then
        self:Show()
    else
        ShowUIPanel(self)
    end
end

-- Show the compact view for a non-player unit.
function ex:OpenSimple()
    if not info.name then
        self:DoInspect("player")
    else
        self:Display(not self:IsVisible())
    end
end

-- Inspect a hovered player without changing the target.
function ex:InspectMouseover()
    local unit = "mouseover"

    -- Tooltip tokens also cover unit frames whose mouseover token is not updated yet.
    if GameTooltip and GameTooltip:GetUnit() then
        local tooltipUnit = select(2, GameTooltip:GetUnit())
        if tooltipUnit and UnitExists(tooltipUnit) then
            unit = tooltipUnit
        end
    end

    if UnitExists(unit) then
        self:DoInspect(unit)
    end
end

-- Clear the active inspection and its module data.
function ex:ClearInspect()
    ExaminerNS.Inspector:Clear()
end

-- Pass the completed inspection to the active session.
function ex:InspectReady(guid)
    ExaminerNS.Inspector:Ready(guid)
end

-- Resolve a stable unit token for an inspected player.
local function UnitToStaticUnit(unit)
    local count = GetNumGroupMembers()
    if count and (count > 0) then
        local isRaid = IsInRaid()
        for i = 1, count do
            local static = (isRaid and "raid" or "party") .. i
            if UnitIsUnit(unit, static) then
                return static
            end
        end
    end
end

-- Start a validated player inspection.
function ex:DoInspect(unit, openFlag)
    return ExaminerNS.Inspector:Start(unit, openFlag)
end

-- Refresh equipment through the inspection service.
function ex:ScanGear(unit)
    local session = ExaminerNS.Inspector.active
    if session and session.unit == unit then
        ExaminerNS.Inspector:Refresh(session)
    end
end

--------------------------------------------------------------------------------------------------------
--                                       Additional Inspection                                        --
--------------------------------------------------------------------------------------------------------

-- Request honor details for the current inspection.
function ex:RequestHonorData()
    local session = ExaminerNS.Inspector.active
    if not session or session.cached or not ExaminerNS.Inspector:Valid(session) then
        return
    end
    if not self.isSelf and not session.serverReady then
        return
    end
    self:RegisterEvent("INSPECT_HONOR_UPDATE")
    if
        (Compat.isRetail or Compat.isForever)
        and (type(RequestInspectHonorData) ~= "function" or type(HasInspectHonorData) ~= "function")
    then
        session.honorReady = true
        return
    end
    if type(RequestInspectHonorData) ~= "function" then
        return
    end
    if self.requestedHonorData then
        return
    end
    self.requestedHonorData = true
    Compat.Try(RequestInspectHonorData)
end

-- Request achievement details for the current inspection.
function ex:RequestAchievementData()
    if self.requestedAchievementData then
        return
    end
    -- Makes the Achievement UI, if loaded, not update when we query the achievements
    if achievementFunctions and (type(achievementFunctions.selectedCategory) == "string") then
        achievementFunctions.selectedCategory = 92
    end
    if AchievementFrameComparison then
        AchievementFrameComparison:UnregisterEvent("INSPECT_ACHIEVEMENT_READY")
    end
    -- REQUEST

    self.requestedAchievementData = true
    self:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
    SetAchievementComparisonUnit(self.unit)
end

--------------------------------------------------------------------------------------------------------
--                                          Helper Functions                                          --
--------------------------------------------------------------------------------------------------------

-- Round a number to the requested precision.
function round(num)
    return math.floor(num + 0.5)
end

-- Format elapsed time using localized units.
function ex:FormatTime(time, short)
    time = math.floor(Compat.Number(time, 0))
    if time < 0 then
        return "n/a"
    -- UNDER A MIN
    elseif time < 60 then
        return time .. (short and "s" or ExaminerNS.L[" seconds"])
    -- LESS THAN 1 HOUR
    elseif time < 60 * 60 then
        return format(
            short and "%dm %.2ds" or ExaminerNS.L["%d minutes and %.2d seconds"],
            math.floor(time / 60),
            time % 60
        )
    -- LESS THAN 1 DAY
    elseif time < 60 * 60 * 24 then
        time = math.floor(time / 60)
        return format(
            short and "%dh %.2dm" or ExaminerNS.L["%d hours and %.2d minutes"],
            math.floor(time / 60),
            time % 60
        )
    -- ABOVE 1 DAY
    else
        time = math.floor(time / 60 / 60)
        return format(
            short and "%dd %.2dh" or ExaminerNS.L["%d days and %.2d hours"],
            math.floor(time / 24),
            time % 24
        )
    end
end

-- Set or clear the reference player for gear comparisons.
function ex:CacheStatsForCompare(unmark)
    wipe(self.compareStats)
    if unmark then
        self.isComparing = nil
    elseif self.itemsLoaded then
        self.isComparing = true
        self.compareStats.entry = self:GetEntryName()
        for key, value in pairs(self.unitStats) do
            self.compareStats[key] = value
        end
        for slot, link in pairs(self.info.Items) do
            self.compareStats[slot] = link
        end
    end
    self:SendModuleEvent("OnCompare", self.isComparing, self.compareStats)
end

-- Tint the window to reflect inspection status.
function ex:SetBackgroundVertex(r, g, b, a)
    self.dlgTopLeft:SetVertexColor(r, g, b, a)
    self.dlgTopRight:SetVertexColor(r, g, b, a)
    self.dlgBottomLeft:SetVertexColor(r, g, b, a)
    self.dlgBottomRight:SetVertexColor(r, g, b, a)
end

-- Apply the saved background visibility.
function ex:ShowBackground(show)
    show = show or (show == nil and cfg.showBackground)
    ex.bgTopLeft:SetShown(show)
    ex.bgTopRight:SetShown(show)
    ex.bgBottomLeft:SetShown(show)
    ex.bgBottomRight:SetShown(show)
    if cfg.style ~= "classic" then ExaminerNS.Appearance.UpdateBackground() end
end

-- Refresh player labels, portrait and equipment controls.
function ex:UpdateObjects()
    -- TEXTURES & MODEL

    if ex.unit and Compat.IsTrue(UnitIsVisible(ex.unit)) then
        SetPortraitTexture(ex.portrait, ex.unit)
        if ex.unitType == 1 then
            ex.model:ClearModel()
        end
        ex.model:SetUnit(ex.unit)
        ex.model.cleared = nil
    else
        local genderRace = (info.sex == 3 and "Female" or "Male") .. "-" .. (info.raceFixed or "")
        ex.portrait:SetTexture("Interface\\CharacterFrame\\TemporaryPortrait-" .. genderRace)
        ex.model:ClearModel()
        ex.model.cleared = true
    end
    ex:SetBackgroundTexture()
    -- Title, Detail & Guild Text
    ex.title:SetText(info.pvpName or info.name)
    ex:SetUnitDetailString()
    ex:SetUnitGuildString()
    ExaminerNS.Appearance.UpdatePortrait()
end

-- Display the selected available module page.
function ex:ShowModulePage(index)
    local requested = index and self.modules[index]
    if requested and requested.parentToken then
        local parent = self:GetModuleFromToken(requested.parentToken)
        if not parent or not parent:IsEnabled() or not requested:IsEnabled() then
            return
        end
        if parent.OnPageOpen then
            parent:OnPageOpen()
        end
        if cfg.activePage == parent.index then
            parent:Draw()
            parent.page:Show()
            return
        end
        index, requested = parent.index, parent
    end
    if index and (not requested or not requested:IsEnabled()) then
        return
    end
    if requested and requested.OnPageOpen then
        requested:OnPageOpen()
    end
    if
        not index
        and cfg.activePage
        and self.modules[cfg.activePage]
        and not self.modules[cfg.activePage]:IsEnabled()
    then
        cfg.activePage = nil
        cfg.activePageToken = nil
    end
    if requested and requested.isPopup then
        requested:TogglePopup()
        return
    end
    if cfg.activePage and self.modules[cfg.activePage] and self.modules[cfg.activePage].isPopup then
        cfg.activePage = nil
        cfg.activePageToken = nil
    end
    -- HIDE CURRENT PAGE

    local lastMod = ex.modules[cfg.activePage]
    if lastMod then
        lastMod.page:Hide()
    end
    -- WHEN WE HAVE A NEW INDEX

    if index then
        -- SAVE OLD PAGE

        if cfg.activePage then
            cfg.prevPage = cfg.activePage
        end
        -- TOGGLE PAGE

        if index == cfg.activePage then
            self:SendModuleEvent("OnPageChanged", lastMod, false)
            cfg.activePage = nil
        else
            cfg.activePage = index
        end
    end
    cfg.activePageToken = cfg.activePage and self.modules[cfg.activePage].token or nil
    -- SHOW ACTIVE PAGE

    if cfg.activePage then
        local shownMod = ex.modules[cfg.activePage]
        if shownMod.hasData then
            shownMod.page:Show()
        else
            shownMod.page:Hide()
        end
        self:SendModuleEvent("OnPageChanged", shownMod, true)
    end
    ExaminerNS.Appearance.UpdateSelection()
end

-- Choose the character background and its texture coordinates.
function ex:SetBackgroundTexture(param)
    local texture
    -- FIND TEXTURE

    if type(param) == "string" then
        texture = param
    elseif (param == true) or not info.raceFixed then
        texture = "Interface\\TalentFrame\\" .. TALENT_BACKGROUNDS[random(#TALENT_BACKGROUNDS)] .. "-"
    else
        param = (info.raceFixed == "Gnome" and "Dwarf")
            or (info.raceFixed == "Troll" and "Orc")
            or info.raceFixed
        texture = "Interface\\DressUpFrame\\DressUpBackground-" .. param
    end
    -- SET TEXTURE

    local normal = texture:find("DressUpFrame")
    ex.bgTopLeft:SetTexture(texture .. (normal and "1" or "TopLeft"))
    ex.bgTopRight:SetTexture(texture .. (normal and "2" or "TopRight"))
    ex.bgBottomLeft:SetTexture(texture .. (normal and "3" or "BottomLeft"))
    ex.bgBottomRight:SetTexture(texture .. (normal and "4" or "BottomRight"))
    -- Set Texture Width -- Scaled about 1.063 for the talent frame textures
    local scale = (normal and 1 or 1.063)
    ex.bgTopLeft:SetWidth(256 * scale)
    ex.bgTopRight:SetWidth(64 * scale)
    ex.bgBottomLeft:SetWidth(256 * scale)
    ex.bgBottomRight:SetWidth(64 * scale)
end

-- Verify that the unit still represents the inspected player.
function ex:ValidateUnit()
    if not self.unit or not Compat.IsTrue(UnitExists(self.unit)) then
        return false
    end
    local guid = UnitGUID(self.unit)
    return Compat.IsString(guid) and guid == self.guid
end

--------------------------------------------------------------------------------------------------------
--                                   Widget Script Helper Functions                                   --
--------------------------------------------------------------------------------------------------------

-- Hide the shared tooltip after leaving a control.
function ex.HideGTT(self)
    gtt:Hide()
end

-- Handle equipment links and supported item shortcuts.
function ex.ItemButton_OnClick(self, button)
    if self.link then
        if button == "RightButton" then
            -- Get Examiner item link and player item link
            local _, ExaminerItemLink = GetItemInfo(self.link)
            local PlayerItemslotId = self.id
            local PlayerItemLink = GetInventoryItemLink("player", PlayerItemslotId)
            local itemStats1, itemStats2 = {}, {}
            LibGearExam:ScanItemLink(ExaminerItemLink, itemStats1)
            LibGearExam:ScanItemLink(PlayerItemLink, itemStats2)
            -- COMPARE BOTH ITEMS

            if not (PlayerItemLink == nil) then
                AzMsg(ExaminerNS.F("Comparing %s with %s", ExaminerItemLink, PlayerItemLink))
                for statToken, statName in next, LibGearExam.StatNames do
                    if itemStats1[statToken] or itemStats2[statToken] then
                        local statText = LibGearExam:GetStatValue(
                            statToken,
                            itemStats1,
                            itemStats2,
                            UnitLevel("player"),
                            cfg.combineAdditiveStats,
                            cfg.percentRatings
                        )
                        AzMsg(format("%s = |1%s|r.", statName, statText))
                    end
                end
            else
                AzMsg(ExaminerNS.L["No equipped item in that slot."])
            end
        elseif button == "LeftButton" then
            local editBox = ChatEdit_GetActiveWindow()
            if IsModifiedClick("DRESSUP") then
                DressUpItemLink(itemLink)
            elseif (IsModifiedClick("CHATLINK")) and editBox and (editBox:IsVisible()) then
                editBox:Insert(itemLink)
            end
        end
    end
end

-- Hide the item tooltip and comparison tooltip.
function ex.ItemButton_OnLeave(self)
    ex.tooltipSlot = nil
    ResetCursor()
    gtt:Hide()
end

-- Show the equipped item and optional comparison tooltip.
function ex.ItemButton_OnEnter(self, motion)
    -- INSPECT CURSOR

    if IsModifiedClick("DRESSUP") then
        ShowInspectCursor()
    else
        ResetCursor()
    end

    -- Use the configured tooltip anchor.
    ex.tooltipSlot = self
    gtt:SetOwner(self, "ANCHOR_NONE")
    if cfg.tooltipSmartAnchor then
        gtt:SetPoint("TOPLEFT", ex, "TOPRIGHT", -34, -12)
    else
        gtt:SetPoint("TOPLEFT", self, "TOPRIGHT")
    end

    -- FILL IN TOOLTIP

    -- ITEMSTRING BREAKDOWN

    if self.link and (IsShiftKeyDown()) and (IsAltKeyDown()) then
        local itemName, _, itemRarity = GetItemInfo(self.link)
        local is = LibItemString:New(self.link)
        gtt:AddLine(itemName, GetItemQualityColor(itemRarity))
        for k, v in ipairs(is) do
            gtt:AddDoubleLine(format("|cffffffff%.2d|r %s", k, is:GetFieldName(k)), v, nil, nil, nil, 1, 1, 1)
        end
        gtt:Show()
    -- STAT BREAKDOWN /W COMPARE SUPPORT
    elseif self.link and (IsAltKeyDown()) then
        local itemName, _, itemRarity = GetItemInfo(self.link)
        gtt:AddLine(itemName, GetItemQualityColor(itemRarity))
        LibGearExam:ScanItemLink(self.link, statTipStats1)
        if ex.isComparing and self.slotName then
            LibGearExam:ScanItemLink(ex.compareStats[self.slotName], statTipStats2)
        end
        for index, statToken in ipairs(LibGearExam.StatNamesSorted) do
            if statTipStats1[statToken] or (statTipStats2 and statTipStats2[statToken]) then
                local statText = LibGearExam:GetStatValue(
                    statToken,
                    statTipStats1,
                    ex.isComparing and statTipStats2,
                    info.level,
                    cfg.combineAdditiveStats,
                    cfg.percentRatings
                )

                gtt:AddDoubleLine(
                    LibGearExam:FormatStatName(statToken, cfg.percentRatings),
                    statText,
                    nil,
                    nil,
                    nil,
                    1,
                    1,
                    1
                )
            end
        end
        wipe(statTipStats1)
        wipe(statTipStats2)
        gtt:Show()
    -- SET ITEM FROM UNIT
    elseif
        self.id
        and ex:ValidateUnit()
        and CheckInteractDistance(ex.unit, 3)
        and gtt:SetInventoryItem(ex.unit, self.id)
    then
    -- SET ITEM FROM LINK
    elseif self.link then
        gtt:SetHyperlink(self.link)
    -- no valid item available, so add text that we can reload cache to get item
    elseif self.realLink then
        gtt:SetText(_G[self.slotName:upper()])
        gtt:AddLine("ItemID: " .. self.realLink:match(LibGearExam.ITEMLINK_PATTERN_ID), 0, 0.44, 0.86)
        gtt:AddLine(ExaminerNS.L["Item data is not cached yet. Click to reload this player."], 1, 1, 1, 1)
        gtt:Show()
    -- EMPTY ITEM SLOT
    elseif self.slotName then
        gtt:SetText(_G[self.slotName:upper()])
    end
end

--------------------------------------------------------------------------------------------------------
--                                           Slash Handling                                           --
--------------------------------------------------------------------------------------------------------

-- Slash Commands -- Array indices are used for command help. Commands starting with underscore are meant for debugging
ex.slashCommands = {
    -- INSPECT UNIT

    " |2inspect <unit>|r = " .. ExaminerNS.L["Inspect the specified unit."],
    -- Inspect the requested unit from the slash command.
    inspect = function(cmd)
        ex:DoInspect(cmd == "" and "target" or cmd)
    end,
    -- SCAN A SINGLE ITEM

    " |2si <itemlink>|r = " .. ExaminerNS.L["Show an item's equipment stats."],
    -- Print the supplied item gear statistics.
    si = function(cmd)
        if cmd ~= "" then
            local itemStats = {}
            LibGearExam:ScanItemLink(cmd, itemStats)
            AzMsg(ExaminerNS.F("Scan overview: %s", cmd))
            for stat in next, itemStats do
                local statName = (
                    cfg.percentRatings and LibGearExam.StatNames[stat]
                    or LibGearExam.StatNames[stat] .. " " .. RATING
                )
                local statText, altText = LibGearExam:GetStatValue(
                    stat,
                    itemStats,
                    nil,
                    UnitLevel("player"),
                    cfg.combineAdditiveStats,
                    cfg.percentRatings
                )
                AzMsg(
                    format(altText and "%s = |1%s|r (|1%s|r)." or "%s = |1%s|r.", statName, statText, altText)
                )
            end
        else
            AzMsg(ExaminerNS.L["No item link given."])
        end
    end,
    -- COMPARES TWO ITEMS

    " |2compare <itemlink1> <itemlink2>|r = " .. ExaminerNS.L["Compare two items."],
    -- Print stat differences between two supplied item links.
    compare = function(cmd)
        if cmd ~= "" then
            local item1, item2 = cmd:match("(|c.+|r)%s+(|c.+|r)")
            if item1 and item2 then
                local itemStats1, itemStats2 = {}, {}
                LibGearExam:ScanItemLink(item1, itemStats1)
                LibGearExam:ScanItemLink(item2, itemStats2)
                AzMsg(ExaminerNS.F("Comparing %s with %s", item1, item2))
                for statToken, statName in next, LibGearExam.StatNames do
                    if itemStats1[statToken] or itemStats2[statToken] then
                        if not cfg.percentRatings then
                            statName = (statName .. " " .. RATING)
                        end
                        local statText = LibGearExam:GetStatValue(
                            statToken,
                            itemStats1,
                            itemStats2,
                            UnitLevel("player"),
                            cfg.combineAdditiveStats,
                            cfg.percentRatings
                        )
                        AzMsg(format("%s = |1%s|r.", statName, statText))
                    end
                end
            else
                AzMsg(ExaminerNS.L["Could not parse item links."])
            end
        else
            AzMsg(ExaminerNS.L["No item links given."])
        end
    end,
    -- RESET WINDOW POSITION

    " |2reset|r = " .. ExaminerNS.L["Reset the window position."],
    -- Center the movable Examiner window.
    reset = function(cmd)
        if cfg.makeMovable then
            ex:ClearAllPoints()
            ex:SetPoint("CENTER")
        else
            AzMsg(ExaminerNS.L["This command requires a movable window."])
        end
    end,
    -- SCALE

    " |2scale <value>|r = " .. ExaminerNS.L["Set window scale (default: 1.00)."],
    -- Apply a scale value from the slash command.
    scale = function(cmd)
        ex:SetWindowScale(tonumber(cmd))
    end,
    -- CLEAR CACHE

    " |2clearcache|r = " .. ExaminerNS.L["Clear all cached players."],
    -- Remove all saved inspection snapshots.
    clearcache = function(cmd)
        wipe(cache)
    end,
    -- Rebuild gear totals for cached players.
    _scanall = function(cmd)
        local count = 0
        for name, entry in next, cache do
            ex:ClearInspect()
            ex:LoadPlayerFromCache(name)
            count = (count + 1)
        end
        AzMsg(ExaminerNS.F("Scanned %d cached entries.", count))
    end,
    -- Request missing cached item data.
    _loaditems = function(cmd)
        local count = 0
        for name, entry in next, cache do
            for slotName, link in next, entry.Items do
                GetItemInfo(link)
                count = (count + 1)
            end
        end
        AzMsg(ExaminerNS.F("Scanned %d items, including duplicates.", count))
    end,
}

-- Dispatch a recognized command or print the command help.
local function HandleSlashCommand(cmd, commandTable)
    -- EXTRACT PARAMTERS

    local param1, param2 = cmd:match("^([^%s]+)%s*(.*)$")
    param1 = (param1 and param1:lower() or cmd:lower())
    -- CHECK PARAM FUNCTION

    if commandTable[param1] then
        commandTable[param1](param2)
    -- INVALID OR NO COMMAND
    else
        UpdateAddOnMemoryUsage()
        AzMsg(
            format(
                "----- |2%s|r |1%s|r ----- |1%.2f |2kb|r -----",
                modName,
                GetAddOnMetadata(modName, "Version"),
                GetAddOnMemoryUsage(modName)
            )
        )
        AzMsg(ExaminerNS.L["Available commands:"])
        for index, help in ipairs(commandTable) do
            AzMsg(help)
        end
    end
end

-- SLASH HANDLER

_G["SLASH_" .. modName .. "1"] = "/examiner"
_G["SLASH_" .. modName .. "2"] = "/ex"
-- Dispatch Examiner slash commands.
SlashCmdList[modName] = function(cmd)
    HandleSlashCommand(cmd, ex.slashCommands)
end
