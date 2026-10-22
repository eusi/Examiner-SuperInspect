local _, ns = ...;
if ns.blocked then return; end
local C, G = ns.Compat, {};
ns.Gear = G;
local map = {
    STRENGTH="STR", AGILITY="AGI", STAMINA="STA", INTELLECT="INT", SPIRIT="SPI", ARMOR="ARMOR",
    ATTACK_POWER="AP", RANGED_ATTACK_POWER="RAP", SPELL_POWER="SPELLDMG", SPELL_HEALING_DONE="HEAL",
    SPELL_PENETRATION="SPELLPENETRATION", HEALTH="HP", MANA="MP", HEALTH_REGEN="HP5", POWER_REGEN0="MP5",
    CRIT_RATING="CRITRATING", HASTE_RATING="HASTERATING", HIT_RATING="HITRATING", MASTERY_RATING="MASTERYRATING",
    VERSATILITY="VERSATILITYRATING", DODGE_RATING="DODGERATING", PARRY_RATING="PARRYRATING",
    EXPERTISE_RATING="EXPERTISERATING", RESILIENCE_RATING="RESILIENCERATING", DEFENSE_SKILL_RATING="DEFENSERATING",
    SPELL_CRIT_RATING="SPELLCRITRATING", SPELL_HASTE_RATING="SPELLHASTERATING", SPELL_HIT_RATING="SPELLHITRATING",
    DAMAGE_PER_SECOND="DPS", LIFESTEAL="LEECH", SPEED="SPEED", AVOIDANCE="AVOIDANCE",
};
G.statMap, G.labels = {}, {};
for suffix, token in pairs(map) do
    local key = "ITEM_MOD_"..suffix.."_SHORT";
    G.statMap[key] = token;
    G.labels[token] = _G[key] or suffix:gsub("_", " ");
end
G.statMap.RESISTANCE0_NAME = "ARMOR";
-- These client keys do not follow ITEM_MOD_<name>_SHORT.
local aliases={ITEM_MOD_VERSATILITY="VERSATILITYRATING",ITEM_MOD_CR_LIFESTEAL_SHORT="LEECH",
    ITEM_MOD_CR_SPEED_SHORT="SPEED",ITEM_MOD_CR_AVOIDANCE_SHORT="AVOIDANCE",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT="SPELLDMG",ITEM_MOD_MANA_REGENERATION_SHORT="MP5",
    ITEM_MOD_BLOCK_RATING_SHORT="BLOCKRATING",ITEM_MOD_BLOCK_VALUE_SHORT="BLOCKVALUE",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT="ARMORPENETRATIONRATING",ITEM_MOD_PVP_POWER_SHORT="PVPPOWERRATING",
    ITEM_MOD_EXTRA_ARMOR_SHORT="BONUSARMOR"};
for key,token in pairs(aliases) do
    G.statMap[key]=token;
    if C.IsString(_G[key]) then G.labels[token]=_G[key]; end
end
G.labels.DPS=C.Text(_G.DAMAGE_PER_SECOND,C.Text(_G.ITEM_MOD_DAMAGE_PER_SECOND_SHORT,"DPS"));
for index,school in ipairs({"HOLY","FIRE","NATURE","FROST","SHADOW","ARCANE"}) do
    local token=school.."RESIST";
    G.statMap["RESISTANCE"..index.."_NAME"]=token;
    G.statMap["ITEM_MOD_"..school.."_RESISTANCE_SHORT"]=token;
    G.labels[token]=_G["RESISTANCE"..index.."_NAME"] or school;
