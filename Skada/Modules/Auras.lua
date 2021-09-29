assert(Skada, "Skada not found!")

-- cache frequently used globals
local pairs, ipairs, format, select, tostring = pairs, ipairs, string.format, select, tostring
local tContains, min, max, floor = tContains, math.min, math.max, math.floor
local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local _

-- we use this custom function in order to round up player
-- active time because of how auras were ticking.
local function PlayerActiveTime(set, player)
	return floor(Skada:PlayerActiveTime(set, player))
end

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local main = Skada:NewModule(L["Buffs and Debuffs"])
do
	function main:OnEnable()
		if not Skada:IsDisabled("Buffs", "Debuffs") then
			Skada.RegisterCallback(self, "COMBAT_PLAYER_TICK", "Tick")
			Skada.RegisterCallback(self, "COMBAT_PLAYER_LEAVE", "Clean")
		end
	end

	function main:OnDisable()
		Skada.UnregisterAllCallbacks(self)
	end

	-- simply adds 1sec to the active spells
	local function auras_tick(set)
		if set then
			for _, player in ipairs(set.players) do
				if player.auras then
					for _, spell in pairs(player.auras) do
						if (spell.active or 0) > 0 then
							spell.uptime = spell.uptime + 1
						end
					end
				end
			end
		end
	end

	function main:Tick(event, current, total)
		if event == "COMBAT_PLAYER_TICK" and current and not current.stopped then
			auras_tick(current)
			auras_tick(total)

			if self.cleaned then
				self.cleaned = nil
			end
		end
	end

	local function setcomplete(set)
		if set then
			local maxtime = Skada:GetSetTime(set)
			for _, player in ipairs(set.players) do
				if player.auras then
					for spellid, spell in pairs(player.auras) do
						spell.active = nil
						if spell.uptime > maxtime then
							spell.uptime = maxtime
						elseif spell.uptime == 0 then
							player.auras[spellid] = nil -- delete 0 uptime
						end
					end
				end
			end
		end
	end

	function main:Clean(event, current, total)
		if not self.cleaned then
			setcomplete(current)
			setcomplete(total)
			self.cleaned = true
		end
	end
end

-- ================================================================== --

--
-- to avoid repeating same functions for both modules, we make
-- make sure to create generic functions that will handle things
--

--
-- common functions to both modules that handle aura apply/remove log
--
local function log_auraapply(set, aura)
	if set and aura then
		local player = Skada:get_player(set, aura.playerid, aura.playername, aura.playerflags)
		if player then
			player.auras = player.auras or {} -- create the table.

			-- save/update aura
			if not player.auras[aura.spellid] then
				player.auras[aura.spellid] = {
					school = aura.spellschool,
					auratype = aura.auratype,
					active = 1,
					uptime = 0,
					count = 1
				}
			else
				player.auras[aura.spellid].active = (player.auras[aura.spellid].active or 0) + 1
				player.auras[aura.spellid].count = (player.auras[aura.spellid].count or 0) + 1
			end

			-- fix the school
			if not player.auras[aura.spellid].school and aura.spellschool then
				player.auras[aura.spellid].school = aura.spellschool
			end

			-- targets for debuffs, sources for buffs
			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.current and aura.auratype == "DEBUFF" and aura.dstName then
				player.auras[aura.spellid].targets = player.auras[aura.spellid].targets or {}
				player.auras[aura.spellid].targets[aura.dstName] = (player.auras[aura.spellid].targets[aura.dstName] or 0) + 1
			end
		end
	end
end

local function log_aurarefresh(set, aura)
	if set and aura then
		local player = Skada:get_player(set, aura.playerid, aura.playername, aura.playerflags)
		if player and player.auras and aura.spellid and player.auras[aura.spellid] and (player.auras[aura.spellid].active or 0) > 0 then
			player.auras[aura.spellid].refresh = (player.auras[aura.spellid].refresh or 0) + 1
		end
	end
end

