-- LibBars-1.0 by Antiarc, all glory to him.
-- Specialized ( = uglified) for Skada
-- Note to self: don't forget to notify original author of changes
-- in the unlikely event they end up being usable outside of Skada.
local MAJOR = "LegacyLibBars-1.0"
local MINOR = 90000 + tonumber(("$Revision: 1 $"):match("%d+"))

local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end -- No Upgrade needed.

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")

local GetTime = _G.GetTime
local sin, cos, rad = _G.math.sin, _G.math.cos, _G.math.rad
local abs, min, max, floor = _G.math.abs, _G.math.min, _G.math.max, _G.math.floor
local table_sort, tinsert, tremove, tconcat = _G.table.sort, tinsert, tremove, _G.table.concat
local next, pairs, assert, error, type, xpcall = next, pairs, assert, error, type, xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
	local code = [[
		local xpcall, eh = ...
		local method, ARGS
		local function call() return method(ARGS) end

		local function dispatch(func, ...)
			 method = func
			 if not method then return end
			 ARGS = ...
			 return xpcall(call, eh)
		end

		return dispatch
	]]

	local ARGS = {}
	for i = 1, argCount do
		ARGS[i] = "arg" .. i
	end
	code = code:gsub("ARGS", tconcat(ARGS, ", "))
	return assert(loadstring(code, "safecall Dispatcher[" .. argCount .. "]"))(xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {__index = function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})
Dispatchers[0] = function(func)
	return xpcall(func, errorhandler)
end

local function safecall(func, ...)
	-- we check to see if the func is passed is actually a function here and don't error when it isn't
	-- this safecall is used for optional functions like OnInitialize OnEnable etc. When they are not
	-- present execution should continue without hinderance
	if type(func) == "function" then
		return Dispatchers[select("#", ...)](func, ...)
	end
end

local dummyFrame, barPrototype, barPrototype_mt, barListPrototype
local barListPrototype_mt

lib.LEFT_TO_RIGHT = 1
lib.BOTTOM_TO_TOP = 2
lib.RIGHT_TO_LEFT = 3
lib.TOP_TO_BOTTOM = 4

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

do
	local mixins = {
		"NewCounterBar",
		"NewTimerBar",
		"NewBarFromPrototype",
		"GetBar",
		"GetBars",
		"HasBar",
		"IterateBars",
		"NewBarGroup",
		"ReleaseBar",
		"GetBarGroup",
		"GetBarGroups"
	}
	function lib:Embed(target)
		for k, v in pairs(mixins) do
			target[v] = self[v]
		end
		lib.embeds[target] = true
		return target
	end
end

