assert(Skada, "Skada not found!")

local Skada = Skada
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local mod = Skada:NewModule("BarDisplay", "SpecializedLibBars-1.0")
local libwindow = LibStub("LibWindow-1.1")
local FlyPaper = LibStub:GetLibrary("LibFlyPaper-1.1", true)
local LSM = LibStub("LibSharedMedia-3.0")

local tinsert, tsort = table.insert, table.sort

mod.name = L["Bar display"]
mod.description = L["Bar display is the normal bar window used by most damage meters. It can be extensively styled."]
Skada:AddDisplaySystem("bar", mod)

-- specs and coordinates
local spec_icon_file = [[Interface\AddOns\Skada\media\textures\icon-specs]]
local spec_icon_tcoords = {
    [1] = {0.75, 0.875, 0.125, 0.25}, --> pet
    [2] = {0.875, 1, 0.125, 0.25}, --> unknown
    [3] = {0.625, 0.75, 0.125, 0.25}, --> monster
    [102] = {0.375, 0.5, 0, 0.125}, --> druid balance
    [103] = {0.5, 0.625, 0, 0.125}, --> druid feral
    [104] = {0.625, 0.75, 0, 0.125}, --> druid tank
    [105] = {0.75, 0.875, 0, 0.125}, --> druid restoration
    [250] = {0, 0.125, 0, 0.125}, --> blood dk
    [251] = {0.125, 0.25, 0, 0.125}, --> frost dk
    [252] = {0.25, 0.375, 0, 0.125}, --> unholy dk
    [253] = {0.875, 1, 0, 0.125}, --> hunter beast mastery
    [254] = {0, 0.125, 0.125, 0.25}, --> hunter marksmalship
    [255] = {0.125, 0.25, 0.125, 0.25}, --> hunter survival
    [256] = {0.375, 0.5, 0.25, 0.375}, --> priest discipline
    [257] = {0.5, 0.625, 0.25, 0.375}, --> priest holy
    [258] = {0.625, 0.75, 0.25, 0.375}, --> priest shadow
    [259] = {0.75, 0.875, 0.25, 0.375}, --> rogue assassination
    [260] = {0.875, 1, 0.25, 0.375}, --> rogue combat
    [261] = {0, 0.125, 0.375, 0.5}, --> rogue subtlty
    [262] = {0.125, 0.25, 0.375, 0.5}, --> shaman elemental
    [263] = {0.25, 0.375, 0.375, 0.5}, --> shamel enhancement
    [264] = {0.375, 0.5, 0.375, 0.5}, --> shaman restoration
    [265] = {0.5, 0.625, 0.375, 0.5}, --> warlock affliction
    [266] = {0.625, 0.75, 0.375, 0.5}, --> warlock demonology
    [267] = {0.75, 0.875, 0.375, 0.5}, --> warlock destruction
    [62] = {0.25, 0.375, 0.125, 0.25}, --> mage arcane
    [63] = {0.375, 0.5, 0.125, 0.25}, --> mage fire
    [64] = {0.5, 0.625, 0.125, 0.25}, --> mage frost
    [65] = {0, 0.125, 0.25, 0.375}, --> paladin holy
    [66] = {0.125, 0.25, 0.25, 0.375}, --> paladin protection
    [70] = {0.25, 0.375, 0.25, 0.375}, --> paladin ret
    [71] = {0.875, 1, 0.375, 0.5}, --> warrior arms
    [72] = {0, 0.125, 0.5, 0.625}, --> warrior fury
    [73] = {0.125, 0.25, 0.5, 0.625} --> warrior protection
}

-- role icons and coordinates
local role_icon_file, role_icon_tcoords = [[Interface\LFGFrame\UI-LFG-ICON-PORTRAITROLES]]

-- classes file and coordinates
local class_icon_file, class_icon_tcoords = [[Interface\AddOns\Skada\media\textures\icon-classes]]

