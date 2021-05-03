assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Deaths", function(Skada, L)
	if Skada:IsDisabled("Deaths") then return end

	local mod = Skada:NewModule(L["Deaths"])
	local playermod = mod:NewModule(L["Player's deaths"])
	local deathlogmod = mod:NewModule(L["Death log"])

	local _UnitHealth, _UnitHealthMax = UnitHealth, UnitHealthMax
	local _UnitIsFeignDeath = UnitIsFeignDeath
	local table_insert, table_remove = table.insert, table.remove
	local table_sort, table_maxn, table_concat = table.sort, table.maxn, table.concat
	local _ipairs, _select, _next = ipairs, select, next
	local _tostring, _format, _strsub = tostring, string.format, string.sub
	local math_abs, math_max, math_modf = math.abs, math.max, math.modf
	local _GetSpellInfo, _GetspellLink = Skada.GetSpellInfo, GetSpellLink
	local _date = date
	local _

	local function log_deathlog(set, data, ts)
		local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)

		if player then
			-- et player maxhp if not already set
			if player.maxhp == 0 then
				player.maxhp = math_max(_UnitHealthMax(player.name) or 0, player.maxhp or 0)
			end

			-- create a log entry if it doesn't exist.
			player.deathlog = player.deathlog or {}
			if not player.deathlog[1] then
				player.deathlog[1] = {time = 0, log = {}}
			end

			-- record our log
			local deathlog = player.deathlog[1]
			table_insert(deathlog.log, 1, {
				spellid = data.spellid,
				source = data.srcName,
				amount = data.amount,
				overkill = data.overkill,
				resisted = data.resisted,
				blocked = data.blocked,
				absorbed = data.absorbed,
				time = ts,
				hp = _UnitHealth(data.playername)
			})

			-- trim things and limit to 20
			while table_maxn(deathlog.log) > 20 do
				table_remove(deathlog.log)
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
		data.amount = amount

		log_deathlog(Skada.current, data, ts)
	end

	local function log_death(set, playerid, playername, playerflags, ts)
		local player = Skada:get_player(set, playerid, playername, playerflags)
		if player then
			set.deaths = set.deaths + 1
			player.deaths = player.deaths + 1
			if player.deathlog[1] then
				player.deathlog[1].time = ts
			end
		end
	end

	local function UnitDied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if not _UnitIsFeignDeath(dstName) then
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
			table_insert(player.deathlog, 1, {time = 0, log = {}})
		end
	end

	local function SpellResurrect(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		log_resurrect(Skada.current, dstGUID, dstName, dstFlags)
	end

	-- this function was added for a more accurate death time
	-- this is useful in case of someone's death causing others'
	-- death. Example: Sindragosa's unchained magic.
	local function formatdate(ts)
		local a, b = math_modf(ts)
		local d = _date("%H:%M:%S", a or ts)
		if b == 0 then
			return d
		end -- really rare to see .000
		b = _strsub(_tostring(b), 3, 5)
		return d .. "." .. b
	end

	function deathlogmod:Enter(win, id, label)
		self.index = id
		win.title = _format(L["%s's death log"], win.playername or UNKNOWN)
	end

	do
		local green = {r = 0, g = 255, b = 0, a = 1}
		local red = {r = 255, g = 0, b = 0, a = 1}

		local function sort_logs(a, b)
			return a and b and a.time > b.time
		end

		function deathlogmod:Update(win, set)
			local player = Skada:find_player(set, win.playerid)
			win.title = _format(L["%s's death log"], win.playername or UNKNOWN)

			if player and player.deathlog and self.index and player.deathlog[self.index] then
				local deathlog = player.deathlog[self.index]

				-- add a fake entry for the actual death
				local nr, pre = 1, win.dataset[nr] or {}
				win.dataset[nr] = pre

				pre.id = nr
				pre.time = deathlog.time
				pre.label = formatdate(deathlog.time) .. ": " .. _format(L["%s dies"], player.name)
				pre.icon = "Interface\\Icons\\Ability_Rogue_FeignDeath"
				pre.value = 0
				pre.valuetext = ""

				nr = nr + 1

				table_sort(deathlog.log, sort_logs)

				for i, log in _ipairs(deathlog.log) do
					local diff = tonumber(log.time) - tonumber(deathlog.time)
					if diff > -30 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						local spellname, _, spellicon = _GetSpellInfo(log.spellid)

						d.id = nr
						d.spellid = log.spellid
						d.label = _format("%2.2f: %s", diff or 0, spellname or UNKNOWN)
						d.reportlabel = _format("%2.2f: %s", diff or 0, _GetspellLink(log.spellid) or spellname or UNKNOWN)
						d.icon = spellicon
						d.time = log.time

						-- used for tooltip
						d.hp = log.hp
						d.amount = log.amount
						d.source = log.source
						d.spellname = spellname

						d.value = log.hp or 0
						local change = (log.amount > 0 and "+" or "-") .. Skada:FormatNumber(math_abs(log.amount))
						local extra = {}
						if log.overkill and log.overkill > 0 then
							d.overkill = log.overkill
							table_insert(extra, "O: " .. Skada:FormatNumber(math_abs(log.overkill)))
						end
						if log.resisted and log.resisted > 0 then
							d.resisted = log.resisted
							table_insert(extra, "R: " .. Skada:FormatNumber(math_abs(log.resisted)))
						end
						if log.blocked and log.blocked > 0 then
							d.blocked = log.blocked
							table_insert(extra, "B: " .. Skada:FormatNumber(math_abs(log.blocked)))
						end
						if log.absorbed and log.absorbed > 0 then
							d.absorbed = log.absorbed
							table_insert(extra, "A: " .. Skada:FormatNumber(math_abs(log.absorbed)))
						end

						if _next(extra) ~= nil then
							change = change .. " [" .. table_concat(extra, ", ") .. "]"
						end
						d.valuetext = Skada:FormatValueText(
							change,
							self.metadata.columns.Change,
							Skada:FormatNumber(log.hp or 0),
							self.metadata.columns.Health,
							_format("%02.1f%%", (log.hp or 1) / (player.maxhp or 1) * 100),
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

				win.metadata.maxvalue = player.maxhp
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's deaths"], label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid)
		local max = 0

		if player and player.deathlog then
			win.title = _format(L["%s's deaths"], player.name)

			local nr = 1
			for i, death in _ipairs(player.deathlog) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = i
				d.time = death.time
				d.icon = "Interface\\Icons\\Ability_Rogue_FeignDeath"

				local dth = death.log[1]

				if dth and dth.spellid then
					d.label, _, d.icon = _GetSpellInfo(dth.spellid)
					d.spellid = dth.spellid
				elseif dth and dth.source then
					d.label = dth.source
				else
					d.label = set.name or UNKNOWN
				end

				d.value = dth and dth.time or death.time
				d.valuetext = formatdate(d.value)

				if d.value > max then
					max = d.value
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
	end

	function mod:Update(win, set)
		local nr, max = 1, 0

		for _, player in _ipairs(set.players) do
			if player.deaths > 0 then
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = player.name
				d.class = player.class or "PET"
				d.role = player.role or "DAMAGER"
				d.spec = player.spec or 1

				d.value = player.deaths
				d.valuetext = _tostring(player.deaths)

				if player.deaths > max then
					max = player.deaths
				end

				nr = nr + 1
			end
		end

		win.metadata.maxvalue = max
		win.title = L["Deaths"]
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
				tooltip:AddDoubleLine("Overkill", Skada:FormatNumber(entry.overkill), 1, 1, 1)
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
		mod.metadata = {click1 = playermod}

		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellHeal, "SPELL_HEAL", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellHeal, "SPELL_PERIODIC_HEAL", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(UnitDied, "UNIT_DIED", {dst_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellResurrect, "SPELL_RESURRECT", {dst_is_interesting_nopets = true})
		Skada.RegisterMessage(self, "UNIT_DIED")

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
		Skada.UnregisterAllMessages(self)
	end

	function mod:SetComplete(set)
		for _, player in _ipairs(set.players) do
			if player.deaths == 0 then
				player.deathlog = nil
			elseif player.deathlog then
				while table_maxn(player.deathlog) > player.deaths do
					table_remove(player.deathlog, 1)
				end
			end
		end
	end

	function mod:AddToTooltip(set, tooltip)
		if set.deaths > 0 then
			tooltip:AddDoubleLine(DEATHS, set.deaths, 1, 1, 1)
		end
	end

	function mod:GetSetSummary(set)
		return set.deaths
	end

	function mod:AddPlayerAttributes(player, set)
		if not player.deaths then
			player.deaths = 0
			player.maxhp = math_max(_UnitHealthMax(player.name) or 0, player.maxhp or 0)
			player.deathlog = {}
		end
	end

	function mod:AddSetAttributes(set)
		set.deaths = set.deaths or 0
	end
end)