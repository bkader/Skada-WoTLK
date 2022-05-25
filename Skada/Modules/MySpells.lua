local Skada = Skada
Skada:AddLoadableModule("My Spells", function(L)
	if Skada:IsDisabled("My Spells") then return end

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

			if spell.hit and spell.hit > 0 then
				tooltip:AddDoubleLine(L["Normal Hits"], format("%s (%s)", spell.hit, Skada:FormatPercent(spell.hit, spell.count)), 1, 1, 1)
			end

			if spell.critical and spell.critical > 0 then
				tooltip:AddDoubleLine(L["Critical Hits"], format("%s (%s)", spell.critical, Skada:FormatPercent(spell.critical, spell.count)), 1, 1, 1)
			end

			tooltip:AddLine(" ")

			if spell.hitmin or spell.min then
				local spellmin = spell.hitmin or spell.min
				if spell.criticalmin and spell.criticalmin < spellmin then
					spellmin = spell.criticalmin
				end
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spellmin), 1, 1, 1)
			end

			if spell.hitmax or spell.max then
				local spellmax = spell.hitmax or spell.max
				if spell.criticalmax and spell.criticalmax < spellmax then
					spellmax = spell.criticalmax
				end
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spellmax), 1, 1, 1)
			end

			local amount = damage and (Skada.db.profile.absdamage and spell.total or spell.amount) or spell.amount
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(amount / spell.count), 1, 1, 1)
		end
	end

	function mod:Update(win, set)
		win.title = L["My Spells"]

		local player = set and set:GetPlayer(Skada.userGUID, Skada.userName)
		if player then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- damage spells
			if player.damagespells then
				for spellname, spell in pairs(player.damagespells) do
					nr = nr + 1
					local d = win:nr(nr)

					d.id = spellname
					d.spellid = spell.id
					d.label = spellname
					_, _, d.icon = GetSpellInfo(spell.id)
					d.spellschool = spell.school

					d.value = Skada.db.profile.absdamage and spell.total or spell.amount
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
					local d = win:nr(nr)

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)
					if spell.ishot then
						d.text = d.label .. L["HoT"]
					end

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
					local d = win:nr(nr)

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)

					d.value = spell.amount
					d.valuetext = Skada:FormatNumber(d.value)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
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