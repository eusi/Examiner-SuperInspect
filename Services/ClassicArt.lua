--------------------------------------------------------------------------------------------------------
--
-- Services/ClassicArt.lua
-- Uses Classic-native window, portrait and icon art on Era, TBC and Mists.
--
----------------------

local _, ns = ...
if ns.blocked or not (ns.Compat.isEra or ns.Compat.isTBC or ns.Compat.isMists) then return end
local ex, A, Art, S = ns.ex, ns.Appearance, ns.FrameArt, {}
ns.ClassicArt = S

--------------------------------------------------------------------------------------------------------
--                                         Native Icon Frames                                         --
--------------------------------------------------------------------------------------------------------

local originalSideTab = Art.SideTab
function Art.SideTab(button, active, hover)
    originalSideTab(button, active, hover)
    local tab = button.sideTabArt
    if not tab then return end
    local enabled = button.navigationIconMode and ex.cfg.style ~= "modern"
    if not enabled then
        if tab.classicBorder then tab.classicBorder:Hide(); tab.classicFill:Hide() end
        return
    end
    if not tab.classicBorder then
        tab.classicFill = button:CreateTexture(nil, "BACKGROUND", nil, 2)
        tab.classicFill:SetAllPoints(button)
        tab.classicFill:SetColorTexture(0.025, 0.025, 0.025, 1)
        -- Guild crest layers are child frames; keep the border above their artwork too.
        tab.classicBorderHost = CreateFrame("Frame", nil, button)
        tab.classicBorderHost:SetAllPoints(button)
        tab.classicBorderHost:SetFrameLevel(button:GetFrameLevel() + 4)
        tab.classicBorderHost:EnableMouse(false)
        tab.classicBorder = tab.classicBorderHost:CreateTexture(nil, "OVERLAY", nil, 3)
        tab.classicBorder:SetAllPoints(button)
        tab.classicBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        -- Native Classic ActionButtonTemplate crops the transparent slot margins.
        tab.classicBorder:SetTexCoord(0.1875, 0.796875, 0.1875, 0.796875)
    end
    tab.background:Hide()
    tab.native = false
    if tab.maskApplied then
        button.navigationIcon:RemoveMaskTexture(tab.mask)
        tab.maskApplied = nil
    end
    local dark = ex.cfg.style == "dark"
    tab.classicBorder:SetDesaturated(ex.cfg.style ~= "forever")
    local shade = dark and 0.55 or 1
    tab.classicBorder:SetVertexColor(shade, shade, shade, 1)
    tab.classicFill:Show(); tab.classicBorder:Show()
    for _, texture in ipairs({tab.selected, tab.hover}) do
        texture:ClearAllPoints(); texture:SetAllPoints(button)
        texture:SetRotation(0)
        texture:SetBlendMode("ADD")
    end
    tab.selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    tab.selected:SetAlpha(0.6); tab.selected:SetShown(not not active)
    tab.hover:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    tab.hover:SetAlpha(0.35); tab.hover:SetShown(not not hover)
end

--------------------------------------------------------------------------------------------------------
--                                      Native Window And Portrait                                    --
--------------------------------------------------------------------------------------------------------

-- The Classic template owns the rock tiling, title band and circular border geometry.
local function Window()
    if S.window then return S.window end
    local frame = CreateFrame("Frame", nil, ex, "PortraitFrameTemplateNoCloseButton")
    frame:EnableMouse(false)
    frame:SetFrameLevel(math.max(0, ex:GetFrameLevel() - 1))
    frame:SetPoint("TOPLEFT", ex, "TOPLEFT", 12, -12)
    frame:SetPoint("BOTTOMRIGHT", ex, "BOTTOMRIGHT", -35, 2)
    if frame.TitleText then frame.TitleText:Hide() end
    if frame.TitleContainer then frame.TitleContainer:Hide() end
    if frame.PortraitContainer then frame.PortraitContainer:Hide() end
    if frame.portrait then frame.portrait:Hide() end
    if frame.NineSlice then frame.NineSlice:Hide() end
    S.window = frame
    return frame
end

local originalPortrait = A.UpdatePortrait
function A.UpdatePortrait()
    originalPortrait()
    if not ex.cfg then return end
    local textured = A.TexturedStyle()
    if textured and ex.portraitMask then
        -- Use the same wrapping and clipping as the native Classic PortraitFrame.
        ex.portraitMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        ex.portraitMask:ClearAllPoints()
        ex.portraitMask:SetPoint("TOPLEFT", ex.portrait, "TOPLEFT", 2, -2)
        ex.portraitMask:SetPoint("BOTTOMRIGHT", ex.portrait, "BOTTOMRIGHT", -5, 4)
        if not S.portraitFill then
            local fill = ex:CreateTexture(nil, "ARTWORK", nil, 0)
            fill:SetAllPoints(ex.portrait); fill:SetColorTexture(0, 0, 0, 1)
            fill:AddMaskTexture(ex.portraitMask)
            S.portraitFill = fill
        end
    end
    if S.portraitFill then S.portraitFill:SetShown(textured) end
end

local originalApply = A.Apply
function A.Apply()
    originalApply()
    if not ex.cfg then return end
    local textured = A.TexturedStyle()
    if not textured then
        if S.window then S.window:Hide() end
        return
    end
    local frame, skin = Window(), ex.styleSkin
    skin.fill:Hide(); skin.headerFill:Hide(); skin.band:Hide()
    Art.Show(skin.edges, false)
    Art.Show(skin.metal.native, false); Art.Show(skin.metal.fallback, false)
    local dark = ex.cfg.style == "dark"
    for _, region in ipairs({frame:GetRegions()}) do
        if region.SetDesaturated then
            region:SetDesaturated(dark)
            local shade = dark and 0.45 or 1
            region:SetVertexColor(shade, shade, shade, 1)
        end
    end
    frame:Show()
end
