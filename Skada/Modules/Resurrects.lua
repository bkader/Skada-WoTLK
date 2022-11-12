local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Resurrects", function(L, P, _, C)
	local mode = Skada:NewModule("Resurrects")
	local mode_target = mode:NewModule("Target List")

	local pairs, format, uformat = pairs, string.format, Private.uformat
	local new, clear = Private.newTable, Private.clearTable
	local get_actor_ress_targets = nil
	local ress_spells = Skada.ress_spells
	local mode_cols = nil

	local function format_valuetext(d, columns, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Count and d.value,
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local ress = {}
	local function log_resurrect(set)
		local actor = Skada:GetActor(set, ress.actorid, ress.actorname, ress.actorflags)
		if not actor then return end

		actor.ress = (actor.ress or 0) + 1
		set.ress = (set.ress or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not ress.dstName then return end
		actor.resstargets = actor.resstargets or {}
		actor.resstargets[ress.dstName] = (actor.resstargets[ress.dstName] or 0) + 1
	end

	local function spell_resurrect(t)
		if t.spellid and (t.event == "SPELL_RESURRECT" or ress_spells[t.spellid]) then
			ress.actorid = t.srcGUID
			ress.actorname = t.srcName
			ress.actorflags = t.srcFlags
			ress.dstName = (t.event == "SPELL_RESURRECT") and t.dstName or t.srcName

			Skada:DispatchSets(log_resurrect)
		end
	end

	function mode_target:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's resurrect targets"], label)
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's resurrect targets"], win.actorname)
		if not set or not win.actorname then return end

		local targets, total, actor = get_actor_ress_targets(set, win.actorid, win.actorname)
		if not targets or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, targetname)
			d.value = target.count
			format_valuetext(d, mode_cols, total, win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = L["Resurrects"]

		local total = set and set:GetTotal(win.class, nil, "ress")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.ress then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.ress
				format_valuetext(d, mode_cols, total, win.metadata)
			end
		end
	end

	function mode:GetSetSummary(set, win)
		if not set then return end
		return set:GetTotal(win and win.class, nil, "ress") or 0
	end

	function mode:OnEnable()
		self.metadata = {
			valuesort = true,
			click1 = mode_target,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\spell_holy_resurrection]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_target.nototal = true

		Skada:RegisterForCL(spell_resurrect, {src_is_not_interesting = true, dst_is_interesting_nopets = true}, "SPELL_RESURRECT")
		Skada:RegisterForCL(spell_resurrect, {src_is_interesting = true, dst_is_not_interesting = true}, "SPELL_CAST_SUCCESS")

		Skada:AddMode(self)
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end

	function mode:AddToTooltip(set, tooltip)
		if set.ress and set.ress > 0 then
			tooltip:AddDoubleLine(L["Resurrects"], set.ress, 1, 1, 1)
		end
	end

	---------------------------------------------------------------------------

	get_actor_ress_targets = function(self, id, name, tbl)
		local actor = self:GetActor(id, name)
		local total = actor and actor.ress
		local targets = total and actor.restargets
		if not targets then return end

		tbl = clear(tbl or C)
		for targetname, count in pairs(targets) do
			local t = new()
			t.count = count
			self:_fill_actor_table(t, targetname)
			tbl[targetname] = t
		end
		return tbl, total, actor
	end
end)