local ComputeGradient
do
	local new, del
	do
		local list = lib.garbageList or setmetatable({}, {__mode = "k"})
		lib.garbageList = list
		-- new is always called with the exact same arguments, no need to
		-- iterate over a vararg
		function new(a1, a2, a3, a4, a5)
			local t = next(list)
			if t then
				list[t] = nil
				t[1] = a1
				t[2] = a2
				t[3] = a3
				t[4] = a4
				t[5] = a5
			else
				t = {a1, a2, a3, a4, a5}
			end
			return t
		end

		-- del is called over the same tables produced from new, no need for
		-- fancy stuff
		function del(t)
			t[1] = nil
			t[2] = nil
			t[3] = nil
			t[4] = nil
			t[5] = nil
			t[""] = true
			t[""] = nil
			list[t] = true
			return nil
		end
	end

	local function sort_colors(a, b)
		return a[1] < b[1]
	end

	local colors = {}
	local function getColor(point)
		local lowerBound = colors[1]
		local upperBound = colors[#colors]
		local lowerBoundIndex, upperBoundIndex = 0, 1
		for i = 1, #colors do
			if colors[i][1] >= point then
				if i > 1 then
					lowerBound = colors[i - 1]
					lowerBoundIndex = colors[i - 1][1]
				end
				upperBound = colors[i]
				upperBoundIndex = colors[i][1]
				break
			end
		end
		local pct = (point - lowerBoundIndex) / (upperBoundIndex - lowerBoundIndex)
		local r = lowerBound[2] + ((upperBound[2] - lowerBound[2]) * pct)
		local g = lowerBound[3] + ((upperBound[3] - lowerBound[3]) * pct)
		local b = lowerBound[4] + ((upperBound[4] - lowerBound[4]) * pct)
		local a = lowerBound[5] + ((upperBound[5] - lowerBound[5]) * pct)
		return r, g, b, a
	end

	function ComputeGradient(self)
		self.gradMap = self.gradMap or {}
		if not self.colors then
			return
		end
		if #self.colors == 0 then
			for k in pairs(self.gradMap) do
				self.gradMap[k] = nil
			end
			return
		end

		for i = 1, #colors do
			del(tremove(colors))
		end
		for i = 1, #self.colors, 5 do
			tinsert(colors, new(self.colors[i], self.colors[i + 1], self.colors[i + 2], self.colors[i + 3], self.colors[i + 4]))
		end
		table_sort(colors, sort_colors)

		for i = 0, 200 do
			local r, g, b, a = getColor(i / 200)
			self.gradMap[(i * 4)] = r
			self.gradMap[(i * 4) + 1] = g
			self.gradMap[(i * 4) + 2] = b
			self.gradMap[(i * 4) + 3] = a
		end
	end
end

function lib:GetBar(name)
	return bars[self] and bars[self][name]
end

function lib:GetBars(name)
	return bars[self]
end

function lib:HasAnyBar()
	return not (not (bars[self] and next(bars[self])))
end

do
	local function NOOP()
	end
	function lib:IterateBars()
		if bars[self] then
			return pairs(bars[self])
		else
			return NOOP
		end
	end
end

-- Convenient method to create a new, empty bar prototype
function lib:NewBarPrototype(super)
	assert(super == nil or (type(super) == "table" and type(super.metatable) == "table"), "!NewBarPrototype: super must either be nil or a valid prototype")
	super = super or barPrototype
	local prototype = setmetatable({}, super.metatable)
	prototype.prototype = prototype
	prototype.super = super
	prototype.metatable = {__index = prototype}
	return prototype
end

function lib:NewBarFromPrototype(prototype, name, ...)
	assert(self ~= lib, "You may only call :NewBar as an embedded function")
	assert(type(prototype) == "table" and type(prototype.metatable) == "table", "Invalid bar prototype")
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

function lib:NewTimerBar(name, text, time, maxTime, icon, orientation, length, thickness)
	return self:NewBarFromPrototype(barPrototype, name, text, time, maxTime, icon, orientation, length, thickness, true)
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
		tinsert(recycledBars, bar)
	end
end

do
	local function move(self)
		if not self:GetParent().locked then
			self.startX = self:GetParent():GetLeft()
			self.startY = self:GetParent():GetTop()
			self:GetParent():StartMoving()
		end
	end
	local function stopMove(self)
		if not self:GetParent().locked then
			self:GetParent():StopMovingOrSizing()
			local endX = self:GetParent():GetLeft()
			local endY = self:GetParent():GetTop()
			if self.startX ~= endX or self.startY ~= endY then
				self:GetParent().callbacks:Fire("AnchorMoved", self:GetParent(), endX, endY)
			end
		end
	end
	local function buttonClick(self, button)
		self:GetParent().callbacks:Fire("AnchorClicked", self:GetParent(), button)
	end
	local function configClick(self, button)
		self:GetParent().callbacks:Fire("ConfigClicked", self:GetParent(), button)
	end

	local DEFAULT_TEXTURE = [[Interface\TARGETINGFRAME\UI-StatusBar]]
	function lib:NewBarGroup(name, orientation, length, thickness, frameName)
		if self == lib then
			error("You may only call :NewBarGroup as an embedded function")
		end

		barLists[self] = barLists[self] or {}
		if barLists[self][name] then
			error("A bar list named " .. name .. " already exists.")
		end

		orientation = orientation or lib.LEFT_TO_RIGHT
		orientation = orientation == "LEFT" and lib.LEFT_TO_RIGHT or orientation
		orientation = orientation == "RIGHT" and lib.RIGHT_TO_LEFT or orientation

		local list = setmetatable(CreateFrame("Frame", frameName, UIParent), barListPrototype_mt)
		list:SetMovable(true)
		list:SetClampedToScreen(true)

		list.callbacks = list.callbacks or CallbackHandler:New(list)
		barLists[self][name] = list
		list.name = name

		local myfont = lib.defaultFont
		if not myfont then
			myfont = CreateFont("MyTitleFont")
			myfont:CopyFontObject(ChatFontSmall)
			myfont:SetJustifyH("CENTER")
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

		-- MODIFIED
		-- TODO: refactor into a generic function for adding buttons.
		list.optbutton = CreateFrame("Button", nil, list)
		list.optbutton:SetFrameLevel(10)
		list.optbutton:ClearAllPoints()
		list.optbutton:SetHeight(16)
		list.optbutton:SetWidth(16)
		list.optbutton:SetNormalTexture([[Interface\AddOns\Skada\Media\Textures\toolbar1\config]])
		list.optbutton:SetHighlightTexture([[Interface\AddOns\Skada\Media\Textures\toolbar1\config]], 0.5)
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

		-- MODIFIED
		list.offset = 0

		return list
	end
end

function lib:GetBarGroups()
	return barLists[self]
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
	bar.RegisterCallback(self, "FadeFinished")
	bar.RegisterCallback(self, "TimerFinished")
	bar:SetParent(self)
	return bar, isNew
end

function barListPrototype:SetWidth(width)
	if self:IsVertical() then
		self:SetThickness(width)
	else
		self:SetLength(width)
	end
end

function barListPrototype:SetHeight(height)
	if self:IsVertical() then
		self:SetLength(height)
	else
		self:SetThickness(height)
	end
end

function barListPrototype:NewCounterBar(name, text, value, maxVal, icon, isTimer)
	return self:NewBarFromPrototype(barPrototype, name, text, value, maxVal, icon, self.orientation, self.length, self.thickness, isTimer)
end

local function startFlashing(bar, time)
	if not bar.flashing then
		bar:Flash(bar.ownerGroup.flashPeriod)
	end
end

function barListPrototype:NewTimerBar(name, text, time, maxTime, icon, flashTrigger)
	local bar, isNew = self:NewBarFromPrototype(barPrototype, name, text, time, maxTime, icon, self.orientation, self.length, self.thickness, true)
	bar:RegisterTimeLeftTrigger(flashTrigger or bar.ownerGroup.flashTrigger or 5, startFlashing)
	return bar, isNew
end

function barListPrototype:Lock()
	self.locked = true
end

function barListPrototype:Unlock()
	self.locked = false
end

function barListPrototype:IsLocked()
	return self.locked
end

-- Max number of bars to display. nil to display all.
function barListPrototype:SetMaxBars(num)
	self.maxBars = num
end

function barListPrototype:GetMaxBars()
	return self.maxBars
end

function barListPrototype:SetFlashTrigger(t)
	self.flashTrigger = t
end

function barListPrototype:SetFlashPeriod(p)
	self.flashPeriod = p
end

function barListPrototype:SetTexture(tex)
	self.texture = tex
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v:SetTexture(tex)
		end
	end
end

function barListPrototype:SetFont(f, s, m)
	self.font, self.fontSize, self.fontFlags = f, s, m
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v:SetFont(f, s, m)
		end
	end
end

function barListPrototype:SetFill(fill)
	self.fill = fill
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v:SetFill(fill)
		end
	end
end

function barListPrototype:IsFilling()
	return self.fill
end

function barListPrototype:ShowIcon()
	self.showIcon = true
	if not bars[self] then
		return
	end
	for name, bar in pairs(bars[self]) do
		bar:ShowIcon()
	end
end

function barListPrototype:HideIcon()
	self.showIcon = false
	if not bars[self] then
		return
	end
	for name, bar in pairs(bars[self]) do
		bar:HideIcon()
	end
end

function barListPrototype:IsIconShown()
	return self.showIcon
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

function barListPrototype:IsLabelShown()
	return self.showLabel
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

function barListPrototype:IsValueLabelShown()
	return self.showTimerLabel
end

function barListPrototype:SetSpacing(spacing)
	self.spacing = spacing
	self:SortBars()
end

function barListPrototype:GetSpacing()
	return self.spacing
end

barListPrototype.GetBar = lib.GetBar
barListPrototype.GetBars = lib.GetBars
barListPrototype.HasAnyBar = lib.HasAnyBar
barListPrototype.IterateBars = lib.IterateBars

function barListPrototype:MoveBarToGroup(bar, group)
	if type(bar) ~= "table" then
		bar = bars[self][bar]
	end
	if not bar then
		error("Cannot find bar passed to MoveBarToGroup")
	end
	bars[group] = bars[group] or {}
	if bars[group][bar.name] then
		error("Cannot move " .. bar.name .. " to this group; a bar with that name already exists.")
	end
	for k, v in pairs(bars[self]) do
		if v == bar then
			bars[self][k] = nil
			bar = v
			break
		end
	end
	bar:SetParent(group)
	bar.ownerGroup = group
	bars[group][bar.name] = bar
end

function barListPrototype:RemoveBar(bar)
	lib.ReleaseBar(self, bar)
end

function barListPrototype:SetDisplayMax(val)
	self.displayMax = val
end

function barListPrototype:UpdateColors()
	-- Force a color update on all the bars, particularly the counter bars
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v:UpdateColor()
		end
	end
end

function barListPrototype:SetColorAt(at, r, g, b, a)
	self.colors = self.colors or {}
	tinsert(self.colors, at)
	tinsert(self.colors, r)
	tinsert(self.colors, g)
	tinsert(self.colors, b)
	tinsert(self.colors, a)
	ComputeGradient(self)
	self:UpdateColors()
end

function barListPrototype:UnsetColorAt(at)
	if not self.colors then
		return
	end
	for i = 1, #self.colors, 5 do
		if self.colors[i] == at then
			for j = 1, 5 do
				tremove(self.colors, i)
			end
			ComputeGradient(self)
			self:UpdateColors()
			return
		end
	end
end

function barListPrototype:UnsetAllColors()
	if not self.colors then
		return
	end
	for i = 1, #self.colors do
		tremove(self.colors)
	end
	return
end

function barListPrototype:TimerFinished(evt, bar, name)
	bar.ownerGroup.callbacks:Fire("TimerFinished", bar.ownerGroup, bar, name)
	bar:Fade()
end

function barListPrototype:FadeFinished(evt, bar, name)
	local group = bar.ownerGroup
	lib.ReleaseBar(group, bar)
	group:SortBars()
end

function barListPrototype:ShowAnchor()
	self.button:Show()
	self:SortBars()
end

function barListPrototype:HideAnchor()
	self.button:Hide()
	self:SortBars()
end

function barListPrototype:IsAnchorVisible()
	return self.button:IsVisible()
end

function barListPrototype:ToggleAnchor()
	if self.button:IsVisible() then
		self.button:Hide()
	else
		self.button:Show()
	end
	self:SortBars()
end

function barListPrototype:GetBarAttachPoint()
	local vertical, growup, lastBar = (self.orientation % 2 == 0), self.growup, self.lastBar
	if vertical then
		if growup then
			return lastBar:GetLeft() - lastBar:GetWidth(), lastBar:GetTop()
		else
			return lastBar:GetRight() + lastBar:GetWidth(), lastBar:GetTop()
		end
	else
		if growup then
			return lastBar:GetLeft(), lastBar:GetTop() + lastBar:GetHeight()
		else
			return lastBar:GetLeft(), lastBar:GetBottom() - lastBar:GetHeight()
		end
	end
end

function barListPrototype:ReverseGrowth(reverse)
	self.growup = reverse
	self.button:ClearAllPoints()
	if self.orientation % 2 == 0 then
		if reverse then
			self.button:SetPoint("TOPRIGHT", self, "TOPRIGHT")
			self.button:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")
		else
			self.button:SetPoint("TOPLEFT", self, "TOPLEFT")
			self.button:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT")
		end
	else
		if reverse then
			self.button:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT")
			self.button:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")
		else
			self.button:SetPoint("TOPLEFT", self, "TOPLEFT")
			self.button:SetPoint("TOPRIGHT", self, "TOPRIGHT")
		end
	end
	self:SortBars()
end

function barListPrototype:HasReverseGrowth()
	return self.growup
end

function barListPrototype:UpdateOrientationLayout()
	local vertical, length, thickness = (self.orientation % 2 == 0), self.length, self.thickness
	if vertical then
		barListPrototype.super.SetWidth(self, thickness)
		barListPrototype.super.SetHeight(self, length)
		self.button:SetWidth(thickness)
		self.button:SetHeight(length)
	else
		barListPrototype.super.SetWidth(self, length)
		barListPrototype.super.SetHeight(self, thickness)
		self.button:SetWidth(length)
		self.button:SetHeight(thickness)
	end

	self.button:SetText(vertical and "" or self.name)
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

function barListPrototype:GetOrientation()
	return self.orientation
end

function barListPrototype:IsVertical()
	return self.orientation % 2 == 0
end

-- MODIFIED
-- Allows nil sort function.
function barListPrototype:SetSortFunction(func)
	if func then
		assert(type(func) == "function")
	end
	self.sortFunc = func
end

function barListPrototype:GetSortFunction(func)
	return self.sortFunc
end

-- MODIFIED
function barListPrototype:SetBarOffset(offset)
	self.offset = offset
	self:SortBars()
end

-- MODIFIED
function barListPrototype:GetBarOffset()
	return self.offset
end

-- MODIFIED
function barListPrototype:SetUseSpark(use)
	self.usespark = use
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v:SetUseSpark(use)
		end
	end
end

-- group:SetSortFunction(group.NOOP) to disable sorting
function barListPrototype.NOOP() end

do
	local values = {}

	-- MODIFIED (for reverse growth)
	local function sortFuncReverse(a, b)
		if a.isTimer ~= b.isTimer then
			return a.isTimer
		end

		local apct, bpct = a.value / a.maxValue, b.value / b.maxValue
		if apct == bpct then
			if a.maxValue == b.maxValue then
				return a.name < b.name
			else
				return a.maxValue < b.maxValue
			end
		else
			return apct < bpct
		end
	end
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
		if not bars[self] then
			return
		end
		for k, v in pairs(bars[self]) do
			if not v.isAnimating then
				ct = ct + 1
				values[ct] = v
			end
		end
		for i = ct + 1, #values do
			values[i] = nil
		end

		-- MODIFIED (for reverse growth)
		if self.growup then
			table_sort(values, self.sortFunc or sortFuncReverse)
		else
			table_sort(values, self.sortFunc or sortFunc)
		end

		local orientation = self.orientation
		local vertical = orientation % 2 == 0
		local growup = self.growup
		local spacing = self.spacing

		local from, to
		local thickness, showIcon = self.thickness, self.showIcon
		local x1, y1, x2, y2 = 0, 0, 0, 0
		if vertical then
			if growup then
				from = "RIGHT"
				to = "LEFT"
				x1, x2 = -spacing, -spacing
			else
				from = "LEFT"
				to = "RIGHT"
				x1, x2 = spacing, spacing
			end
		else
			if growup then
				from = "BOTTOM"
				to = "TOP"
				y1, y2 = spacing, spacing
			else
				from = "TOP"
				to = "BOTTOM"
				y1, y2 = -spacing, -spacing
			end
		end
		local totalHeight = 0
		-- MODIFIED
		local shown = 0
		for i = 1, #values do
			local origTo = to
			local v = values[i]
			if lastBar == self or lastBar == self.button then
				if lastBar == self then
					to = from
				end
				if vertical then
					if orientation == 2 then
						y1, y2 = 0, (v.showIcon and thickness or 0)
					else
						y1, y2 = (v.showIcon and -thickness or 0), 0
					end
				else
					if orientation == 1 then
						x1, x2 = (v.showIcon and thickness or 0), 0
					else
						x1, x2 = 0, (v.showIcon and -thickness or 0)
					end
				end
			else
				if vertical then
					y1, y2 = 0, 0
				else
					x1, x2 = 0, 0
				end
			end

			v:ClearAllPoints()
			-- MODIFIED
			if (self.maxBars and shown >= self.maxBars) or (i < self:GetBarOffset() + 1) then
				v:Hide()
			else
				v:Show()
				shown = shown + 1
				if vertical then
					totalHeight = totalHeight + v:GetWidth() + x1
					v:SetPoint("TOP" .. from, lastBar, "TOP" .. to, x1, y1)
					v:SetPoint("BOTTOM" .. from, lastBar, "BOTTOM" .. to, x2, y2)
				else
					totalHeight = totalHeight + v:GetHeight() + y1
					v:SetPoint(from .. "LEFT", lastBar, to .. "LEFT", x1, y1)
					v:SetPoint(from .. "RIGHT", lastBar, to .. "RIGHT", x2, y2)
				end
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
		self:GetParent().callbacks:Fire("BarClick", self:GetParent(), button)
	end
	local function barEnter(self, button)
		self:GetParent().callbacks:Fire("BarEnter", self:GetParent(), button)
	end
	local function barLeave(self, button)
		self:GetParent().callbacks:Fire("BarLeave", self:GetParent(), button)
	end

	local DEFAULT_ICON = [[Interface\ICONS\INV_Misc_QuestionMark]]
	function barPrototype:Create(text, value, maxVal, icon, orientation, length, thickness, isTimer)
		self.callbacks = self.callbacks or CallbackHandler:New(self)

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
		-- MODIFIED
		if icon then
			self:ShowIcon()
		end
		-- MODIFIED
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

		self.timerFuncs = self.timerFuncs or {}
		for i = 1, #self.timerFuncs do
			tremove(self.timerFuncs)
		end

		self:SetScale(1)
		self:SetAlpha(1)
		self.flashing = false

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
	self:StopFlash()
	self:StopFade()

	self.callbacks:Fire("BarReleased", self, self.name)

	-- Reset our attributes
	self.isAnimating = false
	self.isTimer = false
	self.ownerGroup = nil
	self.fill = false
	if self.colors then
		for k, v in pairs(self.colors) do
			self.colors[k] = nil
		end
	end
	if self.gradMap then
		for k, v in pairs(self.gradMap) do
			self.gradMap[k] = nil
		end
	end
	if self.timeLeftTriggers then
		for k, v in pairs(self.timeLeftTriggers) do
			self.timeLeftTriggers[k] = nil
		end
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

	-- Cancel all registered callbacks. CBH doesn't seem to provide a method to do this.
	if self.callbacks.insertQueue then
		for eventname, callbacks in pairs(self.callbacks.insertQueue) do
			for k, v in pairs(callbacks) do
				callbacks[k] = nil
			end
		end
	end
	for eventname, callbacks in pairs(self.callbacks.events) do
		for k, v in pairs(callbacks) do
			callbacks[k] = nil
		end
		if self.callbacks.OnUnused then
			self.callbacks.OnUnused(self.callbacks, self.ownerGroup, eventname)
		end
	end
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
	tinsert(self.timerFuncs, f)
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
		if type(icon) == "number" then
			icon = select(3, GetSpellInfo(icon))
		end
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

function barPrototype:IsIconShown()
	return self.showIcon
end

function barPrototype:OnAnimateFinished()
	self.callbacks:Fire("AnimateFinished", self, self.name)
end

local function animate(self, elapsed)
	self.aniST = self.aniST + elapsed
	local amt = min(1, self.aniST / self.aniT)
	local x = self.aniSX + ((self.aniX - self.aniSX) * amt)
	local y = self.aniSY + ((self.aniY - self.aniSY) * amt)
	local s = self.aniSS + ((self.aniS - self.aniSS) * amt)
	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
	self:SetScale(s)

	if amt == 1 then
		self.isAnimating = false
		self:RemoveOnUpdate(animate)
		safecall(self.OnAnimateFinished, self)
		if self.ownerGroup then
			self:ClearAllPoints()
			self.ownerGroup:SortBars()
			self:UpdateColor()
			self:SetParent(self.ownerGroup)
			self:SetScale(1)
		end
	end
end

function barPrototype:AnimateTo(x, y, scale, t)
	self.isAnimating = true
	self.aniSX, self.aniSY, self.aniSS, self.aniST = self:GetLeft(), self:GetTop(), self:GetScale(), 0
	self.aniX, self.aniY, self.aniS, self.aniT = x, y, scale, t
	self:AddOnUpdate(animate)
	animate(0)
end

function barPrototype:AnimateToGroup(group)
	self.isAnimating = true
	self.ownerGroup:SortBars()
	self.ownerGroup:MoveBarToGroup(self, group)
	self:SetParent(UIParent)

	local x, y = group:GetBarAttachPoint()
	x = x / UIParent:GetScale()
	y = y / UIParent:GetScale()
	self:AnimateTo(x, y, group:GetScale(), 0.75)
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

function barPrototype:IsLabelShown()
	return self.showLabel
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

function barPrototype:IsValueLabelShown()
	return self.showTimerLabel
end

function barPrototype:SetTexture(texture)
	self.texture:SetTexture(texture)
	self.bgtexture:SetTexture(texture)
end

-- Added by Ulic
-- Allows for the setting of background colors for a specific bar
-- Someday I'll figure out to do it at the group level
function barPrototype:SetBackgroundColor(r, g, b, a)
	a = a or .6
	if r and g and b and a then
		self.bgtexture:SetVertexColor(r, g, b, a)
	end
end

function barPrototype:SetColorAt(at, r, g, b, a)
	self.colors = self.colors or {}
	tinsert(self.colors, at)
	tinsert(self.colors, r)
	tinsert(self.colors, g)
	tinsert(self.colors, b)
	tinsert(self.colors, a)
	ComputeGradient(self)
	self:UpdateColor()
end

function barPrototype:UnsetColorAt(at)
	if not self.colors then
		return
	end
	for i = 1, #self.colors, 5 do
		if self.colors[i] == at then
			for j = 1, 5 do
				tremove(self.colors, i)
			end
			ComputeGradient(self)
			self:UpdateColor()
			return
		end
	end
end

function barPrototype:UnsetAllColors()
	if not self.colors then
		return
	end
	for i = 1, #self.colors do
		tremove(self.colors)
	end
end

do
	function barPrototype:UpdateOrientationLayout()
		local o = self.orientation
		local t
		if o == lib.LEFT_TO_RIGHT then
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
		elseif o == lib.BOTTOM_TO_TOP then
			self.icon:ClearAllPoints()
			self.icon:SetPoint("TOP", self, "BOTTOM", 0, 0)

			t = self.spark
			t:ClearAllPoints()
			t:SetPoint("LEFT", self.texture, "TOPLEFT", -7, 0)
			t:SetPoint("RIGHT", self.texture, "TOPRIGHT", 7, 0)
			t:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)

			t = self.texture
			t.SetValue = t.SetHeight
			t:ClearAllPoints()
			t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT")
			t:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")

			t = self.timerLabel
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", self, "TOPLEFT", 3, -3)
			t:SetPoint("TOPRIGHT", self, "TOPRIGHT", -3, -3)
			t:SetJustifyH("CENTER")
			t:SetJustifyV("TOP")

			t = self.label
			t:ClearAllPoints()
			t:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -3, 3)
			t:SetPoint("TOPLEFT", self.timerLabel, "BOTTOMLEFT", 0, 0)
			t:SetJustifyH("CENTER")
			t:SetJustifyV("BOTTOM")

			self.bgtexture:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
		elseif o == lib.RIGHT_TO_LEFT then
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
		elseif o == lib.TOP_TO_BOTTOM then
			self.icon:ClearAllPoints()
			self.icon:SetPoint("BOTTOM", self, "TOP", 0, 0)

			t = self.spark
			t:ClearAllPoints()
			t:SetPoint("LEFT", self.texture, "BOTTOMLEFT", -7, 0)
			t:SetPoint("RIGHT", self.texture, "BOTTOMRIGHT", 7, 0)
			t:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)

			t = self.texture
			t.SetValue = t.SetHeight
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", self, "TOPLEFT")
			t:SetPoint("TOPRIGHT", self, "TOPRIGHT")

			t = self.timerLabel
			t:ClearAllPoints()
			t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 3, 3)
			t:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -3, 3)
			t:SetJustifyH("CENTER")
			t:SetJustifyV("BOTTOM")

			t = self.label
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", self, "TOPLEFT", 3, -3)
			t:SetPoint("BOTTOMRIGHT", self.timerLabel, "TOPRIGHT", 0, 0)
			t:SetJustifyH("CENTER")
			t:SetJustifyV("TOP")

			self.bgtexture:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
		end
		self:SetValue(self.value or 0)
	end
