local _,ns=...;
if ns.blocked or ns.Compat.hasLegacyHonor then return; end
local ex,C=ns.ex,ns.Compat;
local L,P=ns.L,ns.PvP;

-- Widgets
local mod=ex:CreateModule("PvP",PLAYER_V_PLAYER);
mod.help=ns.L["Available honor and rated PvP information"]; mod.canCache=true;
mod:CreatePage(true,PLAYER_V_PLAYER); mod:HasButton(true);
local rankIcon=CreateFrame("Frame",nil,mod.page); mod.rankIcon=rankIcon;
rankIcon:SetPoint("TOPLEFT",12,-12); rankIcon:SetSize(22,22); rankIcon:EnableMouse(true);
rankIcon.texture=rankIcon:CreateTexture(nil,"ARTWORK"); rankIcon.texture:SetAllPoints();
rankIcon:SetScript("OnEnter",function(self)
    if self.tip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(self.tip); GameTooltip:Show(); end
end);
rankIcon:SetScript("OnLeave",ex.HideGTT); rankIcon:Hide();
local fields={{"honorLevel","Honor level"},{"lifetimeHK","Lifetime honorable kills"},{"arena2","2v2 rating"},
    {"arena3","3v3 rating"},{"rbg","Rated battleground rating"},{"shuffle","Solo shuffle rating"},{"blitz","Battleground Blitz rating"},{"arena5","5v5 rating"},
    {"rankProgress","Rank progress (%)"},{"honorCurrent","Rank points"},{"todayHK","Today's honorable kills"},
    {"todayHonor","Today's honor"},{"yesterdayHK","Yesterday's honorable kills"},{"yesterdayHonor","Yesterday's honor"}};
local rows={}; mod.rows=rows;
for i=1,#fields do
    local row=CreateFrame("Frame",nil,mod.page); row:SetHeight(20);
    row.label=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
    row.label:SetPoint("TOPLEFT"); row.label:SetPoint("TOPRIGHT",-64,0);
    row.label:SetJustifyH("LEFT"); row.label:SetTextColor(0.65,0.8,1);
    row.value=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
    row.value:SetPoint("TOPRIGHT"); row.value:SetWidth(60); row.value:SetJustifyH("RIGHT");
    row.record=row:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
    row.record:SetPoint("TOPLEFT",4,-16); row.record:SetPoint("TOPRIGHT",0,-16); row.record:SetJustifyH("LEFT");
    row.record:SetTextColor(0.8,0.8,0.8);
    rows[i]=row;
end
local progress;
if C.isForever then
    progress=CreateFrame("StatusBar",nil,rows[9]); mod.rankProgressBar=progress;
    progress:SetPoint("TOPLEFT",0,-17); progress:SetPoint("TOPRIGHT",0,-17); progress:SetHeight(10);
    progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");
    progress:SetStatusBarColor(0.2,0.55,0.85); progress:SetMinMaxValues(0,100);
    local background=progress:CreateTexture(nil,"BACKGROUND"); background:SetAllPoints(); background:SetColorTexture(0,0,0,0.65);
    progress:Hide();
end
local honor=mod.page:CreateFontString(nil,"ARTWORK","GameFontNormalSmall"); honor:SetText(L["Honor"]);
local ratings=mod.page:CreateFontString(nil,"ARTWORK","GameFontNormalSmall"); ratings:SetText(L["Season ratings"]);
local status=mod.page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); mod.status=status;
status:SetPoint("BOTTOMLEFT",16,20); status:SetPoint("BOTTOMRIGHT",-16,20); status:SetJustifyH("LEFT"); status:SetTextColor(0.65,0.65,0.65);
local rankTitle=mod.page:CreateFontString(nil,"ARTWORK","GameFontNormalSmall"); mod.rankTitle=rankTitle;
rankTitle:SetPoint("TOPLEFT",40,-16); rankTitle:SetPoint("TOPRIGHT",-12,-16); rankTitle:SetJustifyH("LEFT");

