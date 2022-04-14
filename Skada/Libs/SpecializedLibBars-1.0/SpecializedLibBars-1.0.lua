-- LibBars-1.0 by Kader, all glory to him.
-- Specialized ( = enhanced) for Skada
-- Note to self: don't forget to notify original author of changes
-- in the unlikely event they end up being usable outside of Skada.
local MAJOR, MINOR = "SpecializedLibBars-1.0", 90003
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end -- No Upgrade needed.

local CallbackHandler = LibStub("CallbackHandler-1.0")

local GetTime = GetTime
local sin, cos, rad = math.sin, math.cos, math.rad
local abs, min, max, floor = math.abs, math.min, math.max, math.floor
local tsort, tinsert, tremove, tconcat, wipe = table.sort, tinsert, tremove, table.concat, wipe
local next, pairs, assert, error, type, xpcall = next, pairs, assert, error, type, xpcall
local GameTooltip = GameTooltip

local ICON_LOCK = [[Interface\AddOns\Skada\Libs\SpecializedLibBars-1.0\lock.tga]]
local ICON_UNLOCK = [[Interface\AddOns\Skada\Libs\SpecializedLibBars-1.0\unlock.tga]]
local ICON_RESIZE = [[Interface\AddOns\Skada\Libs\SpecializedLibBars-1.0\resize.blp]]

local L = {
	resize_header = "Resize",
	resize_click = "|cff00ff00Click|r to freely resize window.",
	resize_shift_click = "|cff00ff00Shift-Click|r to change the width.",
	resize_alt_click = "|cff00ff00Alt-Click|r to change the height.",
	lock_window = "Lock Window",
	unlock_window = "Unlock Window"
}
if LOCALE_deDE then
	L.resize_header = "Größe ändern"
	L.resize_click = "|cff00ff00Klicken|r, um die Fenstergröße frei zu ändern."
	L.resize_shift_click = "|cff00ff00Umschalt-Klick|r, um die Breite zu ändern."
	L.resize_alt_click = "|cff00ff00Alt-Klick|r, um die Höhe zu ändern."
	L.lock_window = "Fenster sperren"
	L.unlock_window = "Fenster entsperren"
elseif LOCALE_esES or LOCALE_esMX then
	L.resize_header = "Redimensionar"
	L.resize_click = "|cff00ff00Haga clic|r para cambiar el tamaño de la ventana."
	L.resize_shift_click = "|cff00ff00Shift-Click|r para cambiar el ancho de la ventana."
	L.resize_alt_click = "|cff00ff00Alt-Click|r para cambiar la altura de la ventana."
	L.lock_window = "Bloquear ventana"
	L.unlock_window = "Desbloquear ventana"
elseif LOCALE_frFR then
	L.resize_header = "Redimensionner"
	L.resize_click = "|cff00ff00Clic|r pour redimensionner."
	L.resize_shift_click = "|cff00ff00Shift clic|r pour changer la largeur."
	L.resize_alt_click = "|cff00ff00Alt clic|r pour changer la hauteur."
	L.lock_window = "Verrouiller la fenêtre"
	L.unlock_window = "Déverrouiller la fenêtre"
elseif LOCALE_koKR then
	L.resize_header = "크기 조정"
	L.resize_click = "|cff00ff00클릭|r하여 창 크기를 자유롭게 조정합니다."
	L.resize_shift_click = "너비를 변경하려면 |cff00ff00Shift-클릭|r하십시오."
	L.resize_alt_click = "높이를 변경하려면 |cff00ff00Alt-클릭|r하십시오"
	L.lock_window = "잠금 창"
	L.unlock_window = "잠금 해제 창"
elseif LOCALE_ruRU then
	L.resize_header = "Изменение размера"
	L.resize_click = "|cff00ff00Щелкните|r, чтобы изменить размер окна."
	L.resize_shift_click = "|cff00ff00Shift-Click|r, чтобы изменить ширину."
	L.resize_alt_click = "|cff00ff00ALT-Click|r, чтобы изменить высоту."
	L.lock_window = "Заблокировать окно"
	L.unlock_window = "Разблокировать окно"
elseif LOCALE_zhCN then
	L.resize_header = "调整大小"
	L.resize_click = "|cff00ff00单击|r以调整窗口大小。"
	L.resize_shift_click = "|cff00ff00Shift-Click|r改变窗口的宽度。"
	L.resize_alt_click = "|cff00ff00Alt-Click|r更改窗口高度。"
	L.lock_window = "锁定窗口"
	L.unlock_window = "解锁窗口"
elseif LOCALE_zhTW then
	L.resize_header = "調整大小"
	L.resize_click = "|cff00ff00單擊|r以調整窗口大小。"
	L.resize_shift_click = "|cff00ff00Shift-Click|r改變窗口的寬度。"
	L.resize_alt_click = "|cff00ff00Alt-Click|r更改窗口高度。"
	L.lock_window = "鎖定窗口"
	L.unlock_window = "解鎖窗口"
end

--[[ xpcall safecall implementation ]]--
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

local bars = lib.bars
local barLists = lib.barLists
local recycledBars = lib.recycledBars

local frame_defaults = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	inset = 4,
	edgeSize = 8,
	tile = true,
	insets = {left = 2, right = 2, top = 2, bottom = 2}
}

