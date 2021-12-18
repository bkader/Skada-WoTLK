local Skada = Skada

-- cache frequently used globals
local pairs, ipairs, select, format, max = pairs, ipairs, select, string.format, math.max
local GetSpellInfo, unitClass = Skada.GetSpellInfo or GetSpellInfo, Skada.unitClass
local setPrototype = Skada.setPrototype
local playerPrototype = Skada.playerPrototype
local cacheTable, wipe = Skada.cacheTable, wipe
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

	local function log_heal(set, data, tick)
		if data.spellid and tContains(ignoredSpells, data.spellid) then return end

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
			if set ~= Skada.current then return end

			-- record the spell
			local spell = player.healspells and player.healspells[data.spellid]
			if not spell then
				player.healspells = player.healspells or {}
				player.healspells[data.spellid] = {school = data.spellschool, amount = 0, overheal = 0}
				spell = player.healspells[data.spellid]
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

	local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...
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

		log_heal(Skada.current, heal, eventtype == "SPELL_PERIODIC_HEAL")
		log_heal(Skada.total, heal, eventtype == "SPELL_PERIODIC_HEAL")
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local player = set and set:GetPlayer(win.playerid, win.playername)
		local spell = player and player.healspells and player.healspells[id]

		if spell then
			tooltip:AddLine(player.name .. " - " .. label)
			if spell.school then
				local c = Skada.schoolcolors[spell.school]
				local n = Skada.schoolnames[spell.school]
				if c and n then
					tooltip:AddLine(n, c.r, c.g, c.b)
				end
			end

			tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)

			if (spell.critical or 0) > 0 then
				tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.critical, spell.count), 1, 1, 1)
			end

			if spell.overheal > 0 then
				tooltip:AddDoubleLine(L["Overhealing"], Skada:FormatPercent(spell.overheal, spell.overheal + spell.amount), 1, 1, 1)
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
		win.title = format(L["%s's healing on %s"], win.playername or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's healing on %s"], win.playername or L.Unknown, win.targetname or L.Unknown)
		if not win.targetname then return end

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player:GetHealOnTarget(win.targetname) or 0

		if total > 0 and player.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.healspells) do
				if spell.targets and spell.targets[win.targetname] then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)
					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					d.value = spell.targets[win.targetname].amount or 0
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Healing,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healing spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's healing spells"], win.playername or L.Unknown)

		local player = set and set:GetActor(win.playername, win.playerid)
		local total = player and player.heal or 0

		if total > 0 and player.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.healspells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.spellschool = spell.school
				d.label, _, d.icon = GetSpellInfo(spellid)
				if spell.ishot then
					d.text = d.label .. L["HoT"]
				end

				d.value = spell.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Healing,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's healed targets"], win.playername or L.Unknown)

		local player = set and set:GetActor(win.playername, win.playerid)
		local total = player and player.heal or 0
		local targets = (total > 0) and player:GetHealTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Healing,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing"]
		local total = set and set:GetHeal() or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- players
			for _, player in ipairs(set.players) do
				local hps, amount = player:GetHPS()
				if amount > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

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
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Healing,
						Skada:FormatNumber(hps),
						self.metadata.columns.HPS,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			-- arena enemies
			if Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyHeal then
				for _, enemy in ipairs(set.enemies) do
					local hps, amount = enemy:GetHPS()
					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = enemy.id or enemy.name
						d.label = enemy.name
						d.text = nil
						d.class = enemy.class
						d.role = enemy.role
						d.spec = enemy.spec
						d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.ARENA_GOLD

						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							self.metadata.columns.Healing,
							Skada:FormatNumber(hps),
							self.metadata.columns.HPS,
							Skada:FormatPercent(d.value, total),
							self.metadata.columns.Percent
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
		playermod.metadata = {tooltip = playermod_tooltip}
		targetmod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {playermod, targetmod},
			columns = {Healing = true, HPS = true, Percent = true},
			icon = [[Interface\Icons\spell_nature_healingtouch]]
		}

		Skada:RegisterForCL(SpellHeal, "SPELL_HEAL", {src_is_interesting = true})
		Skada:RegisterForCL(SpellHeal, "SPELL_PERIODIC_HEAL", {src_is_interesting = true})

		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		if not set then return end
		local hps, amount = set:GetHPS()
		return Skada:FormatValueText(
			Skada:FormatNumber(amount),
			self.metadata.columns.Healing,
			Skada:FormatNumber(hps),
			self.metadata.columns.HPS
		), amount
	end

	function setPrototype:GetHeal()
		local amount = self.heal or 0
		if Skada.forPVP and self.type == "arena" and self.GetEnemyHeal then
			amount = amount + self:GetEnemyHeal()
		end
		return amount
	end

	function setPrototype:GetHPS()
		local amount, hps = self:GetHeal(), 0
		if amount > 0 then
			hps = amount / max(1, self:GetTime())
		end
		return hps, amount
	end

	function setPrototype:GetOHPS()
		local amount, ohps = self.overheal or 0, 0
		if amount > 0 then
			ohps = amount / max(1, self:GetTime())
		end
		return ohps, amount
	end

	function playerPrototype:GetHPS(active)
		local amount, hps = self.heal or 0, 0
		if amount > 0 then
			hps = amount / max(1, self:GetTime(active))
		end
		return hps, amount
	end

	function playerPrototype:GetOHPS(active)
		local amount, ohps = self.overheal or 0, 0
		if amount > 0 then
			ohps = amount / max(1, self:GetTime(active))
		end
		return ohps, amount
	end

	function playerPrototype:GetHealTargets()
		if self.healspells then
			wipe(cacheTable)
			for _, spell in pairs(self.healspells) do
				if spell.targets then
					for name, target in pairs(spell.targets) do
						if not cacheTable[name] then
							cacheTable[name] = {amount = target.amount, overheal = target.overheal}
						else
							cacheTable[name].amount = cacheTable[name].amount + target.amount
							cacheTable[name].overheal = cacheTable[name].overheal + target.amount
						end
						if not cacheTable[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								cacheTable[name].id = actor.id
								cacheTable[name].class = actor.class
								cacheTable[name].role = actor.role
								cacheTable[name].spec = actor.spec
							else
								cacheTable[name].class = "UNKNOWN"
							end
						end
					end
				end
			end
			return cacheTable
		end
	end

	function playerPrototype:GetHealOnTarget(name)
		if self.healspells and name then
			local total = 0
			for _, spell in pairs(self.healspells) do
				if spell.targets and spell.targets[name] then
					total = total + spell.amount
				end
			end
			return total
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
		win.title = format(L["%s's overhealing on %s"], win.playername or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's overhealing on %s"], win.playername or L.Unknown, win.targetname or L.Unknown)
		if not win.targetname then return end

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player:GetOverhealOnTarget(win.targetname)

		if total > 0 and player.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.healspells) do
				if spell.targets and spell.targets[win.targetname] and spell.targets[win.targetname].overheal > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)
					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					d.value = spell.targets[win.targetname].overheal / (spell.targets[win.targetname].amount + spell.targets[win.targetname].overheal)
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(spell.targets[win.targetname].overheal),
						mod.metadata.columns.Overhealing,
						Skada:FormatPercent(100 * d.value),
						mod.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's overheal spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's overheal spells"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.overheal or 0

		if total > 0 and player.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.healspells) do
				if spell.overheal > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)

					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					d.value = spell.overheal / (spell.amount + spell.overheal)
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(spell.overheal),
						mod.metadata.columns.Overhealing,
						Skada:FormatPercent(100 * d.value),
						mod.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's overhealed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's overhealed targets"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.overheal or 0
		local targets = (total > 0) and player:GetOverhealTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.amount / target.total
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(target.amount),
					mod.metadata.columns.Overhealing,
					Skada:FormatPercent(100 * d.value),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Overhealing"]
		local total = set.overheal or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (player.overheal or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					local total = player.heal + player.overheal
					d.value = player.overheal
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Overhealing,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
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
			nototalclick = {playermod, targetmod},
			columns = {Overhealing = true, Percent = true},
			icon = [[Interface\Icons\spell_holy_holybolt]]
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.overheal or 0), set.overheal or 0
	end

	function playerPrototype:GetOverhealTargets()
		if self.healspells then
			wipe(cacheTable)
			for _, spell in pairs(self.healspells) do
				if spell.overheal > 0 and spell.targets then
					for name, target in pairs(spell.targets) do
						if target.overheal > 0 then
							if not cacheTable[name] then
								cacheTable[name] = {amount = target.overheal, total = target.amount + target.overheal}
							else
								cacheTable[name].amount = cacheTable[name].amount + target.overheal
								cacheTable[name].total = cacheTable[name].total + target.amount + target.overheal
							end
							if not cacheTable[name].class then
								local actor = self.super:GetActor(name)
								if actor then
									cacheTable[name].id = actor.id
									cacheTable[name].class = actor.class
									cacheTable[name].role = actor.role
									cacheTable[name].spec = actor.spec
								else
									cacheTable[name].class = "UNKNOWN"
								end
							end
						end
					end
				end
			end
			return cacheTable
		end
	end

	function playerPrototype:GetOverhealOnTarget(name)
		if self.healspells and name then
			local total = 0
			for _, spell in pairs(self.healspells) do
				if spell.overheal > 0 and spell.targets and spell.targets[name] then
					total = total + spell.amount
				end
			end
			return total
		end
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
		local player = set and set:GetPlayer(win.playerid, win.playername)
		local spell = player and player.healspells and player.healspells[id]
		if spell then
			tooltip:AddLine(player.name .. " - " .. label)
			if spell.school then
				local c = Skada.schoolcolors[spell.school]
				local n = Skada.schoolnames[spell.school]
				if c and n then
					tooltip:AddLine(n, c.r, c.g, c.b)
				end
			end

			if spell.count then
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
			end

			local total = spell.amount + spell.overheal
			tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(total), 1, 1, 1)
			if spell.amount > 0 then
				tooltip:AddDoubleLine(L["Healing"], format("%s (%s)", Skada:FormatNumber(spell.amount), Skada:FormatPercent(spell.amount, total)), 1, 1, 1)
			end
			if spell.overheal > 0 then
				tooltip:AddDoubleLine(L["Overhealing"], format("%s (%s)", Skada:FormatNumber(spell.overheal), Skada:FormatPercent(spell.overheal, total)), 1, 1, 1)
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
		win.title = format(L["%s's healing on %s"], win.playername or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's healing on %s"], win.playername or L.Unknown, win.targetname or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player:GetTotalHealOnTarget(win.targetname)
		if total > 0 and player.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.healspells) do
				if spell.targets and spell.targets[win.targetname] then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)
					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					d.value = spell.targets[win.targetname].amount + spell.targets[win.targetname].overheal
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Healing,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healing spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's healing spells"], win.playername or L.Unknown)

		local player, enemy = set and set:GetPlayer(win.playerid, win.playername), false
		if not player and Skada.forPVP and set and set.type == "arena" then
			player, enemy = set:GetEnemy(win.playername, win.playerid), true
		end

		local total = player and ((player.heal or 0) + (player.overheal or 0)) or 0

		if total > 0 and player.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.healspells) do
				local amount = spell.amount + (enemy and 0 or (spell.overheal or 0))
				if amount > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)

					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Healing,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's healed targets"], win.playername or L.Unknown)

		local player = set and set:GetActor(win.playername, win.playerid)
		local total = player and ((player.heal or 0) + (player.overheal or 0)) or 0

		local targets
		if total > 0 and player.GetTotalHealTargets then
			targets = player:GetTotalHealTargets()
		elseif total > 0 and player.GetHealTargets then
			targets = player:GetHealTargets()
		end

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Healing,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Total Healing"]
		local total = set and (set:GetHeal() + (set.overheal or 0)) or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- players
			for _, player in ipairs(set.players) do
				local hps, amount = player:GetTHPS()
				if amount > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

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
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Healing,
						Skada:FormatNumber(hps),
						self.metadata.columns.HPS,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			-- arena enemies
			if Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyHeal then
				for _, enemy in ipairs(set.enemies) do
					local hps, amount = enemy:GetHPS()
					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = enemy.id or enemy.name
						d.label = enemy.name
						d.text = nil
						d.class = enemy.class
						d.role = enemy.role
						d.spec = enemy.spec
						d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.ARENA_GOLD

						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							self.metadata.columns.Healing,
							Skada:FormatNumber(hps),
							self.metadata.columns.HPS,
							Skada:FormatPercent(d.value, total),
							self.metadata.columns.Percent
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
		targetmod.metadata = {showspots = true, click1 = spellmod}
		playermod.metadata = {tooltip = spell_tooltip}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
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
		return Skada:FormatValueText(
			Skada:FormatNumber(amount),
			self.metadata.columns.Healing,
			Skada:FormatNumber(ops),
			self.metadata.columns.HPS
		), amount
	end

	function setPrototype:GetTHPS()
		local hps, amount = 0, (self.heal or 0) + (self.overheal or 0)
		if Skada.forPVP and self.type == "arena" and self.GetEnemyHeal then
			amount = amount + self:GetEnemyHeal()
		end
		if amount > 0 then
			hps = amount / max(1, self:GetTime())
		end
		return hps, amount
	end

	function playerPrototype:GetTHPS(active)
		local hps, amount = 0, (self.heal or 0) + (self.overheal or 0)
		if amount > 0 then
			hps = amount / max(1, self:GetTime(active))
		end
		return hps, amount
	end

	function playerPrototype:GetTotalHealTargets()
		if self.healspells then
			wipe(cacheTable)
			for _, spell in pairs(self.healspells) do
				if spell.targets then
					for name, target in pairs(spell.targets) do
						if not cacheTable[name] then
							cacheTable[name] = {amount = target.amount + target.overheal}
						else
							cacheTable[name].amount = cacheTable[name].amount + target.amount + target.overheal
						end
						if not cacheTable[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								cacheTable[name].id = actor.id
								cacheTable[name].class = actor.class
								cacheTable[name].role = actor.role
								cacheTable[name].spec = actor.spec
							else
								cacheTable[name].class = "UNKNOWN"
							end
						end
					end
				end
			end
			return cacheTable
		end
	end

	function playerPrototype:GetTotalHealOnTarget(name)
		if self.healspells and name then
			local total = 0
			for _, spell in pairs(self.healspells) do
				if spell.targets and spell.targets[name] then
					total = total + spell.targets[name].amount + spell.targets[name].overheal
				end
			end
			return total
		end
	end
end)

