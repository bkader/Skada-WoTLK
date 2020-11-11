local Skada = Skada
if not Skada then
    return
end

local CCSpells = {
    [118] = true, -- Polymorph (rank 1)
    [12824] = true, -- Polymorph (rank 2)
    [12825] = true, -- Polymorph (rank 3)
    [12826] = true, -- Polymorph (rank 4)
    [28272] = true, -- Polymorph (rank 1:pig)
    [28271] = true, -- Polymorph (rank 1:turtle)
    [3355] = true, -- Freezing Trap Effect (rank 1)
    [14308] = true, -- Freezing Trap Effect (rank 2)
    [14309] = true, -- Freezing Trap Effect (rank 3)
    [6770] = true, -- Sap (rank 1)
    [2070] = true, -- Sap (rank 2)
    [11297] = true, -- Sap (rank 3)
    [6358] = true, -- Seduction (succubus)
    [60210] = true, -- Freezing Arrow (rank 1)
    [45524] = true, -- Chains of Ice
    [33786] = true, -- Cyclone
    [53308] = true, -- Entangling Roots
    [2637] = true, -- Hibernate (rank 1)
    [18657] = true, -- Hibernate (rank 2)
    [18658] = true, -- Hibernate (rank 3)
    [20066] = true, -- Repentance
    [9484] = true, -- Shackle Undead (rank 1)
    [9485] = true, -- Shackle Undead (rank 2)
    [10955] = true, -- Shackle Undead (rank 3)
    [51722] = true, -- Dismantle
    [710] = true, -- Banish (Rank 1)
    [18647] = true, -- Banish (Rank 2)
    [12809] = true, -- Concussion Blow
    [676] = true -- Disarm
}

local pairs, ipairs, select = pairs, ipairs, select
local tostring, format = tostring, string.format
local GetSpellInfo, GetSpellLink = GetSpellInfo, GetSpellLink

