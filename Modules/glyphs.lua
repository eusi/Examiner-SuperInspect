--------------------------------------------------------------------------------------------------------
--
-- Modules/glyphs.lua
-- Displays and optionally caches Mists glyphs inside the talent window.
--
----------------------

--------------------------------------------------------------------------------------------------------
--                                            Module Setup                                            --
--------------------------------------------------------------------------------------------------------

local _, ns = ...
if ns.blocked or not ns.Compat.isMists then
    return
end
local ex, C, G, L = ns.ex, ns.Compat, ns.Glyphs, ns.L
local parent = ex:GetModuleFromToken("Talents")
local mod = ex:CreateModule("Glyphs", L.Glyphs)
mod.help = L["Shows equipped major and minor glyphs."]
mod.toggleHelp = L["Enable/disable the Glyphs module, which shows equipped major and minor glyphs."]
mod.cacheHelp = L["Saves glyphs for later viewing. Requires Core Caching."]
mod.icon = "Interface\\Icons\\INV_Glyph_MajorWarrior"
mod.canCache = true
mod.parentToken, mod.subviewKey = "Talents", "glyphs"
mod.page = CreateFrame("Frame", nil, parent.page)
mod.page:SetSize(300, 280)
mod.page:SetPoint("TOPLEFT", 10, -42)
mod.page:SetPoint("BOTTOMRIGHT", -10, 8)
mod.page:SetFrameLevel(parent.page:GetFrameLevel() + 2)
mod.page:Hide()
mod:HasButton(false)
mod:HasData(nil)
local worker = CreateFrame("Frame")
worker:Hide()
mod.worker = worker
mod.rows, mod.requested = {}, {}
local order = { 2, 4, 6, 1, 3, 5 }
local events = { "GLYPH_ADDED", "GLYPH_REMOVED", "GLYPH_UPDATED", "SPELL_DATA_LOAD_RESULT" }

--------------------------------------------------------------------------------------------------------
--                                         Session Ownership                                          --
--------------------------------------------------------------------------------------------------------

-- Reject cached, displaced or outdated inspect sessions before reading glyph APIs.
local function Valid()
    local I, session = ns.Inspector, mod.session
    return mod:IsEnabled()
        and parent:IsEnabled()
        and session
        and session == I.active
        and not session.cached
        and session.serverReady
        and ex.unitType ~= 1
        and C.IsTrue(C.Try(UnitIsPlayer, session.unit))
        and not ex.isCacheEntry
        and I:Valid(session)
        and (ex.isSelf or I.notificationGUID == session.guid)
end

-- Stop polling and remove listeners when the inspection or module closes.
function mod:Stop()
    worker:Hide()
    for _, event in ipairs(events) do
        worker:UnregisterEvent(event)
    end
    self.session = nil
end

--------------------------------------------------------------------------------------------------------
--                                           Glyph Display                                            --
--------------------------------------------------------------------------------------------------------

-- Keep the embedded glyph rows aligned with the enlarged talent content area.
function mod:OnLayoutChanged(extra)
    self.page:SetHeight(280 + extra)
    if self.page:IsShown() then self:Draw() end
end

-- Show six glyph slots, including empty, locked and unknown entries.
function mod:Draw()
    local data = ex.glyphData or G.Empty()
    local height = mod.page:GetHeight() / 6
    for index, row in ipairs(self.rows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(index - 1) * height)
        row:SetPoint("TOPRIGHT", 0, -(index - 1) * height)
        row:SetHeight(height)
        local slot = data.slots and data.slots[order[index]] or G.Empty().slots[order[index]]
        row.slot = slot
        local text = slot.state == "empty" and L["Empty glyph slot"]
            or slot.state == "locked" and L["Locked glyph slot"]
            or slot.state == "loading" and (slot.name or L["Loading…"])
            or slot.state == "filled" and slot.name
            or L["Glyph data unavailable"]
        row.name:SetText(text or L["Glyph data unavailable"])
        row.detail:SetText(L[slot.glyphType == 1 and "Major glyph" or "Minor glyph"])
        row.icon:SetTexture(C.Icon(slot.icon) or "Interface\\Spellbook\\UI-Glyph-Rune1")
        row.icon:SetDesaturated(slot.state ~= "filled")
        row.name:SetTextColor(
            slot.state == "filled" and 1 or 0.6,
            slot.state == "filled" and 1 or 0.6,
            slot.state == "filled" and 1 or 0.6
        )
        row:Show()
    end
end

-- Refresh the owned live snapshot and poll only while metadata is missing.
function mod:Read()
    if not Valid() then
        return
    end
    ex.glyphData = G.Read(self.session.unit, ex.isSelf, self.requested)
    self:HasData(true)
    self:Draw()
    if ex.glyphData.state == "loading" then
        worker:Show()
    else
        worker:Hide()
    end
end

-- Retain known glyphs when the bounded loading interval expires.
function mod:OnDataTimeout()
    if ex.glyphData and ex.glyphData.state == "loading" then
        local known = false
        for _, slot in ipairs(ex.glyphData.slots or {}) do
            if slot.state == "loading" then
                slot.state = slot.spell and slot.name and "filled" or "unavailable"
            end
            known = known or slot.state == "filled"
        end
        ex.glyphData.state = known and "partial" or "unavailable"
    end
    worker:Hide()
    self:Draw()
