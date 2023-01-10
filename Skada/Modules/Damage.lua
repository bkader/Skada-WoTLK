local _, Skada = ...
local Private = Skada.Private

local pairs, format, max, uformat = pairs, string.format, math.max, Private.uformat
local new, del, clear = Private.newTable, Private.delTable, Private.clearTable

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
	local mode = Skada:NewModule("Damage")
	local mode_spell = mode:NewModule("Spell List")
	local mode_spell_details = mode_spell:NewModule("Spell Details")
	local mode_spell_breakdown = mode_spell:NewModule("More Details")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")

	local wipe = wipe
	local PercentToRGB = Private.PercentToRGB
	local tooltip_school = Skada.tooltip_school
	local ignored_spells = Skada.ignored_spells.damage -- Edit Skada\Core\Tables.lua
	local passive_spells = Skada.ignored_spells.time -- Edit Skada\Core\Tables.lua
	local missTypes = Skada.missTypes
	local mode_cols = nil

	-- spells on the list below are used to update actor's active time
	-- no matter their role or damage amount, since pets aren't considered.
	local whitelist = {}

	local function add_actor_time(set, actor, spellid, target)
		if whitelist[spellid] then
			Skada:AddActiveTime(set, actor, target, tonumber(whitelist[spellid]))
		elseif actor.role ~= "HEALER" and not passive_spells[spellid] then
			Skada:AddActiveTime(set, actor, target, tonumber(whitelist[spellid]))
		end
	end

	local dmg = {}
	local function log_damage(set)
		if not dmg.amount then return end

		local actor = Skada:GetActor(set, dmg.actorname, dmg.actorid, dmg.actorflags)
		if not actor then
			return
		elseif dmg.amount > 0 and not dmg.petname then
			add_actor_time(set, actor, dmg.spell, dmg.dstName)
		end

		actor.damage = (actor.damage or 0) + dmg.amount
		set.damage = (set.damage or 0) + dmg.amount

		-- add pet damage
		if dmg.petname then
			actor.petdamage = (actor.petdamage or 0) + dmg.amount
		end

		-- absorbed damage
		local absorbed = dmg.absorbed or 0

		if actor.totaldamage then
			actor.totaldamage = actor.totaldamage + dmg.amount + absorbed
		elseif absorbed > 0 then
			actor.totaldamage = actor.damage + absorbed
		end

		if set.totaldamage then
			set.totaldamage = set.totaldamage + dmg.amount + absorbed
		elseif absorbed > 0 then
			set.totaldamage = set.damage + absorbed
		end

		if dmg.petname and actor.pettotaldamage then
			actor.pettotaldamage = actor.pettotaldamage + dmg.amount + absorbed
		elseif dmg.petname and absorbed > 0 then
			actor.pettotaldamage = actor.petdamage + absorbed
		end

		-- add the damage overkill
		local overkill = (dmg.overkill and dmg.overkill > 0) and dmg.overkill or nil
		if overkill then
			set.overkill = (set.overkill or 0) + dmg.overkill
			actor.overkill = (actor.overkill or 0) + dmg.overkill
		end

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		-- spell
		local spell = actor.damagespells and actor.damagespells[dmg.spellid]
		if not spell then
			actor.damagespells = actor.damagespells or {}
			actor.damagespells[dmg.spellid] = {amount = 0}
			spell = actor.damagespells[dmg.spellid]
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

	local function spell_damage(t)
		if t.srcGUID ~= t.dstGUID and t.spellid and not ignored_spells[t.spellid] then
			dmg.actorid = t.srcGUID
			dmg.actorname = t.srcName
			dmg.actorflags = t.srcFlags
			dmg.dstName = t.dstName

			dmg.spell = t.spellid
			dmg.spellid = t.spellstring
			dmg.is_dot = t.is_dot

			dmg.amount = t.amount
			dmg.overkill = t.overkill
			dmg.resisted = t.resisted
			dmg.blocked = t.blocked
			dmg.absorbed = t.absorbed
			dmg.critical = t.critical
			dmg.glancing = t.glancing
			dmg.crushing = t.crushing
			dmg.misstype = t.misstype

			Skada:FixPets(dmg)
			Skada:DispatchSets(log_damage)
		end
	end

	local function damage_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(set, true)
		local dps, damage = actor:GetDPS(set)

		tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, totaltime), nil, nil, nil, 1, 1, 1)
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(damage), 1, 1, 1)

		local suffix = Skada:FormatTime(P.timemesure == 1 and activetime or totaltime)
		tooltip:AddDoubleLine(Skada:FormatNumber(damage) .. "/" .. suffix, Skada:FormatNumber(dps), 1, 1, 1)

		local petdamage = P.absdamage and actor.pettotaldamage or actor.petdamage
		if not petdamage then return end
		petdamage = format("%s (\124cffffffff%s\124r)", Skada:FormatNumber(petdamage), Skada:FormatPercent(petdamage, damage))
		tooltip:AddDoubleLine(L["Pet Damage"], petdamage)
	end

	local function mode_spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		if not set then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagespells and actor.damagespells[id]
		if not spell then return end

		tooltip:AddLine(uformat("%s - %s", win.actorname, label))
		tooltip_school(tooltip, id)

		-- show the aura uptime in case of a debuff.
		local uptime = actor.auras and actor.auras[id] and actor.auras[id].u
		if uptime and uptime > 0 then
			uptime = 100 * (uptime / actor:GetTime(set))
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

	local function mode_spell_details_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] or label == L["Glancing"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetActor(win.actorname, win.actorid)
			local spell = actor.damagespells and actor.damagespells[win.spellid]
			if not spell then return end

			tooltip:AddLine(uformat("%s - %s", win.actorname, win.spellname))
			tooltip_school(tooltip, win.spellid)

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

	function mode_spell:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor damage"](label)
	end

	function mode_spell:Update(win, set)
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
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = P.absdamage and spell.total or spell.amount
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_target:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], win.actorname)
		if not set or not win.actorname then return end

		local targets, total, actor = set:GetActorDamageTargets(win.actorname, win.actorid)
		if not targets or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, targetname)
			d.value = P.absdamage and target.total or target.amount
			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	local function add_detail_bar(win, nr, title, value, total, percent, fmt)
		nr = nr + 1
		local d = win:nr(nr)

		d.id = title
		d.label = title
		d.value = value
		d.valuetext = Skada:FormatValueCols(
			mode.metadata.columns.Damage and (fmt and Skada:FormatNumber(value) or value),
			(mode.metadata.columns.sPercent and percent) and Skada:FormatPercent(d.value, total)
		)

		if win.metadata and d.value > win.metadata.maxvalue then
			win.metadata.maxvalue = d.value
		end

		return nr
	end

	function mode_spell_details:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat("%s: %s", win.actorname, format(L["%s's damage breakdown"], label))
	end

	function mode_spell_details:Tooltip(win, set, id, label, tooltip)
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagespells and actor.damagespells[id]
		if spell then
			if spell.count then
				tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
				return spell, spell.count
			end

			return spell
		end
	end

	function mode_spell_details:Update(win, set, spell, count)
		win.title = uformat("%s: %s", win.actorname, uformat(L["%s's damage breakdown"], win.spellname))
		if not win.spellid then return end

		-- details only available for actors
		if not spell then
			local actor = set and set:GetActor(win.actorname, win.actorid)
			spell = actor and actor.damagespells and actor.damagespells[win.spellid]
			count = spell and spell.count
		end

		if not spell or not count or count == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

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

	function mode_spell_breakdown:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's <%s> damage"], win.actorname, label)
	end

	function mode_spell_breakdown:Tooltip(win, set, id, label, tooltip)
		local actor = set and set:GetActor(win.actorname, win.actorid)
		local spell = actor and actor.damagespells and actor.damagespells[id]
		if spell then
			local total = spell.amount

			-- absorbed damage
			local absorbed = spell.total and (spell.total - total)
			if absorbed then
				total = spell.total
			end

			-- blocked damge
			local blocked = spell.b_amt
			if blocked then
				total = total + blocked
			end

			-- resisted damage
			local resisted = spell.r_amt
			if resisted then
				total = total + resisted
			end

			tooltip:AddDoubleLine(spell.amount == total and L["Damage"] or L["Total"], Skada:FormatNumber(total), 1, 1, 1)
			return spell, total, resisted, blocked, absorbed
		end
	end

	function mode_spell_breakdown:Update(win, set, spell, total, resisted, blocked, absorbed)
		win.title = uformat(L["%s's <%s> damage"], win.actorname, win.spellname)
		if not win.spellid then return end

		if not spell then
			local actor = set and set:GetActor(win.actorname, win.actorid)
			spell = actor and actor.damagespells and actor.damagespells[win.spellid]
			if not spell then return end

			total = spell.amount

			absorbed = spell.total and (spell.total - spell.amount)
			if absorbed then
				total = spell.total
			end

			blocked = spell.b_amt or spell.blocked
			if blocked then
				total = total + blocked
			end

			resisted = spell.r_amt or spell.resisted
			if resisted then
				total = total + resisted
			end

			if win.metadata then
				win.metadata.maxvalue = total
			end
		end

		local nr = 0

		if win.metadata then
			win.metadata.maxvalue = 0
			nr = add_detail_bar(win, nr, L["Damage"], spell.amount, total, true, true)
		elseif spell.amount ~= total then
			nr = add_detail_bar(win, nr, L["Damage"], spell.amount, total, true, true)
		end

		if spell.o_amt and spell.o_amt > 0 then
			nr = add_detail_bar(win, nr, L["Overkill"], spell.o_amt, total, true, true)
		end

		if resisted and resisted > 0 then
			nr = add_detail_bar(win, nr, L["RESIST"], resisted, total, true, true)
		end

		if blocked and blocked > 0 then
			nr = add_detail_bar(win, nr, L["BLOCK"], blocked, total, true, true)
		end

		if absorbed and absorbed > 0 then
			nr = add_detail_bar(win, nr, L["ABSORB"], absorbed, total, true, true)
		end

		if spell.g_amt and spell.g_amt > 0 then
			nr = add_detail_bar(win, nr, L["Glancing"], spell.g_amt, total, true, true)
		end
	end

	function mode_target_spell:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["actor damage"](win.actorname or L["Unknown"], label)
	end

	function mode_target_spell:Update(win, set)
		win.title = L["actor damage"](win.actorname or L["Unknown"], win.targetname or L["Unknown"])
		if not set or not win.targetname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local targets = actor and actor:GetDamageTargets(set)
		if not targets or not targets[win.targetname] then return end

		local total = P.absdamage and targets[win.targetname].total or targets[win.targetname].amount
		local spells = (total and total > 0) and actor.damagespells

		if not spells then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			local target = spell.targets and spell.targets[win.targetname]
			local amount = target and (P.absdamage and target.total or target.amount)
			if amount then
				nr = nr + 1

				local d = win:spell(nr, spellid)
				d.value = amount
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Damage"], L[win.class]) or L["Damage"]

		local total = set and set:GetDamage(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.damage then
				local dps, amount = actor:GetDPS(set, nil, nil, not mode_cols.DPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, mode_cols, total, dps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode:GetSetSummary(set, win)
		local dps, amount = set:GetDPS(nil, win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(amount),
			mode_cols.DPS and Skada:FormatNumber(dps)
		)
		return amount, valuetext
	end

	function mode:AddToTooltip(set, tooltip)
		if not set then return end
		local dps, amount = set:GetDPS()
		tooltip:AddDoubleLine(L["Damage"], Skada:FormatNumber(amount), 1, 1, 1)
		tooltip:AddDoubleLine(L["DPS"], Skada:FormatNumber(dps), 1, 1, 1)
	end

	local function feed_personal_dps()
		local set = Skada:GetSet("current")
		local actor = set and set:GetActor(Skada.userName, Skada.userGUID)
		return format("%s %s", Skada:FormatNumber(actor and actor:GetDPS(set) or 0), L["DPS"])
	end

	local function feed_raid_dps()
		local set = Skada:GetSet("current")
		return format("%s %s", Skada:FormatNumber(set and set:GetDPS() or 0), L["DPS"])
	end

	function mode:OnEnable()
		mode_spell_details.metadata = {tooltip = mode_spell_details_tooltip}
		mode_spell.metadata = {click1 = mode_spell_details, click2 = mode_spell_breakdown, post_tooltip = mode_spell_tooltip}
		mode_target.metadata = {click1 = mode_target_spell}
		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		local flags_src_dst = {src_is_interesting = true, dst_is_not_interesting = true}
		Skada:RegisterForCL(
			spell_damage,
			flags_src_dst,
			-- damage events
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			-- missed events
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED"
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		Skada:AddFeed(L["Damage: Personal DPS"], feed_personal_dps)
		Skada:AddFeed(L["Damage: Raid DPS"], feed_raid_dps)
		Skada:AddMode(self, "Damage Done")
	end

	function mode:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveFeed(L["Damage: Personal DPS"])
		Skada:RemoveFeed(L["Damage: Raid DPS"])
		Skada:RemoveMode(self)
	end

	function mode:CombatLeave()
		wipe(dmg)
	end

	function mode:SetComplete(set)
		-- clean set from garbage before it is saved.
		local total = set.totaldamage or set.damage
		if not total or total == 0 then return end

		for _, actor in pairs(set.actors) do
			local amount = actor.totaldamage or actor.damage
			if (not amount and actor.damagespells) or amount == 0 then
				actor.damage, actor.totaldamage = nil, nil
				actor.damagespells = del(actor.damagespells, true)
			end
		end
	end

	function mode:OnInitialize()
		self.metadata = {
			showspots = true,
			filterclass = true,
			post_tooltip = damage_tooltip,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Damage = true, DPS = true, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_fire_firebolt]]
		}

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
	local mode = Skada:NewModule("DPS")
	local mode_cols = nil

	local function dps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if not actor then return end

		local totaltime = set:GetTime()
		local activetime = actor:GetTime(set, true)
		local dps, damage = actor:GetDPS(set, nil, nil, false)
		tooltip:AddLine(uformat("%s - %s", label, L["DPS"]))
		tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
		tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(damage), 1, 1, 1)

		local petdamage = P.absdamage and actor.pettotaldamage or actor.petdamage
		if not petdamage then return end
		petdamage = format("%s (\124cffffffff%s\124r)", Skada:FormatNumber(petdamage), Skada:FormatPercent(petdamage, damage))
		tooltip:AddDoubleLine(L["Pet Damage"], petdamage)
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["DPS"], L[win.class]) or L["DPS"]

		local total = set and set:GetDPS(nil, win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.damage then
				local dps = actor:GetDPS(set)
				if dps > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = dps
					format_valuetext(d, mode_cols, max(dps, total), dps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode:GetSetSummary(set, win)
		local dps = set:GetDPS(nil, win and win.class)
		return dps, Skada:FormatNumber(dps)
	end

	function mode:OnEnable()
		self.metadata = {
			showspots = true,
			tooltip = dps_tooltip,
			columns = {DPS = true, Percent = true},
			icon = [[Interface\Icons\achievement_bg_topdps]]
		}

		mode_cols = self.metadata.columns

		local parent = Skada:GetModule("Damage", true)
		if parent and parent.metadata then
			self.metadata.click1 = parent.metadata.click1
			self.metadata.click2 = parent.metadata.click2
			self.metadata.filterclass = parent.metadata.filterclass
		end

		Skada:AddMode(self, "Damage Done")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Damage")

-- =========================== --
-- Damage Done By Spell Module --
-- =========================== --

Skada:RegisterModule("Damage Done By Spell", function(L, P, _, C)
	local mode = Skada:NewModule("Damage Done By Spell")
	local mode_source = mode:NewModule("Source List")
	local mode_cols = nil

	local function mode_source_tooltip(win, id, label, tooltip)
		local set = win.spellname and win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		local spell = actor and actor.damagespells and actor.damagespells[win.spellid]
		if not spell then return end

		tooltip:AddLine(label .. " - " .. win.spellname)

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

	function mode_source:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's sources"], label)
	end

	function mode_source:Update(win, set)
		win.title = uformat(L["%s's sources"], win.spellname)
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		if not win.spellid then return end

		local total = 0
		local sources = clear(C)
		local actors = set.actors
		for actorname, actor in pairs(actors) do
			local spell = win:show_actor(actor, set, true) and actor.damagespells and actor.damagespells[win.spellid]
			if spell then
				local amount = P.absdamage and spell.total or spell.amount
				if amount > 0 then
					sources[actorname] = new()
					sources[actorname].id = actor.id
					sources[actorname].class = actor.class
					sources[actorname].role = actor.role
					sources[actorname].spec = actor.spec
					sources[actorname].amount = amount
					sources[actorname].time = mode.metadata.columns.sDPS and actor:GetTime(set)

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
		for actorname, actor in pairs(sources) do
			nr = nr + 1

			local d = win:actor(nr, actor, actor.enemy, actorname)
			d.value = actor.amount
			format_valuetext(d, mode_cols, total, actor.time and (d.value / actor.time), win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = L["Damage Done By Spell"]

		local total = set and set:GetDamage()
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local spells = clear(C)
		for _, actor in pairs(set.actors) do
			local _spells = not actor.enemy and actor.damagespells
			if _spells then
				for spellid, spell in pairs(_spells) do
					local amount = P.absdamage and spell.total or spell.amount
					if amount and amount > 0 then
						if not spells[spellid] then
							spells[spellid] = new()
							spells[spellid].amount = amount
						else
							spells[spellid].amount = spells[spellid].amount + amount
						end
					end
				end
			end
		end

		local nr = 0
		local settime = mode_cols.DPS and set:GetTime()

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = spell.amount
			format_valuetext(d, mode_cols, total, settime and (d.value / settime), win.metadata)
		end
	end

	function mode:OnEnable()
		mode_source.metadata = {showspots = true, filterclass = true, tooltip = mode_source_tooltip}
		self.metadata = {
			showspots = true,
			click1 = mode_source,
			columns = {Damage = true, DPS = false, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_nature_lightning]]
		}

		mode_cols = self.metadata.columns

		Skada:AddMode(self, "Damage Done")
	end

	function mode:OnDisable()
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
	local mode = Skada:NewModule("Useful Damage")
	local mode_spell = mode:NewModule("Spell List")
	local mode_target = mode:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	local mode_cols = nil

	function mode_spell:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = L["actor damage"](label)
	end

	function mode_spell:Update(win, set)
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
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for spellid, spell in pairs(spells) do
			nr = nr + 1

			local d = win:spell(nr, spellid)
			d.value = P.absdamage and spell.total or spell.amount
			if spell.o_amt then
				d.value = max(0, d.value - spell.o_amt)
			end

			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_target:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], win.actorname)
		if not set or not win.actorname then return end

		local targets, total, actor = set:GetActorDamageTargets(win.actorname, win.actorid)
		if not targets or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, target, target.enemy, targetname)
			d.value = P.absdamage and target.total or target.amount
			if target.o_amt then
				d.value = max(0, d.value - target.o_amt)
			end

			format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
		end
	end

	function mode_target_spell:Enter(win, id, label, tooltip)
		win.targetid, win.targetname = id, label
		win.title = format(L["Useful damage on %s"], label)
	end

	function mode_target_spell:Update(win, set)
		win.title = uformat(L["Useful damage on %s"], win.targetname)
		if not set or not win.targetname then return end

		local sources, total, actor = set:GetActorDamageSources(win.targetname, win.targetid)
		if not sources or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for sourcename, source in pairs(sources) do
			local amount = P.absdamage and source.total or source.amount
			if source.o_amt then
				amount = max(0, amount - source.o_amt)
			end

			if amount > 0 then
				nr = nr + 1

				local d = win:actor(nr, source, actor.enemy, sourcename)
				d.value = amount
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Useful Damage"], L[win.class]) or L["Useful Damage"]

		local total = set and set:GetDamage(win.class, true)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.damage then
				local dps, amount = actor:GetDPS(set, true, nil, not mode_cols.DPS)
				if amount > 0 then
					nr = nr + 1

					local d = win:actor(nr, actor, actor.enemy, actorname)
					d.value = amount
					format_valuetext(d, mode_cols, total, dps, win.metadata)
					win:color(d, set, actor.enemy)
				end
			end
		end
	end

	function mode:GetSetSummary(set, win)
		if not set then return end
		local dps, amount = set:GetDPS(true, win and win.class)
		local valuetext = Skada:FormatValueCols(
			mode_cols.Damage and Skada:FormatNumber(amount),
			mode_cols.DPS and Skada:FormatNumber(dps)
		)
		return amount, valuetext
	end

	function mode:OnEnable()
		mode_target_spell.metadata = {showspots = true}
		mode_target.metadata = {click1 = mode_target_spell}
		self.metadata = {
			showspots = true,
			filterclass = true,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Damage = true, DPS = true, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_shaman_stormearthfire]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		Skada:AddMode(self, "Damage Done")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end, "Damage")

