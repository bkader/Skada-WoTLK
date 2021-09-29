assert(Skada, "Skada not found!")

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local AceGUI = LibStub("AceGUI-3.0")

local tinsert, tsort = table.insert, table.sort
local pairs, ipairs, type = pairs, ipairs, type
local format, sbyte = string.format, string.byte
local GetCursorPosition = GetCursorPosition
local GetScreenWidth, GetScreenHeight = GetScreenWidth, GetScreenHeight

local CreateFrame = CreateFrame
local UIDropDownMenu_CreateInfo = L_UIDropDownMenu_CreateInfo or UIDropDownMenu_CreateInfo
local UIDropDownMenu_AddButton = L_UIDropDownMenu_AddButton or UIDropDownMenu_AddButton
local CloseDropDownMenus = L_CloseDropDownMenus or CloseDropDownMenus
local ToggleDropDownMenu = L_ToggleDropDownMenu or ToggleDropDownMenu
local UIDropDownMenu_AddSeparator = L_UIDropDownMenu_AddSeparator or UIDropDownMenu_AddSeparator

-- guesses the dropdown location
local function getDropdownPoint()
	local x, y = GetCursorPosition(UIParent)
	x = x / UIParent:GetEffectiveScale()
	y = y / UIParent:GetEffectiveScale()

	local point = (x > GetScreenWidth() / 2) and "RIGHT" or "LEFT"
	point = ((y > GetScreenHeight() / 2) and "TOP" or "BOTTOM") .. point
	return point, x, y
end

