--------------------------------------------------------------------------------------------------------
--
-- Services/Glyphs.lua
-- Reads Mists glyph slots and restores glyphs from older talent snapshots.
--
----------------------

--------------------------------------------------------------------------------------------------------
--                                            Module Setup                                            --
--------------------------------------------------------------------------------------------------------

local _, ns = ...
if ns.blocked or not ns.Compat.isMists then
    return
end
local C, G = ns.Compat, {}
ns.Glyphs = G

--------------------------------------------------------------------------------------------------------
--                                            Glyph Slots                                             --
--------------------------------------------------------------------------------------------------------

-- Create six unknown slots using Mists' alternating minor/major socket order.
function G.Empty(state)
    local data = { state = state or "unavailable", slots = {}, time = time() }
    for index = 1, 6 do
        data.slots[index] = { slot = index, glyphType = index % 2 == 0 and 1 or 2, state = "unavailable" }
    end
    return data
end

-- Read glyphs only from the requested unit and talent group.
function G.Read(unit, isSelf, requested)
    local data = G.Empty("loading")
    local api = C_SpecializationInfo or {}
    data.group = C.Number(C.Try(api.GetActiveSpecGroup or GetActiveSpecGroup, not isSelf), 1)
    if type(GetGlyphSocketInfo) ~= "function" then
        data.state = "unavailable"
        return data
    end
    local pending = false
    for index, slot in ipairs(data.slots) do
        local enabled, kind, _, spell, icon, glyphID =
            C.Try(GetGlyphSocketInfo, index, data.group, not isSelf, unit)
        enabled = C.Safe(enabled)
        if C.IsNumber(kind) and (kind == 1 or kind == 2) then
            slot.glyphType = kind
        end
        if C.IsTrue(enabled) or (C.IsNumber(enabled) and enabled == 1) then
            slot.spell = C.Number(spell)
            slot.glyphID = C.Number(glyphID)
            if slot.spell and slot.spell > 0 then
                local info = C.Try(C_Spell and C_Spell.GetSpellInfo, slot.spell)
                slot.name = C.IsTable(info) and C.Text(info.name) or C.Text(C.Try(GetSpellInfo, slot.spell))
                if slot.name == "" then
                    slot.name = nil
                end
                slot.icon = C.Icon(icon)
                    or (C.IsTable(info) and C.Icon(info.iconID))
                    or C.Icon(C.Try(C.GetSpellTexture, slot.spell))
                slot.state = slot.name and slot.icon and "filled" or "loading"
                if slot.state == "loading" and requested then
                    local previous = requested[slot.spell]
                    local now = GetTime()
                    if not previous or (previous.count < 2 and now - previous.time >= 2) then
                        requested[slot.spell] = { count = previous and previous.count + 1 or 1, time = now }
                        C.Try(C_Spell and C_Spell.RequestLoadSpellData, slot.spell)
                    end
                end
            else
                slot.spell, slot.glyphID, slot.state = nil, nil, "empty"
            end
        elseif enabled == false or (C.IsNumber(enabled) and enabled == 0) then
            slot.state = "locked"
        end
        pending = pending or slot.state == "loading" or slot.state == "unavailable"
    end
    data.state = pending and "loading" or "ready"
    return data
end

--------------------------------------------------------------------------------------------------------
--                                          Legacy Snapshots                                          --
--------------------------------------------------------------------------------------------------------

-- Recover equipped glyphs from a previous combined talent cache without live queries.
function G.FromTalents(snapshot)
    if not C.IsTable(snapshot) or snapshot.kind ~= "mists" then
        return
    end
    local data = G.Empty("partial")
    local found = false
    data.group = snapshot.group
    for _, tree in ipairs(snapshot.extraTrees or {}) do
        if tree.role == "glyphs" then
            for _, node in ipairs(tree.nodes or {}) do
                local index = C.Number(node.glyphSlot)
                local entry = node.entry
                if index and data.slots[index] and C.IsTable(entry) and C.Number(entry.spell) then
                    data.slots[index] = {
                        slot = index,
                        glyphType = C.Number(node.glyphType) or data.slots[index].glyphType,
                        spell = entry.spell,
                        name = C.Text(entry.name),
                        icon = C.Icon(entry.icon),
                        state = "filled",
                    }
                    found = true
                end
            end
        end
    end
    return found and data or nil
end
