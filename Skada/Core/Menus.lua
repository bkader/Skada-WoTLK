local folder, Skada = ...
local Private = Skada.Private

local L = LibStub("AceLocale-3.0"):GetLocale(folder)
local AceGUI = LibStub("AceGUI-3.0")

local pairs, next, type, tsort = pairs, next, type, table.sort
local format, sbyte = string.format, string.byte
local min, max = math.min, math.max
local GetCursorPosition = GetCursorPosition
local GetScreenWidth, GetScreenHeight = GetScreenWidth, GetScreenHeight

local CreateFrame = CreateFrame
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local CloseDropDownMenus = CloseDropDownMenus
local ToggleDropDownMenu = ToggleDropDownMenu
local IsShiftKeyDown = IsShiftKeyDown
local del = Private.delTable
local _

local _menu_main = nil
local _menu_fight = nil
local _menu_mode = nil
local _menu_large = nil
local _menu_phase = nil
local info = nil
local iconName = "\124T%s:19:19:0:-1:32:32:2:30:2:30\124t %s"

-- references: windows, modes, sets
local windows, modes, sets = nil, nil, nil

-- guesses the dropdown location
local function get_dropdown_point()
	local x, y = GetCursorPosition(UIParent)
	x = x / UIParent:GetEffectiveScale()
	y = y / UIParent:GetEffectiveScale()

	local point, point2 = "LEFT", "LEFT"
	if x > GetScreenWidth() * 0.5 then
		point = "RIGHT"
		point2 = "RIGHT"
	end

	if y > GetScreenHeight() * 0.5 then
		point = "TOP" .. point
		point2 = "BOTTOM" .. point2
	else
		point = "BOTTOM" .. point
		point2 = "TOP" .. point2
	end

	return point, point2, x, y
end

local function set_info_text(set, i, num)
	if set.type == "pvp" or set.type == "arena" then
		if i and num then
			return format("\124cffc0c0c0%02.f.\124r \124cffffd100%s\124r", num - i + 1, Skada:GetSetLabel(set, true))
		else
			return format("\124cffff1919%s\124r", Skada:GetSetLabel(set, true))
		end
	elseif set.gotboss and set.success then
		if i and num then
			return format("\124cffc0c0c0%02.f.\124r \124cff19ff19%s\124r", num - i + 1, Skada:GetSetLabel(set, true))
		else
			return format("\124cff19ff19%s\124r", Skada:GetSetLabel(set, true))
		end
	elseif set.gotboss then
		if i and num then
			return format("\124cffc0c0c0%02.f.\124r \124cffff1919%s\124r", num - i + 1, Skada:GetSetLabel(set, true))
		else
			return format("\124cffff1919%s\124r", Skada:GetSetLabel(set, true))
		end
	elseif i and num then
		return format("\124cffc0c0c0%02.f.\124r %s", num - i + 1, Skada:GetSetLabel(set, true))
	else
		return Skada:GetSetLabel(set, true)
	end
end