-- Data adapters
local Record=P.Record;
local function Personal(data,key,fn,bracket)
    if type(fn)~="function" then return; end
    -- Returns 12/13 contain round totals.
    local ok,rating,_,_,played,won,weeklyPlayed,weeklyWon,_,_,_,_,roundsPlayed,roundsWon=pcall(fn,bracket);
    if not ok then ns.Record("api-error",tostring(rating)); return; end
    data[key]=C.Number(rating);
    if key=="shuffle" then data.records[key]=Record(roundsPlayed,roundsWon,true);
    else data.records[key]=Record(played,won); end
    data.weekly[key]=Record(weeklyPlayed,weeklyWon);
end
function mod:Draw(data)
    P.Filter(data);
    if progress then progress:Hide(); progress:SetValue(0); end
    rankIcon:Hide(); rankIcon.tip=nil; rankIcon.texture:SetTexture(nil);
    rankTitle:SetText("");
    local foreverRank=C.isForever and P.Count(data.foreverRank);
    if mod.page.header then mod.page.header:SetShown(not foreverRank); end
    if foreverRank then
        local faction=C.Text(ex.info.factionGroup);
        local sex=C.Number(ex.info.sex);
        if not ex.isCacheEntry and ex.unit then
            faction=C.Text(C.Try(UnitFactionGroup,ex.unit),faction);
            sex=C.Number(C.Try(UnitSex,ex.unit),sex);
        end
        local firstRank=Enum and Enum.PvPRanks and C.Number(Enum.PvPRanks.Rank_1);
        local name;
        if foreverRank>0 and foreverRank<=14 and firstRank and (faction=="Alliance" or faction=="Horde") then
            local key="PVP_RANK_"..(firstRank+foreverRank-1)..(faction=="Alliance" and "_1" or "_0");
            name=C.Text(C.Try(GetText,key,sex));
        end
        rankTitle:SetText((name or L[foreverRank==0 and "Unranked" or "Rank"])..(foreverRank>0 and (" ("..foreverRank..")") or ""));
        if foreverRank>0 and foreverRank<=14 then
            local atlas="UI-Character-Info-Honor-Icon-"..foreverRank;
            if C.IsTable(C.Try(C_Texture and C_Texture.GetAtlasInfo,atlas)) then rankIcon.texture:SetAtlas(atlas);
            else rankIcon.texture:SetTexture("Interface\\PvPRankBadges\\PvPRank"..string.format("%02d",foreverRank)); end
            rankIcon.tip=rankTitle:GetText(); rankIcon:Show();
        end
    end
    self.visibleFields=foreverRank and 1 or 0;
    local y=-44; local group;
    honor:Hide(); ratings:Hide();
    for _,index in ipairs({1,2,9,10,11,12,13,14,3,4,8,5,6,7}) do
        local field=fields[index];
        local key,label=field[1],field[2]; local row=rows[index]; local value=data[key];
        local valueWidth=key=="honorCurrent" and 110 or 60;
        row.value:SetWidth(valueWidth); row.label:SetPoint("TOPRIGHT",-valueWidth-4,0);
        row.unavailable=not C.IsNumber(value);
        row.label:SetText(L[label]); row.value:SetText(row.unavailable and "" or C.FormatNumber(value));
        if key=="honorCurrent" and C.IsNumber(value) and P.Count(data.honorNextLevel) then
            row.value:SetText(C.FormatNumber(value).." / "..C.FormatNumber(data.honorNextLevel));
        end
        row.value:SetTextColor(1,0.82,0);
        local record=data.records and data.records[key];
        local valid=C.IsTable(record) and Record(record.played,record.won,record.rounds);
        -- Records may be available without a rating.
        local wins=P.Count(data.wins and data.wins[key]);
        local supported=not row.unavailable or (valid and true or false) or wins~=nil;
        local recordText="";
        if valid then recordText=P.FormatRecord(valid);
        elseif wins~=nil then recordText=P.FormatWins(wins); end
        local weekly=data.weekly and data.weekly[key];
        weekly=C.IsTable(weekly) and Record(weekly.played,weekly.won,weekly.rounds);
        if weekly then supported=true; end
        if weekly then recordText=recordText..(recordText~="" and "\n" or "")..L["This week"]..": "..P.FormatRecord(weekly); end
        row.record:SetText(recordText);
        row.record:SetShown(recordText~="");
        row:SetHeight(recordText~="" and (valid or wins~=nil) and weekly and 46 or recordText~="" and 32 or 20);
        if index==9 and progress and not row.unavailable then
            progress:SetValue(value); progress:Show(); row:SetHeight(36);
        end
        row:SetShown(supported);
        if supported then
            self.visibleFields=self.visibleFields+1;
            local section=(index<=2 or index>8) and "honor" or "ratings";
            if section~=group then
                if group then y=y-6; end
                local header=section=="honor" and honor or ratings;
                header:ClearAllPoints(); header:SetPoint("TOPLEFT",16,y); header:Show(); y=y-18; group=section;
            end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",16,y); row:SetPoint("TOPRIGHT",-16,y); y=y-row:GetHeight();
        end
    end
    status:SetText(data.state=="loading" and (LOADING or "Loading...") or "");
