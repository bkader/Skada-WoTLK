--[[

The traditional bar display used in some form by most damage meters.

--]]

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local Skada = Skada

local mod = Skada:NewModule("BarDisplay", "SpecializedLibBars-1.0")
local libwindow = LibStub("LibWindow-1.1")
local media = LibStub("LibSharedMedia-3.0")
local classCoords = Skada.classCoords

--
-- Display implementation.
--

-- Add to Skada's enormous list of display providers.
mod.name = L["Bar display"]
Skada.displays["bar"] = mod

-- Called when a Skada window starts using this display provider.
function mod:Create(window)
  -- Re-use bargroup if it exists.
  window.bargroup = mod:GetBarGroup(window.db.name)

  -- Save a reference to window in bar group. Needed for some nasty callbacks.
  if window.bargroup then
    -- Clear callbacks.
    window.bargroup.callbacks = LibStub:GetLibrary("CallbackHandler-1.0"):New(window.bargroup)
  else
    window.bargroup = mod:NewBarGroup(window.db.name, nil, window.db.barwidth, window.db.barheight, "SkadaBarWindow"..window.db.name)
  end
  window.bargroup.win = window
  window.bargroup.RegisterCallback(mod, "AnchorMoved")
  window.bargroup.RegisterCallback(mod, "AnchorClicked")
  window.bargroup.RegisterCallback(mod, "ConfigClicked")
  window.bargroup.RegisterCallback(mod, "ResetClicked")
  window.bargroup.RegisterCallback(mod, "SegmentClicked")
  window.bargroup.RegisterCallback(mod, "ModeClicked")
  window.bargroup.RegisterCallback(mod, "ReportClicked")
  window.bargroup:EnableMouse(true)
  window.bargroup:SetScript("OnMouseDown", function(win, button) if button == "RightButton" then window:RightClick() end end)
  window.bargroup:HideIcon()

  -- Register with LibWindow-1.0.
  libwindow.RegisterConfig(window.bargroup, window.db)

  -- Restore window position.
  libwindow.RestorePosition(window.bargroup)
end

-- Called by Skada windows when the window is to be destroyed/cleared.
function mod:Destroy(win)
  win.bargroup:Hide()
  win.bargroup.bgframe = nil
  win.bargroup = nil
end

-- Called by Skada windows when the window is to be completely cleared and prepared for new data.
function mod:Wipe(win)
  -- Reset sort function.
  win.bargroup:SetSortFunction(nil)

  -- Reset scroll offset.
  win.bargroup:SetBarOffset(0)

  -- Remove the bars.
  local bars = win.bargroup:GetBars()
  if bars then
    for i, bar in pairs(bars) do
      bar:Hide()
      win.bargroup:RemoveBar(bar)
    end
  end

  -- Clean up.
  win.bargroup:SortBars()
end

local function showmode(win, id, label, mode)
  -- Add current mode to window traversal history.
  if win.selectedmode then
    tinsert(win.history, win.selectedmode)
  end
  -- Call the Enter function on the mode.
  if mode.Enter then
    mode:Enter(win, id, label)
  end
  -- Display mode.
  win:DisplayMode(mode)
end

local function BarClick(win, id, label, button)
  local click1 = win.metadata.click1
  local click2 = win.metadata.click2
  local click3 = win.metadata.click3

  if button == "RightButton" and IsShiftKeyDown() then
    Skada:OpenMenu(win)
  elseif win.metadata.click then
    win.metadata.click(win, id, label, button)
  elseif button == "RightButton" then
    win:RightClick()
  elseif click2 and IsShiftKeyDown() then
    showmode(win, id, label, click2)
  elseif click3 and IsControlKeyDown() then
    showmode(win, id, label, click3)
  elseif click1 then
    showmode(win, id, label, click1)
  end
end

local ttactive = false

