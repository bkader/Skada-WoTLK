local _, Skada = ...
local private = Skada.private
Skada:RegisterModule("Friendly Fire", function(L, P, _, C)
	local mod = Skada:NewModule("Friendly Fire")
	local targetmod = mod:NewModule("Damage target list")
	local spellmod = mod:NewModule("Damage spell list")
	local spelltargetmod = spellmod:NewModule("Damage spell targets")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local passiveSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local get_friendly_fire_targets = nil

	local pairs, format = pairs, string.format
	local uformat, T = private.uformat, Skada.Table
	local new, del, clear = private.newTable, private.delTable, private.clearTable
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

		local player = Skada:GetPlayer(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if not player then
			return
		elseif not passiveSpells[dmg.spellid] then
			Skada:AddActiveTime(set, player, dmg.dstName)
		end

		player.friendfire = (player.friendfire or 0) + dmg.amount
		set.friendfire = (set.friendfire or 0) + dmg.amount

		-- to save up memory, we only record the rest to the current set.
		if (set == Skada.total and not P.totalidc) or not dmg.spellid then return end

		-- spell
		local spell = player.friendfirespells and player.friendfirespells[dmg.spellid]
		if not spell then
			player.friendfirespells = player.friendfirespells or {}
			player.friendfirespells[dmg.spellid] = {amount = 0, school = dmg.school}
			spell = player.friendfirespells[dmg.spellid]
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

	local function spell_damage(_, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID == dstGUID then return end -- ignore damage done to self

		local absorbed

		if eventtype == "SWING_DAMAGE" then
			dmg.spellid, dmg.school = 6603, 0x01
			dmg.amount, _, _, _, _, absorbed = ...
		else
			dmg.spellid, _, dmg.school, dmg.amount, _, _, _, _, absorbed = ...
		end

		if dmg.spellid and not ignoredSpells[dmg.spellid] then
			dmg.playerid = srcGUID
			dmg.playername = srcName
			dmg.playerflags = srcFlags

			if absorbed and absorbed > 0 then
				dmg.amount = dmg.amount + absorbed
			end

			dmg.dstName = Skada:FixPetsName(dstGUID, dstName, dstFlags)
			Skada:DispatchSets(log_damage)
		end
	end

	local function spell_missed(_, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID == dstGUID then return end -- ignore damage done to self

		local misstype

		if eventtype == "SWING_MISSED" then
			dmg.spellid, dmg.school = 6603, 0x01
			misstype, dmg.amount = ...
		else
			dmg.spellid, _, dmg.school, misstype, dmg.amount = ...
		end

		if misstype == "ABSORB" and dmg.spellid and not ignoredSpells[dmg.spellid] then
			dmg.playerid = srcGUID
			dmg.playername = srcName
			dmg.playerflags = srcFlags

			dmg.dstName = Skada:FixPetsName(dstGUID, dstName, dstFlags)
			Skada:DispatchSets(log_damage)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's targets"], win.actorname)

		local actor = set and set:GetPlayer(win.actorid, win.actorname)
		local total = actor and actor.friendfire
		local targets = (total and total > 0) and get_friendly_fire_targets(actor)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime()

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
		local actortime = mod_cols.sDPS and actor:GetTime()

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
		local actortime = mod_cols.sDPS and actor:GetTime()

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

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor.friendfire and (not win.class or win.class == actor.class) then
				nr = nr + 1

				local d = win:actor(nr, actor)
				d.value = actor.friendfire
				format_valuetext(d, mod_cols, total, mod_cols.DPS and (d.value / actor:GetTime()), win.metadata)
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
		spellmod.metadata = {showspots = true, click1 = spelltargetmod}
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
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			flags_src_dst
		)

		Skada:RegisterForCL(
			spell_missed,
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED",
			flags_src_dst
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
		T.clear(dmg)
	end

	function mod:SetComplete(set)
		if not set.friendfire or set.friendfire == 0 then return end
		for i = 1, #set.players do
			local p = set.players[i]
			if p and (p.friendfire == 0 or (not p.friendfire and p.friendfirespells)) then
				p.friendfire, p.friendfirespells = nil, del(p.friendfirespells, true)
			elseif p and p.friendfirespells then
				for spellid, spell in pairs(p.friendfirespells) do
					if spell.amount == 0 then
						p.friendfirespells[spellid] = del(p.friendfirespells[spellid])
					end
				end
				-- nothing left?!
				if next(p.friendfirespells) == nil then
					p.friendfirespells = del(p.friendfirespells)
				end
			end
		end
	end

	---------------------------------------------------------------------------

	get_friendly_fire_targets = function(self, tbl)
		local spells = self.friendfirespells
		if not spells then return end

		tbl = clear(tbl or C)
		for _, spell in pairs(spells) do
			if spell.targets then
				for name, amount in pairs(spell.targets) do
					local t = tbl[name]
					if not t then
						t = new()
						t.amount = amount
						tbl[name] = t
					else
						t.amount = t.amount + amount
					end
					self.super:_fill_actor_table(t, name)
				end
			end
		end
		return tbl
	end
end)
