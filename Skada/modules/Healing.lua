local Skada = Skada

-- cache frequently used globals
local _pairs, _ipairs, _select = pairs, ipairs, select
local _format, math_max, _time = string.format, math.max, time
local _GetSpellInfo = GetSpellInfo

-- ============== --
-- Healing module --
-- ============== --

Skada:AddLoadableModule(
    "Healing",
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
                    amount = 0,
                    overhealing = 0
                }
            end
            player.healing.targets[data.dstName].amount = player.healing.targets[data.dstName].amount + amount
            player.healing.targets[data.dstName].overhealing =
                player.healing.targets[data.dstName].overhealing + data.overhealing

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
                    tooltip:AddDoubleLine(L["Total"], spell.count, 255, 255, 255)
                    if spell.min and spell.max then
                        tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 255, 255, 255)
                        tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 255, 255, 255)
                    end
                    tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 255, 255, 255)
                    if spell.critical then
                        tooltip:AddDoubleLine(CRIT_ABBR, _format("%02.1f%%", spell.critical / spell.count * 100), 255, 255, 255)
                    end
                    if spell.overhealing > 0 then
                        tooltip:AddDoubleLine(L["Overhealing"], _format("%02.1f%%", spell.overhealing / (spell.overhealing + spell.amount) * 100), 255, 255, 255)
                    end
                end
            end
        end

        function spellmod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["%s's healing spells"], label)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid, self.playername)
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
            self.playername = label
            self.title = _format(L["%s's healed players"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid, self.playername)
            local max = 0

            if player then
                local nr = 1

                for targetname, target in _pairs(player.healing.targets) do
                    if target.amount > 0 then
                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = target.id
                        d.label = targetname

                        local p = Skada:find_player(set, target.id, targetname)
                        if p then
                            d.class = p.class
                            d.role = p.role
                            d.spec = p.spec
                        else
                            d.class = Skada:GetPetOwner(target.id) and "PET" or "UNKNOWN"
                        end

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
            self.metadata = {
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
                self.metadata.columns.HPS
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

-- ================== --
-- Overhealing module --
-- ================== --

Skada:AddLoadableModule(
    "Overhealing",
    function(Skada, L)
        if Skada:IsDisabled("Healing", "Overhealing") then
            return
        end
        local mod = Skada:NewModule(L["Overhealing"])
        local playermod = mod:NewModule(L["Overhealed player list"])
        local spellmod = mod:NewModule(L["Overhealing spell list"])

        function spellmod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["%s's overhealing spells"], label)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid, self.playername)
            local max = 0

            if player then
                local nr = 1

                for spellid, spell in _pairs(player.healing.spells) do
                    if spell.overhealing > 0 then
                        local total = spell.amount + spell.overhealing
                        local spellname, _, spellicon = _GetSpellInfo(spellid)

                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = spellid
                        d.icon = spellicon
                        d.spellid = spellid
                        d.label = spellname
                        d.spellschool = spell.school

                        d.value = spell.overhealing
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(spell.overhealing),
                            mod.metadata.columns.Overheal,
                            _format("%02.1f%%", 100 * spell.overhealing / math_max(1, total)),
                            mod.metadata.columns.Percent
                        )

                        if spell.overhealing > max then
                            max = spell.overhealing
                        end

                        nr = nr + 1
                    end
                end
            end

            win.metadata.maxvalue = max
        end

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["%s's overhealed players"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid, self.playername)
            local max = 0

            if player then
                local nr = 1

                for targetname, target in _pairs(player.healing.targets) do
                    local overhealed = target.overhealing or 0
                    if overhealed > 0 then
                        local total = target.amount + overhealed
                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = target.id
                        d.label = targetname

                        local p = Skada:find_player(set, target.id, targetname)
                        if p then
                            d.class = p.class
                            d.role = p.role
                            d.spec = p.spec
                        else
                            d.class = Skada:GetPetOwner(target.id) and "PET" or "UNKNOWN"
                        end

                        d.value = overhealed
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(overhealed),
                            mod.metadata.columns.Overheal,
                            _format("%02.1f%%", 100 * overhealed / math_max(1, total)),
                            mod.metadata.columns.Percent
                        )

                        if overhealed > max then
                            max = overhealed
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
                if player.healing.overhealing > 0 then
                    local total = player.healing.amount + player.healing.overhealing
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
                        _format("%02.1f%%", 100 * player.healing.overhealing / math_max(1, total)),
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
            playermod.metadata = {}
            spellmod.metadata = {}
            self.metadata = {
                showspots = true,
                click1 = spellmod,
                click2 = playermod,
                columns = {Overheal = true, Percent = true}
            }
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

-- ==================== --
-- Total healing module --
-- ==================== --

