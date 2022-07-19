local Skada = Skada

local pairs, max = pairs, math.max
local format, pformat = string.format, Skada.pformat
local GetSpellInfo, PercentToRGB = Skada.GetSpellInfo or GetSpellInfo, Skada.PercentToRGB
local _

-- ================== --
-- Damage Done Module --
-- ================== --

Skada:RegisterModule("Damage", function(L, P, _, _, new, del)
	local mod = Skada:NewModule("Damage")
	local playermod = mod:NewModule("Damage spell list")
	local spellmod = playermod:NewModule("Damage spell details")
	local sdetailmod = playermod:NewModule("Damage Breakdown")
	local targetmod = mod:NewModule("Damage target list")
	local tdetailmod = targetmod:NewModule("Damage spell list")
	local UnitGUID, GetTime = UnitGUID, GetTime
	local spellschools = Skada.spellschools
	local ignoredSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local passiveSpells = Skada.dummyTable -- Edit Skada\Core\Tables.lua
	local T = Skada.Table

	-- damage miss types
	local missTypes = Skada.missTypes
	if not missTypes then
		missTypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}
		Skada.missTypes = missTypes
	end

	-- spells on the list below are used to update player's active time
	-- no matter their role or damage amount, since pets aren't considered.
	local whitelist = {}

	local function log_spellcast(set, playerid, playername, playerflags, spellname, spellschool)
		if not set or (set == Skada.total and not P.totalidc) then return end

		local player = Skada:FindPlayer(set, playerid, playername, playerflags)
		if player and player.damagespells then
			local spell = player.damagespells[spellname] or player.damagespells[spellname..L["DoT"]]
			if spell then
				-- because some DoTs don't have an initial damage
				-- we start from 1 and not from 0 if casts wasn't
				-- previously set. Otherwise we just increment.
				spell.casts = (spell.casts or 1) + 1

				-- fix possible missing spell school.
				if not spell.school and spellschool then
					spell.school = spellschool
				end
			end
		end
	end

	local function log_damage(set, dmg, tick)
		local player = Skada:GetPlayer(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if not player then return end

		-- update activity
		if whitelist[dmg.spellid] ~= nil and not dmg.petname then
			Skada:AddActiveTime(set, player, (dmg.amount > 0), tonumber(whitelist[dmg.spellid]), dmg.dstName)
		elseif player.role ~= "HEALER" and not dmg.petname and not passiveSpells[dmg.spellid] then
			Skada:AddActiveTime(set, player, (dmg.amount > 0), tonumber(whitelist[dmg.spellid]), dmg.dstName)
		end

		-- absorbed and overkill
		local absorbed = dmg.absorbed or 0
		local overkill = dmg.overkill or 0

		player.damage = (player.damage or 0) + dmg.amount
		player.totaldamage = (player.totaldamage or 0) + dmg.amount

		set.damage = (set.damage or 0) + dmg.amount
		set.totaldamage = (set.totaldamage or 0) + dmg.amount

		if absorbed > 0 then -- add absorbed damage to total
			player.totaldamage = player.totaldamage + absorbed
			set.totaldamage = set.totaldamage + absorbed
		end

		-- add the damage overkill
		if overkill > 0 then
			set.overkill = (set.overkill or 0) + dmg.overkill
			player.overkill = (player.overkill or 0) + dmg.overkill
		end

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- spell
		local spellname = dmg.spellname .. (tick and L["DoT"] or "")
		local spell = player.damagespells and player.damagespells[spellname]
		if not spell then
			player.damagespells = player.damagespells or {}
			spell = {id = dmg.spellid, school = dmg.spellschool, amount = 0}
			player.damagespells[spellname] = spell
		elseif dmg.spellid and dmg.spellid ~= spell.id then
			if dmg.spellschool and dmg.spellschool ~= spell.school then
				spellname = spellname .. " (" .. (spellschools[dmg.spellschool] and spellschools[dmg.spellschool].name or L["Other"]) .. ")"
			else
				spellname = GetSpellInfo(dmg.spellid)
			end
			if not player.damagespells[spellname] then
				player.damagespells[spellname] = {id = dmg.spellid, school = dmg.spellschool, amount = 0}
			end
			spell = player.damagespells[spellname]
		elseif not spell.school and dmg.spellschool then
			spell.school = dmg.spellschool
		end

		-- start casts count for non DoTs.
		if dmg.spellid ~= 6603 and not tick then
			spell.casts = spell.casts or 1
		end

		spell.count = (spell.count or 0) + 1
		spell.amount = spell.amount + dmg.amount

		if spell.total then
			spell.total = spell.total + dmg.amount + absorbed
		elseif absorbed > 0 then
			spell.total = spell.amount + absorbed
		end

		if overkill > 0 then
			spell.overkill = (spell.overkill or 0) + overkill
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

		-- target
		if dmg.dstName then
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

			if overkill > 0 then
				target.overkill = (target.overkill or 0) + dmg.overkill
			end
		end
	end

	local dmg = {}
	local extraATT

	local function spell_cast(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID and dstGUID then
			local spellid, spellname, spellschool = ...
			if spellid and spellname and not ignoredSpells[spellid] then
				srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)
				Skada:DispatchSets(log_spellcast, srcGUID, srcName, srcFlags, spellname, spellschool)
			end
		end
	end

	local function spell_damage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
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
				dmg.spellid, dmg.spellname, dmg.spellschool, dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing = ...
			end

			if dmg.spellid and dmg.spellname and not ignoredSpells[dmg.spellid] then
				dmg.playerid = srcGUID
				dmg.playername = srcName
				dmg.playerflags = srcFlags

				dmg.dstGUID = dstGUID
				dmg.dstName = dstName
				dmg.dstFlags = dstFlags

				dmg.misstype = nil
				dmg.petname = nil
				Skada:FixPets(dmg)

				Skada:DispatchSets(log_damage, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
			end
		end
	end

	local function spell_missed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local amount

			if eventtype == "SWING_MISSED" then
				dmg.spellid, dmg.spellname, dmg.spellschool = 6603, L["Melee"], 0x01
				dmg.misstype, amount = ...
			else
				dmg.spellid, dmg.spellname, dmg.spellschool, dmg.misstype, amount = ...
			end

			if dmg.spellid and dmg.spellname and not ignoredSpells[dmg.spellid] then
				dmg.playerid = srcGUID
				dmg.playername = srcName
				dmg.playerflags = srcFlags

				dmg.dstGUID = dstGUID
				dmg.dstName = dstName
				dmg.dstFlags = dstFlags

				dmg.amount = 0
				dmg.overkill = 0
				dmg.resisted = nil
				dmg.blocked = nil
				dmg.absorbed = nil
				dmg.critical = nil
				dmg.glancing = nil

				if dmg.misstype == "ABSORB" then
					dmg.absorbed = amount or 0
				elseif dmg.misstype == "BLOCK" then
					dmg.blocked = amount or 0
				elseif dmg.misstype == "RESIST" then
					dmg.resisted = amount or 0
				end

				dmg.petname = nil
				Skada:FixPets(dmg)

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
			local dps, damage = actor:GetDPS()

			tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, totaltime), nil, nil, nil, 1, 1, 1)
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(damage), 1, 1, 1)

			local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
			tooltip:AddDoubleLine(Skada:FormatNumber(damage) .. "/" .. suffix, Skada:FormatNumber(dps), 1, 1, 1)
		end
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagespells and actor.damagespells[enemy and id or label]
		if spell then
			tooltip:AddLine(actor.name .. " - " .. label)
			if spell.school and spellschools[spell.school] then
				tooltip:AddLine(spellschools(spell.school))
			end

			-- show the aura uptime in case of a debuff.
			if actor.GetAuraUptime then
				local uptime, activetime = actor:GetAuraUptime(spell.id)
				if uptime and uptime > 0 then
					uptime = 100 * (uptime / activetime)
					tooltip:AddDoubleLine(L["Uptime"], Skada:FormatPercent(uptime), nil, nil, nil, PercentToRGB(uptime))
				end
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

			if (spell.count or 0) > 1 then
				local amount = P.absdamage and spell.total or spell.amount
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(amount / spell.count), 1, 1, 1)
			end
		end
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] or label == L["Glancing"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetPlayer(win.actorid, win.actorname)
			local spell = actor.damagespells and actor.damagespells[win.spellname]
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
		win.title = L["actor damage"](label)
	end

	function playermod:Update(win, set)
		win.title = L["actor damage"](win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamage() or 0

		if total > 0 and actor.damagespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
			for spellname, spell in pairs(actor.damagespells) do
				nr = nr + 1
				local d = win:spell(nr, spellname, spell)

				d.value = P.absdamage and spell.total or spell.amount
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

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's targets"], win.actorname)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local targets, total = actor:GetDamageTargets()
		if targets and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:actor(nr, target, true, targetname)

				d.value = P.absdamage and target.total or target.amount
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
		return nr
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = pformat("%s: %s", win.actorname, format(L["%s's damage breakdown"], label))
	end

	function spellmod:Update(win, set)
		win.title = pformat("%s: %s", win.actorname, pformat(L["%s's damage breakdown"], win.spellname))
		if not set or not win.spellname then return end

		-- details only available for players
		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagespells and actor.damagespells[enemy and win.spellid or win.spellname]
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

				if spell.casts and spell.casts > 0 then
					nr = add_detail_bar(win, nr, L["Casts"], spell.casts)
					win.dataset[nr].value = win.dataset[nr].value * 1e3 -- to be always first
				end

				if spell.hit and spell.hit > 0 then
					nr = add_detail_bar(win, nr, L["Normal Hits"], spell.hit, spell.count, true)
				end

				if spell.critical and spell.critical > 0 then
					nr = add_detail_bar(win, nr, L["Critical Hits"], spell.critical, spell.count, true)
				end

				if spell.glancing and spell.glancing > 0 then
					nr = add_detail_bar(win, nr, L["Glancing"], spell.glancing, spell.count, true)
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
		win.title = pformat(L["%s's <%s> damage"], win.actorname, label)
	end

	function sdetailmod:Update(win, set)
		win.title = pformat(L["%s's <%s> damage"], win.actorname, win.spellname)
		if not win.spellname then return end

		-- only available for players
		local actor = set and set:GetPlayer(win.actorid, win.actorname)
		local spell = actor and actor.damagespells and actor.damagespells[win.spellname]
		if spell then
			local absorbed = spell.total and (spell.total - spell.amount) or 0
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

			if blocked > 0 then
				nr = add_detail_bar(win, nr, L["BLOCK"], blocked, total, true, true)
			end

			if resisted > 0 then
				nr = add_detail_bar(win, nr, L["RESIST"], resisted, total, true, true)
			end

			if spell.glance and spell.glance > 0 then
				nr = add_detail_bar(win, nr, L["Glancing"], spell.glance, total, true, true)
			end
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

		local total = targets[win.targetname].amount or 0
		if P.absdamage and targets[win.targetname].total then
			total = targets[win.targetname].total
		end

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
			for spellname, spell in pairs(actor.damagespells) do
				if spell.targets and spell.targets[win.targetname] then
					nr = nr + 1
					local d = win:spell(nr, spellname, spell)

					d.value = spell.targets[win.targetname].amount
					if P.absdamage and spell.targets[win.targetname].total then
						d.value = spell.targets[win.targetname].total
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
		win.title = win.class and format("%s (%s)", L["Damage"], L[win.class]) or L["Damage"]

		local total = set and set:GetDamage() or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- players
			for i = 1, #set.players do
				local player = set.players[i]
				if player and (not win.class or win.class == player.class) then
					local dps, amount = player:GetDPS()
					if amount > 0 then
						nr = nr + 1
						local d = win:actor(nr, player)

						if Skada.forPVP and set.type == "arena" then
							d.color = Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN")
						end

						d.value = amount
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.Damage and Skada:FormatNumber(d.value),
							self.metadata.columns.DPS and Skada:FormatNumber(dps),
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
						local dps, amount = enemy:GetDPS()
						if amount > 0 then
							nr = nr + 1
							local d = win:actor(nr, enemy, true)
							d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")

							d.value = amount
							d.valuetext = Skada:FormatValueCols(
								self.metadata.columns.Damage and Skada:FormatNumber(d.value),
								self.metadata.columns.DPS and Skada:FormatNumber(dps),
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

	function mod:AddToTooltip(set, tooltip)
		if not set then return end
		local dps, amount = set:GetDPS()
		tooltip:AddDoubleLine(L["Damage"], Skada:FormatNumber(amount), 1, 1, 1)
		tooltip:AddDoubleLine(L["DPS"], Skada:FormatNumber(dps), 1, 1, 1)
	end

	function mod:GetSetSummary(set)
		local dps, amount = set:GetDPS()
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Damage and Skada:FormatNumber(amount),
			self.metadata.columns.DPS and Skada:FormatNumber(dps)
		)
		return valuetext, amount
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
		if Skada.Ascension then return end

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

	local function dps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if actor then
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
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["DPS"], L[win.class]) or L["DPS"]

		local total = set and set:GetDPS() or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- players
			for i = 1, #set.players do
				local player = set.players[i]
				if player and (not win.class or win.class == player.class) then
					local dps = player:GetDPS()

					if dps > 0 then
						nr = nr + 1
						local d = win:actor(nr, player)

						if Skada.forPVP and set.type == "arena" then
							d.color = Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN")
						end

						d.value = dps
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.DPS and Skada:FormatNumber(d.value),
							self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
						)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end

			-- arena enemies
			if Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyDamage then
				for i = 1, #set.enemies do
					local enemy = set.enemies[i]
					if enemy and not enemy.fake and (not win.class or win.class == enemy.class) then
						local dps = enemy:GetDPS()

						if dps > 0 then
							nr = nr + 1
							local d = win:actor(nr, enemy, true)
							d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")

							d.value = dps
							d.valuetext = Skada:FormatValueCols(
								self.metadata.columns.DPS and Skada:FormatNumber(d.value),
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
			tooltip = dps_tooltip,
			columns = {DPS = true, Percent = true},
			icon = [[Interface\Icons\achievement_bg_topdps]]
		}

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

	function mod:GetSetSummary(set)
		local dps = set:GetDPS()
		return Skada:FormatNumber(dps), dps
	end
