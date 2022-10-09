local _, Skada = ...
local private = Skada.private
Skada:RegisterDisplay("Legacy Bar Display", "mod_bar_desc", function(L, P)

	local mod = Skada:NewModule("Legacy Bar Display", "LegacyLibBars-1.0")

	local pairs, type, format, tsort = pairs, type, string.format, table.sort
	local SavePosition, RestorePosition = private.SavePosition, private.RestorePosition
	local classcolors = Skada.classcolors
	local white = {r = 1, g = 1, b = 1, a = 1}

	-- Display implementation.
	function mod:OnInitialize()
		classcolors = classcolors or Skada.classcolors
		self.description = L["mod_bar_desc"]
		Skada:AddDisplaySystem("legacy", self)
	end

	-- Called when a Skada window starts using this display provider.
	function mod:Create(window)
		-- Re-use bargroup if it exists.
		window.bargroup = mod:GetBarGroup(window.db.name)

		-- Save a reference to window in bar group. Needed for some nasty callbacks.
		if window.bargroup then
			-- Clear callbacks.
			window.bargroup.callbacks = LibStub:GetLibrary("CallbackHandler-1.0"):New(window.bargroup)
		else
			window.bargroup = mod:NewBarGroup(window.db.name, nil, window.db.barwidth, window.db.barheight, "SkadaBarWindow" .. window.db.name)
		end
		window.bargroup.win = window
		window.bargroup.RegisterCallback(mod, "AnchorMoved")
		window.bargroup.RegisterCallback(mod, "AnchorClicked")
		window.bargroup.RegisterCallback(mod, "ConfigClicked")
		window.bargroup:EnableMouse(true)
		window.bargroup:SetScript("OnMouseDown", function(win, button)
			if button == "RightButton" then
				window:RightClick()
			end
		end)
		window.bargroup:HideIcon()

		-- Restore window position.
		RestorePosition(window.bargroup, window.db)
	end

	-- Called by Skada windows when the window is to be destroyed/cleared.
	function mod:Destroy(win)
		win.bargroup:Hide()
		win.bargroup.bgframe = nil
		win.bargroup = nil
	end

	-- Called by Skada windows when the window is to be completely cleared and prepared for new data.
	function mod:Wipe(win)
		-- Reset sort function.
		win.bargroup:SetSortFunction(nil)

		-- Reset scroll offset.
		win.bargroup:SetBarOffset(0)

		-- Remove the bars.
		local bars = win.bargroup:GetBars()
		if bars then
			for i, bar in pairs(bars) do
				bar:Hide()
				win.bargroup:RemoveBar(bar)
			end
		end

		-- Clean up.
		win.bargroup:SortBars()
	end

	local function showmode(win, id, label, mode)
		-- Add current mode to window traversal history.
		if win.selectedmode then
			win.history[#win.history + 1] = win.selectedmode
		end

		if type(mode) == "function" then
			mode(mode, win, id, label)
		else
			if mode.Enter then
				mode:Enter(win, id, label, mode)
			end
			win:DisplayMode(mode)
		end
	end

	local function BarClick(bar, button)
		if Skada.testMode then return end

		local win, id, label = bar.win, bar.id, bar.text

		local click1 = win.metadata.click1
		local click2 = win.metadata.click2
		local click3 = win.metadata.click3

		if button == "RightButton" and IsShiftKeyDown() then
			Skada:OpenMenu(win)
		elseif win.metadata.click then
			win.metadata.click(win, id, label, button)
		elseif button == "RightButton" then
			win:RightClick()
		elseif click2 and IsShiftKeyDown() then
			showmode(win, id, label, click2)
		elseif click3 and IsControlKeyDown() then
			showmode(win, id, label, click3)
		elseif click1 then
			showmode(win, id, label, click1)
		end
	end

	function mod:SetTitle(win, title)
		win.bargroup.button:SetText(win.metadata.title)
	end

	local ttactive = false

	local function BarEnter(bar, motion)
		if bar and bar.win then
			local win, id, label = bar.win, bar.id, bar.text
			ttactive = true
			Skada:SetTooltipPosition(GameTooltip, win.bargroup, "legacy", win)
			Skada:ShowTooltip(win, id, label, bar)
		end
	end

	local function BarLeave(win, id, label)
		if ttactive then
			GameTooltip:Hide()
			ttactive = false
		end
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

	local function bar_order_reverse_sort(a, b)
		return a and b and a.order and b.order and a.order < b.order
	end

	local function bar_seticon(bar, db, data, icon)
		if icon then
			bar:SetIcon(icon)
			bar:ShowIcon()
		elseif data.icon and not data.ignore and not data.spellid and not data.hyperlink then
			bar:SetIcon(data.icon)
			bar:ShowIcon()
		end
	end

	local function bar_setcolor(bar, db, data, color)
		local default = db.barcolor or Skada.windowdefaults.barcolor
		if not color and data.color then
			color = data.color
		elseif not color and db.classcolorbars and data.class then
			color = classcolors(data.class)
		end

		color = color or default
		bar:SetColorAt(0, color.r, color.g, color.b, color.a or 1)
	end

	-- Called by Skada windows when the display should be updated to match the dataset.
	function mod:Update(win)
		if not win or not win.bargroup then return end

		-- Set title.
		win.bargroup.button:SetText(win.metadata.title)

		-- Sort if we are showing spots with "showspots".
		local metadata = win.metadata
		local dataset = win.dataset
		if metadata.showspots or metadata.valueorder then
			tsort(dataset, value_sort)
		end

		-- If we are using "wipestale", we may have removed data
		-- and we need to remove unused bars.
		-- The Threat module uses this.
		-- For each bar, mark bar as unchecked.
		if metadata.wipestale then
			local bars = win.bargroup:GetBars()
			if bars then
				for name, bar in pairs(bars) do
					bar.checked = nil
				end
			end
		end

		local nr = 1
		for i = 1, #dataset do
			local data = dataset[i]
			if data and data.id then
				local barid = data.id
				local barlabel = data.label

				local bar = win.bargroup:GetBar(barid)

				if bar then
					bar:SetMaxValue(metadata.maxvalue or 1)
					bar:SetValue(data.value)
				else
					-- Initialization of bars.
					bar = mod:CreateBar(win, barid, barlabel, data.value, metadata.maxvalue or 1, data.icon, false)
					if data.icon and not data.ignore then
						bar:ShowIcon()
					end
					bar:EnableMouse()
					bar.id = data.id
					bar.text = data.label

					bar:SetScript("OnEnter", BarEnter)
					bar:SetScript("OnLeave", BarLeave)
					bar:SetScript("OnMouseDown", BarClick)

					-- Spark.
					if win.db.spark then
						bar.spark:Show()
					else
						bar.spark:Hide()
					end

					bar_seticon(bar, win.db, data)
					bar_setcolor(bar, win.db, data)

					local color = data.class and win.db.classcolortext and classcolors[data.class] or white
					bar.label:SetTextColor(color.r, color.g, color.b, color.a or 1)
					bar.timerLabel:SetTextColor(color.r, color.g, color.b, color.a or 1)
				end

				if metadata.ordersort then
					bar.order = i
				end

				if metadata.showspots and P.showranks then
					if win.db.barorientation == 3 then
						bar:SetLabel(format("%s .%2u", data.label, nr))
					else
						bar:SetLabel(format("%2u. %s", nr, data.label))
					end
				else
					bar:SetLabel(data.label)
				end
				bar:SetTimerLabel(data.valuetext)

				if metadata.wipestale then
					bar.checked = true
				end

				-- Emphathized items - cache a flag saying it is done so it is not done again.
				-- This is a little lame.
				if data.emphathize and bar.emphathize_set ~= true then
					bar:SetFont(nil, nil, "OUTLINE")
					bar.emphathize_set = true
				elseif not data.emphathize and bar.emphathize_set ~= false then
					bar:SetFont(nil, nil, "PLAIN")
					bar.emphathize_set = false
				end

				-- Background texture color.
				if data.backgroundcolor then
					bar.bgtexture:SetVertexColor(
						data.backgroundcolor.r,
						data.backgroundcolor.g,
						data.backgroundcolor.b,
						data.backgroundcolor.a or 1
					)
				end

				-- Background texture size (in percent, as the mode has no idea on actual widths).
				if data.backgroundwidth then
					bar.bgtexture:ClearAllPoints()
					bar.bgtexture:SetPoint("BOTTOMLEFT")
					bar.bgtexture:SetPoint("TOPLEFT")
					bar.bgtexture:SetWidth(data.backgroundwidth * bar:GetLength())
				end

				if not data.ignore then
					nr = nr + 1

					if data.changed and not bar.changed then
						bar.changed = true
						bar_seticon(bar, win.db, data, data.icon)
						bar_setcolor(bar, win.db, data, data.color)
					elseif not data.changed and bar.changed then
						bar.changed = nil
						bar_seticon(bar, win.db, data)
						bar_setcolor(bar, win.db, data)
					end
				end
			end
		end

		-- If we are using "wipestale", remove all unchecked bars.
		if metadata.wipestale then
			local bars = win.bargroup:GetBars()
			for name, bar in pairs(bars) do
				if not bar.checked then
					win.bargroup:RemoveBar(bar)
				end
			end
		end

		-- Adjust our background frame if background height is dynamic.
		if win.bargroup.bgframe and win.db.background.height == 0 then
			self:AdjustBackgroundHeight(win)
		end

		-- Sort by the order in the data table if we are using "ordersort".
		if metadata.reversesort then
			win.bargroup:SetSortFunction(bar_order_reverse_sort)
		elseif metadata.ordersort then
			win.bargroup:SetSortFunction(win.db.reversegrowth and bar_order_reverse_sort or bar_order_sort)
		else
			win.bargroup:SetSortFunction(nil)
		end

		win.bargroup:SortBars()
	end

	function mod:AdjustBackgroundHeight(win)
		local numbars = 0
		if win.bargroup:GetBars() ~= nil then
			for name, bar in pairs(win.bargroup:GetBars()) do
				if bar:IsShown() then
					numbars = numbars + 1
				end
			end
			local height = numbars * (win.db.barheight + win.db.barspacing) + win.db.background.borderthickness
			if win.bargroup.bgframe:GetHeight() ~= height then
				win.bargroup.bgframe:SetHeight(height)
			end
		end
	end

	function mod:ConfigClicked(cbk, group, button)
		Skada:OpenMenu(group.win)
	end

	function mod:AnchorClicked(cbk, group, button)
		if IsShiftKeyDown() then
			Skada:OpenMenu(group.win)
		elseif button == "RightButton" then
			group.win:RightClick()
		end
	end

	function mod:AnchorMoved(cbk, group, x, y)
		SavePosition(group, group.win.db)
	end

	function mod:Show(win)
		win.bargroup:Show()
		win.bargroup:SortBars()
	end

	function mod:Hide(win)
		win.bargroup:Hide()
	end

	function mod:IsShown(win)
		return win.bargroup:IsShown()
	end

	local function getNumberOfBars(win)
		local bars = win.bargroup:GetBars()
		local n = 0
		for i, bar in pairs(bars) do
			n = n + 1
		end
		return n
	end

	function mod:OnMouseWheel(win, frame, direction)
		if direction == 1 and win.bargroup:GetBarOffset() > 0 then
			win.bargroup:SetBarOffset(win.bargroup:GetBarOffset() - 1)
		elseif direction == -1 and ((getNumberOfBars(win) - win.bargroup:GetMaxBars() - win.bargroup:GetBarOffset()) > 0) then
			win.bargroup:SetBarOffset(win.bargroup:GetBarOffset() + 1)
		end
	end

	function mod:CreateBar(win, name, label, value, maxvalue, icon, o)
		local bar = win.bargroup:NewCounterBar(name, label, value, maxvalue, icon, o)
		bar:EnableMouseWheel(true)
		bar:SetScript("OnMouseWheel", function(f, d) mod:OnMouseWheel(win, f, d) end)
		bar.win = win
		return bar
	end

	local titlebackdrop = {}
	local windowbackdrop = {}

	-- Called by Skada windows when window settings have changed.
	function mod:ApplySettings(win)
		local g = win.bargroup
		local p = win.db
		g:ReverseGrowth(p.reversegrowth)
		g:SetOrientation(p.barorientation)
		g:SetHeight(p.barheight)
		g:SetWidth(p.barwidth)
		g:SetTexture(Skada:MediaFetch("statusbar", p.bartexture))
		g:SetFont(Skada:MediaFetch("font", p.barfont), p.barfontsize)
		g:SetSpacing(p.barspacing)
		g:UnsetAllColors()
		g:SetColorAt(0, p.barcolor.r, p.barcolor.g, p.barcolor.b, p.barcolor.a)
		g:SetMaxBars(p.barmax)
		if p.barslocked then
			g:Lock()
		else
			g:Unlock()
		end

		-- Header
		local fo = CreateFont("TitleFont" .. win.db.name)
		fo:SetFont(Skada:MediaFetch("font", p.title.font), p.title.fontsize)
		g.button:SetNormalFontObject(fo)
		local inset = p.title.borderinsets
		titlebackdrop.bgFile = Skada:MediaFetch("statusbar", p.title.texture)
		if p.title.borderthickness > 0 then
			titlebackdrop.edgeFile = Skada:MediaFetch("border", p.title.bordertexture)
		else
			titlebackdrop.edgeFile = nil
		end
		titlebackdrop.tile = false
		titlebackdrop.tileSize = 0
		titlebackdrop.edgeSize = p.title.borderthickness
		titlebackdrop.insets = {left = inset, right = inset, top = inset, bottom = inset}
		g.button:SetBackdrop(titlebackdrop)
		local color = p.title.color
		g.button:SetBackdropColor(color.r, color.g, color.b, color.a or 1)

		if p.enabletitle then
			g:ShowAnchor()
		else
			g:HideAnchor()
		end

		-- Spark.
		for i, bar in pairs(g:GetBars()) do
			if p.spark then
				bar.spark:Show()
			else
				bar.spark:Hide()
			end
		end

		-- Header config button
		g.optbutton:ClearAllPoints()
		g.optbutton:SetPoint("TOPRIGHT", g.button, "TOPRIGHT", -5, 0 - (math.max(g.button:GetHeight() - g.optbutton:GetHeight(), 1) * 0.5))

		-- Menu button - default on.
		if p.title.menubutton == nil or p.title.menubutton then
			g.optbutton:Show()
		else
			g.optbutton:Hide()
		end

		-- Window
		if p.enablebackground then
			if g.bgframe == nil then
				g.bgframe = CreateFrame("Frame", p.name .. "BG", g)
				g.bgframe:SetFrameStrata("BACKGROUND")
				g.bgframe:EnableMouse()
				g.bgframe:EnableMouseWheel()
				g.bgframe:SetScript("OnMouseDown", function(frame, btn)
					if IsShiftKeyDown() then
						Skada:OpenMenu(win)
					elseif btn == "RightButton" then
						win:RightClick()
					end
				end)
				g.bgframe:SetScript("OnMouseWheel", win.OnMouseWheel)
			end

			inset = p.background.borderinsets
			windowbackdrop.bgFile = Skada:MediaFetch("background", p.background.texture)
			if p.background.borderthickness > 0 then
				windowbackdrop.edgeFile = Skada:MediaFetch("border", p.background.bordertexture)
			else
				windowbackdrop.edgeFile = nil
			end
			windowbackdrop.tile = false
			windowbackdrop.tileSize = 0
			windowbackdrop.edgeSize = p.background.borderthickness
			windowbackdrop.insets = {left = inset, right = inset, top = inset, bottom = inset}
			g.bgframe:SetBackdrop(windowbackdrop)
			color = p.background.color
			g.bgframe:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
			g.bgframe:SetWidth(g:GetWidth() + (p.background.borderthickness * 2))
			g.bgframe:SetHeight(p.background.height)

			g.bgframe:ClearAllPoints()
			if p.reversegrowth then
				g.bgframe:SetPoint("LEFT", g.button, "LEFT", -p.background.borderthickness, 0)
				g.bgframe:SetPoint("RIGHT", g.button, "RIGHT", p.background.borderthickness, 0)
				g.bgframe:SetPoint("BOTTOM", g.button, "TOP", 0, 0)
			else
				g.bgframe:SetPoint("LEFT", g.button, "LEFT", -p.background.borderthickness, 0)
				g.bgframe:SetPoint("RIGHT", g.button, "RIGHT", p.background.borderthickness, 0)
				g.bgframe:SetPoint("TOP", g.button, "BOTTOM", 0, 5)
			end
			g.bgframe:Show()

			-- Calculate max number of bars to show if our height is not dynamic.
			if p.background.height > 0 then
				local maxbars = math.floor(p.background.height / math.max(1, p.barheight + p.barspacing))
				g:SetMaxBars(maxbars)
			else
				-- Adjust background height according to current bars.
				self:AdjustBackgroundHeight(win)
			end
		elseif g.bgframe then
			g.bgframe:Hide()
		end

		g:SortBars()
	end

	--
	-- Options.
	--

	local optionsValues = {
		ORIENTATION = {
			[1] = L["Left to right"],
			[3] = L["Right to left"]
		}
	}

	function mod:AddDisplayOptions(win, options)
		local db = win.db

		options.baroptions = {
			type = "group",
			name = L["Bars"],
			order = 1,
			get = function(info)
				return db[info[#info]]
			end,
			set = function(info, value)
				db[info[#info]] = value
				Skada:ApplySettings(db.name)
			end,
			args = {
				barfont = {
					type = "select",
					name = L["Font"],
					desc = format(L["The font used by %s."], L["Bars"]),
					order = 10,
					dialogControl = "LSM30_Font",
					values = Skada:MediaList("font")
				},
				barfontsize = {
					type = "range",
					name = L["Font Size"],
					desc = format(L["The font size of %s."], L["Bars"]),
					min = 7,
					max = 40,
					step = 1,
					order = 11
				},
				bartexture = {
					type = "select",
					name = L["Bar Texture"],
					desc = L["The texture used by all bars."],
					width = "double",
					order = 12,
					dialogControl = "LSM30_Statusbar",
					values = Skada:MediaList("statusbar")
				},
				barspacing = {
					type = "range",
					name = L["Spacing"],
					desc = format(L["Distance between %s."], L["Bars"]),
					min = 0,
					max = 10,
					step = 1,
					order = 13
				},
				barheight = {
					type = "range",
					name = L["Height"],
					desc = format(L["The height of %s."], L["Bars"]),
					min = 10,
					max = 40,
					step = 1,
					order = 14
				},
				barwidth = {
					type = "range",
					name = L["Width"],
					desc = format(L["The width of %s."], L["Bars"]),
					min = 80,
					max = 400,
					step = 1,
					order = 14
				},
				barmax = {
					type = "range",
					name = L["Max Bars"],
					desc = L["The maximum number of bars shown."],
					min = 0,
					max = 100,
					step = 1,
					order = 15
				},
				barorientation = {
					type = "select",
					name = L["Bar Orientation"],
					desc = L["The direction the bars are drawn in."],
					values = optionsValues.ORIENTATION,
					width = "double",
					order = 17
				},
				reversegrowth = {
					type = "toggle",
					name = L["Reverse bar growth"],
					desc = L["Bars will grow up instead of down."],
					width = "double",
					order = 19
				},
				barcolor = {
					type = "color",
					name = L["Bar Color"],
					desc = L["Choose the default color of the bars."],
					hasAlpha = true,
					get = function(i)
						local c = db.barcolor or Skada.windowdefaults.barcolor
						return c.r, c.g, c.b, c.a
					end,
					set = function(i, r, g, b, a)
						db.barcolor = db.barcolor or {}
						db.barcolor.r, db.barcolor.g, db.barcolor.b, db.barcolor.a = r, g, b, a
						Skada:ApplySettings(db.names)
					end,
					order = 20
				},
				baraltcolor = {
					type = "color",
					name = L["Background Color"],
					desc = L["The color of the background."],
					hasAlpha = true,
					get = function(i)
						local c = db.baraltcolor or Skada.windowdefaults.baraltcolor
						return c.r, c.g, c.b, c.a
					end,
					set = function(i, r, g, b, a)
						db.baraltcolor = db.baraltcolor or {}
						db.baraltcolor.r = r
						db.baraltcolor.g = g
						db.baraltcolor.b = b
						db.baraltcolor.a = a
						Skada:ApplySettings(db.name)
					end,
					order = 21
				},
				classcolorbars = {
					type = "toggle",
					name = L["Class Color Bars"],
					desc = L["When possible, bars will be colored according to player class."],
					order = 30
				},
				classcolortext = {
					type = "toggle",
					name = L["Class Color Text"],
					desc = L["When possible, bar text will be colored according to player class."],
					order = 31
				},
				spark = {
					type = "toggle",
					name = L["Show Spark Effect"],
					order = 32
				}
			}
		}

		options.titleoptions = {
			type = "group",
			name = L["Title Bar"],
			order = 2,
			get = function(info)
				return db.title[info[#info]]
			end,
			set = function(info, value)
				db.title[info[#info]] = value
				Skada:ApplySettings(db.name)
			end,
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
				font = {
					type = "select",
					name = L["Font"],
					desc = format(L["The font used by %s."], L["Title Bar"]),
					dialogControl = "LSM30_Font",
					values = Skada:MediaList("font"),
					order = 1
				},
				fontsize = {
					type = "range",
					name = L["Font Size"],
					desc = format(L["The font size of %s."], L["Title Bar"]),
					min = 7,
					max = 40,
					step = 1,
					order = 2
				},
				texture = {
					type = "select",
					dialogControl = "LSM30_Statusbar",
					name = L["Background Texture"],
					desc = L["The texture used as the background of the title."],
					values = Skada:MediaList("statusbar"),
					order = 3
				},
				color = {
					type = "color",
					name = L["Background Color"],
					desc = L["The color of the background."],
					hasAlpha = true,
					get = function(i)
						local c = db.title.color or Skada.windowdefaults.title.color
						return c.r, c.g, c.b, c.a
					end,
					set = function(i, r, g, b, a)
						db.title.color = db.title.color or {}
						db.title.color.r, db.title.color.g, db.title.color.b, db.title.color.a = r, g, b, a
						Skada:ApplySettings(db.name)
					end,
					order = 4
				},
				bordertexture = {
					type = "select",
					dialogControl = "LSM30_Border",
					name = L["Border texture"],
					desc = L["The texture used for the borders."],
					values = Skada:MediaList("border"),
					order = 5
				},
				borderthickness = {
					type = "range",
					name = L["Border Thickness"],
					desc = L["The thickness of the borders."],
					min = 0,
					max = 50,
					step = 0.5,
					order = 6
				},
				borderinsets = {
					type = "range",
					name = L["Border Insets"],
					desc = L["The distance between the window and its border."],
					min = 0,
					max = 50,
					step = 0.5,
					width = "double",
					order = 7
				},
				menubutton = {
					type = "toggle",
					name = L["Show Menu Button"],
					desc = L["Shows a button for opening the menu in the window title bar."],
					order = 9
				}
			}
		}

		options.windowoptions = {
			type = "group",
			name = L["Background"],
			order = 2,
			get = function(info)
				return db.background[info[#info]]
			end,
			set = function(info, value)
				db.background[info[#info]] = value
				Skada:ApplySettings(db.name)
			end,
			args = {
				enablebackground = {
					type = "toggle",
					name = L["Enable"],
					width = "double",
					order = 0,
					get = function()
						return db.enablebackground
					end,
					set = function(_, value)
						db.enablebackground = value
						Skada:ApplySettings(db.name)
					end
				},
				texture = {
					type = "select",
					name = L["Background Texture"],
					desc = L["The texture used as the background."],
					dialogControl = "LSM30_Background",
					values = Skada:MediaList("background"),
					order = 1
				},
				color = {
					type = "color",
					name = L["Background Color"],
					desc = L["The color of the background."],
					hasAlpha = true,
					get = function(i)
						local c = db.background.color or Skada.windowdefaults.background.color
						return c.r, c.g, c.b, c.a
					end,
					set = function(i, r, g, b, a)
						db.background.color = db.background.color or {}
						db.background.color.r = r
						db.background.color.g = g
						db.background.color.b = b
						db.background.color.a = a
						Skada:ApplySettings(db.name)
					end,
					order = 2
				},
				bordertexture = {
					type = "select",
					name = L["Border texture"],
					desc = L["The texture used for the borders."],
					dialogControl = "LSM30_Border",
					values = Skada:MediaList("border"),
					order = 3
				},
				borderthickness = {
					type = "range",
					name = L["Border Thickness"],
					desc = L["The thickness of the borders."],
					min = 0,
					max = 50,
					step = 0.5,
					order = 4
				},
				borderinsets = {
					type = "range",
					name = L["Border Insets"],
					desc = L["The distance between the window and its border."],
					min = 0,
					max = 50,
					step = 0.5,
					order = 5
				},
				height = {
					type = "range",
					name = L["Height"],
					desc = format(L["The height of %s."], L["Window"]),
					min = 0,
					max = 600,
					step = 1,
					order = 6
				}
			}
		}
	end
end)