function mod:Create(window)
    -- Re-use bargroup if it exists.
    local bargroup = mod:GetBarGroup(window.db.name)

    -- Save a reference to window in bar group. Needed for some nasty callbacks.
    if bargroup then
        -- Clear callbacks.
        bargroup.callbacks = LibStub:GetLibrary("CallbackHandler-1.0"):New(bargroup)
    else
        bargroup = mod:NewBarGroup(
            window.db.name,
            nil,
            window.db.background.height,
            window.db.barwidth,
            window.db.barheight,
            "SkadaBarWindow" .. window.db.name
        )

        -- Add window buttons.
        bargroup:AddButton(
            L["Configure"],
            L["Opens the configuration window."],
            "Interface\\Addons\\Skada\\media\\textures\\icon-config",
            "Interface\\Addons\\Skada\\media\\textures\\icon-config",
            function() Skada:OpenMenu(bargroup.win) end
        )

        bargroup:AddButton(
            RESET,
            L["Resets all fight data except those marked as kept."],
            "Interface\\Addons\\Skada\\media\\textures\\icon-reset",
            "Interface\\Addons\\Skada\\media\\textures\\icon-reset",
            function() Skada:ShowPopup(bargroup.win) end
        )

        bargroup:AddButton(
            L["Segment"],
            L["Jump to a specific segment."],
            "Interface\\Buttons\\UI-GuildButton-PublicNote-Up",
            "Interface\\Buttons\\UI-GuildButton-PublicNote-Up",
            function() Skada:SegmentMenu(bargroup.win) end
        )

        bargroup:AddButton(
            L["Mode"],
            L["Jump to a specific mode."],
            "Interface\\GROUPFRAME\\UI-GROUP-MAINASSISTICON",
            "Interface\\GROUPFRAME\\UI-GROUP-MAINASSISTICON",
            function() Skada:ModeMenu(bargroup.win) end
        )

        bargroup:AddButton(
            L["Report"],
            L["Opens a dialog that lets you report your data to others in various ways."],
            "Interface\\Buttons\\UI-GuildButton-MOTD-Up",
            "Interface\\Buttons\\UI-GuildButton-MOTD-Up",
            function() Skada:OpenReportWindow(bargroup.win) end
        )

        bargroup:AddButton(
            L["Stop"],
            L["Stops or resumes the current segment. Useful for discounting data after a wipe. Can also be set to automatically stop in the settings."],
            "Interface\\CHATFRAME\\ChatFrameExpandArrow",
            "Interface\\CHATFRAME\\ChatFrameExpandArrow",
            function()
                if Skada.current and Skada.current.stopped then
                    Skada:ResumeSegment()
                elseif Skada.current then
                    Skada:StopSegment()
                end
            end
        )
    end
    bargroup.win = window
    bargroup.RegisterCallback(mod, "AnchorMoved")
    bargroup.RegisterCallback(mod, "WindowResizing")
    bargroup.RegisterCallback(mod, "WindowResized")
    bargroup:EnableMouse(true)
    bargroup:SetScript("OnMouseDown", function(_, button)
        if IsShiftKeyDown() then
            Skada:OpenMenu(window)
        elseif button == "RightButton" then
            window:RightClick()
        end
    end)
    bargroup.button:SetScript("OnClick", function(_, button)
        if IsShiftKeyDown() then
            Skada:OpenMenu(window)
        elseif button == "RightButton" then
            window:RightClick()
        end
    end)

    bargroup:HideIcon()

    local titletext = bargroup.button:GetFontString()
    titletext:SetWordWrap(false)
    titletext:SetPoint("LEFT", bargroup.button, "LEFT", 5, 1)
    titletext:SetJustifyH("LEFT")
    bargroup.button:SetHeight(window.db.title.height or 15)

    -- Register with LibWindow-1.0.
    libwindow.RegisterConfig(bargroup, window.db)

    -- Restore window position.
    libwindow.RestorePosition(bargroup)

    window.bargroup = bargroup

    if not class_icon_tcoords then -- amortized class icon coordinate adjustment
        class_icon_tcoords = {}
        for class, coords in pairs(CLASS_ICON_TCOORDS) do
            class_icon_tcoords[class] = coords
        end
        class_icon_tcoords.ENEMY = {0, 0.25, 0.75, 1}
        class_icon_tcoords.MONSTER = {0, 0.25, 0.75, 1}

        class_icon_tcoords.UNKNOWN = {0.5, 0.75, 0.75, 1}
        class_icon_tcoords.UNGROUPPLAYER = {0.5, 0.75, 0.75, 1}

        class_icon_tcoords.PET = {0.25, 0.49609375, 0.75, 1}
        class_icon_tcoords.PLAYER = {0.75, 1, 0.75, 1}

        class_icon_tcoords.Alliance = {0.49609375, 0.7421875, 0.5, 0.75}
        class_icon_tcoords.Horde = {0.7421875, 0.98828125, 0.5, 0.75}
    end

    if not role_icon_tcoords then
        role_icon_tcoords = {
            DAMAGER = {0.3125, 0.63, 0.3125, 0.63},
            HEALER = {0.3125, 0.63, 0.015625, 0.3125},
            TANK = {0, 0.296875, 0.3125, 0.63},
            LEADER = {0, 0.296875, 0.015625, 0.3125},
            NONE = ""
        }
    end
end

function mod:Destroy(win)
    win.bargroup:Hide()
    win.bargroup = nil
end

function mod:Wipe(win)
    win.bargroup:SetSortFunction(nil)
    win.bargroup:SetBarOffset(0)

    local bars = win.bargroup:GetBars()
    if bars then
        for _, bar in pairs(bars) do
            bar:Hide()
            win.bargroup:RemoveBar(bar)
        end
    end

    win.bargroup:SortBars()
end

function mod:Show(win)
    win.bargroup:Show()
    win.bargroup:SortBars()
end

function mod:Hide(win)
    win.bargroup:Hide()
end

function mod:IsShown(win)
    return win.bargroup:IsShown()
end

function mod:SetTitle(win, title)
    win.bargroup.button:SetText(title)
end

do
    -- these anchors are used to correctly position the windows due
    -- to the title bar overlapping.
    local Xanchors = {LT = true, LB = true, LC = true, RT = true, RB = true, RC = true}
    local Yanchors = {TL = true, TR = true, TC = true, BL = true, BR = true, BC = true}

    function mod:AnchorMoved(_, group, x, y)
        if FlyPaper and group.win.db.snapto and not group.locked then
            -- correction due to stupid border texture
            local offset = group.win.db.background.borderthickness
            local anchor, name, frame = FlyPaper.StickToClosestFrameInGroup(group, "Skada", nil, offset, offset)

            if anchor and frame then
                frame.win.db.snapped[group.win.db.name] = true
                group.win.db.snapped[name] = nil

                -- change the width of the window accordingly
                if Yanchors[anchor] then
                    -- we change things related to height
                    local width = frame.win.db.barwidth
                    group.win.db.barwidth = width
                    group:SetLength(width)
                elseif Xanchors[anchor] then
                    -- window height
                    local height = frame.win.db.background.height
                    group.win.db.background.height = height
                    group:SetHeight(height)

                    -- title bar height
                    local titleheight = frame.win.db.title.height
                    group.win.db.title.height = titleheight
                    group.button:SetHeight(titleheight)
                    group:AdjustButtons()

                    -- bars height
                    local barheight = frame.win.db.barheight
                    group.win.db.barheight = barheight
                    group:SetBarHeight(barheight)

                    group:SortBars()
                end
            else
                for _, win in ipairs(Skada:GetWindows()) do
                    if win.db.display == "bar" and win.db.snapped and win.db.snapped[group.win.db.name] then
                        win.db.snapped[group.win.db.name] = nil
                    end
                end
            end
        end
        libwindow.SavePosition(group)
    end
