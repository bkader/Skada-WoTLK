local Skada = Skada
Skada:RegisterModule("Dispels", function(L, P, _, C, new, _, clear)
	local mod = Skada:NewModule("Dispels")
	local spellmod = mod:NewModule("Dispelled spell list")
	local targetmod = mod:NewModule("Dispelled target list")
	local playermod = mod:NewModule("Dispel spell list")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local get_dispelled_spells = nil
	local get_dispelled_targets = nil

	-- cache frequently used globals
	local pairs, tostring, format, pformat = pairs, tostring, string.format, Skada.pformat
	local _

	local function format_valuetext(d, columns, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Count and d.value,
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local dispel = {}
	local function log_dispel(set)
		local player = Skada:GetPlayer(set, dispel.playerid, dispel.playername, dispel.playerflags)
		if not player then return end

		-- increment player's and set's dispels count
		player.dispel = (player.dispel or 0) + 1
		set.dispel = (set.dispel or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not dispel.spellid then return end

		local spell = player.dispelspells and player.dispelspells[dispel.spellid]
		if not spell then
			player.dispelspells = player.dispelspells or {}
			player.dispelspells[dispel.spellid] = {count = 1}
			spell = player.dispelspells[dispel.spellid]
		else
			spell.count = spell.count + 1
		end

		-- the dispelled spell
		if dispel.extraspellid then
			spell.spells = spell.spells or {}
			spell.spells[dispel.extraspellid] = (spell.spells[dispel.extraspellid] or 0) + 1
		end

		-- the dispelled target
		if dispel.dstName then
			spell.targets = spell.targets or {}
			spell.targets[dispel.dstName] = (spell.targets[dispel.dstName] or 0) + 1
		end
	end

	local function spell_dispel(_, _, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		dispel.spellid, _, _, dispel.extraspellid = ...
		dispel.extraspellid = dispel.extraspellid or 6603

		-- invalid/ignored spell?
		if (dispel.spellid and ignoredSpells[dispel.spellid]) or ignoredSpells[dispel.extraspellid] then return end

		dispel.playerid = srcGUID
		dispel.playername = srcName
		dispel.playerflags = srcFlags

		dispel.dstGUID = dstGUID
		dispel.dstName = dstName
		dispel.dstFlags = dstFlags

		Skada:DispatchSets(log_dispel)
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's dispelled spells"], label)
	end

	function spellmod:Update(win, set)
		win.title = pformat(L["%s's dispelled spells"], win.actorname)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.dispel or 0
		local spells = (total > 0) and get_dispelled_spells(player)

		if not spells or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, count in pairs(spells) do
			nr = nr + 1
			local d = win:spell(nr, spellid)

			d.value = count
			format_valuetext(d, mod.metadata.columns, total, win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's dispelled targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's dispelled targets"], win.actorname)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.dispel or 0
		local targets = (total > 0) and get_dispelled_targets(player)

		if not targets or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for targetname, target in pairs(targets) do
			nr = nr + 1
			local d = win:actor(nr, target, true, targetname)

			d.value = target.count
			format_valuetext(d, mod.metadata.columns, total, win.metadata, true)
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's dispel spells"], label)
	end

	function playermod:Update(win, set)
		win.title = pformat(L["%s's dispel spells"], win.actorname)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.dispel or 0

		if total == 0 or not player.dispelspells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, spell in pairs(player.dispelspells) do
			nr = nr + 1
			local d = win:spell(nr, spellid)

			d.value = spell.count
			format_valuetext(d, mod.metadata.columns, total, win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Dispels"], L[win.class]) or L["Dispels"]

		local total = set.dispel or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for i = 1, #set.players do
			local player = set.players[i]
			if player and player.dispel and (not win.class or win.class == player.class) then
				nr = nr + 1
				local d = win:actor(nr, player)

				d.value = player.dispel
				format_valuetext(d, self.metadata.columns, total, win.metadata)
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

		Skada:RegisterForCL(spell_dispel, "SPELL_DISPEL", "SPELL_STOLEN", {src_is_interesting = true})

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

	---------------------------------------------------------------------------

	get_dispelled_spells = function(self, tbl)
		if not self.dispelspells then return end

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

	get_dispelled_targets = function(self, tbl)
		if not self.dispelspells then return end

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
					self.super:_fill_actor_table(tbl[name], name)
				end
			end
		end
		return tbl
	end
end)
