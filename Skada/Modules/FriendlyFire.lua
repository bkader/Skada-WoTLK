local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Friendly Fire", function(L, P, _, C)
	local mod = Skada:NewModule("Friendly Fire")
	local targetmod = mod:NewModule("Damage target list")
	local spellmod = mod:NewModule("Damage spell list")
	local spelltargetmod = spellmod:NewModule("Damage spell targets")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local passiveSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local get_actor_friendfire_targets = nil

	local pairs, wipe, format, uformat = pairs, wipe, string.format, Private.uformat
	local new, del, clear = Private.newTable, Private.delTable, Private.clearTable
	local mod_cols = nil

	local function format_valuetext(d, columns, total, dps, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Damage and Skada:FormatNumber(d.value),
			columns[subview and "sDPS" or "DPS"] and dps and Skada:FormatNumber(dps),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local dmg = {}
	local function log_damage(set)
		if not dmg.spellid or not dmg.amount or dmg.amount == 0 then return end

		local actor = Skada:GetPlayer(set, dmg.actorid, dmg.actorname, dmg.actorflags)
		if not actor then
			return
		elseif not passiveSpells[dmg.spellid] then
			Skada:AddActiveTime(set, actor, dmg.dstName)
		end

		actor.friendfire = (actor.friendfire or 0) + dmg.amount
		set.friendfire = (set.friendfire or 0) + dmg.amount

		-- to save up memory, we only record the rest to the current set.
		if (set == Skada.total and not P.totalidc) or not dmg.spellid then return end

		-- spell
		local spell = actor.friendfirespells and actor.friendfirespells[dmg.spellid]
		if not spell then
			actor.friendfirespells = actor.friendfirespells or {}
			actor.friendfirespells[dmg.spellid] = {amount = 0, school = dmg.school}
			spell = actor.friendfirespells[dmg.spellid]
		elseif not spell.school and dmg.school then
			spell.school = dmg.school
		end
		spell.amount = spell.amount + dmg.amount

		-- target
		if dmg.dstName then
			spell.targets = spell.targets or {}
			spell.targets[dmg.dstName] = (spell.targets[dmg.dstName] or 0) + dmg.amount
		end
	end

	local function spell_damage(t)
		if t.srcGUID ~= t.dstGUID and t.spellid and not ignoredSpells[t.spellid] and (not t.misstype or t.misstype == "ABSORB") then
			dmg.actorid = t.srcGUID
			dmg.actorname = t.srcName
			dmg.actorflags = t.srcFlags

			dmg.spellid = t.spellid
			dmg.school = t.spellschool
			dmg.amount = t.amount

			if t.absorbed and t.absorbed > 0 then
				dmg.amount = dmg.amount + t.absorbed
			end

			dmg.dstName = Skada:FixPetsName(t.dstGUID, t.dstName, t.dstFlags)
			Skada:DispatchSets(log_damage)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's targets"], win.actorname)

		local targets, total, actor = get_actor_friendfire_targets(set, win.actorid, win.actorname)
		if not targets or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, nil, targetname)
			d.value = target.amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor damage"](label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor damage"](win.actorname or L["Unknown"])

		local actor = set and set:GetPlayer(win.actorid, win.actorname)
		local total = actor and actor.friendfire
		local spells = (total and total > 0) and actor.friendfirespells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = spell.amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function spelltargetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> damage"], win.actorname, label)
	end

	function spelltargetmod:Update(win, set)
		win.title = uformat(L["%s's <%s> damage"], win.actorname, win.spellname)
		if not win.spellid then return end

		local actor = set and set:GetPlayer(win.actorid, win.actorname)
		local total = actor and actor.friendfire
		local spell = (total and total > 0) and actor.friendfirespells and actor.friendfirespells[win.spellid]

		if not spell then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		total = spell.amount -- total becomes that of the spell
		local targets = spell.targets

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime(set)

		for targetname, amount in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, targetname)
			set:_fill_actor_table(d, targetname)

			d.value = amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Friendly Fire"], L[win.class]) or L["Friendly Fire"]

		local total = set and set:GetTotal(win.class, nil, "friendfire")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for i = 1, #actors do
			local actor = actors[i]
			if win:show_actor(actor, set, true) and actor.friendfire then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy)
				d.value = actor.friendfire
				format_valuetext(d, mod_cols, total, mod_cols.DPS and (d.value / actor:GetTime(set)), win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set, win)
		if not set then return end
		local value = set:GetTotal(win and win.class, nil, "friendfire") or 0
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Damage and Skada:FormatNumber(value),
			self.metadata.columns.DPS and Skada:FormatNumber(value / set:GetTime())
		)
		return value, valuetext
	end

	function mod:OnEnable()
		spellmod.metadata = {click1 = spelltargetmod}
		self.metadata = {
			showspots = true,
			click1 = spellmod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Damage = true, DPS = false, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\inv_gizmo_supersappercharge]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		spellmod.nototal = true
		targetmod.nototal = true

		local flags_src_dst = {src_is_interesting_nopets = true, dst_is_interesting = true}

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
		Skada:AddMode(self, L["Damage Done"])

		-- table of ignored spells:
		if Skada.ignoredSpells then
			if Skada.ignoredSpells.friendfire then
				ignoredSpells = Skada.ignoredSpells.friendfire
			end
			if Skada.ignoredSpells.activeTime then
				passiveSpells = Skada.ignoredSpells.activeTime
			end
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:CombatLeave()
		wipe(dmg)
	end

	function mod:SetComplete(set)
		if not set.friendfire or set.friendfire == 0 then return end
		for i = 1, #set.actors do
			local actor = set.actors[i]
			local amount = actor and not actor.enemy and actor.friendfire
			if (actor and not amount and actor.friendfirespells) or amount == 0 then
				actor.friendfire = nil
				actor.friendfirespells = del(actor.friendfirespells, true)
			end
		end
	end

	---------------------------------------------------------------------------

	get_actor_friendfire_targets = function(self, id, name, tbl)
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
end)
