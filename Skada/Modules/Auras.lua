local Skada = Skada

local format, pformat = string.format, Skada.pformat
local pairs, min, floor = pairs, math.min, math.floor
local _

-- common functions
local new, clear = Skada.newTable, Skada.clearTable
local log_auraapply, log_aurarefresh, log_auraremove
local mod_update_func, aura_update_func, aura_tooltip
local format_valuetext, spellschools, aura = nil, nil, nil

-- main module that handles common stuff
do
	local L = LibStub("AceLocale-3.0"):GetLocale("Skada")
	local mod = Skada:NewModule("Buffs and Debuffs")
	local PercentToRGB = Skada.PercentToRGB
	local del = Skada.delTable

	function mod:OnEnable()
		if not Skada:IsDisabled("Buffs") or not Skada:IsDisabled("Debuffs") then
			aura = {}
			spellschools = spellschools or Skada.spellschools
			Skada.RegisterCallback(self, "Skada_SetComplete", "Clean")
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
	end

	function mod:Clean(_, set, curtime)
		clear(aura)
		if not set then return end

		local maxtime = Skada:GetSetTime(set)
		curtime = curtime or set.last_action or time()

		for i = 1, #set.players do
			local player = set.players[i]
			if player and player.auras then
				for spellid, spell in pairs(player.auras) do
					if spell.active ~= nil and spell.start then
						spell.uptime = min(maxtime, spell.uptime + floor((curtime - spell.start) + 0.5))
					end
					-- remove temporary keys
					spell.active, spell.start = nil, nil

					if spell.uptime == 0 then
						-- remove spell with 0 uptime.
						player.auras[spellid] = del(player.auras[spellid], true)
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
							player.auras[spellid] = del(player.auras[spellid])
						end
					end
				end

				-- remove table if no auras left
				if next(player.auras) == nil then
					player.auras = del(player.auras)
				end
			end
		end
	end

	-- common functions.

	function log_auraapply(set)
		if not set or (set == Skada.total and not Skada.db.profile.totalidc) then return end
		if not aura or not aura.spellid then return end

		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		if not player then return end

		local curtime = set.last_action or time()
		local spell = player.auras and player.auras[aura.spellid]
		if not spell then
			player.auras = player.auras or {}
			player.auras[aura.spellid] = {school = aura.school, active = 1, count = 1, uptime = 0, start = curtime}
			spell = player.auras[aura.spellid]
		else
			spell.active = (spell.active or 0) + 1
			spell.count = (spell.count or 0) + 1
			spell.start = spell.start or curtime

			-- fix missing school
			if not spell.school and aura.school then
				spell.school = aura.school
			end
		end

		-- only records targets for debuffs
		if aura.spellid > 0 or not aura.dstName then return end

		local target = spell.targets and spell.targets[aura.dstName]
		if not target then
			spell.targets = spell.targets or {}
			spell.targets[aura.dstName] = {count = 1, active = 1, uptime = 0, start = curtime}
		else
			target.active = (target.active or 0) + 1
			target.count = (target.count or 0) + 1
			target.start = target.start or curtime
		end
	end

	function log_aurarefresh(set)
		if not set or (set == Skada.total and not Skada.db.profile.totalidc) then return end
		if not aura or not aura.spellid then return end

		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		if not player then return end

		local spell = player.auras and player.auras[aura.spellid]
		if not spell or not spell.active or spell.active == 0 then return end

		spell.refresh = (spell.refresh or 0) + 1
		local target = spell.targets and aura.dstName and spell.targets[aura.dstName]
		if target then
			target.refresh = (target.refresh or 0) + 1
		end
	end

	function log_auraremove(set)
		if not set or (set == Skada.total and not Skada.db.profile.totalidc) then return end
		if not aura or not aura.spellid then return end

		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		if not player then return end

		local spell = player.auras and player.auras[aura.spellid]
		if not spell or not spell.active or spell.active == 0 then return end

		local curtime = set.last_action or time()
		spell.active = spell.active - 1
		if spell.active == 0 and spell.start then
			spell.uptime = spell.uptime + floor((curtime - spell.start) + 0.5)
			spell.start = nil
		end

		-- targets
		local target = spell.targets and aura.dstName and spell.targets[aura.dstName]
		if not target or not target.active or target.active == 0 then return end

		target.active = target.active - 1
		if target.active == 0 and target.start then
			target.uptime = target.uptime + floor((curtime - target.start) + 0.5)
			target.start = nil
		end
	end

	function format_valuetext(d, columns, count, uptime, metadata, subview, no_order)
		d.valuetext = Skada:FormatValueCols(
			columns.Uptime and Skada:FormatTime(d.value),
			columns.Count and Skada:FormatNumber(count),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, uptime)
		)

		if no_order then
			return
		elseif metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	do
		local function count_auras_by_type(auras, auratype)
			local count, uptime = 0, 0
			if auras then
				for spellid, spell in pairs(auras) do
					-- fix old data
					if spell.type then
						if spell.type == "DEBUFF" and spellid > 0 then
							local sid = spellid
							spellid = -spellid
							auras[spellid] = spell
							auras[sid] = nil
						end
						spell.type = nil
					end
					if (auratype == "BUFF" and spellid > 0) or (auratype == "DEBUFF" and spellid < 0) then
						count = count + 1
						uptime = uptime + spell.uptime
					end
				end
			end
			return count, uptime
		end

		function mod_update_func(self, auratype, win, set, cols)
			if not auratype then return end
			local settime = set and set:GetTime()

			if not settime or settime == 0 then
				return
			elseif win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			local actors = set.players -- players
			for i = 1, #actors do
				local actor = actors[i]
				if actor and (not win.class or win.class == actor.class) then
					local count, uptime = count_auras_by_type(actor.auras, auratype)
					if count > 0 and uptime > 0 then
						nr = nr + 1

						local d = win:actor(nr, actor)
						local maxtime = floor(actor:GetTime())
						d.value = min(floor(uptime / count), maxtime)
						format_valuetext(d, cols, count, maxtime, win.metadata)
					end
				end
			end
		end
	end

	function aura_update_func(self, auratype, win, set, cols)
		if not auratype then return end

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local maxtime = player and player:GetTime()
		local spells = (maxtime and maxtime > 0) and player.auras

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, spell in pairs(spells) do
			if (auratype == "BUFF" and spellid > 0 and spell.uptime > 0) or (auratype == "DEBUFF" and spellid < 0 and spell.uptime > 0) then
				nr = nr + 1

				local d = win:spell(nr, spellid, spell, nil, nil, true)
				d.value = min(maxtime, spell.uptime)
				format_valuetext(d, cols, spell.count, maxtime, win.metadata, true)
			end
		end
	end

	function aura_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local settime = set and set:GetTime()
		local player = (settime and settime > 0) and set:GetPlayer(win.actorid, win.actorname)
		local spell = player and player.auras and player.auras[id]
		if not spell then return end

		tooltip:AddLine(player.name .. ": " .. label)
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
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(player:GetTime(true)), 1, 1, 1)
		tooltip:AddDoubleLine(L["Duration"], Skada:FormatTime(spell.uptime), 1, 1, 1)

		-- display aura uptime in colored percent
		local uptime = 100 * (spell.uptime / player:GetTime())
		tooltip:AddDoubleLine(L["Uptime"], Skada:FormatPercent(uptime), nil, nil, nil, PercentToRGB(uptime))
	end