local function log_auraremove(set, aura)
	if set and aura and aura.spellid then
		local player = Skada:get_player(set, aura.playerid, aura.playername, aura.playerflags)
		if not player or not player.auras or not player.auras[aura.spellid] then return end
		if player.auras[aura.spellid].auratype == aura.auratype and (player.auras[aura.spellid].active or 0) > 0 then
			player.auras[aura.spellid].active = player.auras[aura.spellid].active - 1
			if player.auras[aura.spellid].active < 0 then
				player.auras[aura.spellid].active = 0
			end
		end
	end
end

-- main module update function
local updatefunc
do
	local function countauras(auras, auratype)
		local count, uptime = 0, 0
		for _, spell in pairs(auras or {}) do
			if spell.auratype == auratype then
				count = count + 1
				uptime = uptime + (spell.uptime or 0)
			end
		end
		return count, uptime
	end

	function updatefunc(auratype, win, set, title, mod)
		win.title = title or UNKNOWN
		local settime = Skada:GetSetTime(set)

		if settime > 0 and auratype then
			local maxvalue, nr = 0, 1

			for _, player in ipairs(set.players) do
				local auracount, aurauptime = countauras(player.auras, auratype)

				if auracount > 0 and aurauptime > 0 then
					local maxtime = PlayerActiveTime(set, player)
					local uptime = min(floor(aurauptime / auracount), maxtime)

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = uptime / max(1, maxtime)
					d.valuetext = Skada:FormatValueText(
						auracount,
						mod.metadata.columns.Count,
						Skada:FormatPercent(100 * d.value),
						mod.metadata.columns.Percent
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

-- spells per player list
local function spellupdatefunc(auratype, win, set, playerid, playername, fmt, mod)
	local player = Skada:find_player(set, playerid, playername)
	if player then
		if fmt then -- set window title
			win.title = format(fmt, player.name)
		end

		local maxtime = PlayerActiveTime(set, player)
		if maxtime > 0 and player.auras then
			local maxvalue, nr = 0, 1

			for spellid, spell in pairs(player.auras) do
				if spell.auratype == auratype then
					local uptime = min(maxtime, spell.uptime)
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)
					d.spellschool = spell.school

					d.value = uptime
					d.valuetext = Skada:FormatValueText(
						Skada:FormatTime(d.value),
						mod.metadata.columns.Uptime,
						Skada:FormatPercent(d.value, maxtime),
						mod.metadata.columns.Percent
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

-- used to show tooltip
local function aura_tooltip(win, id, label, tooltip, playerid, playername)
	local set = win:get_selected_set()

	local player = Skada:find_player(set, playerid, playername)
	if player and player.auras then
		local aura = player.auras[id]

		if aura then
			local settime = Skada:GetSetTime(set)

			if settime > 0 then
				local maxtime = Skada:PlayerActiveTime(set, player, true)

				tooltip:AddLine(player.name .. ": " .. label)

				-- add spell school if provided
				if aura.school then
					local c = Skada.schoolcolors[aura.school]
					local n = Skada.schoolnames[aura.school]
					if c and n then
						tooltip:AddLine(n, c.r, c.g, c.b)
					end
				end

				-- add segment and active times
				if aura.count or aura.refresh then
					if (aura.count or 0) > 0 then
						tooltip:AddDoubleLine(L["Count"], aura.count, 1, 1, 1)
					end
					if (aura.refresh or 0) > 0 then
						tooltip:AddDoubleLine(L["Refresh"], aura.refresh or 0, 1, 1, 1)
					end
					tooltip:AddLine(" ")
				end
				tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
				tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(maxtime), 1, 1, 1)
				tooltip:AddDoubleLine(L["Uptime"], Skada:FormatTime(aura.uptime), 1, 1, 1)
			end
		end
	end
end

-- ================================================================== --