-- ======= --
-- CC Done --
-- ======= --
Skada:AddLoadableModule(
    "CC Done",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("CC Done") then
            return
        end

        local mod = Skada:NewModule(L["CC Done"])
        local spellsmod = mod:NewModule(L["CC Done spells"])
        local spelltargetsmod = mod:NewModule(L["CC Done spell targets"])
        local targetsmod = mod:NewModule(L["CC Done targets"])
        local targetspellsmod = mod:NewModule(L["CC Done target spells"])

        local function log_ccdone(set, data)
            local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
            if not player then
                return
            end

            player.ccdone.count = player.ccdone.count + 1

            if not player.ccdone.spells[data.spellname] then
                player.ccdone.spells[data.spellname] = {id = data.spellid, count = 0, targets = {}}
            end
            player.ccdone.spells[data.spellname].count = player.ccdone.spells[data.spellname].count + 1

            if not player.ccdone.spells[data.spellname].targets[data.dstName] then
                player.ccdone.spells[data.spellname].targets[data.dstName] = {id = data.dstGUID, count = 0}
            end
            player.ccdone.spells[data.spellname].targets[data.dstName].count =
                player.ccdone.spells[data.spellname].targets[data.dstName].count + 1

            if not player.ccdone.targets[data.dstName] then
                player.ccdone.targets[data.dstName] = {id = data.dstGUID, count = 0, spells = {}}
            end
            player.ccdone.targets[data.dstName].count = player.ccdone.targets[data.dstName].count + 1

            if not player.ccdone.targets[data.dstName].spells[data.spellname] then
                player.ccdone.targets[data.dstName].spells[data.spellname] = {id = data.spellid, count = 0}
            end
            player.ccdone.targets[data.dstName].spells[data.spellname].count =
                player.ccdone.targets[data.dstName].spells[data.spellname].count + 1

            set.ccdone = set.ccdone + 1
        end

        local data = {}
        local function SpellAuraApplied(
            timestamp,
            eventtype,
            srcGUID,
            srcName,
            srcFlags,
            dstGUID,
            dstName,
            dstFlags,
            ...)
            local spellid, spellname, extraspellid, extraspellname, _

            if eventtype == "SPELL_AURA_APPLIED" or eventtype == "SPELL_AURA_REFRESH" then
                spellid, spellname = ...
            else
                spellid, spellname, _, extraspellid, extraspellname = ...
            end

            if CCSpells[spellid] then
                data.playerid = srcGUID
                data.playername = srcName
                data.playerflags = srcFlags

                data.dstGUID = dstGUID
                data.dstName = dstName
                data.dstFlags = dstFlags

                data.spellid = spellid
                data.spellname = spellname
                data.extraspellid = extraspellid
                data.extraspellname = extraspellname

                log_ccdone(Skada.current, data)
                log_ccdone(Skada.total, data)
            end
        end

        function spellsmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's CC Done spells"], label)
        end

        function spellsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for spellname, spell in pairs(player.ccdone.spells) do
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

        function spelltargetsmod:Enter(win, id, label)
            self.spellname = label
            local player = Skada:find_player(win:get_selected_set(), spellsmod.playerid)
            if player then
                self.title = format(L["%s's CC Done <%s> targets"], player.name, label)
            end
        end

        function spelltargetsmod:Update(win, set)
            local player = Skada:find_player(set, spellsmod.playerid)
            local max = 0

            if player and self.spellname then
                local nr = 1

                for targetname, target in pairs(player.ccdone.spells[self.spellname].targets) do
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

        function targetsmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's CC Done targets"], label)
        end

        function targetsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for targetname, target in pairs(player.ccdone.targets) do
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

        function targetspellsmod:Enter(win, id, label)
            self.targetname = label
            local player = Skada:find_player(win:get_selected_set(), spellsmod.playerid)
            if player then
                self.title = format("%s's CC Done <%s> spells", player.name, label)
            end
        end

        function targetspellsmod:Update(win, set)
            local player = Skada:find_player(set, spellsmod.playerid)
            local max = 0

            if player and self.targetname then
                local nr = 1

                for spellname, spell in pairs(player.ccdone.targets[self.targetname].spells) do
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
            local max, nr = 0, 1
            for i, player in ipairs(set.players) do
                if player.ccdone.count > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec
                    d.value = player.ccdone.count
                    d.valuetext = tostring(player.ccdone.count)

                    if player.ccdone.count > max then
                        max = player.ccdone.count
                    end
                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            spelltargetsmod.metadata = {}
            spellsmod.metadata = {click1 = spelltargetsmod}

            targetspellsmod.metadata = {}
            targetsmod.metadata = {click1 = targetspellsmod}

            mod.metadata = {showspots = true, click1 = spellsmod, click2 = targetsmod}

            Skada:RegisterForCL(SpellAuraApplied, "SPELL_AURA_APPLIED", {src_is_interesting = true})
            Skada:RegisterForCL(SpellAuraApplied, "SPELL_AURA_REFRESH", {src_is_interesting = true})

            Skada:AddMode(self, L["CC Tracker"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:GetSetSummary(set)
            return set.ccdone
        end

        function mod:AddPlayerAttributes(player)
            if not player.ccdone then
                player.ccdone = {count = 0, spells = {}, targets = {}}
            end
        end

        function mod:AddSetAttributes(set)
            set.ccdone = set.ccdone or 0
        end

        function mod:SetComplete(set)
            for i, player in ipairs(set.players) do
                if player.ccdone.count == 0 then
                    player.ccdone.spells = nil
                    player.ccdone.targets = nil
                end
            end
        end
    end
)

-- ======== --
-- CC Taken --
-- ======== --
Skada:AddLoadableModule(
    "CC Taken",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("CC Taken") then
            return
        end

        local mod = Skada:NewModule(L["CC Taken"])
        local spellsmod = mod:NewModule(L["CC Taken spells"])
        local spellsourcesmod = mod:NewModule(L["CC Taken spell sources"])
        local sourcesmod = mod:NewModule(L["CC Taken sources"])
        local sourcespellsmod = mod:NewModule(L["CC Taken source spells"])

        local function log_cctaken(set, data)
            local player = Skada:get_player(set, data.playerid, data.playername, data.playerflags)
            if not player then
                return
            end

            player.cctaken.count = player.cctaken.count + 1

            if not player.cctaken.spells[data.spellname] then
                player.cctaken.spells[data.spellname] = {id = data.spellid, count = 0, sources = {}}
            end
            player.cctaken.spells[data.spellname].count = player.cctaken.spells[data.spellname].count + 1

            if not player.cctaken.spells[data.spellname].sources[data.srcName] then
                player.cctaken.spells[data.spellname].sources[data.srcName] = {id = data.srcGUID, count = 0}
            end
            player.cctaken.spells[data.spellname].sources[data.srcName].count =
                player.cctaken.spells[data.spellname].sources[data.srcName].count + 1

            if not player.cctaken.sources[data.srcName] then
                player.cctaken.sources[data.srcName] = {id = data.srcGUID, count = 0, spells = {}}
            end
            player.cctaken.sources[data.srcName].count = player.cctaken.sources[data.srcName].count + 1

            if not player.cctaken.sources[data.srcName].spells[data.spellname] then
                player.cctaken.sources[data.srcName].spells[data.spellname] = {id = data.spellid, count = 0}
            end
            player.cctaken.sources[data.srcName].spells[data.spellname].count =
                player.cctaken.sources[data.srcName].spells[data.spellname].count + 1

            set.cctaken = set.cctaken + 1
        end

        local data = {}
        local function SpellAuraApplied(
            timestamp,
            eventtype,
            srcGUID,
            srcName,
            srcFlags,
            dstGUID,
            dstName,
            dstFlags,
            ...)
            local spellid, spellname, extraspellid, extraspellname, _

            if eventtype == "SPELL_AURA_APPLIED" or eventtype == "SPELL_AURA_REFRESH" then
                spellid, spellname = ...
            else
                spellid, spellname, _, extraspellid, extraspellname = ...
            end

            if CCSpells[spellid] then
                data.srcGUID = srcGUID
                data.srcName = srcName
                data.srcFlags = srcFlags

                data.playerid = dstGUID
                data.playername = dstName
                data.playerflags = dstFlags

                data.spellid = spellid
                data.spellname = spellname
                data.extraspellid = extraspellid
                data.extraspellname = extraspellname

                Skada:FixPets(data)

                log_cctaken(Skada.current, data)
                log_cctaken(Skada.total, data)
            end
        end

        function spellsmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's CC Taken spells"], label)
        end

        function spellsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for spellname, spell in pairs(player.cctaken.spells) do
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

        function spellsourcesmod:Enter(win, id, label)
            self.spellname = label
            local player = Skada:find_player(win:get_selected_set(), spellsmod.playerid)
            if player then
                self.title = format(L["%s's CC Taken <%s> sources"], player.name, label)
            end
        end

        function spellsourcesmod:Update(win, set)
            local player = Skada:find_player(set, spellsmod.playerid)
            local max = 0

            if player and self.spellname then
                local nr = 1

                for sourcename, source in pairs(player.cctaken.spells[self.spellname].sources) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = source.id
                    d.label = sourcename
                    d.value = source.count
                    d.valuetext = tostring(source.count)

                    if source.count > max then
                        max = source.count
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function sourcesmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's CC Taken sources"], label)
        end

        function sourcesmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for targetname, target in pairs(player.cctaken.sources) do
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

        function sourcespellsmod:Enter(win, id, label)
            self.targetname = label
            local player = Skada:find_player(win:get_selected_set(), spellsmod.playerid)
            if player then
                self.title = format(L["%s's CC Taken <%s> sources"], player.name, label)
            end
        end

        function sourcespellsmod:Update(win, set)
            local player = Skada:find_player(set, spellsmod.playerid)
            local max = 0

            if player and self.targetname then
                local nr = 1

                for spellname, spell in pairs(player.cctaken.sources[self.targetname].spells) do
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
            local max, nr = 0, 1
            for i, player in ipairs(set.players) do
                if player.cctaken.count > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec
                    d.value = player.cctaken.count
                    d.valuetext = tostring(player.cctaken.count)

                    if player.cctaken.count > max then
                        max = player.cctaken.count
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            spellsourcesmod.metadata = {}
            spellsmod.metadata = {click1 = spellsourcesmod}

            sourcespellsmod.metadata = {}
            sourcesmod.metadata = {click1 = sourcespellsmod}

            mod.metadata = {click1 = spellsmod, click2 = sourcesmod, showspots = true}

            Skada:RegisterForCL(SpellAuraApplied, "SPELL_AURA_APPLIED", {dst_is_interesting = true})
            Skada:RegisterForCL(SpellAuraApplied, "SPELL_AURA_REFRESH", {dst_is_interesting = true})
            Skada:AddMode(self, L["CC Tracker"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:GetSetSummary(set)
            return set.cctaken
        end

        function mod:AddPlayerAttributes(player)
            if not player.cctaken then
                player.cctaken = {count = 0, spells = {}, sources = {}}
            end
        end

        function mod:AddSetAttributes(set)
            set.cctaken = set.cctaken or 0
        end

        function mod:SetComplete(set)
            for i, player in ipairs(set.players) do
                if player.cctaken.count == 0 then
                    player.cctaken.spells = nil
                    player.cctaken.sources = nil
                end
            end
        end
    end
)

-- =========== --
-- CC Breakers --
-- =========== --
Skada:AddLoadableModule(
    "CC Breakers",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("CC Breakers") then
            return
        end

        local mod = Skada:NewModule(L["CC Breakers"])
        local spellsmod = mod:NewModule(L["CC Break spells"])
        local spelltargetsmod = mod:NewModule(L["CC Break spell targets"])
        local targetsmod = mod:NewModule(L["CC Break targets"])
        local targetspellsmod = mod:NewModule(L["CC Break target spells"])

        local GetNumRaidMembers, GetRaidRosterInfo = GetNumRaidMembers, GetRaidRosterInfo
        local IsInInstance, UnitInRaid = IsInInstance, UnitInRaid
        local SendChatMessage = SendChatMessage

        local function log_ccbreak(set, data)
            local player = Skada:get_player(set, data.srcGUID, data.srcName)
            if not player then
                return
            end

            player.ccbreaks.count = player.ccbreaks.count + 1

            if not player.ccbreaks.spells[data.spellname] then
                player.ccbreaks.spells[data.spellname] = {id = data.spellid, count = 0, targets = {}}
            end
            player.ccbreaks.spells[data.spellname].count = player.ccbreaks.spells[data.spellname].count + 1

            if not player.ccbreaks.spells[data.spellname].targets[data.dstName] then
                player.ccbreaks.spells[data.spellname].targets[data.dstName] = {id = data.dstGUID, count = 0}
            end
            player.ccbreaks.spells[data.spellname].targets[data.dstName].count =
                player.ccbreaks.spells[data.spellname].targets[data.dstName].count + 1

            if not player.ccbreaks.targets[data.dstName] then
                player.ccbreaks.targets[data.dstName] = {id = data.dstGUID, count = 0, spells = {}}
            end
            player.ccbreaks.targets[data.dstName].count = player.ccbreaks.targets[data.dstName].count + 1

            if not player.ccbreaks.targets[data.dstName].spells[data.spellname] then
                player.ccbreaks.targets[data.dstName].spells[data.spellname] = {id = data.spellid, count = 0}
            end
            player.ccbreaks.targets[data.dstName].spells[data.spellname].count =
                player.ccbreaks.targets[data.dstName].spells[data.spellname].count + 1

            set.ccbreaks = set.ccbreaks + 1
        end

        local data = {}
        local function SpellAuraBroken(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            local spellid, spellname, extraspellid, extraspellname, _

            if eventtype == "SPELL_AURA_BROKEN" then
                spellid, spellname = ...
                spellid = select(1, ...)
                spellname = select(2, ...)
            else
                spellid, spellname, _, extraspellid, extraspellname = ...
            end

            if not CCSpells[spellid] then
                return
            end

            local petid = srcGUID
            local petname = srcName
            srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName)

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

            log_ccbreak(Skada.current, data)
            log_ccbreak(Skada.total, data)

            -- Optional announce
            local inInstance, instanceType = IsInInstance()
            if
                Skada.db.profile.modules.ccannounce and GetNumRaidMembers() > 0 and UnitInRaid(srcName) and
                    not (instanceType == "pvp")
             then
                -- Ignore main tanks?
                if Skada.db.profile.modules.ccignoremaintanks then
                    -- Loop through our raid and return if src is a main tank.
                    for i = 1, MAX_RAID_MEMBERS do
                        local name, _, _, _, _, class, _, _, _, role, _ = GetRaidRosterInfo(i)
                        if name == srcName and role == "maintank" then
                            return
                        end
                    end
                end

                -- Prettify pets.
                if petid ~= srcGUID then
                    srcName = petname .. " (" .. srcName .. ")"
                end

                -- Go ahead and announce it.
                if extraspellname then
                    SendChatMessage(
                        format(
                            L["%s on %s removed by %s's %s"],
                            spellname,
                            dstName,
                            srcName,
                            select(1, GetSpellLink(extraspellid))
                        ),
                        "RAID"
                    )
                else
                    SendChatMessage(format(L["%s on %s removed by %s"], spellname, dstName, srcName), "RAID")
                end
            end
        end

        function spellsmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's CC Break spells"], label)
        end

        function spellsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for spellname, spell in pairs(player.ccbreaks.spells) do
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

        function spelltargetsmod:Enter(win, id, label)
            self.spellname = label
            local player = Skada:find_player(win:get_selected_set(), spellsmod.playerid)
            if player then
                self.title = format(L["%s's CC Break <%s> targets"], player.name, label)
            end
        end

        function spelltargetsmod:Update(win, set)
            local player = Skada:find_player(set, spellsmod.playerid)
            local max = 0

            if player and self.spellname then
                local nr = 1

                for targetname, target in pairs(player.ccbreaks.spells[self.spellname].targets) do
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

        function targetsmod:Enter(win, id, label)
            self.playerid = id
            self.title = format(L["%s's CC Break targets"], label)
        end

        function targetsmod:Update(win, set)
            local player = Skada:find_player(set, self.playerid)
            local max = 0

            if player then
                local nr = 1

                for targetname, target in pairs(player.ccbreaks.targets) do
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

        function targetspellsmod:Enter(win, id, label)
            self.targetname = label
            local player = Skada:find_player(win:get_selected_set(), spellsmod.playerid)
            if player then
                self.title = format(L["%s's CC Break <%s> spells"], player.name, label)
            end
        end

        function targetspellsmod:Update(win, set)
            local player = Skada:find_player(set, spellsmod.playerid)
            local max = 0

            if player and self.targetname then
                local nr = 1

                for spellname, spell in pairs(player.ccbreaks.targets[self.targetname].spells) do
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
                if player.ccbreaks.count > 0 then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec
                    d.value = player.ccbreaks.count
                    d.valuetext = tostring(player.ccbreaks.count)

                    if player.ccbreaks.count > max then
                        max = player.ccbreaks.count
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function mod:OnEnable()
            spelltargetsmod.metadata = {}
            spellsmod.metadata = {click1 = spelltargetsmod}

            targetspellsmod.metadata = {}
            targetsmod.metadata = {click1 = targetspellsmod}

            mod.metadata = {showspots = true, click1 = spellsmod, click2 = targetsmod}

            Skada:RegisterForCL(SpellAuraBroken, "SPELL_AURA_BROKEN", {src_is_interesting = true})
            Skada:RegisterForCL(SpellAuraBroken, "SPELL_AURA_BROKEN_SPELL", {src_is_interesting = true})

            Skada:AddMode(self, L["CC Tracker"])
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        function mod:AddToTooltip(set, tooltip)
            GameTooltip:AddDoubleLine(L["CC Breaks"], set.ccbreaks, 1, 1, 1)
        end

        function mod:GetSetSummary(set)
            return set.ccbreaks
        end

        -- Called by Skada when a new player is added to a set.
        function mod:AddPlayerAttributes(player)
            if not player.ccbreaks then
                player.ccbreaks = {count = 0, spells = {}, targets = {}}
            end
        end

        -- Called by Skada when a new set is created.
        function mod:AddSetAttributes(set)
            if not set.ccbreaks then
                set.ccbreaks = 0
            end
        end

        function mod:SetComplete(set)
            for i, player in ipairs(set.players) do
                if player.ccbreaks.count == 0 then
                    player.ccbreaks.spells = nil
                    player.ccbreaks.targets = nil
                end
            end
        end

        local opts = {
            ccoptions = {
                type = "group",
                name = L["CC"],
                args = {
                    announce = {
                        type = "toggle",
                        name = L["Announce CC breaking to party"],
                        get = function()
                            return Skada.db.profile.modules.ccannounce
                        end,
                        set = function()
                            Skada.db.profile.modules.ccannounce = not Skada.db.profile.modules.ccannounce
                        end,
                        order = 1
                    },
                    ignoremaintanks = {
                        type = "toggle",
                        name = L["Ignore Main Tanks"],
                        get = function()
                            return Skada.db.profile.modules.ccignoremaintanks
                        end,
                        set = function()
                            Skada.db.profile.modules.ccignoremaintanks = not Skada.db.profile.modules.ccignoremaintanks
                        end,
                        order = 2
                    }
                }
            }
        }

        function mod:OnInitialize()
            -- Add our options.
            table.insert(Skada.options.plugins, opts)
        end
    end
)