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

	local function format_valuetext(d, columns, total, metadata)
		d.valuetext = Skada:FormatValueCols(
			columns.Count and d.value,
			columns.Percent and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_healthstone(set, playerid, playername, playerflags)
		local player = Skada:GetPlayer(set, playerid, playername, playerflags)
		if player then
			player.healthstone = (player.healthstone or 0) + 1
			set.healthstone = (set.healthstone or 0) + 1
		end
	end

	local function stone_used(_, _, srcGUID, srcName, srcFlags, _, _, _, spellid, spellname)
		if (spellid and stonespells[spellid]) or (spellname and spellname == stonename) then
			Skada:DispatchSets(log_healthstone, srcGUID, srcName, srcFlags)
		end
	end

	local function get_total_stones(set, class)
		if not set then return end

		local total = set.healthstone or 0
		if class and Skada.validclass[class] then
			total = 0
			for i = 1, #set.players do
				local p = set.players[i]
				if p and p.class == class and p.healthstone then
					total = total + p.healthstone
				end
			end
		end
		return total
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Healthstones"], L[win.class]) or L["Healthstones"]

		local total = get_total_stones(set, win.class)
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local cols = self.metadata.columns

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor.healthstone and (not win.class or win.class == actor.class) then
				nr = nr + 1
				local d = win:actor(nr, actor)

				d.value = actor.healthstone
				format_valuetext(d, cols, total, win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set, win)
		local stones = get_total_stones(set, win and win.class) or 0
		return tostring(stones), stones
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
end)
