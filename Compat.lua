local _, ns = ...;
if ns.blocked then return; end
local C = {};
ns.Compat = C;
local version, build, _, interface = GetBuildInfo();
C.version, C.build, C.interface = version, build, tonumber(interface) or 0;
local function Project(name)
    return _G[name] ~= nil and WOW_PROJECT_ID == _G[name];
end

-- Forever uses modern UI/Traits APIs despite its 1.x interface number.
C.isForever = Project("WOW_PROJECT_CAMELOT") or Project("WOW_PROJECT_FOREVER")
    or (C.interface >= 16000 and C.interface < 20000);
C.isEra = not C.isForever and (Project("WOW_PROJECT_CLASSIC") or (C.interface >= 10000 and C.interface < 16000));
C.isTBC = not C.isForever and (Project("WOW_PROJECT_BURNING_CRUSADE_CLASSIC") or (C.interface >= 20000 and C.interface < 30000));
C.isMists = Project("WOW_PROJECT_MISTS_CLASSIC") or (C.interface >= 50000 and C.interface < 60000);
C.isRetail = not C.isForever and (Project("WOW_PROJECT_MAINLINE") or C.interface >= 100000);
C.client = C.isForever and "Forever" or C.isEra and "Era" or C.isTBC and "TBC (optional)"
    or C.isMists and "Mists" or C.isRetail and "Retail" or "Unsupported";
C.talentKind = (C.isEra or C.isTBC) and "classic" or C.isMists and "mists" or "traits";

function C.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) or false;
end
function C.IsNumber(value)
    return not C.IsSecret(value) and type(value) == "number";
end
function C.IsString(value)
    return not C.IsSecret(value) and type(value) == "string";
end
function C.IsTable(value) return not C.IsSecret(value) and type(value) == "table"; end
function C.IsTrue(value) return not C.IsSecret(value) and value == true; end
function C.Safe(value) if not C.IsSecret(value) then return value; end end
function C.Number(value, fallback) if C.IsNumber(value) then return value; end return fallback; end
function C.Text(value, fallback) if C.IsString(value) then return value; end return fallback; end
function C.Icon(value)
    if C.IsNumber(value) and value>0 then return value; end
    if C.IsString(value) and value~="" and value~="0" then return value; end
end
function C.FormatNumber(value)
    if not C.IsNumber(value) or value~=value or value==math.huge or value==-math.huge then return "—"; end
    local text=string.format("%.2f",value):gsub("(%..-)0+$","%1"):gsub("%.$","");
    if text=="-0" then text="0"; end
    local separator=_G.DECIMAL_SEPERATOR;
    if C.IsString(separator) and separator~="." then text=text:gsub("%.",function() return separator; end); end
    return text;
end
C.clientKey = C.isForever and "forever" or C.isEra and (C.isSoD and "sod" or "era")
    or C.isTBC and "tbc" or C.isMists and "mists" or "retail";

local function TryResult(ok,...)
    if ok then return ...; end
    ns.Record("api-error",tostring((...)));
end
function C.Try(fn, ...)
    if type(fn) ~= "function" then return; end
    return TryResult(pcall(fn,...));
end

local seasonID = C_Seasons and C.Try(C_Seasons.GetActiveSeason);
local discoveryID = Enum and Enum.SeasonID and Enum.SeasonID.SeasonOfDiscovery;
C.isSoD = C.isEra and discoveryID ~= nil and seasonID == discoveryID;
C.seasonID = seasonID;
if C.isSoD then C.client = "SoD"; end
C.clientKey = C.isSoD and "sod" or C.clientKey;
C.hasLegacyHonor = C.isEra or C.isTBC;
C.profile={talents=C.talentKind,runes=C.isSoD,glyphs=C.isMists,
    arenaBrackets=(C.isTBC or C.isMists) and {2,3,5} or (C.isRetail or C.isForever) and {2,3} or {},
    soloRated=C.isRetail,classicRank=not C.isRetail and not C.isMists};

