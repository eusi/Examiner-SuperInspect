--------------------------------------------------------------------------------------------------------
--
-- Services/GearColors.lua
-- Grades displayed gear values against the inspected character's level.
--
----------------------

local _, ns = ...
if ns.blocked then return end
local C, G = ns.Compat, {}
ns.GearColors = G
-- Color references, not item suitability or best-in-slot scores.
local classicCurve = {{1,1.1},{60,66},{70,120},{80,213},{85,359},{90,397}}
local palette = {
    {0,0.45,0.45,0.45}, {0.65,0.8,0.8,0.8}, {0.85,0.12,1,0},
    {1,0,0.44,0.87}, {1.2,0.64,0.21,0.93}, {1.4,1,0.5,0},
}
local retailCap, retailBaseline

local function Number(value)
    value = C.Number(value)
    return value and value == value and math.abs(value) < math.huge and value or nil
end

-- Classic clients retain expansion breakpoints; Retail follows its active library reference.
function G.Reference(level)
    level = Number(level)
    if not level or level < 1 then return end
    if C.isForever then return math.min(level,60)/60*65 end
    if C.isEra or C.isTBC or C.isMists then
        local cap = C.isEra and 60 or C.isTBC and 70 or 90
        level = math.min(level,cap)
        for index = 2, #classicCurve do
            local previous, current = classicCurve[index-1], classicCurve[index]
            if level <= current[1] then
                local weight = (level-previous[1])/(current[1]-previous[1])
                return previous[2]+(current[2]-previous[2])*weight
            end
        end
    elseif C.isRetail then
        if not retailCap then retailCap = Number(C.Try(GetMaxLevelForLatestExpansion)) end
        if not retailBaseline then
            local library = LibStub("LibFroznFunctions-1.0",true)
            retailBaseline = library and library.hasWoWFlavor and Number(library.hasWoWFlavor.itemLevelOfFirstRaidTierSet)
        end
        if retailCap and retailCap > 0 and retailBaseline and retailBaseline > 0 then
            return retailBaseline*math.min(level,retailCap)/retailCap
        end
    end
end

local function Color(value, reference)
    value, reference = Number(value), Number(reference)
    if not value or value < 0 or not reference or reference <= 0 then return 0.8,0.8,0.8 end
    local ratio = value/reference
    for index = 2, #palette do
        local previous, current = palette[index-1], palette[index]
        if ratio <= current[1] then
            local weight = math.max(0,(ratio-previous[1])/(current[1]-previous[1]))
            return previous[2]+(current[2]-previous[2])*weight,
                previous[3]+(current[3]-previous[3])*weight,
                previous[4]+(current[4]-previous[4])*weight
        end
    end
    return 1,0.5,0
end

function G.ItemLevel(value, characterLevel)
    return Color(value,G.Reference(characterLevel))
end

-- Round only the displayed average; retain the original value for calculations and colors.
function G.Average(value)
    value = Number(value)
    return value and value >= 0 and math.floor(value + 0.5) or "—"
end

-- Color each endpoint independently when both share one font string.
function G.ItemLevelText(value, characterLevel)
    local r, g, b = G.ItemLevel(value, characterLevel)
    return string.format("|cff%02x%02x%02x%s|r", math.floor(r*255+0.5), math.floor(g*255+0.5),
        math.floor(b*255+0.5), C.FormatNumber(value))
end

-- Use the existing TacoTip rare-item formula only as a full-set color reference.
-- The displayed GearScore itself is never recalculated or scaled.
function G.Score(value, characterLevel)
    local reference = G.Reference(characterLevel)
    if reference then
        local offset, divisor = reference <= 148 and 0.75 or 81.375, reference <= 148 and 1.8 or 0.8125
        reference = math.max(1,(reference-offset)/divisor*1.8618*11.25)
    end
    return Color(value,reference)
end
