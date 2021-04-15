assert(Skada, "Skada not found!")

-- cache frequently used globals
local _pairs, _ipairs = pairs, ipairs
local _format, _select, _tostring = string.format, select, tostring
local _GetSpellInfo = Skada.GetSpellInfo
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
                    count = 1,
                    refresh = 0
                }
            else
                player.auras[aura.spellname].active = 1
                player.auras[aura.spellname].count = player.auras[aura.spellname].count + 1
            end

            -- fix the school
            if not player.auras[aura.spellname].school and aura.spellschool then
                player.auras[aura.spellname].school = aura.spellschool
            end

            -- targets for debuffs, sources for buffs
            if aura.auratype == "DEBUFF" and aura.dstName then
                player.auras[aura.spellname].targets = player.auras[aura.spellname].targets or {}
                player.auras[aura.spellname].targets[aura.dstName] = (player.auras[aura.spellname].targets[aura.dstName] or 0) + 1
            end
        end
    end
end

local function log_aurarefresh(set, aura)
    if set then
        local player = Skada:get_player(set, aura.playerid, aura.playername, aura.playerflags)
        if player and player.auras and aura.spellname and player.auras[aura.spellname] and player.auras[aura.spellname].active > 0 then
            player.auras[aura.spellname].refresh = (player.auras[aura.spellname].refresh or 0) + 1
        end
    end
end

local function log_auraremove(set, aura)
    if set and aura.spellname then
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
    local passed = false

    if auratype == "DEBUFF" then
        if Skada:IsPlayer(srcGUID) or Skada:IsPet(srcGUID) then
            aura.playerid = srcGUID
            aura.playername = srcName
            aura.playerflags = srcFlags
            aura.dstName = dstName
            passed = true
        end
    elseif auratype == "BUFF" then
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

    aura.spellid = spellid
    aura.spellname = spellname
    aura.spellschool = spellschool
    aura.auratype = auratype

    Skada:FixPets(aura)
    log_auraapply(Skada.current, aura)
    log_auraapply(Skada.total, aura)
end

