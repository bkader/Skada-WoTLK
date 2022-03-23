local Skada = Skada
Skada:AddLoadableModule("Interrupts", function(L)
	if Skada:IsDisabled("Interrupts") then return end

	local mod = Skada:NewModule(L["Interrupts"])
	local spellmod = mod:NewModule(L["Interrupted spells"])
	local targetmod = mod:NewModule(L["Interrupted targets"])
	local playermod = mod:NewModule(L["Interrupt spells"])
	local _

	-- cache frequently used globals
	local pairs, ipairs, tostring, format, tContains = pairs, ipairs, tostring, string.format, tContains
	local GetSpellInfo, GetSpellLink = Skada.GetSpellInfo or GetSpellInfo, Skada.GetSpellLink or GetSpellLink

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_interrupt(set, data)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			-- increment player's and set's interrupts count
			player.interrupt = (player.interrupt or 0) + 1
			set.interrupt = (set.interrupt or 0) + 1

			-- to save up memory, we only record the rest to the current set.
			if set ~= Skada.total then
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

		spellid = spellid or 6603
		spellname = spellname or L.Melee

		-- invalid/ignored spell?
		if tContains(ignoredSpells, spellid) or (extraspellid and tContains(ignoredSpells, extraspellid)) then
			return
		end

		data.playerid = srcGUID
		data.playername = srcName
		data.playerflags = srcFlags

		data.dstGUID = dstGUID
		data.dstName = dstName
		data.dstFlags = dstFlags

		data.spellid = spellid
		data.extraspellid = extraspellid

		Skada:FixPets(data)

		Skada:DispatchSets(log_interrupt, data)
		log_interrupt(Skada.total, data)

		if Skada.db.profile.modules.interruptannounce and srcGUID == Skada.userGUID then
			local spelllink = extraspellname or dstName
			if Skada.db.profile.reportlinks then
				spelllink = GetSpellLink(extraspellid or extraspellname) or spelllink
			end
			Skada:SendChat(format(L["%s interrupted!"], spelllink), Skada.db.profile.modules.interruptchannel or "SAY", "preset", true)
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's interrupted spells"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's interrupted spells"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unavailable for enemeies yet

		local total = actor and actor.interrupt or 0
		local spells = (total > 0) and actor:GetInterruptedSpells()
		if spells and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, count in pairs(spells) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)

				d.value = count
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
		win.title = format(L["%s's interrupted targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's interrupted targets"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unavailable for enemies yet

		local total = actor and actor.interrupt or 0
		local targets = (total > 0) and actor:GetInterruptTargets()

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

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's interrupt spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's interrupt spells"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unavailable for enemies yet

		local total = actor and actor.interrupt or 0
		if total > 0 and actor.interruptspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(actor.interruptspells) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)

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

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Interrupts"], L[win.class]) or L["Interrupts"]

		local total = set.interrupt or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.interrupt or 0) > 0 then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.interrupt
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
			showspots = true,
			ordersort = true,
			click1 = spellmod,
			click2 = targetmod,
			click3 = playermod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {spellmod, targetmod, playermod},
			columns = {Count = true, Percent = true, sPercent = true},
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
		local wipe = wipe

		function playerPrototype:GetInterruptedSpells(tbl)
			if self.interruptspells then
				tbl = wipe(tbl or Skada.cacheTable)
				for _, spell in pairs(self.interruptspells) do
					if spell.spells then
						for spellid, count in pairs(spell.spells) do
							tbl[spellid] = (tbl[spellid] or 0) + count
						end
					end
				end
				return tbl
			end
		end

		function playerPrototype:GetInterruptTargets(tbl)
			if self.interruptspells then
				tbl = wipe(tbl or Skada.cacheTable)
				for _, spell in pairs(self.interruptspells) do
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
								else
									tbl[name].class = "UNKNOWN"
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