local Skada = Skada
Skada:RegisterModule("My Spells", function(L, P)
	local mod = Skada:NewModule("My Spells")

	local pairs, format = pairs, string.format
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local spellschools = Skada.spellschools
	local _

	local function spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local player = set and set:GetPlayer(Skada.userGUID, Skada.userName)
		if not player then return end

		local spell, damage = nil, nil
		if player.damagespells and player.damagespells[label] then
			spell, damage = player.damagespells[label], true
		elseif player.absorbspells and player.absorbspells[id] then
			spell = player.absorbspells[id]
		elseif player.healspells and player.healspells[id] then
			spell = player.healspells[id]
		end

		if spell then
			tooltip:AddLine(player.name .. " - " .. label)
			if spell.school and spellschools[spell.school] then
				tooltip:AddLine(spellschools(spell.school))
			end

			-- count stats
			tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)

			if spell.n_num and spell.n_num > 0 then
				tooltip:AddDoubleLine(L["Normal Hits"], format("%s (%s)", spell.n_num, Skada:FormatPercent(spell.n_num, spell.count)), 1, 1, 1)
			end

			if spell.c_num and spell.c_num > 0 then
				tooltip:AddDoubleLine(L["Critical Hits"], format("%s (%s)", spell.c_num, Skada:FormatPercent(spell.c_num, spell.count)), 1, 1, 1)
			end

			tooltip:AddLine(" ")

			if spell.n_min or spell.min then
				local spellmin = spell.n_min or spell.min
				if spell.c_min and spell.c_min < spellmin then
					spellmin = spell.c_min
				end
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
			end

			if spell.n_max or spell.max then
				local spellmax = spell.n_max or spell.max
				if spell.c_max and spell.c_max < spellmax then
					spellmax = spell.c_max
				end
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spellmax), 1, 1, 1)
			end

			local amount = damage and (P.absdamage and spell.total or spell.amount) or spell.amount
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(amount / spell.count), 1, 1, 1)
		end
	end

	function mod:Update(win, set)
		win.title = L["My Spells"]

		local player = set and set:GetPlayer(Skada.userGUID, Skada.userName)

		if not player then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		-- damage spells
		if player.damagespells then
			for spellname, spell in pairs(player.damagespells) do
				nr = nr + 1
				local d = win:spell(nr, spellname, spell)

				d.value = P.absdamage and spell.total or spell.amount
				d.valuetext = Skada:FormatNumber(d.value)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end

		-- heal spells
		if player.healspells then
			for spellid, spell in pairs(player.healspells) do
				nr = nr + 1
				local d = win:spell(nr, spellid, spell)

				d.value = spell.amount
				d.valuetext = Skada:FormatNumber(d.value)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end

		-- absorb spells
		if player.absorbspells then
			for spellid, spell in pairs(player.absorbspells) do
				nr = nr + 1
				local d = win:spell(nr, spellid, spell)

				d.value = spell.amount
				d.valuetext = Skada:FormatNumber(d.value)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:OnEnable()
		self.metadata = {showspots = true, tooltip = spell_tooltip, icon = [[Interface\Icons\spell_nature_lightning]]}
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)
