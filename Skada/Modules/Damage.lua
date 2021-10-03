assert(Skada, "Skada not found!")

local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local format, max = string.format, math.max
local pairs, ipairs, select = pairs, ipairs, select

-- list of miss types
local misstypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}

-- common functions
local function getDPS(set, player, useful)
	local amount = player.damage or 0
	if Skada.db.profile.absdamage then
		amount = amount + (player.absdamage or 0)
	end
	if useful and (player.overkill or 0) > 0 then
		amount = max(0, amount - player.overkill)
	end
	return amount / max(1, Skada:PlayerActiveTime(set, player)), amount
end

local function getRaidDPS(set, useful)
	local amount = set.damage or 0
	if Skada.db.profile.absdamage then
		amount = amount + (set.absdamage or 0)
	end
	if useful and (set.overkill or 0) > 0 then
		amount = max(0, amount - set.overkill)
	end
	return amount / max(1, Skada:GetSetTime(set)), amount
end
-- ================== --
-- Damage Done Module --
-- ================== --

Skada:AddLoadableModule("Damage", function(Skada, L)
	if Skada:IsDisabled("Damage") then return end

	local mod = Skada:NewModule(L["Damage"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local spellmod = playermod:NewModule(L["Damage spell details"])
	local sdetailmod = spellmod:NewModule(L["Damage Breakdown"])
	local targetmod = mod:NewModule(L["Damage target list"])
	local tdetailmod = targetmod:NewModule(L["Damage spell list"])

	local UnitGUID = UnitGUID
	local tContains = tContains

	-- spells on the list below are ignored when it comes
	-- to updating player's active time.
	local blacklist = {
		-- Retribution Aura (rank 1 to 7)
		7294, 10298, 10299, 10300, 10301, 27150, 54043,
		-- Molten Armor (rank 1 to 3)
		30482, 43045, 43046,
		-- Lightning Shield (rank 1 to 11)
		324, 325, 905, 945, 8134, 10431, 10432, 25469, 25472, 49280, 49281,
		-- Fire Shield (rank 1 to 7)
		2947, 8316, 8317, 11770, 11771, 27269, 47983
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

	local function log_damage(set, dmg, tick)
		if dmg.spellid and tContains(ignoredSpells, dmg.spellid) then return end

		local player = Skada:get_player(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if not player then return end

		-- update activity
		if whitelist[dmg.spellid] ~= nil then
			Skada:AddActiveTime(player, (dmg.amount > 0), tonumber(whitelist[dmg.spellid]))
		elseif player.role ~= "HEALER" and not dmg.petname then
			Skada:AddActiveTime(player, (dmg.amount > 0 and not tContains(blacklist, dmg.spellid)))
		end

		player.damage = (player.damage or 0) + dmg.amount
		set.damage = (set.damage or 0) + dmg.amount

		local spellname = dmg.spellname .. (tick and L["DoT"] or "")
		local spell = player.damage_spells and player.damage_spells[spellname]
		if not spell then
			player.damage_spells = player.damage_spells or {}
			spell = {id = dmg.spellid, school = dmg.spellschool, amount = 0}
			player.damage_spells[spellname] = spell
		elseif dmg.spellid and dmg.spellid ~= spell.id then
			if dmg.spellschool and dmg.spellschool ~= spell.school then
				spellname = spellname .. " (" .. (Skada.schoolnames[dmg.spellschool] or OTHER) .. ")"
			else
				spellname = GetSpellInfo(dmg.spellid)
			end
			if not player.damage_spells[spellname] then
				player.damage_spells[spellname] = {id = dmg.spellid, school = dmg.spellschool, amount = 0}
			end
			spell = player.damage_spells[spellname]
		end
		spell.count = (spell.count or 0) + 1
		spell.amount = spell.amount + dmg.amount

		if dmg.critical then
			spell.critical = (spell.critical or 0) + 1
			spell.criticalamount = (spell.criticalamount or 0) + dmg.amount

			if not spell.criticalmax or dmg.amount > spell.criticalmax then
				spell.criticalmax = dmg.amount
			end

			if not spell.criticalmin or dmg.amount < spell.criticalmin then
				spell.criticalmin = dmg.amount
			end
		elseif dmg.missed ~= nil then
			spell[dmg.missed] = (spell[dmg.missed] or 0) + 1
		elseif dmg.glancing then
			spell.glancing = (spell.glancing or 0) + 1
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

		if (dmg.absorbed or 0) > 0 then
			set.absdamage = (set.absdamage or 0) + dmg.absorbed
			player.absdamage = (player.absdamage or 0) + dmg.absorbed
			spell.absorbed = (spell.absorbed or 0) + dmg.absorbed
		end

		if (dmg.blocked or 0) > 0 then
			spell.blocked = (spell.blocked or 0) + dmg.blocked
		end

		if (dmg.resisted or 0) > 0 then
			spell.resisted = (spell.resisted or 0) + dmg.resisted
		end

		-- add the damage overkill
		local overkill = dmg.overkill or 0
		player.overkill = (player.overkill or 0) + overkill
		spell.overkill = (spell.overkill or 0) + overkill
		set.overkill = (set.overkill or 0) + overkill

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.current and dmg.dstName then
			spell.targets = spell.targets or {}
			if not spell.targets[dmg.dstName] then
				spell.targets[dmg.dstName] = {amount = dmg.amount, overkill = overkill}
			else
				spell.targets[dmg.dstName].amount = spell.targets[dmg.dstName].amount + dmg.amount
				spell.targets[dmg.dstName].overkill = spell.targets[dmg.dstName].overkill + overkill
			end

			player.damage_targets = player.damage_targets or {}
			if not player.damage_targets[dmg.dstName] then
				player.damage_targets[dmg.dstName] = {amount = dmg.amount, overkill = overkill}
			else
				player.damage_targets[dmg.dstName].amount = player.damage_targets[dmg.dstName].amount + dmg.amount
				player.damage_targets[dmg.dstName].overkill = player.damage_targets[dmg.dstName].overkill + overkill
			end

			if (dmg.absorbed or 0) > 0 then
				spell.targets[dmg.dstName].absorbed = (spell.targets[dmg.dstName].absorbed or 0) + dmg.absorbed
				player.damage_targets[dmg.dstName].absorbed = (player.damage_targets[dmg.dstName].absorbed or 0) + dmg.absorbed
			end
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local spellid, spellname, spellschool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...

			dmg.playerid = srcGUID
			dmg.playername = srcName
			dmg.playerflags = srcFlags
			dmg.dstName = dstName

			dmg.spellid = spellid
			dmg.spellname = spellname
			dmg.spellschool = spellschool
			dmg.amount = amount

			dmg.overkill = overkill
			dmg.resisted = resisted
			dmg.blocked = blocked
			dmg.absorbed = absorbed
			dmg.critical = critical
			dmg.glancing = glancing
			dmg.crushing = crushing
			dmg.missed = nil

			dmg.petname = nil
			Skada:FixPets(dmg)

			log_damage(Skada.current, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
			log_damage(Skada.total, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
		end
	end

	local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, MELEE, 1, ...)
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local spellid, spellname, spellschool, misstype, amount = ...

			dmg.playerid = srcGUID
			dmg.playername = srcName
			dmg.playerflags = srcFlags
			dmg.dstName = dstName

			dmg.spellid = spellid
			dmg.spellname = spellname
			dmg.spellschool = spellschool

			dmg.amount = 0
			dmg.overkill = 0
			dmg.resisted = nil
			dmg.blocked = nil
			dmg.absorbed = nil
			dmg.critical = nil
			dmg.glancing = nil
			dmg.crushing = nil
			dmg.missed = misstype

			if misstype == "ABSORB" then
				dmg.absorbed = amount
			elseif misstype == "BLOCK" then
				dmg.blocked = amount
			elseif misstype == "RESIST" then
				dmg.resisted = amount
			end

			dmg.petname = nil
			Skada:FixPets(dmg)

			log_damage(Skada.current, dmg, eventtype == "SPELL_PERIODIC_MISSED")
			log_damage(Skada.total, dmg, eventtype == "SPELL_PERIODIC_MISSED")
		end
	end

	local function SwingMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, MELEE, 1, ...)
	end

	local function damage_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		local player = Skada:find_player(set, id)
		if player then
			local totaltime = Skada:GetSetTime(set)
			local activetime = Skada:PlayerActiveTime(set, player)
			tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, totaltime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(Skada:PlayerActiveTime(set, player, true)), 1, 1, 1)
		end
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), win.playerid)
		if player then
			local spell = player.damage_spells and player.damage_spells[label]
			if spell then
				tooltip:AddLine(player.name .. " - " .. label)

				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then
						tooltip:AddLine(n, c.r, c.g, c.b)
					end
				end

				if (spell.hitmin or 0) > 0 then
					local spellmin = spell.hitmin
					if spell.criticalmin and spell.criticalmin < spellmin then
						spellmin = spell.criticalmin
					end
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
				end

				if (spell.hitmax or 0) > 0 then
					local spellmax = spell.hitmax
					if spell.criticalmax and spell.criticalmax > spellmax then
						spellmax = spell.criticalmax
					end
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spellmax), 1, 1, 1)
				end

				local amount = spell.amount + (Skada.db.profile.absdamage and (spell.absorbed or 0) or 0)
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(amount / spell.count), 1, 1, 1)
			end
		end
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] then
			local player = Skada:find_player(win:get_selected_set(), win.playerid)
			if player then
				local spell = player.damage_spells and player.damage_spells[win.spellname]
				if spell then
					tooltip:AddLine(player.name .. " - " .. win.spellname)

					if spell.school then
						local c = Skada.schoolcolors[spell.school]
						local n = Skada.schoolnames[spell.school]
						if c and n then
							tooltip:AddLine(n, c.r, c.g, c.b)
						end
					end

					if label == L["Critical Hits"] and spell.criticalamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
					elseif label == L["Normal Hits"] and spell.hitamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.hitmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.hitmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.hitamount / spell.hit), 1, 1, 1)
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's damage"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = format(L["%s's damage"], player.name)
			local total = select(2, getDPS(set, player))

			if total > 0 and player.damage_spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in pairs(player.damage_spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellname
					d.spellid = spell.id
					d.label = spellname
					d.icon = select(3, GetSpellInfo(spell.id))
					d.spellschool = spell.school

					d.value = spell.amount + (Skada.db.profile.absdamage and (spell.absorbed or 0) or 0)
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's targets"], player.name)
			local total = select(2, getDPS(set, player))

			if total > 0 and player.damage_targets then
				local maxvalue, nr = 0, 1

				for targetname, target in pairs(player.damage_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname

					d.value = target.amount + (Skada.db.profile.absdamage and (target.absorbed or 0) or 0)
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	local function add_detail_bar(win, nr, title, value, percent, fmt)
		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = title
		d.label = title
		d.value = value
		d.valuetext = Skada:FormatValueText(
			fmt and Skada:FormatNumber(value) or value,
			mod.metadata.columns.Damage,
			Skada:FormatPercent(d.value, win.metadata.maxvalue),
			percent and mod.metadata.columns.Percent
		)
		nr = nr + 1
		return nr
	end

	function spellmod:Enter(win, id, label)
		win.spellname = label
		win.title = format(L["%s's <%s> damage"], win.playername or UNKNOWN, label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's <%s> damage"], player.name, win.spellname)

			local spell = win.spellname and player.damage_spells and player.damage_spells[win.spellname]

			if spell then
				win.metadata.maxvalue = spell.count

				local nr = add_detail_bar(win, 1, L["Hits"], spell.count)

				if (spell.hit or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Normal Hits"], spell.hit, true)
				end

				if (spell.critical or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Critical Hits"], spell.critical, true)
				end

				if (spell.glancing or 0) > 0 then
					add_detail_bar(win, nr, L["Glancing"], spell.glancing, true)
					nr = nr + 1
				end

				if (spell.crushing or 0) > 0 then
					add_detail_bar(win, nr, L["Crushing"], spell.crushing, true)
					nr = nr + 1
				end

				for _, misstype in ipairs(misstypes) do
					if (spell[misstype] or 0) > 0 then
						nr = add_detail_bar(win, nr, L[misstype], spell[misstype], true)
					end
				end
			end
		end
	end

	function sdetailmod:Enter(win, id, label)
		win.spellname = label
		win.title = format(L["%s's damage breakdown"], label)
	end

	function sdetailmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's damage breakdown"], win.spellname or UNKNOWN)

			local spell = win.spellname and player.damage_spells and player.damage_spells[win.spellname]

			if spell then
				local absorbed = spell.absorbed or 0
				local blocked = spell.blocked or 0
				local resisted = spell.resisted or 0

				win.metadata.maxvalue = spell.amount + absorbed + blocked + resisted

				local nr = add_detail_bar(win, 1, L["Damage"], win.metadata.maxvalue, nil, true)

				if (spell.overkill or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Overkill"], spell.overkill, true, true)
				end

				if absorbed > 0 then
					nr = add_detail_bar(win, nr, L["ABSORB"], absorbed, true, true)
				end

				if blocked > 0 then
					nr = add_detail_bar(win, nr, L["BLOCK"], blocked, true, true)
				end

				if resisted > 0 then
					nr = add_detail_bar(win, nr, L["RESIST"], resisted, true, true)
				end
			end
		end
	end

	function tdetailmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["%s's damage on %s"], win.playername or UNKNOWN, label)
	end

	function tdetailmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's damage on %s"], player.name, win.targetname or UNKNOWN)

			local total = 0
			if player.damage_targets and win.targetname and player.damage_targets[win.targetname] then
				total = player.damage_targets[win.targetname].amount or 0
				if Skada.db.profile.absdamage then
					total = total + (player.damage_targets[win.targetname].absorbed or 0)
				end
			end

			if total > 0 and player.damage_spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in pairs(player.damage_spells) do
					if spell.targets and spell.targets[win.targetname] then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						d.icon = select(3, GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = spell.targets[win.targetname].amount or 0
						if Skada.db.profile.absdamage then
							d.value = d.value + (spell.targets[win.targetname].absorbed or 0)
						end
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Damage"]
		local total = select(2, getRaidDPS(set))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local dps, amount = getDPS(set, player)
				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Damage,
						Skada:FormatNumber(dps),
						self.metadata.columns.DPS,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	local function feed_personal_dps()
		if Skada.current then
			local player = Skada:find_player(Skada.current, Skada.userGUID)
			if player then
				return Skada:FormatNumber(getDPS(Skada.current, player)) .. " " .. L["DPS"]
			end
		end
	end

	local function feed_raid_dps()
		if Skada.current then
			return Skada:FormatNumber(getRaidDPS(Skada.current)) .. " " .. L["RDPS"]
		end
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
			nototalclick = {targetmod},
			columns = {Damage = true, DPS = true, Percent = true},
			icon = "Interface\\Icons\\spell_fire_firebolt"
		}

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_EXTRA_ATTACKS", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})

		Skada:RegisterForCL(SpellMissed, "DAMAGE_SHIELD_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})

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
		local dps, amount = getRaidDPS(set)
		tooltip:AddDoubleLine(L["Damage"], Skada:FormatNumber(amount), 1, 1, 1)
		tooltip:AddDoubleLine(L["DPS"], Skada:FormatNumber(dps), 1, 1, 1)
	end

	function mod:GetSetSummary(set)
		local dps, value = getRaidDPS(set)
		return Skada:FormatValueText(
			Skada:FormatNumber(value),
			self.metadata.columns.Damage,
			Skada:FormatNumber(dps),
			self.metadata.columns.DPS
		), value
	end

	function mod:SetComplete(set)
		for _, player in ipairs(set.players) do
			if (player.damage or 0) == 0 then
				player.damage_spells = nil
				player.damage_targets = nil
			end
		end
	end

	function mod:OnInitialize()
		if Skada.options.args.Tweaks then
			Skada.options.args.Tweaks.args.absdamage = {
				type = "toggle",
				name = L["Include Absorbed Damage"],
				desc = L["Enable this if you want the damage absorbed to be included in the damage done."],
				order = 94,
				width = "double"
			}
		else
			Skada.options.args.generaloptions.args.absdamage = {
				type = "toggle",
				name = L["Include Absorbed Damage"],
				desc = L["Enable this if you want the damage absorbed to be included in the damage done."],
				order = 93
			}
		end
	end
end)

-- ============================= --
-- Damage done per second module --
-- ============================= --

Skada:AddLoadableModule("DPS", function(Skada, L)
	if Skada:IsDisabled("Damage", "DPS") then return end

	local mod = Skada:NewModule(L["DPS"])

	local function dps_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		local player = Skada:find_player(set, id)
		if player then
			local totaltime = Skada:GetSetTime(set)
			local activetime = Skada:PlayerActiveTime(set, player)
			local dps, amount = getDPS(set, player)
			tooltip:AddLine(player.name .. " - " .. L["DPS"])
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(Skada:PlayerActiveTime(set, player, true)), 1, 1, 1)
			tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(player.damage), 1, 1, 1)
			tooltip:AddDoubleLine(Skada:FormatNumber(amount) .. "/" .. Skada:FormatTime(activetime), Skada:FormatNumber(dps), 1, 1, 1)
		end
	end

	function mod:Update(win, set)
		win.title = L["DPS"]
		local total = getRaidDPS(set)

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local amount = getDPS(set, player)

				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.DPS,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			tooltip = dps_tooltip,
			columns = {DPS = true, Percent = true},
			icon = "Interface\\Icons\\inv_misc_pocketwatch_01"
		}

		local parentmod = Skada:GetModule(L["Damage"], true)
		if parentmod then
			self.metadata.click1 = parentmod.metadata.click1
			self.metadata.click2 = parentmod.metadata.click2
			self.metadata.nototalclick = parentmod.metadata.nototalclick
		end

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self, L["Damage Done"])
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(getRaidDPS(set))
	end
end)

-- =========================== --
-- Damage Done By Spell Module --
-- =========================== --

Skada:AddLoadableModule("Damage Done By Spell", function(Skada, L)
	if Skada:IsDisabled("Damage", "Damage Done By Spell") then return end

	local mod = Skada:NewModule(L["Damage Done By Spell"])
	local sourcemod = mod:NewModule(L["Damage spell sources"])
	local newTable, delTable, cacheTable = Skada.newTable, Skada.delTable

	function sourcemod:Enter(win, id, label)
		win.spellname = label
		win.title = format(L["%s's sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = format(L["%s's sources"], win.spellname or UNKNOWN)
		if win.spellname then
			cacheTable = newTable()
			local total = 0

			for _, player in ipairs(set.players) do
				if player.damage_spells and player.damage_spells[win.spellname] then
					if (player.damage_spells[win.spellname].amount or 0) > 0 then
						cacheTable[player.id] = {
							name = player.name,
							class = player.class,
							role = player.role,
							spec = player.spec,
							amount = player.damage_spells[win.spellname].amount
						}
						if Skada.db.profile.absdamage then
							cacheTable[player.id].amount = cacheTable[player.id].amount + (player.damage_spells[win.spellname].absorbed or 0)
						end
						total = total + cacheTable[player.id].amount
					end
				end
			end

			local maxvalue, nr = 0, 1

			for playerid, player in pairs(cacheTable) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = playerid
				d.label = player.name
				d.text = Skada:FormatName(player.name, playerid)
				d.class = player.class
				d.role = player.role
				d.spec = player.spec

				d.value = player.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
			delTable(cacheTable)
		end
	end

	function mod:Update(win, set)
		win.title = L["Damage Done By Spell"]

		local total = set.damage or 0
		if total == 0 then
			return
		end

		cacheTable = newTable()

		for _, player in ipairs(set.players) do
			if player.damage_spells then
				for spellname, spell in pairs(player.damage_spells) do
					if spell.amount > 0 then
						if not cacheTable[spellname] then
							cacheTable[spellname] = {
								id = spell.id,
								school = spell.school,
								amount = spell.amount + (Skada.db.profile.absdamage and (spell.absorbed or 0) or 0)
							}
						else
							cacheTable[spellname].amount = cacheTable[spellname].amount + spell.amount + (Skada.db.profile.absdamage and (spell.absorbed or 0) or 0)
						end
					end
				end
			end
		end

		local maxvalue, nr = 0, 1

		for spellname, spell in pairs(cacheTable) do
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.id = spellname
			d.spellid = spell.id
			d.label = spellname
			d.icon = select(3, GetSpellInfo(spell.id))
			d.spellschool = spell.school

			d.value = spell.amount
			d.valuetext = Skada:FormatValueText(
				Skada:FormatNumber(d.value),
				self.metadata.columns.Damage,
				Skada:FormatPercent(d.value, total),
				self.metadata.columns.Percent
			)

			if d.value > maxvalue then
				maxvalue = d.value
			end
			nr = nr + 1
		end

		win.metadata.maxvalue = maxvalue
		delTable(cacheTable)
	end

	function mod:OnEnable()
		sourcemod.metadata = {showspots = true}
		self.metadata = {
			showspots = true,
			click1 = sourcemod,
			columns = {Damage = true, Percent = true},
			icon = "Interface\\Icons\\spell_nature_lightning"
		}
		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.damage or 0), set.damage or 0
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

Skada:AddLoadableModule("Useful Damage", function(Skada, L)
	if Skada:IsDisabled("Damage", "Useful Damage") then return end

	local mod = Skada:NewModule(L["Useful Damage"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local targetmod = mod:NewModule(L["Damage target list"])
	local detailmod = targetmod:NewModule(L["More Details"])
	local UnitClass = Skada.UnitClass

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's damage"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = format(L["%s's damage"], player.name)
			local total = select(2, getDPS(set, player, true))

			if total > 0 and player.damage_spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in pairs(player.damage_spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellname
					d.spellid = spell.id
					d.label = spellname
					d.icon = select(3, GetSpellInfo(spell.id))
					d.spellschool = spell.school

					d.value = max(0, (spell.amount or 0) - (spell.overkill or 0))
					if Skada.db.profile.absdamage then
						d.value = d.value + (spell.absorbed or 0)
					end
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's targets"], player.name)
			local total = select(2, getDPS(set, player, true))

			if total > 0 and player.damage_targets then
				local maxvalue, nr = 0, 1

				for targetname, target in pairs(player.damage_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname

					d.value = max(0, (target.amount or 0) - (target.overkill or 0))
					if Skada.db.profile.absdamage then
						d.value = d.value + (target.absorbed or 0)
					end
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function detailmod:Enter(win, id, label, tooltip)
		win.targetname = label
		win.title = format(L["Useful damage on %s"], label)
	end

	function detailmod:Update(win, set)
		win.title = format(L["Useful damage on %s"], win.targetname or UNKNOWN)

		local total, players, found = 0, {}

		if Skada.find_enemy then
			local enemy = Skada:find_enemy(set, win.targetname)
			if enemy and (enemy.damagetaken_useful or 0) > 0 then
				total = enemy.damagetaken_useful

				for sourcename, source in pairs(enemy.damagetaken_sources) do
					if (source.useful or 0) > 0 then
						players[sourcename] = {id = source.id, amount = source.useful}
						found = true
					end
				end
			end
		end
		if not found then
			total = 0 -- reset total
			for _, player in ipairs(set.players) do
				if player.damage_targets and player.damage_targets[win.targetname] then
					local amount = max(0, player.damage_targets[win.targetname].amount - player.damage_targets[win.targetname].overkill)
					if Skada.db.profile.absdamage then
						amount = amount + (player.damage_targets[win.targetname].absorbed or 0)
					end
					total = total + amount
					players[player.name] = {
						id = player.id,
						class = player.class,
						role = player.role,
						spec = player.spec,
						amount = amount
					}
				end
			end
		end

		if total > 0 then
			local maxvalue, nr = 0, 1

			for playername, player in pairs(players) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id or playername
				d.label = Skada:FormatName(playername, d.id)
				if not player.class then
					d.class, d.role, d.spec = select(2, UnitClass(player.id, nil, set, true))
				else
					d.class = player.class
					d.role = player.role
					d.spec = player.spec
				end

				d.value = player.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:Update(win, set)
		win.title = L["Useful Damage"]
		local total = select(2, getRaidDPS(set, true))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local dps, amount = getDPS(set, player, true)

				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Damage,
						Skada:FormatNumber(dps),
						self.metadata.columns.DPS,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		detailmod.metadata = {showspots = true}
		targetmod.metadata = {click1 = detailmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Damage = true, DPS = true, Percent = true},
			icon = "Interface\\Icons\\spell_fire_fireball02"
		}
		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local dps, value = getRaidDPS(set, true)
		return Skada:FormatValueText(
			Skada:FormatNumber(value),
			self.metadata.columns.Damage,
			Skada:FormatNumber(dps),
			self.metadata.columns.DPS
		), value
	end
end)

-- =============== --
-- Overkill Module --
-- =============== --

Skada:AddLoadableModule("Overkill", function(Skada, L)
	if Skada:IsDisabled("Damage", "Overkill") then return end

	local mod = Skada:NewModule(L["Overkill"])
	local playermod = mod:NewModule(L["Overkill spell list"])
	local targetmod = mod:NewModule(L["Overkill target list"])
	local detailmod = targetmod:NewModule(L["Overkill spell list"])

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's overkill spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's overkill spells"], player.name)
			local total = player.damage and player.overkill or 0

			if total > 0 and player.damage_spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in pairs(player.damage_spells) do
					if (spell.overkill or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						d.icon = select(3, GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = spell.overkill
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's overkill targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's overkill targets"], player.name)
			local total = player.overkill or 0

			if total > 0 and player.damage_targets then
				local maxvalue, nr = 0, 1

				for targetname, target in pairs(player.damage_targets) do
					if (target.overkill or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = targetname
						d.label = targetname

						d.value = target.overkill
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function detailmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["%s's overkill spells"], win.playername or UNKNOWN)
	end

	function detailmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's overkill spells"], player.name)

			local total = 0
			if player.damage_targets and player.damage_targets[win.targetname] then
				total = player.damage_targets[win.targetname].overkill or 0
			end

			if total > 0 and player.damage_spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in pairs(player.damage_spells) do
					if spell.targets and spell.targets[win.targetname] and (spell.targets[win.targetname].overkill or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						d.icon = select(3, GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = spell.targets[win.targetname].overkill
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Overkill"]
		local total = set.overkill or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.overkill or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.overkill
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		targetmod.metadata = {click1 = detailmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Damage = true, Percent = true},
			icon = "Interface\\Icons\\spell_fire_incinerate"
		}
		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self, L["Damage Done"])
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.overkill or 0), set.overkill or 0
	end
end)

-- ====================== --
-- Absorbed Damage Module --
-- ====================== --

Skada:AddLoadableModule("Absorbed Damage", function(Skada, L)
	if Skada:IsDisabled("Damage", "Absorbed Damage") then return end

	local mod = Skada:NewModule(L["Absorbed Damage"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local targetmod = mod:NewModule(L["Damage target list"])

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's damage"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's damage"], player.name)
			local total = player.absdamage or 0

			if total > 0 and player.damage_spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in pairs(player.damage_spells) do
					if (spell.absorbed or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						d.icon = select(3, GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = spell.absorbed
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's targets"], player.name)
			local total = player.absdamage or 0

			if total > 0 and player.damage_targets then
				local maxvalue, nr = 0, 1

				for targetname, target in pairs(player.damage_targets) do
					if (target.absorbed or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = target.id or targetname
						d.label = targetname

						d.value = target.absorbed
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							Skada:FormatPercent(d.value, total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Absorbed Damage"]
		local total = set.absdamage or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.absdamage or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.absdamage
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Damage = true, Percent = true},
			icon = "Interface\\Icons\\spell_fire_playingwithfire"
		}
		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.absdamage or 0), set.absdamage or 0
	end
end)