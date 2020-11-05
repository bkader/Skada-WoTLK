local Skada=Skada
if not Skada then return end

Skada:AddLoadableModule("Dispels", nil, function(Skada, L)
  if Skada:IsDisabled("Dispels") then return end

  local mod=Skada:NewModule(L["Dispels"])
  local spellsmod=mod:NewModule(L["Dispelled spell list"])
  local targetsmod=mod:NewModule(L["Dispelled target list"])
  local playermod=mod:NewModule(L["Dispel spell list"])

  local format, tostring=string.format, tostring
  local pairs, ipairs, select=pairs, ipairs, select
  local GetSpellInfo=GetSpellInfo

  local function log_dispels(set, data)
    local player=Skada:get_player(set, data.playerid, data.playername)
    if not player then return end
    
    player.dispels.count=player.dispels.count+1

    if not player.dispels.spells[data.spellname] then
      player.dispels.spells[data.spellname]={id=data.spellid, count=0}
    end
    player.dispels.spells[data.spellname].count=player.dispels.spells[data.spellname].count+1

    if not player.dispels.extraspells[data.extraspellname] then
      player.dispels.extraspells[data.extraspellname]={id=data.extraspellid, count=0}
    end
    player.dispels.extraspells[data.extraspellname].count=player.dispels.extraspells[data.extraspellname].count+1

    if not player.dispels.targets[data.dstName] then
      player.dispels.targets[data.dstName]={id=data.dstGUID, count=0}
    end
    player.dispels.targets[data.dstName].count=player.dispels.targets[data.dstName].count+1

    set.dispels=set.dispels+1
  end

  local data={}

  local function SpellDispel(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    -- Dispells
    local spellid, spellname, spellschool, extraspellid, extraspellname, extraschool, auraType=...

    data.srcGUID=srcGUID
    data.srcName=srcName
    data.srcFlags=srcFlags
    data.dstGUID=dstGUID
    data.dstName=dstName
    data.dstFlags=dstFlags
    data.spellid=spellid
    data.spellname=spellname
    data.extraspellid=extraspellid
    data.extraspellname=extraspellname

    Skada:FixPets(data)

    log_dispels(Skada.current, data)
    log_dispels(Skada.total, data)
  end

  function spellsmod:Enter(win, id, label)
    self.playerid=id
    self.title=format(L["%s's dispelled spells"], label)
  end

  function spellsmod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0

    if player then
      local nr=1

      for spellname, spell in pairs(player.dispels.extraspells) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=spellname
        d.label=spellname
        d.icon=select(3, GetSpellInfo(spell.id))
        d.spellid=spell.id
        d.value=spell.count
        d.valuetext=tostring(spell.count)

        if spell.count>max then
          max=spell.count
        end
        
        nr=nr+1
      end

    end

    win.metadata.maxvalue=max
  end

  function targetsmod:Enter(win, id, label)
    self.playerid=id
    self.title=format(L["%s's dispelled targets"], label)
  end

  function targetsmod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=1

    if player then
      local nr=1
      for targetname, target in pairs(player.dispels.targets) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=target.id
        d.label=targetname
        d.value=target.count
        d.valuetext=tostring(target.count)

        if target.count>max then
          max=target.count
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function playermod:Enter(win, id, label)
    self.playerid=id
    self.title=format(L["%s's dispel spells"], label)
  end

  function playermod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0

    if player then
      local nr=1

      for spellname, spell in pairs(player.dispels.spells) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=spellname
        d.label=spellname
        d.icon=select(3, GetSpellInfo(spell.id))
        d.spellid=spell.id
        d.value=spell.count
        d.valuetext=tostring(spell.count)

        if spell.count>max then
          max=spell.count
        end
        
        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end
  function mod:Update(win, set)
    local nr, max=1, 0
    for i, player in ipairs(set.players) do
      if player.dispels.count>0 then
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=player.id
        d.label=player.name
        d.class=player.class
        d.role=player.role

        d.value=player.dispels.count
        d.valuetext=tostring(player.dispels.count)
        if player.dispels.count>max then
          max=player.dispels.count
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end


  function mod:OnEnable()
    spellsmod.metadata={}
    targetsmod.metadata={}
    playermod.metadata={}
    mod.metadata={showspots=true, click1=spellsmod, click2=targetsmod, click3=playermod}

    Skada:RegisterForCL(SpellDispel, 'SPELL_STOLEN', {src_is_interesting=true})
    Skada:RegisterForCL(SpellDispel, 'SPELL_DISPEL', {src_is_interesting=true})

    Skada:AddMode(self)
  end

  function mod:OnDisable()
    Skada:RemoveMode(self)
  end

  function mod:AddToTooltip(set, tooltip)
    GameTooltip:AddDoubleLine(L["Dispels"], set.dispels, 1,1,1)
  end

  function mod:AddPlayerAttributes(player)
    if not player.dispels then
      player.dispels={count=0, spells={}, extraspells={}, targets={}}
    end
  end

  function mod:AddSetAttributes(set)
    set.dispels=set.dispels or 0
  end

  function mod:GetSetSummary(set)
    return set.dispels
  end

  function mod:SetComplete(set)
    for i, player in ipairs(set.players) do
      if player.dispels.count==0 then
        player.dispels.spells=nil
        player.dispels.extraspells=nil
        player.dispels.targets=nil
      end
    end
  end
end)