end

function mod:WindowResized(_, group)
    libwindow.SavePosition(group)
    group.win.db.background.height = group:GetHeight()
    group.win.db.barwidth = group:GetWidth()
    if FlyPaper then
        local offset = group.win.db.background.borderthickness
        for _, win in ipairs(Skada:GetWindows()) do
            if win.db.display == "bar" and win.bargroup:IsShown() and group.win.db.snapped[win.db.name] then
                win.bargroup.callbacks:Fire("AnchorMoved", win.bargroup)
            end
        end
    end
    Skada:ApplySettings()
end

do
    local function getNumberOfBars(win)
        local bars = win.bargroup:GetBars()
        local n = 0
        for _, _ in pairs(bars) do
            n = n + 1
        end
        return n
    end

    local function OnMouseWheel(frame, direction)
        local win = frame.win
        local maxbars = win.db.background.height / (win.db.barheight + win.db.barspacing)
        if direction == 1 and win.bargroup:GetBarOffset() > 0 then
            win.bargroup:SetBarOffset(win.bargroup:GetBarOffset() - 1)
        elseif direction == -1 and ((getNumberOfBars(win) - maxbars - win.bargroup:GetBarOffset() + 1) > 0) then
            win.bargroup:SetBarOffset(win.bargroup:GetBarOffset() + 1)
        end
    end

    function mod:OnMouseWheel(win, frame, direction)
        if not frame then
            mod.framedummy = mod.framedummy or {}
            mod.framedummy.win = win
            frame = mod.framedummy
        end
        OnMouseWheel(frame, direction)
    end

    function mod:CreateBar(win, name, label, value, maxvalue, icon, o)
        local bar, isnew = win.bargroup:NewCounterBar(name, label, value, maxvalue, icon, o)
        bar.win = win
        bar:EnableMouseWheel(true)
        bar:SetScript("OnMouseWheel", OnMouseWheel)
        bar.iconFrame:SetScript("OnEnter", nil)
        bar.iconFrame:SetScript("OnLeave", nil)
        bar.iconFrame:SetScript("OnMouseDown", nil)
        bar.iconFrame:EnableMouse(false)
        return bar, isnew
    end
end

-- ======================================================= --

