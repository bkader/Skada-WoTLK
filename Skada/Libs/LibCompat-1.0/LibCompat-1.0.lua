--
-- **LibCompat-1.0** provided few handy functions that can be embed to addons.
-- This library was originally created for Skada as of 1.8.50.
-- @author: Kader B (https://github.com/bkader)
--

local MAJOR, MINOR = "LibCompat-1.0", 2

local LibCompat, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not LibCompat then return end

LibCompat.embeds = LibCompat.embeds or {}

local pairs, select, tinsert = pairs, select, table.insert
local CreateFrame = CreateFrame
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance

-------------------------------------------------------------------------------

function LibCompat.tlength(tbl)
	local len = 0
	for _ in pairs(tbl) do
		len = len + 1
	end
	return len
end

-- copies a table from another
function LibCompat.tCopy(to, from, ...)
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
				LibCompat.tCopy(to[k], v, ...)
			else
				to[k] = v
			end
		end
	end
end

function LibCompat.tAppendAll(tbl, elems)
	for _, elem in ipairs(elems) do
		tinsert(tbl, elem)
	end
end

-------------------------------------------------------------------------------

function LibCompat:IsInRaid()
	return (GetNumRaidMembers() > 0)
end

function LibCompat:IsInParty()
	return (GetNumPartyMembers() > 0)
end

function LibCompat:IsInGroup()
	return (self:IsInRaid() or self:IsInParty())
end

function LibCompat:IsInPvP()
	local instanceType = select(2, IsInInstance())
	return (instanceType == "pvp" or instanceType == "arena")
end

function LibCompat:GetGroupTypeAndCount()
	local prefix, min_member, max_member = "raid", 1, GetNumRaidMembers()

	if max_member == 0 then
		prefix, min_member, max_member = "party", 0, GetNumPartyMembers()
	end

	if max_member == 0 then
		prefix, min_member, max_member = nil, 0, 0
	end

	return prefix, min_member, max_member
end

function LibCompat:IsGroupDead()
	local prefix, min_member, max_member = self:GetGroupTypeAndCount()
	if prefix then
		for i = min_member, max_member do
			local unit = (i == 0) and "player" or prefix .. i
			if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
				return false
			end
		end
	end

	if not UnitIsDeadOrGhost("player") then
		return false
	end

	return true
end

function LibCompat:IsGroupInCombat()
	local prefix, min_member, max_member = self:GetGroupTypeAndCount()
	if prefix then
		for i = min_member, max_member do
			local unit = (i == 0) and "player" or prefix .. i
			if UnitExists(unit) and UnitAffectingCombat(unit) then
				return true
			end
		end
	end

	if UnitAffectingCombat("player") or InCombatLockdown() then
		return true
	end

	return false
end

-------------------------------------------------------------------------------
-- Class Colors

do
	local classColorsTable
	local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS

	function LibCompat:GetClassColorsTable()
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
	local type, setmetatable = type, setmetatable
	local tinsert, tremove = table.insert, table.remove

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
					ticker._callback(ticker)

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

	local function CreateTicker(duration, callback, iterations)
		local ticker = setmetatable({}, TickerMetatable)
		ticker._remainingIterations = iterations or -1
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

	LibCompat.After = function(duration, callback)
		AddDelayedCall({
			_remainingIterations = 1,
			_delay = duration,
			_callback = callback
		})
	end

	LibCompat.NewTimer = function(duration, callback)
		return CreateTicker(duration, callback, 1)
	end

	LibCompat.NewTicker = function(duration, callback, iterations)
		return CreateTicker(duration, callback, iterations)
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

	function LibCompat.GetSpellInfo(spellid)
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

	function LibCompat.GetSpellLink(spellid)
		if not custom[spellid] then
			return GetSpellLink(spellid)
		end
	end
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
	local GetPlayerInfoByGUID = GetPlayerInfoByGUID
	local UnitExists, UnitClass, UnitName = UnitExists, UnitClass, UnitName
	local MAX_TALENT_TABS = MAX_TALENT_TABS or 3

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

	local Guid2Talent = {}
	local Guid2Spec = {}
	local Guid2Unit = {}

	-- checks if the feral druid is a cat or tank spec
	local function GetDruidSubSpec(unit)
		-- 57881 : Natural Reaction -- used by druid tanks
		local points = LGT:UnitHasTalent(unit, LibCompat.GetSpellInfo(57881), LGT:GetActiveTalentGroup(unit))
		return (points and points > 0) and 3 or 2
	end

	function LibCompat.GetSpecialization(unit, class)
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

	function LibCompat.UnitGroupRolesAssigned(unit)
		local role = LGT:GetUnitRole(unit) or "NONE"
		if role == "melee" or role == "caster" then
			role = "DAMAGER"
		elseif role == "tank" then
			role = "TANK"
		elseif role == "healer" then
			role = "HEALER"
		end
		return role
	end

	function LibCompat.GetGUIDTalentString(guid)
		-- already cached?
		if Guid2Talent[guid] then
			return Guid2Talent[guid]
		end

		local n1, n2, n3 = select(2, LGT:GetGUIDTalentSpec(guid))
		if n1 and n2 and n3 then
			Guid2Talent[guid] = n1 .. "/" .. n2 .. "/" .. n3
			return Guid2Talent[guid]
		end

		return ""
	end

	function LibCompat.GetGUIDSpecialization(guid)
		if Guid2Spec[guid] then
			return Guid2Spec[guid]
		end

		local unit = Guid2Unit[guid]
		if unit and UnitExists(unit) then
			local spec = self.GetSpecialization(unit, class)
			if spec then
				Guid2Spec[guid] = spec
				return Guid2Spec[guid]
			end
		end
	end

	function LibCompat:LibGroupTalents_Update(event, guid, unit, tree_id, n1, n2, n3)
		-- cache guid to unit
		Guid2Unit[guid] = unit

		-- cache talent strings
		Guid2Talent[guid] = n1 .. "/" .. n2 .. "/" .. n3

		local class = select(2, GetPlayerInfoByGUID(guid)) or select(2, UnitClass(unit))
		local spec = self.GetSpecialization(unit, class)
		if spec then
			Guid2Spec[guid] = spec
		end
	end
	LGT.RegisterCallback(LibCompat, "LibGroupTalents_Update")
end

-------------------------------------------------------------------------------

local mixins = {
	"IsInRaid",
	"IsInParty",
	"IsInGroup",
	"IsInPvP",
	"GetGroupTypeAndCount",
	"After",
	"NewTimer",
	"NewTicker",
	"IsGroupDead",
	"IsGroupInCombat",
	"GetClassColorsTable",
	"GetSpellInfo",
	"GetSpellLink",
	"tlength",
	"tCopy",
	"tAppendAll",
	"EscapeStr",
	"GetSpecialization",
	"UnitGroupRolesAssigned",
	"GetGUIDTalentString",
	"GetGUIDSpecialization"
}

function LibCompat:Embed(target)
	for k, v in pairs(mixins) do
		target[v] = self[v]
	end
	self.embeds[target] = true
	return target
end

for addon in pairs(LibCompat.embeds) do
	LibCompat:Embed(addon)
end
