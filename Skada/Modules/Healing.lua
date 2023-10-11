local _, Skada = ...
local Private = Skada.Private

-- cache frequently used globals
local pairs, max = pairs, math.max
local format, uformat = string.format, Private.uformat
local tooltip_school = Skada.tooltip_school
local hits_perc = "%s (\124cffffffff%s\124r)"

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

---------------------------------------------------------------------------
-- Healing Module

Skada:RegisterModule("Healing", function(L, P)
	local mode = Skada:NewModule("Healing")
	local mode_spell = mode:NewModule("Spell List")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	local ignored_spells = Skada.ignored_spells.heal -- Edit Skada\Core\Tables.lua
	local passive_spells = Skada.ignored_spells.time -- Edit Skada\Core\Tables.lua
	tooltip_school = tooltip_school or Skada.tooltip_school
	local new, del = Private.newTable, Private.delTable
	local wipe, clear = wipe, Private.clearTable
	local PercentToRGB = Private.PercentToRGB
	local GetTempUnit = Private.GetTempUnit
	local AddTempUnit = Private.AddTempUnit
	local DelTempUnit = Private.DelTempUnit
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	-- list of spells used to queue units.
	local queued_spells = {[49005] = 50424}
	local heal = {}
	local function log_heal(set)
		if not heal.amount then return end

		local actor = Skada:GetActor(set, heal.actorname, heal.actorid, heal.actorflags)
		if not actor then return end

		-- get rid of overheal
		local amount = max(0, heal.amount - heal.overheal)
		if actor.role == "HEALER" and amount > 0 and not heal.petname and not passive_spells[heal.spell] then
			Skada:AddActiveTime(set, actor, heal.dstName)
		end

		-- record the healing
		actor.heal = (actor.heal or 0) + amount
		set.heal = (set.heal or 0) + amount

		-- record the overheal
		local overheal = (heal.overheal > 0) and heal.overheal or nil
		if overheal then
			actor.overheal = (actor.overheal or 0) + overheal
			set.overheal = (set.overheal or 0) + overheal
		end

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- record the spell
		local spell = actor.healspells and actor.healspells[heal.spellid]
		if not spell then
			actor.healspells = actor.healspells or {}
			actor.healspells[heal.spellid] = {amount = 0}
			spell = actor.healspells[heal.spellid]
		end

		spell.count = (spell.count or 0) + 1
		spell.amount = spell.amount + amount

		if overheal then
			spell.o_amt = (spell.o_amt or 0) + overheal
		end

		if heal.critical then
			spell.c_num = (spell.c_num or 0) + 1
			spell.c_amt = (spell.c_amt or 0) + amount
			if not spell.c_max or amount > spell.c_max then
				spell.c_max = amount
			end
			if not spell.c_min or amount < spell.c_min then
				spell.c_min = amount
			end
		else
			spell.n_num = (spell.n_num or 0) + 1
			spell.n_amt = (spell.n_amt or 0) + amount
			if not spell.n_max or amount > spell.n_max and amount > 0 then
				spell.n_max = amount
			end
			if not spell.n_min or amount < spell.n_min and amount > 0 then
				spell.n_min = amount
			end
		end

		-- record the target
		if not heal.dstName then return end
		local target = spell.targets and spell.targets[heal.dstName]
		if not target then
			spell.targets = spell.targets or {}
			spell.targets[heal.dstName] = {amount = 0}
			target = spell.targets[heal.dstName]
		end
		target.amount = target.amount + amount

		if overheal then
			target.o_amt = (target.o_amt or 0) + overheal
		end
	end

	local function spell_heal(t)
		if not t.spellid or ignored_spells[t.spellid] then return end

		heal.dstName = Skada:FixPetsName(t.dstGUID, t.dstName, t.dstFlags)
		heal.spell = t.spellid
		heal.spellid = t.spellstring
		heal.amount = t.amount
		heal.overheal = t.overheal
		heal.critical = t.critical

		local srcQueued = GetTempUnit(t.srcGUID)
		if srcQueued and srcQueued.spellid == t.spellid then
			heal.actorid, heal.actorname, heal.actorflags = srcQueued.id, srcQueued.name, srcQueued.flag
		else
			heal.actorid = t.srcGUID
			heal.actorname = t.srcName
			heal.actorflags = t.srcFlags
			Skada:FixPets(heal)
		end

		Skada:DispatchSets(log_heal)
	end

	local function spell_aura(t)
		local spellid = t.spellid and not ignored_spells[t.spellid] and queued_spells[t.spellid]
		if not spellid then
			return
		elseif t.event == "SPELL_AURA_APPLIED" then
			local info = new()
			info.id = t.srcGUID
			info.name = t.srcName
			info.flag = t.srcFlags
			info.spellid = spellid

			AddTempUnit(t.dstGUID, info)
		else
			DelTempUnit(t.dstGUID)
		end
	end

	local function healing_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(set, true)
		local hps, amount = actor:GetHPS(set)

		local activepercent = activetime / totaltime * 100
		tooltip:AddDoubleLine(format(L["%s's activity"], classfmt(actor.class, label)), Skada:FormatPercent(activepercent), nil, nil, nil, PercentToRGB(activepercent))
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(amount), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(format("%s/%s", Skada:FormatNumber(amount), suffix), Skada:FormatNumber(hps), 1, 1, 1)
	end

	local function mode_spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.healspells and actor.healspells[id]
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
		local total = actor and actor:GetHealOnTarget(win.targetname)
		local spells = (total and total > 0) and actor.healspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			local tar = spell.targets and spell.targets[win.targetname]
			local amount = tar and (actor.enemy and tar or tar.amount)
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellid, true)
				d.value = amount
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
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

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local targets, total, actor = set:GetActorHealTargets(win.actorname, win.actorid)
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

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Healing"], L[win.class]) or L["Healing"]

		local total = set and set:GetHeal(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.heal then
				local hps, amount = actor:GetHPS(set, nil, not mode_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, mode_cols, total, hps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode_spell:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local hps, amount = actor:GetHPS(set, false, not mode_cols.sHPS)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(amount),
			mode_cols.sHPS and Skada:FormatNumber(hps)
		)
		return amount, valuetext
	end
	mode_target.GetSetSummary = mode_spell.GetSetSummary

	function mode:GetSetSummary(set, win)
		local hps, amount = set:GetHPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(amount),
			mode_cols.HPS and Skada:FormatNumber(hps)
		)
		return amount, valuetext
	end

	function mode:OnEnable()
		mode_spell.metadata = {tooltip = mode_spell_tooltip}
		mode_target.metadata = {showspots = true, click1 = mode_target_spell}
		self.metadata = {
			showspots = true,
			filterclass = true,
			tooltip = healing_tooltip,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\ICONS\spell_nature_healingtouch]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		local flags_src = {src_is_interesting = true}

		Skada:RegisterForCL(
			spell_heal,
			flags_src,
			"SPELL_HEAL",
			"SPELL_PERIODIC_HEAL"
		)

		Skada:RegisterForCL(
			spell_aura,
			flags_src,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REMOVED"
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mode:CombatLeave()
		wipe(heal)
	end

	function mode:SetComplete(set)
		local total = (set.heal or 0) + (set.overheal or 0)
		if total == 0 then return end

		-- clean healspells table!
		for _, actor in pairs(set.actors) do
			local amount = (actor.heal or 0) + (actor.overheal or 0)
			if (not amount and actor.healspells) or amount == 0 then
				actor.heal, actor.overheal = nil, nil
				actor.healspells = del(actor.healspells, true)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Overhealing Module

Skada:RegisterModule("Overhealing", function(L)
	local mode = Skada:NewModule("Overhealing")
	local mode_spell = mode:NewModule("Spell List")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function fmt_valuetext(d, columns, total, dps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Overhealing and Skada:FormatNumber(d.value),
			columns[subview and "sHPS" or "HPS"] and Skada:FormatNumber(dps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
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
		local total = actor and actor:GetOverhealOnTarget(win.targetname)

		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)
		local spells = actor.healspells

		for spellid, spell in pairs(spells) do
			local tar = spell.targets and spell.targets[win.targetname]
			if tar and tar.o_amt and tar.o_amt > 0 then
				nr = nr + 1

				local d = win:spell(nr, spellid, true)
				d.value = tar.o_amt
				fmt_valuetext(d, mode.metadata.columns, tar.amount + d.value, actortime and (d.value / actortime), win.metadata, true)
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
		local total = actor and actor:GetOverheal()
		local spells = (total and total > 0) and actor.healspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			if spell.o_amt and spell.o_amt > 0 then
				nr = nr + 1

				local d = win:spell(nr, spellid, true)
				d.value = spell.o_amt
				fmt_valuetext(d, mode_cols, spell.amount + d.value, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.overheal
		local targets = (total and total > 0) and actor:GetOverhealTargets(set)

		if not targets then
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
			fmt_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Overhealing"], L[win.class]) or L["Overhealing"]

		local total = set and set:GetOverheal(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.overheal then
				local ohps, overheal = actor:GetOHPS(set, nil, not mode_cols.HPS)
				if overheal > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = actor.overheal
					fmt_valuetext(d, mode_cols, actor.heal + d.value, ohps, win.metadata)
				end
			end
		end
	end

	function mode_spell:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local ohps, overheal = actor:GetOHPS(set, false, not mode_cols.sHPS)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Overhealing and Skada:FormatNumber(overheal),
			mode_cols.sHPS and Skada:FormatNumber(ohps)
		)
		return overheal, valuetext
	end
	mode_target.GetSetSummary = mode_spell.GetSetSummary

	function mode:GetSetSummary(set, win)
		local ohps, overheal = set:GetOHPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Overhealing and Skada:FormatNumber(overheal),
			mode_cols.HPS and Skada:FormatNumber(ohps)
		)
		return overheal, valuetext
	end

	function mode:OnEnable()
		mode_target.metadata = {click1 = mode_target_spell}
		self.metadata = {
			showspots = true,
			filterclass = true,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Overhealing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\ICONS\spell_holy_holybolt]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Healing")

---------------------------------------------------------------------------
-- Total Healing Module

Skada:RegisterModule("Total Healing", function(L)
	local mode = Skada:NewModule("Total Healing")
	local mode_spell = mode:NewModule("Spell List")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	tooltip_school = tooltip_school or Skada.tooltip_school
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function mode_spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.healspells and actor.healspells[id]
		if not spell then return end

		tooltip:AddLine(uformat("%s - %s", classfmt(win.actorclass, win.actorname), label))
		tooltip_school(tooltip, id)

		local total = spell.amount + (spell.o_amt or 0)
		tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(total), 1, 1, 1)
		if spell.amount > 0 then
			tooltip:AddDoubleLine(L["Healing"], format(hits_perc, Skada:FormatNumber(spell.amount), Skada:FormatPercent(spell.amount, total)), 0.67, 1, 0.67)
		end
		if spell.o_amt and spell.o_amt > 0 then
			tooltip:AddDoubleLine(L["Overheal"], format(hits_perc, Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, total)), 1, 0.67, 0.67)
		end

		if not spell.count or spell.count == 0 then return end

		tooltip:AddLine(" ")

		local cast = actor.GetSpellCast and actor:GetSpellCast(id)
		if cast then
			tooltip:AddDoubleLine(L["Casts"], cast, nil, nil, nil, 1, 1, 1)
		end

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
		local total = actor and actor:GetTotalHealOnTarget(win.targetname)
		local spells = (total and total > 0) and actor.healspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			local tar = spell.targets and spell.targets[win.targetname]
			if tar then
				nr = nr + 1

				local d = win:spell(nr, spellid, true)
				d.value = actor.enemy and tar or (tar.amount + (tar.o_amt or 0))
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
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
		local total = actor and actor:GetTotalHeal()
		local spells = (total and total > 0) and actor.healspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			local amount = spell.amount + (spell.o_amt or 0)
			if amount > 0 then
				nr = nr + 1

				local d = win:spell(nr, spellid, true)
				d.value = amount
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = format(L["%s's targets"], classfmt(win.actorclass, win.actorname))

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetTotalHeal()
		local targets = (total and total > 0) and actor:GetTotalHealTargets(set)

		if not targets then
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

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Total Healing"], L[win.class]) or L["Total Healing"]

		local total = set and set:GetTotalHeal(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and (actor.heal or actor.overheal) then
				local hps, amount = actor:GetTHPS(set, nil, not mode_cols.HPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, mode_cols, total, hps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode_spell:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local ops, amount = actor:GetTHPS(set, false, not mode_cols.sHPS)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(amount),
			mode_cols.sHPS and Skada:FormatNumber(ops)
		)
		return amount, valuetext
	end
	mode_target.GetSetSummary = mode_spell.GetSetSummary

	function mode:GetSetSummary(set, win)
		local ops, amount = set:GetTHPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Healing and Skada:FormatNumber(amount),
			mode_cols.HPS and Skada:FormatNumber(ops)
		)
		return amount, valuetext
	end

	function mode:OnEnable()
		mode_target.metadata = {showspots = true, click1 = mode_target_spell}
		mode_spell.metadata = {tooltip = mode_spell_tooltip}
		self.metadata = {
			showspots = true,
			filterclass = true,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\ICONS\spell_holy_flashheal]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Healing")

---------------------------------------------------------------------------
-- Healing Taken Module

Skada:RegisterModule("Healing Taken", function(L, P)
	local mode = Skada:NewModule("Healing Taken")
	local mode_source = mode:NewModule("Source List")
	local mode_source_spell = mode_source:NewModule("Spell List")
	local mode_spell = mode:NewModule("Spell List")
	local mode_spell_source = mode_source:NewModule("Source List")
	local new, clear = Private.newTable, Private.clearTable
	local C, classfmt = Skada.cacheTable2, Skada.classcolors.format
	local mode_cols = nil

	local get_set_healed_actors = nil
	local get_actor_heal_sources = nil
	local get_actor_healed_spells = nil
	local get_actor_heal_spell_sources = nil

	function mode_source:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's sources"], classfmt(class, label))
	end

	function mode_source:Update(win, set)
		win.title = format(L["%s's sources"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local sources, total, actor = get_actor_heal_sources(set, win.actorname, win.actorid)
		if not actor or not sources or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		for sourcename, source in pairs(C) do
			nr = nr + 1

			local d = win:actor(nr, source, source.enemy, sourcename)
			d.value = source.amount
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["Spells on %s"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = format(L["Spells on %s"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local spells, total, actor = get_actor_healed_spells(set, win.actorname, win.actorid)
		if not actor or not spells or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = spell.amount
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_source_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = uformat(L["%s's spells on %s"], classfmt(class, label), classfmt(win.actorclass, win.actorname))
	end

	function mode_source_spell:Update(win, set)
		win.title = uformat(L["%s's spells on %s"], classfmt(win.targetclass, win.targetname), classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.targetname, win.targetid)
		if not actor then return end

		local total = actor and actor:GetAbsorbHealOnTarget(win.actorname)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		local spells = actor.absorbspells -- absorb spells
		if spells then
			for spellid, spell in pairs(spells) do
				local amt = spell.targets and spell.targets[win.actorname]
				if amt then
					nr = nr + 1

					local d = win:spell(nr, spellid, spell)
					d.value = amt
					format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
				end
			end
		end

		if actor.healspells then
			for spellid, spell in pairs(actor.healspells) do
				local tar = spell.targets and spell.targets[win.actorname]
				if tar then
					nr = nr + 1

					local d = win:spell(nr, spellid, true)
					d.value = actor.enemy and tar or tar.amount
					format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
				end
			end
		end
	end

	function mode_spell_source:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> sources"], classfmt(win.actorclass, win.actorname), label)
	end

	function mode_spell_source:Update(win, set)
		win.title = uformat(L["%s's <%s> sources"], classfmt(win.actorclass, win.actorname), win.spellname)
		if not set or not win.actorname or not win.spellid then return end

		local sources, total, actor = get_actor_heal_spell_sources(set, win.actorname, win.actorid, win.spellid)
		if not actor or not sources or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sHPS and actor:GetTime(set)

		for sourcename, source in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, source, source.enemy, sourcename)
			d.value = source.amount
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Healing Taken"], L[win.class]) or L["Healing Taken"]

		local total = set and set:GetAbsorbHeal()
		local actors = (total and total > 0) and get_set_healed_actors(set)

		if not actors then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local settime = set:GetTime()

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set) then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.amount
				format_valuetext(d, mode_cols, total, d.value / (actor.time or settime), win.metadata)
			end
		end
	end

	function mode:OnEnable()
		mode_spell_source.metadata = {showspots = true}
		mode_source.metadata = {showspots = true, click1 = mode_source_spell}
		mode_spell.metadata = {click1 = mode_spell_source}
		self.metadata = {
			showspots = true,
			filterclass = true,
			click1 = mode_source,
			click2 = mode_spell,
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\ICONS\spell_nature_resistnature]]
		}

		mode_cols = self.metadata.columns

		Skada:AddMode(self, "Absorbs and Healing")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	get_set_healed_actors = function(self, tbl)
		local total = (self.heal or 0) + (self.absorb or 0)
		if self.arena then
			total = total + (self.eheal or 0) + (self.eabsorb or 0)
		end
		if total == 0 then return end

		tbl = clear(tbl or C)

		local actors = self.actors
		for _, actor in pairs(actors) do
			local spells = (not actor.enemy or self.arena) and actor.absorbspells -- absorb spells
			if spells then
				for _, spell in pairs(spells) do
					if spell.targets then
						for name, amount in pairs(spell.targets) do
							if amount > 0 then
								local t = tbl[name]
								if not t then
									t = new()
									t.amount = amount
									tbl[name] = t
								else
									t.amount = t.amount + amount
								end

								self:_fill_actor_table(t, name, true)
							end
						end
					end
				end
			end

			spells = (not actor.enemy or self.arena) and actor.healspells -- heal spells
			if spells then
				for _, spell in pairs(spells) do
					if spell.targets then
						for name, target in pairs(spell.targets) do
							if target.amount > 0 then
								local t = tbl[name]
								if not t then
									t = new()
									t.amount = target.amount
									tbl[name] = t
								else
									t.amount = t.amount + target.amount
								end

								self:_fill_actor_table(t, name, true)
							end
						end
					end
				end
			end
		end

		return tbl, total
	end

	get_actor_heal_sources = function(self, name, id, tbl)
		local sources = self.actors
		local actor = sources and self:GetActor(name, id)
		if not actor then return end

		tbl = clear(tbl or C)
		local total = 0

		for sourcename, source in pairs(sources) do
			local spells = (not source.enemy or self.arena) and source.absorbspells -- absorb spells
			if spells then
				for spellid, spell in pairs(spells) do
					local amount = spell.targets and spell.targets[name]
					if amount and amount > 0 then
						total = total + amount

						local t = tbl[sourcename]
						if not t then
							t = new()
							t.id = source.id
							t.class = source.class
							t.role = source.role
							t.spec = source.spec
							t.enemy = source.enemy
							t.amount = amount
							tbl[sourcename] = t
						else
							t.amount = t.amount + amount
						end
					end
				end
			end

			spells = (not source.enemy or self.arena) and source.healspells -- heal spells
			if spells then
				for spellid, spell in pairs(spells) do
					local amount = spell.targets and spell.targets[name] and spell.targets[name].amount
					if amount and amount > 0 then
						total = total + amount

						local t = tbl[sourcename]
						if not t then
							t = new()
							t.id = source.id
							t.class = source.class
							t.role = source.role
							t.spec = source.spec
							t.enemy = source.enemy
							t.amount = amount
							tbl[sourcename] = t
						else
							t.amount = t.amount + amount
						end
					end
				end
			end
		end

		return tbl, total, actor
	end

	get_actor_healed_spells = function(self, name, id, tbl)
		local sources = self.actors
		local actor = sources and self:GetActor(name, id)
		if not actor then return end

		tbl = clear(tbl or C)
		local total = 0

		for _, source in pairs(sources) do
			local spells = (not actor.enemy or self.arena) and source.absorbspells -- absorb spells
			if spells then
				for spellid, spell in pairs(spells) do
					local amount = spell.targets and spell.targets[name]
					if amount and amount > 0 then
						total = total + amount

						local t = tbl[spellid]
						if not t then
							t = new()
							t.amount = amount
							tbl[spellid] = t
						else
							t.amount = t.amount + amount
						end
					end
				end
			end

			spells = (not source.enemy or self.arena) and source.healspells -- heal spells
			if spells then
				for spellid, spell in pairs(spells) do
					local amount = spell.targets and spell.targets[name] and spell.targets[name].amount
					if amount and amount > 0 then
						total = total + amount

						local t = tbl[spellid]
						if not t then
							t = new()
							t.amount = amount
							tbl[spellid] = t
						else
							t.amount = t.amount + amount
						end
					end
				end
			end
		end

		return tbl, total, actor
	end

	get_actor_heal_spell_sources = function(self, name, id, spellid)
		local sources = spellid and self.actors
		local actor = sources and self:GetActor(name, id)
		if not actor then return end

		tbl = clear(tbl or C)
		local total = 0

		for sourcename, source in pairs(sources) do
			local spells = (not source.enemy or self.arena) and source.absorbspells -- absorb spells
			if spells then
				for sid, spell in pairs(spells) do
					local amount = (sid == spellid) and spell.targets and spell.targets[name]
					if amount and amount > 0 then
						total = total + amount

						local t = tbl[sourcename]
						if not t then
							t = new()
							t.id = source.id
							t.class = source.class
							t.role = source.role
							t.spec = source.spec
							t.enemy = source.enemy
							t.amount = amount
							tbl[sourcename] = t
						else
							t.amount = t.amount + amount
						end
					end
				end
			end

			spells = (not source.enemy or self.arena) and source.healspells -- heal spells
			if spells then
				for sid, spell in pairs(spells) do
					local amount = (sid == spellid) and spell.targets and spell.targets[name] and spell.targets[name].amount
					if amount and amount > 0 then
						total = total + amount

						local t = tbl[sourcename]
						if not t then
							t = new()
							t.id = source.id
							t.class = source.class
							t.role = source.role
							t.spec = source.spec
							t.enemy = source.enemy
							t.amount = amount
							tbl[sourcename] = t
						else
							t.amount = t.amount + amount
						end
					end
				end
			end
		end

		return tbl, total, actor
	end
end, "Absorbs", "Healing")
