local Skada = Skada
if not Skada then
    return
end

Skada:AddLoadableModule(
    "Improvement",
    function(Skada, L)
        if Skada:IsDisabled("Improvement") then
            return
        end

        local mod = Skada:NewModule(L["Improvement"])
        local mod_modes = mod:NewModule(L["Improvement modes"])
        local mod_comparison = mod:NewModule(L["Improvement comparison"])

        local _UnitGUID, _UnitName, _UnitClass = UnitGUID, UnitName, UnitClass
        local _pairs, _ipairs, _select = pairs, ipairs, select
        local _format, _tostring = string.format, tostring
        local date = date

        local modes = {
            "ActiveTime",
            "Damage",
            "DamageTaken",
            "Deaths",
            "Fails",
            "Healing",
            "Interrupts",
            "Overhealing"
        }

        --
        -- because we added some NPCs as bosses in order to fix the
        -- Gunship Battle segment name, this module will consider them
        -- ass bosses, thus it will record them and we don't want that.
        -- so we make sure to skip them.
        --
        local blacklist = {
            [L["Kor'kron Sergeant"]] = true,
            [L["Kor'kron Axethrower"]] = true,
            [L["Kor'kron Rocketeer"]] = true,
            [L["Kor'kron Battle-Mage"]] = true,
            [L["Skybreaker Sergeant"]] = true,
            [L["Skybreaker Rifleman"]] = true,
            [L["Skybreaker Mortar Soldier"]] = true,
            [L["Skybreaker Sorcerer"]] = true,
            [L["Stinky"]] = true,
            [L["Precious"]] = true
        }

        -- :::::::::::::::::::::::::::::::::::::::::::::::

        local updaters = {}

        updaters.ActiveTime = function(set, player)
            return Skada:PlayerActiveTime(set, player)
        end

        updaters.Damage = function(set, player)
            return player.damagedone and player.damagedone.amount or 0
        end

        updaters.DamageTaken = function(set, player)
            return player.damagetaken and player.damagetaken.amount or 0
        end

        updaters.Deaths = function(set, player)
            return player.deaths or 0
        end

        updaters.Healing = function(set, player)
            local total = 0
            if player.healing then
                total = total + player.healing.amount
            end
            if player.absorbs then
                total = total + player.absorbs.amount
            end
            return total
        end

        updaters.Interrupts = function(set, player)
            return player.interrupts and player.interrupts.count or 0
        end

        updaters.Fails = function(set, player)
            return player.fails and player.fails.count or 0
        end

        -- :::::::::::::::::::::::::::::::::::::::::::::::

        local function find_boss_data(bossname)
            mod.db = mod.db or SkadaImprovementDB
            for k, v in _pairs(mod.db.bosses) do
                if k == bossname then
                    return v
                end
            end

            local boss = {count = 0, encounters = {}}
            mod.db.bosses[bossname] = boss
            return find_boss_data(bossname)
        end

        local function find_encounter_data(boss, starttime)
            for i, encounter in _ipairs(boss.encounters) do
                if encounter.starttime == starttime then
                    return encounter
                end
            end

            tinsert(boss.encounters, {starttime = starttime, data = {}})
            return find_encounter_data(boss, starttime)
        end

        -- :::::::::::::::::::::::::::::::::::::::::::::::

        function mod_comparison:Enter(win, id, label)
            self.mobid = id
            self.modename = label
            self.title = mod_modes.mobname .. " - " .. label
        end

        function mod_comparison:Update(win, set)
            local max = 0
            local boss = find_boss_data(mod_modes.mobname)
            if boss then
                local nr = 1

                for i = 1, boss.count do
                    local encounter = boss.encounters[i]
                    if encounter then
                        local d = win.dataset[nr] or {}
                        win.dataset[nr] = d

                        d.id = i
                        d.label = date("%x %X", encounter.starttime)

                        local value = encounter.data[self.modename]
                        d.value = value or 0
                        if self.modename == "ActiveTime" then
                            d.valuetext = Skada:FormatTime(d.value)
                        elseif self.modename == "Deaths" or self.modename == "Interrupts" or self.modename == "Fails" then
                            d.valuetext = _tostring(d.value)
                        else
                            d.valuetext =
                                Skada:FormatValueText(
                                Skada:FormatNumber(d.value),
                                true,
                                Skada:FormatNumber((d.value) / encounter.data.ActiveTime),
                                true
                            )
                        end

                        if d.value > max then
                            max = d.value
                        end

                        nr = nr + 1
                    end
                end
            end

            win.metadata.maxvalue = max
        end

        -- :::::::::::::::::::::::::::::::::::::::::::::::

        function mod_modes:Enter(win, id, label)
            self.mobid = id
            self.mobname = label
            self.title = _format(L["%s's overall data"], label)
        end

        function mod_modes:Update(win, set)
            local max = 0

            local boss = find_boss_data(self.mobname)
            if boss then
                local nr = 1
                for i, mode in _ipairs(modes) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = i
                    d.label = mode

                    local value, active = 0, 0

                    for _, encounter in _ipairs(boss.encounters) do
                        value = value + (encounter.data[mode] or 0)
                        active = active + (encounter.data.ActiveTime or 0)
                    end

                    d.value = value

                    if mode == "ActiveTime" then
                        d.valuetext = Skada:FormatTime(d.value)
                    elseif mode == "Deaths" or mode == "Interrupts" or mode == "Fails" then
                        d.valuetext = _tostring(d.value)
                    else
                        d.valuetext = Skada:FormatNumber(d.value)
                    end

                    if i > max then
                        max = i
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        -- :::::::::::::::::::::::::::::::::::::::::::::::

        function mod:Update(win, set)
            local max = 0
            if self.db and self.db.bosses then
                local nr = 1
                for name, data in _pairs(self.db.bosses) do
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = name
                    d.label = name
                    d.value = data.count
                    d.valuetext = _tostring(data.count)

                    if data.count > max then
                        max = data.count
                    end

                    nr = nr + 1
                end
            end
            win.metadata.maxvalue = max
        end

        function mod:OnInitialize()
            -- make our DB local
            SkadaImprovementDB = SkadaImprovementDB or {}
            if next(SkadaImprovementDB) == nil then
                SkadaImprovementDB = {
                    id = _UnitGUID("player"),
                    name = _UnitName("player"),
                    class = _select(2, _UnitClass("player")),
                    bosses = {}
                }
            end
            self.db = SkadaImprovementDB
        end

        function mod:EncounterEnd(event, data)
            if event ~= "ENCOUNTER_END" or not data then
                return
            end

            -- we only record raid bosses, nothing else.
            local inInstance, instanceType = IsInInstance()
            if not inInstance or instanceType ~= "raid" then
                return
            end

            if data.gotboss and (data.mobname and not blacklist[data.mobname]) then
                local boss = find_boss_data(data.mobname)
                if not boss then
                    return
                end

                local encounter = find_encounter_data(boss, data.starttime)
                if not encounter then
                    return
                end

                for i, player in _ipairs(data.players) do
                    if player.id == self.db.id then
                        for _, mode in _ipairs(modes) do
                            if updaters[mode] then
                                encounter.data[mode] = updaters[mode](data, player)
                            else
                                encounter.data[mode] = player[mode:lower()]
                            end
                        end
                        -- increment boss count and stop
                        boss.count = boss.count + 1
                        if boss.count ~= #boss.encounters then
                            boss.count = #boss.encounters
                        end
                        break
                    end
                end
            end
        end

        function mod:OnEnable()
            mod_comparison.metadata = {}
            mod_modes.metadata = {click1 = mod_comparison}
            self.metadata = {click1 = mod_modes}

            Skada:AddMode(self)
            Skada.RegisterCallback(self, "ENCOUNTER_END", "EncounterEnd")
        end

        function mod:OnDisable()
            Skada:RemoveMode(self)
        end

        local function ask_for_reset()
            StaticPopupDialogs["ResetImprovementDialog"] = {
                text = L["Do you want to reset your improvement data?"],
                button1 = ACCEPT,
                button2 = CANCEL,
                timeout = 30,
                whileDead = 0,
                hideOnEscape = 1,
                OnAccept = function()
                    mod:Reset()
                end
            }
            StaticPopup_Show("ResetImprovementDialog")
        end

        function mod:Reset()
            Skada:Wipe()
            SkadaImprovementDB = {}
            self:OnInitialize()
            collectgarbage("collect")
            for _, win in _ipairs(Skada:GetWindows()) do
                local mode = win.db.mode
                if mode == L["Improvement"] or mode == L["Improvement modes"] or mode == L["Improvement comparison"] then
                    win:DisplayMode(mod)
                end
            end
            Skada:UpdateDisplay(true)
            Skada:Print(L["All data has been reset."])
        end

        local Default_ShowPopup = Skada.ShowPopup
        function Skada:ShowPopup(win)
            if win and win.db.mode == "Improvement" then
                ask_for_reset()
                return
            end

            return Default_ShowPopup()
        end
    end
)