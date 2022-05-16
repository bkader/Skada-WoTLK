local Skada = Skada
Skada:AddLoadableModule("Resurrects", function(L)
	if Skada:IsDisabled("Resurrects") then return end

	local mod = Skada:NewModule("Resurrects")
	local playermod = mod:NewModule("Resurrect spell list")
	local targetmod = mod:NewModule("Resurrect target list")

	local pairs, tostring, format = pairs, tostring, string.format
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local _

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

	local function log_resurrect(set, data)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			player.ress = (player.ress or 0) + 1
			set.ress = (set.ress or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if (set == Skada.total and not Skada.db.profile.totalidc) or not data.spellid then return end

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
	end

	local data = {}

	local function SpellResurrect(_, event, srcGUID, srcName, srcFlags, _, dstName, _, spellid)
		if spellid and (event == "SPELL_RESURRECT" or resurrectSpells[spellid]) then
			data.spellid = spellid

			if event == "SPELL_RESURRECT" then
				data.playerid = srcGUID
				data.playername = srcName
				data.playerflags = srcFlags
				data.dstName = dstName
			else
				data.playerid = srcGUID
				data.playername = srcName
				data.playerflags = srcFlags
				data.dstName = srcName
			end

			Skada:DispatchSets(log_resurrect, data)
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's resurrect spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's resurrect spells"], win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unuavailable for enemies yet

		local total = actor and actor.ress or 0
		if total > 0 and actor.resspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(actor.resspells) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)
				d.spellschool = resurrectSpells[spellid]

				d.value = spell.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's resurrect targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's resurrect targets"], win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unavailable for enemies yet

		local total = actor and actor.ress or 0
		local targets = (total > 0) and actor:GetRessTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = target.id or targetname
				d.label = targetname
				d.text = target.id and Skada:FormatName(targetname, target.id)
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Resurrects"]
		local total = set.ress or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for i = 1, #set.players do
				local player = set.players[i]
				if player and player.ress then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.ress
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Count and d.value,
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:OnEnable()
		self.metadata = {
			valuesort = true,
			click1 = playermod,
			click2 = targetmod,
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\spell_holy_resurrection]]
		}

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		Skada:RegisterForCL(
			SpellResurrect,
			"SPELL_RESURRECT",
			{src_is_interesting = true, dst_is_interesting = true}
		)

		Skada:RegisterForCL(
			SpellResurrect,
			"SPELL_CAST_SUCCESS",
			{src_is_interesting = true, dst_is_not_interesting = true}
		)

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if (set.ress or 0) > 0 then
			tooltip:AddDoubleLine(L["Resurrects"], set.ress, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return tostring(set.ress or 0), set.ress or 0
	end

	do
		local playerPrototype = Skada.playerPrototype

		function playerPrototype:GetRessTargets(tbl)
			if self.resspells then
				tbl = wipe(tbl or Skada.cacheTable)
				for _, spell in pairs(self.resspells) do
					if spell.targets then
						for name, count in pairs(spell.targets) do
							if not tbl[name] then
								tbl[name] = {count = count}
							else
								tbl[name].count = tbl[name].count + count
							end
							if not tbl[name].class then
								local actor = self.super:GetActor(name)
								if actor then
									tbl[name].id = actor.id
									tbl[name].class = actor.class
									tbl[name].role = actor.role
									tbl[name].spec = actor.spec
								end
							end
						end
					end
				end
				return tbl
			end
		end
	end
end)