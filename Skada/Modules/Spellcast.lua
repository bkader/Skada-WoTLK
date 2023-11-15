local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Casts", function(L, P)
	local mode = Skada:NewModule("Casts")
	local mode_spell = mode:NewModule("Spell List")
	local mode_cols = nil

	local pairs, wipe = pairs, wipe
	local format, uformat = string.format, Private.uformat
	local classfmt = Skada.classcolors.format

	local function format_valuetext(d, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Count and d.value,
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local cast = {}
	local function log_spellcast(set)
		local actor = Skada:GetActor(set, cast.actorname, cast.actorid, cast.actorflags)
		if not actor then return end

		set.cast = (set.cast or 0) + 1
		actor.cast = (actor.cast or 0) + 1

		local spellid = (set ~= Skada.total or P.totalidc) and cast.spellid
		if not spellid then return end

		actor.castspells = actor.castspells or {}
		actor.castspells[spellid] = (actor.castspells[spellid] or 0) + 1
	end

	local function spell_cast(t)
		if not t.spellstring then return end

		cast.actorid = t.srcGUID
		cast.actorname = t.srcName
		cast.actorflags = t.srcFlags
		cast.spellid = t.spellstring

		Skada:FixPets(cast)
		Skada:DispatchSets(log_spellcast)
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["%s's spells"], classfmt(win.actorclass, win.actorname))
		if not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.cast
		local spells = total and total > 0 and actor.castspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, cast in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = cast
			format_valuetext(d, total, win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Casts"], L[win.class]) or L["Casts"]

		local total = set:GetTotal(win.class, nil, "cast")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors
		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.cast then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.cast
				format_valuetext(d, total, win.metadata)
			end
		end
	end

	function mode:GetSetSummary(set, win)
		local value = set and set:GetTotal(win and win.class, nil, "cast")
		return value, Skada:FormatNumber(value)
	end

	function mode:OnEnable()
		self.metadata = {
			showspots = true,
			filterclass = true,
			click1 = mode_spell,
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\ICONS\spell_frost_frostbolt02]]
		}

		mode_cols = self.metadata.columns

		Skada:RegisterForCL(spell_cast, {src_is_interesting = true}, "SPELL_CAST_SUCCESS")

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self)
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mode:CombatLeave()
		wipe(cast)
	end

	---------------------------------------------------------------------------

	local actorPrototype = Skada.actorPrototype
	local spellnames = Skada.spellnames
	local cast_string = "%s (\124cffffd100?\124r)"

	function actorPrototype:GetSpellCast(spellid)
		if spellid and self.castspells then
			if self.castspells[spellid] then
				return self.castspells[spellid]
			end

			local spellname = spellnames[spellid]
			for spellstring, cast in pairs(self.castspells) do
				local name = spellnames[spellstring]
				if spellname == name then
					return format(cast_string, cast)
				end
			end
		end
		return format(cast_string, "")
	end
end)