end
function mod:Read(unit)
    local session=ns.Inspector.active;
    local current=not ex.isCacheEntry and session and not session.cached and ns.Inspector:Valid(session)
        and session.serverReady and ns.Inspector.notificationGUID==session.guid and C.IsTrue(UnitIsUnit(unit,session.unit));
    -- Blizzard can already have a current response without a new honor event.
    if not ex.isSelf and ex.requestedHonorData and session and ns.Inspector:Valid(session)
        and session.serverReady and ns.Inspector.notificationGUID==session.guid
        and C.IsTrue(C.Try(HasInspectHonorData)) then session.honorReady=true; end
    local waiting=not ex.isSelf and current and ex.requestedHonorData and not session.honorReady;
    local data={time=time(),capture=current and session.capture or nil,season=P.Count(C.Try(GetCurrentArenaSeason)),state=waiting and "loading" or "unavailable",records={},weekly={},wins={}};
    if C.isRetail then data.honorLevel=C.Number(C.Try(UnitHonorLevel,unit)); end
    local honorData;
    if ex.isSelf then
        honorData=P.Honor(unit,true);
        local api=C_PvP or {}; local personal=api.GetPersonalRatedInfo or GetPersonalRatedInfo;
        Personal(data,"arena2",personal,1); Personal(data,"arena3",personal,2); Personal(data,"rbg",personal,4);
        if C.isMists then Personal(data,"arena5",personal,3); end
        if C.isRetail then Personal(data,"shuffle",personal,7); Personal(data,"blitz",personal,9); end
    elseif current and session.honorReady then
        honorData=P.Honor(unit,false);
        for index,size in ipairs(C.profile.arenaBrackets) do
            local arena=ns.PvP.Arena(index,false); local key="arena"..size;
            if arena then data[key]=arena.rating; data.records[key]=arena.record; data.weekly[key]=arena.weekly; end
        end
        local paper=C_PaperDollInfo or {};
        for key,fn in pairs({rbg=paper.GetInspectRatedBGData,shuffle=paper.GetInspectRatedSoloShuffleData,blitz=paper.GetInspectRatedBGBlitzData}) do
            local info=(key=="rbg" or C.profile.soloRated) and C.Try(fn);
            if C.IsTable(info) then
                data[key]=C.Number(info.rating);
                if key=="shuffle" then data.records[key]=Record(info.roundsPlayed,info.roundsWon,true);
                elseif key=="rbg" then data.records[key]=Record(info.played,info.won);
                else data.records[key]=Record(info.gamesPlayed,info.gamesWon); end
                if key=="rbg" and info.played==nil then data.wins[key]=ns.PvP.Count(info.won); end
            end
        end
    end
    if honorData then
        data.lifetimeHK=honorData.lifetimeHK; data.honorLevel=C.Number(honorData.honorLevel,data.honorLevel);
        if C.isForever then
            for _,key in ipairs({"foreverRank","rankProgress","honorCurrent","honorNextLevel","todayHK"}) do data[key]=honorData[key]; end
            data.honorLevel=nil;
        end
    end
    P.Filter(data);
    if not waiting then
        if data.foreverRank~=nil then data.state="ready"; end
        for _,field in ipairs(fields) do
            local key=field[1];
            if C.IsNumber(data[key]) or data.records[key] or data.weekly[key] or ns.PvP.Count(data.wins[key]) then data.state="ready"; break end
        end
    end
    if waiting then data.message="Waiting for PvP inspection data.";
    elseif data.state~="ready" then data.message="No readable PvP data is available for this inspection."; end
    ex.pvpData=data; self:Draw(data); self:HasData(self.visibleFields>0 or waiting);
