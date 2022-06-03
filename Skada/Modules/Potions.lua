local Skada = Skada
Skada:RegisterModule("Potions", function(L, P)
	if Skada:IsDisabled("Potions") then return end

	local mod = Skada:NewModule("Potions")
	local playermod = mod:NewModule("Potions list")
	local potionmod = mod:NewModule("Players list")

	-- cache frequently used globals
	local pairs, tconcat, format, strsub, tostring = pairs, table.concat, string.format, string.sub, tostring
	local GetItemInfo, GetSpellInfo = GetItemInfo, Skada.GetSpellInfo or GetSpellInfo
	local UnitIsDeadOrGhost, GroupIterator = UnitIsDeadOrGhost, Skada.GroupIterator
	local UnitGUID, UnitName, UnitClass, UnitBuff = UnitGUID, UnitName, UnitClass, UnitBuff
	local new, del = Skada.newTable, Skada.delTable
	local T, potionIDs, _= Skada.Table, {}, nil

	local prepotionStr, potionStr = "\124c%s%s\124r %s", "\124T%s:14:14:1:-2:32:32:2:30:2:30\124t"
	local prepotion

	local function log_potion(set, playerid, playername, playerflags, spellid)
		local player = Skada:GetPlayer(set, playerid, playername, playerflags)
		if player then
			-- record potion usage for player and set
			player.potion = (player.potion or 0) + 1
			set.potion = (set.potion or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if (set ~= Skada.total or P.totalidc) and spellid then
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
		end
	end

	do
		local function CheckUnitPotions(unit, owner, prepot)
			if owner == nil and not UnitIsDeadOrGhost(unit) then
				local playerid, playername = UnitGUID(unit), UnitName(unit)
				local _, class = UnitClass(unit)

				local potions = new()
				for i = 1, 40 do
					local _, _, icon, _, _, _, _, _, _, _, spellid = UnitBuff(unit, i)
					if spellid then
						if potionIDs[spellid] then
							-- instant recording doesn't work, so we delay it
							Skada:ScheduleTimer(function() PotionUsed(nil, nil, playerid, playername, nil, nil, nil, nil, spellid) end, 1)
							potions[#potions + 1] = format(potionStr, icon)
						end
					else
						break -- nothing found
					end
				end

				-- add to print out:
				if next(potions) ~= nil and class and Skada.validclass[class] then
					prepot[#prepot + 1] = format(prepotionStr, Skada.classcolors(class, true), playername, tconcat(potions, " "))
				end
				del(potions)
			end
		end

		-- we use this function to record pre-pots as well.
		function mod:CheckPrePot(event)
			if event == "COMBAT_PLAYER_ENTER" and P.prepotion and not self.checked then
				prepotion = prepotion or T.get("Potions_PrePotions")
				GroupIterator(CheckUnitPotions, prepotion)
				self.checked = true
			end
		end
	end

	function potionmod:Enter(win, id, label)
		win.potionid, win.potionname = id, label
		win.title = label
	end

	function potionmod:Update(win, set)
		win.title = win.potionname or L["Unknown"]
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
				local d = win:nr(nr)

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
						local d = win:nr(nr)

						d.id = potionid
						d.hyperlink = potionlink
						d.label = potionname
						d.icon = potionicon

						d.value = count
						d.valuetext = Skada:FormatValueCols(
							mod.metadata.columns.Count and d.value,
							mod.metadata.columns.sPercent and Skada:FormatPercent(d.value, total)
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
			for i = 1, #set.players do
				local player = set.players[i]
				if player and player.potion and (not win.class or win.class == player.class) then
					nr = nr + 1
					local d = win:nr(nr)

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
		-- list of potion: [spellid] = potionid

		--[[ level NaN ]]--
		potionIDs[439] = 118 -- Minor Healing Potion
		potionIDs[6724] = 5816 -- Light of Elune
		potionIDs[29236] = 3087 -- Mug of Shimmer Stout
		potionIDs[47430] = 36770 -- Zort's Protective Elixir
		potionIDs[50809] = 38351 -- Murliver Oil

		--[[ level 03-17 ]]--
		potionIDs[437] = 2455 -- Minor Mana Potion
		potionIDs[438] = 3385 -- Lesser Mana Potion
		potionIDs[440] = 4596 -- Discolored Healing Potion
		potionIDs[441] = 929 -- Healing Potion
		potionIDs[2370] = 2456 -- Minor Rejuvenation Potion
		potionIDs[2379] = 2459 -- Swiftness Potion
		potionIDs[2380] = 3384 -- Minor Magic Resistance Potion
		potionIDs[6612] = 5631 -- Rage Potion
		potionIDs[6612] = 858 -- Lesser Healing Potion
		potionIDs[6614] = 5632 -- Cowardly Flight Potion
		potionIDs[7242] = 6048 -- Shadow Protection Potion
		potionIDs[7245] = 6051 -- Holy Protection Potion
		potionIDs[7840] = 6372 -- Swim Speed Potion
		potionIDs[26677] = 3386 -- Potion of Curing

		--[[ level 20-28 ]]--
		potionIDs[2023] = 3827 -- Mana Potion
		potionIDs[2024] = 1710 -- Greater Healing Potion
		potionIDs[3592] = 2633 -- Jungle Remedy
		potionIDs[3680] = 3823 -- Lesser Invisibility Potion
		potionIDs[6613] = 5633 -- Great Rage Potion
		potionIDs[6615] = 5634 -- Free Action Potion
		potionIDs[7233] = 6049 -- Fire Protection Potion
		potionIDs[7239] = 6050 -- Frost Protection Potion
		potionIDs[7254] = 6052 -- Nature Protection Potion

		--[[ level 31-37 ]]--
		potionIDs[4042] = 3928 -- Superior Healing Potion
		potionIDs[4941] = 4623 -- Lesser Stoneshield Potion
		potionIDs[11359] = 9030 -- Restorative Potion
		potionIDs[11364] = 9036 -- Magic Resistance Potion
		potionIDs[11387] = 9144 -- Wildvine Potion
		potionIDs[11392] = 9172 -- Invisibility Potion
		potionIDs[11903] = 6149 -- Greater Mana Potion
		potionIDs[15822] = 12190 -- Dreamless Sleep Potion
		potionIDs[21394] = 17349 -- Superior Healing Draught
		potionIDs[21396] = 17352 -- Superior Mana Draught

		--[[ level 41-49 ]]--
		potionIDs[3169] = 3387 -- Limited Invulnerability Potion
		potionIDs[17528] = 13442 -- Mighty Rage Potion
		potionIDs[17530] = 13443 -- Superior Mana Potion
		potionIDs[17540] = 13455 -- Greater Stoneshield Potion
		potionIDs[17543] = 13457 -- Greater Fire Protection Potion
		potionIDs[17544] = 13456 -- Greater Frost Protection Potion
		potionIDs[17545] = 13460 -- Greater Holy Protection Potion
		potionIDs[17546] = 13458 -- Greater Nature Protection Potion
		potionIDs[17548] = 13459 -- Greater Shadow Protection Potion
		potionIDs[17549] = 13461 -- Greater Arcane Protection Potion
		potionIDs[17550] = 13462 -- Purification Potion
		potionIDs[21393] = 17348 -- Major Healing Draught
		potionIDs[21395] = 17351 -- Major Mana Draught
		potionIDs[24364] = 20008 -- Living Action Potion

		--[[ level 50-55 ]]--
		potionIDs[17624] = 13506 -- Flask of Petrification
		potionIDs[22729] = 18253 -- Major Rejuvenation Potion
		potionIDs[24360] = 20002 -- Greater Dreamless Sleep Potion
		potionIDs[28492] = 22826 -- Sneaking Potion
		potionIDs[28548] = 22871 -- Shrouding Potion
		potionIDs[41617] = 32903 -- Cenarion Mana Salve
		potionIDs[41618] = 32902 -- Bottled Nethergon Energy
		potionIDs[41619] = 32904 -- Cenarion Healing Salve
		potionIDs[41620] = 32905 -- Bottled Nethergon Vapor
		potionIDs[52697] = 39327 -- Noth's Special Brew
		potionIDs[67486] = 33092 -- Healing Potion Injector
		potionIDs[67487] = 33093 -- Mana Potion Injector

		--[[ level 60-65 ]]--
		potionIDs[17531] = 31840 -- Major Combat Mana Potion
		potionIDs[17534] = 31838 -- Major Combat Healing Potion
		potionIDs[28504] = 22836 -- Major Dreamless Sleep Potion
		potionIDs[28506] = 22837 -- Heroic Potion
		potionIDs[28507] = 22838 -- Haste Potion
		potionIDs[28508] = 22839 -- Destruction Potion
		potionIDs[28511] = 22841 -- Major Fire Protection Potion
		potionIDs[28512] = 22842 -- Major Frost Protection Potion
		potionIDs[28513] = 22844 -- Major Nature Protection Potion
		potionIDs[28515] = 22849 -- Ironshield Potion
		potionIDs[28517] = 22850 -- Super Rejuvenation Potion
		potionIDs[28536] = 22845 -- Major Arcane Protection Potion
		potionIDs[28537] = 22846 -- Major Shadow Protection Potion
		potionIDs[28538] = 22847 -- Major Holy Protection Potion
		potionIDs[38908] = 31676 -- Fel Regeneration Potion
		potionIDs[45051] = 34440 -- Mad Alchemist's Potion

		--[[ level 70 ]]--
		potionIDs[28494] = 22828 -- Insane Strength Potion
		potionIDs[28495] = 43569 -- Endless Healing Potion
		potionIDs[28499] = 43570 -- Endless Mana Potion
		potionIDs[38929] = 31677 -- Fel mana potion
		potionIDs[41304] = 32783 -- Blue Ogre Brew
		potionIDs[41306] = 32784 -- Red Ogre Brew
		potionIDs[43185] = 33447 -- Healing Potion
		potionIDs[43186] = 33448 -- Restore Mana
		potionIDs[53750] = 40077 -- Crazy Alchemist's Potion
		potionIDs[53753] = 40081 -- Nightmare Slumber
		potionIDs[53761] = 40087 -- Powerful Rejuvenation Potion
		potionIDs[53762] = 40093 -- Indestructible
		potionIDs[53908] = 40211 -- Potion of Speed
		potionIDs[53909] = 40212 -- Potion of Wild Magic
		potionIDs[53910] = 40213 -- Arcane Protection
		potionIDs[53911] = 40214 -- Fire Protection
		potionIDs[53913] = 40215 -- Frost Protection
		potionIDs[53914] = 40216 -- Nature Protection
		potionIDs[53915] = 40217 -- Shadow Protection
		potionIDs[61371] = 44728 -- Endless Rejuvenation Potion
		potionIDs[67489] = 41166 -- Runic Healing Injector
		potionIDs[67490] = 42545 -- Runic Mana Injector

		-- don't edit below unless you know what you're doing.
		if P.prepotion == nil then
			P.prepotion = true
		end

		Skada.options.args.tweaks.args.general.args.prepotion = {
			type = "toggle",
			name = L["Pre-potion"],
			desc = L["Prints pre-potion after the end of the combat."],
			order = 0
		}
	end

	function mod:ApplySettings()
		if P.prepotion then
			Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER", "CheckPrePot")
		else
			Skada.UnregisterAllMessages(self)
		end
	end

	function mod:OnEnable()
		potionmod.metadata = {
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"]
		}
		playermod.metadata = {click1 = potionmod}
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = playermod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\Icons\inv_potion_31]]
		}

		-- no total click.
		playermod.nototal = true

		Skada:RegisterForCL(PotionUsed, "SPELL_CAST_SUCCESS", {src_is_interesting_nopets = true})
		Skada.RegisterCallback(self, "Skada_ApplySettings", "ApplySettings")
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local potions = set.potion or 0
		return tostring(potions), potions
	end

	function mod:SetComplete(set)
		if prepotion then
			if P.prepotion and next(prepotion) ~= nil then
				Skada:Printf(L["pre-potion: %s"], tconcat(prepotion, ", "))
			end
			T.free("Potions_PrePotions", prepotion)
			self.checked = nil
		end
	end

	do
		local setPrototype = Skada.setPrototype
		local wipe = wipe

		function setPrototype:GetPotion(potionid, class, tbl)
			if potionid and self.potion then
				tbl = wipe(tbl or Skada.cacheTable)
				local total = 0

				for i = 1, #self.players do
					local p = self.players[i]
					if p and p.potionspells and p.potionspells[potionid] and (not class or class == p.class) then
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