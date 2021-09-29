assert(Skada, "Skada not found!")

local CCSpells = {
	[118] = true, -- Polymorph (rank 1)
	[12824] = true, -- Polymorph (rank 2)
	[12825] = true, -- Polymorph (rank 3)
	[12826] = true, -- Polymorph (rank 4)
	[28272] = true, -- Polymorph (rank 1:pig)
	[28271] = true, -- Polymorph (rank 1:turtle)
	[3355] = 16, -- Freezing Trap Effect (rank 1)
	[14308] = 16, -- Freezing Trap Effect (rank 2)
	[14309] = 16, -- Freezing Trap Effect (rank 3)
	[6770] = 1, -- Sap (rank 1)
	[2070] = 1, -- Sap (rank 2)
	[11297] = 1, -- Sap (rank 3)
	[6358] = 32, -- Seduction (succubus)
	[60210] = 16, -- Freezing Arrow (rank 1)
	[45524] = 16, -- Chains of Ice
	[33786] = 8, -- Cyclone
	[53308] = 8, -- Entangling Roots
	[2637] = 8, -- Hibernate (rank 1)
	[18657] = 8, -- Hibernate (rank 2)
	[18658] = 8, -- Hibernate (rank 3)
	[20066] = 2, -- Repentance
	[9484] = 2, -- Shackle Undead (rank 1)
	[9485] = 2, -- Shackle Undead (rank 2)
	[10955] = 2, -- Shackle Undead (rank 3)
	[51722] = 1, -- Dismantle
	[710] = 32, -- Banish (Rank 1)
	[18647] = 32, -- Banish (Rank 2)
	[12809] = 1, -- Concussion Blow
	[676] = 1 -- Disarm
}

