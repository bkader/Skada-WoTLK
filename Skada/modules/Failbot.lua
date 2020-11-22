local Skada = Skada
if not Skada then
    return
end

Skada:AddLoadableModule(
    "Fails",
    function(Skada, L)
        if Skada:IsDisabled("Fails") then
            return
        end

        local mod = Skada:NewModule(L["Fails"])
        local playermod = mod:NewModule(L["Player's failed events"])
        local spellmod = mod:NewModule(L["Event's failed players"])

        local LibFail = LibStub("LibFail-1.0", true)
        if not LibFail then
            return
        end

        local _pairs, _ipairs = pairs, ipairs
        local _tostring, _format = tostring, string.format
        local _GetSpellInfo = GetSpellInfo
        local _UnitGUID = UnitGUID

        local failevents = LibFail:GetSupportedEvents()

        local function onFail(event, who, fatal)
            if event and who then
                -- is th fail a valid spell?
                local spellid = LibFail:GetEventSpellId(event)
                if not spellid then
                    return
                end

                local unitGUID = _UnitGUID(who)

                -- add to current set
                if Skada.current then
                    local player = Skada:get_player(Skada.current, unitGUID, who)
                    if player then
                        player.fails.count = player.fails.count + 1
                        Skada.current.fails = Skada.current.fails + 1

                        if not player.fails.spells[spellid] then
                            player.fails.spells[spellid] = 0
                        end
                        player.fails.spells[spellid] = player.fails.spells[spellid] + 1
                    end
                end

                -- add to total
                if Skada.total then
                    local player = Skada:get_player(Skada.total, unitGUID, who)
                    if player then
                        player.fails.count = player.fails.count + 1
                        Skada.total.fails = Skada.total.fails + 1

                        if not player.fails.spells[spellid] then
                            player.fails.spells[spellid] = 0
                        end
                        player.fails.spells[spellid] = player.fails.spells[spellid] + 1
                    end
                end
            end
        end

        function spellmod:Enter(win, id, label)
            self.spellid = id
            self.title = _format(L["%s's fails"], label)
        end

        function spellmod:Update(win, set)
            local nr, max = 1, 0

            for _, player in _ipairs(set.players) do
                if player.fails.spells and player.fails.spells[self.spellid] then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.fails.spells[self.spellid]
                    d.valuetext = _tostring(d.value)

                    if d.value > max then
                        max = d.value
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function playermod:Enter(win, id, label)
            self.playerid = id
            self.title = _format(L["%s's fails"], label)
        end

        function playermod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player and player.fails.spells then
                local nr = 1

                for spellid, count in _pairs(player.fails.spells) do
                    local spellname, _, spellicon = _GetSpellInfo(spellid)
                    if spellname then
                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = spellid
                        d.spellid = spellid
                        d.label = spellname
                        d.icon = spellicon

                        d.value = count
                        d.valuetext = _tostring(count)

                        if count > max then
                            max = count
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
                if player.fails.count > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.fails.count
                    d.valuetext = _tostring(player.fails.count)

                    if d.value > max then
                        max = d.value
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            for _, event in _ipairs(failevents) do
                LibFail:RegisterCallback(event, onFail)
            end

            spellmod.metadata = {}
            playermod.metadata = {click1 = spellmod}
            mod.metadata = {click1 = playermod}

            Skada:AddMode(self)
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:GetSetSummary(set)
            return set.fails
        end

        function mod:AddToTooltip(set, tooltip)
            if set.fails > 0 then
                tooltip:AddDoubleLine(L["Fails"], set.fails, 1, 1, 1)
            end
        end

        function mod:AddPlayerAttributes(player)
            if not player.fails then
                player.fails = {count = 0, spells = {}}
            end
        end

        function mod:AddSetAttributes(set)
            set.fails = set.fails or 0
        end

        function mod:SetComplete(set)
            for i, player in _ipairs(set.players) do
                if player.fails == 0 then
                    player.fails.spells = nil
                end
            end
        end
    end
)