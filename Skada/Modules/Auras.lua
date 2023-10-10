local _, Skada = ...
local Private = Skada.Private
local L = Skada.Locale

-- frequently used global (sort of...)
local pairs, format, uformat = pairs, string.format, Private.uformat
local time, min, floor = time, math.min, math.floor

-- common functions and locals
local new, del, clear = Private.newTable, Private.delTable, Private.clearTable
local ignored_buffs, ignored_debuffs -- Edit Skada\Core\Tables.lua
local aura, tooltip_school

---------------------------------------------------------------------------
-- Parent Module - Handles common stuff

do
	local main = Skada:NewModule("Buffs and Debuffs")
	local band, next, wipe = bit.band, next, wipe
	local player_flag, enemy_flag = 0x02, 0x04
	local player_clear, enemy_clear = false, false
	local main_flag = 0

	function main:OnEnable()
		if not Skada:IsDisabled("Buffs") or not Skada:IsDisabled("Debuffs") then
			main_flag = main_flag + player_flag
		end
		if not Skada:IsDisabled("Enemy Buffs") or not Skada:IsDisabled("Enemy Debuffs") then
			main_flag = main_flag + enemy_flag
		end

		if main_flag == 0 then return end

		aura = {}
		tooltip_school = Skada.tooltip_school
		Skada.RegisterCallback(self, "Skada_SetComplete", "Clean")

		-- what can be cleaned?
		player_clear = (band(main_flag, player_flag) ~= 0)
		enemy_clear = (band(main_flag, enemy_flag) ~= 0)

		ignored_buffs = Skada.ignored_spells.buff
		ignored_debuffs = Skada.ignored_spells.debuff
	end

	function main:OnDisable()
		Skada.UnregisterAllCallbacks(self)
	end

	local function can_clear_actor(actor)
		if not actor or not actor.auras then
			return false
		elseif actor.enemy and not enemy_clear then
			return false
		elseif not actor.enemy and not player_clear then
			return false
		else
			return true
		end
	end

	local function clear_actor_table(actor, curtime, maxtime)
		if not can_clear_actor(actor) then return end

		for spellid, spell in pairs(actor.auras) do
			if spell.a and spell.a > 0 and spell.s then
				spell.u = min(maxtime, spell.u + floor((curtime - spell.s) + 0.5))
			end
			-- remove temporary keys
			spell.a, spell.s = nil, nil

			if spell.u == 0 then
				-- remove spell with 0 uptime.
				actor.auras[spellid] = del(actor.auras[spellid], true)
			elseif spell.t then
				-- debuff targets
				for name, target in pairs(spell.t) do
					if target.a and target.a > 0 and target.s then
						target.u = min(spell.u, target.u + floor((curtime - target.s) + 0.5))
					end
					-- remove temporary keys
					target.a, target.s = nil, nil

					-- remove targets with 0 uptime.
					if target.u == 0 then
						spell.t[name] = del(spell.t[name])
					end
				end

				-- an empty targets table? Remove it
				if next(spell.t) == nil then
					actor.auras[spellid] = del(actor.auras[spellid])
				end
			end
		end

		-- remove table if no auras left
		if next(actor.auras) == nil then
			actor.auras = del(actor.auras)
		end
	end

	function main:Clean(_, set, curtime)
		wipe(aura) -- empty aura table first

		local actors = set and set.actors
		if not actors then return end

		local maxtime = set and set:GetTime()
		curtime = curtime or Skada._time or time()

		for _, actor in pairs(actors) do
			clear_actor_table(actor, curtime, maxtime)
		end
	end
end

---------------------------------------------------------------------------
-- Common functions

local format_valuetext
local log_auraapplied, log_aurarefresh, log_auraremove, log_specialaura
local main_update_func, spell_update_func, target_update_func
local spelltarget_update_func, targetspell_update_func
local spell_tooltip, spelltarget_tooltip

-- list of spells that don't trigger SPELL_AURA_x events
local special_buffs = {
	[57669] = true -- Replenishment
}

