local _, ExaminerNS = ...; if ExaminerNS.blocked then return; end
local ex = Examiner;
local GetAddOnMetadata = ExaminerNS.Compat.GetAddOnMetadata;
local cfg;

-- Module
local mod = ex:CreateModule("Config",ExaminerNS.L["Settings"]);
mod.help = ExaminerNS.L["Examiner Settings"];
mod:CreatePage(false,ExaminerNS.L["Settings"]);

-- Create Version String
local modName = ex:GetName();
local vers = mod.page:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall");
vers:SetText(modName.." |cffffff80"..GetAddOnMetadata(modName,"Version"));
vers:SetPoint("BOTTOM",0,14);

-- Variables
local checkBtns = {};

--------------------------------------------------------------------------------------------------------
--                                           Config Scripts                                           --
--------------------------------------------------------------------------------------------------------

-- CheckBoxes: OnClick
local function ConfigCheckBox_OnClick(self,button)
	local var = ex.options[self.id].var;
	cfg[var] = (self:GetChecked() and true or false);
	-- Special "makeMovable" handling -- Must not invoke the OnHide event!
	if (var == "makeMovable") then
		local onHide = ex:GetScript("OnHide");
		ex:SetScript("OnHide",nil);
		ex:SetMovable(cfg.makeMovable);
		if (cfg.makeMovable) then
			HideUIPanel(ex);
			ex:Show();
		else
			ex:Hide();
			ShowUIPanel(ex);
		end
		ex:SetScript("OnHide",onHide);
	end
	-- Post Change to Modules
	ex:SendModuleEvent("OnConfigChanged",var,cfg[var]);
end

-- CheckBoxes: OnEnter
local function ConfigCheckBox_OnEnter(self)
	local option = ex.options[self.id];
	GameTooltip:SetOwner(self,"ANCHOR_RIGHT");
	GameTooltip:AddLine(option.label,1,1,1);
	GameTooltip:AddLine(option.tip,nil,nil,nil,1);
	GameTooltip:Show();
end

--------------------------------------------------------------------------------------------------------
--                                           Module Scripts                                           --
--------------------------------------------------------------------------------------------------------