-- Configuration menu.
function Skada:OpenMenu(window)
	local menu = _menu_main
	if not menu then
		menu = CreateFrame("Frame", format("%sMenuMain", folder), UIParent, "UIDropDownMenuTemplate")
		menu.displayMode = "MENU"
		_menu_main = menu
	end

	menu.win = window
	menu.initialize = menu.initialize or function(self, level)
		if not level then return end
		info = info or UIDropDownMenu_CreateInfo()

		if level == 1 then
			-- window menus
			windows = Skada:GetWindows()
			for i = 1, #windows do
				local win = windows[i]
				if win and win.db then
					wipe(info)
					info.text = win.db.name
					info.hasArrow = 1
					info.value = win
					info.notCheckable = 1
					info.colorCode = (self.win and self.win == win) and "\124cffffd100"
					UIDropDownMenu_AddButton(info, level)
				end
			end

			-- create window
			wipe(info)
			info.text = L["Create Window"]
			info.func = function()
				Skada:NewWindow(self.win)
			end
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			-- toggle window
			wipe(info)
			info.text = L["Toggle Windows"]
			info.func = function()
				Skada:ToggleWindow()
			end
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			wipe(info)
			info.disabled = 1
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			-- quick access menu
			wipe(info)
			info.text = L["Quick Access"]
			info.value = "shortcut"
			info.hasArrow = 1
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			wipe(info)
			info.disabled = 1
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			-- Can't report if we are not in a mode.
			if not self.win or (self.win and self.win.selectedmode) then
				wipe(info)
				info.text = L["Report"]
				info.value = "report"
				info.func = function()
					Private.open_report(self.win)
				end
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)
			end

			if self.win and (not self.win.db.enabletitle or (self.win.db.enabletitle and not self.win.db.buttons.segment)) then
				wipe(info)
				info.text = L["Select Segment"]
				info.value = "segment"
				info.hasArrow = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)
			else
				wipe(info)
				info.disabled = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)
			end

			-- delete segment menu
			wipe(info)
			info.text = L["Delete Segment"]
			info.value = "delete"
			info.hasArrow = 1
			info.disabled = (not Skada.char.sets or #Skada.char.sets == 0)
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			if Skada.db.profile.setstokeep > 0 then
				-- keep segment
				wipe(info)
				info.text = L["Keep Segment"]
				info.value = "keep"
				info.hasArrow = 1
				info.disabled = (not Skada.char.sets or #Skada.char.sets == 0)
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)
			end

			wipe(info)
			info.disabled = 1
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			-- start new segment
			wipe(info)
			info.text = L["Start New Segment"]
			info.func = function()
				Skada:NewSegment()
			end
			info.notCheckable = 1
			info.disabled = (Skada.current == nil)
			UIDropDownMenu_AddButton(info, level)

			-- start new phase
			wipe(info)
			info.text = L["Start New Phase"]
			info.func = function()
				Skada:NewPhase()
			end
			info.notCheckable = 1
			info.disabled = (Skada.current == nil)
			UIDropDownMenu_AddButton(info, level)

			wipe(info)
			info.disabled = 1
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			-- reset
			wipe(info)
			info.text = L["Reset"]
			info.func = function()
				Skada:ShowPopup()
			end
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			-- Configure
			wipe(info)
			info.text = L["Configure"]
			info.func = function()
				Private.open_options(self.win)
			end
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)

			-- Close menu item
			wipe(info)
			info.text = CLOSE
			info.func = function()
				CloseDropDownMenus()
			end
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)
		elseif level == 2 then
			if type(UIDROPDOWNMENU_MENU_VALUE) == "table" then
				local win = UIDROPDOWNMENU_MENU_VALUE

				-- window
				wipe(info)
				info.text = L["Window"]
				info.isTitle = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				-- lock window
				wipe(info)
				info.text = L["Lock Window"]
				info.func = function()
					win.db.barslocked = (win.db.barslocked ~= true) and true or nil
					Skada:ApplySettings(win.db.name)
				end
				info.checked = win.db.barslocked
				UIDropDownMenu_AddButton(info, level)

				-- hide window
				wipe(info)
				info.text = L["Hide Window"]
				info.func = function()
					if win:IsShown() then
						win.db.hidden = true
						win:Hide()
					else
						win.db.hidden = false
						win:Show()
					end
					Skada:ApplySettings(win.db.name, true)
				end
				info.checked = not win:IsShown()
				UIDropDownMenu_AddButton(info, level)

				-- snap window
				if win.db.display == "bar" then
					wipe(info)
					info.text = L["Sticky Window"]
					info.func = function()
						win.db.sticky = (win.db.sticky ~= true) and true or nil
						if not win.db.sticky then
							windows = Skada:GetWindows()
							for i = 1, #windows do
								local w = windows[i]
								if w and w.db and w.db.sticked and w.db.sticked[win.db.name] then
									w.db.sticked[win.db.name] = nil
									if next(w.db.sticked) == nil then
										w.db.sticked = del(w.db.sticked)
									end
								end
							end
						end
						Skada:ApplySettings(win.db.name)
					end
					info.checked = win.db.sticky
					UIDropDownMenu_AddButton(info, level)
				end

				-- clamped to screen
				wipe(info)
				info.text = L["Clamped To Screen"]
				info.func = function()
					win.db.clamped = (win.db.clamped ~= true) and true or nil
					Skada:ApplySettings(win.db.name)
				end
				info.checked = win.db.clamped
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.disabled = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				-- window
				if win.db.display == "bar" then
					wipe(info)
					info.text = L["Options"]
					info.isTitle = 1
					info.notCheckable = 1
					UIDropDownMenu_AddButton(info, level)

					if Skada.db.profile.showself ~= true then
						wipe(info)
						info.text = L["Always show self"]
						info.func = function()
							win.db.showself = (win.db.showself ~= true) and true or nil
							Skada:ApplySettings(win.db.name)
						end
						info.checked = (win.db.showself == true)
						UIDropDownMenu_AddButton(info, level)
					end

					if Skada.db.profile.showtotals ~= true then
						wipe(info)
						info.text = L["Show totals"]
						info.func = function()
							win.db.showtotals = (win.db.showtotals ~= true) and true or nil
							win:Wipe(true)
							Skada:UpdateDisplay()
						end
						info.checked = (win.db.showtotals == true)
						UIDropDownMenu_AddButton(info, level)
					end

					wipe(info)
					info.text = L["Include set"]
					info.func = function()
						win.db.titleset = (win.db.titleset ~= true) and true or nil
						Skada:ApplySettings(win.db.name)
					end
					info.checked = (win.db.titleset == true)
					UIDropDownMenu_AddButton(info, level)

					wipe(info)
					info.text = L["Encounter Timer"]
					info.func = function()
						win.db.combattimer = (win.db.combattimer ~= true) and true or nil
						Skada:ApplySettings(win.db.name)
					end
					info.checked = (win.db.combattimer == true)
					UIDropDownMenu_AddButton(info, level)

					wipe(info)
					info.disabled = 1
					info.notCheckable = 1
					UIDropDownMenu_AddButton(info, level)
				end

				-- delete window
				wipe(info)
				info.text = L["Delete Window"]
				info.func = function()
					return Skada:DeleteWindow(win.db.name, IsShiftKeyDown())
				end
				info.notCheckable = 1
				info.leftPadding = 16
				info.colorCode = "\124cffeb4c34"
				UIDropDownMenu_AddButton(info, level)
			elseif UIDROPDOWNMENU_MENU_VALUE == "segment" then
				wipe(info)
				info.text = L["Total"]
				info.func = function()
					self.win:SetSelectedSet("total")
					Skada:UpdateDisplay()
				end
				info.checked = (self.win.selectedset == "total")
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.text = L["Current"]
				info.func = function()
					self.win:SetSelectedSet("current")
					Skada:UpdateDisplay()
				end
				info.checked = (self.win.selectedset == "current")
				UIDropDownMenu_AddButton(info, level)

				sets = Skada.char.sets
				if #sets > 0 then
					wipe(info)
					info.disabled = 1
					info.notCheckable = 1
					UIDropDownMenu_AddButton(info, level)

					local num = #sets
					for i = 1, num do
						local set = sets[i]
						wipe(info)
						info.text = set_info_text(set, i, num)
						info.func = function()
							self.win:SetSelectedSet(i)
							Skada:UpdateDisplay()
						end
						info.checked = (self.win.selectedset == i)
						UIDropDownMenu_AddButton(info, level)
					end
				end
			elseif UIDROPDOWNMENU_MENU_VALUE == "delete" then
				sets = Skada.char.sets
				local num = #sets
				for i = 1, num do
					local set = sets[i]
					wipe(info)
					info.text = set_info_text(set, i, num)
					info.func = function()
						Skada:DeleteSet(set, i)
					end
					info.notCheckable = 1
					UIDropDownMenu_AddButton(info, level)
				end
			elseif UIDROPDOWNMENU_MENU_VALUE == "keep" then
				sets = Skada.char.sets
				local num, kept = #sets, 0
				for i = 1, num do
					local set = sets[i]
					if set.keep then
						kept = kept + 1
					end

					wipe(info)
					info.text = set_info_text(set, i, num)
					info.func = function()
						set.keep = (set.keep ~= true) and true or nil
					end
					info.checked = set.keep
					info.keepShownOnClick = true
					UIDropDownMenu_AddButton(info, level)
				end

				if num > 0 then
					wipe(info)
					info.disabled = 1
					info.notCheckable = 1
					UIDropDownMenu_AddButton(info, level)

					wipe(info)
					info.text = L["Select All"]
					info.func = function()
						sets = Skada.char.sets
						for i = 1, #sets do
							sets[i].keep = true
						end
					end
					info.notCheckable = 1
					info.leftPadding = 16
					info.disabled = (num == kept)
					UIDropDownMenu_AddButton(info, level)

					wipe(info)
					info.text = L["Deselect All"]
					info.func = function()
						sets = Skada.char.sets
						for i = 1, #sets do
							sets[i].keep = nil
						end
					end
					info.notCheckable = 1
					info.leftPadding = 16
					info.disabled = (kept == 0)
					UIDropDownMenu_AddButton(info, level)
				end
			elseif UIDROPDOWNMENU_MENU_VALUE == "shortcut" then
				-- time measure
				wipe(info)
				info.text = L["Time Measure"]
				info.isTitle = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.text = L["Activity Time"]
				info.func = function()
					Skada.db.profile.timemesure = 1
					Skada:ApplySettings(true)
				end
				info.checked = (Skada.db.profile.timemesure == 1)
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.text = L["Effective Time"]
				info.func = function()
					Skada.db.profile.timemesure = 2
					Skada:ApplySettings(true)
				end
				info.checked = (Skada.db.profile.timemesure == 2)
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.disabled = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				-- number format
				wipe(info)
				info.text = L["Number format"]
				info.isTitle = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.text = L["Condensed"]
				info.func = function()
					Skada.db.profile.numberformat = 1
					Skada:ApplySettings(true)
				end
				info.checked = (Skada.db.profile.numberformat == 1)
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.text = L["Comma"]
				info.func = function()
					Skada.db.profile.numberformat = 2
					Skada:ApplySettings(true)
				end
				info.checked = (Skada.db.profile.numberformat == 2)
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.text = L["Detailed"]
				info.func = function()
					Skada.db.profile.numberformat = 3
					Skada:ApplySettings(true)
				end
				info.checked = (Skada.db.profile.numberformat == 3)
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.disabled = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				-- number format
				wipe(info)
				info.text = L["Other"]
				info.isTitle = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.text = L["Show totals"]
				info.func = function()
					Skada.db.profile.showtotals = (Skada.db.profile.showtotals ~= true) and true or nil
					Skada:Wipe()
					Skada:UpdateDisplay(true)
				end
				info.checked = (Skada.db.profile.showtotals == true)
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.text = L["Show rank numbers"]
				info.func = function()
					Skada.db.profile.showranks = (Skada.db.profile.showranks ~= true) and true or nil
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.showranks == true)
				info.keepShownOnClick = 1
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.text = L["Always show self"]
				info.func = function()
					Skada.db.profile.showself = (Skada.db.profile.showself ~= true) and true or nil
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.showself == true)
				info.keepShownOnClick = 1
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.text = L["Aggressive combat detection"]
				info.func = function()
					Skada.db.profile.tentativecombatstart = (Skada.db.profile.tentativecombatstart ~= true) and true or nil
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.tentativecombatstart == true)
				info.keepShownOnClick = 1
				UIDropDownMenu_AddButton(info, level)

				wipe(info)
				info.text = L["Absorbed Damage"]
				info.func = function()
					Skada.db.profile.absdamage = (Skada.db.profile.absdamage ~= true) and true or nil
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.absdamage == true)
				info.keepShownOnClick = 1
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end

	local x, y
	menu.point, _, x, y = get_dropdown_point()
	ToggleDropDownMenu(1, nil, menu, "UIParent", x, y)
