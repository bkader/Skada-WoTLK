local Skada = Skada
Skada:RegisterModule("Dispels", function(L, P, _, C, new, _, clear)
	local mod = Skada:NewModule("Dispels")
	local spellmod = mod:NewModule("Dispelled spell list")
	local targetmod = mod:NewModule("Dispelled target list")
	local playermod = mod:NewModule("Dispel spell list")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	-- cache frequently used globals
	local pairs, tostring, format = pairs, tostring, string.format
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local _

	local function log_dispel(set, data)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			-- increment player's and set's dispels count
			player.dispel = (player.dispel or 0) + 1
			set.dispel = (set.dispel or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if (set ~= Skada.total or P.totalidc) and data.spellid then
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
					spell.targets = spell.targets or {}
					spell.targets[data.dstName] = (spell.targets[data.dstName] or 0) + 1
				end
			end
		end
	end

	local data = {}

	local function SpellDispel(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		data.spellid, _, _, data.extraspellid = ...
		data.extraspellid = data.extraspellid or 6603

		-- invalid/ignored spell?
		if (data.spellid and ignoredSpells[data.spellid]) or ignoredSpells[data.extraspellid] then return end

		data.playerid = srcGUID
		data.playername = srcName
		data.playerflags = srcFlags

		data.dstGUID = dstGUID
		data.dstName = dstName
		data.dstFlags = dstFlags

		Skada:DispatchSets(log_dispel, data)
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's dispelled spells"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's dispelled spells"], win.actorname or L["Unknown"])

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.dispel or 0
		local spells = (total > 0) and player:GetDispelledSpells()

		if spells and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, count in pairs(spells) do
				nr = nr + 1
				local d = win:spell(nr, spellid)

				d.value = count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's dispelled targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's dispelled targets"], win.actorname or L["Unknown"])

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.dispel or 0
		local targets = (total > 0) and player:GetDispelledTargets()

		if targets and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:actor(nr, target, true, targetname)

				d.value = target.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's dispel spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's dispel spells"], win.actorname or L["Unknown"])

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.dispel or 0

		if total > 0 and player.dispelspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.dispelspells) do
				nr = nr + 1
				local d = win:spell(nr, spellid)

				d.value = spell.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
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
			for i = 1, #set.players do
				local player = set.players[i]
				if player and player.dispel and (not win.class or win.class == player.class) then
					nr = nr + 1
					local d = win:actor(nr, player)

					d.value = player.dispel
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Count and d.value,
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
			click1 = targetmod,
			click2 = spellmod,
			click3 = playermod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\spell_holy_dispelmagic]]
		}

		-- no total click.
		spellmod.nototal = true
		targetmod.nototal = true
		playermod.nototal = true

		Skada:RegisterForCL(
			SpellDispel,
			"SPELL_DISPEL",
			"SPELL_STOLEN",
			{src_is_interesting = true}
		)

		Skada:AddMode(self)

		-- table of ignored spells:
		if Skada.ignoredSpells and Skada.ignoredSpells.dispels then
			ignoredSpells = Skada.ignoredSpells.dispels
		end
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if set.dispel and set.dispel > 0 then
			tooltip:AddDoubleLine(L["Dispels"], set.dispel, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		local dispels = set.dispel or 0
		return tostring(dispels), dispels
	end

	do
		local playerPrototype = Skada.playerPrototype

		function playerPrototype:GetDispelledSpells(tbl)
			if self.dispelspells then
				tbl = clear(tbl or C)
				for _, spell in pairs(self.dispelspells) do
					if spell.spells then
						for spellid, count in pairs(spell.spells) do
							tbl[spellid] = (tbl[spellid] or 0) + count
						end
					end
				end
				return tbl
			end
		end

		function playerPrototype:GetDispelledTargets(tbl)
			if self.dispelspells then
				tbl = clear(tbl or C)
				for _, spell in pairs(self.dispelspells) do
					if spell.targets then
						for name, count in pairs(spell.targets) do
							if not tbl[name] then
								tbl[name] = new()
								tbl[name].count = count
							else
								tbl[name].count = tbl[name].count + count
							end
							if not tbl[name].class then
								local actor = self.super:GetActor(name)
								if actor then
									tbl[name].id = actor.id
									tbl[name].class = actor.class
									tbl[name].role = actor.role
									tbl[name].spec = actor.spec
								end
							end
						end
					end
				end
				return tbl
			end
		end
	end
end)