local _, Skada = ...
local private = Skada.private

local pairs, max = pairs, math.max
local format, uformat = string.format, private.uformat
local new, del, clear = private.newTable, private.delTable, private.clearTable

local function format_valuetext(d, columns, total, dps, metadata, subview)
	d.valuetext = Skada:FormatValueCols(
		columns.Damage and Skada:FormatNumber(d.value),
		columns[subview and "sDPS" or "DPS"] and dps and Skada:FormatNumber(dps),
		columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
	)

	if metadata and d.value > metadata.maxvalue then
		metadata.maxvalue = d.value
	end
end

-- ================== --
-- Damage Done Module --
-- ================== --

Skada:RegisterModule("Damage", function(L, P)
	local mod = Skada:NewModule("Damage")
	local playermod = mod:NewModule("Damage spell list")
	local spellmod = playermod:NewModule("Damage spell details")
	local sdetailmod = playermod:NewModule("Damage Breakdown")
	local targetmod = mod:NewModule("Damage target list")
	local tdetailmod = targetmod:NewModule("Damage spell list")

	local UnitGUID, GetTime = UnitGUID, GetTime
	local GetSpellInfo = private.spell_info or GetSpellInfo
	local PercentToRGB = private.PercentToRGB
	local spellschools = Skada.spellschools
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local passiveSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local missTypes = Skada.missTypes
	local T = Skada.Table
	local mod_cols = nil

	-- spells on the list below are used to update player's active time
	-- no matter their role or damage amount, since pets aren't considered.
	local whitelist = {}

	local function log_spellcast(set, playerid, playername, playerflags, spellname, spellschool)
		if not set or (set == Skada.total and not P.totalidc) then return end

		local player = Skada:FindPlayer(set, playerid, playername, playerflags)
		if not player or not player.damagespells then return end

		local spell = player.damagespells[spellname] or player.damagespells[spellname..L["DoT"]]
		if not spell then return end

		-- because some DoTs don't have an initial damage
		-- we start from 1 and not from 0 if casts wasn't
		-- previously set. Otherwise we just increment.
		spell.casts = (spell.casts or 1) + 1

		-- fix possible missing spell school.
		if not spell.school and spellschool then
			spell.school = spellschool
		end
	end

	local function add_actor_time(set, actor, spellid, target)
		if whitelist[spellid] then
			Skada:AddActiveTime(set, actor, target, tonumber(whitelist[spellid]))
		elseif actor.role ~= "HEALER" and not passiveSpells[spellid] then
			Skada:AddActiveTime(set, actor, target, tonumber(whitelist[spellid]))
		end
	end

	local dmg = {}
	local function log_damage(set, isdot)
		if not dmg.spellid or not dmg.amount then return end

		local player = Skada:GetPlayer(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if not player then
			return
		elseif dmg.amount > 0 and not dmg.petname then
			add_actor_time(set, player, dmg.spellid, dmg.dstName)
		end

		-- absorbed damage
		local absorbed = dmg.absorbed or 0

		player.damage = (player.damage or 0) + dmg.amount
		player.totaldamage = (player.totaldamage or 0) + dmg.amount

		set.damage = (set.damage or 0) + dmg.amount
		set.totaldamage = (set.totaldamage or 0) + dmg.amount

		if absorbed > 0 then -- add absorbed damage to total
			player.totaldamage = player.totaldamage + absorbed
			set.totaldamage = set.totaldamage + absorbed
		end

		-- add the damage overkill
		local overkill = (dmg.overkill and dmg.overkill > 0) and dmg.overkill or nil
		if overkill then
			set.overkill = (set.overkill or 0) + dmg.overkill
			player.overkill = (player.overkill or 0) + dmg.overkill
		end

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- spell
		local spellname = dmg.spellname .. (isdot and L["DoT"] or "")
		local spell = player.damagespells and player.damagespells[spellname]
		if not spell then
			player.damagespells = player.damagespells or {}
			spell = {id = dmg.spellid, school = dmg.school, amount = 0}
			player.damagespells[spellname] = spell
		elseif dmg.spellid and dmg.spellid ~= spell.id then
			if dmg.school and dmg.school ~= spell.school then
				spellname = spellname .. " (" .. (spellschools[dmg.school] and spellschools[dmg.school].name or L["Other"]) .. ")"
			else
				spellname = GetSpellInfo(dmg.spellid)
			end
			if not player.damagespells[spellname] then
				player.damagespells[spellname] = {id = dmg.spellid, school = dmg.school, amount = 0}
			end
			spell = player.damagespells[spellname]
		elseif not spell.school and dmg.school then
			spell.school = dmg.school
		end

		-- start casts count for non DoTs.
		if dmg.spellid ~= 6603 and not isdot then
			spell.casts = spell.casts or 1
		end

		spell.count = (spell.count or 0) + 1
		spell.amount = spell.amount + dmg.amount

		if spell.total then
			spell.total = spell.total + dmg.amount + absorbed
		elseif absorbed > 0 then
			spell.total = spell.amount + absorbed
		end

		if overkill then
			spell.o_amt = (spell.o_amt or 0) + overkill
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

		-- target
		if not dmg.dstName then return end
		local target = spell.targets and spell.targets[dmg.dstName]
		if not target then
			spell.targets = spell.targets or {}
			spell.targets[dmg.dstName] = {amount = 0}
			target = spell.targets[dmg.dstName]
		end
		target.amount = target.amount + dmg.amount

		if target.total then
			target.total = target.total + dmg.amount + absorbed
		elseif absorbed > 0 then
			target.total = target.amount + absorbed
		end

		if overkill then
			target.o_amt = (target.o_amt or 0) + overkill
		end
	end

	local function spell_cast(_, _, srcGUID, srcName, srcFlags, dstGUID, _, _, spellid, spellname, spellschool)
		if srcGUID and dstGUID and spellid and spellname and not ignoredSpells[spellid] then
			srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)
			Skada:DispatchSets(log_spellcast, srcGUID, srcName, srcFlags, spellname, spellschool)
		end
	end

	local extraATT = nil
	local function spell_damage(_, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, _, ...)
		if srcGUID == dstGUID then return end

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
			dmg.spellid, dmg.spellname, dmg.school = 6603, L["Melee"], 0x01
			dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing = ...

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
			dmg.spellid, dmg.spellname, dmg.school, dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing = ...
		end

		if dmg.spellid and dmg.spellname and not ignoredSpells[dmg.spellid] then
			dmg.playerid = srcGUID
			dmg.playername = srcName
			dmg.playerflags = srcFlags
			dmg.dstName = dstName
			dmg.misstype = nil

			Skada:FixPets(dmg)
			Skada:DispatchSets(log_damage, eventtype == "SPELL_PERIODIC_DAMAGE")
		end
	end

	local function spell_missed(_, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, _, ...)
		if srcGUID == dstGUID then return end

		local amount

		if eventtype == "SWING_MISSED" then
			dmg.spellid, dmg.spellname, dmg.school = 6603, L["Melee"], 0x01
			dmg.misstype, amount = ...
		else
			dmg.spellid, dmg.spellname, dmg.school, dmg.misstype, amount = ...
		end

		if dmg.spellid and dmg.spellname and not ignoredSpells[dmg.spellid] then
			dmg.playerid = srcGUID
			dmg.playername = srcName
			dmg.playerflags = srcFlags
			dmg.dstName = dstName

			dmg.amount = 0
			dmg.overkill = 0
			dmg.resisted = nil
			dmg.blocked = nil
			dmg.absorbed = nil
			dmg.critical = nil
			dmg.glancing = nil

			if dmg.misstype == "ABSORB" and amount then
				dmg.absorbed = amount
			elseif dmg.misstype == "BLOCK" and amount then
				dmg.blocked = amount
			elseif dmg.misstype == "RESIST" and amount then
				dmg.resisted = amount
			end

			Skada:FixPets(dmg)
			Skada:DispatchSets(log_damage, eventtype == "SPELL_PERIODIC_MISSED")
		end
	end

	local function damage_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(true)
		local dps, damage = actor:GetDPS()

		tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, totaltime), nil, nil, nil, 1, 1, 1)
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(damage), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(Skada:FormatNumber(damage) .. "/" .. suffix, Skada:FormatNumber(dps), 1, 1, 1)
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagespells and actor.damagespells[enemy and id or label]
		if not spell then return end

		tooltip:AddLine(actor.name .. " - " .. label)
		if spell.school and spellschools[spell.school] then
			tooltip:AddLine(spellschools(spell.school))
		end

		-- show the aura uptime in case of a debuff.
		local debuff_id = -spell.id
		local uptime = actor.auras and actor.auras[debuff_id] and actor.auras[debuff_id].uptime
		if uptime and uptime > 0 then
			uptime = 100 * (uptime / actor:GetTime())
			tooltip:AddDoubleLine(L["Uptime"], Skada:FormatPercent(uptime), nil, nil, nil, PercentToRGB(uptime))
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

		if spell.count and spell.count > 0 then
			local amount = P.absdamage and spell.total or spell.amount
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(amount / spell.count), 1, 1, 1)
		end
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] or label == L["Glancing"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetPlayer(win.actorid, win.actorname)
			local spell = actor.damagespells and actor.damagespells[win.spellname]
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
		win.title = L["actor damage"](label)
	end

	function playermod:Update(win, set)
		win.title = L["actor damage"](win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamage()
		local spells = (total and total > 0) and actor.damagespells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime()

		for spellname, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellname, spell)
			d.value = P.absdamage and spell.total or spell.amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's targets"], win.actorname)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local targets, total = actor:GetDamageTargets()

		if not targets or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime()

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, targetname)
			d.value = P.absdamage and target.total or target.amount
			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
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
		return nr
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat("%s: %s", win.actorname, format(L["%s's damage breakdown"], label))
	end

	function spellmod:Update(win, set)
		win.title = uformat("%s: %s", win.actorname, uformat(L["%s's damage breakdown"], win.spellname))
		if not set or not win.spellname then return end

		-- details only available for players
		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagespells and actor.damagespells[enemy and win.spellid or win.spellname]

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

			if spell.casts and spell.casts > 0 then
				nr = add_detail_bar(win, nr, L["Casts"], spell.casts)
				win.dataset[nr].value = win.dataset[nr].value * 1e3 -- to be always first
			end

			if spell.n_num and spell.n_num > 0 then
				nr = add_detail_bar(win, nr, L["Normal Hits"], spell.n_num, spell.count, true)
			end

			if spell.c_num and spell.c_num > 0 then
				nr = add_detail_bar(win, nr, L["Critical Hits"], spell.c_num, spell.count, true)
			end

			if spell.g_num and spell.g_num > 0 then
				nr = add_detail_bar(win, nr, L["Glancing"], spell.g_num, spell.count, true)
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
		win.title = uformat(L["%s's <%s> damage"], win.actorname, label)
	end

	function sdetailmod:Update(win, set)
		win.title = uformat(L["%s's <%s> damage"], win.actorname, win.spellname)
		if not win.spellname then return end

		-- only available for players
		local actor = set and set:GetPlayer(win.actorid, win.actorname)
		local spell = actor and actor.damagespells and actor.damagespells[win.spellname]
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
		win.title = L["actor damage"](win.actorname or L["Unknown"], label)
	end

	function tdetailmod:Update(win, set)
		win.title = L["actor damage"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not set or not win.targetname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local targets = actor and actor:GetDamageTargets()
		if not targets or not targets[win.targetname] then return end

		local total = P.absdamage and targets[win.targetname].total or targets[win.targetname].amount
		local spells = (total and total > 0) and actor.damagespells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime()

		for spellname, spell in pairs(spells) do
			local target = spell.targets and spell.targets[win.targetname]
			local amount = target and (P.absdamage and target.total or target.amount)
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellname, spell)
				d.value = amount
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Damage"], L[win.class]) or L["Damage"]

		local total = set and set:GetDamage(nil, win.class)
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
				local dps, amount = actor:GetDPS()
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor)
					d.color = set.__arena and Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN") or nil
					d.value = amount
					format_valuetext(d, mod_cols, total, dps, win.metadata)
				end
			end
		end

		actors = set.__arena and set.enemies or nil -- arena enemies
		if not actors then return end

		for i = 1, #actors do
			local actor = actors[i]
			if actor and not actor.fake and (not win.class or win.class == actor.class) then
				local dps, amount = actor:GetDPS()
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")
					d.value = amount
					format_valuetext(d, mod_cols, total, dps, win.metadata)
				end
			end
		end
	end

	function mod:GetSetSummary(set, win)
		local dps, amount = set:GetDPS(nil, win and win.class)
		local valuetext = Skada:FormatValueCols(
			mod_cols.Damage and Skada:FormatNumber(amount),
			mod_cols.DPS and Skada:FormatNumber(dps)
		)
		return amount, valuetext
	end

	function mod:AddToTooltip(set, tooltip)
		if not set then return end
		local dps, amount = set:GetDPS()
		tooltip:AddDoubleLine(L["Damage"], Skada:FormatNumber(amount), 1, 1, 1)
		tooltip:AddDoubleLine(L["DPS"], Skada:FormatNumber(dps), 1, 1, 1)
	end

	local function feed_personal_dps()
		local set = Skada:GetSet("current")
		local actor = set and set:GetPlayer(Skada.userGUID, Skada.userName)
		return format("%s %s", Skada:FormatNumber(actor and actor:GetDPS() or 0), L["DPS"])
	end

	local function feed_raid_dps()
		local set = Skada:GetSet("current")
		return format("%s %s", Skada:FormatNumber(set and set:GetDPS() or 0), L["DPS"])
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = spellmod_tooltip}
		playermod.metadata = {click1 = spellmod, click2 = sdetailmod, post_tooltip = playermod_tooltip}
		targetmod.metadata = {click1 = tdetailmod}
		self.metadata = {
			showspots = true,
			post_tooltip = damage_tooltip,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Damage = true, DPS = true, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_fire_firebolt]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		local flags_src_dst = {src_is_interesting = true, dst_is_not_interesting = true}

		Skada:RegisterForCL(
			spell_cast,
			"SPELL_CAST_START",
			"SPELL_CAST_SUCCESS",
			flags_src_dst
		)

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
			flags_src_dst
		)

		Skada:RegisterForCL(
			spell_missed,
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED",
			flags_src_dst
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddFeed(L["Damage: Personal DPS"], feed_personal_dps)
		Skada:AddFeed(L["Damage: Raid DPS"], feed_raid_dps)
		Skada:AddMode(self, L["Damage Done"])

		-- table of ignored damage/time spells:
		if Skada.ignoredSpells then
			if Skada.ignoredSpells.damage then
				ignoredSpells = Skada.ignoredSpells.damage
			end
			if Skada.ignoredSpells.activeTime then
				passiveSpells = Skada.ignoredSpells.activeTime
			end
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveFeed(L["Damage: Personal DPS"])
		Skada:RemoveFeed(L["Damage: Raid DPS"])
		Skada:RemoveMode(self)
	end

	function mod:CombatLeave()
		T.clear(dmg)
		T.free("Damage_ExtraAttacks", extraATT, nil, del)
	end

	function mod:SetComplete(set)
		-- clean set from garbage before it is saved.
		if not set.totaldamage or set.totaldamage == 0 then return end
		for i = 1, #set.players do
			local p = set.players[i]
			if p and (p.totaldamage == 0 or (not p.totaldamage and p.damagespells)) then
				p.damage, p.totaldamage = nil, nil
				p.damagespells = del(p.damagespells, true)
			end
		end
	end

	function mod:OnInitialize()
		-- The Oculus
		whitelist[49840] = true -- Shock Lance (Amber Drake)
		whitelist[50232] = true -- Searing Wrath (Ruby Drake)
		whitelist[50341] = true -- Touch the Nightmare (Emerald Drake)
		whitelist[50344] = true -- Dream Funnel (Emerald Drake)

		-- Eye of Eternity: Wyrmrest Skytalon
		whitelist[56091] = true -- Flame Spike
		whitelist[56092] = true -- Engulf in Flames

		-- Naxxramas: Instructor Razuvious
		whitelist[61696] = true -- Blood Strike (Death Knight Understudy)

		-- Ulduar - Flame Leviathan
		whitelist[62306] = true -- Salvaged Demolisher: Hurl Boulder
		whitelist[62308] = true -- Salvaged Demolisher: Ram
		whitelist[62490] = true -- Salvaged Demolisher: Hurl Pyrite Barrel
		whitelist[62634] = true -- Salvaged Demolisher Mechanic Seat: Mortar
		whitelist[64979] = true -- Salvaged Demolisher Mechanic Seat: Anti-Air Rocket
		whitelist[62345] = true -- Salvaged Siege Engine: Ram
		whitelist[62346] = true -- Salvaged Siege Engine: Steam Rush
		whitelist[62522] = true -- Salvaged Siege Engine: Electroshock
		whitelist[62358] = true -- Salvaged Siege Turret: Fire Cannon
		whitelist[62359] = true -- Salvaged Siege Turret: Anti-Air Rocket
		whitelist[62974] = true -- Salvaged Chopper: Sonic Horn

		-- Icecrown Citadel
		whitelist[69399] = true -- Cannon Blast (Gunship Battle Cannons)
		whitelist[70175] = true -- Incinerating Blast (Gunship Battle Cannons)
		whitelist[70539] = 5.5 -- Regurgitated Ooze (Mutated Abomination)
		whitelist[70542] = true -- Mutated Slash (Mutated Abomination)
	end
end)