local function BarEnter(win, id, label)
  local t = GameTooltip
  if Skada.db.profile.tooltips and (win.metadata.click1 or win.metadata.click2 or win.metadata.click3 or win.metadata.tooltip) then
    ttactive = true
    Skada:SetTooltipPosition(t, win.bargroup)
    t:ClearLines()

    -- Current mode's own tooltips.
    if win.metadata.tooltip then
      win.metadata.tooltip(win, id, label, t)

      -- Spacer
      if win.metadata.click1 or win.metadata.click2 or win.metadata.click3 then
        t:AddLine(" ")
      end
    end

    -- Generic informative tooltips.
    if Skada.db.profile.informativetooltips then
      if win.metadata.click1 then
        Skada:AddSubviewToTooltip(t, win, win.metadata.click1, id, label)
      end
      if win.metadata.click2 then
        Skada:AddSubviewToTooltip(t, win, win.metadata.click2, id, label)
      end
      if win.metadata.click3 then
        Skada:AddSubviewToTooltip(t, win, win.metadata.click3, id, label)
      end
    end

    -- Click directions.
    if win.metadata.click1 then
      t:AddLine(L["Click for"].." "..win.metadata.click1:GetName()..".", 0.2, 1, 0.2)
    end
    if win.metadata.click2 then
      t:AddLine(L["Shift-Click for"].." "..win.metadata.click2:GetName()..".", 0.2, 1, 0.2)
    end
    if win.metadata.click3 then
      t:AddLine(L["Control-Click for"].." "..win.metadata.click3:GetName()..".", 0.2, 1, 0.2)
    end

    t:Show()
  end
end

local function BarLeave(win, id, label)
  if ttactive then
    GameTooltip:Hide()
    ttactive = false
  end
end

local function value_sort(a,b)
  if not a or a.value == nil then
    return false
  elseif not b or b.value == nil then
    return true
  else
    return a.value > b.value
  end
end

local function bar_order_sort(a,b)
  return a and b and a.order and b.order and a.order < b.order
end

local function bar_order_reverse_sort(a,b)
  return a and b and a.order and b.order and a.order < b.order
end

-- Called by Skada windows when the display should be updated to match the dataset.
function mod:Update(win)
  -- Set title.
  win.bargroup.button:SetText(win.metadata.title)

  -- Sort if we are showing spots with "showspots".
  if win.metadata.showspots then
    table.sort(win.dataset, value_sort)
  end

  -- If we are using "wipestale", we may have removed data
  -- and we need to remove unused bars.
  -- The Threat module uses this.
  -- For each bar, mark bar as unchecked.
  if win.metadata.wipestale then
    local bars = win.bargroup:GetBars()
    if bars then
      for name, bar in pairs(bars) do
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

      if bar then
        bar:SetMaxValue(win.metadata.maxvalue or 1)
        bar:SetValue(data.value)
      else
        -- Initialization of bars.
        bar = mod:CreateBar(win, barid, barlabel, data.value, win.metadata.maxvalue or 1, data.icon, false)
        if data.icon then
          bar:ShowIcon()
        end
        bar:EnableMouse()
        bar.id = data.id
        bar:SetScript("OnEnter", function(bar) BarEnter(win, barid, barlabel) end)
        bar:SetScript("OnLeave", function(bar) BarLeave(win, barid, barlabel) end)
        bar:SetScript("OnMouseDown", function(bar, button) BarClick(win, barid, barlabel, button) end)

        -- Spark.
        if win.db.spark then
          bar.spark:Show()
        else
          bar.spark:Hide()
        end

        if data.color then
          -- Explicit color from dataset.
          bar:SetColorAt(0, data.color.r, data.color.g, data.color.b, data.color.a or 1)
        elseif data.class and win.db.classcolorbars then
          -- Class color.
          local color = Skada.classcolors[data.class]
          if color then
            bar:SetColorAt(0, color.r, color.g, color.b, color.a or 1)
            bar:SetTexCoord(unpack(classCoords[data.class]))
          end
        else
          -- Default color.
          local color = win.db.barcolor
          bar:SetColorAt(0, color.r, color.g, color.b, color.a or 1)
        end

        if data.class and win.db.classcolortext then
          -- Class color text.
          local color = Skada.classcolors[data.class]
          if color then
            bar.label:SetTextColor(color.r, color.g, color.b, color.a or 1)
            bar.timerLabel:SetTextColor(color.r, color.g, color.b, color.a or 1)
            bar:SetTexCoord(unpack(classCoords[data.class]))
          end
        else
          -- Default color text.
          bar.label:SetTextColor(1,1,1,1)
          bar.timerLabel:SetTextColor(1,1,1,1)
        end
      end

      if win.metadata.ordersort then
        bar.order = i
      end

      if win.metadata.showspots and Skada.db.profile.showranks then
        bar:SetLabel(("%2u. %s"):format(nr, data.label))
      else
        bar:SetLabel(data.label)
      end
      bar:SetTimerLabel(data.valuetext)

      if win.metadata.wipestale then
        bar.checked = true
      end

      -- Emphathized items - cache a flag saying it is done so it is not done again.
      -- This is a little lame.
      if data.emphathize and bar.emphathize_set ~= true then
        bar:SetFont(nil,nil,"OUTLINE")
        bar.emphathize_set = true
      elseif not data.emphathize and bar.emphathize_set ~= false then
        bar:SetFont(nil,nil,"PLAIN")
        bar.emphathize_set = false
      end

      -- Background texture color.
      if data.backgroundcolor then
        bar.bgtexture:SetVertexColor(data.backgroundcolor.r, data.backgroundcolor.g, data.backgroundcolor.b, data.backgroundcolor.a or 1)
      end

      -- Background texture size (in percent, as the mode has no idea on actual widths).
      if data.backgroundwidth then
        bar.bgtexture:ClearAllPoints()
        bar.bgtexture:SetPoint("BOTTOMLEFT")
        bar.bgtexture:SetPoint("TOPLEFT")
        bar.bgtexture:SetWidth(data.backgroundwidth * bar:GetLength())
      end

      nr = nr + 1
    end
  end

  -- If we are using "wipestale", remove all unchecked bars.
  if win.metadata.wipestale then
    local bars = win.bargroup:GetBars()
    for name, bar in pairs(bars) do
      if not bar.checked then
        win.bargroup:RemoveBar(bar)
      end
    end
  end

  -- Adjust our background frame if background height is dynamic.
  if win.bargroup.bgframe and win.db.background.height == 0 then
    self:AdjustBackgroundHeight(win)
  end

  -- Sort by the order in the data table if we are using "ordersort".
  if win.metadata.ordersort then
    if win.db.reversegrowth then
      win.bargroup:SetSortFunction(bar_order_reverse_sort)
    else
      win.bargroup:SetSortFunction(bar_order_sort)
    end
    win.bargroup:SortBars()
  else
    win.bargroup:SetSortFunction(nil)
    win.bargroup:SortBars()
  end