Skada:AddLoadableModule(
    "Total healing",
    function(Skada, L)
        if Skada:IsDisabled("Healing", "Total healing") then
            return
        end
        local mod = Skada:NewModule(L["Total healing"])
        local playermod = mod:NewModule(L["Healed player list"])
        local spellmod = mod:NewModule(L["Healing spell list"])

        local function getHPS(set, player)
            local totaltime = Skada:PlayerActiveTime(set, player)
            local amount = (player.healing.amount or 0) + (player.healing.overhealing or 0)
            return amount / math_max(1, totaltime)
        end

        local function getRaidHPS(set)
            local amount = (set.healing or 0) + (set.overhealing or 0)
            if set.time > 0 then
                return amount / math_max(1, set.time)
            else
                local endtime = set.endtime or _time()
                return amount / math_max(1, endtime - set.starttime)
            end
        end

        function spellmod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["%s's healing spells"], label)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid, self.playername)
            local max = 0

            if player then
                local total = (player.healing.amount or 0) + (player.healing.overhealing or 0)
                local nr = 1
                for spellid, spell in _pairs(player.healing.spells) do
                    local amount = (spell.amount or 0) + (spell.overhealing or 0)
                    if amount > 0 then
                        local spellname, _, spellicon = _GetSpellInfo(spellid)

                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = spellid
                        d.icon = spellicon
                        d.spellid = spellid
                        d.label = spellname
                        d.spellschool = spell.school

                        d.value = amount
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(amount),
                            mod.metadata.columns.Healing,
                            _format("%02.1f%%", 100 * amount / total),
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

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["%s's healed players"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid, self.playername)
            local max = 0

            if player then
                local total = (player.healing.amount or 0) + (player.healing.overhealing or 0)
                local nr = 1
                for targetname, target in _pairs(player.healing.targets) do
                    local amount = (target.amount or 0) + (target.overhealing or 0)
                    if amount > 0 then
                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = target.id
                        d.label = targetname

                        local p = Skada:find_player(set, target.id, targetname)
                        if p then
                            d.class = p.class
                            d.role = p.role
                            d.spec = p.spec
                        else
                            d.class = Skada:GetPetOwner(target.id) and "PET" or "UNKNOWN"
                        end

                        d.value = amount
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(amount),
                            mod.metadata.columns.Healing,
                            _format("%02.1f%%", 100 * amount / total),
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
            local max = 0

            local total = (set.healing or 0) + (set.overhealing or 0)
            if total > 0 then
                local nr = 1

                for i, player in _ipairs(set.players) do
                    local amount = (player.healing.amount or 0) + (player.healing.overhealing or 0)
                    if amount > 0 then
                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = player.id
                        d.label = player.name
                        d.class = player.class
                        d.role = player.role
                        d.spec = player.spec

                        d.value = amount
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(amount),
                            self.metadata.columns.Healing,
                            Skada:FormatNumber(getHPS(set, player)),
                            self.metadata.columns.HPS,
                            _format("%02.1f%%", 100 * amount / total),
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
            spellmod.metadata = {}
            playermod.metadata = {showspots = true}
            self.metadata = {
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

        function mod:GetSetSummary(set)
            local amount = (set.healing or 0) + (set.overhealing or 0)
            return Skada:FormatValueText(
                Skada:FormatNumber(amount),
                self.metadata.columns.Healing,
                Skada:FormatNumber(getRaidHPS(set)),
                self.metadata.columns.HPS
            )
        end
    end
)


-- ============================== --
-- Healing and overhealing module --
-- ============================== --

Skada:AddLoadableModule(
    "Healing and Overhealing",
    function(Skada, L)
        if Skada:IsDisabled("Healing", "Healing and Overhealing") then
            return
        end
        local mod = Skada:NewModule(L["Healing and Overhealing"])
        local spellsmod = mod:NewModule(L["Healing and overhealing spells"])
        local playersmod = mod:NewModule(L["Healed and overhealed players"])

        function spellsmod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["%s's healing and overhealing spells"], label)
        end

        function spellsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid, self.playername)
            local max = 0

            if player then
                local nr = 1
                local total = (player.healing.amount or 0) + (player.healing.overhealing or 0)

                for spellid, spell in _pairs(player.healing.spells) do
                    local amount = spell.amount + spell.overhealing
                    if amount > 0 then
                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        local spellname, _, spellicon = _GetSpellInfo(spellid)

                        d.id = spellid
                        d.spellid = spellid
                        d.label = spellname
                        d.icon = spellicon
                        d.spellschool = spell.school

                        d.value = amount
                        d.valuetext =
                            Skada:FormatValueText(
                            Skada:FormatNumber(spell.amount),
                            mod.metadata.columns.Healing,
                            Skada:FormatNumber(spell.overhealing),
                            mod.metadata.columns.Overheal,
                            _format("%02.1f%%", 100 * spell.overhealing / amount),
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

        function playersmod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["%s's healed and overhealed players"], label)
        end

        function playersmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid, self.playername)
            local max = 0

            if player then
                local nr = 1
                for targetname, target in _pairs(player.healing.targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname

                    local p = Skada:find_player(set, target.id, targetname)
                    if p then
                        d.class = p.class
                        d.spec = p.spec
                        d.role = p.role
                    else
                        d.class = Skada:GetPetOwner(target.id) and "PET" or "UNKNOWN"
                    end

                    d.value = target.amount + target.overhealing
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(target.amount),
                        mod.metadata.columns.Healing,
                        Skada:FormatNumber(target.overhealing),
                        mod.metadata.columns.Overheal,
                        _format("%02.1f%%", 100 * target.overhealing / d.value),
                        mod.metadata.columns.Percent
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
                local total = (player.healing.amount or 0) + (player.healing.overhealing or 0)
                if total > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = total
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.healing.amount),
                        self.metadata.columns.Healing,
                        Skada:FormatNumber(player.healing.overhealing),
                        self.metadata.columns.Overheal,
                        _format("%02.1f%%", 100 * player.healing.overhealing / total),
                        self.metadata.columns.Percent
                    )

                    if total > max then
                        max = total
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            playersmod.metadata = {}
            spellsmod.metadata = {}
            mod.metadata = {
                showspots = true,
                click1 = spellsmod,
                click2 = playersmod,
                columns = {Healing = true, Overheal = true, Percent = true}
            }
            Skada:AddMode(self, L["Absorbs and healing"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:GetSetSummary(set)
            return Skada:FormatValueText(
                Skada:FormatNumber(set.healing),
                self.metadata.columns.Healing,
                Skada:FormatNumber(set.overhealing),
                self.metadata.columns.Overheal,
                _format("%02.1f%%", 100 * set.overhealing / math_max(1, set.healing + set.overhealing)),
                self.metadata.columns.Percent
            )
        end
    end
)