do
	local SpellSplit = Private.SpellSplit
	local PercentToRGB = Private.PercentToRGB

	-- formats value texts
	function format_valuetext(d, cols, count, maxtime, metadata, subview, no_order)
		d.valuetext = Skada:FormatValueCols(
			cols.Uptime and Skada:FormatTime(d.value),
			cols.Count and Skada:FormatNumber(count),
			cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, maxtime)
		)

		if not no_order and metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function find_or_create_actor(set, info)
		-- 1. make sure we can record to the segment.
		if not set or (set == Skada.total and not Skada.profile.totalidc) then return end

		-- 2. make sure we have valid data.
		if not info or not info.spellid then return end

		-- 3. retrieve the actor.
		return Skada:GetActor(set, info.actorname, info.actorid, info.actorflags)
	end

	-- handles SPELL_AURA_APPLIED event
	function log_auraapplied(set, curtime)
		local actor = find_or_create_actor(set, aura)
		if not actor then return end

		curtime = curtime or Skada._time or time()
		local spell = actor.auras and actor.auras[aura.spellid]
		if not spell then
			actor.auras = actor.auras or {}
			actor.auras[aura.spellid] = {u = 0, n = 1, a = 1, s = curtime}
			spell = actor.auras[aura.spellid]
		else
			spell.n = (spell.n or 0) + 1
			spell.a = (spell.a or 0) + 1
			spell.s = spell.s or curtime
		end

		-- only record targets for debuffs
		local name = aura.type == "DEBUFF" and aura.dstName
		if not name then return end

		local target = spell.t and spell.t[name]
		if not target then
			spell.t = spell.t or {}
			spell.t[name] = {u = 0, n = 1, a = 1, s = curtime}
		else
			target.a = (target.a or 0) + 1
			target.n = (target.n or 0) + 1
			target.s = target.s or curtime
		end
	end

	-- handles SPELL_AURA_REFRESH and SPELL_AURA_APPLIED_DOSE events
	function log_aurarefresh(set)
		local actor = find_or_create_actor(set, aura)
		if not actor then return end

		-- spell
		local spell = actor.auras and actor.auras[aura.spellid]
		if not spell or not spell.a or spell.a == 0 then return end
		spell.r = (spell.r or 0) + 1

		-- target
		local target = spell.t and aura.dstName and spell.t[aura.dstName]
		if not target or not target.a or target.a == 0 then return end
		target.r = (target.r or 0) + 1
	end

	-- handles SPELL_AURA_REMOVED event
	function log_auraremove(set)
		local actor = find_or_create_actor(set, aura)
		if not actor then return end

		-- spell
		local spell = actor.auras and actor.auras[aura.spellid]
		if not spell or not spell.a or spell.a == 0 then return end

		local curtime = Skada._time or time()
		spell.a = spell.a - 1
		if spell.a == 0 and spell.s then
			spell.u = spell.u + floor((curtime - spell.s) + 0.5)
			spell.s = nil
		end

		-- target
		local target = spell.t and aura.dstName and spell.t[aura.dstName]
		if not target or not target.a or target.a == 0 then return end

		target.a = target.a - 1
		if target.a == 0 and target.s then
			target.u = target.u + floor((curtime - target.s) + 0.5)
			target.s = nil
		end
	end

	function log_specialaura(set)
		local actor = find_or_create_actor(set, aura)
		if not actor then return end

		-- spell
		local spell = actor.auras and actor.auras[aura.spellid]
		if not spell then
			actor.auras = actor.auras or {}
			actor.auras[aura.spellid] = {u = 1}
		else
			spell.u = (spell.u or 0) + 1
		end
	end

	do
		-- counts auras by the given type
		local function count_auras_by_type(spells, auratype)
			if not spells then return end

			local count, uptime = 0, 0
			for id, spell in pairs(spells) do
				local spellid = SpellSplit(id)
				if (auratype == "BUFF" and spellid > 0) or (auratype == "DEBUFF" and spellid < 0) then
					count = count + 1
					uptime = uptime + (spell.u or spell.uptime)
				end
			end
			return count, uptime
		end

		-- whether to show the actor or not (player/enemy)
		local function should_show_actor(win, actor, set, is_enemy)
			if not actor or not actor.auras then
				return false
			elseif is_enemy and not actor.enemy then
				return false
			elseif not is_enemy and actor.enemy then
				return false
			else
				return win:show_actor(actor, set)
			end
		end

		-- module's main update function.
		function main_update_func(self, auratype, win, set, cols, is_enemy)
			local settime = auratype and set and set:GetTime()
			if not settime or settime == 0 then return end

			local actors = set.actors
			if not actors then
				return
			elseif win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for actorname, actor in pairs(actors) do
				if should_show_actor(win, actor, set, is_enemy) then
					local count, uptime = count_auras_by_type(actor.auras, auratype)
					if count and count > 0 and uptime > 0 then
						nr = nr + 1

						local d = win:actor(nr, actor, actor.enemy, actorname)
						local maxtime = floor(actor:GetTime(set))
						d.value = min(floor(uptime / count), maxtime)
						format_valuetext(d, cols, count, maxtime, win.metadata)
					end
				end
			end
		end
	end

	-- list actor's auras by type
	function spell_update_func(self, auratype, win, set, cols)
		local actor = set and auratype and set:GetActor(win.actorname, win.actorid)
		local maxtime = actor and floor(actor:GetTime(set))
		local spells = (maxtime and maxtime > 0) and actor.auras

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for id, spell in pairs(spells) do
			local spellid = SpellSplit(id)
			local spell_u = spell.u or spell.uptime
			if
				(auratype == "BUFF" and spellid > 0 and spell_u > 0) or
				(auratype == "DEBUFF" and spellid < 0 and spell_u > 0)
			then
				nr = nr + 1

				local d = win:spell(nr, id, false)
				d.value = min(maxtime, spell_u)
				format_valuetext(d, cols, spell.n, maxtime, win.metadata, true)
			end
		end
	end

	local function new_aura_table(info)
		local t = new()
		t.n = info.n or info.count
		t.r = info.r or info.refresh
		t.u = info.u or info.uptime
		return t
	end

	do
		local function get_actor_auras_targets(self, set, auratype, tbl)
			local spells = set and auratype and self.auras
			if not spells then return end

			tbl = clear(tbl)
			local maxtime = 0
			for _, spell in pairs(spells) do
				local targets = spell.t or spell.targets
				if targets then
					maxtime = maxtime + (spell.u or spell.uptime)
					for name, target in pairs(targets) do
						local t = tbl[name]
						if not t then
							t = new_aura_table(target)
							tbl[name] = t
						else
							t.n = t.n + (target.n or target.count)
							t.u = t.u + (target.u or target.uptime)
							if target.r or target.refresh then
								t.r = (t.r or 0) + (target.r or target.refresh)
							end
						end

						set:_fill_actor_table(t, name)
					end
				end
			end

			return tbl, maxtime
		end

		-- list actor's auras targets by type
		function target_update_func(self, auratype, win, set, cols, tbl)
			local actor = set and auratype and set:GetActor(win.actorname, win.actorid)
			if not actor then return end

			local targets, maxtime = get_actor_auras_targets(actor, set, auratype, tbl)
			if not targets or maxtime == 0 then
				return
			elseif win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for name, target in pairs(targets) do
				nr = nr + 1

				local d = win:actor(nr, target, target.enemy, name)
				d.value = target.u
				format_valuetext(d, cols, target.n, maxtime, win.metadata, true)
			end
		end
	end

	do
		local function get_actor_aura_targets(self, set, spellid, tbl)
			local spell = set and spellid and self.auras and self.auras[spellid]
			local targets = spell and (spell.t or spell.targets)
			if not targets then return end

			tbl = clear(tbl)
			for name, target in pairs(targets) do
				tbl[name] = new_aura_table(target)
				set:_fill_actor_table(tbl[name], name)
			end
			return tbl, spell.u or spell.uptime
		end

		-- list targets of the given aura
		function spelltarget_update_func(self, auratype, win, set, cols, tbl)
			local actor = set and auratype and set:GetActor(win.actorname, win.actorid)
			if not actor then return end

			local targets, maxtime = get_actor_aura_targets(actor, set, win.spellid, tbl)
			if not targets or maxtime == 0 then
				return
			elseif win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for name, target in pairs(targets) do
				nr = nr + 1

				local d = win:actor(nr, target, target.enemy, name)
				d.value = min(target.u or target.uptime, maxtime)
				format_valuetext(d, cols, target.n or target.count, maxtime, win.metadata, true)
			end
		end
	end

	do
		local function get_actor_target_auras(self, name, tbl)
			local spells = name and self.auras
			if not spells then return end

			tbl = clear(tbl)
			local maxtime = 0
			for spellid, spell in pairs(spells) do
				local target = (spell.t and spell.t[name]) or (spell.targets and spell.targets[name])
				local uptime = target and (target.u or target.uptime)
				if uptime then
					maxtime = maxtime + uptime
					tbl[spellid] = new_aura_table(target)
				end
			end

			return tbl, maxtime
		end

		-- list auras done on the given target
		function targetspell_update_func(self, auratype, win, set, cols, tbl)
			local actor = set and auratype and set:GetActor(win.actorname, win.actorid)
			if not actor then return end

			local spells, maxtime = get_actor_target_auras(actor, win.targetname, tbl)
			if not spells or maxtime == 0 then
				return
			elseif win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(spells) do
				nr = nr + 1

				local d = win:spell(nr, spellid, false)
				d.value = spell.u
				format_valuetext(d, cols, spell.n, maxtime, win.metadata, true)
			end
		end
	end

	function spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local settime = set and set:GetTime()
		if not settime or settime == 0 then return end
		local actor = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.auras and actor.auras[id]
		if not spell then return end

		tooltip:AddLine(uformat("%s - %s", Skada.classcolors.format(actor.class, win.actorname), label))
		tooltip_school(tooltip, id)

		local cast = actor.GetSpellCast and actor:GetSpellCast(id)
		if cast then
			tooltip:AddDoubleLine(L["Casts"], cast, 1, 1, 1)
		end

		local spell_n = spell.n or spell.count
		if spell_n then
			tooltip:AddDoubleLine(L["Count"], spell_n, nil, nil, nil, 1, 1, 1)
		end

		local spell_r = spell.r or spell.refresh
		if spell_r then
			tooltip:AddDoubleLine(L["Refresh"], spell_r, nil, nil, nil, 1, 1, 1)
		end

		-- add segment and active times
		local spell_u = spell.u or spell.uptime
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(actor:GetTime(set, true)), 1, 1, 1)
		tooltip:AddDoubleLine(L["Duration"], Skada:FormatTime(spell_u), 1, 1, 1)

		-- display aura uptime in colored percent
		local uptime = 100 * (spell_u / actor:GetTime(set))
		tooltip:AddDoubleLine(L["Uptime"], Skada:FormatPercent(uptime), nil, nil, nil, PercentToRGB(uptime, actor.enemy))
	end

	function spelltarget_tooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.auras and actor.auras[win.spellid]
		local target = spell and spell.t and spell.t[label]
		if not target then return end

		tooltip:AddLine(uformat("%s - %s", Skada.classcolors.format(actor.class, win.actorname), win.spellname))
		tooltip_school(tooltip, win.spellid)

		if target.n then
			tooltip:AddDoubleLine(L["Count"], target.n, 1, 1, 1)
		end
		if target.r then
			tooltip:AddDoubleLine(L["Refresh"], target.r, 1, 1, 1)
		end
	end
