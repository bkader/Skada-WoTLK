local Skada = Skada

-- cache frequently used globals
local pairs, ipairs, select, format, wipe = pairs, ipairs, select, string.format, wipe
local max, min, floor = math.max, math.min, math.floor
local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local UnitGUID, UnitClass, unitClass = UnitGUID, UnitClass, Skada.unitClass
local _

-- ============== --
-- Absorbs module --
-- ============== --

Skada:AddLoadableModule("Absorbs", function(L)
	if Skada:IsDisabled("Absorbs") then return end

	local mod = Skada:NewModule(L["Absorbs"])
	local playermod = mod:NewModule(L["Absorb spell list"])
	local targetmod = mod:NewModule(L["Absorbed target list"])
	local spellmod = targetmod:NewModule(L["Absorb spell list"])

	local LGT = LibStub("LibGroupTalents-1.0")

	local GroupIterator = Skada.GroupIterator
	local UnitName, UnitExists, UnitBuff = UnitName, UnitExists, UnitBuff
	local UnitIsDeadOrGhost, UnitHealthInfo = UnitIsDeadOrGhost, Skada.UnitHealthInfo
	local GetTime, band = GetTime, bit.band
	local tsort, tContains = table.sort, tContains
	local T = Skada.Table

	-- INCOMPLETE
	-- the following list is incomplete due to the lack of testing for different
	-- shield ranks. Feel free to provide any helpful data possible to complete it.
	-- Note: some of the caps are used as backup because their amounts are calculated later.
	local absorbspells = {
		[48707] = {dur = 5}, -- Anti-Magic Shell (rank 1)
		[51052] = {dur = 10}, -- Anti-Magic Zone( (rank 1)
		[50150] = {dur = 86400}, -- Will of the Necropolis
		[49497] = {dur = 86400}, -- Spell Deflection
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
		[1463] = {dur = 60}, --  Mana shield (rank 1)
		[8494] = {dur = 60}, --  Mana shield (rank 2)
		[8495] = {dur = 60}, --  Mana shield (rank 3)
		[10191] = {dur = 60}, --  Mana shield (rank 4)
		[10192] = {dur = 60}, --  Mana shield (rank 5)
		[10193] = {dur = 60}, --  Mana shield (rank 6)
		[27131] = {dur = 60}, --  Mana shield (rank 7)
		[43019] = {dur = 60}, --  Mana shield (rank 8)
		[43020] = {dur = 60, avg = 4500, cap = 6300}, --  Mana shield (rank 9)
		[543] = {dur = 30}, -- Fire Ward (rank 1)
		[8457] = {dur = 30}, -- Fire Ward (rank 2)
		[8458] = {dur = 30}, -- Fire Ward (rank 3)
		[10223] = {dur = 30}, -- Fire Ward (rank 4)
		[10225] = {dur = 30}, -- Fire Ward (rank 5)
		[27128] = {dur = 30}, -- Fire Ward (rank 6)
		[43010] = {dur = 30, avg = 5200, cap = 7000}, -- Fire Ward (rank 7)
		[58597] = {dur = 6, avg = 4400, cap = 6000}, -- Sacred Shield
		[66233] = {dur = 86400}, -- Ardent Defender
		[31230] = {dur = 86400}, -- Cheat Death
		[17] = {dur = 30}, -- Power Word: Shield (rank 1)
		[592] = {dur = 30}, -- Power Word: Shield (rank 2)
		[600] = {dur = 30}, -- Power Word: Shield (rank 3)
		[3747] = {dur = 30}, -- Power Word: Shield (rank 4)
		[6065] = {dur = 30}, -- Power Word: Shield (rank 5)
		[6066] = {dur = 30}, -- Power Word: Shield (rank 6)
		[10898] = {dur = 30, avg = 721, cap = 848}, -- Power Word: Shield (rank 7)
		[10899] = {dur = 30, avg = 898, cap = 1057}, -- Power Word: Shield (rank 8)
		[10900] = {dur = 30, avg = 1543, cap = 1816}, -- Power Word: Shield (rank 9)
		[10901] = {dur = 30, avg = 3643, cap = 4288}, -- Power Word: Shield (rank 10)
		[25217] = {dur = 30, avg = 5436, cap = 6398}, -- Power Word: Shield (rank 11)
		[25218] = {dur = 30, avg = 7175, cap = 8444}, -- Power Word: Shield (rank 12)
		[48065] = {dur = 30, avg = 9596, cap = 11293}, -- Power Word: Shield (rank 13)
		[48066] = {dur = 30, avg = 10000, cap = 11769}, -- Power Word: Shield (rank 14)
		[47509] = {dur = 12}, -- Divine Aegis (rank 1)
		[47511] = {dur = 12}, -- Divine Aegis (rank 2)
		[47515] = {dur = 12}, -- Divine Aegis (rank 3)
		[47753] = {dur = 12, cap = 10000}, -- Divine Aegis (rank 1)
		[54704] = {dur = 12, cap = 10000}, -- Divine Aegis (rank 1)
		[47788] = {dur = 10}, -- Guardian Spirit
		[7812] = {dur = 30}, -- Sacrifice (rank 1)
		[19438] = {dur = 30}, -- Sacrifice (rank 2)
		[19440] = {dur = 30}, -- Sacrifice (rank 3)
		[19441] = {dur = 30}, -- Sacrifice (rank 4)
		[19442] = {dur = 30}, -- Sacrifice (rank 5)
		[19443] = {dur = 30}, -- Sacrifice (rank 6)
		[27273] = {dur = 30}, -- Sacrifice (rank 7)
		[47985] = {dur = 30}, -- Sacrifice (rank 8)
		[47986] = {dur = 30}, -- Sacrifice (rank 9)
		[6229] = {dur = 30}, -- Shadow Ward (rank 1)
		[11739] = {dur = 30}, -- Shadow Ward (rank 1)
		[11740] = {dur = 30}, -- Shadow Ward (rank 2)
		[28610] = {dur = 30}, -- Shadow Ward (rank 3)
		[47890] = {dur = 30}, -- Shadow Ward (rank 4)
		[47891] = {dur = 30, avg = 6500, cap = 8300}, -- Shadow Ward (rank 5)
		[29674] = {dur = 86400, cap = 1000}, -- Lesser Ward of Shielding
		[29719] = {dur = 86400, cap = 4000}, -- Greater Ward of Shielding
		[29701] = {dur = 86400, cap = 4000}, -- Greater Shielding
		[28538] = {dur = 120, avg = 3400, cap = 4000}, -- Major Holy Protection Potion
		[28537] = {dur = 120, avg = 3400, cap = 4000}, -- Major Shadow Protection Potion
		[28536] = {dur = 120, avg = 3400, cap = 4000}, --  Major Arcane Protection Potion
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
		[17548] = {dur = 120, avg = 2600, cap = 3250}, --  Greater Shadow Protection Potion
		[17546] = {dur = 120, avg = 2600, cap = 3250}, -- Greater Nature Protection Potion
		[17545] = {dur = 120, avg = 2600, cap = 3250}, -- Greater Holy Protection Potion
		[17544] = {dur = 120, avg = 2600, cap = 3250}, -- Greater Frost Protection Potion
		[17543] = {dur = 120, avg = 2600, cap = 3250}, -- Greater Fire Protection Potion
		[17549] = {dur = 120, avg = 2600, cap = 3250}, -- Greater Arcane Protection Potion
		[28527] = {dur = 15, avg = 1000, cap = 1250}, -- Fel Blossom
		[29432] = {dur = 3600, avg = 2000, cap = 2500}, -- Frozen Rune
		[36481] = {dur = 4, cap = 100000}, -- Arcane Barrier (TK Kael'Thas) Shield
		[57350] = {dur = 6, cap = 1500}, -- Darkmoon Card: Illusion
		[17252] = {dur = 1800, cap = 500}, -- Mark of the Dragon Lord (LBRS epic ring)
		[25750] = {dur = 15, avg = 151, cap = 302}, -- Defiler's Talisman/Talisman of Arathor
		[25747] = {dur = 15, avg = 344, cap = 378}, -- Defiler's Talisman/Talisman of Arathor
		[25746] = {dur = 15, avg = 435, cap = 478}, -- Defiler's Talisman/Talisman of Arathor
		[23991] = {dur = 15, avg = 550, cap = 605}, -- Defiler's Talisman/Talisman of Arathor
		[31000] = {dur = 300, avg = 1800, cap = 2700}, -- Pendant of Shadow's End Usage
		[30997] = {dur = 300, avg = 1800, cap = 2700}, -- Pendant of Frozen Flame Usage
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
		[65684] = {dur = 86400, cap = 1000000} -- Twin Val'kyr: Dark Essence86400
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
	local passivespells = {
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

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_spellcast(set, playerid, playername, playerflags, spellid, spellschool)
		local player = Skada:GetPlayer(set, playerid, playername, playerflags)
		if player and player.absorbspells and player.absorbspells[spellid] then
			player.absorbspells[spellid].casts = (player.absorbspells[spellid].casts or 1) + 1

			-- fix possible missing spell school.
			if not player.absorbspells[spellid].school and spellschool then
				player.absorbspells[spellid].school = spellschool
			end
		end
	end

	local function log_absorb(set, absorb, nocount)
		if not absorb.spellid or (absorb.amount or 0) == 0 then return end

		local player = Skada:GetPlayer(set, absorb.playerid, absorb.playername)
		if player then
			Skada:AddActiveTime(player, (player.role ~= "DAMAGER" and not nocount))

			-- add absorbs amount
			player.absorb = (player.absorb or 0) + absorb.amount
			set.absorb = (set.absorb or 0) + absorb.amount

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.total then return end

			-- record the spell
			local spell = player.absorbspells and player.absorbspells[absorb.spellid]
			if not spell then
				player.absorbspells = player.absorbspells or {}
				spell = {count = 1, amount = absorb.amount, school = absorb.school}
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
			if not spell.casts and not passivespells[absorb.spellid] then
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
				local actor = Skada:GetActor(set, absorb.dstGUID, absorb.dstName, absorb.dstFlags)
				if actor then
					spell.targets = spell.targets or {}
					spell.targets[absorb.dstName] = (spell.targets[absorb.dstName] or 0) + absorb.amount
				end
			end
		end
	end

	-- https://github.com/TrinityCore/TrinityCore/blob/5d82995951c2be99b99b7b78fa12505952e86af7/src/server/game/Spells/Auras/SpellAuraEffects.h#L316
	-- Note: this order is reversed
	local function SortShields(a, b)
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

	local function HandleShield(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		-- shield removed?
		if eventtype == "SPELL_AURA_REMOVED" then
			local spellid = ...
			if absorbspells[spellid] and shields[dstName] and shields[dstName][spellid] and shields[dstName][spellid][srcName] then
				shields[dstName][spellid][srcName].ts = timestamp + 0.1
			end
			return
		end

		-- shield applied
		local spellid, _, spellschool, _, points = ...
		if spellid and absorbspells[spellid] and not tContains(ignoredSpells, spellid) and dstName then
			shields[dstName] = shields[dstName] or {}
			shields[dstName][spellid] = shields[dstName][spellid] or {}

			-- log spell casts.
			if not passivespells[spellid] then
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
			elseif absorbspells[spellid].cap then
				if shieldamounts[srcName] and shieldamounts[srcName][spellid] then
					shields[dstName][spellid][srcName] = {
						srcGUID = srcGUID,
						srcFlags = srcFlags,
						spellid = spellid,
						school = spellschool,
						points = points,
						amount = shieldamounts[srcName][spellid],
						ts = timestamp + absorbspells[spellid].dur + 0.1,
						full = true
					}
					return
				else
					amount = (absorbspells[spellid].avg or absorbspells[spellid].cap or 1000) * zoneModifier
				end
			else
				amount = 1000 * zoneModifier -- default
			end

			shields[dstName][spellid][srcName] = {
				srcGUID = srcGUID,
				srcFlags = srcFlags,
				spellid = spellid,
				school = spellschool,
				points = points,
				amount = floor(amount),
				ts = timestamp + absorbspells[spellid].dur + 0.1,
				full = true
			}
		end
	end

	do
		-- some effects aren't shields but rather special effects, such us talents.
		-- in order to track them, we simply add them as fake shields before all.
		-- I don't know the whole list of effects but, if you want to add yours
		-- please do : CLASS = {[index] = {spellid, spellschool}}
		local passiveshields = {
			DEATHKNIGHT = {{50150, 1}, {49497, 1}},
			PALADIN = {{66233, 1}},
			ROGUE = {{31230, 1}}
		}

		local function CheckUnitShields(unit, owner, timestamp, curtime)
			if not UnitIsDeadOrGhost(unit) then
				local dstName, dstGUID = UnitName(unit), UnitGUID(unit)
				for i = 1, 40 do
					local expires, unitCaster, _, _, spellid = select(7, UnitBuff(unit, i))
					if spellid then
						if absorbspells[spellid] and unitCaster then
							HandleShield(timestamp + expires - curtime, nil, UnitGUID(unitCaster), UnitName(unitCaster), nil, dstGUID, dstName, nil, spellid)
						end
					else
						break -- nothing found
					end
				end

				-- passive shields (not for pets)
				if owner == nil then
					local class = select(2, UnitClass(unit))
					if passiveshields[class] then
						for _, spell in ipairs(passiveshields[class]) do
							local points = LGT:GUIDHasTalent(dstGUID, GetSpellInfo(spell[1]), LGT:GetActiveTalentGroup(unit))
							if points then
								HandleShield(timestamp - 60, nil, dstGUID, dstGUID, nil, dstGUID, dstName, nil, spell[1], nil, spell[2], nil, points)
							end
						end
					end
				end
			end
		end

		function mod:CheckPreShields(event, set, timestamp)
			if event == "COMBAT_PLAYER_ENTER" and set and not set.stopped then
				self:ZoneModifier()
				GroupIterator(CheckUnitShields, timestamp, GetTime())
			end
		end
	end

	local function process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool, damage, broke)
		shields[dstName] = shields[dstName] or {}
		shieldspopped = wipe(shieldspopped)
		local count, total = 0, damage + absorbed

		for spellid, spells in pairs(shields[dstName]) do
			for srcName, shield in pairs(spells) do
				if shield.ts > timestamp then
					-- Light Essence vs Fire Damage
					if spellid == 65686 and band(spellschool, 0x4) == spellschool then
						return -- don't record
					-- Dark Essence vs Shadow Damage
					elseif spellid == 65684 and band(spellschool, 0x20) == spellschool then
						return -- don't record
					-- Frost Ward vs Frost Damage
					elseif mage_frost_ward[spellid] and band(spellschool, 0x10) ~= spellschool then
						-- nothing
					-- Fire Ward vs Fire Damage
					elseif mage_fire_ward[spellid] and band(spellschool, 0x4) ~= spellschool then
						-- nothing
					-- Shadow Ward vs Shadow Damage
					elseif warlock_shadow_ward[spellid] and band(spellschool, 0x20) ~= spellschool then
						-- nothing
					-- Anti-Magic, Spell Deflection, Savage Defense
					elseif (spellid == 48707 or spellid == 49497 or spellid == 62606) and band(spellschool, 0x1) == spellschool then
						-- nothing
					else
						shieldspopped[#shieldspopped + 1] = {
							srcGUID = shield.srcGUID,
							srcName = srcName,
							srcFlags = shield.srcFlags,
							spellid = shield.spellid,
							school = shield.school,
							points = shield.points,
							ts = shield.ts - absorbspells[shield.spellid].dur,
							amount = shield.amount,
							full = shield.full
						}
						count = count + 1
					end
				end
			end
		end

		-- the player has no shields, so nothing to do.
		if count <= 0 then return end

		-- if the player has a single shield and it broke, we update its max absorb
		if count == 1 and broke and shieldspopped[1].full and absorbspells[shieldspopped[1].spellid].cap then
			local s = shieldspopped[1]
			shieldamounts[s.srcName] = shieldamounts[s.srcName] or {}
			if (not shieldamounts[s.srcName][s.spellid] or shieldamounts[s.srcName][s.spellid] < absorbed) and absorbed < (absorbspells[s.spellid].cap * zoneModifier) then
				shieldamounts[s.srcName][s.spellid] = absorbed
			end
		end

		-- we loop through available shields and make sure to update
		-- their maximum absorb values.
		for _, s in ipairs(shieldspopped) do
			if s.full and shieldamounts and shieldamounts[s.srcName] and shieldamounts[s.srcName][s.spellid] then
				s.amount = shieldamounts[s.srcName][s.spellid]
			elseif s.spellid == 50150 and s.points then -- Will of the Necropolis
				local hppercent = UnitHealthInfo(dstName, dstGUID)
				s.amount = (hppercent and hppercent <= 36) and floor(total * 0.05 * s.points) or 0
			elseif s.spellid == 49497 and s.points then -- Spell Deflection
				s.amount = floor(total * 0.15 * s.points)
			elseif s.spellid == 66233 and s.points then -- Ardent Defender
				local hppercent = UnitHealthInfo(dstName, dstGUID)
				s.amount = (hppercent and hppercent <= 36) and floor(total * 0.0667 * s.points) or 0
			elseif s.spellid == 31230 and s.points then -- Cheat Death
				s.amount = floor((select(3, UnitHealthInfo(dstName, dstGUID)) or 0) * 0.1)
			end
		end

		tsort(shieldspopped, SortShields)

		local amount = absorbed
		local pshield = nil
		for i = #shieldspopped, 0, -1 do
			-- no shield left to check?
			if i == 0 then
				-- if we still have an absorbed amount running and there is
				-- a previous shield, we attributed dumbly to it.
				-- the "true" at the end is so we don't update the spell count or active time.
				if amount > 0 and pshield then
					absorb.playerid = pshield.srcGUID
					absorb.playername = pshield.srcName
					absorb.playerflags = pshield.srcFlags

					absorb.dstGUID = dstGUID
					absorb.dstName = dstName
					absorb.dstFlags = dstFlags

					absorb.spellid = pshield.spellid
					absorb.school = pshield.school
					absorb.amount = amount

					Skada:DispatchSets(log_absorb, absorb, true)
					log_absorb(Skada.total, absorb, true)
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
			if s.amount >= amount then
				shields[dstName][s.spellid][s.srcName].amount = s.amount - amount
				shields[dstName][s.spellid][s.srcName].full = nil

				absorb.playerid = s.srcGUID
				absorb.playername = s.srcName
				absorb.playerflags = s.srcFlags

				absorb.dstGUID = dstGUID
				absorb.dstName = dstName
				absorb.dstFlags = dstFlags

				absorb.spellid = s.spellid
				absorb.school = s.school
				absorb.amount = amount

				Skada:DispatchSets(log_absorb, absorb)
				log_absorb(Skada.total, absorb)
				break
			-- arriving at this point means that the shield broke,
			-- so we make sure to remove it first, use its max
			-- abosrb value then use the difference for the rest.
			else
				-- if the "points" key exists, we don't remove the shield because
				-- for us it means it's a passive shield that should always be kept.
				if s.points == nil then
					shields[dstName][s.spellid][s.srcName] = nil
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

				Skada:DispatchSets(log_absorb, absorb)
				log_absorb(Skada.total, absorb)
				amount = amount - s.amount
			end
		end
	end

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellschool, amount, absorbed

		if eventtype == "SWING_DAMAGE" then
			amount, _, _, _, _, absorbed = ...
		else
			spellschool, amount, _, _, _, _, absorbed = select(3, ...)
		end

		if (absorbed or 0) > 0 and dstName and shields[dstName] then
			process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool or 1, amount, amount > absorbed)
		end
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellschool, misstype, absorbed

		if eventtype == "SWING_MISSED" then
			misstype, absorbed = ...
		else
			spellschool, misstype, absorbed = select(3, ...)
		end

		if misstype == "ABSORB" and (absorbed or 0) > 0 and dstName and shields[dstName] then
			process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool or 1, 0, false)
		end
	end

	local function EnvironmentDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local envtype, amount, _, _, _, _, absorbed = ...
		if (absorbed or 0) > 0 and dstName and shields[dstName] then
			local spellschool = 1

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

			process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool, amount, amount > absorbed)
		end
	end

	local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		heals[dstName] = heals[dstName] or {}
		heals[dstName][srcName] = {ts = timestamp, amount = select(4, ...)}
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local spell = player and player.absorbspells and player.absorbspells[id]

		if spell then
			tooltip:AddLine(player.name .. " - " .. label)
			if spell.school and Skada.spellschools[spell.school] then
				tooltip:AddLine(
					Skada.spellschools[spell.school].name,
					Skada.spellschools[spell.school].r,
					Skada.spellschools[spell.school].g,
					Skada.spellschools[spell.school].b
				)
			end

			if (spell.casts or 0) > 0 then
				tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
			end

			if (spell.count or 0) > 0 then
				tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
			end

			if spell.min and spell.max then
				tooltip:AddLine(" ")
				tooltip:AddDoubleLine(L["Minimum Hit"], Skada:FormatNumber(spell.min), 1, 1, 1)
				tooltip:AddDoubleLine(L["Maximum Hit"], Skada:FormatNumber(spell.max), 1, 1, 1)
				tooltip:AddDoubleLine(L["Average Hit"], Skada:FormatNumber((spell.min + spell.max) / 2), 1, 1, 1)
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's absorbs on %s"], win.actorname or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's absorbs on %s"], win.actorname or L.Unknown, win.targetname or L.Unknown)
		if not win.targetname then return end

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.absorb or 0

		if total > 0 and player.absorbspells then
			local nr = 0
			for spellid, spell in pairs(player.absorbspells) do
				if spell.targets and spell.targets[win.targetname] then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)

					d.value = spell.targets[win.targetname]
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Absorbs and Skada:FormatNumber(d.value),
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's absorb spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's absorb spells"], win.actorname or L.Unknown)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.absorb or 0

		if total > 0 and player.absorbspells then
			local nr = 0
			for spellid, spell in pairs(player.absorbspells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.spellschool = spell.school
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = spell.amount
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Absorbs and Skada:FormatNumber(d.value),
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's absorbed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's absorbed targets"], win.actorname or L.Unknown)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.absorb or 0
		local targets = (total > 0) and player:GetAbsorbTargets()

		if targets then
			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.text = target.id and Skada:FormatName(targetname, target.id)
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.amount
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Absorbs and Skada:FormatNumber(d.value),
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Absorbs"], L[win.class]) or L["Absorbs"]

		local total = set and set:GetAbsorb() or 0
		if total > 0 then
			local nr = 0
			for _, player in ipairs(set.players) do
				if not win.class or win.class == player.class then
					local aps, amount = player:GetAPS()
					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						d.value = amount
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.Absorbs and Skada:FormatNumber(d.value),
							self.metadata.columns.HPS and  Skada:FormatNumber(aps),
							self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
						)

						if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end
		end
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = playermod_tooltip}
		targetmod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod, targetmod},
			columns = {Absorbs = true, HPS = true, Percent = true},
			icon = [[Interface\Icons\spell_holy_powerwordshield]]
		}

		local flags_src = {src_is_interesting_nopets = true}

		Skada:RegisterForCL(
			HandleShield,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_REMOVED",
			flags_src
		)

		Skada:RegisterForCL(
			SpellHeal,
			"SPELL_HEAL",
			"SPELL_PERIODIC_HEAL",
			flags_src
		)

		local flags_dst = {dst_is_interesting_nopets = true}

		Skada:RegisterForCL(
			SpellDamage,
			"DAMAGE_SHIELD",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"RANGE_DAMAGE",
			"SWING_DAMAGE",
			flags_dst
		)

		Skada:RegisterForCL(
			EnvironmentDamage,
			"ENVIRONMENTAL_DAMAGE",
			flags_dst
		)

		Skada:RegisterForCL(
			SpellMissed,
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SPELL_BUILDING_MISSED",
			"RANGE_MISSED",
			"SWING_MISSED",
			flags_dst
		)

		Skada.RegisterCallback(self, "Skada_ZoneCheck", "ZoneModifier")
		Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER", "CheckPreShields")
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		if not set then return end
		local aps, amount = set:GetAPS()
		return Skada:FormatValueCols(
			self.metadata.columns.Absorbs and Skada:FormatNumber(amount),
			self.metadata.columns.HPS and Skada:FormatNumber(aps)
		), amount
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
		heals = heals or T.get("Absorbs_Heals")
		shields = shields or T.get("Absorbs_Shields")
		shieldamounts = shieldamounts or T.get("Absorbs_ShieldAmounts")
		shieldspopped = shieldspopped or T.get("Absorbs_ShieldsPopped")
	end

	function mod:SetComplete(set)
		T.clear(absorb)
		T.free("Absorbs_Heals", heals)
		T.free("Absorbs_Shields", shields)
		T.free("Absorbs_ShieldAmounts", shieldamounts)
		T.free("Absorbs_ShieldsPopped", shieldspopped)
		-- clean absorbspells table:
		if (set.absorb or 0) == 0 then return end
		for _, p in ipairs(set.players) do
			if p.absorb and p.absorb == 0 then
				p.absorbspells = nil
			elseif p.absorbspells then
				for spellid, spell in pairs(p.absorbspells) do
					if spell.amount == 0 then
						p.absorbspells[spellid] = nil
					end
				end
				if next(p.absorbspells) == nil then
					p.absorbspells = nil
				end
			end
		end
	end
