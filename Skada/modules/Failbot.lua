local Skada = Skada
Skada:AddLoadableModule(
    "Fails",
    function(Skada, L)
        if Skada:IsDisabled("Fails") then
            return
        end

        -- this line is moved here so that the module is not added
        -- in case the LibFail library is missing
        local LibFail = LibStub("LibFail-1.0", true)
        if not LibFail then
            return
        end
		local failevents, tankevents = LibFail:GetSupportedEvents(), {}

        local mod = Skada:NewModule(L["Fails"])
        local playermod = mod:NewModule(L["Player's failed events"])
        local spellmod = mod:NewModule(L["Event's failed players"])

        local _pairs, _ipairs = pairs, ipairs
        local _tostring, _format = tostring, string.format
        local _GetSpellInfo = GetSpellInfo
        local _UnitGUID = UnitGUID

        local function onFail(event, who, failtype)
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
                    if player and (player.role ~= "TANK" or not tankevents[event]) then
						player.fails = player.fails or {}
                        player.fails.count = (player.fails.count or 0) + 1
                        Skada.current.fails = (Skada.current.fails or 0) + 1

                        player.fails.spells = player.fails.spells or {}
                        player.fails.spells[spellid] = (player.fails.spells[spellid] or 0) + 1
                    end
                end

                -- add to total
                if Skada.total then
                    local player = Skada:get_player(Skada.total, unitGUID, who)
                    if player and (player.role ~= "TANK" or not tankevents[event]) then
						player.fails = player.fails or {}
                        player.fails.count = (player.fails.count or 0) + 1
                        Skada.total.fails = (Skada.total.fails or 0) + 1

                        player.fails.spells = player.fails.spells or {}
                        player.fails.spells[spellid] = (player.fails.spells[spellid] or 0) + 1
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
                if player.fails and player.fails.spells[self.spellid] then
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

            for _, player in _ipairs(set.players) do
                if player.fails then
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
			for _, event in _ipairs(LibFail:GetFailsWhereTanksDoNotFail()) do
				tankevents[event] = true
			end
            for _, event in _ipairs(failevents) do
                LibFail:RegisterCallback(event, onFail)
            end

            playermod.metadata = {click1 = spellmod}
            self.metadata = {click1 = playermod}

            Skada:AddMode(self)
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:GetSetSummary(set)
            return set.fails or 0
        end

        function mod:AddToTooltip(set, tooltip)
            if set and set.fails and set.fails > 0 then
                tooltip:AddDoubleLine(L["Fails"], set.fails, 1, 1, 1)
            end
        end
    end
)