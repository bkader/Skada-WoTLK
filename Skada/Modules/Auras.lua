local Skada = Skada

local pairs, format, tostring = pairs, string.format, tostring
local min, max, floor = math.min, math.max, math.floor
local UnitName, UnitGUID, UnitBuff = UnitName, UnitGUID, UnitBuff
local UnitIsDeadOrGhost, GroupIterator = UnitIsDeadOrGhost, Skada.GroupIterator
local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local PercentToRGB = Skada.PercentToRGB
local setPrototype = Skada.setPrototype
local playerPrototype = Skada.playerPrototype
local _

-- common functions
local log_auraapply, log_aurarefresh, log_auraremove
local mod_update_func, aura_update_func, aura_tooltip
local spellschools = nil

-- main module that handles common stuff
do
	local L = LibStub("AceLocale-3.0"):GetLocale("Skada")
	local mod = Skada:NewModule("Buffs and Debuffs")
	local del = Skada.delTable

	function mod:OnEnable()
		if not Skada:IsDisabled("Buffs") or not Skada:IsDisabled("Debuffs") then
			spellschools = spellschools or Skada.spellschools
			Skada.RegisterCallback(self, "Skada_SetComplete", "Clean")

			-- add functions to segment prototype
			local cache, new, clear = Skada.cacheTable, Skada.newTable, Skada.clearTable
			setPrototype.GetAuraPlayers = function(set, spellid)
				local count = 0
				if spellid and set.players then
					clear(cache)
					for i = 1, #set.players do
						local p = set.players[i]
						if p and p.auras and p.auras[spellid] then
							local maxtime = floor(p:GetTime())
							local uptime = min(maxtime, p.auras[spellid].uptime)
							count = count + 1
							cache[p.name] = new()
							cache[p.name].id = p.id
							cache[p.name].class = p.class
							cache[p.name].role = p.role
							cache[p.name].spec = p.spec
							cache[p.name].uptime = uptime
							cache[p.name].maxtime = maxtime
						end
					end
					return cache, count
				end
				return nil, count
			end

			-- add player's aura uptime getter.
			playerPrototype.GetAuraUptime = function(p, spellid)
				if p.auras and spellid and p.auras[spellid] and p.auras[spellid].uptime and p.auras[spellid].uptime > 0 then
					return p.auras[spellid].uptime, p:GetTime()
				end
			end
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
	end

	function mod:Clean(_, set, curtime)
		if set then
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
	end

	-- common functions.

	function log_auraapply(set, aura)
		if not set or (set == Skada.total and not Skada.db.profile.totalidc) then return end
		if not aura or not aura.spellid then return end

		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		if player then
			local curtime = set.last_action or time()
			local spell = player.auras and player.auras[aura.spellid]
			if not spell then
				spell = {school = aura.spellschool, type = aura.type, active = 1, count = 1, uptime = 0, start = curtime}
				player.auras = player.auras or {}
				player.auras[aura.spellid] = spell
			else
				spell.active = (spell.active or 0) + 1
				spell.count = (spell.count or 0) + 1
				spell.start = spell.start or curtime

				-- fix missing school
				if not spell.school and aura.spellschool then
					spell.school = aura.spellschool
				end
			end

			-- only records targets for debuffs
			if aura.type == "DEBUFF" and aura.dstName then
				spell.targets = spell.targets or {}
				if not spell.targets[aura.dstName] then
					spell.targets[aura.dstName] = {count = 1, active = 1, uptime = 0, start = curtime}
				else
					spell.targets[aura.dstName].active = (spell.targets[aura.dstName].active or 0) + 1
					spell.targets[aura.dstName].count = (spell.targets[aura.dstName].count or 0) + 1
					spell.targets[aura.dstName].start = spell.targets[aura.dstName].start or curtime
				end
			end
		end
	end

	function log_aurarefresh(set, aura)
		if not set or (set == Skada.total and not Skada.db.profile.totalidc) then return end
		if not aura or not aura.spellid then return end

		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		local spell = player and player.auras and player.auras[aura.spellid]

		if spell and spell.active and spell.active > 0 then
			spell.refresh = (spell.refresh or 0) + 1
			if spell.targets and aura.dstName and spell.targets[aura.dstName] then
				spell.targets[aura.dstName].refresh = (spell.targets[aura.dstName].refresh or 0) + 1
			end
		end
	end

	function log_auraremove(set, aura)
		if not set or (set == Skada.total and not Skada.db.profile.totalidc) then return end
		if not aura or not aura.spellid then return end

		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		local spell = player and player.auras and player.auras[aura.spellid]

		if spell and spell.active and spell.active > 0 then
			local curtime = set.last_action or time()
			spell.active = spell.active - 1
			if spell.active == 0 and spell.start then
				spell.uptime = spell.uptime + floor((curtime - spell.start) + 0.5)
				spell.start = nil
			end

			-- targets
			if spell.targets and aura.dstName and spell.targets[aura.dstName] and spell.targets[aura.dstName].active and spell.targets[aura.dstName].active > 0 then
				spell.targets[aura.dstName].active = spell.targets[aura.dstName].active - 1
				if spell.targets[aura.dstName].active == 0 and spell.targets[aura.dstName].start then
					spell.targets[aura.dstName].uptime = spell.targets[aura.dstName].uptime + floor((curtime - spell.targets[aura.dstName].start) + 0.5)
					spell.targets[aura.dstName].start = nil
				end
			end
		end
	end

	do
		local function count_auras_by_type(auras, atype)
			local count, uptime = 0, 0
			if auras then
				for _, spell in pairs(auras) do
					if spell.type == atype and spell.uptime > 0 then
						count = count + 1
						uptime = uptime + spell.uptime
					end
				end
			end
			return count, uptime
		end

		function mod_update_func(atype, win, set, mode)
			if not atype then return end
			local settime = set and set:GetTime()
			if settime > 0 then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for i = 1, #set.players do
					local player = set.players[i]
					if player and (not win.class or win.class == player.class) then
						local auracount, aurauptime = count_auras_by_type(player.auras, atype)
						if auracount > 0 and aurauptime > 0 then
							nr = nr + 1
							local d = win:actor(nr, player)

							local maxtime = floor(player:GetTime())
							d.value = min(floor(aurauptime / auracount), maxtime)
							d.valuetext = Skada:FormatValueCols(
								mode.metadata.columns.Uptime and Skada:FormatTime(d.value),
								mode.metadata.columns.Count and auracount,
								mode.metadata.columns.Percent and Skada:FormatPercent(d.value, maxtime)
							)

							if win.metadata and d.value > win.metadata.maxvalue then
								win.metadata.maxvalue = d.value
							end
						end
					end
				end
			end
		end
	end

	function aura_update_func(atype, win, set, mode)
		if not atype then return end

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local maxtime = player and player:GetTime() or 0

		if maxtime > 0 and player.auras then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.auras) do
				if spell.type == atype and spell.uptime > 0 then
					nr = nr + 1
					local d = win:spell(nr, spellid, spell)

					d.value = min(maxtime, spell.uptime)
					d.valuetext = Skada:FormatValueCols(
						mode.metadata.columns.Uptime and Skada:FormatTime(d.value),
						mode.metadata.columns.Count and spell.count,
						mode.metadata.columns.sPercent and Skada:FormatPercent(d.value, maxtime)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function aura_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local settime = set and set:GetTime() or 0
		local player = (settime > 0) and set:GetPlayer(win.actorid, win.actorname)
		local aura = player and player.auras and player.auras[id]
		if aura then
			tooltip:AddLine(player.name .. ": " .. label)
			if aura.school and spellschools and spellschools[aura.school] then
				tooltip:AddLine(spellschools(aura.school))
			end
			if aura.count or aura.refresh then
				if aura.count then
					tooltip:AddDoubleLine(L["Count"], aura.count, 1, 1, 1)
				end
				if aura.refresh then
					tooltip:AddDoubleLine(L["Refresh"], aura.refresh, 1, 1, 1)
				end
				tooltip:AddLine(" ")
			end

			-- add segment and active times
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(player:GetTime(true)), 1, 1, 1)
			tooltip:AddDoubleLine(L["Duration"], Skada:FormatTime(aura.uptime), 1, 1, 1)

			-- display aura uptime in colored percent
			local uptime = 100 * (aura.uptime / player:GetTime())
			tooltip:AddDoubleLine(L["Uptime"], Skada:FormatPercent(uptime), nil, nil, nil, PercentToRGB(uptime))
		end
	end