-- extended CC list for only CC Done and CC Taken modules
local ExtraCCSpells = {
	-- Death Knight
	[47476] = 32, -- Strangulate
	[49203] = 16, -- Hungering Cold
	[47481] = 1, -- Gnaw
	[49560] = 1, -- Death Grip
	-- Druid
	[339] = 8, -- Entangling Roots (rank 1)
	[1062] = 8, -- Entangling Roots (rank 2)
	[5195] = 8, -- Entangling Roots (rank 3)
	[5196] = 8, -- Entangling Roots (rank 4)
	[9852] = 8, -- Entangling Roots (rank 5)
	[9853] = 8, -- Entangling Roots (rank 6)
	[26989] = 8, -- Entangling Roots (rank 7)
	[19975] = 8, -- Entangling Roots (Nature's Grasp rank 1)
	[19974] = 8, -- Entangling Roots (Nature's Grasp rank 2)
	[19973] = 8, -- Entangling Roots (Nature's Grasp rank 3)
	[19972] = 8, -- Entangling Roots (Nature's Grasp rank 4)
	[19971] = 8, -- Entangling Roots (Nature's Grasp rank 5)
	[19970] = 8, -- Entangling Roots (Nature's Grasp rank 6)
	[27010] = 8, -- Entangling Roots (Nature's Grasp rank 7)
	[53313] = 8, -- Entangling Roots (Nature's Grasp)
	[66070] = 8, -- Entangling Roots (Force of Nature)
	[8983] = 1, -- Bash
	[16979] = 1, -- Feral Charge - Bear
	[45334] = 1, -- Feral Charge Effect
	[22570] = 1, -- Maim (rank 1)
	[49802] = 1, -- Maim (rank 2)
	[49803] = 1, -- Pounce
	-- Hunter
	[19503] = 1, -- Scatter Shot
	[19386] = 8, -- Wyvern Sting (rank 1)
	[24132] = 8, -- Wyvern Sting (rank 2)
	[24133] = 8, -- Wyvern Sting (rank 3)
	[27068] = 8, -- Wyvern Sting (rank 4)
	[49011] = 8, -- Wyvern Sting (rank 5)
	[49012] = 8, -- Wyvern Sting (rank 6)
	[53548] = 1, -- Pin (Crab)
	[4167] = 1, -- Web (Spider)
	[55509] = 8, -- Venom Web Spray (Silithid)
	[24394] = 1, -- Intimidation
	[19577] = 8, -- Intimidation (stun)
	[53568] = 8, -- Sonic Blast (Bat)
	[53543] = 1, -- Snatch (Bird of Prey)
	[50541] = 1, -- Clench (Scorpid)
	[55492] = true, -- Froststorm Breath (Chimaera)
	[26090] = 8, -- Pummel (Gorilla)
	[53575] = 1, -- Tendon Rip (Hyena)
	[53589] = 32, -- Nether Shock (Nether Ray)
	[53562] = 1, -- Ravage (Ravager)
	[1513] = 8, -- Scare Beast
	[64803] = 1, -- Entrapment
	-- Mage
	[61305] = true, -- Polymorph Cat
	[61721] = true, -- Polymorph Rabbit
	[61780] = true, -- Polymorph Turkey
	[31661] = true, -- Dragon's Breath
	[44572] = 16, -- Deep Freeze
	[122] = 16, -- Frost Nova (rank 1)
	[865] = 16, -- Frost Nova (rank 2)
	[6131] = 16, -- Frost Nova (rank 3)
	[10230] = 16, -- Frost Nova (rank 4)
	[27088] = 16, -- Frost Nova (rank 5)
	[42917] = 16, -- Frost Nova (rank 6)
	[33395] = 33395, -- Freeze (Frost Water Elemental)
	[55021] = true, -- Silenced - Improved Counterspell
	-- Paladin
	[853] = 2, -- Hammer of Justice (rank 1)
	[5588] = 2, -- Hammer of Justice (rank 2)
	[5589] = 2, -- Hammer of Justice (rank 3)
	[10308] = 2, -- Hammer of Justice (rank 4)
	[10326] = 2, -- Turn Evil
	[2812] = 2, -- Holy Wrath (rank 1)
	[10318] = 2, -- Holy Wrath (rank 2)
	[27319] = 2, -- Holy Wrath (rank 3)
	[48816] = 2, -- Holy Wrath (rank 4)
	[48817] = 2, -- Holy Wrath (rank 5)
	[31935] = 2, -- Avengers Shield
	-- Priest
	[8122] = 32, -- Psychic Scream (rank 1)
	[8124] = 32, -- Psychic Scream (rank 2)
	[10888] = 32, -- Psychic Scream (rank 3)
	[10890] = 32, -- Psychic Scream (rank 4)
	[605] = 32, -- Dominate Mind (Mind Control)
	[15487] = 32, -- Silence
	[64044] = 32, -- Psychic Horror
	-- Rogue
	[51724] = 1, -- Sap
	[408] = 1, -- Kidney Shot (rank 1)
	[8643] = 1, -- Kidney Shot (rank 2)
	[2094] = 1, -- Blind
	[1833] = 1, -- Cheap Shot
	[1776] = 1, -- Gouge
	[1330] = 1, -- Garrote - Silence
	-- Shaman
	[51514] = 8, -- Hex
	[8056] = 16, -- Frost Shock (rank 1)
	[8058] = 16, -- Frost Shock (rank 2)
	[10472] = 16, -- Frost Shock (rank 3)
	[10473] = 16, -- Frost Shock (rank 4)
	[25464] = 16, -- Frost Shock (rank 5)
	[49235] = 16, -- Frost Shock (rank 6)
	[49236] = 16, -- Frost Shock (rank 7)
	[64695] = 8, -- Earthgrab (Earthbind Totem with Storm, Earth and Fire talent)
	[3600] = 8, -- Earthbind (Earthbind Totem)
	[39796] = 1, -- Stoneclaw Stun (Stoneclaw Totem)
	[8034] = 16, -- Frostbrand Weapon (rank 1)
	[8037] = 16, -- Frostbrand Weapon (rank 2)
	[10458] = 16, -- Frostbrand Weapon (rank 3)
	[16352] = 16, -- Frostbrand Weapon (rank 4)
	[16353] = 16, -- Frostbrand Weapon (rank 5)
	[25501] = 16, -- Frostbrand Weapon (rank 6)
	[58797] = 16, -- Frostbrand Weapon (rank 7)
	[58798] = 16, -- Frostbrand Weapon (rank 8)
	[58799] = 16, -- Frostbrand Weapon (rank 9)
	-- Warlock
	[6215] = 32, -- Fear
	[5484] = 32, -- Howl of Terror
	[30283] = 32, -- Shadowfury
	[22703] = 4, -- Infernal Awakening
	[6789] = 32, -- Death Coil (rank 1)
	[17925] = 32, -- Death Coil (rank 2)
	[17926] = 32, -- Death Coil (rank 3)
	[27223] = 32, -- Death Coil (rank 4)
	[47859] = 32, -- Death Coil (rank 5)
	[47860] = 32, -- Death Coil (rank 6)
	[24259] = 32, -- Spell Lock
	-- Warrior
	[5246] = 1, -- Initmidating Shout
	[46968] = 1, -- Shockwave
	[6552] = 1, -- Pummel
	[58357] = 1, -- Heroic Throw silence
	[7922] = 1, -- Charge
	[47995] = 1, -- Intercept (Stun)--needs review
	[12323] = 1, -- Piercing Howl
	-- Racials
	[20549] = 1, -- War Stomp (Tauren)
	[28730] = true, -- Arcane Torrent (Bloodelf)
	[47779] = true, -- Arcane Torrent (Bloodelf)
	[50613] = true, -- Arcane Torrent (Bloodelf)
	-- Engineering
	[67890] = 4 -- Cobalt Frag Bomb
}

local pairs, ipairs, select = pairs, ipairs, select
local tostring, format = tostring, string.format
local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local GetSpellLink, UnitClass = Skada.GetSpellLink or GetSpellLink, Skada.UnitClass
local _

local function GetSpellSchool(spellid)
	if CCSpells[spellid] and CCSpells[spellid] ~= true then
		return CCSpells[spellid]
	end
	if ExtraCCSpells[spellid] and ExtraCCSpells[spellid] ~= true then
		return ExtraCCSpells[spellid]
	end
end

-- ======= --
-- CC Done --
-- ======= --
Skada:AddLoadableModule("CC Done", function(Skada, L)
	if Skada:IsDisabled("CC Done") then return end

	local mod = Skada:NewModule(L["CC Done"])
	local playermod = mod:NewModule(L["CC Done spells"])
	local targetmod = mod:NewModule(L["CC Done targets"])
	local function log_ccdone(set, cc)
		local player = Skada:get_player(set, cc.playerid, cc.playername, cc.playerflags)
		if player then
			-- increment the count.
			player.ccdone = (player.ccdone or 0) + 1
			set.ccdone = (set.ccdone or 0) + 1

			-- record the spell and its targets.
			player.ccdone_spells = player.ccdone_spells or {}
			player.ccdone_spells[cc.spellid] = (player.ccdone_spells[cc.spellid] or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.current and cc.dstName then
				player.ccdone_targets = player.ccdone_targets or {}
				player.ccdone_targets[cc.dstName] = (player.ccdone_targets[cc.dstName] or 0) + 1
			end
		end
	end

	local data = {}

	local function SpellAuraApplied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...

		if CCSpells[spellid] or ExtraCCSpells[spellid] then
			data.playerid, data.playername = Skada:FixMyPets(srcGUID, srcName, srcFlags)
			data.playerflags = srcFlags

			data.dstGUID = dstGUID
			data.dstName = dstName

			data.spellid = spellid

			log_ccdone(Skada.current, data)
			log_ccdone(Skada.total, data)
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's CC Done spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = format(L["%s's CC Done spells"], player.name)
			local total = player.ccdone or 0

			if total > 0 and player.ccdone_spells then
				local maxvalue, nr = 0, 1

				for spellid, count in pairs(player.ccdone_spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)
					d.spellschool = GetSpellSchool(spellid)

					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's CC Done targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = format(L["%s's CC Done targets"], player.name)
			local total = player.ccdone or 0

			if total > 0 and player.ccdone_targets then
				local maxvalue, nr = 0, 1

				for targetname, count in pairs(player.ccdone_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname

					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["CC Done"]
		local total = set.ccdone or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.ccdone or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.ccdone
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Count = true, Percent = false},
			icon = "Interface\\Icons\\spell_frost_chainsofice"
		}

		Skada:RegisterForCL(SpellAuraApplied, "SPELL_AURA_APPLIED", {src_is_interesting = true})
		Skada:RegisterForCL(SpellAuraApplied, "SPELL_AURA_REFRESH", {src_is_interesting = true})

		Skada:AddMode(self, L["CC Tracker"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if (set.ccdone or 0) > 0 then
			tooltip:AddDoubleLine(L["CC Done"], set.ccdone, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return tostring(set.ccdone or 0), set.ccdone or 0
	end
end)

-- ======== --
-- CC Taken --
-- ======== --
Skada:AddLoadableModule("CC Taken", function(Skada, L)
	if Skada:IsDisabled("CC Taken") then return end

	local mod = Skada:NewModule(L["CC Taken"])
	local playermod = mod:NewModule(L["CC Taken spells"])
	local sourcemod = mod:NewModule(L["CC Taken sources"])

	local function log_cctaken(set, cc)
		local player = Skada:get_player(set, cc.playerid, cc.playername, cc.playerflags)
		if player then
			-- increment the count.
			player.cctaken = (player.cctaken or 0) + 1
			set.cctaken = (set.cctaken or 0) + 1

			-- record the spell and its sources.
			player.cctaken_spells = player.cctaken_spells or {}
			player.cctaken_spells[cc.spellid] = (player.cctaken_spells[cc.spellid] or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.current and cc.srcName then
				player.cctaken_sources = player.cctaken_sources or {}
				player.cctaken_sources[cc.srcName] = (player.cctaken_sources[cc.srcName] or 0) + 1
			end
		end
	end

	local data = {}

	local function SpellAuraApplied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...

		if CCSpells[spellid] or ExtraCCSpells[spellid] then
			data.srcGUID = srcGUID
			data.srcName = srcName

			data.playerid = dstGUID
			data.playername = dstName
			data.playerflags = dstFlags

			data.spellid = spellid

			log_cctaken(Skada.current, data)
			log_cctaken(Skada.total, data)
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's CC Taken spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = format(L["%s's CC Taken spells"], player.name)
			local total = player.cctaken or 0

			if total > 0 and player.cctaken_spells then
				local maxvalue, nr = 0, 1

				for spellid, count in pairs(player.cctaken_spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)
					d.spellschool = GetSpellSchool(spellid)

					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function sourcemod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's CC Taken sources"], label)
	end

	function sourcemod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = format(L["%s's CC Taken sources"], player.name)
			local total = player.cctaken or 0

			if total > 0 and player.cctaken_sources then
				local maxvalue, nr = 0, 1

				for sourcename, count in pairs(player.cctaken_sources) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = sourcename
					d.label = sourcename

					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["CC Taken"]
		local total = set.cctaken or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.cctaken or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.cctaken
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = sourcemod,
			nototalclick = {sourcemod},
			columns = {Count = true, Percent = false},
			icon = "Interface\\Icons\\spell_magic_polymorphrabbit"
		}

		Skada:RegisterForCL(SpellAuraApplied, "SPELL_AURA_APPLIED", {dst_is_interesting = true})
		Skada:RegisterForCL(SpellAuraApplied, "SPELL_AURA_REFRESH", {dst_is_interesting = true})

		Skada:AddMode(self, L["CC Tracker"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if (set.cctaken or 0) > 0 then
			tooltip:AddDoubleLine(L["CC Taken"], set.cctaken, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return tostring(set.cctaken or 0), set.cctaken or 0
	end
end)

-- =========== --
-- CC Breakers --
-- =========== --
Skada:AddLoadableModule("CC Breakers", function(Skada, L)
	if Skada:IsDisabled("CC Breakers") then return end

	local mod = Skada:NewModule(L["CC Breakers"])
	local playermod = mod:NewModule(L["CC Break spells"])
	local targetmod = mod:NewModule(L["CC Break targets"])

	local UnitExists, UnitName, IsInRaid = UnitExists, UnitName, Skada.IsInRaid
	local GetNumRaidMembers, GetPartyAssignment = GetNumRaidMembers, GetPartyAssignment
	local IsInInstance, UnitInRaid = IsInInstance, UnitInRaid

	local function log_ccbreak(set, cc)
		local player = Skada:get_player(set, cc.playerid, cc.playername)
		if player then
			-- increment the count.
			player.ccbreak = (player.ccbreak or 0) + 1
			set.ccbreak = (set.ccbreak or 0) + 1

			-- record the spell and its targets.
			player.ccbreak_spells = player.ccbreak_spells or {}
			player.ccbreak_spells[cc.spellid] = (player.ccbreak_spells[cc.spellid] or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.current and cc.dstName then
				player.ccbreak_targets = player.ccbreak_targets or {}
				player.ccbreak_targets[cc.dstName] = (player.ccbreak_targets[cc.dstName] or 0) + 1
			end
		end
	end

	local data = {}

	local function SpellAuraBroken(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, _, extraspellid, extraspellname, _, auratype = ...
		if not CCSpells[spellid] then return end

		local petid, petname = srcGUID, srcName
		local srcGUID_modified, srcName_modified = Skada:FixMyPets(srcGUID, srcName, srcFlags)

		data.playerid = srcGUID_modified or srcGUID
		data.playername = srcName_modified or srcName
		data.playerflags = srcFlags

		data.dstGUID = dstGUID
		data.dstName = dstName
		data.dstFlags = dstFlags

		data.spellid = spellid
		data.extraspellid = extraspellid

		log_ccbreak(Skada.current, data)
		log_ccbreak(Skada.total, data)

		-- Optional announce
		srcName = srcName_modified or srcName
		if Skada.db.profile.modules.ccannounce and IsInRaid() and UnitInRaid(srcName) then
			if select(2, IsInInstance()) == "pvp" then return end

			-- Ignore main tanks and main assist?
			if Skada.db.profile.modules.ccignoremaintanks then
				-- Loop through our raid and return if src is a main tank.
				for i = 1, GetNumRaidMembers() do
					local unit = "raid" .. tostring(i)
					if UnitExists(unit) and UnitName(unit) == srcName then
						if GetPartyAssignment("MAINTANK", unit) or GetPartyAssignment("MAINASSIST", unit) then
							return
						end
						break
					end
				end
			end

			-- Prettify pets.
			if petid ~= srcGUID_modified then
				srcName = petname .. " (" .. srcName .. ")"
			end

			-- Go ahead and announce it.
			if extraspellname then
				Skada:SendChat(format(L["%s on %s removed by %s's %s"], spellname, dstName, srcName, GetSpellLink(extraspellid)), "RAID", "preset")
			else
				Skada:SendChat(format(L["%s on %s removed by %s"], spellname, dstName, srcName), "RAID", "preset")
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's CC Break spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = format(L["%s's CC Break spells"], player.name)
			local total = player.ccbreak or 0

			if total > 0 and player.ccbreak_spells then
				local maxvalue, nr = 0, 1

				for spellid, count in pairs(player.ccbreak_spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)
					d.spellschool = GetSpellSchool(spellid)

					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's CC Break targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = format(L["%s's CC Break targets"], player.name)
			local total = player.ccbreak or 0

			if total > 0 and player.ccbreak_targets then
				local maxvalue, nr = 0, 1

				for targetname, count in pairs(player.ccbreak_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname

					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["CC Breakers"]
		local total = set.ccbreak or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.ccbreak or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.ccbreak
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Count = true, Percent = false},
			icon = "Interface\\Icons\\spell_holy_sealofvalor"
		}

		Skada:RegisterForCL(SpellAuraBroken, "SPELL_AURA_BROKEN", {src_is_interesting = true})
		Skada:RegisterForCL(SpellAuraBroken, "SPELL_AURA_BROKEN_SPELL", {src_is_interesting = true})

		Skada:AddMode(self, L["CC Tracker"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if (set.ccbreak or 0) > 0 then
			tooltip:AddDoubleLine(L["CC Breaks"], set.ccbreak, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return tostring(set.ccbreak or 0), set.ccbreak or 0
	end

	function mod:OnInitialize()
		Skada.options.args.modules.args.ccoptions = {
			type = "group",
			name = self.moduleName,
			desc = format(L["Options for %s."], self.moduleName),
			get = function(i)
				return Skada.db.profile.modules[i[#i]]
			end,
			set = function(i, val)
				Skada.db.profile.modules[i[#i]] = val
			end,
			args = {
				ccannounce = {
					type = "toggle",
					name = L["Announce CC breaking to party"],
					order = 1,
					width = "double"
				},
				ccignoremaintanks = {
					type = "toggle",
					name = L["Ignore Main Tanks"],
					order = 2,
					width = "double"
				}
			}
		}
	end
end)