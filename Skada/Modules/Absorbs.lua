assert(Skada, "Skada not found!")

-- cache frequently used globals
local _pairs, _ipairs, _select = pairs, ipairs, select
local _format, math_max, math_min = string.format, math.max, math.min
local _GetSpellInfo = Skada.GetSpellInfo
local _UnitGUID = UnitGUID

-- ============== --
-- Absorbs module --
-- ============== --

Skada:AddLoadableModule("Absorbs", function(Skada, L)
    if Skada:IsDisabled("Absorbs") then return end

    local mod = Skada:NewModule(L["Absorbs"])
    local spellmod = mod:NewModule(L["Absorb spell list"])
    local playermod = mod:NewModule(L["Absorbed player list"])

    local _GetNumRaidMembers, _GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
    local _UnitName, _UnitExists, _UnitIsDeadOrGhost = UnitName, UnitExists, UnitIsDeadOrGhost
    local _tostring, _GetTime, _band = tostring, GetTime, bit.band

    local absorbspells = {
        [48707] = 5,
        [51052] = 10,
        [51271] = 20,
        [62606] = 10,
        [11426] = 60,
        [13031] = 60,
        [13032] = 60,
        [13033] = 60,
        [27134] = 60,
        [33405] = 60,
        [43038] = 60,
        [43039] = 60,
        [6143] = 30,
        [8461] = 30,
        [8462] = 30,
        [10177] = 30,
        [28609] = 30,
        [32796] = 30,
        [43012] = 30,
        [1463] = 60,
        [8494] = 60,
        [8495] = 60,
        [10191] = 60,
        [10192] = 60,
        [10193] = 60,
        [27131] = 60,
        [43019] = 60,
        [43020] = 60,
        [543] = 30,
        [8457] = 30,
        [8458] = 30,
        [10223] = 30,
        [10225] = 30,
        [27128] = 30,
        [43010] = 30,
        [58597] = 6,
        [17] = 30,
        [592] = 30,
        [600] = 30,
        [3747] = 30,
        [6065] = 30,
        [6066] = 30,
        [10898] = 30,
        [10899] = 30,
        [10900] = 30,
        [10901] = 30,
        [25217] = 30,
        [25218] = 30,
        [48065] = 30,
        [48066] = 30,
        [47509] = 12,
        [47511] = 12,
        [47515] = 12,
        [47753] = 12,
        [54704] = 12,
        [47788] = 10,
        [7812] = 30,
        [19438] = 30,
        [19440] = 30,
        [19441] = 30,
        [19442] = 30,
        [19443] = 30,
        [27273] = 30,
        [47985] = 30,
        [47986] = 30,
        [6229] = 30,
        [11739] = 30,
        [11740] = 30,
        [28610] = 30,
        [47890] = 30,
        [47891] = 30,
        [29674] = 86400,
        [29719] = 86400,
        [29701] = 86400,
        [28538] = 120,
        [28537] = 120,
        [28536] = 120,
        [28513] = 120,
        [28512] = 120,
        [28511] = 120,
        [7233] = 120,
        [7239] = 120,
        [7242] = 120,
        [7245] = 120,
        [7254] = 120,
        [53915] = 120,
        [53914] = 120,
        [53913] = 120,
        [53911] = 120,
        [53910] = 120,
        [17548] = 120,
        [17546] = 120,
        [17545] = 120,
        [17544] = 120,
        [17543] = 120,
        [17549] = 120,
        [28527] = 15,
        [29432] = 3600,
        [36481] = 4,
        [57350] = 6,
        [17252] = 30,
        [25750] = 15,
        [25747] = 15,
        [25746] = 15,
        [23991] = 15,
        [31000] = 300,
        [30997] = 300,
        [31002] = 300,
        [30999] = 300,
        [30994] = 300,
        [23506] = 20,
        [12561] = 60,
        [31771] = 20,
        [21956] = 10,
        [29506] = 20,
        [4057] = 60,
        [4077] = 60,
        [39228] = 20,
        [27779] = 30,
        [11657] = 20,
        [10368] = 15,
        [37515] = 15,
        [42137] = 86400,
        [26467] = 30,
        [26470] = 8,
        [27539] = 6,
        [28810] = 30,
        [54808] = 12,
        [55019] = 12,
        -- [64411] = 15, -- it doesn't absorb by itself, it requires healing
        [64413] = 8,
        [40322] = 30,
        [65874] = 15,
        [67257] = 15,
        [67256] = 15,
        [67258] = 15,
        [65858] = 15,
        [67260] = 15,
        [67259] = 15,
        [67261] = 15,
        [65686] = 86400,
        [65684] = 86400
    }

    local mage_fire_ward = {
        [543] = 30, -- Fire Ward (Mage) Rank 1
        [8457] = 30,
        [8458] = 30,
        [10223] = 30,
        [10225] = 30,
        [27128] = 30,
        [43010] = 30 -- Rank 7
    }

    local mage_frost_ward = {
        [6143] = 30, -- Frost Ward (Mage) Rank 1
        [8461] = 30,
        [8462] = 30,
        [10177] = 30,
        [28609] = 30,
        [32796] = 30,
        [43012] = 30 -- Rank 7
    }

    local mage_ice_barrier = {
        [11426] = 60, -- Ice Barrier (Mage) Rank 1
        [13031] = 60,
        [13032] = 60,
        [13033] = 60,
        [27134] = 60,
        [33405] = 60,
        [43038] = 60,
        [43039] = 60 -- Rank 8
    }

    local warlock_shadow_ward = {
        [6229] = 30, -- Shadow Ward (warlock) Rank 1
        [11739] = 30,
        [11740] = 30,
        [28610] = 30,
        [47890] = 30,
        [47891] = 30 -- Rank 6
    }

    local warlock_sacrifice = {
        [7812] = 30, -- Sacrifice (warlock) Rank 1
        [19438] = 30,
        [19440] = 30,
        [19441] = 30,
        [19442] = 30,
        [19443] = 30,
        [27273] = 30,
        [47985] = 30,
        [47986] = 30 -- rank 9
    }

    local shieldschools = {}

    local function log_absorb(set, playername, dstGUID, dstName, spellid, amount)
        local player = Skada:get_player(set, _UnitGUID(playername), playername)
        if player then
            -- add absorbs amount
            player.absorbs = player.absorbs or {}
            player.absorbs.amount = (player.absorbs.amount or 0) + amount
            set.absorbs = (set.absorbs or 0) + amount

            -- record the target
            if dstName then
                player.absorbs.targets = player.absorbs.targets or {}
                if not player.absorbs.targets[dstName] then
                    player.absorbs.targets[dstName] = {id = dstGUID, amount = amount}
                else
                    player.absorbs.targets[dstName].amount = player.absorbs.targets[dstName].amount + amount
                end
            end

            -- record the spell
            if spellid then
                player.absorbs.spells = player.absorbs.spells or {}
                if not player.absorbs.spells[spellid] then
                    player.absorbs.spells[spellid] = {count = 0, amount = 0}
                end
                local spell = player.absorbs.spells[spellid]
                spell.school = spell.school or shieldschools[spellid]
                spell.amount = spell.amount + amount
                spell.count = spell.count + 1

                if (not spell.min or amount < spell.min) and amount > 0 then
                    spell.min = amount
                end
                if (not spell.max or amount > spell.max) and amount > 0 then
                    spell.max = amount
                end
            end
        end
    end

    local shields = {}

    local function AuraApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        local spellid, spellname, spellschool, auratype = ...
        if absorbspells[spellid] then
            shields[dstName] = shields[dstName] or {}
            shields[dstName][spellid] = shields[dstName][spellid] or {}
            shields[dstName][spellid][srcName] = timestamp + absorbspells[spellid]
            if spellschool and not shieldschools[spellid] then
                shieldschools[spellid] = spellschool
            end
        end
    end

    local function AuraRemoved(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        local spellid, spellname, spellschool, auratype = ...
        if absorbspells[spellid] then
            shields[dstName] = shields[dstName] or {}
            if shields[dstName] and shields[dstName][spellid] and shields[dstName][spellid][srcName] then
                shields[dstName][spellid][srcName] = timestamp + 0.1
            end
        end
    end

    function mod:CheckPreShields(event, timestamp)
        if event == "ENCOUNTER_START" and Skada.current and not Skada.current.stopped then
            local prefix, min, max = "raid", 1, _GetNumRaidMembers()
            if max == 0 then
                prefix, min, max = "party", 0, _GetNumPartyMembers()
            end

            local curtime = _GetTime()
            for n = min, max do
                local unit = (n == 0) and "player" or prefix .. _tostring(n)
                if _UnitExists(unit) and not _UnitIsDeadOrGhost(unit) then
                    local dstName = _select(1, _UnitName(unit))
                    for i = 1, 32 do
                        local spellname, _, _, _, _, _, expires, unitCaster, _, _, spellid = UnitAura(unit, i, nil, "BUFF")
                        if spellid and absorbspells[spellid] and unitCaster then
                            shields[dstName] = shields[dstName] or {}
                            shields[dstName][spellid] = shields[dstName][spellid] or {}
                            shields[dstName][spellid][_select(1, _UnitName(unitCaster))] = timestamp + expires - curtime
                        end
                    end
                end
            end
        end
    end

    local function process_absorb(timestamp, dstGUID, dstName, absorbed, spellschool)
        shields[dstName] = shields[dstName] or {}

        local found_sources, found_src, found_shield_id

        for shield_id, sources in pairs(shields[dstName]) do
            -- twin val'kyr light essence and we took fire damage?
            if shield_id == 65686 then
                --twin val'kyr dark essence and we took shadow damage?
                if _band(spellschool, 0x4) == spellschool then
                    return
                end
            elseif shield_id == 65684 then
                -- Frost Ward and we took frost damage?
                if _band(spellschool, 0x20) == spellschool then
                    return
                end
            elseif mage_frost_ward[shield_id] then
                -- Fire Ward and we took fire damage?
                if _band(spellschool, 0x10) == spellschool then
                    found_shield_id = shield_id
                    found_sources = sources
                    break
                end
            elseif mage_fire_ward[shield_id] then
                -- Shadow Ward and we took shadow damage?
                if _band(spellschool, 0x4) == spellschool then
                    found_shield_id = shield_id
                    found_sources = sources
                    break
                end
            elseif warlock_shadow_ward[shield_id] then
                if _band(spellschool, 0x20) == spellschool then
                    found_shield_id = shield_id
                    found_sources = sources
                    break
                end
            else
                local mintime
                for shield_src, ts in pairs(sources) do
                    local starttime = ts - timestamp
                    if starttime > 0 and (mintime == nil or starttime < mintime) then
                        found_src = shield_src
                        found_shield_id = shield_id
                        mintime = starttime
                    end
                end
            end
        end

        -- we didn't found any source byt we have a shield?
        if not found_src and found_sources then
            local mintime
            for shield_src, ts in pairs(found_sources) do
                local starttime = ts - timestamp
                if starttime > 0 and (mintime == nil or starttime < mintime) then
                    found_src = shield_src
                    mintime = starttime
                end
            end
        end

        if found_src and found_shield_id then
            log_absorb(Skada.current, found_src, dstGUID, dstName, found_shield_id, absorbed)
            log_absorb(Skada.total, found_src, dstGUID, dstName, found_shield_id, absorbed)
        end
    end

    local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        local spellid, spellname, spellschool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...
        if absorbed and absorbed > 0 and dstName and shields[dstName] and srcName then
            process_absorb(timestamp, dstGUID, dstName, absorbed, spellschool)
        end
    end

    local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        local spellid, spellname, spellschool, misstype, absorbed = ...
        if misstype == "ABSORB" and absorbed > 0 and dstName and shields[dstName] and srcName then
            process_absorb(timestamp, dstGUID, dstName, absorbed, spellschool)
        end
    end

    local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        local amount, overkill, spellschool, resisted, blocked, absorbed, critical, glancing, crushing = ...
        if absorbed and absorbed > 0 and dstName and shields[dstName] and srcName then
            process_absorb(timestamp, dstGUID, dstName, absorbed, spellschool)
        end
    end

    local function SwingMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, nil, nil, 1, ...)
    end

    local function spell_tooltip(win, id, label, tooltip)
        local player = Skada:find_player(win:get_selected_set(), win.playerid, win.playername)
        if player then
            local spell = player.absorbs.spells[id]
            if spell then
                tooltip:AddLine(player.name .. " - " .. label)
                if spell.school then
                    local c = Skada.schoolcolors[spell.school]
                    local n = Skada.schoolnames[spell.school]
                    if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
                end
                if spell.min and spell.max then
                    tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
                    tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
                end
                tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
            end
        end
    end

    function spellmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's absorb spells"], label)
    end

    function spellmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.absorbs.spells then
            win.title = _format(L["%s's absorb spells"], player.name)

            local nr = 1
            for spellid, spell in _pairs(player.absorbs.spells) do
                if spell.amount > 0 then
                    local spellname, _, spellicon = _GetSpellInfo(spellid)
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = spellid
                    d.spellid = spellid
                    d.label = spellname
                    d.icon = spellicon
                    d.spellschool = spell.school

                    d.value = spell.amount
                    d.valuetext = Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        mod.metadata.columns.Absorbs,
                        _format("%02.1f%%", 100 * spell.amount / math_max(1, player.absorbs.amount)),
                        mod.metadata.columns.Percent
                    )

                    if spell.amount > max then
                        max = spell.amount
                    end

                    nr = nr + 1
                end
            end
        end

        win.metadata.maxvalue = max
    end

    function playermod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's absorbed players"], label)
    end

    function playermod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.absorbs.targets then
            win.title = _format(L["%s's absorbed players"], player.name)

            local nr = 1
            for targetname, target in _pairs(player.absorbs.targets) do
                if target.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = targetname
                    d.label = targetname

                    if not target.class then
                        local p = Skada:find_player(set, target.id, targetname)
                        if p then
                            target.class = p.class or "PET"
                            target.role = p.role or "DAMAGER"
                            target.spec = p.spec or 1
                        elseif Skada:IsBoss(target.id) then
                            target.class = "MONSTER"
                            target.role = "DAMAGER"
                            target.spec = 3
                        else
                            target.class = "PET"
                            target.role = "DAMAGER"
                            target.spec = 1
                        end
                    end

                    d.class = target.class
                    d.role = target.role
                    d.spec = target.spec

                    d.value = target.amount
                    d.valuetext = Skada:FormatValueText(
                        Skada:FormatNumber(target.amount),
                        mod.metadata.columns.Absorbs,
                        _format("%02.1f%%", 100 * target.amount / math_max(1, player.absorbs.amount)),
                        mod.metadata.columns.Percent
                    )

                    if target.amount > max then
                        max = target.amount
                    end

                    nr = nr + 1
                end
            end
        end

        win.metadata.maxvalue = max
    end

    function mod:Update(win, set)
        local total = set.absorbs or 0
        local nr, max = 1, 0

        for i, player in _ipairs(set.players) do
            if player.absorbs then
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class or "PET"
                d.role = player.role or "DAMAGER"
                d.spec = player.spec or 1

                d.value = player.absorbs.amount
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(player.absorbs.amount),
                    self.metadata.columns.Absorbs,
                    _format("%02.1f%%", 100 * player.absorbs.amount / math_max(1, set.absorbs or 0)),
                    self.metadata.columns.Percent
                )

                if player.absorbs.amount > max then
                    max = player.absorbs.amount
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Absorbs"]
    end

    function mod:OnEnable()
        spellmod.metadata = {tooltip = spell_tooltip}
        playermod.metadata = {showspots = true}
        self.metadata = {
            showspots = true,
            click1 = spellmod,
            click2 = playermod,
            columns = {Absorbs = true, Percent = true}
        }

        Skada:RegisterForCL(AuraApplied, "SPELL_AURA_APPLIED", {src_is_interesting_nopets = true})
        Skada:RegisterForCL(AuraRemoved, "SPELL_AURA_REMOVED", {src_is_interesting_nopets = true})
        Skada:RegisterForCL(AuraApplied, "SPELL_AURA_REFRESH", {src_is_interesting_nopets = true})
        Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true})
        Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true})
        Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true})
        Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true})
        Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true})
        Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true})
        Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {dst_is_interesting_nopets = true})
        Skada:RegisterForCL(SpellMissed, "SPELL_PERIODIC_MISSED", {dst_is_interesting_nopets = true})
        Skada:RegisterForCL(SpellMissed, "SPELL_BUILDING_MISSED", {dst_is_interesting_nopets = true})
        Skada:RegisterForCL(SpellMissed, "RANGE_MISSED", {dst_is_interesting_nopets = true})
        Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {dst_is_interesting_nopets = true})

        Skada:AddMode(self, L["Absorbs and healing"])
        Skada.RegisterCallback(self, "ENCOUNTER_START", "CheckPreShields")
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
    end

    function mod:GetSetSummary(set)
        return Skada:FormatNumber(set.absorbs or 0)
    end
