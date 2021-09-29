assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Deaths", function(Skada, L)
	if Skada:IsDisabled("Deaths") then return end

	local mod = Skada:NewModule(L["Deaths"])
	local playermod = mod:NewModule(L["Player's deaths"])
	local deathlogmod = mod:NewModule(L["Death log"])

	local UnitHealth, UnitHealthInfo = UnitHealth, Skada.UnitHealthInfo
	local UnitIsFeignDeath = UnitIsFeignDeath
	local tinsert, tremove = table.insert, table.remove
	local tsort, tmaxn, tconcat = table.sort, table.maxn, table.concat
	local ipairs = ipairs
	local tostring, format, strsub = tostring, string.format, string.sub
	local abs, max, modf = math.abs, math.max, math.modf
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local GetspellLink = Skada.GetSpellLink or GetSpellLink
	local newTable, delTable = Skada.newTable, Skada.delTable
	local IsInGroup, IsInPvP = Skada.IsInGroup, Skada.IsInPvP
	local date, log, _ = date

	local function log_deathlog(set, data, ts)
		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)

		if player then
			-- et player maxhp if not already set
			if (player.maxhp or 0) == 0 then
				player.maxhp = max(select(3, UnitHealthInfo(player.name, player.id, "group")) or 0, player.maxhp or 0)
			end

			-- create a log entry if it doesn't exist.
			player.deathlog = player.deathlog or {}
			if not player.deathlog[1] then
				player.deathlog[1] = {time = 0, log = {}}
			end

			-- record our log
			local deathlog = player.deathlog[1]
			tinsert(deathlog.log, 1, {
				spellid = data.spellid,
				source = data.srcName,
				amount = data.amount,
				overkill = data.overkill,
				overheal = data.overheal,
				resisted = data.resisted,
				blocked = data.blocked,
				absorbed = data.absorbed,
				time = ts,
				hp = UnitHealth(data.playername)
			})

			-- trim things and limit to 14 (custom value now)
			while tmaxn(deathlog.log) > (Skada.db.profile.modules.deathlogevents or 14) do
				tremove(deathlog.log)
			end
		end
	end

	local data = {}

	local function SpellDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, _, _, amount, overkill, _, resisted, blocked, absorbed = ...

		data.srcGUID = srcGUID
		data.srcName = srcName

		data.playerid = dstGUID
		data.playername = dstName
		data.playerflags = dstFlags

		data.spellid = spellid
		data.amount = 0 - amount
		data.overkill = overkill
		data.overheal = nil
		data.resisted = resisted
		data.blocked = blocked
		data.absorbed = absorbed

		log_deathlog(Skada.current, data, ts)
	end

	local function SwingDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, MELEE, nil, ...)
	end

	local function EnvironmentDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local envtype = ...
		local spellid

		if envtype == "Falling" or envtype == "FALLING" then
			spellid = 3
		elseif envtype == "Drowning" or envtype == "DROWNING" then
			spellid = 4
		elseif envtype == "Fatigue" or envtype == "FATIGUE" then
			spellid = 5
		elseif envtype == "Fire" or envtype == "FIRE" then
			spellid = 6
		elseif envtype == "Lava" or envtype == "LAVA" then
			spellid = 7
		elseif envtype == "Slime" or envtype == "SLIME" then
			spellid = 8
		end

		if spellid then
			SpellDamage(ts, event, nil, ENVIRONMENTAL_DAMAGE, nil, dstGUID, dstName, dstFlags, spellid, nil, nil, select(2, ...))
		end
	end

	local function SpellHeal(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, _, _, amount, overheal = ...
		if amount > (Skada.db.profile.modules.deathlogthreshold or 0) then
			srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)
			dstGUID, dstName = Skada:FixMyPets(dstGUID, dstName, dstFlags)

			data.srcGUID = srcGUID
			data.srcName = srcName

			data.playerid = dstGUID
			data.playername = dstName
			data.playerflags = dstFlags

			data.spellid = spellid
			data.amount = max(0, amount - (overheal or 0))
			data.overheal = overheal
			data.overkill = nil
			data.resisted = nil
			data.blocked = nil
			data.absorbed = nil

			log_deathlog(Skada.current, data, ts)
		end
	end

	local function log_death(set, playerid, playername, playerflags, ts)
		local player = Skada:get_player(set, playerid, playername, playerflags)
		if player then
			set.death = (set.death or 0) + 1
			player.death = (player.death or 0) + 1
			if set == Skada.current then
				player.deathlog = player.deathlog or {}
				if player.deathlog[1] then
					player.deathlog[1].time = ((ts or 0) <= 0) and time() or ts

					-- announce death
					if Skada.db.profile.modules.deathannounce and IsInGroup() and not IsInPvP() then
						for _, l in ipairs(player.deathlog[1].log) do
							if l.amount and l.amount < 0 then
								log = l
								break
							end
						end
						if not log then return end

						local output = format("Skada: %s > %s (%s) %s", log.source or UNKNOWN, player.name or UNKNOWN, GetSpellInfo(log.spellid) or UNKNOWN, Skada:FormatNumber(0 - log.amount, 1))
						if log.overkill or log.resisted or log.blocked or log.absorbed then
							output = output .. " ["
							local extra = newTable()
							if log.overkill then
								tinsert(extra, "O:" .. Skada:FormatNumber(log.overkill, 1))
							end
							if log.resisted then
								tinsert(extra, "R:" .. Skada:FormatNumber(log.resisted, 1))
							end
							if log.blocked then
								tinsert(extra, "B:" .. Skada:FormatNumber(log.blocked, 1))
							end
							if log.absorbed then
								tinsert(extra, "A:" .. Skada:FormatNumber(log.absorbed, 1))
							end
							output = output .. tconcat(extra, " - ") .. "]"
							delTable(extra)
						end

						if Skada.db.profile.modules.deathchannel == "SELF" then
							Skada:SendChat(output, nil, "self")
						elseif Skada.db.profile.modules.deathchannel == "GUILD" then
							Skada:SendChat(output, "GUILD", "preset")
						else
							Skada:SendChat(output, IsInRaid() and "RAID" or "PARTY", "preset")
						end
					end
				end
			end
		end
	end

	local function UnitDied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if not UnitIsFeignDeath(dstName) then
			log_death(Skada.current, dstGUID, dstName, dstFlags, ts)
			log_death(Skada.total, dstGUID, dstName, dstFlags, ts)
		end
	end

	--
	-- this function can be called using Skada:SendMessage function.
	--
	function mod:UNIT_DIED(event, ...)
		UnitDied(...)
	end

	local function log_resurrect(set, playerid, playername, playerflags)
		local player = Skada:get_player(set, playerid, playername, playerflags)
		if player then
			player.deathlog = player.deathlog or {}
			tinsert(player.deathlog, 1, {time = 0, log = {}})
		end
	end

	local function SpellResurrect(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		log_resurrect(Skada.current, dstGUID, dstName, dstFlags)
	end

	-- this function was added for a more accurate death time
	-- this is useful in case of someone's death causing others'
	-- death. Example: Sindragosa's unchained magic.
	local function formatdate(ts)
		local a, b = modf(ts)
		local d = date("%H:%M:%S", a or ts)
		if b == 0 then
			return d .. ".000"
		end -- really rare to see .000
		b = strsub(tostring(b), 3, 5)
		return d .. "." .. b
	end

	function deathlogmod:Enter(win, id, label)
		win.datakey = id
		win.title = format(L["%s's death log"], win.playername or UNKNOWN)
	end

	do
		local green = {r = 0, g = 255, b = 0, a = 1}
		local red = {r = 255, g = 0, b = 0, a = 1}

		local function sort_logs(a, b)
			return a and b and a.time > b.time
		end

		function deathlogmod:Update(win, set)
			local player = Skada:find_player(set, win.playerid, win.playername)
			if player and win.datakey then
				win.title = format(L["%s's death log"], win.playername or UNKNOWN)

				local deathlog
				if player.deathlog and player.deathlog[win.datakey] then
					deathlog = player.deathlog[win.datakey]
				end
				if not deathlog then
					return
				end

				win.metadata.maxvalue = player.maxhp

				-- add a fake entry for the actual death
				local nr = 1
				local pre = win.dataset[nr] or {}
				win.dataset[nr] = pre

				pre.id = nr
				pre.time = deathlog.time
				pre.label = formatdate(deathlog.time) .. ": " .. format(L["%s dies"], player.name)
				pre.icon = "Interface\\Icons\\Ability_Rogue_FeignDeath"
				pre.value = 0
				pre.valuetext = ""

				nr = nr + 1

				tsort(deathlog.log, sort_logs)

				for i, log in ipairs(deathlog.log) do
					local diff = tonumber(log.time) - tonumber(deathlog.time)
					if diff > -60 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						local spellname, _, spellicon = GetSpellInfo(log.spellid)

						d.id = nr
						d.spellid = log.spellid
						d.label = format("%02.2f: %s", diff or 0, spellname or UNKNOWN)
						d.icon = spellicon
						d.time = log.time

						-- used for tooltip
						d.hp = log.hp
						d.amount = log.amount
						d.source = log.source
						d.spellname = spellname

						d.value = log.hp or 0
						local change = (log.amount >= 0 and "+" or "-") .. Skada:FormatNumber(abs(log.amount))
						d.reportlabel = format("%02.2f: %s   %s [%s]", diff or 0, GetspellLink(log.spellid) or spellname or UNKNOWN, change, Skada:FormatNumber(log.hp or 0))

						local extra = newTable()

						if (log.overkill or 0) > 0 then
							d.overkill = log.overkill
							tinsert(extra, "O:" .. Skada:FormatNumber(abs(log.overkill)))
						end
						if (log.resisted or 0) > 0 then
							d.resisted = log.resisted
							tinsert(extra, "R:" .. Skada:FormatNumber(abs(log.resisted)))
						end
						if (log.blocked or 0) > 0 then
							d.blocked = log.blocked
							tinsert(extra, "B:" .. Skada:FormatNumber(abs(log.blocked)))
						end
						if (log.absorbed or 0) > 0 then
							d.absorbed = log.absorbed
							tinsert(extra, "A:" .. Skada:FormatNumber(abs(log.absorbed)))
						end

						if next(extra) then
							change = "(|cffff0000*|r) " .. change
							d.reportlabel = d.reportlabel .. " (" .. tconcat(extra, " - ") .. ")"
						end

						delTable(extra)

						d.valuetext = Skada:FormatValueText(
							change,
							self.metadata.columns.Change,
							Skada:FormatNumber(log.hp or 0),
							self.metadata.columns.Health,
							Skada:FormatPercent(log.hp or 1, player.maxhp or 1),
							self.metadata.columns.Percent
						)

						if log.amount >= 0 then
							d.color = green
						else
							d.color = red
						end
						nr = nr + 1
					end
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's deaths"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)

		if player then
			win.title = format(L["%s's deaths"], player.name)

			if (player.death or 0) > 0 and player.deathlog then
				local maxvalue, nr = 0, 1

				for i, death in ipairs(player.deathlog) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = i
					d.time = death.time
					d.icon = "Interface\\Icons\\Ability_Rogue_FeignDeath"

					for k, v in ipairs(death.log) do
						if v.amount and v.amount < 0 and (v.spellid or v.source) then
							if v.spellid then
								d.label, _, d.icon = GetSpellInfo(v.spellid)
								d.spellid = v.spellid
							elseif v.source then
								d.label = v.source
							end
							break
						end
					end

					d.label = d.label or set.name or UNKNOWN

					d.value = death.time
					d.valuetext = formatdate(d.value)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	local function fixdeathtime(timestamp, player)
		if timestamp <= 0 and player.deathlog[1].log[1] then
			player.deathlog[1].time = player.deathlog[1].log[1].time + 25
			timestamp = player.deathlog[1].time
		end
		return timestamp
	end

	function mod:Update(win, set)
		win.title = L["Deaths"]
		local total = set.death or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				if (player.death or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					if player.deathlog then
						d.value = fixdeathtime(player.deathlog[1].time, player)
						d.valuetext = Skada:FormatValueText(
							Skada:FormatTime(d.value - set.starttime),
							self.metadata.columns.Survivability,
							player.death,
							self.metadata.columns.Count
						)
					else
						d.value = player.death
						d.valuetext = tostring(player.death)
					end

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	local function entry_tooltip(win, id, label, tooltip)
		local entry = win.dataset[id]
		if entry and entry.spellname then
			tooltip:AddLine(L["Spell details"] .. " - " .. formatdate(entry.time))
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
				tooltip:AddDoubleLine(L["Overkill"], Skada:FormatNumber(entry.overkill), 1, 1, 1)
			elseif (entry.overheal or 0) > 0 then
				tooltip:AddDoubleLine(L["Overheal"], Skada:FormatNumber(entry.overheal), 1, 1, 1)
			end

			if (entry.resisted or 0) > 0 then
				tooltip:AddDoubleLine(L.RESIST, Skada:FormatNumber(entry.resisted), 1, 1, 1)
			end

			if (entry.blocked or 0) > 0 then
				tooltip:AddDoubleLine(L.BLOCK, Skada:FormatNumber(entry.blocked), 1, 1, 1)
			end

			if (entry.absorbed or 0) > 0 then
				tooltip:AddDoubleLine(L.ABSORB, Skada:FormatNumber(entry.absorbed), 1, 1, 1)
			end
		end
	end

	function mod:OnEnable()
		deathlogmod.metadata = {
			ordersort = true,
			tooltip = entry_tooltip,
			columns = {Change = true, Health = true, Percent = true}
		}
		playermod.metadata = {click1 = deathlogmod}
		self.metadata = {
			click1 = playermod,
			nototalclick = {playermod},
			columns = {Survivability = false, Count = true},
			icon = "Interface\\Icons\\ability_rogue_feigndeath"
		}

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_EXTRA_ATTACKS", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(EnvironmentDamage, "ENVIRONMENTAL_DAMAGE", {dst_is_interesting_nopets = true})

		Skada:RegisterForCL(SpellHeal, "SPELL_HEAL", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellHeal, "SPELL_PERIODIC_HEAL", {dst_is_interesting_nopets = true})

		Skada:RegisterForCL(UnitDied, "UNIT_DIED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(UnitDied, "UNIT_DESTROYED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellResurrect, "SPELL_RESURRECT", {dst_is_interesting_nopets = true})
		Skada.RegisterMessage(self, "UNIT_DIED")
		Skada.RegisterMessage(self, "UNIT_DESTROYED", "UNIT_DIED")

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	function mod:SetComplete(set)
		for _, player in ipairs(set.players) do
			if (player.death or 0) == 0 then
				player.deathlog, player.maxhp = nil, nil
			elseif player.deathlog then
				while tmaxn(player.deathlog) > (player.death or 0) do
					tremove(player.deathlog, 1)
				end
				if #player.deathlog == 0 then
					player.deathlog = nil
				else
					-- fix stupid 0 death timestamp
					for i, v in ipairs(player.deathlog) do
						if v.time <= 0 and v.log[1] then
							player.deathlog[i].time = v.log[1].time or time()
						end
					end
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

	do
		local options
		local function GetOptions()
			if not options then
				options = {
					type = "group",
					name = mod.moduleName,
					desc = format(L["Options for %s."], L["Death log"]),
					get = function(i)
						return Skada.db.profile.modules[i[#i]]
					end,
					set = function(i, val)
						Skada.db.profile.modules[i[#i]] = val
					end,
					args = {
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
									max = 24,
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
				Skada.db.profile.modules.deathlogthreshold = 0
			end
			if Skada.db.profile.modules.deathchannel == nil then
				Skada.db.profile.modules.deathchannel = "AUTO"
			end

			Skada.options.args.modules.args.deathlog = GetOptions()
		end
	end
end)