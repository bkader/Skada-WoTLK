local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("My Spells", function(L, P)
	local mode = Skada:NewModule("My Spells")

	local pairs, format = pairs, string.format
	local userGUID, userName = Skada.userGUID, Skada.userName
	local tooltip_school = Skada.tooltip_school
	local PercentToRGB = Private.PercentToRGB
	local hits_perc = "%s (\124cffffffff%s\124r)"

	local function format_valuetext(d, metadata)
		d.valuetext = Skada:FormatNumber(d.value)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function spell_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(userName, userGUID)
		if not actor then return end

		local spell, damage = nil, nil
		if actor.damagespells and actor.damagespells[id] then
			spell, damage = actor.damagespells[id], true
		elseif actor.absorbspells and actor.absorbspells[id] then
			spell = actor.absorbspells[id]
		elseif actor.healspells and actor.healspells[id] then
			spell = actor.healspells[id]
		end

		if not spell then return end

		tooltip:AddLine(format("%s - %s", userName, label))
		tooltip_school(tooltip, id)

		local cast = actor.GetSpellCast and actor:GetSpellCast(id)
		if cast then
			tooltip:AddDoubleLine(L["Casts"], cast, nil, nil, nil, 1, 1, 1)
		end

		if not spell.count or spell.count == 0 then return end

		-- count stats
		tooltip:AddDoubleLine(L["Hits"], spell.count, 1, 1, 1)
		local amount = damage and P.absdamage and spell.total or spell.amount
		tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(amount / spell.count), 1, 1, 1)

		local uptime = actor.auras and actor.auras[id] and actor.auras[id].uptime
		if uptime and uptime > 0 then
			uptime = 100 * (uptime / actor:GetTime(set))
			tooltip:AddDoubleLine(L["Uptime"], Skada:FormatPercent(uptime), 1, 1, 1, PercentToRGB(uptime))
		end

		-- overheal/overkill
		if spell.o_amt and spell.o_amt > 0 then
			local overamount = format(hits_perc, Skada:FormatNumber(spell.o_amt), Skada:FormatPercent(spell.o_amt, spell.amount + spell.o_amt))
			tooltip:AddDoubleLine(damage and L["Overkill"] or L["Overheal"], overamount, 1, 0.67, 0.67)
		end

		-- normal hits
		if spell.n_num then
			tooltip:AddLine(" ")
			tooltip:AddDoubleLine(L["Normal Hits"], format(hits_perc, Skada:FormatNumber(spell.n_num), Skada:FormatPercent(spell.n_num, spell.count)))
			if spell.n_min then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.n_min), 1, 1, 1)
			end
			if spell.n_max then
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.n_max), 1, 1, 1)
			end
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.n_amt / spell.n_num), 1, 1, 1)
		end

		-- critical hits
		if spell.c_num then
			tooltip:AddLine(" ")
			tooltip:AddDoubleLine(L["Critical Hits"], format(hits_perc, Skada:FormatNumber(spell.c_num), Skada:FormatPercent(spell.c_num, spell.count)))
			if spell.c_min then
				tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.c_min), 1, 1, 1)
			end
			if spell.c_max then
				tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.c_max), 1, 1, 1)
			end
			tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.c_amt / spell.c_num), 1, 1, 1)
		end
	end

	function mode:Update(win, set)
		win.title = L["My Spells"]

		local player = set and set:GetActor(userName, userGUID)
		if not player then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local spells = player.damagespells -- damage spells
		if spells then
			for spellid, spell in pairs(spells) do
				nr = nr + 1

				local d = win:spell(nr, spellid)
				d.value = P.absdamage and spell.total or spell.amount
				format_valuetext(d, win.metadata)
			end
		end

		spells = player.healspells -- heal spells
		if spells then
			for spellid, spell in pairs(spells) do
				nr = nr + 1

				local d = win:spell(nr, spellid, true)
				d.value = spell.amount
				format_valuetext(d, win.metadata)
			end
		end

		spells = player.absorbspells -- absorb spells
		if spells then
			for spellid, spell in pairs(spells) do
				nr = nr + 1

				local d = win:spell(nr, spellid)
				d.value = spell.amount
				format_valuetext(d, win.metadata)
			end
		end
	end

	function mode:OnEnable()
		self.metadata = {
			showspots = true,
			tooltip = spell_tooltip,
			icon = [[Interface\ICONS\spell_nature_lightning]]
		}

		userGUID = userGUID or Skada.userGUID
		userName = userName or Skada.userName

		Skada:AddMode(self)
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end)