end

function barPrototype:GetLength()
	return self.length
end

do
	local function updateSize(self)
		local vertical, thickness, length = self.orientation % 2 == 0, self.thickness, self.length
		local iconSize = self.showIcon and (vertical and length or thickness) or 0
		local width = vertical and thickness or max(0.0001, length - iconSize)
		local height = vertical and max(0.00001, length - iconSize) or thickness
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

function barPrototype:GetOrientation()
	return self.orientation
end

function barPrototype:IsVertical()
	return self.orientation % 2 == 0
end

function barPrototype:SetValue(val)
	assert(val ~= nil, "Value cannot be nil!")
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
		t:SetTexCoord(1 - amt, 1, 1, 1, 1 - amt, 0, 1, 0)
	elseif o == 3 then
		t:SetTexCoord(1 - amt, 1, 0, 1)
	elseif o == 4 then
		t:SetTexCoord(0, 1, amt, 1, 0, 0, amt, 0)
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
	self.callbacks:Fire("TimerStarted", self, self.name)
end

function barPrototype:OnTimerStopped()
	self.callbacks:Fire("TimerStopped", self, self.name)
end

function barPrototype:OnTimerFinished()
	self.callbacks:Fire("TimerFinished", self, self.name)
end

function barPrototype:SetTimer(remaining, maxVal)
	if not self.isTimer then
		return
	end
	self:StopFade()
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
			safecall(self.OnTimerStarted, self)
		end
	end