end

---------------------------------------------------------------------------
-- Buffs Module

Skada:RegisterModule("Buffs", function(_, P, G, C)
	local mode = Skada:NewModule("Buffs")
	local mode_spell = mode:NewModule("Spell List")
	local mode_spell_target = mode_spell:NewModule("Target List")
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function handle_buff(t)
		if t.__temp or (t.spellid and not ignored_buffs[t.spellid] and t.spellstring and (t.auratype == "BUFF" or special_buffs[t.spellid])) then
			aura.actorid = t.dstGUID
			aura.actorname = t.dstName
			aura.actorflags = t.dstFlags
			aura.dstName = nil

			aura.spellid = t.spellstring
			aura.type = t.auratype

			if t.event == "SPELL_PERIODIC_ENERGIZE" then
				Skada:DispatchSets(log_specialaura)
			elseif t.event == "SPELL_AURA_APPLIED" then
				Skada:DispatchSets(log_auraapplied, t.curtime)
			elseif t.event == "SPELL_AURA_REMOVED" then
				Skada:DispatchSets(log_auraremove)
			else
				Skada:DispatchSets(log_aurarefresh)
			end
		end
	end

	function mode_spell_target:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's targets"], label)
	end

	do
		local function new_actor_table(info)
			local t = new()
			t.id = info.id
			t.class = info.class
			t.role = info.role
			t.spec = info.spec
			t.enemy = info.enemy
			return t
		end

		local function get_aura_targets(self, spellid, tbl)
			local actors = spellid and self.actors
			if not actors then return end

			tbl = clear(tbl or C)
			for actorname, actor in pairs(actors) do
				local spell = not actor.enemy and actor.auras and actor.auras[spellid]
				if spell then
					local t = new_actor_table(actor)
					t.n = spell.n
					t.m = floor(actor:GetTime(self))
					t.u = min(t.m, spell.u or spell.uptime)
					tbl[actorname] = t
				end
			end
			return tbl
		end

		function mode_spell_target:Update(win, set)
			win.title = uformat(L["%s's targets"], win.spellname)

			local targets = get_aura_targets(set, win.spellid)
			if not targets then
				return
			elseif win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for name, target in pairs(targets) do
				nr = nr + 1

				local d = win:actor(nr, target, target.enemy, name)
				d.value = target.u
				format_valuetext(d, mode_cols, target.n, target.m, win.metadata, true)
			end
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["%s's spells"], classfmt(win.actorclass, win.actorname))
		spell_update_func(self, "BUFF", win, set, mode_cols)
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Buffs"], L[win.class]) or L["Buffs"]
		main_update_func(self, "BUFF", win, set, mode_cols)
	end

	do
		-- per-session spell strings cache
		local spellstrings = G.spellstrings or {}
		G.spellstrings = spellstrings

		local cache_events = {SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true}
		Skada:RegisterCallback("Skada_SpellString", function(_, t, spellid, spellstring)
			if cache_events[t.event] and t.auratype == "BUFF" and not spellstrings[spellid] then
				spellstrings[spellid] = spellstring
			end
		end)

		function mode:UnitBuff(_, args)
			if args.owner or not args.auras then return end

			local dstGUID, dstName, dstFlags = args.dstGUID, args.dstName, args.dstFlags
			for _, aura in pairs(args.auras) do
				local t = new()
				t.event = args.event
				t.dstGUID = dstGUID
				t.dstName = dstName
				t.dstFlags = dstFlags
				t.spellid = aura.id
				t.spellstring = spellstrings[aura.id]
				t.auratype = "BUFF"
				t.__temp = true
				handle_buff(t)
				t = del(t)
			end
		end
	end

	function mode:OnEnable()
		mode_spell_target.metadata = {showspots = true, ordersort = true, tooltip = spelltarget_tooltip}
		mode_spell.metadata = {valueorder = true, tooltip = spell_tooltip, click1 = mode_spell_target}
		self.metadata = {
			filterclass = true,
			click1 = mode_spell,
			columns = {Uptime = true, Count = false, Percent = true, sPercent = true},
			icon = [[Interface\ICONS\spell_holy_divinespirit]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true

		Skada:RegisterForCL(
			handle_buff,
			{dst_is_interesting_nopets = true},
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_APPLIED_DOSE",
			"SPELL_PERIODIC_ENERGIZE"
		)

		Skada.RegisterCallback(self, "Skada_UnitBuffs", "UnitBuff")
		Skada:AddMode(self, "Buffs and Debuffs")
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end
end)

---------------------------------------------------------------------------
-- Debuffs Module

Skada:RegisterModule("Debuffs", function(_, _, _, C)
	local mode = Skada:NewModule("Debuffs")
	local mode_spell = mode:NewModule("Spell List")
	local mode_spell_target = mode_spell:NewModule("Target List")
	local mode_spell_source = mode_spell:NewModule("Source List")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function handle_debuff(t)
		if t.auratype ~= "DEBUFF" or not t.spellid or ignored_debuffs[t.spellid] then return end

		aura.actorid = t.srcGUID
		aura.actorname = t.srcName
		aura.actorflags = t.srcFlags
		aura.dstName = Skada:FixPetsName(t.dstGUID, t.dstName, t.dstFlags)

		aura.spellid = t.spellstring
		aura.type = t.auratype
		Skada:FixPets(aura)

		if t.event == "SPELL_AURA_APPLIED" then
			Skada:DispatchSets(log_auraapplied)
		elseif t.event == "SPELL_AURA_REMOVED" then
			Skada:DispatchSets(log_auraremove)
		else
			Skada:DispatchSets(log_aurarefresh)
		end
	end

	function mode_target_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label or L["Unknown"], class
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(class, win.targetname))
	end

	function mode_target_spell:Update(win, set)
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(win.targetclass, win.targetname))
		targetspell_update_func(self, "DEBUFF", win, set, mode_cols, C)
	end

	function mode_spell_target:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> targets"], classfmt(win.actorclass, win.actorname), label)
	end

	function mode_spell_target:Update(win, set)
		win.title = uformat(L["%s's <%s> targets"], classfmt(win.actorclass, win.actorname), win.spellname)
		spelltarget_update_func(self, "DEBUFF", win, set, mode_cols, C)
	end

	function mode_spell_source:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's sources"], label)
	end

	function mode_spell_source:Update(win, set)
		win.title = uformat(L["%s's sources"], win.spellname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		if not win.spellid then return end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			local auras = win:show_actor(actor, set, true) and not actor.enemy and actor.auras
			local spell = auras and auras[win.spellid]
			if spell then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = spell.u
				format_valuetext(d, mode_cols, spell.n, actor:GetTime(set), win.metadata, true, true)
			end
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))
		target_update_func(self, "DEBUFF", win, set, mode_cols, C)
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["%s's spells"], classfmt(win.actorclass, win.actorname))
		spell_update_func(self, "DEBUFF", win, set, mode_cols)
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Debuffs"], L[win.class]) or L["Debuffs"]
		main_update_func(self, "DEBUFF", win, set, mode_cols)
	end

	local function spellsource_tooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		local spell = actor and actor.auras and actor.auras[win.spellid]
		if not (spell and spell.n) then return end

		tooltip:AddLine(uformat("%s - %s", classfmt(actor.class, label), win.spellname))
		tooltip_school(tooltip, win.spellid)

		tooltip:AddDoubleLine(L["Count"], spell.n, 1, 1, 1)
		if spell.r then
			tooltip:AddDoubleLine(L["Refresh"], spell.r, 1, 1, 1)
		end
	end

	function mode:OnEnable()
		mode_spell_source.metadata = {
			filterclass = true,
			tooltip = spellsource_tooltip
		}

		mode_spell_target.metadata = {tooltip = spelltarget_tooltip}
		mode_spell.metadata = {click1 = mode_spell_target, click2 = mode_spell_source, tooltip = spell_tooltip}
		mode_target.metadata = {click1 = mode_target_spell}
		self.metadata = {
			filterclass = true,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Uptime = true, Count = false, Percent = true, sPercent = true},
			icon = [[Interface\ICONS\spell_shadow_shadowwordpain]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		Skada:RegisterForCL(
			handle_debuff,
			{src_is_interesting = true},
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_APPLIED_DOSE"
		)

		Skada:AddMode(self, "Buffs and Debuffs")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end)