end

-- Use native glyph tooltips only for the matching live player, never for cached entries.
local function Tooltip(row)
    local slot = row.slot
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local native = slot
        and slot.spell
        and Valid()
        and ex.glyphData
        and not ex.glyphData.cached
        and type(GameTooltip.SetGlyph) == "function"
        and pcall(GameTooltip.SetGlyph, GameTooltip, slot.slot, ex.glyphData.group, not ex.isSelf, ex.unit)
    if not native then
        if slot and slot.spell then
            GameTooltip:SetSpellByID(slot.spell)
        else
            GameTooltip:SetText(row.name:GetText() or "")
        end
    end
    GameTooltip:AddLine(row.detail:GetText() or "", 0.5, 0.75, 1)
    GameTooltip:Show()
end

--------------------------------------------------------------------------------------------------------
--                                           Module Events                                            --
--------------------------------------------------------------------------------------------------------

-- Clear the previous player immediately before a new inspection starts.
function mod:OnInspect()
    self:Stop()
    wipe(self.requested)
    ex.glyphData = G.Empty("loading")
    self:HasData(ex.unitType ~= 1)
    self:Draw()
end

-- Attach glyph loading to an already validated equipment inspection.
function mod:OnInspectReady()
    if not parent:IsEnabled() then
        self:Stop()
        return
    end
    local session = ns.Inspector.active
    if self.session ~= session then
        self:Stop()
        self.session, self.started, self.elapsed = session, GetTime(), 0
        for _, event in ipairs(events) do
            C.Try(worker.RegisterEvent, worker, event)
        end
    end
    self:Read()
end

-- Clear glyph data and cancel stale event delivery.
function mod:OnClearInspect()
    self:Stop()
    wipe(self.requested)
    ex.glyphData = nil
    self:HasData(nil)
    self:Draw()
end

-- Stop live callbacks when Examiner closes.
function mod:OnInspectHidden()
    self:Stop()
end

-- Save glyphs separately without replacing a complete snapshot with partial data.
function mod:OnCache(entry)
    local data = ex.glyphData
    if not self:CanCache() or not data then
        return
    end
    local previous = entry.Glyphs
    if
        data.state == "ready"
        or (
            data.state == "partial"
            and (not C.IsTable(previous) or previous.state ~= "ready" or previous.group ~= data.group)
        )
    then
        entry.Glyphs = ns.Cache.Copy(data)
        entry.Glyphs.cached = nil
    end
end

-- Restore saved glyphs, including data from older combined talent snapshots.
function mod:OnCacheLoaded(entry)
    self:Stop()
    local snapshot = C.IsTable(entry.Glyphs) and C.IsTable(entry.Glyphs.slots) and entry.Glyphs
    ex.glyphData = ns.Cache.Copy(snapshot) or G.FromTalents(entry.Talents) or G.Empty()
    ex.glyphData.cached = true
    self:HasData(true)
    self:Draw()
end

--------------------------------------------------------------------------------------------------------
--                                          Widget Creation                                           --
--------------------------------------------------------------------------------------------------------

local height = mod.page:GetHeight() / 6
for index = 1, 6 do
    local row = CreateFrame("Button", nil, mod.page)
    mod.rows[index] = row
    row:SetPoint("TOPLEFT", 0, -(index - 1) * height)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * height)
    row:SetHeight(height)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:SetScript("OnEnter", Tooltip)
    row:SetScript("OnLeave", ex.HideGTT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(30, 30)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.name = ns.Fonts.Create(row, nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
    row.name:SetPoint("RIGHT", -2, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.detail = ns.Fonts.Create(row, nil, "OVERLAY", "GameFontHighlightSmall")
    row.detail:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, 1)
    row.detail:SetTextColor(0.5, 0.75, 1)
end

-- Repaint the page when selected from a tab or the module list.
mod.page:SetScript("OnShow", function()
    mod:Draw()
end)

--------------------------------------------------------------------------------------------------------
--                                            Event Wiring                                            --
--------------------------------------------------------------------------------------------------------

-- Poll unloaded glyph metadata without issuing another inspect request.
worker:SetScript("OnUpdate", function(_, elapsed)
    if not Valid() then
        mod:Stop()
        return
    end
    if GetTime() - mod.started >= 12 then
        mod:OnDataTimeout()
        ex:CachePlayer()
        return
    end
    mod.elapsed = (mod.elapsed or 0) + elapsed
    if mod.elapsed >= 0.5 then
        mod.elapsed = 0
        mod:Read()
        ex:CachePlayer()
    end
end)

-- Refresh self changes and only the spell metadata requested by this inspection.
worker:SetScript("OnEvent", function(_, event, spell, success)
    if not Valid() then
        return
    end
    if event == "SPELL_DATA_LOAD_RESULT" then
        if not success or not C.IsNumber(spell) or not mod.requested[spell] then
            return
        end
    elseif not ex.isSelf then
        return
    end
    mod:Read()
    ex:CachePlayer()
end)
