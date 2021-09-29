assert(Skada, "Skada not found!")

local LibFail = LibStub("LibFail-1.0", true)
if not LibFail then return end

Skada:AddLoadableModule("Fails", function(Skada, L)
	if Skada:IsDisabled("Fails") then return end

	local mod = Skada:NewModule(L["Fails"])
	local playermod = mod:NewModule(L["Player's failed events"])
	local spellmod = mod:NewModule(L["Event's failed players"])

	local pairs, ipairs = pairs, ipairs
	local tostring, format, tContains = tostring, string.format, tContains
	local GetSpellInfo, UnitGUID = Skada.GetSpellInfo or GetSpellInfo, UnitGUID
	local IsInGroup, IsInRaid = Skada.IsInGroup, Skada.IsInRaid
	local failevents, tankevents = LibFail:GetSupportedEvents(), LibFail:GetFailsWhereTanksDoNotFail()
	local _

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_fail(set, playerid, playername, spellid, event)
		if (spellid and tContains(ignoredSpells, spellid)) or not set then return end

		local player = Skada:find_player(set, playerid, playername)
		if player and (player.role ~= "TANK" or not tContains(tankevents, event)) then
			player.fail = (player.fail or 0) + 1
			set.fail = (set.fail or 0) + 1

			if set == Skada.current and spellid then
				player.fail_spells = player.fail_spells or {}
				player.fail_spells[spellid] = (player.fail_spells[spellid] or 0) + 1
			end
		end
	end

	local function onFail(event, who, failtype)
		if who and event then
			local spellid = LibFail:GetEventSpellId(event)
			if spellid then
				local unitGUID = UnitGUID(who)
				if unitGUID then
					log_fail(Skada.current, unitGUID, who, spellid, event)
					log_fail(Skada.total, unitGUID, who, spellid, event)
				end
			end
		end
	end

	local function countFail(set, spellid)
		local count = 0
		if set and spellid then
			for _, player in ipairs(set.players) do
				if player.fail_spells and player.fail_spells[spellid] then
					count = count + player.fail_spells[spellid]
				end
			end
		end
		return count
	end

	function spellmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's fails"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's fails"], win.spellname or UNKNOWN)

		local total = countFail(set, win.spellid or 0)
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if player.fail_spells and player.fail_spells[win.spellid] then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.fail_spells[win.spellid]
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
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's fails"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's fails"], player.name)
			local total = player.fail or 0

			if total > 0 and player.fail_spells then
				local maxvalue, nr = 0, 1

				for spellid, count in pairs(player.fail_spells) do
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

	function mod:Update(win, set)
		win.title = L["Fails"]
		local total = set.fail or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.fail or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.fail
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if d.value > d.value then
						d.value = d.value
					end
					nr = nr + 1
				end
			end
			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		playermod.metadata = {click1 = spellmod}
		self.metadata = {
			click1 = playermod,
			nototalclick = {playermod},
			columns = {Count = true, Percent = false},
			icon = "Interface\\Icons\\ability_creature_cursed_01"
		}

		tankevents = tankevents or LibFail:GetFailsWhereTanksDoNotFail()
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return tostring(set.fail or 0), set.fail or 0
	end

	function mod:AddToTooltip(set, tooltip)
		if set and (set.fail or 0) > 0 then
			tooltip:AddDoubleLine(L["Fails"], set.fail, 1, 1, 1)
		end
	end

	--------------------------------------------------------------------------

	do
		local options  -- holds the options table
		local function GetOptions()
			if not options then
				options = {
					type = "group",
					name = mod.moduleName,
					desc = format(L["Options for %s."], mod.moduleName),
					get = function(i) return Skada.db.profile.modules[i[#i]] end,
					set = function(i, val) Skada.db.profile.modules[i[#i]] = val or nil end,
					args = {
						failsannounce = {
							type = "toggle",
							name = L["Report Fails"],
							desc = L["Reports the group fails at the end of combat if there are any."],
							descStyle = "inline",
							order = 10,
							width = "double"
						},
						failschannel = {
							type = "select",
							name = L["Channel"],
							values = {AUTO = INSTANCE, GUILD = GUILD, OFFICER = CHAT_MSG_OFFICER, SELF = L["Self"]},
							order = 20,
							width = "double"
						}
					}
				}
			end
			return options
		end

		function mod:OnInitialize()
			failevents = failevents or LibFail:GetSupportedEvents()
			tankevents = tankevents or LibFail:GetFailsWhereTanksDoNotFail()

			if Skada.db.profile.modules.failschannel == nil then
				Skada.db.profile.modules.failschannel = "AUTO"
			end
			if Skada.db.profile.modules.ignoredfails then
				Skada.db.profile.modules.ignoredfails = nil
			end

			Skada.options.args.modules.args.failbot = GetOptions()
		end
	end

	function mod:SetComplete(set)
		if not (Skada.db.profile.modules.failsannounce and IsInGroup()) then return end
		if set ~= Skada.current or (set.fail or 0) == 0 then return end

		local channel = Skada.db.profile.modules.failschannel or "AUTO"
		local chantype = (channel == "SELF") and "self" or "preset"
		if channel == "AUTO" then
			local zoneType = select(2, IsInInstance())
			if zoneType == "pvp" or zoneType == "arena" then
				channel = "BATTLEGROUND"
			elseif zoneType == "party" or zoneType == "raid" then
				channel = zoneType:upper()
			else
				channel = IsInRaid() and "RAID" or "PARTY"
			end
		end
		Skada:Report(channel, chantype, L["Fails"], nil, 10)
	end
end)