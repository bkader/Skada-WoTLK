assert(Skada, "Skada not found!")

local mod = Skada:NewModule("InlineDisplay")
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)

mod.name = L["Inline bar display"]
mod.description = L["Inline display is a horizontal window style."]
Skada:AddDisplaySystem("inline", mod)

local mybars = {}
local barlibrary = {bars = {}, nextuuid = 1}
local leftmargin = 40
local ttactive = false

local libwindow = LibStub("LibWindow-1.1")
local media = LibStub("LibSharedMedia-3.0")

local pairs, tostring, type = pairs, tostring, type
local strrep, format, _match = string.rep, string.format, string.match
local tinsert, tremove, tsort = table.insert, table.remove, table.sort

local classcolors = {
	DEATHKNIGHT = "|cffc41f3b%s|r",
	DRUID = "|cffff7d0a%s|r",
	HUNTER = "|cffa9d271%s|r",
	MAGE = "|cff40c7eb%s|r",
	PALADIN = "|cfff58cba%s|r",
	PRIEST = "|cffffffff%s|r",
	ROGUE = "|cfffff569%s|r",
	SHAMAN = "|cff0070de%s|r",
	WARLOCK = "|cff8787ed%s|r",
	WARRIOR = "|cffc79c6e%s|r"
}

local function serial(val, name, skipnewlines, depth)
	skipnewlines = skipnewlines or false
	depth = depth or 0

	local tmp = strrep("·", depth)
	if name then
		tmp = tmp .. name .. "="
	end

	if type(val) == "table" then
		tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
		for k, v in pairs(val) do
			tmp = tmp .. serial(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
		end
		tmp = tmp .. strrep(" ", depth) .. "}"
	elseif type(val) == "number" then
		tmp = tmp .. tostring(val)
	elseif type(val) == "string" then
		tmp = tmp .. format("%q", val)
	elseif type(val) == "boolean" then
		tmp = tmp .. (val and "true" or "false")
	else
		tmp = tmp .. '"[inserializeable datatype:' .. type(val) .. ']"'
	end
	return tmp
end

function mod:OnInitialize()
end

local function BarLeave(bar)
	if ttactive then
		GameTooltip:Hide()
		ttactive = false
	end
end

local function showmode(win, id, label, mode)
	if win.selectedmode then
		tinsert(win.history, win.selectedmode)
		if win.child then
			tinsert(win.child.history, win.selectedmode)
		end
	end
	if mode.Enter then
		mode:Enter(win, id, label)
		if win.child then
			mode:Enter(win.child, id, label)
		end
	end
	win:DisplayMode(mode)
	L_CloseDropDownMenus() -- always close
end

local function ignoredClick(win, click)
	if win and win.selectedset == "total" and win.metadata and win.metadata.nototalclick and click then
		return tContains(win.metadata.nototalclick, click)
	end
end

local function BarClick(win, bar, button)
	local id, label = bar.valueid, bar.valuetext

	if button == "RightButton" and IsShiftKeyDown() then
		Skada:OpenMenu(win)
	elseif win.metadata.click and not ignoredClick(win, win.metadata.click) then
		win.metadata.click(win, id, label, button)
	elseif button == "RightButton" then
		win:RightClick()
	elseif win.metadata.click2 and IsShiftKeyDown() and not ignoredClick(win, win.metadata.click2) then
		showmode(win, id, label, win.metadata.click2)
	elseif win.metadata.click3 and IsControlKeyDown() and not ignoredClick(win, win.metadata.click3) then
		showmode(win, id, label, win.metadata.click3)
	elseif win.metadata.click1 and not ignoredClick(win, win.metadata.click1) then
		showmode(win, id, label, win.metadata.click1)
	end
end

function mod:Create(window, isnew)
	if not window.frame then
		window.frame = CreateFrame("Frame", window.db.name .. "InlineFrame", UIParent)
		window.frame.win = window
		window.frame:SetFrameLevel(5)
		window.frame:SetClampedToScreen(true)

		if window.db.height == 15 then
			window.db.height = 23
		end
		window.frame:SetHeight(window.db.height)
		window.frame:SetWidth(window.db.width or GetScreenWidth())
		window.frame:ClearAllPoints()
		window.frame:SetPoint("BOTTOM", -1)
		window.frame:SetPoint("LEFT", -1)
		if window.db.background.color.a == 51 / 255 then
			window.db.background.color = {r = 255, b = 250 / 255, g = 250 / 255, a = 1}
		end
	end

	window.frame:EnableMouse()
	window.frame:SetScript("OnMouseDown", function(frame, button)
		if button == "RightButton" then
			window:RightClick()
		end
	end)

	libwindow.RegisterConfig(window.frame, window.db)

	if isnew then
		libwindow.SavePosition(window.frame)
	else
		libwindow.RestorePosition(window.frame)
	end

	window.frame:EnableMouse(true)
	window.frame:SetMovable(true)
	window.frame:RegisterForDrag("LeftButton")
	window.frame:SetScript("OnDragStart", function(frame)
		if not window.db.barslocked then
			GameTooltip:Hide()
			frame.isDragging = true
			frame:StartMoving()
		end
	end)
	window.frame:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		frame.isDragging = false
		libwindow.SavePosition(frame)
	end)

	local titlebg = CreateFrame("Frame", "InlineTitleBackground", window.frame)
	local title = window.frame:CreateFontString("frameTitle", 6)
	title:SetTextColor(self:GetFontColor(window.db))
	title:SetFont(self:GetFont(window.db))
	title:SetText(window.metadata.title or "Skada")
	title:SetWordWrap(false)
	title:SetJustifyH("LEFT")
	title:SetPoint("LEFT", leftmargin, -1)
	title:SetPoint("CENTER", 0, 0)
	title:SetHeight(window.db.height or 23)
	window.frame.fstitle = title
	window.frame.titlebg = titlebg

	titlebg:SetAllPoints(title)
	titlebg:EnableMouse(true)
	titlebg:SetScript("OnMouseDown", function(frame, button)
		if button == "RightButton" then
			Skada:SegmentMenu(window)
		elseif button == "LeftButton" then
			Skada:ModeMenu(window)
		end
	end)

	local skadamenubuttonbackdrop = {
		bgFile = "Interface\\Buttons\\UI-OptionsButton",
		edgeFile = "Interface\\Buttons\\UI-OptionsButton",
		tile = true,
		tileSize = 12,
		edgeSize = 0,
		insets = {left = 0, right = 0, top = 0, bottom = 0}
	}

	local menu = CreateFrame("Button", "InlineFrameMenuButton", window.frame)
	menu:ClearAllPoints()
	menu:SetWidth(12)
	menu:SetHeight(12)
	menu:SetNormalTexture("Interface\\Addons\\Skada\\Media\\Textures\\icon-config")
	menu:SetHighlightTexture("Interface\\Addons\\Skada\\Media\\Textures\\icon-config", 1.0)
	menu:SetAlpha(1)
	menu:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	menu:SetBackdropColor(
		window.db.title.textcolor.r,
		window.db.title.textcolor.g,
		window.db.title.textcolor.b,
		window.db.title.textcolor.a
	)
	menu:SetPoint("BOTTOMLEFT", window.frame, "BOTTOMLEFT", 6, window.db.height / 2 - 8)
	menu:SetFrameLevel(9)
	menu:SetPoint("CENTER")
	menu:SetBackdrop(skadamenubuttonbackdrop)
	menu:SetScript("OnClick", function() Skada:OpenMenu(window) end)

	window.frame.menu = menu
	window.frame.skadamenubutton = title
	window.frame.barstartx = leftmargin + window.frame.fstitle:GetStringWidth()

	window.frame.win = window
	window.frame:EnableMouse(true)

	--create 20 barframes
	local temp = 25
	repeat
		local bar = barlibrary:CreateBar(nil, window)
		barlibrary.bars[temp] = bar
		temp = temp - 1
	until (temp < 1)
	self:Update(window)