end

function Skada:SegmentMenu(window)
	if self.testMode then return end

	local menu = _menu_fight
	if not menu then
		menu = CreateFrame("Frame", format("%sMenuFight", folder), UIParent, "UIDropDownMenuTemplate")
		menu.displayMode = "MENU"
		_menu_fight = menu
	end

	menu.win = window
	menu.initialize = menu.initialize or function(self, level)
		if not level or not self.win then return end
		info = info or UIDropDownMenu_CreateInfo()

		sets = Skada.char.sets
		local numsets = #sets

		if level == 1 then
			wipe(info)
			info.text = L["Total"]
			info.func = function()
				self.win:SetSelectedSet("total")
				Skada:UpdateDisplay()
			end
			info.checked = (self.win.selectedset == "total")
			UIDropDownMenu_AddButton(info, level)

			wipe(info)
			info.text = L["Current"]
			info.func = function()
				self.win:SetSelectedSet("current")
				Skada:UpdateDisplay()
			end
			info.checked = (self.win.selectedset == "current")
			UIDropDownMenu_AddButton(info, level)

			if numsets > 0 then
				wipe(info)
				info.disabled = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				local offset = 1
				if type(self.win.selectedset) == "number" and self.win.selectedset > 25 then
					offset = min(25, max(1, numsets - 24))
				end

				local nr = 0
				for i = offset, numsets do
					nr = nr + 1
					local set = sets[i]
					wipe(info)
					info.text = set_info_text(set, i, numsets)
					info.func = function()
						self.win:SetSelectedSet(i)
						Skada:UpdateDisplay()
					end
					info.checked = (self.win.selectedset == i)
					UIDropDownMenu_AddButton(info, level)
					if nr == 25 then
						break
					end
				end

				if numsets > nr then
					wipe(info)
					info.disabled = 1
					info.notCheckable = 1
					UIDropDownMenu_AddButton(info, level)

					wipe(info)
					if offset == 1 then
						info.text = L["Previous"]
						info.value = "prev"
					else
						info.text = L["Next"]
						info.value = "next"
					end
					info.padding = 40
					info.hasArrow = 1
					UIDropDownMenu_AddButton(info, level)
				end
			end
		elseif level == 2 then
			if UIDROPDOWNMENU_MENU_VALUE == "prev" or UIDROPDOWNMENU_MENU_VALUE == "next" then
				local start, stop = 26, numsets
				if UIDROPDOWNMENU_MENU_VALUE == "next" then
					start, stop = 1, max(1, numsets - 25)
				end

				for i = start, stop do
					local set = sets[i]
					wipe(info)
					info.text = set_info_text(set, i, numsets)
					info.func = function()
						self.win:SetSelectedSet(i)
						Skada:UpdateDisplay()
					end
					info.checked = (self.win.selectedset == i)
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end
	end

	local x, y
	menu.point, _, x, y = get_dropdown_point()
	ToggleDropDownMenu(1, nil, menu, "UIParent", x, y)
