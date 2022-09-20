local Skada = Skada
Skada:RegisterModule("Sunder Counter", function(L, P, _, C, new, del, clear)
	local mod = Skada:NewModule("Sunder Counter")
	local targetmod = mod:NewModule("Sunder target list")
	local sourcemod = mod:NewModule("Sunder source list")
	local get_sunder_sources = nil
	local get_sunder_targets = nil

	local pairs, format, pformat = pairs, string.format, Skada.pformat
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local GetSpellLink = Skada.GetSpellLink or GetSpellLink
	local T = Skada.Table
	local sunder, sunderLink, devastate, _

	local function format_valuetext(d, columns, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Count and Skada:FormatNumber(d.value),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_sunder(set, data)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if not player then return end

		set.sunder = (set.sunder or 0) + 1
		player.sunder = (player.sunder or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not data.dstName then return end

		player.sundertargets = player.sundertargets or {}
		player.sundertargets[data.dstName] = (player.sundertargets[data.dstName] or 0) + 1
	end

	local data = {}

	local function sunder_applied(timestamp, _, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, _, spellname)
		if spellname == sunder or spellname == devastate then
			data.playerid = srcGUID
			data.playername = srcName
			data.playerflags = srcFlags

			data.dstGUID = dstGUID
			data.dstName = dstName
			data.dstFlags = dstFlags

			Skada:DispatchSets(log_sunder, data)

			if not P.modules.sunderannounce then return end -- announce disabled
			if P.modules.sunderbossonly and not Skada:IsBoss(dstGUID, true) then return end -- only for bosses

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

	local function sunder_removed(timestamp, _, _, _, _, dstGUID, dstName, _, _, spellname)
		if not spellname or spellname ~= sunder then return end

		Skada:ScheduleTimer(function()
			if mod.targets and mod.targets[dstGUID] then
				mod.targets[dstGUID] = del(mod.targets[dstGUID])
				if P.modules.sunderannounce then
					if not P.modules.sunderbossonly or (P.modules.sunderbossonly and Skada:IsBoss(dstGUID, true)) then
						mod:Announce(pformat(L["%s dropped from %s!"], sunderLink or sunder, dstName))
					end
				end
			end
		end, 0.1)
	end

	local function unit_died(timestamp, _, _, _, _, dstGUID)
		if P.modules.sunderannounce and dstGUID and mod.targets and mod.targets[dstGUID] then
			mod.targets[dstGUID] = del(mod.targets[dstGUID])
		end
	end

	local function double_check_sunder()
		if sunder then return end
		sunder, devastate = GetSpellInfo(47467), GetSpellInfo(47498)
		sunderLink = P.reportlinks and GetSpellLink(47467)
	end

	function sourcemod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's <%s> sources"], label, sunder)
	end

	function sourcemod:Update(win, set)
		win.title = pformat(L["%s's <%s> sources"], win.targetname, sunder)
		if not win.targetname then return end

		local sources, total = get_sunder_sources(set, win.targetname)
		if not sources or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local cols = mod.metadata.columns

		for sourcename, source in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, source, nil, sourcename)
			d.value = source.count
			format_valuetext(d, cols, total, win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's <%s> targets"], label, sunder)
	end

	function targetmod:Update(win, set)
		double_check_sunder()
		win.title = pformat(L["%s's <%s> targets"], win.actorname, sunder)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = (actor and not enemy) and actor.sunder
		local targets = (total and total > 0) and get_sunder_targets(actor)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local cols = mod.metadata.columns

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, targetname)
			d.value = target.count
			format_valuetext(d, cols, total, win.metadata, true)
		end
	end

	function mod:Update(win, set)
		double_check_sunder()
		win.title = L["Sunder Counter"]

		local total = set.sunder
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local cols = self.metadata.columns

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor.sunder then
				nr = nr + 1

				local d = win:actor(nr, actor)
				d.value = actor.sunder
				format_valuetext(d, cols, total, win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set)
		return set and set.sunder or 0
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

		Skada:RegisterForCL(sunder_applied, "SPELL_AURA_APPLIED", "SPELL_AURA_APPLIED_DOSE", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(sunder_removed, "SPELL_AURA_REMOVED", {src_is_interesting_nopets = true})
		Skada:RegisterForCL(unit_died, "UNIT_DIED", "UNIT_DESTROYED", "UNIT_DISSIPATES", {dst_is_not_interesting = true})

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

	function mod:CombatLeave()
		T.clear(data)
		T.free("Sunder_Targets", self.targets, nil, del)
	end

	function mod:Announce(msg)
		Skada:SendChat(msg, P.modules.sunderchannel or "SAY", "preset")
	end

	function mod:OnInitialize()
		double_check_sunder()

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
					desc = pformat(L["Announces how long it took to apply %d stacks of %s and announces when it drops."], 5, sunder),
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

	---------------------------------------------------------------------------

	get_sunder_sources = function(self, name, tbl)
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

	get_sunder_targets = function(self, tbl)
		if self.sundertargets then
			tbl = clear(tbl or C)
			for name, count in pairs(self.sundertargets) do
				tbl[name] = new()
				tbl[name].count = count
				self.super:_fill_actor_table(tbl[name], name)
			end
			return tbl
		end
	end
end)
