--------------------------------------------------------------------------------------------------------
--
-- Services/FrameArt.lua
-- Uses available native metal-frame and side-tab art with shared-client fallbacks.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local Art, C = {}, ns.Compat
ns.FrameArt = Art

-- Check each atlas before assigning it on a different WoW client.
function Art.Atlas(name)
    local info = C.Try(C_Texture and C_Texture.GetAtlasInfo, name)
    return C.IsTable(info) and info or nil
end

-- Create a thin material strip relative to an existing region.
local function Strip(parent, bounds, side, thickness, inset, color)
    local texture = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    texture:SetColorTexture(unpack(color))
    if side == "TOP" or side == "BOTTOM" then
        texture:SetHeight(thickness)
        local y = side == "TOP" and -inset or inset
        texture:SetPoint(side .. "LEFT", bounds, side .. "LEFT", inset, y)
        texture:SetPoint(side .. "RIGHT", bounds, side .. "RIGHT", -inset, y)
    else
        texture:SetWidth(thickness)
        local x = side == "LEFT" and inset or -inset
        texture:SetPoint("TOP" .. side, bounds, "TOP" .. side, x, -inset)
        texture:SetPoint("BOTTOM" .. side, bounds, "BOTTOM" .. side, x, inset)
    end
    return texture
end

