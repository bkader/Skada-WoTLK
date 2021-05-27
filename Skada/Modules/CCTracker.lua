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

local _pairs, _select, _format = pairs, select, string.format
local _GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local _GetSpellLink = Skada.GetSpellLink or GetSpellLink
local _UnitClass = Skada.UnitClass

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
	local playerspellmod = playermod:NewModule(L["CC Done spell targets"])
	local targetmod = mod:NewModule(L["CC Done targets"])
	local targetpellmod = targetmod:NewModule(L["CC Done target spells"])

	local function log_ccdone(set, cc)
		local player = Skada:get_player(set, cc.playerid, cc.playername, cc.playerflags)
		if player then
			-- increment the count.
			player.ccdone = player.ccdone or {}
			player.ccdone.count = (player.ccdone.count or 0) + 1
			set.ccdone = (set.ccdone or 0) + 1

			-- record the spell and its targets.
			local spell = player.ccdone.spells and player.ccdone.spells[cc.spellid]
			if not spell then
				player.ccdone.spells = player.ccdone.spells or {}
				spell = {count = 1}
				player.ccdone.spells[cc.spellid] = spell
			else
				spell.count = spell.count + 1
			end

			-- record target
			if cc.dstName then
				spell.targets = spell.targets or {}
				if not spell.targets[cc.dstName] then
					spell.targets[cc.dstName] = {id = cc.dstGUID, flags = cc.dstFlags, count = 1}
				else
					spell.targets[cc.dstName].count = spell.targets[cc.dstName].count + 1
				end

				player.ccdone.targets = player.ccdone.targets or {}
				if not player.ccdone.targets[cc.dstName] then
					player.ccdone.targets[cc.dstName] = {id = cc.dstGUID, flags = cc.dstFlags, count = 1, spells = {[cc.spellid] = 1}}
				else
					player.ccdone.targets[cc.dstName].count = player.ccdone.targets[cc.dstName].count + 1
					player.ccdone.targets[cc.dstName].spells[cc.spellid] = (player.ccdone.targets[cc.dstName].spells[cc.spellid] or 0) + 1
				end
			end
		end
	end

	local data = {}

	local function SpellAuraApplied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...

		if CCSpells[spellid] or ExtraCCSpells[spellid] then
			data.playerid = srcGUID
			data.playername = srcName
			data.playerflags = srcFlags

			data.dstGUID = dstGUID
			data.dstName = dstName
			data.dstFlags = dstFlags

			data.spellid = spellid

			log_ccdone(Skada.current, data)
			log_ccdone(Skada.total, data)
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's CC Done spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Done spells"], player.name)
			local total = player.ccdone and player.ccdone.count or 0

			if total > 0 and player.ccdone.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.ccdone.spells) do
					local spellname, _, spellicon = _GetSpellInfo(spellid)

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label = spellname
					d.icon = spellicon
					d.spellschool = GetSpellSchool(spellid)

					d.value = spell.count
					d.valuetext = Skada:FormatValueText(
						spell.count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * spell.count / total),
						mod.metadata.columns.Percent
					)

					if spell.count > maxvalue then
						maxvalue = spell.count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function playerspellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = _format(L["%s's CC Done <%s> targets"], win.playername or UNKNOWN, label)
	end

	function playerspellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Done <%s> targets"], player.name, win.spellname or UNKNOWN)
			local total = player.ccdone and player.ccdone.count or 0

			if total > 0 and player.ccdone.spells and player.ccdone.spells[win.spellid] then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.ccdone.spells[win.spellid].targets or {}) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = _select(2, _UnitClass(d.id, target.flags, set))

					d.value = target.count
					d.valuetext = Skada:FormatValueText(
						target.count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * target.count / total),
						mod.metadata.columns.Percent
					)

					if target.count > maxvalue then
						maxvalue = target.count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's CC Done targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Done targets"], player.name)
			local total = player.ccdone and player.ccdone.count or 0

			if total > 0 and player.ccdone.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.ccdone.targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec =_select(2, _UnitClass(d.id, target.flags, set))

					d.value = target.count
					d.valuetext = Skada:FormatValueText(
						target.count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * target.count / total),
						mod.metadata.columns.Percent
					)

					if target.count > maxvalue then
						maxvalue = target.count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetpellmod:Enter(win, id, label)
		win.targetname = label
		win.title = _format(L["%s's CC Done <%s> spells"], win.playername or UNKNOWN, label)
	end

	function targetpellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Done <%s> spells"], player.name, win.targetname or UNKNOWN)
			local total = player.ccdone and player.ccdone.count or 0

			if total > 0 and player.ccdone.targets and player.ccdone.targets[win.targetname] then
				local maxvalue, nr = 0, 1

				for spellid, count in _pairs(player.ccdone.targets[win.targetname].spells or {}) do
					local spellname, _, spellicon = _GetSpellInfo(spellid)
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label = spellname
					d.icon = spellicon
					d.spellschool = GetSpellSchool(spellid)

					d.value = count
					d.valuetext = Skada:FormatValueText(
						count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * count / total),
						mod.metadata.columns.Percent
					)

					if count > maxvalue then
						maxvalue = count
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

			for _, player in Skada:IteratePlayers(set) do
				if player.ccdone and (player.ccdone.count or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = player.ccdone.count
					d.valuetext = Skada:FormatValueText(
						player.ccdone.count,
						self.metadata.columns.Count,
						_format("%.1f%%", 100 * player.ccdone.count / total),
						self.metadata.columns.Percent
					)

					if player.ccdone.count > maxvalue then
						maxvalue = player.ccdone.count
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		playermod.metadata = {click1 = playerspellmod}
		targetmod.metadata = {click1 = targetpellmod}
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = targetmod,
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
		return set.ccdone or 0
	end
end)

