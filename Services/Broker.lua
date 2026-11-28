--------------------------------------------------------------------------------------------------------
--
-- Services/Broker.lua
-- Offers inspection and Settings shortcuts to broker displays and the minimap.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local ex = ns.ex
local texturePath = "Interface\\AddOns\\" .. ns.addonName .. "\\Textures\\ExaminerLogo"
local B = {icon = texturePath .. "16.tga", minimapIcon = texturePath .. "32.tga",
    fallbackIcon = texturePath .. "24.tga"}
ns.Broker = B

-- Open Settings without toggling an already selected Settings page off.
local function OpenSettings()
    if not ex.info.name then ex:DoInspect("player") end
    local config = ex:GetModuleFromToken("Config")
    if config and ex.cfg.activePage ~= config.index then ex:ShowModulePage(config.index) end
    ex:Display(true)
end

-- Share the same explicit shortcut with the optional minimap button.
function B.OnClick(_, button)
    if button == "LeftButton" then
        AzDropDown:HideMenu()
        if ex:IsVisible() then ex:Display(false)
        else ex:DoInspect(ns.Compat.IsTrue(UnitExists("target")) and "target" or "player") end
    elseif button == "RightButton" then
        AzDropDown:HideMenu()
        OpenSettings()
    end
end

function B.OnTooltipShow(tooltip)
    tooltip:AddLine("Examiner")
    tooltip:AddLine(ns.L["Left-click: inspect target or yourself; click again to close."], 1, 1, 1, true)
    tooltip:AddLine(ns.L["Right-click: open Settings."], 1, 1, 1, true)
end

--------------------------------------------------------------------------------------------------------
--                                           Inspect Launcher                                         --
--------------------------------------------------------------------------------------------------------

-- Register once, including when a display loads its broker library after Examiner.
local function Register()
    if B.object then return true end
    local broker = LibStub("LibDataBroker-1.1", true)
    if not broker then return false end
    B.object = broker:NewDataObject(ns.addonName, {
        type = "launcher",
        label = "Examiner",
        text = BINDING_NAME_EXAMINER_TARGET,
        icon = B.icon,
        OnClick = B.OnClick,
        OnTooltipShow = B.OnTooltipShow,
    })
    if B.object and B.listener then B.listener:UnregisterEvent("ADDON_LOADED") end
    return B.object ~= nil
end
B.Register = Register

-- Register independently of the optional minimap button, including on /reload updates.
function B.RegisterCompartment()
    if B.compartment then return true end
    local frame = AddonCompartmentFrame
    if not frame or type(frame.RegisterAddon) ~= "function" then return false end
    local entry = {
        text = "Examiner", icon = B.icon,
        func = function(_, input)
            local button = type(input) == "table" and input.buttonName or input
            B.OnClick(nil, type(button) == "string" and button or "LeftButton")
        end,
        funcOnEnter = function(button)
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            GameTooltip:ClearLines()
            B.OnTooltipShow(GameTooltip)
            GameTooltip:Show()
        end,
        funcOnLeave = function() GameTooltip:Hide() end,
    }
    frame:RegisterAddon(entry)
    B.compartment = entry
    return true
end

if not B.RegisterCompartment() then
    local listener = CreateFrame("Frame")
    listener:RegisterEvent("ADDON_LOADED")
    listener:RegisterEvent("PLAYER_LOGIN")
    listener:SetScript("OnEvent", function(self, event)
        if B.RegisterCompartment() or event == "PLAYER_LOGIN" then self:UnregisterAllEvents() end
    end)
end

if not Register() then
    B.listener = CreateFrame("Frame")
    B.listener:RegisterEvent("ADDON_LOADED")
    B.listener:SetScript("OnEvent", function(self)
        if Register() then self:UnregisterEvent("ADDON_LOADED") end
    end)
end