lib.embeds = lib.embeds or {}
do
	local mixins = {
		"NewBar",
		"GetBar",
		"ReleaseBar",
		"GetBars",
		"NewBarGroup",
		"GetBarGroup",
		"GetBarGroups",
		"SetScrollSpeed"
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
	-- TODO: Put me back!
	-- local new, del
	-- do
	-- 	local list = setmetatable({}, {__mode = "k"})

	-- 	-- new is always called with the exact same arguments, no need to
	-- 	-- iterate over a vararg
	-- 	function new(a1, a2, a3, a4, a5)
	-- 		local t = next(list)
	-- 		if t then
	-- 			list[t] = nil
	-- 			t[1] = a1
	-- 			t[2] = a2
	-- 			t[3] = a3
	-- 			t[4] = a4
	-- 			t[5] = a5
	-- 		else
	-- 			t = {a1, a2, a3, a4, a5}
	-- 		end
	-- 		return t
	-- 	end

	-- 	-- del is called over the same tables produced from new, no need for
	-- 	-- fancy stuff
	-- 	function del(t)
	-- 		t[1] = nil
	-- 		t[2] = nil
	-- 		t[3] = nil
	-- 		t[4] = nil
	-- 		t[5] = nil
	-- 		t[""] = true
	-- 		t[""] = nil
	-- 		list[t] = true
	-- 		return nil
	-- 	end
	-- end

	-- local function sort_colors(a, b)
	-- 	return a[1] < b[1]
	-- end

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
		--local pct = (point - lowerBoundIndex) / (upperBoundIndex - lowerBoundIndex)
		local diff = (upperBoundIndex - lowerBoundIndex)
		local pct = (diff ~= 0) and ((point - lowerBoundIndex) / diff) or 1
		local r = lowerBound[2] + ((upperBound[2] - lowerBound[2]) * pct)
		local g = lowerBound[3] + ((upperBound[3] - lowerBound[3]) * pct)
		local b = lowerBound[4] + ((upperBound[4] - lowerBound[4]) * pct)
		local a = lowerBound[5] + ((upperBound[5] - lowerBound[5]) * pct)
		return r, g, b, a
	end

	function ComputeGradient(self)
		if not self.colors or #self.colors == 0 then
			if self.gradMap then
				wipe(self.gradMap)
			end
			return
		end

		-- TODO: Enhance me!
		-- for i = 1, #colors do
		-- 	del(tremove(colors))
		-- end
		-- for i = 1, #self.colors, 5 do
		-- 	colors[#colors + 1] = new(self.colors[i], self.colors[i + 1], self.colors[i + 2], self.colors[i + 3], self.colors[i + 4])
		-- end
		-- tsort(colors, sort_colors)

		-- TODO: Remove me!
		colors[1] = colors[1] or {}
		for i, c in ipairs(self.colors) do
			colors[1][i] = c
		end

		self.gradMap = self.gradMap or {}
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

---[[ Individual bars ]]---
function lib:NewBarFromPrototype(prototype, name, ...)
	assert(self ~= lib, "You may only call :NewBar as an embedded function")
	assert(type(prototype) == "table" and type(prototype.metatable) == "table", "Invalid bar prototype")
	bars[self] = bars[self] or {}
	local bar = bars[self][name]
	local isNew = false
	if not bar then
		bar = tremove(recycledBars)
		if not bar then
			bar = CreateFrame("Frame")
		else
			bar:Show()
		end
		isNew = true
	end
	bar = setmetatable(bar, prototype.metatable)
	bar.name = name
	bar:Create(...)
	bar:SetFont(self.font, self.fontSize, self.fontFlags, self.numfont, self.numfontSize, self.numfontFlags)

	bars[self][name] = bar

	return bar, isNew
end

function lib:NewBar(name, text, value, maxVal, icon, orientation, length, thickness)
	return self:NewBarFromPrototype(barPrototype, name, text, value, maxVal, icon, orientation, length, thickness)
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

lib.scrollspeed = lib.scrollspeed or 1
function lib:SetScrollSpeed(speed)
	lib.scrollspeed = min(10, max(1, speed or 0))
end

---[[ Bar Groups ]]---
do
	local function btnOnEnter(self)
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetText(self.title)
		GameTooltip:AddLine(self.description, 1, 1, 1, true)
		GameTooltip:Show()
		if self.list.mouseover then
			self.list:ShowButtons()
			self.list:AdjustTitle(true)
		end
	end

	local function btnOnLeave(self)
		GameTooltip:Hide()
		if self.list.mouseover then
			self:Hide()
			self.list:HideButtons()
			self.list:AdjustTitle()
		end
	end

	function barListPrototype:AddButton(index, title, description, normaltex, highlighttex, clickfunc)
		if index and not title then
			title = index
		elseif title and not index then
			index = title
		end

		-- Create button frame.
		local btn = CreateFrame("Button", "$parent" .. title:gsub("%s+", "_"), self.button)
		btn:SetFrameLevel(self.button:GetFrameLevel() + 1)
		btn:SetSize(14, 14)
		btn:SetNormalTexture(normaltex)
		btn:SetHighlightTexture(highlighttex or normaltex, 1.0)
		btn:RegisterForClicks("AnyUp")
		btn:SetScript("OnClick", clickfunc)

		btn.list = self
		btn.index = index
		btn.title = title
		btn.description = description

		btn:SetScript("OnEnter", btnOnEnter)
		btn:SetScript("OnLeave", btnOnLeave)

		btn:Hide()
		self.buttons[#self.buttons + 1] = btn
		self:AdjustButtons()

		return btn
	end
end

do
	local function Smoothing_OnUpdate(self, elapsed)
		if bars[self] then
			for k, v in pairs(bars[self]) do
				if v.targetamount and v:IsShown() then
					local amt
					if v.targetamount > v.lastamount then
						amt = min(((v.targetamount - v.lastamount) / 10) + v.lastamount, v.targetamount)
					else
						amt = max(v.lastamount - ((v.lastamount - v.targetamount) / 10), v.targetamount)
					end

					v.lastamount = amt
					if amt == v.targetamount then
						v.targetamount = nil
					end
					v:SetTextureValue(amt, v.targetdist)
				end
			end
		end
	end

	function barListPrototype:SetSmoothing(smoothing)
		self.smoothing = smoothing or nil
		self:SetScript("OnUpdate", self.smoothing and Smoothing_OnUpdate or nil)
	end
end

function barListPrototype:SetButtonsOpacity(alpha)
	self.buttonsOpacity = alpha
	for _, btn in ipairs(self.buttons) do
		btn:SetAlpha(alpha)
	end
end

do
	local function anchorOnEnter(self)
		local p = self:GetParent()
		p:ShowButtons()
		p:AdjustTitle(true)
	end

	local function anchorOnLeave(self)
		local p = self:GetParent()
		p:HideButtons()
		p:AdjustTitle()
	end

	function barListPrototype:SetButtonMouseOver(mouseover)
		self.mouseover = mouseover or nil

		if self.mouseover then
			self:HideButtons()
			self.button:SetScript("OnEnter", anchorOnEnter)
			self.button:SetScript("OnLeave", anchorOnLeave)
		else
			self:ShowButtons()
			self.button:SetScript("OnEnter", nil)
			self.button:SetScript("OnLeave", nil)
		end

		self:AdjustButtons()
	end
end

function barListPrototype:SetButtonSpacing(spacing)
	self.spacing2 = spacing
	self:AdjustButtons()
end

function barListPrototype:AdjustButtons()
	self.lastbtn = nil
	local height = self.button:GetHeight()
	local spacing = self.spacing2 or 1
	local nr = 0

	for _, btn in ipairs(self.buttons) do
		btn:ClearAllPoints()

		if btn.visible then
			if nr == 0 and self.orientation == 3 then
				btn:SetPoint("TOPLEFT", self.button, "TOPLEFT", 5, -(max(height - btn:GetHeight(), 0) / 2))
			elseif nr == 0 then
				btn:SetPoint("TOPRIGHT", self.button, "TOPRIGHT", -5, -(max(height - btn:GetHeight(), 0) / 2))
			elseif self.orientation == 3 then
				btn:SetPoint("TOPLEFT", self.lastbtn, "TOPRIGHT", spacing, 0)
			else
				btn:SetPoint("TOPRIGHT", self.lastbtn, "TOPLEFT", -spacing, 0)
			end
			self.lastbtn = btn
			nr = nr + 1

			if self.mouseover then
				btn:Hide()
			else
				btn:Show()
			end
		else
			btn:Hide()
		end
	end

	self:AdjustTitle()
end

function barListPrototype:AdjustTitle(ignoreMouseover)
	self.button.text:SetJustifyH(self.orientation == 3 and "RIGHT" or "LEFT")
	self.button.text:SetJustifyV("MIDDLE")

	self.button.icon:ClearAllPoints()
	self.button.text:ClearAllPoints()

	if self.lastbtn and self.orientation == 3 then
		if self.mouseover and not ignoreMouseover then
			self.button.text:SetPoint("LEFT", self.button, "LEFT", 5, 0)
		else
			self.button.text:SetPoint("LEFT", self.lastbtn, "RIGHT")
		end
		self.button.icon:SetPoint("RIGHT", self.button, "RIGHT", -5, -1)
		self.button.text:SetPoint("RIGHT", self.button, "RIGHT", self.showButtonIcon and -23 or -5, 0)
	elseif self.lastbtn then
		self.button.icon:SetPoint("LEFT", self.button, "LEFT", 5, -1)
		self.button.text:SetPoint("LEFT", self.button, "LEFT", self.showButtonIcon and 23 or 5, 0)
		if self.mouseover and not ignoreMouseover then
			self.button.text:SetPoint("RIGHT", self.button, "RIGHT", -5, 0)
		else
			self.button.text:SetPoint("RIGHT", self.lastbtn, "LEFT")
		end
	else
		self.button.icon:SetPoint("LEFT", self.button, "LEFT", 5, -1)
		self.button.text:SetPoint("LEFT", self.button, "LEFT", self.showButtonIcon and 23 or 5, 0)
		self.button.text:SetPoint("RIGHT", self.button, "RIGHT", -5, 0)
	end
end

function barListPrototype:SetBarBackgroundColor(r, g, b, a)
	self.barbackgroundcolor[1] = r
	self.barbackgroundcolor[2] = g
	self.barbackgroundcolor[3] = b
	self.barbackgroundcolor[4] = a

	if bars[self] then
		for _, bar in pairs(bars[self]) do
			bar.bgtexture:SetVertexColor(unpack(self.barbackgroundcolor))
		end
	end
end

function barListPrototype:ShowButton(title, visible)
	for _, b in ipairs(self.buttons) do
		if b.title == title then
			b.visible = (visible == true)
			break
		end
	end
	self:AdjustButtons()
end

function barListPrototype:ShowButtons()
	for _, b in ipairs(self.buttons) do
		if not b:IsShown() and b.visible then
			b:Show()
		end
	end
end

function barListPrototype:HideButtons()
	for _, b in ipairs(self.buttons) do
		if b:IsShown() then
			b:Hide()
		end
	end
end

do
	local function move(self)
		local win = self:GetParent()
		if not win.locked then
			self.startX = win:GetLeft()
			self.startY = win:GetTop()
			win:StartMoving()
		end
	end

	local function stopMove(self)
		local win = self:GetParent()
		if not win.locked then
			win:StopMovingOrSizing()
			local endX = win:GetLeft()
			local endY = win:GetTop()
			if self.startX ~= endX or self.startY ~= endY then
				win.callbacks:Fire("AnchorMoved", win, endX, endY)
			end
		end
	end

	local function onSizeChanged(self, width)
		self:SetLength(width)
		self.callbacks:Fire("WindowResizing", self)
	end

	local function onMouseWheel(self, direction)
		local maxbars = self:GetMaxBars()
		local numbars = self:GetNumBars()
		local offset = self:GetBarOffset()

		if direction == 1 and offset > 0 then
			self:SetBarOffset(IsShiftKeyDown() and 0 or max(0, offset - (IsControlKeyDown() and maxbars or lib.scrollspeed)))
			self.callbacks:Fire("WindowScroll", self, direction)
		elseif direction == -1 and ((numbars - maxbars - offset) > 0) then
			if IsShiftKeyDown() then
				self:SetBarOffset(numbars - maxbars)
			else
				self:SetBarOffset(min(max(0, numbars - maxbars), offset + (IsControlKeyDown() and maxbars or lib.scrollspeed)))
			end
			self.callbacks:Fire("WindowScroll", self, direction)
		end
	end

	local DEFAULT_TEXTURE = [[Interface\TARGETINGFRAME\UI-StatusBar]]
	function lib:NewBarGroup(name, orientation, height, length, thickness, frameName)
		assert(self ~= lib, "You may only call :NewBarGroup as an embedded function")

		barLists[self] = barLists[self] or {}
		assert(barLists[self][name] == nil, "A bar list named " .. name .. " already exists.")

		orientation = orientation or 1
		orientation = (orientation == "LEFT") and 1 or orientation
		orientation = (orientation == "RIGHT") and 3 or orientation

		local list = setmetatable(CreateFrame("Frame", frameName, UIParent), barListPrototype_mt)
		list:SetMovable(true)
		list.enablemouse = true

		list.callbacks = list.callbacks or CallbackHandler:New(list)
		barLists[self][name] = list
		list.name = name

		local myfont = lib.defaultFont
		if not myfont then
			myfont = CreateFont("MyTitleFont")
			myfont:CopyFontObject(ChatFontSmall)
			lib.defaultFont = myfont
		end

		list.button = list.button or CreateFrame("Button", "$parentAnchor", list)
		list.button:SetText(name)
		list.button:SetBackdrop(frame_defaults)
		list.button:SetNormalFontObject(myfont)
		list.button.text = list.button:GetFontString()

		list.button.icon = list.button.icon or list.button:CreateTexture(nil, "ARTWORK")
		list.button.icon:SetTexCoord(0.094, 0.906, 0.094, 0.906)
		list.button.icon:SetPoint("LEFT", list.button, "LEFT", 5, 0)
		list.button.icon:SetSize(14, 14)

		list.length = length or 200
		list.thickness = thickness or 15

		list.button:SetScript("OnMouseDown", move)
		list.button:SetScript("OnMouseUp", stopMove)
		list.button:SetBackdropColor(0, 0, 0, 1)
		list.button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")

		list.buttons = {}

		list.barbackgroundcolor = {0.3, 0.3, 0.3, 0.6}
		list:SetPoint("TOPLEFT", UIParent, "CENTER", 0, 0)
		list:SetSize(length, height)
		list:SetResizable(true)
		list:SetMinResize(80, 60)
		list:SetMaxResize(500, 500)

		list.showIcon = true
		list.showLabel = true
		list.showTimerLabel = true

		list.lastBar = list

		list.texture = DEFAULT_TEXTURE
		list.spacing = 0
		list.offset = 0

		-- resize to the right
		if not list.resizeright then
			list.resizeright = CreateFrame("Button", "$parentRightResizer", list)
			list.resizeright:SetFrameLevel(list:GetFrameLevel() + 3)
			list.resizeright:SetSize(12, 12)
			list.resizeright:SetAlpha(0)
			list.resizeright.icon = list.resizeright:CreateTexture("$parentIcon", "OVERLAY")
			list.resizeright.icon:SetAllPoints(list.resizeright)
			list.resizeright.icon:SetTexture(ICON_RESIZE)
			list.resizeright.icon:SetVertexColor(0.6, 0.6, 0.6, 0.7)
		end

		-- resize to the left
		if not list.resizeleft then
			list.resizeleft = CreateFrame("Button", "$parentLeftResizer", list)
			list.resizeleft:SetFrameLevel(list:GetFrameLevel() + 3)
			list.resizeleft:SetSize(12, 12)
			list.resizeleft:SetAlpha(0)
			list.resizeleft.icon = list.resizeleft:CreateTexture("$parentIcon", "OVERLAY")
			list.resizeleft.icon:SetAllPoints(list.resizeleft)
			list.resizeleft.icon:SetTexture(ICON_RESIZE)
			list.resizeleft.icon:SetVertexColor(0.6, 0.6, 0.6, 0.7)
		end

		-- lock button
		if not list.lockbutton then
			list.lockbutton = CreateFrame("Button", "$parentLockButton", list)
			list.lockbutton:SetPoint("BOTTOM", list, "BOTTOM", 0, 2)
			list.lockbutton:SetFrameLevel(list:GetFrameLevel() + 5)
			list.lockbutton:SetSize(12, 12)
			list.lockbutton:SetAlpha(0)
			list.lockbutton.icon = list.lockbutton:CreateTexture("$parentIcon", "OVERLAY")
			list.lockbutton.icon:SetAllPoints(list.lockbutton)
			list.lockbutton.icon:SetTexture(ICON_LOCK)
			list.lockbutton.icon:SetVertexColor(0.6, 0.6, 0.6, 0.7)
		end

		list:SetMouseEnter(false)
		list:SetScript("OnSizeChanged", onSizeChanged)

		list:EnableMouseWheel(true)
		list:SetScript("OnMouseWheel", onMouseWheel)

		list:SetOrientation(orientation)
		list:ReverseGrowth(false)

		return list
	end
end

do
	local function listOnEnter(self)
		self.lockbutton:SetAlpha(1)
		if not self.locked then
			self.resizeright:SetAlpha(1)
			self.resizeleft:SetAlpha(1)
		end
	end

	local function listOnLeave(self)
		GameTooltip:Hide()
		self.lockbutton:SetAlpha(0)
		self.resizeright:SetAlpha(0)
		self.resizeleft:SetAlpha(0)
	end

	local strfind = strfind or string.find
	local function sizerOnMouseDown(self, button)
		if button == "LeftButton" then
			local p = self:GetParent()
			if not self.direction then
				self.direction = strfind(self:GetName(), "Left") and "LEFT" or "RIGHT"
			end
			p.isResizing = true
			if IsShiftKeyDown() then
				p:StartSizing(self.direction)
			elseif IsAltKeyDown() then
				p:StartSizing(p.growup and "TOP" or "BOTTOM")
			else
				p:StartSizing((p.growup and "TOP" or "BOTTOM") .. self.direction)
			end
		end
	end

	local function sizerOnMouseUp(self, button)
		if button == "LeftButton" then
			local p = self:GetParent()
			if p.isResizing then
				p.isResizing = nil
				local top, left = p:GetTop(), p:GetLeft()
				p:StopMovingOrSizing()
				p:SetLength(p:GetLength())
				p.callbacks:Fire("WindowResized", p)
				p:SortBars()
			end
		end
	end

	local function sizerOnEnter(self)
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint("BOTTOM", self, "TOP", 0, 0)
		GameTooltip:ClearLines()
		GameTooltip:AddLine(L.resize_header)
		GameTooltip:AddLine(L.resize_click, 1, 1, 1)
		GameTooltip:AddLine(L.resize_shift_click, 1, 1, 1)
		GameTooltip:AddLine(L.resize_alt_click, 1, 1, 1)
		GameTooltip:Show()
		listOnEnter(self:GetParent())
		self.icon:SetVertexColor(1, 1, 1, 0.7)
	end

	local function sizerOnLeave(self)
		listOnLeave(self:GetParent())
		self.icon:SetVertexColor(0.6, 0.6, 0.6, 0.7)
	end

	local function lockOnEnter(self)
		local p = self:GetParent()
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint("BOTTOM", self, "TOP", 0, 0)
		GameTooltip:ClearLines()
		GameTooltip:AddLine(p.name)
		GameTooltip:AddLine(p.locked and L.unlock_window or L.lock_window, 1, 1, 1)
		GameTooltip:Show()
		listOnEnter(self:GetParent())
		self.icon:SetVertexColor(1, 1, 1, 0.7)
	end

	local function lockOnLeave(self)
		listOnLeave(self:GetParent())
		self.icon:SetVertexColor(0.6, 0.6, 0.6, 0.7)
	end

	local function lockOnClick(self)
		local p = self:GetParent()
		if p.locked then
			p:Unlock(true)
		else
			p:Lock(true)
		end
		lockOnEnter(self)
	end

	function barListPrototype:SetMouseEnter(enable)
		if not enable then
			-- window
			self:SetScript("OnEnter", nil)
			self:SetScript("OnLeave", nil)

			-- lock button
			self.lockbutton:SetScript("OnClick", nil)
			self.lockbutton:SetScript("OnEnter", nil)
			self.lockbutton:SetScript("OnLeave", nil)
			self.lockbutton:Hide()

			-- left resizer
			self.resizeleft:SetScript("OnMouseDown", nil)
			self.resizeleft:SetScript("OnMouseUp", nil)
			self.resizeleft:SetScript("OnEnter", nil)
			self.resizeleft:SetScript("OnLeave", nil)
			self.resizeleft:Hide()

			-- right resizer
			self.resizeright:SetScript("OnMouseDown", nil)
			self.resizeright:SetScript("OnMouseUp", nil)
			self.resizeright:SetScript("OnEnter", nil)
			self.resizeright:SetScript("OnLeave", nil)
			self.resizeright:Hide()
		else
			-- window
			self:SetScript("OnEnter", listOnEnter)
			self:SetScript("OnLeave", listOnLeave)

			-- lock button
			self.lockbutton:SetScript("OnClick", lockOnClick)
			self.lockbutton:SetScript("OnEnter", lockOnEnter)
			self.lockbutton:SetScript("OnLeave", lockOnLeave)
			self.lockbutton:Show()

			-- left resizer
			self.resizeleft:SetScript("OnMouseDown", sizerOnMouseDown)
			self.resizeleft:SetScript("OnMouseUp", sizerOnMouseUp)
			self.resizeleft:SetScript("OnEnter", sizerOnEnter)
			self.resizeleft:SetScript("OnLeave", sizerOnLeave)
			self.resizeleft:Show()

			-- right resizer
			self.resizeright:SetScript("OnMouseDown", sizerOnMouseDown)
			self.resizeright:SetScript("OnMouseUp", sizerOnMouseUp)
			self.resizeright:SetScript("OnEnter", sizerOnEnter)
			self.resizeright:SetScript("OnLeave", sizerOnLeave)
			self.resizeright:Show()
		end
	end
end

function lib:GetBarGroups()
	return barLists[self]
end

function lib:GetBarGroup(name)
	return barLists[self] and barLists[self][name]
end

---[[ BarList prototype ]]---
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

	bar:EnableMouse(self.enablemouse)
	return bar, isNew
end

function barListPrototype:SetEnableMouse(enablemouse)
	self.enablemouse = enablemouse or nil

	self:EnableMouse(self.enablemouse)
	self.button:EnableMouse(self.enablemouse)
	self.resizeright:EnableMouse(self.enablemouse)
	self.resizeleft:EnableMouse(self.enablemouse)
	self.lockbutton:EnableMouse(self.enablemouse)

	if bars[self] then
		for _, bar in pairs(bars[self]) do
			bar:EnableMouse(self.enablemouse)
		end
	end
end

function barListPrototype:SetBarHeight(height)
	self:SetThickness(height)
end

function barListPrototype:NewBar(name, text, value, maxVal, icon)
	local bar, isNew = self:NewBarFromPrototype(barPrototype, name, text, value, maxVal, icon, self.orientation, self.length, self.thickness)
	bar.bgtexture:SetVertexColor(unpack(self.barbackgroundcolor))
	return bar, isNew
end

function barListPrototype:SetShown(show)
	if show and not self:IsShown() then
		self:Show()
	elseif not show and self:IsShown() then
		self:Hide()
	end
end

function barListPrototype:Lock(fireEvent)
	self.locked = true

	self.resizeright:Hide()
	self.resizeleft:Hide()
	self.lockbutton.icon:SetTexture(ICON_UNLOCK)

	if fireEvent then
		self.callbacks:Fire("WindowLocked", self, self.locked)
	end
end

function barListPrototype:Unlock(fireEvent)
	self.locked = nil

	self.resizeright:Show()
	self.resizeleft:Show()
	self.lockbutton.icon:SetTexture(ICON_LOCK)

	if fireEvent then
		self.callbacks:Fire("WindowLocked", self, self.locked)
	end
end

function barListPrototype:IsLocked()
	return self.locked
end

function barListPrototype:GuessMaxBars(round)
	local maxBars = self:GetHeight() / (self.thickness + self.spacing)

	if self:IsAnchorVisible() then
		local height = self:GetHeight() + self.spacing
		maxBars = ((maxBars - 1) * ((height - self.button:GetHeight()) / height)) + 1
	end

	return round and floor(maxBars + 0.5) or floor(maxBars)
end

function barListPrototype:SetMaxBars(num, round)
	self.maxBars = ((num or 0) > 0) and floor(num) or self:GuessMaxBars(round)
	self:SortBars()
end

function barListPrototype:GetMaxBars()
	self.maxBars = self.maxBars or self:GuessMaxBars()
	return self.maxBars
end

function barListPrototype:SetTexture(tex)
	self.texture = tex
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v:SetTexture(tex)
		end
	end
end

function barListPrototype:SetFont(f1, s1, m1, f2, s2, m2)
	self.font, self.fontSize, self.fontFlags = f1, s1, m1
	self.numfont, self.numfontSize, self.numfontFlags = f2 or f1, s2 or s1, m2 or m1
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v:SetFont(f1, s1, m1, f2, s2, m2)
		end
	end
end

function barListPrototype:SetFill(fill)
	self.fill = fill or nil
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v:SetFill(self.fill)
		end
	end
end

function barListPrototype:IsFilling()
	return self.fill
end

function barListPrototype:ShowButtonIcon()
	if not self.showButtonIcon then
		self.showButtonIcon = true
		self.button.icon:Show()
		self:AdjustTitle()
	end
end

function barListPrototype:HideButtonIcon()
	if self.showButtonIcon then
		self.showButtonIcon = nil
		self.button.icon:Hide()
		self:AdjustTitle()
	end
end

function barListPrototype:SetButtonIcon(icon)
	self.button.icon:SetTexture(icon)
end

function barListPrototype:ShowIcon()
	self.showIcon = true
	if bars[self] then
		for _, bar in pairs(bars[self]) do
			bar:ShowIcon()
		end
	end
end

function barListPrototype:HideIcon()
	self.showIcon = nil
	if bars[self] then
		for _, bar in pairs(bars[self]) do
			bar:HideIcon()
		end
	end
end

function barListPrototype:IsIconShown()
	return self.showIcon
end

function barListPrototype:ShowLabel()
	self.showLabel = true
	if bars[self] then
		for _, bar in pairs(bars[self]) do
			bar:ShowLabel()
		end
	end
end

function barListPrototype:HideLabel()
	self.showLabel = nil
	if bars[self] then
		for _, bar in pairs(bars[self]) do
			bar:HideLabel()
		end
	end
end

function barListPrototype:IsLabelShown()
	return self.showLabel
end

function barListPrototype:ShowTimerLabel()
	self.showTimerLabel = true
	if bars[self] then
		for _, bar in pairs(bars[self]) do
			bar:ShowTimerLabel()
		end
	end
end

function barListPrototype:HideTimerLabel()
	self.showTimerLabel = nil
	if bars[self] then
		for _, bar in pairs(bars[self]) do
			bar:HideTimerLabel()
		end
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

function barListPrototype:RemoveBar(bar)
	lib.ReleaseBar(self, bar)
end

function barListPrototype:SetDisplayMax(val)
	self.displayMax = val
end

function barListPrototype:SetTextColor(r, g, b, a)
	self.textcolor = self.textcolor or {}
	self.textcolor[1] = r or 1
	self.textcolor[2] = g or 1
	self.textcolor[3] = b or 1
	self.textcolor[4] = a or 1
	self:UpdateTextColor()
end

function barListPrototype:UpdateTextColor()
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v.label:SetTextColor(unpack(self.textcolor))
			v.timerLabel:SetTextColor(unpack(self.textcolor))
		end
	end
end

function barListPrototype:UpdateColors()
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v:UpdateColor()
		end
	end
end

function barListPrototype:SetColorAt(at, r, g, b, a)
	self.colors = self.colors or {}
	if
		self.colors[1] ~= at or
		self.colors[2] ~= r or
		self.colors[3] ~= g or
		self.colors[4] ~= b or
		self.colors[5] ~= a
	then
		self.colors[1] = at
		self.colors[2] = r
		self.colors[3] = g
		self.colors[4] = b
		self.colors[5] = a
		ComputeGradient(self)
		self:UpdateColors()
	end
end

function barListPrototype:UnsetAllColors()
	if self.colors then
		wipe(self.colors)
	end
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
	local growup, lastBar = self.growup, self.lastBar
	if growup then
		return lastBar:GetLeft(), lastBar:GetTop() + lastBar:GetHeight()
	else
		return lastBar:GetLeft(), lastBar:GetBottom() - lastBar:GetHeight()
	end
end

function barListPrototype:ReverseGrowth(reverse)
	self.growup = reverse or nil

	self.button:ClearAllPoints()
	self.resizeright:ClearAllPoints()
	self.resizeleft:ClearAllPoints()
	self.lockbutton:ClearAllPoints()

	if self.growup then
		self.button:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT")
		self.button:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")

		self.resizeright.icon:SetTexCoord(0, 1, 1, 0)
		self.resizeright:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)

		self.resizeleft.icon:SetTexCoord(1, 0, 1, 0)
		self.resizeleft:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)

		self.lockbutton:SetPoint("TOP", self, "TOP", 0, -2)
	else
		self.button:SetPoint("TOPLEFT", self, "TOPLEFT")
		self.button:SetPoint("TOPRIGHT", self, "TOPRIGHT")

		self.resizeright.icon:SetTexCoord(0, 1, 0, 1)
		self.resizeright:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)

		self.resizeleft.icon:SetTexCoord(1, 0, 0, 1)
		self.resizeleft:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 0)

		self.lockbutton:SetPoint("BOTTOM", self, "BOTTOM", 0, 2)
	end

	self:SortBars()
