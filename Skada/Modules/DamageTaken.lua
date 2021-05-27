assert(Skada, "Skada not found!")

-- cache frequently used globals
local _pairs, _ipairs, _select = pairs, ipairs, select
local _format, math_max, math_min = string.format, math.max, math.min
local _GetSpellInfo, _UnitClass = Skada.GetSpellInfo or GetSpellInfo, Skada.UnitClass

-- list of miss types
local misstypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}

-- =================== --
-- Damage Taken Module --
-- =================== --

Skada:AddLoadableModule("Damage Taken", function(Skada, L)
	if Skada:IsDisabled("Damage Taken") then return end

	local mod = Skada:NewModule(L["Damage Taken"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local spellmod = mod:NewModule(L["Damage spell details"])
	local sourcemod = mod:NewModule(L["Damage source list"])

	local function log_damage(set, dmg, tick)
		local player = Skada:get_player(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if not player then return end

		player.damagetaken = player.damagetaken or {}
		player.damagetaken.amount = (player.damagetaken.amount or 0) + dmg.amount
		set.damagetaken = (set.damagetaken or 0) + dmg.amount

		local spellname = dmg.spellname
		if spellname == L["Auto Attack"] then
			spellname = spellname .. " (" .. (dmg.srcName or UNKNOWN) .. ")"
		end

		local spell = player.damagetaken.spells and player.damagetaken.spells[spellname]
		if not spell then
			player.damagetaken.spells = player.damagetaken.spells or {}
			spell = {
				id = dmg.spellid,
				school = dmg.spellschool,
				amount = 0,
				isdot = tick or nil
			}
			player.damagetaken.spells[spellname] = spell
		elseif dmg.spellschool and dmg.spellschool ~= spell.school then
			spellname = spellname .. " (" .. (Skada.schoolnames[dmg.spellschool] or OTHER) .. ")"
			if not player.damagetaken.spells[spellname] then
				player.damagetaken.spells[spellname] = {
					id = dmg.spellid,
					school = dmg.spellschool,
					amount = 0,
					isdot = tick or nil
				}
			end
			spell = player.damagetaken.spells[spellname]
		end

		spell.count = (spell.count or 0) + 1
		spell.amount = spell.amount + dmg.amount

		if spell.max == nil or dmg.amount > spell.max then
			spell.max = dmg.amount
		end

		if (spell.min == nil or dmg.amount < spell.min) and not dmg.missed then
			spell.min = dmg.amount
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

		if dmg.absorbed then
			spell.absorbed = (spell.absorbed or 0) + dmg.absorbed
			player.damagetaken.absorbed = (player.damagetaken.absorbed or 0) + dmg.absorbed
		end

		if dmg.blocked then
			spell.blocked = (spell.blocked or 0) + dmg.blocked
			player.damagetaken.blocked = (player.damagetaken.blocked or 0) + dmg.blocked
		end

		if dmg.resisted then
			spell.resisted = (spell.resisted or 0) + dmg.resisted
			player.damagetaken.resisted = (player.damagetaken.resisted or 0) + dmg.resisted
		end

		if dmg.srcName and dmg.amount > 0 then
			spell.sources = spell.sources or {}
			if not spell.sources[dmg.srcName] then
				spell.sources[dmg.srcName] = {id = dmg.srcGUID, flags = dmg.srcFlags, amount = dmg.amount}
			else
				spell.sources[dmg.srcName].amount = spell.sources[dmg.srcName].amount + dmg.amount
			end

			player.damagetaken.sources = player.damagetaken.sources or {}
			if not player.damagetaken.sources[dmg.srcName] then
				player.damagetaken.sources[dmg.srcName] = {id = dmg.srcGUID, flags = dmg.srcFlags, amount = dmg.amount}
			else
				player.damagetaken.sources[dmg.srcName].amount = player.damagetaken.sources[dmg.srcName].amount + dmg.amount
			end
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...

		dmg.srcGUID = srcGUID
		dmg.srcName = srcName
		dmg.srcFlags = srcFlags

		dmg.playerid = dstGUID
		dmg.playername = dstName
		dmg.playerflags = dstFlags

		dmg.spellid = spellid
		dmg.spellname = spellname
		dmg.spellschool = school

		dmg.amount = amount
		dmg.resisted = resisted
		dmg.blocked = blocked
		dmg.absorbed = absorbed
		dmg.critical = critical
		dmg.glancing = glancing
		dmg.crushing = crushing
		dmg.missed = nil

		log_damage(Skada.current, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
		log_damage(Skada.total, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
	end

	local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellDamage(nil, nil, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, L["Auto Attack"], 1, ...)
	end

	local function EnvironmentDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local envtype = ...
		local spellid, spellname, spellschool

		if envtype == "Falling" or envtype == "FALLING" then
			spellid, spellschool, spellname = 3, 1, ACTION_ENVIRONMENTAL_DAMAGE_FALLING
		elseif envtype == "Drowning" or envtype == "DROWNING" then
			spellid, spellschool, spellname = 4, 1, ACTION_ENVIRONMENTAL_DAMAGE_DROWNING
		elseif envtype == "Fatigue" or envtype == "FATIGUE" then
			spellid, spellschool, spellname = 5, 1, ACTION_ENVIRONMENTAL_DAMAGE_FATIGUE
		elseif envtype == "Fire" or envtype == "FIRE" then
			spellid, spellschool, spellname = 6, 4, ACTION_ENVIRONMENTAL_DAMAGE_FIRE
		elseif envtype == "Lava" or envtype == "LAVA" then
			spellid, spellschool, spellname = 7, 4, ACTION_ENVIRONMENTAL_DAMAGE_LAVA
		elseif envtype == "Slime" or envtype == "SLIME" then
			spellid, spellschool, spellname = 8, 8, ACTION_ENVIRONMENTAL_DAMAGE_SLIME
		end

		if spellid and spellname then
			dstGUID, dstName = Skada:FixMyPets(dstGUID, dstName)
			SpellDamage(nil, nil, nil, ENVIRONMENTAL_DAMAGE, nil, dstGUID, dstName, dstFlags, spellid, spellname, nil, select(2, ...))
		end
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, misstype, amount = ...

		dmg.srcGUID = srcGUID
		dmg.srcName = srcName
		dmg.srcFlags = srcFlags

		dmg.playerid = dstGUID
		dmg.playername = dstName
		dmg.playerflags = dstFlags

		dmg.spellid = spellid
		dmg.spellname = spellname
		dmg.spellschool = spellschool

		dmg.amount = 0
		dmg.overkill = 0
		dmg.missed = misstype

		if misstype == "ABSORB" then
			dmg.absorbed = amount
		elseif misstype == "BLOCK" then
			dmg.blocked = amount
		elseif misstype == "RESIST" then
			dmg.resisted = amount
		end

		log_damage(Skada.current, dmg)
		log_damage(Skada.total, dmg)
	end

	local function SwingMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellMissed(nil, nil, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, L["Auto Attack"], 1, ...)
	end

	local function getDTPS(set, player)
		local amount = player.damagetaken and player.damagetaken.amount or 0
		return amount / math_max(1, Skada:PlayerActiveTime(set, player)), amount
	end
	mod.getDTPS = getDTPS

	local function getRaidDTPS(set)
		local amount = set.damagetaken or 0
		if set.time > 0 then
			return amount / math_max(1, set.time), amount
		else
			return amount / math_max(1, (set.endtime or time()) - set.starttime), amount
		end
	end
	mod.getRaidDTPS = getRaidDTPS

	local function playermod_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), win.playerid)
		if player and player.damagetaken then
			local spell = player.damagetaken.spells and player.damagetaken.spells[label]
			if spell then
				tooltip:AddLine(label .. " - " .. player.name)

				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
				end

				if spell.max and spell.min then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
				end
				tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber((spell.amount or 0) / spell.count), 1, 1, 1)
			end
		end
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] or label == L.ABSORB or label == L.BLOCK or label == L.RESIST then
			local player = Skada:find_player(win:get_selected_set(), win.playerid)
			if player and player.damagetaken then
				local spell = player.damagetaken.spells and player.damagetaken.spells[win.spellname]
				if spell then
					tooltip:AddLine(player.name .. " - " .. win.spellname)

					if spell.school then
						local c = Skada.schoolcolors[spell.school]
						local n = Skada.schoolnames[spell.school]
						if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
					end

					if label == L["Critical Hits"] and spell.criticalamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
					elseif label == L["Normal Hits"] and spell.hitamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.hitmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.hitmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.hitamount / spell.hit), 1, 1, 1)
					elseif label == L.ABSORB and (spell.absorbed or 0) > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.absorbed), 1, 1, 1)
					elseif label == L.BLOCK and (spell.blocked or 0) > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.blocked), 1, 1, 1)
					elseif label == L.RESIST and (spell.resisted or 0) > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.resisted), 1, 1, 1)
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["Damage taken by %s"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)

		if player then
			win.title = _format(L["Damage taken by %s"], player.name or UNKNOWN)
			local total = _select(2, getDTPS(set, player))

			if total > 0 and player.damagetaken.spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in _pairs(player.damagetaken.spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellname
					d.spellid = spell.id
					d.label = spellname
					d.icon = _select(3, _GetSpellInfo(spell.id))
					d.spellschool = spell.school

					d.value = spell.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(spell.amount),
						mod.metadata.columns.Damage,
						_format("%.1f%%", 100 * spell.amount / total),
						mod.metadata.columns.Percent
					)

					if spell.amount > maxvalue then
						maxvalue = spell.amount
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function sourcemod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's damage sources"], label)
	end

	function sourcemod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)

		if player then
			win.title = _format(L["%s's damage sources"], player.name)
			local total = _select(2, getDTPS(set, player))

			if total > 0 and player.damagetaken.sources then
				local maxvalue, nr = 0, 1

				for sourcename, source in _pairs(player.damagetaken.sources) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = source.id or sourcename
					d.label = sourcename
					d.class, d.role, d.spec = _select(2, _UnitClass(source.id, source.flags, set))

					d.value = source.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(source.amount),
						mod.metadata.columns.Damage,
						_format("%.1f%%", 100 * source.amount / total),
						mod.metadata.columns.Percent
					)

					if source.amount > maxvalue then
						maxvalue = source.amount
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	local function add_detail_bar(win, nr, title, value, percent)
		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = title
		d.label = title
		d.value = value
		d.valuetext = Skada:FormatValueText(
			value,
			mod.metadata.columns.Damage,
			_format("%.1f%%", 100 * value / math_max(1, win.metadata.maxvalue)),
			percent and mod.metadata.columns.Percent
		)
		nr = nr + 1
		return nr
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = _format(L["%s damage on %s"], label, win.playername or UNKNOWN)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)

		if player then
			win.title = _format(L["%s damage on %s"], win.spellname or UNKNOWN, player.name)

			local spell
			if player.damagetaken and player.damagetaken.spells then
				spell = player.damagetaken.spells[win.spellname]
			end

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

				for _, misstype in _ipairs(misstypes) do
					if (spell[misstype] or 0) > 0 then
						nr = add_detail_bar(win, nr, L[misstype], spell[misstype], true)
					end
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Damage Taken"]
		local total = _select(2, getRaidDTPS(set))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				local dtps, amount = getDTPS(set, player)

				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.Damage,
						Skada:FormatNumber(dtps),
						self.metadata.columns.DTPS,
						_format("%.1f%%", 100 * amount / total),
						self.metadata.columns.Percent
					)

					if amount > maxvalue then
						maxvalue = amount
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = spellmod_tooltip}
		playermod.metadata = {post_tooltip = playermod_tooltip, click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = sourcemod,
			columns = {Damage = true, DTPS = true, Percent = true},
			icon = "Interface\\Icons\\ability_mage_frostfirebolt"
		}

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_EXTRA_ATTACKS", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(EnvironmentDamage, "ENVIRONMENTAL_DAMAGE", {dst_is_interesting_nopets = true})

		Skada:RegisterForCL(SpellMissed, "DAMAGE_SHIELD_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {dst_is_interesting_nopets = true})

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		local dtps, amount = getRaidDTPS(set)
		tooltip:AddDoubleLine(L["Damage Taken"], Skada:FormatNumber(amount), 1, 1, 1)
		tooltip:AddDoubleLine(L["DTPS"], Skada:FormatNumber(dtps), 1, 1, 1)
	end

	function mod:GetSetSummary(set)
		local dtps, amount = getRaidDTPS(set)
		return Skada:FormatValueText(
			Skada:FormatNumber(amount),
			self.metadata.columns.Damage,
			Skada:FormatNumber(dtps),
			self.metadata.columns.DTPS
		)
	end

	function mod:SetComplete(set)
		for _, player in Skada:IteratePlayers(set) do
			if player.damagetaken and player.damagetaken.amount == 0 then
				player.damagetaken.spells = nil
				player.damagetaken.sources = nil
			end
		end
	end
end)

