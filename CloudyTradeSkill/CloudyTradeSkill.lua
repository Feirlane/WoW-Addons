--[[
	Cloudy TradeSkill
	Copyright (c) 2020, Cloudyfa
	All rights reserved.
]]


--- Initialization ---
local numTabs = 0
local skinUI, loadedUI, delay
local function InitDB()
	-- Create new DB if needed --
	if (not CTradeSkillDB) then
		CTradeSkillDB = {}
		CTradeSkillDB['Unlock'] = false
		CTradeSkillDB['Level'] = true
		CTradeSkillDB['Tooltip'] = true
	end
	CTradeSkillDB['Size'] = 22
	if not CTradeSkillDB['Tabs'] then CTradeSkillDB['Tabs'] = {} end
	if not CTradeSkillDB['Bookmarks'] then CTradeSkillDB['Bookmarks'] = {} end

	-- Load UI addons --
	if IsAddOnLoaded('Aurora') then
		skinUI = 'Aurora'
		loadedUI = unpack(Aurora)
	elseif IsAddOnLoaded('ElvUI') then
		skinUI = 'ElvUI'
		loadedUI = unpack(ElvUI):GetModule('Skins')
	end
end


--- Create Frame ---
local f = CreateFrame('Frame', 'CloudyTradeSkill')
f:RegisterEvent('PLAYER_LOGIN')
f:RegisterEvent('PLAYER_REGEN_ENABLED')
f:RegisterEvent('TRADE_SKILL_DATA_SOURCE_CHANGED')


