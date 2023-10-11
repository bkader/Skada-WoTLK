local LibFail = LibStub("LibFail-1.0", true)
if not LibFail then return end

local folder, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Fails", function(L, P, _, _, M, O)
	local mode = Skada:NewModule("Fails")
	local mode_spell = mode:NewModule("Spell List")
	local mode_spell_target = mode_spell:NewModule("Target List")
	local ignored_spells = Skada.ignored_spells.fail -- Edit Skada\Core\Tables.lua
	local count_fails_by_spell = nil

	local pairs, tostring, format, UnitGUID = pairs, tostring, string.format, UnitGUID
	local uformat, IsInGroup = Private.uformat, Skada.IsInGroup
	local classfmt = Skada.classcolors.format
	local tank_events, mode_cols

	local function format_valuetext(d, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Count and d.value,
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local actorflags = Private.DEFAULT_FLAGS
	local function log_fail(set, actorname, actorid, spellid, failname)
		local actor = Skada:GetActor(set, actorname, actorid, actorflags)
		if not actor or (actor.role == "TANK" and tank_events[failname]) then return end

		actor.fail = (actor.fail or 0) + 1
		set.fail = (set.fail or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not spellid then return end
		actor.failspells = actor.failspells or {}
		actor.failspells[spellid] = (actor.failspells[spellid] or 0) + 1
	end

	local function on_fail(failname, actorname, failtype, ...)
		local spellid = failname and actorname and LibFail:GetEventSpellId(failname)
		local actorid = spellid and not ignored_spells[spellid] and UnitGUID(actorname)
		if not actorid then return end

		Skada:DispatchSets(log_fail, actorname, actorid, tostring(spellid), failname)
	end

	function mode_spell_target:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's fails"], label)
	end

	function mode_spell_target:Update(win, set)
		win.title = uformat(L["%s's fails"], win.spellname)
		if not win.spellid then return end

		local total = set and count_fails_by_spell(set, win.spellid)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if actor.failspells and actor.failspells[win.spellid] then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.failspells[win.spellid]
				format_valuetext(d, total, win.metadata, true)
			end
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's fails"], classfmt(class, label))
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["%s's fails"], classfmt(win.actorclass, win.actorname))

		local actor = set and set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.fail
		local spells = (total and total > 0) and actor.failspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, count in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = count
			format_valuetext(d, total, win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Fails"], L[win.class]) or L["Fails"]

		local total = set and set:GetTotal(win.class, nil, "fail")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.fail then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.fail
				format_valuetext(d, total, win.metadata)
			end
		end
	end

	function mode_spell:GetSetSummary(set, win)
		local actor = set and win and set:GetActor(win.actorname, win.actorid)
		return actor and actor.fail
	end

	function mode:GetSetSummary(set, win)
		if not set then return end
		return set:GetTotal(win and win.class, nil, "fail")
	end

	function mode:AddToTooltip(set, tooltip)
		if set.fail and set.fail > 0 then
			tooltip:AddDoubleLine(L["Fails"], set.fail, 1, 1, 1)
		end
	end

	function mode:OnEnable()
		mode_spell.metadata = {click1 = mode_spell_target}
		self.metadata = {
			showspots = true,
			ordersort = true,
			filterclass = true,
			click1 = mode_spell,
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\ICONS\ability_creature_cursed_01]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self)
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	--------------------------------------------------------------------------

	do
		local options  -- holds the options table
		local function get_options()
			if not options then
				options = {
					type = "group",
					name = mode.localeName,
					desc = format(L["Options for %s."], mode.localeName),
					args = {
						header = {
							type = "description",
							name = mode.localeName,
							fontSize = "large",
							image = [[Interface\ICONS\ability_creature_cursed_01]],
							imageWidth = 18,
							imageHeight = 18,
							imageCoords = Skada.cropTable,
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
							values = {AUTO = L["Instance"], GUILD = L["Guild"], OFFICER = L["Officer"], SELF = L["Self"]},
							order = 20,
							width = "double"
						}
					}
				}
			end
			return options
		end

		function mode:OnInitialize()
			local events = LibFail:GetSupportedEvents()
			for i = 1, #events do
				LibFail.RegisterCallback(folder, events[i], on_fail)
			end

			events = LibFail:GetFailsWhereTanksDoNotFail()
			tank_events = tank_events or {}
			for i = 1, #events do
				tank_events[events[i]] = true
			end

			M.ignoredfails = nil
			M.failschannel = M.failschannel or "AUTO"
			O.modules.args.failbot = get_options()
		end
	end

	function mode:CombatLeave(_, set)
		if set and set.fail and set.fail > 0 and M.failsannounce then
			local channel = M.failschannel or "AUTO"
			if channel == "SELF" or channel == "GUILD" or IsInGroup() then
				Skada:Report(channel, "preset", L["Fails"], nil, 10)
			end
		end
	end

	---------------------------------------------------------------------------

	count_fails_by_spell = function(self, spellid)
		local total = 0
		if not self.fail or not spellid then
			return total
		end

		local actors = self.actors
		for _, a in pairs(actors) do
			if a.failspells and a.failspells[spellid] then
				total = total + a.failspells[spellid]
			end
		end
		return total
	end
end)
