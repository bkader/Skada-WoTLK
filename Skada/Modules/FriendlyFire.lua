local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Friendly Fire", function(L, P, _, C)
	local mode = Skada:NewModule("Friendly Fire")
	local mode_target = mode:NewModule("Target List")
	local mode_spell = mode:NewModule("Spell List")
	local mode_spell_target = mode_spell:NewModule("Target List")
	local get_actor_friendfire_targets = nil
	local get_spell_friendfire_targets = nil
	local mode_cols = nil

	local pairs, wipe, format, uformat = pairs, wipe, string.format, Private.uformat
	local new, del, clear = Private.newTable, Private.delTable, Private.clearTable
	local classfmt = Skada.classcolors.format
	local ignored_spells = Skada.ignored_spells.damage -- Edit Skada\Core\Tables.lua
	local passive_spells = Skada.ignored_spells.time -- Edit Skada\Core\Tables.lua

	local function format_valuetext(d, total, dps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(d.value),
			mode_cols[subview and "sDPS" or "DPS"] and dps and Skada:FormatNumber(dps),
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local dmg = {}
	local function log_damage(set)
		if not dmg.amount or dmg.amount == 0 then return end

		local actor = Skada:GetActor(set, dmg.actorname, dmg.actorid, dmg.actorflags)
		if not actor then
			return
		elseif not passive_spells[dmg.spell] then
			Skada:AddActiveTime(set, actor, dmg.dstName)
		end

		actor.friendfire = (actor.friendfire or 0) + dmg.amount
		set.friendfire = (set.friendfire or 0) + dmg.amount

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- spell
		local spell = actor.friendfirespells and actor.friendfirespells[dmg.spellid]
		if not spell then
			actor.friendfirespells = actor.friendfirespells or {}
			actor.friendfirespells[dmg.spellid] = {amount = 0}
			spell = actor.friendfirespells[dmg.spellid]
		end
		spell.amount = spell.amount + dmg.amount

		-- target
		if dmg.dstName then
			spell.targets = spell.targets or {}
			spell.targets[dmg.dstName] = (spell.targets[dmg.dstName] or 0) + dmg.amount
		end
	end

	local function spell_damage(t)
		if t.srcGUID ~= t.dstGUID and t.spellid and not ignored_spells[t.spellid] and (not t.misstype or t.misstype == "ABSORB") then
			dmg.actorid = t.srcGUID
			dmg.actorname = t.srcName
			dmg.actorflags = t.srcFlags
			dmg.dstName = t.dstName

			dmg.spell = t.spellid
			dmg.spellid = t.spellstring

			dmg.amount = t.amount
			if t.absorbed and t.absorbed > 0 then
				dmg.amount = dmg.amount + t.absorbed
			end

			Skada:DispatchSets(log_damage)
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))

		local targets, total, actor = get_actor_friendfire_targets(set, win.actorname, win.actorid)
		if not targets or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, targetname)
			d.value = target.amount
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's spells"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["%s's spells"], classfmt(win.actorclass, win.actorname))

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.friendfire
		local spells = (total and total > 0) and actor.friendfirespells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, true)
			d.value = spell.amount
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_spell_target:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> targets"], classfmt(win.actorclass, win.actorname), label)
	end

	function mode_spell_target:Update(win, set)
		win.title = uformat(L["%s's <%s> targets"], classfmt(win.actorclass, win.actorname), win.spellname)
		if not win.spellid then return end

		local targets, total, actor = get_spell_friendfire_targets(set, win.actorname, win.actorid, win.spellid)
		if not targets or not actor then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, targetname)
			d.value = target.amount
			format_valuetext(d, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Friendly Fire"], L[win.class]) or L["Friendly Fire"]

		local total = set and set:GetTotal(win.class, nil, "friendfire")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.friendfire then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.friendfire
				format_valuetext(d, total, mode_cols.DPS and (d.value / actor:GetTime(set)), win.metadata)
			end
		end
	end

	function mode_target:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		local value = actor and actor.friendfire
		if not value or value == 0 then return end

		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(value),
			mode_cols.sDPS and Skada:FormatNumber(value / actor:GetTime())
		)
		return value, valuetext
	end
	mode_spell.GetSetSummary = mode_target.GetSetSummary

	function mode:GetSetSummary(set, win)
		if not set then return end
		local value = set:GetTotal(win and win.class, nil, "friendfire") or 0
		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(value),
			mode_cols.DPS and Skada:FormatNumber(value / set:GetTime())
		)
		return value, valuetext
	end

	function mode:OnEnable()
		mode_spell.metadata = {click1 = mode_spell_target}
		self.metadata = {
			showspots = true,
			filterclass = true,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Damage = true, DPS = false, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\ICONS\inv_gizmo_supersappercharge]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		local flags_src_dst = {src_is_interesting_nopets = true, dst_is_interesting_nopets = true}

		Skada:RegisterForCL(
			spell_damage,
			flags_src_dst,
			-- damage events
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			-- missed events
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED"
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, "Damage Done")
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mode:CombatLeave()
		wipe(dmg)
	end

	function mode:SetComplete(set)
		if not set.friendfire or set.friendfire == 0 then return end
		for _, actor in pairs(set.actors) do
			local amount = not actor.enemy and actor.friendfire
			if (not amount and actor.friendfirespells) or amount == 0 then
				actor.friendfire = nil
				actor.friendfirespells = del(actor.friendfirespells, true)
			end
		end
	end

	---------------------------------------------------------------------------

	get_actor_friendfire_targets = function(self, name, id, tbl)
		local actor = self:GetActor(name, id)
		local total = actor and actor.friendfire
		local spells = total and actor.friendfirespells
		if not spells then return end

		tbl = clear(tbl or C)
		for _, spell in pairs(spells) do
			if spell.targets then
				for targetname, amount in pairs(spell.targets) do
					local t = tbl[targetname]
					if not t then
						t = new()
						t.amount = amount
						tbl[targetname] = t
					else
						t.amount = t.amount + amount
					end
					self:_fill_actor_table(t, targetname)
				end
			end
		end
		return tbl, total, actor
	end

	get_spell_friendfire_targets = function(self, name, id, spellid, tbl)
		local actor = spellid and self:GetActor(name, id)
		local spell = actor and actor.friendfirespells and actor.friendfirespells[spellid]
		if not spell or not spell.targets then return end

		tbl = clear(tbl or C)
		for targetname, amount in pairs(spell.targets) do
			local t = new()
			t.amount = amount
			self:_fill_actor_table(t, targetname)
			tbl[targetname] = t
		end
		return tbl, spell.amount, actor
	end
end)
