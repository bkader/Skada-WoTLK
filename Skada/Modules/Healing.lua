local Skada = Skada

-- cache frequently used globals
local pairs, ipairs, select, format, max = pairs, ipairs, select, string.format, math.max
local GetSpellInfo, unitClass = Skada.GetSpellInfo or GetSpellInfo, Skada.unitClass
local T = Skada.Table
local _

-- ============== --
-- Healing module --
-- ============== --

Skada:AddLoadableModule("Healing", function(L)
	if Skada:IsDisabled("Healing") then return end

	local mod = Skada:NewModule(L["Healing"])
	local playermod = mod:NewModule(L["Healing spell list"])
	local targetmod = mod:NewModule(L["Healed target list"])
	local spellmod = targetmod:NewModule(L["Healing spell list"])
	local tContains = tContains

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_spellcast(set, heal)
		local player = Skada:GetPlayer(set, heal.playerid, heal.playername, heal.playerflags)
		if player and player.healspells and player.healspells[heal.spellid] then
			-- because some HoTs don't have an initial amount
			-- we start from 1 and not from 0 if casts wasn't
			-- previously set. Otherwise we just increment.
			player.healspells[heal.spellid].casts = (player.healspells[heal.spellid].casts or 1) + 1

			-- fix possible missing spell school.
			if not player.healspells[heal.spellid].school and heal.spellschool then
				player.healspells[heal.spellid].school = heal.spellschool
			end
		end
	end

	local function log_heal(set, data, tick)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			-- get rid of overheal
			local amount = max(0, data.amount - data.overheal)
			Skada:AddActiveTime(player, (player.role == "HEALER" and amount > 0 and not data.petname))

			-- record the healing
			player.heal = (player.heal or 0) + amount
			set.heal = (set.heal or 0) + amount

			-- record the overheal
			player.overheal = (player.overheal or 0) + data.overheal
			set.overheal = (set.overheal or 0) + data.overheal

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.total then return end

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
				local actor = Skada:GetActor(set, data.dstGUID, data.dstName, data.dstFlags)
				if not actor then return end
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
			heal.spellid, _, heal.spellschool = ...
			if heal.spellid and not tContains(ignoredSpells, heal.spellid) then
				heal.playerid = srcGUID
				heal.playername = srcName
				heal.playerflags = srcFlags

				heal.dstGUID = dstGUID
				heal.dstName = dstName
				heal.dstFlags = dstFlags

				heal.amount = nil
				heal.overheal = nil
				heal.critical = nil
				heal.petname = nil

				Skada:FixPets(heal)

				Skada:DispatchSets(log_spellcast, heal)
			end
		end
	end

	local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...
		if spellid and not tContains(ignoredSpells, spellid) then
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
			log_heal(Skada.total, heal, eventtype == "SPELL_PERIODIC_HEAL")
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

			local suffix = Skada:FormatTime(Skada.db.profile.timemesure == 1 and activetime or totaltime)
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
			if spell.school and Skada.spellschools[spell.school] then
				tooltip:AddLine(
					Skada.spellschools[spell.school].name,
					Skada.spellschools[spell.school].r,
					Skada.spellschools[spell.school].g,
					Skada.spellschools[spell.school].b
				)
			end

			if (spell.casts or 0) > 0 then
				tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
			end

			if (spell.count or 0) > 0 then
				tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)

				if (spell.critical or 0) > 0 then
					tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.critical, spell.count), 1, 1, 1)
				end

				if spell.overheal > 0 then
					tooltip:AddDoubleLine(L["Overheal"], Skada:FormatPercent(spell.overheal, spell.overheal + spell.amount), 1, 1, 1)
				end
			else
				tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(spell.amount), 1, 1, 1)
			end

			if spell.min and spell.max then
				local spellmin = spell.min
				if spell.criticalmin and spell.criticalmin < spellmin then
					spellmin = spell.criticalmin
				end
				local spellmax = spell.max
				if spell.criticalmax and spell.criticalmax > spellmax then
					spellmax = spell.criticalmax
				end
				tooltip:AddLine(" ")
				tooltip:AddDoubleLine(L["Minimum Hit"], Skada:FormatNumber(spellmin), 1, 1, 1)
				tooltip:AddDoubleLine(L["Maximum Hit"], Skada:FormatNumber(spellmax), 1, 1, 1)
				tooltip:AddDoubleLine(L["Average Hit"], Skada:FormatNumber((spellmin + spellmax) / 2), 1, 1, 1)
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healing on %s"], win.actorname or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's healing on %s"], win.actorname or L.Unknown, win.targetname or L.Unknown)
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetHealOnTarget(win.targetname) or 0

		if total > 0 and actor.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
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
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = format(L["%s's healing spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's healing spells"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.heal or 0

		if total > 0 and actor.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
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
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = format(L["%s's healed targets"], win.actorname or L.Unknown)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local total = actor.heal or 0
		local targets = (total > 0) and actor:GetHealTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
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
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
			for _, player in ipairs(set.players) do
				if not win.class or win.class == player.class then
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
							d.color = set.gold and Skada.classcolors.ARENA_GOLD or Skada.classcolors.ARENA_GREEN
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
				for _, enemy in ipairs(set.enemies) do
					if not win.class or win.class == enemy.class then
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
							d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.ARENA_GOLD

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
			nototalclick = {playermod, targetmod},
			columns = {Healing = true, HPS = true, Percent = true},
			icon = [[Interface\Icons\spell_nature_healingtouch]]
		}

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
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		if not set then return end
		local hps, amount = set:GetHPS()
		return Skada:FormatValueCols(
			self.metadata.columns.Healing and Skada:FormatNumber(amount),
			self.metadata.columns.HPS and Skada:FormatNumber(hps)
		), amount
	end

	function mod:SetComplete(set)
		T.clear(heal)

		-- clean healspells table!
		if (set.heal or 0) > 0 or (set.overheal or 0) > 0 then
			for _, p in ipairs(set.players) do
				if p.heal and (p.heal + p.overheal) == 0 then
					p.healspells = nil
				elseif p.healspells then
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

Skada:AddLoadableModule("Overhealing", function(L)
	if Skada:IsDisabled("Healing", "Overhealing") then return end

	local mod = Skada:NewModule(L["Overhealing"])
	local playermod = mod:NewModule(L["Overheal spell list"])
	local targetmod = mod:NewModule(L["Overhealed target list"])
	local spellmod = targetmod:NewModule(L["Overheal spell list"])

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's overhealing on %s"], win.actorname or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's overhealing on %s"], win.actorname or L.Unknown, win.targetname or L.Unknown)
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetOverhealOnTarget(win.targetname) or 0

		if total > 0 and actor.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(actor.healspells) do
				if spell.targets and spell.targets[win.targetname] and (spell.targets[win.targetname].overheal or 0) > 0 then
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
						mod.metadata.columns.Percent and Skada:FormatPercent(100 * d.value)
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
		win.title = format(L["%s's overheal spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's overheal spells"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetOverheal() or 0

		if total > 0 and actor.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(actor.healspells) do
				if (spell.overheal or 0) > 0 then
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
						mod.metadata.columns.Percent and Skada:FormatPercent(100 * d.value)
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
		win.title = format(L["%s's overhealed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's overhealed targets"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.overheal or 0
		local targets = (total > 0) and actor:GetOverhealTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
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
					mod.metadata.columns.Percent and Skada:FormatPercent(100 * d.value)
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
			for _, player in ipairs(set.players) do
				if not win.class or win.class == player.class then
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

						local total = player.heal + player.overheal
						d.value = player.overheal
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.Overhealing and Skada:FormatNumber(d.value),
							self.metadata.columns.HPS and Skada:FormatNumber(ohps),
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

	function mod:OnEnable()
		targetmod.metadata = {click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod, targetmod},
			columns = {Overhealing = true, HPS = true, Percent = true},
			icon = [[Interface\Icons\spell_holy_holybolt]]
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		if not set then return end
		local ohps, overheal = set:GetOHPS()
		return Skada:FormatValueCols(
			self.metadata.columns.Overhealing and Skada:FormatNumber(overheal),
			self.metadata.columns.HPS and Skada:FormatNumber(ohps)
		)
	end
end)

-- ==================== --
-- Total healing module --
-- ==================== --

Skada:AddLoadableModule("Total Healing", function(L)
	if Skada:IsDisabled("Healing", "Total Healing") then return end

	local mod = Skada:NewModule(L["Total Healing"])
	local playermod = mod:NewModule(L["Healing spell list"])
	local targetmod = mod:NewModule(L["Healed target list"])
	local spellmod = targetmod:NewModule(L["Healing spell list"])

	local function spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.healspells and actor.healspells[id]
		if spell then
			tooltip:AddLine(actor.name .. " - " .. label)
			if spell.school and Skada.spellschools[spell.school] then
				tooltip:AddLine(
					Skada.spellschools[spell.school].name,
					Skada.spellschools[spell.school].r,
					Skada.spellschools[spell.school].g,
					Skada.spellschools[spell.school].b
				)
			end

			if (spell.casts or 0) > 0 then
				tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
			end

			if (spell.count or 0) > 0 then
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
			end

			local total = spell.amount + (spell.overheal or 0)
			tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(total), 1, 1, 1)
			if spell.amount > 0 then
				tooltip:AddDoubleLine(L["Healing"], format("%s (%s)", Skada:FormatNumber(spell.amount), Skada:FormatPercent(spell.amount, total)), 1, 1, 1)
			end
			if (spell.overheal or 0) > 0 then
				tooltip:AddDoubleLine(L["Overheal"], format("%s (%s)", Skada:FormatNumber(spell.overheal), Skada:FormatPercent(spell.overheal, total)), 1, 1, 1)
			end

			if spell.min and spell.max then
				local spellmin = spell.min
				if spell.criticalmin and spell.criticalmin < spellmin then
					spellmin = spell.criticalmin
				end
				local spellmax = spell.max
				if spell.criticalmax and spell.criticalmax > spellmax then
					spellmax = spell.criticalmax
				end
				tooltip:AddLine(" ")
				tooltip:AddDoubleLine(L["Minimum Hit"], Skada:FormatNumber(spellmin), 1, 1, 1)
				tooltip:AddDoubleLine(L["Maximum Hit"], Skada:FormatNumber(spellmax), 1, 1, 1)
				tooltip:AddDoubleLine(L["Average Hit"], Skada:FormatNumber((spellmin + spellmax) / 2), 1, 1, 1)
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healing on %s"], win.actorname or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's healing on %s"], win.actorname or L.Unknown, win.targetname or L.Unknown)
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetTotalHealOnTarget(win.targetname) or 0
		if total > 0 and actor.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
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
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = format(L["%s's healing spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's healing spells"], win.actorname or L.Unknown)
		if not win.actorname then return end

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetTotalHeal() or 0

		if total > 0 and actor.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
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
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = format(L["%s's healed targets"], win.actorname or L.Unknown)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetTotalHeal()
		local targets = (total > 0) and actor:GetTotalHealTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
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
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
			for _, player in ipairs(set.players) do
				if not win.class or win.class == player.class then
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
							d.color = set.gold and Skada.classcolors.ARENA_GOLD or Skada.classcolors.ARENA_GREEN
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
				for _, enemy in ipairs(set.enemies) do
					if not win.class or win.class == enemy.class then
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
							d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.ARENA_GOLD

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
			nototalclick = {playermod, targetmod},
			columns = {Healing = true, HPS = true, Percent = true},
			icon = [[Interface\Icons\spell_holy_flashheal]]
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		if not set then return end
		local ops, amount = set:GetTHPS()
		return Skada:FormatValueCols(
			self.metadata.columns.Healing and Skada:FormatNumber(amount),
			self.metadata.columns.HPS and Skada:FormatNumber(ops)
		), amount
	end
end)

-- ================ --
-- Healing taken --
-- ================ --

Skada:AddLoadableModule("Healing Taken", function(L)
	if Skada:IsDisabled("Healing", "Absorbs", "Absorbs and Healing", "Healing Taken") then return end

	local mod = Skada:NewModule(L["Healing Taken"])
	local sourcemod = mod:NewModule(L["Healing source list"])
	local spellmod = sourcemod:NewModule(L["Healing spell list"])
	local cacheTable, wipe = T.get("Skada_CacheTable2"), wipe

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healing on %s"], win.actorname or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's healing on %s"], win.actorname or L.Unknown, win.targetname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.targetname, win.targetid)
		if enemy then return end -- unavailable for enemies yet

		local total = actor and actor:GetAbsorbHealOnTarget(win.actorname)

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
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
							mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
							mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = format(L["%s's received healing"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unavailable for enemies yet

		local sources, total = actor:GetAbsorbHealSources()
		if sources and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for sourcename, source in pairs(cacheTable) do
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
					mod.metadata.columns.Overhealing and Skada:FormatNumber(source.overheal or 0),
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
						mod.metadata.columns.Healing and Skada:FormatNumber(d.value),
						mod.metadata.columns.Overhealing and Skada:FormatNumber(player.overheal),
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:OnEnable()
		sourcemod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = sourcemod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Healing = true, Overhealing = true, Percent = true},
			icon = [[Interface\Icons\spell_nature_resistnature]]
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local amount = set and set:GetAbsorbHeal() or 0
		return Skada:FormatNumber(amount), amount
	end

	---------------------------------------------------------------------------

	local setPrototype = Skada.setPrototype
	local playerPrototype = Skada.playerPrototype

	function setPrototype:GetAbsorbHealTaken(tbl)
		if self.heal or self.absorb then
			tbl = wipe(tbl or cacheTable)
			for _, p in ipairs(self.players) do
				if p.absorbspells then
					for _, spell in pairs(p.absorbspells) do
						if spell.targets then
							for name, amount in pairs(spell.targets) do
								if not tbl[name] then
									tbl[name] = {amount = amount}
								else
									tbl[name].amount = tbl[name].amount + amount
								end
								if not tbl[name].class then
									local actor = self:GetActor(name)
									if actor then
										tbl[name].id = actor.id
										tbl[name].class = actor.class
										tbl[name].role = actor.role
										tbl[name].spec = actor.spec
									else
										tbl[name].class = "UNKNOWN"
									end
								end
							end
						end
					end
				end
				if p.healspells then
					for _, spell in pairs(p.healspells) do
						if spell.targets then
							for name, target in pairs(spell.targets) do
								if not tbl[name] then
									tbl[name] = {amount = target.amount, overheal = target.overheal}
								else
									tbl[name].amount = tbl[name].amount + target.amount
									if target.overheal then
										tbl[name].overheal =
											(tbl[name].overheal or 0) + target.overheal
									end
								end
								if not tbl[name].class then
									local actor = self:GetActor(name)
									if actor then
										tbl[name].id = actor.id
										tbl[name].class = actor.class
										tbl[name].role = actor.role
										tbl[name].spec = actor.spec
									else
										tbl[name].class = "UNKNOWN"
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

	function playerPrototype:GetAbsorbHealSources(tbl)
		local total = 0

		if self.super then
			tbl = wipe(tbl or cacheTable)

			for _, p in pairs(self.super.players) do
				if p.absorbspells then
					for spellid, spell in pairs(p.absorbspells) do
						if spell.targets and spell.targets[self.name] then
							total = total + spell.amount
							if not tbl[p.name] then
								tbl[p.name] = {
									id = p.id,
									class = p.class,
									role = p.role,
									spec = p.spec,
									amount = spell.targets[self.name]
								}
							else
								tbl[p.name].amount = tbl[p.name].amount + spell.targets[self.name]
							end
						end
					end
				end
				if p.healspells then
					for spellid, spell in pairs(p.healspells) do
						if spell.targets and spell.targets[self.name] then
							total = total + spell.amount
							if not tbl[p.name] then
								tbl[p.name] = {
									id = p.id,
									class = p.class,
									role = p.role,
									spec = p.spec,
									amount = spell.targets[self.name].amount
								}
							else
								tbl[p.name].amount =
									tbl[p.name].amount + spell.targets[self.name].amount
							end
						end
					end
				end
			end
		end

		return tbl, total
	end
end)