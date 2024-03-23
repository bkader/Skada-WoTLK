local folder, Skada = ...
local Private = Skada.Private
Skada:RegisterDisplay("Legacy Bar Display", "mod_bar_desc", function(L, P)

	-- common stuff
	local pairs, type, tsort, format = pairs, type, table.sort, string.format
	local lib = {} -- LegacyLibBars-1.0
	local _

	----------------------------------------------------------------
	-- LegacyLibBars-1.0 -- stripped down to minimum
	----------------------------------------------------------------
	do
		local GetTime = GetTime
		local cos, abs, min, max, floor = math.cos, math.abs, math.min, math.max, math.floor
		local wipe, tremove, tconcat = wipe, tremove, table.concat
		local next, error = next, error

		local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")
		lib.callbacks = lib.callbacks or CallbackHandler:New(lib)
		local callbacks = lib.callbacks

		local dummyFrame, barPrototype, barPrototype_mt, barListPrototype
		local barListPrototype_mt

		lib.dummyFrame = lib.dummyFrame or CreateFrame("Frame")
		lib.barFrameMT = lib.barFrameMT or {__index = lib.dummyFrame}
		lib.barPrototype = lib.barPrototype or setmetatable({}, lib.barFrameMT)
		lib.barPrototype_mt = lib.barPrototype_mt or {__index = lib.barPrototype}
		lib.barListPrototype = lib.barListPrototype or setmetatable({}, lib.barFrameMT)
		lib.barListPrototype_mt = lib.barListPrototype_mt or {__index = lib.barListPrototype}

		dummyFrame = lib.dummyFrame
		barPrototype = lib.barPrototype
		barPrototype_mt = lib.barPrototype_mt
		barListPrototype = lib.barListPrototype
		barListPrototype_mt = lib.barListPrototype_mt

		barPrototype.prototype = barPrototype
		barPrototype.metatable = barPrototype_mt
		barPrototype.super = dummyFrame

		barListPrototype.prototype = barListPrototype
		barListPrototype.metatable = barListPrototype_mt
		barListPrototype.super = dummyFrame

		lib.bars = lib.bars or {}
		lib.barLists = lib.barLists or {}
		lib.recycledBars = lib.recycledBars or {}
		lib.embeds = lib.embeds or {}
		local bars = lib.bars
		local barLists = lib.barLists
		local recycledBars = lib.recycledBars

		local frame_defaults = {
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			inset = 4,
			edgeSize = 8,
			tile = true,
			insets = {left = 2, right = 2, top = 2, bottom = 2}
		}
		local CONFIG_ICON = format([[%s\Textures\toolbar1\config]], Skada.mediapath)

		function lib:GetBar(name)
			return bars[self] and bars[self][name]
		end

		function lib:GetBars(name)
			return bars[self]
		end

		function lib:NewBarFromPrototype(prototype, name, ...)
			if self == lib then
				error("You may only call :NewBar as an embedded function")
			end
			if type(prototype) ~= "table" or type(prototype.metatable) ~= "table" then
				error("Invalid bar prototype")
			end

			bars[self] = bars[self] or {}
			local bar = bars[self][name]
			local isNew = false
			if not bar then
				isNew = true
				bar = tremove(recycledBars)
				if not bar then
					bar = CreateFrame("Frame")
				else
					bar:Show()
				end
			end
			bar = setmetatable(bar, prototype.metatable)
			bar.name = name
			bar:Create(...)
			bar:SetFont(self.font, self.fontSize, self.fontFlags)

			bars[self][name] = bar

			return bar, isNew
		end

		function lib:NewCounterBar(name, text, value, maxVal, icon, orientation, length, thickness, isTimer)
			return self:NewBarFromPrototype(barPrototype, name, text, value, maxVal, icon, orientation, length, thickness, isTimer)
		end

		function lib:ReleaseBar(name)
			if not bars[self] then return end

			local bar
			if type(name) == "string" then
				bar = bars[self][name]
			elseif type(name) == "table" then
				if name.name and bars[self][name.name] == name then
					bar = name
				end
			end

			if bar then
				bar:OnBarReleased()
				bars[self][bar.name] = nil
				recycledBars[#recycledBars + 1] = bar
			end
		end

		do
			local function move(self)
				local p = self:GetParent()
				if p and not p.locked then
					self.startX = p:GetLeft()
					self.startY = p:GetTop()
					p:StartMoving()
				end
			end
			local function stopMove(self)
				local p = self:GetParent()
				if p and not p.locked then
					p:StopMovingOrSizing()
					local endX = p:GetLeft()
					local endY = p:GetTop()
					if self.startX ~= endX or self.startY ~= endY then
						callbacks:Fire("AnchorMoved", p, endX, endY)
					end
				end
			end
			local function buttonClick(self, button)
				callbacks:Fire("AnchorClicked", self:GetParent(), button)
			end
			local function configClick(self, button)
				callbacks:Fire("ConfigClicked", self:GetParent(), button)
			end

			local DEFAULT_TEXTURE = [[Interface\TARGETINGFRAME\UI-StatusBar]]
			function lib:NewBarGroup(name, orientation, length, thickness, frameName)
				if self == lib then
					error("You may only call :NewBarGroup as an embedded function")
				end

				barLists[self] = barLists[self] or {}
				if barLists[self][name] then
					error(format("A bar list named %s already exists.", name))
				end

				orientation = orientation or 1
				orientation = orientation == "LEFT" and 1 or orientation
				orientation = orientation == "RIGHT" and 2 or orientation

				local list = setmetatable(CreateFrame("Frame", frameName, UIParent), barListPrototype_mt)
				list:SetMovable(true)
				list:SetClampedToScreen(true)

				barLists[self][name] = list
				list.name = name

				local myfont = lib.defaultFont or _G["SkadaRevTitleFont"]
				if not myfont then
					myfont = CreateFont("SkadaRevTitleFont")
					myfont:CopyFontObject(ChatFontSmall)
					lib.defaultFont = myfont
				end

				list.button = CreateFrame("Button", nil, list)
				list.button:SetBackdrop(frame_defaults)
				list.button:SetText(name)
				list.button:SetNormalFontObject(myfont)
				list.button.text = list.button:GetFontString(nil, "ARTWORK")
				list.button.text:SetWordWrap(false)
				list.button.text:SetAllPoints(true)

				list.length = length or 200
				list.thickness = thickness or 15
				list:SetOrientation(orientation)

				list:UpdateOrientationLayout()

				list.button:SetScript("OnMouseDown", move)
				list.button:SetScript("OnMouseUp", stopMove)
				list.button:SetBackdropColor(0, 0, 0, 1)
				list.button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
				list.button:SetScript("OnClick", buttonClick)

				list.optbutton = CreateFrame("Button", nil, list)
				list.optbutton:SetFrameLevel(10)
				list.optbutton:ClearAllPoints()
				list.optbutton:SetHeight(16)
				list.optbutton:SetWidth(16)
				list.optbutton:SetNormalTexture(CONFIG_ICON)
				list.optbutton:SetHighlightTexture(CONFIG_ICON, "ADD")
				list.optbutton:SetAlpha(0.3)
				list.optbutton:SetPoint("TOPRIGHT", list.button, "TOPRIGHT", -5, 0 - (max(list.button:GetHeight() - list.optbutton:GetHeight(), 2) / 2))
				list.optbutton:Show()
				list.optbutton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				list.optbutton:SetScript("OnClick", configClick)

				list:SetPoint("TOPLEFT", UIParent, "CENTER")
				list:ReverseGrowth(false)

				list.showIcon = true
				list.showLabel = true
				list.showTimerLabel = true

				list.lastBar = list
				list.locked = false

				list.texture = DEFAULT_TEXTURE
				list.spacing = 0
				list.offset = 0

				return list
			end
		end

		function lib:GetBarGroup(name)
			return barLists[self] and barLists[self][name]
		end

		function barListPrototype:NewBarFromPrototype(prototype, ...)
			local bar, isNew = lib.NewBarFromPrototype(self, prototype, ...)
			bar:SetTexture(self.texture)
			bar:SetFill(self.fill)

			if self.showIcon then
				bar:ShowIcon()
			else
				bar:HideIcon(bar)
			end
			if self.showLabel then
				bar:ShowLabel()
			else
				bar:HideLabel(bar)
			end
			if self.showTimerLabel then
				bar:ShowTimerLabel()
			else
				bar:HideTimerLabel(bar)
			end
			self:SortBars()
			bar.ownerGroup = self
			bar:SetParent(self)
			return bar, isNew
		end

		barListPrototype.SetWidth = barListPrototype.SetLength
		barListPrototype.SetHeight = barListPrototype.SetThickness

		function barListPrototype:NewCounterBar(name, text, value, maxVal, icon, isTimer)
			return self:NewBarFromPrototype(barPrototype, name, text, value, maxVal, icon, self.orientation, self.length, self.thickness, isTimer)
		end

		function barListPrototype:SetLocked(lock)
			if lock then
				self:Lock()
			else
				self:Unlock()
			end
		end

		function barListPrototype:Lock()
			self.locked = true
		end

		function barListPrototype:Unlock()
			self.locked = false
		end

		-- Max number of bars to display. nil to display all.
		function barListPrototype:SetMaxBars(num)
			self.maxBars = num
		end

		function barListPrototype:SetTexture(tex)
			self.texture = tex
			if not bars[self] then return end
			for k, v in pairs(bars[self]) do
				v:SetTexture(tex)
			end
		end

		function barListPrototype:SetFont(f, s, m)
			self.font, self.fontSize, self.fontFlags = f, s, m
			if not bars[self] then return end
			for k, v in pairs(bars[self]) do
				v:SetFont(f, s, m)
			end
		end

		function barListPrototype:SetFill(fill)
			self.fill = fill
			if not bars[self] then return end
			for k, v in pairs(bars[self]) do
				v:SetFill(fill)
			end
		end

		function barListPrototype:ShowIcon()
			self.showIcon = true
			if not bars[self] then return end
			for name, bar in pairs(bars[self]) do
				bar:ShowIcon()
			end
		end

		function barListPrototype:HideIcon()
			self.showIcon = false
			if not bars[self] then return end
			for name, bar in pairs(bars[self]) do
				bar:HideIcon()
			end
		end

		function barListPrototype:ShowLabel()
			self.showLabel = true
			for name, bar in pairs(bars[self]) do
				bar:ShowLabel()
			end
		end

		function barListPrototype:HideLabel()
			self.showLabel = false
			for name, bar in pairs(bars[self]) do
				bar:HideLabel()
			end
		end

		function barListPrototype:ShowTimerLabel()
			self.showTimerLabel = true
			for name, bar in pairs(bars[self]) do
				bar:ShowTimerLabel()
			end
		end

		function barListPrototype:HideTimerLabel()
			self.showTimerLabel = false
			for name, bar in pairs(bars[self]) do
				bar:HideTimerLabel()
			end
		end

		function barListPrototype:SetSpacing(spacing)
			self.spacing = spacing
			self:SortBars()
		end

		barListPrototype.GetBar = lib.GetBar
		barListPrototype.GetBars = lib.GetBars

		function barListPrototype:RemoveBar(bar)
			lib.ReleaseBar(self, bar)
		end

		function barListPrototype:SetDisplayMax(val)
			self.displayMax = val
		end

		function barListPrototype:SetColor(r, g, b, a)
			self.colors = self.colors or {}
			self.colors[1] = r
			self.colors[2] = g
			self.colors[3] = b
			self.colors[4] = a
			self:UpdateColors()
		end

		function barListPrototype:UnsetColor()
			if not self.colors then return end
			wipe(self.colors)
		end
		barListPrototype.UnsetAllColors = barListPrototype.UnsetColor

		function barListPrototype:UpdateColors()
			if not bars[self] then return end
			for k, v in pairs(bars[self]) do
				v:UpdateColor()
			end
		end

		function barListPrototype:TimerFinished(evt, bar, name)
			callbacks:Fire("TimerFinished", bar.ownerGroup, bar, name)
		end

		function barListPrototype:ShowAnchor()
			self.button:Show()
			self:SortBars()
		end

		function barListPrototype:HideAnchor()
			self.button:Hide()
			self:SortBars()
		end

		function barListPrototype:ReverseGrowth(reverse)
			self.growup = reverse
			self.button:ClearAllPoints()
			if reverse then
				self.button:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT")
				self.button:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")
			else
				self.button:SetPoint("TOPLEFT", self, "TOPLEFT")
				self.button:SetPoint("TOPRIGHT", self, "TOPRIGHT")
			end
			self:SortBars()
		end

		function barListPrototype:SetClickthrough(clickthrough)
			if self.clickthrough ~= clickthrough then
				self.clickthrough = clickthrough or nil
				if bars[self] then
					for _, bar in pairs(bars[self]) do
						bar:EnableMouse(not self.clickthrough)
					end
				end
			end
		end

		function barListPrototype:UpdateOrientationLayout()
			local length, thickness = self.length, self.thickness
			barListPrototype.super.SetWidth(self, length)
			barListPrototype.super.SetHeight(self, thickness)
			self.button:SetWidth(length)
			self.button:SetHeight(thickness)

			self.button:SetText(self.name)
			self:ReverseGrowth(self.growup)
		end

		function barListPrototype:SetLength(length)
			self.length = length
			if bars[self] then
				for k, v in pairs(bars[self]) do
					v:SetLength(length)
				end
			end
			self:UpdateOrientationLayout()
		end

		function barListPrototype:GetLength()
			return self.length
		end

		function barListPrototype:SetThickness(thickness)
			self.thickness = thickness
			if bars[self] then
				for k, v in pairs(bars[self]) do
					v:SetThickness(thickness)
				end
			end
			self:UpdateOrientationLayout()
		end

		function barListPrototype:GetThickness()
			return self.thickness
		end

		function barListPrototype:SetOrientation(orientation)
			self.orientation = orientation
			if bars[self] then
				for k, v in pairs(bars[self]) do
					v:SetOrientation(orientation)
				end
			end
			self:UpdateOrientationLayout()
		end

		-- Allows nil sort function.
		function barListPrototype:SetSortFunction(func)
			if func and type(func) ~= "function" then
				error(":SetSortFunction requires a valid function.")
			end
			self.sortFunc = func
		end

		function barListPrototype:SetBarOffset(offset)
			self.offset = offset
			self:SortBars()
		end

		function barListPrototype:SetUseSpark(use)
			self.usespark = use
			if not bars[self] then return end
			for _, bar in pairs(bars[self]) do
				if self.usespark and not bar.spark:IsShown() then
					bar.spark:Show()
				elseif not self.usespark and bar.spark:IsShown() then
					bar.spark:Hide()
				end
			end
		end

		do
			local values = {}
			local function sortFunc(a, b)
				if a.isTimer ~= b.isTimer then
					return a.isTimer
				end

				local apct, bpct = a.value / a.maxValue, b.value / b.maxValue
				if apct == bpct then
					if a.maxValue == b.maxValue then
						return a.name > b.name
					else
						return a.maxValue > b.maxValue
					end
				else
					return apct > bpct
				end
			end
			function barListPrototype:SortBars()
				local lastBar = self.button:IsVisible() and self.button or self
				local ct = 0
				if not bars[self] then return end

				for k, v in pairs(bars[self]) do
					ct = ct + 1
					values[ct] = v
				end
				for i = ct + 1, #values do
					values[i] = nil
				end

				tsort(values, self.sortFunc or sortFunc)

				local orientation = self.orientation
				local growup = self.growup
				local spacing = self.spacing

				local from, to
				local thickness, showIcon = self.thickness, self.showIcon
				local x1, y1, x2, y2 = 0, 0, 0, 0
				if growup then
					from = "BOTTOM"
					to = "TOP"
					y1, y2 = spacing, spacing
				else
					from = "TOP"
					to = "BOTTOM"
					y1, y2 = -spacing, -spacing
				end
				local totalHeight = 0

				local shown = 0
				for i = 1, #values do
					local origTo = to
					local v = values[i]
					if lastBar == self or lastBar == self.button then
						if lastBar == self then
							to = from
						end
						if orientation == 1 then
							x1, x2 = (v.showIcon and thickness or 0), 0
						else
							x1, x2 = 0, (v.showIcon and -thickness or 0)
						end
					else
						x1, x2 = 0, 0
					end

					v:ClearAllPoints()
					if (self.maxBars and shown >= self.maxBars) or (i < self.offset + 1) then
						v:Hide()
					else
						v:Show()
						shown = shown + 1
						totalHeight = totalHeight + v:GetHeight() + y1
						v:SetPoint(format("%sLEFT", from), lastBar, format("%sLEFT", to), x1, y1)
						v:SetPoint(format("%sRIGHT", from), lastBar, format("%sRIGHT", to), x2, y2)
						lastBar = v
					end
					to = origTo
				end
				self.lastBar = lastBar
			end
		end

		-- ****************************************************************
		-- ***	Bar methods
		-- ****************************************************************

		--[[ Bar Prototype ]]
		do
			local function barClick(self, button)
				callbacks:Fire("BarClick", self:GetParent(), button)
			end
			local function barEnter(self, button)
				callbacks:Fire("BarEnter", self:GetParent(), button)
			end
			local function barLeave(self, button)
				callbacks:Fire("BarLeave", self:GetParent(), button)
			end

			local DEFAULT_ICON = [[Interface\ICONS\INV_Misc_QuestionMark]]
			function barPrototype:Create(text, value, maxVal, icon, orientation, length, thickness, isTimer)
				self:SetScript("OnSizeChanged", self.OnSizeChanged)

				self.texture = self.texture or self:CreateTexture(nil, "ARTWORK")

				if self.timeLeftTriggers then
					for k, v in pairs(self.timeLeftTriggers) do
						self.timeLeftTriggers[k] = false
					end
				end

				if not self.spark then
					self.spark = self:CreateTexture(nil, "OVERLAY")
					self.spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
					self.spark:SetWidth(10)
					self.spark:SetHeight(10)
					self.spark:SetBlendMode("ADD")
				end

				self.bgtexture = self.bgtexture or self:CreateTexture(nil, "BACKGROUND")
				self.bgtexture:SetAllPoints()
				self.bgtexture:SetVertexColor(0.3, 0.3, 0.3, 0.6)

				self.icon = self.icon or self:CreateTexture(nil, "OVERLAY")
				self.icon:SetPoint("LEFT", self, "LEFT", 0, 0)
				self:SetIcon(icon or DEFAULT_ICON)
				if icon then
					self:ShowIcon()
				end
				self.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

				self.label = self.label or self:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
				self.label:SetText(text)
				self.label:ClearAllPoints()
				self.label:SetPoint("LEFT", self, "LEFT", 3, 0)
				self:ShowLabel()

				local f, s, m = self.label:GetFont()
				self.label:SetFont(f, s or 10, m)

				self.timerLabel = self.timerLabel or self:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
				self:SetTimerLabel("")
				self.timerLabel:ClearAllPoints()
				self.timerLabel:SetPoint("RIGHT", self, "RIGHT", -6, 0)
				self:HideTimerLabel()

				f, s, m = self.timerLabel:GetFont()
				self.timerLabel:SetFont(f, s or 10, m)

				self.timerFuncs = wipe(self.timerFuncs or {})

				self:SetScale(1)
				self:SetAlpha(1)

				self.length = length or 200
				self.thickness = thickness or 15
				self:SetOrientation(orientation or 1)

				value = value or 1
				maxVal = maxVal or value
				self.value = value
				self.maxValue = maxVal
				self.isTimer = isTimer

				if not isTimer then
					self:SetMaxValue(maxVal)
				else
					self:SetTimer(value, maxVal)
				end
				self:SetValue(value)
			end
		end

		barPrototype.SetWidth = barListPrototype.SetWidth
		barPrototype.SetHeight = barListPrototype.SetHeight

		function barPrototype:OnBarReleased()
			self:StopTimer()

			callbacks:Fire("BarReleased", self, self.name)

			-- Reset our attributes
			self.isTimer = false
			self.ownerGroup = nil
			self.fill = false
			if self.colors then
				wipe(self.colors)
			end
			if self.timeLeftTriggers then
				wipe(self.timeLeftTriggers)
			end

			-- Reset widget
			self.texture:SetVertexColor(1, 1, 1, 0)
			self:SetScript("OnUpdate", nil)
			self:SetParent(UIParent)
			self:ClearAllPoints()
			self:Hide()
			local f, s, m = ChatFontNormal:GetFont()
			self.label:SetFont(f, s or 10, m)
			self.timerLabel:SetFont(f, s or 10, m)
		end

		function barPrototype:GetGroup()
			return self.ownerGroup
		end

		function barPrototype:OnSizeChanged()
			self:SetValue(self.value)
		end

		function barPrototype:SetFont(newFont, newSize, newFlags)
			local t, font, size, flags
			t = self.label
			font, size, flags = t:GetFont()
			t:SetFont(newFont or font, newSize or size, newFlags or flags)

			t = self.timerLabel
			font, size, flags = t:GetFont()
			t:SetFont(newFont or font, newSize or size, newFlags or flags)
		end

		function barPrototype:AddOnUpdate(f)
			self.timerFuncs[#self.timerFuncs + 1] = f
			self:SetScript("OnUpdate", self.OnUpdate)
		end

		function barPrototype:RemoveOnUpdate(f)
			local timerFuncs = self.timerFuncs
			for i = 1, #timerFuncs do
				if f == timerFuncs[i] then
					tremove(timerFuncs, i)
					if #timerFuncs == 0 then
						self:SetScript("OnUpdate", nil)
					end
					return
				end
			end
		end

		function barPrototype.OnUpdate(f, t)
			local timerFuncs = f.timerFuncs
			for i = 1, #timerFuncs do
				local func = timerFuncs[i]
				if func then
					func(f, t)
				end
			end
		end

		function barPrototype:SetIcon(icon, ...)
			if icon then
				self.icon:SetTexture(icon)
				if self.showIcon then
					self.icon:Show()
				end
				if ... then
					self.icon:SetTexCoord(...)
				end
			else
				self.icon:Hide()
			end
			self.iconTexture = icon or nil
		end

		function barPrototype:ShowIcon()
			self.showIcon = true
			if self.iconTexture then
				self.icon:Show()
			end
		end

		function barPrototype:HideIcon()
			self.showIcon = false
			self.icon:Hide()
		end

		function barPrototype:SetLabel(text)
			self.label:SetText(text)
		end

		function barPrototype:GetLabel(text)
			return self.label:GetText(text)
		end

		barPrototype.SetText = barPrototype.SetLabel -- for API compatibility
		barPrototype.GetText = barPrototype.GetLabel -- for API compatibility

		function barPrototype:ShowLabel()
			self.showLabel = true
			self.label:Show()
		end

		function barPrototype:HideLabel()
			self.showLabel = false
			self.label:Hide()
		end

		function barPrototype:SetTimerLabel(text)
			self.timerLabel:SetText(text)
		end

		function barPrototype:GetTimerLabel(text)
			return self.timerLabel:GetText(text)
		end

		function barPrototype:ShowTimerLabel()
			self.showTimerLabel = true
			self.timerLabel:Show()
		end

		function barPrototype:HideTimerLabel()
			self.showTimerLabel = false
			self.timerLabel:Hide()
		end

		function barPrototype:SetTexture(texture)
			self.texture:SetTexture(texture)
			self.bgtexture:SetTexture(texture)
		end

		-- Allows for the setting of background colors for a specific bar
		-- Someday I'll figure out to do it at the group level
		function barPrototype:SetBackgroundColor(r, g, b, a)
			if r and g and b then
				self.bgtexture:SetVertexColor(r, g, b, a or 0.6)
			end
		end

		function barPrototype:SetColor(r, g, b, a)
			self.colors = self.colors or {}
			self.colors[1] = r
			self.colors[2] = g
			self.colors[3] = b
			self.colors[4] = a
			self:UpdateColor()
		end

		function barPrototype:UnsetColor()
			if not self.colors then return end
			wipe(self.colors)
		end
		barPrototype.UnsetAllColors = barPrototype.UnsetColor

		do
			function barPrototype:UpdateOrientationLayout()
				local o = self.orientation
				local t
				if o == 1 then
					self.icon:ClearAllPoints()
					self.icon:SetPoint("RIGHT", self, "LEFT", 0, 0)

					t = self.spark
					t:ClearAllPoints()
					t:SetPoint("TOP", self.texture, "TOPRIGHT", 0, 7)
					t:SetPoint("BOTTOM", self.texture, "BOTTOMRIGHT", 0, -7)
					t:SetTexCoord(0, 1, 0, 1)

					t = self.texture
					t.SetValue = t.SetWidth
					t:ClearAllPoints()
					t:SetPoint("TOPLEFT", self, "TOPLEFT")
					t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT")

					t = self.timerLabel
					t:ClearAllPoints()
					t:SetPoint("RIGHT", self, "RIGHT", -6, 0)
					t:SetJustifyH("RIGHT")
					t:SetJustifyV("MIDDLE")

					t = self.label
					t:ClearAllPoints()
					t:SetPoint("LEFT", self, "LEFT", 6, 0)
					t:SetPoint("RIGHT", self.timerLabel, "LEFT", 0, 0)
					t:SetJustifyH("LEFT")
					t:SetJustifyV("MIDDLE")

					self.bgtexture:SetTexCoord(0, 1, 0, 1)
				elseif o == 2 then
					self.icon:ClearAllPoints()
					self.icon:SetPoint("LEFT", self, "RIGHT", 0, 0)

					t = self.spark
					t:ClearAllPoints()
					t:SetPoint("TOP", self.texture, "TOPLEFT", 0, 7)
					t:SetPoint("BOTTOM", self.texture, "BOTTOMLEFT", 0, -7)
					t:SetTexCoord(0, 1, 0, 1)

					t = self.texture
					t.SetValue = t.SetWidth
					t:ClearAllPoints()
					t:SetPoint("TOPRIGHT", self, "TOPRIGHT")
					t:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")

					t = self.timerLabel
					t:ClearAllPoints()
					t:SetPoint("LEFT", self, "LEFT", 6, 0)
					t:SetJustifyH("LEFT")
					t:SetJustifyV("MIDDLE")

					t = self.label
					t:ClearAllPoints()
					t:SetPoint("RIGHT", self, "RIGHT", -6, 0)
					t:SetPoint("LEFT", self.timerLabel, "RIGHT", 0, 0)
					t:SetJustifyH("RIGHT")
					t:SetJustifyV("MIDDLE")

					self.bgtexture:SetTexCoord(0, 1, 0, 1)
				end
				self:SetValue(self.value or 0)
			end
		end

		function barPrototype:GetLength()
			return self.length
		end

		do
			local function updateSize(self)
				local thickness, length = self.thickness, self.length
				local iconSize = self.showIcon and length or thickness
				local width = max(0.0001, length - iconSize)
				local height = thickness
				barPrototype.super.SetWidth(self, width)
				barPrototype.super.SetHeight(self, height)
				self.icon:SetWidth(thickness)
				self.icon:SetHeight(thickness)
			end

			function barPrototype:SetLength(length)
				self.length = length
				updateSize(self)
			end

			function barPrototype:SetThickness(thickness)
				self.thickness = thickness
				updateSize(self)
			end
		end

		function barPrototype:GetThickness()
			return self.thickness
		end

		function barPrototype:SetOrientation(orientation)
			self.orientation = orientation
			self:UpdateOrientationLayout()
			self:SetThickness(self.thickness)
		end

		function barPrototype:SetValue(val)
			if not val then
				error("Value cannot be nil!")
			end
			self.value = val
			if not self.maxValue or val > self.maxValue then
				self.maxValue = val
			end
			local ownerGroup = self.ownerGroup
			local displayMax = ownerGroup and ownerGroup.displayMax or self.displayMax
			if displayMax then
				displayMax = min(displayMax, self.maxValue)
			else
				displayMax = self.maxValue
			end
			local amt = max(0.000001, min(1, val / max(displayMax, 0.000001)))
			if amt == 1 or amt <= 0.000001 then
				self.spark:Hide()
			else
				self.spark:Show()
			end
			local dist = (ownerGroup and ownerGroup:GetLength()) or self.length
			self:SetTextureValue(max(amt, 0.000001), dist)
			self:UpdateColor()
		end

		function barPrototype:SetTextureValue(amt, dist)
			dist = max(0.0001, dist - (self.showIcon and self.thickness or 0))
			local t, o = self.texture, self.orientation
			t:SetValue(amt * dist)

			if o == 1 then
				t:SetTexCoord(0, amt, 0, 1)
			elseif o == 2 then
				t:SetTexCoord(1 - amt, 1, 0, 1)
			end
		end

		function barPrototype:SetDisplayMax(val)
			self.displayMax = val
		end

		function barPrototype:SetMaxValue(val)
			self.maxValue = val
			self:SetValue(self.value)
		end

		function barPrototype:RegisterTimeLeftTrigger(time, func)
			if time > 0 then
				self.timeLeftTriggers = self.timeLeftTriggers or {}
				self.timeLeftTriggerFuncs = self.timeLeftTriggerFuncs or {}
				self.timeLeftTriggers[time] = false
				self.timeLeftTriggerFuncs[time] = func
			end
		end

		function barPrototype:OnTimerStarted()
			callbacks:Fire("TimerStarted", self, self.name)
		end

		function barPrototype:OnTimerStopped()
			callbacks:Fire("TimerStopped", self, self.name)
		end

		function barPrototype:OnTimerFinished()
			callbacks:Fire("TimerFinished", self, self.name)
		end

		function barPrototype:SetTimer(remaining, maxVal)
			if not self.isTimer then
				return
			end
			self.maxValue = maxVal or self.maxValue
			self:SetValue(self.fill and self.maxValue - remaining or remaining)

			self.timerLabel:Show()
			self.startTime = GetTime() - (self.maxValue - remaining)
			self.lastElapsed = 0
			self.updateDelay = min(max(self.maxValue, 1) / self.length, 0.05)
			self:UpdateTimer()
			if remaining > 0 then
				self:RemoveOnUpdate(self.UpdateTimer)
				self:AddOnUpdate(self.UpdateTimer)
				if not self.isTimerRunning then
					self.isTimerRunning = true
					if self.OnTimerStarted then
						self:OnTimerStarted()
					end
				end
			end
		end

		function barPrototype:StopTimer()
			if self.isTimer and self.isTimerRunning then
				self:RemoveOnUpdate(self.UpdateTimer)
				self.isTimerRunning = false
				if self.OnTimerStopped then
					self:OnTimerStopped()
				end
			end
		end

		function barPrototype:SetFill(fill)
			self.fill = fill
		end

		function barPrototype:UpdateColor()
			if not self.colors or not self.colors[1] then return end
			self.texture:SetVertexColor(self.colors[1], self.colors[2], self.colors[3], self.colors[4] or 1)
		end

		function barPrototype:UpdateTimer(t)
			t = t or GetTime()
			local elapsed, elapsedClamped = t - self.startTime, floor(t) - floor(self.startTime)
			self.lastElapsed = self.lastElapsed or 0
			if elapsed - self.lastElapsed <= self.updateDelay then
				return
			end
			self.lastElapsed = elapsed

			local maxvalue = self.maxValue
			local value, valueClamped, remaining
			if not self.fill then
				value = maxvalue - elapsed
				remaining = value
				valueClamped = maxvalue - elapsedClamped
			else
				value = elapsed
				remaining = maxvalue - value
				valueClamped = elapsedClamped
			end
			if self.timeLeftTriggers then
				for k, v in pairs(self.timeLeftTriggers) do
					if not v and remaining < k then
						self.timeLeftTriggers[k] = true
						self.timeLeftTriggerFuncs[k](self, k, remaining)
					end
				end
			end
			if remaining <= 0 then
				self:RemoveOnUpdate(self.UpdateTimer)
				self.isTimerRunning = false
				if self.OnTimerFinished then
					self:OnTimerFinished()
				end
			end
			if valueClamped >= 3600 then
				local h, m, s
				h = floor(valueClamped / 3600)
				m = floor((valueClamped - (h * 3600)) / 60)
				s = floor((valueClamped - (h * 3600)) - (m * 60))
				self:SetTimerLabel(("%02.0f:%02.0f:%02.0f"):format(h, m, s))
			elseif valueClamped >= 60 then
				local m, s
				m = floor(valueClamped / 60)
				s = floor(valueClamped - (m * 60))
				self:SetTimerLabel(("%02.0f:%02.0f"):format(m, s))
			elseif valueClamped > 10 then
				self:SetTimerLabel(("%02.0f"):format(valueClamped))
			else
				self:SetTimerLabel(("%02.1f"):format(abs(value)))
			end
			self:SetValue(value)

			local o = self.orientation
			if o == 1 then
				self.texture:SetTexCoord(0, value / maxvalue, 0, 1)
			elseif o == 2 then
				self.texture:SetTexCoord(1 - (value / maxvalue), 1, 0, 1)
			end
		end

		local function SetShown(self, show)
			if show and not self:IsShown() then
				self:Show()
			elseif not show and self:IsShown() then
				self:Hide()
			end
		end
		barListPrototype.SetShown = SetShown
		barPrototype.SetShown = SetShown

		-- things to prevent errors.
		barListPrototype.SetReverseGrowth = barListPrototype.ReverseGrowth
		barListPrototype.SetBarHeight = Skada.EmptyFunc
		barListPrototype.SetDisableHighlight = Skada.EmptyFunc
		barListPrototype.SetBarBackgroundColor = Skada.EmptyFunc
		barListPrototype.SetAnchorMouseover = Skada.EmptyFunc
		barListPrototype.SetButtonsOpacity = Skada.EmptyFunc
		barListPrototype.SetButtonsSpacing = Skada.EmptyFunc
		barListPrototype.SetDisableResize = Skada.EmptyFunc
		barListPrototype.SetDisableStretch = Skada.EmptyFunc
		barListPrototype.SetReverseStretch = Skada.EmptyFunc
		barListPrototype.SetDisplacement = Skada.EmptyFunc
		barListPrototype.ShowButton = Skada.EmptyFunc
		barListPrototype.SetTextColor = Skada.EmptyFunc
		barListPrototype.SetSticky = Skada.EmptyFunc
		barListPrototype.SetSmoothing = Skada.EmptyFunc
	end

	----------------------------------------------------------------
	-- Legacy Bar Display
	----------------------------------------------------------------
	do
		local mod = Skada:NewModule("Legacy Bar Display", Skada.displayPrototype)

		local IsShiftKeyDown = IsShiftKeyDown
		local IsAltKeyDown = IsAltKeyDown
		local IsControlKeyDown = IsControlKeyDown

		local SavePosition, RestorePosition = Private.SavePosition, Private.RestorePosition
		local classcolors = Skada.classcolors
		local white = {r = 1, g = 1, b = 1, a = 1}

		-- Display implementation.
		function mod:OnInitialize()
			classcolors = classcolors or Skada.classcolors
			self.description = L["mod_bar_desc"]
			Skada:AddDisplaySystem("legacy", self, true)
		end

		function mod:OnEnable()
			lib.RegisterCallback(self, "AnchorMoved")
			lib.RegisterCallback(self, "AnchorClicked")
			lib.RegisterCallback(self, "ConfigClicked")
			lib.RegisterCallback(self, "BarReleased")
		end

		-- Called when a Skada window starts using this display provider.
		function mod:Create(window)
			-- Re-use bargroup if it exists.
			local p = window.db
			window.bargroup = lib.GetBarGroup(mod, p.name)
			if not window.bargroup then
				window.bargroup = lib.NewBarGroup(
					mod,
					p.name, -- window name
					p.barorientation, -- bars orientation
					p.barwidth, -- bars width
					p.barheight, -- bars height
					format("%sLegacyWindow%s", folder, p.name) -- frame name
				)
			end

			window.bargroup.win = window
			window.bargroup:EnableMouse(true)
			window.bargroup:SetScript("OnMouseDown", function(win, button)
				if button == "RightButton" then
					window:RightClick()
				end
			end)
			window.bargroup:HideIcon()

			-- Restore window position.
			RestorePosition(window.bargroup, p)
		end

		local function showmode(win, id, label, class, mode)
			-- Add current mode to window traversal history.
			if win.selectedmode then
				win.history[#win.history + 1] = win.selectedmode
			end

			if type(mode) == "function" then
				mode(win, id, label, class)
			else
				if mode.Enter then
					mode:Enter(win, id, label, class, mode)
				end
				win:DisplayMode(mode)
			end
		end

		local function BarClick(bar, button)
			local win = not Skada.testMode and bar and bar.win
			if not win then return end

			local id, label, class = bar.id, bar.text, bar.class

			local click1 = win.metadata.click1
			local click2 = win.metadata.click2
			local click3 = win.metadata.click3
			local filterclass = win.metadata.filterclass

			if button == "RightButton" and IsShiftKeyDown() then
				Skada:OpenMenu(win)
			elseif button == "RightButton" and IsAltKeyDown() then
				Skada:ModeMenu(win, bar)
			elseif button == "RightButton" and IsControlKeyDown() then
				Skada:SegmentMenu(win)
			elseif win.metadata.click then
				win.metadata.click(win, id, label, button, class)
			elseif button == "RightButton" and not IsModifierKeyDown() then
				win:RightClick(bar, button)
			elseif button == "LeftButton" and click2 and IsShiftKeyDown() then
				showmode(win, id, label, class, click2)
			elseif button == "LeftButton" and filterclass and IsAltKeyDown() then
				win:FilterClass(class)
			elseif button == "LeftButton" and click3 and IsControlKeyDown() then
				showmode(win, id, label, class, click3)
			elseif button == "LeftButton" and click1 and not IsModifierKeyDown() then
				showmode(win, id, label, class, click1)
			end
		end

		function mod:SetTitle(win, title)
			local bargroup = win and win.bargroup
			if not bargroup then return end

			bargroup.button:SetText(title or win.title or win.metadata.title)
		end

		function mod:BarReleased(_, bar)
			if not bar then return end
			bar.order = nil
			bar.text = nil
			bar.win = nil
		end

		local ttactive = false

		local function BarEnter(bar, motion)
			local win = bar and bar.win
			if not win then return end

			local id, label, class = bar.id, bar.text, bar.class
			Skada:SetTooltipPosition(GameTooltip, win.bargroup, "legacy", win)
			Skada:ShowTooltip(win, id, label, bar, class)
			ttactive = true
		end

		local function BarLeave(win, id, label)
			if not ttactive then return end
			GameTooltip:Hide()
			ttactive = false
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
			bar:SetColor(color.r, color.g, color.b, color.a or 1)
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
			for i = 0, #dataset do
				local data = dataset[i]
				if data and data.id then
					local barid = data.id
					local barlabel = data.label

					local bar = win.bargroup:GetBar(barid)

					if not bar then
						-- Initialization of bars.
						bar = mod:CreateBar(win, barid, barlabel, data.value, metadata.maxvalue or 1, data.icon, false)
						if data.icon and not data.ignore then
							bar:ShowIcon()
						end
						bar.id = data.id
						bar.text = data.label

						bar_seticon(bar, win.db, data)
						bar_setcolor(bar, win.db, data)

						local color = data.class and win.db.classcolortext and classcolors[data.class] or white
						bar.label:SetTextColor(color.r, color.g, color.b, color.a or 1)
						bar.timerLabel:SetTextColor(color.r, color.g, color.b, color.a or 1)

						if not data.ignore then
							bar:SetScript("OnEnter", BarEnter)
							bar:SetScript("OnLeave", BarLeave)
							bar:SetScript("OnMouseDown", BarClick)
							bar:EnableMouse(not win.db.clickthrough)
						else
							bar:SetScript("OnEnter", nil)
							bar:SetScript("OnLeave", nil)
							bar:SetScript("OnMouseDown", nil)
							bar:EnableMouse(false)
						end
					end

					bar.class = data.class
					bar:SetValue(data.value)
					bar:SetMaxValue(metadata.maxvalue or 1)

					if metadata.ordersort then
						bar.order = i
					end

					if metadata.showspots and P.showranks and not data.ignore then
						if win.db.barorientation == 2 then
							bar:SetLabel(format("%s .%2u", data.text or data.label or L["Unknown"], nr))
						else
							bar:SetLabel(format("%2u. %s", nr, data.text or data.label or L["Unknown"]))
						end
					else
						bar:SetLabel(data.text or data.label or L["Unknown"])
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

		local OpenOptions = Private.OpenOptions
		function mod:ConfigClicked(_, group, button)
			if button == "RightButton" then
				OpenOptions(group.win)
			else
				Skada:OpenMenu(group.win)
			end
		end

		function mod:AnchorClicked(_, group, button)
			if group and button == "RightButton" then
				if IsShiftKeyDown() then
					Skada:OpenMenu(group.win)
				elseif IsControlKeyDown() then
					Skada:SegmentMenu(group.win)
				elseif IsAltKeyDown() then
					Skada:ModeMenu(group.win, group, true)
				elseif not group.clickthrough and not Skada.testMode then
					group.win:RightClick(nil, button)
				end
			end
		end

		function mod:AnchorMoved(_, group, x, y)
			SavePosition(group, group.win.db)
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
			direction = win.bargroup.growup and (0 - direction) or direction
			if direction == 1 and win.bargroup.offset > 0 then
				win.bargroup:SetBarOffset(win.bargroup.offset - 1)
			elseif direction == -1 and ((getNumberOfBars(win) - win.bargroup.maxBars - win.bargroup.offset) > 0) then
				win.bargroup:SetBarOffset(win.bargroup.offset + 1)
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
			g:SetColor(p.barcolor.r, p.barcolor.g, p.barcolor.b, p.barcolor.a)
			g:SetMaxBars(p.barmax)
			g:SetUseSpark(p.spark)
			g:SetLocked(p.barslocked)

			-- Header
			local fo = g.TitleFont or CreateFont(format("TitleFont%s", win.db.name))
			g.TitleFont = fo
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
					g.bgframe = CreateFrame("Frame", "$parentBG", g)
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
				[2] = L["Right to left"]
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
					},
					clickthrough = {
						type = "toggle",
						name = L["Click Through"],
						desc = L["Disables mouse clicks on bars."],
						order = 33
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
	end
end)
