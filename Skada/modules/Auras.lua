local Skada = Skada
if not Skada then
    return
end

local pairs, ipairs = pairs, ipairs
local format = string.format
local GetSpellInfo = GetSpellInfo
local SecondsToTime = SecondsToTime

local function log_auraapply(set, aura)
    if not set then
        return
    end

    local player = Skada:get_player(set, aura.playerid, aura.playername)
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
            player.auras[aura.spellid].count = player.auras[aura.spellid].count + 1
            player.auras[aura.spellid].active = player.auras[aura.spellid].active + 1
            player.auras[aura.spellid].started = player.auras[aura.spellid].started or now
        end

        if aura.dstName then
	        local targets = player.auras[aura.spellid].targets or {}
	        player.auras[aura.spellid].targets=targets

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
        local player = Skada:get_player(set, aura.playerid, aura.playername)
        if player and player.auras and aura.spellid and player.auras[aura.spellid] then
            local a = player.auras[aura.spellid]
            if a.active > 0 then
                a.active = a.active - 1

                if a.active == 0 and a.started then
                    a.uptime = a.uptime + math.floor(time() - a.started + 0.5)
                    a.started = nil
                end
            end
        end
    end
end

local aura = {}

local function AuraApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    local spellid, spellname, spellschool, auratype = ...

    -- srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName)

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

    -- Skada:FixPets(aura)
    log_auraapply(Skada.current, aura)
    log_auraapply(Skada.total, aura)
end

local function AuraRemoved(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    local spellid, spellname, spellschool, auratype = ...
    -- srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName)

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

    -- Skada:FixPets(aura)
    log_auraremove(Skada.current, aura)
    log_auraremove(Skada.total, aura)
end

