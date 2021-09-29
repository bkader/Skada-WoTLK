assert(Skada, "Skada not found!")

-- cache frequently used globals
local pairs, ipairs, select, format, max = pairs, ipairs, select, string.format, math.max
local GetSpellInfo, UnitClass = Skada.GetSpellInfo or GetSpellInfo, Skada.UnitClass
local _

-- ============== --
-- Healing module --
-- ============== --

Skada:AddLoadableModule("Healing", function(Skada, L)
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

		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
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

			-- record the spell
			local spell = player.heal_spells and player.heal_spells[data.spellid]
			if not spell then
				player.heal_spells = player.heal_spells or {}
				player.heal_spells[data.spellid] = {school = data.spellschool, amount = 0, overheal = 0}
				spell = player.heal_spells[data.spellid]
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
			end

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.current and data.dstName then
				-- spell targets
				local target = spell.targets and spell.targets[data.dstName]
				if not target then
					spell.targets = spell.targets or {}
					spell.targets[data.dstName] = {id = data.dstGUID, amount = amount, overheal = data.overheal}
					target = spell.targets[data.dstName]
				else
					target.id = target.id or data.dstGUID -- GUID fix
					target.amount = target.amount + amount
					target.overheal = target.overheal + data.overheal
				end

				-- player targets
				target = player.heal_targets and player.heal_targets[data.dstName]
				if not target then
					player.heal_targets = player.heal_targets or {}
					player.heal_targets[data.dstName] = {id = data.dstGUID, amount = amount, overheal = data.overheal}
					target = player.heal_targets[data.dstName]
				else
					target.id = target.id or data.dstGUID -- GUID fix
					target.amount = target.amount + amount
					target.overheal = target.overheal + data.overheal
				end
			end
		end
	end

	local heal = {}

	local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, amount, overheal, _, critical = ...

		srcGUID, srcName, srcFlags = Skada:FixUnit(spellid, srcGUID, srcName, srcFlags)

		heal.playerid = srcGUID
		heal.playername = srcName
		heal.playerflags = srcFlags

		heal.dstGUID = dstGUID
		heal.dstName = dstName

		heal.spellid = spellid
		heal.spellschool = spellschool

		heal.amount = amount
		heal.overheal = overheal
		heal.critical = critical

		heal.petname = nil
		Skada:FixPets(heal)

		log_heal(Skada.current, heal, eventtype == "SPELL_PERIODIC_HEAL")
		log_heal(Skada.total, heal, eventtype == "SPELL_PERIODIC_HEAL")
	end

	local function getHPS(set, player)
		local amount = player.heal or 0
		return amount / max(1, Skada:PlayerActiveTime(set, player)), amount
	end

	local function getRaidHPS(set)
		return (set.heal or 0) / max(1, Skada:GetSetTime(set)), (set.heal or 0)
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), win.playerid)
		if player then
			local spell = player.heal_spells and player.heal_spells[id]

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
				if spell.min and spell.max then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
				end
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
				if (spell.critical or 0) > 0 then
					tooltip:AddDoubleLine(L["Critical"], Skada:FormatPercent(spell.critical, spell.count), 1, 1, 1)
				end
				if spell.overheal > 0 then
					tooltip:AddDoubleLine(L["Overhealing"], Skada:FormatPercent(spell.overheal, spell.overheal + spell.amount), 1, 1, 1)
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healing on %s"], win.playername or UNKNOWN, label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's healing on %s"], player.name, win.targetname or UNKNOWN)

			local total = 0
			if player.heal_targets and win.targetname and player.heal_targets[win.targetname] then
				total = player.heal_targets[win.targetname].amount
			end

			if total > 0 and player.heal_spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.heal_spells) do
					if spell.targets and spell.targets[win.targetname] then
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

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healing spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's healing spells"], player.name)
			local total = select(2, getHPS(set, player))

			if total > 0 and player.heal_spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.heal_spells) do
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

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healed targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's healed targets"], player.name)
			local total = select(2, getHPS(set, player))

			if total > 0 and player.heal_targets then
				local maxvalue, nr = 0, 1

				for targetname, target in pairs(player.heal_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = select(2, UnitClass(d.id, nil, set))

					d.value = target.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Healing,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing"]
		local total = select(2, getRaidHPS(set))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local hps, amount = getHPS(set, player)
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = player.name
				d.text = Skada:FormatName(player.name, player.id)
				d.class = player.class
				d.role = player.role
				d.spec = player.spec

				d.value = amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					self.metadata.columns.Healing,
					Skada:FormatNumber(hps),
					self.metadata.columns.HPS,
					Skada:FormatPercent(d.value, total),
					self.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		playermod.metadata = {tooltip = playermod_tooltip}
		targetmod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Healing = true, HPS = true, Percent = true},
			icon = "Interface\\Icons\\spell_nature_healingtouch"
		}

		Skada:RegisterForCL(SpellHeal, "SPELL_HEAL", {src_is_interesting = true})
		Skada:RegisterForCL(SpellHeal, "SPELL_PERIODIC_HEAL", {src_is_interesting = true})

		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local hps, value = getRaidHPS(set)
		return Skada:FormatValueText(
			Skada:FormatNumber(value),
			self.metadata.columns.Healing,
			Skada:FormatNumber(hps),
			self.metadata.columns.HPS
		), value
	end
