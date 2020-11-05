local Skada=Skada
if not Skada then return end

Skada:AddLoadableModule("Improvement", nil, function(Skada, L)
  if Skada:IsDisabled("Improvement") then return end

  local mod=Skada:NewModule(L["Improvement"])
  local mod_modes=mod:NewModule(L["Improvement modes"])
  local mod_comparison=mod:NewModule(L["Improvement comparison"])

  local UnitGUID, UnitName, UnitClass=UnitGUID, UnitName, UnitClass
  local pairs, ipairs, select, tostring=pairs, ipairs, select, tostring
  local SecondsToTime, date=SecondsToTime, date

  local db
  local modes={
    "ActiveTime",
    "Damage",
    "DamageTaken",
    "Deaths",
    "Fails",
    "Healing",
    "Interrupts",
    "Overhealing"
  }

  -- events frame
  local f=CreateFrame("Frame")

  -- :::::::::::::::::::::::::::::::::::::::::::::::

  local updaters={}

  updaters.ActiveTime=function(set, player)
    return Skada:PlayerActiveTime(set, player)
  end

  updaters.Damage=function(set, player)
    return player.damagedone and player.damagedone.amount or 0
  end

  updaters.DamageTaken=function(set, player)
    return player.damagetaken and player.damagetaken.amount or 0
  end

  updaters.Deaths=function(set, player)
    return player.deaths or 0
  end

  updaters.Healing=function(set, player)
    local total=0
    if player.healing then
      total=total+player.healing.amount
    end
    if player.absorbs then
      total=total+player.absorbs.total
    end
    return total
  end

  updaters.Interrupts=function(set, player)
    return player.interrupts.count
  end

  updaters.Fails=function(set, player)
    return player.fails and player.fails.count or 0
  end

  -- :::::::::::::::::::::::::::::::::::::::::::::::

  local function find_boss_data(bossname)
    db=db or SkadaImprovementDB
    for k, v in pairs(db.bosses) do
      if k==bossname then
        v.lasttime=currenttime
        return v
      end
    end

    local boss={count=0, encounters={}}
    db.bosses[bossname]=boss
    return find_boss_data(bossname)
  end

  local function find_encounter_data(boss, starttime)
    for i, encounter in ipairs(boss.encounters) do
      if encounter.starttime==starttime then
        return encounter
      end
    end

    tinsert(boss.encounters,{starttime=starttime, data={}})
    return find_encounter_data(boss, starttime)
  end

  local function EventHandler(self, event, ...)
    -- sorry but we only record raid bosses
    local inInstance, instanceType=IsInInstance()
    if not inInstance or instanceType~="raid" then return end
    if not Skada.current or not Skada.current.gotboss then return end

    if event=="PLAYER_REGEN_ENABLED" then

      local boss=find_boss_data(Skada.current.mobname)
      if not boss then return end

      local encounter=find_encounter_data(boss, Skada.current.starttime)
      if not encounter then return end
      

      for i, player in ipairs(Skada.current.players) do
        if player.id==db.id then
          for _, mode in ipairs(modes) do
            if updaters[mode] then
              encounter.data[mode]=updaters[mode](Skada.current, player)
            else
              encounter.data[mode]=player[mode:lower()]
            end
          end
          
          -- increment boss count and stop
          boss.count=boss.count+1
          if boss.count~=#boss.encounters then
            boss.count=#boss.encounters
          end
          break
        end
      end
    end
  end

  function mod_modes:Enter(win, id, label)
    self.mobid=id
    self.mobname=label
    self.title=format(L["%s's overall data"], label)
  end

  function mod_modes:Update(win, set)
    local boss=find_boss_data(self.mobname)
    local max=0

    if boss then
      local nr=1

      for i, mode in ipairs(modes) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=i
        d.label=mode

        local value, active=0, 0

        for i, encounter in ipairs(boss.encounters) do
          value=value+(encounter.data[mode] or 0)
          active=active+(encounter.data.ActiveTime or 0)
        end

        d.value=value

        if mode=="ActiveTime" then
          d.valuetext=SecondsToTime(d.value)
        elseif mode=="Deaths" or mode=="Interrupts" or mode=="Fails" then
          d.valuetext=tostring(d.value)
        else
          d.valuetext=Skada:FormatValueText(
            Skada:FormatNumber(d.value), true,
            Skada:FormatNumber(d.value/active), true
          )
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod_comparison:Enter(win, id, label)
    self.mobid=id
    self.modename=label
    self.title=mod_modes.mobname.." - "..label
  end

  function mod_comparison:Update(win, set)

    local max=0
    local boss=find_boss_data(mod_modes.mobname)
    if boss then
      local nr=1

      for i=1, boss.count do
        local encounter=boss.encounters[i]
        if encounter then
          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=i
          d.label=date("%x %X", encounter.starttime)
          d.value=encounter.data[self.modename]

          if self.modename=="ActiveTime" then
            d.valuetext=SecondsToTime(d.value)
          elseif self.modename=="Deaths" or self.modename=="Interrupts" or self.modename=="Fails" then
            d.valuetext=tostring(d.value)
          else
            d.valuetext=Skada:FormatValueText(
              Skada:FormatNumber(d.value), true,
              Skada:FormatNumber(d.value/encounter.data.ActiveTime), true
            )
          end

          if i>max then
            max=i
          end

          nr=nr+1
        end
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:Update(win, set)
    if not db then
      db=SkadaImprovementDB
    end

    local nr, max=1, 0
    if db.bosses then
      for name, data in pairs(db.bosses) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=name
        d.label=name
        d.value=data.count
        d.valuetext=tostring(data.count)

        if data.count>max then
          max=data.count
        end

        nr=nr+1
      end
    end
    win.metadata.maxvalue=max
  end

  function mod:OnInitialize()
    -- make our DB local
    SkadaImprovementDB=SkadaImprovementDB or {}
    if next(SkadaImprovementDB)==nil then
      SkadaImprovementDB={
        id=UnitGUID("player"),
        name=UnitName("player"),
        class=select(2, UnitClass("player")),
        bosses={}
      }
    end
    db=SkadaImprovementDB
  end

  function mod:OnEnable()
    mod.metadata={click1=mod_modes}
    mod_modes.metadata={click1=mod_comparison}

    Skada:AddMode(self)

    -- register required frame events.
    f:RegisterEvent('PLAYER_REGEN_ENABLED')
    f:SetScript("OnEvent", EventHandler)
  end

  function mod:OnDisable()
    Skada:RemoveMode(self)
    
    -- unregister frame events.
    f:UnregisterEvent('PLAYER_REGEN_ENABLED')
    f:SetScript("OnEvent", nil)
  end

  local function ask_for_reset()
    StaticPopupDialogs["ResetImprovementDialog"] = {
      text = L["Do you want to reset your improvement data?"],
      button1 = ACCEPT,
      button2 = CANCEL,
      timeout = 30,
      whileDead = 0,
      hideOnEscape = 1,
      OnAccept = function() mod:Reset() end,
    }
    StaticPopup_Show("ResetImprovementDialog")
  end

  function mod:Reset()
    Skada:Wipe()
    SkadaImprovementDB={}
    self:OnInitialize()
    collectgarbage("collect")
    for _, win in ipairs(Skada:GetWindows()) do
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
end)