-- Configuration menu.
function Skada:OpenMenu(window)
	self.skadamenu = self.skadamenu or CreateFrame("Frame", "SkadaMenu", UIParent, "UIDropDownMenuTemplate")
	self.skadamenu.displayMode = "MENU"
	self.skadamenu.initialize = function(self, level)
		if not level then return end
		local info

		if level == 1 then
			-- window menus
			for _, win in Skada:IterateWindows() do
				info = UIDropDownMenu_CreateInfo()
				info.text = win.db.name
				info.hasArrow = 1
				info.value = win
				info.notCheckable = 1
				info.colorCode = (window and window == win) and "|cffffd100"
				UIDropDownMenu_AddButton(info, level)
			end

			-- create window
			info = UIDropDownMenu_CreateInfo()
			info.text = L["Create Window"]
			info.func = Skada.NewWindow
			info.notCheckable = 1
			info.padding = 16
			UIDropDownMenu_AddButton(info, level)

			-- toggle window
			info = UIDropDownMenu_CreateInfo()
			info.text = L["Toggle Windows"]
			info.func = function()
				Skada:ToggleWindow()
			end
			info.notCheckable = 1
			info.padding = 16
			UIDropDownMenu_AddButton(info, level)

			UIDropDownMenu_AddSeparator(info, level)

			-- quick access menu
			info = UIDropDownMenu_CreateInfo()
			info.text = L["Quick Access"]
			info.value = "shortcut"
			info.hasArrow = 1
			info.notCheckable = 1
			info.padding = 16
			UIDropDownMenu_AddButton(info, level)

			UIDropDownMenu_AddSeparator(info, level)

			-- Can't report if we are not in a mode.
			if not window or (window and window.selectedmode) then
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Report"]
				info.value = "report"
				info.func = function()
					Skada:OpenReportWindow(window)
				end
				info.notCheckable = 1
				info.padding = 16
				UIDropDownMenu_AddButton(info, level)
			end

			if window then
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Select Segment"]
				info.value = "segment"
				info.hasArrow = 1
				info.notCheckable = 1
				info.padding = 16
				UIDropDownMenu_AddButton(info, level)
			end

			-- delete segment menu
			info = UIDropDownMenu_CreateInfo()
			info.text = L["Delete Segment"]
			info.value = "delete"
			info.hasArrow = 1
			info.notCheckable = 1
			info.padding = 16
			UIDropDownMenu_AddButton(info, level)

			if Skada.db.profile.setstokeep > 0 then
				-- keep segment
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Keep Segment"]
				info.value = "keep"
				info.hasArrow = 1
				info.notCheckable = 1
				info.padding = 16
				UIDropDownMenu_AddButton(info, level)
			end

			-- start new segment
			info = UIDropDownMenu_CreateInfo()
			info.text = L["Start New Segment"]
			info.func = function()
				Skada:NewSegment()
			end
			info.notCheckable = 1
			info.padding = 16
			UIDropDownMenu_AddButton(info, level)

			UIDropDownMenu_AddSeparator(info, level)

			-- reset
			info = UIDropDownMenu_CreateInfo()
			info.text = RESET
			info.func = function()
				Skada:ShowPopup()
			end
			info.notCheckable = 1
			info.padding = 16
			UIDropDownMenu_AddButton(info, level)

			-- Configure
			info = UIDropDownMenu_CreateInfo()
			info.text = L["Configure"]
			info.func = function()
				Skada:OpenOptions(window)
			end
			info.notCheckable = 1
			info.padding = 16
			UIDropDownMenu_AddButton(info, level)

			-- Close menu item
			info = UIDropDownMenu_CreateInfo()
			info.text = CLOSE
			info.func = function()
				CloseDropDownMenus()
			end
			info.notCheckable = 1
			info.padding = 16
			UIDropDownMenu_AddButton(info, level)
		elseif level == 2 then
			if type(L_UIDROPDOWNMENU_MENU_VALUE) == "table" then
				local window = L_UIDROPDOWNMENU_MENU_VALUE

				if not Skada.db.profile.shortmenu then
					-- dsplay modes only if we have modules enabled.
					local modes = Skada:GetModes()
					if #modes > 0 then
						info = UIDropDownMenu_CreateInfo()
						info.isTitle = 1
						info.text = L["Mode"]
						info.notCheckable = 1
						UIDropDownMenu_AddButton(info, level)

						for _, mode in Skada:IterateModes() do
							info = UIDropDownMenu_CreateInfo()
							info.text = mode:GetName()
							info.func = function()
								window:DisplayMode(mode)
							end
							info.icon = (Skada.db.profile.modeicons and mode.metadata) and mode.metadata.icon
							info.checked = (window.selectedmode == mode or window.parentmode == mode)
							UIDropDownMenu_AddButton(info, level)
						end

						info = UIDropDownMenu_CreateInfo()
						info.disabled = 1
						info.notCheckable = 1
						UIDropDownMenu_AddButton(info, level)
					end

					info = UIDropDownMenu_CreateInfo()
					info.isTitle = 1
					info.text = L["Segment"]
					info.notCheckable = 1
					UIDropDownMenu_AddButton(info, level)

					info = UIDropDownMenu_CreateInfo()
					info.text = L["Total"]
					info.func = function()
						window:set_selected_set("total")
						Skada:Wipe()
						Skada:UpdateDisplay(true)
					end
					info.checked = (window.selectedset == "total")
					UIDropDownMenu_AddButton(info, level)

					info = UIDropDownMenu_CreateInfo()
					info.text = L["Current"]
					info.func = function()
						window:set_selected_set("current")
						Skada:Wipe()
						Skada:UpdateDisplay(true)
					end
					info.checked = (window.selectedset == "current")
					UIDropDownMenu_AddButton(info, level)

					for i, set in Skada:IterateSets() do
						info = UIDropDownMenu_CreateInfo()
						info.text = Skada:GetSetLabel(set)
						info.func = function()
							window:set_selected_set(i)
							Skada:Wipe()
							Skada:UpdateDisplay(true)
						end
						info.colorCode = set.gotboss and (set.success and "|cff00ff00" or "|cffff0000") or "|cffffffff"
						info.checked = (window.selectedset == set.starttime)
						UIDropDownMenu_AddButton(info, level)
					end

					UIDropDownMenu_AddSeparator(info, level)
				end

				-- window
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Window"]
				info.isTitle = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				-- lock window
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Lock Window"]
				info.func = function()
					window.db.barslocked = not window.db.barslocked
					Skada:ApplySettings()
				end
				info.checked = window.db.barslocked
				info.isNotRadio = 1
				UIDropDownMenu_AddButton(info, level)

				-- hide window
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Hide Window"]
				info.func = function()
					if window:IsShown() then
						window.db.hidden = true
						window:Hide()
					else
						window.db.hidden = false
						window:Show()
					end
					Skada:ApplySettings()
				end
				info.checked = not window:IsShown()
				info.isNotRadio = 1
				UIDropDownMenu_AddButton(info, level)

				-- snap window
				if window.db.display == "bar" then
					info = UIDropDownMenu_CreateInfo()
					info.text = L["Sticky Window"]
					info.func = function()
						window.db.sticky = not window.db.sticky
						if not window.db.sticky then
							for _, win in Skada:IterateWindows() do
								if win.db.sticked[window.db.name] then
									win.db.sticked[window.db.name] = nil
								end
							end
						end
						Skada:ApplySettings()
					end
					info.checked = window.db.sticky
					info.isNotRadio = 1
					UIDropDownMenu_AddButton(info, level)
				end

				-- clamped to screen
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Clamped To Screen"]
				info.func = function()
					window.db.clamped = not window.db.clamped
					Skada:ApplySettings()
				end
				info.checked = window.db.clamped
				info.isNotRadio = 1
				UIDropDownMenu_AddButton(info, level)

				UIDropDownMenu_AddSeparator(info, level)

				-- window
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Options"]
				info.isTitle = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Always show self"]
				info.func = function()
					window.db.showself = not window.db.showself
					Skada:ApplySettings()
				end
				info.checked = (window.db.showself == true)
				info.isNotRadio = 1
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Include set"]
				info.func = function()
					window.db.titleset = not window.db.titleset
					Skada:ApplySettings()
				end
				info.checked = (window.db.titleset == true)
				info.isNotRadio = 1
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Encounter timer"]
				info.func = function()
					window.db.combattimer = not window.db.combattimer
					Skada:ApplySettings()
				end
				info.checked = (window.db.combattimer == true)
				info.isNotRadio = 1
				UIDropDownMenu_AddButton(info, level)

				UIDropDownMenu_AddSeparator(info, level)

				-- delete window
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Delete Window"]
				info.func = function()
					return Skada:DeleteWindow(window.db.name)
				end
				info.notCheckable = 1
				info.leftPadding = 16
				info.colorCode = "|cffeb4c34"
				UIDropDownMenu_AddButton(info, level)
			elseif L_UIDROPDOWNMENU_MENU_VALUE == "segment" then
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Total"]
				info.func = function()
					window:set_selected_set("total")
					Skada:Wipe()
					Skada:UpdateDisplay(true)
				end
				info.checked = (window.selectedset == "total")
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Current"]
				info.func = function()
					window:set_selected_set("current")
					Skada:Wipe()
					Skada:UpdateDisplay(true)
				end
				info.checked = (window.selectedset == "current")
				UIDropDownMenu_AddButton(info, level)

				local sets = Skada:GetSets()
				if #sets > 0 then
					UIDropDownMenu_AddSeparator(info, level)

					for i, set in ipairs(sets) do
						info = UIDropDownMenu_CreateInfo()
						info.text = Skada:GetSetLabel(set)
						info.func = function()
							window:set_selected_set(i)
							Skada:Wipe()
							Skada:UpdateDisplay(true)
						end
						info.checked = (window.selectedset == i)
						info.colorCode = set.gotboss and (set.success and "|cff00ff00" or "|cffff0000") or "|cffffffff"
						UIDropDownMenu_AddButton(info, level)
					end
				end
			elseif L_UIDROPDOWNMENU_MENU_VALUE == "delete" then
				for i, set in Skada:IterateSets() do
					info = UIDropDownMenu_CreateInfo()
					info.text = Skada:GetSetLabel(set)
					info.func = function()
						Skada:DeleteSet(set, i)
					end
					info.notCheckable = 1
					info.colorCode = set.gotboss and (set.success and "|cff00ff00" or "|cffff0000") or "|cffffffff"
					UIDropDownMenu_AddButton(info, level)
				end
			elseif L_UIDROPDOWNMENU_MENU_VALUE == "keep" then
				local num, kept = 0, 0

				for _, set in Skada:IterateSets() do
					num = num + 1
					if set.keep then
						kept = kept + 1
					end

					info = UIDropDownMenu_CreateInfo()
					info.text = Skada:GetSetLabel(set)
					info.func = function()
						set.keep = not set.keep
						window:UpdateDisplay()
					end
					info.checked = set.keep
					info.isNotRadio = 1
					info.keepShownOnClick = true
					info.colorCode = set.gotboss and (set.success and "|cff00ff00" or "|cffff0000") or "|cffffffff"
					UIDropDownMenu_AddButton(info, level)
				end

				if num > 0 then
					UIDropDownMenu_AddSeparator(info, level)

					info = UIDropDownMenu_CreateInfo()
					info.text = L["Select All"]
					info.func = function()
						for _, s in Skada:IterateSets() do
							s.keep = true
						end
					end
					info.notCheckable = 1
					info.leftPadding = 16
					info.disabled = (num == kept)
					UIDropDownMenu_AddButton(info, level)

					info = UIDropDownMenu_CreateInfo()
					info.text = L["Deselect All"]
					info.func = function()
						for _, s in Skada:IterateSets() do
							s.keep = nil
						end
					end
					info.notCheckable = 1
					info.leftPadding = 16
					info.disabled = (kept == 0)
					UIDropDownMenu_AddButton(info, level)
				end
			elseif L_UIDROPDOWNMENU_MENU_VALUE == "shortcut" then
				-- time measure
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Time measure"]
				info.isTitle = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Activity time"]
				info.func = function()
					Skada.db.profile.timemesure = 1
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.timemesure == 1)
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Effective time"]
				info.func = function()
					Skada.db.profile.timemesure = 2
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.timemesure == 2)
				UIDropDownMenu_AddButton(info, level)

				UIDropDownMenu_AddSeparator(info, level)

				-- number format
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Number format"]
				info.isTitle = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Condensed"]
				info.func = function()
					Skada.db.profile.numberformat = 1
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.numberformat == 1)
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Comma"]
				info.func = function()
					Skada.db.profile.numberformat = 2
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.numberformat == 2)
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Detailed"]
				info.func = function()
					Skada.db.profile.numberformat = 3
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.numberformat == 3)
				UIDropDownMenu_AddButton(info, level)

				UIDropDownMenu_AddSeparator(info, level)

				-- number format
				info = UIDropDownMenu_CreateInfo()
				info.text = OTHER
				info.isTitle = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Show totals"]
				info.func = function()
					Skada.db.profile.showtotals = not Skada.db.profile.showtotals
					Skada:ReloadSettings()
				end
				info.checked = (Skada.db.profile.showtotals == true)
				info.isNotRadio = 1
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Show rank numbers"]
				info.func = function()
					Skada.db.profile.showranks = not Skada.db.profile.showranks
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.showranks == true)
				info.isNotRadio = 1
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Always show self"]
				info.func = function()
					Skada.db.profile.showself = not Skada.db.profile.showself
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.showself == true)
				info.isNotRadio = 1
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Aggressive combat detection"]
				info.func = function()
					Skada.db.profile.tentativecombatstart = not Skada.db.profile.tentativecombatstart
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.tentativecombatstart == true)
				info.isNotRadio = 1
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Include Absorbed Damage"]
				info.func = function()
					Skada.db.profile.absdamage = not Skada.db.profile.absdamage
					Skada:ApplySettings()
				end
				info.checked = (Skada.db.profile.absdamage == true)
				info.isNotRadio = 1
				UIDropDownMenu_AddButton(info, level)
			end
		elseif level == 3 then
			if L_UIDROPDOWNMENU_MENU_VALUE == "modes" then
				for _, mode in Skada:IterateModes() do
					info = UIDropDownMenu_CreateInfo()
					info.text = mode:GetName()
					info.checked = (Skada.db.profile.report.mode == mode:GetName())
					info.func = function()
						Skada.db.profile.report.mode = mode:GetName()
					end
					UIDropDownMenu_AddButton(info, level)
				end
			elseif L_UIDROPDOWNMENU_MENU_VALUE == "segment" then
				info = UIDropDownMenu_CreateInfo()
				info.text = L["Total"]
				info.func = function()
					Skada.db.profile.report.set = "total"
				end
				info.checked = (Skada.db.profile.report.set == "total")
				UIDropDownMenu_AddButton(info, level)

				info = UIDropDownMenu_CreateInfo()
				info.text = L["Current"]
				info.func = function()
					Skada.db.profile.report.set = "current"
				end
				info.checked = (Skada.db.profile.report.set == "current")
				UIDropDownMenu_AddButton(info, level)

				for i, set in Skada:IterateSets() do
					info = UIDropDownMenu_CreateInfo()
					info.text = Skada:GetSetLabel(set)
					info.func = function()
						Skada.db.profile.report.set = i
					end
					info.checked = (Skada.db.profile.report.set == i)
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end
	end

	local x, y
	self.skadamenu.point, x, y = getDropdownPoint()
	ToggleDropDownMenu(1, nil, self.skadamenu, "UIParent", x, y)