end)

-- ================== --
-- Overhealing module --
-- ================== --

Skada:AddLoadableModule("Overhealing", function(Skada, L)
	if Skada:IsDisabled("Healing", "Overhealing") then return end

	local mod = Skada:NewModule(L["Overhealing"])
	local playermod = mod:NewModule(L["Overheal spell list"])
	local targetmod = mod:NewModule(L["Overhealed target list"])
	local spellmod = targetmod:NewModule(L["Overheal spell list"])

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's overhealing on %s"], win.playername or UNKNOWN, label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's overhealing on %s"], player.name, win.targetname or UNKNOWN)

			local total = 0
			if player.heal_targets and win.targetname and player.heal_targets[win.targetname] then
				total = player.heal_targets[win.targetname].overheal or 0
			end

			if total > 0 and player.heal_spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.heal_spells) do
					if spell.targets and spell.targets[win.targetname] then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellid
						d.spellid = spellid
						d.spellschool = spell.school
						d.label, _, d.icon = GetSpellInfo(spellid)
						if spell.ishot then
							d.text = d.label .. L["HoT"]
						end

						d.value = spell.targets[win.targetname].overheal or 0
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Overhealing,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's overheal spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's overheal spells"], player.name)

			if player.heal_spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.heal_spells) do
					if spell.overheal > 0 then
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

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's overhealed targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's overhealed targets"], player.name)

			if player.heal_targets then
				local maxvalue, nr = 0, 1

				for targetname, target in pairs(player.heal_targets) do
					if target.overheal > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = target.id or targetname
						d.label = targetname
						d.class, d.role, d.spec = select(2, UnitClass(d.id, nil, set))

						d.value = target.overheal / (target.amount + target.overheal)
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(target.overheal),
							mod.metadata.columns.Overhealing,
							Skada:FormatPercent(100 * d.value),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Overhealing"]

		if (set.overheal or 0) > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.overheal or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
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

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		targetmod.metadata = {click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Overhealing = true, Percent = true},
			icon = "Interface\\Icons\\spell_holy_holybolt"
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.overheal or 0), set.overheal or 0
	end
end)

-- ==================== --
-- Total healing module --
-- ==================== --

