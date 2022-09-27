local _, Skada = ...
local private = Skada.private

-- cache frequently used globals
local pairs, format, pformat = pairs, string.format, Skada.pformat
local min, floor, new = math.min, math.floor, Skada.newTable
local GetSpellInfo = private.spell_info or GetSpellInfo

-- ============== --
-- Absorbs module --
-- ============== --

Skada:RegisterModule("Absorbs", function(L, P)
	local mod = Skada:NewModule("Absorbs")
	local playermod = mod:NewModule("Absorb spell list")
	local targetmod = mod:NewModule("Absorbed target list")
	local spellmod = targetmod:NewModule("Absorb spell list")
	local spellschools = Skada.spellschools
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local passiveSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	local GetTime, band, tsort, max = GetTime, bit.band, table.sort, math.max
	local GroupIterator, GetCurrentMapAreaID = Skada.GroupIterator,GetCurrentMapAreaID
	local UnitGUID, UnitName, UnitClass, UnitExists, UnitBuff = UnitGUID, UnitName, UnitClass, UnitExists, UnitBuff
	local UnitIsDeadOrGhost, UnitHealthInfo = UnitIsDeadOrGhost, Skada.UnitHealthInfo
	local IsActiveBattlefieldArena, UnitInBattleground = IsActiveBattlefieldArena, UnitInBattleground
	local T, del = Skada.Table, Skada.delTable
	local mod_cols = nil

	-- INCOMPLETE
	-- the following list is incomplete due to the lack of testing for different
	-- shield ranks. Feel free to provide any helpful data possible to complete it.
	-- Note: some of the caps are used as backup because their amounts are calculated later.
	local absorbspells = {
		[48707] = {dur = 5}, -- Anti-Magic Shell (rank 1)
		[51052] = {dur = 10}, -- Anti-Magic Zone( (rank 1)
		[50150] = {dur = 86400, school = 0x01}, -- Will of the Necropolis
		[49497] = {dur = 86400, school = 0x01}, -- Spell Deflection
		[62606] = {dur = 10, avg = 1600, cap = 2500}, -- Savage Defense
		[11426] = {dur = 60}, -- Ice Barrier (rank 1)
		[13031] = {dur = 60}, -- Ice Barrier (rank 2)
		[13032] = {dur = 60}, -- Ice Barrier (rank 3)
		[13033] = {dur = 60}, -- Ice Barrier (rank 4)
		[27134] = {dur = 60}, -- Ice Barrier (rank 5)
		[33405] = {dur = 60}, -- Ice Barrier (rank 6)
		[43038] = {dur = 60}, -- Ice Barrier (rank 7)
		[43039] = {dur = 60, avg = 6500, cap = 8300}, -- Ice Barrier (rank 8)
		[6143] = {dur = 30}, -- Frost Ward (rank 1)
		[8461] = {dur = 30}, -- Frost Ward (rank 2)
		[8462] = {dur = 30}, -- Frost Ward (rank 3)
		[10177] = {dur = 30}, -- Frost Ward (rank 4)
		[28609] = {dur = 30}, -- Frost Ward (rank 5)
		[32796] = {dur = 30}, -- Frost Ward (rank 6)
		[43012] = {dur = 30, avg = 5200, cap = 7000}, -- Frost Ward (rank 7)
		[1463] = {dur = 60}, -- Mana shield (rank 1)
		[8494] = {dur = 60}, -- Mana shield (rank 2)
		[8495] = {dur = 60}, -- Mana shield (rank 3)
		[10191] = {dur = 60}, -- Mana shield (rank 4)
		[10192] = {dur = 60}, -- Mana shield (rank 5)
		[10193] = {dur = 60}, -- Mana shield (rank 6)
		[27131] = {dur = 60}, -- Mana shield (rank 7)
		[43019] = {dur = 60}, -- Mana shield (rank 8)
		[43020] = {dur = 60, avg = 4500, cap = 6300}, -- Mana shield (rank 9)
		[543] = {dur = 30}, -- Fire Ward (rank 1)
		[8457] = {dur = 30}, -- Fire Ward (rank 2)
		[8458] = {dur = 30}, -- Fire Ward (rank 3)
		[10223] = {dur = 30}, -- Fire Ward (rank 4)
		[10225] = {dur = 30}, -- Fire Ward (rank 5)
		[27128] = {dur = 30}, -- Fire Ward (rank 6)
		[43010] = {dur = 30, avg = 5200, cap = 7000}, -- Fire Ward (rank 7)
		[58597] = {dur = 6, avg = 4400, cap = 6000}, -- Sacred Shield
		[66233] = {dur = 86400, school = 0x02}, -- Ardent Defender
		[31230] = {dur = 86400, school = 0x01}, -- Cheat Death
		[17] = {dur = 30, school = 0x02}, -- Power Word: Shield (rank 1)
		[592] = {dur = 30, school = 0x02}, -- Power Word: Shield (rank 2)
		[600] = {dur = 30, school = 0x02}, -- Power Word: Shield (rank 3)
		[3747] = {dur = 30, school = 0x02}, -- Power Word: Shield (rank 4)
		[6065] = {dur = 30, school = 0x02}, -- Power Word: Shield (rank 5)
		[6066] = {dur = 30, school = 0x02}, -- Power Word: Shield (rank 6)
		[10898] = {dur = 30, avg = 721, cap = 848, school = 0x02}, -- Power Word: Shield (rank 7)
		[10899] = {dur = 30, avg = 898, cap = 1057, school = 0x02}, -- Power Word: Shield (rank 8)
		[10900] = {dur = 30, avg = 1543, cap = 1816, school = 0x02}, -- Power Word: Shield (rank 9)
		[10901] = {dur = 30, avg = 3643, cap = 4288, school = 0x02}, -- Power Word: Shield (rank 10)
		[25217] = {dur = 30, avg = 5436, cap = 6398, school = 0x02}, -- Power Word: Shield (rank 11)
		[25218] = {dur = 30, avg = 7175, cap = 8444, school = 0x02}, -- Power Word: Shield (rank 12)
		[48065] = {dur = 30, avg = 9596, cap = 11293, school = 0x02}, -- Power Word: Shield (rank 13)
		[48066] = {dur = 30, avg = 10000, cap = 11769, school = 0x02}, -- Power Word: Shield (rank 14)
		[47509] = {dur = 12}, -- Divine Aegis (rank 1)
		[47511] = {dur = 12}, -- Divine Aegis (rank 2)
		[47515] = {dur = 12}, -- Divine Aegis (rank 3)
		[47753] = {dur = 12, cap = 10000}, -- Divine Aegis (rank 1)
		[54704] = {dur = 12, cap = 10000}, -- Divine Aegis (rank 1)
		[47788] = {dur = 10}, -- Guardian Spirit
		[7812] = {dur = 30, cap = 305}, -- Sacrifice (rank 1)
		[19438] = {dur = 30, cap = 510}, -- Sacrifice (rank 2)
		[19440] = {dur = 30, cap = 770}, -- Sacrifice (rank 3)
		[19441] = {dur = 30, cap = 1095}, -- Sacrifice (rank 4)
		[19442] = {dur = 30, cap = 1470}, -- Sacrifice (rank 5)
		[19443] = {dur = 30, cap = 1905}, -- Sacrifice (rank 6)
		[27273] = {dur = 30, cap = 2855}, -- Sacrifice (rank 7)
		[47985] = {dur = 30, cap = 6750}, -- Sacrifice (rank 8)
		[47986] = {dur = 30, cap = 8350}, -- Sacrifice (rank 9)
		[6229] = {dur = 30, cap = 290}, -- Shadow Ward (rank 1)
		[11739] = {dur = 30, cap = 470}, -- Shadow Ward (rank 2)
		[11740] = {dur = 30, avg = 675}, -- Shadow Ward (rank 3)
		[28610] = {dur = 30, avg = 875}, -- Shadow Ward (rank 4)
		[47890] = {dur = 30, avg = 2750}, -- Shadow Ward (rank 5)
		[47891] = {dur = 30, avg = 3300, cap = 8300}, -- Shadow Ward (rank 6)
		[25228] = {dur = 86400, school = 0x20}, -- Soul Link
		[29674] = {dur = 86400, cap = 1000}, -- Lesser Ward of Shielding
		[29719] = {dur = 86400, cap = 4000}, -- Greater Ward of Shielding
		[29701] = {dur = 86400, cap = 4000}, -- Greater Shielding
		[28538] = {dur = 120, avg = 3400, cap = 4000}, -- Major Holy Protection Potion
		[28537] = {dur = 120, avg = 3400, cap = 4000}, -- Major Shadow Protection Potion
		[28536] = {dur = 120, avg = 3400, cap = 4000}, -- Major Arcane Protection Potion
		[28513] = {dur = 120, avg = 3400, cap = 4000}, -- Major Nature Protection Potion
		[28512] = {dur = 120, avg = 3400, cap = 4000}, -- Major Frost Protection Potion
		[28511] = {dur = 120, avg = 3400, cap = 4000}, -- Major Fire Protection Potion
		[7233] = {dur = 120, avg = 1300, cap = 1625}, -- Fire Protection Potion
		[7239] = {dur = 120, avg = 1800, cap = 2250}, -- Frost Protection Potion
		[7242] = {dur = 120, avg = 1800, cap = 2250}, -- Shadow Protection Potion
		[7245] = {dur = 120, avg = 1800, cap = 2250}, -- Holy Protection Potion
		[7254] = {dur = 120, avg = 1800, cap = 2250}, -- Nature Protection Potion
		[53915] = {dur = 120, avg = 5100, cap = 6000}, -- Mighty Shadow Protection Potion
		[53914] = {dur = 120, avg = 5100, cap = 6000}, -- Mighty Nature Protection Potion
		[53913] = {dur = 120, avg = 5100, cap = 6000}, -- Mighty Frost Protection Potion
		[53911] = {dur = 120, avg = 5100, cap = 6000}, -- Mighty Fire Protection Potion
		[53910] = {dur = 120, avg = 5100, cap = 6000}, -- Mighty Arcane Protection Potion
		[17548] = {dur = 120, avg = 2600, cap = 3250}, -- Greater Shadow Protection Potion
		[17546] = {dur = 120, avg = 2600, cap = 3250}, -- Greater Nature Protection Potion
		[17545] = {dur = 120, avg = 2600, cap = 3250}, -- Greater Holy Protection Potion
		[17544] = {dur = 120, avg = 2600, cap = 3250}, -- Greater Frost Protection Potion
		[17543] = {dur = 120, avg = 2600, cap = 3250}, -- Greater Fire Protection Potion
		[17549] = {dur = 120, avg = 2600, cap = 3250}, -- Greater Arcane Protection Potion
		[28527] = {dur = 15, avg = 1000, cap = 1250}, -- Fel Blossom
		[29432] = {dur = 3600, avg = 2000, cap = 2500}, -- Frozen Rune
		[36481] = {dur = 4, cap = 100000}, -- Arcane Barrier (TK Kael'Thas) Shield
		[17252] = {dur = 1800, cap = 500}, -- Mark of the Dragon Lord (LBRS epic ring)
		[25750] = {dur = 15, avg = 151, cap = 302}, -- Defiler's Talisman/Talisman of Arathor
		[25747] = {dur = 15, avg = 344, cap = 378}, -- Defiler's Talisman/Talisman of Arathor
		[25746] = {dur = 15, avg = 435, cap = 478}, -- Defiler's Talisman/Talisman of Arathor
		[23991] = {dur = 15, avg = 550, cap = 605}, -- Defiler's Talisman/Talisman of Arathor
		[30997] = {dur = 300, avg = 1800, cap = 2700}, -- Pendant of Frozen Flame
		[31002] = {dur = 300, avg = 1800, cap = 2700}, -- Pendant of the Null Rune
		[30999] = {dur = 300, avg = 1800, cap = 2700}, -- Pendant of Withering
		[30994] = {dur = 300, avg = 1800, cap = 2700}, -- Pendant of Thawing
		[31000] = {dur = 300, avg = 1800, cap = 2700}, -- Pendant of Shadow's End
		[23506] = {dur = 20, avg = 1000, cap = 1250}, -- Arena Grand Master
		[12561] = {dur = 60, avg = 400, cap = 500}, -- Goblin Construction Helmet
		[31771] = {dur = 20, cap = 440}, -- Runed Fungalcap
		[21956] = {dur = 10, cap = 500}, -- Mark of Resolution
		[29506] = {dur = 20, cap = 900}, -- The Burrower's Shell
		[4057] = {dur = 60, cap = 500}, -- Flame Deflector
		[4077] = {dur = 60, cap = 600}, -- Ice Deflector
		[39228] = {dur = 20, cap = 1150}, -- Argussian Compass (may not be an actual absorb)
		[27779] = {dur = 30, cap = 350}, -- Divine Protection (Priest dungeon set 1/2)
		[11657] = {dur = 20, avg = 70, cap = 85}, -- Jang'thraze (Zul Farrak)
		[10368] = {dur = 15, cap = 200}, -- Uther's Light Effect
		[37515] = {dur = 15, cap = 200}, -- Blade Turning
		[42137] = {dur = 86400, cap = 400}, -- Greater Rune of Warding
		[26467] = {dur = 30, cap = 1000}, -- Scarab Brooch
		[26470] = {dur = 8, cap = 1000}, -- Persistent Shield
		[27539] = {dur = 6, avg = 300, cap = 500}, -- Thick Obsidian Breatplate
		[28810] = {dur = 30, cap = 500}, -- Faith Set Proc Armor of Faith
		[55019] = {dur = 12, cap = 1100}, -- Sonic Shield
		[64413] = {dur = 8, cap = 20000}, -- Val'anyr, Hammer of Ancient Kings Protection of Ancient Kings
		[40322] = {dur = 30, avg = 12000, cap = 12600}, -- Teron's Vengeful Spirit Ghost - Spirit Shield
		[71586] = {dur = 10, cap = 6400}, -- Hardened Skin (Corroded Skeleton Key)
		[60218] = {dur = 10, avg = 140, cap = 4000}, -- Essence of Gossamer
		[57350] = {dur = 6, cap = 1500}, -- Illusionary Barrier (Darkmoon Card: Illusion)
		[70845] = {dur = 10}, -- Stoicism
		[65874] = {dur = 15, cap = 175000}, -- Twin Val'kyr's: Shield of Darkness
		[67257] = {dur = 15, cap = 300000}, -- Twin Val'kyr's: Shield of Darkness
		[67256] = {dur = 15, cap = 700000}, -- Twin Val'kyr's: Shield of Darkness
		[67258] = {dur = 15, cap = 1200000}, -- Twin Val'kyr's: Shield of Darkness
		[65858] = {dur = 15, cap = 175000}, -- Twin Val'kyr's: Shield of Lights
		[67260] = {dur = 15, cap = 300000}, -- Twin Val'kyr's: Shield of Lights
		[67259] = {dur = 15, cap = 700000}, -- Twin Val'kyr's: Shield of Lights
		[67261] = {dur = 15, cap = 1200000}, -- Twin Val'kyr's: Shield of Lights
		[65686] = {dur = 86400, cap = 1000000}, -- Twin Val'kyr: Light Essence
		[65684] = {dur = 86400, cap = 1000000} -- Twin Val'kyr: Dark Essence
	}

	local priest_divine_aegis = { -- Divine Aegis
		[47509] = true,
		[47511] = true,
		[47515] = true,
		[47753] = true,
		[54704] = true
	}
	local mage_frost_ward = { -- Frost Ward
		[6143] = true,
		[8461] = true,
		[8462] = true,
		[10177] = true,
		[28609] = true,
		[32796] = true,
		[43012] = true
	}
	local mage_fire_ward = { -- Fire Ward
		[543] = true,
		[8457] = true,
		[8458] = true,
		[10223] = true,
		[10225] = true,
		[27128] = true,
		[43010] = true
	}
	local mage_ice_barrier = { -- Ice Barrier
		[11426] = true,
		[13031] = true,
		[13032] = true,
		[13033] = true,
		[27134] = true,
		[33405] = true,
		[43038] = true,
		[43039] = true
	}
	local warlock_shadow_ward = { -- Shadow Ward
		[6229] = true,
		[11739] = true,
		[11740] = true,
		[28610] = true,
		[47890] = true,
		[47891] = true
	}
	local warlock_sacrifice = { -- Sacrifice
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

	-- spells iof which we don't record casts.
	local passiveShields = {
		[31230] = true, -- Cheat Death
		[49497] = true, -- Spell Deflection
		[50150] = true, -- Will of the Necropolis
		[66233] = true, -- Ardent Defender
	}

	local zoneModifier = 1 -- coefficient used to calculate amounts
	local heals = nil -- holds heal amounts used to "guess" shield amounts
	local shields = nil -- holds the list of players shields and other stuff
	local shieldamounts = nil -- holds the amount shields absorbed so far
	local shieldspopped = nil -- holds the list of shields that popped on a player
	local absorb = {}

	local function format_valuetext(d, columns, total, aps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Absorbs and Skada:FormatNumber(d.value),
			columns[subview and "sAPS" or "APS"] and aps and Skada:FormatNumber(aps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_spellcast(set, playerid, playername, playerflags, spellid, spellschool)
		if not set or (set == Skada.total and not P.totalidc) then return end

		local player = Skada:FindPlayer(set, playerid, playername, playerflags)
		if player and player.absorbspells and player.absorbspells[spellid] then
			player.absorbspells[spellid].casts = (player.absorbspells[spellid].casts or 1) + 1

			-- fix possible missing spell school.
			if not player.absorbspells[spellid].school and spellschool then
				player.absorbspells[spellid].school = spellschool
			end
		end
	end

	local function log_absorb(set, nocount)
		if not absorb.spellid or not absorb.amount or absorb.amount == 0 then return end

		local player = Skada:GetPlayer(set, absorb.playerid, absorb.playername)
		if not player then
			return
		elseif player.role ~= "DAMAGER" and not passiveSpells[absorb.spellid] and not nocount then
			Skada:AddActiveTime(set, player, absorb.dstName)
		end

		-- add absorbs amount
		player.absorb = (player.absorb or 0) + absorb.amount
		set.absorb = (set.absorb or 0) + absorb.amount

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- record the spell
		local spell = player.absorbspells and player.absorbspells[absorb.spellid]
		if not spell then
			player.absorbspells = player.absorbspells or {}
			spell = {school = absorb.school, amount = absorb.amount, count = 1}
			player.absorbspells[absorb.spellid] = spell
		else
			if not spell.school and absorb.school then
				spell.school = absorb.school
			end
			spell.amount = (spell.amount or 0) + absorb.amount
			if not nocount then
				spell.count = (spell.count or 0) + 1
			end
		end

		-- start cast counter.
		if not spell.casts and not passiveShields[absorb.spellid] then
			spell.casts = 1
		end

		if not spell.min or absorb.amount < spell.min then
			spell.min = absorb.amount
		end
		if not spell.max or absorb.amount > spell.max then
			spell.max = absorb.amount
		end

		-- record the target
		if absorb.dstName then
			spell.targets = spell.targets or {}
			spell.targets[absorb.dstName] = (spell.targets[absorb.dstName] or 0) + absorb.amount
		end
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
		if mage_frost_ward[a_spellid] then
			return false
		end
		if mage_frost_ward[b_spellid] then
			return true
		end

		-- Fire Ward
		if mage_fire_ward[a_spellid] then
			return false
		end
		if mage_fire_ward[b_spellid] then
			return true
		end

		-- Shadow Ward
		if warlock_shadow_ward[a_spellid] then
			return false
		end
		if warlock_shadow_ward[b_spellid] then
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
		if priest_divine_aegis[a_spellid] then
			return false
		end
		if priest_divine_aegis[b_spellid] then
			return true
		end

		-- Ice Barrier
		if mage_ice_barrier[a_spellid] then
			return false
		end
		if mage_ice_barrier[b_spellid] then
			return true
		end

		-- Sacrifice
		if warlock_sacrifice[a_spellid] then
			return false
		end
		if warlock_sacrifice[b_spellid] then
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
		if a_spellid == 50150 then
			return false
		end
		if b_spellid == 50150 then
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

	local function handle_shield(timestamp, eventtype, srcGUID, srcName, srcFlags, _, dstName, _, spellid, _, spellschool, _, points)
		if not spellid or not absorbspells[spellid] or not dstName or ignoredSpells[spellid] then return end

		shields = shields or T.get("Skada_Shields") -- create table if missing

		-- shield removed?
		if eventtype == "SPELL_AURA_REMOVED" then
			if shields[dstName] and shields[dstName][spellid] and shields[dstName][spellid][srcName] then
				shields[dstName][spellid][srcName].ts = timestamp + 0.1
			end
			return
		end

		-- shield applied
		shields[dstName] = shields[dstName] or {}
		shields[dstName][spellid] = shields[dstName][spellid] or {}

		-- Soul Link
		if spellid == 25228 then
			srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)
		end

		-- fix spellschool (if possible)
		spellschool = spellschool or absorbspells[spellid].school

		-- log spell casts.
		if not passiveShields[spellid] then
			Skada:DispatchSets(log_spellcast, srcGUID, srcName, srcFlags, spellid, spellschool)
		end

		-- we calculate how much the shield's maximum absorb amount
		local amount = 0

		-- Stackable Shields
		if (priest_divine_aegis[spellid] or spellid == 64413) then
			if shields[dstName][spellid][srcName] and timestamp < shields[dstName][spellid][srcName].ts then
				amount = shields[dstName][spellid][srcName].amount
			end
		end

		if priest_divine_aegis[spellid] then -- Divine Aegis
			if heals and heals[dstName] and heals[dstName][srcName] and heals[dstName][srcName].ts > timestamp - 0.2 then
				amount = min((UnitLevel(srcName) or 80) * 125, amount + (heals[dstName][srcName].amount * 0.3 * zoneModifier))
			end
		elseif spellid == 64413 then -- Protection of Ancient Kings (Vala'nyr)
			if heals and heals[dstName] and heals[dstName][srcName] and heals[dstName][srcName].ts > timestamp - 0.2 then
				amount = min(20000, amount + (heals[dstName][srcName].amount * 0.15))
			end
		elseif (spellid == 48707 or spellid == 51052) and UnitHealthMax(dstName) then -- Anti-Magic Shell/Zone
			amount = UnitHealthMax(dstName) * 0.5
		elseif spellid == 70845 and UnitHealthMax(dstName) then -- Stoicism
			amount = UnitHealthMax(dstName) * 0.2
		elseif absorbspells[spellid].cap or absorbspells[spellid].avg then
			if shieldamounts and shieldamounts[srcName] and shieldamounts[srcName][spellid] then
				local shield = shields[dstName][spellid][srcName]
				if not shield then
					shields[dstName][spellid][srcName] = {
						srcGUID = srcGUID,
						srcFlags = srcFlags,
						school = spellschool,
						points = points,
					}
					shield = shields[dstName][spellid][srcName]
				end

				shield.amount = shieldamounts[srcName][spellid]
				shield.ts = timestamp + absorbspells[spellid].dur + 0.1
				shield.full = true

				-- fix things
				if not shield.school and spellschool then
					shield.school = spellschool
				end
				if not shield.points and points then
					shield.points = points
				end

				return
			else
				amount = (absorbspells[spellid].avg or absorbspells[spellid].cap or 1000) * zoneModifier
			end
		else
			amount = 1000 * zoneModifier -- default
		end

		local shield = shields[dstName][spellid][srcName]
		if not shield then
			shields[dstName][spellid][srcName] = {
				srcGUID = srcGUID,
				srcFlags = srcFlags,
				school = spellschool,
				points = points,
			}
			shield = shields[dstName][spellid][srcName]
		end

		shield.amount = floor(amount)
		shield.ts = timestamp + absorbspells[spellid].dur + 0.1
		shield.full = true

		-- fix things
		if not shield.school and spellschool then
			shield.school = spellschool
		end
		if not shield.points and points then
			shield.points = points
		end
	end

	local function process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool, damage, broke)
		shields[dstName] = shields[dstName] or {}
		shieldspopped = T.clear(shieldspopped or T.get("Skada_ShieldsPopped"), del)

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
					elseif mage_frost_ward[spellid] and band(spellschool, 0x10) ~= spellschool then
						-- nothing
					-- Fire Ward vs Fire Damage
					elseif mage_fire_ward[spellid] and band(spellschool, 0x04) ~= spellschool then
						-- nothing
					-- Shadow Ward vs Shadow Damage
					elseif warlock_shadow_ward[spellid] and band(spellschool, 0x20) ~= spellschool then
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
						shield.school = spell.school
						shield.points = spell.points
						shield.ts = spell.ts - absorbspells[spellid].dur
						shield.amount = spell.amount
						shield.full = spell.full
						shieldspopped[#shieldspopped + 1] = shield
					end
				end
			end
		end

		-- the player has no shields, so nothing to do.
		if #shieldspopped == 0 then return end

		-- if the player has a single shield and it broke, we update its max absorb
		if #shieldspopped == 1 and broke and shieldspopped[1].full and absorbspells[shieldspopped[1].spellid].cap then
			local s = shieldspopped[1]
			shieldamounts = shieldamounts or T.get("Skada_ShieldAmounts") -- create table if missing
			shieldamounts[s.srcName] = shieldamounts[s.srcName] or {}
			local src = shieldamounts[s.srcName]
			if (not src[s.spellid] or src[s.spellid] < absorbed) and absorbed < (absorbspells[s.spellid].cap * zoneModifier) then
				src[s.spellid] = absorbed
			end
		end

		-- we loop through available shields and make sure to update
		-- their maximum absorb values.
		for i = 1, #shieldspopped do
			local s = shieldspopped[i]
			if s and s.full and shieldamounts and shieldamounts[s.srcName] and shieldamounts[s.srcName][s.spellid] then
				s.amount = shieldamounts[s.srcName][s.spellid]
			elseif s and s.spellid == 50150 and s.points then -- Will of the Necropolis
				local hppercent = UnitHealthInfo(dstName, dstGUID)
				s.amount = (hppercent and hppercent <= 36) and floor((damage + absorbed) * 0.05 * s.points) or 0
			elseif s and s.spellid == 49497 and s.points then -- Spell Deflection
				s.amount = floor((damage + absorbed) * 0.15 * s.points)
			elseif s and s.spellid == 66233 and s.points then -- Ardent Defender
				local hppercent = UnitHealthInfo(dstName, dstGUID)
				s.amount = (hppercent and hppercent <= 36) and floor((damage + absorbed) * 0.0667 * s.points) or 0
			elseif s and s.spellid == 31230 and s.points then -- Cheat Death
				local _, _, hpmax = UnitHealthInfo(dstName, dstGUID)
				s.amount = floor((hpmax or 0) * 0.1)
			elseif s and s.spellid == 25228 then -- Soul Link
				s.amount = floor((absorbed + damage) * 0.2)
			end
		end

		-- sort shields
		tsort(shieldspopped, shields_order_pred)

		local pshield = nil
		for i = #shieldspopped, 0, -1 do
			-- no shield left to check?
			if i == 0 then
				-- if we still have an absorbed amount running and there is
				-- a previous shield, we attributed dumbly to it.
				-- the "true" at the end is so we don't update the spell count or active time.
				if absorbed > 0 and pshield then
					absorb.playerid = pshield.srcGUID
					absorb.playername = pshield.srcName
					absorb.playerflags = pshield.srcFlags

					absorb.dstGUID = dstGUID
					absorb.dstName = dstName
					absorb.dstFlags = dstFlags

					absorb.spellid = pshield.spellid
					absorb.school = pshield.school
					absorb.amount = absorbed

					-- always increment the count of passive shields.
					Skada:DispatchSets(log_absorb, passiveShields[absorb.spellid] == nil)
				end
				break
			end

			local s = shieldspopped[i]
			-- whoops! No shield?
			if not s then break end

			-- we store the previous shield to use later in case of
			-- any missing abosrb amount that wasn't properly added.
			pshield = s

			-- if the amount can be handled by the shield itself, we just
			-- attribute it and break, no need to check for more.
			if s.amount >= absorbed then
				shields[dstName][s.spellid][s.srcName].amount = s.amount - absorbed
				shields[dstName][s.spellid][s.srcName].full = nil

				absorb.playerid = s.srcGUID
				absorb.playername = s.srcName
				absorb.playerflags = s.srcFlags

				absorb.dstGUID = dstGUID
				absorb.dstName = dstName
				absorb.dstFlags = dstFlags

				absorb.spellid = s.spellid
				absorb.school = s.school
				absorb.amount = absorbed

				Skada:DispatchSets(log_absorb)
				break
			-- arriving at this point means that the shield broke,
			-- so we make sure to remove it first, use its max
			-- abosrb value then use the difference for the rest.
			else
				-- if the "points" key exists, we don't remove the shield because
				-- for us it means it's a passive shield that should always be kept.
				if s.points == nil and s.spellid ~= 25228 then
					shields[dstName][s.spellid][s.srcName] = del(shields[dstName][s.spellid][s.srcName])
				end

				absorb.playerid = s.srcGUID
				absorb.playername = s.srcName
				absorb.playerflags = s.srcFlags

				absorb.dstGUID = dstGUID
				absorb.dstName = dstName
				absorb.dstFlags = dstFlags

				absorb.spellid = s.spellid
				absorb.school = s.school
				absorb.amount = s.amount

				Skada:DispatchSets(log_absorb)
				absorbed = absorbed - s.amount
			end
		end
	end

	local function spell_damage(timestamp, eventtype, _, _, _, dstGUID, dstName, dstFlags, ...)
		local spellschool, amount, absorbed

		if eventtype == "SWING_DAMAGE" then
			amount, _, _, _, _, absorbed = ...
		elseif eventtype == "ENVIRONMENTAL_DAMAGE" then
			_, amount, _, spellschool, _, _, absorbed = ...
		else
			_, _, spellschool, amount, _, _, _, _, absorbed = ...
		end

		if absorbed and absorbed > 0 and dstName and shields and shields[dstName] then
			process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool or 0x01, amount, amount > absorbed)
		end
	end

	local function spell_missed(timestamp, eventtype, _, _, _, dstGUID, dstName, dstFlags, ...)
		local spellschool, misstype, absorbed

		if eventtype == "SWING_MISSED" then
			misstype, absorbed = ...
		else
			_, _, spellschool, misstype, absorbed = ...
		end

		if misstype == "ABSORB" and absorbed and absorbed > 0 and dstName and shields and shields[dstName] then
			process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool or 0x01, 0, false)
		end
	end

	local function spell_heal(timestamp, _, _, srcName, _, _, dstName, _, _, _, _, amount)
		heals = heals or T.get("Skada_Heals") -- create table if missing
		heals[dstName] = heals[dstName] or {}
		heals[dstName][srcName] = heals[dstName][srcName] or {}
		heals[dstName][srcName].ts = timestamp
		heals[dstName][srcName].amount = amount
	end

	local function absorb_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(true)
		local aps, damage = actor:GetAPS()

		tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, totaltime), nil, nil, nil, 1, 1, 1)
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs"], Skada:FormatNumber(damage), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(Skada:FormatNumber(damage) .. "/" .. suffix, Skada:FormatNumber(aps), 1, 1, 1)
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor or enemy then return end -- unavailable for enemies yet

		local spell = actor.absorbspells and actor.absorbspells[id]
		if not spell then return end

		tooltip:AddLine(actor.name .. " - " .. label)
		if spell.school and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if spell.casts and spell.casts > 0 then
			tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
		end

		local average = nil
		if spell.count and spell.count > 0 then
			tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
			average = spell.amount / spell.count
		end

		local separator = nil

		if spell.min then
			tooltip:AddLine(" ")
			separator = true
			tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
		end

		if spell.max then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end
			tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
		end

		if average then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end

			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(average), 1, 1, 1)
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor absorb spells"](win.actorname or L["Unknown"], label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor absorb spells"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor or enemy then return end -- unavailable for enemies yet

		local total = actor.absorb
		local spells = (total and total > 0) and actor.absorbspells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sAPS and actor:GetTime()

		for spellid, spell in pairs(spells) do
			if spell.targets and spell.targets[win.targetname] then
				nr = nr + 1

				local d = win:spell(nr, spellid, spell)
				d.value = spell.targets[win.targetname]
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor absorb spells"](label)
	end

	function playermod:Update(win, set)
		win.title = L["actor absorb spells"](win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor or enemy then return end -- unavailable for enemies yet

		local total = actor.absorb
		local spells = (total and total > 0) and actor.absorbspells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sAPS and actor:GetTime()

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = spell.amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = pformat(L["%s's absorbed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's absorbed targets"], win.actorname)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor or enemy then return end -- unavailable for enemies yet

		local total = actor and actor.absorb or 0
		local targets = (total > 0) and actor:GetAbsorbTargets()

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sAPS and actor:GetTime()

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, nil, targetname)
			d.value = target.amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Absorbs"], L[win.class]) or L["Absorbs"]

		local total = set and set:GetAbsorb(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and (not win.class or win.class == actor.class) then
				local aps, amount = actor:GetAPS(nil, not mod_cols.APS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor)
					d.color = set.__arena and Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN") or nil
					d.value = amount
					format_valuetext(d, mod_cols, total, aps, win.metadata)
				end
			end
		end

		actors = set.__arena and set.enemies or nil -- arena enemies
		if not actors then return end

		for i = 1, #actors do
			local actor = actors[i]
			if actor and not actor.fake and (not win.class or win.class == actor.class) then
				local aps, amount = actor:GetAPS(nil, not mod_cols.APS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")
					d.value = amount
					format_valuetext(d, mod_cols, total, aps, win.metadata)
				end
			end
		end
	end

	function mod:GetSetSummary(set, win)
		local aps, amount = set:GetAPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Absorbs and Skada:FormatNumber(amount),
			self.metadata.columns.APS and Skada:FormatNumber(aps)
		)
		return amount, valuetext
	end

	do
		-- some effects aren't shields but rather special effects, such us talents.
		-- in order to track them, we simply add them as fake shields before all.
		-- I don't know the whole list of effects but, if you want to add yours
		-- please do : CLASS = {[spellid] = true}
		-- see: http://wotlk.cavernoftime.com/spell=<spellid>
		local _passive = {
			DEATHKNIGHT = {
				[50150] = true, -- Will of the Necropolis
				[49497] = true -- Spell Deflection
			},
			PALADIN = {
				[66233] = true -- Ardent Defender
			},
			ROGUE = {
				[31230] = true -- Cheat Death
			}
		}

		local LGT = LibStub("LibGroupTalents-1.0")
		local function check_unit_shields(unit, owner, timestamp, curtime)
			if not UnitIsDeadOrGhost(unit) then
				local dstName, dstGUID = UnitName(unit), UnitGUID(unit)
				for i = 1, 40 do
					local _, _, _, _, _, _, expires, unitCaster, _, _, spellid = UnitBuff(unit, i)
					if not spellid then
						break -- nothing found
					elseif absorbspells[spellid] and unitCaster then
						handle_shield(timestamp + max(0, expires - curtime), nil, UnitGUID(unitCaster), UnitName(unitCaster), nil, dstGUID, dstName, nil, spellid)
					end
				end

				-- passive shields (not for pets)
				if owner then return end

				local _, class = UnitClass(unit)
				if not _passive[class] then return end

				for spellid, _ in pairs(_passive[class]) do
					local points = LGT:GUIDHasTalent(dstGUID, GetSpellInfo(spellid), LGT:GetActiveTalentGroup(unit))
					if points then
						handle_shield(timestamp - 60, nil, dstGUID, dstGUID, nil, dstGUID, dstName, nil, spellid, nil, nil, nil, points)
					end
				end
			end
		end

		function mod:CombatEnter(_, set, timestamp)
			if set and not set.stopped and not self.checked then
				self:ZoneModifier()
				GroupIterator(check_unit_shields, timestamp, set.last_time or GetTime())
				self.checked = true
			end
		end

		function mod:CombatLeave()
			T.clear(absorb)
			T.free("Skada_Heals", heals)
			T.free("Skada_Shields", shields)
			T.free("Skada_ShieldAmounts", shieldamounts)
			T.free("Skada_ShieldsPopped", shieldspopped, nil, del)
			self.checked = nil
		end
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = playermod_tooltip}
		targetmod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			post_tooltip = absorb_tooltip,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Absorbs = true, APS = true, Percent = true, sAPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_holy_devineaegis]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		local flags_src = {src_is_interesting = true}

		Skada:RegisterForCL(
			handle_shield,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_REMOVED",
			flags_src
		)

		Skada:RegisterForCL(
			spell_heal,
			"SPELL_HEAL",
			"SPELL_PERIODIC_HEAL",
			flags_src
		)

		local flags_dst = {dst_is_interesting_nopets = true}

		Skada:RegisterForCL(
			spell_damage,
			"DAMAGE_SHIELD",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"RANGE_DAMAGE",
			"SWING_DAMAGE",
			"ENVIRONMENTAL_DAMAGE",
			flags_dst
		)

		Skada:RegisterForCL(
			spell_missed,
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SPELL_BUILDING_MISSED",
			"RANGE_MISSED",
			"SWING_MISSED",
			flags_dst
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER", "CombatEnter")
		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, L["Absorbs and Healing"])

		-- table of ignored spells:
		if Skada.ignoredSpells then
			if Skada.ignoredSpells.absorbs then
				ignoredSpells = Skada.ignoredSpells.absorbs
			end
			if Skada.ignoredSpells.activeTime then
				passiveSpells = Skada.ignoredSpells.activeTime
			end
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:ZoneModifier()
		if UnitInBattleground("player") or GetCurrentMapAreaID() == 502 then
			zoneModifier = 1.17
		elseif IsActiveBattlefieldArena() then
			zoneModifier = 0.9
		elseif GetCurrentMapAreaID() == 605 then
			zoneModifier = (UnitBuff("player", GetSpellInfo(73822)) or UnitBuff("player", GetSpellInfo(73828))) and 1.3 or 1
		else
			zoneModifier = 1
		end
	end

	function mod:AddSetAttributes(set)
		self:ZoneModifier()
	end

	function mod:SetComplete(set)
		-- clean absorbspells table:
		if not set.absorb or set.absorb == 0 then return end
		for i = 1, #set.players do
			local p = set.players[i]
			if p and (p.absorb == 0 or (not p.absorb and p.absorbspells)) then
				p.absorb, p.absorbspells = nil, del(p.absorbspells, true)
			end
		end
	end