end

function barListPrototype:HasReverseGrowth()
	return self.growup
end

function barListPrototype:SetReverseGrowth(reverse)
	self.growup = reverse or nil
end

function barListPrototype:UpdateOrientationLayout()
	local length, thickness = self.length, self.thickness
	barListPrototype.super.SetWidth(self, length)
	self.button:SetWidth(length)
	self:ReverseGrowth(self.growup)
end

function barListPrototype:SetLength(length)
	self.length = length
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v:SetLength(length)
			v:OnSizeChanged()
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

function barListPrototype:SetOrientation(o)
	assert(o >= 1 and o <= 4, "orientation must be 1-4")
	self.orientation = o
	if bars[self] then
		for k, v in pairs(bars[self]) do
			v:SetOrientation(self.orientation)
		end
	end
	self:UpdateOrientationLayout()
end

function barListPrototype:GetOrientation()
	return self.orientation
end

function barListPrototype:SetSortFunction(func)
	if self.sortFunc ~= func then
		assert(func == nil or type(func) == "function")
		self.sortFunc = func
	end
end

function barListPrototype:GetSortFunction(func)
	return self.sortFunc
end

function barListPrototype:SetBarOffset(offset)
	self.offset = offset
	self:SortBars()
end

function barListPrototype:GetBarOffset()
	return self.offset
