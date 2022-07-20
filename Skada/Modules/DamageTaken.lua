local Skada = Skada

-- cache frequently used globals
local pairs, select, max = pairs, select, math.max
local format, pformat, T = string.format, Skada.pformat, Skada.Table
local _

-- =================== --
-- Damage Taken Module --
-- =================== --

Skada:RegisterModule("Damage Taken", function(L, P, _, _, new, del)
	local mod = Skada:NewModule("Damage Taken")
	local playermod = mod:NewModule("Damage spell list")
	local spellmod = playermod:NewModule("Damage spell details")
	local sdetailmod = spellmod:NewModule("Damage Breakdown")
	local sourcemod = mod:NewModule("Damage source list")
	local tdetailmod = sourcemod:NewModule("Damage spell list")
	local spellschools = Skada.spellschools
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local missTypes = Skada.missTypes
	local GetTime = GetTime

	local function log_damage(set, dmg, isdot)
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

		local spellid = isdot and -dmg.spellid or dmg.spellid
		local spell = player.damagetakenspells and player.damagetakenspells[spellid]
		if not spell then
			player.damagetakenspells = player.damagetakenspells or {}
			spell = {id = dmg.spellid, school = dmg.spellschool, amount = 0}
			player.damagetakenspells[spellid] = spell
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
			spell.c_num = (spell.c_num or 0) + 1
			spell.c_amt = (spell.c_amt or 0) + dmg.amount

			if not spell.c_max or dmg.amount > spell.c_max then
				spell.c_max = dmg.amount
			end

			if not spell.c_min or dmg.amount < spell.c_min then
				spell.c_min = dmg.amount
			end
		elseif dmg.misstype ~= nil and missTypes[dmg.misstype] then
			spell[missTypes[dmg.misstype]] = (spell[missTypes[dmg.misstype]] or 0) + 1
		elseif dmg.glancing then
			spell.g_num = (spell.g_num or 0) + 1
			spell.g_amt = (spell.g_amt or 0) + dmg.amount
			if not spell.g_max or dmg.amount > spell.g_max then
				spell.g_max = dmg.amount
			end
			if not spell.g_min or dmg.amount < spell.g_min then
				spell.g_min = dmg.amount
			end
		elseif dmg.crushing then
			spell.crushing = (spell.crushing or 0) + 1
		elseif not dmg.misstype then
			spell.n_num = (spell.n_num or 0) + 1
			spell.n_amt = (spell.n_amt or 0) + dmg.amount
			if not spell.n_max or dmg.amount > spell.n_max then
				spell.n_max = dmg.amount
			end
			if not spell.n_min or dmg.amount < spell.n_min then
				spell.n_min = dmg.amount
			end
		end

		if dmg.blocked and dmg.blocked > 0 then
			spell.b_amt = (spell.b_amt or 0) + dmg.blocked
		end

		if dmg.resisted and dmg.resisted > 0 then
			spell.r_amt = (spell.r_amt or 0) + dmg.resisted
		end

		local overkill = (dmg.overkill and dmg.overkill > 0) and dmg.overkill or nil
		if overkill then
			spell.o_amt = (spell.o_amt or 0) + dmg.overkill
		end

		-- record the source
		if not dmg.srcName then return end
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

		if overkill then
			source.o_amt = (source.o_amt or 0) + dmg.overkill
		end
	end

	local dmg = {}
	local extraATT

	local function spell_damage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			-- handle extra attacks
			if eventtype == "SPELL_EXTRA_ATTACKS" then
				local spellid, _, _, amount = ...

				if spellid and not ignoredSpells[spellid] then
					extraATT = extraATT or T.get("Damage_ExtraAttacks")
					if not extraATT[srcName] then
						extraATT[srcName] = new()
						extraATT[srcName].proc = spellid
						extraATT[srcName].count = amount
						extraATT[srcName].time = Skada.current.last_time or GetTime()
					end
				end

				return
			end

			if eventtype == "SWING_DAMAGE" then
				dmg.spellid, _, dmg.spellschool = 6603, L["Melee"], 0x01
				dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing, dmg.crushing = ...

				-- an extra attack?
				if extraATT and extraATT[srcName] then
					local curtime = Skada.current.last_time or GetTime()
					if not extraATT[srcName].spellid then -- queue spell
						extraATT[srcName].spellid = dmg.spellid
					elseif dmg.spellid == 6603 and extraATT[srcName].time < (curtime - 5) then -- expired proc
						extraATT[srcName] = del(extraATT[srcName])
					elseif dmg.spellid == 6603 then -- valid damage contribution
						dmg.spellid = extraATT[srcName].proc
						extraATT[srcName].count = max(0, extraATT[srcName].count - 1)
						if extraATT[srcName].count == 0 then -- no procs left
							extraATT[srcName] = del(extraATT[srcName])
						end
					end
				end
			else
				dmg.spellid, _, dmg.spellschool, dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing, dmg.crushing = ...
			end

			if dmg.spellid and not ignoredSpells[dmg.spellid] then
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

	local function environment_damage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local envtype, amount = ...
		local spellid, spellschool = nil, 0x01

		if envtype == "Falling" or envtype == "FALLING" then
			spellid = 3
		elseif envtype == "Drowning" or envtype == "DROWNING" then
			spellid = 4
		elseif envtype == "Fatigue" or envtype == "FATIGUE" then
			spellid = 5
		elseif envtype == "Fire" or envtype == "FIRE" then
			spellid, spellschool = 6, 0x04
		elseif envtype == "Lava" or envtype == "LAVA" then
			spellid, spellschool = 7, 0x04
		elseif envtype == "Slime" or envtype == "SLIME" then
			spellid, spellschool = 8, 0x08
		end

		if spellid then
			spell_damage(nil, nil, nil, L["Environment"], nil, dstGUID, dstName, dstFlags, spellid, nil, spellschool, amount)
		end
	end

	local function spell_missed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local amount

			if eventtype == "SWING_MISSED" then
				dmg.spellid, _, dmg.spellschool = 6603, L["Melee"], 0x01
				dmg.misstype, amount = ...
			else
				dmg.spellid, _, dmg.spellschool, dmg.misstype, amount = ...
			end

			if dmg.spellid and not ignoredSpells[dmg.spellid] then
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
		if not actor then return end

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

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local spell = (actor and not enemy) and actor.damagetakenspells and actor.damagetakenspells[label]
		if not spell then return end

		tooltip:AddLine(label .. " - " .. actor.name)
		if spell.school and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		if spell.n_min then
			local spellmin = spell.n_min
			if spell.c_min and spell.c_min < spellmin then
				spellmin = spell.c_min
			end
			tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
		end

		if spell.n_max then
			local spellmax = spell.n_max
			if spell.c_max and spell.c_max > spellmax then
				spellmax = spell.c_max
			end
			tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spellmax), 1, 1, 1)
		end

		if spell.count then
			local amount = P.absdamage and spell.total or spell.amount
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(amount / spell.count), 1, 1, 1)
		end
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] or label == L["Glancing"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetPlayer(win.actorid, win.actorname)
			local spell = actor and actor.damagetakenspells and actor.damagetakenspells[win.spellid]
			if not spell then return end

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
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["Damage taken by %s"], label)
	end

	function playermod:Update(win, set)
		win.title = pformat(L["Damage taken by %s"], win.actorname)
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamageTaken() or 0

		if total == 0 or not actor.damagetakenspells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDTPS and actor:GetTime(), 0
		for spellid, spell in pairs(actor.damagetakenspells) do
			nr = nr + 1
			local d = win:spell(nr, spellid, spell)

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

	function sourcemod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's damage sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = pformat(L["%s's damage sources"], win.actorname)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local sources, total = actor:GetDamageSources()

		if not sources or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local actortime, nr = mod.metadata.columns.sDTPS and actor:GetTime(), 0
		for sourcename, source in pairs(sources) do
			nr = nr + 1
			local d = win:actor(nr, source, true, sourcename)

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
		win.title = pformat("%s: %s", win.actorname, format(L["%s's damage breakdown"], label))
	end

	function spellmod:Update(win, set)
		win.title = pformat("%s: %s", win.actorname, pformat(L["%s's damage breakdown"], win.spellname))
		if not set or not win.spellid then return end

		-- details only available for players
		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagetakenspells and actor.damagetakenspells[win.spellid]

		if not spell then
			return
		elseif win.metadata then
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

			if spell.n_num and spell.n_num > 0 then
				nr = add_detail_bar(win, nr, L["Normal Hits"], spell.n_num, spell.count, true)
			end

			if spell.c_num and spell.c_num > 0 then
				nr = add_detail_bar(win, nr, L["Critical Hits"], spell.c_num, spell.count, true)
			end

			if spell.g_num and spell.g_num > 0 then
				nr = add_detail_bar(win, nr, L["Glancing"], spell.g_num, spell.count, true)
			end

			if spell.crushing and spell.crushing > 0 then
				nr = add_detail_bar(win, nr, L["Crushing"], spell.crushing, spell.count, true)
			end

			for k, v in pairs(missTypes) do
				if spell[v] then
					nr = add_detail_bar(win, nr, L[k], spell[v], spell.count, true)
				end
			end
		end
	end

	function sdetailmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = pformat("%s: %s", win.actorname, format(L["Damage from %s"], label))
	end

	function sdetailmod:Update(win, set)
		win.title = pformat("%s: %s", win.actorname, pformat(L["Damage from %s"], win.spellname))
		if not set or not win.spellid then return end

		-- only available for players
		local actor = set:GetPlayer(win.actorid, win.actorname)
		local spell = actor and actor.damagetakenspells and actor.damagetakenspells[win.spellid]
		if not spell then return end

		local absorbed = spell.total and (spell.total - spell.amount) or 0
		local blocked = spell.b_amt or 0
		local resisted = spell.r_amt or 0
		local total = spell.amount + absorbed + blocked + resisted
		if win.metadata then
			win.metadata.maxvalue = total
		end

		local nr = add_detail_bar(win, 0, L["Total"], total, nil, nil, true)
		win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

		if total ~= spell.amount then
			nr = add_detail_bar(win, nr, L["Damage"], spell.amount, total, true, true)
		end

		if spell.o_amt and spell.o_amt > 0 then
			nr = add_detail_bar(win, nr, L["Overkill"], spell.o_amt, total, true, true)
		end

		if absorbed > 0 then
			nr = add_detail_bar(win, nr, L["ABSORB"], absorbed, total, true, true)
		end

		if spell.b_amt and spell.b_amt > 0 then
			nr = add_detail_bar(win, nr, L["BLOCK"], spell.b_amt, total, true, true)
		end

		if spell.r_amt and spell.r_amt > 0 then
			nr = add_detail_bar(win, nr, L["RESIST"], spell.r_amt, total, true, true)
		end

		if spell.g_amt and spell.g_amt > 0 then
			nr = add_detail_bar(win, nr, L["Glancing"], spell.g_amt, total, true, true)
		end
	end

	function tdetailmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor damage"](label, win.actorname or L["Unknown"])
	end

	function tdetailmod:Update(win, set)
		win.title = L["actor damage"](win.targetname or L["Unknown"], win.actorname or L["Unknown"])
		if not set or not win.targetname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local sources = actor and actor:GetDamageSources()
		if sources and sources[win.targetname] then
			local total = sources[win.targetname].amount or 0
			if P.absdamage and sources[win.targetname].total then
				total = sources[win.targetname].total
			end

			if total == 0 then
				return
			elseif win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDTPS and actor:GetTime(), 0
			for spellid, spell in pairs(actor.damagetakenspells) do
				if spell.sources and spell.sources[win.targetname] then
					nr = nr + 1
					local d = win:spell(nr, spellid, spell)

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

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Damage Taken"], L[win.class]) or L["Damage Taken"]

		local total = set and set:GetDamageTaken() or 0

		if total == 0 then
			return
		elseif win.metadata then
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
					local d = win:actor(nr, player)

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
		if not (Skada.forPVP and set.type == "arena" and set.enemies) then return end
		for i = 1, #set.enemies do
			local enemy = set.enemies[i]
			if enemy and not enemy.fake and (not win.class or win.class == enemy.class) then
				local dtps, amount = enemy:GetDTPS()
				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, enemy, true)
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
			spell_damage,
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
			environment_damage,
			"ENVIRONMENTAL_DAMAGE",
			flags_dst
		)

		Skada:RegisterForCL(
			spell_missed,
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
			if p and (p.totaldamagetaken == 0 or (not p.totaldamagetaken and p.damagetakenspells)) then
				p.damagetaken, p.totaldamagetaken = nil, nil
				p.damagetakenspells = del(p.damagetakenspells, true)
			end
		end
	end
end)

