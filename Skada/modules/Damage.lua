local Skada = Skada
if not Skada then
    return
end

local _UnitGUID = UnitGUID
local _GetSpellInfo = GetSpellInfo
local _format, math_max = string.format, math.max
local _pairs, _ipairs, _select = pairs, ipairs, select

-- list of miss types
local misstypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}

-- ================== --
-- Damage Done Module --
-- ================== --

Skada:AddLoadableModule(
    "Damage",
    function(Skada, L)
        if Skada:IsDisabled("Damage") then
            return
        end

        local mod = Skada:NewModule(L["Damage"])
        local playermod = mod:NewModule(L["Damage spell list"])
        local targetmod = mod:NewModule(L["Damage target list"])
        local spellmod = mod:NewModule(L["Damage spell details"])

        local dpsmod = Skada:NewModule(L["DPS"])

        local LBB = LibStub("LibBabble-Boss-3.0"):GetLookupTable()

        --
        -- hold the name of targets used to record useful damage
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
                    local amount =
                        (validTarget[dmg.dstName] == LBB["Blood Prince Council"]) and dmg.overkill or dmg.amount
                    player.damagedone.targets[altname] = (player.damagedone.targets[altname] or 0) + amount
                end
            end
        end

        local dmg = {}

        local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if srcGUID ~= dstGUID then
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
            SpellDamage(
                timestamp,
                eventtype,
                srcGUID,
                srcName,
                srcFlags,
                dstGUID,
                dstName,
                dstFlags,
                6603,
                MELEE,
                1,
                ...
            )
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
            SpellMissed(
                timestamp,
                eventtype,
                srcGUID,
                srcName,
                srcFlags,
                dstGUID,
                dstName,
                dstFlags,
                6603,
                MELEE,
                1,
                ...
            )
        end

        local function getDPS(set, player)
            local uptime = Skada:PlayerActiveTime(set, player)
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
                local activetime = Skada:PlayerActiveTime(set, player)
                local totaltime = Skada:GetSetTime(set)
                tooltip:AddDoubleLine(
                    L["Activity"],
                    _format("%02.1f%%", 100 * activetime / totaltime),
                    255,
                    255,
                    255,
                    255,
                    255,
                    255
                )
                tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 255, 255, 255, 255, 255, 255)
                tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 255, 255, 255, 255, 255, 255)
            end
        end

        local function dps_tooltip(win, id, label, tooltip)
            local set = win:get_selected_set()
            local player = Skada:find_player(set, id)
            if player then
                local activetime = Skada:PlayerActiveTime(set, player)
                local totaltime = Skada:GetSetTime(set)
                tooltip:AddLine(player.name .. " - " .. L["DPS"])
                tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(totaltime), 255, 255, 255, 255, 255, 255)
                tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(activetime), 255, 255, 255, 255, 255, 255)
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
                    Skada:FormatNumber(player.damagedone.amount / math_max(1, activetime)),
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

            local spell = player.damagedone.spells[spellmod.spellname]
            if spell and label then
                tooltip:AddLine(player.name .. " - " .. spellmod.spellname)

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
            self.title = _format(L["%s's damage"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
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
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", spell.amount / player.damagedone.amount * 100),
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
            self.title = _format(L["%s's targets"], label)
        end

        function targetmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for mobname, amount in _pairs(player.damagedone.targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = mobname
                    d.label = mobname

                    d.value = amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", amount / player.damagedone.amount * 100),
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
                _format("%02.1f%%", value / win.metadata.maxvalue * 100),
                mod.metadata.columns.Percent
            )
        end

        function spellmod:Enter(win, id, label)
            self.spellid = id
            self.spellname = label
            self.title = _format(L["%s's <%s> damage"], playermod.playername, label)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, playermod.playerid)

            if player and player.damagedone.spells then
                local spell = player.damagedone.spells[self.spellname]

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
                    for i, misstype in _ipairs(misstypes) do
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
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.damagedone.amount),
                        self.metadata.columns.Damage,
                        Skada:FormatNumber(dps),
                        self.metadata.columns.DPS,
                        _format("%02.1f%%", player.damagedone.amount / set.damagedone * 100),
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
                    d.valuetext = Skada:FormatNumber(dps)

                    if dps > max then
                        max = dps
                    end
                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        --
        -- we make sure to fill our groupName and validTarget tables
        -- used to record damage on useful targets
        --
        function mod:OnInitialize()
            --
            -- we make sure to add our missing entries to LibBabble-Boss
            --
            LBB["Cult Adherent"] = L["Cult Adherent"]
            LBB["Cult Fanatic"] = L["Cult Fanatic"]
            LBB["Deformed Fanatic"] = L["Deformed Fanatic"]
            LBB["Empowered Adherent"] = L["Empowered Adherent"]
            LBB["Gas Cloud"] = L["Gas Cloud"]
            LBB["Reanimated Adherent"] = L["Reanimated Adherent"]
            LBB["Reanimated Fanatic"] = L["Reanimated Fanatic"]
            LBB["Volatile Ooze"] = L["Volatile Ooze"]
            LBB["Wicked Spirit"] = L["Wicked Spirit"]
            LBB["Darnavan"] = L["Darnavan"]
            LBB["Living Inferno"] = L["Living Inferno"]

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
                    [LBB["Raging Spirit"]] = LBB["The Lich King"],
                    [LBB["Ice Sphere"]] = LBB["The Lich King"],
                    [LBB["Val'kyr Shadowguard"]] = LBB["The Lich King"],
                    [LBB["Wicked Spirit"]] = LBB["The Lich King"],
                    -- Professor Putricide
                    [LBB["Gas Cloud"]] = LBB["Professor Putricide"],
                    [LBB["Volatile Ooze"]] = LBB["Professor Putricide"],
                    -- Blood Prince Council
                    [LBB["Prince Valanar"]] = LBB["Blood Prince Council"],
                    [LBB["Prince Taldaram"]] = LBB["Blood Prince Council"],
                    [LBB["Prince Keleseth"]] = LBB["Blood Prince Council"],
                    -- Lady Deathwhisper
                    [LBB["Cult Adherent"]] = LBB["Lady Deathwhisper"],
                    [LBB["Empowered Adherent"]] = LBB["Lady Deathwhisper"],
                    [LBB["Reanimated Adherent"]] = LBB["Lady Deathwhisper"],
                    [LBB["Cult Fanatic"]] = LBB["Lady Deathwhisper"],
                    [LBB["Deformed Fanatic"]] = LBB["Lady Deathwhisper"],
                    [LBB["Reanimated Fanatic"]] = LBB["Lady Deathwhisper"],
                    [LBB["Darnavan"]] = LBB["Lady Deathwhisper"],
                    -- Halion
                    [LBB["Halion"]] = LBB["Halion"],
                    [LBB["Living Inferno"]] = LBB["Halion"]
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
                click2 = targetmod
            }

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
            Skada:AddMode(dpsmod, L["Damage"])
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
    end
)

