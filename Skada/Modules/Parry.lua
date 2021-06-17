assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Parry-Haste", function(Skada, L)
	if Skada:IsDisabled("Parry-Haste") then return end

	local mod = Skada:NewModule(L["Parry-Haste"])
	local targetmod = mod:NewModule(L["Parry target list"])

	local pairs, format, select = pairs, string.format, select

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
			player.parry = (player.parry or 0) + 1
			set.parry = (set.parry or 0) + 1

			if set == Skada.current then
				player.parry_targets = player.parry_targets or {}
				player.parry_targets[data.dstName] = (player.parry_targets[data.dstName] or 0) + 1
			end
		end
	end

	local data = {}

	local function SpellMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if parrybosses[dstName] and srcGUID ~= dstGUID and select(4, ...) == "PARRY" then
			data.playerid = srcGUID
			data.playername = srcName
			data.playerflags = srcFlags
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
		win.title = format(L["%s's parry targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's parry targets"], player.name)
			local total = player.parry or 0

			if total > 0 and player.parry_targets then
				local maxvalue, nr = 0, 1

				for targetname, count in pairs(player.parry_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname
					d.class = "BOSS"

					d.value = count
					d.valuetext = Skada:FormatValueText(
						count,
						mod.metadata.columns.Count,
						format("%.1f%%", 100 * count / total),
						mod.metadata.columns.Percent
					)

					if count > maxvalue then
						maxvalue = count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Parry-Haste"]
		local total = set.parry or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.parry then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = Skada:FormatName(player.name, player.id)
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = player.parry
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Count,
						format("%.1f%%", 100 * d.value / total),
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
			nototalclick = {targetmod},
			columns = {Count = true, Percent = false},
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
		return set.parry or 0
	end
end)