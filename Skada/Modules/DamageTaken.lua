local Skada = Skada

-- cache frequently used globals
local pairs, select, format, max = pairs, select, string.format, math.max
local GetSpellInfo, T = Skada.GetSpellInfo, Skada.Table
local _

-- =================== --
-- Damage Taken Module --
-- =================== --

Skada:RegisterModule("Damage Taken", function(L, P, _, _, new, del)
	if Skada:IsDisabled("Damage Taken") then return end

	local mod = Skada:NewModule("Damage Taken")
	local playermod = mod:NewModule("Damage spell list")
	local spellmod = playermod:NewModule("Damage spell details")
	local sdetailmod = spellmod:NewModule("Damage Breakdown")
	local sourcemod = mod:NewModule("Damage source list")
	local tdetailmod = sourcemod:NewModule("Damage spell list")
	local spellschools = Skada.spellschools
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local GetTime = GetTime

	-- damage miss types
	local missTypes = Skada.missTypes
	if not missTypes then
		missTypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}
		Skada.missTypes = missTypes
	end

	local function log_damage(set, dmg, tick)
		local player = Skada:GetPlayer(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if not player then return end

		player.damagetaken = (player.damagetaken or 0) + dmg.amount
		player.totaldamagetaken = (player.totaldamagetaken or 0) + dmg.amount

		set.damagetaken = (set.damagetaken or 0) + dmg.amount
		set.totaldamagetaken = (set.totaldamagetaken or 0) + dmg.amount

		-- add absorbed damage to total damage
		local absorbed = dmg.absorbed or 0
		if absorbed > 0 then
			player.totaldamagetaken = player.totaldamagetaken + absorbed
			set.totaldamagetaken = set.totaldamagetaken + absorbed
		end

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		local spellname = dmg.spellname .. (tick and L["DoT"] or "")
		local spell = player.damagetakenspells and player.damagetakenspells[spellname]
		if not spell then
			player.damagetakenspells = player.damagetakenspells or {}
			spell = {id = dmg.spellid, school = dmg.spellschool, amount = 0}
			player.damagetakenspells[spellname] = spell
		elseif dmg.spellid and dmg.spellid ~= spell.id then
			if dmg.spellschool and dmg.spellschool ~= spell.school then
				spellname = spellname .. " (" .. (spellschools[dmg.spellschool] and spellschools[dmg.spellschool].name or L["Other"]) .. ")"
			else
				spellname = GetSpellInfo(dmg.spellid)
			end
			if not player.damagetakenspells[spellname] then
				player.damagetakenspells[spellname] = {id = dmg.spellid, school = dmg.spellschool, amount = 0}
			end
			spell = player.damagetakenspells[spellname]
		elseif not spell.school and dmg.spellschool then
			spell.school = dmg.spellschool
		end

		spell.count = (spell.count or 0) + 1
		spell.amount = spell.amount + dmg.amount

		if spell.total then
			spell.total = spell.total + dmg.amount + absorbed
		elseif absorbed > 0 then
			spell.total = spell.amount + absorbed
		end

		if dmg.critical then
			spell.critical = (spell.critical or 0) + 1
			spell.criticalamount = (spell.criticalamount or 0) + dmg.amount

			if not spell.criticalmax or dmg.amount > spell.criticalmax then
				spell.criticalmax = dmg.amount
			end

			if not spell.criticalmin or dmg.amount < spell.criticalmin then
				spell.criticalmin = dmg.amount
			end
		elseif dmg.misstype ~= nil then
			spell[dmg.misstype] = (spell[dmg.misstype] or 0) + 1
		elseif dmg.glancing then
			spell.glancing = (spell.glancing or 0) + 1
			spell.glance = (spell.glance or 0) + dmg.amount
			if not spell.glancemax or dmg.amount > spell.glancemax then
				spell.glancemax = dmg.amount
			end
			if not spell.glancemin or dmg.amount < spell.glancemin then
				spell.glancemin = dmg.amount
			end
		elseif dmg.crushing then
			spell.crushing = (spell.crushing or 0) + 1
		else
			spell.hit = (spell.hit or 0) + 1
			spell.hitamount = (spell.hitamount or 0) + dmg.amount
			if not spell.hitmax or dmg.amount > spell.hitmax then
				spell.hitmax = dmg.amount
			end
			if not spell.hitmin or dmg.amount < spell.hitmin then
				spell.hitmin = dmg.amount
			end
		end

		if dmg.blocked and dmg.blocked > 0 then
			spell.blocked = (spell.blocked or 0) + dmg.blocked
		end

		if dmg.resisted and dmg.resisted > 0 then
			spell.resisted = (spell.resisted or 0) + dmg.resisted
		end

		local overkill = dmg.overkill or 0
		if overkill > 0 then
			spell.overkill = (spell.overkill or 0) + dmg.overkill
		end

		-- record the source
		if dmg.srcName then
			local source = spell.sources and spell.sources[dmg.srcName]
			if not source then
				spell.sources = spell.sources or {}
				spell.sources[dmg.srcName] = {amount = 0}
				source = spell.sources[dmg.srcName]
			end
			source.amount = source.amount + dmg.amount

			if source.total then
				source.total = source.total + dmg.amount + absorbed
			elseif absorbed > 0 then
				source.total = source.amount + absorbed
			end

			if overkill > 0 then
				source.overkill = (source.overkill or 0) + dmg.overkill
			end
		end
	end

	local dmg = {}
	local extraATT

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			-- handle extra attacks
			if eventtype == "SPELL_EXTRA_ATTACKS" then
				local spellid, spellname, _, amount = ...

				if spellid and spellname and not ignoredSpells[spellid] then
					extraATT = extraATT or T.get("Damage_ExtraAttacks")
					if not extraATT[srcName] then
						extraATT[srcName] = new()
						extraATT[srcName].proc = spellname
						extraATT[srcName].count = amount
						extraATT[srcName].time = Skada.current.last_time or GetTime()
					end
				end

				return
			end

			if eventtype == "SWING_DAMAGE" then
				dmg.spellid, dmg.spellname, dmg.spellschool = 6603, L["Melee"], 0x01
				dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing, dmg.crushing = ...

				-- an extra attack?
				if extraATT and extraATT[srcName] then
					local curtime = Skada.current.last_time or GetTime()
					if not extraATT[srcName].spellname then -- queue spell
						extraATT[srcName].spellname = dmg.spellname
					elseif dmg.spellname == L["Melee"] and extraATT[srcName].time < (curtime - 5) then -- expired proc
						extraATT[srcName] = del(extraATT[srcName])
					elseif dmg.spellname == L["Melee"] then -- valid damage contribution
						dmg.spellname = extraATT[srcName].spellname .. " (" .. extraATT[srcName].proc .. ")"
						extraATT[srcName].count = max(0, extraATT[srcName].count - 1)
						if extraATT[srcName].count == 0 then -- no procs left
							extraATT[srcName] = del(extraATT[srcName])
						end
					end
				end
			else
				dmg.spellid, dmg.spellname, dmg.spellschool, dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing, dmg.crushing = ...
			end

			if dmg.spellid and dmg.spellname and not ignoredSpells[dmg.spellid] then
				dmg.srcGUID = srcGUID
				dmg.srcName = srcName
				dmg.srcFlags = srcFlags

				dmg.playerid = dstGUID
				dmg.playername = dstName
				dmg.playerflags = dstFlags

				dmg.misstype = nil

				Skada:DispatchSets(log_damage, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
			end
		end
	end

	local function EnvironmentDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local envtype = ...
		local spellid, spellname, spellschool = nil, nil, 0x01

		if envtype == "Falling" or envtype == "FALLING" then
			spellid, spellname = 3, L["Falling"]
		elseif envtype == "Drowning" or envtype == "DROWNING" then
			spellid, spellname = 4, L["Drowning"]
		elseif envtype == "Fatigue" or envtype == "FATIGUE" then
			spellid, spellname = 5, L["Fatigue"]
		elseif envtype == "Fire" or envtype == "FIRE" then
			spellid, spellname, spellschool = 6, L["Fire"], 0x04
		elseif envtype == "Lava" or envtype == "LAVA" then
			spellid, spellname, spellschool = 7, L["Lava"], 0x04
		elseif envtype == "Slime" or envtype == "SLIME" then
			spellid, spellname, spellschool = 8, L["Slime"], 0x08
		end

		if spellid and spellname then
			SpellDamage(nil, nil, nil, L["Environment"], nil, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, select(2, ...))
		end
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local amount

			if eventtype == "SWING_MISSED" then
				dmg.spellid, dmg.spellname, dmg.spellschool = 6603, L["Melee"], 0x01
				dmg.misstype, amount = ...
			else
				dmg.spellid, dmg.spellname, dmg.spellschool, dmg.misstype, amount = ...
			end

			if dmg.spellid and dmg.spellname and not ignoredSpells[dmg.spellid] then
				dmg.srcGUID = srcGUID
				dmg.srcName = srcName
				dmg.srcFlags = srcFlags

				dmg.playerid = dstGUID
				dmg.playername = dstName
				dmg.playerflags = dstFlags

				dmg.amount = 0
				dmg.overkill = 0
				dmg.resisted = nil
				dmg.blocked = nil
				dmg.absorbed = nil
				dmg.critical = nil
				dmg.glancing = nil
				dmg.crushing = nil

				if dmg.misstype == "ABSORB" then
					dmg.absorbed = amount or 0
				elseif dmg.misstype == "BLOCK" then
					dmg.blocked = amount or 0
				elseif dmg.misstype == "RESIST" then
					dmg.resisted = amount or 0
				end

				Skada:DispatchSets(log_damage, dmg, eventtype == "SPELL_PERIODIC_MISSED")
			end
		end
	end

	local function damage_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if actor then
			local totaltime = set:GetTime()
			local activetime = actor:GetTime(true)
			local dtps, damage = actor:GetDTPS()

			tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, totaltime), nil, nil, nil, 1, 1, 1)
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Damage Taken"], Skada:FormatNumber(damage), 1, 1, 1)

			local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
			tooltip:AddDoubleLine(Skada:FormatNumber(damage) .. "/" .. suffix, Skada:FormatNumber(dtps), 1, 1, 1)
		end
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if enemy then return end -- sorry, only for players.

		local spell = actor and actor.damagetakenspells and actor.damagetakenspells[label]
		if spell then
			tooltip:AddLine(label .. " - " .. actor.name)
			if spell.school and spellschools[spell.school] then
				tooltip:AddLine(spellschools(spell.school))
			end

			if spell.hitmin then
				local spellmin = spell.hitmin
				if spell.criticalmin and spell.criticalmin < spellmin then
					spellmin = spell.criticalmin
				end
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
			end

			if spell.hitmax then
				local spellmax = spell.hitmax
				if spell.criticalmax and spell.criticalmax > spellmax then
					spellmax = spell.criticalmax
				end
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spellmax), 1, 1, 1)
			end

			if spell.count then
				local amount = P.absdamage and spell.total or spell.amount
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(amount / spell.count), 1, 1, 1)
			end
		end
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] or label == L["Glancing"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetPlayer(win.actorid, win.actorname)
			local spell = actor and actor.damagetakenspells and actor.damagetakenspells[win.spellname]
			if spell then
				tooltip:AddLine(actor.name .. " - " .. win.spellname)
				if spell.school and spellschools[spell.school] then
					tooltip:AddLine(spellschools(spell.school))
				end

				if label == L["Critical Hits"] and spell.criticalamount then
					if spell.criticalmin then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
					end
					if spell.criticalmax then
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
					end
					tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
				elseif label == L["Normal Hits"] and spell.hitamount then
					if spell.hitmin then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.hitmin), 1, 1, 1)
					end
					if spell.hitmax then
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.hitmax), 1, 1, 1)
					end
					tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.hitamount / spell.hit), 1, 1, 1)
				elseif label == L["Glancing"] and spell.glance then
					if spell.glancemin then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.glancemin), 1, 1, 1)
					end
					if spell.glancemax then
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.glancemax), 1, 1, 1)
					end
					tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.glance / spell.glancing), 1, 1, 1)
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["Damage taken by %s"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["Damage taken by %s"], win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamageTaken() or 0

		if total > 0 and actor.damagetakenspells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDTPS and actor:GetTime(), 0
			for spellname, spell in pairs(actor.damagetakenspells) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = spellname
				d.spellschool = spell.school

				if enemy then
					d.spellid = spellname
					d.label, _, d.icon = GetSpellInfo(spellname)
				else
					d.spellid = spell.id
					d.label = spellname
					_, _, d.icon = GetSpellInfo(spell.id)
				end

				d.value = spell.amount
				if P.absdamage and spell.total then
					d.value = min(total, spell.total)
				end

				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
					actortime and Skada:FormatNumber(d.value / actortime),
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function sourcemod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's damage sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = format(L["%s's damage sources"], win.actorname or L["Unknown"])

		local actor = set and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local sources, total = actor:GetDamageSources()
		if sources and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDTPS and actor:GetTime(), 0
			for sourcename, source in pairs(sources) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = source.id or sourcename
				d.label = sourcename
				d.class = source.class
				d.role = source.role
				d.spec = source.spec

				d.value = P.absdamage and source.total or source.amount
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
					actortime and Skada:FormatNumber(d.value / actortime),
					mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	local function add_detail_bar(win, nr, title, value, total, percent, fmt)
		nr = nr + 1
		local d = win:nr(nr)

		d.id = title
		d.label = title
		d.value = value
		d.valuetext = Skada:FormatValueCols(
			mod.metadata.columns.Damage and (fmt and Skada:FormatNumber(value) or value),
			(mod.metadata.columns.sPercent and percent) and Skada:FormatPercent(d.value, total)
		)

		if win.metadata and d.value > win.metadata.maxvalue then
			win.metadata.maxvalue = d.value
		end

		return nr
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format("%s: %s", win.actorname or L["Unknown"], format(L["%s's damage breakdown"], label))
	end

	function spellmod:Update(win, set)
		win.title = format("%s: %s", win.actorname or L["Unknown"], format(L["%s's damage breakdown"], win.spellname or L["Unknown"]))
		if not set or not win.spellname then return end

		-- details only available for players
		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagetakenspells and actor.damagetakenspells[enemy and win.spellid or win.spellname]
		if spell then
			if win.metadata then
				if enemy then
					win.metadata.maxvalue = P.absdamage and spell.total or spell.amount or 0
				else
					win.metadata.maxvalue = spell.count
				end
			end

			if enemy then
				local amount = P.absdamage and spell.total or spell.amount
				local nr = add_detail_bar(win, 0, L["Damage"], amount, nil, nil, true)

				if spell.total and spell.total ~= spell.amount then
					nr = add_detail_bar(win, nr, L["ABSORB"], spell.total - spell.amount, nil, nil, true)
				end
			else
				local nr = add_detail_bar(win, 0, L["Hits"], spell.count)
				win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

				if spell.hit and spell.hit > 0 then
					nr = add_detail_bar(win, nr, L["Normal Hits"], spell.hit, spell.count, true)
				end

				if spell.critical and spell.critical > 0 then
					nr = add_detail_bar(win, nr, L["Critical Hits"], spell.critical, spell.count, true)
				end

				if spell.glancing and spell.glancing > 0 then
					nr = add_detail_bar(win, nr, L["Glancing"], spell.glancing, spell.count, true)
				end

				if spell.crushing and spell.crushing > 0 then
					nr = add_detail_bar(win, nr, L["Crushing"], spell.crushing, spell.count, true)
				end

				for i = 1, #missTypes do
					local misstype = missTypes[i]
					if misstype and spell[misstype] then
						nr = add_detail_bar(win, nr, L[misstype], spell[misstype], spell.count, true)
					end
				end
			end
		end
	end

	function sdetailmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format("%s: %s", win.actorname or L["Unknown"], format(L["Damage from %s"], label))
	end

	function sdetailmod:Update(win, set)
		win.title = format("%s: %s", win.actorname or L["Unknown"], format(L["Damage from %s"], win.spellname or L["Unknown"]))
		if not set or not win.spellname then return end

		-- only available for players
		local actor = set:GetPlayer(win.actorid, win.actorname)
		local spell = actor and actor.damagetakenspells and actor.damagetakenspells[win.spellname]
		if spell then
			local absorbed = max(0, spell.total - spell.amount)
			local blocked = spell.blocked or 0
			local resisted = spell.resisted or 0
			local total = spell.amount + absorbed + blocked + resisted
			if win.metadata then
				win.metadata.maxvalue = total
			end

			local nr = add_detail_bar(win, 0, L["Total"], total, nil, nil, true)
			win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

			if total ~= spell.amount then
				nr = add_detail_bar(win, nr, L["Damage"], spell.amount, total, true, true)
			end

			if spell.overkill and spell.overkill > 0 then
				nr = add_detail_bar(win, nr, L["Overkill"], spell.overkill, total, true, true)
			end

			if absorbed > 0 then
				nr = add_detail_bar(win, nr, L["ABSORB"], absorbed, total, true, true)
			end

			if spell.blocked and spell.blocked > 0 then
				nr = add_detail_bar(win, nr, L["BLOCK"], spell.blocked, total, true, true)
			end

			if spell.resisted and spell.resisted > 0 then
				nr = add_detail_bar(win, nr, L["RESIST"], spell.resisted, total, true, true)
			end
		end
	end

	function tdetailmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor damage"](label, win.actorname or L["Unknown"])
	end

	function tdetailmod:Update(win, set)
		win.title = L["actor damage"](win.targetname or L["Unknown"], win.actorname or L["Unknown"])
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local sources = actor and actor:GetDamageSources()
		if sources and sources[win.targetname] then
			local total = sources[win.targetname].amount or 0
			if P.absdamage and sources[win.targetname].total then
				total = sources[win.targetname].total
			end

			if total > 0 then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local actortime, nr = mod.metadata.columns.sDTPS and actor:GetTime(), 0
				for spellname, spell in pairs(actor.damagetakenspells) do
					if spell.sources and spell.sources[win.targetname] then
						nr = nr + 1
						local d = win:nr(nr)

						if enemy then
							d.spellid = spellname
							d.label, _, d.icon = GetSpellInfo(spellname)
							d.id = d.label
						else
							d.id = spellname
							d.spellid = spell.id
							d.label = spellname
							_, _, d.icon = GetSpellInfo(spell.id)
						end

						d.spellschool = spell.school

						d.value = spell.sources[win.targetname].amount or 0
						if P.absdamage and spell.sources[win.targetname].total then
							d.value = spell.sources[win.targetname].total
						end

						d.valuetext = Skada:FormatValueCols(
							mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
							actortime and Skada:FormatNumber(d.value / actortime),
							mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
						)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Damage Taken"], L[win.class]) or L["Damage Taken"]

		local total = set and set:GetDamageTaken() or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- players.
			for i = 1, #set.players do
				local player = set.players[i]
				if player and (not win.class or win.class == player.class) then
					local dtps, amount = player:GetDTPS()
					if amount > 0 then
						nr = nr + 1
						local d = win:nr(nr)

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						if Skada.forPVP and set.type == "arena" then
							d.color = Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN")
						end

						d.value = amount
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.Damage and Skada:FormatNumber(d.value),
							self.metadata.columns.DTPS and Skada:FormatNumber(dtps),
							self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
						)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end

			-- arena enemies
			if Skada.forPVP and set.type == "arena" and set.enemies then
				for i = 1, #set.enemies do
					local enemy = set.enemies[i]
					if enemy and not enemy.fake and (not win.class or win.class == enemy.class) then
						local dtps, amount = enemy:GetDTPS()
						if amount > 0 then
							nr = nr + 1
							local d = win:nr(nr)

							d.id = enemy.id or enemy.name
							d.label = enemy.name
							d.text = nil
							d.class = enemy.class
							d.role = enemy.role
							d.spec = enemy.spec
							d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")

							d.value = amount
							d.valuetext = Skada:FormatValueCols(
								self.metadata.columns.Damage and Skada:FormatNumber(d.value),
								self.metadata.columns.DTPS and Skada:FormatNumber(dtps),
								self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
							)

							if win.metadata and d.value > win.metadata.maxvalue then
								win.metadata.maxvalue = d.value
							end
						end
					end
				end
			end
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = spellmod_tooltip}
		playermod.metadata = {click1 = spellmod, click2 = sdetailmod, post_tooltip = playermod_tooltip}
		sourcemod.metadata = {click1 = tdetailmod}
		self.metadata = {
			showspots = true,
			post_tooltip = damage_tooltip,
			click1 = playermod,
			click2 = sourcemod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Damage = true, DTPS = false, Percent = true, sDTPS = false, sPercent = true},
			icon = [[Interface\Icons\ability_mage_frostfirebolt]]
		}

		-- no total click.
		playermod.nototal = true
		sourcemod.nototal = true

		local flags_dst = {dst_is_interesting_nopets = true}

		Skada:RegisterForCL(
			SpellDamage,
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_EXTRA_ATTACKS",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			flags_dst
		)

		Skada:RegisterForCL(
			EnvironmentDamage,
			"ENVIRONMENTAL_DAMAGE",
			flags_dst
		)

		Skada:RegisterForCL(
			SpellMissed,
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED",
			flags_dst
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self, L["Damage Taken"])

		-- table of ignored spells:
		if Skada.ignoredSpells and Skada.ignoredSpells.damagetaken then
			ignoredSpells = Skada.ignoredSpells.damagetaken
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if not set then return end
		local dtps, amount = set:GetDTPS()
		tooltip:AddDoubleLine(L["Damage Taken"], Skada:FormatNumber(amount), 1, 1, 1)
		tooltip:AddDoubleLine(L["DTPS"], Skada:FormatNumber(dtps), 1, 1, 1)
	end

	function mod:GetSetSummary(set)
		local dtps, amount = set:GetDTPS()
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Damage and Skada:FormatNumber(amount),
			self.metadata.columns.DTPS and Skada:FormatNumber(dtps)
		)
		return valuetext, amount
	end

	function mod:CombatLeave()
		T.clear(dmg)
		T.free("Damage_ExtraAttacks", extraATT, nil, del)
	end

	function mod:SetComplete(set)
		-- clean set from garbage before it is saved.
		if not set.totaldamagetaken or set.totaldamagetaken == 0 then return end
		for i = 1, #set.players do
			local p = set.players[i]
			if p and p.totaldamagetaken == 0 then
				p.damagetakenspells = del(p.damagetakenspells, true)
			elseif p and p.damagetakenspells then
				for spellname, spell in pairs(p.damagetakenspells) do
					if not spell.total or spell.total == 0 or not spell.count or spell.count == 0 then
						p.damagetakenspells[spellname] = del(p.damagetakenspells[spellname])
					end
				end
				-- nothing left?
				if next(p.damagetakenspells) == nil then
					p.damagetakenspells = del(p.damagetakenspells)
				end
			end
		end
	end
