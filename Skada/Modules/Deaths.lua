local _, Skada = ...
local private = Skada.private
Skada:RegisterModule("Deaths", function(L, P, _, _, M)
	local mod = Skada:NewModule("Deaths")
	local playermod = mod:NewModule("Player's deaths")
	local deathlogmod = mod:NewModule("Death log")
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local WATCH = nil -- true to watch those alive

	local tinsert, tremove, tsort, tconcat = table.insert, table.remove, table.sort, table.concat
	local strmatch, format, pformat = strmatch, string.format, Skada.pformat
	local max, floor, wipe = math.max, math.floor, wipe
	local new, del = Skada.newTable, Skada.delTable
	local UnitHealthInfo = Skada.UnitHealthInfo
	local UnitIsFeignDeath = UnitIsFeignDeath
	local GetSpellInfo = private.spell_info or GetSpellInfo
	local GetSpellLink = private.spell_link or GetSpellLink
	local IsInGroup, IsInPvP = Skada.IsInGroup, Skada.IsInPvP
	local GetTime, time, date = GetTime, time, date
	local mod_cols, submod_cols = nil, nil

	-- cache colors
	local GRAY_COLOR = GREEN_FONT_COLOR
	local GREEN_COLOR = GREEN_FONT_COLOR
	local ORANGE_COLOR = ORANGE_FONT_COLOR
	local RED_COLOR = RED_FONT_COLOR
	local YELLOW_COLOR = YELLOW_FONT_COLOR
	local PURPLE_COLOR = {r = 0.69, g = 0.38, b = 1}
	local icon_death = [[Interface\Icons\Spell_Shadow_Soulleech_1]]

	local function get_color(key)
		if P.usecustomcolors and P.customcolors and P.customcolors["deathlog_" .. key] then
			return P.customcolors["deathlog_" .. key]
		elseif key == "orange" then
			return ORANGE_COLOR
		elseif key == "yellow" then
			return YELLOW_COLOR
		elseif key == "green" then
			return GREEN_COLOR
		elseif key == "purple" then
			return PURPLE_COLOR
		else
			return RED_COLOR
		end
	end

	local data = {}
	local function log_deathlog(set, override)
		if not set or (set == Skada.total and not P.totalidc) then return end

		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if not player then return end

		local deathlog = player.deathlog and player.deathlog[1]
		if not deathlog or (deathlog.timeod and not override) then
			deathlog = {log = new()}
			player.deathlog = player.deathlog or {}
			tinsert(player.deathlog, 1, deathlog)
		end

		-- seet player maxhp if not already set
		if not deathlog.hpm or deathlog.hpm == 0 then
			_, _, deathlog.hpm = UnitHealthInfo(player.name, player.id, "group")
			deathlog.hpm = deathlog.hpm or 0
		end

		local log = new()
		log.id = data.spellid
		log.sch = data.school
		log.src = data.srcName
		log.cri = data.critical
		log.time = set.last_time or GetTime()
		_, log.hp = UnitHealthInfo(player.name, player.id, "group")

		if data.amount then
			deathlog.time = log.time
			log.deb = nil

			if data.amount == true then -- instakill
				log.amt = -log.hp
				deathlog.id = log.id
				deathlog.sch = log.sch
				deathlog.src = log.src
			elseif data.amount ~= 0 then
				log.amt = data.amount

				if log.amt < 0 then
					deathlog.id = log.id
					deathlog.sch = log.sch
					deathlog.src = log.src
				end
			end
		elseif data.debuff then
			log.deb = 1
		end

		if data.overheal and data.overheal > 0 then
			log.ovh = data.overheal
		end
		if data.overkill and data.overkill > 0 then
			log.ovk = data.overkill
		end
		if data.resisted and data.resisted > 0 then
			log.res = data.resisted
		end
		if data.blocked and data.blocked > 0 then
			log.blo = data.blocked
		end
		if data.absorbed and data.absorbed > 0 then
			log.abs = data.absorbed
		end

		tinsert(deathlog.log, 1, log)

		-- trim things and limit to deathlogevents (defaul: 14)
		while #deathlog.log > (M.deathlogevents or 14) do
			del(tremove(deathlog.log))
		end
	end

	local function spell_damage(_, event, _, srcName, _, dstGUID, dstName, dstFlags, ...)
		if event == "SWING_DAMAGE" then
			data.spellid, data.school = 6603, 0x01
			data.amount, data.overkill, _, data.resisted, data.blocked, data.absorbed, data.critical = ...
			data.amount = 0 - data.amount
		elseif event == "SPELL_INSTAKILL" then
			data.spellid, _, data.school = ...
			data.amount = true
		else
			data.spellid, _, data.school, data.amount, data.overkill, _, data.resisted, data.blocked, data.absorbed, data.critical = ...
			data.amount = 0 - data.amount
		end

		if data.amount then
			data.srcName = srcName
			data.playerid = dstGUID
			data.playername = dstName
			data.playerflags = dstFlags

			data.overheal = nil

			Skada:DispatchSets(log_deathlog)
		end
	end

	local missTypes = {RESIST = true, BLOCK = true, ABSORB = true}
	local function spell_missed(_, event, _, srcName, _, dstGUID, dstName, dstFlags, ...)
		local misstype, amount

		if event == "SWING_MISSED" then
			data.spellid, data.school = 6603, 0x01
			misstype, amount = ...
		else
			data.spellid, _, data.school, misstype, amount = ...
		end

		if amount and amount > 0 and misstype and missTypes[misstype] then
			data.srcName = srcName
			data.playerid = dstGUID
			data.playername = dstName
			data.playerflags = dstFlags

			data.amount = nil
			data.overkill = nil
			data.overheal = nil
			data.critical = nil
			data.debuff = nil

			if misstype == "RESIST" then
				data.resisted = amount
				data.blocked = nil
				data.absorbed = nil
			elseif misstype == "BLOCK" then
				data.resisted = nil
				data.blocked = amount
				data.absorbed = nil
			elseif misstype == "ABSORB" then
				data.resisted = nil
				data.blocked = nil
				data.absorbed = amount
			end

			Skada:DispatchSets(log_deathlog)
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

	local function spell_heal(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, _, amount, overheal)
		if spellid and amount and (not M.deathlogthreshold or amount > M.deathlogthreshold) then
			srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)
			dstGUID, dstName = Skada:FixMyPets(dstGUID, dstName, dstFlags)

			data.srcName = srcName

			data.playerid = dstGUID
			data.playername = dstName
			data.playerflags = dstFlags

			data.spellid = spellid
			data.amount = amount

			data.school = nil
			data.overheal = nil
			data.overkill = nil
			data.resisted = nil
			data.blocked = nil
			data.absorbed = nil
			data.critical = nil
			data.debuff = nil

			if overheal and overheal > 0 then
				data.amount = max(0, data.amount - overheal)
				data.overheal = overheal
			end

			Skada:DispatchSets(log_deathlog)
		end
	end

	local function log_death(set, playerid, playername, playerflags)
		local player = Skada:GetPlayer(set, playerid, playername, playerflags)
		if not player then return end

		set.death = (set.death or 0) + 1
		player.death = (player.death or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		local deathlog = player.deathlog and player.deathlog[1]
		if not deathlog then return end

		deathlog.time = set.last_time or GetTime()
		deathlog.timeod = set.last_action or time()

		for i = #deathlog.log, 1, -1 do
			local e = deathlog.log[i]
			if (deathlog.time - e.time) >= 60 then
				-- in certain situations, such us The Ruby Sanctum,
				-- deathlog contain old data which are irrelevant to keep.
				del(tremove(deathlog.log, i))
			else
				-- sometimes multiple close events arrive with the same timestamp
				-- so we add a small correction to ensure sort stability.
				e.time = e.time + (i * 0.001)
			end
		end

		-- no entry left? insert an unknown entry
		if #deathlog.log == 0 then
			local log = new()
			log.amt = -deathlog.hpm
			log.time = deathlog.time - 0.001
			log.hp = deathlog.hpm
			deathlog.log[#deathlog.log + 1] = log
		end

		-- announce death
		if M.deathannounce and set ~= Skada.total then
			mod:Announce(deathlog.log, player.name)
		end
	end

	local function unit_died(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags)
		if not UnitIsFeignDeath(dstName) then
			Skada:DispatchSets(log_death, dstGUID, dstName, dstFlags)
		end
	end

	local function sor_applied(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid)
		if spellid == 27827 then -- Spirit of Redemption (Holy Priest)
			Skada:ScheduleTimer(function() unit_died(nil, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags) end, 0.01)
		end
	end

	local resurrectSpells = {
		-- Rebirth
		[20484] = true,
		[20739] = true,
		[20742] = true,
		[20747] = true,
		[20748] = true,
		[26994] = true,
		[48477] = true,
		-- Reincarnation
		[16184] = true,
		[16209] = true,
		[20608] = true,
		[21169] = true,
		-- Use Soulstone
		[3026] = true,
		[20758] = true,
		[20759] = true,
		[20760] = true,
		[20761] = true,
		[27240] = true,
		[47882] = true
	}

	local function spell_resurrect(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid)
		if spellid and (event == "SPELL_RESURRECT" or resurrectSpells[spellid]) then
			data.spellid = spellid

			if event == "SPELL_RESURRECT" then
				data.srcName = srcName
				data.playerid = dstGUID
				data.playername = dstName
				data.playerflags = dstFlags
			else
				data.srcName = srcName
				data.playerid = srcGUID
				data.playername = srcName
				data.playerflags = srcFlags
			end

			data.school = nil
			data.amount = nil
			data.overkill = nil
			data.overheal = nil
			data.resisted = nil
			data.blocked = nil
			data.absorbed = nil
			data.critical = nil
			data.debuff = nil

			Skada:DispatchSets(log_deathlog, true)
		end
	end

	local function debuff_applied(_, _, _, srcName, _, dstGUID, dstName, dstFlags, spellid, _, spellschool, auratype)
		if auratype == "DEBUFF" and spellid and not ignoredSpells[spellid] then
			data.spellid = spellid
			data.school = spellschool

			data.srcName = srcName
			data.playerid = dstGUID
			data.playername = dstName
			data.playerflags = dstFlags

			data.amount = nil
			data.overkill = nil
			data.overheal = nil
			data.resisted = nil
			data.blocked = nil
			data.absorbed = nil
			data.critical = nil
			data.debuff = true

			Skada:DispatchSets(log_deathlog)
		end
	end

	function deathlogmod:Enter(win, id, label)
		if M.alternativedeaths then
			win.actorid, win.datakey = strmatch(id, "(%w+)::(%d+)")
			win.datakey = tonumber(win.datakey or 0)
			win.actorname = label
		else
			win.datakey = id
		end

		win.title = pformat(L["%s's death log"], win.actorname)
	end

	do
		local function sort_logs(a, b)
			return a and b and a.time > b.time
		end

		function deathlogmod:Update(win, set)
			win.title = pformat(L["%s's death log"], win.actorname)

			local player = win.datakey and Skada:FindPlayer(set, win.actorid, win.actorname)
			local deathlog = player and player.deathlog and player.deathlog[win.datakey]
			if not deathlog then return end

			if M.alternativedeaths then
				local num = #player.deathlog
				if win.datakey ~= num then
					win.title = format("%s (%d)", win.title, num - win.datakey + 1)
				end
			end

			if win.metadata then
				win.metadata.maxvalue = deathlog.hpm
			end

			local nr = 0

			-- 1. remove "datakey" from ended logs.
			-- 2. postfix empty table
			-- 3. add a fake entry for the actual death
			if deathlog.timeod then
				win.datakey = nil -- [1]

				if #deathlog.log == 0 then -- [2]
					local log = new()
					log.time = deathlog.time - 0.001
					if deathlog.hpm then
						log.amt = -deathlog.hpm
						log.hp = deathlog.hpm
					else
						log.amt = 0
						log.hp = 0
					end
					deathlog.log[1] = log
				end

				if win.metadata then -- [3]
					nr = nr + 1
					local d = win:nr(nr)

					d.id = nr
					d.label = date("%H:%M:%S", deathlog.timeod)
					d.icon = [[Interface\Icons\Ability_Rogue_FeignDeath]]
					d.color = nil
					d.value = 0
					d.valuetext = format(L["%s dies"], player.name)
				end
			end

			tsort(deathlog.log, sort_logs)

			local curtime = deathlog.time or set.last_time or GetTime()
			for i = #deathlog.log, 1, -1 do
				local log = deathlog.log[i]
				local diff = tonumber(log.time) - tonumber(curtime)
				if diff > -60 then
					nr = i + 1
					local d = win:nr(nr)

					local spellname
					if log.id then
						d.spellid = log.id
						spellname, _, d.icon = GetSpellInfo(log.id)
					else
						spellname = L["Unknown"]
						d.spellid = nil
						d.icon = icon_death
					end

					d.id = nr
					d.label = format("%s%02.2fs: %s", diff > 0 and "+" or "", diff, spellname)
					d.spellname = spellname

					-- used for tooltip
					d.hp = log.hp or 0
					d.amount = log.amt or 0
					d.source = log.src or L["Unknown"]
					d.value = d.hp

					if d.spellid and resurrectSpells[d.spellid] then
						d.color, d.overheal, d.overkill = nil, nil, nil
						d.resisted, d.blocked, d.absorbed = nil, nil, nil
						d.valuetext = d.source
					else
						local change, color = d.amount, get_color("red")
						if log.deb then
							change = L["debuff"]
							color = get_color("purple")
						elseif change > 0 then
							change = "+" .. Skada:FormatNumber(change)
							color = get_color("green")
						elseif change == 0 and (log.res or log.blo or log.abs) then
							change = "+" .. Skada:FormatNumber(log.res or log.blo or log.abs)
							color = get_color("orange")
						elseif log.ovh then
							change = "+" .. Skada:FormatNumber(log.ovh)
							color = get_color("yellow")
						elseif log.cri then
							change = format("%s (%s)", Skada:FormatNumber(change), L["Crit"])
						else
							change = Skada:FormatNumber(change)
						end

						if WATCH and ((d.color and d.color ~= color) or (d.spellname and d.spellname ~= spellname)) then
							d.changed = true
						elseif WATCH and d.changed then
							d.changed = nil
						end

						d.color = color

						-- only format report for ended logs
						if deathlog.timeod ~= nil then
							d.reportlabel = "%02.2fs: %s (%s)   %s [%s]"

							if P.reportlinks and log.id then
								d.reportlabel = format(d.reportlabel, diff, GetSpellLink(log.id) or spellname, d.source, change, Skada:FormatNumber(d.value))
							else
								d.reportlabel = format(d.reportlabel, diff, spellname, d.source, change, Skada:FormatNumber(d.value))
							end

							local extra = new()

							if log.ovh and log.ovh > 0 then
								d.overheal = log.ovh
								extra[#extra + 1] = "O:" .. Skada:FormatNumber(log.ovh)
							end
							if log.ovk and log.ovk > 0 then
								d.overkill = log.ovk
								extra[#extra + 1] = "O:" .. Skada:FormatNumber(log.ovk)
							end
							if log.res and log.res > 0 then
								d.resisted = log.res
								extra[#extra + 1] = "R:" .. Skada:FormatNumber(log.res)
							end
							if log.blo and log.blo > 0 then
								d.blocked = log.blo
								extra[#extra + 1] = "B:" .. Skada:FormatNumber(log.blo)
							end
							if log.abs and log.abs > 0 then
								d.absorbed = log.abs
								extra[#extra + 1] = "A:" .. Skada:FormatNumber(log.abs)
							end

							if next(extra) then
								d.reportlabel = format("%s (%s)", d.reportlabel, tconcat(extra, " - "))
							end

							extra = del(extra)
						else
							if log.ovh and log.ovh > 0 then
								d.overheal = log.ovh
							end
							if log.ovk and log.ovk > 0 then
								d.overkill = log.ovk
							end
							if log.res and log.res > 0 then
								d.resisted = log.res
							end
							if log.blo and log.blo > 0 then
								d.blocked = log.blo
							end
							if log.abs and log.abs > 0 then
								d.absorbed = log.abs
							end
						end

						d.valuetext = Skada:FormatValueCols(
							submod_cols.Change and change,
							submod_cols.Health and Skada:FormatNumber(d.value),
							submod_cols.Percent and Skada:FormatPercent(log.hp or 0, deathlog.hpm or 1)
						)
					end
				else
					del(tremove(deathlog.log, i))
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's deaths"], label)
	end

	function playermod:Update(win, set)
		win.title = pformat(L["%s's deaths"], win.actorname)
		if not set or not win.actorid then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor or enemy then return end

		local deathlog = (actor.death or WATCH) and actor.deathlog
		if not deathlog then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local curtime = set.last_time or GetTime()

		for i = 1, #deathlog do
			local death = deathlog[i]
			if death and (death.timeod or WATCH) then
				nr = nr + 1

				local d = win:nr(nr)
				d.id = i

				if death.id then -- spell id
					d.label, _, d.icon = GetSpellInfo(death.id)
					d.spellschool = death.sch
				end

				d.icon = d.icon or icon_death
				d.label = d.label or L["Unknown"]
				if mod_cols.Source and death.src then
					d.text = format("%s (%s)", d.label, death.src)
				end

				d.value = death.time or curtime
				if death.timeod then
					d.valuetext = Skada:FormatValueCols(
						mod_cols.Time and date("%H:%M:%S", death.timeod),
						mod_cols.Survivability and Skada:FormatTime(death.timeod - set.starttime, true)
					)
				else
					d.valuetext = "..."
				end

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	-- default Deaths module:
	local function mod_update(self, win, set)
		win.title = win.class and format("%s (%s)", L["Deaths"], L[win.class]) or L["Deaths"]

		if not set or not (set.death or WATCH) then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local curtime = set.last_time or GetTime()

		local actors = set.players -- players
		for i = 1, #actors do
			local p = actors[i]
			if p and (p.death or WATCH) and (not win.class or win.class == p.class) then
				nr = nr + 1
				local d = win:actor(nr, p)

				if p.death then
					d.value = p.death
					d.valuetext = p.death

					if p.deathlog then
						local first_death = p.deathlog[#p.deathlog]
						if first_death and first_death.time then
							d.value = first_death.time
							d.color = (WATCH and first_death.time) and GRAY_COLOR or nil
						end
					end
				else
					d.value = curtime
					d.valuetext = "..."
					d.color = nil
				end
			end
		end
	end

	-- alternative Deaths module:
	local function alt_update(self, win, set)
		win.title = win.class and format("%s (%s)", L["Deaths"], L[win.class]) or L["Deaths"]

		if not set or not (set.death or WATCH) then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local curtime = set.last_time or GetTime()

		local actors = set.players -- players
		for i = 1, #actors do
			local p = actors[i]
			if p and p.deathlog and (p.death or WATCH) and (not win.class or win.class == p.class) then
				local num = #p.deathlog
				for j = 1, num do
					local death = p.deathlog[j]
					if death and (death.timeod or WATCH) then
						nr = nr + 1
						local d = win:actor(nr, p)
						d.id = format("%s::%d", p.id, j)

						if death.timeod then
							d.color = WATCH and GRAY_COLOR or nil
							d.value = death.time
							d.valuetext = Skada:FormatValueCols(
								mod_cols.Time and date("%H:%M:%S", death.timeod),
								mod_cols.Survivability and Skada:FormatTime(death.timeod - set.starttime, true)
							)
						else
							d.color = nil
							d.value = curtime or GetTime()
							d.valuetext = "..."
						end

						local src = mod_cols.Source and death.src
						if num ~= 1 then
							d.text = format(src and "%s (%d) (%s)" or "%s (%d)", d.text or d.label, num, src)
							d.reportlabel = format("%s   %s", d.text, d.valuetext)
						else
							d.text = src and format("%s (%s)", d.text or d.label, src) or nil
							d.reportlabel = d.text and format("%s   %s", d.text, d.valuetext) or nil
						end

						num = num - 1
					end
				end
			end
		end
	end

	function mod:Update(win, set)
		if M.alternativedeaths and (set ~= Skada.total or P.totalidc) then
			alt_update(self, win, set)
		else
			mod_update(self, win, set)
		end
	end

	function mod:GetSetSummary(set, win)
		if not set then return end
		local deaths = set:GetTotal(win and win.class, nil, "death") or 0
		return set.last_time or GetTime(), deaths
	end

	function mod:AddToTooltip(set, tooltip)
		if set.death and set.death > 0 then
			tooltip:AddDoubleLine(DEATHS, set.death, 1, 1, 1)
		end
	end

	local function entry_tooltip(win, id, label, tooltip)
		local entry = win.dataset[id]
		if not entry or not entry.spellname then return end

		tooltip:AddLine(L["Spell details"])
		tooltip:AddDoubleLine(L["Spell"], entry.spellname, 1, 1, 1, 1, 1, 1)

		if entry.source then
			tooltip:AddDoubleLine(L["Source"], entry.source, 1, 1, 1, 1, 1, 1)
		end

		if entry.hp and entry.hp ~= 0 then
			tooltip:AddDoubleLine(HEALTH, Skada:FormatNumber(entry.hp), 1, 1, 1)
		end

		local c = nil

		if entry.amount and entry.amount ~= 0 then
			c = get_color(entry.amount < 0 and "red" or "green")
			tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(entry.amount), 1, 1, 1, c.r, c.g, c.b)
		end

		if entry.overkill and entry.overkill > 0 then
			tooltip:AddDoubleLine(L["Overkill"], Skada:FormatNumber(entry.overkill), 1, 1, 1, 0.77, 0.64, 0)
		elseif entry.overheal and entry.overheal > 0 then
			c = get_color("yellow")
			tooltip:AddDoubleLine(L["Overheal"], Skada:FormatNumber(entry.overheal), 1, 1, 1, c.r, c.g, c.b)
		end

		if entry.resisted and entry.resisted > 0 then
			c = get_color("orange")
			tooltip:AddDoubleLine(L["RESIST"], Skada:FormatNumber(entry.resisted), 1, 1, 1, c.r, c.g, c.b)
		end

		if entry.blocked and entry.blocked > 0 then
			c = get_color("orange")
			tooltip:AddDoubleLine(L["BLOCK"], Skada:FormatNumber(entry.blocked), 1, 1, 1, c.r, c.g, c.b)
		end

		if entry.absorbed and entry.absorbed > 0 then
			c = get_color("orange")
			tooltip:AddDoubleLine(L["ABSORB"], Skada:FormatNumber(entry.absorbed), 1, 1, 1, c.r, c.g, c.b)
		end
	end

	function mod:OnEnable()
		deathlogmod.metadata = {
			ordersort = true,
			tooltip = entry_tooltip,
			columns = {Change = true, Health = true, Percent = true},
			icon = icon_death
		}
		playermod.metadata = {click1 = deathlogmod}
		self.metadata = {
			click1 = playermod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Time = true, Survivability = false, Source = false},
			icon = [[Interface\Icons\ability_rogue_feigndeath]]
		}

		-- alternative display
		if M.alternativedeaths then
			playermod.metadata.click1 = nil
			self.metadata.click1 = deathlogmod
		end

		mod_cols = self.metadata.columns
		submod_cols = deathlogmod.metadata.columns

		-- no total click.
		deathlogmod.nototal = true
		playermod.nototal = true

		local flags_dst_nopets = {dst_is_interesting_nopets = true}

		Skada:RegisterForCL(
			sor_applied,
			"SPELL_AURA_APPLIED",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			spell_damage,
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			"SPELL_INSTAKILL",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			spell_missed,
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			environment_damage,
			"ENVIRONMENTAL_DAMAGE",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			spell_heal,
			"SPELL_HEAL",
			"SPELL_PERIODIC_HEAL",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			unit_died,
			"UNIT_DIED",
			"UNIT_DESTROYED",
			"UNIT_DISSIPATES",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			spell_resurrect,
			"SPELL_RESURRECT",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			spell_resurrect,
			"SPELL_CAST_SUCCESS",
			{src_is_interesting = true, dst_is_not_interesting = true}
		)

		Skada:RegisterForCL(
			debuff_applied,
			"SPELL_AURA_APPLIED",
			{src_is_not_interesting = true, dst_is_interesting_nopets = true}
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self)

		if Skada.ignoredSpells and Skada.ignoredSpells.debuffs then
			ignoredSpells = Skada.ignoredSpells.debuffs
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:CombatLeave()
		wipe(data)
	end

	function mod:SetComplete(set)
		-- clean deathlogs.
		for i = 1, #set.players do
			local player = set.players[i]
			if player and (not set.death or not player.death) then
				player.death, player.deathlog = nil, del(player.deathlog, true)
			elseif player and player.deathlog then
				while #player.deathlog > (player.death or 0) do
					del(tremove(player.deathlog, 1), true)
				end
				if #player.deathlog == 0 then
					player.deathlog = del(player.deathlog)
				end
			end
		end
	end

	function mod:Announce(logs, playername)
		-- announce only if:
		-- 	1. we have a valid deathlog.
		-- 	2. player is not in a pvp (spam caution).
		-- 	3. player is in a group or channel set to self or guild.
		if not logs or IsInPvP() then return end

		local channel = M.deathchannel
		if channel ~= "SELF" and channel ~= "GUILD" and not IsInGroup() then return end

		local log = nil
		for i = 1, #logs do
			local l = logs[i]
			if l and l.amt and l.amt < 0 then
				log = l
				break
			end
		end

		if not log then return end

		-- prepare the output.
		local output = format(
			(channel == "SELF") and "%s > %s (%s) %s" or "Skada: %s > %s (%s) %s",
			log.src or L["Unknown"], -- source name
			playername or L["Unknown"], -- player name
			log.id and GetSpellInfo(log.id) or L["Unknown"], -- spell name
			log.amt and Skada:FormatNumber(0 - log.amt, 1) or 0 -- spell amount
		)

		-- prepare any extra info.
		if log.ovk or log.res or log.blo or log.abs then
			local extra = new()

			if log.ovk then
				extra[#extra + 1] = format("O:%s", Skada:FormatNumber(log.ovk, 1))
			end
			if log.res then
				extra[#extra + 1] = format("R:%s", Skada:FormatNumber(log.res, 1))
			end
			if log.blo then
				extra[#extra + 1] = format("B:%s", Skada:FormatNumber(log.blo, 1))
			end
			if log.abs then
				extra[#extra + 1] = format("A:%s", Skada:FormatNumber(log.abs, 1))
			end
			if next(extra) then
				output = format("%s [%s]", output, tconcat(extra, " - "))
			end

			extra = del(extra)
		end

		Skada:SendChat(output, channel, "preset")
	end

	do
		local options
		local function get_options()
			if not options then
				options = {
					type = "group",
					name = mod.localeName,
					desc = format(L["Options for %s."], L["Death log"]),
					args = {
						header = {
							type = "description",
							name = mod.localeName,
							fontSize = "large",
							image = mod.metadata.icon,
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
						deathlog = {
							type = "group",
							name = L["Death log"],
							inline = true,
							order = 10,
							args = {
								deathlogevents = {
									type = "range",
									name = L["Events Amount"],
									desc = L["Set the amount of events the death log should record."],
									min = 4,
									max = 34,
									step = 1,
									order = 10
								},
								deathlogthreshold = {
									type = "range",
									name = L["Minimum Healing"],
									desc = L["Ignore heal events that are below this threshold."],
									min = 0,
									max = 10000,
									step = 1,
									bigStep = 10,
									order = 20
								}
							}
						},
						announce = {
							type = "group",
							name = L["Announce Deaths"],
							inline = true,
							order = 20,
							args = {
								anndesc = {
									type = "description",
									name = L["Announces information about the last hit the player took before they died."],
									fontSize = "medium",
									width = "full",
									order = 10
								},
								deathannounce = {
									type = "toggle",
									name = L["Enable"],
									order = 20
								},
								deathchannel = {
									type = "select",
									name = L["Channel"],
									values = {AUTO = INSTANCE, SELF = L["Self"], GUILD = GUILD},
									order = 30,
									disabled = function()
										return not M.deathannounce
									end
								}
							}
						},
						alternativedeaths = {
							type = "toggle",
							name = L["Alternative Display"],
							desc = L["If a player dies multiple times, each death will be displayed as a separate bar."],
							set = function(_, value)
								if M.alternativedeaths then
									M.alternativedeaths = nil
									mod.metadata.click1 = playermod
									playermod.metadata.click1 = deathlogmod
								else
									M.alternativedeaths = true
									mod.metadata.click1 = deathlogmod
									playermod.metadata.click1 = nil
								end

								mod:Reload()
								Skada:Wipe(true)
								Skada:UpdateDisplay(true)
							end,
							width = "full",
							order = 30
						}
					}
				}
			end
			return options
		end

		function mod:OnInitialize()
			if M.deathlogevents == nil then
				M.deathlogevents = 14
			end
			if M.deathlogthreshold == nil then
				M.deathlogthreshold = 1000 -- default
			end
			if M.deathchannel == nil then
				M.deathchannel = "AUTO"
			end

			Skada.options.args.modules.args.deathlog = get_options()

			-- add colors to tweaks
			Skada.options.args.tweaks.args.advanced.args.colors.args.deathlog = {
				type = "group",
				name = L["Death log"],
				order = 50,
				hidden = Skada.options.args.tweaks.args.advanced.args.colors.args.custom.disabled,
				disabled = Skada.options.args.tweaks.args.advanced.args.colors.args.custom.disabled,
				get = function(i)
					local color = get_color(i[#i])
					return color.r, color.g, color.b
				end,
				set = function(i, r, g, b)
					P.customcolors = P.customcolors or {}
					local key = "deathlog_" .. i[#i]
					P.customcolors[key] = P.customcolors[key] or {}
					P.customcolors[key].r = r
					P.customcolors[key].g = g
					P.customcolors[key].b = b
				end,
				args = {
					green = {
						type = "color",
						name = L["Healing Taken"],
						desc = format(L["Color for %s."], L["Healing Taken"]),
						order = 10
					},
					red = {
						type = "color",
						name = L["Damage Taken"],
						desc = format(L["Color for %s."], L["Damage Taken"]),
						order = 20
					},
					yellow = {
						type = "color",
						name = L["Overheal"],
						desc = format(L["Color for %s."], L["Overhealing"]),
						order = 20
					},
					orange = {
						type = "color",
						name = L["Avoidance & Mitigation"],
						desc = format(L["Color for %s."], L["Avoidance & Mitigation"]),
						order = 20
					},
					purple = {
						type = "color",
						name = L["Debuffs"],
						desc = format(L["Color for %s."], L["Debuffs"]),
						order = 30
					}
				}
			}
		end
	end
end)
