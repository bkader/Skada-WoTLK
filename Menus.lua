local Skada=Skada
if not Skada then return end

local L=LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local AceGUI=LibStub("AceGUI-3.0")

local tinsert, tsort=table.insert, table.sort
local pairs, ipairs, type=pairs, ipairs, type
local format, sbyte=string.format, string.byte
local GetCursorPosition=GetCursorPosition

-- guesses the dropdown location
local function getDropdownPoint()
  local x, y=GetCursorPosition(UIParent)
  x=x/UIParent:GetEffectiveScale()
  y=y/UIParent:GetEffectiveScale()

  local point=(x > GetScreenWidth()/2) and "RIGHT" or "LEFT"
  point=((y > GetScreenHeight()/2) and "TOP" or "BOTTOM")..point
  return point, x, y
end

-- Configuration menu.
function Skada:OpenMenu(window)
  self.skadamenu=self.skadamenu or CreateFrame("Frame", "SkadaMenu")
  local skadamenu=self.skadamenu
  skadamenu.displayMode="MENU"

  local info=L_UIDropDownMenu_CreateInfo()
  skadamenu.initialize=function(self, level)
    if not level then return end

    if level == 1 then

      -- Create the title of the menu
      wipe(info)
      info.isTitle=1
      info.text=L["Skada Menu"]
      info.notCheckable=1
      L_UIDropDownMenu_AddButton(info, level)

      -- window menus
      for i, win in ipairs(Skada:GetWindows()) do
        wipe(info)
        info.text=win.db.name
        info.hasArrow=1
        info.value=win
        info.notCheckable=1
        L_UIDropDownMenu_AddButton(info, level)
      end

      -- separator
      wipe(info)
      info.disabled=1
      info.notCheckable=1
      L_UIDropDownMenu_AddButton(info, level)

      -- Can't report if we are not in a mode.
      if not window or (window and window.selectedmode) then
        wipe(info)
        info.text=L["Report"]
        info.func=function()
          Skada:OpenReportWindow(window)
        end
        info.value="report"
        info.notCheckable=1
        L_UIDropDownMenu_AddButton(info, level)
      end

      -- delete segment menu
      wipe(info)
      info.text=L["Delete segment"]
      info.hasArrow=1
      info.notCheckable=1
      info.value="delete"
      L_UIDropDownMenu_AddButton(info, level)

      -- keep segment
      wipe(info)
      info.text=L["Keep segment"]
      info.notCheckable=1
      info.hasArrow=1
      info.value="keep"
      L_UIDropDownMenu_AddButton(info, level)

      -- separator
      wipe(info)
      info.disabled=1
      info.notCheckable=1
      L_UIDropDownMenu_AddButton(info, level)

      -- toggle window
      wipe(info)
      info.text=L["Toggle window"]
      info.func=function()
        Skada:ToggleWindow()
      end
      info.notCheckable=1
      L_UIDropDownMenu_AddButton(info, level)

      -- reset
      wipe(info)
      info.text=L["Reset"]
      info.func=function()
        Skada:ShowPopup()
      end
      info.notCheckable=1
      L_UIDropDownMenu_AddButton(info, level)

      -- start new segment
      wipe(info)
      info.text=L["Start new segment"]
      info.func=function()
        Skada:NewSegment()
      end
      info.notCheckable=1
      L_UIDropDownMenu_AddButton(info, level)

      -- Configure
      wipe(info)
      info.text=L["Configure"]
      info.func=function()
        Skada:OpenOptions(window)
      end
      info.notCheckable=1
      L_UIDropDownMenu_AddButton(info, level)

      -- Close menu item
      wipe(info)
      info.text=CLOSE
      info.func=function()
        L_CloseDropDownMenus()
      end
      info.checked=nil
      info.notCheckable=1
      L_UIDropDownMenu_AddButton(info, level)

    elseif level == 2 then
      if type(L_UIDROPDOWNMENU_MENU_VALUE) == "table" then
        local window=L_UIDROPDOWNMENU_MENU_VALUE

        -- Display list of modes with current ticked; let user switch mode by checking one.
        wipe(info)
        info.isTitle=1
        info.text=L["Mode"]
        L_UIDropDownMenu_AddButton(info, level)

        for i, module in ipairs(Skada:GetModes()) do
          wipe(info)
          info.text=module:GetName()
          info.func=function()
            window:DisplayMode(module)
          end
          info.checked=(window.selectedmode == module)
          L_UIDropDownMenu_AddButton(info, level)
        end

        -- separator
        wipe(info)
        info.disabled=1
        info.notCheckable=1
        L_UIDropDownMenu_AddButton(info, level)

        -- Display list of sets with current ticked; let user switch set by checking one.
        wipe(info)
        info.isTitle=1
        info.text=L["Segment"]
        L_UIDropDownMenu_AddButton(info, level)

        wipe(info)
        info.text=L["Total"]
        info.func=function()
          window.selectedset="total"
          Skada:Wipe()
          Skada:UpdateDisplay(true)
        end
        info.checked=(window.selectedset == "total")
        L_UIDropDownMenu_AddButton(info, level)

        wipe(info)
        info.text=L["Current"]
        info.func=function()
          window.selectedset="current"
          Skada:Wipe()
          Skada:UpdateDisplay(true)
        end
        info.checked=(window.selectedset == "current")
        L_UIDropDownMenu_AddButton(info, level)

        for i, set in ipairs(Skada:get_sets()) do
          wipe(info)
          info.text=Skada:GetSetLabel(set)
          info.func=function()
            window.selectedset=i
            Skada:Wipe()
            Skada:UpdateDisplay(true)
          end
          info.checked=(window.selectedset == set.starttime)
          L_UIDropDownMenu_AddButton(info, level)
        end

        -- separator
        wipe(info)
        info.disabled=1
        info.notCheckable=1
        L_UIDropDownMenu_AddButton(info, level)

        -- lock window
        wipe(info)
        info.text=L["Lock window"]
        info.func=function()
          window.db.barslocked=not window.db.barslocked
          Skada:ApplySettings()
        end
        info.checked=window.db.barslocked
        info.isNotRadio=1
        L_UIDropDownMenu_AddButton(info, level)

        -- hide window
        wipe(info)
        info.text=L["Hide window"]
        info.func=function()
          if window:IsShown() then
            window.db.hidden=true
            window:Hide()
          else
            window.db.hidden=false
            window:Show()
          end
        end
        info.checked=not window:IsShown()
        info.isNotRadio=1
        L_UIDropDownMenu_AddButton(info, level)

      elseif L_UIDROPDOWNMENU_MENU_VALUE == "delete" then
        for i, set in ipairs(Skada:get_sets()) do
          wipe(info)
          info.text=Skada:GetSetLabel(set)
          info.func=function()
            Skada:DeleteSet(set)
          end
          info.notCheckable=1
          L_UIDropDownMenu_AddButton(info, level)
        end

      elseif L_UIDROPDOWNMENU_MENU_VALUE == "keep" then
        for i, set in ipairs(Skada:get_sets()) do
          wipe(info)
          info.text=Skada:GetSetLabel(set)
          info.func=function()
            set.keep=not set.keep
            Skada:Wipe()
            Skada:UpdateDisplay(true)
          end
          info.checked=set.keep
          info.isNotRadio=1
          L_UIDropDownMenu_AddButton(info, level)
        end
      end

    elseif level == 3 then
      if L_UIDROPDOWNMENU_MENU_VALUE == "modes" then
        for i, module in ipairs(Skada:GetModes()) do
          wipe(info)
          info.text=module:GetName()
          info.checked=(Skada.db.profile.report.mode == module:GetName())
          info.func=function()
            Skada.db.profile.report.mode=module:GetName()
          end
          L_UIDropDownMenu_AddButton(info, level)
        end

      elseif L_UIDROPDOWNMENU_MENU_VALUE == "segment" then
        wipe(info)
        info.text=L["Total"]
        info.func=function()
          Skada.db.profile.report.set="total"
        end
        info.checked=(Skada.db.profile.report.set == "total")
        L_UIDropDownMenu_AddButton(info, level)

        wipe(info)
        info.text=L["Current"]
        info.func=function()
          Skada.db.profile.report.set="current"
        end
        info.checked=(Skada.db.profile.report.set == "current")
        L_UIDropDownMenu_AddButton(info, level)

        for i, set in ipairs(Skada:get_sets()) do
          wipe(info)
          info.text=Skada:GetSetLabel(set)
          info.func=function()
            Skada.db.profile.report.set=i
          end
          info.checked=(Skada.db.profile.report.set == i)
          L_UIDropDownMenu_AddButton(info, level)
        end
      end
    end
  end

  local x, y
  skadamenu.point, x, y=getDropdownPoint()
  L_ToggleDropDownMenu(1, nil, skadamenu, "UIParent", x, y)
