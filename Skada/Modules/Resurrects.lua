local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Resurrects", function(L, P, _, C)
	local mod = Skada:NewModule("Resurrects")
	local spellmod = mod:NewModule("Resurrect spell list")
	local targetmod = mod:NewModule("Resurrect target list")

	local pairs, format, uformat = pairs, string.format, Private.uformat
	local new, clear = Private.newTable, Private.clearTable
	local get_actor_ress_targets = nil
	local mod_cols = nil

	local ress_spells = {
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

	local ress = {}
	local function log_resurrect(set)
		local actor = Skada:GetPlayer(set, ress.actorid, ress.actorname, ress.actorflags)
		if not actor then return end

		actor.ress = (actor.ress or 0) + 1
		set.ress = (set.ress or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not ress.spellid then return end

		-- spell
		local spell = actor.resspells and actor.resspells[ress.spellid]
		if not spell then
			actor.resspells = actor.resspells or {}
			actor.resspells[ress.spellid] = {count = 0}
			spell = actor.resspells[ress.spellid]
		end
		spell.count = spell.count + 1

		-- spell targets
		if ress.dstName then
			spell.targets = spell.targets or {}
			spell.targets[ress.dstName] = (spell.targets[ress.dstName] or 0) + 1
		end
	end

	local function spell_resurrect(t)
		if t.spellid and (t.event == "SPELL_RESURRECT" or ress_spells[t.spellid]) then
			ress.spellid = t.spellid
			ress.actorid = t.srcGUID
			ress.actorname = t.srcName
			ress.actorflags = t.srcFlags
			ress.dstName = (t.event == "SPELL_RESURRECT") and t.dstName or t.srcName

			Skada:DispatchSets(log_resurrect)
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's resurrect spells"], label)
	end

	function spellmod:Update(win, set)
		win.title = uformat(L["%s's resurrect spells"], win.actorname)
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

			local d = win:spell(nr, spellid, nil, ress_spells[spellid])
			d.value = spell.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's resurrect targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's resurrect targets"], win.actorname)
		if not set or not win.actorname then return end

		local targets, total, actor = get_actor_ress_targets(set, win.actorid, win.actorname)
		if not targets or not actor or total == 0 then
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
		local actors = set.actors

		for i = 1, #actors do
			local actor = actors[i]
			if win:show_actor(actor, set, true) and actor.ress then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy)
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
			click1 = spellmod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\spell_holy_resurrection]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		spellmod.nototal = true
		targetmod.nototal = true

		Skada:RegisterForCL(spell_resurrect, {src_is_not_interesting = true, dst_is_interesting_nopets = true}, "SPELL_RESURRECT")
		Skada:RegisterForCL(spell_resurrect, {src_is_interesting = true, dst_is_not_interesting = true}, "SPELL_CAST_SUCCESS")

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

	get_actor_ress_targets = function(self, id, name, tbl)
		local actor = self:GetActor(name, id)
		local total = actor and actor.ress
		local spells = total and actor.resspells
		if not spells then return end

		tbl = clear(tbl or C)
		for _, spell in pairs(spells) do
			if spell.targets then
				for targetname, count in pairs(spell.targets) do
					local t = tbl[targetname]
					if not t then
						t = new()
						t.count = count
						tbl[targetname] = t
					else
						t.count = t.count + count
					end
					self:_fill_actor_table(t, targetname)
				end
			end
		end
		return tbl, total, actor
	end
end)
