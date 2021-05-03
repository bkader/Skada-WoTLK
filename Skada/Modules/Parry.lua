assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Parry-haste", function(Skada, L)
	if Skada:IsDisabled("Parry-haste") then return end

	local mod = Skada:NewModule(L["Parry-haste"])
	local targetmod = mod:NewModule(L["Parry target list"])

	local _pairs, _ipairs = pairs, ipairs
	local _format, math_max = string.format, math.max

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
			player.parries.targets[data.dstName] = (player.parries.targets[data.dstName] or 0) + 1
		end
	end

	local data = {}

	local function SpellMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if parrybosses[dstName] and srcGUID ~= dstGUID then
			local _, _, _, misstype = ...
			if misstype == "PARRY" then
				data.playerid = srcGUID
				data.playername = srcName
				data.playerflags = srcFlags
				data.dstName = dstName

				Skada:FixPets(data)
				log_parry(Skada.current, data)
				log_parry(Skada.total, data)
			end
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
		local max, player = 0, Skada:find_player(set, win.playerid, win.playername)
		if player and player.parries then
			win.title = _format(L["%s's parry targets"], player.name)

			local nr, total = 1, player.parries.count or 0
			for targetname, count in _pairs(player.parries.targets) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = targetname
				d.label = targetname

				d.value = count
				d.valuetext = Skada:FormatValueText(
					count,
					mod.metadata.columns.Count,
					_format("%02.1f%%", 100 * count / math_max(1, total)),
					mod.metadata.columns.Percent
				)

				if count > max then
					max = count
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	function mod:Update(win, set)
		local max = 0
		local total = set and set.parries or 0

		if total > 0 then
			local nr = 1

			for _, player in _ipairs(set.players) do
				if player.parries then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.class = player.class or "PET"
					d.role = player.role or "DAMAGER"
					d.spec = player.spec or 1

					d.value = player.parries.count
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Count,
						_format("%02.1f%%", 100 * d.value / math_max(1, total)),
						self.metadata.columns.Percent
					)

					if d.value > max then
						max = d.value
					end

					nr = nr + 1
				end
			end
		end

		win.metadata.maxvalue = max
		win.title = L["Parry-haste"]
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			click1 = targetmod,
			columns = {Count = true, Percent = true}
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