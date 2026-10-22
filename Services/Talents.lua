local _, ns = ...;
if ns.blocked then return; end
local C,T=ns.Compat,{requested={}}; ns.Talents=T;
function T.RemoveDetachedDuplicates(tree,specID,treeIndex)
    if not C.isForever or not C.IsTable(tree.nodes) or #tree.nodes<4 then return; end
    local nearest,connected,unit={},{},math.huge;
    for i,node in ipairs(tree.nodes) do
        nearest[i]=math.huge;
        for _,target in ipairs(node.edges or {}) do connected[node.id]=true; connected[target]=true; end
        for j,other in ipairs(tree.nodes) do if i~=j then
            local distance=math.max(math.abs(node.x-other.x),math.abs(node.y-other.y));
            nearest[i]=math.min(nearest[i],distance);
            if distance>0 then unit=math.min(unit,distance); end
        end end
    end
    if unit==math.huge then return; end
    local core={};
    for i,node in ipairs(tree.nodes) do if nearest[i]<=8*unit then core[#core+1]=node; end end
    if #core<3 or #core<=#tree.nodes/2 then return; end
    local minX,minY=math.huge,math.huge;
    for _,node in ipairs(core) do minX=math.min(minX,node.x); minY=math.min(minY,node.y); end
    local function SameTalent(a,b)
        if not a.entry or not b.entry or a.entry.pending or b.entry.pending
            or #(a.choices or {})>1 or #(b.choices or {})>1 then return false; end
        local x,y=a.entry,b.entry;
        if a.max~=b.max then
            -- Forever replaced five-rank Improved Serpent Sting with Improved Stings (row 2, column 1).
            return specID==1485 and treeIndex==2 and a.max==5 and b.max==3
                and C.Icon(x.icon)~=nil and x.icon==y.icon
                and math.abs(b.x-minX)<unit*0.01 and math.abs(b.y-minY-unit)<unit*0.01;
        end
        if x.id and x.id==y.id or x.definition and x.definition==y.definition
            or x.spell and (x.spell==y.spell or x.spell==y.overriddenSpell)
            or y.spell and y.spell==x.overriddenSpell then return true; end
        return C.IsString(x.name) and x.name~="" and x.name==y.name and x.icon and x.icon==y.icon;
    end
    local kept={};
    for i,node in ipairs(tree.nodes) do
        local replacement;
        -- Only detached, unspent copies of a talent already present in the main tree.
        if nearest[i]>8*unit and node.rank==0 and (node.spent==nil or node.spent==0) and not connected[node.id] then
            for _,other in ipairs(core) do if SameTalent(node,other) then
                if replacement then replacement=nil; break; end
                replacement=other;
            end end
        end
        if replacement then
            tree.omittedDuplicates=tree.omittedDuplicates or {};
            tree.omittedDuplicates[#tree.omittedDuplicates+1]={id=node.id,replacement=replacement.id,
                x=node.x,y=node.y,name=node.entry.name};
        else kept[#kept+1]=node; end
    end
    tree.nodes=kept;
end
function T.Points(tree,complete)
    local function Count(value)
        if C.IsNumber(value) and value>=0 and value<math.huge and value%1==0 then return value; end
    end
    local supplied=Count(tree.points);
    if supplied then return supplied; end
    if not complete then return; end
    local total=0;
    for _,node in ipairs(tree.nodes or {}) do
        local spent=Count(node.spent) or Count(node.rank);
        if not spent then return; end
        total=total+spent;
    end
    return total;
end
local function RequestSpell(spell)
    if not C.IsNumber(spell) or spell<=0 then return; end
    local request=T.requested[spell]; local now=GetTime();
    if not request or (request.count<2 and now-request.time>=2) then
        T.requested[spell]={count=request and request.count+1 or 1,time=now};
        C.Try(C_Spell and C_Spell.RequestLoadSpellData,spell);
    end
end
function T.LowLevelData(unit,level)
    if not C.isRetail then return; end
    level=C.Number(level) or (unit and C.Number(C.Try(UnitLevel,unit)));
    if level and level>=1 and level<10 then
        return {kind=C.talentKind,state="locked",reason="level",unitLevel=level,requiredLevel=10,trees={},time=time(),build=C.build};
    end
end
local function Entry(configID,id)
    local entry=C.Try(C_Traits.GetEntryInfo,configID,id);
    if not C.IsTable(entry) then return; end
    -- Hero subtree selectors have no definitionID by design.
    if C.IsNumber(entry.subTreeID) then
        local subtree=C.Try(C_Traits.GetSubTreeInfo,configID,entry.subTreeID);
        if not C.IsTable(subtree) then return; end
        return {id=id,subTreeID=entry.subTreeID,name=C.Text(subtree.name,"Hero talents"),atlas=C.Text(subtree.iconElementID),max=C.Number(entry.maxRanks,1)};
    end
    if not C.IsNumber(entry.definitionID) then return; end
    local def=C.Try(C_Traits.GetDefinitionInfo,entry.definitionID);
    if not C.IsTable(def) then return; end
    local spell=C.Number(def.spellID);
    local spellInfo=spell and C_Spell and C.Try(C_Spell.GetSpellInfo,spell);
    local name=C.Text(def.overrideName); if name=="" then name=nil; end
    name=name or (C.IsTable(spellInfo) and C.Text(spellInfo.name));
    if not name and C.isForever and spell then name=C.Text(C.Try(C_Spell and C_Spell.GetSpellName,spell)); end
    if name=="" then name=nil; end
    local icon=C.Icon(def.overrideIcon);
    if not icon then
        local infoIcon=C.IsTable(spellInfo) and C.Icon(spellInfo.iconID);
        local spellIcon,originalIcon;
        if spell and (C.isForever or not infoIcon) then spellIcon,originalIcon=C.Try(C.GetSpellTexture,spell); end
        icon=(C.isForever and C.Icon(originalIcon)) or infoIcon or C.Icon(spellIcon);
    end
    local pending=spell and (not name or not icon);
    if pending then RequestSpell(spell); end
    return {id=id,spell=spell,definition=C.Number(entry.definitionID),overriddenSpell=C.Number(def.overriddenSpellID),
        name=name or ("Talent "..id),icon=icon,pending=pending,max=C.Number(entry.maxRanks,1)};
end
local function Flag(flags,flag)
    return C.IsNumber(flags) and C.IsNumber(flag) and flag>0 and math.floor(flags/flag)%2==1;
end
local function NodeCategory(configID,node)
    if C.IsNumber(node.subTreeID) then return "hero"; end
    local costs=C.Try(C_Traits.GetNodeCost,configID,node.id);
    local flagsEnum=Enum and Enum.TraitCurrencyFlag or {};
    if C.IsTable(costs) then for _,cost in ipairs(costs) do
        if C.IsTable(cost) and C.IsNumber(cost.ID) then
            local flags=C.Try(C_Traits.GetTraitCurrencyInfo,cost.ID);
            if Flag(flags,flagsEnum.UseClassIcon) then return "class"; end
            if Flag(flags,flagsEnum.UseSpecIcon) then return "spec"; end
        end
    end end
end
local function CategorizeRetail(data,configID,unit,isSelf)
    if not C.isRetail then return; end
    data.layout="tabs";
    data.unitLevel=C.Number(C.Try(UnitLevel,unit));
    local _,requiredLevel=C.Try(C_ClassTalents and C_ClassTalents.GetHeroTalentSpecsForClassSpec,configID,data.specID);
    data.heroRequiredLevel=C.Number(requiredLevel);
    local buckets={class={role="class",name=CLASS or "Class",nodes={}},spec={role="spec",name=data.specName or SPECIALIZATION or "Specialization",nodes={}},
        hero={role="hero",name=HERO_TALENTS or "Hero talents",nodes={}},other={role="other",name=TALENTS or "Talents",nodes={}}};
    local all,byID={},{};
    for _,tree in ipairs(data.trees) do for _,node in ipairs(tree.nodes) do
        if not byID[node.id] then all[#all+1]=node; byID[node.id]=node; end
    end end
    local roles={};
    for _,node in ipairs(all) do
        roles[node.id]=NodeCategory(configID,node);
        for _,entry in ipairs(node.choices or {}) do if entry.subTreeID then roles[node.id]="hero"; node.isSubTreeSelection=true; end end
    end
    -- Free/rank-granted nodes can inherit the explicit currency category of a connected node.
    for pass=1,4 do
        local changed=false;
        for _,node in ipairs(all) do for _,target in ipairs(node.edges or {}) do
            if byID[target] then
                if roles[node.id] and not roles[target] then roles[target]=roles[node.id]; changed=true;
                elseif roles[target] and not roles[node.id] then roles[node.id]=roles[target]; changed=true; end
            end
        end end
        if not changed then break end
    end
    for _,node in ipairs(all) do local bucket=buckets[roles[node.id] or "other"]; bucket.nodes[#bucket.nodes+1]=node; end
    data.panels={};
    if #buckets.other.nodes>0 then
        local combined={role="other",name=TALENTS or "Talents",nodes={}};
        for _,role in ipairs({"class","spec","other"}) do for _,node in ipairs(buckets[role].nodes) do combined.nodes[#combined.nodes+1]=node; end end
        data.panels[1]=combined;
        if #buckets.hero.nodes>0 then data.panels[#data.panels+1]=buckets.hero; end
        data.message=data.message or "Section metadata unavailable; class and specialization are shown together.";
    else
        for _,role in ipairs({"class","hero","spec"}) do if #buckets[role].nodes>0 then data.panels[#data.panels+1]=buckets[role]; end end
    end
    data.pvp={}; local api=C_SpecializationInfo or {};
    local own=isSelf and C.Try(api.GetAllSelectedPvpTalentIDs);
    for index=1,3 do
        local slot=isSelf and C.Try(api.GetPvpTalentSlotInfo,index);
        local id=C.IsTable(slot) and C.Number(slot.selectedTalentID) or (C.IsTable(own) and C.Number(own[index])) or (not isSelf and C.Number(C.Try(api.GetInspectSelectedPvpTalent,unit,index)));
        local info=id and C.Try(api.GetPvpTalentInfo,id);
        local talent=C.IsTable(info) and {id=id,name=C.Text(info.name),icon=C.Icon(info.icon),spell=C.Number(info.spellID)};
        if not talent and id then
            local _,name,icon,_,_,spellID=C.Try(GetPvpTalentInfoByID,id);
            talent={id=id,name=C.Text(name),icon=C.Icon(icon),spell=C.Number(spellID)};
        end
        if talent and not talent.icon and talent.spell then talent.icon=C.Icon(C.Try(C.GetSpellTexture,talent.spell)); end
        data.pvp[index]=talent or {};
    end
end
function T.ReadTraits(unit,isSelf)
    local locked=T.LowLevelData(unit); if locked then return locked; end
    local data={kind="traits",state="loading",trees={},time=time(),build=C.build};
    if C.isForever then data.groupingVersion=2; end
    local specID,specName,_,specIcon=C.GetSpecialization(unit,isSelf);
    data.specID=C.Number(specID); data.specName=C.Text(specName); data.specIcon=C.Safe(specIcon);
    if not C_Traits then data.state="unavailable"; data.message="This client has no Traits API."; return data; end
    if not isSelf and not C.IsTrue(C.Try(C_Traits.HasValidInspectData)) then
        data.message="Waiting for inspected talent data."; return data;
    end
    local configID=isSelf and C_ClassTalents and C.Try(C_ClassTalents.GetActiveConfigID)
        or (not isSelf and Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID);
    if not C.IsNumber(configID) then data.state="unavailable"; data.message="No active talent configuration is available."; return data; end
    data.loadout=C.Text(isSelf and C.Try(C_Traits.GenerateImportString,configID) or C.Try(C_Traits.GenerateInspectImportString,unit));
    local config=C.Try(C_Traits.GetConfigInfo,configID);
    if not C.IsTable(config) or not C.IsTable(config.treeIDs) then data.message="Waiting for tree metadata."; return data; end
    local partial,pending,metadataPending,count=false,false,false,0;
    data.gaps={};
    local function Gap(kind,id)
        if #data.gaps<8 then data.gaps[#data.gaps+1]=kind..":"..tostring(id); end
    end
    if C.isRetail and not data.specName then pending=true; Gap("specialization",data.specID or 0); end
    local seenNodes={};
    for _,treeID in ipairs(config.treeIDs) do
        local ids=C.Try(C_Traits.GetTreeNodes,treeID);
        if C.isForever and C.IsTable(ids) then
            local unique={};
            for _,id in ipairs(ids) do
                if C.IsNumber(id) and not seenNodes[id] then unique[#unique+1]=id; seenNodes[id]=true; end
            end
            ids=unique;
        end
        local groups=C.Try(C_Traits.GetGroupDisplayInfoByTreeID,treeID);
        local buckets,order={},{};
        if C.IsTable(groups) then
            for _,group in ipairs(groups) do
                if C.IsTable(group) and C.IsNumber(group.groupID) then
                    local bucket={id=group.groupID,name=C.Text(group.displayName,"Talents"),icon=C.Icon(group.icon),nodes={},order=C.Number(group.orderIndex,0)};
                    buckets[group.groupID]=bucket; order[#order+1]=bucket;
                end
            end
            table.sort(order,function(a,b) return a.order<b.order; end);
            if C.isForever then
                local groupIDs={};
                for _,bucket in ipairs(order) do groupIDs[#groupIDs+1]=bucket.id; end
                local currencies=C.Try(C_Traits.GetGroupCurrencyInfo,configID,groupIDs);
                if C.IsTable(currencies) then for _,info in ipairs(currencies) do
                    local bucket=C.IsTable(info) and C.IsNumber(info.traitNodeGroupID) and buckets[info.traitNodeGroupID];
                    local currency=C.IsTable(info) and C.IsTable(info.currencyInfos) and info.currencyInfos[1];
                    local spent=C.IsTable(currency) and C.Number(currency.spent);
                    if bucket and spent and spent>=0 and spent<math.huge and spent%1==0 then bucket.points=spent; end
                end end
            end
        end
        if C.isForever and #order==0 then pending=true; Gap("groups",treeID); end
        local default={id=treeID,name=TALENTS or "Talents",nodes={}};
        if C.IsTable(ids) then
            for _,id in ipairs(ids) do
                if count>=1024 then partial=true; break end
                local node=C.Try(C_Traits.GetNodeInfo,configID,id);
                local inactiveHero=false;
                if C.isRetail and C.IsTable(node) and C.IsNumber(node.subTreeID) and not C.IsSecret(node.subTreeActive) then
                    inactiveHero=node.subTreeActive==false;
                    if node.subTreeActive==nil then
                        local subtree=C.Try(C_Traits.GetSubTreeInfo,configID,node.subTreeID);
                        inactiveHero=C.IsTable(subtree) and not C.IsSecret(subtree.isActive) and subtree.isActive==false;
                    end
                end
                if inactiveHero then
                    -- An unselected hero tree is an alternative, not an extra active tree.
                elseif C.IsTable(node) and not C.IsSecret(node.isVisible) and node.isVisible~=false
                    and (not C.isForever or C.IsTrue(node.isVisible)) then
                    local nodeData={id=id,x=C.Number(node.posX),y=C.Number(node.posY),rank=C.Number(node.currentRank),
                        max=C.isForever and C.Number(node.totalMaxRanks,C.Number(node.maxRanks,1)) or C.Number(node.maxRanks,1),
                        subTreeID=C.Number(node.subTreeID),edges={},choices={}};
                    if C.isForever then nodeData.spent=C.Number(node.ranksPurchased); end
                    if nodeData.max==0 then
                        -- Non-purchasable gate nodes do not represent a talent icon.
                    elseif nodeData.x and nodeData.y and nodeData.rank then
                        local active=C.IsTable(node.activeEntry) and C.Number(node.activeEntry.entryID);
                        local entries=C.IsTable(node.entryIDs) and node.entryIDs or (active and {active} or {});
                        for _,entryID in ipairs(entries) do
                            if C.IsNumber(entryID) then
                                local item=Entry(configID,entryID);
                                if item then
                                    if item.pending then metadataPending=true; Gap("spell",item.spell or entryID); end
                                    nodeData.choices[#nodeData.choices+1]=item;
                                    if entryID==active or not nodeData.entry then nodeData.entry=item; end
                                else pending=true; Gap("entry",entryID); end
                            end
                        end
                        if not nodeData.entry then pending=true; Gap("node-entry",id); end
                        if C.IsTable(node.visibleEdges) then
                            for _,edge in ipairs(node.visibleEdges) do
                                local target=C.IsTable(edge) and C.Number(edge.targetNode);
                                if target then nodeData.edges[#nodeData.edges+1]=target; end
                            end
                        end
                        local bucket;
                        if C.isForever then
                            nodeData.groupIDs={};
                            if C.IsTable(node.groupIDs) then for _,groupID in ipairs(node.groupIDs) do
                                if C.IsNumber(groupID) then nodeData.groupIDs[#nodeData.groupIDs+1]=groupID; end
                            end end
                            for _,candidate in ipairs(order) do
                                for _,groupID in ipairs(nodeData.groupIDs) do
                                    if candidate.id==groupID then bucket=candidate; break; end
                                end
                                if bucket then break; end
                            end
                            if not bucket then pending=true; Gap("group",id); end
                        else
                            local groupID=C.IsTable(node.groupIDs) and C.Number(node.groupIDs[1]);
                            bucket=groupID and buckets[groupID] or default;
                        end
                        if bucket then bucket.nodes[#bucket.nodes+1]=nodeData; end
                        count=count+1;
                    else
                        if C.IsSecret(node.posX) or C.IsSecret(node.posY) or C.IsSecret(node.currentRank) then partial=true;
                        else pending=true; end
                        Gap("position/rank",id);
                    end
                elseif not C.IsTable(node) then pending=true; Gap("node",id);
                elseif C.IsSecret(node.isVisible) then partial=true; Gap("restricted-node",id); end
            end
        else pending=true; Gap("tree",treeID); end
        for _,bucket in ipairs(order) do if C.isForever or #bucket.nodes>0 then data.trees[#data.trees+1]=bucket; end end
        if not C.isForever and #default.nodes>0 then data.trees[#data.trees+1]=default; end
    end
    data.state=count>0 and ((pending or metadataPending) and "loading" or partial and "partial" or "ready") or "loading";
    if C.isForever then for index,tree in ipairs(data.trees) do
        T.RemoveDetachedDuplicates(tree,data.specID,index);
        tree.points=T.Points(tree,count>0 and not pending and not partial);
    end end
    data.message=(pending or metadataPending) and "Loading remaining talent information…" or partial and "Some talent information is restricted or unavailable." or count==0 and "Waiting for visible talent nodes." or nil;
    CategorizeRetail(data,configID,unit,isSelf);
    return data;
end

function T.ReadMists(unit,isSelf)
    local data={kind="mists",state="loading",trees={},time=time(),build=C.build};
    local id,name,_,icon=C.GetSpecialization(unit,isSelf); data.specID=C.Number(id); data.specName=C.Text(name); data.specIcon=C.Icon(icon);
    local role=C.Text(C.Try(GetSpecializationRoleByID,data.specID));
    if role=="TANK" or role=="HEALER" or role=="DAMAGER" then data.specRole=role; end
    local tree={id=1,name=data.specName or TALENTS or "Talents",role="mists",nodes={}};
    local api=C_SpecializationInfo or {};
    local group=C.Number(C.Try(api.GetActiveSpecGroup or GetActiveSpecGroup,not isSelf),1);
    data.group=group;
    local pending=data.specID and (not data.specName or not data.specIcon) or false;
    for tier=1,6 do
        local available,_,unlock=C.Try(GetTalentTierInfo,tier,group,not isSelf,unit);
        unlock=C.Number(unlock);
        if not unlock or unlock<1 or unlock%1~=0 then unlock=nil; end
        for column=1,3 do
        local info;
        if type(api.GetTalentInfo)=="function" then
            info=C.Try(api.GetTalentInfo,{tier=tier,column=column,groupIndex=group,isInspect=not isSelf,target=unit});
        end
        if C.IsTable(info) and C.IsNumber(info.talentID) and info.talentID>0 and type(C.Safe(info.selected))=="boolean" then
            local spell=C.Number(info.spellID);
            local meta=spell and C.Try(C_Spell and C_Spell.GetSpellInfo,spell);
            local name=C.Text(info.name) or (C.IsTable(meta) and C.Text(meta.name));
            local icon=C.Icon(info.icon) or (C.IsTable(meta) and C.Icon(meta.iconID)) or (spell and C.Icon(C.Try(C.GetSpellTexture,spell)));
            local entry={name=name,icon=icon,spell=spell};
            if not name or not icon then pending=true; RequestSpell(spell); end
            if name then
                tree.nodes[#tree.nodes+1]={id=info.talentID,x=column*100,y=tier*100,
                    tier=tier,unlockLevel=unlock,locked=type(C.Safe(available))=="boolean" and not available or nil,
                    rank=C.IsTrue(info.selected) and 1 or 0,max=1,entry=entry,choices={entry},edges={}};
            end
        end
    end end
    if #tree.nodes>0 then data.trees={tree}; end
    local glyphs={id="glyphs",name=GLYPHS or "Glyphs",role="glyphs",nodes={}};
    for slot=1,6 do
        local enabled,kind,_,spell,icon=C.Try(GetGlyphSocketInfo,slot,group,not isSelf,unit);
        if C.IsTrue(enabled) and C.IsNumber(spell) and spell>0 then
            local spellInfo=C.Try(C_Spell and C_Spell.GetSpellInfo,spell);
            local name=C.IsTable(spellInfo) and C.Text(spellInfo.name) or C.Text(C.Try(GetSpellInfo,spell));
            local entry={spell=spell,name=name,icon=C.Icon(icon) or (C.IsTable(spellInfo) and C.Icon(spellInfo.iconID)) or C.Icon(C.Try(C.GetSpellTexture,spell))};
            if not name or not entry.icon then
                pending=true;
                RequestSpell(spell);
            end
            glyphs.nodes[#glyphs.nodes+1]={id=-slot,x=((slot-1)%3)*100,y=math.floor((slot-1)/3)*100,
                rank=1,max=1,entry=entry,glyph=true,glyphSlot=slot,glyphType=C.Number(kind),edges={}};
        elseif enabled==nil and kind==nil and type(GetGlyphSocketInfo)=="function" and C.Number(C.Try(UnitLevel,unit),0)>=25 then
            pending=true;
        end
    end
    if #glyphs.nodes>0 then data.extraTrees={glyphs}; end
    if #tree.nodes==18 and not pending then data.state="ready";
    elseif type(api.GetTalentInfo)=="function" then data.state="loading";
    else data.state=#glyphs.nodes>0 and "partial" or "unavailable"; end
    return data;
end

function T.Read(unit,isSelf)
    if C.isMists then return T.ReadMists(unit,isSelf); end
    return T.ReadTraits(unit,isSelf);
end