end

function mod:AdjustBackgroundHeight(win)
  local numbars = 0
  if win.bargroup:GetBars() ~= nil then
    for name, bar in pairs(win.bargroup:GetBars()) do if bar:IsShown() then numbars = numbars + 1 end end
    local height = numbars * (win.db.barheight + win.db.barspacing) + win.db.background.borderthickness
    if win.bargroup.bgframe:GetHeight() ~= height then
      win.bargroup.bgframe:SetHeight(height)
    end
  end
end

function mod:ConfigClicked(cbk, group, button)
  Skada:OpenMenu(group.win)
end

function mod:ResetClicked(cbk, group, button)
  local mode = group.win.db.mode
  if mode == L["Improvement"] then
    local improvemode = Skada:GetModule(L["Improvement"])
    if improvemode then
      if not StaticPopupDialogs["ImprovementResetSkadaDialog"] then
        StaticPopupDialogs["ImprovementResetSkadaDialog"] = {
          text = L["Do you want to reset your improvement data?"],
          button1 = ACCEPT,
          button2 = CANCEL,
          timeout = 30,
          whileDead = 0,
          hideOnEscape = 1,
          OnAccept = function()
            Skada:Wipe()
            wipe(SkadaImprovementDB)
            SkadaImprovementDB = {}
            if improvemode.OnInitialize then
              improvemode:OnInitialize()
            end
            collectgarbage("collect")
            for _, win in ipairs(Skada:GetWindows()) do
              local mode = win.db.mode
              if mode == L["Improvement"] or mode == L["Improvement Modes"] or mode == L["Improvement Comparison"] then
                win:DisplayMode(improvemode)
              end
            end

            Skada:UpdateDisplay(true)
            Skada:Print(L["All data has been reset."])
          end
        }
      end
      StaticPopup_Show("ImprovementResetSkadaDialog")
      return
    end
  end
  if not StaticPopupDialogs["ResetSkadaDialog"] then
    StaticPopupDialogs["ResetSkadaDialog"] = {
      text = L["Do you want to reset Skada?"],
      button1 = ACCEPT,
      button2 = CANCEL,
      timeout = 30,
      whileDead = 0,
      hideOnEscape = 1,
      OnAccept = function() Skada:Reset() end,
    }
  end
  StaticPopup_Show("ResetSkadaDialog")
end

function mod:SegmentClicked(cbk, group, button)
  Skada:SegmentMenu(group.win)