-- ======== --
-- CC Taken --
-- ======== --
Skada:AddLoadableModule("CC Taken", function(Skada, L)
	if Skada:IsDisabled("CC Taken") then return end

	local mod = Skada:NewModule(L["CC Taken"])
	local playermod = mod:NewModule(L["CC Taken spells"])
	local playerspellmod = playermod:NewModule(L["CC Taken spell sources"])
	local sourcemod = mod:NewModule(L["CC Taken sources"])
	local sourcespellmod = sourcemod:NewModule(L["CC Taken source spells"])

	local function log_cctaken(set, cc)
		local player = Skada:get_player(set, cc.playerid, cc.playername, cc.playerflags)
		if player then
			-- increment the count.
			player.cctaken = player.cctaken or {}
			player.cctaken.count = (player.cctaken.count or 0) + 1
			set.cctaken = (set.cctaken or 0) + 1

			-- record the spell and its sources.
			local spell = player.cctaken.spells and player.cctaken.spells[cc.spellid]
			if not spell then
				player.cctaken.spells = player.cctaken.spells or {}
				spell = {count = 1}
				player.cctaken.spells[cc.spellid] = spell
			else
				spell.count = spell.count + 1
			end

			-- record target
			if cc.dstName then
				spell.sources = spell.sources or {}
				if not spell.sources[cc.dstName] then
					spell.sources[cc.dstName] = {id = cc.dstGUID, flags = cc.dstFlags, count = 1}
				else
					spell.sources[cc.dstName].count = spell.sources[cc.dstName].count + 1
				end

				player.cctaken.sources = player.cctaken.sources or {}
				if not player.cctaken.sources[cc.dstName] then
					player.cctaken.sources[cc.dstName] = {id = cc.dstGUID, flags = cc.dstFlags, count = 1, spells = {[cc.spellid] = 1}}
				else
					player.cctaken.sources[cc.dstName].count = player.cctaken.sources[cc.dstName].count + 1
					player.cctaken.sources[cc.dstName].spells[cc.spellid] = (player.cctaken.sources[cc.dstName].spells[cc.spellid] or 0) + 1
				end
			end
		end
	end

	local data = {}

	local function SpellAuraApplied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...

		if CCSpells[spellid] or ExtraCCSpells[spellid] then
			data.srcGUID = srcGUID
			data.srcName = srcName
			data.srcFlags = srcFlags

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
		win.title = _format(L["%s's CC Taken spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Taken spells"], player.name)
			local total = player.cctaken and player.cctaken.count or 0

			if total > 0 and player.cctaken.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.cctaken.spells) do
					local spellname, _, spellicon = _GetSpellInfo(spellid)
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label = spellname
					d.icon = spellicon
					d.spellschool = GetSpellSchool(spellid)

					d.value = spell.count
					d.valuetext = Skada:FormatValueText(
						spell.count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * spell.count / total),
						mod.metadata.columns.Percent
					)

					if spell.count > maxvalue then
						maxvalue = spell.count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function playerspellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = _format(L["%s's CC Taken <%s> sources"], win.playername or UNKNOWN, label)
	end

	function playerspellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Taken <%s> sources"], player.name, win.spellname or UNKNOWN)
			local total = player.cctaken and player.cctaken.count or 0

			if total > 0 and player.cctaken.spells and player.cctaken.spells[win.spellid] then
				local maxvalue, nr = 0, 1

				for sourcename, source in _pairs(player.cctaken.spells[win.spellid].sources or {}) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = source.id or sourcename
					d.label = sourcename
					d.class, d.role, d.spec = _select(2, _UnitClass(d.id, source.flags, set))

					d.value = source.count
					d.valuetext = Skada:FormatValueText(
						source.count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * source.count / total),
						mod.metadata.columns.Percent
					)

					if source.count > maxvalue then
						maxvalue = source.count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function sourcemod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's CC Taken sources"], label)
	end

	function sourcemod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Taken sources"], player.name)
			local total = player.cctaken and player.cctaken.count or 0

			if total > 0 and player.cctaken.sources then
				local maxvalue, nr = 0, 1

				for sourcename, source in _pairs(player.cctaken.sources) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = source.id or sourcename
					d.label = sourcename
					d.class, d.role, d.spec = _select(2, _UnitClass(d.id, source.flags, set))

					d.value = source.count
					d.valuetext = Skada:FormatValueText(
						source.count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * source.count / total),
						mod.metadata.columns.Percent
					)

					if source.count > maxvalue then
						maxvalue = source.count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function sourcespellmod:Enter(win, id, label)
		win.targetname = label
		win.title = _format(L["%s's CC Taken <%s> sources"], win.playername or UNKNOWN, label)
	end

	function sourcespellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Taken <%s> sources"], player.name, win.targetname or UNKNOWN)
			local total = player.cctaken and player.cctaken.count or 0

			if total > 0 and player.cctaken.sources and player.cctaken.sources[win.targetname] then
				local maxvalue, nr = 0, 1

				for spellid, count in _pairs(player.cctaken.sources[win.targetname].spells or {}) do
					local spellname, _, spellicon = _GetSpellInfo(spellid)
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label = spellname
					d.icon = spellicon
					d.spellschool = GetSpellSchool(spellid)

					d.value = count
					d.valuetext = Skada:FormatValueText(
						count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * count / total),
						mod.metadata.columns.Percent
					)

					if count > maxvalue then
						maxvalue = count
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

			for _, player in Skada:IteratePlayers(set) do
				if player.cctaken and (player.cctaken.count or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = player.cctaken.count
					d.valuetext = Skada:FormatValueText(
						player.cctaken.count,
						self.metadata.columns.Count,
						_format("%.1f%%", 100 * player.cctaken.count / total),
						self.metadata.columns.Percent
					)

					if player.cctaken.count > maxvalue then
						maxvalue = player.cctaken.count
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		playermod.metadata = {click1 = playerspellmod}
		sourcemod.metadata = {click1 = sourcespellmod}
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = sourcemod,
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
		return set.cctaken or 0
	end
end)

