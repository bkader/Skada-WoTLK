assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Potions", function(Skada, L)
	if Skada:IsDisabled("Potions") then return end

	local mod = Skada:NewModule(L["Potions"])
	local potionsmod = mod:NewModule(L["Potions list"])
	local playersmod = mod:NewModule(L["Players list"])

	-- cache frequently used globals
	local _pairs, _ipairs, _select, tconcat = pairs, ipairs, select, table.concat
	local _pairs, _ipairs, _select = pairs, ipairs, select
	local _format, _strsub, _tostring, math_max = string.format, string.sub, tostring, math.max
	local _GetNumPartyMembers = GetNumPartyMembers
	local _GetNumRaidMembers = GetNumRaidMembers
	local _GetItemInfo = GetItemInfo
	local _UnitExists, _UnitIsDeadOrGhost = UnitExists, UnitIsDeadOrGhost
	local _UnitGUID, _UnitName = UnitGUID, UnitName
	local _UnitClass, _UnitBuff = UnitClass, UnitBuff

	local potionIDs = {
		[28494] = 22828, -- Insane Strength Potion
		[38929] = 31677, -- Fel mana potion
		[53909] = 40212, -- Potion of Wild Magic
		[53908] = 40211, -- Potion of Speed
		[53750] = 40077, -- Crazy Alchemist's Potion
		[53761] = 40087, -- Powerful Rejuvenation Potion
		[43185] = 33447, -- Healing Potion
		[43186] = 33448, -- Restore Mana
		[53753] = 40081, -- Nightmare Slumber
		[53910] = 40213, -- Arcane Protection
		[53911] = 40214, -- Fire Protection
		[53913] = 40215, -- Frost Protection
		[53914] = 40216, -- Nature Protection
		[53915] = 40217, -- Shadow Protection
		[53762] = 40093, -- Indestructible
		[67490] = 42545 -- Runic Mana Injector
	}

	local prepotion = {}
	local prepottStr = "|c%s%s|r |T%s:14:14:0:0:64:64:0:64:0:64|t"

	local function log_potion(set, playerid, playername, playerflags, spellid)
		local player = Skada:get_player(set, playerid, playername, playerflags)
		if player then
			-- record potion usage for player and set
			player.potions = player.potions or {}
			player.potions.count = (player.potions.count or 0) + 1
			set.potions = (set.potions or 0) + 1

			-- record the potion
			local potionid = potionIDs[spellid]
			player.potions.potions = player.potions.potions or {}
			player.potions.potions[potionid] = (player.potions.potions[potionid] or 0) + 1
		end
	end

	local function PotionUsed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool = ...
		if spellid and potionIDs[spellid] then
			log_potion(Skada.current, srcGUID, srcName, srcFlags, spellid)
			log_potion(Skada.total, srcGUID, srcName, srcFlags, spellid)
		end
	end

	-- we use this function to record pre-pots as well.
	function mod:CheckPrePot(event)
		if Skada.db.profile.prepotion and event == "COMBAT_ENCOUNTER_START" then
			prepotion = {}
			local prefix, min, max = "raid", 1, _GetNumRaidMembers()
			if max == 0 then
				prefix, min, max = "party", 0, _GetNumPartyMembers()
			end

			for n = min, max do
				local unit = (n == 0) and "player" or prefix .. _tostring(n)
				if _UnitExists(unit) and not _UnitIsDeadOrGhost(unit) then
					local playerid, playername = _UnitGUID(unit), _UnitName(unit)
					local class = _select(2, _UnitClass(unit))
					for i = 1, 32 do
						local _, _, icon, _, _, _, _, _, _, _, spellid = _UnitBuff(unit, i)
						if spellid and potionIDs[spellid] then
							-- instant recording doesn't work, so we delay it
							Skada.After(1, function() PotionUsed(nil, nil, playerid, playername, nil, nil, nil, nil, spellid) end)

							-- add to print out:
							if class and Skada.validclass[class] then
								local colorStr = Skada.classcolors[class].colorStr or "ffffffff"
								tinsert(prepotion, _format(prepottStr, colorStr, playername, icon))
							end

							break -- beause we can only have a single potion
						end
					end
				end
			end
		end
	end

	function playersmod:Enter(win, id, label)
		win.potionid, win.potionname = id, label
		win.title = label
	end

	function playersmod:Update(win, set)
		local max = 0

		if win.potionid then
			win.title = win.potionname

			local nr, total, players = 1, 0, {}

			for _, player in _ipairs(set.players) do
				if player.potions and player.potions.potions[win.potionid] then
					local count = player.potions.potions[win.potionid]
					total = total + count
					players[player.name] = {
						id = player.id,
						class = player.class,
						role = player.role,
						spec = player.spec,
						count = count
					}
				end
			end

			for playername, player in _pairs(players) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = playername
				d.class = player.class
				d.role = player.role
				d.spec = player.spec

				d.value = player.count
				d.valuetext = Skada:FormatValueText(
					player.count,
					mod.metadata.columns.Count,
					_format("%02.1f%%", 100 * player.count / math_max(1, total)),
					mod.metadata.columns.Percent
				)

				if player.count > max then
					max = player.count
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	function potionsmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's used potions"], label)
	end

	local function RequestPotion(potionid)
		if potionid and potionid ~= nil and potionid ~= "" and potionid ~= 0 and _strsub(potionid, 1, 1) ~= "s" then
			GameTooltip:SetHyperlink("item:" .. potionid .. ":0:0:0:0:0:0:0")
			GameTooltip:Hide()
		end
	end

	function potionsmod:Update(win, set)
		local max = 0
		local player = Skada:find_player(set, win.playerid)

		if player and player.potions.potions then
			win.title = _format(L["%s's used potions"], player.name)

			local nr = 1
			for potionid, count in _pairs(player.potions.potions) do
				local potionname, potionlink, _, _, _, _, _, _, _, potionicon = _GetItemInfo(potionid)
				if not potionname then
					RequestPotion(potionid)
				end

				if potionname then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = potionid
					d.hyperlink = potionlink
					d.label = potionname
					d.icon = potionicon

					d.value = count
					d.valuetext = Skada:FormatValueText(
						count,
						mod.metadata.columns.Count,
						_format("%02.1f%%", 100 * count / math_max(1, player.potions.count)),
						mod.metadata.columns.Percent
					)

					if count > max then
						max = count
					end

					nr = nr + 1
				end
			end
		end

		win.metadata.maxvalue = max
	end

	function mod:Update(win, set)
		local max = 0

		if set and set.potions then
			local nr, total = 1, set.potions

			for _, player in _ipairs(set.players) do
				if player.potions and player.potions.count > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.class = player.class or "PET"
					d.role = player.role or "DAMAGER"
					d.spec = player.spec or 1

					d.value = player.potions.count
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
		win.title = L["Potions"]
	end

	function mod:OnInitialize()
		if Skada.db.profile.prepotion == nil then
			Skada.db.profile.prepotion = true
		end

		Skada.options.args.generaloptions.args.prepotion = {
			type = "toggle",
			name = L["Pre-potion"],
			order = 94
		}
	end

	function mod:OnEnable()
		playersmod.metadata = {}
		potionsmod.metadata = {click1 = playersmod}
		self.metadata = {
			showspots = true,
			click1 = potionsmod,
			columns = {Count = true, Percent = true}
		}
		Skada:RegisterForCL(PotionUsed, "SPELL_CAST_SUCCESS", {src_is_interesting_nopets = true})
		Skada.RegisterCallback(self, "COMBAT_ENCOUNTER_START", "CheckPrePot")
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return set.potions or 0
	end

	function mod:SetComplete(set)
		if Skada.db.profile.prepotion and next(prepotion) ~= nil then
			Skada:Print(_format("pre-potion: %s", tconcat(prepotion, ", ")))
			prepotion = {}
		end
	end
end)