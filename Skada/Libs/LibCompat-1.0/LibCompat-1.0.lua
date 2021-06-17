--
-- **LibCompat-1.0** provided few handy functions that can be embed to addons.
-- This library was originally created for Skada 1.8.50 for WoTLK.
-- @author: Kader B (https://github.com/bkader)
--

local MAJOR, MINOR = "LibCompat-1.0", 1

local LibCompat, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not LibCompat then return end

LibCompat.embeds = LibCompat.embeds or {}

local pairs, select = pairs, select
local CreateFrame = CreateFrame
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance

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
			if UnitExists(prefix .. i) and not UnitIsDeadOrGhost(prefix .. i) then
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
			if UnitExists(prefix .. i) and UnitAffectingCombat(prefix .. i) then
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

local mixins = {
	"IsInRaid", "IsInParty", "IsInGroup", "IsInPvP",
	"GetGroupTypeAndCount",
	"After", "NewTimer", "NewTicker",
	"IsGroupDead", "IsGroupInCombat",
	"GetClassColorsTable",
	"GetSpellInfo", "GetSpellLink"
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