assert(Skada, "Skada not found!")

-- cache frequently used globals
local pairs, select, format, max = pairs, select, string.format, math.max
local GetSpellInfo, UnitClass = Skada.GetSpellInfo or GetSpellInfo, Skada.UnitClass
local _

-- ============== --
-- Healing module --
-- ============== --

Skada:AddLoadableModule("Healing", function(Skada, L)
	if Skada:IsDisabled("Healing") then return end

	local mod = Skada:NewModule(L["Healing"])
	local targetmod = mod:NewModule(L["Healed player list"])
	local playermod = mod:NewModule(L["Healing spell list"])

	local function log_heal(set, data, tick)
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
			if data.spellid then
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
			end

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.current and data.dstName and amount > 0 then
				local target = player.heal_targets and player.heal_targets[data.dstName]
				if not target then
					player.heal_targets = player.heal_targets or {}
					target = {id = data.dstGUID, amount = amount, overheal = data.overheal}
					player.heal_targets[data.dstName] = target
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
					tooltip:AddDoubleLine(L["Critical"], format("%.1f%%", 100 * spell.critical / max(1, spell.count)), 1, 1, 1)
				end
				if spell.overheal > 0 then
					tooltip:AddDoubleLine(L["Overhealing"], format("%.1f%%", 100 * spell.overheal / max(1, spell.overheal + spell.amount)), 1, 1, 1)
				end
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
						Skada:FormatNumber(spell.amount),
						mod.metadata.columns.Healing,
						format("%.1f%%", 100 * spell.amount / total),
						mod.metadata.columns.Percent
					)

					if spell.amount > maxvalue then
						maxvalue = spell.amount
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healed players"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's healed players"], player.name)
			local total = getHPS(set, player)

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
						Skada:FormatNumber(target.amount),
						mod.metadata.columns.Healing,
						format("%.1f%%", 100 * target.amount / total),
						mod.metadata.columns.Percent
					)

					if target.amount > maxvalue then
						maxvalue = target.amount
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

			for _, player in Skada:IteratePlayers(set) do
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
						Skada:FormatNumber(amount),
						self.metadata.columns.Healing,
						Skada:FormatNumber(hps),
						self.metadata.columns.HPS,
						format("%.1f%%", 100 * amount / total),
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
		playermod.metadata = {tooltip = playermod_tooltip}
		targetmod.metadata = {showspots = true}
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
	local playersmod = mod:NewModule(L["Overhealed player list"])
	local spellsmod = mod:NewModule(L["Overheal spell list"])

	function spellsmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's overheal spells"], label)
	end

	function spellsmod:Update(win, set)
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
							format("%.1f%%", 100 * d.value),
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

	function playersmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's overhealed players"], label)
	end

	function playersmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's overhealed players"], player.name)

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
							format("%.1f%%", 100 * d.value),
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

			for _, player in Skada:IteratePlayers(set) do
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
						Skada:FormatNumber(player.overheal),
						self.metadata.columns.Overhealing,
						format("%.1f%%", 100 * player.overheal / total),
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
		playersmod.metadata = {showspots = true}
		self.metadata = {
			showspots = true,
			click1 = spellsmod,
			click2 = playersmod,
			nototalclick = {playersmod},
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
	local playersmod = mod:NewModule(L["Healed player list"])
	local spellsmod = mod:NewModule(L["Healing spell list"])

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
					tooltip:AddDoubleLine(L["Healing"], format("%s (%.1f%%)", Skada:FormatNumber(spell.amount), 100 * spell.amount / max(1, total)), 1, 1, 1)
				end
				if spell.overheal > 0 then
					tooltip:AddDoubleLine(L["Overhealing"], format("%s (%.1f%%)", Skada:FormatNumber(spell.overheal), 100 * spell.overheal / max(1, total)), 1, 1, 1)
				end
			end
		end
	end

	function spellsmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healing spells"], label)
	end

	function spellsmod:Update(win, set)
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
							Skada:FormatNumber(amount),
							mod.metadata.columns.Healing,
							format("%.1f%%", 100 * amount / total),
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

	function playersmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's healed players"], label)
	end

	function playersmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's healed players"], player.name)
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
							Skada:FormatNumber(amount),
							mod.metadata.columns.Healing,
							format("%.1f%%", 100 * amount / total),
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

	function mod:Update(win, set)
		win.title = L["Total Healing"]
		local total = select(2, getRaidHPS(set))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
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
						Skada:FormatNumber(amount),
						self.metadata.columns.Healing,
						Skada:FormatNumber(hps),
						self.metadata.columns.HPS,
						format("%.1f%%", 100 * amount / total),
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
		playersmod.metadata = {showspots = true}
		spellsmod.metadata = {tooltip = spell_tooltip}
		self.metadata = {
			showspots = true,
			click1 = spellsmod,
			click2 = playersmod,
			nototalclick = {playersmod},
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
	local spellmod = mod:NewModule(L["Heal and overheal spells"])
	local targetmod = mod:NewModule(L["Healed and overhealed players"])

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's heal and overheal spells"], label)
	end

	function spellmod:Update(win, set)
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
							Skada:FormatNumber(spell.amount),
							mod.metadata.columns.Healing,
							Skada:FormatNumber(spell.overheal),
							mod.metadata.columns.Overhealing,
							format("%.1f%%", 100 * spell.overheal / amount),
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
		win.title = format(L["%s's healed and overhealed players"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's healed and overhealed players"], player.name)
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
						format("%.1f%%", 100 * target.overheal / max(1, d.value)),
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

			for _, player in Skada:IteratePlayers(set) do
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
						format("%.1f%%", 100 * player.overheal / total),
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
		targetmod.metadata = {showspots = true}
		self.metadata = {
			showspots = true,
			click1 = spellmod,
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
			Skada:FormatNumber(healing),
			self.metadata.columns.Healing,
			Skada:FormatNumber(overheal),
			self.metadata.columns.Overhealing,
			format("%.1f%%", 100 * overheal / max(1, value)),
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
	local playermod = mod:NewModule(L["Healing player list"])

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's received healing"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's received healing"], player.name)

			local total, sources = 0, {}

			for _, p in Skada:IteratePlayers(set) do
				if p.heal_targets then
					for targetname, target in pairs(p.heal_targets) do
						if targetname == player.name then
							total = total + target.amount -- increment total
							sources[p.name] = {
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
							if not sources[p.name] then
								sources[p.name] = {
									id = p.id,
									class = p.class,
									role = p.role,
									spec = p.spec,
									amount = target.amount,
									overheal = 0
								}
							else
								sources[p.name].amount = sources[p.name].amount + target.amount
							end
							break
						end
					end
				end
			end

			if total > 0 then
				local maxvalue, nr = 0, 1

				for sourcename, source in pairs(sources) do
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
						Skada:FormatNumber(source.amount),
						mod.metadata.columns.Healing,
						Skada:FormatNumber(source.overheal or 0),
						mod.metadata.columns.Overhealing,
						format("%.1f%%", 100 * source.amount / max(1, total)),
						mod.metadata.columns.Percent
					)

					if source.amount > maxvalue then
						maxvalue = source.amount
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing Taken"]
		local total = set.heal or 0

		if total > 0 then
			local players = {}

			for _, player in Skada:IteratePlayers(set) do
				if player.heal_targets then
					for targetname, target in pairs(player.heal_targets) do
						if not players[targetname] then
							players[targetname] = {
								id = target.id,
								amount = target.amount,
								overheal = target.overheal
							}
						else
							players[targetname].amount = players[targetname].amount + target.amount
							players[targetname].overheal = players[targetname].overheal + target.overheal
						end
					end
				end
				if player.absorb_targets then
					for targetname, target in pairs(player.absorb_targets) do
						if not players[targetname] then
							players[targetname] = {
								id = target.id,
								amount = target.amount,
								overheal = 0
							}
						else
							players[targetname].amount = players[targetname].amount + target.amount
						end
					end
				end
			end

			local maxvalue, nr = 0, 1

			for playername, player in pairs(players) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = playername
				d.text = Skada:FormatName(playername, player.id)
				d.class, d.role, d.spec = select(2, UnitClass(d.id, nil, set))

				d.value = player.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(player.amount),
					mod.metadata.columns.Healing,
					Skada:FormatNumber(player.overheal),
					mod.metadata.columns.Overhealing,
					format("%.1f%%", 100 * player.amount / total),
					mod.metadata.columns.Percent
				)

				if player.amount > maxvalue then
					maxvalue = player.amount
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		playermod.metadata = {showspots = true}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			columns = {Healing = true, Overhealing = true, Percent = true},
			icon = "Interface\\Icons\\spell_nature_resistnature"
		}
		Skada:AddMode(self, L["Absorbs and Healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)