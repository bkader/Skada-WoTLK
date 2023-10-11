local _, Skada = ...
local Private = Skada.Private

-- cache frequently used globals
local pairs, format, uformat = pairs, string.format, Private.uformat
local new, del, clear = Private.newTable, Private.delTable, Private.clearTable

local function format_valuetext(d, columns, total, dtps, metadata, subview)
	d.valuetext = Skada:FormatValueCols(
		columns.Damage and Skada:FormatNumber(d.value),
		columns[subview and "sDTPS" or "DTPS"] and dtps and Skada:FormatNumber(dtps),
		columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
	)

	if metadata and d.value > metadata.maxvalue then
		metadata.maxvalue = d.value
	end
end

---------------------------------------------------------------------------
-- Damage Taken Module

Skada:RegisterModule("Damage Taken", function(L, P)
	local mode = Skada:NewModule("Damage Taken")
	local mode_spell = mode:NewModule("Spell List")
	local mode_spell_details = mode_spell:NewModule("Spell Details")
	local mode_spell_breakdown = mode_spell:NewModule("More Details")
	local mode_source = mode:NewModule("Source List")
	local mode_source_spell = mode_source:NewModule("Spell List")

	local min, wipe = math.min, wipe
	local PercentToRGB = Private.PercentToRGB
	local GetCreatureId = Skada.GetCreatureId
	local classfmt = Skada.classcolors.format
	local tooltip_school = Skada.tooltip_school
	local ignored_spells = Skada.ignored_spells.damage -- Edit Skada\Core\Tables.lua
	local ignored_creatures = Skada.ignored_creatures -- Edit Skada\Core\Tables.lua
	local missTypes = Skada.missTypes
	local mode_cols = nil

	local dmg = {}
	local function log_damage(set)
		local actor = Skada:GetActor(set, dmg.actorname, dmg.actorid, dmg.actorflags)
		if not actor then return end

		actor.damaged = (actor.damaged or 0) + dmg.amount
		set.damaged = (set.damaged or 0) + dmg.amount

		-- add absorbed damage to total damage
		local absorbed = dmg.absorbed or 0

		if actor.totaldamaged then
			actor.totaldamaged = actor.totaldamaged + dmg.amount + absorbed
		elseif absorbed > 0 then
			actor.totaldamaged = actor.damaged + absorbed
		end

		if set.totaldamaged then
			set.totaldamaged = set.totaldamaged + dmg.amount + absorbed
		elseif absorbed > 0 then
			set.totaldamaged = set.damaged + absorbed
		end

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		local spell = actor.damagedspells and actor.damagedspells[dmg.spellid]
		if not spell then
			actor.damagedspells = actor.damagedspells or {}
			actor.damagedspells[dmg.spellid] = {amount = 0}
			spell = actor.damagedspells[dmg.spellid]
		end

		spell.count = (spell.count or 0) + 1
		spell.amount = spell.amount + dmg.amount

		if spell.total then
			spell.total = spell.total + dmg.amount + absorbed
		elseif absorbed > 0 then
			spell.total = spell.amount + absorbed
		end

		if dmg.critical then
			spell.c_num = (spell.c_num or 0) + 1
			spell.c_amt = (spell.c_amt or 0) + dmg.amount

			if not spell.c_max or dmg.amount > spell.c_max then
				spell.c_max = dmg.amount
			end

			if not spell.c_min or dmg.amount < spell.c_min then
				spell.c_min = dmg.amount
			end
		elseif dmg.misstype ~= nil and missTypes[dmg.misstype] then
			spell[missTypes[dmg.misstype]] = (spell[missTypes[dmg.misstype]] or 0) + 1
		elseif dmg.glancing then
			spell.g_num = (spell.g_num or 0) + 1
			spell.g_amt = (spell.g_amt or 0) + dmg.amount
			if not spell.g_max or dmg.amount > spell.g_max then
				spell.g_max = dmg.amount
			end
			if not spell.g_min or dmg.amount < spell.g_min then
				spell.g_min = dmg.amount
			end
		elseif dmg.crushing then
			spell.crushing = (spell.crushing or 0) + 1
		elseif not dmg.misstype then
			spell.n_num = (spell.n_num or 0) + 1
			spell.n_amt = (spell.n_amt or 0) + dmg.amount
			if not spell.n_max or dmg.amount > spell.n_max then
				spell.n_max = dmg.amount
			end
			if not spell.n_min or dmg.amount < spell.n_min then
				spell.n_min = dmg.amount
			end
		end

		if dmg.blocked and dmg.blocked > 0 then
			spell.b_amt = (spell.b_amt or 0) + dmg.blocked
		end

		if dmg.resisted and dmg.resisted > 0 then
			spell.r_amt = (spell.r_amt or 0) + dmg.resisted
		end

		local overkill = (dmg.overkill and dmg.overkill > 0) and dmg.overkill or nil
		if overkill then
			spell.o_amt = (spell.o_amt or 0) + dmg.overkill
		end

		-- record the source
		if not dmg.srcName then return end
		local source = spell.sources and spell.sources[dmg.srcName]
		if not source then
			spell.sources = spell.sources or {}
			spell.sources[dmg.srcName] = {amount = 0}
			source = spell.sources[dmg.srcName]
		end
		source.amount = source.amount + dmg.amount

		if source.total then
			source.total = source.total + dmg.amount + absorbed
		elseif absorbed > 0 then
			source.total = source.amount + absorbed
		end

		if overkill then
			source.o_amt = (source.o_amt or 0) + overkill
		end
	end

	local function spell_damage(t)
		if
			t.srcGUID ~= t.dstGUID and
			not ignored_creatures[GetCreatureId(t.srcGUID)] and
			t.spellid and not ignored_spells[t.spellid]
		then
			dmg.actorid = t.dstGUID
			dmg.actorname = t.dstName
			dmg.actorflags = t.dstFlags
			dmg.spellid = t.spellstring

			dmg.amount = t.amount
			dmg.overkill = t.overkill
			dmg.resisted = t.resisted
			dmg.blocked = t.blocked
			dmg.absorbed = t.absorbed
			dmg.critical = t.critical
			dmg.glancing = t.glancing
			dmg.crushing = t.crushing
			dmg.misstype = t.misstype

			dmg.srcName = Skada:FixPetsName(t.srcGUID, t.srcName, t.srcFlags)
			Skada:DispatchSets(log_damage)
		end
	end

	local function damage_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(set, true)
		local dtps, damage = actor:GetDTPS(set)

		local activepercent = activetime / totaltime * 100
		tooltip:AddDoubleLine(format(L["%s's activity"], classfmt(actor.class, label)), Skada:FormatPercent(activepercent), nil, nil, nil, PercentToRGB(activepercent))
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Damage Taken"], Skada:FormatNumber(damage), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(format("%s/%s", Skada:FormatNumber(damage), suffix), Skada:FormatNumber(dtps), 1, 1, 1)
	end

	local function mode_spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagedspells and actor.damagedspells[id]
		if not spell then return end

		tooltip:AddLine(uformat("%s - %s", classfmt(win.actorclass, win.actorname), label))
		tooltip_school(tooltip, id)

		if spell.n_min then
			local spellmin = spell.n_min
			if spell.c_min and spell.c_min < spellmin then
				spellmin = spell.c_min
			end
			tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
		end

		if spell.n_max then
			local spellmax = spell.n_max
			if spell.c_max and spell.c_max > spellmax then
				spellmax = spell.c_max
			end
			tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spellmax), 1, 1, 1)
		end

		if spell.count then
			local amount = P.absdamage and spell.total or spell.amount
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(amount / spell.count), 1, 1, 1)
		end
	end

	local function mode_spell_details_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] or label == L["Glancing"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetActor(win.actorname, win.actorid)
			local spell = actor and actor.damagedspells and actor.damagedspells[win.spellid]
			if not spell then return end

			tooltip:AddLine(uformat("%s - %s", win.actorname, win.spellname))
			tooltip_school(tooltip, win.spellid)

			if label == L["Critical Hits"] and spell.c_amt then
				if spell.c_min then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.c_min), 1, 1, 1)
				end
				if spell.c_max then
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.c_max), 1, 1, 1)
				end
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.c_amt / spell.c_num), 1, 1, 1)
			elseif label == L["Normal Hits"] and spell.n_amt then
				if spell.n_min then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.n_min), 1, 1, 1)
				end
				if spell.n_max then
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.n_max), 1, 1, 1)
				end
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.n_amt / spell.n_num), 1, 1, 1)
			elseif label == L["Glancing"] and spell.g_amt then
				if spell.g_min then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.g_min), 1, 1, 1)
				end
				if spell.g_max then
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.g_max), 1, 1, 1)
				end
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.g_amt / spell.g_num), 1, 1, 1)
			end
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["%s's spells"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
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
			d.value = min(total, P.absdamage and spell.total or spell.amount)
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_source:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's sources"], classfmt(class, label))
	end

	function mode_source:Update(win, set)
		win.title = uformat(L["%s's sources"], classfmt(win.actorclass, win.actorname))

		local sources, total, actor = set:GetActorDamageSources(win.actorname, win.actorid)
		if not sources or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDTPS and actor:GetTime(set)

		for sourcename, source in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, source, source.enemy, sourcename)
			d.value = P.absdamage and source.total or source.amount
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	local function add_detail_bar(win, nr, title, value, total, percent, fmt)
		nr = nr + 1

		local d = win:nr(nr)
		d.id = title
		d.label = title
		d.value = value
		format_valuetext(d, mode.metadata.columns, total, nil, win.metadata, true)

		if win.metadata and d.value > win.metadata.maxvalue then
			win.metadata.maxvalue = d.value
		end

		return nr
	end

	function mode_spell_details:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat("%s: %s", classfmt(win.actorclass, win.actorname), format(L["%s's details"], label))
	end

	function mode_spell_details:Tooltip(win, set, id, label, tooltip)
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagedspells and actor.damagedspells[id]
		if spell and spell.count then
			tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
			return spell, spell.count
		end
	end

	function mode_spell_details:Update(win, set, spell, count)
		win.title = uformat("%s: %s", classfmt(win.actorclass, win.actorname), uformat(L["%s's details"], win.spellname))
		if not win.spellid then return end

		if not spell then
			local actor = set and set:GetActor(win.actorname, win.actorid)
			spell = actor and actor.damagedspells and actor.damagedspells[win.spellid]
			count = spell and spell.count
		end

		if not spell or not count or count == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		if spell.n_num and spell.n_num > 0 then
			nr = add_detail_bar(win, nr, L["Normal Hits"], spell.n_num, count, true)
		end

		if spell.c_num and spell.c_num > 0 then
			nr = add_detail_bar(win, nr, L["Critical Hits"], spell.c_num, count, true)
		end

		if spell.g_num and spell.g_num > 0 then
			nr = add_detail_bar(win, nr, L["Glancing"], spell.g_num, count, true)
		end

		if spell.crushing and spell.crushing > 0 then
			nr = add_detail_bar(win, nr, L["Crushing"], spell.crushing, count, true)
		end

		for k, v in pairs(missTypes) do
			if spell[v] or spell[k] then
				nr = add_detail_bar(win, nr, L[k], spell[v] or spell[k], count, true)
			end
		end
	end

	function mode_spell_breakdown:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat("%s: %s", classfmt(win.actorclass, win.actorname), label)
	end

	function mode_spell_breakdown:Tooltip(win, set, id, label, tooltip)
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagedspells and actor.damagedspells[id]
		if spell then
			local total = spell.amount

			-- absorbed damage
			local absorbed = spell.total and (spell.total - total)
			if absorbed then
				total = spell.total
			end

			-- blocked damge
			local blocked = spell.b_amt
			if blocked then
				total = total + blocked
			end

			-- resisted damage
			local resisted = spell.r_amt
			if resisted then
				total = total + resisted
			end

			tooltip:AddDoubleLine(spell.amount == total and L["Damage"] or L["Total"], Skada:FormatNumber(total), 1, 1, 1)
			return spell, total, resisted, blocked, absorbed
		end
	end

	function mode_spell_breakdown:Update(win, set, spell, total, resisted, blocked, absorbed)
		win.title = uformat("%s: %s", classfmt(win.actorclass, win.actorname), win.spellname)
		if not win.spellid then return end

		if not spell then
			local actor = set and set:GetActor(win.actorname, win.actorid)
			spell = actor and actor.damagedspells and actor.damagedspells[win.spellid]
			if not spell then return end

			total = spell.amount

			absorbed = spell.total and (spell.total - spell.amount)
			if absorbed then
				total = spell.total
			end

			blocked = spell.b_amt or spell.blocked
			if blocked then
				total = total + blocked
			end

			resisted = spell.r_amt or spell.resisted
			if resisted then
				total = total + resisted
			end

			if win.metadata then
				win.metadata.maxvalue = total
			end
		end

		local nr = 0

		if win.metadata then
			win.metadata.maxvalue = 0
			nr = add_detail_bar(win, nr, L["Damage"], spell.amount, total, true, true)
		elseif spell.amount ~= total then
			nr = add_detail_bar(win, nr, L["Damage"], spell.amount, total, true, true)
		end

		if spell.o_amt and spell.o_amt > 0 then
			nr = add_detail_bar(win, nr, L["Overkill"], spell.o_amt, total, true, true)
		end

		if resisted and resisted > 0 then
			nr = add_detail_bar(win, nr, L["RESIST"], resisted, total, true, true)
		end

		if blocked and blocked > 0 then
			nr = add_detail_bar(win, nr, L["BLOCK"], blocked, total, true, true)
		end

		if absorbed and absorbed > 0 then
			nr = add_detail_bar(win, nr, L["ABSORB"], absorbed, total, true, true)
		end

		if spell.g_amt and spell.g_amt > 0 then
			nr = add_detail_bar(win, nr, L["Glancing"], spell.g_amt, total, true, true)
		end
	end

	function mode_source_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = uformat(L["%s's spells on %s"], classfmt(class, label), classfmt(win.actorclass, win.actorname))
	end

	function mode_source_spell:Update(win, set)
		win.title = uformat(L["%s's spells on %s"], classfmt(win.targetclass, win.targetname), classfmt(win.actorclass, win.actorname))
		if not set or not win.targetname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local sources = actor and actor:GetDamageSources(set)
		if not sources or not sources[win.targetname] then return end

		local total = P.absdamage and sources[win.targetname].total or sources[win.targetname].amount
		local spells = (total and total > 0) and actor.damagedspells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDTPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			local source = spell.sources and spell.sources[win.targetname]
			local amount = source and (P.absdamage and source.total or source.amount)
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellid)
				d.value = amount
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Damage Taken"], L[win.class]) or L["Damage Taken"]

		local total = set and set:GetDamageTaken(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.damaged then
				local dtps, amount = actor:GetDTPS(set, not mode_cols.DTPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, mode_cols, total, dtps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode_spell:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local dtps, amount = actor:GetDTPS(set, not mode_cols.sDTPS)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(amount),
			mode_cols.sDTPS and Skada:FormatNumber(dtps)
		)
		return amount, valuetext
	end
	mode_source.GetSetSummary = mode_spell.GetSetSummary

	function mode:GetSetSummary(set, win)
		local dtps, amount = set:GetDTPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(amount),
			mode_cols.DTPS and Skada:FormatNumber(dtps)
		)
		return amount, valuetext
	end

	function mode:AddToTooltip(set, tooltip)
		if not set then return end
		local dtps, amount = set:GetDTPS()
		if not amount then return end
		tooltip:AddDoubleLine(L["Damage Taken"], Skada:FormatNumber(amount), 1, 1, 1)
		tooltip:AddDoubleLine(L["DTPS"], Skada:FormatNumber(dtps), 1, 1, 1)
	end

	function mode:OnEnable()
		mode_spell_details.metadata = {tooltip = mode_spell_details_tooltip}
		mode_spell.metadata = {click1 = mode_spell_details, click2 = mode_spell_breakdown, tooltip = mode_spell_tooltip}
		mode_source.metadata = {click1 = mode_source_spell}
		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_source.nototal = true

		local flags_dst = {dst_is_interesting_nopets = true}

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

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, "Damage Taken")
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mode:CombatLeave()
		wipe(dmg)
	end

	function mode:SetComplete(set)
		-- clean set from garbage before it is saved.
		local total = set.totaldamaged or set.damaged
		if not total or total == 0 then return end

		for _, actor in pairs(set.actors) do
			local amount = actor.totaldamaged or actor.damaged
			if (not amount and actor.damagedspells) or amount == 0 then
				actor.damaged, actor.totaldamaged = nil, nil
				actor.damagedspells = del(actor.damagedspells, true)
			end
		end
	end

	function mode:OnInitialize()
		self.metadata = {
			showspots = true,
			filterclass = true,
			tooltip = damage_tooltip,
			click1 = mode_spell,
			click2 = mode_source,
			columns = {Damage = true, DTPS = false, Percent = true, sDTPS = false, sPercent = true},
			icon = [[Interface\ICONS\ability_mage_frostfirebolt]]
		}
	end