-- Menu Init
local function MenuInit(parent,list)
	list[1].text = "|cff00c0ff"..ExaminerNS.L["Examiner Core Caching"];
	list[1].value = "Core";
	list[1].checked = cfg.caching.Core;
	list[1].tip = ExaminerNS.L["Disable this to turn off caching completely in Examiner"];
	for index, mod in ipairs(ex.modules) do
		if (mod.canCache) then
			local tbl = list[#list + 1];
			tbl.text = mod.title;
			tbl.value = mod.token;
			tbl.checked = cfg.caching[mod.token];
			tbl.tip = ExaminerNS.L["Enable to turn on caching for this module"];
		end
	end
end

-- Menu Select
local function MenuSelect(parent,entry)
	cfg.caching[entry.value] = not cfg.caching[entry.value];
end

-- OnInitialize
function mod:OnInitialize()
	cfg = ex.cfg;

	-- DropDown
	self.dropDown = AzDropDown:CreateDropDown(self.page,-190,MenuInit,MenuSelect,false,false);
	self.dropDown.menuFillColor={0.02,0.02,0.02,1};
	self.dropDown:SetBackdrop({
		bgFile="Interface\\Buttons\\WHITE8X8",
		edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
		tile=true,tileSize=16,edgeSize=12,
		insets={left=3,right=3,top=3,bottom=3},
	});
	self.dropDown:SetBackdropColor(0,0,0,1);
	self.dropDown:SetBackdropBorderColor(0.6,0.6,0.6,1);
	local background=self.dropDown:CreateTexture(nil,"BACKGROUND");
	self.dropDown.background=background;
	background:SetColorTexture(0,0,0,1);
	background:SetPoint("TOPLEFT",3,-3);
	background:SetPoint("BOTTOMRIGHT",-3,3);
	self.dropDown:SetWidth(self.page:GetWidth()-40);
	self.dropDown:SetPoint("TOPLEFT",20,-40);
	self.dropDown.button:SetHitRectInsets(self.dropDown.button:GetWidth()-self.dropDown:GetWidth(),0,0,0);
	self.dropDown.label:SetJustifyH("LEFT");
	self.dropDown:SetText(ExaminerNS.L["Enabled Module Caching..."]);

	-- Check Boxes
	for index, option in ipairs(ex.options) do
		local chk = CreateFrame("CheckButton",nil,mod.page);
		chk:SetSize(21,21);
		chk:SetScript("OnClick",ConfigCheckBox_OnClick);
		chk:SetScript("OnEnter",ConfigCheckBox_OnEnter);
		chk:SetScript("OnLeave",ex.HideGTT);

		chk:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up");
		chk:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down");
	 	chk:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight");
		chk:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled");
		chk:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check");

		chk:SetChecked(cfg[option.var]);

		chk.text = chk:CreateFontString("ARTWORK",nil,"GameFontNormalSmall");
		chk.text:SetPoint("LEFT",chk,"RIGHT",0,1);
		chk.text:SetText(option.label);
		chk:SetHitRectInsets(0,chk.text:GetWidth() * -1,0,0);

		chk.id = index;
		chk.var = option.var;

		if (index == 1) then
			chk:SetPoint("TOPLEFT",20,-70);
		else
			chk:SetPoint("TOP",checkBtns[index - 1],"BOTTOM",0,2);
		end

		checkBtns[index] = chk;
	end

	local slider=CreateFrame("Slider",nil,self.page);
	self.scaleSlider=slider;
	slider:SetOrientation("HORIZONTAL");
	slider:SetSize(self.page:GetWidth()-40,16);
	slider:SetPoint("TOPLEFT",20,-96-#checkBtns*19);
	slider:SetMinMaxValues(0.75,1.50);
	slider:SetValueStep(0.01);
	slider:SetObeyStepOnDrag(true);
	local thumb=slider:CreateTexture(nil,"OVERLAY");
	thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal");
	thumb:SetSize(24,24);
	slider:SetThumbTexture(thumb);
	local track=slider:CreateTexture(nil,"BACKGROUND");
	track:SetTexture("Interface\\Buttons\\UI-SliderBar-Background");
	track:SetAllPoints(slider);
	local label=slider:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");
	label:SetPoint("BOTTOMLEFT",slider,"TOPLEFT",0,6);
	label:SetText(ExaminerNS.L["Window scale"]);
	slider.valueText=slider:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
	slider.valueText:SetPoint("BOTTOMRIGHT",slider,"TOPRIGHT",0,6);
	for index,text in ipairs({"0.75","1.50"}) do
		local limit=slider:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
		limit:SetPoint(index==1 and "TOPLEFT" or "TOPRIGHT",slider,index==1 and "BOTTOMLEFT" or "BOTTOMRIGHT",0,-2);
		limit:SetText(text);
	end
	slider.defaultText=slider:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
	slider.defaultText:SetPoint("TOP",slider,"BOTTOM",0,-2);
	slider.defaultText:SetText(ExaminerNS.L["Default: 1.00"]);
	slider.defaultText:SetTextColor(0.7,0.7,0.7);
	local function ApplyScale(self)
		local value=self.pendingScale;
		self.pendingScale=nil;
		self:SetScript("OnUpdate",nil);
		if value then ex:SetWindowScale(value); end
	end
	slider:SetScript("OnValueChanged",function(self,value)
		if self.syncing then return; end
		value=math.max(0.75,math.min(1.50,math.floor(value*100+0.5)/100));
		self.valueText:SetText(string.format("%.2f",value));
		if IsMouseButtonDown("LeftButton") then
			self.pendingScale=value;
			self:SetScript("OnUpdate",function(self)
				if not IsMouseButtonDown("LeftButton") then ApplyScale(self); end
			end);
		else
			ex:SetWindowScale(value);
		end
	end);
	slider:SetScript("OnMouseUp",function(self,button)
		if button=="LeftButton" then ApplyScale(self); end
	end);
	slider:SetScript("OnHide",function(self)
		mod:OnConfigChanged("scale",cfg.scale);
	end);
	slider:SetScript("OnEnter",function(self)
		GameTooltip:SetOwner(self,"ANCHOR_RIGHT");
		GameTooltip:AddLine(ExaminerNS.L["Set window scale (default: 1.00)."],1,1,1);
		GameTooltip:Show();
	end);
	slider:SetScript("OnLeave",ex.HideGTT);
	self:OnConfigChanged("scale",cfg.scale);
end

-- OnConfigChanged
function mod:OnConfigChanged(var,value)
	if var=="scale" and self.scaleSlider then
		local slider=self.scaleSlider;
		slider.pendingScale=nil;
		slider:SetScript("OnUpdate",nil);
		slider.syncing=true;
		slider:SetValue(value);
		slider.valueText:SetText(string.format("%.2f",value));
		slider.syncing=nil;
	end
	for index, chk in ipairs(checkBtns) do
		if (chk.var == var) then
			chk:SetChecked(cfg[var]);
		end
	end
end