-- ============================== --
-- Healing and overheal module --
-- ============================== --

Skada:AddLoadableModule("Healing and Overhealing", function(L)
	if Skada:IsDisabled("Healing", "Healing and Overhealing") then return end

	local mod = Skada:NewModule(L["Healing and Overhealing"])
	local playermod = mod:NewModule(L["Heal and overheal spells"])
	local targetmod = mod:NewModule(L["Healed and overhealed targets"])
	local spellmod = targetmod:NewModule(L["Heal and overheal spells"])

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healing and overhealing on %s"], win.playername or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's healing and overhealing on %s"], win.playername or L.Unknown, win.targetname or L.Unknown)
		if not win.targetname then return end

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player:GetTotalHealOnTarget(win.targetname)

		if total > 0 and player.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.healspells) do
				if spell.targets and spell.targets[win.targetname] then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)
					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					local amount = spell.targets[win.targetname].amount + spell.targets[win.targetname].overheal
					d.value = spell.targets[win.targetname].overheal / amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(spell.targets[win.targetname].amount),
						mod.metadata.columns.Healing,
						Skada:FormatNumber(spell.targets[win.targetname].overheal),
						mod.metadata.columns.Overhealing,
						Skada:FormatPercent(100 * d.value),
						mod.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's heal and overheal spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's heal and overheal spells"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and ((player.heal or 0) + (player.overheal or 0)) or 0

		if total > 0 and player.healspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.healspells) do
				local amount = spell.amount + spell.overheal
				if amount > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)

					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

					d.value = spell.overheal / amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(spell.amount),
						mod.metadata.columns.Healing,
						Skada:FormatNumber(spell.overheal),
						mod.metadata.columns.Overhealing,
						Skada:FormatPercent(100 * d.value),
						mod.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healed and overhealed targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's healed and overhealed targets"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and ((player.heal or 0) + (player.overheal or 0)) or 0
		local targets = (total > 0) and player:GetHealTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.amount + target.overheal
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Healing,
					Skada:FormatNumber(target.overheal),
					mod.metadata.columns.Overhealing,
					Skada:FormatPercent(target.overheal, d.value),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing and Overhealing"]
		local total = set and ((set.heal or 0) + (set.overheal or 0)) or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				local amount = (player.heal or 0) + (player.overheal or 0)
				if amount > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.Healing,
						Skada:FormatNumber(player.overheal),
						self.metadata.columns.Overhealing,
						Skada:FormatPercent(player.overheal, total),
						self.metadata.columns.Percent
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
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {playermod, targetmod},
			columns = {Healing = true, Overhealing = true, Percent = true},
			icon = [[Interface\Icons\spell_holy_prayerofhealing02]]
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local healing = set.heal or 0
		local overheal = set.overheal or 0

		local value = healing + overheal
		return Skada:FormatValueText(
			Skada:FormatNumber(value),
			self.metadata.columns.Healing,
			Skada:FormatNumber(overheal),
			self.metadata.columns.Overhealing,
			Skada:FormatPercent(overheal, value),
			self.metadata.columns.Percent
		), value
	end