-- =========================== --
-- Damage done by spell Module --
-- =========================== --
Skada:AddLoadableModule(
    "Damage done by spell",
    function(Skada, L)
        if Skada:IsDisabled("Damage", "Damage done by spell") then
            return
        end

        local mod = Skada:NewModule(L["Damage done by spell"])
        local sourcemod = mod:NewModule(L["Damage spell sources"])

        local cached = {}

        function sourcemod:Enter(win, id, label)
            self.spellname = label
            self.title = _format(L["%s's sources"], label)
        end

        function sourcemod:Update(win, set)
            local max = 0

            if self.spellname and cached[self.spellname] then
                local nr = 1

                local total = math_max(1, cached[self.spellname].amount)

                for playername, player in _pairs(cached[self.spellname].players) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = playername
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * player.amount / total),
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
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        self.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * spell.amount / set.damagedone),
                        self.metadata.columns.Percent
                    )

                    if spell.amount > max then
                        max = spell.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            sourcemod.metadata = {showspots = true}
            mod.metadata = {
                showspots = true,
                click1 = sourcemod,
                columns = {Damage = true, Percent = true}
            }
            Skada:AddMode(self, L["Damage"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end
    end
)

-- ================== --
-- Useful Damage Module --
-- ================== --
--
-- this module uses the data from Damage module and
-- show the "effective" damage and dps by substructing
-- the overkill from the amount of damage done.
--

Skada:AddLoadableModule(
    "Useful damage",
    function(Skada, L)
        if Skada:IsDisabled("Damage", "Useful damage") then
            return
        end

        local mod = Skada:NewModule(L["Useful damage"])

        local function getDPS(set, player)
            local uptime = Skada:PlayerActiveTime(set, player)
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
                        d.valuetext =
                            Skada:FormatValueText(
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
        end

        function mod:OnEnable()
            mod.metadata = {showspots = true, columns = {Damage = true, DPS = true, Percent = true}}
            Skada:AddMode(self, L["Damage"])
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
    end
)

-- =================== --
-- Damage Taken Module --
-- =================== --

Skada:AddLoadableModule(
    "Damage taken",
    function(Skada, L)
        if Skada:IsDisabled("Damage taken") then
            return
        end

        local mod = Skada:NewModule(L["Damage taken"])
        local playermod = mod:NewModule(L["Damage spell list"])
        local spellmod = mod:NewModule(L["Damage spell details"])
        local sourcemod = mod:NewModule(L["Damage source list"])

        local function log_damage(set, dmg)
            local player = Skada:get_player(set, dmg.playerid, dmg.playername, dmg.playerflags)
            if not player then
                return
            end

            player.damagetaken.amount = player.damagetaken.amount + dmg.amount
            set.damagetaken = set.damagetaken + dmg.amount

            -- add the spell
            local spellname = dmg.spellname
            if spellname == MELEE then
                spellname = spellname .. " (" .. (dmg.srcName or UNKNOWN) .. ")"
            end

            local spell =
                player.damagetaken.spells[spellname] or
                {id = dmg.spellid, school = dmg.spellschool, source = dmg.srcName, amount = 0}
            player.damagetaken.spells[spellname] = spell
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

            if dmg.absorbed then
                spell.absorbed = (spell.absorbed or 0) + dmg.absorbed
            end

            if dmg.blocked then
                spell.blocked = (spell.blocked or 0) + dmg.blocked
            end

            if dmg.resisted then
                spell.resisted = (spell.resisted or 0) + dmg.resisted
            end

            if set == Skada.current and dmg.srcName and dmg.amount > 0 then
                player.damagetaken.sources[dmg.srcName] = (player.damagetaken.sources[dmg.srcName] or 0) + dmg.amount
            end
        end

        local dmg = {}

        local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
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

            dmg.srcName = srcName
            dmg.playerid = dstGUID
            dmg.playername = dstName
            dmg.spellid = spellid
            dmg.spellname = spellname
            dmg.spellschool = school

            dmg.amount = amount
            dmg.resisted = resisted
            dmg.blocked = blocked
            dmg.absorbed = absorbed
            dmg.critical = critical
            dmg.glancing = glancing
            dmg.crushing = crushing
            dmg.missed = nil

            log_damage(Skada.current, dmg)
            log_damage(Skada.total, dmg)
        end

        local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            SpellDamage(
                timestamp,
                eventtype,
                srcGUID,
                srcName,
                srcFlags,
                dstGUID,
                dstName,
                dstFlags,
                6603,
                MELEE,
                1,
                ...
            )
        end

        local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            local spellid, spellname, spellschool, misstype, amount = ...

            dmg.srcGUID = srcGUID
            dmg.srcName = srcName

            dmg.playerid = dstGUID
            dmg.playername = dstName

            dmg.spellid = spellid
            dmg.spellname = spellname
            dmg.spellschool = spellschool

            dmg.amount = 0
            dmg.overkill = 0
            dmg.missed = misstype

            log_damage(Skada.current, dmg)
            log_damage(Skada.total, dmg)
        end

        local function SwingMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            local misstype = _select(1, ...)
            SpellMissed(
                timestamp,
                eventtype,
                srcGUID,
                srcName,
                srcFlags,
                dstGUID,
                dstName,
                dstFlags,
                6603,
                MELEE,
                1,
                misstype
            )
        end

        local function getDTPS(set, player)
            local uptime = Skada:PlayerActiveTime(set, player)
            return player.damagetaken.amount / math_max(1, uptime)
        end

        local function getRaidDTPS(set)
            if set.time > 0 then
                return set.damagetaken / math_max(1, set.time)
            else
                local endtime = set.endtime or time()
                return set.damagetaken / math_max(1, endtime - set.starttime)
            end
        end

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["Damage taken by %s"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player and player.damagetaken.amount > 0 then
                local nr = 1

                for spellname, spell in _pairs(player.damagetaken.spells) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = spellname
                    d.spellid = spell.id
                    d.spellschool = spell.school
                    d.label = spellname
                    d.icon = _select(3, _GetSpellInfo(spell.id))

                    d.value = spell.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", spell.amount / player.damagetaken.amount * 100),
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
            self.title = _format(L["%s's damage sources"], label)
        end

        function sourcemod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for mobname, amount in _pairs(player.damagetaken.sources) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = mobname
                    d.label = mobname

                    d.value = amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", amount / player.damagetaken.amount * 100),
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
                    _format("%02.1f%%", value / win.metadata.maxvalue * 100),
                    mod.metadata.columns.Percent
                )
            end
        end

        function spellmod:Enter(win, id, label)
            self.spellname = label
            self.title = _format(L["<%s> damage on %s"], label, playermod.playername)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, playermod.playerid)

            if player and player.damagetaken.spells then
                local spell = player.damagetaken.spells[self.spellname]

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

                    for i, misstype in _ipairs(misstypes) do
                        if spell[misstype] and spell[misstype] > 0 then
                            local title = _G[misstype] or _G["ACTION_SPELL_MISSED" .. misstype] or misstype
                            nr = nr + 1
                            add_detail_bar(win, nr, title, spell[misstype])
                        end
                    end
                end
            end
        end

        function mod:Update(win, set)
            local nr, max = 1, 0

            for i, player in _ipairs(set.players) do
                if player.damagetaken.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    local totaltime = Skada:PlayerActiveTime(set, player)

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.damagetaken.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.damagetaken.amount),
                        self.metadata.columns.Damage,
                        Skada:FormatNumber(getDTPS(set, player)),
                        self.metadata.columns.DTPS,
                        _format("%02.1f%%", player.damagetaken.amount / set.damagetaken * 100),
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

        local function playerspell_tooltip(win, id, label, tooltip)
            local player = Skada:find_player(win:get_selected_set(), playermod.playerid)
            if not player then
                return
            end

            local spell = player.damagetaken.spells[label]
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
            playermod.metadata = {post_tooltip = playerspell_tooltip, click1 = spellmod}
            sourcemod.metadata = {}
            mod.metadata = {
                showspots = true,
                click1 = playermod,
                click2 = sourcemod,
                columns = {Damage = true, DTPS = true, Percent = true}
            }

            Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true})

            Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {dst_is_interesting_nopets = true})
            Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {dst_is_interesting_nopets = true})

            Skada:AddMode(self, L["Damage"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddToTooltip(set, tooltip)
            tooltip:AddDoubleLine(L["Damage taken"], Skada:FormatNumber(set.damagetaken), 1, 1, 1)
            tooltip:AddDoubleLine(L["DTPS"], Skada:FormatNumber(getRaidDTPS(set)), 1, 1, 1)
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
            for i, player in _ipairs(set.players) do
                if player.damagetaken.amount == 0 then
                    player.damagetaken.spells = nil
                    player.damagetaken.sources = nil
                end

                -- remove this entry anyways
                if set == Skada.total then
                    player.damagetaken.sources = nil
                end
            end
        end
    end
)

-- ============================ --
-- Damage taken by spell Module --
-- ============================ --
Skada:AddLoadableModule(
    "Damage taken by spell",
    function(Skada, L)
        if Skada:IsDisabled("Damage taken", "Damage taken by spell") then
            return
        end

        local mod = Skada:NewModule(L["Damage taken by spell"])
        local targetmod = mod:NewModule(L["Damage spell targets"])

        local cached = {}

        function targetmod:Enter(win, id, label)
            self.spellname = label
            self.title = _format(L["%s's targets"], label)
        end

        function targetmod:Update(win, set)
            local max = 0

            if set ~= Skada.total and self.spellname and cached[self.spellname] then
                local nr = 1

                local total = math_max(1, cached[self.spellname].amount)

                for playername, player in _pairs(cached[self.spellname].players) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = playername
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * player.amount / total),
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
                    if player.damagetaken.amount > 0 then
                        for spellname, spell in _pairs(player.damagetaken.spells) do
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
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        self.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * spell.amount / set.damagetaken),
                        self.metadata.columns.Percent
                    )

                    if spell.amount > max then
                        max = spell.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            targetmod.metadata = {showspots = true}
            mod.metadata = {
                showspots = true,
                click1 = targetmod,
                columns = {Damage = true, Percent = true}
            }
            Skada:AddMode(self, L["Damage"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end
    end
)

-- ============================= --
-- Avoidance & Mitigation Module --
-- ============================= --

Skada:AddLoadableModule(
    "Avoidance & Mitigation",
    function(Skada, L)
        if Skada:IsDisabled("Damage taken", "Avoidance & Mitigation") then
            return
        end

        local mod = Skada:NewModule(L["Avoidance & Mitigation"])
        local playermod = mod:NewModule(L["Damage breakdown"])

        local temp = {}

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.title = _format(L["%s's damage breakdown"], label)
        end

        function playermod:Update(win, set)
            local max = 0

            if temp[self.playerid] then
                local nr = 1
                local p = temp[self.playerid]

                for event, count in _pairs(p.data) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = event
                    d.label = _G[event] or event

                    d.value = count / p.total * 100
                    d.valuetext =
                        Skada:FormatValueText(
                        _format("%02.1f%%", d.value),
                        mod.metadata.columns.Percent,
                        _format("%d/%d", count, p.total),
                        mod.metadata.columns.Total
                    )

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

            for i, player in _ipairs(set.players) do
                if player.damagetaken.amount > 0 then
                    temp[player.id] = {data = {}}

                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    local total, avoid = 0, 0
                    for spellname, spell in _pairs(player.damagetaken.spells) do
                        total = total + spell.totalhits

                        for _, t in _ipairs(misstypes) do
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
                    d.valuetext =
                        Skada:FormatValueText(
                        _format("%02.1f%%", d.value),
                        self.metadata.columns.Percent,
                        _format("%d/%d", avoid, total),
                        self.metadata.columns.Total
                    )

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
            mod.metadata = {showspots = true, click1 = playermod, columns = {Percent = true, Total = true}}

            Skada:AddMode(self, L["Damage"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end
    end
)

-- ======================== --
-- Enemy damage taken module --
-- ======================== --

Skada:AddLoadableModule(
    "Enemy damage taken",
    function(Skada, L)
        if Skada:IsDisabled("Damage", "Enemy damage taken") then
            return
        end

        local mod = Skada:NewModule(L["Enemy damage taken"])
        local playermod = mod:NewModule(L["Damage taken per player"])

        local _ipairs, _pairs, _format = ipairs, pairs, string.format

        local cached = {}

        function playermod:Enter(win, id, label)
            self.mobname = label
            self.title = _format(L["Damage on %s"], label)
        end

        function playermod:Update(win, set)
            local max = 0

            if self.mobname and cached[self.mobname] then
                local total = cached[self.mobname].amount
                local nr = 1

                for playername, player in _pairs(cached[self.mobname].players) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id or playername
                    d.label = playername
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * player.amount / total),
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

        function mod:Update(win, set)
            if set.damagedone > 0 then
                cached = {}

                for _, player in _ipairs(set.players) do
                    if player.damagedone.amount > 0 then
                        for targetname, amount in _pairs(player.damagedone.targets) do
                            -- add damage amount to target, but before, we create it if it doesn't exist
                            cached[targetname] = cached[targetname] or {amount = 0, players = {}}
                            cached[targetname].amount = cached[targetname].amount + amount

                            -- add the player to the list and add his/her damage
                            if not cached[targetname].players[player.name] then
                                cached[targetname].players[player.name] = {
                                    id = player.id,
                                    class = player.class,
                                    role = player.role,
                                    spec = player.spec,
                                    amount = 0
                                }
                            end
                            cached[targetname].players[player.name].amount =
                                cached[targetname].players[player.name].amount + amount
                        end
                    end
                end
            end

            local max = 0

            if cached then
                local nr = 1

                for targetname, target in _pairs(cached) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = targetname
                    d.label = targetname
                    d.value = target.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(target.amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * target.amount / set.damagedone),
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

        function mod:OnEnable()
            playermod.metadata = {showspots = true}
            mod.metadata = {click1 = playermod, columns = {Damage = true, Percent = true}}

            Skada:AddMode(self, L["Damage"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddSetAttributes(set)
            cached = {}
        end

        function mod:GetSetSummary(set)
            return Skada:FormatNumber(set.damagedone or 0)
        end
    end
)

-- ========================= --
-- Enemy damage done module --
-- ========================= --

Skada:AddLoadableModule(
    "Enemy damage done",
    function(Skada, L)
        if Skada:IsDisabled("Damage taken", "Enemy damage done") then
            return
        end

        local mod = Skada:NewModule(L["Enemy damage done"])
        local sourcemod = mod:NewModule(L["Damage done per player"])
        local playermod = mod:NewModule(L["Damage spell list"])
        local spellmod = mod:NewModule(L["Damage spell details"])

        local _ipairs, _pairs, _format = ipairs, pairs, string.format

        local cached

        local function spellmod_tooltip(win, id, label, tooltip)
            local player = Skada:find_player(win:get_selected_set(), playermod.playerid)
            if not player then
                return
            end

            local spell = player.damagetaken.spells[spellmod.spellname]

            if spell then
                tooltip:AddLine(player.name .. " - " .. spellmod.spellname)

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
                _format("%02.1f%%", value / win.metadata.maxvalue * 100),
                mod.metadata.columns.Percent
            )
        end

        function spellmod:Enter(win, id, label)
            self.spellname = label
            self.title = _format(L["%s's damage on %s"], label, playermod.playername)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, playermod.playerid)

            if player then
                local nr = 1

                for spellname, spell in _pairs(player.damagetaken.spells) do
                    if spellname == self.spellname then
                        win.metadata.maxvalue = spell.totalhits

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

                        for i, misstype in _ipairs(misstypes) do
                            if spell[misstype] and spell[misstype] > 0 then
                                local title = _G[misstype] or _G["ACTION_SPELL_MISSED" .. misstype] or misstype
                                add_detail_bar(win, nr, title, spell[misstype])
                                nr = nr + 1
                            end
                        end
                    end
                end
            end
        end

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["%s's damage on %s"], sourcemod.mobname, label)
        end

        function playermod:Update(win, set)
            local max = 0

            if cached[sourcemod.mobname] and cached[sourcemod.mobname].targets[self.playerid] then
                local player = Skada:find_player(set, self.playerid)
                if player then
                    local nr = 1
                    local total = cached[sourcemod.mobname].targets[self.playerid]

                    for spellname, spell in _pairs(player.damagetaken.spells) do
                        if spell.source == sourcemod.mobname or spellname:find(sourcemod.mobname) then
                            local d = win.dataset[nr] or {}
                            win.dataset[nr] = d

                            d.id = spellname
                            d.spellid = spell.id
                            d.label = spellname
                            d.icon = _select(3, _GetSpellInfo(spell.id))

                            d.value = spell.amount
                            d.valuetext =
                                Skada:FormatValueText(
                                Skada:FormatNumber(spell.amount),
                                mod.metadata.columns.Damage,
                                _format("%02.1f%%", 100 * spell.amount / total),
                                mod.metadata.columns.Percent
                            )

                            if spell.amount > max then
                                max = spell.amount
                            end

                            nr = nr + 1
                        end
                    end
                end
            end

            win.metadata.maxvalue = max
        end

        function sourcemod:Enter(win, id, label)
            self.mobname = label
            self.title = _format(L["Damage from %s"], label)
        end

        function sourcemod:Update(win, set)
            local max = 0

            if self.mobname and cached[self.mobname] then
                local mob = cached[self.mobname]
                local nr = 1

                for playerid, amount in _pairs(mob.targets) do
                    local player = Skada:find_player(set, playerid)
                    if player then
                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = playerid
                        d.label = player.name
                        d.class = player.class
                        d.role = player.role
                        d.spec = player.spec

                        d.value = amount
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(amount),
                            mod.metadata.columns.Damage,
                            _format("%02.1f%%", 100 * amount / mob.amount),
                            mod.metadata.columns.Percent
                        )

                        if amount > max then
                            max = amount
                        end

                        nr = nr + 1
                    end
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:Update(win, set)
            if set.damagetaken > 0 then
                cached = {}

                for _, player in _ipairs(set.players) do
                    if player.damagetaken.amount > 0 then
                        for sourcename, amount in _pairs(player.damagetaken.sources) do
                            -- add the mob
                            local source = cached[sourcename] or {amount = 0, targets = {}}
                            cached[sourcename] = source
                            source.amount = source.amount + amount

                            -- add the player
                            if not source.targets[player.id] then
                                source.targets[player.id] = amount
                            else
                                source.targets[player.id] = source.targets[player.id] + amount
                            end
                        end
                    end
                end
            end

            local max = 0

            if cached then
                local nr = 1

                for sourcename, source in _pairs(cached) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = sourcename
                    d.label = sourcename
                    d.value = source.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(source.amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * source.amount / set.damagetaken),
                        mod.metadata.columns.Percent
                    )

                    if source.amount > max then
                        max = source.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            spellmod.metadata = {tooltip = spellmod_tooltip}
            playermod.metadata = {showspots = true, click1 = spellmod}
            sourcemod.metadata = {showspots = true, click1 = playermod}
            mod.metadata = {click1 = sourcemod, columns = {Damage = true, Percent = true}}

            Skada:AddMode(self, L["Damage"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddSetAttributes(set)
            cached = {}
        end

        function mod:GetSetSummary(set)
            return Skada:FormatNumber(set.damagetaken or 0)
        end
    end
)

-- ==================== --
-- Friendly Fire module --
-- ==================== --

Skada:AddLoadableModule(
    "Friendly Fire",
    function(Skada, L)
        if Skada:IsDisabled("Friendly Fire") then
            return
        end

        local mod = Skada:NewModule(L["Friendly Fire"])
        local spellmod = mod:NewModule(L["Damage spell list"])
        local targetmod = mod:NewModule(L["Damage target list"])

        local _pairs, _ipairs = pairs, ipairs
        local _format, math_max = string.format, math.max
        local _GetSpellInfo = GetSpellInfo

        local function log_damage(set, dmg)
            local player = Skada:get_player(set, dmg.playerid, dmg.playername, dmg.playerflags)
            if not player then
                return
            end

            set.friendfire = set.friendfire + dmg.amount
            player.friendfire.amount = player.friendfire.amount + dmg.amount

            -- record spell damage
            if not player.friendfire.spells[dmg.spellid] then
                player.friendfire.spells[dmg.spellid] = {school = dmg.spellschool, amount = dmg.amount}
            else
                player.friendfire.spells[dmg.spellid].amount = player.friendfire.spells[dmg.spellid].amount + dmg.amount
            end

            -- add target to current set only
            if set == Skada.current then
                if not player.friendfire.targets[dmg.dstName] then
                    player.friendfire.targets[dmg.dstName] = {id = dmg.dstGUID, amount = dmg.amount}
                else
                    player.friendfire.targets[dmg.dstName].amount =
                        player.friendfire.targets[dmg.dstName].amount + dmg.amount
                end
            end
        end

        local dmg = {}

        local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if srcGUID ~= dstGUID then
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
                dmg.playerid = srcGUID
                dmg.playername = srcName
                dmg.playerflags = srcFlags
                dmg.dstGUID = dstGUID
                dmg.dstName = dstName
                dmg.dstFlags = dstFlags
                dmg.spellid = spellid
                dmg.spellschool = school
                dmg.amount = (amount or 0) + (overkill or 0) + (absorbed or 0)

                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if srcGUID ~= dstGUID then
                local amount, overkill, school, resisted, blocked, absorbed = ...
                dmg.playerid = srcGUID
                dmg.playername = srcName
                dmg.playerflags = srcFlags
                dmg.dstGUID = dstGUID
                dmg.dstName = dstName
                dmg.dstFlags = dstFlags
                dmg.spellid = 6603
                dmg.spellschool = 1
                dmg.amount = (amount or 0) + (overkill or 0) + (absorbed or 0)

                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        function targetmod:Enter(win, id, label)
            self.playerid = id
            self.title = _format(L["%s's targets"], label)
        end

        function targetmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player and player.friendfire.targets then
                local nr = 1

                for targetname, target in _pairs(player.friendfire.targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname

                    -- get other data
                    local data = Skada:find_player(set, target.id, targetname)
                    if data then
                        d.class = data.class
                        d.role = data.role
                        d.spec = data.spec
                    else
                        d.class = "UNKNOWN"
                        d.role = "NONE"
                    end

                    d.value = target.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(target.amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", target.amount / set.friendfire * 100),
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
            self.title = _format(L["%s's damage"], label)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for spellid, spell in _pairs(player.friendfire.spells) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    local spellname, _, spellicon = _GetSpellInfo(spellid)

                    d.id = spellid
                    d.spellid = spellid
                    d.label = spellname
                    d.icon = spellicon

                    d.value = spell.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * spell.amount / set.friendfire),
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

        function mod:Update(win, set)
            local nr, max = 1, 0

            for i, player in _pairs(set.players) do
                if player.friendfire.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.friendfire.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.friendfire.amount),
                        self.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * player.friendfire.amount / set.friendfire),
                        self.metadata.columns.Percent
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
            targetmod.metadata = {showspots = true}
            mod.metadata = {
                showspots = true,
                click1 = spellmod,
                click2 = targetmod,
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
            return Skada:FormatNumber(set.friendfire)
        end

        function mod:SetComplete(set)
            for i, player in _ipairs(set.players) do
                if player.friendfire.amount == 0 then
                    player.friendfire.spells = nil
                    player.friendfire.targets = nil
                end
            end
        end
    end
)