end

function Skada:SegmentMenu(window)
  self.segmentsmenu=self.segmentsmenu or CreateFrame("Frame", "SkadaWindowButtonsSegments")
  local segmentsmenu=self.segmentsmenu
  segmentsmenu.displayMode="MENU"

  local info=L_UIDropDownMenu_CreateInfo()
  segmentsmenu.initialize=function(self, level)
    if not level then return end

    info.isTitle=1
    info.text=L["Segment"]
    L_UIDropDownMenu_AddButton(info, level)

    wipe(info)
    info.text=L["Total"]
    info.func=function()
      window.selectedset="total"
      Skada:Wipe()
      Skada:UpdateDisplay(true)
    end
    info.checked=(window.selectedset == "total")
    L_UIDropDownMenu_AddButton(info, level)

    wipe(info)
    info.text=L["Current"]
    info.func=function()
      window.selectedset="current"
      Skada:Wipe()
      Skada:UpdateDisplay(true)
    end
    info.checked=(window.selectedset == "current")
    L_UIDropDownMenu_AddButton(info, level)

    for i, set in ipairs(Skada:get_sets()) do
      wipe(info)
      info.text=Skada:GetSetLabel(set)
      info.func=function()
        window.selectedset=i
        Skada:Wipe()
        Skada:UpdateDisplay(true)
      end
      info.checked=(window.selectedset == i)
      L_UIDropDownMenu_AddButton(info, level)
    end
  end

  local x, y
  segmentsmenu.point, x, y=getDropdownPoint()
  L_ToggleDropDownMenu(1, nil, segmentsmenu, "UIParent", x, y)
