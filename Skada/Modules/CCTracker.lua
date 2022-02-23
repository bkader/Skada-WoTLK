local Skada = Skada

local pairs, ipairs, select = pairs, ipairs, select
local tostring, format = tostring, string.format
local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local GetSpellLink = Skada.GetSpellLink or GetSpellLink
local playerPrototype = Skada.playerPrototype
local _

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
Skada:AddLoadableModule("CC Done", function(L)
	if Skada:IsDisabled("CC Done") then return end

	local mod = Skada:NewModule(L["CC Done"])
	local playermod = mod:NewModule(L["Crowd Control Spells"])
	local targetmod = mod:NewModule(L["Crowd Control Targets"])

	local function log_ccdone(set, cc)
		local player = Skada:GetPlayer(set, cc.playerid, cc.playername, cc.playerflags)
		if player then
			-- increment the count.
			player.ccdone = (player.ccdone or 0) + 1
			set.ccdone = (set.ccdone or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.total then return end

			-- record the spell.
			local spell = player.ccdonespells and player.ccdonespells[cc.spellid]
			if not spell then
				player.ccdonespells = player.ccdonespells or {}
				player.ccdonespells[cc.spellid] = {count = 0}
				spell = player.ccdonespells[cc.spellid]
			end
			spell.count = spell.count + 1

			-- record the target.
			if cc.dstName then
				local actor = Skada:GetActor(set, cc.dstGUID, cc.dstName, cc.dstFlags)
				if actor then
					spell.targets = spell.targets or {}
					spell.targets[cc.dstName] = (spell.targets[cc.dstName] or 0) + 1
				end
			end
		end
	end

	local data = {}

	local function AuraApplied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...

		if CCSpells[spellid] or ExtraCCSpells[spellid] then
			data.playerid, data.playername = Skada:FixMyPets(srcGUID, srcName, srcFlags)
			data.playerflags = srcFlags

			data.dstGUID = dstGUID
			data.dstName = dstName
			data.dstFlags = dstFlags

			data.spellid = spellid

			Skada:DispatchSets(log_ccdone, data)
			log_ccdone(Skada.total, data)
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's control spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's control spells"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.ccdone or 0

		if total > 0 and player.ccdonespells then
			local nr = 0
			for spellid, spell in pairs(player.ccdonespells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)
				d.spellschool = GetSpellSchool(spellid)

				d.value = spell.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's control targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's control targets"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.ccdone or 0
		local targets = (total > 0) and player:GetCCDoneTargets()

		if targets then
			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["CC Done"], L[win.class]) or L["CC Done"]

		local total = set.ccdone or 0
		if total > 0 then
			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.ccdone or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.ccdone
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Count and d.value,
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod, targetmod},
			columns = {Count = true, Percent = false},
			icon = [[Interface\Icons\spell_frost_chainsofice]]
		}

		Skada:RegisterForCL(
			AuraApplied,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			{src_is_interesting = true}
		)

		Skada:AddMode(self, L["Crowd Control"])
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

	function playerPrototype:GetCCDoneTargets(tbl)
		if self.ccdonespells then
			tbl = wipe(tbl or Skada.cacheTable)
			for _, spell in pairs(self.ccdonespells) do
				if spell.targets then
					for name, count in pairs(spell.targets) do
						if not tbl[name] then
							tbl[name] = {count = count}
						else
							tbl[name].count = tbl[name].count + count
						end
						if not tbl[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								tbl[name].class = actor.class
								tbl[name].role = actor.role
								tbl[name].spec = actor.spec
							else
								tbl[name].class = "UNKNOWN"
							end
						end
					end
				end
			end
			return tbl
		end
	end
end)

