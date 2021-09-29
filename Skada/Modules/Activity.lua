assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Activity", function(Skada, L)
	if Skada:IsDisabled("Activity") then return end

	local mod = Skada:NewModule(L["Activity"])
	local ipairs, date, format, max = ipairs, date, string.format, math.max

	local function activity_tooltip(win, id, label, tooltip)
		local set = win:get_selected_set()
		local player = Skada:find_player(set, id, label)
		if player then
			local settime = Skada:GetSetTime(set)
			if settime > 0 then
				local activetime = Skada:PlayerActiveTime(set, player, true)
				tooltip:AddLine(player.name .. ": " .. L["Activity"])
				tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
				tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
				tooltip:AddDoubleLine(L["Activity"], Skada:FormatPercent(activetime, settime), 1, 1, 1)
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Activity"]
		local settime = Skada:GetSetTime(set)

		if settime > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local activetime = Skada:PlayerActiveTime(set, player, true)

				if activetime > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
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

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		mod.metadata = {
			showspots = true,
			ordersort = true,
			tooltip = activity_tooltip,
			columns = {["Active Time"] = true, Percent = true},
			icon = "Interface\\Icons\\spell_nature_timestop"
		}
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local value = Skada:GetSetTime(set)
		return Skada:FormatValueText(
			Skada:FormatTime(value),
			self.metadata.columns["Active Time"],
			format("%s - %s", date("%H:%M", set.starttime), date("%H:%M", set.endtime)),
			self.metadata.columns.Percent
		), value
	end
end)