local CI, CA, CP = C_Item or {}, C_AddOns or {}, C_PaperDollInfo or {};
C.GetItemInfo = CI.GetItemInfo or GetItemInfo;
C.GetItemInfoInstant = CI.GetItemInfoInstant or GetItemInfoInstant;
C.GetItemQualityColor = CI.GetItemQualityColor or GetItemQualityColor;
C.GetDetailedItemLevelInfo = CI.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo;
C.GetItemGem = CI.GetItemGem or GetItemGem;
C.GetAddOnMetadata = CA.GetAddOnMetadata or GetAddOnMetadata;
C.GetAddOnMemoryUsage = CA.GetAddOnMemoryUsage or GetAddOnMemoryUsage;
C.UpdateAddOnMemoryUsage = CA.UpdateAddOnMemoryUsage or UpdateAddOnMemoryUsage;
C.GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture;
C.UnitPVPName = UnitPVPName or GetUnitName or UnitName;
C.GetQuestDifficultyColor = GetQuestDifficultyColor or function() return { r = 1, g = 1, b = 1 }; end;

function C.GetInventorySlotInfo(name)
    return C.Try(CP.GetInventorySlotInfo or GetInventorySlotInfo, name);
end

function C.LegacyTalentTab(index, inspect, group)
    local api=C_SpecializationInfo or {};
    if type(api.GetSpecializationInfo)=="function" then
        local _,name,_,icon,_,_,points,background=C.Try(api.GetSpecializationInfo,index,inspect or false,false,nil,nil,group);
        if C.IsString(name) then return name,icon,C.Number(points),C.Text(background); end
    end
    local a,b,c,d,e,f = C.Try(GetTalentTabInfo, index, inspect, false, group);
    if C.IsString(a) then return a,b,C.Number(c),d; end
    return C.Text(b),d,C.Number(e),f;
end
function C.ActiveTalentGroup(inspect)
    return C.Number(C.Try(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup or GetActiveTalentGroup,inspect),1);
end
function C.LegacyTalentInfo(tab,index,inspect,group)
    local fn=C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo;
    if type(fn)=="function" then
        local info=C.Try(fn,{specializationIndex=tab,talentIndex=index,isInspect=inspect or false,isPet=false,groupIndex=group});
        if not C.IsTable(info) then return; end
        return C.Text(info.name),C.Icon(info.icon),C.Number(info.tier),C.Number(info.column),C.Number(info.rank),C.Number(info.maxRank),
            C.Safe(info.meetsPrereq),C.Number(info.previewRank),C.Safe(info.meetsPreviewPrereq),C.Safe(info.isExceptional),C.Safe(info.hasGoldBorder),C.Number(info.talentID);
    end
    return C.Try(GetTalentInfo,tab,index,inspect,false,group);
end

function C.GetSpecialization(unit, isSelf)
    local api = C_SpecializationInfo or {};
    if not isSelf then
        local id=C.Try(api.GetInspectSpecialization or GetInspectSpecialization,unit);
        if C.IsNumber(id) and id>0 then
            local specID,name,description,icon,role=C.Try(api.GetSpecializationInfoByID or GetSpecializationInfoByID,id);
            if C.IsString(name) then return specID or id,name,description,icon,role; end
            -- Some modern clients expose lookup only by index plus classID.
            local _,_,classID=UnitClass(unit);
            for index=1,C.Number(C.Try(api.GetNumSpecializationsForClassID,classID),0) do
                specID,name,description,icon,role=C.Try(api.GetSpecializationInfo or GetSpecializationInfo,index,false,false,nil,C.Safe(UnitSex(unit)),nil,classID);
                if specID==id then return specID,name,description,icon,role; end
            end
            return id;
        end
    end
    local index = C.Try(api.GetSpecialization or GetSpecialization, not isSelf);
    if C.IsNumber(index) then
        return C.Try(api.GetSpecializationInfo or GetSpecializationInfo,index,not isSelf,false,unit);
    end
    if not isSelf then
        local id = C.Try(api.GetInspectSpecialization or GetInspectSpecialization, unit);
        if C.IsNumber(id) and id > 0 then return C.Try(api.GetSpecializationInfoByID or GetSpecializationInfoByID, id); end
    end
