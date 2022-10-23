local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Interrupts", function(L, P, _, C, M)
	local mod = Skada:NewModule("Interrupts")
	local extraspellmod = mod:NewModule("Interrupted spells")
	local targetmod = mod:NewModule("Interrupted targets")
	local spellmod = mod:NewModule("Interrupt spells")
	local ignored_spells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local get_actor_interrupted_spells = nil
	local get_actor_interrupt_targets = nil

	-- cache frequently used globals
	local pairs, format, uformat = pairs, string.format, Private.uformat
	local new, clear = Private.newTable, Private.clearTable
	local GetSpellLink = Private.spell_link or GetSpellLink
	local mod_cols = nil

	local function format_valuetext(d, columns, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Count and d.value,
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local data = {}
	local function log_interrupt(set)
		local actor = Skada:GetPlayer(set, data.actorid, data.actorname, data.actorflags)
		if not actor then return end

		-- increment player's and set's interrupts count
		actor.interrupt = (actor.interrupt or 0) + 1
		set.interrupt = (set.interrupt or 0) + 1

		-- to save up memory, we only record the rest to the current set.
		if (set == Skada.total and not P.totalidc) or not data.spellid then return end

		local spell = actor.interruptspells and actor.interruptspells[data.spellid]
		if not spell then
			actor.interruptspells = actor.interruptspells or {}
			actor.interruptspells[data.spellid] = {count = 1}
			spell = actor.interruptspells[data.spellid]
		else
			spell.count = spell.count + 1
		end

		-- record interrupted spell
		if data.extraspellid then
			spell.spells = spell.spells or {}
			spell.spells[data.extraspellid] = (spell.spells[data.extraspellid] or 0) + 1
		end

		-- record the target
		if data.dstName then
			spell.targets = spell.targets or {}
			spell.targets[data.dstName] = (spell.targets[data.dstName] or 0) + 1
		end
	end

	local function spell_interrupt(t)
		local spellid = t.spellid or 6603
		local spellname = t.spellname or L["Melee"]

		-- invalid/ignored spell?
		if ignored_spells[spellid] or (t.extraspellid and ignored_spells[t.extraspellid]) then return end

		data.actorid, data.actorname, data.actorflags = Skada:FixMyPets(t.srcGUID, t.srcName, t.srcFlags)
		data.dstName = Skada:FixPetsName(t.dstGUID, t.dstName, t.dstFlags)

		data.spellid = t.spellstring
		data.extraspellid = t.extrastring

		Skada:DispatchSets(log_interrupt)

		if not M.interruptannounce or t.srcGUID ~= Skada.userGUID then return end

		local spelllink = t.extraspellname or data.dstName
		if P.reportlinks then
			spelllink = GetSpellLink(t.extraspellid or t.extraspellname) or spelllink
		end
		Skada:SendChat(format(L["%s interrupted!"], spelllink), M.interruptchannel or "SAY", "preset")
	end

	function extraspellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's interrupted spells"], label)
	end

	function extraspellmod:Update(win, set)
		win.title = uformat(L["%s's interrupted spells"], win.actorname)
		if not set or not win.actorname then return end

		local spells, total, actor = get_actor_interrupted_spells(set, win.actorid, win.actorname)
		if not spells or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, count in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's interrupted targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's interrupted targets"], win.actorname)
		if not set or not win.actorname then return end

		local targets, total, actor = get_actor_interrupt_targets(set, win.actorid, win.actorname)
		if not targets or not actor or total == 0 then
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

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's interrupt spells"], label)
	end

	function spellmod:Update(win, set)
		win.title = uformat(L["%s's interrupt spells"], win.actorname)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = (actor and not enemy) and actor.interrupt
		local spells = (total and total > 0) and actor.interruptspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = spell.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Interrupts"], L[win.class]) or L["Interrupts"]

		local total = set and set:GetTotal(win.class, nil, "interrupt")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for i = 1, #actors do
			local actor = actors[i]
			if win:show_actor(actor, set, true) and actor.interrupt then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy)
				d.value = actor.interrupt
				format_valuetext(d, mod_cols, total, win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set, win)
		if not set then return end
		return set:GetTotal(win and win.class, nil, "interrupt") or 0
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = extraspellmod,
			click2 = targetmod,
			click3 = spellmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Count = true, Percent = true, sPercent = true},
			icon = [[Interface\Icons\ability_kick]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		extraspellmod.nototal = true
		targetmod.nototal = true
		spellmod.nototal = true

		Skada:RegisterForCL(spell_interrupt, {src_is_interesting = true}, "SPELL_INTERRUPT")
		Skada:AddMode(self)

		-- table of ignored spells:
		if Skada.ignored_spells and Skada.ignored_spells.interrupts then
			ignored_spells = Skada.ignored_spells.interrupts
		end
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if set.interrupt and set.interrupt > 0 then
			tooltip:AddDoubleLine(L["Interrupts"], set.interrupt, 1, 1, 1)
		end
	end

	function mod:OnInitialize()
		M.interruptchannel = M.interruptchannel or  "SAY"

		Skada.options.args.modules.args.interrupts = {
			type = "group",
			name = self.localeName,
			desc = format(L["Options for %s."], self.localeName),
			args = {
				header = {
					type = "description",
					name = self.localeName,
					fontSize = "large",
					image = [[Interface\Icons\ability_kick]],
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
				interruptannounce = {
					type = "toggle",
					name = format(L["Announce %s"], self.localeName),
					order = 10,
					width = "double"
				},
				interruptchannel = {
					type = "select",
					name = L["Channel"],
					values = {AUTO = INSTANCE, SAY = CHAT_MSG_SAY, YELL = CHAT_MSG_YELL, SELF = L["Self"]},
					order = 20,
					width = "double"
				}
			}
		}
	end

	---------------------------------------------------------------------------

	get_actor_interrupted_spells = function(self, id, name, tbl)
		local actor = self:GetActor(name, id)
		local total = actor and actor.interrupt
		local spells = total and actor.interruptspells
		if not spells then return end

		tbl = clear(tbl or C)
		for _, spell in pairs(spells) do
			if spell.spells then
				for spellid, count in pairs(spell.spells) do
					tbl[spellid] = (tbl[spellid] or 0) + count
				end
			end
		end
		return tbl, total, actor
	end

	get_actor_interrupt_targets = function(self, id, name, tbl)
		local actor = self:GetActor(name, id)
		local total = actor and actor.interrupt
		local spells = total and actor.interruptspells
		if not spells then return end

		tbl = clear(tbl or C)
		for _, spell in pairs(spells) do
			if spell.targets then
				for targetname, count in pairs(spell.targets) do
					local t = tbl[targetname]
					if not t then
						t = new()
						t.count = count
						tbl[targetname] = t
					else
						t.count = t.count + count
					end
					self:_fill_actor_table(t, targetname)
				end
			end
		end
		return tbl, total, actor
	end
end)
