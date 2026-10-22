local _, ns = ...;
if ns.blocked or ns.Compat.talentKind=="classic" then return; end
local ex,C=ns.ex,ns.Compat;
local mod=ex:CreateModule("Talents",TALENTS);
mod.help=ns.L["The inspected character's talents"];
mod.canCache=true; mod:HasButton(true);
mod:CreatePage(true);
local page=mod.page;
-- Do not forward talent-page wheel input to the character model.
page:EnableMouseWheel(true);
page:SetScript("OnMouseWheel",function() end);
-- Parent to Examiner: the PlayerModel is hidden while viewing talents.
page:SetParent(ex); page:ClearAllPoints(); page:SetPoint("TOP",ex.model,"TOP");
page:SetFrameLevel(ex.model:GetFrameLevel()+1);
page:SetBackdrop(nil);
-- Separate frame extends the artwork behind the footer.
local backdrop=CreateFrame("Frame",nil,ex);
backdrop:SetFrameLevel(ex.model:GetFrameLevel());
backdrop:SetSize(320,354);
backdrop:SetPoint("TOPLEFT",ex.model,"TOPLEFT",0,0);
backdrop:SetPoint("BOTTOMRIGHT",ex.model,"BOTTOMRIGHT",0,0);
backdrop:EnableMouse(false); backdrop:Hide(); mod.backgroundFrame=backdrop;
local background=backdrop:CreateTexture(nil,"BACKGROUND");
background:SetPoint("TOPRIGHT"); background:SetSize(320,354); background:SetAlpha(1); background:Hide();
local backgroundFill=backdrop:CreateTexture(nil,"BACKGROUND",nil,-1);
backgroundFill:SetAllPoints(backdrop); backgroundFill:SetColorTexture(0.03,0.03,0.03,1);
mod.backgroundTexture=background;
local specIcon=page:CreateTexture(nil,"ARTWORK"); specIcon:SetSize(20,20); specIcon:SetPoint("TOPLEFT",12,-10); specIcon:Hide();
local subtitle=page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
subtitle:SetPoint("TOPLEFT",38,-14); subtitle:SetPoint("TOPRIGHT",C.isRetail and -138 or -82,-14);
subtitle:SetJustifyH("LEFT");
mod.specLabel=subtitle;
local status=page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
status:SetPoint("TOPLEFT",12,-38); status:SetPoint("TOPRIGHT",-12,-38); status:SetJustifyH("LEFT");
status:SetHeight(24);
local scroll=CreateFrame("ScrollFrame",nil,page); scroll:SetPoint("TOPLEFT",16,-108); scroll:SetPoint("BOTTOMRIGHT",-16,52);
local canvas=CreateFrame("Frame",nil,scroll); canvas:SetSize(300,300); scroll:SetScrollChild(canvas);
local build=CreateFrame("EditBox",nil,page,"InputBoxTemplate"); build:SetAutoFocus(false); build:SetHeight(24);
build:SetPoint("TOPLEFT",16,-38); build:SetPoint("TOPRIGHT",-16,-38); build:Hide(); mod.buildBox=build;
build:SetScript("OnEscapePressed",function(self) self:ClearFocus(); self:Hide(); mod:Draw(); end);
build:SetScript("OnTextChanged",function(self,user) if user then self:SetText(self.copyText or ""); end end);
build:SetScript("OnEditFocusGained",function(self) self:HighlightText(); end);
local tabs,buttons,lines={},{},{}; mod.treeTabs=tabs;
local selected,selectedKey=1,nil;
local copyMode="build";
mod.navigation={};
local function ResetView() scroll:SetVerticalScroll(0); scroll:SetHorizontalScroll(0); end
local function Showable(data)
    if not data or data.state=="locked" then return false; end
    if data.state=="loading" or (C.IsString(data.loadout) and data.loadout~="") then return true; end
    for _,list in ipairs({data.trees or {},data.extraTrees or {}}) do
        for _,tree in ipairs(list) do if #(tree.nodes or {})>0 then return true; end end
    end
    return false;
