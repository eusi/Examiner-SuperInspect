local _, ExaminerNS = ...; if ExaminerNS.blocked then return; end
local REVISION = 8;
local Compat = ExaminerNS.Compat;
local GetItemInfo = Compat.GetItemInfo;
local GetInventorySlotInfo = Compat.GetInventorySlotInfo;
local HIT = HIT or STAT_HIT_CHANCE or ExaminerNS.L["Hit"];
local STRING_SCHOOL_ARCANE = STRING_SCHOOL_ARCANE or RESISTANCE6_NAME or ExaminerNS.L["Arcane"];
local STRING_SCHOOL_FIRE = STRING_SCHOOL_FIRE or RESISTANCE2_NAME or ExaminerNS.L["Fire"];
local STRING_SCHOOL_NATURE = STRING_SCHOOL_NATURE or RESISTANCE3_NAME or ExaminerNS.L["Nature"];
local STRING_SCHOOL_FROST = STRING_SCHOOL_FROST or RESISTANCE4_NAME or ExaminerNS.L["Frost"];
local STRING_SCHOOL_SHADOW = STRING_SCHOOL_SHADOW or RESISTANCE5_NAME or ExaminerNS.L["Shadow"];
local STRING_SCHOOL_HOLY = STRING_SCHOOL_HOLY or RESISTANCE1_NAME or ExaminerNS.L["Holy"];
local ITEM_MOD_SPELL_POWER_SHORT = ITEM_MOD_SPELL_POWER_SHORT or ExaminerNS.L["Spell Power"];
local STAT_CATEGORY_SPELL = STAT_CATEGORY_SPELL or ExaminerNS.L["Spell"];
local CRIT_ABBR = CRIT_ABBR or STAT_CRITICAL_STRIKE or ExaminerNS.L["Crit"];
local STAT_HASTE = STAT_HASTE or STAT_HASTE_RATING or ExaminerNS.L["Haste"];
if (type(LibGearExam) == "table") and (LibGearExam.revision and LibGearExam.revision >= REVISION) then
	return;
end

local _G = getfenv(0);

-- LibGearExam Table
LibGearExam = LibGearExam or {};
local LGE = LibGearExam;
LGE.revision = REVISION;


LGE.ITEMLINK_PATTERN			= "(item:[^|]+)";					-- Matches the raw itemLink from the full itemString
-- Pattern generation for itemLinks. Always match from the start of the itemLink, to ensure that any new properties added to itemLinks, wont break our patterns.
LGE.ITEMLINK_PATTERN_ID			= "item:"..("[^:]*:"):rep(0).."(%d*)";
LGE.ITEMLINK_PATTERN_ENCHANT    = "item:%d+:(%d+)";
LGE.ITEMLINK_PATTERN_LEVEL		= "(item:"..("[^:]*:"):rep(8)..")(%d*)(.+)";		-- used in gsub, so the pattern must match the entire link, even future added properties

-- Other Patterns
LGE.ItemUseToken = "^"..ITEM_SPELL_TRIGGER_ONUSE.." ";
LGE.SetNamePattern = "^(.+) %((%d)/(%d)%)$";
LGE.SetBonusTokenActive = "^"..ITEM_SET_BONUS:gsub("%%s","");
LGE.SetBonusTokenInactive = "%((%d+)%) "..ITEM_SET_BONUS:gsub("%%s","");

-- Schools
LGE.MagicSchools = { "FIRE", "NATURE", "ARCANE", "FROST", "SHADOW", "HOLY" };

-- Gear Slots
LGE.Slots = {
	"HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot",
	"HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
	"MainHandSlot", "SecondaryHandSlot", "RangedSlot",
};
LGE.SlotIDs = {};
for _, slotName in ipairs(LGE.Slots) do
	LGE.SlotIDs[slotName] = GetInventorySlotInfo(slotName);
end
for index = #LGE.Slots, 1, -1 do
    local name = LGE.Slots[index];
    if not LGE.SlotIDs[name] or (name == "RangedSlot" and not Compat.hasRangedSlot) then
        LGE.SlotIDs[name] = nil;
        table.remove(LGE.Slots, index);
    end
end

