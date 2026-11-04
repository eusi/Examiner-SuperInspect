--------------------------------------------------------------------------------------------------------
--
-- Modules/cache.lua
-- Filters, sorts and opens saved players in the Cached Players menu.
--
----------------------


--------------------------------------------------------------------------------------------------------
--                                            Module Setup                                            --
--------------------------------------------------------------------------------------------------------

local _, ExaminerNS = ...
if ExaminerNS.blocked then
    return
end
local ex = Examiner
local C = ExaminerNS.Compat
local GetQuestDifficultyColor = C.GetQuestDifficultyColor
local cfg, cache

-- MODULE

local mod = ex:CreateModule("Cache", ExaminerNS.L["Cached Players"])
mod.help = ExaminerNS.L["Shows saved players with their gear and cached details."]
mod:CreatePage(false, ExaminerNS.L["Cached Players"])

-- VARIABLES

local cacheSortMethods = { "none", "name", "realm", "level", "guild", "race", "class", "time" }
local NUM_BUTTONS = 10
local BUTTON_HEIGHT = (240 / NUM_BUTTONS)
local activeCacheList = {}
local buttons = {}

-- EXPOSE THESE TABLES

mod.cacheSortMethods = cacheSortMethods
mod.activeCacheList = activeCacheList

-- FILTERING

local levelPattern = "%s(%d*)(%-)(%d*)%s"
local numberPattern = "%s%d+%s"
local listPattern = "([^%s]+):([^%s]+)"
local filterList = {}

-- CUSTOM COLORS

local CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS

-- RaceCoords. For females, add 0.5 to "top" and "bottom".
-- http://i.imgur.com/VR5Xy.png -- Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races
local RACE_COORD = {
    Human = { left = 0 / 8, right = 1 / 8, top = 0 / 4, bottom = 1 / 4 },
    Dwarf = { left = 1 / 8, right = 2 / 8, top = 0 / 4, bottom = 1 / 4 },
    Gnome = { left = 2 / 8, right = 3 / 8, top = 0 / 4, bottom = 1 / 4 },
    NightElf = { left = 3 / 8, right = 4 / 8, top = 0 / 4, bottom = 1 / 4 },
    Draenei = { left = 4 / 8, right = 5 / 8, top = 0 / 4, bottom = 1 / 4 },
    Worgen = { left = 5 / 8, right = 6 / 8, top = 0 / 4, bottom = 1 / 4 },

    Tauren = { left = 0 / 8, right = 1 / 8, top = 1 / 4, bottom = 2 / 4 },
    Scourge = { left = 1 / 8, right = 2 / 8, top = 1 / 4, bottom = 2 / 4 },
    Troll = { left = 2 / 8, right = 3 / 8, top = 1 / 4, bottom = 2 / 4 },
    Orc = { left = 3 / 8, right = 4 / 8, top = 1 / 4, bottom = 2 / 4 },
    BloodElf = { left = 4 / 8, right = 5 / 8, top = 1 / 4, bottom = 2 / 4 },
    Goblin = { left = 5 / 8, right = 6 / 8, top = 1 / 4, bottom = 2 / 4 },

    Pandaren = { left = 6 / 8, right = 7 / 8, top = 0 / 4, bottom = 1 / 4 }, -- This uses the alliance images; the horde ones are just mirrored.
}

-- Save the entered filter and rebuild the cached-player list.
local CacheFilterOkayFunc = function(text)
    cfg.cacheFilter = text
    mod:BuildCacheList()
    ex:SendModuleEvent("OnConfigChanged", "cacheFilter", text)
end

-- Refresh this view when its controls become visible.
mod.page:SetScript("OnShow", function(self)
    if #activeCacheList == 0 then
        mod:BuildCacheList()
    end
end)

-- HOOK: Slash Command "clearcache"
local oldClearCacheFunc = ex.slashCommands.clearcache
-- Delete cached players and refresh the browser.
ex.slashCommands.clearcache = function(cmd)
    oldClearCacheFunc(cmd)
    if mod:IsEnabled() then
        mod:BuildCacheList()
    else
        wipe(activeCacheList)
    end