end

function mod:ModeClicked(cbk, group, button)
  Skada:ModeMenu(group.win)
end

function mod:ReportClicked(cbk, group, button)
  Skada:OpenReportWindow(group.win)
end


function mod:AnchorClicked(cbk, group, button)
  if IsShiftKeyDown() then
    Skada:OpenMenu(group.win)
  elseif button == "RightButton" then
    group.win:RightClick()
  end
end

function mod:AnchorMoved(cbk, group, x, y)
  libwindow.SavePosition(group)
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

local function getNumberOfBars(win)
  local bars = win.bargroup:GetBars()
  local n = 0
  for i, bar in pairs(bars) do n = n + 1 end
  return n
end

function mod:OnMouseWheel(win, frame, direction)
  if direction == 1 and win.bargroup:GetBarOffset() > 0 then
    win.bargroup:SetBarOffset(win.bargroup:GetBarOffset() - 1)
  elseif direction == -1 and ((getNumberOfBars(win) - win.bargroup:GetMaxBars() - win.bargroup:GetBarOffset()) > 0) then
    win.bargroup:SetBarOffset(win.bargroup:GetBarOffset() + 1)
  end
end

function mod:CreateBar(win, name, label, value, maxvalue, icon, o)
  local bar = win.bargroup:NewCounterBar(name, label, value, maxvalue, icon, o)
  bar:EnableMouseWheel(true)
  bar:SetScript("OnMouseWheel", function(f, d) mod:OnMouseWheel(win, f, d) end)
  return bar
end

local titlebackdrop = {}
local windowbackdrop = {}