end
local copy=CreateFrame("Button",nil,page,"UIPanelButtonTemplate"); mod.copyButton=copy;
copy:Hide();
copy:SetSize(66,18); copy:SetPoint("TOPRIGHT",C.isRetail and -70 or -10,-11); copy:SetText(ns.L["Copy build"]);
local copyFont=GameFontNormalSmall:GetFont();
copy:SetNormalFontObject(GameFontNormalSmall); copy:SetHighlightFontObject(GameFontHighlightSmall); copy:SetDisabledFontObject(GameFontDisableSmall);
copy:GetFontString():SetFont(copyFont,9);
copy:SetScript("OnClick",function()
    if not C.IsString(build.buildString) or build.buildString=="" then return; end
    copyMode="build"; build:Show(); mod:Draw(); build:SetFocus(); build:HighlightText();
end);
local copyLink=CreateFrame("Button",nil,page,"UIPanelButtonTemplate"); mod.copyLinkButton=copyLink;
copyLink:SetSize(56,18); copyLink:SetPoint("TOPRIGHT",-10,-11); copyLink:SetText(ns.L["Copy link"]);
copy:SetWidth(math.max(66,copy:GetFontString():GetStringWidth()+16));
copyLink:SetWidth(math.max(56,copyLink:GetFontString():GetStringWidth()+16));
copy:ClearAllPoints(); copy:SetPoint("TOPRIGHT",C.isRetail and (-14-copyLink:GetWidth()) or -10,-11);
copyLink:SetNormalFontObject(GameFontNormalSmall); copyLink:SetHighlightFontObject(GameFontHighlightSmall); copyLink:SetDisabledFontObject(GameFontDisableSmall);
copyLink:GetFontString():SetFont(copyFont,9);
copyLink:Hide();
copyLink:SetScript("OnClick",function()
    if not ns.TalentBuildLink(build.buildString) then return; end
    copyMode="link"; build:Show(); mod:Draw(); build:SetFocus(); build:HighlightText();
end);
copyLink:SetScript("OnEnter",function(self)
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(ns.L["Ctrl+C to copy the Wowhead link, then paste it into your browser."]); GameTooltip:Show();
end);
copyLink:SetScript("OnLeave",ex.HideGTT);
local function Tooltip(button)
    local node=button.node; local entry=node and node.entry;
    if not entry then
        if node and node.pvp then GameTooltip:SetOwner(button,"ANCHOR_RIGHT"); GameTooltip:SetText(ns.L["PvP talent information not available"]); GameTooltip:Show(); end
        return;
    end
    GameTooltip:SetOwner(button,"ANCHOR_RIGHT");
    local native=false;
    local data,session=ex.talentData,ns.Inspector.active;
    if C.isMists and data and not data.cached and not ex.isCacheEntry and session and not session.cached
        and session.serverReady and ns.Inspector:Valid(session) and (ex.isSelf or ns.Inspector.notificationGUID==session.guid) then
        if node.glyphSlot and type(GameTooltip.SetGlyph)=="function" then
            native=pcall(GameTooltip.SetGlyph,GameTooltip,node.glyphSlot,data.group,not ex.isSelf,ex.unit);
        elseif type(GameTooltip.SetTalent)=="function" then
            native=pcall(GameTooltip.SetTalent,GameTooltip,node.id,not ex.isSelf,data.group,ex.unit,ex.info.classID);
        end
    end
    if not native then
        if entry.spell then GameTooltip:SetSpellByID(entry.spell); else GameTooltip:SetText(entry.name or ""); end
    end
    if node.unlockLevel then GameTooltip:AddLine(ns.F("Unlocks at level %d",node.unlockLevel),0.7,0.7,0.7); end
    if node.glyphType==1 or node.glyphType==2 then
        GameTooltip:AddLine(ns.L[node.glyphType==1 and "Major glyph" or "Minor glyph"],0.5,0.75,1);
    end
    if not node.pvp and not node.glyph then GameTooltip:AddLine(string.format("%d / %d",node.rank,node.max),1,0.82,0); end
    for _,choice in ipairs(node.choices or {}) do if choice~=entry then GameTooltip:AddLine(choice.name,0.7,0.7,0.7); end end
    GameTooltip:Show();
