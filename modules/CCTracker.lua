local _, Skada=...
if not Skada then return end

local CCSpells={
  [118]=true, -- Polymorph (rank 1)
  [12824]=true, -- Polymorph (rank 2)
  [12825]=true, -- Polymorph (rank 3)
  [12826]=true, -- Polymorph (rank 4)
  [28272]=true, -- Polymorph (rank 1:pig)
  [28271]=true, -- Polymorph (rank 1:turtle)
  [9484]=true, -- Shackle Undead (rank 1)
  [9485]=true, -- Shackle Undead (rank 2)
  [10955]=true, -- Shackle Undead (rank 3)
  [3355]=true, -- Freezing Trap Effect (rank 1)
  [14308]=true, -- Freezing Trap Effect (rank 2)
  [14309]=true, -- Freezing Trap Effect (rank 3)
  [2637]=true, -- Hibernate (rank 1)
  [18657]=true, -- Hibernate (rank 2)
  [18658]=true, -- Hibernate (rank 3)
  [6770]=true, -- Sap (rank 1)
  [2070]=true, -- Sap (rank 2)
  [11297]=true, -- Sap (rank 3)
  [6358]=true, -- Seduction (succubus)
  [60210]=true, -- Freezing Arrow (rank 1)
  [45524]=true, -- Chains of Ice
  [33786]=true, -- Cyclone
  [53308]=true, -- Entangling Roots
  [2637]=true, -- Hibernate (rank 1)
  [18657]=true, -- Hibernate (rank 2)
  [18658]=true, -- Hibernate (rank 3)
  [20066]=true, -- Repentance 
  [9484]=true, -- Shackle Undead (rank 1)
  [9485]=true, -- Shackle Undead (rank 2)
  [10955]=true, -- Shackle Undead (rank 3)
  [51722]=true, -- Dismantle
  [710]=true, -- Banish (Rank 1)
  [18647]=true, -- Banish (Rank 2)
  [12809]=true, -- Concussion Blow
  [676]=true, -- Disarm
}

local pairs, ipairs, select=pairs, ipairs, select
local tostring, format=tostring, string.format
local GetSpellInfo, GetSpellLink=GetSpellInfo, GetSpellLink