Skada:AddLoadableModule("Total Healing", function(Skada, L)
	if Skada:IsDisabled("Healing", "Total Healing") then return end

	local mod = Skada:NewModule(L["Total Healing"])
	local playermod = mod:NewModule(L["Healing spell list"])
	local targetmod = mod:NewModule(L["Healed target list"])
	local spellmod = targetmod:NewModule(L["Healing spell list"])

	local function getHPS(set, player)
		local amount = (player.heal or 0) + (player.overheal or 0)
		return amount / max(1, Skada:PlayerActiveTime(set, player)), amount
	end

	local function getRaidHPS(set)
		local amount = (set.heal or 0) + (set.overheal or 0)
		return amount / max(1, Skada:GetSetTime(set)), amount
	end

	local function spell_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), win.playerid)
		if player then
			local spell = player.heal_spells and player.heal_spells[id]

			if spell then
				tooltip:AddLine(player.name .. " - " .. label)
				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then
						tooltip:AddLine(n, c.r, c.g, c.b)
					end
				end
				if spell.min and spell.max then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
					tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
					tooltip:AddLine(" ")
				end
				local total = spell.amount + spell.overheal
				tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(total), 1, 1, 1)
				if spell.amount > 0 then
					tooltip:AddDoubleLine(L["Healing"], format("%s (%s)", Skada:FormatNumber(spell.amount), Skada:FormatPercent(spell.amount, total)), 1, 1, 1)
				end
				if spell.overheal > 0 then
					tooltip:AddDoubleLine(L["Overhealing"], format("%s (%s)", Skada:FormatNumber(spell.overheal), Skada:FormatPercent(spell.overheal, total)), 1, 1, 1)
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healing on %s"], win.playername or UNKNOWN, label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's healing on %s"], player.name, win.targetname or UNKNOWN)

			local total = 0
			if player.heal_targets and win.targetname and player.heal_targets[win.targetname] then
				total = (player.heal_targets[win.targetname].amount or 0) + (player.heal_targets[win.targetname].overheal or 0)
			end

			if total > 0 and player.heal_spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.heal_spells) do
					if spell.targets and spell.targets[win.targetname] then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellid
						d.spellid = spellid
						d.spellschool = spell.school
						d.label, _, d.icon = GetSpellInfo(spellid)
						if spell.ishot then
							d.text = d.label .. L["HoT"]
						end

						d.value = (spell.targets[win.targetname].amount or 0) + (spell.targets[win.targetname].overheal or 0)
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Healing,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healing spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's healing spells"], player.name)
			local total = (player.heal or 0) + (player.overheal or 0)

			if total > 0 and player.heal_spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.heal_spells) do
					local amount = spell.amount + spell.overheal
					if amount > 0 then
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

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healed targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's healed targets"], player.name)
			local total = (player.heal or 0) + (player.overheal or 0)

			if total > 0 and player.heal_targets then
				local maxvalue, nr = 0, 1

				for targetname, target in pairs(player.heal_targets) do
					local amount = target.amount + target.overheal
					if amount > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = target.id or targetname
						d.label = targetname
						d.class, d.role, d.spec = select(2, UnitClass(d.id, nil, set))

						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Healing,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Total Healing"]
		local total = select(2, getRaidHPS(set))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local hps, amount = getHPS(set, player)
				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Healing,
						Skada:FormatNumber(hps),
						self.metadata.columns.HPS,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		targetmod.metadata = {showspots = true, click1 = spellmod}
		playermod.metadata = {tooltip = spell_tooltip}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Healing = true, HPS = true, Percent = true},
			icon = "Interface\\Icons\\spell_holy_flashheal"
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local hps, value = getRaidHPS(set)
		return Skada:FormatValueText(
			Skada:FormatNumber(value),
			self.metadata.columns.Healing,
			Skada:FormatNumber(hps),
			self.metadata.columns.HPS
		), value
	end
end)

-- ============================== --
-- Healing and overheal module --
-- ============================== --

