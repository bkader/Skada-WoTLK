assert(Skada, "Skada not found!")

-- cache frequently used globals
local _pairs, _ipairs, _select = pairs, ipairs, select
local math_max, _format = math.max, string.format
local _GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo

-- list of miss types
local misstypes = {"DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT"}

-- ======================== --
-- Enemy damage taken module --
-- ======================== --

Skada:AddLoadableModule("Enemy Damage Taken", function(Skada, L)
	if Skada:IsDisabled("Damage", "Enemy Damage Taken") then return end

	local mod = Skada:NewModule(L["Enemy Damage Taken"])
	local enemymod = mod:NewModule(L["Damage taken per player"])
	local playermod = enemymod:NewModule(L["Damage spell list"])
	local spellmod = playermod:NewModule(L["Damage spell details"])

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Hits"] or label == L["Critical"] then
			local player = Skada:find_player(win:get_selected_set(), win.playerid, win.playername)
			if player and player.damagedone and player.damagedone.spells then
				local spell = player.damagedone.spells[win.spellname]

				if spell then
					tooltip:AddLine(player.name .. " - " .. win.spellname)

					if win.targetname and spell.sources and spell.sources[win.targetname] then
						spell = spell.sources[win.targetname]
					end

					if spell.school then
						local c = Skada.schoolcolors[spell.school]
						local n = Skada.schoolnames[spell.school]
						if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
					end

					if label == L["Hits"] and spell.hitamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.hitmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.hitmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.hitamount / spell.hit), 1, 1, 1)
					elseif label == L["Critical"] and spell.criticalamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
					end
				end
			end
		end
	end

	local function add_detail_bar(win, nr, title, value, total)
		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = title
		d.label = title
		d.value = value
		d.valuetext = Skada:FormatValueText(
			total and Skada:FormatNumber(value) or value,
			mod.metadata.columns.Damage,
			_format("%02.1f%%", 100 * value / math_max(1, total or win.metadata.maxvalue)),
			mod.metadata.columns.Percent
		)
		nr = nr + 1
		return nr
	end

	function spellmod:Enter(win, id, label)
		win.spellname = label
		win.title = _format(L["%s's <%s> damage on %s"], win.playername or UNKNOWN, label, win.targetname or UNKNOWN)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's <%s> damage on %s"], player.name, win.spellname or UNKNOWN, win.targetname or UNKNOWN)

			local spell
			for spellname, spelltable in _pairs(player.damagedone.spells or {}) do
				if spellname == win.spellname then
					spell = spelltable -- used as backup
					if win.targetname and spelltable.targets and spelltable.targets[win.targetname] then
						spell = spelltable.targets[win.targetname]
					end
					break
				end
			end

			if spell then
				win.metadata.maxvalue = spell.totalhits

				local total = (spell.amount or 0)
				local absorbed, blocked, resisted, overkill

				if (spell.absorbed or 0) > 0 then
					total = total + spell.absorbed
					absorbed = spell.absorbed
				end

				if (spell.blocked or 0) > 0 then
					total = total + spell.blocked
					blocked = spell.blocked
				end

				if (spell.resisted or 0) > 0 then
					total = total + spell.resisted
					resisted = spell.resisted
				end

				if (spell.overkill or 0) > 0 then
					total = total + spell.overkill
					overkill = spell.overkill
				end

				local nr = 1

				if absorbed then
					nr = add_detail_bar(win, nr, L["Absorbed"], absorbed, total)
				end

				if blocked then
					nr = add_detail_bar(win, nr, L["Blocked"], blocked, total)
				end

				if resisted then
					nr = add_detail_bar(win, nr, L["Resisted"], resisted, total)
				end

				if overkill then
					nr = add_detail_bar(win, nr, L["Overkill"], overkill, total)
				end

				nr = add_detail_bar(win, nr, L["Total Hits"], spell.totalhits or 0)

				if (spell.hit or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Hits"], spell.hit)
				end

				if (spell.critical or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Critical"], spell.critical)
				end

				if (spell.glancing or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Glancing"], spell.glancing)
				end

				if (spell.crushing or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Crushing"], spell.crushing)
				end

				for _, misstype in _ipairs(misstypes) do
					if (spell[misstype] or 0) > 0 then
						nr = add_detail_bar(win, nr, L[misstype], spell[misstype])
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's damage on %s"], label, win.targetname or UNKNOWN)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's damage on %s"], player.name, win.targetname or UNKNOWN)

			local total = 0
			if player.damagedone and player.damagedone.targets and player.damagedone.targets[win.targetname] then
				total = player.damagedone.targets[win.targetname].amount
			end

			if total > 0 and player.damagedone.spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in _pairs(player.damagedone.spells) do
					if spell.targets and spell.targets[win.targetname] then
						local amount = spell.targets[win.targetname].amount

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
							_format("%02.1f%%", 100 * amount / total),
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

	function enemymod:Enter(win, id, label)
		win.targetname = label
		win.title = _format(L["Damage on %s"], label)
	end

	function enemymod:Update(win, set)
		win.title = _format(L["Damage on %s"], win.targetname or UNKNOWN)
		local total = 0
		if win.targetname and set.damagedone and set.damagedone.targets and set.damagedone.targets[win.targetname] then
			total = set.damagedone.targets[win.targetname]
		end

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.damagedone and player.damagedone.targets and player.damagedone.targets[win.targetname] then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.class = player.class or "PET"
					d.role = player.role or "DAMAGER"
					d.spec = player.spec or 1

					d.value = player.damagedone.targets[win.targetname].amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Damage,
						_format("%02.1f%%", 100 * d.value / total),
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

	function mod:GetEnemies(set)
		local enemies = {}
		for _, player in Skada:IteratePlayers(set) do
			if player.damagedone and player.damagedone.targets then
				for enemyname, enemy in _pairs(player.damagedone.targets) do
					if not enemies[enemyname] then
						enemies[enemyname] = {
							id = enemy.id,
							class = enemy.class,
							amount = enemy.amount,
							absorbed = enemy.absorbed,
							blocked = enemy.blocked,
							resisted = enemy.resisted
						}
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
		win.title = L["Enemy Damage Taken"]
		local total = set.damagedone and set.damagedone.amount or 0

		if total > 0 then
			local enemies = self:GetEnemies(set)
			local maxvalue, nr = 0, 1

			for enemyname, enemy in _pairs(enemies) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = enemyname
				d.label = enemyname
				d.class = enemy.class or "ENEMY"

				d.value = enemy.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(enemy.amount),
					mod.metadata.columns.Damage,
					_format("%02.1f%%", 100 * enemy.amount / total),
					mod.metadata.columns.Percent
				)

				if enemy.amount > maxvalue then
					maxvalue = enemy.amount
				end

				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = spellmod_tooltip}
		playermod.metadata = {click1 = spellmod}
		enemymod.metadata = {showspots = true, click1 = playermod}
		self.metadata = {
			click1 = enemymod,
			columns = {Damage = true, Percent = true},
			icon = "Interface\\Icons\\spell_fire_felflamebolt"
		}

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.damagedone and set.damagedone.amount or 0)
	end
end)

