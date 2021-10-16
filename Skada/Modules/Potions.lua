assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Potions", function(Skada, L)
	if Skada:IsDisabled("Potions") then return end

	local mod = Skada:NewModule(L["Potions"])
	local playermod = mod:NewModule(L["Potions list"])
	local potionmod = mod:NewModule(L["Players list"])

	-- cache frequently used globals
	local pairs, ipairs, select, tconcat = pairs, ipairs, select, table.concat
	local format, strsub, tostring = string.format, string.sub, tostring
	local GetItemInfo, GetSpellInfo, After = GetItemInfo, Skada.GetSpellInfo, Skada.After
	local GroupIterator = Skada.GroupIterator
	local UnitExists, UnitIsDeadOrGhost = UnitExists, UnitIsDeadOrGhost
	local UnitGUID, UnitName = UnitGUID, UnitName
	local UnitClass, UnitBuff = UnitClass, UnitBuff
	local newTable, delTable = Skada.newTable, Skada.delTable
	local _

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

	local prepotionStr, potionStr = "|c%s%s|r %s", "|T%s:14:14:1:-2:64:64:2:62:2:62|t"
	local prepotion

	local function log_potion(set, playerid, playername, playerflags, spellid)
		local player = Skada:get_player(set, playerid, playername, playerflags)
		if player then
			-- record potion usage for player and set
			player.potion = (player.potion or 0) + 1
			set.potion = (set.potion or 0) + 1

			-- record the potion
			if spellid then
				local potionid = potionIDs[spellid]
				player.potion_spells = player.potion_spells or {}
				player.potion_spells[potionid] = (player.potion_spells[potionid] or 0) + 1
			end
		end
	end

	local function PotionUsed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...
		if spellid and potionIDs[spellid] then
			log_potion(Skada.current, srcGUID, srcName, srcFlags, spellid)
			log_potion(Skada.total, srcGUID, srcName, srcFlags, spellid)
		end
	end

	do
		local function CheckUnitPotions(unit, owner, prepot)
			if owner == nil and not UnitIsDeadOrGhost(unit) then
				local playerid, playername = UnitGUID(unit), UnitName(unit)
				local class = select(2, UnitClass(unit))

				local potions = newTable() -- holds used potions
				for potionid, _ in pairs(potionIDs) do
					local icon, _, _, _, _, _, _, _, spellid = select(3, UnitBuff(unit, GetSpellInfo(potionid)))
					if spellid and potionIDs[spellid] then
						-- instant recording doesn't work, so we delay it
						After(1, function() PotionUsed(nil, nil, playerid, playername, nil, nil, nil, nil, spellid) end)
						tinsert(potions, format(potionStr, icon))
					end
				end

				-- add to print out:
				if next(potions) ~= nil and class and Skada.validclass[class] then
					local colorStr = Skada.classcolors[class].colorStr or "ffffffff"
					tinsert(prepotion, format(prepotionStr, colorStr, playername, tconcat(potions, " ")))
				end
				delTable(potions)
			end
		end

		-- we use this function to record pre-pots as well.
		function mod:CheckPrePot(event)
			if event == "COMBAT_PLAYER_ENTER" then
				prepotion = newTable()
				GroupIterator(CheckUnitPotions, prepotion)
			end
		end
	end

	function potionmod:Enter(win, id, label)
		win.potionid, win.potionname = id, label
		win.title = label
	end

	function potionmod:Update(win, set)
		win.title = win.potionname or UNKNOWN

		local total, players = 0, newTable()
		if win.potionid then
			for _, player in ipairs(set.players) do
				if player.potion_spells and player.potion_spells[win.potionid] then
					total = total + player.potion_spells[win.potionid]
					players[player.id] = {
						name = player.name,
						class = player.class,
						role = player.role,
						spec = player.spec,
						count = player.potion_spells[win.potionid]
					}
				end
			end
		end

		if total > 0 then
			local maxvalue, nr = 0, 1

			for playerid, player in pairs(players) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = playerid
				d.label = player.name
				d.text = Skada:FormatName(player.name, player.id)
				d.class = player.class
				d.role = player.role
				d.spec = player.spec

				d.value = player.count
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

		delTable(players)
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's used potions"], label)
	end

	local function RequestPotion(potionid)
		if potionid and potionid ~= nil and potionid ~= "" and potionid ~= 0 and strsub(potionid, 1, 1) ~= "s" then
			GameTooltip:SetHyperlink("item:" .. potionid .. ":0:0:0:0:0:0:0")
			GameTooltip:Hide()
		end
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)
		if player then
			win.title = format(L["%s's used potions"], player.name)
			local total = player.potion or 0

			if total > 0 and player.potion_spells then
				local maxvalue, nr = 0, 1

				for potionid, count in pairs(player.potion_spells) do
					local potionname, potionlink, _, _, _, _, _, _, _, potionicon = GetItemInfo(potionid)
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
	end

	function mod:Update(win, set)
		win.title = L["Potions"]
		local total = set.potion or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.potion or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.potion
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

	function mod:OnInitialize()
		if Skada.db.profile.prepotion == nil then
			Skada.db.profile.prepotion = true
		end

		if Skada.options.args.Tweaks then
			Skada.options.args.Tweaks.args.prepotion = {
				type = "toggle",
				name = L["Pre-potion"],
				desc = L["Prints pre-potion after the end of the combat."],
				order = 0
			}
		else
			Skada.options.args.generaloptions.args.prepotion = {
				type = "toggle",
				name = L["Pre-potion"],
				desc = L["Prints pre-potion after the end of the combat."],
				order = 94
			}
		end
	end

	function mod:OnEnable()
		potionmod.metadata = {click1 = playermod}
		playermod.metadata = {click1 = potionmod}
		self.metadata = {
			showspots = true,
			click1 = playermod,
			columns = {Count = true, Percent = true},
			icon = "Interface\\Icons\\inv_potion_110"
		}

		Skada:RegisterForCL(PotionUsed, "SPELL_CAST_SUCCESS", {src_is_interesting_nopets = true})
		Skada.RegisterCallback(self, "COMBAT_PLAYER_ENTER", "CheckPrePot")
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return set.potion or 0
	end

	function mod:SetComplete(set)
		if Skada.db.profile.prepotion and next(prepotion or {}) ~= nil then
			Skada:Printf(L["pre-potion: %s"], tconcat(prepotion, ", "))
		end

		delTable(prepotion)
	end
end)