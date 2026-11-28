--------------------------------------------------------------------------------------------------------
--
-- Services/Roles.lua
-- Shows the native specialization-role badge beside the character details.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local C, ex, R = ns.Compat, ns.ex, {badges = {}}
ns.Roles = R
-- Native GetTexCoordsForRole uses 67-pixel cells in UI-LFG-ICON-ROLES (256x256).
local icons = {
    TANK = {0, 67/256, 67/256, 134/256},
    HEALER = {67/256, 134/256, 0, 67/256},
    DAMAGER = {67/256, 134/256, 67/256, 134/256},
}
local roleAtlases = {
    TANK = "groupfinder-icon-role-large-tank",
    HEALER = "groupfinder-icon-role-large-heal",
    DAMAGER = "groupfinder-icon-role-large-dps",
}
local nativeRoleAtlases = {
    TANK = "UI-LFG-RoleIcon-Tank",
    HEALER = "UI-LFG-RoleIcon-Healer",
    DAMAGER = "UI-LFG-RoleIcon-DPS",
}
local treeRoles = {
    WARRIOR = {"DAMAGER", "DAMAGER", "TANK"},
    PALADIN = {"HEALER", "TANK", "DAMAGER"},
    PRIEST = {"HEALER", "HEALER", "DAMAGER"},
    SHAMAN = {"DAMAGER", "DAMAGER", "HEALER"},
    DRUID = {[1] = "DAMAGER", [3] = "HEALER"},
    MAGE = {"DAMAGER", "DAMAGER", "DAMAGER"},
    WARLOCK = {"DAMAGER", "DAMAGER", "DAMAGER"},
    HUNTER = {"DAMAGER", "DAMAGER", "DAMAGER"},
    ROGUE = {"DAMAGER", "DAMAGER", "DAMAGER"},
}
-- Client-derived Feral marker identities: https://talentsforever.com/data/druid.json
-- Attribution: talentsforever.com, CC BY 4.0 https://creativecommons.org/licenses/by/4.0/
local bearIconPaths = {"ability_druid_lacerate", "ability_racial_cannibalize", "ability_bullrush"}
local bearIcons

-- Infer bear intent only from invested Feral markers; otherwise use the requested DPS default.
function R.Feral(tree)
    if not bearIcons then
        bearIcons = {}
        for _, name in ipairs(bearIconPaths) do
            local path = "Interface\\Icons\\" .. name
            bearIcons[path:lower()] = true
            local id = C.Icon(C.Try(GetFileIDFromPath,path))
            if id and id ~= 0 then bearIcons[id] = true end
        end
    end
    for _, node in ipairs(C.IsTable(tree.nodes) and tree.nodes or {}) do
        local points = C.Number(node.spent, C.Number(node.rank, 0))
        local entry = C.IsTable(node.entry) and node.entry
        if points > 0 and points < math.huge and entry then
            local icon = C.Icon(entry.icon)
            if type(icon) == "string" then icon = icon:lower():gsub("/","\\"):gsub("%.blp$","") end
            local spell = C.Number(entry.spell)
            if icon and bearIcons[icon] or spell == 407995 or spell == 1328617 then return "TANK" end
        end
    end
    return "DAMAGER"
end

-- Only accept known roles; never use the local player's assigned group role.
function R.Valid(role)
    role = C.Text(role)
    return role and icons[role] and role or nil
end

-- Classify the unique active tree; SoD runes can change roles independently.
function R.Resolve(data, class)
    if not C.IsTable(data) then return end
    if C.IsTable(data.groups) then data = data.groups[data.activeGroup] end
    if not C.IsTable(data) then return end
    if not C.isForever and C.talentKind ~= "classic" then return R.Valid(data.role) end
    if C.isSoD then return end
    local roles = treeRoles[class]
    if not roles or not C.IsTable(data.trees) or #data.trees ~= 3 then return end
    local best, highest, tied = nil, 0, false
    for index, tree in ipairs(data.trees) do
        local points = C.Number(tree.points)
        if not points or points < 0 then return end
        if points > highest then best, highest, tied = index, points, false
        elseif points == highest then tied = true end
    end
    if not best or tied then return end
    if C.isForever and class == "DRUID" and best == 2 then return R.Feral(data.trees[2]) end
    return roles[best]
