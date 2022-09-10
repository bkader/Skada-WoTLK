local Skada = Skada

-- cache frequently used globals
local pairs, format, pformat, max = pairs, string.format, Skada.pformat, math.max
local GetSpellInfo, T = Skada.GetSpellInfo or GetSpellInfo, Skada.Table
local _

-- ============== --
-- Healing module --
-- ============== --

Skada:RegisterModule("Healing", function(L, P, _, _, _, del)
	local mod = Skada:NewModule("Healing")
	local playermod = mod:NewModule("Healing spell list")
	local targetmod = mod:NewModule("Healed target list")
	local spellmod = targetmod:NewModule("Healing spell list")
	local spellschools = Skada.spellschools
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local passiveSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	local function log_spellcast(set, playerid, playername, playerflags, spellid, spellschool)
		if not set or (set == Skada.total and not P.totalidc) then return end

		local player = Skada:FindPlayer(set, playerid, playername, playerflags)
		if player and player.healspells and player.healspells[spellid] then
			-- because some HoTs don't have an initial amount
			-- we start from 1 and not from 0 if casts wasn't
			-- previously set. Otherwise we just increment.
			player.healspells[spellid].casts = (player.healspells[spellid].casts or 1) + 1

			-- fix possible missing spell school.
			if not player.healspells[spellid].school and spellschool then
				player.healspells[spellid].school = spellschool
			end
		end
	end

	local function log_heal(set, data, tick)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if not player then return end

		-- get rid of overheal
		local amount = max(0, data.amount - data.overheal)
		if player.role == "HEALER" and amount > 0 and not data.petname then
			Skada:AddActiveTime(set, player, data.spellid and not passiveSpells[data.spellid], nil, data.dstName)
		end

		-- record the healing
		player.heal = (player.heal or 0) + amount
		set.heal = (set.heal or 0) + amount

		-- record the overheal
		local overheal = (data.overheal > 0) and data.overheal or nil
		if overheal then
			player.overheal = (player.overheal or 0) + overheal
			set.overheal = (set.overheal or 0) + overheal
		end

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- record the spell
		local spellid = tick and -data.spellid or data.spellid
		local spell = player.healspells and player.healspells[spellid]
		if not spell then
			player.healspells = player.healspells or {}
			player.healspells[spellid] = {school = data.spellschool, amount = 0}
			spell = player.healspells[spellid]
		elseif not spell.school and data.spellschool then
			spell.school = data.spellschool
		end

		spell.count = (spell.count or 0) + 1
		spell.amount = spell.amount + amount

		if overheal then
			spell.o_amt = (spell.o_amt or 0) + overheal
		end

		if (not spell.min or amount < spell.min) and amount > 0 then
			spell.min = amount
		end
		if (not spell.max or amount > spell.max) and amount > 0 then
			spell.max = amount
		end

		if data.critical then
			spell.c_num = (spell.c_num or 0) + 1
			spell.c_amt = (spell.c_amt or 0) + amount

			if not spell.c_max or amount > spell.c_max then
				spell.c_max = amount
			end

			if not spell.c_min or amount < spell.c_min then
				spell.c_min = amount
			end
		end

		-- record the target
		if not data.dstName then return end
		local target = spell.targets and spell.targets[data.dstName]
		if not target then
			spell.targets = spell.targets or {}
			spell.targets[data.dstName] = {amount = 0}
			target = spell.targets[data.dstName]
		end
		target.amount = target.amount + amount

		if overheal then
			target.o_amt = (target.o_amt or 0) + overheal
		end
	end

	local heal = {}

	local function spell_cast(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID and dstGUID then
			local spellid, _, spellschool = ...
			if spellid and not ignoredSpells[spellid] then
				srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)
				Skada:DispatchSets(log_spellcast, srcGUID, srcName, srcFlags, spellid, spellschool)
			end
		end
	end

	local function spell_heal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...
		if spellid and not ignoredSpells[spellid] then
			srcGUID, srcName, srcFlags = Skada:FixUnit(spellid, srcGUID, srcName, srcFlags)

			heal.playerid = srcGUID
			heal.playername = srcName
			heal.playerflags = srcFlags

			heal.dstGUID = dstGUID
			heal.dstName = dstName
			heal.dstFlags = dstFlags

			heal.spellid, _, heal.spellschool, heal.amount, heal.overheal, _, heal.critical = ...

			heal.petname = nil
			Skada:FixPets(heal)

			Skada:DispatchSets(log_heal, heal, eventtype == "SPELL_PERIODIC_HEAL")
		end
	end

	local function healing_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(true)
		local hps, amount = actor:GetHPS()

		tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, totaltime), nil, nil, nil, 1, 1, 1)
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(amount), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(Skada:FormatNumber(amount) .. "/" .. suffix, Skada:FormatNumber(hps), 1, 1, 1)
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.healspells and actor.healspells[id]
		if not spell then return end

		tooltip:AddLine(actor.name .. " - " .. label)
		if spell.school and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if spell.casts and spell.casts > 0 then
			tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
		end

		local average = nil
		if spell.count and spell.count > 0 then
			tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
			average = spell.amount / spell.count

			if spell.c_num and spell.c_num > 0 then
				tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.c_num, spell.count), 0.67, 1, 0.67)
			end

			if spell.o_amt and spell.o_amt > 0 then
				tooltip:AddDoubleLine(L["Overheal"], Skada:FormatPercent(spell.o_amt, spell.o_amt + spell.amount), 1, 0.67, 0.67)
			end
		end

		local separator = nil

		if spell.min then
			tooltip:AddLine(" ")
			separator = true

			local spellmin = spell.min
			if spell.c_min and spell.c_min < spellmin then
				spellmin = spell.c_min
			end
			tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
		end

		if spell.max then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end

			local spellmax = spell.max
			if spell.c_max and spell.c_max > spellmax then
				spellmax = spell.c_max
			end
			tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spellmax), 1, 1, 1)
		end

		if average then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end

			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(average), 1, 1, 1)
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor heal spells"](win.actorname or L["Unknown"], label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor heal spells"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetHealOnTarget(win.targetname) or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for spellid, spell in pairs(actor.healspells) do
			if spell.targets and spell.targets[win.targetname] then
				nr = nr + 1
				local d = win:spell(nr, spellid, spell, nil, true)

				d.value = enemy and spell.targets[win.targetname] or spell.targets[win.targetname].amount or 0
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
					actortime and Skada:FormatNumber(d.value / actortime),
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor heal spells"](label)
	end

	function playermod:Update(win, set)
		win.title = L["actor heal spells"](win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.heal or 0

		if total == 0 or not actor.healspells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for spellid, spell in pairs(actor.healspells) do
			nr = nr + 1
			local d = win:spell(nr, spellid, spell, nil, true)

			d.value = spell.amount
			d.valuetext = Skada:FormatValueCols(
				mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
				actortime and Skada:FormatNumber(d.value / actortime),
				mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
			)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's healed targets"], win.actorname)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local total = actor.heal or 0
		local targets = (total > 0) and actor:GetHealTargets()

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for targetname, target in pairs(targets) do
			nr = nr + 1
			local d = win:actor(nr, target, nil, targetname)

			d.value = target.amount
			d.valuetext = Skada:FormatValueCols(
				mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
				actortime and Skada:FormatNumber(d.value / actortime),
				mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
			)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Healing"], L[win.class]) or L["Healing"]

		local total = set and set:GetHeal() or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		-- players
		for i = 1, #set.players do
			local player = set.players[i]
			if player and (not win.class or win.class == player.class) then
				local hps, amount = player:GetHPS()
				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, player)

					if Skada.forPVP and set.type == "arena" then
						d.color = Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN")
					end

					d.value = amount
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Healing and Skada:FormatNumber(d.value),
						self.metadata.columns.HPS and Skada:FormatNumber(hps),
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end

		-- arena enemies
		if not (Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyHeal) then return end
		for i = 1, #set.enemies do
			local enemy = set.enemies[i]
			if enemy and not enemy.fake and (not win.class or win.class == enemy.class) then
				local hps, amount = enemy:GetHPS()
				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, enemy, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")

					d.value = amount
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Healing and Skada:FormatNumber(d.value),
						self.metadata.columns.HPS and Skada:FormatNumber(hps),
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = playermod_tooltip}
		targetmod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			post_tooltip = healing_tooltip,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_nature_healingtouch]]
		}

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		local flags_src = {src_is_interesting = true}

		Skada:RegisterForCL(
			spell_cast,
			"SPELL_CAST_START",
			"SPELL_CAST_SUCCESS",
			flags_src
		)

		Skada:RegisterForCL(
			spell_heal,
			"SPELL_HEAL",
			"SPELL_PERIODIC_HEAL",
			flags_src
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, L["Absorbs and Healing"])

		-- table of ignored spells:
		if Skada.ignoredSpells then
			if Skada.ignoredSpells.heals then
				ignoredSpells = Skada.ignoredSpells.heals
			end
			if Skada.ignoredSpells.activeTime then
				passiveSpells = Skada.ignoredSpells.activeTime
			end
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local hps, amount = set:GetHPS()
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Healing and Skada:FormatNumber(amount),
			self.metadata.columns.HPS and Skada:FormatNumber(hps)
		)
		return valuetext, amount
	end

	function mod:CombatLeave()
		T.clear(heal)
	end

	function mod:SetComplete(set)
		-- clean healspells table!
		if (set.heal and set.heal > 0) or (set.overheal and set.overheal > 0) then
			for i = 1, #set.players do
				local p = set.players[i]
				if p and ((p.heal and (p.heal + (p.overheal or 0)) == 0) or (not p.heal and p.healspells)) then
					p.heal, p.overheal = nil, nil
					p.healspells = del(p.healspells, true)
				elseif p and p.healspells then
					for spellid, spell in pairs(p.healspells) do
						if (spell.amount + (spell.o_amt or 0)) == 0 then
							p.healspells[spellid] = del(p.healspells[spellid])
						end
					end
					if next(p.healspells) == nil then
						p.healspells = del(p.healspells)
					end
				end
			end
		end
	end