end
local function Button(index)
    if buttons[index] then return buttons[index]; end
    local button=CreateFrame("Button",nil,canvas);
    button.icon=button:CreateTexture(nil,"ARTWORK"); button.icon:SetAllPoints();
    button.border=button:CreateTexture(nil,"OVERLAY"); button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2"); button.border:SetPoint("CENTER");
    button.rank=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); button.rank:SetPoint("BOTTOMRIGHT",3,-3);
    button:SetScript("OnEnter",Tooltip); button:SetScript("OnLeave",ex.HideGTT);
    buttons[index]=button; return button;
end
-- Classic TabButtonTemplate artwork without the removed XML template.
local function CreateTreeTab(index)
    local tab=CreateFrame("Button",nil,page); tab.index=index; tab.pieces={};
    for part=1,3 do
        local texture=tab:CreateTexture(nil,"BORDER"); tab.pieces[part]=texture;
        texture:SetSize(part==2 and 32 or 16,32);
        if part==1 then texture:SetTexCoord(0,0.25,0,1);
        elseif part==3 then texture:SetTexCoord(0.75,1,0,1);
        else texture:SetTexCoord(0.25,0.75,0,1); end
    end
    local label=tab:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");
    label:SetJustifyH("CENTER"); label:SetJustifyV("MIDDLE"); tab:SetFontString(label); tab.label=label;
    tab:SetNormalFontObject(GameFontNormalSmall); tab:SetHighlightFontObject(GameFontHighlightSmall);
    tab:SetHighlightTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight","ADD");
    local highlight=tab:GetHighlightTexture();
    highlight:ClearAllPoints(); highlight:SetAllPoints(tab); tab.highlight=highlight;
    tab:SetScript("OnClick",function(self)
        if self.unavailable then return; end
        selected=self.index; selectedKey=self.key; ResetView(); mod:Draw();
    end);
    tab:SetScript("OnEnter",function(self)
        if self.reason then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(self.reason); GameTooltip:Show(); end
    end);
    tab:SetScript("OnLeave",ex.HideGTT);
    return tab;