local function AuraRefresh(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
    local passed = false

    if auratype == "DEBUFF" then
        if Skada:IsPlayer(srcGUID) or Skada:IsPet(srcGUID) then
            aura.playerid = srcGUID
            aura.playername = srcName
            aura.playerflags = srcFlags
            aura.dstName = dstName
            passed = true
        end
    elseif auratype == "BUFF" then
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

    aura.spellid = spellid
    aura.spellname = spellname
    aura.spellschool = spellschool
    aura.auratype = auratype

    Skada:FixPets(aura)
    log_aurarefresh(Skada.current, aura)
    log_aurarefresh(Skada.total, aura)
end

local function AuraRemoved(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
    local passed = false

    if auratype == "DEBUFF" then
        if Skada:IsPlayer(srcGUID) or Skada:IsPet(srcGUID) then
            aura.playerid = srcGUID
            aura.playername = srcName
            aura.playerflags = srcFlags
            aura.dstName = dstName
            passed = true
        end
    elseif auratype == "BUFF" then
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
local aurasticker
local function auras_tick(set)
    if set then
        for _, player in _ipairs(set.players) do
            if player.auras then
                for _, spell in _pairs(player.auras) do
                    if spell.active == 1 then
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
        if not set or not auratype then
            return
        end

        local settime = Skada:GetSetTime(set)
        local nr, max = 1, 0

        for _, player in _ipairs(set.players) do
            local auracount, aurauptime = countauras(player.auras or {}, auratype)
            if auracount > 0 then
                local maxtime = math_min(settime, Skada:PlayerActiveTime(set, player))
                local uptime = aurauptime / auracount

                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class or "PET"
                d.role = player.role or "DAMAGER"
                d.spec = player.spec or 1

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
local function spellupdatefunc(auratype, win, set, playerid, playername)
    if not set or not auratype then
        return
    end

    local player = Skada:find_player(set, playerid, playername)
    if player and player.auras then
        local maxtime = math_min(Skada:GetSetTime(set), Skada:PlayerActiveTime(set, player))
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
local function aura_tooltip(win, id, label, tooltip, playerid, playername, L)
    local set = win:get_selected_set()
    local player = Skada:find_player(set, playerid, playername)
    if player and player.auras then
        local aura = player.auras[label]
        if aura then
            local settime = Skada:GetSetTime(set)
            local maxtime = math_min(settime, Skada:PlayerActiveTime(set, player))

            tooltip:AddLine(player.name .. ": " .. label)

            -- add spell school if provided
            if aura.school then
                local c = Skada.schoolcolors[aura.school]
                local n = Skada.schoolnames[aura.school]
                if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
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

-- called on SetComplete to remove active auras
local function setcompletefunc(set, auratype)
    if set then
        local settime = Skada:GetSetTime(set)
        for _, player in _ipairs(set.players) do
            if player.auras then
                local maxtime = math_min(Skada:GetSetTime(set), Skada:PlayerActiveTime(set, player))
                for _, spell in _pairs(player.auras) do
                    if spell.auratype == auratype then
                        if spell.active > 0 then
                            spell.active = 0
                        end
                        if spell.uptime > maxtime then
                            spell.uptime = maxtime
                        end
                    end
                end
            end
        end
    end
    if aurasticker then
        aurasticker:Cancel()
        aurasticker = nil
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
        [72968] = true -- Precious's Ribbon
    }

    function spellmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's buffs"], label)
    end

    function spellmod:Update(win, set)
        win.title = _format(L["%s's buffs"], win.playername or UNKNOWN)
        spellupdatefunc("BUFF", win, set, win.playerid, win.playername)
    end

    function mod:Update(win, set)
        win.title = L["Buffs"]
        updatefunc("BUFF", win, set)
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

    function mod:OnEnable()
        spellmod.metadata = {tooltip = buff_tooltip}
        self.metadata = {click1 = spellmod}

        Skada:RegisterForCL(BuffApplied, "SPELL_AURA_APPLIED", {src_is_interesting = true})
        Skada:RegisterForCL(AuraRefresh, "SPELL_AURA_REFRESH", {src_is_interesting = true})
        Skada:RegisterForCL(AuraRefresh, "SPELL_AURA_APPLIED_DOSE", {src_is_interesting = true})
        Skada:RegisterForCL(AuraRemoved, "SPELL_AURA_REMOVED", {src_is_interesting = true})

        Skada:AddMode(self, L["Buffs and Debuffs"])
        Skada.RegisterCallback(self, "ENCOUNTER_START", "CheckBuffs")
    end

    function mod:SetComplete(set)
        setcompletefunc(set, "BUFF")
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
        Skada.UnregisterAllCallbacks(self)
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
                local unit = (n == 0) and "player" or prefix .. _tostring(n)
                if _UnitExists(unit) and not _UnitIsDeadOrGhost(unit) then
                    local dstGUID, dstName = _UnitGUID(unit), _select(1, _UnitName(unit))
                    for i = 1, 32 do
                        local spellname, rank, _, _, _, _, _, unitCaster, _, _, spellid =
                            _UnitAura(unit, i, nil, "BUFF")
                        if spellname and spellid and unitCaster and rank ~= SPELL_PASSIVE and not blacklist[spellid] then
                            AuraApplied(nil, nil, _UnitGUID(unitCaster), _select(1, _UnitName(unitCaster)), nil, dstGUID, dstName, nil, spellid, spellname, nil, "BUFF")
                        end
                    end
                end
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
    local function DebuffApplied(timestamp, eventtype, srcGUID, srcName, _, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
        if srcName == nil and #srcGUID == 0 and dstName and #dstGUID > 0 then
            srcGUID = dstGUID
            srcName = dstName

            if eventtype == "SPELL_AURA_APPLIED" then
                AuraApplied(timestamp, eventtype, srcGUID, srcName, dstFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
            elseif eventtype == "SPELL_AURA_REFRESH" or eventtype == "SPELL_AURA_APPLIED_DOSE" then
                AuraRefresh(timestamp, eventtype, srcGUID, srcName, dstFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool, auratype)
            else
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
        if not player or not player.auras then
            return
        end
        win.title = _format(L["%s's <%s> targets"], player.name, win.spellname or UNKNOWN)

        if player.auras[win.spellname] and player.auras[win.spellname].targets then
            local nr, max = 1, 0
            local total = player.auras[win.spellname].count
            for targetname, count in _pairs(player.auras[win.spellname].targets) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = nr
                d.label = targetname
                d.value = count
                d.valuetext = _format("%u (%02.1f%%)", count, 100 * count / math_max(1, total))

                if count > max then
                    max = count
                end

                nr = nr + 1
            end

            win.metadata.maxvalue = max
        end
    end

    function spellmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's debuffs"], label)
    end

    function spellmod:Update(win, set)
        win.title = _format(L["%s's debuffs"], win.playername or UNKNOWN)
        spellupdatefunc("DEBUFF", win, set, win.playerid, win.playername)
    end

    function mod:Update(win, set)
        win.title = L["Debuffs"]
        updatefunc("DEBUFF", win, set)
    end

    local function debuff_tooltip(win, set, label, tooltip)
        aura_tooltip(win, set, label, tooltip, win.playerid, win.playername, L)
    end

    function mod:OnEnable()
        spellmod.metadata = {tooltip = debuff_tooltip, click1 = targetmod}
        self.metadata = {click1 = spellmod}

        Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_APPLIED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
        Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_REFRESH", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
        Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_APPLIED_DOSE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
        Skada:RegisterForCL(DebuffApplied, "SPELL_AURA_REMOVED", {dst_is_interesting_nopets = true, src_is_not_interesting = true})

        Skada:AddMode(self, L["Buffs and Debuffs"])
        Skada.RegisterCallback(self, "ENCOUNTER_START", "StartTick")
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
        Skada.UnregisterAllCallbacks(self)
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
end)