end)

-- ========================== --
-- Absorbs and healing module --
-- ========================== --

Skada:AddLoadableModule("Absorbs and Healing", function(L)
	if Skada:IsDisabled("Healing", "Absorbs", "Absorbs and Healing") then return end

	local mod = Skada:NewModule(L["Absorbs and Healing"])
	local playermod = mod:NewModule(L["Absorbs and healing spells"])
	local targetmod = mod:NewModule(L["Absorbed and healed targets"])
	local spellmod = targetmod:NewModule(L["Absorbs and healing spells"])

	local function hps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local player = set and set:GetActor(label, id)
		if player then
			local totaltime = set:GetTime()
			local activetime = player:GetTime()
			local hps, amount = 0, 0
			if player.GetAHPS then
				hps, amount = player:GetAHPS()
			elseif player.GetHPS then
				hps, amount = player:GetHPS()
			end
			tooltip:AddLine(player.name .. " - " .. L["HPS"])
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(set:GetTime()), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(player:GetTime(true)), 1, 1, 1)
			tooltip:AddDoubleLine(L["Absorbs and Healing"], format("%s (%s)", Skada:FormatNumber(hps), Skada:FormatPercent(hps, amount)), 1, 1, 1)
			tooltip:AddDoubleLine(Skada:FormatNumber(amount) .. "/" .. Skada:FormatTime(activetime), Skada:FormatNumber(hps), 1, 1, 1)
		end
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local spell = player and ((player.absorbspells and player.absorbspells[id]) or (player.healspells and player.healspells[id]))
		if spell then
			tooltip:AddLine(player.name .. " - " .. label)
			if spell.school and Skada.spellschools[spell.school] then
				tooltip:AddLine(
					Skada.spellschools[spell.school].name,
					Skada.spellschools[spell.school].r,
					Skada.spellschools[spell.school].g,
					Skada.spellschools[spell.school].b
				)
			end

			if (spell.casts or 0) > 0 then
				tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
			end

			if (spell.count or 0) > 0 then
				tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)

				if (spell.critical or 0) > 0 then
					tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.critical, spell.count), 1, 1, 1)
				end
			end

			if (spell.overheal or 0) > 0 then
				tooltip:AddLine(" ")
				tooltip:AddDoubleLine(L["Total Healing"], Skada:FormatNumber(spell.overheal + spell.amount), 1, 1, 1)
				tooltip:AddDoubleLine(L["Overhealing"], format("%s (%s)", Skada:FormatNumber(spell.overheal), Skada:FormatPercent(spell.overheal, spell.overheal + spell.amount)), 1, 1, 1)
			end

			if spell.min and spell.max then
				local spellmin = spell.min
				if spell.criticalmin and spell.criticalmin < spellmin then
					spellmin = spell.criticalmin
				end
				local spellmax = spell.max
				if spell.criticalmax and spell.criticalmax > spellmax then
					spellmax = spell.criticalmax
				end
				tooltip:AddLine(" ")
				tooltip:AddDoubleLine(L["Minimum Hit"], Skada:FormatNumber(spellmin), 1, 1, 1)
				tooltip:AddDoubleLine(L["Maximum Hit"], Skada:FormatNumber(spellmax), 1, 1, 1)
				tooltip:AddDoubleLine(L["Average Hit"], Skada:FormatNumber((spellmin + spellmax) / 2), 1, 1, 1)
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's absorbs and healing on %s"], win.actorname or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's absorbs and healing on %s"], win.actorname or L.Unknown, win.targetname or L.Unknown)
		if not win.targetname then return end

		local actor, enemy = set and set:GetPlayer(win.actorid, win.actorname)
		if not actor and set and Skada.forPVP and set.type == "arena" then
			actor, enemy = set:GetEnemy(win.actorname, win.actorid)
		end

		local total = actor and actor:GetAbsorbHealOnTarget(win.targetname) or 0
		if total > 0 then
			local nr = 0
			if actor.healspells then
				for spellid, spell in pairs(actor.healspells) do
					if spell.targets and spell.targets[win.targetname] then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellid
						d.spellid = spellid
						d.spellschool = spell.school
						d.label, _, d.icon = GetSpellInfo(spellid)

						if spell.ishot then
							d.text = d.label .. L["HoT"]
						end

						if enemy then
							d.value = spell.targets[win.targetname]
						else
							d.value = spell.targets[win.targetname].amount or 0
						end

						d.valuetext = Skada:FormatValueCols(
							mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
							mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
						)

						if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end

			if actor.absorbspells then
				for spellid, spell in pairs(actor.absorbspells) do
					if spell.targets and spell.targets[win.targetname] then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellid
						d.spellid = spellid
						d.spellschool = spell.school
						d.label, _, d.icon = GetSpellInfo(spellid)

						d.value = spell.targets[win.targetname] or 0
						d.valuetext = Skada:FormatValueCols(
							mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
							mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
						)

						if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's absorb and healing spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's absorb and healing spells"], win.actorname or L.Unknown)
		if not win.actorname then return end

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHeal() or 0

		if total > 0 and (actor.healspells or actor.absorbspells) then
			local nr = 0
			if actor.healspells then
				for spellid, spell in pairs(actor.healspells) do
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)

					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					d.value = spell.amount
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
						win.metadata.maxvalue = d.value
					end
				end
			end

			if actor.absorbspells then
				for spellid, spell in pairs(actor.absorbspells) do
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)

					d.value = spell.amount
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's absorbed and healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's absorbed and healed targets"], win.actorname or L.Unknown)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetAbsorbHeal() or 0
		local targets = (total > 0) and actor:GetAbsorbHealTargets()

		if targets then
			local nr = 0
			for targetname, target in pairs(targets) do
				if target.amount > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class = target.class
					d.role = target.role
					d.spec = target.spec

					d.value = target.amount
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Absorbs and Healing"], L[win.class]) or L["Absorbs and Healing"]

		local total = set and set:GetAbsorbHeal() or 0
		if total > 0 then
			local nr = 0

			-- players
			for _, player in ipairs(set.players) do
				if not win.class or win.class == player.class then
					local hps, amount = player:GetAHPS()

					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						if Skada.forPVP and set.type == "arena" then
							d.color = set.gold and Skada.classcolors.ARENA_GOLD or Skada.classcolors.ARENA_GREEN
						end

						d.value = amount
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.Healing and Skada:FormatNumber(d.value),
							self.metadata.columns.HPS and Skada:FormatNumber(hps),
							self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
						)

						if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end

			-- arena enemies
			if Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyHeal then
				for _, enemy in ipairs(set.enemies) do
					if not win.class or win.class == enemy.class then
						local hps, amount = enemy:GetHPS()

						if amount > 0 then
							nr = nr + 1

							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = enemy.id or enemy.name
							d.label = enemy.name
							d.text = nil
							d.class = enemy.class
							d.role = enemy.role
							d.spec = enemy.spec
							d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.ARENA_GOLD

							d.value = amount
							d.valuetext = Skada:FormatValueCols(
								self.metadata.columns.Healing and Skada:FormatNumber(d.value),
								self.metadata.columns.HPS and Skada:FormatNumber(hps),
								self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
							)

							if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
								win.metadata.maxvalue = d.value
							end
						end
					end
				end
			end
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
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			post_tooltip = hps_tooltip,
			nototalclick = {playermod, targetmod},
			columns = {Healing = true, HPS = true, Percent = true},
			icon = [[Interface\Icons\spell_holy_healingfocus]]
		}

		Skada:AddFeed(L["Healing: Personal HPS"], feed_personal_hps)
		Skada:AddFeed(L["Healing: Raid HPS"], feed_raid_hps)

		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveFeed(L["Healing: Personal HPS"])
		Skada:RemoveFeed(L["Healing: Raid HPS"])
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if not set then return end
		local hps, amount = set:GetAHPS()
		if amount > 0 then
			tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(amount), 1, 1, 1)
			tooltip:AddDoubleLine(L["HPS"], Skada:FormatNumber(hps), 1, 1, 1)
		end
		if (set.overheal or 0) > 0 then
			amount = amount + set.overheal
			tooltip:AddDoubleLine(L["Overhealing"], Skada:FormatPercent(set.overheal, amount), 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		if not set then return end
		local hps, amount = set:GetAHPS()
		return Skada:FormatValueCols(
			self.metadata.columns.Healing and Skada:FormatNumber(amount),
			self.metadata.columns.HPS and Skada:FormatNumber(hps)
		), amount
	end
end)

