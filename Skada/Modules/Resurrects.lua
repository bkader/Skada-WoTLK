assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Resurrects", function(Skada, L)
	if Skada:IsDisabled("Resurrects") then return end

	local mod = Skada:NewModule(L["Resurrects"])
	local playermod = mod:NewModule(L["Resurrect spell list"])
	local targetmod = mod:NewModule(L["Resurrect target list"])

	local _select, _pairs, _format = select, pairs, string.format
	local _UnitClass, _GetSpellInfo = Skada.UnitClass, Skada.GetSpellInfo or GetSpellInfo

	local function log_resurrect(set, data)
		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
		if player then
			player.resurrect = player.resurrect or {}
			player.resurrect.count = (player.resurrect.count or 0) + 1
			set.resurrect = (set.resurrect or 0) + 1

			-- epll
			player.resurrect.spells = player.resurrect.spells or {}
			if not player.resurrect.spells[data.spellid] then
				player.resurrect.spells[data.spellid] = {count = 1, school = data.spellschool}
			else
				player.resurrect.spells[data.spellid].count = player.resurrect.spells[data.spellid].count + 1
			end

			-- target
			player.resurrect.targets = player.resurrect.targets or {}
			if not player.resurrect.targets[data.dstName] then
				player.resurrect.targets[data.dstName] = {id = data.dstGUID, count = 1}
			else
				player.resurrect.targets[data.dstName].count = player.resurrect.targets[data.dstName].count + 1
			end
		end
	end

	local data = Skada:WeakTable()

	local function SpellResurrect(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, _, spellschool = ...

		data.playerid = srcGUID
		data.playername = srcName
		data.playerflags = srcFlags

		data.dstGUID = dstGUID
		data.dstName = dstName
		data.dstFlags = dstFlags

		data.spellid = spellid
		data.spellschool = spellschool

		log_resurrect(Skada.current, data)
		log_resurrect(Skada.total, data)
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's resurrect spells"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's resurrect spells"], player.name)
			local total = player.resurrect and player.resurrect.count or 0

			if total > 0 and player.resurrect.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.resurrect.spells) do
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
						mod.metadata.columns.Count,
						_format("%02.1f%%", 100 * spell.count / total),
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
		win.title = _format(L["%s's resurrect targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's resurrect targets"], player.name)
			local total = player.resurrect and player.resurrect.count or 0

			if total > 0 and player.resurrect.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.resurrect.targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = _select(2, _UnitClass(target.id, nil, set))

					d.value = target.count
					d.valuetext = Skada:FormatValueText(
						target.count,
						mod.metadata.columns.Count,
						_format("%02.1f%%", 100 * target.count / total),
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
		win.title = L["Resurrects"]
		local total = set.resurrect or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.resurrect and (player.resurrect.count or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.resurrect.count
					d.valuetext = Skada:FormatValueText(
						player.resurrect.count,
						self.metadata.columns.Count,
						_format("%02.1f%%", 100 * player.resurrect.count / total),
						self.metadata.columns.Percent
					)

					if player.resurrect.count > maxvalue then
						maxvalue = player.resurrect.count
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
		if (set.resurrect or 0) > 0 then
			tooltip:AddDoubleLine(L["Resurrects"], set.resurrect, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return set.resurrect or 0
	end
end)