do
    local function inserthistory(win)
        tinsert(win.history, win.selectedmode)
        if win.child then
            inserthistory(win.child)
        end
    end

    local function onEnter(win, id, label, mode)
        mode:Enter(win, id, label)
        if win.child then
            onEnter(win.child, id, label, mode)
        end
    end

    local function showmode(win, id, label, mode)
        if win.selectedmode then
            inserthistory(win)
        end

        if mode.Enter then
            onEnter(win, id, label, mode)
        end

        win:DisplayMode(mode)
    end

    local function BarClickIgnore(bar, button)
        if bar.win and button == "RightButton" then
            bar.win:RightClick()
        end
    end

    local function BarClick(bar, button)
        local win, id, label = bar.win, bar.id, bar.text

        if button == "RightButton" and IsShiftKeyDown() then
            Skada:OpenMenu(win)
        elseif button == "RightButton" and IsAltKeyDown() then
            Skada:ModeMenu(win)
        elseif button == "RightButton" and IsControlKeyDown() then
            Skada:SegmentMenu(win)
        elseif win.metadata.click then
            win.metadata.click(win, id, label, button)
        elseif button == "RightButton" then
            win:RightClick()
        elseif win.metadata.click2 and IsShiftKeyDown() then
            showmode(win, id, label, win.metadata.click2)
        elseif win.metadata.click3 and IsControlKeyDown() then
            showmode(win, id, label, win.metadata.click3)
        elseif win.metadata.click1 then
            showmode(win, id, label, win.metadata.click1)
        end
    end

    local ttactive = false

    local function BarEnter(bar)
        local win, id, label = bar.win, bar.id, bar.text
        ttactive = true
        Skada:SetTooltipPosition(GameTooltip, win.bargroup, win.db.display)
        Skada:ShowTooltip(win, id, label)
    end

    local function BarLeave()
        if ttactive then
            GameTooltip:Hide()
            ttactive = false
        end
    end

    local function BarResize(bar)
        if bar.bgwidth then
            bar.bgtexture:SetWidth(bar.bgwidth * bar:GetWidth())
        else
            bar:SetScript("OnSizeChanged", bar.OnSizeChanged)
        end
        bar:OnSizeChanged()
    end

    local function BarIconEnter(icon)
        local bar = icon.bar
        local win = bar.win
        if bar.link and win and win.bargroup then
            Skada:SetTooltipPosition(GameTooltip, win.bargroup, win.db.display)
            GameTooltip:SetHyperlink(bar.link)
            GameTooltip:Show()
        end
    end

    local function BarIconMouseDown(icon)
        local bar = icon.bar
        if not IsShiftKeyDown() or not bar.link then
            return
        end
        local activeEditBox = ChatEdit_GetActiveWindow()
        if activeEditBox then
            ChatEdit_InsertLink(bar.link)
        else
            ChatFrame_OpenChat(bar.link, DEFAULT_CHAT_FRAME)
        end
    end

    local function HideGameTooltip()
        GameTooltip:Hide()
    end

    local function value_sort(a, b)
        if not a or a.value == nil then
            return false
        elseif not b or b.value == nil then
            return true
        else
            return a.value > b.value
        end
    end

    local function bar_order_sort(a, b)
        return a and b and a.order and b.order and a.order < b.order
    end

    function mod:Update(win)
        if not win or not win.bargroup then
            return
        end
        win.bargroup.button:SetText(win.metadata.title)

        if win.metadata.showspots then
            tsort(win.dataset, value_sort)
        end

        local hasicon = false
        for _, data in ipairs(win.dataset) do
            if
                (data.icon and not data.ignore) or (data.spec and win.db.specicons) or
                    (data.class and win.db.classicons) or
                    (data.role and win.db.roleicons)
             then
                hasicon = true
            end
        end

        if hasicon and not win.bargroup.showIcon then
            win.bargroup:ShowIcon()
        end
        if not hasicon and win.bargroup.showIcon then
            win.bargroup:HideIcon()
        end

        if win.metadata.wipestale then
            local bars = win.bargroup:GetBars()
            if bars then
                for _, bar in pairs(bars) do
                    bar.checked = false
                end
            end
        end

        local nr = 1
        for i, data in ipairs(win.dataset) do
            if data.id then
                local barid = data.id
                local barlabel = data.label

                local bar = win.bargroup:GetBar(barid)

                if bar and bar.missingclass and data.class and not data.ignore then
                    bar:Hide()
                    win.bargroup:RemoveBar(bar)
                    bar.missingclass = nil
                    bar = nil
                end

                if bar then
                    bar:SetValue(data.value)
                    bar:SetMaxValue(win.metadata.maxvalue or 1)
                else
                    -- Initialization of bars.
                    bar = mod:CreateBar(win, barid, barlabel, data.value, win.metadata.maxvalue or 1, data.icon, false)
                    bar.id = data.id
                    bar.text = barlabel
                    bar.fixed = false

                    if not data.ignore then
                        if data.icon then
                            bar:ShowIcon()

                            bar.link = nil
                            if data.spellid then
                                bar.link = GetSpellLink(data.spellid)
                            elseif data.hyperlink then
                                bar.link = data.hyperlink
                            end

                            if bar.link then
                                bar.iconFrame.bar = bar
                                bar.iconFrame:EnableMouse(true)
                                bar.iconFrame:SetScript("OnEnter", BarIconEnter)
                                bar.iconFrame:SetScript("OnLeave", HideGameTooltip)
                                bar.iconFrame:SetScript("OnMouseDown", BarIconMouseDown)
                            end
                        end

                        bar:EnableMouse(true)
                        bar:SetScript("OnEnter", BarEnter)
                        bar:SetScript("OnLeave", BarLeave)
                        bar:SetScript("OnMouseDown", BarClick)
                    else
                        bar:SetScript("OnEnter", nil)
                        bar:SetScript("OnLeave", nil)
                        bar:SetScript("OnMouseDown", BarClickIgnore)
                    end
                    bar:SetValue(data.value)

                    if not data.class and (win.db.classicons or win.db.classcolorbars or win.db.classcolortext) then
                        bar.missingclass = true
                    else
                        bar.missingclass = nil
                    end

                    if data.spec and win.db.specicons and spec_icon_tcoords[data.spec] then
                        bar:ShowIcon()
                        bar:SetIconWithCoord(spec_icon_file, spec_icon_tcoords[data.spec])
                    elseif data.role and data.role ~= "NONE" and win.db.roleicons then
                        bar:ShowIcon()
                        bar:SetIconWithCoord(role_icon_file, role_icon_tcoords[data.role])
                    elseif data.class and win.db.classicons and class_icon_tcoords[data.class] then
                        bar:ShowIcon()
                        bar:SetIconWithCoord(class_icon_file, class_icon_tcoords[data.class])
                    elseif not data.ignore and not data.spellid then
                        if data.icon and not bar:IsIconShown() then
                            bar:ShowIcon()
                            bar:SetIconWithCoord(class_icon_file, class_icon_tcoords["PLAYER"])
                        end
                    end

                    -- set bar color
                    local color = win.db.barcolor or Skada.classcolors.NEUTRAL

                    if data.color then
                        color = data.color
                    elseif data.spellschool and win.db.spellschoolcolors then
                        color = Skada.schoolcolors[data.spellschool] or color
                    elseif data.class and win.db.classcolorbars then
                        color = Skada.classcolors[data.class] or color
                    end
                    bar:SetColorAt(0, color.r, color.g, color.b, color.a or 1)

                    if data.class and win.db.classcolortext then
                        local c = Skada.classcolors[data.class]
                        if c then
                            bar.label:SetTextColor(c.r, c.g, c.b, c.a or 1)
                            bar.timerLabel:SetTextColor(c.r, c.g, c.b, c.a or 1)
                        end
                    else
                        bar.label:SetTextColor(1, 1, 1, 1)
                        bar.timerLabel:SetTextColor(1, 1, 1, 1)
                    end

                    if Skada.db.profile.showself and data.id and data.id == UnitGUID("player") then
                        bar.fixed = true
                    end

                    if win.db.spark then
                        bar.spark:Show()
                    else
                        bar.spark:Hide()
                    end
                end

                if win.metadata.ordersort then
                    bar.order = i
                end

                Skada.callbacks:Fire("BarUpdate", win, data, bar, nr)

                if win.metadata.showspots and Skada.db.profile.showranks and not data.ignore then
                    if win.db.barorientation == 1 then
                        bar:SetLabel(("%d. %s"):format(nr, data.label))
                    else
                        bar:SetLabel(("%s .%d"):format(data.label, nr))
                    end
                else
                    bar:SetLabel(data.label)
                end
                bar:SetTimerLabel(data.valuetext)

                if win.metadata.wipestale then
                    bar.checked = true
                end

                if data.emphathize and bar.emphathize_set ~= true then
                    bar:SetFont(nil, nil, "OUTLINE", nil, nil, "OUTLINE")
                    bar.emphathize_set = true
                elseif not data.emphathize and bar.emphathize_set ~= false then
                    bar:SetFont(nil, nil, win.db.barfontflags, nil, nil, win.db.numfontflags)
                    bar.emphathize_set = false
                end

                if data.backgroundcolor then
                    bar.bgtexture:SetVertexColor(
                        data.backgroundcolor.r,
                        data.backgroundcolor.g,
                        data.backgroundcolor.b,
                        data.backgroundcolor.a or 1
                    )
                end

                if data.backgroundwidth then
                    bar.bgtexture:ClearAllPoints()
                    bar.bgtexture:SetPoint("BOTTOMLEFT")
                    bar.bgtexture:SetPoint("TOPLEFT")
                    bar.bgwidth = data.backgroundwidth
                    bar:SetScript("OnSizeChanged", BarResize)
                    BarResize(bar)
                else
                    bar.bgwidth = nil
                end

                if not data.ignore then
                    nr = nr + 1
                end
            end
        end

        if win.metadata.wipestale then
            local bars = win.bargroup:GetBars()
            for name, bar in pairs(bars) do
                if not bar.checked then
                    win.bargroup:RemoveBar(bar)
                end
            end
        end

        if win.metadata.ordersort then
            win.bargroup:SetSortFunction(bar_order_sort)
            win.bargroup:SortBars()
        else
            win.bargroup:SetSortFunction(nil)
            win.bargroup:SortBars()
        end
    end
