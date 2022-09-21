local Skada = Skada
Skada:RegisterModule("Activity", function(L, P, _, C)
	local mod = Skada:NewModule("Activity")
	local targetmod = mod:NewModule("Activity per Target")
	local date, pairs, max = date, pairs, math.max
	local format, pformat = string.format, Skada.pformat
	local new, clear = Skada.newTable, Skada.clearTable
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
		win.title = pformat(L["%s's activity"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's activity"], win.actorname)
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
			if actor and Skada.validclass[actor.class or "NaN"] and (not win.class or win.class == actor.class) then
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
			if actor and Skada.validclass[actor.class or "NaN"] and (not win.class or win.class == actor.class) then
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
		local value = set:GetTime()
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns["Active Time"] and Skada:FormatTime(value),
			self.metadata.columns.Percent and format("%s - %s", date("%H:%M", set.starttime), date("%H:%M", set.endtime))
		)
		return value, valuetext
	end

	function mod:OnInitialize()
		Skada.options.args.tweaks.args.general.args.tartime = {
			type = "toggle",
			name = L["Activity per Target"],
			order = 110
		}
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			tooltip = activity_tooltip,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {["Active Time"] = true, Percent = true, sPercent = true},
			icon = [[Interface\Icons\spell_holy_borrowedtime]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		targetmod.nototal = true

		Skada.RegisterCallback(self, "Skada_ApplySettings", "ApplySettings")
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	local Old_AddActiveTime = Skada.AddActiveTime
	local function Alt_AddActiveTime(self, set, actor, cond, diff, target)
		if actor and actor.last and cond then
			local curtime = set.last_time or GetTime()
			local delta = curtime - actor.last

			if diff and diff > 0 and diff < delta then
				delta = diff
			elseif delta > 3.5 then
				delta = 3.5
			end

			actor.last = curtime
			local add = floor(100 * delta + 0.5) / 100
			actor.time = (actor.time or 0) + add

			if target and (set ~= self.total or P.totalidc) then
				actor.tartime = actor.tartime or {}
				actor.tartime[target] = (actor.tartime[target] or 0) + add
			end
		end
	end

	function mod:ApplySettings()
		if P.tartime and Skada.AddActiveTime ~= Alt_AddActiveTime then
			Skada.AddActiveTime = Alt_AddActiveTime
			self.metadata.click1 = targetmod
			self:Reload()
		elseif not P.tartime and Skada.AddActiveTime ~= Old_AddActiveTime then
			Skada.AddActiveTime = Old_AddActiveTime
			self.metadata.click1 = nil
			self:Reload()
		end
	end

	---------------------------------------------------------------------------

	get_activity_targets = function(self, tbl)
		if not self.tartime then return end

		tbl = clear(tbl or C)
		for name, _time in pairs(self.tartime) do
			tbl[name] = new()
			tbl[name].time = _time
			self.super:_fill_actor_table(tbl[name], name)
		end
		return tbl
	end
end)
