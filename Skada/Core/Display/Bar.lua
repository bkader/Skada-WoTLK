local folder, Skada = ...
local Private = Skada.Private
Skada:RegisterDisplay("Bar Display", "mod_bar_desc", function(L, P, G, _, _, O)
	local mod = Skada:NewModule("Bar Display", Skada.displayPrototype, "SpecializedLibBars-1.0")
	local LEFT_TO_RIGHT = mod.LEFT_TO_RIGHT or 1
	local RIGHT_TO_LEFT = mod.RIGHT_TO_LEFT or 2
	local callbacks = mod.callbacks

	local pairs, tsort, format = pairs, table.sort, string.format
	local max, min, abs = math.max, math.min, math.abs
	local GameTooltip, GameTooltip_Hide = GameTooltip, GameTooltip_Hide
	local SpellLink = Private.SpellLink or GetSpellLink
	local GetScreenWidth, GetScreenHeight = GetScreenWidth, GetScreenHeight
	local IsShiftKeyDown = IsShiftKeyDown
	local IsAltKeyDown = IsAltKeyDown
	local IsControlKeyDown = IsControlKeyDown
	local IsModifierKeyDown = IsModifierKeyDown
	local SavePosition = Private.SavePosition
	local RestorePosition = Private.RestorePosition
	local CheckDuplicate = Private.CheckDuplicate
	local new, del, copy = Private.newTable, Private.delTable, Private.tCopy
	local _

	-- references
	local validclass = Skada.validclass
	local classcolors = Skada.classcolors
	local classicons = Skada.classicons
	local classcoords = Skada.classcoords
	local roleicons = Skada.roleicons
	local rolecoords = Skada.rolecoords
	local specicons = Skada.specicons
	local speccoords = Skada.speccoords
	local spellschools = Skada.spellschools
	local windows = Skada.windows

	local WINDOW_DEFAULTS = Skada.windowdefaults
	local COLOR_WHITE = HIGHLIGHT_FONT_COLOR
	local FONT_FLAGS = Skada.fontFlags
	if not FONT_FLAGS then
		FONT_FLAGS = {
			[""] = L["None"],
			["MONOCHROME"] = L["Monochrome"],
			["OUTLINE"] = L["Outline"],
			["THICKOUTLINE"] = L["Thick Outline"],
			["OUTLINEMONOCHROME"] = L["Outline & Monochrome"],
			["THICKOUTLINEMONOCHROME"] = L["Thick Outline & Monochrome"]
		}
		Skada.fontFlags = FONT_FLAGS
	end

	local function listOnMouseDown(self, button)
		if button == "LeftButton" then
			return
		elseif IsShiftKeyDown() then
			Skada:OpenMenu(self.win)
		elseif IsControlKeyDown() then
			Skada:SegmentMenu(self.win)
		elseif IsAltKeyDown() then
			Skada:ModeMenu(self.win, self)
		elseif not self.clickthrough then
			self.win:RightClick(nil, button)
		end
	end

	local function anchorOnClick(self, button)
		local bargroup = self:GetParent()
		-- other buttons are reserved for other actions
		if bargroup and button == "RightButton" then
			if IsShiftKeyDown() then
				Skada:OpenMenu(bargroup.win)
			elseif IsControlKeyDown() then
				Skada:SegmentMenu(bargroup.win)
			elseif IsAltKeyDown() then
				Skada:ModeMenu(bargroup.win, self, true)
			elseif not bargroup.clickthrough and not Skada.testMode then
				bargroup.win:RightClick(nil, button)
			end
		end
	end

	local buttonsTexPath = format([[%s\Textures\toolbar%%s\%%s]], Skada.mediapath)
	do
		local function AddWindowButton(win, style, index, title, description, func)
			if win and win.AddButton and index then
				return win:AddButton(index, title, description, format(buttonsTexPath, style or 1, index), nil, func)
			end
		end

		local OpenOptions = Private.OpenOptions
		local function configOnClick(self, button)
			if button == "RightButton" then
				OpenOptions(self.list.win)
			elseif button == "LeftButton" then
				Skada:OpenMenu(self.list.win)
			end
		end

		local function resetOnClick(self, button)
			if button == "LeftButton" and IsShiftKeyDown() then
				Skada:DeleteSet(nil, self.list.win.selectedset)
			elseif button == "LeftButton" then
				Skada:ShowPopup(self.list.win)
			end
		end

		local function segmentOnClick(self, button)
			if IsModifierKeyDown() then
				self.list.win:SetSelectedSet(nil, button == "RightButton" and 1 or -1)
			elseif button == "MiddleButton" or button == "RightButton" then
				self.list.win:SetSelectedSet("current")
			elseif button == "LeftButton" then
				Skada:SegmentMenu(self.list.win)
			end
		end

		local function modeOnClick(self, button)
			if button == "LeftButton" or button == "RightButton" then
				Skada:ModeMenu(self.list.win, self, button == "RightButton")
			end
		end

		local OpenReport = Private.OpenReport
		local function reportOnClick(self, button)
			if button == "LeftButton" then
				OpenReport(self.list.win)
			end
		end

		local function splitOnClick(self, button)
			if button == "LeftButton" then
				return Skada:NewSegment()
			end
		end

		local function phaseOnClick(self, button)
			if button == "LeftButton" then
				return Skada:NewPhase()
			end
		end

		local function stopOnClick(self, button)
			if not Skada.current then
				return
			elseif Skada.tempsets and #Skada.tempsets > 0 then
				if (IsShiftKeyDown() or button == "RightButton") and Skada.current.stopped then
					Skada:ResumeSegment()
				elseif IsShiftKeyDown() or button == "RightButton" then
					Skada:StopSegment()
				else
					Skada:PhaseMenu(self.list.win)
				end
			elseif button == "LeftButton" and Skada.current.stopped then
				Skada:ResumeSegment()
			elseif button == "LeftButton" and Skada.current then
				Skada:StopSegment()
			end
		end

		function mod:Create(window, isnew)
			-- Re-use bargroup if it exists.
			local p = window.db
			local bargroup = mod:GetBarGroup(p.name)

			-- fix old oriantation & buttons texture
			p.barorientation = max(LEFT_TO_RIGHT, min(RIGHT_TO_LEFT, p.barorientation or LEFT_TO_RIGHT))
			p.title.toolbar = max(1, min(2, p.title.toolbar or 2))
			p.barfontflags = p.barfontflags == "THICK" and "" or p.barfontflags
			p.numfontflags = p.numfontflags == "THICK" and "" or p.numfontflags
			p.title.fontflags = p.title.fontflags == "THICK" and "" or p.title.fontflags

			if not bargroup then
				bargroup = mod:NewBarGroup(
					p.name, -- window name
					p.barorientation, -- bars orientation
					p.background.height, -- window height
					p.barwidth, -- window width
					p.barheight, -- bars height
					format("%sBarWindow%s", folder, p.name) -- frame name
				)

				-- Add window buttons.
				AddWindowButton(bargroup, p.title.toolbar, "config", L["Configure"], L["btn_config_desc"], configOnClick)
				AddWindowButton(bargroup, p.title.toolbar, "reset", L["Reset"], L["btn_reset_desc"], resetOnClick)
				AddWindowButton(bargroup, p.title.toolbar, "segment", L["Segment"], L["btn_segment_desc"], segmentOnClick)
				AddWindowButton(bargroup, p.title.toolbar, "mode", L["Mode"], L["Jump to a specific mode."], modeOnClick)
				AddWindowButton(bargroup, p.title.toolbar, "split", L["New Segment"], L["Starts a new segment."], splitOnClick)
				AddWindowButton(bargroup, p.title.toolbar, "phase", L["New Phase"], L["Starts a new phase."], phaseOnClick)
				AddWindowButton(bargroup, p.title.toolbar, "report", L["Report"], L["btn_report_desc"], reportOnClick)
				AddWindowButton(bargroup, p.title.toolbar, "stop", L["Stop"], L["btn_stop_desc"], stopOnClick)
			end

			bargroup.win = window
			bargroup:EnableMouse(true)
			bargroup:HookScript("OnMouseDown", listOnMouseDown)
			bargroup:HideBarIcons()

			bargroup.button:SetScript("OnClick", anchorOnClick)
			bargroup.button:SetHeight(p.title.height or 15)
			bargroup:SetAnchorMouseover(p.title.hovermode)

			if isnew then -- save position if new
				SavePosition(bargroup, p)
			else -- restore position if not
				RestorePosition(bargroup, p)
			end

			window.bargroup = bargroup
		end
	end

	function mod:SetTitle(win, title)
		local bargroup = win and win.bargroup
		if not bargroup then return end

		bargroup.button:SetText(title or win.title or win.metadata.title)

		-- module icon
		if not win.db.moduleicons then
			bargroup:HideAnchorIcon()
		elseif win.selectedmode and win.selectedmode.metadata and win.selectedmode.metadata.icon then
			bargroup:ShowAnchorIcon(win.selectedmode.metadata.icon)
		elseif win.parentmode and win.parentmode.metadata and win.parentmode.metadata.icon then
			bargroup:ShowAnchorIcon(win.parentmode.metadata.icon)
		end
	end

	do
		local ttactive = false

		function mod:BarEnter(_, bar, motion)
			local win = bar and bar.win
			if not win then return end

			local id, label, class = bar.id, bar.text, bar.class
			Skada:SetTooltipPosition(GameTooltip, win.bargroup, "bar", win)
			Skada:ShowTooltip(win, id, label, bar, class)
			ttactive = true
		end

		function mod:BarLeave(_, bar, motion)
			if not ttactive then return end
			GameTooltip:Hide()
			ttactive = false
		end
	end

	function mod:BarReleased(_, bar)
		if not bar then return end

		bar.changed = nil
		bar.fixed = nil
		bar.order = nil
		bar.text = nil
		bar.win = nil
		bar.link = nil
		bar.role = nil
		bar.spec = nil
		bar.talent = nil

		bar.iconFrame:SetScript("OnEnter", nil)
		bar.iconFrame:SetScript("OnLeave", nil)
		bar.iconFrame:SetScript("OnMouseDown", nil)
		bar.iconFrame:EnableMouse(false)
	end

	do
		local function stop_move(group, children, deep)
			local p = group and group.win and group.win.db
			if not p then return end

			-- the window wasn't sticked to any? remove just incase
			for i = 1, #windows do
				local win = windows[i]
				if win and win.db and win.db.name ~= p.name and win.db.display == "bar" then
					if win.db.sticked and win.db.sticked[p.name] and not deep then
						win.db.sticked[p.name] = nil
						-- remove table if empty
						if next(win.db.sticked) == nil then
							win.db.sticked = del(win.db.sticked)
						end
						SavePosition(win.bargroup, win.db)
					end

					-- save other window posotions if sticked to this!
					if children and children[win.db.name] then
						SavePosition(win.bargroup, win.db)
						stop_move(win.bargroup, win.db.sticked, true)
					end
				end
			end
		end

		function mod:WindowMoveStop(_, group)
			SavePosition(group, group.win.db) -- save window position

			-- handle sticked windows
			if group.win.db.sticky and not group.locked then
				local p = group.win.db

				-- attempt to stick to the closest frame.
				local offset = p.background.borderthickness
				local _, _, frame = group:StickToClosestFrameInGroup(folder, nil, offset, offset)

				-- found a frame to stick it to?
				if frame then
					-- nothing to do
					SavePosition(group, p)
				else
					stop_move(group, p.sticked)
				end
			end

			Skada:CloseMenus()
			Skada:NotifyChange()
		end
	end

	do
		local function start_move(group, children, offset)
			if not children then return end
			for i = 1, #windows do
				local win = windows[i]
				local p = win and win.db
				if p and p.display == "bar" and children[win.name] then
					win.bargroup:Stick(group, nil, offset, offset)
					start_move(win.bargroup, p.sticked, p.background.borderthickness)
				end
			end
		end

		function mod:WindowMoveStart(_, group)
			local p = group and group.win and group.win.db
			if p and p.sticky and not p.hidden then
				local offset = p.background.borderthickness
				start_move(group, p.sticked, offset)
			end
		end
	end

	function mod:WindowResized(_, group)
		local p = group.win.db
		local width, height = group:GetSize()

		-- Snap to best fit
		if p.snapto then
			local maxbars = group:GetMaxBars()
			local sheight = height

			if p.enabletitle then
				sheight = p.title.height + p.baroffset + ((p.barheight + p.barspacing) * maxbars) - p.barspacing
			else
				sheight = ((p.barheight + p.barspacing) * maxbars) - p.barspacing
			end

			height = sheight
		end

		p.barwidth = width
		p.background.height = height

		-- resize sticked windows as well.
		if p.sticky then
			local offset = p.background.borderthickness
			for i = 1, #windows do
				local win = windows[i]
				if win and win.db and win.db.display == "bar" and win.bargroup:IsShown() and p.sticked and p.sticked[win.db.name] then
					callbacks:Fire("WindowMoveStop", win.bargroup)
				end
			end
		end

		SavePosition(group, p)
		Skada:ApplySettings(p.name)
		Skada:NotifyChange()
	end

	function mod:WindowLocked(_, group, locked)
		if group and group.win and group.win.db then
			group.win.db.barslocked = locked
		end
	end

	function mod:WindowStretching(_, group)
		if group and group.backdropA and group.backdropA < 0.85 then
			group.backdropA = min(0.85, max(0, group.backdropA + 0.015))
			group:SetBackdropColor(group.backdropR, group.backdropG, group.backdropB, group.backdropA)
		end
	end

	function mod:WindowStretchStart(_, group)
		if group then
			group.backdropR, group.backdropG, group.backdropB, group.backdropA = group:GetBackdropColor()
			group:SetBackdropColor(0, 0, 0, group.backdropA)
			group:SetFrameStrata("TOOLTIP")
		end
		Skada:CloseMenus()
	end

	function mod:WindowStretchStop(_, group)
		if group and group.win and group.win.db then
			-- not longer needed
			group.backdropR = nil
			group.backdropG = nil
			group.backdropB = nil
			group.backdropA = nil

			local p = group.win.db
			group:SetBackdropColor(p.background.color.r, p.background.color.g, p.background.color.b, p.background.color.a or 1)
			group:SetFrameStrata(p.strata)
		end
	end

	function mod:CreateBar(win, name, label, value, maxvalue, icon)
		local bar, isnew = win.bargroup:NewBar(name, label, value, maxvalue, icon)
		bar.win = win
		return bar, isnew
	end

	-- ======================================================= --

	do
		-- these anchors are used to correctly position the windows due
		-- to the title bar overlapping.
		local Xanchors = {LT = true, LB = true, LC = true, RT = true, RB = true, RC = true}
		local Yanchors = {TL = true, TR = true, TC = true, BL = true, BR = true, BC = true}

		function mod:OnAnchorFrame(_, group, frame, anchor, x, y)
			local p = group and group.win and group.win.db
			local q = frame and frame.win and frame.win.db
			if not p or not q then return end

			-- change the window it is sticked to.
			q.sticked = q.sticked or new()
			q.sticked[p.name] = true

			-- if the window that we are sticking this one to was
			-- sticked to it, we make sure to remove it from table.
			if p.sticked then
				p.sticked[q.name] = nil
			end

			-- bar spacing first
			p.barspacing = q.barspacing
			group:SetSpacing(p.barspacing)

			-- change the width of the window accordingly
			if Yanchors[anchor] then
				-- we change things related to height
				p.barwidth = q.barwidth
				group:SetLength(p.barwidth)
			elseif Xanchors[anchor] then
				-- window height
				p.background.height = q.background.height
				group:SetHeight(p.background.height)

				-- title bar height
				p.title.height = q.title.height
				group.button:SetHeight(p.title.height)
				group:AdjustButtons()

				-- bars height
				p.barheight = q.barheight
				group:SetBarHeight(p.barheight)

				group:SortBars()
			end

			SavePosition(group, p)
		end

		-- remove all windows that were sticked to this!
		function mod:OnRemoveFrame(_, group, _, name)
			local p = group and group.win and group.win.db
			if p and p.sticked then
				p.sticked = del(p.sticked)
			end
		end
	end

	-- ======================================================= --

	do
		local function inserthistory(win)
			if win.selectedmode and win.history[#win.history] ~= win.selectedmode then
				win.history[#win.history + 1] = win.selectedmode
				if win.child and (win.db.childmode == 1 or win.db.childmode == 3) then
					inserthistory(win.child)
				end
			end
		end

		local function onEnter(win, id, label, class, mode)
			mode:Enter(win, id, label, class)
			if win.child and (win.db.childmode == 1 or win.db.childmode == 3) then
				onEnter(win.child, id, label, class, mode)
			end
		end

		local total_noclick = Private.total_noclick
		local function showmode(win, id, label, class, mode)
			if total_noclick(win.selectedset, mode) then
				return
			end

			inserthistory(win)

			if type(mode) == "function" then
				mode(win, id, label, class)
			else
				if mode.Enter then
					onEnter(win, id, label, class, mode)
				end
				win:DisplayMode(mode)
			end

			Skada:CloseMenus()
			GameTooltip:Hide()
		end

		local function BarClickIgnore(bar, button)
			if not bar.win then
				return
			elseif IsShiftKeyDown() and button == "RightButton" then
				Skada:OpenMenu(bar.win)
			elseif IsControlKeyDown() and button == "RightButton" then
				Skada:SegmentMenu(bar.win)
			elseif IsAltKeyDown() and button == "RightButton" then
				Skada:ModeMenu(bar.win, bar)
			elseif button == "RightButton" then
				bar.win:RightClick(bar, button)
			elseif IsAltKeyDown() and bar.win.class then
				bar.win.class = nil
				bar.win:UpdateDisplay()
			end
		end

		function mod:BarClick(_, bar, button)
			local win = not Skada.testMode and bar and bar.win
			if not win then return end

			local id, label, class = bar.id, bar.text, bar.class

			if button == self.db.button then
				self:ScrollStart(win)
			elseif button == "RightButton" and IsShiftKeyDown() then
				Skada:OpenMenu(win)
			elseif button == "RightButton" and IsAltKeyDown() then
				Skada:ModeMenu(win, bar)
			elseif button == "RightButton" and IsControlKeyDown() then
				Skada:SegmentMenu(win)
			elseif win.metadata.click then
				win.metadata.click(win, id, label, button, class)
			elseif button == "RightButton" and not IsModifierKeyDown() then
				win:RightClick(bar, button)
			elseif button == "LeftButton" and win.metadata.click2 and IsShiftKeyDown() then
				showmode(win, id, label, class, win.metadata.click2)
			elseif button == "LeftButton" and win.metadata.filterclass and IsAltKeyDown() then
				win:FilterClass(class)
			elseif button == "LeftButton" and win.metadata.click3 and IsControlKeyDown() then
				showmode(win, id, label, class, win.metadata.click3)
			elseif button == "LeftButton" and win.metadata.click1 and not IsModifierKeyDown() then
				showmode(win, id, label, class, win.metadata.click1)
			end
		end

		local function barOnSizeChanged(bar)
			if bar.bgwidth then
				bar.bg:SetWidth(bar.bgwidth * bar:GetWidth())
			else
				bar:SetScript("OnSizeChanged", bar.OnSizeChanged)
			end
			bar:OnSizeChanged()
		end

		local function iconOnEnter(icon)
			local bar = icon.bar
			local win = bar.win
			if win and win.bargroup and (bar.link or bar.role or bar.spec) then
				Skada:SetTooltipPosition(GameTooltip, win.bargroup, "bar", win)

				if bar.link then
					GameTooltip:SetHyperlink(bar.link)
					GameTooltip:Show()
					return
				end

				GameTooltip:AddLine(bar.text, classcolors.unpack(bar.class))
				if bar.role and bar.role ~= "NONE" then
					GameTooltip:AddDoubleLine(L["Role"], L[bar.role], 1, 1, 1)
				end
				if bar.spec then
					GameTooltip:AddDoubleLine(L["Specialization"], L["SPEC_"..bar.spec], 1, 1, 1)
				end
				if bar.talent then
					GameTooltip:AddDoubleLine(L["Talents"], bar.talent, 1, 1, 1)
				end
				GameTooltip:Show()
			end
		end

		local function iconOnMouseDown(icon)
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

		local function value_sort(a, b)
			if not a or a.value == nil then
				return false
			elseif not b or b.value == nil then
				return true
			elseif a.value < b.value then
				return false
			elseif a.value > b.value then
				return true
			elseif not a.label then
				return false
			elseif not b.label then
				return true
			else
				return a.label > b.label
			end
		end

		local function bar_order_sort(a, b)
			if not a or a.order == nil then
				return true
			elseif not b or b.order == nil then
				return false
			elseif a.order < b.order then
				return true
			elseif a.order > b.order then
				return false
			elseif not a.GetLabel then
				return true
			elseif not b.GetLabel then
				return false
			else
				return a:GetLabel() < b:GetLabel()
			end
		end

		local function bar_order_reverse_sort(a, b)
			if not a or a.order == nil then
				return false
			elseif not b or b.order == nil then
				return true
			elseif a.order < b.order then
				return false
			elseif a.order > b.order then
				return true
			elseif not a.GetLabel then
				return false
			elseif not b.GetLabel then
				return true
			else
				return a:GetLabel() > b:GetLabel()
			end
		end

		local function bar_seticon(bar, db, data, icon)
			if icon then
				bar:SetIcon(icon)
				bar:ShowIcon()
			elseif db.specicons and data.spec and speccoords[data.spec] then
				bar:SetIcon(specicons, speccoords(data.spec))
				bar:ShowIcon()
			elseif db.roleicons and data.role then
				bar:SetIcon(roleicons, rolecoords(data.role))
				bar:ShowIcon()
			elseif db.classicons and data.class and data.icon == nil then
				bar:SetIcon(classicons, classcoords(data.class))
				bar:ShowIcon()
			elseif data.icon and not data.ignore and not data.spellid and not data.hyperlink then
				bar:SetIcon(data.icon)
				bar:ShowIcon()
			end
		end

		local function bar_setcolor(bar, db, data, color)
			local default = db.barcolor or WINDOW_DEFAULTS.barcolor
			if not color and data.color then
				color = data.color
			elseif not color and db.spellschoolcolors and data.spellschool and spellschools[data.spellschool] then
				color = spellschools[data.spellschool]
			elseif not color and db.useselfcolor and db.selfcolor and data.id == Skada.userGUID then
				color = db.selfcolor
			elseif not color and db.classcolorbars and data.class then
				color = classcolors(data.class)
			end
			if color then
				bar:SetColor(color.r, color.g, color.b, color.a or default.a or 1, true)
			else
				bar:SetColor(default.r, default.g, default.b, default.a or 1)
			end
		end

		function mod:Update(win)
			local bargroup = win and win.bargroup
			if not bargroup then return end
			bargroup.button:SetText(win.metadata.title)

			local metadata = win.metadata
			local dataset = win.dataset

			if metadata.showspots or metadata.valueorder then
				tsort(dataset, value_sort)
			end

			local db = win.db
			local hasicon = nil
			for i = 0, #dataset do
				local data = dataset[i]
				if
					(data and data.icon and not data.ignore) or
					(data and db.classicons and data.class) or
					(data and db.roleicons and data.role) or
					(data and db.specicons and data.spec)
				then
					hasicon = true
					break
				end
			end

			if hasicon and not bargroup.showIcon then
				bargroup:ShowBarIcons()
			end
			if not hasicon and bargroup.showIcon then
				bargroup:HideBarIcons()
			end

			if metadata.wipestale then
				for _, bar in pairs(bargroup:GetBars()) do
					bar.checked = nil
				end
			end

			local nr = 1
			for i = 0, #dataset do
				local data = dataset[i]
				if data and data.id then
					local bar = bargroup:GetBar(data.id)

					-- bar generated before class info? remove it...
					if bar and bar.missingclass and data.class and not data.ignore then
						bar:Hide()
						bargroup:RemoveBar(bar)
						bar.missingclass = nil
						bar = nil
					end

					if bar then
						bar.class = data.class
						bar:SetValue(data.value)
						bar:SetMaxValue(metadata.maxvalue or 1)

						if data.changed and not bar.changed then
							bar.changed = true
							bar_seticon(bar, db, data, data.icon)
							bar_setcolor(bar, db, data, data.color)
						elseif not data.changed and bar.changed then
							bar.changed = nil
							bar_seticon(bar, db, data)
							bar_setcolor(bar, db, data)
						end
					else
						-- Initialization of bars.
						bar = mod:CreateBar(win, data.id, data.label, data.value, metadata.maxvalue or 1, data.icon)
						bar.id = data.id
						bar.text = data.label
						bar.class = data.class
						bar.fixed = nil

						if not data.ignore then
							if data.icon then
								bar:ShowIcon()

								bar.link = nil
								if data.spellid then
									bar.link = SpellLink(abs(data.spellid))
								elseif data.hyperlink then
									bar.link = data.hyperlink
								end

								if bar.link then
									bar.iconFrame:EnableMouse(true)
									bar.iconFrame:SetScript("OnEnter", iconOnEnter)
									bar.iconFrame:SetScript("OnLeave", GameTooltip_Hide)
									bar.iconFrame:SetScript("OnMouseDown", iconOnMouseDown)
								end
							elseif bargroup:IsIconShown() and (data.role or data.spec or data.talent) then
								bar.role = data.role
								bar.spec = data.spec
								bar.talent = data.talent
								bar.iconFrame:EnableMouse(true)
								bar.iconFrame:SetScript("OnEnter", iconOnEnter)
								bar.iconFrame:SetScript("OnLeave", GameTooltip_Hide)
							end

							bar:EnableMouse(not db.clickthrough)
						else
							bar:SetScript("OnEnter", nil)
							bar:SetScript("OnLeave", nil)
							bar:SetScript("OnMouseDown", BarClickIgnore)
						end

						bar:SetValue(data.value)

						if not data.class and (db.classicons or db.classcolorbars or db.classcolortext) then
							bar.missingclass = true
						else
							bar.missingclass = nil
						end

						-- set bar icon and color
						bar_seticon(bar, db, data)
						bar_setcolor(bar, db, data)

						if validclass[data.class] and (db.classcolortext or db.classcolorleft or db.classcolorright) then
							local c = classcolors(data.class)
							if db.classcolortext or db.classcolorleft then
								bar.label:SetTextColor(c.r, c.g, c.b, c.a or 1)
							end
							if db.classcolortext or db.classcolorright then
								bar.timerLabel:SetTextColor(c.r, c.g, c.b, c.a or 1)
							end
						else
							local c = db.textcolor or COLOR_WHITE
							bar.label:SetTextColor(c.r, c.g, c.b, c.a or 1)
							bar.timerLabel:SetTextColor(c.r, c.g, c.b, c.a or 1)
						end

						if bargroup.showself and data.id == Skada.userGUID then
							bar.fixed = true
						end
					end

					if metadata.ordersort or metadata.reversesort then
						bar.order = i
					end

					if metadata.showspots and P.showranks and not data.ignore then
						if db.barorientation == 1 then
							bar:SetLabel(format("%d. %s", nr, data.text or data.label or L["Unknown"]))
						else
							bar:SetLabel(format("%s .%d", data.text or data.label or L["Unknown"], nr))
						end
					else
						bar:SetLabel(data.text or data.label or L["Unknown"])
					end
					bar:SetTimerLabel(data.valuetext)

					if metadata.wipestale then
						bar.checked = true
					end

					if data.emphathize and bar.emphathize_set ~= true then
						bar:SetFont(nil, nil, "OUTLINE", nil, nil, "OUTLINE")
						bar.emphathize_set = true
					elseif not data.emphathize and bar.emphathize_set ~= false then
						bar:SetFont(nil, nil, db.barfontflags, nil, nil, db.numfontflags)
						bar.emphathize_set = false
					end

					if data.backgroundcolor then
						bar.bg:SetVertexColor(
							data.backgroundcolor.r,
							data.backgroundcolor.g,
							data.backgroundcolor.b,
							data.backgroundcolor.a or 1
						)
					end

					if data.backgroundwidth then
						bar.bg:ClearAllPoints()
						bar.bg:SetPoint("BOTTOMLEFT")
						bar.bg:SetPoint("TOPLEFT")
						bar.bgwidth = data.backgroundwidth
						bar:SetScript("OnSizeChanged", barOnSizeChanged)
						barOnSizeChanged(bar)
					else
						bar.bgwidth = nil
					end

					if not data.ignore then
						nr = nr + 1
					end
				end
			end

			if metadata.wipestale then
				for _, bar in pairs(bargroup:GetBars()) do
					if not bar.checked then
						bargroup:RemoveBar(bar)
					end
				end
			end

			if metadata.reversesort then
				bargroup:SetSortFunction(bar_order_reverse_sort)
			elseif metadata.ordersort then
				bargroup:SetSortFunction(db.reversegrowth and bar_order_reverse_sort or bar_order_sort)
			else
				bargroup:SetSortFunction(nil)
			end

			bargroup:SortBars()
		end
	end

	-- ======================================================= --

	do
		local math_abs = math.abs
		local CreateFrame = CreateFrame
		local SetCursor = SetCursor
		local ResetCursor = ResetCursor
		local GetCursorPosition = GetCursorPosition
		local IsMouseButtonDown = IsMouseButtonDown

		local f = CreateFrame("Frame")
		local scrollWin = nil
		local cursorYPos = nil
		local lastUpdated = 0
		local start_scroll = nil
		local stop_scroll = nil

		local function ShowCursor(win)
			if not mod.db.icon then return end

			SetCursor("")
			local icon = win.scroll_icon
			if not icon then
				icon = CreateFrame("Frame", nil, win.bargroup)
				icon:SetWidth(32)
				icon:SetHeight(32)
				icon:SetPoint("CENTER")
				icon:SetFrameLevel(win.bargroup:GetFrameLevel() + 6)

				local t = icon:CreateTexture(nil, "OVERLAY")
				t:SetTexture(format([[%s\Textures\icon-scroll]], Skada.mediapath))
				t:SetAllPoints(icon)

				win.scroll_icon = icon
			end
			icon:Show()
		end

		local function HideCursor(win)
			local icon = win and win.scroll_icon
			if not icon then return end
			ResetCursor()
			icon:Hide()
		end

		local function OnMouseWheel(win, direction)
			win.OnMouseWheel = win.OnMouseWheel or win:GetScript("OnMouseWheel")
			win.OnMouseWheel(win, direction)
		end

		local function OnUpdate(self, elapsed)
			-- no scrolled window
			if not scrollWin then
				stop_scroll()
				return
			end

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

		function start_scroll()
			f:SetScript("OnUpdate", OnUpdate)
			f:Show()
		end

		function stop_scroll()
			f:SetScript("OnUpdate", nil)
			f:Hide()
		end

		function mod:ScrollStart(win)
			_, cursorYPos = GetCursorPosition()
			scrollWin = win
			ShowCursor(win)
			start_scroll()
		end

		function mod:EndScroll(win)
			scrollWin = nil
			HideCursor(win)
			stop_scroll()
		end

		function Skada:Scroll(up)
			for _, win in pairs(mod:GetBarGroups()) do
				OnMouseWheel(win, up and 1 or -1)
			end
		end
	end

	-- ======================================================= --

	do
		local backdrop = {insets = {left = 0, right = 0, top = 0, bottom = 0}}

		-- Called by Skada windows when window settings have changed.
		function mod:ApplySettings(win)
			if not win or not win.bargroup then return end

			local g = win.bargroup
			local p = win.db

			g.name = p.name -- update name
			g:SetReverseGrowth(p.reversegrowth, p.title.swap)
			g:SetOrientation(p.barorientation)
			g:SetBarHeight(p.barheight)
			g:SetHeight(p.background.height)
			g:SetLength(p.barwidth)
			g:SetTexture(Skada:MediaFetch("statusbar", p.bartexture))
			g:SetDisableHighlight(p.disablehighlight)
			g:SetBarBackgroundColor(p.barbgcolor.r, p.barbgcolor.g, p.barbgcolor.b, p.barbgcolor.a or 0.6)
			g:SetAnchorMouseover(p.title.hovermode)
			g:SetButtonsOpacity(p.title.toolbaropacity or 0.25)
			g:SetButtonsSpacing(p.title.spacing or 1)
			g:SetUseSpark(p.spark)
			g:SetDisableResize(p.noresize)
			g:SetDisableStretch(p.nostrech)
			g:SetReverseStretch(p.botstretch)
			g:SetFont(Skada:MediaFetch("font", p.barfont), p.barfontsize, p.barfontflags, Skada:MediaFetch("font", p.numfont), p.numfontsize, p.numfontflags)
			g:SetSpacing(p.barspacing)
			g:SetColor(p.barcolor.r, p.barcolor.g, p.barcolor.b, p.barcolor.a)
			g:SetLocked(p.barslocked)
			g:SetDisplacement(p.baroffset or 0)

			if p.strata then
				g:SetFrameStrata(p.strata)
			end

			-- Header
			local fo = g.TitleFont or CreateFont(format("%s%sTitleFont", folder, win.db.name))
			g.TitleFont = fo
			fo:SetFont(p.title.fontpath or Skada:MediaFetch("font", p.title.font), p.title.fontsize, p.title.fontflags)
			if p.title.textcolor then
				fo:SetTextColor(p.title.textcolor.r, p.title.textcolor.g, p.title.textcolor.b, p.title.textcolor.a)
			end
			g.button:SetNormalFontObject(fo)
			g.button:SetHeight(p.title.height or 15)

			backdrop.bgFile = p.title.texturepath or Skada:MediaFetch("statusbar", p.title.texture)
			backdrop.tile = false
			backdrop.tileSize = 0
			backdrop.edgeSize = p.title.borderthickness
			backdrop.insets.left, backdrop.insets.right = 0, 0
			backdrop.insets.top, backdrop.insets.bottom = 0, 0
			g.button:SetBackdrop(backdrop)

			local color = p.title.color
			g.button:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
			Skada:ApplyBorder(g.button, p.title.bordertexture, p.title.bordercolor, p.title.borderthickness, p.title.borderinsets)

			if g.stretcher then
				g.stretcher.bg:SetTexture(backdrop.bgFile)
				g.stretcher.bg:SetVertexColor(color.r, color.g, color.b, color.a or 1)
			end

			g.button.toolbar = g.button.toolbar or p.title.toolbar or 1
			if g.button.toolbar ~= p.title.toolbar then
				g.button.toolbar = p.title.toolbar or 1
				for i = 1, #g.buttons do
					local b = g.buttons[i]
					b.normalTex:SetTexture(format(buttonsTexPath, g.button.toolbar, b.index))
					b.highlightTex:SetTexture(format(buttonsTexPath, g.button.toolbar, b.index), 1.0)
				end
			end

			if p.enabletitle then
				g:ShowAnchor()

				g:ShowButton(L["Configure"], p.buttons.menu)
				g:ShowButton(L["Reset"], p.buttons.reset)
				g:ShowButton(L["Segment"], p.buttons.segment)
				g:ShowButton(L["Mode"], p.buttons.mode)
				g:ShowButton(L["New Phase"], p.buttons.phase)
				g:ShowButton(L["New Segment"], p.buttons.split)
				g:ShowButton(L["Report"], p.buttons.report)
				g:ShowButton(L["Stop"], p.buttons.stop)
			else
				g:HideAnchor()
			end

			backdrop.bgFile = p.background.texturepath or Skada:MediaFetch("background", p.background.texture)
			backdrop.tile = p.background.tile
			backdrop.tileSize = p.background.tilesize
			backdrop.insets.left, backdrop.insets.right = 0, 0
			backdrop.insets.top, backdrop.insets.bottom = 0, 0
			if p.enabletitle and p.reversegrowth then
				backdrop.insets.top = p.title.swap and p.title.height or 0
				backdrop.insets.bottom = p.title.swap and 0 or p.title.height
			elseif p.enabletitle then
				backdrop.insets.top = p.title.swap and 0 or p.title.height
				backdrop.insets.bottom = p.title.swap and p.title.height or 0
			end
			g:SetBackdrop(backdrop)

			color = p.background.color
			g:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
			Skada:ApplyBorder(g, p.background.bordertexture, p.background.bordercolor, p.background.borderthickness, p.background.borderinsets)

			color = p.textcolor or COLOR_WHITE
			g:SetTextColor(color.r, color.g, color.b, color.a or 1)
			g:SetSticky(p.sticky, folder)

			-- make player's bar fixed.
			g.showself = P.showself or p.showself

			g:SetClickthrough(p.clickthrough)
			g:SetClampedToScreen(p.clamped == true)
			g:SetSmoothing(p.smoothing)
			g:SetShown(not p.hidden)
			g:SetScale(p.scale or 1)
			g:SortBars()

			-- restore position
			RestorePosition(g, p)
		end

		function mod:WindowResizing(_, group)
			if group and not group.isStretching and group.win and group.win.db and group.win.db.sticky then
				local offset = group.win.db.background.borderthickness
				for i = 1, #windows do
					local win = windows[i]
					if win and win.db and win.db.display == "bar" and win.bargroup:IsShown() and group.win.db.sticked and group.win.db.sticked[win.db.name] then
						win.bargroup:Stick(group, nil, offset, offset)
					end
				end
			end
		end
	end

	local optionsValues = {
		ORIENTATION = {
			[LEFT_TO_RIGHT] = L["Left to right"],
			[RIGHT_TO_LEFT] = L["Right to left"]
		},
		TITLEBTNS = {
			[1] = format("\124T%s:22:88\124t", format(buttonsTexPath, 1, "_prev")),
			[2] = format("\124T%s:22:88\124t", format(buttonsTexPath, 2, "_prev"))
		}
	}

	local FrameOptions = Private.FrameOptions

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
				local key = i[#i]
				db[key] = (type(val) == "boolean" and val or nil) or val
				if key == "showtotals" or key == "classcolortext" or key == "classcolorleft" or key == "classcolorright" then
					win:Wipe(true)
				end
				Skada:ApplySettings(win)
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
						baroffset = {
							type = "range",
							name = L["Displacement"],
							desc = L["The distance between the edge of the window and the first bar."],
							order = 50,
							min = 0,
							max = 40,
							step = 0.01,
							bigStep = 1
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
								local c = db.barcolor or WINDOW_DEFAULTS.barcolor
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
							desc = L["The color of the background."],
							order = 90,
							hasAlpha = true,
							get = function()
								local c = db.barbgcolor or WINDOW_DEFAULTS.barbgcolor
								return c.r, c.g, c.b, c.a or 1
							end,
							set = function(_, r, g, b, a)
								db.barbgcolor = db.barbgcolor or {}
								db.barbgcolor.r, db.barbgcolor.g, db.barbgcolor.b, db.barbgcolor.a = r, g, b, a
								Skada:ApplySettings(db.name)
							end
						},
						useselfcolor = {
							type = "toggle",
							name = L["Custom Color"],
							desc = L["Use a different color for my bar."],
							order = 100
						},
						selfcolor = {
							type = "color",
							name = L["My Color"],
							order = 110,
							hasAlpha = true,
							get = function()
								local c = db.selfcolor or WINDOW_DEFAULTS.barcolor
								return c.r, c.g, c.b, c.a or 1
							end,
							set = function(_, r, g, b, a)
								db.selfcolor = db.selfcolor or {}
								db.selfcolor.r, db.selfcolor.g, db.selfcolor.b, db.selfcolor.a = r, g, b, a
								Skada:ApplySettings(db.name)
							end,
							disabled = function()
								return not db.useselfcolor
							end
						},
						classcolorbars = {
							type = "toggle",
							name = L["Class Colors"],
							desc = L["When possible, bars will be colored according to player class."],
							order = 120
						},
						spellschoolcolors = {
							type = "toggle",
							name = L["Spell school colors"],
							desc = L["Use spell school colors where applicable."],
							order = 130
						},
						classicons = {
							type = "toggle",
							name = L["Class Icons"],
							desc = L["Use class icons where applicable."],
							order = 140,
							disabled = function()
								return (db.specicons or db.roleicons)
							end
						},
						roleicons = {
							type = "toggle",
							name = L["Role Icons"],
							desc = L["Use role icons where applicable."],
							order = 150,
							set = function()
								db.roleicons = not db.roleicons
								if db.roleicons and not db.classicons then
									db.classicons = true
								end
								win:Wipe(true)
								Skada:ApplySettings(win)
							end
						},
						specicons = {
							type = "toggle",
							name = L["Spec Icons"],
							desc = L["Use specialization icons where applicable."],
							order = 160,
							set = function()
								db.specicons = not db.specicons
								if db.specicons and not db.classicons then
									db.classicons = true
								end
								win:Wipe(true)
								Skada:ApplySettings(win)
							end
						},
						spark = {
							type = "toggle",
							name = L["Show Spark Effect"],
							order = 170
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
							desc = L["opt_showself_desc"],
							descStyle = "inline",
							width = "double",
							disabled = function() return P.showself end,
							hidden = function() return P.showself end,
							order = 10
						},
						showtotals = {
							type = "toggle",
							name = L["Show totals"],
							desc = L["Shows a extra row with a summary in certain modes."],
							descStyle = "inline",
							width = "double",
							disabled = function() return P.showtotals end,
							hidden = function() return P.showtotals end,
							order = 20
						},
						disablehighlight = {
							type = "toggle",
							name = L["Disable bar highlight"],
							desc = L["Hovering a bar won't make it brighter."],
							descStyle = "inline",
							width = "double",
							order = 30
						},
						clickthrough = {
							type = "toggle",
							name = L["Click Through"],
							desc = L["Disables mouse clicks on bars."],
							descStyle = "inline",
							width = "double",
							order = 40
						},
						smoothing = {
							type = "toggle",
							name = L["Smooth Bars"],
							desc = L["Animate bar changes smoothly rather than immediately."],
							descStyle = "inline",
							width = "double",
							order = 50
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
							width = "double",
							order = 0,
							get = function()
								return db.enabletitle
							end,
							set = function()
								db.enabletitle = not db.enabletitle
								Skada:ApplySettings(db.name)
							end
						},
						swap = {
							type = "toggle",
							name = L["Swap Position"],
							desc = L["When enabled, the title bar will be moved to the opposite side of its current position."],
							order = 10
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
									desc = L["The color of the background."],
									order = 20,
									hasAlpha = true,
									get = function()
										local c = db.title.color or WINDOW_DEFAULTS.title.color
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
									desc = L["The texture used for the borders."],
									order = 10,
									values = Skada:MediaList("border")
								},
								bordercolor = {
									type = "color",
									name = L["Border Color"],
									desc = L["The color used for the border."],
									hasAlpha = true,
									order = 20,
									get = function()
										local c = db.title.bordercolor or WINDOW_DEFAULTS.title.bordercolor
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
								},
								borderinsets = {
									type = "range",
									name = L["Border Insets"],
									desc = L["The distance between the window and its border."],
									order = 40,
									min = -32,
									max = 32,
									step = 0.01,
									bigStep = 1
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
								local c = db.title.textcolor or WINDOW_DEFAULTS.title.textcolor
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
									desc = L["btn_config_desc"],
									order = 10
								},
								reset = {
									type = "toggle",
									name = L["Reset"],
									desc = L["btn_reset_desc"],
									order = 20
								},
								segment = {
									type = "toggle",
									name = L["Segment"],
									desc = L["btn_segment_desc"],
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
									desc = L["btn_report_desc"],
									order = 50
								},
								stop = {
									type = "toggle",
									name = L["Stop"],
									desc = L["btn_stop_desc"],
									order = 60
								},
								split = {
									type = "toggle",
									name = L["New Segment"],
									desc = L["Starts a new segment."],
									order = 70
								},
								phase = {
									type = "toggle",
									name = L["New Phase"],
									desc = L["Starts a new phase."],
									order = 80
								}
							}
						},
						style = {
							type = "multiselect",
							name = L["Buttons Style"],
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

		options.windowoptions = FrameOptions(db)

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

		local x, y = floor(GetScreenWidth() * 0.025) * 20, floor(GetScreenHeight() * 0.025) * 20
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
					RestorePosition(window, db)
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
					RestorePosition(window, db)
				end
			end
		}
	end

	-- ======================================================= --

	do
		local tremove = table.remove
		local strmatch = strmatch or string.match
		local GetBindingKey = GetBindingKey
		local SetBinding = SetBinding
		local SaveBindings = SaveBindings
		local GetCurrentBindingSet = GetCurrentBindingSet

		local opt_themes
		local function GetThemeOptions()
			GetThemeOptions = nil
			if opt_themes then
				return opt_themes
			end

			local applytheme, applywindow = nil, nil
			local savetheme, savewindow = nil, nil
			local skipped = {"name", "x", "y", "sticked", "set", "modeincombat", "wipemode", "returnaftercombat"}
			local list = {}

			local themes = {
				["All glowy 'n stuff"] = {
					barspacing = 0,
					bartexture = "LiteStep",
					barfont = "ABF",
					barfontflags = "",
					barfontsize = 12,
					barheight = 16,
					barwidth = 240,
					baroffset = 0,
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
						borderinsets = 0,
						color = {r = 0.6, g = 0.6, b = 0.8, a = 1},
						fontflags = ""
					},
					background = {
						height = 195,
						texture = "None",
						bordercolor = {r = 0.9, g = 0.9, b = 0.5, a = 0.6},
						bordertexture = "Glow",
						borderthickness = 5,
						borderinsets = 0,
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
				["Minimalistic"] = {
					barspacing = 0,
					bartexture = "Armory",
					barfont = "Accidental Presidency",
					barfontflags = "",
					barfontsize = 12,
					barheight = 16,
					barwidth = 240,
					baroffset = 0,
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
						borderinsets = 0,
						color = {r = 0.6, g = 0.6, b = 0.8, a = 1},
						fontflags = ""
					},
					background = {
						height = 195,
						texture = "None",
						bordercolor = {r = 0, g = 0, b = 0, a = 1},
						bordertexture = "Blizzard Party",
						borderthickness = 0,
						borderinsets = 0,
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
				["Omen Threat Meter"] = {
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
					baroffset = 0,
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
						borderthickness = 0,
						borderinsets = 0,
						color = {r = 0.2, g = 0.2, b = 0.2, a = 0},
						fontflags = ""
					},
					background = {
						height = 108,
						texture = "Blizzard Parchment",
						bordercolor = {r = 1, g = 1, b = 1, a = 1},
						bordertexture = "Blizzard Dialog",
						borderthickness = 0,
						borderinsets = 0,
						color = {r = 1, g = 1, b = 1, a = 1},
						tilesize = 0
					},
					strata = "LOW",
					scale = 1,
					enabletitle = true,
					display = "bar"
				},
				["Recount"] = {
					barspacing = 0,
					bartexture = "BantoBar",
					barfont = "Arial Narrow",
					barfontflags = "",
					barfontsize = 12,
					barheight = 18,
					barwidth = 240,
					baroffset = 0,
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
						borderinsets = 0,
						color = {r = 1, g = 0, b = 0, a = 0.75},
						fontflags = ""
					},
					background = {
						height = 150,
						texture = "Solid",
						bordercolor = {r = 0.9, g = 0.9, b = 0.5, a = 0.6},
						bordertexture = "None",
						borderthickness = 5,
						borderinsets = 0,
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
				["Skada default (Legion)"] = {
					barspacing = 0,
					bartexture = "BantoBar",
					barfont = "Accidental Presidency",
					barfontflags = "",
					barfontsize = 13,
					barheight = 18,
					barwidth = 240,
					baroffset = 0,
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
						borderinsets = 0,
						color = {r = 0.3, g = 0.3, b = 0.3, a = 1},
						fontflags = ""
					},
					background = {
						height = 200,
						texture = "Solid",
						bordercolor = {r = 0, g = 0, b = 0, a = 1},
						bordertexture = "Blizzard Party",
						borderthickness = 2,
						borderinsets = 0,
						color = {r = 0, g = 0, b = 0, a = 0.4},
						tilesize = 0
					},
					strata = "LOW",
					scale = 1,
					enabletitle = true,
					titleset = true,
					display = "bar",
					snapto = true
				}
			}

			local function theme_locked()
				return (applytheme == nil or themes[applytheme])
			end

			local function check_theme_name(name)
				return CheckDuplicate(CheckDuplicate(name, themes), G.themes)
			end

			local ImportExport = Private.ImportExport
			local serialize, deserialize = Private.serialize, Private.deserialize
			local temp = {}

			local function theme_export()
				local theme = not theme_locked() and G.themes and G.themes[applytheme]
				if not theme then return end

				wipe(temp)
				copy(temp, theme)
				temp.__name = applytheme
				return ImportExport(L["This is your current theme in text format."], serialize(false, temp))
			end

			local function theme_import(data)
				if type(data) ~= "string" then
					Skada:Print("Import theme failed, data supplied must be a string.")
					return false
				end

				local success, theme = deserialize(data)
				if not success or theme.bartexture == nil then -- sanity check!
					Skada:Print("Import theme failed!")
					return false
				end

				local name = check_theme_name(theme.__name)
				theme.__name = nil
				G.themes = G.themes or {}
				G.themes[name] = theme
				Skada:NotifyChange()
			end

			opt_themes = {
				type = "group",
				name = L["Themes"],
				desc = format(L["Options for %s."], L["Themes"]),
				args = {
					manage = {
						type = "group",
						name = L["Manage Themes"],
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
									for name in pairs(themes) do
										list[name] = name
									end
									if G.themes then
										for name in pairs(G.themes) do
											list[name] = name
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
								disabled = function() return (applytheme == nil) end,
								values = function()
									wipe(list)
									list["**"] = L["All Windows"]
									for i = 1, #windows do
										local win = windows[i]
										if win and win.db and win.db.display == "bar" then
											list[win.db.name] = win.db.name
										end
									end
									return list
								end
							},
							export = {
								type = "execute",
								name = L["Export"],
								order = 30,
								disabled = theme_locked,
								func = theme_export
							},
							apply = {
								type = "execute",
								name = L["Apply"],
								desc = L["Apply Theme"],
								order = 40,
								disabled = function()
									return (applytheme == nil or applywindow == nil)
								end,
								func = function()
									if applywindow and applytheme then
										local theme = themes[applytheme] or G.themes and G.themes[applytheme]
										if theme then
											for i = 1, #windows do
												local win = windows[i]
												if win and win.db and (applywindow == "**" or win.db.name == applywindow) then
													copy(win.db, theme, skipped)
													Skada:ApplySettings()
													applytheme = nil
													-- single window? no need to go further..
													if win.db.name == applywindow then break end
												end
											end
											if not applytheme then
												Skada:Print(L["Theme applied!"])
											end
										end
									end
									applytheme, applywindow = nil, nil
								end
							},
							import = {
								type = "execute",
								name = L["Import"],
								order = 50,
								func = function()
									return ImportExport(L["Paste here a theme in text format."], theme_import)
								end
							},
							delete = {
								type = "execute",
								name = L["Delete"],
								desc = L["Delete Theme"],
								order = 60,
								disabled = theme_locked,
								confirm = function() return L["Are you sure you want to delete this theme?"] end,
								func = function()
									G.themes[applytheme] = del(G.themes[applytheme], true)
									applytheme = nil
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
									for i = 1, #windows do
										local win = windows[i]
										if win and win.db and win.db.display == "bar" then
											list[win.db.name] = win.db.name
										end
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
								set = function(_, val) savetheme = val end,
								disabled = function() return (savewindow == nil) end
							},
							exec = {
								type = "execute",
								name = L["Save"],
								width = "double",
								order = 30,
								disabled = function() return (savewindow == nil or savetheme == nil or savetheme:trim() == "") end,
								func = function()
									for i = 1, #windows do
										local win = windows[i]
										if win and win.db and win.db.name == savewindow then
											G.themes = G.themes or {}
											local theme = {}
											copy(theme, win.db, skipped)
											local name = check_theme_name(savetheme or win.db.name)
											G.themes[name] = theme
											break -- stop
										end
									end
									savetheme, savewindow = nil, nil
								end
							}
						}
					}
				}
			}

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
									desc = L["opt_wheelspeed_desc"],
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

			GetScrollOptions = nil
			return opt_scroll
		end

		function mod:OnEnable()
			self:RegisterCallback("OnRemoveFrame")
			self:RegisterCallback("OnAnchorFrame")
			self:RegisterCallback("BarClick")
			self:RegisterCallback("BarEnter")
			self:RegisterCallback("BarLeave")
			self:RegisterCallback("BarReleased")
			self:RegisterCallback("WindowMoveStart")
			self:RegisterCallback("WindowMoveStop")
			self:RegisterCallback("WindowResized")
			self:RegisterCallback("WindowLocked")
			self:RegisterCallback("WindowResizing")
			self:RegisterCallback("WindowStretching")
			self:RegisterCallback("WindowStretchStart")
			self:RegisterCallback("WindowStretchStop")
		end

		function mod:OnInitialize()
			self.description = L["mod_bar_desc"]
			Skada:AddDisplaySystem("bar", self, true)

			self.db = P.scroll
			if not self.db then
				self.db = {speed = 2, icon = true, button = "MiddleButton"}
				P.scroll = self.db
			end

			O.themeoptions = GetThemeOptions()
			O.themeoptions.order = 960

			O.tweaks.args.advanced.args.scroll = GetScrollOptions()
			O.tweaks.args.advanced.args.scroll.order = 980

			self:SetScrollSpeed(self.db.speed)

			validclass = validclass or Skada.validclass
			classcolors = classcolors or Skada.classcolors
			classicons = classicons or Skada.classicons
			classcoords = classcoords or Skada.classcoords
			roleicons = roleicons or Skada.roleicons
			rolecoords = rolecoords or Skada.rolecoords
			specicons = specicons or Skada.specicons
			speccoords = speccoords or Skada.speccoords
			spellschools = spellschools or Skada.spellschools
			windows = windows or Skada.windows

			-- fix old saved themes!
			if G.themes and #G.themes > 0 then
				local i = 1
				local theme = G.themes[i]
				while theme do
					local name = theme.name or format("%s (%d)", L["Unknown"], i)
					theme.name = nil
					G.themes[name] = theme
					tremove(G.themes, i)

					i = i + 1
					theme = G.themes[i]
				end
			end
		end
	end

	_G.BINDING_NAME_SKADA_SCROLLUP = L["Scroll Up"]
	_G.BINDING_NAME_SKADA_SCROLLDOWN = L["Scroll Down"]
end)
