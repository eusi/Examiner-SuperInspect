local _, ns = ...;
if ns.blocked then return; end
local ex, C = ns.ex, ns.Compat;
local function Out(message) AzMsg("Examiner: "..message); end
function ex:Diagnostics(command)
    Out(C.client.." | "..tostring(C.version).." | build "..tostring(C.build).." | interface "..C.interface);
    Out("folder="..ns.addonName.." | data="..ns.configKey.." / "..ns.cacheKey);
    Out("LibFroznFunctions="..tostring(LibStub.minors["LibFroznFunctions-1.0"]).." | bundled=71 | SoD="..tostring(C.isSoD).." | ranged="..tostring(C.hasRangedSlot));
    local names = {};
    for _, mod in ipairs(self.modules) do names[#names + 1] = mod.token; end
    Out("modules="..table.concat(names, ", "));
    Out("inspect entry="..(ns.inspectEntry or "legacy InspectUnit"));
    Out("Equipment="..(self.gear and self.gear.state or "none").." | stats="..(self.gear and self.gear.statsState or "none").." | talents="..(self.talentData and self.talentData.state or "classic/none"));
    if self.talentData and self.talentData.gaps and #self.talentData.gaps>0 then Out("talent gaps="..table.concat(self.talentData.gaps,", ")); end
    local talents=self:GetModuleFromToken("Talents");
    if talents and talents.backgroundTexture then Out("talent background="..tostring(talents.backgroundSource or "not drawn").." | spec="..tostring(self.talentData and self.talentData.specID)); end
    if command=="stats" then
        for _,token in ipairs({"STR","AGI","STA","INT","VERSATILITYRATING","LEECH","DPS"}) do
            Out(token.."="..(C.IsNumber(self.unitStats[token]) and C.FormatNumber(self.unitStats[token]) or "not captured"));
        end
        for _,source in ipairs(self.gear and self.gear.dpsSources or {}) do
            Out("DPS source: slot="..tostring(source.slot).." | "..source.link.." | "..C.FormatNumber(source.value));
        end
        for slot,link in pairs(self.info.Items or {}) do
            local raw=C.Try(C_Item and C_Item.GetItemStats or GetItemStats,link);
            if C.IsTable(raw) then
                local keys={};
                for key,value in pairs(raw) do
                    if C.IsString(key) and C.IsNumber(value) and value~=0 then keys[#keys+1]=key.."="..C.FormatNumber(value); end
                end
                table.sort(keys); if #keys>0 then Out(slot..": "..table.concat(keys,", ")); end
            end
        end
    end
    Out("Build: "..C.Text(C.Try(C.GetAddOnMetadata,ns.addonName,"Version"),"unknown").." | In-game verification required per client.");
    if command=="pvp" then
        local session=ns.Inspector.active;
        Out("PvP requested="..tostring(self.requestedHonorData).." | server ready="..tostring(session and session.serverReady).." | honor ready="..tostring(session and session.honorReady));
        local data=self.pvpData or {};
        for _,key in ipairs({"honorLevel","lifetimeHK","arena2","arena3","arena5","rbg","shuffle","blitz"}) do
            local record=C.IsTable(data.records) and data.records[key];
            Out(key.."="..(C.IsNumber(data[key]) and C.FormatNumber(data[key]) or "not supplied").." | record="..tostring(C.IsTable(record)));
        end
    end
    if command == "talents" or command == "talents self" or command == "talents inspect" then
        local unit = command == "talents self" and "player" or self.unit or "player";
        if command == "talents inspect" and (not self:ValidateUnit() or self.isSelf) then
            Out("Inspect another player first, keep the unit selected, then run /ex diag talents inspect.");
            return;
        end
        if self.unit and not self:ValidateUnit() and unit ~= "player" then Out("The inspected unit changed; inspect again."); return; end
        local r = C.ProbeTalents(unit);
        self.lastTalentProbe = r;
        Out("talents="..r.status.." | trees="..r.trees.." nodes="..r.nodes.." positions="..r.positions.." ranks="..r.ranks.." entries="..r.entries.." edges="..r.edges);
        Out("graphical candidate="..tostring(r.graphicalCandidate or false).." | build string="..tostring(C.IsString(r.loadout) and #r.loadout > 0));
        if C.isForever then
            for _,tree in ipairs(self.talentData and self.talentData.trees or {}) do
                local missing={};
                for _,node in ipairs(tree.nodes) do
                    if not node.entry or not node.entry.icon or node.entry.pending then missing[#missing+1]=tostring(node.id); end
                end
                local layout=ns.TalentPanelLayout(tree,talents and talents.treeWidth or 300,talents and talents.treeHeight or 350);
                Out("tree="..tostring(tree.name).." | nodes="..#tree.nodes.." | icon size="..C.FormatNumber(layout.size)
                    .." | missing metadata="..(#missing>0 and table.concat(missing,",") or "none"));
                for _,node in ipairs(tree.omittedDuplicates or {}) do
                    Out("detached duplicate="..node.id.." | retained="..node.replacement.." | position="..node.x..","..node.y.." | "..tostring(node.name));
                end
                for _,gap in ipairs(layout.compressedGaps or {}) do
                    Out("compressed "..gap.axis.." gap="..gap.from.." to "..gap.to);
                    for _,node in ipairs(tree.nodes) do
                        if node[gap.axis]==gap.from or node[gap.axis]==gap.to then
                            Out("node="..node.id.." | position="..node.x..","..node.y.." | "..tostring(node.entry and node.entry.name));
                        end
                    end
                end
            end
        end
    end
    for _, entry in ipairs(ns.trace) do Out(string.format("%.1f %s: %s", entry.time, entry.event, entry.detail or "")); end
end
ex.slashCommands[#ex.slashCommands + 1] = " |2diag [stats|pvp|talents [self|inspect]]|r = Client, library and read-only data diagnostics";
ex.slashCommands.diag = function(command) ex:Diagnostics(command); end;
