--
-- **LibCompat-1.0** provided few handy functions that can be embed to addons.
-- This library was originally created for Skada as of 1.8.50.
-- @author: Kader B (https://github.com/bkader/LibCompat-1.0)
--

local MAJOR, MINOR = "LibCompat-1.0", 25
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.embeds = lib.embeds or {}
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)

local pairs, ipairs, select, type = pairs, ipairs, select, type
local tinsert, tremove, tconcat, wipe = table.insert, table.remove, table.concat, wipe
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local format = format or string.format
local strlen = strlen or string.len
local strmatch = strmatch or string.match
local tostring, tonumber = tostring, tonumber
local setmetatable = setmetatable
local CreateFrame = CreateFrame
local error = error

local GAME_LOCALE = GetLocale()
GAME_LOCALE = (GAME_LOCALE == "enGB") and "enUS" or GAME_LOCALE

local QuickDispatch
local IsInGroup, IsInRaid
local GetUnitIdFromGUID
local tLength
local WithinRange

local NOOP = function() end

-------------------------------------------------------------------------------

do
	local tmp = {}
	local function _print(self, frame, ...)
		local n = 0
		if self ~= lib then
			n = n + 1
			tmp[n] = "|cff33ff99" .. tostring(self) .. "|r:"
		end
		for i = 1, select("#", ...) do
			n = n + 1
			tmp[n] = tostring(select(i, ...))
		end
		frame:AddMessage(tconcat(tmp, " ", 1, n))
	end

	function lib:Print(...)
		local frame = ...
		if type(frame) == "table" and frame.AddMessage then
			return _print(self, frame, select(2, ...))
		end
		return _print(self, DEFAULT_CHAT_FRAME, ...)
	end

	function lib:Printf(...)
		local frame = ...
		if type(frame) == "table" and frame.AddMessage then
			return _print(self, frame, format(select(2, ...)))
		else
			return _print(self, DEFAULT_CHAT_FRAME, format(...))
		end
	end
end

-------------------------------------------------------------------------------
-- Lua Memoize

do
	local unpack = unpack
	local getmetatable = getmetatable
	local memoizedFunc = {}

	local function isCallable(func)
		-- function or method?
		if type(func) == "function" then
			return true
		end
		-- maybe a metatable.
		if type(func) == "table" then
			local mt = getmetatable(func)
			return (type(mt) == "table" and isCallable(mt.__call))
		end
		return false
	end

	local function cacheGet(cache, params)
		local node = cache
		for i = 1, #params do
			node = node.children and node.children[params[i]]
			if not node then
				return nil
			end
		end
		return node.results
	end

	local function cachePut(cache, params, results)
		local node = cache
		local i = 1
		local param = params[i]
		while param do
			node.children = node.children or {}
			node.children[param] = node.children[param] or {}
			node = node.children[param]
			i = i + 1
			param = params[i]
		end
		node.results = results
	end

	local function memoize(func, cache)
		if not isCallable(func) then
			error(("Only functions and callable tables are memoizable. Received %s (a %s)"):format(tostring(func), type(func)), 2)
		end

		cache = cache or memoizedFunc[func]
		if not cache then
			memoizedFunc[func] = {}
			cache = memoizedFunc[func]
		end

		return function(...)
			local params = {...}
			local results = cacheGet(cache, params)
			if not results then
				results = {func(...)}
				cachePut(cache, params, results)
			end
			return unpack(results)
		end
	end

	lib.memoize = memoize
end

-------------------------------------------------------------------------------

do
	local pcall = pcall

	local function dispatchError(err)
		print("|cffff9900Error|r:" .. (err or "<no error given>"))
	end

	function QuickDispatch(func, ...)
		if type(func) ~= "function" then return end
		local ok, err = pcall(func, ...)
		if not ok then
			dispatchError(err)
			return
		end
		return true
	end

	lib.QuickDispatch = QuickDispatch
end

-------------------------------------------------------------------------------

do
	local function SafePack(...)
		local tbl = {...}
		tbl.n = select("#", ...)
		return tbl
	end

	local function SafeUnpack(tbl)
		return unpack(tbl, 1, tbl.n)
	end

	function tLength(tbl)
		local len = 0
		for _ in pairs(tbl) do
			len = len + 1
		end
		return len
	end

	-- copies a table from another
	local function tCopy(to, from, ...)
		for k, v in pairs(from) do
			local skip = false
			if ... then
				for _, j in ipairs(...) do
					if j == k then
						skip = true
						break
					end
				end
			end
			if not skip then
				if type(v) == "table" then
					to[k] = {}
					tCopy(to[k], v, ...)
				else
					to[k] = v
				end
			end
		end
	end

	local function tInvert(tbl)
		local inverted = {}
		for k, v in pairs(tbl) do
			inverted[v] = k
		end
		return inverted
	end

	local function tIndexOf(tbl, item)
		for i, v in ipairs(tbl) do
			if item == v then
				return i
			end
		end
	end

	-- replace the global function
	_G.tContains = function(tbl, item)
		return (tIndexOf(tbl, item) ~= nil)
	end

	local function tAppendAll(tbl, elems)
		for _, elem in ipairs(elems) do
			tinsert(tbl, elem)
		end
	end

	local weaktable = {__mode = "v"}
	local function WeakTable(t)
		return setmetatable(wipe(t or {}), weaktable)
	end

	-- Shamelessly copied from Omen - thanks!
	local tablePool = lib.tablePool or setmetatable({}, {__mode = "kv"})
	lib.tablePool = tablePool

	-- get a new table
	local function newTable()
		local t = next(tablePool) or {}
		tablePool[t] = nil
		return t
	end

	-- delete table and return to pool
	local function delTable(t)
		if type(t) == "table" then
			for k, v in pairs(t) do
				if type(v) == "table" then
					delTable(v)
				end
				t[k] = nil
			end
			t[true] = true
			t[true] = nil
			tablePool[t] = true
		end
		return nil
	end

	lib.SafePack = SafePack
	lib.SafeUnpack = SafeUnpack
	lib.tLength = tLength
	lib.tCopy = tCopy
	lib.tInvert = tInvert
	lib.tIndexOf = tIndexOf
	lib.tAppendAll = tAppendAll
	lib.WeakTable = WeakTable
	lib.newTable = newTable
	lib.delTable = delTable
end

-------------------------------------------------------------------------------

