local _, ExaminerNS = ...; if ExaminerNS.blocked then return; end
local gtt = GameTooltip;
local Compat = ExaminerNS.Compat;
local GetItemInfo = Compat.GetItemInfo;
local GetItemQualityColor = Compat.GetItemQualityColor;
local GetDetailedItemLevelInfo = Compat.GetDetailedItemLevelInfo;
local GetAddOnMetadata = Compat.GetAddOnMetadata;
local GetAddOnMemoryUsage = Compat.GetAddOnMemoryUsage;
local UpdateAddOnMemoryUsage = Compat.UpdateAddOnMemoryUsage;
local UnitPVPName = Compat.UnitPVPName;
local GetQuestDifficultyColor = Compat.GetQuestDifficultyColor;

-- Create Examiner Frame
local modName = ...;
local ex = CreateFrame("Frame",modName,UIParent);
ExaminerNS.ex = ex;
ex.Compat = Compat;
Examiner = ex;

-- Global Chat Message Function
function AzMsg(msg) DEFAULT_CHAT_FRAME:AddMessage(tostring(msg):gsub("|1","|cffffff80"):gsub("|2","|cffffffff"),0.5,0.75,1.0); end

-- Local Saved Tables
local cfg, cache;

-- Libs
local LibFroznFunctions = LibStub("LibFroznFunctions-1.0", true)
if not LibFroznFunctions then
    print("Warning: LibFroznFunctions not available.")
    return
end

-- Data Tables
local info = { Sets = {}, Items = {}, Runes = {} };
local unitStats = {};
local statTipStats1, statTipStats2 = {}, {};
ex.compareStats = {};
ex.unitStats = unitStats;
ex.info = info;

-- Misc Constants
local HOOK_DEFAULT_INSPECT = Compat.isEra or Compat.isTBC;
local CLASSIFICATION_NAMES = {
	worldboss = BOSS,
	rareelite = ITEM_QUALITY3_DESC..ELITE,
	elite = ELITE,
	rare = ITEM_QUALITY3_DESC,
};

-- Colors
local CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS;

-- Texture Mapping
local TALENT_BACKGROUNDS = {
	"DeathKnightBlood", "DeathKnightFrost", "DeathKnightUnholy",
	"DruidBalance", "DruidFeralCombat", "DruidRestoration",
	"HunterBeastMastery", "HunterMarksmanship", "HunterSurvival",
	"MageArcane", "MageFire", "MageFrost",
	"PaladinCombat", "PaladinHoly", "PaladinProtection",
	"PriestDiscipline", "PriestHoly", "PriestShadow",
	"RogueAssassination", "RogueCombat", "RogueSubtlety",
	"ShamanElementalCombat", "ShamanEnhancement", "ShamanRestoration",
	"WarlockCurses", "WarlockDestruction", "WarlockSummoning",
	"WarriorArms", "WarriorFury", "WarriorProtection",
};

-- Options
ex.options = {
	{ var = "makeMovable", default = true, label = ExaminerNS.L["Make Examiner Movable"], tip = ExaminerNS.L["Allow dragging the window; otherwise use standard panel positioning."] },
	{ var = "autoInspect", default = true, label = ExaminerNS.L["Auto Inspect on Target Change"], tip = ExaminerNS.L["Inspect the new target while Examiner is open."] },
	{ var = "clearInspectOnHide", default = true, label = ExaminerNS.L["Clear Inspect Data on Hide"], tip = ExaminerNS.L["Release the current inspection data when the window is hidden."] },
	-- { var = "percentRatings", default = false, label = "Show Ratings in Percentage *", tip = "* = Not working in WoD.\nWith this option enabled, ratings will be displayed in percent relative to the inspected person's level." },
	{ var = "combineAdditiveStats", default = true, label = ExaminerNS.L["Combine Additive Stats"], tip = ExaminerNS.L["Combine compatible equipment bonuses without adding character base stats."] },
	{ var = "tooltipSmartAnchor", default = false, label = ExaminerNS.L["Smart Tooltip Anchor"], tip = ExaminerNS.L["Anchor item tooltips beside Examiner rather than beside each item."] },
};

-- Binding Name
BINDING_HEADER_EXAMINER = modName;
BINDING_NAME_EXAMINER_OPEN = ExaminerNS.L["Open Examiner"];
BINDING_NAME_EXAMINER_TARGET = "Ex: "..INSPECT.." "..TARGET;
BINDING_NAME_EXAMINER_MOUSEOVER = ExaminerNS.L["Inspect mouseover"];
BINDING_NAME_EXAMINER_SELF = ExaminerNS.L["Inspect yourself"];

