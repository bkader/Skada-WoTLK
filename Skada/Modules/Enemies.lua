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
	local mode_cols = nil

	local GetUnitIdFromGUID, GetCreatureId = Skada.GetUnitIdFromGUID, Skada.GetCreatureId
	local UnitExists, UnitGUID = UnitExists, UnitGUID
	local UnitHealthMax, UnitPowerMax = UnitHealthMax, UnitPowerMax
	local del, copy = Private.delTable, Private.copyTable
	local classfmt = Skada.classcolors.format

	local ignored_spells = Skada.ignored_spells.damage -- Edit Skada\Core\Tables.lua
	local grouped_units = Skada.grouped_units -- Edit Skada\Core\Tables.lua
	local user_units = Skada.custom_units -- Edit Skada\Core\Tables.lua
	local ignored_creatures = Skada.ignored_creatures -- Edit Skada\Core\Tables.lua
	local trash_n_boss = grouped_units.BOSS or grouped_units.TRASH -- Edit Skada\Core\Tables.lua

	local totalset = L["Total"]
	local instance_diff, instance_type
	local max_health, max_power
	local custom_units = {}
	local custom_groups = {}
	local instance_units = {}
	local ignored_units = {}
	local ignored_instance_units = {}

	-- table of acceptable/trackable instance difficulties
	-- uncomment those you want to use or add custom ones.
	local allowed_diffs = {
		-- ["5n"] = false, -- 5man Normal
		-- ["5h"] = false, -- 5man Heroic
		-- ["mc"] = false, -- Mythic Dungeons
		-- ["tw"] = false, -- Time Walker
		-- ["wb"] = false, -- World Boss
		["10n"] = true, -- 10man Normal
		["10h"] = true, -- 10man Heroic
		["25n"] = true, -- 25man Normal
		["25h"] = true, -- 25man Heroic
	}

	local function format_valuetext(d, total, dtps, metadata, subview, dont_sort)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(d.value),
			mode_cols[subview and "sDTPS" or "DTPS"] and Skada:FormatNumber(dtps),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if not dont_sort and metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function get_instance_diff()
		if not instance_diff then
			instance_diff = Skada:GetInstanceDiff() or "NaN"
		end
		return instance_diff
	end

	local function get_custom_unit_maxval(guid, unit, name)
		if not unit then return end -- no user-defined custom unit?

		local creatureId = GetCreatureId(guid)
		local diff = get_instance_diff()

		if unit.power ~= nil then
			-- already cached power?
			if max_power and max_power[creatureId] and max_power[creatureId][diff] then
				return max_power[creatureId][diff]
			end

			-- try to grab UnitID
			local uid = GetUnitIdFromGUID(guid)
			if not uid then return end

			local maxval = UnitPowerMax(uid, unit.power)
			if not maxval then return end

			max_power = max_power or {}
			max_power[creatureId] = max_power[creatureId] or {}
			max_power[creatureId][diff] = maxval
			Skada:Debug(format("[%s:%s] \124cffffbb00Max Power\124r: %s (diff: %s)", name, creatureId, maxval, diff))

			return maxval
		end

		-- already cached health?
		if max_health and max_health[creatureId] and max_health[creatureId][diff] then
			return max_health[creatureId][diff]
		end

		-- try to grab UnitID
		local uid = GetUnitIdFromGUID(guid)
		if not uid then return end

		local maxval = UnitHealthMax(uid)
		if not maxval then return end

		max_health = max_health or {}
		max_health[creatureId] = max_health[creatureId] or {}
		max_health[creatureId][diff] = maxval
		Skada:Debug(format("[%s:%s] \124cffffbb00Max Health\124r: %s (diff: %s)", name, creatureId, maxval, diff))

		return maxval
	end

	local function get_custom_unit_name(unit, text, start, stop, oname)
		local str = type(text) == "string" and text or stop and L["%s - %s%% to %s%%"] or L["%s below %s%%"]
		return format(str, oname, start * 100, stop * 100)
	end

	local function create_unit_table(unit, guid, creatureId, name, maxval, curval)
		local start = (unit.start or 1)
		local stop = (unit.stop or 0)

		-- ignore units below minimum required.
		local minval = floor(maxval * stop)
		if curval <= minval then
			ignored_units[guid] = true
			return false
		end

		local t = new()
		t.oname = name or L["Unknown"]
		t.name = unit.name or get_custom_unit_name(unit, unit.text, start, stop, t.oname)
		t.id = creatureId
		t.guid = guid
		t.curval = curval
		t.minval = minval
		t.maxval = floor(maxval * start)
		t.full = maxval
		t.power = (unit.power ~= nil)
		t.useful = unit.useful

		return t
	end

	local function start_custom_unit(unit, creatureId, guid, name, amount, overkill)
		if unit.diff ~= nil and ((type(unit.diff == "table") and not unit.diff[get_instance_diff()]) or (type(unit.diff) ~= "table" and unit.diff ~= get_instance_diff())) then
			ignored_units[guid] = true
			return false
		end

		-- get the unit max value.
		local maxval = get_custom_unit_maxval(guid, unit, name)
		if not maxval or maxval == 0 then
			ignored_units[guid] = true
			return false
		end

		-- calculate current value then create unit table
		local curval = maxval - amount - overkill
		return create_unit_table(unit, guid, creatureId, name, maxval, curval)
	end

	local function get_custom_units(guid, name, amount, overkill)
		-- invalid or ignored?
		if not guid or ignored_units[guid] then return end

		-- already cached?
		local units = custom_units[guid]
		if units then
			return units
		end

		local creatureId = GetCreatureId(guid)
		local my_units = user_units[creatureId]
		if not my_units then
			ignored_units[guid] = true
			return
		end

		if type(my_units[1]) ~= "table" then
			local to_copy = copy(my_units)
			wipe(user_units[creatureId])
			user_units[creatureId][1] = to_copy
			my_units = user_units[creatureId]
		end

		units = new()
		for i = 1, #my_units do
			local unit = start_custom_unit(my_units[i], creatureId, guid, name, amount, overkill, i)
			if unit then
				units[#units + 1] = unit
			end
		end

		custom_units[guid] = units
		return units
	end

	local function log_custom_unit(set, name, playername, spellid, amount, absorbed)
		local e = Skada:GetActor(set, name, name, true)
		if not e then return end

		e.damaged = (e.damaged or 0) + amount
		e.totaldamaged = (e.totaldamaged or 0) + amount
		if absorbed > 0 then
			e.totaldamaged = e.totaldamaged + absorbed
		end

		if not spellid then return end

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

	local function log_custom_group(set, name, id, playername, spellid, amount, overkill, absorbed, isboss)
		if trash_n_boss and set.name == totalset and name and not ignored_instance_units[name] then
			-- see if it was cached already
			local trash_or_boss = instance_units[name]
			if not trash_or_boss then -- process if not cached.
				if grouped_units.BOSS and isboss then
					trash_or_boss = instance_type == "raid" and L["Raid Bosses"] or L["Dungeon Bosses"]
				elseif grouped_units.TRASH and not isboss then
					trash_or_boss = instance_type == "raid" and L["Raid Trash"] or L["Dungeon Trash"]
				end
				instance_units[name] = trash_or_boss -- cache if found.
			end
			if trash_or_boss then -- record if found.
				log_custom_unit(set, trash_or_boss, playername, spellid, amount, absorbed)
			else -- otherwise, ignore it.
				ignored_instance_units[name] = true
			end
		end

		-- we use ignored units table to ignore grouped units
		-- if not needed in order to reduce useless processing.
		if not name or ignored_units[name] then return end

		-- a custom unit with useful damage (i.e: Valkyr overkilling)
		if id and custom_groups[id] then return end

		-- see if it was cached already..
		local group_name = grouped_units[name]
		if not group_name then -- a little bit of processing if not cached.
			group_name = grouped_units[GetCreatureId(id)]
			if not group_name then -- not found?
				ignored_units[name] = true -- ignore it so we only process once.
				return
			end
			grouped_units[name] = group_name -- cache it.
		end

		-- Halion and Inferno are only considered for 25 heroic mode.
		if group_name == L["Halion and Inferno"] and get_instance_diff() ~= "25h" then return end

		-- log the damage as custom fake unit.
		-- PS: we use "overkill" instead of "amount" for "Princes overkilling"
		log_custom_unit(set, group_name, playername, spellid, group_name == L["Princes overkilling"] and overkill or amount, absorbed)
	end

	local dmg = {}
	local function log_damage(set, isboss)
		local amount = dmg.amount
		if not amount then return end

		local absorbed = dmg.absorbed or 0
		if (amount + absorbed) == 0 then return end

		local actorid, actorname = dmg.actorid, dmg.actorname
		local e = Skada:GetActor(set, actorname, actorid, dmg.actorflags)
		if not e then return end

		e.damaged = (e.damaged or 0) + amount
		set.edamaged = (set.edamaged or 0) + amount

		if e.totaldamaged then
			e.totaldamaged = e.totaldamaged + amount + absorbed
		elseif absorbed > 0 then
			e.totaldamaged = e.damaged + absorbed
		end

		if set.etotaldamaged then
			set.etotaldamaged = set.etotaldamaged + amount + absorbed
		elseif absorbed > 0 then
			set.etotaldamaged = set.edamaged + absorbed
		end

		local srcName = dmg.srcName
		local spellid = dmg.spellid
		local overkill = dmg.overkill or 0

		-- saving this to total set may become a memory hog deluxe.
		if set.name == totalset and not P.totalidc then
			log_custom_group(set, actorname, actorid, srcName, spellid, amount, overkill, absorbed, isboss)
			return
		end

		-- damage spell.
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

		if overkill > 0 then
			spell.o_amt = (spell.o_amt or 0) + overkill
		end

		-- damage source.
		if not srcName then return end

		-- the source
		local source = spell.sources and spell.sources[srcName]
		if not source then
			spell.sources = spell.sources or {}
			spell.sources[srcName] = {amount = amount}
			source = spell.sources[srcName]
		else
			source.amount = source.amount + amount
		end

		if source.total then
			source.total = source.total + amount + absorbed
		elseif absorbed > 0 then
			source.total = source.amount + absorbed
		end

		if overkill > 0 then
			source.o_amt = (source.o_amt or 0) + overkill
		end

		-- custom groups
		log_custom_group(set, actorname, actorid, srcName, spellid, amount, overkill, absorbed, isboss)

		-- the rest of the code is only for allowed instance diffs.
		if not allowed_diffs[get_instance_diff()] then return end

		-- until a better and simple way is found to handle custom units
		-- this is temporarily disabled, only recorded to the current set.
		if set.name == totalset then return end

		-- custom units.
		local units = get_custom_units(actorid, actorname, amount, overkill)
		if not units then return end

		for i = 1, #units do
			local unit = units[i]
			if not unit or unit.done then
				-- nothing to do
			elseif unit.full then -- started with less than max?
				amount = unit.full - unit.curval
				if unit.useful then
					e.usefuldamaged = (e.usefuldamaged or 0) + amount
					spell.useful = (spell.useful or 0) + amount
					source.useful = (source.useful or 0) + amount
				end
				if unit.maxval == unit.full then
					log_custom_unit(set, unit.name, srcName, spellid, amount, absorbed)
				end
				unit.full = nil
			elseif unit.curval >= unit.maxval then -- still above max value?
				amount = amount - overkill
				unit.curval = unit.curval - amount

				if unit.curval <= unit.maxval then
					log_custom_unit(set, unit.name, srcName, spellid, unit.maxval - unit.curval, absorbed)
					amount = amount - (unit.maxval - unit.curval)
					if grouped_units[unit.oname] and unit.useful then
						log_custom_group(set, unit.oname, unit.guid, srcName, spellid, amount, overkill, absorbed)
						custom_groups[unit.guid] = true
					end
					if grouped_units[unit.name] then
						log_custom_group(set, unit.name, unit.guid, srcName, spellid, unit.maxval - unit.curval, overkill, absorbed)
					end
				end
				if unit.useful then
					e.usefuldamaged = (e.usefuldamaged or 0) + amount
					spell.useful = (spell.useful or 0) + amount
					source.useful = (source.useful or 0) + amount
				end
			elseif unit.curval >= unit.minval then -- astill above min value?
				amount = amount - overkill
				unit.curval = unit.curval - amount

				if grouped_units[unit.name] then
					log_custom_group(set, unit.name, unit.guid, srcName, spellid, amount, overkill, absorbed)
				end

				if unit.curval <= unit.minval then
					local delta = unit.minval - unit.curval
					log_custom_unit(set, unit.name, srcName, spellid, amount - delta, absorbed)
					Skada:Debug(format("[%s] \124cffffbb00Stopped\124r", unit.name))
					unit.done = true
				else
					log_custom_unit(set, unit.name, srcName, spellid, amount, absorbed)
				end
			elseif unit.power then -- tracking power instead?
				log_custom_unit(set, unit.name, srcName, spellid, amount - (unit.useful and overkill or 0), absorbed)
			end
		end
	end

	local function spell_damage(t)
		if
			t.srcName and t.dstName and
			not ignored_creatures[GetCreatureId(t.dstGUID)] and
			t.spellid and not ignored_spells[t.spellid] and
			(not t.misstype or t.misstype == "ABSORB")
		then
			dmg.actorid = t.dstGUID
			dmg.actorname = t.dstName
			dmg.actorflags = t.dstFlags

			dmg.spellid = t.spellstring
			dmg.amount = t.amount
			dmg.overkill = t.overkill
			dmg.absorbed = t.absorbed

			_, dmg.srcName = Skada:FixMyPets(t.srcGUID, t.srcName, t.srcFlags)
			Skada:DispatchSets(log_damage, t:DestIsBoss())
		end
	end

	local function mode_source_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local damage, overkill, useful = set:GetActorDamageFromSource(win.targetname, win.targetid, label)
		if damage == 0 then return end

		tooltip:AddLine(format(L["%s's details"], label))
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

		tooltip:AddLine(format(L["%s's details"], label))
		tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(total), 1, 1, 1)
		tooltip:AddDoubleLine(L["Useful Damage"], format("%s (%s)", Skada:FormatNumber(useful), Skada:FormatPercent(useful, total)), 1, 1, 1)
		local overkill = max(0, total - useful)
		tooltip:AddDoubleLine(L["Overkill"], format("%s (%s)", Skada:FormatNumber(overkill), Skada:FormatPercent(overkill, total)), 1, 1, 1)
	end

	function mode_spell_source:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> sources"], classfmt(win.targetclass, win.targetname), label)
	end

	function mode_spell_source:Update(win, set)
		win.title = uformat(L["%s's <%s> sources"], classfmt(win.targetclass, win.targetname), win.spellname)
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
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_source:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = format(L["%s's sources"], classfmt(class, label))
	end

	function mode_source:Update(win, set)
		win.title = uformat(L["%s's sources"], classfmt(win.targetclass, win.targetname))
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
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_source_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's spells on %s"], classfmt(class, label), classfmt(win.targetclass, win.targetname))
	end

	function mode_source_spell:Update(win, set)
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(win.targetclass, win.targetname))
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
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = format(L["Spells on %s"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["Spells on %s"], classfmt(win.targetclass, win.targetname))

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
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_useful:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = format(L["Useful damage on %s"], classfmt(class, label))
	end

	function mode_useful:Update(win, set)
		win.title = uformat(L["Useful damage on %s"], classfmt(win.targetclass, win.targetname))
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
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
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
				if amount and amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, total, dtps, win.metadata, nil, actor.fake)
				end
			end
		end
	end

	function mode_source:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.targetname, win.targetid)
		if not actor then return end

		local dtps, amount = actor:GetDTPS(set, not mode_cols.sDTPS)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(amount),
			mode_cols.sDTPS and Skada:FormatNumber(dtps)
		)
		return amount, valuetext
	end
	mode_spell.GetSetSummary = mode_source.GetSetSummary

	function mode:GetSetSummary(set, win)
		local dtps, amount = set:GetDTPS(win and win.class, true)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(amount),
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
			icon = [[Interface\ICONS\spell_fire_felflamebolt]]
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
		Skada.RegisterMessage(self, "ZONE_TYPE_CHANGED", "CheckZone")
		Skada:AddMode(self, "Enemies")
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mode:CombatLeave()
		instance_diff = nil
		wipe(dmg)
		clear(custom_units)
		clear(custom_groups)
		clear(instance_units)
		clear(ignored_units)
		clear(ignored_instance_units)
	end

	function mode:CheckZone(_, insType)
		instance_type = insType
		trash_n_boss = (insType == "raid" or insType == "party") and (grouped_units.BOSS or grouped_units.TRASH)
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
			elseif src.amount then
				total = total + src.amount
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
	local mode_cols = nil

	local GetCreatureId = Skada.GetCreatureId
	local classfmt = Skada.classcolors.format
	local ignored_spells = Skada.ignored_spells.damage -- Edit Skada\Core\Tables.lua
	local passive_spells = Skada.ignored_spells.time -- Edit Skada\Core\Tables.lua
	local ignored_creatures = Skada.ignored_creatures -- Edit Skada\Core\Tables.lua

	local function format_valuetext(d, total, dps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(d.value),
			mode_cols[subview and "sDPS" or "DPS"] and dps and Skada:FormatNumber(dps),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
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
		if not dmg.amount then return end

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

		-- saving this to total set may become a memory hog deluxe.
		if set.name == L["Total"] and not P.totalidc then return end

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
		if
			t.srcName and t.dstName and
			not ignored_creatures[GetCreatureId(t.srcGUID)] and
			t.spellid and not ignored_spells[t.spellid] and
			(not t.misstype or t.misstype == "ABSORB")
		then
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

	function mode_target_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's spells on %s"], classfmt(win.targetclass, win.targetname), classfmt(class, label))
	end

	function mode_target_spell:Update(win, set)
		win.title = uformat(L["%s's spells on %s"], classfmt(win.targetclass, win.targetname), classfmt(win.actorclass, win.actorname))
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
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_spell_target:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> targets"], classfmt(win.targetclass, win.targetname), label)
	end

	function mode_spell_target:Update(win, set)
		win.title = uformat(L["%s's <%s> targets"], classfmt(win.targetclass, win.targetname), win.spellname)
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
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = format(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.targetclass, win.targetname))
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
				format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["%s's spells"], classfmt(win.targetclass, win.targetname))

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
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
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
				local dps, amount = actor:GetDPS(set, false, false, not mode_cols.DPS)
				if amount and amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, total, dps, win.metadata)
				end
			end
		end
	end

	function mode_target:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.targetname, win.targetid)
		if not actor then return end

		local dps, amount = actor:GetDPS(set, false, false, not mode_cols.sDPS)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(amount),
			mode_cols.sDPS and Skada:FormatNumber(dps)
		)
		return amount, valuetext
	end
	mode_spell.GetSetSummary = mode_target.GetSetSummary

	function mode:GetSetSummary(set, win)
		local dps, amount = set:GetEnemyDPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(amount),
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
			icon = [[Interface\ICONS\spell_shadow_shadowbolt]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_target.nototal = true
		mode_spell.nototal = true

		Skada:RegisterForCL(
			spell_damage,
			{src_is_not_interesting = true, dst_is_interesting = true},
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

	function setPrototype:GetEnemyDPS(class, no_calc)
		local total = self:GetEnemyDamage(class)
		if not total or total == 0 or no_calc then
			return 0, total or 0
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
	local mode_cols = nil

	local classfmt = Skada.classcolors.format
	local ignored_spells = Skada.ignored_spells.heal -- Edit Skada\Core\Tables.lua
	local passive_spells = Skada.ignored_spells.time -- Edit Skada\Core\Tables.lua

	local function format_valuetext(d, total, dps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(d.value),
			mode_cols[subview and "sHPS" or "HPS"] and dps and Skada:FormatNumber(dps),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
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

		-- saving this to total set may become a memory hog deluxe.
		if set.name == L["Total"] and not P.totalidc then return end

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

	function mode_target:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = format(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.targetclass, win.targetname))

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
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["%s's spells"], classfmt(win.targetclass, win.targetname))

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
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", win.title, L[win.class]) or L["Enemy Healing Done"]

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
				if amount and amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, total, hps, win.metadata)
				end
			end
		end
	end

	function mode_target:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.targetname, win.targetid)
		if not actor then return end

		local hps, amount = actor:GetHPS(set, false, not mode_cols.sHPS)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(amount),
			mode_cols.sHPS and Skada:FormatNumber(hps)
		)
		return amount, valuetext
	end
	mode_spell.GetSetSummary = mode_target.GetSetSummary

	function mode:GetSetSummary(set, win)
		local hps, amount = set:GetHPS(win and win.class, true)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(amount),
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
			icon = [[Interface\ICONS\spell_holy_blessedlife]]
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
