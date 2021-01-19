local Skada = Skada

--
-- cache frequently used globals
--
local _pairs, _ipairs = pairs, ipairs
local _format, _select, _tostring = string.format, select, tostring
local _GetSpellInfo = GetSpellInfo
local math_min, math_max, math_floor = math.min, math.max, math.floor

--
-- used to reset timers
--
local function setattributes(set)
    if set then
        for i, player in _ipairs(set.players) do
            if player.auras ~= nil then
                for spellid, spell in _pairs(player.auras) do
                    if spell.active > 0 then
                        spell.active = 0
                        spell.started = nil
                    end
                end
            end
        end
    end
end

--
-- once the set is complete, we make sure to stop calculating
--
local function setcomplete(set)
    if set then
        for i, player in _ipairs(set.players) do
            for spellid, spell in _pairs(player.auras) do
                if spell.active > 0 and spell.started then
                    spell.uptime = spell.uptime + math_floor((time() - spell.started) + 0.5)
                    spell.active = 0
                    spell.started = nil
                end
            end
        end
    end
end

--
-- common functions to both modules that handle aura apply/remove log
--
local function log_auraapply(set, aura)
    if not set then
        return
    end

    local player = Skada:get_player(set, aura.playerid, aura.playername, aura.playerflags)
    if not player then
        return
    end

    local now = time()

    if aura.auratype == "BUFF" and not Skada:IsDisabled("Buffs") then
        if not player.auras[aura.spellid] then
            player.auras[aura.spellid] = {
                school = aura.spellschool,
                auratype = aura.auratype,
                active = 1,
                started = now,
                uptime = 0,
                count = 1
            }
        else
            player.auras[aura.spellid].count = player.auras[aura.spellid].count + 1
            player.auras[aura.spellid].active = player.auras[aura.spellid].active + 1
            player.auras[aura.spellid].started = player.auras[aura.spellid].started or now
        end
    elseif aura.auratype == "DEBUFF" and not Skada:IsDisabled("Debuffs") then
        if not player.auras[aura.spellid] then
            player.auras[aura.spellid] = {
                school = aura.spellschool,
                auratype = aura.auratype,
                active = 1,
                started = now,
                uptime = 0,
                count = 1,
                targets = {}
            }
        else
            player.auras[aura.spellid].active = player.auras[aura.spellid].active + 1
            player.auras[aura.spellid].started = player.auras[aura.spellid].started or now
            player.auras[aura.spellid].count = player.auras[aura.spellid].count + 1
        end

        if aura.dstName then
            local targets = player.auras[aura.spellid].targets or {}
            player.auras[aura.spellid].targets = targets

            if not targets[aura.dstName] then
                targets[aura.dstName] = {id = aura.dstGUID, count = 1}
            else
                targets[aura.dstName].count = targets[aura.dstName].count + 1
            end
        end
    end
end

local function log_auraremove(set, aura)
    if set then
        local player = Skada:get_player(set, aura.playerid, aura.playername, aura.playerflags)
        if player and player.auras and aura.spellid and player.auras[aura.spellid] then
            local a = player.auras[aura.spellid]
            if a.active > 0 then
                a.active = a.active - 1

                if a.active == 0 and a.started then
                    a.uptime = a.uptime + math_floor(time() - a.started + 0.5)
                    a.started = nil
                end
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

    aura.dstGUID = dstGUID
    aura.dstName = dstName
    aura.dstFlags = dstFlags

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

    aura.dstGUID = dstGUID
    aura.dstName = dstName
    aura.dstFlags = dstFlags

    aura.spellid = spellid
    aura.spellname = spellname
    aura.spellschool = spellschool
    aura.auratype = auratype

    Skada:FixPets(aura)
    log_auraremove(Skada.current, aura)
    log_auraremove(Skada.total, aura)
end

-- ================================================================== --

--
-- to avoid repeating same functions for both modules, we make
-- make sure to create generic functions that will handle things
--

-- main module update function
local function updatefunc(auratype, win, set)
    local nr, max = 1, 0

    for _, player in _ipairs(set.players) do
        -- we collect number and uptime of auras first
        local auracount, aurauptime = 0, 0

        for spellid, spell in _pairs(player.auras) do
            if spell.auratype == auratype then
                auracount = auracount + 1
                aurauptime = aurauptime + spell.uptime

                -- still active?
                if spell.active > 0 and spell.started then
                    aurauptime = aurauptime + math_floor((time() - spell.started) + 0.5)
                end
            end
        end

        if auracount > 0 then
            local maxtime = Skada:PlayerActiveTime(set, player)
            local uptime = math_min(maxtime, aurauptime / auracount)

            local d = win.dataset[nr] or {}
            win.dataset[nr] = d

            d.id = player.id
            d.label = player.name
            d.class = player.class
            d.role = player.role
            d.spec = player.spec

            d.value = uptime
            d.valuetext = _format("%02.1f%% / %u", 100 * uptime / maxtime, auracount)

            if uptime > max then
                max = uptime
            end

            nr = nr + 1
        end
    end

    win.metadata.maxvalue = max
