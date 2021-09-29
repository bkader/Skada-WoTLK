assert(Skada, "Skada not found!")

-- cache frequently used globals
local pairs, ipairs, select, format = pairs, ipairs, select, string.format
local max, min, floor = math.max, math.min, math.floor
local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local UnitGUID, UnitClass = UnitGUID, Skada.UnitClass
local newTable, delTable = Skada.newTable, Skada.delTable
local _

-- ============== --
-- Absorbs module --
-- ============== --

Skada:AddLoadableModule("Absorbs", function(Skada, L)
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
	local tinsert, tsort, tContains = table.insert, table.sort, tContains

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

	local priest_divine_aegis = {47509, 47511, 47515, 47753, 54704} -- Divine Aegis
	local mage_fire_ward = {543, 8457, 8458, 10223, 10225, 27128, 43010} -- Fire Ward
	local mage_frost_ward = {6143, 8461, 8462, 10177, 28609, 32796, 43012} -- Frost Ward
	local mage_ice_barrier = {11426, 13031, 13032, 13033, 27134, 33405, 43038, 43039} -- Ice Barrier
	local warlock_shadow_ward = {6229, 11739, 11740, 28610, 47890, 47891} -- Shadow Ward
	local warlock_sacrifice = {7812, 19438, 19440, 19441, 19442, 19443, 27273, 47985, 47986} -- Sacrifice

	local zoneModifier = 1
	local heals, shields, shieldamounts

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_absorb(set, playerid, playername, dstGUID, dstName, spellid, spellschool, amount, nocount)
		if (spellid and tContains(ignoredSpells, spellid)) or (amount or 0) <= 0 then return end

		local player = Skada:get_player(set, playerid, playername)
		if player then
			Skada:AddActiveTime(player, (player.role ~= "DAMAGER" and not nocount))

			-- add absorbs amount
			player.absorb = (player.absorb or 0) + amount
			set.absorb = (set.absorb or 0) + amount

			-- record the spell
			local spell = player.absorb_spells and player.absorb_spells[spellid]
			if not spell then
				player.absorb_spells = player.absorb_spells or {}
				spell = {count = 1, amount = amount, school = spellschool}
				player.absorb_spells[spellid] = spell
			else
				if not spell.school and spellschool then
					spell.school = spellschool
				end
				spell.amount = (spell.amount or 0) + amount
				if not nocount then
					spell.count = (spell.count or 0) + 1
				end
			end

			if not spell.min or amount < spell.min then
				spell.min = amount
			end
			if not spell.max or amount > spell.max then
				spell.max = amount
			end

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.current and dstName then
				-- spell targets
				local target = spell.targets and spell.targets[dstName]
				if not target then
					spell.targets = spell.targets or {}
					spell.targets[dstName] = {id = dstGUID, amount = amount}
					target = spell.targets[dstName]
				else
					target.id = target.id or dstGUID -- GUID fix
					target.amount = target.amount + amount
				end

				-- player targets
				target = player.absorb_targets and player.absorb_targets[dstName]
				if not target then
					player.absorb_targets = player.absorb_targets or {}
					player.absorb_targets[dstName] = {id = dstGUID, amount = amount}
					target = player.absorb_targets[dstName]
				else
					target.id = target.id or dstGUID -- GUID fix
					target.amount = target.amount + amount
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
		if tContains(mage_frost_ward, a_spellid) then
			return false
		end
		if tContains(mage_frost_ward, b_spellid) then
			return true
		end

		-- Fire Ward
		if tContains(mage_fire_ward, a_spellid) then
			return false
		end
		if tContains(mage_fire_ward, b_spellid) then
			return true
		end

		-- Shadow Ward
		if tContains(warlock_shadow_ward, a_spellid) then
			return false
		end
		if tContains(warlock_shadow_ward, b_spellid) then
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
		if tContains(priest_divine_aegis, a_spellid) then
			return false
		end
		if tContains(priest_divine_aegis, b_spellid) then
			return true
		end

		-- Ice Barrier
		if tContains(mage_ice_barrier, a_spellid) then
			return false
		end
		if tContains(mage_ice_barrier, b_spellid) then
			return true
		end

		-- Sacrifice
		if tContains(warlock_sacrifice, a_spellid) then
			return false
		end
		if tContains(warlock_sacrifice, b_spellid) then
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

	local function AuraApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, _, spellschool, _, points = ...
		if absorbspells[spellid] and dstName then
			shields[dstName] = shields[dstName] or {}
			shields[dstName][spellid] = shields[dstName][spellid] or {}

			-- we calculate how much the shield's maximum absorb amount
			local amount = 0

			-- Stackable Shields
			if (tContains(priest_divine_aegis, spellid) or spellid == 64413) then
				if shields[dstName][spellid][srcName] and timestamp < shields[dstName][spellid][srcName].ts then
					amount = shields[dstName][spellid][srcName].amount
				end
			end

			if tContains(priest_divine_aegis, spellid) then -- Divine Aegis
				if heals[dstName] and heals[dstName][srcName] and heals[dstName][srcName].ts > timestamp - 0.2 then
					amount = min((UnitLevel(srcName) or 80) * 125, amount + (heals[dstName][srcName].amount * 0.3 * zoneModifier))
				end
			elseif spellid == 64413 then -- Protection of Ancient Kings (Vala'nyr)
				if heals[dstName] and heals[dstName][srcName] and heals[dstName][srcName].ts > timestamp - 0.2 then
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
				spellid = spellid,
				school = spellschool,
				points = points,
				amount = floor(amount),
				ts = timestamp + absorbspells[spellid].dur + 0.1,
				full = true
			}
		end
	end

	local function AuraRemoved(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...
		if absorbspells[spellid] and shields[dstName] and shields[dstName][spellid] and shields[dstName][spellid][srcName] then
			shields[dstName][spellid][srcName].ts = timestamp + 0.1
		end
	end

	do
		-- some effects aren't shields but rather special effects, such us talents.
		-- in order to track them, we simply add them as fake shields before all.
		-- I don't know the whole list of effects but, if you want to add yours
		-- please do : CLASS = {[index] = {spellid, spellschool}}
		local passivespells = {
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
							AuraApplied(timestamp + expires - curtime, nil, UnitGUID(unitCaster), UnitName(unitCaster), nil, dstGUID, dstName, nil, spellid)
						end
					else
						break -- nothing found
					end
				end

				-- passive shields (not for pets)
				if owner == nil then
					local class = select(2, _G.UnitClass(unit))
					if passivespells[class] then
						for _, spell in ipairs(passivespells[class]) do
							local points = LGT:GUIDHasTalent(dstGUID, GetSpellInfo(spell[1]), LGT:GetActiveTalentGroup(unit))
							if points then
								AuraApplied(timestamp - 60, nil, dstGUID, dstGUID, nil, dstGUID, dstName, nil, spell[1], nil, spell[2], nil, points)
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

	local function process_absorb(timestamp, dstGUID, dstName, absorbed, spellschool, damage, broke)
		shields[dstName] = shields[dstName] or {}
		local shieldsPopped = newTable()
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
					elseif tContains(mage_frost_ward, spellid) and band(spellschool, 0x10) ~= spellschool then
						-- nothing
					-- Fire Ward vs Fire Damage
					elseif tContains(mage_fire_ward, spellid) and band(spellschool, 0x4) ~= spellschool then
						-- nothing
					-- Shadow Ward vs Shadow Damage
					elseif tContains(warlock_shadow_ward, spellid) and band(spellschool, 0x20) ~= spellschool then
						-- nothing
					-- Anti-Magic, Spell Deflection, Savage Defense
					elseif (spellid == 48707 or spellid == 49497 or spellid == 62606) and band(spellschool, 0x1) == spellschool then
						-- nothing
					else
						tinsert(shieldsPopped, {
							srcGUID = shield.srcGUID,
							srcName = srcName,
							spellid = shield.spellid,
							school = shield.school,
							points = shield.points,
							ts = shield.ts - absorbspells[shield.spellid].dur,
							amount = shield.amount,
							full = shield.full
						})
						count = count + 1
					end
				end
			end
		end

		-- the player has no shields, so nothing to do.
		if count <= 0 then return end

		-- if the player has a single shield and it broke, we update its max absorb
		if count == 1 and broke and shieldsPopped[1].full and absorbspells[shieldsPopped[1].spellid].cap then
			local s = shieldsPopped[1]
			shieldamounts[s.srcName] = shieldamounts[s.srcName] or {}
			if (not shieldamounts[s.srcName][s.spellid] or shieldamounts[s.srcName][s.spellid] < absorbed) and absorbed < (absorbspells[s.spellid].cap * zoneModifier) then
				shieldamounts[s.srcName][s.spellid] = absorbed
			end
		end

		-- we loop through available shields and make sure to update
		-- their maximum absorb values.
		for _, s in ipairs(shieldsPopped) do
			if s.full and shieldamounts[s.srcName] and shieldamounts[s.srcName][s.spellid] then
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

		tsort(shieldsPopped, SortShields)

		local amount = absorbed
		local pshield = nil
		for i = #shieldsPopped, 0, -1 do
			-- no shield left to check?
			if i == 0 then
				-- if we still have an absorbed amount running and there is
				-- a previous shield, we attributed dumbly to it.
				-- the "true" at the end is so we don't update the spell count or active time.
				if amount > 0 and pshield then
					log_absorb(Skada.current, pshield.srcGUID, pshield.srcName, dstGUID, dstName, pshield.spellid, pshield.school, amount, true)
					log_absorb(Skada.total, pshield.srcGUID, pshield.srcName, dstGUID, dstName, pshield.spellid, pshield.school, amount, true)
				end
				break
			end

			local s = shieldsPopped[i]
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
				log_absorb(Skada.current, s.srcGUID, s.srcName, dstGUID, dstName, s.spellid, s.school, amount)
				log_absorb(Skada.total, s.srcGUID, s.srcName, dstGUID, dstName, s.spellid, s.school, amount)
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
				log_absorb(Skada.current, s.srcGUID, s.srcName, dstGUID, dstName, s.spellid, s.school, s.amount)
				log_absorb(Skada.total, s.srcGUID, s.srcName, dstGUID, dstName, s.spellid, s.school, s.amount)
				amount = amount - s.amount
			end
		end

		delTable(shieldsPopped)
	end

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellschool, amount, _, _, _, _, absorbed = select(3, ...)
		if (absorbed or 0) > 0 and dstName and shields[dstName] then
			process_absorb(timestamp, dstGUID, dstName, absorbed, spellschool, amount, amount > absorbed)
		end
	end

	local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, nil, 1, ...)
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellschool, misstype, absorbed = select(3, ...)
		if misstype == "ABSORB" and (absorbed or 0) > 0 and dstName and shields[dstName] then
			process_absorb(timestamp, dstGUID, dstName, absorbed, spellschool, 0, false)
		end
	end

	local function SwingMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, nil, 1, ...)
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

			process_absorb(timestamp, dstGUID, dstName, absorbed, spellschool, amount, amount > absorbed)
		end
	end

	local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		heals[dstName] = heals[dstName] or {}
		heals[dstName][srcName] = {ts = timestamp, amount = select(4, ...)}
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), win.playerid, win.playername)
		if player then
			local spell = player.absorb_spells and player.absorb_spells[id]

			if spell then
				tooltip:AddLine(player.name .. " - " .. label)
				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
				end
				if (spell.count or 0) > 0 then
					tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
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
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's absorbs on %s"], win.playername or UNKNOWN, label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's absorbs on %s"], player.name, win.targetname or UNKNOWN)

			local total = 0
			if player.absorb_targets and win.targetname and player.absorb_targets[win.targetname] then
				total = player.absorb_targets[win.targetname].amount
			end

			if total > 0 and player.absorb_spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.absorb_spells) do
					if spell.targets and spell.targets[win.targetname] then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellid
						d.spellid = spellid
						d.spellschool = spell.school
						d.label, _, d.icon = GetSpellInfo(spellid)

						d.value = spell.targets[win.targetname].amount or 0
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Absorbs,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
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
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's absorb spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's absorb spells"], player.name)
			local total = player.absorb or 0

			if total > 0 and player.absorb_spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.absorb_spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)

					d.value = spell.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Absorbs,
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
		win.title = format(L["%s's absorbed targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's absorbed targets"], player.name)
			local total = player.absorb or 0

			if total > 0 and player.absorb_targets then
				local maxvalue, nr = 0, 1

				for targetname, target in pairs(player.absorb_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = select(2, UnitClass(d.id, nil, set))

					d.value = target.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Absorbs,
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
		win.title = L["Absorbs"]
		local total = set.absorb or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.absorb or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.absorb
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Absorbs,
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
		playermod.metadata = {tooltip = playermod_tooltip}
		targetmod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Absorbs = true, Percent = true},
			icon = "Interface\\Icons\\spell_holy_powerwordshield"
		}

		Skada:RegisterForCL(AuraApplied, "SPELL_AURA_APPLIED", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(AuraApplied, "SPELL_AURA_REFRESH", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(AuraRemoved, "SPELL_AURA_REMOVED", {src_is_interesting_nopets = true})
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

		Skada:RegisterForCL(SpellHeal, "SPELL_HEAL", {src_is_interesting = true})
		Skada:RegisterForCL(SpellHeal, "SPELL_PERIODIC_HEAL", {src_is_interesting = true})

		Skada.RegisterCallback(self, "SKADA_ZONE_CHECK", "ZoneModifier")
		Skada.RegisterCallback(self, "COMBAT_PLAYER_ENTER", "CheckPreShields")
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.absorb or 0), set.absorb or 0
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
		heals = newTable()
		shields = newTable()
		shieldamounts = newTable()
	end

	function mod:SetComplete(set)
		delTable(heals)
		delTable(shields)
		delTable(shieldamounts)
	end
end)

