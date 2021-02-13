local Skada = Skada

--
-- cache frequently used globals
--
local _pairs, _ipairs = pairs, ipairs
local _format, _select, _tostring = string.format, select, tostring
local _GetSpellInfo = GetSpellInfo
local math_min, math_max, math_floor = math.min, math.max, math.floor

--
-- common functions to both modules that handle aura apply/remove log
--
local function log_auraapply(set, aura)
	if set then
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
					count = 1
				}
			else
				player.auras[aura.spellname].count = player.auras[aura.spellname].count + 1
				player.auras[aura.spellname].active = player.auras[aura.spellname].active + 1
			end

			-- fix the school
			if not player.auras[aura.spellname].school and aura.spellschool then
				player.auras[aura.spellname].school = aura.spellschool
			end

			-- if it's a debuff, we add the target.
			if aura.auratype == "DEBUFF" and aura.dstName then
				player.auras[aura.spellname].targets = player.auras[aura.spellname].targets or {}
				player.auras[aura.spellname].targets[aura.dstName] = (player.auras[aura.spellname].targets[aura.dstName] or 0) + 1
			end
		end
	end
end

local function log_auraremove(set, aura)
	if set then
		local player = Skada:get_player(set, aura.playerid, aura.playername, aura.playerflags)
		if player and player.auras and aura.spellname and player.auras[aura.spellname] then
	        local a = player.auras[aura.spellname]
	        if a.active > 0 then
	            a.active = a.active - 1
	        end
	    end
    end
end

--
-- common functions handling SPELL_AURA_APPLIED and SPELL_AURA_REMOVED
--

local aura = {}

local function AuraApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    local spellid, spellname, spellschool, auratype = ...

	aura.playerid = srcGUID
    aura.playername = srcName
    aura.playerflags = srcFlags

    if auratype == "DEBUFF" then
		aura.dstGUID = dstGUID
		aura.dstName = dstName
		aura.dstFlags = dstFlags
	else
		aura.dstGUID = nil
		aura.dstName = nil
		aura.dstFlags = nil
    end

    aura.spellid = spellid
    aura.spellname = spellname
    aura.spellschool = spellschool
    aura.auratype = auratype

    Skada:FixPets(aura)
    log_auraapply(Skada.current, aura)
    log_auraapply(Skada.total, aura)
end

local function AuraRemoved(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    local spellid, spellname, spellschool, auratype = ...

    aura.playerid = srcGUID
    aura.playername = srcName
    aura.playerflags = srcFlags

    aura.dstGUID = nil
    aura.dstName = nil
    aura.dstFlags = nil

    aura.spellid = nil
    aura.spellname = spellname
    aura.spellschool = nil
    aura.auratype = nil

    Skada:FixPets(aura)
    log_auraremove(Skada.current, aura)
    log_auraremove(Skada.total, aura)
end

-- ================================================================== --

--
-- simply adds 1sec to the active spells
--
local aurasticker
local function auras_tick(set)
	if set then
		for _, player in _ipairs(set.players) do
			if player.auras then
				for _, spell in _pairs(player.auras) do
					if spell.active > 0 then
						spell.uptime = spell.uptime + 1
					end
				end
			end
		end
	end
end
local function combat_tick()
	if Skada.current then
		auras_tick(Skada.current)
		auras_tick(Skada.total)
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
		for _, spell in _pairs(auras) do
			if spell.auratype == auratype then
				count = count + 1
				uptime = uptime + (spell.uptime or 0)
			end
		end
		return count, uptime
	end

	function updatefunc(auratype, win, set)
		local nr, max = 1, 0
		for _, player in _ipairs(set.players) do
			local auracount, aurauptime = countauras(player.auras or {}, auratype)
			if auracount > 0 then
				local maxtime = Skada:PlayerActiveTime(set, player)
				local uptime = aurauptime / auracount

	            local d = win.dataset[nr] or {}
	            win.dataset[nr] = d

	            d.id = player.id
	            d.label = player.name
	            d.class = player.class
	            d.role = player.role
	            d.spec = player.spec

	            d.value = uptime
	            d.valuetext = _format("%02.1f%% / %u", 100 * uptime / math_max(1, maxtime), auracount)

	            if uptime > max then
	                max = uptime
	            end

	            nr = nr + 1
			end
		end
		win.metadata.maxvalue = max
	end
end

-- spells per player list
local function detailupdatefunc(auratype, win, set, playerid)
    local player = Skada:find_player(set, playerid)
    if player and player.auras then
        local maxtime = Skada:PlayerActiveTime(set, player)
        if maxtime and maxtime > 0 then
            win.metadata.maxvalue = maxtime
            local nr = 1

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
                    d.valuetext = _format("%02.1f%%", 100 * uptime / maxtime)

                    nr = nr + 1
                end
            end
        end
    end
end

-- used to show tooltip
local function aura_tooltip(win, id, label, tooltip, playerid, L)
    local set = win:get_selected_set()
    local player = Skada:find_player(set, playerid)
    if player and player.auras then
        local aura = player.auras[label]
        if aura then
            local totaltime = Skada:PlayerActiveTime(set, player)

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
            tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(totaltime), 1, 1, 1)
            tooltip:AddDoubleLine(L["Uptime"], Skada:FormatTime(aura.uptime), 1, 1, 1)
            tooltip:AddDoubleLine(L["Count"], aura.count, 1, 1, 1)
        end
    end
