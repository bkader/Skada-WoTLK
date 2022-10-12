local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Resources", function(L, P)
	local mod = Skada:NewModule("Resources")
	mod.icon = [[Interface\Icons\spell_holy_rapture]]

	local setmetatable, pairs = setmetatable, pairs
	local format, uformat = string.format, Private.uformat
	local mod_cols = nil

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

	local function format_valuetext(d, columns, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Amount and Skada:FormatNumber(d.value),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local gain = {}
	local function log_gain(set)
		if not (gain and gain.type and gainTable[gain.type]) then return end

		local player = Skada:GetPlayer(set, gain.playerid, gain.playername, gain.playerflags)
		if not player then return end

		player[gainTable[gain.type]] = (player[gainTable[gain.type]] or 0) + gain.amount
		set[gainTable[gain.type]] = (set[gainTable[gain.type]] or 0) + gain.amount

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not gain.spellid then return end

		player[spellTable[gain.type]] = player[spellTable[gain.type]] or {}
		player[spellTable[gain.type]][gain.spellid] = (player[spellTable[gain.type]][gain.spellid] or 0) + gain.amount
	end

	local function spell_energize(_, _, srcGUID, srcName, srcFlags, _, _, _, spellid, _, _, amount, gain_type)
		if spellid and not ignoredSpells[spellid] then
			gain.playerid, gain.playername, gain.playerflags = Skada:FixMyPets(srcGUID, srcName, srcFlags)
			gain.spellid = spellid
			gain.amount = amount
			gain.type = gain_type

			Skada:DispatchSets(log_gain)
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
		if not power or not gainTable[power] then return end

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

	-- this is the main module update function that shows the list
	-- of players depending on the selected power gain type.
	function basemod:Update(win, set)
		win.title = self.localeName or self.moduleName or L["Unknown"]
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		local total = set and set:GetTotal(win.class, nil, self.power)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if win:show_actor(actor, set) and actor[self.power] then
				nr = nr + 1

				local d = win:actor(nr, actor)
				d.value = actor[self.power]
				format_valuetext(d, mod_cols, total, win.metadata)
			end
		end
	end

	-- base function used to return sets summaries
	function basemod:GetSetSummary(set, win)
		if not set then return end
		local value = set:GetTotal(win and win.class, nil, self.power) or 0
		return value, Skada:FormatNumber(value)
	end

	-- player mods common Enter function.
	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = uformat(L["%s's gained %s"], label, namesTable[self.powerid])
	end

	-- player mods main update function
	function playermod:Update(win, set)
		win.title = uformat(L["%s's gained %s"], win.actorname, L[self.powername])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unavailable for enemies yet

		local total = actor and self.power and actor[self.power]
		local spells = (total and total > 0) and actor[self.spells]

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, amount in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = amount
			format_valuetext(d, mod_cols, total, win.metadata, true)
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
		mod_cols = self.metadata.columns
		Skada:AddColumnOptions(self)

		Skada:RegisterForCL(spell_energize, {src_is_interesting = true}, "SPELL_ENERGIZE", "SPELL_PERIODIC_ENERGIZE")

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
