local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Comparison", function(L, P)
	local parent = Skada:GetModule("Damage", true)
	if not parent then return end

	local mode = parent:NewModule("Comparison")
	local mode_spell = mode:NewModule("Spell List")
	local mode_spell_details = mode_spell:NewModule("Spell Details")
	local mode_spell_breakdown = mode_spell:NewModule("More Details")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	local C = Skada.cacheTable2

	local pairs, max = pairs, math.max
	local format, uformat = string.format, Private.uformat
	local tooltip_school = Skada.tooltip_school
	local classfmt = Skada.classcolors.format
	local COLOR_GOLD = {r = 1, g = 0.82, b = 0, colorStr = "ffffd100"}
	local userid = Skada.userGUID
	local username = Skada.userName
	local userclass = Skada.userClass
	local mode_cols = nil

	-- damage miss types
	local missTypes = Skada.missTypes

	-- percentage colors
	local red = "\124cffffaaaa-%s\124r"
	local green = "\124cffaaffaa+%s\124r"
	local grey = "\124cff808080%s\124r"

	local function format_percent(value1, value2, cond)
		if cond == false then return end

		value1, value2 = value1 or 0, value2 or 0
		if value1 == value2 then
			return format(grey, Skada:FormatPercent(0))
		elseif value1 > value2 then
			return format(green, Skada:FormatPercent(value1 - value2, value2))
		else
			return format(red, Skada:FormatPercent(value2 - value1, value1))
		end
	end

	local function format_value_percent(val, oval, disabled)
		val, oval = val or 0, oval or 0
		return Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatPercent(val),
			(mode_cols.Comparison and not disabled) and Skada:FormatPercent(oval),
			format_percent(oval, val, mode_cols.Percent and not disabled)
		)
	end

	local function format_value_number(val, oval, fmt, disabled)
		val, oval = val or 0, oval or 0 -- sanity check
		return Skada:FormatValueCols(
			mode_cols.Damage and (fmt and Skada:FormatNumber(val) or val),
			(mode_cols.Comparison and not disabled) and (fmt and Skada:FormatNumber(oval) or oval),
			format_percent(oval, val, mode_cols.Percent and not disabled)
		)
	end

	local function can_compare(actor, otherclass)
		return (actor and not actor.enemy and actor.class == otherclass and actor.role == "DAMAGER")
	end

	local function mode_spell_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] or label == L["Glancing"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetActor(win.actorname, win.actorid)
			local spell = actor.damagespells and actor.damagespells[win.spellid]
			local otherid = win.otherid

			if actor.id == otherid then
				if spell then
					tooltip:AddLine(uformat("%s - %s", win.actorname, win.spellname))
					tooltip_school(tooltip, win.spellid)

					if label == L["Critical Hits"] and spell.c_amt then
						if spell.c_min then
							tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.c_min), 1, 1, 1)
						end
						if spell.c_max then
							tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.c_max), 1, 1, 1)
						end
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.c_amt / spell.c_num), 1, 1, 1)
					elseif label == L["Normal Hits"] and spell.n_amt then
						if spell.n_min then
							tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.n_min), 1, 1, 1)
						end
						if spell.n_max then
							tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.n_max), 1, 1, 1)
						end
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.n_amt / spell.n_num), 1, 1, 1)
					elseif label == L["Glancing"] and spell.g_amt then
						if spell.g_min then
							tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.g_min), 1, 1, 1)
						end
						if spell.g_max then
							tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.g_max), 1, 1, 1)
						end
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.g_amt / spell.g_num), 1, 1, 1)
					end
				end
				return
			end

			local othername = win.othername
			local oactor = set and set:GetActor(othername, otherid)
			local ospell = oactor and oactor.damagespells and oactor.damagespells[win.spellid]

			if spell or ospell then
				tooltip:AddLine(uformat(L["%s vs %s: %s"], win.actorname, othername, win.spellname))
				tooltip_school(tooltip, win.spellid)

				if label == L["Critical Hits"] and (spell and spell.c_amt or ospell.c_amt) then
					if (spell and spell.c_min) or (ospell and ospell.c_min) then
						tooltip:AddDoubleLine(L["Minimum"], format_value_number(spell and spell.c_min, ospell and ospell.c_min, true), 1, 1, 1)
					end

					if (spell and spell.c_max) or (ospell and ospell.c_max) then
						tooltip:AddDoubleLine(L["Maximum"], format_value_number(spell and spell.c_max, ospell and ospell.c_max, true), 1, 1, 1)
					end

					local num = (spell and spell.c_amt) and (spell.c_amt / spell.c_num)
					local onum = (ospell and ospell.c_amt) and (ospell.c_amt / ospell.c_num)
					tooltip:AddDoubleLine(L["Average"], format_value_number(num, onum, true), 1, 1, 1)
				elseif label == L["Normal Hits"] and ((spell and spell.n_amt) or (ospell and ospell.n_amt)) then
					if (spell and spell.n_min) or (ospell and ospell.n_min) then
						tooltip:AddDoubleLine(L["Minimum"], format_value_number(spell and spell.n_min, ospell and ospell.n_min, true), 1, 1, 1)
					end

					if (spell and spell.n_max) or (ospell and ospell.n_max) then
						tooltip:AddDoubleLine(L["Maximum"], format_value_number(spell and spell.n_max, ospell and ospell.n_max, true), 1, 1, 1)
					end

					local num = (spell and spell.n_amt) and (spell.n_amt / spell.n_num)
					local onum = (ospell and ospell.n_amt) and (ospell.n_amt / ospell.n_num)
					tooltip:AddDoubleLine(L["Average"], format_value_number(num, onum, true), 1, 1, 1)
				elseif label == L["Glancing"] and ((spell and spell.g_amt) or (ospell and ospell.g_amt)) then
					local num = (spell and spell.g_amt) and (spell.g_amt / spell.g_num)
					local onum = (ospell and ospell.g_amt) and (ospell.g_amt / ospell.g_num)

					if (spell and spell.g_min) or (ospell and ospell.g_min) then
						tooltip:AddDoubleLine(L["Minimum"], format_value_number(spell and spell.g_min, ospell and ospell.g_min, true), 1, 1, 1)
					end

					if (spell and spell.g_max) or (ospell and ospell.g_max) then
						tooltip:AddDoubleLine(L["Maximum"], format_value_number(spell and spell.g_max, ospell and ospell.g_max, true), 1, 1, 1)
					end

					tooltip:AddDoubleLine(L["Average"], format_value_number(num, onum, true), 1, 1, 1)
				end
			end
		end
	end

	local function activity_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		local otherid = actor and win.otherid
		if otherid then
			local totaltime = set:GetTime()
			local activetime = actor:GetTime(set, true)
			local oactivetime = set:GetActorTime(win.othername, otherid, true)

			tooltip:AddDoubleLine(L["Activity"], format_value_percent(100 * activetime / totaltime, 100 * oactivetime / totaltime, actor.id == otherid), nil, nil, nil, 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], format(actor.id ~= otherid and "%s (%s)" or "%s", Skada:FormatTime(activetime), Skada:FormatTime(oactivetime)), 1, 1, 1)
		end
	end

	-- local nr = add_detail_bar(win, 0, L["Hits"], spell.count, ospell.count)
	local function add_detail_bar(win, nr, title, value, ovalue, fmt, disabled)
		nr = nr + 1
		local d = win:nr(nr)

		d.id = title
		d.label = title
		d.value = value or 0

		d.valuetext = format_value_number(value, ovalue or 0, fmt, disabled)

		if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
			win.metadata.maxvalue = d.value
		end

		return nr
	end

	function mode_spell_details:Enter(win, id, label)
		win.spellid, win.spellname = id, label

		if win.actorname == win.othername then
			win.title = uformat("%s: %s", classfmt(win.actorclass, win.actorname), format(L["%s's details"], label))
		else
			win.title = uformat(L["%s vs %s: %s"], classfmt(win.actorclass, win.actorname), classfmt(win.otherclass, win.othername), uformat(L["%s's details"], win.spellname))
		end
	end

	function mode_spell_details:Tooltip(win, set, id, label, tooltip)
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagespells and actor.damagespells[id]
		local otherid = win.otherid

		if spell and actor.id == otherid then
			if spell.count then
				tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
			end

			return actor, spell
		end

		local oactor = set and set:GetActor(win.othername, win.otherid)
		local ospell = oactor and oactor.damagespells and oactor.damagespells[id]

		-- hits
		if (spell and spell.count) or (ospell and ospell.count) then
			tooltip:AddDoubleLine(L["Hits"], format_value_number(spell and spell.count, ospell and ospell.count, true), 1, 1, 1)
		end

		return actor, spell, oactor, ospell
	end

	function mode_spell_details:Update(win, set, actor, spell, oactor, ospell)
		if not actor or not spell then
			actor = set and set:GetActor(win.actorname, win.actorid)
			spell = actor and actor.damagespells and actor.damagespells[win.spellid]
		end

		-- same actor?
		local otherid = win.otherid
		if spell and actor and actor.id == otherid then
			win.title = format("%s: %s", classfmt(win.actorclass, win.actorname), format(L["%s's details"], win.spellname))

			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			if spell.n_num and spell.n_num > 0 then
				nr = add_detail_bar(win, nr, L["Normal Hits"], spell.n_num, nil, nil, true)
			end

			if spell.c_num and spell.c_num > 0 then
				nr = add_detail_bar(win, nr, L["Critical Hits"], spell.c_num, nil, nil, true)
			end

			if spell.g_num and spell.g_num > 0 then
				nr = add_detail_bar(win, nr, L["Glancing"], spell.g_num, nil, nil, true)
			end

			for k, v in pairs(missTypes) do
				if spell[v] or spell[k] then
					nr = add_detail_bar(win, nr, L[k], spell[v] or spell[k], nil, nil, true)
				end
			end

			return
		end

		win.title = uformat(L["%s vs %s: %s"], classfmt(win.actorclass, win.actorname), classfmt(win.otherclass, win.othername), uformat(L["%s's details"], win.spellname))

		if not oactor or not ospell then
			oactor = set and set:GetActor(win.othername, otherid)
			ospell = oactor and oactor.damagespells and oactor.damagespells[win.spellid]
		end

		if spell or ospell then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			if (spell and spell.n_num and spell.n_num > 0) or (ospell and ospell.n_num and ospell.n_num > 0) then
				nr = add_detail_bar(win, nr, L["Normal Hits"], spell and spell.n_num, ospell and ospell.n_num)
			end

			if (spell and spell.c_num and spell.c_num > 0) or (ospell and ospell.c_num and ospell.c_num > 0) then
				nr = add_detail_bar(win, nr, L["Critical Hits"], spell and spell.c_num, ospell and ospell.c_num)
			end

			if (spell and spell.g_num and spell.g_num > 0) or (ospell and ospell.g_num and ospell.g_num > 0) then
				nr = add_detail_bar(win, nr, L["Glancing"], spell and spell.g_num, ospell and ospell.g_num)
			end

			for k, v in pairs(missTypes) do
				if (spell and (spell[v] or spell[k])) or (ospell and (ospell[v] or ospell[k])) then
					nr = add_detail_bar(win, nr, L[k], spell and (spell[v] or spell[k]), ospell and (ospell[v] or ospell[k]))
				end
			end
		end
	end

	function mode_spell_breakdown:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s vs %s: %s"], classfmt(win.actorclass, win.actorname), classfmt(win.otherclass, win.othername), label)
	end

	function mode_spell_breakdown:Tooltip(win, set, id, label, tooltip)
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagespells and actor.damagespells[id]
		local otherid = win.otherid

		if spell and actor.id == otherid then
			local total = spell.total or spell.amount
			if spell.r_amt then
				total = total + spell.r_amt
			end
			if spell.b_amt then
				total = total + spell.b_amt
			end

			tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(total), 1, 1, 1)
			return actor, spell, total
		end

		local oactor = set and set:GetActor(win.othername, otherid)
		local ospell = oactor and oactor.damagespells and oactor.damagespells[id]
		if spell or ospell then
			local total = spell and (spell.total or spell.amount) or 0
			if spell and spell.r_amt then
				total = total + spell.r_amt
			end
			if spell and spell.b_amt then
				total = total + spell.b_amt
			end

			local ototal = ospell and (ospell.total or ospell.amount) or 0
			if ospell and ospell.r_amt then
				ototal = ototal + ospell.r_amt
			end
			if ospell and ospell.b_amt then
				ototal = ototal + ospell.b_amt
			end

			tooltip:AddDoubleLine(L["Total"], format_value_number(total, ototal, true), 1, 1, 1)
			return actor, spell, oactor, ospell
		end

	end

	function mode_spell_breakdown:Update(win, set, actor, spell, oactor, ospell)
		local othername, otherclass = win.othername, win.otherclass
		win.title = uformat(L["%s vs %s: %s"], classfmt(win.actorclass, win.actorname), classfmt(otherclass, othername), win.spellname)

		if not set or not win.spellid then return end

		if not actor or not spell then
			actor = set:GetActor(win.actorname, win.actorid)
			spell = actor and actor.damagespells and actor.damagespells[win.spellid]
		end

		local otherid = win.otherid
		if spell and actor and actor.id == otherid then
			win.title = uformat("%s: %s", classfmt(win.actorclass, win.actorname), win.spellname)

			local nr = add_detail_bar(win, 0, L["Damage"], spell.amount, nil, true, true)

			-- absorbed damage
			if spell.total and spell.total ~= spell.amount then
				nr = add_detail_bar(win, nr, L["ABSORB"], max(0, spell.total - spell.amount), nil, true, true)
			end

			-- resisted damage
			if spell.r_amt and spell.r_amt > 0 then
				nr = add_detail_bar(win, nr, L["RESIST"], spell.r_amt, nil, true, true)
			end

			-- blocked damage
			if spell.b_amt and spell.b_amt > 0 then
				nr = add_detail_bar(win, nr, L["BLOCK"], spell.b_amt, nil, true, true)
			end

			-- overkill damage
			if spell.o_amt and spell.o_amt > 0 then
				nr = add_detail_bar(win, nr, L["Overkill"], spell.o_amt, nil, true, true)
			end

			return
		end

		if not oactor or not ospell then
			oactor = set and set:GetActor(othername, otherid)
			ospell = oactor and oactor.damagespells and oactor.damagespells[win.spellid]
		end

		if spell or ospell then
			-- damage done
			local nr = add_detail_bar(win, 0, L["Damage"], spell and spell.amount, ospell and ospell.amount, true)

			-- resisted damage
			local r_amt1 = spell and spell.r_amt
			local r_amt2 = ospell and ospell.r_amt
			if (r_amt1 and r_amt1 > 0) or (r_amt2 and r_amt2 > 0) then
				nr = add_detail_bar(win, nr, L["RESIST"], r_amt1, r_amt2, true)
			end

			-- blocked damage
			local b_amt1 = spell and spell.b_amt
			local b_amt2 = ospell and ospell.b_amt
			if (b_amt1 and b_amt1 > 0) or (b_amt2 and b_amt2 > 0) then
				nr = add_detail_bar(win, nr, L["RESIST"], b_amt1, b_amt2, true)
			end

			-- overkill damage
			local o_amt1 = spell and spell.o_amt
			local o_amt2 = ospell and ospell.o_amt
			if (o_amt1 and o_amt1 > 0) or (o_amt2 and o_amt2 > 0) then
				nr = add_detail_bar(win, nr, L["Overkill"], o_amt1, o_amt2, true)
			end

			-- absorbed damage
			local a_amt1 = spell and spell.total and spell.total ~= spell.amount and max(0, spell.total - spell.amount)
			local a_amt2 = ospell and ospell.total and ospell.total ~= ospell.amount and max(0, ospell.total - ospell.amount)
			if (a_amt1 and a_amt1 > 0) or (a_amt2 and a_amt2 > 0) then
				nr = add_detail_bar(win, nr, L["ABSORB"], a_amt1, a_amt2, true)
			end

			-- glancing
			local g_amt1 = spell and spell.g_amt
			local g_amt2 = ospell and ospell.g_amt
			if (g_amt1 and g_amt1 > 0) or (g_amt2 and g_amt2 > 0) then
				nr = add_detail_bar(win, nr, L["Glancing"], g_amt1, g_amt2, true)
			end
		end
	end

	function mode_target_spell:Enter(win, id, label, class)
		win.targetid, win.targetname, win.targetclass = id, label, class
		win.title = uformat(L["%s vs %s: %s"], classfmt(win.actorclass, win.actorname), classfmt(win.otherclass, win.othername), format(L["Spells on %s"], classfmt(class, label)))
	end

	function mode_target_spell:Update(win, set)
		local othername, otherclass = win.othername, win.otherclass
		win.title = uformat(L["%s vs %s: %s"], classfmt(win.actorclass, win.actorname), classfmt(otherclass, othername), uformat(L["Spells on %s"], classfmt(win.targetclass, win.targetname)))

		if not set or not win.targetname then return end

		local targets, _, actor = set:GetActorDamageTargets(win.actorname, win.actorid)
		if not targets then return end

		local otherid = win.otherid
		if actor.id == otherid then
			win.title = uformat(L["%s's spells on %s"], classfmt(win.actorclass, win.actorname), classfmt(win.targetclass, win.targetname))

			local total = targets[win.targetname] and targets[win.targetname].amount
			if P.absdamage and targets[win.targetname].total then
				total = targets[win.targetname].total
			end

			local spells = (total and total > 0) and actor.damagespells
			if not spells then
				return
			elseif win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(spells) do
				local target = spell.targets and spell.targets[win.targetname]
				local amount = target and (P.absdamage and target.total or target.amount)
				if amount then
					nr = nr + 1

					local d = win:spell(nr, spellid)
					d.value = amount
					d.valuetext = Skada:FormatValueCols(mode_cols.Damage and Skada:FormatNumber(d.value))

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			return
		end

		local otargets, _, oactor = set:GetActorDamageTargets(othername, otherid, C)

		-- the compared actor
		local total = targets[win.targetname] and targets[win.targetname].amount
		if P.absdamage and targets[win.targetname].total then
			total = targets[win.targetname].total
		end

		-- existing targets.
		local spells = (total and total > 0) and actor.damagespells
		if spells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(spells) do
				if spell.targets and spell.targets[win.targetname] then
					nr = nr + 1
					local d = win:spell(nr, spellid)

					d.value = spell.targets[win.targetname].amount or 0
					local oamount = 0
					if
						oactor and
						oactor.damagespells and
						oactor.damagespells[spellid] and
						oactor.damagespells[spellid].targets and
						oactor.damagespells[spellid].targets[win.targetname]
					then
						oamount = oactor.damagespells[spellid].targets[win.targetname].amount or oamount
					end

					if P.absdamage then
						if spell.targets[win.targetname].total then
							d.value = spell.targets[win.targetname].total
						end
						if
							oactor and
							oactor.damagespells and
							oactor.damagespells[spellid] and
							oactor.damagespells[spellid].targets and
							oactor.damagespells[spellid].targets[win.targetname] and
							oactor.damagespells[spellid].targets[win.targetname].total
						then
							oamount = oactor.damagespells[spellid].targets[win.targetname].total
						end
					end

					d.valuetext = format_value_number(d.value, oamount, true)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			return
		end

		-- unexisting targets.
		if not otargets then return end
		total = otargets[win.targetname] and otargets[win.targetname].amount
		if P.absdamage and otargets[win.targetname].total then
			total = otargets[win.targetname].total
		end

		spells = (total and total > 0) and oactor.damagespells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellid, spell in pairs(spells) do
			local target = spell.targets and spell.targets[win.targetname]
			local amount = target and (P.absdamage and target.total or target.amount)
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellid)
				d.value = amount
				d.valuetext = format_value_number(0, amount, true)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		if label == win.othername then
			win.title = format(L["%s's spells"], classfmt(class, label))
		else
			win.title = uformat(L["%s vs %s: Spells"], classfmt(class, label), classfmt(win.otherclass, win.othername))
		end
	end

	function mode_spell:Update(win, set)
		local othername, otherclass = win.othername, win.otherclass
		win.title = uformat(L["%s vs %s: Spells"], classfmt(win.actorclass, win.actorname), classfmt(otherclass, othername))

		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local spells = actor and actor.damagespells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local otherid = win.otherid

		-- same actor?
		if actor.id == otherid then
			win.title = uformat(L["%s's spells"], classfmt(otherclass, othername))

			for spellid, spell in pairs(spells) do
				nr = nr + 1

				local d = win:spell(nr, spellid)
				d.value = P.absdamage and spell.total or spell.amount or 0
				d.valuetext = Skada:FormatValueCols(mode_cols.Damage and Skada:FormatNumber(d.value))

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end

			return
		end

		-- collect compared actor's spells.
		local oactor = set and set:GetActor(othername, otherid)
		local ospells = oactor and oactor.damagespells

		-- iterate comparison actor's spells.
		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = P.absdamage and spell.total or spell.amount

			local ospell = ospells and ospells[spellid]
			local oamount = ospell and (P.absdamage and ospell.total or ospell.amount)
			d.valuetext = format_value_number(d.value, oamount, true)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end

		-- any other left spells.
		if not ospells then return end
		for spellid, spell in pairs(ospells) do
			if not spells[spellid] then
				nr = nr + 1

				local d = win:spell(nr, spellid)
				d.value = P.absdamage and spell.total or spell.amount
				d.valuetext = format_value_number(0, d.value, true)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		if label == win.othername then
			win.title = format(L["%s's targets"], classfmt(class, label))
		else
			win.title = uformat(L["%s vs %s: Targets"], classfmt(class, label), classfmt(win.otherclass, win.othername))
		end
	end

	function mode_target:Update(win, set)
		local othername, otherclass = win.othername, win.otherclass
		win.title = uformat(L["%s vs %s: Targets"], classfmt(win.actorclass, win.actorname), classfmt(otherclass, othername))

		if not set or not win.actorname then return end

		local targets, _, actor = set:GetActorDamageTargets(win.actorname, win.actorid)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local otherid = win.otherid

		-- same actor?
		if actor.id == otherid then
			win.title = format(L["%s's targets"], classfmt(win.actorclass, win.actorname))

			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win:actor(nr, target, target.enemy, targetname)
				d.value = P.absdamage and target.total or target.amount
				d.valuetext = Skada:FormatValueCols(mode_cols.Damage and Skada:FormatNumber(d.value))

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end

			return
		end

		-- collect compared actor's targets.
		local otargets = set:GetActorDamageTargets(othername, otherid, C)

		-- iterate comparison actor's targets.
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, targetname)
			d.value = P.absdamage and target.total or target.amount

			local otarget = otargets and otargets[targetname]
			local oamount = otarget and (P.absdamage and otarget.total or otarget.amount)
			d.valuetext = format_value_number(d.value, oamount, true, actor.id == otherid)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end

		-- any other left targets.
		if not otargets then return end
		for targetname, target in pairs(otargets) do
			if not targets[targetname] then
				nr = nr + 1

				local d = win:actor(nr, target, target.enemy, targetname)
				d.value = P.absdamage and target.total or target.amount
				d.valuetext = format_value_number(0, d.value, true, actor.id == otherid)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mode:Update(win, set)
		local othername, otherclass = win.othername, win.otherclass
		win.title = format("%s: %s", L["Comparison"], classfmt(otherclass, othername))

		local total = set and set:GetDamage()
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local otherid, nr = win.otherid, 0
		local oamount = set:GetActorDamage(othername, otherid)

		for actorname, actor in pairs(set.actors) do
			if can_compare(actor, otherclass) then
				local dps, amount = actor:GetDPS(set, false, false, not mode_cols.DPS)
				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, actor, actor.enemy, actorname)

					d.value = amount
					d.valuetext = Skada:FormatValueCols(
						mode_cols.Damage and Skada:FormatNumber(d.value),
						mode_cols.DPS and Skada:FormatNumber(dps),
						format_percent(oamount, d.value, mode_cols.Percent and actor.id ~= otherid)
					)

					-- a valid window, not a tooltip
					if win.metadata then
						-- color the selected actor's bar.
						if actor.id == otherid then
							d.color = COLOR_GOLD
						elseif d.color then
							d.color = nil
						end

						-- order bars.
						if not win.metadata.maxvalue or d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end
		end
	end

	local function set_actor(win, id, label, class)
		if not win or not win.DisplayMode then return end

		userid = userid or Skada.userGUID
		username = username or Skada.userName
		userclass = userclass or Skada.userClass

		-- same actor or me? reset to the actor
		if id == userid or (id == win.otherid and win.selectedmode == mode) then
			win.otherid, win.othername, win.otherclass = userid, username, userclass
			win:DisplayMode(mode)
			return
		end

		win.otherid, win.othername, win.otherclass = id, label, class
		win:DisplayMode(mode)
	end

	function mode:OnEnable()
		mode_spell_details.metadata = {tooltip = mode_spell_tooltip}
		mode_target.metadata = {click1 = mode_target_spell}
		mode_spell.metadata = {click1 = mode_spell_details, click2 = mode_spell_breakdown}
		self.metadata = {
			showspots = true,
			tooltip = activity_tooltip,
			click1 = mode_spell,
			click2 = mode_target,
			click3 = set_actor,
			click3_label = L["Comparison"],
			columns = {Damage = true, DPS = true, Comparison = true, Percent = true},
			icon = [[Interface\ICONS\Ability_Warrior_OffensiveStance]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		self.nototal = true
		mode_spell.nototal = true
		mode_target.nototal = true

		self.category = parent.category or L["Damage Done"]
		Skada:AddColumnOptions(self)

		parent.metadata.click3 = set_actor
		parent.metadata.click3_label = L["Comparison"]
		parent:Reload()
	end
end, "Damage")