end)

-- ========================== --
-- Absorbs and healing module --
-- ========================== --

Skada:AddLoadableModule("Absorbs and healing", function(Skada, L)
    if Skada:IsDisabled("Healing", "Absorbs", "Absorbs and healing") then
        return
    end

    local mod = Skada:NewModule(L["Absorbs and healing"])
    local playermod = mod:NewModule(L["Absorbed and healed players"])
    local spellmod = mod:NewModule(L["Absorbs and healing spell list"])
    local hpsmode = mod:NewModule(L["HPS"])

    local _time = time

    local function getHPS(set, player)
        local healing = (player.healing and player.healing.amount or 0) + (player.absorbs and player.absorbs.amount or 0)
        return healing / math_max(1, Skada:PlayerActiveTime(set, player))
    end

    local function getRaidHPS(set)
        local healing = (set.healing or 0) + (set.absorbs or 0)
        if set.time > 0 then
            return healing / math_max(1, set.time)
        else
            return healing / math_max(1, (set.endtime or _time()) - set.starttime)
        end
    end

    local function hps_tooltip(win, id, label, tooltip)
        local set = win:get_selected_set()
        local player = Skada:find_player(set, id)
        if player then
            tooltip:AddLine(player.name .. " - " .. L["HPS"])
            tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(Skada:GetSetTime(set)), 1, 1, 1)
            tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(Skada:PlayerActiveTime(set, player, true)), 1, 1, 1)

            local healing = (player.healing and player.healing.amount or 0) + (player.absorbs and player.absorbs.amount or 0)
            local total = (set.healing or 0) + (set.absorbs or 0)
            tooltip:AddDoubleLine(L["Absorbs and healing"], _format("%s (%02.1f%%)", Skada:FormatNumber(healing), 100 * healing / math_max(1, total)), 1, 1, 1)
        end
    end

    local function spell_tooltip(win, id, label, tooltip)
        local player = Skada:find_player(win:get_selected_set(), win.playerid, win.playername)
        if player then
            local spell
            if player.healing then
                spell = player.healing.spells[id]
            end
            if not spell and player.absorbs then
                spell = player.absorbs.spells[id]
            end
            if spell then
                tooltip:AddLine(player.name .. " - " .. label)
                if spell.school then
                    local c = Skada.schoolcolors[spell.school]
                    local n = Skada.schoolnames[spell.school]
                    if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
                end
                tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
                if spell.min and spell.max then
                    tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
                    tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
                end
                tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
                if spell.critical then
                    tooltip:AddDoubleLine(CRIT_ABBR, _format("%02.1f%%", spell.critical / spell.count * 100), 1, 1, 1)
                end
                if spell.overhealing and spell.overhealing > 0 then
                    tooltip:AddDoubleLine(L["Overhealing"], _format("%02.1f%%", spell.overhealing / (spell.overhealing + spell.amount) * 100), 1, 1, 1)
                end
            end
        end
    end

    function spellmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's absorb and healing spells"], label)
    end

    function spellmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player then
            win.title = _format(L["%s's absorb and healing spells"], player.name)

            local total, spells = 0, {}

            if player.healing then
                total = total + player.healing.amount
                for spellid, spell in _pairs(player.healing.spells) do
                    spells[spellid] = CopyTable(spell)
                end
            end
            if player.absorbs then
                total = total + player.absorbs.amount
                for spellid, spell in _pairs(player.absorbs.spells) do
                    if not spells[spellid] then
                        spells[spellid] = CopyTable(spell)
                    else
                        spells[spellid].amount = spells[spellid].amount + spell.amount
                    end
                end
            end

            local nr = 1
            for spellid, spell in _pairs(spells) do
                if spell.amount > 0 then
                    local spellname, _, spellicon = _GetSpellInfo(spellid)

                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = spellid
                    d.label = spellname
                    d.icon = spellicon
                    d.spellid = spellid
                    d.spellschool = spell.school

                    d.value = spell.amount
                    d.valuetext = Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        mod.metadata.columns.Healing,
                        _format("%02.1f%%", 100 * spell.amount / math_max(1, total)),
                        mod.metadata.columns.Percent
                    )

                    if spell.amount > max then
                        max = spell.amount
                    end

                    nr = nr + 1
                end
            end
        end

        win.metadata.maxvalue = max
    end

    function playermod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's absorbed and healed players"], label)
    end

    function playermod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player then
            win.title = _format(L["%s's absorbed and healed players"], player.name)

            local total, targets = 0, {}

            if player.healing then
                total = total + player.healing.amount
                for targetname, target in _pairs(player.healing.targets) do
                    if not target.class then -- cache missing data once.
                        local p = Skada:find_player(set, target.id, targetname)
                        if p then
                            target.class = p.class or "PET"
                            target.role = p.role or "DAMAGER"
                            target.spec = p.spec or 1
                        elseif Skada:IsBoss(target.id) then
                            target.class = "MONSTER"
                            target.role = "DAMAGER"
                            target.spec = 3
                        else
                            target.class = "PET"
                            target.role = "DAMAGER"
                            target.spec = 1
                        end
                    end

                    targets[targetname] = CopyTable(target)
                end
            end

            if player.absorbs then
                total = total + player.absorbs.amount
                for targetname, target in _pairs(player.absorbs.targets) do
                    if not target.class then -- cache data.
                        local p = Skada:find_player(set, target.id, targetname)
                        if p then
                            target.class = p.class or "PET"
                            target.role = p.role or "DAMAGER"
                            target.spec = p.spec or 1
                        elseif Skada:IsBoss(target.id) then
                            target.class = "MONSTER"
                            target.role = "DAMAGER"
                            target.spec = 3
                        else
                            target.class = "PET"
                            target.role = "DAMAGER"
                            target.spec = 1
                        end
                    end

                    if not targets[targetname] then
                        targets[targetname] = CopyTable(target)
                    else
                        targets[targetname].amount = targets[targetname].amount + target.amount
                    end
                end
            end

            local nr = 1
            for targetname, target in _pairs(targets) do
                if target.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname
                    d.class = target.class
                    d.role = target.role
                    d.spec = target.spec

                    d.value = target.amount
                    d.valuetext = Skada:FormatValueText(
                        Skada:FormatNumber(target.amount),
                        mod.metadata.columns.Healing,
                        _format("%02.1f%%", 100 * target.amount / math_max(1, total)),
                        mod.metadata.columns.Percent
                    )

                    if target.amount > max then
                        max = target.amount
                    end

                    nr = nr + 1
                end
            end
        end

        win.metadata.maxvalue = max
    end

    function mod:Update(win, set)
        local total = (set.healing or 0) + (set.absorbs or 0)
        local nr, max = 1, 0

        for i, player in _ipairs(set.players) do
            local healing = 0
            if player.healing then
                healing = healing + player.healing.amount
            end
            if player.absorbs then
                healing = healing + player.absorbs.amount
            end

            if healing > 0 then
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class or "PET"
                d.role = player.role or "DAMAGER"
                d.spec = player.spec or 1

                d.value = healing
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(healing),
                    self.metadata.columns.Healing,
                    Skada:FormatNumber(getHPS(set, player)),
                    self.metadata.columns.HPS,
                    _format("%02.1f%%", 100 * healing / math_max(1, total)),
                    self.metadata.columns.Percent
                )

                if healing > max then
                    max = healing
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Absorbs and healing"]
    end

    local function feed_personal_hps()
        if Skada.current then
            local player = Skada:find_player(Skada.current, _UnitGUID("player"))
            if player then
                return Skada:FormatNumber(getHPS(Skada.current, player)) .. " " .. L["HPS"]
            end
        end
    end

    local function feed_raid_hps()
        if Skada.current then
            return Skada:FormatNumber(getRaidHPS(Skada.current)) .. " " .. L["RHPS"]
        end
    end

    function hpsmode:GetSetSummary(set)
        return Skada:FormatNumber(getRaidHPS(set))
    end

    function hpsmode:Update(win, set)
        local max, nr = 0, 1
        local total = getRaidHPS(set)

        for _, player in ipairs(set.players) do
            local hps = getHPS(set, player)
            if hps > 0 then
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class or "PET"
                d.role = player.role or "DAMAGER"
                d.spec = player.spec or 1

                d.value = hps
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(hps),
                    self.metadata.columns.HPS,
                    _format("%02.1f%%", 100 * hps / math_max(1, total)),
                    self.metadata.columns.Percent
                )

                if hps > max then
                    max = hps
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["HPS"]
    end

    function mod:OnEnable()
        spellmod.metadata = {tooltip = spell_tooltip}
        playermod.metadata = {showspots = true}
        mod.metadata = {
            showspots = true,
            click1 = spellmod,
            click2 = playermod,
            columns = {Healing = true, HPS = true, Percent = true}
        }
        hpsmode.metadata = {
            showspots = true,
            tooltip = hps_tooltip,
            click1 = spellmod,
            click2 = playermod,
            columns = {HPS = true, Percent = true}
        }

        Skada:AddFeed(L["Healing: Personal HPS"], feed_personal_hps)
        Skada:AddFeed(L["Healing: Raid HPS"], feed_raid_hps)

        Skada:AddMode(self, L["Absorbs and healing"])
        Skada:AddMode(hpsmode, L["Absorbs and healing"])
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
        Skada:RemoveMode(hpsmode)
        Skada:RemoveFeed(L["Healing: Personal HPS"])
        Skada:RemoveFeed(L["Healing: Raid HPS"])
    end

    function mod:AddToTooltip(set, tooltip)
        local total = (set.healing or 0) + (set.absorbs or 0)
        if total > 0 then
            tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(total), 1, 1, 1)
            tooltip:AddDoubleLine(L["HPS"], Skada:FormatNumber(getRaidHPS(set)), 1, 1, 1)
        end
        if set.overhealing and set.overhealing > 0 then
            local totall = total + set.overhealing
            tooltip:AddDoubleLine(L["Overhealing"], _format("%02.1f%%", 100 * set.overhealing / math_max(1, totall)), 1, 1, 1)
        end
    end

    function mod:GetSetSummary(set)
        local total = (set.healing or 0) + (set.absorbs or 0)
        return Skada:FormatValueText(
            Skada:FormatNumber(total),
            self.metadata.columns.Healing,
            Skada:FormatNumber(getRaidHPS(set)),
            self.metadata.columns.HPS
        )
    end