end)

-- ================== --
-- Overhealing module --
-- ================== --

Skada:RegisterModule("Overhealing", function(L)
	local mod = Skada:NewModule("Overhealing")
	local playermod = mod:NewModule("Overheal spell list")
	local targetmod = mod:NewModule("Overhealed target list")
	local spellmod = targetmod:NewModule("Overheal spell list")

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor overheal spells"](win.actorname or L["Unknown"], label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor overheal spells"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetOverhealOnTarget(win.targetname) or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for spellid, spell in pairs(actor.healspells) do
			if spell.targets and spell.targets[win.targetname] and spell.targets[win.targetname].o_amt and spell.targets[win.targetname].o_amt > 0 then
				nr = nr + 1
				local d = win:spell(nr, spellid, spell, nil, true)

				d.value = spell.targets[win.targetname].o_amt / (spell.targets[win.targetname].amount + spell.targets[win.targetname].o_amt)
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Overhealing and Skada:FormatNumber(spell.targets[win.targetname].o_amt),
					actortime and Skada:FormatNumber(spell.targets[win.targetname].o_amt / actortime),
					mod.metadata.columns.sPercent and Skada:FormatPercent(100 * d.value)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor overheal spells"](label)
	end

	function playermod:Update(win, set)
		win.title = L["actor overheal spells"](win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetOverheal() or 0

		if total == 0 or not actor.healspells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for spellid, spell in pairs(actor.healspells) do
			if spell.o_amt and spell.o_amt > 0 then
				nr = nr + 1
				local d = win:spell(nr, spellid, spell, nil, true)

				d.value = spell.o_amt / (spell.amount + spell.o_amt)
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Overhealing and Skada:FormatNumber(spell.o_amt),
					actortime and Skada:FormatNumber(spell.o_amt / actortime),
					mod.metadata.columns.sPercent and Skada:FormatPercent(100 * d.value)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's overheal targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's overheal targets"], win.actorname)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.overheal or 0
		local targets = (total > 0) and actor:GetOverhealTargets()

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for targetname, target in pairs(targets) do
			nr = nr + 1
			local d = win:actor(nr, target, nil, targetname)

			d.value = target.amount
			d.valuetext = Skada:FormatValueCols(
				mod.metadata.columns.Overhealing and Skada:FormatNumber(target.amount),
				actortime and Skada:FormatNumber(target.amount / actortime),
				mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, target.total)
			)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Overhealing"], L[win.class]) or L["Overhealing"]

		local total = set.overheal or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for i = 1, #set.players do
			local player = set.players[i]
			if player and (not win.class or win.class == player.class) then
				local ohps, overheal = player:GetOHPS()
				if overheal > 0 then
					nr = nr + 1
					local d = win:actor(nr, player)

					local overall = player.heal + player.overheal
					d.value = player.overheal
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Overhealing and Skada:FormatNumber(d.value),
						self.metadata.columns.HPS and Skada:FormatNumber(ohps),
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, overall)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:OnEnable()
		targetmod.metadata = {click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Overhealing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_holy_holybolt]]
		}

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local ohps, overheal = set:GetOHPS()
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Overhealing and Skada:FormatNumber(overheal),
			self.metadata.columns.HPS and Skada:FormatNumber(ohps)
		)
		return valuetext, overheal
	end
