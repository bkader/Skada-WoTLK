local Skada = Skada
Skada:AddLoadableModule("Interrupts", function(L)
	if Skada:IsDisabled("Interrupts") then return end

	local mod = Skada:NewModule(L["Interrupts"])
	local spellmod = mod:NewModule(L["Interrupted spells"])
	local targetmod = mod:NewModule(L["Interrupted targets"])
	local playermod = mod:NewModule(L["Interrupt spells"])
	local _

	-- cache frequently used globals
	local pairs, ipairs, select, max = pairs, ipairs, select, math.max
	local tostring, format, tContains = tostring, string.format, tContains
	local UnitGUID, IsInInstance = UnitGUID, IsInInstance
	local GetSpellInfo, GetSpellLink = Skada.GetSpellInfo or GetSpellInfo, Skada.GetSpellLink or GetSpellLink
	local IsInGroup, IsInRaid = Skada.IsInGroup, Skada.IsInRaid

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_interrupt(set, data)
		-- ignored spells
		if data.spellid and tContains(ignoredSpells, data.spellid) then return end
		-- other ignored spells
		if data.extraspellid and tContains(ignoredSpells, data.extraspellid) then return end

		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			-- increment player's and set's interrupts count
			player.interrupt = (player.interrupt or 0) + 1
			set.interrupt = (set.interrupt or 0) + 1

			-- to save up memory, we only record the rest to the current set.
			if set == Skada.current and data.spellid then
				local spell = player.interruptspells and player.interruptspells[data.spellid]
				if not spell then
					player.interruptspells = player.interruptspells or {}
					player.interruptspells[data.spellid] = {count = 0}
					spell = player.interruptspells[data.spellid]
				end
				spell.count = spell.count + 1

				-- record interrupted spell
				if data.extraspellid then
					spell.spells = spell.spells or {}
					spell.spells[data.extraspellid] = (spell.spells[data.extraspellid] or 0) + 1
				end

				-- record the target
				if data.dstName then
					local actor = Skada:GetActor(set, data.dstGUID, data.dstName, data.dstFlags)
					if actor then
						spell.targets = spell.targets or {}
						spell.targets[data.dstName] = (spell.targets[data.dstName] or 0) + 1
					end
				end
			end
		end
	end

	local data = {}

	local function SpellInterrupt(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, _, extraspellid, extraspellname, _ = ...

		data.playerid = srcGUID
		data.playername = srcName
		data.playerflags = srcFlags

		data.dstGUID = dstGUID
		data.dstName = dstName
		data.dstFlags = dstFlags

		data.spellid = spellid or 6603
		data.extraspellid = extraspellid

		Skada:FixPets(data)

		log_interrupt(Skada.current, data)
		log_interrupt(Skada.total, data)

		if Skada.db.profile.modules.interruptannounce and IsInGroup() and srcGUID == Skada.userGUID then
			local spelllink = GetSpellLink(extraspellid or extraspellname) or extraspellname

			local channel = Skada.db.profile.modules.interruptchannel or "SAY"
			if channel == "SELF" then
				Skada:Print(format(L["%s interrupted!"], spelllink or dstName))
				return
			end

			if channel == "AUTO" then
				local zoneType = select(2, IsInInstance())
				if zoneType == "pvp" or zoneType == "arena" then
					channel = "BATTLEGROUND"
				elseif zoneType == "party" or zoneType == "raid" then
					channel = zoneType:upper()
				else
					channel = IsInRaid() and "RAID" or "PARTY"
				end
			end

			Skada:SendChat(format(L["%s interrupted!"], spelllink or dstName), channel, "preset", true)
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's interrupted spells"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's interrupted spells"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.interrupt or 0
		local spells = (total > 0) and player:GetInterruptedSpells()

		if spells and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, count in pairs(spells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = count
				d.valuetext = Skada:FormatValueText(
					d.value,
					mod.metadata.columns.Total,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's interrupted targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's interrupted targets"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.interrupt or 0
		local targets = (total > 0) and player:GetInterruptTargets()

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

				d.value = target.count
				d.valuetext = Skada:FormatValueText(
					d.value,
					mod.metadata.columns.Total,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's interrupt spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's interrupt spells"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.interrupt or 0

		if total > 0 and player.interruptspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.interruptspells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = spell.count
				d.valuetext = Skada:FormatValueText(
					d.value,
					mod.metadata.columns.Total,
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
		win.title = L["Interrupts"]
		local total = set.interrupt or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (player.interrupt or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.interrupt
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Total,
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
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = spellmod,
			click2 = targetmod,
			click3 = playermod,
			nototalclick = {spellmod, targetmod, playermod},
			columns = {Total = true, Percent = true},
			icon = [[Interface\Icons\ability_kick]]
		}

		Skada:RegisterForCL(SpellInterrupt, "SPELL_INTERRUPT", {src_is_interesting = true})
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if set and (set.interrupt or 0) > 0 then
			tooltip:AddDoubleLine(L["Interrupts"], set.interrupt, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return tostring(set.interrupt or 0), set.interrupt or 0
	end

	function mod:OnInitialize()
		if not Skada.db.profile.modules.interruptchannel then
			Skada.db.profile.modules.interruptchannel = "SAY"
		end

		Skada.options.args.modules.args.interrupts = {
			type = "group",
			name = self.moduleName,
			desc = format(L["Options for %s."], self.moduleName),
			args = {
				header = {
					type = "description",
					name = self.moduleName,
					fontSize = "large",
					image = [[Interface\Icons\ability_kick]],
					imageWidth = 18,
					imageHeight = 18,
					imageCoords = {0.05, 0.95, 0.05, 0.95},
					width = "full",
					order = 0
				},
				sep = {
					type = "description",
					name = " ",
					width = "full",
					order = 1
				},
				interruptannounce = {
					type = "toggle",
					name = format(L["Announce %s"], self.moduleName),
					order = 10,
					width = "double"
				},
				interruptchannel = {
					type = "select",
					name = L["Channel"],
					values = {AUTO = INSTANCE, SAY = CHAT_MSG_SAY, YELL = CHAT_MSG_YELL, SELF = L["Self"]},
					order = 20,
					width = "double"
				}
			}
		}
	end

	do
		local playerPrototype = Skada.playerPrototype
		local cacheTable = Skada.cacheTable
		local wipe = wipe

		function playerPrototype:GetInterruptedSpells()
			if self.interruptspells then
				wipe(cacheTable)
				for _, spell in pairs(self.interruptspells) do
					if spell.spells then
						for spellid, count in pairs(spell.spells) do
							cacheTable[spellid] = (cacheTable[spellid] or 0) + count
						end
					end
				end
				return cacheTable
			end
		end

		function playerPrototype:GetInterruptTargets()
			if self.interruptspells then
				wipe(cacheTable)
				for _, spell in pairs(self.interruptspells) do
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