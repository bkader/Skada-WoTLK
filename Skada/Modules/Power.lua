local Skada = Skada
Skada:RegisterModule("Resources", function(L, P)
	local mod = Skada:NewModule("Resources")
	mod.icon = [[Interface\Icons\spell_holy_rapture]]

	local pairs, format = pairs, string.format
	local setmetatable, GetSpellInfo = setmetatable, Skada.GetSpellInfo or GetSpellInfo
	local _

	local SPELL_POWER_MANA = SPELL_POWER_MANA or 0
	local SPELL_POWER_RAGE = SPELL_POWER_RAGE or 1
	local SPELL_POWER_FOCUS = SPELL_POWER_FOCUS or 2
	local SPELL_POWER_ENERGY = SPELL_POWER_ENERGY or 3
	local SPELL_POWER_HAPPINESS = SPELL_POWER_HAPPINESS or 4
	local SPELL_POWER_RUNIC_POWER = SPELL_POWER_RUNIC_POWER or 6

	-- used to localize modules names.
	local namesTable = {
		[SPELL_POWER_MANA] = "Mana",
		[SPELL_POWER_RAGE] = "Rage",
		[SPELL_POWER_ENERGY] = "Energy",
		[SPELL_POWER_RUNIC_POWER] = "Runic Power"
	}

	-- used to store total amounts for sets and players
	local gainTable = {
		[SPELL_POWER_MANA] = "mana",
		[SPELL_POWER_RAGE] = "rage",
		[SPELL_POWER_FOCUS] = "energy",
		[SPELL_POWER_ENERGY] = "energy",
		[SPELL_POWER_HAPPINESS] = "energy",
		[SPELL_POWER_RUNIC_POWER] = "runic"
	}

	-- users as keys to store spells and their amounts.
	local spellTable = {
		[SPELL_POWER_MANA] = "manaspells",
		[SPELL_POWER_RAGE] = "ragespells",
		[SPELL_POWER_FOCUS] = "energyspells",
		[SPELL_POWER_ENERGY] = "energyspells",
		[SPELL_POWER_HAPPINESS] = "energyspells",
		[SPELL_POWER_RUNIC_POWER] = "runicspells"
	}

	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	local function log_gain(set, gain)
		if not (gain and gain.type and gainTable[gain.type]) then return end

		local player = Skada:GetPlayer(set, gain.playerid, gain.playername, gain.playerflags)
		if player then
			player[gainTable[gain.type]] = (player[gainTable[gain.type]] or 0) + gain.amount
			set[gainTable[gain.type]] = (set[gainTable[gain.type]] or 0) + gain.amount

			if (set ~= Skada.total or P.totalidc) and gain.spellid then
				player[spellTable[gain.type]] = player[spellTable[gain.type]] or {}
				player[spellTable[gain.type]][gain.spellid] = (player[spellTable[gain.type]][gain.spellid] or 0) + gain.amount
			end
		end
	end

	local gain = {}

	local function spell_energize(timestamp, eventtype, srcGUID, srcName, srcFlags, _, _, _, ...)
		gain.spellid, _, _, gain.amount, gain.type = ...
		if gain.spellid and not ignoredSpells[gain.spellid] then
			gain.playerid = srcGUID
			gain.playername = srcName
			gain.playerflags = srcFlags

			Skada:FixPets(gain)

			Skada:DispatchSets(log_gain, gain)
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

			local instance = Skada:NewModule(format("Power gained: %s", powername))
			setmetatable(instance, basemod_mt)

			local pmode = instance:NewModule(format("%s gained spells", powername))
			setmetatable(pmode, playermod_mt)

			pmode.powerid = power
			pmode.power = gainTable[power]
			pmode.powername = powername
			pmode.spells = spellTable[power]
			instance.power = gainTable[power]
			instance.metadata = {
				showspots = true,
				click1 = pmode,
				click4 = Skada.FilterClass,
				click4_label = L["Toggle Class Filter"]
			}

			-- no total click.
			pmode.nototal = true

			return instance
		end
	end

	-- this is the main module update function that shows the list
	-- of players depending on the selected power gain type.
	function basemod:Update(win, set)
		win.title = self.localeName or self.moduleName or L["Unknown"]
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		local total = set and self.power and set[self.power] or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for i = 1, #set.players do
				local player = set.players[i]
				if player and player[self.power] and (not win.class or win.class == player.class) then
					nr = nr + 1
					local d = win:actor(nr, player)

					d.value = player[self.power]
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Amount and Skada:FormatNumber(d.value),
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		local value = self.power and set[self.power] or 0
		return Skada:FormatNumber(value), value
	end

	-- player mods common Enter function.
	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's gained %s"], label, namesTable[self.powerid] or L["Unknown"])
	end

	-- player mods main update function
	function playermod:Update(win, set)
		win.title = format(L["%s's gained %s"], win.actorname or L["Unknown"], L[self.powername])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unavailable for enemies yet

		local total = actor and self.power and actor[self.power] or 0
		if total > 0 and actor[self.spells] then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, amount in pairs(actor[self.spells]) do
				nr = nr + 1
				local d = win:spell(nr, spellid)

				d.value = amount
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Amount and Skada:FormatNumber(d.value),
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	-- we create the modules now
	-- power gained: mana
	local manamod = basemod:Create(SPELL_POWER_MANA)
	local ragemod = basemod:Create(SPELL_POWER_RAGE)
	local energymod = basemod:Create(SPELL_POWER_ENERGY)
	local runicmod = basemod:Create(SPELL_POWER_RUNIC_POWER)

	function mod:OnEnable()
		self.metadata = {columns = {Amount = true, Percent = true, sPercent = true}}
		Skada:AddColumnOptions(self)

		Skada:RegisterForCL(spell_energize, "SPELL_ENERGIZE", "SPELL_PERIODIC_ENERGIZE", {src_is_interesting = true})

		manamod.metadata.icon = [[Interface\Icons\spell_frost_summonwaterelemental]]
		ragemod.metadata.icon = [[Interface\Icons\spell_nature_shamanrage]]
		energymod.metadata.icon = [[Interface\Icons\spell_holy_circleofrenewal]]
		runicmod.metadata.icon = [[Interface\Icons\inv_sword_62]]

		Skada:AddMode(manamod, L["Resources"])
		Skada:AddMode(ragemod, L["Resources"])
		Skada:AddMode(energymod, L["Resources"])
		Skada:AddMode(runicmod, L["Resources"])

		-- table of ignored spells:
		if Skada.ignoredSpells and Skada.ignoredSpells.power then
			ignoredSpells = Skada.ignoredSpells.power
		end
	end

	function mod:OnDisable()
		Skada:RemoveMode(manamod)
		Skada:RemoveMode(ragemod)
		Skada:RemoveMode(energymod)
		Skada:RemoveMode(runicmod)
	end
end)