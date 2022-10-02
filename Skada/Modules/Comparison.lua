local _, Skada = ...
local private = Skada.private
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
	local format, uformat = string.format, private.uformat
	local spellschools = Skada.spellschools
	local COLOR_GOLD = {r = 1, g = 0.82, b = 0, colorStr = "ffffd100"}
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

	local function format_value_percent(val, myval, disabled)
		val, myval = val or 0, myval or 0
		return Skada:FormatValueCols(
			mod.metadata.columns.Damage and Skada:FormatPercent(val),
			(mod.metadata.columns.Comparison and not disabled) and Skada:FormatPercent(myval),
			(mod.metadata.columns.Percent and not disabled) and format_percent(myval, val)
		)
	end

	local function format_value_number(val, myval, fmt, disabled)
		val, myval = val or 0, myval or 0 -- sanity check
		return Skada:FormatValueCols(
			mod.metadata.columns.Damage and (fmt and Skada:FormatNumber(val) or val),
			(mod.metadata.columns.Comparison and not disabled) and (fmt and Skada:FormatNumber(myval) or myval),
			format_percent(myval, val, mod.metadata.columns.Percent and not disabled)
		)
	end

	local function can_compare(actor)
		return (actor and actor.class == mod.userClass and actor.role == "DAMAGER")
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] or label == L["Glancing"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetActor(win.actorname, win.actorid)
			local spell = actor.damagespells and actor.damagespells[win.spellname]

			if actor.id == mod.userGUID then
				if spell then
					tooltip:AddLine(actor.name .. " - " .. win.spellname)
					if spell.school and spellschools[spell.school] then
						tooltip:AddLine(spellschools(spell.school))
					end

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

			local myspells = set:GetActorDamageSpells(mod.userGUID, mod.userName)
			local myspell = myspells and myspells[win.spellname]

			if spell or myspell then
				tooltip:AddLine(uformat(L["%s vs %s: %s"], actor and actor.name, mod.userName, win.spellname))
				if (spell.school and spellschools[spell.school]) or (myspell.school and spellschools[myspell.school]) then
					tooltip:AddLine(spellschools(spell and spell.school or myspell.school))
				end

				if label == L["Critical Hits"] and (spell and spell.c_amt or myspell.c_amt) then
					local num = spell and spell.c_num and (100 * spell.c_num / spell.count)
					local mynum = myspell and myspell.c_num and (100 * myspell.c_num / myspell.count)

					tooltip:AddDoubleLine(L["Critical"], format_value_percent(mynum, num, actor.id == mod.userGUID), 1, 1, 1)

					num = (spell and spell.c_amt) and (spell.c_amt / spell.c_num)
					mynum = (myspell and myspell.c_amt) and (myspell.c_amt / myspell.c_num)

					if (spell and spell.c_min) or (myspell and myspell.c_min) then
						tooltip:AddDoubleLine(L["Minimum"], format_value_number(spell and spell.c_min, myspell and myspell.c_min, true), 1, 1, 1)
					end

					if (spell and spell.c_max) or (myspell and myspell.c_max) then
						tooltip:AddDoubleLine(L["Maximum"], format_value_number(spell and spell.c_max, myspell and myspell.c_max, true), 1, 1, 1)
					end

					tooltip:AddDoubleLine(L["Average"], format_value_number(num, mynum, true), 1, 1, 1)
				elseif label == L["Normal Hits"] and ((spell and spell.n_amt) or (myspell and myspell.n_amt)) then
					local num = (spell and spell.n_amt) and (spell.n_amt / spell.n_num)
					local mynum = (myspell and myspell.n_amt) and (myspell.n_amt / myspell.n_num)

					if (spell and spell.n_min) or (myspell and myspell.n_min) then
						tooltip:AddDoubleLine(L["Minimum"], format_value_number(spell and spell.n_min, myspell and myspell.n_min, true), 1, 1, 1)
					end

					if (spell and spell.n_max) or (myspell and myspell.n_max) then
						tooltip:AddDoubleLine(L["Maximum"], format_value_number(spell and spell.n_max, myspell and myspell.n_max, true), 1, 1, 1)
					end

					tooltip:AddDoubleLine(L["Average"], format_value_number(num, mynum, true), 1, 1, 1)
				elseif label == L["Glancing"] and ((spell and spell.g_amt) or (myspell and myspell.g_amt)) then
					local num = (spell and spell.g_amt) and (spell.g_amt / spell.g_num)
					local mynum = (myspell and myspell.g_amt) and (myspell.g_amt / myspell.g_num)

					if (spell and spell.g_min) or (myspell and myspell.g_min) then
						tooltip:AddDoubleLine(L["Minimum"], format_value_number(spell and spell.g_min, myspell and myspell.g_min, true), 1, 1, 1)
					end

					if (spell and spell.g_max) or (myspell and myspell.g_max) then
						tooltip:AddDoubleLine(L["Maximum"], format_value_number(spell and spell.g_max, myspell and myspell.g_max, true), 1, 1, 1)
					end

					tooltip:AddDoubleLine(L["Average"], format_value_number(num, mynum, true), 1, 1, 1)
				end
			end
		end
	end

	local function activity_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if actor then
			local totaltime = set:GetTime()
			local activetime = actor:GetTime(true)
			local mytime = set:GetActorTime(mod.userGUID, mod.userName, true)

			tooltip:AddDoubleLine(L["Activity"], format_value_percent(100 * activetime / totaltime, 100 * mytime / totaltime, actor.id == mod.userGUID), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], format(actor.id ~= mod.userGUID and "%s (%s)" or "%s", Skada:FormatTime(activetime), Skada:FormatTime(mytime)), 1, 1, 1)
		end
	end

	-- local nr = add_detail_bar(win, 0, L["Hits"], spell.count, myspell.count)
	local function add_detail_bar(win, nr, title, value, myvalue, fmt, disabled)
		nr = nr + 1
		local d = win:nr(nr)

		d.id = title
		d.label = title

		if value then
			d.value = value
			myvalue = myvalue or 0
		elseif myvalue then
			d.value = myvalue
			value = value or 0
		else
			d.value = value or 0
			myvalue = myvalue or 0
		end

		d.valuetext = format_value_number(value, myvalue, fmt, disabled)

		if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
			win.metadata.maxvalue = d.value
		end

		return nr
	end

	function dspellmod:Enter(win, id, label)
		win.spellname = label
		win.title = uformat(L["%s vs %s: %s"], win.actorname, mod.userName, uformat(L["%s's damage breakdown"], label))
	end

	function dspellmod:Update(win, set)
		win.title = uformat(L["%s vs %s: %s"], win.actorname, mod.userName, uformat(L["%s's damage breakdown"], win.spellname))
		if not set or not win.spellname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local spell = actor and actor.damagespells and actor.damagespells[win.spellname]

		-- same actor?
		if actor.id == mod.userGUID then
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

		local myspells = set:GetActorDamageSpells(mod.userGUID, mod.userName)
		local myspell = myspells and myspells[win.spellname]

		if spell or myspell then
			if win.metadata then
				win.metadata.maxvalue = spell and spell.count or myspell.count
			end

			local nr = add_detail_bar(win, 0, L["Hits"], spell and spell.count, myspell and myspell.count)
			win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

			if (spell and spell.casts and spell.casts > 0) or (myspell and myspell.casts and myspell.casts > 0) then
				nr = add_detail_bar(win, nr, L["Casts"], spell and spell.casts, myspell and myspell.casts)
				win.dataset[nr].value = win.dataset[nr].value * 1e3 -- to be always first
			end

			if (spell and spell.n_num and spell.n_num > 0) or (myspell and myspell.n_num and myspell.n_num > 0) then
				nr = add_detail_bar(win, nr, L["Normal Hits"], spell and spell.n_num, myspell and myspell.n_num)
			end

			if (spell and spell.c_num and spell.c_num > 0) or (myspell and myspell.c_num and myspell.c_num > 0) then
				nr = add_detail_bar(win, nr, L["Critical Hits"], spell and spell.c_num, myspell and myspell.c_num)
			end

			if (spell and spell.g_num and spell.g_num > 0) or (myspell and myspell.g_num and myspell.g_num > 0) then
				nr = add_detail_bar(win, nr, L["Glancing"], spell and spell.g_num, myspell and myspell.g_num)
			end

			for k, v in pairs(missTypes) do
				if (spell and (spell[v] or spell[k])) or (myspell and (myspell[v] or myspell[k])) then
					nr = add_detail_bar(win, nr, L[k], spell and (spell[v] or spell[k]), myspell and (myspell[v] or myspell[k]))
				end
			end
		end
	end

	function bspellmod:Enter(win, id, label)
		win.spellname = label
		win.title = uformat(L["%s vs %s: %s"], win.actorname, mod.userName, L["actor damage"](label))
	end

	function bspellmod:Update(win, set)
		win.title = uformat(L["%s vs %s: %s"], win.actorname, mod.userName, L["actor damage"](win.spellname or L["Unknown"]))
		if not set or not win.spellname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local spell = actor and actor.damagespells and actor.damagespells[win.spellname]

		if actor.id == mod.userGUID then
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
				local overkill = spell.o_amt or spell.overkill
				if overkill and overkill > 0 then
					nr = add_detail_bar(win, nr, L["Overkill"], overkill, nil, true, true)
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

		local myspells = set:GetActorDamageSpells(mod.userGUID, mod.userName)
		local myspell = myspells and myspells[win.spellname]

		if spell or myspell then
			local total = spell and spell.amount
			local mytotal = myspell and myspell.amount

			local absorbed = (spell and spell.total) and max(0, spell.total - spell.amount)
			if absorbed then
				total = spell.total
			end

			local myabsorbed = (myspell and myspell.total) and max(0, myspell.total - myspell.amount)
			if myabsorbed then
				mytotal = myspell.total
			end

			local blocked = spell and (spell.b_amt or spell.blocked)
			if blocked then
				total = total + blocked
			end

			local myblocked = myspell and (myspell.b_amt or myspell.blocked)
			if myblocked then
				mytotal = mytotal + myblocked
			end

			local resisted = spell and (spell.r_amt or spell.resisted)
			if resisted then
				total = total + resisted
			end

			local myresisted = myspell and (myspell.r_amt or myspell.resisted)
			if myresisted then
				mytotal = mytotal + myresisted
			end

			-- total damage
			local nr = add_detail_bar(win, 0, L["Total"], total, mytotal, true)
			win.dataset[nr].value = (spell and total or mytotal) + 1 -- to be always first

			-- real damage
			if (spell and total ~= spell.amount) or (myspell and mytotal ~= myspell.amount) then
				nr = add_detail_bar(win, nr, L["Damage"], spell and spell.amount, myspell and myspell.amount, true)
			end

			-- absorbed damage
			if (absorbed and absorbed > 0) or (myabsorbed and myabsorbed > 0) then
				nr = add_detail_bar(win, nr, L["ABSORB"], absorbed, myabsorbed, true)
			end

			-- overkill damage
			local overkill = spell and (spell.o_amt or spell.overkill)
			local myoverkill = myspell and (myspell.o_amt or myspell.overkill)
			if (overkill and overkill > 0) or (myoverkill and myoverkill > 0) then
				nr = add_detail_bar(win, nr, L["Overkill"], overkill, myoverkill, true)
			end

			-- blocked damage
			if (blocked and blocked > 0) or (myblocked and myblocked > 0) then
				nr = add_detail_bar(win, nr, L["BLOCK"], blocked, myblocked, true)
			end

			-- resisted damage
			if (resisted and resisted > 0) or (myresisted and myresisted > 0) then
				nr = add_detail_bar(win, nr, L["RESIST"], resisted, myresisted, true)
			end
		end
	end

	function dtargetmod:Enter(win, id, label)
		win.targetname = label
		win.title = uformat(L["%s vs %s: Damage on %s"], win.actorname, mod.userName, label)
	end

	function dtargetmod:Update(win, set)
		win.title = uformat(L["%s vs %s: Damage on %s"], win.actorname, mod.userName, win.targetname)
		if not set or not win.targetname then return end

		local targets, actor = set:GetActorDamageTargets(win.actorid, win.actorname)
		if not targets then return end

		if actor.id == mod.userGUID then
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
			for spellname, spell in pairs(spells) do
				local target = spell.targets and spell.targets[win.targetname]
				local amount = target and (P.absdamage and target.total or target.amount)
				if amount then
					nr = nr + 1

					local d = win:spell(nr, spellname, spell)
					d.value = amount
					d.valuetext = Skada:FormatValueCols(mod_cols.Damage and Skada:FormatNumber(d.value))

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			return
		end

		local mytargets, myself = set:GetActorDamageTargets(mod.userGUID, mod.userName, C)

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
			for spellname, spell in pairs(spells) do
				if spell.targets and spell.targets[win.targetname] then
					nr = nr + 1
					local d = win:spell(nr, spellname, spell)

					d.value = spell.targets[win.targetname].amount or 0
					local myamount = 0
					if
						myself and
						myself.damagespells and
						myself.damagespells[spellname] and
						myself.damagespells[spellname].targets and
						myself.damagespells[spellname].targets[win.targetname]
					then
						myamount = myself.damagespells[spellname].targets[win.targetname].amount or myamount
					end

					if P.absdamage then
						if spell.targets[win.targetname].total then
							d.value = spell.targets[win.targetname].total
						end
						if
							myself and
							myself.damagespells and
							myself.damagespells[spellname] and
							myself.damagespells[spellname].targets and
							myself.damagespells[spellname].targets[win.targetname] and
							myself.damagespells[spellname].targets[win.targetname].total
						then
							myamount = myself.damagespells[spellname].targets[win.targetname].total
						end
					end

					d.valuetext = format_value_number(d.value, myamount, true)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			return
		end

		-- unexisting targets.
		if not mytargets then return end
		total = mytargets[win.targetname] and mytargets[win.targetname].amount
		if P.absdamage and mytargets[win.targetname].total then
			total = mytargets[win.targetname].total
		end

		spells = (total and total > 0) and myself.damagespells
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellname, spell in pairs(spells) do
			local target = spell.targets and spell.targets[win.targetname]
			local amount = target and (P.absdamage and target.total or target.amount)
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellname, spell)
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
		win.title = uformat(L["%s vs %s: Spells"], label, mod.userName)
	end

	function spellmod:Update(win, set)
		win.title = uformat(L["%s vs %s: Spells"], win.actorname, mod.userName)
		if not set or not win.actorname then return end

		local spells, actor = set:GetActorDamageSpells(win.actorid, win.actorname)
		if not actor or not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		-- same actor?
		if actor.id == mod.userGUID then
			win.title = L["actor damage"](actor.name)

			for spellname, spell in pairs(spells) do
				nr = nr + 1

				local d = win:spell(nr, spellname, spell)
				d.value = P.absdamage and spell.total or spell.amount or 0
				d.valuetext = Skada:FormatValueCols(mod_cols.Damage and Skada:FormatNumber(d.value))

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end

			return
		end

		-- collect compared actor's spells.
		local myspells = set:GetActorDamageSpells(mod.userGUID, mod.userName)

		-- iterate comparison actor's spells.
		for spellname, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellname, spell)
			d.value = P.absdamage and spell.total or spell.amount

			local myspell = myspells and myspells[spellname]
			local myamount = myspell and (P.absdamage and myspell.total or myspell.amount)
			d.valuetext = format_value_number(d.value, myamount, true)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end

		-- any other left spells.
		if not myspells then return end
		for spellname, spell in pairs(myspells) do
			if not spells[spellname] then
				nr = nr + 1

				local d = win:spell(nr, spellname, spell)
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
		win.title = uformat(L["%s vs %s: Targets"], label, mod.userName)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s vs %s: Targets"], win.actorname, mod.userName)
		if not set or not win.actorname then return end

		local targets, actor = set:GetActorDamageTargets(win.actorid, win.actorname)

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		-- same actor?
		if actor.id == mod.userGUID then
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
		local mytargets = set:GetActorDamageTargets(mod.userGUID, mod.userName, C)

		-- iterate comparison actor's targets.
		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, targetname)
			d.value = P.absdamage and target.total or target.amount

			local mytarget = mytargets and mytargets[targetname]
			local myamount = mytarget and (P.absdamage and mytarget.total or mytarget.amount)
			d.valuetext = format_value_number(d.value, myamount, true, actor.id == mod.userGUID)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end

		-- any other left targets.
		if not mytargets then return end
		for targetname, target in pairs(mytargets) do
			if not targets[targetname] then
				nr = nr + 1

				local d = win:actor(nr, target, true, targetname)
				d.value = P.absdamage and target.total or target.amount
				d.valuetext = format_value_number(0, d.value, true, actor.id == mod.userGUID)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = format("%s: %s", L["Comparison"], self.userName)

		local total = set and set:GetDamage()
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local myamount = set:GetActorDamage(mod.userGUID, mod.userName)

		for i = 1, #set.players do
			local player = set.players[i]
			if can_compare(player) then
				local dps, amount = player:GetDPS()
				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, player)

					d.value = amount
					d.valuetext = Skada:FormatValueCols(
						mod_cols.Damage and Skada:FormatNumber(d.value),
						mod_cols.DPS and Skada:FormatNumber(dps),
						format_percent(myamount, d.value, mod_cols.Percent and player.id ~= mod.userGUID)
					)

					-- a valid window, not a tooltip
					if win.metadata then
						-- color the selected player's bar.
						if player.id == mod.userGUID then
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

		-- same actor or me? reset to the player
		if id == Skada.userGUID or (id == mod.userGUID and win.selectedmode == mod) then
			mod.userGUID = Skada.userGUID
			mod.userName = Skada.userName
			mod.userClass = Skada.userClass
			win:DisplayMode(mod)
		elseif win.GetSelectedSet then
			local set = win:GetSelectedSet()
			local actor = set and set:GetActor(label, id)
			if actor then
				mod.userGUID = actor.id
				mod.userName = actor.name
				mod.userClass = actor.class
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