-- ======== --
-- CC Taken --
-- ======== --
Skada:AddLoadableModule("CC Taken", function(L)
	if Skada:IsDisabled("CC Taken") then return end

	local mod = Skada:NewModule(L["CC Taken"])
	local playermod = mod:NewModule(L["Crowd Control Spells"])
	local sourcemod = mod:NewModule(L["Crowd Control Sources"])

	local RaidCCSpells = {
		[16869] = 16, -- Maleki the Pallid/Ossirian the Unscarred: Ice Tomb (Stratholme/??)
		[29670] = 16, -- Frostwarden Sorceress: Ice Tomb (Karazhan)
		[29670] = 16, -- Skeletal Usher: Ice Tomb (Karazhan)
		[69065] = 1, -- Bone Spike: Impale (Icecrown Citadel: Lord Marrowgar)
		[70157] = 16, -- Sindragosa: Ice Tomb (Icecrown Citadel)
		[70447] = 64, -- Green Ooze: Volatile Ooze Adhesive (Icecrown Citadel: Professor Putricide)
		[71289] = 32, -- Lady Deathwhisper: Dominate Mind (Icecrown Citadel)
		[72836] = 64, -- Green Ooze: Volatile Ooze Adhesive (Icecrown Citadel: Professor Putricide)
		[72837] = 64, -- Green Ooze: Volatile Ooze Adhesive (Icecrown Citadel: Professor Putricide)
		[72838] = 64 -- Green Ooze: Volatile Ooze Adhesive (Icecrown Citadel: Professor Putricide)
	}

	local function log_cctaken(set, cc)
		local player = Skada:GetPlayer(set, cc.playerid, cc.playername, cc.playerflags)
		if player then
			-- increment the count.
			player.cctaken = (player.cctaken or 0) + 1
			set.cctaken = (set.cctaken or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.total then return end

			-- record the spell.
			local spell = player.cctakenspells and player.cctakenspells[cc.spellid]
			if not spell then
				player.cctakenspells = player.cctakenspells or {}
				player.cctakenspells[cc.spellid] = {count = 0}
				spell = player.cctakenspells[cc.spellid]
			end
			spell.count = spell.count + 1

			-- record the source.
			if cc.srcName then
				local actor = Skada:GetActor(set, cc.srcGUID, cc.srcName, cc.srcFlags)
				if actor then
					spell.sources = spell.sources or {}
					spell.sources[cc.srcName] = (spell.sources[cc.srcName] or 0) + 1
				end
			end
		end
	end

	local data = {}

	local function AuraApplied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...

		if CCSpells[spellid] or ExtraCCSpells[spellid] or RaidCCSpells[spellid] then
			data.srcGUID = srcGUID
			data.srcName = srcName
			data.srcFlags = srcFlags

			data.playerid = dstGUID
			data.playername = dstName
			data.playerflags = dstFlags

			data.spellid = spellid

			Skada:DispatchSets(log_cctaken, data)
			log_cctaken(Skada.total, data)
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's control spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's control spells"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.cctaken or 0

		if total > 0 and player.cctakenspells then
			local nr = 0
			for spellid, spell in pairs(player.cctakenspells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)
				d.spellschool = GetSpellSchool(spellid) or RaidCCSpells[spellid]

				d.value = spell.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function sourcemod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's control sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = format(L["%s's control sources"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.cctaken or 0
		local sources = (total > 0) and player:GetCCTakenSources()

		if sources then
			local nr = 0
			for sourcename, source in pairs(sources) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = source.id or sourcename
				d.label = sourcename
				d.class = source.class
				d.role = source.role
				d.spec = source.spec

				d.value = source.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["CC Taken"], L[win.class]) or L["CC Taken"]

		local total = set.cctaken or 0
		if total > 0 then
			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.cctaken or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.cctaken
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Count and d.value,
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = sourcemod,
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod, sourcemod},
			columns = {Count = true, Percent = false},
			icon = [[Interface\Icons\spell_magic_polymorphrabbit]]
		}

		Skada:RegisterForCL(
			AuraApplied,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			{dst_is_interesting = true}
		)

		Skada:AddMode(self, L["Crowd Control"])
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

	function playerPrototype:GetCCTakenSources(tbl)
		if self.cctakenspells then
			tbl = wipe(tbl or Skada.cacheTable)
			for _, spell in pairs(self.cctakenspells) do
				if spell.sources then
					for name, count in pairs(spell.sources) do
						if not tbl[name] then
							tbl[name] = {count = count}
						else
							tbl[name].count = tbl[name].count + count
						end
						if not tbl[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								tbl[name].class = actor.class
								tbl[name].role = actor.role
								tbl[name].spec = actor.spec
							else
								tbl[name].class = "UNKNOWN"
							end
						end
					end
				end
			end
			return tbl
		end
	end
end)

