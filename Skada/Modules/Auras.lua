local folder, Skada = ...
local Private = Skada.Private
local L = LibStub("AceLocale-3.0"):GetLocale(folder)

-- frequently used global (sort of...)
local pairs, format, uformat = pairs, string.format, Private.uformat
local time, min, floor = time, math.min, math.floor
local _

-- common functions and locals
local new, del, clear = Private.newTable, Private.delTable, Private.clearTable
local ignored_buffs = Skada.dummyTable -- Edit Skada\Core\Tables.lua
local ignored_debuffs = Skada.dummyTable -- Edit Skada\Core\Tables.lua
local aura, spellschools

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
		spellschools = Skada.spellschools
		Skada.RegisterCallback(self, "Skada_SetComplete", "Clean")

		-- what can be cleaned?
		player_clear = (band(main_flag, player_flag) ~= 0)
		enemy_clear = (band(main_flag, enemy_flag) ~= 0)

		if Skada.ignoredSpells then
			ignored_buffs = Skada.ignoredSpells.buffs or ignored_buffs
			ignored_debuffs = Skada.ignoredSpells.debuffs or ignored_debuffs
		end
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
			if spell.active ~= nil and spell.start then
				spell.uptime = min(maxtime, spell.uptime + floor((curtime - spell.start) + 0.5))
			end
			-- remove temporary keys
			spell.active, spell.start = nil, nil

			if spell.uptime == 0 then
				-- remove spell with 0 uptime.
				actor.auras[spellid] = del(actor.auras[spellid], true)
			elseif spell.targets then
				-- debuff targets
				for name, target in pairs(spell.targets) do
					if target.active ~= nil and target.start then
						target.uptime = min(spell.uptime, target.uptime + floor((curtime - target.start) + 0.5))
					end

					-- remove targets with 0 uptime.
					if target.uptime == 0 then
						spell.targets[name] = del(spell.targets[name])
					else
						-- remove temporary keys
						target.active, target.start = nil, nil
					end
				end

				-- an empty targets table? Remove it
				if next(spell.targets) == nil then
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
		curtime = curtime or set.last_action or time()

		for i = 1, #actors do
			clear_actor_table(actors[i], curtime, maxtime)
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

	local function find_or_create_actor(set, info, is_enemy)
		-- 1. make sure we can record to the segment.
		if not set or (set == Skada.total and not Skada.db.profile.totalidc) then return end

		-- 2. make sure we have valid data.
		if not info or not info.spellid then return end

		-- 3. retrieve the actor.
		if is_enemy then -- enemy?
			return Skada:GetEnemy(set, info.actorname, info.actorid, info.actorflags, true)
		end

		return Skada:GetPlayer(set, info.actorid, info.actorname, info.actorflags) -- player?
	end

	-- handles SPELL_AURA_APPLIED event
	function log_auraapplied(set, is_enemy)
		local actor = find_or_create_actor(set, aura, is_enemy)
		if not actor then return end

		local curtime = set.last_action or time()
		local spell = actor.auras and actor.auras[aura.spellid]
		if not spell then
			actor.auras = actor.auras or {}
			actor.auras[aura.spellid] = {school = aura.school, uptime = 0, count = 1, active = 1, start = curtime}
			spell = actor.auras[aura.spellid]
		else
			spell.active = (spell.active or 0) + 1
			spell.count = (spell.count or 0) + 1
			spell.start = spell.start or curtime

			-- fix missing school
			if not spell.school and aura.school then
				spell.school = aura.school
			end
		end

		-- only record targets for debuffs
		if aura.spellid > 0 or not aura.dstName then return end

		local target = spell.targets and spell.targets[aura.dstName]
		if not target then
			spell.targets = spell.targets or {}
			spell.targets[aura.dstName] = {uptime = 0, count = 1, active = 1, start = curtime}
		else
			target.active = (target.active or 0) + 1
			target.count = (target.count or 0) + 1
			target.start = target.start or curtime
		end
	end

	-- handles SPELL_AURA_REFRESH and SPELL_AURA_APPLIED_DOSE events
	function log_aurarefresh(set, is_enemy)
		local actor = find_or_create_actor(set, aura, is_enemy)
		if not actor then return end

		-- spell
		local spell = actor.auras and actor.auras[aura.spellid]
		if not spell or not spell.active or spell.active == 0 then return end
		spell.refresh = (spell.refresh or 0) + 1

		-- target
		local target = spell.targets and aura.dstName and spell.targets[aura.dstName]
		if not target or not target.active or target.active == 0 then return end
		target.refresh = (target.refresh or 0) + 1
	end

	-- handles SPELL_AURA_REMOVED event
	function log_auraremove(set, is_enemy)
		local actor = find_or_create_actor(set, aura, is_enemy)
		if not actor then return end

		-- spell
		local spell = actor.auras and actor.auras[aura.spellid]
		if not spell or not spell.active or spell.active == 0 then return end

		local curtime = set.last_action or time()
		spell.active = spell.active - 1
		if spell.active == 0 and spell.start then
			spell.uptime = spell.uptime + floor((curtime - spell.start) + 0.5)
			spell.start = nil
		end

		-- target
		local target = spell.targets and aura.dstName and spell.targets[aura.dstName]
		if not target or not target.active or target.active == 0 then return end

		target.active = target.active - 1
		if target.active == 0 and target.start then
			target.uptime = target.uptime + floor((curtime - target.start) + 0.5)
			target.start = nil
		end
	end

	function log_specialaura(set, is_enemy)
		local actor = find_or_create_actor(set, aura, is_enemy)
		if not actor then return end

		-- spell
		local spell = actor.auras and actor.auras[aura.spellid]
		if not spell then
			actor.auras = actor.auras or {}
			actor.auras[aura.spellid] = {school = aura.school, uptime = 1}
		else
			spell.uptime = (spell.uptime or 0) + 1

			-- fix missing school
			if not spell.school and aura.school then
				spell.school = aura.school
			end
		end
	end

	do
		-- counts auras by the given type
		local function count_auras_by_type(spells, auratype)
			if not spells then return end

			local count, uptime = 0, 0
			for spellid, spell in pairs(spells) do
				-- fix old data
				if spell.type then
					if spell.type == "DEBUFF" and spellid > 0 then
						local sid = spellid
						spellid = -spellid
						spells[spellid] = spell
						spells[sid] = nil
					end
					spell.type = nil
				end
				if (auratype == "BUFF" and spellid > 0) or (auratype == "DEBUFF" and spellid < 0) then
					count = count + 1
					uptime = uptime + spell.uptime
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
			for i = 1, #actors do
				local actor = actors[i]
				if should_show_actor(win, actor, set, is_enemy) then
					local count, uptime = count_auras_by_type(actor.auras, auratype)
					if count and count > 0 and uptime > 0 then
						nr = nr + 1

						local d = win:actor(nr, actor, actor.enemy)
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
		for spellid, spell in pairs(spells) do
			if
				(auratype == "BUFF" and spellid > 0 and spell.uptime > 0) or
				(auratype == "DEBUFF" and spellid < 0 and spell.uptime > 0)
			then
				nr = nr + 1

				local d = win:spell(nr, spellid, spell, nil, nil, true)
				d.value = min(maxtime, spell.uptime)
				format_valuetext(d, cols, spell.count, maxtime, win.metadata, true)
			end
		end
	end

	local function new_aura_table(info)
		local t = new()
		t.count = info.count
		t.refresh = info.refresh
		t.uptime = info.uptime
		t.school = info.school
		return t
	end

	do
		local function get_actor_auras_targets(self, set, auratype, tbl)
			local spells = set and auratype and self.auras
			if not spells then return end

			tbl = clear(tbl)
			local maxtime = 0
			for _, spell in pairs(spells) do
				if spell.targets then
					maxtime = maxtime + spell.uptime
					for name, target in pairs(spell.targets) do
						local t = tbl[name]
						if not t then
							t = new_aura_table(target)
							tbl[name] = t
						else
							t.count = t.count + target.count
							t.uptime = t.uptime + target.uptime
							if target.refresh then
								t.refresh = (t.refresh or 0) + target.refresh
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
				d.value = target.uptime
				format_valuetext(d, cols, target.count, maxtime, win.metadata, true)
			end
		end
	end

	do
		local function get_actor_aura_targets(self, set, spellid, tbl)
			local spell = set and spellid and self.auras and self.auras[spellid]
			local targets = spell and spell.targets
			if not targets then return end

			tbl = clear(tbl)
			for name, target in pairs(targets) do
				tbl[name] = new_aura_table(target)
				set:_fill_actor_table(tbl[name], name)
			end
			return tbl, spell.uptime
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
				d.value = min(target.uptime, maxtime)
				format_valuetext(d, cols, target.count, maxtime, win.metadata, true)
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
				local target = spell.targets and spell.targets[name]
				local uptime = target and target.uptime
				if uptime then
					maxtime = maxtime + uptime
					tbl[spellid] = new_aura_table(spell.targets[name])
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

				local d = win:spell(nr, spellid, spell, nil, nil, true)
				d.value = spell.uptime
				format_valuetext(d, cols, spell.count, maxtime, win.metadata, true)
			end
		end
	end

	function spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local settime = set and set:GetTime()
		if not settime or settime == 0 then return end
		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.auras and actor.auras[id]
		if not spell then return end

		tooltip:AddLine(format("%s: %s", actor.name, label))
		if spell.school and spellschools and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if spell.count or spell.refresh then
			if spell.count then
				tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
			end
			if spell.refresh then
				tooltip:AddDoubleLine(L["Refresh"], spell.refresh, 1, 1, 1)
			end
			tooltip:AddLine(" ")
		end

		-- add segment and active times
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(actor:GetTime(set, true)), 1, 1, 1)
		tooltip:AddDoubleLine(L["Duration"], Skada:FormatTime(spell.uptime), 1, 1, 1)

		-- display aura uptime in colored percent
		local uptime = 100 * (spell.uptime / actor:GetTime(set))
		tooltip:AddDoubleLine(L["Uptime"], Skada:FormatPercent(uptime), nil, nil, nil, PercentToRGB(uptime, enemy))
	end

	function spelltarget_tooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.auras and actor.auras[win.spellid]
		local target = spell and spell.targets and spell.targets[label]
		if not target then return end

		tooltip:AddLine(actor.name .. ": " .. win.spellname)
		if spell.school and spellschools and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if target.count then
			tooltip:AddDoubleLine(L["Count"], target.count, 1, 1, 1)
		end
		if target.refresh then
			tooltip:AddDoubleLine(L["Refresh"], target.refresh, 1, 1, 1)
		end
	end