end

function mod:Destroy(win)
	if win and win.frame then
		win.frame:Hide()
		win.frame = nil
	end
end

function mod:Wipe(win)
end

function mod:SetTitle(win, title)
	if win and win.frame then
		win.frame.fstitle:SetText(title)
		win.frame.barstartx = leftmargin + win.frame.fstitle:GetStringWidth() + 20
	end
end

function barlibrary:CreateBar(uuid, win)
	local bar = {}
	bar.uuid = uuid or self.nextuuid
	bar.inuse = false
	bar.value = 0
	bar.win = win

	bar.bg = CreateFrame("Frame", "bg" .. bar.uuid, win.frame)
	bar.label = bar.bg:CreateFontString("label" .. bar.uuid)
	bar.label:SetFont(mod:GetFont(win.db))
	bar.label:SetTextColor(mod:GetFontColor(win.db))
	bar.label:SetJustifyH("LEFT")
	bar.label:SetJustifyV("MIDDLE")
	bar.bg:EnableMouse(true)
	bar.bg:SetScript("OnMouseDown", function(frame, button) BarClick(win, bar, button) end)
	bar.bg:SetScript("OnEnter", function(frame, button)
		ttactive = true
		Skada:SetTooltipPosition(GameTooltip, win.frame, win.db.display, win)
		Skada:ShowTooltip(win, bar.valueid, bar.valuetext)
	end)
	bar.bg:SetScript("OnLeave", BarLeave)

	if uuid then
		self.nextuuid = self.nextuuid + 1
	end
	return bar
