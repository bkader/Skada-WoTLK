local Skada=Skada
if not Skada then return end

local LibFail=LibStub("LibFail-1.0", true)
if not LibFail then return end

local pairs, ipairs, select=pairs, ipairs, select
local tostring, format=tostring, string.format
local GetSpellInfo=GetSpellInfo
local UnitGUID=UnitGUID

local modname="Fails"
Skada:AddLoadableModule(modname, nil, function(Skada, L)
  if Skada.db.profile.modulesBlocked[modname] then return end

  local mod=Skada:NewModule(L[modname])
  local playermod=mod:NewModule(L["Player's failed events"])
  local spellmod=mod:NewModule(L["Event's failed players"])

  local failevents=LibFail:GetSupportedEvents()

  local function onFail(event, who, fatal)
    if event and who then
      local unitGUID=UnitGUID(who)
      
      -- add to current set
      if Skada.current then
        local player=Skada:find_player(Skada.current, unitGUID, who)
        if not player then return end

        player.fails.count=player.fails.count+1
        Skada.current.fails=Skada.current.fails+1

        if not player.fails.events[event] then
          player.fails.events[event]={id=LibFail:GetEventSpellId(event) or event, count=0}
        end
        player.fails.events[event].count=player.fails.events[event].count+1
      end

      -- add to total
      if Skada.total then
        local player=Skada:find_player(Skada.total, unitGUID, who)
        if not player then return end

        player.fails.count=player.fails.count+1
        Skada.total.fails=Skada.total.fails+1

        if not player.fails.events[event] then
          player.fails.events[event]={id=LibFail:GetEventSpellId(event) or event, count=0}
        end
        player.fails.events[event].count=player.fails.events[event].count+1
      end
    end
  end

  function playermod:Enter(win, id, label)
    self.playerid=id
    self.title=format(L["%s's fails"], label)
  end

  function playermod:Update(win, set)
    local player=Skada:find_player(set, self.playerid)
    local max=0

    if player then
      local nr=1

      for name, event in pairs(player.fails.events) do
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=name
        d.value=event.count
        d.valuetext=tostring(event.count)

        local spellname, _, spellicon=GetSpellInfo(event.id)
        if spellname then
          d.spellid=event.id
          d.label=spellname
          d.icon=spellicon
        else
          d.label=event
        end

        if event.count>max then
          max=event.count
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function spellmod:Enter(win, id, label)
    self.failid=id
    self.title=format(L["%s's fails"], label)
  end

  function spellmod:Update(win, set)
    local nr, max=1, 0

    for i, player in ipairs(set.players) do
      if player.fails.count>0 and player.fails.events[self.failid] then
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=self.failid.."_"..player.name
        d.label=player.name
        d.class=player.class
        d.role=player.role

        local count=player.fails.events[self.failid].count
        d.value=count
        d.valuetext=tostring(count)

        if count>max then
          max=count
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:Update(win, set)
    local nr, max=1, 0

    for i, player in ipairs(set.players) do
      if player.fails.count>0 then
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id=player.id
        d.label=player.name
        d.class=player.class
        d.role=player.role

        d.value=player.fails.count
        d.valuetext=tostring(player.fails.count)

        if player.fails.count>max then
          max=player.fails.count
        end

        nr=nr+1
      end
    end

    win.metadata.maxvalue=max
  end

  function mod:OnEnable()
    for _, event in ipairs(failevents) do
      LibFail:RegisterCallback(event, onFail)
    end

    mod.metadata={showspots=true, ordersort=true, click1=playermod}
    playermod.metadata={showspots=true, click1=spellmod}

    Skada:AddMode(self)
  end

  function mod:OnDisable()
    Skada:RemoveMode(self)
  end

  function mod:GetSetSummary(set)
    return set.fails
  end

  function mod:AddToTooltip(set, tooltip)
    GameTooltip:AddDoubleLine(L["Fails"], set.fails, 1, 1, 1)
  end

  function mod:AddPlayerAttributes(player)
    if not player.fails then
      player.fails={count=0, events={}}
    end
  end

  function mod:AddSetAttributes(set)
    set.fails=set.fails or 0
  end

  function mod:SetComplete(set)
    for i, player in ipairs(set.players) do
      if player.fails==0 then
        player.fails.events=nil
      end
    end
  end
end)