end

Skada:RegisterModule("Buffs", function(L, P)
	local mod = Skada:NewModule("Buffs")
	local spellmod = mod:NewModule("Buff spell list")
	local playermod = spellmod:NewModule("Players list")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	-- list of spells that don't trigger SPELL_AURA_x events
	local speciallist = {
		[57669] = true -- Replenishment
	}

	local function log_specialaura(set, aura)
		if not set or (set == Skada.total and not P.totalidc) then return end
		if not aura or not aura.spellid then return end

		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		if player then
			local spell = player.auras and player.auras[aura.spellid]
			if not spell then
				player.auras = player.auras or {}
				player.auras[aura.spellid] = {school = aura.spellschool, type = aura.type, uptime = 0}
				spell = player.auras[aura.spellid]
			end
			spell.uptime = spell.uptime + 1
		end
	end

	local aura = {type = "BUFF"}
	local function handle_buff(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, spellschool, auratype)
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
			aura.spellschool = spellschool

			if event == "SPELL_PERIODIC_ENERGIZE" then
				Skada:DispatchSets(log_specialaura, aura)
			elseif event == "SPELL_AURA_APPLIED" then
				Skada:DispatchSets(log_auraapply, aura)
			elseif event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" then
				Skada:DispatchSets(log_aurarefresh, aura)
			elseif event == "SPELL_AURA_REMOVED" then
				Skada:DispatchSets(log_auraremove, aura)
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's targets"], label or L["Unknown"])
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's targets"], win.spellname or L["Unknown"])
		if not (win.spellid and set) then return end

		local players, count = set:GetAuraPlayers(win.spellid)
		if count > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for playername, player in pairs(players) do
				nr = nr + 1
				local d = win:actor(nr, player, nil, playername)

				d.value = player.uptime
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Uptime and Skada:FormatTime(d.value),
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, player.maxtime)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's buffs"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's buffs"], win.actorname or L["Unknown"])
		aura_update_func("BUFF", win, set, mod)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Buffs"], L[win.class]) or L["Buffs"]
		mod_update_func("BUFF", win, set, self)
	end

	do
		local function check_unit_buffs(unit, owner)
			if owner == nil and not UnitIsDeadOrGhost(unit) then
				local dstGUID, dstName = UnitGUID(unit), UnitName(unit)
				for i = 1, 40 do
					local _, rank, _, _, _, _, _, unitCaster, _, _, spellid = UnitBuff(unit, i)
					if spellid then
						if unitCaster and rank ~= SPELL_PASSIVE then
							handle_buff(nil, "SPELL_AURA_APPLIED", UnitGUID(unitCaster), UnitName(unitCaster), nil, dstGUID, dstName, nil, spellid, nil, nil, "BUFF")
						end
					else
						break -- nothing found!
					end
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
		local aura = actor and actor.auras and actor.auras[win.spellid]
		if aura then
			tooltip:AddLine(actor.name .. ": " .. win.spellname)
			if aura.school and spellschools and spellschools[aura.school] then
				tooltip:AddLine(spellschools(aura.school))
			end

			if aura.count then
				tooltip:AddDoubleLine(L["Count"], aura.count, 1, 1, 1)
			end
			if aura.refresh then
				tooltip:AddDoubleLine(L["Refresh"], aura.refresh, 1, 1, 1)
			end
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
end)