do
	local function Lerp(startValue, endValue, amount)
		return (1 - amount) * startValue + amount * endValue
	end

	local function Round(val)
		return (val < 0.0) and ceil(val - 0.5) or floor(val + 0.5)
	end

	local function Square(val)
		return val * val
	end

	local function Clamp(val, minval, maxval)
		return min(maxval or 1, max(minval or 0, val))
	end

	function WithinRange(val, minval, maxval)
		return val >= minval and val <= maxval
	end

	local function WithinRangeExclusive(val, minval, maxval)
		return val > minval and val < maxval
	end

	lib.Lerp = Lerp
	lib.Round = Round
	lib.Square = Square
	lib.Clamp = Clamp
	lib.WithinRange = WithinRange
	lib.WithinRangeExclusive = WithinRangeExclusive
end

-------------------------------------------------------------------------------

do
	local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
	local UnitExists, UnitAffectingCombat, UnitIsDeadOrGhost = UnitExists, UnitAffectingCombat, UnitIsDeadOrGhost
	local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
	local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax

	function IsInRaid()
		return (GetNumRaidMembers() > 0)
	end

	function IsInGroup()
		return (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0)
	end

	local function GetNumGroupMembers()
		return IsInRaid() and GetNumRaidMembers() or GetNumPartyMembers()
	end

	local function GetNumSubgroupMembers()
		return GetNumPartyMembers()
	end

	local function GetGroupTypeAndCount()
		if IsInRaid() then
			return "raid", 1, GetNumRaidMembers()
		elseif IsInGroup() then
			return "party", 0, GetNumPartyMembers()
		else
			return nil, 0, 0
		end
	end

	local UnitIterator
	do
		local rmem, pmem, step, count

		local function SelfIterator()
			while step do
				local unit, owner
				if step == 1 then
					unit, owner, step = "player", nil, 2
				elseif step == 2 then
					unit, owner, step = "playerpet", "player", nil
				end
				if unit and UnitExists(unit) then
					return unit, owner
				end
			end
		end

		local function PartyIterator()
			while step do
				local unit, owner
				if step <= 2 then
					unit, owner = SelfIterator()
					step = step or 3
				elseif step == 3 then
					unit, owner, step = format("party%d", count), nil, 4
				elseif step == 4 then
					unit, owner = format("partypet%d", count), format("party%d", count)
					count = count + 1
					step = count <= pmem and 3 or nil
				end
				if unit and UnitExists(unit) then
					return unit, owner
				end
			end
		end

		local function RaidIterator()
			while step do
				local unit, owner
				if step == 1 then
					unit, owner, step = format("raid%d", count), nil, 2
				elseif step == 2 then
					unit, owner = format("raidpet%d", count), format("raid%d", count)
					count = count + 1
					step = count <= rmem and 1 or nil
				end
				if unit and UnitExists(unit) then
					return unit, owner
				end
			end
		end

		function UnitIterator()
			rmem, step = GetNumRaidMembers(), 1
			if rmem == 0 then
				pmem = GetNumPartyMembers()
				if pmem == 0 then
					return SelfIterator, false
				end
				count = 1
				return PartyIterator, false
			end
			count = 1
			return RaidIterator, true
		end
	end

	local function IsGroupDead()
		for unit in UnitIterator() do
			if not UnitIsDeadOrGhost(unit) then
				return false
			end
		end
		return true
	end

	local function IsGroupInCombat()
		for unit in UnitIterator() do
			if UnitAffectingCombat(unit) then
				return true
			end
		end
		return false
	end

	local function GroupIterator(func, ...)
		for unit, owner in UnitIterator() do
			QuickDispatch(func, unit, owner, ...)
		end
	end

	local MAX_BOSS_FRAMES = MAX_BOSS_FRAMES or 5

	function GetUnitIdFromGUID(guid, filter)
		if filter == nil or filter == "boss" then
			for i = 1, MAX_BOSS_FRAMES do
				if UnitExists("boss" .. i) and UnitGUID("boss" .. i) == guid then
					return "boss" .. i
				end
			end
			if filter == "boss" then return end
		end

		if filter == nil or filter == "player" then
			if UnitExists("target") and UnitGUID("target") == guid then
				return "target"
			elseif UnitExists("focus") and UnitGUID("focus") == guid then
				return "focus"
			elseif UnitExists("targettarget") and UnitGUID("targettarget") == guid then
				return "targettarget"
			elseif UnitExists("focustarget") and UnitGUID("focustarget") == guid then
				return "focustarget"
			elseif UnitExists("mouseover") and UnitGUID("mouseover") == guid then
				return "mouseover"
			elseif filter == "player" then return end
		end

		if filter == nil or filter == "group" then
			for unit, owner in UnitIterator() do
				if UnitGUID(unit) == guid then
					return unit
				elseif UnitExists(unit .. "target") and UnitGUID(unit .. "target") == guid then
					return unit .. "target"
				elseif owner and UnitGUID(owner) == guid then
					return owner
				elseif owner and UnitGUID(owner .. "target") == guid then
					return owner .. "target"
				end
			end
			if filter == "group" then return end
		end
	end

	local function GetClassFromGUID(guid, filter)
		local unit = GetUnitIdFromGUID(guid, filter)
		local class
		if unit and unit:find("pet") then
			class = "PET"
		elseif unit and unit:find("boss") then
			class = "BOSS"
		elseif unit then
			class = select(2, UnitClass(unit))
		end
		return class, unit
	end

	local function GetCreatureId(guid)
		return guid and tonumber(guid:sub(9, 12), 16) or 0
	end

	local function GetUnitCreatureId(unit)
		return GetCreatureId(UnitGUID(unit))
	end

	local unknownUnits = {[UKNOWNBEING] = true, [UNKNOWNOBJECT] = true}

	local function UnitHealthInfo(unit, guid, filter)
		unit = (unit and not unknownUnits[unit]) and unit or (guid and GetUnitIdFromGUID(guid, filter))
		local percent, health, maxhealth
		if unit and UnitExists(unit) then
			health, maxhealth = UnitHealth(unit), UnitHealthMax(unit)
			if health and maxhealth then
				percent = 100 * health / max(1, maxhealth)
			end
		end
		return percent, health, maxhealth
	end

	local function UnitPowerInfo(unit, guid, powerType, filter)
		unit = (unit and not unknownUnits[unit]) and unit or (guid and GetUnitIdFromGUID(guid, filter))
		local percent, power, maxpower
		if unit and UnitExists(unit) then
			power, maxpower = UnitPower(unit, powerType), UnitPowerMax(unit, powerType)
			if power and maxpower then
				percent = 100 * power / max(1, maxpower)
			end
		end
		return percent, power, maxpower
	end

	local function UnitFullName(unit)
		local name, realm = UnitName(unit)
		local namerealm = realm and realm ~= "" and name .. "-" .. realm or name
		return namerealm
	end

	lib.IsInRaid = IsInRaid
	lib.IsInGroup = IsInGroup
	lib.GetNumGroupMembers = GetNumGroupMembers
	lib.GetNumSubgroupMembers = GetNumSubgroupMembers
	lib.GetGroupTypeAndCount = GetGroupTypeAndCount
	lib.IsGroupDead = IsGroupDead
	lib.IsGroupInCombat = IsGroupInCombat
	lib.GroupIterator = GroupIterator
	lib.UnitIterator = UnitIterator
	lib.GetUnitIdFromGUID = GetUnitIdFromGUID
	lib.GetClassFromGUID = GetClassFromGUID
	lib.GetCreatureId = GetCreatureId
	lib.GetUnitCreatureId = GetUnitCreatureId
	lib.UnitHealthInfo = UnitHealthInfo
	lib.UnitHealthPercent = UnitHealthInfo -- backward compatibility
	lib.UnitPowerInfo = UnitPowerInfo
	lib.UnitFullName = UnitFullName