end

do
	local categories -- list of mode categories.
	local categorized -- modes organized by category.

	local function sort_categories(a, b)
		local a_score = (a == L["Other"]) and 1000 or 0
		local b_score = (b == L["Other"]) and 1000 or 0
		a_score = a_score + (sbyte(a, 1) * 10) + sbyte(a, 1)
		b_score = b_score + (sbyte(b, 1) * 10) + sbyte(b, 1)
		return a_score < b_score
	end

	local function construct_categories()
		if categories then return end

		categories = {}
		categorized = {}

		modes = Skada:GetModes()
		for i = 1, #modes do
			local mode = modes[i]
			categorized[mode.category] = categorized[mode.category] or {}
			categorized[mode.category][#categorized[mode.category] + 1] = mode
			if not tContains(categories, mode.category) then
				categories[#categories + 1] = mode.category
			end
		end

		tsort(categories, sort_categories)
	end

	local function build_large_menu()
		local menu_name = format("%sMenuModeLarge", folder)
		local menu = CreateFrame("Button", menu_name, UIParent)
		menu:SetFrameStrata("TOOLTIP")
		menu:SetClampedToScreen(true)
		menu:SetBackdrop({
			bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
			edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
			inset = 4,
			edgeSize = 8,
			tile = true,
			insets = {left = 2, right = 2, top = 2, bottom = 2}
		})
		menu:SetBackdropColor(0, 0, 0, 0.83)
		menu:SetBackdropBorderColor(0, 0, 0, 1)
		menu:SetPoint("CENTER")
		menu.headers = {}
		menu.buttons = {}

		local function click_on_mode(self, button)
			local mode = menu.win and menu.buttons[self]
			if mode and button == "LeftButton" then
				menu.win:DisplayMode(mode)
			end
			menu:Hide()
		end

		local function create_button(mode, index, header)
			local btn = CreateFrame("Button", nil, menu)
			btn:SetFrameLevel(menu:GetFrameLevel() + 1)
			btn:SetNormalFontObject("GameFontHighlightSmallLeft")
			btn:SetHighlightFontObject("GameFontNormalSmallLeft")
			btn:SetScript("OnClick", click_on_mode)

			-- format button text
			if mode.metadata and mode.metadata.icon then
				btn:SetText(format(iconName, mode.metadata.icon, mode.localeName))
			else
				btn:SetText(mode.localeName)
			end

			local fs = btn:GetFontString()
			local width = fs:GetStringWidth() + 12
			local height = fs:GetStringHeight() + 4
			btn:SetWidth(width)
			btn:SetHeight(height)

			-- position
			local prev = header.buttons[index - 1]
			btn:ClearAllPoints()
			if index == 1 then
				height = height + 12 -- extra bottom margin
				btn:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
				btn:SetPoint("TOPRIGHT", header, "TOPRIGHT")
			elseif prev then
				btn:SetPoint("TOPLEFT", prev, "BOTTOMLEFT")
				btn:SetPoint("TOPRIGHT", prev, "TOPRIGHT")
			end

			menu.buttons[btn] = mode
			header.buttons[index] = btn
			return width, height
		end

		local function create_header(text, index, modules)
			local header = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmallLeft")
			header:SetWordWrap(false)
			header:SetText(text)
			menu.headers[index] = header
			header.buttons = header.buttons or {}

			local width = header:GetStringWidth() + 12
			local height = header:GetStringHeight() + 8
			header:SetHeight(height)

			-- position
			local prev = menu.headers[index - 1]
			header:ClearAllPoints()
			if index == 1 then
				header:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -6)
			elseif prev then
				header:SetPoint("LEFT", prev, "RIGHT", 12, 0)
			end

			for i, mode in pairs(modules) do
				local w, h = create_button(mode, i, header)
				if w > width then
					width = w
				end
				height = height + h
			end

			header:SetWidth(width)

			if index > 0 then -- small left margin
				width = width + 12
			end
			return width, height
		end

		local width, height = 12, 0
		for index, name in pairs(categories) do
			local w, h = create_header(name, index, categorized[name])
			width = width + w
			if h > height then
				height = h
			end
		end

		menu:SetWidth(width)
		menu:SetHeight(height)

		menu:RegisterForClicks("AnyUp")
		menu:SetScript("OnMouseDown", function(self, button)
			if button == "RightButton" then
				self:Hide()
			end
		end)

		-- to set highlight stuff
		menu:SetScript("OnShow", function(self)
			self.opened = true
			local mode = self.win and self.win.selectedmode
			if not mode then return end
			for btn, module in pairs(self.buttons) do
				if module == mode then
					btn:LockHighlight()
				else
					btn:UnlockHighlight()
				end
			end
		end)
		menu:SetScript("OnHide", function(self)
			self.opened = nil
		end)

		menu:Hide()
		UISpecialFrames[#UISpecialFrames + 1] = menu_name
		return menu
	end

	local function large_mode_menu(self, window, frame)
		local menu = _menu_large
		if not menu then
			menu = build_large_menu()
			_menu_large = menu
		end

		menu.win = window

		if menu.opened then
			menu:Hide()
			menu.opened = nil
		else
			local point, rPoint = get_dropdown_point()
			if point then
				menu:ClearAllPoints()
				menu:SetPoint(point, frame or UIParent, rPoint)
			end
			menu.opened = true
			menu:Show()
			CloseDropDownMenus()
		end
	end

	function Skada:ModeMenu(window, frame, large)
		construct_categories()

		if large then
			return large_mode_menu(self, window, frame)
		elseif _menu_large then
			_menu_large:Hide()
		end

		local menu = _menu_mode
		if not menu then
			menu = CreateFrame("Frame", format("%sMenuMode", folder), UIParent, "UIDropDownMenuTemplate")
			menu.displayMode = "MENU"
			_menu_mode = menu
		end

		menu.win = window
		menu.initialize = menu.initialize or function(self, level)
			if not level or not self.win then return end
			info = info or UIDropDownMenu_CreateInfo()

			if level == 1 then
				if #categories > 0 then
					for i = 1, #categories do
						local category = categories[i]
						wipe(info)
						info.text = category
						info.value = category
						info.hasArrow = 1
						info.notCheckable = 1
						if self.win and self.win.selectedmode and (self.win.selectedmode.category == category or (self.win.parentmode and self.win.parentmode.category == category)) then
							info.colorCode = "\124cffffd100"
						end
						UIDropDownMenu_AddButton(info, level)
					end

					wipe(info)
					info.disabled = 1
					info.notCheckable = 1
					UIDropDownMenu_AddButton(info, level)
				end

				-- Close menu item
				wipe(info)
				info.text = CLOSE
				info.func = function()
					CloseDropDownMenus()
				end
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)
			elseif level == 2 and categorized[UIDROPDOWNMENU_MENU_VALUE] then
				for i = 1, #categorized[UIDROPDOWNMENU_MENU_VALUE] do
					local mode = categorized[UIDROPDOWNMENU_MENU_VALUE][i]
					wipe(info)

					if Skada.db.profile.moduleicons and mode.metadata and mode.metadata.icon then
						info.text = format(iconName, mode.metadata.icon, mode.localeName)
					else
						info.text = mode.localeName
					end

					info.func = function()
						self.win:DisplayMode(mode)
						CloseDropDownMenus()
					end

					if self.win and self.win.selectedmode and (self.win.selectedmode == mode or self.win.parentmode == mode) then
						info.checked = 1
						info.colorCode = "\124cffffd100"
					end

					UIDropDownMenu_AddButton(info, level)
				end
			end
		end

		local x, y
		menu.point, _, x, y = get_dropdown_point()
		ToggleDropDownMenu(1, nil, menu, "UIParent", x, y)
	end
end

do
	local strtrim = strtrim or string.trim
	local UnitExists, UnitName = UnitExists, UnitName

	-- handles reporting
	local function do_report(window, barid)
		local mode = Skada.db.profile.report.mode
		local set = Skada.db.profile.report.set
		local channel = Skada.db.profile.report.channel
		local chantype = Skada.db.profile.report.chantype
		local number = Skada.db.profile.report.number

		if channel == "whisper" then
			channel = Skada.db.profile.report.target
			if channel and #strtrim(channel) == 0 then
				channel = nil
			end
		elseif channel == "target" then
			if UnitExists("target") then
				local toon, realm = UnitName("target")
				if realm and #realm > 0 then
					channel = toon .. "-" .. realm
				else
					channel = toon
				end
			else
				channel = nil
			end
		end

		if channel and chantype and mode and set and number then
			Skada:Report(channel, chantype, mode, set, number, window, barid)

			-- hide report window if shown.
			if Skada.reportwindow and Skada.reportwindow:IsShown() then
				Skada.reportwindow:Hide()
			end
		else
			Skada:Print("Error: Whisper target not found")
		end
	end

	local function destroy_report_window()
		if Skada.reportwindow then
			-- remove AceGUI hacks before recycling the widget
			local frame = Skada.reportwindow
			frame.LayoutFinished = frame.orig_LayoutFinished
			frame.frame:SetScript("OnKeyDown", nil)
			frame.frame:EnableKeyboard(false)
			frame:ReleaseChildren()
			frame:Release()
			Skada.reportwindow = nil
		end
	end

	local function create_report_window(window)
		Skada.reportwindow = AceGUI:Create("Window")

		local frame = Skada.reportwindow
		frame:SetLayout("List")
		frame:EnableResize(false)
		frame:SetWidth(225)
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

		if window then
			frame:SetTitle(L["Report"] .. format(" - %s", window.db.name))
		else
			frame:SetTitle(L["Report"])
		end

		frame:SetCallback("OnClose", destroy_report_window)

		-- make the frame closable with Escape button
		_G.SkadaReportWindow = frame.frame
		UISpecialFrames[#UISpecialFrames + 1] = "SkadaReportWindow"

		-- slight AceGUI hack to auto-set height of Window widget:
		frame.orig_LayoutFinished = frame.LayoutFinished
		frame.LayoutFinished = function(self, _, height)
			frame:SetHeight(height + 57)
		end

		local barid
		if window then
			Skada.db.profile.report.set = window.selectedset
			Skada.db.profile.report.mode = window.db.mode

			-- report a specific line
			if window.selectedset and window.selectedmode then
				local linebox = AceGUI:Create("Dropdown")
				linebox:SetLabel(L["Line"])
				linebox:SetList({[""] = L["None"]})

				local dataset = window.dataset
				for i = 1, #dataset do
					local data = dataset[i]
					if data and data.id and not data.ignore then
						linebox:AddItem(data.id, format("%s   %s", data.text or data.label, data.valuetext))
					end
				end
				linebox:SetCallback("OnValueChanged", function(f, e, value) barid = (value ~= "") and value or nil end)
				linebox:SetValue(barid or "")
				frame:AddChild(linebox)
			end
		else
			-- Mode, default last chosen or first available.
			local modebox = AceGUI:Create("Dropdown")
			modebox:SetLabel(L["Mode"])
			modebox:SetList({})

			modes = Skada:GetModes()
			for i = 1, #modes do
				modebox:AddItem(modes[i].moduleName, modes[i].localeName)
			end
			modebox:SetCallback("OnValueChanged", function(f, e, value) Skada.db.profile.report.mode = value end)
			modebox:SetValue(Skada.db.profile.report.mode or Skada:GetModes()[1])
			frame:AddChild(modebox)

			-- Segment, default last chosen or last set.
			local setbox = AceGUI:Create("Dropdown")
			setbox:SetLabel(L["Segment"])
			setbox:SetList({total = L["Total"], current = L["Current"]})
			sets = Skada.char.sets
			for i = 1, #sets do
				setbox:AddItem(i, sets[i].name)
			end
			setbox:SetCallback("OnValueChanged", function(f, e, value) Skada.db.profile.report.set = value end)
			setbox:SetValue(Skada.db.profile.report.set or Skada.char.sets[1])
			frame:AddChild(setbox)
		end

		local channellist = {
			whisper = {L["Whisper"], "whisper", true},
			target = {L["Whisper Target"], "whisper"},
			say = {CHAT_MSG_SAY, "preset"},
			raid = {CHAT_MSG_RAID, "preset"},
			party = {CHAT_MSG_PARTY, "preset"},
			guild = {CHAT_MSG_GUILD, "preset"},
			officer = {CHAT_MSG_OFFICER, "preset"},
			self = {L["Self"], "self"}
		}

		local list = {GetChannelList()}
		for i = 1, #list, 2 do
			local chan = list[i + 1]
			if chan ~= "Trade" and chan ~= "General" and chan ~= "LocalDefense" and chan ~= "LookingForGroup" then -- These should be localized.
				channellist[chan] = {format("%s: %d/%s", L["Channel"], list[i], chan), "channel"}
			end
		end

		-- Channel, default last chosen or Say.
		local channelbox = AceGUI:Create("Dropdown")
		channelbox:SetLabel(L["Channel"])
		channelbox:SetList({})
		for chan, kind in pairs(channellist) do
			channelbox:AddItem(chan, kind[1])
		end

		local origchan = Skada.db.profile.report.channel or "say"
		if not channellist[origchan] then
			origchan = "say"
		end

		channelbox:SetValue(origchan)
		channelbox:SetCallback("OnValueChanged", function(f, e, value)
			Skada.db.profile.report.channel = value
			Skada.db.profile.report.chantype = channellist[value][2]
			if channellist[origchan][3] ~= channellist[value][3] then
				-- redraw in-place to add/remove whisper widget
				local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
				destroy_report_window()
				create_report_window(window)
				Skada.reportwindow:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
			end
		end)
		frame:AddChild(channelbox)

		local lines = AceGUI:Create("Slider")
		lines:SetLabel(L["Lines"])
		lines:SetValue(Skada.db.profile.report.number ~= nil and Skada.db.profile.report.number or 10)
		lines:SetSliderValues(1, 25, 1)
		lines:SetCallback("OnValueChanged", function(self, event, value)
			Skada.db.profile.report.number = value
		end)
		lines:SetFullWidth(true)
		frame:AddChild(lines)

		if channellist[origchan][3] then
			local whisperbox = AceGUI:Create("EditBox")
			whisperbox:SetLabel(L["Whisper Target"])
			whisperbox:SetText(Skada.db.profile.report.target or "")

			whisperbox:SetCallback("OnEnterPressed", function(box, event, text)
				-- remove spaces which are always non-meaningful and can sometimes cause problems
				if strlenutf8(text) == #text then
					local ntext = text:gsub("%s", "")
					if ntext ~= text then
						text = ntext
						whisperbox:SetText(text)
					end
				end
				Skada.db.profile.report.target = text
				frame.button.frame:Click()
			end)

			whisperbox:SetCallback("OnTextChanged", function(box, event, text)
				Skada.db.profile.report.target = text
			end)
			whisperbox:SetFullWidth(true)
			frame:AddChild(whisperbox)
		end

		local report = AceGUI:Create("Button")
		frame.button = report
		report:SetText(L["Report"])
		report:SetCallback("OnClick", function()
			do_report(window, barid)
		end)

		report:SetFullWidth(true)
		frame:AddChild(report)
	end

	function Private.open_report(window)
		if Skada.testMode then
			return -- nothing to do.
		elseif IsShiftKeyDown() then
			do_report(window) -- quick report?
		elseif Skada.reportwindow == nil then
			create_report_window(window)
		elseif Skada.reportwindow:IsShown() then
			Skada.reportwindow:Hide()
		else
			Skada.reportwindow:Show()
		end
	end
end

function Skada:PhaseMenu(window)
	if self.testMode or not self.tempsets or #self.tempsets == 0 then return end

	local menu = _menu_phase
	if not menu then
		menu = CreateFrame("Frame", format("%sMenuPhase", folder), UIParent, "UIDropDownMenuTemplate")
		menu.displayMode = "MENU"
		_menu_phase = menu
	end

	menu.initialize = menu.initialize or function(self, level)
		if not level then return end
		info = info or UIDropDownMenu_CreateInfo()

		for i = #Skada.tempsets, 1, -1 do
			wipe(info)
			local set = Skada.tempsets[i]
			info.text = format(L["%s - Phase %s"], set.mobname or L["Unknown"], set.phase)
			info.func = function()
				if set.stopped then
					Skada:ResumeSegment(nil, i)
				else
					Skada:StopSegment(nil, i)
				end
			end
			info.notCheckable = 1
			info.colorCode = set.stopped and "\124cffff1919"
			UIDropDownMenu_AddButton(info, level)
		end

		wipe(info)
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)

		wipe(info)
		info.text = L["All Segments"]
		info.func = function()
			if Skada.current.stopped then
				Skada:ResumeSegment()
			else
				Skada:StopSegment()
			end
		end
		info.colorCode = Skada.current.stopped and "\124cffff1919"
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
	end

	local x, y
	menu.point, _, x, y = get_dropdown_point()
	ToggleDropDownMenu(1, nil, menu, "UIParent", x, y)
end

function Skada:CloseMenus()
	CloseDropDownMenus()
	if _menu_large then
		_menu_large:Hide()
	end
end
