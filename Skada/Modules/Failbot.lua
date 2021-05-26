assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Fails", function(Skada, L)
	if Skada:IsDisabled("Fails") then return end

	-- this line is moved here so that the module is not added
	-- in case the LibFail library is missing
	local LibFail = LibStub("LibFail-1.0", true)
	if not LibFail then return end

	local failevents = LibFail:GetSupportedEvents()
	local tankevents

	local mod = Skada:NewModule(L["Fails"])
	local playermod = mod:NewModule(L["Player's failed events"])
	local spellmod = mod:NewModule(L["Event's failed players"])

	local _pairs, _ipairs = pairs, ipairs
	local _tostring, _format = tostring, string.format
	local _GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local _UnitGUID = UnitGUID

	local function log_fail(set, playerid, playername, spellid)
		if set then
			local player = Skada:find_player(set, playerid, playername)
			if player and (player.role ~= "TANK" or not tankevents[event]) then
				-- players
				player.fails = player.fails or {count = 0, spells = {}}
				player.fails.count = (player.fails.count or 0) + 1
				player.fails.spells = player.fails.spells or {}
				player.fails.spells[spellid] = (player.fails.spells[spellid] or 0) + 1

				-- set
				set.fails = set.fails or {count = 0, spells = {}}
				set.fails.count = (set.fails.count or 0) + 1
				set.fails.spells = set.fails.spells or {}
				set.fails.spells[spellid] = (set.fails.spells[spellid] or 0) + 1
			end
		end
	end

	local function onFail(event, who, failtype)
		if event and who then
			local spellid = LibFail:GetEventSpellId(event)
			if not spellid then return end

			local unitGUID = _UnitGUID(who)
			if not unitGUID then return end

			log_fail(Skada.current, unitGUID, who, spellid)
			log_fail(Skada.total, unitGUID, who, spellid)
		end
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = _format(L["%s's fails"], label)
	end

	function spellmod:Update(win, set)
		win.title = _format(L["%s's fails"], win.spellname or UNKNOWN)

		local total = 0
		if set.fails and set.fails.spells and set.fails.spells[win.spellid] then
			total = set.fails.spells[win.spellid]
		end

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.fails and player.fails.spells[win.spellid] then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = player.fails.spells[win.spellid]
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Count,
						_format("%02.1f%%", 100 * d.value / total),
						mod.metadata.columns.Percent
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

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's fails"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's fails"], player.name)
			local total = player.fails and player.fails.count or 0

			if total > 0 and player.fails.spells then
				local maxvalue, nr = 0, 1

				for spellid, count in _pairs(player.fails.spells) do
					local spellname, _, spellicon = _GetSpellInfo(spellid)
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label = spellname
					d.icon = spellicon

					d.value = count
					d.valuetext = Skada:FormatValueText(
						count,
						mod.metadata.columns.Count,
						_format("%02.1f%%", 100 * count / total),
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
		win.title = L["Fails"]
		local total = set.fails and (set.fails.count or 0) or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.fails and (player.fails.count or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = player.fails.count
					d.valuetext = Skada:FormatValueText(
						player.fails.count,
						self.metadata.columns.Count,
						_format("%02.1f%%", 100 * player.fails.count / total),
						self.metadata.columns.Percent
					)

					if d.value > player.fails.count then
						player.fails.count = d.value
					end
					nr = nr + 1
				end
			end
			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnInitialize()
		tankevents = {}
		for _, event in _ipairs(LibFail:GetFailsWhereTanksDoNotFail()) do
			tankevents[event] = true
		end
		for _, event in _ipairs(failevents) do
			LibFail:RegisterCallback(event, onFail)
		end
	end

	function mod:OnEnable()
		if not tankevents then
			self:OnInitialize()
		end

		playermod.metadata = {click1 = spellmod}
		self.metadata = {
			click1 = playermod,
			columns = {Count = true, Percent = false},
			icon = "Interface\\Icons\\ability_creature_cursed_01"
		}

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return set.fails and set.fails.count or 0
	end

	function mod:AddToTooltip(set, tooltip)
		if set and set.fails and (set.fails.count or 0) > 0 then
			tooltip:AddDoubleLine(L["Fails"], set.fails.count, 1, 1, 1)
		end
	end
end)