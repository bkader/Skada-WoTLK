local Skada = Skada

-- cache frequently used globals
local pairs, format, max = pairs, string.format, math.max
local GetSpellInfo, T = Skada.GetSpellInfo or GetSpellInfo, Skada.Table
local _

-- ============== --
-- Healing module --
-- ============== --

Skada:RegisterModule("Healing", function(L, P)
	if Skada:IsDisabled("Healing") then return end

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
		if player then
			-- get rid of overheal
			local amount = max(0, data.amount - data.overheal)
			if player.role == "HEALER" and amount > 0 and not data.petname then
				Skada:AddActiveTime(set, player, data.spellid and not passiveSpells[data.spellid])
			end

			-- record the healing
			player.heal = (player.heal or 0) + amount
			set.heal = (set.heal or 0) + amount

			-- record the overheal
			player.overheal = (player.overheal or 0) + data.overheal
			set.overheal = (set.overheal or 0) + data.overheal

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.total and not P.totalidc then return end

			-- record the spell
			local spell = player.healspells and player.healspells[data.spellid]
			if not spell then
				player.healspells = player.healspells or {}
				player.healspells[data.spellid] = {school = data.spellschool, amount = 0, overheal = 0}
				spell = player.healspells[data.spellid]
			elseif not spell.school and data.spellschool then
				spell.school = data.spellschool
			end

			spell.ishot = tick or nil
			spell.count = (spell.count or 0) + 1
			spell.amount = spell.amount + amount
			spell.overheal = spell.overheal + data.overheal

			if (not spell.min or amount < spell.min) and amount > 0 then
				spell.min = amount
			end
			if (not spell.max or amount > spell.max) and amount > 0 then
				spell.max = amount
			end

			if data.critical then
				spell.critical = (spell.critical or 0) + 1
				spell.criticalamount = (spell.criticalamount or 0) + amount

				if not spell.criticalmax or amount > spell.criticalmax then
					spell.criticalmax = amount
				end

				if not spell.criticalmin or amount < spell.criticalmin then
					spell.criticalmin = amount
				end
			end

			-- record the target
			if data.dstName then
				local target = spell.targets and spell.targets[data.dstName]
				if not target then
					spell.targets = spell.targets or {}
					spell.targets[data.dstName] = {amount = 0, overheal = 0}
					target = spell.targets[data.dstName]
				end
				target.amount = target.amount + amount
				target.overheal = target.overheal + data.overheal
			end
		end
	end

	local heal = {}

	local function SpellCast(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID and dstGUID then
			local spellid, _, spellschool = ...
			if spellid and not ignoredSpells[spellid] then
				srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)
				Skada:DispatchSets(log_spellcast, srcGUID, srcName, srcFlags, spellid, spellschool)
			end
		end
	end

	local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
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
		if actor then
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
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.healspells and actor.healspells[id]

		if spell then
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

				if spell.critical and spell.critical > 0 then
					tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.critical, spell.count), 0.67, 1, 0.67)
				end

				if spell.overheal and spell.overheal > 0 then
					tooltip:AddDoubleLine(L["Overheal"], Skada:FormatPercent(spell.overheal, spell.overheal + spell.amount), 1, 0.67, 0.67)
				end
			end

			local separator = nil

			if spell.min then
				tooltip:AddLine(" ")
				separator = true

				local spellmin = spell.min
				if spell.criticalmin and spell.criticalmin < spellmin then
					spellmin = spell.criticalmin
				end
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
			end

			if spell.max then
				if not separator then
					tooltip:AddLine(" ")
					separator = true
				end

				local spellmax = spell.max
				if spell.criticalmax and spell.criticalmax > spellmax then
					spellmax = spell.criticalmax
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

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
			for spellid, spell in pairs(actor.healspells) do
				if spell.targets and spell.targets[win.targetname] then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)
					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					if enemy then
						d.value = spell.targets[win.targetname]
					else
						d.value = spell.targets[win.targetname].amount or 0
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

		if total > 0 and actor.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
			for spellid, spell in pairs(actor.healspells) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = spellid
				d.spellid = spellid
				d.spellschool = spell.school
				d.label, _, d.icon = GetSpellInfo(spellid)
				if spell.ishot then
					d.text = d.label .. L["HoT"]
				end

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
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's healed targets"], win.actorname or L["Unknown"])

		local actor = set and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local total = actor.heal or 0
		local targets = (total > 0) and actor:GetHealTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

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
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Healing"], L[win.class]) or L["Healing"]

		local total = set and set:GetHeal() or 0
		if total > 0 then
			if win.metadata then
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
						local d = win:nr(nr)

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

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
			if Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyHeal then
				for i = 1, #set.enemies do
					local enemy = set.enemies[i]
					if enemy and not enemy.fake and (not win.class or win.class == enemy.class) then
						local hps, amount = enemy:GetHPS()
						if amount > 0 then
							nr = nr + 1
							local d = win:nr(nr)

							d.id = enemy.id or enemy.name
							d.label = enemy.name
							d.text = nil
							d.class = enemy.class
							d.role = enemy.role
							d.spec = enemy.spec
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
			SpellCast,
			"SPELL_CAST_START",
			"SPELL_CAST_SUCCESS",
			flags_src
		)

		Skada:RegisterForCL(
			SpellHeal,
			"SPELL_HEAL",
			"SPELL_PERIODIC_HEAL",
			flags_src
		)

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

	function mod:SetComplete(set)
		T.clear(heal)

		-- clean healspells table!
		if (set.heal and set.heal > 0) or (set.overheal and set.overheal > 0) then
			for i = 1, #set.players do
				local p = set.players[i]
				if p and p.heal and (p.heal + p.overheal) == 0 then
					p.healspells = nil
				elseif p and p.healspells then
					for spellid, spell in pairs(p.healspells) do
						if (spell.amount + spell.overheal) == 0 then
							p.healspells[spellid] = nil
						end
					end
					if next(p.healspells) == nil then
						p.healspells = nil
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
	if Skada:IsDisabled("Healing", "Overhealing") then return end

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

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
			for spellid, spell in pairs(actor.healspells) do
				if spell.targets and spell.targets[win.targetname] and spell.targets[win.targetname].overheal and spell.targets[win.targetname].overheal > 0 then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)
					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					d.value = spell.targets[win.targetname].overheal / (spell.targets[win.targetname].amount + spell.targets[win.targetname].overheal)
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Overhealing and Skada:FormatNumber(spell.targets[win.targetname].overheal),
						actortime and Skada:FormatNumber(spell.targets[win.targetname].overheal / actortime),
						mod.metadata.columns.sPercent and Skada:FormatPercent(100 * d.value)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
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

		if total > 0 and actor.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
			for spellid, spell in pairs(actor.healspells) do
				if spell.overheal and spell.overheal > 0 then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)

					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					d.value = spell.overheal / (spell.amount + spell.overheal)
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Overhealing and Skada:FormatNumber(spell.overheal),
						actortime and Skada:FormatNumber(spell.overheal / actortime),
						mod.metadata.columns.sPercent and Skada:FormatPercent(100 * d.value)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's overheal targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's overheal targets"], win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.overheal or 0
		local targets = (total > 0) and actor:GetOverhealTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.amount / target.total
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Overhealing and Skada:FormatNumber(target.amount),
					actortime and Skada:FormatNumber(target.amount / actortime),
					mod.metadata.columns.sPercent and Skada:FormatPercent(100 * d.value)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Overhealing"], L[win.class]) or L["Overhealing"]

		local total = set.overheal or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for i = 1, #set.players do
				local player = set.players[i]
				if player and (not win.class or win.class == player.class) then
					local ohps, overheal = player:GetOHPS()
					if overheal > 0 then
						nr = nr + 1
						local d = win:nr(nr)

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

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
end)

