local addonName, ns = ...;
ns.addonName = addonName;
ns.assetPath = "Interface\\AddOns\\"..addonName.."\\";
ns.development = addonName ~= "Examiner";
ns.configKey = ns.development and "ExaminerDev_Config" or "Examiner_Config";
ns.cacheKey = ns.development and "ExaminerDev_Cache" or "Examiner_Cache";
ns.trace = {};

-- OptionalDeps loads Examiner first for conflict detection.
ns.blocked = _G.Examiner ~= nil;
if ns.blocked then
    print(addonName..": another Examiner is already loaded. Disable it before testing this copy.");
end

function ns.Record(event, detail)
    local trace = ns.trace;
    trace[#trace + 1] = { time = GetTime(), event = event, detail = detail };
    if #trace > 8 then table.remove(trace, 1); end
end