end

-- spells per player list
local function detailupdatefunc(auratype, win, set, playerid)
    local player = Skada:find_player(set, playerid)
    if player then
        local maxtime = Skada:PlayerActiveTime(set, player)
        if maxtime and maxtime > 0 then
            win.metadata.maxvalue = maxtime
            local nr = 1

            for spellid, spell in _pairs(player.auras) do
                if spell.auratype == auratype then
                    local uptime = math_min(maxtime, spell.uptime)

                    if spell.active > 0 and spell.started then
                        uptime = uptime + math_floor((time() - spell.started) + 0.5)
                    end

                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    local spellname, _, spellicon = _GetSpellInfo(spellid)

                    d.id = spellid
                    d.spellid = spellid
                    d.label = spellname
                    d.icon = spellicon
                    d.spellschool = spell.school

                    d.value = uptime
                    d.valuetext = _format("%02.1f%%", 100 * uptime / maxtime)

                    nr = nr + 1
                end
            end
        end
    end

    -- win.metadata.maxvalue = max
end

-- used to show tooltip
local function aura_tooltip(win, id, label, tooltip, playerid, L)
    local set = win:get_selected_set()
    local player = Skada:find_player(set, playerid)
    if player then
        local aura = player.auras[id]
        if aura then
            local totaltime = Skada:PlayerActiveTime(set, player)

            tooltip:AddLine(player.name .. ": " .. label)

            -- add spell school if provided
            if aura.school then
                local c = Skada.schoolcolors[aura.school]
                local n = Skada.schoolnames[aura.school]
                if c and n then
                    tooltip:AddLine(L[n], c.r, c.g, c.b)
                end
            end

            -- add segment and active times
            tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(totaltime), 1, 1, 1)
            tooltip:AddDoubleLine(L["Uptime"], Skada:FormatTime(aura.uptime), 1, 1, 1)
            tooltip:AddDoubleLine(L["Count"], aura.count, 1, 1, 1)
        end
    end
end

-- ================================================================== --

Skada:AddLoadableModule(
    "Buffs",
    function(Skada, L)
        if Skada:IsDisabled("Buffs") then
            return
        end

        local mod = Skada:NewModule(L["Buffs"])
        local spellmod = mod:NewModule(L["Buff spell list"])

        function spellmod:Enter(win, id, label)
            self.playerid = id
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
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddPlayerAttributes(player)
            if not player.auras then
                player.auras = {}
            end
        end

        function mod:AddSetAttributes(set)
            set.auras = {}
            setattributes(set)
        end

        function mod:SetComplete(set)
            setcomplete(set)
        end
    end
)

-- ================================================================== --

Skada:AddLoadableModule(
    "Debuffs",
    function(Skada, L)
        if Skada:IsDisabled("Debuffs") then
            return
        end

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
            self.spellid = id
            self.title = _format(L["%s's <%s> targets"], spellmod.playername, label)
        end

        function targetmod:Update(win, set)
            local player = Skada:find_player(set, spellmod.playerid)
            local max = 0
            if player and player.auras[self.spellid] then
                local nr = 1

                local total = player.auras[self.spellid].count

                for targetname, target in _pairs(player.auras[self.spellid].targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname

                    d.value = target.count
                    d.valuetext = _format("%u (%02.1f%%)", target.count, 100 * target.count / total)

                    if target.count > max then
                        max = target.count
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

            Skada:RegisterForCL(
                DebuffApplied,
                "SPELL_AURA_APPLIED",
                {dst_is_interesting_nopets = true, src_is_not_interesting = true}
            )
            Skada:RegisterForCL(
                DebuffApplied,
                "SPELL_AURA_REMOVED",
                {dst_is_interesting_nopets = true, src_is_not_interesting = true}
            )

            Skada:AddMode(self, L["Buffs and Debuffs"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddPlayerAttributes(player)
            if not player.auras then
                player.auras = {}
            end
        end

        function mod:AddSetAttributes(set)
            set.auras = {}
            setattributes(set)
        end

        function mod:SetComplete(set)
            setcomplete(set)
        end
    end
)