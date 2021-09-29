assert(Skada, "Skada not found!")

local Enemies = Skada:NewModule("Enemies")
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)

-- frequently used globals --
local pairs, ipairs, select = pairs, ipairs, select
local format, min, max = string.format, math.min, math.max
local UnitClass, GetSpellInfo = Skada.UnitClass, Skada.GetSpellInfo
local tContains = tContains
local _

function Skada:find_enemy(set, name)
	if set and name then
		set._enemyidx = set._enemyidx or {}

		local enemy = set._enemyidx[name]
		if enemy then
			return enemy
		end

		for _, e in pairs(set.enemies) do
			if e.name == name then
				set._enemyidx[name] = e
				return e
			end
		end
	end
end

function Skada:get_enemy(set, guid, name, flags)
	if set then
		local enemy = self:find_enemy(set, name)
		local now = time()

		if not enemy then
			if not name then return end

			enemy = {id = guid or name, name = name}

			if guid or flags then
				enemy.class = select(2, UnitClass(guid, flags, set))
			else
				enemy.class = "ENEMY"
			end

			tinsert(set.enemies, enemy)
		end

		self.changed = true
		return enemy
	end
end

local function EnemyClass(name, set)
	local class = "UNKNOWN"
	local e = Skada:find_enemy(set, name)
	if e and e.class then
		class = e.class
	end
	return class
end

function Enemies:CreateSet(_, set)
	if set and set.name == L["Current"] then
		set.enemies = set.enemies or {}
	end
end

function Enemies:ClearIndexes(_, set)
	if set then
		set._enemyidx = nil
	end
end

function Enemies:OnEnable()
	Skada.RegisterCallback(self, "SKADA_DATA_SETCREATED", "CreateSet")
	Skada.RegisterCallback(self, "SKADA_DATA_CLEARSETINDEX", "ClearIndexes")
end

function Enemies:OnDisable()
	Skada.UnregisterAllCallbacks(self)
end

---------------------------------------------------------------------------
-- Enemy Damage Taken

