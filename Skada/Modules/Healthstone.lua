local _, Skada = ...
Skada:RegisterModule("Healthstones", function(L)
	local mode = Skada:NewModule("Healthstones")
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
	local mode_cols = nil

	local function format_valuetext(d, total, metadata)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Count and d.value,
			mode_cols.Percent and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_healthstone(set, actorname, actorid, actorflags)
		local actor = Skada:GetActor(set, actorname, actorid, actorflags)
		if actor then
			actor.healthstone = (actor.healthstone or 0) + 1
			set.healthstone = (set.healthstone or 0) + 1
		end
	end

	local function stone_used(t)
		if (t.spellid and stonespells[t.spellid]) or (t.spellname and t.spellname == stonename) then
			Skada:DispatchSets(log_healthstone, t.srcName, t.srcGUID, t.srcFlags)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Healthstones"], L[win.class]) or L["Healthstones"]

		local total = set and set:GetTotal(win.class, nil, "healthstone")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.healthstone then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.healthstone
				format_valuetext(d, total, win.metadata)
			end
		end
	end

	function mode:GetSetSummary(set, win)
		if not set then return end
		return set:GetTotal(win and win.class, nil, "healthstone") or 0
	end

	function mode:OnEnable()
		stonename = stonename or GetSpellInfo(47874)
		self.metadata = {
			showspots = true,
			ordersort = true,
			filterclass = true,
			columns = {Count = true, Percent = false},
			icon = [[Interface\ICONS\inv_stone_04]]
		}

		mode_cols = self.metadata.columns

		Skada:RegisterForCL(stone_used, {src_is_interesting_nopets = true}, "SPELL_CAST_SUCCESS")
		Skada:AddMode(self)
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end
end)
