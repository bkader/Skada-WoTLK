local Skada = Skada

local mod = Skada:NewModule("BarDisplay", "SpecializedLibBars-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Skada")
local ACR = LibStub("AceConfigRegistry-3.0")
local LibWindow = LibStub("LibWindow-1.1")
local FlyPaper = LibStub:GetLibrary("LibFlyPaper-1.1", true)

local pairs, ipairs, tsort, format = pairs, ipairs, table.sort, string.format
local GetSpellLink = Skada.GetSpellLink or GetSpellLink
local CloseDropDownMenus = L_CloseDropDownMenus or CloseDropDownMenus
local GetScreenWidth, GetScreenHeight = GetScreenWidth, GetScreenHeight
local white = {r = 0.9, g = 0.9, b = 0.9, a = 1}

mod.name = L["Bar display"]
mod.description = L["Bar display is the normal bar window used by most damage meters. It can be extensively styled."]
Skada:AddDisplaySystem("bar", mod)

-- class, role & specs
local classicons, roleicons, specicons
local classcoords, rolecoords, speccoords

local function WindowOnMouseDown(self, button)
	if IsShiftKeyDown() then
		Skada:OpenMenu(self.win)
	elseif button == "RightButton" and IsControlKeyDown() then
		Skada:SegmentMenu(self.win)
	elseif button == "RightButton" and IsAltKeyDown() then
		Skada:ModeMenu(self.win)
	elseif button == "RightButton" then
		self.win:RightClick()
	end
end

local function TitleButtonOnClick(self, button)
	local bargroup = self:GetParent()
	if not bargroup then return end
	if IsShiftKeyDown() then
		Skada:OpenMenu(bargroup.win)
	elseif button == "RightButton" and IsControlKeyDown() then
		Skada:SegmentMenu(bargroup.win)
	elseif button == "RightButton" and not IsAltKeyDown() then
		bargroup.win:RightClick()
	end
end

local buttonsTexPath = [[Interface\AddOns\Skada\Media\Textures\toolbar]]
local buttonsTexCoords = {
	{0.008, 0.117, 0.062, 0.938}, -- config
	{0.133, 0.242, 0.062, 0.938}, -- reset
	{0.258, 0.367, 0.062, 0.938}, -- segments
	{0.383, 0.492, 0.062, 0.938}, -- modes
	{0.508, 0.617, 0.062, 0.938}, -- report
	{0.633, 0.742, 0.062, 0.938} -- stop/resume
}

local function AddWindowButton(win, style, index, title, description, func)
	if win and win.AddButton then
		style, index = style or 1, index or 1
		local tex = buttonsTexPath .. style
		local texcoords = buttonsTexCoords[index]
		win:AddButton(title, description, tex, texcoords, func)
	end
end

function mod:Create(window)
	-- Re-use bargroup if it exists.
	local bargroup = mod:GetBarGroup(window.db.name)

	-- Save a reference to window in bar group. Needed for some nasty callbacks.
	if bargroup then
		-- Clear callbacks.
		bargroup.callbacks = LibStub:GetLibrary("CallbackHandler-1.0"):New(bargroup)
	else
		bargroup = mod:NewBarGroup(
			window.db.name,
			window.db.barorientation,
			window.db.background.height,
			window.db.barwidth,
			window.db.barheight,
			"SkadaBarWindow" .. window.db.name
		)

		bargroup:SetButtonsOpacity(window.db.title.toolbaropacity or 0.25)
		bargroup:SetButtonMouseOver(window.db.title.hovermode)

		-- Add window buttons.
		AddWindowButton(bargroup, window.db.title.toolbar, 1,
			L["Configure"], L["Opens the configuration window."],
			function(_, button)
				if button == "RightButton" then
					Skada:OpenOptions(bargroup.win)
				else
					Skada:OpenMenu(bargroup.win)
				end
			end
		)

		AddWindowButton(bargroup, window.db.title.toolbar, 2,
			RESET, L["Resets all fight data except those marked as kept."],
			function() Skada:ShowPopup(bargroup.win) end
		)

		AddWindowButton(bargroup, window.db.title.toolbar, 3,
			L["Segment"], L["Jump to a specific segment."],
			function(_, button)
				if button == "MiddleButton" then
					bargroup.win:set_selected_set("current")
				elseif IsModifierKeyDown() then
					bargroup.win:set_selected_set(nil, button == "RightButton" and 1 or -1)
				else
					Skada:SegmentMenu(bargroup.win)
				end
			end
		)

		AddWindowButton(bargroup, window.db.title.toolbar, 4,
			L["Mode"], L["Jump to a specific mode."],
			function() Skada:ModeMenu(bargroup.win) end
		)

		AddWindowButton(bargroup, window.db.title.toolbar, 5,
			L["Report"], L["Opens a dialog that lets you report your data to others in various ways."],
			function() Skada:OpenReportWindow(bargroup.win) end
		)

		AddWindowButton(bargroup, window.db.title.toolbar, 6,
			L["Stop"], L["Stops or resumes the current segment. Useful for discounting data after a wipe. Can also be set to automatically stop in the settings."],
			function()
				if Skada.current and Skada.current.stopped then
					Skada:ResumeSegment()
				elseif Skada.current then
					Skada:StopSegment()
				end
			end
		)
	end
	bargroup.win = window

	bargroup.RegisterCallback(mod, "BarClick")
	bargroup.RegisterCallback(mod, "BarEnter")
	bargroup.RegisterCallback(mod, "BarLeave")
	bargroup.RegisterCallback(mod, "AnchorMoved")
	bargroup.RegisterCallback(mod, "WindowResizing")
	bargroup.RegisterCallback(mod, "WindowResized")
	bargroup:EnableMouse(true)
	bargroup:SetScript("OnMouseDown", WindowOnMouseDown)
	bargroup.button:SetScript("OnClick", TitleButtonOnClick)
	bargroup:HideIcon()

	local titletext = bargroup.button:GetFontString()
	titletext:SetWordWrap(false)
	titletext:SetPoint("LEFT", bargroup.button, "LEFT", 5, 1)
	titletext:SetJustifyH("LEFT")
	bargroup.button:SetHeight(window.db.title.height or 15)
	bargroup:SetButtonMouseOver(window.db.title.hovermode)

	-- Register with LibWindow-1.0.
	LibWindow.RegisterConfig(bargroup, window.db)

	-- Restore window position.
	LibWindow.RestorePosition(bargroup)

	bargroup:SetMaxBars(nil, window.db.snapto)
	window.bargroup = bargroup

	if not classicons then
		classicons = Skada.classicons
		classcoords = Skada.classcoords

		roleicons = Skada.roleicons
		rolecoords = Skada.rolecoords

		specicons = Skada.specicons
		speccoords = Skada.speccoords
	end
