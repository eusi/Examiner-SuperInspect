--------------------------------------------------------------------------------------------------------
--
-- Services/UITransitions.lua
-- Separates pending inspection artwork from unavailable data and fades newly revealed content.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local U, ex = {}, ns.ex
ns.UITransitions = U
local animations = {}
local batch = {}
local ticker = CreateFrame("Frame")
ticker:Hide()
U.frame = ticker
local DURATION = 0.12

-- Keep only active fades; repeated metadata updates never restart the same reveal.
function U.Fade(region, key, target)
    target = target or 1
    if region.examinerRevealKey == key then
        local active = animations[region]
        if active then active.target = target else region:SetAlpha(target) end
        return
    end
    region.examinerRevealKey = key
    animations[region] = { started = GetTime(), target = target }
    region:SetAlpha(0)
    ticker:Show()
end

function U.Alpha(region, target)
    local fade = animations[region]
    if fade then fade.target = target else region:SetAlpha(target) end
end

-- Retire a whole equipment button without revealing its empty background first.
function U.FadeOut(region, finished)
    animations[region] = { started = GetTime(), from = region:GetAlpha(), target = 0, finished = finished }
    ticker:Show()
end

function U.Reset(region, keepAlpha)
    animations[region] = nil
    region.examinerRevealKey = nil
    if not keepAlpha then region:SetAlpha(1) end
    if not next(animations) then ticker:Hide() end
end

-- Keep page backgrounds separate from fading contents and block stale controls.
function U.RegisterPage(module, regions, redraw, background)
    module.keepPageWhilePending = true
    module.transitionRegions, module.transitionRedraw, module.transitionBackgrounds = regions, redraw, background or {}
    module.page:HookScript("OnHide", function() U.ResetPage(module) end)
end

function U.ResetPage(module)
    module.transitionSerial = (module.transitionSerial or 0) + 1
    module.transitionPending, module.transitionOut, module.transitionReady = nil, nil, nil
    for _, region in ipairs(module.transitionRegions or {}) do U.Reset(region) end
    for _, region in ipairs(module.transitionBackgrounds or {}) do U.Reset(region) end
    if module.transitionShield then module.transitionShield:Hide() end
end

-- Embedded views follow their selected parent instead of owning a main tab.
function U.IsSelected(module)
    if module:IsShown() then return true end
    local parent = module.parentToken and ex:GetModuleFromToken(module.parentToken)
    return parent and parent:IsShown() and module.page:IsShown()
end

local function BeginPage(module)
    module.transitionSerial = (module.transitionSerial or 0) + 1
    local serial = module.transitionSerial
    module.transitionPending, module.transitionReady = true, nil
    local shield = module.transitionShield
    if not shield then
        shield = CreateFrame("Button", nil, module.page)
        shield:SetPoint("TOPLEFT", 0, 40); shield:SetPoint("BOTTOMRIGHT")
        shield:SetFrameLevel(module.page:GetFrameLevel() + 50)
        shield:EnableMouse(true); shield:EnableMouseWheel(true)
        shield:SetScript("OnMouseWheel", function() end)
        module.transitionShield = shield
    end
    shield:Show(); GameTooltip:Hide()
    local remaining = 0
    for _, region in ipairs(module.transitionRegions) do
        U.Reset(region, true)
        if region:GetAlpha() > 0 then remaining = remaining + 1 end
    end
    module.transitionOut = remaining > 0 or nil
    for _, region in ipairs(module.transitionRegions) do
        if region:GetAlpha() > 0 then
            U.FadeOut(region, function()
                if module.transitionSerial ~= serial then return end
                remaining = remaining - 1
                if remaining == 0 then
                    module.transitionOut = nil
                    if module.transitionReady then module.transitionRedraw() end
                end
            end)
        end
    end
end

-- Render only after old contents have faded, using the latest current-player data.
function U.DeferPage(module, ready, unavailable)
    if not module.transitionPending then return false end
    if unavailable then U.ResetPage(module); return false end
    if not ready then return true end
    if module.transitionOut then module.transitionReady = true; return true end
    module.transitionPending, module.transitionReady = nil, nil
    for _, region in ipairs(module.transitionRegions) do U.Fade(region, module.transitionSerial, 1) end
    for _, region in ipairs(module.transitionBackgrounds) do U.Fade(region, module.transitionSerial, 1) end
    module.transitionShield:Hide()
    return false
end

ticker:SetScript("OnUpdate", function()
    local now = GetTime()
    local finished
    -- Alpha hooks can cancel/add fades; never keep a live hash iterator across them.
    local count = 0
    for region, fade in pairs(animations) do
        count = count + 2
        batch[count - 1], batch[count] = region, fade
    end
    for index = 1, count, 2 do
        local region, fade = batch[index], batch[index + 1]
        batch[index], batch[index + 1] = nil, nil
        if animations[region] == fade then
            local fraction = math.min(1, math.max(0, (now - fade.started) / DURATION))
            local from = fade.from or 0
            region:SetAlpha(from + (fade.target - from) * fraction * fraction * (3 - 2 * fraction))
            if fraction >= 1 and animations[region] == fade then
                animations[region] = nil
                if fade.finished then
                    finished = finished or {}
                    finished[#finished + 1] = fade.finished
                end
            end
        end
    end
    if finished then for _, callback in ipairs(finished) do callback() end end
    if not next(animations) then ticker:Hide() end
end)

-- Retain rendered artwork only, never the previous player's inspect data or controls.
function U.Begin(hold)
    U.holding = hold or nil
    for _, module in ipairs(ex.modules) do
        module.inspectPending = hold and (module.hasButton or module.transitionRegions) and module.token ~= "More" or nil
    end
    for _, module in ipairs(ex.modules) do
        if module.transitionRegions then
            if module.transitionPrepare then module.transitionPrepare() end
            if hold and U.IsSelected(module) and module.page:IsShown() and (module.hasData or module.transitionPending) then
                BeginPage(module)
            else U.ResetPage(module) end
        end
    end
end

function U.Pending(token)
    local module = ex:GetModuleFromToken(token)
    return module and (module.inspectPending or (U.holding and ex:IsNavigationPending(token)))
end

-- Auxiliary loaders have their own replies and must not be called unavailable merely on request.
local function Loading(module, session)
    if not session or not session.serverReady then return session and not session.done end
    if module.token == "PvP" then return ex.pvpData and ex.pvpData.state == "loading" end
    if module.token == "Talents" then return ex.talentData and ex.talentData.state == "loading" end
    if module.token == "Professions" then return module.state == "queued" or module.state == "waiting" end
    if module.token == "Achievements" then return module.state == "waiting" or module.state == "building" end
    if module.token == "Glyphs" then return ex.glyphData and ex.glyphData.state == "loading" end
    if module.token == "Stats" or module.token == "Equipment" then return ex.gear and ex.gear.state == "loading" end
    return false
end

function U.Resolve(module, value, force)
    if not module.inspectPending then return end
    local session = ns.Inspector and ns.Inspector.active
    if module.transitionPending and not value then
        if force or (session and session.done and not module.transitionReady and not Loading(module, session)) then
            U.ResetPage(module)
            if module.page then module.page:Hide() end
        else return end
    end
    if value or force or (session and not session.refreshing and not Loading(module, session)) then
        module.inspectPending = nil
    end
end

function U.ResolveAll(force)
    for _, module in ipairs(ex.modules) do U.Resolve(module, module.hasData, force) end
    if ex.cfg then ns.Appearance.UpdateSelection() end
end
