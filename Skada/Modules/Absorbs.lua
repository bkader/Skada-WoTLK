local _, Skada = ...
local Private = Skada.Private

-- cache frequently used globals
local pairs, format, uformat = pairs, string.format, Private.uformat
local min, floor = math.min, math.floor
local new, del = Private.newTable, Private.delTable
local PercentToRGB = Private.PercentToRGB
local tooltip_school = Skada.tooltip_school
local hits_perc = "%s (\124cffffffff%s\124r)"
local slash_fmt = "%s/%s"

---------------------------------------------------------------------------
-- Absorbs Module

Skada:RegisterModule("Absorbs", function(L, P, G)
	local mode = Skada:NewModule("Absorbs")
	local mode_spell = mode:NewModule("Spell List")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	local ignored_spells = Skada.ignored_spells.absorb -- Edit Skada\Core\Tables.lua
	local passive_spells = Skada.ignored_spells.time -- Edit Skada\Core\Tables.lua
	local spellnames = Skada.spellnames

	local band, tsort, max = bit.band, table.sort, math.max
	local GetCurrentMapAreaID, UnitBuff, UnitLevel, UnitHealthInfo = GetCurrentMapAreaID, UnitBuff, UnitLevel, Skada.UnitHealthInfo
	local IsActiveBattlefieldArena, UnitInBattleground = IsActiveBattlefieldArena, UnitInBattleground
	tooltip_school = tooltip_school or Skada.tooltip_school
	local classfmt = Skada.classcolors.format
	local clear = Private.clearTable
	local mode_cols = nil

	-- INCOMPLETE
	-- the following list is incomplete due to the lack of testing for different
	-- shield ranks. Feel free to provide any helpful data possible to complete it.
	-- Note: some of the caps are used as backup because their amounts are calculated later.
	local ABSORB_SPELLS = {
		[48707] = {school = 0x20, dur = 5}, -- Anti-Magic Shell (rank 1)
		[51052] = {school = 0x20, dur = 10}, -- Anti-Magic Zone( (rank 1)
		[52286] = {school = 0x01, dur = 86400}, -- Will of the Necropolis
		[49497] = {school = 0x01, dur = 86400}, -- Spell Deflection
		[62606] = {school = 0x08, dur = 10, avg = 1600, cap = 2500}, -- Savage Defense
		[11426] = {school = 0x10, dur = 60}, -- Ice Barrier (rank 1)
		[13031] = {school = 0x10, dur = 60}, -- Ice Barrier (rank 2)
		[13032] = {school = 0x10, dur = 60}, -- Ice Barrier (rank 3)
		[13033] = {school = 0x10, dur = 60}, -- Ice Barrier (rank 4)
		[27134] = {school = 0x10, dur = 60}, -- Ice Barrier (rank 5)
		[33405] = {school = 0x10, dur = 60}, -- Ice Barrier (rank 6)
		[43038] = {school = 0x10, dur = 60}, -- Ice Barrier (rank 7)
		[43039] = {school = 0x10, dur = 60, avg = 6500, cap = 8300}, -- Ice Barrier (rank 8)
		[6143] = {school = 0x10, dur = 30}, -- Frost Ward (rank 1)
		[8461] = {school = 0x10, dur = 30}, -- Frost Ward (rank 2)
		[8462] = {school = 0x10, dur = 30}, -- Frost Ward (rank 3)
		[10177] = {school = 0x10, dur = 30}, -- Frost Ward (rank 4)
		[28609] = {school = 0x10, dur = 30}, -- Frost Ward (rank 5)
		[32796] = {school = 0x10, dur = 30}, -- Frost Ward (rank 6)
		[43012] = {school = 0x10, dur = 30, avg = 5200, cap = 7000}, -- Frost Ward (rank 7)
		[1463] = {school = 0x40, dur = 60}, -- Mana shield (rank 1)
		[8494] = {school = 0x40, dur = 60}, -- Mana shield (rank 2)
		[8495] = {school = 0x40, dur = 60}, -- Mana shield (rank 3)
		[10191] = {school = 0x40, dur = 60}, -- Mana shield (rank 4)
		[10192] = {school = 0x40, dur = 60}, -- Mana shield (rank 5)
		[10193] = {school = 0x40, dur = 60}, -- Mana shield (rank 6)
		[27131] = {school = 0x40, dur = 60}, -- Mana shield (rank 7)
		[43019] = {school = 0x40, dur = 60}, -- Mana shield (rank 8)
		[43020] = {school = 0x40, dur = 60, avg = 4500, cap = 6300}, -- Mana shield (rank 9)
		[543] = {school = 0x04, dur = 30}, -- Fire Ward (rank 1)
		[8457] = {school = 0x04, dur = 30}, -- Fire Ward (rank 2)
		[8458] = {school = 0x04, dur = 30}, -- Fire Ward (rank 3)
		[10223] = {school = 0x04, dur = 30}, -- Fire Ward (rank 4)
		[10225] = {school = 0x04, dur = 30}, -- Fire Ward (rank 5)
		[27128] = {school = 0x04, dur = 30}, -- Fire Ward (rank 6)
		[43010] = {school = 0x04, dur = 30, avg = 5200, cap = 7000}, -- Fire Ward (rank 7)
		[58597] = {school = 0x02, dur = 6, avg = 4400, cap = 6000}, -- Sacred Shield
		[66233] = {school = 0x02, dur = 86400}, -- Ardent Defender
		[31230] = {school = 0x01, dur = 86400}, -- Cheat Death
		[17] = {school = 0x02, dur = 30}, -- Power Word: Shield (rank 1)
		[592] = {school = 0x02, dur = 30}, -- Power Word: Shield (rank 2)
		[600] = {school = 0x02, dur = 30}, -- Power Word: Shield (rank 3)
		[3747] = {school = 0x02, dur = 30}, -- Power Word: Shield (rank 4)
		[6065] = {school = 0x02, dur = 30}, -- Power Word: Shield (rank 5)
		[6066] = {school = 0x02, dur = 30}, -- Power Word: Shield (rank 6)
		[10898] = {school = 0x02, dur = 30, avg = 721, cap = 848}, -- Power Word: Shield (rank 7)
		[10899] = {school = 0x02, dur = 30, avg = 898, cap = 1057}, -- Power Word: Shield (rank 8)
		[10900] = {school = 0x02, dur = 30, avg = 1543, cap = 1816}, -- Power Word: Shield (rank 9)
		[10901] = {school = 0x02, dur = 30, avg = 3643, cap = 4288}, -- Power Word: Shield (rank 10)
		[25217] = {school = 0x02, dur = 30, avg = 5436, cap = 6398}, -- Power Word: Shield (rank 11)
		[25218] = {school = 0x02, dur = 30, avg = 7175, cap = 8444}, -- Power Word: Shield (rank 12)
		[48065] = {school = 0x02, dur = 30, avg = 9596, cap = 11293}, -- Power Word: Shield (rank 13)
		[48066] = {school = 0x02, dur = 30, avg = 10000, cap = 11769}, -- Power Word: Shield (rank 14)
		[47509] = {school = 0x02, dur = 12}, -- Divine Aegis (rank 1)
		[47511] = {school = 0x02, dur = 12}, -- Divine Aegis (rank 2)
		[47515] = {school = 0x02, dur = 12}, -- Divine Aegis (rank 3)
		[47753] = {school = 0x02, dur = 12, cap = 10000}, -- Divine Aegis (rank 1)
		[54704] = {school = 0x02, dur = 12, cap = 10000}, -- Divine Aegis (rank 1)
		[47788] = {school = 0x02, dur = 10}, -- Guardian Spirit
		[7812] = {school = 0x20, dur = 30, cap = 305}, -- Sacrifice (rank 1)
		[19438] = {school = 0x20, dur = 30, cap = 510}, -- Sacrifice (rank 2)
		[19440] = {school = 0x20, dur = 30, cap = 770}, -- Sacrifice (rank 3)
		[19441] = {school = 0x20, dur = 30, cap = 1095}, -- Sacrifice (rank 4)
		[19442] = {school = 0x20, dur = 30, cap = 1470}, -- Sacrifice (rank 5)
		[19443] = {school = 0x20, dur = 30, cap = 1905}, -- Sacrifice (rank 6)
		[27273] = {school = 0x20, dur = 30, cap = 2855}, -- Sacrifice (rank 7)
		[47985] = {school = 0x20, dur = 30, cap = 6750}, -- Sacrifice (rank 8)
		[47986] = {school = 0x20, dur = 30, cap = 8350}, -- Sacrifice (rank 9)
		[6229] = {school = 0x20, dur = 30, cap = 290}, -- Shadow Ward (rank 1)
		[11739] = {school = 0x20, dur = 30, cap = 470}, -- Shadow Ward (rank 2)
		[11740] = {school = 0x20, dur = 30, avg = 675}, -- Shadow Ward (rank 3)
		[28610] = {school = 0x20, dur = 30, avg = 875}, -- Shadow Ward (rank 4)
		[47890] = {school = 0x20, dur = 30, avg = 2750}, -- Shadow Ward (rank 5)
		[47891] = {school = 0x20, dur = 30, avg = 3300, cap = 8300}, -- Shadow Ward (rank 6)
		[25228] = {school = 0x20, dur = 86400}, -- Soul Link
		[29674] = {school = 0x40, dur = 86400, cap = 1000}, -- Lesser Ward of Shielding
		[29719] = {school = 0x40, dur = 86400, cap = 4000}, -- Greater Ward of Shielding
		[29701] = {school = 0x40, dur = 86400, cap = 4000}, -- Greater Shielding
		[28538] = {school = 0x02, dur = 120, avg = 3400, cap = 4000}, -- Major Holy Protection Potion
		[28537] = {school = 0x20, dur = 120, avg = 3400, cap = 4000}, -- Major Shadow Protection Potion
		[28536] = {school = 0x04, dur = 120, avg = 3400, cap = 4000}, -- Major Arcane Protection Potion
		[28513] = {school = 0x08, dur = 120, avg = 3400, cap = 4000}, -- Major Nature Protection Potion
		[28512] = {school = 0x10, dur = 120, avg = 3400, cap = 4000}, -- Major Frost Protection Potion
		[28511] = {school = 0x04, dur = 120, avg = 3400, cap = 4000}, -- Major Fire Protection Potion
		[7233] = {school = 0x04, dur = 120, avg = 1300, cap = 1625}, -- Fire Protection Potion
		[7239] = {school = 0x10, dur = 120, avg = 1800, cap = 2250}, -- Frost Protection Potion
		[7242] = {school = 0x20, dur = 120, avg = 1800, cap = 2250}, -- Shadow Protection Potion
		[7245] = {school = 0x02, dur = 120, avg = 1800, cap = 2250}, -- Holy Protection Potion
		[7254] = {school = 0x08, dur = 120, avg = 1800, cap = 2250}, -- Nature Protection Potion
		[53915] = {school = 0x20, dur = 120, avg = 5100, cap = 6000}, -- Mighty Shadow Protection Potion
		[53914] = {school = 0x08, dur = 120, avg = 5100, cap = 6000}, -- Mighty Nature Protection Potion
		[53913] = {school = 0x10, dur = 120, avg = 5100, cap = 6000}, -- Mighty Frost Protection Potion
		[53911] = {school = 0x04, dur = 120, avg = 5100, cap = 6000}, -- Mighty Fire Protection Potion
		[53910] = {school = 0x04, dur = 120, avg = 5100, cap = 6000}, -- Mighty Arcane Protection Potion
		[17548] = {school = 0x20, dur = 120, avg = 2600, cap = 3250}, -- Greater Shadow Protection Potion
		[17546] = {school = 0x08, dur = 120, avg = 2600, cap = 3250}, -- Greater Nature Protection Potion
		[17545] = {school = 0x02, dur = 120, avg = 2600, cap = 3250}, -- Greater Holy Protection Potion
		[17544] = {school = 0x10, dur = 120, avg = 2600, cap = 3250}, -- Greater Frost Protection Potion
		[17543] = {school = 0x04, dur = 120, avg = 2600, cap = 3250}, -- Greater Fire Protection Potion
		[17549] = {school = 0x04, dur = 120, avg = 2600, cap = 3250}, -- Greater Arcane Protection Potion
		[28527] = {school = 0x02, dur = 15, avg = 1000, cap = 1250}, -- Fel Blossom
		[29432] = {school = 0x04, dur = 3600, avg = 2000, cap = 2500}, -- Frozen Rune (Fire Protection)
		[36481] = {school = 0x40, dur = 4, cap = 100000}, -- Arcane Barrier (TK Kael'Thas) Shield
		[17252] = {school = 0x01, dur = 1800, cap = 500}, -- Mark of the Dragon Lord (LBRS epic ring)
		[25750] = {school = 0x02, dur = 15, avg = 151, cap = 302}, -- Defiler's Talisman/Talisman of Arathor
		[25747] = {school = 0x02, dur = 15, avg = 344, cap = 378}, -- Defiler's Talisman/Talisman of Arathor
		[25746] = {school = 0x02, dur = 15, avg = 435, cap = 478}, -- Defiler's Talisman/Talisman of Arathor
		[23991] = {school = 0x02, dur = 15, avg = 550, cap = 605}, -- Defiler's Talisman/Talisman of Arathor
		[30997] = {school = 0x04, dur = 300, avg = 1800, cap = 2700}, -- Pendant of Frozen Flame (Fire Absorption)
		[31002] = {school = 0x40, dur = 300, avg = 1800, cap = 2700}, -- Pendant of the Null Rune (Arcane Absorption)
		[30999] = {school = 0x08, dur = 300, avg = 1800, cap = 2700}, -- Pendant of Withering (Nature Absorption)
		[30994] = {school = 0x10, dur = 300, avg = 1800, cap = 2700}, -- Pendant of Thawing (Frost Absorption)
		[31000] = {school = 0x40, dur = 300, avg = 1800, cap = 2700}, -- Pendant of Shadow's End (Shadow Absorption)
		[23506] = {school = 0x02, dur = 20, avg = 1000, cap = 1250}, -- Arena Grand Master (Aura of Protection)
		[12561] = {school = 0x04, dur = 60, avg = 400, cap = 500}, -- Goblin Construction Helmet (Fire Protection)
		[31771] = {school = 0x02, dur = 20, cap = 440}, -- Runed Fungalcap (Shell of Deterrence)
		[21956] = {school = 0x02, dur = 10, cap = 500}, -- Mark of Resolution (Physical Protection)
		[29506] = {school = 0x02, dur = 20, cap = 900}, -- The Burrower's Shell
		[4057] = {school = 0x04, dur = 60, cap = 500}, -- Flame Deflector (Fire Resistance)
		[4077] = {school = 0x10, dur = 60, cap = 600}, -- Ice Deflector (Frost Resistance)
		[39228] = {school = 0x02, dur = 20, cap = 1150}, -- Argussian Compass
		[27779] = {school = 0x02, dur = 30, cap = 350}, -- Divine Protection (Priest dungeon set 1/2)
		[11657] = {school = 0x01, dur = 20, avg = 70, cap = 85}, -- Jang'thraze
		[10368] = {school = 0x02, dur = 15, cap = 200}, -- Uther's Light Effect
		[37515] = {school = 0x02, dur = 15, cap = 200}, -- Blade Turning
		[42137] = {school = 0x01, dur = 86400, cap = 400}, -- Greater Rune of Warding
		[26467] = {school = 0x01, dur = 30, cap = 1000}, -- Scarab Brooch (Persistent Shield)
		[26470] = {school = 0x08, dur = 8, cap = 1000}, -- Persistent Shield
		[27539] = {school = 0x01, dur = 6, avg = 300, cap = 500}, -- Thick Obsidian Breatplate (Obsidian Armor)
		[28810] = {school = 0x02, dur = 30, cap = 500}, -- Faith Set Proc (Armor of Faith)
		[55019] = {school = 0x01, dur = 12, cap = 1100}, -- Sonic Shield
		[64413] = {school = 0x08, dur = 8, cap = 20000}, -- Protection of Ancient Kings (Val'anyr, Hammer of Ancient Kings)
		[40322] = {school = 0x10, dur = 30, avg = 12000, cap = 12600}, -- Teron's Vengeful Spirit Ghost - Spirit Shield
		[71586] = {school = 0x02, dur = 10, cap = 6400}, -- Hardened Skin (Corroded Skeleton Key)
		[60218] = {school = 0x02, dur = 10, avg = 140, cap = 4000}, -- Essence of Gossamer
		[57350] = {school = 0x01, dur = 6, cap = 1500}, -- Illusionary Barrier (Darkmoon Card: Illusion)
		[70845] = {school = 0x01, dur = 10}, -- Stoicism
		[65874] = {school = 0x20, dur = 15, cap = 175000}, -- Twin Val'kyr's: Shield of Darkness
		[67257] = {school = 0x20, dur = 15, cap = 300000}, -- Twin Val'kyr's: Shield of Darkness
		[67256] = {school = 0x20, dur = 15, cap = 700000}, -- Twin Val'kyr's: Shield of Darkness
		[67258] = {school = 0x20, dur = 15, cap = 1200000}, -- Twin Val'kyr's: Shield of Darkness
		[65858] = {school = 0x04, dur = 15, cap = 175000}, -- Twin Val'kyr's: Shield of Lights
		[67260] = {school = 0x04, dur = 15, cap = 300000}, -- Twin Val'kyr's: Shield of Lights
		[67259] = {school = 0x04, dur = 15, cap = 700000}, -- Twin Val'kyr's: Shield of Lights
		[67261] = {school = 0x04, dur = 15, cap = 1200000}, -- Twin Val'kyr's: Shield of Lights
		[65686] = {school = 0x01, dur = 86400, cap = 1000000}, -- Twin Val'kyr: Light Essence
		[65684] = {school = 0x01, dur = 86400, cap = 1000000} -- Twin Val'kyr: Dark Essence
	}

	local PRIEST_DIVINE_AEGIS = { -- Divine Aegis
		[47509] = true,
		[47511] = true,
		[47515] = true,
		[47753] = true,
		[54704] = true
	}
	local MAGE_FROST_WARD = { -- Frost Ward
		[6143] = true,
		[8461] = true,
		[8462] = true,
		[10177] = true,
		[28609] = true,
		[32796] = true,
		[43012] = true
	}
	local MAGE_FIRE_WARD = { -- Fire Ward
		[543] = true,
		[8457] = true,
		[8458] = true,
		[10223] = true,
		[10225] = true,
		[27128] = true,
		[43010] = true
	}
	local MAGE_ICE_BARRIER = { -- Ice Barrier
		[11426] = true,
		[13031] = true,
		[13032] = true,
		[13033] = true,
		[27134] = true,
		[33405] = true,
		[43038] = true,
		[43039] = true
	}
	local WARLOCK_SHADOW_WARD = { -- Shadow Ward
		[6229] = true,
		[11739] = true,
		[11740] = true,
		[28610] = true,
		[47890] = true,
		[47891] = true
	}
	local WARLOCK_SACRIFICE = { -- Sacrifice
		[7812] = true,
		[19438] = true,
		[19440] = true,
		[19441] = true,
		[19442] = true,
		[19443] = true,
		[27273] = true,
		[47985] = true,
		[47986] = true
	}

	-- passive shields that are applied by default.
	local PASSIVE_SHIELDS = {
		[31230] = true, -- Cheat Death
		[49497] = true, -- Spell Deflection
		[52286] = true, -- Will of the Necropolis
		[66233] = true, -- Ardent Defender
	}

	local zoneModifier = 1 -- coefficient used to calculate amounts
	local heals = {} -- holds heal amounts used to "guess" shield amounts
	local shields = {} -- holds the list of players shields and other stuff
	local shield_amounts = {} -- holds the amount shields absorbed so far
	local shields_popped = nil -- holds the list of shields that popped on a player
	local queued_amounts = nil -- amounts that went lost, added to next spell
	local absorb = {}

	local function format_valuetext(d, total, aps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Absorbs and Skada:FormatNumber(d.value),
			mode_cols[subview and "sAPS" or "APS"] and aps and Skada:FormatNumber(aps),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_absorb(set, nocount)
		if not absorb.amount or absorb.amount == 0 then return end

		local actor = Skada:GetActor(set, absorb.actorname, absorb.actorid, absorb.actorflags)
		if not actor then
			return
		elseif actor.role ~= "DAMAGER" and not passive_spells[absorb.spell] and not nocount then
			Skada:AddActiveTime(set, actor, absorb.dstName)
		end

		-- add absorbs amount
		actor.absorb = (actor.absorb or 0) + absorb.amount
		set.absorb = (set.absorb or 0) + absorb.amount

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- record the spell
		local spell = actor.absorbspells and actor.absorbspells[absorb.spellid]
		if not spell then
			actor.absorbspells = actor.absorbspells or {}
			actor.absorbspells[absorb.spellid] = {amount = 0}
			spell = actor.absorbspells[absorb.spellid]
		end
		spell.amount = spell.amount + absorb.amount

		if not nocount then
			spell.count = (spell.count or 0) + 1

			if absorb.critical then
				spell.c_num = (spell.c_num or 0) + 1
				spell.c_amt = (spell.c_amt or 0) + absorb.amount
				if not spell.c_max or absorb.amount > spell.c_max then
					spell.c_max = absorb.amount
				end
				if not spell.c_min or absorb.amount < spell.c_min then
					spell.c_min = absorb.amount
				end
			else
				spell.n_num = (spell.n_num or 0) + 1
				spell.n_amt = (spell.n_amt or 0) + absorb.amount
				if not spell.n_max or absorb.amount > spell.n_max then
					spell.n_max = absorb.amount
				end
				if not spell.n_min or absorb.amount < spell.n_min then
					spell.n_min = absorb.amount
				end
			end
		end

		-- record the target
		if not absorb.dstName then return end
		spell.targets = spell.targets or {}
		spell.targets[absorb.dstName] = (spell.targets[absorb.dstName] or 0) + absorb.amount
	end

	-- https://github.com/TrinityCore/TrinityCore/blob/5d82995951c2be99b99b7b78fa12505952e86af7/src/server/game/Spells/Auras/SpellAuraEffects.h#L316
	-- Note: this order is reversed
	local function shields_order_pred(a, b)
		local a_spellid, b_spellid = a.spellid, b.spellid

		if a_spellid == b_spellid then
			return (a.ts > b.ts)
		end

		-- Twin Val'ky
		if a_spellid == 65686 then
			return false
		end
		if b_spellid == 65686 then
			return true
		end
		if a_spellid == 65684 then
			return false
		end
		if b_spellid == 65684 then
			return true
		end

		-- Frost Ward
		if MAGE_FROST_WARD[a_spellid] then
			return false
		end
		if MAGE_FROST_WARD[b_spellid] then
			return true
		end

		-- Fire Ward
		if MAGE_FIRE_WARD[a_spellid] then
			return false
		end
		if MAGE_FIRE_WARD[b_spellid] then
			return true
		end

		-- Shadow Ward
		if WARLOCK_SHADOW_WARD[a_spellid] then
			return false
		end
		if WARLOCK_SHADOW_WARD[b_spellid] then
			return true
		end

		-- Sacred Shield
		if a_spellid == 58597 then
			return false
		end
		if b_spellid == 58597 then
			return true
		end

		-- Fel Blossom
		if a_spellid == 28527 then
			return false
		end
		if b_spellid == 28527 then
			return true
		end

		-- Divine Aegis
		if PRIEST_DIVINE_AEGIS[a_spellid] then
			return false
		end
		if PRIEST_DIVINE_AEGIS[b_spellid] then
			return true
		end

		-- Ice Barrier
		if MAGE_ICE_BARRIER[a_spellid] then
			return false
		end
		if MAGE_ICE_BARRIER[b_spellid] then
			return true
		end

		-- Sacrifice
		if WARLOCK_SACRIFICE[a_spellid] then
			return false
		end
		if WARLOCK_SACRIFICE[b_spellid] then
			return true
		end

		-- Anti-Magic Shell
		if a_spellid == 48707 then
			return false
		end
		if b_spellid == 48707 then
			return true
		end

		-- Will of the Necropolis
		if a_spellid == 52286 then
			return false
		end
		if b_spellid == 52286 then
			return true
		end

		-- Ardent Defender
		if a_spellid == 66233 then
			return false
		end
		if b_spellid == 66233 then
			return true
		end

		-- Hardened Skin (Corroded Skeleton Key)
		if a_spellid == 71586 then
			return false
		end
		if b_spellid == 71586 then
			return true
		end

		return (a.ts > b.ts)
	end

	local function handle_shield(t, points)
		local shield_id = t.dstName and t.spellid
		local SHIELD = shield_id and ABSORB_SPELLS[shield_id]
		if not SHIELD then return end

		local dstName = Skada:FixPetsName(t.dstGUID, t.dstName, t.dstFlags)
		local srcGUID, srcName, srcFlags = t.srcGUID, t.srcName, t.srcFlags

		local shield = shields[dstName] and shields[dstName][shield_id] and shields[dstName][shield_id][srcName]

		-- shield removed?
		if t.event == "SPELL_AURA_REMOVED" then
			if shield then
				shield.ts = t.timestamp + 0.1
			end
			return
		end

		-- Soul Link
		if shield_id == 25228 then
			srcGUID, srcName, srcFlags = Skada:FixMyPets(srcGUID, srcName, srcFlags)
		end

		-- shield applied
		if not shield then
			shield = new()
			shield.srcGUID = srcGUID
			shield.srcFlags = srcFlags
			shield.string = t.spellstring
			shield.points = points
			-- add it to shields table
			shields[dstName] = shields[dstName] or new()
			shields[dstName][shield_id] = shields[dstName][shield_id] or new()
			shields[dstName][shield_id][srcName] = shield
		end

		-- we calculate how much the shield's maximum absorb amount
		local amount = 0

		-- Stackable Shields
		if (PRIEST_DIVINE_AEGIS[shield_id] or shield_id == 64413) then
			if shield.ts and t.timestamp < shield.ts then
				amount = shield.amount
			end
		end

		if PRIEST_DIVINE_AEGIS[shield_id] then -- Divine Aegis
			if heals[dstName] and heals[dstName][srcName] and heals[dstName][srcName].ts > t.timestamp - 0.2 then
				amount = min((UnitLevel(srcName) or 80) * 125, amount + (heals[dstName][srcName].amount * 0.3 * zoneModifier))
			else
				amount = SHIELD.cap
			end
		elseif shield_id == 64413 then -- Protection of Ancient Kings (Vala'nyr)
			if heals[dstName] and heals[dstName][srcName] and heals[dstName][srcName].ts > t.timestamp - 0.2 then
				amount = min(20000, amount + (heals[dstName][srcName].amount * 0.15))
			else
				amount = SHIELD.cap
			end
		elseif (shield_id == 48707 or shield_id == 51052) and UnitHealthMax(dstName) then -- Anti-Magic Shell/Zone
			amount = UnitHealthMax(dstName) * 0.5
		elseif shield_id == 70845 and UnitHealthMax(dstName) then -- Stoicism
			amount = UnitHealthMax(dstName) * 0.2
		elseif SHIELD.cap or SHIELD.avg then
			if shield_amounts[srcName] and shield_amounts[srcName][shield_id] then
				shield.amount = shield_amounts[srcName][shield_id]
				shield.ts = t.timestamp + SHIELD.dur + 0.1
				shield.full = true

				if not shield.points and points then
					shield.points = points
				end

				return
			else
				amount = (SHIELD.avg or SHIELD.cap or 1000) * zoneModifier
			end
		else
			amount = 1000 * zoneModifier -- default
		end

		shield.amount = floor(amount)
		shield.ts = t.timestamp + SHIELD.dur + 0.1
		shield.full = true

		if not shield.points and points then
			shield.points = points
		end
	end

	-- unfortunate hack so we don't lose any amount!
	local function queue_amount(dstName, amount)
		queued_amounts = queued_amounts or new()
		queued_amounts[dstName] = (queued_amounts[dstName] or 0) + amount
	end

	local function unqueue_amount(dstName, amount)
		if queued_amounts and queued_amounts[dstName] then
			amount = amount + queued_amounts[dstName]
			queued_amounts[dstName] = nil
		end
		return amount
	end

	local function process_absorb(dstName, t, broke)
		shields_popped = clear(shields_popped) or {}

		local timestamp = t.timestamp
		local spellschool = t.spellschool
		for spellid, sources in pairs(shields[dstName]) do
			for srcName, spell in pairs(sources) do
				if spell.ts > timestamp then
					-- Light Essence vs Fire Damage
					if spellid == 65686 and band(spellschool, 0x04) == spellschool then
						return -- don't record
					-- Dark Essence vs Shadow Damage
					elseif spellid == 65684 and band(spellschool, 0x20) == spellschool then
						return -- don't record
					-- Frost Ward vs Frost Damage
					elseif MAGE_FROST_WARD[spellid] and band(spellschool, 0x10) ~= spellschool then
						-- nothing
					-- Fire Ward vs Fire Damage
					elseif MAGE_FIRE_WARD[spellid] and band(spellschool, 0x04) ~= spellschool then
						-- nothing
					-- Shadow Ward vs Shadow Damage
					elseif WARLOCK_SHADOW_WARD[spellid] and band(spellschool, 0x20) ~= spellschool then
						-- nothing
					-- Anti-Magic, Spell Deflection, Savage Defense
					elseif (spellid == 48707 or spellid == 49497 or spellid == 62606) and band(spellschool, 0x01) == spellschool then
						-- nothing
					else
						local shield = new()
						shield.srcGUID = spell.srcGUID
						shield.srcName = srcName
						shield.srcFlags = spell.srcFlags
						shield.spellid = spellid
						shield.string = spell.string
						shield.points = spell.points
						shield.ts = spell.ts - ABSORB_SPELLS[spellid].dur
						shield.amount = spell.amount
						shield.full = spell.full
						shields_popped[#shields_popped + 1] = shield
					end
				end
			end
		end

		-- the player has no shields, so nothing to do.
		if #shields_popped == 0 then
			-- queued this lost amount for next spell (sadly!)
			queue_amount(dstName, t.absorbed)
			return
		end

		-- if the player has a single shield and it broke, we update its max absorb
		local absorbed = t.absorbed
		if #shields_popped == 1 and broke and shields_popped[1].full and ABSORB_SPELLS[shields_popped[1].spellid].cap then
			local s = shields_popped[1]
			shield_amounts[s.srcName] = shield_amounts[s.srcName] or new()
			local src = shield_amounts[s.srcName]
			if (not src[s.spellid] or src[s.spellid] < absorbed) and absorbed < (ABSORB_SPELLS[s.spellid].cap * zoneModifier) then
				src[s.spellid] = absorbed
			end
		end

		-- we loop through available shields and make sure to update
		-- their maximum absorb values.
		local total = t.amount + t.absorbed
		for i = 1, #shields_popped do
			local s = shields_popped[i]
			if s and s.full and shield_amounts[s.srcName] and shield_amounts[s.srcName][s.spellid] then
				s.amount = shield_amounts[s.srcName][s.spellid]
			elseif s and s.spellid == 52286 and s.points then -- Will of the Necropolis
				local hppercent = UnitHealthInfo(dstName, t.dstGUID)
				s.amount = (hppercent and hppercent <= 36) and floor(total * 0.05 * s.points) or 0
			elseif s and s.spellid == 49497 and s.points then -- Spell Deflection
				s.amount = floor(total * 0.15 * s.points)
			elseif s and s.spellid == 66233 and s.points then -- Ardent Defender
				local hppercent = UnitHealthInfo(dstName, t.dstGUID)
				s.amount = (hppercent and hppercent <= 36) and floor(total * 0.0667 * s.points) or 0
			elseif s and s.spellid == 31230 and s.points then -- Cheat Death
				local _, _, hpmax = UnitHealthInfo(dstName, t.dstGUID)
				s.amount = floor((hpmax or 0) * 0.1)
			elseif s and s.spellid == 25228 then -- Soul Link
				s.amount = floor(total * 0.2)
			elseif s and s.spellid == 62606 then -- Savage Defense
				local base, posBuff, negBuff = UnitAttackPower(t.dstName)
				if base > 0 then -- only works if you're the bear
					s.amount = floor((base + posBuff + negBuff) * 0.25)
				end
			end
		end

		-- sort shields
		tsort(shields_popped, shields_order_pred)

		local prev_shield = nil
		for i = #shields_popped, 0, -1 do
			-- no shield left to check?
			if i == 0 then
				-- if we still have an absorbed amount running and there is
				-- a previous shield, we attributed dumbly to it.
				-- the "true" at the end is so we don't update the spell count or active time.
				if absorbed > 0 and prev_shield then
					absorb.actorid = prev_shield.srcGUID
					absorb.actorname = prev_shield.srcName
					absorb.actorflags = prev_shield.srcFlags
					absorb.dstName = dstName
					absorb.spell = prev_shield.spellid
					absorb.spellid = prev_shield.string
					absorb.amount = unqueue_amount(dstName, absorbed)
					absorb.critical = t.critical

					-- always increment the count of passive shields.
					Skada:DispatchSets(log_absorb, PASSIVE_SHIELDS[prev_shield.spellid] == nil)
				end
				break
			end

			local s = shields_popped[i]
			-- whoops! No shield or ignored?
			if not s or ignored_spells[s.spellid] then break end

			-- we store the previous shield to use later in case of
			-- any missing abosrb amount that wasn't properly added.
			prev_shield = s

			-- if the amount can be handled by the shield itself, we just
			-- attribute it and break, no need to check for more.
			local shield_id = s.spellid
			local _shield = shields[dstName][shield_id]

			absorb.actorid = s.srcGUID
			absorb.actorname = s.srcName
			absorb.actorflags = s.srcFlags
			absorb.dstName = dstName
			absorb.spell = shield_id
			absorb.spellid = s.string
			absorb.critical = t.critical

			if s.amount >= absorbed then
				_shield[s.srcName].amount = s.amount - absorbed
				_shield[s.srcName].full = nil

				absorb.amount = unqueue_amount(dstName, absorbed)
				Skada:DispatchSets(log_absorb)

				break
			end

			-- arriving at this point means that the shield broke,
			-- so we make sure to remove it first, use its max
			-- abosrb value then use the difference for the rest.

			-- if the "points" key exists, we don't remove the shield
			-- because it is a passive one that should be kept.
			if s.points == nil and shield_id ~= 25228 then
				_shield[s.srcName] = del(_shield[s.srcName])
			end

			absorb.amount = unqueue_amount(dstName, s.amount)
			Skada:DispatchSets(log_absorb)
			absorbed = absorbed - s.amount
		end
	end

	local function spell_damage(t)
		local dstName = t.dstName and Skada:FixPetsName(t.dstGUID, t.dstName, t.dstFlags)
		if dstName and shields[dstName] and t.absorbed and t.absorbed > 0 then
			process_absorb(dstName, t, t.amount > t.absorbed)
		end
	end

	local function spell_heal(t)
		local dstName = t.dstName and Skada:FixPetsName(t.dstGUID, t.dstName, t.dstFlags)
		if not dstName then return end

		local heal = heals[dstName] and heals[dstName][t.srcName]
		if not heal then
			heal = new()
			heal.ts = t.timestamp
			heal.amount = t.amount
			-- add it to heals table
			heals[dstName] = heals[dstName] or new()
			heals[dstName][t.srcName] = heal
		else
			heal.ts = t.timestamp
			heal.amount = t.amount
		end
	end

	local function absorb_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(set, true)
		local aps, damage = actor:GetAPS(set)

		local activepercent = activetime / totaltime * 100
		tooltip:AddDoubleLine(format(L["%s's activity"], classfmt(actor.class, label)), Skada:FormatPercent(activepercent), nil, nil, nil, PercentToRGB(activepercent))
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs"], Skada:FormatNumber(damage), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(format(slash_fmt, Skada:FormatNumber(damage), suffix), Skada:FormatNumber(aps), 1, 1, 1)
	end

	local function mode_spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.absorbspells and actor.absorbspells[id]
		if not spell then return end

		tooltip:AddLine(uformat("%s - %s", classfmt(win.actorclass, win.actorname), label))
		tooltip_school(tooltip, id)

		local cast = actor.GetSpellCast and actor:GetSpellCast(id)
		if cast then
			tooltip:AddDoubleLine(L["Casts"], cast, nil, nil, nil, 1, 1, 1)
		end

		if not spell.count or spell.count == 0 then return end

		-- hits and average
		tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
		tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)

		-- normal hits
		if spell.n_num then
			tooltip:AddLine(" ")
			tooltip:AddDoubleLine(L["Normal Hits"], format(hits_perc, Skada:FormatNumber(spell.n_num), Skada:FormatPercent(spell.n_num, spell.count)))
			if spell.n_min then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.n_min), 1, 1, 1)
			end
			if spell.n_max then
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.n_max), 1, 1, 1)
			end
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.n_amt / spell.n_num), 1, 1, 1)
		end

		-- critical hits
		if spell.c_num then
			tooltip:AddLine(" ")
			tooltip:AddDoubleLine(L["Critical Hits"], format(hits_perc, Skada:FormatNumber(spell.c_num), Skada:FormatPercent(spell.c_num, spell.count)))
			if spell.c_min then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.c_min), 1, 1, 1)
			end
			if spell.c_max then
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.c_max), 1, 1, 1)
			end
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.c_amt / spell.c_num), 1, 1, 1)
		end
	end

	function mode_target_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(class, label))
	end

	function mode_target_spell:Update(win, set)
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(win.targetclass, win.targetname))
		if not set or not win.targetname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor or actor.enemy then return end -- unavailable for enemies yet

		local total = actor.absorb
		local spells = (total and total > 0) and actor.absorbspells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sAPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			local amount = spell.targets and spell.targets[win.targetname]
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellid, spell)
				d.value = amount
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = format(L["%s's spells"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor or actor.enemy then return end -- unavailable for enemies yet

		local total = actor.absorb
		local spells = (total and total > 0) and actor.absorbspells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sAPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = spell.amount
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor or actor.enemy then return end -- unavailable for enemies yet

		local total = actor and actor.absorb or 0
		local targets = (total > 0) and actor:GetAbsorbTargets(set)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sAPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, targetname)
			d.value = target.amount
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Absorbs"], L[win.class]) or L["Absorbs"]

		local total = set and set:GetAbsorb(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.absorb then
				local aps, amount = actor:GetAPS(set, nil, not mode_cols.APS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, total, aps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode_spell:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		if not actor or not actor.absorb then return end

		local aps, amount = actor:GetAPS(set, false, not mode_cols.sAPS)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Absorbs and Skada:FormatNumber(amount),
			mode_cols.sAPS and Skada:FormatNumber(aps)
		)
		return amount, valuetext
	end
	mode_target.GetSetSummary = mode_spell.GetSetSummary

	function mode:GetSetSummary(set, win)
		local aps, amount = set:GetAPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Absorbs and Skada:FormatNumber(amount),
			mode_cols.APS and Skada:FormatNumber(aps)
		)
		return amount, valuetext
	end

	do
		local LGT = LibStub("LibGroupTalents-1.0")

		-- some effects aren't shields but rather special effects, such us talents.
		-- in order to track them, we simply add them as fake shields before all.
		-- I don't know the whole list of effects but, if you want to add yours
		-- please do : CLASS = {[spellid] = true}
		-- see: http://wotlk.cavernoftime.com/spell=<spellid>
		local _passive = {
			DEATHKNIGHT = {
				[52286] = true, -- Will of the Necropolis
				[49497] = true -- Spell Deflection
			},
			PALADIN = {
				[66233] = true -- Ardent Defender
			},
			ROGUE = {
				[31230] = true -- Cheat Death
			}
		}

		function mode:UnitBuff(_, args)
			if not args.auras or not args.timestamp then return end
			local curtime = args.Time or Skada._Time

			for _, aura in pairs(args.auras) do
				if ABSORB_SPELLS[aura.id] then
					local t = new()
					t.event = "SPELL_AURA_APPLIED"
					t.timestamp = args.timestamp + max(0, aura.expires - curtime)
					t.srcGUID = aura.srcGUID
					t.srcName = aura.srcName
					t.srcFlags = aura.srcFlags
					t.dstGUID = args.dstGUID
					t.dstName = args.dstName
					t.dstFlags = args.dstFlags
					t.spellid = aura.id
					t.spellstring = format("%s.%s", aura.id, ABSORB_SPELLS[aura.id].school)
					t.__temp = true
					handle_shield(t)
					t = del(t)
				end
			end

			if args.owner then return end

			local spells = args.class and _passive[args.class]
			if not spells then return end

			for spellid, _ in pairs(spells) do
				local points = LGT:GUIDHasTalent(args.dstGUID, spellnames[spellid], LGT:GetActiveTalentGroup(args.unit))
				if points then
					local t = new()
					t.timestamp = args.timestamp - 60
					t.srcGUID = args.dstGUID
					t.srcName = args.dstName
					t.srcFlags = args.dstFlags
					t.dstGUID = args.dstGUID
					t.dstName = args.dstName
					t.dstFlags = args.dstFlags
					t.spellid = spellid
					t.spellstring = format("%s.%s", spellid, ABSORB_SPELLS[spellid].school)
					t.__temp = true
					handle_shield(t, points)
					t = del(t)
				end
			end
		end
	end

	function mode:CombatLeave()
		wipe(absorb)
		clear(heals)
		clear(shields)
		clear(shield_amounts)
		clear(shields_popped)
		self.checked = nil
	end

	function mode:OnEnable()
		mode_spell.metadata = {tooltip = mode_spell_tooltip}
		mode_target.metadata = {showspots = true, click1 = mode_target_spell}
		self.metadata = {
			showspots = true,
			filterclass = true,
			tooltip = absorb_tooltip,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Absorbs = true, APS = true, Percent = true, sAPS = false, sPercent = true},
			icon = [[Interface\ICONS\spell_holy_devineaegis]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		local flags_src = {src_is_interesting = true}

		Skada:RegisterForCL(
			handle_shield,
			flags_src,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_REMOVED"
		)

		Skada:RegisterForCL(
			spell_heal,
			flags_src,
			"SPELL_HEAL",
			"SPELL_PERIODIC_HEAL"
		)

		local flags_dst = {dst_is_interesting = true}

		Skada:RegisterForCL(
			spell_damage,
			flags_dst,
			-- damage events
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			"ENVIRONMENTAL_DAMAGE",
			-- missed events
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED"
		)

		Skada.RegisterCallback(self, "Skada_UnitBuffs", "UnitBuff")
		Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER", "ZoneModifier")
		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mode:ZoneModifier()
		if UnitInBattleground("player") or GetCurrentMapAreaID() == 502 then
			zoneModifier = 1.17
		elseif IsActiveBattlefieldArena() then
			zoneModifier = 0.9
		elseif GetCurrentMapAreaID() == 605 then
			zoneModifier = (UnitBuff("player", spellnames[73822]) or UnitBuff("player", spellnames[73828])) and 1.3 or 1
		else
			zoneModifier = 1
		end
	end

	function mode:AddSetAttributes(set)
		self:ZoneModifier()
	end

	function mode:SetComplete(set)
		-- clean absorbspells table:
		if not set.absorb or set.absorb == 0 then return end
		for _, actor in pairs(set.actors) do
			local amount = actor.absorb
			if (not amount and actor.absorbspells) or amount == 0 then
				actor.absorb = nil
				actor.absorbspells = del(actor.absorbspells, true)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Absorbs and Healing Module

Skada:RegisterModule("Absorbs and Healing", function(L, P)
	local mode = Skada:NewModule("Absorbs and Healing")
	local mode_spell = mode:NewModule("Spell List")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	tooltip_school = tooltip_school or Skada.tooltip_school
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function format_valuetext(d, total, hps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(d.value),
			mode_cols[subview and "sHPS" or "HPS"] and hps and Skada:FormatNumber(hps),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function hps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(set, true)
		local hps, amount = actor:GetAHPS(set)

		local activepercent = activetime / totaltime * 100
		tooltip:AddDoubleLine(format(L["%s's activity"], classfmt(actor.class, label)), Skada:FormatPercent(activepercent), nil, nil, nil, PercentToRGB(activepercent))
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(set:GetTime()), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs and Healing"], Skada:FormatNumber(amount), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(format(slash_fmt, Skada:FormatNumber(amount), suffix), Skada:FormatNumber(hps), 1, 1, 1)
	end

	local function mode_spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local spell = actor.healspells and actor.healspells[id] or actor.absorbspells and actor.absorbspells[id]
		if not spell then return end

		tooltip:AddLine(uformat("%s - %s", classfmt(win.actorclass, win.actorname), label))
		tooltip_school(tooltip, id)

		local cast = actor.GetSpellCast and actor:GetSpellCast(id)
		if cast then
			tooltip:AddDoubleLine(L["Casts"], cast, nil, nil, nil, 1, 1, 1)
		end

		if not spell.count or spell.count == 0 then return end

		-- hits and average
		tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
		tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
		if spell.o_amt and spell.o_amt > 0 then
			tooltip:AddDoubleLine(L["Overheal"], format(hits_perc, Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, spell.amount + spell.o_amt)), 1, 0.67, 0.67)
		end

		-- normal hits
		if spell.n_num then
			tooltip:AddLine(" ")
			tooltip:AddDoubleLine(L["Normal Hits"], format(hits_perc, Skada:FormatNumber(spell.n_num), Skada:FormatPercent(spell.n_num, spell.count)))
			if spell.n_min then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.n_min), 1, 1, 1)
			end
			if spell.n_max then
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.n_max), 1, 1, 1)
			end
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.n_amt / spell.n_num), 1, 1, 1)
		end

		-- critical hits
		if spell.c_num then
			tooltip:AddLine(" ")
			tooltip:AddDoubleLine(L["Critical Hits"], format(hits_perc, Skada:FormatNumber(spell.c_num), Skada:FormatPercent(spell.c_num, spell.count)))
			if spell.c_min then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.c_min), 1, 1, 1)
			end
			if spell.c_max then
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.c_max), 1, 1, 1)
			end
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.c_amt / spell.c_num), 1, 1, 1)
		end
	end

	function mode_target_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(class, label))
	end

	function mode_target_spell:Update(win, set)
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(win.targetclass, win.targetname))
		if not set or not win.targetname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHealOnTarget(win.targetname)

		if not total or total == 0 or not (actor.healspells or actor.absorbspells) then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		local spells = actor.healspells -- heal spells
		if spells then
			for spellid, spell in pairs(spells) do
				local amount = spell.targets and spell.targets[win.targetname]
				amount = amount and (actor.enemy and amount or amount.amount)
				if amount then
					nr = nr + 1

					local d = win:spell(nr, spellid, spell, nil, true)
					d.value = amount
					format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
				end
			end
		end

		spells = actor.absorbspells -- absorb spells
		if not spells then return end

		for spellid, spell in pairs(spells) do
			local amount = spell.targets and spell.targets[win.targetname]
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellid, spell)
				d.value = amount
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = format(L["%s's spells"], classfmt(win.actorclass, win.actorname))
		if not win.actorname then return end

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHeal()

		if not total or total == 0 or not (actor.healspells or actor.absorbspells) then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		local spells = actor.healspells -- heal spells
		if spells then
			for spellid, spell in pairs(spells) do
				nr = nr + 1

				local d = win:spell(nr, spellid, spell, nil, true)
				d.value = spell.amount
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end

		spells = actor.absorbspells -- absorb spells
		if not spells then return end

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = spell.amount
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHeal()
		local targets = (total and total > 0) and actor:GetAbsorbHealTargets(set)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sAPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			if target.amount > 0 then
				nr = nr + 1

				local d = win:actor(nr, target, target.enemy, targetname)
				d.value = target.amount
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Absorbs and Healing"], L[win.class]) or L["Absorbs and Healing"]

		local total = set and set:GetAbsorbHeal(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and (actor.absorb or actor.heal) then
				local hps, amount = actor:GetAHPS(set, nil, not mode_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, total, hps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode_spell:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local hps, amount = actor:GetAHPS(set, false, not mode_cols.sHPS)
		if amount <= 0 then return end

		local valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(amount),
			mode_cols.sHPS and Skada:FormatNumber(hps)
		)
		return amount, valuetext
	end
	mode_target.GetSetSummary = mode_spell.GetSetSummary

	function mode:GetSetSummary(set, win)
		if not set then return end
		local hps, amount = set:GetAHPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(amount),
			mode_cols.HPS and Skada:FormatNumber(hps)
		)
		return amount, valuetext
	end

	function mode:AddToTooltip(set, tooltip)
		if not set then return end
		local hps, amount = set:GetAHPS()
		if amount > 0 then
			tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(amount), 1, 1, 1)
			tooltip:AddDoubleLine(L["HPS"], Skada:FormatNumber(hps), 1, 1, 1)
		end
		if set.overheal and set.overheal > 0 then
			amount = amount + set.overheal
			tooltip:AddDoubleLine(L["Overheal"], Skada:FormatPercent(set.overheal, amount), 1, 1, 1)
		end
	end

	local function feed_personal_hps()
		local set = Skada:GetSet("current")
		local actor = set and set:GetActor(Skada.userName, Skada.userGUID)
		if actor then
			return format("%s %s", Skada:FormatNumber((actor:GetAHPS(set))), L["HPS"])
		end
	end

	local function feed_raid_hps()
		local set = Skada:GetSet("current")
		return format("%s %s", Skada:FormatNumber(set and set:GetAHPS() or 0), L["RHPS"])
	end

	function mode:OnEnable()
		mode_spell.metadata = {tooltip = mode_spell_tooltip}
		mode_target.metadata = {showspots = true, click1 = mode_target_spell}
		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		Skada:AddFeed(L["Healing: Personal HPS"], feed_personal_hps)
		Skada:AddFeed(L["Healing: Raid HPS"], feed_raid_hps)

		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada:RemoveFeed(L["Healing: Personal HPS"])
		Skada:RemoveFeed(L["Healing: Raid HPS"])
		Skada:RemoveMode(self)
	end

	function mode:OnInitialize()
		self.metadata = {
			showspots = true,
			filterclass = true,
			tooltip = hps_tooltip,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\ICONS\spell_holy_healingfocus]]
		}
	end
