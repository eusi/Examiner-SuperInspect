--------------------------------------------------------------------------------------------------------
--
-- Services/GuildIcon.lua
-- Reuses saved native guild crest components for navigation without new data requests.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local C, ex, G = ns.Compat, ns.ex, {}
ns.GuildIcon=G

-- Validate all tint components before displaying the saved guild emblem.
local function Color(value)
    return C.IsTable(value) and C.IsNumber(value.r) and C.IsNumber(value.g) and C.IsNumber(value.b)
end

-- Build the same native tabard layers as the Guild page, scaled into one icon.
local function Create(icon)
    local frame=CreateFrame("Frame",nil,icon:GetParent())
    frame:SetAllPoints(icon);frame:SetFrameLevel(icon:GetParent():GetFrameLevel()+1)
    frame:EnableMouse(false)
    frame.layers={}
    for index=1,4 do frame.layers[index]=frame:CreateTexture(nil,"ARTWORK",nil,index-1) end
    local background,border,left,right=unpack(frame.layers)
    background:SetTexture("Interface\\GuildFrame\\GuildInspect-Parts")
    background:SetTexCoord(0.23632813,0.46679688,0.70117188,0.98242188)
    border:SetTexture("Interface\\GuildFrame\\GuildInspect-Parts")
    border:SetTexCoord(0.00195313,0.23242188,0.70117188,0.98242188)
    left:SetTexCoord(1,0,0,1);right:SetTexCoord(0,1,0,1)
    icon.guildCrest=frame
    return frame
end

-- Reuse the current guild snapshot; this function never queries guild or inspect APIs.
function G.Apply(icon, token)
    local data=ex.guildData
    local crest=token=="Guild" and C.IsTable(data) and C.IsString(data.name) and C.IsTable(data.banner) and data.banner
    local valid=not ex:IsNavigationPending(token) and crest and C.Icon(crest.emblem) and Color(crest.background) and Color(crest.border) and Color(crest.color)
    local frame=icon.guildCrest
    if token=="Guild" and ns.UITransitions and ns.UITransitions.Pending(token) then
        if frame and frame:IsShown() then
            frame.iconAlpha=1
            ns.UITransitions.Alpha(frame,1)
            for _,layer in ipairs(frame.layers) do layer:SetDesaturated(false) end
            icon:SetAlpha(0)
        end
        return
    end
    if token~="Guild" or ex:IsNavigationPending(token) or not icon:IsShown() then
        if frame then
            if frame.hiddenIcon and icon:GetAlpha()==0 then icon:SetAlpha(frame.iconAlpha or 1) end
            frame.hiddenIcon=nil;frame:Hide()
        end
        return
    end
    frame=frame or Create(icon)
    local width,height=icon:GetWidth()*0.82,icon:GetHeight()
    local background,border,left,right=unpack(frame.layers)
    background:ClearAllPoints();background:SetSize(width,height);background:SetPoint("CENTER",frame,"CENTER")
    border:SetAllPoints(background)
    left:ClearAllPoints();left:SetSize(width*37.3/88,height*93.2/108)
    left:SetPoint("CENTER",background,"CENTER",-width*18.65/88,0)
    right:ClearAllPoints();right:SetSize(width*37.3/88,height*93.2/108)
    right:SetPoint("LEFT",left,"RIGHT",-width*0.75/88,0)
    background:Show();border:Show()
    left:SetShown(valid and true or false);right:SetShown(valid and true or false)
    left:SetTexture(valid and crest.emblem or nil);right:SetTexture(valid and crest.emblem or nil)
    if valid then
        for index,color in ipairs({crest.background,crest.border,crest.color,crest.color}) do
            frame.layers[index]:SetVertexColor(color.r,color.g,color.b)
        end
    else
        background:SetVertexColor(1,1,1)
        border:SetVertexColor(1,1,1)
    end
    local module=ex:GetModuleFromToken(token)
    local available=module and (module.hasData or module.inspectPending)
    frame.iconAlpha=available and 1 or 0.2
    for _,layer in ipairs(frame.layers) do layer:SetDesaturated(not available) end
    if ns.UITransitions then
        local key=table.concat({tostring(valid and crest.emblem or "empty"),
            tostring(valid and crest.background.r or 1),tostring(valid and crest.background.g or 1),tostring(valid and crest.background.b or 1),
            tostring(valid and crest.border.r or 1),tostring(valid and crest.border.g or 1),tostring(valid and crest.border.b or 1),
            tostring(valid and crest.color.r or 1),tostring(valid and crest.color.g or 1),tostring(valid and crest.color.b or 1)}, ":")
        ns.UITransitions.Fade(frame,key,frame.iconAlpha)
    else frame:SetAlpha(frame.iconAlpha) end
    icon:SetAlpha(0);frame.hiddenIcon=true;frame:Show()
end
