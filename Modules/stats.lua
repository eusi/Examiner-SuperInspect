local _, ExaminerNS = ...; if ExaminerNS.blocked then return; end
local ex = Examiner;
local GetItemInfo = ExaminerNS.Compat.GetItemInfo;
local GetDetailedItemLevelInfo = ExaminerNS.Compat.GetDetailedItemLevelInfo;
local cfg, cache;
local gtt = GameTooltip;

-- Module
local mod = ex:CreateModule("Stats",ExaminerNS.L["Gear Statistics"]);
mod.help = ExaminerNS.L["Equipment contributions only; excludes character base stats and buffs. Some conditional effects may be unavailable.\nShift-click: compare. Shift-right-click: clear comparison."];
mod:CreatePage(false);
mod:HasButton(true);
mod.details = ex:CreateDetailObject();

-- Libs
local LibFroznFunctions = LibStub("LibFroznFunctions-1.0", true)
if not LibFroznFunctions then
    print("Warning: LibFroznFunctions not available.")
    return
end

-- Variables
local ITEM_HEIGHT = 12;
local displayList = {};
mod.displayList = displayList;
local resists = {};
mod.resistanceIcons=resists;
local entries = {};
mod.statRows=entries;
local measure=mod.page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); measure:Hide();
local function TextWidth(text)
    measure:SetText(text); return ExaminerNS.Compat.Number(measure:GetStringWidth(),0);
