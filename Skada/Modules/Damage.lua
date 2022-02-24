local Skada = Skada

local format, max = string.format, math.max
local pairs, select = pairs, select
local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local cacheTable, T = Skada.cacheTable, Skada.Table
local PercentToRGB = Skada.PercentToRGB
local misstypes = Skada.missTypes
local _

-- list of miss types

-- ================== --
-- Damage Done Module --
-- ================== --

Skada:AddLoadableModule("Damage", function(L)
	if Skada:IsDisabled("Damage") then return end

	local mod = Skada:NewModule(L["Damage"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local spellmod = playermod:NewModule(L["Damage spell details"])
	local sdetailmod = playermod:NewModule(L["Damage Breakdown"])
	local targetmod = mod:NewModule(L["Damage target list"])
	local tdetailmod = targetmod:NewModule(L["Damage spell list"])
	local UnitGUID, tContains = UnitGUID, tContains
	local new, del = Skada.TablePool()

	-- spells on the list below are ignored when it comes
	-- to updating player's active time.
	local blacklist = {
		[7294] = true, -- Retribution Aura (Rank 1)
		[10298] = true, -- Retribution Aura (Rank 2)
		[10299] = true, -- Retribution Aura (Rank 3)
		[10300] = true, -- Retribution Aura (Rank 4)
		[10301] = true, -- Retribution Aura (Rank 5)
		[27150] = true, -- Retribution Aura (Rank 6)
		[54043] = true, -- Retribution Aura (Rank 7)
		[30482] = true, -- Molten Armor (Rank 1)
		[43045] = true, -- Molten Armor (Rank 2)
		[43046] = true, -- Molten Armor (Rank 3)
		[324] = true, -- Lightning Shield (Rank 1)
		[325] = true, -- Lightning Shield (Rank 2)
		[905] = true, -- Lightning Shield (Rank 3)
		[945] = true, -- Lightning Shield (Rank 4)
		[8134] = true, -- Lightning Shield (Rank 5)
		[10431] = true, -- Lightning Shield (Rank 6)
		[10432] = true, -- Lightning Shield (Rank 7)
		[25469] = true, -- Lightning Shield (Rank 8)
		[25472] = true, -- Lightning Shield (Rank 9)
		[49280] = true, -- Lightning Shield (Rank 10)
		[49281] = true, -- Lightning Shield (Rank 11)
		[2947] = true, -- Fire Shield (Rank 1)
		[8316] = true, -- Fire Shield (Rank 2)
		[8317] = true, -- Fire Shield (Rank 3)
		[11770] = true, -- Fire Shield (Rank 4)
		[11771] = true, -- Fire Shield (Rank 5)
		[27269] = true, -- Fire Shield (Rank 6)
		[47983] = true -- Fire Shield (Rank 7)
	}

	-- spells on the list below are used to update player's active time
	-- no matter their role or damage amount, since pets aren't considered.
	local whitelist = {
		-- The Oculus
		[49840] = true, -- Shock Lance (Amber Drake)
		[50232] = true, -- Searing Wrath (Ruby Drake)
		[50341] = true, -- Touch the Nightmare (Emerald Drake)
		[50344] = true, -- Dream Funnel (Emerald Drake)
		-- Eye of Eternity: Wyrmrest Skytalon
		[56091] = true, -- Flame Spike
		[56092] = true, -- Engulf in Flames
		-- Naxxramas: Instructor Razuvious
		[61696] = true, -- Blood Strike (Death Knight Understudy)
		-- Ulduar - Flame Leviathan
		[62306] = true, -- Salvaged Demolisher: Hurl Boulder
		[62308] = true, -- Salvaged Demolisher: Ram
		[62490] = true, -- Salvaged Demolisher: Hurl Pyrite Barrel
		[62634] = true, -- Salvaged Demolisher Mechanic Seat: Mortar
		[64979] = true, -- Salvaged Demolisher Mechanic Seat: Anti-Air Rocket
		[62345] = true, -- Salvaged Siege Engine: Ram
		[62346] = true, -- Salvaged Siege Engine: Steam Rush
		[62522] = true, -- Salvaged Siege Engine: Electroshock
		[62358] = true, -- Salvaged Siege Turret: Fire Cannon
		[62359] = true, -- Salvaged Siege Turret: Anti-Air Rocket
		[62974] = true, -- Salvaged Chopper: Sonic Horn
		-- Icecrown Citadel
		[69399] = true, -- Cannon Blast (Gunship Battle Cannons)
		[70175] = true, -- Incinerating Blast (Gunship Battle Cannons)
		[70539] = 5.5, -- Regurgitated Ooze (Mutated Abomination)
		[70542] = true -- Mutated Slash (Mutated Abomination)
	}

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_spellcast(set, dmg)
		local player = Skada:GetPlayer(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if player and player.damagespells then
			local spell = player.damagespells[dmg.spellname] or player.damagespells[dmg.spellname..L["DoT"]]
			if spell then
				-- because some DoTs don't have an initial damage
				-- we start from 1 and not from 0 if casts wasn't
				-- previously set. Otherwise we just increment.
				spell.casts = (spell.casts or 1) + 1

				-- fix possible missing spell school.
				if not spell.school and dmg.spellschool then
					spell.school = dmg.spellschool
				end
			end
		end
	end

	local function log_damage(set, dmg, tick)
		local player = Skada:GetPlayer(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if not player then return end

		-- update activity
		if whitelist[dmg.spellid] ~= nil then
			Skada:AddActiveTime(player, (dmg.amount > 0), tonumber(whitelist[dmg.spellid]))
		elseif player.role ~= "HEALER" and not dmg.petname then
			Skada:AddActiveTime(player, (dmg.amount > 0 and not blacklist[dmg.spellid]))
		end

		-- add absorbed damage to total damage
		local absorbed = dmg.absorbed or 0

		player.damage = (player.damage or 0) + dmg.amount
		player.totaldamage = (player.totaldamage or 0) + dmg.amount + absorbed

		set.damage = (set.damage or 0) + dmg.amount
		set.totaldamage = (set.totaldamage or 0) + dmg.amount + absorbed

		-- add the damage overkill
		if (dmg.overkill or 0) > 0 then
			set.overkill = (set.overkill or 0) + dmg.overkill
			player.overkill = (player.overkill or 0) + dmg.overkill
		end

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total then return end

		-- spell
		local spellname = dmg.spellname .. (tick and L["DoT"] or "")
		local spell = player.damagespells and player.damagespells[spellname]
		if not spell then
			player.damagespells = player.damagespells or {}
			spell = {id = dmg.spellid, school = dmg.spellschool, amount = 0, total = 0}
			player.damagespells[spellname] = spell
		elseif dmg.spellid and dmg.spellid ~= spell.id then
			if dmg.spellschool and dmg.spellschool ~= spell.school then
				spellname = spellname .. " (" .. (Skada.spellschools[dmg.spellschool] and Skada.spellschools[dmg.spellschool].name or OTHER) .. ")"
			else
				spellname = GetSpellInfo(dmg.spellid)
			end
			if not player.damagespells[spellname] then
				player.damagespells[spellname] = {id = dmg.spellid, school = dmg.spellschool, amount = 0, total = 0}
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
		spell.total = spell.total + dmg.amount

		if (dmg.overkill or 0) > 0 then
			spell.overkill = (spell.overkill or 0) + dmg.overkill
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

		if (dmg.blocked or 0) > 0 then
			spell.blocked = (spell.blocked or 0) + dmg.blocked
		end

		if (dmg.resisted or 0) > 0 then
			spell.resisted = (spell.resisted or 0) + dmg.resisted
		end

		-- target
		if dmg.dstName then
			-- we make sure to record the target!
			local actor = Skada:GetActor(set, dmg.dstGUID, dmg.dstName, dmg.dstFlags)
			if not actor then return end
			local target = spell.targets and spell.targets[dmg.dstName]
			if not target then
				spell.targets = spell.targets or {}
				spell.targets[dmg.dstName] = {amount = 0, total = 0}
				target = spell.targets[dmg.dstName]
			end
			target.amount = target.amount + dmg.amount
			target.total = target.total + dmg.amount + absorbed
			if (dmg.overkill or 0) > 0 then
				target.overkill = (target.overkill or 0) + dmg.overkill
			end
		end
	end

	local dmg = {}
	local extraATT

	local function SpellCast(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID and dstGUID then
			dmg.spellid, dmg.spellname, dmg.spellschool = ...
			if dmg.spellid and dmg.spellname and not tContains(ignoredSpells, dmg.spellid) then
				dmg.playerid = srcGUID
				dmg.playerflags = srcFlags
				dmg.playername = srcName

				dmg.dstGUID = dstGUID
				dmg.dstName = dstName
				dmg.dstFlags = dstFlags

				dmg.amount = nil
				dmg.overkill = nil
				dmg.resisted = nil
				dmg.blocked = nil
				dmg.absorbed = nil
				dmg.critical = nil
				dmg.glancing = nil
				dmg.misstype = nil
				dmg.petname = nil

				Skada:FixPets(dmg)

				Skada:DispatchSets(log_spellcast, dmg)
			end
		end
	end

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			-- handle extra attacks
			if eventtype == "SPELL_EXTRA_ATTACKS" then
				local spellid, spellname, _, amount = ...

				if spellid and spellname and not tContains(ignoredSpells, spellid) then
					extraATT = extraATT or T.get("Damage_ExtraAttacks")
					if not extraATT[srcName] then
						extraATT[srcName] = new()
						extraATT[srcName].spellname = spellname
						extraATT[srcName].amount = amount
					end
				end

				return
			end

			if eventtype == "SWING_DAMAGE" then
				dmg.spellid, dmg.spellname, dmg.spellschool = 6603, L.Melee, 0x01
				dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing = ...

				-- an extra attack?
				if extraATT and extraATT[srcName] then
					dmg.spellname = dmg.spellname .. " (" .. extraATT[srcName].spellname .. ")"
					extraATT[srcName].amount = max(0, extraATT[srcName].amount - 1)
					if extraATT[srcName].amount == 0 then
						extraATT[srcName] = del(extraATT[srcName])
					end
				end
			else
				dmg.spellid, dmg.spellname, dmg.spellschool, dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing = ...
			end

			if dmg.spellid and dmg.spellname and not tContains(ignoredSpells, dmg.spellid) then
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
				log_damage(Skada.total, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
			end
		end
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local amount

			if eventtype == "SWING_MISSED" then
				dmg.spellid, dmg.spellname, dmg.spellschool = 6603, L.Melee, 0x01
				dmg.misstype, amount = ...
			else
				dmg.spellid, dmg.spellname, dmg.spellschool, dmg.misstype, amount = ...
			end

			if dmg.spellid and dmg.spellname and not tContains(ignoredSpells, dmg.spellid) then
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
				log_damage(Skada.total, dmg, eventtype == "SPELL_PERIODIC_MISSED")
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

			local suffix = Skada:FormatTime(Skada.db.profile.timemesure == 1 and activetime or totaltime)
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
			if spell.school and Skada.spellschools[spell.school] then
				tooltip:AddLine(
					Skada.spellschools[spell.school].name,
					Skada.spellschools[spell.school].r,
					Skada.spellschools[spell.school].g,
					Skada.spellschools[spell.school].b
				)
			end

			if (spell.casts or 0) > 0 then
				tooltip:AddDoubleLine(L["Casts"], spell.casts, 1, 1, 1)
			end

			local amount = Skada.db.profile.absdamage and spell.total or spell.amount
			if (spell.count or 0) > 0 then
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(amount / spell.count), 1, 1, 1)
			else
				tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(amount), 1, 1, 1)
			end

			-- show the aura uptime in case of a debuff.
			if actor.GetAuraUptime then
				local uptime, activetime = actor:GetAuraUptime(spell.id)
				if (uptime or 0) > 0 then
					uptime = 100 * (uptime / activetime)
					tooltip:AddDoubleLine(L["Uptime"], Skada:FormatPercent(uptime), nil, nil, nil, PercentToRGB(uptime))
				end
			end

			if spell.hitmin and spell.hitmax then
				local spellmin = spell.hitmin
				if spell.criticalmin and spell.criticalmin < spellmin then
					spellmin = spell.criticalmin
				end
				local spellmax = spell.hitmax
				if spell.criticalmax and spell.criticalmax > spellmax then
					spellmax = spell.criticalmax
				end
				tooltip:AddLine(" ")
				tooltip:AddDoubleLine(L["Minimum Hit"], Skada:FormatNumber(spellmin), 1, 1, 1)
				tooltip:AddDoubleLine(L["Maximum Hit"], Skada:FormatNumber(spellmax), 1, 1, 1)
				tooltip:AddDoubleLine(L["Average Hit"], Skada:FormatNumber((spellmin + spellmax) / 2), 1, 1, 1)
			end
		end
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetPlayer(win.actorid, win.actorname)
			local spell = actor.damagespells and actor.damagespells[win.spellname]
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
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's damage"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's damage"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamage() or 0


		if total > 0 and actor.damagespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellname, spell in pairs(actor.damagespells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellname
				d.spellschool = spell.school

				if enemy then
					d.spellid = spellname
					d.label, _, d.icon = GetSpellInfo(spellname)
				else
					d.spellid = spell.id
					d.label = spellname
					d.icon = select(3, GetSpellInfo(spell.id))
				end

				d.value = Skada.db.profile.absdamage and spell.total or spell.amount
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = format(L["%s's targets"], win.actorname or L.Unknown)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local total = actor:GetDamage()
		local targets = (total > 0) and actor:GetDamageTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = Skada.db.profile.absdamage and target.total or target.amount
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	local function add_detail_bar(win, nr, title, value, total, percent, fmt)
		nr = nr + 1

		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = title
		d.label = title
		d.value = value
		d.valuetext = Skada:FormatValueCols(
			mod.metadata.columns.Damage and (fmt and Skada:FormatNumber(value) or value),
			(mod.metadata.columns.Percent and percent) and Skada:FormatPercent(d.value, total)
		)
		return nr
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format("%s: %s", win.actorname or L.Unknown, format(L["%s's damage breakdown"], label))
	end

	function spellmod:Update(win, set)
		win.title = format("%s: %s", win.actorname or L.Unknown, format(L["%s's damage breakdown"], win.spellname or L.Unknown))
		if not set or not win.spellname then return end

		-- details only available for players
		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagespells and actor.damagespells[enemy and win.spellid or win.spellname]
		if spell then
			if win.metadata then
				if enemy then
					win.metadata.maxvalue = Skada.db.profile.absdamage and spell.total or spell.amount or 0
				else
					win.metadata.maxvalue = spell.count
				end
			end

			if enemy then
				local amount = Skada.db.profile.absdamage and spell.total or spell.amount
				local nr = add_detail_bar(win, 0, L["Damage"], amount, nil, nil, true)

				if spell.total ~= spell.amount then
					nr = add_detail_bar(win, nr, L["ABSORB"], spell.total - spell.amount, nil, nil, true)
				end
			else
				local nr = add_detail_bar(win, 0, L["Hits"], spell.count)
				win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

				if (spell.casts or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Casts"], spell.casts)
					win.dataset[nr].value = win.dataset[nr].value * 1e3 -- to be always first
				end

				if (spell.hit or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Normal Hits"], spell.hit, spell.count, true)
				end

				if (spell.critical or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Critical Hits"], spell.critical, spell.count, true)
				end

				if (spell.glancing or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Glancing"], spell.glancing, spell.count, true)
				end

				for _, misstype in ipairs(misstypes) do
					if (spell[misstype] or 0) > 0 then
						nr = add_detail_bar(win, nr, L[misstype], spell[misstype], spell.count, true)
					end
				end
			end
		end
	end

	function sdetailmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's <%s> damage"], win.actorname or L.Unknown, label)
	end

	function sdetailmod:Update(win, set)
		win.title = format(L["%s's <%s> damage"], win.actorname or L.Unknown, win.spellname or L.Unknown)
		if not win.spellname then return end

		-- only available for players
		local actor = set and set:GetPlayer(win.actorid, win.actorname)
		local spell = actor and actor.damagespells and actor.damagespells[win.spellname]
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

			if (spell.overkill or 0) > 0 then
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
		end
	end

	function tdetailmod:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = format(L["%s's damage on %s"], win.actorname or L.Unknown, label)
	end

	function tdetailmod:Update(win, set)
		win.title = format(L["%s's damage on %s"], win.actorname or L.Unknown, win.targetname or L.Unknown)
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local targets = actor and actor:GetDamageTargets()
		if targets then
			local total = targets[win.targetname] and targets[win.targetname].amount or 0
			if Skada.db.profile.absdamage and targets[win.targetname].total then
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

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						if enemy then
							d.spellid = spellname
							d.label, _, d.icon = GetSpellInfo(spellname)
							d.id = d.label
						else
							d.id = spellname
							d.spellid = spell.id
							d.label = spellname
							d.icon = select(3, GetSpellInfo(spell.id))
						end

						d.spellschool = spell.school

						d.value = spell.targets[win.targetname].amount
						if Skada.db.profile.absdamage then
							d.value = spell.targets[win.targetname].total or d.value
						end

						d.valuetext = Skada:FormatValueCols(
							mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
							mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = win.class and format("%s (%s)", L["Damage"], L[win.class]) or L["Damage"]

		local total = set and set:GetDamage() or 0

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- players
			for _, player in ipairs(set.players) do
				if not win.class or win.class == player.class then
					local dps, amount = player:GetDPS()
					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						if Skada.forPVP and set.type == "arena" then
							d.color = set.gold and Skada.classcolors.ARENA_GOLD or Skada.classcolors.ARENA_GREEN
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
				for _, enemy in ipairs(set.enemies) do
					if not win.class or win.class == enemy.class then
						local dps, amount = enemy:GetDPS()
						if amount > 0 then
							nr = nr + 1

							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = enemy.id or enemy.name
							d.label = enemy.name
							d.text = nil
							d.class = enemy.class
							d.role = enemy.role
							d.spec = enemy.spec
							d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.ARENA_GOLD

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
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod, targetmod},
			columns = {Damage = true, DPS = true, Percent = true},
			icon = [[Interface\Icons\spell_fire_firebolt]]
		}

		local compare = Skada:GetModule(L["Comparison"], true)
		if compare then
			self.metadata.click3 = compare.SetActor
			self.metadata.click3_label = L["Damage Comparison"]
			tinsert(self.metadata.nototalclick, compare)
		end

		local flags_src_dst = {src_is_interesting = true, dst_is_not_interesting = true}

		Skada:RegisterForCL(
			SpellCast,
			"SPELL_CAST_START",
			"SPELL_CAST_SUCCESS",
			flags_src_dst
		)

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
			flags_src_dst
		)

		Skada:RegisterForCL(
			SpellMissed,
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED",
			flags_src_dst
		)

		Skada:AddFeed(L["Damage: Personal DPS"], feed_personal_dps)
		Skada:AddFeed(L["Damage: Raid DPS"], feed_raid_dps)

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
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
		if not set then return end
		local dps, amount = set:GetDPS()
		return Skada:FormatValueCols(
			self.metadata.columns.Damage and Skada:FormatNumber(amount),
			self.metadata.columns.DPS and Skada:FormatNumber(dps)
		), amount
	end

	function mod:SetComplete(set)
		T.clear(dmg)
		T.free("Damage_ExtraAttacks", extraATT)

		-- clean set from garbage before it is saved.
		if (set.totaldamage or 0) == 0 then return end
		for _, p in ipairs(set.players) do
			if p.totaldamage and p.totaldamage == 0 then
				p.damagespells = nil
			elseif p.damagespells then
				for spellname, spell in pairs(p.damagespells) do
					if (spell.total or 0) == 0 or (spell.count or 0) == 0 then
						p.damagespells[spellname] = nil
					end
				end
				-- nothing left?
				if next(p.damagespells) == nil then
					p.damagespells = nil
				end
			end
		end
	end

	function mod:OnInitialize()
		Skada.options.args.tweaks.args.general.args.absdamage = {
			type = "toggle",
			name = L["Absorbed Damage"],
			desc = L["Enable this if you want the damage absorbed to be included in the damage done."],
			order = 100
		}
	end
end)

-- ============================= --
-- Damage done per second module --
-- ============================= --

Skada:AddLoadableModule("DPS", function(L)
	if Skada:IsDisabled("Damage", "DPS") then return end

	local mod = Skada:NewModule(L["DPS"])

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

			local suffix = Skada:FormatTime(Skada.db.profile.timemesure == 1 and activetime or totaltime)
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
			for _, player in ipairs(set.players) do
				if not win.class or win.class == player.class then
					local dps = player:GetDPS()

					if dps > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						if Skada.forPVP and set.type == "arena" then
							d.color = set.gold and Skada.classcolors.ARENA_GOLD or Skada.classcolors.ARENA_GREEN
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
				for _, enemy in ipairs(set.enemies) do
					if not win.class or win.class == enemy.class then
						local dps = enemy:GetDPS()

						if dps > 0 then
							nr = nr + 1

							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = enemy.id or enemy.name
							d.label = enemy.name
							d.text = nil
							d.class = enemy.class
							d.role = enemy.role
							d.spec = enemy.spec
							d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.ARENA_GOLD

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

		local parentmod = Skada:GetModule(L["Damage"], true)
		if parentmod then
			self.metadata.click1 = parentmod.metadata.click1
			self.metadata.click2 = parentmod.metadata.click2
			self.metadata.nototalclick = parentmod.metadata.nototalclick
			self.metadata.click4 = parentmod.metadata.click4
			self.metadata.click4_label = parentmod.metadata.click4_label
		end

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self, L["Damage Done"])
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set and set:GetDPS() or 0)
	end
end)

-- =========================== --
-- Damage Done By Spell Module --
-- =========================== --

Skada:AddLoadableModule("Damage Done By Spell", function(L)
	if Skada:IsDisabled("Damage", "Damage Done By Spell") then return end

	local mod = Skada:NewModule(L["Damage Done By Spell"])
	local sourcemod = mod:NewModule(L["Damage spell sources"])

	function sourcemod:Enter(win, id, label)
		win.spellname = label
		win.title = format(L["%s's sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = format(L["%s's sources"], win.spellname or L.Unknown)
		if win.spellname then
			wipe(cacheTable)
			local total = 0

			for _, player in ipairs(set.players) do
				if
					player.damagespells and
					player.damagespells[win.spellname] and
					(player.damagespells[win.spellname].total or 0) > 0
				then
					cacheTable[player.name] = {
						id = player.id,
						class = player.class,
						role = player.role,
						spec = player.spec,
						amount = player.damagespells[win.spellname].amount
					}
					if Skada.db.profile.absdamage then
						cacheTable[player.name].amount = player.damagespells[win.spellname].total
					end

					total = total + cacheTable[player.name].amount
				end
			end

			if total > 0 then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for playername, player in pairs(cacheTable) do
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or playername
					d.label = playername
					d.text = player.id and Skada:FormatName(playername, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.amount
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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

		wipe(cacheTable)

		for _, player in ipairs(set.players) do
			if player.damagespells then
				for spellname, spell in pairs(player.damagespells) do
					if spell.total > 0 then
						if not cacheTable[spellname] then
							cacheTable[spellname] = {id = spell.id, school = spell.school, amount = 0}
						end
						if Skada.db.profile.absdamage then
							cacheTable[spellname].amount = cacheTable[spellname].amount + spell.total
						else
							cacheTable[spellname].amount = cacheTable[spellname].amount + spell.amount
						end
					end
				end
			end
		end

		if win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for spellname, spell in pairs(cacheTable) do
			nr = nr + 1

			local d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.id = spellname
			d.spellid = spell.id
			d.label = spellname
			d.icon = select(3, GetSpellInfo(spell.id))
			d.spellschool = spell.school

			d.value = spell.amount
			d.valuetext = Skada:FormatValueCols(
				self.metadata.columns.Damage and Skada:FormatNumber(d.value),
				self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
			)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end
	end

	function mod:OnEnable()
		sourcemod.metadata = {showspots = true}
		self.metadata = {
			showspots = true,
			click1 = sourcemod,
			columns = {Damage = true, Percent = true},
			icon = [[Interface\Icons\spell_nature_lightning]]
		}
		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)

-- ==================== --
-- Useful Damage Module --
-- ==================== --
--
-- this module uses the data from Damage module and
-- show the "effective" damage and dps by substructing
-- the overkill from the amount of damage done.
--

Skada:AddLoadableModule("Useful Damage", function(L)
	if Skada:IsDisabled("Damage", "Useful Damage") then return end

	local mod = Skada:NewModule(L["Useful Damage"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local targetmod = mod:NewModule(L["Damage target list"])
	local detailmod = targetmod:NewModule(L["More Details"])

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's damage"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's damage"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamage(true) or 0

		if total > 0 and actor.damagespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellname, spell in pairs(actor.damagespells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				if enemy then
					d.spellid = spellname
					d.label, _, d.icon = GetSpellInfo(spellname)
					d.id = d.label
				else
					d.id = spellname
					d.spellid = spell.id
					d.label = spellname
					d.icon = select(3, GetSpellInfo(spell.id))
				end

				d.spellschool = spell.school

				d.value = Skada.db.profile.absdamage and spell.total or spell.amount
				if spell.overkill then
					d.value = max(0, d.value - spell.overkill)
				end

				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = format(L["%s's targets"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor:GetDamage(true) or 0
		local targets = (total > 0) and actor:GetDamageTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = Skada.db.profile.absdamage and target.total or target.amount
				if target.overkill then
					d.value = max(0, d.value - target.overkill)
				end

				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = format(L["Useful damage on %s"], win.targetname or L.Unknown)
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.targetname, win.targetid)
		local total = actor and actor:GetDamageTaken() or 0
		local sources = (total > 0) and actor:GetDamageSources()

		if sources then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for sourcename, source in pairs(sources) do
				local amount = source.amount or 0
				if Skada.db.profile.absdamage and source.total then
					amount = source.total
				end
				if sources.overkill then
					amount = max(0, amount - source.overkill)
				end

				if amount > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = source.id or sourcename
					d.label = sourcename
					d.text = (source.id and enemy) and Skada:FormatName(sourcename, source.id)
					d.class = source.class
					d.role = source.role
					d.spec = source.spec

					d.value = amount
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
			for _, player in ipairs(set.players) do
				if not win.class or win.class == player.class then
					local dps, amount = player:GetDPS(true)

					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						if Skada.forPVP and set.type == "arena" then
							d.color = set.gold and Skada.classcolors.ARENA_GOLD or Skada.classcolors.ARENA_GREEN
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
				for _, enemy in ipairs(set.enemies) do
					if not win.class or win.class == enemy.class then
						local dps, amount = enemy:GetDPS(true)

						if amount > 0 then
							nr = nr + 1

							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = enemy.id or enemy.name
							d.label = enemy.name
							d.text = nil
							d.class = enemy.class
							d.role = enemy.role
							d.spec = enemy.spec
							d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.ARENA_GOLD

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
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod, targetmod},
			columns = {Damage = true, DPS = true, Percent = true},
			icon = [[Interface\Icons\spell_shaman_stormearthfire]]
		}
		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		if not set then return end
		local dps, damage = set:GetDPS(true)
		return Skada:FormatValueCols(
			self.metadata.columns.Damage and Skada:FormatNumber(damage),
			self.metadata.columns.DPS and Skada:FormatNumber(dps)
		), damage
	end
end)

-- =============== --
-- Overkill Module --
-- =============== --

Skada:AddLoadableModule("Overkill", function(L)
	if Skada:IsDisabled("Damage", "Overkill") then return end

	local mod = Skada:NewModule(L["Overkill"])
	local playermod = mod:NewModule(L["Overkill spell list"])
	local targetmod = mod:NewModule(L["Overkill target list"])
	local detailmod = targetmod:NewModule(L["Overkill spell list"])

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's overkill spells"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's overkill spells"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.overkill or 0
		if total > 0 and actor.damagespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellname, spell in pairs(actor.damagespells) do
				if (spell.overkill or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					if enemy then
						d.spellid = spellname
						d.label, _, d.icon = GetSpellInfo(spellname)
						d.id = d.label
					else
						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						d.icon = select(3, GetSpellInfo(spell.id))
					end

					d.spellschool = spell.school

					d.value = spell.overkill
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = format(L["%s's overkill targets"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = actor and actor.overkill or 0
		local targets = (total > 0) and actor:GetDamageTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				if (target.overkill or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class = target.class
					d.role = target.role
					d.spec = target.spec

					d.value = target.overkill
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = format(L["%s's overkill spells"], win.actorname or L.Unknown)
	end

	function detailmod:Update(win, set)
		win.title = format(L["%s's overkill spells"], win.actorname or L.Unknown)
		if not set or not win.targetname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor or (actor.overkill or 0) == 0 then return end

		local targets = actor:GetDamageTargets()
		local total = (targets and targets[win.targetname]) and targets[win.targetname].overkill or 0

		if total > 0 and actor.damagespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellname, spell in pairs(actor.damagespells) do
				if spell.targets and spell.targets[win.targetname] and (spell.targets[win.targetname].overkill or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					if enemy then
						d.spellid = spellname
						d.label, _, d.icon = GetSpellInfo(spellname)
						d.id = d.label
					else
						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						d.icon = select(3, GetSpellInfo(spell.id))
					end

					d.spellschool = spell.school

					d.value = spell.targets[win.targetname].overkill
					d.valuetext = Skada:FormatValueCols(
						mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
						mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.overkill or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					if Skada.forPVP and set.type == "arena" then
						d.color = set.gold and Skada.classcolors.ARENA_GOLD or Skada.classcolors.ARENA_GREEN
					end

					d.value = player.overkill
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Damage and Skada:FormatNumber(d.value),
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			-- arena enemies
			if Skada.forPVP and set.type == "arena" and set.enemies and set.GetEnemyOverkill then
				for _, enemy in ipairs(set.enemies) do
					if (not win.class or win.class == enemy.class) and (enemy.overkill or 0) > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = enemy.id or enemy.name
						d.label = enemy.name
						d.text = nil
						d.class = enemy.class
						d.role = enemy.role
						d.spec = enemy.spec
						d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.v

						d.value = enemy.overkill
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.Damage and Skada:FormatNumber(d.value),
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
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod, targetmod},
			columns = {Damage = true, Percent = true},
			icon = [[Interface\Icons\spell_fire_incinerate]]
		}
		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self, L["Damage Done"])
	end

	function mod:GetSetSummary(set)
		local overkill = set:GetOverkill()
		return Skada:FormatNumber(overkill), overkill
	end
end)

-- ====================== --
-- Absorbed Damage Module --
-- ====================== --

Skada:AddLoadableModule("Absorbed Damage", function(L)
	if Skada:IsDisabled("Damage", "Absorbed Damage") then return end

	local mod = Skada:NewModule(L["Absorbed Damage"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local targetmod = mod:NewModule(L["Damage target list"])

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's damage"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's damage"], win.actorname or L.Unknown)
		if not set or not win.actorname then return end

		local actor, enemy = set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local total = (actor.totaldamage and actor.damage) and max(0, actor.totaldamage - actor.damage) or 0
		if total > 0 and actor.damagespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellname, spell in pairs(actor.damagespells) do
				if spell.total and spell.amount then
					local amount = max(0, spell.total - spell.amount)
					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						if enemy then
							d.spellid = spellname
							d.label, _, d.icon = GetSpellInfo(spellname)
							d.id = d.label
						else
							d.id = spellname
							d.spellid = spell.id
							d.label = spellname
							d.icon = select(3, GetSpellInfo(spell.id))
						end

						d.spellschool = spell.school

						d.value = amount
						d.valuetext = Skada:FormatValueCols(
							mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
							mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
						)

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
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's targets"], win.actorname or L.Unknown)

		local actor = set and set:GetActor(win.actorname, win.actorid)
		if not actor then return end

		local total = (actor.totaldamage and actor.damage) and max(0, actor.totaldamage - actor.damage) or 0
		local targets = (total > 0) and actor:GetDamageTargets()
		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				if target.total and target.amount then
					local amount = max(0, target.total - target.amount)
					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = target.id or targetname
						d.label = targetname
						d.class = target.class
						d.role = target.role
						d.spec = target.spec

						d.value = amount
						d.valuetext = Skada:FormatValueCols(
							mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
							mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
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
		win.title = win.class and format("%s (%s)", L["Absorbed Damage"], L[win.class]) or L["Absorbed Damage"]

		local total = set and set:GetAbsorbedDamage() or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- players.
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and player.totaldamage and player.damage then
					local amount = max(0, player.totaldamage - player.damage)
					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						if Skada.forPVP and set.type == "arena" then
							d.color = set.gold and Skada.classcolors.ARENA_GOLD or Skada.classcolors.ARENA_GREEN
						end

						d.value = amount
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.Damage and Skada:FormatNumber(d.value),
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
				for _, enemy in ipairs(set.enemies) do
					if (not win.class or win.class == enemy.class) and enemy.totaldamage and enemy.damage then
						local amount = max(0, enemy.totaldamage - enemy.damage)
						if amount > 0 then
							nr = nr + 1

							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = enemy.id or enemy.name
							d.label = enemy.name
							d.text = nil
							d.class = enemy.class
							d.role = enemy.role
							d.spec = enemy.spec
							d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.ARENA_GOLD

							d.value = amount
							d.valuetext = Skada:FormatValueCols(
								self.metadata.columns.Damage and Skada:FormatNumber(d.value),
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
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {playermod, targetmod},
			columns = {Damage = true, Percent = true},
			icon = [[Interface\Icons\spell_fire_playingwithfire]]
		}
		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local damage = set and set:GetAbsorbedDamage() or 0
		return Skada:FormatNumber(damage), damage
	end

	---------------------------------------------------------------------------

	local setPrototype = Skada.setPrototype

	function setPrototype:GetAbsorbedDamage()
		local damage = 0

		if self.totaldamage and self.damage then
			damage = max(0, self.totaldamage - self.damage)
		end

		if Skada.forPVP and self.type == "arena" and self.etotaldamage and self.edamage then
			damage = damage + max(0, self.etotaldamage - self.edamage)
		end

		return damage
	end
end)