local folder, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Deaths", function(L, P, _, _, M, O)
	local mode = Skada:NewModule("Deaths")
	local mode_actor = mode:NewModule("Player's deaths")
	local mode_deathlog = mode:NewModule("Death log")
	local WATCH = nil -- true to watch those alive

	--------------------------------------------------------------------------
	-- cache most used functions
	--------------------------------------------------------------------------
	local tinsert, tremove, tsort, tconcat = table.insert, Private.tremove, table.sort, table.concat
	local strmatch, format, uformat = strmatch, string.format, Private.uformat
	local max, floor, abs = math.max, math.floor, math.abs
	local new, del, clear = Private.newTable, Private.delTable, Private.clearTable
	local UnitIsFeignDeath, UnitHealthInfo = UnitIsFeignDeath, Skada.UnitHealthInfo
	local IsInGroup, IsInPvP, spellnames = Skada.IsInGroup, Skada.IsInPvP, Skada.spellnames
	local GetTime, time, date, wipe = GetTime, time, date, wipe
	local classfmt = Skada.classcolors.format
	local mode_cols, submode_cols = nil, nil
	local death_timers -- holds Spirit of Redemption scheduled death timers

	--------------------------------------------------------------------------
	-- colors and icons
	--------------------------------------------------------------------------
	local GREEN_COLOR = GREEN_FONT_COLOR
	local ORANGE_COLOR = ORANGE_FONT_COLOR
	local RED_COLOR = RED_FONT_COLOR
	local YELLOW_COLOR = YELLOW_FONT_COLOR
	local PURPLE_COLOR = {r = 0.69, g = 0.38, b = 1}
	local BLUE_COLOR = {r = 0.176, g = 0.318, b = 1}
	local icon_mode = [[Interface\ICONS\Ability_Rogue_FeignDeath]]
	local icon_death = [[Interface\ICONS\Spell_Shadow_Soulleech_1]]

	-- returns a color table by its key
	local function get_color(key)
		if P.usecustomcolors and P.customcolors and P.customcolors[format("deathlog_%s", key)] then
			return P.customcolors[format("deathlog_%s", key)]
		elseif key == "orange" then
			return ORANGE_COLOR
		elseif key == "yellow" then
			return YELLOW_COLOR
		elseif key == "green" then
			return GREEN_COLOR
		elseif key == "purple" then
			return PURPLE_COLOR
		elseif key == "blue" then
			return BLUE_COLOR
		else
			return RED_COLOR
		end
	end

	--------------------------------------------------------------------------
	-- logger functions
	--------------------------------------------------------------------------

	local data = {} -- holds what's to log
	local function log_deathlog(set, override)
		if not set or (set == Skada.total and not P.totalidc) then return end

		local actor = Skada:GetActor(set, data.actorname, data.actorid, data.actorflags)
		if not actor then return end

		local deathlog = actor.deathlog and actor.deathlog[1]
		if not deathlog or (deathlog.timeod and not override) then
			actor.deathlog = actor.deathlog or {}
			tinsert(actor.deathlog, 1, {log = new()})
			deathlog = actor.deathlog[1]
		end

		-- seet actor maxhp if not already set
		if not deathlog.hpm or deathlog.hpm == 0 then
			_, _, deathlog.hpm = UnitHealthInfo(data.actorname, actor.id, "group")
			deathlog.hpm = deathlog.hpm or 0
		end

		local log = new()
		log.id = data.spellid
		log.src = data.srcName
		log.cri = data.critical
		log.time = Skada._Time or GetTime()
		_, log.hp = UnitHealthInfo(data.actorname, actor.id, "group")

		if data.amount then
			deathlog.time = log.time
			log.aur = nil
			log.rem = nil

			if data.amount == true then -- instakill
				log.amt = -log.hp
				deathlog.id = log.id
				deathlog.src = log.src
			elseif data.amount ~= 0 then
				log.amt = data.amount

				if log.amt < 0 then
					deathlog.id = log.id
					deathlog.src = log.src
				end
			end
		elseif data.aura then
			log.aur = 1
			log.rem = data.remove and 1 or nil
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
		if #deathlog.log > M.deathlogevents then
			del(tremove(deathlog.log))
		end
	end

	local function log_death(set, actorname, actorid, actorflags)
		local actor = Skada:GetActor(set, actorname, actorid, actorflags)
		if not actor then return end

		set.death = (set.death or 0) + 1
		actor.death = (actor.death or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		local deathlog = actor.deathlog and actor.deathlog[1]
		if not deathlog then return end

		deathlog.time = Skada._Time or GetTime()
		deathlog.timeod = Skada._time or time()

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
			mode:Announce(deathlog.log, actorname)
		end
	end

	--------------------------------------------------------------------------
	-- damage handlers
	--------------------------------------------------------------------------

	local spell_damage
	local spell_missed
	do
		local ignored_spells = Skada.ignored_spells.damage -- Edit Skada\Core\Tables.lua
		local misstypes = {RESIST = true, BLOCK = true, ABSORB = true}

		function spell_damage(t)
			if t.spellid and t.amount and not ignored_spells[t.spellid] then
				data.srcName = t.srcName
				data.actorid = t.dstGUID
				data.actorname = t.dstName
				data.actorflags = t.dstFlags

				data.spellid = t.spellstring
				data.amount = t.amount
				data.overkill = t.overkill
				data.resisted = t.resisted
				data.blocked = t.blocked
				data.absorbed = t.absorbed
				data.critical = t.critical
				data.overheal = nil

				if t.event == "SPELL_INSTAKILL" then
					data.amount = true
				else
					data.amount = 0 - data.amount
				end

				Skada:DispatchSets(log_deathlog)
			end
		end

		function spell_missed(t)
			if t.spellid and not ignored_spells[t.spellid] and t.misstype and misstypes[t.misstype] then
				data.srcName = t.srcName
				data.actorid = t.dstGUID
				data.actorname = t.dstName
				data.actorflags = t.dstFlags
				data.spellid = t.spellstring

				data.amount = nil
				data.overkill = nil
				data.overheal = nil
				data.critical = nil
				data.aura = nil
				data.remove = nil

				if t.misstype == "RESIST" then
					data.resisted = t.resisted
					data.blocked = nil
					data.absorbed = nil
				elseif t.misstype == "BLOCK" then
					data.resisted = nil
					data.blocked = t.blocked
					data.absorbed = nil
				elseif t.misstype == "ABSORB" then
					data.resisted = nil
					data.blocked = nil
					data.absorbed = t.absorbed
				end

				Skada:DispatchSets(log_deathlog)
			end
		end
	end

	--------------------------------------------------------------------------
	-- heal handler
	--------------------------------------------------------------------------

	local spell_heal
	do
		-- Edit Skada\Core\Tables.lua
		local ignored_spells = setmetatable({
			[spellnames[15290]] = true, -- Vampiric Embrace
			[spellnames[20267]] = true, -- Judgement of Light
			[spellnames[23881]] = true, -- Bloodthirst
			[spellnames[50475]] = true, -- Blood Presence
			[spellnames[52042]] = true, -- Healing Stream Totem
		}, {__index = Skada.ignored_spells.heal})

		function spell_heal(t)
			-- no spell id or ignored healing spell? (Tables.lua)
			if not t.spellid or ignored_spells[t.spellid] then return end
			-- no spellstring or ignored healing spell? (top)
			if not t.spellstring or ignored_spells[t.spellname] then return end
			-- no amount or less than set threshold?
			if not t.amount or t.amount < M.deathlogthreshold then return end

			-- all tests passed?
			data.actorid = t.dstGUID
			data.actorname = t.dstName
			data.actorflags = t.dstFlags
			_, data.srcName = Skada:FixMyPets(t.srcGUID, t.srcName, t.srcFlags)
			data.spellid = t.spellstring
			data.amount = t.amount

			data.overheal = nil
			data.overkill = nil
			data.resisted = nil
			data.blocked = nil
			data.absorbed = nil
			data.critical = nil
			data.aura = nil
			data.remove = nil

			if t.overheal and t.overheal > 0 then
				data.amount = max(0, data.amount - t.overheal)
				data.overheal = t.overheal
			end

			Skada:DispatchSets(log_deathlog)
		end
	end

	--------------------------------------------------------------------------
	-- death and resurrect handlers
	--------------------------------------------------------------------------

	local dead = {}
	local function unit_died(t)
		if not UnitIsFeignDeath(t.dstName) then
			dead[t.dstName] = true
			Skada:DispatchSets(log_death, t.dstName, t.dstGUID, t.dstFlags)
		end
		if death_timers and t.dstGUID and death_timers[t.dstGUID] then
			Skada:CancelTimer(death_timers[t.dstGUID], true)
			death_timers[t.dstGUID] = nil
			if not next(death_timers) then
				death_timers = del(death_timers)
			end
		end
	end

	local function sor_applied(t)
		if t.spellid == 27827 then -- Spirit of Redemption (Holy Priest)
			local args = new()
			args.dstGUID = t.dstGUID
			args.dstName = t.dstName
			args.dstFlags = t.dstFlags

			death_timers = death_timers or new()
			death_timers[t.dstGUID] = Skada:ScheduleTimer(unit_died, 0.01, args)
		end
	end

	local ress_spells = Skada.ress_spells
	local function spell_resurrect(t)
		if t.spellid and (t.event == "SPELL_RESURRECT" or ress_spells[t.spellid]) then
			data.spellid = t.spellstring

			if t.event == "SPELL_RESURRECT" then
				data.srcName = t.srcName
				data.actorid = t.dstGUID
				data.actorname = t.dstName
				data.actorflags = t.dstFlags
			else
				data.srcName = t.srcName
				data.actorid = t.srcGUID
				data.actorname = t.srcName
				data.actorflags = t.srcFlags
			end

			data.amount = nil
			data.overkill = nil
			data.overheal = nil
			data.resisted = nil
			data.blocked = nil
			data.absorbed = nil
			data.critical = nil
			data.aura = nil
			data.remove = nil

			dead[data.actorid] = nil
			Skada:DispatchSets(log_deathlog, true)
		end
	end

	--------------------------------------------------------------------------
	-- buff and debuff handlers
	--------------------------------------------------------------------------

	local handle_debuff
	local handle_buff
	do
		local ignored_debuff = Skada.ignored_spells.debuff -- Edit Skada\Core\Tables.lua
		local ignored_buff = Skada.ignored_spells.buff -- Edit Skada\Core\Tables.lua
		local tracked_buff = Skada.deathlog_tracked_buff -- Edit Skada\Core\Tables.lua

		local function handle_aura(dstGUID, dstName, dstFlags, srcName, spellid, removed)
			data.spellid = spellid
			data.aura = true
			data.remove = removed or nil

			data.srcName = (srcName ~= dstName) and srcName or nil
			data.actorid = dstGUID
			data.actorname = dstName
			data.actorflags = dstFlags

			data.amount = nil
			data.overkill = nil
			data.overheal = nil
			data.resisted = nil
			data.blocked = nil
			data.absorbed = nil
			data.critical = nil

			Skada:DispatchSets(log_deathlog)
		end

		function handle_debuff(t)
			-- not a debuff or an ignored one?
			if t.auratype ~= "DEBUFF" or not t.spellid or ignored_debuff[t.spellid] then return end
			-- invalid destination or already dead?
			if not t.dstName or dead[t.dstName] then return end

			-- all tests passed.
			handle_aura(t.dstGUID, t.dstName, t.dstFlags, t.srcName, t.spellstring, t.event == "SPELL_AURA_REMOVED")
		end

		function handle_buff(t)
			-- not a buff or the spell isn't tracked?
			if t.auratype ~= "BUFF" or not t.spellname or not tracked_buff[t.spellname] then return end
			-- no spellid, an ignored spell or the destination isn't valid or is dead?
			if not t.spellid or ignored_buff[t.spellid] or not t.dstGUID or dead[t.dstName] then return end

			-- all tests passed.
			handle_aura(t.dstGUID, t.dstName, t.dstFlags, t.srcName, t.spellstring, t.event == "SPELL_AURA_REMOVED")
		end
	end

	--------------------------------------------------------------------------
	-- module functions
	--------------------------------------------------------------------------

	function mode_deathlog:Enter(win, id, label)
		if M.alternativedeaths then
			win.actorid, win.datakey = strmatch(id, "(%w+)::(%d+)")
			win.datakey = tonumber(win.datakey or 0)
			win.actorname = label
		else
			win.datakey = id
		end

		win.title = uformat(L["%s's death log"], classfmt(win.actorclass, win.actorname))
	end

	do
		local function sort_logs(a, b)
			return a and b and a.time > b.time
		end

		function mode_deathlog:Update(win, set)
			win.title = uformat(L["%s's death log"], classfmt(win.actorclass, win.actorname))

			local actor = win.datakey and Skada:FindActor(set, win.actorname, win.actorid)
			local deathlog = actor and actor.deathlog and actor.deathlog[win.datakey]
			if not deathlog then return end

			if M.alternativedeaths then
				local num = #actor.deathlog
				if win.datakey ~= num then
					win.title = format("%s (%d)", win.title, num - win.datakey + 1)
				end
			end

			if win.metadata then
				win.metadata.maxvalue = deathlog.hpm
			end

			-- 1. remove "datakey" from ended logs.
			-- 2. postfix empty table
			-- 3. add a fake entry for the actual death
			if deathlog.timeod then
				-- win.datakey = nil -- [1] -- TODO: needs review

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
					local d = win:nr(0)

					d.id = 0
					d.label = date("%H:%M:%S", deathlog.timeod)
					d.icon = icon_mode
					d.color = nil
					d.value = 0
					d.valuetext = format(L["%s dies"], win.actorname)
				end
			end

			tsort(deathlog.log, sort_logs)

			local nr = 0
			local curtime = deathlog.time or Skada._Time or GetTime()
			for i = #deathlog.log, 1, -1 do
				local log = deathlog.log[i]
				local diff = tonumber(log.time) - tonumber(curtime)
				if diff > -60 then
					nr = i + 1

					local d = log.id and win:spell(nr, log.id, false) or win:nr(nr)
					d.id = i
					d.label = d.label or L["Unknown"]
					d.icon = d.icon or icon_death
					d.text = format("%s%02.2fs: %s", diff > 0 and "+" or "", diff, d.label)
					d.value = log.hp or 0 -- used for tooltip

					local src = log.src or L["Unknown"]
					if d.spellid and ress_spells[d.spellid] then
						d.color = nil
						d.valuetext = src
					else
						local color = get_color("red")
						local change = log.amt or 0

						if log.aur and d.spellid > 0 then
							change = format("%s %s", log.rem and "-" or "+", L["buff"])
							color = get_color("blue")
						elseif log.aur then
							change = format("%s %s", log.rem and "-" or "+", L["debuff"])
							color = get_color("purple")
						elseif change > 0 then
							change = format("+%s", Skada:FormatNumber(change))
							color = get_color("green")
						elseif change == 0 and (log.res or log.blo or log.abs) then
							change = format("+%s", Skada:FormatNumber(log.res or log.blo or log.abs))
							color = get_color("orange")
						elseif log.ovh then
							change = format("+%s", Skada:FormatNumber(log.ovh))
							color = get_color("yellow")
						elseif log.cri then
							change = format("%s (%s)", Skada:FormatNumber(change), L["Crit"])
						else
							change = Skada:FormatNumber(change)
						end

						d.changed = (WATCH and color ~= d.color) and true or (WATCH and d.changed) and nil
						d.color = color

						-- only format report for ended logs
						if deathlog.timeod ~= nil then
							d.reportlabel = d.text
							d.reportvalue = format("%s [%s]", change, Skada:FormatNumber(d.value))

							local extra = new()

							if log.ovh and log.ovh > 0 then
								extra[#extra + 1] = format("O:%s", Skada:FormatNumber(log.ovh))
							end
							if log.ovk and log.ovk > 0 then
								extra[#extra + 1] = format("O:%s", Skada:FormatNumber(log.ovk))
							end
							if log.res and log.res > 0 then
								extra[#extra + 1] = format("R:%s", Skada:FormatNumber(log.res))
							end
							if log.blo and log.blo > 0 then
								extra[#extra + 1] = format("B:%s", Skada:FormatNumber(log.blo))
							end
							if log.abs and log.abs > 0 then
								extra[#extra + 1] = format("A:%s", Skada:FormatNumber(log.abs))
							end

							if next(extra) then
								d.reportvalue = format("%s (%s)", d.reportvalue, tconcat(extra, " - "))
							end

							extra = del(extra)
						end

						d.valuetext = Skada:FormatValueCols(
							submode_cols.Change and change,
							submode_cols.Health and Skada:FormatNumber(d.value),
							submode_cols.Percent and Skada:FormatPercent(log.hp or 0, deathlog.hpm or 1)
						)
					end
				else
					del(tremove(deathlog.log, i))
				end
			end
		end
	end

	function mode_actor:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's deaths"], classfmt(class, label))
	end

	function mode_actor:Update(win, set)
		win.title = uformat(L["%s's deaths"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorid then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor or actor.enemy then return end

		local deathlog = (actor.death or WATCH) and actor.deathlog
		if not deathlog then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local curtime = Skada._Time or GetTime()

		for i = 1, #deathlog do
			local death = deathlog[i]
			if death and (death.timeod or WATCH) then
				nr = nr + 1

				local d = death.id and win:spell(nr, death.id, false) or win:nr(nr)
				d.id = i
				d.icon = d.icon or icon_death
				d.label = d.label or L["Unknown"]
				if mode_cols.Source and death.src then
					d.text = format("%s (%s)", d.label, death.src)
					d.reportlabel = d.text
				end

				d.value = death.time or curtime
				if death.timeod then
					d.valuetext = Skada:FormatValueCols(
						mode_cols.Time and date("%H:%M:%S", death.timeod),
						mode_cols.Survivability and Skada:FormatTime(death.timeod - set.starttime, true)
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
		local curtime = Skada._Time or GetTime()
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.deathlog and (actor.death or WATCH) then
				nr = nr + 1
				local d = win:actor(nr, actor, actor.enemy, actorname)

				if actor.death then
					d.value = actor.death
					d.valuetext = actor.death

					if actor.deathlog then
						local first_death = actor.deathlog[#actor.deathlog]
						if first_death and first_death.time then
							d.value = first_death.time
						end
					end
				else
					d.value = curtime
					d.valuetext = "..."
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
		local curtime = Skada._Time or GetTime()
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.deathlog and (actor.death or WATCH) then
				local num = #actor.deathlog
				for j = 1, num do
					local death = actor.deathlog[j]
					if death and (death.timeod or WATCH) then
						nr = nr + 1
						local d = win:actor(nr, actor, actor.enemy, actorname)
						d.id = format("%s::%d", actor.id, j)

						if death.timeod then
							d.value = death.time
							d.valuetext = Skada:FormatValueCols(
								mode_cols.Time and date("%H:%M:%S", death.timeod),
								mode_cols.Survivability and Skada:FormatTime(death.timeod - set.starttime, true)
							)
						else
							d.value = curtime or GetTime()
							d.valuetext = "..."
						end

						local src = mode_cols.Source and death.src
						if num ~= 1 then
							d.text = format(src and "%s (%d) (%s)" or "%s (%d)", d.label, num, src)
							d.reportlabel = d.text
						else
							d.text = src and format("%s (%s)", d.label, src) or d.label
							d.reportlabel = d.text
						end

						num = num - 1
					end
				end
			end
		end
	end

	function mode:Update(win, set)
		if M.alternativedeaths and (set ~= Skada.total or P.totalidc) then
			alt_update(self, win, set)
		else
			mod_update(self, win, set)
		end
	end

	function mode:GetSetSummary(set, win)
		if not set then return end
		local deaths = set:GetTotal(win and win.class, nil, "death") or 0
		return set.endtime or Skada._time or time(), deaths
	end

	function mode:AddToTooltip(set, tooltip)
		if set.death and set.death > 0 then
			tooltip:AddDoubleLine(L["Deaths"], set.death, 1, 1, 1)
		end
	end

	local function entry_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local deathlog = actor and actor.deathlog and win.datakey and actor.deathlog[win.datakey]
		local entry = deathlog and deathlog.log and deathlog.log[id]
		if not entry or not entry.id then return end

		tooltip:AddLine(L["Spell details"])
		tooltip:AddDoubleLine(L["Spell"], label, 1, 1, 1, 1, 1, 1)

		if entry.src then
			tooltip:AddDoubleLine(L["Source"], entry.src, 1, 1, 1, 1, 1, 1)
		end

		if entry.hp and entry.hp ~= 0 then
			tooltip:AddDoubleLine(L["Health"], Skada:FormatNumber(entry.hp), 1, 1, 1)
		end

		local c = nil

		if entry.amt and entry.amt ~= 0 then
			c = get_color(entry.amt < 0 and "red" or "green")
			tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(entry.amt), 1, 1, 1, c.r, c.g, c.b)
		end

		if entry.ovk and entry.ovk > 0 then
			tooltip:AddDoubleLine(L["Overkill"], Skada:FormatNumber(entry.ovk), 1, 1, 1, 0.77, 0.64, 0)
		elseif entry.ovh and entry.ovh > 0 then
			c = get_color("yellow")
			tooltip:AddDoubleLine(L["Overheal"], Skada:FormatNumber(entry.ovh), 1, 1, 1, c.r, c.g, c.b)
		end

		if entry.res and entry.res > 0 then
			c = get_color("orange")
			tooltip:AddDoubleLine(L["RESIST"], Skada:FormatNumber(entry.res), 1, 1, 1, c.r, c.g, c.b)
		end

		if entry.blo and entry.blo > 0 then
			c = get_color("orange")
			tooltip:AddDoubleLine(L["BLOCK"], Skada:FormatNumber(entry.blo), 1, 1, 1, c.r, c.g, c.b)
		end

		if entry.abs and entry.abs > 0 then
			c = get_color("orange")
			tooltip:AddDoubleLine(L["ABSORB"], Skada:FormatNumber(entry.abs), 1, 1, 1, c.r, c.g, c.b)
		end
	end

	function mode:OnEnable()
		mode_deathlog.metadata = {
			ordersort = true,
			tooltip = entry_tooltip,
			columns = {Change = true, Health = true, Percent = true},
			icon = icon_death
		}
		mode_actor.metadata = {click1 = mode_deathlog}
		self.metadata = {
			filterclass = true,
			click1 = mode_actor,
			columns = {Time = true, Survivability = false, Source = false},
			icon = icon_mode
		}

		-- alternative display
		if M.alternativedeaths then
			mode_actor.metadata.click1 = nil
			self.metadata.click1 = mode_deathlog
		end

		mode_cols = self.metadata.columns
		submode_cols = mode_deathlog.metadata.columns

		-- no total click.
		mode_deathlog.nototal = true
		mode_actor.nototal = true

		local flags_dst_nopets = {dst_is_interesting_nopets = true}

		Skada:RegisterForCL(
			sor_applied,
			flags_dst_nopets,
			"SPELL_AURA_APPLIED"
		)

		Skada:RegisterForCL(
			spell_damage,
			flags_dst_nopets,
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			"ENVIRONMENTAL_DAMAGE",
			"SPELL_INSTAKILL"
		)

		Skada:RegisterForCL(
			spell_missed,
			flags_dst_nopets,
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED"
		)

		Skada:RegisterForCL(
			spell_heal,
			flags_dst_nopets,
			"SPELL_HEAL",
			"SPELL_PERIODIC_HEAL"
		)

		Skada:RegisterForCL(
			unit_died,
			flags_dst_nopets,
			"UNIT_DIED",
			"UNIT_DESTROYED",
			"UNIT_DISSIPATES"
		)

		Skada:RegisterForCL(
			spell_resurrect,
			flags_dst_nopets,
			"SPELL_RESURRECT"
		)

		Skada:RegisterForCL(
			spell_resurrect,
			{src_is_interesting = true, dst_is_not_interesting = true},
			"SPELL_CAST_SUCCESS"
		)

		Skada:RegisterForCL(
			handle_buff,
			{dst_is_interesting_nopets = true},
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_APPLIED_DOSE"
		)

		Skada:RegisterForCL(
			handle_debuff,
			{src_is_not_interesting = true, dst_is_interesting_nopets = true},
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_REMOVED",
			"SPELL_AURA_APPLIED_DOSE"
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddMode(self)
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mode:CombatLeave()
		wipe(data)
		wipe(dead)
	end

	function mode:SetComplete(set)
		-- clean deathlogs.
		for _, actor in pairs(set.actors) do
			if not actor.enemy and (not set.death or not actor.death) then
				actor.death, actor.deathlog = nil, del(actor.deathlog, true)
			elseif not actor.enemy and actor.deathlog then
				while #actor.deathlog > (actor.death or 0) do
					del(tremove(actor.deathlog, 1), true)
				end
				if #actor.deathlog == 0 then
					actor.deathlog = del(actor.deathlog)
				end
			end
		end
	end

	local announce_fmt1 = "%s > %s (%s) %s"
	local announce_fmt2 = format("%s: %%s > %%s (%%s) %%s", folder)

	function mode:Announce(logs, actorname)
		-- announce only if:
		-- 	1. we have a valid deathlog.
		-- 	2. actor is not in a pvp (spam caution).
		-- 	3. actor is in a group or channel set to self or guild.
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
			(channel == "SELF") and announce_fmt1 or announce_fmt2,
			log.src or L["Unknown"], -- source name
			actorname or L["Unknown"], -- actor name
			log.id and spellnames[abs(log.id)] or L["Unknown"], -- spell name
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
					name = mode.localeName,
					desc = format(L["Options for %s."], L["Death log"]),
					args = {
						header = {
							type = "description",
							name = mode.localeName,
							fontSize = "large",
							image = icon_mode,
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
									values = {AUTO = L["Instance"], SELF = L["Self"], GUILD = L["Guild"]},
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
									mode.metadata.click1 = mode_actor
									mode_actor.metadata.click1 = mode_deathlog
								else
									M.alternativedeaths = true
									mode.metadata.click1 = mode_deathlog
									mode_actor.metadata.click1 = nil
								end

								mode:Reload()
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

		function mode:OnInitialize()
			M.deathlogevents = M.deathlogevents or 14
			M.deathlogthreshold = M.deathlogthreshold or 1000
			M.deathchannel = M.deathchannel or "AUTO"

			O.modules.args.deathlog = get_options()

			-- add colors to tweaks
			local color_opt = O.tweaks.args.advanced.args.colors
			if not color_opt then return end
			color_opt.args.deathlog = {
				type = "group",
				name = L["Death log"],
				order = 50,
				hidden = O.tweaks.args.advanced.args.colors.args.custom.disabled,
				disabled = O.tweaks.args.advanced.args.colors.args.custom.disabled,
				get = function(i)
					local color = get_color(i[#i])
					return color.r, color.g, color.b
				end,
				set = function(i, r, g, b)
					P.customcolors = P.customcolors or {}
					local key = format("deathlog_%s", i[#i])
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
					},
					blue = {
						type = "color",
						name = L["Buffs"],
						desc = format(L["Color for %s."], L["Debuffs"]),
						order = 40
					}
				}
			}
		end
	end
end)