end

function barlibrary:Deposit(_bar)
	--strip the bar of variables
	_bar.inuse = false
	_bar.bg:Hide()
	_bar.value = 0
	_bar.label:Hide()

	--place it at the front of the queue
	tinsert(barlibrary.bars, 1, _bar)
end

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
			print("|c0033ff99SkadaInline|r: THIS SHOULD NEVER HAPPEN")
		end
		replacement = self:CreateBar(uuid, win)
		tinsert(barlibrary.bars, replacement)
	end

	barlibrary.bars[1].inuse = false
	barlibrary.bars[1].value = 0
	barlibrary.bars[1].label:SetJustifyH("LEFT")
	mod:ApplySettings(win)
	return tremove(barlibrary.bars, 1)
end

function mod:RecycleBar(_bar)
	_bar.value = 0
	_bar.label:Hide()
	_bar.bg:Hide()
	barlibrary:Deposit(_bar)
end

function mod:GetBar(win)
	return barlibrary:Withdraw(win)
end

function mod:UpdateBar(bar, bardata, db)
	local label = bardata.text or bardata.label or UNKNOWN
	if db.isusingclasscolors then
		if bardata.class then
			label = format(classcolors[bardata.class] or "|cffffffff%s|r", bardata.text or bardata.label or UNKNOWN)
		end
	else
		label = bardata.text or bardata.label or UNKNOWN
	end

	if bardata.valuetext then
		if db.isonnewline and db.barfontsize * 2 < db.height then
			label = label .. "\n"
		else
			label = label .. " - "
		end
		label = label .. bardata.valuetext
	end

	bar.label:SetFont(mod:GetFont(db))
	bar.label:SetText(label)
	bar.label:SetTextColor(mod:GetFontColor(db))
	bar.value = bardata.value
	if bardata.ignore then
		bar.ignore = true
	else
		bar.class = bardata.class
		bar.spec = bardata.spec
		bar.role = bardata.role
	end

	bar.valueid = bardata.id
	bar.valuetext = bardata.text or bardata.label or UNKNOWN
	return bar
end

