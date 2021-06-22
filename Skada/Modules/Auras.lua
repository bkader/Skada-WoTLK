assert(Skada, "Skada not found!")

-- cache frequently used globals
local pairs, format, select, tostring = pairs, string.format, select, tostring
local min, max, floor = math.min, math.max, math.floor
local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
local _

-- list of the auras that are ignored!
local blacklist = {
	[57819] = true, -- Tabard of the Argent Crusade
	[57820] = true, -- Tabard of the Ebon Blade
	[57821] = true, -- Tabard of the Kirin Tor
	[57822] = true, -- Tabard of the Wyrmrest Accord
	[72968] = true, -- Precious's Ribbon
	[57723] = true, -- Exhaustion (Heroism)
	[57724] = true, -- Sated (Bloodlust)
	[57940] = true -- Essence of Wintergrasp
}

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
					count = 1,
					refresh = 0
				}
			else
				player.auras[aura.spellid].active = player.auras[aura.spellid].active + 1
				player.auras[aura.spellid].count = player.auras[aura.spellid].count + 1
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
		if player and player.auras and aura.spellid and player.auras[aura.spellid] and player.auras[aura.spellid].active > 0 then
			player.auras[aura.spellid].refresh = player.auras[aura.spellid].refresh + 1
		end
	end
end

local function log_auraremove(set, aura)
	if set and aura and aura.spellid then
		local player = Skada:get_player(set, aura.playerid, aura.playername, aura.playerflags)
		if not player or not player.auras or not player.auras[aura.spellid] then
			return
		end
		if player.auras[aura.spellid].auratype == aura.auratype and player.auras[aura.spellid].active > 0 then
			player.auras[aura.spellid].active = player.auras[aura.spellid].active - 1
			if player.auras[aura.spellid].active < 0 then
				player.auras[aura.spellid].active = 0
			end
		end
	end
end

--
-- common functions handling SPELL_AURA_APPLIED and SPELL_AURA_REMOVED
--

local aura = {}

local function AuraApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, spellschool, auratype)
	if blacklist[spellid] then return end

	local passed

	if Skada:IsPet(dstGUID, dstFlags) then
		passed = false
	elseif auratype == "DEBUFF" and not Skada:IsDisabled("Debuffs") then
		if Skada:IsPlayer(srcGUID, srcFlags, srcName) then
			aura.playerid = srcGUID
			aura.playername = srcName
			aura.playerflags = srcFlags
			aura.dstGUID = dstGUID
			aura.dstName = dstName
			aura.dstFlags = dstFlags
			passed = true
		end
	elseif auratype == "BUFF" and not Skada:IsDisabled("Buffs") then
		if Skada:IsPlayer(dstGUID, dstFlags, dstName) then
			aura.playerid = dstGUID
			aura.playername = dstName
			aura.playerflags = dstFlags
			aura.dstGUID = nil
			aura.dstName = nil
			aura.dstFlags = nil
			passed = true
		end
	end

	if not passed then
		aura = {} -- clean it
		return
	end

	aura.spellid = spellid
	aura.spellschool = spellschool
	aura.auratype = auratype

	Skada:FixPets(aura)
	log_auraapply(Skada.current, aura)
	log_auraapply(Skada.total, aura)
end

local function AuraRefresh(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, spellschool, auratype)
	if blacklist[spellid] then return end

	local passed

	if Skada:IsPet(dstGUID, dstFlags) then
		passed = false
	elseif auratype == "DEBUFF" and not Skada:IsDisabled("Debuffs") then
		if Skada:IsPlayer(srcGUID, srcFlags, srcName) then
			aura.playerid = srcGUID
			aura.playername = srcName
			aura.playerflags = srcFlags
			aura.dstGUID = dstGUID
			aura.dstName = dstName
			aura.dstFlags = dstFlags
			passed = true
		end
	elseif auratype == "BUFF" and not Skada:IsDisabled("Buffs") then
		if Skada:IsPlayer(dstGUID, dstFlags, dstName) then
			aura.playerid = dstGUID
			aura.playername = dstName
			aura.playerflags = dstFlags
			aura.dstGUID = nil
			aura.dstName = nil
			aura.dstFlags = nil
			passed = true
		end
	end

	if not passed then
		aura = {} -- clean it
		return
	end

	aura.spellid = spellid
	aura.spellschool = spellschool
	aura.auratype = auratype

	Skada:FixPets(aura)
	log_aurarefresh(Skada.current, aura)
	log_aurarefresh(Skada.total, aura)
end