-- ======= --
-- CC Done --
-- ======= --
do
  local modname="CC Done"
  Skada:AddLoadableModule(modname, nil, function(Skada, L)
    if Skada.db.profile.modulesBlocked[modname] then return end
    
    local mod=Skada:NewModule(L[modname])
    local spellsmod=mod:NewModule(L["CC Done Spells"])
    local spelltargetsmod=mod:NewModule(L["CC Done Spell Targets"])
    local targetsmod=mod:NewModule(L["CC Done Targets"])
    local targetspellsmod=mod:NewModule(L["CC Done Target Spells"])

    local function log_ccdone(set, data)
      local player=Skada:get_player(set, data.srcGUID, data.srcName)
      if not player then return end
      
      player.ccdone.count=player.ccdone.count+1

      if not player.ccdone.spells[data.spellname] then
        player.ccdone.spells[data.spellname]={id=data.spellid, count=0, targets={}}
      end
      player.ccdone.spells[data.spellname].count=player.ccdone.spells[data.spellname].count+1

      if not player.ccdone.spells[data.spellname].targets[data.dstName] then
        player.ccdone.spells[data.spellname].targets[data.dstName]={id=data.dstGUID, count=0}
      end
      player.ccdone.spells[data.spellname].targets[data.dstName].count=player.ccdone.spells[data.spellname].targets[data.dstName].count+1

      if not player.ccdone.targets[data.dstName] then
        player.ccdone.targets[data.dstName]={id=data.dstGUID, count=0, spells={}}
      end
      player.ccdone.targets[data.dstName].count=player.ccdone.targets[data.dstName].count+1

      if not player.ccdone.targets[data.dstName].spells[data.spellname] then
        player.ccdone.targets[data.dstName].spells[data.spellname]={id=data.spellid, count=0}
      end
      player.ccdone.targets[data.dstName].spells[data.spellname].count=player.ccdone.targets[data.dstName].spells[data.spellname].count+1

      set.ccdone=set.ccdone+1
    end

    local data={}
    local function SpellAuraApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
      local spellid, spellname, spellschool, auratype, extraspellid, extraspellname, extraschool

      if eventtype == "SPELL_AURA_APPLIED" or eventtype == "SPELL_AURA_REFRESH" then
        spellid, spellname, spellschool, auratype=...
      else
        spellid, spellname, spellschool, extraspellid, extraspellname, extraschool, auratype=...
      end

      if CCSpells[spellid] then
        srcGUID,srcName=Skada:FixMyPets(srcGUID, srcName)
        dstGUID,dstName=Skada:FixMyPets(dstGUID, dstName)
        
        data.srcGUID=srcGUID
        data.srcName=srcName
        data.dstGUID=dstGUID
        data.dstName=dstName
        data.spellid=spellid
        data.spellname=spellname
        data.extraspellid=extraspellid
        data.extraspellname=extraspellname

        log_ccdone(Skada.current, data)
        log_ccdone(Skada.total, data)
      end
    end

    function spellsmod:Enter(win, id, label)
      local player=Skada:find_player(win:get_selected_set(), id)
      if player then
        self.playerid=id
        self.title=player.name..L["'s "]..L["CC Done Spells"]
      end
    end

    function spellsmod:Update(win, set)
      local player=Skada:find_player(set, self.playerid)
      local max=0

      if player then
        local nr=1

        for spellname, spell in pairs(player.ccdone.spells) do
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

    function spelltargetsmod:Enter(win, id, label)
      self.spellname=label
      local player=Skada:find_player(win:get_selected_set(), spellsmod.playerid)
      if player then
        self.title=format(L["%s's CC Done <%s> targets"], player.name, label)
      end
    end

    function spelltargetsmod:Update(win, set)
      local player=Skada:find_player(set,spellsmod.playerid)
      local max=0

      if player and self.spellname then
        local nr=1

        for targetname, target in pairs(player.ccdone.spells[self.spellname].targets) do
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

    function targetsmod:Enter(win, id, label)
      self.playerid=id
      local player=Skada:find_player(win:get_selected_set(), id)
      if player then
        self.title=player.name..L["'s "]..L["CC Done Targets"]
      end
    end

    function targetsmod:Update(win, set)
      local player=Skada:find_player(set, self.playerid)
      local max=0

      if player then
        local nr=1

        for targetname, target in pairs(player.ccdone.targets) do
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

    function targetspellsmod:Enter(win, id, label)
      self.targetname=label
      local player=Skada:find_player(win:get_selected_set(), spellsmod.playerid)
      if player then
        self.title=format("%s's CC Done <%s> spells", player.name, label)
      end
    end

    function targetspellsmod:Update(win, set)
      local player=Skada:find_player(set,spellsmod.playerid)
      local max=0

      if player and self.targetname then
        local nr=1

        for spellname, spell in pairs(player.ccdone.targets[self.targetname].spells) do
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
      local max, nr=0, 1
      for i, player in ipairs(set.players) do
        if player.ccdone.count>0 then
          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=player.id
          d.label=player.name
          d.class=player.class
          d.icon=d.class and Skada.classIcon or Skada.petIcon
          d.value=player.ccdone.count
          d.valuetext=tostring(player.ccdone.count)
          
          if player.ccdone.count>max then
            max=player.ccdone.count
          end
          nr=nr+1
        end
      end

      win.metadata.maxvalue=max
    end

    function mod:OnEnable()
      spelltargetsmod.metadata={}
      spellsmod.metadata={click1=spelltargetsmod}
      
      targetspellsmod.metadata={}
      targetsmod.metadata={click1=targetspellsmod}
      
      mod.metadata={showspots=true, click1=spellsmod, click2=targetsmod}

      Skada:RegisterForCL(SpellAuraApplied, 'SPELL_AURA_APPLIED', {src_is_interesting=true})
      Skada:RegisterForCL(SpellAuraApplied, 'SPELL_AURA_REFRESH', {src_is_interesting=true})
      
      Skada:AddMode(self)
    end

    function mod:OnDisable()
      Skada:RemoveMode(self)
    end

    function mod:GetSetSummary(set)
      return set.ccdone
    end

    function mod:AddPlayerAttributes(player)
      if not player.ccdone then
        player.ccdone={count=0, spells={}, targets={}}
      end
    end

    function mod:AddSetAttributes(set)
      set.ccdone=set.ccdone or 0
    end

    function mod:SetComplete(set)
      for i, player in ipairs(set.players) do
        if player.ccdone.count==0 then
          player.ccdone.spells=nil
          player.ccdone.targets=nil
        end
      end
    end
  end)
