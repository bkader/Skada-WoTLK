local _, Skada = ...
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

	local format = string.format
	local mod_cols = nil

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

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Healthstones"], L[win.class]) or L["Healthstones"]

		local total = set and set:GetTotal(win.class, nil, "healthstone")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor.healthstone and (not win.class or win.class == actor.class) then
				nr = nr + 1
				local d = win:actor(nr, actor)

				d.value = actor.healthstone
				format_valuetext(d, mod_cols, total, win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set, win)
		if not set then return end
		return set:GetTotal(win and win.class, nil, "healthstone") or 0
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

		mod_cols = self.metadata.columns

		Skada:RegisterForCL(stone_used, "SPELL_CAST_SUCCESS", {src_is_interesting_nopets = true})
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)