-- ============================== --
-- Healing done per second module --
-- ============================== --

Skada:AddLoadableModule("HPS", function(L)
	if Skada:IsDisabled("Absorbs", "Healing", "Absorbs and Healing", "HPS") then return end

	local mod = Skada:NewModule(L["HPS"])

	local function hps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local player = set and set:GetActor(label, id)
		if player then
			local totaltime = set:GetTime()
			local activetime = player:GetTime()
			local hps, amount = 0
			if player.GetAHPS then
				hps, amount = player:GetAHPS()
			elseif player.GetHPS then
				hps, amount = player:GetHPS()
			end
			tooltip:AddLine(player.name .. " - " .. L["HPS"])
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(set:GetTime()), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(player:GetTime(true)), 1, 1, 1)
			tooltip:AddDoubleLine(L["Absorbs and Healing"], format("%s (%s)", Skada:FormatNumber(hps), Skada:FormatPercent(hps, amount)), 1, 1, 1)
			tooltip:AddDoubleLine(Skada:FormatNumber(amount) .. "/" .. Skada:FormatTime(activetime), Skada:FormatNumber(hps), 1, 1, 1)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["HPS"], L[win.class]) or L["HPS"]

		local total = set and set:GetAHPS() or 0
		if total > 0 then
			local nr = 0

			-- players
			for _, player in ipairs(set.players) do
				if not win.class or win.class == player.class then
					local amount = player:GetAHPS()
					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						if Skada.forPVP and set.type == "arena" then
							d.color = set.gold and Skada.classcolors.ARENA_GOLD or Skada.classcolors.ARENA_GREEN
						end

						d.value = amount
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.HPS and Skada:FormatNumber(d.value),
							self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
						)

						if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end

			-- arena enemies
			if Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyHeal then
				for _, enemy in ipairs(set.enemies) do
					if not win.class or win.class == enemy.class then
						local amount = enemy:GetHPS()
						if amount > 0 then
							nr = nr + 1

							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = enemy.id or enemy.name
							d.label = enemy.name
							d.text = nil
							d.class = enemy.class
							d.role = enemy.role
							d.spec = enemy.spec
							d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.ARENA_GOLD

							d.value = amount
							d.valuetext = Skada:FormatValueCols(
								self.metadata.columns.HPS and Skada:FormatNumber(d.value),
								self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
							)

							if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
								win.metadata.maxvalue = d.value
							end
						end
					end
				end
			end
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			tooltip = hps_tooltip,
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			columns = {HPS = true, Percent = true},
			icon = [[Interface\Icons\spell_nature_rejuvenation]]
		}

		local parentmod = Skada:GetModule(L["Absorbs and Healing"], true)
		if parentmod then
			self.metadata.click1 = parentmod.metadata.click1
			self.metadata.click2 = parentmod.metadata.click2
			self.metadata.nototalclick = parentmod.metadata.nototalclick
		end

		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set and set:GetAHPS() or 0)
	end
