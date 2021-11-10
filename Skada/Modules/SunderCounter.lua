local Skada = Skada
Skada:AddLoadableModule("Sunder Counter", function(L)
	if Skada:IsDisabled("Sunder Counter") then return end

	local mod = Skada:NewModule(L["Sunder Counter"])
	local targetmod = mod:NewModule(L["Sunder target list"])

	local pairs, ipairs, select = pairs, ipairs, select
	local tostring, format = tostring, string.format
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local GetSpellLink = Skada.GetSpellLink or GetSpellLink
	local newTable, delTable, After = Skada.newTable, Skada.delTable, Skada.After
	local IsInGroup, IsInRaid = Skada.IsInGroup, Skada.IsInRaid
	local sunder, sunderLink, devastate
	local _

	local function log_sunder(set, data)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			set.sunder = (set.sunder or 0) + 1
			player.sunder = (player.sunder or 0) + 1

			if set == Skada.current and data.dstName then
				local actor = Skada:GetActor(set, data.dstGUID, data.dstName, data.dstFlags)
				if actor then
					player.sundertargets = player.sundertargets or {}
					player.sundertargets[data.dstName] = (player.sundertargets[data.dstName] or 0) + 1
				end
			end
		end
	end

	local data = {}

	local function SunderApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellname = select(2, ...)
		if spellname == sunder or spellname == devastate then
			data.playerid = srcGUID
			data.playername = srcName
			data.playerflags = srcFlags

			data.dstGUID = dstGUID
			data.dstName = dstName
			data.dstFlags = dstFlags

			log_sunder(Skada.current, data)
			log_sunder(Skada.total, data)

			if Skada.db.profile.modules.sunderannounce then
				mod.targets = mod.targets or newTable()
				if not mod.targets[dstGUID] then
					mod.targets[dstGUID] = {count = 1, time = timestamp}
				elseif mod.targets[dstGUID] ~= -1 then
					mod.targets[dstGUID].count = (mod.targets[dstGUID].count or 0) + 1
					if mod.targets[dstGUID].count == 5 then
						mod:Announce(format(
							L["%s stacks of %s applied on %s in %s sec!"],
							mod.targets[dstGUID].count,
							sunderLink or sunder,
							dstName,
							format("%.1f", timestamp - mod.targets[dstGUID].time)
						), dstGUID)
						mod.targets[dstGUID] = -1
					end
				end
			end
		end
	end

	local function SunderRemoved(timestamp, eventtype, _, _, _, dstGUID, dstName, _, _, spellname)
		if Skada.db.profile.modules.sunderannounce and spellname and spellname == sunder then
			After(0.1, function()
				if mod.targets and mod.targets[dstGUID] then
					mod:Announce(format(L["%s dropped from %s!"], sunderLink or sunder, dstName or L.Unknown), dstGUID)
					mod.targets[dstGUID] = nil
				end
			end)
		end
	end

	local function TargetDied(timestamp, eventtype, _, _, _, dstGUID)
		if Skada.db.profile.modules.sunderannounce and dstGUID and mod.targets and mod.targets[dstGUID] then
			mod.targets[dstGUID] = nil
		end
	end

	local function DoubleCheckSunder()
		if not sunder then
			sunder, devastate = GetSpellInfo(47467), GetSpellInfo(47498)
			sunderLink = GetSpellLink(47467)
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's <%s> targets"], label, sunder)
	end

	function targetmod:Update(win, set)
		DoubleCheckSunder()
		win.title = format(L["%s's <%s> targets"], win.playername or L.Unknown, sunder)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.sunder or 0
		local targets = (total > 0) and player:GetSunderTargets()

		if targets then
			local maxvalue, nr = 0, 1

			for targetname, target in pairs(targets) do
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
					mod.metadata.columns.Count,
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

	function mod:Update(win, set)
		DoubleCheckSunder()

		win.title = L["Sunder Counter"]
		local total = set.sunder or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.sunder or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.spec = player.spec
					d.role = player.role

					d.value = player.sunder
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Count,
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
			click1 = targetmod,
			nototalclick = {targetmod},
			columns = {Count = true, Percent = true},
			icon = [[Interface\Icons\ability_warrior_sunder]]
		}

		Skada:RegisterForCL(SunderApplied, "SPELL_CAST_SUCCESS", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(SunderRemoved, "SPELL_AURA_REMOVED", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(TargetDied, "UNIT_DIED", {dst_is_not_interesting = true})

		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if set and (set.sunder or 0) > 0 then
			tooltip:AddDoubleLine(sunder, set.sunder or 0, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return tostring(set.sunder or 0), set.sunder or 0
	end

	function mod:AddSetAttributes(set)
		self.targets = newTable()
	end

	function mod:SetComplete(set)
		self.targets = delTable(self.targets)
	end

	function mod:Announce(msg, guid)
		-- only in a group
		if not IsInGroup() or not msg then return end

		-- only on bosses!
		if Skada.db.profile.modules.sunderbossonly and guid and not Skada:IsBoss(guid) then return end

		local channel = Skada.db.profile.modules.sunderchannel or "SAY"
		if channel == "SELF" then
			Skada:Print(msg)
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

		Skada:SendChat(msg, channel, "preset", true)
	end

	function mod:OnInitialize()
		DoubleCheckSunder()

		if Skada.db.profile.modules.sunderchannel == nil then
			Skada.db.profile.modules.sunderchannel = "SAY"
		end

		Skada.options.args.modules.args.sundercounter = {
			type = "group",
			name = self.moduleName,
			desc = format(L["Options for %s."], self.moduleName),
			args = {
				header = {
					type = "description",
					name = self.moduleName,
					fontSize = "large",
					image = [[Interface\Icons\ability_warrior_sunder]],
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
				sunderannounce = {
					type = "toggle",
					name = format(L["Announce %s"], sunder),
					desc = format(L["Announces how long it took to apply %d stacks of %s and announces when it drops."], 5, sunder or L.Unknown),
					descStyle = "inline",
					order = 10,
					width = "double"
				},
				sunderchannel = {
					type = "select",
					name = L["Channel"],
					values = {AUTO = INSTANCE, SAY = CHAT_MSG_SAY, YELL = CHAT_MSG_YELL, SELF = L["Self"]},
					order = 20,
					width = "double"
				},
				sunderbossonly = {
					type = "toggle",
					name = L["Only for bosses."],
					desc = L["Enable this only against bosses."],
					order = 30,
					width = "double"
				}
			}
		}
	end

	do
		local playerPrototype = Skada.playerPrototype
		local cacheTable = Skada.cacheTable
		local wipe = wipe

		function playerPrototype:GetSunderTargets()
			if self.sundertargets then
				wipe(cacheTable)
				for name, count in pairs(self.sundertargets) do
					cacheTable[name] = {count = count}
					local actor = self.super:GetActor(name)
					if actor then
						cacheTable[name].id = actor.id
						cacheTable[name].class = actor.class
						cacheTable[name].role = actor.role
						cacheTable[name].spec = actor.spec
					end
				end
				return cacheTable
			end
		end
	end
end)