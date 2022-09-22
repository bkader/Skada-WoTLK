local _, Skada = ...
local private = Skada.private

local pairs, format, pformat = pairs, string.format, Skada.pformat
local GetSpellLink = private.spell_link or GetSpellLink
local new, clear = Skada.newTable, Skada.clearTable
local cc_table = {} -- holds stuff from cleu

local CCSpells = {
	[118] = 0x40, -- Polymorph (rank 1)
	[12824] = 0x40, -- Polymorph (rank 2)
	[12825] = 0x40, -- Polymorph (rank 3)
	[12826] = 0x40, -- Polymorph (rank 4)
	[28272] = 0x40, -- Polymorph (rank 1:pig)
	[28271] = 0x40, -- Polymorph (rank 1:turtle)
	[3355] = 0x10, -- Freezing Trap Effect (rank 1)
	[14308] = 0x10, -- Freezing Trap Effect (rank 2)
	[14309] = 0x10, -- Freezing Trap Effect (rank 3)
	[6770] = 0x01, -- Sap (rank 1)
	[2070] = 0x01, -- Sap (rank 2)
	[11297] = 0x01, -- Sap (rank 3)
	[6358] = 0x20, -- Seduction (succubus)
	[60210] = 0x10, -- Freezing Arrow (rank 1)
	[45524] = 0x10, -- Chains of Ice
	[33786] = 0x08, -- Cyclone
	[53308] = 0x08, -- Entangling Roots
	[2637] = 0x08, -- Hibernate (rank 1)
	[18657] = 0x08, -- Hibernate (rank 2)
	[18658] = 0x08, -- Hibernate (rank 3)
	[20066] = 0x02, -- Repentance
	[9484] = 0x02, -- Shackle Undead (rank 1)
	[9485] = 0x02, -- Shackle Undead (rank 2)
	[10955] = 0x02, -- Shackle Undead (rank 3)
	[51722] = 0x01, -- Dismantle
	[710] = 0x20, -- Banish (Rank 1)
	[18647] = 0x20, -- Banish (Rank 2)
	[12809] = 0x01, -- Concussion Blow
	[676] = 0x01 -- Disarm
}

