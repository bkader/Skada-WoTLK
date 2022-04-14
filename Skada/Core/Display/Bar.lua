local Skada = Skada

local mod = Skada:NewModule("BarDisplay", "SpecializedLibBars-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Skada")
local ACR = LibStub("AceConfigRegistry-3.0")
local LibWindow = LibStub("LibWindow-1.1")
local FlyPaper = LibStub("LibFlyPaper-1.1", true)

local pairs, ipairs = pairs, ipairs
local tsort, tContains, unpack = table.sort, tContains, unpack
local format, max = string.format, math.max
local GetSpellLink = Skada.GetSpellLink or GetSpellLink
local CloseDropDownMenus = CloseDropDownMenus
local GetScreenWidth, GetScreenHeight = GetScreenWidth, GetScreenHeight
local IsShiftKeyDown = IsShiftKeyDown
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsModifierKeyDown = IsModifierKeyDown
local _

local COLOR_WHITE = HIGHLIGHT_FONT_COLOR
local FONT_FLAGS = Skada.fontFlags
if not FONT_FLAGS then
	FONT_FLAGS = {
		[""] = L.None,
		["OUTLINE"] = L["Outline"],
		["THICKOUTLINE"] = L["Thick outline"],
		["MONOCHROME"] = L["Monochrome"],
		["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
	}
	Skada.fontFlags = FONT_FLAGS
end

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
		self.win:RightClick(nil, button)
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
		bargroup.win:RightClick(nil, button)
	end
end

local buttonsTexPath = [[Interface\AddOns\Skada\Media\Textures\toolbar%s\%s.blp]]
do
	local function AddWindowButton(win, style, index, title, description, func)
		if win and win.AddButton and index then
			return win:AddButton(index, title, description, format(buttonsTexPath, style or 1, index), nil, func)
		end
	end

	local function configOnClick(self, button)
		if button == "RightButton" then
			Skada:OpenOptions(self.list.win)
		else
			Skada:OpenMenu(self.list.win)
		end
	end

	local function resetOnClick(self, button)
		Skada:ShowPopup(self.list.win)
	end

	local function segmentOnClick(self, button)
		if button == "MiddleButton" then
			self.list.win:set_selected_set("current")
		elseif IsModifierKeyDown() then
			self.list.win:set_selected_set(nil, button == "RightButton" and 1 or -1)
		else
			Skada:SegmentMenu(self.list.win)
		end
	end

	local function modeOnClick(self, button)
		Skada:ModeMenu(self.list.win)
	end

	local function reportOnClick(self, button)
		Skada:OpenReportWindow(self.list.win)
	end

	local function stopOnClick(self, button)
		if Skada.current and Skada.current.stopped then
			Skada:ResumeSegment()
		elseif Skada.current then
			Skada:StopSegment()
		end
	end

	function mod:Create(window)
		-- Re-use bargroup if it exists.
		local p = window.db
		local bargroup = mod:GetBarGroup(p.name)

		-- Save a reference to window in bar group. Needed for some nasty callbacks.
		if bargroup then
			-- Clear callbacks.
			bargroup.callbacks = LibStub("CallbackHandler-1.0"):New(bargroup)
		else
			bargroup = mod:NewBarGroup(
				p.name, -- window name
				p.barorientation, -- bars orientation
				p.background.height, -- window height
				p.barwidth, -- window width
				p.barheight, -- bars height
				format("SkadaBarWindow%s", p.name) -- frame name
			)

			-- Add window buttons.
			AddWindowButton(bargroup, p.title.toolbar, "config", L.Configure, L.btn_config_desc, configOnClick)
			AddWindowButton(bargroup, p.title.toolbar, "reset", RESET, L.btn_reset_desc, resetOnClick)
			AddWindowButton(bargroup, p.title.toolbar, "segment", L.Segment, L.btn_segment_desc, segmentOnClick)
			AddWindowButton(bargroup, p.title.toolbar, "mode", L.Mode, L["Jump to a specific mode."], modeOnClick)
			AddWindowButton(bargroup, p.title.toolbar, "report", L.Report, L.btn_report_desc, reportOnClick)
			AddWindowButton(bargroup, p.title.toolbar, "stop", L.Stop, L.btn_stop_desc, stopOnClick)
		end

		bargroup.win = window

		bargroup.RegisterCallback(mod, "BarClick")
		bargroup.RegisterCallback(mod, "BarEnter")
		bargroup.RegisterCallback(mod, "BarLeave")
		bargroup.RegisterCallback(mod, "AnchorMoved")
		bargroup.RegisterCallback(mod, "WindowResizing")
		bargroup.RegisterCallback(mod, "WindowResized")
		bargroup.RegisterCallback(mod, "WindowLocked")
		bargroup:EnableMouse(true)
		bargroup:SetScript("OnMouseDown", WindowOnMouseDown)
		bargroup:SetScript("OnShow", function(self) self:SetMaxBars(nil, p.snapto) end)
		bargroup.button:SetScript("OnClick", TitleButtonOnClick)
		bargroup:HideIcon()

		local titletext = bargroup.button:GetFontString()
		titletext:SetWordWrap(false)
		titletext:SetPoint("LEFT", bargroup.button, "LEFT", 5, 1)
		titletext:SetJustifyH("LEFT")
		bargroup.button:SetHeight(p.title.height or 15)
		bargroup:SetButtonMouseOver(p.title.hovermode)

		-- Register with LibWindow-1.0.
		LibWindow.RegisterConfig(bargroup, p)

		-- Restore window position.
		LibWindow.RestorePosition(bargroup)

		bargroup:SetMaxBars(nil, p.snapto)
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
	if self:IsShown(win) == false then
		win.bargroup:Show()
		win.bargroup:SortBars()
	end
end

function mod:Hide(win)
	if self:IsShown(win) == true then
		win.bargroup:Hide()
	end
end

function mod:IsShown(win)
	if win and win.bargroup then
		return win.bargroup:IsShown() and true or false
	end
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
			Skada:ShowTooltip(win, id, label, bar)
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

function mod:WindowLocked(_, group, locked)
	if group and group.win and group.win.db then
		group.win.db.barslocked = locked
	end
end

do
	local barbackdrop = {bgFile = [[Interface\Buttons\WHITE8X8]]}
	function mod:CreateBar(win, name, label, value, maxvalue, icon, o)
		local bar, isnew = win.bargroup:NewBar(name, label, value, maxvalue, icon, o)
		bar.win = win
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
		if win.selectedmode and win.history[#win.history] ~= win.selectedmode then
			win.history[#win.history + 1] = win.selectedmode
			if win.child and win.db.childmode ~= 1 then
				inserthistory(win.child)
			end
		end
	end

	local function onEnter(win, id, label, mode)
		mode:Enter(win, id, label)
		if win.child and win.db.childmode ~= 1 then
			onEnter(win.child, id, label, mode)
		end
	end

	local function showmode(win, id, label, mode)
		if win.selectedset == "total" and win.metadata.nototalclick and tContains(win.metadata.nototalclick, mode) then
			return
		end

		inserthistory(win)

		if type(mode) == "function" then
			mode(mode, win, id, label)
		else
			if mode.Enter then
				onEnter(win, id, label, mode)
			end
			win:DisplayMode(mode)
		end

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
			bar.win:RightClick(bar, button)
		end
	end

	function mod:BarClick(_, bar, button)
		local win, id, label = bar.win, bar.id, bar.text

		if button == self.db.button then
			self:ScrollStart(win)
		elseif button == "RightButton" and IsShiftKeyDown() then
			Skada:OpenMenu(win)
		elseif button == "RightButton" and IsAltKeyDown() then
			Skada:ModeMenu(win)
		elseif button == "RightButton" and IsControlKeyDown() then
			Skada:SegmentMenu(win)
		elseif win.metadata.click then
			win.metadata.click(win, id, label, button)
		elseif button == "RightButton" and not IsModifierKeyDown() then
			win:RightClick(bar, button)
		elseif button == "LeftButton" and win.metadata.click2 and IsShiftKeyDown() then
			showmode(win, id, label, win.metadata.click2)
		elseif button == "LeftButton" and not Skada.Ascension and win.metadata.click4 and IsAltKeyDown() then
			showmode(win, id, label, win.metadata.click4)
		elseif button == "LeftButton" and win.metadata.click3 and IsControlKeyDown() then
			showmode(win, id, label, win.metadata.click3)
		elseif button == "LeftButton" and win.metadata.click1 and not IsModifierKeyDown() then
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

	local function bar_setcolor(bar, db, data, color)
		if not color then
			color = db.barcolor or Skada.windowdefaults.barcolor

			if data.color then
				color = data.color
			elseif db.spellschoolcolors and data.spellschool and Skada.spellschools[data.spellschool] then
				color = Skada.spellschools[data.spellschool]
			elseif db.classcolorbars and data.class and Skada.classcolors[data.class] then
				color = Skada.classcolors[data.class]
			end
		end

		color.a = db.disablehighlight and (color.a or 1) or 0.85
		bar:SetColorAt(0, color.r, color.g, color.b, color.a)
	end

	function mod:Update(win)
		if not win or not win.bargroup then return end
		win.bargroup.button:SetText(win.metadata.title)

		if win.metadata.showspots or win.metadata.valueorder then
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
					bar.fixed = nil

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

						bar:EnableMouse(not win.db.clickthrough)
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
						bar:SetIcon(specicons, unpack(speccoords[data.spec]))
					elseif win.db.roleicons and rolecoords and data.role and data.role ~= "NONE" and rolecoords[data.role] then
						bar:ShowIcon()
						bar:SetIcon(roleicons, unpack(rolecoords[data.role]))
					elseif win.db.classicons and data.class and classcoords[data.class] and data.icon == nil then
						bar:ShowIcon()
						bar:SetIcon(classicons, unpack(classcoords[data.class]))
					elseif not data.ignore and not data.spellid and not data.hyperlink then
						if data.icon and not bar:IsIconShown() then
							bar:ShowIcon()
							bar:SetIcon(data.icon)
						end
					end

					-- set bar color
					bar_setcolor(bar, win.db, data)

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
						local c = win.db.textcolor or COLOR_WHITE
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

					if data.color and not data.changed then
						bar_setcolor(bar, win.db, data, data.color)
						data.changed = true
					elseif not data.color and data.changed then
						bar_setcolor(bar, win.db, data)
						data.changed = nil
					end
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
	local CreateFrame = CreateFrame
	local SetCursor = SetCursor
	local ResetCursor = ResetCursor
	local scrollIcons = nil

	local function ShowCursor(win)
		if mod.db.icon then
			SetCursor("")
			local icon = scrollIcons and scrollIcons[win]
			if not icon then
				icon = CreateFrame("Frame", nil, win.bargroup)
				icon:SetSize(32, 32)
				icon:SetPoint("CENTER")
				icon:SetFrameLevel(win.bargroup:GetFrameLevel() + 6)

				local t = icon:CreateTexture(nil, "OVERLAY")
				t:SetTexture([[Interface\AddOns\Skada\Media\Textures\icon-scroll]])
				t:SetAllPoints(icon)
				t:Show()

				scrollIcons = scrollIcons or {}
				scrollIcons[win] = icon
			end
			icon:Show()
		end
	end

	local function HideCursor(win)
		if mod.db.icon and scrollIcons and scrollIcons[win] then
			ResetCursor()
			scrollIcons[win]:Hide()
		end
	end

	local GetCursorPosition = GetCursorPosition
	local scrollWin = nil

	local cursorYPos = nil
	function mod:ScrollStart(win)
		_, cursorYPos = GetCursorPosition()
		scrollWin = win
		ShowCursor(win)
	end

	function mod:EndScroll(win)
		scrollWin = nil
		HideCursor(win)
	end

	local IsMouseButtonDown = IsMouseButtonDown
	local lastUpdated = 0
	local math_abs = math.abs

	local function OnMouseWheel(win, direction)
		win.OnMouseWheel = win.OnMouseWheel or win:GetScript("OnMouseWheel")
		win.OnMouseWheel(win, direction)
	end

	local function OnUpdate(_, elapsed)
		-- no scrolled window
		if not scrollWin then return end

		-- db button isn't used
		if not IsMouseButtonDown(mod.db.button) then
			mod:EndScroll(scrollWin)
			return
		end

		ShowCursor(scrollWin)
		lastUpdated = lastUpdated + elapsed
		if lastUpdated <= 0.1 then return end
		lastUpdated = 0

		local _, newpos = GetCursorPosition()
		local step = (scrollWin.db.barheight + scrollWin.db.barspacing) / (scrollWin.bargroup:GetEffectiveScale() * mod.db.speed)
		while math_abs(newpos - cursorYPos) > step do
			if newpos > cursorYPos then
				OnMouseWheel(scrollWin.bargroup, 1)
				cursorYPos = cursorYPos + step
			else
				OnMouseWheel(scrollWin.bargroup, -1)
				cursorYPos = cursorYPos - step
			end
		end
	end

	local f = CreateFrame("Frame", nil, UIParent)
	f:SetScript("OnUpdate", OnUpdate)

	function Skada:Scroll(up)
		for _, win in pairs(mod:GetBarGroups()) do
			OnMouseWheel(win, up and 1 or -1)
		end
	end
end

-- ======================================================= --

do
	local titlebackdrop = {}
	local windowbackdrop = {}

	local lastStretchTime = 0
	local function stretch(self, elapsed)
		lastStretchTime = lastStretchTime + elapsed
		if lastStretchTime > 0.01 then
			self:SortBars()
			if self:GetHeight() >= 500 then
				self:StopMovingOrSizing()
			end
			lastStretchTime = 0
		end
	end

	local function move(self, button)
		local group = self:GetParent()
		if group then
			if button == "MiddleButton" or (button == "LeftButton" and group.locked) then
				group.isStretching = true
				group:StartSizing(IsModifierKeyDown() and "BOTTOM" or "TOP")
				group:SetScript("OnUpdate", stretch)

				CloseDropDownMenus()
				group:SetBackdropColor(0, 0, 0, 0.9)
				group:SetFrameStrata("TOOLTIP")
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
				group:StopMovingOrSizing()
				group:SetScript("OnUpdate", nil)

				local p = group.win.db
				group:SetBackdropColor(p.background.color.r, p.background.color.g, p.background.color.b, p.background.color.a or 1)
				group:SetFrameStrata(p.strata)
				group.win.bargroup:SetHeight(p.background.height)
				LibWindow.RestorePosition(group.win.bargroup)
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
		g.name = p.name -- update name
		g:SetReverseGrowth(p.reversegrowth)
		g:SetOrientation(p.barorientation)
		g:SetBarHeight(p.barheight)
		g:SetHeight(p.background.height)
		g:SetWidth(p.barwidth)
		g:SetLength(p.barwidth)
		g:SetTexture(p.bartexturepath or Skada:MediaFetch("statusbar", p.bartexture))
		g:SetBarBackgroundColor(p.barbgcolor.r, p.barbgcolor.g, p.barbgcolor.b, p.barbgcolor.a or 0.6)
		g:SetButtonMouseOver(p.title.hovermode)
		g:SetButtonsOpacity(p.title.toolbaropacity or 0.25)
		g:SetButtonSpacing(p.title.spacing or 1)
		g:SetUseSpark(p.spark)
		g:SetMouseEnter(not p.hidebuttons)

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
				b:GetNormalTexture():SetTexture(format(buttonsTexPath, g.button.toolbar, b.index))
				b:GetHighlightTexture():SetTexture(format(buttonsTexPath, g.button.toolbar, b.index), 1.0)
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

			g.button:SetScript("OnMouseDown", move)
			g.button:SetScript("OnMouseUp", stopMove)
		else
			g:HideAnchor()

			g.button:SetScript("OnMouseDown", nil)
			g.button:SetScript("OnMouseUp", nil)
		end

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

		color = p.textcolor or COLOR_WHITE
		g:SetTextColor(color.r, color.g, color.b, color.a or 1)

		if FlyPaper then
			if p.sticky then
				FlyPaper.AddFrame("Skada", p.name, g)
			else
				FlyPaper.RemoveFrame("Skada", p.name)
			end
		end

		-- make player's bar fixed.
		g.showself = Skada.db.profile.showself or p.showself

		g:SetMaxBars(nil, p.snapto)

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

local optionsValues = {
	ORIENTATION = {
		[1] = L["Left to right"],
		[3] = L["Right to left"]
	},
	TITLEBTNS = {
		[1] = format("|T%s:22:66|t", format(buttonsTexPath, 1, "_prev")),
		[2] = format("|T%s:22:66|t", format(buttonsTexPath, 2, "_prev")),
		[3] = format("|T%s:22:66|t", format(buttonsTexPath, 3, "_prev"))
	}
}

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
						values = Skada:MediaList("statusbar")
					},
					barheight = {
						type = "range",
						name = L["Height"],
						desc = format(L["The height of %s."], L["Bars"]),
						order = 20,
						min = 10,
						max = 40,
						step = 0.01,
						bigStep = 1
					},
					barwidth = {
						type = "range",
						name = L["Width"],
						desc = format(L["The width of %s."], L["Bars"]),
						order = 30,
						min = 80,
						max = 400,
						step = 0.01,
						bigStep = 1
					},
					barspacing = {
						type = "range",
						name = L["Spacing"],
						desc = format(L["Distance between %s."], L["Bars"]),
						order = 40,
						min = 0,
						max = 10,
						step = 0.01,
						bigStep = 1
					},
					barmax = {
						type = "range",
						name = L["Max Bars"],
						desc = L["The maximum number of bars shown."],
						order = 50,
						min = 0,
						max = 100,
						step = 1
					},
					barorientation = {
						type = "select",
						name = L["Bar Orientation"],
						desc = L["The direction the bars are drawn in."],
						order = 60,
						width = "double",
						values = optionsValues.ORIENTATION
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
							local c = db.barcolor or Skada.windowdefaults.barcolor
							return c.r, c.g, c.b, c.a or 1
						end,
						set = function(_, r, g, b, a)
							db.barcolor = db.barcolor or {}
							db.barcolor.r, db.barcolor.g, db.barcolor.b, db.barcolor.a = r, g, b, a
							Skada:ApplySettings(db.name)
						end
					},
					bgcolor = {
						type = "color",
						name = L["Background Color"],
						desc = L["Choose the background color of the bars."],
						order = 90,
						hasAlpha = true,
						get = function()
							local c = db.barbgcolor or Skada.windowdefaults.barbgcolor
							return c.r, c.g, c.b, c.a or 1
						end,
						set = function(_, r, g, b, a)
							db.barbgcolor = db.barbgcolor or {}
							db.barbgcolor.r, db.barbgcolor.g, db.barbgcolor.b, db.barbgcolor.a = r, g, b, a
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
							local c = db.textcolor or COLOR_WHITE
							return c.r, c.g, c.b, c.a or 1
						end,
						set = function(_, r, g, b, a)
							db.textcolor = db.textcolor or {}
							db.textcolor.r, db.textcolor.g, db.textcolor.b, db.textcolor.a = r, g, b, a
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
								values = Skada:MediaList("font"),
								dialogControl = "LSM30_Font"
							},
							barfontflags = {
								type = "select",
								name = L["Font Outline"],
								desc = L["Sets the font outline."],
								order = 20,
								values = FONT_FLAGS
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
								values = Skada:MediaList("font"),
								dialogControl = "LSM30_Font"
							},
							numfontflags = {
								type = "select",
								name = L["Font Outline"],
								desc = L["Sets the font outline."],
								order = 20,
								values = FONT_FLAGS
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
					}
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
						desc = L.opt_showself_desc,
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
								values = Skada:MediaList("statusbar")
							},
							color = {
								type = "color",
								name = L["Background Color"],
								desc = L["The background color of the title."],
								order = 20,
								hasAlpha = true,
								get = function()
									local c = db.title.color or Skada.windowdefaults.title.color
									return c.r, c.g, c.b, c.a or 1
								end,
								set = function(_, r, g, b, a)
									db.title.color = db.title.color or {}
									db.title.color.r, db.title.color.g, db.title.color.b, db.title.color.a = r, g, b, a
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
								values = Skada:MediaList("border")
							},
							bordercolor = {
								type = "color",
								name = L["Border Color"],
								desc = L["The color used for the border."],
								hasAlpha = true,
								order = 20,
								get = function()
									local c = db.title.bordercolor or Skada.windowdefaults.title.bordercolor
									return c.r, c.g, c.b, c.a or 1
								end,
								set = function(_, r, g, b, a)
									db.title.bordercolor = db.title.bordercolor or {}
									db.title.bordercolor.r = r
									db.title.bordercolor.g = g
									db.title.bordercolor.b = b
									db.title.bordercolor.a = a
									Skada:ApplySettings(db.name)
								end
							},
							borderthickness = {
								type = "range",
								name = L["Border Thickness"],
								desc = L["The thickness of the borders."],
								order = 30,
								min = 0,
								max = 50,
								step = 0.01,
								bigStep = 0.1
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
						values = Skada:MediaList("font"),
						order = 10
					},
					fontflags = {
						type = "select",
						name = L["Font Outline"],
						desc = L["Sets the font outline."],
						order = 20,
						values = FONT_FLAGS
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
							local c = db.title.textcolor or Skada.windowdefaults.title.textcolor
							return c.r, c.g, c.b, c.a or 1
						end,
						set = function(_, r, g, b, a)
							db.title.textcolor = db.title.textcolor or {}
							db.title.textcolor.r = r
							db.title.textcolor.g = g
							db.title.textcolor.b = b
							db.title.textcolor.a = a
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
				args = {
					buttons = {
						type = "group",
						name = L["Buttons"],
						inline = true,
						order = 10,
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
								desc = L.btn_config_desc,
								order = 10
							},
							reset = {
								type = "toggle",
								name = RESET,
								desc = L.btn_reset_desc,
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
								desc = L.btn_report_desc,
								order = 50
							},
							stop = {
								type = "toggle",
								name = L["Stop"],
								desc = L.btn_stop_desc,
								order = 60
							}
						}
					},
					style = {
						type = "multiselect",
						name = L["Buttons Style"],
						width = "half",
						order = 20,
						get = function(_, key)
							return (db.title.toolbar == key)
						end,
						set = function(_, val)
							db.title.toolbar = val
							Skada:ApplySettings(db.name)
						end,
						values = optionsValues.TITLEBTNS
					},
					sep1 = {
						type = "description",
						name = " ",
						width = "full",
						order = 30
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
						order = 40
					},
					spacing = {
						type = "range",
						name = L["Spacing"],
						desc = format(L["Distance between %s."], L["Buttons"]),
						get = function()
							return db.title.spacing or 1
						end,
						set = function(_, val)
							db.title.spacing = val
							Skada:ApplySettings(db.name)
						end,
						min = 0,
						max = 10,
						step = 0.01,
						bigStep = 1,
						order = 50
					},
					hovermode = {
						type = "toggle",
						name = L["Auto Hide Buttons"],
						desc = L["Show window buttons only if the cursor is over the title bar."],
						width = "double",
						order = 90,
						get = function()
							return db.title.hovermode
						end,
						set = function()
							db.title.hovermode = not db.title.hovermode
							Skada:ApplySettings(db.name)
						end
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

	local x, y = floor(GetScreenWidth() / 2), floor(GetScreenHeight() / 2)
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

-- ======================================================= --

do
	local tremove = table.remove
	local GetBindingKey = GetBindingKey
	local SetBinding = SetBinding
	local SaveBindings = SaveBindings
	local GetCurrentBindingSet = GetCurrentBindingSet

	local opt_themes
	local function GetThemeOptions()
		if not opt_themes then
			local applytheme, applywindow = nil, nil
			local savetheme, savewindow = nil, nil
			local deletetheme = nil
			local list = {}

			local themes = {
				{
					name = "Skada default (Legion)",
					barspacing = 0,
					bartexture = "BantoBar",
					barfont = "Accidental Presidency",
					barfontflags = "",
					barfontsize = 13,
					barheight = 18,
					barwidth = 240,
					barorientation = 1,
					barcolor = {r = 0.3, g = 0.3, b = 0.8, a = 1},
					barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
					classcolorbars = true,
					classicons = true,
					buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
					title = {
						textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1},
						height = 20,
						font = "Accidental Presidency",
						fontsize = 13,
						texture = "Armory",
						bordercolor = {r = 0, g = 0, b = 0, a = 1},
						bordertexture = "None",
						borderthickness = 2,
						color = {r = 0.3, g = 0.3, b = 0.3, a = 1},
						fontflags = ""
					},
					background = {
						height = 200,
						texture = "Solid",
						bordercolor = {r = 0, g = 0, b = 0, a = 1},
						bordertexture = "Blizzard Party",
						borderthickness = 2,
						color = {r = 0, g = 0, b = 0, a = 0.4},
						tilesize = 0
					},
					strata = "LOW",
					scale = 1,
					enabletitle = true,
					titleset = true,
					display = "bar",
					snapto = true,
					version = 1
				},
				{
					name = "Minimalistic",
					barspacing = 0,
					bartexture = "Armory",
					barfont = "Accidental Presidency",
					barfontflags = "",
					barfontsize = 12,
					barheight = 16,
					barwidth = 240,
					barorientation = 1,
					barcolor = {r = 0.3, g = 0.3, b = 0.8, a = 1},
					barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
					classcolorbars = true,
					classicons = true,
					buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
					title = {
						textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1},
						height = 18,
						font = "Accidental Presidency",
						fontsize = 12,
						texture = "Armory",
						bordercolor = {r = 0, g = 0, b = 0, a = 1},
						bordertexture = "None",
						borderthickness = 0,
						color = {r = 0.6, g = 0.6, b = 0.8, a = 1},
						fontflags = ""
					},
					background = {
						height = 195,
						texture = "None",
						bordercolor = {r = 0, g = 0, b = 0, a = 1},
						bordertexture = "Blizzard Party",
						borderthickness = 0,
						color = {r = 0, g = 0, b = 0, a = 0.4},
						tilesize = 0
					},
					strata = "LOW",
					scale = 1,
					enabletitle = true,
					titleset = true,
					display = "bar",
					snapto = true,
					version = 1
				},
				{
					name = "All glowy 'n stuff",
					barspacing = 0,
					bartexture = "LiteStep",
					barfont = "ABF",
					barfontflags = "",
					barfontsize = 12,
					barheight = 16,
					barwidth = 240,
					barorientation = 1,
					barcolor = {r = 0.3, g = 0.3, b = 0.8, a = 1},
					barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
					classcolorbars = true,
					classicons = true,
					buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
					title = {
						textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1},
						height = 20,
						font = "ABF",
						fontsize = 12,
						texture = "Aluminium",
						bordercolor = {r = 0, g = 0, b = 0, a = 1},
						bordertexture = "None",
						borderthickness = 0,
						color = {r = 0.6, g = 0.6, b = 0.8, a = 1},
						fontflags = ""
					},
					background = {
						height = 195,
						texture = "None",
						bordercolor = {r = 0.9, g = 0.9, b = 0.5, a = 0.6},
						bordertexture = "Glow",
						borderthickness = 5,
						color = {r = 0, g = 0, b = 0, a = 0.4},
						tilesize = 0
					},
					strata = "LOW",
					scale = 1,
					enabletitle = true,
					titleset = true,
					display = "bar",
					snapto = true
				},
				{
					name = "Recount",
					barspacing = 0,
					bartexture = "BantoBar",
					barfont = "Arial Narrow",
					barfontflags = "",
					barfontsize = 12,
					barheight = 18,
					barwidth = 240,
					barorientation = 1,
					barcolor = {r = 0.3, g = 0.3, b = 0.8, a = 1},
					barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
					classcolorbars = true,
					buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
					title = {
						textcolor = {r = 1, g = 1, b = 1, a = 1},
						height = 18,
						font = "Arial Narrow",
						fontsize = 12,
						texture = "Gloss",
						bordercolor = {r = 0, g = 0, b = 0, a = 1},
						bordertexture = "None",
						borderthickness = 0,
						color = {r = 1, g = 0, b = 0, a = 0.75},
						fontflags = ""
					},
					background = {
						height = 150,
						texture = "Solid",
						bordercolor = {r = 0.9, g = 0.9, b = 0.5, a = 0.6},
						bordertexture = "None",
						borderthickness = 5,
						color = {r = 0, g = 0, b = 0, a = 0.4},
						tilesize = 0
					},
					strata = "LOW",
					scale = 1,
					enabletitle = true,
					titleset = true,
					display = "bar",
					snapto = true
				},
				{
					name = "Omen Threat Meter",
					barspacing = 1,
					bartexture = "Blizzard",
					barfont = "Friz Quadrata TT",
					barfontflags = "",
					barfontsize = 10,
					numfont = "Friz Quadrata TT",
					numfontflags = "",
					numfontsize = 10,
					barheight = 14,
					barwidth = 200,
					barorientation = 1,
					barcolor = {r = 0.8, g = 0.05, b = 0, a = 1},
					barbgcolor = {r = 0.3, g = 0.01, b = 0, a = 0.6},
					classcolorbars = true,
					smoothing = true,
					buttons = {menu = true, reset = true, mode = true},
					title = {
						textcolor = {r = 1, g = 1, b = 1, a = 1},
						height = 16,
						font = "Friz Quadrata TT",
						fontsize = 10,
						texture = "Blizzard",
						bordercolor = {r = 1, g = 0.75, b = 0, a = 1},
						bordertexture = "Blizzard Dialog",
						borderthickness = 1,
						color = {r = 0.2, g = 0.2, b = 0.2, a = 0},
						fontflags = ""
					},
					background = {
						height = 108,
						texture = "Blizzard Parchment",
						bordercolor = {r = 1, g = 1, b = 1, a = 1},
						bordertexture = "Blizzard Dialog",
						borderthickness = 1,
						color = {r = 1, g = 1, b = 1, a = 1},
						tilesize = 0
					},
					strata = "LOW",
					scale = 1,
					enabletitle = true,
					display = "bar",
					version = 1
				}
			}

			opt_themes = {
				type = "group",
				name = L["Themes"],
				desc = format(L["Options for %s."], L["Themes"]),
				args = {
					apply = {
						type = "group",
						name = L["Apply Theme"],
						inline = true,
						order = 10,
						args = {
							theme = {
								type = "select",
								name = L["Theme"],
								order = 10,
								get = function() return applytheme end,
								set = function(_, val) applytheme = val end,
								values = function()
									wipe(list)
									for _, theme in ipairs(themes) do
										list[theme.name] = theme.name
									end
									if Skada.db.global.themes then
										for _, theme in ipairs(Skada.db.global.themes) do
											if theme.name then
												list[theme.name] = theme.name
											end
										end
									end
									return list
								end
							},
							window = {
								type = "select",
								name = L["Window"],
								order = 20,
								get = function() return applywindow end,
								set = function(_, val) applywindow = val end,
								values = function()
									wipe(list)
									for _, win in Skada:IterateWindows() do
										list[win.db.name] = win.db.name
									end
									return list
								end
							},
							exec = {
								type = "execute",
								name = L["Apply"],
								width = "double",
								order = 30,
								disabled = function()
									return (applytheme == nil or applywindow == nil)
								end,
								func = function()
									if applywindow and applytheme then
										local thetheme = nil
										for i, theme in ipairs(themes) do
											if theme.name == applytheme then
												thetheme = theme
												break
											end
										end
										if Skada.db.global.themes then
											for i, theme in ipairs(Skada.db.global.themes) do
												if theme.name == applytheme then
													thetheme = theme
													break
												end
											end
										end

										if thetheme then
											for _, win in Skada:IterateWindows() do
												if win.db.name == applywindow then
													Skada.tCopy(win.db, thetheme)
													Skada:ApplySettings()
													Skada:Print(L["Theme applied!"])
												end
											end
										end
									end
									applytheme, applywindow = nil, nil
								end
							}
						}
					},
					save = {
						type = "group",
						name = L["Save Theme"],
						inline = true,
						order = 20,
						args = {
							window = {
								type = "select",
								name = L["Window"],
								order = 10,
								get = function() return savewindow end,
								set = function(_, val) savewindow = val end,
								values = function()
									wipe(list)
									for _, win in Skada:IterateWindows() do
										list[win.db.name] = win.db.name
									end
									return list
								end
							},
							theme = {
								type = "input",
								name = L["Name"],
								desc = L["Name of your new theme."],
								order = 20,
								get = function() return savetheme end,
								set = function(_, val) savetheme = val end
							},
							exec = {
								type = "execute",
								name = L["Save"],
								width = "double",
								order = 30,
								disabled = function() return (savetheme == nil or savewindow == nil) end,
								func = function()
									for _, win in Skada:IterateWindows() do
										if win.db.name == savewindow then
											Skada.db.global.themes = Skada.db.global.themes or {}
											local theme = {}
											Skada.tCopy(theme, win.db, "name", "sticked", "x", "y", "point", "modeincombat", "set", "wipemode", "returnaftercombat")
											theme.name = savetheme or win.db.name
											Skada.db.global.themes[#Skada.db.global.themes + 1] = theme
										end
									end
									savetheme, savewindow = nil, nil
								end
							}
						}
					},
					delete = {
						type = "group",
						name = L["Delete Theme"],
						inline = true,
						order = 30,
						args = {
							theme = {
								type = "select",
								name = L["Theme"],
								order = 10,
								get = function() return deletetheme end,
								set = function(_, name) deletetheme = name end,
								values = function()
									wipe(list)
									if Skada.db.global.themes then
										for i, theme in ipairs(Skada.db.global.themes) do
											if theme.name then
												list[theme.name] = theme.name
											end
										end
									end
									return list
								end
							},
							exec = {
								type = "execute",
								name = L["Delete"],
								order = 20,
								disabled = function() return (deletetheme == nil) end,
								confirm = function() return L["Are you sure you want to delete this theme?"] end,
								func = function()
									if Skada.db.global.themes then
										for i, theme in ipairs(Skada.db.global.themes) do
											if theme.name == deletetheme then
												tremove(Skada.db.global.themes, i)
												break
											end
										end
									end
									deletetheme = nil
								end
							}
						}
					}
				}
			}
		end

		return opt_themes
	end

	local opt_scroll
	local function GetScrollOptions()
		if not opt_scroll then
			opt_scroll = {
				type = "group",
				name = L["Scroll"],
				desc = format(L["Options for %s."], L["Scroll"]),
				order = 10,
				get = function(info) return mod.db[info[#info]] end,
				set = function(info, val) mod.db[info[#info]] = val end,
				args = {
					mouse = {
						type = "group",
						name = L["Mouse"],
						inline = true,
						order = 10,
						args = {
							speed = {
								type = "range",
								name = L["Wheel Speed"],
								desc = L.opt_wheelspeed_desc,
								set = function(_, val)
									mod.db.speed = val
									mod:SetScrollSpeed(val)
								end,
								min = 1,
								max = 10,
								step = 1,
								width = "double",
								order = 10
							},
							button = {
								type = "select",
								name = L["Scroll mouse button"],
								values = {
									MiddleButton = L["Middle Button"],
									Button4 = L["Mouse Button 4"],
									Button5 = L["Mouse Button 5"]
								},
								order = 20
							},
							icon = {
								type = "toggle",
								name = L["Scroll Icon"],
								order = 30
							}
						}
					},
					binding = {
						type = "group",
						name = L["Keybinding"],
						inline = true,
						order = 20,
						args = {
							upkey = {
								type = "keybinding",
								name = L["Scroll Up"],
								set = function(info, val)
									local b1, b2 = GetBindingKey("SKADA_SCROLLUP")
									if b1 then
										SetBinding(b1)
									end
									if b2 then
										SetBinding(b2)
									end
									SetBinding(val, "SKADA_SCROLLUP")
									SaveBindings(GetCurrentBindingSet())
								end,
								get = function(info)
									return GetBindingKey("SKADA_SCROLLUP")
								end,
								order = 10
							},
							downkey = {
								type = "keybinding",
								name = L["Scroll Down"],
								set = function(info, val)
									local b1, b2 = GetBindingKey("SKADA_SCROLLDOWN")
									if b1 then
										SetBinding(b1)
									end
									if b2 then
										SetBinding(b2)
									end
									SetBinding(val, "SKADA_SCROLLDOWN")
									SaveBindings(GetCurrentBindingSet())
								end,
								get = function(info)
									return GetBindingKey("SKADA_SCROLLDOWN")
								end,
								order = 20
							}
						}
					}
				}
			}
		end

		return opt_scroll
	end

	function mod:OnInitialize()
		self.name = L["Bar display"]
		self.description = L.mod_bar_desc
		Skada:AddDisplaySystem("bar", self)

		self.db = Skada.db.profile.scroll or {speed = 2, icon = true, button = "MiddleButton"}
		if not self.db then
			self.db = {speed = 2, icon = true, button = "MiddleButton"}
			Skada.db.profile.scroll = self.db
		end

		Skada.options.args.themeoptions = GetThemeOptions()
		Skada.options.args.themeoptions.order = 960

		Skada.options.args.scrolloptions = GetScrollOptions()
		Skada.options.args.scrolloptions.order = 970

		self:SetScrollSpeed(self.db.speed)
	end
end

_G.BINDING_NAME_SKADA_SCROLLUP = L["Scroll Up"]
_G.BINDING_NAME_SKADA_SCROLLDOWN = L["Scroll Down"]