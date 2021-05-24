assert(Skada, "Skada not found!")

-- cache frequently used globals
local _pairs, _select, _format = pairs, select, string.format
local math_min, math_max = math.min, math.max
local _UnitGUID, _GetSpellInfo = UnitGUID, Skada.GetSpellInfo or GetSpellInfo

-- ============== --
-- Absorbs module --
-- ============== --

Skada:AddLoadableModule("Absorbs", function(Skada, L)
	if Skada:IsDisabled("Absorbs") then return end

	local mod = Skada:NewModule(L["Absorbs"])
	local spellmod = mod:NewModule(L["Absorb spell list"])
	local playermod = mod:NewModule(L["Absorbed player list"])

	local _GetNumRaidMembers, _GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
	local _UnitName, _UnitExists, _UnitBuff = UnitName, UnitExists, UnitBuff
	local _UnitIsDeadOrGhost, _UnitClass = UnitIsDeadOrGhost, Skada.UnitClass
	local _tostring, _GetTime, _band = tostring, GetTime, bit.band

	local absorbspells = {
		[48707] = 5, -- Anti-Magic Shell (rank 1)
		[51052] = 10, -- Anti-Magic Zone( (rank 1)
		[51271] = 20, -- Unbreakable Armor
		[62606] = 10, -- Savage Defense
		[11426] = 60, -- Ice Barrier (rank 1)
		[13031] = 60, -- Ice Barrier (rank 2)
		[13032] = 60, -- Ice Barrier (rank 3)
		[13033] = 60, -- Ice Barrier (rank 4)
		[27134] = 60, -- Ice Barrier (rank 5)
		[33405] = 60, -- Ice Barrier (rank 6)
		[43038] = 60, -- Ice Barrier (rank 7)
		[43039] = 60, -- Ice Barrier (rank 8)
		[6143] = 30, -- Frost Ward (rank 1)
		[8461] = 30, -- Frost Ward (rank 2)
		[8462] = 30, -- Frost Ward (rank 3)
		[10177] = 30, -- Frost Ward (rank 4)
		[28609] = 30, -- Frost Ward (rank 5)
		[32796] = 30, -- Frost Ward (rank 6)
		[43012] = 30, -- Frost Ward (rank 7)
		[1463] = 60, --  Mana shield (rank 1)
		[8494] = 60, --  Mana shield (rank 2)
		[8495] = 60, --  Mana shield (rank 3)
		[10191] = 60, --  Mana shield (rank 4)
		[10192] = 60, --  Mana shield (rank 5)
		[10193] = 60, --  Mana shield (rank 6)
		[27131] = 60, --  Mana shield (rank 7)
		[43019] = 60, --  Mana shield (rank 8)
		[43020] = 60, --  Mana shield (rank 9)
		[543] = 30, -- Fire Ward (rank 1)
		[8457] = 30, -- Fire Ward (rank 2)
		[8458] = 30, -- Fire Ward (rank 3)
		[10223] = 30, -- Fire Ward (rank 4)
		[10225] = 30, -- Fire Ward (rank 5)
		[27128] = 30, -- Fire Ward (rank 6)
		[43010] = 30, -- Fire Ward (rank 7)
		[58597] = 6, -- Sacred Shield
		[17] = 30, -- Power Word: Shield (rank 1)
		[592] = 30, -- Power Word: Shield (rank 2)
		[600] = 30, -- Power Word: Shield (rank 3)
		[3747] = 30, -- Power Word: Shield (rank 4)
		[6065] = 30, -- Power Word: Shield (rank 5)
		[6066] = 30, -- Power Word: Shield (rank 6)
		[10898] = 30, -- Power Word: Shield (rank 7)
		[10899] = 30, -- Power Word: Shield (rank 8)
		[10900] = 30, -- Power Word: Shield (rank 9)
		[10901] = 30, -- Power Word: Shield (rank 10)
		[25217] = 30, -- Power Word: Shield (rank 11)
		[25218] = 30, -- Power Word: Shield (rank 12)
		[48065] = 30, -- Power Word: Shield (rank 13)
		[48066] = 30, -- Power Word: Shield (rank 14)
		[47509] = 12, -- Divine Aegis (rank 1)
		[47511] = 12, -- Divine Aegis (rank 2)
		[47515] = 12, -- Divine Aegis (rank 3)
		[47753] = 12, -- Divine Aegis (rank 1)
		[54704] = 12, -- Divine Aegis (rank 1)
		[47788] = 10, -- Guardian Spirit
		[7812] = 30, -- Sacrifice (rank 1)
		[19438] = 30, -- Sacrifice (rank 2)
		[19440] = 30, -- Sacrifice (rank 3)
		[19441] = 30, -- Sacrifice (rank 4)
		[19442] = 30, -- Sacrifice (rank 5)
		[19443] = 30, -- Sacrifice (rank 6)
		[27273] = 30, -- Sacrifice (rank 7)
		[47985] = 30, -- Sacrifice (rank 8)
		[47986] = 30, -- Sacrifice (rank 9)
		[6229] = 30, -- Shadow Ward (rank 1)
		[11739] = 30, -- Shadow Ward (rank 1)
		[11740] = 30, -- Shadow Ward (rank 2)
		[28610] = 30, -- Shadow Ward (rank 3)
		[47890] = 30, -- Shadow Ward (rank 4)
		[47891] = 30, -- Shadow Ward (rank 5)
		[29674] = 86400, -- Lesser Ward of Shielding
		[29719] = 86400, -- Greater Ward of Shielding
		[29701] = 86400, -- Greater Shielding
		[28538] = 120, -- Major Holy Protection Potion
		[28537] = 120, -- Major Shadow Protection Potion
		[28536] = 120, --  Major Arcane Protection Potion
		[28513] = 120, -- Major Nature Protection Potion
		[28512] = 120, -- Major Frost Protection Potion
		[28511] = 120, -- Major Fire Protection Potion
		[7233] = 120, -- Fire Protection Potion
		[7239] = 120, -- Frost Protection Potion
		[7242] = 120, -- Shadow Protection Potion
		[7245] = 120, -- Holy Protection Potion
		[7254] = 120, -- Nature Protection Potion
		[53915] = 120, -- Mighty Shadow Protection Potion
		[53914] = 120, -- Mighty Nature Protection Potion
		[53913] = 120, -- Mighty Frost Protection Potion
		[53911] = 120, -- Mighty Fire Protection Potion
		[53910] = 120, -- Mighty Arcane Protection Potion
		[17548] = 120, --  Greater Shadow Protection Potion
		[17546] = 120, -- Greater Nature Protection Potion
		[17545] = 120, -- Greater Holy Protection Potion
		[17544] = 120, -- Greater Frost Protection Potion
		[17543] = 120, -- Greater Fire Protection Potion
		[17549] = 120, -- Greater Arcane Protection Potion
		[28527] = 15, -- Fel Blossom
		[29432] = 3600, -- Frozen Rune
		[36481] = 4, -- Arcane Barrier (TK Kael'Thas) Shield
		[57350] = 6, -- Darkmoon Card: Illusion
		[17252] = 30, -- Mark of the Dragon Lord (LBRS epic ring)
		[25750] = 15, -- Defiler's Talisman/Talisman of Arathor
		[25747] = 15, -- Defiler's Talisman/Talisman of Arathor
		[25746] = 15, -- Defiler's Talisman/Talisman of Arathor
		[23991] = 15, -- Defiler's Talisman/Talisman of Arathor
		[31000] = 300, -- Pendant of Shadow's End Usage
		[30997] = 300, -- Pendant of Frozen Flame Usage
		[31002] = 300, -- Pendant of the Null Rune
		[30999] = 300, -- Pendant of Withering
		[30994] = 300, -- Pendant of Thawing
		[31000] = 300, -- Pendant of Shadow's End
		[23506] = 20, -- Arena Grand Master
		[12561] = 60, -- Goblin Construction Helmet
		[31771] = 20, -- Runed Fungalcap
		[21956] = 10, -- Mark of Resolution
		[29506] = 20, -- The Burrower's Shell
		[4057] = 60, -- Flame Deflector
		[4077] = 60, -- Ice Deflector
		[39228] = 20, -- Argussian Compass (may not be an actual absorb)
		[27779] = 30, -- Divine Protection (Priest dungeon set 1/2)
		[11657] = 20, -- Jang'thraze (Zul Farrak)
		[10368] = 15, -- Uther's Strength
		[37515] = 15, -- Warbringer Armor Proc
		[42137] = 86400, -- Greater Rune of Warding Proc
		[26467] = 30, -- Scarab Brooch
		[26470] = 8, -- Scarab Brooch
		[27539] = 6, -- Thick Obsidian Breatplate
		[28810] = 30, -- Faith Set Proc Armor of Faith
		[54808] = 12, -- Noise Machine Sonic Shield
		[55019] = 12, -- Sonic Shield
		[64413] = 8, -- Val'anyr, Hammer of Ancient Kings Protection of Ancient Kings
		[40322] = 30, -- Teron's Vengeful Spirit Ghost - Spirit Shield
		[65874] = 15, -- Twin Val'kyr's: Shield of Darkness (175000)
		[67257] = 15, -- Twin Val'kyr's: Shield of Darkness (300000)
		[67256] = 15, -- Twin Val'kyr's: Shield of Darkness (700000)
		[67258] = 15, -- Twin Val'kyr's: Shield of Darkness (1200000)
		[65858] = 15, -- Twin Val'kyr's: Shield of Lights (175000)
		[67260] = 15, -- Twin Val'kyr's: Shield of Lights (300000)
		[67259] = 15, -- Twin Val'kyr's: Shield of Lights (700000)
		[67261] = 15, -- Twin Val'kyr's: Shield of Lights (1200000)
		[65686] = 86400, -- Twin Val'kyr: Light Essence
		[65684] = 86400 -- Twin Val'kyr: Dark Essence86400
	}

	local mage_fire_ward = { -- Fire Ward
		[543] = 30,
		[8457] = 30,
		[8458] = 30,
		[10223] = 30,
		[10225] = 30,
		[27128] = 30,
		[43010] = 30
	}

	local mage_frost_ward = { -- Frost Ward
		[6143] = 30,
		[8461] = 30,
		[8462] = 30,
		[10177] = 30,
		[28609] = 30,
		[32796] = 30,
		[43012] = 30
	}

	local mage_ice_barrier = { -- Ice Barrier
		[11426] = 60,
		[13031] = 60,
		[13032] = 60,
		[13033] = 60,
		[27134] = 60,
		[33405] = 60,
		[43038] = 60,
		[43039] = 60
	}

	local warlock_shadow_ward = { -- Shadow Ward
		[6229] = 30,
		[11739] = 30,
		[11740] = 30,
		[28610] = 30,
		[47890] = 30,
		[47891] = 30
	}

	local warlock_sacrifice = { -- Sacrifice
		[7812] = 30,
		[19438] = 30,
		[19440] = 30,
		[19441] = 30,
		[19442] = 30,
		[19443] = 30,
		[27273] = 30,
		[47985] = 30,
		[47986] = 30
	}

	local shieldschools = Skada:WeakTable()

	local function log_absorb(set, playername, dstGUID, dstName, dstFlags, spellid, amount)
		local player = Skada:get_player(set, _UnitGUID(playername), playername)
		if player then
			-- add absorbs amount
			player.absorbs = player.absorbs or {}
			player.absorbs.amount = (player.absorbs.amount or 0) + amount
			set.absorbs = (set.absorbs or 0) + amount

			-- record the target
			if dstName then
				player.absorbs.targets = player.absorbs.targets or {}
				if not player.absorbs.targets[dstName] then
					local class, role, spec = _select(2, _UnitClass(dstGUID, dstFlags, set))
					player.absorbs.targets[dstName] = {
						id = dstGUID,
						class = class,
						role = role,
						spec = spec,
						amount = amount
					}
				else
					player.absorbs.targets[dstName].amount = player.absorbs.targets[dstName].amount + amount
				end
			end

			-- record the spell
			if spellid then
				player.absorbs.spells = player.absorbs.spells or {}
				if not player.absorbs.spells[spellid] then
					player.absorbs.spells[spellid] = {count = 0, amount = 0}
				end
				local spell = player.absorbs.spells[spellid]
				spell.school = spell.school or shieldschools[spellid]
				spell.amount = spell.amount + amount
				spell.count = spell.count + 1

				if (not spell.min or amount < spell.min) and amount > 0 then
					spell.min = amount
				end
				if (not spell.max or amount > spell.max) and amount > 0 then
					spell.max = amount
				end
			end
		end
	end

	local shields = Skada:WeakTable()

	local function AuraApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, auratype = ...
		if absorbspells[spellid] then
			shields[dstName] = shields[dstName] or {}
			shields[dstName][spellid] = shields[dstName][spellid] or {}
			shields[dstName][spellid][srcName] = timestamp + absorbspells[spellid]
			if spellschool and not shieldschools[spellid] then
				shieldschools[spellid] = spellschool
			end
		end
	end

	local function AuraRemoved(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, auratype = ...
		if absorbspells[spellid] then
			shields[dstName] = shields[dstName] or {}
			if shields[dstName] and shields[dstName][spellid] and shields[dstName][spellid][srcName] then
				shields[dstName][spellid][srcName] = timestamp + 0.1
			end
		end
	end

	function mod:CheckPreShields(event, timestamp)
		if event == "COMBAT_ENCOUNTER_START" and Skada.current and not Skada.current.stopped then
			local prefix, min, max = "raid", 1, _GetNumRaidMembers()
			if max == 0 then
				prefix, min, max = "party", 0, _GetNumPartyMembers()
			end

			local curtime = _GetTime()
			for n = min, max do
				local unit = (n == 0) and "player" or prefix .. _tostring(n)
				if _UnitExists(unit) and not _UnitIsDeadOrGhost(unit) then
					local dstName = _select(1, _UnitName(unit))
					for i = 1, 40 do
						local spellname, _, _, _, _, _, expires, unitCaster, _, _, spellid = _UnitBuff(unit, i)
						if spellid and absorbspells[spellid] and unitCaster then
							shields[dstName] = shields[dstName] or {}
							shields[dstName][spellid] = shields[dstName][spellid] or {}
							shields[dstName][spellid][_select(1, _UnitName(unitCaster))] = timestamp + expires - curtime
						end
					end
				end
			end
		end
	end

	local function process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool)
		shields[dstName] = shields[dstName] or {}

		local found_sources, found_src, found_shield_id

		for shield_id, sources in _pairs(shields[dstName]) do
			-- Twin Val'kyr light essence and we took fire damage?
			if shield_id == 65686 then
				if _band(spellschool, 0x4) == spellschool then
					return
				end
			-- Twin Val'kyr dark essence and we took shadow damage?
			elseif shield_id == 65684 then
				if _band(spellschool, 0x20) == spellschool then
					return
				end
			-- Frost Ward and we took frost damage?
			elseif mage_frost_ward[shield_id] then
				if _band(spellschool, 0x10) == spellschool then
					found_shield_id = shield_id
					found_sources = sources
					break
				end
			-- Fire Ward and we took fire damage?
			elseif mage_fire_ward[shield_id] then
				if _band(spellschool, 0x4) == spellschool then
					found_shield_id = shield_id
					found_sources = sources
					break
				end
			-- Shadow Ward and we took shadow damage?
			elseif warlock_shadow_ward[shield_id] then
				if _band(spellschool, 0x20) == spellschool then
					found_shield_id = shield_id
					found_sources = sources
					break
				end
			else
				local mintime
				for shield_src, ts in _pairs(sources) do
					local starttime = ts - timestamp
					if starttime > 0 and (mintime == nil or starttime < mintime) then
						found_src = shield_src
						found_shield_id = shield_id
						mintime = starttime
					end
				end
			end
		end

		-- we didn't find any source but we have a shield?
		if not found_src and found_sources then
			local mintime
			for shield_src, ts in _pairs(found_sources) do
				local starttime = ts - timestamp
				if starttime > 0 and (mintime == nil or starttime < mintime) then
					found_src = shield_src
					mintime = starttime
				end
			end
		end

		if found_src and found_shield_id then
			log_absorb(Skada.current, found_src, dstGUID, dstName, dstFlags, found_shield_id, absorbed)
			log_absorb(Skada.total, found_src, dstGUID, dstName, dstFlags, found_shield_id, absorbed)
		end
	end

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local _, _, spellschool, _, _, _, _, _, absorbed = ...
		if absorbed and absorbed > 0 and dstName and shields[dstName] and srcName then
			process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool)
		end
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local _, _, spellschool, misstype, absorbed = ...
		if misstype == "ABSORB" and absorbed > 0 and dstName and shields[dstName] and srcName then
			process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool)
		end
	end

	local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local _, _, spellschool, _, _, absorbed = ...
		if absorbed and absorbed > 0 and dstName and shields[dstName] and srcName then
			process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool)
		end
	end

	local function SwingMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, nil, nil, 1, ...)
	end

	local function EnvironmentDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local envtype, _, _, _, _, _, absorbed = ...
		if (absorbed or 0) > 0 then
			local spellschool

			if envtype == "Falling" or envtype == "FALLING" then
				spellschool = 1
			elseif envtype == "Drowning" or envtype == "DROWNING" then
				spellschool = 1
			elseif envtype == "Fatigue" or envtype == "FATIGUE" then
				spellschool = 1
			elseif envtype == "Fire" or envtype == "FIRE" then
				spellschool = 4
			elseif envtype == "Lava" or envtype == "LAVA" then
				spellschool = 4
			elseif envtype == "Slime" or envtype == "SLIME" then
				spellschool = 8
			end

			process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool or 1)
		end
	end

	local function spell_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), win.playerid, win.playername)
		if player then
			local spell
			if player.absorbs and player.absorbs.spells then
				spell = player.absorbs.spells[id]
			end

			if spell then
				tooltip:AddLine(player.name .. " - " .. label)
				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
				end
				if spell.min and spell.max then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
				end
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's absorb spells"], label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's absorb spells"], player.name)
			local total = player.absorbs and player.absorbs.amount or 0

			if total > 0 and player.absorbs.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.absorbs.spells) do
					if (spell.amount or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						local spellname, _, spellicon = _GetSpellInfo(spellid)
						d.id = spellid
						d.spellid = spellid
						d.label = spellname
						d.text = spellname .. (spell.ishot and L["HoT"] or "")
						d.icon = spellicon
						d.spellschool = spell.school

						d.value = spell.amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(spell.amount),
							mod.metadata.columns.Absorbs,
							_format("%02.1f%%", 100 * spell.amount / total),
							mod.metadata.columns.Percent
						)

						if spell.amount > maxvalue then
							maxvalue = spell.amount
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's absorbed players"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's absorbed players"], player.name)
			local total = player.absorbs and player.absorbs.amount or 0

			if total > 0 and player.absorbs.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.absorbs.targets) do
					if (target.amount or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = target.id or targetname
						d.label = targetname
						d.class = target.class or "PET"
						d.role = target.role or "DAMAGER"
						d.spec = target.spec

						d.value = target.amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(target.amount),
							mod.metadata.columns.Absorbs,
							_format("%02.1f%%", 100 * target.amount / total),
							mod.metadata.columns.Percent
						)

						if target.amount > maxvalue then
							maxvalue = target.amount
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Absorbs"]
		local total = set.absorbs or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.absorbs and (player.absorbs.amount or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.class = player.class or "PET"
					d.role = player.role or "DAMAGER"
					d.spec = player.spec or 1

					d.value = player.absorbs.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(player.absorbs.amount),
						self.metadata.columns.Absorbs,
						_format("%02.1f%%", 100 * player.absorbs.amount / total),
						self.metadata.columns.Percent
					)

					if player.absorbs.amount > maxvalue then
						maxvalue = player.absorbs.amount
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = spell_tooltip}
		playermod.metadata = {showspots = true}
		self.metadata = {
			showspots = true,
			click1 = spellmod,
			click2 = playermod,
			columns = {Absorbs = true, Percent = true},
			icon = "Interface\\Icons\\spell_holy_powerwordshield"
		}

		Skada:RegisterForCL(AuraApplied, "SPELL_AURA_APPLIED", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(AuraRemoved, "SPELL_AURA_REMOVED", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(AuraApplied, "SPELL_AURA_REFRESH", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(EnvironmentDamage, "ENVIRONMENTAL_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {dst_is_interesting_nopets = true})

		Skada.RegisterCallback(self, "COMBAT_ENCOUNTER_START", "CheckPreShields")
		Skada:AddMode(self, L["Absorbs and healing"])
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.absorbs or 0)
	end
end)

-- ========================== --
-- Absorbs and healing module --
-- ========================== --

Skada:AddLoadableModule("Absorbs and healing", function(Skada, L)
	if Skada:IsDisabled("Healing", "Absorbs", "Absorbs and healing") then return end

	local mod = Skada:NewModule(L["Absorbs and healing"])
	local playermod = mod:NewModule(L["Absorbed and healed players"])
	local spellmod = mod:NewModule(L["Absorbs and healing spells"])

	local _time = time

	local function getHPS(set, player)
		local healing = (player.healing and player.healing.amount or 0) + (player.absorbs and player.absorbs.amount or 0)
		return healing / math_max(1, Skada:PlayerActiveTime(set, player)), healing
	end
	mod.getHPS = getHPS

	local function getRaidHPS(set)
		local healing = (set.healing or 0) + (set.absorbs or 0)
		if set.time > 0 then
			return healing / math_max(1, set.time), healing
		else
			return healing / math_max(1, (set.endtime or _time()) - set.starttime), healing
		end
	end
	mod.getRaidHPS = getRaidHPS

	local function hps_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		local player = Skada:find_player(set, id)
		if player then
			tooltip:AddLine(player.name .. " - " .. L["HPS"])
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(Skada:GetSetTime(set)), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(Skada:PlayerActiveTime(set, player, true)), 1, 1, 1)

			local healing =
				(player.healing and player.healing.amount or 0) + (player.absorbs and player.absorbs.amount or 0)
			local total = (set.healing or 0) + (set.absorbs or 0)
			tooltip:AddDoubleLine(L["Absorbs and healing"], _format("%s (%02.1f%%)", Skada:FormatNumber(healing), 100 * healing / math_max(1, total)), 1, 1, 1)
		end
	end

	local function spell_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), win.playerid, win.playername)
		if player then
			local spell
			if player.healing and player.healing.spells then
				spell = player.healing.spells[id]
			end
			if not spell and player.absorbs and player.absorbs.spells then
				spell = player.absorbs.spells[id]
			end
			if spell then
				tooltip:AddLine(player.name .. " - " .. label)
				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
				end
				tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
				if spell.min and spell.max then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
				end
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
				if (spell.critical or 0) > 0 then
					tooltip:AddDoubleLine(L["Critical"], _format("%02.1f%%", 100 * spell.critical / spell.count), 1, 1, 1)
				end
				if (spell.overhealing or 0) > 0 then
					tooltip:AddDoubleLine(L["Overhealing"], _format("%02.1f%%", 100 * spell.overhealing / (spell.overhealing + spell.amount)), 1, 1, 1)
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's absorb and healing spells"], label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's absorb and healing spells"], player.name)

			local total, spells = 0, {}

			if player.healing and (player.healing.amount or 0) > 0 then
				total = total + player.healing.amount
				for spellid, spell in _pairs(player.healing.spells) do
					spells[spellid] = CopyTable(spell)
				end
			end
			if player.absorbs and (player.absorbs.amount or 0) > 0 then
				total = total + player.absorbs.amount
				for spellid, spell in _pairs(player.absorbs.spells) do
					if not spells[spellid] then
						spells[spellid] = CopyTable(spell)
					else
						spells[spellid].amount = spells[spellid].amount + spell.amount
						spells[spellid].count = (spells[spellid].count or 0) + (spell.count or 0)
					end
				end
			end

			if total > 0 then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(spells) do
					if spell.amount > 0 then
						local spellname, _, spellicon = _GetSpellInfo(spellid)

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellid
						d.spellid = spellid
						d.label = spellname
						d.text = spellname .. (spell.ishot and L["HoT"] or "")
						d.icon = spellicon
						d.spellschool = spell.school

						d.value = spell.amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(spell.amount),
							mod.metadata.columns.Healing,
							_format("%02.1f%%", 100 * spell.amount / math_max(1, total)),
							mod.metadata.columns.Percent
						)

						if spell.amount > maxvalue then
							maxvalue = spell.amount
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's absorbed and healed players"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's absorbed and healed players"], player.name)

			local total, targets = 0, {}

			if player.healing and (player.healing.amount or 0) > 0 then
				total = total + player.healing.amount
				for targetname, target in _pairs(player.healing.targets) do
					targets[targetname] = CopyTable(target)
				end
			end

			if player.absorbs and (player.absorbs.amount or 0) > 0 then
				total = total + player.absorbs.amount
				for targetname, target in _pairs(player.absorbs.targets) do
					if not targets[targetname] then
						targets[targetname] = CopyTable(target)
					else
						targets[targetname].amount = targets[targetname].amount + target.amount
					end
					if not targets[targetname].class and target.class then
						targets[targetname].class = target.class
						targets[targetname].role = target.role
						targets[targetname].spec = target.spec
					end
				end
			end

			if total > 0 then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(targets) do
					if target.amount > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = target.id
						d.label = targetname
						d.class = target.class
						d.role = target.role
						d.spec = target.spec

						d.value = target.amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(target.amount),
							mod.metadata.columns.Healing,
							_format("%02.1f%%", 100 * target.amount / total),
							mod.metadata.columns.Percent
						)

						if target.amount > maxvalue then
							maxvalue = target.amount
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Absorbs and healing"]
		local total = _select(2, getRaidHPS(set))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				local hps, amount = getHPS(set, player)

				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.class = player.class or "PET"
					d.role = player.role or "DAMAGER"
					d.spec = player.spec or 1

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.Healing,
						Skada:FormatNumber(hps),
						self.metadata.columns.HPS,
						_format("%02.1f%%", 100 * amount / total),
						self.metadata.columns.Percent
					)

					if amount > maxvalue then
						maxvalue = amount
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	local function feed_personal_hps()
		if Skada.current then
			local player = Skada:find_player(Skada.current, _UnitGUID("player"))
			if player then
				return Skada:FormatNumber(getHPS(Skada.current, player)) .. " " .. L["HPS"]
			end
		end
	end

	local function feed_raid_hps()
		if Skada.current then
			return Skada:FormatNumber(getRaidHPS(Skada.current)) .. " " .. L["RHPS"]
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = spell_tooltip}
		playermod.metadata = {showspots = true}
		self.metadata = {
			showspots = true,
			click1 = spellmod,
			click2 = playermod,
			columns = {Healing = true, HPS = true, Percent = true},
			icon = "Interface\\Icons\\spell_holy_healingfocus"
		}

		Skada:AddFeed(L["Healing: Personal HPS"], feed_personal_hps)
		Skada:AddFeed(L["Healing: Raid HPS"], feed_raid_hps)

		Skada:AddMode(self, L["Absorbs and healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
		Skada:RemoveFeed(L["Healing: Personal HPS"])
		Skada:RemoveFeed(L["Healing: Raid HPS"])
	end

	function mod:AddToTooltip(set, tooltip)
		local hps, total = getRaidHPS(set)
		if total > 0 then
			tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(total), 1, 1, 1)
			tooltip:AddDoubleLine(L["HPS"], Skada:FormatNumber(hps), 1, 1, 1)
		end
		if (set.overhealing or 0) > 0 then
			total = total + set.overhealing
			tooltip:AddDoubleLine(L["Overhealing"], _format("%02.1f%%", 100 * set.overhealing / math_max(1, total)), 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		local hps, total = getRaidHPS(set)
		return Skada:FormatValueText(
			Skada:FormatNumber(total),
			self.metadata.columns.Healing,
			Skada:FormatNumber(hps),
			self.metadata.columns.HPS
		)
	end
end)

-- ============================== --
-- Healing done per second module --
-- ============================== --

Skada:AddLoadableModule("HPS", function(Skada, L)
	if Skada:IsDisabled("Absorbs and healing", "HPS") then return end

	local parentmod = Skada:GetModule(L["Absorbs and healing"], true)
	if not parentmod then return end

	local mod = Skada:NewModule(L["HPS"])
	local getHPS, getRaidHPS = parentmod.getHPS, parentmod.getRaidHPS

	function mod:Update(win, set)
		win.title = L["HPS"]
		local total = getRaidHPS(set)

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local amount = getHPS(set, player)
				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.class = player.class or "PET"
					d.role = player.role or "DAMAGER"
					d.spec = player.spec or 1

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.HPS,
						_format("%02.1f%%", 100 * amount / total),
						self.metadata.columns.Percent
					)

					if amount > maxvalue then
						maxvalue = amount
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
			tooltip = hps_tooltip,
			click1 = parentmod.metadata.click1,
			click2 = parentmod.metadata.click2,
			columns = {HPS = true, Percent = true},
			icon = "Interface\\Icons\\spell_nature_rejuvenation"
		}
		Skada:AddMode(self, L["Absorbs and healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(getRaidHPS(set))
	end
end)

-- ===================== --
-- Healing done by spell --
-- ===================== --

Skada:AddLoadableModule("Healing Done By Spell", function(Skada, L)
	if Skada:IsDisabled("Healing", "Absorbs", "Healing Done By Spell") then return end

	local mod = Skada:NewModule(L["Healing Done By Spell"])
	local spellmod = mod:NewModule(L["Healing spell sources"])
	local spells

	local function CacheSpells(set)
		spells = Skada:WeakTable()
		for _, player in Skada:IteratePlayers(set) do
			if player.healing and player.healing.spells then
				for spellid, spell in _pairs(player.healing.spells) do
					if (spell.amount or 0) > 0 then
						if not spells[spellid] then
							spells[spellid] = CopyTable(spell)
						else
							spells[spellid].amount = spells[spellid].amount + spell.amount
							spells[spellid].count = (spells[spellid].count or 0) + (spell.count or 0)
							spells[spellid].overhealing = (spells[spellid].overhealing or 0) + (spell.overhealing or 0)
						end
						spells[spellid].sources = spells[spellid].sources or {}
						-- add spell source
						if not spells[spellid].sources[player.name] then
							spells[spellid].sources[player.name] = {
								id = player.id,
								class = player.class,
								role = player.role,
								spec = player.spec,
								amount = spell.amount
							}
						else
							spells[spellid].sources[player.name].amount = (spells[spellid].sources[player.name].amount or 0) + spell.amount
						end
					end
				end
			end
			if player.absorbs and player.absorbs.spells then
				for spellid, spell in _pairs(player.absorbs.spells) do
					if not spells[spellid] then
						spells[spellid] = CopyTable(spell)
					else
						spells[spellid].amount = spells[spellid].amount + spell.amount
						spells[spellid].count = (spells[spellid].count or 0) + (spell.count or 0)
					end
					-- add spell source
					spells[spellid].sources = spells[spellid].sources or {}
					if not spells[spellid].sources[player.name] then
						spells[spellid].sources[player.name] = {
							id = player.id,
							class = player.class,
							role = player.role,
							spec = player.spec,
							amount = spell.amount
						}
					else
						spells[spellid].sources[player.name].amount = (spells[spellid].sources[player.name].amount or 0) + spell.amount
					end
				end
			end
		end
	end

	local function spell_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then
			return
		end

		if not spells then
			CacheSpells(set)
		end

		local spell = spells[id]
		if spell then
			local total = (set.healing or 0) + (set.absorbs or 0)
			if total > 0 then
				local overheal = (set.overhealing or 0)

				tooltip:AddLine(_GetSpellInfo(id))
				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
				end

				if spell.count then
					tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
				end
				tooltip:AddDoubleLine(L["Healing"], _format("%s (%02.1f%%)", Skada:FormatNumber(spell.amount), 100 * spell.amount / math_max(1, total)), 1, 1, 1)
				if (spell.overhealing or 0) > 0 then
					tooltip:AddDoubleLine(L["Overhealing"], _format("%s (%02.1f%%)", Skada:FormatNumber(spell.overhealing), 100 * spell.overhealing / math_max(1, overheal)), 1, 1, 1)
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = _format(L["%s's sources"], label)
	end

	function spellmod:Update(win, set)
		local healing = (set.healing or 0) + (set.absorbs or 0)
		if healing > 0 then
			CacheSpells(set)
			local spell = spells[win.spellid]
			if spell then
				win.title = _format(L["%s's sources"], win.spellname or UNKNOWN)
				local maxvalue, nr = 0, 1

				for playername, player in _pairs(spell.sources) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = playername
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(player.amount),
						mod.metadata.columns.Healing,
						_format("%02.1f%%", 100 * player.amount / math_max(1, spell.amount)),
						mod.metadata.columns.Percent
					)

					if player.amount > maxvalue then
						maxvalue = player.amount
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing Done By Spell"]
		local total = (set.healing or 0) + (set.absorbs or 0)

		if total > 0 then
			CacheSpells(set)
			local maxvalue, nr = 0, 1

			for spellid, spell in _pairs(spells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				local spellname, _, spellicon = _GetSpellInfo(spellid)
				d.id = spellid
				d.spellid = spellid
				d.label = spellname
				d.text = spellname .. (spell.ishot and L["HoT"] or "")
				d.icon = spellicon
				d.spellschool = spell.school

				d.value = spell.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(spell.amount),
					self.metadata.columns.Healing,
					_format("%02.1f%%", 100 * spell.amount / total),
					self.metadata.columns.Percent
				)

				if spell.amount > maxvalue then
					maxvalue = spell.amount
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			tooltip = spell_tooltip,
			click1 = spellmod,
			columns = {Healing = true, Percent = true},
			icon = "Interface\\Icons\\spell_nature_healingwavelesser"
		}
		Skada:AddMode(self, L["Absorbs and healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self, L["Absorbs and healing"])
	end
end)