end)

-- ========================== --
-- Absorbs and healing module --
-- ========================== --

Skada:RegisterModule("Absorbs and Healing", function(L, P)
	local mod = Skada:NewModule("Absorbs and Healing")
	local playermod = mod:NewModule("Absorbs and healing spells")
	local targetmod = mod:NewModule("Absorbed and healed targets")
	local spellmod = targetmod:NewModule("Absorbs and healing spells")
	local spellschools = Skada.spellschools
	local mod_cols = nil

	local function format_valuetext(d, columns, total, hps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Healing and Skada:FormatNumber(d.value),
			columns[subview and "sHPS" or "HPS"] and hps and Skada:FormatNumber(hps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
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
		local activetime = actor:GetTime(true)
		local hps, amount = actor:GetAHPS()

		tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, totaltime), nil, nil, nil, 1, 1, 1)
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(set:GetTime()), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs and Healing"], Skada:FormatNumber(amount), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(Skada:FormatNumber(amount) .. "/" .. suffix, Skada:FormatNumber(hps), 1, 1, 1)
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local spell = actor.absorbspells and actor.absorbspells[id] -- absorb?
		spell = spell or actor.healspells and actor.healspells[id] -- heal?
		if not spell then return end

		tooltip:AddLine(actor.name .. " - " .. label)
		if spell.school and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if enemy then
			tooltip:AddDoubleLine(L["Amount"], spell.amount, 1, 1, 1)
			return
		end

		if spell.casts then
			tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
		end

		local average = nil
		if spell.count and spell.count > 0 then
			tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
			average = spell.amount / spell.count

			if spell.c_num and spell.c_num > 0 then
				tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.c_num, spell.count), 0.67, 1, 0.67)
			end
		end

		if spell.o_amt and spell.o_amt > 0 then
			tooltip:AddDoubleLine(L["Total Healing"], Skada:FormatNumber(spell.o_amt + spell.amount), 1, 1, 1)
			tooltip:AddDoubleLine(L["Overheal"], format("%s (%s)", Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, spell.o_amt + spell.amount)), 1, 0.67, 0.67)
		end

		local separator = nil

		if spell.min then
			tooltip:AddLine(" ")
			separator = true

			local spellmin = spell.min
			if spell.c_min and spell.c_min < spellmin then
				spellmin = spell.c_min
			end
			tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
		end

		if spell.max then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end

			local spellmax = spell.max
			if spell.c_max and spell.c_max > spellmax then
				spellmax = spell.c_max
			end
			tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spellmax), 1, 1, 1)
		end

		if average then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end

			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(average), 1, 1, 1)
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor absorb and heal spells"](win.actorname or L["Unknown"], label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor absorb and heal spells"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHealOnTarget(win.targetname)

		if not total or total == 0 or not (actor.healspells or actor.absorbspells) then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sHPS and actor:GetTime()

		local spells = actor.healspells -- heal spells
		if spells then
			for spellid, spell in pairs(spells) do
				local amount = spell.targets and spell.targets[win.targetname]
				amount = amount and (enemy and amount or amount.amount)
				if amount then
					nr = nr + 1

					local d = win:spell(nr, spellid, spell, nil, true)
					d.value = amount
					format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
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
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor absorb and heal spells"](label)
	end

	function playermod:Update(win, set)
		win.title = L["actor absorb and heal spells"](win.actorname or L["Unknown"])
		if not win.actorname then return end

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHeal()

		if not total or total == 0 or not (actor.healspells or actor.absorbspells) then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sHPS and actor:GetTime()

		local spells = actor.healspells -- heal spells
		if spells then
			for spellid, spell in pairs(spells) do
				nr = nr + 1

				local d = win:spell(nr, spellid, spell, nil, true)
				d.value = spell.amount
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end

		spells = actor.absorbspells -- absorb spells
		if not spells then return end

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = spell.amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = pformat(L["%s's absorbed and healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's absorbed and healed targets"], win.actorname)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHeal()
		local targets = (total and total > 0) and actor:GetAbsorbHealTargets()

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sAPS and actor:GetTime()

		for targetname, target in pairs(targets) do
			if target.amount > 0 then
				nr = nr + 1

				local d = win:actor(nr, target, nil, targetname)
				d.value = target.amount
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Absorbs and Healing"], L[win.class]) or L["Absorbs and Healing"]

		local total = set and set:GetAbsorbHeal(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and (not win.class or win.class == actor.class) then
				local hps, amount = actor:GetAHPS(nil, not mod_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor)
					d.color = set.__arena and Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN") or nil
					d.value = amount
					format_valuetext(d, mod_cols, total, hps, win.metadata)
				end
			end
		end

		actors = set.__arena and set.enemies or nil -- arena enemies
		if not actors then return end

		for i = 1, #actors do
			local actor = actors[i]
			if actor and not actor.fake and (not win.class or win.class == actor.class) then
				local hps, amount = actor:GetAHPS(nil, not mod_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")
					d.value = amount
					format_valuetext(d, mod_cols, total, hps, win.metadata)
				end
			end
		end
	end

	function mod:GetSetSummary(set, win)
		if not set then return end
		local hps, amount = set:GetAHPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Healing and Skada:FormatNumber(amount),
			self.metadata.columns.HPS and Skada:FormatNumber(hps)
		)
		return amount, valuetext
	end

	function mod:AddToTooltip(set, tooltip)
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
		local player = set and set:GetPlayer(Skada.userGUID, Skada.userName)
		if player then
			return Skada:FormatNumber(player:GetAHPS()) .. " " .. L["HPS"]
		end
	end

	local function feed_raid_hps()
		local set = Skada:GetSet("current")
		return Skada:FormatNumber(set and set:GetAHPS() or 0) .. " " .. L["RHPS"]
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = playermod_tooltip}
		targetmod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			post_tooltip = hps_tooltip,
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_holy_healingfocus]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		Skada:AddFeed(L["Healing: Personal HPS"], feed_personal_hps)
		Skada:AddFeed(L["Healing: Raid HPS"], feed_raid_hps)

		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveFeed(L["Healing: Personal HPS"])
		Skada:RemoveFeed(L["Healing: Raid HPS"])
		Skada:RemoveMode(self)
	end
