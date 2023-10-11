local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Activity", function(L, P, _, C)
	local mode = Skada:NewModule("Activity")
	local mode_target = mode:NewModule("Activity per Target")
	local date, pairs, format = date, pairs, string.format
	local uformat, new, clear = Private.uformat, Private.newTable, Private.clearTable
	local classfmt = Skada.classcolors.format
	local get_activity_targets = nil
	local mode_cols = nil

	local function format_valuetext(d, maxtime, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols["Active Time"] and Skada:FormatTime(d.value),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, maxtime)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function activity_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local settime = set:GetTime()
		if settime == 0 then return end

		local activetime = actor:GetTime(set, true)
		tooltip:AddLine(uformat("%s - %s", classfmt(actor.class, label), L["Activity"]))
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, settime), nil, nil, nil, 1, 1, 1)
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's activity"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's activity"], classfmt(win.actorclass, win.actorname))
		if not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local maxtime = actor and actor:GetTime(set, true)
		local targets = maxtime and get_activity_targets(actor, set)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for name, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, name)
			d.value = target.time
			format_valuetext(d, maxtime, win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Activity"], L[win.class]) or L["Activity"]

		local settime = set and set:GetTime()
		if not settime or settime == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) then
				local activetime = actor:GetTime(set, true)
				if activetime > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = activetime
					format_valuetext(d, settime, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode_target:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		if not actor or not actor.time then return end
		return actor.time, Skada:FormatTime(actor.time)
	end

	function mode:GetSetSummary(set)
		if not set or not set.time then return end
		local valuetext = Skada:FormatValueCols(
			mode_cols["Active Time"] and Skada:FormatTime(set.time),
			mode_cols.Percent and format("%s - %s", date("%H:%M", set.starttime), date("%H:%M", set.endtime))
		)
		return set.time, valuetext
	end

	function mode:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			filterclass = true,
			tooltip = activity_tooltip,
			click1 = mode_target,
			columns = {["Active Time"] = true, Percent = true, sPercent = true},
			icon = [[Interface\ICONS\spell_holy_borrowedtime]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_target.nototal = true

		Skada:AddMode(self)
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	get_activity_targets = function(self, set, tbl)
		if not set or not self.timespent then return end

		tbl = clear(tbl or C)
		for name, timespent in pairs(self.timespent) do
			tbl[name] = new()
			tbl[name].time = timespent
			set:_fill_actor_table(tbl[name], name)
		end
		return tbl
	end
end)