end, "Healing")

-- ==================== --
-- Total healing module --
-- ==================== --

Skada:RegisterModule("Total Healing", function(L)
	local mod = Skada:NewModule("Total Healing")
	local playermod = mod:NewModule("Healing spell list")
	local targetmod = mod:NewModule("Healed target list")
	local spellmod = targetmod:NewModule("Healing spell list")
	local spellschools = Skada.spellschools

	local function spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.healspells and actor.healspells[id]
		if not spell then return end

		tooltip:AddLine(actor.name .. " - " .. label)
		if spell.school and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if spell.casts then
			tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
		end

		local total = spell.amount + (spell.o_amt or 0)
		tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(total), 1, 1, 1)
		if spell.amount > 0 then
			tooltip:AddDoubleLine(L["Healing"], format("%s (%s)", Skada:FormatNumber(spell.amount), Skada:FormatPercent(spell.amount, total)), 0.67, 1, 0.67)
		end
		if spell.o_amt and spell.o_amt > 0 then
			tooltip:AddDoubleLine(L["Overheal"], format("%s (%s)", Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, total)), 1, 0.67, 0.67)
		end

		local separator = nil

		if spell.min then
			tooltip:AddLine(" ")
			separator = true

			local spellmin = spell.min
			if spell.c_min and spell.c_min < spellmin then
				spellmin = spell.c_min
			end
			tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
		end

		if spell.max then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end

			local spellmax = spell.max
			if spell.c_max and spell.c_max > spellmax then
				spellmax = spell.c_max
			end
			tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spellmax), 1, 1, 1)
		end

		if spell.count and spell.count > 0 then
			if not separator then
				tooltip:AddLine(" ")
				separator = true
			end

			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor heal spells"](win.actorname or L["Unknown"], label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor heal spells"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetTotalHealOnTarget(win.targetname) or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for spellid, spell in pairs(actor.healspells) do
			if spell.targets and spell.targets[win.targetname] then
				nr = nr + 1
				local d = win:spell(nr, spellid, spell, nil, true)

				if enemy then
					d.value = spell.targets[win.targetname]
				else
					d.value = spell.targets[win.targetname].amount
					if spell.targets[win.targetname].o_amt then
						d.value = d.value + spell.targets[win.targetname].o_amt
					end
				end

				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
					actortime and Skada:FormatNumber(d.value / actortime),
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor heal spells"](label)
	end

	function playermod:Update(win, set)
		win.title = L["actor heal spells"](win.actorname or L["Unknown"])
		if not win.actorname then return end

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetTotalHeal() or 0

		if total == 0 or not actor.healspells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for spellid, spell in pairs(actor.healspells) do
			local amount = spell.amount + (spell.o_amt or 0)
			if amount > 0 then
				nr = nr + 1
				local d = win:spell(nr, spellid, spell, nil, true)

				d.value = amount
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
					actortime and Skada:FormatNumber(d.value / actortime),
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's healed targets"], win.actorname)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetTotalHeal()
		local targets = (total > 0) and actor:GetTotalHealTargets()

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for targetname, target in pairs(targets) do
			nr = nr + 1
			local d = win:actor(nr, target, nil, targetname)

			d.value = target.amount
			d.valuetext = Skada:FormatValueCols(
				mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
				actortime and Skada:FormatNumber(d.value / actortime),
				mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
			)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Total Healing"], L[win.class]) or L["Total Healing"]

		local total = set and set:GetTotalHeal() or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		-- players
		for i = 1, #set.players do
			local player = set.players[i]
			if player and (not win.class or win.class == player.class) then
				local hps, amount = player:GetTHPS()
				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, player)

					if Skada.forPVP and set.type == "arena" then
						d.color = Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN")
					end

					d.value = amount
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Healing and Skada:FormatNumber(d.value),
						self.metadata.columns.HPS and Skada:FormatNumber(hps),
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end

		-- arena enemies
		if not (Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyHeal) then return end
		for i = 1, #set.enemies do
			local enemy = set.enemies[i]
			if enemy and not enemy.fake and (not win.class or win.class == enemy.class) then
				local hps, amount = enemy:GetHPS()
				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, enemy, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")

					d.value = amount
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Healing and Skada:FormatNumber(d.value),
						self.metadata.columns.HPS and Skada:FormatNumber(hps),
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:OnEnable()
		targetmod.metadata = {showspots = true, click1 = spellmod}
		playermod.metadata = {tooltip = spell_tooltip}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_holy_flashheal]]
		}

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local ops, amount = set:GetTHPS()
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Healing and Skada:FormatNumber(amount),
			self.metadata.columns.HPS and Skada:FormatNumber(ops)
		)
		return valuetext, amount
	end
