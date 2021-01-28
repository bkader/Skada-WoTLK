local Skada = Skada
Skada:AddLoadableModule(
    "Dispels",
    function(Skada, L)
        if Skada:IsDisabled("Dispels") then
            return
        end

        local mod = Skada:NewModule(L["Dispels"])
        local spellsmod = mod:NewModule(L["Dispelled spell list"])
        local targetsmod = mod:NewModule(L["Dispelled target list"])
        local playermod = mod:NewModule(L["Dispel spell list"])

        -- cache frequently used globals
        local _pairs, _ipairs = pairs, ipairs
        local _format, math_max = string.format, math.max
        local _GetSpellInfo = GetSpellInfo

        local function log_dispels(set, data)
            local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
            if player then
                -- increment player's and set's dispels count
                player.dispels = player.dispels or {}
                player.dispels.count = (player.dispels.count or 0) + 1
                set.dispels = (set.dispels or 0) + 1

                -- add the dispelled spell
                if data.spellid then
                    player.dispels.spells = player.dispels.spells or {}
                    if not player.dispels.spells[data.spellid] then
                        player.dispels.spells[data.spellid] = {school = data.spellschool, count = 1}
                    else
                        player.dispels.spells[data.spellid].count = player.dispels.spells[data.spellid].count + 1
                    end
                end

                -- add the dispelling spell
                if data.extraspellid then
                    player.dispels.extraspells = player.dispels.extraspells or {}
                    if not player.dispels.extraspells[data.extraspellid] then
                        player.dispels.extraspells[data.extraspellid] = {school = data.extraspellschool, count = 1}
                    else
                        player.dispels.extraspells[data.extraspellid].count = player.dispels.extraspells[data.extraspellid].count + 1
                    end
                end

                -- add the dispelled target
                if data.dstName then
                    player.dispels.targets = player.dispels.targets or {}
                    if not player.dispels.targets[data.dstName] then
                        player.dispels.targets[data.dstName] = {id = data.dstGUID, count = 1}
                    else
                        player.dispels.targets[data.dstName].count = player.dispels.targets[data.dstName].count + 1
                    end
                end
            end
        end

        local data = {}

        local function SpellDispel(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if eventtype ~= "SPELL_DISPEL_FAILED" then
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
        end

        function spellsmod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["%s's dispelled spells"], label)
        end

        function spellsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid, self.playername)
            local max = 0

            if player and player.dispels.extraspells then
                local nr = 1

                for spellid, spell in _pairs(player.dispels.extraspells) do
                    local spellname, _, spellicon = _GetSpellInfo(spellid)

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
                        _format("%02.1f%%", 100 * spell.count / math_max(1, set.dispels or 0)),
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
            self.playername = label
            self.title = _format(L["%s's dispelled targets"], label)
        end

        function targetsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid, self.playername)
            local max = 1

            if player and player.dispels.targets then
                local nr = 1
                for targetname, target in _pairs(player.dispels.targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname

                    local p = Skada:find_player(set, target.id, targetname)
                    if p then
                        d.class = p.class
                        d.spec = p.spec
                        d.role = p.role
                    elseif Skada:GetPetOwner(target.id) then
						d.class = "PET"
						d.spec = 1
						d.role = "DAMAGER"
                    else
                        d.class = "UNKNOWN"
                        d.spec = 2
						d.role = "DAMAGER"
                    end

                    d.value = target.count
                    d.valuetext =
                        Skada:FormatValueText(
                        target.count,
                        mod.metadata.columns.Total,
                        _format("%02.1f%%", 100 * target.count / math_max(1, set.dispels or 0)),
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
            self.playername = label
            self.title = _format(L["%s's dispel spells"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid, self.playername)
            local max = 0

            if player and player.dispels.spells then
                local nr = 1

                for spellid, spell in _pairs(player.dispels.spells) do
                    local spellname, _, spellicon = _GetSpellInfo(spellid)

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
                        _format("%02.1f%%", 100 * spell.count / math_max(1, set.dispels or 0)),
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
                if player.dispels then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.spec = player.spec
                    d.role = player.role

                    d.value = player.dispels.count
                    d.valuetext =
                        Skada:FormatValueText(
                        player.dispels.count,
                        self.metadata.columns.Total,
                        _format("%02.1f%%", 100 * player.dispels.count / math_max(1, set.dispels or 0)),
                        self.metadata.columns.Percent
                    )

                    if player.dispels.count > max then
                        max = player.dispels.count
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            self.metadata = {
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
			if set and set.dispels and set.dispels > 0 then
				tooltip:AddDoubleLine(L["Dispels"], set.dispels, 1, 1, 1)
			end
        end

        function mod:GetSetSummary(set)
            return set.dispels or 0
        end
    end
)