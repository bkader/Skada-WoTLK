local Skada = Skada
Skada:AddLoadableModule("Dispels", function(L)
	if Skada:IsDisabled("Dispels") then return end

	local mod = Skada:NewModule(L["Dispels"])
	local spellmod = mod:NewModule(L["Dispelled spell list"])
	local targetmod = mod:NewModule(L["Dispelled target list"])
	local playermod = mod:NewModule(L["Dispel spell list"])

	-- cache frequently used globals
	local pairs, ipairs, select = pairs, ipairs, select
	local tostring, format = tostring, string.format
	local GetSpellInfo, tContains = Skada.GetSpellInfo or GetSpellInfo, tContains
	local _

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_dispel(set, data)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			-- increment player's and set's dispels count
			player.dispel = (player.dispel or 0) + 1
			set.dispel = (set.dispel or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.current and data.spellid then
				local spell = player.dispelspells and player.dispelspells[data.spellid]
				if not spell then
					player.dispelspells = player.dispelspells or {}
					player.dispelspells[data.spellid] = {count = 0}
					spell = player.dispelspells[data.spellid]
				end
				spell.count = spell.count + 1

				-- the dispelled spell
				if data.extraspellid then
					spell.spells = spell.spells or {}
					spell.spells[data.extraspellid] = (spell.spells[data.extraspellid] or 0) + 1
				end

				-- the dispelled target
				if data.dstName then
					local actor = Skada:GetActor(set, data.dstGUID, data.dstName, data.dstFlags)
					if actor then
						spell.targets = spell.targets or {}
						spell.targets[data.dstName] = (spell.targets[data.dstName] or 0) + 1
					end
				end
			end
		end
	end

	local data = {}

	local function SpellDispel(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		data.spellid, _, _, data.extraspellid = ...
		data.extraspellid = data.extraspellid or 6603

		-- invalid/ignored spell?
		if (data.spellid and tContains(ignoredSpells, data.spellid)) or tContains(ignoredSpells, data.extraspellid) then
			return
		end

		data.playerid = srcGUID
		data.playername = srcName
		data.playerflags = srcFlags

		data.dstGUID = dstGUID
		data.dstName = dstName
		data.dstFlags = dstFlags

		log_dispel(Skada.current, data)
		log_dispel(Skada.total, data)
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's dispelled spells"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's dispelled spells"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.dispel or 0
		local spells = (total > 0) and player:GetDispelledSpells()

		if spells and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, count in pairs(spells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = count
				d.valuetext = Skada:FormatValueText(
					d.value,
					mod.metadata.columns.Total,
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
		win.title = format(L["%s's dispelled targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's dispelled targets"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.dispel or 0
		local targets = (total > 0) and player:GetDispelledTargets()

		if targets and total > 0 then
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

				d.value = target.count
				d.valuetext = Skada:FormatValueText(
					d.value,
					mod.metadata.columns.Total,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's dispel spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's dispel spells"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.dispel or 0

		if total > 0 and player.dispelspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.dispelspells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = spell.count
				d.valuetext = Skada:FormatValueText(
					d.value,
					mod.metadata.columns.Total,
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
		win.title = win.class and format("%s (%s)", L["Dispels"], L[win.class]) or L["Dispels"]

		local total = set.dispel or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.dispel or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.spec = player.spec
					d.role = player.role

					d.value = player.dispel
					d.valuetext =
						Skada:FormatValueText(
						d.value,
						self.metadata.columns.Total,
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
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = spellmod,
			click2 = targetmod,
			click3 = playermod,
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {spellmod, targetmod, playermod},
			columns = {Total = true, Percent = true},
			icon = [[Interface\Icons\spell_holy_dispelmagic]]
		}

		Skada:RegisterForCL(
			SpellDispel,
			"SPELL_DISPEL",
			"SPELL_STOLEN",
			{src_is_interesting = true}
		)

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if set and (set.dispel or 0) > 0 then
			tooltip:AddDoubleLine(L["Dispels"], set.dispel, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return tostring(set.dispel or 0), set.dispel or 0
	end

	do
		local playerPrototype = Skada.playerPrototype
		local cacheTable = Skada.cacheTable
		local wipe = wipe

		function playerPrototype:GetDispelledSpells()
			if self.dispelspells then
				wipe(cacheTable)
				for _, spell in pairs(self.dispelspells) do
					if spell.spells then
						for spellid, count in pairs(spell.spells) do
							cacheTable[spellid] = (cacheTable[spellid] or 0) + count
						end
					end
				end
				return cacheTable
			end
		end

		function playerPrototype:GetDispelledTargets()
			if self.dispelspells then
				wipe(cacheTable)
				for _, spell in pairs(self.dispelspells) do
					if spell.targets then
						for name, count in pairs(spell.targets) do
							if not cacheTable[name] then
								cacheTable[name] = {count = count}
							else
								cacheTable[name].count = cacheTable[name].count + count
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
	end
end)