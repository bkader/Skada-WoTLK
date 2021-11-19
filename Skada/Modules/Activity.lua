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
				tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, settime), 1, 1, 1)
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Activity"]

		local settime = set and set:GetTime()
		if settime > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 1
			for _, player in ipairs(set.players) do
				local activetime = player:GetTime(true)

				if activetime > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = activetime
					d.valuetext = Skada:FormatValueText(
						Skada:FormatTime(d.value),
						self.metadata.columns["Active Time"],
						Skada:FormatPercent(d.value, settime),
						self.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
					nr = nr + 1
				end
			end
		end
	end

	function mod:OnEnable()
		mod.metadata = {
			showspots = true,
			ordersort = true,
			tooltip = activity_tooltip,
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
			return Skada:FormatValueText(
				Skada:FormatTime(settime),
				self.metadata.columns["Active Time"],
				format("%s - %s", date("%H:%M", set.starttime), date("%H:%M", set.endtime)),
				self.metadata.columns.Percent
			), settime
		end
	end
end)