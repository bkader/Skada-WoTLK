local Skada = Skada

-- cache frequently used globals
local pairs, ipairs, select = pairs, ipairs, select
local format, max = string.format, math.max
local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local newTable, delTable = Skada.newTable, Skada.delTable
local misstypes = Skada.missTypes
local _

-- =================== --
-- Damage Taken Module --
-- =================== --

Skada:AddLoadableModule("Damage Taken", function(L)
	if Skada:IsDisabled("Damage Taken") then return end

	local mod = Skada:NewModule(L["Damage Taken"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local spellmod = playermod:NewModule(L["Damage spell details"])
	local sdetailmod = spellmod:NewModule(L["Damage Breakdown"])
	local sourcemod = mod:NewModule(L["Damage source list"])
	local tdetailmod = sourcemod:NewModule(L["Damage spell list"])
	local tContains = tContains

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_damage(set, dmg, tick)
		if dmg.spellid and tContains(ignoredSpells, dmg.spellid) then return end

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
		if set ~= Skada.current then return end

		local spellname = dmg.spellname .. (tick and L["DoT"] or "")
		local spell = player.damagetakenspells and player.damagetakenspells[spellname]
		if not spell then
			player.damagetakenspells = player.damagetakenspells or {}
			spell = {id = dmg.spellid, school = dmg.spellschool, amount = 0}
			player.damagetakenspells[spellname] = spell
		elseif dmg.spellid and dmg.spellid ~= spell.id then
			if dmg.spellschool and dmg.spellschool ~= spell.school then
				spellname = spellname .. " (" .. (Skada.schoolnames[dmg.spellschool] or OTHER) .. ")"
			else
				spellname = GetSpellInfo(dmg.spellid)
			end
			if not player.damagetakenspells[spellname] then
				player.damagetakenspells[spellname] = {id = dmg.spellid, school = dmg.spellschool, amount = 0}
			end
			spell = player.damagetakenspells[spellname]
		end

		spell.count = (spell.count or 0) + 1
		spell.amount = spell.amount + dmg.amount
		spell.total = (spell.total or spell.amount) + dmg.amount

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

		if absorbed > 0 then
			spell.total = spell.total + dmg.absorbed
		end

		if (dmg.blocked or 0) > 0 then
			spell.blocked = (spell.blocked or 0) + dmg.blocked
		end

		if (dmg.resisted or 0) > 0 then
			spell.resisted = (spell.resisted or 0) + dmg.resisted
		end

		if (dmg.overkill or 0) > 0 then
			spell.overkill = (spell.overkill or 0) + dmg.overkill
		end

		-- record the source
		if dmg.srcName then
			local actor = Skada:GetActor(set, dmg.srcGUID, dmg.srcName, dmg.srcFlags)
			if not actor then return end
			local source = spell.sources and spell.sources[dmg.srcName]
			if not source then
				spell.sources = spell.sources or {}
				spell.sources[dmg.srcName] = {amount = 0, total = 0}
				source = spell.sources[dmg.srcName]
			end
			source.amount = source.amount + dmg.amount
			source.total = source.total + dmg.amount
			if absorbed > 0 then
				source.total = source.total + absorbed
			end
			if (dmg.overkill or 0) > 0 then
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
				local _, spellname, _, amount = ...
				extraATT = extraATT or newTable()
				if not extraATT[srcName] then
					extraATT[srcName] = {spellname = spellname, amount = amount}
				end
				return
			end

			if eventtype == "SWING_DAMAGE" then
				dmg.spellid, dmg.spellname, dmg.spellschool = 6603, L["Melee"], 1
				dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing, dmg.crushing = ...

				-- an extra attack?
				if extraATT and extraATT[srcName] then
					dmg.spellname = dmg.spellname .. " (" .. extraATT[srcName].spellname .. ")"
					extraATT[srcName].amount = max(0, extraATT[srcName].amount - 1)
					if extraATT[srcName].amount == 0 then
						extraATT[srcName] = nil
					end
				end
			else
				dmg.spellid, dmg.spellname, dmg.spellschool, dmg.amount, dmg.overkill, _, dmg.resisted, dmg.blocked, dmg.absorbed, dmg.critical, dmg.glancing, dmg.crushing = ...
			end

			dmg.srcGUID = srcGUID
			dmg.srcName = srcName
			dmg.srcFlags = srcFlags

			dmg.playerid = dstGUID
			dmg.playername = dstName
			dmg.playerflags = dstFlags

			dmg.misstype = nil

			log_damage(Skada.current, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
			log_damage(Skada.total, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
		end
	end

	local function EnvironmentDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local envtype = ...
		local spellid, spellname

		if envtype == "Falling" or envtype == "FALLING" then
			spellid, spellname = 3, ACTION_ENVIRONMENTAL_DAMAGE_FALLING
		elseif envtype == "Drowning" or envtype == "DROWNING" then
			spellid, spellname = 4, ACTION_ENVIRONMENTAL_DAMAGE_DROWNING
		elseif envtype == "Fatigue" or envtype == "FATIGUE" then
			spellid, spellname = 5, ACTION_ENVIRONMENTAL_DAMAGE_FATIGUE
		elseif envtype == "Fire" or envtype == "FIRE" then
			spellid, spellname = 6, ACTION_ENVIRONMENTAL_DAMAGE_FIRE
		elseif envtype == "Lava" or envtype == "LAVA" then
			spellid, spellname = 7, ACTION_ENVIRONMENTAL_DAMAGE_LAVA
		elseif envtype == "Slime" or envtype == "SLIME" then
			spellid, spellname = 8, ACTION_ENVIRONMENTAL_DAMAGE_SLIME
		end

		if spellid and spellname then
			SpellDamage(nil, nil, nil, ENVIRONMENTAL_DAMAGE, nil, dstGUID, dstName, dstFlags, spellid, spellname, nil, select(2, ...))
		end
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local amount

			if eventtype == "SWING_MISSED" then
				dmg.spellid, dmg.spellname, dmg.spellschool = 6603, L["Melee"], 1
				dmg.misstype, amount = ...
			else
				dmg.spellid, dmg.spellname, dmg.spellschool, dmg.misstype, amount = ...
			end

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

			log_damage(Skada.current, dmg, eventtype == "SPELL_PERIODIC_MISSED")
			log_damage(Skada.total, dmg, eventtype == "SPELL_PERIODIC_MISSED")
		end
	end

	local function playermod_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local player = set and set:GetPlayer(win.playerid, win.playername)
		local spell = player and player.damagetakenspells and player.damagetakenspells[label]
		if spell then
			tooltip:AddLine(label .. " - " .. player.name)
			if spell.school then
				local c = Skada.schoolcolors[spell.school]
				local n = Skada.schoolnames[spell.school]
				if c and n then
					tooltip:AddLine(n, c.r, c.g, c.b)
				end
			end

			local amount = Skada.db.profile.absdamage and spell.total or spell.amount
			tooltip:AddDoubleLine(L["Average Hit"], Skada:FormatNumber(amount / spell.count), 1, 1, 1)

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
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spellmax), 1, 1, 1)
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber((spellmin + spellmax) / 2), 1, 1, 1)
			end
		end
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] then
			local set = win:GetSelectedSet()
			local player = set and set:GetPlayer(win.playerid, win.playername)
			local spell = player and player.damagetakenspells and player.damagetakenspells[win.spellname]
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
					tooltip:AddDoubleLine(L["Average Hit"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
					if spell.criticalmin and spell.criticalmax then
						tooltip:AddLine(" ")
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber((spell.criticalmin + spell.criticalmax) / 2), 1, 1, 1)
					end
				elseif label == L["Normal Hits"] and spell.hitamount then
					tooltip:AddDoubleLine(L["Average Hit"], Skada:FormatNumber(spell.hitamount / spell.hit), 1, 1, 1)
					if spell.hitmin and spell.hitmax then
						tooltip:AddLine(" ")
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.hitmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.hitmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber((spell.hitmin + spell.hitmax) / 2), 1, 1, 1)
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["Damage taken by %s"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["Damage taken by %s"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player:GetDamageTaken() or 0

		if total > 0 and player.damagetakenspells then
			local maxvalue, nr = 0, 1

			for spellname, spell in pairs(player.damagetakenspells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellname
				d.spellid = spell.id
				d.label = spellname
				d.icon = select(3, GetSpellInfo(spell.id))
				d.spellschool = spell.school

				d.value = spell.amount
				if Skada.db.profile.absdamage then
					d.value = min(total, spell.total)
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

	function sourcemod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's damage sources"], label)
	end

	function sourcemod:Update(win, set)
		win.title = format(L["%s's damage sources"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player:GetDamageTaken() or 0
		local sources = (total > 0) and player:GetDamageSources()

		if sources then
			local maxvalue, nr = 0, 1

			for sourcename, source in pairs(sources) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = source.id or sourcename
				d.label = sourcename
				d.class = source.class
				d.role = source.role
				d.spec = source.spec

				d.value = Skada.db.profile.absdamage and source.total or source.amount
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

		if d.value > win.metadata.maxvalue then
			win.metadata.maxvalue = d.value
		end
		nr = nr + 1
		return nr
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's damage on %s"], label, win.playername or L.Unknown)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's damage on %s"], win.spellname or L.Unknown, win.playername or L.Unknown)
		if not win.spellname then return end

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local spell = player and player.damagetakenspells and player.damagetakenspells[win.spellname]
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
				nr = add_detail_bar(win, nr, L["Glancing"], spell.glancing, true)
			end

			if (spell.crushing or 0) > 0 then
				nr = add_detail_bar(win, nr, L["Crushing"], spell.crushing, true)
			end

			for _, misstype in ipairs(misstypes) do
				if (spell[misstype] or 0) > 0 then
					nr = add_detail_bar(win, nr, L[misstype], spell[misstype], true)
				end
			end
		end
	end

	function sdetailmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's damage breakdown"], label)
	end

	function sdetailmod:Update(win, set)
		win.title = format(L["%s's damage breakdown"], win.spellname or L.Unknown)
		if not win.spellname then return end

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local spell = player and player.damagetakenspells and player.damagetakenspells[win.spellname]
		if spell then
			local absorbed = max(0, spell.total - spell.amount)
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

			if (spell.blocked or 0) > 0 then
				nr = add_detail_bar(win, nr, L["BLOCK"], spell.blocked, true, true)
			end

			if (spell.resisted or 0) > 0 then
				nr = add_detail_bar(win, nr, L["RESIST"], spell.resisted, true, true)
			end
		end
	end

	function tdetailmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["%s's damage on %s"], label, win.playername or L.Unknown)
	end

	function tdetailmod:Update(win, set)
		win.title = format(L["%s's damage on %s"], win.targetname or L.Unknown, win.playername or L.Unknown)
		if not win.targetname then return end

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local sources = player and player:GetDamageSources()
		if sources then
			local total = sources[win.targetname] and sources[win.targetname].amount or 0
			if Skada.db.profile.absdamage then
				total = sources[win.targetname].total or total
			end

			if total > 0 and player.damagetakenspells then
				local maxvalue, nr = 0, 1

				for spellname, spell in pairs(player.damagetakenspells) do
					if spell.sources and spell.sources[win.targetname] then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						d.icon = select(3, GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = spell.sources[win.targetname].amount or 0
						if Skada.db.profile.absdamage then
							d.value = spell.sources[win.targetname].total or d.value
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
		win.title = L["Damage Taken"]
		local total = set and set:GetDamageTaken() or 0
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local dtps, amount = player:GetDTPS()
				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Damage,
						Skada:FormatNumber(dtps),
						self.metadata.columns.DTPS,
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
		spellmod.metadata = {tooltip = spellmod_tooltip}
		playermod.metadata = {click1 = spellmod, click2 = sdetailmod, post_tooltip = playermod_tooltip}
		sourcemod.metadata = {click1 = tdetailmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = sourcemod,
			nototalclick = {playermod, sourcemod},
			columns = {Damage = true, DTPS = true, Percent = true},
			icon = [[Interface\Icons\ability_mage_frostfirebolt]]
		}

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_EXTRA_ATTACKS", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(EnvironmentDamage, "ENVIRONMENTAL_DAMAGE", {dst_is_interesting_nopets = true})

		Skada:RegisterForCL(SpellMissed, "DAMAGE_SHIELD_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SWING_MISSED", {dst_is_interesting_nopets = true})

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if not set then return end
		local dtps, amount = set:GetDTPS()
		tooltip:AddDoubleLine(L["Damage Taken"], Skada:FormatNumber(amount), 1, 1, 1)
		tooltip:AddDoubleLine(L["DTPS"], Skada:FormatNumber(dtps), 1, 1, 1)
	end

	function mod:GetSetSummary(set)
		if not set then return end
		local dtps, amount = set:GetDTPS()
		return Skada:FormatValueText(
			Skada:FormatNumber(amount),
			self.metadata.columns.Damage,
			Skada:FormatNumber(dtps),
			self.metadata.columns.DTPS
		), amount
	end

	function mod:SetComplete(set)
		delTable(extraATT)

		-- clean set from garbage before it is saved.
		for _, p in ipairs(set.players) do
			if p.totaldamagetaken and p.totaldamagetaken == 0 then
				p.damagetakenspells = nil
			elseif p.damagetakenspells then
				for spellname, spell in pairs(p.damagetakenspells) do
					if spell.total == 0 then
						p.damagetakenspells[spellname] = nil
					end
				end
				-- nothing left?
				if next(p.damagetakenspells) == nil then
					p.damagetakenspells = nil
				end
			end
		end
	end

	do
		local setPrototype = Skada.setPrototype
		local playerPrototype = Skada.playerPrototype
		local cacheTable = Skada.cacheTable
		local wipe = wipe

		function setPrototype:GetDamageTaken()
			return Skada.db.profile.absdamage and self.totaldamagetaken or self.damagetaken or 0
		end

		function setPrototype:GetDTPS()
			local damage, dtps = self:GetDamageTaken(), 0
			if damage > 0 then
				dtps = damage / max(1, self:GetTime())
			end
			return dtps, damage
		end

		function playerPrototype:GetDamageTaken()
			return Skada.db.profile.absdamage and self.totaldamagetaken or self.damagetaken or 0
		end

		function playerPrototype:GetDTPS(active)
			local damage, dtps = self:GetDamageTaken(), 0
			if damage > 0 then
				dtps = damage / max(1, self:GetTime(active))
			end
			return dtps, damage
		end

		function playerPrototype:GetDamageSources()
			if self.damagetakenspells then
				wipe(cacheTable)
				for _, spell in pairs(self.damagetakenspells) do
					if spell.sources then
						for name, source in pairs(spell.sources) do
							if not cacheTable[name] then
								cacheTable[name] = {amount = source.amount, total = source.total, overkill = source.overkill}
							else
								cacheTable[name].amount = cacheTable[name].amount + source.amount
								if source.total then
									cacheTable[name].total = (cacheTable[name].total or 0) + source.total
								end
								if source.overkill then
									cacheTable[name].overkill = (cacheTable[name].overkill or 0) + source.overkill
								end
							end

							-- attempt to get the class
							if not cacheTable[name].class then
								local actor = self.super:GetActor(name)
								if actor then
									cacheTable[name].id = actor.id
									cacheTable[name].class = actor.class
									cacheTable[name].role = actor.role
									cacheTable[name].spec = actor.spec
								else
									cacheTable[name].class = "UNKNOWN"
								end
							end
						end
					end
				end
				return cacheTable
			end
		end
	end
end)

-- ============================== --
-- Damage taken per second module --
-- ============================== --

Skada:AddLoadableModule("DTPS", function(L)
	if Skada:IsDisabled("Damage Taken", "DTPS") then return end

	local mod = Skada:NewModule(L["DTPS"])

	local function dtps_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local player = set and set:GetPlayer(id, label)
		if player then
			local totaltime = set:GetTime()
			local activetime = player:GetTime()
			local dtps, damage = player:GetDTPS()
			tooltip:AddLine(player.name .. " - " .. L["DTPS"])
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(player:GetTime(true)), 1, 1, 1)
			tooltip:AddDoubleLine(L["Damage Taken"], Skada:FormatNumber(damage), 1, 1, 1)
			tooltip:AddDoubleLine(Skada:FormatNumber(damage) .. "/" .. Skada:FormatTime(activetime), Skada:FormatNumber(dtps), 1, 1, 1)
		end
	end

	function mod:Update(win, set)
		win.title = L["DTPS"]
		local total = set and set:GetDTPS()
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local dtps = player:GetDTPS()
				if dtps > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = dtps
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.DTPS,
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
			tooltip = dtps_tooltip,
			columns = {DTPS = true, Percent = true},
			icon = [[Interface\Icons\inv_misc_pocketwatch_02]]
		}

		local parentmod = Skada:GetModule(L["Damage Taken"], true)
		if parentmod then
			self.metadata.click1 = parentmod.metadata.click1
			self.metadata.click2 = parentmod.metadata.click2
			self.metadata.nototalclick = parentmod.metadata.nototalclick
		end

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set and set:GetDTPS() or 0)
	end
end)

-- ============================ --
-- Damage Taken By Spell Module --
-- ============================ --

Skada:AddLoadableModule("Damage Taken By Spell", function(L)
	if Skada:IsDisabled("Damage Taken", "Damage Taken By Spell") then return end

	local mod = Skada:NewModule(L["Damage Taken By Spell"])
	local targetmod = mod:NewModule(L["Damage spell targets"])
	local cacheTable = Skada.cacheTable

	function targetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's targets"], win.spellname or L.Unknown)
		if win.spellname then
			wipe(cacheTable)
			local total = 0

			for _, player in ipairs(set.players) do
				if
					player.damagetakenspells and
					player.damagetakenspells[win.spellname] and
					(player.damagetakenspells[win.spellname].total or 0) > 0
				then
					cacheTable[player.name] = {
						id = player.id,
						class = player.class,
						role = player.role,
						spec = player.spec,
						amount = player.damagetakenspells[win.spellname].amount
					}
					if Skada.db.profile.absdamage then
						cacheTable[player.name].amount = player.damagetakenspells[win.spellname].total
					end

					total = total + cacheTable[player.name].amount
				end
			end

			if total > 0 then
				local maxvalue, nr = 0, 1
				for playername, player in pairs(cacheTable) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or playername
					d.label = playername
					d.text = player.id and Skada:FormatName(playername, player.id)
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
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Damage Taken By Spell"]
		local total = set and set:GetDamageTaken() or 0
		if total == 0 then return end

		wipe(cacheTable)
		for _, player in ipairs(set.players) do
			if player.damagetakenspells then
				for spellname, spell in pairs(player.damagetakenspells) do
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
	end

	function mod:OnEnable()
		targetmod.metadata = {showspots = true}
		self.metadata = {
			showspots = true,
			click1 = targetmod,
			columns = {Damage = true, Percent = true},
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

Skada:AddLoadableModule("Avoidance & Mitigation", function(L)
	if Skada:IsDisabled("Damage Taken", "Avoidance & Mitigation") then return end

	local mod = Skada:NewModule(L["Avoidance & Mitigation"])
	local playermod = mod:NewModule(L["Damage Breakdown"])
	local cacheTable = Skada.cacheTable

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's damage breakdown"], label)
	end

	function playermod:Update(win, set)
		if cacheTable[win.playerid] then
			local player = cacheTable[win.playerid]
			win.title = format(L["%s's damage breakdown"], player.name)

			local maxvalue, nr = 0, 1

			for event, count in pairs(player.data) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = event
				d.label = L[event]

				d.value = 100 * count / player.total
				d.valuetext = Skada:FormatValueText(
					Skada:FormatPercent(d.value),
					mod.metadata.columns.Percent,
					count,
					mod.metadata.columns.Count,
					player.total,
					mod.metadata.columns.Total
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
		win.title = L["Avoidance & Mitigation"]
		if (set.damagetaken or 0) > 0 then
			wipe(cacheTable) -- used later

			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if player.damagetakenspells then
					local tmp = {name = player.name, data = {}}

					local total, avoid = 0, 0
					for _, spell in pairs(player.damagetakenspells) do
						total = total + spell.count

						for _, t in ipairs(misstypes) do
							if (spell[t] or 0) > 0 then
								avoid = avoid + spell[t]
								tmp.data[t] = (tmp.data[t] or 0) + spell[t]
							end
						end
					end

					if avoid > 0 then
						tmp.total = total
						tmp.avoid = avoid
						cacheTable[player.id] = tmp

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						d.value = 100 * avoid / total
						d.valuetext = Skada:FormatValueText(
							Skada:FormatPercent(d.value),
							self.metadata.columns.Percent,
							avoid,
							self.metadata.columns.Count,
							total,
							self.metadata.columns.Total
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					elseif cacheTable[player.id] then
						cacheTable[player.id] = nil
					end
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		playermod.metadata = {}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			columns = {Percent = true, Count = true, Total = true},
			icon = [[Interface\Icons\ability_warrior_shieldwall]]
		}

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)

-- ================ --
-- Damage Mitigated --
-- ================ --

Skada:AddLoadableModule("Damage Mitigated", function(L)
	if Skada:IsDisabled("Damage Taken", "Damage Mitigated") then return end

	local mod = Skada:NewModule(L["Damage Mitigated"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local spellmod = playermod:NewModule(L["Damage spell details"])

	local function getMIT(player)
		local amount, total = 0, 0
		if player and player.damagetakenspells then
			for _, spell in pairs(player.damagetakenspells) do
				amount = amount + spell.amount
				total = total + spell.total
			end
		end
		return amount, total
	end

	local function add_detail_bar(win, nr, title, value)
		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = title
		d.label = title
		d.value = value
		d.valuetext = Skada:FormatValueText(
			Skada:FormatNumber(value),
			mod.metadata.columns.Damage,
			Skada:FormatPercent(value, win.metadata.maxvalue),
			mod.metadata.columns.Percent
		)

		if value > win.metadata.maxvalue then
			win.metadata.maxvalue = value
		end
		nr = nr + 1
		return nr
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's <%s> mitigated damage"], win.playername or L.Unknown, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's <%s> mitigated damage"], win.playername or L.Unknown, win.spellname or L.Unknown)
		if not win.spellname then return end

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local spell = player and player.damagetakenspells and player.damagetakenspells[win.spellname]

		if spell then
			win.metadata.maxvalue = spell.total

			local nr = add_detail_bar(win, 1, L["Total"], win.metadata.maxvalue)
			nr = add_detail_bar(win, nr, L["Damage Taken"], spell.amount)

			local absorbed = max(0, spell.total - spell.amount)
			if absorbed then
				nr = add_detail_bar(win, nr, L["ABSORB"], absorbed)
			end

			if (spell.blocked or 0) > 0 then
				nr = add_detail_bar(win, nr, L["BLOCK"], spell.blocked)
				win.metadata.maxvalue = win.metadata.maxvalue + spell.blocked
			end

			if (spell.resisted or 0) > 0 then
				nr = add_detail_bar(win, nr, L["RESIST"], spell.resisted)
				win.metadata.maxvalue = win.metadata.maxvalue + spell.resisted
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's mitigated damage"], label)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's mitigated damage"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local overall = player and select(2, getMIT(player))

		if overall > 0 and player.damagetakenspells then
			local maxvalue, nr = 0, 1

			for spellname, spell in pairs(player.damagetakenspells) do
				if spell.total > 0 then
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
						mod.metadata.columns.Damage,
						Skada:FormatNumber(spell.total),
						mod.metadata.columns.Total,
						Skada:FormatPercent(d.value, spell.total),
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

	function mod:Update(win, set)
		win.title = L["Damage Mitigated"]
		if (set.damagetaken or 0) > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local amount, total = getMIT(player)

				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Damage,
						Skada:FormatNumber(total),
						self.metadata.columns.Total,
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
		playermod.metadata = {click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			columns = {Damage = true, Total = true, Percent = true},
			icon = [[Interface\Icons\spell_shadow_shadowward]]
		}

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)