local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Potions", function(L, P, G, C, _, O)
	local mode = Skada:NewModule("Potions")
	local mode_spell = mode:NewModule("Spell List")
	local mode_actor = mode_spell:NewModule("Target List")
	local get_actors_by_potion = nil
	local mode_cols = nil

	local pairs, format, strsub, uformat = pairs, string.format, string.sub, Private.uformat
	local GetItemInfo, classcolors, classfmt = GetItemInfo, Skada.classcolors, Skada.classcolors.format
	local new, del, clear = Private.newTable, Private.delTable, Private.clearTable
	local prepotionStr, potionStr = "\124c%s%s\124r %s", "\124T%s:14:14:0:0:64:64:4:60:4:60\124t"
	local potion_ids, prepotion = {}, {}

	local function format_valuetext(d, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Count and d.value,
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_potion(set, actorname, actorid, actorflags, potionid)
		local actor = Skada:GetActor(set, actorname, actorid, actorflags)
		if not actor then return end

		-- record potion usage for actor and set
		actor.potion = (actor.potion or 0) + 1
		set.potion = (set.potion or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if set == Skada.total and not P.totalidc then return end

		actor.potionspells = actor.potionspells or {}
		actor.potionspells[potionid] = (actor.potionspells[potionid] or 0) + 1
	end

	local function potion_used(t)
		if t.__temp or (t.spellid and potion_ids[t.spellid]) then
			Skada:DispatchSets(log_potion, t.srcName, t.srcGUID, t.srcFlags, potion_ids[t.spellid])
		end
	end

	do
		local tconcat = table.concat
		local UnitClass = UnitClass

		-- listens to combat start
		function mode:UnitBuff(_, args)
			if args.owner or not args.auras then return end

			local potions = nil
			for _, aura in pairs(args.auras) do
				if potion_ids[aura.id] then
					local t = new()
					t.srcGUID = args.dstGUID
					t.srcName = args.dstName
					t.srcFlags = args.dstFlags
					t.spellid = aura.id
					t.__temp = true
					potion_used(t)
					t = del(t)

					potions = potions or new()
					potions[#potions + 1] = format(potionStr, aura.icon)
				end
			end

			if not potions then return end

			local _, class = UnitClass(args.unit)
			prepotion[#prepotion + 1] = format(prepotionStr, classcolors.str(class), args.dstName, tconcat(potions, " "))
			potions = del(potions)
		end

		-- listens to combat end
		function mode:CombatLeave()
			if prepotion then
				if P.prepotion and next(prepotion) ~= nil then
					Skada:Printf(L["pre-potion: %s"], tconcat(prepotion, ", "))
				end
				clear(prepotion)
			end
		end
	end

	function mode_actor:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = label
	end

	function mode_actor:Update(win, set)
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

			local d = win:actor(nr, actor, actor.enemy, actorname)
			d.value = actor.count
			format_valuetext(d, total, win.metadata, true)
		end
	end

	function mode_spell:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's potions"], classfmt(class, label))
	end

	local function request_potion(potionid)
		if potionid and potionid ~= nil and potionid ~= "" and potionid ~= 0 and strsub(potionid, 1, 1) ~= "s" then
			GameTooltip:SetHyperlink(format("item:%s:0:0:0:0:0:0:0", potionid))
			GameTooltip:Hide()
		end
	end

	function mode_spell:Update(win, set)
		win.title = uformat(L["%s's potions"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local actor = Skada:FindActor(set, win.actorname, win.actorid, true)
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
				format_valuetext(d, total, win.metadata, true)
			end
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Potions"], L[win.class]) or L["Potions"]

		local total = set and set:GetTotal(win.class, nil, "potion")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.potion then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.potion
				format_valuetext(d, total, win.metadata)
			end
		end
	end

	function mode:GetSetSummary(set, win)
		if not set then return end
		return set:GetTotal(win and win.class, nil, "potion") or 0
	end

	function mode:OnEnable()
		mode_actor.metadata = {filterclass = true}
		mode_spell.metadata = {click1 = mode_actor}
		self.metadata = {
			showspots = true,
			ordersort = true,
			filterclass = true,
			click1 = mode_spell,
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\ICONS\inv_potion_31]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_spell.nototal = true

		Skada:RegisterForCL(potion_used, {src_is_interesting_nopets = true}, "SPELL_CAST_SUCCESS")
		Skada.RegisterCallback(self, "Skada_ApplySettings", "ApplySettings")
		Skada:AddMode(self)
	end

	function mode:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	function mode:ApplySettings()
		if P.prepotion then
			Skada.RegisterCallback(self, "Skada_UnitBuffs", "UnitBuff")
			Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")
		else
			Skada.UnregisterCallback(self, "Skada_UnitBuffs")
			Skada.UnregisterAllMessages(self)
		end
	end

	function mode:OnInitialize()
		-- list of potion: [spellid] = potionid (string)

		--[[ level NaN ]]--
		potion_ids[439] = "118" -- Minor Healing Potion
		potion_ids[6724] = "5816" -- Light of Elune
		potion_ids[29236] = "3087" -- Mug of Shimmer Stout
		potion_ids[47430] = "36770" -- Zort's Protective Elixir
		potion_ids[50809] = "38351" -- Murliver Oil

		--[[ level 03-17 ]]--
		potion_ids[437] = "2455" -- Minor Mana Potion
		potion_ids[438] = "3385" -- Lesser Mana Potion
		potion_ids[440] = "4596" -- Discolored Healing Potion
		potion_ids[441] = "929" -- Healing Potion
		potion_ids[2370] = "2456" -- Minor Rejuvenation Potion
		potion_ids[2379] = "2459" -- Swiftness Potion
		potion_ids[2380] = "3384" -- Minor Magic Resistance Potion
		potion_ids[6612] = "5631" -- Rage Potion
		potion_ids[6612] = "858" -- Lesser Healing Potion
		potion_ids[6614] = "5632" -- Cowardly Flight Potion
		potion_ids[7242] = "6048" -- Shadow Protection Potion
		potion_ids[7245] = "6051" -- Holy Protection Potion
		potion_ids[7840] = "6372" -- Swim Speed Potion
		potion_ids[26677] = "3386" -- Potion of Curing

		--[[ level 20-28 ]]--
		potion_ids[2023] = "3827" -- Mana Potion
		potion_ids[2024] = "1710" -- Greater Healing Potion
		potion_ids[3592] = "2633" -- Jungle Remedy
		potion_ids[3680] = "3823" -- Lesser Invisibility Potion
		potion_ids[6613] = "5633" -- Great Rage Potion
		potion_ids[6615] = "5634" -- Free Action Potion
		potion_ids[7233] = "6049" -- Fire Protection Potion
		potion_ids[7239] = "6050" -- Frost Protection Potion
		potion_ids[7254] = "6052" -- Nature Protection Potion

		--[[ level 31-37 ]]--
		potion_ids[4042] = "3928" -- Superior Healing Potion
		potion_ids[4941] = "4623" -- Lesser Stoneshield Potion
		potion_ids[11359] = "9030" -- Restorative Potion
		potion_ids[11364] = "9036" -- Magic Resistance Potion
		potion_ids[11387] = "9144" -- Wildvine Potion
		potion_ids[11392] = "9172" -- Invisibility Potion
		potion_ids[11903] = "6149" -- Greater Mana Potion
		potion_ids[15822] = "12190" -- Dreamless Sleep Potion
		potion_ids[21394] = "17349" -- Superior Healing Draught
		potion_ids[21396] = "17352" -- Superior Mana Draught

		--[[ level 41-49 ]]--
		potion_ids[3169] = "3387" -- Limited Invulnerability Potion
		potion_ids[17528] = "13442" -- Mighty Rage Potion
		potion_ids[17530] = "13443" -- Superior Mana Potion
		potion_ids[17540] = "13455" -- Greater Stoneshield Potion
		potion_ids[17543] = "13457" -- Greater Fire Protection Potion
		potion_ids[17544] = "13456" -- Greater Frost Protection Potion
		potion_ids[17545] = "13460" -- Greater Holy Protection Potion
		potion_ids[17546] = "13458" -- Greater Nature Protection Potion
		potion_ids[17548] = "13459" -- Greater Shadow Protection Potion
		potion_ids[17549] = "13461" -- Greater Arcane Protection Potion
		potion_ids[17550] = "13462" -- Purification Potion
		potion_ids[21393] = "17348" -- Major Healing Draught
		potion_ids[21395] = "17351" -- Major Mana Draught
		potion_ids[24364] = "20008" -- Living Action Potion

		--[[ level 50-55 ]]--
		potion_ids[17624] = "13506" -- Flask of Petrification
		potion_ids[22729] = "18253" -- Major Rejuvenation Potion
		potion_ids[24360] = "20002" -- Greater Dreamless Sleep Potion
		potion_ids[28492] = "22826" -- Sneaking Potion
		potion_ids[28548] = "22871" -- Shrouding Potion
		potion_ids[41617] = "32903" -- Cenarion Mana Salve
		potion_ids[41618] = "32902" -- Bottled Nethergon Energy
		potion_ids[41619] = "32904" -- Cenarion Healing Salve
		potion_ids[41620] = "32905" -- Bottled Nethergon Vapor
		potion_ids[52697] = "39327" -- Noth's Special Brew
		potion_ids[67486] = "33092" -- Healing Potion Injector
		potion_ids[67487] = "33093" -- Mana Potion Injector

		--[[ level 60-65 ]]--
		potion_ids[17531] = "31840" -- Major Combat Mana Potion
		potion_ids[17534] = "31838" -- Major Combat Healing Potion
		potion_ids[28504] = "22836" -- Major Dreamless Sleep Potion
		potion_ids[28506] = "22837" -- Heroic Potion
		potion_ids[28507] = "22838" -- Haste Potion
		potion_ids[28508] = "22839" -- Destruction Potion
		potion_ids[28511] = "22841" -- Major Fire Protection Potion
		potion_ids[28512] = "22842" -- Major Frost Protection Potion
		potion_ids[28513] = "22844" -- Major Nature Protection Potion
		potion_ids[28515] = "22849" -- Ironshield Potion
		potion_ids[28517] = "22850" -- Super Rejuvenation Potion
		potion_ids[28536] = "22845" -- Major Arcane Protection Potion
		potion_ids[28537] = "22846" -- Major Shadow Protection Potion
		potion_ids[28538] = "22847" -- Major Holy Protection Potion
		potion_ids[38908] = "31676" -- Fel Regeneration Potion
		potion_ids[45051] = "34440" -- Mad Alchemist's Potion

		--[[ level 70 ]]--
		potion_ids[28494] = "22828" -- Insane Strength Potion
		potion_ids[28495] = "43569" -- Endless Healing Potion
		potion_ids[28499] = "43570" -- Endless Mana Potion
		potion_ids[38929] = "31677" -- Fel mana potion
		potion_ids[41304] = "32783" -- Blue Ogre Brew
		potion_ids[41306] = "32784" -- Red Ogre Brew
		potion_ids[43185] = "33447" -- Healing Potion
		potion_ids[43186] = "33448" -- Restore Mana
		potion_ids[53750] = "40077" -- Crazy Alchemist's Potion
		potion_ids[53753] = "40081" -- Nightmare Slumber
		potion_ids[53761] = "40087" -- Powerful Rejuvenation Potion
		potion_ids[53762] = "40093" -- Indestructible
		potion_ids[53908] = "40211" -- Potion of Speed
		potion_ids[53909] = "40212" -- Potion of Wild Magic
		potion_ids[53910] = "40213" -- Arcane Protection
		potion_ids[53911] = "40214" -- Fire Protection
		potion_ids[53913] = "40215" -- Frost Protection
		potion_ids[53914] = "40216" -- Nature Protection
		potion_ids[53915] = "40217" -- Shadow Protection
		potion_ids[61371] = "44728" -- Endless Rejuvenation Potion
		potion_ids[67489] = "41166" -- Runic Healing Injector
		potion_ids[67490] = "42545" -- Runic Mana Injector

		-- don't edit below unless you know what you're doing.
		if P.prepotion == nil then
			P.prepotion = true
		end

		O.tweaks.args.general.args.prepotion = {
			type = "toggle",
			name = L["Pre-potion"],
			desc = L["Prints pre-potion after the end of the combat."],
			order = 0
		}
	end

	---------------------------------------------------------------------------

	get_actors_by_potion = function(self, potionid, class, tbl)
		local total = 0
		if not self.actors or not self.potion or not potionid then
			return total
		end

		tbl = clear(tbl or C)

		local actors = self.actors
		for aname, a in pairs(actors) do
			if a.potionspells and a.potionspells[potionid] and (not class or class == a.class) then
				total = total + a.potionspells[potionid]
				tbl[aname] = new()
				tbl[aname].id = a.id
				tbl[aname].class = a.class
				tbl[aname].role = a.role
				tbl[aname].spec = a.spec
				tbl[aname].enemy = a.enemy
				tbl[aname].count = a.potionspells[potionid]
			end
		end

		return total, tbl
	end
end)
