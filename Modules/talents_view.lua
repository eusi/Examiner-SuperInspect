local _,ns=...;
if ns.blocked then return; end
local C=ns.Compat;
local backgrounds={
    [250]="deathknight-blood",[251]="deathknight-frost",[252]="deathknight-unholy",
    [577]="demonhunter-havoc",[581]="demonhunter-vengeance",[1480]="demonhunter-devourer",
    [102]="druid-balance",[103]="druid-feral",[104]="druid-guardian",[105]="druid-restoration",
    [1467]="evoker-devastation",[1468]="evoker-preservation",[1473]="evoker-augmentation",
    [253]="hunter-beastmastery",[254]="hunter-marksmanship",[255]="hunter-survival",
    [62]="mage-arcane",[63]="mage-fire",[64]="mage-frost",
    [268]="monk-brewmaster",[269]="monk-windwalker",[270]="monk-mistweaver",
    [65]="paladin-holy",[66]="paladin-protection",[70]="paladin-retribution",
    [256]="priest-discipline",[257]="priest-holy",[258]="priest-shadow",
    [259]="rogue-assassination",[260]="rogue-outlaw",[261]="rogue-subtlety",
    [262]="shaman-elemental",[263]="shaman-enhancement",[264]="shaman-restoration",
    [265]="warlock-affliction",[266]="warlock-demonology",[267]="warlock-destruction",
    [71]="warrior-arms",[72]="warrior-fury",[73]="warrior-protection",
};
local foreverClasses={ [1482]="MAGE",[1484]="DRUID",[1485]="HUNTER",[1486]="PALADIN",[1487]="PRIEST",[1488]="ROGUE",[1489]="SHAMAN",[1490]="WARLOCK",[1491]="WARRIOR" };
local foreverTrees={
    MAGE={62,63,64},DRUID={102,103,105},HUNTER={253,254,255},PALADIN={65,66,70},
    PRIEST={256,257,258},ROGUE={259,260,261},SHAMAN={262,263,264},
    WARLOCK={265,266,267},WARRIOR={71,72,73},
};
local shortNames={[62]="Arcane",[63]="Fire",[64]="Frost",[65]="Holy",[257]="Holy",[258]="Shadow",[262]="Elemental"};
function ns.TalentBackground(specID,classToken,treeSpecID)
    local selected=C.isForever and backgrounds[treeSpecID] and treeSpecID;
    local visuals=not selected and ClassTalentUtil and C.Try(ClassTalentUtil.GetVisualsForSpecID,specID);
    local class=C.isForever and (foreverClasses[specID] or classToken);
    class=C.IsString(class) and class:lower();
    local atlas=selected and ("talents-background-"..backgrounds[selected])
        or (C.IsTable(visuals) and C.Text(visuals.background))
        or (class and "talent-background-"..class)
        or (backgrounds[specID] and "talents-background-"..backgrounds[specID]);
    if atlas and ((C_Texture and C.IsTrue(C.Try(C_Texture.GetAtlasExists,atlas))) or C.IsTable(C.Try(C_Texture and C_Texture.GetAtlasInfo or GetAtlasInfo,atlas))) then return atlas,"atlas"; end
    local legacy={
        [250]="DeathKnightBlood",[251]="DeathKnightFrost",[252]="DeathKnightUnholy",
        [102]="DruidBalance",[103]="DruidFeralCombat",[104]="DruidFeralCombat",[105]="DruidRestoration",
        [253]="HunterBeastMastery",[254]="HunterMarksmanship",[255]="HunterSurvival",
        [62]="MageArcane",[63]="MageFire",[64]="MageFrost",[65]="PaladinHoly",[66]="PaladinProtection",[70]="PaladinCombat",
        [256]="PriestDiscipline",[257]="PriestHoly",[258]="PriestShadow",[259]="RogueAssassination",[260]="RogueCombat",[261]="RogueSubtlety",
        [262]="ShamanElementalCombat",[263]="ShamanEnhancement",[264]="ShamanRestoration",
        [265]="WarlockCurses",[266]="WarlockSummoning",[267]="WarlockDestruction",[71]="WarriorArms",[72]="WarriorFury",[73]="WarriorProtection",
    };
    local file=legacy[selected or specID];
    if C.isMists and not file then return nil,nil,"unavailable"; end
    return "Interface\\TalentFrame\\"..(file or "MageArcane").."-TopLeft","texture",file and "legacy-spec" or "generic-fallback";
