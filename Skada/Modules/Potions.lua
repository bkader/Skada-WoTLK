local _, Skada = ...
Skada:RegisterModule("Potions", function(L, P, _, C)
	local mod = Skada:NewModule("Potions")
	local playermod = mod:NewModule("Potions list")
	local potionmod = mod:NewModule("Players list")
	local get_actors_by_potion = nil

	-- cache frequently used globals
	local pairs, tconcat, format, strsub = pairs, table.concat, string.format, string.sub
	local GetItemInfo, UnitIsDeadOrGhost, GroupIterator = GetItemInfo, UnitIsDeadOrGhost, Skada.GroupIterator
	local UnitGUID, UnitName, UnitClass, UnitBuff = UnitGUID, UnitName, UnitClass, UnitBuff
	local new, del, clear = Skada.newTable, Skada.delTable, Skada.clearTable
	local T, pformat = Skada.Table, Skada.pformat
	local potion_ids = {}
	local mod_cols = nil

	local prepotionStr, potionStr = "\124c%s%s\124r %s", "\124T%s:14:14:0:0:64:64:4:60:4:60\124t"
	local prepotion

	local function format_valuetext(d, columns, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			columns.Count and d.value,
			columns[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_potion(set, playerid, playername, playerflags, spellid)
		local player = Skada:GetPlayer(set, playerid, playername, playerflags)
		if not player then return end

		-- record potion usage for player and set
		player.potion = (player.potion or 0) + 1
		set.potion = (set.potion or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not spellid then return end

		local potionid = potion_ids[spellid]
		player.potionspells = player.potionspells or {}
		player.potionspells[potionid] = (player.potionspells[potionid] or 0) + 1
	end

	local function potion_used(_, _, srcGUID, srcName, srcFlags, _, _, _, spellid)
		if spellid and potion_ids[spellid] then
			Skada:DispatchSets(log_potion, srcGUID, srcName, srcFlags, spellid)
		end
	end

	do
		local function check_unit_potions(unit, owner, prepot)
			if owner or UnitIsDeadOrGhost(unit) then return end

			local playerid, playername = UnitGUID(unit), UnitName(unit)
			local _, class = UnitClass(unit)

			local potions = nil
			for i = 1, 40 do
				local _, _, icon, _, _, _, _, _, _, _, spellid = UnitBuff(unit, i)
				if not spellid then
					break -- nothing found
				elseif potion_ids[spellid] then
					potions = potions or new()
					-- instant recording doesn't work, so we delay it
					Skada:ScheduleTimer(function() potion_used(nil, nil, playerid, playername, nil, nil, nil, nil, spellid) end, 1)
					potions[#potions + 1] = format(potionStr, icon)
				end
			end

			if not potions then
				return
			elseif next(potions) ~= nil and class and Skada.validclass[class] then
				prepot[#prepot + 1] = format(prepotionStr, Skada.classcolors(class, true), playername, tconcat(potions, " "))
			end
			del(potions)
		end

		-- we use this function to record pre-pots as well.
		function mod:CombatEnter()
			if P.prepotion and not self.checked then
				prepotion = prepotion or T.get("Potions_PrePotions")
				GroupIterator(check_unit_potions, prepotion)
				self.checked = true
			end
		end

		function mod:CombatLeave()
			if prepotion then
				if P.prepotion and next(prepotion) ~= nil then
					Skada:Printf(L["pre-potion: %s"], tconcat(prepotion, ", "))
				end
				T.free("Potions_PrePotions", prepotion)
				self.checked = nil
			end
		end
	end

	function potionmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = label
	end

	function potionmod:Update(win, set)
		win.title = win.spellname or L["Unknown"]
		if win.class then
			win.title = format("%s (%s)", win.title, L[win.class])
		end

		if not set or not win.spellname then return end

		local total, actors = get_actors_by_potion(set, win.spellid, win.class)
		if total == 0 or not actors then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for actorname, actor in pairs(actors) do
			nr = nr + 1

			local d = win:actor(nr, actor, nil, actorname)
			d.value = actor.count
			format_valuetext(d, mod_cols, total, win.metadata, true)
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's used potions"], label)
	end

	local function request_potion(potionid)
		if potionid and potionid ~= nil and potionid ~= "" and potionid ~= 0 and strsub(potionid, 1, 1) ~= "s" then
			GameTooltip:SetHyperlink("item:" .. potionid .. ":0:0:0:0:0:0:0")
			GameTooltip:Hide()
		end
	end

	function playermod:Update(win, set)
		win.title = pformat(L["%s's used potions"], win.actorname)
		if not set or not win.actorname then return end

		local actor = Skada:FindPlayer(set, win.actorid, win.actorname, true)
		local total = actor and actor.potion
		local potions = (total and total > 0) and actor.potionspells

		if not potions then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for potionid, count in pairs(potions) do
			local potionname, potionlink, _, _, _, _, _, _, _, potionicon = GetItemInfo(potionid)
			if not potionname then
				request_potion(potionid)
			end

			if potionname then
				nr = nr + 1
				local d = win:nr(nr)

				d.id = potionid
				d.hyperlink = potionlink
				d.label = potionname
				d.icon = potionicon

				d.value = count
				format_valuetext(d, mod_cols, total, win.metadata, true)
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Potions"], L[win.class]) or L["Potions"]

		local total = set and set:GetTotal(win.class, nil, "potion")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0

		local actors = set.players -- players
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor.potion and (not win.class or win.class == actor.class) then
				nr = nr + 1

				local d = win:actor(nr, actor)
				d.value = actor.potion
				format_valuetext(d, mod_cols, total, win.metadata)
			end
		end
	end

	function mod:GetSetSummary(set, win)
		if not set then return end
		return set:GetTotal(win and win.class, nil, "potion") or 0
	end

	function mod:OnInitialize()
		-- list of potion: [spellid] = potionid

		--[[ level NaN ]]--
		potion_ids[439] = 118 -- Minor Healing Potion
		potion_ids[6724] = 5816 -- Light of Elune
		potion_ids[29236] = 3087 -- Mug of Shimmer Stout
		potion_ids[47430] = 36770 -- Zort's Protective Elixir
		potion_ids[50809] = 38351 -- Murliver Oil

		--[[ level 03-17 ]]--
		potion_ids[437] = 2455 -- Minor Mana Potion
		potion_ids[438] = 3385 -- Lesser Mana Potion
		potion_ids[440] = 4596 -- Discolored Healing Potion
		potion_ids[441] = 929 -- Healing Potion
		potion_ids[2370] = 2456 -- Minor Rejuvenation Potion
		potion_ids[2379] = 2459 -- Swiftness Potion
		potion_ids[2380] = 3384 -- Minor Magic Resistance Potion
		potion_ids[6612] = 5631 -- Rage Potion
		potion_ids[6612] = 858 -- Lesser Healing Potion
		potion_ids[6614] = 5632 -- Cowardly Flight Potion
		potion_ids[7242] = 6048 -- Shadow Protection Potion
		potion_ids[7245] = 6051 -- Holy Protection Potion
		potion_ids[7840] = 6372 -- Swim Speed Potion
		potion_ids[26677] = 3386 -- Potion of Curing

		--[[ level 20-28 ]]--
		potion_ids[2023] = 3827 -- Mana Potion
		potion_ids[2024] = 1710 -- Greater Healing Potion
		potion_ids[3592] = 2633 -- Jungle Remedy
		potion_ids[3680] = 3823 -- Lesser Invisibility Potion
		potion_ids[6613] = 5633 -- Great Rage Potion
		potion_ids[6615] = 5634 -- Free Action Potion
		potion_ids[7233] = 6049 -- Fire Protection Potion
		potion_ids[7239] = 6050 -- Frost Protection Potion
		potion_ids[7254] = 6052 -- Nature Protection Potion

		--[[ level 31-37 ]]--
		potion_ids[4042] = 3928 -- Superior Healing Potion
		potion_ids[4941] = 4623 -- Lesser Stoneshield Potion
		potion_ids[11359] = 9030 -- Restorative Potion
		potion_ids[11364] = 9036 -- Magic Resistance Potion
		potion_ids[11387] = 9144 -- Wildvine Potion
		potion_ids[11392] = 9172 -- Invisibility Potion
		potion_ids[11903] = 6149 -- Greater Mana Potion
		potion_ids[15822] = 12190 -- Dreamless Sleep Potion
		potion_ids[21394] = 17349 -- Superior Healing Draught
		potion_ids[21396] = 17352 -- Superior Mana Draught

		--[[ level 41-49 ]]--
		potion_ids[3169] = 3387 -- Limited Invulnerability Potion
		potion_ids[17528] = 13442 -- Mighty Rage Potion
		potion_ids[17530] = 13443 -- Superior Mana Potion
		potion_ids[17540] = 13455 -- Greater Stoneshield Potion
		potion_ids[17543] = 13457 -- Greater Fire Protection Potion
		potion_ids[17544] = 13456 -- Greater Frost Protection Potion
		potion_ids[17545] = 13460 -- Greater Holy Protection Potion
		potion_ids[17546] = 13458 -- Greater Nature Protection Potion
		potion_ids[17548] = 13459 -- Greater Shadow Protection Potion
		potion_ids[17549] = 13461 -- Greater Arcane Protection Potion
		potion_ids[17550] = 13462 -- Purification Potion
		potion_ids[21393] = 17348 -- Major Healing Draught
		potion_ids[21395] = 17351 -- Major Mana Draught
		potion_ids[24364] = 20008 -- Living Action Potion

		--[[ level 50-55 ]]--
		potion_ids[17624] = 13506 -- Flask of Petrification
		potion_ids[22729] = 18253 -- Major Rejuvenation Potion
		potion_ids[24360] = 20002 -- Greater Dreamless Sleep Potion
		potion_ids[28492] = 22826 -- Sneaking Potion
		potion_ids[28548] = 22871 -- Shrouding Potion
		potion_ids[41617] = 32903 -- Cenarion Mana Salve
		potion_ids[41618] = 32902 -- Bottled Nethergon Energy
		potion_ids[41619] = 32904 -- Cenarion Healing Salve
		potion_ids[41620] = 32905 -- Bottled Nethergon Vapor
		potion_ids[52697] = 39327 -- Noth's Special Brew
		potion_ids[67486] = 33092 -- Healing Potion Injector
		potion_ids[67487] = 33093 -- Mana Potion Injector

		--[[ level 60-65 ]]--
		potion_ids[17531] = 31840 -- Major Combat Mana Potion
		potion_ids[17534] = 31838 -- Major Combat Healing Potion
		potion_ids[28504] = 22836 -- Major Dreamless Sleep Potion
		potion_ids[28506] = 22837 -- Heroic Potion
		potion_ids[28507] = 22838 -- Haste Potion
		potion_ids[28508] = 22839 -- Destruction Potion
		potion_ids[28511] = 22841 -- Major Fire Protection Potion
		potion_ids[28512] = 22842 -- Major Frost Protection Potion
		potion_ids[28513] = 22844 -- Major Nature Protection Potion
		potion_ids[28515] = 22849 -- Ironshield Potion
		potion_ids[28517] = 22850 -- Super Rejuvenation Potion
		potion_ids[28536] = 22845 -- Major Arcane Protection Potion
		potion_ids[28537] = 22846 -- Major Shadow Protection Potion
		potion_ids[28538] = 22847 -- Major Holy Protection Potion
		potion_ids[38908] = 31676 -- Fel Regeneration Potion
		potion_ids[45051] = 34440 -- Mad Alchemist's Potion

		--[[ level 70 ]]--
		potion_ids[28494] = 22828 -- Insane Strength Potion
		potion_ids[28495] = 43569 -- Endless Healing Potion
		potion_ids[28499] = 43570 -- Endless Mana Potion
		potion_ids[38929] = 31677 -- Fel mana potion
		potion_ids[41304] = 32783 -- Blue Ogre Brew
		potion_ids[41306] = 32784 -- Red Ogre Brew
		potion_ids[43185] = 33447 -- Healing Potion
		potion_ids[43186] = 33448 -- Restore Mana
		potion_ids[53750] = 40077 -- Crazy Alchemist's Potion
		potion_ids[53753] = 40081 -- Nightmare Slumber
		potion_ids[53761] = 40087 -- Powerful Rejuvenation Potion
		potion_ids[53762] = 40093 -- Indestructible
		potion_ids[53908] = 40211 -- Potion of Speed
		potion_ids[53909] = 40212 -- Potion of Wild Magic
		potion_ids[53910] = 40213 -- Arcane Protection
		potion_ids[53911] = 40214 -- Fire Protection
		potion_ids[53913] = 40215 -- Frost Protection
		potion_ids[53914] = 40216 -- Nature Protection
		potion_ids[53915] = 40217 -- Shadow Protection
		potion_ids[61371] = 44728 -- Endless Rejuvenation Potion
		potion_ids[67489] = 41166 -- Runic Healing Injector
		potion_ids[67490] = 42545 -- Runic Mana Injector

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
			Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER", "CombatEnter")
			Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
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

		mod_cols = self.metadata.columns

		-- no total click.
		playermod.nototal = true

		Skada:RegisterForCL(potion_used, "SPELL_CAST_SUCCESS", {src_is_interesting_nopets = true})
		Skada.RegisterCallback(self, "Skada_ApplySettings", "ApplySettings")
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	---------------------------------------------------------------------------

	get_actors_by_potion = function(self, potionid, class, tbl)
		local total = 0
		if not self.potion or not potionid then
			return total
		end

		tbl = clear(tbl or C)

		local actors = self.players -- players
		for i = 1, #actors do
			local a = actors[i]
			if a and a.potionspells and a.potionspells[potionid] and (not class or class == a.class) then
				total = total + a.potionspells[potionid]
				tbl[a.name] = new()
				tbl[a.name].id = a.id
				tbl[a.name].class = a.class
				tbl[a.name].role = a.role
				tbl[a.name].spec = a.spec
				tbl[a.name].count = a.potionspells[potionid]
			end
		end

		return total, tbl
	end
end)