end

function mod:Destroy(win)
	win.bargroup:Hide()
	win.bargroup = nil
end

function mod:Wipe(win)
	if win and win.bargroup then
		win.bargroup:SetSortFunction(nil)
		win.bargroup:SetBarOffset(0)

		local bars = win.bargroup:GetBars()
		if bars then
			for _, bar in pairs(bars) do
				win.bargroup:RemoveBar(bar)
			end
		end

		win.bargroup:SortBars()
	end
end

function mod:Show(win)
	if win and win.bargroup then
		win.bargroup:Show()
		win.bargroup:SortBars()
	end
end

function mod:Hide(win)
	if win and win.bargroup then
		win.bargroup:Hide()
	end
end

function mod:IsShown(win)
	return (win and win.bargroup and win.bargroup:IsShown())
end

function mod:SetTitle(win, title)
	if win and win.bargroup then
		win.bargroup.button:SetText(title)

		-- module icon
		if not win.db.moduleicons then
			win.bargroup:HideButtonIcon()
		elseif win.selectedmode and win.selectedmode.metadata and win.selectedmode.metadata.icon then
			win.bargroup:SetButtonIcon(win.selectedmode.metadata.icon)
			win.bargroup:ShowButtonIcon()
		elseif win.parentmode and win.parentmode.metadata and win.parentmode.metadata.icon then
			win.bargroup:SetButtonIcon(win.parentmode.metadata.icon)
			win.bargroup:ShowButtonIcon()
		end
	end
end

do
	local ttactive = false

	function mod:BarEnter(_, bar, motion)
		if bar and bar.win then
			local win, id, label = bar.win, bar.id, bar.text
			ttactive = true
			Skada:SetTooltipPosition(GameTooltip, win.bargroup, win.db.display, win)
			Skada:ShowTooltip(win, id, label)
			if not win.db.disablehighlight then
				bar:SetOpacity(1)
				bar:SetBackdropColor(0, 0, 0, 0.25)
			end
		end
	end

	function mod:BarLeave(_, bar, motion)
		if ttactive then
			GameTooltip:Hide()
			ttactive = false
		end
		if not bar.win.db.disablehighlight then
			bar:SetOpacity(0.85)
			bar:SetBackdropColor(0, 0, 0, 0)
		end
	end
end

do
	-- these anchors are used to correctly position the windows due
	-- to the title bar overlapping.
	local Xanchors = {LT = true, LB = true, LC = true, RT = true, RB = true, RC = true}
	local Yanchors = {TL = true, TR = true, TC = true, BL = true, BR = true, BC = true}

	function mod:AnchorMoved(_, group, x, y)
		if FlyPaper and group.win.db.sticky and not group.locked then
			-- correction due to stupid border texture
			local offset = group.win.db.background.borderthickness
			local anchor, name, frame = FlyPaper.StickToClosestFrameInGroup(group, "Skada", nil, offset, offset)

			if anchor and frame and frame.win then
				frame.win.db.sticked[group.win.db.name] = true
				group.win.db.sticked[name] = nil

				-- bar spacing first
				group.win.db.barspacing = frame.win.db.barspacing
				group:SetSpacing(group.win.db.barspacing)

				-- change the width of the window accordingly
				if Yanchors[anchor] then
					-- we change things related to height
					group.win.db.barwidth = frame.win.db.barwidth
					group:SetLength(group.win.db.barwidth)
				elseif Xanchors[anchor] then
					-- window height
					group.win.db.background.height = frame.win.db.background.height
					group:SetHeight(group.win.db.background.height)

					-- title bar height
					group.win.db.title.height = frame.win.db.title.height
					group.button:SetHeight(group.win.db.title.height)
					group:AdjustButtons()

					-- bars height
					group.win.db.barheight = frame.win.db.barheight
					group:SetBarHeight(group.win.db.barheight)

					group:SortBars()
				end
			else
				for _, win in Skada:IterateWindows() do
					if win.db.display == "bar" and win.db.sticked and win.db.sticked[group.win.db.name] then
						win.db.sticked[group.win.db.name] = nil
					end
				end
			end
		end

		CloseDropDownMenus()
		LibWindow.SavePosition(group)
		ACR:NotifyChange("Skada")
	end
end

function mod:WindowResized(_, group)
	local db, height = group.win.db, group:GetHeight()

	-- Snap to best fit
	if db.snapto then
		local maxbars = group:GuessMaxBars(true)
		local snapheight = height

		if db.enabletitle then
			snapheight = db.title.height + ((db.barheight + db.barspacing) * maxbars) - db.barspacing
		else
			snapheight = ((db.barheight + db.barspacing) * maxbars) - db.barspacing
		end

		height = snapheight
	end

	LibWindow.SavePosition(group)
	db.background.height = height
	db.barwidth = group:GetWidth()

	-- resize sticked windows as well.
	if FlyPaper then
		local offset = db.background.borderthickness
		for _, win in Skada:IterateWindows() do
			if win.db.display == "bar" and win.bargroup:IsShown() and db.sticked[win.db.name] then
				win.bargroup.callbacks:Fire("AnchorMoved", win.bargroup)
			end
		end
	end

	group:SetMaxBars(nil, db.snapto)
	Skada:ApplySettings(db.name)
	ACR:NotifyChange("Skada")
end