end

-- Avoid snapping small curved artwork to whole texels when the window is scaled.
local function Smooth(texture)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
end

-- Reuse frames with native circular role artwork and a separately tinted rim.
local function Badge(key, parent, size)
    local badge = R.badges[key]
    if not badge then
        badge = CreateFrame("Frame", nil, parent)
        badge:SetFrameLevel(parent:GetFrameLevel() + 12)
        badge:EnableMouse(false)
        badge.texture = badge:CreateTexture(nil, "OVERLAY")
        badge.texture:SetAllPoints()
        Smooth(badge.texture)
        if badge.CreateMaskTexture then
            badge.rim = badge:CreateTexture(nil, "ARTWORK")
            badge.rim:SetAllPoints()
            badge.rim:SetDesaturated(true)
            Smooth(badge.rim)
            badge.centerMask = badge:CreateMaskTexture(nil, "ARTWORK")
            badge.centerMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
            badge.centerMask:SetPoint("CENTER", badge, "CENTER")
            Smooth(badge.centerMask)
        end
        R.badges[key] = badge
    end
    badge:SetSize(size, size)
    if badge.centerMask then badge.centerMask:SetSize(size*0.8, size*0.8) end
    return badge
end

-- Match the native Group Finder artwork without resizing the badge to the atlas size.
local function SetArtwork(badge, role)
    local style = ex.cfg.style
    if badge.artworkRole == role and badge.artworkStyle == style then return end
    local atlas = roleAtlases[role]
    local info = ns.FrameArt.Atlas(atlas)
    if not info then
        atlas = nativeRoleAtlases[role]
        info = ns.FrameArt.Atlas(atlas)
    end
    for _, texture in ipairs(badge.rim and {badge.texture, badge.rim} or {badge.texture}) do
        if texture.SetAtlas and info then
            texture:SetTexCoord(0, 1, 0, 1)
            texture:SetAtlas(atlas, false)
        else
            texture:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")
            texture:SetTexCoord(unpack(icons[role]))
        end
        Smooth(texture)
    end
    if badge.rim then
        local styled = style ~= "forever"
        if styled and not badge.maskAttached then
            badge.texture:AddMaskTexture(badge.centerMask)
            badge.maskAttached = true
        elseif not styled and badge.maskAttached then
            badge.texture:RemoveMaskTexture(badge.centerMask)
            badge.maskAttached = false
        end
        if style == "classic" then badge.rim:SetVertexColor(0.85, 0.87, 0.9)
        else badge.rim:SetVertexColor(0.14, 0.15, 0.17) end
        badge.rim:SetShown(styled)
    end
    badge.artworkRole, badge.artworkStyle = role, style
end

-- Keep the role beside the character details while leaving room for long headers.
function R.Update()
    local role = ns.ClassIcon and R.Valid(ns.ClassIcon.role)
    if role and ex.unitType ~= 1 and ex.cfg then
        local header = Badge("header", ex, 16)
        header:ClearAllPoints()
        header:SetPoint("LEFT", ex.details, "RIGHT", 4, 0)
        local textWidth = C.Number(ex.details:GetStringWidth(), 0)
        header.fits = ex:GetWidth()/2 + 5 + textWidth/2 + 20 <= ex:GetWidth() - 36
    end
    for _, badge in pairs(R.badges) do
        if role then SetArtwork(badge, role) end
        badge:SetShown(role ~= nil and ex.unitType ~= 1 and ex.details:IsShown()
            and badge.fits == true)
    end
end
