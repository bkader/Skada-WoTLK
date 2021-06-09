assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Deaths", function(Skada, L)
	if Skada:IsDisabled("Deaths") then return end

	local mod = Skada:NewModule(L["Deaths"])
	local playermod = mod:NewModule(L["Player's deaths"])
	local deathlogmod = mod:NewModule(L["Death log"])

	local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
	local UnitIsFeignDeath = UnitIsFeignDeath
	local tinsert, tremove = table.insert, table.remove
	local tsort, tmaxn, tconcat = table.sort, table.maxn, table.concat
	local ipairs = ipairs
	local tostring, format, strsub = tostring, string.format, string.sub
	local abs, max, modf = math.abs, math.max, math.modf
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local GetspellLink = Skada.GetSpellLink or GetSpellLink
	local date = date
	local _

	local function log_deathlog(set, data, ts)
		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)

		if player then
			-- et player maxhp if not already set
			if (player.maxhp or 0) == 0 then
				player.maxhp = max(UnitHealthMax(player.name) or 0, player.maxhp or 0)
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
				resisted = data.resisted,
				blocked = data.blocked,
				absorbed = data.absorbed,
				time = ts,
				hp = UnitHealth(data.playername)
			})

			-- trim things and limit to 15
			while tmaxn(deathlog.log) > 15 do
				tremove(deathlog.log)
			end
		end
	end

	local data = {}

	local function SpellDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...

		local dstGUID_modified, dstName_modified = Skada:FixMyPets(dstGUID, dstName)

		data.srcGUID = srcGUID
		data.srcName = srcName
		data.srcFlags = srcFlags

		data.playerid = dstGUID_modified or dstGUID
		data.playername = dstName_modified or dstName
		data.playerflags = dstFlags

		data.spellid = spellid
		data.spellname = spellname

		data.amount = 0 - amount
		data.overkill = overkill
		data.resisted = resisted
		data.blocked = blocked
		data.absorbed = absorbed

		log_deathlog(Skada.current, data, ts)
	end

	local function SwingDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local amount, overkill, spellschool, resisted, blocked, absorbed, critical, glancing, crushing = ...

		local dstGUID_modified, dstName_modified = Skada:FixMyPets(dstGUID, dstName)

		data.srcGUID = srcGUID
		data.srcName = srcName
		data.srcFlags = srcFlags

		data.playerid = dstGUID_modified or dstGUID
		data.playername = dstName_modified or dstName
		data.playerflags = dstFlags

		data.spellid = 6603
		data.spellname = L["Auto Attack"]
		data.amount = 0 - amount
		data.overkill = overkill
		data.resisted = resisted
		data.blocked = blocked
		data.absorbed = absorbed

		log_deathlog(Skada.current, data, ts)
	end

	local function EnvironmentDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local envtype = ...
		local spellid, spellname, spellschool

		if envtype == "Falling" or envtype == "FALLING" then
			spellid, spellschool, spellname = 3, 1, ACTION_ENVIRONMENTAL_DAMAGE_FALLING
		elseif envtype == "Drowning" or envtype == "DROWNING" then
			spellid, spellschool, spellname = 4, 1, ACTION_ENVIRONMENTAL_DAMAGE_DROWNING
		elseif envtype == "Fatigue" or envtype == "FATIGUE" then
			spellid, spellschool, spellname = 5, 1, ACTION_ENVIRONMENTAL_DAMAGE_FATIGUE
		elseif envtype == "Fire" or envtype == "FIRE" then
			spellid, spellschool, spellname = 6, 4, ACTION_ENVIRONMENTAL_DAMAGE_FIRE
		elseif envtype == "Lava" or envtype == "LAVA" then
			spellid, spellschool, spellname = 7, 4, ACTION_ENVIRONMENTAL_DAMAGE_LAVA
		elseif envtype == "Slime" or envtype == "SLIME" then
			spellid, spellschool, spellname = 8, 8, ACTION_ENVIRONMENTAL_DAMAGE_SLIME
		end

		if spellid and spellname then
			dstGUID, dstName = Skada:FixMyPets(dstGUID, dstName)
			SpellDamage(timestamp, eventtype, nil, ENVIRONMENTAL_DAMAGE, nil, dstGUID, dstName, dstFlags, spellid, spellname, nil, select(2, ...))
		end
	end

	local function SpellHeal(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, amount, overhealing, absorbed, critical = ...

		local srcGUID_modified, srcName_modified = Skada:FixMyPets(srcGUID, srcName)
		local dstGUID_modified, dstName_modified = Skada:FixMyPets(dstGUID, dstName)

		data.srcGUID = dstGUID_modified or srcGUID
		data.srcName = dstName_modified or srcName
		data.srcFlags = srcFlags

		data.playerid = dstGUID_modified or dstGUID
		data.playername = dstName_modified or dstName
		data.playerflags = dstFlags

		data.spellid = spellid
		data.spellname = spellname
		data.amount = max(0, amount - (overhealing or 0))

		log_deathlog(Skada.current, data, ts)
	end

	local function log_death(set, playerid, playername, playerflags, ts)
		local player = Skada:get_player(set, playerid, playername, playerflags)
		if player then
			set.deaths = (set.deaths or 0) + 1
			player.deaths = (player.deaths or 0) + 1
			player.deathlog = player.deathlog or {}
			if player.deathlog[1] then
				player.deathlog[1].time = ts
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
			return d
		end -- really rare to see .000
		b = strsub(tostring(b), 3, 5)
		return d .. "." .. b
	end

	function deathlogmod:Enter(win, id, label)
		self.index = id
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
			if player and self.index then
				win.title = format(L["%s's death log"], win.playername or UNKNOWN)

				local deathlog
				if player.deathlog and player.deathlog[self.index] then
					deathlog = player.deathlog[self.index]
				end
				if not deathlog then
					return
				end

				win.metadata.maxvalue = player.maxhp

				-- add a fake entry for the actual death
				local nr, pre = 1, win.dataset[nr] or {}
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
					if diff > -30 then
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
						local change = (log.amount > 0 and "+" or "-") .. Skada:FormatNumber(abs(log.amount))
						d.reportlabel =format("%02.2f: %s   %s [%s]", diff or 0, GetspellLink(log.spellid) or spellname or UNKNOWN, change, Skada:FormatNumber(log.hp or 0))

						local extra
						if (log.overkill or 0) > 0 then
							extra = extra or {}
							d.overkill = log.overkill
							tinsert(extra, "O:" .. Skada:FormatNumber(abs(log.overkill)))
						end
						if (log.resisted or 0) > 0 then
							extra = extra or {}
							d.resisted = log.resisted
							tinsert(extra, "R:" .. Skada:FormatNumber(abs(log.resisted)))
						end
						if (log.blocked or 0) > 0 then
							extra = extra or {}
							d.blocked = log.blocked
							tinsert(extra, "B:" .. Skada:FormatNumber(abs(log.blocked)))
						end
						if (log.absorbed or 0) > 0 then
							extra = extra or {}
							d.absorbed = log.absorbed
							tinsert(extra, "A:" .. Skada:FormatNumber(abs(log.absorbed)))
						end

						if extra then
							change = "(|cffff0000*|r) " .. change
							d.reportlabel = d.reportlabel .. " (" .. tconcat(extra, " - ") .. ")"
						end

						d.valuetext = Skada:FormatValueText(
							change,
							self.metadata.columns.Change,
							Skada:FormatNumber(log.hp or 0),
							self.metadata.columns.Health,
							format("%.1f%%", 100 * (log.hp or 1) / (player.maxhp or 1)),
							self.metadata.columns.Percent
						)

						if log.amount > 0 then
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

			if (player.deaths or 0) > 0 and player.deathlog then
				local maxvalue, nr = 0, 1

				for i, death in ipairs(player.deathlog) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = i
					d.time = death.time
					d.icon = "Interface\\Icons\\Ability_Rogue_FeignDeath"

					local dth = death.log[1]

					if dth and dth.spellid then
						d.label, _, d.icon = GetSpellInfo(dth.spellid)
						d.spellid = dth.spellid
					elseif dth and dth.source then
						d.label = dth.source
					else
						d.label = set.name or UNKNOWN
					end

					d.value = dth and dth.time or death.time
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

	function mod:Update(win, set)
		win.title = L["Deaths"]
		local total = set.deaths or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if (player.deaths or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = Skada:FormatName(player.name, player.id)
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = player.deaths
					d.valuetext = tostring(player.deaths)

					if player.deaths > maxvalue then
						maxvalue = player.deaths
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

			if entry.overkill and entry.overkill > 0 then
				tooltip:AddDoubleLine(L["Overkill"], Skada:FormatNumber(entry.overkill), 1, 1, 1)
			end

			if entry.resisted and entry.resisted > 0 then
				tooltip:AddDoubleLine(RESIST, Skada:FormatNumber(entry.resisted), 1, 1, 1)
			end

			if entry.blocked and entry.blocked > 0 then
				tooltip:AddDoubleLine(BLOCK, Skada:FormatNumber(entry.blocked), 1, 1, 1)
			end

			if entry.absorbed and entry.absorbed > 0 then
				tooltip:AddDoubleLine(ABSORB, Skada:FormatNumber(entry.absorbed), 1, 1, 1)
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
		self.metadata = {click1 = playermod, nototalclick = {playermod}, icon = "Interface\\Icons\\ability_rogue_feigndeath"}

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
		for _, player in Skada:IteratePlayers(set) do
			if player.deaths and player.deaths == 0 then
				player.deathlog = nil
			elseif player.deaths and player.deathlog then
				while tmaxn(player.deathlog) > player.deaths do
					tremove(player.deathlog, 1)
				end
			end
		end
	end

	function mod:AddToTooltip(set, tooltip)
		if (set.deaths or 0) > 0 then
			tooltip:AddDoubleLine(DEATHS, set.deaths, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return set.deaths or 0
	end
end)