local Skada=Skada
if not Skada then return end

local L=LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local pairs, ipairs=pairs, ipairs
local format=string.format
local GetSpellInfo=GetSpellInfo

local function log_auraapply(set, aura)
  if not set then return end
  local player=Skada:get_player(set, aura.srcGUID, aura.srcName)
  if not player then return end

  if aura.auratype=="BUFF" then
    if not player.buffs[aura.spellname] then
      player.buffs[aura.spellname]={id=aura.spellid, active=1, refresh=0, uptime=0}
    else
      player.buffs[aura.spellname].active=player.buffs[aura.spellname].active+1
      player.buffs[aura.spellname].refresh=player.buffs[aura.spellname].refresh+1
    end
  
  elseif aura.auratype=="DEBUFF" then
    if not player.debuffs[aura.spellname] then
      player.debuffs[aura.spellname]={id=aura.spellid, active=1, refresh=1, uptime=0, targets={}}
    else
      player.debuffs[aura.spellname].active=player.debuffs[aura.spellname].active+1
      player.debuffs[aura.spellname].refresh=player.debuffs[aura.spellname].refresh+1
    end

    if set==Skada.current and aura.srcName~= aura.dstName then
      if not player.debuffs[aura.spellname].targets[aura.dstName] then
        player.debuffs[aura.spellname].targets[aura.dstName]={id=aura.dstGUID, refresh=0}
      end
      player.debuffs[aura.spellname].targets[aura.dstName].refresh=player.debuffs[aura.spellname].targets[aura.dstName].refresh+1
    end
  end
end

local function log_auraremove(set, aura)
  if not set then return end
  local player=Skada:get_player(set, aura.srcGUID, aura.srcName)
  if not player then return end

  if aura.auratype=="BUFF" then
    if player.buffs[aura.spellname] then
      if player.buffs[aura.spellname].active>1 then
        player.buffs[aura.spellname].active=player.buffs[aura.spellname].active-1
      end
    end
  elseif aura.auratype=="DEBUFF" then
    if player.debuffs[aura.spellname] then
      if player.debuffs[aura.spellname].active>1 then
        player.debuffs[aura.spellname].active=player.debuffs[aura.spellname].active-1
      end
    end
  end
end

local aura={}

