--------------------------------------------------------------------------------------------------------
--
-- Services/Fonts.lua
-- Applies the selected font to Examiner text while protecting shared UI controls.
--
----------------------

--------------------------------------------------------------------------------------------------------
--                                      Variables And Constants                                       --
--------------------------------------------------------------------------------------------------------

local _, ns = ...
if ns.blocked then
    return
end
local F = { records = setmetatable({}, { __mode = "k" }) }
ns.Fonts = F
local locale = GetLocale()
local latin = locale ~= "ruRU" and locale ~= "koKR" and locale ~= "zhCN" and locale ~= "zhTW"
F.choices = { { "default", ns.L["Default"] } }
if latin then
    F.choices[#F.choices + 1] = { "friz", "Friz Quadrata", "Fonts\\FRIZQT__.TTF" }
    F.choices[#F.choices + 1] = { "arial", "Arial Narrow", "Fonts\\ARIALN.TTF" }
    F.choices[#F.choices + 1] = { "morpheus", "Morpheus", "Fonts\\MORPHEUS.TTF" }
    F.choices[#F.choices + 1] = { "skurri", "Skurri", "Fonts\\SKURRI.TTF" }
end
local nativeChoices = F.choices

--------------------------------------------------------------------------------------------------------
--                                       SharedMedia Integration                                      --
--------------------------------------------------------------------------------------------------------

-- Connect once when another addon provides the optional library.
function F.ConnectSharedMedia()
    local media = LibStub("LibSharedMedia-3.0", true)
    if not media or type(media.List) ~= "function" or type(media.Fetch) ~= "function" then
        return false
    end
    if F.media == media then
        return false
    end
    F.media = media
    if type(media.RegisterCallback) == "function" then
        media.RegisterCallback(F, "LibSharedMedia_Registered", "OnSharedMediaChanged")
        media.RegisterCallback(F, "LibSharedMedia_SetGlobal", "OnSharedMediaChanged")
    end
    return true
end

-- Read a registered face without substituting the library's default font.
function F.SharedPath(name, registeredOnly)
    local media = F.media
    if not media then
        return
    end
    local registry = type(media.HashTable) == "function" and media:HashTable("font")
    local path
    if type(registry) == "table" then
        path = registry[name]
        if not path then
            return
        end
    elseif type(media.IsValid) == "function" and not media:IsValid("font", name) then
        return
    end
    if not registeredOnly or not path then
        path = media:Fetch("font", name, true)
    end
    if type(path) == "string" and path ~= "" then
        return path
    end
end

-- Normalize paths only for duplicate detection, preserving original file spelling.
local function FontKey(path)
    return path:lower():gsub("/", "\\")
end

-- Merge locale-compatible library fonts with the native choices without duplicates.
function F.GetChoices()
    F.ConnectSharedMedia()
    local choices, paths, aliases = {}, {}, {}
    for _, choice in ipairs(nativeChoices) do
        choices[#choices + 1] = choice
        if choice[3] then
            paths[FontKey(choice[3])] = choice[1]
        end
    end
    if F.media then
        for _, name in ipairs(F.media:List("font")) do
            local path = F.SharedPath(name, true)
            if path then
                local id, key = "lsm:" .. name, FontKey(path)
                if paths[key] then
                    aliases[id] = paths[key]
                else
                    choices[#choices + 1] = { id, name, path }
                    paths[key] = id
                end
            end
        end
    end
    local selected = ns.ex and ns.ex.cfg and ns.ex.cfg.font
    if
        type(selected) == "string"
        and selected:sub(1, 4) == "lsm:"
        and not F.SharedPath(selected:sub(5), true)
    then
        choices[#choices + 1] = { selected, selected:sub(5) .. " — " .. ns.L["Not available"], nil, true }
    end
    F.choices, F.aliases = choices, aliases
    return choices
end

-- Retain unavailable SharedMedia selections so their providers can load later.
function F.NormalizeSelection(cfg)
    local selected = cfg.font
    if type(selected) == "string" and selected:sub(1, 4) == "lsm:" and #selected > 4 then
        F.GetChoices()
        return
    end
    for _, choice in ipairs(nativeChoices) do
        if choice[1] == selected then
            return
        end
    end
    cfg.font = "default"
end

-- Mark an aliased library font on its single visible native entry.
function F.IsSelected(id, selected)
    return id == selected or (F.aliases and F.aliases[selected] == id)
end

-- Reapply a selected shared face when its provider or global override changes.
function F:OnSharedMediaChanged(event, mediaType, name)
    if mediaType ~= "font" then
        return
    end
    self.GetChoices()
    local ex = ns.ex
    local selected = ex and ex.cfg and ex.cfg.font
    if type(selected) ~= "string" or selected:sub(1, 4) ~= "lsm:" then
        return
    end
    if event == "LibSharedMedia_Registered" and name ~= selected:sub(5) then
        return
    end
    ex:SendModuleEvent("OnConfigChanged", "font", selected)
    ex:RefreshModuleButtons()
    local stats = ex:GetModuleFromToken("Stats")
    if stats and stats:IsEnabled() then
        stats:BuildShownList()
    end
end

--------------------------------------------------------------------------------------------------------
--                                           Font Selection                                           --
--------------------------------------------------------------------------------------------------------

-- Limit shared-control styling to controls currently owned by Examiner.
function F.IsOwned(frame)
    while frame do
        if frame == ns.ex then
            return true
        end
        frame = frame.GetParent and frame:GetParent()
    end
    return false
end

-- Resolve the selected face with a script-compatible fallback.
function F.Resolve(original, text)
    if text and not F.IsOwned(text) then
        return original
    end
    if text and text.examinerFontPreview then return text.examinerFontPreview end
    local selected = ns.ex and ns.ex.cfg and ns.ex.cfg.font
    if type(selected) == "string" and selected:sub(1, 4) == "lsm:" then
        F.ConnectSharedMedia()
        return F.SharedPath(selected:sub(5)) or original
    end
    for _, choice in ipairs(F.choices) do
        if choice[1] == selected then
            return choice[3] or original
        end
    end
    return original
end

--------------------------------------------------------------------------------------------------------
--                                          Font Application                                          --
--------------------------------------------------------------------------------------------------------

-- Apply the chosen face while preserving text size and outline.
function F.Apply(text)
    if not text or type(text.GetFont) ~= "function" or type(text.SetFont) ~= "function" then
        return
    end
    local face, size, flags = text:GetFont()
    if not face or not size then
        return
    end
    local record = F.records[text]
    if not record then
        record = { original = face }
        F.records[text] = record
        if type(hooksecurefunc) == "function" then
            -- Preserve the chosen face after changing text size or outline.
            hooksecurefunc(text, "SetFont", function()
                if not record.applying then
                    F.Apply(text)
                end
            end)
            -- Preserve the chosen face after assigning a font object.
            hooksecurefunc(text, "SetFontObject", function(_, fontObject)
                if not record.applying then
                    if type(fontObject) == "string" then
                        fontObject = _G[fontObject]
                    end
                    if fontObject and type(fontObject.GetFont) == "function" then
                        record.original = select(1, fontObject:GetFont()) or record.original
                    end
                    F.Apply(text)
                end
            end)
        end
    end
    local chosen = F.Resolve(record.original, text)
    if face ~= chosen then
        record.applying = true
        local ok, result = pcall(text.SetFont, text, chosen, size, flags)
        if not ok or result == false then
            pcall(text.SetFont, text, record.original, size, flags)
        end
        record.applying = nil
    end
end

--------------------------------------------------------------------------------------------------------
--                                     Shared Menus And Tooltips                                      --
--------------------------------------------------------------------------------------------------------

-- Restore the tooltip before Blizzard or another addon reuses its regions.
function F.RestoreTooltip()
    for text, saved in pairs(F.tooltipFonts or {}) do
        pcall(text.SetFont, text, unpack(saved))
    end
    F.tooltipFonts = nil
end

-- Style Examiner descriptions while keeping native item and spell tooltips unchanged.
function F.StyleTooltip()
    F.RestoreTooltip()
    local tooltip = GameTooltip
    if not tooltip or not F.IsOwned(tooltip:GetOwner()) then
        return
    end
    if tooltip.GetItem then
        local _, link = tooltip:GetItem()
        if ns.Compat.IsSecret(link) or ns.Compat.IsString(link) then
            return
        end
    end
    if tooltip.GetSpell then
        local _, spell = tooltip:GetSpell()
        if ns.Compat.IsSecret(spell) or ns.Compat.IsNumber(spell) then
            return
        end
    end
    F.tooltipFonts = {}
    for _, text in ipairs({ tooltip:GetRegions() }) do
        if text.IsObjectType and text:IsObjectType("FontString") then
            local face, size, flags = text:GetFont()
            if face and size then
                F.tooltipFonts[text] = { face, size, flags }
                pcall(text.SetFont, text, F.Resolve(face), size, flags)
            end
        end
    end
end

if type(hooksecurefunc) == "function" then
    -- Refresh the shared menu after it has been assigned to its current owner.
    hooksecurefunc(AzDropDown, "ToggleMenu", function()
        local scroll = _G["AzDropDownScroll" .. AzDropDown.vers]
        if scroll then
            F.Refresh(scroll:GetParent())
        end
    end)
    -- Apply the addon font only to its descriptive tooltips.
    hooksecurefunc(GameTooltip, "Show", F.StyleTooltip)
    -- Return tooltip regions to their native font when the tooltip closes.
    hooksecurefunc(GameTooltip, "Hide", F.RestoreTooltip)
end

--------------------------------------------------------------------------------------------------------
--                                           Text Creation                                            --
--------------------------------------------------------------------------------------------------------

-- Register newly created Examiner text for font changes.
function F.Create(parent, ...)
    local text = parent:CreateFontString(...)
    F.Apply(text)
    return text
end

--------------------------------------------------------------------------------------------------------
--                                           Owned Controls                                           --
--------------------------------------------------------------------------------------------------------

-- Apply the font to owned regions, template labels and edit boxes.
function F.Refresh(frame)
    if not frame then
        return
    end
    if frame.IsObjectType and (frame:IsObjectType("FontString") or frame:IsObjectType("EditBox")) then
        F.Apply(frame)
    end
    if frame.GetFontString then
        F.Apply(frame:GetFontString())
    end
    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("FontString") then
                F.Apply(region)
            end
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            F.Refresh(child)
        end
    end
end

local mediaListener = CreateFrame("Frame")
F.mediaListener = mediaListener
mediaListener:RegisterEvent("ADDON_LOADED")
-- Discover libraries embedded in addons that load after Examiner.
mediaListener:SetScript("OnEvent", function()
    if F.ConnectSharedMedia() then
        F:OnSharedMediaChanged(nil, "font")
    end
end)
F.GetChoices()
