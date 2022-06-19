local LibFail = LibStub("LibFail-1.0", true)
if not LibFail then return end

local Skada = Skada
Skada:RegisterModule("Fails", function(L, P)
	if Skada:IsDisabled("Fails") then return end

	local mod = Skada:NewModule("Fails")
	local playermod = mod:NewModule("Player's failed events")
	local spellmod = mod:NewModule("Event's failed players")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	local pairs, tostring, format, tContains = pairs, tostring, string.format, tContains
	local GetSpellInfo, UnitGUID, IsInGroup = Skada.GetSpellInfo or GetSpellInfo, UnitGUID, Skada.IsInGroup
	local _

	local function log_fail(set, playerid, playername, spellid, event)
		local player = Skada:FindPlayer(set, playerid, playername)
		if player and (player.role ~= "TANK" or not tContains(LibFail:GetFailsWhereTanksDoNotFail(), event)) then
			player.fail = (player.fail or 0) + 1
			set.fail = (set.fail or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set ~= Skada.total or P.totalidc then
				player.failspells = player.failspells or {}
				player.failspells[spellid] = (player.failspells[spellid] or 0) + 1
			end
		end
	end

	local function onFail(event, who, failtype)
		if who and event then
			local spellid = LibFail:GetEventSpellId(event)
			if spellid and not ignoredSpells[spellid] then
				local unitGUID = UnitGUID(who)
				if unitGUID then
					Skada:DispatchSets(log_fail, unitGUID, who, spellid, event)
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's fails"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's fails"], win.spellname or L["Unknown"])
		if not win.spellid then return end

		local total = set and set:GetFailCount(win.spellid) or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for i = 1, #set.players do
				local player = set.players[i]
				if player and player.failspells and player.failspells[win.spellid] then
					nr = nr + 1
					local d = win:actor(nr, player)

					d.value = player.failspells[win.spellid]
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
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's fails"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's fails"], win.actorname or L["Unknown"])

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.fail or 0

		if total > 0 and player.failspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, count in pairs(player.failspells) do
				nr = nr + 1
				local d = win:spell(nr, spellid)

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

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Fails"], L[win.class]) or L["Fails"]

		local total = set.fail or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for i = 1, #set.players do
				local player = set.players[i]
				if player and player.fail and (not win.class or win.class == player.class) then
					nr = nr + 1
					local d = win:actor(nr, player)

					d.value = player.fail
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
		playermod.metadata = {click1 = spellmod}
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\ability_creature_cursed_01]]
		}

		-- no total click.
		playermod.nototal = true

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self)

		-- table of ignored spells:
		if Skada.ignoredSpells and Skada.ignoredSpells.fails then
			ignoredSpells = Skada.ignoredSpells.fails
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local fails = set.fail or 0
		return tostring(fails), fails
	end

	function mod:AddToTooltip(set, tooltip)
		if set.fail and set.fail > 0 then
			tooltip:AddDoubleLine(L["Fails"], set.fail, 1, 1, 1)
		end
	end

	--------------------------------------------------------------------------

	do
		local options  -- holds the options table
		local function GetOptions()
			if not options then
				options = {
					type = "group",
					name = mod.localeName,
					desc = format(L["Options for %s."], mod.localeName),
					args = {
						header = {
							type = "description",
							name = mod.localeName,
							fontSize = "large",
							image = [[Interface\Icons\ability_creature_cursed_01]],
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
						failsannounce = {
							type = "toggle",
							name = L["Report Fails"],
							desc = L["Reports the group fails at the end of combat if there are any."],
							descStyle = "inline",
							order = 10,
							width = "double"
						},
						failschannel = {
							type = "select",
							name = L["Channel"],
							values = {AUTO = INSTANCE, GUILD = GUILD, OFFICER = CHAT_MSG_OFFICER, SELF = L["Self"]},
							order = 20,
							width = "double"
						}
					}
				}
			end
			return options
		end

		function mod:OnInitialize()
			local events = LibFail:GetSupportedEvents()
			for i = 1, #events do
				LibFail:RegisterCallback(events[i], onFail)
			end

			if P.modules.failschannel == nil then
				P.modules.failschannel = "AUTO"
			end
			if P.modules.ignoredfails then
				P.modules.ignoredfails = nil
			end

			Skada.options.args.modules.args.failbot = GetOptions()
		end
	end

	function mod:CombatLeave(_, set)
		if set and set.fail and set.fail > 0 and P.modules.failsannounce then
			local channel = P.modules.failschannel or "AUTO"
			if channel == "SELF" or channel == "GUILD" or IsInGroup() then
				Skada:Report(channel, "preset", L["Fails"], nil, 10)
			end
		end
	end

	do
		local setPrototype = Skada.setPrototype
		function setPrototype:GetFailCount(spellid)
			if spellid and self.fail then
				local count = 0
				for i = 1, #self.players do
					local p = self.players[i]
					if p and p.failspells and p.failspells[spellid] then
						count = count + p.failspells[spellid]
					end
				end
				return count
			end
		end
	end
end)