end

-- called on SetComplete to remove active auras
local function setcompletefunc(set, auratype)
	if set then
		local settime = Skada:GetSetTime(set)
		for _, player in _ipairs(set.players) do
			if player.auras then
				local maxtime = Skada:PlayerActiveTime(set, player)
				for _, spell in _pairs(player.auras) do
					if spell.auratype == auratype then
						if spell.active > 0 then spell.active = 0 end
						if spell.uptime > maxtime then spell.uptime = maxtime end
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
    local _UnitGUID, _UnitName, _UnitAura = UnitGUID, UnitName, UnitAura

    -- list of the auras that are ignored!
	local blacklist = {
		[57819] = true, -- Tabard of the Argent Crusade
		[57820] = true, -- Tabard of the Ebon Blade
		[57821] = true, -- Tabard of the Kirin Tor
		[57822] = true, -- Tabard of the Wyrmrest Accord
		[72968] = true, -- Precious's Ribbon
	}

    function spellmod:Enter(win, id, label)
        self.playerid = id
        self.playername = label
        self.title = _format(L["%s's buffs"], label)
    end

    function spellmod:Update(win, set)
        detailupdatefunc("BUFF", win, set, self.playerid)
    end

    function mod:Update(win, set)
        updatefunc("BUFF", win, set)
    end

    local function buff_tooltip(win, set, label, tooltip)
        aura_tooltip(win, set, label, tooltip, spellmod.playerid, L)
    end

    function mod:OnEnable()
        spellmod.metadata = {tooltip = buff_tooltip}
        self.metadata = {click1 = spellmod}

        Skada:RegisterForCL(AuraApplied, "SPELL_AURA_APPLIED", {src_is_interesting = true})
        Skada:RegisterForCL(AuraRemoved, "SPELL_AURA_REMOVED", {src_is_interesting = true})

        Skada:AddMode(self, L["Buffs and Debuffs"])
        Skada.RegisterCallback(self, "ENCOUNTER_START", "CheckBuffs")
        Skada.RegisterCallback(self, "ENCOUNTER_END", "StopTick")
    end

    function mod:SetComplete(set)
		setcompletefunc(set, "BUFF")
    end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:CheckBuffs(event, timestamp)
		if event == "ENCOUNTER_START" and Skada.current and not Skada.current.stopped then
			-- we start our auras ticker if not started
			if not aurasticker then
				aurasticker = Skada.NewTicker(1, combat_tick)
			end

			-- let's now check for buffs put before the combat started.
			local prefix, min, max = "raid", 1, _GetNumRaidMembers()
			if max == 0 then
				prefix, min, max = "party", 0, _GetNumPartyMembers()
			end

			for n = min, max do
				local unit = (n == 0) and "player" or prefix.._tostring(n)
				if _UnitExists(unit) and not _UnitIsDeadOrGhost(unit) then
					local unitGUID, unitName = _UnitGUID(unit), _select(1, _UnitName(unit))
					for i = 0, 31 do
					local spellname, rank, _, _, _, _, _, unitCaster, _, _, spellid = _UnitAura(unit, i, nil, "BUFF")
						if spellname and spellid and unitCaster and rank ~= SPELL_PASSIVE and not blacklist[spellid] then
							AuraApplied(nil, nil, unitGUID, unitName, nil, nil, nil, nil, spellid, spellname, nil, "BUFF")
						end
					end
				end
			end
		end
	end

	function mod:StopTick(event, set)
		if event == "ENCOUNTER_END" and set then
			if aurasticker then
				aurasticker:Cancel()
				aurasticker = nil
			end
		end
	end
