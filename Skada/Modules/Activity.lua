local Skada = Skada
Skada:AddLoadableModule("Activity", function(L)
	if Skada:IsDisabled("Activity") then return end

	local mod = Skada:NewModule(L["Activity"])
	local ipairs, date, format, max = ipairs, date, string.format, math.max

	local function activity_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local player = set and set:GetPlayer(id, label)
		if player then
			local settime = set:GetTime()
			if settime > 0 then
				local activetime = player:GetTime(true)
				tooltip:AddLine(player.name .. ": " .. L["Activity"])
				tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
				tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
				tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, settime), nil, nil, nil, 1, 1, 1)
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Activity"], L[win.class]) or L["Activity"]

		local settime = set and set:GetTime()
		if settime > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- players.
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and player.class and Skada.validclass[player.class] then
					local activetime = player:GetTime(true)
					if activetime > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						if Skada.forPVP and set.type == "arena" then
							d.color = set.gold and Skada.classcolors.ARENA_GOLD or Skada.classcolors.ARENA_GREEN
						end

						d.value = activetime
						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns["Active Time"] and Skada:FormatTime(d.value),
							self.metadata.columns.Percent and Skada:FormatPercent(d.value, settime)
						)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end

			-- arena enemies
			if Skada.forPVP and set.type == "arena" and set.enemies then
				for _, enemy in ipairs(set.enemies) do
					if (not win.class or win.class == enemy.class) and enemy.class and Skada.validclass[enemy.class] then
						local activetime = enemy:GetTime(true)
						if activetime > 0 then
							nr = nr + 1

							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = enemy.id or enemy.name
							d.label = enemy.name
							d.text = nil
							d.class = enemy.class
							d.role = enemy.role
							d.spec = enemy.spec
							d.color = set.gold and Skada.classcolors.ARENA_GREEN or Skada.classcolors.ARENA_GOLD

							d.value = activetime
							d.valuetext = Skada:FormatValueCols(
								self.metadata.columns["Active Time"] and Skada:FormatTime(d.value),
								self.metadata.columns.Percent and Skada:FormatPercent(d.value, settime)
							)

							if win.metadata and d.value > win.metadata.maxvalue then
								win.metadata.maxvalue = d.value
							end
						end
					end
				end
			end
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			tooltip = activity_tooltip,
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			columns = {["Active Time"] = true, Percent = true},
			icon = [[Interface\Icons\spell_holy_borrowedtime]]
		}
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local settime = set and set:GetTime() or 0
		if settime > 0 then
			return Skada:FormatValueCols(
				self.metadata.columns["Active Time"] and Skada:FormatTime(settime),
				self.metadata.columns.Percent and format("%s - %s", date("%H:%M", set.starttime), date("%H:%M", set.endtime))
			), settime
		end
	end
end)