local Skada = Skada

-- frequently used globals --
local pairs, type, max, format = pairs, type, math.max, string.format
local pformat, T = Skada.pformat, Skada.Table
local setPrototype, enemyPrototype = Skada.setPrototype, Skada.enemyPrototype
local _

---------------------------------------------------------------------------
-- Enemy Damage Taken

Skada:RegisterModule("Enemy Damage Taken", function(L, P, _, C, new, del, clear)
	local mod = Skada:NewModule("Enemy Damage Taken")
	local sourcemod = mod:NewModule("Damage source list")
	local sourcespellmod = sourcemod:NewModule("Damage spell list")
	local spellmod = mod:NewModule("Damage spell list")
	local spellsourcemod = spellmod:NewModule("Damage spell sources")
	local usefulmod = mod:NewModule("Useful Damage")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	local instanceDiff, customGroupsTable, customUnitsTable, customUnitsInfo
	local UnitIterator, GetCreatureId = Skada.UnitIterator, Skada.GetCreatureId
	local UnitHealthInfo, UnitPowerInfo = Skada.UnitHealthInfo, Skada.UnitPowerInfo
	local UnitExists, UnitGUID = UnitExists, UnitGUID
	local UnitHealthMax, UnitPowerMax = UnitHealthMax, UnitPowerMax
	local tContains = tContains

	-- this table holds the units to which the damage done is
	-- collected into a new fake unit.
	local customGroups = {}

	-- this table holds units that should create a fake unit
	-- at certain health percentage. Useful in case you want
	-- to collect damage done to the units at certain phases.
	local customUnits = {}

	-- table of acceptable/trackable instance difficulties
	-- uncomments those you want to use or add custom ones.
	local allowed_diffs = {
		-- ["5n"] = true, -- 5man Normal
		-- ["5h"] = true, -- 5man Heroic
		-- ["mc"] = true, -- Mythic Dungeons
		-- ["tw"] = true, -- Time Walker
		-- ["wb"] = true, -- World Boss
		["10n"] = true, -- 10man Normal
		["10h"] = true, -- 10man Heroic
		["25n"] = true, -- 25man Normal
		["25h"] = true, -- 25man Heroic
	}

	local function format_valuetext(d, columns, total, dtps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Damage and Skada:FormatNumber(d.value),
			columns[subview and "sDTPS" or "DTPS"] and Skada:FormatNumber(dtps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function get_instance_diff()
		instanceDiff = instanceDiff or Skada:GetInstanceDiff() or "NaN"
		return instanceDiff
	end

	local function custom_units_max_value(id, guid, unit)
		if id and customUnitsInfo and customUnitsInfo[id] then
			return customUnitsInfo[id]
		end

		local maxval
		for uid in UnitIterator() do
			if UnitExists(uid .. "target") and UnitGUID(uid .. "target") == guid then
				maxval = (unit.power ~= nil) and UnitPowerMax(uid .. "target", unit.power) or UnitHealthMax(uid .. "target")
				if maxval and maxval > 0 then break end -- break only if found!
			end
		end

		if not maxval then
			if unit.power ~= nil then
				_, _, maxval = UnitPowerInfo(nil, guid, unit.power)
			else
				_, _, maxval = UnitHealthInfo(nil, guid)
			end
		end

		if not maxval and unit.values then
			maxval = unit.values[get_instance_diff()]
		end

		if maxval and maxval > 0 then
			customUnitsInfo = customUnitsInfo or T.get("Enemies_UnitsInfo")
			customUnitsInfo[id] = maxval
		end

		return maxval
	end

	local function is_custom_unit(guid, name, amount, overkill)
		if guid and customUnitsTable and customUnitsTable[guid] then
			return (customUnitsTable[guid] ~= -1)
		end

		local id = GetCreatureId(guid)
		local unit = id and customUnits[id]
		if unit then
			customUnitsTable = customUnitsTable or T.get("Enemies_UnitsTable")

			if unit.diff ~= nil and ((type(unit.diff) == "table" and not tContains(unit.diff, get_instance_diff())) or (type(unit.diff) == "string" and get_instance_diff() ~= unit.diff)) then
				customUnitsTable[guid] = -1
				return false
			end

			-- get the unit max value.
			local maxval = custom_units_max_value(id, guid, unit)
			if not maxval or maxval == 0 then
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

			customUnitsTable[guid] = new()
			customUnitsTable[guid].oname = name or L["Unknown"]
			customUnitsTable[guid].name = unit.name
			customUnitsTable[guid].guid = guid
			customUnitsTable[guid].curval = curval
			customUnitsTable[guid].minval = minval
			customUnitsTable[guid].maxval = floor(maxval * (unit.start or 1))
			customUnitsTable[guid].full = maxval
			customUnitsTable[guid].power = (unit.power ~= nil)
			customUnitsTable[guid].useful = unit.useful

			if unit.name == nil then
				customUnitsTable[guid].name = format(
					unit.text or (unit.stop and L["%s - %s%% to %s%%"] or L["%s below %s%%"]),
					name or L["Unknown"],
					(unit.start or 1) * 100,
					(unit.stop or 0) * 100
				)
			end
			return true
		end

		return false
	end

	local function log_custom_unit(set, name, playername, spellid, spellschool, amount, absorbed)
		local e = Skada:GetEnemy(set, name, nil, nil, true)
		if not e then return end

		e.fake = true
		e.damaged = (e.damaged or 0) + amount
		e.totaldamaged = (e.totaldamaged or 0) + amount
		if absorbed > 0 then
			e.totaldamaged = e.totaldamaged + absorbed
		end

		-- spell
		local spell = e.damagedspells and e.damagedspells[spellid]
		if not spell then
			e.damagedspells = e.damagedspells or {}
			e.damagedspells[spellid] = {school = spellschool, amount = amount}
			spell = e.damagedspells[spellid]
		else
			spell.amount = spell.amount + amount
		end

		if spell.total then
			spell.total = spell.total + amount + absorbed
		elseif absorbed > 0 then
			spell.total = spell.amount + absorbed
		end

		-- source
		local source = spell.sources and spell.sources[playername]
		if not source then
			spell.sources = spell.sources or {}
			spell.sources[playername] = {amount = amount}
			source = spell.sources[playername]
		else
			source.amount = source.amount + amount
		end

		if source.total then
			source.total = source.total + amount + absorbed
		elseif absorbed > 0 then
			source.total = source.amount + absorbed
		end
	end

	local function log_custom_group(set, id, name, playername, spellid, spellschool, amount, overkill, absorbed)
		if not (name and customGroups[name]) then return end -- not a custom group.
		if customGroups[name] == L["Halion and Inferno"] and get_instance_diff() ~= "25h" then return end -- rs25hm only
		if customGroupsTable and customGroupsTable[id] then return end -- a custom unit with useful damage.

		amount = (customGroups[name] == L["Princes overkilling"]) and overkill or amount
		log_custom_unit(set, customGroups[name], playername, spellid, spellschool, amount, absorbed)
	end

	local function log_damage(set, dmg, isdot)
		if not set or (set == Skada.total and not P.totalidc) then return end

		local absorbed = dmg.absorbed or 0
		if (dmg.amount + absorbed) == 0 then return end

		local e = Skada:GetEnemy(set, dmg.enemyname, dmg.enemyid, dmg.enemyflags, true)
		if not e then return end

		set.edamaged = (set.edamaged or 0) + dmg.amount
		set.etotaldamaged = (set.etotaldamaged or 0) + dmg.amount

		e.damaged = (e.damaged or 0) + dmg.amount
		e.totaldamaged = (e.totaldamaged or 0) + dmg.amount
		if absorbed > 0 then
			set.etotaldamaged = set.etotaldamaged + absorbed
			e.totaldamaged = e.totaldamaged + absorbed
		end

		-- damage spell.
		local spellid = isdot and -dmg.spellid or dmg.spellid
		local spell = e.damagedspells and e.damagedspells[spellid]
		if not spell then
			e.damagedspells = e.damagedspells or {}
			e.damagedspells[spellid] = {school = dmg.spellschool, amount = dmg.amount}
			spell = e.damagedspells[spellid]
		else
			spell.amount = spell.amount + dmg.amount
		end

		if spell.total then
			spell.total = spell.total + dmg.amount + absorbed
		elseif absorbed > 0 then
			spell.total = spell.amount + absorbed
		end

		local overkill = dmg.overkill or 0
		if overkill > 0 then
			spell.o_amt = (spell.o_amt or 0) + overkill
		end

		-- damage source.
		if not dmg.srcName then return end

		-- the source
		local source = spell.sources and spell.sources[dmg.srcName]
		if not source then
			spell.sources = spell.sources or {}
			spell.sources[dmg.srcName] = {amount = dmg.amount}
			source = spell.sources[dmg.srcName]
		else
			source.amount = source.amount + dmg.amount
		end

		if source.total then
			source.total = source.total + dmg.amount + absorbed
		elseif absorbed > 0 then
			source.total = source.amount + absorbed
		end

		if overkill > 0 then
			source.o_amt = (source.o_amt or 0) + dmg.overkill
		end

		-- the rest of the code is only for allowed instance diffs.
		if not allowed_diffs[get_instance_diff()] then return end

		if is_custom_unit(dmg.enemyid, dmg.enemyname, dmg.amount, overkill) then
			local unit = customUnitsTable[dmg.enemyid]
			-- started with less than max?
			if unit.full then
				local amount = unit.full - unit.curval
				if unit.useful then
					e.usefuldamaged = (e.usefuldamaged or 0) + amount
					spell.useful = (spell.useful or 0) + amount
					source.useful = (source.useful or 0) + amount
				end
				if unit.maxval == unit.full then
					log_custom_unit(set, unit.name, dmg.srcName, spellid, dmg.spellschool, amount, absorbed)
				end
				unit.full = nil
			elseif unit.curval >= unit.maxval then
				local amount = dmg.amount - overkill
				unit.curval = unit.curval - amount

				if unit.curval <= unit.maxval then
					log_custom_unit(set, unit.name, dmg.srcName, spellid, dmg.spellschool, unit.maxval - unit.curval, absorbed)
					amount = amount - (unit.maxval - unit.curval)
					if customGroups[unit.oname] and unit.useful then
						log_custom_group(set, unit.guid, unit.oname, dmg.srcName, spellid, dmg.spellschool, amount, overkill, absorbed)
						customGroupsTable = customGroupsTable or T.get("Enemies_GroupsTable")
						customGroupsTable[unit.guid] = true
					end
					if customGroups[unit.name] then
						log_custom_group(set, unit.guid, unit.name, dmg.srcName, spellid, dmg.spellschool, unit.maxval - unit.curval, overkill, absorbed)
					end
				end
				if unit.useful then
					e.usefuldamaged = (e.usefuldamaged or 0) + amount
					spell.useful = (spell.useful or 0) + amount
					source.useful = (source.useful or 0) + amount
				end
			elseif unit.curval >= unit.minval then
				local amount = dmg.amount - overkill
				unit.curval = unit.curval - amount

				if customGroups[unit.name] then
					log_custom_group(set, unit.guid, unit.name, dmg.srcName, spellid, dmg.spellschool, amount, overkill, absorbed)
				end

				if unit.curval <= unit.minval then
					log_custom_unit(set, unit.name, dmg.srcName, spellid, dmg.spellschool, amount - (unit.minval - unit.curval), absorbed)

					-- remove it
					local guid = unit.guid
					customUnitsTable[guid] = del(customUnitsTable[guid])
					customUnitsTable[guid] = -1
				else
					log_custom_unit(set, unit.name, dmg.srcName, spellid, dmg.spellschool, amount, absorbed)
				end
			elseif unit.power then
				log_custom_unit(set, unit.name, dmg.srcName, spellid, dmg.spellschool, dmg.amount - (unit.useful and overkill or 0), absorbed)
			end
		end

		-- custom groups
		log_custom_group(set, dmg.enemyid, dmg.enemyname, dmg.srcName, spellid, dmg.spellschool, dmg.amount, overkill, absorbed)
	end

	local dmg = {}

	local function spell_damage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)

			if eventtype == "SWING_DAMAGE" then
				dmg.spellid, dmg.spellschool = 6603, 0x01
				dmg.amount, dmg.overkill, _, _, _, dmg.absorbed = ...
			else
				dmg.spellid, _, dmg.spellschool, dmg.amount, dmg.overkill, _, _, _, dmg.absorbed = ...
			end

			if dmg.spellid and not ignoredSpells[dmg.spellid] then
				dmg.enemyid = dstGUID
				dmg.enemyname = dstName
				dmg.enemyflags = dstFlags

				dmg.srcGUID = srcGUID
				dmg.srcName = srcName
				dmg.srcFlags = srcFlags

				Skada:DispatchSets(log_damage, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
			end
		end
	end

	local function spell_missed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			local spellid, spellschool, misstype, amount

			if eventtype == "SWING_MISSED" then
				spellid, spellschool = 6603, 0x01
				misstype, amount = ...
			else
				spellid, _, spellschool, misstype, amount = ...
			end

			if misstype == "ABSORB" and spellid and not ignoredSpells[spellid] then
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

				Skada:DispatchSets(log_damage, dmg, eventtype == "SPELL_PERIODIC_MISSED")
			end
		end
	end

	local function sourcemod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local damage, overkill, useful = set:GetActorDamageFromSource(win.targetid, win.targetname, label)
		if damage == 0 then return end

		tooltip:AddLine(format(L["%s's damage breakdown"], label))
		tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(damage), 1, 1, 1)
		if useful > 0 then
			tooltip:AddDoubleLine(L["Useful Damage"], format("%s (%s)", Skada:FormatNumber(useful), Skada:FormatPercent(useful, damage)), 1, 1, 1)

			-- override overkill
			overkill = max(0, damage - useful)
			tooltip:AddDoubleLine(L["Overkill"], format("%s (%s)", Skada:FormatNumber(overkill), Skada:FormatPercent(overkill, damage)), 1, 1, 1)
		elseif overkill > 0 then
			tooltip:AddDoubleLine(L["Overkill"], format("%s (%s)", Skada:FormatNumber(overkill), Skada:FormatPercent(overkill, damage)), 1, 1, 1)
		end
	end

	local function usefulmod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local e = set and set:GetEnemy(label, id)
		local amount, total, useful = e:GetDamageTakenBreakdown()
		if not useful or useful == 0 then return end

		tooltip:AddLine(format(L["%s's damage breakdown"], label))
		tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(total), 1, 1, 1)
		tooltip:AddDoubleLine(L["Useful Damage"], format("%s (%s)", Skada:FormatNumber(useful), Skada:FormatPercent(useful, total)), 1, 1, 1)
		local overkill = max(0, total - useful)
		tooltip:AddDoubleLine(L["Overkill"], format("%s (%s)", Skada:FormatNumber(overkill), Skada:FormatPercent(overkill, total)), 1, 1, 1)
	end

	function spellsourcemod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = pformat(L["%s's <%s> sources"], win.targetname, label)
	end

	function spellsourcemod:Update(win, set)
		win.title = pformat(L["%s's <%s> sources"], win.targetname, win.spellname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		if not win.spellid then return end

		local actor = set and set:GetEnemy(win.targetname, win.targetid)
		if not (actor and actor.GetDamageSpellSources) then return end

		local sources, total = actor:GetDamageSpellSources(win.spellid)

		if not sources or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDTPS and actor:GetTime(), 0
		for sourcename, source in pairs(sources) do
			if not win.class or win.class == source.class then
				nr = nr + 1
				local d = win:actor(nr, source, nil, sourcename)

				d.value = source.amount
				format_valuetext(d, mod.metadata.columns, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function sourcemod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's damage sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = pformat(L["%s's damage sources"], win.targetname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		local actor = set and set:GetEnemy(win.targetname, win.targetid)
		if not actor then return end

		local sources, total = actor:GetDamageSources()

		if not sources or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDTPS and actor:GetTime(), 0
		for sourcename, source in pairs(sources) do
			if not win.class or win.class == source.class then
				nr = nr + 1
				local d = win:actor(nr, source, nil, sourcename)

				d.value = source.amount or 0
				if P.absdamage and source.total then
					d.value = source.total
				end

				format_valuetext(d, mod.metadata.columns, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function sourcespellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor damage"](label or L["Unknown"], win.targetname or L["Unknown"])
	end

	function sourcespellmod:Update(win, set)
		win.title = L["actor damage"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not win.actorname or not win.targetname then return end

		local actor = set and set:GetEnemy(win.targetname, win.targetid)
		local sources = actor and actor:GetDamageSources()
		if sources and sources[win.actorname] then
			local total = sources[win.actorname].amount or 0
			if P.absdamage and sources[win.actorname].total then
				total = sources[win.actorname].total
			end

			if total == 0 then
				return
			elseif win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDTPS and actor:GetTime(), 0
			for spellid, spell in pairs(actor.damagedspells or actor.damagetakenspells) do
				if spell.sources and spell.sources[win.actorname] then
					nr = nr + 1
					local d = win:spell(nr, spellid, spell)

					d.value = spell.sources[win.actorname].amount or 0
					if P.absdamage and spell.sources[win.actorname].total then
						d.value = spell.sources[win.actorname].total
					end

					format_valuetext(d, mod.metadata.columns, total, actortime and (d.value / actortime), win.metadata, true)
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["Damage taken by %s"], label)
	end

	function spellmod:Update(win, set)
		win.title = pformat(L["Damage taken by %s"], win.targetname)

		local actor = set and set:GetEnemy(win.targetname, win.targetid)
		local total = actor and actor:GetDamageTaken() or 0

		if total == 0 or not (actor.damagedspells or actor.damagetakenspells) then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDTPS and actor:GetTime(), 0
		for spellid, spell in pairs(actor.damagedspells or actor.damagetakenspells) do
			nr = nr + 1
			local d = win:spell(nr, spellid, spell)

			d.value = spell.amount or 0
			if P.absdamage and spell.total then
				d.value = spell.total
			end

			format_valuetext(d, mod.metadata.columns, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function usefulmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["Useful damage on %s"], label)
	end

	function usefulmod:Update(win, set)
		win.title = pformat(L["Useful damage on %s"], win.targetname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		local actor = set and set:GetEnemy(win.targetname, win.targetid)
		local total = actor and (actor.usefuldamaged or actor.usefuldamagetaken) or 0
		local sources = (total > 0) and actor:GetDamageSources()

		if not sources then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDTPS and actor:GetTime(), 0
		for sourcename, source in pairs(sources) do
			if source.useful and source.useful > 0 and (not win.class or win.class == source.class) then
				nr = nr + 1
				local d = win:actor(nr, source, nil, sourcename)

				d.value = source.useful
				format_valuetext(d, mod.metadata.columns, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Enemy Damage Taken"]
		local total = set and set:GetEnemyDamageTaken() or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for i = 1, #set.enemies do
			local enemy = set.enemies[i]
			if enemy then
				local dtps, amount = enemy:GetDTPS()
				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, enemy, true)

					d.value = amount
					format_valuetext(d, self.metadata.columns, total, dtps, win.metadata)
				end
			end
		end
	end

	function mod:OnEnable()
		spellsourcemod.metadata = {
			showspots = true,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"]
		}
		usefulmod.metadata = {
			showspots = true,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"]
		}
		sourcemod.metadata = {
			showspots = true,
			click1 = sourcespellmod,
			click4 = Skada.FilterClass,
			post_tooltip = sourcemod_tooltip,
			click4_label = L["Toggle Class Filter"]
		}
		spellmod.metadata = {click1 = spellsourcemod, valueorder = true}
		self.metadata = {
			click1 = sourcemod,
			click2 = spellmod,
			click3 = usefulmod,
			post_tooltip = usefulmod_tooltip,
			columns = {Damage = true, DTPS = false, Percent = true, sDTPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_fire_felflamebolt]]
		}

		-- no total click.
		sourcemod.nototal = true
		spellmod.nototal = true
		usefulmod.nototal = true

		local flags_src_dst = {src_is_interesting = true, dst_is_not_interesting = true}

		Skada:RegisterForCL(
			spell_damage,
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			flags_src_dst
		)

		Skada:RegisterForCL(
			spell_missed,
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED",
			flags_src_dst
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, L["Enemies"])

		-- table of ignored spells:
		if Skada.ignoredSpells and Skada.ignoredSpells.damage then
			ignoredSpells = Skada.ignoredSpells.damage
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:CombatLeave()
		instanceDiff = nil
		T.free("Enemies_UnitsInfo", customUnitsInfo)
		T.free("Enemies_UnitsTable", customUnitsTable, nil, del)
		T.free("Enemies_GroupsTable", customGroupsTable)
	end

	function mod:OnInitialize()
		-- ----------------------------
		-- Custom Groups
		-- ----------------------------

		-- The Lich King: Useful targets
		customGroups[L["The Lich King"]] = L["Important targets"]
		customGroups[L["Raging Spirit"]] = L["Important targets"]
		customGroups[L["Ice Sphere"]] = L["Important targets"]
		customGroups[L["Val'kyr Shadowguard"]] = L["Important targets"]
		customGroups[L["Wicked Spirit"]] = L["Important targets"]

		-- Professor Putricide: Oozes
		customGroups[L["Gas Cloud"]] = L["Oozes"]
		customGroups[L["Volatile Ooze"]] = L["Oozes"]

		-- Blood Prince Council: Princes overkilling
		customGroups[L["Prince Valanar"]] = L["Princes overkilling"]
		customGroups[L["Prince Taldaram"]] = L["Princes overkilling"]
		customGroups[L["Prince Keleseth"]] = L["Princes overkilling"]

		-- Lady Deathwhisper: Adds
		customGroups[L["Cult Adherent"]] = L["Adds"]
		customGroups[L["Empowered Adherent"]] = L["Adds"]
		customGroups[L["Reanimated Adherent"]] = L["Adds"]
		customGroups[L["Cult Fanatic"]] = L["Adds"]
		customGroups[L["Deformed Fanatic"]] = L["Adds"]
		customGroups[L["Reanimated Fanatic"]] = L["Adds"]
		customGroups[L["Darnavan"]] = L["Adds"]

		-- Halion: Halion and Inferno
		customGroups[L["Halion"]] = L["Halion and Inferno"]
		customGroups[L["Living Inferno"]] = L["Halion and Inferno"]

		-- ----------------------------
		-- Custom Units
		-- ----------------------------

		-- ICC: Lady Deathwhisper
		customUnits[36855] = {
			start = 0, power = 0, text = L["%s - Phase 2"],
			values = {["10n"] = 3264800, ["10h"] = 3264800, ["25n"] = 11193600, ["25h"] = 13992000}
		}

		-- ICC: Professor Putricide
		customUnits[36678] = {
			start = 0.35, text = L["%s - Phase 3"],
			values = {["10n"] = 9761500, ["10h"] = 13666100, ["25n"] = 41835000, ["25h"] = 50202000}
		}

		-- ICC: Sindragosa
		customUnits[36853] = {
			start = 0.35, text = L["%s - Phase 2"],
			values = {["10n"] = 11156000, ["10h"] = 13945000, ["25n"] = 38348750, ["25h"] = 46018500}
		}

		-- ICC: The Lich King
		customUnits[36597] = {
			start = 0.4, stop = 0.1, text = L["%s - Phase 3"],
			values = {["10n"] = 17431250, ["10h"] = 29458813, ["25n"] = 61009375, ["25h"] = 103151165}
		}

		-- ICC: Valkyrs overkilling
		customUnits[36609] = {
			name = L["Valkyrs overkilling"],
			diff = {"10h", "25h"}, start = 0.5, useful = true,
			values = {["10h"] = 1417500, ["25h"] = 2992000}
		}

		-- ToC: Anub'arak
		customUnits[34564] = {
			start = 0.3, text = L["%s - Phase 2"],
			values = {["10n"] = 4183500, ["10h"] = 5438550, ["25n"] = 20917500, ["25h"] = 27192750}
		}
	end

	---------------------------------------------------------------------------

	function setPrototype:GetEnemyDamageTaken()
		if not self.enemies then
			return 0
		elseif P.absdamage and (self.etotaldamaged or self.totaldamagetaken) then
			return self.etotaldamaged or self.totaldamagetaken
		elseif self.edamaged or self.edamagetaken then
			return self.edamaged or self.edamagetaken
		end

		local total = 0
		for i = 1, #self.enemies do
			local e = self.enemies[i]
			if e and not e.fake and P.absdamage and (e.totaldamaged or e.totaldamagetaken) then
				total = total + (e.totaldamaged or e.totaldamagetaken)
			elseif e and not e.fake and (e.damaged or e.damagetaken) then
				total = total + (e.damaged or e.damagetaken)
			end
		end
		return total
	end

	function setPrototype:GetEnemyDTPS()
		local damage = self:GetEnemyDamageTaken()
		if damage > 0 then
			return damage / max(1, self:GetTime()), damage
		end
		return 0, damage
	end

	function enemyPrototype:GetDamageSpellSources(spellid, tbl)
		local spell = self.damagedspells and self.damagedspells[spellid]
		spell = spell or self.damagetakenspells and self.damagetakenspells[spellid]

		if spell and spell.sources then
			tbl = clear(tbl or C)

			local total = spell.amount or 0
			if P.absdamage and spell.total then
				total = spell.total
			end

			for name, source in pairs(spell.sources) do
				if not tbl[name] then
					tbl[name] = new()
					tbl[name].amount = P.absdamage and source.total or source.amount or 0
				elseif P.absdamage and source.total then
					tbl[name].amount = tbl[name].amount + source.total
				else
					tbl[name].amount = tbl[name].amount + source.amount
				end

				self.super:_fill_actor_table(tbl[name], name)
			end

			return tbl, total
		end
	end

	function enemyPrototype:GetDamageTakenBreakdown()
		if self.damagedspells or self.damagetakenspells then
			local amount, total, useful = 0, 0, 0
			local sources = self:GetDamageSources()
			if sources then
				for _, source in pairs(sources) do
					amount = amount + (source.amount or 0)
					total = total + (source.total or 0)
					if source.useful then
						useful = useful + source.useful
					end
				end
			end
			return amount, total, useful
		end
	end
end)

---------------------------------------------------------------------------
-- Enemy Damage Done

Skada:RegisterModule("Enemy Damage Done", function(L, P, _, C, new, _, clear)
	local mod = Skada:NewModule("Enemy Damage Done")
	local targetmod = mod:NewModule("Damage target list")
	local targetspellmod = targetmod:NewModule("Damage spell targets")
	local spellmod = mod:NewModule("Damage spell list")
	local spelltargetmod = spellmod:NewModule("Damage spell targets")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local passiveSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	local function format_valuetext(d, columns, total, dps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Damage and Skada:FormatNumber(d.value),
			columns[subview and "sDPS" or "DPS"] and dps and Skada:FormatNumber(dps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_damage(set, dmg, isdot)
		if not set or (set == Skada.total and not P.totalidc) then return end

		local absorbed = dmg.absorbed or 0
		if (dmg.amount + absorbed) == 0 then return end

		local e = Skada:GetEnemy(set, dmg.enemyname, dmg.enemyid, dmg.enemyflags, true)
		if not e then return end

		if (set.type == "arena" or set.type == "pvp") and e.class and Skada.validclass[e.class] and e.role ~= "HEALER" then
			Skada:AddActiveTime(set, e, dmg.amount > 0 and dmg.spellid and not passiveSpells[dmg.spellid], nil, dmg.dstName)
		end

		set.edamage = (set.edamage or 0) + dmg.amount
		set.etotaldamage = (set.etotaldamage or 0) + dmg.amount

		e.damage = (e.damage or 0) + dmg.amount
		e.totaldamage = (e.totaldamage or 0) + dmg.amount

		local overkill = dmg.overkill or 0
		if overkill > 0 then
			set.eoverkill = (set.eoverkill or 0) + dmg.overkill
			e.overkill = (e.overkill or 0) + dmg.overkill
		end

		-- damage spell.
		local spellid = isdot and -dmg.spellid or dmg.spellid
		local spell = e.damagespells and e.damagespells[spellid]
		if not spell then
			e.damagespells = e.damagespells or {}
			e.damagespells[spellid] = {school = dmg.spellschool, amount = dmg.amount}
			spell = e.damagespells[spellid]
		else
			spell.amount = spell.amount + dmg.amount
		end

		if absorbed > 0 then
			set.etotaldamage = set.etotaldamage + absorbed
			e.totaldamage = e.totaldamage + absorbed
			spell.total = (spell.total and (spell.total + dmg.amount) or spell.amount) + absorbed
		end

		if overkill > 0 then
			spell.o_amt = (spell.o_amt or 0) + dmg.overkill
		end

		-- damage target.
		if not dmg.dstName then return end

		local target = spell.targets and spell.targets[dmg.dstName]
		if not target then
			spell.targets = spell.targets or {}
			spell.targets[dmg.dstName] = {amount = dmg.amount}
			target = spell.targets[dmg.dstName]
		else
			target.amount = target.amount + dmg.amount
		end

		if target.total then
			target.total = target.total + dmg.amount + absorbed
		elseif absorbed > 0 then
			target.total = target.amount + absorbed
		end

		if overkill > 0 then
			target.o_amt = (target.o_amt or 0) + dmg.overkill
		end
	end

	local dmg = {}

	local function spell_damage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			if eventtype == "SWING_DAMAGE" then
				dmg.spellid, dmg.spellschool = 6603, 0x01
				dmg.amount, dmg.overkill, _, _, _, dmg.absorbed = ...
			else
				dmg.spellid, _, dmg.spellschool, dmg.amount, dmg.overkill, _, _, _, dmg.absorbed = ...
			end

			if dmg.spellid and not ignoredSpells[dmg.spellid] then
				dmg.enemyid = srcGUID
				dmg.enemyname = srcName
				dmg.enemyflags = srcFlags

				dmg.dstGUID = dstGUID
				dmg.dstName = dstName
				dmg.dstFlags = dstFlags

				Skada:DispatchSets(log_damage, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
			end
		end
	end

	local function spell_missed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcName and dstName then
			local spellid, spellschool, misstype, amount

			if eventtype == "SWING_MISSED" then
				spellid, spellschool = 6603, 0x01
				misstype, amount = ...
			else
				spellid, _, spellschool, misstype, amount = ...
			end

			if misstype == "ABSORB" and spellid and not ignoredSpells[spellid] then
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

				Skada:DispatchSets(log_damage, dmg, eventtype == "SPELL_PERIODIC_MISSED")
			end
		end
	end

	function targetspellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor damage"](win.targetname or L["Unknown"], label)
	end

	function targetspellmod:Update(win, set)
		win.title = L["actor damage"](win.targetname or L["Unknown"], win.actorname or L["Unknown"])
		if not (win.targetname and win.actorname) then return end

		local actor = set and set:GetEnemy(win.targetname, win.targetid)
		if not (actor and actor.GetDamageTargetSpells) then return end
		local spells, total = actor:GetDamageTargetSpells(win.actorname)

		if not spells or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
		for spellid, spell in pairs(spells) do
			nr = nr + 1
			local d = win:spell(nr, spellid, spell)

			d.value = spell.amount
			format_valuetext(d, mod.metadata.columns, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function spelltargetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = pformat(L["%s's <%s> targets"], win.targetname, label)
	end

	function spelltargetmod:Update(win, set)
		win.title = pformat(L["%s's <%s> targets"], win.targetname, win.spellname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		if not win.spellid then return end

		local actor = set and set:GetEnemy(win.targetname, win.targetid)
		if not (actor and actor.GetDamageSpellTargets) then return end

		local targets, total = actor:GetDamageSpellTargets(win.spellid)

		if not targets or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
		for targetname, target in pairs(targets) do
			if not win.class or win.class == target.class then
				nr = nr + 1
				local d = win:actor(nr, target, nil, targetname)

				d.value = target.amount
				format_valuetext(d, mod.metadata.columns, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's targets"], win.targetname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		local actor = set and set:GetEnemy(win.targetname, win.targetid)
		if not actor then return end

		local targets, total = actor:GetDamageTargets()

		if not targets or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
		for targetname, target in pairs(targets) do
			if not win.class or win.class == target.class then
				nr = nr + 1
				local d = win:actor(nr, target, true, targetname)

				d.value = target.amount
				if P.absdamage and target.total then
					d.value = target.total
				end

				format_valuetext(d, mod.metadata.columns, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor damage"](label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor damage"](win.targetname or L["Unknown"])

		local actor = set and set:GetEnemy(win.targetname, win.targetid)
		local total = actor and actor:GetDamage() or 0

		if total == 0 or not actor.damagespells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
		for spellid, spell in pairs(actor.damagespells) do
			nr = nr + 1
			local d = win:spell(nr, spellid, spell)

			d.value = spell.amount
			if P.absdamage and spell.total then
				d.value = spell.total
			end

			format_valuetext(d, mod.metadata.columns, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = L["Enemy Damage Done"]

		local total = set and set:GetEnemyDamage() or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for i = 1, #set.enemies do
			local enemy = set.enemies[i]
			if enemy and not enemy.fake then
				local dps, amount = enemy:GetDPS()
				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, enemy, true)

					d.value = amount
					format_valuetext(d, self.metadata.columns, total, dps, win.metadata)
				end
			end
		end
	end

	function mod:OnEnable()
		spelltargetmod.metadata = {
			showspots = true,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"]
		}
		targetmod.metadata = {
			showspots = true,
			click1 = targetspellmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"]
		}
		spellmod.metadata = {click1 = spelltargetmod, valueorder = true}
		self.metadata = {
			click1 = targetmod,
			click2 = spellmod,
			columns = {Damage = true, DPS = false, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_shadow_shadowbolt]]
		}

		-- no total click.
		targetmod.nototal = true
		spellmod.nototal = true

		local flags_dst_src = {dst_is_interesting_nopets = true, src_is_not_interesting = true}

		Skada:RegisterForCL(
			spell_damage,
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			flags_dst_src
		)

		Skada:RegisterForCL(
			spell_missed,
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED",
			flags_dst_src
		)

		Skada:AddMode(self, L["Enemies"])

		-- table of ignored damage/time spells:
		if Skada.ignoredSpells then
			if Skada.ignoredSpells.damaged then
				ignoredSpells = Skada.ignoredSpells.damaged
			end
			if Skada.ignoredSpells.activeTime then
				passiveSpells = Skada.ignoredSpells.activeTime
			end
		end
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function setPrototype:GetEnemyDamage()
		if not self.enemies then
			return 0
		elseif P.absdamage and self.etotaldamage then
			return self.etotaldamage
		elseif self.edamage then
			return self.edamage
		end

		local total = 0
		for i = 1, #self.enemies do
			local e = self.enemies[i]
			if e and not e.fake and P.absdamage and e.totaldamage then
				total = total + e.totaldamage
			elseif e and not e.fake and e.damage then
				total = total + e.damage
			end
		end
		return total
	end

	function setPrototype:GetEnemyDPS()
		local dps, damage = 0, self:GetEnemyDamage()
		if damage > 0 then
			dps = damage / max(1, self:GetTime())
		end
		return dps, damage
	end

	function setPrototype:GetEnemyOverkill()
		return self.eoverkill or 0
	end

	function enemyPrototype:GetDamageTargetSpells(name, tbl)
		if self.damagespells and name then
			tbl = clear(tbl or C)
			local total = 0

			for spellid, spell in pairs(self.damagespells) do
				if spell.targets and spell.targets[name] then
					local amount = P.absdamage and spell.targets[name].total or spell.targets[name].amount
					if not tbl[spellid] then
						tbl[spellid] = new()
						tbl[spellid].school = spell.school
						tbl[spellid].amount = amount
					else
						tbl[spellid].amount = tbl[spellid].amount + amount
					end

					total = total + tbl[spellid].amount
				end
			end

			return tbl, total
		end
	end

	function enemyPrototype:GetDamageSpellTargets(spellid, tbl)
		if self.damagespells and self.damagespells[spellid] and self.damagespells[spellid].targets then
			tbl = clear(tbl or C)

			local total = self.damagespells[spellid].amount or 0
			if P.absdamage and self.damagespells[spellid].total then
				total = self.damagespells[spellid].total
			end

			for name, target in pairs(self.damagespells[spellid].targets) do
				local amount = P.absdamage and target.total or target.amount
				if not tbl[name] then
					tbl[name] = new()
					tbl[name].amount = amount
				else
					tbl[name].amount = tbl[name].amount + amount
				end

				self.super:_fill_actor_table(tbl[name], name)
			end

			return tbl, total
		end
	end
end)

---------------------------------------------------------------------------
-- Enemy Healing Done

Skada:RegisterModule("Enemy Healing Done", function(L, P)
	local mod = Skada:NewModule("Enemy Healing Done")
	local targetmod = mod:NewModule("Healed target list")
	local spellmod = mod:NewModule("Healing spell list")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local passiveSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	local function format_valuetext(d, columns, total, dps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Healing and Skada:FormatNumber(d.value),
			columns[subview and "sHPS" or "HPS"] and hps and Skada:FormatNumber(dps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_heal(set, data, ishot)
		if not set or (set == Skada.total and not P.totalidc) then return end

		if not data.amount or data.amount == 0 then return end

		local e = Skada:GetEnemy(set, data.enemyname, data.enemyid, data.enemyflags, true)
		if not e then return end

		if (set.type == "arena" or set.type == "pvp") and e.class and Skada.validclass[e.class] and e.role == "HEALER" then
			Skada:AddActiveTime(set, e, data.amount > 0 and data.spellid and not passiveSpells[data.spellid], nil, data.dstName)
		end

		set.eheal = (set.eheal or 0) + data.amount
		e.heal = (e.heal or 0) + data.amount

		local spellid = ishot and -data.spellid or data.spellid
		local spell = e.healspells and e.healspells[spellid]
		if not spell then
			e.healspells = e.healspells or {}
			e.healspells[spellid] = {school = data.spellschool, amount = data.amount}
			spell = e.healspells[spellid]
		else
			spell.amount = spell.amount + data.amount
		end

		if data.dstName then
			spell.targets = spell.targets or {}
			spell.targets[data.dstName] = (spell.targets[data.dstName] or 0) + data.amount
		end
	end

	local heal = {}

	local function spell_heal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, _, spellschool, amount, overheal = ...
		if spellid and not ignoredSpells[spellid] then
			heal.enemyid = srcGUID
			heal.enemyname = srcName
			heal.enemyflags = srcFlags

			heal.dstGUID = dstGUID
			heal.dstName = dstName
			heal.dstFlags = dstFlags

			heal.spellid = spellid
			heal.spellschool = spellschool
			heal.amount = max(0, amount - overheal)

			Skada:DispatchSets(log_heal, heal, eventtype == "SPELL_PERIODIC_HEAL")
		end
	end

	function targetmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's healed targets"], win.targetname)

		local actor = set and set:GetEnemy(win.targetname, win.targetid)
		local total = actor and actor.heal or 0
		local targets = (total > 0) and actor:GetHealTargets()

		if not targets or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for targetname, target in pairs(targets) do
			nr = nr + 1
			local d = win:actor(nr, target, true, targetname)

			d.value = target.amount
			format_valuetext(d, mod.metadata.columns, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor heal spells"](label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor heal spells"](win.targetname or L["Unknown"])

		local actor = set and set:GetEnemy(win.targetname, win.targetid)
		local total = actor and actor.heal or 0

		if total == 0 or not actor.healspells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for spellid, spell in pairs(actor.healspells) do
			nr = nr + 1
			local d = win:spell(nr, spellid, spell, true)

			d.value = spell.amount
			format_valuetext(d, mod.metadata.columns, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = L["Enemy Healing Done"]
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		local total = set and set:GetEnemyHeal() or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for i = 1, #set.enemies do
			local enemy = set.enemies[i]
			if enemy and enemy.heal and (not win.class or win.class == enemy.class) then
				local hps, amount = enemy:GetHPS()
				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, enemy, true)

					d.value = amount
					format_valuetext(d, self.metadata.columns, total, hps, win.metadata)
				end
			end
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {valueorder = true}
		self.metadata = {
			showspots = true,
			click1 = spellmod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_holy_blessedlife]]
		}

		-- no total click.
		spellmod.nototal = true
		targetmod.nototal = true

		Skada:RegisterForCL(
			spell_heal,
			"SPELL_HEAL",
			"SPELL_PERIODIC_HEAL",
			{src_is_not_interesting = true, dst_is_not_interesting = true}
		)

		Skada:AddMode(self, L["Enemies"])

		-- table of ignored heal/time spells:
		if Skada.ignoredSpells then
			if Skada.ignoredSpells.heals then
				ignoredSpells = Skada.ignoredSpells.heals
			end
			if Skada.ignoredSpells.activeTime then
				passiveSpells = Skada.ignoredSpells.activeTime
			end
		end
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function setPrototype:GetEnemyHeal(absorb)
		local heal = 0
		if not self.enemies then
			return heal
		end

		if self.eheal then
			heal = self.eheal

			if absorb and self.eabsorb then
				heal = heal + self.eabsorb
			end
		else
			for i = 1, #self.enemies do
				local e = self.enemies[i]
				if e and e.heal then
					heal = heal + e.heal

					if absorb and e.absorb then
						heal = heal + e.absorb
					end
				end
			end
		end

		return heal
	end

	function setPrototype:GetEnemyHPS(absorb, active)
		local hps, amount = 0, self:GetEnemyHeal(absorb)

		if amount > 0 then
			hps = amount / max(1, self:GetTime(active))
		end

		return hps, amount
	end
end)
