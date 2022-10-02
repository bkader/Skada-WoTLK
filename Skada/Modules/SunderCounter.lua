local _, Skada = ...
local private = Skada.private
Skada:RegisterModule("Sunder Counter", function(L, P, _, C, M)
	local mod = Skada:NewModule("Sunder Counter")
	local targetmod = mod:NewModule("Sunder target list")
	local sourcemod = mod:NewModule("Sunder source list")
	local get_sunder_sources = nil
	local get_sunder_targets = nil

	local pairs, format, GetTime, uformat = pairs, string.format, GetTime, private.uformat
	local new, del, clear = private.newTable, private.delTable, private.clearTable
	local GetSpellInfo = private.spell_info or GetSpellInfo
	local GetSpellLink = private.spell_link or GetSpellLink
	local T = Skada.Table

	local sunder_targets -- holds sunder targets details for announcement
	local active_sunders = {} -- holds sunder targets to consider refreshes
	local spell_sunder, spell_devastate, sunder_link
	local last_srcGUID, last_srcName, last_srcFlags
	local mod_cols = nil

	local function format_valuetext(d, columns, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Count and Skada:FormatNumber(d.value),
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local data = {}
	local function log_sunder(set)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if not player then return end

		set.sunder = (set.sunder or 0) + 1
		player.sunder = (player.sunder or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not data.dstName then return end

		player.sundertargets = player.sundertargets or {}
		player.sundertargets[data.dstName] = (player.sundertargets[data.dstName] or 0) + 1
	end

	local function sunder_dropped(dstGUID)
		if dstGUID and sunder_targets and sunder_targets[dstGUID] then
			local dstName = sunder_targets[dstGUID].name
			sunder_targets[dstGUID] = del(sunder_targets[dstGUID])

			if not M.sunderannounce then
				return
			elseif not M.sunderbossonly or (M.sunderbossonly and Skada:IsBoss(dstGUID, true)) then
				mod:Announce(uformat(L["%s dropped from %s!"], sunder_link or spell_sunder, dstName))
			end
		end
	end

	local function sunder_applied(_, eventtype, _, _, _, dstGUID, dstName, dstFlags, _, spellname)
		if spellname ~= spell_sunder and spellname ~= spell_devastate then return end

		-- sunder removed!
		if eventtype == "SPELL_AURA_REMOVED" then
			Skada:ScheduleTimer(sunder_dropped, 0.1, dstGUID)
			return
		end

		-- sunder refreshed
		if eventtype == "SPELL_AURA_REFRESH" and active_sunders[dstGUID] and active_sunders[dstGUID] > GetTime() then
			active_sunders[dstGUID] = GetTime() + M.sunderdelay -- useless refresh
			return
		else
			active_sunders[dstGUID] = GetTime() + M.sunderdelay
		end

		data.playerid = last_srcGUID
		data.playername = last_srcName
		data.playerflags = last_srcFlags
		data.dstName = dstName

		Skada:DispatchSets(log_sunder)

		-- announce disabled or only for bosses
		if not M.sunderannounce or (M.sunderbossonly and not Skada:IsBoss(dstGUID, true)) then return end

		local t = sunder_targets and sunder_targets[dstGUID]
		if not t then
			t = new()
			t.name = dstName
			t.count = 1
			t.time = GetTime()
			sunder_targets = sunder_targets or T.get("Sunder_Targets")
			sunder_targets[dstGUID] = t
		elseif not t.full then
			t.count = (t.count or 0) + 1
			if t.count == 5 then
				mod:Announce(format(
					L["%s stacks of %s applied on %s in %s sec!"],
					t.count,
					sunder_link or spell_sunder,
					dstName,
					format("%.1f", GetTime() - t.time)
				))
				t.full = true
			end
		end
	end

	local function sunder_cast(_, _, srcGUID, srcName, srcFlags, _, _, _, _, spellname)
		if spellname == spell_sunder or spellname == spell_devastate then
			last_srcGUID = srcGUID
			last_srcName = srcName
			last_srcFlags = srcFlags
		end
	end

	local function unit_died(_, _, _, _, _, dstGUID)
		if M.sunderannounce and dstGUID and sunder_targets and sunder_targets[dstGUID] then
			sunder_targets[dstGUID] = del(sunder_targets[dstGUID])
		end
	end

	local function double_check_sunder()
		if not spell_sunder then
			spell_sunder = GetSpellInfo(47467)
		end
		if not spell_devastate then
			spell_devastate = GetSpellInfo(47498)
		end
		if not sunder_link then
			sunder_link = GetSpellLink(47467)
		end
	end

	function sourcemod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's <%s> sources"], label, spell_sunder)
	end

	function sourcemod:Update(win, set)
		win.title = uformat(L["%s's <%s> sources"], win.targetname, spell_sunder)
		if not win.targetname then return end

		local sources, total = get_sunder_sources(set, win.targetname)
		if not sources or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for sourcename, source in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, source, nil, sourcename)
			d.value = source.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's <%s> targets"], label, spell_sunder)
	end

	function targetmod:Update(win, set)
		double_check_sunder()
		win.title = uformat(L["%s's <%s> targets"], win.actorname, spell_sunder)
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
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, targetname)
			d.value = target.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
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

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor.sunder then
				nr = nr + 1

				local d = win:actor(nr, actor)
				d.value = actor.sunder
				format_valuetext(d, mod_cols, total, win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set)
		return set and set.sunder or 0
	end

	function mod:AddToTooltip(set, tooltip)
		if set.sunder and set.sunder > 0 then
			tooltip:AddDoubleLine(spell_sunder, set.sunder, 1, 1, 1)
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

		mod_cols = self.metadata.columns

		-- no total click.
		targetmod.nototal = true

		local flags_src = {src_is_interesting_nopets = true}
		Skada:RegisterForCL(
			sunder_applied,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_APPLIED_DOSE",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_REMOVED",
			flags_src
		)

		Skada:RegisterForCL(
			sunder_cast,
			"SPELL_CAST_SUCCESS",
			flags_src
		)

		Skada:RegisterForCL(
			unit_died,
			"UNIT_DIED",
			"UNIT_DESTROYED",
			"UNIT_DISSIPATES",
			{dst_is_not_interesting = true}
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:CombatLeave()
		T.clear(data)
		T.free("Sunder_Targets", sunder_targets, nil, del)
		last_srcGUID, last_srcName, last_srcFlags = nil, nil, nil
	end

	function mod:Announce(msg)
		Skada:SendChat(msg, M.sunderchannel or "SAY", "preset")
	end

	function mod:OnInitialize()
		double_check_sunder()

		M.sunderchannel = M.sunderchannel or "SAY"
		M.sunderdelay = M.sunderdelay or 20

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
				empty_1 = {
					type = "description",
					name = " ",
					width = "full",
					order = 1
				},
				sunderannounce = {
					type = "toggle",
					name = format(L["Announce %s"], spell_sunder),
					desc = uformat(L["Announces how long it took to apply %d stacks of %s and announces when it drops."], 5, spell_sunder),
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
				},
				empty_2 = {
					type = "description",
					name = " ",
					width = "full",
					order = 31
				},
				sunderdelay = {
					type = "range",
					name = L["Refresh"],
					desc = L["Number of seconds after application to count refreshs."],
					min = 0,
					max = 30,
					step = 1,
					order = 40,
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
