assert(Skada, "Skada not found!")

local _UnitGUID = UnitGUID
local _GetSpellInfo = Skada.GetSpellInfo
local _format, math_max, math_min = string.format, math.max, math.min
local _pairs, _ipairs, _select = pairs, ipairs, select

-- list of miss types
local misstypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}

-- ================== --
-- Damage Done Module --
-- ================== --

Skada:AddLoadableModule("Damage", function(Skada, L)
    if Skada:IsDisabled("Damage") then return end

    local mod = Skada:NewModule(L["Damage"])
    local playermod = mod:NewModule(L["Damage spell list"])
    local targetmod = mod:NewModule(L["Damage target list"])
    local spellmod = mod:NewModule(L["Damage spell details"])

    local dpsmod = Skada:NewModule(L["DPS"])

    local LBB = LibStub("LibBabble-Boss-3.0"):GetLookupTable()

    --
    -- holds the name of targets used to record useful damage
    --
    local groupName, validTarget

    --
    -- the instance difficulty is only called once to reduce
    -- useless multiple calls that return the same thing
    -- This value is set to nil on SetComplete
    --
    local instanceDiff

    local function get_raid_diff()
        if not instanceDiff then
            local _, instanceType, difficulty, _, _, dynamicDiff, isDynamic = GetInstanceInfo()
            if instanceType == "raid" and isDynamic then
                if difficulty == 1 or difficulty == 3 then -- 10man raid
                    instanceDiff = (dynamicDiff == 0) and "10n" or ((dynamicDiff == 1) and "10h" or "unknown")
                elseif difficulty == 2 or difficulty == 4 then -- 25main raid
                    instanceDiff = (dynamicDiff == 0) and "25n" or ((dynamicDiff == 1) and "25h" or "unknown")
                end
            else
                local insDiff = GetInstanceDifficulty()
                if insDiff == 1 then
                    instanceDiff = "10n"
                elseif insDiff == 2 then
                    instanceDiff = "25n"
                elseif insDiff == 3 then
                    instanceDiff = "10h"
                elseif insDiff == 4 then
                    instanceDiff = "25h"
                end
            end
        end

        return instanceDiff
    end

    local valkyrsTable
    local valkyr10hp, valkyr25hp = 1900000, 2992000

    local function log_damage(set, dmg)
        local player = Skada:get_player(set, dmg.playerid, dmg.playername, dmg.playerflags)
        if not player then
            return
        end

        set.damagedone = set.damagedone + dmg.amount
        player.damagedone.amount = player.damagedone.amount + dmg.amount

        if not player.damagedone.spells[dmg.spellname] then
            player.damagedone.spells[dmg.spellname] = {
                id = dmg.spellid,
                amount = 0,
                school = dmg.spellschool
            }
        end

        local spell = player.damagedone.spells[dmg.spellname]
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

        -- add the damage overkill
        if dmg.overkill and dmg.overkill > 0 then
            spell.overkill = (spell.overkill or 0) + dmg.overkill
            player.overkill = (player.overkill or 0) + dmg.overkill
            set.overkill = (set.overkill or 0) + dmg.overkill
        end

        if set == Skada.current and dmg.dstName and dmg.amount > 0 then
            spell.targets = spell.targets or {}
            spell.targets[dmg.dstName] = (spell.targets[dmg.dstName] or 0) + dmg.amount
            player.damagedone.targets[dmg.dstName] = (player.damagedone.targets[dmg.dstName] or 0) + dmg.amount

            -- add useful damage.
            if validTarget[dmg.dstName] then
                local altname = groupName[validTarget[dmg.dstName]]

                -- same name, ignore to not have double damage.
                if altname == dmg.dstName then
                    return
                end

                -- useful damage on Val'kyrs
                if dmg.dstName == LBB["Val'kyr Shadowguard"] then
                    local diff = get_raid_diff()

                    -- useful damage accounts only on heroic mode.
                    if diff == "10h" or diff == "25h" then
                        -- we make sure to always have a table.
                        valkyrsTable = valkyrsTable or {}

                        -- valkyr's max health depending on the difficulty
                        local maxhp = diff == "10h" and valkyr10hp or valkyr25hp

                        -- we make sure to add our valkyr to the table
                        if not valkyrsTable[dmg.dstGUID] then
                            valkyrsTable[dmg.dstGUID] = maxhp - dmg.amount
                        else
                            --
                            -- here, the valkyr was already recorded, it reached half its health
                            -- but the player still dpsing it. This counts as useless damage.
                            --
                            if valkyrsTable[dmg.dstGUID] < maxhp / 2 then
                                spell.targets[L["Valkyrs overkilling"]] =
                                    (spell.targets[L["Valkyrs overkilling"]] or 0) + dmg.amount
                                player.damagedone.targets[L["Valkyrs overkilling"]] =
                                    (player.damagedone.targets[L["Valkyrs overkilling"]] or 0) + dmg.amount
                                return
                            end

                            -- deducte the damage
                            valkyrsTable[dmg.dstGUID] = valkyrsTable[dmg.dstGUID] - dmg.amount
                        end
                    end
                end

                -- if we are on BPC, we attempt to catch overkilling
                local amount = (validTarget[dmg.dstName] == LBB["Blood Prince Council"]) and dmg.overkill or dmg.amount
                spell.targets[altname] = (spell.targets[altname] or 0) + amount
                player.damagedone.targets[altname] = (player.damagedone.targets[altname] or 0) + amount
            end
        end
    end

    local dmg = {}

    local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        if srcGUID ~= dstGUID then
            local spellid, spellname, spellschool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...

            dmg.playerid = srcGUID
            dmg.playername = srcName
            dmg.playerflags = srcFlags

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

            Skada:FixPets(dmg)

            log_damage(Skada.current, dmg)
            log_damage(Skada.total, dmg)
        end
    end

    local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, L["Auto Attack"], 1, ...)
    end

    local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        if srcGUID ~= dstGUID then
            local spellid, spellname, spellschool, misstype, amount = ...

            dmg.playerid = srcGUID
            dmg.playername = srcName
            dmg.playerflags = srcFlags

            dmg.dstGUID = dstGUID
            dmg.dstName = dstName
            dmg.dstFlags = dstFlags

            dmg.spellid = spellid
            dmg.spellname = spellname
            dmg.spellschool = spellschool
            dmg.amount = 0

            dmg.overkill = 0
            dmg.resisted = nil
            dmg.blocked = nil
            dmg.absorbed = nil
            dmg.critical = nil
            dmg.glancing = nil
            dmg.crushing = nil
            dmg.missed = misstype

            Skada:FixPets(dmg)

            log_damage(Skada.current, dmg)
            log_damage(Skada.total, dmg)
        end
    end

    local function SwingMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        SpellMissed(nil, nil, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, L["Auto Attack"], 1, ...)
    end

    local function getDPS(set, player)
        local uptime = math_min(Skada:GetSetTime(set), Skada:PlayerActiveTime(set, player))
        return player.damagedone.amount / math_max(1, uptime)
    end

    local function getRaidDPS(set)
        if set.time > 0 then
            return set.damagedone / math_max(1, set.time)
        else
            local endtime = set.endtime or time()
            return set.damagedone / math_max(1, endtime - set.starttime)
        end
    end

    local function damage_tooltip(win, id, label, tooltip)
        local set = win:get_selected_set()
        local player = Skada:find_player(set, id)
        if player then
            local totaltime = Skada:GetSetTime(set)
            local activetime = math_min(totaltime, Skada:PlayerActiveTime(set, player))
            tooltip:AddDoubleLine(L["Activity"], _format("%02.1f%%", 100 * activetime / totaltime), 1, 1, 1)
            tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
            tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
        end
    end

    local function dps_tooltip(win, id, label, tooltip)
        local set = win:get_selected_set()
        local player = Skada:find_player(set, id)
        if player then
            local totaltime = Skada:GetSetTime(set)
            local activetime = math_min(totaltime, Skada:PlayerActiveTime(set, player))
            tooltip:AddLine(player.name .. " - " .. L["DPS"])
            tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 1, 1, 1)
            tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 1, 1, 1)
            tooltip:AddDoubleLine(L["Damage done"], Skada:FormatNumber(player.damagedone.amount), 1, 1, 1)
            tooltip:AddDoubleLine(Skada:FormatNumber(player.damagedone.amount) .. "/" .. activetime .. ":", Skada:FormatNumber(player.damagedone.amount / math_max(1, activetime)), 1, 1, 1)
        end
    end

    local function player_tooltip(win, id, label, tooltip)
        local player = Skada:find_player(win:get_selected_set(), win.playerid)
        if not player then
            return
        end

        local spell = player.damagedone.spells[id]
        if spell then
            tooltip:AddLine(player.name .. " - " .. label)

            if spell.school then
                local c = Skada.schoolcolors[spell.school]
                local n = Skada.schoolnames[spell.school]
                if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
            end

            if spell.max and spell.min then
                tooltip:AddDoubleLine(L["Minimum hit:"], Skada:FormatNumber(spell.min), 1, 1, 1)
                tooltip:AddDoubleLine(L["Maximum hit:"], Skada:FormatNumber(spell.max), 1, 1, 1)
            end
            tooltip:AddDoubleLine(L["Average hit:"], Skada:FormatNumber(spell.amount / spell.totalhits), 1, 1, 1)
            tooltip:AddDoubleLine(L["Total hits:"], tostring(spell.totalhits), 1, 1, 1)
        end
    end

    local function spellmod_tooltip(win, id, label, tooltip)
        if label == CRIT_ABBR or label == HIT or label == ABSORB or label == BLOCK or label == RESIST then
            local player = Skada:find_player(win:get_selected_set(), win.playerid)
            if not player then
                return
            end

            local spell = player.damagedone.spells[win.spellname]
            if spell then
                tooltip:AddLine(player.name .. " - " .. win.spellname)

                if spell.school then
                    local c = Skada.schoolcolors[spell.school]
                    local n = Skada.schoolnames[spell.school]
                    if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
                end

                if label == CRIT_ABBR and spell.criticalamount then
                    tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 1, 1, 1)
                    tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 1, 1, 1)
                    tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 1, 1, 1)
                elseif label == HIT and spell.hitamount then
                    tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.hitmin), 1, 1, 1)
                    tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.hitmax), 1, 1, 1)
                    tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.hitamount / spell.hit), 1, 1, 1)
                elseif label == ABSORB and spell.absorbed and spell.absorbed > 0 then
                    tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.absorbed), 1, 1, 1)
                elseif label == BLOCK and spell.blocked and spell.blocked > 0 then
                    tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.blocked), 1, 1, 1)
                elseif label == RESIST and spell.resisted and spell.resisted > 0 then
                    tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.resisted), 1, 1, 1)
                end
            end
        end
    end

    function playermod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's damage"], label)
    end

    function playermod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.damagedone.spells then
            win.title = _format(L["%s's damage"], player.name)

            local nr = 1
            for spellname, spell in _pairs(player.damagedone.spells) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = spellname
                d.spellid = spell.id
                d.spellschool = spell.school
                d.label = spellname
                d.icon = _select(3, _GetSpellInfo(spell.id))

                d.value = spell.amount
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(spell.amount),
                    mod.metadata.columns.Damage,
                    _format("%02.1f%%", 100 * spell.amount / math_max(1, player.damagedone.amount)),
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
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's targets"], label)
    end

    function targetmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.damagedone.targets then
            win.title = _format(L["%s's targets"], player.name)

            local nr = 1
            for mobname, amount in _pairs(player.damagedone.targets) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = mobname
                d.label = mobname

                d.value = amount
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(amount),
                    mod.metadata.columns.Damage,
                    _format("%02.1f%%", 100 * amount / math_max(1, player.damagedone.amount)),
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
        d.valuetext = Skada:FormatValueText(
            value,
            mod.metadata.columns.Damage,
            _format("%02.1f%%", 100 * value / math_max(1, win.metadata.maxvalue)),
            mod.metadata.columns.Percent
        )
    end

    function spellmod:Enter(win, id, label)
        win.spellname = label
        win.title = _format(L["%s's <%s> damage"], win.playername or UNKNOWN, label)
    end

    function spellmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)

        if player and player.damagedone.spells then
            local spell = player.damagedone.spells[win.spellname]

            if spell then
                win.metadata.maxvalue = spell.totalhits
                win.title = _format(L["%s's <%s> damage"], player.name, win.spellname)

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
                for _, misstype in _ipairs(misstypes) do
                    if spell[misstype] and spell[misstype] > 0 then
                        local title = _G[misstype] or _G["ACTION_SPELL_MISSED" .. misstype] or misstype
                        add_detail_bar(win, nr, title, spell[misstype])
                        nr = nr + 1
                    end
                end
            end
        end
    end

    function mod:Update(win, set)
        local nr, max = 1, 0

        for i, player in _ipairs(set.players) do
            if player.damagedone.amount > 0 then
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class
                d.role = player.role
                d.spec = player.spec

                local dps = getDPS(set, player)

                d.value = player.damagedone.amount
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(player.damagedone.amount),
                    self.metadata.columns.Damage,
                    Skada:FormatNumber(dps),
                    self.metadata.columns.DPS,
                    _format("%02.1f%%", 100 * player.damagedone.amount / math_max(1, set.damagedone)),
                    self.metadata.columns.Percent
                )

                if player.damagedone.amount > max then
                    max = player.damagedone.amount
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Damage"]
    end

    local function feed_personal_dps()
        if Skada.current then
            local player = Skada:find_player(Skada.current, _UnitGUID("player"))
            if player then
                return Skada:FormatNumber(getDPS(Skada.current, player)) .. " " .. L["DPS"]
            end
        end
    end

    local function feed_raid_dps()
        if Skada.current then
            return Skada:FormatNumber(getRaidDPS(Skada.current)) .. " " .. L["RDPS"]
        end
    end

    function dpsmod:GetSetSummary(set)
        return Skada:FormatNumber(getRaidDPS(set))
    end

    function dpsmod:Update(win, set)
        local nr, max = 1, 0
        local total = getRaidDPS(set)

        for i, player in _ipairs(set.players) do
            local dps = getDPS(set, player)

            if dps > 0 then
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class
                d.role = player.role
                d.spec = player.spec

                d.value = dps
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(dps),
                    self.metadata.columns.DPS,
                    _format("%02.1f%%", 100 * dps / math_max(1, total)),
                    self.metadata.columns.Percent
                )

                if dps > max then
                    max = dps
                end
                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["DPS"]
    end

    --
    -- we make sure to fill our groupName and validTarget tables
    -- used to record damage on useful targets
    --
    function mod:OnInitialize()
        if not groupName then
            groupName = {
                [LBB["The Lich King"]] = L["Useful targets"],
                [LBB["Professor Putricide"]] = L["Oozes"],
                [LBB["Blood Prince Council"]] = L["Princes overkilling"],
                [LBB["Lady Deathwhisper"]] = L["Adds"],
                [LBB["Halion"]] = L["Halion and Inferno"]
            }
        end

        if not validTarget then
            validTarget = {
                -- The Lich King fight
                [LBB["The Lich King"]] = LBB["The Lich King"],
                [LBB["Raging Spirit"]] = LBB["The Lich King"],
                [LBB["Ice Sphere"]] = LBB["The Lich King"],
                [LBB["Val'kyr Shadowguard"]] = LBB["The Lich King"],
                [L["Wicked Spirit"]] = LBB["The Lich King"],
                -- Professor Putricide
                [L["Gas Cloud"]] = LBB["Professor Putricide"],
                [L["Volatile Ooze"]] = LBB["Professor Putricide"],
                -- Blood Prince Council
                [LBB["Prince Valanar"]] = LBB["Blood Prince Council"],
                [LBB["Prince Taldaram"]] = LBB["Blood Prince Council"],
                [LBB["Prince Keleseth"]] = LBB["Blood Prince Council"],
                -- Lady Deathwhisper
                [L["Cult Adherent"]] = LBB["Lady Deathwhisper"],
                [L["Empowered Adherent"]] = LBB["Lady Deathwhisper"],
                [L["Reanimated Adherent"]] = LBB["Lady Deathwhisper"],
                [L["Cult Fanatic"]] = LBB["Lady Deathwhisper"],
                [L["Deformed Fanatic"]] = LBB["Lady Deathwhisper"],
                [L["Reanimated Fanatic"]] = LBB["Lady Deathwhisper"],
                [L["Darnavan"]] = LBB["Lady Deathwhisper"],
                -- Halion
                [LBB["Halion"]] = LBB["Halion"],
                [L["Living Inferno"]] = LBB["Halion"]
            }
        end
    end

    function mod:OnEnable()
        spellmod.metadata = {tooltip = spellmod_tooltip}
        playermod.metadata = {post_tooltip = player_tooltip, click1 = spellmod}
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

        Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {src_is_interesting = true, dst_is_not_interesting = true})
        Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
        Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
        Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
        Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})

        Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
        Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})

        Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
        Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
        Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
        Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})

        Skada:AddFeed(L["Damage: Personal DPS"], feed_personal_dps)
        Skada:AddFeed(L["Damage: Raid DPS"], feed_raid_dps)

        Skada:AddMode(self, L["Damage done"])
        Skada:AddMode(dpsmod, L["Damage done"])
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
        Skada:RemoveMode(dpsmod)
        Skada:RemoveFeed(L["Damage: Personal DPS"])
        Skada:RemoveFeed(L["Damage: Raid DPS"])
    end

    function mod:AddToTooltip(set, tooltip)
        tooltip:AddDoubleLine(L["Damage"], Skada:FormatNumber(set.damagedone), 1, 1, 1)
        tooltip:AddDoubleLine(L["DPS"], Skada:FormatNumber(getRaidDPS(set)), 1, 1, 1)
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
            player.damagedone = {amount = 0, overkil = 0, spells = {}, targets = {}}
        end
    end

    function mod:AddSetAttributes(set)
        set.damagedone = set.damagedone or 0
        set.overkill = set.overkill or 0
        instanceDiff, valkyrsTable = nil, nil
    end

    function mod:SetComplete(set)
        for _, player in _ipairs(set.players) do
            if player.damagedone.amount == 0 then
                player.damagedone.spells = nil
                player.damagedone.targets = nil
            end
        end
        instanceDiff, valkyrsTable = nil, nil
    end
