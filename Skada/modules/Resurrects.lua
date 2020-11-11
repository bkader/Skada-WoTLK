local Skada = Skada
if not Skada then
    return
end

Skada:AddLoadableModule(
    "Resurrects",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Resurrects") then
            return
        end

        local mod = Skada:NewModule(L["Resurrects"])
        local spellsmod = mod:NewModule(L["Resurrect spell list"])
        local spelltargetsmod = mod:NewModule(L["Resurrect spell target list"])
        local targetsmod = mod:NewModule(L["Resurrect target list"])
        local targetspellsmod = mod:NewModule(L["Resurrect target spell list"])

        local select, pairs, ipairs = select, pairs, ipairs
        local tostring, tonumber = tostring, tonumber
        local format = string.format
        local GetSpellInfo = GetSpellInfo
        local UnitClass = UnitClass

        local function log_resurrect(set, data, ts)
            local player = Skada:get_player(set, data.srcGUID, data.srcName, data.srcFlags)
            if player then
                player.resurrect.count = player.resurrect.count + 1
                set.resurrect = set.resurrect + 1

                if not player.resurrect.spells[data.spellid] then
                    player.resurrect.spells[data.spellid] = {count = 0, school = data.spellschool, targets = {}}
                end
                player.resurrect.spells[data.spellid].count = player.resurrect.spells[data.spellid].count + 1

                if not player.resurrect.spells[data.spellid].targets[data.dstName] then
                    player.resurrect.spells[data.spellid].targets[data.dstName] = {id = data.dstGUID, count = 0}
                end
                player.resurrect.spells[data.spellid].targets[data.dstName].count =
                    player.resurrect.spells[data.spellid].targets[data.dstName].count + 1

                if not player.resurrect.targets[data.dstName] then
                    player.resurrect.targets[data.dstName] = {id = data.dstGUID, count = 0, spells = {}}
                end
                player.resurrect.targets[data.dstName].count = player.resurrect.targets[data.dstName].count + 1

                if not player.resurrect.targets[data.dstName].spells[data.spellid] then
                    player.resurrect.targets[data.dstName].spells[data.spellid] = {id = data.spellid, count = 0}
                end
                player.resurrect.targets[data.dstName].spells[data.spellid].count =
                    player.resurrect.targets[data.dstName].spells[data.spellid].count + 1
            end
        end

        local data = {}

        local function SpellResurrect(
            ts,
            event,
            srcGUID,
            srcName,
            srcFlags,
            dstGUID,
            dstName,
            dstFlags,
            spellid,
            spellname,
            spellschool)
            data.srcGUID = srcGUID
            data.srcName = srcName
            data.srcFlags = srcFlags
            data.dstGUID = dstGUID
            data.dstName = dstName
            data.dstFlags = dstFlags
            data.spellid = spellid
            data.spellname = spellname
            data.spellschool = spellschool

            log_resurrect(Skada.current, data, ts)
            log_resurrect(Skada.total, data, ts)
        end

        function spellsmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's resurrect spells"], label)
        end

        function spellsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1
                for spellid, spell in pairs(player.resurrect.spells) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    local spellname, _, spellicon = GetSpellInfo(spellid)

                    d.id = spellname
                    d.spellid = spellid
                    d.label = spellname
                    d.icon = spellicon

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

        function spelltargetsmod:Enter(win, id, label)
            self.spellid = id
            local player = Skada:find_player(win:get_selected_set(), spellsmod.playerid)
            if player then
                self.title = format(L["%s's resurrect <%s> targets"], player.name, label)
            else
                self.title = format(L["%s's resurrect targets"], label)
            end
        end

        function spelltargetsmod:Update(win, set)
            local player = Skada:find_player(set, spellsmod.playerid)
            local max = 0

            if player and self.spellid and player.resurrect.spells[self.spellid] then
                local nr = 1

                for targetname, target in pairs(player.resurrect.spells[self.spellid]) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname
                    d.class = select(2, UnitClass(targetname))
                    d.role = target.role
                    d.spec = target.spec

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

        function targetsmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's resurrect targets"], label)
        end

        function targetsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player and player.resurrect.targets then
                local nr = 1

                for targetname, target in pairs(player.resurrect.targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname
                    d.class = select(2, UnitClass(targetname))
                    d.role = target.role
                    d.spec = target.spec

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

        function targetspellsmod:Enter(win, id, label)
            self.targetname = label
            self.title = format(L["%s's received resurrects"], label)
        end

        function targetspellsmod:Update(win, set)
            local player = Skada:find_player(set, targetsmod.playerid)
            local max = 0

            if player and self.targetname and player.resurrect.targets[self.targetname] then
                local nr = 1

                for spellid, spell in pairs(player.resurrect.targets[self.targetname].spells) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    local spellname, _, spellicon = GetSpellInfo(spellid)

                    d.id = spellid
                    d.spellid = spellid
                    d.label = spellname
                    d.icon = spellicon

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
                if player.resurrect.count > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.resurrect.count
                    d.valuetext = tostring(player.resurrect.count)

                    if player.resurrect.count > max then
                        max = player.resurrect.count
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            spelltargetsmod.metadata = {}
            targetspellsmod.metadata = {}
            spellsmod.metadata = {click1 = spelltargetsmod}
            targetsmod.metadata = {click1 = targetspellsmod}
            self.metadata = {showspots = true, click1 = spellsmod, click2 = targetsmod}

            Skada:RegisterForCL(
                SpellResurrect,
                "SPELL_RESURRECT",
                {src_is_interesting = true, dst_is_interesting = true}
            )
            Skada:AddMode(self)
            Skada:EnableModule(self:GetName())
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
            Skada:DisableModule(self:GetName())
        end

        function mod:GetSetSummary(set)
            return set.resurrect
        end

        function mod:AddPlayerAttributes(player)
            if not player.resurrect then
                player.resurrect = {count = 0, spells = {}, targets = {}}
            end
        end

        function mod:AddSetAttributes(set)
            set.resurrect = set.resurrect or 0
        end

        function mod:SetComplete(set)
            for i, player in ipairs(set.players) do
                if player.resurrect.count == 0 then
                    player.resurrect.spells = nil
                    player.resurrect.targets = nil
                end
            end
        end
    end
)