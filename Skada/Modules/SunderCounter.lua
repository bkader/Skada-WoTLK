assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Sunder Counter", function(Skada, L)
	if Skada:IsDisabled("Sunder Counter") then return end

	local mod = Skada:NewModule(L["Sunder Counter"])
	local targetmod = mod:NewModule(L["Sunder target list"])

	local _pairs, _select, _format = pairs, select, string.format
	local _UnitClass, _GetSpellInfo = Skada.UnitClass, Skada.GetSpellInfo or GetSpellInfo

	local sunder, devastate

	local function log_sunder(set, data)
		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
		if player then
			player.sunders = player.sunders or {}
			player.sunders.count = (player.sunders.count or 0) + 1
			set.sunders = (set.sunders or 0) + 1

			if data.dstName then
				player.sunders.targets = player.sunders.targets or {}
				if not player.sunders.targets[data.dstName] then
					player.sunders.targets[data.dstName] = {id = data.dstGUID, flags = data.dstFlags, count = 1}
				else
					player.sunders.targets[data.dstName].count = (player.sunders.targets[data.dstName].count or 0) + 1
				end
			end
		end
	end

	local data = Skada:WeakTable()

	local function SunderApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool = ...
		if spellname == sunder or spellname == devastate then
			data.playerid = srcGUID
			data.playername = srcName
			data.playerflags = srcFlags

			data.dstGUID = dstGUID
			data.dstName = dstName
			data.dstFlags = dstFlags

			log_sunder(Skada.current, data)
			log_sunder(Skada.total, data)
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's <%s> targets"], label, sunder)
	end

	function targetmod:Update(win, set)
		if not sunder then
			sunder = _select(1, _GetSpellInfo(47467))
			devastate = _select(1, _GetSpellInfo(47498))
		end

		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's <%s> targets"], player.name, sunder)
			local total = player.sunders and player.sunders.count or 0

			if total > 0 and player.sunders.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.sunders.targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = _select(2, _UnitClass(target.id, target.flags, set))

					d.value = target.count
					d.valuetext = Skada:FormatValueText(
						target.count,
						mod.metadata.columns.Count,
						_format("%.1f%%", 100 * target.count / total),
						mod.metadata.columns.Percent
					)

					if target.count > maxvalue then
						maxvalue = target.count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		if not sunder then
			sunder = _select(1, _GetSpellInfo(47467))
			devastate = _select(1, _GetSpellInfo(47498))
		end

		win.title = L["Sunder Counter"]
		local total = set.sunders or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.sunders and (player.sunders.count > 0) then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class
					d.spec = player.spec
					d.role = player.role

					d.value = player.sunders.count
					d.valuetext = Skada:FormatValueText(
						player.sunders.count,
						self.metadata.columns.Count,
						_format("%.1f%%", 100 * player.sunders.count / total),
						self.metadata.columns.Percent
					)

					if player.sunders.count > maxvalue then
						maxvalue = player.sunders.count
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnInitialize()
		sunder = _select(1, _GetSpellInfo(47467))
		devastate = _select(1, _GetSpellInfo(47498))
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			click1 = targetmod,
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
		tooltip:AddDoubleLine(sunder, set.sunders or 0, 1, 1, 1)
	end

	function mod:GetSetSummary(set)
		return set.sunders or 0
	end
end)