end

-- Stop pending cached-player work when inspection closes.
function mod:OnInspectHidden()
    wipe(activeCacheList)
end


--------------------------------------------------------------------------------------------------------
--                                           Module Scripts                                           --
--------------------------------------------------------------------------------------------------------

-- Initialize cached-player controls and saved preferences.
function mod:OnInitialize()
    cfg = ex.cfg
    cache = ex.cache
    -- DEFAULTS

    cfg.cacheSort = cfg.cacheSort or "class"
    cfg.cacheFilter = type(cfg.cacheFilter) == "string" and cfg.cacheFilter or ""
end

-- Handle cached-player navigation and its modifier shortcuts.
function mod:OnButtonClick(frame, button)

    if button == "LeftButton" then
        if IsShiftKeyDown() then
            AzDialog:Show(ExaminerNS.L["Enter new cache filter..."], cfg.cacheFilter, CacheFilterOkayFunc)
        end

    elseif IsShiftKeyDown() then
        cfg.cacheFilter = ""
        cfg.cacheShowAlts = false
        self:BuildCacheList()
    end
end

-- Save available cached-player details into the player snapshot.
function mod:OnCache(entry)
    if self:IsShown() then
        self:BuildCacheList()
    else
        wipe(activeCacheList)
    end
end


--------------------------------------------------------------------------------------------------------
--                                       Delete Cache Functions                                       --
--------------------------------------------------------------------------------------------------------

-- Count stored entries in a table.
local function GetTableEntries(t)
    local count = 0
    for _ in next, t do
        count = (count + 1)
    end
    return count
end

-- Find an entry in the active cache list.
local function IndexOf(t, value)
    for index, v in ipairs(t) do
        if v == value then
            return index
        end
    end
end

-- Delete every saved player after confirmation.
local function DeleteAllCache()
    wipe(cache)
    mod:BuildCacheList()
end

-- Delete only players included by the current filter.
local function DeleteShownCache()
    for index, entryName in ipairs(activeCacheList) do
        cache[entryName] = nil
    end
    mod:BuildCacheList()
end

-- Delete only players excluded by the current filter.
local function DeleteHiddenCache()
    for entryName in next, cache do
        if not IndexOf(activeCacheList, entryName) then
            cache[entryName] = nil
        end
    end
    mod:BuildCacheList()
end


--------------------------------------------------------------------------------------------------------
--                                                Menu                                                --
--------------------------------------------------------------------------------------------------------