end
-- Fit height, align right, crop left.
function ns.TalentBackgroundCrop(width,height,imageWidth,imageHeight)
    if not C.IsNumber(width) or not C.IsNumber(height) or not C.IsNumber(imageWidth) or not C.IsNumber(imageHeight)
        or width<=0 or height<=0 or imageWidth<=0 or imageHeight<=0 then return; end
    local scale=height/imageHeight;
    local scaledWidth=imageWidth*scale;
    local visibleWidth=math.min(1,width/scaledWidth);
    return {left=1-visibleWidth,right=1,top=0,bottom=1,
        width=math.min(width,scaledWidth),height=height,scale=scale,scaledWidth=scaledWidth};
end
function ns.ApplyTalentBackground(texture,image,kind,width,height)
    local info;
    if kind=="atlas" then
        texture:SetAtlas(image);
        info=C.Try(C_Texture and C_Texture.GetAtlasInfo or GetAtlasInfo,image);
        if not C.IsTable(info) then return; end
    else
        texture:SetTexture(image); texture:SetTexCoord(0,1,0,1);
        -- The legacy fallback uses Blizzard's square TopLeft talent tile.
        info={width=256,height=256,leftTexCoord=0,rightTexCoord=1,topTexCoord=0,bottomTexCoord=1};
    end
    local crop=ns.TalentBackgroundCrop(width,height,info.width,info.height);
    if not crop or not C.IsNumber(info.leftTexCoord) or not C.IsNumber(info.rightTexCoord)
        or not C.IsNumber(info.topTexCoord) or not C.IsNumber(info.bottomTexCoord) then return; end
    local left,right,top,bottom=info.leftTexCoord,info.rightTexCoord,info.topTexCoord,info.bottomTexCoord;
    texture:SetTexCoord(left+(right-left)*crop.left,left+(right-left)*crop.right,
        top+(bottom-top)*crop.top,top+(bottom-top)*crop.bottom);
    texture:ClearAllPoints(); texture:SetPoint("TOPRIGHT"); texture:SetSize(crop.width,crop.height);
    return crop;
end
function ns.SetTalentIcon(texture,entry)
    texture:SetTexCoord(0,1,0,1);
    texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
    if not entry then return; end
    if C.IsString(entry.atlas) and entry.atlas~="" then
        local ok=pcall(texture.SetAtlas,texture,entry.atlas);
        if ok then return; end
    end
    local icon=C.Icon(entry.icon) or (entry.spell and C.Icon(C.Try(C.GetSpellTexture,entry.spell)));
    if icon and texture:SetTexture(icon)==false then texture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); end