-- =========== --
-- CC Breakers --
-- =========== --
Skada:AddLoadableModule("CC Breakers", function(Skada, L)
	if Skada:IsDisabled("CC Breakers") then return end

	local mod = Skada:NewModule(L["CC Breakers"])
	local playermod = mod:NewModule(L["CC Break spells"])
	local playerspellmod = playermod:NewModule(L["CC Break spell targets"])
	local targetmod = mod:NewModule(L["CC Break targets"])
	local targetspellmod = targetmod:NewModule(L["CC Break target spells"])

	local _tostring = tostring
	local _UnitExists, _GetUnitName = UnitExists, GetUnitName
	local _GetNumRaidMembers, _GetPartyAssignment = GetNumRaidMembers, GetPartyAssignment
	local _IsInInstance, _UnitInRaid = IsInInstance, UnitInRaid
	local _SendChatMessage = SendChatMessage

	local function log_ccbreak(set, data)
		local player = Skada:get_player(set, data.playerid, data.playername)
		if player then
			-- increment the count.
			player.ccbreaks = player.ccbreaks or {}
			player.ccbreaks.count = (player.ccbreaks.count or 0) + 1
			set.ccbreaks = (set.ccbreaks or 0) + 1

			-- record the spell and its targets.
			local spell = player.ccbreaks.spells and player.ccbreaks.spells[cc.spellid]
			if not spell then
				player.ccbreaks.spells = player.ccbreaks.spells or {}
				spell = {count = 1}
				player.ccbreaks.spells[cc.spellid] = spell
			else
				spell.count = spell.count + 1
			end

			-- record target
			if cc.dstName then
				spell.targets = spell.targets or {}
				if not spell.targets[cc.dstName] then
					spell.targets[cc.dstName] = {id = cc.dstGUID, flags = cc.dstFlags, count = 1}
				else
					spell.targets[cc.dstName].count = spell.targets[cc.dstName].count + 1
				end

				player.ccbreaks.targets = player.ccbreaks.targets or {}
				if not player.ccbreaks.targets[cc.dstName] then
					player.ccbreaks.targets[cc.dstName] = {id = cc.dstGUID, flags = cc.dstFlags, count = 1, spells = {[cc.spellid] = 1}}
				else
					player.ccbreaks.targets[cc.dstName].count = player.ccbreaks.targets[cc.dstName].count + 1
					player.ccbreaks.targets[cc.dstName].spells[cc.spellid] = (player.ccbreaks.targets[cc.dstName].spells[cc.spellid] or 0) + 1
				end
			end
		end
	end

	local data = {}

	local function SpellAuraBroken(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, _, extraspellid, extraspellname, _, auratype = ...
		if not CCSpells[spellid] then return end

		local petid = srcGUID
		local petname = srcName

		local srcGUID_modified, srcName_modified = Skada:FixMyPets(srcGUID, srcName)

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
		if Skada.db.profile.modules.ccannounce and IsInRaid() and _UnitInRaid(srcName) then
			local instanceType = _select(2, _IsInInstance())
			if instanceType == "pvp" then
				return
			end
			-- Ignore main tanks and main assist?
			if Skada.db.profile.modules.ccignoremaintanks then
				-- Loop through our raid and return if src is a main tank.
				for i = 1, _GetNumRaidMembers() do
					local unit = "raid" .. _tostring(i)
					if _UnitExists(unit) and _GetUnitName(unit) == srcName then
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
				_SendChatMessage(_format(L["%s on %s removed by %s's %s"], spellname, dstName, srcName, _GetSpellLink(extraspellid)), "RAID")
			else
				_SendChatMessage(_format(L["%s on %s removed by %s"], spellname, dstName, srcName), "RAID")
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's CC Break spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Break spells"], player.name)
			local total = player.ccbreaks and player.ccbreaks.count or 0

			if total > 0 and player.ccbreaks.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.ccbreaks.spells) do
					local spellname, _, spellicon = _GetSpellInfo(spellid)
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellname
					d.spellid = spell.id
					d.label = spellname
					d.icon = spellicon
					d.spellschool = GetSpellSchool(spellid)

					d.value = spell.count
					d.valuetext = Skada:FormatValueText(
						spell.count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * spell.count / total),
						mod.metadata.columns.Percent
					)

					if spell.count > maxvalue then
						maxvalue = spell.count
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function playerspellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = _format(L["%s's CC Break <%s> targets"], win.playername or UNKNOWN, label)
	end

	function playerspellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Break <%s> targets"], player.name, win.spellname or UNKNOWN)
			local total = player.ccbreaks and player.ccbreaks.count or 0

			if total > 0 and player.ccbreaks.spells and player.ccbreaks.spells[win.spellid] then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.ccbreaks.spells[win.spellid].target or {}) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = _select(2, _UnitClass(d.id, target.flags, set))

					d.value = target.count
					d.valuetext = Skada:FormatValueText(
						target.count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * target.count / total),
						mod.metadata.columns.Percent
					)

					if target.count > maxvalue then
						maxvalue = target.count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's CC Break targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Break targets"], player.name)
			local total = player.ccbreaks and player.ccbreaks.count or 0

			if total > 0 and player.ccbreaks.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.ccbreaks.targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = _select(2, _UnitClass(d.id, target.flags, set))

					d.value = target.count
					d.valuetext = Skada:FormatValueText(
						target.count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * target.count / total),
						mod.metadata.columns.Percent
					)

					if target.count > maxvalue then
						maxvalue = target.count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetspellmod:Enter(win, id, label)
		win.targetname = label
		win.title = _format(L["%s's CC Break <%s> spells"], win.playername or UNKNOWN, label)
	end

	function targetspellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's CC Break <%s> spells"], player.name, win.targetname or UNKNOWN)
			local total = player.ccbreaks and player.ccbreaks.count or 0

			if total > 0 and player.ccbreaks.targets and player.ccbreaks.targets[win.targetname] then
				local maxvalue, nr = 0, 1

				for spellid, count in _pairs(player.ccbreaks.targets[win.targetname].spells or {}) do
					local spellname, _, spellicon = _GetSpellInfo(spellid)
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label = spellname
					d.icon = spellicon
					d.spellschool = GetSpellSchool(spellid)

					d.value = count
					d.valuetext = Skada:FormatValueText(
						count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * count / total),
						mod.metadata.columns.Percent
					)

					if count > maxvalue then
						maxvalue = count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["CC Breakers"]
		local total = set.ccbreaks or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.ccbreaks and (player.ccbreaks.count or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = player.ccbreaks.count
					d.valuetext = Skada:FormatValueText(
						player.ccbreaks.count,
						self.metadata.columns.Count,
						_format("%.1f%%", 100 * player.ccbreaks.count / total),
						self.metadata.columns.Percent
					)

					if player.ccbreaks.count > maxvalue then
						maxvalue = player.ccbreaks.count
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		playermod.metadata = {click1 = playerspellmod}
		targetmod.metadata = {click1 = targetspellmod}
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click2 = targetmod,
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
		if (set.ccbreaks or 0) > 0 then
			tooltip:AddDoubleLine(L["CC Breaks"], set.ccbreaks, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return set.ccbreaks or 0
	end

	local opts = {
		type = "group",
		name = L["CC Breakers"],
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

	function mod:OnInitialize()
		Skada.options.args.modules.args.ccoptions = opts
	end
end)