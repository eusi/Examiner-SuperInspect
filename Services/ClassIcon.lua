--------------------------------------------------------------------------------------------------------
--
-- Services/ClassIcon.lua
-- Shows the inspected class with style-specific placement and a Forever glass bezel.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local P, C, ex = {}, ns.Compat, ns.ex
ns.ClassIcon = P
-- Retain the original character-creation sheet on clients without the shared global table.
local classicCoords = {
    WARRIOR = {0,0.25,0,0.25}, MAGE = {0.25,0.5,0,0.25}, ROGUE = {0.5,0.75,0,0.25}, DRUID = {0.75,1,0,0.25},
    HUNTER = {0,0.25,0.25,0.5}, SHAMAN = {0.25,0.5,0.25,0.5}, PRIEST = {0.5,0.75,0.25,0.5}, WARLOCK = {0.75,1,0.25,0.5},
    PALADIN = {0,0.25,0.5,0.75}, DEATHKNIGHT = {0.25,0.5,0.5,0.75}, MONK = {0.5,0.75,0.5,0.75},
}

local button = CreateFrame("Button", nil, ex)
button:SetSize(20,20)
button:SetFrameLevel(ex:GetFrameLevel() + 10)
button:Hide()
P.frame = button
button.icon = button:CreateTexture(nil,"ARTWORK")
button.icon:SetAllPoints()
button:SetPoint("BOTTOMRIGHT",ex.portrait,"BOTTOMRIGHT",6,-3)

-- Clip a decorative layer with the same native round mask as the class artwork.
local function RoundLayer(layer)
    local mask = button:CreateMaskTexture(nil,"ARTWORK")
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    mask:SetAllPoints(layer)
    layer:AddMaskTexture(mask)
    return mask
end

-- Keep the Modern badge inside the name bar and restore portrait badges in other styles.
local function UpdateStyle()
    local modern, forever = ex.cfg.style == "modern", ex.cfg.style == "forever"
    button:ClearAllPoints()
    if modern then
        button:SetPoint("LEFT",ex,"TOPLEFT",63,-26)
    else
        button:SetPoint("BOTTOMRIGHT",ex.portrait,"BOTTOMRIGHT",forever and 4 or 6,-3)
    end
    ex.title:ClearAllPoints()
    ex.title:SetWordWrap(not modern)
    if modern then
        ex.title:SetPoint("LEFT",button,"RIGHT",14,2)
        ex.title:SetPoint("RIGHT",ex.close,"LEFT",-8,0)
    else
        ex.title:SetPoint("TOP",5,-17)
    end
    if forever and button.CreateMaskTexture and not button.bezel then
        button.bezel = button:CreateTexture(nil,"BACKGROUND",nil,0)
        button.bezel:SetSize(24,24)
        button.bezel:SetPoint("CENTER",button,"CENTER",-1,0)
        button.bezel:SetColorTexture(0.72,0.56,0.38,1)
        button.bezelMask = RoundLayer(button.bezel)
        button.socket = button:CreateTexture(nil,"BACKGROUND",nil,1)
        button.socket:SetSize(22,22)
        button.socket:SetPoint("CENTER",button,"CENTER",-1,0)
        button.socket:SetColorTexture(0.05,0.05,0.05,1)
        button.socketMask = RoundLayer(button.socket)
        button.glass = button:CreateTexture(nil,"OVERLAY")
        button.glass:SetSize(20,20)
        button.glass:SetPoint("CENTER",button.icon,"CENTER",-1,0)
        button.glass:SetColorTexture(1,1,1,1)
        if button.glass.SetGradient and CreateColor then
            button.glass:SetGradient("VERTICAL",CreateColor(1,1,1,0),CreateColor(1,1,1,0.38))
        else
            button.glass:SetGradientAlpha("VERTICAL",1,1,1,0,1,1,1,0.38)
        end
        button.glassMask = RoundLayer(button.glass)
    end
    for _, key in ipairs({"bezel","socket","glass"}) do
        if button[key] then button[key]:SetShown(forever) end
    end
end

-- Update only the inspected/cached class, never substituting the local player's class.
function P.Update()
    if not ex.cfg then button:Hide(); return end
    UpdateStyle()
    local class = C.Text(ex.info.classFixed)
    local coords = class and ((CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]) or classicCoords[class])
    if ex.unitType == 1 or not coords then
        button.className = nil
        if GameTooltip:GetOwner() == button then GameTooltip:Hide() end
        button:Hide()
        return
    end
    button.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    button.icon:SetTexCoord(unpack(coords))
    button.className = C.Text(ex.info.class) or class
    if button.CreateMaskTexture then
        if not button.mask then
            button.mask = button:CreateMaskTexture(nil,"ARTWORK")
            button.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            button.mask:SetAllPoints(button.icon)
        end
        if not button.maskAttached then
            button.icon:AddMaskTexture(button.mask)
            button.maskAttached = true
        end
    end
    button:Show()
end

-- Identify the inspected class without exposing development controls.
button:SetScript("OnEnter",function(self)
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(self.className or "",1,0.82,0)
    GameTooltip:Show()
end)
button:SetScript("OnLeave",ex.HideGTT)
-- Release class help when the window or icon is hidden.
button:SetScript("OnHide",function(self)
    if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
end)