--- Local Functions ---
	--- Check Current Tab ---
	local function isCurrentTab(self)
		if self.id and IsCurrentSpell(self.id) then
			if TradeSkillFrame:IsShown() and (self.isSub == 0) then
				CTradeSkillDB['Panel'] = self.id
			end
			self:SetChecked(true)
			self:RegisterForClicks(nil)
		else
			self:SetChecked(false)
			self:RegisterForClicks('AnyDown')
		end
	end

	--- Add Tab Button ---
	local function addTab(id, index, isSub)
		local icon = select(3, GetSpellInfo(id))
		if (not name) or (not icon) then return end

		local tab = _G['CTradeSkillTab' .. index] or CreateFrame('CheckButton', 'CTradeSkillTab' .. index, TradeSkillFrame, 'SpellBookSkillLineTabTemplate, SecureActionButtonTemplate')
		tab:SetScript('OnEvent', isCurrentTab)
		tab:RegisterEvent('CURRENT_SPELL_CAST_CHANGED')

		tab.id = id
		tab.isSub = isSub
		tab.tooltip = name
		tab:SetNormalTexture(icon)
		tab:SetAttribute('type', tabType)
		tab:SetAttribute(tabType, tabItem and name or id)
		isCurrentTab(tab)

		if skinUI and not tab.skinned then
			local checkedTexture
			if (skinUI == 'Aurora') then
				checkedTexture = 'Interface\\AddOns\\Aurora\\media\\CheckButtonHilight'
			elseif (skinUI == 'ElvUI') then
				checkedTexture = tab:CreateTexture(nil, 'HIGHLIGHT')
				checkedTexture:SetColorTexture(1, 1, 1, 0.3)
				checkedTexture:SetInside()
				tab:SetHighlightTexture(nil)
			end
			tab:SetCheckedTexture(checkedTexture)
			tab:GetNormalTexture():SetTexCoord(.08, .92, .08, .92)
			tab:GetRegions():Hide()
			tab.skinned = true
		end
	end

	--- Remove Tab Buttons ---
	local function removeTabs()
		for i = 1, numTabs do
			local tab = _G['CTradeSkillTab' .. i]
			if tab and tab:IsShown() then
				tab:UnregisterEvent('CURRENT_SPELL_CAST_CHANGED')
				tab:Hide()
			end
		end
	end

	--- Sort Tabs ---
	local function sortTabs()
		local index = 1
		for i = 1, numTabs do
			local tab = _G['CTradeSkillTab' .. i]
			if tab then
				if CTradeSkillDB['Tabs'][tab.id] then
					tab:SetPoint('TOPLEFT', TradeSkillFrame, 'TOPRIGHT', skinUI and 1 or 0, (-50 * index) + (-50 * tab.isSub))
					tab:Show()
					index = index + 1
				else
					tab:Hide()
				end
			end
		end
	end

	--- Update Profession Tabs ---
	local function updateTabs(init)
		local mainTabs, subTabs = {}, {}

		local _, class = UnitClass('player')
		if (class == 'ROGUE') then
			local spell = GetSpellInfo(1804) --PickLock
			if IsUsableSpell(spell) then
				tinsert(subTabs, spell)
			end
		end

		local prof1, prof2, arch, fishing, cooking, firstaid = GetProfessions()
		local profs = {prof1, prof2, cooking, firstaid}
		for _, prof in pairs(profs) do
			local num, offset, _, _, _, spec = select(5, GetProfessionInfo(prof))
			if (spec and spec ~= 0) then num = 1 end
			for i = 1, num do
				if not IsPassiveSpell(offset + i, BOOKTYPE_PROFESSION) then
					local _, id = GetSpellBookItemInfo(offset + i, BOOKTYPE_PROFESSION)
					if (i == 1) then
						tinsert(mainTabs, id)
						if init and not CTradeSkillDB['Panel'] then
							CTradeSkillDB['Panel'] = id
						end
					else
						tinsert(subTabs, id)
					end
				end
			end
		end

		local sameTabs = true
		for i = 1, #mainTabs + #subTabs do
			local id = mainTabs[i] or subTabs[i - #mainTabs]
			if not CTradeSkillDB['Tabs'][id] then
				CTradeSkillDB['Tabs'][id] = true
				sameTabs = false
			end
		end

		if not sameTabs or (numTabs ~= #mainTabs + #subTabs) then
			removeTabs()
			numTabs = #mainTabs + #subTabs
			for i = 1, numTabs do
				local id = mainTabs[i] or subTabs[i - #mainTabs]
				addTab(id, i, mainTabs[i] and 0 or 1)
			end
			sortTabs()
		end
	end

	--- Update Frame Size ---
	local function updateSize()
		TradeSkillFrame:SetWidth(714)
		TradeSkillFrame:SetHeight(skinUI and 512 or 487)

		TradeSkillDetailScrollFrame:ClearAllPoints()
		TradeSkillDetailScrollFrame:SetPoint('TOPLEFT', TradeSkillFrame, 'TOPLEFT', 362, -92)
		TradeSkillDetailScrollFrame:SetSize(296, 332)
		TradeSkillDetailScrollFrameTop:SetAlpha(0)
		TradeSkillDetailScrollFrameBottom:SetAlpha(0)

		TradeSkillListScrollFrame:ClearAllPoints()
		TradeSkillListScrollFrame:SetPoint('TOPLEFT', TradeSkillFrame, 'TOPLEFT', 23.8, -99)
		TradeSkillListScrollFrame:SetSize(296, 332)
		if not skinUI then
			local scrollFix = TradeSkillListScrollFrame:CreateTexture(nil, 'BACKGROUND')
			scrollFix:SetPoint('TOPRIGHT', TradeSkillListScrollFrame, 'TOPRIGHT', 29, -110)
			scrollFix:SetTexture('Interface\\ClassTrainerFrame\\UI-ClassTrainer-ScrollBar')
			scrollFix:SetTexCoord(.0, .5, .2, .9)
			scrollFix:SetSize(32, 0)
		end

		local regions = {TradeSkillFrame:GetRegions()}
		regions[2]:SetTexture('Interface\\QuestFrame\\UI-QuestLogDualPane-Left')
		regions[2]:SetSize(512, 512)

		regions[3]:ClearAllPoints()
		regions[3]:SetPoint('TOPLEFT', regions[2], 'TOPRIGHT')
		regions[3]:SetTexture('Interface\\QuestFrame\\UI-QuestLogDualPane-Right')
		regions[3]:SetSize(256, 512)

		if not skinUI then
			regions[4]:Hide()
			regions[5]:Hide()
		end
		regions[9]:Hide()
		regions[10]:Hide()

		if not skinUI then
			--- Recipe Background ---
			local RecipeInset = TradeSkillFrame:CreateTexture(nil, 'ARTWORK')
			RecipeInset:SetPoint('TOPLEFT', 'TradeSkillFrame', 'TOPLEFT', 16.4, -72)
			RecipeInset:SetTexture('Interface\\RaidFrame\\UI-RaidFrame-GroupBg')
			RecipeInset:SetSize(326.5, 360.8)

			--- Detail Background ---
			local DetailsInset = TradeSkillFrame:CreateTexture(nil, 'ARTWORK')
			DetailsInset:SetPoint('TOPLEFT', TradeSkillFrame, 'TOPLEFT', 349, -73)
			DetailsInset:SetAtlas('tradeskill-background-recipe')
			DetailsInset:SetSize(324, 339)
		end

		-- Expand Tab ---
		TradeSkillExpandTabLeft:Hide()

		--- Filter Dropdown ---
		TradeSkillInvSlotDropDown:ClearAllPoints()
		TradeSkillInvSlotDropDown:SetPoint('TOPLEFT', TradeSkillFrame, 'TOPLEFT', 190, -70)
		TradeSkillSubClassDropDown:ClearAllPoints()
		TradeSkillSubClassDropDown:SetPoint('TOPRIGHT', TradeSkillInvSlotDropDown, 'TOPLEFT', 29, 0)

		--- Craft Buttons ---
		TradeSkillCancelButton:ClearAllPoints()
		TradeSkillCancelButton:SetPoint('BOTTOMRIGHT', TradeSkillFrame, 'BOTTOMRIGHT', -40, skinUI and 79 or 54)
		TradeSkillCreateButton:ClearAllPoints()
		TradeSkillCreateButton:SetPoint('RIGHT', TradeSkillCancelButton, 'LEFT', -1, 0)

		--- Recipe Buttons ---
		TRADE_SKILLS_DISPLAYED = CTradeSkillDB['Size']
		for i = 1, CTradeSkillDB['Size'] do
			local button = _G['TradeSkillSkill' .. i] or CreateFrame('Button', 'TradeSkillSkill' .. i, TradeSkillFrame, 'TradeSkillSkillButtonTemplate')
			if (i > 1) then
				button:ClearAllPoints()
				button:SetPoint('TOPLEFT', _G['TradeSkillSkill' .. (i - 1)], 'BOTTOMLEFT', 0, 1)
			end
			if skinUI and not button.skinned then
				button._minus = button:CreateTexture(nil, 'OVERLAY')
				button._plus = button:CreateTexture(nil, 'OVERLAY')
				button.skinned = true
			end
		end
	end

	--- Get Recipe Index ---
	local function getRecipeIndex(name)
		for index = 1, GetNumTradeSkills() do
			local recipe = GetTradeSkillInfo(index)
			if (recipe == name) then
				return index
			end
		end
	end

	--- Set Bookmark Icon ---
	local function bookmarkIcon(button, texture)
		button:SetNormalTexture(texture)
		button:SetPushedTexture(texture)

		local pushed = button:GetPushedTexture()
		pushed:ClearAllPoints()
		pushed:SetPoint('TOPLEFT', 1, -1)
		pushed:SetPoint('BOTTOMRIGHT', -1, 1)
		pushed:SetVertexColor(0.75, 0.75, 0.75)
	end

	--- Update Bookmarks ---
	local function updateBookmarks()
		local prof = GetTradeSkillLine()
		if not prof or (prof == 'UNKNOWN') then return end

		if not CTradeSkillDB['Bookmarks'][prof] then
			CTradeSkillDB['Bookmarks'][prof] = {}
		end

		local saved = CTradeSkillDB['Bookmarks'][prof]
		for i = 1, 10 do
			local button = _G['CTradeSkillBookmark' .. i]
			if saved[i] then
				local index = getRecipeIndex(saved[i])
				if index then
					local icon = GetTradeSkillIcon(index)
					bookmarkIcon(button, icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
					button:Show()
				end
			else
				button:Hide()
			end
		end

		local main = _G['CTradeSkillBookmark0']
		local recipe = GetTradeSkillInfo(TradeSkillFrame.selectedSkill or 0)
		local selected = tContains(saved, recipe)
		if not recipe or (#saved > 9 and not selected) then
			main:Disable()
			main.State:Hide()
		else
			main:Enable()
			main.State:Show()
			if selected then
				main.State:SetTexture('Interface\\PetBattles\\DeadPetIcon')
			else
				main.State:SetTexture('Interface\\PaperDollInfoFrame\\Character-Plus')
			end
		end
	end

	--- Add Bookmark ---
	local function addBookmark(index)
		local button = _G['CTradeSkillBookmark' .. index] or CreateFrame('Button', 'CTradeSkillBookmark' .. index, TradeSkillFrame)
		button:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square', 'ADD')
		button:RegisterForClicks('LeftButtonDown', 'RightButtonDown')
		button:SetPoint('TOPRIGHT', TradeSkillFrame, 'TOPRIGHT', -65 - (index * 25), -42)
		button:SetSize(24, 24)
		button:SetID(index)

		if (index == 0) then
			bookmarkIcon(button, 'Interface\\Icons\\INV_Misc_Book_09')
			button.State = button:CreateTexture(nil, 'OVERLAY')
			button.State:SetSize(12, 12)
			button.State:SetPoint('BOTTOMRIGHT', -3, 3)
		else
			button:Hide()
		end

		button:SetScript('OnClick', function(self, mouse)
			local prof = GetTradeSkillLine()
			if not prof then return end

			local saved = CTradeSkillDB['Bookmarks'][prof]
			local recipe = GetTradeSkillInfo(TradeSkillFrame.selectedSkill or 0)
			if (self:GetID() == 0) then
				if tContains(saved, recipe) then
					for i = #saved, 1, -1 do
						if (saved[i] == recipe) then
							tremove(saved, i)
						end
					end
				else
					if (#saved < 10) then
						tinsert(saved, recipe)
					end
				end
				updateBookmarks()
			else
				if (mouse == 'LeftButton') then
					local index = getRecipeIndex(saved[self:GetID()])
					if index then
						TradeSkillListScrollFrameScrollBar:SetValue((index - 1) * 16)
						TradeSkillFrame_SetSelection(index)
						TradeSkillFrame_Update()
					end
				elseif (mouse == 'RightButton') then
					tremove(saved, self:GetID())
					updateBookmarks()
				end
			end
		end)

		button:SetScript('OnEnter', function(self)
			local prof = GetTradeSkillLine()
			if not prof then return end

			local saved = CTradeSkillDB['Bookmarks'][prof]
			GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
			if (self:GetID() > 0) then
				local index = getRecipeIndex(saved[self:GetID()])
				if index then
					GameTooltip:SetTradeSkillItem(index)
				end
			else
				local recipe = GetTradeSkillInfo(TradeSkillFrame.selectedSkill or 0)
				local selected = tContains(saved, recipe)
				GameTooltip:AddLine(selected and REMOVE or ADD, 1, 1, 1)
			end
			GameTooltip:Show()
		end)
		button:SetScript('OnLeave', function()
			GameTooltip:Hide()
		end)
	end

	--- Create Bookmarks ---
	local function createBookmarks()
		for i = 0, 10 do
			addBookmark(i)
		end
		hooksecurefunc('TradeSkillFrame_Update', updateBookmarks)
	end

	--- Update Frame Position ---
	local function updatePosition()
		if CTradeSkillDB['Unlock'] then
			UIPanelWindows['TradeSkillFrame'].area = nil
			TradeSkillFrame:ClearAllPoints()
			if CTradeSkillDB['OffsetX'] and CTradeSkillDB['OffsetY'] then
				TradeSkillFrame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', CTradeSkillDB['OffsetX'], CTradeSkillDB['OffsetY'])
			else
				TradeSkillFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', GetUIPanel('left') and 623 or 16, -116)
			end
		else
			UpdateUIPanelPositions(TradeSkillFrame)
		end
	end


--- Create Movable Bar ---
local createMoveBar = function()
	local movBar = CreateFrame('Button', nil, TradeSkillFrame)
	movBar:SetPoint('TOPRIGHT', TradeSkillFrame, -37, -15)
	movBar:SetSize(610, 20)
	movBar:SetScript('OnMouseDown', function(_, button)
		if (button == 'LeftButton') then
			if CTradeSkillDB['Unlock'] then
				TradeSkillFrame:SetMovable(true)
				TradeSkillFrame:StartMoving()
			end
		elseif (button == 'RightButton') then
			if not UnitAffectingCombat('player') then
				CTradeSkillDB['OffsetX'] = nil
				CTradeSkillDB['OffsetY'] = nil
				updatePosition()
			end
		end
	end)
	movBar:SetScript('OnMouseUp', function(_, button)
		if (button == 'LeftButton') then
			TradeSkillFrame:StopMovingOrSizing()
			TradeSkillFrame:SetMovable(false)

			CTradeSkillDB['OffsetX'] = TradeSkillFrame:GetLeft()
			CTradeSkillDB['OffsetY'] = TradeSkillFrame:GetTop()
		end
	end)
end


--- Create Resize Bar ---
local createResizeBar = function()
	local resizeBar = CreateFrame('Button', nil, TradeSkillFrame)
	resizeBar:SetPoint('BOTTOM', TradeSkillFrame)
	resizeBar:SetSize(670, 6)
	resizeBar:SetScript('OnMouseDown', function(_, button)
		if (button == 'LeftButton') and not UnitAffectingCombat('player') then
			TradeSkillFrame:SetResizable(true)
			TradeSkillFrame:SetMinResize(670, 512)
			TradeSkillFrame:SetMaxResize(670, TradeSkillFrame:GetTop())
			TradeSkillFrame:StartSizing('BOTTOM')
		end
	end)
	resizeBar:SetScript('OnMouseUp', function(_, button)
		if (button == 'LeftButton') and not UnitAffectingCombat('player') then
			TradeSkillFrame:StopMovingOrSizing()
			TradeSkillFrame:SetResizable(false)
			updateSize(true)
		end
	end)
	resizeBar:SetScript('OnEnter', function()
		if not UnitAffectingCombat('player') then
			SetCursor('CAST_CURSOR')
		end
	end)
	resizeBar:SetScript('OnLeave', function()
		if not UnitAffectingCombat('player') then
			ResetCursor()
		end
	end)
end


--- Refresh TSFrame ---
TradeSkillFrame:HookScript('OnSizeChanged', function(self)
	if self:IsShown() and not UnitAffectingCombat('player') then
		CTradeSkillDB['Size'] = (self:GetHeight() - 96) / 16
		updateSize()
	end
end)


--- Refresh RecipeList ---
hooksecurefunc(TradeSkillFrame.RecipeList, 'UpdateFilterBar', function(self)
	if self.FilterBar:IsVisible() then
		self:SetHeight(CTradeSkillDB['Size'] * 16 - 11) --389
	else
		self:SetHeight(CTradeSkillDB['Size'] * 16 + 5) --405
	end
end)


--- Refresh RecipeButton ---
TradeSkillFrame.RecipeList:HookScript('OnUpdate', function(self, ...)
	for i = 1, #self.buttons do
		local button = self.buttons[i]

		--- Button Tooltip ---
		if not button.CTSTip then
			button:HookScript('OnEnter', function(self)
				if CTradeSkillDB and CTradeSkillDB['Tooltip'] then
					if self.tradeSkillInfo and not self.isHeader then
						local link = C_TradeSkillUI.GetRecipeLink(self.tradeSkillInfo.recipeID)
						if link then
							GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
							GameTooltip:SetHyperlink(link)
						end
					end
				end
			end)
			button:HookScript('OnLeave', function()
				if CTradeSkillDB and CTradeSkillDB['Tooltip'] then
					GameTooltip:Hide()
				end
			end)
			button.CTSTip = true
		end

		--- Required Level ---
		if CTradeSkillDB and CTradeSkillDB['Level'] then
			if not button.CTSLevel then
				button.CTSLevel = button:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
				button.CTSLevel:SetPoint('RIGHT', button.Text, 'LEFT', 1, 0)
			end

			if button.tradeSkillInfo and not button.isHeader then
				local recipe = button.tradeSkillInfo.recipeID
				local item = C_TradeSkillUI.GetRecipeItemLink(recipe)
				if item then
					local quality, _, level = select(3, GetItemInfo(item))
					if quality and level and level > 1 then
						button.CTSLevel:SetText(level)
						button.CTSLevel:SetTextColor(GetItemQualityColor(quality))
					else
						button.CTSLevel:SetText('')
					end
				end
			else
				button.CTSLevel:SetText('')
			end
		else
			if button.CTSLevel then
				button.CTSLevel:SetText('')
			end
		end
	end
end)


--- Collapse Recipes ---
hooksecurefunc(TradeSkillFrame.RecipeList, 'OnHeaderButtonClicked', function(self, _, info, button)
	if (button ~= 'RightButton') then return end

	local collapsed = self:IsCategoryCollapsed(info.categoryID)
	local subCat = C_TradeSkillUI.GetSubCategories(info.categoryID)
	if subCat then
		collapsed = not self:IsCategoryCollapsed(subCat)
	end

	local allCategories = {C_TradeSkillUI.GetCategories()}
	for _, catId in pairs(allCategories) do
		local subCategories = {C_TradeSkillUI.GetSubCategories(catId)}
		if #subCategories == 0 then
			self.collapsedCategories[catId] = collapsed
		else
			self.collapsedCategories[catId] = false
			for _, subId in pairs(subCategories) do
				self.collapsedCategories[subId] = collapsed
			end
		end
	end
	self:Refresh()
end)


--- Druid Unshapeshift ---
local function injectDruidButtons()
	local _, class = UnitClass('player')
	if (class ~= 'DRUID') then return end

	local function injectMacro(button, text)
		local macro = CreateFrame('Button', nil, button:GetParent(), 'MagicButtonTemplate, SecureActionButtonTemplate')
		macro:SetAttribute('type', 'macro')
		macro:SetAttribute('macrotext', SLASH_CANCELFORM1)
		macro:SetPoint(button:GetPoint())
		macro:SetFrameStrata('HIGH')
		macro:SetText(text)

		if (skinUI == 'Aurora') then
			loadedUI.Reskin(macro)
		elseif (skinUI == 'ElvUI') then
			loadedUI:HandleButton(macro, true)
		end

		macro:HookScript('OnClick', button:GetScript('OnClick'))
		button:HookScript('OnDisable', function()
			button:SetAlpha(1)
			macro:SetAlpha(0)
			macro:RegisterForClicks(nil)
		end)
		button:HookScript('OnEnable', function()
			button:SetAlpha(0)
			macro:SetAlpha(1)
			macro:RegisterForClicks('LeftButtonDown')
		end)
	end
	injectMacro(TradeSkillFrame.DetailsFrame.CreateButton, CREATE_PROFESSION)
	injectMacro(TradeSkillFrame.DetailsFrame.CreateAllButton, CREATE_ALL)
end


--- Warning Dialog ---
StaticPopupDialogs['CTRADESKILL_WARNING'] = {
	text = UNLOCK_FRAME .. ' ' .. REQUIRES_RELOAD:lower() .. '!\n',
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function()
		CTradeSkillDB['Unlock'] = not CTradeSkillDB['Unlock']
		ReloadUI()
	end,
	OnShow = function()
		_G['CTSOption']:Disable()
	end,
	OnHide = function()
		_G['CTSOption']:Enable()
	end,
	timeout = 0,
	exclusive = 1,
	preferredIndex = 3,
}


--- Dropdown Menu ---
local function CTSDropdown_Init(self, level)
	local info = UIDropDownMenu_CreateInfo()
	if level == 1 then
		info.text = f:GetName()
		info.isTitle = true
		info.notCheckable = true
		UIDropDownMenu_AddButton(info, level)

		info.isTitle = false
		info.disabled = false
		info.isNotRadio = true
		info.notCheckable = false

		info.text = UNLOCK_FRAME
		info.func = function()
			StaticPopup_Show('CTRADESKILL_WARNING')
		end
		info.checked = CTradeSkillDB['Unlock']
		UIDropDownMenu_AddButton(info, level)

		info.text = STAT_AVERAGE_ITEM_LEVEL
		info.func = function()
			CTradeSkillDB['Level'] = not CTradeSkillDB['Level']
			TradeSkillFrame.RecipeList:Refresh()
		end
		info.keepShownOnClick = true
		info.checked = CTradeSkillDB['Level']
		UIDropDownMenu_AddButton(info, level)

		info.text = DISPLAY .. ' ' .. INFO
		info.func = function()
			CTradeSkillDB['Tooltip'] = not CTradeSkillDB['Tooltip']
		end
		info.keepShownOnClick = true
		info.checked = CTradeSkillDB['Tooltip']
		UIDropDownMenu_AddButton(info, level)

		info.func = nil
		info.checked = 	nil
		info.notCheckable = true
		info.hasArrow = true

		info.text = PRIMARY
		info.value = 1
		info.disabled = UnitAffectingCombat('player')
		UIDropDownMenu_AddButton(info, level)

		info.text = SECONDARY
		info.value = 2
		info.disabled = UnitAffectingCombat('player')
		UIDropDownMenu_AddButton(info, level)
	elseif level == 2 then
		info.isNotRadio = true
		info.keepShownOnClick = true
		if UIDROPDOWNMENU_MENU_VALUE == 1 then
			for i = 1, numTabs do
				local tab = _G['CTradeSkillTab' .. i]
				if tab and (tab.isSub == 0) then
					info.text = tab.tooltip
					info.func = function()
						CTradeSkillDB['Tabs'][tab.id] = not CTradeSkillDB['Tabs'][tab.id]
						sortTabs()
					end
					info.checked = CTradeSkillDB['Tabs'][tab.id]
					UIDropDownMenu_AddButton(info, level)
				end
			end
		elseif UIDROPDOWNMENU_MENU_VALUE == 2 then
			for i = 1, numTabs do
				local tab = _G['CTradeSkillTab' .. i]
				if tab and (tab.isSub == 1) then
					info.text = tab.tooltip
					info.func = function()
						CTradeSkillDB['Tabs'][tab.id] = not CTradeSkillDB['Tabs'][tab.id]
						sortTabs()
					end
					info.checked = CTradeSkillDB['Tabs'][tab.id]
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end
	end
end


--- Create Option Menu ---
local function createOptions()
	if not _G['CTSDropdown'] then
		local menu = CreateFrame('Frame', 'CTSDropdown', TradeSkillFrame, 'UIDropDownMenuTemplate')
		UIDropDownMenu_Initialize(CTSDropdown, CTSDropdown_Init, 'MENU')
	end

	--- Option Button ---
	local button = CreateFrame('Button', 'CTSOption', TradeSkillFrame, 'UIPanelButtonTemplate')
	button:SetScript('OnClick', function(self) ToggleDropDownMenu(1, nil, CTSDropdown, self, 2, -6) end)
	button:SetPoint('RIGHT', TradeSkillFrameCloseButton, 'LEFT', 3.5, 0.4)
	button:SetFrameStrata('HIGH')
	button:SetText('CTS')
	button:SetSize(38, 22)

	if (skinUI == 'Aurora') then
		loadedUI.Reskin(button)
	elseif (skinUI == 'ElvUI') then
		button:StripTextures(true)
		button:CreateBackdrop('Default', true)
		button.backdrop:SetAllPoints()
	end
end


--- Force ESC Close ---
hooksecurefunc('ToggleGameMenu', function()
	if CTradeSkillDB['Unlock'] and TradeSkillFrame:IsShown() then
		C_TradeSkillUI.CloseTradeSkill()
		HideUIPanel(GameMenuFrame)
	end
end)


--- Handle Events ---
f:SetScript('OnEvent', function(self, event, ...)
	if (event == 'PLAYER_LOGIN') then
		InitDB()
		updateSize(true)
		updatePosition()
		updateTabs(true)
		createMoveBar()
		createResizeBar()
		createBookmarks()
		createOptions()
		injectDruidButtons()
	elseif (event == 'TRADE_SKILL_DATA_SOURCE_CHANGED') then
		if UnitAffectingCombat('player') then
			delay = true
		else
			updateTabs()
		end
	elseif (event == 'PLAYER_REGEN_ENABLED') then
		if delay then
			updateTabs()
			delay = false
		end
	end
end)
