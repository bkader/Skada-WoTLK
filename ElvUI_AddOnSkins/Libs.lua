local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

local _G = _G
local ipairs = ipairs
local select = select
local unpack = unpack

local hooksecurefunc = hooksecurefunc

AS.skinnedLibs = {}

local dropdownArrowColor = {1, 0.8, 0}

local function SkinDewdrop(lib, libName)
	local dewdropEditBoxFrame
	local dewdropSliderFrame

	local function DewdropOpen(prefix)
		local level = prefix.."Level"
		local button = prefix.."Button"

		local i = 1
		local frame = _G[level .. i]

		while frame do
			if not frame.isSkinned then
				frame:SetTemplate("Transparent")

				frame:GetChildren():Hide()
				frame.SetBackdropColor = E.noop
				frame.SetBackdropBorderColor = E.noop

				frame.isSkinned = true
			end

			i = i + 1
			frame = _G[level .. i]
		end

		i = 1
		frame = _G[button .. i]

		while frame do
			if not frame.isHook then
				frame:HookScript("OnEnter", function(self)
					if not self.disabled and self.hasArrow then
						if not dewdropEditBoxFrame and self.hasEditBox then
							dewdropEditBoxFrame = AS:FindFrameBySizeChild({"EditBox"}, 200, 40)

							if dewdropEditBoxFrame then
								dewdropEditBoxFrame:SetTemplate("Transparent")
								S:HandleEditBox(dewdropEditBoxFrame.editBox)
								dewdropEditBoxFrame.editBox:DisableDrawLayer("BACKGROUND")
							end
						end
						if not dewdropSliderFrame and self.hasSlider then
							dewdropSliderFrame = AS:FindFrameBySizeChild({"Slider", "EditBox"}, 100, 170)

							if dewdropSliderFrame then
								dewdropSliderFrame:SetTemplate("Transparent")
								S:HandleSliderFrame(dewdropSliderFrame.slider)
								S:HandleEditBox(dewdropSliderFrame.currentText)
								dewdropSliderFrame.currentText:DisableDrawLayer("BACKGROUND")
							end
						end

						DewdropOpen(prefix)
					end
				end)

				frame.isHook = true
			end

			i = i + 1
			frame = _G[button .. i]
		end
	end

	if not S:IsHooked(lib, "Open") then
		S:SecureHook(lib, "Open", function()
			DewdropOpen(libName == "Dewdrop-2.0" and "Dewdrop20" or "ArkDewdrop30")
		end)
	end

	return true
end

local function SkinTablet2(lib)
	local function SkinDetachedFrame(self, fakeParent, parent)
		if not parent then
			parent = fakeParent
		end
		if self.registry[parent].data.detached then
			local i = 1
			local frame = _G["Tablet20DetachedFrame" .. i]

			while frame do
				if not frame.isSkinned then
					frame:SetTemplate("Transparent")
					S:HandleSliderFrame(frame.slider)

					frame.isSkinned = true
				end

				i = i + 1
				frame = _G["Tablet20DetachedFrame" .. i]
			end
		end
	end

	if not S:IsHooked(lib, "Open") then
		S:SecureHook(lib, "Open", function(self, fakeParent, parent)
			_G["Tablet20Frame"]:SetTemplate("Transparent")
			SkinDetachedFrame(self, fakeParent, parent)
		end)
	end

	if not S:IsHooked(lib, "Detach") then
		S:SecureHook(lib, "Detach", function(self, parent)
			SkinDetachedFrame(self, parent)
		end)
	end

	return true
end

local function SkinLibRockConfig(lib)
	local function SkinMainFrame(self)
		if self.base.isSkinned then return end

		self.base:SetTemplate("Transparent")
		self.base.header:StripTextures()
		S:HandleCloseButton(self.base.closeButton, self.base)

		self.base.treeView:SetTemplate("Transparent")
		S:HandleScrollBar(self.base.treeView.scrollBar)
		S:HandleDropDownBox(self.base.addonChooser)

		self.base.addonChooser.text:Height(20)
		self.base.addonChooser.text:SetTemplate("Transparent")
		S:HandleNextPrevButton(self.base.addonChooser.button)

		local pullout = _G[self.base.mainPane:GetName().."_ChoicePullout"]
		if pullout then
			pullout:SetTemplate("Transparent")
		else
			S:SecureHookScript(self.base.addonChooser.button, "OnClick", function(self)
				_G[lib.base.mainPane:GetName().."_ChoicePullout"]:SetTemplate("Transparent")
				S:Unhook(self, "OnClick")
			end)
		end

		self.base.mainPane:SetTemplate("Transparent")
		S:HandleScrollBar(self.base.mainPane.scrollBar)

		self.base.treeView.sizer:SetTemplate("Transparent")

		self.base.isSkinned = true
	end

	S:SecureHook(lib, "OpenConfigMenu", function(self)
		SkinMainFrame(self)
		S:Unhook(self, "OpenConfigMenu")
	end)

	local LR = LibStub("LibRock-1.0", true)
	if LR then
		for object in LR:IterateMixinObjects("LibRockConfig-1.0") do
			if not S:IsHooked(object, "OpenConfigMenu") then
				S:SecureHook(object, "OpenConfigMenu", function(self)
					SkinMainFrame(lib)
					S:Unhook(self, "OpenConfigMenu")
				end)
			end
		end
	end

	return true