do
	local function OnMouseWheel(frame, direction)
		local win = frame.win
		-- NOTE: this line is kept just in case mousewheel misbehaves.
		-- local maxbars = win.db.background.height / (win.db.barheight + win.db.barspacing)
		local maxbars = win.bargroup:GetMaxBars()
		if direction == 1 and win.bargroup:GetBarOffset() > 0 then
			win.bargroup:SetBarOffset(win.bargroup:GetBarOffset() - 1)
		elseif direction == -1 and ((win.bargroup:GetNumBars() - maxbars - win.bargroup:GetBarOffset()) > 0) then
			win.bargroup:SetBarOffset(win.bargroup:GetBarOffset() + 1)
		end
	end

	-- for external usage
	function mod:OnMouseWheel(win, frame, direction)
		if not frame then
			mod.framedummy = mod.framedummy or {}
			mod.framedummy.win = win
			frame = mod.framedummy
		end
		OnMouseWheel(frame, direction)
	end

	local barbackdrop = {bgFile = [[Interface\Buttons\WHITE8X8]]}
	function mod:CreateBar(win, name, label, value, maxvalue, icon, o)
		local bar, isnew = win.bargroup:NewCounterBar(name, label, value, maxvalue, icon, o)
		bar.win = win
		bar:EnableMouseWheel(true)
		bar:SetScript("OnMouseWheel", OnMouseWheel)
		bar.iconFrame:SetScript("OnEnter", nil)
		bar.iconFrame:SetScript("OnLeave", nil)
		bar.iconFrame:SetScript("OnMouseDown", nil)
		bar.iconFrame:EnableMouse(false)
		bar:SetBackdrop(win.db.disablehighlight and nil or barbackdrop)
		bar:SetBackdropColor(0, 0, 0, 0)
		return bar, isnew
	end
end

-- ======================================================= --

