local _, ns = ...;
if ns.blocked then return; end
local C, Cache = ns.Compat, {schema=2};
ns.Cache = Cache;

function Cache.Copy(value, depth)
    depth=depth or 0;
    if C.IsSecret(value) or depth>10 then return nil; end
    local kind=type(value);
    if kind=="string" or kind=="number" or kind=="boolean" then return value; end
    if kind~="table" then return nil; end
    local copy,count={},0;
    for key,item in pairs(value) do
        if count>=1024 then break end
        if not C.IsSecret(key) and (type(key)=="string" or type(key)=="number") then
            copy[key]=Cache.Copy(item,depth+1); count=count+1;
        end
    end
    return copy;
end

function Cache.Valid(entry)
    return C.IsTable(entry) and C.IsString(entry.name) and (entry.schemaVersion==nil or (C.IsNumber(entry.schemaVersion) and entry.schemaVersion<=Cache.schema));
end
function Cache.Initialize(ex)
    for _,entry in pairs(ex.cache) do
        if Cache.Valid(entry) then
            if not entry.schemaVersion then entry.legacy=true; entry.schemaVersion=Cache.schema; entry.clientKey="legacy"; end
            entry.Items=C.IsTable(entry.Items) and entry.Items or {};
            entry.Sets=C.IsTable(entry.Sets) and entry.Sets or {};
            entry.Runes=C.IsTable(entry.Runes) and entry.Runes or {};
            entry.level=C.Number(entry.level,0); entry.time=C.Number(entry.time,0);
            entry.pvpName=C.Text(entry.pvpName,entry.name); entry.class=C.Text(entry.class,UNKNOWN or "Unknown");
            entry.race=C.Text(entry.race,UNKNOWN or "Unknown"); entry.zone=C.Text(entry.zone,UNKNOWN or "Unknown");
        end
    end
end

function Cache.Store(ex, manual)
    if ex.isCacheEntry or not ex.gear or not C.IsString(ex.info.name) or not ex.info.raceFixed then return false; end
    if not manual then
        if not ex.cfg.caching.Core then return false; end
        if ex.gear.state~="ready" then
            local inspector=ns.Inspector;
            local session=inspector.active;
            if not session or session.cached or not session.serverReady or not inspector:Valid(session)
                or (not ex.isSelf and inspector.notificationGUID~=session.guid) then return false; end
        end
    end
    local key=ex:GetEntryName();
    local previous=ex.cache[key];
    if C.IsTable(previous) and C.IsNumber(previous.schemaVersion) and previous.schemaVersion>Cache.schema then return false; end
    if C.IsTable(previous) and previous.clientKey and previous.clientKey~="legacy" and previous.clientKey~=C.clientKey then previous=nil; end
    local entry=Cache.Valid(previous) and Cache.Copy(previous) or {};
    local snapshot=Cache.Copy(ex.info);
    for name,value in pairs(snapshot) do entry[name]=value; end
    local preserve=C.IsTable(previous) and C.IsTable(previous.gear) and previous.gear.state=="ready" and ex.gear.state~="ready";
    if preserve then
        entry.Items=Cache.Copy(previous.Items); entry.Sets=Cache.Copy(previous.Sets); entry.Runes=Cache.Copy(previous.Runes);
        entry.iLvlAverage=previous.iLvlAverage; entry.gear=Cache.Copy(previous.gear);
    else
        entry.gear=Cache.Copy(ex.gear);
    end
    entry.schemaVersion=Cache.schema; entry.clientKey=C.clientKey; entry.build=C.build; entry.legacy=nil;
    entry.gearTime=preserve and (previous.gearTime or previous.time) or ex.info.time;
    ex.cache[key]=entry;
    ex:SendModuleEvent("OnCache",entry);
    return true;
end

function Cache.Load(ex, key, keepSession)
    local entry=ex.cache[key];
    if not Cache.Valid(entry) then return false; end
    if entry.clientKey and entry.clientKey~="legacy" and entry.clientKey~=C.clientKey then
        ns.Record("cache", "entry belongs to another client"); return false;
    end
    if not keepSession then ns.Inspector:Clear(); end
    for name,value in pairs(Cache.Copy(entry)) do ex.info[name]=value; end
    ex.info.raceFixed=ex.info.raceFixed or "Unknown";
    if C.IsTable(entry.gear) and C.IsTable(entry.gear.stats) then
        ns.Gear.Apply(ex,Cache.Copy(entry.gear));
        if not C.IsTable(ex.gear.gems) then ex.gear.gems=ns.Gear.ReadGems(ex.info.Items); end
    else
        local result=ns.Gear.Calculate(ex.info.Items,nil,true,entry.Sets);
        result.statsState="partial"; result.legacy=true;
        ns.Gear.Apply(ex,result);
    end
    ex.isCacheEntry=true;
    ex:SetBackgroundVertex(1,1,0.4);
    ex:UpdateObjects();
    ex:SendModuleEvent("OnCacheLoaded",entry,nil);
    ex:ShowModulePage();
    if not keepSession and (#ex.gear.pending>0 or (ex.gear.gems and ex.gear.gems.state=="loading")) then ns.Inspector:LoadCachedItems(entry); end
    return true;
end