Skada:AddLoadableModule("Healing and Overhealing", function(Skada, L)
	if Skada:IsDisabled("Healing", "Healing and Overhealing") then return end

	local mod = Skada:NewModule(L["Healing and Overhealing"])
	local playermod = mod:NewModule(L["Heal and overheal spells"])
	local targetmod = mod:NewModule(L["Healed and overhealed targets"])
	local spellmod = targetmod:NewModule(L["Heal and overheal spells"])

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healing and overhealing on %s"], win.playername or UNKNOWN, label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's healing and overhealing on %s"], player.name, win.targetname or UNKNOWN)

			local total = 0
			if player.heal_targets and win.targetname and player.heal_targets[win.targetname] then
				total = (player.heal_targets[win.targetname].amount or 0) + (player.heal_targets[win.targetname].overheal or 0)
			end

			if total > 0 and player.heal_spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.heal_spells) do
					if spell.targets and spell.targets[win.targetname] then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellid
						d.spellid = spellid
						d.spellschool = spell.school
						d.label, _, d.icon = GetSpellInfo(spellid)
						if spell.ishot then
							d.text = d.label .. L["HoT"]
						end

						d.value = (spell.targets[win.targetname].amount or 0) + (spell.targets[win.targetname].overheal or 0)
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(spell.targets[win.targetname].amount or 0),
							mod.metadata.columns.Healing,
							Skada:FormatNumber(spell.targets[win.targetname].overheal or 0),
							mod.metadata.columns.Overhealing,
							Skada:FormatPercent(spell.targets[win.targetname].overheal or 0, d.value),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's heal and overheal spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's heal and overheal spells"], player.name)
			local total = (player.heal or 0) + (player.overheal or 0)

			if total > 0 and player.heal_spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.heal_spells) do
					local amount = spell.amount + spell.overheal
					if amount > 0 then
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
							Skada:FormatNumber(amount),
							mod.metadata.columns.Healing,
							Skada:FormatNumber(spell.overheal),
							mod.metadata.columns.Overhealing,
							Skada:FormatPercent(spell.overheal, amount),
							mod.metadata.columns.Percent
						)

						if amount > maxvalue then
							maxvalue = amount
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healed and overhealed targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's healed and overhealed targets"], player.name)
			local total = (player.heal or 0) + (player.overheal or 0)

			if total > 0 and player.heal_targets then
				local maxvalue, nr = 0, 1

				for targetname, target in pairs(player.heal_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = select(2, UnitClass(d.id, nil, set))

					d.value = target.amount + target.overheal
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Healing,
						Skada:FormatNumber(target.overheal),
						mod.metadata.columns.Overhealing,
						Skada:FormatPercent(target.overheal, d.value),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing and Overhealing"]
		local total = (set.heal or 0) + (set.overheal or 0)

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.heal or 0) > 0 then
					local amount = player.heal + (player.overheal or 0)
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
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

					if amount > maxvalue then
						maxvalue = amount
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		targetmod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Healing = true, Overhealing = true, Percent = true},
			icon = "Interface\\Icons\\spell_holy_prayerofhealing02"
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

