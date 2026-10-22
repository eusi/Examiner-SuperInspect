local _, ns = ...;
if ns.blocked then return; end
local ex,C=ns.ex,ns.Compat;
local I={generation=0,lastRequest=-100,ownsRequest=false};
ns.Inspector=I;
local timer=CreateFrame("Frame"); I.frame=timer; timer:Hide();
local RETRY_AFTER, TIMEOUT, MAX_REQUESTS = 2,12,2;

function I:Valid(session)
    if self.active~=session or session.generation~=self.generation then return false; end
    if session.cached then return true; end
    if not C.IsTrue(UnitExists(session.unit)) then return false; end
    local guid=UnitGUID(session.unit);
    return C.IsString(guid) and guid==session.guid;
end
function I:Cancel()
    self.generation=self.generation+1;
    self.active=nil; timer:Hide();
    if self.ownsRequest then
        self.ownsRequest=false;
        C.Try(ClearInspectPlayer);
    end
    ex:UnregisterEvent("INSPECT_READY"); ex:UnregisterEvent("UPDATE_MOUSEOVER_UNIT"); ex:UnregisterEvent("INSPECT_HONOR_UPDATE");
    ex:SetScript("OnUpdate",nil);
end
function I:Clear()
    self:Cancel();
    ex.unit,ex.guid,ex.isSelf,ex.unitType,ex.canInspect=nil,nil,nil,nil,nil;
    ex.itemsLoaded,ex.isCacheEntry,ex.gear=nil,nil,nil;
    ex.averageItemLevel,ex.gs,ex.gsQualityColor=nil,nil,nil;
    ex.requestedHonorData=nil;
    wipe(ex.unitStats); wipe(ex.info);
    ex.info.Items,ex.info.Sets,ex.info.Runes={},{},{};
    ex:SetBackgroundVertex(1,1,1);
    ex:SendModuleEvent("OnClearInspect");
    ex:RefreshModuleButtons();
end
function I:CanInspect(unit)
    if C.IsTrue(UnitIsUnit(unit,"player")) then return true; end
    return C.IsTrue(C.Try(CanInspect,unit));
end
local function StaticUnit(unit)
    if unit~="target" and unit~="mouseover" then return unit; end
    local count=C.Number(GetNumGroupMembers(),0);
    local raid=C.IsTrue(IsInRaid and IsInRaid());
    for index=1,count do
        local candidate=(raid and "raid" or "party")..index;
        if C.IsTrue(UnitIsUnit(candidate,unit)) then return candidate; end
    end
    return unit;
end
function I:Start(unit, open)
    unit=C.IsString(unit) and unit or "target";
    if not C.IsTrue(UnitExists(unit)) then unit="player"; end
    unit=StaticUnit(unit);
    local guid=UnitGUID(unit);
    if not C.IsString(guid) then ns.Record("inspect", "unit identity restricted"); return false; end
    if self.active and self.active.guid==guid and GetTime()-self.active.started<1 then
        if open~=false then ex:Display(true); end return true;
    end
    self:Clear();
    local selfUnit=C.IsTrue(UnitIsUnit(unit,"player"));
    local session={generation=self.generation,unit=unit,guid=guid,started=GetTime(),requests=0,requested={},serverReady=selfUnit};
    session.capture=guid..":"..time()..":"..session.started..":"..self.generation;
    self.active=session;
    ex.unit,ex.guid,ex.isSelf=unit,guid,selfUnit;
    ex.unitType=not C.IsTrue(UnitIsPlayer(unit)) and 1 or C.IsTrue(UnitCanCooperate("player",unit)) and 3 or 2;
    ex:RefreshModuleButtons();
    ex.canInspect=self:CanInspect(unit);
    local info=ex.info;
    local name,realm=UnitName(unit);
    info.name=C.Text(name,UNKNOWN or "Unknown"); info.realm=C.Text(realm);
    if info.realm=="" then info.realm=nil; end
    info.pvpName=C.Text(C.Try(C.UnitPVPName,unit),info.name);
    info.isSelf,info.guid=selfUnit,guid;
    info.level,info.sex=C.Number(UnitLevel(unit),0),C.Number(UnitSex(unit),1);
    info.factionGroup=C.Text(C.Try(UnitFactionGroup,unit));
    local class,fixed,id=UnitClass(unit); info.class=C.Text(class); info.classFixed=C.Text(fixed); info.classID=C.Number(id);
    local race,raceFixed=UnitRace(unit); info.race=C.Text(race); info.raceFixed=C.Text(raceFixed);
    local guild,rank,rankIndex=GetGuildInfo(unit); info.guild=C.Text(guild); info.guildRank=C.Text(rank); info.guildIndex=C.Number(rankIndex);
    if ex.unitType==1 then
        info.raceFixed,info.class,info.classFixed,info.classID=nil,nil,nil,nil;
        info.guild,info.guildRank,info.guildIndex,info.realm=nil,nil,nil,nil;
        info.race=C.Text(C.Try(UnitCreatureFamily,unit)) or C.Text(C.Try(UnitCreatureType,unit));
    end
    info.time,info.zone=time(),C.Text(GetRealZoneText(),"");
    if ex.unitType~=1 then
        ex.gear=ns.Gear.Calculate({},nil,false);
        ex.averageItemLevel,ex.gs="—","—";
    end
    ex:UpdateObjects();
    if ex.unitType~=1 then ex:SendModuleEvent("OnInspect",unit,guid); end
    if ex.unitType==1 then
        self.active=nil;
        local mod=ex.modules[ex.cfg.activePage]; if mod and mod.page then mod.page:Hide(); end
    elseif selfUnit then
        self:Refresh(session);
    else
        ex:SetBackgroundVertex(0.5,1,0.5);
        if not ex.canInspect then ns.Cache.Load(ex,ex:GetEntryName(),true); end
        timer:Show(); self:Tick();
    end
    if open~=false then ex:Display(true); end
    return true;
