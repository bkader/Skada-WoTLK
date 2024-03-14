local folder, Skada = ...
local Private = Skada.Private
Skada:RegisterDisplay("Inline Bar Display", "mod_inline_desc", function(L)
	local mod = Skada:NewModule("Inline Bar Display", Skada.displayPrototype)

	local pairs, tostring, type = pairs, tostring, type
	local format, strmatch = string.format, string.match
	local tinsert, tremove, tsort = table.insert, table.remove, table.sort
	local GameTooltip = GameTooltip
	local GetScreenWidth = GetScreenWidth
	local GetScreenHeight = GetScreenHeight
	local SavePosition = Private.SavePosition
	local RestorePosition = Private.RestorePosition

	local mybars = {}
	local barlibrary = {bars = {}, nextuuid = 1}
	local leftmargin = 40
	local ttactive = false

	local WrapTextInColorCode = Private.WrapTextInColorCode
	local RGBPercToHex = Private.RGBPercToHex
	local classcolors = Skada.classcolors
	local ElvUI = _G.ElvUI

	local FONT_FLAGS = Skada.fontFlags
	if not FONT_FLAGS then
		FONT_FLAGS = {
			[""] = L["None"],
			["OUTLINE"] = L["Outline"],
			["THICK"] = L["Thick"],
			["THICKOUTLINE"] = L["Thick outline"],
			["MONOCHROME"] = L["Monochrome"],
			["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
		}
		Skada.fontFlags = FONT_FLAGS
	end

	local buttonTexture = format([[%s\Textures\toolbar%%s\config]], Skada.mediapath)

	local function BarLeave(bar)
		if ttactive then
			GameTooltip:Hide()
			ttactive = false
		end
	end

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

	local function showmode(win, id, label, class, mode)
		if Private.total_noclick(win.selectedset, mode) then return end

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

	local function BarClick(win, bar, button)
		if Skada.testMode or bar.ignore then return end

		local id, label, class = bar.valueid, bar.valuetext, bar.class

		if button == "RightButton" and IsShiftKeyDown() then
			Skada:OpenMenu(win)
		elseif win.metadata.click then
			win.metadata.click(win, id, label, button)
		elseif button == "RightButton" then
			win:RightClick(bar, button)
		elseif button == "LeftButton" and win.metadata.click2 and IsShiftKeyDown() then
			showmode(win, id, label, class, win.metadata.click2)
		elseif button == "LeftButton" and win.metadata.filterclass and IsAltKeyDown() then
			win:FilterClass(class)
		elseif button == "LeftButton" and win.metadata.click3 and IsControlKeyDown() then
			showmode(win, id, label, class, win.metadata.click3)
		elseif button == "LeftButton" and win.metadata.click1 then
			showmode(win, id, label, class, win.metadata.click1)
		end
	end

	local function frameOnMouseDown(self, button)
		if button == "RightButton" and not Skada.testMode then
			self.win:RightClick(nil, button)
		end
	end

	local function frameOnDragStart(self)
		if not self.win.db.barslocked then
			GameTooltip:Hide()
			self.isDragging = true
			self:StartMoving()
		end
	end

	local function frameOnDragStop(self)
		self:StopMovingOrSizing()
		self.isDragging = false
		SavePosition(self, self.win.db)
	end

	local function titleOnMouseDown(self, button)
		if button == "RightButton" then
			Skada:SegmentMenu(self.win)
		elseif button == "LeftButton" then
			Skada:ModeMenu(self.win, self)
		end
	end

	local function menuOnClick(self, button)
		if button == "RightButton" then
			Private.OpenOptions(self.win)
		else
			Skada:OpenMenu(self.win)
		end
	end

	function mod:Create(window, isnew)
		local p = window.db
		local frame = window.frame

		if not frame then
			frame = CreateFrame("Frame", format("%sInlineWindow%s", folder, p.name), UIParent)
			frame:SetFrameLevel(1)

			if p.height == 15 then
				p.height = 23
			end

			frame:SetHeight(p.height)
			frame:SetWidth(p.width or GetScreenWidth())
			frame:ClearAllPoints()
			frame:SetPoint("BOTTOM", -1)
			frame:SetPoint("LEFT", -1)
			if p.background.color.a == 0.2 then
				p.background.color = {r = 1, b = 0.98, g = 0.98, a = 1}
			end
		end

		if isnew then
			SavePosition(frame, p)
		else
			RestorePosition(frame, p)
		end

		frame:SetClampedToScreen(true)
		frame:EnableMouse(true)
		frame:SetMovable(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnMouseDown", frameOnMouseDown)
		frame:SetScript("OnDragStart", frameOnDragStart)
		frame:SetScript("OnDragStop", frameOnDragStop)

		local titlebg = CreateFrame("Frame", "$parentTitleBackground", frame)
		titlebg.win = window

		local title = frame:CreateFontString("frameTitle", 6)
		title:SetTextColor(self:GetFontColor(p))
		title:SetFont(self:GetFont(p))
		title:SetText(window.metadata.title or folder)
		title:SetWordWrap(false)
		title:SetJustifyH("LEFT")
		title:SetPoint("LEFT", leftmargin, -1)
		title:SetPoint("CENTER", 0, 0)
		title:SetHeight(p.height or 23)
		frame.fstitle = title
		frame.titlebg = titlebg

		titlebg:SetAllPoints(title)
		titlebg:EnableMouse(true)
		titlebg:SetScript("OnMouseDown", titleOnMouseDown)

		local menu = CreateFrame("Button", "$parentMenuButton", frame)
		menu:ClearAllPoints()
		menu:SetWidth(12)
		menu:SetHeight(12)
		menu:SetNormalTexture(format(buttonTexture, p.title.toolbar or 1))
		menu:SetHighlightTexture(format(buttonTexture, p.title.toolbar or 1), "ADD")
		menu:SetAlpha(0.5)
		menu:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		menu:SetPoint("LEFT", frame, "LEFT", 6, 0)
		menu:SetFrameLevel(frame:GetFrameLevel() + 5)
		menu.win = window
		menu:SetScript("OnClick", menuOnClick)

		frame.menu = menu
		frame.skadamenubutton = title
		frame.barstartx = leftmargin + frame.fstitle:GetStringWidth()

		frame.win = window
		window.frame = frame

		--create 20 barframes
		local temp = 20
		repeat
			local bar = barlibrary:CreateBar(nil, window)
			barlibrary.bars[temp] = bar
			temp = temp - 1
		until (temp < 1)
		self:Update(window)
	end

	function mod:SetTitle(win, title)
		local frame = win and win.frame
		if not win then return end
		frame.fstitle:SetText(title or win.title or win.metadata.title)
		frame.barstartx = leftmargin + frame.fstitle:GetStringWidth() + 20
	end

	local function barOnMouseDown(self, button)
		local bar = self.bar
		local win = bar and bar.win
		if not win then return end
		BarClick(win, bar, button)
	end

	local function barOnEnter(self, motion)
		local bar = self.bar
		local win = bar and bar.win
		if not win then return end
		ttactive = true
		Skada:SetTooltipPosition(GameTooltip, win.frame, "inline", win)
		Skada:ShowTooltip(win, bar.valueid, bar.valuetext, bar, bar.class)
	end

	function barlibrary:CreateBar(uuid, win)
		local bar = {}
		bar.uuid = uuid or self.nextuuid
		bar.inuse = false
		bar.value = 0
		bar.win = win

		bar.bg = CreateFrame("Frame", format("$parentBackground%d", bar.uuid), win.frame)
		bar.bg:SetFrameLevel(win.frame:GetFrameLevel() + 6)
		bar.bg.bar = bar

		bar.label = win.frame:CreateFontString(format("$parentLabel%d", bar.uuid))
		bar.label:SetFont(mod:GetFont(win.db))
		bar.label:SetTextColor(mod:GetFontColor(win.db))
		bar.label:SetJustifyH("LEFT")
		bar.label:SetJustifyV("MIDDLE")
		bar.bg:EnableMouse(true)
		bar.bg:SetScript("OnMouseDown", barOnMouseDown)
		bar.bg:SetScript("OnEnter", barOnEnter)
		bar.bg:SetScript("OnLeave", BarLeave)

		if uuid then
			self.nextuuid = self.nextuuid + 1
		end
		return bar
	end

	function barlibrary:Deposit(bar)
		--strip the bar of variables
		bar.inuse = false
		bar.bg:Hide()
		bar.value = 0
		bar.label:Hide()

		--place it at the front of the queue
		tinsert(barlibrary.bars, 1, bar)
	end

	local Print = Private.Print
	function barlibrary:Withdraw(win)
		local db = win.db

		if #barlibrary.bars < 2 then
			local replacement = {}
			local uuid = 1
			if #barlibrary.bars == 0 then
				uuid = 1
			elseif #barlibrary.bars < 2 then
				uuid = barlibrary.bars[#barlibrary.bars].uuid + 1
			else
				uuid = 1
				Print("\124c0033ff99SkadaInline\124r: THIS SHOULD NEVER HAPPEN")
			end
			replacement = self:CreateBar(uuid, win)
			barlibrary.bars[#barlibrary.bars + 1] = replacement
		end

		barlibrary.bars[1].inuse = false
		barlibrary.bars[1].value = 0
		barlibrary.bars[1].label:SetJustifyH("LEFT")
		mod:ApplySettings(win)
		return tremove(barlibrary.bars, 1)
	end

	function mod:RecycleBar(bar)
		bar.value = 0
		bar.label:Hide()
		bar.bg:Hide()
		barlibrary:Deposit(bar)
	end

	function mod:GetBar(win)
		return barlibrary:Withdraw(win)
	end

	function mod:UpdateBar(bar, bardata, db)
		local label = bardata.text or bardata.label or L["Unknown"]
		if db.isusingclasscolors and bardata.class then
			label = classcolors.format(bardata.class, bardata.text or bardata.label or L["Unknown"])
		elseif bardata.color and bardata.color.colorStr then
			label = format("\124c%s%s\124r", bardata.color.colorStr, bardata.text or bardata.label or L["Unknown"])
		elseif bardata.color then
			label = WrapTextInColorCode(bardata.text or bardata.label or L["Unknown"], RGBPercToHex(bardata.color.r or 1, bardata.color.g or 1, bardata.color.b or 1, true))
		else
			label = bardata.text or bardata.label or L["Unknown"]
		end

		if bardata.valuetext then
			label = format("%s%s%s", label, (db.isonnewline and db.barfontsize * 2 < db.height) and "\n" or " - ", bardata.valuetext)
		end

		bar.label:SetFont(mod:GetFont(db))
		bar.label:SetText(label)
		bar.label:SetTextColor(mod:GetFontColor(db))
		bar.class = bardata.class
		bar.value = bardata.value
		if bardata.ignore then
			bar.ignore = true
		else
			bar.class = bardata.class
			bar.spec = bardata.spec
			bar.role = bardata.role
		end

		bar.valueid = bardata.id
		bar.valuetext = bardata.text or bardata.label or L["Unknown"]
		return bar
	end

	local function sortFunc(a, b)
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
			return a.label:GetText() > b.label:GetText()
		end
	end

	function mod:Update(win)
		if not win or not win.frame then return end

		local wd = win.dataset
		for i = #wd, 1, -1 do
			if wd[i] and wd[i].label == nil then
				tremove(wd, i)
			end
		end

		local i = #mybars
		while i > 0 do
			mod:RecycleBar(tremove(mybars, i))
			i = i - 1
		end

		for k, bardata in pairs(wd) do
			if bardata.id then
				mybars[#mybars + 1] = mod:UpdateBar(mod:GetBar(win), bardata, win.db)
			end
		end

		tsort(mybars, sortFunc)

		local yoffset = (win.db.height - win.db.barfontsize) * 0.5
		local left = win.frame.barstartx + 40

		for key, bar in pairs(mybars) do
			bar.bg:SetHeight(win.db.height)
			bar.bg:SetPoint("BOTTOMLEFT", win.frame, "BOTTOMLEFT", left, 0)
			bar.bg:SetWidth(bar.label:GetStringWidth())
			bar.label:SetHeight(win.db.height)
			bar.label:SetPoint("BOTTOMLEFT", win.frame, "BOTTOMLEFT", left, 0)

			if win.db.fixedbarwidth then
				left = left + win.db.barwidth
			else
				left = left + bar.label:GetStringWidth()
				left = left + 15
			end

			if (left + win.frame:GetLeft()) < win.frame:GetRight() then
				bar.bg:Show()
				bar.label:Show()
			else
				bar.bg:Hide()
				bar.label:Hide()
			end
		end
	end

	function mod:OnMouseWheel(win, frame, direction)
	end

	function mod:CreateBar(win, name, label, maxValue, icon, o)
		local bar = {}
		bar.win = win

		return bar
	end

	function mod:GetFont(db)
		if db.isusingelvuiskin and ElvUI then
			if ElvUI then
				return ElvUI[1]["media"].normFont, db.barfontsize, nil
			else
				return nil
			end
		else
			return Skada:MediaFetch("font", db.barfont), db.barfontsize, db.barfontflags
		end
	end

	function mod:GetFontColor(db)
		if db.isusingelvuiskin and ElvUI then
			return 255, 255, 255, 1
		else
			return db.title.textcolor.r, db.title.textcolor.g, db.title.textcolor.b, db.title.textcolor.a
		end
	end

	function mod:ApplySettings(win)
		if not win or not win.frame then return end

		local f = win.frame
		local p = win.db

		f:SetHeight(p.height)
		f:SetWidth(p.width or GetScreenWidth())
		f.fstitle:SetTextColor(self:GetFontColor(p))
		f.fstitle:SetFont(self:GetFont(p))

		for k, bar in pairs(mybars) do
			bar.label:SetFont(self:GetFont(p))
			bar.label:SetTextColor(self:GetFontColor(p))
			bar.bg:EnableMouse(not p.clickthrough)
		end
		f.menu:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, p.height * 0.5 - 8)

		f:SetClampedToScreen(p.clamped == true)
		f:EnableMouse(not p.clickthrough)
		f:SetScale(p.scale)

		-- restore position
		RestorePosition(f, p)

		--ElvUI
		if p.isusingelvuiskin and ElvUI then
			f:SetHeight(p.height)
			f.fstitle:SetTextColor(255, 255, 255, 1)
			f.fstitle:SetFont(ElvUI[1]["media"].normFont, p.barfontsize, nil)
			for k, bar in pairs(mybars) do
				bar.label:SetFont(ElvUI[1]["media"].normFont, p.barfontsize, nil)
				bar.label:SetTextColor(255, 255, 255, 1)
			end

			--background
			local fbackdrop = {}
			local borderR, borderG, borderB = ElvUI[1]["media"].bordercolor[1], ElvUI[1]["media"].bordercolor[2], ElvUI[1]["media"].bordercolor[3]
			local backdropR, backdropG, backdropB = ElvUI[1]["media"].backdropcolor[1], ElvUI[1]["media"].backdropcolor[2], ElvUI[1]["media"].backdropcolor[3]
			local backdropA = 0
			if p.issolidbackdrop then
				backdropA = 1.0
			else
				backdropA = 0.8
			end
			local resolution = ({GetScreenResolutions()})[GetCurrentResolution()]
			local mult = 768 / strmatch(resolution, "%d+x(%d+)") / (max(0.64, min(1.15, 768 / GetScreenHeight() or UIParent:GetScale())))

			fbackdrop.bgFile = ElvUI[1]["media"].blankTex
			fbackdrop.edgeFile = ElvUI[1]["media"].blankTex
			fbackdrop.tile = false
			fbackdrop.tileSize = 0
			fbackdrop.edgeSize = mult
			fbackdrop.insets = {left = 0, right = 0, top = 0, bottom = 0}
			f:SetBackdrop(fbackdrop)
			f:SetBackdropColor(backdropR, backdropG, backdropB, backdropA)
			f:SetBackdropBorderColor(borderR, borderG, borderB, 1.0)
		else
			--background
			local fbackdrop = {}
			fbackdrop.bgFile = Skada:MediaFetch("background", p.background.texture)
			fbackdrop.tile = p.background.tile
			fbackdrop.tileSize = p.background.tilesize
			f:SetBackdrop(fbackdrop)
			f:SetBackdropColor(p.background.color.r, p.background.color.g, p.background.color.b, p.background.color.a)
			f:SetFrameStrata(p.strata)
			Skada:ApplyBorder(f, p.background.bordertexture, p.background.bordercolor, p.background.borderthickness, p.background.borderinsets)
		end

		if p.hidden and win.frame:IsShown() then
			win.frame:Hide()
		elseif not p.hidden and not win.frame:IsShown() then
			win.frame:Show()
		end
	end

	function mod:AddDisplayOptions(win, options)
		local db = win.db

		options.baroptions = {
			type = "group",
			name = L["Text"],
			desc = format(L["Options for %s."], L["Text"]),
			order = 1,
			get = function(i)
				return db[i[#i]]
			end,
			set = function(i, val)
				db[i[#i]] = val
				Skada:ApplySettings(db.name)
			end,
			args = {
				barfont = {
					type = "select",
					dialogControl = "LSM30_Font",
					name = L["Font"],
					desc = format(L["The font used by %s."], L["Bars"]),
					values = Skada:MediaList("font"),
					order = 10
				},
				barfontflags = {
					type = "select",
					name = L["Font Outline"],
					desc = L["Sets the font outline."],
					values = FONT_FLAGS,
					order = 20
				},
				barfontsize = {
					type = "range",
					name = L["Font Size"],
					desc = format(L["The font size of %s."], L["Bars"]),
					min = 5,
					max = 32,
					step = 1,
					order = 30,
					width = "double"
				},
				color = {
					type = "color",
					name = L["Font Color"],
					desc = L["Font Color.\nClick \"Class Colors\" to begin."],
					hasAlpha = true,
					get = function()
						local c = db.title.textcolor or Skada.windowdefaults.title.textcolor
						return c.r, c.g, c.b, c.a or 1
					end,
					set = function(win, r, g, b, a)
						db.title.textcolor = db.title.textcolor or {}
						db.title.textcolor.r, db.title.textcolor.g, db.title.textcolor.b, db.title.textcolor.a = r, g, b, a
						Skada:ApplySettings(db.name)
					end,
					order = 40,
					width = "double"
				},
				barwidth = {
					type = "range",
					name = L["Width"],
					desc = L["opt_barwidth_desc"],
					min = 100,
					max = 300,
					step = 1.0,
					order = 50,
					width = "double"
				},
				separator = {
					type = "description",
					name = "\n",
					order = 60,
					width = "full"
				},
				fixedbarwidth = {
					type = "toggle",
					name = L["Fixed bar width"],
					desc = L["opt_fixedbarwidth_desc"],
					order = 70
				},
				isusingclasscolors = {
					type = "toggle",
					name = L["Class Colors"],
					desc = format(L["opt_isusingclasscolors_desc"], classcolors.format(Skada.userClass, Skada.userName), Skada.userName),
					order = 80,
				},
				isonnewline = {
					type = "toggle",
					name = L["Put values on new line."],
					desc = format(L["opt_isonnewline_desc"], Skada.userName),
					order = 90
				},
				clickthrough = {
					type = "toggle",
					name = L["Click Through"],
					desc = L["Disables mouse clicks on bars."],
					order = 100
				}
			}
		}

		options.elvuioptions = {
			type = "group",
			name = "ElvUI",
			desc = format(L["Options for %s."], "ElvUI"),
			order = 2,
			get = function(i)
				return db[i[#i]]
			end,
			set = function(i, val)
				db[i[#i]] = val
				Skada:ApplySettings(db.name)
			end,
			args = {
				isusingelvuiskin = {
					type = "toggle",
					name = L["Use ElvUI skin if avaliable."],
					desc = L["opt_isusingelvuiskin_desc"],
					descStyle = "inline",
					order = 10,
					width = "full"
				},
				issolidbackdrop = {
					type = "toggle",
					name = L["Use solid background."],
					desc = L["Un-check this for an opaque background."],
					descStyle = "inline",
					order = 20,
					width = "full"
				}
			}
		}

		options.windowoptions = Private.FrameOptions(db, true)
	end

	function mod:OnInitialize()
		classcolors = classcolors or Skada.classcolors
		self.name = L["Inline Bar Display"]
		self.description = L["mod_inline_desc"]
		Skada:AddDisplaySystem("inline", self, true)
	end
end)
