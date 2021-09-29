assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Interrupts", function(Skada, L)
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
		if (data.spellid and tContains(ignoredSpells, data.spellid)) or (data.extraspellid and tContains(ignoredSpells, data.extraspellid)) then return end

		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
		if player then
			-- increment player's and set's interrupts count
			player.interrupt = (player.interrupt or 0) + 1
			set.interrupt = (set.interrupt or 0) + 1

			-- to save up memory, we only record the rest to the current set.
			if set ~= Skada.current then
				return
			end

			-- add the interrupted spell
			if data.spellid then
				player.interrupt_spells = player.interrupt_spells or {}
				player.interrupt_spells[data.spellid] = (player.interrupt_spells[data.spellid] or 0) + 1
			end

			-- add the interrupt spell
			if data.extraspellid then
				player.interrupt_ispells = player.interrupt_ispells or {}
				player.interrupt_ispells[data.extraspellid] = (player.interrupt_ispells[data.extraspellid] or 0) + 1
			end

			-- add the interrupted target
			if data.dstName then
				player.interrupt_targets = player.interrupt_targets or {}
				player.interrupt_targets[data.dstName] = (player.interrupt_targets[data.dstName] or 0) + 1
			end
		end
	end

	local data = {}

	local function SpellInterrupt(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, extraspellid, extraspellname, extraschool = ...

		data.playerid = srcGUID
		data.playername = srcName
		data.playerflags = srcFlags
		data.dstName = dstName

		data.spellid = spellid or 6603
		data.spellschool = spellschool

		data.extraspellid = extraspellid
		data.extraspellschool = extraschool

		Skada:FixPets(data)

		log_interrupt(Skada.current, data)
		log_interrupt(Skada.total, data)

		if Skada.db.profile.modules.interruptannounce and IsInGroup() and srcGUID == Skada.userGUID then
			local spelllink = GetSpellLink(extraspellid or extraspellname) or extraspellname

			local channel = Skada.db.profile.modules.interruptchannel or "SAY"
			if channel == "SELF" then
				return Skada:SendChat(format(L["%s interrupted!"], spelllink or dstName), nil, "self")
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

			Skada:SendChat(format(L["%s interrupted!"], spelllink or dstName), channel, "preset")
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's interrupted spells"], label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)
		if player then
			win.title = format(L["%s's interrupted spells"], player.name)
			local total = player.interrupt or 0

			if total > 0 and player.interrupt_ispells then
				local maxvalue, nr = 0, 1

				for spellid, count in pairs(player.interrupt_ispells) do
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

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's interrupted targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)
		if player then
			win.title = format(L["%s's interrupted targets"], player.name)
			local total = player.interrupt or 0

			if total > 0 and player.interrupt_targets then
				local maxvalue, nr = 0, 1

				for targetname, count in pairs(player.interrupt_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname

					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Total,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's interrupt spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)
		if player then
			win.title = format(L["%s's interrupt spells"], player.name)
			local total = player.interrupt or 0

			if total > 0 and player.interrupt_spells then
				local maxvalue, nr = 0, 1

				for spellid, count in pairs(player.interrupt_spells) do
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

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Interrupts"]
		local total = set.interrupt or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.interrupt or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
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

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			click1 = spellmod,
			click2 = targetmod,
			click3 = playermod,
			nototalclick = {spellmod, targetmod, playermod},
			columns = {Total = true, Percent = true},
			icon = "Interface\\Icons\\ability_kick"
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
			name = L["Interrupts"],
			desc = format(L["Options for %s."], L["Interrupts"]),
			get = function(i)
				return Skada.db.profile.modules[i[#i]]
			end,
			set = function(i, val)
				Skada.db.profile.modules[i[#i]] = val
			end,
			args = {
				interruptannounce = {
					type = "toggle",
					name = L["Announce Interrupts"],
					order = 1,
					width = "double"
				},
				interruptchannel = {
					type = "select",
					name = L["Channel"],
					values = {AUTO = INSTANCE, SAY = CHAT_MSG_SAY, YELL = CHAT_MSG_YELL, SELF = L["Self"]},
					order = 2,
					width = "double"
				}
			}
		}
	end
end)