end
for token,label in pairs(G.labels) do if not LibGearExam.StatNames[token] then LibGearExam.StatNames[token]=label; end end
wipe(LibGearExam.StatNamesSorted);
for token in pairs(LibGearExam.StatNames) do LibGearExam.StatNamesSorted[#LibGearExam.StatNamesSorted+1]=token; end
table.sort(LibGearExam.StatNamesSorted,function(a,b) return tostring(LibGearExam.StatNames[a])<tostring(LibGearExam.StatNames[b]); end);
function G.ResolveStat(key)
    if not C.IsString(key) or key:match("^EMPTY_SOCKET_") then return; end
    local token=G.statMap[key];
    if token then return token; end
    token=key; G.statMap[key]=token;
    G.labels[token]=C.Text(_G[key]) or key:gsub("^ITEM_MOD_",""):gsub("_SHORT$",""):gsub("_"," ");
    LibGearExam.StatNames[token]=G.labels[token];
    LibGearExam.StatNamesSorted[#LibGearExam.StatNamesSorted+1]=token;
    return token;
end
local function Add(destination, source)
    for key,value in pairs(source) do
        if C.IsNumber(value) then destination[key] = (destination[key] or 0) + value; end
    end
end
local function Clean(text)
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\194\160", " ");
end
local function Number(text)
    -- Equipment stat amounts are integral; punctuation in those amounts groups thousands.
    return tonumber((text:gsub("[%,%.%s]", "")));
end
function G.ParseLine(text)
    if not C.IsString(text) then return {}; end
    text = Clean(text);
    local stats, matched = {}, false;
    for key,token in pairs(G.statMap) do
        local label = _G[key];
        if C.IsString(label) and #label > 0 then
            local escaped = label:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1");
            local amount = text:match("^%+([%d%,%.]+)%s+"..escaped.."%s*$");
            -- Percent bonuses and rating amounts use separate keys.
            if amount and not text:find("%%") then
                stats[token] = Number(amount); matched = true;
            end
        end
    end
    if not matched and text:match("^%+") and not text:find("%%") then
        -- Hybrid gem lines must contain only recognized flat stats.
        local remaining,combined=text,{};
        local function NextStat(tail)
            tail=tail:gsub("^%s+",""):gsub("%s+$","");
            if tail=="" then return ""; end
            if tail:match("^%+") then return tail; end
            local nextText,count=tail:gsub("^[,;/&]%s*","",1);
            if count>0 then return nextText; end
            for _,word in ipairs({"and","und","et","y","e","и","및","和","與"}) do
                if tail:sub(1,#word)==word then
                    local rest=tail:sub(#word+1);
                    if rest:match("^%s+") then return rest:gsub("^%s+",""); end
                end
            end
        end
        while remaining~="" do
            local found=false;
            for key,token in pairs(G.statMap) do
                local label=_G[key];
                if C.IsString(label) and label~="" then
                    local escaped=label:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])","%%%1");
                    local amount,tail=remaining:match("^%+?([%d%,%.]+)%s+"..escaped.."(.*)$");
                    local nextText=tail and NextStat(tail);
                    local value=amount and Number(amount);
                    if C.IsNumber(value) and nextText~=nil then
                        combined[token]=(combined[token] or 0)+value;
                        remaining=nextText; found=true; break;
                    end
                end
            end
            if not found then combined=nil; break; end
        end
        if combined then stats=combined; matched=true; end
    end
    if not matched then
        -- Match the whole line to exclude stat amounts inside proc descriptions.
        local exact=false;
        for _,pattern in ipairs(LibGearExam.Patterns) do
            local first,last=text:find(pattern.p);
            if first==1 and last==#text then exact=true; break end
        end
        if exact then LibGearExam:ScanLineForPatterns(text, stats); end
    end
    return stats;
end

function G.Tooltip(link, unit, slot)
    local api = C_TooltipInfo;
    local data,inventory;
    if api then
        if unit and slot then
            data = C.Try(api.GetInventoryItem, unit, slot);
            inventory=C.IsTable(data) and C.IsTable(data.lines);
        end
        if not inventory then data = C.Try(api.GetHyperlink, link); end
        if C.IsTable(data) and C.IsTable(data.lines) then return data.lines,inventory; end
    end
    local tip = LibGearExam.Tip;
    tip:ClearLines();
    local ok, problem;
    if unit and slot then ok,problem = pcall(tip.SetInventoryItem, tip, unit, slot);
    else ok,problem = pcall(tip.SetHyperlink, tip, link); end
    if not ok then ns.Record("tooltip-error", tostring(problem)); return nil; end
    local lines = {};
    for i=2,tip:NumLines() do
        local left = _G[tip:GetName().."TextLeft"..i];
        if left then
            local r,g,b = left:GetTextColor();
            lines[#lines+1] = { leftText=left:GetText(), leftColor={r=r,g=g,b=b} };
        end
    end
    return #lines > 0 and lines or nil,unit~=nil and slot~=nil;
end

function G.Item(link, unit, slot, result)
    local raw = C_Item and C.Try(C_Item.GetItemStats, link) or C.Try(GetItemStats, link);
    local base = {};
    if C.IsTable(raw) then
        for key,value in pairs(raw) do
            if C.IsSecret(key) or C.IsSecret(value) then result.statsPartial=true;
            elseif C.IsNumber(value) and value~=0 then
                local token=G.ResolveStat(key);
                if token then base[token]=(base[token] or 0)+value; end
            end
        end
    end
    local scanned, baseSeen, setName, setCount = {}, {}, nil, nil;
    local lines,inventory = G.Tooltip(link, unit, slot);
    local enchantID = tonumber(link:match("item:%d+:(%d+)")) or 0;
    local enchantSeen = false;
    if C.isSoD and not result.runesInitialized then
        LibRunes:CreateRunesTable(result.class); result.runesInitialized=true;
    end
    if lines then
        for _,line in ipairs(lines) do
            local text = C.IsTable(line) and C.Text(line.leftText);
            if text then
                text = Clean(text);
                local name,count,maximum = text:match("^(.+) %((%d+)/(%d+)%)$");
                if name then
                    setName=name;
                    local expected=result.expectedSets and result.expectedSets[name];
                    setCount=inventory and unit and tonumber(count) or (C.IsTable(expected) and C.Number(expected.count));
                    if setCount then result.sets[name] = {count=setCount,max=tonumber(maximum)};
                    elseif unit then result.statsPartial=true; end
                else
                    local color = C.IsTable(line.leftColor) and line.leftColor;
                    local gray = color and C.IsNumber(color.r) and C.IsNumber(color.g) and C.IsNumber(color.b)
                        and math.abs(color.r-0.5)<0.02 and math.abs(color.g-0.5)<0.02 and math.abs(color.b-0.5)<0.02;
                    local prefix = (ITEM_SET_BONUS or "Set: %s"):gsub("%%s", "");
                    local bonus = text:find(prefix,1,true) ~= nil;
                    local enchantPrefix=(ENCHANTED_TOOLTIP_LINE or "Enchanted: %s"):gsub("%%s", "");
                    local enchanted=enchantID>0 and text:find(enchantPrefix,1,true)~=nil;
                    local needed = tonumber(text:match("^%((%d+)%)"));
                    local active = not gray and (not needed or (setCount and setCount >= needed));
                    if bonus and not (inventory and unit) and not setCount then active=false; end
                    local usePrefix = ITEM_SPELL_TRIGGER_ONUSE or "Use:";
                    local equipPrefix=ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:";
                    local flat=text:find("^%+?[%d%,%.]+%s")~=nil;
                    local legacy=C.isEra or C.isTBC or C.isSoD;
                    if active and not text:find(usePrefix,1,true) and (flat or enchanted or bonus or legacy or text:sub(1,#equipPrefix)==equipPrefix) then
                        local parseText=text;
                        if bonus then
                            local start=parseText:find(prefix,1,true); parseText=parseText:sub(start+#prefix):gsub("^%s+","");
                        elseif enchanted then
                            local start=parseText:find(enchantPrefix,1,true); parseText=parseText:sub(start+#enchantPrefix):gsub("^%s+","");
                        else
                            if parseText:sub(1,#equipPrefix)==equipPrefix then parseText=parseText:sub(#equipPrefix+1):gsub("^%s+",""); end
                        end
                        local values = G.ParseLine(parseText);
                        if bonus then
                            local key = (setName or "unknown")..":"..text;
                            if (unit or result.expectedSets) and not result.seenSets[key] then Add(result.setStats,values); result.seenSets[key]=true; end
                        else
                            Add(scanned,values);
                            if not enchanted then for token in pairs(values) do baseSeen[token]=true; end end
                        end
                        if enchanted and next(values) then enchantSeen=true; end
                    end
                    if C.isSoD and LibRunes.abilities[text] and not result.seenRunes[text] then
                        result.runes[#result.runes+1]={name=text,spellID=LibRunes.abilities[text],slot=slot}; result.seenRunes[text]=true;
                    end
                end
            end
        end
    end
    -- Tooltip totals replace structured amounts to avoid counting base stats twice.
    for key,value in pairs(scanned) do
        if baseSeen[key] or base[key]==nil then base[key]=value;
        else result.statsPartial=true; end
    end
    if not lines or (enchantID > 0 and not enchantSeen) or (not next(base) and not next(scanned)) then result.statsPartial=true; end
    Add(result.stats,base);
    if C.IsNumber(base.DPS) and base.DPS~=0 then
        result.dpsSources=result.dpsSources or {};
        result.dpsSources[#result.dpsSources+1]={link=link,slot=slot,value=base.DPS};
    end
end

function G.ReadGems(links)
    local summary={items={},count=0,pending={},state="ready"};
    local byID,pending,unknown={},{},false;
    local hasAPI=type(C.GetItemGem)=="function";
    for _,slotName in ipairs(LibGearExam.Slots) do
        local link=links[slotName];
        if C.IsString(link) then
            local fields={};
            local payload=link:match("item:([^|]+)") or "";
            for field in (payload..":"):gmatch("(.-):") do
                fields[#fields+1]=field; if #fields==6 then break; end
            end
            if not hasAPI and #fields<6 then unknown=true; end
            for socket=1,4 do
                local expected=tonumber(fields[socket+2]);
                if expected and (expected<=0 or expected%1~=0) then expected=nil; end
                local gemName,gemLink=C.Try(C.GetItemGem,link,socket);
                if C.IsSecret(gemName) or C.IsSecret(gemLink) then unknown=true; gemName,gemLink=nil,nil; end
                gemName=C.Text(gemName); gemLink=C.Text(gemLink);
                local id=gemLink and tonumber(gemLink:match("item:(%d+)"));
                if id and id<=0 then id=nil; end
                if expected and id~=expected then id=expected; gemLink="item:"..id; gemName=nil; end
                if id then
                    local key=id;
                    gemLink=gemLink or ("item:"..id);
                    if not gemName or gemName=="" then gemName=C.Text(C.Try(C.GetItemInfo,gemLink)); end
                    if gemName=="" then gemName=nil; end
                    local gem=byID[key];
                    if not gem then
                        gem={id=id,link=gemLink,name=gemName,count=0,slots={}};
                        byID[key]=gem; summary.items[#summary.items+1]=gem;
                    elseif gemName then gem.name=gemName; end
                    gem.count=gem.count+1; summary.count=summary.count+1;
                    gem.slots[#gem.slots+1]=slotName;
                    if not gemName and not pending[id] then
                        summary.pending[#summary.pending+1]="item:"..id; pending[id]=true;
                    end
                end
            end
        end
    end
    table.sort(summary.items,function(a,b) return a.id<b.id; end);
    if #summary.pending>0 then summary.state="loading";
    elseif unknown then summary.state=summary.count>0 and "partial" or "unavailable"; end
    return summary;
end
function G.Calculate(links, unit, knownEmpty, expectedSets)
    local result = {links={},stats={},sets={},runes={},levels={},pending={},setStats={},seenSets={},seenRunes={},count=0,total=0,denominator=0,time=time()};
    result.class = ns.ex and ns.ex.info.class;
    result.expectedSets=expectedSets;
    for _,slotName in ipairs(LibGearExam.Slots) do
        local slot,link = LibGearExam.SlotIDs[slotName],links[slotName];
        local scored = slotName ~= "ShirtSlot" and slotName ~= "TabardSlot";
        if scored then result.denominator=result.denominator+1; end
        if C.IsString(link) and #link>0 then
            result.links[slotName]=link;
            local itemName,_,_,baseLevel,_,_,_,_,equip = C.Try(C.GetItemInfo,link);
            local level = C.Try(C.GetDetailedItemLevelInfo,link);
            level=C.Number(level,C.Number(baseLevel));
            if not level or not C.IsString(itemName) then result.pending[#result.pending+1]=link;
            else
                result.levels[slotName]=level;
                G.Item(link,unit,slot,result);
                if scored then
                    result.count=result.count+1; result.total=result.total+level;
                    result.min=math.min(result.min or level,level); result.max=math.max(result.max or level,level);
                    if slotName=="MainHandSlot" then result.mainType=C.Text(equip); end
                end
            end
        elseif not knownEmpty then result.pending[#result.pending+1]=slotName; end
    end
    if result.mainType == "INVTYPE_2HWEAPON" and not result.links.SecondaryHandSlot then
        result.total=result.total+(result.levels.MainHandSlot or 0);
    end
    Add(result.stats,result.setStats);
    result.gems=G.ReadGems(result.links);
    if #result.pending>0 and result.gems.state=="ready" then result.gems.state="loading"; end
    -- Socket detection alone cannot prove every conditional gem contribution.
    if result.gems.count>0 then result.statsPartial=true; end
    result.average = result.denominator>0 and result.total/result.denominator or 0;
    result.state = #result.pending==0 and "ready" or "loading";
    result.statsState = result.statsPartial and "partial" or result.state;
    result.setStats,result.seenSets,result.seenRunes,result.class,result.expectedSets,result.runesInitialized=nil,nil,nil,nil,nil,nil;
    return result;
end

function G.Apply(ex, result)
    ex.gear = result;
    wipe(ex.unitStats); Add(ex.unitStats,result.stats);
    ex.info.Items=CopyTable(result.links); ex.info.Sets=CopyTable(result.sets); ex.info.Runes=CopyTable(result.runes);
    ex.info.iLvlAverage=result.average;
    ex.averageItemLevel=C.FormatNumber(result.average);
    ex.itemsLoaded = result.count>0 or result.state=="ready";
    ex.gs,ex.gsQualityColor="-",nil;
    if result.state=="ready" and ex.unit then
        local lib=LibStub("LibFroznFunctions-1.0",true);
        local score=lib and C.Try(lib.GetAverageItemLevel,lib,ex.unit);
        if C.IsTable(score) and C.IsNumber(score.TacoTipGearScore) then
            ex.gs=math.floor(score.TacoTipGearScore); ex.gsQualityColor=score.TacoTipGearScoreQualityColor;
        end
    end
end

function G.Normalized(stats,token,combine)
    local value=C.Number(stats[token],0);
    if combine and token=="RAP" then value=value+C.Number(stats.AP,0); end
    if combine and token=="SANCTIFIED" and C.Number(stats["SANCTIFIED-SET"],0)>2 then value=value+2; end
    return value;
end
