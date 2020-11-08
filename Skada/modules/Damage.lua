local Skada = Skada
if not Skada then
    return
end

local UnitGUID, UnitClass = UnitGUID, UnitClass
local GetSpellInfo = GetSpellInfo
local format, math_max = string.format, math.max
local pairs, ipairs, select = pairs, ipairs, select

-- list of miss types
local misstypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}

-- generic spell damage
local function _SpellDamage(cond, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if cond == true then
        local spellid,
            spellname,
            spellschool,
            amount,
            overkill,
            school,
            resisted,
            blocked,
            absorbed,
            critical,
            glancing,
            crushing = ...

        local dmg = {}

        dmg.srcGUID = srcGUID
        dmg.srcName = srcName
        dmg.srcFlags = srcFlags

        dmg.dstGUID = dstGUID
        dmg.dstName = dstName
        dmg.dstFlags = dstFlags

        dmg.spellid = spellid
        dmg.spellname = spellname
        dmg.spellschool = spellschool

        dmg.amount = amount
        dmg.overkill = overkill
        dmg.resisted = resisted
        dmg.blocked = blocked
        dmg.absorbed = absorbed
        dmg.critical = critical
        dmg.glancing = glancing
        dmg.crushing = crushing
        dmg.missed = nil

        return dmg
    end

    return nil
end

local function _SpellMissed(cond, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if cond == true then
        local spellid, spellname, spellschool, misstype, amount = ...

        local dmg = {}

        dmg.srcGUID = srcGUID
        dmg.srcName = srcName
        dmg.srcFlags = srcFlags

        dmg.dstGUID = dstGUID
        dmg.dstName = dstName
        dmg.dstFlags = dstFlags

        dmg.spellid = spellid
        dmg.spellname = spellname
        dmg.spellschool = spellschool

        dmg.amount = 0
        dmg.overkill = 0
        dmg.missed = misstype

        return dmg
    end
end

-- generic swing (melee) damage
local function _SwingDamage(cond, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if cond == true then
        local amount, overkill, spellschool, resisted, blocked, absorbed, critical, glancing, crushing = ...

        local dmg = {}

        dmg.srcGUID = srcGUID
        dmg.srcName = srcName
        dmg.srcFlags = srcFlags

        dmg.dstGUID = dstGUID
        dmg.dstName = dstName
        dmg.dstFlags = dstFlags

        dmg.spellid = 6603
        dmg.spellname = MELEE
        dmg.spellschool = 1

        dmg.amount = amount
        dmg.overkill = overkill
        dmg.resisted = resisted
        dmg.blocked = blocked
        dmg.absorbed = absorbed
        dmg.critical = critical
        dmg.glancing = glancing
        dmg.crushing = crushing
        dmg.missed = nil

        return dmg
    end
end

-- generic swing missed
local function _SwingMissed(cond, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if cond == true then
        local dmg = {}

        dmg.srcGUID = srcGUID
        dmg.srcName = srcName
        dmg.srcFlags = srcFlags

        dmg.dstGUID = dstGUID
        dmg.dstName = dstName
        dmg.dstFlags = dstFlags

        dmg.spellid = 6603
        dmg.spellname = MELEE
        dmg.spellschool = 1

        dmg.amount = 0
        dmg.overkill = 0
        dmg.missed = select(1, ...)

        return dmg
    end
end

-- ================== --
-- Damage Done Module --
-- ================== --
local damagedone = "Damage"
Skada:AddLoadableModule(
    damagedone,
    nil,
    function(Skada, L)
        if Skada:IsDisabled(damagedone) then
            return
        end

        local mod = Skada:NewModule(L[damagedone])
        local playermod = mod:NewModule(L["Damage spell list"])
        local spellmod = mod:NewModule(L["Damage spell details"])
        local targetmod = mod:NewModule(L["Damage spell targets"])

        local dpsmod = Skada:NewModule(L["DPS"])

        local spellsmod = Skada:NewModule(L["Damage done by spell"])
        local spellsourcesmod = spellsmod:NewModule(L["Damage spell sources"])

        local function log_damage(set, dmg)
            local player = Skada:get_player(set, dmg.playerid, dmg.playername)
            if not player then
                return
            end

            set.damagedone = set.damagedone + dmg.amount
            player.damagedone.amount = player.damagedone.amount + dmg.amount

            if not player.damagedone.spells[dmg.spellid] then
                player.damagedone.spells[dmg.spellid] = {amount = 0, school = dmg.spellschool}
            end

            local spell = player.damagedone.spells[dmg.spellid]
            spell.totalhits = (spell.totalhits or 0) + 1
            spell.amount = spell.amount + dmg.amount

            if spell.max == nil or dmg.amount > spell.max then
                spell.max = dmg.amount
            end

            if (spell.min == nil or dmg.amount < spell.min) and not dmg.missed then
                spell.min = dmg.amount
            end

            if dmg.critical then
                spell.critical = (spell.critical or 0) + 1
                spell.criticalamount = (spell.criticalamount or 0) + dmg.amount

                if not spell.criticalmax or dmg.amount > spell.criticalmax then
                    spell.criticalmax = dmg.amount
                end

                if not spell.criticalmin or dmg.amount < spell.criticalmin then
                    spell.criticalmin = dmg.amount
                end
            elseif dmg.missed ~= nil then
                spell[dmg.missed] = (spell[dmg.missed] or 0) + 1
            elseif dmg.glancing then
                spell.glancing = (spell.glancing or 0) + 1
            elseif dmg.crushing then
                spell.crushing = (spell.crushing or 0) + 1
            else
                spell.hit = (spell.hit or 0) + 1
                spell.hitamount = (spell.hitamount or 0) + dmg.amount
                if not spell.hitmax or dmg.amount > spell.hitmax then
                    spell.hitmax = dmg.amount
                end
                if not spell.hitmin or dmg.amount < spell.hitmin then
                    spell.hitmin = dmg.amount
                end
            end

            if set == Skada.current and dmg.dstName and dmg.amount > 0 then
                if not player.damagedone.targets[dmg.dstName] then
                    player.damagedone.targets[dmg.dstName] = 0
                end
                player.damagedone.targets[dmg.dstName] = player.damagedone.targets[dmg.dstName] + dmg.amount
            end
        end

        local function SpellDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            dmg = _SpellDamage((srcGUID ~= dstGUID), srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if dmg then
                dmg.playerid = dmg.srcGUID
                dmg.playername = dmg.srcName
                dmg.playerflags = dmg.srcFlags
                dmg.srcGUID, dmg.srcName, dmg.srcFlags = nil, nil, nil

                Skada:FixPets(dmg)
                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        local function SpellMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            dmg = _SpellMissed((srcGUID ~= dstGUID), srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if dmg then
                dmg.playerid = dmg.srcGUID
                dmg.playername = dmg.srcName
                dmg.playerflags = dmg.srcFlags
                dmg.srcGUID, dmg.srcName, dmg.srcFlags = nil, nil, nil

                Skada:FixPets(dmg)
                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        local function SwingDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            dmg = _SwingDamage((srcGUID ~= dstGUID), srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if dmg then
                dmg.playerid = dmg.srcGUID
                dmg.playername = dmg.srcName
                dmg.playerflags = dmg.srcFlags
                dmg.srcGUID, dmg.srcName, dmg.srcFlags = nil, nil, nil

                Skada:FixPets(dmg)
                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        local function SwingMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            dmg = _SwingMissed((srcGUID ~= dstGUID), srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if dmg then
                dmg.playerid = dmg.srcGUID
                dmg.playername = dmg.srcName
                dmg.playerflags = dmg.srcFlags
                dmg.srcGUID, dmg.srcName, dmg.srcFlags = nil, nil, nil

                Skada:FixPets(dmg)
                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        local function getDPS(set, player)
            local uptime = Skada:PlayerActiveTime(set, player)
            return player.damagedone.amount / math_max(1, uptime)
        end

        local function getRaidDPS(set)
            if set.time > 0 then
                return set.damagedone / math_max(1, set.time)
            else
                local endtime = set.endtime
                if not endtime then
                    endtime = time()
                end
                return set.damagedone / math_max(1, endtime - set.starttime)
            end
        end

        local function damage_tooltip(win, id, label, tooltip)
            local set = win:get_selected_set()
            local player = Skada:find_player(set, id)
            if player then
                local activetime = Skada:PlayerActiveTime(set, player)
                local totaltime = Skada:GetSetTime(set)
                tooltip:AddDoubleLine(
                    L["Activity"],
                    ("%02.1f%%"):format(activetime / math.max(1, totaltime) * 100),
                    255,
                    255,
                    255,
                    255,
                    255,
                    255
                )
            end
        end

        local function dps_tooltip(win, id, label, tooltip)
            local set = win:get_selected_set()
            local player = Skada:find_player(set, id)
            if player then
                local activetime = Skada:PlayerActiveTime(set, player)
                local totaltime = Skada:GetSetTime(set)
                tooltip:AddLine(player.name .. " - " .. L["DPS"])
                tooltip:AddDoubleLine(L["Segment Time"], SecondsToTime(totaltime), 255, 255, 255, 255, 255, 255)
                tooltip:AddDoubleLine(L["Active Time"], SecondsToTime(activetime), 255, 255, 255, 255, 255, 255)
                tooltip:AddDoubleLine(
                    L["Damage done"],
                    Skada:FormatNumber(player.damagedone.amount),
                    255,
                    255,
                    255,
                    255,
                    255,
                    255
                )
                tooltip:AddDoubleLine(
                    Skada:FormatNumber(player.damagedone.amount) .. "/" .. activetime .. ":",
                    format("%02.1f", player.damagedone.amount / math_max(1, activetime)),
                    255,
                    255,
                    255,
                    255,
                    255,
                    255
                )
            end
        end

        local function player_tooltip(win, id, label, tooltip)
            local player = Skada:find_player(win:get_selected_set(), playermod.playerid)
            if not player then
                return
            end

            local spell = player.damagedone.spells[id]
            if spell then
                tooltip:AddLine(player.name .. " - " .. label)

                if spell.school then
                    local c = Skada.schoolcolors[spell.school]
                    local n = Skada.schoolnames[spell.school]
                    if c and n then
                        tooltip:AddLine(L[n], c.r, c.g, c.b)
                    end
                end

                if spell.max and spell.min then
                    tooltip:AddDoubleLine(
                        L["Minimum hit:"],
                        Skada:FormatNumber(spell.min),
                        255,
                        255,
                        255,
                        255,
                        255,
                        255
                    )
                    tooltip:AddDoubleLine(
                        L["Maximum hit:"],
                        Skada:FormatNumber(spell.max),
                        255,
                        255,
                        255,
                        255,
                        255,
                        255
                    )
                end
                tooltip:AddDoubleLine(
                    L["Average hit:"],
                    Skada:FormatNumber(spell.amount / spell.totalhits),
                    255,
                    255,
                    255,
                    255,
                    255,
                    255
                )
                tooltip:AddDoubleLine(L["Total hits:"], tostring(spell.totalhits), 255, 255, 255, 255, 255, 255)
            end
        end

        local function spellmod_tooltip(win, id, label, tooltip)
            local player = Skada:find_player(win:get_selected_set(), playermod.playerid)
            if not player then
                return
            end

            local spell = player.damagedone.spells[spellmod.spellid]
            if spell and label then
                tooltip:AddLine(player.name .. " - " .. select(1, GetSpellInfo(spellmod.spellid)))

                if spell.school then
                    local c = Skada.schoolcolors[spell.school]
                    local n = Skada.schoolnames[spell.school]
                    if c and n then
                        tooltip:AddLine(L[n], c.r, c.g, c.b)
                    end
                end

                if label == CRIT_ABBR and spell.criticalamount then
                    tooltip:AddDoubleLine(
                        L["Minimum"],
                        Skada:FormatNumber(spell.criticalmin),
                        255,
                        255,
                        255,
                        255,
                        255,
                        255
                    )
                    tooltip:AddDoubleLine(
                        L["Maximum"],
                        Skada:FormatNumber(spell.criticalmax),
                        255,
                        255,
                        255,
                        255,
                        255,
                        255
                    )
                    tooltip:AddDoubleLine(
                        L["Average"],
                        Skada:FormatNumber(spell.criticalamount / spell.critical),
                        255,
                        255,
                        255,
                        255,
                        255,
                        255
                    )
                end

                if label == HIT and spell.hitamount then
                    tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.hitmin), 255, 255, 255, 255, 255, 255)
                    tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.hitmax), 255, 255, 255, 255, 255, 255)
                    tooltip:AddDoubleLine(
                        L["Average"],
                        Skada:FormatNumber(spell.hitamount / spell.hit),
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

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = format(L["%s's damage"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for spellid, spell in pairs(player.damagedone.spells) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    local spellname, _, spellicon = GetSpellInfo(spellid)

                    d.id = spellid
                    d.spellid = spellid
                    d.spellschool = spell.school
                    d.label = spellname
                    d.icon = spellicon

                    d.value = spell.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        mod.metadata.columns.Damage,
                        format("%02.1f%%", spell.amount / player.damagedone.amount * 100),
                        mod.metadata.columns.Percent
                    )

                    if spell.amount > max then
                        max = spell.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function targetmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's targets"], label)
        end

        function targetmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for mobname, amount in pairs(player.damagedone.targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = mobname
                    d.label = mobname

                    d.value = amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(amount),
                        mod.metadata.columns.Damage,
                        format("%02.1f%%", amount / player.damagedone.amount * 100),
                        mod.metadata.columns.Percent
                    )

                    if amount > max then
                        max = amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        local function add_detail_bar(win, nr, title, value)
            local d = win.dataset[nr] or {}
            win.dataset[nr] = d

            d.id = title
            d.label = title
            d.value = value
            d.valuetext =
                Skada:FormatValueText(
                value,
                mod.metadata.columns.Damage,
                format("%02.1f%%", value / win.metadata.maxvalue * 100),
                mod.metadata.columns.Percent
            )
        end

        function spellmod:Enter(win, id, label)
            self.spellid = id
            self.title = playermod.playername .. ": " .. label
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, playermod.playerid)

            if player and player.damagedone.spells then
                local spell = player.damagedone.spells[self.spellid]

                if spell then
                    win.metadata.maxvalue = spell.totalhits
                    local nr = 1

                    if spell.hit and spell.hit > 0 then
                        add_detail_bar(win, nr, HIT, spell.hit)
                        nr = nr + 1
                    end
                    if spell.critical and spell.critical > 0 then
                        add_detail_bar(win, nr, CRIT_ABBR, spell.critical)
                        nr = nr + 1
                    end
                    if spell.glancing and spell.glancing > 0 then
                        add_detail_bar(win, nr, L["Glancing"], spell.glancing)
                        nr = nr + 1
                    end
                    if spell.crushing and spell.crushing > 0 then
                        add_detail_bar(win, nr, L["Crushing"], spell.crushing)
                        nr = nr + 1
                    end
                    for i, misstype in ipairs(misstypes) do
                        if spell[misstype] and spell[misstype] > 0 then
                            local title = _G[misstype] or _G["ACTION_SPELL_MISSED" .. misstype] or misstype
                            add_detail_bar(win, nr, title, spell[misstype])
                            nr = nr + 1
                        end
                    end
                end
            end
        end

        function spellsourcesmod:Enter(win, id, label)
            self.spellid = id
            self.title = format(L["%s's sources"], label)
        end

        function spellsourcesmod:Update(win, set)
            local nr, max = 1, 0

            for i, player in ipairs(set.players) do
                if player.damagedone.amount > 0 and player.damagedone.spells[self.spellid] then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role

                    local amount = player.damagedone.spells[self.spellid].amount

                    d.value = amount
                    d.valuetext = Skada:FormatNumber(amount)

                    if amount > max then
                        max = amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function spellsmod:Update(win, set)
            local spells, _ = {}

            for i, player in ipairs(set.players) do
                if player.damagedone.amount > 0 then
                    for spellid, spell in pairs(player.damagedone.spells) do
                        spells[spellid] = spells[spellid] or spell
                        spells[spellid].spellname, _, spells[spellid].spellicon = GetSpellInfo(spellid)
                    end
                end
            end

            local nr, max = 1, 0

            for spellid, spell in pairs(spells) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = spellid
                d.spellid = spellid
                d.spellschool = spell.school
                d.label = spell.spellname
                d.icon = spell.spellicon

                d.value = spell.amount
                d.valuetext =
                    format("%s (%02.1f%%)", Skada:FormatNumber(spell.amount), spell.amount / set.damagedone * 100)

                if spell.amount > max then
                    max = spell.amount
                end

                nr = nr + 1
            end

            win.metadata.maxvalue = max
        end

        function mod:Update(win, set)
            local nr, max = 1, 0

            for i, player in ipairs(set.players) do
                if player.damagedone.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role

                    local dps = getDPS(set, player)

                    d.value = player.damagedone.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.damagedone.amount),
                        self.metadata.columns.Damage,
                        format("%02.1f", dps),
                        self.metadata.columns.DPS,
                        format("%02.1f%%", player.damagedone.amount / set.damagedone * 100),
                        self.metadata.columns.Percent
                    )

                    if player.damagedone.amount > max then
                        max = player.damagedone.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        local function feed_personal_dps()
            if Skada.current then
                local player = Skada:find_player(Skada.current, UnitGUID("player"))
                if player then
                    return format("%02.1f", getDPS(Skada.current, player)) .. " " .. L["DPS"]
                end
            end
        end

        local function feed_raid_dps()
            if Skada.current then
                return format("%02.1f", getRaidDPS(Skada.current)) .. " " .. L["RDPS"]
            end
        end

        function dpsmod:GetSetSummary(set)
            return Skada:FormatNumber(getRaidDPS(set))
        end

        function dpsmod:Update(win, set)
            local nr, max = 1, 0
            local raiddps = getRaidDPS(set)

            for i, player in ipairs(set.players) do
                local dps = getDPS(set, player)

                if dps > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role

                    d.value = dps
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(dps),
                        self.metadata.columns.DPS,
                        format("%02.1f%%", dps / raiddps * 100),
                        self.metadata.columns.Percent
                    )

                    if dps > max then
                        max = dps
                    end
                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            spellmod.metadata = {tooltip = spellmod_tooltip}
            playermod.metadata = {tooltip = player_tooltip, click1 = spellmod}
            targetmod.metadata = {}
            mod.metadata = {
                showspots = true,
                post_tooltip = damage_tooltip,
                click1 = playermod,
                click2 = targetmod,
                columns = {Damage = true, DPS = true, Percent = true}
            }

            dpsmod.metadata = {
                showspots = true,
                tooltip = dps_tooltip,
                click1 = playermod,
                click2 = targetmod,
                columns = {DPS = true, Percent = true}
            }
            spellsmod.metadata = {showspots = true, ordersort = true, click1 = spellsourcesmod}

            Skada:RegisterForCL(
                SpellDamage,
                "DAMAGE_SHIELD",
                {src_is_interesting = true, dst_is_not_interesting = true}
            )
            Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
            Skada:RegisterForCL(
                SpellDamage,
                "SPELL_PERIODIC_DAMAGE",
                {src_is_interesting = true, dst_is_not_interesting = true}
            )
            Skada:RegisterForCL(
                SpellDamage,
                "SPELL_BUILDING_DAMAGE",
                {src_is_interesting = true, dst_is_not_interesting = true}
            )
            Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})

            Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
            Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})

            Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
            Skada:RegisterForCL(
                SpellMissed,
                "SPELL_PERIODIC_MISSED",
                {src_is_interesting = true, dst_is_not_interesting = true}
            )
            Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
            Skada:RegisterForCL(
                SpellMissed,
                "SPELL_BUILDING_MISSED",
                {src_is_interesting = true, dst_is_not_interesting = true}
            )

            Skada:AddFeed(L["Damage: Personal DPS"], feed_personal_dps)
            Skada:AddFeed(L["Damage: Raid DPS"], feed_raid_dps)

            Skada:AddMode(self, L["Damage"])
            Skada:AddMode(spellsmod, L["Damage"])
            Skada:AddMode(dpsmod, L["Damage"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
            Skada:RemoveMode(spellsmod)
            Skada:RemoveMode(dpsmod)
            Skada:RemoveFeed(L["Damage: Personal DPS"])
            Skada:RemoveFeed(L["Damage: Raid DPS"])
        end

        function mod:AddToTooltip(set, tooltip)
            GameTooltip:AddDoubleLine(L["DPS"], format("%02.1f", getRaidDPS(set)), 1, 1, 1)
        end

        function mod:GetSetSummary(set)
            return Skada:FormatValueText(
                Skada:FormatNumber(set.damagedone),
                self.metadata.columns.Damage,
                Skada:FormatNumber(getRaidDPS(set)),
                self.metadata.columns.DPS
            )
        end

        function mod:AddPlayerAttributes(player)
            if not player.damagedone then
                player.damagedone = {amount = 0, spells = {}, targets = {}}
            end
        end

        function mod:AddSetAttributes(set)
            set.damagedone = set.damagedone or 0
        end

        function mod:SetComplete(set)
            for i, player in ipairs(set.players) do
                if player.damagedone.amount == 0 then
                    player.damagedone.spells = nil
                    player.damagedone.targets = nil
                end
            end
        end
    end
)

-- ================== --
-- Damage Taken Module --
-- ================== --
local damagetaken = "Damage taken"
Skada:AddLoadableModule(
    damagetaken,
    nil,
    function(Skada, L)
        if Skada:IsDisabled(damagetaken) then
            return
        end

        local mod = Skada:NewModule(L[damagetaken])
        local playermod = mod:NewModule(L["Damage spell list"])
        local spellmod = mod:NewModule(L["Damage spell details"])
        local sourcemod = mod:NewModule(L["Damage spell sources"])

        local spellsmod = Skada:NewModule(L["Damage taken by spell"])
        local spelltargetsmod = spellsmod:NewModule(L["Damage spell targets"])

        local function log_damage(set, dmg)
            local player = Skada:find_player(set, dmg.playerid, dmg.playername)
            if not player then
                return
            end

            set.damagetaken = set.damagetaken + dmg.amount
            player.damagetaken.amount = player.damagetaken.amount + dmg.amount

            if not player.damagetaken.spells[dmg.spellid] then
                player.damagetaken.spells[dmg.spellid] = {amount = 0, school = dmg.spellschool}
            end

            local spell = player.damagetaken.spells[dmg.spellid]
            spell.totalhits = (spell.totalhits or 0) + 1
            spell.amount = spell.amount + dmg.amount

            if spell.max == nil or dmg.amount > spell.max then
                spell.max = dmg.amount
            end

            if (spell.min == nil or dmg.amount < spell.min) and not dmg.missed then
                spell.min = dmg.amount
            end

            if dmg.critical then
                spell.critical = (spell.critical or 0) + 1
            elseif dmg.glancing then
                spell.glancing = (spell.glancing or 0) + 1
            elseif dmg.crushing then
                spell.crushing = (spell.crushing or 0) + 1
            elseif dmg.missed ~= nil then
                spell[dmg.missed] = (spell[dmg.missed] or 0) + 1
            else
                spell.hit = (spell.hit or 0) + 1
                spell.hitamount = (spell.hitamount or 0) + dmg.amount
                if not spell.hitmax or dmg.amount > spell.hitmax then
                    spell.hitmax = dmg.amount
                end
                if not spell.hitmin or dmg.amount < spell.hitmin then
                    spell.hitmin = dmg.amount
                end
            end

            if dmg.absorbed then
                spell.absorbed = (spell.absorbed or 0) + dmg.absorbed
            end

            if dmg.blocked then
                spell.blocked = (spell.blocked or 0) + dmg.blocked
            end

            if dmg.resisted then
                spell.resisted = (spell.resisted or 0) + dmg.resisted
            end

            if set == Skada.current and dmg.dstName and dmg.amount > 0 then
                if not player.damagetaken.sources[dmg.dstName] then
                    player.damagetaken.sources[dmg.dstName] = 0
                end
                player.damagetaken.sources[dmg.dstName] = player.damagetaken.sources[dmg.dstName] + dmg.amount
            end
        end

        local dmg = {}

        local function SpellDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            dmg = _SpellDamage((srcGUID ~= dstGUID), dstGUID, dstName, dstFlags, srcGUID, srcName, srcFlags, ...)
            if dmg then
                dmg.playerid = dmg.srcGUID
                dmg.playername = dmg.srcName
                dmg.playerflags = dmg.srcFlags
                dmg.srcGUID, dmg.srcName, dmg.srcFlags = nil, nil, nil

                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        local function SpellMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            dmg = _SpellMissed((srcGUID ~= dstGUID), dstGUID, dstName, dstFlags, srcGUID, srcName, srcFlags, ...)
            if dmg then
                dmg.playerid = dmg.srcGUID
                dmg.playername = dmg.srcName
                dmg.playerflags = dmg.srcFlags
                dmg.srcGUID, dmg.srcName, dmg.srcFlags = nil, nil, nil

                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        local function SwingDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            dmg = _SwingDamage((srcGUID ~= dstGUID), dstGUID, dstName, dstFlags, srcGUID, srcName, srcFlags, ...)
            if dmg then
                dmg.playerid = dmg.srcGUID
                dmg.playername = dmg.srcName
                dmg.playerflags = dmg.srcFlags
                dmg.srcGUID, dmg.srcName, dmg.srcFlags = nil, nil, nil

                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        local function SwingMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            dmg = _SwingMissed((srcGUID ~= dstGUID), dstGUID, dstName, dstFlags, srcGUID, srcName, srcFlags, ...)
            if dmg then
                dmg.playerid = dmg.srcGUID
                dmg.playername = dmg.srcName
                dmg.playerflags = dmg.srcFlags
                dmg.srcGUID, dmg.srcName, dmg.srcFlags = nil, nil, nil

                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        local function getDTPS(set, player)
            local uptime = Skada:PlayerActiveTime(set, player)
            return player.damagetaken.amount / math_max(1, uptime)
        end

        local function getRaidDTPS(set)
            if set.time > 0 then
                return set.damagetaken / math_max(1, set.time)
            else
                local endtime = set.endtime
                if not endtime then
                    endtime = time()
                end
                return set.damagetaken / math_max(1, endtime - set.starttime)
            end
        end

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = format(L["%s's damage taken"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player and player.damagetaken.amount > 0 then
                local nr = 1

                for spellid, spell in pairs(player.damagetaken.spells) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    local spellname, _, spellicon = GetSpellInfo(spellid)

                    d.id = spellid
                    d.spellid = spellid
                    d.spellschool = spell.school
                    d.label = spellname
                    d.icon = spellicon

                    d.value = spell.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        mod.metadata.columns.Damage,
                        format("%02.1f%%", spell.amount / player.damagetaken.amount * 100),
                        mod.metadata.columns.Percent
                    )

                    if spell.amount > max then
                        max = spell.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function sourcemod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's damage sources"], label)
        end

        function sourcemod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for mobname, amount in pairs(player.damagetaken.sources) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = mobname
                    d.label = mobname

                    d.value = amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(amount),
                        mod.metadata.columns.Damage,
                        format("%02.1f%%", amount / player.damagetaken.amount * 100),
                        mod.metadata.columns.Percent
                    )

                    if amount > max then
                        max = amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        local function add_detail_bar(win, nr, title, value)
            local d = win.dataset[nr] or {}
            win.dataset[nr] = d

            d.id = title
            d.label = title
            d.value = value
            if title == L["Total"] then
                d.valuetext = value
            else
                d.valuetext =
                    Skada:FormatValueText(
                    value,
                    mod.metadata.columns.Damage,
                    format("%02.1f%%", value / win.metadata.maxvalue * 100),
                    mod.metadata.columns.Percent
                )
            end
        end

        function spellmod:Enter(win, id, label)
            self.spellid = id
            self.title = label .. ": " .. playermod.playername
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, playermod.playerid)

            if player and player.damagetaken.spells then
                local spell = player.damagetaken.spells[self.spellid]

                if spell then
                    win.metadata.maxvalue = spell.totalhits
                    local nr = 1
                    add_detail_bar(win, nr, L["Total"], spell.totalhits)

                    if spell.hit and spell.hit > 0 then
                        nr = nr + 1
                        add_detail_bar(win, nr, HIT, spell.hit)
                    end
                    if spell.critical and spell.critical > 0 then
                        nr = nr + 1
                        add_detail_bar(win, nr, CRIT_ABBR, spell.critical)
                    end
                    if spell.glancing and spell.glancing > 0 then
                        nr = nr + 1
                        add_detail_bar(win, nr, L["Glancing"], spell.glancing)
                    end
                    if spell.crushing and spell.crushing > 0 then
                        add_detail_bar(win, nr, L["Crushing"], spell.crushing)
                        nr = nr + 1
                    end

                    for i, misstype in ipairs(misstypes) do
                        if spell[misstype] and spell[misstype] > 0 then
                            local title = _G[misstype] or _G["ACTION_SPELL_MISSED" .. misstype] or misstype
                            nr = nr + 1
                            add_detail_bar(win, nr, title, spell[misstype])
                        end
                    end
                end
            end
        end

        function spelltargetsmod:Enter(win, id, label)
            self.spellid = id
            self.title = format(L["%s's targets"], label)
        end

        function spelltargetsmod:Update(win, set)
            local nr, max = 1, 0

            for i, player in ipairs(set.players) do
                if player.damagetaken.amount > 0 and player.damagetaken.spells[self.spellid] then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role

                    local amount = player.damagetaken.spells[self.spellid].amount

                    d.value = amount
                    d.valuetext = Skada:FormatNumber(amount)

                    if amount > max then
                        max = amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function spellsmod:Update(win, set)
            local spells, _ = {}

            for i, player in ipairs(set.players) do
                if player.damagetaken.amount > 0 then
                    for id, spell in pairs(player.damagetaken.spells) do
                        spells[id] = spells[id] or spell
                        spells[id].spellname, _, spells[id].spellicon = GetSpellInfo(id)
                    end
                end
            end

            local nr, max = 1, 0

            for spellid, spell in pairs(spells) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = spellid
                d.spellid = spellid
                d.spellschool = spell.school
                d.spellname = spell.spellname
                d.label = spell.spellname
                d.icon = spell.spellicon

                d.value = spell.amount
                d.valuetext =
                    format("%s (%02.1f%%)", Skada:FormatNumber(spell.amount), spell.amount / set.damagetaken * 100)

                if spell.amount > max then
                    max = spell.amount
                end

                nr = nr + 1
            end

            win.metadata.maxvalue = max
        end

        function mod:Update(win, set)
            local nr, max = 1, 0

            for i, player in ipairs(set.players) do
                if player.damagetaken.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    local totaltime = Skada:PlayerActiveTime(set, player)

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role

                    d.value = player.damagetaken.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.damagetaken.amount),
                        self.metadata.columns.Damage,
                        Skada:FormatNumber(getDTPS(set, player)),
                        self.metadata.columns.DTPS,
                        format("%02.1f%%", player.damagetaken.amount / set.damagetaken * 100),
                        self.metadata.columns.Percent
                    )

                    if player.damagetaken.amount > max then
                        max = player.damagetaken.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        local function spellmod_tooltip(win, id, label, tooltip)
            local player = Skada:find_player(win:get_selected_set(), playermod.playerid)
            if not player then
                return
            end

            local spell = player.damagetaken.spells[spellmod.spellid]
            if not spell then
                return
            end

            tooltip:AddLine(label .. ": " .. player.name)

            if spell.school then
                local c = Skada.schoolcolors[spell.school]
                local n = Skada.schoolnames[spell.school]
                if c and n then
                    tooltip:AddLine(L[n], c.r, c.g, c.b)
                end
            end

            if spell.max and spell.min then
                tooltip:AddDoubleLine(L["Minimum hit:"], Skada:FormatNumber(spell.min), 255, 255, 255, 255, 255, 255)
                tooltip:AddDoubleLine(L["Maximum hit:"], Skada:FormatNumber(spell.max), 255, 255, 255, 255, 255, 255)
            end
            tooltip:AddDoubleLine(
                L["Average hit:"],
                Skada:FormatNumber(spell.amount / spell.totalhits),
                255,
                255,
                255,
                255,
                255,
                255
            )

            if spell.blocked and spell.blocked > 0 then
                tooltip:AddDoubleLine(BLOCK, Skada:FormatNumber(spell.blocked), 255, 255, 255, 255, 255, 255)
            end
            if spell.resisted and spell.resisted > 0 then
                tooltip:AddDoubleLine(RESIST, Skada:FormatNumber(spell.resisted), 255, 255, 255, 255, 255, 255)
            end
            if spell.absorbed and spell.absorbed > 0 then
                tooltip:AddDoubleLine(ABSORB, Skada:FormatNumber(spell.absorbed), 255, 255, 255, 255, 255, 255)
            end
        end

        function mod:OnEnable()
            spellmod.metadata = {}
            playermod.metadata = {tooltip = spellmod_tooltip, click1 = spellmod}
            sourcemod.metadata = {}
            mod.metadata = {
                showspots = true,
                click1 = playermod,
                click2 = sourcemod,
                columns = {Damage = true, DTPS = true, Percent = true}
            }

            spelltargetsmod.metadata = {showspots = true}
            spellsmod.metadata = {showspots = true, ordersort = true, click1 = spelltargetsmod}

            Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true})

            Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true})

            Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {dst_is_interesting_nopets = true})

            Skada:AddMode(self, L["Damage"])
            Skada:AddMode(spellsmod, L["Damage"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
            Skada:RemoveMode(spellsmod)
        end

        function mod:GetSetSummary(set)
            return Skada:FormatValueText(
                Skada:FormatNumber(set.damagetaken),
                self.metadata.columns.Damage,
                Skada:FormatNumber(getRaidDTPS(set)),
                self.metadata.columns.DTPS
            )
        end

        function mod:AddPlayerAttributes(player)
            if not player.damagetaken then
                player.damagetaken = {amount = 0, spells = {}, sources = {}}
            end
        end

        function mod:AddSetAttributes(set)
            set.damagetaken = set.damagetaken or 0
        end

        function mod:SetComplete(set)
            for i, player in ipairs(set.players) do
                if player.damagetaken.amount == 0 then
                    player.damagetaken.spells = nil
                    player.damagetaken.sources = nil
                end
            end
        end
    end
)

-- ============================= --
-- Avoidance & Mitigation Module --
-- ============================= --
Skada:AddLoadableModule(
    "Avoidance & Mitigation",
    nil,
    function(Skada, L)
        if Skada:IsDisabled(damagetaken, "Avoidance & Mitigation") then
            return
        end

        local mod = Skada:NewModule(L["Avoidance & Mitigation"])
        local playermod = mod:NewModule(L["Damage breakdown"])

        local misstypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "PARRY", "REFLECT", "RESIST", "MISS"}
        local temp = {}

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.title = format("%s's damage breakdown", label)
        end

        function playermod:Update(win, set)
            local max = 0

            if temp[self.playerid] then
                local nr = 1
                local p = temp[self.playerid]

                for event, count in pairs(p.data) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = event
                    d.label = _G[event] or event
                    d.value = count / p.total * 100
                    d.valuetext = format("%d (%02.1f%%)", count, d.value)

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

            for i, player in ipairs(set.players) do
                if player.damagetaken.amount > 0 then
                    temp[player.id] = {data = {}}

                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role

                    local total, avoid = 0, 0
                    for spellname, spell in pairs(player.damagetaken.spells) do
                        total = total + spell.totalhits

                        for _, t in ipairs(misstypes) do
                            if spell[t] and spell[t] > 0 then
                                avoid = avoid + spell[t]
                                if not temp[player.id].data[t] then
                                    temp[player.id].data[t] = spell[t]
                                else
                                    temp[player.id].data[t] = temp[player.id].data[t] + spell[t]
                                end
                            end
                        end
                    end

                    temp[player.id].total = total
                    temp[player.id].avoid = avoid

                    d.value = avoid / total * 100
                    d.valuetext = format("%02.1f%% (%d/%d)", d.value, avoid, total)

                    if d.value > max then
                        max = d.value
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            playermod.metadata = {}
            mod.metadata = {showspots = true, click1 = playermod}

            Skada:AddMode(self, L["Damage"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end
    end
)

-- ============== --
-- Enemies Module --
-- ============== --

do
    local function find_mob(set, name)
        if not set.enemies.list[name] then
            set.enemies.list[name] = {done = 0, taken = 0, players = {}}
        end
        return set.enemies.list[name]
    end

    local function find_player(mob, name)
        if not mob.players[name] then
            local unitCLass = select(2, UnitClass(name))
            local unitRole = UnitGroupRolesAssigned(name) or "NONE"
            mob.players[name] = {class = unitCLass, role = unitRole, done = 0, taken = 0}
        end
        return mob.players[name]
    end

    local function ModUpdate(stat, mod)
        return function(self, win, set)
            local nr, max = 1, 0

            for mobname, mob in pairs(set.enemies.list) do
                if (mob[stat] or 0) > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = mobname
                    d.label = mobname
                    d.value = mob[stat]

                    if mod and mod.metadata.columns then
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(mob[stat]),
                            mod.metadata.columns.Damage,
                            format("%02.1f%%", 100 * mob[stat] / math.max(1, set.enemies[stat])),
                            mod.metadata.columns.Percent
                        )
                    else
                        d.valuetext = Skada:FormatNumber(mob[stat])
                    end

                    if mob[stat] > max then
                        max = mob[stat]
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end
    end

    -- ================== --
    -- Enemy damage done --
    -- ================== --
    Skada:AddLoadableModule(
        "Enemy damage done",
        nil,
        function(Skada, L)
            if Skada:IsDisabled("Enemy damage done") then
                return
            end

            local mod = Skada:NewModule(L["Enemy damage done"])
            mod.Update = ModUpdate("done", mod)

            local playermod = mod:NewModule(L["Damage done per player"])

            local function log_damage_done(set, dmg)
                if dmg.amount and dmg.amount > 0 then
                    set.enemies.done = set.enemies.done + dmg.amount

                    local mob = find_mob(set, dmg.srcName)
                    mob.done = mob.done + dmg.amount

                    local player = find_player(mob, dmg.dstName)
                    player.done = player.done + dmg.amount
                end
            end

            local dmg = {}

            local function SpellDamageDone(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
                if srcName and dstName then
                    dmg = _SpellDamage(true, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
                    log_damage_done(Skada.current, dmg)
                end
            end

            local function SwingDamageDone(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
                if srcName and dstName then
                    dmg = _SwingDamage(true, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
                    log_damage_done(Skada.current, dmg)
                end
            end

            function playermod:Enter(win, id, label)
                self.mobname = label
                self.title = format(L["Damage from %s"], label)
            end

            function playermod:Update(win, set)
                if self.mobname then
                    local max = 0

                    for mobname, mob in pairs(set.enemies.list) do
                        if mobname == self.mobname then
                            local nr = 1

                            for playername, player in pairs(mob.players) do
                                if player.done > 0 then
                                    local d = win.dataset[nr] or {}
                                    win.dataset[nr] = d

                                    d.id = playername
                                    d.label = playername
                                    d.class = player.class
                                    d.role = player.role

                                    d.value = player.done
                                    d.valuetext =
                                        Skada:FormatValueText(
                                        Skada:FormatNumber(player.done),
                                        mod.metadata.columns.Damage,
                                        format("%02.1f%%", 100 * player.done / math.max(1, set.enemies.done)),
                                        mod.metadata.columns.Percent
                                    )

                                    if player.done > max then
                                        max = player.done
                                    end

                                    nr = nr + 1
                                end
                            end

                            break
                        end
                    end

                    win.metadata.maxvalue = max
                end
            end

            function mod:OnEnable()
                playermod.metadata = {showspots = true}
                mod.metadata = {click1 = playermod, columns = {Damage = true, Percent = true}}

                Skada:RegisterForCL(
                    SpellDamageDone,
                    "SPELL_DAMAGE",
                    {dst_is_interesting_nopets = true, src_is_not_interesting = true}
                )
                Skada:RegisterForCL(
                    SpellDamageDone,
                    "SPELL_PERIODIC_DAMAGE",
                    {dst_is_interesting_nopets = true, src_is_not_interesting = true}
                )
                Skada:RegisterForCL(
                    SpellDamageDone,
                    "SPELL_BUILDING_DAMAGE",
                    {dst_is_interesting_nopets = true, src_is_not_interesting = true}
                )
                Skada:RegisterForCL(
                    SpellDamageDone,
                    "RANGE_DAMAGE",
                    {dst_is_interesting_nopets = true, src_is_not_interesting = true}
                )
                Skada:RegisterForCL(
                    SwingDamageDone,
                    "SWING_DAMAGE",
                    {dst_is_interesting_nopets = true, src_is_not_interesting = true}
                )

                Skada:AddMode(self, L["Damage"])
            end

            function mod:OnDisable()
                Skada:RemoveMode(self)
            end

            function mod:GetSetSummary(set)
                return Skada:FormatValueText(
                    Skada:FormatNumber(set.enemies.done),
                    self.metadata.columns.Damage,
                    format("%02.1f%%", 100 * set.enemies.done / math.max(1, set.enemies.done)),
                    self.metadata.columns.Percent
                )
            end

            function mod:AddSetAttributes(set)
                set.enemies = set.enemies or {}
                set.enemies.list = set.enemies.list or {}
                set.enemies.done = set.enemies.done or 0
            end
        end
    )

    -- ================== --
    -- Enemy damage taken --
    -- ================== --
    Skada:AddLoadableModule(
        "Enemy damage taken",
        nil,
        function(Skada, L)
            if Skada:IsDisabled("Enemy damage taken") then
                return
            end

            local mod = Skada:NewModule(L["Enemy damage taken"])
            mod.Update = ModUpdate("taken", mod)

            local playermod = mod:NewModule(L["Damage taken per player"])

            local function log_damage_taken(set, dmg)
                if dmg.amount and dmg.amount > 0 then
                    set.enemies.taken = set.enemies.taken + dmg.amount

                    local mob = find_mob(set, dmg.dstName)
                    mob.taken = mob.taken + dmg.amount

                    local player = find_player(mob, dmg.srcName)
                    player.taken = player.taken + dmg.amount
                end
            end

            local function SpellDamageTaken(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
                if srcName and dstName then
                    dmg = _SpellDamage(true, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
                    dmg.srcGUID, dmg.srcName = Skada:FixMyPets(dmg.srcGUID, dmg.srcName)
                    log_damage_taken(Skada.current, dmg)
                end
            end

            local function SwingDamageTaken(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
                if srcName and dstName then
                    dmg = _SwingDamage(true, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
                    dmg.srcGUID, dmg.srcName = Skada:FixMyPets(dmg.srcGUID, dmg.srcName)
                    log_damage_taken(Skada.current, dmg)
                end
            end

            function playermod:Enter(win, id, label)
                self.mobname = label
                self.title = format(L["Damage on %s"], label)
            end

            function playermod:Update(win, set)
                if self.mobname then
                    local max = 0

                    for mobname, mob in pairs(set.enemies.list) do
                        if mobname == self.mobname then
                            local nr = 1

                            for name, player in pairs(mob.players) do
                                if player.taken > 0 then
                                    local d = win.dataset[nr] or {}
                                    win.dataset[nr] = d

                                    d.id = name
                                    d.label = name
                                    d.class = player.class
                                    d.role = player.role

                                    d.value = player.taken
                                    d.valuetext =
                                        Skada:FormatValueText(
                                        Skada:FormatNumber(player.taken),
                                        mod.metadata.columns.Damage,
                                        format("%02.1f%%", 100 * player.taken / math.max(1, set.enemies.taken)),
                                        mod.metadata.columns.Percent
                                    )

                                    if player.taken > max then
                                        max = player.taken
                                    end

                                    nr = nr + 1
                                end
                            end

                            break
                        end
                    end

                    win.metadata.maxvalue = max
                end
            end

            function mod:OnEnable()
                playermod.metadata = {showspots = true}
                mod.metadata = {click1 = playermod, columns = {Damage = true, Percent = true}}

                Skada:RegisterForCL(
                    SpellDamageTaken,
                    "SPELL_DAMAGE",
                    {src_is_interesting = true, dst_is_not_interesting = true}
                )
                Skada:RegisterForCL(
                    SpellDamageTaken,
                    "SPELL_PERIODIC_DAMAGE",
                    {src_is_interesting = true, dst_is_not_interesting = true}
                )
                Skada:RegisterForCL(
                    SpellDamageTaken,
                    "SPELL_BUILDING_DAMAGE",
                    {src_is_interesting = true, dst_is_not_interesting = true}
                )
                Skada:RegisterForCL(
                    SpellDamageTaken,
                    "RANGE_DAMAGE",
                    {src_is_interesting = true, dst_is_not_interesting = true}
                )
                Skada:RegisterForCL(
                    SwingDamageTaken,
                    "SWING_DAMAGE",
                    {src_is_interesting = true, dst_is_not_interesting = true}
                )

                Skada:AddMode(self, L["Damage"])
            end

            function mod:OnDisable()
                Skada:RemoveMode(self)
            end

            function mod:GetSetSummary(set)
                return Skada:FormatValueText(
                    Skada:FormatNumber(set.enemies.taken),
                    self.metadata.columns.Damage,
                    format("%02.1f%%", 100 * set.enemies.taken / math.max(1, set.enemies.taken)),
                    self.metadata.columns.Percent
                )
            end

            function mod:AddSetAttributes(set)
                set.enemies = set.enemies or {}
                set.enemies.list = set.enemies.list or {}
                set.enemies.taken = set.enemies.taken or 0
            end
        end
    )
end

-- ==================== --
-- Friendly Fire Module --
-- ==================== --
Skada:AddLoadableModule(
    "Friendly Fire",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Friendly Fire") then
            return
        end

        local mod = Skada:NewModule(L["Friendly Fire"])
        local spellmod = mod:NewModule(L["Damage spell list"])
        local playermod = mod:NewModule(L["Damage spell targets"])

        local function log_damage(set, dmg)
            local amount = (dmg.amount or 0) + (dmg.overkill or 0) + (dmg.absorbed or 0)
            if amount > 0 then
                -- Get the player.
                local player = Skada:get_player(set, dmg.srcGUID, dmg.srcName)
                if not player then
                    return
                end

                set.friendfire = set.friendfire + amount
                player.friendfire.amount = player.friendfire.amount + amount

                -- record spell damage
                if not player.friendfire.spells[dmg.spellid] then
                    player.friendfire.spells[dmg.spellid] = 0
                end
                player.friendfire.spells[dmg.spellid] = player.friendfire.spells[dmg.spellid] + amount

                -- add target
                if not player.friendfire.targets[dmg.dstName] then
                    player.friendfire.targets[dmg.dstName] = {
                        id = dmg.dstGUID,
                        class = select(2, UnitClass(dmg.dstName)),
                        amount = 0
                    }
                end
                player.friendfire.targets[dmg.dstName].amount = player.friendfire.targets[dmg.dstName].amount + amount
            end
        end

        local dmg = {}

        local function SpellDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            dmg = _SpellDamage((dstGUID ~= srcGUID), srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if dmg then
                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        local function SwingDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            dmg = _SwingMissed((dstGUID ~= srcGUID), srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if dmg then
                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's targets"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player and player.friendfire.targets then
                local nr = 1

                for targetname, target in pairs(player.friendfire.targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname
                    d.class = target.class

                    d.value = target.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(target.amount),
                        mod.metadata.columns.Damage,
                        format("%02.1f%%", target.amount / set.friendfire * 100),
                        mod.metadata.columns.Percent
                    )

                    if target.amount > max then
                        max = target.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function spellmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's damage"], label)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for spellid, amount in pairs(player.friendfire.spells) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    local spellname, _, spellicon = GetSpellInfo(spellid)

                    d.id = spellid
                    d.label = spellname
                    d.icon = spellicon

                    d.value = amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(amount),
                        mod.metadata.columns.Damage,
                        format("%02.1f%%", amount / set.friendfire * 100),
                        mod.metadata.columns.Percent
                    )

                    if amount > max then
                        max = amount
                    end

                    nr = nr + 1
                end
            end
            win.metadata.maxvalue = max
        end

        function mod:Update(win, set)
            local nr, max = 1, 0

            for i, player in pairs(set.players) do
                if player.friendfire.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role

                    d.value = player.friendfire.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.friendfire.amount),
                        self.metadata.columns.Damage,
                        format("%02.1f%%", player.friendfire.amount / set.friendfire * 100),
                        self.metadata.columns.Percent
                    )
                    d.valuetext =
                        format(
                        "%s (%02.1f%%)",
                        Skada:FormatNumber(player.friendfire.amount),
                        player.friendfire.amount / set.friendfire * 100
                    )

                    if player.friendfire.amount > max then
                        max = player.friendfire.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            spellmod.metadata = {}
            playermod.metadata = {}
            mod.metadata = {
                showspots = true,
                click1 = spellmod,
                click2 = playermod,
                columns = {Damage = true, Percent = true}
            }

            Skada:RegisterForCL(
                SpellDamage,
                "SPELL_DAMAGE",
                {dst_is_interesting_nopets = true, src_is_interesting_nopets = true}
            )
            Skada:RegisterForCL(
                SpellDamage,
                "SPELL_PERIODIC_DAMAGE",
                {dst_is_interesting_nopets = true, src_is_interesting_nopets = true}
            )
            Skada:RegisterForCL(
                SpellDamage,
                "SPELL_BUILDING_DAMAGE",
                {dst_is_interesting_nopets = true, src_is_interesting_nopets = true}
            )
            Skada:RegisterForCL(
                SpellDamage,
                "RANGE_DAMAGE",
                {dst_is_interesting_nopets = true, src_is_interesting_nopets = true}
            )
            Skada:RegisterForCL(
                SwingDamage,
                "SWING_DAMAGE",
                {dst_is_interesting_nopets = true, src_is_interesting_nopets = true}
            )

            Skada:AddMode(self, L["Damage"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddPlayerAttributes(player)
            if not player.friendfire then
                player.friendfire = {amount = 0, spells = {}, targets = {}}
            end
        end

        function mod:AddSetAttributes(set)
            set.friendfire = set.friendfire or 0
        end

        function mod:GetSetSummary(set)
            return Skada:FormatValueText(
                Skada:FormatNumber(set.friendfire),
                self.metadata.columns.Damage,
                format("%02.1f%%", 100 * set.friendfire / math.max(1, set.friendfire)),
                self.metadata.columns.Percent
            )
        end

        function mod:SetComplete(set)
            for i, player in ipairs(set.players) do
                if player.friendfire.amount == 0 then
                    player.friendfire.spells = nil
                    player.friendfire.targets = nil
                end
            end
        end
    end
)