-- Called by Skada windows when window settings have changed.
function mod:ApplySettings(win)
  local g = win.bargroup
  local p = win.db
  g:ReverseGrowth(p.reversegrowth)
  g:SetOrientation(p.barorientation)
  g:SetHeight(p.barheight)
  g:SetWidth(p.barwidth)
  g:SetTexture(media:Fetch('statusbar', p.bartexture))
  g:SetFont(media:Fetch('font', p.barfont), p.barfontsize)
  g:SetSpacing(p.barspacing)
  g:UnsetAllColors()
  g:SetColorAt(0,p.barcolor.r,p.barcolor.g,p.barcolor.b, p.barcolor.a)
  g:SetMaxBars(p.barmax)
  if p.barslocked then
    g:Lock()
  else
    g:Unlock()
  end

  -- Header
  local fo = CreateFont("TitleFont"..win.db.name)
  fo:SetFont(media:Fetch('font', p.title.font), p.title.fontsize)
  g.button:SetNormalFontObject(fo)
  
  local inset = p.title.margin
  titlebackdrop.bgFile = media:Fetch("statusbar", p.title.texture)
  if p.title.borderthickness > 0 then
    titlebackdrop.edgeFile = media:Fetch("border", p.title.bordertexture)
  else
    titlebackdrop.edgeFile = nil
  end
  titlebackdrop.tile = false
  titlebackdrop.tileSize = 0
  titlebackdrop.edgeSize = p.title.borderthickness
  titlebackdrop.insets = {left = inset, right = inset, top = inset, bottom = inset}
  g.button:SetBackdrop(titlebackdrop)
  local color = p.title.color
  g.button:SetBackdropColor(color.r, color.g, color.b, color.a or 1)

  if p.enabletitle then
    g:ShowAnchor()
  else
    g:HideAnchor()
  end

  -- Spark.
  for i, bar in pairs(g:GetBars()) do
    if p.spark then
      bar.spark:Show()
    else
      bar.spark:Hide()
    end
  end

  -- Header config button
  g.optbutton:ClearAllPoints()
  g.optbutton:SetPoint("TOPRIGHT", g.button, "TOPRIGHT", -5, 0 - (math.max(g.button:GetHeight() - g.optbutton:GetHeight(), 1) / 2))

  -- Menu button - default on.
  local title = g.button:GetFontString()
  if p.title.menubutton == nil or p.title.menubutton then
    g.optbutton:Show()
    g.resetbutton:Show()
    g.segmentbutton:Show()
    g.modebutton:Show()
    g.reportbutton:Show()
    title:SetPoint("LEFT", g.button, "LEFT", 5, 1)
    title:SetJustifyH("LEFT")
  else
    g.optbutton:Hide()
    g.resetbutton:Hide()
    g.segmentbutton:Hide()
    g.modebutton:Hide()
    g.reportbutton:Hide()
    title:SetPoint("LEFT", g.button, "LEFT")
    title:SetPoint("RIGHT", g.button, "RIGHT")
    title:SetJustifyH("CENTER")
  end

  -- Window
  if p.enablebackground then
    if g.bgframe == nil then
      g.bgframe = CreateFrame("Frame", p.name.."BG", g)
      g.bgframe:SetFrameStrata("BACKGROUND")
      g.bgframe:EnableMouse()
      g.bgframe:EnableMouseWheel()
      g.bgframe:SetScript("OnMouseDown", function(frame, btn)
      if IsShiftKeyDown() then
        Skada:OpenMenu(win)
      elseif btn == "RightButton" then
        win:RightClick()
      end
      end)
      g.bgframe:SetScript("OnMouseWheel", win.OnMouseWheel)
    end

    local inset = p.background.margin
    windowbackdrop.bgFile = media:Fetch("background", p.background.texture)
    if p.background.borderthickness > 0 then
      windowbackdrop.edgeFile = media:Fetch("border", p.background.bordertexture)
    else
      windowbackdrop.edgeFile = nil
    end
    windowbackdrop.tile = false
    windowbackdrop.tileSize = 0
    windowbackdrop.edgeSize = p.background.borderthickness
    windowbackdrop.insets = {left = inset, right = inset, top = inset, bottom = inset}
    g.bgframe:SetBackdrop(windowbackdrop)
    local color = p.background.color
    g.bgframe:SetBackdropColor(color.r, color.g, color.b, color.a or 1)
    g.bgframe:SetWidth(g:GetWidth() + (p.background.borderthickness * 2))
    g.bgframe:SetHeight(p.background.height)

    g.bgframe:ClearAllPoints()
    if p.reversegrowth then
      g.bgframe:SetPoint("LEFT", g.button, "LEFT", -p.background.borderthickness, 0)
      g.bgframe:SetPoint("RIGHT", g.button, "RIGHT", p.background.borderthickness, 0)
      g.bgframe:SetPoint("BOTTOM", g.button, "TOP", 0, 0)
    else
      g.bgframe:SetPoint("LEFT", g.button, "LEFT", -p.background.borderthickness, 0)
      g.bgframe:SetPoint("RIGHT", g.button, "RIGHT", p.background.borderthickness, 0)
      g.bgframe:SetPoint("TOP", g.button, "BOTTOM", 0, 5)
    end
    g.bgframe:Show()

    -- Calculate max number of bars to show if our height is not dynamic.
    if p.background.height > 0 then
      local maxbars = math.floor(p.background.height / math.max(1, p.barheight + p.barspacing))
      g:SetMaxBars(maxbars)
    else
      -- Adjust background height according to current bars.
      self:AdjustBackgroundHeight(win)
    end

  elseif g.bgframe then
    g.bgframe:Hide()
  end

  g:SortBars()
end

--
-- Options.
--

