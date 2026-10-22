local _,ns=...;
if ns.blocked then return; end
local ex,C=ns.ex,ns.Compat;
local mod=ex:CreateModule("Guild",GUILD or ns.L["Guild"]);
mod.help=ns.L["Guild information for the inspected character"];
mod.canCache=true; mod:CreatePage(false,GUILD or ns.L["Guild"]); mod:HasButton(true);
local page=mod.page;
local banner=page:CreateTexture(nil,"ARTWORK",nil,0); mod.banner=banner;
banner:SetSize(88,108); banner:SetPoint("TOP",0,-38);
banner:SetTexture("Interface\\GuildFrame\\GuildInspect-Parts");
banner:SetTexCoord(0.23632813,0.46679688,0.70117188,0.98242188);
local border=page:CreateTexture(nil,"ARTWORK",nil,1);
border:SetAllPoints(banner); border:SetTexture("Interface\\GuildFrame\\GuildInspect-Parts");
border:SetTexCoord(0.00195313,0.23242188,0.70117188,0.98242188);
local left=page:CreateTexture(nil,"ARTWORK",nil,2); mod.leftEmblem=left;
left:SetSize(37.3,93.2); left:SetPoint("CENTER",banner,-18.65,0); left:SetTexCoord(1,0,0,1);
local right=page:CreateTexture(nil,"ARTWORK",nil,2); mod.rightEmblem=right;
right:SetSize(37.3,93.2); right:SetPoint("LEFT",left,"RIGHT",-0.75,0); right:SetTexCoord(0,1,0,1);
local function Label(y,font)
    local text=page:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall");
    text:SetPoint("TOPLEFT",12,y); text:SetPoint("TOPRIGHT",-12,y); return text;
end
local name=Label(-153,"GameFontNormal"); mod.guildName=name;
local rank=Label(-181); mod.guildRank=rank;
local realm=Label(-202); mod.guildRealm=realm;
local members=Label(-223); mod.guildMembers=members;
local points=page:CreateFontString(nil,"OVERLAY","GameFontNormal"); mod.guildPoints=points;
points:SetPoint("BOTTOM",0,23);
local note=page:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
note:SetPoint("BOTTOM",0,8); note:SetTextColor(0.65,0.65,0.65);
local function Color(value)
    if not C.IsTable(value) then return; end
    local r,g,b;
    if type(value.GetRGB)=="function" then r,g,b=C.Try(value.GetRGB,value);
    else r,g,b=value.r or value[1],value.g or value[2],value.b or value[3]; end
    if C.IsNumber(r) and C.IsNumber(g) and C.IsNumber(b) then return {r=r,g=g,b=b}; end
end
local function ReadBanner(unit)
    local api=C_GuildInfo or {};
    local info=C.Try(api.GetGuildTabardInfo,unit);
    if C.IsTable(info) then
        local emblem=C.Icon(info.emblemFileID);
        local backgroundColor,borderColor,emblemColor=Color(info.backgroundColor),Color(info.borderColor),Color(info.emblemColor);
        if emblem and backgroundColor and borderColor and emblemColor then
            return {emblem=emblem,background=backgroundColor,border=borderColor,color=emblemColor};
        end
    end
    -- Older clients return ten scalar values, not ColorMixin objects.
    local r,g,b,br,bg,bb,er,eg,eb,file=C.Try(GetGuildLogoInfo,unit);
    if C.Icon(file) and C.IsNumber(r) and C.IsNumber(g) and C.IsNumber(b)
        and C.IsNumber(br) and C.IsNumber(bg) and C.IsNumber(bb)
        and C.IsNumber(er) and C.IsNumber(eg) and C.IsNumber(eb) then
        return {emblem=file,background={r=r,g=g,b=b},border={r=br,g=bg,b=bb},color={r=er,g=eg,b=eb}};
    end