-- ============================= --
-- Damage done per second module --
-- ============================= --

Skada:RegisterModule("DPS", function(L, P)
	local mod = Skada:NewModule("DPS")
	local mod_cols = nil

	local function dps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(true)
		local dps, damage = actor:GetDPS()
		tooltip:AddLine(actor.name .. " - " .. L["DPS"])
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(damage), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(Skada:FormatNumber(damage) .. "/" .. suffix, Skada:FormatNumber(dps), 1, 1, 1)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["DPS"], L[win.class]) or L["DPS"]

		local total = set and set:GetDPS(nil, win.class)
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
				local dps = actor:GetDPS()
				if dps > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor)
					d.color = set.__arena and Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN") or nil
					d.value = dps
					format_valuetext(d, mod_cols, total, dps, win.metadata)
				end
			end
		end

		actors = set.__arena and set.enemies or nil -- arena enemies
		if not actors then return end

		for i = 1, #actors do
			local actor = actors[i]
			if actor and not actor.fake and (not win.class or win.class == actor.class) then
				local dps = actor:GetDPS()
				if dps > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")
					d.value = dps
					format_valuetext(d, mod_cols, total, dps, win.metadata)
				end
			end
		end
	end

	function mod:GetSetSummary(set, win)
		local dps = set:GetDPS(nil, win and win.class)
		return dps, Skada:FormatNumber(dps)
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			tooltip = dps_tooltip,
			columns = {DPS = true, Percent = true},
			icon = [[Interface\Icons\achievement_bg_topdps]]
		}

		mod_cols = self.metadata.columns

		local parentmod = Skada:GetModule("Damage", true)
		if parentmod then
			self.metadata.click1 = parentmod.metadata.click1
			self.metadata.click2 = parentmod.metadata.click2
			self.metadata.click4 = parentmod.metadata.click4
			self.metadata.click4_label = parentmod.metadata.click4_label
		end

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self, L["Damage Done"])
	end