Skada:AddLoadableModule("Buffs", function(Skada, L)
	if Skada:IsDisabled("Buffs") then return end

	local mod = Skada:NewModule(L["Buffs"])
	local spellmod = mod:NewModule(L["Buff spell list"])

	local GroupIterator, UnitExists, UnitIsDeadOrGhost = Skada.GroupIterator, UnitExists, UnitIsDeadOrGhost
	local UnitGUID, UnitName, UnitBuff = UnitGUID, UnitName, UnitBuff

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

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's buffs"], label)
	end

	function spellmod:Update(win, set)
		spellupdatefunc("BUFF", win, set, win.playerid, win.playername, L["%s's buffs"], mod)
	end

	function mod:Update(win, set)
		updatefunc("BUFF", win, set, L["Buffs"], mod)
	end

	local function buff_tooltip(win, set, label, tooltip)
		aura_tooltip(win, set, label, tooltip, win.playerid, win.playername)
	end

	local function log_specialtick(set, aura)
		local player = Skada:get_player(set, aura.playerid, aura.playername, aura.playerflags)
		if player then
			player.auras = player.auras or {} -- create the table.
			if not player.auras[aura.spellid] then
				player.auras[aura.spellid] = {
					school = aura.spellschool,
					auratype = "BUFF",
					uptime = 1
				}
			else
				player.auras[aura.spellid].uptime = player.auras[aura.spellid].uptime + 1
			end
		end
	end

	local aura = {}

	local function handleBuff(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, spellschool, auratype)
		if auratype == "BUFF" and not tContains(ignoredSpells, spellid) and Skada:IsPlayer(dstGUID, dstFlags, dstName) then
			if spellid == 27827 then -- Spirit of Redemption (Holy Priest)
				Skada:SendMessage("UNIT_DIED", ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, nil, spellschool, auratype)
				return
			end

			aura.playerid = dstGUID
			aura.playername = dstName
			aura.playerflags = dstFlags

			aura.spellid = spellid
			aura.spellschool = spellschool
			aura.auratype = auratype

			if event == "SPELL_AURA_APPLIED" then
				log_auraapply(Skada.current, aura)
				log_auraapply(Skada.total, aura)
			elseif event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" then
				log_aurarefresh(Skada.current, aura)
				log_aurarefresh(Skada.total, aura)
			elseif event == "SPELL_AURA_REMOVED" then
				log_auraremove(Skada.current, aura)
				log_auraremove(Skada.total, aura)
			end
		elseif event == "SPELL_PERIODIC_ENERGIZE" and speciallist[spellid] and Skada:IsPlayer(dstGUID, dstFlags, dstName) then
			aura.playerid = dstGUID
			aura.playername = dstName
			aura.playerflags = dstFlags

			aura.spellid = spellid
			aura.spellschool = spellschool
			aura.auratype = "BUFF"

			log_specialtick(Skada.current, aura)
			log_specialtick(Skada.total, aura)
		end
	end

	do
		local function CheckUnitBuffs(unit, owner)
			if owner == nil and not UnitIsDeadOrGhost(unit) then
				local dstGUID, dstName = UnitGUID(unit), UnitName(unit)
				for i = 1, 40 do
					local rank, _, _, _, _, _, unitCaster, _, _, spellid = select(2, UnitBuff(unit, i))
					if spellid then
						if unitCaster and rank ~= SPELL_PASSIVE then
							handleBuff(nil, "SPELL_AURA_APPLIED", UnitGUID(unitCaster), UnitName(unitCaster), nil, dstGUID, dstName, nil, spellid, nil, nil, "BUFF")
						end
					else
						break -- no buff at all
					end
				end
			end
		end

		function mod:CheckBuffs(event, set, timestamp)
			if event == "COMBAT_PLAYER_ENTER" and set and not set.stopped then
				GroupIterator(CheckUnitBuffs)
			end
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = buff_tooltip}
		self.metadata = {
			click1 = spellmod,
			columns = {Count = true, Uptime = true, Percent = true},
			icon = "Interface\\Icons\\spell_magic_greaterblessingofkings"
		}

		Skada:RegisterForCL(handleBuff, "SPELL_AURA_APPLIED", {dst_is_interesting = true})
		Skada:RegisterForCL(handleBuff, "SPELL_AURA_REFRESH", {dst_is_interesting = true})
		Skada:RegisterForCL(handleBuff, "SPELL_AURA_APPLIED_DOSE", {dst_is_interesting = true})
		Skada:RegisterForCL(handleBuff, "SPELL_AURA_REMOVED", {dst_is_interesting = true})
		Skada:RegisterForCL(handleBuff, "SPELL_PERIODIC_ENERGIZE", {dst_is_interesting = true})

		Skada.RegisterCallback(self, "COMBAT_PLAYER_ENTER", "CheckBuffs")

		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end
