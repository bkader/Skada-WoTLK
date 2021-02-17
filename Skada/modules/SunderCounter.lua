local Skada = Skada
Skada:AddLoadableModule("Sunder Counter", function(Skada, L)
    if Skada:IsDisabled("Sunder Counter") then return end

    local mod = Skada:NewModule(L["Sunder Counter"])
    local targetmod = mod:NewModule(L["Sunder target list"])

	local _pairs, _ipairs, _select = pairs, ipairs, select
	local _format, math_max = string.format, math.max
	local _GetSpellInfo = GetSpellInfo

    local sunder, devastate

    local function log_sunder(set, playerid, playername, playerflags, targetname)
        local player = Skada:get_player(set, playerid, playername, playerflags)
        if player then
            player.sunders = player.sunders or {}
            player.sunders.count = (player.sunders.count or 0) + 1
            set.sunders = (set.sunders or 0) + 1

            if targetname then
                player.sunders.targets = player.sunders.targets or {}
                player.sunders.targets[targetname] = (player.sunders.targets[targetname] or 0) + 1
            end
        end
    end

    local function SunderApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        local spellid, spellname, spellschool = ...
        if spellname == sunder or spellname == devastate then
            log_sunder(Skada.current, srcGUID, srcName, srcFlags, dstName)
            log_sunder(Skada.total, srcGUID, srcName, srcFlags, dstName)
        end
    end

    function targetmod:Enter(win, id, label)
        self.playerid = id
        self.playername = label
        self.title = _format(L["%s's <%s> targets"], label, sunder)
    end

    function targetmod:Update(win, set)
        local player = Skada:find_player(set, self.playerid)
        local max = 0

        if player and player.sunders.targets then
            local nr = 1
            for targetname, count in _pairs(player.sunders.targets) do
                local d = win.dataset[nr] or {}
                win.dataset[nr] = d

                d.id = targetname
                d.label = targetname

                d.value = count
                d.valuetext = Skada:FormatValueText(
                    count,
                    mod.metadata.columns.Count,
                    _format("%02.1f%%", 100 * count / math_max(1, player.sunders.count or 0)),
                    mod.metadata.columns.Percent
                )

                if count > max then
                    max = count
                end

                nr = nr + 1
            end
        end

        win.metadata.maxvalue = max
    end

    function mod:Update(win, set)
        sunder = sunder or _select(1, _GetSpellInfo(47467))
        devastate = devastate or _select(1, _GetSpellInfo(47498))

        local max = 0
        local total = set.sunders or 0

        if total > 0 then
            local nr = 1

            for _, player in _ipairs(set.players) do
                if player.sunders then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.spec = player.spec
                    d.role = player.role

                    d.value = player.sunders.count
                    d.valuetext = Skada:FormatValueText(
                        d.value,
                        self.metadata.columns.Count,
                        _format("%02.1f%%", 100 * d.value / math_max(1, total)),
                        self.metadata.columns.Percent
                    )

                    if d.value > max then
                        max = d.value
                    end

                    nr = nr + 1
                end
            end
        end

        win.metadata.maxvalue = max
    end

    function mod:OnInitialize()
        sunder = sunder or _select(1, _GetSpellInfo(47467))
        devastate = devastate or _select(1, _GetSpellInfo(47498))
    end

    function mod:OnEnable()
        self.metadata = {
            showspots = true,
            click1 = targetmod,
            columns = {Count = true, Percent = true}
        }
        Skada:RegisterForCL(SunderApplied, "SPELL_CAST_SUCCESS", {src_is_interesting_nopets = true})
        Skada:AddMode(self, L["Buffs and Debuffs"])
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
    end

    function mod:AddToTooltip(set, tooltip)
        tooltip:AddDoubleLine(sunder, set.sunders or 0, 1, 1, 1)
    end

    function mod:GetSetSummary(set)
        return set.sunders or 0
    end
end)