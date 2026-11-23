--------------------------------------------------------------------------------------------------------
--
-- Services/ClassIcon.lua
-- Shows the inspected class and a style-aware active-specialization badge on the Talents tab.
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

-- Clip a decorative layer with the same native round mask as its badge artwork.
local function RoundLayer(layer, owner)
    local mask = (owner or button):CreateMaskTexture(nil,"ARTWORK")
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    mask:SetAllPoints(layer)
    layer:AddMaskTexture(mask)
    return mask
end

-- Create the tab badge once while leaving all mouse interaction with its parent tab.
local function CreateSpecBadge(size)
    local frame = CreateFrame("Button",nil,ex)
    frame:SetSize(size,size)
    frame:SetFrameLevel(button:GetFrameLevel())
    frame:EnableMouse(false)
    frame:Hide()
    frame.icon = frame:CreateTexture(nil,"ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetTexCoord(0.08,0.92,0.08,0.92)
    if frame.CreateMaskTexture then
        frame.mask = frame:CreateMaskTexture(nil,"ARTWORK")
        frame.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        frame.mask:SetAllPoints(frame.icon)
        frame.icon:AddMaskTexture(frame.mask)
        frame.maskAttached = true
    end
    -- Release specialization help when a preview is hidden or reparented.
    frame:SetScript("OnHide",function(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    return frame
end

local tabSpecialization = CreateSpecBadge(16)
tabSpecialization.icon:SetTexCoord(0,1,0,1)
P.specialization = tabSpecialization
P.tabSpecialization = tabSpecialization
P.specCandidates = {tabSpecialization}

-- Add a round metal rim, dark inset and glass sheen without enlarging the icon itself.
local function AddTabGlass(frame)
    if not frame.CreateMaskTexture then return end
    frame.bezel = frame:CreateTexture(nil,"BACKGROUND",nil,0)
    frame.bezel:SetPoint("TOPLEFT",frame,"TOPLEFT",-2,2)
    frame.bezel:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",2,-2)
    frame.bezelMask = RoundLayer(frame.bezel,frame)
    frame.socket = frame:CreateTexture(nil,"BACKGROUND",nil,1)
    frame.socket:SetPoint("TOPLEFT",frame,"TOPLEFT",-1,1)
    frame.socket:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",1,-1)
    frame.socket:SetColorTexture(0.04,0.04,0.04,1)
    frame.socketMask = RoundLayer(frame.socket,frame)
    frame.glass = frame:CreateTexture(nil,"OVERLAY")
    frame.glass:SetAllPoints(frame.icon)
    frame.glass:SetColorTexture(1,1,1,1)
    frame.glass:SetAlpha(0.25)
    if frame.glass.SetGradient and CreateColor then
        frame.glass:SetGradient("VERTICAL",CreateColor(1,1,1,0),CreateColor(1,1,1,0.38))
    else
        frame.glass:SetGradientAlpha("VERTICAL",1,1,1,0,1,1,1,0.38)
    end
    frame.glassMask = RoundLayer(frame.glass,frame)
end
AddTabGlass(tabSpecialization)

-- Follow the Talents module when pooled navigation buttons change owner or layout.
local function UpdateTabSpecialization(show)
    local talents = ex:GetModuleFromToken("Talents")
    local owner = talents and talents:IsEnabled() and talents.button
    if not show or not owner then
        tabSpecialization:Hide()
        tabSpecialization:SetParent(ex)
        return
    end
    tabSpecialization:SetParent(owner)
    tabSpecialization:SetFrameLevel(owner:GetFrameLevel()+8)
    tabSpecialization:ClearAllPoints()
    tabSpecialization:SetPoint("BOTTOMRIGHT",owner,"BOTTOMRIGHT",-4,owner.navigationIconMode and 4 or -8)
    tabSpecialization:SetSize(owner.navigationIconMode and 16 or 12,owner.navigationIconMode and 16 or 12)
    local round = ex.cfg.style ~= "modern"
    if tabSpecialization.mask then
        if round and not tabSpecialization.maskAttached then
            tabSpecialization.icon:AddMaskTexture(tabSpecialization.mask)
            tabSpecialization.maskAttached = true
        elseif not round and tabSpecialization.maskAttached then
            tabSpecialization.icon:RemoveMaskTexture(tabSpecialization.mask)
            tabSpecialization.maskAttached = false
        end
    end
    for _, key in ipairs({"bezel","socket","glass"}) do
        if tabSpecialization[key] then tabSpecialization[key]:SetShown(round) end
    end
    if tabSpecialization.bezel then
        if ex.cfg.style == "forever" then
            tabSpecialization.bezel:SetColorTexture(0.72,0.56,0.38,1)
        else
            tabSpecialization.bezel:SetColorTexture(0.65,0.65,0.65,1)
        end
    end
    tabSpecialization:Show()
end

-- Select a unique dominant tree only when every active tree has known points.
local function DominantTree(data)
    if not C.IsTable(data) or not C.IsTable(data.trees) then return end
    local best, highest, tied = nil, 0, false
    for _, tree in ipairs(data.trees) do
        local points = C.Number(tree.points)
        if not points or points < 0 then return end
        if points > highest then
            best, highest, tied = tree, points, false
        elseif points == highest then
            tied = true
        end
    end
    if best and not tied then return C.Text(best.name), C.Icon(best.icon) end
end

-- Resolve only the active build; a selected inactive talent page is not the active spec.
function P.ReadSpecialization(data)
    if C.IsTable(data) and C.IsTable(data.groups) then data = data.groups[data.activeGroup] end
    if C.isForever or C.talentKind == "classic" then return DominantTree(data) end
    if C.IsTable(data) then return C.Text(data.specName), C.Icon(data.specIcon) end
end

-- Keep specialization data independent of whether the talent page is open or enabled.
function P.CaptureSpecialization(unit)
    local data
    if C.talentKind == "classic" then
        data = { trees = {} }
        local inspect = not ex.isSelf
        local group = C.ActiveTalentGroup(inspect)
        for index = 1, math.min(3,C.Number(C.Try(GetNumTalentTabs,inspect,false),0)) do
            local name, icon, points = C.LegacyTalentTab(index,inspect,group)
            data.trees[index] = {name=name,icon=icon,points=points}
        end
    elseif C.isForever then
        local mod = ex:GetModuleFromToken("Talents")
        data = mod and mod:IsEnabled() and ex.talentData or ns.Talents.ReadForever(unit,ex.isSelf)
    else
        local _, name, _, icon = C.GetSpecialization(unit,ex.isSelf)
        data = {specName=name,specIcon=icon}
    end
    P.specName, P.specIcon = P.ReadSpecialization(data)
    ex.info.specialization=P.specIcon and {name=P.specName,icon=P.specIcon} or false
    P.Update()
end

-- Restore only this cached player's saved talent snapshot, without querying live APIs.
function P.LoadSpecialization(entry)
    local saved=entry.specialization
    if C.IsTable(saved) then
        P.specName,P.specIcon=C.Text(saved.name),C.Icon(saved.icon)
    elseif saved==false then
        P.specName,P.specIcon=nil,nil
    else
        P.specName, P.specIcon = P.ReadSpecialization(entry.Talents or entry.ClassicTalents)
    end
    P.Update()
end

-- Remove a previous player's or previous build's badge while new data is pending.
function P.ClearSpecialization()
    P.specName, P.specIcon = nil, nil
    for _, frame in ipairs(P.specCandidates) do
        frame:Hide()
        if GameTooltip:GetOwner() == frame then GameTooltip:Hide() end
    end
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
    if not ex.cfg then
        button:Hide()
        for _, frame in ipairs(P.specCandidates) do frame:Hide() end
        return
    end
    local class = C.Text(ex.info.classFixed)
    local coords = class and ((CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]) or classicCoords[class])
    local hasSpec = P.specIcon ~= nil and ex.unitType ~= 1 and coords ~= nil
    UpdateTabSpecialization(hasSpec)
    UpdateStyle()
    if ns.Friends then ns.Friends.Update() end
    if ex.unitType == 1 or not coords then
        button.className = nil
        if GameTooltip:GetOwner() == button then GameTooltip:Hide() end
        button:Hide()
        P.ClearSpecialization()
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
    if hasSpec then
        for _, frame in ipairs(P.specCandidates) do frame.icon:SetTexture(P.specIcon) end
    end
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