end, "Damage")

-- =========================== --
-- Damage Done By Spell Module --
-- =========================== --

Skada:RegisterModule("Damage Done By Spell", function(L, P, _, C)
	local mod = Skada:NewModule("Damage Done By Spell")
	local sourcemod = mod:NewModule("Damage spell sources")
	local mod_cols = nil

	local function player_tooltip(win, id, label, tooltip)
		local set = win.spellname and win:GetSelectedSet()
		local player = set and set:GetActor(label, id)
		local spell = player and player.damagespells and player.damagespells[win.spellname]
		if not spell then return end

		tooltip:AddLine(label .. " - " .. win.spellname)

		if spell.casts then
			tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
		end

		if not spell.count or spell.count == 0 then return end

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
		win.spellname = label
		win.title = format(L["%s's sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = uformat(L["%s's sources"], win.spellname)
		if not win.spellname then return end

		local total = 0
		local sources = clear(C)
		for i = 1, #set.players do
			local player = set.players[i]
			local spell = player and player.damagespells and player.damagespells[win.spellname]
			if spell then
				local amount = P.absdamage and spell.total or spell.amount
				if amount > 0 then
					sources[player.name] = new()
					sources[player.name].id = player.id
					sources[player.name].class = player.class
					sources[player.name].role = player.role
					sources[player.name].spec = player.spec
					sources[player.name].amount = amount
					sources[player.name].time = mod.metadata.columns.sDPS and player:GetTime()

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
		for playername, player in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, player, nil, playername)
			d.value = player.amount
			format_valuetext(d, mod_cols, total, player.time and (d.value / player.time), win.metadata, true)
		end
	end

	function mod:Update(win, set)
		win.title = L["Damage Done By Spell"]

		local total = set and set:GetDamage()
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local spells = clear(C)
		for i = 1, #set.players do
			local player = set.players[i]
			if player and player.damagespells then
				for spellname, spell in pairs(player.damagespells) do
					local amount = P.absdamage and spell.total or spell.amount
					if amount and amount > 0 then
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

		local nr = 0
		local settime = mod_cols.DPS and set:GetTime()

		for spellname, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellname, spell)
			d.value = spell.amount
			format_valuetext(d, mod_cols, total, settime and (d.value / settime), win.metadata)
		end
	end

	function mod:OnEnable()
		sourcemod.metadata = {showspots = true, tooltip = player_tooltip}
		self.metadata = {
			showspots = true,
			click1 = sourcemod,
			columns = {Damage = true, DPS = false, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_nature_lightning]]
		}

		mod_cols = self.metadata.columns

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Damage")