do
	local function inserthistory(win)
		win.history[#win.history + 1] = win.selectedmode
		if win.child and win.db.childmode ~= 1 then
			inserthistory(win.child)
		end
	end

	local function onEnter(win, id, label, mode)
		mode:Enter(win, id, label)
		if win.child and win.db.childmode ~= 1 then
			onEnter(win.child, id, label, mode)
		end
	end

	local function showmode(win, id, label, mode)
		if win.selectedmode then
			inserthistory(win)
		end

		if mode.Enter then
			onEnter(win, id, label, mode)
		end

		win:DisplayMode(mode)
		CloseDropDownMenus()
	end

	local function BarClickIgnore(bar, button)
		if not bar.win then
			return
		elseif IsShiftKeyDown() and button == "RightButton" then
			Skada:OpenMenu(bar.win)
		elseif IsControlKeyDown() and button == "RightButton" then
			Skada:SegmentMenu(bar.win)
		elseif IsAltKeyDown() and button == "RightButton" then
			Skada:ModeMenu(bar.win)
		elseif button == "RightButton" then
			bar.win:RightClick()
		end
	end

	local function ignoredClick(win, click)
		if win and win.selectedset == "total" and win.metadata and win.metadata.nototalclick and click then
			return tContains(win.metadata.nototalclick, click)
		end
	end

	function mod:BarClick(_, bar, button)
		local win, id, label = bar.win, bar.id, bar.text

		if button == "RightButton" and IsShiftKeyDown() then
			Skada:OpenMenu(win)
		elseif button == "RightButton" and IsAltKeyDown() then
			Skada:ModeMenu(win)
		elseif button == "RightButton" and IsControlKeyDown() then
			Skada:SegmentMenu(win)
		elseif win.metadata.click and not ignoredClick(win, win.metadata.click) then
			win.metadata.click(win, id, label, button)
		elseif button == "RightButton" and not IsModifierKeyDown() then
			win:RightClick()
		elseif win.metadata.click2 and not ignoredClick(win, win.metadata.click2) and IsShiftKeyDown() then
			showmode(win, id, label, win.metadata.click2)
		elseif win.metadata.click3 and not ignoredClick(win, win.metadata.click3) and IsControlKeyDown() then
			showmode(win, id, label, win.metadata.click3)
		elseif win.metadata.click1 and not ignoredClick(win, win.metadata.click1) and not IsModifierKeyDown() then
			showmode(win, id, label, win.metadata.click1)
		end
	end

	local function BarResize(bar)
		if bar.bgwidth then
			bar.bgtexture:SetWidth(bar.bgwidth * bar:GetWidth())
		else
			bar:SetScript("OnSizeChanged", bar.OnSizeChanged)
		end
		bar:OnSizeChanged()
	end

	local function BarIconEnter(icon)
		local bar = icon.bar
		local win = bar.win
		if bar.link and win and win.bargroup then
			Skada:SetTooltipPosition(GameTooltip, win.bargroup, win.db.display, win)
			GameTooltip:SetHyperlink(bar.link)
			GameTooltip:Show()
		end
	end

	local function BarIconMouseDown(icon)
		local bar = icon.bar
		if not IsShiftKeyDown() or not bar.link then
			return
		end
		local activeEditBox = ChatEdit_GetActiveWindow()
		if activeEditBox then
			ChatEdit_InsertLink(bar.link)
		else
			ChatFrame_OpenChat(bar.link, DEFAULT_CHAT_FRAME)
		end
	end

	local function HideGameTooltip()
		GameTooltip:Hide()
	end

	local function value_sort(a, b)
		if not a or a.value == nil then
			return false
		elseif not b or b.value == nil then
			return true
		else
			return a.value > b.value
		end
	end

	local function bar_order_sort(a, b)
		return a and b and a.order and b.order and a.order < b.order
	end

	function mod:Update(win)
		if not win or not win.bargroup then return end
		win.bargroup.button:SetText(win.metadata.title)

		if win.metadata.showspots then
			tsort(win.dataset, value_sort)
		end

		local hasicon
		for _, data in ipairs(win.dataset) do
			if
				(data.icon and not data.ignore) or
				(win.db.classicons and data.class) or
				(win.db.roleicons and rolecoords and data.role) or
				(win.db.specicons and speccoords and data.spec)
			then
				hasicon = true
				break
			end
		end

		if hasicon and not win.bargroup.showIcon then
			win.bargroup:ShowIcon()
		end
		if not hasicon and win.bargroup.showIcon then
			win.bargroup:HideIcon()
		end

		if win.metadata.wipestale then
			local bars = win.bargroup:GetBars()
			if bars then
				for _, bar in pairs(bars) do
					bar.checked = false
				end
			end
		end

		local maxbars = (win.selectedmode and win.db.barmax > 0) and win.db.barmax or 100
		local numbars, nr = 0, 1
		for i, data in ipairs(win.dataset) do
			if numbars == maxbars then break end
			if data.id then
				local bar = win.bargroup:GetBar(data.id)

				if bar and bar.missingclass and data.class and not data.ignore then
					win.bargroup:RemoveBar(bar)
					bar.missingclass = nil
					bar = nil
				end

				if bar then
					numbars = numbars + 1
					bar:SetValue(data.value)
					bar:SetMaxValue(win.metadata.maxvalue or 1)
				else
					-- Initialization of bars.
					bar = mod:CreateBar(win, data.id, data.label, data.value, win.metadata.maxvalue or 1, data.icon, false)
					bar.id = data.id
					bar.text = data.label
					bar.fixed = false

					if not data.ignore then
						numbars = numbars + 1
						if data.icon then
							bar:ShowIcon()

							bar.link = nil
							if data.spellid then
								bar.link = GetSpellLink(data.spellid)
							elseif data.hyperlink then
								bar.link = data.hyperlink
							end

							if bar.link then
								bar.iconFrame.bar = bar
								bar.iconFrame:EnableMouse(true)
								bar.iconFrame:SetScript("OnEnter", BarIconEnter)
								bar.iconFrame:SetScript("OnLeave", HideGameTooltip)
								bar.iconFrame:SetScript("OnMouseDown", BarIconMouseDown)
							end
						end

						bar:EnableMouse(true)
					else
						bar:SetScript("OnEnter", nil)
						bar:SetScript("OnLeave", nil)
						bar:SetScript("OnMouseDown", BarClickIgnore)
						bar:EnableMouse(false)
					end

					bar:SetValue(data.value)

					if not data.class and (win.db.classicons or win.db.classcolorbars or win.db.classcolortext) then
						bar.missingclass = true
					else
						bar.missingclass = nil
					end

					if win.db.specicons and speccoords and data.spec and speccoords[data.spec] then
						bar:ShowIcon()
						bar:SetIconWithCoord(specicons, speccoords[data.spec])
					elseif win.db.roleicons and rolecoords and data.role and data.role ~= "NONE" and rolecoords[data.role] then
						bar:ShowIcon()
						bar:SetIconWithCoord(roleicons, rolecoords[data.role])
					elseif win.db.classicons and data.class and classcoords[data.class] and data.icon == nil then
						bar:ShowIcon()
						bar:SetIconWithCoord(classicons, classcoords[data.class])
					elseif not data.ignore and not data.spellid and not data.hyperlink then
						if data.icon and not bar:IsIconShown() then
							bar:ShowIcon()
							bar:SetIcon(data.icon)
						end
					end

					-- set bar color
					local color = win.db.barcolor or {r = 1, g = 1, b = 0}

					if data.color then
						color = data.color
					elseif data.spellschool and win.db.spellschoolcolors then
						color = Skada.schoolcolors[data.spellschool] or color
					elseif data.class and win.db.classcolorbars then
						color = Skada.classcolors[data.class] or color
					end

					color.a = win.db.disablehighlight and (color.a or 1) or 0.85
					bar:SetColorAt(0, color.r, color.g, color.b, color.a or 1)

					if
						data.class and
						Skada.classcolors[data.class] and
						(win.db.classcolortext or win.db.classcolorleft or win.db.classcolorright)
					then
						local c = Skada.classcolors[data.class]
						if win.db.classcolortext or win.db.classcolorleft then
							bar.label:SetTextColor(c.r, c.g, c.b, c.a or 1)
						end
						if win.db.classcolortext or win.db.classcolorright then
							bar.timerLabel:SetTextColor(c.r, c.g, c.b, c.a or 1)
						end
					else
						local c = win.db.textcolor or white
						bar.label:SetTextColor(c.r, c.g, c.b, c.a or 1)
						bar.timerLabel:SetTextColor(c.r, c.g, c.b, c.a or 1)
					end

					if win.bargroup.showself and data.id == Skada.userGUID then
						bar.fixed = true
					end
				end

				if win.metadata.ordersort then
					bar.order = i
				end

				if win.metadata.showspots and Skada.db.profile.showranks and not data.ignore then
					if win.db.barorientation == 1 then
						bar:SetLabel(format("%d. %s", nr, data.text or data.label or L.Unknown))
					else
						bar:SetLabel(format("%s .%d", data.text or data.label or L.Unknown, nr))
					end
				else
					bar:SetLabel(data.text or data.label or L.Unknown)
				end
				bar:SetTimerLabel(data.valuetext)

				if win.metadata.wipestale then
					bar.checked = true
				end

				if data.emphathize and bar.emphathize_set ~= true then
					bar:SetFont(nil, nil, "OUTLINE", nil, nil, "OUTLINE")
					bar.emphathize_set = true
				elseif not data.emphathize and bar.emphathize_set ~= false then
					bar:SetFont(nil, nil, win.db.barfontflags, nil, nil, win.db.numfontflags)
					bar.emphathize_set = false
				end

				if data.backgroundcolor then
					bar.bgtexture:SetVertexColor(
						data.backgroundcolor.r,
						data.backgroundcolor.g,
						data.backgroundcolor.b,
						data.backgroundcolor.a or 1
					)
				end

				if data.backgroundwidth then
					bar.bgtexture:ClearAllPoints()
					bar.bgtexture:SetPoint("BOTTOMLEFT")
					bar.bgtexture:SetPoint("TOPLEFT")
					bar.bgwidth = data.backgroundwidth
					bar:SetScript("OnSizeChanged", BarResize)
					BarResize(bar)
				else
					bar.bgwidth = nil
				end

				if not data.ignore then
					nr = nr + 1
				end
			end
		end

		if win.metadata.wipestale then
			local bars = win.bargroup:GetBars()
			for _, bar in pairs(bars) do
				if not bar.checked then
					win.bargroup:RemoveBar(bar)
				end
			end
		end

		win.bargroup:SetSortFunction(win.metadata.ordersort and bar_order_sort or nil)
		win.bargroup:SortBars()
	end
end

-- ======================================================= --

do
	local titlebackdrop = {}
	local windowbackdrop = {}

	local lastStretchTime = 0
	local function OnStretch(self, elapsed)
		lastStretchTime = lastStretchTime + elapsed
		if lastStretchTime > 0.01 then
			self:SortBars()
			if self:GetHeight() >= 450 then
				self:StopMovingOrSizing()
			end
			lastStretchTime = 0
		end
	end

	local function move(self, button)
		local group = self:GetParent()
		if group then
			if button == "MiddleButton" then
				CloseDropDownMenus()
				group.isStretching = true
				group:SetBackdropColor(0, 0, 0, 0.9)
				group:SetFrameStrata("TOOLTIP")
				group:StartSizing("TOP")
				group:SetScript("OnUpdate", OnStretch)
			elseif button == "LeftButton" and not group.locked then
				self.startX = group:GetLeft()
				self.startY = group:GetTop()
				group:StartMoving()

				-- move sticked windows.
				if FlyPaper and group.win.db.sticky and not group.win.db.hidden then
					local offset = group.win.db.background.borderthickness
					for _, win in Skada:IterateWindows() do
						if win.db.display == "bar" and win.bargroup:IsShown() and group.win.db.sticked[win.db.name] then
							FlyPaper.Stick(win.bargroup, group, nil, offset, offset)
							win.bargroup.button.startX = win.bargroup:GetLeft()
							win.bargroup.button.startY = win.bargroup:GetTop()
							move(win.bargroup.button, "LeftButton")
						end
					end
				end
			end
		end
	end

	local function stopMove(self, button)
		local group = self:GetParent()
		if group then
			if group.isStretching then
				group.isStretching = nil
				local color = group.win.db.background.color
				group:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
				group:SetFrameStrata(group.win.db.strata)
				group:StopMovingOrSizing()
				group:SetScript("OnUpdate", nil)
				mod:ApplySettings(group.win)
			elseif button == "LeftButton" and not group.locked then
				group:StopMovingOrSizing()
				local endX = group:GetLeft()
				local endY = group:GetTop()
				if self.startX ~= endX or self.startY ~= endY then
					group.callbacks:Fire("AnchorMoved", group, endX, endY)
					if FlyPaper and group.win.db.sticky and not group.win.db.hidden then
						for _, win in Skada:IterateWindows() do
							if win.db.display == "bar" and win.bargroup:IsShown() and group.win.db.sticked[win.db.name] then
								local xOfs, yOfs = win.bargroup:GetLeft(), win.bargroup:GetTop()
								if win.bargroup.startX ~= xOfs or win.bargroup.startY ~= yOfs then
									win.bargroup.callbacks:Fire("AnchorMoved", win.bargroup, xOfs, yOfs)
									stopMove(win.bargroup.button, "LeftButton")
								end
							end
						end
					end
				end
			end
		end
	end

	-- Called by Skada windows when window settings have changed.
	function mod:ApplySettings(win)
		if not win or not win.bargroup then return end

		local g = win.bargroup
		g:SetFrameLevel(1)

		local p = win.db
		g:ReverseGrowth(p.reversegrowth)
		g:SetOrientation(p.barorientation)
		g:SetBarHeight(p.barheight)
		g:SetHeight(p.background.height)
		g:SetWidth(p.barwidth)
		g:SetLength(p.barwidth)
		g:SetTexture(p.bartexturepath or Skada:MediaFetch("statusbar", p.bartexture))
		g:SetBarBackgroundColor(p.barbgcolor.r, p.barbgcolor.g, p.barbgcolor.b, p.barbgcolor.a or 0.6)
		g:SetButtonMouseOver(p.title.hovermode)
		g:SetButtonsOpacity(p.title.toolbaropacity or 0.25)

		g:SetFont(
			p.barfontpath or Skada:MediaFetch("font", p.barfont),
			p.barfontsize,
			p.barfontflags,
			p.numfontpath or Skada:MediaFetch("font", p.numfont),
			p.numfontsize,
			p.numfontflags
		)

		g:SetSpacing(p.barspacing)
		g:UnsetAllColors()
		g:SetColorAt(0, p.barcolor.r, p.barcolor.g, p.barcolor.b, p.barcolor.a)

		if p.barslocked then
			g:Lock()
		else
			g:Unlock()
		end

		if p.strata then
			g:SetFrameStrata(p.strata)
		end

		-- Header
		local fo = CreateFont("TitleFont" .. win.db.name)
		fo:SetFont(p.title.fontpath or Skada:MediaFetch("font", p.title.font), p.title.fontsize, p.title.fontflags)
		if p.title.textcolor then
			fo:SetTextColor(p.title.textcolor.r, p.title.textcolor.g, p.title.textcolor.b, p.title.textcolor.a)
		end
		g.button:SetNormalFontObject(fo)

		titlebackdrop.bgFile = Skada:MediaFetch("statusbar", p.title.texture)
		titlebackdrop.tile = false
		titlebackdrop.tileSize = 0
		titlebackdrop.edgeSize = p.title.borderthickness
		g.button:SetBackdrop(titlebackdrop)

		local color = p.title.color
		g.button:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
		g.button:SetHeight(p.title.height or 15)

		Skada:ApplyBorder(g.button, p.title.bordertexture, p.title.bordercolor, p.title.borderthickness)

		g.button.toolbar = g.button.toolbar or p.title.toolbar or 1
		if g.button.toolbar ~= p.title.toolbar then
			g.button.toolbar = p.title.toolbar or 1
			for i, b in ipairs(g.buttons) do
				b:GetNormalTexture():SetTexture(buttonsTexPath .. g.button.toolbar)
				b:GetHighlightTexture():SetTexture(buttonsTexPath .. g.button.toolbar, 1.0)
			end
		end

		if p.enabletitle then
			g:ShowAnchor()

			g:ShowButton(L["Configure"], p.buttons.menu)
			g:ShowButton(RESET, p.buttons.reset)
			g:ShowButton(L["Segment"], p.buttons.segment)
			g:ShowButton(L["Mode"], p.buttons.mode)
			g:ShowButton(L["Report"], p.buttons.report)
			g:ShowButton(L["Stop"], p.buttons.stop)
		else
			g:HideAnchor()
		end

		g:SetUseSpark(p.spark)

		-- Window border
		Skada:ApplyBorder(g, p.background.bordertexture, p.background.bordercolor, p.background.borderthickness)

		windowbackdrop.bgFile = p.background.texturepath or Skada:MediaFetch("background", p.background.texture)
		windowbackdrop.tile = p.background.tile
		windowbackdrop.tileSize = p.background.tilesize
		windowbackdrop.insets = {left = 0, right = 0, top = 0, bottom = 0}
		if p.enabletitle then
			if p.reversegrowth then
				windowbackdrop.insets.top = 0
				windowbackdrop.insets.bottom = p.title.height
			else
				windowbackdrop.insets.top = p.title.height
				windowbackdrop.insets.bottom = 0
			end
		end
		g:SetBackdrop(windowbackdrop)

		color = p.background.color
		g:SetBackdropColor(color.r, color.g, color.b, color.a or 1)

		color = p.textcolor or white
		g:SetTextColor(color.r, color.g, color.b, color.a or 1)

		if FlyPaper then
			if p.sticky then
				FlyPaper.AddFrame("Skada", p.name, g)
			else
				FlyPaper.RemoveFrame("Skada", p.name)
			end
		end
		g.button:SetScript("OnMouseDown", move)
		g.button:SetScript("OnMouseUp", stopMove)

		-- make player's bar fixed.
		g.showself = Skada.db.profile.showself or p.showself

		g:SetMaxBars(nil, p.snapto)
		g:SetScript("OnShow", function(self) self:SetMaxBars(nil, p.snapto) end)

		g:SetEnableMouse(not p.clickthrough)
		g:SetClampedToScreen(p.clamped)
		g:SetSmoothing(p.smoothing)
		LibWindow.SetScale(g, p.scale)
		g:SortBars()
		g:SetShown(not p.hidden)
	end

	function mod:WindowResizing(_, group)
		if FlyPaper then
			local offset = group.win.db.background.borderthickness
			for _, win in Skada:IterateWindows() do
				if win.db.display == "bar" and win.bargroup:IsShown() and group.win.db.sticked[win.db.name] then
					FlyPaper.Stick(win.bargroup, group, nil, offset, offset)
				end
			end
		end
		group:SetMaxBars(nil, group.win.db.snapto)
	end
end

function mod:AddDisplayOptions(win, options)
	local db = win.db

	options.baroptions = {
		type = "group",
		name = L["Bars"],
		desc = format(L["Options for %s."], L["Bars"]),
		childGroups = "tab",
		order = 10,
		get = function(i)
			return db[i[#i]]
		end,
		set = function(i, val)
			db[i[#i]] = val
			Skada:ApplySettings(db.name)
			if i[#i] == "barmax" then
				mod:Wipe(win)
				win:UpdateDisplay()
			end
		end,
		args = {
			general = {
				type = "group",
				name = L["General"],
				desc = format(L["General options for %s."], L["Bars"]),
				order = 10,
				args = {
					bartexture = {
						type = "select",
						name = L["Bar Texture"],
						desc = L["The texture used by all bars."],
						order = 10,
						width = "double",
						dialogControl = "LSM30_Statusbar",
						values = AceGUIWidgetLSMlists.statusbar
					},
					barspacing = {
						type = "range",
						name = L["Spacing"],
						desc = format(L["Distance between %s."], L["Bars"]),
						order = 20,
						width = "double",
						min = 0,
						max = 10,
						step = 0.01,
						bigStep = 1
					},
					barheight = {
						type = "range",
						name = L["Height"],
						desc = format(L["The height of %s."], L["Bars"]),
						order = 30,
						min = 10,
						max = 40,
						step = 0.01,
						bigStep = 1
					},
					barwidth = {
						type = "range",
						name = L["Width"],
						desc = format(L["The width of %s."], L["Bars"]),
						order = 40,
						min = 80,
						max = 400,
						step = 0.01,
						bigStep = 1
					},
					barmax = {
						type = "range",
						name = L["Max Bars"],
						desc = L["The maximum number of bars shown."],
						min = 0,
						max = 100,
						step = 1,
						order = 50,
						width = "double",
					},
					barorientation = {
						type = "select",
						name = L["Bar Orientation"],
						desc = L["The direction the bars are drawn in."],
						order = 60,
						width = "double",
						values = {[1] = L["Left to right"], [3] = L["Right to left"]}
					},
					reversegrowth = {
						type = "toggle",
						name = L["Reverse bar growth"],
						desc = L["Bars will grow up instead of down."],
						order = 70,
						width = "double"
					},
					color = {
						type = "color",
						name = L["Bar Color"],
						desc = L["Choose the default color of the bars."],
						order = 80,
						hasAlpha = true,
						get = function()
							return db.barcolor.r, db.barcolor.g, db.barcolor.b, db.barcolor.a
						end,
						set = function(_, r, g, b, a)
							db.barcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
							Skada:ApplySettings(db.name)
						end
					},
					bgcolor = {
						type = "color",
						name = L["Background Color"],
						desc = L["Choose the background color of the bars."],
						order = 90,
						hasAlpha = true,
						get = function(_)
							return db.barbgcolor.r, db.barbgcolor.g, db.barbgcolor.b, db.barbgcolor.a
						end,
						set = function(_, r, g, b, a)
							db.barbgcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
							Skada:ApplySettings(db.name)
						end
					},
					classcolorbars = {
						type = "toggle",
						name = L["Class Colors"],
						desc = L["When possible, bars will be colored according to player class."],
						order = 100
					},
					spellschoolcolors = {
						type = "toggle",
						name = L["Spell school colors"],
						desc = L["Use spell school colors where applicable."],
						order = 110
					},
					classicons = {
						type = "toggle",
						name = L["Class Icons"],
						desc = L["Use class icons where applicable."],
						order = 120,
						disabled = function()
							return (db.specicons or db.roleicons)
						end
					},
					roleicons = {
						type = "toggle",
						name = L["Role Icons"],
						desc = L["Use role icons where applicable."],
						order = 130,
						set = function()
							db.roleicons = not db.roleicons
							if db.roleicons and not db.classicons then
								db.classicons = true
							end
							Skada:ReloadSettings()
						end,
						hidden = Skada.Ascension
					},
					specicons = {
						type = "toggle",
						name = L["Spec Icons"],
						desc = L["Use specialization icons where applicable."],
						order = 140,
						set = function()
							db.specicons = not db.specicons
							if db.specicons and not db.classicons then
								db.classicons = true
							end
							Skada:ReloadSettings()
						end,
						hidden = Skada.Ascension
					},
					spark = {
						type = "toggle",
						name = L["Show Spark Effect"],
						order = 150
					}
				}
			},
			text = {
				type = "group",
				name = L["Text"],
				desc = format(L["Text options for %s."], L["Bars"]),
				order = 20,
				args = {
					classcolortext = {
						type = "toggle",
						name = L["Class Colors"],
						desc = L["When possible, bar text will be colored according to player class."],
						order = 10
					},
					textcolor = {
						type = "color",
						name = L["Text Color"],
						desc = format(L["The text color of %s."], L["Bars"]),
						order = 20,
						hasAlpha = true,
						disabled = function() return db.classcolortext end,
						get = function()
							local c = db.textcolor or white
							return c.r, c.g, c.b, c.a
						end,
						set = function(_, r, g, b, a)
							db.textcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
							Skada:ApplySettings(db.name)
						end
					},
					sep = {
						type = "description",
						name = " ",
						width = "full",
						order = 20.9
					},
					lefttext = {
						type = "group",
						name = L["Left Text"],
						desc = format(L["Text options for %s."], L["Left Text"]),
						inline = true,
						order = 30,
						args = {
							barfont = {
								type = "select",
								name = L["Font"],
								desc = format(L["The font used by %s."], L["Left Text"]),
								order = 10,
								values = AceGUIWidgetLSMlists.font,
								dialogControl = "LSM30_Font"
							},
							barfontflags = {
								type = "select",
								name = L["Font Outline"],
								desc = L["Sets the font outline."],
								order = 20,
								values = Skada.fontFlags
							},
							barfontsize = {
								type = "range",
								name = L["Font Size"],
								desc = format(L["The font size of %s."], L["Left Text"]),
								order = 30,
								min = 5,
								max = 32,
								step = 1
							},
							classcolorleft = {
								type = "toggle",
								name = L["Class Colors"],
								desc = format(L["Use class colors for %s."], L["Left Text"]),
								disabled = function() return db.classcolortext end,
								order = 40
							}
						}
					},
					righttext = {
						type = "group",
						name = L["Right Text"],
						desc = format(L["Text options for %s."], L["Right Text"]),
						inline = true,
						order = 40,
						args = {
							numfont = {
								type = "select",
								name = L["Font"],
								desc = format(L["The font used by %s."], L["Right Text"]),
								order = 10,
								values = AceGUIWidgetLSMlists.font,
								dialogControl = "LSM30_Font"
							},
							numfontflags = {
								type = "select",
								name = L["Font Outline"],
								desc = L["Sets the font outline."],
								order = 20,
								values = Skada.fontFlags
							},
							numfontsize = {
								type = "range",
								name = L["Font Size"],
								desc = format(L["The font size of %s."], L["Right Text"]),
								order = 30,
								min = 5,
								max = 32,
								step = 1
							},
							classcolorright = {
								type = "toggle",
								name = L["Class Colors"],
								desc = format(L["Use class colors for %s."], L["Right Text"]),
								disabled = function() return db.classcolortext end,
								order = 40
							}
						}
					},
				}
			},
			advanced = {
				type = "group",
				name = L["Advanced"],
				desc = format(L["Advanced options for %s."], L["Bars"]),
				order = 30,
				args = {
					showself = {
						type = "toggle",
						name = L["Always show self"],
						desc = L["Keeps the player shown last even if there is not enough space."],
						descStyle = "inline",
						width = "double",
						order = 10
					},
					disablehighlight = {
						type = "toggle",
						name = L["Disable bar highlight"],
						desc = L["Hovering a bar won't make it brighter."],
						descStyle = "inline",
						width = "double",
						order = 20
					},
					clickthrough = {
						type = "toggle",
						name = L["Click Through"],
						desc = L["Disables mouse clicks on bars."],
						descStyle = "inline",
						width = "double",
						order = 30
					},
					smoothing = {
						type = "toggle",
						name = L["Smooth Bars"],
						desc = L["Animate bar changes smoothly rather than immediately."],
						descStyle = "inline",
						width = "double",
						order = 40
					}
				}
			}
		}
	}

	options.titleoptions = {
		type = "group",
		name = L["Title Bar"],
		desc = format(L["Options for %s."], L["Title Bar"]),
		childGroups = "tab",
		order = 20,
		get = function(i)
			return db.title[i[#i]]
		end,
		set = function(i, val)
			db.title[i[#i]] = val
			Skada:ApplySettings(db.name)
		end,
		args = {
			general = {
				type = "group",
				name = L["General"],
				desc = format(L["General options for %s."], L["Title Bar"]),
				order = 10,
				args = {
					enable = {
						type = "toggle",
						name = L["Enable"],
						desc = L["Enables the title bar."],
						order = 10,
						get = function()
							return db.enabletitle
						end,
						set = function()
							db.enabletitle = not db.enabletitle
							Skada:ApplySettings(db.name)
						end
					},
					titleset = {
						type = "toggle",
						name = L["Include set"],
						desc = L["Include set name in title bar"],
						order = 20,
						get = function()
							return db.titleset
						end,
						set = function()
							db.titleset = not db.titleset
							Skada:ApplySettings(db.name)
						end
					},
					combattimer = {
						type = "toggle",
						name = L["Encounter Timer"],
						desc = L["When enabled, a stopwatch is shown on the left side of the text."],
						order = 30,
						get = function()
							return db.combattimer
						end,
						set = function()
							db.combattimer = not db.combattimer
							Skada:ApplySettings(db.name)
						end
					},
					moduleicons = {
						type = "toggle",
						name = L["Mode Icon"],
						desc = L["Shows mode's icon in the title bar."],
						order = 40,
						get = function()
							return db.moduleicons
						end,
						set = function()
							db.moduleicons = not db.moduleicons
							Skada:ApplySettings(db.name)
						end
					},
					height = {
						type = "range",
						name = L["Height"],
						desc = format(L["The height of %s."], L["Title Bar"]),
						width = "double",
						order = 50,
						min = 10,
						max = 50,
						step = 1
					},
					background = {
						type = "group",
						name = L["Background"],
						inline = true,
						order = 60,
						args = {
							texture = {
								type = "select",
								dialogControl = "LSM30_Statusbar",
								name = L["Background Texture"],
								desc = L["The texture used as the background of the title."],
								order = 10,
								width = "double",
								values = AceGUIWidgetLSMlists.statusbar
							},
							color = {
								type = "color",
								name = L["Background Color"],
								desc = L["The background color of the title."],
								order = 20,
								hasAlpha = true,
								get = function(_)
									return db.title.color.r, db.title.color.g, db.title.color.b, db.title.color.a
								end,
								set = function(_, r, g, b, a)
									db.title.color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
									Skada:ApplySettings(db.name)
								end
							}
						}
					},
					border = {
						type = "group",
						name = L["Border"],
						inline = true,
						order = 70,
						args = {
							bordertexture = {
								type = "select",
								dialogControl = "LSM30_Border",
								name = L["Border texture"],
								desc = L["The texture used for the border of the title."],
								order = 10,
								width = "double",
								values = AceGUIWidgetLSMlists.border
							},
							bordercolor = {
								type = "color",
								name = L["Border Color"],
								desc = L["The color used for the border."],
								hasAlpha = true,
								order = 20,
								get = function()
									return db.title.bordercolor.r, db.title.bordercolor.g, db.title.bordercolor.b, db.title.bordercolor.a
								end,
								set = function(_, r, g, b, a)
									db.title.bordercolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
									Skada:ApplySettings(db.name)
								end
							},
							thickness = {
								type = "range",
								name = L["Border Thickness"],
								desc = L["The thickness of the borders."],
								order = 30,
								min = 0,
								max = 50,
								step = 0.1,
								bigStep = 0.5
							}
						}
					}
				}
			},
			text = {
				type = "group",
				name = L["Text"],
				desc = format(L["Text options for %s."], L["Title Bar"]),
				order = 20,
				args = {
					font = {
						type = "select",
						name = L["Font"],
						desc = format(L["The font used by %s."], L["Title Bar"]),
						dialogControl = "LSM30_Font",
						values = AceGUIWidgetLSMlists.font,
						order = 10
					},
					fontflags = {
						type = "select",
						name = L["Font Outline"],
						desc = L["Sets the font outline."],
						order = 20,
						values = {
							[""] = NONE,
							["OUTLINE"] = L["Outline"],
							["THICKOUTLINE"] = L["Thick outline"],
							["MONOCHROME"] = L["Monochrome"],
							["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
						}
					},
					fontsize = {
						type = "range",
						name = L["Font Size"],
						desc = format(L["The font size of %s."], L["Title Bar"]),
						order = 30,
						min = 5,
						max = 32,
						step = 1
					},
					textcolor = {
						type = "color",
						name = L["Text Color"],
						desc = format(L["The text color of %s."], L["Title Bar"]),
						order = 40,
						hasAlpha = true,
						get = function()
							local c = db.title.textcolor or white
							return c.r, c.g, c.b, c.a
						end,
						set = function(_, r, g, b, a)
							db.title.textcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
							Skada:ApplySettings(db.name)
						end
					}
				}
			},
			buttons = {
				type = "group",
				name = L["Buttons"],
				desc = format(L["Options for %s."], L["Buttons"]),
				order = 30,
				width = "double",
				get = function(i)
					return db.buttons[i[#i]]
				end,
				set = function(i, val)
					db.buttons[i[#i]] = val
					Skada:ApplySettings(db.name)
				end,
				args = {
					menu = {
						type = "toggle",
						name = L["Configure"],
						desc = L["Opens the configuration window."],
						order = 10
					},
					reset = {
						type = "toggle",
						name = RESET,
						desc = L["Resets all fight data except those marked as kept."],
						order = 20
					},
					segment = {
						type = "toggle",
						name = L["Segment"],
						desc = L["Jump to a specific segment."],
						order = 30
					},
					mode = {
						type = "toggle",
						name = L["Mode"],
						desc = L["Jump to a specific mode."],
						order = 40
					},
					report = {
						type = "toggle",
						name = L["Report"],
						desc = L["Opens a dialog that lets you report your data to others in various ways."],
						order = 50
					},
					stop = {
						type = "toggle",
						name = L["Stop"],
						desc = L["Stops or resumes the current segment. Useful for discounting data after a wipe. Can also be set to automatically stop in the settings."],
						order = 60
					},
					hovermode = {
						type = "toggle",
						name = L["Auto Hide Buttons"],
						desc = L["Show window buttons only if the cursor is over the title bar."],
						order = 70,
						width = "double",
						get = function()
							return db.title.hovermode
						end,
						set = function()
							db.title.hovermode = not db.title.hovermode
							Skada:ApplySettings(db.name)
						end
					},
					appearance = {
						type = "group",
						name = L["Appearance"],
						desc = format(L["Appearance options for %s."], L["Buttons"]),
						inline = true,
						order = 80,
						args = {
							style = {
								type = "multiselect",
								name = L["Buttons Style"],
								width = "full",
								order = 10,
								get = function(_, key)
									return (db.title.toolbar == key)
								end,
								set = function(_, val)
									db.title.toolbar = val
									Skada:ApplySettings(db.name)
								end,
								values = {
									format("|T%s%d:24:192|t", buttonsTexPath, 1),
									format("|T%s%d:24:192|t", buttonsTexPath, 2),
									format("|T%s%d:24:192|t", buttonsTexPath, 3)
								}
							},
							opacity = {
								type = "range",
								name = L["Opacity"],
								get = function()
									return db.title.toolbaropacity or 0.25
								end,
								set = function(_, val)
									db.title.toolbaropacity = val
									Skada:ApplySettings(db.name)
								end,
								min = 0,
								max = 1,
								step = 0.01,
								isPercent = true,
								width = "double",
								order = 20,
							}
						}
					}
				}
			}
		}
	}

	options.windowoptions = Skada:FrameSettings(db)

	options.windowoptions.args.position.args.barwidth = {
		type = "range",
		name = L["Width"],
		order = 70,
		min = 80,
		max = 500,
		step = 0.01,
		bigStep = 1
	}
	options.windowoptions.args.position.args.height = {
		type = "range",
		name = L["Height"],
		order = 80,
		min = 60,
		max = 500,
		step = 0.01,
		bigStep = 1,
		get = function()
			return db.background.height
		end,
		set = function(_, val)
			db.background.height = val
			Skada:ApplySettings(db.name)
		end
	}

	local x, y = floor(GetScreenWidth()), floor(GetScreenHeight())
	options.windowoptions.args.position.args.x = {
		type = "range",
		name = L["X Offset"],
		order = 90,
		min = -x,
		max = x,
		step = 0.01,
		bigStep = 1,
		set = function(_, val)
			local window = mod:GetBarGroup(db.name)
			if window then
				db.x = val
				LibWindow.RestorePosition(window)
			end
		end
	}
	options.windowoptions.args.position.args.y = {
		type = "range",
		name = L["Y Offset"],
		order = 100,
		min = -y,
		max = y,
		step = 0.01,
		bigStep = 1,
		set = function(_, val)
			local window = mod:GetBarGroup(db.name)
			if window then
				db.y = val
				LibWindow.RestorePosition(window)
			end
		end
	}
end