-- ========================== --
-- Absorbs and healing module --
-- ========================== --

Skada:AddLoadableModule("Absorbs and Healing", function(Skada, L)
	if Skada:IsDisabled("Healing", "Absorbs", "Absorbs and Healing") then return end

	local mod = Skada:NewModule(L["Absorbs and Healing"])
	local playermod = mod:NewModule(L["Absorbs and healing spells"])
	local targetmod = mod:NewModule(L["Absorbed and healed targets"])
	local spellmod = targetmod:NewModule(L["Absorbs and healing spells"])

	local function getHPS(set, player)
		local amount = (player.heal or 0) + (player.absorb or 0)
		return amount / max(1, Skada:PlayerActiveTime(set, player)), amount
	end
	mod.getHPS = getHPS

	local function getRaidHPS(set)
		local amount = (set.heal or 0) + (set.absorb or 0)
		return amount / max(1, Skada:GetSetTime(set)), amount
	end
	mod.getRaidHPS = getRaidHPS

	local function hps_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		local player = Skada:find_player(set, id)
		if player then
			tooltip:AddLine(player.name .. " - " .. L["HPS"])
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(Skada:GetSetTime(set)), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(Skada:PlayerActiveTime(set, player, true)), 1, 1, 1)

			local amount = (player.heal or 0) + (player.absorb or 0)
			local total = (set.heal or 0) + (set.absorb or 0)
			tooltip:AddDoubleLine(L["Absorbs and Healing"], format("%s (%02.1f%%)", Skada:FormatNumber(amount), 100 * amount / max(1, total)), 1, 1, 1)
		end
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), win.playerid, win.playername)
		if player then
			local spell = player.heal_spells and player.heal_spells[id]
			spell = spell or player.absorb_spells and player.absorb_spells[id]

			if spell then
				tooltip:AddLine(player.name .. " - " .. label)

				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
				end
				if (spell.count or 0) > 0 then
					tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
				end
				if spell.min and spell.max then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
				end
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
				if (spell.critical or 0) > 0 then
					tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.critical, spell.count), 1, 1, 1)
				end
				if (spell.overheal or 0) > 0 then
					tooltip:AddDoubleLine(L["Overhealing"], Skada:FormatPercent(spell.overheal, spell.overheal + spell.amount), 1, 1, 1)
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's absorbs and healing on %s"], win.playername or UNKNOWN, label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player and win.targetname then
			win.title = format(L["%s's absorbs and healing on %s"], player.name, win.targetname or UNKNOWN)

			local total = 0
			if player.heal_targets and player.heal_targets[win.targetname] then
				total = player.heal_targets[win.targetname].amount
			end
			if player.absorb_targets and player.absorb_targets[win.targetname] then
				total = player.absorb_targets[win.targetname].amount
			end

			if total > 0 then
				local maxvalue, nr = 0, 1

				if player.heal_spells then
					for spellid, spell in pairs(player.heal_spells) do
						if spell.targets and spell.targets[win.targetname] then
							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = spellid
							d.spellid = spellid
							d.spellschool = spell.school
							d.label, _, d.icon = GetSpellInfo(spellid)
							if spell.ishot then
								d.text = d.label .. L["HoT"]
							end

							d.value = spell.targets[win.targetname].amount or 0
							d.valuetext = Skada:FormatValueText(
								Skada:FormatNumber(d.value),
								mod.metadata.columns.Healing,
								Skada:FormatPercent(d.value, total),
								mod.metadata.columns.Percent
							)

							if d.value > maxvalue then
								maxvalue = d.value
							end
							nr = nr + 1
						end
					end
				end

				if player.absorb_spells then
					for spellid, spell in pairs(player.absorb_spells) do
						if spell.targets and spell.targets[win.targetname] then
							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = spellid
							d.spellid = spellid
							d.spellschool = spell.school
							d.label, _, d.icon = GetSpellInfo(spellid)

							d.value = spell.targets[win.targetname].amount or 0
							d.valuetext = Skada:FormatValueText(
								Skada:FormatNumber(d.value),
								mod.metadata.columns.Healing,
								Skada:FormatPercent(d.value, total),
								mod.metadata.columns.Percent
							)

							if d.value > maxvalue then
								maxvalue = d.value
							end
							nr = nr + 1
						end
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's absorb and healing spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's absorb and healing spells"], player.name)

			local total = (player.heal or 0) + (player.absorb or 0)

			if total > 0 then
				local maxvalue, nr = 0, 1

				if player.heal_spells then
					for spellid, spell in pairs(player.heal_spells) do
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
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Healing,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				if player.absorb_spells then
					for spellid, spell in pairs(player.absorb_spells) do
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellid
						d.spellid = spellid
						d.spellschool = spell.school
						d.label, _, d.icon = GetSpellInfo(spellid)

						d.value = spell.amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Healing,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
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
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's absorbed and healed targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's absorbed and healed targets"], player.name)

			local total, targets = 0, {}

			if (player.heal or 0) > 0 and player.heal_targets then
				total = total + player.heal
				for targetname, target in pairs(player.heal_targets) do
					if not targets[targetname] then
						targets[targetname] = {id = target.id, amount = target.amount, overheal = target.overheal}
					else
						targets[targetname].amount = targets[targetname].amount + target.amount
						targets[targetname].overheal = targets[targetname].overheal + target.overheal
					end
				end
			end

			if (player.absorb or 0) > 0 and player.absorb_targets then
				total = total + player.absorb
				for targetname, target in pairs(player.absorb_targets) do
					if not targets[targetname] then
						targets[targetname] = {id = target.id, amount = target.amount, overheal = 0}
					else
						targets[targetname].amount = targets[targetname].amount + target.amount
					end
				end
			end

			if total > 0 then
				local maxvalue, nr = 0, 1

				for targetname, target in pairs(targets) do
					if target.amount > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = target.id or targetname
						d.label = targetname
						d.class, d.role, d.spec = select(2, UnitClass(d.id, target.flags, set))

						d.value = target.amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Healing,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
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
	end

	function mod:Update(win, set)
		win.title = L["Absorbs and Healing"]
		local total = select(2, getRaidHPS(set))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local hps, amount = getHPS(set, player)

				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Healing,
						Skada:FormatNumber(hps),
						self.metadata.columns.HPS,
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

	local function feed_personal_hps()
		if Skada.current then
			local player = Skada:find_player(Skada.current, Skada.userGUID)
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
		playermod.metadata = {tooltip = playermod_tooltip}
		targetmod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Healing = true, HPS = true, Percent = true},
			icon = "Interface\\Icons\\spell_holy_healingfocus"
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
		local hps, total = getRaidHPS(set)
		if total > 0 then
			tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(total), 1, 1, 1)
			tooltip:AddDoubleLine(L["HPS"], Skada:FormatNumber(hps), 1, 1, 1)
		end
		if (set.overheal or 0) > 0 then
			total = total + set.overheal
			tooltip:AddDoubleLine(L["Overhealing"], Skada:FormatPercent(set.overheal, total), 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		local hps, value = getRaidHPS(set)
		return Skada:FormatValueText(
			Skada:FormatNumber(value),
			self.metadata.columns.Healing,
			Skada:FormatNumber(hps),
			self.metadata.columns.HPS
		), value
	end
end)