end
-- Inspect lifecycle and cache
function mod:OnInspect(unit)
    self:HasData(true);
    if ex.isSelf then
        C.Try(C_PvP and C_PvP.RequestRatedInfo or RequestRatedInfo);
        self:Read(unit);
    else self:Draw({state="loading"}); end
end
function mod:OnInspectReady(unit)
    if not ex.isSelf then ex:RequestHonorData(); end
    self:Read(unit);
end
function mod:OnHonorReady() self:Read(ex.unit); end
function mod:OnClearInspect()
    if progress then progress:Hide(); progress:SetValue(0); end
    ex.pvpData=nil; rankIcon:Hide(); rankIcon.tip=nil; rankIcon.texture:SetTexture(nil); rankTitle:SetText(""); self:HasData(nil);
end
function mod:OnDataTimeout()
    local data=ex.pvpData or {};
    if data.state=="loading" or not ex.pvpData then
        data.state="unavailable"; data.message="PvP inspection data could not be loaded."; ex.pvpData=data; self:Draw(data);
    end
end
function mod:OnCache(entry)
    local data=ex.pvpData;
    if not self:CanCache() or not data or data.state~="ready" then return; end
    local previous=entry.PvP;
    local stored=ns.Cache.Copy(data);
    if data.capture and C.IsTable(previous) and previous.capture==data.capture and previous.season==data.season then
        stored=ns.Cache.Copy(previous);
        for key,value in pairs(data) do
            if key=="records" or key=="weekly" or key=="wins" then
                stored[key]=stored[key] or {};
                for field,record in pairs(value) do stored[key][field]=ns.Cache.Copy(record); end
            else stored[key]=ns.Cache.Copy(value); end
        end
    end
    stored.cached=nil; entry.PvP=P.Filter(stored);
end
function mod:OnCacheLoaded(entry)
    local data=ns.Cache.Copy(entry.PvP) or {message="This cache has no PvP snapshot."}; data.cached=true;
    ex.pvpData=data; self:Draw(data); self:HasData(self.visibleFields>0);
end
if C.isRetail or C.isForever or C.isMists then
    local updates=CreateFrame("Frame"); mod.selfUpdateFrame=updates;
    if C.isRetail or C.isMists then updates:RegisterEvent("PVP_RATED_STATS_UPDATE"); end
    if C.isForever then
        updates:RegisterEvent("UPDATE_FACTION");
        updates:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED");
    end
    updates:SetScript("OnEvent",function()
        local session=ns.Inspector.active;
        if ex.isSelf and not ex.isCacheEntry and session and not session.cached and ns.Inspector:Valid(session) then
            mod:Read(ex.unit); ex:CachePlayer();
        end
    end);
end
