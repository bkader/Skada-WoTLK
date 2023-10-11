local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Killing Blows", function(L, P, _, C, M, O)
	local mode = Skada:NewModule("Killing Blows")
	local mode_target = mode:NewModule("Target List")
	local mode_source = mode_target:NewModule("Source List")
	local get_actor_killing_blows = nil
	local get_target_killing_blows = nil
	local mode_cols = nil

	local KILLING_BLOWS = _G.KILLING_BLOWS or mode.localeName
	local next, tconcat = next, table.concat
	local SpellLink, uformat = Private.SpellLink or GetSpellLink, Private.uformat
	local new, del, clear = Private.newTable, Private.delTable, Private.clearTable
	local classfmt = Skada.classcolors.format
	local announce_fmt = format("%s: %%s > %%s <%%s> %%s", KILLING_BLOWS)
	local last_damager = {}

	local function format_valuetext(d, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Count and Skada:FormatNumber(d.value),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_kill(set, data)
		local actor = Skada:GetActor(set, data.actorname, data.actorid, data.actorflags)
		if not actor then return end

		set.kill = (set.kill or 0) + 1
		actor.kill = (actor.kill or 0) + 1

		local dstName = (set ~= Skada.total or P.totalidc) and data.dstName
		if not dstName then return end

		actor.kills = actor.kills or {}
		actor.kills[dstName] = (actor.kills[dstName] or 0) + 1
	end

	local function spell_damage(t)
		if not t.dstGUID or (M.killpvponly and not t:DestIsPlayer()) then return end

		local data = last_damager[t.dstGUID] or new()
		last_damager[t.dstGUID] = data

		data.actorid = t.srcGUID
		data.actorname = t.srcName
		data.actorflags = t.srcFlags
		data.dstName = t.dstName

		-- announcing? collect data...
		if M.killannounce then
			data.spellname = t.spellname
			data.amount = t.amount
			data.overkill = t.overkill
			data.absorbed = t.absorbed
			data.blocked = t.blocked
			data.resisted = t.resisted
		end

		Skada:FixPets(data)
	end

	local function unit_died(t)
		local data = t.dstGUID and last_damager[t.dstGUID]
		if not data then return end

		Skada:DispatchSets(log_kill, data)

		if M.killannounce and t:DestIsBoss() then
			local output = format(
				announce_fmt,
				data.actorname,
				data.dstName,
				data.spellname or L["Unknown"],
				data.amount and Skada:FormatNumber(0 - data.amount, 1) or "??"
			)

			if data.overkill or data.resisted or data.blocked or data.absorbed then
				local extra = new()

				if data.overkill then
					extra[#extra + 1] = format("O:%s", Skada:FormatNumber(data.overkill, 1))
				end
				if data.resisted then
					extra[#extra + 1] = format("R:%s", Skada:FormatNumber(data.resisted, 1))
				end
				if data.blocked then
					extra[#extra + 1] = format("B:%s", Skada:FormatNumber(data.blocked, 1))
				end
				if data.absorbed then
					extra[#extra + 1] = format("A:%s", Skada:FormatNumber(data.absorbed, 1))
				end

				if next(extra) then
					output = format("%s [%s]", output, tconcat(extra, " - "))
				end

				extra = del(extra)
			end

			Skada:SendChat(output, M.killchannel or "SAY", "preset")
		end

		-- not needed anymore?
		last_damager[t.dstGUID] = del(last_damager[t.dstGUID])
	end

	function mode_source:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = format("%s - %s", classfmt(class, label), KILLING_BLOWS)
	end

	function mode_source:Update(win, set)
		win.title = uformat("%s - %s", classfmt(win.targetclass, win.targetname), KILLING_BLOWS)
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
			format_valuetext(d, total, win.metadata, true)
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format("%s - %s", classfmt(class, label), KILLING_BLOWS)
	end

	function mode_target:Update(win, set)
		win.title = uformat("%s - %s", classfmt(win.actorclass, win.actorname), KILLING_BLOWS)
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
			format_valuetext(d, total, win.metadata, true)
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
				format_valuetext(d, total, win.metadata)
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

	function mode_target:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		if not actor or not actor.kill then return end
		return actor.kill, Skada:FormatNumber(actor.kill)
	end

	function mode:GetSetSummary(set, win)
		if not set then return end
		local value = set:GetTotal(win and win.class, nil, "kill") or 0
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
			columns = {Count = true, Percent = true, sPercent = false},
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

	function mode:OnInitialize()
		M.killchannel = M.killchannel or "SAY"

		O.modules.args.killbow = {
			type = "group",
			name = self.localeName,
			desc = format(L["Options for %s."], self.localeName),
			args = {
				header = {
					type = "description",
					name = self.localeName,
					fontSize = "large",
					image = [[Interface\ICONS\ability_creature_cursed_02]],
					imageWidth = 18,
					imageHeight = 18,
					imageCoords = Skada.cropTable,
					width = "full",
					order = 0
				},
				empty_1 = {
					type = "description",
					name = " ",
					width = "full",
					order = 1
				},
				killpvponly = {
					type = "toggle",
					name = L["Only PvP Kills"],
					desc = L["When enabled, only kills against enemy players count."],
					descStyle = "inline",
					width = "full",
					order = 2
				},
				killannounce = {
					type = "toggle",
					name = format(L["Announce %s"], KILLING_BLOWS),
					desc = L["Announce killing blows after combat ends. Only works for boss fights."],
					descStyle = "inline",
					width = "full",
					order = 3
				},
				killchannel = {
					type = "select",
					name = L["Channel"],
					values = {AUTO = L["Instance"], SAY = L["Say"], YELL = L["Yell"], SELF = L["Self"]},
					order = 4,
					width = "full"
				},
			}
		}
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
