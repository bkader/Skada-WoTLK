--
-- **LibCompat-1.0** provides few handy functions that can be embed to addons.
-- This library was originally created for Skada as of 1.8.50.
-- @author: Kader B (https://github.com/bkader/LibCompat-1.0)
--

local MAJOR, MINOR = "LibCompat-1.0-Skada", 34
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.embeds = lib.embeds or {}
lib.EmptyFunc = Multibar_EmptyFunc

local pairs, ipairs, select, type = pairs, ipairs, select, type
local tconcat, wipe = table.concat, wipe
local max, min = math.max, math.min
local format, tonumber = format or string.format, tonumber
local strbyte, strchar = strbyte or string.byte, strchar or string.char
local setmetatable = setmetatable
local error = error
local _

local Dispatch
local IsInGroup, IsInRaid
local GetUnitIdFromGUID
local tLength

-------------------------------------------------------------------------------

do
	local pcall = pcall

	function Dispatch(func, ...)
		if type(func) ~= "function" then
			print("\124cffff9900Error\124r: Dispatch requires a function.")
			return
		end
		return func(...)
	end

	local function QuickDispatch(func, ...)
		if type(func) ~= "function" then return end
		local ok, err = pcall(func, ...)
		if not ok then
			print("\124cffff9900Error\124r:" .. (err or "<no error given>"))
			return
		end
		return true
	end

	local pformat -- Thank you DBM!
	do
		local function replace(cap1)
			return cap1 == "%" and UNKNOWN
		end

		function pformat(fstr, ...)
			local ok, str = pcall(format, fstr, ...)
			return ok and str or fstr:gsub("(%%+)([^%%%s<]+)", replace):gsub("%%%%", "%%")
		end
	end

	lib.Dispatch = Dispatch
	lib.QuickDispatch = QuickDispatch
	lib.pformat = pformat
end

-------------------------------------------------------------------------------

do
	function tLength(tbl)
		local len = 0
		if tbl then
			for _ in pairs(tbl) do
				len = len + 1
			end
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

	-- replace the global function
	_G.tContains = function(tbl, item)
		for _, v in pairs(tbl) do
			if item == v then
				return true
			end
		end
		return false
	end

	lib.tLength = tLength
	lib.tCopy = tCopy
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

	-- clears all items in a table.
	function Table.clear(obj, func, ...)
		if obj and func then
			for k in pairs(obj) do
				obj[k] = func(obj[k], ...)
			end
		elseif obj then
			wipe(obj)
		end
		return obj
	end

	-- releases the already used lua table into the table pool
	-- named "tag" or creates it right away.
	function Table.free(tag, obj, noclear, func, ...)
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
			obj = Table.clear(obj, func, ...)
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
	function lib.TablePool(mode)
		local pool = {}
		setmetatable(pool, {__mode = mode or "k"})

		-- attempts to retrieve a table from the cache
		-- creates if if it doesn't exist.
		local function new()
			local t = next(pool) or {}
			pool[t] = nil
			return t
		end

		-- it will wipe the provided table then cache it
		-- to be reusable later.
		local function del(t, recursive)
			if type(t) == "table" then
				setmetatable(t, nil)
				for k, v in pairs(t) do
					if recursive and type(v) == "table" then
						del(v)
					end
					t[k] = nil
				end
				t[""] = true
				t[""] = nil
				pool[t] = true
			end
			return nil
		end

		-- optional function used to wipe a table that contains
		-- other reusable tables.
		local function clear(t, recursive)
			if type(t) == "table" then
				for k, v in pairs(t) do
					t[k] = del(v, recursive)
				end
			end
			return t
		end

		return new, del, clear
	end
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
		local nmem, step, count

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
					step = count <= nmem and 3 or nil
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
					step = count <= nmem and 1 or nil
				end
				if unit and UnitExists(unit) then
					return unit, owner
				end
			end
		end

		function UnitIterator(excPets)
			nmem, step = GetNumRaidMembers(), 1
			if nmem == 0 then
				nmem = GetNumPartyMembers()
				if nmem == 0 then
					return SelfIterator, excPets
				end
				count = 1
				return PartyIterator, excPets
			end
			count = 1
			return RaidIterator, excPets
		end
	end

	local function IsGroupDead()
		for unit in UnitIterator(true) do
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
			Dispatch(func, unit, owner, ...)
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

		if filter == "arena" then
			for i = 1, 5 do
				if UnitExists("arena" .. i) and UnitGUID("arena" .. i) == guid then
					return "arena" .. i
				end
			end
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
			_, class = UnitClass(unit)
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
	function RGBPercToHex(r, g, b, prefix)
		r = r <= 1 and r >= 0 and r or 0
		g = g <= 1 and g >= 0 and g or 0
		b = b <= 1 and b >= 0 and b or 0
		return format(prefix and "ff%02x%02x%02x" or "%02x%02x%02x", r * 255, g * 255, b * 255)
	end

	local function PercentToRGB(perc, reverse, hex)
		-- clamp first
		perc = min(100, max(0, perc or 0))

		-- start with full red
		local r, g, b = 1, 0, 0

		-- reversed?
		if reverse then
			r, g = 0, 1

			if perc <= 50 then -- increment red channel
				r = r + (perc / 50)
			else -- set red to 1 and decrement green channel
				r, g = 1, g - ((perc - 50) / 50)
			end
		elseif perc <= 50 then -- increment green channel
			g = g + (perc / 50)
		else -- set green to 1 and decrement red channel
			r, g = r - ((perc - 50) / 50), 1
		end

		-- return hex? channels will be as of 2nd param.
		if hex then
			return RGBPercToHex(r, g, b, true), r, g, b
		end

		-- return only channels.
		return r, g, b
	end

	lib.RGBPercToHex = RGBPercToHex
	lib.PercentToRGB = PercentToRGB
end

-------------------------------------------------------------------------------
-- Classes & Colors

do
	local classColorsTable, classCoordsTable

	local function GetClassColorsTable()
		-- fill class colors table.
		if classColorsTable == nil then
			classColorsTable = {}
			for class, tbl in pairs(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS) do
				classColorsTable[class] = tbl
				classColorsTable[class].colorStr = RGBPercToHex(tbl.r, tbl.g, tbl.b, true)
				classColorsTable[class].className = LOCALIZED_CLASS_NAMES_MALE[class] or UNKNOWN
			end
		end

		-- fill class coords table
		if classCoordsTable == nil then
			classCoordsTable = {}
			for class, coords in pairs(CLASS_ICON_TCOORDS) do
				classCoordsTable[class] = coords
			end
		end

		return classColorsTable, classCoordsTable
	end

	lib.GetClassColorsTable = GetClassColorsTable
end

-------------------------------------------------------------------------------
-- Hex Encode, Decode and String Escape

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
-- Specs and Roles

do
	local UnitClass, GetSpellInfo = UnitClass, GetSpellInfo
	local UnitGroupRolesAssigned = UnitGroupRolesAssigned
	local MAX_TALENT_TABS = MAX_TALENT_TABS or 3

	local LGT = LibStub("LibGroupTalents-1.0")
	local LGTRoleTable = {melee = "DAMAGER", caster = "DAMAGER", healer = "HEALER", tank = "TANK"}

	-- list of class to specs
	local specsTable = {
		MAGE = {62, 63, 64},
		PRIEST = {256, 257, 258},
		ROGUE = {259, 260, 261},
		WARLOCK = {265, 266, 267},
		WARRIOR = {71, 72, 73},
		PALADIN = {65, 66, 70},
		DEATHKNIGHT = {250, 251, 252},
		DRUID = {102, 103, 104, 105},
		HUNTER = {253, 254, 255},
		SHAMAN = {262, 263, 264}
	}

	local guardianSpells = {
		[16929] = 2, -- Thick Hide
		[57880] = 1 -- Natural Reactions
	}
	local function GetFeralSubSpec(unit, talentGroup)
		for spellid, points in pairs(guardianSpells) do
			local pts = LGT:UnitHasTalent(unit, GetSpellInfo(spellid), talentGroup) or 0
			if pts <= points then
				return 2
			end
		end
		return 3
	end

	-- cached specs
	local cachedSpecs = setmetatable({}, {__index = function(self, id)
		local unit = id and (GetUnitIdFromGUID(id, "group") or GetUnitIdFromGUID(id, "player"))
		if not unit then return end

		local _, class = UnitClass(unit)
		if not class or not specsTable[class] then return end

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
							index = GetFeralSubSpec(unit, talentGroup)
						end
					else
						index = i
					end
				end
			end
		end

		local spec = specsTable[class][index]
		self[id] = spec
		return spec
	end})

	-- cached roles
	local cachedRoles = setmetatable({}, {__index = function(self, id)
		local unit = id and (GetUnitIdFromGUID(id, "group") or GetUnitIdFromGUID(id, "player"))
		if not unit then return end

		local role = nil

		-- For LFG using "UnitGroupRolesAssigned" is enough.
		local isTank, isHealer, isDamager = UnitGroupRolesAssigned(unit)
		if isTank then
			role = "TANK"
		elseif isHealer then
			role = "HEALER"
		elseif isDamager then
			role = "DAMAGER"
		else
			local _, class = UnitClass(unit)
			-- speedup things using classes.
			if class == "HUNTER" or class == "MAGE" or class == "ROGUE" or class == "WARLOCK" then
				role = "DAMAGER"
			else
				role = LGTRoleTable[LGT:GetUnitRole(unit)] or "NONE"
			end
		end

		self[id] = role
		return role
	end})

	local function GetUnitSpec(guid)
		return cachedSpecs[guid]
	end

	local function GetUnitRole(guid)
		return cachedRoles[guid]
	end

	LGT:RegisterCallback("LibGroupTalents_Update", function(_, guid, unit, _, n1, n2, n3)
		if not guid or not unit then return end

		local _, class = UnitClass(unit)
		if class and specsTable[class] then
			local nx = max(n1, n2, n3) -- highest in points spent
			local index = nx == n1 and 1 or nx == n2 and 2 or nx == n3 and 3

			if class == "DRUID" and index == 3 then
				index = 4
			elseif class == "DRUID" and index == 2 then
				local points = LGT:UnitHasTalent(unit, GetSpellInfo(57881))
				index = (points and points > 0) and 3 or 2
			end

			cachedSpecs[guid] = specsTable[class][index]
		end
	end)

	LGT:RegisterCallback("LibGroupTalents_RoleChange", function(_, guid, _, role, oldrole)
		if not guid or role == oldrole then return end
		cachedRoles[guid] = LGTRoleTable[role] or role
	end)

	lib.GetUnitSpec = GetUnitSpec
	lib.GetUnitRole = GetUnitRole
end

-------------------------------------------------------------------------------
-- Pvp

do
	local IsInInstance, instanceType = IsInInstance, nil

	local function IsInPvP()
		_, instanceType = IsInInstance()
		return (instanceType == "pvp" or instanceType == "arena")
	end

	lib.IsInPvP = IsInPvP
end

-------------------------------------------------------------------------------
-- Colors

do
	local function WrapTextInColorCode(text, colorHexString)
		return format("\124c%s%s\124r", colorHexString, text)
	end

	lib.WrapTextInColorCode = WrapTextInColorCode
end

-------------------------------------------------------------------------------
-- Save/Restore frame positions to/from db

do
	local floor = math.floor
	local GetScreenWidth, GetScreenHeight = GetScreenWidth, GetScreenHeight

	local function SavePosition(self, db)
		if self and self.GetCenter and db then
			local x, y = self:GetCenter()
			local scale = self:GetEffectiveScale()
			local uscale = UIParent:GetScale()

			db.x = ((x * scale) - (GetScreenWidth() * uscale) / 2) / uscale
			db.y = ((y * scale) - (GetScreenHeight() * uscale) / 2) / uscale
			db.scale = floor(self:GetScale() * 100) / 100
		end
	end

	local function RestorePosition(self, db)
		if self and self.SetPoint and db then
			local scale = self:GetEffectiveScale()
			local uscale = UIParent:GetScale()
			local x = (db.x or 0) * uscale / scale
			local y = (db.y or 0) * uscale / scale

			self:ClearAllPoints()
			self:SetPoint("CENTER", UIParent, "CENTER", x, y)
			self:SetScale(db.scale or 1)
		end
	end

	lib.SavePosition = SavePosition
	lib.RestorePosition = RestorePosition
end

-------------------------------------------------------------------------------

local mixins = {
	"EmptyFunc",
	"Dispatch",
	"QuickDispatch",
	"pformat",
	-- table util
	"tLength",
	"tCopy",
	"Table",
	"TablePool",
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
	-- color conversion
	"RGBPercToHex",
	"PercentToRGB",
	-- misc util
	"HexEncode",
	"HexDecode",
	"EscapeStr",
	"GetClassColorsTable",
	"WrapTextInColorCode",
	-- frame position
	"SavePosition",
	"RestorePosition"
}

function lib:Embed(target)
	for _, v in pairs(mixins) do
		target[v] = self[v]
	end
	self.embeds[target] = true
	return target
end

for addon in pairs(lib.embeds) do
	lib:Embed(addon)
end
