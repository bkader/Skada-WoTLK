local Skada = Skada
Skada:AddLoadableModule("Friendly Fire", function(L)
	if Skada:IsDisabled("Friendly Fire") then return end

	local mod = Skada:NewModule(L["Friendly Fire"])
	local targetmod = mod:NewModule(L["Damage target list"])
	local spellmod = mod:NewModule(L["Damage spell list"])
	local spelltargetmod = spellmod:NewModule(L["Damage spell targets"])

	local pairs, ipairs, select, format = pairs, ipairs, select, string.format
	local GetSpellInfo, tContains = Skada.GetSpellInfo or GetSpellInfo, tContains
	local _

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_damage(set, dmg)
		if dmg.spellid and tContains(ignoredSpells, dmg.spellid) then return end

		local player = Skada:GetPlayer(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if player then
			Skada:AddActiveTime(player, dmg.amount > 0)

			player.friendfire = (player.friendfire or 0) + dmg.amount
			set.friendfire = (set.friendfire or 0) + dmg.amount

			-- to save up memory, we only record the rest to the current set.
			if set ~= Skada.current or not dmg.spellid then return end

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
				local actor = Skada:GetActor(set, dmg.dstGUID, dmg.dstName, dmg.dstFlags)
				if actor then
					spell.targets = spell.targets or {}
					spell.targets[dmg.dstName] = (spell.targets[dmg.dstName] or 0) + dmg.amount
				end
			end
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local amount, absorbed

			if eventtype == "SWING_DAMAGE" then
				dmg.spellid = 6603
				amount, _, _, _, _, absorbed = ...
			else
				dmg.spellid, _, _, amount, _, _, _, _, absorbed = ...
			end

			dmg.playerid = srcGUID
			dmg.playername = srcName
			dmg.playerflags = srcFlags

			dmg.dstGUID = dstGUID
			dmg.dstName = dstName
			dmg.dstFlags = dstFlags

			dmg.amount = (amount or 0) + (absorbed or 0)

			log_damage(Skada.current, dmg)
			log_damage(Skada.total, dmg)
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's targets"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.friendfire or 0
		local targets = (total > 0) and player:GetFriendlyFireTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's damage"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's damage"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.friendfire or 0

		if total > 0 and player.friendfirespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.friendfirespells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = spell.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function spelltargetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's <%s> damage"], win.playername or L.Unknown, label)
	end

	function spelltargetmod:Update(win, set)
		win.title = format(L["%s's <%s> damage"], win.playername or L.Unknown, win.spellname or L.Unknown)
		if not win.spellid then return end

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.friendfire or 0
		local targets = nil
		if total > 0 and player.friendfirespells and player.friendfirespells[win.spellid] then
			targets = player.friendfirespells[win.spellid].targets
		end

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, amount in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = targetname
				d.label = targetname

				local actor = set:GetActor(targetname)
				if actor then
					d.id = actor.id or targetname
					d.class = actor.class
					d.role = actor.role
					d.spec = actor.spec
				end

				d.value = amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Friendly Fire"]
		local total = set.friendfire or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (player.friendfire or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.friendfire
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
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
			nototalclick = {spellmod, targetmod},
			columns = {Damage = true, Percent = true},
			icon = [[Interface\Icons\inv_gizmo_supersappercharge]]
		}

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_EXTRA_ATTACKS", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local value = set.friendfire or 0
		return Skada:FormatNumber(value), value
	end

	function mod:SetComplete(set)
		for _, p in ipairs(set.players) do
			if p.friendfire and p.friendfire == 0 then
				p.friendfirespells = nil
			elseif p.friendfirespells then
				for spellid, spell in pairs(p.friendfirespells) do
					if spell.amount == 0 then
						p.friendfirespells[spellid] = nil
					end
					-- nothing left?!
					if next(p.friendfirespells) == nil then
						p.friendfirespells = nil
					end
				end
			end
		end
	end

	do
		local playerPrototype = Skada.playerPrototype
		local cacheTable = Skada.cacheTable
		local wipe = wipe

		function playerPrototype:GetFriendlyFireTargets()
			if self.friendfirespells then
				wipe(cacheTable)
				for _, spell in pairs(self.friendfirespells) do
					if spell.targets then
						for name, amount in pairs(spell.targets) do
							if not cacheTable[name] then
								cacheTable[name] = {amount = amount}
							else
								cacheTable[name].amount = cacheTable[name].amount + amount
							end
							if not cacheTable[name].class then
								local actor = self.super:GetActor(name)
								if actor then
									cacheTable[name].id = actor.id
									cacheTable[name].class = actor.class
									cacheTable[name].role = actor.role
									cacheTable[name].spec = actor.spec
								else
									cacheTable[name].class = "UNKNOWN"
								end
							end
						end
					end
				end
				return cacheTable
			end
		end
	end
end)