-- Build the cached-player context menu.
function mod.MenuInit(parent, list)
    if mod:IsShown() then
        mod:BuildCacheList()
    end
    -- FILTER

    local tbl = list[#list + 1]
    tbl.text = ExaminerNS.L["Filter"]
    tbl.header = 1
    tbl = list[#list + 1]
    tbl.text = ExaminerNS.L["Set Filter..."]
    tbl.value = 1
    tbl = list[#list + 1]
    tbl.text = ExaminerNS.L["Show Alts"]
    tbl.value = 10
    tbl.checked = cfg.cacheShowAlts
    -- SORT

    tbl = list[#list + 1]
    tbl.header = 1
    tbl = list[#list + 1]
    tbl.text = ExaminerNS.L["Sort Method"]
    tbl.header = 1
    for index, method in ipairs(cacheSortMethods) do
        local tbl = list[#list + 1]
        tbl.text = ExaminerNS.L[method]
        tbl.value = method
        tbl.checked = (cfg.cacheSort == method)
    end
    -- CACHE

    tbl = list[#list + 1]
    tbl.header = 1
    tbl = list[#list + 1]
    tbl.text = ExaminerNS.L["Cache"]
    tbl.header = 1
    tbl = list[#list + 1]
    tbl.text = ExaminerNS.L["Delete All Entries"]
    tbl.value = 2
    if #activeCacheList ~= GetTableEntries(cache) then
        tbl = list[#list + 1]
        tbl.text = ExaminerNS.L["Delete Shown Entries"]
        tbl.value = 3
        tbl = list[#list + 1]
        tbl.text = ExaminerNS.L["Delete Hidden Entries"]
        tbl.value = 4
    end
end

-- Apply the selected cached-player menu action.
function mod.MenuSelect(parent, entry)
    -- SORT

    if type(entry.value) == "string" then
        cfg.cacheSort = entry.value
    -- CACHE FILTER

    elseif entry.value == 1 then
        AzDialog:Show(ExaminerNS.L["Enter new cache filter..."], cfg.cacheFilter, CacheFilterOkayFunc)
    elseif entry.value == 10 then
        cfg.cacheShowAlts = not cfg.cacheShowAlts
    -- DELETE CACHE

    elseif entry.value == 2 then
        AzDialog:Show(ExaminerNS.F("Delete %d cached entries?", GetTableEntries(cache)), nil, DeleteAllCache)
    elseif entry.value == 3 then
        AzDialog:Show(ExaminerNS.F("Delete %d shown entries?", #activeCacheList), nil, DeleteShownCache)
    elseif entry.value == 4 then
        AzDialog:Show(
            ExaminerNS.F("Delete %d hidden entries?", GetTableEntries(cache) - #activeCacheList),
            nil,
            DeleteHiddenCache
        )
    end
    -- REBUILD CACHE LIST

    if entry.value ~= 1 then
        mod:BuildCacheList()
    end
end


--------------------------------------------------------------------------------------------------------
--                                        Cache Code Functions                                        --
--------------------------------------------------------------------------------------------------------

-- Load the selected cached player or handle its shortcuts.
local function CacheEntry_OnClick(self, button)
    if button == "LeftButton" then
        local editBox = ChatEdit_GetActiveWindow()
        if editBox and (IsModifiedClick("CHATLINK")) and (editBox:IsVisible()) then
            local entry = cache[self.entryName]
            editBox:Insert(
                format(
                    "%s, %d %s%s",
                    self.entryName,
                    entry.level,
                    entry.class,
                    (entry.guild and ExaminerNS.L[" of "] .. "<" .. entry.guild .. ">" or "")
                )
            )
        else
            -- GO TO PREVIOUS PAGE

            if not IsShiftKeyDown() then
                cfg.activePage = cfg.prevPage
                mod.page:Hide()
            end
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) -- "igMainMenuOptionCheckBoxOn"
            ex:ClearInspect()
            ex:LoadPlayerFromCache(self.entryName)
        end
    elseif (button == "RightButton") and (IsShiftKeyDown()) then
        cache[self.entryName] = nil
        mod:BuildCacheList()
    end
end

-- Show the saved player summary and available actions.
local function CacheEntry_OnEnter(self, motion)
    local entry = cache[self.entryName]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    -- INIT TEXT & COLORS

    local color = CLASS_COLORS[entry.classFixed] or { r = 1, g = 1, b = 1 }
    local classText = ("|cff%.2x%.2x%.2x%s|r"):format(
        color.r * 255,
        color.g * 255,
        color.b * 255,
        entry.class
    )
    color = GetQuestDifficultyColor(entry.level ~= -1 and entry.level or 500)
    local level = ("|cff%.2x%.2x%.2x%s|r"):format(
        color.r * 255,
        color.g * 255,
        color.b * 255,
        entry.level ~= -1 and entry.level or "??"
    )
    -- ADD LINES & SHOW

    GameTooltip:AddLine(entry.pvpName .. (entry.realm and " - " .. entry.realm or ""), 0.5, 0.75, 1.0)
    if entry.guild then
        GameTooltip:AddLine("<" .. entry.guild .. "> |cffc0c0c0" .. (entry.guildRank or ""), 0.0, 0.5, 0.8)
    end
    GameTooltip:AddLine(level .. "  " .. entry.race .. " " .. classText, 1, 1, 1)
    GameTooltip:AddLine(entry.zone, 1, 1, 1)
    GameTooltip:AddLine(ex:FormatTime(time() - entry.time) .. ExaminerNS.L[" ago"])
    GameTooltip:AddLine(date("%a, %b %d, %Y - %H:%M:%S", entry.time))
    GameTooltip:AddLine(ExaminerNS.L["<Shift + Right-Click to Delete>"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

-- Compare cached players using the selected sort method.
local function CacheListSortFunc(a, b)
    local aValue = cache[a][cfg.cacheSort]
    local bValue = cache[b][cfg.cacheSort]
    if aValue == bValue then
        return cache[a].name < cache[b].name
    elseif not aValue or not bValue then
        return aValue and true
    elseif type(aValue) ~= type(bValue) then
        return tostring(aValue) < tostring(bValue)
    elseif type(aValue) == "number" then
        return aValue > bValue
    else
        return aValue < bValue
    end
end

-- Update the visible cached-player rows for the current scroll offset.
local function UpdateShownItems(self)
    buttons[1]:SetWidth(#activeCacheList > #buttons and 200 or 216)
    FauxScrollFrame_Update(self, #activeCacheList, #buttons, BUTTON_HEIGHT)
    local gttOwner = GameTooltip:GetOwner()
    local index = self.offset
    for i = 1, #buttons do
        index = (index + 1)
        local button = buttons[i]
        if activeCacheList[index] then
            local entryName = activeCacheList[index]
            local entry = cache[entryName]
            local color = CLASS_COLORS[entry.classFixed] or { r = 1, g = 1, b = 1 }

            button.entryName = entryName
            button.name:SetFormattedText(
                "|cffffffff%s|r %s%s",
                (entry.level ~= -1 and entry.level or "??"),
                entry.name,
                entry.realm and "|cffffff00*" or ""
            )
            button.name:SetTextColor(color.r, color.g, color.b)

            local valueText
            if cfg.cacheSort == "name" then
                valueText = ""
            elseif cfg.cacheSort == "time" then
                valueText = ex:FormatTime(time() - entry.time, true)
            else
                valueText = entry[cfg.cacheSort]
            end
            button.value:SetText(valueText)

            local coords = RACE_COORD[entry.raceFixed] or RACE_COORD.Human -- Default to Human to avoid error in case of new race in the future
            local iconOffset = (entry.sex == 3 and 0.5 or 0)
            button.race:SetTexCoord(
                coords.left + 0.01,
                coords.right - 0.006,
                coords.top + iconOffset + 0.014,
                coords.bottom + iconOffset - 0.013
            )

            -- UPDATE TOOLTIP

            if button == gttOwner then
                CacheEntry_OnEnter(button)
            end

            button:Show()
        else
            button:Hide()
        end
    end
end

-- Check name, level and field filters for a cached player.
local function IncludeFilteredEntry(entry, filter, lvlMin, lvlHyphen, lvlMax)
    if not ExaminerNS.Cache.Valid(entry) then
        return false
    end
    local include = true
    -- SHOW ALTS

    include = include and (not cfg.cacheShowAlts or cfg.cacheShowAlts and entry.isSelf)
    -- LIST PATTERN

    for type, string in next, filterList do
        include = include
            and entry[type]
            and (tostring(entry[type]):lower():gsub(" ", ""):find(string, 1, true))
    end
    -- LEVEL MATCH

    if lvlMin and lvlMax then
        include = include and (entry.level >= lvlMin and entry.level <= lvlMax)
    elseif lvlHyphen == "-" then
        include = include and (lvlMin and entry.level >= lvlMin or lvlMax and entry.level <= lvlMax)
    elseif lvlMin then
        include = include and (entry.level == lvlMin)
    end
    -- NAME MATCH & RETURN

    return include and (entry.name:lower():find(filter, 1, true))
end

-- Filter and sort saved players before refreshing visible rows.
function mod:BuildCacheList()
    -- We're padding the filter with spaces to fix some pattern matching
    local filter = (" " .. cfg.cacheFilter .. " ")
    -- FILTER LIST

    for type, string in filter:gmatch(listPattern) do
        filterList[type] = string:lower()
    end
    -- FILTER LEVEL

    local lvlMin, lvlHyphen, lvlMax = filter:match(levelPattern)
    if not lvlMin then
        lvlMin = filter:match(numberPattern)
    end
    lvlMin, lvlMax = tonumber(lvlMin), tonumber(lvlMax)
    -- FILTER FIN

    filter = filter:gsub(levelPattern, ""):gsub(numberPattern, ""):gsub(listPattern, ""):trim():lower()
    local notFiltered = (
        filter == ""
        and not cfg.cacheShowAlts
        and not lvlMin
        and not lvlMax
        and not next(filterList)
    )
    -- CREATE DISPLAY TABLE

    wipe(activeCacheList)
    for entryName, entry in next, cache do
        if notFiltered or (IncludeFilteredEntry(entry, filter, lvlMin, lvlHyphen, lvlMax)) then
            activeCacheList[#activeCacheList + 1] = entryName
        end
    end
    -- SORT

    if cfg.cacheSort ~= "none" then
        sort(activeCacheList, CacheListSortFunc)
    end

    self.page.header:SetFormattedText(
        ExaminerNS.L["Cached Players (%d)%s"],
        #activeCacheList,
        (notFiltered and "" or " |cffffff00*")
    )
    UpdateShownItems(self.scroll)
    wipe(filterList)
end


--------------------------------------------------------------------------------------------------------
--                                        Cache Frame Creation                                        --
--------------------------------------------------------------------------------------------------------

-- CACHE ENTRIES

for i = 1, NUM_BUTTONS do
    local btn = CreateFrame("Button", nil, mod.page)
    btn:SetSize(200, BUTTON_HEIGHT)
    btn:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    btn.id = i

    if i == 1 then
        btn:SetPoint("TOPLEFT", 8, -40)
    else
        btn:SetPoint("TOPLEFT", buttons[i - 1], "BOTTOMLEFT")
        btn:SetPoint("TOPRIGHT", buttons[i - 1], "BOTTOMRIGHT")
    end

    btn:SetScript("OnClick", CacheEntry_OnClick)
    btn:SetScript("OnEnter", CacheEntry_OnEnter)
    btn:SetScript("OnLeave", ex.HideGTT)

    btn.race = btn:CreateTexture(nil, "ARTWORK")
    btn.race:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races")
    btn.race:SetPoint("LEFT", 3, 0)
    btn.race:SetSize(BUTTON_HEIGHT - 2, BUTTON_HEIGHT - 2)

    btn.name = ExaminerNS.Fonts.Create(btn, nil, "ARTWORK", "GameFontHighlight")
    btn.name:SetPoint("LEFT", btn.race, "RIGHT", 3, 0)
    btn.name:SetJustifyH("LEFT")

    btn.value = ExaminerNS.Fonts.Create(btn, nil, "ARTWORK", "GameFontHighlightExtraSmall")
    btn.value:SetPoint("LEFT", btn.name, "RIGHT", 2, 0)
    btn.value:SetPoint("RIGHT", -2)
    btn.value:SetJustifyH("RIGHT")

    buttons[i] = btn
end

-- CACHE SCROLL

mod.scroll =
    CreateFrame("ScrollFrame", "Examiner" .. mod.token .. "Scroll", mod.page, "FauxScrollFrameTemplate")
mod.scroll:SetPoint("TOPLEFT", buttons[1])
mod.scroll:SetPoint("BOTTOMRIGHT", buttons[#buttons], -3, -1)
-- Update visible rows for the new scroll position.
mod.scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, BUTTON_HEIGHT, UpdateShownItems)
end)