end

Skada:RegisterModule("Buffs", function(L, P, _, C)
	local mod = Skada:NewModule("Buffs")
	local spellmod = mod:NewModule("Buff spell list")
	local playermod = spellmod:NewModule("Players list")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local get_players_by_buff = nil
	local mod_cols = nil

	local UnitName, UnitGUID, UnitBuff = UnitName, UnitGUID, UnitBuff
	local UnitIsDeadOrGhost, GroupIterator = UnitIsDeadOrGhost, Skada.GroupIterator

	-- list of spells that don't trigger SPELL_AURA_x events
	local speciallist = {
		[57669] = true -- Replenishment
	}

	local function log_specialaura(set)
		if not set or (set == Skada.total and not P.totalidc) then return end
		if not aura or not aura.spellid then return end

		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		if not player then return end

		local spell = player.auras and player.auras[aura.spellid]
		if not spell then
			player.auras = player.auras or {}
			player.auras[aura.spellid] = {school = aura.school, uptime = 1}
			spell = player.auras[aura.spellid]
		else
			spell.uptime = spell.uptime + 1
			if not spell.school and aura.school then
				spell.school = aura.school
			end
		end
	end

	local function handle_buff(_, event, _, _, _, dstGUID, dstName, dstFlags, spellid, _, school, auratype)
		if
			spellid and -- just in case, you never know!
			not ignoredSpells[spellid] and
			(auratype == "BUFF" or speciallist[spellid])
		then
			aura.playerid = dstGUID
			aura.playername = dstName
			aura.playerflags = dstFlags

			aura.dstGUID = nil
			aura.dstName = nil
			aura.dstFlags = nil

			aura.spellid = spellid
			aura.school = school

			if event == "SPELL_PERIODIC_ENERGIZE" then
				Skada:DispatchSets(log_specialaura)
			elseif event == "SPELL_AURA_APPLIED" then
				Skada:DispatchSets(log_auraapply)
			elseif event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" then
				Skada:DispatchSets(log_aurarefresh)
			elseif event == "SPELL_AURA_REMOVED" then
				Skada:DispatchSets(log_auraremove)
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = pformat(L["%s's targets"], label)
	end

	function playermod:Update(win, set)
		win.title = pformat(L["%s's targets"], win.spellname)
		if not (win.spellid and set) then return end

		local players, count = get_players_by_buff(set, win.spellid)

		if count == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for playername, player in pairs(players) do
			nr = nr + 1

			local d = win:actor(nr, player, nil, playername)
			d.value = player.uptime
			format_valuetext(d, mod_cols, nil, player.maxtime, win.metadata, true)
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = pformat(L["%s's buffs"], label)
	end

	function spellmod:Update(win, set)
		win.title = pformat(L["%s's buffs"], win.actorname)
		aura_update_func(mod, "BUFF", win, set, mod_cols)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Buffs"], L[win.class]) or L["Buffs"]
		mod_update_func(self, "BUFF", win, set, mod_cols)
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

		function mod:CombatEnter(event, set)
			if event == "COMBAT_PLAYER_ENTER" and set and not set.stopped and not self.checked then
				GroupIterator(check_unit_buffs)
				self.checked = true
			end
		end

		function mod:CombatLeave()
			self.checked = nil
		end
	end

	local function aura_subtooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local actor = set and set:GetPlayer(id, label)
		local spell = actor and actor.auras and actor.auras[win.spellid]
		if not spell then return end

		tooltip:AddLine(actor.name .. ": " .. win.spellname)
		if spell.school and spellschools and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if spell.count then
			tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
		end
		if spell.refresh then
			tooltip:AddDoubleLine(L["Refresh"], spell.refresh, 1, 1, 1)
		end
	end

	function mod:OnEnable()
		playermod.metadata = {showspots = true, ordersort = true, tooltip = aura_subtooltip}
		spellmod.metadata = {valueorder = true, tooltip = aura_tooltip, click1 = playermod}
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
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_APPLIED_DOSE",
			"SPELL_PERIODIC_ENERGIZE",
			{dst_is_interesting_nopets = true}
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER", "CombatEnter")
		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, L["Buffs and Debuffs"])

		-- table of ignored spells:
		if Skada.ignoredSpells and Skada.ignoredSpells.buffs then
			ignoredSpells = Skada.ignoredSpells.buffs
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:AddMode(self)
	end

	---------------------------------------------------------------------------

	get_players_by_buff = function(self, spellid, tbl)
		local count = 0
		if not spellid or not self.players then
			return nil, count
		end

		tbl = clear(tbl or C)
		for i = 1, #self.players do
			local p = self.players[i]
			if p and p.auras and p.auras[spellid] then
				count = count + 1

				local t = new()
				t.id = p.id
				t.class = p.class
				t.role = p.role
				t.spec = p.spec
				t.maxtime = floor(p:GetTime())
				t.uptime = min(t.maxtime, p.auras[spellid].uptime)
				tbl[p.name] = t
			end
		end
		return tbl, count
	end
