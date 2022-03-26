local LibFail = LibStub("LibFail-1.0", true)
if not LibFail then return end

local Skada = Skada
Skada:AddLoadableModule("Fails", function(L)
	if Skada:IsDisabled("Fails") then return end

	local mod = Skada:NewModule(L["Fails"])
	local playermod = mod:NewModule(L["Player's failed events"])
	local spellmod = mod:NewModule(L["Event's failed players"])
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua

	local pairs, ipairs, tostring, format, tContains = pairs, ipairs, tostring, string.format, tContains
	local GetSpellInfo, UnitGUID, IsInGroup = Skada.GetSpellInfo or GetSpellInfo, UnitGUID, Skada.IsInGroup
	local _

	local function log_fail(set, playerid, playername, spellid, event)
		local player = Skada:FindPlayer(set, playerid, playername)
		if player and (player.role ~= "TANK" or not tContains(LibFail:GetFailsWhereTanksDoNotFail(), event)) then
			player.fail = (player.fail or 0) + 1
			set.fail = (set.fail or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set ~= Skada.total then
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
					log_fail(Skada.total, unitGUID, who, spellid, event)
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's fails"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's fails"], win.spellname or L.Unknown)
		if not win.spellid then return end

		local total = set and set:GetFailCount(win.spellid) or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if player.failspells and player.failspells[win.spellid] then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

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
		win.title = format(L["%s's fails"], win.actorname or L.Unknown)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local total = player and player.fail or 0

		if total > 0 and player.failspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, count in pairs(player.failspells) do
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

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Fails"], L[win.class]) or L["Fails"]

		local total = set.fail or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.fail or 0) > 0 then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

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
			nototalclick = {playermod},
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\ability_creature_cursed_01]]
		}

		Skada:AddMode(self)

		-- table of ignored spells:
		if Skada.ignoredSpells and Skada.ignoredSpells.fails then
			ignoredSpells = Skada.ignoredSpells.fails
		end
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return tostring(set.fail or 0), set.fail or 0
	end

	function mod:AddToTooltip(set, tooltip)
		if set and (set.fail or 0) > 0 then
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
					name = mod.moduleName,
					desc = format(L["Options for %s."], mod.moduleName),
					args = {
						header = {
							type = "description",
							name = mod.moduleName,
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
			for _, event in ipairs(LibFail:GetSupportedEvents()) do
				LibFail:RegisterCallback(event, onFail)
			end

			if Skada.db.profile.modules.failschannel == nil then
				Skada.db.profile.modules.failschannel = "AUTO"
			end
			if Skada.db.profile.modules.ignoredfails then
				Skada.db.profile.modules.ignoredfails = nil
			end

			Skada.options.args.modules.args.failbot = GetOptions()
		end
	end

	function mod:SetComplete(set)
		if (set.fail or 0) > 0 and Skada.db.profile.modules.failsannounce then
			local channel = Skada.db.profile.modules.failschannel or "AUTO"
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
				for _, p in ipairs(self.players) do
					if p.failspells and p.failspells[spellid] then
						count = count + p.failspells[spellid]
					end
				end
				return count
			end
		end
	end
end)