local Skada = Skada

local pairs, ipairs, format, tostring = pairs, ipairs, string.format, tostring
local tContains, min, max, floor = tContains, math.min, math.max, math.floor
local UnitExists, UnitName, UnitGUID, UnitBuff = UnitExists, UnitName, UnitGUID, UnitBuff
local UnitIsDeadOrGhost, GroupIterator = UnitIsDeadOrGhost, Skada.GroupIterator
local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local PercentToRGB = Skada.PercentToRGB
local dummyTable = Skada.dummyTable
local setPrototype = Skada.setPrototype
local playerPrototype = Skada.playerPrototype
local cacheTable = Skada.cacheTable
local wipe = wipe
local _

-- common functions
local log_auraapply, log_aurarefresh, log_auraremove
local UpdateFunction, SpellUpdateFunction, aura_tooltip

-- main module that handles common stuff
do
	local L = LibStub("AceLocale-3.0"):GetLocale("Skada")
	local mod = Skada:NewModule(L["Buffs and Debuffs"])

	function mod:OnEnable()
		if not Skada:IsDisabled("Buffs") or not Skada:IsDisabled("Debuffs") then
			Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "Clean")

			-- add player's aura uptime getter.
			playerPrototype.GetAuraUptime = function(self, spellid)
				if self.auras and spellid and self.auras[spellid] and (self.auras[spellid].uptime or 0) > 0 then
					return self.auras[spellid].uptime, self:GetTime()
				end
			end
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
	end

	function mod:Clean(event, set, curtime)
		if event == "COMBAT_PLAYER_LEAVE" and set then
			local maxtime = Skada:GetSetTime(set)
			curtime = curtime or time()

			for _, player in ipairs(set.players) do
				if player.auras then
					for spellid, spell in pairs(player.auras) do
						if spell.active ~= nil and spell.start then
							spell.uptime = min(maxtime, spell.uptime + floor((curtime - spell.start) + 0.5))
							spell.active = nil
							spell.start = nil

							if spell.uptime == 0 then
								-- remove spell with 0 uptime.
								player.auras[spellid] = nil
							elseif spell.targets then
								-- debuff targets
								for name, target in pairs(spell.targets) do
									if target.active ~= nil and target.start then
										target.uptime = min(spell.uptime, target.uptime + floor((curtime - target.start) + 0.5))
									end

									spell.targets[name].active = nil
									spell.targets[name].start = nil

									-- remove targets with 0 uptime.
									if target.uptime == 0 then
										player.auras[spellid].targets[name] = nil
									end

								end

								-- an empty targets table? Remove it
								if next(spell.targets) == nil then
									player.auras[spellid] = nil
								end
							end
						end
					end

					-- remove table if no auras left
					if next(player.auras) == nil then
						player.auras = nil
					end
				end
			end
		end
	end

	-- add functions to segment prototype

	function setPrototype:GetAuraPlayers(spellid, tbl)
		local count = 0
		if spellid and self.players then
			tbl = wipe(tbl or cacheTable)
			for _, p in ipairs(self.players) do
				if p.auras and p.auras[spellid] then
					local maxtime = floor(p:GetTime())
					local uptime = min(maxtime, p.auras[spellid].uptime)
					count = count + 1
					tbl[p.name] = {
						id = p.id,
						class = p.class,
						role = p.role,
						spec = p.spec,
						uptime = uptime,
						maxtime = maxtime
					}
				end
			end
			return tbl, count
		end
		return nil, count
	end

	-- common functions.

	function log_auraapply(set, aura)
		if not (set and aura and aura.spellid) then return end
		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		if player then
			local spell = player.auras and player.auras[aura.spellid]
			if not spell then
				spell = {school = aura.spellschool, type = aura.type, active = 1, count = 1, uptime = 0, start = time()}
				player.auras = player.auras or {}
				player.auras[aura.spellid] = spell
			else
				spell.active = spell.active + 1
				spell.count = spell.count + 1
				spell.start = spell.start or time()

				-- fix missing school
				if not spell.school and aura.spellschool then
					spell.school = aura.spellschool
				end
			end

			-- only records targets for debuffs
			if aura.type == "DEBUFF" and aura.dstName then
				local actor = Skada:GetActor(set, aura.dstGUID, aura.dstName, aura.dstFlags)
				if actor then
					spell.targets = spell.targets or {}
					if not spell.targets[aura.dstName] then
						spell.targets[aura.dstName] = {count = 1, active = 1, uptime = 0, start = time()}
					else
						spell.targets[aura.dstName].count = spell.targets[aura.dstName].count + 1
						spell.targets[aura.dstName].active = (spell.targets[aura.dstName].active or 0) + 1
						spell.targets[aura.dstName].start = spell.targets[aura.dstName].start or time()
					end
				end
			end
		end
	end

	function log_aurarefresh(set, aura)
		if not (set and aura and aura.spellid) then return end
		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		local spell = player and player.auras and player.auras[aura.spellid]

		if spell and (spell.active or 0) > 0 then
			spell.refresh = (spell.refresh or 0) + 1
			if spell.targets and aura.dstName and spell.targets[aura.dstName] then
				spell.targets[aura.dstName].refresh = (spell.targets[aura.dstName].refresh or 0) + 1
			end
		end
	end

	function log_auraremove(set, aura)
		if not (set and aura and aura.spellid) then return end
		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		local spell = player and player.auras and player.auras[aura.spellid]

		if spell and (spell.active or 0) > 0 then
			spell.active = spell.active - 1
			if spell.active == 0 and spell.start then
				spell.uptime = spell.uptime + floor((time() - spell.start) + 0.5)
				spell.start = nil
			end

			-- targets
			if spell.targets and aura.dstName and spell.targets[aura.dstName] and (spell.targets[aura.dstName].active or 0) > 0 then
				spell.targets[aura.dstName].active = spell.targets[aura.dstName].active - 1
				if spell.targets[aura.dstName].active == 0 and spell.targets[aura.dstName].start then
					spell.targets[aura.dstName].uptime = spell.targets[aura.dstName].uptime + floor((time() - spell.targets[aura.dstName].start) + 0.5)
					spell.targets[aura.dstName].start = nil
				end
			end
		end
	end

	do
		local function CountAuras(auras, atype)
			local count, uptime = 0, 0
			for _, spell in pairs(auras or dummyTable) do
				if spell.type == atype and spell.uptime > 0 then
					count = count + 1
					uptime = uptime + spell.uptime
				end
			end
			return count, uptime
		end

		function UpdateFunction(atype, win, set, mode)
			if not atype then return end
			local settime = set and set:GetTime()
			if settime > 0 then
				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for _, player in ipairs(set.players) do
					if not win.class or win.class == player.class then
						local auracount, aurauptime = CountAuras(player.auras, atype)
						if auracount > 0 and aurauptime > 0 then
							nr = nr + 1
							local d = win:nr(nr)

							d.id = player.id or player.name
							d.label = player.name
							d.text = player.id and Skada:FormatName(player.name, player.id)
							d.class = player.class
							d.role = player.role
							d.spec = player.spec

							local maxtime = floor(player:GetTime())
							d.value = min(floor(aurauptime / auracount), maxtime)
							d.valuetext = Skada:FormatValueCols(
								mode.metadata.columns.Uptime and Skada:FormatTime(d.value),
								mode.metadata.columns.Count and auracount,
								mode.metadata.columns.Percent and Skada:FormatPercent(d.value, maxtime)
							)

							if win.metadata and d.value > win.metadata.maxvalue then
								win.metadata.maxvalue = d.value
							end
						end
					end
				end
			end
		end
	end

	function SpellUpdateFunction(atype, win, set, title, mode)
		if not atype then return end
		win.title = title and format(title, win.actorname or L.Unknown) or mode.moduleName or L.Unknown

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		local maxtime = player and player:GetTime() or 0

		if maxtime > 0 and player.auras then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, spell in pairs(player.auras) do
				if spell.type == atype and spell.uptime > 0 then
					nr = nr + 1
					local d = win:nr(nr)

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)
					d.spellschool = spell.school

					d.value = min(maxtime, spell.uptime)
					d.valuetext = Skada:FormatValueCols(
						mode.metadata.columns.Uptime and Skada:FormatTime(d.value),
						mode.metadata.columns.Count and spell.count,
						mode.metadata.columns.Percent and Skada:FormatPercent(d.value, maxtime)
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function aura_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local settime = set and set:GetTime() or 0
		local player = (settime > 0) and set:GetPlayer(win.actorid, win.actorname)
		local aura = player and player.auras and player.auras[id]
		if aura then
			tooltip:AddLine(player.name .. ": " .. label)
			if aura.school and Skada.spellschools[aura.school] then
				tooltip:AddLine(
					Skada.spellschools[aura.school].name,
					Skada.spellschools[aura.school].r,
					Skada.spellschools[aura.school].g,
					Skada.spellschools[aura.school].b
				)
			end
			if aura.count or aura.refresh then
				tooltip:AddDoubleLine(L["Count"], aura.count or 0, 1, 1, 1)
				tooltip:AddDoubleLine(L["Refresh"], aura.refresh or 0 or 0, 1, 1, 1)
				tooltip:AddLine(" ")
			end

			-- add segment and active times
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(player:GetTime(true)), 1, 1, 1)
			tooltip:AddDoubleLine(L["Duration"], Skada:FormatTime(aura.uptime), 1, 1, 1)

			-- display aura uptime in colored percent
			local uptime = 100 * (aura.uptime / player:GetTime())
			tooltip:AddDoubleLine(L["Uptime"], Skada:FormatPercent(uptime), nil, nil, nil, PercentToRGB(uptime))
		end
	end
