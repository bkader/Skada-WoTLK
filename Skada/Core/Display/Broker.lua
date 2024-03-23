local folder, Skada = ...
local Private = Skada.Private
Skada:RegisterDisplay("Data Text", "mod_broker_desc", function(L, P)
	local mod = Skada:NewModule("Data Text", Skada.displayPrototype)
	local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

	mod.SetTitle = Skada.EmptyFunc

	local wipe, tsort, format = wipe, table.sort, string.format
	local GameTooltip = GameTooltip
	local GameTooltip_Hide = GameTooltip_Hide
	local SavePosition = Private.SavePosition
	local RestorePosition = Private.RestorePosition
	local WrapTextInColorCode = Private.WrapTextInColorCode
	local RGBPercToHex = Private.RGBPercToHex
	local classcolors = Skada.classcolors

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
			return a.label > b.label
		end
	end

	local function sortDataset(win)
		tsort(win.dataset, sortFunc)
		return win.dataset
	end

	local function formatLabel(win, data)
		if win.db.isusingclasscolors and data.class then
			return classcolors.format(data.class, data.text or data.label or L["Unknown"])
		elseif data.color and data.color.colorStr then
			return format("\124c%s%s\124r", data.color.colorStr, data.text or data.label or L["Unknown"])
		elseif data.color then
			return WrapTextInColorCode(data.text or data.label or L["Unknown"], RGBPercToHex(data.color.r or 1, data.color.g or 1, data.color.b or 1, true))
		else
			return data.text or data.label or L["Unknown"]
		end
	end

	local function formatValue(win, data)
		return data.valuetext
	end

	local function clickHandler(win, frame, button)
		if not win.obj then return end

		if button == "LeftButton" and IsShiftKeyDown() then
			Skada:OpenMenu(win)
		elseif button == "LeftButton" then
			Skada:ModeMenu(win, frame)
		elseif button == "RightButton" then
			Skada:SegmentMenu(win)
		end
	end

	local function tooltipHandler(win, tooltip)
		if win.db.useframe then
			Skada:SetTooltipPosition(tooltip, win.frame, "broker", win)
		end

		-- Default color.
		local color = win.db.textcolor or {r = 1, g = 1, b = 1}

		tooltip:AddLine(win.metadata.title)

		local dataset = sortDataset(win)
		if #dataset > 0 then
			tooltip:AddLine(" ")
			local n = 0 -- used to fix spots starting from 2
			for i = 1, #dataset do
				local data = dataset[i]
				if data and data.id and not data.ignore and i < 30 then
					n = n + 1
					local label = formatLabel(win, data)
					local value = formatValue(win, data)

					if win.metadata.showspots and P.showranks then
						label = format("%s. %s", n, label)
					end

					tooltip:AddDoubleLine(label or "", value or "", color.r, color.g, color.b, color.r, color.g, color.b)
				elseif i >= 30 then
					break
				end
			end
		end

		tooltip:AddLine(" ")
		tooltip:AddLine(L["Hint: Left-Click to set active mode."], 0, 1, 0)
		tooltip:AddLine(L["Right-Click to set active set."], 0, 1, 0)
		tooltip:AddLine(L["Shift+Left-Click to open menu."], 0, 1, 0)

		tooltip:Show()
	end

	local ttactive = false

	function mod:Create(win, isnew)
		local p = win.db
		local frame = win.frame

		-- Optional internal frame
		if not frame then
			frame = CreateFrame("Frame", format("%sBrokerWindow%s", folder, p.name), UIParent)
			frame:SetHeight(p.height or 30)
			frame:SetWidth(p.width or 200)
			frame:SetPoint("CENTER", 0, 0)

			local title = frame:CreateFontString("frameTitle", "OVERLAY")
			title:SetPoint("CENTER", 0, 0)
			frame.title = title

			frame:EnableMouse(true)
			frame:SetMovable(true)
			frame:RegisterForDrag("LeftButton")
			frame:SetScript("OnMouseUp", function(frame, button) clickHandler(win, frame, button) end)
			frame:SetScript("OnEnter", function(frame) tooltipHandler(win, GameTooltip) end)
			frame:SetScript("OnLeave", GameTooltip_Hide)
			frame:SetScript("OnDragStart", function(self)
				if not p.barslocked then
					GameTooltip:Hide()
					self.isDragging = true
					self:StartMoving()
				end
			end)
			frame:SetScript("OnDragStop", function(self)
				self:StopMovingOrSizing()
				self.isDragging = false
				SavePosition(self, p)
			end)
		end

		-- Restore window position.
		if isnew then
			SavePosition(frame, p)
		else
			RestorePosition(frame, p)
		end

		win.frame = frame

		-- LDB object
		if not win.obj then
			win.obj = LDB:NewDataObject(format("%s: %s", folder, p.name), {
				type = "data source",
				text = "",
				OnTooltipShow = function(tooltip) tooltipHandler(win, tooltip) end,
				OnClick = function(frame, button) clickHandler(win, frame, button) end
			})
		end

		mod:ApplySettings(win)
	end

	function mod:Update(win)
		if win.obj then
			win.obj.text = ""
		end

		local dataset = sortDataset(win)
		local data = (#dataset > 0) and dataset[1]
		if not data or not data.id then return end

		local label = format("%s - %s", formatLabel(win, data) or "", formatValue(win, data) or "")

		if win.obj then
			win.obj.text = label
		end
		if win.db.useframe then
			win.frame.title:SetText(label)
		end
	end

	local fbackdrop = {}
	function mod:ApplySettings(win)
		if win.db.useframe then
			local title = win.frame.title
			local db = win.db

			win.frame:SetMovable(not db.barslocked)
			win.frame:SetHeight(db.height or 30)
			win.frame:SetWidth(db.width or 200)
			win.frame:SetScale(db.scale)
			win.frame:SetFrameStrata(db.strata)

			wipe(fbackdrop)
			fbackdrop.bgFile = Skada:MediaFetch("background", db.background.texture)
			fbackdrop.tile = db.background.tile
			fbackdrop.tileSize = db.background.tilesize
			win.frame:SetBackdrop(fbackdrop)
			win.frame:SetBackdropColor(db.background.color.r, db.background.color.g, db.background.color.b, db.background.color.a)

			Skada:ApplyBorder(win.frame, db.background.bordertexture, db.background.bordercolor, db.background.borderthickness, db.background.borderinsets)

			local color = db.textcolor or {r = 1, g = 1, b = 1, a = 1}
			title:SetTextColor(color.r, color.g, color.b, color.a)
			title:SetFont(Skada:MediaFetch("font", db.barfont), db.barfontsize, db.barfontflags)
			title:SetWordWrap(false)
			title:SetJustifyH("CENTER")
			title:SetJustifyV("MIDDLE")
			title:SetHeight(db.height or 30)
			title:SetText(win.metadata.title or folder)

			-- restore position
			RestorePosition(win.frame, db)

			if db.hidden and win.frame:IsShown() then
				win.frame:Hide()
			elseif not db.hidden and not win.frame:IsShown() then
				win.frame:Show()
			end
		else
			win.frame:Hide()
		end

		self:Update(win)
	end

	function mod:AddDisplayOptions(win, options)
		local db = win.db

		options.main = {
			type = "group",
			name = L["Data Text"],
			desc = format(L["Options for %s."], L["Data Text"]),
			order = 10,
			get = function(i)
				return db[i[#i]]
			end,
			set = function(i, val)
				db[i[#i]] = val
				Skada:ApplySettings(db.name)
			end,
			args = {
				useframe = {
					type = "toggle",
					name = L["Use frame"],
					desc = L["opt_useframe_desc"],
					order = 10,
					width = "double"
				},
				barfont = {
					type = "select",
					dialogControl = "LSM30_Font",
					name = L["Font"],
					desc = format(L["The font used by %s."], L["Bars"]),
					values = Skada:MediaList("font"),
					order = 20
				},
				barfontflags = {
					type = "select",
					name = L["Font Outline"],
					desc = L["Sets the font outline."],
					values = FONT_FLAGS,
					order = 30
				},
				barfontsize = {
					type = "range",
					name = L["Font Size"],
					desc = format(L["The font size of %s."], L["Bars"]),
					min = 5,
					max = 32,
					step = 1,
					order = 40,
					width = "double"
				},
				color = {
					type = "color",
					name = L["Text Color"],
					desc = L["Choose the default color."],
					hasAlpha = true,
					get = function()
						local c = db.textcolor or Skada.windowdefaults.textcolor
						return c.r, c.g, c.b, c.a or 1
					end,
					set = function(i, r, g, b, a)
						db.textcolor = db.textcolor or {}
						db.textcolor.r, db.textcolor.g, db.textcolor.b, db.textcolor.a = r, g, b, a
						Skada:ApplySettings(db.name)
					end,
					disabled = function() return db.isusingclasscolors end,
					order = 50,
				},
				isusingclasscolors = {
					type = "toggle",
					name = L["Class Colors"],
					desc = L["When possible, bar text will be colored according to player class."],
					order = 60
				},
			}
		}

		options.windowoptions = Private.FrameOptions(db, true)
	end

	function mod:OnInitialize()
		classcolors = classcolors or Skada.classcolors
		self.description = L["mod_broker_desc"]
		Skada:AddDisplaySystem("broker", self)
	end
end)
