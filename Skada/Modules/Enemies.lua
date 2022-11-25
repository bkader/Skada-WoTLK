local _, Skada = ...
local Private = Skada.Private

-- frequently used globals --
local pairs, type, format, max = pairs, type, string.format, math.max
local wipe, uformat, new, clear = wipe, Private.uformat, Private.newTable, Private.clearTable
local setPrototype, enemyPrototype = Skada.setPrototype, Skada.enemyPrototype

---------------------------------------------------------------------------
-- Enemy Damage Taken

Skada:RegisterModule("Enemy Damage Taken", function(L, P, _, C)
	local mode = Skada:NewModule("Enemy Damage Taken")
	local mode_source = mode:NewModule("Source List")
	local mode_source_spell = mode_source:NewModule("Spell List")
	local mode_spell = mode:NewModule("Spell List")
	local mode_spell_source = mode_spell:NewModule("Source List")
	local mode_useful = mode:NewModule("Useful Damage")
	local ignored_spells = Skada.ignored_spells.damage -- Edit Skada\Core\Tables.lua
	local grouped_units = Skada.grouped_units -- Edit Skada\Core\Tables.lua
	local custom_units = Skada.custom_units -- Edit Skada\Core\Tables.lua
	local mode_cols = nil

	local instanceDiff, customGroupsTable, customUnitsTable
	local GetUnitIdFromGUID, GetCreatureId = Skada.GetUnitIdFromGUID, Skada.GetCreatureId
	local UnitHealthInfo, UnitPowerInfo = Skada.UnitHealthInfo, Skada.UnitPowerInfo
	local UnitExists, UnitGUID = UnitExists, UnitGUID
	local UnitHealthMax, UnitPowerMax = UnitHealthMax, UnitPowerMax
	local del = Private.delTable

	-- table of acceptable/trackable instance difficulties
	-- uncomments those you want to use or add custom ones.
	local allowed_diffs = {
		["5n"] = false, -- 5man Normal
		["5h"] = false, -- 5man Heroic
		["mc"] = false, -- Mythic Dungeons
		["tw"] = false, -- Time Walker
		["wb"] = false, -- World Boss
		["10n"] = true, -- 10man Normal
		["10h"] = true, -- 10man Heroic
		["25n"] = true, -- 25man Normal
		["25h"] = true, -- 25man Heroic
	}

	local function format_valuetext(d, columns, total, dtps, metadata, subview, dont_sort)
		d.valuetext = Skada:FormatValueCols(
			columns.Damage and Skada:FormatNumber(d.value),
			columns[subview and "sDTPS" or "DTPS"] and Skada:FormatNumber(dtps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if not dont_sort and metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function get_instance_diff()
		if not instanceDiff then
			instanceDiff = Skada:GetInstanceDiff() or "NaN"
		end
		return instanceDiff
	end

	local function custom_units_max_value(guid, unit)
		local diff = get_instance_diff()
		local maxval = unit.values and unit.values[diff]
		if not maxval then
			local uid = GetUnitIdFromGUID(guid)
			if uid then
				maxval = (unit.power ~= nil) and UnitPowerMax(uid, unit.power) or UnitHealthMax(uid)
			end

			if maxval then
				unit.values = unit.values or {}
				unit.values[diff] = maxval
			end
		end
		return maxval
	end

	local function is_custom_unit(guid, name, amount, overkill)
		if guid and customUnitsTable and customUnitsTable[guid] then
			return (customUnitsTable[guid] ~= -1)
		end

		local unit = custom_units[GetCreatureId(guid)]
		if not unit then
			-- prevent constant checking...
			customUnitsTable = customUnitsTable or {}
			customUnitsTable[guid] = -1
			return false
		end

		customUnitsTable = customUnitsTable or {}

		if unit.diff ~= nil and ((type(unit.diff) == "table" and not unit.diff[get_instance_diff()]) or (type(unit.diff) == "string" and get_instance_diff() ~= unit.diff)) then
			customUnitsTable[guid] = -1
			return false
		end

		-- get the unit max value.
		local maxval = custom_units_max_value(guid, unit)
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

		local t = new()
		t.oname = name or L["Unknown"]
		t.name = unit.name
		t.guid = guid
		t.curval = curval
		t.minval = minval
		t.maxval = floor(maxval * (unit.start or 1))
		t.full = maxval
		t.power = (unit.power ~= nil)
		t.useful = unit.useful

		if unit.name == nil then
			local str = unit.text or (unit.stop and L["%s - %s%% to %s%%"] or L["%s below %s%%"])
			t.name = format(str, t.oname, (unit.start or 1) * 100, (unit.stop or 0) * 100)
		end

		customUnitsTable[guid] = t
		return true
	end

	local function log_custom_unit(set, name, playername, spellid, amount, absorbed)
		local e = Skada:GetActor(set, name, name, true)
		if not e then return end

		e.damaged = (e.damaged or 0) + amount
		e.totaldamaged = (e.totaldamaged or 0) + amount
		if absorbed > 0 then
			e.totaldamaged = e.totaldamaged + absorbed
		end

		-- spell
		local spell = e.damagedspells and e.damagedspells[spellid]
		if not spell then
			e.damagedspells = e.damagedspells or {}
			e.damagedspells[spellid] = {amount = amount}
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

	local function log_custom_group(set, name, id, playername, spellid, amount, overkill, absorbed)
		local group_name = name and grouped_units[name]
		if not group_name then
			group_name = grouped_units[GetCreatureId(id)]
			if not group_name then return end
			grouped_units[name] = group_name
		end
		if group_name == L["Halion and Inferno"] and get_instance_diff() ~= "25h" then return end -- rs25hm only
		if customGroupsTable and customGroupsTable[id] then return end -- a custom unit with useful damage.

		if group_name == L["Princes overkilling"] then
			log_custom_unit(set, group_name, playername, spellid, overkill, absorbed)
			return
		end
		log_custom_unit(set, group_name, playername, spellid, amount, absorbed)
	end

	local dmg = {}
	local function log_damage(set)
		if not set or (set == Skada.total and not P.totalidc) then return end

		local absorbed = dmg.absorbed or 0
		if (dmg.amount + absorbed) == 0 then return end

		local e = Skada:GetActor(set, dmg.actorname, dmg.actorid, dmg.actorflags)
		if not e then return end

		e.damaged = (e.damaged or 0) + dmg.amount
		set.edamaged = (set.edamaged or 0) + dmg.amount

		if e.totaldamaged then
			e.totaldamaged = e.totaldamaged + dmg.amount + absorbed
		elseif absorbed > 0 then
			e.totaldamaged = e.damaged + absorbed
		end

		if set.etotaldamaged then
			set.etotaldamaged = set.etotaldamaged + dmg.amount + absorbed
		elseif absorbed > 0 then
			set.etotaldamaged = set.edamaged + absorbed
		end

		-- damage spell.
		local spell = e.damagedspells and e.damagedspells[dmg.spellid]
		if not spell then
			e.damagedspells = e.damagedspells or {}
			e.damagedspells[dmg.spellid] = {amount = dmg.amount}
			spell = e.damagedspells[dmg.spellid]
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

		if is_custom_unit(dmg.actorid, dmg.actorname, dmg.amount, overkill) then
			local unit = customUnitsTable[dmg.actorid]
			-- started with less than max?
			if unit.full then
				local amount = unit.full - unit.curval
				if unit.useful then
					e.usefuldamaged = (e.usefuldamaged or 0) + amount
					spell.useful = (spell.useful or 0) + amount
					source.useful = (source.useful or 0) + amount
				end
				if unit.maxval == unit.full then
					log_custom_unit(set, unit.name, dmg.srcName, dmg.spellid, amount, absorbed)
				end
				unit.full = nil
			elseif unit.curval >= unit.maxval then
				local amount = dmg.amount - overkill
				unit.curval = unit.curval - amount

				if unit.curval <= unit.maxval then
					log_custom_unit(set, unit.name, dmg.srcName, dmg.spellid, unit.maxval - unit.curval, absorbed)
					amount = amount - (unit.maxval - unit.curval)
					if grouped_units[unit.oname] and unit.useful then
						log_custom_group(set, unit.oname, unit.guid, dmg.srcName, dmg.spellid, amount, overkill, absorbed)
						customGroupsTable = customGroupsTable or {}
						customGroupsTable[unit.guid] = true
					end
					if grouped_units[unit.name] then
						log_custom_group(set, unit.name, unit.guid, dmg.srcName, dmg.spellid, unit.maxval - unit.curval, overkill, absorbed)
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

				if grouped_units[unit.name] then
					log_custom_group(set, unit.name, unit.guid, dmg.srcName, dmg.spellid, amount, overkill, absorbed)
				end

				if unit.curval <= unit.minval then
					log_custom_unit(set, unit.name, dmg.srcName, dmg.spellid, amount - (unit.minval - unit.curval), absorbed)

					-- remove it
					local guid = unit.guid
					customUnitsTable[guid] = del(customUnitsTable[guid])
					customUnitsTable[guid] = -1
				else
					log_custom_unit(set, unit.name, dmg.srcName, dmg.spellid, amount, absorbed)
				end
			elseif unit.power then
				log_custom_unit(set, unit.name, dmg.srcName, dmg.spellid, dmg.amount - (unit.useful and overkill or 0), absorbed)
			end
		end

		-- custom groups
		log_custom_group(set, dmg.actorname, dmg.actorid, dmg.srcName, dmg.spellid, dmg.amount, overkill, absorbed)
	end

	local function spell_damage(t)
		if t.srcName and t.dstName and t.spellid and not ignored_spells[t.spellid] and (not t.misstype or t.misstype == "ABSORB") then
			dmg.actorid = t.dstGUID
			dmg.actorname = t.dstName
			dmg.actorflags = t.dstFlags

			dmg.spellid = t.spellstring
			dmg.amount = t.amount
			dmg.overkill = t.overkill
			dmg.absorbed = t.absorbed

			_, dmg.srcName = Skada:FixMyPets(t.srcGUID, t.srcName, t.srcFlags)
			Skada:DispatchSets(log_damage)
		end
	end

	local function mode_source_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local damage, overkill, useful = set:GetActorDamageFromSource(win.targetname, win.targetid, label)
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

	local function mode_useful_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local e = set and set:GetActor(label, id)
		local amount, total, useful = e:GetDamageTakenBreakdown(set)
		if not useful or useful == 0 then return end

		tooltip:AddLine(format(L["%s's damage breakdown"], label))
		tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(total), 1, 1, 1)
		tooltip:AddDoubleLine(L["Useful Damage"], format("%s (%s)", Skada:FormatNumber(useful), Skada:FormatPercent(useful, total)), 1, 1, 1)
		local overkill = max(0, total - useful)
		tooltip:AddDoubleLine(L["Overkill"], format("%s (%s)", Skada:FormatNumber(overkill), Skada:FormatPercent(overkill, total)), 1, 1, 1)
	end

	function mode_spell_source:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> sources"], win.targetname, label)
	end

	function mode_spell_source:Update(win, set)
		win.title = uformat(L["%s's <%s> sources"], win.targetname, win.spellname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		if not win.spellid then return end

		local actor = set and set:GetActor(win.targetname, win.targetid)
		if not (actor and actor.GetDamageSpellSources) then return end

		local sources, total = actor:GetDamageSpellSources(set, win.spellid)
		if not sources or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDTPS and actor:GetTime(set)

		for sourcename, source in pairs(sources) do
			if not win.class or win.class == source.class then
				nr = nr + 1

				local d = win:actor(nr, source, source.enemy, sourcename)
				d.value = source.amount
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_source:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's damage sources"], label)
	end

	function mode_source:Update(win, set)
		win.title = uformat(L["%s's damage sources"], win.targetname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		local sources, total, actor = set:GetActorDamageSources(win.targetname, win.targetid)
		if not sources or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDTPS and actor:GetTime(set)

		for sourcename, source in pairs(sources) do
			if not win.class or win.class == source.class then
				nr = nr + 1

				local d = win:actor(nr, source, source.enemy, sourcename)
				d.value = P.absdamage and source.total or source.amount
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_source_spell:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor damage"](label or L["Unknown"], win.targetname or L["Unknown"])
	end

	function mode_source_spell:Update(win, set)
		win.title = L["actor damage"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not win.actorname or not win.targetname then return end

		local actor = set and set:GetActor(win.targetname, win.targetid)
		local sources = actor and actor:GetDamageSources(set)
		local source = sources and sources[win.actorname]
		if not source then return end

		local total = P.absdamage and source.total or source.amount
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDTPS and actor:GetTime(set)
		local spells = actor.damagedspells

		for spellid, spell in pairs(spells) do
			local src = spell.sources and spell.sources[win.actorname]
			if src then
				nr = nr + 1

				local d = win:spell(nr, spellid)
				d.value = P.absdamage and src.total or src.amount
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_spell:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["Damage taken by %s"], label)
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["Damage taken by %s"], win.targetname)

		local actor = set and set:GetActor(win.targetname, win.targetid)
		local total = actor and actor:GetDamageTaken()
		local spells = (total and total > 0) and actor.damagedspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDTPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = P.absdamage and spell.total or spell.amount
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_useful:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["Useful damage on %s"], label)
	end

	function mode_useful:Update(win, set)
		win.title = uformat(L["Useful damage on %s"], win.targetname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		local actor = set and set:GetActor(win.targetname, win.targetid)
		local total = actor and actor.usefuldamaged
		local sources = (total and total > 0) and actor:GetDamageSources(set)

		if not sources then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDTPS and actor:GetTime(set)

		for sourcename, source in pairs(sources) do
			if win:show_actor(source, set) and source.useful and source.useful > 0 then
				nr = nr + 1

				local d = win:actor(nr, source, source.enemy, sourcename)
				d.value = source.useful
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode:Update(win, set)
		win.title = L["Enemy Damage Taken"]

		local total = set and set:GetDamageTaken(win.class, true)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if actor.enemy then
				local dtps, amount = actor:GetDTPS(set, nil, not mode_cols.sDTPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, mode_cols, total, dtps, win.metadata, nil, actor.fake)
				end
			end
		end
	end

	function mode:GetSetSummary(set, win)
		local dtps, amount = set:GetDTPS(win and win.class, true)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(amount or 0),
			mode_cols.DTPS and Skada:FormatNumber(dtps)
		)
		return amount, valuetext
	end

	function mode:OnEnable()
		mode_spell_source.metadata = {showspots = true, filterclass = true}
		mode_useful.metadata = {showspots = true, filterclass = true}
		mode_source.metadata = {
			showspots = true,
			filterclass = true,
			click1 = mode_source_spell,
			post_tooltip = mode_source_tooltip
		}
		mode_spell.metadata = {click1 = mode_spell_source, valueorder = true}
		self.metadata = {
			click1 = mode_source,
			click2 = mode_spell,
			click3 = mode_useful,
			post_tooltip = mode_useful_tooltip,
			columns = {Damage = true, DTPS = false, Percent = true, sDTPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_fire_felflamebolt]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_source.nototal = true
		mode_spell.nototal = true
		mode_useful.nototal = true

		Skada:RegisterForCL(
			spell_damage,
			{src_is_interesting = true, dst_is_not_interesting = true},
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

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, "Enemies")
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mode:CombatLeave()
		instanceDiff = nil
		wipe(dmg)
		clear(customUnitsTable)
		clear(customGroupsTable)
	end

	---------------------------------------------------------------------------

	function enemyPrototype:GetDamageSpellSources(set, spellid, tbl)
		local spell = set and spellid and self.damagedspells and self.damagedspells[spellid]
		if not spell or not spell.sources then return end

		tbl = clear(tbl or C)
		for name, source in pairs(spell.sources) do
			local t = tbl[name]
			if not t then
				t = new()
				t.amount = P.absdamage and source.total or source.amount or 0
				tbl[name] = t
			else
				t.amount = t.amount + (P.absdamage and source.total or source.amount or 0)
			end

			set:_fill_actor_table(t, name)
		end

		return tbl, P.absdamage and spell.total or spell.amount
	end

	function enemyPrototype:GetDamageTakenBreakdown(set)
		local sources = self:GetDamageSources(set)
		if not sources then return end

		local amount, total, useful = 0, 0, 0
		for _, src in pairs(sources) do
			if src.amount then
				amount = amount + src.amount
			end
			if src.total then
				total = total + src.total
			end
			if src.useful then
				useful = useful + src.useful
			end
		end
		return amount, total, useful
	end
end)

---------------------------------------------------------------------------
-- Enemy Damage Done

Skada:RegisterModule("Enemy Damage Done", function(L, P, _, C)
	local mode = Skada:NewModule("Enemy Damage Done")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Target List")
	local mode_spell = mode:NewModule("Spell List")
	local mode_spell_target = mode_spell:NewModule("Target List")
	local ignored_spells = Skada.ignored_spells.damage -- Edit Skada\Core\Tables.lua
	local passive_spells = Skada.ignored_spells.time -- Edit Skada\Core\Tables.lua
	local mode_cols = nil

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

	local function add_actor_time(set, actor, spellid, target)
		if not spellid or passive_spells[spellid] then
			return -- missing spellid or passive spell?
		elseif not Skada.validclass[actor.class] or actor.role == "HEALER" then
			return -- missing/invalid actor class or actor is a healer?
		else
			Skada:AddActiveTime(set, actor, target)
		end
	end

	local dmg = {}
	local function log_damage(set)
		if not set or (set == Skada.total and not P.totalidc) then return end

		local absorbed = dmg.absorbed or 0
		if (dmg.amount + absorbed) == 0 then return end

		local e = Skada:GetActor(set, dmg.actorname, dmg.actorid, dmg.actorflags)
		if not e then
			return
		elseif (set.type == "arena" or set.type == "pvp") and dmg.amount > 0 then
			add_actor_time(set, e, dmg.spell, dmg.dstName)
		end

		e.damage = (e.damage or 0) + dmg.amount
		set.edamage = (set.edamage or 0) + dmg.amount

		if e.totaldamage then
			e.totaldamage = e.totaldamage + dmg.amount + absorbed
		elseif absorbed > 0 then
			e.totaldamage = e.damage + absorbed
		end

		if set.etotaldamage then
			set.etotaldamage = set.etotaldamage + dmg.amount + absorbed
		elseif absorbed > 0 then
			set.etotaldamage = set.edamage + absorbed
		end

		local overkill = dmg.overkill or 0
		if overkill > 0 then
			set.eoverkill = (set.eoverkill or 0) + dmg.overkill
			e.overkill = (e.overkill or 0) + dmg.overkill
		end

		-- damage spell.
		local spell = e.damagespells and e.damagespells[dmg.spellid]
		if not spell then
			e.damagespells = e.damagespells or {}
			e.damagespells[dmg.spellid] = {amount = dmg.amount}
			spell = e.damagespells[dmg.spellid]
		else
			spell.amount = spell.amount + dmg.amount
		end

		if spell.total then
			spell.total = spell.total + dmg.amount + absorbed
		elseif absorbed > 0 then
			spell.total = spell.amount + absorbed
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

	local function spell_damage(t)
		if t.srcName and t.dstName and t.spellid and not ignored_spells[t.spellid] and (not t.misstype or t.misstype == "ABSORB") then
			dmg.actorid = t.srcGUID
			dmg.actorname = t.srcName
			dmg.actorflags = t.srcFlags

			dmg.spell = t.spellid
			dmg.spellid = t.spellstring
			dmg.amount = t.amount
			dmg.overkill = t.overkill
			dmg.absorbed = t.absorbed

			dmg.dstName = Skada:FixPetsName(t.dstGUID, t.dstName, t.dstFlags)
			Skada:DispatchSets(log_damage)
		end
	end

	function mode_target_spell:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor damage"](win.targetname or L["Unknown"], label)
	end

	function mode_target_spell:Update(win, set)
		win.title = L["actor damage"](win.targetname or L["Unknown"], win.actorname or L["Unknown"])
		if not (win.targetname and win.actorname) then return end

		local actor = set and set:GetActor(win.targetname, win.targetid)
		if not (actor and actor.GetDamageTargetSpells) then return end
		local spells, total = actor:GetDamageTargetSpells(win.actorname)

		if not spells or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = spell.amount
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_spell_target:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> targets"], win.targetname, label)
	end

	function mode_spell_target:Update(win, set)
		win.title = uformat(L["%s's <%s> targets"], win.targetname, win.spellname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		if not win.spellid then return end

		local actor = set and set:GetActor(win.targetname, win.targetid)
		if not (actor and actor.GetDamageSpellTargets) then return end

		local targets, total = actor:GetDamageSpellTargets(set, win.spellid)
		if not targets or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			if not win.class or win.class == target.class then
				nr = nr + 1

				local d = win:actor(nr, target, target.enemy, targetname)
				d.value = target.amount
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_target:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], win.targetname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		local targets, total, actor = set:GetActorDamageTargets(win.targetname, win.targetid)
		if not targets or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			if not win.class or win.class == target.class then
				nr = nr + 1

				local d = win:actor(nr, target, target.enemy, targetname)
				d.value = P.absdamage and target.total or target.amount
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_spell:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor damage"](label)
	end

	function mode_spell:Update(win, set)
		win.title = L["actor damage"](win.targetname or L["Unknown"])

		local actor = set and set:GetActor(win.targetname, win.targetid)
		local total = actor and actor:GetDamage()
		local spells = (total and total > 0) and actor.damagespells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = P.absdamage and spell.total or spell.amount
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = L["Enemy Damage Done"]

		local total = set and set:GetEnemyDamage()
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors -- enemies

		for actorname, actor in pairs(actors) do
			if actor.enemy and not actor.fake then
				local dps, amount = actor:GetDPS(set)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, mode_cols, total, dps, win.metadata)
				end
			end
		end
	end

	function mode:GetSetSummary(set, win)
		local dps, amount = set:GetEnemyDPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(amount or 0),
			mode_cols.DPS and Skada:FormatNumber(dps)
		)
		return amount, valuetext
	end

	function mode:OnEnable()
		mode_spell_target.metadata = {showspots = true, filterclass = true}
		mode_target.metadata = {showspots = true, filterclass = true, click1 = mode_target_spell}
		mode_spell.metadata = {click1 = mode_spell_target, valueorder = true}
		self.metadata = {
			click1 = mode_target,
			click2 = mode_spell,
			columns = {Damage = true, DPS = false, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_shadow_shadowbolt]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_target.nototal = true
		mode_spell.nototal = true

		Skada:RegisterForCL(
			spell_damage,
			{dst_is_interesting = true, src_is_not_interesting = true},
			-- damage events
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			-- missed events
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED"
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, "Enemies")
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mode:CombatLeave()
		wipe(dmg)
	end

	---------------------------------------------------------------------------

	function setPrototype:GetEnemyDamage(class)
		return P.absdamage and self:GetTotal(class, nil, "etotaldamage") or self:GetTotal(class, nil, "edamage")
	end

	function setPrototype:GetEnemyDPS(class)
		local total = self:GetEnemyDamage(class)
		if not total or total == 0 then
			return 0, total
		end
		return total / self:GetTime(), total
	end

	function enemyPrototype:GetDamageTargetSpells(name, tbl)
		local spells = name and self.damagespells
		if not spells then return end

		tbl = clear(tbl or C)

		local total = 0
		for spellid, spell in pairs(spells) do
			local amount = spell.targets and spell.targets[name] and (P.absdamage and spell.targets[name].total or spell.targets[name].amount)
			if amount then
				local t = tbl[spellid]
				if not tbl[spellid] then
					t = new()
					t.amount = amount
					tbl[spellid] = t
				else
					t.amount = t.amount + amount
				end

				total = total + amount
			end
		end
		return tbl, total
	end

	function enemyPrototype:GetDamageSpellTargets(set, spellid, tbl)
		local spell = set and spellid and self.damagespells and self.damagespells[spellid]
		if not spell or not spell.targets then return end

		tbl = clear(tbl or C)

		local total = P.absdamage and spell.total or spell.amount or 0
		for name, target in pairs(spell.targets) do
			local amount = P.absdamage and target.total or target.amount
			local t = tbl[name]
			if not t then
				t = new()
				t.amount = amount
				tbl[name] = t
			else
				t.amount = t.amount + amount
			end
			set:_fill_actor_table(t, name)
		end
		return tbl, total
	end
end)

---------------------------------------------------------------------------
-- Enemy Healing Done

Skada:RegisterModule("Enemy Healing Done", function(L, P)
	local mode = Skada:NewModule("Enemy Healing Done")
	local mode_target = mode:NewModule("Target List")
	local mode_spell = mode:NewModule("Spell List")
	local ignored_spells = Skada.ignored_spells.heal -- Edit Skada\Core\Tables.lua
	local passive_spells = Skada.ignored_spells.time -- Edit Skada\Core\Tables.lua
	local mode_cols = nil

	local function format_valuetext(d, columns, total, dps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Healing and Skada:FormatNumber(d.value),
			columns[subview and "sHPS" or "HPS"] and dps and Skada:FormatNumber(dps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function add_actor_time(set, actor, spellid, target)
		if passive_spells[spellid] then
			return -- missing spellid or passive spell?
		elseif not actor.class or not Skada.validclass[actor.class] or actor.role ~= "HEALER" then
			return -- missing/invalid actor class or actor is not a healer?
		else
			Skada:AddActiveTime(set, actor, target)
		end
	end

	local heal = {}
	local function log_heal(set)
		if not set or (set == Skada.total and not P.totalidc) then return end
		if not heal.amount then return end

		local actor = Skada:GetActor(set, heal.actorname, heal.actorid, heal.actorflags)
		if not actor then return end

		-- get rid of overheal
		if (set.type == "arena" or set.type == "pvp") and heal.amount > 0 then
			add_actor_time(set, actor, heal.spell, heal.dstName)
		end

		actor.heal = (actor.heal or 0) + heal.amount
		set.eheal = (set.eheal or 0) + heal.amount

		local overheal = (heal.overheal > 0) and heal.overheal or nil
		if overheal then
			actor.overheal = (actor.overheal or 0) + overheal
			set.eoverheal = (set.eoverheal or 0) + overheal
		end

		local spell = actor.healspells and actor.healspells[heal.spellid]
		if not spell then
			actor.healspells = actor.healspells or {}
			actor.healspells[heal.spellid] = {amount = heal.amount, count = 1}
			spell = actor.healspells[heal.spellid]
		else
			spell.amount = spell.amount + heal.amount
			spell.count = spell.count + 1
		end

		if overheal then
			spell.o_amt = (spell.o_amt or 0) + overheal
		end

		if not heal.dstName then return end

		local target = spell.targets and spell.targets[heal.dstName]
		if not target then
			spell.targets = spell.targets or {}
			spell.targets[heal.dstName] = {amount = heal.amount}
			target = spell.targets[heal.dstName]
		else
			target.amount = target.amount + heal.amount
		end

		if overheal then
			target.o_amt = (target.o_amt or 0) + overheal
		end
	end

	local function spell_heal(t)
		if t.spellid and not ignored_spells[t.spellid] then
			heal.actorid = t.srcGUID
			heal.actorname = t.srcName
			heal.actorflags = t.srcFlags
			heal.dstName = t.dstName

			heal.spell = t.spellid
			heal.spellid = t.spellstring
			heal.overheal = t.overheal or 0
			heal.amount = max(0, t.amount - heal.overheal)

			Skada:DispatchSets(log_heal)
		end
	end

	function mode_target:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healed targets"], label)
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's healed targets"], win.targetname)

		local targets, total, actor = set:GetActorHealTargets(win.targetname, win.targetid)
		if not targets or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, targetname)
			d.value = target.amount
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_spell:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor heal spells"](label)
	end

	function mode_spell:Update(win, set)
		win.title = L["actor heal spells"](win.targetname or L["Unknown"])

		local actor = set and set:GetActor(win.targetname, win.targetid)
		local total = actor and actor.heal
		local spells = (total and total > 0) and actor.healspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, true)
			d.value = spell.amount
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = L["Enemy Healing Done"]
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		local total = set and set:GetHeal(win.class, true)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors -- enemies

		for actorname, actor in pairs(actors) do
			if actor.enemy and not actor.fake then
				local hps, amount = actor:GetHPS(set, nil, not mode_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, mode_cols, total, hps, win.metadata)
				end
			end
		end
	end

	function mode:GetSetSummary(set, win)
		local hps, amount = set:GetHPS(win and win.class, true)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(amount or 0),
			mode_cols.HPS and Skada:FormatNumber(hps)
		)
		return amount, valuetext
	end

	function mode:OnEnable()
		mode_spell.metadata = {valueorder = true}
		self.metadata = {
			showspots = true,
			filterclass = true,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_holy_blessedlife]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		Skada:RegisterForCL(
			spell_heal,
			{src_is_not_interesting = true, dst_is_not_interesting = true},
			"SPELL_HEAL",
			"SPELL_PERIODIC_HEAL"
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, "Enemies")
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mode:CombatLeave()
		wipe(heal)
	end
end)