end

---------------------------------------------------------------------------
-- Buffs Module

Skada:RegisterModule("Buffs", function(_, P, _, C)
	local mod = Skada:NewModule("Buffs")
	local spellmod = mod:NewModule("Buff spell list")
	local spelltargetmod = spellmod:NewModule("Players list")
	local mod_cols = nil

	local UnitName, UnitGUID, UnitBuff = UnitName, UnitGUID, UnitBuff
	local UnitIsDeadOrGhost, GroupIterator = UnitIsDeadOrGhost, Skada.GroupIterator

	local function handle_buff(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, school, auratype)
		if spellid and not ignored_buffs[spellid] and (auratype == "BUFF" or special_buffs[spellid]) then
			aura.actorid = dstGUID
			aura.actorname = dstName
			aura.actorflags = dstFlags
			aura.dstName = nil

			aura.spellid = spellid
			aura.school = school

			if event == "SPELL_PERIODIC_ENERGIZE" then
				Skada:DispatchSets(log_specialaura)
			elseif event == "SPELL_AURA_APPLIED" then
				Skada:DispatchSets(log_auraapplied)
			elseif event == "SPELL_AURA_REMOVED" then
				Skada:DispatchSets(log_auraremove)
			else
				Skada:DispatchSets(log_aurarefresh)
			end
		end
	end

	function spelltargetmod:Enter(win, id, label)
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
			for i = 1, #actors do
				local actor = actors[i]
				local spell = actor and not actor.enemy and actor.auras and actor.auras[spellid]
				if spell then
					local t = new_actor_table(actor)
					t.count = spell.count
					t.maxtime = floor(actor:GetTime(self))
					t.uptime = min(t.maxtime, spell.uptime)
					tbl[actor.name] = t
				end
			end
			return tbl
		end

		function spelltargetmod:Update(win, set)
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
				d.value = target.uptime
				format_valuetext(d, mod_cols, target.count, target.maxtime, win.metadata, true)
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = uformat(L["%s's buffs"], label)
	end

	function spellmod:Update(win, set)
		win.title = uformat(L["%s's buffs"], win.actorname)
		spell_update_func(self, "BUFF", win, set, mod_cols)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Buffs"], L[win.class]) or L["Buffs"]
		main_update_func(self, "BUFF", win, set, mod_cols)
	end

	do
		local function check_unit_buffs(unit, owner)
			if owner or UnitIsDeadOrGhost(unit) then return end
			local dstGUID, dstName = UnitGUID(unit), UnitName(unit)
			for i = 1, 40 do
				local _, rank, _, _, _, _, _, unitCaster, _, _, spellid = UnitBuff(unit, i)
				if not spellid then
					break -- nothing found!
				elseif unitCaster and rank ~= SPELL_PASSIVE then
					handle_buff(nil, "SPELL_AURA_APPLIED", nil, nil, nil, dstGUID, dstName, nil, spellid, nil, nil, "BUFF")
				end
			end
		end

		function mod:CombatEnter(_, set)
			if set and not set.stopped and not self.checked then
				GroupIterator(check_unit_buffs)
				self.checked = true
			end
		end

		function mod:CombatLeave()
			self.checked = nil
		end
	end

	function mod:OnEnable()
		spelltargetmod.metadata = {showspots = true, ordersort = true, tooltip = spelltarget_tooltip}
		spellmod.metadata = {valueorder = true, tooltip = spell_tooltip, click1 = spelltargetmod}
		self.metadata = {
			click1 = spellmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Uptime = true, Count = false, Percent = true, sPercent = true},
			icon = [[Interface\Icons\spell_holy_divinespirit]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		spellmod.nototal = true

		Skada:RegisterForCL(
			handle_buff,
			{dst_is_interesting_nopets = true},
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_APPLIED_DOSE",
			"SPELL_PERIODIC_ENERGIZE"
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER", "CombatEnter")
		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end
end)

---------------------------------------------------------------------------
-- Debuffs Module

Skada:RegisterModule("Debuffs", function(_, _, _, C)
	local mod = Skada:NewModule("Debuffs")
	local spellmod = mod:NewModule("Debuff spell list")
	local spelltargetmod = spellmod:NewModule("Debuff target list")
	local spellsourcemod = spellmod:NewModule("Debuff source list")
	local targetmod = mod:NewModule("Debuff target list")
	local targetspellmod = targetmod:NewModule("Debuff spell list")
	local mod_cols = nil

	local function handle_debuff(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, school, auratype)
		if not spellid or ignored_debuffs[spellid] or auratype ~= "DEBUFF" then return end

		aura.actorid, aura.actorname, aura.actorflags = Skada:FixMyPets(srcGUID, srcName, srcFlags)
		aura.dstName = Skada:FixPetsName(dstGUID, dstName, dstFlags)
		aura.spellid = -spellid
		aura.school = school

		if event == "SPELL_AURA_APPLIED" then
			Skada:DispatchSets(log_auraapplied)
		elseif event == "SPELL_AURA_REMOVED" then
			Skada:DispatchSets(log_auraremove)
		else
			Skada:DispatchSets(log_aurarefresh)
		end
	end

	function targetspellmod:Enter(win, id, label)
		win.targetname = label or L["Unknown"]
		win.title = L["actor debuffs"](win.actorname or L["Unknown"], label)
	end

	function targetspellmod:Update(win, set)
		win.title = L["actor debuffs"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		targetspell_update_func(self, "DEBUFF", win, set, mod_cols, C)
	end

	function spelltargetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> targets"], win.actorname, label)
	end

	function spelltargetmod:Update(win, set)
		win.title = uformat(L["%s's <%s> targets"], win.actorname, win.spellname)
		spelltarget_update_func(self, "DEBUFF", win, set, mod_cols, C)
	end

	function spellsourcemod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's sources"], label)
	end

	function spellsourcemod:Update(win, set)
		win.title = uformat(L["%s's sources"], win.spellname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		if not win.spellid then return end

		local nr = 0
		local actors = set.actors

		for i = 1, #actors do
			local actor = actors[i]
			local auras = win:show_actor(actor, set, true) and not actor.enemy and actor.auras
			local spell = auras and auras[win.spellid]
			if spell then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy)
				d.value = spell.uptime
				format_valuetext(d, mod_cols, spell.count, actor:GetTime(set), win.metadata, true, true)
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = uformat(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's targets"], win.actorname)
		target_update_func(self, "DEBUFF", win, set, mod_cols, C)
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor debuffs"](label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor debuffs"](win.actorname or L["Unknown"])
		spell_update_func(self, "DEBUFF", win, set, mod_cols)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Debuffs"], L[win.class]) or L["Debuffs"]
		main_update_func(self, "DEBUFF", win, set, mod_cols)
	end

	local function spellsource_tooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		local spell = actor and actor.auras and actor.auras[win.spellid]
		if not (spell and spell.count) then return end

		tooltip:AddLine(label .. ": " .. win.spellname)
		if spell.school and spellschools and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
		if spell.refresh then
			tooltip:AddDoubleLine(L["Refresh"], spell.refresh, 1, 1, 1)
		end
	end

	function mod:OnEnable()
		spellsourcemod.metadata = {
			tooltip = spellsource_tooltip,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"]
		}

		spelltargetmod.metadata = {tooltip = spelltarget_tooltip}
		spellmod.metadata = {click1 = spelltargetmod, click2 = spellsourcemod, tooltip = spell_tooltip}
		targetmod.metadata = {click1 = targetspellmod}
		self.metadata = {
			click1 = spellmod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Uptime = true, Count = false, Percent = true, sPercent = true},
			icon = [[Interface\Icons\spell_shadow_shadowwordpain]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		spellmod.nototal = true
		targetmod.nototal = true

		Skada:RegisterForCL(
			handle_debuff,
			{src_is_interesting = true},
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_APPLIED_DOSE"
		)

		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)

---------------------------------------------------------------------------
-- Enemy Buffs Module

Skada:RegisterModule("Enemy Buffs", function(_, P, _, C)
	local mod = Skada:NewModule("Enemy Buffs")
	local spellmod = mod:NewModule("Buff spell list")
	local mod_cols = nil

	local function handle_buff(_, event, _, _, _, dstGUID, dstName, dstFlags, spellid, _, school, auratype)
		if spellid and not ignored_buffs[spellid] and (auratype == "BUFF" or special_buffs[spellid]) then
			aura.actorid = dstGUID
			aura.actorname = dstName
			aura.actorflags = dstFlags
			aura.dstName = nil

			aura.spellid = spellid
			aura.school = school

			if event == "SPELL_PERIODIC_ENERGIZE" then
				Skada:DispatchSets(log_specialaura, true)
			elseif event == "SPELL_AURA_APPLIED" then
				Skada:DispatchSets(log_auraapplied, true)
			elseif event == "SPELL_AURA_REMOVED" then
				Skada:DispatchSets(log_auraremove, true)
			else
				Skada:DispatchSets(log_aurarefresh, true)
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = uformat(L["%s's buffs"], label)
	end

	function spellmod:Update(win, set)
		win.title = uformat(L["%s's buffs"], win.actorname)
		spell_update_func(self, "BUFF", win, set, mod_cols)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Enemy Buffs"], L[win.class]) or L["Enemy Buffs"]
		main_update_func(self, "BUFF", win, set, mod_cols, true)
	end

	function mod:OnEnable()
		spellmod.metadata = {valueorder = true, tooltip = spell_tooltip}
		self.metadata = {
			click1 = spellmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Uptime = true, Count = false, Percent = true, sPercent = true},
			icon = [[Interface\Icons\ability_paladin_beaconoflight]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		spellmod.nototal = true

		Skada:RegisterForCL(
			handle_buff,
			{src_is_not_interesting = true, dst_is_not_interesting = true},
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_APPLIED_DOSE",
			"SPELL_PERIODIC_ENERGIZE"
		)

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)

---------------------------------------------------------------------------
-- Enemy Debuffs Module

Skada:RegisterModule("Enemy Debuffs", function(_, _, _, C)
	local mod = Skada:NewModule("Enemy Debuffs")
	local spellmod = mod:NewModule("Debuff spell list")
	local spelltargetmod = spellmod:NewModule("Debuff target list")
	local targetmod = mod:NewModule("Debuff target list")
	local targetspellmod = targetmod:NewModule("Debuff spell list")
	local mod_cols = nil

	local function handle_debuff(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, school, auratype)
		if not spellid or ignored_debuffs[spellid] or auratype ~= "DEBUFF" then return end

		aura.actorid = srcGUID
		aura.actorname = srcName
		aura.actorflags = srcFlags
		aura.dstName = Skada:FixPetsName(dstGUID, dstName, dstFlags)

		aura.spellid = -spellid
		aura.school = school

		if event == "SPELL_AURA_APPLIED" then
			Skada:DispatchSets(log_auraapplied, true)
		elseif event == "SPELL_AURA_REMOVED" then
			Skada:DispatchSets(log_auraremove, true)
		else
			Skada:DispatchSets(log_aurarefresh, true)
		end
	end

	function targetspellmod:Enter(win, id, label)
		win.targetname = label or L["Unknown"]
		win.title = L["actor debuffs"](win.actorname or L["Unknown"], label)
	end

	function targetspellmod:Update(win, set)
		win.title = L["actor debuffs"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		targetspell_update_func(self, "DEBUFF", win, set, mod_cols, C)
	end

	function spelltargetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> targets"], win.actorname, label)
	end

	function spelltargetmod:Update(win, set)
		win.title = uformat(L["%s's <%s> targets"], win.actorname, win.spellname)
		spelltarget_update_func(self, "DEBUFF", win, set, mod_cols, C)
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = uformat(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's targets"], win.actorname)
		target_update_func(self, "DEBUFF", win, set, mod_cols, C)
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor debuffs"](label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor debuffs"](win.actorname or L["Unknown"])
		spell_update_func(self, "DEBUFF", win, set, mod_cols)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Enemy Debuffs"], L[win.class]) or L["Enemy Debuffs"]
		main_update_func(self, "DEBUFF", win, set, mod_cols, true)
	end

	function mod:OnEnable()
		spelltargetmod.metadata = {tooltip = spelltarget_tooltip}
		spellmod.metadata = {click1 = spelltargetmod, tooltip = spell_tooltip}
		targetmod.metadata = {click1 = targetspellmod}
		self.metadata = {
			click1 = spellmod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Uptime = true, Count = false, Percent = true, sPercent = true},
			icon = [[Interface\Icons\ability_warlock_improvedsoulleech]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		spellmod.nototal = true
		targetmod.nototal = true

		Skada:RegisterForCL(
			handle_debuff,
			{src_is_not_interesting = true, dst_is_interesting = true},
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_APPLIED_DOSE"
		)

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)