-- ==================== --
-- Useful Damage Module --
-- ==================== --
--
-- this module uses the data from Damage module and
-- show the "effective" damage and dps by substructing
-- the overkill from the amount of damage done.
--

Skada:RegisterModule("Useful Damage", function(L, P)
	local mod = Skada:NewModule("Useful Damage")
	local playermod = mod:NewModule("Damage spell list")
	local targetmod = mod:NewModule("Damage target list")
	local detailmod = targetmod:NewModule("More Details")
	local mod_cols = nil

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor damage"](label)
	end

	function playermod:Update(win, set)
		win.title = L["actor damage"](win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamage(true)
		local spells = (total and total > 0) and actor.damagespells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime()

		for spellname, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellname, spell)
			d.value = P.absdamage and spell.total or spell.amount
			if spell.o_amt or spell.overkill then
				d.value = max(0, d.value - (spell.o_amt or spell.overkill))
			end

			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's targets"], win.actorname)
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamage(true)
		local targets = (total and total > 0) and actor:GetDamageTargets()

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime()

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, true, targetname)
			d.value = P.absdamage and target.total or target.amount
			if target.o_amt or target.overkill then
				d.value = max(0, d.value - (target.o_amt or target.overkill))
			end

			format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function detailmod:Enter(win, id, label, tooltip)
		win.targetid, win.targetname = id, label
		win.title = format(L["Useful damage on %s"], label)
	end

	function detailmod:Update(win, set)
		win.title = uformat(L["Useful damage on %s"], win.targetname)
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.targetname, win.targetid)
		if not actor then return end

		local sources, total = actor:GetDamageSources()

		if not sources or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime()

		for sourcename, source in pairs(sources) do
			local amount = P.absdamage and source.total or source.amount
			if source.o_amt then
				amount = max(0, amount - source.o_amt)
			end

			if amount > 0 then
				nr = nr + 1

				local d = win:actor(nr, source, true, sourcename)
				d.text = (source.id and not enemy) and Skada:FormatName(sourcename, source.id)
				d.value = amount
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Useful Damage"], L[win.class]) or L["Useful Damage"]

		local total = set and set:GetDamage(true, win.class)
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
				local dps, amount = actor:GetDPS(true)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor)
					d.color = set.__arena and Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN") or nil
					d.value = amount
					format_valuetext(d, mod_cols, total, dps, win.metadata)
				end
			end
		end

		actors = set.__arena and set.enemies or nil -- arena enemies
		if not actors then return end

		for i = 1, #actors do
			local actor = actors[i]
			if actor and not actor.fake and (not win.class or win.class == actor.class) then
				local dps, amount = actor:GetDPS(true)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, true)
					d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")
					d.value = amount
					format_valuetext(d, mod_cols, total, dps, win.metadata)
				end
			end
		end
	end

	function mod:GetSetSummary(set, win)
		if not set then return end
		local dps, amount = set:GetDPS(true, win and win.class)
		local valuetext = Skada:FormatValueCols(
			mod_cols.Damage and Skada:FormatNumber(amount),
			mod_cols.DPS and Skada:FormatNumber(dps)
		)
		return amount, valuetext
	end

	function mod:OnEnable()
		detailmod.metadata = {showspots = true}
		targetmod.metadata = {click1 = detailmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Damage = true, DPS = true, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_shaman_stormearthfire]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Damage")

