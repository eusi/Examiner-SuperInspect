--------------------------------------------------------------------------------------------------------
--
-- Services/Minimap.lua
-- Positions the optional inspection launcher around the advertised minimap shape.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local ex, C, M = ns.ex, ns.Compat, {}
ns.Minimap = M
-- Same established quadrant convention used by the SNP launcher and broker icons.
local corners = {
    ROUND={true,true,true,true}, SQUARE={false,false,false,false},
    ["CORNER-TOPLEFT"]={false,false,false,true}, ["CORNER-TOPRIGHT"]={false,false,true,false},
    ["CORNER-BOTTOMLEFT"]={false,true,false,false}, ["CORNER-BOTTOMRIGHT"]={true,false,false,false},
    ["SIDE-LEFT"]={false,true,false,true}, ["SIDE-RIGHT"]={true,false,true,false},
    ["SIDE-TOP"]={false,false,true,true}, ["SIDE-BOTTOM"]={true,true,false,false},
    ["TRICORNER-TOPLEFT"]={false,true,true,true}, ["TRICORNER-TOPRIGHT"]={true,false,true,true},
    ["TRICORNER-BOTTOMLEFT"]={true,true,false,true}, ["TRICORNER-BOTTOMRIGHT"]={true,true,true,false},
}

-- Map a saved direction onto round, rectangular or mixed minimap edges.
function M.Offset(angle, width, height, shape)
    local x, y = math.cos(math.rad(angle)), math.sin(math.rad(angle))
    local quadrant = 1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)
    local rounded = (corners[shape] or corners.ROUND)[quadrant]
    local factor = rounded and 1 or 1/math.max(math.abs(x), math.abs(y))
    return x*(width/2+8)*factor, y*(height/2+8)*factor
end

local lastWidth, lastHeight, lastShape, lastMapScale, lastButtonScale
local elapsedTotal = 0
-- A button collector owns layout and dragging after moving the launcher into its container.
local function OnMinimap()
    return M.frame and M.frame:GetParent() == Minimap
end

local function Geometry()
    local width, height = C.Number(Minimap:GetWidth(), 0), C.Number(Minimap:GetHeight(), 0)
    local mapScale, buttonScale = C.Number(Minimap:GetEffectiveScale(), 0), C.Number(M.frame:GetEffectiveScale(), 0)
    if width <= 0 or height <= 0 or mapScale <= 0 or buttonScale <= 0 then return end
    return width, height, mapScale, buttonScale, C.Text(C.Try(GetMinimapShape), "ROUND")
end

-- Convert map geometry into button coordinates only while we own its layout.
function M.Position()
    if M.library or not OnMinimap() or not ex.cfg then return end
    local width, height, mapScale, buttonScale, shape = Geometry()
    if not width then return end
    local angle = C.Number(ex.cfg.minimapAngle, 225)
    if angle ~= angle or math.abs(angle) == math.huge then angle = 225 end
    ex.cfg.minimapAngle = angle % 360
    local x, y = M.Offset(ex.cfg.minimapAngle, width*mapScale/buttonScale, height*mapScale/buttonScale, shape)
    lastWidth, lastHeight, lastMapScale, lastButtonScale, lastShape = width, height, mapScale, buttonScale, shape
    M.frame:ClearAllPoints()
    M.frame:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Reposition only after visible shape, size or scale changes, at most twice a second.
