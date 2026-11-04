--------------------------------------------------------------------------------------------------------
--
-- Modules/modlist.lua
-- Builds the More menu and the separate module enable/disable page.
--
----------------------

--------------------------------------------------------------------------------------------------------
--                                            Module Setup                                            --
--------------------------------------------------------------------------------------------------------

local _, ns = ...
if ns.blocked then
    return
end
local ex, L = ns.ex, ns.L
local mod = ex:CreateModule("More", L["More"])
mod.help = L["Shows additional modules, such as settings.\nShift-click: reopen the last menu page."]
mod:CreatePage(false, L["More"])
mod:HasButton(true)
local controls = ex:CreateModule("Modules", L["Modules"])
controls.help = L["Lets you enable or disable modules and their tabs."]
controls:CreatePage(false, L["Modules"])
local catalog = {
    {
        "Stats",
        "Gear Statistics",
        "INV_Chest_Plate01",
        L["Shows gear statistics, item levels, bonuses and more.\nShift-click: mark this player for comparison.\nShift-right-click: clear comparison."]:match(
            "^[^\n]+"
        ),
    },
    { "Talents", "Talents", "Spell_Holy_MagicalSentry", L["Shows talent trees."] },
    {
        "PvP",
        "PvP",
        "INV_BannerPVP_02",
        ns.Compat.isEra and L["Shows PvP details, such as honor ranks and honorable kills."]
            or L["Shows PvP details, such as honorable kills and ratings."],
    },
    {
        "Guild",
        "Guild",
        "INV_Shirt_GuildTabard_01",
        L["Shows guild details, such as rank, member count, and banner."],
    },
    { "Runes", "SoD Runes", "INV_Misc_Rune_01", L["Shows equipped runes for each gear slot."] },
    {
        "Achievements",
        "Achievements",
        "Achievement_General",
        L["Shows achievements, completion status, points, and rewards."],
    },
}
controls.catalog = catalog
local navigation = {
    { "Config", "Settings", "INV_Misc_Gear_01" },
    { "Cache", "Cached Players", "INV_Misc_Book_09" },
    { "Modules", "Modules", "INV_Misc_EngGizmos_19" },
}
local rows, entries = {}, {}
mod.listButtons = {}
controls.listButtons = rows
local count, height = 8, (controls.page:GetHeight() - 47) / 8

--------------------------------------------------------------------------------------------------------
--                                            List Display                                            --
--------------------------------------------------------------------------------------------------------

-- Apply a menu entry and its checkbox availability to a row.
local function PaintRow(row, entry)
    local module = entry.module
    row.entry = entry
    row.id = module and module.index
    row.name:SetText(module and module.title or L[entry[2]])
    row.name:SetTextColor(module and 1 or 0.5, module and 1 or 0.5, module and 1 or 0.5)
    row.icon:SetTexture(ns.Compat.Icon(module and module.icon) or "Interface\\Icons\\" .. entry[3])
    row.icon:SetDesaturated(not module)
    if row.check then
        row.check:SetChecked(module ~= nil and module:IsEnabled())
        row.check:SetEnabled(module ~= nil)
    end
    row:Show()
end