end

-------------------------------------------------------------------------------

do
	local IsRaidLeader, IsPartyLeader = IsRaidLeader, IsPartyLeader
	local GetPartyLeaderIndex, GetRaidRosterInfo = GetPartyLeaderIndex, GetRaidRosterInfo

	local function UnitIsGroupLeader(unit)
		if not IsInGroup() then
			return false
		elseif unit == "player" then
			return (IsInRaid() and IsRaidLeader() or IsPartyLeader())
		else
			local index = unit:match("%d+")
			if not index then -- to allow other units to be checked
				unit = GetUnitIdFromGUID(UnitGUID(unit), "group")
				index = unit and unit:match("%d+")
			end
			return (index and GetPartyLeaderIndex() == tonumber(index))
		end
	end

	local function UnitIsGroupAssistant(unit)
		if not IsInRaid() then
			return false
		else
			local index = unit:match("%d+")
			if not index then -- to allow other units to be checked
				unit = GetUnitIdFromGUID(UnitGUID(unit), "group")
				index = unit and unit:match("%d+")
			end
			return (index and select(2, GetRaidRosterInfo(index)) == 1)
		end
	end

	lib.UnitIsGroupLeader = UnitIsGroupLeader
	lib.UnitIsGroupAssistant = UnitIsGroupAssistant
end

-------------------------------------------------------------------------------
-- Color functions

local HexToRGB, RGBToHex
local HexToRGBPerc, RGBPercToHex
do
	function HexToRGB(hex)
		local rhex, ghex, bhex
		if strlen(hex) == 6 then
			rhex, ghex, bhex = strmatch("([a-fA-F0-9]{2})([a-fA-F0-9]{2})([a-fA-F0-9]{2})", hex)
		elseif strlen(hex) == 3 then
			rhex, ghex, bhex = strmatch("([a-fA-F0-9])([a-fA-F0-9])([a-fA-F0-9])", hex)
			if rhex and ghex and bhex then
				rhex = rhex .. rhex
				ghex = ghex .. ghex
				bhex = bhex .. bhex
			end
		end
		if not (rhex and ghex and bhex) then
			return 0, 0, 0
		else
			return tonumber(rhex, 16), tonumber(ghex, 16), tonumber(bhex, 16)
		end
	end

	function RGBToHex(r, g, b)
		r = r <= 255 and r >= 0 and r or 0
		g = g <= 255 and g >= 0 and g or 0
		b = b <= 255 and b >= 0 and b or 0
		return format("%02x%02x%02x", r, g, b)
	end

	function HexToRGBPerc(hex)
		local rhex, ghex, bhex, base
		if strlen(hex) == 6 then
			rhex, ghex, bhex = strmatch("([a-fA-F0-9]{2})([a-fA-F0-9]{2})([a-fA-F0-9]{2})", hex)
			base = 255
		elseif strlen(hex) == 3 then
			rhex, ghex, bhex = strmatch("([a-fA-F0-9])([a-fA-F0-9])([a-fA-F0-9])", hex)
			base = 16
		end
		if not (rhex and ghex and bhex) then
			return 0, 0, 0
		else
			return tonumber(rhex, 16) / base, tonumber(ghex, 16) / base, tonumber(bhex, 16) / base
		end
	end

	function RGBPercToHex(r, g, b)
		r = r <= 1 and r >= 0 and r or 0
		g = g <= 1 and g >= 0 and g or 0
		b = b <= 1 and b >= 0 and b or 0
		return format("%02x%02x%02x", r * 255, g * 255, b * 255)
	end

	lib.HexToRGB = HexToRGB
	lib.RGBToHex = RGBToHex
	lib.HexToRGBPerc = HexToRGBPerc
	lib.RGBPercToHex = RGBPercToHex
end

-------------------------------------------------------------------------------
-- Classes & Colors

do
	local classColorsTable, classInfoTable
	local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	local CLASS_SORT_ORDER = CLASS_SORT_ORDER

	-- the functions below are for internal usage only
	local function __fillClassColorsTable()
		if classColorsTable ~= nil then return end
		classColorsTable = {}
		for class, tbl in pairs(colors) do
			classColorsTable[class] = tbl
			classColorsTable[class].colorStr = "ff" .. RGBPercToHex(tbl.r, tbl.g, tbl.b)
		end
	end

	local function __fillClassInfoTable()
		if classInfoTable ~= nil then return end

		classInfoTable = {
			WARRIOR = {classFile = "WARRIOR", classID = 1},
			PALADIN = {classFile = "PALADIN", classID = 2},
			HUNTER = {classFile = "HUNTER", classID = 3},
			ROGUE = {classFile = "ROGUE", classID = 4},
			PRIEST = {classFile = "PRIEST", classID = 5},
			DEATHKNIGHT = {classFile = "DEATHKNIGHT", classID = 6},
			SHAMAN = {classFile = "SHAMAN", classID = 7},
			MAGE = {classFile = "MAGE", classID = 8},
			WARLOCK = {classFile = "WARLOCK", classID = 9},
			DRUID = {classFile = "DRUID", classID = 11}
		}

		-- fill names
		for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
			if classInfoTable[k] then
				classInfoTable[k].className = v
			end
		end
	end

	local function GetClassColorsTable()
		if classColorsTable == nil then
			__fillClassColorsTable()
		end

		return classColorsTable
	end

	local function GetClassColorObj(class)
		if classColorsTable == nil then
			__fillClassColorsTable()
		end

		return class and classColorsTable[class]
	end

	local function GetClassColor(class)
		local obj = GetClassColorObj(class)
		if obj then
			return obj.r, obj.g, obj.b, obj.colorStr
		end
		return 1, 1, 1, "ffffffff"
	end

	local function GetNumClasses()
		return CLASS_SORT_ORDER and #CLASS_SORT_ORDER or tLength(colors)
	end

	local function GetClassInfo(classIndex)
		if classInfoTable == nil then
			__fillClassInfoTable()
		end

		local className, classFile, classID
		if classIndex then
			for _, class in pairs(classInfoTable) do
				if class.classID == classIndex then
					className = class.className or class.classFile
					classFile = class.classFile
					classID = class.classID
					break
				end
			end
		end
		return className, classFile, classID
	end

	lib.GetClassColorsTable = GetClassColorsTable
	lib.GetClassColorObj = GetClassColorObj
	lib.GetClassColor = GetClassColor
	lib.GetNumClasses = GetNumClasses
	lib.GetClassInfo = GetClassInfo
