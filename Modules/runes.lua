local _, ExaminerNS = ...; if ExaminerNS.blocked then return; end
local ex = Examiner;
if not ExaminerNS.Compat.isSoD then return; end
local C = ExaminerNS.Compat;
local gtt = GameTooltip;

-- Module
local mod = ex:CreateModule("Runes",ExaminerNS.L["SoD Runes"]);
mod.help = ExaminerNS.L["Shows the currently equipped SoD Runes"];
mod:CreatePage(false,ExaminerNS.L["Runes"]);
mod:HasButton(true);

-- Variables
local NUM_BUTTONS = 10;
local BUTTON_HEIGHT = (mod.page:GetHeight() - 47) / NUM_BUTTONS;
local showEngravings = {};
local buttons = {};

-- Inspect lifecycle and cache

function mod:OnInspect(unit)
	self:BuildEngravingList();
end

function mod:OnInspectReady(unit)
	self:BuildEngravingList();
end

function mod:OnCacheLoaded(entry,unit)
	self:BuildEngravingList();
end

function mod:OnClearInspect()
	self:HasData(nil);
	wipe(showEngravings);
end

function mod:OnPageChanged(module,shown)
	if (self == module) then
		self:BuildEngravingList();
	end
end

-- Rune tooltips

-- Rune OnEnter
local function RuneButton_OnEnter(self,motion)
	gtt:SetOwner(self,"ANCHOR_RIGHT");
  gtt:SetSpellByID(self.id);
  gtt:Show();
end

-- Rune OnLeave
local function RuneButton_OnLeave(self,motion)
  gtt:Hide();
end

-- Rune list

-- Update
local function UpdateShownItems(self)
    FauxScrollFrame_Update(self, #showEngravings, NUM_BUTTONS, BUTTON_HEIGHT);
    for i = 1, NUM_BUTTONS do
        local btn = buttons[i];
        local engraving=showEngravings[(self.offset or 0)+i];
        if engraving then
            btn.name:SetText(engraving.name);
            btn.id = engraving.spellID;
            btn.icon:SetTexture(C.Icon(C.Try(C.GetSpellTexture,btn.id)));
            btn.name:SetTextColor(0.9, 0.9, 0.9);
            btn:Show();
        else
            btn:Hide();
        end
    end
end

-- Live snapshots carry spell IDs; old caches may only contain localized names.
function mod:BuildEngravingList()
	wipe(showEngravings);
	LibRunes:CreateRunesTable(ex.info.class);
	for _, rune in ipairs(ex.info.Runes) do
		local id=C.Number(rune.spellID) or LibRunes.abilities[rune.name];
		if C.IsNumber(id) and id>0 and C.IsString(rune.name) then
			showEngravings[#showEngravings + 1] = {name=rune.name,spellID=id};
		end
	end
	UpdateShownItems(self.scroll);
	self:HasData(#showEngravings>0);
	return #showEngravings;
end

-- Widgets

-- Buttons
for i = 1, NUM_BUTTONS do
	local btn = CreateFrame("Button",nil,mod.page);

	btn:SetHeight(BUTTON_HEIGHT);
	btn:RegisterForClicks("LeftButtonDown","RightButtonDown");
	btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
	btn:Hide();

	if (#buttons == 0) then
		btn:SetPoint("TOPLEFT",8,-36.5);
		btn:SetPoint("TOPRIGHT",-28,-36.5);
	else
		btn:SetPoint("TOPLEFT",buttons[#buttons],"BOTTOMLEFT");
		btn:SetPoint("TOPRIGHT",buttons[#buttons],"BOTTOMRIGHT");
	end

	btn:SetScript("OnEnter",RuneButton_OnEnter);
	btn:SetScript("OnLeave",RuneButton_OnLeave);

	btn.icon = btn:CreateTexture(nil,"ARTWORK");
	btn.icon:SetSize(BUTTON_HEIGHT - 2,BUTTON_HEIGHT - 2);
	btn.icon:SetPoint("LEFT",2,0);
	btn.icon:SetTexCoord(0.07,0.93,0.07,0.93);
	btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");

	btn.name = btn:CreateFontString(nil,"ARTWORK","GameFontHighlight");
	btn.name:SetPoint("LEFT",btn.icon,"RIGHT",3,0);
	btn.name:SetPoint("RIGHT",-8,0);
	btn.name:SetJustifyH("LEFT");

	buttons[i] = btn;
end

-- Scroll
mod.scroll = CreateFrame("ScrollFrame","Examiner"..mod.token.."Scroll",mod.page,"FauxScrollFrameTemplate");
mod.scroll:SetPoint("TOPLEFT",buttons[1]);
mod.scroll:SetPoint("BOTTOMRIGHT",buttons[NUM_BUTTONS],-6,-1);
mod.scroll:SetScript("OnVerticalScroll",function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,BUTTON_HEIGHT,UpdateShownItems) end);