end)

-- ================ --
-- Healing taken --
-- ================ --

Skada:AddLoadableModule("Healing Taken", function(L)
	if Skada:IsDisabled("Healing", "Healing Taken") then return end

	local mod = Skada:NewModule(L["Healing Taken"])
	local sourcemod = mod:NewModule(L["Healing source list"])
	local spellmod = sourcemod:NewModule(L["Healing spell list"])

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healing on %s"], win.playername or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's healing on %s"], win.playername or L.Unknown, win.targetname or L.Unknown)

		local player = set and set:GetPlayer(win.targetid, win.targetname)
		local total = player and player:GetAbsorbHealOnTarget(win.playername)

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			if player.absorbspells then
				for spellid, spell in pairs(player.absorbspells) do
					if spell.targets and spell.targets[win.playername] then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellid
						d.spellid = spellid
						d.spellschool = spell.school
						d.label, _, d.icon = GetSpellInfo(spellid)

						d.value = spell.targets[win.playername]
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Healing,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
						)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end

			if player.healspells then
				for spellid, spell in pairs(player.healspells) do
					if spell.targets and spell.targets[win.playername] then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellid
						d.spellid = spellid
						d.spellschool = spell.school
						d.label, _, d.icon = GetSpellInfo(spellid)
						if spell.ishot then
							d.text = d.label .. L["HoT"]
						end

						d.value = spell.targets[win.playername].amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Healing,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
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
		win.playerid, win.playername = id, label
		win.title = format(L["%s's received healing"], label)
	end

	function sourcemod:Update(win, set)
		win.title = format(L["%s's received healing"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		if not player then return end

		local sources, total = player:GetAbsorbHealSources()

		if sources and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for sourcename, source in pairs(cacheTable) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = source.id
				d.label = sourcename
				d.text = source.id and Skada:FormatName(sourcename, source.id)
				d.class = source.class
				d.role = source.role
				d.spec = source.spec

				d.value = source.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Healing,
					Skada:FormatNumber(source.overheal or 0),
					mod.metadata.columns.Overhealing,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing Taken"]
		local total = set and set:GetAbsorbHeal() or 0
		local players = (total > 0) and set:GetAbsorbHealTaken()

		if players then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for playername, player in pairs(players) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id or playername
				d.label = playername
				d.text = player.id and Skada:FormatName(playername, player.id)
				d.class = player.class
				d.role = player.role
				d.spec = player.spec

				d.value = player.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Healing,
					Skada:FormatNumber(player.overheal),
					mod.metadata.columns.Overhealing,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:OnEnable()
		sourcemod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = sourcemod,
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

	function setPrototype:GetAbsorbHealTaken()
		if self.heal or self.absorb then
			wipe(cacheTable)
			for _, p in ipairs(self.players) do
				if p.absorbspells then
					for _, spell in pairs(p.absorbspells) do
						if spell.targets then
							for name, amount in pairs(spell.targets) do
								if not cacheTable[name] then
									cacheTable[name] = {amount = amount}
								else
									cacheTable[name].amount = cacheTable[name].amount + amount
								end
								if not cacheTable[name].class then
									local actor = self:GetActor(name)
									if actor then
										cacheTable[name].id = actor.id
										cacheTable[name].class = actor.class
										cacheTable[name].role = actor.role
										cacheTable[name].spec = actor.spec
									else
										cacheTable[name].class = "UNKNOWN"
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
								if not cacheTable[name] then
									cacheTable[name] = {amount = target.amount, overheal = target.overheal}
								else
									cacheTable[name].amount = cacheTable[name].amount + target.amount
									if target.overheal then
										cacheTable[name].overheal =
											(cacheTable[name].overheal or 0) + target.overheal
									end
								end
								if not cacheTable[name].class then
									local actor = self:GetActor(name)
									if actor then
										cacheTable[name].id = actor.id
										cacheTable[name].class = actor.class
										cacheTable[name].role = actor.role
										cacheTable[name].spec = actor.spec
									else
										cacheTable[name].class = "UNKNOWN"
									end
								end
							end
						end
					end
				end
			end
			return cacheTable
		end
	end

	function playerPrototype:GetAbsorbHealSources()
		if self.super then
			wipe(cacheTable)
			local total = 0
			for _, p in pairs(self.super.players) do
				if p.absorbspells then
					for spellid, spell in pairs(p.absorbspells) do
						if spell.targets and spell.targets[self.name] then
							total = total + spell.amount
							if not cacheTable[p.name] then
								cacheTable[p.name] = {
									id = p.id,
									class = p.class,
									role = p.role,
									spec = p.spec,
									amount = spell.targets[self.name]
								}
							else
								cacheTable[p.name].amount = cacheTable[p.name].amount + spell.targets[self.name]
							end
						end
					end
				end
				if p.healspells then
					for spellid, spell in pairs(p.healspells) do
						if spell.targets and spell.targets[self.name] then
							total = total + spell.amount
							if not cacheTable[p.name] then
								cacheTable[p.name] = {
									id = p.id,
									class = p.class,
									role = p.role,
									spec = p.spec,
									amount = spell.targets[self.name].amount
								}
							else
								cacheTable[p.name].amount =
									cacheTable[p.name].amount + spell.targets[self.name].amount
							end
						end
					end
				end
			end
			return cacheTable, total
		end
	end
end)