end, "Absorbs", "Healing")

---------------------------------------------------------------------------
-- HPS Module

Skada:RegisterModule("HPS", function(L, P)
	local mode = Skada:NewModule("HPS")
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function format_valuetext(d, total, metadata)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.HPS and Skada:FormatNumber(d.value),
			mode_cols.Percent and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function hps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(set, true)
		local hps, amount = actor:GetAHPS(set)

		tooltip:AddLine(uformat(L["%s's activity"], classfmt(actor.class, label), L["HPS"]))
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(set:GetTime()), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs and Healing"], Skada:FormatNumber(amount), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(format(slash_fmt, Skada:FormatNumber(amount), suffix), Skada:FormatNumber(hps), 1, 1, 1)
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["HPS"], L[win.class]) or L["HPS"]

		local total = set and set:GetAHPS(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and (actor.absorb or actor.heal) then
				local amount = actor:GetAHPS(set, nil, not mode_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, total, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode:GetSetSummary(set, win)
		local value =  set:GetAHPS(win and win.class)
		return value, Skada:FormatNumber(value)
	end

	function mode:OnEnable()
		self.metadata = {
			showspots = true,
			filterclass = true,
			tooltip = hps_tooltip,
			columns = {HPS = true, Percent = true},
			icon = [[Interface\ICONS\spell_nature_rejuvenation]]
		}

		mode_cols = self.metadata.columns

		local parent = Skada:GetModule("Absorbs and Healing", true)
		if parent and parent.metadata then
			self.metadata.click1 = parent.metadata.click1
			self.metadata.click2 = parent.metadata.click2
		end

		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Absorbs", "Healing", "Absorbs and Healing")

---------------------------------------------------------------------------
-- Healing Done By Spell

Skada:RegisterModule("Healing Done By Spell", function(L, _, _, C)
	local mode = Skada:NewModule("Healing Done By Spell")
	local mode_source = mode:NewModule("Source List")
	local classfmt = Skada.classcolors.format
	local clear = Private.clearTable
	local get_absorb_heal_spells = nil
	local mode_cols = nil

	local function format_valuetext(d, total, hps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(d.value),
			mode_cols[subview and "sHPS" or "HPS"] and Skada:FormatNumber(hps),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function mode_source_tooltip(win, id, label, tooltip)
		local set = win.spellname and win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local spell = actor.healspells and actor.healspells[win.spellid]
		spell = spell or actor.absorbspells and actor.absorbspells[win.spellid]
		if not spell then return end

		tooltip:AddLine(uformat("%s - %s", classfmt(actor.class, label), win.spellname))

		local cast = actor.GetSpellCast and actor:GetSpellCast(win.spellid)
		if cast then
			tooltip:AddDoubleLine(L["Casts"], cast, nil, nil, nil, 1, 1, 1)
		end

		if spell.count then
			tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)

			if spell.c_num then
				tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.c_num, spell.count), 1, 1, 1)
			end

			if spell.min and spell.max then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
			end
		end

		if spell.o_amt then
			tooltip:AddDoubleLine(L["Overheal"], format("%s (%s)", Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, spell.amount + spell.o_amt)), nil, nil, nil, 1, 0.67, 0.67)
		end
	end

	function mode_source:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's sources"], label)
	end

	function mode_source:Update(win, set)
		win.title = uformat(L["%s's sources"], win.spellname)
		if not (win.spellid and set) then return end

		-- let's go...
		local total = 0
		local overheal = 0
		local sources = clear(C)

		local actors = set.actors
		for actorname, actor in pairs(actors) do
			if not actor.enemy and (actor.absorbspells or actor.healspells) then
				local spell = actor.absorbspells and actor.absorbspells[win.spellid]
				spell = spell or actor.healspells and actor.healspells[win.spellid]
				if spell and spell.amount then
					sources[actorname] = new()
					sources[actorname].id = actor.id
					sources[actorname].class = actor.class
					sources[actorname].role = actor.role
					sources[actorname].spec = actor.spec
					sources[actorname].enemy = actor.enemy
					sources[actorname].amount = spell.amount
					sources[actorname].time = mode.metadata.columns.sHPS and actor:GetTime(set)
					-- calculate the total.
					total = total + spell.amount
					if spell.o_amt then
						overheal = overheal + spell.o_amt
					end
				end
			end
		end

		if total == 0 and overheal == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for sourcename, source in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, source, source.enemy, sourcename)
			d.value = source.amount
			format_valuetext(d, total, source.time and (d.value / source.time), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = L["Healing Done By Spell"]
		local total = set and set:GetAbsorbHeal()
		local spells = (total and total > 0) and get_absorb_heal_spells(set)

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local settime = mode_cols.HPS and set:GetTime()

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell, nil, true)
			d.value = spell.amount
			format_valuetext(d, total, settime and (d.value / settime), win.metadata)
		end
	end

	function mode:OnEnable()
		mode_source.metadata = {showspots = true, tooltip = mode_source_tooltip}
		self.metadata = {
			click1 = mode_source,
			columns = {Healing = true, HPS = false, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\ICONS\spell_nature_healingwavelesser]]
		}
		mode_cols = self.metadata.columns
		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	local function fill_spells_table(t, spellid, info)
		if not info or not (info.amount or info.o_amt) then return end

		local spell = t[spellid]
		if not spell then
			spell = new()
			-- common
			spell.amount = info.amount

			-- for heals
			spell.o_amt = info.o_amt

			t[spellid] = spell
		else
			spell.amount = spell.amount + info.amount
			if info.o_amt then -- for heals
				spell.o_amt = (spell.o_amt or 0) + info.o_amt
			end
		end
	end

	get_absorb_heal_spells = function(self, tbl)
		if not self.actors or not (self.absorb or self.heal) then return end

		tbl = clear(tbl or C)
		for _, actor in pairs(self.actors) do
			if actor.healspells then
				for spellid, spell in pairs(actor.healspells) do
					fill_spells_table(tbl, spellid, spell)
				end
			end
			if actor.absorbspells then
				for spellid, spell in pairs(actor.absorbspells) do
					fill_spells_table(tbl, spellid, spell)
				end
			end
		end
		return tbl
	end
end, "Absorbs", "Healing")