function mod:Update(win)
	if not win or not win.frame then
		return
	end

	local wd = win.dataset
	for i = #wd, 1, -1 do
		if wd[i].label == nil then
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
			tinsert(mybars, mod:UpdateBar(mod:GetBar(win), bardata, win.db))
		end
	end

	tsort(mybars, function(bar1, bar2)
		if not bar1 or bar1.value == nil then
			return false
		elseif not bar2 or bar2.value == nil then
			return true
		else
			return bar1.value > bar2.value
		end
	end)

	local yoffset = (win.db.height - win.db.barfontsize) / 2
	local left = win.frame.barstartx + 40

	for key, bar in pairs(mybars) do
		bar.bg:SetFrameLevel(9)
		bar.bg:SetHeight(win.db.height)
		bar.bg:SetPoint("BOTTOMLEFT", win.frame, "BOTTOMLEFT", left, 0)
		bar.label:SetHeight(win.db.height)
		bar.label:SetPoint("BOTTOMLEFT", win.frame, "BOTTOMLEFT", left, 0)
		bar.bg:SetWidth(bar.label:GetStringWidth())

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

function mod:Show(win)
	if win and win.frame then
		win.frame:Show()
	end
end

function mod:Hide(win)
	win.frame:Hide()
end

function mod:IsShown(win)
	return win.frame:IsShown()
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
		return media:Fetch("font", db.barfont), db.barfontsize, db.barfontflags
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
	if not win or not win.frame then
		return
	end

	local f = win.frame
	local p = win.db

	f:SetHeight(p.height)
	f:SetWidth(win.db.width or GetScreenWidth())
	f.fstitle:SetTextColor(self:GetFontColor(p))
	f.fstitle:SetFont(self:GetFont(p))

	for k, bar in pairs(mybars) do
		bar.label:SetFont(self:GetFont(p))
		bar.label:SetTextColor(self:GetFontColor(p))
		bar.bg:EnableMouse(not p.clickthrough)
	end
	f.menu:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, win.db.height / 2 - 8)

	f:EnableMouse(not p.clickthrough)
	f:SetScale(p.scale)

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
		local borderR, borderG, borderB = unpack(ElvUI[1]["media"].bordercolor)
		local backdropR, backdropG, backdropB = unpack(ElvUI[1]["media"].backdropcolor)
		local backdropA = 0
		if p.issolidbackdrop then
			backdropA = 1.0
		else
			backdropA = 0.8
		end
		local resolution = ({GetScreenResolutions()})[GetCurrentResolution()]
		local mult = 768 / _match(resolution, "%d+x(%d+)") / (max(0.64, min(1.15, 768 / GetScreenHeight() or UIParent:GetScale())))

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
		fbackdrop.bgFile = media:Fetch("background", p.background.texture)
		fbackdrop.tile = p.background.tile
		fbackdrop.tileSize = p.background.tilesize
		f:SetBackdrop(fbackdrop)
		f:SetBackdropColor(p.background.color.r, p.background.color.g, p.background.color.b, p.background.color.a)
		f:SetFrameStrata(p.strata)
		Skada:ApplyBorder(f, p.background.bordertexture, p.background.bordercolor, p.background.borderthickness)
	end
end