end

function I:RequestItems(session, result)
    for _,list in ipairs({result.pending,result.gems and result.gems.pending or {}}) do for _,value in ipairs(list) do
        local id=C.IsString(value) and tonumber(value:match("item:(%d+)"));
        if id and not session.requested[id] then
            session.requested[id]=true;
            C.Try(C_Item and C_Item.RequestLoadItemDataByID,id);
        end
    end end
end
function I:Refresh(session)
    if not self:Valid(session) or (not session.cached and not session.serverReady) then return; end
    local links,unknown={},{};
    if session.cached then links=ex.info.Items;
    else
        for _,slot in ipairs(LibGearExam.Slots) do
            local id=LibGearExam.SlotIDs[slot]; local link=GetInventoryItemLink(session.unit,id);
            if C.IsString(link) then links[slot]=link;
            else
                local itemID=C.Safe(GetInventoryItemID(session.unit,id));
                local texture=GetInventoryItemTexture and C.Safe(GetInventoryItemTexture(session.unit,id));
                if itemID or texture then unknown[#unknown+1]=C.IsNumber(itemID) and ("item:"..itemID) or slot; end
            end
        end
    end
    local result=ns.Gear.Calculate(links,session.cached and nil or session.unit,true,session.cached and ex.info.Sets);
    if session.cached and ex.info.legacy then result.statsState="partial"; result.legacy=true; end
    for _,slot in ipairs(unknown) do result.pending[#result.pending+1]=slot; end
    if #result.pending>0 then result.state="loading"; end
    ns.Gear.Apply(ex,result);
    ex.isCacheEntry=session.cached or nil;
    self:RequestItems(session,result);
    if session.cached then
        ex:SendModuleEvent("OnGearUpdated",nil,nil);
    else
        ex.info.time=time();
        ex:SendModuleEvent("OnInspectReady",session.unit,session.guid);
        ex:CachePlayer();
    end
    ex:ShowModulePage();
    session.refreshed=GetTime();
    local talent=ex.talentData;
    session.done=result.state=="ready" and (not result.gems or result.gems.state~="loading")
        and (not talent or talent.state~="loading") and (not ex.pvpData or ex.pvpData.state~="loading");
    if session.done then timer:Hide(); ex:SetBackgroundVertex(session.cached and 1 or 1,1,session.cached and 0.4 or 1);
    else timer:Show(); end
end
function I:Ready(guid)
    local session=self.active;
    if not session or session.done or session.cached or (not ex.isSelf and session.requests==0) or not C.IsString(guid) or guid~=session.guid or not self:Valid(session) then return; end
    if self.notificationGUID and self.notificationGUID~=guid then return; end
    session.serverReady=true;
    ns.Record("inspect-ready",guid);
    self:Refresh(session);
end
function I:Tick()
    local session=self.active;
    if not session then self:Cancel(); return; end
    if not self:Valid(session) then
        if ex.gear and ex.gear.state=="loading" then ex.gear.state="unavailable"; ex.gear.statsState="unavailable"; end
        if ex.talentData and ex.talentData.state=="loading" then ex.talentData.state="unavailable"; ex.talentData.message="The inspected unit changed or disappeared."; end
        ex.unit=nil; ex:SendModuleEvent("OnDataTimeout"); self:Cancel(); return;
    end
    local now=GetTime();
    if now-session.started>=TIMEOUT then
        session.done=true; timer:Hide();
        if ex.gear and ex.gear.state=="loading" then
            ex.gear.state=ex.gear.count>0 and "partial" or "unavailable";
            ex.gear.statsState=ex.gear.state;
        end
        if ex.talentData and ex.talentData.state=="loading" then
            local data=ex.talentData;
            data.state=(#(data.trees or {})>0 or #(data.extraTrees or {})>0) and "partial" or "unavailable";
            data.message=data.state=="partial" and "Some talent details could not be loaded. The available tree is shown." or "Talent data could not be loaded before the timeout.";
        end
        if ex.gear and ex.gear.gems and ex.gear.gems.state=="loading" then
            ex.gear.gems.state=ex.gear.gems.count>0 and "partial" or "unavailable";
        end
        ex:SendModuleEvent("OnDataTimeout");
        if session.serverReady and not session.cached and (ex.isSelf or self.notificationGUID==session.guid) then ex:CachePlayer(); end
        ex:SetBackgroundVertex(1,1,1); ns.Record("inspect-timeout","partial data retained"); return;
    end
    if session.serverReady or session.cached then
        if not session.refreshed or now-session.refreshed>=0.5 then self:Refresh(session); end
    elseif session.requests<MAX_REQUESTS and now-self.lastRequest>=RETRY_AFTER and self:CanInspect(session.unit) then
        if InCombatLockdown and InCombatLockdown() then return; end
        session.requests=session.requests+1;
        self.lastRequest=now; self.notificationGUID=session.guid; self.ownsRequest=true;
        ns.Record("inspect-request",session.guid);
        self.sending=true; C.Try(NotifyInspect,session.unit); self.sending=false;
    end
end
function I:SpellLoaded(spellID,success)
    local session=self.active;
    local request=C.IsNumber(spellID) and ns.Talents.requested[spellID];
    if (C.talentKind~="traits" and not C.isMists) or not success or not request or request.delivered or not session or not session.done
        or session.cached or not session.serverReady or not self:Valid(session)
        or (not ex.isSelf and self.notificationGUID~=session.guid) then return; end
    request.delivered=true;
    local mod=ex:GetModuleFromToken("Talents");
    if not mod then return; end
    mod:OnInspectReady(session.unit);
    local data=ex.talentData;
    if data and data.state=="loading" then
        data.state=(#(data.trees or {})>0 or #(data.extraTrees or {})>0) and "partial" or "unavailable";
        mod:OnDataTimeout();
    end
    ex:CachePlayer();
end
function I:LoadCachedItems(entry)
    self.generation=self.generation+1;
    self.active={generation=self.generation,cached=true,started=GetTime(),requested={}};
    self:RequestItems(self.active,ex.gear); timer:Show();
end
function I:InventoryChanged(unit)
    local session=self.active;
    if not session or session.cached or not self:Valid(session) or not C.IsTrue(UnitIsUnit(unit,session.unit)) then return; end
    session.started=GetTime(); session.done=false;
    if ex.isSelf then self:Refresh(session);
    else
        session.serverReady=false; session.honorReady=nil; session.requests=0; ex.requestedHonorData=nil;
        session.capture=session.guid..":"..time()..":"..GetTime()..":"..self.generation;
        timer:Show();
    end
end

local elapsedTotal=0;
timer:SetScript("OnUpdate",function(_,elapsed)
    elapsedTotal=elapsedTotal+elapsed;
    if elapsedTotal>=0.15 then elapsedTotal=0; I:Tick(); end
end);
timer:SetScript("OnEvent",function(_,event,...)
    if event=="INSPECT_READY" then I:Ready(...);
    elseif event=="UNIT_INVENTORY_CHANGED" then I:InventoryChanged(...);
    elseif event=="PLAYER_EQUIPMENT_CHANGED" or event=="PLAYER_TALENT_UPDATE" or event=="TRAIT_CONFIG_UPDATED" then I:InventoryChanged("player");
    elseif event=="SPELL_DATA_LOAD_RESULT" and I.active and I.active.done then I:SpellLoaded(...);
    else
        local session=I.active;
        if session and not session.done and I:Valid(session) and (session.serverReady or session.cached) then session.refreshed=nil; timer:Show(); end
    end
end);
for _,event in ipairs({"INSPECT_READY","ITEM_DATA_LOAD_RESULT","GET_ITEM_INFO_RECEIVED","PLAYER_EQUIPMENT_CHANGED","PLAYER_TALENT_UPDATE"}) do timer:RegisterEvent(event); end
if C_Traits then C.Try(timer.RegisterEvent,timer,"TRAIT_CONFIG_UPDATED"); end
if C_Spell and C_Spell.RequestLoadSpellData then C.Try(timer.RegisterEvent,timer,"SPELL_DATA_LOAD_RESULT"); end
if type(NotifyInspect)=="function" then
    hooksecurefunc("NotifyInspect",function(unit)
        I.lastRequest=GetTime(); I.notificationGUID=C.IsString(unit) and C.Safe(UnitGUID(unit)) or nil;
        if not I.sending then
            I.ownsRequest=false;
            local session=I.active;
            if session and not session.cached and not ex.isSelf then
                session.serverReady=false; session.honorReady=nil; ex.requestedHonorData=nil;
                if not session.done then timer:Show(); end
            end
        end
    end);
end