-- ============================== --
-- Damage taken per second module --
-- ============================== --

Skada:AddLoadableModule("DTPS", function(Skada, L)
	if Skada:IsDisabled("Damage Taken", "DTPS") then return end

	local parentmod = Skada:GetModule(L["Damage Taken"], true)
	if not parentmod then return end

	local mod = Skada:NewModule(L["DTPS"])
	local getDTPS = parentmod.getDTPS
	local getRaidDTPS = parentmod.getRaidDTPS

	function mod:Update(win, set)
		win.title = L["DTPS"]
		local total = getRaidDTPS(set)

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				local amount = getDTPS(set, player)

				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.DTPS,
						_format("%.1f%%", 100 * amount / total),
						self.metadata.columns.Percent
					)

					if amount > maxvalue then
						maxvalue = amount
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
			click1 = parentmod.metadata.click1,
			click2 = parentmod.metadata.click2,
			columns = {DTPS = true, Percent = true},
			icon = "Interface\\Icons\\inv_misc_pocketwatch_02"
		}

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(getRaidDTPS(set))
	end
end)

-- ============================ --
-- Damage Taken By Spell Module --
-- ============================ --

Skada:AddLoadableModule("Damage Taken By Spell", function(Skada, L)
	if Skada:IsDisabled("Damage Taken", "Damage Taken By Spell") then return end

	local mod = Skada:NewModule(L["Damage Taken By Spell"])
	local targetmod = mod:NewModule(L["Damage spell targets"])

	local cached = {}

	function targetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = _format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = _format(L["%s's targets"], win.spellname or UNKNOWN)
		if win.selectedset ~= "total" and win.spellname and cached[win.spellname] then
			local total = math_max(1, cached[win.spellname].amount or 0)
			local maxvalue, nr = 0, 1

			for playername, player in _pairs(cached[win.spellname].players or {}) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = playername
				d.class = player.class or "PET"
				d.role = player.role
				d.spec = player.spec

				d.value = player.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(player.amount),
					mod.metadata.columns.Damage,
					_format("%.1f%%", 100 * player.amount / total),
					mod.metadata.columns.Percent
				)

				if player.amount > maxvalue then
					maxvalue = player.amount
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	-- for performance purposes, we ignore total segment
	function mod:Update(win, set)
		win.title = L["Damage Taken By Spell"]

		if win.selectedset ~= "total" then
			local total = set.damagetaken or 0
			if total == 0 then
				return
			end

			cached = {}
			for _, player in Skada:IteratePlayers(set) do
				if player.damagetaken and (player.damagetaken.amount or 0) > 0 then
					for spellname, spell in _pairs(player.damagetaken.spells) do
						if spell.amount > 0 then
							if not cached[spellname] then
								cached[spellname] = {
									id = spell.id,
									school = spell.school,
									isdot = spell.isdot,
									amount = spell.amount,
									players = {}
								}
							else
								cached[spellname].amount = cached[spellname].amount + spell.amount
							end

							-- add the players
							if not cached[spellname].players[player.name] then
								cached[spellname].players[player.name] = {
									id = player.id,
									class = player.class or "PET",
									role = player.role,
									spec = player.spec,
									amount = spell.amount
								}
							else
								cached[spellname].players[player.name].amount = cached[spellname].players[player.name].amount + spell.amount
							end
						end
					end
				end
			end

			local maxvalue, nr = 0, 1

			for spellname, spell in _pairs(cached) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellname
				d.spellid = spell.id
				d.label = spellname
				d.icon = _select(3, _GetSpellInfo(spell.id))
				d.spellschool = spell.school

				d.value = spell.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(spell.amount),
					self.metadata.columns.Damage,
					_format("%.1f%%", 100 * spell.amount / total),
					self.metadata.columns.Percent
				)

				if spell.amount > maxvalue then
					maxvalue = spell.amount
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		targetmod.metadata = {showspots = true}
		self.metadata = {
			showspots = true,
			click1 = targetmod,
			columns = {Damage = true, Percent = true},
			icon = "Interface\\Icons\\spell_arcane_starfire"
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

Skada:AddLoadableModule("Avoidance & Mitigation", function(Skada, L)
	if Skada:IsDisabled("Damage Taken", "Avoidance & Mitigation") then return end

	local mod = Skada:NewModule(L["Avoidance & Mitigation"])
	local playermod = mod:NewModule(L["Damage Breakdown"])

	local temp = {}

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's damage breakdown"], label)
	end

	function playermod:Update(win, set)
		if temp[win.playerid] then
			local player = temp[win.playerid]
			win.title = _format(L["%s's damage breakdown"], player.name)

			local maxvalue, nr = 0, 1

			for event, count in _pairs(player.data) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = event
				d.label = L[event]

				d.value = 100 * count / player.total
				d.valuetext = Skada:FormatValueText(
					_format("%.1f%%", d.value),
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
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.damagetaken and (player.damagetaken.amount or 0) > 0 and player.damagetaken.spells then
					local tmp = {name = player.name, data = {}}

					local total, avoid = 0, 0
					for _, spell in _pairs(player.damagetaken.spells) do
						total = total + spell.count

						for _, t in _ipairs(misstypes) do
							if (spell[t] or 0) > 0 then
								avoid = avoid + spell[t]
								tmp.data[t] = (tmp.data[t] or 0) + spell[t]
							end
						end
					end

					if avoid > 0 then
						tmp.total = total
						tmp.avoid = avoid
						temp[player.id] = tmp

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id
						d.label = player.altname or player.name
						d.class = player.class or "PET"
						d.role = player.role
						d.spec = player.spec

						d.value = 100 * avoid / total
						d.valuetext = Skada:FormatValueText(
							_format("%.1f%%", d.value),
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
					elseif temp[player.id] then
						temp[player.id] = nil
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
			icon = "Interface\\Icons\\ability_warrior_shieldwall"
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

Skada:AddLoadableModule("Damage Mitigated", function(Skada, L)
	if Skada:IsDisabled("Damage Taken", "Damage Mitigated") then return end

	local mod = Skada:NewModule(L["Damage Mitigated"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local spellmod = playermod:NewModule(L["Damage spell details"])

	local function getMIT(player)
		local amount, total = 0, 0
		if player and player.damagetaken then
			amount = (player.damagetaken.absorbed or 0) + (player.damagetaken.blocked or 0) + (player.damagetaken.resisted or 0)
			total = (player.damagetaken.amount or 0) + amount
		end
		return amount, total
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = _format(L["%s's <%s> mitigated damage"], win.playername or UNKNOWN, label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)

		if player then
			win.title = _format(L["%s's <%s> mitigated damage"], player.name, win.spellname or UNKNOWN)

			local spell
			if player.damagetaken and player.damagetaken.spells and player.damagetaken.spells[win.spellname] then
				spell = player.damagetaken.spells[win.spellname]
			end

			if spell then
				local amount = (spell.absorbed or 0) + (spell.blocked or 0) + (spell.resisted or 0)
				local total = amount + spell.amount
				local maxvalue, nr = 0, 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				-- start of total bar --
				d.id = "Total"
				d.label = L["Total"]
				d.value = total
				d.valuetext = Skada:FormatNumber(total)
				-- end of total bar --

				-- start of amount bar --
				nr = nr + 1
				d = win.dataset[nr] or {}
				win.dataset[nr] = d
				d.id = "Damage Taken"
				d.label = L["Damage Taken"]
				d.value = spell.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(spell.amount),
					mod.metadata.columns.Amount,
					_format("%.1f%%", 100 * spell.amount / total),
					mod.metadata.columns.Percent
				)
				-- end of amount bar --

				if (spell.absorbed or 0) > 0 then
					nr = nr + 1
					d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = "ABSORB"
					d.label = L["ABSORB"]
					d.value = spell.absorbed
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(spell.absorbed),
						mod.metadata.columns.Amount,
						_format("%.1f%%", 100 * spell.absorbed / math_max(1, total)),
						mod.metadata.columns.Percent
					)

					if spell.absorbed > maxvalue then
						maxvalue = spell.absorbed
					end
				end

				if (spell.blocked or 0) > 0 then
					nr = nr + 1
					d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = "BLOCK"
					d.label = L["BLOCK"]
					d.value = spell.blocked
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(spell.blocked),
						mod.metadata.columns.Amount,
						_format("%.1f%%", 100 * spell.blocked / math_max(1, total)),
						mod.metadata.columns.Percent
					)

					if spell.blocked > maxvalue then
						maxvalue = spell.blocked
					end
				end

				if (spell.resisted or 0) > 0 then
					nr = nr + 1
					d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = "RESIST"
					d.label = L["RESIST"]
					d.value = spell.resisted
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(spell.resisted),
						mod.metadata.columns.Amount,
						_format("%.1f%%", 100 * spell.resisted / math_max(1, total)),
						mod.metadata.columns.Percent
					)

					if spell.resisted > maxvalue then
						maxvalue = spell.resisted
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's mitigated damage"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's mitigated damage"], player.name)
			local total = _select(2, getMIT(player))

			if total > 0 and player.damagetaken.spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in _pairs(player.damagetaken.spells) do
					local amount = (spell.blocked or 0) + (spell.absorbed or 0) + (spell.resisted or 0)
					if amount > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						d.icon = _select(3, _GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(amount),
							mod.metadata.columns.Amount,
							Skada:FormatNumber(total),
							mod.metadata.columns.Total,
							_format("%.1f%%", 100 * amount / total),
							mod.metadata.columns.Percent
						)

						if amount > maxvalue then
							maxvalue = amount
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Damage Mitigated"]

		if (set.damagetaken or 0) > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				local amount, total = getMIT(player)

				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.Amount,
						Skada:FormatNumber(total),
						self.metadata.columns.Total,
						_format("%.1f%%", 100 * amount / total),
						self.metadata.columns.Percent
					)

					if amount > maxvalue then
						maxvalue = amount
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
			columns = {Amount = true, Total = true, Percent = true},
			icon = "Interface\\Icons\\spell_shadow_shadowward"
		}

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)