-- ============================== --
-- Damage taken per second module --
-- ============================== --

Skada:RegisterModule("DTPS", function(L, P)
	local mod = Skada:NewModule("DTPS")

	local function dtps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

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

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["DTPS"], L[win.class]) or L["DTPS"]

		local total = set and set:GetDTPS() or 0

		if total == 0 then
			return
		elseif win.metadata then
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
					local d = win:actor(nr, player)

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
		if not (Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyDamageTaken) then return end
		for i = 1, #set.enemies do
			local enemy = set.enemies[i]
			if enemy and not enemy.fake and (not win.class or win.class == enemy.class) then
				local dtps = enemy:GetDTPS()
				if dtps > 0 then
					nr = nr + 1
					local d = win:actor(nr, enemy, true)
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
		if parentmod and parentmod.metadata then
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
end, "Damage Taken")

-- ============================ --
-- Damage Taken By Spell Module --
-- ============================ --

Skada:RegisterModule("Damage Taken By Spell", function(L, P, _, _, new, _, clear)
	local mod = Skada:NewModule("Damage Taken By Spell")
	local targetmod = mod:NewModule("Damage spell targets")
	local sourcemod = mod:NewModule("Damage spell sources")
	local C = Skada.cacheTable2

	local function player_tooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local player = set and set:GetActor(label, id)
		local spell = player and player.damagetakenspells and player.damagetakenspells[win.spellid]
		if not spell or not spell.count then return end

		tooltip:AddLine(label .. " - " .. win.spellname)

		tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
		local diff = spell.count -- used later

		if spell.n_num then
			tooltip:AddDoubleLine(L["Normal Hits"], Skada:FormatPercent(spell.n_num, spell.count), 1, 1, 1)
			diff = diff - spell.n_num
		end

		if spell.c_num then
			tooltip:AddDoubleLine(L["Critical Hits"], Skada:FormatPercent(spell.c_num, spell.count), 1, 1, 1)
			diff = diff - spell.c_num
		end

		if spell.g_num then
			tooltip:AddDoubleLine(L["Glancing"], Skada:FormatPercent(spell.g_num, spell.count), 1, 1, 1)
			diff = diff - spell.g_num
		end

		if diff > 0 then
			tooltip:AddDoubleLine(L["Other"], Skada:FormatPercent(diff, spell.count), nil, nil, nil, 1, 1, 1)
		end
	end

	function sourcemod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function sourcemod:Update(win, set)
		win.title = pformat(L["%s's sources"], win.spellname)
		if not win.spellid then return end

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

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for sourcename, source in pairs(sources) do
			nr = nr + 1
			local d = win:actor(nr, source, true, sourcename)

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

	function targetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's targets"], win.spellname)
		if not win.spellid then return end

		local targets, total = clear(C), 0
		for i = 1, #set.players do
			local player = set.players[i]
			local spell = player and player.damagetakenspells and player.damagetakenspells[win.spellid]
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

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for playername, player in pairs(targets) do
			nr = nr + 1
			local d = win:actor(nr, player, nil, playername)

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

	function mod:Update(win, set)
		win.title = L["Damage Taken By Spell"]
		local total = set and set:GetDamageTaken() or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local spells = clear(C)
		for i = 1, #set.players do
			local player = set.players[i]
			if player and player.damagetakenspells then
				for spellid, spell in pairs(player.damagetakenspells) do
					local amount = P.absdamage and spell.total or spell.amount or 0
					if amount > 0 then
						if not spells[spellid] then
							spells[spellid] = new()
							spells[spellid].id = spell.id
							spells[spellid].school = spell.school
							spells[spellid].amount = amount
						else
							spells[spellid].amount = spells[spellid].amount + amount
						end
					end
				end
			end
		end

		local settime, nr = self.metadata.columns.DTPS and set:GetTime(), 0
		for spellid, spell in pairs(spells) do
			nr = nr + 1
			local d = win:spell(nr, spellid, spell)

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
end, "Damage Taken")

-- ============================= --
-- Avoidance & Mitigation Module --
-- ============================= --

Skada:RegisterModule("Avoidance & Mitigation", function(L, _, _, _, new, del, clear)
	local mod = Skada:NewModule("Avoidance & Mitigation")
	local playermod = mod:NewModule("Damage Breakdown")
	local missTypes = Skada.missTypes
	local C = Skada.cacheTable2

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

							for k, v in pairs(missTypes) do
								if spell[v] then
									avoid = avoid + spell[v]
									tmp.data = tmp.data or new()
									tmp.data[k] = (tmp.data[k] or 0) + spell[v]
								end
							end
						end

						if avoid > 0 then
							tmp.total = total
							tmp.avoid = avoid
							C[player.id] = tmp

							nr = nr + 1
							local d = win:actor(nr, player)

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
end, "Damage Taken")