-- =============== --
-- Overkill Module --
-- =============== --

Skada:RegisterModule("Overkill", function(L, _, _, C)
	local mode = Skada:NewModule("Overkill")
	local mode_spell = mode:NewModule("Spell List")
	local mode_target = mode:NewModule("Target List")
	local mode_spell_target = mode_spell:NewModule("Target List")
	local mode_target_spell = mode_target:NewModule("Spell List")
	local get_actor_spell_overkill_targets = nil
	local mode_cols = nil

	function mode_spell:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's overkill spells"], label)
	end

	function mode_spell:Update(win, set)
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
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for spellid, spell in pairs(actor.damagespells) do
			if spell.o_amt and spell.o_amt > 0 then
				nr = nr + 1

				local d = win:spell(nr, spellid)
				d.value = spell.o_amt
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_target:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's overkill targets"], label)
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's overkill targets"], win.actorname)
		if not set or not win.actorname then return end

		local targets, _, actor, total = set:GetActorDamageTargets(win.actorname, win.actorid)
		if not targets or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			if target.o_amt and target.o_amt > 0 then
				nr = nr + 1

				local d = win:actor(nr, target, target.enemy, targetname)
				d.value = target.o_amt
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_spell_target:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = uformat(L["%s's overkill targets"], win.actorname)
	end

	function mode_spell_target:Update(win, set)
		win.title = uformat(L["%s's overkill targets"], win.actorname)
		if not win.spellname or not win.actorname then return end

		local targets, total, actor = get_actor_spell_overkill_targets(set, win.actorname, win.actorid, win.spellid)
		if not targets or not actor or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for targetname, target in pairs(targets) do
			if target.o_amt and target.o_amt > 0 then
				nr = nr + 1

				local d = win:actor(nr, target, target.enemy, targetname)
				d.value = target.o_amt
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode_target_spell:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = uformat(L["%s's overkill spells"], win.actorname)
	end

	function mode_target_spell:Update(win, set)
		win.title = uformat(L["%s's overkill spells"], win.actorname)
		if not set or not win.targetname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		if not actor or not actor.overkill or actor.overkill == 0 then return end

		local targets = actor:GetDamageTargets(set)
		local total = targets and targets[win.targetname] and targets[win.targetname].o_amt

		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actortime = mode_cols.sDPS and actor:GetTime(set)

		for spellid, spell in pairs(actor.damagespells) do
			local o_amt = spell.targets and spell.targets[win.targetname] and spell.targets[win.targetname].o_amt
			if o_amt and o_amt > 0 then
				nr = nr + 1

				local d = win:spell(nr, spellid)
				d.value = o_amt
				format_valuetext(d, mode_cols, total, actortime and (d.value / actortime), win.metadata, true)
			end
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Overkill"], L[win.class]) or L["Overkill"]

		local total = set and set:GetOverkill(win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.overkill then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.overkill
				format_valuetext(d, mode_cols, total, mode_cols.DPS and (d.value / actor:GetTime(set)), win.metadata)
				win:color(d, set, actor.enemy)
			end
		end
	end

	function mode:GetSetSummary(set, win)
		local overkill = set:GetOverkill(win and win.class)
		return overkill, Skada:FormatNumber(overkill)
	end

	function mode:OnEnable()
		mode_target.metadata = {click1 = mode_target_spell}
		mode_spell.metadata = {click1 = mode_spell_target}
		self.metadata = {
			showspots = true,
			filterclass = true,
			click1 = mode_spell,
			click2 = mode_target,
			columns = {Damage = true, DPS = false, Percent = true, sDPS = false, sPercent = true},
			icon = [[Interface\Icons\spell_fire_incinerate]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true
		mode_target.nototal = true

		Skada:AddMode(self, "Damage Done")
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	get_actor_spell_overkill_targets = function(self, name, id, spellid, tbl)
		local actor = self:GetActor(name, id)
		if not actor or not actor.overkill or actor.overkill == 0 then return end

		local spell = actor.damagespells and actor.damagespells[spellid]
		local total = spell and spell.targets and spell.o_amt
		if not total or total == 0 then return end

		tbl = clear(tbl or C)
		for targetname, target in pairs(spell.targets) do
			local t = tbl[targetname]
			if not t then
				t = new()
				t.o_amt = target.o_amt
				tbl[targetname] = t
			elseif target.o_amt then
				t.o_amt = (t.o_amt or 0) + target.o_amt
			end
			self:_fill_actor_table(t, targetname)
		end

		return tbl, total, actor
	end
end, "Damage")