end

-- ======================================================= --

do
    local titlebackdrop = {}
    local windowbackdrop = {}

    local function move(self, button)
        local group = self:GetParent()
        if group then
            if button == "MiddleButton" or IsAltKeyDown() then
                group.stretching = true
                group:SetBackdropColor(0, 0, 0, 1)
                group:SetFrameStrata("TOOLTIP")
                group:StartSizing("TOP")
                group:SetScript("OnUpdate", group.SortBars)
            elseif button == "LeftButton" and not group.locked then
                self.startX = group:GetLeft()
                self.startY = group:GetTop()
                group:StartMoving()

                -- move sticked windows.
                local offset = group.win.db.background.borderthickness
                for _, win in ipairs(Skada:GetWindows()) do
                    if win.db.display == "bar" and win.bargroup:IsShown() and group.win.db.snapped[win.db.name] then
                        FlyPaper.Stick(win.bargroup, group, nil, offset, offset)
                        win.bargroup.button.startX = win.bargroup:GetLeft()
                        win.bargroup.button.startY = win.bargroup:GetTop()
                        move(win.bargroup.button, "LeftButton")
                    end
                end
            end
        end
    end

    local function stopMove(self, button)
        local group = self:GetParent()
        if group then
            if button == "MiddleButton" or group.stretching then
                group.stretching = nil
                local color = group.win.db.background.color
                group:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
                group:SetFrameStrata(group.win.db.strata)
                group:StopMovingOrSizing()
                group:SetScript("OnUpdate", nil)
                mod:ApplySettings(group.win)
            elseif button == "LeftButton" and not group.locked then
                group:StopMovingOrSizing()
                local endX = group:GetLeft()
                local endY = group:GetTop()
                if self.startX ~= endX or self.startY ~= endY then
                    group.callbacks:Fire("AnchorMoved", group, endX, endY)
                    for _, win in ipairs(Skada:GetWindows()) do
                        if win.db.display == "bar" and win.bargroup:IsShown() and group.win.db.snapped[win.db.name] then
                            local xOfs, yOfs = win.bargroup:GetLeft(), win.bargroup:GetTop()
                            if win.bargroup.startX ~= xOfs or win.bargroup.startY ~= yOfs then
                                win.bargroup.callbacks:Fire("AnchorMoved", win.bargroup, xOfs, yOfs)
                                stopMove(win.bargroup.button, "LeftButton")
                            end
                        end
                    end
                end
            end
        end
    end

    -- Called by Skada windows when window settings have changed.
    function mod:ApplySettings(win)
        if not win or not win.bargroup then
            return
        end

        local g = win.bargroup
        g:SetFrameLevel(1)

        local p = win.db
        g:ReverseGrowth(p.reversegrowth)
        g:SetOrientation(p.barorientation)
        g:SetBarHeight(p.barheight)
        g:SetHeight(p.background.height)
        g:SetWidth(p.barwidth)
        g:SetLength(p.barwidth)
        g:SetTexture(p.bartexturepath or LSM:Fetch("statusbar", p.bartexture))
        g:SetBarBackgroundColor(p.barbgcolor.r, p.barbgcolor.g, p.barbgcolor.b, p.barbgcolor.a or 0.6)

        g:SetFont(
            p.barfontpath or LSM:Fetch("font", p.barfont),
            p.barfontsize,
            p.barfontflags,
            p.numfontpath or LSM:Fetch("font", p.numfont),
            p.numfontsize,
            p.numfontflags
        )

        g:SetSpacing(p.barspacing)
        g:UnsetAllColors()
        g:SetColorAt(0, p.barcolor.r, p.barcolor.g, p.barcolor.b, p.barcolor.a)

        if p.barslocked then
            g:Lock()
        else
            g:Unlock()
        end

        if p.strata then
            g:SetFrameStrata(p.strata)
        end

        -- Header
        local fo = CreateFont("TitleFont" .. win.db.name)
        fo:SetFont(p.title.fontpath or LSM:Fetch("font", p.title.font), p.title.fontsize, p.title.fontflags)
        if p.title.textcolor then
            fo:SetTextColor(p.title.textcolor.r, p.title.textcolor.g, p.title.textcolor.b, p.title.textcolor.a)
        end
        g.button:SetNormalFontObject(fo)

        titlebackdrop.bgFile = LSM:Fetch("statusbar", p.title.texture)
        titlebackdrop.tile = false
        titlebackdrop.tileSize = 0
        titlebackdrop.edgeSize = p.title.borderthickness
        g.button:SetBackdrop(titlebackdrop)

        local color = p.title.color
        g.button:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
        g.button:SetHeight(p.title.height or 15)

        Skada:ApplyBorder(g.button, p.title.bordertexture, p.title.bordercolor, p.title.borderthickness)

        if p.enabletitle then
            g:ShowAnchor()

            g:ShowButton(L["Configure"], p.buttons.menu)
            g:ShowButton(RESET, p.buttons.reset)
            g:ShowButton(L["Segment"], p.buttons.segment)
            g:ShowButton(L["Mode"], p.buttons.mode)
            g:ShowButton(L["Report"], p.buttons.report)
            g:ShowButton(L["Stop"], p.buttons.stop)
            g:AdjustButtons()

            if p.title.hovermode then
                for _, btn in ipairs(g.buttons) do
                    btn:SetAlpha(0)
                end
                g.button:SetScript("OnEnter", function(self)
                    for _, btn in ipairs(g.buttons) do
                        btn:SetAlpha(0.25)
                    end
                end)
                g.button:SetScript("OnLeave", function(self)
                    for _, btn in ipairs(g.buttons) do
                        btn:SetAlpha(MouseIsOver(self) and 0.25 or 0)
                    end
                end)
            else
                for _, btn in ipairs(g.buttons) do
                    btn:SetAlpha(0.25)
                end
                g.button:SetScript("OnEnter", nil)
                g.button:SetScript("OnLeave", nil)
            end
        else
            g:HideAnchor()
        end

        for _, bar in pairs(g:GetBars()) do
            if p.spark then
                bar.spark:Show()
            else
                bar.spark:Hide()
            end
        end

        -- Window border
        Skada:ApplyBorder(g, p.background.bordertexture, p.background.bordercolor, p.background.borderthickness)

        windowbackdrop.bgFile = p.background.texturepath or LSM:Fetch("background", p.background.texture)
        windowbackdrop.tile = p.background.tile
        windowbackdrop.tileSize = p.background.tilesize
        windowbackdrop.insets = {left = 0, right = 0, top = 0, bottom = 0}
        if p.enabletitle then
            if p.reversegrowth then
                windowbackdrop.insets.top = 0
                windowbackdrop.insets.bottom = p.title.height
            else
                windowbackdrop.insets.top = p.title.height
                windowbackdrop.insets.bottom = 0
            end
        end
        g:SetBackdrop(windowbackdrop)

        local bgcolor = p.background.color
        g:SetBackdropColor(bgcolor.r, bgcolor.g, bgcolor.b, bgcolor.a or 1)

        if FlyPaper and p.snapto then
            FlyPaper.AddFrame("Skada", p.name, g)
            g.button:SetScript("OnMouseDown", move)
            g.button:SetScript("OnMouseUp", stopMove)
        end

        g:SetEnableMouse(not p.clickthrough)
        g:SetSmoothing(p.smoothing)
        libwindow.SetScale(g, p.scale)
        g:SortBars()
    end

    function mod:WindowResizing(_, group)
        if FlyPaper then
            local offset = group.win.db.background.borderthickness
            for _, win in ipairs(Skada:GetWindows()) do
                if win.db.display == "bar" and win.bargroup:IsShown() and group.win.db.snapped[win.db.name] then
                    FlyPaper.Stick(win.bargroup, group, nil, offset, offset)
                end
            end
        end
    end