function mod:AddDisplayOptions(win, options)
	local db = win.db

	options.baroptions = {
		type = "group",
		name = L["Text"],
		desc = format(L["Options for %s."], L["Text"]),
		order = 3,
		args = {
			barfont = {
				type = "select",
				dialogControl = "LSM30_Font",
				name = L["Bar font"],
				desc = L["The font used by all bars."],
				values = AceGUIWidgetLSMlists.font,
				get = function() return db.barfont end,
				set = function(win, key)
					db.barfont = key
					Skada:ApplySettings(db.name)
				end,
				order = 10,
				width = "double"
			},
			barfontflags = {
				type = "select",
				name = L["Font Outline"],
				desc = L["Sets the font outline."],
				values = {
					[""] = NONE,
					["OUTLINE"] = L["Outline"],
					["THICKOUTLINE"] = L["Thick outline"],
					["MONOCHROME"] = L["Monochrome"],
					["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
				},
				get = function() return db.barfontflags end,
				set = function(win, key)
					db.barfontflags = key
					Skada:ApplySettings(db.name)
				end,
				order = 20,
				width = "double"
			},
			barfontsize = {
				type = "range",
				name = L["Bar font size"],
				desc = L["The font size of all bars."],
				min = 7,
				max = 40,
				step = 1,
				get = function() return db.barfontsize end,
				set = function(win, size)
					db.barfontsize = size
					Skada:ApplySettings(db.name)
				end,
				order = 30,
				width = "double"
			},
			color = {
				type = "color",
				name = L["Font Color"],
				desc = L['Font Color. \nClick "Use class colors" to begin.'],
				hasAlpha = true,
				get = function()
					local c = db.title.textcolor
					return c.r, c.g, c.b, c.a
				end,
				set = function(win, r, g, b, a)
					db.title.textcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a or 1.0}
					Skada:ApplySettings(db.name)
				end,
				order = 40,
				width = "double"
			},
			barwidth = {
				type = "range",
				name = L["Width"],
				desc = L['Width of bars. This only applies if the "Fixed bar width" option is used.'],
				min = 100,
				max = 300,
				step = 1.0,
				get = function() return db.barwidth end,
				set = function(win, key)
					db.barwidth = key
					Skada:ApplySettings(db.name)
				end,
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
				desc = L["If checked, bar width is fixed. Otherwise, bar width depends on the text width."],
				get = function() return db.fixedbarwidth end,
				set = function()
					db.fixedbarwidth = not db.fixedbarwidth
					Skada:ApplySettings(db.name)
				end,
				order = 70,
			},
			isusingclasscolors = {
				type = "toggle",
				name = L["Use class colors"],
				desc = L["Class colors:\n|cFFF58CBAKader|r - 5.71M (21.7K)\n\nWithout:\nKader - 5.71M (21.7K)"],
				get = function() return db.isusingclasscolors end,
				set = function(win, key)
					db.isusingclasscolors = key
					Skada:ApplySettings(db.name)
				end,
				order = 80,
			},
			isonnewline = {
				type = "toggle",
				name = L["Put values on new line."],
				desc = L["New line:\nKader\n5.71M (21.7K)\n\nDivider:\nKader - 5.71M (21.7K)"],
				get = function() return db.isonnewline end,
				set = function(win, key)
					db.isonnewline = key
					Skada:ApplySettings(db.name)
				end,
				order = 90
			},
			clickthrough = {
				type = "toggle",
				name = L["Clickthrough"],
				desc = L["Disables mouse clicks on bars."],
				get = function() return db.clickthrough end,
				set = function()
					db.clickthrough = not db.clickthrough
					Skada:ApplySettings(db.name)
				end,
				order = 100
			}
		}
	}

	options.elvuioptions = {
		type = "group",
		name = "ElvUI",
		desc = format(L["Options for %s."], "ElvUI"),
		order = 4,
		args = {
			isusingelvuiskin = {
				type = "toggle",
				name = L["Use ElvUI skin if avaliable."],
				desc = L["Check this to use ElvUI skin instead. \nDefault: checked"],
				descStyle = "inline",
				get = function() return db.isusingelvuiskin end,
				set = function(win, key)
					db.isusingelvuiskin = key
					Skada:ApplySettings(db.name)
				end,
				order = 10,
				width = "full"
			},
			issolidbackdrop = {
				type = "toggle",
				name = L["Use solid background."],
				desc = L["Un-check this for an opaque background."],
				descStyle = "inline",
				get = function()
					return db.issolidbackdrop
				end,
				set = function(win, key)
					db.issolidbackdrop = key
					Skada:ApplySettings(db.name)
				end,
				order = 20,
				width = "full"
			}
		}
	}

	options.frameoptions = Skada:FrameSettings(db, true)
end