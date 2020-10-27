local _, Skada=...
if not Skada then return end

local L=LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local tostring, tonumber=tostring, tonumber
local pairs, ipairs, select=pairs, ipairs, select
local format=string.format
local GetSpellInfo=GetSpellInfo

local modname="Power gained"
local mana="Power gained: Mana"
local rage="Power gained: Rage"
local energy="Power gained: Energy"
local runicpower="Power gained: Runic Power"

local mod=Skada:NewModule(L[modname])
local power="mana"

local playermod=mod:NewModule(L["Power gain spell list"])

local locales={
  mana=MANA,
  energy=ENERGY,
  rage=RAGE,
  runicpower=RUNIC_POWER
}

-- returns the proper power type
local function fix_power_type(t)
  local p
  
  if t==0 then
    p="mana"
  elseif t==1 then
    p="rage"
  elseif t==3 then
    p="energy"
  elseif t==6 then
    p="runicpower"
  end

  return p
end

local function log_gain(set, gain)
  -- Get the player from set.
  local player=Skada:get_player(set, gain.playerid, gain.playername)
  if not player then return end

  local p=fix_power_type(gain.type)
  if not p then return end

  player.power=player.power or {}

  -- Make sure power type exists.
  if not player.power[p] then
    player.power[p]={spells={}, amount=0}
  end

  -- Add to player total.
  player.power[p].amount=player.power[p].amount+gain.amount

  if not player.power[p].spells[gain.spellname] then
    player.power[p].spells[gain.spellname]={id=gain.spellid, amount=0}
  end
  player.power[p].spells[gain.spellname].amount=player.power[p].spells[gain.spellname].amount+gain.amount

  set.power=set.power or {}
  -- Make sure set power type exists.
  if not set.power[p] then
    set.power[p]=0
  end

  -- Also add to set total gain.
  set.power[p]=set.power[p]+gain.amount
end

local gain={}

local function SpellEnergize(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
  -- Healing
  local spellid, spellname, spellschool, samount, powerType=...

  gain.srcGUID=srcGUID
  gain.srcName=srcName
  gain.spellid=spellid
  gain.spellname=spellname
  gain.amount=samount
  gain.type=tonumber(powerType)

  Skada:FixPets(gain)
  log_gain(Skada.current, gain)
  log_gain(Skada.total, gain)
end

function playermod:Enter(win, id, label)
  local player=Skada:find_player(win:get_selected_set(), id)
  if player then
    self.playerid=player.id
    self.title=label..L["'s "]..format(L["gained %s"], locales[power])
  end
end

-- Detail view of a player.
function playermod:Update(win, set)
  local player=Skada:find_player(set, self.playerid)
  local max=0

  if player and player.power[power]then
    local nr=1

    for spellname, spell in pairs(player.power[power].spells) do
      local d=win.dataset[nr] or {}
      win.dataset[nr]=d

      d.id=spell.id
      d.label=spellname
      d.icon=select(3, GetSpellInfo(spell.id))
      d.value=spell.amount
      if power=="mana" then
        d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(spell.amount), self.metadata.columns.Power,
          format("%02.1f%%", spell.amount/player.power[power].amount*100), self.metadata.columns.Percent
        )
      else
        d.valuetext=tostring(spell.amount)
      end

      if spell.amount>max then
        max=spell.amount
      end

      nr=nr+1
    end
  end

  win.metadata.maxvalue=max
end

function mod:OnEnable()
  playermod.metadata ={showspots=true, columns={Power=true, Percent=true}}  
  mod.metadata={}

  Skada:RegisterForCL(SpellEnergize, 'SPELL_ENERGIZE', {src_is_interesting=true})
  Skada:RegisterForCL(SpellEnergize, 'SPELL_PERIODIC_ENERGIZE', {src_is_interesting=true})
end

function mod:GetSetSummary(set)
  return Skada:FormatNumber(set.power[power] or 0)
end

-- Called by Skada when a new player is added to a set.
function mod:AddPlayerAttributes(player)
  if not player.power then
    player.power={}
  end
end

-- Called by Skada when a new set is created.
function mod:AddSetAttributes(set)
  if not set.power then
    set.power={}
  end
end

-- ================== --
-- Power gained: Mana --
-- ================== --