end


do
  local categorized

  local function sort_modes(a, b)
    local a_score=(a.category==OTHER) and 1000 or 0
    local b_score=(b.category==OTHER) and 1000 or 0
    a_score=a_score+(sbyte(a.category, 1)*10)+sbyte(a:GetName(), 1)
    b_score=b_score+(sbyte(b.category, 1)*10)+sbyte(b:GetName(), 1)
    return a_score<b_score
  end

  function Skada:ModeMenu(window)
    self.modesmenu=self.modesmenu or CreateFrame("Frame", "SkadaWindowButtonsModes")
    local modesmenu=self.modesmenu
    local info=L_UIDropDownMenu_CreateInfo()

    -- so we call it only once.
    if categorized==nil then
      local modes=Skada:GetModes()
      categorized={}
      for i, mode in ipairs(modes) do
        categorized[mode.category]=categorized[mode.category] or {}
        tinsert(categorized[mode.category], mode)
      end
      tsort(categorized, sort_modes)
    end

    modesmenu.displayMode="MENU"
    modesmenu.initialize=function(self, level)
      if not level then return end

      if level==1 then

        for category, modes in pairs(categorized) do
          if category~=OTHER then
            wipe(info)
            info.text=category
            info.value=category
            info.hasArrow=1
            info.notCheckable=1
            L_UIDropDownMenu_AddButton(info, level)
          end
        end

        if categorized[OTHER] then
          wipe(info)
          info.text=OTHER
          info.value=OTHER
          info.hasArrow=1
          info.notCheckable=1
          L_UIDropDownMenu_AddButton(info, level)
        end

      elseif level==2 and categorized[L_UIDROPDOWNMENU_MENU_VALUE] then
        for i, mode in ipairs(categorized[L_UIDROPDOWNMENU_MENU_VALUE]) do
          wipe(info)
          info.text = mode:GetName()
          info.func = function()
            window:DisplayMode(mode)
            L_CloseDropDownMenus()
          end
          info.checked = (window.selectedmode == mode)
          L_UIDropDownMenu_AddButton(info, level)
        end
      end
    end

    local x, y
    modesmenu.point, x, y=getDropdownPoint()
    L_ToggleDropDownMenu(1, nil, modesmenu, "UIParent", x, y)
  end