end
function mod:Draw(data)
    data=data or {};
    name:SetText(data.name or ns.L["No guild information"]);
    local rankLabel=ns.L.Rank:gsub(":$","");
    rank:SetText(data.rank and data.rank~="" and (rankLabel..": "..data.rank) or "");
    realm:SetText(data.realm and data.realm~="" and (ns.L.Realm..": "..data.realm) or "");
    members:SetText(C.IsNumber(data.members) and ("|cffffd100"..C.FormatNumber(data.members).."|r "..ns.L["Guild Members"]) or "");
    points:SetText(C.IsNumber(data.points) and (C.FormatNumber(data.points).." |TInterface\\AchievementFrame\\UI-Achievement-Shields-NoPoints:18:18:0:0:128:128:0:64:64:128|t") or "");
    note:SetText(data.cached and ns.L["Cached guild information"] or "");
    local crest=C.IsTable(data.banner) and data.banner;
    local backgroundColor=crest and Color(crest.background);
    local borderColor=crest and Color(crest.border);
    local emblemColor=crest and Color(crest.color);
    local visible=data.name and crest and C.Icon(crest.emblem) and backgroundColor and borderColor and emblemColor;
    for _,texture in ipairs({banner,border,left,right}) do texture:SetShown(visible and true or false); end
    left:SetTexture(visible and crest.emblem or nil); right:SetTexture(visible and crest.emblem or nil);
    if visible then
        banner:SetVertexColor(backgroundColor.r,backgroundColor.g,backgroundColor.b);
        border:SetVertexColor(borderColor.r,borderColor.g,borderColor.b);
        left:SetVertexColor(emblemColor.r,emblemColor.g,emblemColor.b);
        right:SetVertexColor(emblemColor.r,emblemColor.g,emblemColor.b);
    end
end
function mod:Read(unit,inspectReady)
    local guild,rankName,_,guildRealm=C.Try(GetGuildInfo,unit);
    local data={name=C.Text(guild),rank=C.Text(rankName),realm=C.Text(guildRealm),time=time(),complete=inspectReady or ex.isSelf or nil};
    if not data.name then data.name=ex.info.guild; data.rank=ex.info.guildRank; end
    -- Read global inspect results only after the matching INSPECT_READY.
    if inspectReady or ex.isSelf then
        local paper=C_PaperDollInfo or {};
        local pointsValue,count,inspectName,inspectRealm=C.Try(paper.GetInspectGuildInfo or GetInspectGuildInfo,unit);
        if C.IsString(inspectName) and inspectName~="" and (not data.name or data.name==inspectName) then
            data.name=inspectName; data.realm=C.Text(inspectRealm,data.realm);
            data.points=C.Number(pointsValue); data.members=C.Number(count);
        end
        if data.name then data.banner=ReadBanner(unit); end
    end
    if data.name and (not data.realm or data.realm=="") then
        data.realm=C.Text(ex.info.realm,C.Text(C.Try(GetRealmName)));
    end
    ex.guildData=data; self:Draw(data); self:HasData(C.IsString(data.name) and data.name~="");
end
function mod:OnInspect(unit) self:Read(unit); end
function mod:OnInspectReady(unit) self:Read(unit,true); end
function mod:OnClearInspect() ex.guildData=nil; self:Draw(); self:HasData(nil); end
function mod:OnCache(entry)
    local data=ex.guildData;
    if not self:CanCache() or not data or not data.complete then return; end
    local previous=entry.Guild;
    local stored=ns.Cache.Copy(data);
    if C.IsTable(previous) and data.name and previous.name==data.name and previous.realm==data.realm then
        for _,key in ipairs({"members","points","banner"}) do
            if stored[key]==nil then stored[key]=ns.Cache.Copy(previous[key]); end
        end
    end
    stored.cached=nil; entry.Guild=stored;
end
function mod:OnCacheLoaded(entry)
    ex.guildData=ns.Cache.Copy(entry.Guild) or {name=entry.guild,rank=entry.guildRank};
    ex.guildData.cached=true; self:Draw(ex.guildData); self:HasData(C.IsString(ex.guildData.name) and ex.guildData.name~="");
end