local function AuraRemoved(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, spellschool, auratype)
	if blacklist[spellid] then return end

	local passed

	if Skada:IsPet(dstGUID, dstFlags) then
		passed = false
	elseif auratype == "DEBUFF" and not Skada:IsDisabled("Debuffs") then
		if Skada:IsPlayer(srcGUID, srcFlags, srcName) then
			aura.playerid = srcGUID
			aura.playername = srcName
			aura.playerflags = srcFlags
			aura.dstGUID = dstGUID
			aura.dstName = dstName
			aura.dstFlags = dstFlags
			passed = true
		end
	elseif auratype == "BUFF" and not Skada:IsDisabled("Buffs") then
		if Skada:IsPlayer(dstGUID, dstFlags, dstName) then
			aura.playerid = dstGUID
			aura.playername = dstName
			aura.playerflags = dstFlags
			aura.dstGUID = nil
			aura.dstName = nil
			aura.dstFlags = nil
			passed = true
		end
	end

	if not passed then
		aura = {} -- clean it
		return
	end

	aura.spellid = spellid
	aura.spellschool = nil
	aura.auratype = auratype

	Skada:FixPets(aura)
	log_auraremove(Skada.current, aura)
	log_auraremove(Skada.total, aura)
end

-- ================================================================== --

--
-- simply adds 1sec to the active spells
--
local function auras_tick(set, auratype)
	if set and auratype then
		for _, player in Skada:IteratePlayers(set) do
			if player.auras then
				for _, spell in pairs(player.auras) do
					if spell.auratype == auratype and (spell.active or 0) > 0 then
						spell.uptime = spell.uptime + 1
					end
				end
			end
		end
	end
end

-- ================================================================== --

--
-- to avoid repeating same functions for both modules, we make
-- make sure to create generic functions that will handle things
--

-- we use this custom function in order to round up player
-- active time because of how auras were ticking.
local function PlayerActiveTime(set, player)
	return floor(Skada:PlayerActiveTime(set, player, true))
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

	function updatefunc(auratype, win, set, title)
		win.title = title or UNKNOWN
		local settime = Skada:GetSetTime(set)

		if settime > 0 and auratype then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				local auracount, aurauptime = countauras(player.auras, auratype)

				if auracount > 0 and aurauptime > 0 then
					local maxtime = PlayerActiveTime(set, player)
					local uptime = aurauptime / auracount

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = uptime
					d.valuetext = format("%u (%.1f%%)", auracount, 100 * uptime / max(1, maxtime))

					if uptime > maxvalue then
						maxvalue = uptime
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end
end

-- spells per player list
local function spellupdatefunc(auratype, win, set, playerid, playername, fmt)
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
					d.valuetext = format("%.1f%%", 100 * uptime / maxtime)

					if uptime > maxvalue then
						maxvalue = uptime
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end
end

-- used to show tooltip
local function aura_tooltip(win, id, label, tooltip, playerid, playername, L)
	local set = win:get_selected_set()

	local player = Skada:find_player(set, playerid, playername)
	if player and player.auras then
		local aura = player.auras[id]

		if aura then
			local settime = Skada:GetSetTime(set)

			if settime > 0 then
				local maxtime = PlayerActiveTime(set, player)

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
				tooltip:AddDoubleLine(L["Count"], aura.count, 1, 1, 1)
				tooltip:AddDoubleLine(L["Refresh"], aura.refresh or 0, 1, 1, 1)
				tooltip:AddLine(" ")
				tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
				tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(maxtime), 1, 1, 1)
				tooltip:AddDoubleLine(L["Uptime"], Skada:FormatTime(aura.uptime), 1, 1, 1)
			end
		end
	end
end

-- called on SetComplete to remove active auras
local function setcompletefunc(set, auratype)
	if set and auratype then
		for _, player in Skada:IteratePlayers(set) do
			if player.auras then
				local maxtime = PlayerActiveTime(set, player, true)
				for spellid, spell in pairs(player.auras) do
					if spell.auratype == auratype then
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
end

-- ================================================================== --

