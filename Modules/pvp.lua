local _, ExaminerNS = ...; if ExaminerNS.blocked then return; end
local ex = Examiner;
local C = ExaminerNS.Compat;
local L,P = ExaminerNS.L,ExaminerNS.PvP;
if not ExaminerNS.Compat.hasLegacyHonor then return; end

-- Module
local mod = ex:CreateModule("PvP",PLAYER_V_PLAYER);
mod.help = ExaminerNS.L["Honor Details"];
mod:CreatePage(true,PLAYER_V_PLAYER);
mod:HasButton(true);
mod.canCache = true;

-- Variables
local labels = {};
mod.labels = labels;
local sideHeaders = {};
local arena = {}; mod.arenaRows=arena;
local extraHonor=mod.page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
extraHonor:SetPoint("TOPLEFT",16,-88); extraHonor:SetPoint("TOPRIGHT",-16,-88); extraHonor:SetJustifyH("LEFT");
local progress;
if C.isEra then
    progress=CreateFrame("StatusBar",nil,mod.page); mod.rankProgressBar=progress;
    progress:SetPoint("TOPLEFT",extraHonor,"BOTTOMLEFT",0,-4); progress:SetPoint("TOPRIGHT",extraHonor,"BOTTOMRIGHT",0,-4);
    progress:SetHeight(10); progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
    progress:SetStatusBarColor(0.2,0.55,0.85); progress:SetMinMaxValues(0,100);
    local background=progress:CreateTexture(nil,"BACKGROUND"); background:SetAllPoints(); background:SetColorTexture(0,0,0,0.65);
    progress:Hide();
end

-- Data Variables
local hd = {};
local function RankText(value,saved)
    if not C.IsNumber(value) or value<5 or value>18 or value%1~=0 then return; end
    local name;
    if not ex.isCacheEntry and ex.unit then name=C.Text(C.Try(GetPVPRankInfo,value,ex.unit));
    else
        name=C.Text(saved);
        local faction=ex.info.factionGroup;
        if not name and (faction=="Alliance" or faction=="Horde") then
            name=C.Text(C.Try(GetText,"PVP_RANK_"..value..(faction=="Alliance" and "_1" or "_0"),ex.info.sex));
        end
    end
    return name and name~="" and format("%s (%s %d)",name,L.Rank,value-4) or (L.Rank.." "..(value-4)),name;
end

-- Inspect lifecycle and cache

function mod:OnInspect(unit)
	if (ex.isSelf) then
		self:LoadHonorNormal();
	end
end
function mod:OnInspectReady()
	if ex.isSelf then self:LoadHonorNormal();
	else self.waiting=true; ex.pvpData={state="loading"}; self:HasData(true); ex:RequestHonorData(); end
	if not ex.isSelf and C.IsTrue(C.Try(HasInspectHonorData)) then self:LoadHonorNormal(); end
end

function mod:OnHonorReady()
	self:LoadHonorNormal();
end

function mod:OnCacheLoaded(entry,unit)
	self:OnClearInspect();
	if (entry.Honor) then
		self:HasData(true);
		-- Honor
		wipe(hd);
		for name, value in next, entry.Honor do
			hd[name] = value;
		end
		self:UpdateHonor();
	end
end
function mod:OnDataTimeout()
	self.waiting=nil; self:UpdateHonor();
	ex.pvpData={state=self.visibleData and "ready" or "unavailable"};
end

function mod:OnCache(entry)
	if (self:CanCache()) and (next(hd)) then
		local session=ExaminerNS.Inspector.active;
		local capture=session and session.capture;
		local previous=entry.Honor;
		local stored=capture and C.IsTable(previous) and previous.capture==capture and CopyTable(previous) or {};
		if hd.currentRank~=nil and hd.currentRank~=stored.currentRank then stored.currentRankName=nil; end
		if hd.lifetimeRank~=nil and hd.lifetimeRank~=stored.lifetimeRank then stored.lifetimeRankName=nil; end
		for key,value in pairs(hd) do stored[key]=ExaminerNS.Cache.Copy(value); end
		stored.capture=capture; entry.Honor=stored;
	end
end

function mod:OnClearInspect()
    if progress then progress:Hide(); progress:SetValue(0); end
	self.waiting,self.visibleData,ex.pvpData=nil,nil,nil;
	self:HasData(nil);
	-- Header
	self.rankIcon:Hide();
	self.rankTitle:SetText("");
	self.highestRank:SetText(""); self.highestRank:Hide();
	-- Clear Honor
	wipe(hd);
	extraHonor:SetText("");
	for _,row in ipairs(arena) do row:Hide(); end
	for i = 1, 9 do
		labels[i]:Hide();
	end
	for _, header in ipairs(sideHeaders) do header:Hide(); end
	labels[9]:SetTextColor(1,1,0);