-- Stat Names
LGE.StatNames = {
	STR = ITEM_MOD_STRENGTH_SHORT,
	AGI = ITEM_MOD_AGILITY_SHORT,
	STA = ITEM_MOD_STAMINA_SHORT,
	INT = ITEM_MOD_INTELLECT_SHORT,
	SPI = ITEM_MOD_SPIRIT_SHORT,

	ARMOR = ARMOR,

	ARCANERESIST = RESISTANCE6_NAME,
	FIRERESIST = RESISTANCE2_NAME,
	NATURERESIST = RESISTANCE3_NAME,
	FROSTRESIST = RESISTANCE4_NAME,
	SHADOWRESIST = RESISTANCE5_NAME,

	MASTERY = STAT_MASTERY,

	DODGE = DODGE_CHANCE,
	PARRY = PARRY_CHANCE,
	DEFENSE = DEFENSE,
	BLOCK = BLOCK_CHANCE,
	BLOCKVALUE = ITEM_MOD_BLOCK_VALUE_SHORT,
	RESILIENCE = STAT_RESILIENCE,
	PVPPOWER = STAT_PVP_POWER,

	AP = STAT_ATTACK_POWER,
	RAP = ITEM_MOD_RANGED_ATTACK_POWER_SHORT,
	CRIT = CRIT_CHANCE,
	HIT = STAT_HIT_CHANCE,

	HASTE = STAT_HASTE,

	WPNDMG = DAMAGE_TOOLTIP,
	RANGEDDMG = RANGED_DAMAGE_TOOLTIP,
	ARMORPENETRATION = ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT,
	EXPERTISE = STAT_EXPERTISE,

	SPELLCRIT = STAT_CATEGORY_SPELL.." "..CRIT_ABBR,
	SPELLHIT = STAT_CATEGORY_SPELL.." "..HIT,
	SPELLHASTE = STAT_CATEGORY_SPELL.." "..STAT_HASTE,
	SPELLPENETRATION = ITEM_MOD_SPELL_PENETRATION_SHORT,

	SPELLDMG = ITEM_MOD_SPELL_POWER_SHORT, --ITEM_MOD_SPELL_DAMAGE_DONE_SHORT,
	HEAL = STAT_SPELLHEALING, --ITEM_MOD_SPELL_HEALING_DONE_SHORT,

	ARCANEDMG = ITEM_MOD_SPELL_POWER_SHORT.." ("..STRING_SCHOOL_ARCANE..")",
	FIREDMG = ITEM_MOD_SPELL_POWER_SHORT.." ("..STRING_SCHOOL_FIRE..")",
	NATUREDMG = ITEM_MOD_SPELL_POWER_SHORT.." ("..STRING_SCHOOL_NATURE..")",
	FROSTDMG = ITEM_MOD_SPELL_POWER_SHORT.." ("..STRING_SCHOOL_FROST..")",
	SHADOWDMG = ITEM_MOD_SPELL_POWER_SHORT.." ("..STRING_SCHOOL_SHADOW..")",
	HOLYDMG = ITEM_MOD_SPELL_POWER_SHORT.." ("..STRING_SCHOOL_HOLY..")",

	HP = HEALTH,
	MP = MANA,

	HP5 = ITEM_MOD_HEALTH_REGEN_SHORT,
	MP5 = ITEM_MOD_POWER_REGEN0_SHORT,

	-- Further
	SANCTIFIED = ExaminerNS.L["Sanctified"],

	DAGGERSKILL = ExaminerNS.L["Increased Daggers Skill"],
	
	ONEAXESKILL = ExaminerNS.L["Increased Axes Skill"],
	TWOAXESKILL = ExaminerNS.L["Increased Two-Handed Axes Skill"],

	ONESWORDSKILL = ExaminerNS.L["Increased Swords Skill"],
	TWOSWORDSKILL = ExaminerNS.L["Increased Two-Handed Swords Skill"],
	
	ONEMACESKILL = ExaminerNS.L["Increased Maces Skill"],
	TWOMACESKILL = ExaminerNS.L["Increased Two-Handed Maces Skill"],
	
	BOWSKILL = ExaminerNS.L["Increased Bows skill"],
	GUNSSKILL = ExaminerNS.L["Increased Guns skill"],
	CROSSBOWSKILL = ExaminerNS.L["Increased Crossbows Skill"],
};