end)

-- ============================== --
-- Damage taken per second module --
-- ============================== --

Skada:RegisterModule("DTPS", function(L, P)
	if Skada:IsDisabled("Damage Taken", "DTPS") then return end

	local mod = Skada:NewModule("DTPS")

	local function dtps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if actor then
			local totaltime = set:GetTime()
			local activetime = actor:GetTime(true)
			local dtps, damage = actor:GetDTPS()

			tooltip:AddLine(actor.name .. " - " .. L["DTPS"])
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Damage Taken"], Skada:FormatNumber(damage), 1, 1, 1)

			local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
			tooltip:AddDoubleLine(Skada:FormatNumber(damage) .. "/" .. suffix, Skada:FormatNumber(dtps), 1, 1, 1)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["DTPS"], L[win.class]) or L["DTPS"]

		local total = set and set:GetDTPS() or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- players
			for i = 1, #set.players do
				local player = set.players[i]
				if player and (not win.class or win.class == player.class) then
					local dtps = player:GetDTPS()
					if dtps > 0 then
						nr = nr + 1
						local d = win:nr(nr)

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						if Skada.forPVP and set.type == "arena" then
							d.color = Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN")
						end

						d.value = dtps
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.DTPS and Skada:FormatNumber(d.value),
							self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
						)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end

			-- arena enemies
			if Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyDamageTaken then
				for i = 1, #set.enemies do
					local enemy = set.enemies[i]
					if enemy and not enemy.fake and (not win.class or win.class == enemy.class) then
						local dtps = enemy:GetDTPS()
						if dtps > 0 then
							nr = nr + 1
							local d = win:nr(nr)

							d.id = enemy.id or enemy.name
							d.label = enemy.name
							d.text = nil
							d.class = enemy.class
							d.role = enemy.role
							d.spec = enemy.spec
							d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")

							d.value = dtps
							d.valuetext = Skada:FormatValueCols(
								self.metadata.columns.DTPS and Skada:FormatNumber(d.value),
								self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
							)

							if win.metadata and d.value > win.metadata.maxvalue then
								win.metadata.maxvalue = d.value
							end
						end
					end
				end
			end
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			tooltip = dtps_tooltip,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {DTPS = true, Percent = true},
			icon = [[Interface\Icons\inv_weapon_shortblade_06]]
		}

		local parentmod = Skada:GetModule("Damage Taken", true)
		if parentmod then
			self.metadata.click1 = parentmod.metadata.click1
			self.metadata.click2 = parentmod.metadata.click2
		end

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local dtps = set:GetDTPS()
		return Skada:FormatNumber(dtps), dtps
	end
