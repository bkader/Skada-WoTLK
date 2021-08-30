--
-- **LibCompat-1.0** provided few handy functions that can be embed to addons.
-- This library was originally created for Skada as of 1.8.50.
-- @author: Kader B (https://github.com/bkader)
--

local MAJOR, MINOR = "LibCompat-1.0", 10

local LibCompat, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not LibCompat then return end

LibCompat.embeds = LibCompat.embeds or {}

local pairs, ipairs, select, type = pairs, ipairs, select, type
local tinsert, tremove, wipe = table.insert, table.remove, wipe
local setmetatable, format = setmetatable, string.format
local CreateFrame = CreateFrame

-------------------------------------------------------------------------------

do
	local tconcat = table.concat
	local tostring = tostring

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
	local function delTable(t, recursive)
		if type(t) == "table" then
			for k, v in pairs(t) do
				if recursive and type(v) == "table" then
					delTable(v, recursive)
				end
				t[k] = nil
			end
			t[true] = true
			t[true] = nil
			setmetatable(t, nil)
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
	local floor, ceil = math.floor, math.ceil

	local function Round(val)
		return (val < 0.0) and ceil(val - 0.5) or floor(val + 0.5)
	end

	local function Square(val)
		return val * val
	end

	local function Clamp(val, minval, maxval)
		return (val > maxval) and maxval or (val < minval) and minval or val
	end

	local function WithinRange(val, minval, maxval)
		return val >= minval and val <= maxval
	end

	local function WithinRangeExclusive(val, minval, maxval)
		return val > minval and value < maxval
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
	local UnitAffectingCombat, UnitIsDeadOrGhost = UnitAffectingCombat, UnitIsDeadOrGhost
	local UnitExists, IsInInstance = UnitExists, IsInInstance
	local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
	local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax

	local function IsInRaid()
		return (GetNumRaidMembers() > 0)
	end

	local function IsInParty()
		return (GetNumPartyMembers() > 0)
	end

	local function IsInGroup()
		return (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0)
	end

	local IsInPvP
	do
		local instanceType
		function IsInPvP()
			instanceType = select(2, IsInInstance())
			return (instanceType == "pvp" or instanceType == "arena")
		end
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

	local function IsGroupDead()
		if not UnitIsDeadOrGhost("player") then
			return false
		elseif IsInGroup() then
			local prefix, min_member, max_member = GetGroupTypeAndCount()
			for i = min_member, max_member do
				local unit = (i == 0) and "player" or format("%s%d", prefix, i)
				if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
					return false
				end
			end
		end
		return true
	end

	local function IsGroupInCombat()
		if UnitAffectingCombat("player") then
			return true
		elseif IsInGroup() then
			local prefix, min_member, max_member = GetGroupTypeAndCount()
			for i = min_member, max_member do
				local unit = (i == 0) and "player" or format("%s%d", prefix, i)
				if UnitExists(unit) and UnitAffectingCombat(unit) then
					return true
				end
			end
		end
		return false
	end

	local function GroupIterator(func, ...)
		if IsInRaid() then
			for i = 1, GetNumRaidMembers() do
				LibCompat.QuickDispatch(func, format("raid%d", i), ...)
			end
		elseif IsInGroup() then
			for i = 0, 4 do
				LibCompat.QuickDispatch(func, (i == 0) and "player" or format("party%d", i), ...)
			end
		else
			LibCompat.QuickDispatch(func, "player", ...)
		end
	end

	local function UnitFullName(unit)
		local name, realm = UnitName(unit)
		local namerealm = realm and realm ~= "" and name .. "-" .. realm or name
		return namerealm
	end

	local function GetUnitIdFromGUID(guid)
		local unitId
		for i = 1, 4 do
			if UnitExists("boss" .. i) and UnitGUID("boss" .. i) == guid then
				unitId = "boss" .. i
				break
			end
		end

		if not unitId then
			if UnitExists("target") and UnitGUID("target") == guid then
				unitId = "target"
			elseif UnitExists("focus") and UnitGUID("focus") == guid then
				unitId = "focus"
			elseif UnitExists("targettarget") and UnitGUID("targettarget") == guid then
				unitId = "targettarget"
			elseif UnitExists("focustarget") and UnitGUID("focustarget") == guid then
				unitId = "focustarget"
			elseif UnitExists("mouseover") and UnitGUID("mouseover") == guid then
				unitId = "mouseover"
			end
		end

		if not unitId then
			GroupIterator(function(unit)
				if unitId then
					return
				elseif UnitExists(unit) and UnitGUID(unit) == guid then
					unitId = unit
				elseif UnitExists(unit .. "pet") and UnitGUID(unit .. "pet") == guid then
					unitId = unit .. "pet"
				elseif UnitExists(unit .. "target") and UnitGUID(unit .. "target") == guid then
					unitId = unit .. "target"
				elseif UnitExists(unit .. "pettarget") and UnitGUID(unit .. "pettarget") == guid then
					unitId = unit .. "pettarget"
				end
			end)
		end

		return unitId
	end

	local function GetClassFromGUID(guid)
		local unit = GetUnitIdFromGUID(guid)
		if unit and unit:find("pet") then
			return "PET", unit
		end
		if UnitExists(unit) then
			return select(2, UnitClass(unit)), unit
		end
		return nil, unit
	end

	local function GetCreatureId(guid)
		return guid and tonumber(guid:sub(9, 12), 16) or 0
	end

	local function GetUnitCreatureId(unit)
		return GetCreatureId(UnitGUID(unit))
	end

	local function UnitHealthInfo(unit, guid)
		local health, maxhealth
		if unit and UnitExists(unit) then
			health, maxhealth = UnitHealth(unit), UnitHealthMax(unit)
		end

		if not health and guid then
			unit = GetUnitIdFromGUID(guid)
			if unit then
				health, maxhealth = UnitHealth(unit), UnitHealthMax(unit)
			end
		end

		if health and maxhealth then
			return floor(100 * health / maxhealth), health, maxhealth
		end
	end

	local function UnitPowerInfo(unit, guid, powerType)
		local power, maxpower
		if unit and UnitExists(unit) then
			power, maxpower = UnitPower(unit, powerType), UnitPowerMax(unit, powerType)
		end

		if not power and guid then
			unit = GetUnitIdFromGUID(guid)
			if unit then
				power, maxpower = UnitPower(unit, powerType), UnitPowerMax(unit, powerType)
			end
		end

		if power and maxpower then
			return floor(100 * power / maxpower), power, maxpower
		end
	end

	LibCompat.IsInRaid = IsInRaid
	LibCompat.IsInParty = IsInParty
	LibCompat.IsInGroup = IsInGroup
	LibCompat.IsInPvP = IsInPvP
	LibCompat.GetNumGroupMembers = GetNumGroupMembers
	LibCompat.GetNumSubgroupMembers = GetNumSubgroupMembers
	LibCompat.GetGroupTypeAndCount = GetGroupTypeAndCount
	LibCompat.IsGroupDead = IsGroupDead
	LibCompat.IsGroupInCombat = IsGroupInCombat
	LibCompat.GroupIterator = GroupIterator
	LibCompat.UnitFullName = UnitFullName
	LibCompat.GetUnitIdFromGUID = GetUnitIdFromGUID
	LibCompat.GetClassFromGUID = GetClassFromGUID
	LibCompat.GetCreatureId = GetCreatureId
	LibCompat.GetUnitCreatureId = GetUnitCreatureId
	LibCompat.UnitHealthInfo = UnitHealthInfo
	LibCompat.UnitHealthPercent = UnitHealthInfo -- backwards compatibility
	LibCompat.UnitPowerInfo = UnitPowerInfo
end

-------------------------------------------------------------------------------

do
	local IsRaidLeader, GetPartyLeaderIndex = IsRaidLeader, GetPartyLeaderIndex
	local GetRealNumRaidMembers, GetRaidRosterInfo = GetRealNumRaidMembers, GetRaidRosterInfo

	local function UnitIsGroupLeader(unit)
		if LibCompat.IsInRaid() then
			if unit == "player" then
				return IsRaidLeader()
			end

			local rank = select(2, GetRaidRosterInfo(unit:match("%d+")))
			return (rank and rank == 2)
		end

		if unit == "player" then
			return (GetPartyLeaderIndex() == 0)
		end
		local index = unit:match("%d+")
		return (index and index == GetPartyLeaderIndex())
	end

	local function UnitIsGroupAssistant(unit)
		for i = 1, GetRealNumRaidMembers() do
			local name, rank = GetRaidRosterInfo(i)
			if name == UnitName(unit) then
				return (rank == 1)
			end
		end
		return false
	end

	LibCompat.UnitIsGroupLeader = UnitIsGroupLeader
	LibCompat.UnitIsGroupAssistant = UnitIsGroupAssistant
end

-------------------------------------------------------------------------------
-- Class Colors

do
	local classColorsTable
	local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS

	function LibCompat.GetClassColorsTable()
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
end

-------------------------------------------------------------------------------
-- C_Timer mimic

do
	local Timer = {}

	local TickerPrototype = {}
	local TickerMetatable = {__index = TickerPrototype, __metatable = true}
	local waitTable = {}

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
					ticker._callback(ticker, LibCompat.SafeUnpack(ticker._args or {}))

					if ticker._remainingIterations == -1 then
						ticker._delay = ticker._duration
						i = i + 1
					elseif ticker._remainingIterations > 1 then
						ticker._remainingIterations = ticker._remainingIterations - 1
						ticker._delay = ticker._duration
						i = i + 1
					elseif ticker._remainingIterations == 1 then
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

	local function CreateTicker(duration, callback, iterations, ...)
		local ticker = setmetatable({}, TickerMetatable)
		ticker._remainingIterations = iterations or -1
		ticker._duration = duration
		ticker._delay = duration
		ticker._callback = callback
		ticker._args = LibCompat.SafePack(...)

		AddDelayedCall(ticker)
		return ticker
	end

	function TickerPrototype:IsCancelled()
		return self._cancelled
	end

	function TickerPrototype:Cancel()
		self._cancelled = true
	end

	LibCompat.CancelAllTimers = function()
		for i = 1, #waitTable do
			if waitTable[i] and not waitTable[i]._cancelled then
				waitTable[i]:Cancel()
			end
		end
	end

	LibCompat.After = function(duration, callback, ...)
		AddDelayedCall({
			_remainingIterations = 1,
			_delay = duration,
			_callback = callback,
			_args = LibCompat.SafePack(...)
		})
	end

	LibCompat.NewTimer = function(duration, callback, ...)
		return CreateTicker(duration, callback, 1, ...)
	end

	LibCompat.NewTicker = function(duration, callback, iterations, ...)
		return CreateTicker(duration, callback, iterations, ...)
	end
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

function LibCompat.EscapeStr(str)
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

-------------------------------------------------------------------------------

do
	local LGT = LibStub("LibGroupTalents-1.0")
	local UnitClass, MAX_TALENT_TABS = UnitClass, MAX_TALENT_TABS or 3

	-- list of class to specs
	local specIDs = {
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

	-- checks if the feral druid is a cat or tank spec
	local function GetDruidSubSpec(unit)
		-- 57881 : Natural Reaction -- used by druid tanks
		local points = LGT:UnitHasTalent(unit, LibCompat.GetSpellInfo(57881), LGT:GetActiveTalentGroup(unit))
		return (points and points > 0) and 3 or 2
	end

	local function GetSpecialization(unit, class)
		unit = unit or "player"
		class = class or select(2, UnitClass(unit))

		local spec  -- start with nil

		if unit and specIDs[class] then
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
								index = GetDruidSubSpec(unit)
							end
						else
							index = i
						end
					end
				end
			end

			spec = specIDs[class][index]
		end

		return spec
	end

	local function GetTrueRole(role)
		if role == "melee" or role == "caster" then
			role = "DAMAGER"
		elseif role == "tank" then
			role = "TANK"
		elseif role == "healer" then
			role = "HEALER"
		end
		return role
	end

	local function GetUnitRole(unit)
		return GetTrueRole(LGT:GetUnitRole(unit)) or "NONE"
	end

	local function GetGUIDRole(guid)
		return GetTrueRole(LGT:GetGUIDRole(guid)) or "NONE"
	end

	LibCompat.GetSpecialization = GetSpecialization
	LibCompat.GetUnitRole = GetUnitRole
	LibCompat.GetGUIDRole = GetGUIDRole
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
	"IsInParty",
	"IsInGroup",
	"IsInPvP",
	"GetNumGroupMembers",
	"GetNumSubgroupMembers",
	"GetGroupTypeAndCount",
	"IsGroupDead",
	"IsGroupInCombat",
	"GroupIterator",
	"UnitFullName",
	-- unit util
	"GetUnitIdFromGUID",
	"GetClassFromGUID",
	"GetCreatureId",
	"GetUnitCreatureId",
	"UnitHealthInfo",
	"UnitHealthPercent",
	"UnitPowerInfo",
	"UnitIsGroupLeader",
	"UnitIsGroupAssistant",
	"GetSpecialization",
	"GetUnitRole",
	"GetGUIDRole",
	-- timer unit
	"After",
	"NewTimer",
	"NewTicker",
	"CancelAllTimers",
	-- spell util
	"GetSpellInfo",
	"GetSpellLink",
	-- misc util
	"EscapeStr",
	"GetClassColorsTable",
	"Print",
	"Printf"
}

function LibCompat:Embed(target)
	for k, v in pairs(mixins) do
		target[v] = self[v]
	end
	target.locale = target.locale or GetLocale()
	self.embeds[target] = true
	return target
end

for addon in pairs(LibCompat.embeds) do
	LibCompat:Embed(addon)
end