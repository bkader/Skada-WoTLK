local Skada = Skada
Skada:AddLoadableModule(
    "Friendly Fire",
    function(Skada, L)
        if Skada:IsDisabled("Friendly Fire") then
            return
        end

        local mod = Skada:NewModule(L["Friendly Fire"])
        local spellmod = mod:NewModule(L["Damage spell list"])
        local targetmod = mod:NewModule(L["Damage target list"])

        local _pairs, _ipairs = pairs, ipairs
        local _format, math_max = string.format, math.max
        local _GetSpellInfo = GetSpellInfo

        local function log_damage(set, dmg)
            local player = Skada:get_player(set, dmg.playerid, dmg.playername, dmg.playerflags)
            if player then
                -- add player and set friendly fire:
                player.friendfire = player.friendfire or {}
                player.friendfire.amount = (player.friendfire.amount or 0) + dmg.amount
                set.friendfire = (set.friendfire or 0) + dmg.amount

                -- save the spell first.
                if dmg.spellid then
                    player.friendfire.spells = player.friendfire.spells or {}
                    if not player.friendfire.spells[dmg.spellid] then
                        player.friendfire.spells[dmg.spellid] = {school = dmg.spellschool, amount = dmg.amount}
                    else
                        player.friendfire.spells[dmg.spellid].amount =
                            player.friendfire.spells[dmg.spellid].amount + dmg.amount
                    end
                end

                -- record targets
                if dmg.dstName then
                    player.friendfire.targets = player.friendfire.targets or {}
                    if not player.friendfire.targets[dmg.dstName] then
                        player.friendfire.targets[dmg.dstName] = {id = dmg.dstGUID, amount = dmg.amount}
                    else
                        player.friendfire.targets[dmg.dstName].amount =
                            player.friendfire.targets[dmg.dstName].amount + dmg.amount
                    end
                end
            end
        end

        local dmg = {}

        local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if srcGUID ~= dstGUID then
                local spellid, spellname, spellschool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...
                dmg.playerid = srcGUID
                dmg.playername = srcName
                dmg.playerflags = srcFlags
                dmg.dstGUID = dstGUID
                dmg.dstName = dstName
                dmg.dstFlags = dstFlags
                dmg.spellid = spellid
                dmg.spellschool = school
                dmg.amount = (amount or 0) + (overkill or 0) + (absorbed or 0)

                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            if srcGUID ~= dstGUID then
                local amount, overkill, school, resisted, blocked, absorbed = ...
                dmg.playerid = srcGUID
                dmg.playername = srcName
                dmg.playerflags = srcFlags
                dmg.dstGUID = dstGUID
                dmg.dstName = dstName
                dmg.dstFlags = dstFlags
                dmg.spellid = 6603
                dmg.spellschool = 1
                dmg.amount = (amount or 0) + (overkill or 0) + (absorbed or 0)

                log_damage(Skada.current, dmg)
                log_damage(Skada.total, dmg)
            end
        end

        function targetmod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["%s's targets"], label)
        end

        function targetmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player and player.friendfire.targets then
                local nr = 1

                for targetname, target in _pairs(player.friendfire.targets) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = target.id
                    d.label = targetname

                    -- get other data
                    local data = Skada:find_player(set, target.id, targetname)
                    if data then
                        d.class = data.class
                        d.role = data.role
                        d.spec = data.spec
                    else
                        d.class = "UNKNOWN"
                        d.role = "NONE"
                    end

                    d.value = target.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(target.amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * target.amount / math_max(1, set.friendfire or 0)),
                        mod.metadata.columns.Percent
                    )

                    if target.amount > max then
                        max = target.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function spellmod:Enter(win, id, label)
            self.playerid = id
            self.playername = label
            self.title = _format(L["%s's damage"], label)
        end

        function spellmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player and player.friendfire.spells then
                local nr = 1

                for spellid, spell in _pairs(player.friendfire.spells) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    local spellname, _, spellicon = _GetSpellInfo(spellid)

                    d.id = spellid
                    d.spellid = spellid
                    d.label = spellname
                    d.icon = spellicon

                    d.value = spell.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(spell.amount),
                        mod.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * spell.amount / math_max(1, set.friendfire or 0)),
                        mod.metadata.columns.Percent
                    )

                    if spell.amount > max then
                        max = spell.amount
                    end

                    nr = nr + 1
                end
            end
            win.metadata.maxvalue = max
        end

        function mod:Update(win, set)
            local nr, max = 1, 0

            for i, player in _pairs(set.players) do
                if player.friendfire and player.friendfire.amount > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec

                    d.value = player.friendfire.amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(player.friendfire.amount),
                        self.metadata.columns.Damage,
                        _format("%02.1f%%", 100 * player.friendfire.amount / math_max(1, set.friendfire or 0)),
                        self.metadata.columns.Percent
                    )

                    if player.friendfire.amount > max then
                        max = player.friendfire.amount
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            spellmod.metadata = {}
            targetmod.metadata = {showspots = true}
            self.metadata = {
                showspots = true,
                click1 = spellmod,
                click2 = targetmod,
                columns = {Damage = true, Percent = true}
            }

            Skada:RegisterForCL(
                SpellDamage,
                "SPELL_DAMAGE",
                {dst_is_interesting_nopets = true, src_is_interesting_nopets = true}
            )
            Skada:RegisterForCL(
                SpellDamage,
                "SPELL_PERIODIC_DAMAGE",
                {dst_is_interesting_nopets = true, src_is_interesting_nopets = true}
            )
            Skada:RegisterForCL(
                SpellDamage,
                "SPELL_BUILDING_DAMAGE",
                {dst_is_interesting_nopets = true, src_is_interesting_nopets = true}
            )
            Skada:RegisterForCL(
                SpellDamage,
                "RANGE_DAMAGE",
                {dst_is_interesting_nopets = true, src_is_interesting_nopets = true}
            )
            Skada:RegisterForCL(
                SwingDamage,
                "SWING_DAMAGE",
                {dst_is_interesting_nopets = true, src_is_interesting_nopets = true}
            )

            Skada:AddMode(self, L["Damage done"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:GetSetSummary(set)
            return Skada:FormatNumber(set.friendfire or 0)
        end
    end
)