function mod:AddDisplayOptions(win, options)
  local db = win.db

  options.baroptions = {
    type = "group",
    name = L["Bars"],
    order=1,
    args = {

      barfont = {
        type = 'select',
        dialogControl = 'LSM30_Font',
        name = L["Bar font"],
        desc = L["The font used by all bars."],
        values = AceGUIWidgetLSMlists.font,
        get = function() return db.barfont end,
        set = function(win,key)
        db.barfont = key
        Skada:ApplySettings()
        end,
        order=10,
      },

      barfontsize = {
        type="range",
        name=L["Bar font size"],
        desc=L["The font size of all bars."],
        min=7,
        max=40,
        step=1,
        get=function() return db.barfontsize end,
        set=function(win, size)
        db.barfontsize = size
        Skada:ApplySettings()
        end,
        order=11,
      },

      bartexture = {
        type = 'select',
        dialogControl = 'LSM30_Statusbar',
        name = L["Bar texture"],
        desc = L["The texture used by all bars."],
        values = AceGUIWidgetLSMlists.statusbar,
        get = function() return db.bartexture end,
        set = function(win,key)
        db.bartexture = key
        Skada:ApplySettings()
        end,
        order=12,
      },

      barspacing = {
        type="range",
        name=L["Bar spacing"],
        desc=L["Distance between bars."],
        min=0,
        max=10,
        step=1,
        get=function() return db.barspacing end,
        set=function(win, spacing)
        db.barspacing = spacing
        Skada:ApplySettings()
        end,
        order=13,
      },

      barheight = {
        type="range",
        name=L["Bar height"],
        desc=L["The height of the bars."],
        min=10,
        max=40,
        step=1,
        get=function() return db.barheight end,
        set=function(win, height)
        db.barheight = height
        Skada:ApplySettings()
        end,
        order=14,
      },

      barwidth = {
        type="range",
        name=L["Bar width"],
        desc=L["The width of the bars."],
        min=80,
        max=400,
        step=1,
        get=function() return db.barwidth end,
        set=function(win, width)
        db.barwidth = width
        Skada:ApplySettings()
        end,
        order=14,
      },

      barmax = {
        type="range",
        name=L["Max bars"],
        desc=L["The maximum number of bars shown."],
        min=0,
        max=100,
        step=1,
        get=function() return db.barmax end,
        set=function(win, max)
        db.barmax = max
        Skada:ApplySettings()
        end,
        order=15,
      },

      barorientation = {
        type="select",
        name=L["Bar orientation"],
        desc=L["The direction the bars are drawn in."],
        values= function() return {[1] = L["Left to right"], [3] = L["Right to left"]} end,
        get=function() return db.barorientation end,
        set=function(win, orientation)
        db.barorientation = orientation
        Skada:ApplySettings()
        end,
        order=17,
      },

      reversegrowth = {
        type="toggle",
        name=L["Reverse bar growth"],
        desc=L["Bars will grow up instead of down."],
        order=19,
        get=function() return db.reversegrowth end,
        set=function()
        db.reversegrowth = not db.reversegrowth
        Skada:ApplySettings()
        end,
      },

      color = {
        type="color",
        name=L["Bar color"],
        desc=L["Choose the default color of the bars."],
        hasAlpha=true,
        get=function(i)
        local c = db.barcolor
        return c.r, c.g, c.b, c.a
        end,
        set=function(i, r,g,b,a)
        db.barcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
        Skada:ApplySettings()
        end,
        order=20,
      },

      altcolor = {
        type="color",
        name=L["Alternate color"],
        desc=L["Choose the alternate color of the bars."],
        hasAlpha=true,
        get=function(i)
        local c = db.baraltcolor
        return c.r, c.g, c.b, c.a
        end,
        set=function(i, r,g,b,a)
        db.baraltcolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
        Skada:ApplySettings()
        end,
        order=21,
      },

      classcolorbars = {
        type="toggle",
        name=L["Class color bars"],
        desc=L["When possible, bars will be colored according to player class."],
        order=30,
        get=function() return db.classcolorbars end,
        set=function()
        db.classcolorbars = not db.classcolorbars
        Skada:ApplySettings()
        end,
      },

      classcolortext = {
        type="toggle",
        name=L["Class color text"],
        desc=L["When possible, bar text will be colored according to player class."],
        order=31,
        get=function() return db.classcolortext end,
        set=function()
        db.classcolortext = not db.classcolortext
        Skada:ApplySettings()
        end,
      },

      spark = {
        type="toggle",
        name=L["Show spark effect"],
        order=32,
        get=function() return db.spark end,
        set=function()
        db.spark = not db.spark
        Skada:ApplySettings()
        end,
      },

    }
  }

  options.titleoptions = {
    type = "group",
    name = L["Title bar"],
    order=2,
    args = {

      enable = {
        type="toggle",
        name=L["Enable"],
        desc=L["Enables the title bar."],
        order=0,
        get=function() return db.enabletitle end,
        set=function()
        db.enabletitle = not db.enabletitle
        Skada:ApplySettings()
        end,
      },

      font = {
        type = 'select',
        dialogControl = 'LSM30_Font',
        name = L["Bar font"],
        desc = L["The font used by all bars."],
        values = AceGUIWidgetLSMlists.font,
        get = function() return db.title.font end,
        set = function(win,key)
        db.title.font = key
        Skada:ApplySettings()
        end,
        order=1,
      },

      fontsize = {
        type="range",
        name=L["Bar font size"],
        desc=L["The font size of all bars."],
        min=7,
        max=40,
        step=1,
        get=function() return db.title.fontsize end,
        set=function(win, size)
        db.title.fontsize = size
        Skada:ApplySettings()
        end,
        order=2,
      },


      texture = {
        type = 'select',
        dialogControl = 'LSM30_Statusbar',
        name = L["Background texture"],
        desc = L["The texture used as the background of the title."],
        values = AceGUIWidgetLSMlists.statusbar,
        get = function() return db.title.texture end,
        set = function(win,key)
        db.title.texture = key
        Skada:ApplySettings()
        end,
        order=3,
      },

      bordertexture = {
        type = 'select',
        dialogControl = 'LSM30_Border',
        name = L["Border texture"],
        desc = L["The texture used for the border of the title."],
        values = AceGUIWidgetLSMlists.border,
        get = function() return db.title.bordertexture end,
        set = function(win,key)
        db.title.bordertexture = key
        Skada:ApplySettings()
        end,
        order=4,
      },

      thickness = {
        type="range",
        name=L["Border thickness"],
        desc=L["The thickness of the borders."],
        min=0,
        max=50,
        step=0.5,
        get=function() return db.title.borderthickness end,
        set=function(win, val)
        db.title.borderthickness = val
        Skada:ApplySettings()
        end,
        order=5,
      },

      margin = {
        type="range",
        name=L["Margin"],
        desc=L["The margin between the outer edge and the background texture."],
        min=0,
        max=50,
        step=0.5,
        get=function() return db.title.margin end,
        set=function(win, val)
        db.title.margin = val
        Skada:ApplySettings()
        end,
        order=6,
      },

      color = {
        type="color",
        name=L["Background color"],
        desc=L["The background color of the title."],
        hasAlpha=true,
        get=function(i)
        local c = db.title.color
        return c.r, c.g, c.b, c.a
        end,
        set=function(i, r,g,b,a)
        db.title.color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
        Skada:ApplySettings()
        end,
        order=7,
      },

      menubutton = {
        type="toggle",
        name=L["Show menu button"],
        desc=L["Shows a button for opening the menu in the window title bar."],
        order=8,
        get=function() return db.title.menubutton == nil or db.title.menubutton end,
        set=function()
        db.title.menubutton = not db.title.menubutton
        Skada:ApplySettings()
        end,
      },

    }
  }

  options.windowoptions = {
    type = "group",
    name = L["Background"],
    order=2,
    args = {

      enablebackground = {
        type="toggle",
        name=L["Enable"],
        desc=L["Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."],
        order=0,
        get=function() return db.enablebackground end,
        set=function()
        db.enablebackground = not db.enablebackground
        Skada:ApplySettings()
        end,
      },

      texture = {
        type = 'select',
        dialogControl = 'LSM30_Background',
        name = L["Background texture"],
        desc = L["The texture used as the background."],
        values = AceGUIWidgetLSMlists.background,
        get = function() return db.background.texture end,
        set = function(win,key)
        db.background.texture = key
        Skada:ApplySettings()
        end,
        order=1,
      },

      bordertexture = {
        type = 'select',
        dialogControl = 'LSM30_Border',
        name = L["Border texture"],
        desc = L["The texture used for the borders."],
        values = AceGUIWidgetLSMlists.border,
        get = function() return db.background.bordertexture end,
        set = function(win,key)
        db.background.bordertexture = key
        Skada:ApplySettings()
        end,
        order=2,
      },

      thickness = {
        type="range",
        name=L["Border thickness"],
        desc=L["The thickness of the borders."],
        min=0,
        max=50,
        step=0.5,
        get=function() return db.background.borderthickness end,
        set=function(win, val)
        db.background.borderthickness = val
        Skada:ApplySettings()
        end,
        order=3,
      },

      margin = {
        type="range",
        name=L["Margin"],
        desc=L["The margin between the outer edge and the background texture."],
        min=0,
        max=50,
        step=0.5,
        get=function() return db.background.margin end,
        set=function(win, val)
        db.background.margin = val
        Skada:ApplySettings()
        end,
        order=4,
      },

      height = {
        type="range",
        name=L["Window height"],
        desc=L["The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."],
        min=0,
        max=600,
        step=1,
        get=function() return db.background.height end,
        set=function(win, height)
        db.background.height = height
        Skada:ApplySettings()
        end,
        order=5,
      },

      color = {
        type="color",
        name=L["Background color"],
        desc=L["The color of the background."],
        hasAlpha=true,
        get=function(i)
        local c = db.background.color
        return c.r, c.g, c.b, c.a
        end,
        set=function(i, r,g,b,a)
        db.background.color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
        Skada:ApplySettings()
        end,
        order=6,
      },

    }
  }
end