end
local function FitLabel(text,width)
    if TextWidth(text)<=width then return text,false; end
    if TextWidth("...")>width then return "",true; end
    local chars={};
    for char in text:gmatch("[^\128-\191][\128-\191]*") do chars[#chars+1]=char; end
    local low,high=0,#chars;
    while low<high do
        local middle=math.floor((low+high+1)/2);
        if TextWidth(table.concat(chars,"",1,middle).."...")<=width then low=middle; else high=middle-1; end
    end
    return table.concat(chars,"",1,low).."...",true;
end
mod.FitLabel=FitLabel;

-- Stat Entry Order -- Item 0 is the header for the group
local StatEntryOrder = {
	{ [0] = PLAYERSTAT_BASE_STATS, "STR", "AGI", "STA", "INT", "SPI", "ARMOR", "MASTERY" },
	{ [0] = STAT_CATEGORY_GENERAL, "CRIT", "HIT", "HASTE", "EXPERTISE", "SPELLHASTE", "HP", "MP", "HP5", "MP5", "SANCTIFIED" },
	{ [0] = PLAYERSTAT_SPELL_COMBAT.." "..STATS_LABEL:gsub(":",""), "SPELLDMG", "HEAL", "ARCANEDMG", "FIREDMG", "NATUREDMG", "FROSTDMG", "SHADOWDMG", "HOLYDMG", "SPELLPENETRATION" },
	{ [0] = MELEE.." & "..RANGED, "AP", "RAP", "ARMORPENETRATION", "EXPERTISE", "WPNDMG", "RANGEDDMG", "DAGGERSKILL", "ONEAXESKILL", "TWOAXESKILL", "ONESWORDSKILL", "TWOSWORDSKILL", "ONEMACESKILL", "TWOMACESKILL", "BOWSKILL", "GUNSSKILL", "CROSSBOWSKILL" },
	{ [0] = PLAYERSTAT_DEFENSES, "DEFENSE", "DODGE", "PARRY", "BLOCK", "BLOCKVALUE", "RESILIENCE", "PVPPOWER" },
};

--------------------------------------------------------------------------------------------------------
--                                           Module Scripts                                           --
--------------------------------------------------------------------------------------------------------

-- OnInitialize
function mod:OnInitialize()
	cfg = ex.cfg;
	cache = ex.cache;
	-- Defaults
	cfg.statsViewType = 1;
	-- Add cache "iLvlAverage" sort method
	local cacheMod = ex:GetModuleFromToken("Cache");
	if (cacheMod) and (cacheMod.cacheSortMethods) then
		cacheMod.cacheSortMethods[#cacheMod.cacheSortMethods + 1] = "iLvlAverage";
	end
end

-- OnConfigChanged
function mod:OnConfigChanged(var,value)
	if (cfg.statsViewType == 1) and (var == "combineAdditiveStats" or var == "percentRatings") then
		self:BuildShownList();
	end
end

-- OnButtonClick
function mod:OnButtonClick(frame,button)
	-- left
	if (button == "LeftButton") then
		if (IsShiftKeyDown()) and (ex.itemsLoaded) then
			ex:CacheStatsForCompare();
		end
	-- right
	elseif (IsShiftKeyDown()) then
		ex:CacheStatsForCompare(1);
	end
end

-- OnInspectReady
function mod:OnInspectReady(unit,guid)
	self.blizzardItemLevel=nil;
	local C,I=ExaminerNS.Compat,ExaminerNS.Inspector;
	local session=I.active;
	if (C.isRetail or C.isForever) and not ex.isCacheEntry and session and session.serverReady and I:Valid(session)
		and unit==session.unit and (ex.isSelf or I.notificationGUID==session.guid) then
		local value=C.Try(C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel,unit);
		if C.IsNumber(value) and value>=0 and value<math.huge then self.blizzardItemLevel=value; end
	end
	self:HasData(ex.itemsLoaded);
	if (ex.itemsLoaded) then
		self:InitDetails();
		self:BuildShownList();
	end
end
mod.OnInspect = mod.OnInspectReady;

-- OnCacheLoaded
function mod:OnCacheLoaded(entry,unit)
	self.blizzardItemLevel=nil;
	self:HasData(true);
	self:InitDetails();
	self:BuildShownList();
end
mod.OnGearUpdated = mod.OnInspectReady;
function mod:OnDataTimeout() self:HasData(true); self:InitDetails(); self:BuildShownList(); end

-- OnClearInspect
function mod:OnClearInspect()
	self.blizzardItemLevel=nil;
	self:HasData(nil);
	self.details:Clear();
end

-- OnCompare
function mod:OnCompare(isCompare,compareEntry)
	self:BuildShownList();
end

-- OnDetailsUpdate
function mod:OnDetailsUpdate()
	if (cfg.statsViewType == 2) then
		self:BuildShownList();
	end
end

--------------------------------------------------------------------------------------------------------
--                                                Menu                                                --
--------------------------------------------------------------------------------------------------------

-- Menu Init Items
function mod.MenuInit(parent,list)
	-- stats
	local tbl = list[#list + 1]; tbl.text = ExaminerNS.L["Stats"]; tbl.header = 1;
	tbl = list[#list + 1]; tbl.text = ExaminerNS.L["Cache Player"]; tbl.value = 1; tbl.checked = (cache[ex:GetEntryName()] ~= nil);
	-- compare
	tbl = list[#list + 1]; tbl.header = 1;
	tbl = list[#list + 1]; tbl.text = ExaminerNS.L["Compare"]; tbl.header = 1;
	tbl = list[#list + 1]; tbl.text = ExaminerNS.L["Mark for Compare"]; tbl.value = 2; tbl.checked = (ex.isComparing and ex.compareStats.entry == ex:GetEntryName());
	if (ex.isComparing) then
		tbl = list[#list + 1]; tbl.text = ExaminerNS.L["Clear Compare"]; tbl.value = 3;
	end
end

-- Menu Select Item
function mod.MenuSelect(parent,entry)
	-- Cache
	if (entry.value == 1) then
		ex:CachePlayer(1);
	-- Mark for Compare & Clear Compare
	elseif (entry.value == 2 or entry.value == 3) then
		ex:CacheStatsForCompare(entry.value == 3);
	end
end

--------------------------------------------------------------------------------------------------------
--                                               Details                                              --
--------------------------------------------------------------------------------------------------------

local function GetItemLevelInfo()
	local gear=ex.gear or {};
	return gear.total or 0, gear.min, gear.max;
end

-- Initialise Details
function mod:InitDetails()
	local details = self.details;
	details:Clear();
	-- Item Level
	local iLvlTotal, iLvlMin, iLvlMax = GetItemLevelInfo();
	details:Add(ExaminerNS.L["Item Levels"]);
	details:Add("Combined Item Levels",iLvlTotal);
	details:Add(ExaminerNS.L["Average Item Level"],ex.averageItemLevel or "—");
	if self.blizzardItemLevel then details:Add(ExaminerNS.L["Blizzard Average Item Level"],ExaminerNS.Compat.FormatNumber(self.blizzardItemLevel)); end
	if (iLvlMin and iLvlMax) then
		details:Add(ExaminerNS.L["Min / Max Item Levels"],iLvlMin.." / "..iLvlMax);
	end
	-- Cache
	if (ex.isCacheEntry) then
		details:Add("Cached Entry");
		details:Add("Zone",ex.info.zone);
		details:Add("Date",date("%a, %b %d, %Y",ex.info.time));
		details:Add("Time",date("%H:%M:%S",ex.info.time));
		details:Add("Time Ago",ex:FormatTime(time() - ex.info.time));
		if ex.gear and ex.gear.time then details:Add("Gear snapshot age",ex:FormatTime(time()-ex.gear.time)); end
	end
end

--------------------------------------------------------------------------------------------------------
--                                         Update Stat Lists                                          --
--------------------------------------------------------------------------------------------------------

-- Show Resistances
local function UpdateResistances()
	for i = 1, 5 do
		local statToken = (LibGearExam.MagicSchools[i].."RESIST");
		if (ex.unitStats[statToken]) or (ex.isComparing and ex.compareStats[statToken]) then
			local statText = LibGearExam:GetStatValue(statToken,ex.unitStats,ex.isComparing and ex.compareStats,ex.info.level,cfg.combineAdditiveStats,cfg.percentRatings);
			resists[i].value:SetText(statText);
		else
			resists[i].value:SetText("");
		end
	end
end

-- ScrollBar: Update Stat List
local function UpdateShownItems(self)
	FauxScrollFrame_Update(self,displayList.count,#entries,ITEM_HEIGHT);
	local rowWidth=displayList.count > #entries and 196 or 212;
	entries[1]:SetWidth(rowWidth);
	local index = self.offset;
	for i = 1, #entries do
		index = (index + 1);
		local entry = entries[i];
		if (index <= displayList.count) then
			if (displayList[index].value) then
				entry.left:SetTextColor(1,1,1);
				entry.left:SetFormattedText("  %s",displayList[index].name);
				if ( displayList[index] and displayList[index].name == "GearScore" and displayList[index].value ) then
					local color = ex.gsQualityColor;
					if color and color.GetRGB then
						entry.right:SetTextColor(color:GetRGB());
					else
						entry.right:SetTextColor(1, 1, 0);
					end
				else 
					entry.right:SetTextColor(1.0,1.0,0.0);
				end
				entry.right:SetText(displayList[index].value);
			elseif (displayList[index].name) then
				entry.left:SetTextColor(0.5,0.75,1.0);
				entry.left:SetFormattedText("%s:",displayList[index].name);
				entry.right:SetText("");
			else
				entry.left:SetText("");
				entry.right:SetText("");
			end

			local row=displayList[index];
			local valueWidth=TextWidth(tostring(row.value or ""));
			local rightWidth=math.min(rowWidth,math.max(rowWidth*0.2,valueWidth));
			local leftWidth=math.max(0,math.min(rowWidth*0.8,rowWidth-rightWidth-6));
			local fullLabel=row.name and (row.value~=nil and ("  "..row.name) or (row.name..":")) or "";
			local label,truncated=FitLabel(fullLabel,leftWidth);
			entry.left:SetWidth(leftWidth); entry.left:SetText(label);
			entry.right:SetWidth(rightWidth);
			entry.tip.tip=truncated and not row.link and (row.name..(row.tip and ("\n\n"..row.tip) or "")) or row.tip;
			entry.tip.link=row.link;
			if entry.tip.tip or entry.tip.link then entry.tip:Show(); else entry.tip:Hide(); end

			entry:Show();
		else
			entry:Hide();
		end
	end
end

-- Adds a List Entry
local function AddListEntry(name,value,tip,link)
	if name and value==nil and displayList.count>0 and displayList[displayList.count].name then AddListEntry(); end
	displayList.count = (displayList.count + 1);
	local tbl = displayList[displayList.count] or {};
   	displayList[displayList.count] = tbl;
	tbl.name = name;
	tbl.value = ExaminerNS.Compat.IsNumber(value) and ExaminerNS.Compat.FormatNumber(value) or value;
	tbl.tip = tip;
	tbl.link = link;
end


-- Build Stat List
local function BuildStatList()
	displayList.count = 0;
	AddListEntry(ExaminerNS.L["Item Levels"]);
	AddListEntry(ExaminerNS.L["Average Item Level"],ex.averageItemLevel or "—");
	if mod.blizzardItemLevel then AddListEntry(ExaminerNS.L["Blizzard Average Item Level"],mod.blizzardItemLevel); end
	if ex.gear and ex.gear.min then AddListEntry(ExaminerNS.L["Min / Max Item Levels"],ExaminerNS.Compat.FormatNumber(ex.gear.min).." / "..ExaminerNS.Compat.FormatNumber(ex.gear.max)); end
	if type(ex.gs)=="number" then AddListEntry("GearScore",ex.gs); end
	if ex.gear then
		if ex.gear.state=="loading" then AddListEntry(ExaminerNS.L["Equipment"],ExaminerNS.L["Loading…"]);
		elseif ex.gear.state=="unavailable" then AddListEntry(ExaminerNS.L["Equipment"],ExaminerNS.L["Not available"]); end
	end
	local needHeader;
	local shown={};
	-- Build display table
	for _, statCat in ipairs(StatEntryOrder) do
		needHeader = 1;
		for _, statToken in ipairs(statCat) do
			if not shown[statToken] and ((ex.unitStats[statToken]) or (ex.isComparing and ex.compareStats[statToken])) then
				shown[statToken]=true;
				if (needHeader) then
					AddListEntry(statCat[0]);
					needHeader = nil;
				end
				local value, tip = LibGearExam:GetStatValue(statToken,ex.unitStats,ex.isComparing and ex.compareStats,ex.info.level,cfg.combineAdditiveStats,cfg.percentRatings);
				AddListEntry(LibGearExam:FormatStatName(statToken,cfg.percentRatings),value,tip);
			end
		end
	end
	local ratingTokens={};
	local available={};
	for token,value in pairs(ex.unitStats) do if ExaminerNS.Compat.IsNumber(value) then available[token]=true; end end
	if ex.isComparing then for token,value in pairs(ex.compareStats) do if ExaminerNS.Compat.IsNumber(value) then available[token]=true; end end end
	for token in pairs(available) do
		if not shown[token] and token~="SANCTIFIED-SET" and token~="DPS" then ratingTokens[#ratingTokens+1]=token; end
	end
	table.sort(ratingTokens);
	if #ratingTokens>0 then AddListEntry(ExaminerNS.L["Additional Stats"]); end
	for _,token in ipairs(ratingTokens) do
		local value,tip=LibGearExam:GetStatValue(token,ex.unitStats,ex.isComparing and ex.compareStats,ex.info.level,cfg.combineAdditiveStats);
		AddListEntry(ExaminerNS.Gear.labels[token] or LibGearExam.StatNames[token] or token,value,tip);
	end
	-- Add Sets
	if (next(ex.info.Sets)) then
		AddListEntry(ExaminerNS.L["Sets"]);
	end
	for setName, setEntry in next, ex.info.Sets do
		AddListEntry(setName,setEntry.count.."/"..setEntry.max);
	end
	-- Add Padding + Update Resistances + Shown Items
	AddListEntry();
	UpdateResistances();
	UpdateShownItems(mod.scroll);
end

-- Build the Shown List
function mod:BuildShownList()
	BuildStatList();
end

--------------------------------------------------------------------------------------------------------
--                                           Widget Creation                                          --
--------------------------------------------------------------------------------------------------------

-- Resistance Boxes
for i = 1, 5 do
	local t = CreateFrame("Frame",nil,mod.page);
	t:SetSize(32,29);

	t.texture = t:CreateTexture(nil,"BACKGROUND");
	t.texture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ResistanceIcons");
	local normHeight, offset = 0.11328125, 0.00;
	t.texture:SetTexCoord(offset,1 - offset,(i - 1 + offset) * normHeight,(i - offset) * normHeight);
	t.texture:SetAllPoints();

	t.value = t:CreateFontString(nil,"ARTWORK","GameFontNormal");
	t.value:SetFont(GameFontNormal:GetFont(),12,"OUTLINE");
	t.value:SetPoint("BOTTOM",1,3);
	t.value:SetTextColor(1,1,0);

	if (i == 1) then
 		t:SetPoint("TOPLEFT",36,-9);
	else
 		t:SetPoint("LEFT",resists[i - 1],"RIGHT");
	end

	resists[i] = t;
	t:SetShown(not ExaminerNS.Compat.isRetail);
end

-- Stat Entries
local StatEntry_OnEnter = function(self,motion)
	if self.tip or self.link then
		gtt:SetOwner(self,"ANCHOR_RIGHT");
		if self.link then
			gtt:SetHyperlink(self.link);
			if self.tip then gtt:AddLine(self.tip,0.8,0.8,0.8,true); end
		else gtt:SetText(self.tip); end
		gtt:Show();
	end
end
for i = 1, 20 do
	local t = CreateFrame("Frame",nil,mod.page);
	t:SetSize(200,ITEM_HEIGHT);
	t.id = i;

	if (i == 1) then
		t:SetPoint("TOPLEFT",10,ExaminerNS.Compat.isRetail and -12 or -46);
	else
		t:SetPoint("TOPLEFT",entries[i - 1],"BOTTOMLEFT");
		t:SetPoint("TOPRIGHT",entries[i - 1],"BOTTOMRIGHT");
	end

	t.left = t:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
	t.left:SetPoint("LEFT");
	t.left:SetJustifyH("LEFT"); t.left:SetWordWrap(false); t.left:SetMaxLines(1);

	t.right = t:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
	t.right:SetPoint("RIGHT");
	t.right:SetWordWrap(false); t.right:SetMaxLines(1);
	t.right:SetTextColor(1,1,0);
	t.right:SetJustifyH("RIGHT");

	t.tip = CreateFrame("Frame",nil,t);
	t.tip:SetAllPoints(t);
	t.tip:Hide();
	t.tip:SetScript("OnEnter",StatEntry_OnEnter);
	t.tip:SetScript("OnLeave",ex.HideGTT);
	t.tip:EnableMouse(true);

	entries[i] = t;
end

-- Scroll
mod.scroll = CreateFrame("ScrollFrame","Examiner"..mod.token.."Scroll",mod.page,"FauxScrollFrameTemplate");
mod.scroll:SetPoint("TOPLEFT",entries[1]);
mod.scroll:SetPoint("BOTTOMRIGHT",entries[#entries],-3,-1);
mod.scroll:SetScript("OnVerticalScroll",function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,ITEM_HEIGHT,UpdateShownItems) end);
