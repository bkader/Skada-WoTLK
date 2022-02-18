local Skada = Skada
Skada:AddLoadableModule("Comparison", function(L)
	if Skada:IsDisabled("Damage", "Comparison") then return end

	local mod = Skada:NewModule(L["Comparison"])

	local spellmod = mod:NewModule(L["Damage spell list"])
	local dspellmod = spellmod:NewModule(L["Damage spell details"])
	local bspellmod = spellmod:NewModule(L["Damage Breakdown"])

	local targetmod = mod:NewModule(L["Damage target list"])
	local dtargetmod = targetmod:NewModule(L["Damage spell list"])

	local format, max = string.format, math.max
	local pairs, ipairs, select = pairs, ipairs, select
	local GetSpellInfo, T = Skada.GetSpellInfo or GetSpellInfo, Skada.Table
	local misstypes = Skada.missTypes
	local cacheTable = T.get("Skada_CacheTable2")
	local _

	local red = "|cffffaaaa-%s|r"
	local green = "|cffaaffaa+%s|r"
	local grey = "|cff808080%s|r"

	local function FormatPercent(value1, value2, cond)
		if cond == false then return end

		value1, value2 = value1 or 0, value2 or 0
		if value1 == value2 then
			return format(grey, Skada:FormatPercent(0))
		elseif value1 > value2 then
			return format(green, Skada:FormatPercent(value1 - value2, value2))
		else
			return format(red, Skada:FormatPercent(value2 - value1, value1))
		end
	end

	local function FormatValuePercent(val, myval, disabled)
		return Skada:FormatValueCols(
			mod.metadata.columns.Damage and Skada:FormatPercent(val),
			(mod.metadata.columns.Comparison and not disabled) and Skada:FormatPercent(myval),
			(mod.metadata.columns.Percent and not disabled) and  FormatPercent(myval, val)
		)
	end

	local function FormatValueNumber(val, myval, fmt, disabled)
		val, myval = val or 0, myval or 0 -- sanity check
		return Skada:FormatValueCols(
			mod.metadata.columns.Damage and (fmt and Skada:FormatNumber(val) or val),
			(mod.metadata.columns.Comparison and not disabled) and (fmt and Skada:FormatNumber(myval) or myval),
			FormatPercent(myval, val, mod.metadata.columns.Percent and not disabled)
		)
	end

	local function CanCompare(actor)
		if actor and actor.class == mod.userClass then
			return (Skada.Ascension or Skada.AscensionCoA) and true or (actor.role == "DAMAGER")
		end
		return false
	end

	local function spellmod_tooltip(win, id, label, tooltip)
		if label == L["Critical Hits"] or label == L["Normal Hits"] then
			local set = win:GetSelectedSet()
			local actor = set and set:GetPlayer(win.playerid, win.playername)
			local spell = actor.damagespells and actor.damagespells[win.spellname]

			local myspells = set:GetActorDamageSpells(mod.userGUID, mod.userName)
			local myspell = myspells and myspells[win.spellname]

			if spell or myspell then
				tooltip:AddLine(format(L["%s vs %s: %s"], actor and actor.name or L.Unknown, mod.userName, win.spellname))
				if (spell and spell.school) or (myspell and myspell.school) then
					local c = Skada.schoolcolors[spell and spell.school or myspell.school]
					local n = Skada.schoolnames[spell and spell.school or myspell.school]
					if c and n then
						tooltip:AddLine(n, c.r, c.g, c.b)
					end
				end

				if label == L["Critical Hits"] and (spell and spell.criticalamount or myspell.criticalamount) then
					local num = spell and spell.critical and (100 * spell.critical / spell.count) or 0
					local mynum = myspell and myspell.critical and (100 * myspell.critical / myspell.count) or 0

					tooltip:AddDoubleLine(L["Critical"], FormatValuePercent(mynum, num, actor.id == mod.userGUID), 1, 1, 1)

					num = (spell and spell.criticalamount) and (spell.criticalamount / spell.critical) or 0
					mynum = (myspell and myspell.criticalamount) and (myspell.criticalamount / myspell.critical) or 0

					tooltip:AddDoubleLine(L["Average"], FormatValueNumber(num, mynum, true), 1, 1, 1)

					if (spell and spell.criticalmin and spell.criticalmax) or (myspell and myspell.criticalmin and myspell.criticalmax) then
						tooltip:AddLine(" ")
						tooltip:AddDoubleLine(L["Minimum Hit"], FormatValueNumber(spell and spell.criticalmin, myspell and myspell.criticalmin, true), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum Hit"], FormatValueNumber(spell and spell.criticalmax, myspell and myspell.criticalmax, true), 1, 1, 1)

						num = (spell and spell.criticalmin and spell.criticalmax) and ((spell.criticalmin + spell.criticalmax) / 2) or 0
						mynum = (myspell and myspell.criticalmin and myspell.criticalmax) and ((myspell.criticalmin + myspell.criticalmax) / 2) or 0
						tooltip:AddDoubleLine(L["Average Hit"], FormatValueNumber(num, mynum, true), 1, 1, 1)
					end
				elseif label == L["Normal Hits"] and ((spell and spell.hitamount) or (myspell and myspell.hitamount)) then
					local num = (spell and spell.hitamount) and (spell.hitamount / spell.hit) or 0
					local mynum = (myspell and myspell.hitamount) and (myspell.hitamount / myspell.hit) or 0

					tooltip:AddDoubleLine(L["Average"], FormatValueNumber(num, mynum, true), 1, 1, 1)

					if (spell and spell.hitmin and spell.hitmax) or (myspell and myspell.hitmin and myspell.hitmax) then
						tooltip:AddLine(" ")
						tooltip:AddDoubleLine(L["Minimum Hit"], FormatValueNumber(spell and spell.hitmin, myspell and myspell.hitmin, true), 1, 1, 1)
						tooltip:AddDoubleLine(L["Maximum Hit"], FormatValueNumber(spell and spell.hitmax, myspell and myspell.hitmax, true), 1, 1, 1)

						num = (spell and spell.hitmin and spell.hitmax) and ((spell.hitmin + spell.hitmax) / 2) or 0
						mynum = (myspell and myspell.hitmin and myspell.hitmax) and ((myspell.hitmin + myspell.hitmax) / 2) or 0
						tooltip:AddDoubleLine(L["Average Hit"], FormatValueNumber(num, mynum, true), 1, 1, 1)
					end
				end
			end
		end
	end

	local function activity_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		if actor then
			local totaltime = set:GetTime()
			local activetime = actor:GetTime(true)
			local mytime = set:GetActorTime(mod.userGUID, mod.userName, true)

			tooltip:AddDoubleLine(L["Activity"], FormatValuePercent(100 * activetime / totaltime, 100 * mytime / totaltime, actor.id == mod.userGUID), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], format(actor.id ~= mod.userGUID and "%s (%s)" or "%s", Skada:FormatTime(activetime), Skada:FormatTime(mytime)), 1, 1, 1)
		end
	end

	-- local nr = add_detail_bar(win, 0, L["Hits"], spell.count, myspell.count)
	local function add_detail_bar(win, nr, title, value, myvalue, fmt, disabled)
		nr = nr + 1

		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = title
		d.label = title

		value, myvalue = value or 0, myvalue or 0
		d.value = value
		d.valuetext = FormatValueNumber(d.value, myvalue, fmt, disabled)

		return nr
	end

	function dspellmod:Enter(win, id, label)
		win.spellname = label
		win.title = format(L["%s vs %s: %s"], mod.userName, win.playername or L.Unknown, format(L["%s's damage"], label))
	end

	function dspellmod:Update(win, set)
		win.title = format( L["%s vs %s: %s"], mod.userName, win.playername or L.Unknown, format(L["%s's damage"], win.spellname or L.Unknown))
		if not win.spellname then return end

		local actor = set and set:GetPlayer(win.playerid, win.playername)
		local spell = actor and actor.damagespells and actor.damagespells[win.spellname]

		local myspells = set:GetActorDamageSpells(mod.userGUID, mod.userName)
		local myspell = myspells and myspells[win.spellname]

		if spell and myspell then
			if win.metadata then
				win.metadata.maxvalue = spell.count
			end

			local nr = add_detail_bar(win, 0, L["Hits"], spell.count, myspell.count, nil, actor.id == mod.userGUID)
			win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

			if (spell.casts or 0) > 0 or (myspell.casts or 0) > 0 then
				nr = add_detail_bar(win, nr, L["Casts"], spell.casts, myspell.casts, nil, actor.id == mod.userGUID)
				win.dataset[nr].value = win.dataset[nr].value * 1e3 -- to be always first
			end

			if (spell.hit or 0) > 0 or (myspell.hit or 0) > 0 then
				nr = add_detail_bar(win, nr, L["Normal Hits"], spell.hit, myspell.hit, nil, actor.id == mod.userGUID)
			end

			if (spell.critical or 0) > 0 or (myspell.critical or 0) > 0 then
				nr = add_detail_bar(win, nr, L["Critical Hits"], spell.critical, myspell.critical, nil, actor.id == mod.userGUID)
			end

			if (spell.glancing or 0) > 0 or (myspell.glancing or 0) > 0 then
				nr = add_detail_bar(win, nr, L["Glancing"], spell.glancing, myspell.glancing, nil, actor.id == mod.userGUID)
			end

			for _, misstype in ipairs(misstypes) do
				if (spell[misstype] or 0) > 0 or (myspell[misstype] or 0) > 0 then
					nr = add_detail_bar(win, nr, L[misstype], spell[misstype], myspell[misstype], nil, actor.id == mod.userGUID)
				end
			end
		end
	end

	function bspellmod:Enter(win, id, label)
		win.spellname = label
		win.title = format(L["%s vs %s: %s"], mod.userName, win.playername or L.Unknown, format(L["%s's damage breakdown"], label))
	end

	function bspellmod:Update(win, set)
		win.title = format(L["%s vs %s: %s"], mod.userName, win.playername or L.Unknown, format(L["%s's damage breakdown"], win.spellname or L.Unknown))
		if not win.spellname then return end

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local spell = player and player.damagespells and player.damagespells[win.spellname]

		local myspells = set:GetActorDamageSpells(mod.userGUID, mod.userName)
		local myspell = myspells and myspells[win.spellname]

		if spell and myspell then
			-- the player
			local absorbed = max(0, spell.total - spell.amount)
			local blocked = spell.blocked or 0
			local resisted = spell.resisted or 0
			local total = spell.amount + absorbed + blocked + resisted
			if win.metadata then
				win.metadata.maxvalue = total
			end

			-- mine
			local myabsorbed = max(0, myspell.total - myspell.amount)
			local myblocked = myspell.blocked or 0
			local myresisted = myspell.resisted or 0
			local mytotal = myspell.amount + myabsorbed + myblocked + myresisted

			local nr = add_detail_bar(win, 0, L["Total"], total, mytotal, true, player.id == mod.userGUID)
			win.dataset[nr].value = win.dataset[nr].value + 1 -- to be always first

			if total ~= spell.amount or mytotal ~= myspell.amount then
				nr = add_detail_bar(win, nr, L["Damage"], spell.amount, myspell.amount, true, player.id == mod.userGUID)
			end

			if (spell.overkill or 0) > 0 or (myspell.overkill or 0) > 0 then
				nr = add_detail_bar(win, nr, L["Overkill"], spell.overkill, myspell.overkill, true, player.id == mod.userGUID)
			end

			if absorbed > 0 or myabsorbed > 0 then
				nr = add_detail_bar(win, nr, L["ABSORB"], absorbed, myabsorbed, true, player.id == mod.userGUID)
			end

			if blocked > 0 or myblocked > 0 then
				nr = add_detail_bar(win, nr, L["BLOCK"], blocked, myblocked, true, player.id == mod.userGUID)
			end

			if resisted > 0 or myresisted > 0 then
				nr = add_detail_bar(win, nr, L["RESIST"], resisted, myresisted, true, player.id == mod.userGUID)
			end
		end
	end

	function dtargetmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["%s vs %s: Damage on %s"], mod.userName, win.playername or L.Unknown, label)
	end

	function dtargetmod:Update(win, set)
		win.title = format(L["%s vs %s: Damage on %s"], mod.userName, win.playername or L.Unknown, win.targetname or L.Unknown)
		if not win.targetname then return end

		local actor = set and set:GetPlayer(win.playerid, win.playername)
		local targets = actor and actor:GetDamageTargets()

		local mytargets, myself = set:GetActorDamageTargets(mod.userGUID, mod.userName, cacheTable)

		if targets and mytargets then
			-- the player
			local total = targets[win.targetname] and targets[win.targetname].amount or 0
			if Skada.db.profile.absdamage then
				total = targets[win.targetname].total or total
			end

			if total > 0 and actor.damagespells then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				-- mine
				local mytotal = mytargets[win.targetname] and mytargets[win.targetname].amount or 0
				if Skada.db.profile.absdamage then
					mytotal = mytargets[win.targetname].total or mytotal
				end

				local nr = 0
				for spellname, spell in pairs(actor.damagespells) do
					if spell.targets and spell.targets[win.targetname] then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						d.icon = select(3, GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = spell.targets[win.targetname].amount
						if Skada.db.profile.absdamage then
							d.value = spell.targets[win.targetname].total or d.value
						end

						local myamount = 0
						if
							myself.damagespells and
							myself.damagespells[spellname] and
							myself.damagespells[spellname].targets and
							myself.damagespells[spellname].targets[win.targetname]
						then
							if Skada.db.profile.absdamage then
								myamount = myself.damagespells[spellname].targets[win.targetname].total
							else
								myamount = myself.damagespells[spellname].targets[win.targetname].amount
							end

							-- sanity check
							myamount = myamount or 0
						end

						d.valuetext = FormatValueNumber(d.value, myamount, true, actor.id == mod.userGUID)
					end
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s vs %s: Spells"], mod.userName, label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s vs %s: Spells"], mod.userName, win.playername)

		local actor = set and set:GetPlayer(win.playerid, win.playername)
		if actor and actor.damagespells then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local myspells = set:GetActorDamageSpells(mod.userGUID, mod.userName)
			local nr = 0

			for spellname, spell in pairs(actor.damagespells) do
				if myspells and myspells[spellname] then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellname
					d.spellid = spell.id
					d.label = spellname
					d.icon = select(3, GetSpellInfo(spell.id))
					d.spellschool = spell.school

					local myamount = 0
					if Skada.db.profile.absdamage then
						d.value = spell.total or spell.amount or 0
						myamount = myspells[spellname].total or myspells[spellname].amount or 0
					else
						d.value = spell.amount or 0
						myamount = myspells[spellname].amount or 0
					end

					d.valuetext = FormatValueNumber(d.value, myamount, true, actor.id == mod.userGUID)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s vs %s: Targets"], mod.userName, label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s vs %s: Targets"], mod.userName, win.playername or L.Unknown)

		local actor = set and set:GetPlayer(win.playerid, win.playername)
		local targets = actor and actor:GetDamageTargets()

		if targets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local mytargets = set:GetActorDamageTargets(mod.userGUID, mod.userName, cacheTable)
			local nr = 0

			for targetname, target in pairs(targets) do
				if mytargets and mytargets[targetname] then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class = target.class
					d.role = target.role
					d.spec = target.spec

					local myamount = 0
					if Skada.db.profile.absdamage then
						d.value = target.total or target.amount or 0
						myamount = mytargets[targetname].amount or mytargets[targetname].amount or 0
					else
						d.value = target.amount or 0
						myamount = mytargets[targetname].amount or 0
					end
					d.valuetext = FormatValueNumber(d.value, myamount, true, actor.id == mod.userGUID)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:SetActor(win, id, label)
		-- same player, same mode or no DisplayMode func?
		if (id == mod.userGUID and win.selectedmode == mod) or not win.DisplayMode then
			return
		end

		-- is it met?
		if id == Skada.userGUID then
			mod.userGUID = Skada.userGUID
			mod.userName = Skada.userName
			mod.userClass = Skada.userClass
			win:DisplayMode(mod)
		elseif win.GetSelectedSet then
			local set = win:GetSelectedSet()
			local actor = set and set:GetPlayer(id, label)
			if actor then
				mod.userGUID = actor.id
				mod.userName = actor.name
				mod.userClass = actor.class
				win:DisplayMode(mod)
			end
		end
	end

	function mod:Update(win, set)
		win.title = format("%s: %s", L["Comparison"], self.userName)

		if (set:GetDamage() or 0) then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local myamount = set:GetActorDamage(mod.userGUID, mod.userName)
			local nr = 0

			for _, player in ipairs(set.players) do
				if CanCompare(player) then
					local dps, amount = player:GetDPS()
					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						d.value = amount
						d.valuetext = Skada:FormatValueCols(
							mod.metadata.columns.Damage and Skada:FormatNumber(d.value),
							mod.metadata.columns.DPS and Skada:FormatNumber(dps),
							FormatPercent(myamount, d.value, mod.metadata.columns.Percent and player.id ~= mod.userGUID)
						)

						-- a valid window, not a tooltip
						if win.metadata then
							-- color the selected player's bar.
							if player.id == mod.userGUID then
								d.color = Skada.classcolors.ARENA_GOLD
							elseif d.color then
								d.color = nil
							end

							-- order bars.
							if d.value > win.metadata.maxvalue then
								win.metadata.maxvalue = d.value
							end
						end
					end
				end
			end
		end
	end

	function mod:OnEnable()
		dspellmod.metadata = {tooltip = spellmod_tooltip}
		targetmod.metadata = {click1 = dtargetmod}
		spellmod.metadata = {click1 = dspellmod, click2 = bspellmod}
		self.metadata = {
			showspots = true,
			post_tooltip = activity_tooltip,
			click1 = spellmod,
			click2 = targetmod,
			click3 = self.SetActor,
			click3_label = L["Damage Comparison"],
			nototalclick = {spellmod, targetmod},
			columns = {Damage = true, DPS = true, Comparison = true, Percent = true},
			icon = [[Interface\Icons\Ability_Warrior_OffensiveStance]]
		}

		self.userGUID = Skada.userGUID
		self.userName = Skada.userName
		self.userClass = Skada.userClass

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)