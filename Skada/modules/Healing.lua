assert(Skada, "Skada not found!")

-- cache frequently used globals
local _pairs, _ipairs, _select = pairs, ipairs, select
local _format, math_max, math_min, _time = string.format, math.max, math.min, time
local _GetSpellInfo = Skada.GetSpellInfo

-- ============== --
-- Healing module --
-- ============== --

Skada:AddLoadableModule("Healing", function(Skada, L)
    if Skada:IsDisabled("Healing") then return end

    local mod = Skada:NewModule(L["Healing"])
    local playersmod = mod:NewModule(L["Healed player list"])
    local spellsmod = mod:NewModule(L["Healing spell list"])

    local function log_heal(set, data, tick)
        local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
        if player then
            -- get rid of overhealing
            local amount = math_max(0, data.amount - data.overhealing)

            -- record the healing
            player.healing = player.healing or {}
            player.healing.amount = (player.healing.amount or 0) + amount
            set.healing = (set.healing or 0) + amount

            -- record the overhealing
            player.healing.overhealing = (player.healing.overhealing or 0) + data.overhealing
            set.overhealing = (set.overhealing or 0) + data.overhealing

            -- record the target
            if data.dstName then
                player.healing.targets = player.healing.targets or {}
                if not player.healing.targets[data.dstName] then
                    player.healing.targets[data.dstName] = {
                        id = data.dstGUID,
                        amount = amount,
                        overhealing = data.overhealing or 0
                    }
                else
                    player.healing.targets[data.dstName].amount = player.healing.targets[data.dstName].amount + amount
                    player.healing.targets[data.dstName].overhealing = (player.healing.targets[data.dstName].overhealing or 0) + data.overhealing
                end
            end

            -- record the spell
            if data.spellid then
                player.healing.spells = player.healing.spells or {}
                if not player.healing.spells[data.spellid] then
                    player.healing.spells[data.spellid] = {
                        school = data.spellschool,
                        count = 0,
                        amount = 0,
                        overhealing = 0
                    }
                end

                local spell = player.healing.spells[data.spellid]
                spell.count = spell.count + 1
                spell.amount = spell.amount + amount
                spell.overhealing = spell.overhealing + data.overhealing

                if (not spell.min or amount < spell.min) and amount > 0 then
                    spell.min = amount
                end
                if (not spell.max or amount > spell.max) and amount > 0 then
                    spell.max = amount
                end

                if data.critical then
                    spell.critical = (spell.critical or 0) + 1
                end
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
        local totaltime = math_min(Skada:GetSetTime(set), Skada:PlayerActiveTime(set, player))
        local healing = player.healing and player.healing.amount or 0
        return healing / math_max(1, totaltime)
    end

    local function getRaidHPS(set)
        if set.time > 0 then
            return (set.healing or 0) / math_max(1, set.time)
        else
            local endtime = set.endtime or _time()
            return (set.healing or 0) / math_max(1, endtime - set.starttime)
        end
    end

    local function spell_tooltip(win, id, label, tooltip)
        local player = Skada:find_player(win:get_selected_set(), win.playerid)
        if player then
            local spell = player.healing.spells[id]
            if spell then
                tooltip:AddLine(player.name .. " - " .. label)
                if spell.school then
                    local c = Skada.schoolcolors[spell.school]
                    local n = Skada.schoolnames[spell.school]
                    if c and n then tooltip:AddLine(n, c.r, c.g, c.b) end
                end
                tooltip:AddDoubleLine(L["Total"], spell.count, 1, 1, 1)
                if spell.min and spell.max then
                    tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.min), 1, 1, 1)
                    tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.max), 1, 1, 1)
                end
                tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
                if spell.critical then
                    tooltip:AddDoubleLine(CRIT_ABBR, _format("%02.1f%%", 100 * spell.critical / math_max(1, spell.count)), 1, 1, 1)
                end
                if spell.overhealing > 0 then
                    tooltip:AddDoubleLine(L["Overhealing"], _format("%02.1f%%", 100 * spell.overhealing / math_max(1, spell.overhealing + spell.amount)), 1, 1, 1)
                end
            end
        end
    end

    function spellsmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's healing spells"], label)
    end

    function spellsmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.healing.spells then
            win.title = _format(L["%s's healing spells"], player.name)

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
                    d.valuetext = Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        mod.metadata.columns.Healing,
                        _format("%02.1f%%", 100 * spell.amount / math_max(1, player.healing.amount)),
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

    function playersmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's healed players"], label)
    end

    function playersmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.healing.targets then
            win.title = _format(L["%s's healed players"], player.name)

            local nr = 1
            for targetname, target in _pairs(player.healing.targets) do
                if target.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname

                    if not target.class then
                        local p = Skada:find_player(set, target.id, targetname)
                        if p then
                            target.class = p.class
                            target.role = p.role
                            target.spec = p.spec
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
                        mod.metadata.columns.Healing,
                        _format("%02.1f%%", 100 * target.amount / math_max(1, player.healing.amount)),
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

        for _, player in _ipairs(set.players) do
            if player.healing and player.healing.amount > 0 then
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class
                d.role = player.role
                d.spec = player.spec

                d.value = player.healing.amount
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(player.healing.amount),
                    self.metadata.columns.Healing,
                    Skada:FormatNumber(getHPS(set, player)),
                    self.metadata.columns.HPS,
                    _format("%02.1f%%", 100 * player.healing.amount / math_max(1, set.healing)),
                    self.metadata.columns.Percent
                )

                if player.healing.amount > max then
                    max = player.healing.amount
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Healing"]
    end

    function mod:OnEnable()
        spellsmod.metadata = {tooltip = spell_tooltip}
        playersmod.metadata = {showspots = true}
        self.metadata = {
            showspots = true,
            click1 = spellsmod,
            click2 = playersmod,
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
            Skada:FormatNumber(set.healing or 0),
            self.metadata.columns.Healing,
            Skada:FormatNumber(getRaidHPS(set)),
            self.metadata.columns.HPS
        )
    end
