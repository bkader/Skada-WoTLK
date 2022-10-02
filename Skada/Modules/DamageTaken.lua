local _, Skada = ...
local private = Skada.private

-- cache frequently used globals
local pairs, min, max = pairs, math.min, math.max
local format, uformat, T = string.format, private.uformat, Skada.Table
local new, del, clear = private.newTable, private.delTable, private.clearTable

local function format_valuetext(d, columns, total, dtps, metadata, subview)
	d.valuetext = Skada:FormatValueCols(
		columns.Damage and Skada:FormatNumber(d.value),
		columns[subview and "sDTPS" or "DTPS"] and dtps and Skada:FormatNumber(dtps),
		columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
	)

	if metadata and d.value > metadata.maxvalue then
		metadata.maxvalue = d.value
	end
end

-- =================== --
-- Damage Taken Module --
-- =================== --

Skada:RegisterModule("Damage Taken", function(L, P)
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
	local mod_cols = nil

	local dmg = {}
	local function log_damage(set, isdot)
		local player = Skada:GetPlayer(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if not player then return end

		player.damaged = (player.damaged or 0) + dmg.amount
		player.totaldamaged = (player.totaldamaged or 0) + dmg.amount

		set.damaged = (set.damaged or 0) + dmg.amount
		set.totaldamaged = (set.totaldamaged or 0) + dmg.amount

		-- add absorbed damage to total damage
		local absorbed = dmg.absorbed or 0
		if absorbed > 0 then
			player.totaldamaged = player.totaldamaged + absorbed
			set.totaldamaged = set.totaldamaged + absorbed
		end

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		local spellid = isdot and -dmg.spellid or dmg.spellid
		local spell = player.damagedspells and player.damagedspells[spellid]
		if not spell then
			player.damagedspells = player.damagedspells or {}
			spell = {id = spellid, school = dmg.school, amount = 0}
			player.damagedspells[spellid] = spell
		elseif not spell.school and dmg.school then
			spell.school = dmg.school
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
			source.o_amt = (source.o_amt or 0) + overkill
		end
	end

	local extraATT = nil
	local function spell_damage(_, eventtype, srcGUID, srcName, _, dstGUID, dstName, dstFlags, ...)
		if srcGUID == dstGUID then return end

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
			dmg.spellid, _, dmg.school = 6603, L["Melee"], 0x01
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
			dmg.spellid, _, dmg.school, dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing, dmg.crushing = ...
		end

		if dmg.spellid and not ignoredSpells[dmg.spellid] then
			dmg.srcName = srcName
			dmg.playerid = dstGUID
			dmg.playername = dstName
			dmg.playerflags = dstFlags
			dmg.misstype = nil

			Skada:DispatchSets(log_damage, eventtype == "SPELL_PERIODIC_DAMAGE")
		end
	end

	local function environment_damage(_, _, _, _, _, dstGUID, dstName, dstFlags, envtype, amount)
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

	local function spell_missed(_, eventtype, srcGUID, srcName, _, dstGUID, dstName, dstFlags, ...)
		if srcGUID == dstGUID then return end

		local amount

		if eventtype == "SWING_MISSED" then
			dmg.spellid, _, dmg.school = 6603, L["Melee"], 0x01
			dmg.misstype, amount = ...
		else
			dmg.spellid, _, dmg.school, dmg.misstype, amount = ...
		end

		if dmg.spellid and not ignoredSpells[dmg.spellid] then
			dmg.srcName = srcName
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

			if dmg.misstype == "ABSORB" and amount then
				dmg.absorbed = amount
			elseif dmg.misstype == "BLOCK" and amount then
				dmg.blocked = amount
			elseif dmg.misstype == "RESIST" and amount then
				dmg.resisted = amount
			end

			Skada:DispatchSets(log_damage, eventtype == "SPELL_PERIODIC_MISSED")
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

		local spell = nil
		if actor and not enemy then
			spell = actor.damagedspells and actor.damagedspells[label]
			spell = spell or actor.damagetakenspells and actor.damagetakenspells[label]
		end
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
			if not actor then return end

			local spell = actor.damagedspells and actor.damagedspells[win.spellid]
			spell = spell or actor.damagetakenspells and actor.damagetakenspells[win.spellid]
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
		win.title = uformat(L["Damage taken by %s"], win.actorname)
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamageTaken()
		local spells = (total and total > 0) and actor.damagedspells or actor.damagetakenspells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDTPS and actor:GetTime()

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = min(total, P.absdamage and spell.total or spell.amount)
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function sourcemod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's damage sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = uformat(L["%s's damage sources"], win.actorname)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local sources, total = actor:GetDamageSources()
		if not sources or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDTPS and actor:GetTime()

		for sourcename, source in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, source, true, sourcename)
			d.value = P.absdamage and source.total or source.amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	local function add_detail_bar(win, nr, title, value, total, percent, fmt)
		nr = nr + 1

		local d = win:nr(nr)
		d.id = title
		d.label = title
		d.value = value
		format_valuetext(d, mod.metadata.columns, total, nil, win.metadata, true)

		return nr
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat("%s: %s", win.actorname, format(L["%s's damage breakdown"], label))
	end

	function spellmod:Update(win, set)
		win.title = uformat("%s: %s", win.actorname, uformat(L["%s's damage breakdown"], win.spellname))
		if not set or not win.spellid then return end

		-- details only available for players
		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local spell = actor.damagedspells and actor.damagedspells[win.spellid]
		spell = spell or actor.damagetakenspells and actor.damagetakenspells[win.spellid]

		if not spell then
			return
		elseif win.metadata then
			win.metadata.maxvalue = enemy and (P.absdamage and spell.total or spell.amount or 0) or spell.count
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
				if spell[v] or spell[k] then
					nr = add_detail_bar(win, nr, L[k], spell[v] or spell[k], spell.count, true)
				end
			end
		end
	end

	function sdetailmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat("%s: %s", win.actorname, format(L["Damage from %s"], label))
	end

	function sdetailmod:Update(win, set)
		win.title = uformat("%s: %s", win.actorname, uformat(L["Damage from %s"], win.spellname))
		if not set or not win.spellid then return end

		-- only available for players
		local actor = set:GetPlayer(win.actorid, win.actorname)
		if not actor then return end

		local spell = actor.damagedspells and actor.damagedspells[win.spellid]
		spell = spell or actor.damagetakenspells and actor.damagetakenspells[win.spellid]
		if not spell then return end

		local total = spell.amount

		local absorbed = spell.total and (spell.total - spell.amount)
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

		if win.metadata then
			win.metadata.maxvalue = total
		end

		local nr = add_detail_bar(win, 0, L["Total"], total, nil, nil, true)
		win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

		if total ~= spell.amount then
			nr = add_detail_bar(win, nr, L["Damage"], spell.amount, total, true, true)
		end

		local overkill = spell.o_amt or spell.overkill
		if overkill and overkill > 0 then
			nr = add_detail_bar(win, nr, L["Overkill"], overkill, total, true, true)
		end

		if absorbed and absorbed > 0 then
			nr = add_detail_bar(win, nr, L["ABSORB"], absorbed, total, true, true)
		end

		if blocked and blocked > 0 then
			nr = add_detail_bar(win, nr, L["BLOCK"], blocked, total, true, true)
		end

		if resisted and resisted > 0 then
			nr = add_detail_bar(win, nr, L["RESIST"], resisted, total, true, true)
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
		if not sources or not sources[win.targetname] then return end

		local total = P.absdamage and sources[win.targetname].total or sources[win.targetname].amount
		local spells = (total and total > 0) and (actor.damagedspells or actor.damagetakenspells)
		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDTPS and actor:GetTime()

		for spellid, spell in pairs(spells) do
			local source = spell.sources and spell.sources[win.targetname]
			local amount = source and (P.absdamage and source.total or source.amount)
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellid, spell)
				d.value = amount
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Damage Taken"], L[win.class]) or L["Damage Taken"]

		local total = set and set:GetDamageTaken(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players.
		for i = 1, #actors do
			local actor = actors[i]
			if actor and (not win.class or win.class == actor.class) then
				local dtps, amount = actor:GetDTPS(not mod_cols.DTPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor)
					d.color = set.__arena and Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN") or nil
					d.value = amount
					format_valuetext(d, mod_cols, total, dtps, win.metadata)
				end
			end
		end

		actors = set.__arena and set.enemies or nil -- arena enemies
		if not actors then return end

		for i = 1, #actors do
			local actor = actors[i]
			if actor and not actor.fake and (not win.class or win.class == actor.class) then
				local dtps, amount = actor:GetDTPS(not mod_cols.DTPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")
					d.value = amount
					format_valuetext(d, mod_cols, total, dtps, win.metadata)
				end
			end
		end
	end

	function mod:GetSetSummary(set, win)
		local dtps, amount = set:GetDTPS(win and win.class)
		local valuetext = Skada:FormatValueCols(
			mod_cols.Damage and Skada:FormatNumber(amount),
			mod_cols.DTPS and Skada:FormatNumber(dtps)
		)
		return amount, valuetext
	end

	function mod:AddToTooltip(set, tooltip)
		if not set then return end
		local dtps, amount = set:GetDTPS()
		tooltip:AddDoubleLine(L["Damage Taken"], Skada:FormatNumber(amount), 1, 1, 1)
		tooltip:AddDoubleLine(L["DTPS"], Skada:FormatNumber(dtps), 1, 1, 1)
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

		mod_cols = self.metadata.columns

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
		if Skada.ignoredSpells and Skada.ignoredSpells.damaged then
			ignoredSpells = Skada.ignoredSpells.damaged
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:CombatLeave()
		T.clear(dmg)
		T.free("Damage_ExtraAttacks", extraATT, nil, del)
	end

	function mod:SetComplete(set)
		-- clean set from garbage before it is saved.
		if not set.totaldamaged or set.totaldamaged == 0 then return end
		for i = 1, #set.players do
			local p = set.players[i]
			if p and (p.totaldamaged == 0 or (not p.totaldamaged and (p.damagedspells or p.damagetakenspells))) then
				p.damaged, p.totaldamaged = nil, nil
				p.damagedspells = del(p.damagedspells or p.damagetakenspells, true)
			end
		end
	end
end)

-- ============================== --
-- Damage taken per second module --
-- ============================== --

Skada:RegisterModule("DTPS", function(L, P)
	local mod = Skada:NewModule("DTPS")
	local mod_cols = nil

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

		local total = set and set:GetDTPS(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and (not win.class or win.class == actor.class) then
				local dtps = actor:GetDTPS()
				if dtps > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor)
					d.color = set.__arena and Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN") or nil
					d.value = dtps
					format_valuetext(d, mod_cols, total, dtps, win.metadata)
				end
			end
		end

		actors = set.__arena and set.enemies or nil -- arena enemies
		if not actors then return end

		for i = 1, #actors do
			local actor = actors[i]
			if actor and not actor.fake and (not win.class or win.class == actor.class) then
				local dtps = actor:GetDTPS()
				if dtps > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")
					d.value = dtps
					format_valuetext(d, mod_cols, total, dtps, win.metadata)
				end
			end
		end
	end

	function mod:GetSetSummary(set, win)
		local dtps = set:GetDTPS(win and win.class)
		return dtps, Skada:FormatNumber(dtps)
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

		mod_cols = self.metadata.columns

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
end, "Damage Taken")

-- ============================ --
-- Damage Taken By Spell Module --
-- ============================ --

Skada:RegisterModule("Damage Taken By Spell", function(L, P)
	local mod = Skada:NewModule("Damage Taken By Spell")
	local targetmod = mod:NewModule("Damage spell targets")
	local sourcemod = mod:NewModule("Damage spell sources")
	local C = Skada.cacheTable2
	local mod_cols = nil

	local function player_tooltip(win, id, label, tooltip)
		local set = win.spellid and win:GetSelectedSet()
		local player = set and set:GetActor(label, id)
		if not player then return end

		local spell = player.damagedspells and player.damagedspells[win.spellid]
		spell = spell or player.damagetakenspells and player.damagetakenspells[win.spellid]
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
		win.title = uformat(L["%s's sources"], win.spellname)
		if not win.spellid then return end

		local total = 0
		local sources = clear(C)
		local players = set.players
		for i = 1, #players do
			local player = players[i]
			local spell = player and player.damagedspells and player.damagedspells[win.spellid]
			spell = spell or player and player.damagetakenspells and player.damagetakenspells[win.spellid]

			if spell and spell.sources then
				for sourcename, source in pairs(spell.sources) do
					local amount = P.absdamage and source.total or source.amount or 0
					if amount > 0 then
						local src = sources[sourcename]
						if not src then
							src = new()
							src.amount = amount
							sources[sourcename] = src
						else
							src.amount = src.amount + amount
						end

						total = total + amount

						if not src.class or (mod_cols.sDTPS and not src.time) then
							local actor = set:GetActor(sourcename)
							if actor and not src.class then
								src.id = actor.id or actor.name
								src.class = actor.class
								src.role = actor.role
								src.spec = actor.spec
							end
							if actor and mod_cols.sDTPS and not src.time then
								src.time = set:GetActorTime(actor.id, actor.name)
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
			format_valuetext(d, mod_cols, total, source.time and (d.value / source.time), win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's targets"], win.spellname)
		if not win.spellid then return end

		local total = 0
		local targets = clear(C)

		local players = set.players
		for i = 1, #players do
			local player = players[i]
			local spell = player and player.damagedspells and player.damagedspells[win.spellid]
			spell = spell or player.damagetakenspells and player.damagetakenspells[win.spellid]
			if spell then
				local amount = P.absdamage and spell.total or spell.amount or 0
				if amount > 0 then
					targets[player.name] = new()
					targets[player.name].id = player.id
					targets[player.name].class = player.class
					targets[player.name].role = player.role
					targets[player.name].spec = player.spec
					targets[player.name].amount = amount
					targets[player.name].time = mod_cols.sDTPS and player:GetTime()

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
			format_valuetext(d, mod_cols, total, player.time and (d.value / player.time), win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = L["Damage Taken By Spell"]

		local total = set and set:GetDamageTaken()
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local spells = clear(C)
		for i = 1, #set.players do
			local player = set.players[i]
			local _spells = player and (player.damagedspells or player.damagetakenspells)
			if _spells then
				for spellid, spell in pairs(_spells) do
					local amount = P.absdamage and spell.total or spell.amount or 0
					if amount > 0 then
						local sp = spells[spellid]
						if not sp then
							sp = new()
							sp.id = spell.id
							sp.school = spell.school
							sp.amount = amount
							spells[spellid] = sp
						else
							sp.amount = sp.amount + amount
						end
					end
				end
			end
		end

		local nr = 0
		local settime = mod_cols.DTPS and set:GetTime()

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid, spell)
			d.value = spell.amount
			format_valuetext(d, mod_cols, total, settime and (d.value / settime), win.metadata)
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

		mod_cols = self.metadata.columns

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Damage Taken")

-- ============================= --
-- Avoidance & Mitigation Module --
-- ============================= --

Skada:RegisterModule("Avoidance & Mitigation", function(L)
	local mod = Skada:NewModule("Avoidance & Mitigation")
	local playermod = mod:NewModule("Damage Breakdown")
	local missTypes = Skada.missTypes
	local C = Skada.cacheTable2
	local mod_cols = nil

	local function fmt_valuetext(d, columns, total, count, metadata)
		d.valuetext = Skada:FormatValueCols(
			columns.Percent and Skada:FormatPercent(d.value),
			columns.Count and count and Skada:FormatNumber(count),
			columns.Total and Skada:FormatNumber(total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
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
				fmt_valuetext(d, mod_cols, actor.total, count, win.metadata)
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Avoidance & Mitigation"], L[win.class]) or L["Avoidance & Mitigation"]

		local total = set and (set.totaldamaged or set.totaldamagetaken)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		clear(C, true) -- used later

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local player = actors[i]
			if player and (not win.class or win.class == player.class) then
				local spells = player.damagedspells or player.damagetakenspells
				if spells then
					local tmp = new()
					tmp.name = player.name

					local count, avoid = 0, 0
					for _, spell in pairs(spells) do
						count = count + spell.count

						for k, v in pairs(missTypes) do
							local num = spell[v] or spell[k]
							if num then
								avoid = avoid + num
								tmp.data = tmp.data or new()
								tmp.data[k] = (tmp.data[k] or 0) + num
							end
						end
					end

					if avoid > 0 then
						tmp.total = count
						tmp.avoid = avoid
						C[player.id] = tmp

						nr = nr + 1
						local d = win:actor(nr, player)

						d.value = 100 * avoid / count
						fmt_valuetext(d, mod_cols, count, avoid, win.metadata)
					elseif C[player.id] then
						C[player.id] = del(C[player.id])
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

		mod_cols = self.metadata.columns

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Damage Taken")
