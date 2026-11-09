--------------------------------------------------------------------------------------------------------
--
-- Services/Appearance.lua
-- Styles Examiner-owned surfaces and fits content to the selected navigation layout.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local A, C = {}, ns.Compat
ns.Appearance = A
A.palettes = {
    modern = { background = {0.094, 0.094, 0.094, 1}, panel = {0.14, 0.14, 0.14, 1},
        frameEdge = {0.16, 0.16, 0.16, 1},
        edge = {0.27, 0.27, 0.27, 1}, accent = {0.6, 0.6, 0.6, 1}, label = {0.9, 0.9, 0.9, 1} },
    forever = { background = {0.075, 0.075, 0.075, 1}, panel = {0.13, 0.13, 0.13, 1},
        edge = {0.38, 0.32, 0.23, 1}, accent = {0.88, 0.73, 0.32, 1}, label = {1, 0.82, 0.35, 1} },
}
local buttons, pages = {}, {}
local labelColors = setmetatable({}, {__mode = "k"})

-- Discover labelled Examiner buttons while leaving item, spell and checkbox artwork intact.
local function RegisterLabelledButtons(frame, sharedMenu)
    if frame == sharedMenu then return end
    if frame.IsObjectType and frame:IsObjectType("Button") and frame.GetFontString
        and frame:GetFontString() and frame.GetText and C.Text(frame:GetText()) then
        A.RegisterButton(frame)
    end
    if frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do RegisterLabelledButtons(child, sharedMenu) end
    end
end

-- Compare owned text colors without changing quality, class or comparison colors.
local function SameColor(a, b)
    return math.abs(a[1] - b[1]) < 0.005 and math.abs(a[2] - b[2]) < 0.005
        and math.abs(a[3] - b[3]) < 0.005
end

-- Recolor only the original blue section labels, tracking reversible changes per region.
local function PaintLabel(text, palette)
    local color = {text:GetTextColor()}
    if not C.IsNumber(color[1]) or not C.IsNumber(color[2]) or not C.IsNumber(color[3]) then return end
    local record = labelColors[text]
    if record then
        if SameColor(color, record.applied) then color = record.original else record = nil end
    end
    local label = SameColor(color, {0.5, 0.75, 1}) or SameColor(color, {0.65, 0.8, 1})
    if palette and label then
        labelColors[text] = {original = color, applied = palette.label}
        text:SetTextColor(unpack(palette.label))
    else
        if record then text:SetTextColor(unpack(color)) end
        labelColors[text] = nil
    end
end

-- Update section colors after reused statistic rows receive new content.
function A.RefreshLabels(frame)
    local ex = ns.ex
    if not ex or not ex.cfg then return end
    frame = frame or ex
    local shared = AzDropDown and _G["AzDropDownScroll" .. AzDropDown.vers]
    if shared and frame == shared:GetParent() then return end
    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do
            if region.IsObjectType and region:IsObjectType("FontString") then PaintLabel(region, A.Palette()) end
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do A.RefreshLabels(child) end
    end
end

--------------------------------------------------------------------------------------------------------
--                                         Saved Preferences                                          --
--------------------------------------------------------------------------------------------------------

-- Normalize appearance choices while preserving all unrelated settings.
function A.Normalize(cfg)
    if cfg.style ~= "modern" and cfg.style ~= "forever" then cfg.style = "classic" end
    if cfg.menuStyle ~= "classic" and cfg.menuStyle ~= "iconsRight" and cfg.menuStyle ~= "iconsBottom" then
        cfg.menuStyle = "iconsBottom"
    end
    -- Discard obsolete development preferences; Gear List uses the normal module setting.
    cfg.gearView, cfg.classIconPreview = nil, nil
    cfg.appearanceNotice107Shown = nil
end

-- Return the active optional palette; Classic uses the original artwork.
function A.Palette()
    return ns.ex and ns.ex.cfg and A.palettes[ns.ex.cfg.style]
end

--------------------------------------------------------------------------------------------------------
--                                          Owned Surfaces                                            --
--------------------------------------------------------------------------------------------------------