-- ==================== --
-- Total healing module --
-- ==================== --

Skada:RegisterModule("Total Healing", function(L)
	if Skada:IsDisabled("Healing", "Total Healing") then return end

	local mod = Skada:NewModule("Total Healing")
	local playermod = mod:NewModule("Healing spell list")
	local targetmod = mod:NewModule("Healed target list")
	local spellmod = targetmod:NewModule("Healing spell list")
	local spellschools = Skada.spellschools

	local function spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.healspells and actor.healspells[id]
		if spell then
			tooltip:AddLine(actor.name .. " - " .. label)
			if spell.school and spellschools[spell.school] then
				tooltip:AddLine(spellschools(spell.school))
			end

			if spell.casts then
				tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
			end

			local total = spell.amount + (spell.overheal or 0)
			tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(total), 1, 1, 1)
			if spell.amount > 0 then
				tooltip:AddDoubleLine(L["Healing"], format("%s (%s)", Skada:FormatNumber(spell.amount), Skada:FormatPercent(spell.amount, total)), 0.67, 1, 0.67)
			end
			if spell.overheal and spell.overheal > 0 then
				tooltip:AddDoubleLine(L["Overheal"], format("%s (%s)", Skada:FormatNumber(spell.overheal), Skada:FormatPercent(spell.overheal, total)), 1, 0.67, 0.67)
			end

			local separator = nil

			if spell.min then
				tooltip:AddLine(" ")
				separator = true

				local spellmin = spell.min
				if spell.criticalmin and spell.criticalmin < spellmin then
					spellmin = spell.criticalmin
				end
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
			end

			if spell.max then
				if not separator then
					tooltip:AddLine(" ")
					separator = true
				end

				local spellmax = spell.max
				if spell.criticalmax and spell.criticalmax > spellmax then
					spellmax = spell.criticalmax
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
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
			for spellid, spell in pairs(actor.healspells) do
				if spell.targets and spell.targets[win.targetname] then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)
					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					if enemy then
						d.value = spell.targets[win.targetname]
					else
						d.value = spell.targets[win.targetname].amount
						if spell.targets[win.targetname].overheal then
							d.value = d.value + spell.targets[win.targetname].overheal
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

		if total > 0 and actor.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
			for spellid, spell in pairs(actor.healspells) do
				local amount = spell.amount + (spell.overheal or 0)
				if amount > 0 then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)

					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

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
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's healed targets"], win.actorname or L["Unknown"])

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetTotalHeal()
		local targets = (total > 0) and actor:GetTotalHealTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

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
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Total Healing"], L[win.class]) or L["Total Healing"]

		local total = set and set:GetTotalHeal() or 0
		if total > 0 then
			if win.metadata then
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
						local d = win:nr(nr)

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

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
			if Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyHeal then
				for i = 1, #set.enemies do
					local enemy = set.enemies[i]
					if enemy and not enemy.fake and (not win.class or win.class == enemy.class) then
						local hps, amount = enemy:GetHPS()
						if amount > 0 then
							nr = nr + 1
							local d = win:nr(nr)

							d.id = enemy.id or enemy.name
							d.label = enemy.name
							d.text = nil
							d.class = enemy.class
							d.role = enemy.role
							d.spec = enemy.spec
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
end)