---------------------------------------------------------------------------
-- Enemy Buffs Module

Skada:RegisterModule("Enemy Buffs", function(_, P, _, C)
	local mode = Skada:NewModule("Enemy Buffs")
	local mode_spell = mode:NewModule("Spell List")
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function handle_buff(t)
		if t.spellid and not ignored_buffs[t.spellid] and (t.auratype == "BUFF" or special_buffs[t.spellid]) then
			aura.actorid = t.dstGUID
			aura.actorname = t.dstName
			aura.actorflags = t.dstFlags
			aura.dstName = nil

			aura.spellid = t.spellstring
			aura.type = t.auratype

			if t.event == "SPELL_PERIODIC_ENERGIZE" then
				Skada:DispatchSets(log_specialaura)
			elseif t.event == "SPELL_AURA_APPLIED" then
				Skada:DispatchSets(log_auraapplied)
			elseif t.event == "SPELL_AURA_REMOVED" then
				Skada:DispatchSets(log_auraremove)
			else
				Skada:DispatchSets(log_aurarefresh)
			end
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["%s's spells"], classfmt(win.actorclass, win.actorname))
		spell_update_func(self, "BUFF", win, set, mode_cols)
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Enemy Buffs"], L[win.class]) or L["Enemy Buffs"]
		main_update_func(self, "BUFF", win, set, mode_cols, true)
	end

	function mode:OnEnable()
		mode_spell.metadata = {valueorder = true, tooltip = spell_tooltip}
		self.metadata = {
			filterclass = true,
			click1 = mode_spell,
			columns = {Uptime = true, Count = false, Percent = true, sPercent = true},
			icon = [[Interface\ICONS\ability_paladin_beaconoflight]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true

		Skada:RegisterForCL(
			handle_buff,
			{src_is_not_interesting = true, dst_is_not_interesting = true},
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_APPLIED_DOSE",
			"SPELL_PERIODIC_ENERGIZE"
		)

		Skada:AddMode(self, "Enemies")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end)

---------------------------------------------------------------------------
-- Enemy Debuffs Module

Skada:RegisterModule("Enemy Debuffs", function(_, _, _, C)
	local mode = Skada:NewModule("Enemy Debuffs")
	local mode_spell = mode:NewModule("Spell List")
	local mode_spell_target = mode_spell:NewModule("Target List")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local function handle_debuff(t)
		if t.auratype ~= "DEBUFF" or not t.spellid or ignored_debuffs[t.spellid] then return end

		aura.actorid = t.srcGUID
		aura.actorname = t.srcName
		aura.actorflags = t.srcFlags
		aura.dstName = Skada:FixPetsName(t.dstGUID, t.dstName, t.dstFlags)

		aura.spellid = t.spellstring
		aura.type = t.auratype

		if t.event == "SPELL_AURA_APPLIED" then
			Skada:DispatchSets(log_auraapplied)
		elseif t.event == "SPELL_AURA_REMOVED" then
			Skada:DispatchSets(log_auraremove)
		else
			Skada:DispatchSets(log_aurarefresh)
		end
	end

	function mode_target_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label or L["Unknown"], class
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(class, win.targetname))
	end

	function mode_target_spell:Update(win, set)
		win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(win.targetclass, win.targetname))
		targetspell_update_func(self, "DEBUFF", win, set, mode_cols, C)
	end

	function mode_spell_target:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> targets"], classfmt(win.actorclass, win.actorname), label)
	end

	function mode_spell_target:Update(win, set)
		win.title = uformat(L["%s's <%s> targets"], classfmt(win.actorclass, win.actorname), win.spellname)
		spelltarget_update_func(self, "DEBUFF", win, set, mode_cols, C)
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = uformat(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))
		target_update_func(self, "DEBUFF", win, set, mode_cols, C)
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = format(L["%s's spells"], classfmt(win.actorclass, win.actorname))
		spell_update_func(self, "DEBUFF", win, set, mode_cols)
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Enemy Debuffs"], L[win.class]) or L["Enemy Debuffs"]
		main_update_func(self, "DEBUFF", win, set, mode_cols, true)
	end

	function mode:OnEnable()
		mode_spell_target.metadata = {tooltip = spelltarget_tooltip}
		mode_spell.metadata = {click1 = mode_spell_target, tooltip = spell_tooltip}
		mode_target.metadata = {click1 = mode_target_spell}
		self.metadata = {
			filterclass = true,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Uptime = true, Count = false, Percent = true, sPercent = true},
			icon = [[Interface\ICONS\ability_warlock_improvedsoulleech]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		Skada:RegisterForCL(
			handle_debuff,
			{src_is_not_interesting = true, dst_is_interesting = true},
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_APPLIED_DOSE"
		)

		Skada:AddMode(self, "Enemies")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end)