end)

---------------------------------------------------------------------------
-- DTPS Module

Skada:RegisterModule("DTPS", function(L, P)
	local mode = Skada:NewModule("DTPS")
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function dtps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(set, true)
		local dtps, damage = actor:GetDTPS(set, nil, false)

		tooltip:AddLine(uformat("%s - %s", classfmt(actor.class, label), L["DTPS"]))
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Damage Taken"], Skada:FormatNumber(damage), 1, 1, 1)
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["DTPS"], L[win.class]) or L["DTPS"]

		local total = set and set:GetDTPS(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.damaged then
				local dtps = actor:GetDTPS(set)
				if dtps > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = dtps
					format_valuetext(d, mode_cols, total, dtps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode:GetSetSummary(set, win)
		local dtps = set:GetDTPS(win and win.class)
		return dtps, Skada:FormatNumber(dtps)
	end

	function mode:OnEnable()
		self.metadata = {
			showspots = true,
			filterclass = true,
			tooltip = dtps_tooltip,
			columns = {DTPS = true, Percent = true},
			icon = [[Interface\ICONS\inv_weapon_shortblade_06]]
		}

		mode_cols = self.metadata.columns

		local parent = Skada:GetModule("Damage Taken", true)
		if parent and parent.metadata then
			self.metadata.click1 = parent.metadata.click1
			self.metadata.click2 = parent.metadata.click2
		end

		Skada:AddMode(self, "Damage Taken")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Damage Taken")

---------------------------------------------------------------------------
-- Damage Taken By Spell Module

Skada:RegisterModule("Damage Taken By Spell", function(L, P)
	local mode = Skada:NewModule("Damage Taken By Spell")
	local mode_target = mode:NewModule("Target List")
	local mode_source = mode:NewModule("Source List")
	local C, classfmt = Skada.cacheTable2, Skada.classcolors.format
	local mode_cols = nil

	local function actor_tooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local spell = actor.damagedspells and actor.damagedspells[win.spellid]
		if not spell or not spell.count then return end

		tooltip:AddLine(uformat("%s - %s", classfmt(actor.class, label), win.spellname))

		tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
		local diff = spell.count -- used later

		if spell.n_num then
			tooltip:AddDoubleLine(L["Normal Hits"], Skada:FormatPercent(spell.n_num, spell.count), 1, 1, 1)
			diff = diff - spell.n_num
		end

		if spell.c_num then
			tooltip:AddDoubleLine(L["Critical Hits"], Skada:FormatPercent(spell.c_num, spell.count), 1, 1, 1)
			diff = diff - spell.c_num
		end

		if spell.g_num then
			tooltip:AddDoubleLine(L["Glancing"], Skada:FormatPercent(spell.g_num, spell.count), 1, 1, 1)
			diff = diff - spell.g_num
		end

		if diff > 0 then
			tooltip:AddDoubleLine(L["Other"], Skada:FormatPercent(diff, spell.count), nil, nil, nil, 1, 1, 1)
		end
	end

	function mode_source:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's sources"], label)
	end

	function mode_source:Update(win, set)
		win.title = uformat(L["%s's sources"], win.spellname)
		if not win.spellid then return end

		local total = 0
		local sources = clear(C)
		local actors = set.actors
		for _, actor in pairs(actors) do
			local spell = not actor.enemy and actor.damagedspells and actor.damagedspells[win.spellid]

			if spell and spell.sources then
				for sourcename, source in pairs(spell.sources) do
					local amount = P.absdamage and source.total or source.amount or 0
					if amount > 0 then
						local src = sources[sourcename]
						if not src then
							src = new()
							src.amount = amount
							sources[sourcename] = src
						else
							src.amount = src.amount + amount
						end

						total = total + amount

						set:_fill_actor_table(src, sourcename, true)
					end
				end
			end
		end

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for sourcename, source in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, source, source.enemy, sourcename)
			d.value = source.amount
			format_valuetext(d, mode_cols, total, source.time and (d.value / source.time), win.metadata, true)
		end
	end

	function mode_target:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], win.spellname)
		win.title = win.class and format("%s (%s)", win.title, L[win.class]) or win.title
		if not win.spellid then return end

		local total = 0
		local targets = clear(C)
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			local spell = win:show_actor(actor, set, true) and actor.damagedspells and actor.damagedspells[win.spellid]
			if spell then
				local amount = P.absdamage and spell.total or spell.amount or 0
				if amount > 0 then
					targets[actorname] = new()
					targets[actorname].id = actor.id
					targets[actorname].class = actor.class
					targets[actorname].role = actor.role
					targets[actorname].spec = actor.spec
					targets[actorname].enemy = actor.enemy
					targets[actorname].amount = amount
					targets[actorname].time = mode_cols.sDTPS and actor:GetTime(set)

					total = total + amount
				end
			end
		end

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for actorname, actor in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, actor, actor.enemy, actorname)
			d.value = actor.amount
			format_valuetext(d, mode_cols, total, actor.time and (d.value / actor.time), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = L["Damage Taken By Spell"]

		local total = set and set:GetDamageTaken()
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local spells = clear(C)
		local actors = set.actors
		for _, actor in pairs(actors) do
			local _spells = not actor.enemy and actor.damagedspells
			if _spells then
				for spellid, spell in pairs(_spells) do
					local amount = P.absdamage and spell.total or spell.amount or 0
					if amount > 0 then
						local sp = spells[spellid]
						if not sp then
							sp = new()
							sp.amount = amount
							spells[spellid] = sp
						else
							sp.amount = sp.amount + amount
						end
					end
				end
			end
		end

		local nr = 0
		local settime = mode_cols.DTPS and set:GetTime()

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = spell.amount
			format_valuetext(d, mode_cols, total, settime and (d.value / settime), win.metadata)
		end
	end

	function mode:OnEnable()
		mode_target.metadata = {showspots = true, filterclass = true, tooltip = actor_tooltip}
		self.metadata = {
			showspots = true,
			click1 = mode_target,
			click2 = mode_source,
			columns = {Damage = true, DTPS = false, Percent = true, sDTPS = false, sPercent = true},
			icon = [[Interface\ICONS\spell_arcane_starfire]]
		}

		mode_cols = self.metadata.columns

		Skada:AddMode(self, "Damage Taken")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Damage Taken")

---------------------------------------------------------------------------
-- Avoidance & Mitigation Module

Skada:RegisterModule("Avoidance & Mitigation", function(L)
	local mode = Skada:NewModule("Avoidance & Mitigation")
	local mode_breakdown = mode:NewModule("More Details")
	local classfmt = Skada.classcolors.format
	local missTypes = Skada.missTypes
	local C = Skada.cacheTable2
	local mode_cols = nil

	local function fmt_valuetext(d, columns, total, count, metadata)
		d.valuetext = Skada:FormatValueCols(
			columns.Percent and Skada:FormatPercent(d.value),
			columns.Count and count and Skada:FormatNumber(count),
			columns.Total and Skada:FormatNumber(total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	function mode_breakdown:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's details"], classfmt(class, label))
	end

	function mode_breakdown:Update(win, set)
		win.title = uformat(L["%s's details"], classfmt(win.actorclass, win.actorname))

		local actor = win.actorid and C[win.actorid]
		if not actor then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for event, count in pairs(actor.data) do
			nr = nr + 1

			local d = win:nr(nr)
			d.id = event
			d.label = L[event]
			d.value = 100 * count / actor.total
			fmt_valuetext(d, mode_cols, actor.total, count, win.metadata)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Avoidance & Mitigation"], L[win.class]) or L["Avoidance & Mitigation"]

		local total = set and set.totaldamaged
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		clear(C) -- used later

		local nr = 0

		local actors = set.actors
		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.damagedspells then
				local tmp = new()
				tmp.name = actorname

				local count, avoid = 0, 0
				for _, spell in pairs(actor.damagedspells) do
					count = count + (spell.count or 0)

					for k, v in pairs(missTypes) do
						local num = spell[v] or spell[k]
						if num then
							avoid = avoid + num
							tmp.data = tmp.data or new()
							tmp.data[k] = (tmp.data[k] or 0) + num
						end
					end
				end

				if avoid > 0 then
					tmp.total = count
					tmp.avoid = avoid
					C[actor.id] = tmp

					nr = nr + 1
					local d = win:actor(nr, actor, actor.enemy, actorname)

					d.value = 100 * avoid / count
					fmt_valuetext(d, mode_cols, count, avoid, win.metadata)
					win:color(d, set, actor.enemy)
				elseif C[actor.id] then
					C[actor.id] = del(C[actor.id])
				end
			end
		end
	end

	function mode:OnEnable()
		self.metadata = {
			showspots = true,
			filterclass = true,
			click1 = mode_breakdown,
			columns = {Percent = true, Count = true, Total = true},
			icon = [[Interface\ICONS\ability_warlock_avoidance]]
		}

		mode_cols = self.metadata.columns

		Skada:AddMode(self, "Damage Taken")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Damage Taken")
