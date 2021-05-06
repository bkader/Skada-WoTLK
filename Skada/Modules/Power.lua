assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Power gained", function(Skada, L)
	if Skada:IsDisabled("Power gained") then return end

	local mod = Skada:NewModule(L["Power gained"])

	local locales = {
		[0] = MANA,
		[1] = RAGE,
		[3] = ENERGY,
		[6] = RUNIC_POWER
	}

	local _pairs, _ipairs, _select = pairs, ipairs, select
	local _format, _tostring, math_max = string.format, tostring, math.max
	local _GetSpellInfo = Skada.GetSpellInfo
	local _setmetatable = setmetatable

	local function log_gain(set, gain)
		if gain.type == nil then
			return
		elseif gain.type == 2 or gain.type == 4 then
			gain.type = 3 -- Focus & Happiness treated as Energy
		end
		if locales[gain.type] then
			local player = Skada:get_player(set, gain.playerid, gain.playername, gain.playerflags)
			if player then
				-- make sure tables are created.
				player.power = player.power or {}
				player.power[gain.type] = player.power[gain.type] or {amount = 0, spells = {}}
				set.power[gain.type] = set.power[gain.type] or 0

				-- add the amounts.
				player.power[gain.type].amount = (player.power[gain.type].amount or 0) + gain.amount
				set.power[gain.type] = set.power[gain.type] + gain.amount

				-- record the spell
				if not player.power[gain.type].spells[gain.spellname] then
					player.power[gain.type].spells[gain.spellname] = {
						id = gain.spellid,
						school = gain.spellschool,
						amount = 0
					}
				end
				player.power[gain.type].spells[gain.spellname].amount = player.power[gain.type].spells[gain.spellname].amount + gain.amount
			end
		end
	end

	local gain = {}

	local function SpellEnergize(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, amount, powertype = ...

		gain.playerid = dstGUID
		gain.playername = dstName
		gain.playerflags = dstFlags

		gain.spellid = spellid
		gain.spellname = spellname
		gain.spellschool = spellschool
		gain.amount = amount
		gain.type = powertype

		Skada:FixPets(gain)
		log_gain(Skada.current, gain)
		log_gain(Skada.total, gain)
	end

	local function SpellLeech(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, amount, powertype, extraamount = ...

		gain.playerid = dstGUID
		gain.playername = dstName
		gain.playerflags = dstFlags

		gain.spellid = spellid
		gain.spellname = spellname
		gain.spellschool = spellschool
		gain.amount = amount
		gain.type = powertype

		Skada:FixPets(gain)
		log_gain(Skada.current, gain)
		log_gain(Skada.total, gain)
	end

	-- a base module used to create our power modules.
	local basemod = {}
	local basemod_mt = {__index = basemod}

	-- a base player module used to create power gained per player modules.
	local playermod = {}
	local playermod_mt = {__index = playermod}

	-- allows us to create a module for each power type.
	function basemod:Create(power, modname, playermodname)
		local pmode = {metadata = {}, name = playermodname}
		_setmetatable(pmode, playermod_mt)

		local instance = {
			playermod = pmode,
			metadata = {showspots = true, click1 = pmode},
			name = modname
		}
		instance.power = power
		pmode.power = power

		_setmetatable(instance, basemod_mt)
		return instance
	end

	function basemod:GetName()
		return self.name
	end

	-- this is the main module update function that shows the list
	-- of players depending on the selected power gain type.
	function basemod:Update(win, set)
		local max = 0

		if set and set.power and self.power then
			local nr, total = 1, set.power[self.power] or 0

			for _, player in _ipairs(set.players) do
				if player.power[self.power] then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.class = player.class or "PET"
					d.role = player.role or "DAMAGER"
					d.spec = player.spec or 1

					d.value = player.power[self.power].amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Amount,
						_format("%02.1f%%", 100 * d.value / math_max(1, total)),
						mod.metadata.columns.Percent
					)

					if d.value > max then
						max = d.value
					end

					nr = nr + 1
				end
			end
		end

		win.metadata.maxvalue = max
		win.title = self.name
	end

	-- base function used to return sets summaries
	function basemod:GetSetSummary(set)
		if self.power == 0 then
			return Skada:FormatNumber(set.power[self.power] or 0)
		end
		return set.power[self.power] or 0
	end

	function playermod:GetName()
		return self.name
	end

	-- player mods common Enter function.
	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's gained %s"], label, locales[self.power])
	end

	-- player mods main update function
	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)
		local max = 0

		if player and player.power and self.power and player.power[self.power] then
			win.title = _format(L["%s's gained %s"], player.name, locales[self.power])
			local nr = 1
			local nr, total = 1, player.power[self.power].amount or 0

			for spellname, spell in _pairs(player.power[self.power].spells or {}) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spell.id
				d.spellid = spell.id
				d.label = spellname
				d.icon = _select(3, _GetSpellInfo(spell.id))
				d.spellschool = spell.school

				d.value = spell.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Amount,
					_format("%02.1f%%", 100 * d.value / math_max(1, total)),
					mod.metadata.columns.Percent
				)

				if d.value > max then
					max = d.value
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	-- we create the modules now
	local manamod = basemod:Create(0, L["Power gained: Mana"], L["Mana gained spell list"])
	local ragemod = basemod:Create(1, L["Power gained: Rage"], L["Rage gained spell list"])
	local energymod = basemod:Create(3, L["Power gained: Energy"], L["Energy gained spell list"])
	local runicmod = basemod:Create(6, L["Power gained: Runic Power"], L["Runic Power gained spell list"])

	function mod:OnEnable()
		self.metadata = {columns = {Amount = true, Percent = true}}
		Skada:AddColumnOptions(self)

		Skada:RegisterForCL(SpellEnergize, "SPELL_ENERGIZE", {src_is_interesting = true})
		Skada:RegisterForCL(SpellEnergize, "SPELL_PERIODIC_ENERGIZE", {src_is_interesting = true})
		Skada:RegisterForCL(SpellLeech, "SPELL_LEECH", {src_is_interesting = true})
		Skada:RegisterForCL(SpellLeech, "SPELL_PERIODIC_LEECH", {src_is_interesting = true})

		Skada:AddMode(manamod, L["Power gained"])
		Skada:AddMode(ragemod, L["Power gained"])
		Skada:AddMode(energymod, L["Power gained"])
		Skada:AddMode(runicmod, L["Power gained"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(manamod)
		Skada:RemoveMode(ragemod)
		Skada:RemoveMode(energymod)
		Skada:RemoveMode(runicmod)
	end

	function manamod:AddPlayerAttributes(player, set)
		player.power = player.power or {}
	end

	function manamod:AddSetAttributes(set)
		set.power = set.power or {}
	end
end)