Skada:AddLoadableModule("Enemy Damage Taken", function(Skada, L)
	if Skada:IsDisabled("Enemy Damage Taken") then return end

	local mod = Skada:NewModule(L["Enemy Damage Taken"])
	local enemymod = mod:NewModule(L["Damage taken per player"])
	local spellmod = mod:NewModule(L["Damage spell details"])
	local damagemod, usefulmod

	local type, newTable, delTable = type, Skada.newTable, Skada.delTable
	local LBB = LibStub("LibBabble-Boss-3.0"):GetLookupTable()

	local instanceDiff, customGroupsTable, customUnitsTable, customUnitsInfo
	local UnitIterator, GetCreatureId = Skada.UnitIterator, Skada.GetCreatureId
	local UnitHealthInfo, UnitPowerInfo = Skada.UnitHealthInfo, Skada.UnitPowerInfo
	local UnitExists, UnitGUID = UnitExists, UnitGUID
	local UnitHealthMax, UnitPowerMax = UnitHealthMax, UnitPowerMax

	-- this table holds the units to which the damage done is
	-- collected into a new fake unit.
	local customGroups = {
		-- The Lich King: Useful targets
		[LBB["The Lich King"]] = L["Important targets"],
		[LBB["Raging Spirit"]] = L["Important targets"],
		[LBB["Ice Sphere"]] = L["Important targets"],
		[LBB["Val'kyr Shadowguard"]] = L["Important targets"],
		[L["Wicked Spirit"]] = L["Important targets"],
		-- Professor Putricide: Oozes
		[L["Gas Cloud"]] = L["Oozes"],
		[L["Volatile Ooze"]] = L["Oozes"],
		-- Blood Prince Council: Princes overkilling
		[LBB["Prince Valanar"]] = L["Princes overkilling"],
		[LBB["Prince Taldaram"]] = L["Princes overkilling"],
		[LBB["Prince Keleseth"]] = L["Princes overkilling"],
		-- Lady Deathwhisper: Adds
		[L["Cult Adherent"]] = L["Adds"],
		[L["Empowered Adherent"]] = L["Adds"],
		[L["Reanimated Adherent"]] = L["Adds"],
		[L["Cult Fanatic"]] = L["Adds"],
		[L["Deformed Fanatic"]] = L["Adds"],
		[L["Reanimated Fanatic"]] = L["Adds"],
		[L["Darnavan"]] = L["Adds"],
		-- Halion: Halion and Inferno
		[LBB["Halion"]] = L["Halion and Inferno"],
		[L["Living Inferno"]] = L["Halion and Inferno"]
	}

	-- this table holds units that should create a fake unit
	-- at certain health percentage. Useful in case you want
	-- to collect damage done to the units at certain phases.
	local customUnits = {
		-- Icecrown Citadel:
		[36855] = {start = 0, text = L["%s - Phase 2"], power = 0}, -- Lady Deathwhisper
		[36678] = {start = 0.35, text = L["%s - Phase 3"]}, -- Professor Putricide
		[36853] = {start = 0.35, text = L["%s - Phase 2"]}, -- Sindragosa
		[36597] = {start = 0.4, stop = 0.1, text = L["%s - Phase 3"]}, -- The Lich King
		[36609] = {name = L["Valkyrs overkilling"], diff = {"10h", "25h"}, start = 0.5, useful = true, values = {["10h"] = 1417500, ["25h"] = 2992000}}, -- Valkyrs overkilling
		-- Trial of the Crusader
		[34564] = {start = 0.3, text = L["%s - Phase 2"]} -- Anub'arak
	}

	local function GetRaidDiff()
		if not instanceDiff then
			local _, instanceType, difficulty, _, _, dynamicDiff, isDynamic = GetInstanceInfo()
			if instanceType == "raid" and isDynamic then
				if difficulty == 1 or difficulty == 3 then -- 10man raid
					instanceDiff = (dynamicDiff == 0) and "10n" or ((dynamicDiff == 1) and "10h" or "unknown")
				elseif difficulty == 2 or difficulty == 4 then -- 25main raid
					instanceDiff = (dynamicDiff == 0) and "25n" or ((dynamicDiff == 1) and "25h" or "unknown")
				end
			else
				local insDiff = GetInstanceDifficulty()
				if insDiff == 1 then
					instanceDiff = "10n"
				elseif insDiff == 2 then
					instanceDiff = "25n"
				elseif insDiff == 3 then
					instanceDiff = "10h"
				elseif insDiff == 4 then
					instanceDiff = "25h"
				end
			end
		end
		return instanceDiff
	end

	local function CustomUnitsMaxValue(id, guid, unit)
		if id and customUnitsInfo and customUnitsInfo[id] then
			return customUnitsInfo[id]
		end

		local maxval
		for uid in UnitIterator() do
			if UnitExists(uid .. "target") and UnitGUID(uid .. "target") == guid then
				maxval = (unit.power ~= nil) and UnitPowerMax(uid .. "target", unit.power) or UnitHealthMax(uid .. "target")
				break
			end
		end

		if not maxval then
			if unit.power ~= nil then
				maxval = select(3, UnitPowerInfo(nil, guid, unit.power))
			else
				maxval = select(3, UnitHealthInfo(nil, guid))
			end
		end

		if not maxval and unit.values then
			maxval = unit.values[GetRaidDiff()]
		end

		if maxval then
			customUnitsInfo = customUnitsInfo or newTable()
			customUnitsInfo[id] = maxval
		end

		return maxval
	end

	local function IsCustomUnit(guid, name, amount, overkill)
		if guid and customUnitsTable and customUnitsTable[guid] then
			return (customUnitsTable[guid] ~= -1)
		end

		local id = GetCreatureId(guid)
		local unit = id and customUnits[id]
		if unit then
			customUnitsTable = customUnitsTable or newTable()

			if unit.diff ~= nil and ((type(unit.diff) == "table" and not tContains(unit.diff, GetRaidDiff())) or (type(unit.diff) == "string" and GetRaidDiff() ~= unit.diff)) then
				customUnitsTable[guid] = -1
				return false
			end

			-- get the unit max value.
			local maxval = CustomUnitsMaxValue(id, guid, unit)
			if not maxval then
				customUnitsTable[guid] = -1
				return false
			end

			-- calculate the current value and the point where to stop.
			local curval = maxval - amount - overkill
			local minval = floor(maxval * (unit.stop or 0))

			-- ignore units below minimum required.
			if curval <= minval then
				customUnitsTable[guid] = -1
				return false
			end

			customUnitsTable[guid] = {
				oname = name or UNKNOWN,
				name = unit.name,
				guid = guid,
				curval = curval,
				minval = minval,
				maxval = floor(maxval * (unit.start or 1)),
				full = maxval,
				power = (unit.power ~= nil),
				useful = unit.useful
			}
			if unit.name == nil then
				customUnitsTable[guid].name = format(
					unit.text or (unit.stop and L["%s - %s%% to %s%%"] or L["%s below %s%%"]),
					name or UNKNOWN,
					(unit.start or 1) * 100,
					(unit.stop or 0) * 100
				)
			end
			return true
		end

		return false
	end

	local function log_custom_unit(set, name, playerid, playername, spellid, amount, absorbed)
		local e = Skada:get_enemy(set, nil, name, nil)
		if e then
			e.fake = true
			e.damagetaken = (e.damagetaken or 0) + amount

			-- spell
			e.damagetaken_spells = e.damagetaken_spells or {}
			if not e.damagetaken_spells[spellid] then
				e.damagetaken_spells[spellid] = {amount = amount}
			else
				e.damagetaken_spells[spellid].amount = e.damagetaken_spells[spellid].amount + amount
			end

			-- source
			e.damagetaken_sources = e.damagetaken_sources or {}
			if not e.damagetaken_sources[playername] then
				e.damagetaken_sources[playername] = {id = playerid, amount = amount}
			else
				e.damagetaken_sources[playername].id = e.damagetaken_sources[playername].id or playerid -- GUID fix
				e.damagetaken_sources[playername].amount = e.damagetaken_sources[playername].amount + amount
			end

			if (absorbed or 0) > 0 then
				e.damagetaken_spells[spellid].absorbed = (e.damagetaken_spells[spellid].absorbed or 0) + absorbed
				e.damagetaken_sources[playername].absorbed = (e.damagetaken_sources[playername].absorbed or 0) + absorbed
			end
		end
	end

	local function log_custom_group(set, id, name, playerid, playername, spellid, amount, overkill, absorbed)
		if not (name and customGroups[name]) then return end -- not a custom group.
		if customGroups[name] == L["Halion and Inferno"] and GetRaidDiff() ~= "25h" then return end -- rs25hm only
		if customGroupsTable and customGroupsTable[id] then return end -- a custim unit with useful damage.

		amount = (customGroups[name] == L["Princes overkilling"]) and overkill or amount
		log_custom_unit(set, customGroups[name], playerid, playername, spellid, amount, absorbed)
	end

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_damage(set, dmg)
		if dmg.spellid and tContains(ignoredSpells, dmg.spellid) then return end
		if (dmg.amount + dmg.absorbed) <= 0 then return end

		local e = Skada:get_enemy(set, dmg.enemyid, dmg.enemyname, dmg.enemyflags)
		if e then
			e.damagetaken = (e.damagetaken or 0) + dmg.amount
			set.edamagetaken = (set.edamagetaken or 0) + dmg.amount

			-- spell
			if dmg.spellid then
				e.damagetaken_spells = e.damagetaken_spells or {}
				if not e.damagetaken_spells[dmg.spellid] then
					e.damagetaken_spells[dmg.spellid] = {amount = dmg.amount}
				else
					e.damagetaken_spells[dmg.spellid].amount = e.damagetaken_spells[dmg.spellid].amount + dmg.amount
				end
			end

			if dmg.srcName then
				e.damagetaken_sources = e.damagetaken_sources or {}
				if not e.damagetaken_sources[dmg.srcName] then
					e.damagetaken_sources[dmg.srcName] = {id = dmg.srcGUID, amount = dmg.amount}
				else
					e.damagetaken_sources[dmg.srcName].id = e.damagetaken_sources[dmg.srcName].id or dmg.srcGUID -- GUID fix
					e.damagetaken_sources[dmg.srcName].amount = e.damagetaken_sources[dmg.srcName].amount + dmg.amount
				end

				if (dmg.absorbed or 0) > 0 then
					e.absdamagetaken = (e.absdamagetaken or 0) + dmg.absorbed
					set.eabsdamagetaken = (set.eabsdamagetaken or 0) + dmg.absorbed
					e.damagetaken_spells[dmg.spellid].absorbed = (e.damagetaken_spells[dmg.spellid].absorbed or 0) + dmg.absorbed
					e.damagetaken_sources[dmg.srcName].absorbed = (e.damagetaken_sources[dmg.srcName].absorbed or 0) + dmg.absorbed
				end

				-- the rest is dne only for raids, sorry.
				if GetRaidDiff() == nil or GetRaidDiff() == "unknown" then return end

				-- custom units
				if IsCustomUnit(dmg.enemyid, dmg.enemyname, dmg.amount, dmg.overkill) then
					local unit = customUnitsTable[dmg.enemyid]
					-- started with less than max?
					if unit.full then
						if unit.useful then
							e.damagetaken_useful = (e.damagetaken_useful or 0) + (unit.full - unit.curval)
							e.damagetaken_sources[dmg.srcName].useful = (e.damagetaken_sources[dmg.srcName].useful or 0) + (unit.full - unit.curval)
						end
						unit.full = nil
					elseif unit.curval >= unit.maxval then
						local amount = dmg.amount - dmg.overkill
						unit.curval = unit.curval - amount

						if unit.curval <= unit.maxval then
							log_custom_unit(set, unit.name, dmg.srcGUID, dmg.srcName, dmg.spellid, unit.maxval - unit.curval, dmg.absorbed)
							amount = amount - (unit.maxval - unit.curval)
							if customGroups[unit.oname] and unit.useful then
								log_custom_group(set, unit.guid, unit.oname, dmg.srcGUID, dmg.srcName, dmg.spellid, amount, dmg.overkill, dmg.absorbed)
								customGroupsTable = customGroupsTable or newTable()
								customGroupsTable[unit.guid] = true
							end
						end
						if unit.useful then
							e.damagetaken_useful = (e.damagetaken_useful or 0) + amount
							e.damagetaken_sources[dmg.srcName].useful = (e.damagetaken_sources[dmg.srcName].useful or 0) + amount
						end
					elseif unit.curval >= unit.minval then
						local amount = dmg.amount - dmg.overkill
						unit.curval = unit.curval - amount

						if unit.curval <= unit.minval then
							amount = amount - (unit.minval - unit.curval)
							customUnitsTable[unit.guid] = -1 -- remove it
						end
						log_custom_unit(set, unit.name, dmg.srcGUID, dmg.srcName, dmg.spellid, amount, dmg.absorbed)
					elseif unit.power then
						log_custom_unit(set, unit.name, dmg.srcGUID, dmg.srcName, dmg.spellid, dmg.amount - (unit.useful and dmg.overkill or 0), dmg.absorbed)
					end
				end

				-- custom groups
				log_custom_group(set, dmg.enemyid, dmg.enemyname, dmg.srcGUID, dmg.srcName, dmg.spellid, dmg.amount, dmg.overkill, dmg.absorbed)
			end
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			local spellid, _, spellschool, amount, overkill, _, _, _, absorbed = ...
			srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)

			dmg.enemyid = dstGUID
			dmg.enemyname = dstName
			dmg.enemyflags = dstFlags

			dmg.srcGUID = srcGUID
			dmg.srcName = srcName
			dmg.srcFlags = srcFlags

			dmg.spellid = spellid
			dmg.amount = amount
			dmg.overkill = overkill or 0
			dmg.absorbed = absorbed or 0

			log_damage(Skada.current, dmg)
		end
	end

	local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, nil, nil, ...)
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			local spellid, _, _, misstype, amount = ...
			if misstype == "ABSORB" then
				srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)

				dmg.enemyid = dstGUID
				dmg.enemyname = dstName
				dmg.enemyflags = dstFlags
				dmg.srcGUID = srcGUID
				dmg.srcName = srcName

				dmg.spellid = spellid
				dmg.amount = 0
				dmg.absorbed = amount

				log_damage(Skada.current, dmg)
			end
		end
	end

	local function SwingMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, MELEE, 1, ...)
	end

	local function getDTPS(set, enemy)
		local amount = enemy.damagetaken or 0
		if Skada.db.profile.absdamage then
			amount = amount + (enemy.absdamagetaken or 0)
		end
		return amount / max(1, Skada:GetSetTime(set)), amount
	end

	local function getEnemiesDTPS(set)
		local amount = set.edamagetaken or 0
		if Skada.db.profile.absdamage then
			amount = amount + (set.eabsdamagetaken or 0)
		end
		return amount / max(1, Skada:GetSetTime(set)), amount
	end

	local function enemymod_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		local p = Skada:find_player(set, id, label)
		local e = Skada:find_enemy(set, win.targetname)
		if p and e and e.damagetaken_sources and e.damagetaken_sources[p.name] then
			tooltip:AddLine(format(L["%s's damage breakdown"], p.name))

			local total = e.damagetaken_sources[p.name].amount
			if Skada.db.profile.absdamage then
				total = total + (e.damagetaken_sources[p.name].absorbed or 0)
			end
			tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(total), 1, 1, 1)

			local useful = e.damagetaken_sources[p.name].useful or 0
			if useful > 0 then
				tooltip:AddDoubleLine(L["Useful Damage"], format("%s (%s)", Skada:FormatNumber(useful), Skada:FormatPercent(useful, total)), 1, 1, 1)
			end
		end
	end

	function enemymod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["Damage on %s"], label)
	end

	function enemymod:Update(win, set)
		win.title = format(L["Damage on %s"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getDTPS(set, enemy)) or 0

		if total > 0 and enemy.damagetaken_sources then
			local maxvalue, nr = 0, 1

			for playername, player in pairs(enemy.damagetaken_sources) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id or playername
				d.label = playername
				d.text = Skada:FormatName(playername, d.id)
				d.class, d.role, d.spec = select(2, UnitClass(d.id, nil, set))

				d.value = player.amount
				if Skada.db.profile.absdamage then
					d.value = d.value + (player.absorbed or 0)
				end
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
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

	function spellmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["Damage on %s"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["Damage on %s"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getDTPS(set, enemy)) or 0

		if total > 0 and enemy.damagetaken_spells then
			local maxvalue, nr = 0, 1

			for spellid, spell in pairs(enemy.damagetaken_spells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = spell.amount
				if Skada.db.profile.absdamage then
					d.value = d.value + (spell.absorbed or 0)
				end
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
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

	function mod:Update(win, set)
		win.title = L["Enemy Damage Taken"]
		local total = select(2, getEnemiesDTPS(set))
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, enemy in ipairs(set.enemies) do
				local dtps, amount = getDTPS(set, enemy)
				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = enemy.name
					d.label = enemy.name
					d.class = enemy.class

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Damage,
						Skada:FormatNumber(dtps),
						self.metadata.columns.DTPS,
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
		damagemod = Skada:GetModule(L["Damage"], true)
		enemymod.metadata = {
			showspots = true,
			click1 = damagemod and damagemod:GetModule(L["Damage target list"], true),
			tooltip = enemymod_tooltip
		}
		self.metadata = {
			click1 = enemymod,
			click2 = spellmod,
			columns = {Damage = true, DTPS = false, Percent = true},
			icon = "Interface\\Icons\\spell_fire_felflamebolt"
		}

		if Skada:GetModule(L["Useful Damage"], true) then
			usefulmod = Skada:GetModule(L["Useful Damage"]):GetModule(L["Damage target list"]):GetModule(L["More Details"], true)
			usefulmod.label = L["Useful Damage"]
			self.metadata.click3 = usefulmod
		end

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_EXTRA_ATTACKS", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})

		Skada:RegisterForCL(SpellMissed, "DAMAGE_SHIELD_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:SetComplete(set)
		instanceDiff = nil
		customUnitsTable = delTable(customUnitsTable)
		customUnitsInfo = delTable(customUnitsInfo)
	end
end)

---------------------------------------------------------------------------
-- Enemy Damage Done

Skada:AddLoadableModule("Enemy Damage Done", function(Skada, L)
	if Skada:IsDisabled("Enemy Damage Done") then return end

	local mod = Skada:NewModule(L["Enemy Damage Done"])
	local enemymod = mod:NewModule(L["Damage taken per player"])
	local spellmod = mod:NewModule(L["Damage spell list"])
	local damagemod -- used for redirection

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_damage(set, dmg)
		if dmg.spellid and tContains(ignoredSpells, dmg.spellid) then return end

		local e = Skada:get_enemy(set, dmg.enemyid, dmg.enemyname, dmg.enemyflags)
		if e then
			e.damage = (e.damage or 0) + dmg.amount
			set.edamage = (set.edamage or 0) + dmg.amount

			-- spell
			e.damage_spells = e.damage_spells or {}
			if not e.damage_spells[dmg.spellid] then
				e.damage_spells[dmg.spellid] = {amount = dmg.amount}
			else
				e.damage_spells[dmg.spellid].amount = e.damage_spells[dmg.spellid].amount + dmg.amount
			end

			e.damage_targets = e.damage_targets or {}
			if not e.damage_targets[dmg.dstName] then
				e.damage_targets[dmg.dstName] = {id = dmg.dstGUID, amount = dmg.amount}
			else
				e.damage_targets[dmg.dstName].id = e.damage_targets[dmg.dstName].id or dmg.dstGUID -- GUID fix
				e.damage_targets[dmg.dstName].amount = e.damage_targets[dmg.dstName].amount + dmg.amount
			end

			if (dmg.absorbed or 0) > 0 then
				e.absdamage = (e.absdamage or 0) + dmg.absorbed
				set.eabsdamage = (set.eabsdamage or 0) + dmg.absorbed
				e.damage_spells[dmg.spellid].absorbed = (e.damage_spells[dmg.spellid].absorbed or 0) + dmg.absorbed
				e.damage_targets[dmg.dstName].absorbed = (e.damage_targets[dmg.dstName].absorbed or 0) + dmg.absorbed
			end
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			local spellid, _, _, amount, _, _, _, _, absorbed = ...

			dmg.enemyid = srcGUID
			dmg.enemyname = srcName
			dmg.enemyflags = srcFlags

			dmg.dstGUID = dstGUID
			dmg.dstName = dstName
			dmg.dstFlags = dstFlags

			dmg.spellid = spellid
			dmg.amount = amount
			dmg.absorbed = absorbed or 0

			log_damage(Skada.current, dmg)
		end
	end

	local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellDamage(nil, nil, srcGUID, srcName, nil, dstGUID, dstName, dstFlags, 6603, nil, nil, ...)
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			local spellid, _, _, misstype, amount = ...
			if misstype == "ABSORB" then
				dmg.enemyid = srcGUID
				dmg.enemyname = srcName
				dmg.enemyflags = srcFlags

				dmg.dstGUID = dstGUID
				dmg.dstName = dstName
				dmg.dstFlags = dstFlags

				dmg.spellid = spellid
				dmg.amount = 0
				dmg.absorbed = amount

				log_damage(Skada.current, dmg)
			end
		end
	end

	local function SwingMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, MELEE, 1, ...)
	end

	local function getDPS(set, enemy)
		local amount = enemy.damage or 0
		if Skada.db.profile.absdamage then
			amount = amount + (enemy.absdamage or 0)
		end
		return amount / max(1, Skada:GetSetTime(set)), amount
	end

	local function getEnemiesDPS(set)
		local amount = set.edamage or 0
		if Skada.db.profile.absdamage then
			amount = amount + (set.eabsdamage or 0)
		end
		return amount / max(1, Skada:GetSetTime(set)), amount
	end

	function enemymod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["Damage from %s"], label)
	end

	function enemymod:Update(win, set)
		win.title = format(L["Damage from %s"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getDPS(set, enemy)) or 0

		if total > 0 and enemy.damage_targets then
			local maxvalue, nr = 0, 1

			for targetname, target in pairs(enemy.damage_targets) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.text = Skada:FormatName(targetname, d.id)
				d.class, d.role, d.spec = select(2, UnitClass(d.id, nil, set))

				d.value = target.amount
				if Skada.db.profile.absdamage then
					d.value = d.value + (target.amount or 0)
				end
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
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

	function spellmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["%s's damage"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's damage"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getDPS(set, enemy)) or 0

		if total > 0 and enemy.damage_spells then
			local maxvalue, nr = 0, 1

			for spellid, spell in pairs(enemy.damage_spells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = spell.amount
				if Skada.db.profile.absdamage then
					d.value = d.value + (spell.absorbed or 0)
				end
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
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

	function mod:Update(win, set)
		win.title = L["Enemy Damage Done"]
		local total = select(2, getEnemiesDPS(set))
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, enemy in ipairs(set.enemies) do
				if not enemy.fake then
					local dtps, amount = getDPS(set, enemy)
					if amount > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = enemy.name
						d.label = enemy.name
						d.class = enemy.class

						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							self.metadata.columns.Damage,
							Skada:FormatNumber(dtps),
							self.metadata.columns.DPS,
							Skada:FormatPercent(d.value, total),
							self.metadata.columns.Percent
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

	function mod:OnEnable()
		damagemod = Skada:GetModule(L["Damage Taken"], true)

		enemymod.metadata = {showspots = true, click1 = damagemod and damagemod:GetModule(L["Damage target list"], true)}
		self.metadata = {
			click1 = enemymod,
			click2 = spellmod,
			columns = {Damage = true, DPS = false, Percent = true},
			icon = "Interface\\Icons\\spell_shadow_shadowbolt"
		}

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_EXTRA_ATTACKS", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})

		Skada:RegisterForCL(SpellMissed, "DAMAGE_SHIELD_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)

---------------------------------------------------------------------------
-- Enemy Healing Done

Skada:AddLoadableModule("Enemy Healing Done", function(Skada, L)
	if Skada:IsDisabled("Enemy Healing Done") then return end

	local mod = Skada:NewModule(L["Enemy Healing Done"])
	local targetmod = mod:NewModule(L["Healed target list"])
	local spellmod = mod:NewModule(L["Healing spell list"])

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_heal(set, data)
		if data.spellid and tContains(ignoredSpells, data.spellid) then return end

		local e = Skada:get_enemy(set, data.enemyid, data.enemyname, data.enemyflags)
		if e then
			e.heal = (e.heal or 0) + data.amount
			set.eheal = (set.eheal or 0) + data.amount

			-- spell
			if data.spellid then
				e.heal_spells = e.heal_spells or {}
				e.heal_spells[data.spellid] = (e.heal_spells[data.spellid] or 0) + data.amount
			end

			-- target
			if data.dstName then
				e.heal_targets = e.heal_targets or {}
				e.heal_targets[data.dstName] = (e.heal_targets[data.dstName] or 0) + data.amount
			end
		end
	end

	local heal = {}

	local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, _, _, amount, overheal = ...

		heal.enemyid = srcGUID
		heal.enemyname = srcName
		heal.enemyflags = srcFlags

		heal.dstName = dstName
		heal.spellid = spellid
		heal.amount = max(0, amount - overheal)

		log_heal(Skada.current, heal)
	end

	local function getHPS(set, enemy)
		local amount = enemy.heal or 0
		return amount / max(1, Skada:GetSetTime(set)), amount
	end

	local function getEnemiesHPS(set)
		return (set.eheal or 0) / max(1, Skada:GetSetTime(set)), (set.eheal or 0)
	end

	function targetmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["%s's healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's healed targets"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getHPS(set, enemy)) or 0

		if total > 0 and enemy.heal_targets then
			local maxvalue, nr = 0, 1

			for targetname, amount in pairs(enemy.heal_targets) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = targetname
				d.label = targetname
				d.class = EnemyClass(targetname, set)

				d.value = amount
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

			win.metadata.maxvalue = maxvalue
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["%s's healing spells"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's healing spells"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getHPS(set, enemy)) or 0

		if total > 0 and enemy.heal_spells then
			local maxvalue, nr = 0, 1

			for spellid, amount in pairs(enemy.heal_spells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = amount
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

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:Update(win, set)
		win.title = L["Enemy Healing Done"]
		local total = select(2, getEnemiesHPS(set))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, enemy in ipairs(set.enemies) do
				if not enemy.fake then
					local hps, amount = getHPS(set, enemy)
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = enemy.id
					d.label = enemy.name
					d.class = enemy.class

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

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			click1 = spellmod,
			click2 = targetmod,
			nototalclick = {spellmod, targetmod},
			columns = {Healing = true, HPS = false, Percent = true},
			icon = "Interface\\Icons\\spell_nature_healingtouch"
		}

		Skada:RegisterForCL(SpellHeal, "SPELL_HEAL", {src_is_not_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellHeal, "SPELL_PERIODIC_HEAL", {src_is_not_interesting = true, dst_is_not_interesting = true})

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)