assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Dispels", function(Skada, L)
	if Skada:IsDisabled("Dispels") then return end

	local mod = Skada:NewModule(L["Dispels"])
	local spellmod = mod:NewModule(L["Dispelled spell list"])
	local targetmod = mod:NewModule(L["Dispelled target list"])
	local playermod = mod:NewModule(L["Dispel spell list"])

	-- cache frequently used globals
	local pairs, ipairs, select = pairs, ipairs, select
	local tostring, format = tostring, string.format
	local GetSpellInfo, tContains = Skada.GetSpellInfo or GetSpellInfo, tContains
	local _

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_dispel(set, data)
		if (data.spellid and tContains(ignoredSpells, data.spellid)) or (data.extraspellid and tContains(ignoredSpells, data.extraspellid)) then return end

		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
		if player then
			-- increment player's and set's dispels count
			player.dispel = (player.dispel or 0) + 1
			set.dispel = (set.dispel or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set ~= Skada.current then return end

			-- add the dispelled spell
			if data.spellid then
				player.dispel_spells = player.dispel_spells or {}
				player.dispel_spells[data.spellid] = (player.dispel_spells[data.spellid] or 0) + 1
			end

			-- add the dispelling spell
			if data.extraspellid then
				player.dispel_dspells = player.dispel_dspells or {}
				player.dispel_dspells[data.extraspellid] = (player.dispel_dspells[data.extraspellid] or 0) + 1
			end

			-- add the dispelled target
			if data.dstName then
				player.dispel_targets = player.dispel_targets or {}
				player.dispel_targets[data.dstName] = (player.dispel_targets[data.dstName] or 0) + 1
			end
		end
	end

	local data = {}

	local function SpellDispel(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if eventtype ~= "SPELL_DISPEL_FAILED" then
			local spellid, spellname, spellschool, extraspellid, extraspellname, extraspellschool, auraType = ...

			data.playerid = srcGUID
			data.playername = srcName
			data.playerflags = srcFlags

			data.dstName = dstName
			data.spellid = spellid
			data.extraspellid = extraspellid or 6603

			log_dispel(Skada.current, data)
			log_dispel(Skada.total, data)
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's dispelled spells"], label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's dispelled spells"], player.name)
			local total = player.dispel or 0

			if total > 0 and player.dispel_dspells then
				local maxvalue, nr = 0, 1

				for spellid, count in pairs(player.dispel_dspells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)

					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Total,
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
		win.title = format(L["%s's dispelled targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's dispelled targets"], player.name)
			local total = player.dispel or 0

			if total > 0 and player.dispel_targets then
				local maxvalue, nr = 0, 1

				for targetname, count in pairs(player.dispel_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname

					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Total,
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

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's dispel spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's dispel spells"], player.name)
			local total = player.dispel or 0

			if total > 0 and player.dispel_spells then
				local maxvalue, nr = 0, 1

				for spellid, count in pairs(player.dispel_spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)

					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Total,
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
		win.title = L["Dispels"]

		local total = set.dispel or 0
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.dispel or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.spec = player.spec
					d.role = player.role

					d.value = player.dispel
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Total,
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
			click1 = spellmod,
			click2 = targetmod,
			click3 = playermod,
			nototalclick = {spellmod, targetmod, playermod},
			columns = {Total = true, Percent = true},
			icon = "Interface\\Icons\\spell_arcane_massdispel"
		}

		Skada:RegisterForCL(SpellDispel, "SPELL_DISPEL", {src_is_interesting = true})
		Skada:RegisterForCL(SpellDispel, "SPELL_STOLEN", {src_is_interesting = true})

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:AddToTooltip(set, tooltip)
		if set and (set.dispel or 0) > 0 then
			tooltip:AddDoubleLine(L["Dispels"], set.dispel, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return tostring(set.dispel or 0), set.dispel or 0
	end
end)