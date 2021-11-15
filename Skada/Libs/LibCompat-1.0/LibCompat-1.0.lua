--
-- **LibCompat-1.0** provides few handy functions that can be embed to addons.
-- This library was originally created for Skada as of 1.8.50.
-- @author: Kader B (https://github.com/bkader/LibCompat-1.0)
--

local MAJOR, MINOR = "LibCompat-1.0-Skada", 27
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.embeds = lib.embeds or {}

local pairs, ipairs, select, type = pairs, ipairs, select, type
local tinsert, tremove, tconcat, wipe = table.insert, table.remove, table.concat, wipe
local max, min = math.max, math.min
local format = format or string.format
local strbyte = strbyte or string.byte
local strchar = strchar or string.char
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
-------------------------------------------------------------------------------

do
	local pcall = pcall

	function QuickDispatch(func, ...)
		if type(func) ~= "function" then return end
		local ok, err = pcall(func, ...)
		if not ok then
			print("|cffff9900Error|r:" .. (err or "<no error given>"))
			return
		end
		return true
	end
end

-------------------------------------------------------------------------------

do
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
				if type(...) == "table" then
					for _, j in ipairs(...) do
						if j == k then
							skip = true
							break
						end
					end
				else
					for i = 1, select("#", ...) do
						if select(i, ...) == k then
							skip = true
							break
						end
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

	lib.tLength = tLength
	lib.tCopy = tCopy
	lib.tIndexOf = tIndexOf
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

		local function SelfIterator(excPets)
			while step do
				local unit, owner
				if step == 1 then
					unit, owner, step = "player", nil, 2
				elseif step == 2 then
					if not excPets then
						unit, owner = "playerpet", "player"
					end
					step = nil
				end
				if unit and UnitExists(unit) then
					return unit, owner
				end
			end
		end

		local function PartyIterator(excPets)
			while step do
				local unit, owner
				if step <= 2 then
					unit, owner = SelfIterator(excPets)
					step = step or 3
				elseif step == 3 then
					unit, owner, step = format("party%d", count), nil, 4
				elseif step == 4 then
					if not excPets then
						unit, owner = format("partypet%d", count), format("party%d", count)
					end
					count = count + 1
					step = count <= pmem and 3 or nil
				end
				if unit and UnitExists(unit) then
					return unit, owner
				end
			end
		end

		local function RaidIterator(excPets)
			while step do
				local unit, owner
				if step == 1 then
					unit, owner, step = format("raid%d", count), nil, 2
				elseif step == 2 then
					if not excPets then
						unit, owner = format("raidpet%d", count), format("raid%d", count)
					end
					count = count + 1
					step = count <= rmem and 1 or nil
				end
				if unit and UnitExists(unit) then
					return unit, owner
				end
			end
		end

		function UnitIterator(excPets)
			rmem, step = GetNumRaidMembers(), 1
			if rmem == 0 then
				pmem = GetNumPartyMembers()
				if pmem == 0 then
					return SelfIterator, excPets
				end
				count = 1
				return PartyIterator, excPets
			end
			count = 1
			return RaidIterator, excPets
		end
	end

	local function IsGroupDead(incPets)
		for unit in UnitIterator(not incPets) do
			if not UnitIsDeadOrGhost(unit) then
				return false
			end
		end
		return true
	end

	local function IsGroupInCombat(incPets)
		for unit in UnitIterator(not incPets) do
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
			for unit in UnitIterator() do
				if UnitGUID(unit) == guid then
					return unit
				elseif UnitExists(unit .. "target") and UnitGUID(unit .. "target") == guid then
					return unit .. "target"
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

	lib.IsInRaid = IsInRaid
	lib.IsInGroup = IsInGroup
	lib.GetNumGroupMembers = GetNumGroupMembers
	lib.GetGroupTypeAndCount = GetGroupTypeAndCount
	lib.IsGroupDead = IsGroupDead
	lib.IsGroupInCombat = IsGroupInCombat
	lib.GroupIterator = GroupIterator
	lib.UnitIterator = UnitIterator
	lib.GetUnitIdFromGUID = GetUnitIdFromGUID
	lib.GetClassFromGUID = GetClassFromGUID
	lib.GetCreatureId = GetCreatureId
	lib.UnitHealthInfo = UnitHealthInfo
	lib.UnitPowerInfo = UnitPowerInfo
end

-------------------------------------------------------------------------------
-- Color functions

local RGBPercToHex
do
	function RGBPercToHex(r, g, b)
		r = r <= 1 and r >= 0 and r or 0
		g = g <= 1 and g >= 0 and g or 0
		b = b <= 1 and b >= 0 and b or 0
		return format("%02x%02x%02x", r * 255, g * 255, b * 255)
	end

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

	lib.GetClassColorsTable = GetClassColorsTable
end

-------------------------------------------------------------------------------
-- C_Timer mimic

do
	local TickerPrototype = {}
	local TickerMetatable = {
		__index = TickerPrototype,
		__metatable = true
	}

	local WaitTable = {}

	local new, del
	do
		lib.afterPool = lib.afterPool or setmetatable({}, {__mode = "k"})
		lib.timerPool = lib.timerPool or setmetatable({}, {__mode = "k"})
		local afterPool = lib.afterPool
		local timerPool = lib.timerPool

		function new(temp)
			if temp then
				local t = next(afterPool) or {}
				afterPool[t] = nil
				return t
			end
			local t = next(timerPool) or setmetatable({}, TickerMetatable)
			timerPool[t] = nil
			return t
		end

		function del(t, temp)
			if t then
				wipe(t)
				t[true] = true
				t[true] = nil
				if temp then
					afterPool[t] = true
				else
					timerPool[t] = true
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
				del(tremove(WaitTable, i), ticker._temp)
				total = total - 1
			elseif ticker._delay > elapsed then
				ticker._delay = ticker._delay - elapsed
				i = i + 1
			else
				ticker._callback(ticker)

				if ticker._iterations == -1 then
					ticker._delay = ticker._duration
					i = i + 1
				elseif ticker._iterations > 1 then
					ticker._iterations = ticker._iterations - 1
					ticker._delay = ticker._duration
					i = i + 1
				elseif ticker._iterations == 1 then
					del(tremove(WaitTable, i), ticker._temp)
					total = total - 1
				end
			end
		end

		if #WaitTable == 0 then
			self:Hide()
		end
	end

	local WaitFrame = _G.LibCompatSkada_WaitFrame or CreateFrame("Frame", "LibCompatSkada_WaitFrame", UIParent)
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

	local function After(duration, callback)
		ValidateArguments(duration, callback, "After")
		local ticker = new(true)

		ticker._iterations = 1
		ticker._delay = max(0.01, duration)
		ticker._callback = callback
		ticker._temp = true
		ticker._cancelled = nil -- just in case

		AddDelayedCall(ticker)
	end

	local function CreateTicker(duration, callback, iterations)
		local ticker = new()

		ticker._iterations = iterations or -1
		ticker._delay = max(0.01, duration)
		ticker._duration = ticker._delay
		ticker._callback = callback
		ticker._cancelled = nil -- just in case
		ticker._temp = nil -- just in case

		AddDelayedCall(ticker)
		return ticker
	end

	local function NewTicker(duration, callback, iterations)
		ValidateArguments(duration, callback, "NewTicker")
		return CreateTicker(duration, callback, iterations)
	end

	local function NewTimer(duration, callback)
		ValidateArguments(duration, callback, "NewTimer")
		return CreateTicker(duration, callback, 1)
	end

	local function CancelTimer(ticker, silent)
		if ticker and ticker.Cancel then
			ticker:Cancel()
		elseif not silent then
			error(MAJOR .. ": CancelTimer(timer[, silent]): '"..tostring(ticker).."' - no such timer registered")
		end
		return nil
	end

	function TickerPrototype:Cancel()
		self._cancelled = true
	end
	function TickerPrototype:IsCancelled()
		return self._cancelled
	end

	lib.After = After
	lib.NewTicker = NewTicker
	lib.NewTimer = NewTimer
	lib.CancelTimer = CancelTimer
end

-------------------------------------------------------------------------------

do
	local band, rshift, lshift = bit.band, bit.rshift, bit.lshift

	local function HexEncode(str, title)
		local hex = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
		local t = (title and title ~= "") and {format("[=== %s ===]", title)} or {}
		local j = 0
		for i = 1, #str do
			if j <= 0 then
				t[#t + 1], j = "\n", 32
			end
			j = j - 1

			local b = strbyte(str, i)
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
			bl = strbyte(str, i)
			bl = bl >= 65 and bl - 55 or bl - 48
			i = i + 1
			bh = strbyte(str, i)
			bh = bh >= 65 and bh - 55 or bh - 48
			i = i + 1
			t[#t + 1] = strchar(lshift(bh, 4) + bl)
		until i >= #str
		return tconcat(t)
	end

	-- we a fake frame/fontstring to escape the string
	local escapeFrame = CreateFrame("Frame")
	escapeFrame.fs = escapeFrame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
	escapeFrame:Hide()

	local function EscapeStr(str)
		escapeFrame.fs:SetText(str)
		str = escapeFrame.fs:GetText()
		escapeFrame.fs:SetText("")
		return str
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

	local function GetUnitSpec(unit, class)
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
									local points = LGT:UnitHasTalent(unit, GetSpellInfo(57881))
									index = (points and points > 0) and 3 or 2
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

	local UnitGroupRolesAssigned = UnitGroupRolesAssigned
	local function GetUnitRole(unit, class)
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

		return LGTRoleTable[LGT:GetUnitRole(unit)] or "NONE"
	end

	lib.GetUnitSpec = GetUnitSpec
	lib.GetUnitRole = GetUnitRole
end

-------------------------------------------------------------------------------

do
	local IsInInstance, instanceType = IsInInstance, nil

	local function IsInPvP()
		instanceType = select(2, IsInInstance())
		return (instanceType == "pvp" or instanceType == "arena")
	end

	lib.IsInPvP = IsInPvP
end

-------------------------------------------------------------------------------

do
	local function WrapTextInColorCode(text, colorHexString)
		return format("|c%s%s|r", colorHexString, text)
	end

	lib.WrapTextInColorCode = WrapTextInColorCode
end

-------------------------------------------------------------------------------

do
	local Table = {}
	local max_pool_size = 200
	local pools = {}

	-- attempts to get a table from the table pool of the
	-- specified tag name. if the pool doesn't exist or is empty
	-- it creates a lua table.
	function Table.get(tag)
		local pool = pools[tag]
		if not pool then
			pool = {}
			pools[tag] = pool
			pool.c = 0
			pool[0] = 0
		else
			local len = pool[0]
			if len > 0 then
				local obj = pool[len]
				pool[len] = nil
				pool[0] = len - 1
				return obj
			end
		end
		return {}
	end

	-- releases the already used lua table into the table pool
	-- named "tag" or creates it right away.
	function Table.free(tag, obj, noclear)
		if not obj then return end

		local pool = pools[tag]
		if not pool then
			pool = {}
			pools[tag] = pool
			pool.c = 0
			pool[0] = 0
		end

		if not noclear then
			setmetatable(obj, nil)
			for k, _ in pairs(obj) do
				obj[k] = nil
			end
		end

		do
			local cnt = pool.c + 1
			if cnt >= 20000 then
				pool = {}
				pools[tag] = pool
				pool.c = 0
				pool[0] = 0
				return
			end
			pool.c = cnt
		end

		local len = pool[0] + 1
		if len > max_pool_size then
			return
		end

		pool[len] = obj
		pool[0] = len
	end

	lib.Table = Table
end

-------------------------------------------------------------------------------

do
	-- Table Pool for recycling tables
	-- creates a new table system that can be used to reuse tables
	-- it returns both "new" and "del" functions.
	function lib.TablePool()
		max_pool_size = max_pool_size or 10
		local pool = {}
		setmetatable(pool, {__mode = "kv"})

		-- attempts to retrieve a table from the cache
		-- creates if if it doesn't exist.
		local function new()
			local t = next(pool) or {}
			pool[t] = nil
			return t
		end

		-- it will wipe the provided table then cache it
		-- to be reusable later.
		local function del(t)
			if type(t) == "table" then
				for k, _ in pairs(t) do
					t[k] = nil
				end
				t[true] = true
				t[true] = nil
				pool[t] = true
			end
			return nil
		end

		return new, del
	end
end

-------------------------------------------------------------------------------

local mixins = {
	-- table util
	"tLength",
	"tCopy",
	"tIndexOf",
	-- roster util
	"IsInRaid",
	"IsInGroup",
	"IsInPvP",
	"GetNumGroupMembers",
	"GetGroupTypeAndCount",
	"IsGroupDead",
	"IsGroupInCombat",
	"GroupIterator",
	"UnitIterator",
	-- unit util
	"GetUnitIdFromGUID",
	"GetClassFromGUID",
	"GetCreatureId",
	"UnitHealthInfo",
	"UnitPowerInfo",
	"GetUnitSpec",
	"GetUnitRole",
	-- timer util
	"After",
	"NewTicker",
	"NewTimer",
	"CancelTimer",
	-- color conversion
	"RGBPercToHex",
	-- misc util
	"HexEncode",
	"HexDecode",
	"EscapeStr",
	"GetClassColorsTable",
	"WrapTextInColorCode",
	"Table",
	"TablePool",
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