-- Update visible module rows and clamp the scroll offset.
local function Paint()
    controls.scroll.offset = math.max(0, math.min(controls.scroll.offset or 0, math.max(0, #entries - count)))
    FauxScrollFrame_Update(controls.scroll, #entries, count, height)
    for index, row in ipairs(mod.listButtons) do
        local definition = navigation[index]
        PaintRow(
            row,
            { definition[1], definition[2], definition[3], module = ex:GetModuleFromToken(definition[1]) }
        )
    end
    for index, row in ipairs(rows) do
        local entry = entries[(controls.scroll.offset or 0) + index]
        if entry then
            PaintRow(row, entry)
        else
            row.entry = nil
            row.id = nil
            row:Hide()
        end
    end
end

--------------------------------------------------------------------------------------------------------
--                                            Menu Content                                            --
--------------------------------------------------------------------------------------------------------

-- Populate More navigation and the separate feature settings page.
function mod:BuildModuleList()
    wipe(entries)
    for _, definition in ipairs(catalog) do
        entries[#entries + 1] = {
            definition[1],
            definition[2],
            definition[3],
            definition[4],
            module = ex:GetModuleFromToken(definition[1]),
        }
    end
    for _, module in ipairs(ex.modules) do
        local found = module.token == "More"
            or module.token == "Config"
            or module.token == "Cache"
            or module.token == "Modules"
            or module.parentToken
            or not module.page
        for _, definition in ipairs(catalog) do
            if definition[1] == module.token then
                found = true
            end
        end
        if not found then
            entries[#entries + 1] = { module.token, module.title, "INV_Misc_QuestionMark", module = module }
        end
    end
    Paint()
end
mod.OnInitialize = mod.BuildModuleList
mod.OnInspect = mod.BuildModuleList
mod.OnInspectReady = mod.BuildModuleList
mod.OnDataChanged = mod.BuildModuleList
mod.OnCacheLoaded = mod.BuildModuleList
mod.OnClearInspect = mod.BuildModuleList
-- Update module navigation controls when the active page changes.
function mod:OnPageChanged()
    self:BuildModuleList()
end

-- Handle module navigation navigation and its modifier shortcuts.
function mod:OnButtonClick(frame, button)
    if button == "LeftButton" and IsShiftKeyDown() then
        ex:ShowModulePage(ex.cfg.lastActivatedModule or ex.cfg.prevPage)
    elseif button == "RightButton" and not IsModifierKeyDown() then
        local module = ex.modules[ex.cfg.activePage]
        if module and module:IsEnabled() and module.MenuInit and module.MenuSelect then
            frame.initFunc = module.MenuInit
            frame.selectValueFunc = module.MenuSelect
            AzDropDown:ToggleMenu(frame, "TOPLEFT", "BOTTOMLEFT")
        end
    end
end

--------------------------------------------------------------------------------------------------------
--                                              Tooltips                                              --
--------------------------------------------------------------------------------------------------------

-- Show module navigation details for the hovered entry.
local function Tooltip(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local module = row.entry and row.entry.module
    GameTooltip:ClearLines()
    local text = module and (module.help or module.title) or (row.entry and (row.entry[4] or L[row.entry[2]]))
    if row.check and module then
        text = module.toggleHelp or ns.F("Enable/disable: %s", text:match("^[^\n]+"))
    end
    if text then
        GameTooltip:AddLine(text, 1, 1, 1, true)
    end
    if not module then
        GameTooltip:AddLine(L["Not available in this WoW version."], 1, 0.82, 0, true)
    end
    GameTooltip:Show()
end

--------------------------------------------------------------------------------------------------------
--                                          Widget Creation                                           --
--------------------------------------------------------------------------------------------------------

-- Create an icon row with an optional module checkbox.
local function CreateRow(top, toggle)
    local row = CreateFrame("Button", nil, toggle and controls.page or mod.page)
    row:SetHeight(height)
    row:SetPoint("TOPLEFT", 8, -top)
    row:SetPoint("TOPRIGHT", toggle and -28 or -8, -top)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(23, 23)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if toggle then
        row.check = CreateFrame("CheckButton", nil, row)
        row.check:SetSize(26, 26)
        row.check:SetPoint("RIGHT", 0, 0)
        row.check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        row.check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        row.check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        row.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        row.check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
        -- Apply the selected control action.
        row.check:SetScript("OnClick", function()
            local entry = row.entry
            if entry and entry.module then
                ex:SetModuleEnabled(entry[1], not entry.module:IsEnabled())
            end
        end)
        -- Show the control description or unavailable-data explanation.
        row.check:SetScript("OnEnter", function()
            Tooltip(row)
        end)
        row.check:SetScript("OnLeave", ex.HideGTT)
    end
    row.name = ns.Fonts.Create(row, nil, "ARTWORK", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    if row.check then
        row.name:SetPoint("RIGHT", row.check, "LEFT", -3, 0)
    else
        row.name:SetPoint("RIGHT", -3, 0)
    end
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    -- Apply the selected control action.
    row:SetScript("OnClick", function()
        local module = row.entry and row.entry.module
        if toggle then
            if module then
                ex:SetModuleEnabled(module.token, not module:IsEnabled())
            end
        elseif module and module:IsEnabled() and module.hasData then
            ex.cfg.lastActivatedModule = module.index
            ex:ShowModulePage(module.index)
        end
    end)
    row:SetScript("OnEnter", Tooltip)
    row:SetScript("OnLeave", ex.HideGTT)
    return row
end
for index = 1, #navigation do
    mod.listButtons[index] = CreateRow(38 + (index - 1) * 32, false)
end
for index = 1, count do
    rows[index] = CreateRow(38 + (index - 1) * height, true)
end
controls.scroll =
    CreateFrame("ScrollFrame", "ExaminerModulesScroll", controls.page, "FauxScrollFrameTemplate")
controls.scroll:SetPoint("TOPLEFT", rows[1])
controls.scroll:SetPoint("BOTTOMRIGHT", rows[count], -6, -1)
-- Update visible rows for the new scroll position.
controls.scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, height, Paint)
end)

-- Refresh this view when its controls become visible.
mod.page:SetScript("OnShow", function()
    mod:BuildModuleList()
end)

-- Refresh this view when its controls become visible.
controls.page:SetScript("OnShow", function()
    mod:BuildModuleList()
end)
