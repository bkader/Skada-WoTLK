local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Resurrects", function(L, P, _, C)
	local mode = Skada:NewModule("Resurrects")
	local mode_target = mode:NewModule("Target List")

	local pairs, format, uformat = pairs, string.format, Private.uformat
	local new, clear = Private.newTable, Private.clearTable
	local classfmt = Skada.classcolors.format
	local ress_spells = Skada.ress_spells
	local get_actor_ress_targets = nil
	local mode_cols = nil

	local function format_valuetext(d, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Count and d.value,
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_resurrect(set, actorname, actorid, actorflags, dstName)
		local actor = Skada:GetActor(set, actorname, actorid, actorflags)
		if not actor then return end

		actor.ress = (actor.ress or 0) + 1
		set.ress = (set.ress or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not dstName then return end
		actor.resstargets = actor.resstargets or {}
		actor.resstargets[dstName] = (actor.resstargets[dstName] or 0) + 1
	end

	local function spell_resurrect(t)
		if t.spellid and (t.event == "SPELL_RESURRECT" or ress_spells[t.spellid]) then
			local dstName = (t.event == "SPELL_RESURRECT") and t.dstName or t.srcName
			Skada:DispatchSets(log_resurrect, t.srcName, t.srcGUID, t.srcFlags, dstName)
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local targets, total, actor = get_actor_ress_targets(set, win.actorname, win.actorid)
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
			format_valuetext(d, total, win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Resurrects"], L[win.class]) or L["Resurrects"]

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
				format_valuetext(d, total, win.metadata)
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
			filterclass = true,
			click1 = mode_target,
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\ICONS\spell_holy_resurrection]]
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

	get_actor_ress_targets = function(self, name, id, tbl)
		local actor = self:GetActor(name, id)
		local total = actor and actor.ress
		local targets = total and actor.resstargets
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