end

function Skada:SegmentMenu(window)
	self.segmentsmenu = self.segmentsmenu or CreateFrame("Frame", "SkadaWindowButtonsSegments", UIParent, "UIDropDownMenuTemplate")
	self.segmentsmenu.displayMode = "MENU"
	self.segmentsmenu.initialize = function(self, level)
		if not level then return
		end
		local info

		info = UIDropDownMenu_CreateInfo()
		info.text = L["Total"]
		info.func = function()
			window:set_selected_set("total")
			Skada:Wipe()
			Skada:UpdateDisplay(true)
		end
		info.checked = (window.selectedset == "total")
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.text = L["Current"]
		info.func = function()
			window:set_selected_set("current")
			Skada:Wipe()
			Skada:UpdateDisplay(true)
		end
		info.checked = (window.selectedset == "current")
		UIDropDownMenu_AddButton(info, level)

		local sets = Skada:GetSets()
		if #sets > 0 then
			UIDropDownMenu_AddSeparator(info, level)

			for i, set in ipairs(sets) do
				info = UIDropDownMenu_CreateInfo()
				info.text = Skada:GetSetLabel(set)
				info.func = function()
					window:set_selected_set(i)
					Skada:Wipe()
					Skada:UpdateDisplay(true)
				end
				info.checked = (window.selectedset == i)
				if set.gotboss then
					info.colorCode = set.success and "|cff00ff00" or "|cffff0000"
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end

	local x, y
	self.segmentsmenu.point, x, y = getDropdownPoint()
	ToggleDropDownMenu(1, nil, self.segmentsmenu, "UIParent", x, y)
