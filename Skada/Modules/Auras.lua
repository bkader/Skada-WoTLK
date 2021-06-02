assert(Skada, "Skada not found!")

-- cache frequently used globals
local _pairs, _format, _select, _tostring = pairs, string.format, select, tostring
local math_min, math_max = math.min, math.max
local _GetSpellInfo, _UnitClass = Skada.GetSpellInfo or GetSpellInfo, Skada.UnitClass

-- list of the auras that are ignored!
local blacklist = {
	[57819] = true, -- Tabard of the Argent Crusade
	[57820] = true, -- Tabard of the Ebon Blade
	[57821] = true, -- Tabard of the Kirin Tor
	[57822] = true, -- Tabard of the Wyrmrest Accord
	[72968] = true, -- Precious's Ribbon
	[57723] = true, -- Exhaustion (Heroism)
	[57724] = true -- Sated (Bloodlust)
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
			if not player.auras[aura.spellname] then
				player.auras[aura.spellname] = {
					id = aura.spellid,
					school = aura.spellschool,
					auratype = aura.auratype,
					active = 1,
					uptime = 0,
					count = 1,
					refresh = 0
				}
			else
				player.auras[aura.spellname].active = 1
				player.auras[aura.spellname].count = (player.auras[aura.spellname].count or 0) + 1
			end

			-- fix the school
			if not player.auras[aura.spellname].school and aura.spellschool then
				player.auras[aura.spellname].school = aura.spellschool
			end

			-- targets for debuffs, sources for buffs
			if aura.auratype == "DEBUFF" and aura.dstName then
				player.auras[aura.spellname].targets = player.auras[aura.spellname].targets or {}
				if not player.auras[aura.spellname].targets[aura.dstName] then
					player.auras[aura.spellname].targets[aura.dstName] = {id = aura.dstGUID, flags = aura.dstFlags, count = 1}
				else
					player.auras[aura.spellname].targets[aura.dstName].count = player.auras[aura.spellname].targets[aura.dstName].count + 1
				end
			end
		end
	end
end

local function log_aurarefresh(set, aura)
	if set and aura then
		local player = Skada:get_player(set, aura.playerid, aura.playername, aura.playerflags)
		if player and player.auras and aura.spellname and player.auras[aura.spellname] and player.auras[aura.spellname].active > 0 then
			player.auras[aura.spellname].refresh = (player.auras[aura.spellname].refresh or 0) + 1
		end
	end
end

local function log_auraremove(set, aura)
	if set and aura and aura.spellname then
		local player = Skada:get_player(set, aura.playerid, aura.playername, aura.playerflags)
		if not player or not player.auras or not player.auras[aura.spellname] then return end
		if player.auras[aura.spellname].auratype == aura.auratype and player.auras[aura.spellname].active > 0 then
			player.auras[aura.spellname].active = 0
		end
	end
end

--
-- common functions handling SPELL_AURA_APPLIED and SPELL_AURA_REMOVED
--

local aura = {}

local function AuraApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
	if blacklist[spellid] then return end

	local passed

	if auratype == "DEBUFF" and not Skada:IsDisabled("Debuffs") then
		if Skada:IsPlayer(srcGUID) or Skada:IsPet(srcGUID) then
			aura.playerid = srcGUID
			aura.playername = srcName
			aura.playerflags = srcFlags
			aura.dstGUID = dstGUID
			aura.dstName = dstName
			aura.dstFlags = dstFlags
			passed = true
		end
	elseif auratype == "BUFF" and not Skada:IsDisabled("Buffs") then
		if srcGUID == dstGUID and Skada:IsPlayer(srcGUID) then
			aura.playerid = srcGUID
			aura.playername = srcName
			aura.playerflags = srcFlags
			passed = true
		else
			local pet = Skada:GetPetOwner(srcGUID)
			if pet and pet.id == dstGUID then
				aura.playerid = dstGUID
				aura.playername = dstName
				aura.playerflags = dstFlags
				passed = true
			end
		end
		aura.dstGUID = nil
		aura.dstName = nil
		aura.dstFlags = nil
	end

	if not passed then
		aura = {} -- clean it
		return
	end

	aura.spellid = spellid
	aura.spellname = spellname
	aura.spellschool = spellschool
	aura.auratype = auratype

	Skada:FixPets(aura)
	log_auraapply(Skada.current, aura)
	log_auraapply(Skada.total, aura)
end

local function AuraRefresh(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
	if blacklist[spellid] then return end

	local passed

	if auratype == "DEBUFF" and not Skada:IsDisabled("Debuffs") then
		if Skada:IsPlayer(srcGUID) or Skada:IsPet(srcGUID) then
			aura.playerid = srcGUID
			aura.playername = srcName
			aura.playerflags = srcFlags
			aura.dstGUID = dstGUID
			aura.dstName = dstName
			aura.dstFlags = dstFlags
			passed = true
		end
	elseif auratype == "BUFF" and not Skada:IsDisabled("Buffs") then
		if srcGUID == dstGUID and Skada:IsPlayer(srcGUID) then
			aura.playerid = srcGUID
			aura.playername = srcName
			aura.playerflags = srcFlags
			passed = true
		else
			local pet = Skada:GetPetOwner(srcGUID)
			if pet and pet.id == dstGUID then
				aura.playerid = dstGUID
				aura.playername = dstName
				aura.playerflags = dstFlags
				passed = true
			end
		end
		aura.dstGUID = nil
		aura.dstName = nil
		aura.dstFlags = nil
	end

	if not passed then
		aura = {} -- clean it
		return
	end

	aura.spellid = spellid
	aura.spellname = spellname
	aura.spellschool = spellschool
	aura.auratype = auratype

	Skada:FixPets(aura)
	log_aurarefresh(Skada.current, aura)
	log_aurarefresh(Skada.total, aura)
end

local function AuraRemoved(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
	if blacklist[spellid] then return end

	local passed

	if auratype == "DEBUFF" and not Skada:IsDisabled("Debuffs") then
		if Skada:IsPlayer(srcGUID) or Skada:IsPet(srcGUID) then
			aura.playerid = srcGUID
			aura.playername = srcName
			aura.playerflags = srcFlags
			aura.dstName = dstName
			passed = true
		end
	elseif auratype == "BUFF" and not Skada:IsDisabled("Buffs") then
		if srcGUID == dstGUID and Skada:IsPlayer(srcGUID) then
			aura.playerid = srcGUID
			aura.playername = srcName
			aura.playerflags = srcFlags
			passed = true
		else
			local pet = Skada:GetPetOwner(srcGUID)
			if pet and pet.id == dstGUID then
				aura.playerid = dstGUID
				aura.playername = dstName
				aura.playerflags = dstFlags
				passed = true
			end
		end
		aura.dstName = nil
	end

	if not passed then
		aura = {} -- clean it
		return
	end

	aura.spellid = nil
	aura.spellname = spellname
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
				for _, spell in _pairs(player.auras) do
					if spell.auratype == auratype and (spell.active or 0) == 1 then
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

-- main module update function
local updatefunc
do
	local function countauras(auras, auratype)
		local count, uptime = 0, 0
		for spellname, spell in _pairs(auras or {}) do
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
					local maxtime = Skada:PlayerActiveTime(set, player, true)
					local uptime = aurauptime / auracount

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = Skada:FormatName(player.name, player.id)
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = uptime
					d.valuetext = _format("%u (%.1f%%)", auracount, 100 * uptime / math_max(1, maxtime))

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
			win.title = _format(fmt, player.name)
		end

		local maxtime = Skada:PlayerActiveTime(set, player, true)
		if maxtime > 0 and player.auras then
			local maxvalue, nr = 0, 1

			for spellname, spell in _pairs(player.auras) do
				if spell.auratype == auratype then
					local uptime = math_min(maxtime, spell.uptime)
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spell.id
					d.spellid = spell.id
					d.label = spellname
					d.icon = _select(3, _GetSpellInfo(spell.id))
					d.spellschool = spell.school

					d.value = uptime
					d.valuetext = _format("%.1f%%", 100 * uptime / maxtime)

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
		local aura = player.auras[label]

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
				local maxtime = Skada:PlayerActiveTime(set, player, true)
				for spellname, spell in _pairs(player.auras) do
					if spell.auratype == auratype then
						if spell.active > 0 then
							spell.active = 0
						end
						if spell.uptime > maxtime then
							spell.uptime = maxtime
						elseif spell.uptime == 0 then
							player.auras[spellname] = nil -- delete 0 uptime
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

	local _GetNumRaidMembers, _GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
	local _UnitExists, _UnitIsDeadOrGhost = UnitExists, UnitIsDeadOrGhost
	local _UnitGUID, _UnitName, _UnitBuff = UnitGUID, UnitName, UnitBuff

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's buffs"], label)
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

	local function BuffApplied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
		if auratype == "BUFF" and spellid == 27827 then -- Spirit of Redemption (Holy Priest)
			Skada:SendMessage("UNIT_DIED", ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
		else
			AuraApplied(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
		end
	end

	function mod:CheckBuffs(event, set, timestamp)
		if event == "COMBAT_PLAYER_ENTER" and set and not set.stopped then
			-- let's now check for buffs put before the combat started.
			local prefix, min, max = "raid", 1, _GetNumRaidMembers()
			if max == 0 then
				prefix, min, max = "party", 0, _GetNumPartyMembers()
			end

			for n = min, max do
				local unit = (n == 0) and "player" or prefix .. _tostring(n)
				if _UnitExists(unit) and not _UnitIsDeadOrGhost(unit) then
					local dstGUID, dstName = _UnitGUID(unit), _UnitName(unit)
					for i = 1, 40 do
						local spellname, rank, _, _, _, _, _, unitCaster, _, _, spellid = _UnitBuff(unit, i)
						if spellname and spellid and unitCaster and rank ~= SPELL_PASSIVE and not blacklist[spellid] then
							AuraApplied(nil, nil, _UnitGUID(unitCaster), _UnitName(unitCaster), nil, dstGUID, dstName, nil, spellid, spellname, nil, "BUFF")
						end
					end
				end
			end
		end
	end

	function mod:Tick(event, set)
		if event == "COMBAT_ENCOUNTER_TICK" and set and not set.stopped then
			auras_tick(set, "BUFF")
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
		Skada.RegisterCallback(self, "COMBAT_ENCOUNTER_TICK", "Tick")

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

	local function DebuffApplied(timestamp, eventtype, srcGUID, srcName, _, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
		if srcName == nil and #srcGUID == 0 and dstName and #dstGUID > 0 then
			srcGUID = dstGUID
			srcName = dstName

			if eventtype == "SPELL_AURA_APPLIED" then
				AuraApplied(timestamp, eventtype, srcGUID, srcName, dstFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
			elseif eventtype == "SPELL_AURA_REFRESH" or eventtype == "SPELL_AURA_APPLIED_DOSE" then
				AuraRefresh(timestamp, eventtype, srcGUID, srcName, dstFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
			elseif eventtype == "SPELL_AURA_REMOVED" or eventtype == "SPELL_AURA_REMOVED_DOSE" then
				AuraRemoved(timestamp, eventtype, srcGUID, srcName, dstFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
			end
		end
	end

	function targetmod:Enter(win, id, label)
		win.spellname = label
		win.title = _format(L["%s's <%s> targets"], win.playername or UNKNOWN, label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)

		if player then
			win.title = _format(L["%s's <%s> targets"], player.name, win.spellname or UNKNOWN)

			local total = 0
			if player.auras and player.auras[win.spellname] then
				total = player.auras[win.spellname].count or 0
			end

			if total > 0 and player.auras[win.spellname].targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.auras[win.spellname].targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = _select(2, _UnitClass(d.id, target.flags, set))

					d.value = target.count
					d.valuetext = _format("%u (%.1f%%)", target.count, 100 * target.count / total)

					if target.count > maxvalue then
						maxvalue = target.count
					end

					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's debuffs"], label)
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

	function mod:Tick(event, set)
		if event == "COMBAT_ENCOUNTER_TICK" and set and not set.stopped then
			auras_tick(set, "DEBUFF")
		end
	end

	function mod:OnEnable()
		spellmod.metadata = {post_tooltip = debuff_tooltip, click1 = targetmod}
		self.metadata = {click1 = spellmod, icon = "Interface\\Icons\\spell_shadow_shadowwordpain"}

		Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_APPLIED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_REFRESH", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_APPLIED_DOSE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_REMOVED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(DebuffApplied, "SPELL__AURA_REMOVED_DOSE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})

		Skada.RegisterCallback(self, "COMBAT_ENCOUNTER_TICK", "Tick")
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