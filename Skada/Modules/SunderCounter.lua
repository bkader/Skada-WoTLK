assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Sunder Counter", function(Skada, L)
	if Skada:IsDisabled("Sunder Counter") then return end

	local mod = Skada:NewModule(L["Sunder Counter"])
	local targetmod = mod:NewModule(L["Sunder target list"])

	local pairs, select = pairs, select
	local tostring, format = tostring, string.format
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local _

	local sunder, devastate

	local function log_sunder(set, data)
		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
		if player then
			set.sunder = (set.sunder or 0) + 1
			player.sunder = (player.sunder or 0) + 1

			if set == Skada.current and data.dstName then
				player.sunder_targets = player.sunder_targets or {}
				player.sunder_targets[data.dstName] = (player.sunder_targets[data.dstName] or 0) + 1
			end
		end
	end

	local data = {}

	local function SunderApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellname = select(2, ...)
		if spellname == sunder or spellname == devastate then
			data.playerid = srcGUID
			data.playername = srcName
			data.playerflags = srcFlags
			data.dstName = dstName

			log_sunder(Skada.current, data)
			log_sunder(Skada.total, data)
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's <%s> targets"], label, sunder)
	end

	function targetmod:Update(win, set)
		if not sunder then
			sunder = GetSpellInfo(47467)
			devastate = GetSpellInfo(47498)
		end

		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's <%s> targets"], player.name, sunder)
			local total = player.sunder or 0

			if total > 0 and player.sunder_targets then
				local maxvalue, nr = 0, 1

				for targetname, count in pairs(player.sunder_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname
					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		if not sunder then
			sunder = GetSpellInfo(47467)
			devastate = GetSpellInfo(47498)
		end

		win.title = L["Sunder Counter"]
		local total = set.sunder or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if (player.sunder or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.spec = player.spec
					d.role = player.role

					d.value = player.sunder
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
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

	function mod:OnInitialize()
		sunder = GetSpellInfo(47467)
		devastate = GetSpellInfo(47498)
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			click1 = targetmod,
			nototalclick = {targetmod},
			columns = {Count = true, Percent = true},
			icon = "Interface\\Icons\\ability_warrior_sunder"
		}
		Skada:RegisterForCL(SunderApplied, "SPELL_CAST_SUCCESS", {src_is_interesting_nopets = true})
		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if set and (set.sunder or 0) > 0 then
			tooltip:AddDoubleLine(sunder, set.sunder or 0, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return tostring(set.sunder or 0), set.sunder or 0
	end
end)