assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Dispels", function(Skada, L)
	if Skada:IsDisabled("Dispels") then return end

	local mod = Skada:NewModule(L["Dispels"])
	local spellmod = mod:NewModule(L["Dispelled spell list"])
	local targetmod = mod:NewModule(L["Dispelled target list"])
	local playermod = mod:NewModule(L["Dispel spell list"])

	-- cache frequently used globals
	local _pairs, _select, _format = pairs, select, string.format
	local _UnitClass, _GetSpellInfo = Skada.UnitClass, Skada.GetSpellInfo or GetSpellInfo

	local function log_dispels(set, data)
		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
		if player then
			-- increment player's and set's dispels count
			player.dispels = player.dispels or {}
			player.dispels.count = (player.dispels.count or 0) + 1
			set.dispels = (set.dispels or 0) + 1

			-- add the dispelled spell
			if data.spellid then
				player.dispels.spells = player.dispels.spells or {}
				if not player.dispels.spells[data.spellid] then
					player.dispels.spells[data.spellid] = {school = data.spellschool, count = 1}
				else
					player.dispels.spells[data.spellid].count = player.dispels.spells[data.spellid].count + 1
				end
			end

			-- add the dispelling spell
			if data.extraspellid then
				player.dispels.extraspells = player.dispels.extraspells or {}
				if not player.dispels.extraspells[data.extraspellid] then
					player.dispels.extraspells[data.extraspellid] = {school = data.extraspellschool, count = 1}
				else
					player.dispels.extraspells[data.extraspellid].count = player.dispels.extraspells[data.extraspellid].count + 1
				end
			end

			-- add the dispelled target
			if data.dstName then
				player.dispels.targets = player.dispels.targets or {}
				if not player.dispels.targets[data.dstName] then
					player.dispels.targets[data.dstName] = {id = data.dstGUID, flags = data.dstFlags, count = 1}
				else
					player.dispels.targets[data.dstName].count = player.dispels.targets[data.dstName].count + 1
				end
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

			data.dstGUID = dstGUID
			data.dstName = dstName
			data.dstFlags = dstFlags

			data.spellid = spellid
			data.spellschool = spellschool

			data.extraspellid = extraspellid or 6603
			data.extraspellname = extraspellname or L["Auto Attack"]
			data.extraspellschool = extraspellschool or 1

			log_dispels(Skada.current, data)
			log_dispels(Skada.total, data)
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's dispelled spells"], label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's dispelled spells"], player.name)
			local total = player.dispels and player.dispels.count or 0

			if total > 0 and player.dispels.extraspells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.dispels.extraspells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					local spellname, _, spellicon = _GetSpellInfo(spellid)
					d.id = spellid
					d.spellid = spellid
					d.label = spellname
					d.icon = spellicon
					d.spellschool = spell.school

					d.value = spell.count
					d.valuetext = Skada:FormatValueText(
						spell.count,
						mod.metadata.columns.Total,
						_format("%.1f%%", 100 * spell.count / total),
						mod.metadata.columns.Percent
					)

					if spell.count > maxvalue then
						maxvalue = spell.count
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's dispelled targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's dispelled targets"], player.name)
			local total = player.dispels and player.dispels.count or 0

			if total > 0 and player.dispels.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.dispels.targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = _select(2, _UnitClass(d.id, target.flags, set))

					d.value = target.count
					d.valuetext = Skada:FormatValueText(
						target.count,
						mod.metadata.columns.Total,
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

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's dispel spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's dispel spells"], player.name)
			local total = player.dispels and (player.dispels.count or 0) or 0

			if total > 0 and player.dispels.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.dispels.spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					local spellname, _, spellicon = _GetSpellInfo(spellid)
					d.id = spellid
					d.spellid = spellid
					d.label = spellname
					d.icon = spellicon
					d.spellschool = spell.school

					d.value = spell.count or 0
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Total,
						_format("%.1f%%", 100 * d.value / total),
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

		local total = set.dispels or 0
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.dispels and (player.dispels.count or 0) then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = Skada:FormatName(player.name, player.id)
					d.class = player.class or "PET"
					d.spec = player.spec
					d.role = player.role

					d.value = player.dispels.count
					d.valuetext = Skada:FormatValueText(
						player.dispels.count,
						self.metadata.columns.Total,
						_format("%.1f%%", 100 * player.dispels.count / total),
						self.metadata.columns.Percent
					)

					if player.dispels.count > maxvalue then
						maxvalue = player.dispels.count
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
		if set and (set.dispels or 0) > 0 then
			tooltip:AddDoubleLine(L["Dispels"], set.dispels, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return set.dispels or 0
	end
end)