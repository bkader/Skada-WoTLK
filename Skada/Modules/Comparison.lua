local Skada = Skada
Skada:AddLoadableModule("Comparison", function(L)
	if Skada:IsDisabled("Damage", "Comparison") then return end

	local mod = Skada:NewModule(L["Comparison"])

	local spellmod = mod:NewModule(L["Damage spell list"])
	local dspellmod = spellmod:NewModule(L["Damage spell details"])
	local bspellmod = spellmod:NewModule(L["Damage Breakdown"])

	local targetmod = mod:NewModule(L["Damage target list"])
	local dtargetmod = targetmod:NewModule(L["Damage spell list"])

	local pairs, format, max = pairs, string.format, math.max
	local GetSpellInfo, T = Skada.GetSpellInfo or GetSpellInfo, Skada.Table
	local cacheTable = T.get("Skada_CacheTable2")
	local COLOR_GOLD = {r = 1, g = 0.82, b = 0, colorStr = "ffffd100"}
	local _

	-- damage miss types
	local missTypes = Skada.missTypes
	if not missTypes then
		missTypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}
		Skada.missTypes = missTypes
	end

	-- percentage colors
	local red = "|cffffaaaa-%s|r"
	local green = "|cffaaffaa+%s|r"
	local grey = "|cff808080%s|r"

	local function FormatPercent(value1, value2, cond)
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

	local function FormatValuePercent(val, myval, disabled)
		return Skada:FormatValueCols(
			mod.metadata.columns.Damage and Skada:FormatPercent(val),
			(mod.metadata.columns.Comparison and not disabled) and Skada:FormatPercent(myval),
			(mod.metadata.columns.Percent and not disabled) and FormatPercent(myval, val)
		)
	end

	local function FormatValueNumber(val, myval, fmt, disabled)
		val, myval = val or 0, myval or 0 -- sanity check
		return Skada:FormatValueCols(
			mod.metadata.columns.Damage and (fmt and Skada:FormatNumber(val) or val),
			(mod.metadata.columns.Comparison and not disabled) and (fmt and Skada:FormatNumber(myval) or myval),
			FormatPercent(myval, val, mod.metadata.columns.Percent and not disabled)
		)
	end

	local function CanCompare(actor)
		return (actor and actor.class == mod.userClass and actor.role == "DAMAGER")
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetActor(win.actorname, win.actorid)
			local spell = actor.damagespells and actor.damagespells[win.spellname]

			if actor.id == mod.userGUID then
				if spell then
					tooltip:AddLine(actor.name .. " - " .. win.spellname)
					if spell.school and Skada.spellschools[spell.school] then
						tooltip:AddLine(
							Skada.spellschools[spell.school].name,
							Skada.spellschools[spell.school].r,
							Skada.spellschools[spell.school].g,
							Skada.spellschools[spell.school].b
						)
					end

					if label == L["Critical Hits"] and spell.criticalamount then
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
						if spell.criticalmin and spell.criticalmax then
							tooltip:AddLine(" ")
							tooltip:AddDoubleLine(L["Minimum Hit"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
							tooltip:AddDoubleLine(L["Maximum Hit"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
							tooltip:AddDoubleLine(L["Average Hit"], Skada:FormatNumber((spell.criticalmin + spell.criticalmax) / 2), 1, 1, 1)
						end
					elseif label == L["Normal Hits"] and spell.hitamount then
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.hitamount / spell.hit), 1, 1, 1)
						if spell.hitmin and spell.hitmax then
							tooltip:AddLine(" ")
							tooltip:AddDoubleLine(L["Minimum Hit"], Skada:FormatNumber(spell.hitmin), 1, 1, 1)
							tooltip:AddDoubleLine(L["Maximum Hit"], Skada:FormatNumber(spell.hitmax), 1, 1, 1)
							tooltip:AddDoubleLine(L["Average Hit"], Skada:FormatNumber((spell.hitmin + spell.hitmax) / 2), 1, 1, 1)
						end
					end
				end
				return
			end

			local myspells = set:GetActorDamageSpells(mod.userGUID, mod.userName)
			local myspell = myspells and myspells[win.spellname]

			if spell or myspell then
				tooltip:AddLine(format(L["%s vs %s: %s"], actor and actor.name or L.Unknown, mod.userName, win.spellname))
				if (spell.school and Skada.spellschools[spell.school]) or (myspell.school and Skada.spellschools[myspell.school]) then
					tooltip:AddLine(
						Skada.spellschools[spell and spell.school or myspell.school].name,
						Skada.spellschools[spell and spell.school or myspell.school].r,
						Skada.spellschools[spell and spell.school or myspell.school].g,
						Skada.spellschools[spell and spell.school or myspell.school].b
					)
				end

				if label == L["Critical Hits"] and (spell and spell.criticalamount or myspell.criticalamount) then
					local num = spell and spell.critical and (100 * spell.critical / spell.count) or 0
					local mynum = myspell and myspell.critical and (100 * myspell.critical / myspell.count) or 0

					tooltip:AddDoubleLine(L["Critical"], FormatValuePercent(mynum, num, actor.id == mod.userGUID), 1, 1, 1)

					num = (spell and spell.criticalamount) and (spell.criticalamount / spell.critical) or 0
					mynum = (myspell and myspell.criticalamount) and (myspell.criticalamount / myspell.critical) or 0

					tooltip:AddDoubleLine(L["Average"], FormatValueNumber(num, mynum, true), 1, 1, 1)

					if (spell and spell.criticalmin and spell.criticalmax) or (myspell and myspell.criticalmin and myspell.criticalmax) then
						tooltip:AddLine(" ")
						tooltip:AddDoubleLine(L["Minimum Hit"], FormatValueNumber(spell and spell.criticalmin, myspell and myspell.criticalmin, true), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum Hit"], FormatValueNumber(spell and spell.criticalmax, myspell and myspell.criticalmax, true), 1, 1, 1)

						num = (spell and spell.criticalmin and spell.criticalmax) and ((spell.criticalmin + spell.criticalmax) / 2) or 0
						mynum = (myspell and myspell.criticalmin and myspell.criticalmax) and ((myspell.criticalmin + myspell.criticalmax) / 2) or 0
						tooltip:AddDoubleLine(L["Average Hit"], FormatValueNumber(num, mynum, true), 1, 1, 1)
					end
				elseif label == L["Normal Hits"] and ((spell and spell.hitamount) or (myspell and myspell.hitamount)) then
					local num = (spell and spell.hitamount) and (spell.hitamount / spell.hit) or 0
					local mynum = (myspell and myspell.hitamount) and (myspell.hitamount / myspell.hit) or 0

					tooltip:AddDoubleLine(L["Average"], FormatValueNumber(num, mynum, true), 1, 1, 1)

					if (spell and spell.hitmin and spell.hitmax) or (myspell and myspell.hitmin and myspell.hitmax) then
						tooltip:AddLine(" ")
						tooltip:AddDoubleLine(L["Minimum Hit"], FormatValueNumber(spell and spell.hitmin, myspell and myspell.hitmin, true), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum Hit"], FormatValueNumber(spell and spell.hitmax, myspell and myspell.hitmax, true), 1, 1, 1)

						num = (spell and spell.hitmin and spell.hitmax) and ((spell.hitmin + spell.hitmax) / 2) or 0
						mynum = (myspell and myspell.hitmin and myspell.hitmax) and ((myspell.hitmin + myspell.hitmax) / 2) or 0
						tooltip:AddDoubleLine(L["Average Hit"], FormatValueNumber(num, mynum, true), 1, 1, 1)
					end
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

			tooltip:AddDoubleLine(L["Activity"], FormatValuePercent(100 * activetime / totaltime, 100 * mytime / totaltime, actor.id == mod.userGUID), 1, 1, 1)
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

		d.valuetext = FormatValueNumber(value, myvalue, fmt, disabled)

		if win.metadata and (not win.metadata.maxvalue or d.value > win.metadata.maxvalue) then
			win.metadata.maxvalue = d.value
		end

		return nr
	end

	function dspellmod:Enter(win, id, label)
		win.spellname = label
		win.title = format(L["%s vs %s: %s"], win.actorname or L.Unknown, mod.userName or L.Unknown, format(L["%s's damage breakdown"], label))
	end

	function dspellmod:Update(win, set)
		win.title = format(L["%s vs %s: %s"], win.actorname or L.Unknown, mod.userName or L.Unknown, format(L["%s's damage breakdown"], win.spellname or L.Unknown))
		if not set or not win.spellname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
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

				if (spell.casts or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Casts"], spell.casts, nil, nil, true)
					win.dataset[nr].value = win.dataset[nr].value * 1e3 -- to be always first
				end

				if (spell.hit or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Normal Hits"], spell.hit, nil, nil, true)
				end

				if (spell.critical or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Critical Hits"], spell.critical, nil, nil, true)
				end

				if (spell.glancing or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Glancing"], spell.glancing, nil, nil, true)
				end

				for i = 1, #missTypes do
					local misstype = missTypes[i]
					if misstype and spell[misstype] then
						nr = add_detail_bar(win, nr, L[misstype], spell[misstype], nil, nil, true)
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

			if (spell and (spell.casts or 0) > 0) or (myspell and (myspell.casts or 0) > 0) then
				nr = add_detail_bar(win, nr, L["Casts"], spell and spell.casts, myspell and myspell.casts)
				win.dataset[nr].value = win.dataset[nr].value * 1e3 -- to be always first
			end

			if (spell and (spell.hit or 0) > 0) or (myspell and (myspell.hit or 0) > 0) then
				nr = add_detail_bar(win, nr, L["Normal Hits"], spell and spell.hit, myspell and myspell.hit)
			end

			if (spell and (spell.critical or 0) > 0) or (myspell and (myspell.critical or 0) > 0) then
				nr = add_detail_bar(win, nr, L["Critical Hits"], spell and spell.critical, myspell and myspell.critical)
			end

			if (spell and (spell.glancing or 0) > 0) or (myspell and (myspell.glancing or 0) > 0) then
				nr = add_detail_bar(win, nr, L["Glancing"], spell and spell.glancing, myspell and myspell.glancing)
			end

			for i = 1, #missTypes do
				local misstype = missTypes[i]
				if misstype and ((spell and spell[misstype]) or (myspell and myspell[misstype])) then
					nr = add_detail_bar(win, nr, L[misstype], spell and spell[misstype], myspell and myspell[misstype])
				end
			end
		end
	end

	function bspellmod:Enter(win, id, label)
		win.spellname = label
		win.title = format(L["%s vs %s: %s"], win.actorname or L.Unknown, mod.userName or L.Unknown, L["actor damage"](label))
	end

	function bspellmod:Update(win, set)
		win.title = format(L["%s vs %s: %s"], win.actorname or L.Unknown, mod.userName or L.Unknown, L["actor damage"](win.spellname or L.Unknown))
		if not set or not win.spellname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagespells and actor.damagespells[win.spellname]

		if actor.id == mod.userGUID then
			win.title = format(L["%s's <%s> damage"], actor.name, win.spellname)

			if spell then
				local absorbed = max(0, spell.total - spell.amount)
				local blocked, resisted = spell.blocked or 0, spell.resisted or 0
				local total = spell.amount + absorbed + blocked + resisted

				-- total damage
				local nr = add_detail_bar(win, 0, L["Total"], total, nil, true, true)
				win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

				-- real damage
				if total ~= spell.amount then
					nr = add_detail_bar(win, nr, L["Damage"], spell.amount, nil, true, true)
				end

				-- absorbed damage
				if absorbed > 0 then
					nr = add_detail_bar(win, nr, L["Overkill"], absorbed, nil, true, true)
				end

				-- overkill damage
				if (spell.overkill or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Overkill"], spell.overkill, nil, true, true)
				end

				-- blocked damage
				if (spell.blocked or 0) > 0 then
					nr = add_detail_bar(win, nr, L["BLOCK"], spell.blocked, nil, true, true)
				end

				-- resisted damage
				if (spell.resisted or 0) > 0 then
					nr = add_detail_bar(win, nr, L["RESIST"], spell.resisted, nil, true, true)
				end
			end

			return
		end

		local myspells = set:GetActorDamageSpells(mod.userGUID, mod.userName)
		local myspell = myspells and myspells[win.spellname]

		if spell or myspell then
			local absorbed = spell and max(0, spell.total - spell.amount) or 0
			local myabsorbed = myspell and max(0, myspell.total - myspell.amount) or 0
			local blocked, myblocked = spell and spell.blocked or 0, myspell and myspell.blocked or 0
			local resisted, myresisted = spell and spell.resisted or 0, myspell and myspell.resisted or 0

			local total = (spell and spell.amount or 0) + absorbed + blocked + resisted
			local mytotal = (myspell and myspell.amount or 0) + myabsorbed + myblocked + myresisted

			-- total damage
			local nr = add_detail_bar(win, 0, L["Total"], total, mytotal, true)
			win.dataset[nr].value = (spell and total or mytotal) + 1 -- to be always first

			-- real damage
			if (spell and total ~= spell.amount) or (myspell and mytotal ~= myspell.amount) then
				nr = add_detail_bar(win, nr, L["Damage"], spell and spell.amount, myspell and myspell.amount, true)
			end

			-- absorbed damage
			if absorbed > 0 or myabsorbed > 0 then
				nr = add_detail_bar(win, nr, L["ABSORB"], absorbed, myabsorbed, true)
			end

			-- overkill damage
			if (spell and (spell.overkill or 0) > 0) or (myspell and (myspell.overkill or 0) > 0) then
				nr = add_detail_bar(win, nr, L["Overkill"], spell and spell.overkill, myspell and myspell.overkill, true)
			end

			-- blocked damage
			if (spell and (spell.blocked or 0) > 0) or (myspell and (myspell.blocked or 0) > 0) then
				nr = add_detail_bar(win, nr, L["BLOCK"], spell and spell.blocked, myspell and myspell.blocked, true)
			end

			-- resisted damage
			if (spell and (spell.resisted or 0) > 0) or (myspell and (myspell.resisted or 0) > 0) then
				nr = add_detail_bar(win, nr, L["RESIST"], spell and spell.resisted, myspell and myspell.resisted, true)
			end
		end
	end

	function dtargetmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["%s vs %s: Damage on %s"], win.actorname or L.Unknown, mod.userName or L.Unknown, label)
	end

	function dtargetmod:Update(win, set)
		win.title = format(L["%s vs %s: Damage on %s"], win.actorname or L.Unknown, mod.userName or L.Unknown, win.targetname or L.Unknown)
		if not set or not win.targetname then return end

		local targets, actor = set:GetActorDamageTargets(win.actorid, win.actorname)
		if not targets then return end

		if actor.id == mod.userGUID then
			win.title = L["actor damage"](actor.name, win.targetname)

			local total = targets[win.targetname] and targets[win.targetname].amount or 0
			if Skada.db.profile.absdamage and targets[win.targetname] and targets[win.targetname].total then
				total = targets[win.targetname].total
			end

			if total > 0 and actor.damagespells then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for spellname, spell in pairs(actor.damagespells) do
					if spell.targets and spell.targets[win.targetname] then
						nr = nr + 1
						local d = win:nr(nr)

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						_, _, d.icon = GetSpellInfo(spell.id)
						d.spellschool = spell.school

						d.value = spell.targets[win.targetname].amount or 0
						if Skada.db.profile.absdamage and spell.targets[win.targetname].total then
							d.value = spell.targets[win.targetname].total
						end

						d.valuetext = Skada:FormatValueCols(mod.metadata.columns.Damage and Skada:FormatNumber(d.value))

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end

			return
		end

		local mytargets, myself = set:GetActorDamageTargets(mod.userGUID, mod.userName, cacheTable)

		-- the compared actor
		local total = targets[win.targetname] and targets[win.targetname].amount or 0
		if Skada.db.profile.absdamage and targets[win.targetname] and targets[win.targetname].total then
			total = targets[win.targetname].total
		end

		-- existing targets.
		if total > 0 and actor.damagespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellname, spell in pairs(actor.damagespells) do
				if spell.targets and spell.targets[win.targetname] then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = spellname
					d.spellid = spell.id
					d.label = spellname
					_, _, d.icon = GetSpellInfo(spell.id)
					d.spellschool = spell.school

					local myamount = 0
					if Skada.db.profile.absdamage then
						d.value = spell.targets[win.targetname].total or spell.targets[win.targetname].amount or 0
						if
							myself and
							myself.damagespells and
							myself.damagespells[spellname] and
							myself.damagespells[spellname].targets and
							myself.damagespells[spellname].targets[win.targetname]
						then
							myamount = myself.damagespells[spellname].targets[win.targetname].total or myself.damagespells[spellname].targets[win.targetname].amount or 0
						end
					else
						d.value = spell.targets[win.targetname].amount or 0
						if
							myself and
							myself.damagespells and
							myself.damagespells[spellname] and
							myself.damagespells[spellname].targets and
							myself.damagespells[spellname].targets[win.targetname]
						then
							myamount = myself.damagespells[spellname].targets[win.targetname].amount or 0
						end
					end

					d.valuetext = FormatValueNumber(d.value, myamount, true)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			return
		end

		-- unexisting targets.
		if mytargets then
			local mytotal = mytargets[win.targetname] and mytargets[win.targetname].amount or 0
			if Skada.db.profile.absdamage and mytargets[win.targetname] and mytargets[win.targetname].total then
				mytotal = mytargets[win.targetname].total
			end
			if mytotal > 0 then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for spellname, spell in pairs(myself.damagespells) do
					if spell.targets and spell.targets[win.targetname] then
						nr = nr + 1
						local d = win:nr(nr)

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						_, _, d.icon = GetSpellInfo(spell.id)
						d.spellschool = spell.school

						local myamount = spell.targets[win.targetname].amount or 0
						if Skada.db.profile.absdamage and spell.targets[win.targetname].total then
							myamount = spell.targets[win.targetname].total
						end

						d.value = myamount
						d.valuetext = FormatValueNumber(0, myamount, true)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s vs %s: Spells"], label, mod.userName or L.Unknown)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s vs %s: Spells"], win.actorname or L.Unknown, mod.userName or L.Unknown)
		if not set or not win.actorname then return end

		local spells, actor = set:GetActorDamageSpells(win.actorid, win.actorname)
		if actor and spells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- same actor?
			if actor.id == mod.userGUID then
				win.title = L["actor damage"](actor.name)

				for spellname, spell in pairs(spells) do
					nr = nr + 1
					local d = win:nr(nr)

					d.id = spellname
					d.spellid = spell.id
					d.label = spellname
					_, _, d.icon = GetSpellInfo(spell.id)
					d.spellschool = spell.school

					d.value = spell.amount or 0
					if Skada.db.profile.absdamage and spell.total then
						d.value = spell.total
					end

					d.valuetext = Skada:FormatValueCols(mod.metadata.columns.Damage and Skada:FormatNumber(d.value))

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
				local d = win:nr(nr)

				d.id = spellname
				d.spellid = spell.id
				d.label = spellname
				_, _, d.icon = GetSpellInfo(spell.id)
				d.spellschool = spell.school

				local myamount = 0
				if Skada.db.profile.absdamage then
					d.value = spell.total or spell.amount or 0
					if myspells and myspells[spellname] then
						myamount = myspells[spellname].total or myspells[spellname].amount or 0
					end
				else
					d.value = spell.amount or 0
					if myspells and myspells[spellname] then
						myamount = myspells[spellname].amount or 0
					end
				end

				d.valuetext = FormatValueNumber(d.value, myamount, true)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end

			-- any other left spells.
			if myspells then
				for spellname, spell in pairs(myspells) do
					if not spells[spellname] then
						nr = nr + 1
						local d = win:nr(nr)

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						_, _, d.icon = GetSpellInfo(spell.id)
						d.spellschool = spell.school

						local myamount = 0
						if Skada.db.profile.absdamage and spell.total then
							myamount = spell.total
						else
							myamount = spell.amount or 0
						end

						d.value = myamount
						d.valuetext = FormatValueNumber(0, myamount, true)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s vs %s: Targets"], label, mod.userName or L.Unknown)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s vs %s: Targets"], win.actorname or L.Unknown, mod.userName or L.Unknown)
		if not set or not win.actorname then return end

		local targets, actor = set:GetActorDamageTargets(win.actorid, win.actorname)
		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- same actor?
			if actor.id == mod.userGUID then
				win.title = format(L["%s's targets"], actor.name)

				for targetname, target in pairs(targets) do
					nr = nr + 1
					local d = win:nr(nr)

					d.id = target.id or targetname
					d.label = targetname
					d.class = target.class
					d.role = target.role
					d.spec = target.spec

					if Skada.db.profile.absdamage and target.total then
						d.value = target.total
					else
						d.value = target.amount or 0
					end

					d.valuetext = Skada:FormatValueCols(mod.metadata.columns.Damage and Skada:FormatNumber(d.value))

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
				return
			end

			-- collect compared actor's targets.
			local mytargets = set:GetActorDamageTargets(mod.userGUID, mod.userName, cacheTable)

			-- iterate comparison actor's targets.
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				local myamount = 0
				if Skada.db.profile.absdamage then
					d.value = target.total or target.amount or 0
					if mytargets and mytargets[targetname] then
						myamount = mytargets[targetname].amount or mytargets[targetname].amount or 0
					end
				else
					d.value = target.amount or 0
					if mytargets and mytargets[targetname] then
						myamount = mytargets[targetname].amount or 0
					end
				end

				d.valuetext = FormatValueNumber(d.value, myamount, true, actor.id == mod.userGUID)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end

			-- any other left targets.
			if mytargets then
				for targetname, target in pairs(mytargets) do
					if not targets[targetname] then
						nr = nr + 1
						local d = win:nr(nr)

						d.id = target.id or targetname
						d.label = targetname
						d.class = target.class
						d.role = target.role
						d.spec = target.spec

						local myamount = 0
						if Skada.db.profile.absdamage and target.total then
							myamount = target.total
						else
							myamount = target.amount or 0
						end

						d.value = myamount
						d.valuetext = FormatValueNumber(0, myamount, true, actor.id == mod.userGUID)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = format("%s: %s", L["Comparison"], self.userName)

		if set and set:GetDamage() > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local myamount = set:GetActorDamage(mod.userGUID, mod.userName)
			local nr = 0

			for i = 1, #set.players do
				local player = set.players[i]
				if CanCompare(player) then
					local dps, amount = player:GetDPS()
					if amount > 0 then
						nr = nr + 1
						local d = win:nr(nr)

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						d.value = amount
						d.valuetext = Skada:FormatValueCols(
							mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
							mod.metadata.columns.DPS and Skada:FormatNumber(dps),
							FormatPercent(myamount, d.value, mod.metadata.columns.Percent and player.id ~= mod.userGUID)
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
	end

	function mod:SetActor(win, id, label)
		-- no DisplayMode func?
		if not win.DisplayMode then return end

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

	-- just to alter "CanCompare" function
	function mod:OnInitialize()
		if Skada.Ascension then
			CanCompare = function(actor)
				return (actor and actor.class == mod.userClass)
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
			click3 = self.SetActor,
			click3_label = L["Damage Comparison"],
			columns = {Damage = true, DPS = true, Comparison = true, Percent = true},
			icon = [[Interface\Icons\Ability_Warrior_OffensiveStance]]
		}

		-- no total click.
		spellmod.nototal = true
		targetmod.nototal = true

		self.userGUID = Skada.userGUID
		self.userName = Skada.userName
		self.userClass = Skada.userClass

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)