local Skada = Skada
Skada:AddLoadableModule("Deaths", function(L)
	if Skada:IsDisabled("Deaths") then return end

	local mod = Skada:NewModule(L["Deaths"])
	local playermod = mod:NewModule(L["Player's deaths"])
	local deathlogmod = mod:NewModule(L["Death log"])

	local UnitHealthInfo = Skada.UnitHealthInfo
	local UnitIsFeignDeath = UnitIsFeignDeath
	local tinsert, tremove, tsort, tconcat = table.insert, table.remove, table.sort, table.concat
	local ipairs, select = ipairs, select
	local tostring, format = tostring, string.format
	local max, floor = math.max, math.floor
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local GetSpellLink = Skada.GetSpellLink or GetSpellLink
	local T, wipe = Skada.Table, wipe
	local new, del = Skada.newTable, Skada.delTable
	local IsInGroup, IsInPvP = Skada.IsInGroup, Skada.IsInPvP
	local GetTime, date = GetTime, date
	local _

	local function log_deathlog(set, data, deathlog, override)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			deathlog = deathlog or player.deathlog and player.deathlog[1]
			if not deathlog or (deathlog.time and not override) then
				deathlog = {log = {}}
				player.deathlog = player.deathlog or {}
				tinsert(player.deathlog, 1, deathlog)
			end

			-- seet player maxhp if not already set
			if not deathlog.maxhp or deathlog.maxhp == 0 then
				deathlog.maxhp = select(3, UnitHealthInfo(player.name, player.id, "group")) or 0
			end

			local log = new()
			log.spellid = data.spellid
			log.school = data.spellschool
			log.source = data.srcName
			log.amount = data.amount
			log.time = GetTime()
			_, log.hp = UnitHealthInfo(player.name, player.id, "group")

			if data.overheal and data.overheal > 0 then
				log.overheal = data.overheal
			end
			if data.overkill and data.overkill > 0 then
				log.overkill = data.overkill
			end
			if data.resisted and data.resisted > 0 then
				log.resisted = data.resisted
			end
			if data.blocke and data.blocked > 0 then
				log.blocked = data.blocked
			end
			if data.absorbed and data.absorbed > 0 then
				log.absorbed = data.absorbed
			end

			tinsert(deathlog.log, 1, log)

			-- trim things and limit to deathlogevents (defaul: 14)
			while #deathlog.log > (Skada.db.profile.modules.deathlogevents or 14) - 1 do
				del(tremove(deathlog.log))
			end
		end
	end

	local data = {}

	local function SpellDamage(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if event == "SWING_DAMAGE" then
			data.spellid, data.spellschool = 6603, 0x01
			data.amount, data.overkill, _, data.resisted, data.blocked, data.absorbed = ...
		else
			data.spellid, _, data.spellschool, data.amount, data.overkill, _, data.resisted, data.blocked, data.absorbed = ...
		end

		if data.amount then
			data.srcName = srcName
			data.playerid = dstGUID
			data.playername = dstName
			data.playerflags = dstFlags

			data.amount = 0 - data.amount
			data.overheal = nil

			Skada:DispatchSets(log_deathlog, nil, data)
		end
	end

	local function SpellMissed(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local misstype, amount

		if event == "SWING_MISSED" then
			data.spellid, data.spellschool = 6603, 0x01
			misstype, amount = ...
		else
			data.spellid, _, data.spellschool, misstype, amount = ...
		end

		if (amount or 0) > 0 and (misstype == "RESIST" or misstype == "BLOCK" or misstype == "ABSORB") then
			data.srcName = srcName
			data.playerid = dstGUID
			data.playername = dstName
			data.playerflags = dstFlags

			data.amount = nil
			data.overkill = nil
			data.overheal = nil

			if misstype == "RESIST" then
				data.resisted = amount
				data.blocked = nil
				data.absorbed = nil
			elseif misstype == "BLOCK" then
				data.resisted = nil
				data.blocked = amount
				data.absorbed = nil
			elseif misstype == "ABSORB" then
				data.resisted = nil
				data.blocked = nil
				data.absorbed = amount
			end

			Skada:DispatchSets(log_deathlog, nil, data)
		end
	end

	local function EnvironmentDamage(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local envtype, amount = ...
		local spellid, spellschool = nil, 0x01

		if envtype == "Falling" or envtype == "FALLING" then
			spellid = 3
		elseif envtype == "Drowning" or envtype == "DROWNING" then
			spellid = 4
		elseif envtype == "Fatigue" or envtype == "FATIGUE" then
			spellid = 5
		elseif envtype == "Fire" or envtype == "FIRE" then
			spellid, spellschool = 6, 0x04
		elseif envtype == "Lava" or envtype == "LAVA" then
			spellid, spellschool = 7, 0x04
		elseif envtype == "Slime" or envtype == "SLIME" then
			spellid, spellschool = 8, 0x08
		end

		if spellid then
			SpellDamage(nil, event, nil, ENVIRONMENTAL_DAMAGE, nil, dstGUID, dstName, dstFlags, spellid, nil, spellschool, amount)
		end
	end

	local function SpellHeal(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, _, spellschool, amount, overheal = ...

		if amount > (Skada.db.profile.modules.deathlogthreshold or 0) then
			srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)
			dstGUID, dstName = Skada:FixMyPets(dstGUID, dstName, dstFlags)

			data.srcName = srcName

			data.playerid = dstGUID
			data.playername = dstName
			data.playerflags = dstFlags

			data.spellid = spellid
			data.spellschool = spellschool
			data.amount = max(0, amount - (overheal or 0))
			data.overheal = overheal
			data.overkill = nil
			data.resisted = nil
			data.blocked = nil
			data.absorbed = nil

			Skada:DispatchSets(log_deathlog, nil, data)
		end
	end

	local function log_death(set, playerid, playername, playerflags)
		local player = Skada:GetPlayer(set, playerid, playername, playerflags)
		if player then
			set.death = (set.death or 0) + 1
			player.death = (player.death or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.total then return end

			local deathlog = player.deathlog and player.deathlog[1]
			if deathlog then
				deathlog.time = GetTime()
				deathlog.timeStr = date("%H:%M:%S")

				for i = #deathlog.log, 1, -1 do
					local e = deathlog.log[i]
					if (deathlog.time - e.time) >= 60 then
						-- in certain situations, such us The Ruby Sanctum,
						-- deathlog contain old data which are irrelevant to keep.
						del(tremove(deathlog.log, i))
					else
						-- sometimes multiple close events arrive with the same timestamp
						-- so we add a small correction to ensure sort stability.
						e.time = e.time + (i * 0.001)
					end
				end

				-- no entry left? insert an unknown entry
				if #deathlog.log == 0 then
					local log = new()
					log.amount = -deathlog.maxhp
					log.time = deathlog.time-0.001
					log.hp = deathlog.maxhp
					tinsert(deathlog.log, log)
				end

				-- announce death
				if Skada.db.profile.modules.deathannounce then
					mod:Announce(deathlog.log, player.name)
				end
			end
		end
	end

	local function UnitDied(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags)
		if not UnitIsFeignDeath(dstName) then
			Skada:DispatchSets(log_death, true, dstGUID, dstName, dstFlags)
		end
	end

	local function AuraApplied(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid)
		if spellid == 27827 then -- Spirit of Redemption (Holy Priest)
			Skada:ScheduleTimer(function() UnitDied(nil, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags) end, 0.01)
		end
	end

	local function log_resurrect(set, playerid, playername, playerflags, srcName, spellid)
		local player = Skada:GetPlayer(set, playerid, playername, playerflags)
		local deathlog = player and player.deathlog and player.deathlog[1]
		if deathlog then
			data.spellid = spellid
			data.srcName = srcName
			data.playerid = player.id or playerid
			data.playername = player.name or playername
			data.playerflags = player.flag or playerflags

			data.amount = nil
			data.overkill = nil
			data.overheal = nil
			data.resisted = nil
			data.blocked = nil
			data.absorbed = nil

			-- log resurrection.
			log_deathlog(set, data, deathlog, true)
		end
	end

	local function SpellResurrect(_, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid)
		if spellid then
			Skada:DispatchSets(log_resurrect, nil, dstGUID, dstName, dstFlags, srcName, spellid)
		end
	end

	function deathlogmod:Enter(win, id, label)
		win.datakey = id
		win.title = format(L["%s's death log"], win.actorname or L.Unknown)
	end

	do
		local green = GREEN_FONT_COLOR
		local red = RED_FONT_COLOR
		local yellow = YELLOW_FONT_COLOR
		local orange = ORANGE_FONT_COLOR

		local function sort_logs(a, b)
			return a and b and a.time > b.time
		end

		function deathlogmod:Update(win, set)
			win.title = format(L["%s's death log"], win.actorname or L.Unknown)
			if set == Skada.current then return end -- don't show while in combat

			local player = Skada:FindPlayer(set, win.actorid, win.actorname)
			if player and win.datakey then
				local deathlog
				if player.deathlog and player.deathlog[win.datakey] then
					deathlog = player.deathlog[win.datakey]
				end
				if not deathlog then return end

				if win.metadata then
					win.metadata.maxvalue = deathlog.maxhp
				end

				-- add a fake entry for the actual death
				if win.metadata and deathlog.timeStr then
					local d = win:nr(1)
					d.id = 1
					d.label = deathlog.timeStr
					d.icon = [[Interface\Icons\Ability_Rogue_FeignDeath]]
					d.value = 0
					d.valuetext = format(L["%s dies"], player.name)
				end

				-- postfix
				if #deathlog.log == 0 then
					local log = new()
					log.amount = deathlog.maxhp and -deathlog.maxhp or 0
					log.time = deathlog.time-0.001
					log.hp = deathlog.maxhp or 0
					deathlog.log[1] = log
				end

				tsort(deathlog.log, sort_logs)

				for i = #deathlog.log, 1, -1 do
					local log = deathlog.log[i]
					local diff = tonumber(log.time) - tonumber(deathlog.time)
					if diff > -60 then
						local nr = i + 1
						local d = win:nr(nr)

						local spellname, spellicon
						if log.spellid then
							spellname, _, spellicon = GetSpellInfo(log.spellid)
						else
							spellname = L.Unknown
							spellicon = [[Interface\Icons\Spell_Shadow_Soulleech_1]]
						end

						d.id = nr
						d.spellid = log.spellid
						d.label = format("%02.2fs: %s", diff, spellname)
						d.icon = spellicon

						-- used for tooltip
						d.hp = log.hp or 0
						d.amount = log.amount or 0
						d.source = log.source or L.Unknown
						d.spellname = spellname
						d.value = d.hp

						local change = d.amount
						if change > 0 then
							change = "+" .. Skada:FormatNumber(change)
							d.color = green
						elseif change == 0 and (log.resisted or log.blocked or log.absorbed) then
							change = "+" .. Skada:FormatNumber(log.resisted or log.blocked or log.absorbed)
							d.color = orange
						else
							change = Skada:FormatNumber(change)
							d.color = log.overheal and yellow or red
						end

						d.reportlabel = "%02.2fs: %s (%s)   %s [%s]"

						if Skada.db.profile.reportlinks and log.spellid then
							d.reportlabel = format(d.reportlabel, diff, GetSpellLink(log.spellid) or spellname, d.source, change, Skada:FormatNumber(d.value))
						else
							d.reportlabel = format(d.reportlabel, diff, spellname, d.source, change, Skada:FormatNumber(d.value))
						end

						local extra = new()

						if (log.overheal or 0) > 0 then
							d.overheal = log.overheal
							extra[#extra + 1] = "O:" .. Skada:FormatNumber(log.overheal)
						end
						if (log.overkill or 0) > 0 then
							d.overkill = log.overkill
							extra[#extra + 1] = "O:" .. Skada:FormatNumber(log.overkill)
						end
						if (log.resisted or 0) > 0 then
							d.resisted = log.resisted
							extra[#extra + 1] = "R:" .. Skada:FormatNumber(log.resisted)
						end
						if (log.blocked or 0) > 0 then
							d.blocked = log.blocked
							extra[#extra + 1] = "B:" .. Skada:FormatNumber(log.blocked)
						end
						if (log.absorbed or 0) > 0 then
							d.absorbed = log.absorbed
							extra[#extra + 1] = "A:" .. Skada:FormatNumber(log.absorbed)
						end

						if next(extra) then
							-- change = "(|cffff0000*|r) " .. change -- uncomment for * back.
							d.reportlabel = d.reportlabel .. " (" .. tconcat(extra, " - ") .. ")"
						end

						extra = del(extra)

						d.valuetext = Skada:FormatValueCols(
							self.metadata.columns.Change and change,
							self.metadata.columns.Health and Skada:FormatNumber(d.value),
							self.metadata.columns.Percent and Skada:FormatPercent(log.hp or 1, deathlog.maxhp or 1)
						)
					else
						del(tremove(deathlog.log, i))
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's deaths"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:FindPlayer(set, win.actorid)

		if player then
			win.title = format(L["%s's deaths"], player.name)

			if (player.death or 0) > 0 and player.deathlog then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for i, death in ipairs(player.deathlog) do
					nr = nr + 1
					local d = win:nr(nr)

					d.id = i
					d.icon = [[Interface\Icons\Spell_Shadow_Soulleech_1]]

					for k, v in ipairs(death.log) do
						if v.amount and v.amount < 0 and (v.spellid or v.source) then
							if v.spellid then
								d.label, _, d.icon = GetSpellInfo(v.spellid)
								d.spellid = v.spellid
								d.spellschool = v.school
							elseif v.source then
								d.label = v.source
							end
							break
						end
					end

					d.label = d.label or L.Unknown
					d.value = death.time
					d.valuetext = death.timeStr

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Deaths"], L[win.class]) or L["Deaths"]

		local total = set.death or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.death or 0) > 0 then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.death
					d.valuetext = tostring(player.death)
					if player.deathlog and player.deathlog[1] and player.deathlog[1].time then
						d.value = player.deathlog[1].time
					end

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	local function entry_tooltip(win, id, label, tooltip)
		local entry = win.dataset[id]
		if entry and entry.spellname then
			tooltip:AddLine(L["Spell details"])
			tooltip:AddDoubleLine(L["Spell"], entry.spellname, 1, 1, 1, 1, 1, 1)

			if entry.source then
				tooltip:AddDoubleLine(L["Source"], entry.source, 1, 1, 1, 1, 1, 1)
			end

			if entry.hp then
				tooltip:AddDoubleLine(HEALTH, Skada:FormatNumber(entry.hp), 1, 1, 1)
			end

			if entry.amount then
				local amount = (entry.amount < 0) and (0 - entry.amount) or entry.amount
				tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(amount), 1, 1, 1)
			end

			if (entry.overkill or 0) > 0 then
				tooltip:AddDoubleLine(L["Overkill"], Skada:FormatNumber(entry.overkill), 1, 1, 1, 1, 0.45, 0.45)
			elseif (entry.overheal or 0) > 0 then
				tooltip:AddDoubleLine(L["Overheal"], Skada:FormatNumber(entry.overheal), 1, 1, 1, 0.45, 1, 0.45)
			end

			if (entry.resisted or 0) > 0 then
				tooltip:AddDoubleLine(L.RESIST, Skada:FormatNumber(entry.resisted), 1, 1, 1)
			end

			if (entry.blocked or 0) > 0 then
				tooltip:AddDoubleLine(L.BLOCK, Skada:FormatNumber(entry.blocked), 1, 1, 1)
			end

			if (entry.absorbed or 0) > 0 then
				tooltip:AddDoubleLine(L.ABSORB, Skada:FormatNumber(entry.absorbed), 1, 1, 1, 0.45, 1, 0.45)
			end
		end
	end

	function mod:OnEnable()
		deathlogmod.metadata = {
			ordersort = true,
			tooltip = entry_tooltip,
			columns = {Change = true, Health = true, Percent = true},
			icon = [[Interface\Icons\Spell_Shadow_Soulleech_1]]
		}
		playermod.metadata = {click1 = deathlogmod}
		self.metadata = {
			click1 = playermod,
			click4 = Skada.FilterClass,
			click4_label = L["Toggle Class Filter"],
			icon = [[Interface\Icons\ability_rogue_feigndeath]]
		}

		-- no total click.
		playermod.nototal = true

		local flags_dst_nopets = {dst_is_interesting_nopets = true}

		Skada:RegisterForCL(
			AuraApplied,
			"SPELL_AURA_APPLIED",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			SpellDamage,
			"DAMAGE_SHIELD",
			"DAMAGE_SPLIT",
			"RANGE_DAMAGE",
			"SPELL_BUILDING_DAMAGE",
			"SPELL_DAMAGE",
			"SPELL_PERIODIC_DAMAGE",
			"SWING_DAMAGE",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			SpellMissed,
			"DAMAGE_SHIELD_MISSED",
			"RANGE_MISSED",
			"SPELL_BUILDING_MISSED",
			"SPELL_MISSED",
			"SPELL_PERIODIC_MISSED",
			"SWING_MISSED",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			EnvironmentDamage,
			"ENVIRONMENTAL_DAMAGE",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			SpellHeal,
			"SPELL_HEAL",
			"SPELL_PERIODIC_HEAL",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			UnitDied,
			"UNIT_DIED",
			"UNIT_DESTROYED",
			"UNIT_DISSIPATES",
			flags_dst_nopets
		)

		Skada:RegisterForCL(
			SpellResurrect,
			"SPELL_RESURRECT",
			flags_dst_nopets
		)

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:SetComplete(set)
		T.clear(data)

		-- clean deathlogs.
		for _, player in ipairs(set.players) do
			if (set.death or 0) == 0 or (player.death or 0) == 0 then
				player.death, player.deathlog = nil, nil
			elseif player.deathlog then
				while #player.deathlog > (player.death or 0) do
					tremove(player.deathlog, 1)
				end
				if #player.deathlog == 0 then
					player.deathlog = nil
				end
			end
		end
	end

	function mod:AddToTooltip(set, tooltip)
		if (set.death or 0) > 0 then
			tooltip:AddDoubleLine(DEATHS, set.death, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return tostring(set.death or 0)
	end

	function mod:Announce(logs, playername)
		-- announce only if:
		-- 	1. we have a valid deathlog.
		-- 	2. player is not in a pvp (spam caution).
		-- 	3. player is in a group or channel set to self or guild.
		if not logs or IsInPvP() then return end

		local channel = Skada.db.profile.modules.deathchannel
		if channel ~= "SELF" and channel ~= "GUILD" and not IsInGroup() then return end

		local log = nil
		for _, l in ipairs(logs) do
			if l.amount and l.amount < 0 then
				log = l
				break
			end
		end

		if not log then return end

		-- prepare the output.
		local output = format(
			(channel == "SELF") and "%s > %s (%s) %s" or "Skada: %s > %s (%s) %s",
			log.source or L.Unknown, -- source name
			playername or L.Unknown, -- player name
			log.spellid and GetSpellInfo(log.spellid) or L.Unknown, -- spell name
			log.amount and Skada:FormatNumber(0 - log.amount, 1) or 0 -- spell amount
		)

		-- prepare any extra info.
		if log.overkill or log.resisted or log.blocked or log.absorbed then
			local extra = new()

			if log.overkill then
				extra[#extra + 1] = format("O:%s", Skada:FormatNumber(log.overkill, 1))
			end
			if log.resisted then
				extra[#extra + 1] = format("R:%s", Skada:FormatNumber(log.resisted, 1))
			end
			if log.blocked then
				extra[#extra + 1] = format("B:%s", Skada:FormatNumber(log.blocked, 1))
			end
			if log.absorbed then
				extra[#extra + 1] = format("A:%s", Skada:FormatNumber(log.absorbed, 1))
			end
			if next(extra) then
				output = format("%s [%s]", output, tconcat(extra, " - "))
			end

			extra = del(extra)
		end

		Skada:SendChat(output, channel, "preset")
	end

	do
		local options
		local function GetOptions()
			if not options then
				options = {
					type = "group",
					name = mod.moduleName,
					desc = format(L["Options for %s."], L["Death log"]),
					args = {
						header = {
							type = "description",
							name = mod.moduleName,
							fontSize = "large",
							image = [[Interface\Icons\ability_rogue_feigndeath]],
							imageWidth = 18,
							imageHeight = 18,
							imageCoords = {0.05, 0.95, 0.05, 0.95},
							width = "full",
							order = 0
						},
						sep = {
							type = "description",
							name = " ",
							width = "full",
							order = 1,
						},
						deathlog = {
							type = "group",
							name = L["Death log"],
							inline = true,
							order = 10,
							args = {
								deathlogevents = {
									type = "range",
									name = L["Events Amount"],
									desc = L["Set the amount of events the death log should record."],
									min = 4,
									max = 34,
									step = 1,
									order = 10
								},
								deathlogthreshold = {
									type = "range",
									name = L["Minimum Healing"],
									desc = L["Ignore heal events that are below this threshold."],
									min = 0,
									max = 10000,
									step = 1,
									bigStep = 10,
									order = 20
								}
							}
						},
						announce = {
							type = "group",
							name = L["Announce Deaths"],
							inline = true,
							order = 20,
							args = {
								anndesc = {
									type = "description",
									name = L["Announces information about the last hit the player took before they died."],
									fontSize = "medium",
									width = "full",
									order = 10
								},
								deathannounce = {
									type = "toggle",
									name = L["Enable"],
									order = 20
								},
								deathchannel = {
									type = "select",
									name = L["Channel"],
									values = {AUTO = INSTANCE, SELF = L["Self"], GUILD = GUILD},
									order = 30,
									disabled = function()
										return not Skada.db.profile.modules.deathannounce
									end
								}
							}
						}
					}
				}
			end
			return options
		end

		function mod:OnInitialize()
			if Skada.db.profile.modules.deathlogevents == nil then
				Skada.db.profile.modules.deathlogevents = 14
			end
			if Skada.db.profile.modules.deathlogthreshold == nil then
				Skada.db.profile.modules.deathlogthreshold = 1000 -- default
			end
			if Skada.db.profile.modules.deathchannel == nil then
				Skada.db.profile.modules.deathchannel = "AUTO"
			end

			Skada.options.args.modules.args.deathlog = GetOptions()
		end
	end
end)