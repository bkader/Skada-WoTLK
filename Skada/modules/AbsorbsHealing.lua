local Skada = Skada
if not Skada then
    return
end

local _time, _GetTime = time, GetTime
local _pairs, _ipairs = pairs, ipairs
local _select, _format = select, string.format
local math_max = math.max
local _UnitGUID, _UnitName, _UnitClass = UnitGUID, UnitName, UnitClass
local _GetSpellInfo = GetSpellInfo
local table_insert, table_remove, table_sort = table.insert, table.remove, table.sort

Skada:AddLoadableModule(
    "Healing",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Healing") then
            return
        end

        local mod = Skada:NewModule(L["Healing"])
        local playermod = mod:NewModule(L["Healed player list"])
        local spellmod = mod:NewModule(L["Healing spell list"])

        local function log_heal(set, data, tick)
            local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
            if not player then
                return
            end

            -- get rid of overhealing
            local amount = math_max(0, data.amount - data.overhealing)

            -- record the healing
            player.healing.amount = player.healing.amount + amount
            set.healing = set.healing + amount

            -- record the overhealing
            player.healing.overhealing = player.healing.overhealing + data.overhealing
            set.overhealing = set.overhealing + data.overhealing

            -- record the target
            if not player.healing.targets[data.dstName] then
                player.healing.targets[data.dstName] = {
                    id = data.dstGUID,
                    name = data.dstName,
                    flag = data.dstFlags,
                    amount = 0
                }
                Skada:FixPlayer(player.healing.targets[data.dstName])
            end
            player.healing.targets[data.dstName].amount = player.healing.targets[data.dstName].amount + amount

            -- record the spell
            if data.spellid then
                if not player.healing.spells[data.spellid] then
                    player.healing.spells[data.spellid] = {
                        school = data.spellschool,
                        amount = 0,
                        count = 0,
                        overhealing = 0
                    }
                end

                local spell = player.healing.spells[data.spellid]
                spell.count = spell.count + 1
                spell.amount = spell.amount + amount
                spell.overhealing = spell.overhealing + data.overhealing

                if not spell.min or amount < spell.min then
                    spell.min = amount
                end
                if not spell.max or amount > spell.max then
                    spell.max = amount
                end

                if data.critical then
                    spell.critical = (spell.critical or 0) + 1
                end
            end
        end

        local heal = {}

        local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            local spellid, spellname, spellschool, amount, overhealing, absorbed, critical = ...

            if absorbed == 1 and not critical then
                critical = absorbed
                absorbed = nil
            end

            heal.playerid = srcGUID
            heal.playername = srcGUID
            heal.playerflags = srcFlags

            heal.dstGUID = dstGUID
            heal.dstName = dstName
            heal.dstFlags = dstFlags

            heal.spellid = spellid
            heal.spellname = spellname
            heal.spellschool = spellschool

            heal.amount = amount
            heal.overhealing = overhealing
            heal.absorbed = absorbed
            heal.critical = critical

            Skada:FixPets(heal)
            log_heal(Skada.current, heal)
            log_heal(Skada.total, heal)
        end

        local function getHPS(set, player)
            local totaltime = Skada:PlayerActiveTime(set, player)
            return player.healing.amount / math_max(1, totaltime)
        end

        local function getRaidHPS(set)
            if set.time > 0 then
                return set.healing / math_max(1, set.time)
            else
                local endtime = set.endtime or _time()
                return set.healing / math_max(1, endtime - set.starttime)
            end
        end

        local function spell_tooltip(win, id, label, tooltip)
            local player = Skada:find_player(win:get_selected_set(), spellmod.playerid)
            if player then
                local spell = player.healing.spells[id]
                if spell then
                    tooltip:AddLine(player.name .. " - " .. label)
                    if spell.school then
                        local c = Skada.schoolcolors[spell.school]
                        local n = Skada.schoolnames[spell.school]
                        if c and n then
                            tooltip:AddLine(L[n], c.r, c.g, c.b)
                        end
                    end
                    tooltip:AddDoubleLine(L["Total"], spell.count, 255, 255, 255, 255, 255, 255)
                    if spell.min and spell.max then
                        tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 255, 255, 255, 255, 255, 255)
                        tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 255, 255, 255, 255, 255, 255)
                    end
                    tooltip:AddDoubleLine(
                        L["Average"],
                        Skada:FormatNumber(spell.amount / spell.count),
                        255,
                        255,
                        255,
                        255,
                        255,
                        255
                    )
                    if spell.critical then
                        tooltip:AddDoubleLine(
                            CRIT_ABBR,
                            _format("%02.1f%%", spell.critical / spell.count * 100),
                            255,
                            255,
                            255,
                            255,
                            255,
                            255
                        )
                    end
                    if spell.overhealing > 0 then
                        tooltip:AddDoubleLine(
                            L["Overhealing"],
                            _format("%02.1f%%", spell.overhealing / (spell.overhealing + spell.amount) * 100),
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
        end

        function spellmod:Enter(win, id, label)
            self.playerid = id
            self.title = _format(L["%s's healing spells"], label)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for spellid, spell in _pairs(player.healing.spells) do
                    if spell.amount > 0 then
                        local spellname, _, spellicon = _GetSpellInfo(spellid)

                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = spellid
                        d.icon = spellicon
                        d.spellid = spellid
                        d.label = spellname
                        d.spellschool = spell.school

                        d.value = spell.amount
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(spell.amount),
                            mod.metadata.columns.Healing,
                            _format("%02.1f%%", spell.amount / player.healing.amount * 100),
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
            self.playerid = id
            self.title = _format(L["%s's healed players"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for targetname, target in _pairs(player.healing.targets) do
                    if target.amount > 0 then
                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = target.id
                        d.label = targetname
                        d.class = target.class
                        d.role = target.role
                        d.spec = target.spec

                        d.value = target.amount
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(target.amount),
                            mod.metadata.columns.Healing,
                            _format("%02.1f%%", target.amount / player.healing.amount * 100),
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
            local nr, max = 1, 0

            for i, player in _ipairs(set.players) do
                if player.healing.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.healing.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.healing.amount),
                        self.metadata.columns.Healing,
                        Skada:FormatNumber(getHPS(set, player)),
                        self.metadata.columns.HPS,
                        _format("%02.1f%%", player.healing.amount / set.healing * 100),
                        self.metadata.columns.Percent
                    )

                    if player.healing.amount > max then
                        max = player.healing.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
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

            Skada:RegisterForCL(SpellHeal, "SPELL_HEAL", {src_is_interesting = true})
            Skada:RegisterForCL(SpellHeal, "SPELL_PERIODIC_HEAL", {src_is_interesting = true})

            Skada:AddMode(self, L["Absorbs and healing"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:GetSetSummary(set)
            return Skada:FormatValueText(
                Skada:FormatNumber(set.healing),
                self.metadata.columns.Healing,
                Skada:FormatNumber(getRaidHPS(set)),
                self.metadata.columns.HPS,
                _format("%02.1f%%", 100 * set.healing / math_max(1, set.healing)),
                self.metadata.columns.Percent
            )
        end

        function mod:AddPlayerAttributes(player)
            if not player.healing then
                player.healing = {amount = 0, overhealing = 0, spells = {}, targets = {}}
            end
        end

        function mod:AddSetAttributes(set)
            set.healing = set.healing or 0
            set.overhealing = set.overhealing or 0
        end
    end
)

-- Total healing
Skada:AddLoadableModule(
    "Total healing",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Healing", "Total healing") then
            return
        end
        local mod = Skada:NewModule(L["Total healing"])

        function mod:Update(win, set)
            local maxvalue = 0
            for i, player in _ipairs(set.players) do
                if player.healing.amount + player.healing.overhealing > maxvalue then
                    maxvalue = player.healing.amount + player.healing.overhealing
                end
            end

            local nr, max = 1, 0

            for i, player in _ipairs(set.players) do
                local total = (player.healing.amount or 0) + (player.healing.overhealing or 0)
                if total > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.healing.amount
                    d.valuetext =
                        Skada:FormatNumber(player.healing.amount) ..
                        "/" .. Skada:FormatNumber(player.healing.overhealing)

                    d.color = {r = 0, g = 1, b = 0, a = 1}
                    d.backgroundcolor = {r = 1, g = 0, b = 0, a = 1}
                    d.backgroundwidth = total / maxvalue

                    if total > max then
                        max = total
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            mod.metadata = {showspots = true}
            Skada:AddMode(self, L["Absorbs and healing"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:GetSetSummary(set)
            return Skada:FormatNumber(set.healing) .. "/" .. Skada:FormatNumber(set.overhealing)
        end
    end
)

-- Overhealing
Skada:AddLoadableModule(
    "Overhealing",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Healing", "Overhealing") then
            return
        end
        local mod = Skada:NewModule(L["Overhealing"])

        function mod:Update(win, set)
            local nr, max = 1, 0

            for i, player in _ipairs(set.players) do
                if player.healing.overhealing > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.healing.overhealing
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.healing.overhealing),
                        self.metadata.columns.Overheal,
                        _format("%02.1f%%", player.healing.overhealing / set.overhealing * 100),
                        self.metadata.columns.Percent
                    )

                    if player.healing.overhealing > max then
                        max = player.healing.overhealing
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            mod.metadata = {showspots = true, columns = {Overheal = true, Percent = true}}
            Skada:AddMode(self, L["Absorbs and healing"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:GetSetSummary(set)
            return Skada:FormatNumber(set.overhealing)
        end
    end
)

-- Absorbs
Skada:AddLoadableModule(
    "Absorbs",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Absorbs") then
            return
        end

        local mod = Skada:NewModule(L["Absorbs"], "AceTimer-3.0")
        local spellmod = mod:NewModule(L["Absorb spell list"])
        local playermod = mod:NewModule(L["Absorbed player list"])

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
            [31000] = 300,
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
            [64411] = 15,
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

        local function log_absorb(set, playerid, playername, playerflags, dstGUID, dstName, dstFlags, spellid, amount)
            local player = Skada:get_player(set, playerid, playername, playerflags)
            if not player then
                return
            end

            -- add absorbs amount
            player.absorbs.amount = player.absorbs.amount + amount
            set.absorbs = set.absorbs + amount

            -- record the target
            if not player.absorbs.targets[dstName] then
                local p = Skada:find_player(set, dstGUID, dstName, dstGUID)
                if p then
                    player.absorbs.targets[dstName] = {
                        id = p.id,
                        class = p.class,
                        role = p.role,
                        spec = p.spec,
                        amount = 0
                    }
                else
                    local unitclass = _select(2, _UnitClass(dstName))
                    local unitrole = UnitGroupRolesAssigned(dstName) or "NONE"
                    player.absorbs.targets[dstName] = {class = unitclass, role = unitrole, amount = 0}
                end
            end
            player.absorbs.targets[dstName].amount = player.absorbs.targets[dstName].amount + amount

            -- record the spell
            if not player.absorbs.spells[spellid] then
                player.absorbs.spells[spellid] = {count = 0, amount = 0}
            end
            local spell = player.absorbs.spells[spellid]
            spell.amount = spell.amount + amount
            spell.count = spell.count + 1

            if not spell.min or amount < spell.min then
                spell.min = amount
            end

            if not spell.max or amount > spell.max then
                spell.max = amount
            end
        end

        local shields = {}

        --
        -- just like details, we make sure to order shields by priority, and that's not
        -- the time it was applied, but function depending on the damage received
        --
        local function sort_shields(a, b)
            local a_spell = a and a.spellid or 100000
            local b_spell = b and b.spellid or 100000

            -- puts oldest absorb first if there is two with the same id.
            if a_spell == b_spell then
                return a.timestamp < b.timestamp
            end

            -- twin val'kyr light essence
            if a_spell == 65686 then
                return true
            end
            if b_spell == 65686 then
                return false
            end

            -- twin val'kyr dark essence
            if a_spell == 65684 then
                return true
            end
            if b_spell == 65684 then
                return false
            end

            --frost ward
            if mage_frost_ward[a_spell] then
                return true
            end
            if mage_frost_ward[b_spell] then
                return false
            end

            -- fire ward
            if mage_fire_ward[a_spell] then
                return true
            end
            if mage_fire_ward[b_spell] then
                return false
            end

            --shadow ward
            if warlock_shadow_ward[a_spell] then
                return true
            end
            if warlock_shadow_ward[b_spell] then
                return false
            end

            -- Sacred Shield
            if a_spell == 58597 then
                return true
            end
            if b_spell == 58597 then
                return false
            end

            -- Fell blossom
            if a_spell == 28527 then
                return true
            end
            if b_spell == 28527 then
                return false
            end

            -- Divine Aegis
            if a_spell == 47753 then
                return true
            end
            if b_spell == 47753 then
                return false
            end

            -- Ice Barrier
            if mage_ice_barrier[a_spell] then
                return true
            end
            if mage_ice_barrier[b_spell] then
                return false
            end

            -- Warlock Sacrifice
            if warlock_sacrifice[a_spell] then
                return true
            end
            if warlock_sacrifice[b_spell] then
                return false
            end

            if absorbspells[a_spell] then
                return true
            end
            if absorbspells[b_spell] then
                return false
            end

            -- sort oldest buffs to the top
            return a.timestamp < b.timestamp
        end

        local function remove_shield(dstName, srcGUID, spellid)
            shields[dstName] = shields[dstName] or {}
            local index

            for i, absorb in _ipairs(shields[dstName]) do
                if absorb.srcGUID == srcGUID and absorb.spellid == spellid then
                    index = i
                    break
                end
            end

            if index then
                table_remove(shields[dstName], index)
                table_sort(shields[dstName], sort_shields)
            end
        end

        local function AuraApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            local spellid, spellname, spellschool, auratype, amount = ...
            if absorbspells[spellid] then
                shields[dstName] = shields[dstName] or {}

                local absorb = {}
                absorb.timestamp = timestamp
                absorb.srcGUID = srcGUID
                absorb.srcName = srcName
                absorb.srcFlags = srcFlags
                absorb.spellid = spellid

                table_insert(shields[dstName], absorb)
                table_sort(shields[dstName], sort_shields)
            end
        end

        local function AuraRemoved(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            local spellid, spellname, spellschool, auratype = ...
            if absorbspells[spellid] then
                shields[dstName] = shields[dstName] or {}

                for _, absorb in _ipairs(shields[dstName]) do
                    if absorb.srcGUID == srcGUID and absorb.spellid == spellid then
                        mod:ScheduleTimer(
                            function()
                                remove_shield(dstName, dstGUID, spellid)
                            end,
                            0.1
                        )
                    end
                end
            end
        end

        local function AuraRefresh(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            local spellid, spellname, spellschool, auratype, amount = ...
            if absorbspells[spellid] then
                shields[dstName] = shields[dstName] or {}

                local found = false
                for _, absorb in _ipairs(shields[dstName]) do
                    if absorb.spellid == spellid and absorb.srcGUID == srcGUID then
                        absorb.timestamp = timestamp
                        found = true
                        break
                    end
                end

                if not found then
                    local absorb = {}
                    absorb.timestamp = timestamp
                    absorb.srcGUID = srcGUID
                    absorb.srcName = srcName
                    absorb.srcFlags = srcFlags
                    absorb.spellid = spellid

                    table_insert(shields[dstName], absorb)
                    table_sort(shields[dstName], sort_shields)
                end
            end
        end

        local function process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool)
            shields[dstName] = shields[dstName] or {}
            local found

            for _, absorb in _ipairs(shields[dstName]) do
                -- twin val'kyr light essence and we took fire damage
                if absorb.spellid == 65686 then
                    --twin val'kyr dark essence and we took shadow damage
                    if bit.band(spellschool, 0x4) == spellschool then
                        return
                    end
                elseif absorb.spellid == 65684 then
                    -- check if its a frost ward
                    if bit.band(spellschool, 0x20) == spellschool then
                        return
                    end
                elseif mage_frost_ward[absorb.spellid] then
                    -- check if its a fire ward
                    -- only pick if its frost damage
                    if bit.band(spellschool, 0x10) == spellschool then
                        found = absorb
                        break
                    end
                elseif mage_fire_ward[absorb.spellid] then
                    -- check if its a shadow ward
                    -- only pick if its fire damage
                    if bit.band(spellschool, 0x4) == spellschool then
                        found = absorb
                        break
                    end
                elseif warlock_shadow_ward[absorb.spellid] then
                    -- only pick if its shadow damage
                    if bit.band(spellschool, 0x20) == spellschool then
                        found = absorb
                        break
                    end
                else
                    found = absorb
                    break
                end
            end

            if found then
                log_absorb(
                    Skada.current,
                    found.srcGUID,
                    found.srcName,
                    found.srcFlags,
                    dstGUID,
                    dstName,
                    dstFlags,
                    found.spellid,
                    absorbed
                )
                log_absorb(
                    Skada.total,
                    found.srcGUID,
                    found.srcName,
                    found.srcFlags,
                    dstGUID,
                    dstName,
                    dstFlags,
                    found.spellid,
                    absorbed
                )
            end
        end

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
            if absorbed and absorbed > 0 and dstName and srcName then
                process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool)
            end
        end

        local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            local spellid, spellname, spellschool, misstype, absorbed = ...
            if misstype == "ABSORB" and absorbed > 0 and dstName and srcName then
                process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, spellschool)
            end
        end

        local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            local amount, overkill, spellschool, resisted, blocked, absorbed, critical, glancing, crushing = ...
            if absorbed and absorbed > 0 and dstName and srcName then
                process_absorb(timestamp, dstGUID, dstName, dstFlags, absorbed, 1)
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
                3306,
                MELEE,
                1,
                ...
            )
        end

        local function spell_tooltip(win, id, label, tooltip)
            local player = Skada:find_player(win:get_selected_set(), spellmod.playerid)
            if player then
                local spell = player.absorbs.spells[id]
                if spell then
                    tooltip:AddLine(player.name .. " - " .. label)
                    if spell.min and spell.max then
                        tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 255, 255, 255, 255, 255, 255)
                        tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 255, 255, 255, 255, 255, 255)
                    end
                    tooltip:AddDoubleLine(
                        L["Average"],
                        Skada:FormatNumber(spell.amount / spell.count),
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

        function spellmod:Enter(win, id, label)
            self.playerid = id
            self.title = _format(L["%s's absorb spells"], label)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
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

                        d.value = spell.amount
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(spell.amount),
                            mod.metadata.columns.Absorbs,
                            _format("%02.1f%%", spell.amount / player.absorbs.amount * 100),
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
            self.playerid = id
            self.title = _format(L["%s's absorbed players"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1
                for targetname, target in _pairs(player.absorbs.targets) do
                    if target.amount > 0 then
                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = targetname
                        d.label = targetname
                        d.class = target.class
                        d.role = target.role
                        d.spec = target.spec

                        d.value = target.amount
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(target.amount),
                            mod.metadata.columns.Absorbs,
                            _format("%02.1f%%", target.amount / player.absorbs.amount * 100),
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
                if player.absorbs.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec
                    d.value = player.absorbs.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.absorbs.amount),
                        self.metadata.columns.Absorbs,
                        _format("%02.1f%%", player.absorbs.amount / math_max(1, set.absorbs) * 100),
                        self.metadata.columns.Percent
                    )

                    if player.absorbs.amount > max then
                        max = player.absorbs.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        do
            local function check_for_shields(unit)
                if unit then
                    local found = false
                    local dstGUID, dstName = _UnitGUID(unit), _UnitName(unit)
                    shields[dstName] = shields[dstName] or {}
                    -- loop through our shields and see if player were pre-shielded
                    for i = 0, 31 do
                        local spellname, _, _, _, _, duration, expires, unitCaster, _, _, spellid =
                            UnitAura(unit, i, nil, "BUFF")

                        -- if we find any, we make sure to send it to AuraApplied to do the rest
                        if spellid and absorbspells[spellid] and unitCaster then
                            found = true -- flag so we can order shields later

                            local srcGUID, srcName = _UnitGUID(unitCaster), _UnitName(unitCaster)

                            local absorb = {}
                            absorb.timestamp = expires - (duration or absorbspells[spellid])
                            absorb.srcGUID = srcGUID
                            absorb.srcName = srcName
                            absorb.spellid = spellid
                            table_insert(shields[dstName], absorb)
                        end

                        if found then
                            table_sort(shields[dstName], sort_shields)
                        end
                    end
                end
            end

            function mod:StartCombat()
                -- we always clear our shields table at the start of the combat
                shields = {}

                local t, count = Skada:GetGroupTypeAndCount()
                if count > 0 then
                    for i = 1, count do
                        if UnitExists(t .. i) and not UnitIsDeadOrGhost(t .. i) then
                            check_for_shields(t .. i)
                        end
                    end
                elseif not UnitIsDeadOrGhost(t) then
                    check_for_shields(t)
                end
            end
        end

        function mod:OnEnable()
            spellmod.metadata = {tooltip = spell_tooltip}
            playermod.metadata = {showspots = true}
            mod.metadata = {
                showspots = true,
                click1 = spellmod,
                click2 = playermod,
                columns = {Absorbs = true, Percent = true}
            }

            hooksecurefunc(Skada, "StartCombat", mod.StartCombat)

            Skada:RegisterForCL(AuraApplied, "SPELL_AURA_APPLIED", {src_is_interesting_nopets = true})
            Skada:RegisterForCL(AuraRemoved, "SPELL_AURA_REMOVED", {src_is_interesting_nopets = true})
            Skada:RegisterForCL(AuraRefresh, "SPELL_AURA_REFRESH", {src_is_interesting_nopets = true})
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
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:GetSetSummary(set)
            return Skada:FormatValueText(
                Skada:FormatNumber(set.absorbs),
                self.metadata.columns.Absorbs,
                _format("%02.1f%%", 100 * set.absorbs / math_max(1, set.absorbs)),
                self.metadata.columns.Percent
            )
        end

        function mod:AddPlayerAttributes(player)
            if not player.absorbs then
                player.absorbs = {amount = 0, spells = {}, targets = {}}
            end
        end

        function mod:AddSetAttributes(set)
            set.absorbs = set.absorbs or 0
            shields = {}
        end
    end
)

-- -- Absorbs and healing
Skada:AddLoadableModule(
    "Absorbs and healing",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Healing", "Absorbs", "Absorbs and healing") then
            return
        end

        local mod = Skada:NewModule(L["Absorbs and healing"])
        local playermod = mod:NewModule(L["Healed and absorbed players"])
        local spellmod = mod:NewModule(L["Healing and absorbs spell list"])

        local function getHPS(set, player)
            local totaltime = Skada:PlayerActiveTime(set, player)
            return (player.healing.amount + player.absorbs.amount) / math_max(1, totaltime)
        end

        local function getRaidHPS(set)
            if set.time > 0 then
                return (set.healing + set.absorbs) / math_max(1, set.time)
            else
                local endtime = set.endtime or _time()
                return (set.healing + set.absorbs) / math_max(1, endtime - set.starttime)
            end
        end

        local function spell_tooltip(win, id, label, tooltip)
            local player = Skada:find_player(win:get_selected_set(), spellmod.playerid)
            if player then
                local spell = player.healing.spells[id] or player.absorbs.spells[id]
                if spell then
                    tooltip:AddLine(player.name .. " - " .. label)
                    if spell.school then
                        local c = Skada.schoolcolors[spell.school]
                        local n = Skada.schoolnames[spell.school]
                        if c and n then
                            tooltip:AddLine(L[n], c.r, c.g, c.b)
                        end
                    end
                    tooltip:AddDoubleLine(L["Count"], spell.count, 255, 255, 255, 255, 255, 255)
                    if spell.min and spell.max then
                        tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 255, 255, 255, 255, 255, 255)
                        tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 255, 255, 255, 255, 255, 255)
                    end
                    tooltip:AddDoubleLine(
                        L["Average"],
                        Skada:FormatNumber(spell.amount / spell.count),
                        255,
                        255,
                        255,
                        255,
                        255,
                        255
                    )
                    if spell.critical then
                        tooltip:AddDoubleLine(
                            CRIT_ABBR,
                            _format("%02.1f%%", spell.critical / spell.count * 100),
                            255,
                            255,
                            255,
                            255,
                            255,
                            255
                        )
                    end
                    if spell.overhealing and spell.overhealing > 0 then
                        tooltip:AddDoubleLine(
                            L["Overhealing"],
                            _format("%02.1f%%", spell.overhealing / (spell.overhealing + spell.amount) * 100),
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
        end

        function spellmod:Enter(win, id, label)
            self.playerid = id
            self.title = _format(L["%s's absorb and healing spells"], label)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local spells = {}

                for spellid, spell in _pairs(player.healing.spells) do
                    spells[spellid] = CopyTable(spell)
                end
                for spellid, spell in _pairs(player.absorbs.spells) do
                    if not spells[spellid] then
                        spells[spellid] = CopyTable(spell)
                    else
                        spells[spellid].amount = spells[spellid].amount + spell.amount
                    end
                end

                local total = player.healing.amount + player.absorbs.amount
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
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(spell.amount),
                            mod.metadata.columns.Healing,
                            _format("%02.1f%%", spell.amount / total * 100),
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
            self.playerid = id
            self.title = _format(L["%s's absorbed and healed players"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local targets = {}

                for targetname, target in _pairs(player.healing.targets) do
                    targets[targetname] = CopyTable(target)
                end
                for targetname, target in _pairs(player.absorbs.targets) do
                    if not targets[targetname] then
                        targets[targetname] = CopyTable(target)
                    else
                        targets[targetname].amount = targets[targetname].amount + target.amount
                    end
                end

                local total = player.healing.amount + player.absorbs.amount
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
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(target.amount),
                            mod.metadata.columns.Healing,
                            _format("%02.1f%%", target.amount / total * 100),
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
            local nr, max = 1, 0

            for i, player in _ipairs(set.players) do
                local healing = player.healing.amount + player.absorbs.amount

                if healing > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = healing
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(healing),
                        self.metadata.columns.Healing,
                        Skada:FormatNumber(getHPS(set, player)),
                        self.metadata.columns.HPS,
                        _format("%02.1f%%", healing / (set.healing + set.absorbs) * 100),
                        self.metadata.columns.Percent
                    )

                    if healing > max then
                        max = healing
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
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

            Skada:AddMode(self, L["Absorbs and healing"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddToTooltip(set, tooltip)
            local total = (set.healing or 0) + (set.absorbs or 0)
            if total > 0 then
                tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(total), 1, 1, 1)
                tooltip:AddDoubleLine(L["HPS"], Skada:FormatNumber(getRaidHPS(set)), 1, 1, 1)
            end
            if set.overhealing and set.overhealing > 0 then
                local totall = total + set.overhealing
                tooltip:AddDoubleLine(
                    L["Overhealing"],
                    _format("%02.1f%%", 100 * set.overhealing / math_max(1, totall)),
                    1,
                    1,
                    1
                )
            end
        end

        function mod:GetSetSummary(set)
            local total = set.healing + set.absorbs
            return Skada:FormatValueText(
                Skada:FormatNumber(total),
                mod.metadata.columns.Healing,
                Skada:FormatNumber(getRaidHPS(set)),
                mod.metadata.columns.HPS,
                _format("%02.1f%%", 100 * total / math_max(1, total)),
                mod.metadata.columns.Percent
            )
        end
    end
)