end

function mod:AddDisplayOptions(win, options)
    local db = win.db

    options.baroptions = {
        type = "group",
        name = L["Bars"],
        order = 1,
        get = function(i)
            return db[i[#i]]
        end,
        set = function(i, val)
            db[i[#i]] = val
            Skada:ApplySettings()
        end,
        args = {
            barfont = {
                type = "select",
                dialogControl = "LSM30_Font",
                name = L["Bar font"],
                desc = L["The font used by all bars."],
                order = 1,
                width = "full",
                values = AceGUIWidgetLSMlists.font
            },
            barfontsize = {
                type = "range",
                name = L["Bar font size"],
                desc = L["The font size of all bars."],
                order = 2,
                width = "full",
                min = 6,
                max = 40,
                step = 1
            },
            barfontflags = {
                type = "select",
                name = L["Font flags"],
                desc = L["Sets the font flags."],
                order = 3,
                width = "full",
                values = {
                    [""] = NONE,
                    ["OUTLINE"] = L["Outline"],
                    ["THICKOUTLINE"] = L["Thick outline"],
                    ["MONOCHROME"] = L["Monochrome"],
                    ["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
                }
            },
            numfont = {
                type = "select",
                dialogControl = "LSM30_Font",
                name = L["Values font"],
                desc = L["The font used by bar values."],
                order = 4,
                width = "full",
                values = AceGUIWidgetLSMlists.font
            },
            numfontsize = {
                type = "range",
                name = L["Values font size"],
                desc = L["The font size of bar values."],
                order = 5,
                width = "full",
                min = 6,
                max = 40,
                step = 1
            },
            numfontflags = {
                type = "select",
                name = L["Font flags"],
                desc = L["Sets the font flags."],
                order = 6,
                width = "full",
                values = {
                    [""] = NONE,
                    ["OUTLINE"] = L["Outline"],
                    ["THICKOUTLINE"] = L["Thick outline"],
                    ["MONOCHROME"] = L["Monochrome"],
                    ["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
                }
            },
            bartexture = {
                type = "select",
                dialogControl = "LSM30_Statusbar",
                name = L["Bar texture"],
                desc = L["The texture used by all bars."],
                order = 7,
                width = "full",
                values = AceGUIWidgetLSMlists.statusbar
            },
            barspacing = {
                type = "range",
                name = L["Bar spacing"],
                desc = L["Distance between bars."],
                order = 8,
                width = "full",
                min = 0,
                max = 10,
                step = 1
            },
            barheight = {
                type = "range",
                name = L["Bar height"],
                desc = L["The height of the bars."],
                order = 9,
                width = "full",
                min = 10,
                max = 40,
                step = 1
            },
            barwidth = {
                type = "range",
                name = L["Bar width"],
                desc = L["The width of the bars."],
                order = 10,
                width = "full",
                min = 80,
                max = 400,
                step = 1
            },
            barorientation = {
                type = "select",
                name = L["Bar orientation"],
                desc = L["The direction the bars are drawn in."],
                order = 11,
                width = "full",
                values = {[1] = L["Left to right"], [3] = L["Right to left"]}
            },
            reversegrowth = {
                type = "toggle",
                name = L["Reverse bar growth"],
                desc = L["Bars will grow up instead of down."],
                order = 12,
                width = "full"
            },
            color = {
                type = "color",
                name = L["Bar color"],
                desc = L["Choose the default color of the bars."],
                order = 13,
                width = "full",
                hasAlpha = true,
                get = function()
                    return db.barcolor.r, db.barcolor.g, db.barcolor.b, db.barcolor.a
                end,
                set = function(_, r, g, b, a)
                    db.barcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
                    Skada:ApplySettings()
                end
            },
            bgcolor = {
                type = "color",
                name = L["Background color"],
                desc = L["Choose the background color of the bars."],
                order = 14,
                width = "full",
                hasAlpha = true,
                get = function(_)
                    return db.barbgcolor.r, db.barbgcolor.g, db.barbgcolor.b, db.barbgcolor.a
                end,
                set = function(_, r, g, b, a)
                    db.barbgcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
                    Skada:ApplySettings()
                end
            },
            spellschoolcolors = {
                type = "toggle",
                name = L["Spell school colors"],
                desc = L["Use spell school colors where applicable."],
                order = 15,
                width = "full"
            },
            classcolorbars = {
                type = "toggle",
                name = L["Class color bars"],
                desc = L["When possible, bars will be colored according to player class."],
                order = 16,
                width = "full"
            },
            classcolortext = {
                type = "toggle",
                name = L["Class color text"],
                desc = L["When possible, bar text will be colored according to player class."],
                order = 17,
                width = "full"
            },
            classicons = {
                type = "toggle",
                name = L["Class icons"],
                desc = L["Use class icons where applicable."],
                order = 18,
                width = "full"
            },
            roleicons = {
                type = "toggle",
                name = L["Role icons"],
                desc = L["Use role icons where applicable."],
                order = 19,
                width = "full"
            },
            specicons = {
                type = "toggle",
                name = L["Spec icons"],
                desc = L["Use specialization icons where applicable."],
                order = 20,
                width = "full"
            },
            spark = {
                type = "toggle",
                name = L["Show spark effect"],
                order = 21,
                width = "full"
            },
            clickthrough = {
                type = "toggle",
                name = L["Clickthrough"],
                desc = L["Disables mouse clicks on bars."],
                order = 22,
                width = "full"
            },
            smoothing = {
                type = "toggle",
                name = L["Smooth bars"],
                desc = L["Animate bar changes smoothly rather than immediately."],
                order = 23,
                width = "full"
            }
        }
    }

    options.titleoptions = {
        type = "group",
        name = L["Title bar"],
        order = 2,
        get = function(i)
            return db.title[i[#i]]
        end,
        set = function(i, val)
            db.title[i[#i]] = val
            Skada:ApplySettings()
        end,
        args = {
            enable = {
                type = "toggle",
                name = L["Enable"],
                desc = L["Enables the title bar."],
                order = 1,
                get = function()
                    return db.enabletitle
                end,
                set = function()
                    db.enabletitle = not db.enabletitle
                    Skada:ApplySettings()
                end
            },
            titleset = {
                type = "toggle",
                name = L["Include set"],
                desc = L["Include set name in title bar"],
                order = 2,
                get = function()
                    return db.titleset
                end,
                set = function()
                    db.titleset = not db.titleset
                    Skada:ApplySettings()
                end
            },
            combattimer = {
                type = "toggle",
                name = L["Encounter timer"],
                desc = L["When enabled, a stopwatch is shown on the left side of the text."],
                order = 3,
                get = function()
                    return db.combattimer
                end,
                set = function()
                    db.combattimer = not db.combattimer
                    Skada:ApplySettings()
                end
            },
            height = {
                type = "range",
                name = L["Title height"],
                desc = L["The height of the title frame."],
                order = 4,
                width = "full",
                min = 10,
                max = 50,
                step = 1
            },
            font = {
                type = "select",
                dialogControl = "LSM30_Font",
                name = L["Bar font"],
                desc = L["The font used by all bars."],
                values = AceGUIWidgetLSMlists.font,
                order = 5,
                width = "full"
            },
            fontsize = {
                type = "range",
                name = L["Title font size"],
                desc = L["The font size of the title bar."],
                order = 6,
                width = "full",
                min = 7,
                max = 40,
                step = 1
            },
            fontflags = {
                type = "select",
                name = L["Font flags"],
                desc = L["Sets the font flags."],
                order = 7,
                width = "full",
                values = {
                    [""] = NONE,
                    ["OUTLINE"] = L["Outline"],
                    ["THICKOUTLINE"] = L["Thick outline"],
                    ["MONOCHROME"] = L["Monochrome"],
                    ["OUTLINEMONOCHROME"] = L["Outlined monochrome"]
                }
            },
            textcolor = {
                type = "color",
                name = L["Title color"],
                desc = L["The text color of the title."],
                order = 8,
                width = "full",
                hasAlpha = true,
                get = function()
                    local c = db.title.textcolor or {r = 0.9, g = 0.9, b = 0.9, a = 1}
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    db.title.textcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
                    Skada:ApplySettings()
                end
            },
            texture = {
                type = "select",
                dialogControl = "LSM30_Statusbar",
                name = L["Background texture"],
                desc = L["The texture used as the background of the title."],
                order = 9,
                width = "full",
                values = AceGUIWidgetLSMlists.statusbar
            },
            color = {
                type = "color",
                name = L["Background color"],
                desc = L["The background color of the title."],
                order = 10,
                width = "full",
                hasAlpha = true,
                get = function(_)
                    return db.title.color.r, db.title.color.g, db.title.color.b, db.title.color.a
                end,
                set = function(_, r, g, b, a)
                    db.title.color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
                    Skada:ApplySettings()
                end
            },
            bordertexture = {
                type = "select",
                dialogControl = "LSM30_Border",
                name = L["Border texture"],
                desc = L["The texture used for the border of the title."],
                order = 11,
                width = "full",
                values = AceGUIWidgetLSMlists.border
            },
            bordercolor = {
                type = "color",
                name = L["Border color"],
                desc = L["The color used for the border."],
                hasAlpha = true,
                order = 12,
                width = "full",
                get = function()
                    return db.title.bordercolor.r, db.title.bordercolor.g, db.title.bordercolor.b, db.title.bordercolor.a
                end,
                set = function(_, r, g, b, a)
                    db.title.bordercolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
                    Skada:ApplySettings()
                end
            },
            thickness = {
                type = "range",
                name = L["Border thickness"],
                desc = L["The thickness of the borders."],
                order = 13,
                width = "full",
                min = 0,
                max = 50,
                step = 0.5
            },
            buttons = {
                type = "group",
                name = L["Buttons"],
                order = 14,
                width = "full",
                inline = true,
                get = function(i)
                    return db.buttons[i[#i]]
                end,
                set = function(i, val)
                    db.buttons[i[#i]] = val
                    Skada:ApplySettings()
                end,
                args = {
                    report = {
                        type = "toggle",
                        name = L["Report"],
                        desc = L["Opens a dialog that lets you report your data to others in various ways."],
                        order = 1
                    },
                    mode = {
                        type = "toggle",
                        name = L["Mode"],
                        desc = L["Jump to a specific mode."],
                        order = 2
                    },
                    segment = {
                        type = "toggle",
                        name = L["Segment"],
                        desc = L["Jump to a specific segment."],
                        order = 3
                    },
                    reset = {
                        type = "toggle",
                        name = RESET,
                        desc = L["Resets all fight data except those marked as kept."],
                        order = 4
                    },
                    menu = {
                        type = "toggle",
                        name = L["Configure"],
                        order = 5
                    },
                    stop = {
                        type = "toggle",
                        name = L["Stop"],
                        desc = L["Stops or resumes the current segment. Useful for discounting data after a wipe. Can also be set to automatically stop in the settings."],
                        order = 6
                    },
                    hovermode = {
                        type = "toggle",
                        name = L["Show on MouseOver"],
                        order = 7,
                        width = "full",
                        get = function()
                            return db.title.hovermode
                        end,
                        set = function()
                            db.title.hovermode = not db.title.hovermode
                            Skada:ApplySettings()
                        end
                    }
                }
            }
        }
    }

    options.windowoptions = Skada:FrameSettings(db, false)
end