end, "Absorbs", "Healing")

-- ============================== --
-- Healing done per second module --
-- ============================== --

Skada:RegisterModule("HPS", function(L, P)
	local mod = Skada:NewModule("HPS")
	local mod_cols = nil

	local function format_valuetext(d, columns, total, metadata)
		d.valuetext = Skada:FormatValueCols(
			columns.HPS and Skada:FormatNumber(d.value),
			columns.Percent and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function hps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor  = set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(true)
		local hps, amount = actor:GetAHPS()

		tooltip:AddLine(actor.name .. " - " .. L["HPS"])
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(set:GetTime()), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Absorbs and Healing"], Skada:FormatNumber(amount), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(Skada:FormatNumber(amount) .. "/" .. suffix, Skada:FormatNumber(hps), 1, 1, 1)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["HPS"], L[win.class]) or L["HPS"]

		local total = set and set:GetAHPS(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and (not win.class or win.class == actor.class) then
				local amount = actor:GetAHPS(nil, not mod_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor)
					d.color = set.__arena and Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN") or nil
					d.value = amount
					format_valuetext(d, mod_cols, total, win.metadata)
				end
			end
		end

		actors = set.__arena and set.enemies or nil -- arena enemies
		if not actors then return end

		for i = 1, #actors do
			local actor = actors[i]
			if actor and not actor.fake and (not win.class or win.class == actor.class) then
				local amount = actor:GetHPS(nil, not mod_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")
					d.value = amount
					format_valuetext(d, mod_cols, total, win.metadata)
				end
			end
		end
	end

	function mod:GetSetSummary(set, win)
		local value =  set:GetAHPS(win and win.class)
		return value, Skada:FormatNumber(value)
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			tooltip = hps_tooltip,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {HPS = true, Percent = true},
			icon = [[Interface\Icons\spell_nature_rejuvenation]]
		}

		mod_cols = self.metadata.columns

		local parentmod = Skada:GetModule("Absorbs and Healing", true)
		if parentmod then
			self.metadata.click1 = parentmod.metadata.click1
			self.metadata.click2 = parentmod.metadata.click2
		end

		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Absorbs", "Healing", "Absorbs and Healing")

-- ===================== --
-- Healing done by spell --
-- ===================== --

Skada:RegisterModule("Healing Done By Spell", function(L, _, _, C)
	local mod = Skada:NewModule("Healing Done By Spell")
	local spellmod = mod:NewModule("Healing spell sources")
	local spellschools = Skada.spellschools
	local clear = Skada.clearTable
	local get_absorb_heal_spells = nil
	local mod_cols = nil

	local function format_valuetext(d, columns, total, hps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Healing and Skada:FormatNumber(d.value),
			columns[subview and "sHPS" or "HPS"] and Skada:FormatNumber(hps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function player_tooltip(win, id, label, tooltip)
		local set = win.spellname and win:GetSelectedSet()
		local player = set and set:GetActor(label, id)
		if not player then return end

		local spell = player.healspells and player.healspells[win.spellid]
		spell = spell or player.absorbspells and player.absorbspells[win.spellid]
		if not spell then return end

		tooltip:AddLine(label .. " - " .. win.spellname)

		if spell.casts then
			tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
		end

		if spell.count then
			tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)

			if spell.c_num then
				tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.c_num, spell.count), 1, 1, 1)
				tooltip:AddLine(" ")
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

	local function spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local total = set and set:GetAbsorbHeal()
		if not total or total == 0 then return end

		clear(C)
		for i = 1, #set.players do
			local p = set.players[i]
			local spell = p and ((p.absorbspells and p.absorbspells[id]) or (p.healspells and p.healspells[id])) or nil
			if spell then
				if not C[id] then
					C[id] = new()
					C[id].school = spell.school
					C[id].amount = spell.amount
					C[id].o_amt = spell.o_amt or spell.overheal
					C[id].isabsorb = (p.absorbspells and p.absorbspells[id])
				else
					C[id].amount = C[id].amount + spell.amount
					if spell.o_amt or spell.overheal then
						C[id].o_amt = (C[id].o_amt or 0) + (spell.o_amt or spell.overheal)
					end
				end
			end
		end

		local spell = C[id]
		if not spell then return end

		tooltip:AddLine((GetSpellInfo(id)))
		if spell.school and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if spell.casts and spell.casts > 0 then
			tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
		end

		if spell.count and spell.count > 0 then
			tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
		end
		tooltip:AddDoubleLine(spell.isabsorb and L["Absorbs"] or L["Healing"], format("%s (%s)", Skada:FormatNumber(spell.amount), Skada:FormatPercent(spell.amount, total)), 1, 1, 1)
		if set.overheal and spell.o_amt and spell.o_amt > 0 then
			tooltip:AddDoubleLine(L["Overheal"], format("%s (%s)", Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, set.overheal)), 1, 1, 1)
		end
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = pformat(L["%s's sources"], label)
	end

	function spellmod:Update(win, set)
		win.title = pformat(L["%s's sources"], win.spellname)
		if not (win.spellid and set) then return end

		-- let's go...
		local total = 0
		local players = clear(C)

		local _players = set.players
		for i = 1, #_players do
			local p = _players[i]
			local spell = p and ((p.absorbspells and p.absorbspells[win.spellid]) or (p.healspells and p.healspells[win.spellid])) or nil
			if spell then
				players[p.name] = new()
				players[p.name].id = p.id
				players[p.name].class = p.class
				players[p.name].role = p.role
				players[p.name].spec = p.spec
				players[p.name].amount = spell.amount
				players[p.name].time = mod.metadata.columns.sHPS and p:GetTime()
				-- calculate the total.
				total = total + spell.amount
			end
		end

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for playername, player in pairs(players) do
			nr = nr + 1

			local d = win:actor(nr, player, nil, playername)
			d.value = player.amount
			format_valuetext(d, mod_cols, total, player.time and (d.value / player.time), win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing Done By Spell"]
		local total = set and set:GetAbsorbHeal()
		local spells = (total and total > 0) and get_absorb_heal_spells(set)

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local settime = mod_cols.HPS and set:GetTime()

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell, nil, true)
			d.value = spell.amount
			format_valuetext(d, mod_cols, total, settime and (d.value / settime), win.metadata)
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {showspots = true, tooltip = player_tooltip}
		self.metadata = {
			click1 = spellmod,
			post_tooltip = spell_tooltip,
			columns = {Healing = true, HPS = false, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_nature_healingwavelesser]]
		}
		mod_cols = self.metadata.columns
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	local function fill_spells_table(t, spellid, info)
		local spell = t[spellid]
		if not spell then
			spell = new()
			-- common
			spell.school = info.school
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
		if not self.players or not (self.absorb or self.heal) then return end

		tbl = clear(tbl or C)
		for i = 1, #self.players do
			local player = self.players[i]
			if player and player.healspells then
				for spellid, spell in pairs(player.healspells) do
					fill_spells_table(tbl, spellid, spell)
				end
			end
			if player and player.absorbspells then
				for spellid, spell in pairs(player.absorbspells) do
					fill_spells_table(tbl, spellid, spell)
				end
			end
		end
		return tbl
	end
end, "Absorbs", "Healing")