end)

Skada:RegisterModule("Debuffs", function(L, _, _, C)
	local mod = Skada:NewModule("Debuffs")
	local spellmod = mod:NewModule("Debuff spell list")
	local spelltargetmod = spellmod:NewModule("Debuff target list")
	local spellsourcemod = spellmod:NewModule("Debuff source list")
	local targetmod = mod:NewModule("Debuff target list")
	local targetspellmod = targetmod:NewModule("Debuff spell list")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	local get_debuffs_targets = nil
	local get_debuff_targets = nil
	local get_debuffs_on_target = nil
	local mod_cols = nil

	-- list of spells used to queue units.
	local queuedSpells = {[49005] = 50424}

	local function handle_debuff(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, _, spellid, _, school, auratype)
		if not spellid or ignoredSpells[spellid] or auratype ~= "DEBUFF" then return end

		aura.playerid = srcGUID
		aura.playername = srcName
		aura.playerflags = srcFlags

		aura.dstGUID = nil
		aura.dstName = dstName
		aura.dstFlags = nil

		aura.spellid = -spellid
		aura.school = school

		Skada:FixPets(aura)

		if event == "SPELL_AURA_APPLIED" then
			Skada:DispatchSets(log_auraapply)
			if queuedSpells[spellid] then
				Skada:QueueUnit(queuedSpells[spellid], srcGUID, srcName, srcFlags, dstGUID)
			end
		elseif event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" then
			Skada:DispatchSets(log_aurarefresh)
		elseif event == "SPELL_AURA_REMOVED" then
			Skada:DispatchSets(log_auraremove)
			if queuedSpells[spellid] then
				Skada:UnqueueUnit(queuedSpells[spellid], dstGUID)
			end
		end
	end

	function targetspellmod:Enter(win, id, label)
		win.targetname = label or L["Unknown"]
		win.title = L["actor debuffs"](win.actorname or L["Unknown"], label)
	end

	function targetspellmod:Update(win, set)
		win.title = L["actor debuffs"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not win.targetname then return end

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		if not player then return end

		local auras, maxtime = get_debuffs_on_target(player, win.targetname)

		if not auras or maxtime == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, spell in pairs(auras) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell, nil, nil, true)
			d.value = spell.uptime
			format_valuetext(d, mod_cols, spell.count, maxtime, win.metadata, true)
		end
	end

	function spelltargetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = pformat(L["%s's <%s> targets"], win.actorname, label)
	end

	function spelltargetmod:Update(win, set)
		win.title = pformat(L["%s's <%s> targets"], win.actorname, win.spellname)
		if not win.spellid then return end

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		if not player then return end

		local targets, maxtime = get_debuff_targets(player, win.spellid)

		if not targets or maxtime == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, targetname)
			d.value = target.uptime
			format_valuetext(d, mod_cols, target.count, maxtime, win.metadata, true)
		end
	end

	function spellsourcemod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = pformat(L["%s's sources"], label)
	end

	function spellsourcemod:Update(win, set)
		win.title = pformat(L["%s's sources"], win.spellname)
		if not win.spellid then return end

		local nr = 0
		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			local spell = actor and actor.auras and actor.auras[win.spellid]
			if spell then
				nr = nr + 1

				local d = win:actor(nr, actor)
				d.value = spell.uptime
				format_valuetext(d, mod_cols, spell.count, actor:GetTime(), win.metadata, true, true)
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = pformat(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's targets"], win.actorname)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		if not player then return end

		local targets, maxtime = get_debuffs_targets(player)

		if not targets or maxtime == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, targetname)
			d.value = target.uptime
			format_valuetext(d, mod_cols, target.count, maxtime, win.metadata, true)
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor debuffs"](label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor debuffs"](win.actorname or L["Unknown"])
		aura_update_func(mod, "DEBUFF", win, set, mod_cols)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Debuffs"], L[win.class]) or L["Debuffs"]
		mod_update_func(self, "DEBUFF", win, set, mod_cols)
	end

	local function aura_target_tooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local actor = set and set:GetPlayer(win.actorid, win.actorname)
		local spell = actor and actor.auras and actor.auras[win.spellid]
		if not (spell and spell.targets and spell.targets[label]) then return end

		tooltip:AddLine(actor.name .. ": " .. win.spellname)
		if spell.school and spellschools and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if spell.targets[label].count then
			tooltip:AddDoubleLine(L["Count"], spell.targets[label].count, 1, 1, 1)
		end
		if spell.targets[label].refresh then
			tooltip:AddDoubleLine(L["Refresh"], spell.targets[label].refresh, 1, 1, 1)
		end
	end

	local function aura_source_tooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local actor = set and set:GetPlayer(id, label)
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
		spelltargetmod.metadata = {tooltip = aura_target_tooltip}
		spellsourcemod.metadata = {tooltip = aura_source_tooltip}
		spellmod.metadata = {click1 = spelltargetmod, click2 = spellsourcemod, post_tooltip = aura_tooltip}
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
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_APPLIED_DOSE",
			{src_is_interesting = true}
		)

		Skada:AddMode(self, L["Buffs and Debuffs"])

		-- table of ignored spells:
		if Skada.ignoredSpells and Skada.ignoredSpells.debuffs then
			ignoredSpells = Skada.ignoredSpells.debuffs
		end
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	-- add functions to player's prototype.

	local function new_debuff_table(info)
		local debuff = new()
		debuff.count = info.count
		debuff.refresh = info.refresh
		debuff.uptime = info.uptime
		return debuff
	end

	get_debuffs_targets = function(self, tbl)
		if not self.auras then return end

		tbl = clear(tbl or C)
		local maxtime = 0
		for _, spell in pairs(self.auras) do
			if spell.targets then
				maxtime = maxtime + spell.uptime
				for name, target in pairs(spell.targets) do
					local debuff = tbl[name]
					if not debuff then
						debuff = new_debuff_table(target)
						tbl[name] = debuff
					else
						debuff.count = debuff.count + target.count
						debuff.uptime = debuff.uptime + target.uptime
						if target.refresh then
							debuff.refresh = (debuff.refresh or 0) + target.refresh
						end
					end

					self.super:_fill_actor_table(debuff, name)
				end
			end
		end
		return tbl, maxtime
	end

	get_debuff_targets = function(self, spellid, tbl)
		if self.auras and spellid and self.auras[spellid] and self.auras[spellid].targets then
			tbl = clear(tbl or C)
			local maxtime = self.auras[spellid].uptime
			for name, target in pairs(self.auras[spellid].targets) do
				tbl[name] = new_debuff_table(target)
				self.super:_fill_actor_table(tbl[name], name)
			end
			return tbl, maxtime
		end
	end

	get_debuffs_on_target = function(self, name, tbl)
		if self.auras and name then
			tbl = clear(tbl or C)
			local maxtime = 0
			for spellid, spell in pairs(self.auras) do
				if spell.targets and spell.targets[name] then
					maxtime = maxtime + spell.uptime
					tbl[spellid] = new_debuff_table(spell.targets[name])
					tbl[spellid].school = spell.school
				end
			end
			return tbl, maxtime
		end
	end
end)