end)

-- =========================== --
-- Damage done by spell Module --
-- =========================== --

Skada:AddLoadableModule("Damage done by spell", function(Skada, L)
    if Skada:IsDisabled("Damage", "Damage done by spell") then return end

    local mod = Skada:NewModule(L["Damage done by spell"])
    local sourcemod = mod:NewModule(L["Damage spell sources"])

    local cached = {}

    function sourcemod:Enter(win, id, label)
        win.spellname = label
        win.title = _format(L["%s's sources"], label)
    end

    function sourcemod:Update(win, set)
        local max = 0

        if win.spellname and cached[win.spellname] then
            win.title = _format(L["%s's sources"], win.spellname)

            local nr = 1
            local total = math_max(1, cached[win.spellname].amount)

            for playername, player in _pairs(cached[win.spellname].players) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = playername
                d.class = player.class
                d.role = player.role
                d.spec = player.spec

                d.value = player.amount
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(player.amount),
                    mod.metadata.columns.Damage,
                    _format("%02.1f%%", 100 * player.amount / math_max(1, total)),
                    mod.metadata.columns.Percent
                )

                if player.amount > max then
                    max = player.amount
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
    end

    -- for performance purposes, we ignore total segment
    function mod:Update(win, set)
        local max = 0

        if set ~= Skada.total then
            local nr = 1

            cached = {}
            for i, player in _ipairs(set.players) do
                if player.damagedone.amount > 0 then
                    for spellname, spell in _pairs(player.damagedone.spells) do
                        if spell.amount > 0 then
                            if not cached[spellname] then
                                cached[spellname] = {
                                    id = spell.id,
                                    school = spell.school,
                                    amount = spell.amount,
                                    players = {}
                                }
                            else
                                cached[spellname].amount = cached[spellname].amount + spell.amount
                            end

                            -- add the players
                            if not cached[spellname].players[player.name] then
                                cached[spellname].players[player.name] = {
                                    id = player.id,
                                    class = player.class,
                                    spec = player.spec,
                                    role = player.role,
                                    amount = spell.amount
                                }
                            else
                                cached[spellname].players[player.name].amount =
                                    cached[spellname].players[player.name].amount + spell.amount
                            end
                        end
                    end
                end
            end

            for spellname, spell in _pairs(cached) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = spellname
                d.spellid = spell.id
                d.spellname = spellname
                d.spellschool = spell.school
                d.label = spellname
                d.icon = _select(3, _GetSpellInfo(spell.id))

                d.value = spell.amount
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(spell.amount),
                    self.metadata.columns.Damage,
                    _format("%02.1f%%", 100 * spell.amount / math_max(1, set.damagedone or 0)),
                    self.metadata.columns.Percent
                )

                if spell.amount > max then
                    max = spell.amount
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Damage done by spell"]
    end

    function mod:OnEnable()
        sourcemod.metadata = {showspots = true}
        mod.metadata = {
            showspots = true,
            click1 = sourcemod,
            columns = {Damage = true, Percent = true}
        }
        Skada:AddMode(self, L["Damage done"])
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
    end