end

Skada:AddLoadableModule("Buffs", function(L)
	if Skada:IsDisabled("Buffs") then return end

	local mod = Skada:NewModule(L["Buffs"])
	local spellmod = mod:NewModule(L["Buff spell list"])
	local playermod = spellmod:NewModule(L["Players list"])

	-- list of the auras that are ignored!
	local ignoredSpells = {
		57819, -- Tabard of the Argent Crusade
		57820, -- Tabard of the Ebon Blade
		57821, -- Tabard of the Kirin Tor
		57822, -- Tabard of the Wyrmrest Accord
		72968, -- Precious's Ribbon
		57940, -- Essence of Wintergrasp
		-- 73816, -- Hellscream's Warsong (ICC-Horde 5%)
		-- 73818, -- Hellscream's Warsong (ICC-Horde 10%)
		-- 73819, -- Hellscream's Warsong (ICC-Horde 15%)
		-- 73820, -- Hellscream's Warsong (ICC-Horde 20%)
		-- 73821, -- Hellscream's Warsong (ICC-Horde 25%)
		-- 73822, -- Hellscream's Warsong (ICC-Horde 30%)
		-- 73762, -- Hellscream's Warsong (ICC-Alliance 5%)
		-- 73824, -- Hellscream's Warsong (ICC-Alliance 10%)
		-- 73825, -- Hellscream's Warsong (ICC-Alliance 15%)
		-- 73826, -- Hellscream's Warsong (ICC-Alliance 20%)
		-- 73827, -- Hellscream's Warsong (ICC-Alliance 25%)
		-- 73828, -- Hellscream's Warsong (ICC-Alliance 30%)
	}

	-- list of spells that don't trigger SPELL_AURA_x events
	local speciallist = {
		[57669] = true -- Replenishment
	}

	local function log_specialaura(set, aura)
		if not (set and aura and aura.spellid) then return end
		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		if player then
			local spell = player.auras and player.auras[aura.spellid]
			if not spell then
				player.auras = player.auras or {}
				player.auras[aura.spellid] = {school = aura.spellschool, type = "BUFF", uptime = 0}
				spell = player.auras[aura.spellid]
			end
			spell.uptime = spell.uptime + 1
		end
	end

	local aura = {}
	local function HandleBuff(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, spellschool, auratype)
		if
			spellid and -- just in case, you never know!
			not tContains(ignoredSpells, spellid) and
			(auratype == "BUFF" or speciallist[spellid]) and
			Skada:IsPlayer(dstGUID, dstFlags, dstName)
		then
			aura.playerid = dstGUID
			aura.playername = dstName
			aura.playerflags = dstFlags

			aura.dstGUID = nil
			aura.dstName = nil
			aura.dstFlags = nil

			aura.spellid = spellid
			aura.spellschool = spellschool
			aura.type = auratype or "BUFF"

			if event == "SPELL_PERIODIC_ENERGIZE" then
				Skada:DispatchSets(log_specialaura, aura)
			elseif event == "SPELL_AURA_APPLIED" or event == true then
				Skada:DispatchSets(log_auraapply, aura)
			elseif event == "SPELL_AURA_REFRESH" then
				Skada:DispatchSets(log_aurarefresh, aura)
			elseif event == "SPELL_AURA_REMOVED" then
				Skada:DispatchSets(log_auraremove, aura)
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's targets"], label or L.Unknown)
	end

	function playermod:Update(win, set)
		win.title = format(L["%s's targets"], win.spellname or L.Unknown)
		if not (win.spellid and set) then return end

		local players, count = set:GetAuraPlayers(win.spellid)
		if count > 0 then
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

				d.value = player.uptime
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Uptime and Skada:FormatTime(d.value),
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, player.maxtime)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's buffs"], label)
	end

	function spellmod:Update(win, set)
		SpellUpdateFunction("BUFF", win, set, L["%s's buffs"], mod)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Buffs"], L[win.class]) or L["Buffs"]
		UpdateFunction("BUFF", win, set, self)
	end

	do
		local function CheckUnitBuffs(unit, owner)
			if owner == nil and not UnitIsDeadOrGhost(unit) then
				local dstGUID, dstName = UnitGUID(unit), UnitName(unit)
				for i = 1, 40 do
					local _, rank, _, _, _, _, _, unitCaster, _, _, spellid = UnitBuff(unit, i)
					if spellid then
						if unitCaster and rank ~= SPELL_PASSIVE then
							HandleBuff(nil, true, UnitGUID(unitCaster), UnitName(unitCaster), nil, dstGUID, dstName, nil, spellid, nil, nil, "BUFF")
						end
					else
						break -- nothing found!
					end
				end
			end
		end

		function mod:CheckBuffs(event, set)
			if event == "COMBAT_PLAYER_ENTER" and set and not set.stopped then
				GroupIterator(CheckUnitBuffs)
			end
		end
	end

	function mod:OnEnable()
		playermod.metadata = {showspots = true, ordersort = true}
		spellmod.metadata = {valueorder = true, tooltip = aura_tooltip, click1 = playermod}
		self.metadata = {
			click1 = spellmod,
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {spellmod},
			columns = {Uptime = true, Count = false, Percent = true},
			icon = [[Interface\Icons\spell_holy_divinespirit]]
		}

		Skada:RegisterForCL(
			HandleBuff,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_REMOVED",
			"SPELL_PERIODIC_ENERGIZE",
			{dst_is_interesting = true}
		)

		Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER", "CheckBuffs")
		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:AddMode(self)
	end