-- =========== --
-- CC Breakers --
-- =========== --
Skada:AddLoadableModule("CC Breaks", function(L)
	if Skada:IsDisabled("CC Breaks") then return end

	local mod = Skada:NewModule(L["CC Breaks"])
	local playermod = mod:NewModule(L["Crowd Control Spells"])
	local targetmod = mod:NewModule(L["Crowd Control Targets"])

	local UnitExists, UnitName, IsInRaid = UnitExists, UnitName, Skada.IsInRaid
	local GetNumRaidMembers, GetPartyAssignment = GetNumRaidMembers, GetPartyAssignment
	local IsInInstance, UnitInRaid = IsInInstance, UnitInRaid
	local UnitIterator = Skada.UnitIterator

	local function log_ccbreak(set, cc)
		local player = Skada:GetPlayer(set, cc.playerid, cc.playername)
		if player then
			-- increment the count.
			player.ccbreak = (player.ccbreak or 0) + 1
			set.ccbreak = (set.ccbreak or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.total then return end

			-- record the spell.
			local spell = player.ccbreakspells and player.ccbreakspells[cc.spellid]
			if not spell then
				player.ccbreakspells = player.ccbreakspells or {}
				player.ccbreakspells[cc.spellid] = {count = 0}
				spell = player.ccbreakspells[cc.spellid]
			end
			spell.count = spell.count + 1

			-- record the target.
			if cc.dstName then
				local actor = Skada:GetActor(set, cc.dstGUID, cc.dstName, cc.dstFlags)
				if actor then
					spell.targets = spell.targets or {}
					spell.targets[cc.dstName] = (spell.targets[cc.dstName] or 0) + 1
				end
			end
		end
	end

	local data = {}

	local function AuraBroken(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
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

		Skada:DispatchSets(log_ccbreak, data)
		log_ccbreak(Skada.total, data)

		-- Optional announce
		srcName = srcName_modified or srcName
		if Skada.db.profile.modules.ccannounce and IsInRaid() and UnitInRaid(srcName) then
			if select(2, IsInInstance()) == "pvp" then return end

			-- Ignore main tanks and main assist?
			if Skada.db.profile.modules.ccignoremaintanks then
				-- Loop through our raid and return if src is a main tank.
				for unit in UnitIterator(true) do -- exclude pets
					if UnitName(unit) == srcName and (GetPartyAssignment("MAINTANK", unit) or GetPartyAssignment("MAINASSIST", unit)) then
						return
					end
				end
			end

			-- Prettify pets.
			if petid ~= srcGUID_modified then
				srcName = petname .. " (" .. srcName .. ")"
			end

			-- Go ahead and announce it.
			if extraspellname then
				Skada:SendChat(format(L["%s on %s removed by %s's %s"], spellname, dstName, srcName, GetSpellLink(extraspellid)), "RAID", "preset", true)
			else
				Skada:SendChat(format(L["%s on %s removed by %s"], spellname, dstName, srcName), "RAID", "preset", true)
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's control spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's control spells"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.ccbreak or 0

		if total > 0 and player.ccbreakspells then
			local nr = 0
			for spellid, spell in pairs(player.ccbreakspells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)
				d.spellschool = GetSpellSchool(spellid)

				d.value = spell.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's control targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's control targets"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.ccbreak or 0
		local targets = (total > 0) and player:GetCCBreakTargets()

		if targets then
			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["CC Breaks"], L[win.class]) or L["CC Breaks"]

		local total = set.ccbreak or 0
		if total > 0 then
			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.ccbreak or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.ccbreak
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Count and d.value,
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod, targetmod},
			columns = {Count = true, Percent = false},
			icon = [[Interface\Icons\spell_holy_sealofvalor]]
		}

		Skada:RegisterForCL(
			AuraBroken,
			"SPELL_AURA_BROKEN",
			"SPELL_AURA_BROKEN_SPELL",
			{src_is_interesting = true}
		)

		Skada:AddMode(self, L["Crowd Control"])
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

	function playerPrototype:GetCCBreakTargets(tbl)
		if self.ccbreakspells then
			tbl = wipe(tbl or Skada.cacheTable)
			for _, spell in pairs(self.ccbreakspells) do
				if spell.targets then
					for name, count in pairs(spell.targets) do
						if not tbl[name] then
							tbl[name] = {count = count}
						else
							tbl[name].count = tbl[name].count + count
						end
						if not tbl[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								tbl[name].class = actor.class
								tbl[name].role = actor.role
								tbl[name].spec = actor.spec
							else
								tbl[name].class = "UNKNOWN"
							end
						end
					end
				end
			end
			return tbl
		end
	end

	function mod:OnInitialize()
		Skada.options.args.modules.args.ccoptions = {
			type = "group",
			name = self.moduleName,
			desc = format(L["Options for %s."], self.moduleName),
			args = {
				header = {
					type = "description",
					name = self.moduleName,
					fontSize = "large",
					image = [[Interface\Icons\spell_holy_sealofvalor]],
					imageWidth = 18,
					imageHeight = 18,
					imageCoords = {0.05, 0.95, 0.05, 0.95},
					width = "full",
					order = 0
				},
				sep = {
					type = "description",
					name = " ",
					width = "full",
					order = 1
				},
				ccannounce = {
					type = "toggle",
					name = format(L["Announce %s"], self.moduleName),
					order = 10,
					width = "double"
				},
				ccignoremaintanks = {
					type = "toggle",
					name = L["Ignore Main Tanks"],
					order = 20,
					width = "double"
				}
			}
		}
	end
end)