end, "Damage")

-- =========================== --
-- Damage Done By Spell Module --
-- =========================== --

Skada:RegisterModule("Damage Done By Spell", function(L, P, _, C, new, _, clear)
	local mod = Skada:NewModule("Damage Done By Spell")
	local sourcemod = mod:NewModule("Damage spell sources")

	local function player_tooltip(win, id, label, tooltip)
		local set = win.spellname and win:GetSelectedSet()
		local player = set and set:GetActor(label, id)
		local spell = player and player.damagespells and player.damagespells[win.spellname]
		if spell then
			tooltip:AddLine(label .. " - " .. win.spellname)

			if spell.casts then
				tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
			end

			if spell.count then
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
	end

	function sourcemod:Enter(win, id, label)
		win.spellname = label
		win.title = format(L["%s's sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = pformat(L["%s's sources"], win.spellname)
		if win.spellname then
			local sources, total = clear(C), 0
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

			if total > 0 then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for playername, player in pairs(sources) do
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
		end
	end

	function mod:Update(win, set)
		win.title = L["Damage Done By Spell"]

		local total = set and set:GetDamage() or 0
		if total == 0 then return end

		local spells = clear(C)
		for i = 1, #set.players do
			local player = set.players[i]
			if player and player.damagespells then
				for spellname, spell in pairs(player.damagespells) do
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

		local settime, nr = self.metadata.columns.DPS and set:GetTime(), 0
		for spellname, spell in pairs(spells) do
			nr = nr + 1
			local d = win:spell(nr, spellname, spell)

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
		sourcemod.metadata = {showspots = true, tooltip = player_tooltip}
		self.metadata = {
			showspots = true,
			click1 = sourcemod,
			columns = {Damage = true, DPS = false, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_nature_lightning]]
		}
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

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor damage"](label)
	end

	function playermod:Update(win, set)
		win.title = L["actor damage"](win.actorname or L["Unknown"])
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamage(true) or 0

		if total > 0 and actor.damagespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
			for spellname, spell in pairs(actor.damagespells) do
				nr = nr + 1
				local d = win:spell(nr, spellname, spell)

				d.value = P.absdamage and spell.total or spell.amount
				if spell.overkill then
					d.value = max(0, d.value - spell.overkill)
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

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's targets"], win.actorname)
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamage(true) or 0
		local targets = (total > 0) and actor:GetDamageTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:actor(nr, target, true, targetname)

				d.value = P.absdamage and target.total or target.amount
				if target.overkill then
					d.value = max(0, d.value - target.overkill)
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

	function detailmod:Enter(win, id, label, tooltip)
		win.targetid, win.targetname = id, label
		win.title = format(L["Useful damage on %s"], label)
	end

	function detailmod:Update(win, set)
		win.title = pformat(L["Useful damage on %s"], win.targetname)
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.targetname, win.targetid)
		if not actor then return end

		local sources, total = actor:GetDamageSources()
		if sources and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
			for sourcename, source in pairs(sources) do
				local amount = source.amount or 0
				if P.absdamage and source.total then
					amount = source.total
				end
				if source.overkill then
					amount = max(0, amount - source.overkill)
				end

				if amount > 0 then
					nr = nr + 1
					local d = win:actor(nr, source, true, sourcename)
					d.text = (source.id and enemy) and Skada:FormatName(sourcename, source.id)

					d.value = amount
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
		win.title = win.class and format("%s (%s)", L["Useful Damage"], L[win.class]) or L["Useful Damage"]

		local total = set and set:GetDamage(true) or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- players
			for i = 1, #set.players do
				local player = set.players[i]
				if player and (not win.class or win.class == player.class) then
					local dps, amount = player:GetDPS(true)

					if amount > 0 then
						nr = nr + 1
						local d = win:actor(nr, player)

						if Skada.forPVP and set.type == "arena" then
							d.color = Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN")
						end

						d.value = amount
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.Damage and Skada:FormatNumber(d.value),
							self.metadata.columns.DPS and Skada:FormatNumber(dps),
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
						local dps, amount = enemy:GetDPS(true)

						if amount > 0 then
							nr = nr + 1
							local d = win:actor(nr, enemy, true)
							d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")

							d.value = amount
							d.valuetext = Skada:FormatValueCols(
								self.metadata.columns.Damage and Skada:FormatNumber(d.value),
								self.metadata.columns.DPS and Skada:FormatNumber(dps),
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

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		if not set then return end
		local dps, amount = set:GetDPS(true)
		local valuetext = Skada:FormatValueCols(
			self.metadata.columns.Damage and Skada:FormatNumber(amount),
			self.metadata.columns.DPS and Skada:FormatNumber(dps)
		)
		return valuetext, amount
	end
end, "Damage")

-- =============== --
-- Overkill Module --
-- =============== --

Skada:RegisterModule("Overkill", function(L)
	local mod = Skada:NewModule("Overkill")
	local playermod = mod:NewModule("Overkill spell list")
	local targetmod = mod:NewModule("Overkill target list")
	local detailmod = targetmod:NewModule("Overkill spell list")

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's overkill spells"], label)
	end

	function playermod:Update(win, set)
		win.title = pformat(L["%s's overkill spells"], win.actorname)
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.overkill or 0
		if total > 0 and actor.damagespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
			for spellname, spell in pairs(actor.damagespells) do
				if spell.overkill and spell.overkill > 0 then
					nr = nr + 1
					local d = win:spell(nr, spellname, spell)

					d.value = spell.overkill
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

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's overkill targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = pformat(L["%s's overkill targets"], win.actorname)
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.overkill or 0
		local targets = (total > 0) and actor:GetDamageTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
			for targetname, target in pairs(targets) do
				if target.overkill and target.overkill > 0 then
					nr = nr + 1
					local d = win:actor(nr, target, true, targetname)

					d.value = target.overkill
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

	function detailmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = pformat(L["%s's overkill spells"], win.actorname)
	end

	function detailmod:Update(win, set)
		win.title = pformat(L["%s's overkill spells"], win.actorname)
		if not set or not win.targetname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor or not actor.overkill or actor.overkill == 0 then return end

		local targets = actor:GetDamageTargets()
		local total = (targets and targets[win.targetname]) and targets[win.targetname].overkill or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local actortime, nr = mod.metadata.columns.sDPS and actor:GetTime(), 0
			for spellname, spell in pairs(actor.damagespells) do
				if spell.targets and spell.targets[win.targetname] and spell.targets[win.targetname].overkill and spell.targets[win.targetname].overkill > 0 then
					nr = nr + 1
					local d = win:spell(nr, spellname, spell)

					d.value = spell.targets[win.targetname].overkill
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
		win.title = win.class and format("%s (%s)", L["Overkill"], L[win.class]) or L["Overkill"]

		local total = set:GetOverkill()
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- players
			for i = 1, #set.players do
				local player = set.players[i]
				if player and player.overkill and (not win.class or win.class == player.class) then
					nr = nr + 1
					local d = win:actor(nr, player)

					if Skada.forPVP and set.type == "arena" then
						d.color = Skada.classcolors(set.gold and "ARENA_GOLD" or "ARENA_GREEN")
					end

					d.value = player.overkill
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Damage and Skada:FormatNumber(d.value),
						self.metadata.columns.DPS and Skada:FormatNumber(d.value / max(1, player:GetTime())),
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			-- arena enemies
			if Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyOverkill then
				for i = 1, #set.enemies do
					local enemy = set.enemies[i]
					if enemy and not enemy.fake and enemy.overkill and (not win.class or win.class == enemy.class) then
						nr = nr + 1
						local d = win:actor(nr, enemy, true)
						d.color = Skada.classcolors(set.gold and "ARENA_GREEN" or "ARENA_GOLD")

						d.value = enemy.overkill
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.Damage and Skada:FormatNumber(d.value),
							self.metadata.columns.DPS and Skada:FormatNumber(d.value / max(1, enemy:GetTime())),
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

	function mod:OnEnable()
		targetmod.metadata = {click1 = detailmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Damage = true, DPS = false, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_fire_incinerate]]
		}

		-- no total click.
		playermod.nototal = true
		targetmod.nototal = true

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self, L["Damage Done"])
	end

	function mod:GetSetSummary(set)
		local overkill = set:GetOverkill()
		return Skada:FormatNumber(overkill), overkill
	end
end, "Damage")
