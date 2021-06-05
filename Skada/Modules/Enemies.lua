assert(Skada, "Skada not found!")

-- cache frequently used globals
local _pairs, _select, _format, math_max = pairs, select, string.format, math.max
local _GetSpellInfo, _UnitClass = Skada.GetSpellInfo or GetSpellInfo, Skada.UnitClass

-- list of miss types
local misstypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}

-- ======================== --
-- Enemy Damage Taken module --
-- ======================== --

Skada:AddLoadableModule("Enemy Damage Taken", function(Skada, L)
	if Skada:IsDisabled("Damage", "Enemy Damage Taken") then return end

	local mod = Skada:NewModule(L["Enemy Damage Taken"])
	local enemymod = mod:NewModule(L["Damage taken per player"])
	local playermod = enemymod:NewModule(L["Damage spell list"])
	local detailmod = enemymod:NewModule(L["Damage Breakdown"])

	local function add_detail_bar(win, nr, title, value)
		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = title
		d.label = title
		d.value = value
		d.valuetext = Skada:FormatValueText(
			Skada:FormatNumber(value),
			mod.metadata.columns.Damage,
			_format("%.1f%%", 100 * value / math_max(1, win.metadata.maxvalue)),
			mod.metadata.columns.Percent
		)

		nr = nr + 1
		return nr
	end

	function detailmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's damage on %s"], label, win.targetname or UNKNOWN)
	end

	function detailmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's damage on %s"], player.name, win.targetname or UNKNOWN)

			local total, amount, target = 0, 0
			if player.damagedone and player.damagedone.targets and player.damagedone.targets[win.targetname] then
				target = player.damagedone.targets[win.targetname]
				amount = target.amount or 0
				total = amount + (target.overkill or 0)
			end

			if total > 0 and target then
				win.metadata.maxvalue = total

				local nr = add_detail_bar(win, 1, L["Total"], total)
				nr = add_detail_bar(win, nr, L["Damage Done"], amount)

				if (target.useful or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Useful Damage"], target.useful)
				end

				if (target.overkill or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Overkill"], target.overkill)
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
			win.title = _format(L["%s's damage on %s"], player.name, win.targetname)

			local total = 0
			if player.damagedone and player.damagedone.targets and win.targetname then
				total = player.damagedone.targets[win.targetname].amount or 0
			end

			if total > 0 and player.damagedone.spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in _pairs(player.damagedone.spells) do
					if spell.targets and spell.targets[win.targetname] and (spell.targets[win.targetname].amount or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						if spell.isdot then
							d.text = spellname .. L["DoT"]
						end
						d.icon = _select(3, _GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = spell.targets[win.targetname].amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							_format("%.1f%%", 100 * d.value / total),
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

	function enemymod:Enter(win, id, label)
		win.targetname = label
		win.title = _format(L["Damage on %s"], label)
	end

	function enemymod:Update(win, set)
		win.title = _format(L["Damage on %s"], win.targetname or UNKNOWN)
		local total = set.damagedone or 0

		if total > 0 and win.targetname then
			local maxvalue, nr = 0, 1
			for _, player in Skada:IteratePlayers(set) do
				if player.damagedone and player.damagedone.targets and player.damagedone.targets[win.targetname] then
					if (player.damagedone.targets[win.targetname].amount or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id
						d.label = Skada:FormatName(player.name, player.id)
						d.class = player.class or "PET"
						d.role = player.role
						d.spec = player.spec

						d.value = player.damagedone.targets[win.targetname].amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							_format("%.1f%%", 100 * d.value / total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:GetEnemies(set)
		local enemies = {}
		for _, player in Skada:IteratePlayers(set) do
			if player.damagedone and player.damagedone.targets then
				for name, tbl in _pairs(player.damagedone.targets) do
					if not enemies[name] then
						enemies[name] = {id = tbl.id, flags = tbl.flags, amount = tbl.amount}
					else
						enemies[name].amount = (enemies[name].amount or 0) + tbl.amount
					end
				end
			end
		end
		return enemies
	end

	function mod:Update(win, set)
		win.title = L["Enemy Damage Taken"]
		local total = set.damagedone or 0

		if total > 0 then
			local enemies = self:GetEnemies(set)
			local maxvalue, nr = 0, 1

			for enemyname, enemy in _pairs(enemies) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = enemy.id or enemyname
				d.label = enemyname
				d.class, d.role, d.spec = _select(2, _UnitClass(d.id, enemy.flags, set))

				d.value = enemy.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(enemy.amount),
					mod.metadata.columns.Damage,
					_format("%.1f%%", 100 * enemy.amount / total),
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
		enemymod.metadata = {showspots = true, click1 = playermod, click2 = detailmod}
		self.metadata = {
			click1 = enemymod,
			columns = {Damage = true, Percent = true},
			icon = "Interface\\Icons\\spell_fire_felflamebolt"
		}

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.damagetaken)
	end
end)

-- ========================= --
-- Enemy Damage Done module --
-- ========================= --

Skada:AddLoadableModule("Enemy Damage Done", function(Skada, L)
	if Skada:IsDisabled("Damage Taken", "Enemy Damage Done") then return end

	local mod = Skada:NewModule(L["Enemy Damage Done"])
	local enemymod = mod:NewModule(L["Damage done per player"])
	local playermod = enemymod:NewModule(L["Damage spell list"])

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's damage on %s"], win.targetname or UNKNOWN, label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's damage on %s"], win.targetname or UNKNOWN, player.name)

			local total = 0
			if player.damagetaken and player.damagetaken.sources and win.targetname then
				total = player.damagetaken.sources[win.targetname].amount or 0
			end

			if total > 0 and player.damagetaken.spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in _pairs(player.damagetaken.spells) do
					if spell.sources and spell.sources[win.targetname] and (spell.sources[win.targetname].amount or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						if spell.isdot then
							d.text = spellname .. L["DoT"]
						end
						d.icon = _select(3, _GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = spell.sources[win.targetname].amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							_format("%.1f%%", 100 * d.value / total),
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

	function enemymod:Enter(win, id, label)
		win.targetname = label
		win.title = _format(L["Damage from %s"], label)
	end

	function enemymod:Update(win, set)
		win.title = _format(L["Damage from %s"], win.targetname or UNKNOWN)
		local total = set.damagetaken or 0

		if total > 0 and win.targetname then
			local maxvalue, nr = 0, 1
			for _, player in Skada:IteratePlayers(set) do
				if player.damagetaken and player.damagetaken.sources and player.damagetaken.sources[win.targetname] then
					if (player.damagetaken.sources[win.targetname].amount or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id
						d.label = Skada:FormatName(player.name, player.id)
						d.class = player.class or "PET"
						d.role = player.role
						d.spec = player.spec

						d.value = player.damagetaken.sources[win.targetname].amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							_format("%.1f%%", 100 * d.value / total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:GetEnemies(set)
		local enemies = {}
		for _, player in Skada:IteratePlayers(set) do
			if player.damagetaken and player.damagetaken.sources then
				for name, tbl in _pairs(player.damagetaken.sources) do
					if not enemies[name] then
						enemies[name] = {id = tbl.id, flags = tbl.flags, amount = tbl.amount}
					else
						enemies[name].amount = (enemies[name].amount or 0) + tbl.amount
					end
				end
			end
		end
		return enemies
	end

	function mod:Update(win, set)
		win.title = L["Enemy Damage Done"]
		local total = set.damagetaken or 0

		if total > 0 then
			local enemies = self:GetEnemies(set)
			local maxvalue, nr = 0, 1

			for enemyname, enemy in _pairs(enemies) do
				if (enemy.amount or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = enemy.id or enemyname
					d.label = enemyname
					d.class, d.role, d.spec = _select(2, _UnitClass(d.id, enemy.flags, set))

					d.value = enemy.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(enemy.amount),
						mod.metadata.columns.Damage,
						_format("%.1f%%", 100 * enemy.amount / total),
						mod.metadata.columns.Percent
					)

					if enemy.amount > maxvalue then
						maxvalue = enemy.amount
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		enemymod.metadata = {showspots = true, click1 = playermod}
		self.metadata = {
			click1 = enemymod,
			columns = {Damage = true, Percent = true},
			icon = "Interface\\Icons\\spell_shadow_shadowbolt"
		}

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.damagetaken)
	end
end)