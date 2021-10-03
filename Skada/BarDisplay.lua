assert(Skada, "Skada not found!")

local mod = Skada:NewModule("BarDisplay", "SpecializedLibBars-1.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local libwindow = LibStub("LibWindow-1.1")
local FlyPaper = LibStub:GetLibrary("LibFlyPaper-1.1", true)
local LSM = LibStub("LibSharedMedia-3.0")

local tinsert, tsort = table.insert, table.sort
local GetSpellLink = Skada.GetSpellLink or GetSpellLink
local CloseDropDownMenus = L_CloseDropDownMenus or CloseDropDownMenus

mod.name = L["Bar display"]
mod.description = L["Bar display is the normal bar window used by most damage meters. It can be extensively styled."]
Skada:AddDisplaySystem("bar", mod)

-- class, role & specs
local classiconfile, classicontcoords
local roleiconfile, roleicontcoords
local specicons = {
	-- Death Knight
	[250] = "Interface\\Icons\\spell_deathknight_bloodpresence", --> Blood
	[251] = "Interface\\Icons\\spell_deathknight_frostpresence", --> Frost
	[252] = "Interface\\Icons\\spell_deathknight_unholypresence", --> Unholy
	-- Druid
	[102] = "Interface\\Icons\\spell_nature_starfall", --> Balance
	[103] = "Interface\\Icons\\ability_druid_catform", --> Feral
	[104] = "Interface\\Icons\\ability_racial_bearform", --> Tank
	[105] = "Interface\\Icons\\spell_nature_healingtouch", --> Restoration
	-- Hunter
	[253] = "Interface\\Icons\\ability_hunter_beasttaming", --> Beastmastery
	[254] = "Interface\\Icons\\ability_hunter_focusedaim", --> Marksmalship
	[255] = "Interface\\Icons\\ability_hunter_swiftstrike", --> Survival
	-- Mage
	[62] = "Interface\\Icons\\spell_holy_magicalsentry", --> Arcane (or: spell_arcane_blast)
	[63] = "Interface\\Icons\\spell_fire_flamebolt", --> Fire
	[64] = "Interface\\Icons\\spell_frost_frostbolt02", --> Frost
	-- Paldin
	[65] = "Interface\\Icons\\spell_holy_holybolt", --> Holy
	[66] = "Interface\\Icons\\ability_paladin_shieldofthetemplar", --> Protection (or: spell_holy_devotionaura)
	[70] = "Interface\\Icons\\spell_holy_auraoflight", --> Ret
	-- Priest
	[256] = "Interface\\Icons\\spell_holy_powerwordshield", --> Discipline
	[257] = "Interface\\Icons\\spell_holy_guardianspirit", --> Holy
	[258] = "Interface\\Icons\\spell_shadow_shadowwordpain", --> Shadow
	-- Rogue
	[259] = "Interface\\Icons\\ability_rogue_eviscerate", --> Assassination (or: ability_rogue_shadowstrikes)
	[260] = "Interface\\Icons\\ability_backstab", --> Combat
	[261] = "Interface\\Icons\\ability_stealth", --> Subtlty
	-- Shaman
	[262] = "Interface\\Icons\\spell_nature_lightning", --> Elemental
	[263] = "Interface\\Icons\\spell_shaman_improvedstormstrike", --> Enhancement (or: spell_nature_lightningshield)
	[264] = "Interface\\Icons\\spell_nature_healingwavegreater", --> Restoration
	-- Warlock
	[265] = "Interface\\Icons\\spell_shadow_deathcoil", --> Affliction
	[266] = "Interface\\Icons\\spell_shadow_metamorphosis", --> Demonology
	[267] = "Interface\\Icons\\spell_shadow_rainoffire", --> Destruction
	-- Warrior
	[71] = "Interface\\Icons\\ability_warrior_savageblow", --> Arms
	[72] = "Interface\\Icons\\ability_warrior_innerrage", --> Fury (or: ability_warrior_titansgrip)
	[73] = "Interface\\Icons\\ability_warrior_defensivestance" --> Protection (or: ability_warrior_safeguard)
}

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
			nil,
			window.db.background.height,
			window.db.barwidth,
			window.db.barheight,
			"SkadaBarWindow" .. window.db.name
		)

		-- Add window buttons.
		bargroup:AddButton(
			L["Configure"],
			L["Opens the configuration window."],
			"Interface\\Addons\\Skada\\Media\\Textures\\icon-config",
			"Interface\\Addons\\Skada\\Media\\Textures\\icon-config",
			function() Skada:OpenMenu(bargroup.win) end
		)

		bargroup:AddButton(
			RESET,
			L["Resets all fight data except those marked as kept."],
			"Interface\\Addons\\Skada\\Media\\Textures\\icon-reset",
			"Interface\\Addons\\Skada\\Media\\Textures\\icon-reset",
			function() Skada:ShowPopup(bargroup.win) end
		)

		bargroup:AddButton(
			L["Segment"],
			L["Jump to a specific segment."],
			"Interface\\Buttons\\UI-GuildButton-PublicNote-Up",
			"Interface\\Buttons\\UI-GuildButton-PublicNote-Up",
			function(_, button)
				if button == "RightButton" then
					bargroup.win:set_selected_set(nil, IsModifierKeyDown() and 1 or -1)
				elseif button == "MiddleButton" then
					bargroup.win:set_selected_set("current")
				else
					Skada:SegmentMenu(bargroup.win)
				end
			end
		)

		bargroup:AddButton(
			L["Mode"],
			L["Jump to a specific mode."],
			"Interface\\GROUPFRAME\\UI-GROUP-MAINASSISTICON",
			"Interface\\GROUPFRAME\\UI-GROUP-MAINASSISTICON",
			function() Skada:ModeMenu(bargroup.win) end
		)

		bargroup:AddButton(
			L["Report"],
			L["Opens a dialog that lets you report your data to others in various ways."],
			"Interface\\Buttons\\UI-GuildButton-MOTD-Up",
			"Interface\\Buttons\\UI-GuildButton-MOTD-Up",
			function() Skada:OpenReportWindow(bargroup.win) end
		)

		bargroup:AddButton(
			L["Stop"],
			L["Stops or resumes the current segment. Useful for discounting data after a wipe. Can also be set to automatically stop in the settings."],
			"Interface\\CHATFRAME\\ChatFrameExpandArrow",
			"Interface\\CHATFRAME\\ChatFrameExpandArrow",
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
	bargroup.RegisterCallback(mod, "OnMouseWheel")
	bargroup.RegisterCallback(mod, "AnchorMoved")
	bargroup.RegisterCallback(mod, "WindowResizing")
	bargroup.RegisterCallback(mod, "WindowResized")
	bargroup:EnableMouse(true)
	bargroup:SetScript("OnMouseDown", function(_, button)
		if IsShiftKeyDown() then
			Skada:OpenMenu(window)
		elseif button == "RightButton" and IsControlKeyDown() then
			Skada:SegmentMenu(window)
		elseif button == "RightButton" and IsAltKeyDown() then
			Skada:ModeMenu(window)
		elseif button == "RightButton" then
			window:RightClick()
		end
	end)
	bargroup.button:SetScript("OnClick", function(_, button)
		if IsShiftKeyDown() then
			Skada:OpenMenu(window)
		elseif button == "RightButton" and IsControlKeyDown() then
			Skada:SegmentMenu(window)
		elseif button == "RightButton" and not IsAltKeyDown() then
			window:RightClick()
		end
	end)
	bargroup:HideIcon()

	local titletext = bargroup.button:GetFontString()
	titletext:SetWordWrap(false)
	titletext:SetPoint("LEFT", bargroup.button, "LEFT", 5, 1)
	titletext:SetJustifyH("LEFT")
	bargroup.button:SetHeight(window.db.title.height or 15)

	-- Register with LibWindow-1.0.
	libwindow.RegisterConfig(bargroup, window.db)

	-- Restore window position.
	libwindow.RestorePosition(bargroup)

	bargroup:SetMaxBars()
	window.bargroup = bargroup

	if not classicontcoords then
		-- class icon file and texture coordinates
		classiconfile = [[Interface\AddOns\Skada\Media\Textures\icon-classes]]
		classicontcoords = {}
		for class, coords in pairs(CLASS_ICON_TCOORDS) do
			classicontcoords[class] = coords
		end
		classicontcoords.ENEMY = {0.5, 0.75, 0.5, 0.75}
		classicontcoords.BOSS = {0.75, 1, 0.5, 0.75}
		classicontcoords.MONSTER = {0, 0.25, 0.75, 1}
		classicontcoords.PET = {0.25, 0.5, 0.75, 1}
		classicontcoords.PLAYER = {0.75, 1, 0.75, 1}
		classicontcoords.UNKNOWN = {0.5, 0.75, 0.75, 1}
		classicontcoords.AGGRO = {0.75, 1, 0.75, 1}

		-- role icon file and texture coordinates
		roleiconfile = [[Interface\LFGFrame\UI-LFG-ICON-PORTRAITROLES]]
		roleicontcoords = {
			DAMAGER = {0.3125, 0.63, 0.3125, 0.63},
			HEALER = {0.3125, 0.63, 0.015625, 0.3125},
			TANK = {0, 0.296875, 0.3125, 0.63},
			LEADER = {0, 0.296875, 0.015625, 0.3125},
			NONE = ""
		}
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

function mod:OnMouseWheel(_, frame, direction)
	local win = frame.win

	local maxbars = win.bargroup:GetMaxBars()
	local numbars = #win.dataset
	local offset = win.bargroup:GetBarOffset()

	if direction == 1 and offset > 0 then
		win.bargroup:SetBarOffset(offset - 1)
	elseif direction == -1 and ((numbars - maxbars - offset) > 0) then
		win.bargroup:SetBarOffset(offset + 1)
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

			if anchor and frame then
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
		libwindow.SavePosition(group)
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

	libwindow.SavePosition(group)
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

	group:SetMaxBars()
	Skada:ApplySettings()
end

do
	local barbackdrop = {bgFile = "Interface\\Buttons\\WHITE8X8"}
	function mod:CreateBar(win, name, label, value, maxvalue, icon, o)
		local bar, isnew = win.bargroup:NewCounterBar(name, label, value, maxvalue, icon, o)
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
		tinsert(win.history, win.selectedmode)
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
		elseif button == "RightButton" then
			win:RightClick()
		elseif win.metadata.click2 and not ignoredClick(win, win.metadata.click2) and IsShiftKeyDown() then
			showmode(win, id, label, win.metadata.click2)
		elseif win.metadata.click3 and not ignoredClick(win, win.metadata.click3) and IsControlKeyDown() then
			showmode(win, id, label, win.metadata.click3)
		elseif win.metadata.click1 and not ignoredClick(win, win.metadata.click1) then
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
			if (data.icon and not data.ignore) or (data.spec and win.db.specicons) or (data.class and win.db.classicons) or (data.role and win.db.roleicons) then
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

		local nr = 1
		for i, data in ipairs(win.dataset) do
			if data.id then
				local bar = win.bargroup:GetBar(data.id)

				if bar and bar.missingclass and data.class and not data.ignore then
					win.bargroup:RemoveBar(bar)
					bar.missingclass = nil
					bar = nil
				end

				if bar then
					bar:SetValue(data.value)
					bar:SetMaxValue(win.metadata.maxvalue or 1)
				else
					-- Initialization of bars.
					bar = mod:CreateBar(win, data.id, data.label, data.value, win.metadata.maxvalue or 1, data.icon, false)
					bar.id = data.id
					bar.text = data.label
					bar.fixed = false

					if not data.ignore then
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

					if data.spec and win.db.specicons and specicons[data.spec] then
						bar:ShowIcon()
						bar:SetIcon(specicons[data.spec])
					elseif data.role and data.role ~= "NONE" and win.db.roleicons then
						bar:ShowIcon()
						bar:SetIconWithCoord(roleiconfile, roleicontcoords[data.role])
					elseif data.class and win.db.classicons and classicontcoords[data.class] then
						bar:ShowIcon()
						bar:SetIconWithCoord(classiconfile, classicontcoords[data.class])
					elseif not data.ignore and not data.spellid then
						if data.icon and not bar:IsIconShown() then
							bar:ShowIcon()
							bar:SetIconWithCoord(classiconfile, classicontcoords["PLAYER"])
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

					if data.class and win.db.classcolortext then
						local c = Skada.classcolors[data.class]
						if c then
							bar.label:SetTextColor(c.r, c.g, c.b, c.a or 1)
							bar.timerLabel:SetTextColor(c.r, c.g, c.b, c.a or 1)
						end
					else
						bar.label:SetTextColor(1, 1, 1, 1)
						bar.timerLabel:SetTextColor(1, 1, 1, 1)
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
						bar:SetLabel(("%d. %s"):format(nr, data.text or data.label or UNKNOWN))
					else
						bar:SetLabel(("%s .%d"):format(data.text or data.label or UNKNOWN, nr))
					end
				else
					bar:SetLabel(data.text or data.label or UNKNOWN)
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

	local function move(self, button)
		local group = self:GetParent()
		if group then
			if button == "MiddleButton" then
				CloseDropDownMenus()
				group.isStretching = true
				group:SetBackdropColor(0, 0, 0, 0.9)
				group:SetFrameStrata("TOOLTIP")
				group:StartSizing("TOP")
				group:SetScript("OnUpdate", function(self, elapsed)
					self:SortBars()
					if self:GetHeight() >= 450 then
						self:StopMovingOrSizing()
					end
				end)
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
		g:SetTexture(p.bartexturepath or LSM:Fetch("statusbar", p.bartexture))
		g:SetBarBackgroundColor(p.barbgcolor.r, p.barbgcolor.g, p.barbgcolor.b, p.barbgcolor.a or 0.6)

		g:SetFont(
			p.barfontpath or LSM:Fetch("font", p.barfont),
			p.barfontsize,
			p.barfontflags,
			p.numfontpath or LSM:Fetch("font", p.numfont),
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
		fo:SetFont(p.title.fontpath or LSM:Fetch("font", p.title.font), p.title.fontsize, p.title.fontflags)
		if p.title.textcolor then
			fo:SetTextColor(p.title.textcolor.r, p.title.textcolor.g, p.title.textcolor.b, p.title.textcolor.a)
		end
		g.button:SetNormalFontObject(fo)

		titlebackdrop.bgFile = LSM:Fetch("statusbar", p.title.texture)
		titlebackdrop.tile = false
		titlebackdrop.tileSize = 0
		titlebackdrop.edgeSize = p.title.borderthickness
		g.button:SetBackdrop(titlebackdrop)

		local color = p.title.color
		g.button:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
		g.button:SetHeight(p.title.height or 15)

		Skada:ApplyBorder(g.button, p.title.bordertexture, p.title.bordercolor, p.title.borderthickness)

		if p.enabletitle then
			g:ShowAnchor()

			g:ShowButton(L["Configure"], p.buttons.menu)
			g:ShowButton(RESET, p.buttons.reset)
			g:ShowButton(L["Segment"], p.buttons.segment)
			g:ShowButton(L["Mode"], p.buttons.mode)
			g:ShowButton(L["Report"], p.buttons.report)
			g:ShowButton(L["Stop"], p.buttons.stop)
			g:AdjustButtons()

			if p.title.hovermode then
				for _, btn in ipairs(g.buttons) do
					btn:SetAlpha(0)
				end
				g.button:SetScript("OnEnter", function(self)
					for _, btn in ipairs(g.buttons) do
						btn:SetAlpha(0.25)
					end
				end)
				g.button:SetScript("OnLeave", function(self)
					for _, btn in ipairs(g.buttons) do
						btn:SetAlpha(MouseIsOver(self) and 0.25 or 0)
					end
				end)
			else
				for _, btn in ipairs(g.buttons) do
					btn:SetAlpha(0.25)
				end
				g.button:SetScript("OnEnter", nil)
				g.button:SetScript("OnLeave", nil)
			end
		else
			g:HideAnchor()
		end

		g:SetUseSpark(p.spark)

		-- Window border
		Skada:ApplyBorder(g, p.background.bordertexture, p.background.bordercolor, p.background.borderthickness)

		windowbackdrop.bgFile = p.background.texturepath or LSM:Fetch("background", p.background.texture)
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

		local bgcolor = p.background.color
		g:SetBackdropColor(bgcolor.r, bgcolor.g, bgcolor.b, bgcolor.a or 1)

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

		g:SetMaxBars()
		g:SetScript("OnShow", function(self) self:SetMaxBars() end)

		g:SetEnableMouse(not p.clickthrough)
		g:SetClampedToScreen(p.clamped)
		g:SetSmoothing(p.smoothing)
		libwindow.SetScale(g, p.scale)
		g:SortBars()
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
	end
end

function mod:AddDisplayOptions(win, options)
	local db = win.db

	options.baroptions = {
		type = "group",
		name = L["Bars"],
		desc = (L["Options for %s."]):format(L["Bars"]),
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
				name = L["Bar font"],
				desc = L["The font used by all bars."],
				order = 1,
				values = AceGUIWidgetLSMlists.font
			},
			barfontflags = {
				type = "select",
				name = L["Font Outline"],
				desc = L["Sets the font outline."],
				order = 2,
				values = {
					[""] = NONE,
					["OUTLINE"] = L["Outline"],
					["THICKOUTLINE"] = L["Thick outline"],
					["MONOCHROME"] = L["Monochrome"],
					["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
				}
			},
			barfontsize = {
				type = "range",
				name = L["Bar font size"],
				desc = L["The font size of all bars."],
				order = 3,
				width = "double",
				min = 6,
				max = 40,
				step = 1
			},
			numfont = {
				type = "select",
				dialogControl = "LSM30_Font",
				name = L["Values font"],
				desc = L["The font used by bar values."],
				order = 4,
				values = AceGUIWidgetLSMlists.font
			},
			numfontflags = {
				type = "select",
				name = L["Font Outline"],
				desc = L["Sets the font outline."],
				order = 5,
				values = {
					[""] = NONE,
					["OUTLINE"] = L["Outline"],
					["THICKOUTLINE"] = L["Thick outline"],
					["MONOCHROME"] = L["Monochrome"],
					["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
				}
			},
			numfontsize = {
				type = "range",
				name = L["Values font size"],
				desc = L["The font size of bar values."],
				order = 6,
				width = "double",
				min = 6,
				max = 40,
				step = 1
			},
			bartexture = {
				type = "select",
				dialogControl = "LSM30_Statusbar",
				name = L["Bar texture"],
				desc = L["The texture used by all bars."],
				order = 7,
				width = "double",
				values = AceGUIWidgetLSMlists.statusbar
			},
			barspacing = {
				type = "range",
				name = L["Bar spacing"],
				desc = L["Distance between bars."],
				order = 8,
				width = "double",
				min = 0,
				max = 10,
				step = 0.01,
				bigStep = 1
			},
			barheight = {
				type = "range",
				name = L["Bar height"],
				desc = L["The height of the bars."],
				order = 9,
				min = 10,
				max = 40,
				step = 0.01,
				bigStep = 1
			},
			barwidth = {
				type = "range",
				name = L["Bar width"],
				desc = L["The width of the bars."],
				order = 10,
				min = 80,
				max = 400,
				step = 0.01,
				bigStep = 1
			},
			barorientation = {
				type = "select",
				name = L["Bar orientation"],
				desc = L["The direction the bars are drawn in."],
				order = 11,
				width = "double",
				values = {[1] = L["Left to right"], [3] = L["Right to left"]}
			},
			reversegrowth = {
				type = "toggle",
				name = L["Reverse bar growth"],
				desc = L["Bars will grow up instead of down."],
				order = 12
			},
			showself = {
				type = "toggle",
				name = L["Always show self"],
				desc = L["Keeps the player shown last even if there is not enough space."],
				order = 13
			},
			color = {
				type = "color",
				name = L["Bar color"],
				desc = L["Choose the default color of the bars."],
				order = 14,
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
				name = L["Background color"],
				desc = L["Choose the background color of the bars."],
				order = 15,
				hasAlpha = true,
				get = function(_)
					return db.barbgcolor.r, db.barbgcolor.g, db.barbgcolor.b, db.barbgcolor.a
				end,
				set = function(_, r, g, b, a)
					db.barbgcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings(db.name)
				end
			},
			disablehighlight = {
				type = "toggle",
				name = L["Disable bar highlight"],
				desc = L["Hovering a bar won't make it brighter."],
				order = 16
			},
			spellschoolcolors = {
				type = "toggle",
				name = L["Spell school colors"],
				desc = L["Use spell school colors where applicable."],
				order = 17
			},
			classcolorbars = {
				type = "toggle",
				name = L["Class color bars"],
				desc = L["When possible, bars will be colored according to player class."],
				order = 18
			},
			classcolortext = {
				type = "toggle",
				name = L["Class color text"],
				desc = L["When possible, bar text will be colored according to player class."],
				order = 19
			},
			classicons = {
				type = "toggle",
				name = L["Class icons"],
				desc = L["Use class icons where applicable."],
				order = 20,
				disabled = function()
					return (db.specicons or db.roleicons)
				end
			},
			roleicons = {
				type = "toggle",
				name = L["Role icons"],
				desc = L["Use role icons where applicable."],
				order = 21,
				set = function()
					db.roleicons = not db.roleicons
					if db.roleicons and not db.classicons then
						db.classicons = true
					end
					Skada:ReloadSettings()
				end
			},
			specicons = {
				type = "toggle",
				name = L["Spec icons"],
				desc = L["Use specialization icons where applicable."],
				order = 22,
				set = function()
					db.specicons = not db.specicons
					if db.specicons and not db.classicons then
						db.classicons = true
					end
					Skada:ReloadSettings()
				end
			},
			spark = {
				type = "toggle",
				name = L["Show spark effect"],
				order = 23
			},
			clickthrough = {
				type = "toggle",
				name = L["Clickthrough"],
				desc = L["Disables mouse clicks on bars."],
				order = 24
			},
			smoothing = {
				type = "toggle",
				name = L["Smooth bars"],
				desc = L["Animate bar changes smoothly rather than immediately."],
				order = 25
			}
		}
	}

	options.titleoptions = {
		type = "group",
		name = L["Title Bar"],
		desc = (L["Options for %s."]):format(L["Title Bar"]),
		order = 2,
		get = function(i)
			return db.title[i[#i]]
		end,
		set = function(i, val)
			db.title[i[#i]] = val
			Skada:ApplySettings(db.name)
		end,
		args = {
			enable = {
				type = "toggle",
				name = L["Enable"],
				desc = L["Enables the title bar."],
				order = 1,
				width = "double",
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
				order = 2,
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
				name = L["Encounter timer"],
				desc = L["When enabled, a stopwatch is shown on the left side of the text."],
				order = 3,
				get = function()
					return db.combattimer
				end,
				set = function()
					db.combattimer = not db.combattimer
					Skada:ApplySettings(db.name)
				end
			},
			font = {
				type = "select",
				dialogControl = "LSM30_Font",
				name = L["Bar font"],
				desc = L["The font used by all bars."],
				values = AceGUIWidgetLSMlists.font,
				order = 4
			},
			fontflags = {
				type = "select",
				name = L["Font Outline"],
				desc = L["Sets the font outline."],
				order = 5,
				values = {
					[""] = NONE,
					["OUTLINE"] = L["Outline"],
					["THICKOUTLINE"] = L["Thick outline"],
					["MONOCHROME"] = L["Monochrome"],
					["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
				}
			},
			textcolor = {
				type = "color",
				name = L["Title color"],
				desc = L["The text color of the title."],
				order = 6,
				width = "double",
				hasAlpha = true,
				get = function()
					local c = db.title.textcolor or {r = 0.9, g = 0.9, b = 0.9, a = 1}
					return c.r, c.g, c.b, c.a
				end,
				set = function(_, r, g, b, a)
					db.title.textcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings(db.name)
				end
			},
			fontsize = {
				type = "range",
				name = L["Title font size"],
				desc = L["The font size of the title bar."],
				order = 7,
				min = 7,
				max = 40,
				step = 1
			},
			height = {
				type = "range",
				name = L["Title height"],
				desc = L["The height of the title frame."],
				order = 8,
				min = 10,
				max = 50,
				step = 1
			},
			texture = {
				type = "select",
				dialogControl = "LSM30_Statusbar",
				name = L["Background texture"],
				desc = L["The texture used as the background of the title."],
				order = 9,
				width = "double",
				values = AceGUIWidgetLSMlists.statusbar
			},
			color = {
				type = "color",
				name = L["Background color"],
				desc = L["The background color of the title."],
				order = 10,
				width = "double",
				hasAlpha = true,
				get = function(_)
					return db.title.color.r, db.title.color.g, db.title.color.b, db.title.color.a
				end,
				set = function(_, r, g, b, a)
					db.title.color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings(db.name)
				end
			},
			bordertexture = {
				type = "select",
				dialogControl = "LSM30_Border",
				name = L["Border texture"],
				desc = L["The texture used for the border of the title."],
				order = 11,
				width = "double",
				values = AceGUIWidgetLSMlists.border
			},
			bordercolor = {
				type = "color",
				name = L["Border color"],
				desc = L["The color used for the border."],
				hasAlpha = true,
				order = 12,
				width = "double",
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
				name = L["Border thickness"],
				desc = L["The thickness of the borders."],
				order = 13,
				width = "double",
				min = 0,
				max = 50,
				step = 0.5
			},
			buttons = {
				type = "group",
				name = L["Buttons"],
				order = 14,
				width = "double",
				inline = true,
				get = function(i)
					return db.buttons[i[#i]]
				end,
				set = function(i, val)
					db.buttons[i[#i]] = val
					Skada:ApplySettings(db.name)
				end,
				args = {
					report = {
						type = "toggle",
						name = L["Report"],
						desc = L["Opens a dialog that lets you report your data to others in various ways."],
						order = 1
					},
					mode = {
						type = "toggle",
						name = L["Mode"],
						desc = L["Jump to a specific mode."],
						order = 2
					},
					segment = {
						type = "toggle",
						name = L["Segment"],
						desc = L["Jump to a specific segment."],
						order = 3
					},
					reset = {
						type = "toggle",
						name = RESET,
						desc = L["Resets all fight data except those marked as kept."],
						order = 4
					},
					menu = {
						type = "toggle",
						name = L["Configure"],
						order = 5
					},
					stop = {
						type = "toggle",
						name = L["Stop"],
						desc = L["Stops or resumes the current segment. Useful for discounting data after a wipe. Can also be set to automatically stop in the settings."],
						order = 6
					},
					hovermode = {
						type = "toggle",
						name = L["Show on MouseOver"],
						order = 7,
						width = "double",
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

	-- add custom
	options.windowoptions.args.position.args.barwidth = {
		type = "range",
		name = L["Width"],
		order = 1,
		min = 80,
		max = 500,
		step = 0.01,
		bigStep = 1
	}
	options.windowoptions.args.position.args.height = {
		type = "range",
		name = L["Height"],
		order = 2,
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
		order = 3,
		min = -x,
		max = x,
		step = 0.01,
		bigStep = 1,
		set = function(_, val)
			local window = mod:GetBarGroup(db.name)
			if window then
				db.x = val
				libwindow.RestorePosition(window)
			end
		end
	}
	options.windowoptions.args.position.args.y = {
		type = "range",
		name = L["Y Offset"],
		order = 4,
		min = -y,
		max = y,
		step = 0.01,
		bigStep = 1,
		set = function(_, val)
			local window = mod:GetBarGroup(db.name)
			if window then
				db.y = val
				libwindow.RestorePosition(window)
			end
		end
	}
end