-- ============================== --
-- Healing done per second module --
-- ============================== --

Skada:AddLoadableModule("HPS", function(Skada, L)
	if Skada:IsDisabled("Absorbs", "Healing", "Absorbs and Healing", "HPS") then return end

	local parentmod = Skada:GetModule(L["Absorbs and Healing"], true)
	local getHPS, getRaidHPS = parentmod.getHPS, parentmod.getRaidHPS

	local mod = Skada:NewModule(L["HPS"])

	local function hps_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		local player = Skada:find_player(set, id)
		if player then
			tooltip:AddLine(player.name .. " - " .. L["HPS"])
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(Skada:GetSetTime(set)), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(Skada:PlayerActiveTime(set, player, true)), 1, 1, 1)

			local amount = (player.heal or 0) + (player.absorb or 0)
			local total = (set.heal or 0) + (set.absorb or 0)
			tooltip:AddDoubleLine(L["Absorbs and Healing"], format("%s (%02.1f%%)", Skada:FormatNumber(amount), 100 * amount / max(1, total)), 1, 1, 1)
		end
	end

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
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.HPS,
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
			tooltip = hps_tooltip,
			click1 = parentmod.metadata.click1,
			click2 = parentmod.metadata.click2,
			nototalclick = {parentmod.metadata.click2},
			columns = {HPS = true, Percent = true},
			icon = "Interface\\Icons\\spell_nature_rejuvenation"
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
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
		spells = {}
		for _, player in ipairs(set.players) do
			if player.heal_spells then
				for spellid, spell in pairs(player.heal_spells) do
					if (spell.amount or 0) > 0 then
						if not spells[spellid] then
							spells[spellid] = {
								count = spell.count,
								school = spell.school,
								amount = spell.amount,
								overheal = spell.overheal,
								sources = {}
							}
						else
							spells[spellid].amount = spells[spellid].amount + spell.amount
							spells[spellid].count = (spells[spellid].count or 0) + (spell.count or 0)
							spells[spellid].overheal = (spells[spellid].overheal or 0) + spell.overheal
						end

						-- add spell source
						if not spells[spellid].sources[player.name] then
							spells[spellid].sources[player.name] = {
								id = player.id,
								class = player.class,
								role = player.role,
								spec = player.spec,
								count = spell.count,
								amount = spell.amount,
								overheal = spell.overheal
							}
						else
							spells[spellid].sources[player.name].count = spells[spellid].sources[player.name].count + spell.count
							spells[spellid].sources[player.name].amount = spells[spellid].sources[player.name].amount + spell.amount
							spells[spellid].sources[player.name].overheal = spells[spellid].sources[player.name].overheal + spell.amount
						end
					end
				end
			end
			if player.absorb_spells then
				for spellid, spell in pairs(player.absorb_spells) do
					if not spells[spellid] then
						spells[spellid] = {
							count = spell.count,
							school = spell.school,
							amount = spell.amount,
							overheal = 0,
							sources = {}
						}
					else
						spells[spellid].amount = spells[spellid].amount + spell.amount
						spells[spellid].count = (spells[spellid].count or 0) + (spell.count or 0)
					end

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
	end

	local function spell_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		if not set then return end

		if not spells then
			CacheSpells(set)
		end

		local spell = spells[id]
		if spell then
			local total = (set.heal or 0) + (set.absorb or 0)
			if total > 0 then
				local overheal = (set.overheal or 0)

				tooltip:AddLine(GetSpellInfo(id))
				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
				end

				if spell.count then
					tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
				end
				tooltip:AddDoubleLine(L["Healing"], format("%s (%02.1f%%)", Skada:FormatNumber(spell.amount), 100 * spell.amount / max(1, total)), 1, 1, 1)
				if spell.overheal > 0 then
					tooltip:AddDoubleLine(L["Overhealing"], format("%s (%02.1f%%)", Skada:FormatNumber(spell.overheal), 100 * spell.overheal / max(1, overheal)), 1, 1, 1)
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's sources"], label)
	end

	function spellmod:Update(win, set)
		local healing = (set.heal or 0) + (set.absorb or 0)
		if healing > 0 then
			CacheSpells(set)
			local spell = spells[win.spellid]
			if spell then
				win.title = format(L["%s's sources"], win.spellname or UNKNOWN)
				local maxvalue, nr = 0, 1

				for playername, player in pairs(spell.sources) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = playername
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Healing,
						Skada:FormatPercent(d.value, spell.amount),
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
		win.title = L["Healing Done By Spell"]
		local total = (set.heal or 0) + (set.absorb or 0)

		if total > 0 then
			CacheSpells(set)
			local maxvalue, nr = 0, 1

			for spellid, spell in pairs(spells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				local spellname, _, spellicon = GetSpellInfo(spellid)
				d.id = spellid
				d.spellid = spellid
				d.label = spellname
				d.text = spellname .. (spell.ishot and L["HoT"] or "")
				d.icon = spellicon
				d.spellschool = spell.school

				d.value = spell.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					self.metadata.columns.Healing,
					Skada:FormatPercent(d.value, total),
					self.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {showspots = true}
		self.metadata = {
			click1 = spellmod,
			post_tooltip = spell_tooltip,
			columns = {Healing = true, Percent = true},
			icon = "Interface\\Icons\\spell_nature_healingwavelesser"
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)