end)

-- ===================== --
-- Healing done by spell --
-- ===================== --

Skada:AddLoadableModule("Healing done by spell", function(Skada, L)
    if Skada:IsDisabled("Healing", "Absorbs", "Healing done by spell") then
        return
    end

    local mod = Skada:NewModule(L["Healing done by spell"])
    local spells

    local function CacheSpells(set)
        spells = {}
        for _, player in _ipairs(set.players) do
            if player.healing and player.healing.spells then
                for spellid, spell in _pairs(player.healing.spells) do
                    if not spells[spellid] then
                        spells[spellid] = CopyTable(spell)
                    else
                        spells[spellid].amount = spells[spellid].amount + spell.amount
                        spells[spellid].count = (spells[spellid].count or 0) + (spell.count or 0)
                        spells[spellid].overhealing = (spells[spellid].overhealing or 0) + (spell.overhealing or 0)
                    end
                end
            end
            if player.absorbs and player.absorbs.spells then
                for spellid, spell in _pairs(player.absorbs.spells) do
                    if not spells[spellid] then
                        spells[spellid] = CopyTable(spell)
                    else
                        spells[spellid].amount = spells[spellid].amount + spell.amount
                        spells[spellid].count = (spells[spellid].count or 0) + (spell.count or 0)
                    end
                end
            end
        end
    end

    local function spell_tooltip(win, id, label, tooltip)
        local set = win:get_selected_set()
        if not set then return end

        if not spells then CacheSpells(set) end

        local spell = spells[id]
        if spell then
            local total = (set.healing or 0) + (set.absorbs or 0)
            local overheal = (set.overhealing or 0)

            tooltip:AddLine(_GetSpellInfo(id))
            if spell.school then
                local c = Skada.schoolcolors[spell.school]
                local n = Skada.schoolnames[spell.school]
                if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
            end

            if spell.count then
                tooltip:AddDoubleLine(L["Count"], spell.count, 1, 1, 1)
            end
            tooltip:AddDoubleLine(L["Healing"], _format("%s (%02.1f%%)", Skada:FormatNumber(spell.amount), 100 * spell.amount / math_max(1, total)), 1, 1, 1)
            if spell.overhealing then
                tooltip:AddDoubleLine(L["Overhealing"], _format("%s (%02.1f%%)", Skada:FormatNumber(spell.overhealing), 100 * spell.overhealing / math_max(1, overheal) ), 1, 1, 1)
            end
        end
    end

    function mod:Update(win, set)
        local max = 0
        if set then
            CacheSpells(set)

            local total = (set.healing or 0) + (set.absorbs or 0)
            local nr = 1

            for spellid, spell in _pairs(spells) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                local spellname, _, spellicon = _GetSpellInfo(spellid)

                d.id = spellid
                d.spellid = spellid
                d.label = spellname
                d.icon = spellicon
                d.spellschool = spell.school

                d.value = spell.amount
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(spell.amount),
                    self.metadata.columns.Healing,
                    _format("%02.1f%%", 100 * spell.amount / math_max(1, total)),
                    self.metadata.columns.Percent
                )

                if spell.amount > max then
                    max = spell.amount
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Healing done by spell"]
    end

    function mod:OnEnable()
        self.metadata = {
            showspots = true,
            tooltip = spell_tooltip,
            columns = {Healing = true, Percent = true}
        }
        Skada:AddMode(self, L["Absorbs and healing"])
    end

    function mod:OnDisable()
        Skada:RemoveMode(self, L["Absorbs and healing"])
    end
end)