local function Watch(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 0.5 then return end
    elapsedTotal = 0
    if not OnMinimap() then return end
    local width, height, mapScale, buttonScale, shape = Geometry()
    if width ~= lastWidth or height ~= lastHeight or shape ~= lastShape
        or mapScale ~= lastMapScale or buttonScale ~= lastButtonScale then M.Position() end
end

-- Normalize against both radii so dragging also follows rectangular and scaled maps.
local function Drag()
    if not OnMinimap() then return end
    local width, height, mapScale, buttonScale = Geometry()
    if not width then return end
    local x, y = GetCursorPosition()
    local cx, cy = Minimap:GetCenter()
    if not C.IsNumber(x) or not C.IsNumber(y) or not C.IsNumber(cx) or not C.IsNumber(cy) then return end
    local dx = (x-cx*mapScale)/(width*mapScale/2+8*buttonScale)
    local dy = (y-cy*mapScale)/(height*mapScale/2+8*buttonScale)
    ex.cfg.minimapAngle = math.deg(math.atan2(dy, dx))
    M.Position()
end

local function Create()
    local button = CreateFrame("Button", ns.addonName .. "MinimapButton", Minimap)
    M.frame = button
    button:Hide()
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel()+10)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(25, 25); background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(20, 20); button.icon:SetPoint("CENTER", 0, 1)
    -- The authored 24px image occupies a 24px corner of a native 32px texture.
    button.icon:SetTexture(ns.Broker.fallbackIcon)
    button.icon:SetTexCoord(0, 0.75, 0, 0.75)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54); border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnShow", function(self)
        elapsedTotal = 0; M.Position(); self:SetScript("OnUpdate", Watch)
    end)
    button:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil); self.dragged = nil
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    button:SetScript("OnMouseDown", function(self) self.dragged = nil end)
    button:SetScript("OnDragStart", function(self)
        self.dragged = true
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        self:SetScript("OnUpdate", Drag)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", ex.cfg.showMinimapButton and self:IsShown() and Watch or nil)
        M.Position()
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if not self.dragged then ns.Broker.OnClick(self, mouseButton) end
        self.dragged = nil
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:ClearLines()
        ns.Broker.OnTooltipShow(GameTooltip)
        GameTooltip:AddLine(ns.L["Drag to move."], 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", ex.HideGTT)
end

-- Prefer the shared registry so collectors can retain our label, tooltip and visibility.
local function RegisterLibrary()
    if M.library then return true end
    local library = LibStub("LibDBIcon-1.0", true)
    if not library or not ns.Broker.Register() then return false end
    local saved = ex.cfg.minimapLauncher
    if type(saved) ~= "table" then
        saved = {minimapPos = ex.cfg.minimapAngle or 225}
        ex.cfg.minimapLauncher = saved
    end
    local angle = C.Number(saved.minimapPos, 225)
    saved.minimapPos = angle == angle and math.abs(angle) < math.huge and angle % 360 or 225
    saved.hide = not ex.cfg.showMinimapButton
    -- Broker owns the native addon-list entry, so the library must not add a duplicate.
    saved.showInCompartment = false
    library:Register(ns.addonName, ns.Broker.object, saved)
    local button = library:GetMinimapButton(ns.addonName)
    if not button then return false end
    -- Keep the library's size, positioning and pressed-state crop; use the larger source.
    if library.SetButtonIcon then library:SetButtonIcon(ns.addonName, ns.Broker.minimapIcon)
    elseif button.icon then button.icon:SetTexture(ns.Broker.minimapIcon) end
    -- Optically center the supplied magnifier inside the native contour.
    if button.icon then
        local point, relative, relativePoint, x, y = button.icon:GetPoint(1)
        if point then
            button.icon:ClearAllPoints()
            button.icon:SetPoint(point, relative, relativePoint, x or 0, (y or 0)+1)
        end
    end
    if M.frame then M.frame:Hide() end
    M.frame, M.library = button, library
    return true
end

-- Do not create a button or run a watcher while the saved option is off.
function M.Update()
    local enabled = ex.cfg and ex.cfg.showMinimapButton == true
    if enabled then RegisterLibrary() end
    if M.library then
        ex.cfg.minimapLauncher.hide = not enabled
        if enabled then M.library:Show(ns.addonName) else M.library:Hide(ns.addonName) end
    end
    -- Libraries may load after Examiner, including when a launcher is enabled mid-session.
    if enabled and not M.library and not M.listener then
        M.listener = CreateFrame("Frame")
        M.listener:SetScript("OnEvent", function() M.Update() end)
    end
    if M.listener then
        if enabled and not M.library then M.listener:RegisterEvent("ADDON_LOADED")
        else M.listener:UnregisterEvent("ADDON_LOADED") end
    end
    if enabled and Minimap and not M.frame then Create() end
    if M.frame and not M.library then M.frame:SetShown(enabled and Minimap ~= nil) end
end
