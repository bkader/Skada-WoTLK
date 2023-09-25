local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Killing Blows", function(L, P, _, C)
	local mode = Skada:NewModule("Killing Blows")
	local mode_target = mode:NewModule("Target List")
	local mode_source = mode_target:NewModule("Source List")
	local get_actor_killing_blows = nil
	local get_target_killing_blows = nil

	local new, del, clear = Private.newTable, Private.delTable, Private.clearTable
	local uformat = Private.uformat
	local last_damager = {}
	local mode_cols = nil

	local function format_valuetext(d, columns, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Count and Skada:FormatNumber(d.value),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_kill(set, data, dstName)
		local actor = Skada:GetActor(set, data.name, data.id, data.flag)
		if not actor then return end

		set.kill = (set.kill or 0) + 1
		actor.kill = (actor.kill or 0) + 1

		if not dstName or (set == Skada.total and not P.totalidc) then return end

		actor.kills = actor.kills or {}
		actor.kills[dstName] = (actor.kills[dstName] or 0) + 1
	end

	local function spell_damage(t)
		if not t.dstGUID then return end

		local actor = last_damager[t.dstGUID]
		if not actor then
			last_damager[t.dstGUID] = new()
			actor = last_damager[t.dstGUID]
		end

		actor.dstName = t.dstName
		actor.id, actor.name, actor.flag = Skada:FixMyPets(t.srcGUID, t.srcName, t.srcFlags)
	end

	local function unit_died(t)
		if not t.dstGUID then return end

		local actor = last_damager[t.dstGUID]
		if not actor then return end

		Skada:DispatchSets(log_kill, actor, t.dstName)
		last_damager[t.dstGUID] = del(last_damager[t.dstGUID])
	end

	function mode_source:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["Killing blows on %s"], label)
	end

	function mode_source:Update(win, set)
		win.title = uformat(L["Killing blows on %s"], win.targetname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		if not win.targetname then return end

		local total, actors = get_target_killing_blows(set, win.targetname, win.class)
		if not total or not actors then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for actorname, actor in pairs(actors) do
			nr = nr + 1

			local d = win:actor(nr, actor, actor.enemy, actorname)
			d.value = actor.count
			format_valuetext(d, mode_cols, total, win.metadata, true)
		end
	end

	function mode_target:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's killing blows"], label)
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's killing blows"], win.actorname)
		if not set or not win.actorname then return end

		local total, targets = get_actor_killing_blows(set, win.actorname, win.actorid)
		if not total or not targets then
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
		win.title = win.class and format("%s (%s)", L["Killing Blows"], L[win.class]) or L["Killing Blows"]

		local total = set and set:GetTotal(win.class, nil, "kill")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.kill then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.kill
				format_valuetext(d, mode_cols, total, win.metadata)
			end
		end
	end

	function mode_source:GetSetSummary(set, win)
		local actors = win and win.targetname and set and set.kill and set.actors
		if not actors then return end

		local value = 0
		for _, actor in pairs(actors) do
			if not actor.enemy and actor.kills and actor.kills[win.targetname] and (not win.class or actor.class == win.class) then
				value = value + actor.kills[win.targetname]
			end
		end
		return value, Skada:FormatNumber(value)
	end

	function mode:GetSetSummary(set, win)
		if not set then return end
		local value = set:GetTotal(win and win.class, nil, "kill")
		return value, Skada:FormatNumber(value)
	end

	function mode:SetComplete()
		clear(last_damager)
	end

	function mode:OnEnable()
		mode_source.metadata = {showspots = true, ordersort = true, filterclass = true}
		mode_target.metadata = {click1 = mode_source}

		self.metadata = {
			showspots = true,
			ordersort = true,
			filterclass = true,
			click1 = mode_target,
			columns = {Count = true, Damage = true, Percent = true, sPercent = true},
			icon = [[Interface\ICONS\ability_creature_cursed_02]]
		}

		mode_source.nototal = true
		mode_target.nototal = true

		Skada:RegisterForCL(
			spell_damage,
			{src_is_interesting = true, dst_is_not_interesting = true},
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE"
		)

		Skada:RegisterForCL(
			unit_died,
			{dst_is_not_interesting = true},
			"UNIT_DIED",
			"UNIT_DESTROYED",
			"UNIT_DISSIPATES"
		)

		mode_cols = self.metadata.columns
		Skada:AddMode(self, "Damage Done")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	get_actor_killing_blows = function(self, actorname, actorid, tbl)
		local actor = self:GetActor(actorname, actorid)
		local total = actor and actor.kills and actor.kill
		if not total or total == 0 then return end

		tbl = clear(tbl or C)
		for name, count in pairs(actor.kills) do
			local t = tbl[name]
			if not t then
				t = new()
				t.count = 0
				tbl[name] = t
			end
			t.count = t.count + count
			self:_fill_actor_table(t, name)
		end
		return total, tbl
	end

	get_target_killing_blows = function(self, name, class, tbl)
		local actors = self.kill and name and self.actors
		if not actors then return end

		tbl = clear(tbl or C)
		local total = 0
		for actorname, actor in pairs(actors) do
			local count = not actor.enemy and (not class or actor.class == class) and actor.kills and actor.kills[name]
			if count then
				local t = tbl[actorname] or new()
				t.id = actor.id
				t.class = actor.class
				t.role = actor.role
				t.spec = actor.spec
				t.count = count
				tbl[actorname] = t

				total = total + count
			end
		end
		return total, tbl
	end
end)
