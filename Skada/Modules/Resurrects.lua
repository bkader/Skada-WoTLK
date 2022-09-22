local _, Skada = ...
Skada:RegisterModule("Resurrects", function(L, P, _, C)
	local mod = Skada:NewModule("Resurrects")
	local playermod = mod:NewModule("Resurrect spell list")
	local targetmod = mod:NewModule("Resurrect target list")

	local pairs, format, pformat = pairs, string.format, Skada.pformat
	local new, clear = Skada.newTable, Skada.clearTable
	local get_resurrected_targets = nil
	local mod_cols = nil

	local resurrectSpells = {
		-- Rebirth
		[20484] = 0x08,
		[20739] = 0x08,
		[20742] = 0x08,
		[20747] = 0x08,
		[20748] = 0x08,
		[26994] = 0x08,
		[48477] = 0x08,
		-- Reincarnation
		[16184] = 0x08,
		[16209] = 0x08,
		[20608] = 0x08,
		[21169] = 0x08,
		-- Use Soulstone
		[3026] = 0x01,
		[20758] = 0x01,
		[20759] = 0x01,
		[20760] = 0x01,
		[20761] = 0x01,
		[27240] = 0x01,
		[47882] = 0x01
	}

	local function format_valuetext(d, columns, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Count and d.value,
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local data = {}
	local function log_resurrect(set)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if not player then return end

		player.ress = (player.ress or 0) + 1
		set.ress = (set.ress or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not data.spellid then return end

		-- spell
		local spell = player.resspells and player.resspells[data.spellid]
		if not spell then
			player.resspells = player.resspells or {}
			player.resspells[data.spellid] = {count = 0}
			spell = player.resspells[data.spellid]
		end
		spell.count = spell.count + 1

		-- spell targets
		if data.dstName then
			spell.targets = spell.targets or {}
			spell.targets[data.dstName] = (spell.targets[data.dstName] or 0) + 1
		end
	end

	local function spell_resurrect(_, event, srcGUID, srcName, srcFlags, _, dstName, _, spellid)
		if spellid and (event == "SPELL_RESURRECT" or resurrectSpells[spellid]) then
			data.spellid = spellid
			data.playerid = srcGUID
			data.playername = srcName
			data.playerflags = srcFlags
			data.dstName = (event == "SPELL_RESURRECT") and dstName or srcName

			Skada:DispatchSets(log_resurrect)
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's resurrect spells"], label)
	end

	function playermod:Update(win, set)
		win.title = pformat(L["%s's resurrect spells"], win.actorname)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = (actor and not enemy) and actor.ress

		if not total or total == 0 or not actor.resspells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, spell in pairs(actor.resspells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, nil, resurrectSpells[spellid])
			d.value = spell.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's resurrect targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's resurrect targets"], win.actorname)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = (actor and not enemy) and actor.ress
		local targets = (total and total > 0) and get_resurrected_targets(actor)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, nil, targetname)
			d.value = target.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = L["Resurrects"]

		local total = set and set:GetTotal(win.class, nil, "ress")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor.ress and (not win.class or win.class == actor.class) then
				nr = nr + 1

				local d = win:actor(nr, actor)
				d.value = actor.ress
				format_valuetext(d, mod_cols, total, win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set, win)
		if not set then return end
		return set:GetTotal(win and win.class, nil, "ress") or 0
	end

	function mod:OnEnable()
		self.metadata = {
			valuesort = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\spell_holy_resurrection]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		Skada:RegisterForCL(spell_resurrect, "SPELL_RESURRECT", {src_is_interesting = true, dst_is_interesting = true})
		Skada:RegisterForCL(spell_resurrect, "SPELL_CAST_SUCCESS", {src_is_interesting = true, dst_is_not_interesting = true})

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if set.ress and set.ress > 0 then
			tooltip:AddDoubleLine(L["Resurrects"], set.ress, 1, 1, 1)
		end
	end

	---------------------------------------------------------------------------

	get_resurrected_targets = function(self, tbl)
		if not self.resspells then return end

		tbl = clear(tbl or C)
		for _, spell in pairs(self.resspells) do
			if spell.targets then
				for name, count in pairs(spell.targets) do
					local t = tbl[name]
					if not t then
						t = new()
						t.count = count
						tbl[name] = t
					else
						t.count = t.count + count
					end
					self.super:_fill_actor_table(t, name)
				end
			end
		end
		return tbl
	end
end)