end)

-- ================== --
-- Overhealing module --
-- ================== --

Skada:AddLoadableModule("Overhealing", function(Skada, L)
    if Skada:IsDisabled("Healing", "Overhealing") then return end

    local mod = Skada:NewModule(L["Overhealing"])
    local playersmod = mod:NewModule(L["Overhealed player list"])
    local spellsmod = mod:NewModule(L["Overhealing spell list"])

    function spellsmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's overhealing spells"], label)
    end

    function spellsmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.healing.spells then
            win.title = _format(L["%s's overhealing spells"], player.name)

            local nr, total = 1, player.healing.overhealing or 0
            for spellid, spell in _pairs(player.healing.spells) do
                if spell.overhealing > 0 then
                    local spellname, _, spellicon = _GetSpellInfo(spellid)

                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = spellid
                    d.icon = spellicon
                    d.spellid = spellid
                    d.label = spellname
                    d.spellschool = spell.school

                    d.value = spell.overhealing
                    d.valuetext = Skada:FormatValueText(
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

    function playersmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's overhealed players"], label)
    end

    function playersmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.healing.targets then
            win.title = _format(L["%s's overhealed players"], player.name)

            local nr, total = 1, ((player.healing.amount or 0) + (player.healing.overhealing or 0))
            for targetname, target in _pairs(player.healing.targets) do
                local overhealed = target.overhealing or 0
                if overhealed > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname

                    if not target.class then
                        local p = Skada:find_player(set, target.id, targetname)
                        if p then
                            target.class = p.class
                            target.role = p.role
                            target.spec = p.spec
                        else
                            target.class = "PET"
                            target.role = "DAMAGER"
                            target.spec = 1
                        end
                    end

                    d.class = target.class
                    d.role = target.role
                    d.spec = target.spec

                    d.value = overhealed
                    d.valuetext = Skada:FormatValueText(
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
        local total = (set.healing or 0) + (set.overhealing or 0)
        local nr, max = 1, 0

        for _, player in _ipairs(set.players) do
            if player.healing and player.healing.overhealing > 0 then
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class
                d.role = player.role
                d.spec = player.spec

                d.value = player.healing.overhealing
                d.valuetext = Skada:FormatValueText(
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
        win.title = L["Overhealing"]
    end

    function mod:OnEnable()
        playersmod.metadata = {showspots = true}
        self.metadata = {
            showspots = true,
            click1 = spellsmod,
            click2 = playersmod,
            columns = {Overheal = true, Percent = true}
        }
        Skada:AddMode(self, L["Absorbs and healing"])
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
    end

    function mod:GetSetSummary(set)
        return Skada:FormatNumber(set.overhealing or 0)
    end
end)

-- ==================== --
-- Total healing module --
-- ==================== --

Skada:AddLoadableModule("Total healing", function(Skada, L)
    if Skada:IsDisabled("Healing", "Total healing") then
        return
    end

    local mod = Skada:NewModule(L["Total healing"])
    local playersmod = mod:NewModule(L["Healed player list"])
    local spellsmod = mod:NewModule(L["Healing spell list"])

    local function getHPS(set, player)
        local totaltime = math_min(Skada:GetSetTime(set), Skada:PlayerActiveTime(set, player))
        local amount = 0
        if player.healing then
            amount = (player.healing.amount or 0) + (player.healing.overhealing or 0)
        end
        return amount / math_max(1, totaltime)
    end

    local function getRaidHPS(set)
        local amount = (set.healing or 0) + (set.overhealing or 0)
        if set.time > 0 then
            return amount / math_max(1, set.time)
        else
            return amount / math_max(1, (set.endtime or _time()) - set.starttime)
        end
    end

    local function spell_tooltip(win, id, label, tooltip)
        local player = Skada:find_player(win:get_selected_set(), win.playerid)
        if player then
            local spell = player.healing.spells[id]
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
                    tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.amount / spell.count), 1, 1, 1)
                    tooltip:AddLine(" ")
                end
                tooltip:AddDoubleLine(L["Total"], Skada:FormatNumber(spell.amount + spell.overhealing), 1, 1, 1)
                tooltip:AddDoubleLine(L["Healing"], Skada:FormatNumber(spell.amount), 1, 1, 1)
                tooltip:AddDoubleLine(L["Overhealing"], Skada:FormatNumber(spell.overhealing), 1, 1, 1)
                tooltip:AddDoubleLine(L["Overheal"], _format("%02.1f%%", 100 * spell.overhealing / math_max(1, spell.overhealing + spell.amount)), 1, 1, 1)
            end
        end
    end

    function spellsmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's healing spells"], label)
    end

    function spellsmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.healing.spells then
            win.title = _format(L["%s's healing spells"], player.name)

            local nr, total = 1, ((player.healing.amount or 0) + (player.healing.overhealing or 0))
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
                    d.valuetext = Skada:FormatValueText(
                        Skada:FormatNumber(amount),
                        mod.metadata.columns.Healing,
                        _format("%02.1f%%", 100 * amount / math_max(1, total)),
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
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's healed players"], label)
    end

    function playersmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.healing.targets then
            win.title = _format(L["%s's healed players"], player.name)

            local nr, total = 1, ((player.healing.amount or 0) + (player.healing.overhealing or 0))
            for targetname, target in _pairs(player.healing.targets) do
                local amount = (target.amount or 0) + (target.overhealing or 0)
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = target.id
                d.label = targetname

                if not target.class then
                    local p = Skada:find_player(set, target.id, targetname)
                    if p then
                        target.class = p.class
                        target.role = p.role
                        target.spec = p.spec
                    else
                        target.class = "PET"
                        target.role = "DAMAGER"
                        target.spec = 1
                    end
                end

                d.class = target.class
                d.role = target.role
                d.spec = target.spec

                d.value = amount
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(amount),
                    mod.metadata.columns.Healing,
                    _format("%02.1f%%", 100 * amount / math_max(1, total)),
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
        local total = (set.healing or 0) + (set.overhealing or 0)
        local nr, max = 1, 0

        for _, player in _ipairs(set.players) do
            if player.healing then
                local amount = (player.healing.amount or 0) + (player.healing.overhealing or 0)
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class
                d.role = player.role
                d.spec = player.spec

                d.value = amount
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(amount),
                    self.metadata.columns.Healing,
                    Skada:FormatNumber(getHPS(set, player)),
                    self.metadata.columns.HPS,
                    _format("%02.1f%%", 100 * amount / math_max(1, total)),
                    self.metadata.columns.Percent
                )

                if amount > max then
                    max = amount
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Total healing"]
    end

    function mod:OnEnable()
        playersmod.metadata = {showspots = true}
        spellsmod.metadata = {tooltip = spell_tooltip}
        self.metadata = {
            showspots = true,
            click1 = spellsmod,
            click2 = playersmod,
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
end)

-- ============================== --
-- Healing and overhealing module --
-- ============================== --

Skada:AddLoadableModule("Healing and Overhealing", function(Skada, L)
    if Skada:IsDisabled("Healing", "Healing and Overhealing") then
        return
    end

    local mod = Skada:NewModule(L["Healing and Overhealing"])
    local spellsmod = mod:NewModule(L["Healing and overhealing spells"])
    local playersmod = mod:NewModule(L["Healed and overhealed players"])

    function spellsmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's healing and overhealing spells"], label)
    end

    function spellsmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.healing.spells then
            win.title = _format(L["%s's healing and overhealing spells"], player.name)

            local nr, total = 1, ((player.healing.amount or 0) + (player.healing.overhealing or 0))
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
                    d.valuetext = Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        mod.metadata.columns.Healing,
                        Skada:FormatNumber(spell.overhealing),
                        mod.metadata.columns.Overheal,
                        _format("%02.1f%%", 100 * spell.overhealing / math_max(1, amount)),
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
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's healed and overhealed players"], label)
    end

    function playersmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.healing.targets then
            win.title = _format(L["%s's healed and overhealed players"], player.name)

            local nr = 1
            for targetname, target in _pairs(player.healing.targets) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = target.id
                d.label = targetname

                if not target.class then
                    local p = Skada:find_player(set, target.id, targetname)
                    if p then
                        target.class = p.class
                        target.role = p.role
                        target.spec = p.spec
                    else
                        target.class = "PET"
                        target.role = "DAMAGER"
                        target.spec = 1
                    end
                end

                d.class = target.class
                d.role = target.role
                d.spec = target.spec

                d.value = target.amount + target.overhealing
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(target.amount),
                    mod.metadata.columns.Healing,
                    Skada:FormatNumber(target.overhealing),
                    mod.metadata.columns.Overheal,
                    _format("%02.1f%%", 100 * target.overhealing / math_max(1, d.value)),
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

        for _, player in _ipairs(set.players) do
            if player.healing then
                local total = (player.healing.amount or 0) + (player.healing.overhealing or 0)
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class
                d.role = player.role
                d.spec = player.spec

                d.value = total
                d.valuetext = Skada:FormatValueText(
                    Skada:FormatNumber(player.healing.amount),
                    self.metadata.columns.Healing,
                    Skada:FormatNumber(player.healing.overhealing),
                    self.metadata.columns.Overheal,
                    _format("%02.1f%%", 100 * player.healing.overhealing / math_max(1, total)),
                    self.metadata.columns.Percent
                )

                if total > max then
                    max = total
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Healing and Overhealing"]
    end

    function mod:OnEnable()
        playersmod.metadata = {showspots = true}
        self.metadata = {
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
        local healing = set.healing or 0
        local overhealing = set.overhealing or 0
        return Skada:FormatValueText(
            Skada:FormatNumber(healing),
            self.metadata.columns.Healing,
            Skada:FormatNumber(overhealing),
            self.metadata.columns.Overheal,
            _format("%02.1f%%", 100 * overhealing / math_max(1, healing + overhealing)),
            self.metadata.columns.Percent
        )
    end
end)

-- ================ --
-- Healing received --
-- ================ --

Skada:AddLoadableModule("Healing received", function(Skada, L)
    if Skada:IsDisabled("Healing", "Healing received") then
        return
    end

    local mod = Skada:NewModule(L["Healing received"])
    local playermod = mod:NewModule(L["Healing player list"])

    function playermod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's received healing"], label)
    end

    function playermod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        if player then
            win.title = _format(L["%s's received healing"], player.name)

            local max, total, sources = 0, 0, {}

            for _, p in _ipairs(set.players) do
                if p.healing then
                    for targetname, target in _pairs(p.healing.targets) do
                        if target.id == player.id and targetname == player.name then
                            total = total + target.amount -- increment total
                            sources[p.name] = {
                                id = p.id,
                                class = p.class,
                                role = p.role,
                                spec = p.spec,
                                amount = target.amount,
                                overhealing = target.overhealing
                            }
                            break
                        end
                    end
                end
            end

            if total > 0 and win then
                local nr = 1

                for sourcename, source in _pairs(sources) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = source.id
                    d.label = sourcename
                    d.class = source.class
                    d.role = source.role
                    d.spec = source.spec

                    d.value = source.amount
                    d.valuetext = Skada:FormatValueText(
                        Skada:FormatNumber(source.amount),
                        mod.metadata.columns.Healing,
                        Skada:FormatNumber(source.overhealing),
                        mod.metadata.columns.Overhealing,
                        _format("%02.1f%%", 100 * source.amount / math_max(1, total)),
                        mod.metadata.columns.Percent
                    )

                    if source.amount > max then
                        max = source.amount
                    end

                    nr = nr + 1
                end

                win.metadata.maxvalue = max
            end
        end
    end

    function mod:Update(win, set)
        local max = 0
        if set.healing and set.healing > 0 then
            local players = {}

            for _, player in _ipairs(set.players) do
                if player.healing then
                    for targetname, target in _pairs(player.healing.targets) do
                        if not target.class then
                            local p = Skada:find_player(set, target.id, targetname)
                            if p then
                                target.class = p.class
                                target.role = p.role
                                target.spec = p.spec
                            else
                                target.class = "PET"
                                target.role = "DAMAGER"
                                target.spec = 1
                            end
                        end

                        if not players[targetname] then
                            players[targetname] = CopyTable(target)
                        else
                            players[targetname].amount = players[targetname].amount + target.amount
                            players[targetname].overhealing = players[targetname].overhealing + target.overhealing
                        end
                    end
                end
            end

            if win then
                local nr = 1

                for playername, player in _pairs(players) do
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
                        mod.metadata.columns.Healing,
                        Skada:FormatNumber(player.overhealing),
                        mod.metadata.columns.Overhealing,
                        _format("%02.1f%%", 100 * player.amount / math_max(1, set.healing or 0)),
                        mod.metadata.columns.Percent
                    )

                    if player.amount > max then
                        max = player.amount
                    end

                    nr = nr + 1
                end
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Healing received"]
    end

    function mod:OnEnable()
        playermod.metadata = {showspots = true}
        self.metadata = {
            showspots = true,
            click1 = playermod,
            columns = {Healing = true, Overhealing = true, Percent = true}
        }
        Skada:AddMode(self, L["Absorbs and healing"])
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
    end
end)