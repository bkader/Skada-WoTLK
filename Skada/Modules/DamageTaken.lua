assert(Skada, "Skada not found!")

-- cache frequently used globals
local _pairs, _ipairs, _select = pairs, ipairs, select
local _format, math_max, math_min = string.format, math.max, math.min
local _GetSpellInfo = Skada.GetSpellInfo

-- list of miss types
local misstypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}

-- =================== --
-- Damage Taken Module --
-- =================== --

Skada:AddLoadableModule("Damage taken", function(Skada, L)
	if Skada:IsDisabled("Damage taken") then return end

	local mod = Skada:NewModule(L["Damage taken"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local spellmod = mod:NewModule(L["Damage spell details"])
	local sourcemod = mod:NewModule(L["Damage source list"])

	local function log_damage(set, dmg)
		local player = Skada:get_player(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if not player then
			return
		end

		player.damagetaken.amount = player.damagetaken.amount + dmg.amount
		set.damagetaken = set.damagetaken + dmg.amount

		-- add the spell
		local spellname = dmg.spellname
		if spellname == L["Auto Attack"] then
			spellname = spellname .. " (" .. (dmg.srcName or UNKNOWN) .. ")"
		end

		local spell = player.damagetaken.spells[spellname] or {id = dmg.spellid, school = dmg.spellschool, source = dmg.srcName, amount = 0}
		player.damagetaken.spells[spellname] = spell
		spell.totalhits = (spell.totalhits or 0) + 1
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
		end

		if dmg.blocked then
			spell.blocked = (spell.blocked or 0) + dmg.blocked
		end

		if dmg.resisted then
			spell.resisted = (spell.resisted or 0) + dmg.resisted
		end

		if set == Skada.current and dmg.srcName and dmg.amount > 0 then
			player.damagetaken.sources[dmg.srcName] = (player.damagetaken.sources[dmg.srcName] or 0) + dmg.amount
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...

		dmg.srcGUID = srcGUID
		dmg.srcName = srcName

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

		log_damage(Skada.current, dmg)
		log_damage(Skada.total, dmg)
	end

	local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, L["Auto Attack"], 1, ...)
	end

	local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, misstype, amount = ...

		dmg.srcGUID = srcGUID
		dmg.srcName = srcName

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
		SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, L["Auto Attack"], 1, ...)
	end

	local function getDTPS(set, player)
		return player.damagetaken.amount / math_max(1, Skada:PlayerActiveTime(set, player))
	end

	local function getRaidDTPS(set)
		if set.time > 0 then
			return set.damagetaken / math_max(1, set.time)
		else
			return set.damagetaken / math_max(1, (set.endtime or time()) - set.starttime)
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["Damage taken by %s"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)
		local max = 0

		if player and player.damagetaken and player.damagetaken.spells then
			win.title = _format(L["Damage taken by %s"], player.name)

			local nr = 1
			for spellname, spell in _pairs(player.damagetaken.spells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellname
				d.spellid = spell.id
				d.spellschool = spell.school
				d.label = spellname
				d.icon = _select(3, _GetSpellInfo(spell.id))

				d.value = spell.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(spell.amount),
					mod.metadata.columns.Damage,
					_format("%02.1f%%", 100 * spell.amount / math_max(1, player.damagetaken.amount)),
					mod.metadata.columns.Percent
				)

				if spell.amount > max then
					max = spell.amount
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	function sourcemod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's damage sources"], label)
	end

	function sourcemod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)
		local max = 0

		if player and player.damagetaken and player.damagetaken.sources then
			win.title = _format(L["%s's damage sources"], player.name)

			local nr = 1
			for mobname, amount in _pairs(player.damagetaken.sources) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = mobname
				d.label = mobname

				d.value = amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(amount),
					mod.metadata.columns.Damage,
					_format("%02.1f%%", 100 * amount / math_max(1, player.damagetaken.amount)),
					mod.metadata.columns.Percent
				)

				if amount > max then
					max = amount
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	local function add_detail_bar(win, nr, title, value)
		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = title
		d.label = title
		d.value = value
		if title == L["Total"] then
			d.valuetext = value
		else
			d.valuetext = Skada:FormatValueText(
				value,
				mod.metadata.columns.Damage,
				_format("%02.1f%%", 100 * value / math_max(1, win.metadata.maxvalue)),
				mod.metadata.columns.Percent
			)
		end
	end

	function spellmod:Enter(win, id, label)
		win.spellname = label
		win.title = _format(L["%s damage on %s"], label, win.playername or UNKNOWN)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)

		if player and player.damagetaken and player.damagetaken.spells then
			local spell = player.damagetaken.spells[win.spellname]

			if spell then
				win.title = _format(L["%s damage on %s"], win.spellname, player.name)
				win.metadata.maxvalue = spell.totalhits

				local nr = 1
				add_detail_bar(win, nr, L["Total"], spell.totalhits)

				if spell.hit and spell.hit > 0 then
					nr = nr + 1
					add_detail_bar(win, nr, HIT, spell.hit)
				end
				if spell.critical and spell.critical > 0 then
					nr = nr + 1
					add_detail_bar(win, nr, CRIT_ABBR, spell.critical)
				end
				if spell.glancing and spell.glancing > 0 then
					nr = nr + 1
					add_detail_bar(win, nr, L["Glancing"], spell.glancing)
				end
				if spell.crushing and spell.crushing > 0 then
					add_detail_bar(win, nr, L["Crushing"], spell.crushing)
					nr = nr + 1
				end

				for i, misstype in _ipairs(misstypes) do
					if spell[misstype] and spell[misstype] > 0 then
						local title = _G[misstype] or _G["ACTION_SPELL_MISSED" .. misstype] or misstype
						nr = nr + 1
						add_detail_bar(win, nr, title, spell[misstype])
					end
				end
			end
		end
	end

	function mod:Update(win, set)
		local nr, max = 1, 0
		local settime = Skada:GetSetTime(set)

		for _, player in _ipairs(set.players) do
			if player.damagetaken.amount > 0 then
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = player.name
				d.class = player.class or "PET"
				d.role = player.role or "DAMAGER"
				d.spec = player.spec or 1

				d.value = player.damagetaken.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(player.damagetaken.amount),
					self.metadata.columns.Damage,
					Skada:FormatNumber(getDTPS(set, player)),
					self.metadata.columns.DTPS,
					_format("%02.1f%%", 100 * player.damagetaken.amount / math_max(1, set.damagetaken)),
					self.metadata.columns.Percent
				)

				if player.damagetaken.amount > max then
					max = player.damagetaken.amount
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
		win.title = L["Damage taken"]
	end

	local function player_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), win.playerid)
		if not player then
			return
		end

		local spell = player.damagetaken.spells[label]
		if spell then
			tooltip:AddLine(label .. " - " .. player.name)
			if spell.school then
				local c = Skada.schoolcolors[spell.school]
				local n = Skada.schoolnames[spell.school]
				if c and n then
					tooltip:AddLine(n, c.r, c.g, c.b)
				end
			end

			if spell.max and spell.min then
				tooltip:AddDoubleLine(L["Minimum hit:"], Skada:FormatNumber(spell.min), 1, 1, 1)
				tooltip:AddDoubleLine(L["Maximum hit:"], Skada:FormatNumber(spell.max), 1, 1, 1)
			end
			tooltip:AddDoubleLine(L["Average hit:"], Skada:FormatNumber(spell.amount / spell.totalhits), 1, 1, 1)
		end
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == CRIT_ABBR or label == HIT or label == ABSORB or label == BLOCK or label == RESIST then
			local player = Skada:find_player(win:get_selected_set(), win.playerid)
			if not player then
				return
			end

			local spell = player.damagetaken.spells[win.spellname]
			if spell then
				tooltip:AddLine(player.name .. " - " .. win.spellname)

				if spell.school then
					local c = Skada.schoolcolors[spell.school]
					local n = Skada.schoolnames[spell.school]
					if c and n then
						tooltip:AddLine(n, c.r, c.g, c.b)
					end
				end

				if label == CRIT_ABBR and spell.criticalamount then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
					tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
				elseif label == HIT and spell.hitamount then
					tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.hitmin), 1, 1, 1)
					tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.hitmax), 1, 1, 1)
					tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.hitamount / spell.hit), 1, 1, 1)
				elseif label == ABSORB and spell.absorbed and spell.absorbed > 0 then
					tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.absorbed), 1, 1, 1)
				elseif label == BLOCK and spell.blocked and spell.blocked > 0 then
					tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.blocked), 1, 1, 1)
				elseif label == RESIST and spell.resisted and spell.resisted > 0 then
					tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.resisted), 1, 1, 1)
				end
			end
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = spellmod_tooltip}
		playermod.metadata = {post_tooltip = player_tooltip, click1 = spellmod}
		sourcemod.metadata = {}
		mod.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = sourcemod,
			columns = {Damage = true, DTPS = true, Percent = true}
		}

		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true})

		Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {dst_is_interesting_nopets = true})

		Skada:AddMode(self, L["Damage taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		tooltip:AddDoubleLine(L["Damage taken"], Skada:FormatNumber(set.damagetaken), 1, 1, 1)
		tooltip:AddDoubleLine(L["DTPS"], Skada:FormatNumber(getRaidDTPS(set)), 1, 1, 1)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatValueText(
			Skada:FormatNumber(set.damagetaken),
			self.metadata.columns.Damage,
			Skada:FormatNumber(getRaidDTPS(set)),
			self.metadata.columns.DTPS
		)
	end

	function mod:AddPlayerAttributes(player)
		if not player.damagetaken then
			player.damagetaken = {amount = 0, spells = {}, sources = {}}
		end
	end

	function mod:AddSetAttributes(set)
		set.damagetaken = set.damagetaken or 0
	end

	function mod:SetComplete(set)
		for i, player in _ipairs(set.players) do
			if player.damagetaken.amount == 0 then
				player.damagetaken.spells = nil
				player.damagetaken.sources = nil
			end

			-- remove this entry anyways
			if set == Skada.total then
				player.damagetaken.sources = nil
			end
		end
	end
end)

-- ============================ --
-- Damage taken by spell Module --
-- ============================ --

Skada:AddLoadableModule("Damage taken by spell", function(Skada, L)
	if Skada:IsDisabled("Damage taken", "Damage taken by spell") then return end

	local mod = Skada:NewModule(L["Damage taken by spell"])
	local targetmod = mod:NewModule(L["Damage spell targets"])

	local cached = {}

	function targetmod:Enter(win, id, label)
		win.spellname = label
		win.title = _format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		local max = 0

		if set ~= Skada.total and win.spellname and cached[win.spellname] then
			win.title = _format(L["%s's targets"], win.spellname)

			local nr = 1
			local total = math_max(1, cached[win.spellname].amount)

			for playername, player in _pairs(cached[win.spellname].players) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = playername
				d.class = player.class or "PET"
				d.role = player.role or "DAMAGER"
				d.spec = player.spec or 1

				d.value = player.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(player.amount),
					mod.metadata.columns.Damage,
					_format("%02.1f%%", 100 * player.amount / math_max(1, total)),
					mod.metadata.columns.Percent
				)

				if player.amount > max then
					max = player.amount
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
		win.title = L["Damage taken by spell"]
	end

	-- for performance purposes, we ignore total segment
	function mod:Update(win, set)
		local max = 0

		if set ~= Skada.total then
			local nr = 1

			cached = {}
			for i, player in _ipairs(set.players) do
				if player.damagetaken.amount > 0 then
					for spellname, spell in _pairs(player.damagetaken.spells) do
						if spell.amount > 0 then
							if not cached[spellname] then
								cached[spellname] = {
									id = spell.id,
									school = spell.school,
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
									role = player.role or "DAMAGER",
									spec = player.spec or 1,
									amount = spell.amount
								}
							else
								cached[spellname].players[player.name].amount =
									cached[spellname].players[player.name].amount + spell.amount
							end
						end
					end
				end
			end

			for spellname, spell in _pairs(cached) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellname
				d.spellid = spell.id
				d.spellname = spellname
				d.spellschool = spell.school
				d.label = spellname
				d.icon = _select(3, _GetSpellInfo(spell.id))

				d.value = spell.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(spell.amount),
					self.metadata.columns.Damage,
					_format("%02.1f%%", 100 * spell.amount / math_max(1, set.damagetaken)),
					self.metadata.columns.Percent
				)

				if spell.amount > max then
					max = spell.amount
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
		win.title = L["Damage taken by spell"]
	end

	function mod:OnEnable()
		targetmod.metadata = {showspots = true}
		mod.metadata = {
			showspots = true,
			click1 = targetmod,
			columns = {Damage = true, Percent = true}
		}
		Skada:AddMode(self, L["Damage taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)

-- ============================= --
-- Avoidance & Mitigation Module --
-- ============================= --

Skada:AddLoadableModule("Avoidance & Mitigation", function(Skada, L)
	if Skada:IsDisabled("Damage taken", "Avoidance & Mitigation") then return end

	local mod = Skada:NewModule(L["Avoidance & Mitigation"])
	local playermod = mod:NewModule(L["Damage breakdown"])

	local temp = {}

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's damage breakdown"], label)
	end

	function playermod:Update(win, set)
		local max = 0

		if temp[win.playerid] then
			local nr, p = 1, temp[win.playerid]
			win.title = _format(L["%s's damage breakdown"], p.name)

			for event, count in _pairs(p.data) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = event
				d.label = _G[event] or event

				d.value = count / p.total * 100
				d.valuetext = Skada:FormatValueText(
					_format("%02.1f%%", d.value),
					mod.metadata.columns.Percent,
					_format("%d/%d", count, p.total),
					mod.metadata.columns.Total
				)

				if d.value > max then
					max = d.value
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	function mod:Update(win, set)
		local nr, max = 1, 0

		for i, player in _ipairs(set.players) do
			if player.damagetaken.amount > 0 then
				temp[player.id] = {name = player.name, data = {}}

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = player.name
				d.class = player.class or "PET"
				d.role = player.role or "DAMAGER"
				d.spec = player.spec or 1

				local total, avoid = 0, 0
				for spellname, spell in _pairs(player.damagetaken.spells) do
					total = total + spell.totalhits

					for _, t in _ipairs(misstypes) do
						if spell[t] and spell[t] > 0 then
							avoid = avoid + spell[t]
							if not temp[player.id].data[t] then
								temp[player.id].data[t] = spell[t]
							else
								temp[player.id].data[t] = temp[player.id].data[t] + spell[t]
							end
						end
					end
				end

				temp[player.id].total = total
				temp[player.id].avoid = avoid

				d.value = avoid / total * 100
				d.valuetext = Skada:FormatValueText(
					_format("%02.1f%%", d.value),
					self.metadata.columns.Percent,
					_format("%d/%d", avoid, total),
					self.metadata.columns.Total
				)

				if d.value > max then
					max = d.value
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
		win.title = L["Avoidance & Mitigation"]
	end

	function mod:OnEnable()
		playermod.metadata = {}
		mod.metadata = {showspots = true, click1 = playermod, columns = {Percent = true, Total = true}}

		Skada:AddMode(self, L["Damage taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)

-- ================ --
-- Damage mitigated --
-- ================ --

Skada:AddLoadableModule("Damage mitigated", function(Skada, L)
	if Skada:IsDisabled("Damage taken", "Damage mitigated") then return end

	local mod = Skada:NewModule(L["Damage mitigated"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local spellmod = mod:NewModule(L["Damage spell details"])

	function spellmod:Enter(win, id, label)
		win.spellname = id
		win.title = _format(L["%s's <%s> mitigated damage"], win.playername or UNKNOWN, label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)
		if not player or not player.damagetaken or not player.damagetaken.spells then
			return
		end
		if not win.spellname or not player.damagetaken.spells[win.spellname] then
			return
		end

		local spell = player.damagetaken.spells[win.spellname]
		local mit = (spell.blocked or 0) + (spell.absorbed or 0) + (spell.resisted or 0)
		local total = mit + spell.amount
		local max, nr, d = 0, 1

		-- start of total bar --
		d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = L["Total"]
		d.label = L["Total"]
		d.value = total
		d.valuetext = Skada:FormatNumber(total)
		max = total
		nr = nr + 1
		-- endstart of total bar --

		if spell.blocked and spell.blocked > 0 then
			d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.id = BLOCK
			d.label = BLOCK
			d.value = spell.blocked
			d.valuetext = Skada:FormatValueText(
				Skada:FormatNumber(spell.blocked),
				mod.metadata.columns.Amount,
				_format("%02.1f%%", 100 * spell.blocked / math_max(1, total)),
				mod.metadata.columns.Percent
			)

			if spell.blocked > max then
				max = spell.blocked
			end

			nr = nr + 1
		end

		if spell.absorbed and spell.absorbed > 0 then
			d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.id = ABSORB
			d.label = ABSORB
			d.value = spell.absorbed
			d.valuetext = Skada:FormatValueText(
				Skada:FormatNumber(spell.absorbed),
				mod.metadata.columns.Amount,
				_format("%02.1f%%", 100 * spell.absorbed / math_max(1, total)),
				mod.metadata.columns.Percent
			)

			if spell.absorbed > max then
				max = spell.absorbed
			end

			nr = nr + 1
		end

		if spell.resisted and spell.resisted > 0 then
			d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.id = RESIST
			d.label = RESIST
			d.value = spell.resisted
			d.valuetext = Skada:FormatValueText(
				Skada:FormatNumber(spell.resisted),
				mod.metadata.columns.Amount,
				_format("%02.1f%%", 100 * spell.resisted / math_max(1, total)),
				mod.metadata.columns.Percent
			)

			if spell.resisted > max then
				max = spell.resisted
			end

			nr = nr + 1
		end

		win.metadata.maxvalue = max
		win.title = _format(L["%s's <%s> mitigated damage"], player.name, win.spellname)
	end

	function playermod:Enter(win, id, label)
		win.playerid = id
		win.title = _format(L["%s's mitigated damage"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)
		if player and player.damagetaken and player.damagetaken.spells then
			local max, nr = 0, 1

			for spellname, spell in pairs(player.damagetaken.spells) do
				local mit = (spell.blocked or 0) + (spell.absorbed or 0) + (spell.resisted or 0)
				if mit > 0 then
					local total = mit + spell.amount

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellname
					d.spellid = spell.id
					d.label = spellname
					d.icon = _select(3, _GetSpellInfo(spell.id))

					d.value = mit
					d.valuetext =
						Skada:FormatValueText(
						Skada:FormatNumber(mit),
						mod.metadata.columns.Amount,
						Skada:FormatNumber(total),
						mod.metadata.columns.Total,
						_format("%02.1f%%", 100 * mit / math_max(1, total)),
						mod.metadata.columns.Percent
					)

					if mit > max then
						max = mit
					end

					nr = nr + 1
				end
			end

			win.metadata.maxvalue = max
			win.title = _format(L["%s's mitigated damage"], player.name)
		end
	end

	function mod:Update(win, set)
		local max, nr = 0, 1

		for _, player in next, set.players do
			local mit = 0
			if player.damagetaken and player.damagetaken.spells then
				for _, spell in pairs(player.damagetaken.spells) do
					mit = mit + (spell.blocked or 0) + (spell.absorbed or 0) + (spell.resisted or 0)
				end
			end
			if mit > 0 then
				local total = mit + player.damagetaken.amount

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = player.name
				d.class = player.class or "PET"
				d.role = player.role or "DAMAGER"
				d.spec = player.spec or 1

				d.value = mit
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(mit),
					self.metadata.columns.Amount,
					Skada:FormatNumber(total),
					self.metadata.columns.Total,
					_format("%02.1f%%", 100 * mit / math_max(1, total)),
					self.metadata.columns.Percent
				)

				if mit > max then
					max = mit
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
		win.title = L["Damage mitigated"]
	end

	function mod:OnEnable()
		playermod.metadata = {click1 = spellmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			columns = {Amount = true, Total = true, Percent = true}
		}
		Skada:AddMode(self, L["Damage taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
	end

	function mod:GetSetSummary(set)
	end
end)