end

function barListPrototype:SetUseSpark(use)
	self.usespark = use or nil
end

function barListPrototype:GetNumBars()
	local n = 0
	if bars[self] then
		for _, _ in pairs(bars[self]) do
			n = n + 1
		end
	end
	return n
end

do
	local values = {}

	local function sortFunc(a, b)
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
		local lastBar = self
		local ct = 0
		local has_fixed = nil

		if not bars[self] then
			return
		end
		for k, v in pairs(bars[self]) do
			ct = ct + 1
			values[ct] = v
			v:Hide()
			if v.fixed then
				has_fixed = true
			end
		end
		for i = ct + 1, #values do
			values[i] = nil
		end
		if #values == 0 then
			return
		end

		tsort(values, self.sortFunc or sortFunc)

		local orientation = self.orientation
		local growup = self.growup
		local spacing = self.spacing
		local startpoint = self:IsAnchorVisible() and self.button:GetHeight() or 0

		local from, to
		local thickness, showIcon = self.thickness, self.showIcon
		local offset = self.offset
		local x1, y1, x2, y2 = 0, startpoint, 0, startpoint
		local maxbars = min(#values, self.isStretching and self:GuessMaxBars() or self:GetMaxBars())

		local start, stop, step, fixnum
		if growup then
			from = "BOTTOM"
			to = "TOP"
			start = min(#values, maxbars + offset)
			stop = min(#values, 1 + offset)
			step = -1
			fixnum = start
		else
			from = "TOP"
			to = "BOTTOM"
			start = min(1 + offset, #values)
			stop = min(maxbars + offset, #values)
			step = 1
			fixnum = stop
		end

		-- Fixed bar replaces the last bar
		if has_fixed and fixnum < #values then
			for i = fixnum + 1, #values, 1 do
				if values[i].fixed then
					tinsert(values, fixnum, values[i])
					break
				end
			end
		end

		local shown = 0
		for i = start, stop, step do
			local origTo = to
			local v = values[i]
			if lastBar == self then
				to = from
				if growup then
					y1, y2 = startpoint, startpoint
				else
					y1, y2 = -startpoint, -startpoint
				end
			else
				if growup then
					y1, y2 = spacing, spacing
				else
					y1, y2 = -spacing, -spacing
				end
			end

			x1, x2 = 0, 0

			-- Silly hack to fix icon positions. I should just rewrite the whole thing, really. WTB energy.
			if showIcon and lastBar == self then
				if orientation == 1 then
					x1 = thickness
				else
					x2 = -thickness
				end
			end

			if shown <= maxbars and v then
				v:ClearAllPoints()

				v:SetPoint(from .. "LEFT", lastBar, to .. "LEFT", x1, y1)
				v:SetPoint(from .. "RIGHT", lastBar, to .. "RIGHT", x2, y2)

				v:Show()
				shown = shown + 1
				lastBar = v
			end

			to = origTo
		end

		self.lastBar = lastBar
	end
end
---[[ Bar Prototype ]]---

---[[ Bar methods ]] ---
do
	local function barClick(self, button)
		local parent = self:GetParent()
		if parent and parent.callbacks then
			parent.callbacks:Fire("BarClick", self, button)
		end
	end

	local function barEnter(self, motion)
		local parent = self:GetParent()
		if parent and parent.callbacks then
			parent.callbacks:Fire("BarEnter", self, motion)
		end
	end

	local function barLeave(self, motion)
		local parent = self:GetParent()
		if parent and parent.callbacks then
			parent.callbacks:Fire("BarLeave", self, motion)
		end
	end

	local DEFAULT_ICON = [[Interface\Icons\INV_Misc_QuestionMark]]
	function barPrototype:Create(text, value, maxVal, icon, orientation, length, thickness)
		self.callbacks = self.callbacks or CallbackHandler:New(self)

		self:SetScript("OnMouseDown", barClick)
		self:SetScript("OnEnter", barEnter)
		self:SetScript("OnLeave", barLeave)

		self:SetScript("OnSizeChanged", self.OnSizeChanged)
		self.texture = self.texture or self:CreateTexture(nil, "ARTWORK")

		self.spark = self.spark or self:CreateTexture(nil, "OVERLAY")
		self.spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
		self.spark:SetSize(10, 10)
		self.spark:SetBlendMode("ADD")
		self.spark:Hide()

		self.bgtexture = self.bgtexture or self:CreateTexture(nil, "BACKGROUND")
		self.bgtexture:SetAllPoints()
		self.bgtexture:SetVertexColor(0.3, 0.3, 0.3, 0.6)

		self.icon = self.icon or self:CreateTexture(nil, "OVERLAY")
		self.icon:SetPoint("LEFT", self, "LEFT", 0, 0)
		self:SetIcon(icon or DEFAULT_ICON)
		if icon then
			self:ShowIcon()
		end
		self.icon:SetTexCoord(0.094, 0.906, 0.094, 0.906)

		-- Lame frame solely used for handling mouse input on icon.
		self.iconFrame = self.iconFrame or CreateFrame("Frame", nil, self)
		self.iconFrame:SetAllPoints(self.icon)
		self.iconFrame:SetFrameLevel(self:GetFrameLevel() + 1)

		self.label = self.label or self:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
		self.label:SetWordWrap(false)
		self.label:SetText(text)
		self.label:ClearAllPoints()
		self.label:SetPoint("LEFT", self, "LEFT", 3, 0)
		self:ShowLabel()

		self.timerLabel = self.timerLabel or self:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
		self.timerLabel:ClearAllPoints()
		self.timerLabel:SetPoint("RIGHT", self, "RIGHT", -3, 0)
		self:SetTimerLabel("")
		self:HideTimerLabel()

		local f, s, m = self.label:GetFont()
		self.label:SetFont(f, s or 10, m)

		f, s, m = self.timerLabel:GetFont()
		self.timerLabel:SetFont(f, s or 10, m)

		self:SetScale(1)
		self:SetAlpha(1)

		self.length = length or 200
		self.thickness = thickness or 15
		self:SetOrientation(orientation or 1)

		self.value = value or 1
		self.maxValue = maxVal or self.value
		self:SetMaxValue(self.maxValue)
		self:SetValue(self.value)

		if self.updateFuncs then
			for i = 1, #self.updateFuncs do
				tremove(self.updateFuncs, i)
			end
		end
	end
end

barPrototype.SetWidth = barListPrototype.SetWidth
barPrototype.SetHeight = barListPrototype.SetHeight
barPrototype.SetSize = barListPrototype.SetSize

function barPrototype:OnBarReleased()
	self.callbacks:Fire("BarReleased", self, self.name)

	self.ownerGroup = nil
	self.fill = nil
	if self.colors then
		wipe(self.colors)
	end

	if self.gradMap then
		wipe(self.gradMap)
	end

	self.texture:SetVertexColor(1, 1, 1, 0)
	self:SetScript("OnEnter", nil)
	self:SetScript("OnLeave", nil)
	self:SetScript("OnUpdate", nil)
	self:SetParent(UIParent)
	self:ClearAllPoints()
	self:Hide()

	local f, s, m = ChatFontNormal:GetFont()
	self.label:SetFont(f, s or 10, m)
	self.timerLabel:SetFont(f, s or 10, m)

	if self.callbacks.insertQueue then
		for eventname, callbacks in pairs(self.callbacks.insertQueue) do
			wipe(callbacks)
		end
	end
	for eventname, callbacks in pairs(self.callbacks.events) do
		wipe(callbacks)
		if self.callbacks.OnUnused then
			self.callbacks:OnUnused(self, eventname)
		end
	end
end

function barPrototype:GetGroup()
	return self.ownerGroup
end

function barPrototype:OnSizeChanged()
	self:SetValue(self.value)
end

function barPrototype:SetFont(f1, s1, m1, f2, s2, m2)
	local font, size, flags = self.label:GetFont()
	self.label:SetFont(f1 or font, s1 or size, m1 or flags)

	font, size, flags = self.timerLabel:GetFont()
	self.timerLabel:SetFont(f2 or font, s2 or size, m2 or flags)
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
end

function barPrototype:ShowIcon()
	self.showIcon = true
	if self.icon then
		self.icon:Show()
	end
end

function barPrototype:HideIcon()
	self.showIcon = nil
	if self.icon then
		self.icon:Hide()
	end
end

function barPrototype:IsIconShown()
	return self.showIcon
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
	self.showLabel = nil
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
	self.showTimerLabel = nil
	self.timerLabel:Hide()
end

function barPrototype:IsValueLabelShown()
	return self.showTimerLabel
end

function barPrototype:SetTexture(texture)
	self.texture:SetTexture(texture)
	self.bgtexture:SetTexture(texture)
end

function barPrototype:SetBackgroundColor(r, g, b, a)
	a = a or .6
	if r and g and b and a then
		self.bgtexture:SetVertexColor(r, g, b, a)
	end
end

function barPrototype:SetColorAt(at, r, g, b, a)
	self.colors = self.colors or {}
	if
		self.colors[1] ~= at or
		self.colors[2] ~= r or
		self.colors[3] ~= g or
		self.colors[4] ~= b or
		self.colors[5] ~= a
	then
		self.colors[1] = at
		self.colors[2] = r
		self.colors[3] = g
		self.colors[4] = b
		self.colors[5] = a
		ComputeGradient(self)
		self:UpdateColor()
	end
end

function barPrototype:SetOpacity(a)
	self:SetColorAt(self.colors[1], self.colors[2], self.colors[3], self.colors[4], a or self.colors[5])
end

function barPrototype:UnsetAllColors()
	if self.colors then
		wipe(self.colors)
	end
end

do
	function barPrototype:UpdateOrientationLayout(orientation)
		local t = nil
		if orientation == 1 then
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
			t:SetPoint("RIGHT", self, "RIGHT", -3, 0)
			t:SetJustifyH("RIGHT")
			t:SetJustifyV("MIDDLE")

			t = self.label
			t:ClearAllPoints()
			t:SetPoint("LEFT", self, "LEFT", 3, 0)
			t:SetPoint("RIGHT", self.timerLabel, "LEFT", 0, 0)
			t:SetJustifyH("LEFT")
			t:SetJustifyV("MIDDLE")

			self.bgtexture:SetTexCoord(0, 1, 0, 1)
		elseif orientation == 2 then
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
			t:SetPoint("TOPLEFT", self.Label, "BOTTOMLEFT", 0, 0)
			t:SetJustifyH("CENTER")
			t:SetJustifyV("BOTTOM")

			self.bgtexture:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
		elseif orientation == 3 then
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
			t:SetPoint("LEFT", self, "LEFT", 3, 0)
			t:SetJustifyH("LEFT")
			t:SetJustifyV("MIDDLE")

			t = self.label
			t:ClearAllPoints()
			t:SetPoint("RIGHT", self, "RIGHT", -3, 0)
			t:SetPoint("LEFT", self.timerLabel, "RIGHT", 0, 0)
			t:SetJustifyH("RIGHT")
			t:SetJustifyV("MIDDLE")

			self.bgtexture:SetTexCoord(0, 1, 0, 1)
		elseif orientation == 4 then
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
	local function updateSize(self, length, thickness)
		if length then
			local iconSize = self.showIcon and thickness or 0
			local width = max(0.0001, length - iconSize)
			barPrototype.super.SetWidth(self, width)
		end

		if thickness then
			barPrototype.super.SetHeight(self, thickness)
			self.icon:SetSize(thickness, thickness)
		end
	end

	function barPrototype:SetLength(length)
		updateSize(self, length)
	end

	function barPrototype:SetThickness(thickness)
		updateSize(self, nil, thickness)
	end
end

function barPrototype:GetThickness()
	return self.thickness
end

function barPrototype:SetOrientation(o)
	self:UpdateOrientationLayout(o)
	self:SetThickness(self.thickness)
end

function barPrototype:GetOrientation()
	return self.orientation
end

function barPrototype:SetValue(val)
	assert(val ~= nil, "value cannot be nil!")
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
	local amt = min(1, val / max(displayMax, 0.000001))
	local dist = (ownerGroup and ownerGroup:GetLength()) or self.length
	amt = max(amt, 0.000001)

	if ownerGroup then
		-- smoothing
		if ownerGroup.smoothing and self.lastamount then
			self:SetTextureTarget(amt, dist)
		else
			self.lastamount = amt
			self:SetTextureValue(amt, dist)
		end
		-- spark
		if ownerGroup.usespark and self.spark then
			if amt == 1 or amt <= 0.000001 then
				self.spark:Hide()
			else
				self.spark:Show()
			end
		end
	end

	self:UpdateColor()
end

function barPrototype:SetTextureTarget(amt, dist)
	self.targetamount = amt
	self.targetdist = dist
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

function barPrototype:SetFill(fill)
	self.fill = fill or nil
end

function barPrototype:UpdateColor()
	local amt = floor(self.value / max(self.maxValue, 0.000001) * 200) * 4
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

function barPrototype:AddOnUpdate(f)
	self.updateFuncs = self.updateFuncs or {}
	tinsert(self.updateFuncs, f)
	self:SetScript("OnUpdate", self.OnUpdate)
end

function barPrototype:RemoveOnUpdate(f)
	if self.updateFuncs then
		for i = 1, #self.updateFuncs do
			if f == self.updateFuncs[i] then
				tremove(self.updateFuncs, i)
				if #self.updateFuncs == 0 then
					self:SetScript("OnUpdate", nil)
				end
				return
			end
		end
	end
end

function barPrototype.OnUpdate(f, t)
	if f and f.updateFuncs then
		for i = 1, #f.updateFuncs do
			local func = f.updateFuncs[i]
			if func then
				func(f, t)
			end
		end
	end
end

--- Finally: upgrade our old embeds
for target, v in pairs(lib.embeds) do
	lib:Embed(target)
end