end, "Healing")

-- ================ --
-- Healing taken --
-- ================ --

Skada:RegisterModule("Healing Taken", function(L, P, _, _, new, _, clear)
	local mod = Skada:NewModule("Healing Taken")
	local sourcemod = mod:NewModule("Healing source list")
	local sourcespellmod = sourcemod:NewModule("Healing spell list")
	local C = Skada.cacheTable2

	local get_healing_taken_list = nil
	local get_healing_taken_sources = nil

	local function healing_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local total = set and set:GetAbsorbHeal() or 0
		local players = (total > 0) and get_healing_taken_list(set)

		local player, actor = nil, nil
		if not players then
			return
		else
			actor = set:GetActor(label, id)
			if not actor then return end

			for n, p in pairs(players) do
				if n == label and p.id == id then
					player = p
					break
				end
			end
		end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(true)

		tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, totaltime), nil, nil, nil, 1, 1, 1)
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Healing Taken"], Skada:FormatNumber(player.amount), 1, 1, 1)

		if P.timemesure == 1 then
			tooltip:AddDoubleLine(Skada:FormatNumber(player.amount) .. "/" .. activetime, Skada:FormatNumber(player.amount / activetime), 1, 1, 1)
		else
			tooltip:AddDoubleLine(Skada:FormatNumber(player.amount) .. "/" .. totaltime, Skada:FormatNumber(player.amount / totaltime), 1, 1, 1)
		end
	end

	function sourcespellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor heal spells"](label, win.actorname or L["Unknown"])
	end

	function sourcespellmod:Update(win, set)
		win.title = L["actor heal spells"](win.targetname or L["Unknown"], win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.targetname, win.targetid)
		if enemy then return end -- unavailable for enemies yet

		local total = actor and actor:GetAbsorbHealOnTarget(win.actorname)

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0

		if actor.absorbspells then
			for spellid, spell in pairs(actor.absorbspells) do
				if spell.targets and spell.targets[win.actorname] then
					nr = nr + 1
					local d = win:spell(nr, spellid, spell)

					d.value = spell.targets[win.actorname]
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
						actortime and Skada:FormatNumber(d.value / actortime),
						mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end

		if actor.healspells then
			for spellid, spell in pairs(actor.healspells) do
				if spell.targets and spell.targets[win.actorname] then
					nr = nr + 1
					local d = win:spell(nr, spellid, spell, nil, true)

					d.value = enemy and spell.targets[win.actorname] or spell.targets[win.actorname].amount or 0
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
						actortime and Skada:FormatNumber(d.value / actortime),
						mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function sourcemod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's received healing"], label)
	end

	function sourcemod:Update(win, set)
		win.title = pformat(L["%s's received healing"], win.actorname)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unavailable for enemies yet

		local sources, total = get_healing_taken_sources(actor)

		if not sources or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
		for sourcename, source in pairs(C) do
			nr = nr + 1
			local d = win:actor(nr, source, nil, sourcename)

			d.value = source.amount
			d.valuetext = Skada:FormatValueCols(
				mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
				actortime and Skada:FormatNumber(d.value / actortime),
				mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
			)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Healing Taken"], L[win.class]) or L["Healing Taken"]

		local total = set and set:GetAbsorbHeal() or 0
		local players = (total > 0) and get_healing_taken_list(set)

		if not players then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for playername, player in pairs(players) do
			if not win.class or win.class == player.class then
				nr = nr + 1
				local d = win:actor(nr, player, nil, playername)

				d.value = player.amount
				d.valuetext = Skada:FormatValueCols(
					self.metadata.columns.Healing and Skada:FormatNumber(d.value),
					self.metadata.columns.HPS and Skada:FormatNumber(d.value / player.time),
					self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:OnEnable()
		sourcemod.metadata = {showspots = true, click1 = sourcespellmod}
		self.metadata = {
			showspots = true,
			post_tooltip = healing_tooltip,
			click1 = sourcemod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Healing = true, HPS = true, Percent = true, sHPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_nature_resistnature]]
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local settime = set:GetTime()
		local hps, value = set:GetAHPS()
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Healing and Skada:FormatNumber(value),
			self.metadata.columns.HPS and Skada:FormatNumber(value / settime)
		)
		return valuetext, value
	end

	---------------------------------------------------------------------------

	get_healing_taken_list = function(self, tbl)
		if not self.heal and not self.absorb then return end

		tbl = clear(tbl or C)

		-- healed by players.
		for i = 1, #self.players do
			local p = self.players[i]
			if p and p.absorbspells then
				for _, spell in pairs(p.absorbspells) do
					if spell.targets then
						for name, amount in pairs(spell.targets) do
							if amount > 0 then
								if not tbl[name] then
									tbl[name] = new()
									tbl[name].amount = amount
								else
									tbl[name].amount = tbl[name].amount + amount
								end

								if not tbl[name].class or not tbl[name].time then
									local actor = self:_fill_actor_table(tbl[name], name)
									tbl[name].time = actor and actor:GetTime() or self:GetTime()
								end
							end
						end
					end
				end
			end
			if p and p.healspells then
				for _, spell in pairs(p.healspells) do
					if spell.targets then
						for name, target in pairs(spell.targets) do
							if target.amount > 0 then
								if not tbl[name] then
									tbl[name] = new()
									tbl[name].amount = target.amount
									tbl[name].o_amt = target.o_amt
								else
									tbl[name].amount = tbl[name].amount + target.amount
									if target.o_amt then
										tbl[name].o_amt = (tbl[name].o_amt or 0) + target.o_amt
									end
								end

								if not tbl[name].class or not tbl[name].time then
									local actor = self:_fill_actor_table(tbl[name], name)
									tbl[name].time = actor and actor:GetTime() or self:GetTime()
								end
							end
						end
					end
				end
			end
		end

		if not self.enemies or not self.eheal then
			return tbl
		end

		-- healed by enemies.
		for i = 1, #self.enemies do
			local p = self.enemies[i]
			if p and p.healspells then
				for _, spell in pairs(p.healspells) do
					if spell.targets then
						for name, amount in pairs(spell.targets) do
							if amount > 0 then
								if not tbl[name] then
									tbl[name] = new()
									tbl[name].amount = amount
								else
									tbl[name].amount = tbl[name].amount + amount
								end

								if not tbl[name].class or not tbl[name].time then
									local actor = self:_fill_actor_table(tbl[name], name)
									tbl[name].time = actor and actor:GetTime() or self:GetTime()
								end
							end
						end
					end
				end
			end
		end

		return tbl
	end

	get_healing_taken_sources = function(self, tbl)
		local total = 0

		if self.super then
			tbl = clear(tbl or C)

			-- healed by players.
			for i = 1, #self.super.players do
				local p = self.super.players[i]
				if p and p.absorbspells then
					for spellid, spell in pairs(p.absorbspells) do
						if spell.targets and spell.targets[self.name] then
							local amount = spell.targets[self.name]
							if amount > 0 then
								total = total + amount

								if not tbl[p.name] then
									tbl[p.name] = new()
									tbl[p.name].id = p.id
									tbl[p.name].class = p.class
									tbl[p.name].role = p.role
									tbl[p.name].spec = p.spec
									tbl[p.name].amount = amount
								else
									tbl[p.name].amount = tbl[p.name].amount + amount
								end
							end
						end
					end
				end
				if p and p.healspells then
					for spellid, spell in pairs(p.healspells) do
						if spell.targets and spell.targets[self.name] then
							local amount = spell.targets[self.name].amount
							if amount > 0 then
								total = total + amount

								if not tbl[p.name] then
									tbl[p.name] = new()
									tbl[p.name].id = p.id
									tbl[p.name].class = p.class
									tbl[p.name].role = p.role
									tbl[p.name].spec = p.spec
									tbl[p.name].amount = amount
								else
									tbl[p.name].amount = tbl[p.name].amount + amount
								end
							end
						end
					end
				end
			end

			if not self.super.enemies or not self.super.eheal then
				return tbl, total
			end

			-- healed by enemies.
			for i = 1, #self.super.enemies do
				local p = self.super.enemies[i]
				if p and p.healspells then
					for spellid, spell in pairs(p.healspells) do
						if spell.targets and spell.targets[self.name] then
							local amount = spell.targets[self.name]
							if amount > 0 then
								total = total + amount

								if not tbl[p.name] then
									tbl[p.name] = new()
									tbl[p.name].id = p.id
									tbl[p.name].class = p.class
									tbl[p.name].role = p.role
									tbl[p.name].spec = p.spec
									tbl[p.name].amount = amount
								else
									tbl[p.name].amount = tbl[p.name].amount + amount
								end
							end
						end
					end
				end
			end
		end

		return tbl, total
	end
end, "Absorbs", "Healing")
