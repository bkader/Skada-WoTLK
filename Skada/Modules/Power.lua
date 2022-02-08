local Skada = Skada
Skada:AddLoadableModule("Resources", function(L)
	if Skada:IsDisabled("Resources") then return end

	local mod = Skada:NewModule(L["Resources"])
	mod.icon = [[Interface\Icons\spell_holy_rapture]]

	local pairs, ipairs, format, tContains = pairs, ipairs, string.format, tContains
	local setmetatable, GetSpellInfo = setmetatable, Skada.GetSpellInfo or GetSpellInfo
	local _

	-- used to localize modules names.
	local namesTable = {
		[0] = MANA,
		[1] = RAGE,
		[3] = ENERGY,
		[6] = RUNIC_POWER
	}

	-- used to store total amounts for sets and players
	local gainTable = {
		[0] = "mana",
		[1] = "rage",
		[2] = "energy",
		[3] = "energy",
		[4] = "energy",
		[6] = "runic"
	}

	-- users as keys to store spells and their amounts.
	local spellTable = {
		[0] = "manaspells",
		[1] = "ragespells",
		[2] = "energyspells",
		[3] = "energyspells",
		[4] = "energyspells",
		[6] = "runicspells"
	}

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_gain(set, gain)
		if not (gain and gain.type and gainTable[gain.type]) then return end

		local player = Skada:GetPlayer(set, gain.playerid, gain.playername, gain.playerflags)
		if player then
			player[gainTable[gain.type]] = (player[gainTable[gain.type]] or 0) + gain.amount
			set[gainTable[gain.type]] = (set[gainTable[gain.type]] or 0) + gain.amount

			if set == Skada.current then
				player[spellTable[gain.type]] = player[spellTable[gain.type]] or {}
				player[spellTable[gain.type]][gain.spellid] = (player[spellTable[gain.type]][gain.spellid] or 0) + gain.amount
			end
		end
	end

	local gain = {}

	local function SpellEnergize(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		gain.spellid, _, _, gain.amount, gain.type = ...
		if gain.spellid and not tContains(ignoredSpells, gain.spellid) then
			gain.playerid = dstGUID
			gain.playername = dstName
			gain.playerflags = dstFlags

			Skada:FixPets(gain)

			log_gain(Skada.current, gain)
			log_gain(Skada.total, gain)
		end
	end

	local function SpellLeech(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		gain.spellid, _, _, gain.amount, gain.type = ...
		if gain.spellid and not tContains(ignoredSpells, gain.spellid) then
			gain.playerid = dstGUID
			gain.playername = dstName
			gain.playerflags = dstFlags

			Skada:FixPets(gain)

			log_gain(Skada.current, gain)
			log_gain(Skada.total, gain)
		end
	end

	-- a base module used to create our power modules.
	local basemod = {}
	local basemod_mt = {__index = basemod}

	-- a base player module used to create power gained per player modules.
	local playermod = {}
	local playermod_mt = {__index = playermod}

	-- allows us to create a module for each power type.
	function basemod:Create(power)
		if gainTable[power] then
			local powername = namesTable[power]
			local instance = Skada:NewModule(format(L["Power gained: %s"], powername))
			setmetatable(instance, basemod_mt)

			local pmode = instance:NewModule(format(L["%s gained spells"], powername))
			setmetatable(pmode, playermod_mt)

			pmode.powerid = power
			pmode.power = gainTable[power]
			pmode.powername = powername
			pmode.spells = spellTable[power]
			instance.power = gainTable[power]
			instance.metadata = {showspots = true, click1 = pmode, nototalclick = {pmode}}
			return instance
		end
	end

	-- this is the main module update function that shows the list
	-- of players depending on the selected power gain type.
	function basemod:Update(win, set)
		win.title = self.moduleName or L.Unknown
		local total = set and self.power and set[self.power] or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if player[self.power] then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player[self.power]
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Amount,
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

	-- base function used to return sets summaries
	function basemod:GetSetSummary(set)
		if set and self.power then
			local value = set[self.power] or 0
			local valuetext = (self.power == "mana") and Skada:FormatNumber(value) or value
			return valuetext, value
		end
	end

	-- player mods common Enter function.
	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's gained %s"], label, namesTable[self.powerid] or L.Unknown)
	end

	-- player mods main update function
	function playermod:Update(win, set)
		win.title = format(L["%s's gained %s"], win.playername or L.Unknown, self.powername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and self.power and player[self.power] or 0

		if total > 0 and player[self.spells] then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, amount in pairs(player[self.spells]) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Amount,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	-- we create the modules now
	-- power gained: mana
	local manamod = basemod:Create(0)
	local ragemod = basemod:Create(1)
	local energymod = basemod:Create(3)
	local runicmod = basemod:Create(6)

	function mod:OnEnable()
		self.metadata = {columns = {Amount = true, Percent = true}}
		Skada:AddColumnOptions(self)

		local flags_src = {src_is_interesting = true}

		Skada:RegisterForCL(
			SpellEnergize,
			"SPELL_ENERGIZE",
			"SPELL_PERIODIC_ENERGIZE",
			flags_src
		)

		Skada:RegisterForCL(
			SpellLeech,
			"SPELL_LEECH",
			"SPELL_PERIODIC_LEECH",
			flags_src
		)

		manamod.metadata.icon = [[Interface\Icons\spell_frost_summonwaterelemental]]
		ragemod.metadata.icon = [[Interface\Icons\spell_nature_shamanrage]]
		energymod.metadata.icon = [[Interface\Icons\spell_holy_circleofrenewal]]
		runicmod.metadata.icon = [[Interface\Icons\inv_sword_62]]

		Skada:AddMode(manamod, L["Resources"])
		Skada:AddMode(ragemod, L["Resources"])
		Skada:AddMode(energymod, L["Resources"])
		Skada:AddMode(runicmod, L["Resources"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(manamod)
		Skada:RemoveMode(ragemod)
		Skada:RemoveMode(energymod)
		Skada:RemoveMode(runicmod)
	end
end)