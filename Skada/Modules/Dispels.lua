local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Dispels", function(L, P, _, C)
	local mode = Skada:NewModule("Dispels")
	local mode_extraspell = mode:NewModule("Spell List")
	local mode_target = mode:NewModule("Target List")
	local mode_spell = mode:NewModule("Dispel Spells")
	local classfmt = Skada.classcolors.format
	local ignored_spells = Skada.ignored_spells.dispel -- Edit Skada\Core\Tables.lua
	local get_actor_dispelled_spells = nil
	local get_actor_dispelled_targets = nil

	-- cache frequently used globals
	local pairs, format = pairs, string.format
	local uformat, new, clear = Private.uformat, Private.newTable, Private.clearTable
	local mode_cols = nil

	local function format_valuetext(d, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Count and d.value,
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local dispel = {}
	local function log_dispel(set)
		local actor = Skada:GetActor(set, dispel.actorname, dispel.actorid, dispel.actorflags)
		if not actor then return end

		-- increment actor's and set's dispels count
		actor.dispel = (actor.dispel or 0) + 1
		set.dispel = (set.dispel or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not dispel.spellid then return end

		local spell = actor.dispelspells and actor.dispelspells[dispel.spellid]
		if not spell then
			actor.dispelspells = actor.dispelspells or {}
			actor.dispelspells[dispel.spellid] = {count = 1}
			spell = actor.dispelspells[dispel.spellid]
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

	local function spell_dispel(t)
		if t.spellid and not ignored_spells[t.spellid] and not ignored_spells[t.extraspellid] then
			dispel.actorid = t.srcGUID
			dispel.actorname = t.srcName
			dispel.actorflags = t.srcFlags

			dispel.dstName = Skada:FixPetsName(t.dstGUID, t.dstName, t.dstFlags)
			dispel.spellid = t.spellstring
			dispel.extraspellid = t.extrastring

			Skada:FixPets(dispel)
			Skada:DispatchSets(log_dispel)
		end
	end

	function mode_extraspell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's dispelled spells"], classfmt(class, label))
	end

	function mode_extraspell:Update(win, set)
		win.title = uformat(L["%s's dispelled spells"], classfmt(win.actorclass, win.actorname))

		local spells, total, actor = get_actor_dispelled_spells(set, win.actorname, win.actorid)
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, count in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = count
			format_valuetext(d, total, win.metadata, true)
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))

		local targets, total, actor = get_actor_dispelled_targets(set, win.actorname, win.actorid)
		if not targets or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, targetname)
			d.value = target.count
			format_valuetext(d, total, win.metadata, true)
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["%s's spells"], classfmt(win.actorclass, win.actorname))

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.dispel
		local spells = (total and total > 0) and actor.dispelspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = spell.count
			format_valuetext(d, total, win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Dispels"], L[win.class]) or L["Dispels"]

		local total = set and set:GetTotal(win.class, nil, "dispel")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.dispel then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.dispel
				format_valuetext(d, total, win.metadata)
			end
		end
	end

	function mode:GetSetSummary(set, win)
		if not set then return end
		local value = set:GetTotal(win and win.class, nil, "dispel") or 0
		return value, Skada:FormatNumber(value)
	end

	function mode:AddToTooltip(set, tooltip)
		if set.dispel and set.dispel > 0 then
			tooltip:AddDoubleLine(L["Dispels"], set.dispel, 1, 1, 1)
		end
	end

	function mode:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			filterclass = true,
			click1 = mode_target,
			click2 = mode_extraspell,
			click3 = mode_spell,
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\ICONS\spell_holy_dispelmagic]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_extraspell.nototal = true
		mode_target.nototal = true
		mode_spell.nototal = true

		Skada:RegisterForCL(spell_dispel, {src_is_interesting = true}, "SPELL_DISPEL", "SPELL_STOLEN")
		Skada:AddMode(self)
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	get_actor_dispelled_spells = function(self, name, id, tbl)
		local actor = self:GetActor(name, id)
		local total = actor and actor.dispel
		local spells = total and total > 0 and actor.dispelspells
		if not spells then return end

		tbl = clear(tbl or C)
		for _, spell in pairs(spells) do
			if spell.spells then
				for spellid, count in pairs(spell.spells) do
					tbl[spellid] = (tbl[spellid] or 0) + count
				end
			end
		end
		return tbl, total, actor
	end

	get_actor_dispelled_targets = function(self, name, id, tbl)
		local actor = self:GetActor(name, id)
		local total = actor and actor.dispel
		local spells = total and total > 0 and actor.dispelspells
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
					self:_fill_actor_table(t, targetname, nil, true)
				end
			end
		end
		return tbl, total, actor
	end
end)
