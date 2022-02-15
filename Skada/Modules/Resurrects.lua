local Skada = Skada
Skada:AddLoadableModule("Resurrects", function(L)
	if Skada:IsDisabled("Resurrects") then return end

	local mod = Skada:NewModule(L["Resurrects"])
	local playermod = mod:NewModule(L["Resurrect spell list"])
	local targetmod = mod:NewModule(L["Resurrect target list"])

	local select, pairs, ipairs = select, pairs, ipairs
	local tostring, format = tostring, string.format
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local _

	local spellSchools = {
		-- Rebirth
		[20484] = 8,
		[20739] = 8,
		[20742] = 8,
		[20747] = 8,
		[20748] = 8,
		[26994] = 8,
		[48477] = 8,
		-- Reincarnation
		[16184] = 8,
		[16209] = 8,
		[20608] = 8
	}

	local function log_resurrect(set, data)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			player.ress = (player.ress or 0) + 1
			set.ress = (set.ress or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.total then return end

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
				local actor = Skada:FindActor(set, data.dstGUID, data.dstName, data.dstFlags)
				if actor then
					spell.targets = spell.targets or {}
					spell.targets[data.dstName] = (spell.targets[data.dstName] or 0) + 1
				end
			end
		end
	end

	local data = {}

	local function SpellResurrect(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...
		if not spellid then return end

		data.spellid = spellid

		data.playerid = srcGUID
		data.playername = srcName
		data.playerflags = srcFlags

		data.dstGUID = dstGUID
		data.dstName = dstName
		data.dstFlags = dstFlags

		log_resurrect(Skada.current, data)
		log_resurrect(Skada.total, data)
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's resurrect spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's resurrect spells"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.ress or 0

		if total > 0 and player.resspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.resspells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)
				d.spellschool = spellSchools[spellid]

				d.value = spell.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's resurrect targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's resurrect targets"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.ress or 0
		local targets = (total > 0) and player:GetRessTargets()

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
				d.text = target.id and Skada:FormatName(targetname, target.id)
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
			for _, player in ipairs(set.players) do
				if (player.ress or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

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
			nototalclick = {playermod, targetmod},
			columns = {Count = true, Percent = false},
			icon = [[Interface\Icons\spell_holy_resurrection]]
		}

		Skada:RegisterForCL(
			SpellResurrect,
			"SPELL_RESURRECT",
			{src_is_interesting = true, dst_is_interesting = true}
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
		local cacheTable = Skada.cacheTable

		function playerPrototype:GetRessTargets()
			if self.resspells then
				wipe(cacheTable)
				for _, spell in pairs(self.resspells) do
					if spell.targets then
						for name, count in pairs(spell.targets) do
							if not cacheTable[name] then
								cacheTable[name] = {count = count}
							else
								cacheTable[name].count = cacheTable[name].count + count
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