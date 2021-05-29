assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Parry-Haste", function(Skada, L)
	if Skada:IsDisabled("Parry-Haste") then return end

	local mod = Skada:NewModule(L["Parry-Haste"])
	local targetmod = mod:NewModule(L["Parry target list"])

	local _pairs, _format, _select = pairs, string.format, select
	local _UnitClass = Skada.UnitClass

	local LBB = LibStub("LibBabble-Boss-3.0"):GetLookupTable()
	local parrybosses = {
		[LBB["Acidmaw"]] = true,
		[LBB["Dreadscale"]] = true,
		[LBB["Icehowl"]] = true,
		[LBB["Onyxia"]] = true,
		[LBB["Lady Deathwhisper"]] = true,
		[LBB["Sindragosa"]] = true,
		[LBB["Halion"]] = true
	}

	local function log_parry(set, data)
		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
		if player then
			player.parries = player.parries or {}
			player.parries.count = (player.parries.count or 0) + 1
			set.parries = (set.parries or 0) + 1

			player.parries.targets = player.parries.targets or {}
			if not player.parries.targets[data.dstName] then
				player.parries.targets[data.dstName] = {id = data.dstGUID, count = 1}
			else
				player.parries.targets[data.dstName].count = (player.parries.targets[data.dstName].count or 0) + 1
			end
		end
	end

	local data = {}

	local function SpellMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if parrybosses[dstName] and srcGUID ~= dstGUID and _select(4, ...) == "PARRY" then
			data.playerid = srcGUID
			data.playername = srcName
			data.playerflags = srcFlags
			data.dstGUID = dstGUID
			data.dstName = dstName

			Skada:FixPets(data)
			log_parry(Skada.current, data)
			log_parry(Skada.total, data)
		end
	end

	local function SwingMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, nil, nil, nil, ...)
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's parry targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's parry targets"], player.name)
			local total = player.parries and player.parries.count or 0

			if total > 0 and player.parries.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.parries.targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class = "BOSS"

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
		win.title = L["Parry-Haste"]
		local total = set.parries or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.parries then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = player.parries.count
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Count,
						_format("%.1f%%", 100 * d.value / total),
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
		self.metadata = {
			showspots = true,
			click1 = targetmod,
			columns = {Count = true, Percent = true},
			icon = "Interface\\Icons\\ability_parry"
		}

		Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return set.parries or 0
	end
end)