end

function barPrototype:StopTimer()
	if self.isTimer and self.isTimerRunning then
		self:RemoveOnUpdate(self.UpdateTimer)
		self.isTimerRunning = false
		safecall(self.OnTimerStopped, self)
	end
end

function barPrototype:SetFill(fill)
	self.fill = fill
end

function barPrototype:UpdateColor()
	local amt = floor(self.value / self.maxValue * 200) * 4
	local map
	if self.gradMap and #self.gradMap > 0 then
		map = self.gradMap
	elseif self.ownerGroup and self.ownerGroup.gradMap and #self.ownerGroup.gradMap > 0 then
		map = self.ownerGroup.gradMap
	end
	if map then
		self.texture:SetVertexColor(map[amt], map[amt + 1], map[amt + 2], map[amt + 3])
	end
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
		safecall(self.OnTimerFinished, self)
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
	if o == lib.LEFT_TO_RIGHT then
		self.texture:SetTexCoord(0, value / maxvalue, 0, 1)
	elseif o == lib.RIGHT_TO_LEFT then
		self.texture:SetTexCoord(1 - (value / maxvalue), 1, 0, 1)
	elseif o == lib.BOTTOM_TO_TOP then
		self.texture:SetTexCoord(1 - (value / maxvalue), 1, 1, 1, 1 - value / maxvalue, 0, 1, 0)
	elseif o == lib.TOP_TO_BOTTOM then
		self.texture:SetTexCoord(0, 1, value / maxvalue, 1, 0, 0, value / maxvalue, 0)
	end
