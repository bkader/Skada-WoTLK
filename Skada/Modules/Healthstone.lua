local Skada = Skada
Skada:RegisterModule("Healthstones", function(L)
	local mod = Skada:NewModule("Healthstones")
	local stonename = GetSpellInfo(47874)
	local stonespells = {
		[27235] = true, -- Master Healthstone (2080)
		[27236] = true, -- Master Healthstone (2288)
		[27237] = true, -- Master Healthstone (2496)
		[47872] = true, -- Demonic Healthstone (4200)
		[47873] = true, -- Demonic Healthstone (3850)
		[47874] = true, -- Demonic Healthstone (3500)
		[47875] = true, -- Fel Healthstone (4280)
		[47876] = true, -- Fel Healthstone (4708)
		[47877] = true -- Fel Healthstone (5136)
	}

	local format, tostring = string.format, tostring

	local function log_healthstone(set, playerid, playername, playerflags)
		local player = Skada:GetPlayer(set, playerid, playername, playerflags)
		if player then
			player.healthstone = (player.healthstone or 0) + 1
			set.healthstone = (set.healthstone or 0) + 1
		end
	end

	local function stone_used(_, eventtype, srcGUID, srcName, srcFlags, _, _, _, spellid, spellname)
		if (spellid and stonespells[spellid]) or (spellname and spellname == stonename) then
			Skada:DispatchSets(log_healthstone, srcGUID, srcName, srcFlags)
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Healthstones"], L[win.class]) or L["Healthstones"]

		local total = set.healthstone or 0

		if total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for i = 1, #set.players do
			local player = set.players[i]
			if player and player.healthstone and (not win.class or win.class == player.class) then
				nr = nr + 1
				local d = win:actor(nr, player)

				d.value = player.healthstone
				d.valuetext = Skada:FormatValueCols(
					self.metadata.columns.Count and d.value,
					self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:OnEnable()
		stonename = stonename or GetSpellInfo(47874)
		self.metadata = {
			showspots = true,
			ordersort = true,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Count = true, Percent = true},
			icon = [[Interface\Icons\inv_stone_04]]
		}
		Skada:RegisterForCL(stone_used, "SPELL_CAST_SUCCESS", {src_is_interesting = true})
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local stones = set.healthstone or 0
		return tostring(stones), stones
	end
end)