UIPanelWindows[modName] = { area = "left", pushable = 1, whileDead = 1 };
-- Allow Escape to close the window.
UISpecialFrames[#UISpecialFrames + 1] = modName;

--------------------------------------------------------------------------------------------------------
--                                          Examiner Scripts                                          --
--------------------------------------------------------------------------------------------------------

-- OnShow
local function Examiner_OnShow(self)
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UNIT_MODEL_CHANGED");
	self:RegisterEvent("UNIT_PORTRAIT_UPDATE");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
	self:RegisterEvent("MODIFIER_STATE_CHANGED");
end

-- OnHide
local function Examiner_OnHide(self)
	ExaminerNS.Inspector:Cancel();
	self:SendModuleEvent("OnInspectHidden");
	self.model.isRotating = nil;
	self.model.isPanning = nil;
	self:UnregisterEvent("INSPECT_READY");
	self:UnregisterEvent("PLAYER_TARGET_CHANGED");
	self:UnregisterEvent("UNIT_MODEL_CHANGED");
	self:UnregisterEvent("UNIT_PORTRAIT_UPDATE");
	self:UnregisterEvent("UNIT_INVENTORY_CHANGED");
	self:UnregisterEvent("MODIFIER_STATE_CHANGED");
	if (cfg.clearInspectOnHide) then
		ex:ClearInspect();
	else
		self:SetScript("OnUpdate",nil);
	end
end

-- OnUpdate -- Only used for units outside inspect range
local function Examiner_OnUpdate(self,elapsed)
	if (self:ValidateUnit()) and (CheckInteractDistance(self.unit,3)) then
		self:DoInspect(self.unit);
	end
end

--------------------------------------------------------------------------------------------------------
--                                           Event Handling                                           --
--------------------------------------------------------------------------------------------------------

local function WindowScale(value)
	if not Compat.IsNumber(value) or value~=value or value<=0 or value==math.huge then return 1; end
	return math.max(0.75,math.min(1.50,math.floor(value*100+0.5)/100));
end
function ex:SetWindowScale(value)
	if not Compat.IsNumber(value) or value~=value or value<=0 or value==math.huge then return; end
	cfg.scale=WindowScale(value);
	self:SetScale(cfg.scale);
	self:SendModuleEvent("OnConfigChanged","scale",cfg.scale);
end
-- Variables Loaded
function ex:VARIABLES_LOADED(event)
	-- Config
	if type(_G[ExaminerNS.configKey]) ~= "table" then _G[ExaminerNS.configKey] = {}; end
	cfg = _G[ExaminerNS.configKey];
	if type(cfg.caching) ~= "table" then
		cfg.caching = {};
	end
	self.cfg = cfg;
	-- Load Defaults
	if (cfg.showBackground == nil) then
		cfg.showBackground = true;
	end
	for _, option in ipairs(self.options) do
		if (cfg[option.var] == nil) then
			cfg[option.var] = option.default;
		end
	end
	-- Cache
	if type(_G[ExaminerNS.cacheKey]) ~= "table" then _G[ExaminerNS.cacheKey] = {}; end
	cache = _G[ExaminerNS.cacheKey];
	self.cache = cache;
	ExaminerNS.Cache.Initialize(self);
	Compat.RestorePage(cfg, self.modules);
	-- SET: Background Visibility | Scale | Frame Movability
	self:ShowBackground();
	cfg.scale=WindowScale(cfg.scale);
	self:SetScale(cfg.scale);
	self:SetMovable(cfg.makeMovable);
	if (cfg.makeMovable) and Compat.IsNumber(cfg.left) and Compat.IsNumber(cfg.bottom) then
		self:ClearAllPoints();
		self:SetPoint("BOTTOMLEFT",cfg.left,cfg.bottom);
	end
	-- HOOK: InspectUnit
	if (HOOK_DEFAULT_INSPECT) then
		InspectUnit = function(...) ex:DoInspect(...); end
	end
	-- Init Modules
	for index, mod in ipairs(self.modules) do
		if (mod.OnInitialize) then
			mod:OnInitialize();
			mod.OnInitialize = nil;
		end
	end
	-- Is active page valid?
	if (cfg.activePage) and (not self.modules[cfg.activePage] or not self.modules[cfg.activePage].page) then
		cfg.activePage = nil;
	end
	-- Initialise the Config for Modules
	for _, option in ipairs(self.options) do
		self:SendModuleEvent("OnConfigChanged",option.var,cfg[option.var]);
	end
	-- Remove this event
	self:UnregisterEvent(event);
	self[event] = nil;
end

-- Target Unit Changed
function ex:PLAYER_TARGET_CHANGED(event)
	if (cfg.autoInspect) and (UnitExists("target")) then
		self:DoInspect("target");
	elseif (self.unit == "target") then
		ExaminerNS.Inspector:Cancel();
		self.unit = nil;
		self:SetScript("OnUpdate",nil);
	end
end

-- Mouseover Unit Changed
function ex:UPDATE_MOUSEOVER_UNIT(event)
	ExaminerNS.Inspector:Cancel();
	self.unit = nil;
	self:SetScript("OnUpdate",nil);
	self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT");
end

-- Model or Portrait Change
function ex:UNIT_MODEL_CHANGED(event,unit)
	if (unit and self:ValidateUnit() and UnitIsUnit(unit,self.unit)) then
		self.model:SetUnit(self.unit);
		SetPortraitTexture(self.portrait,self.unit);
	end
end
ex.UNIT_PORTRAIT_UPDATE = ex.UNIT_MODEL_CHANGED;

-- Rescan Gear on Item Change
function ex:UNIT_INVENTORY_CHANGED(event,unit)
    ExaminerNS.Inspector:InventoryChanged(unit);
end

-- Modifier State Changed
function ex:MODIFIER_STATE_CHANGED(event)
	if (self.tooltipSlot) then
		local onEnterFunc = self.tooltipSlot:GetScript("OnEnter");
		if (onEnterFunc) then
			onEnterFunc(self.tooltipSlot);
		end
	end
end

function ex:INSPECT_READY(event,guid)
    ExaminerNS.Inspector:Ready(guid);
end

-- INSPECT_HONOR_UPDATE
function ex:INSPECT_HONOR_UPDATE(event)
    local session=ExaminerNS.Inspector.active;
    if session and ExaminerNS.Inspector:Valid(session) and session.serverReady
        and (self.isSelf or ExaminerNS.Inspector.notificationGUID==session.guid) then
        session.honorReady=true;
        self:SendModuleEvent('OnHonorReady'); self:CachePlayer();
    end
end

-- Achievement Inspection Ready
function ex:INSPECT_ACHIEVEMENT_READY(event,guid)
	if (AchievementFrameComparison) then
		AchievementFrameComparison:RegisterEvent("INSPECT_ACHIEVEMENT_READY");
	end
	self:UnregisterEvent("INSPECT_ACHIEVEMENT_READY");
	self:SendModuleEvent("OnAchievementReady",self.unit,guid);
end

--------------------------------------------------------------------------------------------------------
--                                         Model Frame Scripts                                        --
--------------------------------------------------------------------------------------------------------

-- Model Frame Workaround
local function Model_OnShow(self)
	if (self.cleared) then
		self:ClearModel();
	end
end

local function Model_OnUpdate(self,elapsed)
	if (self.isRotating) then
		local endx, endy = GetCursorPosition();
		self.rotation = (endx - self.startx) / 34 + self:GetFacing();
		self:SetFacing(self.rotation);
		self.startx, self.starty = GetCursorPosition();
	elseif (self.isPanning) then
		local endx, endy = GetCursorPosition();
		local z, x, y = self:GetPosition(z,x,y);
		x = (endx - self.startx) / 45 + x;
		y = (endy - self.starty) / 45 + y;
		self:SetPosition(z,x,y);
		self.startx, self.starty = GetCursorPosition();
	end
end

local function Model_OnMouseWheel(self,delta)
	local z, x, y = self:GetPosition();
	local scale = (IsControlKeyDown() and 2 or 0.7);
	z = (delta > 0 and z + scale or z - scale);
	self:SetPosition(z,x,y);
end

local function Model_OnMouseDown(self,button)
	self.startx, self.starty = GetCursorPosition();
	if (button == "LeftButton") then
		self.isRotating = true;
		if (IsControlKeyDown()) then
			ex:SetBackgroundTexture(true);
		end
	elseif (button == "RightButton") then
		self.isPanning = true;
		if (IsControlKeyDown()) then
			cfg.showBackground = (not cfg.showBackground);
			ex:ShowBackground();
		end
	end
end

local function Model_OnMouseUp(self,button)
	if (button == "LeftButton") then
		self.isRotating = nil;
	elseif (button == "RightButton") then
		self.isPanning = nil;
	end
end

--------------------------------------------------------------------------------------------------------
--                                            Init Examiner                                           --
--------------------------------------------------------------------------------------------------------

-- Examiner Main Frame
ex:SetSize(384,440);
ex:SetPoint("CENTER");
ex:EnableMouse(true);
ex:SetToplevel(true);
ex:Hide();
ex:SetHitRectInsets(12,35,10,2);
ex:SetScript("OnShow",Examiner_OnShow);
ex:SetScript("OnHide",Examiner_OnHide);
ex:SetScript("OnEvent",function(self,event,...) self[event](self,event,...); end);
ex:SetScript("OnMouseDown",function(self,button) if (self:IsMovable()) then self:StartMoving(); end end);
ex:SetScript("OnMouseUp",function(self,button) if (self:IsMovable()) then self:StopMovingOrSizing(); cfg.left = self:GetLeft(); cfg.bottom = self:GetBottom() end end);

-- Events
ex:RegisterEvent("VARIABLES_LOADED");

-- Close Button
ex.close = CreateFrame("Button",nil,ex,"UIPanelCloseButton");
ex.close:SetPoint("TOPRIGHT",-34,-12);

-- Portrait
ex.portrait = ex:CreateTexture(nil,"BACKGROUND");
ex.portrait:SetSize(60,60);
ex.portrait:SetPoint("TOPLEFT",7,-6);

-- FontStrings
ex.title = ex:CreateFontString(nil,"ARTWORK","GameFontNormal");
ex.title:SetPoint("TOP",5,-17);
ex.details = ex:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
ex.details:SetPoint("TOP",5,-44);
ex.guild = ex:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
ex.guild:SetPoint("TOP",ex.details,"BOTTOM",0,-2);

-- Dialog Textures
ex.dlgTopLeft = ex:CreateTexture(nil,"ARTWORK");
ex.dlgTopLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft");
ex.dlgTopLeft:SetPoint("TOPLEFT");
ex.dlgTopLeft:SetSize(256,256);
ex.dlgTopRight = ex:CreateTexture(nil,"ARTWORK");
ex.dlgTopRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight");
ex.dlgTopRight:SetPoint("TOPRIGHT");
ex.dlgTopRight:SetSize(128,256);
ex.dlgBottomLeft = ex:CreateTexture(nil,"ARTWORK");
ex.dlgBottomLeft:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft");
ex.dlgBottomLeft:SetPoint("TOPLEFT",0,-256);
ex.dlgBottomLeft:SetSize(256,256);
ex.dlgBottomRight = ex:CreateTexture(nil,"ARTWORK");
ex.dlgBottomRight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight");
ex.dlgBottomRight:SetPoint("TOPRIGHT",0,-256);
ex.dlgBottomRight:SetSize(128,256);

-- Background Textures -- Resize height, so they go beneath module buttons
local bgScale = 1.064;
ex.bgTopLeft = ex:CreateTexture(nil,"OVERLAY");
ex.bgTopLeft:SetPoint("TOPLEFT",21,-76);
ex.bgTopLeft:SetHeight(256 * bgScale);
ex.bgTopRight = ex:CreateTexture(nil,"OVERLAY");
ex.bgTopRight:SetPoint("LEFT",ex.bgTopLeft,"RIGHT");
ex.bgTopRight:SetHeight(256 * bgScale);
ex.bgBottomLeft = ex:CreateTexture(nil,"OVERLAY");
ex.bgBottomLeft:SetPoint("TOP",ex.bgTopLeft,"BOTTOM");
ex.bgBottomLeft:SetHeight(128 * bgScale);
ex.bgBottomRight = ex:CreateTexture(nil,"OVERLAY");
ex.bgBottomRight:SetPoint("LEFT",ex.bgBottomLeft,"RIGHT");
ex.bgBottomRight:SetHeight(128 * bgScale);

-- Model
ex.model = CreateFrame("PlayerModel",nil,ex);
ex.model:SetSize(320,354);
ex.model:SetPoint("BOTTOM",-11,10);
ex.model:EnableMouse(true);
ex.model:EnableMouseWheel(true);
ex.model:SetScript("OnShow",Model_OnShow);
ex.model:SetScript("OnUpdate",Model_OnUpdate);
ex.model:SetScript("OnMouseDown",Model_OnMouseDown);
ex.model:SetScript("OnMouseUp",Model_OnMouseUp);
ex.model:SetScript("OnMouseWheel",Model_OnMouseWheel);

--------------------------------------------------------------------------------------------------------
--                                            Unit Details                                            --
--------------------------------------------------------------------------------------------------------

local uDetails = {};

-- Unit Detail String
function ex:SetUnitDetailString()
	-- Level
	local color = GetQuestDifficultyColor(info.level ~= -1 and info.level or 500);
	uDetails[#uDetails + 1] = format("%s |cff%.2x%.2x%.2x%s|r",LEVEL,color.r * 255,color.g * 255,color.b * 255,(info.level ~= -1 and info.level or "??"));
	-- Classification (non players only, so ok to use ex.unit)
	if (not info.raceFixed) then
		local classification = UnitClassification(ex.unit);
		if (CLASSIFICATION_NAMES[classification]) then
			uDetails[#uDetails + 1] = "("..CLASSIFICATION_NAMES[classification]..")";
		end
	end
	-- Race for Players / Family or Type for NPC's
	if (info.race) then
		uDetails[#uDetails + 1] = (info.race ~= "Not specified" and info.race or UNKNOWN);
	end
	-- Players Only: Class (+ Realm)
	if (info.raceFixed) then
		if (info.class) then
			local color = CLASS_COLORS[info.classFixed] or { r = 1, g = 1, b = 1 };
			uDetails[#uDetails + 1] = format("|cff%.2x%.2x%.2x%s|r",color.r * 255,color.g * 255,color.b * 255,info.class);
		end
		if (info.realm) then
			uDetails[#uDetails + 1] = "["..info.realm.."]";
		end
	end
	-- Set Result
	self.details:SetText(table.concat(uDetails," "));
	wipe(uDetails);
end

-- Unit Guild String (Faction for NPC's)
function ex:SetUnitGuildString()
	-- Init as empty
	self.guild:SetText("");
	-- Players
	if (info.raceFixed) then
		if (info.guild) then
			self.guild:SetFormattedText("%s%s<%s>",info.guildRank or "",info.guildRank and info.guildRank~="" and ExaminerNS.L[" of "] or "",info.guild);
		end
	-- NPC's only, so ok to use 'ex.unit' here
	else
		LibGearExamTip:ClearLines();
		LibGearExamTip:SetUnit(ex.unit);
		local line;
		for i = 2, LibGearExamTip:NumLines() - 1 do
			line = _G["LibGearExamTipTextLeft"..i]:GetText();
			if (line and TOOLTIP_UNIT_LEVEL and line:find("^"..TOOLTIP_UNIT_LEVEL:gsub("%%s",".+"))) then
				line = _G["LibGearExamTipTextLeft"..(i + 1)]:GetText();
				if (line ~= PVP_ENABLED) then
					self.guild:SetText(line);
					return;
				end
			end
		end
	end
end

-- Return name used for entires
function ex:GetEntryName()
	return (info.realm and info.name.."-"..info.realm or info.name);
end

--------------------------------------------------------------------------------------------------------
--                                           Cache Functions                                          --
--------------------------------------------------------------------------------------------------------

-- Cache Player
function ex:CachePlayer(override)
    return ExaminerNS.Cache.Store(self,override);
end

-- Load player from cache
function ex:LoadPlayerFromCache(entryName)
    return ExaminerNS.Cache.Load(self,entryName);
end

--------------------------------------------------------------------------------------------------------
--                                         Inspect Functions                                          --
--------------------------------------------------------------------------------------------------------

function ex:CanInspect(unit)
    return ExaminerNS.Inspector:CanInspect(unit);
end

-- Show or hide Examiner, but ensures that its done using the movable option
function ex:Display(state)
	state = (state == nil and true or state);
	if (not state) then
		HideUIPanel(self);
	elseif (cfg.makeMovable) then
		self:Show();
	else
		ShowUIPanel(self);
	end
end

-- Normal Open
function ex:OpenSimple()
	if (not info.name) then
		self:DoInspect("player");
	else
		self:Display(not self:IsVisible());
	end
end

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


-- ClearInspect -- Clears all work variables. Always called before a new inspect request!
function ex:ClearInspect()
    ExaminerNS.Inspector:Clear();
end

-- Inspect Ready
function ex:InspectReady(guid)
    ExaminerNS.Inspector:Ready(guid);
end

-- Converts a unit token such as "mouseover" or "target" into a more static unit token such as "party4" or "raid17"
local function UnitToStaticUnit(unit)
	local count = GetNumGroupMembers();
	if (count) and (count > 0) then
		local isRaid = IsInRaid();
		for i = 1, count do
			local static = (isRaid and "raid" or "party")..i;
			if (UnitIsUnit(unit,static)) then
				return static;
			end
		end
	end
end

-- Inspect Unit
function ex:DoInspect(unit,openFlag)
    return ExaminerNS.Inspector:Start(unit,openFlag);
end

-- Scans the gear (also using LibFroznFunctions and TacoTip algorithm)
function ex:ScanGear(unit)
    local session=ExaminerNS.Inspector.active;
    if session and session.unit==unit then ExaminerNS.Inspector:Refresh(session); end
end




--------------------------------------------------------------------------------------------------------
--                                        Additional Inspection                                       --
--------------------------------------------------------------------------------------------------------

-- Requests Honor Data
function ex:RequestHonorData()
    local session=ExaminerNS.Inspector.active;
    if not session or session.cached or not ExaminerNS.Inspector:Valid(session) then return; end
    if not self.isSelf and not session.serverReady then return; end
    self:RegisterEvent('INSPECT_HONOR_UPDATE');
    if (Compat.isRetail or Compat.isForever) and (type(RequestInspectHonorData)~='function' or type(HasInspectHonorData)~='function') then
        session.honorReady=true;
        return;
    end
    if type(RequestInspectHonorData)~='function' then return; end
    if self.requestedHonorData then return; end
    self.requestedHonorData=true;
    Compat.Try(RequestInspectHonorData);
end

-- Requests Achievement Data
function ex:RequestAchievementData()
	if (self.requestedAchievementData) then
		return;
	end
	-- Makes the Achievement UI, if loaded, not update when we query the achievements
	if (achievementFunctions) and (type(achievementFunctions.selectedCategory) == "string") then
		achievementFunctions.selectedCategory = 92;
	end
	if (AchievementFrameComparison) then
		AchievementFrameComparison:UnregisterEvent("INSPECT_ACHIEVEMENT_READY");
	end
	-- Request
	self.requestedAchievementData = true;
	self:RegisterEvent("INSPECT_ACHIEVEMENT_READY");
	SetAchievementComparisonUnit(self.unit);
end

--------------------------------------------------------------------------------------------------------
--                                          Helper Functions                                          --
--------------------------------------------------------------------------------------------------------

-- Round number
function round(num)
    return math.floor(num + 0.5)
end

-- Format Time (sec)
function ex:FormatTime(time,short)
	time=math.floor(Compat.Number(time,0));
	if (time < 0) then
		return "n/a";
	-- under a min
	elseif (time < 60) then
		return time..(short and "s" or ExaminerNS.L[" seconds"]);
	-- less than 1 hour
	elseif (time < 60*60) then
		return format(short and "%dm %.2ds" or ExaminerNS.L["%d minutes and %.2d seconds"],math.floor(time / 60),time % 60);
	-- less than 1 day
	elseif (time < 60*60*24) then
		time = math.floor(time/60);
		return format(short and "%dh %.2dm" or ExaminerNS.L["%d hours and %.2d minutes"],math.floor(time / 60),time % 60);
	-- above 1 day
	else
		time = math.floor(time/60/60);
		return format(short and "%dd %.2dh" or ExaminerNS.L["%d days and %.2d hours"],math.floor(time / 24),time % 24);
	end
end

-- Cache current stats for compare or clear previous marked one
function ex:CacheStatsForCompare(unmark)
    wipe(self.compareStats);
    if unmark then self.isComparing=nil;
    elseif self.itemsLoaded then
        self.isComparing=true; self.compareStats.entry=self:GetEntryName();
        for key,value in pairs(self.unitStats) do self.compareStats[key]=value; end
        for slot,link in pairs(self.info.Items) do self.compareStats[slot]=link; end
    end
    self:SendModuleEvent('OnCompare',self.isComparing,self.compareStats);
end

-- Sets the background vertex color
function ex:SetBackgroundVertex(r,g,b,a)
	self.dlgTopLeft:SetVertexColor(r,g,b,a);
	self.dlgTopRight:SetVertexColor(r,g,b,a);
	self.dlgBottomLeft:SetVertexColor(r,g,b,a);
	self.dlgBottomRight:SetVertexColor(r,g,b,a);
end

-- Toggle the Background
function ex:ShowBackground(show)
	show = (show) or (show == nil and cfg.showBackground);
	ex.bgTopLeft:SetShown(show);
	ex.bgTopRight:SetShown(show);
	ex.bgBottomLeft:SetShown(show);
	ex.bgBottomRight:SetShown(show);
end

-- Updates the Main Objects
function ex:UpdateObjects()
	-- Textures & Model


	if (ex.unit and Compat.IsTrue(UnitIsVisible(ex.unit))) then
		SetPortraitTexture(ex.portrait,ex.unit);
		if ex.unitType==1 then ex.model:ClearModel(); end
		ex.model:SetUnit(ex.unit);
		ex.model.cleared = nil;
	else
		local genderRace = (info.sex == 3 and "Female" or "Male").."-"..(info.raceFixed or "");
		ex.portrait:SetTexture("Interface\\CharacterFrame\\TemporaryPortrait-"..genderRace);
		ex.model:ClearModel();
		ex.model.cleared = true;
	end
	ex:SetBackgroundTexture();
	-- Title, Detail & Guild Text
	ex.title:SetText(info.pvpName or info.name);
	ex:SetUnitDetailString();
	ex:SetUnitGuildString();
end

-- Show Module Page
function ex:ShowModulePage(index)
	local requested = index and self.modules[index];
	if requested and requested.isPopup then requested:TogglePopup(); return; end
	if cfg.activePage and self.modules[cfg.activePage] and self.modules[cfg.activePage].isPopup then
		cfg.activePage=nil; cfg.activePageToken=nil;
	end
	-- hide current page
	local lastMod = ex.modules[cfg.activePage];
	if (lastMod) then
		lastMod.page:Hide();
	end
	-- when we have a new index
	if (index) then
		-- save old page
		if (cfg.activePage) then
			cfg.prevPage = cfg.activePage;
		end
		-- toggle page
		if (index == cfg.activePage) then
			self:SendModuleEvent("OnPageChanged",lastMod,false);
			cfg.activePage = nil;
		else
			cfg.activePage = index;
		end
	end
	cfg.activePageToken = cfg.activePage and self.modules[cfg.activePage].token or nil;
	-- show active page
	if (cfg.activePage) then
		local shownMod = ex.modules[cfg.activePage];
		if shownMod.hasData then shownMod.page:Show(); else shownMod.page:Hide(); end
		self:SendModuleEvent("OnPageChanged",shownMod,true);
	end
end

-- Background Texture -- param can be a texture, or true for loading racial texture, or nothing to load a random texture
function ex:SetBackgroundTexture(param)
	local texture;
	-- Find Texture
	if (type(param) == "string") then
		texture = param;
	elseif (param == true) or (not info.raceFixed) then
		texture = "Interface\\TalentFrame\\"..TALENT_BACKGROUNDS[random(#TALENT_BACKGROUNDS)].."-";
	else
		param = (info.raceFixed == "Gnome" and "Dwarf") or (info.raceFixed == "Troll" and "Orc") or (info.raceFixed);
		texture = "Interface\\DressUpFrame\\DressUpBackground-"..param;
	end
	-- Set Texture
	local normal = texture:find("DressUpFrame");
	ex.bgTopLeft:SetTexture(texture..(normal and "1" or "TopLeft"));
	ex.bgTopRight:SetTexture(texture..(normal and "2" or "TopRight"));
	ex.bgBottomLeft:SetTexture(texture..(normal and "3" or "BottomLeft"));
	ex.bgBottomRight:SetTexture(texture..(normal and "4" or "BottomRight"));
	-- Set Texture Width -- Scaled about 1.063 for the talent frame textures
	local scale = (normal and 1 or 1.063);
	ex.bgTopLeft:SetWidth(256 * scale);
	ex.bgTopRight:SetWidth(64 * scale);
	ex.bgBottomLeft:SetWidth(256 * scale);
	ex.bgBottomRight:SetWidth(64 * scale);
end

-- Check Last Unit -- Clears unit if invalid
function ex:ValidateUnit()
    if not self.unit or not Compat.IsTrue(UnitExists(self.unit)) then return false; end
    local guid=UnitGUID(self.unit);
    return Compat.IsString(guid) and guid==self.guid;
end

--------------------------------------------------------------------------------------------------------
--                                   Widget Script Helper Functions                                   --
--------------------------------------------------------------------------------------------------------

-- Hide GTT
function ex.HideGTT(self)
	gtt:Hide();
end

-- Item Button OnClick
function ex.ItemButton_OnClick(self,button)
	if (self.link) then
		if (button == "RightButton") then
			-- Get Examiner item link and player item link
			local _, ExaminerItemLink = GetItemInfo(self.link);
			local PlayerItemslotId = self.id
			local PlayerItemLink = GetInventoryItemLink("player", PlayerItemslotId)
			local itemStats1, itemStats2 = {}, {};
			LibGearExam:ScanItemLink(ExaminerItemLink,itemStats1);
			LibGearExam:ScanItemLink(PlayerItemLink,itemStats2);
			-- Compare both items
			if not (PlayerItemLink == nil) then
				AzMsg(ExaminerNS.F("Comparing %s with %s",ExaminerItemLink,PlayerItemLink));
				for statToken, statName in next, LibGearExam.StatNames do
					if (itemStats1[statToken] or itemStats2[statToken]) then
						local statText = LibGearExam:GetStatValue(statToken,itemStats1,itemStats2,UnitLevel("player"),cfg.combineAdditiveStats,cfg.percentRatings);
						AzMsg(format("%s = |1%s|r.",statName,statText));
					end			
				end
			else
				AzMsg(ExaminerNS.L["No equipped item in that slot."]);
			end
		elseif (button == "LeftButton") then
			local editBox = ChatEdit_GetActiveWindow();
			if (IsModifiedClick("DRESSUP")) then
				DressUpItemLink(itemLink);
			elseif (IsModifiedClick("CHATLINK")) and (editBox) and (editBox:IsVisible()) then
				editBox:Insert(itemLink);
			end
		end
	end
end

-- Item Button OnLeave
function ex.ItemButton_OnLeave(self)
	ex.tooltipSlot = nil;
	ResetCursor();
	gtt:Hide();
end

-- Item Button OnEnter
function ex.ItemButton_OnEnter(self,motion)
	-- Inspect Cursor
	if (IsModifiedClick("DRESSUP")) then
		ShowInspectCursor();
	else
		ResetCursor();
	end

	-- Use the configured tooltip anchor.
	ex.tooltipSlot = self;
	gtt:SetOwner(self,"ANCHOR_NONE");
	if (cfg.tooltipSmartAnchor) then
		gtt:SetPoint("TOPLEFT",ex,"TOPRIGHT",-34,-12);
	else
		gtt:SetPoint("TOPLEFT",self,"TOPRIGHT");
	end

	-- Fill in tooltip
	-- itemstring breakdown
	if (self.link) and (IsShiftKeyDown()) and (IsAltKeyDown()) then
		local itemName, _, itemRarity = GetItemInfo(self.link);
		local is = LibItemString:New(self.link);
		gtt:AddLine(itemName,GetItemQualityColor(itemRarity));
		for k, v in ipairs(is) do

			gtt:AddDoubleLine(format("|cffffffff%.2d|r %s",k,is:GetFieldName(k)),v,nil,nil,nil,1,1,1);
		end
		gtt:Show();
	-- stat breakdown /w compare support
	elseif (self.link) and (IsAltKeyDown()) then
		local itemName, _, itemRarity = GetItemInfo(self.link);
		gtt:AddLine(itemName,GetItemQualityColor(itemRarity));
		LibGearExam:ScanItemLink(self.link,statTipStats1);
		if (ex.isComparing) and (self.slotName) then
			LibGearExam:ScanItemLink(ex.compareStats[self.slotName],statTipStats2);
		end
		for index, statToken in ipairs(LibGearExam.StatNamesSorted) do
			if (statTipStats1[statToken]) or (statTipStats2 and statTipStats2[statToken]) then
				local statText = LibGearExam:GetStatValue(statToken,statTipStats1,ex.isComparing and statTipStats2,info.level,cfg.combineAdditiveStats,cfg.percentRatings);

				gtt:AddDoubleLine(LibGearExam:FormatStatName(statToken,cfg.percentRatings),statText,nil,nil,nil,1,1,1);
			end
		end
		wipe(statTipStats1);
		wipe(statTipStats2);
		gtt:Show();
	-- set item from unit
	elseif (self.id and ex:ValidateUnit() and CheckInteractDistance(ex.unit,3) and gtt:SetInventoryItem(ex.unit,self.id)) then
	-- set item from link
	elseif (self.link) then
		gtt:SetHyperlink(self.link);
	-- no valid item available, so add text that we can reload cache to get item
	elseif (self.realLink) then
		gtt:SetText(_G[self.slotName:upper()]);
		gtt:AddLine("ItemID: "..self.realLink:match(LibGearExam.ITEMLINK_PATTERN_ID),0,0.44,0.86);
		gtt:AddLine(ExaminerNS.L["Item data is not cached yet. Click to reload this player."],1,1,1,1);
		gtt:Show();
	-- empty item slot
	elseif (self.slotName) then
		gtt:SetText(_G[self.slotName:upper()]);
	end
end

--------------------------------------------------------------------------------------------------------
--                                           Slash Handling                                           --
--------------------------------------------------------------------------------------------------------

-- Slash Commands -- Array indices are used for command help. Commands starting with underscore are meant for debugging
ex.slashCommands = {
	-- Inspect Unit
	" |2inspect <unit>|r = "..ExaminerNS.L["Inspect the specified unit."],
	inspect = function(cmd)
		ex:DoInspect(cmd == "" and "target" or cmd);
	end,
	-- Scan a Single Item
	" |2si <itemlink>|r = "..ExaminerNS.L["Show an item's equipment stats."],
	si = function(cmd)
		if (cmd ~= "") then
			local itemStats = {};
			LibGearExam:ScanItemLink(cmd,itemStats);
			AzMsg(ExaminerNS.F("Scan overview: %s",cmd));
			for stat in next, itemStats do
				local statName = (cfg.percentRatings and LibGearExam.StatNames[stat] or LibGearExam.StatNames[stat].." "..RATING);
				local statText, altText = LibGearExam:GetStatValue(stat,itemStats,nil,UnitLevel("player"),cfg.combineAdditiveStats,cfg.percentRatings);
				AzMsg(format(altText and "%s = |1%s|r (|1%s|r)." or "%s = |1%s|r.",statName,statText,altText));
			end
		else
			AzMsg(ExaminerNS.L["No item link given."]);
		end
	end,
	-- Compares two Items
	" |2compare <itemlink1> <itemlink2>|r = "..ExaminerNS.L["Compare two items."],
	compare = function(cmd)
		if (cmd ~= "") then
			local item1, item2 = cmd:match("(|c.+|r)%s+(|c.+|r)");
			if (item1 and item2) then
				local itemStats1, itemStats2 = {}, {};
				LibGearExam:ScanItemLink(item1,itemStats1);
				LibGearExam:ScanItemLink(item2,itemStats2);
				AzMsg(ExaminerNS.F("Comparing %s with %s",item1,item2));
				for statToken, statName in next, LibGearExam.StatNames do
					if (itemStats1[statToken] or itemStats2[statToken]) then
						if (not cfg.percentRatings) then
							statName = (statName.." "..RATING);
						end
						local statText = LibGearExam:GetStatValue(statToken,itemStats1,itemStats2,UnitLevel("player"),cfg.combineAdditiveStats,cfg.percentRatings);
						AzMsg(format("%s = |1%s|r.",statName,statText));
					end
				end
			else
				AzMsg(ExaminerNS.L["Could not parse item links."]);
			end
		else
			AzMsg(ExaminerNS.L["No item links given."]);
		end
	end,
	-- Reset Window Position
	" |2reset|r = "..ExaminerNS.L["Reset the window position."],
	reset = function(cmd)
		if (cfg.makeMovable) then
			ex:ClearAllPoints();
			ex:SetPoint("CENTER");
		else
			AzMsg(ExaminerNS.L["This command requires a movable window."]);
		end
	end,
	-- Scale
	" |2scale <value>|r = "..ExaminerNS.L["Set window scale (default: 1.00)."],
	scale = function(cmd)
		ex:SetWindowScale(tonumber(cmd));
	end,
	-- Clear Cache
	" |2clearcache|r = "..ExaminerNS.L["Clear all cached players."],
	clearcache = function(cmd)
		wipe(cache);
	end,
	-- Scans all cached entries
	_scanall = function(cmd)
		local count = 0;
		for name, entry in next, cache do
			ex:ClearInspect();
			ex:LoadPlayerFromCache(name);
			count = (count + 1);
		end
		AzMsg(ExaminerNS.F("Scanned %d cached entries.",count));
	end,
	-- Load all items, so they are cached locally
	_loaditems = function(cmd)
		local count = 0;
		for name, entry in next, cache do
			for slotName, link in next, entry.Items do
				GetItemInfo(link);
				count = (count + 1);
			end
		end
		AzMsg(ExaminerNS.F("Scanned %d items, including duplicates.",count));
	end,
};

local function HandleSlashCommand(cmd,commandTable)
	-- Extract Paramters
	local param1, param2 = cmd:match("^([^%s]+)%s*(.*)$");
	param1 = (param1 and param1:lower() or cmd:lower());
	-- Check Param Function
	if (commandTable[param1]) then
		commandTable[param1](param2)
	-- Invalid or No Command
	else
		UpdateAddOnMemoryUsage();
		AzMsg(format("----- |2%s|r |1%s|r ----- |1%.2f |2kb|r -----",modName,GetAddOnMetadata(modName,"Version"),GetAddOnMemoryUsage(modName)));
		AzMsg(ExaminerNS.L["Available commands:"]);
		for index, help in ipairs(commandTable) do
			AzMsg(help);
		end
	end
end

-- Slash Handler
_G["SLASH_"..modName.."1"] = "/examiner";
_G["SLASH_"..modName.."2"] = "/ex";
SlashCmdList[modName] = function(cmd) HandleSlashCommand(cmd,ex.slashCommands) end
