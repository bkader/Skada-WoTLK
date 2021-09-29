assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Resurrects", function(Skada, L)
	if Skada:IsDisabled("Resurrects") then return end

	local mod = Skada:NewModule(L["Resurrects"])
	local playermod = mod:NewModule(L["Resurrect spell list"])
	local targetmod = mod:NewModule(L["Resurrect target list"])

	local select, pairs, ipairs = select, pairs, ipairs
	local tostring, format = tostring, string.format
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local _

	local function log_resurrect(set, data)
		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
		if player then
			player.ress = (player.ress or 0) + 1
			set.ress = (set.ress or 0) + 1

			-- spell
			player.ress_spells = player.ress_spells or {}
			player.ress_spells[data.spellid] = (player.ress_spells[data.spellid] or 0) + 1

			-- target
			if set == Skada.current then
				player.ress_targets = player.ress_targets or {}
				player.ress_targets[data.dstName] = (player.ress_targets[data.dstName] or 0) + 1
			end
		end
	end

	local data = {}

	local function SpellResurrect(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		data.playerid = srcGUID
		data.playername = srcName
		data.playerflags = srcFlags
		data.dstName = dstName
		data.spellid = ...

		log_resurrect(Skada.current, data)
		log_resurrect(Skada.total, data)
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's resurrect spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's resurrect spells"], player.name)
			local total = player.ress or 0

			if total > 0 and player.ress_spells then
				local maxvalue, nr = 0, 1

				for spellid, count in pairs(player.ress_spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)

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

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's resurrect targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's resurrect targets"], player.name)
			local total = player.ress or 0

			if total > 0 and player.ress_targets then
				local maxvalue, nr = 0, 1

				for targetname, count in pairs(player.ress_targets) do
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
		win.title = L["Resurrects"]
		local total = set.ress or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.ress or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.ress
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

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			click1 = playermod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Count = true, Percent = false},
			icon = "Interface\\Icons\\spell_nature_reincarnation"
		}

		Skada:RegisterForCL(SpellResurrect, "SPELL_RESURRECT", {src_is_interesting = true, dst_is_interesting = true})

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if (set.ress or 0) > 0 then
			tooltip:AddDoubleLine(L["Resurrects"], set.ress, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return tostring(set.ress or 0), set.ress or 0
	end
end)