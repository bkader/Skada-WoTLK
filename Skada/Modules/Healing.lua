assert(Skada, "Skada not found!")

-- cache frequently used globals
local _pairs, _select, _format = pairs, select, string.format
local math_max, math_min, _time = math.max, math.min, time
local _GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo

-- ============== --
-- Healing module --
-- ============== --

Skada:AddLoadableModule("Healing", function(Skada, L)
	if Skada:IsDisabled("Healing") then return end

	local mod = Skada:NewModule(L["Healing"])
	local targetmod = mod:NewModule(L["Healed player list"])
	local playermod = mod:NewModule(L["Healing spell list"])

	local _UnitClass = Skada.UnitClass

	local function log_heal(set, data, tick)
		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
		if player then
			-- get rid of overhealing
			local amount = math_max(0, data.amount - data.overhealing)

			-- record the healing
			player.healing = player.healing or {}
			player.healing.amount = (player.healing.amount or 0) + amount
			set.healing = (set.healing or 0) + amount

			-- record the overhealing
			player.healing.overhealing = (player.healing.overhealing or 0) + (data.overhealing or 0)
			set.overhealing = (set.overhealing or 0) + (data.overhealing or 0)

			-- record the spell
			if data.spellid then
				local spell = player.healing.spells and player.healing.spells[data.spellid]
				if not spell then
					player.healing.spells = player.healing.spells or {}
					player.healing.spells[data.spellid] = {school = data.spellschool}
					spell = player.healing.spells[data.spellid]
				end

				spell.ishot = tick or nil
				spell.count = (spell.count or 0) + 1
				spell.amount = (spell.amount or 0) + amount
				spell.overhealing = (spell.overhealing or 0) + data.overhealing

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

			-- record the target
			if data.dstName then
				local target = player.healing.targets and player.healing.targets[data.dstName]
				if not target then
					player.healing.targets = player.healing.targets or {}
					target = {id = data.dstGUID}
					player.healing.targets[data.dstName] = target
				end

				target.amount = (target.amount or 0) + amount
				target.overhealing = (target.overhealing or 0) + data.overhealing
			end
		end
	end

	local heal = Skada:WeakTable()

	local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, amount, overhealing, absorbed, critical = ...

		heal.playerid = srcGUID
		heal.playername = srcName
		heal.playerflags = srcFlags

		heal.dstGUID = dstGUID
		heal.dstName = dstName
		heal.dstFlags = dstFlags

		heal.spellid = spellid
		heal.spellname = spellname
		heal.spellschool = spellschool

		heal.amount = amount
		heal.overhealing = overhealing
		heal.absorbed = absorbed
		heal.critical = critical

		Skada:FixPets(heal)
		log_heal(Skada.current, heal, eventtype == "SPELL_PERIODIC_HEAL")
		log_heal(Skada.total, heal, eventtype == "SPELL_PERIODIC_HEAL")
	end

	local function getHPS(set, player)
		local amount = player.healing and player.healing.amount or 0
		return amount / math_max(1, Skada:PlayerActiveTime(set, player)), amount
	end

	local function getRaidHPS(set)
		if set.time > 0 then
			return (set.healing or 0) / math_max(1, set.time), (set.healing or 0)
		else
			local endtime = set.endtime or _time()
			return (set.healing or 0) / math_max(1, endtime - set.starttime), (set.healing or 0)
		end
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), win.playerid)
		if player then
			local spell
			if player.healing and player.healing.spells then
				spell = player.healing.spells[id]
			end

			if spell then
				tooltip:AddLine(player.name .. " - " .. label)
				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
				end
				tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
				if spell.min and spell.max then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
				end
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
				if (spell.critical or 0) > 0 then
					tooltip:AddDoubleLine(L["Critical"], _format("%02.1f%%", 100 * spell.critical / math_max(1, spell.count)), 1, 1, 1)
				end
				if (spell.overhealing or 0) > 0 then
					tooltip:AddDoubleLine(L["Overhealing"], _format("%02.1f%%", 100 * spell.overhealing / math_max(1, spell.overhealing + spell.amount)), 1, 1, 1)
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's healing spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's healing spells"], player.name)
			local total = _select(2, getHPS(set, player))

			if total > 0 and player.healing.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.healing.spells) do
					if (spell.amount or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						local spellname, _, spellicon = _GetSpellInfo(spellid)
						d.id = spellid
						d.spellid = spellid
						d.label = spellname
						d.text = spellname .. (spell.ishot and L["HoT"] or "")
						d.icon = spellicon
						d.spellschool = spell.school

						d.value = spell.amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(spell.amount),
							mod.metadata.columns.Healing,
							_format("%02.1f%%", 100 * spell.amount / total),
							mod.metadata.columns.Percent
						)

						if spell.amount > maxvalue then
							maxvalue = spell.amount
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
		win.title = _format(L["%s's healed players"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's healed players"], player.name)
			local total = getHPS(set, player)

			if total > 0 and player.healing.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.healing.targets) do
					if (target.amount or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = target.id or targetname
						d.label = targetname
						d.class, d.role, d.spec = _select(2, _UnitClass(target.id, nil, set))

						d.value = target.amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(target.amount),
							mod.metadata.columns.Healing,
							_format("%02.1f%%", 100 * target.amount / total),
							mod.metadata.columns.Percent
						)

						if target.amount > maxvalue then
							maxvalue = target.amount
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing"]
		local total = _select(2, getRaidHPS(set))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				local hps, amount = getHPS(set, player)
				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.Healing,
						Skada:FormatNumber(hps),
						self.metadata.columns.HPS,
						_format("%02.1f%%", 100 * amount / total),
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
			columns = {Healing = true, HPS = true, Percent = true},
			icon = "Interface\\Icons\\spell_nature_healingtouch"
		}

		Skada:RegisterForCL(SpellHeal, "SPELL_HEAL", {src_is_interesting = true})
		Skada:RegisterForCL(SpellHeal, "SPELL_PERIODIC_HEAL", {src_is_interesting = true})

		Skada:AddMode(self, L["Absorbs and healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatValueText(
			Skada:FormatNumber(set.healing or 0),
			self.metadata.columns.Healing,
			Skada:FormatNumber(getRaidHPS(set)),
			self.metadata.columns.HPS
		)
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
		win.title = _format(L["%s's overheal spells"], label)
	end

	function spellsmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's overheal spells"], player.name)

			if player.healing and player.healing.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.healing.spells) do
					if (spell.overhealing or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						local spellname, _, spellicon = _GetSpellInfo(spellid)
						d.id = spellid
						d.spellid = spellid
						d.label = spellname
						d.text = spellname .. (spell.ishot and L["HoT"] or "")
						d.icon = spellicon
						d.spellschool = spell.school

						local total = (spell.amount or 0) + spell.overhealing
						d.value = spell.overhealing / total
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(spell.overhealing),
							mod.metadata.columns.Overheal,
							_format("%02.1f%%", 100 * d.value),
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
		win.title = _format(L["%s's overhealed players"], label)
	end

	function playersmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's overhealed players"], player.name)

			if player.healing and player.healing.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.healing.targets) do
					if (target.overhealing or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = target.id or targetname
						d.label = targetname
						d.class, d.role, d.spec = _select(2, _UnitClass(target.id, nil, set))

						local total = (target.amount or 0) + target.overhealing
						d.value = target.overhealing / total
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(target.overhealing),
							mod.metadata.columns.Overheal,
							_format("%02.1f%%", 100 * d.value),
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

		if (set.overhealing or 0) > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.healing and (player.healing.overhealing or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					local total = (player.healing.amount or 0) + player.healing.overhealing
					d.value = player.healing.overhealing / total
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(player.healing.overhealing),
						self.metadata.columns.Overheal,
						_format("%02.1f%%", 100 * d.value),
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
			columns = {Overheal = true, Percent = true},
			icon = "Interface\\Icons\\spell_holy_holybolt"
		}
		Skada:AddMode(self, L["Absorbs and healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.overhealing or 0)
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
		local amount = player.healing and ((player.healing.amount or 0) + (player.healing.overhealing or 0)) or 0
		return amount / math_max(1, Skada:PlayerActiveTime(set, player)), amount
	end

	local function getRaidHPS(set)
		local amount = (set.healing or 0) + (set.overhealing or 0)
		if set.time > 0 then
			return amount / math_max(1, set.time), amount
		else
			return amount / math_max(1, (set.endtime or _time()) - set.starttime), amount
		end
	end

	local function spell_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), win.playerid)
		if player then
			local spell
			if player.healing and player.healing.spells then
				spell = player.healing.spells[id]
			end

			if spell then
				tooltip:AddLine(player.name .. " - " .. label)
				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
				end
				if spell.min and spell.max then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
					tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
					tooltip:AddLine(" ")
				end
				tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(spell.amount + spell.overhealing), 1, 1, 1)
				tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(spell.amount), 1, 1, 1)
				tooltip:AddDoubleLine(L["Overhealing"], Skada:FormatNumber(spell.overhealing), 1, 1, 1)
				tooltip:AddDoubleLine(L["Overheal"], _format("%02.1f%%", 100 * spell.overhealing / math_max(1, spell.overhealing + spell.amount)), 1, 1, 1)
			end
		end
	end

	function spellsmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's healing spells"], label)
	end

	function spellsmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's healing spells"], player.name)
			local total = player.healing and ((player.healing.amount or 0) + (player.healing.overhealing or 0)) or 9

			if total > 0 and player.healing.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.healing.spells) do
					local amount = (spell.amount or 0) + (spell.overhealing or 0)
					if amount > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						local spellname, _, spellicon = _GetSpellInfo(spellid)
						d.id = spellid
						d.spellid = spellid
						d.label = spellname
						d.text = spellname .. (spell.ishot and L["HoT"] or "")
						d.icon = spellicon
						d.spellschool = spell.school

						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(amount),
							mod.metadata.columns.Healing,
							_format("%02.1f%%", 100 * amount / total),
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
		win.title = _format(L["%s's healed players"], label)
	end

	function playersmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's healed players"], player.name)
			local total = player.healing and ((player.healing.amount or 0) + (player.healing.overhealing or 0)) or 0

			if total > 0 and player.healing.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.healing.targets) do
					local amount = (target.amount or 0) + (target.overhealing or 0)
					if amount > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = target.id or targetname
						d.label = targetname
						d.class, d.role, d.spec = _select(2, _UnitClass(target.id, nil, set))

						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(amount),
							mod.metadata.columns.Healing,
							_format("%02.1f%%", 100 * amount / total),
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
		local total = _select(2, getRaidHPS(set))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				local hps, amount = getHPS(set, player)
				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.Healing,
						Skada:FormatNumber(hps),
						self.metadata.columns.HPS,
						_format("%02.1f%%", 100 * amount / total),
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
			columns = {Healing = true, HPS = true, Percent = true},
			icon = "Interface\\Icons\\spell_holy_flashheal"
		}
		Skada:AddMode(self, L["Absorbs and healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local hps, total = getRaidHPS(set)
		return Skada:FormatValueText(
			Skada:FormatNumber(total),
			self.metadata.columns.Healing,
			Skada:FormatNumber(hps),
			self.metadata.columns.HPS
		)
	end
end)

-- ============================== --
-- Healing and overhealing module --
-- ============================== --

Skada:AddLoadableModule("Healing and overhealing", function(Skada, L)
	if Skada:IsDisabled("Healing", "Healing and overhealing") then return end

	local mod = Skada:NewModule(L["Healing and overhealing"])
	local spellmod = mod:NewModule(L["Heal and overheal spells"])
	local targetmod = mod:NewModule(L["Healed and overhealed players"])

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's heal and overheal spells"], label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's heal and overheal spells"], player.name)
			local total = player.healing and ((player.healing.amount or 0) + (player.healing.overhealing or 0)) or 0

			if total > 0 and player.healing.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.healing.spells) do
					local amount = (spell.amount or 0) + (spell.overhealing or 0)
					if amount > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						local spellname, _, spellicon = _GetSpellInfo(spellid)
						d.id = spellid
						d.spellid = spellid
						d.label = spellname
						d.text = spellname .. (spell.ishot and L["HoT"] or "")
						d.icon = spellicon
						d.spellschool = spell.school

						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(spell.amount),
							mod.metadata.columns.Healing,
							Skada:FormatNumber(spell.overhealing),
							mod.metadata.columns.Overheal,
							_format("%02.1f%%", 100 * spell.overhealing / amount),
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
		win.title = _format(L["%s's healed and overhealed players"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player and player.healing and player.healing.targets then
			win.title = _format(L["%s's healed and overhealed players"], player.name)
			local total = player.healing and ((player.healing.amount or 0) + (player.healing.overhealing or 0)) or 0

			if total > 0 and player.healing.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.healing.targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = _select(2, _UnitClass(target.id, nil, set))

					d.value = (target.amount or 0) + (target.overhealing or 0)
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(target.amount),
						mod.metadata.columns.Healing,
						Skada:FormatNumber(target.overhealing),
						mod.metadata.columns.Overheal,
						_format("%02.1f%%", 100 * target.overhealing / math_max(1, d.value)),
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
		win.title = L["Healing and overhealing"]
		local total = (set.healing or 0) + (set.overhealing or 0)

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.healing then
					local amount = (player.healing.amount or 0) + (player.healing.overhealing or 0)
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = total
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.Healing,
						Skada:FormatNumber(player.healing.overhealing or 0),
						self.metadata.columns.Overheal,
						_format("%02.1f%%", 100 * player.healing.overhealing / total),
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
			columns = {Healing = true, Overheal = true, Percent = true},
			icon = "Interface\\Icons\\spell_holy_prayerofhealing02"
		}
		Skada:AddMode(self, L["Absorbs and healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local healing = set.healing or 0
		local overhealing = set.overhealing or 0
		return Skada:FormatValueText(
			Skada:FormatNumber(healing),
			self.metadata.columns.Healing,
			Skada:FormatNumber(overhealing),
			self.metadata.columns.Overheal,
			_format("%02.1f%%", 100 * overhealing / math_max(1, healing + overhealing)),
			self.metadata.columns.Percent
		)
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
		win.title = _format(L["%s's received healing"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's received healing"], player.name)

			local total, sources = 0, {}

			for _, p in Skada:IteratePlayers(set) do
				if p.healing and p.healing.targets then
					for targetname, target in _pairs(p.healing.targets) do
						if target.id == player.id and targetname == player.name then
							total = total + target.amount -- increment total
							sources[p.name] = {
								id = p.id,
								class = p.class,
								role = p.role,
								spec = p.spec,
								amount = target.amount,
								overhealing = target.overhealing
							}
							break
						end
					end
				end
			end

			if total > 0 then
				local maxvalue, nr = 0, 1

				for sourcename, source in _pairs(sources) do
					if (source.amount or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = source.id
						d.label = sourcename
						d.class = source.class
						d.role = source.role
						d.spec = source.spec

						d.value = source.amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(source.amount),
							mod.metadata.columns.Healing,
							Skada:FormatNumber(source.overhealing),
							mod.metadata.columns.Overhealing,
							_format("%02.1f%%", 100 * source.amount / math_max(1, total)),
							mod.metadata.columns.Percent
						)

						if source.amount > maxvalue then
							maxvalue = source.amount
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Healing Taken"]
		local total = set.healing or 0

		if total > 0 then
			local players = {}

			for _, player in Skada:IteratePlayers(set) do
				if player.healing then
					for targetname, target in _pairs(player.healing.targets) do
						if not players[targetname] then
							players[targetname] = CopyTable(target)
						else
							players[targetname].amount = players[targetname].amount + target.amount
							players[targetname].overhealing = (players[targetname].overhealing or 0) + (target.overhealing or 0)
						end
					end
				end
			end

			local maxvalue, nr = 0, 1

			for playername, player in _pairs(players) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = playername
				d.class = player.class or "PET"
				d.role = player.role
				d.spec = player.spec

				d.value = player.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(player.amount),
					mod.metadata.columns.Healing,
					Skada:FormatNumber(player.overhealing),
					mod.metadata.columns.Overhealing,
					_format("%02.1f%%", 100 * player.amount / total),
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
		Skada:AddMode(self, L["Absorbs and healing"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)