end
local function ForeverLayout(panel,width,height)
    local xs,ys={},{};
    for _,node in ipairs(panel.nodes) do xs[node.x]=true; ys[node.y]=true; end
    local columns,rows={},{};
    for x in pairs(xs) do columns[#columns+1]=x; end; table.sort(columns);
    for y in pairs(ys) do rows[#rows+1]=y; end; table.sort(rows);
    local unit=math.huge;
    -- Axis-only gaps can be tiny when nodes in one row are slightly offset.
    for i,node in ipairs(panel.nodes) do for j=i+1,#panel.nodes do
        local other=panel.nodes[j];
        local distance=math.max(math.abs(node.x-other.x),math.abs(node.y-other.y));
        if distance>0 then unit=math.min(unit,distance); end
    end end
    if unit==math.huge then unit=1; end
    local gaps={};
    local function Axis(values,axis)
        local positions,span={},0;
        for i,value in ipairs(values) do
            if i>1 then
                local gap=(value-values[i-1])/unit;
                -- Remote nodes must not shrink the entire tree to a few pixels.
                if gap>8 then
                    gaps[#gaps+1]={axis=axis,from=values[i-1],to=value};
                    gap=2;
                end
                span=span+gap;
            end
            positions[value]=span;
        end
        return positions,span;
    end
    local xPositions,spanX=Axis(columns,"x");
    local yPositions,spanY=Axis(rows,"y");
    local size=math.max(1,math.min(32,(width-16)/(spanX*1.1+1),(height-16)/(spanY*1.1+1)));
    local step=48;
    if spanX>0 then step=math.min(step,(width-16-size)/spanX); end
    if spanY>0 then step=math.min(step,(height-16-size)/spanY); end
    local left=(width-spanX*step-size)/2;
    local layout={size=size,fit=size/32,positions={},compressedGaps=gaps};
    for _,node in ipairs(panel.nodes) do
        layout.positions[node.id]={x=left+xPositions[node.x]*step,y=8+yPositions[node.y]*step};
    end
    return layout;
end
function ns.TalentPanelLayout(panel,width,height)
    if C.isForever and not panel.role then return ForeverLayout(panel,width,height); end
    if panel.role=="mists" then
        local size=math.max(1,math.min(32,(width-54)/3,(height-16)/6));
        local stepX=(width-54-size)/2;
        local stepY=(height-16-size)/5;
        local layout={size=size,fit=size/32,positions={}};
        for _,node in ipairs(panel.nodes) do
            layout.positions[node.id]={x=38+(node.x/100-1)*stepX,y=8+(node.tier-1)*stepY};
        end
        return layout;
    end
    if panel.role=="pvp" then
        local count=#panel.nodes;
        local size=math.max(1,math.min(48,width-32,(height-16)/math.max(1,count+math.max(0,count-1)*0.45)));
        local gap=size*0.45;
        local top=(height-(count*size+math.max(0,count-1)*gap))/2;
        local layout={size=size,fit=size/32,positions={}};
        for index,node in ipairs(panel.nodes) do
            layout.positions[node.id]={x=(width-size)/2,y=top+(index-1)*(size+gap)};
        end
        return layout;
    end
    local nodes,selectors,xs,ys={},{},{},{};
    for _,node in ipairs(panel.nodes) do
        local selector=panel.role=="hero" and node.isSubTreeSelection;
        if panel.role=="hero" and not selector then for _,entry in ipairs(node.choices or {}) do if entry.subTreeID then selector=true; break end end end
        if selector then selectors[#selectors+1]=node;
        else nodes[#nodes+1]=node; xs[node.x]=true; ys[node.y]=true; end
    end
    local columns,rows={},{};
    for x in pairs(xs) do columns[#columns+1]=x; end; table.sort(columns);
    for y in pairs(ys) do rows[#rows+1]=y; end; table.sort(rows);
    local xIndex,yIndex={},{};
    for i,x in ipairs(columns) do xIndex[x]=i-1; end
    for i,y in ipairs(rows) do yIndex[y]=i-1; end
    local size=math.max(1,math.min(32,(width-16)/math.max(1,(#columns-1)*1.1+1,#selectors*1.4),
        (height-16)/math.max(1,(#rows-1)*1.1+1+(#selectors>0 and 1.8 or 0))));
    local selectorHeight=#selectors>0 and size*1.8 or 0;
    local stepX=#columns>1 and math.min(48,(width-16-size)/(#columns-1)) or 0;
    local stepY=#rows>1 and math.min(48,(height-16-size-selectorHeight)/(#rows-1)) or 0;
    local rawW=math.max(1,#columns-1)*stepX+size;
    local rawH=math.max(0,#rows-1)*stepY+size+selectorHeight;
    local left=(width-rawW)/2;
    local top=panel.role=="hero" and math.max(8,(height-rawH)/2) or 8;
    local layout={size=size,fit=size/32,positions={}};
    for _,node in ipairs(nodes) do layout.positions[node.id]={x=left+xIndex[node.x]*stepX,y=top+yIndex[node.y]*stepY+selectorHeight}; end
    table.sort(selectors,function(a,b) return a.id<b.id; end);
    for i,node in ipairs(selectors) do layout.positions[node.id]={x=(width-(#selectors-1)*size*1.4-size)/2+(i-1)*size*1.4,y=top}; end
    return layout;
end
function ns.TalentTabs(data,classToken)
    local tabs={};
    if C.isRetail and C.IsTable(data.panels) then
        for _,role in ipairs({"class","spec","hero","other"}) do
            local found=false;
            for _,panel in ipairs(data.panels) do if panel.role==role then
                local labels={class=CLASS or ns.L.Class,spec=ns.L.Spec,hero=HERO_TALENTS or ns.L.Hero};
                local locked=role=="hero" and C.IsNumber(data.unitLevel) and C.IsNumber(data.heroRequiredLevel) and data.unitLevel<data.heroRequiredLevel;
                tabs[#tabs+1]={key=role,name=labels[role] or panel.name,fullName=role=="spec" and (SPECIALIZATION or ns.L.Specialization) or nil,role=role,nodes=panel.nodes,disabled=locked or (role=="hero" and #panel.nodes==0),
                    reason=locked and ns.F("Hero talents unlock at level %d.",data.heroRequiredLevel) or nil};
                found=true;
            end end
            if role=="hero" and not found then
                local locked=C.IsNumber(data.unitLevel) and C.IsNumber(data.heroRequiredLevel) and data.unitLevel<data.heroRequiredLevel;
                tabs[#tabs+1]={key="hero",name=HERO_TALENTS or ns.L.Hero,role="hero",nodes={},disabled=true,
                    reason=locked and ns.F("Hero talents unlock at level %d.",data.heroRequiredLevel) or ns.L["No selected Hero talent tree is available for this inspection."]};
            end
        end
        local pvp={key="pvp",name=PVP or ns.L.PvP,role="pvp",nodes={}};
        for index=1,3 do
            local talent=data.pvp and data.pvp[index] or {};
            if C.IsNumber(talent.id) and talent.id>0 then
                pvp.nodes[#pvp.nodes+1]={id=-index,x=100,y=index*100,rank=1,max=1,pvp=true,entry=talent,edges={}};
            end
        end
        if #pvp.nodes>0 then tabs[#tabs+1]=pvp; end
    else
        for index,tree in ipairs(data.trees or {}) do
            local name=tree.name;
            local fullName,treeSpecID=tree.name,nil;
            if C.isForever then
                local specs=foreverTrees[foreverClasses[data.specID] or classToken];
                treeSpecID=specs and specs[index];
                local label=shortNames[treeSpecID];
                if label then name=ns.L[label]; fullName=name; end
                local points=ns.Talents.Points(tree,data.state=="ready");
                if points then name=name.." |cff00ff00"..C.FormatNumber(points).."|r"; end
            end
            tabs[#tabs+1]={key="tree:"..tostring(tree.id or index),id=tree.id,name=name,fullName=fullName,backgroundSpecID=treeSpecID,icon=tree.icon,role=tree.role,nodes=tree.nodes};
        end
    end
    for _,tree in ipairs(data.extraTrees or {}) do
        tabs[#tabs+1]={key=tree.id,id=tree.id,name=tree.name,role=tree.role,nodes=tree.nodes};
    end
    return tabs;
end
function ns.TalentBuildLink(value)
    if (C.isRetail or C.isForever) and C.IsString(value) and value~="" and value:match("^[A-Za-z0-9+/=]+$") then
        return "https://www.wowhead.com/"..(C.isForever and "forever/" or "").."talent-calc/blizzard/"..value;
    end
end
function ns.DrawTalentTree(mod,tree,canvas,width,height,Button,lines,zoom)
    mod.renderedTreeKey=tree.key; mod.renderedNodeIDs={};
    zoom=zoom or 1;
    local layout=ns.TalentPanelLayout(tree,width,height);
    local size,fit=layout.size*zoom,layout.fit*zoom;
    canvas:SetSize(width*zoom,height*zoom);
    local byID={};
    if tree.role=="mists" then
        mod.tierLabels=mod.tierLabels or {};
        local seen={};
        for _,node in ipairs(tree.nodes) do if node.unlockLevel and not seen[node.tier] then
            seen[node.tier]=true;
            local label=mod.tierLabels[node.tier];
            if not label then label=canvas:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); mod.tierLabels[node.tier]=label; end
            label:ClearAllPoints(); label:SetPoint("TOPLEFT",2,-layout.positions[node.id].y*zoom);
            label:SetSize(30,size); label:SetJustifyH("CENTER"); label:SetJustifyV("MIDDLE");
            label:SetText(C.FormatNumber(node.unlockLevel));
            label:SetTextColor(node.locked and 0.5 or 1,node.locked and 0.5 or 0.82,node.locked and 0.5 or 0);
            label:Show();
        end end
    end
    for index,node in ipairs(tree.nodes) do
        local button=Button(index); button.node=node;
        button:SetSize(size,size); button.border:SetSize(size*1.65,size*1.65);
        button.rank:SetFont(GameFontNormalSmall:GetFont(),math.max(8,math.min(12,12*fit)),"OUTLINE");
        button.rank:SetText((node.pvp or node.glyph) and "" or node.rank.."/"..node.max);
        local position=layout.positions[node.id];
        button:ClearAllPoints(); button:SetPoint("TOPLEFT",position.x*zoom,-position.y*zoom);
        ns.SetTalentIcon(button.icon,node.entry); button.icon:SetDesaturated(node.rank==0);
        button.border:SetVertexColor(node.rank>0 and 1 or 0.45,node.rank>0 and 0.82 or 0.45,node.rank>0 and 0 or 0.45);
        button:Show(); byID[node.id]=button; mod.renderedNodeIDs[node.id]=true;
    end
    local lineIndex=0;
    if canvas.CreateLine then for _,node in ipairs(tree.nodes) do for _,target in ipairs(node.edges or {}) do
        if byID[node.id] and byID[target] then
            lineIndex=lineIndex+1; local line=lines[lineIndex];
            if not line then line=canvas:CreateLine(nil,"BACKGROUND"); lines[lineIndex]=line; end
            line:SetThickness(2); line:SetColorTexture(0.6,0.5,0.25,0.8);
            line:SetStartPoint("CENTER",byID[node.id],0,0); line:SetEndPoint("CENTER",byID[target],0,0); line:Show();
        end
    end end end
end
