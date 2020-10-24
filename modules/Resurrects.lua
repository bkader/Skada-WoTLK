local Skada=Skada
if not Skada then return end

local L=LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local mod=Skada:NewModule(L["Resurrects"])
local spellsmod=mod:NewModule(L["Resurrect spell list"])
local spelltargetsmod=mod:NewModule(L["Resurrect spell target list"])
local targetsmod=mod:NewModule(L["Resurrect target list"])
local targetspellsmod=mod:NewModule(L["Resurrect target spell list"])

local select, pairs, ipairs=select, pairs, ipairs
local tostring, tonumber=tostring, tonumber
local format=string.format
local GetSpellInfo=GetSpellInfo
local UnitClass=UnitClass

local function log_resurrect(set, data, ts)
  local player=Skada:get_player(set, data.srcGUID, data.srcName)
  if player then
    player.resurrect.count=player.resurrect.count+1

    if not player.resurrect.spells[data.spellname] then
      player.resurrect.spells[data.spellname]={id=data.spellid, count=0, targets={}}
    end
    player.resurrect.spells[data.spellname].count=player.resurrect.spells[data.spellname].count+1

    if not player.resurrect.spells[data.spellname].targets[data.dstName] then
      player.resurrect.spells[data.spellname].targets[data.dstName]={id=data.dstGUID, count=0}
    end
    player.resurrect.spells[data.spellname].targets[data.dstName].count=player.resurrect.spells[data.spellname].targets[data.dstName].count+1

    if not player.resurrect.targets[data.dstName] then
      player.resurrect.targets[data.dstName]={id=data.dstGUID, count=0, spells={}}
    end
    player.resurrect.targets[data.dstName].count=player.resurrect.targets[data.dstName].count+1

    if not player.resurrect.targets[data.dstName].spells[data.spellname] then
      player.resurrect.targets[data.dstName].spells[data.spellname]={id=data.spellid, count=0}
    end
    player.resurrect.targets[data.dstName].spells[data.spellname].count=player.resurrect.targets[data.dstName].spells[data.spellname].count+1

    set.resurrect=set.resurrect+1
  end
end

local data={}
local function SpellResurrect(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellid, spellname, spellschool)
  data.srcGUID=srcGUID
  data.srcName=srcName
  data.dstGUID=dstGUID
  data.dstName=dstName
  data.spellid=spellid
  data.spellname=spellname
  data.spellschool=spellschool

  log_resurrect(Skada.current, data, ts)
  log_resurrect(Skada.total, data, ts)
end

function spellsmod:Enter(win, id, label)
 local player=Skada:find_player(win:get_selected_set(), id)
 if player then
  self.playerid=id
  self.title=format(L["%s's resurrect spells"], label)
 end
end

function spellsmod:Update(win, set)
  local player=Skada:find_player(set, self.playerid)
  local max, nr=0, 1
  if player then
    for spellname, spell in pairs(player.resurrect.spells) do
      local d=win.dataset[nr] or {}
      win.dataset[nr]=d
      d.label=spellname
      d.id=spellname
      d.icon=select(3, GetSpellInfo(spell.id))
      d.spellid=spell.id
      d.value=spell.count
      d.valuetext=spell.count
      if spell.count > max then
        max=spell.count
      end
      nr=nr+1
    end
  end
  win.metadata.maxvalue=max
end


function spelltargetsmod:Enter(win, id, label)
  local player=Skada:find_player(win:get_selected_set(), spellsmod.playerid)
  if player then
    self.spellname=label
    self.title=format(L["%s's resurrect <%s> targets"], player.name, label)
  end
end

function spelltargetsmod:Update(win, set)
  local player=Skada:find_player(set, spellsmod.playerid)
  local max, nr=0, 1
  if player then
    local spell=self.spellname
    if spell then
      local targets=player.resurrect.spells[spell].targets
      for targetName, target in pairs(targets) do

        local d=win.dataset[nr] or {}
        win.dataset[nr]=d
        
        d.id=target.id
        d.label=targetName
        d.value=tonumber(target.count)
        d.valuetext=tostring(target.count)
        d.class=select(2, UnitClass(targetName))
        d.icon=d.class and Skada.classIcon or Skada.petIcon
        
        if tonumber(target.count) > max then
          max=tonumber(target.count)
        end
        nr=nr+1
      end
    end
  end
  win.metadata.maxvalue=max
end

function targetsmod:Enter(win, id, label)
  self.playerid=id
  self.title=format(L["%s's resurrect targets"], label)
end

function targetsmod:Update(win, set)
  local player=Skada:find_player(set, self.playerid)
  local max, nr=0, 1
  if player then
    for targetName, target in pairs(player.resurrect.targets) do
      local d=win.dataset[nr] or {}
      win.dataset[nr]=d
      
      d.id=target.id
      d.label=targetName
      d.value=tonumber(target.count)
      d.valuetext=tostring(target.count)
      d.class=select(2, UnitClass(targetName))
      d.icon=d.class and Skada.classIcon or Skada.petIcon
      
      if tonumber(target.count) > max then
        max=tonumber(target.count)
      end
      nr=nr+1
    end
  end
  win.metadata.maxvalue=max
end

function targetspellsmod:Enter(win, id, label)
  self.targetName=label
  self.title=format(L["%s's received resurrects"], label)
end

function targetspellsmod:Update(win, set)
  local player=Skada:find_player(set, targetsmod.playerid)
  local max, nr=0, 1
  if player then
    local target=self.targetName
    if target then
      local spells=player.resurrect.targets[target].spells
      for spellname, spell in pairs(spells) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d
        d.label=spellname
        d.id=spellname
        d.icon=select(3, GetSpellInfo(spell.id))
        d.spellid=spell.id
        d.value=spell.count
        d.valuetext=spell.count
        if spell.count > max then
          max=spell.count
        end
        nr=nr+1
      end
    end
  end
  win.metadata.maxvalue=max
end


function mod:OnEnable()
  self.metadata={click1=spellsmod, click2=targetsmod}
  spellsmod.metadata={click1=spelltargetsmod}
  spelltargetsmod.metadata={}
  targetsmod.metadata={click1=targetspellsmod}
  targetspellsmod.metadata={}

  Skada:RegisterForCL(SpellResurrect, "SPELL_RESURRECT", {src_is_interesting=true, dst_is_interesting=true})
  Skada:AddMode(self)
  Skada:EnableModule(self:GetName())
end

function mod:OnDisable()
  Skada:RemoveMode(self)
  Skada:DisableModule(self:GetName())
end

function mod:GetSetSummary(set)
  return set.resurrect
end

function mod:AddPlayerAttributes(player)
  if not player.resurrect then
    player.resurrect={count=0, spells={}, targets={}}
  end
end

function mod:AddSetAttributes(set)
  set.resurrect=set.resurrect or 0
end

function mod:Update(win, set)
  local max, nr=0, 1
  for i, player in ipairs(set.players) do
    if player.resurrect.count > 0 then
      local d=win.dataset[nr] or {}
      win.dataset[nr]=d
      d.value=player.resurrect.count
      d.label=player.name
      d.valuetext=tostring(player.resurrect.count)
      d.id=player.id
      d.class=player.class
      d.icon=d.class and Skada.classIcon or Skada.petIcon
      if player.resurrect.count > max then
        max=player.resurrect.count
      end
      nr=nr+1
    end
  end
  win.metadata.maxvalue=max
end

-- :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
