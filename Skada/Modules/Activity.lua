local _, Skada = ...
local private = Skada.private
Skada:RegisterModule("Activity", function(L, P, _, C)
	local mod = Skada:NewModule("Activity")
	local targetmod = mod:NewModule("Activity per Target")
	local date, pairs, format = date, pairs, string.format
	local uformat, new, clear = private.uformat, private.newTable, private.clearTable
	local get_activity_targets = nil
	local mod_cols = nil

	local function format_valuetext(d, columns, maxtime, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns["Active Time"] and Skada:FormatTime(d.value),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, maxtime)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function activity_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local player = set and set:GetPlayer(id, label)
		if not player then return end

		local settime = set:GetTime()
		if settime == 0 then return end

		local activetime = player:GetTime(true)
		tooltip:AddLine(player.name .. ": " .. L["Activity"])
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, settime), nil, nil, nil, 1, 1, 1)
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = uformat(L["%s's activity"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's activity"], win.actorname)
		if not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local maxtime = actor and actor:GetTime(true)
		local targets = maxtime and get_activity_targets(actor)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for name, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, name)
			d.value = target.time
			format_valuetext(d, mod_cols, maxtime, win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Activity"], L[win.class]) or L["Activity"]

		local settime = set and set:GetTime()
		if not settime or settime == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players.
		for i = 1, #actors do
			local actor = actors[i]
			if win:show_actor(actor, set) and Skada.validclass[actor.class or "NaN"] then
				local activetime = actor:GetTime(true)
				if activetime > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor)
					d.color = set.__arena and Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN") or nil
					d.value = activetime
					format_valuetext(d, mod_cols, settime, win.metadata)
				end
			end
		end

		actors = set.__arena and set.enemies or nil -- arena enemies
		if not actors then return end

		for i = 1, #actors do
			local actor = actors[i]
			if win:show_actor(actor, set) and Skada.validclass[actor.class or "NaN"] then
				local activetime = actor:GetTime(true)
				if activetime > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")
					d.value = activetime
					format_valuetext(d, mod_cols, settime, win.metadata)
				end
			end
		end
	end

	function mod:GetSetSummary(set)
		if not set or not set.time then return end

		local settime = set.time
		local value, valuetext = nil, nil

		if set.activetime then
			value = set.activetime
			valuetext = Skada:FormatValueCols(
				mod_cols["Active Time"] and Skada:FormatTime(value),
				mod_cols.Percent and Skada:FormatPercent(value, settime)
			)
		else -- backwards compatibility
			value = settime
			valuetext = Skada:FormatValueCols(
				mod_cols["Active Time"] and Skada:FormatTime(value),
				mod_cols.Percent and format("%s - %s", date("%H:%M", set.starttime), date("%H:%M", set.endtime))
			)
		end

		return value, valuetext
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			tooltip = activity_tooltip,
			click1 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {["Active Time"] = true, Percent = true, sPercent = true},
			icon = [[Interface\Icons\spell_holy_borrowedtime]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		targetmod.nototal = true

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	get_activity_targets = function(self, tbl)
		if not self.super or not self.timespent then return end

		tbl = clear(tbl or C)
		for name, timespent in pairs(self.timespent) do
			tbl[name] = new()
			tbl[name].time = timespent
			self.super:_fill_actor_table(tbl[name], name)
		end
		return tbl
	end
end)
