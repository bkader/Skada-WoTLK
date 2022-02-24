local Skada = Skada
Skada:AddLoadableModule("Sunder Counter", function(L)
	if Skada:IsDisabled("Sunder Counter") then return end

	local mod = Skada:NewModule(L["Sunder Counter"])
	local targetmod = mod:NewModule(L["Sunder target list"])

	local pairs, ipairs, select = pairs, ipairs, select
	local tostring, format = tostring, string.format
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local GetSpellLink = Skada.GetSpellLink or GetSpellLink
	local IsInGroup, IsInRaid = Skada.IsInGroup, Skada.IsInRaid
	local T = Skada.Table
	local new, del = Skada.TablePool()
	local sunder, sunderLink, devastate, _

	local function log_sunder(set, data)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			set.sunder = (set.sunder or 0) + 1
			player.sunder = (player.sunder or 0) + 1

			if set ~= Skada.total and data.dstName then
				local actor = Skada:GetActor(set, data.dstGUID, data.dstName, data.dstFlags)
				if actor then
					player.sundertargets = player.sundertargets or {}
					player.sundertargets[data.dstName] = (player.sundertargets[data.dstName] or 0) + 1
				end
			end
		end
	end

	local data = {}

	local function SunderApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, _, spellname)
		if spellname == sunder or spellname == devastate then
			data.playerid = srcGUID
			data.playername = srcName
			data.playerflags = srcFlags

			data.dstGUID = dstGUID
			data.dstName = dstName
			data.dstFlags = dstFlags

			Skada:DispatchSets(log_sunder, data)
			log_sunder(Skada.total, data)

			if Skada.db.profile.modules.sunderannounce then
				mod.targets = mod.targets or T.get("Sunder_Targets")
				if not mod.targets[dstGUID] then
					mod.targets[dstGUID] = new()
					mod.targets[dstGUID].count = 1
					mod.targets[dstGUID].time = timestamp
				elseif not mod.targets[dstGUID].full then
					mod.targets[dstGUID].count = (mod.targets[dstGUID].count or 0) + 1
					if mod.targets[dstGUID].count == 5 then
						mod:Announce(format(
							L["%s stacks of %s applied on %s in %s sec!"],
							mod.targets[dstGUID].count,
							sunderLink or sunder,
							dstName,
							format("%.1f", timestamp - mod.targets[dstGUID].time)
						), dstGUID)
						mod.targets[dstGUID].full = true
					end
				end
			end
		end
	end

	local function SunderRemoved(timestamp, eventtype, _, _, _, dstGUID, dstName, _, _, spellname)
		if spellname == sunder then
			Skada:ScheduleTimer(function()
				if mod.targets and mod.targets[dstGUID] then
					mod.targets[dstGUID] = del(mod.targets[dstGUID])
					if Skada.db.profile.modules.sunderannounce then
						mod:Announce(format(L["%s dropped from %s!"], sunderLink or sunder, dstName or L.Unknown), dstGUID)
					end
				end
			end, 0.1)
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
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's <%s> targets"], label, sunder)
	end

	function targetmod:Update(win, set)
		DoubleCheckSunder()
		win.title = format(L["%s's <%s> targets"], win.actorname or L.Unknown, sunder)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unavailable for enemies yet

		local total = actor and actor.sunder or 0
		local targets = (total > 0) and actor:GetSunderTargets()

		if targets then
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
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		DoubleCheckSunder()

		win.title = L["Sunder Counter"]
		local total = set.sunder or 0

		if total > 0 then
			local nr = 0
			for _, player in ipairs(set.players) do
				if (player.sunder or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.spec = player.spec
					d.role = player.role

					d.value = player.sunder
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Count and d.value,
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			click1 = targetmod,
			nototalclick = {targetmod},
			columns = {Count = true, Percent = false},
			icon = [[Interface\Icons\ability_warrior_sunder]]
		}

		Skada:RegisterForCL(SunderApplied, "SPELL_CAST_SUCCESS", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(SunderRemoved, "SPELL_AURA_REMOVED", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(TargetDied, "UNIT_DIED", "UNIT_DESTROYED", "UNIT_DISSIPATES", {dst_is_not_interesting = true})

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

	function mod:SetComplete(set)
		T.clear(data)

		-- delete to reuse
		if self.targets then
			for k, _ in pairs(self.targets) do
				self.targets[k] = del(self.targets[k])
			end
			T.free("Sunder_Targets", self.targets)
		end
	end

	function mod:Announce(msg, guid)
		-- only in a group
		if not IsInGroup() or not msg then return end

		-- -- only on bosses!
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
		local wipe = wipe

		function playerPrototype:GetSunderTargets(tbl)
			if self.sundertargets then
				tbl = wipe(tbl or Skada.cacheTable)
				for name, count in pairs(self.sundertargets) do
					tbl[name] = {count = count}
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
				return tbl
			end
		end
	end
end)