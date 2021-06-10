assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Interrupts", function(Skada, L)
	if Skada:IsDisabled("Interrupts") then return end

	local mod = Skada:NewModule(L["Interrupts"])
	local spellmod = mod:NewModule(L["Interrupted spells"])
	local targetmod = mod:NewModule(L["Interrupted targets"])
	local playermod = mod:NewModule(L["Interrupt spells"])
	local playerid, _

	-- cache frequently used globals
	local pairs, select, format, max = pairs, select, string.format, math.max
	local UnitGUID, UnitClass = UnitGUID, Skada.UnitClass
	local IsInInstance, SendChatMessage = IsInInstance, SendChatMessage
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local GetSpellLink = Skada.GetSpellLink or GetSpellLink

	local function log_interrupt(set, data)
		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
		if player then
			-- increment player's and set's interrupts count
			player.interrupts = player.interrupts or {}
			player.interrupts.count = (player.interrupts.count or 0) + 1
			set.interrupts = (set.interrupts or 0) + 1

			-- to save up memory, we only record the rest to the current set.
			if set ~= Skada.current then return end

			-- add the interrupted spell
			if data.spellid then
				player.interrupts.spells = player.interrupts.spells or {}
				if not player.interrupts.spells[data.spellid] then
					player.interrupts.spells[data.spellid] = {
						id = data.spellid,
						school = data.spellschool,
						count = 1
					}
				else
					player.interrupts.spells[data.spellid].count = player.interrupts.spells[data.spellid].count + 1
				end
			end

			-- add the interrupt spell
			if data.extraspellid then
				player.interrupts.extraspells = player.interrupts.extraspells or {}
				if not player.interrupts.extraspells[data.extraspellid] then
					player.interrupts.extraspells[data.extraspellid] = {
						id = data.extraspellid,
						school = data.extraspellschool,
						count = 1
					}
				else
					player.interrupts.extraspells[data.extraspellid].count = player.interrupts.extraspells[data.extraspellid].count + 1
				end
			end

			-- add the interrupted target
			if data.dstName then
				player.interrupts.targets = player.interrupts.targets or {}
				if not player.interrupts.targets[data.dstName] then
					local class, role, spec = select(2, UnitClass(data.dstGUID, data.dstFlags, set, true))
					player.interrupts.targets[data.dstName] = {class = class, role = role, spec = spec, count = 1}
				else
					player.interrupts.targets[data.dstName].count = player.interrupts.targets[data.dstName].count + 1
				end
			end
		end
	end

	local data = {}

	local function SpellInterrupt(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, extraspellid, extraspellname, extraschool = ...

		data.playerid = srcGUID
		data.playername = srcName
		data.playerflags = srcFlags

		data.dstGUID = dstGUID
		data.dstName = dstName
		data.dstFlags = dstFlags

		data.spellid = spellid or 6603
		data.spellname = spellname or L["Auto Attack"]
		data.spellschool = spellschool

		data.extraspellid = extraspellid
		data.extraspellname = extraspellname
		data.extraspellschool = extraschool

		Skada:FixPets(data)

		log_interrupt(Skada.current, data)
		log_interrupt(Skada.total, data)

		if Skada.db.profile.modules.interruptannounce and Skada:IsInGroup() and srcGUID == playerid then
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
					channel = Skada:IsInRaid() and "RAID" or "PARTY"
				end
			end

			SendChatMessage(format(L["%s interrupted!"], spelllink or dstName), channel)
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
			local total = player.interrupts and player.interrupts.count or 0

			if total > 0 and player.interrupts.extraspells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.interrupts.extraspells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)
					d.spellschool = spell.school

					d.value = spell.count
					d.valuetext = Skada:FormatValueText(
						spell.count,
						mod.metadata.columns.Total,
						format("%.1f%%", 100 * spell.count / total),
						mod.metadata.columns.Percent
					)

					if spell.count > maxvalue then
						maxvalue = spell.count
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
			local total = player.interrupts and player.interrupts.count or 0

			if total > 0 and player.interrupts.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in pairs(player.interrupts.targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname
					d.class = target.class
					d.role = target.role
					d.spec = target.spec

					d.value = target.count
					d.valuetext = Skada:FormatValueText(
						target.count,
						mod.metadata.columns.Total,
						format("%.1f%%", 100 * target.count / total),
						mod.metadata.columns.Percent
					)

					if target.count > maxvalue then
						maxvalue = target.count
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
			local total = player.interrupts and player.interrupts.count or 0

			if total > 0 and player.interrupts.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in pairs(player.interrupts.spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)
					d.spellschool = spell.school

					d.value = spell.count
					d.valuetext = Skada:FormatValueText(
						spell.count,
						mod.metadata.columns.Total,
						format("%.1f%%", 100 * spell.count / total),
						mod.metadata.columns.Percent
					)

					if spell.count > maxvalue then
						maxvalue = spell.count
					end
					nr = nr + 1
				end
				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Interrupts"]
		local total = set.interrupts or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.interrupts and (player.interrupts.count or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = Skada:FormatName(player.name, player.id)
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = player.interrupts.count
					d.valuetext = Skada:FormatValueText(
						player.interrupts.count,
						self.metadata.columns.Total,
						format("%.1f%%", 100 * player.interrupts.count / total),
						self.metadata.columns.Percent
					)

					if player.interrupts.count > maxvalue then
						maxvalue = player.interrupts.count
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		playerid = playerid or UnitGUID("player")
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
		if set and (set.interrupts or 0) > 0 then
			tooltip:AddDoubleLine(L["Interrupts"], set.interrupts, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return set.interrupts or 0
	end

	local opts = {
		type = "group",
		name = L["Interrupts"],
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

	function mod:OnInitialize()
		playerid = playerid or UnitGUID("player")
		if not Skada.db.profile.modules.interruptchannel then
			Skada.db.profile.modules.interruptchannel = "SAY"
		end
		Skada.options.args.modules.args.interrupts = opts
	end
end)