-- Add flat surfaces behind a control's existing text and icons.
function A.Surface(frame)
    if frame.examinerSurface then return frame.examinerSurface end
    local surface = { fill = frame:CreateTexture(nil, "BACKGROUND"), edges = {} }
    surface.fill:SetAllPoints()
    for index = 1, 4 do
        local edge = frame:CreateTexture(nil, "BORDER")
        if index <= 2 then
            edge:SetHeight(1)
            edge:SetPoint(index == 1 and "TOPLEFT" or "BOTTOMLEFT")
            edge:SetPoint(index == 1 and "TOPRIGHT" or "BOTTOMRIGHT")
        else
            edge:SetWidth(1)
            edge:SetPoint(index == 3 and "TOPLEFT" or "TOPRIGHT")
            edge:SetPoint(index == 3 and "BOTTOMLEFT" or "BOTTOMRIGHT")
        end
        surface.edges[index] = edge
    end
    frame.examinerSurface = surface
    return surface
end

-- Paint or hide a registered flat surface without touching item textures.
local function PaintSurface(surface, palette, active, hover)
    surface.fill:SetShown(palette ~= nil)
    if palette then
        local color = palette.panel
        local lift = hover and 0.04 or 0
        surface.fill:SetColorTexture(color[1] + lift, color[2] + lift, color[3] + lift, color[4])
    end
    for _, edge in ipairs(surface.edges) do
        edge:SetShown(palette ~= nil)
        if palette then edge:SetColorTexture(unpack((active or hover) and palette.accent or palette.edge)) end
    end
end