end

do
	local categorized, categories

	local function sort_categories(a, b)
		local a_score = (a == OTHER) and 1000 or 0
		local b_score = (b == OTHER) and 1000 or 0
		a_score = a_score + (sbyte(a, 1) * 10) + sbyte(a, 1)
		b_score = b_score + (sbyte(b, 1) * 10) + sbyte(b, 1)
		return a_score < b_score
	end

	function Skada:ModeMenu(win)
		self.modesmenu = self.modesmenu or CreateFrame("Frame", "SkadaWindowButtonsModes", UIParent, "UIDropDownMenuTemplate")

		-- so we call it only once.
		if categorized == nil then
			categories, categorized = {}, {}
			for _, mode in Skada:IterateModes() do
				categorized[mode.category] = categorized[mode.category] or {}
				tinsert(categorized[mode.category], mode)
				if not tContains(categories, mode.category) then
					tinsert(categories, mode.category)
				end
			end
			tsort(categories, sort_categories)
		end

		self.modesmenu.displayMode = "MENU"
		self.modesmenu.initialize = function(self, level)
			if not level then return end
			local info

			if level == 1 then
				for _, category in ipairs(categories) do
					info = UIDropDownMenu_CreateInfo()
					info.text = category
					info.value = category
					info.hasArrow = 1
					info.notCheckable = 1
					info.padding = 16
					if win and win.selectedmode and (win.selectedmode.category == category or (win.parentmode and win.parentmode.category == category)) then
						info.colorCode = "|cffffd100"
					end
					UIDropDownMenu_AddButton(info, level)
				end
			elseif level == 2 and categorized[L_UIDROPDOWNMENU_MENU_VALUE] then
				for _, mode in ipairs(categorized[L_UIDROPDOWNMENU_MENU_VALUE]) do
					info = UIDropDownMenu_CreateInfo()
					info.text = mode:GetName()
					info.func = function()
						win:DisplayMode(mode)
						CloseDropDownMenus()
					end

					if win and win.selectedmode and (win.selectedmode == mode or win.parentmode == mode) then
						info.checked = 1
						info.colorCode = "|cffffd100"
					end

					Skada.callbacks:Fire("SKADA_MODE_MENU", info, mode)
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end

		local x, y
		self.modesmenu.point, x, y = getDropdownPoint()
		ToggleDropDownMenu(1, nil, self.modesmenu, "UIParent", x, y)
	end
