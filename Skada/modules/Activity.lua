assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Activity", function(Skada, L)
    if Skada:IsDisabled("Activity") then return end

    local mod = Skada:NewModule(L["Activity"])
    local _date, _ipairs, _format = date, ipairs, string.format
    local math_min, math_max = math.min, math.max

    local function activity_tooltip(win, id, label, tooltip)
        local set = win:get_selected_set()
        local player = Skada:find_player(set, id)
        if player then
            local settime = Skada:GetSetTime(set)
            local playertime = Skada:PlayerActiveTime(set, player)
            tooltip:AddLine(player.name .. ": " .. L["Activity"])
            tooltip:AddDoubleLine(L["Segment Time"], Skada:FormatTime(settime), 1, 1, 1)
            tooltip:AddDoubleLine(L["Active Time"], Skada:FormatTime(playertime), 1, 1, 1)
            tooltip:AddDoubleLine(L["Activity"], _format("%02.1f%%", 100 * playertime / math_max(1, settime)), 1, 1, 1)
        end
    end

    function mod:Update(win, set)
        local settime = Skada:GetSetTime(set)
        local nr, max = 1, 0
        for i, player in _ipairs(set.players) do
            local d = win.dataset[nr] or {}
            win.dataset[nr] = d

            local playertime = Skada:PlayerActiveTime(set, player)

            d.id = player.id
            d.label = player.name
            if player.class then
                d.class = player.class
                d.role = player.role
                d.spec = player.spec
            else
                d.class = Skada:IsBoss(player.id) and "MONSTER" or "PET"
            end

            d.value = playertime
            d.valuetext = Skada:FormatValueText(
                Skada:FormatTime(playertime),
                self.metadata.columns["Active Time"],
                _format("%02.1f%%", 100 * playertime / math_max(1, settime)),
                self.metadata.columns.Percent
            )

            if playertime > max then
                max = playertime
            end

            nr = nr + 1
        end

        win.metadata.maxvalue = settime
        win.title = L["Activity"]
    end

    function mod:OnEnable()
        mod.metadata = {
            showspots = true,
            tooltip = activity_tooltip,
            columns = {["Active Time"] = true, Percent = true}
        }
        Skada:AddMode(self)
    end

    function mod:OnDisable()
        Skada:RemoveMode(self)
    end

    function mod:GetSetSummary(set)
        if set then
            return Skada:FormatValueText(
                Skada:GetFormatedSetTime(set),
                self.metadata.columns["Active Time"],
                _format("%s - %s", _date("%H:%M", set.starttime), _date("%H:%M", set.endtime)),
                self.metadata.columns.Percent
            )
        end
    end
end)