local Skada = Skada
Skada:RegisterModule("Sunder Counter", function(L, P, _, C, new, del, clear)
	local mod = Skada:NewModule("Sunder Counter")
	local targetmod = mod:NewModule("Sunder target list")
	local sourcemod = mod:NewModule("Sunder source list")

	local pairs, tostring, format = pairs, tostring, string.format
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local GetSpellLink = Skada.GetSpellLink or GetSpellLink
	local T = Skada.Table
	local sunder, sunderLink, devastate, _

	local function log_sunder(set, data)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			set.sunder = (set.sunder or 0) + 1
			player.sunder = (player.sunder or 0) + 1

			if (set ~= Skada.total or P.totalidc) and data.dstName then
				player.sundertargets = player.sundertargets or {}
				player.sundertargets[data.dstName] = (player.sundertargets[data.dstName] or 0) + 1
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

			if P.modules.sunderannounce then
				if not P.modules.sunderbossonly or (P.modules.sunderbossonly and Skada:IsBoss(dstGUID, true)) then
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
							))
							mod.targets[dstGUID].full = true
						end
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
					if P.modules.sunderannounce then
						if not P.modules.sunderbossonly or (P.modules.sunderbossonly and Skada:IsBoss(dstGUID, true)) then
							mod:Announce(format(L["%s dropped from %s!"], sunderLink or sunder, dstName or L["Unknown"]))
						end
					end
				end
			end, 0.1)
		end
	end

	local function TargetDied(timestamp, eventtype, _, _, _, dstGUID)
		if P.modules.sunderannounce and dstGUID and mod.targets and mod.targets[dstGUID] then
			mod.targets[dstGUID] = del(mod.targets[dstGUID])
		end
	end

	local function DoubleCheckSunder()
		if not sunder then
			sunder, devastate = GetSpellInfo(47467), GetSpellInfo(47498)
			sunderLink = P.reportlinks and GetSpellLink(47467)
		end
	end

	function sourcemod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's <%s> sources"], label, sunder)
	end

	function sourcemod:Update(win, set)
		win.title = format(L["%s's <%s> sources"], win.targetname or L["Unknown"], sunder)
		if not win.targetname then return end

		local sources, total = set:GetSunderSources(win.targetname)
		if sources then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for sourcename, source in pairs(sources) do
				nr = nr + 1
				local d = win:actor(nr, source, nil, sourcename)

				d.value = source.count
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
		win.title = format(L["%s's <%s> targets"], label, sunder)
	end

	function targetmod:Update(win, set)
		DoubleCheckSunder()
		win.title = format(L["%s's <%s> targets"], win.actorname or L["Unknown"], sunder)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- unavailable for enemies yet

		local total = actor and actor.sunder or 0
		local targets = (total > 0) and actor:GetSunderTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:actor(nr, target, true, targetname)

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
		DoubleCheckSunder()

		win.title = L["Sunder Counter"]
		local total = set.sunder or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for i = 1, #set.players do
				local player = set.players[i]
				if player and player.sunder then
					nr = nr + 1
					local d = win:actor(nr, player)

					d.value = player.sunder
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
		sourcemod.metadata = {showspots = true}
		targetmod.metadata = {click1 = sourcemod}
		self.metadata = {
			showspots = true,
			click1 = targetmod,
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\ability_warrior_sunder]]
		}

		-- no total click.
		targetmod.nototal = true

		Skada:RegisterForCL(SunderApplied, "SPELL_CAST_SUCCESS", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(SunderRemoved, "SPELL_AURA_REMOVED", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(TargetDied, "UNIT_DIED", "UNIT_DESTROYED", "UNIT_DISSIPATES", {dst_is_not_interesting = true})

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if set.sunder and set.sunder > 0 then
			tooltip:AddDoubleLine(sunder, set.sunder, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		local sunders = set.sunder or 0
		return tostring(sunders), sunders
	end

	function mod:CombatLeave()
		T.clear(data)
		T.free("Sunder_Targets", self.targets, nil, del)
	end

	function mod:Announce(msg)
		Skada:SendChat(msg, P.modules.sunderchannel or "SAY", "preset")
	end

	function mod:OnInitialize()
		DoubleCheckSunder()

		if P.modules.sunderchannel == nil then
			P.modules.sunderchannel = "SAY"
		end

		Skada.options.args.modules.args.sundercounter = {
			type = "group",
			name = self.localeName,
			desc = format(L["Options for %s."], self.localeName),
			args = {
				header = {
					type = "description",
					name = self.localeName,
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
					desc = format(L["Announces how long it took to apply %d stacks of %s and announces when it drops."], 5, sunder or L["Unknown"]),
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
		local setPrototype = Skada.setPrototype
		function setPrototype:GetSunderSources(name, tbl)
			local total = 0
			if self.sunder and name then
				tbl = clear(tbl or C)
				for i = 1, #self.players do
					local p = self.players[i]
					if p and p.sundertargets and p.sundertargets[name] then
						tbl[p.name] = new()
						tbl[p.name].id = p.id
						tbl[p.name].class = p.class
						tbl[p.name].role = p.role
						tbl[p.name].spec = p.spec
						tbl[p.name].count = p.sundertargets[name]
						total = total + p.sundertargets[name]
					end
				end
			end
			return tbl, total
		end

		local playerPrototype = Skada.playerPrototype
		function playerPrototype:GetSunderTargets(tbl)
			if self.sundertargets then
				tbl = clear(tbl or C)
				for name, count in pairs(self.sundertargets) do
					tbl[name] = new()
					tbl[name].count = count
					local actor = self.super:GetActor(name)
					if actor then
						tbl[name].id = actor.id
						tbl[name].class = actor.class
						tbl[name].role = actor.role
						tbl[name].spec = actor.spec
					end
				end
				return tbl
			end
		end
	end
end)