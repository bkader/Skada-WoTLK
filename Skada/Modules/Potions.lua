local Skada = Skada
Skada:AddLoadableModule("Potions", function(L)
	if Skada:IsDisabled("Potions") then return end

	local mod = Skada:NewModule(L["Potions"])
	local playermod = mod:NewModule(L["Potions list"])
	local potionmod = mod:NewModule(L["Players list"])

	-- cache frequently used globals
	local pairs, ipairs, select, tconcat = pairs, ipairs, select, table.concat
	local format, strsub, tostring = string.format, string.sub, tostring
	local GetItemInfo, GetSpellInfo = GetItemInfo, Skada.GetSpellInfo or GetSpellInfo
	local GroupIterator = Skada.GroupIterator
	local UnitExists, UnitIsDeadOrGhost = UnitExists, UnitIsDeadOrGhost
	local UnitGUID, UnitName = UnitGUID, UnitName
	local UnitClass, UnitBuff = UnitClass, UnitBuff
	local new, del = Skada.TablePool()
	local T = Skada.Table
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

	local prepotionStr, potionStr = "|c%s%s|r %s", "|T%s:14:14:1:-2:32:32:2:30:2:30|t"
	local prepotion

	local function log_potion(set, playerid, playername, playerflags, spellid)
		local player = Skada:GetPlayer(set, playerid, playername, playerflags)
		if player then
			-- record potion usage for player and set
			player.potion = (player.potion or 0) + 1
			set.potion = (set.potion or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set ~= Skada.total then
				local potionid = potionIDs[spellid]
				player.potionspells = player.potionspells or {}
				player.potionspells[potionid] = (player.potionspells[potionid] or 0) + 1
			end
		end
	end

	local function PotionUsed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid = ...
		if spellid and potionIDs[spellid] then
			Skada:DispatchSets(log_potion, srcGUID, srcName, srcFlags, spellid)
			log_potion(Skada.total, srcGUID, srcName, srcFlags, spellid)
		end
	end

	do
		local function CheckUnitPotions(unit, owner, prepot)
			if owner == nil and not UnitIsDeadOrGhost(unit) then
				local playerid, playername = UnitGUID(unit), UnitName(unit)
				local class = select(2, UnitClass(unit))

				local potions = new()
				for potionid, _ in pairs(potionIDs) do
					local icon, _, _, _, _, _, _, _, spellid = select(3, UnitBuff(unit, GetSpellInfo(potionid)))
					if spellid and potionIDs[spellid] then
						-- instant recording doesn't work, so we delay it
						Skada:ScheduleTimer(function() PotionUsed(nil, nil, playerid, playername, nil, nil, nil, nil, spellid) end, 1)
						potions[#potions + 1] = format(potionStr, icon)
					end
				end

				-- add to print out:
				if next(potions) ~= nil and class and Skada.validclass[class] then
					local colorStr = Skada.classcolors[class].colorStr or "ffffffff"
					prepot[#prepot + 1] = format(prepotionStr, colorStr, playername, tconcat(potions, " "))
				end
				del(potions)
			end
		end

		-- we use this function to record pre-pots as well.
		function mod:CheckPrePot(event)
			if event == "COMBAT_PLAYER_ENTER" then
				prepotion = prepotion or T.get("Potions_PrePotions")
				GroupIterator(CheckUnitPotions, prepotion)
			end
		end
	end

	function potionmod:Enter(win, id, label)
		win.potionid, win.potionname = id, label
		win.title = label
	end

	function potionmod:Update(win, set)
		win.title = win.potionname or L.Unknown
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		if not (set and win.potionname) then return end

		local players, total = set:GetPotion(win.potionid, win.class)
		if players and total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for playername, player in pairs(players) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id or playername
				d.label = playername
				d.text = player.id and Skada:FormatName(playername, player.id)
				d.class = player.class
				d.role = player.role
				d.spec = player.spec

				d.value = player.count
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Count and d.value,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's used potions"], label)
	end

	local function RequestPotion(potionid)
		if potionid and potionid ~= nil and potionid ~= "" and potionid ~= 0 and strsub(potionid, 1, 1) ~= "s" then
			GameTooltip:SetHyperlink("item:" .. potionid .. ":0:0:0:0:0:0:0")
			GameTooltip:Hide()
		end
	end

	function playermod:Update(win, set)
		local player = Skada:FindPlayer(set, win.actorid)
		if player then
			win.title = format(L["%s's used potions"], player.name)
			local total = player.potion or 0

			if total > 0 and player.potionspells then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for potionid, count in pairs(player.potionspells) do
					local potionname, potionlink, _, _, _, _, _, _, _, potionicon = GetItemInfo(potionid)
					if not potionname then
						RequestPotion(potionid)
					end

					if potionname then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = potionid
						d.hyperlink = potionlink
						d.label = potionname
						d.icon = potionicon

						d.value = count
						d.valuetext = Skada:FormatValueCols(
							mod.metadata.columns.Count and d.value,
							mod.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
						)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Potions"], L[win.class]) or L["Potions"]

		local total = set.potion or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.potion or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.potion
					d.valuetext = Skada:FormatValueCols(
						self.metadata.columns.Count and d.value,
						self.metadata.columns.Percent and Skada:FormatPercent(d.value, total)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:OnInitialize()
		if Skada.db.profile.prepotion == nil then
			Skada.db.profile.prepotion = true
		end

		Skada.options.args.tweaks.args.general.args.prepotion = {
			type = "toggle",
			name = L["Pre-potion"],
			desc = L["Prints pre-potion after the end of the combat."],
			order = 0
		}
	end

	function mod:OnEnable()
		potionmod.metadata = {
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"]
		}
		playermod.metadata = {click1 = potionmod}
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {playermod},
			columns = {Count = true, Percent = false},
			icon = [[Interface\Icons\inv_potion_31]]
		}

		Skada:RegisterForCL(PotionUsed, "SPELL_CAST_SUCCESS", {src_is_interesting_nopets = true})
		Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER", "CheckPrePot")
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return set.potion or 0
	end

	function mod:SetComplete(set)
		if Skada.db.profile.prepotion and next(prepotion or {}) ~= nil then
			Skada:Printf(L["pre-potion: %s"], tconcat(prepotion, ", "))
		end
		T.free("Potions_PrePotions", prepotion)
	end

	do
		local setPrototype = Skada.setPrototype
		local wipe = wipe

		function setPrototype:GetPotion(potionid, class, tbl)
			if potionid and self.potion then
				tbl = wipe(tbl or Skada.cacheTable)
				local total = 0

				for _, p in ipairs(self.players) do
					if (not class or class == p.class) and p.potionspells and p.potionspells[potionid] then
						total = total + p.potionspells[potionid]
						tbl[p.name] = {
							id = p.id,
							class = p.class,
							role = p.role,
							spec = p.spec,
							count = p.potionspells[potionid]
						}
					end
				end

				return tbl, total
			end
		end
	end
end)