end

function barPrototype:OnFadeStarted()
	self.callbacks:Fire("FadeStarted", self, self.name)
end

function barPrototype:OnFadeFinished()
	self.callbacks:Fire("FadeFinished", self, self.name)
end

function barPrototype:OnFadeStopped()
	self.callbacks:Fire("FadeStopped", self, self.name)
end

do
	local function fade(self, elapsed)
		self.fadeElapsed = (self.fadeElapsed or 0) + elapsed
		self:SetAlpha(self.fadeAlpha * (1 - min(1, max(0, self.fadeElapsed / self.fadeTotal))))
		if self.fadeElapsed > self.fadeTotal then
			self:RemoveOnUpdate(fade)
			self.fadeElapsed, self.fadeTotal, self.fadeAlpha, self.fading = nil, nil, nil, false
			safecall(self.OnFadeFinished, self)
		end
	end

	function barPrototype:Fade(t)
		if self.fading then
			return
		end
		self:StopTimer()
		self.fading = true
		t = t or 0.5
		self.fadeTotal = t
		self.fadeElapsed = 0
		self.fadeAlpha = self.flashAlpha or self:GetAlpha()
		self:AddOnUpdate(fade)
		fade(self, 0)
		safecall(self.OnFadeStarted, self)
	end

	function barPrototype:StopFade()
		if self.fading then
			self:RemoveOnUpdate(fade)
			self:SetAlpha(self.fadeAlpha)
			self.fadeElapsed, self.fadeTotal, self.fadeAlpha, self.fading = nil, nil, nil, false
			safecall(self.OnFadeStopped, self)
		end
	end

	function barPrototype:IsFading()
		return self.fading
	end