end
function mod:Draw()
    local data=ex.talentData or {trees={},state="loading",message="Waiting for talent data."};
    local trees=ns.TalentTabs(data,ex.info.classFixed); self.displayTrees=trees;
    if selectedKey then
        local found=false;
        for index,tree in ipairs(trees) do if tree.key==selectedKey then selected=index; found=true; break; end end
        if not found then selected=1; end
    end
    selected=math.min(selected,math.max(1,#trees));
    if trees[selected] and trees[selected].disabled then
        for index,tree in ipairs(trees) do if not tree.disabled then selected=index; break; end end
    end
    selectedKey=trees[selected] and trees[selected].key;
    subtitle:SetText((C.isForever and trees[selected] and (trees[selected].fullName or trees[selected].name)) or data.specName or (#trees==1 and trees[1].name) or "");
    if C.isMists and data.specRole then
        subtitle:SetText(subtitle:GetText().." · "..(_G[data.specRole] or data.specRole));
    end
    local icon=(C.isForever and trees[selected] and trees[selected].icon) or data.specIcon;
    if icon then specIcon:SetTexture(icon); specIcon:Show(); else specIcon:Hide(); end
    local image,kind,source=ns.TalentBackground(data.specID,ex.info.classFixed,trees[selected] and trees[selected].backgroundSpecID);
    mod.backgroundKind=kind;
    mod.backgroundSource=source or kind;
    if image then
        mod.backgroundCrop=ns.ApplyTalentBackground(background,image,kind,backdrop:GetWidth(),backdrop:GetHeight());
        background:Show();
    else mod.backgroundCrop=nil; background:Hide(); end
    local widths,totalWidth={},0;
    for index,tree in ipairs(trees) do
        local tab=tabs[index]; if not tab then tab=CreateTreeTab(index); tabs[index]=tab; end
        tab:SetText(tree.name); tab.label:ClearAllPoints(); tab.label:SetWidth(0); tab.label:SetHeight(20);
        widths[index]=math.max(56,tab.label:GetStringWidth()+28); totalWidth=totalWidth+widths[index];
    end
    local available=page:GetWidth()-45;
    local minimum=math.min(56,available/math.max(1,#trees));
    local shrink=totalWidth>available and math.max(0,(available-minimum*#trees)/(totalWidth-minimum*#trees)) or 1;
    local tabX=45;
    for index,tree in ipairs(trees) do
        local tab=tabs[index];
        tab.key=tree.key;
        tab.unavailable=tree.disabled; tab.reason=tree.reason or tree.fullName or tree.name;
        local width=minimum+(widths[index]-minimum)*shrink;
        -- The tab artwork has 12px of transparent padding above its 20px face.
        tab:ClearAllPoints(); tab:SetPoint("TOPLEFT",tabX,24); tab:SetSize(width,20); tabX=tabX+width;
        tab.selected=index==selected;
        local offset=0;
        for part,texture in ipairs(tab.pieces) do
            texture:SetTexture("Interface\\HelpFrame\\HelpFrameTab-"..(tab.selected and "Active" or "Inactive"));
            texture:ClearAllPoints();
            if part==1 then texture:SetPoint("BOTTOMLEFT",0,offset);
            elseif part==3 then texture:SetPoint("BOTTOMRIGHT",0,offset);
            else texture:SetPoint("BOTTOMLEFT",16,offset); texture:SetPoint("BOTTOMRIGHT",-16,offset); end
        end
        tab.label:ClearAllPoints(); tab.label:SetPoint("TOPLEFT",8,0); tab.label:SetPoint("BOTTOMRIGHT",-8,0);
        tab:SetDisabledFontObject(tree.disabled and GameFontDisableSmall or GameFontHighlightSmall);
        if tree.disabled then tab.label:SetTextColor(0.5,0.5,0.5);
        elseif tab.selected then tab.label:SetTextColor(1,1,1); else tab.label:SetTextColor(1,0.82,0); end
        if #trees>1 then tab:Show(); if index==selected or tree.disabled then tab:Disable(); else tab:Enable(); end else tab:Hide(); end
    end
    for index=#trees+1,#tabs do tabs[index]:Hide(); end
    for _,button in ipairs(buttons) do button:Hide(); end
    for _,line in ipairs(lines) do line:Hide(); end
    for _,label in pairs(mod.tierLabels or {}) do label:Hide(); end
    build.buildString=C.Text(data.loadout) or "";
    local link=ns.TalentBuildLink(build.buildString);
    copyLink:SetShown(link~=nil);
    copy:ClearAllPoints(); copy:SetPoint("TOPRIGHT",link and (-14-copyLink:GetWidth()) or -10,-11);
    subtitle:SetPoint("TOPRIGHT",build.buildString~="" and (link and -138 or -82) or -12,-14);
    build.copyText=(copyMode=="link" and link or nil) or build.buildString;
    if copyMode=="link" and not link then build:Hide(); copyMode="build"; end
    if build:GetText()~=build.copyText then build:SetText(build.copyText); end
    copy:SetShown(build.buildString~="");
    if build.buildString=="" then build:Hide(); end
    local tree=trees[selected];
    local message=data.state=="loading" and (LOADING or "Loading...") or "";
    if C.isForever and tree and #tree.nodes>0 then message=""; end
    status:SetText(message); status:SetShown(not build:IsShown() and message~="");
    local top=(build:IsShown() or message~="") and 70 or 40;
    scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT",10,-top); scroll:SetPoint("BOTTOMRIGHT",-10,8);
    if not tree or #tree.nodes==0 then canvas:SetSize(1,1); ResetView(); return; end
    local width=math.max(100,page:GetWidth()-20);
    local height=math.max(100,page:GetHeight()-top-8);
    self.treeWidth=width; self.treeHeight=height;
    ns.DrawTalentTree(self,tree,canvas,width,height,Button,lines,1);
end
local detailsShown,guildShown,modelShown;
page:SetScript("OnShow",function()
    detailsShown,guildShown,modelShown=ex.details:IsShown(),ex.guild:IsShown(),ex.model:IsShown();
    ex.details:Hide(); ex.guild:Hide(); ex.model:Hide(); backdrop:Show(); mod:Draw();
end);
page:SetScript("OnHide",function()
    build:ClearFocus(); build:Hide(); backdrop:Hide();
    ex.details:SetShown(detailsShown); ex.guild:SetShown(guildShown); ex.model:SetShown(modelShown);
end);
function mod:OnInspect(unit)
    wipe(ns.Talents.requested);
    selected,selectedKey=1,nil;
    copyMode="build";
    ex.talentData=ns.Talents.LowLevelData(unit) or {state="loading",trees={},message="Waiting for talent data."};
    ResetView(); self:HasData(Showable(ex.talentData));
    if page:IsShown() then self:Draw(); end
end
function mod:OnInspectReady(unit)
    ex.talentData=ns.Talents.Read(unit,ex.isSelf); self:HasData(Showable(ex.talentData));
    if page:IsShown() then self:Draw(); end
end
function mod:OnClearInspect() ex.talentData=nil; self:HasData(nil); if page:IsShown() then self:Draw(); end end
function mod:OnInspectHidden() page:Hide(); end
function mod:OnDataTimeout() self:HasData(Showable(ex.talentData)); if page:IsShown() then self:Draw(); end end
function mod:OnCache(entry)
    local data=ex.talentData;
    if not self:CanCache() or not data then return; end
    local previous=entry.Talents;
    if C.isForever and C.IsTable(previous) and previous.groupingVersion~=2 then previous=nil; end
    local useful=C.IsString(data.loadout) and data.loadout~="";
    for _,list in ipairs({data.trees or {},data.extraTrees or {}}) do
        for _,tree in ipairs(list) do if #(tree.nodes or {})>0 then useful=true; end end
    end
    useful=useful and (data.state=="partial" or data.state=="loading");
    if data.state=="ready" or (useful and (not C.IsTable(previous) or previous.state~="ready" or (data.specID and previous.specID~=data.specID))) then
        local stored=ns.Cache.Copy(data);
        if stored.state=="loading" then stored.state="partial"; end
        stored.cached=nil; entry.Talents=stored;
    end
end
function mod:OnCacheLoaded(entry)
    selected,selectedKey=1,nil;
    copyMode="build";
    local snapshot=entry.Talents;
    if C.isForever and C.IsTable(snapshot) and snapshot.groupingVersion~=2 then snapshot=nil; end
    ex.talentData=ns.Talents.LowLevelData(nil,ex.info.level) or ns.Cache.Copy(snapshot) or {state="unavailable",trees={},message="This cache has no complete talent snapshot."};
    if C.isForever then for index,tree in ipairs(ex.talentData.trees or {}) do
        ns.Talents.RemoveDetachedDuplicates(tree,ex.talentData.specID,index);
    end end
    ex.talentData.cached=true; ResetView(); self:HasData(Showable(ex.talentData));
    if page:IsShown() then self:Draw(); end
end