-- extended CC list for only CC Done and CC Taken modules
local ExtraCCSpells = {
	-- Death Knight
	[47476] = 0x20, -- Strangulate
	[49203] = 0x10, -- Hungering Cold
	[47481] = 0x01, -- Gnaw
	[49560] = 0x01, -- Death Grip
	-- Druid
	[339] = 0x08, -- Entangling Roots (rank 1)
	[1062] = 0x08, -- Entangling Roots (rank 2)
	[5195] = 0x08, -- Entangling Roots (rank 3)
	[5196] = 0x08, -- Entangling Roots (rank 4)
	[9852] = 0x08, -- Entangling Roots (rank 5)
	[9853] = 0x08, -- Entangling Roots (rank 6)
	[26989] = 0x08, -- Entangling Roots (rank 7)
	[19975] = 0x08, -- Entangling Roots (Nature's Grasp rank 1)
	[19974] = 0x08, -- Entangling Roots (Nature's Grasp rank 2)
	[19973] = 0x08, -- Entangling Roots (Nature's Grasp rank 3)
	[19972] = 0x08, -- Entangling Roots (Nature's Grasp rank 4)
	[19971] = 0x08, -- Entangling Roots (Nature's Grasp rank 5)
	[19970] = 0x08, -- Entangling Roots (Nature's Grasp rank 6)
	[27010] = 0x08, -- Entangling Roots (Nature's Grasp rank 7)
	[53313] = 0x08, -- Entangling Roots (Nature's Grasp)
	[66070] = 0x08, -- Entangling Roots (Force of Nature)
	[8983] = 0x01, -- Bash
	[16979] = 0x01, -- Feral Charge - Bear
	[45334] = 0x01, -- Feral Charge Effect
	[22570] = 0x01, -- Maim (rank 1)
	[49802] = 0x01, -- Maim (rank 2)
	[49803] = 0x01, -- Pounce
	-- Hunter
	[5116] = 0x01, -- Concussive Shot
	[19503] = 0x01, -- Scatter Shot
	[19386] = 0x08, -- Wyvern Sting (rank 1)
	[24132] = 0x08, -- Wyvern Sting (rank 2)
	[24133] = 0x08, -- Wyvern Sting (rank 3)
	[27068] = 0x08, -- Wyvern Sting (rank 4)
	[49011] = 0x08, -- Wyvern Sting (rank 5)
	[49012] = 0x08, -- Wyvern Sting (rank 6)
	[53548] = 0x01, -- Pin (Crab)
	[4167] = 0x01, -- Web (Spider)
	[55509] = 0x08, -- Venom Web Spray (Silithid)
	[24394] = 0x01, -- Intimidation
	[19577] = 0x08, -- Intimidation (stun)
	[53568] = 0x08, -- Sonic Blast (Bat)
	[53543] = 0x01, -- Snatch (Bird of Prey)
	[50541] = 0x01, -- Clench (Scorpid)
	[55492] = 0x10, -- Froststorm Breath (Chimaera)
	[26090] = 0x08, -- Pummel (Gorilla)
	[53575] = 0x01, -- Tendon Rip (Hyena)
	[53589] = 0x20, -- Nether Shock (Nether Ray)
	[53562] = 0x01, -- Ravage (Ravager)
	[1513] = 0x08, -- Scare Beast
	[64803] = 0x01, -- Entrapment
	-- Mage
	[61305] = 0x40, -- Polymorph Cat
	[61721] = 0x40, -- Polymorph Rabbit
	[61780] = 0x40, -- Polymorph Turkey
	[31661] = 0x04, -- Dragon's Breath
	[44572] = 0x10, -- Deep Freeze
	[122] = 0x10, -- Frost Nova (rank 1)
	[865] = 0x10, -- Frost Nova (rank 2)
	[6131] = 0x10, -- Frost Nova (rank 3)
	[10230] = 0x10, -- Frost Nova (rank 4)
	[27088] = 0x10, -- Frost Nova (rank 5)
	[42917] = 0x10, -- Frost Nova (rank 6)
	[33395] = 0x10, -- Freeze (Frost Water Elemental)
	[55021] = 0x40, -- Silenced - Improved Counterspell
	-- Paladin
	[853] = 0x02, -- Hammer of Justice (rank 1)
	[5588] = 0x02, -- Hammer of Justice (rank 2)
	[5589] = 0x02, -- Hammer of Justice (rank 3)
	[10308] = 0x02, -- Hammer of Justice (rank 4)
	[10326] = 0x02, -- Turn Evil
	[2812] = 0x02, -- Holy Wrath (rank 1)
	[10318] = 0x02, -- Holy Wrath (rank 2)
	[27319] = 0x02, -- Holy Wrath (rank 3)
	[48816] = 0x02, -- Holy Wrath (rank 4)
	[48817] = 0x02, -- Holy Wrath (rank 5)
	[31935] = 0x02, -- Avengers Shield
	-- Priest
	[8122] = 0x20, -- Psychic Scream (rank 1)
	[8124] = 0x20, -- Psychic Scream (rank 2)
	[10888] = 0x20, -- Psychic Scream (rank 3)
	[10890] = 0x20, -- Psychic Scream (rank 4)
	[605] = 0x20, -- Dominate Mind (Mind Control)
	[15487] = 0x20, -- Silence
	[64044] = 0x20, -- Psychic Horror
	-- Rogue
	[51724] = 0x01, -- Sap
	[408] = 0x01, -- Kidney Shot (rank 1)
	[8643] = 0x01, -- Kidney Shot (rank 2)
	[2094] = 0x01, -- Blind
	[1833] = 0x01, -- Cheap Shot
	[1776] = 0x01, -- Gouge
	[1330] = 0x01, -- Garrote - Silence
	-- Shaman
	[51514] = 0x08, -- Hex
	[8056] = 0x10, -- Frost Shock (rank 1)
	[8058] = 0x10, -- Frost Shock (rank 2)
	[10472] = 0x10, -- Frost Shock (rank 3)
	[10473] = 0x10, -- Frost Shock (rank 4)
	[25464] = 0x10, -- Frost Shock (rank 5)
	[49235] = 0x10, -- Frost Shock (rank 6)
	[49236] = 0x10, -- Frost Shock (rank 7)
	[64695] = 0x08, -- Earthgrab (Earthbind Totem with Storm, Earth and Fire talent)
	[3600] = 0x08, -- Earthbind (Earthbind Totem)
	[39796] = 0x01, -- Stoneclaw Stun (Stoneclaw Totem)
	[8034] = 0x10, -- Frostbrand Weapon (rank 1)
	[8037] = 0x10, -- Frostbrand Weapon (rank 2)
	[10458] = 0x10, -- Frostbrand Weapon (rank 3)
	[16352] = 0x10, -- Frostbrand Weapon (rank 4)
	[16353] = 0x10, -- Frostbrand Weapon (rank 5)
	[25501] = 0x10, -- Frostbrand Weapon (rank 6)
	[58797] = 0x10, -- Frostbrand Weapon (rank 7)
	[58798] = 0x10, -- Frostbrand Weapon (rank 8)
	[58799] = 0x10, -- Frostbrand Weapon (rank 9)
	-- Warlock
	[6215] = 0x20, -- Fear
	[5484] = 0x20, -- Howl of Terror
	[30283] = 0x20, -- Shadowfury
	[22703] = 0x04, -- Infernal Awakening
	[6789] = 0x20, -- Death Coil (rank 1)
	[17925] = 0x20, -- Death Coil (rank 2)
	[17926] = 0x20, -- Death Coil (rank 3)
	[27223] = 0x20, -- Death Coil (rank 4)
	[47859] = 0x20, -- Death Coil (rank 5)
	[47860] = 0x20, -- Death Coil (rank 6)
	[24259] = 0x20, -- Spell Lock
	-- Warrior
	[5246] = 0x01, -- Initmidating Shout
	[46968] = 0x01, -- Shockwave
	[6552] = 0x01, -- Pummel
	[58357] = 0x01, -- Heroic Throw silence
	[7922] = 0x01, -- Charge
	[47995] = 0x01, -- Intercept (Stun)--needs review
	[12323] = 0x01, -- Piercing Howl
	-- Racials
	[20549] = 0x01, -- War Stomp (Tauren)
	[28730] = 0x40, -- Arcane Torrent (Bloodelf)
	[47779] = 0x40, -- Arcane Torrent (Bloodelf)
	[50613] = 0x40, -- Arcane Torrent (Bloodelf)
	-- Engineering
	[67890] = 0x04 -- Cobalt Frag Bomb
}

local function get_spell_school(spellid)
	if CCSpells[spellid] and CCSpells[spellid] ~= true then
		return CCSpells[spellid]
	end
	if ExtraCCSpells[spellid] and ExtraCCSpells[spellid] ~= true then
		return ExtraCCSpells[spellid]
	end
end

local function format_valuetext(d, columns, total, metadata, subview)
	d.valuetext = Skada:FormatValueCols(
		columns.Count and d.value,
		columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
	)

	if metadata and d.value > metadata.maxvalue then
		metadata.maxvalue = d.value
	end
end

-- ======= --
-- CC Done --
-- ======= --
Skada:RegisterModule("CC Done", function(L, P, _, C)
	local mod = Skada:NewModule("CC Done")
	local playermod = mod:NewModule("Crowd Control Spells")
	local targetmod = mod:NewModule("Crowd Control Targets")
	local sourcemod = playermod:NewModule("Crowd Control Sources")
	local get_cc_done_sources = nil
	local get_cc_done_targets = nil
	local mod_cols = nil

	local function log_ccdone(set)
		local player = Skada:GetPlayer(set, cc_table.srcGUID, cc_table.srcName, cc_table.srcFlags)
		if not player then return end

		-- increment the count.
		player.ccdone = (player.ccdone or 0) + 1
		set.ccdone = (set.ccdone or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- record the spell.
		local spell = player.ccdonespells and player.ccdonespells[cc_table.spellid]
		if not spell then
			player.ccdonespells = player.ccdonespells or {}
			player.ccdonespells[cc_table.spellid] = {count = 0}
			spell = player.ccdonespells[cc_table.spellid]
		end
		spell.count = spell.count + 1

		-- record the target.
		if cc_table.dstName then
			spell.targets = spell.targets or {}
			spell.targets[cc_table.dstName] = (spell.targets[cc_table.dstName] or 0) + 1
		end
	end

	local function aura_applied(_, _, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid)
		if CCSpells[spellid] or ExtraCCSpells[spellid] then
			cc_table.srcGUID, cc_table.srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)
			cc_table.srcFlags = srcFlags

			cc_table.dstGUID = dstGUID
			cc_table.dstName = dstName
			cc_table.dstFlags = dstFlags

			cc_table.spellid = spellid
			cc_table.extraspellid = nil

			Skada:DispatchSets(log_ccdone)
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = pformat(L["%s's control spells"], label)
	end

	function playermod:Update(win, set)
		win.title = pformat(L["%s's control spells"], win.actorname)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.ccdone
		local spells = (total and total > 0) and player.ccdonespells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, nil, get_spell_school(spellid))
			d.value = spell.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = pformat(L["%s's control targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's control targets"], win.actorname)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.ccdone
		local targets = (total and total > 0) and get_cc_done_targets(player)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, targetname)
			d.value = target.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function sourcemod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = pformat(L["%s's sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = pformat(L["%s's sources"], win.spellname)
		if not set or not win.spellid then return end

		local total, sources = get_cc_done_sources(set, win.spellid)

		if not sources then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for sourcename, source in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, source, true, sourcename)
			d.value = source.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["CC Done"], L[win.class]) or L["CC Done"]

		local total = set:GetTotal(win.class, nil, "ccdone")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor.ccdone and (not win.class or win.class == actor.class) then
				nr = nr + 1

				local d = win:actor(nr, actor)
				d.value = actor.ccdone
				format_valuetext(d, mod_cols, total, win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set, win)
		return set and set:GetTotal(win and win.class, nil, "ccdone") or 0
	end

	function mod:AddToTooltip(set, tooltip)
		if set.ccdone and set.ccdone > 0 then
			tooltip:AddDoubleLine(L["CC Done"], set.ccdone, 1, 1, 1)
		end
	end

	function mod:OnEnable()
		playermod.metadata = {click1 = sourcemod}
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\spell_frost_chainsofice]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		sourcemod.nototal = true
		playermod.nototal = true
		targetmod.nototal = true

		Skada:RegisterForCL(
			aura_applied,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			{src_is_interesting = true}
		)

		Skada:AddMode(self, L["Crowd Control"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	get_cc_done_sources = function(self, spellid, tbl)
		local total = 0
		if not self.ccdone or not spellid then return total end

		tbl = clear(tbl or C)

		local actors = self.players -- players
		for i = 1, #actors do
			local p = actors[i]
			if p and p.ccdonespells and p.ccdonespells[spellid] then
				tbl[p.name] = new()
				tbl[p.name].id = p.id
				tbl[p.name].class = p.class
				tbl[p.name].role = p.role
				tbl[p.name].spec = p.spec
				tbl[p.name].count = p.ccdonespells[spellid].count
				total = total + p.ccdonespells[spellid].count
			end
		end

		return total, tbl
	end

	get_cc_done_targets = function(self, tbl)
		if not self.ccdonespells then return end

		tbl = clear(tbl or C)
		for _, spell in pairs(self.ccdonespells) do
			if spell.targets then
				for name, count in pairs(spell.targets) do
					local t = tbl[name]
					if not t then
						t = new()
						t.count = count
						tbl[name] = t
					else
						t.count = t.count + count
					end
					self.super:_fill_actor_table(t, name)
				end
			end
		end
		return tbl
	end
end)

-- ======== --
-- CC Taken --
-- ======== --
Skada:RegisterModule("CC Taken", function(L, P, _, C)
	local mod = Skada:NewModule("CC Taken")
	local playermod = mod:NewModule("Crowd Control Spells")
	local sourcemod = mod:NewModule("Crowd Control Sources")
	local targetmod = playermod:NewModule("Crowd Control Targets")
	local get_cc_taken_targets = nil
	local get_cc_taken_sources = nil
	local mod_cols = nil

	local RaidCCSpells = {
		[16869] = 0x10, -- Maleki the Pallid/Ossirian the Unscarred: Ice Tomb (Stratholme/??)
		[29670] = 0x10, -- Frostwarden Sorceress: Ice Tomb (Karazhan) / Skeletal Usher: Ice Tomb (Karazhan)
		[69065] = 0x01, -- Bone Spike: Impale (Icecrown Citadel: Lord Marrowgar)
		[70157] = 0x10, -- Sindragosa: Ice Tomb (Icecrown Citadel)
		[70447] = 0x40, -- Green Ooze: Volatile Ooze Adhesive (Icecrown Citadel: Professor Putricide)
		[71289] = 0x20, -- Lady Deathwhisper: Dominate Mind (Icecrown Citadel)
		[72836] = 0x40, -- Green Ooze: Volatile Ooze Adhesive (Icecrown Citadel: Professor Putricide)
		[72837] = 0x40, -- Green Ooze: Volatile Ooze Adhesive (Icecrown Citadel: Professor Putricide)
		[72838] = 0x40 -- Green Ooze: Volatile Ooze Adhesive (Icecrown Citadel: Professor Putricide)
	}

	local function log_cctaken(set)
		local player = Skada:GetPlayer(set, cc_table.dstGUID, cc_table.dstName, cc_table.dstFlags)
		if not player then return end

		-- increment the count.
		player.cctaken = (player.cctaken or 0) + 1
		set.cctaken = (set.cctaken or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- record the spell.
		local spell = player.cctakenspells and player.cctakenspells[cc_table.spellid]
		if not spell then
			player.cctakenspells = player.cctakenspells or {}
			player.cctakenspells[cc_table.spellid] = {count = 0}
			spell = player.cctakenspells[cc_table.spellid]
		end
		spell.count = spell.count + 1

		-- record the source.
		if cc_table.srcName then
			spell.sources = spell.sources or {}
			spell.sources[cc_table.srcName] = (spell.sources[cc_table.srcName] or 0) + 1
		end
	end

	local function aura_applied(_, _, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid)
		if CCSpells[spellid] or ExtraCCSpells[spellid] or RaidCCSpells[spellid] then
			cc_table.srcGUID = srcGUID
			cc_table.srcName = srcName
			cc_table.srcFlags = srcFlags

			cc_table.dstGUID = dstGUID
			cc_table.dstName = dstName
			cc_table.dstFlags = dstFlags

			cc_table.spellid = spellid
			cc_table.extraspellid = nil

			Skada:DispatchSets(log_cctaken)
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = pformat(L["%s's control spells"], label)
	end

	function playermod:Update(win, set)
		win.title = pformat(L["%s's control spells"], win.actorname)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.cctaken
		local spells = (total and total > 0) and player.cctakenspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, nil, get_spell_school(spellid) or RaidCCSpells[spellid])
			d.value = spell.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function sourcemod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = pformat(L["%s's control sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = pformat(L["%s's control sources"], win.actorname)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.cctaken
		local sources = (total and total > 0) and get_cc_taken_sources(player)

		if not sources then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for sourcename, source in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, source, true, sourcename)
			d.value = source.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = pformat(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's targets"], win.spellname)
		if not set or not win.spellid then return end

		local total, targets = get_cc_taken_targets(set, win.spellid)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, targetname)
			d.value = target.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["CC Taken"], L[win.class]) or L["CC Taken"]

		local total = set:GetTotal(win.class, nil, "cctaken")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor.cctaken and (not win.class or win.class == actor.class) then
				nr = nr + 1

				local d = win:actor(nr, actor)
				d.value = actor.cctaken
				format_valuetext(d, mod_cols, total, win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set, win)
		return set and set:GetTotal(win and win.class, nil, "cctaken") or 0
	end

	function mod:AddToTooltip(set, tooltip)
		if set.cctaken and set.cctaken > 0 then
			tooltip:AddDoubleLine(L["CC Taken"], set.cctaken, 1, 1, 1)
		end
	end

	function mod:OnEnable()
		playermod.metadata = {click1 = targetmod}
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = sourcemod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\spell_magic_polymorphrabbit]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		playermod.nototal = true
		sourcemod.nototal = true
		targetmod.nototal = true

		Skada:RegisterForCL(
			aura_applied,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			{dst_is_interesting = true}
		)

		Skada:AddMode(self, L["Crowd Control"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	get_cc_taken_targets = function(self, spellid, tbl)
		local total = 0
		if not self.cctaken or not spellid then return total end

		tbl = clear(tbl or C)

		local actors = self.players -- players
		for i = 1, #actors do
			local p = actors[i]
			if p and p.cctakenspells and p.cctakenspells[spellid] then
				tbl[p.name] = new()
				tbl[p.name].id = p.id
				tbl[p.name].class = p.class
				tbl[p.name].role = p.role
				tbl[p.name].spec = p.spec
				tbl[p.name].count = p.cctakenspells[spellid].count
				total = total + p.cctakenspells[spellid].count
			end
		end

		return total, tbl
	end

	get_cc_taken_sources = function(self, tbl)
		if not self.cctakenspells then return end

		tbl = clear(tbl or C)
		for _, spell in pairs(self.cctakenspells) do
			if spell.sources then
				for name, count in pairs(spell.sources) do
					local t = tbl[name]
					if not t then
						t = new()
						t.count = count
						tbl[name] = t
					else
						t.count = t.count + count
					end
					self.super:_fill_actor_table(t, name)
				end
			end
		end
		return tbl
	end
end)

-- =========== --
-- CC Breakers --
-- =========== --
Skada:RegisterModule("CC Breaks", function(L, P, _, C, M)
	local mod = Skada:NewModule("CC Breaks")
	local playermod = mod:NewModule("Crowd Control Spells")
	local targetmod = mod:NewModule("Crowd Control Targets")
	local get_cc_break_targets = nil
	local mod_cols = nil

	local UnitName, UnitInRaid, IsInRaid = UnitName, UnitInRaid, Skada.IsInRaid
	local GetPartyAssignment, UnitIterator = GetPartyAssignment, Skada.UnitIterator

	local function log_ccbreak(set)
		local player = Skada:GetPlayer(set, cc_table.srcGUID, cc_table.srcName, cc_table.srcFlags)
		if not player then return end

		-- increment the count.
		player.ccbreak = (player.ccbreak or 0) + 1
		set.ccbreak = (set.ccbreak or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- record the spell.
		local spell = player.ccbreakspells and player.ccbreakspells[cc_table.spellid]
		if not spell then
			player.ccbreakspells = player.ccbreakspells or {}
			player.ccbreakspells[cc_table.spellid] = {count = 0}
			spell = player.ccbreakspells[cc_table.spellid]
		end
		spell.count = spell.count + 1

		-- record the target.
		if cc_table.dstName then
			spell.targets = spell.targets or {}
			spell.targets[cc_table.dstName] = (spell.targets[cc_table.dstName] or 0) + 1
		end
	end

	local function aura_broken(_, _, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, _, extraspellid, extraspellname = ...
		if not CCSpells[spellid] then return end

		local petid, petname = srcGUID, srcName
		local srcGUID_modified, srcName_modified = Skada:FixMyPets(srcGUID, srcName, srcFlags)

		cc_table.srcGUID = srcGUID_modified or srcGUID
		cc_table.srcName = srcName_modified or srcName
		cc_table.srcFlags = srcFlags

		cc_table.dstGUID = dstGUID
		cc_table.dstName = dstName
		cc_table.dstFlags = dstFlags

		cc_table.spellid = spellid
		cc_table.extraspellid = extraspellid

		Skada:DispatchSets(log_ccbreak)

		-- Optional announce
		srcName = srcName_modified or srcName
		if M.ccannounce and IsInRaid() and UnitInRaid(srcName) then
			if Skada.insType == "pvp" then return end

			-- Ignore main tanks and main assist?
			if M.ccignoremaintanks then
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
			if extraspellid or extraspellname then
				Skada:SendChat(format(L["%s on %s removed by %s's %s"], spellname, dstName, srcName, GetSpellLink(extraspellid or extraspellname)), "RAID", "preset")
			else
				Skada:SendChat(format(L["%s on %s removed by %s"], spellname, dstName, srcName), "RAID", "preset")
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = pformat(L["%s's control spells"], label)
	end

	function playermod:Update(win, set)
		win.title = pformat(L["%s's control spells"], win.actorname)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.ccbreak
		local spells = (total and total > 0) and player.ccbreakspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, nil, get_spell_school(spellid))
			d.value = spell.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = pformat(L["%s's control targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's control targets"], win.actorname)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.ccbreak
		local targets = (total and total > 0) and get_cc_break_targets(player)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, targetname)
			d.value = target.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["CC Breaks"], L[win.class]) or L["CC Breaks"]

		local total = set:GetTotal(win.class, nil, "ccbreak")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor.ccbreak and (not win.class or win.class == actor.class) then
				nr = nr + 1

				local d = win:actor(nr, actor)
				d.value = actor.ccbreak
				format_valuetext(d, mod_cols, total, win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set, win)
		return set and set:GetTotal(win and win.class, nil, "ccbreak") or 0
	end

	function mod:AddToTooltip(set, tooltip)
		if set.ccbreak and set.ccbreak > 0 then
			tooltip:AddDoubleLine(L["CC Breaks"], set.ccbreak, 1, 1, 1)
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\spell_holy_sealofvalor]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		Skada:RegisterForCL(
			aura_broken,
			"SPELL_AURA_BROKEN",
			"SPELL_AURA_BROKEN_SPELL",
			{src_is_interesting = true}
		)

		Skada:AddMode(self, L["Crowd Control"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:OnInitialize()
		Skada.options.args.modules.args.ccoptions = {
			type = "group",
			name = self.localeName,
			desc = format(L["Options for %s."], self.localeName),
			args = {
				header = {
					type = "description",
					name = self.localeName,
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
					name = format(L["Announce %s"], self.localeName),
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

	get_cc_break_targets = function(self, tbl)
		if not self.ccbreakspells then return end

		tbl = clear(tbl or C)
		for _, spell in pairs(self.ccbreakspells) do
			if spell.targets then
				for name, count in pairs(spell.targets) do
					local t = tbl[name]
					if not t then
						t = new()
						t.count = count
						tbl[name] = t
					else
						t.count = t.count + count
					end
					self.super:_fill_actor_table(t, name)
				end
			end
		end
		return tbl
	end
end)
