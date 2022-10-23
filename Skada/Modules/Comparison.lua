local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Comparison", function(L, P)
	local parent = Skada:GetModule("Damage", true)
	if not parent then return end

	local mod = parent:NewModule("Comparison")
	local spellmod = mod:NewModule("Damage spell list")
	local dspellmod = spellmod:NewModule("Damage spell details")
	local bspellmod = spellmod:NewModule("Damage Breakdown")
	local targetmod = mod:NewModule("Damage target list")
	local dtargetmod = targetmod:NewModule("Damage spell list")
	local C = Skada.cacheTable2

	local pairs, max = pairs, math.max
	local format, uformat = string.format, Private.uformat
	local tooltip_school = Skada.tooltip_school
	local COLOR_GOLD = {r = 1, g = 0.82, b = 0, colorStr = "ffffd100"}
	local userGUID, otherGUID = Skada.userGUID, nil
	local userName, otherName = Skada.userName, nil
	local userClass, otherClass = Skada.userClass, nil
	local mod_cols = nil

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
			mod.metadata.columns.Damage and Skada:FormatPercent(val),
			(mod.metadata.columns.Comparison and not disabled) and Skada:FormatPercent(oval),
			(mod.metadata.columns.Percent and not disabled) and format_percent(oval, val)
		)
	end

	local function format_value_number(val, oval, fmt, disabled)
		val, oval = val or 0, oval or 0 -- sanity check
		return Skada:FormatValueCols(
			mod.metadata.columns.Damage and (fmt and Skada:FormatNumber(val) or val),
			(mod.metadata.columns.Comparison and not disabled) and (fmt and Skada:FormatNumber(oval) or oval),
			format_percent(oval, val, mod.metadata.columns.Percent and not disabled)
		)
	end

	local function can_compare(actor)
		return (actor and not actor.enemy and actor.class == otherClass and actor.role == "DAMAGER")
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] or label == L["Glancing"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetActor(win.actorname, win.actorid)
			local spell = actor.damagespells and actor.damagespells[win.spellid]

			if actor.id == otherGUID then
				if spell then
					tooltip:AddLine(actor.name .. " - " .. win.spellname)
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

			local ospells = set:GetActorDamageSpells(otherGUID, otherName)
			local ospell = ospells and ospells[win.spellid]

			if spell or ospell then
				tooltip:AddLine(uformat(L["%s vs %s: %s"], actor and actor.name, otherName, win.spellname))
				tooltip_school(tooltip, win.spellid)

				if label == L["Critical Hits"] and (spell and spell.c_amt or ospell.c_amt) then
					local num = spell and spell.c_num and (100 * spell.c_num / spell.count)
					local onum = ospell and ospell.c_num and (100 * ospell.c_num / ospell.count)

					tooltip:AddDoubleLine(L["Critical"], format_value_percent(onum, num, actor.id == otherGUID), 1, 1, 1)

					num = (spell and spell.c_amt) and (spell.c_amt / spell.c_num)
					onum = (ospell and ospell.c_amt) and (ospell.c_amt / ospell.c_num)

					if (spell and spell.c_min) or (ospell and ospell.c_min) then
						tooltip:AddDoubleLine(L["Minimum"], format_value_number(spell and spell.c_min, ospell and ospell.c_min, true), 1, 1, 1)
					end

					if (spell and spell.c_max) or (ospell and ospell.c_max) then
						tooltip:AddDoubleLine(L["Maximum"], format_value_number(spell and spell.c_max, ospell and ospell.c_max, true), 1, 1, 1)
					end

					tooltip:AddDoubleLine(L["Average"], format_value_number(num, onum, true), 1, 1, 1)
				elseif label == L["Normal Hits"] and ((spell and spell.n_amt) or (ospell and ospell.n_amt)) then
					local num = (spell and spell.n_amt) and (spell.n_amt / spell.n_num)
					local onum = (ospell and ospell.n_amt) and (ospell.n_amt / ospell.n_num)

					if (spell and spell.n_min) or (ospell and ospell.n_min) then
						tooltip:AddDoubleLine(L["Minimum"], format_value_number(spell and spell.n_min, ospell and ospell.n_min, true), 1, 1, 1)
					end

					if (spell and spell.n_max) or (ospell and ospell.n_max) then
						tooltip:AddDoubleLine(L["Maximum"], format_value_number(spell and spell.n_max, ospell and ospell.n_max, true), 1, 1, 1)
					end

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
		if actor then
			local totaltime = set:GetTime()
			local activetime = actor:GetTime(set, true)
			local oactivetime = set:GetActorTime(otherGUID, otherName, true)

			tooltip:AddDoubleLine(L["Activity"], format_value_percent(100 * activetime / totaltime, 100 * oactivetime / totaltime, actor.id == otherGUID), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], format(actor.id ~= otherGUID and "%s (%s)" or "%s", Skada:FormatTime(activetime), Skada:FormatTime(oactivetime)), 1, 1, 1)
		end
	end

	-- local nr = add_detail_bar(win, 0, L["Hits"], spell.count, ospell.count)
	local function add_detail_bar(win, nr, title, value, ovalue, fmt, disabled)
		nr = nr + 1
		local d = win:nr(nr)

		d.id = title
		d.label = title

		if value then
			d.value = value
			ovalue = ovalue or 0
		elseif ovalue then
			d.value = ovalue
			value = value or 0
		else
			d.value = value or 0
			ovalue = ovalue or 0
		end

		d.valuetext = format_value_number(value, ovalue, fmt, disabled)

		if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
			win.metadata.maxvalue = d.value
		end

		return nr
	end

	function dspellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s vs %s: %s"], win.actorname, otherName, uformat(L["%s's damage breakdown"], label))
	end

	function dspellmod:Update(win, set)
		win.title = uformat(L["%s vs %s: %s"], win.actorname, otherName, uformat(L["%s's damage breakdown"], win.spellname))
		if not set or not win.spellid then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local spell = actor and actor.damagespells and actor.damagespells[win.spellid]

		-- same actor?
		if actor.id == otherGUID then
			win.title = format("%s: %s", actor.name, format(L["%s's damage breakdown"], win.spellname))

			if spell then
				if win.metadata then
					win.metadata.maxvalue = spell.count
				end

				local nr = add_detail_bar(win, 0, L["Hits"], spell.count, nil, nil, true)
				win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

				if spell.casts and spell.casts > 0 then
					nr = add_detail_bar(win, nr, L["Casts"], spell.casts, nil, nil, true)
					win.dataset[nr].value = win.dataset[nr].value * 1e3 -- to be always first
				end

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
			end

			return
		end

		local ospells = set:GetActorDamageSpells(otherGUID, otherName)
		local ospell = ospells and ospells[win.spellid]

		if spell or ospell then
			if win.metadata then
				win.metadata.maxvalue = spell and spell.count or ospell.count
			end

			local nr = add_detail_bar(win, 0, L["Hits"], spell and spell.count, ospell and ospell.count)
			win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

			if (spell and spell.casts and spell.casts > 0) or (ospell and ospell.casts and ospell.casts > 0) then
				nr = add_detail_bar(win, nr, L["Casts"], spell and spell.casts, ospell and ospell.casts)
				win.dataset[nr].value = win.dataset[nr].value * 1e3 -- to be always first
			end

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

	function bspellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s vs %s: %s"], win.actorname, otherName, L["actor damage"](label))
	end

	function bspellmod:Update(win, set)
		win.title = uformat(L["%s vs %s: %s"], win.actorname, otherName, L["actor damage"](win.spellname or L["Unknown"]))
		if not set or not win.spellid then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local spell = actor and actor.damagespells and actor.damagespells[win.spellid]

		if actor.id == otherGUID then
			win.title = uformat(L["%s's <%s> damage"], actor.name, win.spellname)

			if spell then
				local total = spell.amount

				local absorbed = spell.total and max(0, spell.total - spell.amount)
				if absorbed then
					total = spell.total
				end

				local blocked = spell.b_amt or spell.blocked
				if blocked then
					total = total + blocked
				end

				local resisted = spell.r_amt or spell.resisted
				if resisted then
					total = total + resisted
				end

				-- total damage
				local nr = add_detail_bar(win, 0, L["Total"], total, nil, true, true)
				win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

				-- real damage
				if total ~= spell.amount then
					nr = add_detail_bar(win, nr, L["Damage"], spell.amount, nil, true, true)
				end

				-- absorbed damage
				if absorbed and absorbed > 0 then
					nr = add_detail_bar(win, nr, L["ABSORB"], absorbed, nil, true, true)
				end

				-- overkill damage
				if spell.o_amt and spell.o_amt > 0 then
					nr = add_detail_bar(win, nr, L["Overkill"], spell.o_amt, nil, true, true)
				end

				-- blocked damage
				if blocked and blocked > 0 then
					nr = add_detail_bar(win, nr, L["BLOCK"], blocked, nil, true, true)
				end

				-- resisted damage
				if resisted and resisted > 0 then
					nr = add_detail_bar(win, nr, L["RESIST"], resisted, nil, true, true)
				end
			end

			return
		end

		local ospells = set:GetActorDamageSpells(otherGUID, otherName)
		local ospell = ospells and ospells[win.spellid]

		if spell or ospell then
			local total = spell and spell.amount
			local ototal = ospell and ospell.amount

			local absorbed = (spell and spell.total) and max(0, spell.total - spell.amount)
			if absorbed then
				total = spell.total
			end

			local oabsorbed = (ospell and ospell.total) and max(0, ospell.total - ospell.amount)
			if oabsorbed then
				ototal = ospell.total
			end

			local blocked = spell and (spell.b_amt or spell.blocked)
			if blocked then
				total = total + blocked
			end

			local oblocked = ospell and (ospell.b_amt or ospell.blocked)
			if oblocked then
				ototal = ototal + oblocked
			end

			local resisted = spell and (spell.r_amt or spell.resisted)
			if resisted then
				total = total + resisted
			end

			local oresisted = ospell and (ospell.r_amt or ospell.resisted)
			if oresisted then
				ototal = ototal + oresisted
			end

			-- total damage
			local nr = add_detail_bar(win, 0, L["Total"], total, ototal, true)
			win.dataset[nr].value = (spell and total or ototal) + 1 -- to be always first

			-- real damage
			if (spell and total ~= spell.amount) or (ospell and ototal ~= ospell.amount) then
				nr = add_detail_bar(win, nr, L["Damage"], spell and spell.amount, ospell and ospell.amount, true)
			end

			-- absorbed damage
			if (absorbed and absorbed > 0) or (oabsorbed and oabsorbed > 0) then
				nr = add_detail_bar(win, nr, L["ABSORB"], absorbed, oabsorbed, true)
			end

			-- overkill damage
			local overkill = spell and spell.o_amt
			local ooverkill = ospell and ospell.o_amt
			if (overkill and overkill > 0) or (ooverkill and ooverkill > 0) then
				nr = add_detail_bar(win, nr, L["Overkill"], overkill, ooverkill, true)
			end

			-- blocked damage
			if (blocked and blocked > 0) or (oblocked and oblocked > 0) then
				nr = add_detail_bar(win, nr, L["BLOCK"], blocked, oblocked, true)
			end

			-- resisted damage
			if (resisted and resisted > 0) or (oresisted and oresisted > 0) then
				nr = add_detail_bar(win, nr, L["RESIST"], resisted, oresisted, true)
			end
		end
	end

	function dtargetmod:Enter(win, id, label)
		win.targetname = label
		win.title = uformat(L["%s vs %s: Damage on %s"], win.actorname, otherName, label)
	end

	function dtargetmod:Update(win, set)
		win.title = uformat(L["%s vs %s: Damage on %s"], win.actorname, otherName, win.targetname)
		if not set or not win.targetname then return end

		local targets, _, actor = set:GetActorDamageTargets(win.actorid, win.actorname)
		if not targets then return end

		if actor.id == otherGUID then
			win.title = L["actor damage"](actor.name, win.targetname)

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
					d.valuetext = Skada:FormatValueCols(mod_cols.Damage and Skada:FormatNumber(d.value))

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			return
		end

		local otargets, _, oactor = set:GetActorDamageTargets(otherGUID, otherName, C)

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

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = uformat(L["%s vs %s: Spells"], label, otherName)
	end

	function spellmod:Update(win, set)
		win.title = uformat(L["%s vs %s: Spells"], win.actorname, otherName)
		if not set or not win.actorname then return end

		local spells, actor = set:GetActorDamageSpells(win.actorid, win.actorname)
		if not actor or not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		-- same actor?
		if actor.id == otherGUID then
			win.title = L["actor damage"](actor.name)

			for spellid, spell in pairs(spells) do
				nr = nr + 1

				local d = win:spell(nr, spellid)
				d.value = P.absdamage and spell.total or spell.amount or 0
				d.valuetext = Skada:FormatValueCols(mod_cols.Damage and Skada:FormatNumber(d.value))

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end

			return
		end

		-- collect compared actor's spells.
		local ospells = set:GetActorDamageSpells(otherGUID, otherName)

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

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = uformat(L["%s vs %s: Targets"], label, otherName)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s vs %s: Targets"], win.actorname, otherName)
		if not set or not win.actorname then return end

		local targets, _, actor = set:GetActorDamageTargets(win.actorid, win.actorname)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		-- same actor?
		if actor.id == otherGUID then
			win.title = format(L["%s's targets"], actor.name)

			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win:actor(nr, target, true, targetname)
				d.value = P.absdamage and target.total or target.amount
				d.valuetext = Skada:FormatValueCols(mod_cols.Damage and Skada:FormatNumber(d.value))

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end

			return
		end

		-- collect compared actor's targets.
		local otargets = set:GetActorDamageTargets(otherGUID, otherName, C)

		-- iterate comparison actor's targets.
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, targetname)
			d.value = P.absdamage and target.total or target.amount

			local otarget = otargets and otargets[targetname]
			local oamount = otarget and (P.absdamage and otarget.total or otarget.amount)
			d.valuetext = format_value_number(d.value, oamount, true, actor.id == otherGUID)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end

		-- any other left targets.
		if not otargets then return end
		for targetname, target in pairs(otargets) do
			if not targets[targetname] then
				nr = nr + 1

				local d = win:actor(nr, target, true, targetname)
				d.value = P.absdamage and target.total or target.amount
				d.valuetext = format_value_number(0, d.value, true, actor.id == otherGUID)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = format("%s: %s", L["Comparison"], otherName)

		local total = set and set:GetDamage()
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local oamount = set:GetActorDamage(otherGUID, otherName)

		for i = 1, #set.actors do
			local actor = set.actors[i]
			if can_compare(actor) then
				local dps, amount = actor:GetDPS(set)
				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, actor)

					d.value = amount
					d.valuetext = Skada:FormatValueCols(
						mod_cols.Damage and Skada:FormatNumber(d.value),
						mod_cols.DPS and Skada:FormatNumber(dps),
						format_percent(oamount, d.value, mod_cols.Percent and actor.id ~= otherGUID)
					)

					-- a valid window, not a tooltip
					if win.metadata then
						-- color the selected actor's bar.
						if actor.id == otherGUID then
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

	local function set_actor(_, win, id, label)
		-- no DisplayMode func?
		if not win or not win.DisplayMode then return end
		userGUID = userGUID or Skada.userGUID

		-- same actor or me? reset to the actor
		if id == userGUID or (id == otherGUID and win.selectedmode == mod) then
			userName = userName or Skada.userName
			userClass = userClass or Skada.userClass
			otherGUID = userGUID
			otherName = userName
			otherClass = userClass
			win:DisplayMode(mod)
		elseif win.GetSelectedSet then
			local set = win:GetSelectedSet()
			local actor = set and set:GetActor(label, id)
			if actor then
				otherGUID = actor.id
				otherName = actor.name
				otherClass = actor.class
				win:DisplayMode(mod)
			end
		end
	end

	function mod:OnEnable()
		dspellmod.metadata = {tooltip = spellmod_tooltip}
		targetmod.metadata = {click1 = dtargetmod}
		spellmod.metadata = {click1 = dspellmod, click2 = bspellmod}
		self.metadata = {
			showspots = true,
			post_tooltip = activity_tooltip,
			click1 = spellmod,
			click2 = targetmod,
			click3 = set_actor,
			click3_label = L["Damage Comparison"],
			columns = {Damage = true, DPS = true, Comparison = true, Percent = true},
			icon = [[Interface\Icons\Ability_Warrior_OffensiveStance]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		self.nototal = true
		spellmod.nototal = true
		targetmod.nototal = true

		self.category = parent.category or L["Damage Done"]
		Skada:AddColumnOptions(self)

		parent.metadata.click3 = set_actor
		parent.metadata.click3_label = L["Damage Comparison"]
		parent:Reload()
	end
end, "Damage")