end
local ranged = C.Try(CP.IsRangedSlotShown);
if type(ranged) == "boolean" then
    C.hasRangedSlot = ranged;
else
    C.hasRangedSlot = C.isEra or C.isTBC;
end

-- Legacy page indices use the original module order.
function C.RestorePage(cfg, modules)
    local oldOrder = { "ItemSlots", "Config", "Cache", "Stats", "Runes", "PvP", "DelayedScan", "Talents", "More" };
    local token = cfg.activePageToken;
    if not token and type(cfg.activePage) == "number" then token = oldOrder[cfg.activePage]; end
    cfg.activePage = nil;
    for index, mod in ipairs(modules) do
        if mod.token == token and mod.page then cfg.activePage = index; break end
    end
    cfg.activePageToken = cfg.activePage and modules[cfg.activePage].token or nil;
    cfg.prevPage = nil;
    cfg.foundationVersion = 1;
end

function C.ProbeTalents(unit)
    local result = { trees = 0, nodes = 0, positions = 0, ranks = 0, entries = 0, edges = 0 };
    if not unit or not UnitExists(unit) then result.status = "no unit"; return result; end
    if not C_Traits then result.status = "Traits API unavailable"; return result; end
    local configID;
    if UnitIsUnit(unit, "player") then
        configID = C_ClassTalents and C.Try(C_ClassTalents.GetActiveConfigID);
        if C.IsNumber(configID) then result.loadout = C.Try(C_Traits.GenerateImportString, configID); end
    else
        if C.Try(C_Traits.HasValidInspectData) ~= true then result.status = "inspect data not ready"; return result; end
        configID = Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID;
        result.loadout = C.Try(C_Traits.GenerateInspectImportString, unit);
    end
    if not C.IsNumber(configID) then result.status = "config unavailable"; return result; end
    local config = C.Try(C_Traits.GetConfigInfo, configID);
    if type(config) ~= "table" or C.IsSecret(config) or type(config.treeIDs) ~= "table" then
        result.status = "tree data unavailable"; return result;
    end
    for _, treeID in ipairs(config.treeIDs) do
        local nodes = C.Try(C_Traits.GetTreeNodes, treeID);
        if type(nodes) == "table" and not C.IsSecret(nodes) then
            result.trees = result.trees + 1;
            for _, nodeID in ipairs(nodes) do
                if result.nodes >= 1024 then result.status = "probe limit reached"; return result; end
                local node = C.Try(C_Traits.GetNodeInfo, configID, nodeID);
                if type(node) == "table" and not C.IsSecret(node) then
                    result.nodes = result.nodes + 1;
                    if C.IsNumber(node.posX) and C.IsNumber(node.posY) then result.positions = result.positions + 1; end
                    if C.IsNumber(node.currentRank) then result.ranks = result.ranks + 1; end
                    if type(node.visibleEdges) == "table" and not C.IsSecret(node.visibleEdges) then result.edges = result.edges + #node.visibleEdges; end
                    local entryID;
                    if not C.IsSecret(node.activeEntry) and type(node.activeEntry) == "table" then entryID = node.activeEntry.entryID; end
                    if C.IsNumber(entryID) then
                        local entry = C.Try(C_Traits.GetEntryInfo, configID, entryID);
                        local definition = type(entry) == "table" and not C.IsSecret(entry) and C.Try(C_Traits.GetDefinitionInfo, entry.definitionID);
                        if type(definition) == "table" and not C.IsSecret(definition) then result.entries = result.entries + 1; end
                    end
                end
            end
        end
    end
    result.status = result.nodes > 0 and "nodes readable" or "nodes unavailable";
    result.graphicalCandidate = result.nodes > 0 and result.positions == result.nodes and result.ranks == result.nodes and result.entries > 0;
    return result;
end