Skada:AddLoadableModule("Healing Taken", function(Skada, L)
	if Skada:IsDisabled("Healing", "Healing Taken") then return end

	local mod = Skada:NewModule(L["Healing Taken"])
	local sourcemod = mod:NewModule(L["Healing source list"])
	local spellmod = sourcemod:NewModule(L["Healing spell list"])
	local newTable, delTable, cacheTable = Skada.newTable, Skada.delTable

	function spellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's healing on %s"], win.playername or UNKNOWN, label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.targetid, win.targetname)
		if player then
			win.title = format(L["%s's healing on %s"], player.name, win.targetname or UNKNOWN)

			local total = 0
			if player.heal_targets and win.playername and player.heal_targets[win.playername] then
				total = player.heal_targets[win.playername].amount
			end
			if player.absorb_targets and win.playername and player.absorb_targets[win.playername] then
				total = player.absorb_targets[win.playername].amount
			end

			if total > 0 then
				local maxvalue, nr = 0, 1

				if player.heal_spells then
					for spellid, spell in pairs(player.heal_spells) do
						if spell.targets and spell.targets[win.playername] then
							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = spellid
							d.spellid = spellid
							d.spellschool = spell.school
							d.label, _, d.icon = GetSpellInfo(spellid)
							if spell.ishot then
								d.text = d.label .. L["HoT"]
							end

							d.value = spell.targets[win.playername].amount or 0
							d.valuetext = Skada:FormatValueText(
								Skada:FormatNumber(d.value),
								mod.metadata.columns.Healing,
								Skada:FormatPercent(d.value, total),
								mod.metadata.columns.Percent
							)

							if d.value > maxvalue then
								maxvalue = d.value
							end
							nr = nr + 1
						end
					end
				end

				if player.absorb_spells then
					for spellid, spell in pairs(player.absorb_spells) do
						if spell.targets and spell.targets[win.playername] then
							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = spellid
							d.spellid = spellid
							d.spellschool = spell.school
							d.label, _, d.icon = GetSpellInfo(spellid)

							d.value = spell.targets[win.playername].amount or 0
							d.valuetext = Skada:FormatValueText(
								Skada:FormatNumber(d.value),
								mod.metadata.columns.Healing,
								Skada:FormatPercent(d.value, total),
								mod.metadata.columns.Percent
							)

							if d.value > maxvalue then
								maxvalue = d.value
							end
							nr = nr + 1
						end
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function sourcemod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's received healing"], label)
	end

	function sourcemod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's received healing"], player.name)

			cacheTable = newTable()
			local total = 0

			for _, p in ipairs(set.players) do
				if p.heal_targets then
					for targetname, target in pairs(p.heal_targets) do
						if targetname == player.name then
							total = total + target.amount -- increment total
							cacheTable[p.name] = {
								id = p.id,
								class = p.class,
								role = p.role,
								spec = p.spec,
								amount = target.amount,
								overheal = target.overheal
							}
							break
						end
					end
				end
				if p.absorb and p.absorb_targets then
					for targetname, target in pairs(p.absorb_targets) do
						if targetname == player.name then
							total = total + target.amount -- increment total
							if not cacheTable[p.name] then
								cacheTable[p.name] = {
									id = p.id,
									class = p.class,
									role = p.role,
									spec = p.spec,
									amount = target.amount,
									overheal = 0
								}
							else
								cacheTable[p.name].amount = cacheTable[p.name].amount + target.amount
							end
							break
						end
					end
				end
			end

			if total > 0 then
				local maxvalue, nr = 0, 1

				for sourcename, source in pairs(cacheTable) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = source.id
					d.label = sourcename
					d.text = Skada:FormatName(sourcename, source.id)
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

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end

			delTable(cacheTable)
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing Taken"]
		local total = set.heal or 0

		if total > 0 then
			cacheTable = newTable()

			for _, player in ipairs(set.players) do
				if player.heal_targets then
					for targetname, target in pairs(player.heal_targets) do
						if not cacheTable[targetname] then
							cacheTable[targetname] = {
								id = target.id,
								amount = target.amount,
								overheal = target.overheal
							}
						else
							cacheTable[targetname].amount = cacheTable[targetname].amount + target.amount
							cacheTable[targetname].overheal = cacheTable[targetname].overheal + target.overheal
						end
					end
				end
				if player.absorb_targets then
					for targetname, target in pairs(player.absorb_targets) do
						if not cacheTable[targetname] then
							cacheTable[targetname] = {
								id = target.id,
								amount = target.amount,
								overheal = 0
							}
						else
							cacheTable[targetname].amount = cacheTable[targetname].amount + target.amount
						end
					end
				end
			end

			local maxvalue, nr = 0, 1

			for playername, player in pairs(cacheTable) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = playername
				d.text = Skada:FormatName(playername, player.id)
				d.class, d.role, d.spec = select(2, UnitClass(d.id, nil, set))

				d.value = player.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Healing,
					Skada:FormatNumber(player.overheal),
					mod.metadata.columns.Overhealing,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
			delTable(cacheTable)
		end
	end

	function mod:OnEnable()
		sourcemod.metadata = {showspots = true, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = sourcemod,
			columns = {Healing = true, Overhealing = true, Percent = true},
			icon = "Interface\\Icons\\spell_nature_resistnature"
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local amount = (set.heal or 0) + (set.absorb or 0)
		return Skada:FormatNumber(amount), amount
	end
end)