end

-- ======== --
-- CC Taken --
-- ======== --
do
  local modname="CC Taken"
  Skada:AddLoadableModule(modname, nil, function(Skada, L)
    if Skada.db.profile.modulesBlocked[modname] then return end
    
    local mod=Skada:NewModule(L[modname])
    local spellsmod=mod:NewModule(L["CC Taken Spells"])
    local spellsourcesmod=mod:NewModule(L["CC Taken Spell Sources"])
    local sourcesmod=mod:NewModule(L["CC Taken Sources"])
    local sourcespellsmod=mod:NewModule(L["CC Taken Source Spells"])

    local function log_cctaken(set, data)
      local player=Skada:get_player(set, data.srcGUID, data.srcName)
      if not player then return end
      
      player.cctaken.count=player.cctaken.count+1

      if not player.cctaken.spells[data.spellname] then
        player.cctaken.spells[data.spellname]={id=data.spellid, count=0, sources={}}
      end
      player.cctaken.spells[data.spellname].count=player.cctaken.spells[data.spellname].count+1

      if not player.cctaken.spells[data.spellname].sources[data.dstName] then
        player.cctaken.spells[data.spellname].sources[data.dstName]={id=data.dstGUID, count=0}
      end
      player.cctaken.spells[data.spellname].sources[data.dstName].count=player.cctaken.spells[data.spellname].sources[data.dstName].count+1

      if not player.cctaken.sources[data.dstName] then
        player.cctaken.sources[data.dstName]={id=data.dstGUID, count=0, spells={}}
      end
      player.cctaken.sources[data.dstName].count=player.cctaken.sources[data.dstName].count+1

      if not player.cctaken.sources[data.dstName].spells[data.spellname] then
        player.cctaken.sources[data.dstName].spells[data.spellname]={id=data.spellid, count=0}
      end
      player.cctaken.sources[data.dstName].spells[data.spellname].count=player.cctaken.sources[data.dstName].spells[data.spellname].count+1

      set.cctaken=set.cctaken+1
    end

    local data={}
    local function SpellAuraApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
      local spellid, spellname, spellschool, auratype, extraspellid, extraspellname, extraschool

      if eventtype == "SPELL_AURA_APPLIED" or eventtype == "SPELL_AURA_REFRESH" then
        spellid, spellname, spellschool, auratype=...
      else
        spellid, spellname, spellschool, extraspellid, extraspellname, extraschool, auratype=...
      end

      if CCSpells[spellid] then
        srcGUID,srcName=Skada:FixMyPets(srcGUID, srcName)
        dstGUID,dstName=Skada:FixMyPets(dstGUID, dstName)

        data.srcGUID=srcGUID
        data.srcName=srcName
        data.dstGUID=dstGUID
        data.dstName=dstName
        data.spellid=spellid
        data.spellname=spellname
        data.extraspellid=extraspellid
        data.extraspellname=extraspellname

        log_cctaken(Skada.current, data)
        log_cctaken(Skada.total, data)
      end
    end

    function spellsmod:Enter(win, id, label)
      self.playerid=id
      local player=Skada:find_player(win:get_selected_set(), id)
      if player then
        self.title=player.name..L["'s "]..L["CC Taken Spells"]
      end
    end

    function spellsmod:Update(win, set)
      local player=Skada:find_player(set, self.playerid)
      local max=0

      if player then
        local nr=1

        for spellname, spell in pairs(player.cctaken.spells) do
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

    function spellsourcesmod:Enter(win, id, label)
      self.spellname=label
      local player=Skada:find_player(win:get_selected_set(), spellsmod.playerid)
      if player then
        self.title=format(L["%s's CC Taken <%s> sources"], player.name, label)
      end
    end

    function spellsourcesmod:Update(win, set)
      local player=Skada:find_player(set,spellsmod.playerid)
      local max=0

      if player and self.spellname then
        local nr=1

        for sourcename, source in pairs(player.cctaken.spells[self.spellname].sources) do
          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=source.id
          d.label=sourcename
          d.value=source.count
          d.valuetext=tostring(source.count)

          if source.count>max then
            max=source.count
          end

          nr=nr+1
        end
      end

      win.metadata.maxvalue=max
    end

    function sourcesmod:Enter(win, id, label)
      self.playerid=id
      local player=Skada:find_player(win:get_selected_set(), id)
      if player then
        self.title=player.name..L["'s "]..L["CC Taken Sources"]
      end
    end

    function sourcesmod:Update(win, set)
      local player=Skada:find_player(set, self.playerid)
      local max=0

      if player then
        local nr=1

        for targetname, target in pairs(player.cctaken.sources) do
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

    function sourcespellsmod:Enter(win, id, label)
      self.targetname=label
      local player=Skada:find_player(win:get_selected_set(), spellsmod.playerid)
      if player then
        self.title=format(L["%s's CC Taken <%s> sources"], player.name, label)
      end
    end

    function sourcespellsmod:Update(win, set)
      local player=Skada:find_player(set,spellsmod.playerid)
      local max=0

      if player and self.targetname then
        local nr=1

        for spellname, spell in pairs(player.cctaken.sources[self.targetname].spells) do
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
      local max, nr=0, 1
      for i, player in ipairs(set.players) do
        if player.cctaken.count>0 then
          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=player.id
          d.label=player.name
          d.class=player.class
          d.icon=d.class and Skada.classIcon or Skada.petIcon
          d.value=player.cctaken.count
          d.valuetext=tostring(player.cctaken.count)

          if player.cctaken.count>max then
            max=player.cctaken.count
          end

          nr=nr+1
        end
      end

      win.metadata.maxvalue=max
    end

    function mod:OnEnable()
      spellsourcesmod.metadata={}
      spellsmod.metadata={click1=spellsourcesmod}

      sourcespellsmod.metadata={}
      sourcesmod.metadata={click1=sourcespellsmod}

      mod.metadata={click1=spellsmod, click2=sourcesmod, showspots=true}

      Skada:RegisterForCL(SpellAuraApplied, 'SPELL_AURA_APPLIED', {dst_is_interesting=true})
      Skada:RegisterForCL(SpellAuraApplied, 'SPELL_AURA_REFRESH', {dst_is_interesting=true})
      Skada:AddMode(self)
    end

    function mod:OnDisable()
      Skada:RemoveMode(self)
    end

    function mod:GetSetSummary(set)
      return set.cctaken
    end

    function mod:AddPlayerAttributes(player)
      if not player.cctaken then
        player.cctaken={count=0, spells={}, sources={}}
      end
    end

    function mod:AddSetAttributes(set)
      set.cctaken=set.cctaken or 0
    end

    function mod:SetComplete(set)
      for i, player in ipairs(set.players) do
        if player.cctaken.count==0 then
          player.cctaken.spells=nil
          player.cctaken.sources=nil
        end
      end
    end
  end)
