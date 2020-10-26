local _, Skada=...
if not Skada then return end

local L=LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local UnitGUID, UnitClass=UnitGUID, UnitClass
local GetSpellInfo=GetSpellInfo
local format, math_max=string.format, math.max
local pairs, ipairs, select=pairs, ipairs, select

-- generic spell damage
local function _SpellDamage(cond, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
  if cond==true then
    local spellid, spellname, spellschool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing=...

    local dmg={}

    dmg.srcGUID=srcGUID
    dmg.srcName=srcName
    dmg.srcFlags=srcFlags

    dmg.dstGUID=dstGUID
    dmg.dstName=dstName
    dmg.dstFlags=dstFlags

    dmg.spellid=spellid
    dmg.spellname=spellname
    dmg.spellschool=spellschool

    dmg.amount=amount
    dmg.overkill=overkill
    dmg.resisted=resisted
    dmg.blocked=blocked
    dmg.absorbed=absorbed
    dmg.critical=critical
    dmg.glancing=glancing
    dmg.crushing=crushing
    dmg.missed=nil

    return dmg
  end

  return nil
end

local function _SpellMissed(cond, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
  if cond==true then
    local spellid, spellname, spellschool, misstype, amount=...

    local dmg={}

    dmg.srcGUID=srcGUID
    dmg.srcName=srcName
    dmg.srcFlags=srcFlags

    dmg.dstGUID=dstGUID
    dmg.dstName=dstName
    dmg.dstFlags=dstFlags

    dmg.spellid=spellid
    dmg.spellname=spellname
    dmg.spellschool=spellschool

    dmg.amount=0
    dmg.overkill=0
    dmg.missed=misstype

    return dmg
  end
end

-- generic swing (melee) damage
local function _SwingDamage(cond, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
  if cond==true then
    local amount, overkill, spellschool, resisted, blocked, absorbed, critical, glancing, crushing=...

    local dmg={}

    dmg.srcGUID=srcGUID
    dmg.srcName=srcName
    dmg.srcFlags=srcFlags

    dmg.dstGUID=dstGUID
    dmg.dstName=dstName
    dmg.dstFlags=dstFlags

    dmg.spellid=6603
    dmg.spellname=ACTION_SWING

    dmg.amount=amount
    dmg.overkill=overkill
    dmg.resisted=resisted
    dmg.blocked=blocked
    dmg.absorbed=absorbed
    dmg.critical=critical
    dmg.glancing=glancing
    dmg.crushing=crushing
    dmg.missed=nil

    return dmg
  end
end

-- generic swing missed
local function _SwingMissed(cond, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
  if cond==true then
    local dmg={}

    dmg.srcGUID=srcGUID
    dmg.srcName=srcName
    dmg.srcFlags=srcFlags
    
    dmg.dstGUID=dstGUID
    dmg.dstName=dstName
    dmg.dstFlags=dstFlags

    dmg.spellid=6603
    dmg.spellname=ACTION_SWING

    dmg.amount=0
    dmg.overkill=0
    dmg.missed=select(1, ...)

    return dmg
  end
end

-- ================== --
-- Damage Done Module --
-- ================== --

do
  local mod=Skada:NewModule(L["Damage"])
  local playermod=mod:NewModule(L["Damage spell list"])
  local spellmod=mod:NewModule(L["Damage spell details"])
  local targetmod=mod:NewModule(L["Damage spell targets"])

  local dpsmod=Skada:NewModule(L["DPS"])

  local spellsmod=Skada:NewModule(L["Damage done by spell"])
  local spellsourcesmod=spellsmod:NewModule(L["Damage spell targets"])

  local function log_damage(set, dmg)
    local player=Skada:find_player(set, dmg.playerid, dmg.playername)
    if not player then return end

    set.damagedone=set.damagedone+dmg.amount
    player.damagedone.amount=player.damagedone.amount+dmg.amount

    if not player.damagedone.spells[dmg.spellname] then
      player.damagedone.spells[dmg.spellname]={id=dmg.spellid, hit=0, totalhits=0, amount=0, critical=0, glancing=0, crushing=0, ABSORB=0, BLOCK=0, DEFLECT=0, DODGE=0, EVADE=0, IMMUNE=0, PARRY=0, REFLECT=0, RESIST=0, MISS=0}
    end

    local spell=player.damagedone.spells[dmg.spellname]
    spell.totalhits=spell.totalhits+1
    spell.amount=spell.amount+dmg.amount

    if spell.max==nil or dmg.amount>spell.max then
      spell.max=dmg.amount
    end

    if (spell.min==nil or dmg.amount<spell.min) and not dmg.missed then
      spell.min=dmg.amount
    end

    if dmg.critical then
      spell.critical=spell.critical+1

    elseif dmg.missed ~= nil then
      if spell[dmg.missed] ~= nil then
        spell[dmg.missed]=spell[dmg.missed]+1
      end

    elseif dmg.glancing then
      spell.glancing=spell.glancing+1

    elseif dmg.crushing then
      spell.crushing=spell.crushing+1

    else
      spell.hit=spell.hit+1
    end

    if set==Skada.current and dmg.dstName then
      if not player.damagedone.targets[dmg.dstName] then
        player.damagedone.targets[dmg.dstName]={id=dmg.dstGUID, amount=0}
      end
      player.damagedone.targets[dmg.dstName].amount=player.damagedone.targets[dmg.dstName].amount+dmg.amount
    end
  end

  local function getDPS(set, player)
    local uptime=Skada:PlayerActiveTime(set, player)
    return player.damagedone.amount/math_max(1, uptime)
  end

  local function getRaidDPS(set)
    if set.time>0 then
      return set.damagedone/math_max(1, set.time)
    else
      local endtime=set.endtime
      if not endtime then
        endtime=time()
      end
      return set.damagedone/math_max(1, endtime-set.starttime)
    end
  end

  local dmg={}

  local function SpellDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    dmg=_SpellDamage((srcGUID ~= dstGUID), srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if dmg then
      Skada:FixPets(dmg)
      log_damage(Skada.current, dmg)
      log_damage(Skada.total, dmg)
    end
  end

  local function SpellMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    dmg=_SpellMissed((srcGUID ~= dstGUID), srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if dmg then
      Skada:FixPets(dmg)
      log_damage(Skada.current, dmg)
      log_damage(Skada.total, dmg)
    end
  end

  local function SwingDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    dmg=_SwingDamage((srcGUID ~= dstGUID), srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if dmg then
      Skada:FixPets(dmg)
      log_damage(Skada.current, dmg)
      log_damage(Skada.total, dmg)
    end
  end

  local function SwingMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    dmg=_SwingMissed((srcGUID ~= dstGUID), srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if dmg then
      Skada:FixPets(dmg)
      log_damage(Skada.current, dmg)
      log_damage(Skada.total, dmg)
    end
  end

  local function dps_tooltip(win, id, label, tooltip)
    local set=win:get_selected_set()
    local player=Skada:find_player(set, id)
    if player then

      local activetime=Skada:PlayerActiveTime(set, player)
      local totaltime=Skada:GetSetTime(set)
      tooltip:AddLine(player.name.." - "..L["DPS"])
      tooltip:AddDoubleLine(L["Segment Time"], SecondsToTime(totaltime), 255,255,255,255,255,255)
      tooltip:AddDoubleLine(L["Active Time"], SecondsToTime(activetime), 255,255,255,255,255,255)
      tooltip:AddDoubleLine(L["Damage Done"], Skada:FormatNumber(player.damagedone.amount), 255,255,255,255,255,255)
      tooltip:AddDoubleLine(Skada:FormatNumber(player.damagedone.amount) .. "/" .. activetime .. ":", format("%02.1f", player.damagedone.amount/math_max(1,activetime)), 255,255,255,255,255,255)

    end
  end

  local function player_tooltip(win, id, label, tooltip)
    local player=Skada:find_player(win:get_selected_set(), playermod.playerid)
    if not player then return end

    local spell=player.damagedone.spells[label]
    if spell then
      tooltip:AddLine(player.name.." - "..label)
      if spell.min then
        tooltip:AddDoubleLine(L["Minimum hit:"], Skada:FormatNumber(spell.min), 255,255,255,255,255,255)
      end
      if spell.max then
        tooltip:AddDoubleLine(L["Maximum hit:"], Skada:FormatNumber(spell.max), 255,255,255,255,255,255)
      end
      tooltip:AddDoubleLine(L["Average hit:"], Skada:FormatNumber(spell.amount/spell.totalhits), 255,255,255,255,255,255)
      tooltip:AddDoubleLine(L["Total hits:"], tostring(spell.totalhits), 255,255,255,255,255,255)
    end
  end

  function playermod:Enter(win, id, label)
    local player=Skada:find_player(win:get_selected_set(), id)
    if player then
      self.playerid=id
      self.title=format(L["%s's Damage"], player.name)
    end
  end

  function playermod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0

    if player then
      local nr=1

      for spellname, spell in pairs(player.damagedone.spells) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=spellname
        d.label=spellname
        d.icon=select(3, GetSpellInfo(spell.id))

        d.value=spell.amount
        d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(spell.amount), self.metadata.columns.Damage,
          format("%02.1f%%", spell.amount/player.damagedone.amount*100), self.metadata.columns.Percent
        )

        if spell.amount>max then
          max=spell.amount
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function targetmod:Enter(win, id, label)
    local player=Skada:find_player(win:get_selected_set(), id)
    self.playerid=id
    self.title=format(L["%s's Targets"], player.name)
  end

  function targetmod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0

    if player then
      local nr=1

      for mobname, mob in pairs(player.damagedone.targets) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=mobname
        d.label=mobname

        d.value=mob.amount
        d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(mob.amount), self.metadata.columns.Damage,
          format("%02.1f%%", mob.amount/player.damagedone.amount*100), self.metadata.columns.Percent
          )

        if mob.amount>max then
          max=mob.amount
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  local function add_detail_bar(win, nr, title, value)
    local d=win.dataset[nr] or {}
    win.dataset[nr]=d

    d.id=title
    d.label=title
    d.value=value
    d.valuetext=Skada:FormatValueText(
      value, mod.metadata.columns.Damage,
      format("%02.1f%%", value/win.metadata.maxvalue*100), mod.metadata.columns.Percent
    )
  end

  function spellmod:Enter(win, id, label)
    local player=Skada:find_player(win:get_selected_set(), playermod.playerid)
    self.spellname=id
    self.title=player.name..L["'s "]..label
  end

  function spellmod:Update(win, set)
    local player=Skada:find_player(set, playermod.playerid)

    if player then
      local spell=player.damagedone.spells[self.spellname]

      if spell then
        win.metadata.maxvalue=spell.totalhits
        local nr=1

        if spell.hit>0 then
          add_detail_bar(win, nr, HIT, spell.hit)
          nr=nr+1
        end
        if spell.critical>0 then
          add_detail_bar(win, nr, CRIT_ABBR, spell.critical)
          nr=nr+1
        end
        if spell.glancing>0 then
          add_detail_bar(win, nr, L["Glancing"], spell.glancing)
          nr=nr+1
        end
        if spell.crushing>0 then
          add_detail_bar(win, nr, L["Crushing"], spell.crushing)
          nr=nr+1
        end
        if spell.ABSORB and spell.ABSORB>0 then
          add_detail_bar(win, nr, ABSORB, spell.ABSORB)
          nr=nr+1
        end
        if spell.BLOCK and spell.BLOCK>0 then
          add_detail_bar(win, nr, ACTION_SPELL_MISSED_BLOCK, spell.BLOCK)
          nr=nr+1
        end
        if spell.DEFLECT and spell.DEFLECT>0 then
          add_detail_bar(win, nr, DEFLECT, spell.DEFLECT)
          nr=nr+1
        end
        if spell.DODGE and spell.DODGE>0 then
          add_detail_bar(win, nr, DODGE, spell.DODGE)
          nr=nr+1
        end
        if spell.EVADE and spell.EVADE>0 then
          add_detail_bar(win, nr, EVADE, spell.EVADE)
          nr=nr+1
        end
        if spell.IMMUNE and spell.IMMUNE>0 then
          add_detail_bar(win, nr, IMMUNE, spell.IMMUNE)
          nr=nr+1
        end
        if spell.MISS and spell.MISS>0 then
          add_detail_bar(win, nr, MISS, spell.MISS)
          nr=nr+1
        end
        if spell.PARRY and spell.PARRY>0 then
          add_detail_bar(win, nr, PARRY, spell.PARRY)
          nr=nr+1
        end
        if spell.REFLECT and spell.REFLECT>0 then
          add_detail_bar(win, nr, REFLECT, spell.REFLECT)
          nr=nr+1
        end
        if spell.RESIST and spell.RESIST>0 then
          add_detail_bar(win, nr, RESIST, spell.RESIST)
          nr=nr+1
        end
      end
    end
  end

  function spellsourcesmod:Enter(win, id, label)
    self.spellname=id
    self.title=label..L["'s Sources"]
  end

  function spellsourcesmod:Update(win, set)
    local nr, max=1, 0

    for i, player in ipairs(set.players) do
      if player.damagedone.amount>0 and player.damagedone.spells[self.spellname] then
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=player.id
        d.label=player.name
        d.class=player.class
        d.icon=d.class and Skada.classIcon or Skada.petIcon

        local amount=player.damagedone.spells[self.spellname].amount

        d.value=amount
        d.valuetext=Skada:FormatNumber(amount)

        if amount>max then
          max=amount
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function spellsmod:Update(win, set)
    local spells={}

    for i, player in ipairs(set.players) do
      if player.damagedone.amount>0 then
        for spellname, spell in pairs(player.damagedone.spells) do
          spells[spellname]=spells[spellname] or spell
        end
      end
    end

    local nr, max=1, 0

    for spellname, spell in pairs(spells) do
      local d=win.dataset[nr] or {}
      win.dataset[nr]=d

      d.id=spellname
      d.label=spellname
      d.icon=select(3, GetSpellInfo(spell.id))

      d.value=spell.amount
      d.valuetext=format("%s (%02.1f%%)", Skada:FormatNumber(spell.amount), spell.amount/set.damagedone*100)

      if spell.amount>max then
        max=spell.amount
      end

      nr=nr+1
    end

    win.metadata.maxvalue=max
  end

  function mod:Update(win, set)
    local nr, max=1, 0

    for i, player in ipairs(set.players) do
      if player.damagedone.amount>0 then
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=player.id
        d.label=player.name
        d.class=player.class
        d.icon=d.class and Skada.classIcon or Skada.petIcon

        local dps=getDPS(set, player)

        d.value=player.damagedone.amount
        d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(player.damagedone.amount), self.metadata.columns.Damage,
          format("%02.1f", dps), self.metadata.columns.DPS,
          format("%02.1f%%", player.damagedone.amount/set.damagedone*100), self.metadata.columns.Percent
        )

        if player.damagedone.amount>max then
          max=player.damagedone.amount
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  local function feed_personal_dps()
    if Skada.current then
      local player=Skada:find_player(Skada.current, UnitGUID("player"))
      if player then
        return format("%02.1f", getDPS(Skada.current, player)).." "..L["DPS"]
      end
    end
  end

  local function feed_raid_dps()
    if Skada.current then
      return format("%02.1f", getRaidDPS(Skada.current)).." "..L["RDPS"]
    end
  end

  function dpsmod:GetSetSummary(set)
    return Skada:FormatNumber(getRaidDPS(set))
  end

  function dpsmod:Update(win, set)
    local nr, max=1, 0

    for i, player in ipairs(set.players) do
      local dps=getDPS(set, player)

      if dps>0 then
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=player.id
        d.label=player.name
        d.class=player.class
        d.icon=d.class and Skada.classIcon or Skada.petIcon
        
        d.value=dps
        d.valuetext=format("%02.1f", dps)
        
        if dps>max then
          max=dps
        end
        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:OnEnable()
    spellmod.metadata={columns={Damage=true, Percent=true}}
    playermod.metadata={showspots=true, tooltip=player_tooltip, click1=spellmod, columns={Damage=true, Percent=true}}
    targetmod.metadata={columns={Damage=true, Percent=true}}
    mod.metadata={showspots=true, click1=playermod, click2=targetmod, columns={Damage=true, DPS=true, Percent=true}}

    dpsmod.metadata={showspots=true, tooltip=dps_tooltip, click1=playermod}
    spellsmod.metadata={showspots=true, ordersort=true, click1=spellsourcesmod}

    Skada:RegisterForCL(SpellDamage, 'DAMAGE_SHIELD', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SpellDamage, 'SPELL_DAMAGE', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SpellDamage, 'SPELL_PERIODIC_DAMAGE', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SpellDamage, 'SPELL_BUILDING_DAMAGE', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SpellDamage, 'RANGE_DAMAGE', {src_is_interesting=true, dst_is_not_interesting=true})

    Skada:RegisterForCL(SpellMissed, 'SPELL_MISSED', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SpellMissed, 'SPELL_PERIODIC_MISSED', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SpellMissed, 'RANGE_MISSED', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SpellMissed, 'SPELL_BUILDING_MISSED', {src_is_interesting=true, dst_is_not_interesting=true})

    Skada:RegisterForCL(SwingDamage, 'SWING_DAMAGE', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SwingMissed, 'SWING_MISSED', {src_is_interesting=true, dst_is_not_interesting=true})

    Skada:AddFeed(L["Damage: Personal DPS"], feed_personal_dps)
    Skada:AddFeed(L["Damage: Raid DPS"], feed_raid_dps)

    Skada:AddMode(self)
    Skada:AddMode(spellsmod)
    Skada:AddMode(dpsmod)
  end

  function mod:OnDisable()
    Skada:RemoveMode(self)
    Skada:RemoveMode(spellsmod)
    Skada:RemoveMode(dpsmod)
    Skada:RemoveFeed(L["Damage: Personal DPS"])
    Skada:RemoveFeed(L["Damage: Raid DPS"])
  end

  function mod:AddToTooltip(set, tooltip)
    GameTooltip:AddDoubleLine(L["DPS"], format("%02.1f", getRaidDPS(set)), 1, 1, 1)
  end

  function mod:GetSetSummary(set)
    return Skada:FormatNumber(set.damagedone)
  end

  function mod:AddPlayerAttributes(player)
    if not player.damagedone then
      player.damagedone={amount=0, spells={}, targets={}}
    end
  end

  function mod:AddSetAttributes(set)
    set.damagedone=set.damagedone or 0
  end
end

-- ================== --
-- Damage Taken Module --
-- ================== --

do
  local mod=Skada:NewModule(L["Damage Taken"])
  local playermod=mod:NewModule(L["Damage spell list"])
  local spellmod=mod:NewModule(L["Damage spell details"])
  local sourcemod=mod:NewModule(L["Damage spell sources"])

  local spellsmod=Skada:NewModule(L["Damage taken by spell"])
  local spelltargetsmod=spellsmod:NewModule(L["Damage spell targets"])

  local function log_damage(set, dmg)
    local player=Skada:find_player(set, dmg.srcGUID, dmg.srcName)
    if not player then return end

    set.damagetaken=set.damagetaken+dmg.amount
    player.damagetaken.amount=player.damagetaken.amount+dmg.amount

    if not player.damagetaken.spells[dmg.spellname] then
      player.damagetaken.spells[dmg.spellname]={id=dmg.spellid, hit=0, totalhits=0, amount=0, critical=0, glancing=0, crushing=0, ABSORB=0, BLOCK=0, DEFLECT=0, DODGE=0, EVADE=0, IMMUNE=0, PARRY=0, REFLECT=0, RESIST=0, MISS=0}
    end

    local spell=player.damagetaken.spells[dmg.spellname]
    spell.totalhits=spell.totalhits+1
    spell.amount=spell.amount+dmg.amount

    if spell.max==nil or dmg.amount>spell.max then
      spell.max=dmg.amount
    end

    if (spell.min==nil or dmg.amount<spell.min) and not dmg.missed then
      spell.min=dmg.amount
    end

    if dmg.critical then
      spell.critical=spell.critical+1

    elseif dmg.missed ~= nil then
      if spell[dmg.missed] ~= nil then
        spell[dmg.missed]=spell[dmg.missed]+1
      end

    elseif dmg.glancing then
      spell.glancing=spell.glancing+1

    elseif dmg.crushing then
      spell.crushing=spell.crushing+1

    else
      spell.hit=spell.hit+1
    end

    if set==Skada.current and dmg.dstName then
      if not player.damagetaken.sources[dmg.dstName] then
        player.damagetaken.sources[dmg.dstName]={id=dmg.dstGUID, amount=0}
      end
      player.damagetaken.sources[dmg.dstName].amount=player.damagetaken.sources[dmg.dstName].amount+dmg.amount
    end
  end

  local dmg={}

  local function SpellDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    dmg=_SpellDamage((srcGUID ~= dstGUID), dstGUID, dstName, dstFlags, srcGUID, srcName, srcFlags, ...)
    if dmg then
      log_damage(Skada.current, dmg)
      log_damage(Skada.total, dmg)
    end
  end

  local function SpellMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    dmg=_SpellMissed((srcGUID ~= dstGUID), dstGUID, dstName, dstFlags, srcGUID, srcName, srcFlags, ...)
    if dmg then
      log_damage(Skada.current, dmg)
      log_damage(Skada.total, dmg)
    end
  end

  local function SwingDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    dmg=_SwingDamage((srcGUID ~= dstGUID), dstGUID, dstName, dstFlags, srcGUID, srcName, srcFlags, ...)
    if dmg then
      log_damage(Skada.current, dmg)
      log_damage(Skada.total, dmg)
    end
  end

  local function SwingMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    dmg=_SwingMissed((srcGUID ~= dstGUID), dstGUID, dstName, dstFlags, srcGUID, srcName, srcFlags, ...)
    if dmg then
      log_damage(Skada.current, dmg)
      log_damage(Skada.total, dmg)
    end
  end

  function playermod:Enter(win, id, label)
    self.playerid=id
    self.title=format(L["%s's Damage taken"], label)
  end

  function playermod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0

    if player then
      local nr=1

      for spellname, spell in pairs(player.damagetaken.spells) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=spellname
        d.label=spellname
        d.icon=select(3, GetSpellInfo(spell.id))

        d.value=spell.amount
        d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(spell.amount), self.metadata.columns.Damage,
          format("%02.1f%%", spell.amount/player.damagetaken.amount*100), self.metadata.columns.Percent
        )

        if spell.amount>max then
          max=spell.amount
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function sourcemod:Enter(win, id, label)
    local player=Skada:find_player(win:get_selected_set(), id)
    self.playerid=id
    self.title=format(L["%s's Damage sources"], player.name)
  end

  function sourcemod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0

    if player then
      local nr=1

      for mobname, mob in pairs(player.damagetaken.sources) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=mobname
        d.label=mobname

        d.value=mob.amount
        d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(mob.amount), self.metadata.columns.Damage,
          format("%02.1f%%", mob.amount/player.damagetaken.amount*100), self.metadata.columns.Percent
          )

        if mob.amount>max then
          max=mob.amount
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  local function add_detail_bar(win, nr, title, value)
    local d=win.dataset[nr] or {}
    win.dataset[nr]=d

    d.id=title
    d.label=title
    d.value=value
    d.valuetext=Skada:FormatValueText(
      value, mod.metadata.columns.Damage,
      format("%02.1f%%", value/win.metadata.maxvalue*100), mod.metadata.columns.Percent
    )
  end

  function spellmod:Enter(win, id, label)
    local player=Skada:find_player(win:get_selected_set(), playermod.playerid)
    self.spellname=id
    self.title=player.name..L["'s "]..label
  end

  function spellmod:Update(win, set)
    local player=Skada:find_player(set, playermod.playerid)

    if player then
      local spell=player.damagetaken.spells[self.spellname]

      if spell then
        win.metadata.maxvalue=spell.totalhits
        local nr=1

        if spell.hit>0 then
          add_detail_bar(win, nr, HIT, spell.hit)
          nr=nr+1
        end
        if spell.critical>0 then
          add_detail_bar(win, nr, CRIT_ABBR, spell.critical)
          nr=nr+1
        end
        if spell.glancing>0 then
          add_detail_bar(win, nr, L["Glancing"], spell.glancing)
          nr=nr+1
        end
        if spell.crushing>0 then
          add_detail_bar(win, nr, L["Crushing"], spell.crushing)
          nr=nr+1
        end
        if spell.ABSORB and spell.ABSORB>0 then
          add_detail_bar(win, nr, ABSORB, spell.ABSORB)
          nr=nr+1
        end
        if spell.BLOCK and spell.BLOCK>0 then
          add_detail_bar(win, nr, ACTION_SPELL_MISSED_BLOCK, spell.BLOCK)
          nr=nr+1
        end
        if spell.DEFLECT and spell.DEFLECT>0 then
          add_detail_bar(win, nr, DEFLECT, spell.DEFLECT)
          nr=nr+1
        end
        if spell.DODGE and spell.DODGE>0 then
          add_detail_bar(win, nr, DODGE, spell.DODGE)
          nr=nr+1
        end
        if spell.EVADE and spell.EVADE>0 then
          add_detail_bar(win, nr, EVADE, spell.EVADE)
          nr=nr+1
        end
        if spell.IMMUNE and spell.IMMUNE>0 then
          add_detail_bar(win, nr, IMMUNE, spell.IMMUNE)
          nr=nr+1
        end
        if spell.MISS and spell.MISS>0 then
          add_detail_bar(win, nr, MISS, spell.MISS)
          nr=nr+1
        end
        if spell.PARRY and spell.PARRY>0 then
          add_detail_bar(win, nr, PARRY, spell.PARRY)
          nr=nr+1
        end
        if spell.REFLECT and spell.REFLECT>0 then
          add_detail_bar(win, nr, REFLECT, spell.REFLECT)
          nr=nr+1
        end
        if spell.RESIST and spell.RESIST>0 then
          add_detail_bar(win, nr, RESIST, spell.RESIST)
          nr=nr+1
        end
      end
    end
  end

  function spelltargetsmod:Enter(win, id, label)
    self.spellname=id
    self.title=format(L["%s's Targets"], label)
  end

  function spelltargetsmod:Update(win, set)
    local nr, max=1, 0

    for i, player in ipairs(set.players) do
      if player.damagetaken.amount>0 and player.damagetaken.spells[self.spellname] then
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=player.id
        d.label=player.name
        d.class=player.class
        d.icon=d.class and Skada.classIcon or Skada.petIcon

        local amount=player.damagetaken.spells[self.spellname].amount

        d.value=amount
        d.valuetext=Skada:FormatNumber(amount)

        if amount>max then
          max=amount
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function spellsmod:Update(win, set)
    local spells={}

    for i, player in ipairs(set.players) do
      if player.damagetaken.amount>0 then
        for spellname, spell in pairs(player.damagetaken.spells) do
          spells[spellname]=spells[spellname] or spell
        end
      end
    end

    local nr, max=1, 0

    for spellname, spell in pairs(spells) do
      local d=win.dataset[nr] or {}
      win.dataset[nr]=d

      d.id=spellname
      d.label=spellname
      d.icon=select(3, GetSpellInfo(spell.id))

      d.value=spell.amount
      d.valuetext=format("%s (%02.1f%%)", Skada:FormatNumber(spell.amount), spell.amount/set.damagetaken*100)

      if spell.amount>max then
        max=spell.amount
      end

      nr=nr+1
    end

    win.metadata.maxvalue=max
  end

  function mod:Update(win, set)
    local nr, max=1, 0

    for i, player in ipairs(set.players) do
      if player.damagetaken.amount>0 then
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=player.id
        d.label=player.name
        d.class=player.class
        d.icon=d.class and Skada.classIcon or Skada.petIcon

        d.value=player.damagetaken.amount
        d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(player.damagetaken.amount), self.metadata.columns.Damage,
          format("%02.1f%%", player.damagetaken.amount/set.damagetaken*100), self.metadata.columns.Percent
        )

        if player.damagetaken.amount>max then
          max=player.damagetaken.amount
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:OnEnable()
    spellmod.metadata={columns={Damage=true, Percent=true}}
    playermod.metadata={showspots=true, click1=spellmod, columns={Damage=true, Percent=true}}
    sourcemod.metadata={columns={Damage=true, Percent=true}}
    mod.metadata={showspots=true, click1=playermod, click2=sourcemod, columns={Damage=true, Percent=true}}

    spellsmod.metadata={showspots=true, ordersort=true, click1=spelltargetsmod}

    Skada:RegisterForCL(SpellDamage, 'DAMAGE_SHIELD', {dst_is_interesting_nopets=true})
    Skada:RegisterForCL(SpellDamage, 'SPELL_DAMAGE', {dst_is_interesting_nopets=true})
    Skada:RegisterForCL(SpellDamage, 'SPELL_PERIODIC_DAMAGE', {dst_is_interesting_nopets=true})
    Skada:RegisterForCL(SpellDamage, 'SPELL_BUILDING_DAMAGE', {dst_is_interesting_nopets=true})
    Skada:RegisterForCL(SpellDamage, 'RANGE_DAMAGE', {dst_is_interesting_nopets=true})

    Skada:RegisterForCL(SpellMissed, 'SPELL_MISSED', {dst_is_interesting_nopets=true})
    Skada:RegisterForCL(SpellMissed, 'SPELL_PERIODIC_MISSED', {dst_is_interesting_nopets=true})
    Skada:RegisterForCL(SpellMissed, 'RANGE_MISSED', {dst_is_interesting_nopets=true})
    Skada:RegisterForCL(SpellMissed, 'SPELL_BUILDING_MISSED', {dst_is_interesting_nopets=true})

    Skada:RegisterForCL(SwingDamage, 'SWING_DAMAGE', {dst_is_interesting_nopets=true})
    Skada:RegisterForCL(SwingMissed, 'SWING_MISSED', {dst_is_interesting_nopets=true})

    Skada:AddMode(self)
    Skada:AddMode(spellsmod)
  end

  function mod:OnDisable()
    Skada:RemoveMode(self)
    Skada:RemoveMode(spellsmod)
  end

  function mod:GetSetSummary(set)
    return Skada:FormatNumber(set.damagetaken)
  end

  function mod:AddPlayerAttributes(player)
    if not player.damagetaken then
      player.damagetaken={amount=0, spells={}, sources={}}
    end
  end

  function mod:AddSetAttributes(set)
    set.damagetaken=set.damagetaken or 0
  end
end

-- ============== --
-- Enemies Module --
-- ============== --
do
  local done=Skada:NewModule(L["Enemy damage done"])
  local doneplayers=done:NewModule(L["Damage done per player"])

  local taken=Skada:NewModule(L["Enemy damage taken"])
  local takenplayers=taken:NewModule(L["Damage taken per player"])

  local function find_player(mob, name)

    if not mob.players[name] then
      mob.players[name]={class=select(2, UnitClass(name)), done=0, taken=0}
    end

    return mob.players[name]
  end

  local function log_damage_done(set, dmg)
    set.enemies.done=set.enemies.done+dmg.amount

    if not set.enemies.list[dmg.srcName] then
      set.enemies.list[dmg.srcName]={taken=0, done=0, players={}}
    end

    local mob=set.enemies.list[dmg.srcName]
    mob.done=mob.done+dmg.amount

    local player=find_player(mob, dmg.dstName)
    player.done=player.done+dmg.amount
  end

  local function log_damage_taken(set, dmg)
    set.enemies.taken=set.enemies.taken+dmg.amount

    if not set.enemies.list[dmg.dstName] then
      set.enemies.list[dmg.dstName]={taken=0, done=0, players={}}
    end

    local mob=set.enemies.list[dmg.dstName]
    mob.taken=set.enemies.list[dmg.dstName].taken+dmg.amount

    local player=find_player(mob, dmg.srcName)
    player.taken=player.taken+dmg.amount
  end

  local dmg={}

  local function SpellDamageTaken(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if not srcName or not dstName then return end
    srcGUID, srcName=Skada:FixMyPets(srcGUID, srcName)
    dmg=_SpellDamage(true, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if dmg then
      log_damage_taken(Skada.current, dmg)
    end
  end

  local function SpellDamageDone(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if not srcName or not dstName then return end
    srcGUID, srcName=Skada:FixMyPets(srcGUID, srcName)
    dmg=_SpellDamage(true, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if dmg then
      log_damage_done(Skada.current, dmg)
    end
  end

  local function SwingDamageTaken(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if not srcName or not dstName then return end
    srcGUID, srcName=Skada:FixMyPets(srcGUID, srcName)
    dmg=_SwingDamage(true, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if dmg then
      log_damage_taken(Skada.current, dmg)
    end
  end

  local function SwingDamageDone(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if not srcName or not dstName then return end
    srcGUID, srcName=Skada:FixMyPets(srcGUID, srcName)
    dmg=_SwingDamage(true, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if dmg then
      log_damage_done(Skada.current, dmg)
    end
  end

  function doneplayers:Enter(win, id, label)
    self.mobname=label
    self.title=format(L["Damage from %s"], label)
  end

  function doneplayers:Update(win, set)
    if self.mobname then
      local max=0

      for mobname, mob in pairs(set.enemies.list) do
        if mobname==self.mobname then
          local nr=1

          for playername, player in pairs(mob.players) do
            if player.done>0 then
              local d=win.dataset[nr] or {}
              win.dataset[nr]=d

              d.id=playername
              d.label=playername
              d.class=player.class
              d.icon=d.class and Skada.classIcon or Skada.petIcon

              d.value=player.done
              d.valuetext=format("%s (%02.1f%%)", Skada:FormatNumber(player.done), player.done/mob.done*100)

              if player.done>max then
                max=player.done
              end

              nr=nr+1
            end
          end

          break
        end
      end

      win.metadata.maxvalue=max
    end
  end

  function done:Update(win, set)
    local nr, max=1, 0

    for mobname, mob in pairs(set.enemies.list) do
      if mob.done>0 then
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=mobname
        d.label=mobname

        d.value=mob.done
        d.valuetext=Skada:FormatNumber(mob.done)

        if mob.done>max then
          max=mob.done
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function takenplayers:Enter(win, id, label)
    self.mobname=label
    self.title=format(L["Damage on %s"], label)
  end

  function takenplayers:Update(win, set)
    if self.mobname then
      local max=0

      for mobname, mob in pairs(set.enemies.list) do
        if mobname==self.mobname then
          local nr=1

          for name, player in pairs(mob.players) do
            if player.taken>0 then
              local d=win.dataset[nr] or {}
              win.dataset[nr]=d

              d.id=name
              d.label=name
              d.class=player.class
              d.icon=d.class and Skada.classIcon or Skada.petIcon

              d.value=player.taken
              d.valuetext=format("%s (%02.1f%%)", Skada:FormatNumber(player.taken), player.taken/mob.taken*100)

              if player.taken>max then
                max=player.taken
              end

              nr=nr+1
            end
          end

          break
        end
      end

      win.metadata.maxvalue=max
    end
  end

  function taken:Update(win, set)
    local nr, max=1, 0

    for mobname, mob in pairs(set.enemies.list) do
      if mob.taken>0 then
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=mobname
        d.label=mobname

        d.value=mob.taken
        d.valuetext=Skada:FormatNumber(mob.taken)

        if mob.taken>max then
          max=mob.taken
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function done:OnEnable()
    doneplayers.metadata={showspots=true}
    done.metadata={click1=doneplayers}
    
    takenplayers.metadata={showspots=true}
    taken.metadata={click1=takenplayers}

    Skada:RegisterForCL(SpellDamageTaken, 'SPELL_DAMAGE', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SpellDamageTaken, 'SPELL_PERIODIC_DAMAGE', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SpellDamageTaken, 'SPELL_BUILDING_DAMAGE', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SpellDamageTaken, 'RANGE_DAMAGE', {src_is_interesting=true, dst_is_not_interesting=true})
    Skada:RegisterForCL(SwingDamageTaken, 'SWING_DAMAGE', {src_is_interesting=true, dst_is_not_interesting=true})

    Skada:RegisterForCL(SpellDamageDone, 'SPELL_DAMAGE', {dst_is_interesting_nopets=true, src_is_not_interesting=true})
    Skada:RegisterForCL(SpellDamageDone, 'SPELL_PERIODIC_DAMAGE', {dst_is_interesting_nopets=true, src_is_not_interesting=true})
    Skada:RegisterForCL(SpellDamageDone, 'SPELL_BUILDING_DAMAGE', {dst_is_interesting_nopets=true, src_is_not_interesting=true})
    Skada:RegisterForCL(SpellDamageDone, 'RANGE_DAMAGE', {dst_is_interesting_nopets=true, src_is_not_interesting=true})
    Skada:RegisterForCL(SwingDamageDone, 'SWING_DAMAGE', {dst_is_interesting_nopets=true, src_is_not_interesting=true})

    Skada:AddMode(self)
    Skada:AddMode(taken)
  end

  function done:OnDisable()
    Skada:RemoveMode(self)
    Skada:RemoveMode(taken)
  end

  function done:GetSetSummary(set)
    return Skada:FormatNumber(set.enemies.done)
  end

  function taken:GetSetSummary(set)
    return Skada:FormatNumber(set.enemies.taken)
  end

  function done:AddSetAttributes(set)
    if not set.enemies then
      set.enemies={done=0, taken=0, list={}}
    end
  end
end

-- ==================== --
-- Friendly Fire Module --
-- ==================== --
do
  local mod=Skada:NewModule(L["Friendly Fire"])
  local spellmod=mod:NewModule(L["Damage spell list"])
  local playermod=mod:NewModule(L["Damage spell targets"])

  local function log_damage(set, dmg)
    -- Get the player.
    local player=Skada:get_player(set, dmg.srcGUID, dmg.srcName)
    if not player then return end

    -- add to player
    player.friendfire.amount=player.friendfire.amount+dmg.amount

    -- record spell damage
    if not player.friendfire.spells[dmg.spellname] then
      player.friendfire.spells[dmg.spellname]={id=dmg.spellid, amount=0}
    end
    player.friendfire.spells[dmg.spellname].amount=player.friendfire.spells[dmg.spellname].amount+dmg.amount

    -- add target
    if not player.friendfire.targets[dmg.dstName] then
      player.friendfire.targets[dmg.dstName]={id=dmg.dstGUID, class=select(2, UnitClass(dmg.dstName)), amount=0}
    end
    player.friendfire.targets[dmg.dstName].amount=player.friendfire.targets[dmg.dstName].amount+dmg.amount

    -- Also add to set total ff damage done.
    set.friendfire=set.friendfire+dmg.amount
  end

  local dmg={}

  local function SpellDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    dmg=_SpellDamage(true, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if dmg then
      log_damage(Skada.current, dmg)
      log_damage(Skada.total, dmg)
    end
  end

  local function SwingDamage(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    dmg=_SwingMissed(true, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if dmg then
      log_damage(Skada.current, dmg)
      log_damage(Skada.total, dmg)
    end
  end

  function playermod:Enter(win, id, label)
    self.playerid=id
    self.title=format(L["%s's Targets"], label)
  end

  function playermod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0
    
    if player then
      local nr=1

      for targetname, target in pairs(player.friendfire.targets) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=target.id
        d.label=targetname
        d.class=target.class
        d.icon=d.class and Skada.classIcon or Skada.petIcon

        d.value=target.amount
        d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(target.amount), self.metadata.columns.Damage,
          format("%02.1f%%", target.amount/set.friendfire*100), self.metadata.columns.Percent
        )

        if target.amount>max then
          max=target.amount
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function spellmod:Enter(win, id, label)
    self.playerid=id
    self.title=format(L["%s's Damage"], label)
  end

  function spellmod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0

    if player then
      local nr=1

      for spellname, spell in pairs(player.friendfire.spells) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=spell.id
        d.label=spellname
        d.icon=select(3, GetSpellInfo(spell.id))
        d.value=spell.amount
        d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(spell.amount), self.metadata.columns.Damage,
          format("%02.1f%%", spell.amount/set.friendfire*100), self.metadata.columns.Percent
        )

        if spell.amount>max then
          max=spell.amount
        end

        nr=nr+1
      end
    end
    win.metadata.maxvalue=max
  end

  function mod:Update(win, set)
    local nr, max=1, 0

    for i, player in pairs(set.players) do
      if player.friendfire.amount>0 then
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=player.id
        d.label=player.name
        d.class=player.class
        d.icon=d.class and Skada.classIcon or Skada.petIcon
        d.value=player.friendfire.amount
        d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(player.friendfire.amount), self.metadata.columns.Damage,
          format("%02.1f%%", player.friendfire.amount/set.friendfire*100), self.metadata.columns.Percent
        )
        d.valuetext=format("%s (%02.1f%%)", Skada:FormatNumber(player.friendfire.amount), player.friendfire.amount/set.friendfire*100)

        if player.friendfire.amount>max then
          max=player.friendfire.amount
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:OnEnable()
    spellmod.metadata={showspots=true, columns={Damage=true, Percent=true}}
    playermod.metadata={showspots=true, columns={Damage=true, Percent=true}}
    mod.metadata={showspots=true, click1=spellmod, click2=playermod, columns={Damage=true, Percent=true}}

    Skada:RegisterForCL(SpellDamage, 'SPELL_DAMAGE', {dst_is_interesting_nopets=true, src_is_interesting_nopets=true})
    Skada:RegisterForCL(SpellDamage, 'SPELL_PERIODIC_DAMAGE', {dst_is_interesting_nopets=true, src_is_interesting_nopets=true})
    Skada:RegisterForCL(SpellDamage, 'SPELL_BUILDING_DAMAGE', {dst_is_interesting_nopets=true, src_is_interesting_nopets=true})
    Skada:RegisterForCL(SpellDamage, 'RANGE_DAMAGE', {dst_is_interesting_nopets=true, src_is_interesting_nopets=true})
    
    Skada:RegisterForCL(SwingDamage, 'SWING_DAMAGE', {dst_is_interesting_nopets=true, src_is_interesting_nopets=true})

    Skada:AddMode(self)
  end

  function mod:OnDisable()
    Skada:RemoveMode(self)
  end

  function mod:AddPlayerAttributes(player)
    if not player.friendfire then
      player.friendfire={amount=0, spells={}, targets={}}
    end
  end

  function mod:AddSetAttributes(set)
    set.friendfire=set.friendfire or 0
  end

  function mod:GetSetSummary(set)
    return Skada:FormatNumber(set.friendfire)
  end
end

-- ============================= --
-- Avoidance & Mitigation Module --
-- ============================= --
do
  local mod=Skada:NewModule(L["Avoidance & Mitigation"])
  local playermod=mod:NewModule(L["Damage breakdown"])

  local tbl={"ABSORB", "BLOCK", "DEFLECT", "DODGE", "PARRY", "REFLECT", "RESIST", "MISS"}
  local temp={}

  function playermod:Enter(win, id, label)
    self.playerid=id
    self.title=format("%s's damage breakdown", label)
  end

  function playermod:Update(win, set)
    local max=0

    if temp[self.playerid] then
      local nr=1
      local p=temp[self.playerid]

      for event, count in pairs(p.data) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=event
        d.label=L[event]
        d.value=count/p.total*100
        d.valuetext=format("%d (%02.1f%%)", count, d.value)

        if d.value>max then
          max=d.value
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:Update(win, set)
    local nr, max=1, 0

    for i, player in ipairs(set.players) do
      if player.damagetaken.amount>0 then

        temp[player.id]={data={}}

        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=player.id
        d.label=player.name
        d.class=player.class
        d.icon=d.class and Skada.classIcon or Skada.petIcon

        local total, avoid=0, 0
        for spellname, spell in pairs(player.damagetaken.spells) do
          total=total+spell.totalhits

          for _, t in ipairs(tbl) do
            if spell[t] and spell[t]>0 then
              avoid=avoid+spell[t]
              if not temp[player.id].data[t] then
                temp[player.id].data[t]=spell[t]
              else
                temp[player.id].data[t]=temp[player.id].data[t]+spell[t]
              end
            end
          end
        end

        temp[player.id].total=total
        temp[player.id].avoid=avoid

        d.value=avoid/total*100
        d.valuetext = format("%02.1f%% (%d/%d)", d.value, avoid, total)

        if d.value>max then
          max=d.value
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:OnEnable()
    playermod.metadata={}
    mod.metadata={showspots=true, click1=playermod}

    Skada:AddMode(self)
  end

  function mod:OnDisable()
    Skada:RemoveMode(self)
  end
end