local function NullAura(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	if srcGUID ~= dstGUID then
	    if eventtype == "SPELL_AURA_APPLIED" then
	        AuraApplied(timestamp, eventtype, dstGUID, dstName, dstFlags, srcGUID, srcName, srcFlags, ...)
	    else
	        AuraRemoved(timestamp, eventtype, dstGUID, dstName, dstFlags, srcGUID, srcName, srcFlags, ...)
	    end
	end
end

-- account for old total segment
local clear_set_attributes, complete_set
do
    local cleared = false
    local completed = false

    function clear_set_attributes(set)
        if set and not cleared then
            for _, player in ipairs(set.players) do
                if player.auras ~= nil then
                    for _, spell in pairs(player.auras) do
                        if spell.active > 0 then
                            spell.active = 0
                            spell.started = 0
                        end
                    end
                end
            end

            cleared = true
        end
    end

    function complete_set(set)
        if not completed then
            for _, player in ipairs(set.players) do
                for spellid, spell in pairs(player.auras) do
                    if spell.active > 0 and spell.started then
                        spell.uptime = spell.uptime + math.floor((time() - spell.started) + 0.5)
                        spell.active = 0
                        spell.started = nil
                    end
                end
            end
            completed = true
        end
    end
end

local function playermod_update(auratype, win, set, playerid, mod)
    local nr = 1
    local max = 0
    local player = Skada:find_player(set, playerid)

    if player then
        local maxtime = Skada:PlayerActiveTime(set, player)

        if maxtime and maxtime > 0 then
            win.metadata.maxvalue = maxtime
            for spellid, spell in pairs(player.auras) do
                if spell.auratype == auratype then
                    local uptime = math.min(maxtime, spell.uptime)

                    -- Account for active auras
                    if spell.active > 0 and spell.started then
                        uptime = uptime + math.floor((time() - spell.started) + 0.5)
                    end

                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    local spellname, _, spellicon = GetSpellInfo(spellid)

                    d.id = spellid
                    d.spellid = spellid
                    d.label = spellname
                    d.icon = spellicon
                    d.spellschool = spell.school

                    d.value = uptime

                    if mod then
                        d.valuetext =
                            Skada:FormatValueText(
                            uptime .. "s",
                            mod.metadata.columns.Total,
                            format("%02.1f%%", 100 * uptime / maxtime),
                            mod.metadata.columns.Percent
                        )
                    else
                        d.valuetext = format("%02.1f%%", 100 * uptime / maxtime)
                    end

                    nr = nr + 1
                end
            end
        end
    end
end

local function mod_update(auratype, win, set, mod)
    local nr = 1
    local max = 0

    for i, player in ipairs(set.players) do
        -- Find number of debuffs.
        local auracount = 0
        local aurauptime = 0
        for spellname, spell in pairs(player.auras) do
            if spell.auratype == auratype then
                auracount = auracount + 1
                aurauptime = aurauptime + spell.uptime

                -- Account for active auras
                if spell.active > 0 and spell.started then
                    aurauptime = aurauptime + math.floor((time() - spell.started) + 0.5)
                end
            end
        end

        if auracount > 0 then
            -- Calculate player max possible uptime.
            local maxtime = Skada:PlayerActiveTime(set, player)

            -- Now divide by the number of spells to get the average uptime.
            local uptime = math.min(maxtime, aurauptime / auracount)

            local d = win.dataset[nr] or {}
            win.dataset[nr] = d

            d.id = player.id
            d.label = player.name
            d.class = player.class
            d.role = player.role
            d.spec = player.spec

            d.value = uptime
            d.valuetext = format("%02.1f%% / %u", uptime / maxtime * 100, auracount)

            if uptime > max then
                max = uptime
            end

            nr = nr + 1
        end
    end

    win.metadata.maxvalue = max
end

local function spell_tooltip(win, id, label, tooltip, playerid, L)
    local set = win:get_selected_set()
    local player = Skada:find_player(set, playerid)
    if player then
        local aura = player.auras[id]
        if aura then
            local totaltime = Skada:PlayerActiveTime(set, player)

            tooltip:AddLine(player.name .. ": " .. label)
            if aura.school then
                local c = Skada.schoolcolors[aura.school]
                local n = Skada.schoolnames[aura.school]
                if c and n then
                    tooltip:AddLine(L[n], c.r, c.g, c.b)
                end
            end

            tooltip:AddDoubleLine(L["Segment Time"], SecondsToTime(totaltime) .. "s", 255, 255, 255, 255, 255, 255)
            tooltip:AddDoubleLine(L["Active Time"], SecondsToTime(aura.uptime) .. "s", 255, 255, 255, 255, 255, 255)
            tooltip:AddDoubleLine((L["Total"]), aura.count, 255, 255, 255, 255, 255, 255)
            tooltip:AddDoubleLine(
                ("%d/%d"):format(aura.uptime, totaltime),
                ("%02.1f%%)"):format(aura.uptime / totaltime * 100),
                255,
                255,
                255,
                255,
                255,
                255
            )
        end
    end
end

Skada:AddLoadableModule(
    "Buffs",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Buffs") then
            return
        end

        local mod = Skada:NewModule(L["Buffs"])
        local playermod = mod:NewModule(L["Buff spell list"])

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's buff uptime"], label)
        end

        function playermod:Update(win, set)
            playermod_update("BUFF", win, set, self.playerid, mod)
        end

        function mod:Update(win, set)
            mod_update("BUFF", win, set, self)
        end

        local function aura_tooltip(win, id, label, tooltip)
            spell_tooltip(win, id, label, tooltip, playermod.playerid, L)
        end

        function mod:OnEnable()
            playermod.metadata = {tooltip = aura_tooltip}
            mod.metadata = {click1 = playermod, columns = {Total = true, Percent = true}}

            Skada:RegisterForCL(AuraApplied, "SPELL_AURA_APPLIED", {src_is_interesting = true})
            Skada:RegisterForCL(AuraRemoved, "SPELL_AURA_REMOVED", {src_is_interesting = true})

            Skada:AddMode(self, L["Buffs and Debuffs"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddPlayerAttributes(player)
            player.auras = player.auras or {}
        end

        function mod:AddSetAttributes(set)
            set.auras = set.auras or {}
            clear_set_attributes(set)
        end

        function mod:SetComplete(set)
            complete_set(set)
        end
    end
)

Skada:AddLoadableModule(
    "Debuffs",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Debuffs") then
            return
        end

        local mod = Skada:NewModule(L["Debuffs"])
        local playermod = mod:NewModule(L["Debuff spell list"])
        local targetmod = mod:NewModule(L["Debuff target list"])

        function targetmod:Enter(win, id, label)
            self.spellid = id
            local player = Skada:find_player(win:get_selected_set(), playermod.playerid)
            if player then
                self.title = format(L["%s's <%s> targets"], player.name, label)
            else
                self.title = format(L["%s's targets"], label)
            end
        end

        function targetmod:Update(win, set)
            local player = Skada:find_player(set, playermod.playerid)
            local max = 0

            if player and self.spellid and player.auras[self.spellid] then
                local auracount = player.auras[self.spellid].count
                local nr = 1

                for targetname, target in pairs(player.auras[self.spellid].targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname

                    d.value = target.count
                    d.valuetext =
                        Skada:FormatValueText(
                        target.count,
                        mod.metadata.columns.Total,
                        format("%02.1f%%", 100 * target.count / auracount),
                        mod.metadata.columns.Percent
                    )

                    if target.count > max then
                        max = target.count
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's debuff uptime"], label)
        end

        function playermod:Update(win, set)
            playermod_update("DEBUFF", win, set, self.playerid, mod)
        end

        function mod:Update(win, set)
            mod_update("DEBUFF", win, set, self)
        end

        local function aura_tooltip(win, id, label, tooltip)
            spell_tooltip(win, id, label, tooltip, playermod.playerid, L)
        end

        function mod:OnEnable()
            playermod.metadata = {tooltip = aura_tooltip, click1 = targetmod}
            mod.metadata = {click1 = playermod, columns = {Total = true, Percent = true}}

            Skada:RegisterForCL(
                NullAura,
                "SPELL_AURA_APPLIED",
                {dst_is_interesting_nopets = true, src_is_not_interesting = true}
            )
            Skada:RegisterForCL(
                NullAura,
                "SPELL_AURA_REMOVED",
                {dst_is_interesting_nopets = true, src_is_not_interesting = true}
            )

            Skada:AddMode(self, L["Buffs and Debuffs"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddPlayerAttributes(player)
            player.auras = player.auras or {}
        end

        function mod:AddSetAttributes(set)
            set.auras = set.auras or {}
            clear_set_attributes(set)
        end

        function mod:SetComplete(set)
            complete_set(set)
        end
    end
)

Skada:AddLoadableModule(
    "Sunders Counter",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Debuffs", "Sunders Counter") then
            return
        end

        local mod = Skada:NewModule(L["Sunders Counter"])
        local sunder

        local function total_sunders(set)
            sunder = sunder or select(1, GetSpellInfo(47467))

            local total = 0

            if set then
                for _, player in ipairs(set.players) do
                    if player.class == "WARRIOR" and player.auras then
                        for spellid, spell in pairs(player.auras) do
                            local spellname = select(1, GetSpellInfo(spellid))
                            if spellname == sunder then
                                total = total + spell.count
                            end
                        end
                    end
                end
            end

            return total
        end

        function mod:Update(win, set)
            sunder = sunder or select(1, GetSpellInfo(47467))

            local nr, max = 1, 0
            local total = total_sunders(set)

            for _, player in ipairs(set.players) do
                if player.class == "WARRIOR" and player.auras then
                    for spellid, spell in pairs(player.auras) do
                        local spellname, _, spellicon = GetSpellInfo(spellid)
                        if spellname == sunder then
                            local d = win.dataset[nr] or {}
                            win.dataset[nr] = d

                            d.id = player.id
                            d.label = player.name
                            d.class = player.class
                            d.role = player.role
                            d.spec = player.spec

                            d.value = spell.count
                            d.valuetext =
                                Skada:FormatValueText(
                                spell.count,
                                self.metadata.columns.Total,
                                format("%02.1f%%", 100 * spell.count / math.max(1, total)),
                                self.metadata.columns.Percent
                            )

                            if spell.count > max then
                                max = spell.count
                            end

                            nr = nr + 1
                        end
                    end
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnInitialize()
            sunder = sunder or select(1, GetSpellInfo(47467))
        end

        function mod:OnEnable()
            sunder = sunder or select(1, GetSpellInfo(47467))
            mod.metadata = {showspots = true, columns = {Total = true, Percent = true}}
            Skada:AddMode(self, L["Buffs and Debuffs"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:GetSetSummary(set)
            return total_sunders(set)
        end
    end
)