end

function barPrototype:OnFlashStarted()
	self.callbacks:Fire("FlashStarted", self, self.name)
end

function barPrototype:OnFlashStopped()
	self.callbacks:Fire("FlashStopped", self, self.name)
end

do
	local TWOPI = _G.math.pi * 2
	local function flash(self, t)
		self.flashTime = self.flashTime + t
		if self.flashTime > TWOPI then
			self.flashTime = self.flashTime - TWOPI
			if self.flashTimes then
				self.flashedTimes = self.flashedTimes + 1
				if self.flashedTimes >= self.flashTimes then
					self:StopFlash()
				end
			end
		end
		local amt = self.flashAlpha * (cos(self.flashTime / self.flashPeriod) + 1) / 2
		self:SetAlpha(amt)
	end

	function barPrototype:Flash(period, times)
		self.flashTimes = times
		self.flashTime = 0
		self.flashedTimes = 0
		self.flashPeriod = (period or 1 / 5) or 0.1
		if not self.flashing then
			self.flashing = true
			self.flashAlpha = self.fadeAlpha or self:GetAlpha()
			self:SetAlpha(self.flashAlpha)
			self:AddOnUpdate(flash)
			safecall(self.OnFlashStarted, self)
		end
	end

	function barPrototype:StopFlash()
		if self.flashing then
			self:SetAlpha(self.flashAlpha)
			self.flashing, self.flashAlpha = false, nil
			self:RemoveOnUpdate(flash)
			safecall(self.OnFlashStopped, self)
		end
	end
end

--- Finally: upgrade our old embeds
for target, v in pairs(lib.embeds) do
	lib:Embed(target)
end