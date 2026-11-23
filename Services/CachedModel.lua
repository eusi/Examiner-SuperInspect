--------------------------------------------------------------------------------------------------------
--
-- Services/CachedModel.lua
-- Displays a native closed chest and the saved inspection time for cached players.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local C, ex, M = ns.Compat, ns.ex, {}
ns.CachedModel = M
-- These native assets were read from every installed supported client family.
local models = {219372, 199748}
local captions = CreateFrame("Frame",nil,ex.model)
captions:SetAllPoints(ex.model)
captions:SetFrameLevel(ex.model:GetFrameLevel())
captions:EnableMouse(false)
captions:Hide()
M.captions = captions
local label = ns.Fonts.Create(captions,nil,"OVERLAY","GameFontNormal")
local saved = ns.Fonts.Create(captions,nil,"OVERLAY","GameFontHighlightSmall")
local stamp = ns.Fonts.Create(captions,nil,"OVERLAY","GameFontHighlightSmall")
M.label, M.saved, M.stamp = label, saved, stamp
for index,text in ipairs({label,saved,stamp}) do
    text:SetWidth(270);text:SetWordWrap(true);text:SetJustifyH("CENTER");text:Hide()
end

--------------------------------------------------------------------------------------------------------
--                                           Cached Display                                           --
--------------------------------------------------------------------------------------------------------

-- Keep missing/legacy timestamps distinct from a real saved inspection date.
function M.Timestamp(value)
    if not C.IsNumber(value) or value<=0 or value==math.huge then return "—" end
    return C.Text(C.Try(date,ns.L["%d %b %Y · %H:%M"],value),"—")
end

-- Keep cache identity in the background below the name bar, without reserving page space.
function M.Layout()
    local top=8
    for _,text in ipairs({label,saved,stamp}) do
        text:SetWidth(math.max(1,ex.model:GetWidth()-90))
        local height=math.max(10,math.ceil(text:GetStringHeight()))
        text:SetHeight(height);text:ClearAllPoints()
        text:SetPoint("TOP",ex.model,"TOP",0,-top)
        top=top+height+2
    end
end

-- Stop pending loads and remove the cache captions before live inspection.
function M.Clear()
    local active=M.index~=nil
    M.pending=nil;M.index=nil;M.loaded=nil
    M.zoom=nil
    M.chestPosition=nil;M.chestFacing=nil
    captions:Hide()
    for _,text in ipairs({label,saved,stamp}) do text:Hide() end
    if active then
        ex.model:SetPaused(false)
        ex.model:SetCamera(0)
        ex.model:SetModelScale(M.scale or 1)
        local position=M.position or {}
        ex.model:SetPosition(C.Number(position[1],0),C.Number(position[2],0),C.Number(position[3],0))
        ex.model:SetFacing(M.facing or 0)
        local translation=M.translation or {}
        ex.model:SetViewTranslation(C.Number(translation[1],0),C.Number(translation[2],0))
        M.position=nil;M.facing=nil;M.scale=nil;M.translation=nil
    end
end

-- Move along the viewing direction so zoom keeps the chest centered.
local function PositionCamera()
    local titan=M.index==2
    -- The front faces positive X; keep eye and target on the same horizontal centerline.
    local tx,tz=0,titan and 1.33 or 0.9
    local base=titan and 17.5 or 8.7
    local distance=math.max(base*0.3,math.min(base*3,base+(M.zoom or 0)))
    M.zoom=distance-base
    ex.model:SetCameraPosition(tx+distance,0,tz)
    ex.model:SetCameraTarget(tx,0,tz)
end

-- Configure a centered camera using the verified native chest bounds.
local function FrameChest()
    ex.model:SetModelScale(1)
    local position=M.chestPosition or {}
    ex.model:SetPosition(position[1] or 0,position[2] or 0,position[3] or 0)
    ex.model:SetFacing(M.chestFacing or 0)
    ex.model:MakeCurrentCameraCustom()
    PositionCamera()
    ex.model:SetViewTranslation(0,42)
    ex.model:SetSequence(0)
    ex.model:SetSequenceTime(0,0)
    ex.model:SetPaused(true)
end

-- Retain native drag changes when a content page temporarily hides the model.
function M.SaveTransform()
    local position=M.chestPosition or {}
    position[1],position[2],position[3]=ex.model:GetPosition()
    M.chestPosition=position
    M.chestFacing=ex.model:GetFacing()
end

-- Match the character model's wheel direction and faster Control-wheel steps.
function M.Zoom(delta)
    if not ex.isCacheEntry or not M.loaded or M.pending or delta==0 then return end
    local step=IsControlKeyDown() and 2 or 0.7
    M.zoom=(M.zoom or 0)+(delta>0 and -step or step)
    PositionCamera()
end

-- Try the verified legacy chest first; the native titan chest is the fallback.
local function Load(index)
    M.index=index;M.pending=0;M.elapsed=0
    if M.loaded==models[index] and C.Try(ex.model.GetModelFileID,ex.model)==models[index] then
        FrameChest();M.pending=nil;return
    end
    -- Drop the previous unit binding before assigning a non-character model.
    ex.model:ClearModel()
    local ok=pcall(ex.model.SetModel,ex.model,models[index])
    if not ok then
        if index<#models then Load(index+1) else M.pending=nil;ns.Record("cache-model","native chest unavailable") end
    end
end

-- Show cache identity without reading any live unit or replacing its saved time.
function M.Show(restore)
    if not M.index then
        M.position={C.Try(ex.model.GetPosition,ex.model)}
        M.facing=C.Number(C.Try(ex.model.GetFacing,ex.model),0)
        M.scale=C.Number(C.Try(ex.model.GetModelScale,ex.model),1)
        M.translation={C.Try(ex.model.GetViewTranslation,ex.model)}
    end
    ex.model.isRotating,ex.model.isPanning=nil,nil
    ex.model.cleared=nil
    label:SetText(ns.L["Cached character"]);saved:SetText(ns.L["Saved"])
    stamp:SetText(M.Timestamp(ex.info.time))
    M.Layout()
    captions:Show()
    for _,text in ipairs({label,saved,stamp}) do text:Show() end
    if restore then M.loaded=nil end
    Load(1)
end

-- Poll only while a model is loading; no recurring cache worker remains afterwards.
function M.Tick(elapsed)
    if not M.pending then return end
    if not ex.isCacheEntry then M.Clear();return end
    M.pending=M.pending+elapsed;M.elapsed=M.elapsed+elapsed
    if M.elapsed<0.05 then return end
    M.elapsed=0
    if M.pending>=2 then
        if M.index<#models then Load(M.index+1) else M.pending=nil;ns.Record("cache-model","native chest load timed out") end
    end
end

-- File IDs can be assigned before asynchronous geometry loading has finished.
ex.model:HookScript("OnModelLoaded",function(self)
    if ex.isCacheEntry and M.index and C.Try(self.GetModelFileID,self)==models[M.index] then
        FrameChest();M.loaded=models[M.index];M.pending=nil
    end
end)