end

-- =========== --
-- CC Breakers --
-- =========== --
do
  local modname="CC Breakers"
  Skada:AddLoadableModule(modname, nil, function(Skada, L)
    if Skada.db.profile.modulesBlocked[modname] then return end
    
    local mod=Skada:NewModule(L[modname])
    local spellsmod=mod:NewModule(L["CC Break Spells"])
    local spelltargetsmod=mod:NewModule(L["CC Break Spell Targets"])
    local targetsmod=mod:NewModule(L["CC Break Targets"])
    local targetspellsmod=mod:NewModule(L["CC Break Target Spells"])

    local GetNumRaidMembers, GetRaidRosterInfo=GetNumRaidMembers, GetRaidRosterInfo
    local IsInInstance, UnitInRaid=IsInInstance, UnitInRaid
    local SendChatMessage
    
    local function log_ccbreak(set,data)
      local player=Skada:get_player(set, data.srcGUID, data.srcName)
      if not player then return end
      
      player.ccbreaks.count=player.ccbreaks.count+1

      if not player.ccbreaks.spells[data.spellname] then
        player.ccbreaks.spells[data.spellname]={id=data.spellid, count=0, targets={}}
      end
      player.ccbreaks.spells[data.spellname].count=player.ccbreaks.spells[data.spellname].count+1

      if not player.ccbreaks.spells[data.spellname].targets[data.dstName] then
        player.ccbreaks.spells[data.spellname].targets[data.dstName]={id=data.dstGUID, count=0}
      end
      player.ccbreaks.spells[data.spellname].targets[data.dstName].count=player.ccbreaks.spells[data.spellname].targets[data.dstName].count+1

      if not player.ccbreaks.targets[data.dstName] then
        player.ccbreaks.targets[data.dstName]={id=data.dstGUID, count=0, spells={}}
      end
      player.ccbreaks.targets[data.dstName].count=player.ccbreaks.targets[data.dstName].count+1

      if not player.ccbreaks.targets[data.dstName].spells[data.spellname] then
        player.ccbreaks.targets[data.dstName].spells[data.spellname]={id=data.spellid, count=0}
      end
      player.ccbreaks.targets[data.dstName].spells[data.spellname].count=player.ccbreaks.targets[data.dstName].spells[data.spellname].count+1

      set.ccbreaks=set.ccbreaks+1
    end

    local data={}
    local function SpellAuraBroken(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
      local spellid, spellname, spellschool, auratype, extraspellid, extraspellname, extraschool

      if eventtype == "SPELL_AURA_BROKEN" then
        spellid, spellname, spellschool, auratype=...
      else
        spellid, spellname, spellschool, extraspellid, extraspellname, extraschool, auratype=...
      end

      if not CCSpells[spellid] then return end

      local petid=srcGUID
      local petname=srcName
      srcGUID, srcName=Skada:FixMyPets(srcGUID, srcName)

      data.srcGUID=srcGUID
      data.srcName=srcName
      data.dstGUID=dstGUID
      data.dstName=dstName
      data.spellid=spellid
      data.spellname=spellname
      data.extraspellid=extraspellid
      data.extraspellname=extraspellname

      log_ccbreak(Skada.current, data)
      log_ccbreak(Skada.total, data)

      -- Optional announce
      local inInstance, instanceType=IsInInstance()
      if Skada.db.profile.modules.ccannounce and GetNumRaidMembers()>0 and UnitInRaid(srcName) and not (instanceType == "pvp") then

        -- Ignore main tanks?
        if Skada.db.profile.modules.ccignoremaintanks then

          -- Loop through our raid and return if src is a main tank.
          for i=1, MAX_RAID_MEMBERS do
            local name, _, _, _, _, class, _, _, _, role, _=GetRaidRosterInfo(i)
            if name == srcName and role == "maintank" then
              return
            end
          end
        end

        -- Prettify pets.
        if petid ~= srcGUID then
          srcName=petname.." ("..srcName..")"
        end

        -- Go ahead and announce it.
        if extraspellname then
          SendChatMessage(format(L["%s on %s removed by %s's %s"], spellname, dstName, srcName, select(1,GetSpellLink(extraspellid))), "RAID")
        else
          SendChatMessage(format(L["%s on %s removed by %s"], spellname, dstName, srcName), "RAID")
        end
      end
    end

    function spellsmod:Enter(win, id, label)
      local player=Skada:find_player(win:get_selected_set(), id)
      if player then
        self.playerid=id
        self.title=player.name..L["'s "]..L["CC Break Spells"]
      end
    end

    function spellsmod:Update(win, set)
      local player=Skada:find_player(set, self.playerid)
      local max=0

      if player then
        local nr=1

        for spellname, spell in pairs(player.ccbreaks.spells) do
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

    function spelltargetsmod:Enter(win, id, label)
      self.spellname=label
      local player=Skada:find_player(win:get_selected_set(), spellsmod.playerid)
      if player then
        self.title=format(L["%s's CC Break <%s> targets"], player.name, label)
      end
    end

    function spelltargetsmod:Update(win, set)
      local player=Skada:find_player(set,spellsmod.playerid)
      local max=0

      if player and self.spellname then
        local nr=1

        for targetname, target in pairs(player.ccbreaks.spells[self.spellname].targets) do
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

    function targetsmod:Enter(win, id, label)
      self.playerid=id
      local player=Skada:find_player(win:get_selected_set(), id)
      if player then
        self.title=player.name..L["'s "]..L["CC Break Targets"]
      end
    end

    function targetsmod:Update(win, set)
      local player=Skada:find_player(set, self.playerid)
      local max=0

      if player then
        local nr=1

        for targetname, target in pairs(player.ccbreaks.targets) do
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

    function targetspellsmod:Enter(win, id, label)
      self.targetname=label
      local player=Skada:find_player(win:get_selected_set(), spellsmod.playerid)
      if player then
        self.title=format(L["%s's CC Break <%s> spells"], player.name, label)
      end
    end

    function targetspellsmod:Update(win, set)
      local player=Skada:find_player(set,spellsmod.playerid)
      local max=0

      if player and self.targetname then
        local nr=1

        for spellname, spell in pairs(player.ccbreaks.targets[self.targetname].spells) do
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
        if player.ccbreaks.count>0 then
          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=player.id
          d.label=player.name
          d.class=player.class
          d.icon=d.class and Skada.classIcon or Skada.petIcon
          d.value=player.ccbreaks.count
          d.valuetext=tostring(player.ccbreaks.count)

          if player.ccbreaks.count>max then
            max=player.ccbreaks.count
          end

          nr=nr+1
        end
      end

      win.metadata.maxvalue=max
    end

    function mod:OnEnable()
      spelltargetsmod.metadata={}
      spellsmod.metadata={click1=spelltargetsmod}

      targetspellsmod.metadata={}
      targetsmod.metadata={click1=targetspellsmod}

      mod.metadata={showspots=true, click1=spellsmod, click2=targetsmod}

      Skada:RegisterForCL(SpellAuraBroken, 'SPELL_AURA_BROKEN', {src_is_interesting = true})
      Skada:RegisterForCL(SpellAuraBroken, 'SPELL_AURA_BROKEN_SPELL', {src_is_interesting = true})

      Skada:AddMode(self)
    end

    function mod:OnDisable()
      Skada:RemoveMode(self)
    end

    function mod:AddToTooltip(set, tooltip)
      GameTooltip:AddDoubleLine(L["CC Breaks"], set.ccbreaks, 1,1,1)
    end

    function mod:GetSetSummary(set)
      return set.ccbreaks
    end

    -- Called by Skada when a new player is added to a set.
    function mod:AddPlayerAttributes(player)
      if not player.ccbreaks then
        player.ccbreaks={count=0, spells={}, targets={}}
      end
    end

    -- Called by Skada when a new set is created.
    function mod:AddSetAttributes(set)
      if not set.ccbreaks then
        set.ccbreaks=0
      end
    end

    function mod:SetComplete(set)
      for i, player in ipairs(set.players) do
        if player.ccbreaks.count==0 then
          player.ccbreaks.spells=nil
          player.ccbreaks.targets=nil
        end
      end
    end

    local opts={
      ccoptions={
        type="group",
        name=L["CC"],
        args={

          announce={
            type="toggle",
            name=L["Announce CC breaking to party"],
            get=function() return Skada.db.profile.modules.ccannounce end,
            set=function() Skada.db.profile.modules.ccannounce=not Skada.db.profile.modules.ccannounce end,
            order=1,
          },

          ignoremaintanks={
            type="toggle",
            name=L["Ignore Main Tanks"],
            get=function() return Skada.db.profile.modules.ccignoremaintanks end,
            set=function() Skada.db.profile.modules.ccignoremaintanks=not Skada.db.profile.modules.ccignoremaintanks end,
            order=2,
          },

        },
      }
    }

    function mod:OnInitialize()
      -- Add our options.
      table.insert(Skada.options.plugins, opts)
    end
  end)
end
