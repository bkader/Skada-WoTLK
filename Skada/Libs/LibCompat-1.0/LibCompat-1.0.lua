--
-- **LibCompat-1.0** provided few handy functions that can be embed to addons.
-- This library was originally created for Skada as of 1.8.50.
-- @author: Kader B (https://github.com/bkader)
--

local MAJOR, MINOR = "LibCompat-1.0", 23
local LibCompat, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not LibCompat then return end

LibCompat.embeds = LibCompat.embeds or {}

local pairs, ipairs, select, type = pairs, ipairs, select, type
local tinsert, tremove, tconcat, wipe = table.insert, table.remove, table.concat, wipe
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local setmetatable, format = setmetatable, string.format
local tostring, tonumber = tostring, tonumber
local CreateFrame = CreateFrame

local GAME_LOCALE = GetLocale()
GAME_LOCALE = (GAME_LOCALE == "enGB") and "enUS" or GAME_LOCALE

-------------------------------------------------------------------------------

do
	local tmp = {}
	local function Print(self, frame, ...)
		local n = 0
		if self ~= LibCompat then
			n = n + 1
			tmp[n] = "|cff33ff99" .. tostring(self) .. "|r:"
		end
		for i = 1, select("#", ...) do
			n = n + 1
			tmp[n] = tostring(select(i, ...))
		end
		frame:AddMessage(tconcat(tmp, " ", 1, n))
	end

	function LibCompat:Print(...)
		local frame = ...
		if type(frame) == "table" and frame.AddMessage then
			return Print(self, frame, select(2, ...))
		end
		return Print(self, DEFAULT_CHAT_FRAME, ...)
	end

	function LibCompat:Printf(...)
		local frame = ...
		if type(frame) == "table" and frame.AddMessage then
			return Print(self, frame, format(select(2, ...)))
		else
			return Print(self, DEFAULT_CHAT_FRAME, format(...))
		end
	end
end

-------------------------------------------------------------------------------

do
	local pcall = pcall

	local function DispatchError(err)
		print("|cffff9900Error|r:" .. (err or "<no error given>"))
	end

	function LibCompat.QuickDispatch(func, ...)
		if type(func) ~= "function" then
			return
		end
		local ok, err = pcall(func, ...)
		if not ok then
			DispatchError(err)
			return
		end
		return true
	end
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

	local function tLength(tbl)
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
				for i, j in ipairs(...) do
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
	local tablePool = {}
	setmetatable(tablePool, {__mode = "kv"})

	-- get a new table
	local function newTable()
		local t = next(tablePool) or {}
		tablePool[t] = nil
		return t
	end

	-- delete table and return to pool
	local function delTable(t)
		if type(t) == "table" then
			for k, _ in pairs(t) do
				t[k] = nil
			end
			t[true] = true
			t[true] = nil
			tablePool[t] = true
		end
		return nil
	end

	LibCompat.SafePack = SafePack
	LibCompat.SafeUnpack = SafeUnpack
	LibCompat.tLength = tLength
	LibCompat.tCopy = tCopy
	LibCompat.tAppendAll = tAppendAll
	LibCompat.WeakTable = WeakTable
	LibCompat.newTable = newTable
	LibCompat.delTable = delTable
end

-------------------------------------------------------------------------------

do
	local function Round(val)
		return (val < 0.0) and ceil(val - 0.5) or floor(val + 0.5)
	end

	local function Square(val)
		return val * val
	end

	local function Clamp(val, minval, maxval)
		return min(maxval, max(minval, val))
	end

	local function WithinRange(val, minval, maxval)
		return val >= minval and val <= maxval
	end

	local function WithinRangeExclusive(val, minval, maxval)
		return val > minval and val < maxval
	end

	LibCompat.Round = Round
	LibCompat.Square = Square
	LibCompat.Clamp = Clamp
	LibCompat.WithinRange = WithinRange
	LibCompat.WithinRangeExclusive = WithinRangeExclusive
end

-------------------------------------------------------------------------------

do
	local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
	local UnitExists, UnitAffectingCombat, UnitIsDeadOrGhost = UnitExists, UnitAffectingCombat, UnitIsDeadOrGhost
	local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
	local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax

	local function IsInRaid()
		return (GetNumRaidMembers() > 0)
	end

	local function IsInGroup()
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
			LibCompat.QuickDispatch(func, unit, owner, ...)
		end
	end

	local function GetUnitIdFromGUID(guid, specific)
		if specific == nil or specific == "boss" then
			for i = 1, 4 do
				if UnitExists("boss" .. i) and UnitGUID("boss" .. i) == guid then
					return "boss" .. i
				end
			end
		end

		if specific == nil or specific == "player" then
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
			end
		end

		if specific == nil or specific == "group" then
			for unit in UnitIterator() do
				if UnitGUID(unit) == guid then
					return unit
				elseif UnitExists(unit .. "target") and UnitGUID(unit .. "target") == guid then
					return unit .. "target"
				end
			end
		end
	end

	local function GetClassFromGUID(guid, specific)
		local unit = GetUnitIdFromGUID(guid, specific)
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

	local function UnitHealthInfo(unit, guid, specific)
		unit = (unit and not unknownUnits[unit]) and unit or (guid and GetUnitIdFromGUID(guid, specific))
		local percent, health, maxhealth
		if unit and UnitExists(unit) then
			health, maxhealth = UnitHealth(unit), UnitHealthMax(unit)
			if health and maxhealth then
				percent = 100 * health / max(1, maxhealth)
			end
		end
		return percent, health, maxhealth
	end

	local function UnitPowerInfo(unit, guid, powerType, specific)
		unit = (unit and not unknownUnits[unit]) and unit or (guid and GetUnitIdFromGUID(guid, specific))
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

	LibCompat.IsInRaid = IsInRaid
	LibCompat.IsInGroup = IsInGroup
	LibCompat.GetNumGroupMembers = GetNumGroupMembers
	LibCompat.GetNumSubgroupMembers = GetNumSubgroupMembers
	LibCompat.GetGroupTypeAndCount = GetGroupTypeAndCount
	LibCompat.IsGroupDead = IsGroupDead
	LibCompat.IsGroupInCombat = IsGroupInCombat
	LibCompat.GroupIterator = GroupIterator
	LibCompat.UnitIterator = UnitIterator
	LibCompat.GetUnitIdFromGUID = GetUnitIdFromGUID
	LibCompat.GetClassFromGUID = GetClassFromGUID
	LibCompat.GetCreatureId = GetCreatureId
	LibCompat.GetUnitCreatureId = GetUnitCreatureId
	LibCompat.UnitHealthInfo = UnitHealthInfo
	LibCompat.UnitHealthPercent = UnitHealthInfo -- backward compatibility
	LibCompat.UnitPowerInfo = UnitPowerInfo
	LibCompat.UnitFullName = UnitFullName
end

-------------------------------------------------------------------------------

do
	local IsRaidLeader, IsPartyLeader = IsRaidLeader, IsPartyLeader
	local GetPartyLeaderIndex, GetRaidRosterInfo = GetPartyLeaderIndex, GetRaidRosterInfo

	local function UnitIsGroupLeader(unit)
		if not LibCompat.IsInGroup() then
			return false
		elseif unit == "player" then
			return (LibCompat.IsInRaid() and IsRaidLeader() or IsPartyLeader())
		else
			local index = unit:match("%d+")
			if not index then -- to allow other units to be checked
				unit = LibCompat.GetUnitIdFromGUID(UnitGUID(unit), "group")
				index = unit and unit:match("%d+")
			end
			return (index and GetPartyLeaderIndex() == tonumber(index))
		end
	end

	local function UnitIsGroupAssistant(unit)
		if not LibCompat.IsInRaid() then
			return false
		else
			local index = unit:match("%d+")
			if not index then -- to allow other units to be checked
				unit = LibCompat.GetUnitIdFromGUID(UnitGUID(unit), "group")
				index = unit and unit:match("%d+")
			end
			return (index and select(2, GetRaidRosterInfo(index)) == 1)
		end
	end

	LibCompat.UnitIsGroupLeader = UnitIsGroupLeader
	LibCompat.UnitIsGroupAssistant = UnitIsGroupAssistant
end

-------------------------------------------------------------------------------
-- Class Colors

do
	local classColorsTable
	local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS

	local classInfoTable = {
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

	for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		classInfoTable[k].className = v
	end

	local function GetClassColorsTable()
		if not classColorsTable then
			-- add missing class color strings
			colors.DEATHKNIGHT.colorStr = "ffc41f3b"
			colors.DRUID.colorStr = "ffff7d0a"
			colors.HUNTER.colorStr = "ffabd473"
			colors.MAGE.colorStr = "ff3fc7eb"
			colors.PALADIN.colorStr = "fff58cba"
			colors.PRIEST.colorStr = "ffffffff"
			colors.ROGUE.colorStr = "fffff569"
			colors.SHAMAN.colorStr = "ff0070de"
			colors.WARLOCK.colorStr = "ff8788ee"
			colors.WARRIOR.colorStr = "ffc79c6e"

			-- cache it once and for all.
			classColorsTable = {}
			for class, tbl in pairs(colors) do
				classColorsTable[class] = tbl
			end
		end

		return classColorsTable
	end

	local function GetClassColorObj(class)
		classColorsTable = classColorsTable or GetClassColorsTable()
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
		return LibCompat.tLength(colors)
	end

	local function GetClassInfo(classIndex)
		local className, classFile, classID
		if classIndex then
			for _, class in pairs(classInfoTable) do
				if class.classID == classIndex then
					className = class.className
					classFile = class.classFile
					classID = class.classID
					break
				end
			end
		end
		return className, classFile, classID
	end

	LibCompat.GetClassColorsTable = GetClassColorsTable
	LibCompat.GetClassColorObj = GetClassColorObj
	LibCompat.GetClassColor = GetClassColor
	LibCompat.GetNumClasses = GetNumClasses
	LibCompat.GetClassInfo = GetClassInfo
end

-------------------------------------------------------------------------------
-- C_Timer mimic

do
	local TickerPrototype, waitTable = {}, {}
	local TickerMetatable = {__index = TickerPrototype, __metatable = true}

	local waitFrame = LibCompat_TimerFrame or CreateFrame("Frame", "LibCompat_TimerFrame", UIParent)
	waitFrame:SetScript("OnUpdate", function(self, elapsed)
		local total = #waitTable
		for i = 1, total do
			local ticker = waitTable[i]

			if ticker then
				if ticker._cancelled then
					tremove(waitTable, i)
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
						tremove(waitTable, i)
						total = total - 1
					end
				end
			end
		end

		if #waitTable == 0 then
			self:Hide()
		end
	end)

	local function AddDelayedCall(ticker, oldTicker)
		if oldTicker and type(oldTicker) == "table" then
			ticker = oldTicker
		end

		tinsert(waitTable, ticker)
		waitFrame:Show()
	end

	local function CreateTicker(duration, callback, iterations)
		local ticker = setmetatable({}, TickerMetatable)

		ticker._iterations = iterations or -1
		ticker._duration = duration
		ticker._delay = duration
		ticker._callback = callback

		AddDelayedCall(ticker)
		return ticker
	end

	function TickerPrototype:IsCancelled()
		return self._cancelled
	end

	function TickerPrototype:Cancel()
		self._cancelled = true
	end

	local function After(duration, callback)
		AddDelayedCall({_iterations = 1, _delay = duration, _callback = callback})
	end

	local function NewTimer(duration, callback)
		return CreateTicker(duration, callback, 1)
	end

	local function NewTicker(duration, callback, iterations)
		return CreateTicker(duration, callback, iterations)
	end

	local function CancelTimer(ticker)
		if ticker and type(ticker.Cancel) == "function" then
			ticker:Cancel()
		end
		return nil -- return nil to assign input reference
	end

	LibCompat.After = After
	LibCompat.NewTimer = NewTimer
	LibCompat.NewTicker = NewTicker
	LibCompat.CancelTimer = CancelTimer
end

-------------------------------------------------------------------------------

do
	local GetSpellInfo, GetSpellLink = GetSpellInfo, GetSpellLink

	local custom = {
		[3] = {ACTION_ENVIRONMENTAL_DAMAGE_FALLING, "Interface\\Icons\\ability_rogue_quickrecovery"},
		[4] = {ACTION_ENVIRONMENTAL_DAMAGE_DROWNING, "Interface\\Icons\\spell_shadow_demonbreath"},
		[5] = {ACTION_ENVIRONMENTAL_DAMAGE_FATIGUE, "Interface\\Icons\\ability_creature_cursed_05"},
		[6] = {ACTION_ENVIRONMENTAL_DAMAGE_FIRE, "Interface\\Icons\\spell_fire_fire"},
		[7] = {ACTION_ENVIRONMENTAL_DAMAGE_LAVA, "Interface\\Icons\\spell_shaman_lavaflow"},
		[8] = {ACTION_ENVIRONMENTAL_DAMAGE_SLIME, "Interface\\Icons\\inv_misc_slime_01"}
	}

	local function _GetSpellInfo(spellid)
		local res1, res2, res3, res4, res5, res6, res7, res8, res9
		if spellid then
			if custom[spellid] then
				res1, res3 = custom[spellid][1], custom[spellid][2]
			else
				res1, res2, res3, res4, res5, res6, res7, res8, res9 = GetSpellInfo(spellid)
				if spellid == 75 then
					res3 = "Interface\\Icons\\INV_Weapon_Bow_07"
				elseif spellid == 6603 then
					res1, res3 = MELEE, "Interface\\Icons\\INV_Sword_04"
				end
			end
		end
		return res1, res2, res3, res4, res5, res6, res7, res8, res9
	end

	local function _GetSpellLink(spellid)
		if not custom[spellid] then
			return GetSpellLink(spellid)
		end
	end

	LibCompat.GetSpellInfo = _GetSpellInfo
	LibCompat.GetSpellLink = _GetSpellLink
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
		for i = 1, str:len() do
			local n = str:sub(i, i)
			res = res .. n
			if n == "|" then
				res = res .. "\124"
			end
		end
		return (res ~= "") and res or str
	end

	LibCompat.HexEncode = HexEncode
	LibCompat.HexDecode = HexDecode
	LibCompat.EscapeStr = EscapeStr
end

-------------------------------------------------------------------------------

do
	local LGT = LibStub("LibGroupTalents-1.0")
	local UnitClass, MAX_TALENT_TABS = UnitClass, MAX_TALENT_TABS or 3
	local GetActiveTalentGroup, GetTalentTabInfo = GetActiveTalentGroup, GetTalentTabInfo
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
		local points = LGT:UnitHasTalent(unit, LibCompat.GetSpellInfo(57881), LGT:GetActiveTalentGroup(unit))
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
	local function _UnitGroupRolesAssigned(unit)
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
		local class = select(2, UnitClass(unit))
		if class == "HUNTER" or class == "MAGE" or class == "ROGUE" or class == "WARLOCK" then
			return "DAMAGER"
		end

		return LGTRoleTable[LGT:GetUnitRole(unit or "player")] or "NONE"
	end

	local function GetGUIDRole(guid)
		return LGTRoleTable[LGT:GetGUIDRole(guid)] or "NONE"
	end

	LibCompat.GetSpecialization = GetSpecialization
	LibCompat.GetInspectSpecialization = GetInspectSpecialization
	LibCompat.GetSpecializationRole = GetSpecializationRole
	LibCompat.GetSpecializationInfo = GetSpecializationInfo

	LibCompat.UnitGroupRolesAssigned = _UnitGroupRolesAssigned
	LibCompat.GetUnitRole = _UnitGroupRolesAssigned
	LibCompat.GetGUIDRole = GetGUIDRole
	LibCompat.GetUnitSpec = GetInspectSpecialization

	-- functions that simply replaced other api functions
	LibCompat.GetNumSpecializations = GetNumTalentTabs
	LibCompat.GetNumSpecGroups = GetNumTalentGroups
	LibCompat.GetNumUnspentTalents = GetUnspentTalentPoints
	LibCompat.GetActiveSpecGroup = GetActiveTalentGroup
	LibCompat.SetActiveSpecGroup = SetActiveTalentGroup
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

	LibCompat.IsInPvP = C_PvP.IsPvPMap
	LibCompat.C_PvP = C_PvP
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

	local function FramePool_Hide(framePool, frame)
		frame:Hide()
	end

	local function FramePool_HideAndClearAnchors(framePool, frame)
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

	function ColorMixin:WrapTextInColorCode(text)
		return WrapTextInColorCode(text, self:GenerateHexColor())
	end

	local function CreateColor(r, g, b, a)
		local color = CreateFromMixins(ColorMixin)
		color:OnLoad(r, g, b, a)
		return color
	end

	local function WrapTextInColorCode(text, colorHexString)
		return ("|c%s%s|r"):format(colorHexString, text)
	end

	LibCompat.Mixin = Mixin
	LibCompat.CreateFromMixins = CreateFromMixins
	LibCompat.CreateAndInitFromMixin = CreateAndInitFromMixin
	LibCompat.ObjectPoolMixin = ObjectPoolMixin
	LibCompat.CreateObjectPool = CreateObjectPool
	LibCompat.FramePoolMixin = FramePoolMixin
	LibCompat.FramePool_Hide = FramePool_Hide
	LibCompat.FramePool_HideAndClearAnchors = FramePool_HideAndClearAnchors
	LibCompat.CreateFramePool = CreateFramePool
	LibCompat.TexturePoolMixin = TexturePoolMixin
	LibCompat.TexturePool_Hide = FramePool_Hide
	LibCompat.TexturePool_HideAndClearAnchors = FramePool_HideAndClearAnchors
	LibCompat.CreateTexturePool = CreateTexturePool
	LibCompat.ColorMixin = ColorMixin
	LibCompat.CreateColor = CreateColor
	LibCompat.WrapTextInColorCode = WrapTextInColorCode
end

-------------------------------------------------------------------------------
-- status bar emulation

do
	local StatusBarPrototype = {
		minValue = 0.0,
		maxValue = 1.0,
		value = 1,
		rotate = true,
		reverse = false,
		orientation = "HORIZONTAL",
		fill = "STANDARD",
		-- [[ API ]]--
		Update = function(self, OnSizeChanged)
			self.progress = (self.value - self.minValue) / (self.maxValue - self.minValue)

			local align1, align2
			local TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy
			local TLx_, TLy_, BLx_, BLy_, TRx_, TRy_, BRx_, BRy_
			local width, height = self:GetSize()

			if self.orientation == "HORIZONTAL" then
				self.xProgress = width * self.progress -- progress horizontally
				if self.fill == "CENTER" then
					align1, align2 = "TOP", "BOTTOM"
				elseif self.reverse or self.fill == "REVERSE" then
					align1, align2 = "TOPRIGHT", "BOTTOMRIGHT"
				else
					align1, align2 = "TOPLEFT", "BOTTOMLEFT"
				end
			elseif self.orientation == "VERTICAL" then
				self.yProgress = height * self.progress -- progress vertically
				if self.fill == "CENTER" then
					align1, align2 = "LEFT", "RIGHT"
				elseif self.reverse or self.fill == "REVERSE" then
					align1, align2 = "TOPLEFT", "TOPRIGHT"
				else
					align1, align2 = "BOTTOMLEFT", "BOTTOMRIGHT"
				end
			end

			if self.rotate then
				TLx, TLy = 0.0, 1.0
				TRx, TRy = 0.0, 0.0
				BLx, BLy = 1.0, 1.0
				BRx, BRy = 1.0, 0.0
				TLx_, TLy_ = TLx, TLy
				TRx_, TRy_ = TRx, TRy
				BLx_, BLy_ = BLx * self.progress, BLy
				BRx_, BRy_ = BRx * self.progress, BRy
			else
				TLx, TLy = 0.0, 0.0
				TRx, TRy = 1.0, 0.0
				BLx, BLy = 0.0, 1.0
				BRx, BRy = 1.0, 1.0
				TLx_, TLy_ = TLx, TLy
				TRx_, TRy_ = TRx * self.progress, TRy
				BLx_, BLy_ = BLx, BLy
				BRx_, BRy_ = BRx * self.progress, BRy
			end

			if not OnSizeChanged then
				self.bg:ClearAllPoints()
				self.bg:SetAllPoints()
				self.bg:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)

				self.fg:ClearAllPoints()
				self.fg:SetPoint(align1)
				self.fg:SetPoint(align2)
				self.fg:SetTexCoord(TLx_, TLy_, BLx_, BLy_, TRx_, TRy_, BRx_, BRy_)
			end

			if self.xProgress then
				self.fg:SetWidth(self.xProgress > 0 and self.xProgress or 0.1)
			end
			if self.yProgress then
				self.fg:SetHeight(self.yProgress > 0 and self.yProgress or 0.1)
			end
		end,
		OnSizeChanged = function(self, width, height)
			self:Update(true)
		end,
		SetMinMaxValues = function(self, minValue, maxValue)
			assert((type(minValue) == "number" and type(maxValue) == "number"), "Usage: StatusBar:SetMinMaxValues(number, number)")

			if maxValue > minValue then
				self.minValue = minValue
				self.maxValue = maxValue
			else
				self.minValue = 0
				self.maxValue = 1
			end

			if not self.value or self.value > self.maxValue then
				self.value = self.maxValue
			elseif not self.value or self.value < self.minValue then
				self.value = self.minValue
			end

			self:Update()
		end,
		GetMinMaxValues = function(self)
			return self.minValue, self.maxValue
		end,
		SetValue = function(self, value)
			assert(type(value) == "number", "Usage: StatusBar:SetValue(number)")
			if value >= self.minValue and value <= self.maxValue then
				self.value = value
				self:Update()
			end
		end,
		GetValue = function(self)
			return self.value
		end,
		SetOrientation = function(self, orientation)
			if orientation == "HORIZONTAL" or orientation == "VERTICAL" then
				self.orientation = orientation
				self:Update()
			end
		end,
		GetOrientation = function(self)
			return self.orientation
		end,
		SetRotatesTexture = function(self, rotate)
			if type(rotate) == "boolean" then
				self.rotate = rotate
				self:Update()
			end
		end,
		GetRotatesTexture = function(self)
			return self.rotate
		end,
		SetReverseFill = function(self, reverse)
			self.reverse = (reverse == true)
			self:Update()
		end,
		GetReverseFill = function(self)
			return self.reverse
		end,
		SetFillStyle = function(self, style)
			if type(style) == "string" and style:upper() == "CENTER" or style:upper() == "REVERSE" then
				self.fill = style:upper()
				self:Update()
			else
				self.fill = "STANDARD"
				self:Update()
			end
		end,
		GetFillStyle = function(self)
			return self.fill
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
		SetVertexColor = function(self, r, g, b, a)
			self:SetForegroundColor(r, g, b, a)
		end,
		GetVertexColor = function(self)
			return self.fg:GetVertexColor()
		end,
		SetStatusBarGradient = function(self, r1, g1, b1, a1, r2, g2, b2, a2)
			self.fg:SetGradientAlpha(self.orientation, r1, g1, b1, a1, r2, g2, b2, a2)
		end,
		SetStatusBarGradientAuto = function(self, r, g, b, a)
			self.fg:SetGradientAlpha(self.orientation, 0.5 + (r * 1.1), g * 0.7, b * 0.7, a, r * 0.7, g * 0.7, 0.5 + (b * 1.1), a)
		end,
		SetStatusBarSmartGradient = function(self, r1, g1, b1, r2, g2, b2)
			self.fg:SetGradientAlpha(self.orientation, r1, g1, b1, 1, r2 or r1, g2 or g1, b2 or b1, 1)
		end,
		GetObjectType = function(self)
			return "StatusBar"
		end,
		IsObjectType = function(self, otype)
			return (otype == self:GetObjectType()) and 1 or nil
		end
	}

	setmetatable(StatusBarPrototype, {__call = function(self, name, parent)
		local bar = CreateFrame("Frame", name, parent)
		bar.fg = bar.fg or bar:CreateTexture(name and "$parent.Texture", "ARTWORK")
		bar.bg = bar.bg or bar:CreateTexture(name and "$parent.Background", "BACKGROUND")
		for k, v in pairs(StatusBarPrototype) do bar[k] = v end
		bar:SetRotatesTexture(false)
		bar:HookScript("OnSizeChanged", bar.OnSizeChanged)
		bar:Update()
		bar.bg:Hide()
		return bar
	end})

	LibCompat.StatusBarPrototype = StatusBarPrototype
end

-------------------------------------------------------------------------------

do
	local strmatch = strmatch
	local GetScreenResolutions = GetScreenResolutions
	local GetCurrentResolution = GetCurrentResolution

	local function GetPhysicalScreenSize()
		local width, height = strmatch(({GetScreenResolutions()})[GetCurrentResolution()], "(%d+)x(%d+)")
		return tonumber(width), tonumber(height)
	end
	LibCompat.GetPhysicalScreenSize = GetPhysicalScreenSize
end

-------------------------------------------------------------------------------

local mixins = {
	"QuickDispatch",
	-- table util
	"SafePack",
	"SafeUnpack",
	"tLength",
	"tCopy",
	"tAppendAll",
	"WeakTable",
	"newTable",
	"delTable",
	-- math util
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
	"After",
	"NewTimer",
	"NewTicker",
	"CancelTimer",
	-- spell util
	"GetSpellInfo",
	"GetSpellLink",
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

function LibCompat:Embed(target)
	for _, v in pairs(mixins) do
		target[v] = self[v]
	end
	target.locale = target.locale or GAME_LOCALE
	self.embeds[target] = true
	return target
end

for addon in pairs(LibCompat.embeds) do
	LibCompat:Embed(addon)
end