end)

-- ============================ --
-- Damage Taken By Spell Module --
-- ============================ --

Skada:RegisterModule("Damage Taken By Spell", function(L, P, _, _, new, _, clear)
	if Skada:IsDisabled("Damage Taken", "Damage Taken By Spell") then return end

	local mod = Skada:NewModule("Damage Taken By Spell")
	local targetmod = mod:NewModule("Damage spell targets")
	local sourcemod = mod:NewModule("Damage spell sources")
	local C = Skada.cacheTable2

	local function player_tooltip(win, id, label, tooltip)
		local set = win.spellname and win:GetSelectedSet()
		local player = set and set:GetActor(label, id)
		local spell = player and player.damagetakenspells and player.damagetakenspells[win.spellname]
		if spell and spell.count then
			tooltip:AddLine(label .. " - " .. win.spellname)

			tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
			local diff = spell.count -- used later

			if spell.hit then
				tooltip:AddDoubleLine(L["Normal Hits"], Skada:FormatPercent(spell.hit, spell.count), 1, 1, 1)
				diff = diff - spell.hit
			end

			if spell.critical then
				tooltip:AddDoubleLine(L["Critical Hits"], Skada:FormatPercent(spell.critical, spell.count), 1, 1, 1)
				diff = diff - spell.critical
			end

			if spell.glancing then
				tooltip:AddDoubleLine(L["Glancing"], Skada:FormatPercent(spell.glancing, spell.count), 1, 1, 1)
				diff = diff - spell.glancing
			end

			if diff > 0 then
				tooltip:AddDoubleLine(L["Other"], Skada:FormatPercent(diff, spell.count), nil, nil, nil, 1, 1, 1)
			end
		end
	end

	function sourcemod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function sourcemod:Update(win, set)
		win.title = format(L["%s's sources"], win.spellname or L["Unknown"])
		if win.spellname then
			local sources, total = clear(C), 0
			for i = 1, #set.players do
				local player = set.players[i]
				if
					player and
					player.damagetakenspells and
					player.damagetakenspells[win.spellname] and
					player.damagetakenspells[win.spellname].sources
				then
					for sourcename, source in pairs(player.damagetakenspells[win.spellname].sources) do
						local amount = P.absdamage and source.total or source.amount or 0
						if amount > 0 then
							if not sources[sourcename] then
								sources[sourcename] = new()
								sources[sourcename].amount = amount
							else
								sources[sourcename].amount = sources[sourcename].amount + amount
							end

							total = total + amount

							if not sources[sourcename].class or (mod.metadata.columns.sDTPS and not sources[sourcename].time) then
								local actor = set:GetActor(sourcename)
								if actor and not sources[sourcename].class then
									sources[sourcename].id = actor.id or actor.name
									sources[sourcename].class = actor.class
									sources[sourcename].role = actor.role
									sources[sourcename].spec = actor.spec
								end
								if actor and mod.metadata.columns.sDTPS and not sources[sourcename].time then
									sources[sourcename].time = set:GetActorTime(actor.id, actor.name)
								end
							end
						end
					end
				end
			end

			if total > 0 then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for sourcename, source in pairs(sources) do
					nr = nr + 1
					local d = win:nr(nr)

					d.id = source.id or sourcename
					d.label = sourcename
					d.class = source.class
					d.role = source.role
					d.spec = source.spec

					d.value = source.amount
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
						source.time and Skada:FormatNumber(d.value / source.time),
						mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's targets"], win.spellname or L["Unknown"])
		if win.spellname then
			local targets, total = clear(C), 0
			for i = 1, #set.players do
				local player = set.players[i]
				local spell = player and player.damagetakenspells and player.damagetakenspells[win.spellname]
				if spell then
					local amount = P.absdamage and spell.total or spell.amount or 0
					if amount > 0 then
						targets[player.name] = new()
						targets[player.name].id = player.id
						targets[player.name].class = player.class
						targets[player.name].role = player.role
						targets[player.name].spec = player.spec
						targets[player.name].amount = amount
						targets[player.name].time = mod.metadata.columns.sDTPS and player:GetTime()

						total = total + amount
					end
				end
			end

			if total > 0 then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for playername, player in pairs(targets) do
					nr = nr + 1
					local d = win:nr(nr)

					d.id = player.id or playername
					d.label = playername
					d.text = player.id and Skada:FormatName(playername, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.amount
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
						player.time and Skada:FormatNumber(d.value / player.time),
						mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Damage Taken By Spell"]
		local total = set and set:GetDamageTaken() or 0
		if total == 0 then return end

		local spells = clear(C)
		for i = 1, #set.players do
			local player = set.players[i]
			if player and player.damagetakenspells then
				for spellname, spell in pairs(player.damagetakenspells) do
					local amount = P.absdamage and spell.total or spell.amount or 0
					if amount > 0 then
						if not spells[spellname] then
							spells[spellname] = new()
							spells[spellname].id = spell.id
							spells[spellname].school = spell.school
							spells[spellname].amount = amount
						else
							spells[spellname].amount = spells[spellname].amount + amount
						end
					end
				end
			end
		end

		if win.metadata then
			win.metadata.maxvalue = 0
		end

		local settime, nr = self.metadata.columns.DTPS and set:GetTime(), 0
		for spellname, spell in pairs(spells) do
			nr = nr + 1
			local d = win:nr(nr)

			d.id = spellname
			d.spellid = spell.id
			d.label = spellname
			_, _, d.icon = GetSpellInfo(spell.id)
			d.spellschool = spell.school

			d.value = spell.amount
			d.valuetext = Skada:FormatValueCols(
				self.metadata.columns.Damage and Skada:FormatNumber(d.value),
				settime and Skada:FormatNumber(d.value / settime),
				self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
			)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end
	end

	function mod:OnEnable()
		targetmod.metadata = {showspots = true, tooltip = player_tooltip}
		self.metadata = {
			showspots = true,
			click1 = targetmod,
			click2 = sourcemod,
			columns = {Damage = true, DTPS = false, Percent = true, sDTPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_arcane_starfire]]
		}
		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)