do
  Skada:AddLoadableModule(mana, nil, function(Skada, L)
    if Skada.db.profile.modulesBlocked[modname] then return end
    if Skada.db.profile.modulesBlocked[mana] then return end
    local manamod=mod:NewModule(L[mana])

    function manamod:Update(win, set)
      local nr, max=1, 0
      power="mana"

      for i, player in pairs(set.players) do
        if player.power and player.power[power] then
          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          local amount=player.power[power].amount

          d.id=player.id
          d.label=player.name
          d.class=player.class
          d.icon=player.class and Skada.classIcon or Skada.petIcon
          d.power=power
          d.value=amount
          d.valuetext=Skada:FormatValueText(
            Skada:FormatNumber(amount), self.metadata.columns.Power,
            format("%02.1f%%", amount/set.power[power]*100), self.metadata.columns.Percent
          )

          if d.value>max then
            max=d.value
          end

          nr=nr+1
        end
      end

      win.metadata.maxvalue=max
    end

    function manamod:OnEnable()
      manamod.metadata={showspots=true, click1=playermod, columns={Power=true, Percent=true}}
      Skada:AddMode(self)
    end

    function manamod:OnDisable()
      Skada:RemoveMode(self)
    end

    function manamod:GetSetSummary(set)
      return Skada:FormatNumber(set.power.mana or 0)
    end
  end)
end

-- ================== --
-- Power gained: Rage --
-- ================== --

do
  Skada:AddLoadableModule(rage, nil, function(Skada, L)
    if Skada.db.profile.modulesBlocked[modname] then return end
    if Skada.db.profile.modulesBlocked[rage] then return end

    local ragemod=mod:NewModule(L[rage])

    function ragemod:Update(win, set)
      local nr, max=1, 0
      power="rage"

      for i, player in pairs(set.players) do
        if player.power and player.power[power] then
          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=player.id
          d.label=player.name
          d.class=player.class
          d.icon=player.class and Skada.classIcon or Skada.petIcon
          d.power=power
          d.value=player.power[power].amount
          d.valuetext=tostring(d.value)

          if d.value>max then
            max=d.value
          end

          nr=nr+1
        end
      end

      win.metadata.maxvalue=max
    end

    function ragemod:OnEnable()
      ragemod.metadata={showspots=true, click1=playermod, columns={Power=true, Percent=true}}
      Skada:AddMode(self)
    end

    function ragemod:OnDisable()
      Skada:RemoveMode(self)
    end

    function ragemod:GetSetSummary(set)
      return Skada:FormatNumber(set.power.rage or 0)
    end
  end)
end

-- ==================== --
-- Power gained: Energy --
-- ==================== --

do
  Skada:AddLoadableModule(energy, nil, function(Skada, L)
    if Skada.db.profile.modulesBlocked[modname] then return end
    if Skada.db.profile.modulesBlocked[energy] then return end
    local energymod=mod:NewModule(L[energy])

    function energymod:Update(win, set)
      local nr, max=1, 0
      power="energy"

      for i, player in pairs(set.players) do
        if player.power and player.power[power] then
          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=player.id
          d.label=player.name
          d.class=player.class
          d.icon=player.class and Skada.classIcon or Skada.petIcon
          d.power=power
          d.value=player.power[power].amount
          d.valuetext=tostring(d.value)

          if d.value>max then
            max=d.value
          end

          nr=nr+1
        end
      end

      win.metadata.maxvalue=max
    end

    function energymod:OnEnable()
      energymod.metadata={showspots=true, click1=playermod, columns={Power=true, Percent=true}}
      Skada:AddMode(self)
    end

    function energymod:OnDisable()
      Skada:RemoveMode(self)
    end

    function energymod:GetSetSummary(set)
      return Skada:FormatNumber(set.power.energy or 0)
    end
  end)
end

-- ========================= --
-- Power gained: Runic Power --
-- ========================= --

do
  Skada:AddLoadableModule(runicpower, nil, function(Skada, L)
    if Skada.db.profile.modulesBlocked[modname] then return end
    if Skada.db.profile.modulesBlocked[runicpower] then return end
    
    local runicmod=mod:NewModule(L[runicpower])

    function runicmod:Update(win, set)
      local nr, max=1, 0
      power="runicpower"

      for i, player in pairs(set.players) do
        if player.power and player.power[power] then
          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=player.id
          d.label=player.name
          d.class=player.class
          d.icon=player.class and Skada.classIcon or Skada.petIcon
          d.power=power
          d.value=player.power[power].amount
          d.valuetext=tostring(d.value)

          if d.value>max then
            max=d.value
          end

          nr=nr+1
        end
      end

      win.metadata.maxvalue=max
    end

    function runicmod:OnEnable()
      runicmod.metadata={showspots=true, click1=playermod, columns={Power=true, Percent=true}}
      Skada:AddMode(self)
    end

    function runicmod:OnDisable()
      Skada:RemoveMode(self)
    end

    function runicmod:GetSetSummary(set)
      return Skada:FormatNumber(set.power.runicpower or 0)
    end
  end)
end