-- =============== --
-- Overkill Module --
-- =============== --

Skada:RegisterModule("Overkill", function(L, _, _, C)
	local mod = Skada:NewModule("Overkill")
	local spellmod = mod:NewModule("Overkill spell list")
	local targetmod = mod:NewModule("Overkill target list")
	local spelltargetmod = spellmod:NewModule("Overkill target list")
	local targetspellmod = targetmod:NewModule("Overkill spell list")
	local get_spell_overkill_targets = nil
	local mod_cols = nil

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's overkill spells"], label)
	end

	function spellmod:Update(win, set)
		win.title = uformat(L["%s's overkill spells"], win.actorname)
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.overkill
		local spells = (total and total > 0) and actor.damagespells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime()

		for spellname, spell in pairs(actor.damagespells) do
			local o_amt = spell.o_amt or spell.overkill
			if o_amt and o_amt > 0 then
				nr = nr + 1

				local d = win:spell(nr, spellname, spell)
				d.value = o_amt
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's overkill targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = uformat(L["%s's overkill targets"], win.actorname)
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.overkill
		local targets = (total and total > 0) and actor:GetDamageTargets()

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime()

		for targetname, target in pairs(targets) do
			local o_amt = target.o_amt or target.overkill
			if o_amt and o_amt > 0 then
				nr = nr + 1

				local d = win:actor(nr, target, true, targetname)
				d.value = o_amt
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function spelltargetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's overkill targets"], win.actorname)
	end

	function spelltargetmod:Update(win, set)
		win.title = uformat(L["%s's overkill targets"], win.actorname)
		if not win.spellname or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local total, targets = get_spell_overkill_targets(actor, win.spellname)
		if not targets or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime()

		for targetname, target in pairs(targets) do
			if target.o_amt and target.o_amt > 0 then
				nr = nr + 1

				local d = win:actor(nr, target, true, targetname)
				d.value = target.o_amt
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function targetspellmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = uformat(L["%s's overkill spells"], win.actorname)
	end

	function targetspellmod:Update(win, set)
		win.title = uformat(L["%s's overkill spells"], win.actorname)
		if not set or not win.targetname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor or not actor.overkill or actor.overkill == 0 then return end

		local targets = actor:GetDamageTargets()
		local total = targets and targets[win.targetname] and (targets[win.targetname].o_amt or targets[win.targetname].overkill)

		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mod_cols.sDPS and actor:GetTime()

		for spellname, spell in pairs(actor.damagespells) do
			local o_amt = spell.targets and spell.targets[win.targetname] and (spell.targets[win.targetname].o_amt or spell.targets[win.targetname].overkill)
			if o_amt and o_amt > 0 then
				nr = nr + 1

				local d = win:spell(nr, spellname, spell)
				d.value = o_amt
				format_valuetext(d, mod_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Overkill"], L[win.class]) or L["Overkill"]

		local total = set and set:GetOverkill(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor.overkill and (not win.class or win.class == actor.class) then
				nr = nr + 1

				local d = win:actor(nr, actor)
				d.color = set.__arena and Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN") or nil
				d.value = actor.overkill
				format_valuetext(d, mod_cols, total, mod_cols.DPS and (d.value / actor:GetTime()), win.metadata)
			end
		end

		actors = set.__arena and set.enemies or nil -- arena enemies
		if not actors then return end

		for i = 1, #actors do
			local actor = actors[i]
			if actor and not actor.fake and actor.overkill and (not win.class or win.class == actor.class) then
				nr = nr + 1

				local d = win:actor(nr, actor, true)
				d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")
				d.value = actor.overkill
				format_valuetext(d, mod_cols, total, mod_cols.DPS and (d.value / actor:GetTime()), win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set, win)
		local overkill = set:GetOverkill(win and win.class)
		return overkill, Skada:FormatNumber(overkill)
	end

	function mod:OnEnable()
		targetmod.metadata = {click1 = targetspellmod}
		spellmod.metadata = {click1 = spelltargetmod}
		self.metadata = {
			showspots = true,
			click1 = spellmod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Damage = true, DPS = false, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_fire_incinerate]]
		}

		mod_cols = self.metadata.columns

		-- no total click.
		spellmod.nototal = true
		targetmod.nototal = true

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self, L["Damage Done"])
	end

	---------------------------------------------------------------------------

	get_spell_overkill_targets = function(self, spellname, tbl)
		local total = self.overkill
		local spells = (total and total > 0) and self.damagespells

		if not spells then
			return total
		end

		tbl = clear(tbl or C)
		for name, spell in pairs(spells) do
			if spell.targets then
				for targetname, target in pairs(spell.targets) do
					local t = tbl[targetname]
					if not t then
						t = new()
						t.o_amt = target.o_amt or target.overkill
						tbl[targetname] = t
					elseif target.o_amt or target.overkill then
						t.o_amt = (t.o_amt or 0) + (target.o_amt or target.overkill)
					end

					self.super:_fill_actor_table(t, targetname)
				end
			end
		end

		return total, tbl
	end
end, "Damage")
