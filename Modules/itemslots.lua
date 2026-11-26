--------------------------------------------------------------------------------------------------------
--
-- Modules/itemslots.lua
-- Displays equipped items and item-level overlays around the character model.
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
local GetItemInfo = ExaminerNS.Compat.GetItemInfo
local GetItemQualityColor = ExaminerNS.Compat.GetItemQualityColor
local GetDetailedItemLevelInfo = ExaminerNS.Compat.GetDetailedItemLevelInfo
local GetInventorySlotInfo = ExaminerNS.Compat.GetInventorySlotInfo
local cfg
local gtt = GameTooltip

-- MODULE

local mod = ex:CreateModule("ItemSlots")
mod.slotBtns = {}
mod.pendingItems, mod.requestedItems = {}, {}
local itemEvents = CreateFrame("Frame")
mod.itemEvents = itemEvents

-- VARIABLES

local ITEM_ICON_UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Fade only item artwork and its overlays; the native empty slot stays opaque.
local function RevealItem(button)
    if not button.hasArtwork or button.artRevealed then return end
    button.artRevealed = true
    if ExaminerNS.UITransitions then
        for _, region in ipairs(button.itemRegions) do ExaminerNS.UITransitions.Fade(region, button, 1) end
    end
end

-- Clear only retired visuals; interaction references are cleared synchronously on selection.
local function ClearVisuals(button)
    local transitions = ExaminerNS.UITransitions
    if transitions then
        transitions.Reset(button)
        for _, region in ipairs(button.itemRegions) do transitions.Reset(region) end
    end
    button.artRevealed, button.hasArtwork = nil, nil
    button.texture:SetTexture(nil)
    button.border:Hide()
    button.level:SetText("")
    button.level:Hide()
end

--------------------------------------------------------------------------------------------------------
--                                           Module Scripts                                           --
--------------------------------------------------------------------------------------------------------

-- Initialize equipment controls and saved preferences.
function mod:OnInitialize()
    cfg = ex.cfg
end

-- Clear item contents while retaining native empty slots during player changes.
function mod:CancelItemFade()
    if not self.itemsFading then return end
    self.itemFadeSerial = (self.itemFadeSerial or 0) + 1
    self.itemsFading, self.itemRefreshPending = nil, nil
    for _, button in ipairs(self.slotBtns) do
        for _, region in ipairs(button.itemRegions) do ExaminerNS.UITransitions.Reset(region, true) end
    end
end

