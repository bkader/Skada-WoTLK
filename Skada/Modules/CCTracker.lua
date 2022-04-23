local Skada = Skada

local pairs, ipairs, tostring, format = pairs, ipairs, tostring, string.format
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
	[5116] = true, -- Concussive Shot
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
	[55492] = true, -- Froststorm Breath (Chimaera)
	[26090] = 0x08, -- Pummel (Gorilla)
	[53575] = 0x01, -- Tendon Rip (Hyena)
	[53589] = 0x20, -- Nether Shock (Nether Ray)
	[53562] = 0x01, -- Ravage (Ravager)
	[1513] = 0x08, -- Scare Beast
	[64803] = 0x01, -- Entrapment
	-- Mage
	[61305] = true, -- Polymorph Cat
	[61721] = true, -- Polymorph Rabbit
	[61780] = true, -- Polymorph Turkey
	[31661] = 0x04, -- Dragon's Breath
	[44572] = 0x10, -- Deep Freeze
	[122] = 0x10, -- Frost Nova (rank 1)
	[865] = 0x10, -- Frost Nova (rank 2)
	[6131] = 0x10, -- Frost Nova (rank 3)
	[10230] = 0x10, -- Frost Nova (rank 4)
	[27088] = 0x10, -- Frost Nova (rank 5)
	[42917] = 0x10, -- Frost Nova (rank 6)
	[33395] = 0x10, -- Freeze (Frost Water Elemental)
	[55021] = true, -- Silenced - Improved Counterspell
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
	[28730] = true, -- Arcane Torrent (Bloodelf)
	[47779] = true, -- Arcane Torrent (Bloodelf)
	[50613] = true, -- Arcane Torrent (Bloodelf)
	-- Engineering
	[67890] = 0x04 -- Cobalt Frag Bomb
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

			Skada:DispatchSets(log_ccdone, true, data)
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's control spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's control spells"], win.actorname or L.Unknown)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.ccdone or 0

		if total > 0 and player.ccdonespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.ccdonespells) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)
				d.spellschool = GetSpellSchool(spellid)

				d.value = spell.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's control targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's control targets"], win.actorname or L.Unknown)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.ccdone or 0
		local targets = (total > 0) and player:GetCCDoneTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["CC Done"], L[win.class]) or L["CC Done"]

		local total = set.ccdone or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.ccdone or 0) > 0 then
					nr = nr + 1
					local d = win:nr(nr)

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

					if win.metadata and d.value > win.metadata.maxvalue then
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
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod, targetmod},
			columns = {Count = true, Percent = false, sPercent = false},
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
		[16869] = 0x10, -- Maleki the Pallid/Ossirian the Unscarred: Ice Tomb (Stratholme/??)
		[29670] = 0x10, -- Frostwarden Sorceress: Ice Tomb (Karazhan) / Skeletal Usher: Ice Tomb (Karazhan)
		[69065] = 0x01, -- Bone Spike: Impale (Icecrown Citadel: Lord Marrowgar)
		[70157] = 0x10, -- Sindragosa: Ice Tomb (Icecrown Citadel)
		[70447] = 64, -- Green Ooze: Volatile Ooze Adhesive (Icecrown Citadel: Professor Putricide)
		[71289] = 0x20, -- Lady Deathwhisper: Dominate Mind (Icecrown Citadel)
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

			Skada:DispatchSets(log_cctaken, true, data)
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's control spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's control spells"], win.actorname or L.Unknown)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.cctaken or 0

		if total > 0 and player.cctakenspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.cctakenspells) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)
				d.spellschool = GetSpellSchool(spellid) or RaidCCSpells[spellid]

				d.value = spell.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function sourcemod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's control sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = format(L["%s's control sources"], win.actorname or L.Unknown)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.cctaken or 0
		local sources = (total > 0) and player:GetCCTakenSources()

		if sources then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for sourcename, source in pairs(sources) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = source.id or sourcename
				d.label = sourcename
				d.class = source.class
				d.role = source.role
				d.spec = source.spec

				d.value = source.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["CC Taken"], L[win.class]) or L["CC Taken"]

		local total = set.cctaken or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.cctaken or 0) > 0 then
					nr = nr + 1
					local d = win:nr(nr)

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

					if win.metadata and d.value > win.metadata.maxvalue then
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
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod, sourcemod},
			columns = {Count = true, Percent = false, sPercent = false},
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

	local UnitName, UnitInRaid, IsInRaid = UnitName, UnitInRaid, Skada.IsInRaid
	local GetPartyAssignment, UnitIterator = GetPartyAssignment, Skada.UnitIterator

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

		Skada:DispatchSets(log_ccbreak, true, data)

		-- Optional announce
		srcName = srcName_modified or srcName
		if Skada.db.profile.modules.ccannounce and IsInRaid() and UnitInRaid(srcName) then
			if Skada.instanceType == "pvp" then return end

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
			if extraspellid or extraspellname then
				Skada:SendChat(format(L["%s on %s removed by %s's %s"], spellname, dstName, srcName, GetSpellLink(extraspellid or extraspellname)), "RAID", "preset", true)
			else
				Skada:SendChat(format(L["%s on %s removed by %s"], spellname, dstName, srcName), "RAID", "preset", true)
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's control spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's control spells"], win.actorname or L.Unknown)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.ccbreak or 0

		if total > 0 and player.ccbreakspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.ccbreakspells) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)
				d.spellschool = GetSpellSchool(spellid)

				d.value = spell.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's control targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's control targets"], win.actorname or L.Unknown)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.ccbreak or 0
		local targets = (total > 0) and player:GetCCBreakTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["CC Breaks"], L[win.class]) or L["CC Breaks"]

		local total = set.ccbreak or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.ccbreak or 0) > 0 then
					nr = nr + 1
					local d = win:nr(nr)

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

					if win.metadata and d.value > win.metadata.maxvalue then
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
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod, targetmod},
			columns = {Count = true, Percent = false, sPercent = false},
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