end

local function SkinConfigator(lib)
	local function skinSlider(obj)
		obj:StripTextures()
		obj:SetTemplate("Default")
		obj:Height(12)
		obj:SetThumbTexture(E.media.blankTex)
		obj:GetThumbTexture():SetVertexColor(0.3, 0.3, 0.3)
		obj:GetThumbTexture():Size(10)
	end

	local function skinEditBox(obj)
		if not obj then return end

		local objName = obj:GetName()
		if objName then
			_G[objName.."Left"]:Kill()
			_G[objName.."Middle"]:Kill()
			_G[objName.."Right"]:Kill()
		end

		obj:Height(17)
		obj:CreateBackdrop("Default")
		obj.backdrop:Point("TOPLEFT", -2, 0)
		obj.backdrop:Point("BOTTOMRIGHT", 2, 0)
		obj.backdrop:SetParent(obj:GetParent())
		obj:SetParent(obj.backdrop)
	end

	local function skinObject(obj)
		if not obj then return end

		local objType = obj:GetObjectType()

	--	if objType == "FontString" then
		if objType == "CheckButton" then
			S:HandleCheckBox(obj, true)
		elseif objType == "Slider" then
			skinSlider(obj)

			if obj.slave then
				skinEditBox(obj.slave)
			end
		elseif objType == "EditBox" then
			skinEditBox(obj)
		elseif objType == "Button" then
			S:HandleButton(obj, true)
		elseif objType == "Frame" then
			if obj.stype == "SelectBox" then
				obj:StripTextures()
				obj:SetTemplate("Default")
				obj:Size(159, 22)
				local _, _, _, x = obj:GetPoint(2)
				obj:Point("LEFT", x + 15, 0)

				_G[obj:GetName().."Text"]:Point("RIGHT", -26, 0)

				S:HandleNextPrevButton(obj.button, "down", dropdownArrowColor)
				obj.button:Point("TOPRIGHT", -2, -2)
			elseif obj.stype == "MoneyFrame"
			or obj.stype == "PinnedMoney"
			or obj.stype == "MoneyFramePinned" then
				local objName = obj:GetName()
				if objName then
					skinEditBox(_G[objName.."Gold"])
					skinEditBox(_G[objName.."Silver"])
					skinEditBox(_G[objName.."Copper"])
				else
					for i = 1, obj:GetNumChildren() do
						local child = select(i, obj:GetChildren())
						if child and child:IsObjectType("EditBox") then
							skinEditBox(child)
						end
					end
				end
			end
		end
	end

	local function fullsizeSetNormalTexture(self, texture)
		if texture == "Interface\\Minimap\\UI-Minimap-ZoomInButton-Up" then
			self.normalTexture:SetTexture(E.Media.Textures.Plus)
			self.pushedTexture:SetTexture(E.Media.Textures.Plus)
		else
			self.normalTexture:SetTexture(E.Media.Textures.Minus)
			self.pushedTexture:SetTexture(E.Media.Textures.Minus)
		end
	end
	local function skinTab(self)
		local frame = self.tabs[#self.tabs].frame

		frame:SetTemplate("Default")

		S:HandleButton(frame.fullsize)
		frame.fullsize:Size(18)
		frame.fullsize:Point("BOTTOMLEFT", 4, 4)

		frame.fullsize.normalTexture = frame.fullsize:GetNormalTexture()
		frame.fullsize.pushedTexture = frame.fullsize:GetPushedTexture()

		frame.fullsize.SetNormalTexture = fullsizeSetNormalTexture
		frame.fullsize:SetNormalTexture(frame.fullsize.normalTexture:GetTexture())

		frame.fullsize:SetHighlightTexture("")
		frame.fullsize.SetPushedTexture = E.noop
		frame.fullsize.SetHighlightTexture = E.noop
	end

	local function skinScroll(self, id)
		local tab = self.tabs[id]
		if tab.scroll.isSkinned then return end

		if tab.scroll.vScroll then
			S:HandleScrollBar(tab.scroll.vScroll)
			tab.scroll.vScroll:Point("TOPLEFT", tab.scroll, "TOPRIGHT", 3, -16)
			tab.scroll.vScroll:Point("BOTTOMLEFT", tab.scroll, "BOTTOMRIGHT", 3, 14)
		end
		if tab.scroll.hScroll then
			S:HandleScrollBar(tab.scroll.hScroll, true)
			tab.scroll.hScroll:Point("TOPLEFT", tab.scroll, "BOTTOMLEFT", 18, -3)
			tab.scroll.hScroll:Point("TOPRIGHT", tab.scroll, "BOTTOMRIGHT", -19, -3)
		end

		tab.scroll.isSkinned = true
	end

	local function skinControl(self, id, cType, ...)
		local obj = S.hooks[self].AddControl(self, id, cType, ...)

		skinObject(obj)

		return obj
	end

	S:RawHook(lib, "Create", function(self, ...)
		local gui = S.hooks[self].Create(self, ...)

		gui.Backdrop:SetTemplate("Transparent")

		gui.DragTop:Point("TOPLEFT", 10, -1)
		gui.DragTop:Point("TOPRIGHT", -10, -1)

		gui.DragBottom:Point("BOTTOMLEFT", 10, 1)
		gui.DragBottom:Point("BOTTOMRIGHT", -10, 1)

		S:HandleButton(gui.Done)
		gui.Done:Point("BOTTOMRIGHT", gui, "BOTTOMRIGHT", -8, 8)

		hooksecurefunc(gui, "AddTab", skinTab)
		hooksecurefunc(gui, "MakeScrollable", skinScroll)
		S:RawHook(gui, "AddControl", skinControl)

		return gui
	end)

	if #lib.frames > 0 then
		for _, frame in ipairs(lib.frames) do
			frame.Backdrop:SetTemplate("Transparent")
			S:HandleButton(frame.Done)

			for _, tab in ipairs(frame.tabs) do
				if tab.frame then
					tab.frame:SetTemplate("Transparent")
				end

				if tab.scroll then
					if tab.scroll.vScroll then
						S:HandleScrollBar(tab.scroll.vScroll)
						tab.scroll.vScroll:Point("TOPLEFT", tab.scroll, "TOPRIGHT", 3, -16)
						tab.scroll.vScroll:Point("BOTTOMLEFT", tab.scroll, "BOTTOMRIGHT", 3, 14)
					end
					if tab.scroll.hScroll then
						S:HandleScrollBar(tab.scroll.hScroll, true)
						tab.scroll.hScroll:Point("TOPLEFT", tab.scroll, "BOTTOMLEFT", 18, -3)
						tab.scroll.hScroll:Point("TOPRIGHT", tab.scroll, "BOTTOMRIGHT", -19, -3)
					end
				end

				if tab.frame.ctrls then
					for _, entry in ipairs(tab.frame.ctrls) do
						for _, object in ipairs(entry.kids) do
							skinObject(object)
						end
					end
				end
			end
		end
	end

	do	-- tooltip
		lib.tooltip:SetTemplate("Transparent")
		lib.tooltip._SetBackdropColor = lib.tooltip.SetBackdropColor
		lib.tooltip.SetBackdropColor = function(self)
			self:SetBackdropBorderColor(unpack(E.media.bordercolor, 1, 3))
			local r, g, b = unpack(E.media.backdropfadecolor, 1, 3)
			self:_SetBackdropColor(r, g, b, E.db.tooltip.colorAlpha)
		end
	end

	do	-- help
		lib.help:SetTemplate("Transparent")

		lib.help.scroll:SetTemplate("Transparent")
		lib.help.scroll:Point("TOPLEFT", 8, -25)
		lib.help.scroll:Point("BOTTOMRIGHT", -29, 8)

		lib.help.content:Width(416)

		S:HandleScrollBar(lib.help.scroll.vScroll)
		lib.help.scroll.vScroll:Point("TOPLEFT", lib.help.scroll, "TOPRIGHT", 3, -19)
		lib.help.scroll.vScroll:Point("BOTTOMLEFT", lib.help.scroll, "BOTTOMRIGHT", 3, 19)

		S:HandleCloseButton(lib.help.close)
	end

	local SelectBox = LibStub("SelectBox", true)
	if SelectBox then
		SelectBox.menu.back:SetTemplate("Transparent")
		SelectBox.menu.isSkinned = true
	end

	local ScrollSheet = LibStub("ScrollSheet", true)
	if ScrollSheet then
		S:RawHook(ScrollSheet, "Create", function(self, ...)
			local sheet = S.hooks[self].Create(self, ...)

			if not sheet.panel.isSkinned then
				if sheet.panel.vScroll then
					S:HandleScrollBar(sheet.panel.vScroll)
					sheet.panel.vScroll:Point("TOPLEFT", sheet.panel, "TOPRIGHT", 3, -18)
					sheet.panel.vScroll:Point("BOTTOMLEFT", sheet.panel, "BOTTOMRIGHT", 3, 19)
				end
				if sheet.panel.hScroll then
					S:HandleScrollBar(sheet.panel.hScroll, true)
					sheet.panel.hScroll:Point("TOPLEFT", sheet.panel, "BOTTOMLEFT", 18, -3)
					sheet.panel.hScroll:Point("TOPRIGHT", sheet.panel, "BOTTOMRIGHT", -19, -3)
				end

				sheet.panel.isSkinned = true
			end

			return sheet
		end, true)
	end

	return true
end

local function SkinAceAddon20(lib)
	S:SecureHook(lib.prototype, "PrintAddonInfo", function()
		AceAddon20AboutFrame:SetTemplate("Transparent")
		S:HandleButton(AceAddon20AboutFrameButton)
		S:HandleButton(AceAddon20AboutFrameDonateButton)

		S:Unhook(lib.prototype, "PrintAddonInfo")
	end)

	S:SecureHook(lib.prototype, "OpenDonationFrame", function()
		AceAddon20Frame:SetTemplate("Transparent")
		S:HandleScrollBar(AceAddon20FrameScrollFrameScrollBar)
		S:HandleButton(AceAddon20FrameButton)

		S:Unhook(lib.prototype, "OpenDonationFrame")
	end)

	return true
end

local function SkinAzDialog(libName)
	local lib = _G[libName]
	if not lib then return end

	local function skinDialog(frame)
		if frame.isSkinned then return end

		frame:SetTemplate("Transparent")

		frame.edit:SetBackdrop(nil)
		S:HandleEditBox(frame.edit)

		S:HandleButton(frame.ok)
		S:HandleButton(frame.cancel)

		frame.isSkinned = true
	end

	for _, frame in ipairs(lib.dialogs) do
		skinDialog(frame)
	end

	S:SecureHook(lib, "Show", function(self)
		skinDialog(self.dialogs[#self.dialogs])
	end)

	return true
end

local function SkinAzDropDown(libName)
	local lib = _G[libName]
	if not lib then return end

	S:RawHook(lib, "CreateDropDown", function(parent, ...)
		local f = S.hooks[lib].CreateDropDown(parent, ...)

		f:SetTemplate()

		S:HandleNextPrevButton(f.button, "down", dropdownArrowColor)
		f.button:Point("TOPRIGHT", -2, -2)
		f.button:Point("BOTTOMRIGHT", -2, 2)
		f.button:Size(20)

		return f
	end)

	S:SecureHook(lib, "ToggleMenu", function(parent, width, isAutoSelect, initFunc, selectValueFunc)
		local scrollFrame = _G["AzDropDownScroll"..lib.vers]
		if scrollFrame then
			scrollFrame:GetParent():SetTemplate("Default")
			S:HandleScrollBar(_G["AzDropDownScroll"..lib.vers.."ScrollBar"])

			S:Unhook(lib, "ToggleMenu")
		end
	end)

	return true
end

local function SkinAzOptionsFactory(libName)
	local lib = _G[libName]
	if not lib then return end

	AS:SkinLibrary("AzDropDown")

	S:RawHook(lib.makers, "Slider", function(self)
		local f = S.hooks[lib.makers].Slider(self)

		S:HandleEditBox(f.edit)
		S:HandleSliderFrame(f.slider)

		f.slider:Point("TOPLEFT", f.edit, "TOPRIGHT", 5, -10)
		f.slider:Point("BOTTOMRIGHT", 0, -1)

		return f
	end)

	S:RawHook(lib.makers, "Check", function(self)
		local f = S.hooks[lib.makers].Check(self)

		S:HandleCheckBox(f)

		return f
	end)

	S:RawHook(lib.makers, "Color", function(self)
		local f = S.hooks[lib.makers].Color(self)

		S:HandleColorSwatch(f)

		return f
	end)

	S:RawHook(lib.makers, "Text", function(self)
		local f = S.hooks[lib.makers].Text(self)

		f:SetBackdrop(nil)

		f:CreateBackdrop()
		f.backdrop:SetFrameLevel(f:GetFrameLevel())

		f.backdrop:Point("TOPLEFT", 2, -2)
		f.backdrop:Point("BOTTOMRIGHT", -2, 2)

		return f
	end)

	return true
end

local function SkinLibExtraTip(lib)
	S:RawHook(lib, "GetFreeExtraTipObject", function(self)
		local tooltip = S.hooks[self].GetFreeExtraTipObject(self)

		if not tooltip.isSkinned then
			tooltip:SetTemplate("Transparent")
			tooltip.isSkinned = true
		end

		return tooltip
	end)

	return true
end

local function SkinZFrame(lib)
	S:RawHook(lib, "Create", function(self, ...)
		local frame = S.hooks[self].Create(self, ...)

		frame.ZMain:SetTemplate("Transparent")
		frame.ZMain.close:Size(32)
		S:HandleCloseButton(frame.ZMain.close, frame.ZMain)

		return frame
	end, true)

	return true
end

local function SkinLibCandyBar(lib)
	local offset = E:Scale(E.PixelMode and 1 or 3)
	local function setPoint(self, point, attachTo, anchorPoint, xOffset, yOffset)
		if (point == "BOTTOMLEFT" and yOffset ~= offset) or (point == "TOPLEFT" and yOffset ~= -offset) then
			self:Point(point, attachTo, anchorPoint, 0, point == "BOTTOMLEFT" and offset or -offset)
		end
	end

	local function skinBar(bar)
		if not bar.isSkinned then
			bar:CreateBackdrop("Transparent")
			hooksecurefunc(bar, "SetPoint", setPoint)
			bar.isSkinned = true
		end
	end

	for _, bar in ipairs(lib.availableBars) do
		skinBar(bar)
	end

	S:RawHook(lib, "New", function(self, ...)
		local bar = S.hooks[self].New(self, ...)
		skinBar(bar)
		return bar
	end)

	return true
end

local function SkinLibDialog(lib)
	local function skinDialog(dialog)
		if not dialog.isSkinned then
			dialog:SetTemplate("Transparent")
			dialog.SetBackdrop = E.noop
			S:HandleCloseButton(dialog.close_button, dialog)

			dialog.isSkinned = true
		end

		if dialog.checkboxes then
			for _, checkbox in ipairs(dialog.checkboxes) do
				S:HandleCheckBox(checkbox)
			end
		end

		if dialog.editboxes then
			for _, editbox in ipairs(dialog.editboxes) do
				S:HandleEditBox(editbox)
				editbox:Height(20)
			end
		end

		if dialog.buttons then
			for _, button in ipairs(dialog.buttons) do
				S:HandleButton(button)
			end
		end
	end

	for _, dialog in ipairs(lib.active_dialogs) do
		skinDialog(dialog)
	end

	S:RawHook(lib, "Spawn", function(self, ...)
		local dialog = S.hooks[self].Spawn(self, ...)

		if dialog then
			skinDialog(dialog)
			return dialog
		end
	end)

	return true
end

local function SkinScrollingTable(lib)
	local function updateRows(self, num)
		if num and num > 0 and #self.rows ~= 0 then
			self.rows[1]:Point("TOPRIGHT", self.frame, "TOPRIGHT", -21, -5)
		end
	end

	S:RawHook(lib, "CreateST", function(self, ...)
		local st = S.hooks[self].CreateST(self, ...)

		st.frame:SetTemplate("Transparent")

		local frameName = st.frame:GetName()
		local scrollbar = _G[frameName .. "ScrollFrameScrollBar"]
		scrollbar:Point("TOPLEFT", st.scrollframe, "TOPRIGHT", 6, -17)
		scrollbar:Point("BOTTOMLEFT", st.scrollframe, "BOTTOMRIGHT", 6, 18)
		S:HandleScrollBar(scrollbar)

		_G[frameName .. "ScrollTrough"]:Kill()
		_G[frameName .. "ScrollTroughBorder"]:Kill()

		updateRows(st, st.displayRows)
		S:SecureHook(st, "SetDisplayRows", updateRows)

		return st
	end)

	return true
end

local function SkinDropDownMenu(libName)
	if not _G.Lib_UIDropDownMenu_Initialize then return end

	local checkBoxSkin = E.private.skins.dropdownCheckBoxSkin
	local menuLevel = 0
	local maxButtons = 0

	local function dropDownButtonShow(self)
		if self.notCheckable then
			self.check.backdrop:Hide()
		else
			self.check.backdrop:Show()
		end
	end

	local function skinDropdownMenu()
		local updateButtons = maxButtons < LIB_UIDROPDOWNMENU_MAXBUTTONS

		if updateButtons or menuLevel < LIB_UIDROPDOWNMENU_MAXLEVELS then
			for i = 1, LIB_UIDROPDOWNMENU_MAXLEVELS do
				local frame = _G["Lib_DropDownList"..i]

				if not frame.isSkinned then
					_G["Lib_DropDownList"..i.."Backdrop"]:SetTemplate("Transparent")
					_G["Lib_DropDownList"..i.."MenuBackdrop"]:SetTemplate("Transparent")

					frame.isSkinned = true
				end

				if updateButtons then
					for j = 1, LIB_UIDROPDOWNMENU_MAXBUTTONS do
						local button = _G["Lib_DropDownList"..i.."Button"..j]

						if not button.isSkinned then
							S:HandleButtonHighlight(_G["Lib_DropDownList"..i.."Button"..j.."Highlight"])

							if checkBoxSkin then
								local check = _G["Lib_DropDownList"..i.."Button"..j.."Check"]
								check:Size(12)
								check:Point("LEFT", 1, 0)
								check:CreateBackdrop()
								check:SetTexture(E.media.normTex)
								check:SetVertexColor(1, 0.82, 0, 0.8)

								button.check = check
								hooksecurefunc(button, "Show", dropDownButtonShow)
							end

							S:HandleColorSwatch(_G["Lib_DropDownList"..i.."Button"..j.."ColorSwatch"], 14)

							button.isSkinned = true
						end
					end
				end
			end

			menuLevel = LIB_UIDROPDOWNMENU_MAXLEVELS
			maxButtons = LIB_UIDROPDOWNMENU_MAXBUTTONS
		end
	end

	skinDropdownMenu()
	hooksecurefunc("Lib_UIDropDownMenu_InitializeHelper", skinDropdownMenu)

	return true
end

local function SkinLibQTip(lib)
	hooksecurefunc(lib, "Acquire", function(self, key)
		if self.activeTooltips[key] then
			self.activeTooltips[key]:SetTemplate("Transparent")
		end
	end)

	S:Hook(lib.LabelPrototype, "SetupCell", function(self)
		self.fontString:FontTemplate()
	end)

	hooksecurefunc(lib.tipPrototype, "UpdateScrolling", function(self)
		if self.slider and not self.slider.isSkinned then
			S:HandleSliderFrame(self.slider)
			self.slider.isSkinned = true
		end
	end)

	return true
end

local function SkinWaterfall(lib)
	hooksecurefunc(WaterfallFrame.prototype, "init", function(self)
		self.frame:SetTemplate("Transparent")

		self.titlebar:SetDrawLayer("ARTWORK")
		self.titlebar2:SetDrawLayer("ARTWORK")

		self.titlebar:Point("TOPLEFT", self.frame, "TOPLEFT", 4, -4)
		self.titlebar:Point("TOPRIGHT", self.frame, "TOPRIGHT", -4, -4)

		S:HandleCloseButton(self.closebutton)
		self.closebutton:SetPoint("TOPRIGHT", 0, 0)

		self.treeview:Point("TOPLEFT", self.frame, "TOPLEFT", 8, -33)
		self.treeview:Point("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 8, 8)

		self.mainpane:Point("TOPLEFT", self.treeview.frame, "TOPRIGHT", 3, 0)
		self.mainpane:Point("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -8, 8)
	end)
	S:RawHook(WaterfallFrame.prototype, "ReAnchorTree", function(self)
		self.treeview:Point("TOPLEFT", self.frame, "TOPLEFT", 8, -33)
		self.treeview:Point("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 8, 8)
	end)

	hooksecurefunc(WaterfallPane.prototype, "init", function(self, parent)
		self.frame:SetTemplate("Transparent")

		self.titlebar:SetDrawLayer("ARTWORK")
		self.titlebar2:SetDrawLayer("ARTWORK")

		S:HandleScrollBar(self.scrollbar)
	end)

	hooksecurefunc(WaterfallTreeView.prototype, "init", function(self, parent)
		self.frame:SetTemplate("Transparent")

		S:HandleScrollBar(self.scrollbar)

		self.sizer:ClearAllPoints()
		self.sizer:Point("TOPLEFT", self.frame, "TOPRIGHT", -2, 0)
		self.sizer:Point("BOTTOMLEFT", self.frame, "BOTTOMRIGHT", -2, 0)
	end)
	hooksecurefunc(WaterfallTreeLine.prototype, "init", function(self)
		S:HandleCollapseExpandButton(self.expand)
	end)
	hooksecurefunc(WaterfallTreeSection.prototype, "init", function(self, parent)
		self.frame:SetTemplate("Transparent")

		self.titlebar:SetDrawLayer("ARTWORK")
		self.titlebar2:SetDrawLayer("ARTWORK")

		self.titlebar:Point("TOPLEFT", self.frame, "TOPLEFT", 4, -4)
		self.titlebar:Point("TOPRIGHT", self.frame, "TOPRIGHT", -4, -4)

		S:HandleCloseButton(self.closebutton)
		self.closebutton:SetPoint("TOPRIGHT", 0, 0)
	end)

	hooksecurefunc(WaterfallColorSwatch.prototype, "init", function(self)
		self.frame:CreateBackdrop("Default")
		self.frame.backdrop:SetOutside(self.colorSwatch)

		self.colorSwatch:SetTexture(nil)
		self.colorSwatch:Size(18)

		self.colorSwatch.texture:SetParent(self.frame.backdrop)
		self.colorSwatch.texture:SetInside()

		self.text:Point("LEFT", self.colorSwatch, "RIGHT", 4, 0)
		self.text.SetPoint = E.noop
	end)

	hooksecurefunc(WaterfallCheckBox.prototype, "init", function(self)
		self.frame:CreateBackdrop("Default")
		self.frame.backdrop:SetOutside(self.checkbg)

		self.checkbg:Hide()
		self.checkbg:Size(18)

		self.check:SetParent(self.frame.backdrop)
		self.check:SetAllPoints()

		self.text:Point("LEFT", self.check, "RIGHT", 3, 0)
		self.text.SetPoint = E.noop
	end)
	hooksecurefunc(WaterfallCheckBox.prototype, "UpdateTexture", function(self)
		if self.isRadio then
			self.frame.backdrop:Hide()
			self.checkbg:Show()
		else
			self.frame.backdrop:Show()
			self.checkbg:Hide()
		end
	end)

	hooksecurefunc(WaterfallDragLink.prototype, "init", function(self)
		self.frame:CreateBackdrop("Default")
		self.frame.backdrop:ClearAllPoints()
		self.frame.backdrop:SetPoint("LEFT")
		self.frame.backdrop:Width(self.iconWidth or WaterfallDragLink.defaultIconSize)
		self.frame.backdrop:Height(self.iconHeight or WaterfallDragLink.defaultIconSize)

		self.linkIcon:SetParent(self.frame.backdrop)
		self.linkIcon:SetInside()
		self.linkIcon:SetTexCoord(unpack(E.TexCoords))
	end)

	hooksecurefunc(WaterfallButton.prototype, "init", function(self)
		S:HandleButton(self.frame)
	end)

	hooksecurefunc(WaterfallKeybinding.prototype, "init", function(self)
		S:HandleButton(self.frame)
		self.msgframe:SetTemplate("Transparent")
	end)

	hooksecurefunc(WaterfallSlider.prototype, "init", function(self)
		S:HandleSliderFrame(self.slider)
	end)

	hooksecurefunc(WaterfallTextBox.prototype, "init", function(self)
		self.frame:Height(22)
		self.frame:SetTemplate("Default")
	end)

	hooksecurefunc(WaterfallDropdown.prototype, "init", function(self)
		self.editbox:SetTemplate("Default")

		self.frame:Size(200, 20)
		self.frame.SetWidth = E.noop

		S:HandleNextPrevButton(self.button, "down", dropdownArrowColor)
		self.button:Size(16)
		self.button:Point("RIGHT", self.frame, "RIGHT", -22, 0)

		self.pullout:SetTemplate("Default")
	end)

	return true
end

local function SkinLDropDownMenu(lib)
	if not _G.L_UIDropDownMenu_Initialize then return end

	local checkBoxSkin = E.private.skins.dropdownCheckBoxSkin
	local menuLevel = 0
	local maxButtons = 0

	local function dropDownButtonShow(self)
		if self.notCheckable then
			self.check.backdrop:Hide()
		else
			self.check.backdrop:Show()
		end
	end

	local function skinL_DropDownMenu()
		local updateButtons = maxButtons < L_UIDROPDOWNMENU_MAXBUTTONS

		if updateButtons or menuLevel < L_UIDROPDOWNMENU_MAXLEVELS then
			for i = 1, L_UIDROPDOWNMENU_MAXLEVELS do
				local frame = _G["L_DropDownList" .. i]

				if frame and not frame.isSkinned then
					_G["L_DropDownList" .. i .. "Backdrop"]:SetTemplate("Transparent")
					_G["L_DropDownList" .. i .. "MenuBackdrop"]:SetTemplate("Transparent")

					frame.isSkinned = true
				end

				if updateButtons then
					for j = 1, L_UIDROPDOWNMENU_MAXBUTTONS do
						local button = _G["L_DropDownList" .. i .. "Button" .. j]

						if button and not button.isSkinned then
							S:HandleButtonHighlight(_G["L_DropDownList" .. i .. "Button" .. j .. "Highlight"])

							if checkBoxSkin then
								local check = _G["L_DropDownList" .. i .. "Button" .. j .. "Check"]
								check:Size(12)
								check:Point("LEFT", 1, 0)
								check:CreateBackdrop()
								check:SetTexture(E.media.normTex)
								check:SetVertexColor(1, 0.82, 0, 0.8)

								local uncheck = _G["L_DropDownList" .. i .. "Button" .. j .. "UnCheck"]
								uncheck:Size(12)
								uncheck:Point("LEFT", 1, 0)
								uncheck:CreateBackdrop()
								uncheck:SetTexture(nil)
								uncheck:SetVertexColor(1, 0.82, 0, 0.8)

								button.check = check
								hooksecurefunc(button, "Show", dropDownButtonShow)
							end

							button.isSkinned = true
						end
					end
				end
			end

			menuLevel = L_UIDROPDOWNMENU_MAXLEVELS
			maxButtons = L_UIDROPDOWNMENU_MAXBUTTONS
		end
	end

	skinL_DropDownMenu()
	hooksecurefunc("L_UIDropDownMenu_InitializeHelper", skinL_DropDownMenu)

	return true
end

AS.libSkins = {
	["AceAddon-2.0"] = {
		stub = true,
		func = SkinAceAddon20
	},
	["ArkDewdrop-3.0"] = {
		stub = true,
		func = SkinDewdrop
	},
	["AzDialog"] = {
		stub = false,
		func = SkinAzDialog
	},
	["AzDropDown"] = {
		stub = false,
		func = SkinAzDropDown
	},
	["AzOptionsFactory"] = {
		stub = false,
		func = SkinAzOptionsFactory
	},
	["Configator"] = {
		stub = true,
		func = SkinConfigator
	},
	["Dewdrop-2.0"] = {
		stub = true,
		func = SkinDewdrop
	},
	["DropDownMenu"] = {
		stub = false,
		func = SkinDropDownMenu
	},
	["LibCandyBar-3.0"] = {
		stub = true,
		func = SkinLibCandyBar
	},
	["LibDialog-1.0"] = {
		stub = true,
		func = SkinLibDialog
	},
	["LibExtraTip-1"] = {
		stub = true,
		func = SkinLibExtraTip
	},
	["LibRockConfig-1.0"] = {
		stub = true,
		func = SkinLibRockConfig
	},
	["LibQTip-1.0"] = {
		stub = true,
		func = SkinLibQTip
	},
	["ScrollingTable"] = {
		stub = true,
		func = SkinScrollingTable
	},
	["Tablet-2.0"] = {
		stub = true,
		func = SkinTablet2
	},
	["Waterfall-1.0"] = {
		stub = true,
		func = SkinWaterfall
	},
	["ZFrame-1.0"] = {
		stub = true,
		func = SkinZFrame
	},
	["LibUIDropDownMenu"] = {
		stub = true,
		func = SkinLDropDownMenu
	},
}

function AS:SkinLibrary(libName)
	if not libName or not self.libSkins[libName] then return end

	if self.libSkins[libName].stub then
		local lib, minor = LibStub(libName, true)
		if lib and (not self.skinnedLibs[libName] or self.skinnedLibs[libName] < minor) then
			if self.libSkins[libName].func(lib, libName) then
				self.skinnedLibs[libName] = minor or 1
				return true
			end
		end
	elseif not self.skinnedLibs[libName] then
		if self.libSkins[libName].func(libName) then
			self.skinnedLibs[libName] = true
			return true
		end
	end
end