-- Create a sorted List of Stats
local stats = LGE.StatNames;
local statsSorted = {};
LGE.StatNamesSorted = statsSorted;
for stat, name in next, stats do
	statsSorted[#statsSorted + 1] = stat;
end
sort(statsSorted,function(a,b) return stats[a] < stats[b]; end);

-- Absolute Stats, ie. they don't scale in percentages
LGE.ABSOLUTE_STATS = {
	MASTERY = true,
	EXPERTISE = true,
};

-- Scanner Tooltip
LGE.Tip = LGE.Tip or CreateFrame("GameTooltip","LibGearExamTip",nil,"GameTooltipTemplate");
LGE.Tip:SetOwner(UIParent,"ANCHOR_NONE");




--------------------------------------------------------------------------------------------------------
--                                  Sanctified Helper Functions                                       --
--------------------------------------------------------------------------------------------------------
local function trim(s)
    return s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub(",",""); -- remove all color coding, to simplify pattern matching
end
local function trim2(s)
	return trim(s):lower():gsub("|r", "") -- reset code
end
local function getSanctifiedSetBonusText()
    if not Compat.isSoD then return nil; end
    local itemID = 236725 --Wristwraps of undead cleansing, one example, just want to get the text
    local itemLink = select(2, GetItemInfo(itemID))
    if not itemLink or not Compat.isSoD then return nil end

    local tooltip = CreateFrame("GameTooltip", "MyScanningTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)

    for i = 1, tooltip:NumLines() do
        local text = _G["MyScanningTooltipTextLeft" .. i]:GetText()
        if text and text:find("Set:") then
            text = text:gsub("^%(%d+%)%s*", ""):gsub("%s0$", "")
            return text
        end
    end

    return nil
end
local SanctifiedSetBonus = Compat.isSoD and getSanctifiedSetBonusText() or nil;
local SanctifiedTags = {
	["enUS"] = { ExaminerNS.L["Sanctified"], "Scarlet Uniform" },
	["deDE"] = { "Geweiht", "Scharlachrote Uniform" },
	["frFR"] = { "Sanctifié", "Uniforme écarlate" },
	["esES"] = { "Santificar", "Uniforme Escarlata" },
	["ruRU"] = { "Освящённый", "Форма Алого ордена" },
	["koKR"] = { "신성화됨", "붉은십자군 제복" },
	["zhCN"] = { "神圣", "血色军装" },
	["zhTW"] = { "神聖", "血色軍裝" },
}
local function isSanctifiedOrScarletTag(text)
	local tags = SanctifiedTags[GetLocale()]
	if not tags then return false end
	for _, tag in ipairs(tags) do
		if text:find(tag) then return true end
	end
end
local function getSanctifiedName()
	local tags = SanctifiedTags[GetLocale()]
	return tags and tags[1] or nil
end
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
--                   Scans a single item - Stats are added to the [statTable] param                   --
--------------------------------------------------------------------------------------------------------
function LGE:ScanItemLink(link,stats)
    if not link then return; end
    local result={stats={},sets={},runes={},setStats={},seenSets={},seenRunes={}};
    result.class=ExaminerNS.ex and ExaminerNS.ex.info.class;
    ExaminerNS.Gear.Item(link,nil,nil,result);
    for key,value in pairs(result.stats) do stats[key]=(stats[key] or 0)+value; end
end
--------------------------------------------------------------------------------------------------------
--                    Scans set bonuses - Stats are added to the [statTable] param                    --
--------------------------------------------------------------------------------------------------------
function LGE:ScanArmorSetBonuses(setName,setCount,statTable,itemTable)
	if not (setName and setCount and statTable and itemTable) then
		return;
	end

	for slotName, itemLink in next, itemTable do
		-- Set Link
		self.Tip:ClearLines();
		self.Tip:SetHyperlink(itemLink);
		-- Check Lines
		for i = 2, self.Tip:NumLines() do
			local text = _G["LibGearExamTipTextLeft"..i]:GetText();
			local setFound = text:match(self.SetNamePattern);
			if (setName == setFound) then

				for n = i + 1, self.Tip:NumLines() do
					local text = _G["LibGearExamTipTextLeft"..n]:GetText();
					-- Apply the inspected equipment's piece count, not the tooltip's activation state.
					local setBonusIndex = tonumber(text:match(self.SetBonusTokenInactive));
					if (setBonusIndex) then
						if (setBonusIndex > setCount) then

							return;
						end

						self:ScanLineForPatterns(text,statTable);
					end
				end
				return;
			end
		end
	end
end
--------------------------------------------------------------------------------------------------------
--                         Checks if a Line Needs to be Scanned for Patterns                          --
--------------------------------------------------------------------------------------------------------
function LGE:DoLineNeedScan(tipLine,scanSetBonuses)
	-- Init Line
	local text = tipLine:GetText();
	local color = text:match("^(|c%x%x%x%x%x%x%x%x)");		-- look for color code at the start of line
	text = trim(text);	-- remove all color coding, to simplify pattern matching
	local r, g, b = tipLine:GetTextColor();
	r, g, b = ceil(r * 255), ceil(g * 255), ceil(b * 255);	-- some lines don't use color codes, but store color in the text widget itself
	-- Always *Skip* Gray Lines
	if (r == 128 and g == 128 and b == 128) or (color == "|cff808080") then
		return false, text;
	-- Active Set Bonuses (Must be checked before green color check)
	elseif (not scanSetBonuses and text:find(self.SetBonusTokenActive)) then
		return false, text;
	-- Skip "Use:" lines, they are not a permanent stat, so don't include them
	elseif (text:find(self.ItemUseToken)) then
		return false, text;
	-- Always *Scan* Green Lines
	elseif (r == 0 and g == 255 and b == 0) or (color == "|cff00ff00") then
		return true, text;
	-- Should Match: Normal +Stat, Base Item Armor, Block Value on Shields
	elseif (text:find("^[+-]?%d+ [^%d]")) then
		return true, text;
	-- Lazy hack for French clients to detect armor value (e.g Armure : 50)
	elseif (text:find("^(%a+) (%p)")) then
		return true, text;
	-- Set Names (Needed to Check Sets)
	elseif (scanSetBonuses and text:find(self.SetNamePattern)) then
		return true, text;
	-- Sanctified / Scarlet Uniform
	elseif (scanSetBonuses and isSanctifiedOrScarletTag(text) ) then
		return true, text;
	end
	return;
end
--------------------------------------------------------------------------------------------------------
--                                 Checks a Single Line for Patterns                                  --
--------------------------------------------------------------------------------------------------------
function LGE:ScanLineForPatterns(text,statTable)
	if( SanctifiedSetBonus == nil or SanctifiedSetBonus == "" ) then
		SanctifiedSetBonus = getSanctifiedSetBonusText() or ""
	end

	for index, pattern in ipairs(self.Patterns) do
		local pos, _, value1, value2 = text:find(pattern.p);

		-- Sanctiefied / Scarlet Uniform
		if (isSanctifiedOrScarletTag(pattern.p) and trim2(text) == trim2(pattern.p)) then
			value1 = 1;
		end
		-- Sanctified Set
		if (pos == nil and pattern.p == SanctifiedSetBonus and trim(text) == trim(pattern.p)) then
			value1 = 1
			pos = 1
		end

		if (pos) and (value1 or pattern.v) then

			-- Add to stat
			if (type(pattern.s) == "string") then
				statTable[pattern.s] = (statTable[pattern.s] or 0) + (value1 or pattern.v);
			elseif (type(pattern.s) == "table") then
				for statIndex, statName in ipairs(pattern.s) do
					if (type(pattern.v) == "table") then
						statTable[statName] = (statTable[statName] or 0) + (pattern.v[statIndex]);
					-- Legacy patterns support two numeric captures; fixed values may cover more stats.
					elseif (statIndex == 2) and (value2) then
						statTable[statName] = (statTable[statName] or 0) + (value2);
					else
						statTable[statName] = (statTable[statName] or 0) + (value1 or pattern.v);
					end
				end
			end
		end
	end
end
--------------------------------------------------------------------------------------------------------
--                                      Convert Rating to Percent                                     --
--------------------------------------------------------------------------------------------------------

function LGE:GetRatingInPercent(stat,rating,level)
    -- Rating conversion is unavailable; the old Cata formula does not apply.
    return nil;
end

--------------------------------------------------------------------------------------------------------
--                                           Get Stat Value                                           --
--------------------------------------------------------------------------------------------------------

-- Returns a modified and formatted stat from the given "statTable", which might be adjusted by certain options
-- If "compareTable" is given a table, it assumes compare mode and displays and colorizes the differences.
-- As a control flag, "compareTable" set to a boolean, will return the value unformatted for use in compare mode.
function LGE:GetStatValue(token,stats,compare,level,combine,percentRatings)
    local value=ExaminerNS.Gear.Normalized(stats,token,combine);
    if type(compare)=="table" then value=value-ExaminerNS.Gear.Normalized(compare,token,combine); end
    if compare==true then return value; end
    local text=Compat.FormatNumber(value);
    local percentages={CRIT=true,HIT=true,SPELLCRIT=true,SPELLHIT=true,DODGE=true,PARRY=true,BLOCK=true};
    if (Compat.isEra or Compat.isTBC) and percentages[token] then text=text.."%"; end
    if type(compare)=="table" and math.abs(value)>=0.005 then text=(value>0 and "|cff80ff80+" or "|cffff8080")..text.."|r"; end
    return text,token=="DPS" and "Sum of DPS reported by equipped item data (normally weapons). Not your character's damage output." or nil;
end

--------------------------------------------------------------------------------------------------------
--                                          Helper Functions                                          --
--------------------------------------------------------------------------------------------------------


function LGE:FixItemStringLevel(link,level)
	return (link and level) and link:gsub(self.ITEMLINK_PATTERN_LEVEL,"%1"..level.."%3") or link;
end

-- Format Stat Name
function LGE:FormatStatName(statToken,inPercent)
	if (not self.StatNames[statToken]) then
		return statToken.." (Invalid Stat)";
	else
		return self.StatNames[statToken];
	end
end
