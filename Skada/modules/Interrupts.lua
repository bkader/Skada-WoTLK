local Skada = Skada
if not Skada then
    return
end
Skada:AddLoadableModule(
    "Interrupts",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Interrupts") then
            return
        end

        local mod = Skada:NewModule(L["Interrupts"])
        local spellsmod = mod:NewModule(L["Interrupted spells"])
        local targetsmod = mod:NewModule(L["Interrupted targets"])
        local playermod = mod:NewModule(L["Interrupt spells"])

        local select, tostring, format = select, tostring, string.format
        local pairs, ipairs = pairs, ipairs
        local GetSpellInfo = GetSpellInfo

        local function log_interrupt(set, data)
            local player = Skada:find_player(set, data.playerid, data.playername)
            if not player then
                return
            end

            player.interrupts.count = player.interrupts.count + 1

            -- own spell details
            if not player.interrupts.spells[data.spellname] then
                player.interrupts.spells[data.spellname] = {id = data.spellid, count = 0}
            end
            player.interrupts.spells[data.spellname].count = player.interrupts.spells[data.spellname].count + 1

            -- extra spell details
            if not player.interrupts.extraspells[data.extraspellname] then
                player.interrupts.extraspells[data.extraspellname] = {id = data.extraspellid, count = 0}
            end
            player.interrupts.extraspells[data.extraspellname].count =
                player.interrupts.extraspells[data.extraspellname].count + 1

            -- target details
            if not player.interrupts.targets[data.dstName] then
                player.interrupts.targets[data.dstName] = {id = data.dstGUID, count = 0}
            end
            player.interrupts.targets[data.dstName].count = player.interrupts.targets[data.dstName].count + 1

            set.interrupts = set.interrupts + 1
        end

        local data = {}

        local function SpellInterrupt(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            -- Interrupts
            local spellid, spellname, spellschool, extraspellid, extraspellname, extraschool = ...

            data.srcGUID = srcGUID
            data.srcName = srcName
            data.srcFlags = srcFlags
            data.dstGUID = dstGUID
            data.dstName = dstName
            data.dstFlags = dstFlags
            data.spellid = spellid
            data.spellname = spellname
            data.extraspellid = extraspellid
            data.extraspellname = extraspellname

            Skada:FixPets(data)

            log_interrupt(Skada.current, data)
            log_interrupt(Skada.total, data)
        end

        function spellsmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's interrupted spells"], label)
        end

        function spellsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for spellname, spell in pairs(player.interrupts.extraspells) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = spellname
                    d.label = spellname
                    d.icon = select(3, GetSpellInfo(spell.id))
                    d.spellid = spell.id
                    d.value = spell.count
                    d.valuetext = tostring(spell.count)

                    if spell.count > max then
                        max = spell.count
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function targetsmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's interrupted targets"], label)
        end

        function targetsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 1

            if player then
                local nr = 1
                for targetname, target in pairs(player.interrupts.targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname
                    d.value = target.count
                    d.valuetext = tostring(target.count)

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
            self.title = format(L["%s's interrupt spells"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for spellname, spell in pairs(player.interrupts.spells) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = spellname
                    d.label = spellname
                    d.icon = select(3, GetSpellInfo(spell.id))
                    d.spellid = spell.id
                    d.value = spell.count
                    d.valuetext = tostring(spell.count)

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
            for i, player in ipairs(set.players) do
                if player.interrupts.count > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role

                    d.value = player.interrupts.count
                    d.valuetext = tostring(player.interrupts.count)
                    if player.interrupts.count > max then
                        max = player.interrupts.count
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            spellsmod.metadata = {}
            targetsmod.metadata = {}
            playermod.metadata = {}
            mod.metadata = {showspots = true, click1 = spellsmod, click2 = targetsmod, click3 = playermod}

            Skada:RegisterForCL(SpellInterrupt, "SPELL_INTERRUPT", {src_is_interesting = true})

            Skada:AddMode(self)
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddToTooltip(set, tooltip)
            GameTooltip:AddDoubleLine(L["Interrupts"], set.interrupts, 1, 1, 1)
        end

        function mod:GetSetSummary(set)
            return set.interrupts
        end

        -- Called by Skada when a new player is added to a set.
        function mod:AddPlayerAttributes(player)
            if not player.interrupts then
                player.interrupts = {count = 0, spells = {}, extraspells = {}, targets = {}}
            end
        end

        -- Called by Skada when a new set is created.
        function mod:AddSetAttributes(set)
            set.interrupts = set.interrupts or 0
        end

        function mod:SetComplete(set)
            for i, player in ipairs(set.players) do
                if player.interrupts.count == 0 then
                    player.interrupts.spells = nil
                    player.interrupts.extraspells = nil
                    player.interrupts.targets = nil
                end
            end
        end
    end
)