end

do
	local function destroywindow()
		if Skada.reportwindow then
			-- remove AceGUI hacks before recycling the widget
			local frame = Skada.reportwindow
			frame.LayoutFinished = frame.orig_LayoutFinished
			frame.frame:SetScript("OnKeyDown", nil)
			frame.frame:EnableKeyboard(false)
			frame:ReleaseChildren()
			frame:Release()
		end
		Skada.reportwindow = nil
	end

	local function createReportWindow(window)
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

		frame:SetCallback("OnClose", function(widget, callback) destroywindow() end)

		-- make the frame closable with Escape button
		_G.SkadaReportWindow = frame.frame
		tinsert(UISpecialFrames, "SkadaReportWindow")

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
				linebox:SetList({[""] = NONE})
				for _, bar in ipairs(window.dataset) do
					if bar.id and not bar.ignore then
						linebox:AddItem(bar.id, format("%s   %s", bar.text or bar.label, bar.valuetext))
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
			for _, mode in Skada:IterateModes() do
				modebox:AddItem(mode:GetName(), mode:GetName())
			end
			modebox:SetCallback("OnValueChanged", function(f, e, value) Skada.db.profile.report.mode = value end)
			modebox:SetValue(Skada.db.profile.report.mode or Skada:GetModes()[1])
			frame:AddChild(modebox)

			-- Segment, default last chosen or last set.
			local setbox = AceGUI:Create("Dropdown")
			setbox:SetLabel(L["Segment"])
			setbox:SetList({total = L["Total"], current = L["Current"]})
			for i, set in Skada:IterateSets() do
				setbox:AddItem(i, set.name)
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
				local pos = {frame:GetPoint()}
				destroywindow()
				createReportWindow(window)
				Skada.reportwindow:SetPoint(unpack(pos))
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
			local mode, set, channel, chantype, number =
				Skada.db.profile.report.mode,
				Skada.db.profile.report.set,
				Skada.db.profile.report.channel,
				Skada.db.profile.report.chantype,
				Skada.db.profile.report.number

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
				frame:Hide()
			else
				Skada:Print("Error: Whisper target not found")
			end
		end)

		report:SetFullWidth(true)
		frame:AddChild(report)
	end

	function Skada:OpenReportWindow(window)
		if self.reportwindow == nil then
			createReportWindow(window)
		elseif self.reportwindow:IsShown() then
			self.reportwindow:Hide()
		else
			self.reportwindow:Show()
		end
	end
end