end)

-- ===================== --
-- Healing done by spell --
-- ===================== --

Skada:AddLoadableModule("Healing Done By Spell", function(L)
	if Skada:IsDisabled("Healing", "Absorbs", "Healing Done By Spell") then return end

	local mod = Skada:NewModule(L["Healing Done By Spell"])
	local spellmod = mod:NewModule(L["Healing spell sources"])
	local cacheTable = Skada.cacheTable

	local function spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local total = set and set:GetAbsorbHeal() or 0
		if total == 0 then return end

		wipe(cacheTable)
		for _, p in ipairs(set.players) do
			local spell = (p.absorbspells and p.absorbspells[id]) or (p.healspells and p.healspells[id])
			if spell then
				if not cacheTable[id] then
					cacheTable[id] = {school = spell.school, amount = spell.amount}
					cacheTable[id].isabsorb = (p.absorbspells and p.absorbspells[id])
				else
					cacheTable[id].amount = cacheTable[id].amount + spell.amount
				end
			end
		end

		local spell = cacheTable[id]
		if spell then
			tooltip:AddLine(GetSpellInfo(id))
			if spell.school and Skada.spellschools[spell.school] then
				tooltip:AddLine(
					Skada.spellschools[spell.school].name,
					Skada.spellschools[spell.school].r,
					Skada.spellschools[spell.school].g,
					Skada.spellschools[spell.school].b
				)
			end

			if (spell.casts or 0) > 0 then
				tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
			end

			if (spell.count or 0) > 0 then
				tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
			end
			tooltip:AddDoubleLine(spell.isabsorb and L["Absorbs"] or L["Healing"], format("%s (%s)", Skada:FormatNumber(spell.amount), Skada:FormatPercent(spell.amount, total)), 1, 1, 1)
			if (spell.overheal or 0) > 0 then
				local overheal = set.overheal or 1
				tooltip:AddDoubleLine(L["Overhealing"], format("%s (%s)", Skada:FormatNumber(spell.overheal), Skada:FormatPercent(spell.overheal, overheal)), 1, 1, 1)
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's sources"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's sources"], win.spellname or L.Unknown)
		if not (win.spellid and set) then return end

		-- let's go...
		wipe(cacheTable)
		local total = 0

		for _, p in ipairs(set.players) do
			local spell = (p.absorbspells and p.absorbspells[win.spellid]) or (p.healspells and p.healspells[win.spellid])
			if spell then
				cacheTable[p.name] = {
					id = p.id,
					class = p.class,
					role = p.role,
					spec = p.spec,
					amount = spell.amount
				}
				-- calculate the total.
				total = total + spell.amount
			end
		end

		if total > 0 then
			local nr = 0
			for playername, player in pairs(cacheTable) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id or playername
				d.label = playername
				d.text = player.id and Skada:FormatName(playername, player.id)
				d.class = player.class
				d.role = player.role
				d.spec = player.spec

				d.value = player.amount
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing Done By Spell"]
		local total = set and set:GetAbsorbHeal() or 0
		local spells = (total > 0) and set:GetAbsorbHealSpells()

		if spells then
			local nr = 0
			for spellid, spell in pairs(spells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.spellschool = spell.school
				d.label, _, d.icon = GetSpellInfo(spellid)

				if spell.ishot then
					d.text = d.label .. L["HoT"]
				end

				d.value = spell.amount
				d.valuetext = Skada:FormatValueCols(
					self.metadata.columns.Healing and Skada:FormatNumber(d.value),
					self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {showspots = true}
		self.metadata = {
			click1 = spellmod,
			post_tooltip = spell_tooltip,
			columns = {Healing = true, Percent = true},
			icon = [[Interface\Icons\spell_nature_healingwavelesser]]
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	local setPrototype = Skada.setPrototype

	function setPrototype:GetAbsorbHealSpells(tbl)
		if (self.absorb or self.heal) and self.players then
			tbl = wipe(tbl or cacheTable)
			for _, player in ipairs(self.players) do
				if player.healspells then
					for spellid, spell in pairs(player.healspells) do
						if not tbl[spellid] then
							tbl[spellid] = {school = spell.school, amount = spell.amount}
						else
							tbl[spellid].amount = tbl[spellid].amount + spell.amount
						end
					end
				end
				if player.absorbspells then
					for spellid, spell in pairs(player.absorbspells) do
						if not tbl[spellid] then
							tbl[spellid] = {school = spell.school, amount = spell.amount}
						else
							tbl[spellid].amount = tbl[spellid].amount + spell.amount
						end
					end
				end
			end
		end

		return tbl
	end
end)