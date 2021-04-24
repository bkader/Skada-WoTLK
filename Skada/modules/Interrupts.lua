assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Interrupts", function(Skada, L)
    if Skada:IsDisabled("Interrupts") then return end

    local mod = Skada:NewModule(L["Interrupts"])
    local spellsmod = mod:NewModule(L["Interrupted spells"])
    local targetsmod = mod:NewModule(L["Interrupted targets"])
    local playermod = mod:NewModule(L["Interrupt spells"])
    local playerGUID

    -- cache frequently used globals
    local _pairs, _ipairs = pairs, ipairs
    local _format, math_max = string.format, math.max
    local _GetSpellInfo = Skada.GetSpellInfo
    local _UnitGUID = UnitGUID
    local _GetSpellLink = GetSpellLink
    local _IsInInstance = IsInInstance
    local _SendChatMessage = SendChatMessage

    local function log_interrupt(set, data)
        local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
        if player then
            -- increment player's and set's interrupts count
            player.interrupts = player.interrupts or {}
            player.interrupts.count = (player.interrupts.count or 0) + 1
            set.interrupts = (set.interrupts or 0) + 1

            -- add the interrupted spell
            if data.spellid then
                player.interrupts.spells = player.interrupts.spells or {}
                if not player.interrupts.spells[data.spellid] then
                    player.interrupts.spells[data.spellid] = {school = data.spellschool, count = 1}
                else
                    player.interrupts.spells[data.spellid].count = player.interrupts.spells[data.spellid].count + 1
                end
            end

            -- add the interrupt spell
            if data.extraspellid then
                player.interrupts.extraspells = player.interrupts.extraspells or {}
                if not player.interrupts.extraspells[data.extraspellid] then
                    player.interrupts.extraspells[data.extraspellid] = {school = data.extraspellschool, count = 1}
                else
                    player.interrupts.extraspells[data.extraspellid].count = player.interrupts.extraspells[data.extraspellid].count + 1
                end
            end

            -- add the interrupted target
            if data.dstName then
                player.interrupts.targets = player.interrupts.targets or {}
                if not player.interrupts.targets[data.dstName] then
                    player.interrupts.targets[data.dstName] = {id = data.dstGUID, count = 1}
                else
                    player.interrupts.targets[data.dstName].count = player.interrupts.targets[data.dstName].count + 1
                end
            end
        end
    end

    local data = {}

    local function SpellInterrupt(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        local spellid, spellname, spellschool, extraspellid, extraspellname, extraschool = ...

        data.playerid = srcGUID
        data.playername = srcName
        data.playerflags = srcFlags

        data.dstGUID = dstGUID
        data.dstName = dstName
        data.dstFlags = dstFlags

        data.spellid = spellid or 6603
        data.spellname = spellname or L["Auto Attack"]
        data.spellschool = spellschool or 1
        data.extraspellid = extraspellid
        data.extraspellname = extraspellname
        data.extraspellschool = extraschool

        Skada:FixPets(data)

        log_interrupt(Skada.current, data)
        log_interrupt(Skada.total, data)

        if srcGUID == playerGUID and (IsInGroup() or IsInRaid()) and Skada.db.profile.modules.interruptannounce then
            local spelllink = _GetSpellLink(extraspellid or extraspellname) or extraspellname

            local channel = Skada.db.profile.modules.interruptchannel or "SAY"
            if channel == "SELF" then
                Skada:Print(_format("%s interrupted!", extraspellname))
                return
            end

            if channel == "AUTO" then
                local zoneType = select(2, _IsInInstance())
                if zoneType == "pvp" or zoneType == "arena" then
                    channel = "BATTLEGROUND"
                elseif zoneType == "party" or zoneType == "raid" then
                    channel = zoneType:upper()
                end
            end

            _SendChatMessage(_format("%s interrupted!", spelllink), channel)
        end
    end

    function spellsmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's interrupted spells"], label)
    end

    function spellsmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid)
        local max = 0

        if player and player.interrupts.extraspells then
            win.title = _format(L["%s's interrupted spells"], player.name)

            local nr = 1
            for spellid, spell in _pairs(player.interrupts.extraspells) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                local spellname, _, spellicon = _GetSpellInfo(spellid)

                d.id = spellid
                d.spellid = spellid
                d.label = spellname
                d.icon = spellicon
                d.spellschool = spell.school

                d.value = spell.count
                d.valuetext = Skada:FormatValueText(
                    spell.count,
                    mod.metadata.columns.Total,
                    _format("%02.1f%%", 100 * spell.count / math_max(1, set.interrupts)),
                    mod.metadata.columns.Percent
                )

                if spell.count > max then
                    max = spell.count
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
    end

    function targetsmod:Enter(win, id, label)
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's interrupted targets"], label)
    end

    function targetsmod:Update(win, set)
        local player = Skada:find_player(set, win.playerid)
        local max = 1

        if player and player.interrupts.targets then
            win.title = _format(L["%s's interrupted targets"], player.name)

            local nr = 1
            for targetname, target in _pairs(player.interrupts.targets) do
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
                        target.class = "UNKNOWN"
                        target.role = "DAMAGER"
                        target.spec = 2
                    end
                end

                d.class = target.class
                d.role = target.role
                d.spec = target.spec

                d.value = target.count
                d.valuetext = Skada:FormatValueText(
                    target.count,
                    mod.metadata.columns.Total,
                    _format("%02.1f%%", 100 * target.count / math_max(1, set.interrupts or 0)),
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
        win.playerid, win.playername = id, label
        win.title = _format(L["%s's interrupt spells"], label)
    end

    function playermod:Update(win, set)
        local player = Skada:find_player(set, win.playerid)
        local max = 0

        if player and player.interrupts.spells then
            win.title = _format(L["%s's interrupt spells"], player.name)

            local nr = 1
            for spellid, spell in _pairs(player.interrupts.spells) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                local spellname, _, spellicon = _GetSpellInfo(spellid)

                d.id = spellid
                d.spellid = spellid
                d.label = spellname
                d.icon = spellicon
                d.spellschool = spell.school

                d.value = spell.count
                d.valuetext = Skada:FormatValueText(
                    spell.count,
                    mod.metadata.columns.Total,
                    _format("%02.1f%%", 100 * spell.count / math_max(1, set.interrupts or 0)),
                    mod.metadata.columns.Percent
                )

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
        for _, player in _ipairs(set.players) do
            if player.interrupts then
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = player.id
                d.label = player.name
                d.class = player.class or "PET"
                d.role = player.role or "DAMAGER"
                d.spec = player.spec or 1

                d.value = player.interrupts.count
                d.valuetext = Skada:FormatValueText(
                    player.interrupts.count,
                    self.metadata.columns.Total,
                    _format("%02.1f%%", 100 * player.interrupts.count / math_max(1, set.interrupts or 0)),
                    self.metadata.columns.Percent
                )

                if player.interrupts.count > max then
                    max = player.interrupts.count
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
        win.title = L["Interrupts"]
    end

    function mod:OnEnable()
        playerGUID = playerGUID or _UnitGUID("player")

        self.metadata = {
            showspots = true,
            click1 = spellsmod,
            click2 = targetsmod,
            click3 = playermod,
            columns = {Total = true, Percent = true}
        }

        Skada:RegisterForCL(SpellInterrupt, "SPELL_INTERRUPT", {src_is_interesting = true})

        Skada:AddMode(self)
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
    end

    function mod:AddToTooltip(set, tooltip)
        if set and set.interrupts and set.interrupts > 0 then
            tooltip:AddDoubleLine(L["Interrupts"], set.interrupts, 1, 1, 1)
        end
    end

    function mod:GetSetSummary(set)
        return set.interrupts or 0
    end

    local opts = {
        type = "group",
        name = L["Interrupts"],
        get = function(i)
            return Skada.db.profile.modules[i[#i]]
        end,
        set = function(i, val)
            Skada.db.profile.modules[i[#i]] = val
        end,
        args = {
            interruptannounce = {
                type = "toggle",
                name = L["Announce Interrupts"],
                order = 1,
                width = "double"
            },
            interruptchannel = {
                type = "select",
                name = L["Channel"],
                values = {AUTO = INSTANCE, SAY = CHAT_MSG_SAY, YELL = CHAT_MSG_YELL, SELF = L["Self"]},
                order = 2,
                width = "double"
            }
        }
    }

    function mod:OnInitialize()
        playerGUID = playerGUID or _UnitGUID("player")

        if not Skada.db.profile.modules.interruptchannel then
            Skada.db.profile.modules.interruptchannel = "SAY"
        end

        Skada.options.args.modules.args.interrupts = opts
    end
end)