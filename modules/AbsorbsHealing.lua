local Skada=Skada
if not Skada then return end

local pairs, ipairs=pairs, ipairs
local select, format=select, string.format
local UnitGUID, UnitName, UnitClass=UnitGUID, UnitName, UnitClass
local GetSpellInfo=GetSpellInfo

-- ============== --
-- Absorbs Module
-- ============== -- 
do
  local modname="Absorbs and healing"
  Skada:AddLoadableModule(modname, nil, function(Skada, L)
    if Skada.db.profile.modulesBlocked[modname] then return end
    
    -- hacked out local crap here
    local mod=Skada:NewModule(L[modname])
    local spellsmod=mod:NewModule(L["Healing and absorbs spell list"])
    local healedmod=mod:NewModule(L["Healed and absorbed players"])

    local absorbsmod=Skada:NewModule(L["Absorbs"])
    local playermod=absorbsmod:NewModule(L["Absorb details"])


    -- This bit shamelessly copied straight from RecountGuessedAbsorbs - thanks!
    local AbsorbSpellDuration=
    {
      -- Death Knight
      [48707]=5, -- Anti-Magic Shell (DK) Rank 1 -- Does not currently seem to show tracable combat log events. It shows energizes which do not reveal the amount of damage absorbed
      [51052]=10, -- Anti-Magic Zone (DK)( Rank 1 (Correct spellID?)
      -- Does DK Spell Deflection show absorbs in the CL?
      [51271]=20, -- Unbreakable Armor (DK)
      [77535]=10, -- Blood Shield (DK)
      -- Druid
      [62606]=10, -- Savage Defense proc. (Druid) Tooltip of the original spell doesn't clearly state that this is an absorb, but the buff does.
      -- Mage
      [11426]=60, -- Ice Barrier (Mage) Rank 1
      [13031]=60,
      [13032]=60,
      [13033]=60,
      [27134]=60,
      [33405]=60,
      [43038]=60,
      [43039]=60, -- Rank 8
      [6143]=30, -- Frost Ward (Mage) Rank 1
      [8461]=30,
      [8462]=30,
      [10177]=30,
      [28609]=30,
      [32796]=30,
      [43012]=30, -- Rank 7
      [1463]=60, --  Mana shield (Mage) Rank 1
      [8494]=60,
      [8495]=60,
      [10191]=60,
      [10192]=60,
      [10193]=60,
      [27131]=60,
      [43019]=60,
      [43020]=60, -- Rank 9
      [543]=30 , -- Fire Ward (Mage) Rank 1
      [8457]=30,
      [8458]=30,
      [10223]=30,
      [10225]=30,
      [27128]=30,
      [43010]=30, -- Rank 7
      -- Paladin
      [58597]=6, -- Sacred Shield (Paladin) proc (Fixed, thanks to Julith)
      -- Priest
      [17]=30, -- Power Word: Shield (Priest) Rank 1
      [592]=30,
      [600]=30,
      [3747]=30,
      [6065]=30,
      [6066]=30,
      [10898]=30,
      [10899]=30,
      [10900]=30,
      [10901]=30,
      [25217]=30,
      [25218]=30,
      [48065]=30,
      [48066]=30, -- Rank 14
      [47509]=12, -- Divine Aegis (Priest) Rank 1
      [47511]=12,
      [47515]=12, -- Divine Aegis (Priest) Rank 3 (Some of these are not actual buff spellIDs)
      [47753]=12, -- Divine Aegis (Priest) Rank 1
      [54704]=12, -- Divine Aegis (Priest) Rank 1
      [47788]=10, -- Guardian Spirit  (Priest) (50 nominal absorb, this may not show in the CL)
      -- Warlock
      [7812]=30, -- Sacrifice (warlock) Rank 1
      [19438]=30,
      [19440]=30,
      [19441]=30,
      [19442]=30,
      [19443]=30,
      [27273]=30,
      [47985]=30,
      [47986]=30, -- rank 9
      [6229]=30, -- Shadow Ward (warlock) Rank 1
      [11739]=30,
      [11740]=30,
      [28610]=30,
      [47890]=30,
      [47891]=30, -- Rank 6
      -- Consumables
      [29674]=86400, -- Lesser Ward of Shielding
      [29719]=86400, -- Greater Ward of Shielding (these have infinite duration, set for a day here :P)
      [29701]=86400,
      [28538]=120, -- Major Holy Protection Potion
      [28537]=120, -- Major Shadow
      [28536]=120, --  Major Arcane
      [28513]=120, -- Major Nature
      [28512]=120, -- Major Frost
      [28511]=120, -- Major Fire
      [7233]=120, -- Fire
      [7239]=120, -- Frost
      [7242]=120, -- Shadow Protection Potion
      [7245]=120, -- Holy
      [6052]=120, -- Nature Protection Potion
      [53915]=120, -- Mighty Shadow Protection Potion
      [53914]=120, -- Mighty Nature Protection Potion
      [53913]=120, -- Mighty Frost Protection Potion
      [53911]=120, -- Mighty Fire
      [53910]=120, -- Mighty Arcane
      [17548]=120, --  Greater Shadow
      [17546]=120, -- Greater Nature
      [17545]=120, -- Greater Holy
      [17544]=120, -- Greater Frost
      [17543]=120, -- Greater Fire
      [17549]=120, -- Greater Arcane
      [28527]=15, -- Fel Blossom
      [29432]=3600, -- Frozen Rune usage (Naxx classic)
      -- Item usage
      [36481]=4, -- Arcane Barrier (TK Kael'Thas) Shield
      [57350]=6, -- Darkmoon Card: Illusion
      [17252]=30, -- Mark of the Dragon Lord (LBRS epic ring) usage
      [25750]=15, -- Defiler's Talisman/Talisman of Arathor Rank 1
      [25747]=15,
      [25746]=15,
      [23991]=15,
      [31000]=300, -- Pendant of Shadow's End Usage
      [30997]=300, -- Pendant of Frozen Flame Usage
      [31002]=300, -- Pendant of the Null Rune
      [30999]=300, -- Pendant of Withering
      [30994]=300, -- Pendant of Thawing
      [31000]=300, --
      [23506]= 20, -- Arena Grand Master Usage (Aura of Protection)
      [12561]=60, -- Goblin Construction Helmet usage
      [31771]=20, -- Runed Fungalcap usage
      [21956]=10, -- Mark of Resolution usage
      [29506]=20, -- The Burrower's Shell
      [4057]=60, -- Flame Deflector
      [4077]=60, -- Ice Deflector
      [39228]=20, -- Argussian Compass (may not be an actual absorb)
      -- Item procs
      [27779]=30, -- Divine Protection - Priest dungeon set 1/2  Proc
      [11657]=20, -- Jang'thraze (Zul Farrak) proc
      [10368]=15, -- Uther's Strength proc
      [37515]=15, -- Warbringer Armor Proc
      [42137]=86400, -- Greater Rune of Warding Proc
      [26467]=30, -- Scarab Brooch proc
      [26470]=8, -- Scarab Brooch proc (actual)
      [27539]=6, -- Thick Obsidian Breatplate proc
      [28810]=30, -- Faith Set Proc Armor of Faith
      [54808]=12, -- Noise Machine proc Sonic Shield
      [55019]=12, -- Sonic Shield (one of these too ought to be wrong)
      [64411]=15, -- Blessing of the Ancient (Val'anyr Hammer of Ancient Kings equip effect)
      [64413]=8, -- Val'anyr, Hammer of Ancient Kings proc Protection of Ancient Kings
      -- Misc
      [40322]=30, -- Teron's Vengeful Spirit Ghost - Spirit Shield
      -- Boss abilities
      [65874]=15, -- Twin Val'kyr's Shield of Darkness 175000
      [67257]=15, -- 300000
      [67256]=15, -- 700000
      [67258]=15, -- 1200000
      [65858]=15, -- Twin Val'kyr's Shield of Lights 175000
      [67260]=15, -- 300000
      [67259]=15, -- 700000
      [67261]=15, -- 1200000
    }

    local shields={}

    local function AuraApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
      local spellid, spellname, spellschool, auratype=...
      if AbsorbSpellDuration[spellid] then

        shields[dstName]=shields[dstName] or {}
        shields[dstName][spellid]=shields[dstName][spellid] or {}
        shields[dstName][spellid][srcName]=timestamp + AbsorbSpellDuration[spellid]

      end
    end

    local function AuraRemoved(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
      local spellid, spellname, spellschool, auratype=...
      if AbsorbSpellDuration[spellid] then

        if shields[dstName] and shields[dstName][spellid] and shields[dstName][spellid][dstName] then
          -- As advised in RecountGuessedAbsorbs, do not remove shields straight away as an absorb can come after the aura removed event.
          shields[dstName][spellid][dstName]=timestamp + 0.1
        end

      end
    end

    local function log_absorb(set, srcName, dstName, amount, spell_id)
      -- Get the player
      local player=Skada:get_player(set, UnitGUID(srcName), UnitName(srcName))
      if player then
        -- add the absorb amount to the player's current healed total
        player.absorbTotal=player.absorbTotal + amount

        -- Also add to the set total heals
        set.absorbTotal=set.absorbTotal + amount

        -- Create recipient if it does not exist.
        if not player.absorbed[dstName] then
          player.absorbed[dstName]={class=select(2, UnitClass(dstName)), amount=0}
        end

        -- Add to recipient absorbs.
        player.absorbed[dstName].amount=player.absorbed[dstName].amount + amount

        -- Create spell if it does not exist.
        local spellname=GetSpellInfo(spell_id)
        if not player.absorbSpells[spellname] then
          player.absorbSpells[spellname]={id=spell_id, name=spellname, hits=0, healing=0, overhealing=0, critical=0, min=0, max=0}
        end

        -- Get the spell from player.
        local spell=player.absorbSpells[spellname]

        spell.healing=spell.healing + amount
        spell.hits=(spell.hits or 0) + 1

        --NOTE The min code here is just copied from Skada's Healing.lua, but it doesn't work in either spot, needs a better implementation
        if not spell.min or amount < spell.min then
          spell.min=amount
        end
        if not spell.max or amount>spell.max then
          spell.max=amount
        end
      end
    end

    local function consider_absorb(amount, dstName, srcName, timestamp)
      local mintime=nil
      local found_shield_src
      local spell_id
      for shield_id, spells in pairs(shields[dstName]) do
        for shield_src, ts in pairs(spells) do
          if ts - timestamp>0 and (mintime==nil or ts - timestamp < mintime) then
            found_shield_src=shield_src
            spell_id=shield_id
          end
        end
      end

      if found_shield_src then
        log_absorb(Skada.current, found_shield_src, dstName, amount,spell_id)
        log_absorb(Skada.total, found_shield_src, dstName, amount,spell_id)
      end
    end

    local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
      local samount, soverkill, sschool, sresisted, sblocked, absorbed, scritical, sglancing, scrushing=...
      if absorbed and absorbed>0 and dstName and shields[dstName] and srcName then
        --Skada:Print(dstName.." absorbed "..absorbed.." from "..srcName.." (SWING)")
        consider_absorb(absorbed, dstName, srcName, timestamp)
      end
    end

    local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
      local spellid, spellname, spellschool, samount, soverkill, sschool, sresisted, sblocked, absorbed, scritical, sglancing, scrushing=...
      if absorbed and absorbed>0 and dstName and shields[dstName] and srcName then
        --Skada:Print(dstName.." absorbed "..absorbed.." from "..srcName.." (SPELL)")
        consider_absorb(absorbed, dstName, srcName, timestamp)
      end
    end

    local function SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
      local spellid, spellname, spellschool, misstype, absorbed=...
      if misstype=="ABSORB" and absorbed>0 and dstName and shields[dstName] and srcName then
        --Skada:Print(dstName.." absorbed "..absorbed.." from "..srcName.." (MISS)")
        consider_absorb(absorbed, dstName, srcName, timestamp)
      end
    end

    local function SwingMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
      SpellMissed(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, nil, nil, nil, ...)
    end

    local function getHPS(set, player)
      local totaltime=Skada:PlayerActiveTime(set, player)

      return (player.healing+player.absorbTotal)/math.max(1,totaltime)
    end

    function mod:Update(win, set)
      local nr=1
      local max=0

      for i, player in ipairs(set.players) do
        if ((player.healing+player.absorbTotal)>0) then

          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=player.id
          d.value=player.healing + player.absorbTotal
          d.label=player.name
          d.valuetext=Skada:FormatValueText(
            Skada:FormatNumber(player.healing+player.absorbTotal), self.metadata.columns.Healing,
            format("%02.1f", getHPS(set, player)), self.metadata.columns.HPS,
            (" (%02.1f%%)"):format((player.healing+player.absorbTotal)/(set.healing+set.absorbTotal)*100), self.metadata.columns.Percent
            )
          d.class=player.class
          d.role=player.role

          if((player.healing+player.absorbTotal)>max) then
            max=player.healing+player.absorbTotal
          end

          nr=nr + 1
        end
      end

      win.metadata.maxvalue=max
    end

    local function spell_tooltip(win, id, label, tooltip)
      local player=Skada:find_player(win:get_selected_set(), spellsmod.playerid)
      if player then
        local spell=player.healingspells[label]
        --if not spell then spell=player.absorbSpells[label] end

        if spell then
          tooltip:AddLine(player.name.." - "..label)
          if spell.min and spell.min>0 then
            tooltip:AddDoubleLine(L["Minimum hit:"], Skada:FormatNumber(spell.min), 255,255,255,255,255,255)
          end
          if spell.max then
            tooltip:AddDoubleLine(L["Maximum hit:"], Skada:FormatNumber(spell.max), 255,255,255,255,255,255)
          end
          tooltip:AddDoubleLine(L["Average hit:"], Skada:FormatNumber(spell.healing/spell.hits), 255,255,255,255,255,255)
          
          if spell.hits then
            tooltip:AddDoubleLine(L["Critical"]..":", ("%02.1f%%"):format(spell.critical/spell.hits*100), 255,255,255,255,255,255)
          end
          if spell.hits then
            tooltip:AddDoubleLine(L["Overhealing"]..":", ("%02.1f%%"):format(spell.overhealing/(spell.overhealing + spell.healing)*100), 255,255,255,255,255,255)
          end
        end
      end
    end

    function spellsmod:Enter(win, id, label)
      spellsmod.playerid=id
      spellsmod.title=format(L["%s's Absorbs and healing"], label)
    end

    -- Spell view of a player.
    function spellsmod:Update(win, set)
      -- View spells for this player.

      local player=Skada:find_player(set, self.playerid)
      local nr=1
      local max=0

      if player then
        local healAbsorbSpells={}

        -- copy the healingspells table
        for spellname, spell in pairs(player.healingspells) do healAbsorbSpells[spellname]=spell end

        -- merge in the absorbSpells table
        for spellname, spell in pairs(player.absorbSpells) do healAbsorbSpells[spellname]=spell end

        for spellname, spell in pairs(healAbsorbSpells) do

          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=spell.id
          d.spellid=spell.id
          d.label=spell.name
          d.value=spell.healing
          d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(spell.healing), self.metadata.columns.Healing,
          format("%02.1f%%", spell.healing/(player.healing + player.absorbTotal)*100), self.metadata.columns.Percent
          )
          d.icon=select(3, GetSpellInfo(spell.id))

          if spell.healing>max then
            max=spell.healing
          end

          nr=nr + 1
        end
      end

      win.metadata.maxvalue=max
    end

    function healedmod:Enter(win, id, label)
      healedmod.playerid=id
      healedmod.title=format(L["Healed by %s"], label)
    end

    -- Healed players view of a player.
    function healedmod:Update(win, set)
      local player=Skada:find_player(set, healedmod.playerid)
      local nr=1
      local max=0

      if player then
        local healAbsorbs={}

        -- copy the heal table
        for name, heal in pairs(player.healed) do healAbsorbs[name]=heal end

        -- merge in the absorb table
        for name, heal in pairs(player.absorbed) do
          if not healAbsorbs[name] then
            healAbsorbs[name]=heal
          else
            healAbsorbs[name].amount=healAbsorbs[name].amount + heal.amount
          end
        end
        for name, heal in pairs(healAbsorbs) do
          if heal.amount>0 then

            local d=win.dataset[nr] or {}
            win.dataset[nr]=d

            d.id=name
            d.label=name
            d.value=heal.amount
            d.class=heal.class
            d.valuetext=Skada:FormatValueText(
            Skada:FormatNumber(heal.amount), self.metadata.columns.Healing,
            format("%02.1f%%", heal.amount/(player.healing+player.absorbTotal)*100), self.metadata.columns.Percent
            )
            if heal.amount>max then
              max=heal.amount
            end

            nr=nr + 1
          end
        end
      end

      win.metadata.maxvalue=max
    end

    function absorbsmod:Update(win, set)
      local nr=1
      local max=0

      for i, player in ipairs(set.players) do
        if player.absorbTotal>0 then

          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=player.id
          d.value=player.absorbTotal
          d.label=player.name
          d.valuetext=Skada:FormatNumber(player.absorbTotal)..(" (%02.1f%%)"):format(player.absorbTotal/set.absorbTotal*100)
          d.class=player.class
          d.role=player.role

          if player.absorbTotal>max then
            max=player.absorbTotal
          end

          nr=nr + 1
        end
      end

      win.metadata.maxvalue=max
    end

    function playermod:Enter(win, id, label)
      playermod.playerid=id
      playermod.title=format(L["%s's Absorbs"], label)
    end

    function playermod:Update(win, set)
      local player=Skada:find_player(set, self.playerid)

      local nr=1
      local max=0

      if player then

        for dstName, absorbed in pairs(player.absorbed) do
          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=dstName
          d.value=absorbed.amount
          d.label=dstName
          d.valuetext=Skada:FormatNumber(absorbed.amount)..(" (%02.1f%%)"):format(absorbed.amount/player.absorbTotal*100)
          d.class=absorbed.class

          if absorbed.amount>max then
            max=absorbed.amount
          end

          nr=nr + 1
        end

        win.metadata.maxvalue=max

      end
    end

    function mod:OnEnable()
      absorbsmod.metadata={showspots=true, click1=playermod}
      playermod.metadata={}

      mod.metadata={showspots=true, click1=spellsmod, click2=healedmod, columns={Healing=true, HPS=true, Percent=true}}
      spellsmod.metadata ={tooltip=spell_tooltip, columns={Healing=true, Percent=true}}
      healedmod.metadata ={showspots=true, columns={Healing=true, Percent=true}}

      Skada:RegisterForCL(AuraApplied, 'SPELL_AURA_REFRESH', {src_is_interesting_nopets=true})
      Skada:RegisterForCL(AuraApplied, 'SPELL_AURA_APPLIED', {src_is_interesting_nopets=true})
      Skada:RegisterForCL(AuraRemoved, 'SPELL_AURA_REMOVED', {src_is_interesting_nopets=true})
      Skada:RegisterForCL(SpellDamage, 'DAMAGE_SHIELD', {dst_is_interesting_nopets=true})
      Skada:RegisterForCL(SpellDamage, 'SPELL_DAMAGE', {dst_is_interesting_nopets=true})
      Skada:RegisterForCL(SpellDamage, 'SPELL_PERIODIC_DAMAGE', {dst_is_interesting_nopets=true})
      Skada:RegisterForCL(SpellDamage, 'SPELL_BUILDING_DAMAGE', {dst_is_interesting_nopets=true})
      Skada:RegisterForCL(SpellDamage, 'RANGE_DAMAGE', {dst_is_interesting_nopets=true})
      Skada:RegisterForCL(SwingDamage, 'SWING_DAMAGE', {dst_is_interesting_nopets=true})
      Skada:RegisterForCL(SpellMissed, 'SPELL_MISSED', {dst_is_interesting_nopets=true})
      Skada:RegisterForCL(SpellMissed, 'SPELL_PERIODIC_MISSED', {dst_is_interesting_nopets=true})
      Skada:RegisterForCL(SpellMissed, 'SPELL_BUILDING_MISSED', {dst_is_interesting_nopets=true})
      Skada:RegisterForCL(SpellMissed, 'RANGE_MISSED', {dst_is_interesting_nopets=true})
      Skada:RegisterForCL(SwingMissed, 'SWING_MISSED', {dst_is_interesting_nopets=true})

      Skada:AddMode(self, L["Absorbs and healing"])
      Skada:AddMode(absorbsmod, L["Absorbs and healing"])
    end

    function mod:OnDisable()
      Skada:RemoveMode(self)
      Skada:RemoveMode(absorbsmod)
    end

    function mod:GetSetSummary(set)
      return Skada:FormatNumber(set.healing+set.absorbTotal)
    end

    -- Called by Skada when a new player is added to a set.
    function mod:AddPlayerAttributes(player)
      if not player.absorbed then
        player.absorbed={} -- Stored absorbs per recipient
      end
      if not player.absorbTotal then
        player.absorbTotal=0 -- Total absorbs
        player.absorbSpells={} -- Absorbed spells
      end
    end

    -- Called by Skada when a new set is created.
    -- Conveniently this is when a new fight starts, so we can clear our shield cache.
    function mod:AddSetAttributes(set)
      if not set.absorbTotal then
        set.absorbTotal=0
      end
      shields={}
    end
  end)
end

-- ============== --
-- Healing Module
-- ============== --
local healingmod="Healing"
do
  Skada:AddLoadableModule(healingmod, nil, function(Skada, L)
    if Skada.db.profile.modulesBlocked[healingmod] then return end
    
    local mod=Skada:NewModule(L[healingmod])
    local spellsmod=mod:NewModule(L["Healing spell list"])
    local healedmod=mod:NewModule(L["Healed players"])

    local function log_heal(set, heal)
      -- Get the player from set.
      local player=Skada:get_player(set, heal.playerid, heal.playername)
      if player then
        -- Subtract overhealing
        local amount=math.max(0, heal.amount - heal.overhealing)

        -- Add to player total.
        player.healing=player.healing + amount
        player.overhealing=player.overhealing + heal.overhealing

        -- Also add to set total damage.
        set.healing=set.healing + amount
        set.overhealing=set.overhealing + heal.overhealing

        -- Create recipient if it does not exist.
        if not player.healed[heal.dstName] then
          player.healed[heal.dstName]={class=select(2, UnitClass(heal.dstName)), amount=0}
        end

        -- Add to recipient healing.
        player.healed[heal.dstName].amount=player.healed[heal.dstName].amount + amount

        -- Create spell if it does not exist.
        if not player.healingspells[heal.spellname] then
          player.healingspells[heal.spellname]={id=heal.spellid, name=heal.spellname, hits=0, healing=0, overhealing=0, critical=0, min=0, max=0}
        end

        -- Get the spell from player.
        local spell=player.healingspells[heal.spellname]

        spell.healing=spell.healing + amount
        if heal.critical then
          spell.critical=spell.critical + 1
        end
        spell.overhealing=spell.overhealing + heal.overhealing

        spell.hits=(spell.hits or 0) + 1

        if not spell.min or amount < spell.min then
          spell.min=amount
        end
        if not spell.max or amount>spell.max then
          spell.max=amount
        end
      end
    end

    local heal={}

    local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
      -- Healing
      local spellid, spellname, spellschool, samount, soverhealing, absorbed, scritical=...

      heal.playerid=srcGUID
      heal.playername=srcName
      heal.dstName=dstName
      heal.dstGUID=dstGUID
      heal.spellid=spellid
      heal.spellname=spellname
      heal.amount=samount
      heal.overhealing=soverhealing
      heal.critical=scritical

      Skada:FixPets(heal)
      log_heal(Skada.current, heal)
      log_heal(Skada.total, heal)
    end

    local function getHPS(set, player)
      local totaltime=Skada:PlayerActiveTime(set, player)

      return player.healing/math.max(1,totaltime)
    end

    function mod:Update(win, set)
      local nr=1
      local max=0

      for i, player in ipairs(set.players) do
        if player.healing>0 then

          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=player.id
          d.label=player.name
          d.value=player.healing

          d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(player.healing), self.metadata.columns.Healing,
          format("%02.1f", getHPS(set, player)), self.metadata.columns.HPS,
          format("%02.1f%%", player.healing/set.healing*100), self.metadata.columns.Percent
          )
          d.class=player.class
          d.role=player.role

          if player.healing>max then
            max=player.healing
          end

          nr=nr + 1
        end
      end

      win.metadata.maxvalue=max
    end

    local function spell_tooltip(win, id, label, tooltip)
      local player=Skada:find_player(win:get_selected_set(), spellsmod.playerid)
      if player then
        local spell=player. healingspells[label]
        if spell then
          tooltip:AddLine(player.name.." - "..label)
          if spell.max and spell.min then
            tooltip:AddDoubleLine(L["Minimum hit:"], Skada:FormatNumber(spell.min), 255,255,255,255,255,255)
            tooltip:AddDoubleLine(L["Maximum hit:"], Skada:FormatNumber(spell.max), 255,255,255,255,255,255)
          end
          tooltip:AddDoubleLine(L["Average hit:"], Skada:FormatNumber(spell.healing/spell.hits), 255,255,255,255,255,255)
          if spell.hits then
            tooltip:AddDoubleLine(L["Critical"]..":", ("%02.1f%%"):format(spell.critical/spell.hits*100), 255,255,255,255,255,255)
          end
          if spell.hits then
            tooltip:AddDoubleLine(L["Overhealing"]..":", ("%02.1f%%"):format(spell.overhealing/(spell.overhealing + spell.healing)*100), 255,255,255,255,255,255)
          end
        end
      end
    end

    function spellsmod:Enter(win, id, label)
      spellsmod.playerid=id
      spellsmod.title=format(L["%s's healing"], label)
    end

    -- Spell view of a player.
    function spellsmod:Update(win, set)
      -- View spells for this player.

      local player=Skada:find_player(set, self.playerid)
      local nr=1
      local max=0

      if player then

        for spellname, spell in pairs(player.healingspells) do

          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=spell.id
          d.spellid=spell.id
          d.label=spell.name
          d.value=spell.healing
          d.valuetext=Skada:FormatValueText(
          Skada:FormatNumber(spell.healing), self.metadata.columns.Healing,
          format("%02.1f%%", spell.healing/player.healing*100), self.metadata.columns.Percent
          )
          d.icon=select(3, GetSpellInfo(spell.id))

          if spell.healing>max then
            max=spell.healing
          end

          nr=nr + 1
        end
      end

      win.metadata.maxvalue=max
    end

    function healedmod:Enter(win, id, label)
      healedmod.playerid=id
      healedmod.title=format(L["Healed by %s"], label)
    end

    -- Healed players view of a player.
    function healedmod:Update(win, set)
      local player=Skada:find_player(set, healedmod.playerid)
      local nr=1
      local max=0

      if player then
        for name, heal in pairs(player.healed) do
          if heal.amount>0 then

            local d=win.dataset[nr] or {}
            win.dataset[nr]=d

            d.id=name
            d.label=name
            d.value=heal.amount
            d.class=heal.class
            d.valuetext=Skada:FormatValueText(
            Skada:FormatNumber(heal.amount), self.metadata.columns.Healing,
            format("%02.1f%%", heal.amount/player.healing*100), self.metadata.columns.Percent
            )
            if heal.amount>max then
              max=heal.amount
            end

            nr=nr + 1
          end
        end
      end

      win.metadata.maxvalue=max
    end

    function mod:OnEnable()
      mod.metadata={showspots=true, click1=spellsmod, click2=healedmod, columns={Healing=true, HPS=true, Percent=true}}
      spellsmod.metadata={tooltip=spell_tooltip, columns={Healing=true, Percent=true}}
      healedmod.metadata={showspots=true, columns={Healing=true, Percent=true}}

      Skada:RegisterForCL(SpellHeal, 'SPELL_HEAL', {src_is_interesting=true})
      Skada:RegisterForCL(SpellHeal, 'SPELL_PERIODIC_HEAL', {src_is_interesting=true})

      Skada:AddMode(self, L["Absorbs and healing"])
    end

    function mod:OnDisable()
      Skada:RemoveMode(self)
    end

    function mod:AddToTooltip(set, tooltip)
      local endtime=set.endtime
      if not endtime then
        endtime=time()
      end
      local raidhps=set.healing/(endtime - set.starttime + 1)
      GameTooltip:AddDoubleLine(L["HPS"], ("%02.1f"):format(raidhps), 1,1,1)
    end

    function mod:GetSetSummary(set)
      return Skada:FormatNumber(set.healing)
    end

    -- Called by Skada when a new player is added to a set.
    function mod:AddPlayerAttributes(player)
      if not player.healed then
        player.healed={}      -- Stored healing per recipient
      end
      if not player.healing then
        player.healing=0      -- Total healing
        player.healingspells={} -- Healing spells
        player.overhealing=0    -- Overheal total
      end
    end

    -- Called by Skada when a new set is created.
    function mod:AddSetAttributes(set)
      if not set.healing then
        set.healing=0
        set.overhealing=0
      end
    end
  end)
end

-- ==================== --
-- Total Healing Module
-- ==================== --
do
  local modname="Total healing"
  Skada:AddLoadableModule(modname, nil, function(Skada, L)
    -- requires the healing module
    if Skada.db.profile.modulesBlocked[healingmod] then return end
    if Skada.db.profile.modulesBlocked[modname] then return end
    
    local mod=Skada:NewModule(L[modname])

    function mod:GetSetSummary(set)
      return Skada:FormatNumber(set.healing + set.overhealing)
    end

    local function sort_by_healing(a, b)
      return a.healing>b.healing
    end

    local green={r=0, g=255, b=0, a=1}
    local red={r=255, g=0, b=0, a=1}

    function mod:Update(win, set)
      -- Calculate the highest total healing.
      -- How to get rid of this iteration?
      local maxvalue=0
      for i, player in ipairs(set.players) do
        if player.healing + player.overhealing>maxvalue then
          maxvalue=player.healing + player.overhealing
        end
      end

      local nr=1
      local max=0

      for i, player in ipairs(set.players) do
        if player.healing>0 or player.overhealing>0 then

          local mypercent=(player.healing + player.overhealing)/maxvalue

          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=player.id
          d.value=player.healing
          d.label=player.name
          d.valuetext=Skada:FormatNumber(player.healing).."/"..Skada:FormatNumber(player.overhealing)
          d.color=green
          d.backgroundcolor=red
          d.backgroundwidth=mypercent

          if player.healing + player.overhealing>max then
            max=player.healing + player.overhealing
          end

          nr=nr + 1
        end
      end

      win.metadata.maxvalue=max
    end

    function mod:OnEnable()
      mod.metadata={showspots=true}
      Skada:AddMode(self, L["Absorbs and healing"])
    end

    function mod:OnDisable()
      Skada:RemoveMode(self)
    end
  end)
end

-- ================== --
-- Overhealing Module
-- ================== --
do
  local modname="Overhealing"
  Skada:AddLoadableModule(modname, nil, function(Skada, L)
    -- requires the healing module
    if Skada.db.profile.modulesBlocked[healingmod] then return end
    if Skada.db.profile.modulesBlocked[modname] then return end

    local mod=Skada:NewModule(L[modname])

    function mod:Update(win, set)
      local nr=1
      local max=0

      for i, player in ipairs(set.players) do
        if player.overhealing>0 then

          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=player.id
          d.value=player.overhealing
          d.label=player.name

          d.valuetext=Skada:FormatValueText(
            Skada:FormatNumber(player.overhealing), self.metadata.columns.Overheal,
            format("%02.1f%%", player.overhealing/set.overhealing*100), self.metadata.columns.Percent
          )
          d.class=player.class
          d.role=player.role

          if player.overhealing>max then
            max=player.overhealing
          end
          nr=nr + 1
        end
      end

      win.metadata.maxvalue=max
    end

    function mod:OnEnable()
      mod.metadata={showspots=true, columns={Overheal=true, Percent=true}}

      Skada:AddMode(self, L["Absorbs and healing"])
    end

    function mod:OnDisable()
      Skada:RemoveMode(self)
    end

    function mod:GetSetSummary(set)
      return Skada:FormatNumber(set.overhealing)
    end
  end)
end
