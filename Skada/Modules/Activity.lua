local Skada = Skada
Skada:RegisterModule("Activity", function(L, P, _, C, new, _, clear)
	local mod = Skada:NewModule("Activity")
	local targetmod = mod:NewModule("Activity per Target")
	local date, pairs, max = date, pairs, math.max
	local format, pformat = string.format, Skada.pformat
	local get_activity_targets = nil

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
			d.valuetext = Skada:FormatValueCols(
				mod.metadata.columns["Active Time"] and Skada:FormatTime(d.value),
				mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, maxtime)
			)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
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

		-- players.
		for i = 1, #set.players do
			local player = set.players[i]
			if player and Skada.validclass[player.class or "NaN"] and (not win.class or win.class == player.class) then
				local activetime = player:GetTime(true)
				if activetime > 0 then
					nr = nr + 1
					local d = win:actor(nr, player)

					if Skada.forPVP and set.type == "arena" then
						d.color = Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN")
					end

					d.value = activetime
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns["Active Time"] and Skada:FormatTime(d.value),
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, settime)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end

		-- arena enemies
		if not (Skada.forPVP and set.type == "arena" and set.enemies) then return end
		for i = 1, #set.enemies do
			local enemy = set.enemies[i]
			if enemy and Skada.validclass[enemy.class or "NaN"] and (not win.class or win.class == enemy.class) then
				local activetime = enemy:GetTime(true)
				if activetime > 0 then
					nr = nr + 1
					local d = win:actor(nr, enemy, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")

					d.value = activetime
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns["Active Time"] and Skada:FormatTime(d.value),
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, settime)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
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

		-- no total click.
		targetmod.nototal = true

		Skada.RegisterCallback(self, "Skada_ApplySettings", "ApplySettings")
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local settime = set:GetTime()
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns["Active Time"] and Skada:FormatTime(settime),
			self.metadata.columns.Percent and format("%s - %s", date("%H:%M", set.starttime), date("%H:%M", set.endtime))
		)
		return valuetext, settime
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