end

do
  local function destroywindow()
    if Skada.reportwindow then
      -- remove AceGUI hacks before recycling the widget
      local frame=Skada.reportwindow
      frame.LayoutFinished=frame.orig_LayoutFinished
      frame.frame:SetScript("OnKeyDown", nil)
      frame.frame:EnableKeyboard(false)
      frame:ReleaseChildren()
      frame:Release()
    end
    Skada.reportwindow=nil
  end

  local function createReportWindow(window)
    Skada.reportwindow=AceGUI:Create("Window")

    local frame=Skada.reportwindow
    frame:SetLayout("List")
    frame:EnableResize(false)
    frame:SetWidth(250)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    if window then
      frame:SetTitle(L["Report"]..format(" - %s", window.db.name))
    else
      frame:SetTitle(L["Report"])
    end

    frame:SetCallback("OnClose", function(widget, callback)
      destroywindow()
    end)

    -- slight AceGUI hack to auto-set height of Window widget:
    frame.orig_LayoutFinished=frame.LayoutFinished
    frame.LayoutFinished=function(self, _, height)
      frame:SetHeight(height+57)
    end

    if window then
      Skada.db.profile.report.set=window.selectedset
      Skada.db.profile.report.mode=window.db.mode
    else
      -- Mode, default last chosen or first available.
      local modebox=AceGUI:Create("Dropdown")
      modebox:SetLabel(L["Mode"])
      modebox:SetList({})
      for i, mode in ipairs(Skada:GetModes()) do
        modebox:AddItem(mode:GetName(), mode:GetName())
      end
      modebox:SetCallback("OnValueChanged", function(f, e, value)
        Skada.db.profile.report.mode=value
      end)
      modebox:SetValue(Skada.db.profile.report.mode or Skada:GetModes()[1])
      frame:AddChild(modebox)

      -- Segment, default last chosen or last set.
      local setbox=AceGUI:Create("Dropdown")
      setbox:SetLabel(L["Segment"])
      setbox:SetList({total=L["Total"], current=L["Current"]})
      for i, set in ipairs(Skada:get_sets()) do
        setbox:AddItem(i, set.name)
      end
      setbox:SetCallback("OnValueChanged", function(f, e, value)
        Skada.db.profile.report.set=value
      end)
      setbox:SetValue(Skada.db.profile.report.set or Skada.char.sets[1])
      frame:AddChild(setbox)
    end

    local channellist={
      whisper={L["Whisper"], "whisper", true},
      target={L["Whisper Target"], "whisper"},
      say={L["Say"], "preset"},
      raid={L["Raid"], "preset"},
      party={L["Party"], "preset"},
      guild={L["Guild"], "preset"},
      officer={L["Officer"], "preset"},
      self={L["Self"], "self"},
    }

    local list={GetChannelList()}
    for i=1, #list, 2 do
      local chan=list[i+1]
      if chan ~= "Trade" and chan ~= "General" and chan ~= "LocalDefense" and chan ~= "LookingForGroup" then -- These should be localized.
        channellist[chan]={("%s: %d/%s"):format(L["Channel"], list[i], chan), "channel"}
      end
    end

    -- Channel, default last chosen or Say.
    local channelbox=AceGUI:Create("Dropdown")
    channelbox:SetLabel(L["Channel"])
    channelbox:SetList({})
    for chan, kind in pairs(channellist) do
      channelbox:AddItem(chan, kind[1])
    end

    local origchan=Skada.db.profile.report.channel or "say"
    if not channellist[origchan] then
      origchan="say"
    end

    channelbox:SetValue(origchan)
    channelbox:SetCallback("OnValueChanged", function(f, e, value)
      Skada.db.profile.report.channel=value
      Skada.db.profile.report.chantype=channellist[value][2]
      if channellist[origchan][3] ~= channellist[value][3] then
        -- redraw in-place to add/remove whisper widget
        local pos={frame:GetPoint()}
        destroywindow()
        createReportWindow(window)
        Skada.reportwindow:SetPoint(unpack(pos))
      end
    end)
    frame:AddChild(channelbox)

    local lines=AceGUI:Create("Slider")
    lines:SetLabel(L["Lines"])
    lines:SetValue(Skada.db.profile.report.number ~= nil and Skada.db.profile.report.number or 10)
    lines:SetSliderValues(1, 25, 1)
    lines:SetCallback("OnValueChanged", function(self, event, value)
      Skada.db.profile.report.number=value
    end)
    lines:SetFullWidth(true)
    frame:AddChild(lines)

    if channellist[origchan][3] then
      local whisperbox=AceGUI:Create("EditBox")
      whisperbox:SetLabel(L["Whisper Target"])
      whisperbox:SetText(Skada.db.profile.report.target or "")
      
      whisperbox:SetCallback("OnEnterPressed", function(box, event, text)
        if strlenutf8(text) == #text then -- remove spaces which are always non-meaningful and can sometimes cause problems
          local ntext=text:gsub("%s", "")
          if ntext ~= text then
            text=ntext
            whisperbox:SetText(text)
          end
        end
        Skada.db.profile.report.target=text
        frame.button.frame:Click()
      end)

      whisperbox:SetCallback("OnTextChanged", function(box, event, text)
        Skada.db.profile.report.target=text
      end)
      whisperbox:SetFullWidth(true)
      frame:AddChild(whisperbox)
    end

    local report=AceGUI:Create("Button")
    frame.button=report
    report:SetText(L["Report"])
    report:SetCallback("OnClick", function()
      local mode, set, channel, chantype, number =
        Skada.db.profile.report.mode,
        Skada.db.profile.report.set,
        Skada.db.profile.report.channel,
        Skada.db.profile.report.chantype,
        Skada.db.profile.report.number

      if channel == "whisper" then
        channel=Skada.db.profile.report.target
        if channel and #strtrim(channel) == 0 then
          channel=nil
        end
      elseif channel == "target" then
        if UnitExists("target") then
          local toon, realm=UnitName("target")
          if realm and #realm > 0 then
            channel=toon .. "-" .. realm
          else
            channel=toon
          end
        else
          channel=nil
        end
      end

      if channel and chantype and mode and set and number then
        Skada:Report(channel, chantype, mode, set, number, window)
        frame:Hide()
      else
        Skada:Print("Error: Whisper target not found")
      end
    end)
    
    report:SetFullWidth(true)
    frame:AddChild(report)
  end

  function Skada:OpenReportWindow(window)
    if self.reportwindow == nil then
      createReportWindow(window)
    end
    self.reportwindow:Show()
  end
end
