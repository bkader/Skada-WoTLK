assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Player Score", function(Skada, L)
	-- Because we adopted the method of not storing everything
	-- and rather use what's available, this module won't be storing
	-- any unnecessary data but grab it from other modules.
	if Skada:IsDisabled("Damage", "Damage Taken", "Absorbs", "Healing", "Player Score") then
		return
	end

	local mod = Skada:NewModule(L["Player Score"])
	local format = string.format

	local mindamagetaken = 75000
	local multipliers = {
		damage = {NONE = 1.0, TANK = 1.5, HEALER = 1.0, DAMAGER = 2.0},
		healing = {NONE = 1.0, TANK = 1.5, HEALER = 2.0, DAMAGER = 1.0},
		mitigation = {NONE = 1.0, TANK = 2.0, HEALER = 1.0, DAMAGER = 1.0}
	}

	local function GetPlayerMitigation(player)
		local mitigation = 0

		if player.damagetaken_spells then
			for _, spell in pairs(player.damagetaken_spells) do
				mitigation = mitigation + (spell.blocked or 0) + (spell.absorbed or 0) + (spell.resisted or 0)
			end
		end

		return mitigation
	end

	local function CalculateScore(damage, healing, mitigation, damagetaken, role)
		local score = 0
		score = score + damage * (multipliers.damage[role] or 1)
		score = score + healing * (multipliers.healing[role] or 1)
		score = score + mitigation * (multipliers.mitigation[role] or 1)
		return score / damagetaken
	end

	local function GetSetScore(set)
		local raidscore = 0
		if set and set.players then
			local count = 0
			for _, player in Skada:IteratePlayers(set) do
				local damage = player.damage or 0
				local healing = (player.heal or 0) + (player.absorb or 0)
				local mitigation = GetPlayerMitigation(player)
				local damagetaken = player.damagetaken or 0

				local role = player.role
				if not role then
					role = "NONE"
				elseif role == "TANK" then
					damagetaken = damagetaken - mitigation
				end

				local score
				if damagetaken < mindamagetaken then
					score = 0
					if role ~= "NONE" then
						damagetaken = mindamagetaken
					end
				end

				if damagetaken >= mindamagetaken then
					score = CalculateScore(damage, healing, mitigation, damagetaken, player.role)
				end
				raidscore = raidscore + score
				count = count + 1
			end

			if count > 0 then
				raidscore = raidscore / count
			end
		end
		return raidscore
	end

	local function score_tooltip(win, id, label, tooltip)
		local player = Skada:find_player(win:get_selected_set(), id)
		if not player then
			return
		end

		tooltip:AddLine(format(L["%s's Score"], player.name))

		local damagedone = player.damage or 0
		tooltip:AddDoubleLine(L["Damage"], Skada:FormatNumber(damagedone), 1, 1, 1, 1, 1, 1)

		local healing = (player.heal or 0) + (player.absorb or 0)
		tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(healing), 1, 1, 1, 0, 1, 0)

		local damagetaken = player.damagetaken or 0
		tooltip:AddDoubleLine(L["Damage Taken"], Skada:FormatNumber(damagetaken), 1, 1, 1, 1, 0, 0)

		local mitigation = GetPlayerMitigation(player)
		tooltip:AddDoubleLine(L["Damage Mitigated"], Skada:FormatNumber(mitigation), 1, 1, 1, 1, 1, 0)

		local role = player.role
		if not role then
			role = "NONE"
		elseif role == "TANK" then
			damagetaken = damagetaken - mitigation
		end

		local score
		if damagetaken < mindamagetaken then
			score = 0
			if role ~= "NONE" then
				damagetaken = mindamagetaken
			end
		end

		if damagetaken >= mindamagetaken then
			score = CalculateScore(damagedone, healing, mitigation, damagetaken, player.role)
		end
		tooltip:AddDoubleLine(L["Score"], format("%.1f", score), 1, 1, 1)
	end

	function mod:Update(win, set)
		local maxvalue, nr = 0, 1

		for _, player in Skada:IteratePlayers(set) do
			local damagedone = player.damage or 0
			local healing = (player.heal or 0) + (player.absorb or 0)
			local mitigation = GetPlayerMitigation(player)
			local damagetaken = player.damagetaken or 0

			local role = player.role
			if not role then
				role = "NONE"
			elseif role == "TANK" then
				damagetaken = damagetaken - mitigation
			end

			local score
			if damagetaken < mindamagetaken then
				score = 0
				if role ~= "NONE" then
					damagetaken = mindamagetaken
				end
			end

			if damagetaken >= mindamagetaken then
				score = CalculateScore(damagedone, healing, mitigation, damagetaken, player.role)
			end

			local d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.id = player.id
			d.label = Skada:FormatName(player.name, player.id)
			d.class = player.class or "PET"
			d.role = (role == "NONE") and "UNKNOWN" or role
			d.spec = player.spec or 1

			d.value = score
			d.valuetext = format("%.1f", score)

			if score > maxvalue then
				maxvalue = score
			end

			nr = nr + 1
		end

		win.metadata.maxvalue = maxvalue
		win.title = L["Player Score"]
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			tooltip = score_tooltip,
			icon = "Interface\\Icons\\spell_misc_emotionangry"
		}
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local score = set and GetSetScore(set) or 0
		return format("%.1f", score)
	end
end)