-- ========================= --
-- Enemy damage done module --
-- ========================= --

Skada:AddLoadableModule("Enemy Damage Done", function(Skada, L)
	if Skada:IsDisabled("Damage Taken", "Enemy Damage Done") then return end

	local mod = Skada:NewModule(L["Enemy Damage Done"])
	local enemymod = mod:NewModule(L["Damage done per player"])
	local playermod = enemymod:NewModule(L["Damage spell list"])
	local spellmod = playermod:NewModule(L["Damage spell details"])

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Hits"] or label == L["Critical"] then
			local player = Skada:find_player(win:get_selected_set(), win.playerid, win.playername)
			if player and player.damagetaken and player.damagetaken.spells then
				local spell = player.damagetaken.spells[win.spellname]

				if spell then
					tooltip:AddLine(player.name .. " - " .. win.spellname)

					if win.targetname and spell.sources and spell.sources[win.targetname] then
						spell = spell.sources[win.targetname]
					end

					if spell.school then
						local c = Skada.schoolcolors[spell.school]
						local n = Skada.schoolnames[spell.school]
						if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
					end

					if label == L["Critical"] and spell.criticalamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
					end

					if label == L["Hits"] and spell.hitamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.hitmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.hitmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.hitamount / spell.hit), 1, 1, 1)
					elseif label == L["Critical"] and spell.criticalamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
					end
				end
			end
		end
	end

	local function add_detail_bar(win, nr, title, value, total)
		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = title
		d.label = title
		d.value = value
		d.valuetext = Skada:FormatValueText(
			total and Skada:FormatNumber(value) or value,
			mod.metadata.columns.Damage,
			_format("%02.1f%%", 100 * value / math_max(1, total or win.metadata.maxvalue)),
			mod.metadata.columns.Percent
		)
		nr = nr + 1
		return nr
	end

	function spellmod:Enter(win, id, label)
		win.spellname = label
		win.title = _format(L["%s's <%s> damage on %s"], label, win.spellname or "*", win.playername or UNKNOWN)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's <%s> damage on %s"], win.targetname or UNKNOWN, win.spellname or UNKNOWN, player.name)

			local spell
			for spellname, spelltable in _pairs(player.damagetaken.spells or {}) do
				if spellname == win.spellname then
					spell = spelltable -- used as backup
					if win.targetname and spelltable.sources and spelltable.sources[win.targetname] then
						spell = spelltable.sources[win.targetname]
					end
					break
				end
			end

			if spell then
				win.metadata.maxvalue = spell.totalhits

				local total = (spell.amount or 0)
				local absorbed, blocked, resisted, overkill

				if (spell.absorbed or 0) > 0 then
					total = total + spell.absorbed
					absorbed = spell.absorbed
				end

				if (spell.blocked or 0) > 0 then
					total = total + spell.blocked
					blocked = spell.blocked
				end

				if (spell.resisted or 0) > 0 then
					total = total + spell.resisted
					resisted = spell.resisted
				end

				if (spell.overkill or 0) > 0 then
					total = total + spell.overkill
					overkill = spell.overkill
				end

				local nr = 1

				if absorbed then
					nr = add_detail_bar(win, nr, L["Absorbed"], absorbed, total)
				end

				if blocked then
					nr = add_detail_bar(win, nr, L["Blocked"], blocked, total)
				end

				if resisted then
					nr = add_detail_bar(win, nr, L["Resisted"], resisted, total)
				end

				if overkill then
					nr = add_detail_bar(win, nr, L["Overkill"], overkill, total)
				end

				nr = add_detail_bar(win, nr, L["Total Hits"], spell.totalhits or 0)

				if (spell.hit or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Hits"], spell.hit)
				end

				if (spell.critical or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Critical"], spell.critical)
				end

				if (spell.glancing or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Glancing"], spell.glancing)
				end

				if (spell.crushing or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Crushing"], spell.crushing)
				end

				for _, misstype in _ipairs(misstypes) do
					if (spell[misstype] or 0) > 0 then
						nr = add_detail_bar(win, nr, L[misstype], spell[misstype])
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's damage on %s"], win.targetname or UNKNOWN, label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's damage on %s"], win.targetname or UNKNOWN, player.name)

			local total = 0
			if player.damagetaken and player.damagetaken.sources and player.damagetaken.sources[win.targetname] then
				total = player.damagetaken.sources[win.targetname].amount or 0
			end

			if total > 0 and player.damagetaken.spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in _pairs(player.damagetaken.spells) do
					if spell.sources and spell.sources[win.targetname] then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spell.id
						d.spellid = spell.id
						d.label = spellname
						d.text = spellname .. (spell.isdot and L["DoT"] or "")
						d.icon = _select(3, _GetSpellInfo(spell.id))
						d.spellschool = spell.school

						local amount = spell.sources[win.targetname].amount
						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(amount),
							mod.metadata.columns.Damage,
							_format("%02.1f%%", 100 * amount / total),
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

	function enemymod:Enter(win, id, label)
		win.targetname = label
		win.title = _format(L["%s's damage"], label)
	end

	function enemymod:Update(win, set)
		if win.targetname then
			win.title = _format(L["%s's damage"], win.targetname)

			local total = (set.damagetaken and set.damagetaken.sources) and set.damagetaken.sources[win.targetname] or 0
			if total > 0 then
				local maxvalue, nr = 0, 1

				for _, player in Skada:IteratePlayers(set) do
					if player.damagetaken and player.damagetaken.sources and player.damagetaken.sources[win.targetname] then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id
						d.label = player.name
						d.class = player.class or "PET"
						d.role = player.role or "DAMAGER"
						d.spec = player.spec or 1

						d.value = player.damagetaken.sources[win.targetname].amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							_format("%02.1f%%", 100 * d.value / total),
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

	function mod:GetEnemies(set)
		local enemies = {}
		for _, player in Skada:IteratePlayers(set) do
			if player.damagetaken and player.damagetaken.sources then
				for enemyname, enemy in _pairs(player.damagetaken.sources) do
					if not enemies[enemyname] then
						enemies[enemyname] = CopyTable(enemy)
						enemies[enemyname] = {
							id = enemy.id,
							class = enemy.class,
							amount = enemy.amount,
							absorbed = enemy.absorbed,
							blocked = enemy.blocked,
							resisted = enemy.resisted
						}
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
		win.title = L["Enemy Damage Done"]
		local total = set.damagetaken and set.damagetaken.amount or 0

		if total > 0 then
			local enemies = self:GetEnemies(set)
			local maxvalue, nr = 0, 1

			for enemyname, enemy in _pairs(enemies) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = enemy.id or enemyname
				d.label = enemyname
				d.class = enemy.class or "ENEMY"

				d.value = enemy.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(enemy.amount),
					mod.metadata.columns.Damage,
					_format("%02.1f%%", 100 * enemy.amount / total),
					mod.metadata.columns.Percent
				)

				if enemy.amount > maxvalue then
					maxvalue = enemy.amount
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = spellmod_tooltip}
		playermod.metadata = {click1 = spellmod}
		enemymod.metadata = {showspots = true, click1 = playermod}
		self.metadata = {
			click1 = enemymod,
			columns = {Damage = true, Percent = true},
			icon = "Interface\\Icons\\spell_shadow_shadowbolt"
		}

		Skada:AddMode(self, L["Damage Taken"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.damagetaken and set.damagetaken.amount or 0)
	end
end)