Skada:AddLoadableModule("Buffs", function(Skada, L)
	if Skada:IsDisabled("Buffs") then return end

	local mod = Skada:NewModule(L["Buffs"])
	local spellmod = mod:NewModule(L["Buff spell list"])

	local UnitExists, UnitIsDeadOrGhost = UnitExists, UnitIsDeadOrGhost
	local UnitGUID, UnitName, UnitBuff = UnitGUID, UnitName, UnitBuff

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's buffs"], label)
	end

	function spellmod:Update(win, set)
		spellupdatefunc("BUFF", win, set, win.playerid, win.playername, L["%s's buffs"])
	end

	function mod:Update(win, set)
		updatefunc("BUFF", win, set, L["Buffs"])
	end

	local function buff_tooltip(win, set, label, tooltip)
		aura_tooltip(win, set, label, tooltip, win.playerid, win.playername, L)
	end

	local function BuffApplied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, _, spellschool, auratype)
		if auratype == "BUFF" and spellid == 27827 then -- Spirit of Redemption (Holy Priest)
			Skada:SendMessage("UNIT_DIED", ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, nil, spellschool, auratype)
		else
			AuraApplied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, nil, spellschool, auratype)
		end
	end

	function mod:CheckBuffs(event, set, timestamp)
		if event == "COMBAT_PLAYER_ENTER" and set and not set.stopped then
			-- let's now check for buffs put before the combat started.
			local prefix, min_member, max_member = Skada:GetGroupTypeAndCount()

			if prefix then
				for n = min_member, max_member do
					local unit = (n == 0) and "player" or prefix .. tostring(n)
					if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
						local dstGUID, dstName = UnitGUID(unit), UnitName(unit)
						for i = 1, 40 do
							local rank, _, _, _, _, _, unitCaster, _, _, spellid = select(2, UnitBuff(unit, i))
							if spellid then
								if unitCaster and rank ~= SPELL_PASSIVE and not blacklist[spellid] then
									AuraApplied(nil, nil, UnitGUID(unitCaster), UnitName(unitCaster), nil, dstGUID, dstName, nil, spellid, nil, nil, "BUFF")
								end
							else
								break -- no buff at all
							end
						end
					end
				end
			else
				local dstGUID, dstName = UnitGUID("player"), UnitName("player")
				for i = 1, 40 do
					local rank, _, _, _, _, _, unitCaster, _, _, spellid = select(2, UnitBuff("player", i))
					if spellid then
						if unitCaster and rank ~= SPELL_PASSIVE and not blacklist[spellid] then
							AuraApplied(nil, nil, UnitGUID(unitCaster), UnitName(unitCaster), nil, dstGUID, dstName, nil, spellid, nil, nil, "BUFF")
						end
					else
						break -- no buff at all
					end
				end
			end
		end
	end

	function mod:Tick(event, current, total)
		if event == "COMBAT_PLAYER_TICK" and current and not current.stopped then
			auras_tick(current, "BUFF")
			if total then
				auras_tick(total, "BUFF")
			end
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {tooltip = buff_tooltip}
		self.metadata = {click1 = spellmod, icon = "Interface\\Icons\\spell_magic_greaterblessingofkings"}

		Skada:RegisterForCL(BuffApplied, "SPELL_AURA_APPLIED", {src_is_interesting = true})
		Skada:RegisterForCL(AuraRefresh, "SPELL_AURA_REFRESH", {src_is_interesting = true})
		Skada:RegisterForCL(AuraRefresh, "SPELL_AURA_APPLIED_DOSE", {src_is_interesting = true})
		Skada:RegisterForCL(AuraRemoved, "SPELL_AURA_REMOVED", {src_is_interesting = true})

		Skada.RegisterCallback(self, "COMBAT_PLAYER_ENTER", "CheckBuffs")
		Skada.RegisterCallback(self, "COMBAT_PLAYER_TICK", "Tick")

		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	function mod:SetComplete(set)
		setcompletefunc(set, "BUFF")
	end
end)

-- ================================================================== --

Skada:AddLoadableModule("Debuffs", function(Skada, L)
	if Skada:IsDisabled("Debuffs") then return end

	local mod = Skada:NewModule(L["Debuffs"])
	local spellmod = mod:NewModule(L["Debuff spell list"])
	local targetmod = spellmod:NewModule(L["Debuff target list"])

	local function DebuffApplied(ts, event, srcGUID, srcName, _, dstGUID, dstName, dstFlags, spellid, _, spellschool, auratype)
		if srcName == nil and #srcGUID == 0 and dstName and #dstGUID > 0 then
			srcGUID = dstGUID
			srcName = dstName

			if event == "SPELL_AURA_APPLIED" then
				AuraApplied(ts, event, srcGUID, srcName, dstFlags, dstGUID, dstName, dstFlags, spellid, nil, spellschool, auratype)
			elseif event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" then
				AuraRefresh(ts, event, srcGUID, srcName, dstFlags, dstGUID, dstName, dstFlags, spellid, nil, spellschool, auratype)
			elseif event == "SPELL_AURA_REMOVED" or event == "SPELL_AURA_REMOVED_DOSE" then
				AuraRemoved(ts, event, srcGUID, srcName, dstFlags, dstGUID, dstName, dstFlags, spellid, nil, spellschool, auratype)
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
					d.valuetext = format("%u (%.1f%%)", count, 100 * count / total)

					if count > maxvalue then
						maxvalue = count
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
		spellupdatefunc("DEBUFF", win, set, win.playerid, win.playername, L["%s's debuffs"])
	end

	function mod:Update(win, set)
		updatefunc("DEBUFF", win, set, L["Debuffs"])
	end

	local function debuff_tooltip(win, set, label, tooltip)
		aura_tooltip(win, set, label, tooltip, win.playerid, win.playername, L)
	end

	function mod:Tick(event, current, total)
		if event == "COMBAT_PLAYER_TICK" and current and not current.stopped then
			auras_tick(current, "DEBUFF")
			if total then
				auras_tick(total, "DEBUFF")
			end
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {post_tooltip = debuff_tooltip, click1 = targetmod, nototalclick = {targetmod}}
		self.metadata = {click1 = spellmod, icon = "Interface\\Icons\\spell_shadow_shadowwordpain"}

		Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_APPLIED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_REFRESH", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_APPLIED_DOSE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_REMOVED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_REMOVED_DOSE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})

		Skada.RegisterCallback(self, "COMBAT_PLAYER_TICK", "Tick")
		Skada:AddMode(self, L["Buffs and Debuffs"])
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	function mod:SetComplete(set)
		setcompletefunc(set, "DEBUFF")
	end
end)