end)

-- ================================================================== --

Skada:AddLoadableModule("Debuffs", function(Skada, L)
	if Skada:IsDisabled("Debuffs") then return end

	local mod = Skada:NewModule(L["Debuffs"])
	local spellmod = mod:NewModule(L["Debuff spell list"])
	local targetmod = spellmod:NewModule(L["Debuff target list"])

	-- list of the auras that are ignored!
	local ignoredSpells = {
		57723, -- Exhaustion (Heroism)
		57724 -- Sated (Bloodlust)
	}

	-- list of spells used to queue units.
	local queuedSpells = {[49005] = 50424}

	local aura = {}

	local function handleDebuff(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
		if auratype == "DEBUFF" and not tContains(ignoredSpells, spellid) then
			if srcName == nil and #srcGUID == 0 and dstName and #dstGUID > 0 then
				srcGUID = dstGUID
				srcName = dstName
				srcFlags = dstFlags
			end

			-- we only record players
			if not Skada:IsPlayer(srcGUID, srcFlags, srcName) then return end

			aura.playerid = srcGUID
			aura.playername = srcName
			aura.playerflags = srcFlags

			aura.dstName = dstName
			aura.spellid = spellid
			aura.spellschool = spellschool
			aura.auratype = auratype

			if event == "SPELL_AURA_APPLIED" then
				log_auraapply(Skada.current, aura)
				log_auraapply(Skada.total, aura)
				Skada:QueueUnit(spellid and queuedSpells[spellid], srcGUID, srcName, srcFlags, dstGUID)
			elseif event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" then
				log_aurarefresh(Skada.current, aura)
				log_aurarefresh(Skada.total, aura)
			elseif event == "SPELL_AURA_REMOVED" then
				log_auraremove(Skada.current, aura)
				log_auraremove(Skada.total, aura)
				Skada:UnqueueUnit(spellid and queuedSpells[spellid], dstGUID)
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.spellid, win.spellname = id, label
		win.title = format(L["%s's <%s> targets"], win.playername or UNKNOWN, label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = format(L["%s's <%s> targets"], player.name, win.spellname or UNKNOWN)

			local total = 0
			if player.auras and player.auras[win.spellid] then
				total = player.auras[win.spellid].count or 0
			end

			if total > 0 and player.auras[win.spellid].targets then
				local maxvalue, nr = 0, 1

				for targetname, count in pairs(player.auras[win.spellid].targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname

					d.value = count
					d.valuetext = Skada:FormatValueText(
						d.value,
						mod.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
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
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's debuffs"], label)
	end

	function spellmod:Update(win, set)
		spellupdatefunc("DEBUFF", win, set, win.playerid, win.playername, L["%s's debuffs"], mod)
	end

	function mod:Update(win, set)
		updatefunc("DEBUFF", win, set, L["Debuffs"], mod)
	end

	local function debuff_tooltip(win, set, label, tooltip)
		aura_tooltip(win, set, label, tooltip, win.playerid, win.playername)
	end

	function mod:OnEnable()
		spellmod.metadata = {post_tooltip = debuff_tooltip, click1 = targetmod, nototalclick = {targetmod}}
		self.metadata = {
			click1 = spellmod,
			columns = {Count = true, Uptime = true, Percent = true},
			icon = "Interface\\Icons\\spell_shadow_shadowwordpain"
		}

		Skada:RegisterForCL(handleDebuff, "SPELL_AURA_APPLIED", {src_is_interesting = true})
		Skada:RegisterForCL(handleDebuff, "SPELL_AURA_REFRESH", {src_is_interesting = true})
		Skada:RegisterForCL(handleDebuff, "SPELL_AURA_APPLIED_DOSE", {src_is_interesting = true})
		Skada:RegisterForCL(handleDebuff, "SPELL_AURA_REMOVED", {src_is_interesting = true})

		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)