end)

-- ================================================================== --

Skada:AddLoadableModule("Debuffs", function(Skada, L)
    if Skada:IsDisabled("Debuffs") then return end

    local mod = Skada:NewModule(L["Debuffs"])
    local spellmod = mod:NewModule(L["Debuff spell list"])
    local targetmod = mod:NewModule(L["Debuff target list"])

    --
    -- used to record debuffs and rely on AuraApplied and AuraRemoved functions
    --
    local function DebuffApplied(timestamp, eventtype, srcGUID, srcName, _, dstGUID, dstName, dstFlags, ...)
        if srcName == nil and #srcGUID == 0 and dstName and #dstGUID > 0 then
            srcGUID = dstGUID
            srcName = dstName

            if eventtype == "SPELL_AURA_APPLIED" then
                AuraApplied(timestamp, eventtype, srcGUID, srcName, dstFlags, dstGUID, dstName, dstFlags, ...)
            else
                AuraRemoved(timestamp, eventtype, srcGUID, srcName, dstFlags, dstGUID, dstName, dstFlags, ...)
            end
        end
    end

    function targetmod:Enter(win, id, label)
        self.spellname = label
        self.title = _format(L["%s's <%s> targets"], spellmod.playername, label)
    end

    function targetmod:Update(win, set)
        local player = Skada:find_player(set, spellmod.playerid)
        local max = 0
        if player and self.spellname and player.auras[self.spellname] then
            local nr = 1

            local total = player.auras[self.spellname].count

            for targetname, count in _pairs(player.auras[self.spellname].targets) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = targetname
                d.label = targetname

                d.value = count
                d.valuetext = _format("%u (%02.1f%%)", count, 100 * count / total)

                if count > max then
                    max = count
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
    end

    function spellmod:Enter(win, id, label)
        self.playerid = id
        self.playername = label
        self.title = _format(L["%s's debuffs"], label)
    end

    function spellmod:Update(win, set)
        detailupdatefunc("DEBUFF", win, set, self.playerid)
    end

    function mod:Update(win, set)
        updatefunc("DEBUFF", win, set)
    end

    local function debuff_tooltip(win, set, label, tooltip)
        aura_tooltip(win, set, label, tooltip, spellmod.playerid, L)
    end

    function mod:OnEnable()
        spellmod.metadata = {tooltip = debuff_tooltip, click1 = targetmod}
        self.metadata = {click1 = spellmod}

        Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_APPLIED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
        Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_REMOVED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})

        Skada:AddMode(self, L["Buffs and Debuffs"])
        Skada.RegisterCallback(self, "ENCOUNTER_START", "StartTick")
        Skada.RegisterCallback(self, "ENCOUNTER_END", "StopTick")
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
    end

	function mod:SetComplete(set)
		setcompletefunc(set, "DEBUFF")
	end

	function mod:StartTick(event)
		if event == "ENCOUNTER_START" and Skada.current and not Skada.current.stopped then
			if not aurasticker then
				aurasticker = Skada.NewTicker(1, combat_tick)
			end
		end
	end

	function mod:StopTick(event, set)
		if event == "ENCOUNTER_END" and set then
			if aurasticker then
				aurasticker:Cancel()
				aurasticker = nil
			end
		end
	end
end)