end

-- Honor data and rendering

-- Load Honor Normal
function mod:LoadHonorNormal()
	wipe(hd);
	for key,value in pairs(ExaminerNS.PvP.Honor(ex.unit,ex.isSelf)) do hd[key]=value; end
	local _,currentName=RankText(hd.currentRank); local _,highestName=RankText(hd.lifetimeRank);
	hd.currentRankName,hd.lifetimeRankName=currentName,highestName;
	self.waiting=nil;
	if C.isTBC then
		hd.arenas={};
		for index=1,3 do hd.arenas[index]=ExaminerNS.PvP.Arena(index,ex.isSelf); end
	end
	-- Update
	self:UpdateHonor();
	ex.pvpData={state=self.visibleData and "ready" or "unavailable"};
end

-- Honor Update
function mod:UpdateHonor()
    if progress then
        local value=C.Number(hd.rankProgress);
        local valid=value and value>=0 and value<=100;
        hd.rankProgress=valid and value or nil;
        progress:SetValue(valid and value or 0); progress:SetShown(valid and true or false);
    end
	-- Show Rank
	local rankValue=hd.currentRank or hd.lifetimeRank;
	if C.IsNumber(rankValue) and rankValue>=5 and rankValue<=18 and rankValue%1==0 then
		self.rankIcon.texture:SetTexture("Interface\\PvPRankBadges\\PvPRank"..format("%.2d", rankValue - 4));
		self.rankIcon.texture:SetTexCoord(0, 1, 0, 1);
		self.rankIcon.tip=RankText(rankValue,hd.currentRank~=nil and hd.currentRankName or hd.lifetimeRankName);
		self.rankTitle:SetText(self.rankIcon.tip);
		self.rankIcon:Show();
	else self.rankIcon:Hide(); self.rankTitle:SetText(""); end
	if self.page.header then self.page.header:SetShown(not self.rankIcon:IsShown()); end
	local highest=C.isEra and RankText(hd.lifetimeRank,hd.lifetimeRankName);
	self.highestRank:SetText(highest and (L["Highest PvP rank"]..": "..highest) or ""); self.highestRank:SetShown(highest~=nil and highest~=false);
	local offset=highest and 16 or 0;
	for i,label in ipairs(labels) do
		label:ClearAllPoints();
		if (i-1)%3==0 then label:SetPoint("TOP",-28,-36-(i-1)/3*12-offset);
		else label:SetPoint("LEFT",labels[i-1],"RIGHT"); end
	end
	extraHonor:ClearAllPoints(); extraHonor:SetPoint("TOPLEFT",16,-88-offset); extraHonor:SetPoint("TOPRIGHT",-16,-88-offset);
	-- Show Kills/Honor
	local values = {hd.todayHK, hd.yesterdayHK, hd.lifetimeHK, hd.todayHonor, hd.yesterdayHonor};
	for i = 4, 9 do
		local value = values[i - 3];
		labels[i]:SetText(C.IsNumber(value) and C.FormatNumber(value) or "");
		labels[i]:SetShown(C.IsNumber(value));
	end
	for i = 1, 3 do
		labels[i]:SetShown(C.IsNumber(values[i]) or C.IsNumber(values[i + 3]));
	end
	sideHeaders[1]:SetShown(C.IsNumber(hd.todayHK) or C.IsNumber(hd.yesterdayHK) or C.IsNumber(hd.lifetimeHK));
	sideHeaders[2]:SetShown(C.IsNumber(hd.todayHonor) or C.IsNumber(hd.yesterdayHonor));
	local detail={};
	if C.isEra then
		for _,field in ipairs({{"todayDK","Today's dishonorable kills"},{"lifetimeDK","Lifetime dishonorable kills"},
			{"thisWeekHK","This week's honorable kills"},{"thisWeekHonor","This week's honor"},
			{"lastWeekHK","Last week's honorable kills"},{"lastWeekHonor","Last week's honor"},
			{"lastWeekStanding","Last week's standing"},{"rankProgress","Rank progress (%)"}}) do
			if C.IsNumber(hd[field[1]]) then
				detail[#detail+1]="|cff99bfff"..L[field[2]]..":|r |cffffd100"..C.FormatNumber(hd[field[1]]).."|r";
			end
		end
	end
	extraHonor:SetText(table.concat(detail,"\n"));
	for index,row in ipairs(arena) do
		local data=hd.arenas and hd.arenas[index];
		row:SetShown(C.IsTable(data));
		if C.IsTable(data) then
			row.title:SetText(data.size.."v"..data.size..(data.name and (" — "..data.name) or ""));
			row.rating:SetText(C.IsNumber(data.rating) and C.FormatNumber(data.rating) or "");
			local record=data.record;
			row.record:SetText(record and P.FormatRecord(record) or "");
			row.personal:SetText(C.IsNumber(data.personal) and (L["Personal rating"]..": "..C.FormatNumber(data.personal)) or "");
		end
	end
	local visible=self.rankIcon:IsShown() or self.highestRank:IsShown() or #detail>0;
	for i=4,9 do if labels[i]:IsShown() then visible=true; end end
	for _,row in ipairs(arena) do if row:IsShown() then visible=true; end end
	self.visibleData=visible and true or nil;
	self:HasData(self.visibleData or self.waiting);
end



-- Widgets

-- Rank Icon
mod.rankIcon = CreateFrame("Frame",nil,mod.page);
mod.rankIcon:SetPoint("TOPLEFT",12,-12);
mod.rankIcon:SetWidth(18);
mod.rankIcon:SetHeight(18);
mod.rankIcon:EnableMouse(1);
mod.rankIcon:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_BOTTOMRIGHT"); GameTooltip:SetText(self.tip) end)
mod.rankIcon:SetScript("OnLeave",ex.HideGTT);
mod.rankIcon.texture = mod.rankIcon:CreateTexture(nil,"ARTWORK");
mod.rankIcon.texture:SetAllPoints();
mod.rankTitle=mod.page:CreateFontString(nil,"ARTWORK","GameFontNormalSmall");
mod.rankTitle:SetPoint("TOPLEFT",40,-14); mod.rankTitle:SetPoint("TOPRIGHT",-12,-14); mod.rankTitle:SetJustifyH("LEFT");
mod.highestRank=mod.page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
mod.highestRank:SetPoint("TOPLEFT",40,-31); mod.highestRank:SetPoint("TOPRIGHT",-12,-31); mod.highestRank:SetJustifyH("LEFT"); mod.highestRank:Hide();

-- Honor Labels
for i = 1, 9 do
	local l = mod.page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
	l:SetWidth(70);

	if (i <= 3) then
		l:SetText(L[i == 1 and ExaminerNS.L["Today"] or i == 2 and ExaminerNS.L["Yesterday"] or ExaminerNS.L["Lifetime"]]);
		l:SetTextColor(0.5,0.75,1);
	else
		l:SetTextColor(1,1,0);
	end

	if ((i - 1) % 3 == 0) then
		l:SetPoint("TOP",-28,-36 - (i - 1) / 3 * 12);
	else
		l:SetPoint("LEFT",labels[i - 1],"RIGHT");
	end

	labels[i] = l;
	l:Hide();
end

-- Honor Label Side Headers
local t = mod.page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
t:SetPoint("RIGHT",labels[4],"LEFT");
t:SetWidth(70);
t:SetJustifyH("LEFT");
t:SetText(L["Honor Kills"]);
t:SetTextColor(0.5,0.75,1);
sideHeaders[1] = t; t:Hide();

t = mod.page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
t:SetPoint("RIGHT",labels[7],"LEFT");
t:SetWidth(70);
t:SetJustifyH("LEFT");
t:SetText(L["Honor Points"]);
t:SetTextColor(0.5,0.75,1);
sideHeaders[2] = t; t:Hide();
if C.isTBC then for index=1,3 do
    local row=CreateFrame("Frame",nil,mod.page); row:SetHeight(58);
    row:SetPoint("TOPLEFT",16,-112-(index-1)*60); row:SetPoint("TOPRIGHT",-16,-112-(index-1)*60);
    row.title=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); row.title:SetPoint("TOPLEFT"); row.title:SetPoint("TOPRIGHT",-58,0); row.title:SetJustifyH("LEFT"); row.title:SetTextColor(0.65,0.8,1);
    row.rating=row:CreateFontString(nil,"ARTWORK","GameFontNormalSmall"); row.rating:SetPoint("TOPRIGHT");
    row.record=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); row.record:SetPoint("TOPLEFT",0,-17);
    row.personal=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); row.personal:SetPoint("TOPLEFT",0,-33);
    row:Hide(); arena[index]=row;
end end
if C.isEra then
    local updates=CreateFrame("Frame"); mod.selfUpdateFrame=updates;
    updates:RegisterEvent("PLAYER_PVP_KILLS_CHANGED");
    updates:RegisterEvent("PLAYER_PVP_RANK_CHANGED");
    updates:SetScript("OnEvent",function()
        local session=ExaminerNS.Inspector.active;
        if ex.isSelf and not ex.isCacheEntry and session and not session.cached and ExaminerNS.Inspector:Valid(session) then
            mod:LoadHonorNormal(); ex:CachePlayer();
        end
    end);
end
