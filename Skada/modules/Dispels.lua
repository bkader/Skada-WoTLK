local Skada = Skada
if not Skada then
    return
end

Skada:AddLoadableModule(
    "Dispels",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Dispels") then
            return
        end

        local mod = Skada:NewModule(L["Dispels"])
        local spellsmod = mod:NewModule(L["Dispelled spell list"])
        local targetsmod = mod:NewModule(L["Dispelled target list"])
        local playermod = mod:NewModule(L["Dispel spell list"])

        local format, tostring = string.format, tostring
        local pairs, ipairs, select = pairs, ipairs, select
        local GetSpellInfo = GetSpellInfo

        local function log_dispels(set, data)
            local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
            if not player then
                return
            end

            player.dispels.count = player.dispels.count + 1

            if not player.dispels.spells[data.spellid] then
                player.dispels.spells[data.spellid] = {school = data.spellschool, count = 0}
            end
            player.dispels.spells[data.spellid].count = player.dispels.spells[data.spellid].count + 1

            if not player.dispels.extraspells[data.extraspellid] then
                player.dispels.extraspells[data.extraspellid] = {school = data.extraspellschool, count = 0}
            end
            player.dispels.extraspells[data.extraspellid].count =
                player.dispels.extraspells[data.extraspellid].count + 1

            if not player.dispels.targets[data.dstName] then
                player.dispels.targets[data.dstName] = {
                    id = data.dstGUID,
                    class = select(2, UnitClass(data.dstName)),
                    count = 0
                }
            end
            player.dispels.targets[data.dstName].count = player.dispels.targets[data.dstName].count + 1

            set.dispels = set.dispels + 1
        end

        local data = {}

        local function SpellDispel(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if eventtype == "SPELL_DISPEL_FAILED" then
                return
            end

            -- Dispells
            local spellid, spellname, spellschool, extraspellid, extraspellname, extraspellschool, auraType = ...

            data.playerid = srcGUID
            data.playername = srcName
            data.playerflags = srcFlags

            data.dstGUID = dstGUID
            data.dstName = dstName
            data.dstFlags = dstFlags

            data.spellid = spellid
            data.spellname = spellname
            data.spellschool = spellschool

            data.extraspellid = extraspellid or 6603
            data.extraspellname = extraspellname or MELEE
            data.extraspellschool = extraspellschool or 1

            log_dispels(Skada.current, data)
            log_dispels(Skada.total, data)
        end

        function spellsmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's dispelled spells"], label)
        end

        function spellsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player and player.dispels.extraspells then
                local nr = 1

                for spellid, spell in pairs(player.dispels.extraspells) do
                    local spellname, _, spellicon = GetSpellInfo(spellid)

                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = spellid
                    d.spellid = spellid
                    d.label = spellname
                    d.icon = spellicon
                    d.spellschool = spell.school

                    d.value = spell.count
                    d.valuetext =
                        Skada:FormatValueText(
                        spell.count,
                        mod.metadata.columns.Total,
                        format("%02.1f%%", spell.count / math.max(1, set.dispels) * 100),
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
            self.playerid = id
            self.title = format(L["%s's dispelled targets"], label)
        end

        function targetsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 1

            if player and player.dispels.targets then
                local nr = 1
                for targetname, target in pairs(player.dispels.targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname
                    d.value = target.count
                    d.valuetext =
                        Skada:FormatValueText(
                        target.count,
                        mod.metadata.columns.Total,
                        format("%02.1f%%", target.count / math.max(1, set.dispels) * 100),
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
            self.playerid = id
            self.title = format(L["%s's dispel spells"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player and player.dispels.spells then
                local nr = 1

                for spellid, spell in pairs(player.dispels.spells) do
                    local spellname, _, spellicon = GetSpellInfo(spellid)

                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = spellid
                    d.spellid = spellid
                    d.label = spellname
                    d.icon = spellicon
                    d.spellschool = spell.school

                    d.value = spell.count
                    d.valuetext =
                        Skada:FormatValueText(
                        spell.count,
                        mod.metadata.columns.Total,
                        format("%02.1f%%", spell.count / math.max(1, set.dispels) * 100),
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
            for i, player in ipairs(set.players) do
                if player.dispels.count > 0 then
                    local count = player.dispels.count

                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role

                    d.value = count
                    d.valuetext =
                        Skada:FormatValueText(
                        count,
                        self.metadata.columns.Total,
                        format("%02.1f%%", count / math.max(1, set.dispels) * 100),
                        self.metadata.columns.Percent
                    )

                    if count > max then
                        max = count
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            spellsmod.metadata = {}
            targetsmod.metadata = {showspots = true}
            playermod.metadata = {showspots = true}
            mod.metadata = {
                showspots = true,
                click1 = spellsmod,
                click2 = targetsmod,
                click3 = playermod,
                columns = {Total = true, Percent = true}
            }

            Skada:RegisterForCL(SpellDispel, "SPELL_DISPEL", {src_is_interesting = true})
            Skada:RegisterForCL(SpellDispel, "SPELL_STOLEN", {src_is_interesting = true})

            Skada:AddMode(self)
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddToTooltip(set, tooltip)
            if set.dispels > 0 then
                tooltip:AddDoubleLine(L["Dispels"], set.dispels, 1, 1, 1)
            end
        end

        function mod:AddPlayerAttributes(player)
            if not player.dispels then
                player.dispels = {count = 0, spells = {}, extraspells = {}, targets = {}}
            end
        end

        function mod:AddSetAttributes(set)
            set.dispels = set.dispels or 0
        end

        function mod:GetSetSummary(set)
            return set.dispels
        end

        function mod:SetComplete(set)
            for i, player in ipairs(set.players) do
                if player.dispels.count == 0 then
                    player.dispels.spells = nil
                    player.dispels.extraspells = nil
                    player.dispels.targets = nil
                end
            end
        end
    end
)