end)

Skada:AddLoadableModule("Debuffs", function(L)
	if Skada:IsDisabled("Debuffs") then return end

	local mod = Skada:NewModule(L["Debuffs"])
	local spellmod = mod:NewModule(L["Debuff spell list"])
	local spelltargetmod = spellmod:NewModule(L["Debuff target list"])
	local targetmod = mod:NewModule(L["Debuff target list"])
	local targetspellmod = targetmod:NewModule(L["Debuff spell list"])

	-- list of the auras that are ignored!
	local ignoredSpells = {
		57723, -- Exhaustion (Heroism)
		57724 -- Sated (Bloodlust)
	}

	-- list of spells used to queue units.
	local queuedSpells = {[49005] = 50424}

	local aura = {}
	local function HandleDebuff(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, spellschool, auratype)
		if spellid and not tContains(ignoredSpells, spellid) and auratype == "DEBUFF" then
			if srcName == nil and #srcGUID == 0 and dstName and #dstGUID > 0 then
				srcGUID = dstGUID
				srcName = dstName
				srcFlags = dstFlags
			end

			if Skada:IsPlayer(srcGUID, srcFlags, srcName) then
				aura.playerid = srcGUID
				aura.playername = srcName
				aura.playerflags = srcFlags

				aura.dstGUID = dstGUID
				aura.dstName = dstName
				aura.dstFlags = dstFlags

				aura.spellid = spellid
				aura.spellschool = spellschool
				aura.type = "DEBUFF"

				if event == "SPELL_AURA_APPLIED" then
					Skada:DispatchSets(log_auraapply, aura)
					if queuedSpells[spellid] then
						Skada:QueueUnit(queuedSpells[spellid], srcGUID, srcName, srcFlags, dstGUID)
					end
				elseif event == "SPELL_AURA_REFRESH" then
					Skada:DispatchSets(log_aurarefresh, aura)
				elseif event == "SPELL_AURA_REMOVED" then
					Skada:DispatchSets(log_auraremove, aura)
					if queuedSpells[spellid] then
						Skada:UnqueueUnit(queuedSpells[spellid], dstGUID)
					end
				end
			end
		end
	end

	function targetspellmod:Enter(win, id, label)
		win.targetname = label or L.Unknown
		win.title = format(L["%s's debuffs on %s"], win.actorname or L.Unknown, label)
	end

	function targetspellmod:Update(win, set)
		win.title = format(L["%s's debuffs on %s"], win.actorname or L.Unknown, win.targetname or L.Unknown)
		if not win.targetname then return end

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		if not player then return end

		local auras, maxtime = player:GetDebuffsOnTarget(win.targetname)
		if auras and maxtime > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellid, aura in pairs(auras) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)
				d.spellschool = aura.school

				d.value = aura.uptime
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Uptime and Skada:FormatTime(d.value),
					mod.metadata.columns.Count and aura.count,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, maxtime)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function spelltargetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's <%s> targets"], win.actorname or L.Unknown, label)
	end

	function spelltargetmod:Update(win, set)
		win.title = format(L["%s's <%s> targets"], win.actorname or L.Unknown, win.spellname or L.Unknown)
		if not win.spellid then
			return
		end

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		if not player then
			return
		end

		local targets, maxtime = player:GetDebuffTargets(win.spellid)
		if targets and maxtime > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.uptime
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Uptime and Skada:FormatTime(d.value),
					mod.metadata.columns.Count and target.count,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, maxtime)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's targets"], win.actorname or L.Unknown)

		local player = set and set:GetPlayer(win.actorid, win.actorname)
		if not player then return end

		local targets, maxtime = player:GetDebuffsTargets()
		if targets and maxtime > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1
				local d = win:nr(nr)

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.uptime
				d.valuetext = Skada:FormatValueCols(
					mod.metadata.columns.Uptime and Skada:FormatTime(d.value),
					mod.metadata.columns.Count and target.count,
					mod.metadata.columns.Percent and Skada:FormatPercent(d.value, maxtime)
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.actorid, win.actorname = id, label
		win.title = format(L["%s's debuffs"], label)
	end

	function spellmod:Update(win, set)
		SpellUpdateFunction("DEBUFF", win, set, L["%s's debuffs"], mod)
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Debuffs"], L[win.class]) or L["Debuffs"]
		UpdateFunction("DEBUFF", win, set, self)
	end

	function mod:OnEnable()
		spellmod.metadata = {click1 = spelltargetmod, post_tooltip = aura_tooltip}
		targetmod.metadata = {click1 = targetspellmod}
		self.metadata = {
			click1 = spellmod,
			click2 = targetmod,
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {spellmod, targetmod},
			columns = {Uptime = true, Count = false, Percent = true},
			icon = [[Interface\Icons\spell_shadow_shadowwordpain]]
		}

		Skada:RegisterForCL(
			HandleDebuff,
			"SPELL_AURA_APPLIED",
			"SPELL_AURA_REFRESH",
			"SPELL_AURA_REMOVED",
			{src_is_interesting = true}
		)

		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	-- add functions to player's prototype.

	function playerPrototype:GetDebuffsTargets(tbl)
		if self.auras then
			tbl = wipe(tbl or cacheTable)
			local maxtime = 0
			for _, aura in pairs(self.auras) do
				if aura.targets then
					maxtime = maxtime + aura.uptime
					for name, target in pairs(aura.targets) do
						if not tbl[name] then
							tbl[name] = {count = target.count, refresh = target.refresh, uptime = target.uptime}
						else
							tbl[name].count = tbl[name].count + target.count
							tbl[name].uptime = tbl[name].uptime + target.uptime
							if target.refresh then
								tbl[name].refresh = (tbl[name].refresh or 0) + target.refresh
							end
						end

						if not tbl[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								tbl[name].id = actor.id
								tbl[name].class = actor.class
								tbl[name].role = actor.role
								tbl[name].spec = actor.spec
							else
								tbl[name].class = "UNKNOWN"
							end
						end
					end
				end
			end
			return tbl, maxtime
		end
	end

	function playerPrototype:GetDebuffTargets(spellid, tbl)
		if self.auras and spellid and self.auras[spellid] and self.auras[spellid].targets then
			tbl = wipe(tbl or cacheTable)
			local maxtime = self.auras[spellid].uptime
			for name, target in pairs(self.auras[spellid].targets) do
				tbl[name] = {count = target.count, refresh = target.refresh, uptime = target.uptime}
				local actor = self.super:GetActor(name)
				if actor then
					tbl[name].id = actor.id
					tbl[name].class = actor.class
					tbl[name].role = actor.role
					tbl[name].spec = actor.spec
				else
					tbl[name].class = "UNKNOWN"
				end
			end
			return tbl, maxtime
		end
	end

	function playerPrototype:GetDebuffsOnTarget(name, tbl)
		if self.auras and name then
			tbl = wipe(tbl or cacheTable)
			local maxtime = 0
			for spellid, aura in pairs(self.auras) do
				if aura.targets and aura.targets[name] then
					maxtime = maxtime + aura.uptime
					tbl[spellid] = {
						school = aura.school,
						count = aura.targets[name].count,
						refresh = aura.targets[name].refresh,
						uptime = aura.targets[name].uptime
					}
				end
			end
			return tbl, maxtime
		end
	end
end)