end)

-- ================== --
-- Useful Damage Module --
-- ================== --
--
-- this module uses the data from Damage module and
-- show the "effective" damage and dps by substructing
-- the overkill from the amount of damage done.
--

Skada:AddLoadableModule("Useful damage", function(Skada, L)
    if Skada:IsDisabled("Damage", "Useful damage") then return end

    local mod = Skada:NewModule(L["Useful damage"])

    local function getDPS(set, player)
        local uptime = math_min(Skada:GetSetTime(set), Skada:PlayerActiveTime(set, player))
        local amount = player.damagedone.amount - (player.overkill or 0)
        return amount / math_max(1, uptime)
    end

    local function getRaidDPS(set)
        local amount = set.damagedone - (set.overkill or 0)
        if set.time > 0 then
            return amount / math_max(1, set.time)
        else
            local endtime = set.endtime or time()
            return amount / math_max(1, endtime - set.starttime)
        end
    end

    function mod:Update(win, set)
        local max = 0

        if set and set.damagedone > 0 then
            local total = set.damagedone - (set.overkill or 0)
            local nr = 1

            for _, player in _ipairs(set.players) do
                if player.damagedone.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    local amount = player.damagedone.amount - (player.overkill or 0)
                    local dps = getDPS(set, player)

                    d.value = amount
                    d.valuetext = Skada:FormatValueText(
                        Skada:FormatNumber(amount),
                        self.metadata.columns.Damage,
                        Skada:FormatNumber(dps),
                        self.metadata.columns.DPS,
                        _format("%02.1f%%", 100 * amount / math_max(1, total)),
                        self.metadata.columns.Percent
                    )

                    if amount > max then
                        max = amount
                    end

                    nr = nr + 1
                end
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Useful damage"]
    end

    function mod:OnEnable()
        mod.metadata = {showspots = true, columns = {Damage = true, DPS = true, Percent = true}}
        Skada:AddMode(self, L["Damage done"])
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
    end

    function mod:GetSetSummary(set)
        return Skada:FormatValueText(
            Skada:FormatNumber(set.damagedone - (set.overkill or 6)),
            self.metadata.columns.Damage,
            Skada:FormatNumber(getRaidDPS(set)),
            self.metadata.columns.DPS
        )
    end
end)