-- Add several bevel layers when native frame atlases are unavailable.
local function FallbackFrame(parent, bounds)
    local pieces = {}
    for inset, color in ipairs({{0.015,0.015,0.012,1}, {0.31,0.30,0.25,1},
        {0.12,0.12,0.10,1}, {0.035,0.03,0.02,1}, {0.23,0.18,0.11,1}}) do
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            pieces[#pieces + 1] = Strip(parent, bounds, side, 1, inset - 2, color)
        end
    end
    return pieces
end

-- Show or hide one material layer collection.
function Art.Show(pieces, shown)
    for _, piece in pairs(pieces or {}) do piece:SetShown(shown) end
end

-- Paint the same metal pieces and offsets used by Forever's PortraitFrameTemplate.
function Art.MetalFrame(parent, bounds, cache, shown)
    cache = cache or {native = {}, fallback = FallbackFrame(parent, bounds)}
    Art.Show(cache.native, false)
    Art.Show(cache.fallback, false)
    if not shown then return cache end
    local atlases = {TopLeftCorner="UI-Frame-PortraitMetal-CornerTopLeft",
        TopRightCorner="UI-Frame-Metal-CornerTopRight", BottomLeftCorner="UI-Frame-Metal-CornerBottomLeft",
        BottomRightCorner="UI-Frame-Metal-CornerBottomRight", TopEdge="_UI-Frame-Metal-EdgeTop",
        BottomEdge="_UI-Frame-Metal-EdgeBottom", LeftEdge="!UI-Frame-Metal-EdgeLeft",
        RightEdge="!UI-Frame-Metal-EdgeRight"}
    local available = true
    for _, atlas in pairs(atlases) do if not Art.Atlas(atlas) then available = false end end
    cache.available = available
    if not available then Art.Show(cache.fallback, true); return cache end
    for key, atlas in pairs(atlases) do
        local piece = cache.native[key] or parent:CreateTexture(nil, "OVERLAY", nil, 3)
        piece:ClearAllPoints()
        local info = Art.Atlas(atlas)
        piece:SetHorizTile(info.tilesHorizontally or false)
        piece:SetVertTile(info.tilesVertically or false)
        piece:SetAtlas(atlas, true)
        piece:Show()
        cache.native[key] = piece
    end
    local p = cache.native
    p.TopLeftCorner:SetPoint("TOPLEFT", bounds, "TOPLEFT", -13, 16)
    p.TopRightCorner:SetPoint("TOPRIGHT", bounds, "TOPRIGHT", C.isForever and 2 or 4, 16)
    p.BottomLeftCorner:SetPoint("BOTTOMLEFT", bounds, "BOTTOMLEFT", -13, C.isForever and -8 or -3)
    p.BottomRightCorner:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", C.isForever and 2 or 4, C.isForever and -8 or -3)
    p.TopEdge:SetPoint("TOPLEFT", p.TopLeftCorner, "TOPRIGHT")
    p.TopEdge:SetPoint("TOPRIGHT", p.TopRightCorner, "TOPLEFT")
    p.BottomEdge:SetPoint("BOTTOMLEFT", p.BottomLeftCorner, "BOTTOMRIGHT")
    p.BottomEdge:SetPoint("BOTTOMRIGHT", p.BottomRightCorner, "BOTTOMLEFT")
    p.LeftEdge:SetPoint("TOPLEFT", p.TopLeftCorner, "BOTTOMLEFT")
    p.LeftEdge:SetPoint("BOTTOMLEFT", p.BottomLeftCorner, "TOPLEFT")
    p.RightEdge:SetPoint("TOPRIGHT", p.TopRightCorner, "BOTTOMRIGHT")
    p.RightEdge:SetPoint("BOTTOMRIGHT", p.BottomRightCorner, "TOPRIGHT")
    return cache
end

-- Continue the window material around each Modern tab, keeping a separate black icon border.
local function ModernTab(button, tab, active, hover)
    tab.background:Hide(); tab.selected:Hide(); tab.hover:Hide()
    tab.native = false
    if tab.maskApplied then
        button.navigationIcon:RemoveMaskTexture(tab.mask)
        tab.maskApplied = nil
    end
    if not tab.modernFill then
        tab.modernFill = button:CreateTexture(nil, "BACKGROUND", nil, 1)
        tab.modernFill:SetAllPoints(button)
        tab.modernEdges, tab.modernIconEdges, tab.modernHighlight = {}, {}, {}
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            tab.modernEdges[#tab.modernEdges + 1] = Strip(button, button, side, 1, 0, ns.Appearance.palettes.modern.frameEdge)
            tab.modernIconEdges[#tab.modernIconEdges + 1] = Strip(button, button.navigationIcon, side, 1, -1, {0,0,0,1})
        end
        -- Adjacent one-pixel rings avoid a dark gap and keep the fade portable across clients.
        for layer, alpha in ipairs({1, 0.42, 0.18, 0.06}) do
            for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
                tab.modernHighlight[#tab.modernHighlight + 1] = Strip(button, button.navigationIcon, side, 1, layer - 2, {0.6,0.6,0.6,alpha})
            end
        end
    end
    tab.modernFill:SetColorTexture(unpack(ns.Appearance.palettes.modern.background))
    tab.modernFill:Show()
    Art.Show(tab.modernEdges, true)
    tab.modernEdges[button.navigationIconPosition == "bottom" and 1 or 3]:Hide()
    Art.Show(tab.modernIconEdges, true)
    Art.Show(tab.modernHighlight, active or hover)
end

-- Paint rectangular Modern buttons or native Classic/Forever tabs without replacing their handlers.
function Art.SideTab(button, active, hover)
    local tab = button.sideTabArt
    if not tab then
        tab = {background=button:CreateTexture(nil,"BACKGROUND",nil,1),
            selected=button:CreateTexture(nil,"OVERLAY",nil,4),
            hover=button:CreateTexture(nil,"OVERLAY",nil,5)}
        for _, texture in pairs(tab) do texture:SetPoint("CENTER"); end
        button.sideTabArt = tab
    end
    local enabled = button.navigationIconMode
    local bottom = button.navigationIconPosition == "bottom"
    local style = ns.ex.cfg and ns.ex.cfg.style or "classic"
    if tab.modernFill then
        tab.modernFill:Hide()
        Art.Show(tab.modernEdges, false)
        Art.Show(tab.modernIconEdges, false)
        Art.Show(tab.modernHighlight, false)
    end
    for _, texture in ipairs({tab.background, tab.selected, tab.hover}) do
        texture:SetSize(bottom and button:GetHeight() or button:GetWidth(), bottom and (button:GetWidth() + 5) or (button:GetHeight() + 5))
        texture:SetRotation(bottom and -math.pi / 2 or 0)
        texture:SetDesaturated(style ~= "forever")
        texture:SetShown(enabled)
    end
    if not enabled then return end
    if style == "modern" then ModernTab(button, tab, active, hover); return end
    local native = Art.Atlas("common-sidetab")
    tab.native = native ~= nil
    if native then
        tab.background:SetAtlas("common-sidetab")
    else
        -- This shared spellbook tab already supplies a dark, bevelled side-tab silhouette.
        tab.background:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    end
    tab.selected:SetShown(active)
    if Art.Atlas("common-sidetab-selected") then
        tab.selected:SetAtlas("common-sidetab-selected")
        tab.selected:SetBlendMode("BLEND")
    else
        tab.selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        tab.selected:SetBlendMode("ADD")
    end
    tab.hover:SetShown(hover)
    if Art.Atlas("common-sidetab-hover") then
        tab.hover:SetAtlas("common-sidetab-hover")
        tab.hover:SetBlendMode("BLEND")
    else
        tab.hover:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        tab.hover:SetBlendMode("ADD")
    end
    if native and Art.Atlas("common-sidetab-mask") and button.CreateMaskTexture then
        if not tab.mask then
            tab.mask = button:CreateMaskTexture(nil, "ARTWORK")
            tab.mask:SetAtlas("common-sidetab-mask")
            tab.mask:SetAllPoints(tab.background)
        end
        if not tab.maskApplied then button.navigationIcon:AddMaskTexture(tab.mask); tab.maskApplied = true end
        tab.mask:SetRotation(bottom and -math.pi / 2 or 0)
    elseif tab.maskApplied then
        button.navigationIcon:RemoveMaskTexture(tab.mask)
        tab.maskApplied = nil
    end
end

-- Continue the subtle window outline between attached tabs.
function Art.ModernDock(ex)
    local skin = ex.styleSkin
    if not skin then return end
    Art.Show(skin.dockSegments, false)
    if ex.cfg.style ~= "modern" then return end
    local bottom = ex.cfg.menuStyle == "iconsBottom"
    local docked = bottom or ex.cfg.menuStyle == "iconsRight"
    local color = ns.Appearance.palettes.modern.frameEdge
    for _, edge in ipairs(skin.edges) do edge:SetColorTexture(unpack(color)); edge:Show() end
    if not docked then return end
    local visible = {}
    for _, button in ipairs(ex.buttons) do
        if button.id and button:IsShown() then visible[#visible + 1] = button end
    end
    if #visible == 0 then return end
    skin.edges[bottom and 2 or 4]:Hide()
    skin.dockSegments = skin.dockSegments or {}
    for index = 1, #visible + 1 do
        local segment = skin.dockSegments[index] or ex:CreateTexture(nil, "BORDER")
        skin.dockSegments[index] = segment
        segment:ClearAllPoints()
        segment:SetColorTexture(unpack(color))
        local previous, following = visible[index - 1], visible[index]
        if bottom then
            segment:SetHeight(1)
            segment:SetPoint("BOTTOMLEFT", previous or skin.bounds, previous and "TOPRIGHT" or "BOTTOMLEFT")
            segment:SetPoint("BOTTOMRIGHT", following or skin.bounds, following and "TOPLEFT" or "BOTTOMRIGHT")
        else
            segment:SetWidth(1)
            segment:SetPoint("TOPRIGHT", previous or skin.bounds, previous and "BOTTOMLEFT" or "TOPRIGHT")
            segment:SetPoint("BOTTOMRIGHT", following or skin.bounds, following and "TOPLEFT" or "BOTTOMRIGHT")
        end
        segment:Show()
    end
end
