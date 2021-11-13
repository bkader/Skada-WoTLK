local Skada = Skada

local pairs, ipairs, format, tostring = pairs, ipairs, string.format, tostring
local tContains, min, max, floor = tContains, math.min, math.max, math.floor
local UnitExists, UnitName, UnitGUID, UnitBuff = UnitExists, UnitName, UnitGUID, UnitBuff
local UnitIsDeadOrGhost, GroupIterator = UnitIsDeadOrGhost, Skada.GroupIterator
local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
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
		if not Skada:IsDisabled("Buffs", "Debuffs") then
			Skada.RegisterCallback(self, "Skada_CombatTick", "Tick")
			Skada.RegisterCallback(self, "COMBAT_PLAYER_LEAVE", "Clean")
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
	end

	function mod:Tick(event, set)
		if event == "Skada_CombatTick" and set and not set.stopped then
			for _, player in ipairs(set.players) do
				if player.auras then
					for _, spell in pairs(player.auras) do
						if (spell.active or 0) > 0 then
							spell.uptime = spell.uptime + 1
							if spell.targets then
								for name, target in pairs(spell.targets) do
									if target.active > 0 then
										target.uptime = target.uptime + 1
									end
								end
							end
						end
					end
				end
			end
		end
	end

	function mod:Clean(event, set)
		if event == "COMBAT_PLAYER_LEAVE" and set then
			local maxtime = Skada:GetSetTime(set)
			for _, player in ipairs(set.players) do
				if player.auras then
					for spellid, spell in pairs(player.auras) do
						spell.active = nil -- remove it
						if spell.uptime == 0 then
							player.auras[spellid] = nil -- remove 0 uptime
						else
							-- never exceed settime
							spell.uptime = min(spell.uptime, maxtime)
							-- debuff targets
							if spell.targets then
								for name, target in pairs(spell.targets) do
									target.active = nil -- remove it
									if target.uptime == 0 then
										player.auras[spellid].targets[name] = nil -- remove 0 uptime
									else
										target.uptime = min(target.uptime, spell.uptime)
									end
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

	function setPrototype:GetAuraPlayers(spellid)
		local count = 0
		if spellid and self.players then
			wipe(cacheTable)
			for _, p in ipairs(self.players) do
				if p.auras and p.auras[spellid] then
					local maxtime = floor(p:GetTime())
					local uptime = min(maxtime, p.auras[spellid].uptime)
					count = count + 1
					cacheTable[p.name] = {
						id = p.id,
						class = p.class,
						role = p.role,
						spec = p.spec,
						uptime = uptime,
						maxtime = maxtime
					}
				end
			end
			return cacheTable, count
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
				player.auras = player.auras or {}
				player.auras[aura.spellid] = {school = aura.spellschool, type = aura.type, active = 0, count = 0, uptime = 0}
				spell = player.auras[aura.spellid]
			end

			spell.active = spell.active + 1
			spell.count = spell.count + 1

			-- fix missing school
			if not spell.school and aura.spellschool then
				spell.school = aura.spellschool
			end

			-- only records targets for debuffs
			if aura.type == "DEBUFF" and aura.dstName then
				local actor = Skada:GetActor(set, aura.dstGUID, aura.dstName, aura.dstGUID)
				if actor then
					spell.targets = spell.targets or {}
					if not spell.targets[aura.dstName] then
						spell.targets[aura.dstName] = {count = 1, active = 1, uptime = 0}
					else
						spell.targets[aura.dstName].count = spell.targets[aura.dstName].count + 1
						spell.targets[aura.dstName].active = spell.targets[aura.dstName].active + 1
					end
				end
			end
		end
	end

	function log_aurarefresh(set, aura)
		if not (set and aura and aura.spellid) then return end
		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		if player and player.auras and player.auras[aura.spellid] and player.auras[aura.spellid].active > 0 then
			player.auras[aura.spellid].refresh = (player.auras[aura.spellid].refresh or 0) + 1
			if aura.dstName and player.auras[aura.spellid].targets and player.auras[aura.spellid].targets[aura.dstName] then
				player.auras[aura.spellid].targets[aura.dstName].refresh = (player.auras[aura.spellid].targets[aura.dstName].refresh or 0) + 1
			end
		end
	end

	function log_auraremove(set, aura)
		if not (set and aura and aura.spellid) then return end
		local player = Skada:GetPlayer(set, aura.playerid, aura.playername, aura.playerflags)
		if player and player.auras and player.auras[aura.spellid] and player.auras[aura.spellid].active > 0 then
			player.auras[aura.spellid].active = max(0, player.auras[aura.spellid].active - 1)
			if aura.dstName and player.auras[aura.spellid].targets and player.auras[aura.spellid].targets[aura.dstName] then
				player.auras[aura.spellid].targets[aura.dstName].active = max(0, player.auras[aura.spellid].targets[aura.dstName].active - 1)
			end
		end
	end

	do
		local function CountAuras(auras, atype)
			local count, uptime = 0, 0
			for _, spell in pairs(auras or dummyTable) do
				if spell.type == atype then
					count = count + 1
					if spell.uptime then
						uptime = uptime + spell.uptime
					end
				end
			end
			return count, uptime
		end

		function UpdateFunction(atype, win, set, mode)
			if not atype then return end
			local settime = set and set:GetTime()
			if settime > 0 then
				local maxvalue, nr = 0, 1

				for _, player in ipairs(set.players) do
					local auracount, aurauptime = CountAuras(player.auras, atype)
					if auracount > 0 and aurauptime > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						local maxtime = floor(player:GetTime())
						d.value = min(floor(aurauptime / auracount), maxtime)
						d.valuetext = Skada:FormatValueText(
							Skada:FormatTime(d.value),
							mode.metadata.columns.Uptime,
							auracount,
							mode.metadata.columns.Count,
							Skada:FormatPercent(d.value, maxtime),
							mode.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function SpellUpdateFunction(atype, win, set, title, mode)
		if not atype then return end
		win.title = title and format(title, win.playername or L.Unknown) or mode.moduleName or L.Unknown

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local maxtime = player and player:GetTime() or 0

		if maxtime > 0 and player.auras then
			local maxvalue, nr = 0, 1

			for spellid, spell in pairs(player.auras) do
				if spell.type == atype then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)
					d.spellschool = spell.school

					d.value = min(maxtime, spell.uptime)
					d.valuetext = Skada:FormatValueText(
						Skada:FormatTime(d.value),
						mode.metadata.columns.Uptime,
						spell.count,
						spell.count and mode.metadata.columns.Count,
						Skada:FormatPercent(d.value, maxtime),
						mode.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function aura_tooltip(win, id, label, tooltip)
		local set = win:GetSelectedSet()
		local settime = set and set:GetTime() or 0
		local player = (settime > 0) and set:GetPlayer(win.playerid, win.playername)
		local aura = player and player.auras and player.auras[id]
		if aura then
			tooltip:AddLine(player.name .. ": " .. label)
			if aura.school then
				local c = Skada.schoolcolors[aura.school]
				local n = Skada.schoolnames[aura.school]
				if c and n then
					tooltip:AddLine(n, c.r, c.g, c.b)
				end
			end
			if aura.count or aura.refresh then
				if aura.count then
					tooltip:AddDoubleLine(L["Count"], aura.count, 1, 1, 1)
				end
				if aura.refresh then
					tooltip:AddDoubleLine(L["Refresh"], aura.refresh or 0, 1, 1, 1)
				end
				tooltip:AddLine(" ")
			end

			-- add segment and active times
			tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
			tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(player:GetTime(true)), 1, 1, 1)
			tooltip:AddDoubleLine(L["Uptime"], Skada:FormatTime(aura.uptime), 1, 1, 1)
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
		57940 -- Essence of Wintergrasp
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
			(auratype == "BUFF" or speciallist[spellid]) and
			not tContains(ignoredSpells, spellid) and
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
				log_specialaura(Skada.current, aura)
			elseif event == "SPELL_AURA_APPLIED" or event == true then
				log_auraapply(Skada.current, aura)
			elseif event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" then
				log_aurarefresh(Skada.current, aura)
			elseif event == "SPELL_AURA_REMOVED" then
				log_auraremove(Skada.current, aura)
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
			local maxvalue, nr = 0, 1

			for playername, player in pairs(players) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id or playername
				d.label = playername
				d.text = player.id and Skada:FormatName(playername, player.id)
				d.class = player.class
				d.role = player.role
				d.spec = player.spec

				d.value = player.uptime
				d.valuetext = Skada:FormatValueText(
					Skada:FormatTime(d.value),
					mod.metadata.columns.Uptime,
					Skada:FormatPercent(d.value, player.maxtime),
					mod.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's buffs"], label)
	end

	function spellmod:Update(win, set)
		SpellUpdateFunction("BUFF", win, set, L["%s's buffs"], mod)
	end

	function mod:Update(win, set)
		win.title = L["Buffs"]
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
		spellmod.metadata = {tooltip = aura_tooltip, click1 = playermod}
		self.metadata = {
			click1 = spellmod,
			nototalclick = {spellmod},
			columns = {Uptime = true, Count = true, Percent = true},
			icon = [[Interface\Icons\spell_magic_greaterblessingofkings]]
		}

		Skada:RegisterForCL(HandleBuff, "SPELL_AURA_APPLIED", {dst_is_interesting = true})
		Skada:RegisterForCL(HandleBuff, "SPELL_AURA_REFRESH", {dst_is_interesting = true})
		Skada:RegisterForCL(HandleBuff, "SPELL_AURA_APPLIED_DOSE", {dst_is_interesting = true})
		Skada:RegisterForCL(HandleBuff, "SPELL_AURA_REMOVED", {dst_is_interesting = true})
		Skada:RegisterForCL(HandleBuff, "SPELL_PERIODIC_ENERGIZE", {dst_is_interesting = true})

		Skada.RegisterCallback(self, "COMBAT_PLAYER_ENTER", "CheckBuffs")
		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
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
		if auratype == "DEBUFF" and not tContains(ignoredSpells, spellid) then
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
					log_auraapply(Skada.current, aura)
					if queuedSpells[spellid] then
						Skada:QueueUnit(queuedSpells[spellid], srcGUID, srcName, srcFlags, dstGUID)
					end
				elseif event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" then
					log_aurarefresh(Skada.current, aura)
				elseif event == "SPELL_AURA_REMOVED" then
					log_auraremove(Skada.current, aura)
					if queuedSpells[spellid] then
						Skada:UnqueueUnit(queuedSpells[spellid], dstGUID)
					end
				end
			end
		end
	end

	function targetspellmod:Enter(win, id, label)
		win.targetname = label or L.Unknown
		win.title = format(L["%s's debuffs on %s"], win.playername or L.Unknown, label)
	end

	function targetspellmod:Update(win, set)
		win.title = format(L["%s's debuffs on %s"], win.playername or L.Unknown, win.targetname or L.Unknown)
		if not win.targetname then return end

		local player = set and set:GetPlayer(win.playerid, win.playername)
		if not player then return end

		local auras, maxtime = player:GetDebuffsOnTarget(win.targetname)
		if auras and maxtime > 0 then
			local maxvalue, nr = 0, 1

			for spellid, aura in pairs(auras) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellid
				d.spellid = spellid
				d.label, _, d.icon = GetSpellInfo(spellid)
				d.spellschool = aura.school

				d.value = aura.uptime
				d.valuetext = Skada:FormatValueText(
					Skada:FormatTime(d.value),
					mod.metadata.columns.Uptime,
					aura.count,
					mod.metadata.columns.Count,
					Skada:FormatPercent(d.value, maxtime),
					mod.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function spelltargetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's <%s> targets"], win.playername or L.Unknown, label)
	end

	function spelltargetmod:Update(win, set)
		win.title = format(L["%s's <%s> targets"], win.playername or L.Unknown, win.spellname or L.Unknown)
		if not win.spellid then
			return
		end

		local player = set and set:GetPlayer(win.playerid, win.playername)
		if not player then
			return
		end

		local targets, maxtime = player:GetDebuffTargets(win.spellid)
		if targets and maxtime > 0 then
			local maxvalue, nr = 0, 1

			for targetname, target in pairs(targets) do
				local d = win.metadata[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.uptime
				d.valuetext = Skada:FormatValueText(
					Skada:FormatTime(d.value),
					mod.metadata.columns.Uptime,
					target.count,
					mod.metadata.columns.Count,
					Skada:FormatPercent(d.value, maxtime),
					mod.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's targets"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		if not player then return end

		local targets, maxtime = player:GetDebuffsTargets()
		if targets and maxtime > 0 then
			local maxvalue, nr = 0, 1

			for targetname, target in pairs(targets) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = target.uptime
				d.valuetext = Skada:FormatValueText(
					Skada:FormatTime(d.value),
					mod.metadata.columns.Uptime,
					target.count,
					mod.metadata.columns.Count,
					Skada:FormatPercent(d.value, maxtime),
					mod.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's debuffs"], label)
	end

	function spellmod:Update(win, set)
		SpellUpdateFunction("DEBUFF", win, set, L["%s's debuffs"], mod)
	end

	function mod:Update(win, set)
		win.title = L["Debuffs"]
		UpdateFunction("DEBUFF", win, set, self)
	end

	function mod:OnEnable()
		spellmod.metadata = {click1 = spelltargetmod, post_tooltip = aura_tooltip}
		targetmod.metadata = {click1 = targetspellmod}
		self.metadata = {
			click1 = spellmod,
			click2 = targetmod,
			nototalclick = {spellmod, targetmod},
			columns = {Uptime = true, Count = true, Percent = true},
			icon = [[Interface\Icons\spell_shadow_shadowwordpain]]
		}

		Skada:RegisterForCL(HandleDebuff, "SPELL_AURA_APPLIED", {src_is_interesting = true})
		Skada:RegisterForCL(HandleDebuff, "SPELL_AURA_REFRESH", {src_is_interesting = true})
		Skada:RegisterForCL(HandleDebuff, "SPELL_AURA_APPLIED_DOSE", {src_is_interesting = true})
		Skada:RegisterForCL(HandleDebuff, "SPELL_AURA_REMOVED", {src_is_interesting = true})

		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	-- add functions to player's prototype.

	function playerPrototype:GetDebuffsTargets()
		if self.auras then
			wipe(cacheTable)
			local maxtime = 0
			for _, aura in pairs(self.auras) do
				if aura.targets then
					maxtime = maxtime + aura.uptime
					for name, target in pairs(aura.targets) do
						if not cacheTable[name] then
							cacheTable[name] = {count = target.count, refresh = target.refresh, uptime = target.uptime}
						else
							cacheTable[name].count = cacheTable[name].count + target.count
							cacheTable[name].uptime = cacheTable[name].uptime + target.uptime
							if target.refresh then
								cacheTable[name].refresh = (cacheTable[name].refresh or 0) + target.refresh
							end
						end

						if not cacheTable[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								cacheTable[name].id = actor.id
								cacheTable[name].class = actor.class
								cacheTable[name].role = actor.role
								cacheTable[name].spec = actor.spec
							end
						end
					end
				end
			end
			return cacheTable, maxtime
		end
	end

	function playerPrototype:GetDebuffTargets(spellid)
		if self.auras and spellid and self.auras[spellid] and self.auras[spellid].targets then
			wipe(cacheTable)
			local maxtime = self.auras[spellid].uptime
			for name, target in pairs(self.auras[spellid].targets) do
				cacheTable[name] = {count = target.count, refresh = target.refresh, uptime = target.uptime}
				local actor = self.super:GetActor(name)
				if actor then
					cacheTable[name].id = actor.id
					cacheTable[name].class = actor.class
					cacheTable[name].role = actor.role
					cacheTable[name].spec = actor.spec
				end
			end
			return cacheTable, maxtime
		end
	end

	function playerPrototype:GetDebuffsOnTarget(name)
		if self.auras and name then
			wipe(cacheTable)
			local maxtime = 0
			for spellid, aura in pairs(self.auras) do
				if aura.targets and aura.targets[name] then
					maxtime = maxtime + aura.uptime
					cacheTable[spellid] = {
						school = aura.school,
						count = aura.targets[name].count,
						refresh = aura.targets[name].refresh,
						uptime = aura.targets[name].uptime
					}
				end
			end
			return cacheTable, maxtime
		end
	end
end)