-- Preserve native button artwork for exact restoration of Classic controls.
function A.RegisterButton(button)
    if buttons[button] then return end
    local record = { native = {}, surface = A.Surface(button) }
    for _, method in ipairs({"GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture"}) do
        local texture = button[method] and button[method](button)
        if texture then record.native[#record.native + 1] = { texture, C.Number(texture:GetAlpha(), 1), method } end
    end
    buttons[button] = record
    -- Highlight only the owned surface while retaining the original tooltip handler.
    button:HookScript("OnEnter", function(self)
        record.hover = true
        A.PaintButton(self, self.moduleActive, self.navigationIconMode)
    end)
    -- Restore the selected or neutral surface when the pointer leaves.
    button:HookScript("OnLeave", function(self)
        record.hover = nil
        A.PaintButton(self, self.moduleActive, self.navigationIconMode)
    end)
end

-- Mark talent selectors so their native artwork can be restored outside Modern.
function A.TalentTab(tab, selected)
    A.RegisterButton(tab)
    local record = buttons[tab]
    if not record.talentArt then
        record.talentArt = {}
        local regions = {tab:GetRegions()}
        for _, texture in ipairs(tab.pieces or {}) do regions[#regions + 1] = texture end
        if tab.highlight then regions[#regions + 1] = tab.highlight end
        local seen = {}
        for _, region in ipairs(regions) do
            local owned = region == record.surface.fill
            for _, edge in ipairs(record.surface.edges) do owned = owned or region == edge end
            if not owned and not seen[region] and (region.SetTexture and region ~= tab:GetFontString()) then
                seen[region] = true
                local alpha = C.Number(region:GetAlpha(), 1)
                for _, native in ipairs(record.native) do
                    if native[1] == region then alpha = native[2] end
                end
                record.talentArt[#record.talentArt + 1] = {region, alpha}
            end
        end
        record.selection = tab:CreateTexture(nil, "OVERLAY")
        record.selection:SetHeight(2)
        record.selection:SetPoint("BOTTOMLEFT", 1, 0)
        record.selection:SetPoint("BOTTOMRIGHT", -1, 0)
        tab.talentSelection = record.selection
    end
    tab.talentSelected = selected
    A.PaintButton(tab)
end

-- Style a button independently of whether its navigation uses icons.
function A.PaintButton(button, active, iconMode)
    A.RegisterButton(button)
    local palette = A.Palette()
    local visual = palette or (iconMode and A.palettes.forever)
    local forever = ns.ex.cfg.style == "forever"
    -- Text navigation keeps native buttons without an extra surface or selection frame.
    local classicMenu = button.navigationIconMode == false
    if forever or classicMenu then visual = nil end
    local record = buttons[button]
    if button == ns.ex.close and ns.ex.cfg.style == "modern" then
        for _, native in ipairs(record.native) do native[1]:SetAlpha(0) end
        PaintSurface(record.surface, nil)
        local shade = record.hover and 1 or 0.82
        for _, stroke in ipairs(button.styleCross.strokes) do stroke:SetColorTexture(shade,shade,shade,1) end
        return
    end
    if record.talentArt then
        local modern = ns.ex.cfg.style == "modern"
        local forever = ns.ex.cfg.style == "forever"
        if button.talentAnchorX then
            button:ClearAllPoints()
            if button.talentLegacy then
                button:SetPoint("TOPLEFT", button.talentAnchorX, forever and 32 or 36)
            elseif C.isMists then
                button:SetPoint("BOTTOMLEFT", button:GetParent(), "TOPLEFT", button.talentAnchorX, 0)
            else
                button:SetPoint("TOPLEFT", button.talentAnchorX, forever and 20 or 24)
            end
        end
        for _, native in ipairs(record.talentArt) do native[1]:SetAlpha(modern and 0 or native[2]) end
        if button.pieces and button.label and button.highlight then
            -- Match classic TabButtonTemplate geometry instead of stretching its art into a flat tab.
            local offset = forever and button.talentSelected and -3 or 0
            for part, texture in ipairs(button.pieces) do
                texture:ClearAllPoints()
                if part == 1 then
                    texture:SetPoint("BOTTOMLEFT", 0, offset)
                elseif part == 3 then
                    texture:SetPoint("BOTTOMRIGHT", 0, offset)
                else
                    texture:SetPoint("BOTTOMLEFT", 16, offset)
                    texture:SetPoint("BOTTOMRIGHT", -16, offset)
                end
            end
            button.label:ClearAllPoints()
            button.highlight:ClearAllPoints()
            if forever then
                button.label:SetPoint("BOTTOM", 0, 5)
                button.label:SetSize(math.max(1, button:GetWidth() - 16), 13)
                button.highlight:SetPoint("BOTTOM", 2, -8)
                button.highlight:SetSize(math.max(1, button:GetWidth() - 30), 32)
            else
                button.label:SetPoint("TOPLEFT", 8, 0)
                button.label:SetPoint("BOTTOMRIGHT", -8, 0)
                button.highlight:SetAllPoints(button)
            end
        end
        PaintSurface(record.surface, modern and palette or nil, false, false)
        record.selection:Hide()
        if modern then
            local shade = button.talentSelected and 0.22 or record.hover and 0.18 or 0.14
            record.surface.fill:SetColorTexture(shade, shade, shade, 1)
            button:GetFontString():SetTextColor(unpack(button.unavailable and {0.4,0.4,0.4,1}
                or button.talentSelected and {1,1,1,1} or {0.65,0.65,0.65,1}))
        else
            button:GetFontString():SetTextColor(unpack(button.unavailable and {0.5,0.5,0.5,1}
                or button.talentSelected and {1,1,1,1} or {1,0.82,0,1}))
        end
        return
    end
    local more = ns.ex:GetModuleFromToken("More")
    for _, native in ipairs(record.native) do
        local hideMoreHover = classicMenu
            and more and button.id == more.index and native[3] == "GetHighlightTexture"
        native[1]:SetAlpha((visual or iconMode or hideMoreHover) and 0 or native[2])
    end
    PaintSurface(record.surface, visual, active, record.hover)
    if forever and active and not iconMode and not classicMenu then
        for _, edge in ipairs(record.surface.edges) do
            edge:SetColorTexture(unpack(palette.accent))
            edge:Show()
        end
    end
    if iconMode then
        PaintSurface(record.surface, nil)
    end
    ns.FrameArt.SideTab(button, active, record.hover)
end

-- Remember the original content backdrop before applying any optional style.
function A.RegisterPage(page)
    pages[page] = {height = page:GetHeight()}
end

-- Reuse the old footer space for content whenever navigation sits outside the frame.
function A.UpdateLayout()
    local ex = ns.ex
    if not ex or not ex.cfg then return end
    local extra = ex.cfg.menuStyle ~= "classic" and 24 or 0
    if ex.navigationContentExtra == extra then return end
    ex.navigationContentExtra = extra
    for page, record in pairs(pages) do page:SetHeight(record.height + extra) end
    ex:SendModuleEvent("OnLayoutChanged", extra)
end

-- Paint content frames and preserve their original sizes and anchors.
local function PaintPage(page, palette)
    local original = pages[page]
    if not original.saved then
        original.saved, original.backdrop = true, page:GetBackdrop()
        original.color, original.border = {page:GetBackdropColor()}, {page:GetBackdropBorderColor()}
        if #original.color == 0 then original.color = {0.06, 0.132, 0.21, 0.7} end
        if #original.border == 0 then original.border = {0.7, 0.7, 0.8, 0.2} end
    end
    if palette then
        local forever = palette == A.palettes.forever
        page:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = forever and "Interface\\Tooltips\\UI-Tooltip-Border" or "Interface\\Buttons\\WHITE8X8",
            edgeSize = forever and 8 or 1, tile = forever, tileSize = 128,
            insets = forever and {left=3,right=3,top=3,bottom=3} or nil})
        -- Match Classic's translucent content shade, including statistics.
        local color = forever and {0.06,0.06,0.06,0.7} or {unpack(palette.background)}
        color[4] = 0.7
        page:SetBackdropColor(unpack(color))
        page:SetBackdropBorderColor(unpack(palette.edge))
        local talents = ns.ex:GetModuleFromToken("Talents")
        if forever and talents and page == talents.page and not original.backdrop then page:SetBackdrop(nil) end
    else
        page:SetBackdrop(original.backdrop)
        page:SetBackdropColor(unpack(original.color))
        page:SetBackdropBorderColor(unpack(original.border))
    end
    if page.header then
        page.header:SetTextColor(unpack(palette and palette.label or {0.5, 0.75, 1, 1}))
    end
end

--------------------------------------------------------------------------------------------------------
--                                           Main Window                                              --
--------------------------------------------------------------------------------------------------------

-- Preserve the chosen character artwork and visibility independently of the window style.
function A.UpdateBackground()
    local ex = ns.ex
    if not ex or not ex.cfg then return end
    local forever = ex.cfg.style == "forever"
    for _, key in ipairs({"bgTopLeft", "bgTopRight", "bgBottomLeft", "bgBottomRight"}) do
        ex[key]:SetShown(ex.cfg.showBackground)
        ex[key]:SetDesaturated(forever)
        ex[key]:SetVertexColor(forever and 0.55 or 1, forever and 0.55 or 1, forever and 0.55 or 1, 1)
    end
end

-- Crop the round portrait into a compact square only in Modern and restore native geometry otherwise.
function A.UpdatePortrait()
    local ex = ns.ex
    if not ex or not ex.cfg then return end
    local modern = ex.cfg.style == "modern"
    ex.portrait:ClearAllPoints()
    ex.portrait:SetPoint("TOPLEFT", modern and 17 or 7, modern and -17 or -6)
    ex.portrait:SetSize(modern and 44 or 60, modern and 44 or 60)
    local low, high = modern and 0.16 or 0, modern and 0.84 or 1
    ex.portrait:SetTexCoord(low, high, low, high)
    ex.portrait:SetDrawLayer(ex.cfg.style == "classic" and "BACKGROUND" or "ARTWORK", ex.cfg.style == "classic" and 0 or 1)
    -- Match the native portrait's circular clipping rather than exposing the texture's square corners.
    if ex.cfg.style == "forever" and ex.CreateMaskTexture then
        if not ex.portraitMask then
            ex.portraitMask = ex:CreateMaskTexture(nil, "ARTWORK")
            ex.portraitMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            ex.portraitMask:SetPoint("TOPLEFT", ex.portrait, "TOPLEFT", 2, 0)
            ex.portraitMask:SetPoint("BOTTOMRIGHT", ex.portrait, "BOTTOMRIGHT", -2, 4)
        end
        if not ex.portraitMaskAttached then
            ex.portrait:AddMaskTexture(ex.portraitMask)
            ex.portraitMaskAttached = true
        end
    elseif ex.portraitMaskAttached then
        ex.portrait:RemoveMaskTexture(ex.portraitMask)
        ex.portraitMaskAttached = nil
    end
    if ns.ClassIcon then ns.ClassIcon.Update() end
end

-- Build an inset replacement skin around the existing window bounds.
local function CreateWindowSkin(ex)
    local skin = A.Surface(ex)
    -- Keep the border bounds independent of the portrait-shaped background cutout.
    skin.bounds = ex:CreateTexture(nil, "BACKGROUND", nil, -8)
    skin.bounds:SetColorTexture(0,0,0,0)
    skin.bounds:SetPoint("TOPLEFT", 12, -12)
    skin.bounds:SetPoint("BOTTOMRIGHT", -35, 2)
    skin.fill:SetDrawLayer("BACKGROUND", -8)
    skin.fill:ClearAllPoints()
    skin.fill:SetAllPoints(skin.bounds)
    skin.headerFill = ex:CreateTexture(nil, "BACKGROUND", nil, -8)
    skin.headerFill:SetPoint("TOPLEFT", skin.bounds, "TOPLEFT", 62, -25)
    skin.headerFill:SetPoint("BOTTOMRIGHT", skin.bounds, "TOPRIGHT", -1, -64)
    skin.headerFill:Hide()
    for index, edge in ipairs(skin.edges) do
        edge:ClearAllPoints()
        if index <= 2 then
            edge:SetPoint(index == 1 and "TOPLEFT" or "BOTTOMLEFT", skin.bounds)
            edge:SetPoint(index == 1 and "TOPRIGHT" or "BOTTOMRIGHT", skin.bounds)
        else
            edge:SetPoint(index == 3 and "TOPLEFT" or "TOPRIGHT", skin.bounds)
            edge:SetPoint(index == 3 and "BOTTOMLEFT" or "BOTTOMRIGHT", skin.bounds)
        end
    end
    local band = ex:CreateTexture(nil, "BACKGROUND", nil, -7)
    band:SetPoint("TOPLEFT", skin.bounds, "TOPLEFT", 1, -1)
    band:SetPoint("TOPRIGHT", skin.bounds, "TOPRIGHT", -1, -1)
    band:SetHeight(25)
    skin.band = band
    ex.styleSkin = skin
    -- Draw a compact cross independently of the chosen text font, without button chrome.
    local cross = CreateFrame("Frame", nil, ex.close)
    cross:SetSize(12,12)
    cross:SetPoint("CENTER", 0, 0)
    cross.strokes = {}
    for _, angle in ipairs({math.pi/4,-math.pi/4}) do
        local stroke = cross:CreateTexture(nil,"OVERLAY")
        stroke:SetSize(13,2)
        stroke:SetPoint("CENTER")
        stroke:SetRotation(angle)
        stroke:SetColorTexture(0.82,0.82,0.82,1)
        cross.strokes[#cross.strokes + 1] = stroke
    end
    ex.close.styleCross = cross
    ex.close.nativeWidth, ex.close.nativeHeight = ex.close:GetWidth(), ex.close:GetHeight()
    A.RegisterButton(ex.close)
end

-- Apply one style to all registered Examiner controls, including inactive pages.
function A.Apply()
    local ex = ns.ex
    if not ex or not ex.cfg then return end
    local palette = A.Palette()
    if not ex.styleSkin then CreateWindowSkin(ex) end
    local modern = ex.cfg.style == "modern"
    ex.close:ClearAllPoints()
    ex.close:SetPoint("TOPRIGHT", modern and -37 or -34, modern and -14 or -12)
    ex.close:SetSize(modern and 22 or ex.close.nativeWidth, modern and 22 or ex.close.nativeHeight)
    PaintSurface(ex.styleSkin, palette)
    ex.styleSkin.band:SetShown(palette ~= nil)
    if palette then
        ex.styleSkin.fill:SetColorTexture(unpack(palette.background))
        ex.styleSkin.band:SetColorTexture(unpack(palette.panel))
    end
    local forever = ex.cfg.style == "forever"
    ex.styleSkin.fill:ClearAllPoints()
    ex.styleSkin.fill:SetPoint("BOTTOMRIGHT", ex.styleSkin.bounds, "BOTTOMRIGHT")
    ex.styleSkin.band:ClearAllPoints()
    ex.styleSkin.band:SetPoint("TOPLEFT", ex.styleSkin.bounds, "TOPLEFT", forever and 62 or 1, -1)
    ex.styleSkin.band:SetPoint("TOPRIGHT", ex.styleSkin.bounds, "TOPRIGHT", -1, -1)
    ex.styleSkin.headerFill:Hide()
    ex.styleSkin.fill:SetHorizTile(forever)
    ex.styleSkin.fill:SetVertTile(forever)
    ex.styleSkin.fill:SetTexCoord(0,1,0,1)
    if forever then
        -- Keep the upper-left fill behind the round portrait instead of exposing a square corner.
        ex.styleSkin.fill:SetPoint("TOPLEFT", ex.styleSkin.bounds, "TOPLEFT", 0, -20)
        ex.styleSkin.fill:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
        ex.styleSkin.fill:SetVertexColor(1,1,1,1)
        ex.styleSkin.headerFill:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
        ex.styleSkin.headerFill:ClearAllPoints()
        ex.styleSkin.headerFill:SetPoint("TOPLEFT", ex.styleSkin.bounds, "TOPLEFT", 30, 0)
        ex.styleSkin.headerFill:SetPoint("BOTTOMRIGHT", ex.styleSkin.bounds, "TOPRIGHT", 0, -20)
        ex.styleSkin.headerFill:Show()
        ex.styleSkin.headerFill:SetHorizTile(true)
        ex.styleSkin.headerFill:SetVertTile(true)
        ex.styleSkin.headerFill:SetVertexColor(1,1,1,1)
        ex.styleSkin.band:SetColorTexture(0.02,0.02,0.015,1)
        for _, edge in ipairs(ex.styleSkin.edges) do edge:Hide() end
    else
        ex.styleSkin.fill:SetPoint("TOPLEFT", ex.styleSkin.bounds, "TOPLEFT")
        ex.styleSkin.fill:SetVertexColor(1,1,1,1)
    end
    ex.styleSkin.metal = ns.FrameArt.MetalFrame(ex, ex.styleSkin.bounds, ex.styleSkin.metal, forever)
    ex.title:SetDrawLayer(ex.cfg.style == "classic" and "ARTWORK" or "OVERLAY", ex.cfg.style == "classic" and 0 or 6)
    A.UpdatePortrait()
    if not ex.navigationGutter then
        ex.navigationGutter = ex:CreateTexture(nil,"BACKGROUND",nil,-6)
        ex.navigationGutter:SetPoint("TOPLEFT", ex.styleSkin.fill, "TOPRIGHT", 0,-60)
        ex.navigationGutter:SetPoint("BOTTOMRIGHT", ex.styleSkin.fill,"BOTTOMRIGHT",14,4)
    end
    ex.navigationGutter:SetColorTexture(unpack(palette and palette.background or {0.02,0.02,0.02,1}))
    ex.navigationGutter:Hide()
    for _, key in ipairs({"dlgTopLeft", "dlgTopRight", "dlgBottomLeft", "dlgBottomRight"}) do
        ex[key]:SetShown(palette == nil)
    end
    for page in pairs(pages) do PaintPage(page, palette) end
    local sharedScroll = AzDropDown and _G["AzDropDownScroll" .. AzDropDown.vers]
    RegisterLabelledButtons(ex, sharedScroll and sharedScroll:GetParent())
    for button in pairs(buttons) do
        A.PaintButton(button, button.moduleActive, button.navigationIconMode)
    end
    ex.close.styleCross:SetShown(ex.cfg.style == "modern")
    ex.title:SetTextColor(unpack(palette and palette.label or {1, 0.82, 0, 1}))
    local config = ex:GetModuleFromToken("Config")
    if config then
        for _, key in ipairs({"dropDown", "sourceDropDown", "fontDropDown", "styleDropDown", "menuDropDown"}) do
            local dropdown = config[key]
            if dropdown then
                local fill = {0, 0, 0, 1}
                dropdown.background:SetColorTexture(unpack(fill))
                dropdown.menuFillColor = fill
                dropdown.label:SetTextColor(unpack(palette and palette.label or {1, 0.82, 0, 1}))
            end
        end
    end
    ns.FrameArt.ModernDock(ex)
    A.UpdateBackground()
    A.RefreshLabels()
end

-- Synchronize icon selection with the active module without rebuilding any pages.
function A.UpdateSelection()
    local ex = ns.ex
    if not ex or not ex.cfg then return end
    if ns.ClassIcon then ns.ClassIcon.Update() end
    local current = ex.modules[ex.cfg.activePage]
    for _, button in ipairs(ex.buttons) do
        local module = button.id and ex.modules[button.id]
        if module then
            button.moduleActive = current == module or (module.token == "More"
                and current and (current.token == "Config" or current.token == "Cache" or current.token == "Modules"))
            A.PaintButton(button, button.moduleActive, button.navigationIconMode)
            if button.navigationIcon then
                button.navigationIcon:SetDesaturated(not module.hasData)
                button.navigationIcon:SetAlpha(module.hasData and 1 or 0.35)
            end
        end
    end
    ns.FrameArt.ModernDock(ex)
end

-- Commit an allowed appearance choice and immediately refresh owned controls.
function A.Select(setting, value)
    local ex = ns.ex
    if setting == "style" then
        if value ~= "classic" and not A.palettes[value] then return end
    elseif setting == "menuStyle" then
        if value ~= "classic" and value ~= "iconsRight" and value ~= "iconsBottom" then return end
    else
        return
    end
    ex.cfg[setting] = value
    AzDropDown:HideMenu()
    ex:RefreshModuleButtons()
    A.Apply()
    ex:SendModuleEvent("OnConfigChanged", setting, value)
end
