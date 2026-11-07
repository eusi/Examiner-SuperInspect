--------------------------------------------------------------------------------------------------------
--
-- Services/ProgressBars.lua
-- Creates consistent framed progress bars with centered value labels.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local C, B = ns.Compat, {}
ns.ProgressBars = B

--------------------------------------------------------------------------------------------------------
--                                          Shared Controls                                           --
--------------------------------------------------------------------------------------------------------

-- Create one blue progress bar with a dark background and a restrained native border.
function B.Create(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(16)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.55, 0.85)
    bar:SetMinMaxValues(0, 100)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.9)
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetAllPoints()
    border:SetFrameLevel(bar:GetFrameLevel() + 1)
    border:EnableMouse(false)
    border:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=8})
    border:SetBackdropBorderColor(0.6, 0.55, 0.45, 1)
    local label = ns.Fonts.Create(border, nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", bar, "CENTER")
    label:SetJustifyH("CENTER")
    label:SetTextColor(1, 1, 1)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    bar.text = label
    return bar
end

-- Fill only from known finite values; preserve the actual counters in the label.
function B.Set(bar, value, maximum, label)
    local valid = C.IsNumber(value) and C.IsNumber(maximum)
        and value >= 0 and value < math.huge and maximum > 0 and maximum < math.huge
    bar:SetMinMaxValues(0, valid and maximum or 100)
    bar:SetValue(valid and math.min(value, maximum) or 0)
    bar.text:SetText(label or (valid and (C.FormatNumber(value) .. " / " .. C.FormatNumber(maximum)) or ""))
    return valid
end