end

-------------------------------------------------------------------------------
-- C_Timer mimic

do
	local Timer = {}

	local TickerPrototype = {}
	local TickerMetatable = {
		__index = TickerPrototype,
		__metatable = true
	}

	local WaitTable = {}

	local new, del
	do
		Timer.__timers = Timer.__timers or {}
		Timer.__afters = Timer.__afters or {}
		local listT = Timer.__timers
		local listA = Timer.__afters

		function new(temp)
			if temp then
				local t = next(listA) or {}
				listA[t] = nil
				return t
			end

			local t = next(listT) or setmetatable({}, TickerMetatable)
			listT[t] = nil
			return t
		end

		function del(t)
			if t then
				local temp = t._temp
				t[true] = true
				t[true] = nil
				if temp then
					listA[t] = true
				else
					listT[t] = true
				end
			end
		end
	end

	local function WaitFunc(self, elapsed)
		local total = #WaitTable
		local i = 1

		while i <= total do
			local ticker = WaitTable[i]

			if ticker._cancelled then
				del(tremove(WaitTable, i))
				total = total - 1
			elseif ticker._delay > elapsed then
				ticker._delay = ticker._delay - elapsed
				i = i + 1
			else
				ticker._callback(ticker)

				if ticker._remainingIterations == -1 then
					ticker._delay = ticker._duration
					i = i + 1
				elseif ticker._remainingIterations > 1 then
					ticker._remainingIterations = ticker._remainingIterations - 1
					ticker._delay = ticker._duration
					i = i + 1
				elseif ticker._remainingIterations == 1 then
					del(tremove(WaitTable, i))
					total = total - 1
				end
			end
		end

		if #WaitTable == 0 then
			self:Hide()
		end
	end

	local WaitFrame = _G.LibCompat_WaitFrame or CreateFrame("Frame", "LibCompat_WaitFrame", UIParent)
	WaitFrame:SetScript("OnUpdate", WaitFunc)

	local function AddDelayedCall(ticker, oldTicker)
		ticker = (oldTicker and type(oldTicker) == "table") and oldTicker or ticker
		tinsert(WaitTable, ticker)
		WaitFrame:Show()
	end

	local function ValidateArguments(duration, callback, callFunc)
		if type(duration) ~= "number" then
			error(format(
				"Bad argument #1 to '" .. callFunc .. "' (number expected, got %s)",
				duration ~= nil and type(duration) or "no value"
			), 2)
		elseif type(callback) ~= "function" then
			error(format(
				"Bad argument #2 to '" .. callFunc .. "' (function expected, got %s)",
				callback ~= nil and type(callback) or "no value"
			), 2)
		end
	end

	function Timer.After(duration, callback, ...)
		ValidateArguments(duration, callback, "After")

		local ticker = new(true)

		ticker._remainingIterations = 1
		ticker._delay = max(0.01, duration)
		ticker._callback = callback
		ticker._cancelled = nil
		ticker._temp = true

		AddDelayedCall(ticker)
	end

	local function CreateTicker(duration, callback, iterations, ...)
		local ticker = new()

		ticker._remainingIterations = iterations or -1
		ticker._delay = max(0.01, duration)
		ticker._duration = ticker._delay
		ticker._callback = callback
		ticker._cancelled = nil

		AddDelayedCall(ticker)
		return ticker
	end

	function Timer.NewTicker(duration, callback, iterations, ...)
		ValidateArguments(duration, callback, "NewTicker")
		return CreateTicker(duration, callback, iterations, ...)
	end

	function Timer.NewTimer(duration, callback, ...)
		ValidateArguments(duration, callback, "NewTimer")
		return CreateTicker(duration, callback, 1, ...)
	end

	function Timer.CancelTimer(ticker)
		if ticker and ticker.Cancel then
			ticker:Cancel()
		end
		return nil
	end

	function TickerPrototype:Cancel()
		self._cancelled = true
	end
	function TickerPrototype:IsCancelled()
		return self._cancelled
	end

	lib.C_Timer = Timer
	-- backwards compatibility
	lib.After = Timer.After
	lib.NewTicker = Timer.NewTicker
	lib.NewTimer = Timer.NewTimer
	lib.CancelTimer = Timer.CancelTimer
end

-------------------------------------------------------------------------------