local function AuraApplied(timestamp, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
  local spellid, spellname, spellschool, auratype=...
  if auratype=="BUFF" or auratype=="DEBUFF" then
    srcGUID, srcName=Skada:FixMyPets(srcGUID, srcName)
    
    aura.srcGUID=srcGUID
    aura.srcName=srcName
    aura.dstGUID=dstGUID
    aura.dstName=dstName
    aura.spellid=spellid
    aura.spellname=spellname
    aura.spellschool=spellschool
    aura.auratype=auratype

    log_auraapply(Skada.current, aura)
    log_auraapply(Skada.total, aura)
  end
end

local function AuraRemoved(timestamp, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
  local spellid, spellname, spellschool, auratype=...
  if auratype=="BUFF" or auratype=="DEBUFF" then
    srcGUID, srcName=Skada:FixMyPets(srcGUID, srcName)
    
    aura.srcGUID=srcGUID
    aura.srcName=srcName
    aura.dstGUID=dstGUID
    aura.dstName=dstName
    aura.spellid=spellid
    aura.spellname=spellname
    aura.spellschool=spellschool
    aura.auratype=auratype

    log_auraremove(Skada.current, aura)
    log_auraremove(Skada.total, aura)
  end
end

local function len(t)
  local l=0
  for i, j in pairs(t) do
    l=l+1
  end
  return l
end


-- :::::::::::::::::::::::::::::::::::
-- Buffs uptime
-- :::::::::::::::::::::::::::::::::::

do
  local mod=Skada:NewModule(L["Auras: Buff uptime"], "AceTimer-3.0")
  local playermod=mod:NewModule(L["Auras spell list"])

  local function aura_tooltip(win, id, label, tooltip)
    local set=win:get_selected_set()
    local player=Skada:find_player(set, playermod.playerid)
    if not player then return end

    local buff
    for spellname, spell in pairs(player.buffs) do
      if spellname==label then
        buff=spell
        buff.name=spellname
        break
      end
    end

    if not buff then return end

    local totaltime=Skada:PlayerActiveTime(set, player)
    local uptime=buff.uptime
    tooltip:AddLine(label)
    tooltip:AddDoubleLine(L["Active Time"], SecondsToTime(totaltime), 255,255,255,255,255,255)
    tooltip:AddDoubleLine(L["Buff Uptime"], SecondsToTime(uptime), 255,255,255,255,255,255)
    tooltip:AddDoubleLine((L["Refreshes"]), buff.refresh, 255,255,255,255,255,255)
    tooltip:AddDoubleLine(("%d/%d"):format(uptime, totaltime), ("%02.1f%%)"):format(uptime/totaltime*100), 255,255,255,255,255,255)
  end

  function playermod:Enter(win, id, label)
    self.playerid=id
    self.title=format(L["%s's buff uptime"], label)
  end

  function playermod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0

    if player then
      local nr=1
      
      local maxtime=Skada:PlayerActiveTime(set, player)
      max=maxtime

      for spellname, spell in pairs(player.buffs) do
        local uptime=spell.uptime

        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=spellname
        d.label=spellname
        d.icon=select(3, GetSpellInfo(spell.id))
        d.value=uptime
        d.valuetext=("%ds (%02.1f%%)"):format(uptime, uptime/maxtime*100)

        nr=nr + 1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:Update(win, set)
    local nr, max=1, 0

    for i, player in ipairs(set.players) do
      local count=len(player.buffs)
      
      if count>0 then
        local maxtime=Skada:PlayerActiveTime(set, player)
        local uptime=player.buff_uptime/count

        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=player.id
        d.label=player.name
        d.class=player.class
        d.icon=d.class and Skada.classIcon or Skada.petIcon
        d.value=uptime
        d.valuetext=("%02.1f%% / %u"):format(uptime/maxtime*100, count)

        max=maxtime
        nr=nr + 1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:OnEnable()
    playermod.metadata={showspots=true, tooltip=aura_tooltip}
    mod.metadata={click1=playermod}

    Skada:RegisterForCL(AuraApplied, 'SPELL_AURA_APPLIED', {src_is_interesting=true})
    Skada:RegisterForCL(AuraRemoved, 'SPELL_AURA_REMOVED', {src_is_interesting=true})

    self:ScheduleRepeatingTimer("Tick", 1)

    Skada:AddMode(self)
  end

  function mod:OnDisable()
    Skada:RemoveMode(self)
  end

  -- Called by Skada when a new player is added to a set.
  function mod:AddPlayerAttributes(player)
    if not player.buffs then
      player.buffs={}
      player.buff_uptime=0
    end
  end

  local function tick_spells(set)
    for i, player in ipairs(set.players) do
      for spellname, spell in pairs(player.buffs) do
        if spell.active>1 then
          spell.uptime=spell.uptime+1
          player.buff_uptime=player.buff_uptime+1
        end
      end
    end
  end

  function mod:Tick()
    if Skada.current then
      tick_spells(Skada.current)
      tick_spells(Skada.total)
    end
  end
end

-- :::::::::::::::::::::::::::::::::::
-- Debuffs uptime
-- :::::::::::::::::::::::::::::::::::

do
  local mod=Skada:NewModule(L["Auras: Debuff uptime"], "AceTimer-3.0")
  local playermod=mod:NewModule(L["Auras spell list"])
  local targetmod=mod:NewModule(L["Auras target list"])

  local function aura_tooltip(win, id, label, tooltip)
    local set=win:get_selected_set()
    local player=Skada:find_player(set, playermod.playerid)
    if not player then return end

    local debuff
    for spellname, spell in pairs(player.debuffs) do
      if spellname==label then
        debuff=spell
        debuff.name=spellname
        break
      end
    end

    if not debuff then return end

    local totaltime=Skada:PlayerActiveTime(set, player)
    local uptime=debuff.uptime
    tooltip:AddLine(label)
    tooltip:AddDoubleLine(L["Active Time"], SecondsToTime(totaltime), 255,255,255,255,255,255)
    tooltip:AddDoubleLine(L["Debuff Uptime"], SecondsToTime(uptime), 255,255,255,255,255,255)
    tooltip:AddDoubleLine((L["Refreshes"]), debuff.refresh, 255,255,255,255,255,255)
    tooltip:AddDoubleLine(("%d/%d"):format(uptime, totaltime), ("%02.1f%%)"):format(uptime/totaltime*100), 255,255,255,255,255,255)
  end

  function targetmod:Enter(win, id, label)
    self.spellname=id
    local player=Skada:find_player(win:get_selected_set(), playermod.playerid)
    if player then
      self.title=format(L["%s's <%s> targets"], player.name, label)
    end
  end

  function targetmod:Update(win, set)
    local player=Skada:find_player(set, playermod.playerid)
    local max=0

    if player and self.spellname and player.debuffs[self.spellname] then
      local nr=1
      local spell=player.debuffs[self.spellname]
      for targetname, target in pairs(spell.targets) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=target.id
        d.label=targetname
        d.value=target.refresh
        d.valuetext=format("%s (%02.1f%%)", target.refresh, target.refresh/spell.refresh*100)

        if target.refresh>max then
          max=target.refresh
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function playermod:Enter(win, id, label)
    self.playerid=id
    self.title=format(L["%s's debuff uptime"], label)
  end

  function playermod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0

    if player then
      local nr=1
      
      local maxtime=Skada:PlayerActiveTime(set, player)
      max=maxtime

      for spellname, spell in pairs(player.debuffs) do
        local uptime=spell.uptime

        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=spellname
        d.label=spellname
        d.icon=select(3, GetSpellInfo(spell.id))
        d.value=uptime
        d.valuetext=format("%s (%02.1f%%)", SecondsToTime(uptime), uptime/maxtime*100)

        nr=nr + 1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:Update(win, set)
    local nr, max=1, 0

    for i, player in ipairs(set.players) do
      local maxtime=Skada:PlayerActiveTime(set, player)
      max=maxtime
      
      local count=len(player.debuffs)
      
      if count>0 then
        local uptime=player.debuff_uptime/count

        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=player.id
        d.label=player.name
        d.class=player.class
        d.icon=d.class and Skada.classIcon or Skada.petIcon
        d.value=uptime
        d.valuetext=format("%02.1f%% / %u", uptime/maxtime*100, count)

        nr=nr + 1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:OnEnable()
    targetmod.metadata={showspots=true}
    playermod.metadata={tooltip=aura_tooltip, click1=targetmod}
    mod.metadata={showspots=true, click1=playermod}

    Skada:RegisterForCL(AuraApplied, 'SPELL_AURA_APPLIED', {src_is_interesting=true})
    Skada:RegisterForCL(AuraRemoved, 'SPELL_AURA_REMOVED', {src_is_interesting=true})

    self:ScheduleRepeatingTimer("Tick", 1)

    Skada:AddMode(self)
  end

  function mod:OnDisable()
    Skada:RemoveMode(self)
  end

  -- Called by Skada when a new player is added to a set.
  function mod:AddPlayerAttributes(player)
    if not player.debuffs then
      player.debuffs={}
      player.debuff_uptime=0
    end
  end

  local function tick_spells(set)
    for i, player in ipairs(set.players) do
      for spellname, spell in pairs(player.debuffs) do
        if spell.active>1 then
          spell.uptime=spell.uptime+1
          player.debuff_uptime=player.debuff_uptime+1
        end
      end
    end
  end

  function mod:Tick()
    if Skada.current then
      tick_spells(Skada.current)
      tick_spells(Skada.total)
    end
  end
end

-- :::::::::::::::::::::::::::::::::::
-- Sunder counter
-- :::::::::::::::::::::::::::::::::::
do
  local mod=Skada:NewModule(L["Auras: Sunders Counter"])
  local targetmod=mod:NewModule(L["Auras target list"])
  local sunder

  function targetmod:Enter(win, id, label)
    self.playerid=id
    self.title=format(L["%s's debuff targets"], label)
  end

  function targetmod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0
    sunder=sunder or select(1, GetSpellInfo(47467))

    if player and player.debuffs[sunder] then
      local spell=player.debuffs[sunder]
      local nr=1

      for targetname, target in pairs(spell.targets) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=target.id
        d.label=targetname
        d.value=target.refresh
        d.valuetext=format("%d (%02.1f%%)", target.refresh, target.refresh/spell.refresh*100)

        if target.refresh>max then
          max=target.refresh
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:Update(win, set)
    local nr, max=1, 0
    sunder=sunder or select(1, GetSpellInfo(47467))

    local total=0
    for i, player in ipairs(set.players) do
      if player.class and player.class=="WARRIOR" then
        local count=len(player.debuffs)
        if count>0 then
          for spellname, spell in pairs(player.debuffs) do
            if spellname==sunder or spell.id==47467 then
              total=total+spell.refresh

              local d=win.dataset[nr] or {}
              win.dataset[nr]=d


              d.id=player.id
              d.label=player.name
              d.class="WARRIOR"
              d.icon=Skada.classIcon

              d.value=spell.refresh
              d.valuetext=format("%d (%02.1f%%)", spell.refresh, spell.refresh/total*100)

              if spell.refresh>max then
                max=spell.refresh
              end

              nr=nr+1
            end
          end
        end
      end
    end
    
    win.metadata.maxvalue=max
  end

  function mod:OnInitialize()
    sunder=select(1, GetSpellInfo(47467))
  end

  function mod:OnEnable()
    targetmod.metadata={showspots=true}
    mod.metadata={showspots=true, click1=targetmod}
    Skada:AddMode(self)
  end

  function mod:OnDisable()
    Skada:RemoveMode(self)
  end
end