-- ================ --
-- Healing taken --
-- ================ --

Skada:RegisterModule("Healing Taken", function(L, _, _, _, new, _, clear)
	if Skada:IsDisabled("Healing", "Absorbs", "Absorbs and Healing", "Healing Taken") then return end

	local mod = Skada:NewModule("Healing Taken")
	local sourcemod = mod:NewModule("Healing source list")
	local sourcespellmod = sourcemod:NewModule("Healing spell list")
	local C = Skada.cacheTable2

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

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0

			if actor.absorbspells then
				for spellid, spell in pairs(actor.absorbspells) do
					if spell.targets and spell.targets[win.actorname] then
						nr = nr + 1
						local d = win:nr(nr)

						d.id = spellid
						d.spellid = spellid
						d.spellschool = spell.school
						d.label, _, d.icon = GetSpellInfo(spellid)

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
						local d = win:nr(nr)

						d.id = spellid
						d.spellid = spellid
						d.spellschool = spell.school
						d.label, _, d.icon = GetSpellInfo(spellid)
						if spell.ishot then
							d.text = d.label .. L["HoT"]
						end

						if enemy then
							d.value = spell.targets[win.actorname]
						else
							d.value = spell.targets[win.actorname].amount
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
		end
	end

	function sourcemod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's received healing"], label)
	end

	function sourcemod:Update(win, set)
		win.title = format(L["%s's received healing"], win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unavailable for enemies yet

		local sources, total = actor:GetAbsorbHealSources()
		if sources and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sHPS and actor:GetTime(), 0
			for sourcename, source in pairs(C) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = source.id
				d.label = sourcename
				d.text = source.id and Skada:FormatName(sourcename, source.id)
				d.class = source.class
				d.role = source.role
				d.spec = source.spec

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
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Healing Taken"], L[win.class]) or L["Healing Taken"]

		local total = set and set:GetAbsorbHeal() or 0
		local players = (total > 0) and set:GetAbsorbHealTaken()

		if players then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for playername, player in pairs(players) do
				if not win.class or win.class == player.class then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = player.id or playername
					d.label = playername
					d.text = player.id and Skada:FormatName(playername, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

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
	end

	function mod:OnEnable()
		sourcemod.metadata = {showspots = true, click1 = sourcespellmod}
		self.metadata = {
			showspots = true,
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

	local setPrototype = Skada.setPrototype
	local actorPrototype = Skada.actorPrototype

	function setPrototype:GetAbsorbHealTaken(tbl)
		if self.heal or self.absorb then
			tbl = clear(tbl or C)

			-- healed by players.
			for i = 1, #self.players do
				local p = self.players[i]
				if p and p.absorbspells then
					for _, spell in pairs(p.absorbspells) do
						if spell.targets then
							for name, amount in pairs(spell.targets) do
								if not tbl[name] then
									tbl[name] = new()
									tbl[name].amount = amount
								else
									tbl[name].amount = tbl[name].amount + amount
								end
								if not tbl[name].class or not tbl[name].time then
									local actor = self:GetActor(name)
									if actor then
										if not tbl[name].class then
											tbl[name].id = actor.id
											tbl[name].class = actor.class
											tbl[name].role = actor.role
											tbl[name].spec = actor.spec
										end
										if not tbl[name].time then
											tbl[name].time = actor:GetTime()
										end
									else
										tbl[name].time = self:GetTime()
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
								if not tbl[name] then
									tbl[name] = new()
									tbl[name].amount = target.amount
									tbl[name].overheal = target.overheal
								else
									tbl[name].amount = tbl[name].amount + target.amount
									if target.overheal then
										tbl[name].overheal = (tbl[name].overheal or 0) + target.overheal
									end
								end
								if not tbl[name].class or not tbl[name].time then
									local actor = self:GetActor(name)
									if actor then
										if not tbl[name].class then
											tbl[name].id = actor.id
											tbl[name].class = actor.class
											tbl[name].role = actor.role
											tbl[name].spec = actor.spec
										end
										if not tbl[name].time then
											tbl[name].time = actor:GetTime()
										end
									else
										tbl[name].time = self:GetTime()
									end
								end
							end
						end
					end
				end
			end

			-- healed by enemies.
			if self.enemies and self.eheal then
				for i = 1, #self.enemies do
					local p = self.enemies[i]
					if p and p.healspells then
						for _, spell in pairs(p.healspells) do
							if spell.targets then
								for name, target in pairs(spell.targets) do
									if not tbl[name] then
										tbl[name] = new()
										tbl[name].amount = target.amount
										tbl[name].overheal = target.overheal
									else
										tbl[name].amount = tbl[name].amount + target.amount
										if target.overheal then
											tbl[name].overheal = (tbl[name].overheal or 0) + target.overheal
										end
									end
									if not tbl[name].class or not tbl[name].time then
										local actor = self:GetActor(name)
										if actor then
											if not tbl[name].class then
												tbl[name].id = actor.id
												tbl[name].class = actor.class
												tbl[name].role = actor.role
												tbl[name].spec = actor.spec
											end
											if not tbl[name].time then
												tbl[name].time = actor:GetTime()
											end
										else
											tbl[name].time = self:GetTime()
										end
									end
								end
							end
						end
					end
				end
			end
		end

		return tbl
	end

	function actorPrototype:GetAbsorbHealSources(tbl)
		local total = 0

		if self.super then
			tbl = clear(tbl or C)

			-- healed by players.
			for i = 1, #self.super.players do
				local p = self.super.players[i]
				if p and p.absorbspells then
					for spellid, spell in pairs(p.absorbspells) do
						if spell.targets and spell.targets[self.name] then
							total = total + spell.amount
							if not tbl[p.name] then
								tbl[p.name] = new()
								tbl[p.name].id = p.id
								tbl[p.name].class = p.class
								tbl[p.name].role = p.role
								tbl[p.name].spec = p.spec
								tbl[p.name].amount = spell.targets[self.name]
							else
								tbl[p.name].amount = tbl[p.name].amount + spell.targets[self.name]
							end
						end
					end
				end
				if p and p.healspells then
					for spellid, spell in pairs(p.healspells) do
						if spell.targets and spell.targets[self.name] then
							total = total + spell.amount
							if not tbl[p.name] then
								tbl[p.name] = new()
								tbl[p.name].id = p.id
								tbl[p.name].class = p.class
								tbl[p.name].role = p.role
								tbl[p.name].spec = p.spec
								tbl[p.name].amount = spell.targets[self.name].amount
							else
								tbl[p.name].amount = tbl[p.name].amount + spell.targets[self.name].amount
							end
						end
					end
				end
			end

			-- healed by enemies.
			if self.super.enemies and self.super.eheal then
				for i = 1, #self.super.enemies do
					local p = self.super.enemies[i]
					if p and p.healspells then
						for spellid, spell in pairs(p.healspells) do
							if spell.targets and spell.targets[self.name] then
								total = total + spell.amount
								if not tbl[p.name] then
									tbl[p.name] = new()
									tbl[p.name].id = p.id
									tbl[p.name].class = p.class
									tbl[p.name].role = p.role
									tbl[p.name].spec = p.spec
									tbl[p.name].amount = spell.targets[self.name].amount
								else
									tbl[p.name].amount = tbl[p.name].amount + spell.targets[self.name].amount
								end
							end
						end
					end
				end
			end
		end

		return tbl, total
	end
end)