assert(Skada, "Skada not found!")

-- cache frequently used globals
local _pairs, _ipairs, _select = pairs, ipairs, select
local _format, math_max = string.format, math.max
local _GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo

-- list of miss types
local misstypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}

-- ======================== --
-- Enemy damage taken module --
-- ======================== --

Skada:AddLoadableModule("Enemy damage taken", function(Skada, L)
	if Skada:IsDisabled("Damage", "Enemy damage taken") then return end

	local mod = Skada:NewModule(L["Enemy damage taken"])
	local enemymod = mod:NewModule(L["Damage taken per player"])
	local playermod = enemymod:NewModule(L["Damage spell list"])
	local spellmod = playermod:NewModule(L["Damage spell details"])

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == CRIT_ABBR or label == HIT or label == ABSORB or label == BLOCK or label == RESIST then
			local player = Skada:find_player(win:get_selected_set(), win.playerid, win.playername)
			if player and player.damagedone and player.damagedone.spells then
				local spell = player.damagedone.spells[win.spellname]

				if spell then
					tooltip:AddLine(player.name .. " - " .. win.spellname)

					if win.mobname and spell.sources and spell.sources[win.mobname] then
						spell = spell.sources[win.mobname]
					end

					if spell.school then
						local c = Skada.schoolcolors[spell.school]
						local n = Skada.schoolnames[spell.school]
						if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
					end

					if label == CRIT_ABBR and spell.criticalamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
					end

					if label == HIT and spell.hitamount then
						tooltip:AddDoubleLine(L["Minimum hit:"], Skada:FormatNumber(spell.hitmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum hit:"], Skada:FormatNumber(spell.hitmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average hit:"], Skada:FormatNumber(spell.hitamount / spell.hit), 1, 1, 1)
					elseif label == ABSORB and spell.absorbed and spell.absorbed > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.absorbed), 1, 1, 1)
					elseif label == BLOCK and spell.blocked and spell.blocked > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.blocked), 1, 1, 1)
					elseif label == RESISTED and spell.resisted and spell.resisted > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.resisted), 1, 1, 1)
					end
				end
			end
		end
	end

	local function add_detail_bar(win, nr, title, value)
		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = title
		d.label = title
		d.value = value
		d.valuetext = Skada:FormatValueText(
			value,
			mod.metadata.columns.Damage,
			_format("%02.1f%%", value / win.metadata.maxvalue * 100),
			mod.metadata.columns.Percent
		)
	end

	function spellmod:Enter(win, id, label)
		win.spellname = label
		win.title = _format(L["%s's <%s> damage on %s"], win.playername or UNKNOWN, label, win.mobname or UNKNOWN)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			local nr = 1

			for spellname, spell in _pairs(player.damagedone.spells) do
				if spellname == win.spellname then
					if win.mobname and spell.sources and spell.sources[win.mobname] then
						spell = spell.sources[win.mobname]
					end

					win.metadata.maxvalue = spell.totalhits
					win.title = _format(L["%s's <%s> damage on %s"], player.name, spellname, win.mobname)

					if spell.hit and spell.hit > 0 then
						add_detail_bar(win, nr, HIT, spell.hit)
						nr = nr + 1
					end

					if spell.critical and spell.critical > 0 then
						add_detail_bar(win, nr, CRIT_ABBR, spell.critical)
						nr = nr + 1
					end

					if spell.glancing and spell.glancing > 0 then
						add_detail_bar(win, nr, L["Glancing"], spell.glancing)
						nr = nr + 1
					end

					if spell.crushing and spell.crushing > 0 then
						add_detail_bar(win, nr, L["Crushing"], spell.crushing)
						nr = nr + 1
					end

					for i, misstype in _ipairs(misstypes) do
						if spell[misstype] and spell[misstype] > 0 then
							local title = _G[misstype] or _G["ACTION_SPELL_MISSED" .. misstype] or misstype
							add_detail_bar(win, nr, title, spell[misstype])
							nr = nr + 1
						end
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's damage on %s"], label, win.mobname or UNKNOWN)
	end

	function playermod:Update(win, set)
		local max = 0
		if win.mobname then
			local player = Skada:find_player(set, win.playerid, win.playername)

			if player and player.damagedone and player.damagedone.spells then
				win.title = _format(L["%s's damage on %s"], player.name, win.mobname)

				local nr, total = 1, player.damagedone.targets[win.mobname].amount or 0

				for spellname, spell in _pairs(player.damagedone.spells) do
					if spell.targets and spell.targets[win.mobname] then
						local amount = spell.targets[win.mobname].amount

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spell.id
						d.spellid = spell.id
						d.label = spellname
						d.text = spellname .. (spell.isdot and L["DoT"] or "")
						d.icon = _select(3, _GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(amount),
							mod.metadata.columns.Damage,
							_format("%02.1f%%", 100 * amount / math_max(1, total)),
							mod.metadata.columns.Percent
						)

						if amount > max then
							max = amount
						end

						nr = nr + 1
					end
				end
			end
		end

		win.metadata.maxvalue = max
	end

	function enemymod:Enter(win, id, label)
		win.mobname = label
		win.title = _format(L["Damage on %s"], label)
	end

	function enemymod:Update(win, set)
		local total, max = 0, 0
		if win.mobname then
			win.title = _format(L["Damage on %s"], win.mobname)

			for _, player in _ipairs(set.players) do
				if player.damagedone and player.damagedone.targets and player.damagedone.targets[win.mobname] then
					total = total + player.damagedone.targets[win.mobname].amount
				end
			end

			local nr = 1
			for _, player in _ipairs(set.players) do
				if player.damagedone and player.damagedone.targets and player.damagedone.targets[win.mobname] then
					local amount = player.damagedone.targets[win.mobname].amount

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.class = player.class or "PET"
					d.role = player.role or "DAMAGER"
					d.spec = player.spec or 1

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						mod.metadata.columns.Damage,
						_format("%02.1f%%", 100 * amount / math_max(1, total)),
						mod.metadata.columns.Percent
					)

					if amount > max then
						max = amount
					end

					nr = nr + 1
				end
			end
		end

		win.metadata.maxvalue = max
	end

	function mod:GetEnemies(set)
		local enemies = {}
		for _, player in _ipairs(set.players) do
			if player.damagedone and player.damagedone.targets then
				for enemyname, enemy in _pairs(player.damagedone.targets) do
					if not enemies[enemyname] then
						enemies[enemyname] = CopyTable(enemy)
					else
						enemies[enemyname].amount = (enemies[enemyname].amount or 0) + (enemy.amount or 0)
						enemies[enemyname].absorbed = (enemies[enemyname].absorbed or 0) + (enemy.absorbed or 0)
						enemies[enemyname].blocked = (enemies[enemyname].blocked or 0) + (enemy.blocked or 0)
						enemies[enemyname].resisted = (enemies[enemyname].resisted or 0) + (enemy.resisted or 0)
					end
				end
			end
		end
		return enemies
	end

	function mod:Update(win, set)
		local enemies = self:GetEnemies(set)
		local nr, max = 1, 0

		for enemyname, enemy in _pairs(enemies) do
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.id = enemyname
			d.label = enemyname
			d.class = enemy.class or "MONSTER"

			d.value = enemy.amount
			d.valuetext = Skada:FormatValueText(
				Skada:FormatNumber(enemy.amount),
				mod.metadata.columns.Damage,
				_format("%02.1f%%", 100 * enemy.amount / math_max(1, set.damagedone.amount)),
				mod.metadata.columns.Percent
			)

			if enemy.amount > max then
				max = enemy.amount
			end

			nr = nr + 1
		end

		win.metadata.maxvalue = max
		win.title = L["Enemy damage taken"]
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = spellmod_tooltip}
		playermod.metadata = {click1 = spellmod}
		enemymod.metadata = {showspots = true, click1 = playermod}
		mod.metadata = {click1 = enemymod, columns = {Damage = true, Percent = true}}

		Skada:AddMode(self, L["Damage done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.damagedone.amount)
	end
end)

-- ========================= --
-- Enemy damage done module --
-- ========================= --

Skada:AddLoadableModule("Enemy damage done", function(Skada, L)
	if Skada:IsDisabled("Damage taken", "Enemy damage done") then return end

	local mod = Skada:NewModule(L["Enemy damage done"])
	local enemymod = mod:NewModule(L["Damage done per player"])
	local playermod = enemymod:NewModule(L["Damage spell list"])
	local spellmod = playermod:NewModule(L["Damage spell details"])

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == CRIT_ABBR or label == HIT or label == ABSORB or label == BLOCK or label == RESIST then
			local player = Skada:find_player(win:get_selected_set(), win.playerid, win.playername)
			if player and player.damagetaken and player.damagetaken.spells then
				local spell = player.damagetaken.spells[win.spellname]

				if spell then
					tooltip:AddLine(player.name .. " - " .. win.spellname)

					if win.mobname and spell.sources and spell.sources[win.mobname] then
						spell = spell.sources[win.mobname]
					end

					if spell.school then
						local c = Skada.schoolcolors[spell.school]
						local n = Skada.schoolnames[spell.school]
						if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
					end

					if label == CRIT_ABBR and spell.criticalamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
					end

					if label == HIT and spell.hitamount then
						tooltip:AddDoubleLine(L["Minimum hit:"], Skada:FormatNumber(spell.hitmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum hit:"], Skada:FormatNumber(spell.hitmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average hit:"], Skada:FormatNumber(spell.hitamount / spell.hit), 1, 1, 1)
					elseif label == ABSORB and spell.absorbed and spell.absorbed > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.absorbed), 1, 1, 1)
					elseif label == BLOCK and spell.blocked and spell.blocked > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.blocked), 1, 1, 1)
					elseif label == RESISTED and spell.resisted and spell.resisted > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.resisted), 1, 1, 1)
					end
				end
			end
		end
	end

	local function add_detail_bar(win, nr, title, value)
		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = title
		d.label = title
		d.value = value
		d.valuetext = Skada:FormatValueText(
			value,
			mod.metadata.columns.Damage,
			_format("%02.1f%%", value / win.metadata.maxvalue * 100),
			mod.metadata.columns.Percent
		)
	end

	function spellmod:Enter(win, id, label)
		win.spellname = label
		win.title = _format(L["%s's <%s> damage on %s"], label, win.spellname or "*", win.playername or UNKNOWN)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player and player.damagetaken and player.damagetaken.spells then
			local nr = 1

			for spellname, spell in _pairs(player.damagetaken.spells) do
				if spellname == win.spellname then
					if win.mobname and spell.sources and spell.sources[win.mobname] then
						spell = spell.sources[win.mobname]
					end

					win.metadata.maxvalue = spell.totalhits
					win.title = _format(L["%s's <%s> damage on %s"], win.mobname, spellname, player.name)

					if spell.hit and spell.hit > 0 then
						add_detail_bar(win, nr, HIT, spell.hit)
						nr = nr + 1
					end

					if spell.critical and spell.critical > 0 then
						add_detail_bar(win, nr, CRIT_ABBR, spell.critical)
						nr = nr + 1
					end

					if spell.glancing and spell.glancing > 0 then
						add_detail_bar(win, nr, L["Glancing"], spell.glancing)
						nr = nr + 1
					end

					if spell.crushing and spell.crushing > 0 then
						add_detail_bar(win, nr, L["Crushing"], spell.crushing)
						nr = nr + 1
					end

					for i, misstype in _ipairs(misstypes) do
						if spell[misstype] and spell[misstype] > 0 then
							local title = _G[misstype] or _G["ACTION_SPELL_MISSED" .. misstype] or misstype
							add_detail_bar(win, nr, title, spell[misstype])
							nr = nr + 1
						end
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's damage on %s"], win.mobname or UNKNOWN, label)
	end

	function playermod:Update(win, set)
		local max = 0
		if win.mobname then
			local player = Skada:find_player(set, win.playerid, win.playername)

			if player and player.damagetaken and player.damagetaken.sources and player.damagetaken.sources[win.mobname] then
				win.title = _format(L["%s's damage on %s"], win.mobname, player.name)

				local nr, total = 1, set.damagetaken.sources[win.mobname]

				for spellname, spell in _pairs(player.damagetaken.spells) do
					if spell.sources and spell.sources[win.mobname] then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spell.id
						d.spellid = spell.id
						d.label = spellname
						d.text = spellname .. (spell.isdot and L["DoT"] or "")
						d.icon = _select(3, _GetSpellInfo(spell.id))
						d.spellschool = spell.school

						local amount = spell.sources[win.mobname].amount
						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(amount),
							mod.metadata.columns.Damage,
							_format("%02.1f%%", 100 * amount / math_max(1, total)),
							mod.metadata.columns.Percent
						)

						if amount > max then
							max = amount
						end

						nr = nr + 1
					end
				end
			end
		end

		win.metadata.maxvalue = max
	end

	function enemymod:Enter(win, id, label)
		win.mobname = label
		win.title = _format(L["%s's damage"], label)
	end

	function enemymod:Update(win, set)
		local max = 0
		if win.mobname and set.damagetaken.sources[win.mobname] then
			win.title = _format(L["%s's damage"], win.mobname)

			local nr, total = 1, set.damagetaken.sources[win.mobname]
			for _, player in _ipairs(set.players) do
				if player.damagetaken and player.damagetaken.sources and player.damagetaken.sources[win.mobname] then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.class = player.class or "PET"
					d.role = player.role or "DAMAGER"
					d.spec = player.spec or 1

					d.value = player.damagetaken.sources[win.mobname].amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Damage,
						_format("%02.1f%%", 100 * d.value / math_max(1, total)),
						mod.metadata.columns.Percent
					)

					if d.value > max then
						max = d.value
					end

					nr = nr + 1
				end
			end
		end

		win.metadata.maxvalue = max
	end

	function mod:GetEnemies(set)
		local enemies = {}
		for _, player in _ipairs(set.players) do
			if player.damagetaken and player.damagetaken.sources then
				for enemyname, enemy in _pairs(player.damagetaken.sources) do
					if not enemies[enemyname] then
						enemies[enemyname] = CopyTable(enemy)
					else
						enemies[enemyname].amount = (enemies[enemyname].amount or 0) + (enemy.amount or 0)
						enemies[enemyname].absorbed = (enemies[enemyname].absorbed or 0) + (enemy.absorbed or 0)
						enemies[enemyname].blocked = (enemies[enemyname].blocked or 0) + (enemy.blocked or 0)
						enemies[enemyname].resisted = (enemies[enemyname].resisted or 0) + (enemy.resisted or 0)
					end
				end
			end
		end
		return enemies
	end

	function mod:Update(win, set)
		local enemies = self:GetEnemies(set)

		local nr, max = 1, 0
		for enemyname, enemy in _pairs(enemies) do
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.id = enemyname
			d.label = enemyname
			d.class = enemy.class or "MONSTER"

			d.value = enemy.amount
			d.valuetext = Skada:FormatValueText(
				Skada:FormatNumber(enemy.amount),
				mod.metadata.columns.Damage,
				_format("%02.1f%%", 100 * enemy.amount / math_max(1, set.damagetaken.amount)),
				mod.metadata.columns.Percent
			)

			if enemy.amount > max then
				max = enemy.amount
			end

			nr = nr + 1
		end

		win.metadata.maxvalue = max
		win.title = L["Enemy damage done"]
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = spellmod_tooltip}
		playermod.metadata = {click1 = spellmod}
		enemymod.metadata = {showspots = true, click1 = playermod}
		mod.metadata = {click1 = enemymod, columns = {Damage = true, Percent = true}}

		Skada:AddMode(self, L["Damage taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.damagetaken.amount)
	end
end)