do
	local band, rshift, lshift = bit.band, bit.rshift, bit.lshift
	local byte, char = string.byte, string.char

	local function HexEncode(str, title)
		local hex = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
		local t = (title and title ~= "") and {format("[=== %s ===]", title)} or {}
		local j = 0
		for i = 1, #str do
			if j <= 0 then
				t[#t + 1], j = "\n", 32
			end
			j = j - 1

			local b = byte(str, i)
			t[#t + 1] = hex[band(b, 15) + 1]
			t[#t + 1] = hex[band(rshift(b, 4), 15) + 1]
		end
		if title and title ~= "" then
			t[#t + 1] = "\n" .. t[1]
		end
		return tconcat(t)
	end

	local function HexDecode(str)
		str = str:gsub("%[.-%]", ""):gsub("[^0123456789ABCDEF]", "")
		if (#str == 0) or (#str % 2 ~= 0) then
			return false, "Invalid Hex string"
		end

		local t, bl, bh = {}
		local i = 1
		repeat
			bl = byte(str, i)
			bl = bl >= 65 and bl - 55 or bl - 48
			i = i + 1
			bh = byte(str, i)
			bh = bh >= 65 and bh - 55 or bh - 48
			i = i + 1
			t[#t + 1] = char(lshift(bh, 4) + bl)
		until i >= #str
		return tconcat(t)
	end

	local function EscapeStr(str)
		local res = ""
		for i = 1, strlen(str) do
			local n = str:sub(i, i)
			res = res .. n
			if n == "|" then
				res = res .. "\124"
			end
		end
		return (res ~= "") and res or str
	end

	lib.HexEncode = HexEncode
	lib.HexDecode = HexDecode
	lib.EscapeStr = EscapeStr
end

-------------------------------------------------------------------------------

do
	local LGT = LibStub("LibGroupTalents-1.0")
	local UnitClass = UnitClass
	local GetSpellInfo = GetSpellInfo
	local MAX_TALENT_TABS = MAX_TALENT_TABS or 3
	local GetActiveTalentGroup = GetActiveTalentGroup
	local GetTalentTabInfo = GetTalentTabInfo
	local LGTRoleTable = {melee = "DAMAGER", caster = "DAMAGER", healer = "HEALER", tank = "TANK"}

	-- list of class to specs
	local specsTable = {
		["MAGE"] = {62, 63, 64},
		["PRIEST"] = {256, 257, 258},
		["ROGUE"] = {259, 260, 261},
		["WARLOCK"] = {265, 266, 267},
		["WARRIOR"] = {71, 72, 73},
		["PALADIN"] = {65, 66, 70},
		["DEATHKNIGHT"] = {250, 251, 252},
		["DRUID"] = {102, 103, 104, 105},
		["HUNTER"] = {253, 254, 255},
		["SHAMAN"] = {262, 263, 264}
	}

	local function GetSpecialization(isInspect, isPet, specGroup)
		local currentSpecGroup = GetActiveTalentGroup(isInspect, isPet) or (specGroup or 1)
		local points, specname, specid = 0, nil, nil

		for i = 1, MAX_TALENT_TABS do
			local name, _, pointsSpent = GetTalentTabInfo(i, isInspect, isPet, currentSpecGroup)
			if points <= pointsSpent then
				points = pointsSpent
				specname = name
				specid = i
			end
		end
		return specid, specname, points
	end

	-- checks if the feral druid is a cat or tank spec
	local function GetDruidSpec(unit)
		-- 57881 : Natural Reaction -- used by druid tanks
		local points = LGT:UnitHasTalent(unit, GetSpellInfo(57881), LGT:GetActiveTalentGroup(unit))
		return (points and points > 0) and 3 or 2
	end

	local function GetInspectSpecialization(unit, class)
		local spec  -- start with nil

		if unit and UnitExists(unit) then
			class = class or select(2, UnitClass(unit))
			if class and specsTable[class] then
				local talentGroup = LGT:GetActiveTalentGroup(unit)
				local maxPoints, index = 0, 0

				for i = 1, MAX_TALENT_TABS do
					local _, _, pointsSpent = LGT:GetTalentTabInfo(unit, i, talentGroup)
					if pointsSpent ~= nil then
						if maxPoints < pointsSpent then
							maxPoints = pointsSpent
							if class == "DRUID" and i >= 2 then
								if i == 3 then
									index = 4
								elseif i == 2 then
									index = GetDruidSpec(unit)
								end
							else
								index = i
							end
						end
					end
				end
				spec = specsTable[class][index]
			end
		end

		return spec
	end

	local function GetSpecializationRole(unit)
		return LGTRoleTable[LGT:GetUnitRole(unit or "player")] or "NONE"
	end

	local function GetSpecializationInfo(specIndex, isInspect, isPet, specGroup)
		local name, icon, _, background = GetTalentTabInfo(specIndex, isInspect, isPet, specGroup)
		local id, role
		if isInspect and UnitExists("target") then
			id, role = GetInspectSpecialization("target"), GetSpecializationRole("target")
		else
			id, role = GetInspectSpecialization("player"), GetSpecializationRole("player")
		end
		return id, name, nil, icon, background, role
	end

	local UnitGroupRolesAssigned = UnitGroupRolesAssigned
	local function _UnitGroupRolesAssigned(unit, class)
		unit = unit or "player" -- always fallback to player

		-- For LFG using "UnitGroupRolesAssigned" is enough.
		local isTank, isHealer, isDamager = UnitGroupRolesAssigned(unit)
		if isTank then
			return "TANK"
		elseif isHealer then
			return "HEALER"
		elseif isDamager then
			return "DAMAGER"
		end

		-- speedup things using classes.
		class = class or select(2, UnitClass(unit))
		if class == "HUNTER" or class == "MAGE" or class == "ROGUE" or class == "WARLOCK" then
			return "DAMAGER"
		end

		return LGTRoleTable[LGT:GetUnitRole(unit or "player")] or "NONE"
	end

	local function GetGUIDRole(guid)
		return LGTRoleTable[LGT:GetGUIDRole(guid)] or "NONE"
	end

	lib.GetSpecialization = GetSpecialization
	lib.GetInspectSpecialization = GetInspectSpecialization
	lib.GetSpecializationRole = GetSpecializationRole
	lib.GetSpecializationInfo = GetSpecializationInfo

	lib.UnitGroupRolesAssigned = _UnitGroupRolesAssigned
	lib.GetUnitRole = _UnitGroupRolesAssigned
	lib.GetGUIDRole = GetGUIDRole
	lib.GetUnitSpec = GetInspectSpecialization

	-- functions that simply replaced other api functions
	lib.GetNumSpecializations = GetNumTalentTabs
	lib.GetNumSpecGroups = GetNumTalentGroups
	lib.GetNumUnspentTalents = GetUnspentTalentPoints
	lib.GetActiveSpecGroup = GetActiveTalentGroup
	lib.SetActiveSpecGroup = SetActiveTalentGroup
end

-------------------------------------------------------------------------------

do
	local C_PvP = {}
	local IsInInstance, instanceType = IsInInstance, nil

	function C_PvP.IsPvPMap()
		instanceType = select(2, IsInInstance())
		return (instanceType == "pvp" or instanceType == "arena")
	end

	function C_PvP.IsBattleground()
		instanceType = select(2, IsInInstance())
		return (instanceType == "pvp")
	end

	function C_PvP.IsArena()
		instanceType = select(2, IsInInstance())
		return (instanceType == "arena")
	end

	lib.IsInPvP = C_PvP.IsPvPMap
	lib.C_PvP = C_PvP
end

-------------------------------------------------------------------------------

do
	local function PassClickToParent(obj, ...)
		obj:GetParent():Click(...)
	end

	local function Mixin(obj, ...)
		for i = 1, select("#", ...) do
			local mixin = select(i, ...)
			for k, v in pairs(mixin) do
				obj[k] = v
			end
		end
		return obj
	end

	local function CreateFromMixins(...)
		return Mixin({}, ...)
	end

	local function CreateAndInitFromMixin(mixin, ...)
		local obj = CreateFromMixins(mixin)
		obj:Init(...)
		return obj
	end

	local ObjectPoolMixin = {}

	function ObjectPoolMixin:OnLoad(creationFunc, resetterFunc)
		self.creationFunc, self.resetterFunc = creationFunc, resetterFunc
		self.activeObjects, self.inactiveObjects = {}, {}
		self.numActiveObjects = 0
	end

	function ObjectPoolMixin:Acquire()
		local numInactiveObjects = #self.inactiveObjects
		if numInactiveObjects > 0 then
			local obj = self.inactiveObjects[numInactiveObjects]
			self.activeObjects[obj] = true
			self.numActiveObjects = self.numActiveObjects + 1
			self.inactiveObjects[numInactiveObjects] = nil
			return obj, false
		end

		local newObj = self.creationFunc(self)
		if self.resetterFunc and not self.disallowResetIfNew then
			self.resetterFunc(self, newObj)
		end
		self.activeObjects[newObj] = true
		self.numActiveObjects = self.numActiveObjects + 1
		return newObj, true
	end

	function ObjectPoolMixin:Release(obj)
		if self:IsActive(obj) then
			self.inactiveObjects[#self.inactiveObjects + 1] = obj
			self.activeObjects[obj] = nil
			self.numActiveObjects = self.numActiveObjects - 1
			if self.resetterFunc then
				self.resetterFunc(self, obj)
			end
			return true
		end
		return false
	end

	function ObjectPoolMixin:ReleaseAll()
		for obj in pairs(self.activeObjects) do
			self:Release(obj)
		end
	end

	function ObjectPoolMixin:SetResetDisallowedIfNew(disallowed)
		self.disallowResetIfNew = disallowed
	end

	function ObjectPoolMixin:EnumerateActive()
		return pairs(self.activeObjects)
	end

	function ObjectPoolMixin:GetNextActive(current)
		return (next(self.activeObjects, current))
	end

	function ObjectPoolMixin:GetNextInactive(current)
		return (next(self.inactiveObjects, current))
	end

	function ObjectPoolMixin:IsActive(object)
		return (self.activeObjects[object] ~= nil)
	end

	function ObjectPoolMixin:GetNumActive()
		return self.numActiveObjects
	end

	function ObjectPoolMixin:EnumerateInactive()
		return ipairs(self.inactiveObjects)
	end

	local function CreateObjectPool(creationFunc, resetterFunc)
		local objectPool = CreateFromMixins(ObjectPoolMixin)
		objectPool:OnLoad(creationFunc, resetterFunc)
		return objectPool
	end

	local FramePoolMixin = CreateFromMixins(ObjectPoolMixin)

	local function FramePoolFactory(framePool)
		return CreateFrame(framePool.frameType, nil, framePool.parent, framePool.frameTemplate)
	end

	local CreateForbiddenFrame = CreateForbiddenFrame or NOOP
	local function ForbiddenFramePoolFactory(framePool)
		return CreateForbiddenFrame(framePool.frameType, nil, framePool.parent, framePool.frameTemplate)
	end

	function FramePoolMixin:OnLoad(frameType, parent, frameTemplate, resetterFunc, forbidden)
		if forbidden then
			ObjectPoolMixin.OnLoad(self, ForbiddenFramePoolFactory, resetterFunc)
		else
			ObjectPoolMixin.OnLoad(self, FramePoolFactory, resetterFunc)
		end
		self.frameType = frameType
		self.parent = parent
		self.frameTemplate = frameTemplate
	end

	function FramePoolMixin:GetTemplate()
		return self.frameTemplate
	end

	local function FramePool_Hide(_, frame)
		frame:Hide()
	end

	local function FramePool_HideAndClearAnchors(_, frame)
		frame:Hide()
		frame:ClearAllPoints()
	end

	local function CreateFramePool(frameType, parent, frameTemplate, resetterFunc, forbidden)
		local framePool = CreateFromMixins(FramePoolMixin)
		framePool:OnLoad(frameType, parent, frameTemplate, resetterFunc or FramePool_HideAndClearAnchors, forbidden)
		return framePool
	end

	local TexturePoolMixin = CreateFromMixins(ObjectPoolMixin)

	local function TexturePoolFactory(texturePool)
		return texturePool.parent:CreateTexture(
			nil,
			texturePool.layer,
			texturePool.textureTemplate,
			texturePool.subLayer
		)
	end

	function TexturePoolMixin:OnLoad(parent, layer, subLayer, textureTemplate, resetterFunc)
		ObjectPoolMixin.OnLoad(self, TexturePoolFactory, resetterFunc)
		self.parent = parent
		self.layer = layer
		self.subLayer = subLayer
		self.textureTemplate = textureTemplate
	end

	local function CreateTexturePool(parent, layer, subLayer, textureTemplate, resetterFunc)
		local texturePool = CreateFromMixins(TexturePoolMixin)
		texturePool:OnLoad(parent, layer, subLayer, textureTemplate, resetterFunc or FramePool_HideAndClearAnchors)
		return texturePool
	end

	local ColorMixin = {}

	function ColorMixin:OnLoad(r, g, b, a)
		self:SetRGBA(r, g, b, a)
	end

	function ColorMixin:IsEqualTo(obj)
		return (self.r == obj.r and self.g == obj.g and self.b == obj.b and self.a == obj.a)
	end

	function ColorMixin:GetRGB()
		return self.r, self.g, self.b
	end

	function ColorMixin:GetRGBAsBytes()
		return self.r * 255, self.g * 255, self.b * 255
	end

	function ColorMixin:GetRGBA()
		return self.r, self.g, self.b, self.a
	end

	function ColorMixin:GetRGBAAsBytes()
		return self.r * 255, self.g * 255, self.b * 255, (self.a or 1) * 255
	end

	function ColorMixin:SetRGBA(r, g, b, a)
		self.r, self.g, self.b, self.a = r, g, b, a
	end

	function ColorMixin:SetRGB(r, g, b)
		self:SetRGBA(r, g, b, nil)
	end

	function ColorMixin:GenerateHexColor()
		return ("ff%.2x%.2x%.2x"):format(self:GetRGBAsBytes())
	end

	function ColorMixin:GenerateHexColorMarkup()
		return "|c" .. self:GenerateHexColor()
	end

	local function WrapTextInColorCode(text, colorHexString)
		return ("|c%s%s|r"):format(colorHexString, text)
	end

	function ColorMixin:WrapTextInColorCode(text)
		return WrapTextInColorCode(text, self:GenerateHexColor())
	end

	local function CreateColor(r, g, b, a)
		local color = CreateFromMixins(ColorMixin)
		color:OnLoad(r, g, b, a)
		return color
	end

	lib.PassClickToParent = PassClickToParent
	lib.Mixin = Mixin
	lib.CreateFromMixins = CreateFromMixins
	lib.CreateAndInitFromMixin = CreateAndInitFromMixin
	lib.ObjectPoolMixin = ObjectPoolMixin
	lib.CreateObjectPool = CreateObjectPool
	lib.FramePoolMixin = FramePoolMixin
	lib.FramePool_Hide = FramePool_Hide
	lib.FramePool_HideAndClearAnchors = FramePool_HideAndClearAnchors
	lib.CreateFramePool = CreateFramePool
	lib.TexturePoolMixin = TexturePoolMixin
	lib.TexturePool_Hide = FramePool_Hide
	lib.TexturePool_HideAndClearAnchors = FramePool_HideAndClearAnchors
	lib.CreateTexturePool = CreateTexturePool
	lib.ColorMixin = ColorMixin
	lib.CreateColor = CreateColor
	lib.WrapTextInColorCode = WrapTextInColorCode
end

-------------------------------------------------------------------------------
-- status bar emulation

do
	local barFrame = CreateFrame("Frame")
	local barPrototype_SetScript = barFrame.SetScript

	local function barPrototype_Update(self, sizeChanged, width, height)
		local progress = (self.VALUE - self.MINVALUE) / (self.MAXVALUE - self.MINVALUE)

		local align1, align2
		local TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy
		local TLx_, TLy_, BLx_, BLy_, TRx_, TRy_, BRx_, BRy_
		local xprogress, yprogress

		width = width or self:GetWidth()
		height = height or self:GetHeight()

		if self.ORIENTATION == "HORIZONTAL" then
			xprogress = width * progress -- progress horizontally
			if self.FILLSTYLE == "CENTER" then
				align1, align2 = "TOP", "BOTTOM"
			elseif self.REVERSE or self.FILLSTYLE == "REVERSE" then
				align1, align2 = "TOPRIGHT", "BOTTOMRIGHT"
			else
				align1, align2 = "TOPLEFT", "BOTTOMLEFT"
			end
		elseif self.ORIENTATION == "VERTICAL" then
			yprogress = height * progress -- progress vertically
			if self.FILLSTYLE == "CENTER" then
				align1, align2 = "LEFT", "RIGHT"
			elseif self.REVERSE or self.FILLSTYLE == "REVERSE" then
				align1, align2 = "TOPLEFT", "TOPRIGHT"
			else
				align1, align2 = "BOTTOMLEFT", "BOTTOMRIGHT"
			end
		end

		if self.ROTATE then
			TLx, TLy = 0.0, 1.0
			TRx, TRy = 0.0, 0.0
			BLx, BLy = 1.0, 1.0
			BRx, BRy = 1.0, 0.0
			TLx_, TLy_ = TLx, TLy
			TRx_, TRy_ = TRx, TRy
			BLx_, BLy_ = BLx * progress, BLy
			BRx_, BRy_ = BRx * progress, BRy
		else
			TLx, TLy = 0.0, 0.0
			TRx, TRy = 1.0, 0.0
			BLx, BLy = 0.0, 1.0
			BRx, BRy = 1.0, 1.0
			TLx_, TLy_ = TLx, TLy
			TRx_, TRy_ = TRx * progress, TRy
			BLx_, BLy_ = BLx, BLy
			BRx_, BRy_ = BRx * progress, BRy
		end

		if not sizeChanged then
			self.bg:ClearAllPoints()
			self.bg:SetAllPoints()
			self.bg:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)

			self.fg:ClearAllPoints()
			self.fg:SetPoint(align1)
			self.fg:SetPoint(align2)
			self.fg:SetTexCoord(TLx_, TLy_, BLx_, BLy_, TRx_, TRy_, BRx_, BRy_)
		end

		if xprogress then
			self.fg:SetWidth(xprogress > 0 and xprogress or 0.1)
			lib.callbacks:Fire("OnValueChanged", self, self.VALUE)
		end
		if yprogress then
			self.fg:SetHeight(yprogress > 0 and yprogress or 0.1)
			lib.callbacks:Fire("OnValueChanged", self, self.VALUE)
		end
	end

	local function barPrototype_OnSizeChanged(self, width, height)
		barPrototype_Update(self, true, width, height)
	end

	local barPrototype = setmetatable({
		MINVALUE = 0.0,
		MAXVALUE = 1.0,
		VALUE = 1.0,
		ROTATE = true,
		REVERSE = false,
		ORIENTATION = "HORIZONTAL",
		FILLSTYLE = "STANDARD",

		SetMinMaxValues = function(self, minValue, maxValue)
			assert((type(minValue) == "number" and type(maxValue) == "number"), "Usage: StatusBar:SetMinMaxValues(number, number)")

			if maxValue > minValue then
				self.MINVALUE = minValue
				self.MAXVALUE = maxValue
			else
				self.MINVALUE = 0
				self.MAXVALUE = 1
			end

			if not self.VALUE or self.VALUE > self.MAXVALUE then
				self.VALUE = self.MAXVALUE
			elseif not self.VALUE or self.VALUE < self.MINVALUE then
				self.VALUE = self.MINVALUE
			end

			barPrototype_Update(self)
		end,

		GetMinMaxValues = function(self)
			return self.MINVALUE, self.MAXVALUE
		end,

		SetValue = function(self, value)
			assert(type(value) == "number", "Usage: StatusBar:SetValue(number)")
			if WithinRange(value, self.MINVALUE, self.MAXVALUE) then
				self.VALUE = value
				barPrototype_Update(self)
			end
		end,

		GetValue = function(self)
			return self.VALUE
		end,

		SetOrientation = function(self, orientation)
			if orientation == "HORIZONTAL" or orientation == "VERTICAL" then
				self.ORIENTATION = orientation
				barPrototype_Update(self)
			end
		end,

		GetOrientation = function(self)
			return self.ORIENTATION
		end,

		SetRotatesTexture = function(self, rotate)
			self.ROTATE = (rotate ~= nil and rotate ~= false)
			barPrototype_Update(self)
		end,

		GetRotatesTexture = function(self)
			return self.ROTATE
		end,

		SetReverseFill = function(self, reverse)
			self.REVERSE = (reverse == true)
			barPrototype_Update(self)
		end,

		GetReverseFill = function(self)
			return self.REVERSE
		end,

		SetFillStyle = function(self, style)
			assert(type(style) == "string" or style == nil, "Usage: StatusBar:SetFillStyle(string)")
			if style and style:lower() == "center" then
				self.FILLSTYLE = "CENTER"
				barPrototype_Update(self)
			elseif style and style:lower() == "reverse" then
				self.FILLSTYLE = "REVERSE"
				barPrototype_Update(self)
			else
				self.FILLSTYLE = "STANDARD"
				barPrototype_Update(self)
			end
		end,

		GetFillStyle = function(self)
			return self.FILLSTYLE
		end,

		SetStatusBarTexture = function(self, texture)
			self.fg:SetTexture(texture)
			self.bg:SetTexture(texture)
		end,

		GetStatusBarTexture = function(self)
			return self.fg
		end,

		SetForegroundColor = function(self, r, g, b, a)
			self.fg:SetVertexColor(r, g, b, a)
		end,

		GetForegroundColor = function(self)
			return self.fg
		end,

		SetBackgroundColor = function(self, r, g, b, a)
			self.bg:SetVertexColor(r, g, b, a)
		end,

		GetBackgroundColor = function(self)
			return self.bg:GetVertexColor()
		end,

		SetTexture = function(self, texture)
			self:SetStatusBarTexture(texture)
		end,

		GetTexture = function(self)
			return self.fg:GetTexture()
		end,

		SetStatusBarColor = function(self, r, g, b, a)
			self:SetForegroundColor(r, g, b, a)
		end,

		GetStatusBarColor = function(self)
			return self.fg:GetVertexColor()
		end,

		SetVertexColor = function(self, r, g, b, a)
			self:SetForegroundColor(r, g, b, a)
		end,

		GetVertexColor = function(self)
			return self.fg:GetVertexColor()
		end,

		SetStatusBarGradient = function(self, r1, g1, b1, a1, r2, g2, b2, a2)
			self.fg:SetGradientAlpha(self.ORIENTATION, r1, g1, b1, a1, r2, g2, b2, a2)
		end,

		SetStatusBarGradientAuto = function(self, r, g, b, a)
			self.fg:SetGradientAlpha(self.ORIENTATION, 0.5 + (r * 1.1), g * 0.7, b * 0.7, a, r * 0.7, g * 0.7, 0.5 + (b * 1.1), a)
		end,

		SetStatusBarSmartGradient = function(self, r1, g1, b1, r2, g2, b2)
			self.fg:SetGradientAlpha(self.ORIENTATION, r1, g1, b1, 1, r2 or r1, g2 or g1, b2 or b1, 1)
		end,

		GetObjectType = function(self)
			return "StatusBar"
		end,

		IsObjectType = function(self, otype)
			return (otype == "StatusBar") and 1 or nil
		end,

		SetScript = function(self, event, callback)
			if event == "OnValueChanged" then
				assert(type(callback) == "function", 'Usage: StatusBar:SetScript("OnValueChanged", function)')
				lib.RegisterCallback(self, "OnValueChanged", function() callback(self, self.VALUE) end)
			else
				barPrototype_SetScript(self, event, callback)
			end
		end
	}, {__index = barFrame})

	local barPrototype_mt = {__index = barPrototype}

	local function StatusBarPrototype(name, parent)
		-- create the bar and its elements.
		local bar = setmetatable(CreateFrame("Frame", name, parent), barPrototype_mt)
		bar.fg = bar.fg or bar:CreateTexture(name and "$parent.Texture", "ARTWORK")
		bar.bg = bar.bg or bar:CreateTexture(name and "$parent.Background", "BACKGROUND")
		bar.bg:Hide()

		-- do some stuff then return it.
		bar:HookScript("OnSizeChanged", barPrototype_OnSizeChanged)
		bar:SetRotatesTexture(false)
		return bar
	end

	lib.StatusBarPrototype = StatusBarPrototype
end

-------------------------------------------------------------------------------

do
	local GetScreenResolutions = GetScreenResolutions
	local GetCurrentResolution = GetCurrentResolution

	local function GetPhysicalScreenSize()
		local width, height = strmatch(({GetScreenResolutions()})[GetCurrentResolution()], "(%d+)x(%d+)")
		return tonumber(width), tonumber(height)
	end
	lib.GetPhysicalScreenSize = GetPhysicalScreenSize
end

-------------------------------------------------------------------------------

local mixins = {
	"QuickDispatch",
	-- table util
	"SafePack",
	"SafeUnpack",
	"tLength",
	"tCopy",
	"tInvert",
	"tIndexOf",
	"tAppendAll",
	"WeakTable",
	"newTable",
	"delTable",
	-- lua memoize
	"memoize",
	-- math util
	"Lerp",
	"Round",
	"Square",
	"Clamp",
	"WithinRange",
	"WithinRangeExclusive",
	-- roster util
	"IsInRaid",
	"IsInGroup",
	"IsInPvP",
	"GetNumGroupMembers",
	"GetNumSubgroupMembers",
	"GetGroupTypeAndCount",
	"IsGroupDead",
	"IsGroupInCombat",
	"GroupIterator",
	"UnitIterator",
	"UnitFullName",
	"C_PvP",
	-- unit util
	"GetUnitIdFromGUID",
	"GetClassFromGUID",
	"GetCreatureId",
	"GetUnitCreatureId",
	"UnitHealthInfo",
	"UnitHealthPercent", -- backward compatibility
	"UnitPowerInfo",
	"UnitIsGroupLeader",
	"UnitIsGroupAssistant",
	"GetUnitSpec", -- backward compatibility
	"GetSpecialization",
	"GetInspectSpecialization",
	"GetSpecializationRole",
	"GetNumSpecializations",
	"GetSpecializationInfo",
	"UnitGroupRolesAssigned",
	"GetNumSpecGroups",
	"GetNumUnspentTalents",
	"GetActiveSpecGroup",
	"SetActiveSpecGroup",
	"GetUnitRole",
	"GetGUIDRole",
	-- timer util
	"C_Timer",
	"After",
	"NewTicker",
	"NewTimer",
	"CancelTimer",
	-- spell util
	-- color conversion
	"HexToRGB",
	"RGBToHex",
	"HexToRGBPerc",
	"RGBPercToHex",
	-- misc util
	"HexEncode",
	"HexDecode",
	"EscapeStr",
	"GetClassColorsTable",
	"GetClassColorObj",
	"GetClassColor",
	"GetNumClasses",
	"GetClassInfo",
	"Print",
	"Printf",
	"PassClickToParent",
	"Mixin",
	"CreateFromMixins",
	"CreateAndInitFromMixin",
	"ObjectPoolMixin",
	"CreateObjectPool",
	"FramePoolMixin",
	"FramePool_Hide",
	"FramePool_HideAndClearAnchors",
	"CreateFramePool",
	"TexturePoolMixin",
	"TexturePool_Hide",
	"TexturePool_HideAndClearAnchors",
	"CreateTexturePool",
	"ColorMixin",
	"CreateColor",
	"WrapTextInColorCode",
	"StatusBarPrototype",
	"GetPhysicalScreenSize"
}

function lib:Embed(target)
	for _, v in pairs(mixins) do
		target[v] = self[v]
	end
	target.locale = target.locale or GAME_LOCALE
	self.embeds[target] = true
	return target
end

for addon in pairs(lib.embeds) do
	lib:Embed(addon)
end