Skada:RegisterModule("Debuffs", function(L, _, _, C, new, _, clear)
	local mod = Skada:NewModule("Debuffs")
	local spellmod = mod:NewModule("Debuff spell list")
	local spelltargetmod = spellmod:NewModule("Debuff target list")
	local spellsourcemod = spellmod:NewModule("Debuff source list")
	local targetmod = mod:NewModule("Debuff target list")
	local targetspellmod = targetmod:NewModule("Debuff spell list")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	-- list of spells used to queue units.
	local queuedSpells = {[49005] = 50424}

	local aura = {type = "DEBUFF"}
	local function handle_debuff(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, spellschool, auratype)
		if spellid and not ignoredSpells[spellid] and auratype == "DEBUFF" then
			if srcName == nil and #srcGUID == 0 and dstName and #dstGUID > 0 then
				srcGUID = dstGUID
				srcName = dstName
				srcFlags = dstFlags
			end

			aura.playerid = srcGUID
			aura.playername = srcName
			aura.playerflags = srcFlags

			aura.dstGUID = dstGUID
			aura.dstName = dstName
			aura.dstFlags = dstFlags

			aura.spellid = spellid
			aura.spellschool = spellschool

			Skada:FixPets(aura)

			if event == "SPELL_AURA_APPLIED" then
				Skada:DispatchSets(log_auraapply, aura)
				if queuedSpells[spellid] then
					Skada:QueueUnit(queuedSpells[spellid], srcGUID, srcName, srcFlags, dstGUID)
				end
			elseif event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" then
				Skada:DispatchSets(log_aurarefresh, aura)
			elseif event == "SPELL_AURA_REMOVED" then
				Skada:DispatchSets(log_auraremove, aura)
				if queuedSpells[spellid] then
					Skada:UnqueueUnit(queuedSpells[spellid], dstGUID)
				end
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

		local auras, maxtime = player:GetDebuffsOnTarget(win.targetname)
		if auras and maxtime > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, aura in pairs(auras) do
				nr = nr + 1
				local d = win:spell(nr, spellid, aura)

				d.value = aura.uptime
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Uptime and Skada:FormatTime(d.value),
					mod.metadata.columns.Count and aura.count,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, maxtime)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function spelltargetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's <%s> targets"], win.actorname or L["Unknown"], label)
	end

	function spelltargetmod:Update(win, set)
		win.title = format(L["%s's <%s> targets"], win.actorname or L["Unknown"], win.spellname or L["Unknown"])
		if not win.spellid then return end

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		if not player then return end

		local targets, maxtime = player:GetDebuffTargets(win.spellid)
		if targets and maxtime > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:actor(nr, target, true, targetname)

				d.value = target.uptime
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Uptime and Skada:FormatTime(d.value),
					mod.metadata.columns.Count and target.count,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, maxtime)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function spellsourcemod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's sources"], label)
	end

	function spellsourcemod:Update(win, set)
		win.title = format(L["%s's sources"], win.spellname or L["Unknown"])
		if not win.spellid then return end

		local nr = 0
		for i = 1, #set.players do
			local player = set.players[i]
			local aura = player and player.auras and player.auras[win.spellid]
			if aura then
				nr = nr + 1
				local d = win:actor(nr, player)

				d.value = aura.uptime
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Uptime and Skada:FormatTime(d.value),
					mod.metadata.columns.Count and aura.count,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, player:GetTime())
				)
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's targets"], win.actorname or L["Unknown"])

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		if not player then return end

		local targets, maxtime = player:GetDebuffsTargets()
		if targets and maxtime > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:actor(nr, target, true, targetname)

				d.value = target.uptime
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Uptime and Skada:FormatTime(d.value),
					mod.metadata.columns.Count and target.count,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, maxtime)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor debuffs"](label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor debuffs"](win.actorname or L["Unknown"])
		aura_update_func("DEBUFF", win, set, mod)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Debuffs"], L[win.class]) or L["Debuffs"]
		mod_update_func("DEBUFF", win, set, self)
	end

	local function aura_target_tooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local actor = set and set:GetPlayer(win.actorid, win.actorname)
		local aura = actor and actor.auras and actor.auras[win.spellid]
		if aura and aura.targets and aura.targets[label] then
			tooltip:AddLine(actor.name .. ": " .. win.spellname)
			if aura.school and spellschools and spellschools[aura.school] then
				tooltip:AddLine(spellschools(aura.school))
			end

			if aura.targets[label].count then
				tooltip:AddDoubleLine(L["Count"], aura.targets[label].count, 1, 1, 1)
			end
			if aura.targets[label].refresh then
				tooltip:AddDoubleLine(L["Refresh"], aura.targets[label].refresh, 1, 1, 1)
			end
		end
	end

	local function aura_source_tooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local actor = set and set:GetPlayer(id, label)
		local aura = actor and actor.auras and actor.auras[win.spellid]
		if aura and aura.count then
			tooltip:AddLine(label .. ": " .. win.spellname)
			if aura.school and spellschools and spellschools[aura.school] then
				tooltip:AddLine(spellschools(aura.school))
			end

			tooltip:AddDoubleLine(L["Count"], aura.count, 1, 1, 1)
			if aura.refresh then
				tooltip:AddDoubleLine(L["Refresh"], aura.refresh, 1, 1, 1)
			end
		end
	end

	function mod:OnEnable()
		spelltargetmod.metadata = {tooltip = aura_target_tooltip}
		spellsourcemod.metadata = {showspots = true, tooltip = aura_source_tooltip}
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

	function playerPrototype:GetDebuffsTargets(tbl)
		if self.auras then
			tbl = clear(tbl or C)
			local maxtime = 0
			for _, aura in pairs(self.auras) do
				if aura.targets then
					maxtime = maxtime + aura.uptime
					for name, target in pairs(aura.targets) do
						if not tbl[name] then
							tbl[name] = new()
							tbl[name].count = target.count
							tbl[name].refresh = target.refresh
							tbl[name].uptime = target.uptime
						else
							tbl[name].count = tbl[name].count + target.count
							tbl[name].uptime = tbl[name].uptime + target.uptime
							if target.refresh then
								tbl[name].refresh = (tbl[name].refresh or 0) + target.refresh
							end
						end

						if not tbl[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								tbl[name].id = actor.id
								tbl[name].class = actor.class
								tbl[name].role = actor.role
								tbl[name].spec = actor.spec
							end
						end
					end
				end
			end
			return tbl, maxtime
		end
	end

	function playerPrototype:GetDebuffTargets(spellid, tbl)
		if self.auras and spellid and self.auras[spellid] and self.auras[spellid].targets then
			tbl = clear(tbl or C)
			local maxtime = self.auras[spellid].uptime
			for name, target in pairs(self.auras[spellid].targets) do
				tbl[name] = new()
				tbl[name].count = target.count
				tbl[name].refresh = target.refresh
				tbl[name].uptime = target.uptime
				local actor = self.super:GetActor(name)
				if actor then
					tbl[name].id = actor.id
					tbl[name].class = actor.class
					tbl[name].role = actor.role
					tbl[name].spec = actor.spec
				end
			end
			return tbl, maxtime
		end
	end

	function playerPrototype:GetDebuffsOnTarget(name, tbl)
		if self.auras and name then
			tbl = clear(tbl or C)
			local maxtime = 0
			for spellid, aura in pairs(self.auras) do
				if aura.targets and aura.targets[name] then
					maxtime = maxtime + aura.uptime
					tbl[spellid] = new()
					tbl[spellid].school = aura.school
					tbl[spellid].count = aura.targets[name].count
					tbl[spellid].refresh = aura.targets[name].refresh
					tbl[spellid].uptime = aura.targets[name].uptime
				end
			end
			return tbl, maxtime
		end
	end
end)