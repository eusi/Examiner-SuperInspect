--------------------------------------------------------------------------------------------------------
--
-- Services/Friends.lua
-- Provides explicit friend, group and whisper actions beside the inspected portrait.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local ex, C, L = ns.ex, ns.Compat, ns.L
local F = {}
ns.Friends = F
local ACTION_WIDTH, ACTION_HEIGHT, ACTION_STEP = 24, 22, 26

-- Build a compact action using the same material and hover path as icon tabs.
local function CreateAction(texture, fill)
    local action = CreateFrame("Button", nil, ex)
    action:SetSize(ACTION_WIDTH, ACTION_HEIGHT)
    action.navigationIconMode, action.navigationIconPosition = true, "top"
    action.actionDock = true
    -- Native tooltip fonts retain character coverage for player and realm names.
    action.nativeTooltipFont = true
    action.fillActionIcon, action.actionIconSize = fill, fill and 20 or 18
    action.navigationIcon = action:CreateTexture(nil, "ARTWORK")
    action.navigationIcon:SetSize(action.actionIconSize, action.actionIconSize)
    action.navigationIcon:SetPoint("CENTER")
    action.navigationIcon:SetTexture(texture)
    action.navigationIcon:SetTexCoord(0, 1, 0, 1)
    action.navigationIcon:SetDesaturated(false)
    action:Hide()
    action:SetScript("OnLeave", ex.HideGTT)
    -- Release owned help when the inspected player or window disappears.
    action:SetScript("OnHide", function(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    return action
end

local button = CreateAction("Interface\\Icons\\Achievement_Reputation_01", true)
local group = CreateAction("Interface\\Icons\\INV_Misc_GroupNeedMore", true)
local whisper = CreateAction("Interface\\GossipFrame\\GossipGossipIcon")
F.button, F.groupButton, F.whisperButton = button, group, whisper
ex.options[#ex.options + 1] = {
    var = "showPlayerActions", default = true,
    label = L["Show Player Actions"],
    tip = L["Shows friend, group invite and whisper buttons for the displayed player."],
}

--------------------------------------------------------------------------------------------------------
--                                         Player Identity                                            --
--------------------------------------------------------------------------------------------------------

-- Resolve only the displayed player, retaining the realm in cross-realm names.
local function DisplayedName()
    local name, realm = C.Text(ex.info.name), C.Text(ex.info.realm)
    if ex.unitType == 1 or not name or name == "" or name == (UNKNOWN or "Unknown") then return end
    if realm and realm ~= "" and not name:find("-", 1, true) then name = name .. "-" .. realm end
    local ownName, ownRealm = C.Try(UnitFullName or UnitName, "player")
    ownName, ownRealm = C.Text(ownName), C.Text(ownRealm) or C.Text(C.Try(GetRealmName))
    local ownFull = ownName and ownRealm and (ownName .. "-" .. ownRealm) or ownName
    local guid, ownGUID = C.Text(ex.info.guid), C.Text(C.Try(UnitGUID, "player"))
    if ex.isSelf or (guid and guid == ownGUID) then return end
    if ownFull and name:gsub("%s", ""):lower() == ownFull:gsub("%s", ""):lower() then return end
    if ownName and name == ownName and not realm then return end
    return name
end

-- Use the character-friend API, retaining compatibility with older clients.
local function AddFunction()
    if C_FriendList and type(C_FriendList.IsLegacyFriendSystemEnabled) == "function"
        and not C.IsTrue(C.Try(C_FriendList.IsLegacyFriendSystemEnabled)) then return end
    return C_FriendList and C_FriendList.AddFriend or AddFriend
end

-- Prefer native name-based invitations, including the newer WoW-friend system.
local function FriendAction(name)
    if not name then return end
    local add = AddFunction()
    if type(add) == "function" then return add, name end
    if not C_BattleNet then return end
    if not C.IsTrue(C.Try(BNFeaturesEnabledAndConnected))
        or not C.IsTrue(C.Try(C_BattleNet.AreTitleFriendsEnabled)) then return end
    if type(C_BattleNet.SendTitleFriendInviteByName) == "function" then
        return C_BattleNet.SendTitleFriendInviteByName, name
    end
    if ex.isCacheEntry or not ex.unit then return end
    local _, battleTag = C.Try(BNGetInfo)
    local guid = C.Text(ex.info.guid)
    if not C.Text(battleTag) or not guid or guid ~= C.Text(C.Try(UnitGUID, ex.unit)) then return end
    return C_BattleNet.BNCheckTitleFriendInviteToUnit, ex.unit
end

-- Keep realms in roster comparisons while ignoring their display whitespace.
local function NameKey(name, realm)
    name, realm = C.Text(name), C.Text(realm)
    if not name then return end
    if not name:find("-", 1, true) then
        realm = realm and realm ~= "" and realm or C.Text(C.Try(GetRealmName))
        if realm then name = name .. "-" .. realm end
    end
    return name:gsub("%s", ""):lower()
end

-- Confirm membership before treating character metadata as a friend or offline proof.
local function CharacterFriend(name)
    if not name then return nil, false end
    local guid = C.Text(ex.info.guid)
    local member = guid and C.Safe(C.Try(C_FriendList and C_FriendList.IsFriend, guid))
    if member == false then return nil, false end
    local info = C.Try(C_FriendList and C_FriendList.GetFriendInfo, name)
    local recordName = C.IsTable(info) and C.Text(info.name)
    if recordName and recordName ~= "" and NameKey(recordName) == NameKey(name) then return info, true end
    return nil, C.IsTrue(member)
end

-- Distinguish character friends from confirmed Battle.net and newer WoW friends.
function F.FriendStatus(name)
    local _, character = CharacterFriend(name)
    local guid = C.Text(ex.info.guid)
    local account = guid and C_BattleNet and C.Try(C_BattleNet.GetAccountInfoByGUID, guid)
    local known = C.IsTable(account) and C.IsTrue(account.isFriend) or false
    local level = C.IsTable(account) and C.Safe(account.friendLevel)
    local title = Enum and Enum.BattleNetFriendLevel and Enum.BattleNetFriendLevel.Title
    local wow = known and C.IsNumber(level) and C.IsNumber(title) and level == title or false
    return {character=character, battleNet=known and not wow, wow=wow}
end

-- Suppress redundant friend actions without assuming an add request succeeded.
local function IsFriend(name)
    local status = F.FriendStatus(name)
    return status.character or status.battleNet or status.wow
end

-- Only live identity-matched units or current friend data can prove an offline state.
local function KnownOffline(name)
    local guid = C.Text(ex.info.guid)
    if not ex.isCacheEntry and ex.unit and guid and guid == C.Text(C.Try(UnitGUID, ex.unit)) then
        if C.Safe(C.Try(UnitIsConnected, ex.unit)) == false then return true end
    end
    local friend = CharacterFriend(name)
    return C.IsTable(friend) and C.Safe(friend.connected) == false or false
end

-- Open Blizzard's whisper composer without sending any message.
local function WhisperFunction()
    return ChatFrameUtil and ChatFrameUtil.SendTell or ChatFrame_SendTell
end

--------------------------------------------------------------------------------------------------------
--                                           Group Actions                                            --
--------------------------------------------------------------------------------------------------------

-- Match live or cached inspected identities against the current group roster.
local function InGroup(name)
    local raid = C.IsTrue(C.Try(IsInRaid))
    local count = C.Number(C.Try(GetNumGroupMembers), 0)
    if count == 0 then count = C.Number(C.Try(raid and GetNumRaidMembers or GetNumPartyMembers), 0) end
    local targetGUID, targetName = C.Text(ex.info.guid), NameKey(name)
    for index = 1, math.min(40, count) do
        local unit = (raid and "raid" or "party") .. index
        local guid = C.Text(C.Try(UnitGUID, unit))
        if targetGUID and guid == targetGUID then return true end
        local member, realm = C.Try(UnitName, unit)
        if targetName and NameKey(member, realm) == targetName then return true end
    end
    return false
end

-- Follow native invite permissions, with leader/assistant checks on older clients.
local function CanInvite()
    local raid = C.IsTrue(C.Try(IsInRaid))
    local count = C.Number(C.Try(GetNumGroupMembers), 0)
    if count == 0 then
        count = C.Number(C.Try(raid and GetNumRaidMembers or GetNumPartyMembers), 0)
        if not raid and count > 0 then count = count + 1 end
    end
    if count >= (raid and 40 or 5) then return false end
    local faction, ownFaction = C.Text(ex.info.factionGroup), C.Text(C.Try(UnitFactionGroup, "player"))
    if faction and ownFaction and faction ~= ownFaction
        and not C.IsTrue(C.Try(C_PartyInfo and C_PartyInfo.CanFormCrossFactionParties)) then return false end
    if C_PartyInfo and type(C_PartyInfo.CanInvite) == "function" then
        return C.IsTrue(C.Try(C_PartyInfo.CanInvite))
    end
    local grouped = C.IsTrue(C.Try(IsInGroup)) or C.Number(C.Try(GetNumGroupMembers), 0) > 0
        or C.Number(C.Try(GetNumPartyMembers), 0) > 0 or C.Number(C.Try(GetNumRaidMembers), 0) > 0
    return not grouped or C.IsTrue(C.Try(UnitIsGroupLeader, "player"))
        or C.IsTrue(C.Try(UnitIsGroupAssistant, "player"))
end

-- Use the normal invite path so Blizzard can request its usual confirmations.
local function InviteFunction()
    return C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
end

-- Explain why a displayed player cannot currently be invited.
local function InviteReason(name)
    if KnownOffline(name) then return "You cannot invite players right now." end
    if InGroup(name) then return "Already in your group" end
    if not CanInvite() then return "You cannot invite players right now." end
end

--------------------------------------------------------------------------------------------------------
--                                           Button State                                             --
--------------------------------------------------------------------------------------------------------

-- Dock available action tabs upward and close gaps left by unavailable actions.
function F.Update()
    if not ex.cfg then button:Hide(); group:Hide(); whisper:Hide(); return end
    local name = ex.cfg.showPlayerActions ~= false and DisplayedName() or nil
    local add = FriendAction(name)
    local friend = name and IsFriend(name)
    local visible = name ~= nil and type(add) == "function" and not friend
    local bounds = ex.styleSkin and ex.styleSkin.bounds or ex
    local x = ex.cfg.style == "modern" and 65 or 71
    local y = bounds == ex and -12 or 0
    -- Dock to each style's visible upper frame edge, using compact native art.
    if ns.Appearance.TexturedStyle() then y = y + 4
    elseif ex.cfg.style == "classic" then y = y - 1 end
    if bounds ~= ex then x = x - 12 end
    button.playerName = visible and name or nil
    button:SetShown(visible)
    button:SetEnabled(visible)
    group.playerName = name
    group.reason = name and InviteReason(name)
    local inviteVisible = name ~= nil and type(InviteFunction()) == "function" and not group.reason
    group:SetShown(inviteVisible)
    group:SetEnabled(inviteVisible)
    local whisperVisible = name ~= nil and type(WhisperFunction()) == "function" and not KnownOffline(name)
    whisper.playerName = whisperVisible and name or nil
    whisper:SetShown(whisperVisible); whisper:SetEnabled(whisperVisible)
    ex.title:SetWidth(0)
    ex.title:SetMaxLines(0)
    local offset = x
    for _, action in ipairs({whisper, group, button}) do
        action:ClearAllPoints()
        action:SetPoint("BOTTOMLEFT", bounds, "TOPLEFT", offset, y)
        if action:IsShown() then offset = offset + ACTION_STEP end
        -- Keep heads below the curved top; retain the chat texture's native size.
        local inset = action.fillActionIcon and ex.cfg.style ~= "modern" and action.CreateMaskTexture
            and ns.FrameArt.Atlas("common-sidetab") and ns.FrameArt.Atlas("common-sidetab-mask")
        local size = action.actionIconSize
        action.navigationIcon:SetSize(size, size)
        action.navigationIcon:ClearAllPoints()
        local iconY = action == whisper and -2 or (inset or ex.cfg.style == "modern") and -1 or 0
        action.navigationIcon:SetPoint("CENTER", 0, iconY)
        ns.Appearance.PaintButton(action, false, true)
        if action == button then action.navigationIcon:SetDesaturated(false) end
        if GameTooltip:IsShown() and GameTooltip:GetOwner() == action then
            if action:IsShown() and ex:IsShown() then action:GetScript("OnEnter")(action) else GameTooltip:Hide() end
        end
    end
    ns.FrameArt.ModernDock(ex)
end

-- Explain the action using the same identity that a click will resolve again.
function F.ShowTooltip()
    local friend = IsFriend(button.playerName)
    local add = FriendAction(button.playerName)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(friend and L["Already on your friends list"] or L["Add to friends list"], 1, 0.82, 0)
    GameTooltip:AddLine(button.playerName or "", 1, 1, 1)
    if not friend and type(add) ~= "function" then
        GameTooltip:AddLine(L["Not available"], 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

-- Add only the currently displayed player after a deliberate button click.
button:SetScript("OnClick", function()
    if not ex.cfg or ex.cfg.showPlayerActions == false then return end
    local name = DisplayedName()
    local add, identity = FriendAction(name)
    if name and type(add) == "function" and not IsFriend(name) then add(identity) end
    F.Update()
end)
button:SetScript("OnEnter", F.ShowTooltip)

-- Identify the current invite target and any native permission restriction.
group:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L["Invite to group"], 1, 0.82, 0)
    GameTooltip:AddLine(self.playerName or "", 1, 1, 1)
    if self.reason then GameTooltip:AddLine(L[self.reason], 0.7, 0.7, 0.7) end
    GameTooltip:Show()
end)
-- Recheck both identity and permissions immediately before sending one invitation.
group:SetScript("OnClick", function()
    if not ex.cfg or ex.cfg.showPlayerActions == false then return end
    local name, invite = DisplayedName(), InviteFunction()
    if name and type(invite) == "function" and not InviteReason(name) then invite(name) end
    F.Update()
end)
whisper:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L["Whisper"], 1, 0.82, 0)
    GameTooltip:AddLine(self.playerName or "", 1, 1, 1)
    GameTooltip:Show()
end)
-- Resolve the displayed identity again when opening the chat input.
whisper:SetScript("OnClick", function()
    if not ex.cfg or ex.cfg.showPlayerActions == false then return end
    local name, compose = DisplayedName(), WhisperFunction()
    if name and type(compose) == "function" and not KnownOffline(name) then compose(name) end
    F.Update()
end)
for _, action in ipairs({button, group, whisper}) do ns.Appearance.RegisterButton(action) end
for _, event in ipairs({"FRIENDLIST_UPDATE", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED"}) do button:RegisterEvent(event) end
for _, event in ipairs({"BN_FRIEND_INFO_CHANGED", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE",
    "BN_FRIEND_ACCOUNT_OFFLINE", "BN_CONNECTED", "BN_DISCONNECTED", "UNIT_CONNECTION"}) do C.Try(button.RegisterEvent, button, event) end
button:SetScript("OnEvent", F.Update)
ex:HookScript("OnShow", F.Update)