-- Retire only old item art; apply the latest player's preview after the short fade.
function mod:RetireItems()
    if self.itemsFading then return end
    local transitions, regions = ExaminerNS.UITransitions, {}
    for _, button in ipairs(self.slotBtns) do
        if button:IsShown() and button.hasArtwork then
            for _, region in ipairs(button.itemRegions) do regions[#regions + 1] = region end
        end
    end
    if #regions == 0 then return end
    self.itemFadeSerial = (self.itemFadeSerial or 0) + 1
    local serial, remaining = self.itemFadeSerial, #regions
    self.itemsFading = true
    for _, region in ipairs(regions) do
        transitions.FadeOut(region, function()
            if self.itemFadeSerial ~= serial then return end
            remaining = remaining - 1
            if remaining > 0 then return end
            self.itemsFading = nil
            for _, button in ipairs(self.slotBtns) do ClearVisuals(button); button:Enable() end
            if self.itemRefreshPending then
                self.itemRefreshPending = nil
                self:UpdateItemSlots(); self:ShowItemSlotButtons()
            end
        end)
    end
end

function mod:OnClearInspect()
    if ExaminerNS.UITransitions.holding and not self.npcFading then self:RetireItems()
    else self:CancelItemFade() end
    self.previewLinks, self.previewTextures, self.previewVisible = nil, nil, nil
    wipe(self.pendingItems); wipe(self.requestedItems)
    itemEvents:UnregisterAllEvents()
    for _, button in ipairs(self.slotBtns) do
        if gtt:IsOwned(button) then
            gtt:Hide()
        end
        button.link, button.realLink = nil, nil
        if self.itemsFading then button:Disable()
        elseif not self.npcFading then ClearVisuals(button); button:Enable() end
    end
    ex.tooltipSlot = nil
    if cfg then self:ShowItemSlotButtons() end
end

-- A player/NPC switch fades the existing group, with no empty-slot intermediate.
function mod:FadeOutForNPC()
    self:CancelItemFade()
    local transitions = ExaminerNS.UITransitions
    if self.npcFading or not transitions then return end
    local count = 0
    for _, button in ipairs(self.slotBtns) do if button:IsShown() then count = count + 1 end end
    if count == 0 then return end
    self.npcFading = true
    for _, button in ipairs(self.slotBtns) do
        if button:IsShown() then
            button:Disable()
            button:UnregisterEvent("MODIFIER_STATE_CHANGED")
            for _, region in ipairs(button.itemRegions) do transitions.Reset(region, true) end
            transitions.FadeOut(button, function()
                button:Hide()
                ClearVisuals(button)
                count = count - 1
                if count == 0 then self.npcFading = nil end
            end)
        end
    end
end

-- A new player/cache selection cancels callbacks that would hide their new equipment.
function mod:CancelNPCFade()
    if not self.npcFading then return end
    self.npcFading = nil
    for _, button in ipairs(self.slotBtns) do
        if ExaminerNS.UITransitions then ExaminerNS.UITransitions.Reset(button) end
        button:Hide()
    end
end

-- Read equipment data after the inspection reply.
function mod:OnInspectReady(unit, guid)
    if not ex.itemsLoaded and unit and not ex.isCacheEntry then return self:OnInspect(unit) end
    self.previewLinks, self.previewTextures, self.previewVisible = nil, nil, nil
    self:UpdateItemSlots()
    self:ShowItemSlotButtons()
end
mod.OnGearUpdated = mod.OnInspectReady

-- Show only this unit's public equipment artwork while authoritative inspection is pending.
function mod:OnInspect(unit)
    local C, count = ExaminerNS.Compat, 0
    self.previewLinks, self.previewTextures = {}, {}
    for _, button in ipairs(self.slotBtns) do
        local link = C.Text(C.Try(GetInventoryItemLink, unit, button.id))
        local texture = C.Icon(C.Try(GetInventoryItemTexture, unit, button.id))
        self.previewLinks[button.slotName] = link
        self.previewTextures[button.slotName] = texture
        if link or texture then count = count + 1 end
    end
    self.previewVisible = count > 0
    self:UpdateItemSlots()
    self:ShowItemSlotButtons()
end

-- Restore equipment details from the saved player snapshot.
function mod:OnCacheLoaded(entry, unit)
    self.previewLinks, self.previewTextures, self.previewVisible = nil, nil, nil
    self:UpdateItemSlots()
    self:ShowItemSlotButtons()
end

-- Update equipment controls when the active page changes.
function mod:OnPageChanged(module, shown)
    self:ShowItemSlotButtons()
end

-- Move the weapon row and spread the side columns into the space released by icon navigation.
function mod:OnLayoutChanged(extra)
    for index, button in ipairs(self.slotBtns) do
        if index == 17 then
            button:ClearAllPoints()
            button:SetPoint("BOTTOM", ExaminerNS.Compat.hasRangedSlot and -41.5 or -21, 27 - extra)
        elseif index > 1 and index <= 16 and index ~= 9 then
            button:ClearAllPoints()
            button:SetPoint("TOP", self.slotBtns[index - 1], "BOTTOM", 0, -4 - extra / 7)
        end
    end
end

-- Apply changed preferences to the equipment display.
function mod:OnConfigChanged(var, value)
    if var == "alwaysShowItemLevel" then
        for index, button in ipairs(self.slotBtns) do
            if value and button.link then
                button.level:Show()
            else
                button.level:Hide()
            end
        end
    end
end


--------------------------------------------------------------------------------------------------------
--                                          Helper Functions                                          --
--------------------------------------------------------------------------------------------------------

-- Show equipment controls only on pages that use them.
function mod:ShowItemSlotButtons()
    if self.npcFading then return end
    local shownMod = (cfg.activePage and ex.modules[cfg.activePage])
    local visible = ex.unitType ~= 1
        and (ex.unit or ex.isCacheEntry or ex.itemsLoaded or self.previewVisible
            or (ExaminerNS.UITransitions and ExaminerNS.UITransitions.holding))
        and (not shownMod or shownMod.showItems)
    for _, button in ipairs(self.slotBtns) do
        if visible then
            button:Show()
            RevealItem(button)
        else
            button:Hide()
        end
    end
end

-- Refresh equipment icons and item-level overlays.
function mod:UpdateItemSlots()
    if self.itemsFading then self.itemRefreshPending = true; return end
    wipe(self.pendingItems)
    for index, button in ipairs(self.slotBtns) do
        local link = (self.previewLinks or ex.info.Items)[button.slotName]
        local previewTexture = self.previewTextures and self.previewTextures[button.slotName]
        local hasArtwork = previewTexture ~= nil
        if cfg.alwaysShowItemLevel then
            button.level:Show()
        end
        button.realLink = nil
        button.link = link
        if not link then
            button.texture:SetTexture(previewTexture)
            button.border:Hide()
            button.level:SetText("")
        else
            local _, _, itemRarity, itemLevel, _, _, _, _, _, itemTexture = GetItemInfo(link)
            if itemTexture then
                hasArtwork = true
                button.texture:SetTexture(itemTexture or ITEM_ICON_UNKNOWN)
                local r, g, b = GetItemQualityColor(itemRarity and itemRarity > 0 and itemRarity or 0)
                button.border:SetVertexColor(r, g, b)
                button.border:Show()
                itemLevel = GetDetailedItemLevelInfo(link)
                button.level:SetText(itemLevel)
            else
                local id = tonumber(link:match("item:(%d+)"))
                if id then self.pendingItems[id] = true end
                button.realLink = link
                button.link = nil
                button.texture:SetTexture(previewTexture)
                button.border:Hide()
                button.level:SetText("")
            end
        end
        if not hasArtwork and button.hasArtwork then
            button.artRevealed = nil
            if ExaminerNS.UITransitions then
                for _, region in ipairs(button.itemRegions) do ExaminerNS.UITransitions.Reset(region) end
            end
        end
        button.hasArtwork = hasArtwork
        if button:IsShown() then RevealItem(button) end
    end
    if next(self.pendingItems) then
        itemEvents:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        ExaminerNS.Compat.Try(itemEvents.RegisterEvent, itemEvents, "ITEM_DATA_LOAD_RESULT")
        for id in pairs(self.pendingItems) do
            if not self.requestedItems[id] then
                self.requestedItems[id] = true
                ExaminerNS.Compat.Try(C_Item and C_Item.RequestLoadItemDataByID, id)
            end
        end
    else itemEvents:UnregisterAllEvents() end
end

-- Refresh only the current slots when requested item metadata becomes available.
itemEvents:SetScript("OnEvent", function(_, event, id, success)
    if success == false or not mod.pendingItems[id] then return end
    mod:UpdateItemSlots()
    for _, button in ipairs(mod.slotBtns) do
        if gtt:IsOwned(button) then button:GetScript("OnEnter")(button) end
    end
end)


--------------------------------------------------------------------------------------------------------
--                                         Item Slot Scripts                                          --
--------------------------------------------------------------------------------------------------------

-- Refresh item-level overlays after their relevant client event.
local function OnEvent(self, event, key, state)

    if gtt:IsOwned(self) then
        self:GetScript("OnEnter")(self)
    end
    -- TOGGLE ITEMLEVEL

    if not cfg.alwaysShowItemLevel then
        if self.link and (IsAltKeyDown()) then
            self.level:Show()
        else
            self.level:Hide()
        end
    end
end

-- Pick up an equipped item only when inspecting yourself.
local function OnDrag(self)
    if ex:ValidateUnit() and UnitIsUnit(ex.unit, "player") then
        PickupInventoryItem(self.id)
    end
end

-- Apply the selected equipment-slot shortcut.
local function OnClick(self, button)
    if CursorHasItem() then
        OnDrag(self)
    elseif self.link then
        if button == "LeftButton" then
            local editBox = ChatEdit_GetActiveWindow()
            if IsModifiedClick("DRESSUP") then
                DressUpItemLink(self.link)
            elseif (IsModifiedClick("CHATLINK")) and editBox and (editBox:IsVisible()) then
                local _, itemLink = GetItemInfo(self.link)
                editBox:Insert(itemLink)
            else
                OnDrag(self)
            end
        end
    elseif self.realLink then
        mod:UpdateItemSlots()
        self:GetScript("OnEnter")(self)
    end
end

-- Refresh visible equipment controls and required events.
local function OnShow(self)
    self:RegisterEvent("MODIFIER_STATE_CHANGED")
end

-- Unregister equipment updates while the controls are hidden.
local function OnHide(self)
    self:UnregisterEvent("MODIFIER_STATE_CHANGED")
    if not cfg.alwaysShowItemLevel then
        self.level:Hide()
    end
end


--------------------------------------------------------------------------------------------------------
--                                          Widget Creation                                           --
--------------------------------------------------------------------------------------------------------

for index, slot in ipairs(LibGearExam.Slots) do
    local btn = CreateFrame("Button", "ExaminerItemButton" .. slot, ex.model) -- Some other mods bug if you create this nameless
    btn:SetSize(37, 37)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    btn:SetScript("OnShow", OnShow)
    btn:SetScript("OnHide", OnHide)
    btn:SetScript("OnClick", OnClick)
    btn:SetScript("OnEnter", ex.ItemButton_OnEnter)
    btn:SetScript("OnLeave", ex.ItemButton_OnLeave)
    btn:SetScript("OnEvent", OnEvent)
    btn:SetScript("OnDragStart", OnDrag)
    btn:SetScript("OnReceiveDrag", OnDrag)

    btn.id, btn.bgTexture = GetInventorySlotInfo(slot)
    btn.slotName = slot

    btn.slotBackground = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    btn.slotBackground:SetAllPoints()
    btn.slotBackground:SetTexture(btn.bgTexture)

    btn.texture = btn:CreateTexture(nil, "BACKGROUND")
    btn.texture:SetAllPoints()

    btn.border = btn:CreateTexture(nil, "OVERLAY")
    btn.border:SetTexture(ExaminerNS.assetPath .. "Textures\\Border")
    btn.border:SetSize(41, 41)
    btn.border:SetPoint("CENTER")

    btn.level = ExaminerNS.Fonts.Create(btn, nil, "ARTWORK", "GameFontHighlight")
    btn.level:SetFont(GameFontHighlight:GetFont(), 12, "OUTLINE")
    btn.level:SetPoint("BOTTOM", 0, 4)
    btn.level:Hide()
    btn.itemRegions = {btn.texture, btn.border, btn.level}

    if index == 1 then
        btn:SetPoint("TOPLEFT", 4, -3)
    elseif index == 9 then
        btn:SetPoint("TOPRIGHT", -4, -3)
    elseif index == 17 then
        btn:SetPoint("BOTTOM", ExaminerNS.Compat.hasRangedSlot and -41.5 or -21, 27)
    elseif index <= 16 then
        btn:SetPoint("TOP", mod.slotBtns[index - 1], "BOTTOM", 0, -4)
    else
        btn:SetPoint("LEFT", mod.slotBtns[index - 1], "RIGHT", 5, 0)
    end

    mod.slotBtns[index] = btn
end
