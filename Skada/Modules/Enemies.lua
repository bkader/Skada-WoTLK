local Skada = Skada

-- frequently used globals --
local pairs, ipairs, type, select = pairs, ipairs, type, select
local format, min, max = string.format, math.min, math.max
local unitClass, GetSpellInfo = Skada.unitClass, Skada.GetSpellInfo or GetSpellInfo
local newTable, delTable, wipe = Skada.newTable, Skada.delTable, wipe
local cacheTable = Skada.cacheTable
local setPrototype = Skada.setPrototype
local enemyPrototype = Skada.enemyPrototype
local tContains = tContains
local _

---------------------------------------------------------------------------
-- Enemy Damage Taken

Skada:AddLoadableModule("Enemy Damage Taken", function(L)
	if Skada:IsDisabled("Enemy Damage Taken") then return end

	local mod = Skada:NewModule(L["Enemy Damage Taken"])
	local spellmod = mod:NewModule(L["Damage spell list"])
	local sourcemod = mod:NewModule(L["Damage source list"])
	local usefulmod = mod:NewModule(L["Useful Damage"])

	local instanceDiff, customGroupsTable, customUnitsTable, customUnitsInfo
	local UnitIterator, GetCreatureId = Skada.UnitIterator, Skada.GetCreatureId
	local UnitHealthInfo, UnitPowerInfo = Skada.UnitHealthInfo, Skada.UnitPowerInfo
	local UnitExists, UnitGUID = UnitExists, UnitGUID
	local UnitHealthMax, UnitPowerMax = UnitHealthMax, UnitPowerMax

	-- this table holds the units to which the damage done is
	-- collected into a new fake unit.
	local customGroups = {
		-- The Lich King: Useful targets
		[L["The Lich King"]] = L["Important targets"],
		[L["Raging Spirit"]] = L["Important targets"],
		[L["Ice Sphere"]] = L["Important targets"],
		[L["Val'kyr Shadowguard"]] = L["Important targets"],
		[L["Wicked Spirit"]] = L["Important targets"],
		-- Professor Putricide: Oozes
		[L["Gas Cloud"]] = L["Oozes"],
		[L["Volatile Ooze"]] = L["Oozes"],
		-- Blood Prince Council: Princes overkilling
		[L["Prince Valanar"]] = L["Princes overkilling"],
		[L["Prince Taldaram"]] = L["Princes overkilling"],
		[L["Prince Keleseth"]] = L["Princes overkilling"],
		-- Lady Deathwhisper: Adds
		[L["Cult Adherent"]] = L["Adds"],
		[L["Empowered Adherent"]] = L["Adds"],
		[L["Reanimated Adherent"]] = L["Adds"],
		[L["Cult Fanatic"]] = L["Adds"],
		[L["Deformed Fanatic"]] = L["Adds"],
		[L["Reanimated Fanatic"]] = L["Adds"],
		[L["Darnavan"]] = L["Adds"],
		-- Halion: Halion and Inferno
		[L["Halion"]] = L["Halion and Inferno"],
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
				oname = name or L.Unknown,
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
					name or L.Unknown,
					(unit.start or 1) * 100,
					(unit.stop or 0) * 100
				)
			end
			return true
		end

		return false
	end

	local function log_custom_unit(set, name, playername, spellid, spellschool, amount, absorbed)
		local e = Skada:GetEnemy(set, name)
		if e then
			e.fake = true
			e.damagetaken = (e.damagetaken or 0) + amount
			e.totaldamagetaken = (e.totaldamagetaken or 0) + amount
			if absorbed > 0 then
				e.totaldamagetaken = e.totaldamagetaken + absorbed
			end

			-- spell
			local spell = e.damagetakenspells and e.damagetakenspells[spellid]
			if not spell then
				e.damagetakenspells = e.damagetakenspells or {}
				e.damagetakenspells[spellid] = {school = spellschool, amount = 0, total = 0}
				spell = e.damagetakenspells[spellid]
			end

			-- source
			local source = spell.sources and spell.sources[playername]
			if not source then
				spell.sources = spell.sources or {}
				spell.sources[playername] = {amount = 0, total = 0}
				source = spell.sources[playername]
			end

			spell.amount = spell.amount + amount
			source.amount = source.amount + amount

			spell.total = spell.total + amount
			source.total = source.total + amount
			if absorbed > 0 then
				spell.total = spell.total + absorbed
				source.total = source.total + absorbed
			end
		end
	end

	local function log_custom_group(set, id, name, playername, spellid, spellschool, amount, overkill, absorbed)
		if not (name and customGroups[name]) then return end -- not a custom group.
		if customGroups[name] == L["Halion and Inferno"] and GetRaidDiff() ~= "25h" then return end -- rs25hm only
		if customGroupsTable and customGroupsTable[id] then return end -- a custim unit with useful damage.

		amount = (customGroups[name] == L["Princes overkilling"]) and overkill or amount
		log_custom_unit(set, customGroups[name], playername, spellid, spellschool, amount, absorbed)
	end

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_damage(set, dmg)
		if dmg.spellid and tContains(ignoredSpells, dmg.spellid) then return end
		local absorbed = dmg.absorbed or 0
		if (dmg.amount + absorbed) == 0 then return end

		local e = Skada:GetEnemy(set, dmg.enemyname, dmg.enemyid, dmg.enemyflags)
		if e then
			e.damagetaken = (e.damagetaken or 0) + dmg.amount
			e.totaldamagetaken = (e.totaldamagetaken or 0) + dmg.amount
			if absorbed > 0 then
				e.totaldamagetaken = e.totaldamagetaken + absorbed
			end

			-- damage spell.
			local spell = e.damagetakenspells and e.damagetakenspells[dmg.spellid]
			if not spell then
				e.damagetakenspells = e.damagetakenspells or {}
				e.damagetakenspells[dmg.spellid] = {school = dmg.spellschool, amount = 0, total = 0}
				spell = e.damagetakenspells[dmg.spellid]
			end

			-- add amounts to sepll.
			spell.amount = spell.amount + dmg.amount
			spell.total = spell.total + dmg.amount
			if absorbed > 0 then
				spell.total = spell.total + absorbed
			end

			-- damage source.
			if dmg.srcName then
				local actor = Skada:GetActor(set, dmg.srcGUID, dmg.srcName, dmg.srcFlags)
				if not actor then return end -- missing for some reason!

				-- the source
				local source = spell.sources and spell.sources[dmg.srcName]
				if not source then
					spell.sources = spell.sources or {}
					spell.sources[dmg.srcName] = {amount = 0, total = 0}
					source = spell.sources[dmg.srcName]
				end
				source.amount = source.amount + dmg.amount
				source.total = source.total + dmg.amount
				if absorbed > 0 then
					source.total = source.total + absorbed
				end

				-- the rest of the code is only for raids.
				if GetRaidDiff() == nil or GetRaidDiff() == "unknown" then return end
				if IsCustomUnit(dmg.enemyid, dmg.enemyname, dmg.amount, dmg.overkill) then
					local unit = customUnitsTable[dmg.enemyid]
					-- started with less than max?
					if unit.full then
						if unit.useful then
							local amount = unit.full - unit.curval
							e.usefuldamagetaken = (e.usefuldamagetaken or 0) + amount
							spell.useful = (spell.useful or 0) + amount
							source.useful = (source.useful or 0) + amount
						end
						unit.full = nil
					elseif unit.curval >= unit.maxval then
						local amount = dmg.amount - dmg.overkill
						unit.curval = unit.curval - amount

						if unit.curval <= unit.maxval then
							log_custom_unit(set, unit.name, dmg.srcName, dmg.spellid, dmg.spellschool, unit.maxval - unit.curval, absorbed)
							amount = amount - (unit.maxval - unit.curval)
							if customGroups[unit.oname] and unit.useful then
								log_custom_group(set, unit.guid, unit.oname, dmg.srcName, dmg.spellid, dmg.spellschool, amount, dmg.overkill, absorbed)
								customGroupsTable = customGroupsTable or newTable()
								customGroupsTable[unit.guid] = true
							end
						end
						if unit.useful then
							e.usefuldamagetaken = (e.usefuldamagetaken or 0) + amount
							spell.useful = (spell.useful or 0) + amount
							source.useful = (source.useful or 0) + amount
						end
					elseif unit.curval >= unit.minval then
						local amount = dmg.amount - dmg.overkill
						unit.curval = unit.curval - amount

						if unit.curval <= unit.minval then
							amount = amount - (unit.minval - unit.curval)
							customUnitsTable[unit.guid] = -1 -- remove it
						end
						log_custom_unit(set, unit.name, dmg.srcName, dmg.spellid, dmg.spellschool, amount, absorbed)
					elseif unit.power then
						log_custom_unit(set, unit.name, dmg.srcName, dmg.spellid, dmg.spellschool, dmg.amount - (unit.useful and dmg.overkill or 0), absorbed)
					end
				end

				-- custom groups
				log_custom_group(set, dmg.enemyid, dmg.enemyname, dmg.srcName, dmg.spellid, dmg.spellschool, dmg.amount, dmg.overkill, absorbed)
			end
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)

			if eventtype == "SWING_DAMAGE" then
				dmg.spellid, dmg.spellschool = 6603, 1
				dmg.amount, dmg.overkill, _, _, _, dmg.absorbed = ...
			else
				dmg.spellid, _, dmg.spellschool, dmg.amount, dmg.overkill, _, _, _, dmg.absorbed = ...
			end

			dmg.enemyid = dstGUID
			dmg.enemyname = dstName
			dmg.enemyflags = dstFlags

			dmg.srcGUID = srcGUID
			dmg.srcName = srcName
			dmg.srcFlags = srcFlags

			log_damage(Skada.current, dmg)
		end
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			local spellid, spellschool, misstype, amount

			if eventtype == "SWING_MISSED" then
				spellid, spellschool = 6603, 1
				misstype, amount = ...
			else
				spellid, _, spellschool, misstype, amount = ...
			end

			if misstype == "ABSORB" then
				srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)

				dmg.enemyid = dstGUID
				dmg.enemyname = dstName
				dmg.enemyflags = dstFlags

				dmg.srcGUID = srcGUID
				dmg.srcName = srcName
				dmg.srcFlags = srcFlags

				dmg.spellid = spellid
				dmg.spellschool = spellschool
				dmg.amount = 0
				dmg.absorbed = amount

				log_damage(Skada.current, dmg)
			end
		end
	end

	local function sourcemod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local e = set and set:GetEnemy(win.targetname, win.targetid)
		if not e then return end

		local amount, total, useful = e:GetDamageFromSource(label)
		if total > 0 then
			tooltip:AddLine(format(L["%s's damage breakdown"], label))
			local damage = Skada.db.profile.absdamage and total or amount
			tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(damage), 1, 1, 1)
			if useful > 0 then
				tooltip:AddDoubleLine(L["Useful Damage"], format("%s (%s)", Skada:FormatNumber(useful), Skada:FormatPercent(useful, damage)), 1, 1, 1)
			end
		end
	end

	function sourcemod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's damage sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = format(L["%s's damage sources"], win.targetname or L.Unknown)

		local enemy = set and set:GetEnemy(win.targetname, win.targetid)
		local total = enemy and enemy:GetDamageTaken() or 0
		local sources = (total > 0) and enemy:GetDamageSources()

		if sources then
			local maxvalue, nr = 0, 1

			for sourcename, source in pairs(sources) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = source.id or sourcename
				d.label = sourcename
				d.class = source.class
				d.role = source.role
				d.spec = source.spec

				d.value = source.amount
				if Skada.db.profile.absdamage then
					d.value = source.total or d.value
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
		win.targetid, win.targetname = id, label
		win.title = format(L["Damage taken by %s"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["Damage taken by %s"], win.targetname or L.Unknown)

		local enemy = set and set:GetEnemy(win.targetname, win.targetid)
		local total = enemy and enemy:GetDamageTaken() or 0

		if total > 0 and enemy.damagetakenspells then
			local maxvalue, nr = 0, 1

			for spellid, spell in pairs(enemy.damagetakenspells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.spellschool = spell.school
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

	function usefulmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["Useful damage on %s"], label)
	end

	function usefulmod:Update(win, set)
		win.title = format(L["Useful damage on %s"], win.targetname or L.Unknown)

		local enemy = set and set:GetEnemy(win.targetname, win.targetid)
		local total = enemy and enemy.usefuldamagetaken or 0
		local sources = (total > 0) and enemy:GetDamageSources()

		if sources then
			local maxvalue, nr = 0, 1

			for sourcename, source in pairs(sources) do
				if (source.useful or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = source.id or sourcename
					d.label = sourcename
					d.class = source.class
					d.role = source.role
					d.spec = source.spec

					d.value = source.useful
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
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:Update(win, set)
		win.title = L["Enemy Damage Taken"]
		local total = set and set:GetEnemyDamageTaken() or 0
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, enemy in set:IterateEnemies() do
				local dtps, amount = enemy:GetDTPS()
				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = enemy.id or enemy.name
					d.label = enemy.name
					d.class = enemy.class
					d.role = enemy.role
					d.spec = enemy.spec

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
		usefulmod.metadata = {showspots = true}
		sourcemod.metadata = {showspots = true, post_tooltip = sourcemod_tooltip}
		self.metadata = {
			click1 = sourcemod,
			click2 = spellmod,
			click3 = usefulmod,
			columns = {Damage = true, DTPS = false, Percent = true},
			icon = [[Interface\Icons\spell_fire_felflamebolt]]
		}

		local damagemod = Skada:GetModule(L["Damage"], true)
		if damagemod then
			sourcemod.metadata.click1 = damagemod:GetModule(L["Damage target list"], true)
		end

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SWING_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})

		Skada:RegisterForCL(SpellMissed, "DAMAGE_SHIELD_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SWING_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})

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

	function setPrototype:GetEnemyDamageTaken()
		if not self.GetDamage and self.enemies then
			local total = 0
			for _, e in ipairs(self.enemies) do
				if not e.fake and Skada.db.profile.absdamage then
					total = total + e.totaldamagetaken
				elseif not e.fake then
					total = total + e.damagetaken
				end
			end
			return total
		end
		return self.GetDamage and self:GetDamage() or 0
	end

	function enemyPrototype:GetDamageTaken()
		if Skada.db.profile.absdamage then
			return self.totaldamagetaken or 0
		end
		return self.damagetaken or 0
	end

	function enemyPrototype:GetDTPS()
		local dtps, damage = 0, self:GetDamageTaken()
		if damage > 0 then
			dtps = damage / max(1, self:GetTime())
		end
		return dtps, damage
	end

	function enemyPrototype:GetDamageSources()
		if self.damagetakenspells then
			wipe(cacheTable)
			for _, spell in pairs(self.damagetakenspells) do
				if spell.sources then
					for name, source in pairs(spell.sources) do
						if not cacheTable[name] then
							cacheTable[name] = {amount = source.amount, total = source.total, useful = source.useful}
						else
							cacheTable[name].amount = cacheTable[name].amount + source.amount
							cacheTable[name].total = cacheTable[name].total + source.total
							if source.useful then
								cacheTable[name].useful = (cacheTable[name].useful or 0) + source.useful
							end
						end

						-- attempt to get the class
						if not cacheTable[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								cacheTable[name].id = actor.id
								cacheTable[name].class = actor.class
								cacheTable[name].role = actor.role
								cacheTable[name].spec = actor.spec
							end
						end
					end
				end
			end
			return cacheTable
		end
	end

	function enemyPrototype:GetDamageFromSource(name)
		if self.damagetakenspells and name then
			local amount, total, useful = 0, 0, 0
			for _, spell in pairs(self.damagetakenspells) do
				if spell.sources and spell.sources[name] then
					amount = amount + spell.amount
					total = total + spell.total
					if spell.useful then
						useful = useful + spell.useful
					end
				end
			end
			return amount, total, useful
		end
	end
end)

---------------------------------------------------------------------------
-- Enemy Damage Done

Skada:AddLoadableModule("Enemy Damage Done", function(L)
	if Skada:IsDisabled("Enemy Damage Done") then return end

	local mod = Skada:NewModule(L["Enemy Damage Done"])
	local targetmod = mod:NewModule(L["Damage target list"])
	local spellmod = mod:NewModule(L["Damage spell list"])

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_damage(set, dmg)
		if dmg.spellid and tContains(ignoredSpells, dmg.spellid) then return end
		local absorbed = dmg.absorbed or 0
		if (dmg.amount + absorbed) == 0 then return end

		local e = Skada:GetEnemy(set, dmg.enemyname, dmg.enemyid, dmg.enemyflags)
		if e then
			e.damage = (e.damage or 0) + dmg.amount
			e.totaldamage = (e.totaldamage or 0) + dmg.amount

			-- damage spell.
			local spell = e.damagespells and e.damagespells[dmg.spellid]
			if not spell then
				e.damagespells = e.damagespells or {}
				e.damagespells[dmg.spellid] = {school = dmg.spellschool, amount = 0, total = 0}
				spell = e.damagespells[dmg.spellid]
			end
			spell.amount = spell.amount + dmg.amount
			spell.total = spell.total + dmg.amount

			if absorbed > 0 then
				e.totaldamage = e.totaldamage + absorbed
				spell.total = spell.total + absorbed
			end

			-- damage target.
			if dmg.dstName then
				local actor = Skada:GetActor(set, dmg.dstGUID, dmg.dstName, dmg.dstFlags)
				if not actor then return end

				local target = spell.targets and spell.targets[dmg.dstName]
				if not target then
					spell.targets = spell.targets or {}
					spell.targets[dmg.dstName] = {amount = 0, total = 0}
					target = spell.targets[dmg.dstName]
				end
				target.amount = target.amount + dmg.amount
				target.total = target.total + dmg.amount

				if absorbed > 0 then
					target.total = target.total + absorbed
				end
			end
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			if eventtype == "SWING_DAMAGE" then
				dmg.spellid, dmg.spellschool = 6603, 1
				dmg.amount, _, _, _, _, dmg.absorbed = ...
			else
				dmg.spellid, _, dmg.spellschool, dmg.amount, _, _, _, _, dmg.absorbed = ...
			end

			dmg.enemyid = srcGUID
			dmg.enemyname = srcName
			dmg.enemyflags = srcFlags

			dmg.dstGUID = dstGUID
			dmg.dstName = dstName
			dmg.dstFlags = dstFlags

			log_damage(Skada.current, dmg)
		end
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			local spellid, spellschool, misstype, amount

			if eventtype == "SWING_MISSED" then
				spellid, spellschool = 6603, 1
				misstype, amount = ...
			else
				spellid, _, spellschool, misstype, amount = ...
			end

			if misstype == "ABSORB" then
				srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)

				dmg.enemyid = srcGUID
				dmg.enemyname = srcName
				dmg.enemyflags = srcFlags

				dmg.dstGUID = dstGUID
				dmg.dstName = dstName
				dmg.dstFlags = dstFlags

				dmg.spellid = spellid
				dmg.spellschool = spellschool
				dmg.amount = 0
				dmg.absorbed = amount

				log_damage(Skada.current, dmg)
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's targets"], win.targetname or L.Unknown)

		local enemy = set and set:GetEnemy(win.targetname, win.targetid)
		local total = enemy and enemy:GetDamageDone() or 0
		local targets = (total > 0) and enemy:GetDamageTargets()

		if targets then
			local maxvalue, nr = 0, 1

			for targetname, target in pairs(targets) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.amount
				if Skada.db.profile.absdamage then
					d.value = target.total or d.value
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
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's damage"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's damage"], win.targetname or L.Unknown)

		local enemy = set and set:GetEnemy(win.targetname, win.targetid)
		local total = enemy and enemy:GetDamageDone() or 0

		if total > 0 and enemy.damagespells then
			local maxvalue, nr = 0, 1

			for spellid, spell in pairs(enemy.damagespells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.spellschool = spell.school
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = spell.amount
				if Skada.db.profile.absdamage then
					d.value = spell.total or d.value
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
		local total = set and set:GetEnemyDamageDone() or 0
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, enemy in set:IterateEnemies() do
				if not enemy.fake then
					local dtps, amount = enemy:GetDPS()
					if amount > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = enemy.id or enemy.name
						d.id = enemy.name
						d.label = enemy.name
						d.class = enemy.class
						d.role = enemy.role
						d.spec = enemy.spec

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
		targetmod.metadata = {showspots = true}
		self.metadata = {
			click1 = targetmod,
			click2 = spellmod,
			columns = {Damage = true, DPS = false, Percent = true},
			icon = [[Interface\Icons\spell_shadow_shadowbolt]]
		}

		local damagemod = Skada:GetModule(L["Damage"], true)
		if damagemod then
			targetmod.metadata.click1 = damagemod:GetModule(L["Damage target list"], true)
		end

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})

		Skada:RegisterForCL(SpellMissed, "DAMAGE_SHIELD_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SWING_MISSED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function setPrototype:GetEnemyDamageDone()
		if not self.GetDamageTaken and self.enemies then
			local total = 0
			for _, e in ipairs(self.enemies) do
				if not e.fake and Skada.db.profile.absdamage then
					total = total + e.totaldamage
				elseif not e.fake then
					total = total + e.damage
				end
			end
			return total
		end
		return self.GetDamageTaken and self:GetDamageTaken() or 0
	end

	function enemyPrototype:GetDamageDone()
		if Skada.db.profile.absdamage then
			return self.totaldamage or 0
		end
		return self.damage or 0
	end

	function enemyPrototype:GetDPS()
		local dtps, damage = 0, self:GetDamageDone()
		if damage > 0 then
			dtps = damage / max(1, self:GetTime())
		end
		return dtps, damage
	end

	function enemyPrototype:GetDamageTargets()
		if self.damagespells then
			wipe(cacheTable)
			for _, spell in pairs(self.damagespells) do
				if spell.targets then
					for name, target in pairs(spell.targets) do
						if not cacheTable[name] then
							cacheTable[name] = {amount = target.amount, total = target.total}
						else
							cacheTable[name].amount = cacheTable[name].amount + target.amount
							cacheTable[name].total = cacheTable[name].total + target.total
						end

						-- attempt to get the class
						if not cacheTable[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								cacheTable[name].id = actor.id
								cacheTable[name].class = actor.class
								cacheTable[name].role = actor.role
								cacheTable[name].spec = actor.spec
							end
						end
					end
				end
			end
			return cacheTable
		end
	end

	function enemyPrototype:GetDamageOnTarget(name)
		if self.damagespells and name then
			local amount, total = 0, 0
			for _, spell in pairs(self.damagespells) do
				if spell.targets and spell.targets[name] then
					amount = amount + spell.amount
					total = total + spell.total
				end
			end
			return amount, total
		end
	end
end)

---------------------------------------------------------------------------
-- Enemy Healing Done

Skada:AddLoadableModule("Enemy Healing Done", function(L)
	if Skada:IsDisabled("Enemy Healing Done") then return end

	local mod = Skada:NewModule(L["Enemy Healing Done"])
	local targetmod = mod:NewModule(L["Healed target list"])
	local spellmod = mod:NewModule(L["Healing spell list"])

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_heal(set, data)
		if (data.spellid and tContains(ignoredSpells, data.spellid)) or data.amount == 0 then return end

		local e = Skada:GetEnemy(set, data.enemyname, data.enemyid, data.enemyflags)
		if e then
			e.heal = (e.heal or 0) + data.amount

			local spell = e.healspells and e.healspells[data.spellid]
			if not spell then
				e.healspells = e.healspells or {}
				e.healspells[data.spellid] = {school = data.spellschool, amount = 0}
				spell = e.healspells[data.spellid]
			end
			spell.amount = spell.amount + data.amount

			if data.dstName then
				local actor = Skada:GetActor(set, data.dstGUID, data.dstName, data.dstFlags)
				if actor then
					spell.targets = spell.targets or {}
					spell.targets[data.dstName] = (spell.targets[data.dstName] or 0) + data.amount
				end
			end
		end
	end

	local heal = {}

	local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		heal.enemyid = srcGUID
		heal.enemyname = srcName
		heal.enemyflags = srcFlags

		heal.dstGUID = dstGUID
		heal.dstName = dstName
		heal.dstFlags = dstFlags

		local spellid, _, spellschool, amount, overheal = ...
		heal.spellid = spellid
		heal.spellschool = spellschool
		heal.amount = max(0, amount - overheal)

		log_heal(Skada.current, heal)
	end

	function targetmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's healed targets"], win.targetname or L.Unknown)

		local enemy = set and set:GetEnemy(win.targetname, win.targetid)
		local total = enemy and enemy.heal or 0
		local targets = (total > 0) and enemy:GetHealTargets()

		if total > 0 and targets then
			local maxvalue, nr = 0, 1

			for targetname, target in pairs(targets) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

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

			win.metadata.maxvalue = maxvalue
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healing spells"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's healing spells"], win.targetname or L.Unknown)

		local enemy = set and set:GetEnemy(win.targetname, win.targetid)
		local total = enemy and enemy.heal or 0

		if total > 0 and enemy.healspells then
			local maxvalue, nr = 0, 1

			for spellid, spell in pairs(enemy.healspells) do
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

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:Update(win, set)
		win.title = L["Enemy Healing Done"]
		local total = set and set:GetEnemyHeal() or 0
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, enemy in set:IterateEnemies() do
				if not enemy.fake then
					local hps, amount = enemy:GetHPS()
					if amount > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = enemy.id or enemy.name
						d.label = enemy.name
						d.class = enemy.class
						d.role = enemy.role
						d.spec = enemy.spec

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
			columns = {Healing = true, HPS = true, Percent = true},
			icon = [[Interface\Icons\spell_nature_healingtouch]]
		}

		Skada:RegisterForCL(SpellHeal, "SPELL_HEAL", {src_is_not_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellHeal, "SPELL_PERIODIC_HEAL", {src_is_not_interesting = true, dst_is_not_interesting = true})

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function setPrototype:GetEnemyHeal()
		local total = 0
		if self.enemies then
			for _, e in ipairs(self.enemies) do
				if e.heal then
					total = total + e.heal
				end
			end
		end
		return total
	end

	function enemyPrototype:GetHPS()
		local hps, amount = 0, self.heal or 0
		if amount > 0 then
			hps = amount / max(1, self:GetTime())
		end
		return hps, amount
	end

	function enemyPrototype:GetHealTargets()
		if self.healspells then
			wipe(cacheTable)
			for _, spell in pairs(self.healspells) do
				if spell.targets then
					for name, amount in pairs(spell.targets) do
						if not cacheTable[name] then
							cacheTable[name] = {amount = amount}
						else
							cacheTable[name].amount = cacheTable[name].amount + amount
						end
						if not cacheTable[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								cacheTable[name].id = actor.id
								cacheTable[name].class = actor.class
								cacheTable[name].role = actor.role
								cacheTable[name].spec = actor.spec
							end
						end
					end
				end
			end
			return cacheTable
		end
	end
end)