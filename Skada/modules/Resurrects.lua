assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Resurrects", function(Skada, L)
    if Skada:IsDisabled("Resurrects") then return end

    local mod = Skada:NewModule(L["Resurrects"])
    local spellsmod = mod:NewModule(L["Resurrect spell list"])
    local spelltargetsmod = mod:NewModule(L["Resurrect spell target list"])
    local targetsmod = mod:NewModule(L["Resurrect target list"])
    local targetspellsmod = mod:NewModule(L["Resurrect target spell list"])

    local _select, _pairs, _ipairs = select, pairs, ipairs
    local _tostring, _format = tostring, string.format
    local _GetSpellInfo = Skada.GetSpellInfo

    local function log_resurrect(set, data)
        local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
        if player then
            player.resurrect = player.resurrect or {}
            player.resurrect.count = (player.resurrect.count or 0) + 1
            set.resurrect = (set.resurrect or 0) + 1

            -- details about spells and their targets.
            player.resurrect.spells = player.resurrect.spells or {}
            if not player.resurrect.spells[data.spellid] then
                player.resurrect.spells[data.spellid] = {count = 1, school = data.spellschool, targets = {}}
            else
                player.resurrect.spells[data.spellid].count = player.resurrect.spells[data.spellid].count + 1
            end
            if not player.resurrect.spells[data.spellid].targets[data.dstName] then
                player.resurrect.spells[data.spellid].targets[data.dstName] = {id = data.dstGUID, count = 1}
            else
                player.resurrect.spells[data.spellid].targets[data.dstName].count = player.resurrect.spells[data.spellid].targets[data.dstName].count + 1
            end

            -- details about resurrected players and spells used on them
            player.resurrect.targets = player.resurrect.targets or {}
            if not player.resurrect.targets[data.dstName] then
                player.resurrect.targets[data.dstName] = {id = data.dstGUID, count = 1, spells = {}}
            else
                player.resurrect.targets[data.dstName].count = player.resurrect.targets[data.dstName].count + 1
            end
            if not player.resurrect.targets[data.dstName].spells[data.spellid] then
                player.resurrect.targets[data.dstName].spells[data.spellid] = {id = data.spellid, count = 1}
            else
                player.resurrect.targets[data.dstName].spells[data.spellid].count = player.resurrect.targets[data.dstName].spells[data.spellid].count + 1
            end
        end
    end

    local data = {}

    local function SpellResurrect(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        local spellid, spellname, spellschool = ...

        data.playerid = srcGUID
        data.playername = srcName
        data.playerflags = srcFlags

        data.dstGUID = dstGUID
        data.dstName = dstName
        data.dstFlags = dstFlags

        data.spellid = spellid
        data.spellname = spellname
        data.spellschool = spellschool

        log_resurrect(Skada.current, data)
        log_resurrect(Skada.total, data)
    end

    function spellsmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's resurrect spells"], label)
    end

    function spellsmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.resurrect.spells then
            win.title = _format(L["%s's resurrect spells"], player.name)

            local nr = 1
            for spellid, spell in _pairs(player.resurrect.spells) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                local spellname, _, spellicon = _GetSpellInfo(spellid)

                d.id = spellid
                d.spellid = spellid
                d.label = spellname
                d.icon = spellicon

                d.value = spell.count
                d.valuetext = _tostring(spell.count)

                if spell.count > max then
                    max = spell.count
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
    end

    function spelltargetsmod:Enter(win, id, label)
        win.spellid, win.spellname = id, label
        win.title = _format(L["%s's resurrect <%s> targets"], win.playername or UNKNOWN, label)
    end

    function spelltargetsmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and win.spellid and player.resurrect.spells[win.spellid] then
            win.title = _format(L["%s's resurrect <%s> targets"], player.name, win.spellname)

            local nr = 1
            for targetname, target in _pairs(player.resurrect.spells[win.spellid].targets) do
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

                d.value = target.count
                d.valuetext = _tostring(target.count)

                if target.count > max then
                    max = target.count
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
    end

    function targetsmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's resurrect targets"], label)
    end

    function targetsmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and player.resurrect.targets then
            win.title = _format(L["%s's resurrect targets"], player.name)

            local nr = 1
            for targetname, target in _pairs(player.resurrect.targets) do
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

                d.value = target.count
                d.valuetext = _tostring(target.count)

                if target.count > max then
                    max = target.count
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
    end

    function targetspellsmod:Enter(win, id, label)
        win.targetname = label
        win.title = _format(L["%s's received resurrects"], label)
    end

    function targetspellsmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid, win.playername)
        local max = 0

        if player and win.targetname and player.resurrect.targets[win.targetname] then
            win.title = _format(L["%s's received resurrects"], win.targetname)

            local nr = 1
            for spellid, spell in _pairs(player.resurrect.targets[win.targetname].spells) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                local spellname, _, spellicon = _GetSpellInfo(spellid)

                d.id = spellid
                d.spellid = spellid
                d.label = spellname
                d.icon = spellicon

                d.value = spell.count
                d.valuetext = _tostring(spell.count)

                if spell.count > max then
                    max = spell.count
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
    end

    function mod:Update(win, set)
        local nr, max = 1, 0

        for i, player in _ipairs(set.players) do
            if player.resurrect then
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class
                d.role = player.role
                d.spec = player.spec

                d.value = player.resurrect.count
                d.valuetext = _tostring(player.resurrect.count)

                if player.resurrect.count > max then
                    max = player.resurrect.count
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Resurrects"]
    end

    function mod:OnEnable()
        spellsmod.metadata = {click1 = spelltargetsmod}
        targetsmod.metadata = {click1 = targetspellsmod}
        self.metadata = {showspots = true, click1 = spellsmod, click2 = targetsmod}

        Skada:RegisterForCL(SpellResurrect, "SPELL_RESURRECT", {src_is_interesting = true, dst_is_interesting = true})

        Skada:AddMode(self)
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
    end

    function mod:AddToTooltip(set, tooltip)
        tooltip:AddDoubleLine(L["Resurrects"], set.resurrect or 0, 1, 1, 1)
    end

    function mod:GetSetSummary(set)
        return set.resurrect or 0
    end
end)