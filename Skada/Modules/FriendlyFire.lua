local Skada = Skada
Skada:RegisterModule("Friendly Fire", function(L, P, _, C, new, del, clear)
	local mod = Skada:NewModule("Friendly Fire")
	local targetmod = mod:NewModule("Damage target list")
	local spellmod = mod:NewModule("Damage spell list")
	local spelltargetmod = spellmod:NewModule("Damage spell targets")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local passiveSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	local pairs, max, format = pairs, math.max, string.format
	local pformat, T = Skada.pformat, Skada.Table
	local _

	local function log_damage(set, dmg)
		local player = Skada:GetPlayer(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if not player then return end

		if dmg.amount > 0 and dmg.spellid and not passiveSpells[dmg.spellid] then
			Skada:AddActiveTime(set, player, true, nil, dmg.dstName)
		end

		player.friendfire = (player.friendfire or 0) + dmg.amount
		set.friendfire = (set.friendfire or 0) + dmg.amount

		-- to save up memory, we only record the rest to the current set.
		if (set == Skada.total and not P.totalidc) or not dmg.spellid then return end

		-- spell
		local spell = player.friendfirespells and player.friendfirespells[dmg.spellid]
		if not spell then
			player.friendfirespells = player.friendfirespells or {}
			player.friendfirespells[dmg.spellid] = {amount = 0}
			spell = player.friendfirespells[dmg.spellid]
		end
		spell.amount = spell.amount + dmg.amount

		-- target
		if dmg.dstName then
			spell.targets = spell.targets or {}
			spell.targets[dmg.dstName] = (spell.targets[dmg.dstName] or 0) + dmg.amount
		end
	end

	local dmg = {}

	local function spell_damage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local amount, absorbed

			if eventtype == "SWING_DAMAGE" then
				dmg.spellid = 6603
				amount, _, _, _, _, absorbed = ...
			else
				dmg.spellid, _, _, amount, _, _, _, _, absorbed = ...
			end

			if dmg.spellid and not ignoredSpells[dmg.spellid] then
				dmg.playerid = srcGUID
				dmg.playername = srcName
				dmg.playerflags = srcFlags

				dmg.dstGUID = dstGUID
				dmg.dstName = dstName
				dmg.dstFlags = dstFlags

				dmg.amount = (amount or 0) + (absorbed or 0)

				Skada:DispatchSets(log_damage, dmg)
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's targets"], win.actorname)

		local actor = set and set:GetPlayer(win.actorid, win.actorname)
		local total = actor and actor.friendfire or 0
		local targets = (total > 0) and actor:GetFriendlyFireTargets()

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
		for targetname, target in pairs(targets) do
			nr = nr + 1
			local d = win:actor(nr, target, nil, targetname)

			d.value = target.amount
			d.valuetext = Skada:FormatValueCols(
				mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
				actortime and Skada:FormatNumber(d.value / actortime),
				mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
			)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor damage"](label)
	end

	function spellmod:Update(win, set)
		win.title = L["actor damage"](win.actorname or L["Unknown"])

		local actor = set and set:GetPlayer(win.actorid, win.actorname)
		local total = actor and actor.friendfire or 0

		if total == 0 or not actor.friendfirespells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
		for spellid, spell in pairs(actor.friendfirespells) do
			nr = nr + 1
			local d = win:spell(nr, spellid)

			d.value = spell.amount
			d.valuetext = Skada:FormatValueCols(
				mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
				actortime and Skada:FormatNumber(d.value / actortime),
				mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
			)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end
	end

	function spelltargetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = pformat(L["%s's <%s> damage"], win.actorname, label)
	end

	function spelltargetmod:Update(win, set)
		win.title = pformat(L["%s's <%s> damage"], win.actorname, win.spellname)
		if not win.spellid then return end

		local actor = set and set:GetPlayer(win.actorid, win.actorname)
		local total = actor and actor.friendfire or 0
		local targets = nil
		if total > 0 and actor.friendfirespells and actor.friendfirespells[win.spellid] then
			total = actor.friendfirespells[win.spellid].amount
			targets = actor.friendfirespells[win.spellid].targets
		end

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
		for targetname, amount in pairs(targets) do
			nr = nr + 1
			local d = win:actor(nr, targetname)

			local tactor = set:GetActor(targetname)
			if tactor then
				d.id = tactor.id or d.id or targetname
				d.class = tactor.class
				d.role = tactor.role
				d.spec = tactor.spec
			end

			d.value = amount
			d.valuetext = Skada:FormatValueCols(
				mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
				actortime and Skada:FormatNumber(d.value / actortime),
				mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
			)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Friendly Fire"], L[win.class]) or L["Friendly Fire"]

		local total = set.friendfire or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for i = 1, #set.players do
			local player = set.players[i]
			if player and player.friendfire and (not win.class or win.class == player.class) then
				nr = nr + 1
				local d = win:actor(nr, player)

				d.value = player.friendfire
				d.valuetext = Skada:FormatValueCols(
					self.metadata.columns.Damage and Skada:FormatNumber(d.value),
					self.metadata.columns.DPS and Skada:FormatNumber(d.value / max(1, player:GetTime())),
					self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
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

		-- no total click.
		spellmod.nototal = true
		targetmod.nototal = true

		Skada:RegisterForCL(
			spell_damage,
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			{dst_is_interesting_nopets = true, src_is_interesting_nopets = true}
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

	function mod:GetSetSummary(set)
		local value = set.friendfire or 0
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Damage and Skada:FormatNumber(value),
			self.metadata.columns.DPS and Skada:FormatNumber(value / set:GetTime())
		)
		return valuetext, value
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

	do
		local playerPrototype = Skada.playerPrototype
		function playerPrototype:GetFriendlyFireTargets(tbl)
			if not self.friendfirespells then return end

			tbl = clear(tbl or C)
			for _, spell in pairs(self.friendfirespells) do
				if spell.targets then
					for name, amount in pairs(spell.targets) do
						if not tbl[name] then
							tbl[name] = new()
							tbl[name].amount = amount
						else
							tbl[name].amount = tbl[name].amount + amount
						end
						self.super:_fill_actor_table(tbl[name], name)
					end
				end
			end
			return tbl
		end
	end
end)