-- ============================= --
-- Avoidance & Mitigation Module --
-- ============================= --

Skada:RegisterModule("Avoidance & Mitigation", function(L, _, _, _, new, del, clear)
	if Skada:IsDisabled("Damage Taken", "Avoidance & Mitigation") then return end

	local mod = Skada:NewModule("Avoidance & Mitigation")
	local playermod = mod:NewModule("Damage Breakdown")
	local C = Skada.cacheTable2

	-- damage miss types
	local missTypes = Skada.missTypes
	if not missTypes then
		missTypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}
		Skada.missTypes = missTypes
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's damage breakdown"], label)
	end

	function playermod:Update(win, set)
		if C[win.actorid] then
			local actor = C[win.actorid]
			win.title = format(L["%s's damage breakdown"], actor.name)

			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for event, count in pairs(actor.data) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = event
				d.label = L[event]

				d.value = 100 * count / actor.total
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value),
					mod.metadata.columns.Count and count,
					mod.metadata.columns.Total and actor.total
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Avoidance & Mitigation"], L[win.class]) or L["Avoidance & Mitigation"]

		if set.totaldamagetaken and set.totaldamagetaken > 0 then
			clear(C, true) -- used later

			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for i = 1, #set.players do
				local player = set.players[i]
				if player and (not win.class or win.class == player.class) then
					if player.damagetakenspells then
						local tmp = new()
						tmp.name = player.name

						local total, avoid = 0, 0
						for _, spell in pairs(player.damagetakenspells) do
							total = total + spell.count

							for j = 1, #missTypes do
								local t = missTypes[j]
								if t and spell[t] then
									avoid = avoid + spell[t]
									tmp.data = tmp.data or new()
									tmp.data[t] = (tmp.data[t] or 0) + spell[t]
								end
							end
						end

						if avoid > 0 then
							tmp.total = total
							tmp.avoid = avoid
							C[player.id] = tmp

							nr = nr + 1
							local d = win:nr(nr)

							d.id = player.id or player.name
							d.label = player.name
							d.text = player.id and Skada:FormatName(player.name, player.id)
							d.class = player.class
							d.role = player.role
							d.spec = player.spec

							d.value = 100 * avoid / total
							d.valuetext = Skada:FormatValueCols(
								self.metadata.columns.Percent and Skada:FormatPercent(d.value),
								self.metadata.columns.Count and avoid,
								self.metadata.columns.Total and total
							)

							if win.metadata and d.value > win.metadata.maxvalue then
								win.metadata.maxvalue = d.value
							end
						elseif C[player.id] then
							C[player.id] = del(C[player.id])
						end
					end
				end
			end
		end
	end

	function mod:OnEnable()
		playermod.metadata = {}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Percent = true, Count = true, Total = true},
			icon = [[Interface\Icons\ability_warlock_avoidance]]
		}

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)