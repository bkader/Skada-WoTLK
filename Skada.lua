local Skada=LibStub("AceAddon-3.0"):NewAddon("Skada", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
_G.Skada=Skada

local L=LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local ACD=LibStub("AceConfigDialog-3.0")
local LDB=LibStub:GetLibrary("LibDataBroker-1.1")
local ICON=LibStub("LibDBIcon-1.0", true)
local LSM=LibStub("LibSharedMedia-3.0")
local BOSS=LibStub("LibBossIDs-1.0")
local AceConfig=LibStub("AceConfig-3.0")

local dataobj=LDB:NewDataObject("Skada", {label="Skada", type="data source", icon="Interface\\Icons\\Spell_Lightning_LightningBolt01", text="n/a"})

-- Keybindings
BINDING_HEADER_Skada="Skada"
BINDING_NAME_SKADA_TOGGLE=L["Toggle window"]
BINDING_NAME_SKADA_RESET=L["Reset"]
BINDING_NAME_SKADA_NEWSEGMENT=L["Start new segment"]

-- available display types
Skada.displays={}

-- flag to check if disabled
local disabled=false

-- flag used to check if we need an update
local changed=true

-- update & tick timers
local update_timer, tick_timer

-- classe colors
Skada.classcolors=CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS

-- list of plyaers and pets
local players, pets={}, {}

-- list of feeds & selected feed
local feeds, selectedfeed={}

-- lists of modules and windows
local modes, windows={}, {}

-- flags for party, instance and ovo
local wasinparty, wasininstance, wasinpvp=false

-- cache frequently used globlas
local tsort, tinsert, tremove, tmaxn=table.sort, table.insert, table.remove, table.maxn
local next, pairs, ipairs, type=next, pairs, ipairs, type
local tonumber, tostring, format=tonumber, tostring, string.format
local band, time=bit.band, time
local GetNumPartyMembers, GetNumRaidMembers=GetNumPartyMembers, GetNumRaidMembers
local IsInInstance, UnitAffectingCombat, InCombatLockdown=IsInInstance, UnitAffectingCombat, InCombatLockdown
local UnitClass, UnitGroupRolesAssigned=UnitClass, UnitGroupRolesAssigned
local UnitIsPlayer, UnitGUID, UnitName=UnitIsPlayer, UnitGUID, UnitName
-- =================== --
-- add missing globals --
-- =================== --

local IsInParty=IsInParty or function() return GetNumPartyMembers()>0 end
local IsInRaid=IsInRaid or function() return GetNumRaidMembers()>0 end
local IsInGroup=IsInGroup or function() return IsInRaid() or IsInParty() end

-- returns the group type and count
local function GetGroupTypeAndCount()
  local t, count="player", 0

  if IsInRaid() then
    t, count="raid", GetNumRaidMembers()
  elseif IsInParty() then
    t, count="party", GetNumPartyMembers()
  end

  return t, count
end

-- ============= --
-- needed locals --
-- ============= --

local createSet, verify_set, find_mode, sort_modes
local is_in_pvp, is_solo
local IsRaidInCombat, IsRaidDead
local setPlayerActiveTimes

-- party/group

function is_in_pvp()
  local t=select(2, IsInInstance())
  return (t=="pvp" or t=="arena")
end

function is_solo()
  return (not IsInGroup())
end

function setPlayerActiveTimes(set)
  for i, player in ipairs(set.players) do
    if player.last then
      player.time=player.time+(player.last-player.first)
    end
  end
end

function Skada:PlayerActiveTime(set, player)
  local maxtime=(player.time>0) and player.time or 0
  if (not set.endtime or set.stopped) and player.first then
    maxtime=maxtime+player.last - player.first
  end
  return maxtime
end

-- utilities

function Skada:ShowPopup(str, func)
  StaticPopupDialogs["ResetSkadaDialog"]={
    -- text=str or L["Do you want to reset Skada?"],
    text=L["Do you want to reset Skada?"],
    button1=ACCEPT,
    button2=CANCEL,
    timeout=30,
    whileDead=0,
    hideOnEscape=1,
    -- OnAccept=func or function() Skada:Reset() end
    OnAccept=function() Skada:Reset() end
  }
  StaticPopup_Show("ResetSkadaDialog")
end

-- ================= --
-- WINDOWS FUNCTIONS --
-- ================= --
local Window={}
do
  local mt={__index=Window}

  -- create a new window
  function Window:new()
    return setmetatable({
      selectedmode=nil,
      selectedset=nil,
      restore_mode=nil,
      restore_set=nil,
      usealt=true,
      dataset={},
      metadata={},
      display=nil,
      history={},
      changed=false,
    }, mt)
  end

  -- add window options
  function Window:AddOptions()
    local db=self.db

    local options={
      type="group",
      name=function() return db.name end,
      args={
        rename={
          type="input",
          name=L["Rename window"],
          desc=L["Enter the name for the window."],
          order=1,
          get=function() return db.name end,
          set=function(win, val)
            if val~=db.name and val~="" then
              local oldname=db.name
              db.name=val
              Skada.options.args.windows.args[val]=Skada.options.args.windows.args[oldname]
              Skada.options.args.windows.args[oldname]=nil
            end
          end
        },

        locked={
          type="toggle",
          name=L["Lock window"],
          desc=L["Locks the bar window in place."],
          order=2,
          get=function() return db.barslocked end,
          set=function() db.barslocked=not db.barslocked; Skada:ApplySettings() end
        },

        hidden={
          type="toggle",
          name=L["Hide window"],
          desc=L["Hides the window."],
          order=3,
          get=function() return db.hidden end,
          set=function() db.hidden=not db.hidden; Skada:ApplySettings()end
        },

        display={
          type="select",
          name=L["Display system"],
          desc=L["Choose the system to be used for displaying data in this window."],
          order=4,
          values= function()
            local list={}
            for name, display in pairs(Skada.displays) do
              list[name]=display.name
            end
            return list
          end,
          get=function() return db.display end,
          set=function(i, display) self:SetDisplay(display) end
        }
      }
    }

    options.args.switchoptions={
      type="group",
      name=L["Mode switching"],
      order=4,
      args={

        modeincombat={
          type="select",
          name=L["Combat mode"],
          desc=L["Automatically switch to set 'Current' and this mode when entering combat."],
          order=21,
          values= function()
            local modes={}
            modes[""]=L["None"]
            for i, mode in ipairs(Skada:GetModes()) do
              modes[mode:GetName()]=mode:GetName()
            end
            return modes
          end,
          get=function() return db.modeincombat end,
          set=function(win, mode) db.modeincombat=mode end
        },

        returnaftercombat={
          type="toggle",
          name=L["Return after combat"],
          desc=L["Return to the previous set and mode after combat ends."],
          order=22,
          get=function() return db.returnaftercombat end,
          set=function() db.returnaftercombat=not db.returnaftercombat end,
          disabled=function() return db.returnaftercombat==nil end
        },

        wipemode={
          type="select",
          name=L["Wipe mode"],
          desc=L["Automatically switch to set 'Current' and this mode after a wipe."],
          order=23,
          values=function()
            local modes={}
            modes[""]=L["None"]
            for i, mode in ipairs(Skada:GetModes()) do
              modes[mode:GetName()]=mode:GetName()
            end
            return modes
          end,
          get=function() return db.wipemode end,
          set=function(win, mode) db.wipemode=mode end
        }
      }
    }

    self.display:AddDisplayOptions(self, options.args)
    Skada.options.args.windows.args[self.db.name]=options
  end

  -- destroy a window
  function Window:destroy()
    self.dataset=nil
    self.display:Destroy(self)

    local name=self.db.name or Skada.windowdefaults.name
    Skada.options.args.windows.args[name]=nil
  end

  function Window:set_mode_title()
    if not self.selectedmode or not self.selectedset then return end
    if not self.selectedmode.GetName then return end
    local name=self.selectedmode.title or self.selectedmode:GetName()

    -- save window settings for RestoreView after reload
    self.db.set=self.selectedset
    local savemode=name
    if self.history[1] then -- can't currently preserve a nested mode, use topmost one
      savemode=self.history[1].title or self.history[1]:GetName()
    end
    self.db.mode=savemode

    if self.db.titleset then
      local setname
      if self.selectedset=="current" then
        setname=L["Current"]
      elseif self.selectedset=="total" then
        setname=L["Total"]
      else
        local set=self:get_selected_set()
        if set then
          setname=Skada:GetSetLabel(set)
        end
      end
      if setname then
        name=name..": "..setname
      end
    end
    if disabled and (self.selectedset=="current" or self.selectedset=="total") then
      -- indicate when data collection is disabled
      name=name.."  |cFFFF0000"..L["DISABLED"].."|r"
    end
    self.metadata.title=name
    self.display:SetTitle(self, name)
  end

  -- change window display
  function Window:SetDisplay(name)
    if name~=self.db.display or self.display==nil then
      if self.display then
        self.display:Destroy(self)
      end

      self.db.display=name
      self.display=Skada.displays[self.db.display]
      self:AddOptions()
    end
  end

  -- tell window to update the display of its dataset, using its display provider.
  function Window:UpdateDisplay()
    if not self.metadata.maxvalue then
      self.metadata.maxvalue=0
      for i, data in ipairs(self.dataset) do
        if data.id and data.value>self.metadata.maxvalue then
          self.metadata.maxvalue=data.value
        end
      end
    end

    self.display:Update(self)
    self:set_mode_title()
  end

  -- called before dataset is updated.
  function Window:UpdateInProgress()
    for i, data in ipairs(self.dataset) do
      if data.ignore then
        data.icon=nil
      end
      data.id=nil
      data.ignore=nil
    end
  end

  function Window:Show()
    self.display:Show(self)
  end

  function Window:Hide()
    self.display:Hide(self)
  end

  function Window:IsShown()
    return self.display:IsShown(self)
  end

  function Window:Reset()
    for i, data in ipairs(self.dataset) do
      wipe(data)
    end
  end

  function Window:Wipe()
    self:Reset()
    self.display:Wipe(self)
  end

  function Window:get_selected_set()
    return Skada:find_set(self.selectedset)
  end

  function Window:DisplayMode(mode)
    if type(mode)~="table" then return end
    self:Wipe()

    self.selectedplayer=nil
    self.selectedspell=nil
    self.selectedmode=mode

    self.metadata={}

    if mode.metadata then
      for key, value in pairs(mode.metadata) do
        self.metadata[key]=value
      end
    end

    self.changed=true
    self:set_mode_title()
    Skada:UpdateDisplay(false)
  end

  do
    function sort_modes()
      tsort(modes, function(a, b)
        if Skada.db.profile.sortmodesbyusage and Skada.db.profile.modeclicks then
          return (Skada.db.profile.modeclicks[a:GetName()] or 0)>(Skada.db.profile.modeclicks[b:GetName()] or 0)
        else
          return a:GetName()<b:GetName()
        end
      end)
    end

    local function click_on_mode(win, id, label, button)
      if button=="LeftButton" then
        local mode=find_mode(id)
        if mode then
          if Skada.db.profile.sortmodesbyusage then
            Skada.db.profile.modeclicks=Skada.db.profile.modeclicks or {}
            Skada.db.profile.modeclicks[id]=(Skada.db.profile.modeclicks[id] or 0)+1
            sort_modes()
          end
          win:DisplayMode(mode)
        end
      elseif button=="RightButton" then
        win:RightClick()
      end
    end

    function Window:DisplayModes(settime)
      self.history={}
      self:Wipe()

      self.selectedplayer=nil
      self.selectedmode=nil

      self.metadata={}
      self.metadata.title=L["Skada: Modes"]

      self.db.set=settime

      if settime=="current" or settime=="total" then
        self.selectedset=settime
      else
        for i, set in ipairs(Skada.char.sets) do
          if tostring(set.starttime)==settime then
            if set.name==L["Current"] then
              self.selectedset="current"
            elseif set.name==L["Total"] then
              self.selectedset="total"
            else
              self.selectedset=i
            end
          end
        end
      end

      self.metadata.click=click_on_mode
      self.metadata.maxvalue=1
      self.metadata.sortfunc=function(a,b) return a.name<b.name end

      self.display:SetTitle(self, self.metadata.title)
      self.changed=true

      Skada:UpdateDisplay(false)
    end
  end

  do
    local function click_on_set(win, id, label, button)
      if button=="LeftButton" then
        win:DisplayModes(id)
      elseif button=="RightButton" then
        win:RightClick()
      end
    end

    function Window:DisplaySets()
      self.history={}
      self:Wipe()

      self.selectedplayer=nil
      self.selectedmode=nil
      self.selectedset=nil

      self.metadata={}
      self.metadata.title=L["Skada: Fights"]
      self.display:SetTitle(self, self.metadata.title)

      self.metadata.click=click_on_set
      self.metadata.maxvalue=1
      self.changed=true
      Skada:UpdateDisplay(false)
    end
  end

  function Window:RightClick(group, button)
    if self.selectedmode then
      if #self.history>0 then
        self:DisplayMode(tremove(self.history))
      else
        self:DisplayModes(self.selectedset)
      end
    elseif self.selectedset then
      self:DisplaySets()
    end
  end

  -- ================================================== --

  function Skada:GetWindows()
    return windows
  end

  function Skada:tcopy(to, from)
    for k,v in pairs(from) do
      if(type(v)=="table") then
        to[k]={}
        self:tcopy(to[k], v);
      else
        to[k]=v;
      end
    end
  end

  function Skada:CreateWindow(name, db, display)
    local isnew=false
    if not db then
      db, isnew={}, true
      self:tcopy(db, Skada.windowdefaults)
      tinsert(self.db.profile.windows, db)
    end

    if display then db.display=display end

    if not db.barbgcolor then
      db.barbgcolor={r=0.3, g=0.3, b=0.3, a=0.6}
    end

    if not db.buttons then
      db.buttons={menu=true, reset=true, report=true, mode=true, segment=true, stop=true}
    end

    local window=Window:new()
    window.db=db
    window.db.name=name

    if self.displays[window.db.display] then
      window:SetDisplay(window.db.display or "bar")
      window.display:Create(window)
      tinsert(windows, window)
      window:DisplaySets()

      if isnew and find_mode(L["Damage"]) then
        self:RestoreView(window, "current", L["Damage"])
      elseif window.db.set or window.db.mode then
        self:RestoreView(window, window.db.set, window.db.mode)
      end
    end

    self:ApplySettings()
  end


  function Skada:DeleteWindow(name)
    for i, win in ipairs(windows) do
      if win.db.name==name then
        win:destroy()
        wipe(tremove(windows, i))
      end
    end

    for i, win in ipairs(self.db.profile.windows) do
      if win.name==name then
        tremove(self.db.profile.windows, i)
      end
    end
  end

  function Skada:ToggleWindow()
    for i, win in ipairs(windows) do
      if win:IsShown() then
        win.db.hidden=true
        win:Hide()
      else
        win.db.hidden=false
        win:Show()
      end
    end
  end

  function Skada:RestoreView(win, theset, themode)
    if theset and type(theset)=="string" and (theset=="current" or theset=="total" or theset=="last") then
      win.selectedset=theset
    elseif theset and type(theset)=="number" and theset <= #self.char.sets then
      win.selectedset=theset
    else
      win.selectedset="current"
    end

    changed=true

    if themode then
      win:DisplayMode(find_mode(themode) or win.selectedset)
    else
      win:DisplayModes(win.selectedset)
    end
  end

  function Skada:Wipe()
    for i, win in ipairs(windows) do
      win:Wipe()
    end
  end

  function Skada:SetActive(enable)
    if enable then
      for i, win in ipairs(windows) do
        win:Show()
      end
    else
      for i, win in ipairs(windows) do
        win:Hide()
      end
    end

    if not enable and self.db.profile.hidedisables then
      disabled=true
      self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
      disabled=false
      self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatLogEvent")
    end

    self:UpdateDisplay(true)
  end
end

-- =============== --
-- MODES FUNCTIONS --
-- =============== --

function find_mode(name)
  for i, mode in ipairs(modes) do
    if mode:GetName()==name then
      return mode
    end
  end
end

do
  local function scan_for_columns(mode)
    if not mode.scanned then
      mode.scanned=true

      if not mode.metadata then return end

      if mode.metadata.columns then
        Skada:AddColumnOptions(mode)
      end

      if mode.metadata.click1 then
        scan_for_columns(mode.metadata.click1)
      end
      if mode.metadata.click2 then
        scan_for_columns(mode.metadata.click2)
      end
      if mode.metadata.click3 then
        scan_for_columns(mode.metadata.click3)
      end
    end
  end

  function Skada:AddMode(mode, category)
    if self.total then
      verify_set(mode, self.total)
    end

    if self.current then
      verify_set(mode, self.current)
    end

    for i, set in ipairs(self.char.sets) do
      verify_set(mode, set)
    end

    tinsert(modes, mode)
    mode.category=category or OTHER

    for i, win in ipairs(windows) do
      if mode:GetName()==win.db.mode then
        self:RestoreView(win, win.db.set, mode:GetName())
      end
    end

    if selectedfeed==nil and self.db.profile.feed~="" then
      for name, feed in pairs(feeds) do
        if name==self.db.profile.feed then
          self:SetFeed(feed)
        end
      end
    end

    scan_for_columns(mode)
    sort_modes()

    for i, win in ipairs(windows) do
      win:Wipe()
    end

    changed=true
  end
end

function Skada:RemoveMode(mode)
  tremove(modes, mode)
end

function Skada:GetModes()
  return modes
end

function Skada:AddLoadableModule(name, description, func)
  self.modulelist=self.modulelist or {}
  self.modulelist[#self.modulelist+1]=func
  self:AddLoadableModuleCheckbox(name, L[name], description and L[description])
end

do
  local numorder=5

  function Skada:AddDisplaySystem(key, mod)
    self.displays[key]=mod
    if mod.description then
      Skada.options.args.windows.args[key.."desc"]={
        type="description",
        name=mod.description,
        order=numorder
      }
      numorder=numorder+1
    end
  end
end

-- =============== --
-- SETS FUNCTIONS --
-- =============== --

function createSet(setname)
  local set={players={}, name=setname, starttime=time(), last_action=time(), time=0}
  for i, mode in ipairs(modes) do verify_set(mode, set) end
  return set
end

function verify_set(mode, set)
  if mode.AddSetAttributes then
    mode:AddSetAttributes(set)
  end

  for i, player in ipairs(set.players) do
    if mode.AddPlayerAttributes then
      mode:AddPlayerAttributes(player)
    end
  end
end

function Skada:get_sets()
  return self.char.sets
end

function Skada:find_set(s)
  if s=="current" then
    if self.current~=nil then
      return self.current
    elseif self.last~=nil then
      return self.last
    else
      return self.char.sets[1]
    end
  elseif s=="total" then
    return self.total
  else
    return self.char.sets[s]
  end
end

function Skada:DeleteSet(set)
  if not set then return end

  for i, s in ipairs(self.char.sets) do
    if s==set then
      wipe(tremove(self.char.sets, i))

      if set==self.last then
        self.last=nil
      end

      -- Don't leave windows pointing to deleted sets
      for _, win in ipairs(windows) do
        if win.selectedset==i or win:get_selected_set()==set then
          win.selectedset="current"
          win.changed=true
        elseif (tonumber(win.selectedset) or 0)>i then
          win.selectedset=win.selectedset-1
          win.changed=true
        end
      end
      break
    end
  end

  self:Wipe()
  self:UpdateDisplay(true)
end

function Skada:GetSetTime(set)
  return set.time and set.time or (time()-set.starttime)
end

-- ================ --
-- GETTER FUNCTIONS --
-- ================ --

function Skada:ClearIndexes(set)
  if set then
    set._playeridx=nil
  end
end

function Skada:ClearAllIndexes()
  Skada:ClearIndexes(self.current)
  Skada:ClearIndexes(self.char.total)
  for _,set in pairs(self.char.sets) do
    Skada:ClearIndexes(set)
  end
end

function Skada:find_player(set, playerid)
  if set then
    set._playeridx=set._playeridx or {}
    local player=set._playeridx[playerid]
    if player then return player end

    for i, p in ipairs(set.players) do
      if p.id==playerid then
        set._playeridx[playerid]=p
        return p
      end
    end
  end
end

function Skada:get_player(set, playerid, playername)
  local player=self:find_player(set, playerid)

  if not player then
    if not playername then return end

    local playerClass=select(2, UnitClass(playername))
    local playerRole=UnitGroupRolesAssigned(playername)
    player={
      id=playerid,
      class=playerClass,
      role=playerRole or "NONE",
      name=playername,
      first=time(),
      time=0
    }

    for i, mode in ipairs(modes) do
      if mode.AddPlayerAttributes~=nil then
        mode:AddPlayerAttributes(player)
      end
    end

    tinsert(set.players, player)
  end

  player.first=player.first or time()
  player.last=time()
  changed=true
  return player
end

function Skada:IsBoss(GUID)
  return GUID and BOSS.BossIDs[tonumber(GUID:sub(9, 12), 16)]
end

-- ================== --
-- FIX PETS FUNCTIONS --
-- ================== --

function Skada:FixPets(action)

  if not action then return end
  if not action.playerid and not action.srcGUID then return end
  if not action.playername and not action.srcName then return end

  action.playerid=action.playerid or action.srcGUID
  action.playername=action.playername or action.srcName
  action.playerflags=action.playerflags or action.srcFlags

  local pet=pets[action.playerid]
  if pet then

    if self.db.profile.mergepets then
      if action.spellname then
        action.spellname=action.playername..": "..action.spellname
      end
      action.playerid=pet.id
      action.playername=pet.name
    else
      local petMobID=action.playerid:sub(6, 10)
      action.playerid=pet.id..petMobID
      action.playername=pet.name..": "..action.playername
    end
  else
    if action.playerflags and band(action.playerflags, COMBATLOG_OBJECT_TYPE_GUARDIAN)~=0 then
      if band(action.playerflags, COMBATLOG_OBJECT_AFFILIATION_MINE)~=0 then
        if action.spellname then
          action.spellname=action.playername..": "..action.spellname
        end
        action.playername=UnitName("player")
        action.playerid=UnitGUID("player")
      else
        action.playerid=action.playername
      end
    end
  end

  -- if not UnitIsPlayer(action.playername) then

  --   if not pets[action.playerid] then
  --     if action.playerflags and band(action.playerflags, COMBATLOG_OBJECT_TYPE_GUARDIAN)~=0 then
  --       if band(action.playerflags, COMBATLOG_OBJECT_AFFILIATION_MINE)~=0 then
  --         if action.spellname then
  --           action.spellname=action.playername..": "..action.spellname
  --         end
  --         action.playername=UnitName("player")
  --         action.playerid=UnitGUID("player")
  --       else
  --         action.playerid=action.playername
  --       end
  --     end
  --   end

  --   local pet=pets[action.playerid]
  --   if pet then
  --     if action.spellname then
  --       action.spellname=action.playername..": "..action.spellname
  --     end
  --     action.playername=pet.name
  --     action.playerid=pet.id
  --   end
  -- end
end

function Skada:FixMyPets(playerGUID, playerName)
  local pet=pets[playerGUID]
  if pet then
    return pet.id, pet.name
  end

  return playerGUID, playerName
end

function Skada:PetDebug()
  self:CheckGroup()
  self:Print("pets:")
  for pet, owner in pairs(pets) do
    self:Print("pet "..pet.." belongs to ".. owner.id..", "..owner.name)
  end
end

-- ================= --
-- TOOLTIP FUNCTIONS --
-- ================= --

function Skada:SetTooltipPosition(tooltip, frame)
  local p=self.db.profile.tooltippos
  if p=="default" then
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -40, 40);
  elseif p=="topleft" then
    tooltip:SetOwner(frame, "ANCHOR_NONE")
    tooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT")
  elseif p=="topright" then
    tooltip:SetOwner(frame, "ANCHOR_NONE")
    tooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT")
  elseif p=="smart" and frame then
    if frame:GetLeft()<(GetScreenWidth()/2) then
      tooltip:SetOwner(frame, "ANCHOR_NONE")
      tooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT", 10, 0)
    else
      tooltip:SetOwner(frame, "ANCHOR_NONE")
      tooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT", -10, 0)
    end
  end
end

do
  local function value_sort(a, b)
    if not a or a.value==nil then
      return false
    elseif not b or b.value==nil then
      return true
    else
      return a.value>b.value
    end
  end

  function Skada.valueid_sort(a, b)
    if not a or a.value==nil or a.id==nil then
      return false
    elseif not b or b.value==nil or b.id==nil then
      return true
    else
      return a.value>b.value
    end
  end

  local ttwin=Window:new()
  
  function Skada:AddSubviewToTooltip(tooltip, win, mode, id, label)
    wipe(ttwin.dataset)

    if mode.Enter then
      mode:Enter(win, id, label)
    end

    mode:Update(ttwin, win:get_selected_set())

    if not mode.metadata or not mode.metadata.ordersort then
      tsort(ttwin.dataset, value_sort)
    end

    if #ttwin.dataset>0 then
      tooltip:AddLine(mode.title or mode:GetName(), 1,1,1)
      local nr=0

      for i, data in ipairs(ttwin.dataset) do
        if data.id and nr<Skada.db.profile.tooltiprows then
          nr=nr+1
          local color={r=1, g=1, b=1}

          if data.color then
            color=data.color
          elseif data.class then
            local color=Skada.classcolors[data.class]
          end
          tooltip:AddDoubleLine(nr..". "..data.label, data.valuetext, color.r, color.g, color.b)
        end
      end

      tooltip:AddLine(" ")
    end
  end
end

function Skada:ShowTooltip(win, id, label)
  local t=GameTooltip

  if Skada.db.profile.tooltips then
    if win.metadata.is_modelist and Skada.db.profile.informativetooltips then
      t:ClearLines()
      Skada:AddSubviewToTooltip(t, win, find_mode(id), id, label)
      t:Show()

    elseif win.metadata.click1 or win.metadata.click2 or win.metadata.click3 or win.metadata.tooltip then
      t:ClearLines()
      local hasClick=win.metadata.click1 or win.metadata.click2 or win.metadata.click3

      if win.metadata.tooltip then
        local numLines=t:NumLines()
        win.metadata.tooltip(win, id, label, t)

        if t:NumLines()~=numLines and hasClick then
          t:AddLine(" ")
        end
      end

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

      if win.metadata.post_tooltip then
        local numLines=t:NumLines()
        win.metadata.post_tooltip(win, id, label, t)

        if t:NumLines()~=numLines and hasClick then
          t:AddLine(" ")
        end
      end

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
end

-- ============== --
-- SLACH COMMANDS --
-- ============== --

function Skada:Command(param)
  if param=="pets" then
    self:PetDebug()
  elseif param=="test" then
    Skada:Notify("test")
  elseif param=="reset" then
    self:Reset()
  elseif param=="newsegment" then
    self:NewSegment()
  elseif param=="toggle" then
    self:ToggleWindow()
  elseif param=="config" then
    self:OpenOptions()
  elseif param:sub(1,6)=="report" then
    param=param:sub(7)

    local w1, w2, w3, w4=self:GetArgs(param, 4)

    local chan=w1 or "say"
    local report_mode_name=w2 or L["Damage"]
    local max=tonumber(w3 or 10)
    local chantype="preset"

    -- Sanity checks.
    if chan and (chan=="say" or chan=="guild" or chan=="raid" or chan=="party" or chan=="officer") and (report_mode_name and find_mode(report_mode_name)) then
      self:Report(chan, "preset", report_mode_name, "current", max)
    else
      self:Print("Usage:")
      self:Print(format("%-20s", "/skada report [raid|guild|party|officer|say] [mode] [max lines]"))
    end
  else
    self:Print("Usage:")
    self:Print(format("%-20s", "/skada report [raid|guild|party|officer|say] [mode] [max lines]"))
    self:Print(format("%-20s", "/skada reset"))
    self:Print(format("%-20s", "/skada toggle"))
    self:Print(format("%-20s", "/skada newsegment"))
    self:Print(format("%-20s", "/skada config"))
  end
end

-- =============== --
-- REPORT FUNCTION --
-- =============== --
do
  local SendChatMessage=SendChatMessage
  if ChatThrottleLib and ChatThrottleLib.SendChatMessage then
    SendChatMessage=function(...)
      ChatThrottleLib:SendChatMessage("BULK", "Skada", ...)
    end
  end

  local function escapestr(str)
    local newstr=""
    for i=1, str:len() do
      local n=str:sub(i, i)
      newstr=newstr .. n
      if n=="|" then
        newstr=newstr .. n
      end
    end
    return (newstr~="") and newstr or str
  end

  local function sendchat(msg, chan, chantype)
    msg=escapestr(msg)

    if chantype=="self" then
      Skada:Print(msg)
    elseif chantype=="channel" then
      SendChatMessage(msg, "CHANNEL", nil, chan)
    elseif chantype=="preset" then
      SendChatMessage(msg, string.upper(chan))
    elseif chantype=="whisper" then
      SendChatMessage(msg, "WHISPER", nil, chan)
    elseif chantype == "bnet" then
      BNSendWhisper(chan, msg)
    end
  end

  function Skada:Report(channel, chantype, report_mode_name, report_set_name, max, window)
    if chantype=="channel" then
      local list={GetChannelList()}
      for i=1,table.getn(list)/2 do
        if(self.db.profile.report.channel==list[i*2]) then
          channel=list[i*2-1]
          break
        end
      end
    end

    local report_table, report_set, report_mode

    if not window then
      report_mode=find_mode(report_mode_name)
      report_set=self:find_set(report_set_name)
      if report_set==nil then
        return
      end

      report_table=Window:new()
      report_mode:Update(report_table, report_set)
    else
      report_table=window
      report_set=window:get_selected_set()
      report_mode=window.selectedmode
    end

    if not report_set then
      Skada:Print(L["There is nothing to report."])
      return
    end

    if not report_table.metadata.ordersort then
      tsort(report_table.dataset, Skada.valueid_sort)
    end

    local endtime=report_set.endtime or time()

    if not report_mode then
      self:Print(L["No mode or segment selected for report."])
      return
    end

    sendchat(format(L["Skada: %s for %s:"], report_mode.title or report_mode:GetName(), Skada:GetSetLabel(report_set)), channel, chantype)

    local nr=1
    for i, data in ipairs(report_table.dataset) do
      if data.id then
        if report_mode.metadata and report_mode.metadata.showspots then
          sendchat(format("%2u. %s   %s", nr, data.label, data.valuetext), channel, chantype)
        else
          sendchat(format("%s   %s", data.label, data.valuetext), channel, chantype)
        end
        nr=nr+1
      end
      if nr>max then
        break
      end
    end
  end
end

-- ============== --
-- FEED FUNCTIONs --
-- ============== --

function Skada:SetFeed(feed)
  selectedfeed=feed
  self:UpdateDisplay()
end

function Skada:AddFeed(name, func)
  feeds[name]=func
end

function Skada:RemoveFeed(name, func)
  for i, feed in ipairs(feeds) do
    if feed.name==name then
      tremove(feeds, i)
    end
  end
end

function Skada:GetFeeds()
  return feeds
end

-- ======================================================= --

function Skada:AssignPet(ownerGUID, ownerName, petGUID)
  pets[petGUID]={id=ownerGUID, name=ownerName}
end

function Skada:GetPetOwner(petGUID)
  return pets[petGUID]
end

function Skada:CheckGroup()
  local t, count=GetGroupTypeAndCount()
  if count>0 then
    for i=1, count do
      local unit=format("%s%d", t, i)
      local unitGUID=UnitGUID(unit)
      if unitGUID then
        players[unitGUID] = true
        local petGUID=UnitGUID(unit.."pet")
        if petGUID and not pets[petGUID] then
          self:AssignPet(unitGUID, UnitName(unit), petGUID)
        end
      end
    end
  end

  -- Solo, always check.
  local unitGUID=UnitGUID("player")
  if unitGUID then
    players[unitGUID] = true
    local petGUID=UnitGUID("playerpet")
    if petGUID and not pets[petGUID] then
      self:AssignPet(unitGUID, UnitName("player"), petGUID)
    end
  end
end

function Skada:ZoneCheck()
  local inInstance, instanceType=IsInInstance()
  local isininstance=inInstance and (instanceType=="party" or instanceType=="raid")
  local isinpvp=is_in_pvp()

  if isininstance and wasininstance~=nil and not wasininstance and self.db.profile.reset.instance~=1 and total~=nil then
    if self.db.profile.reset.instance==3 then
      self:ShowPopup()
    else
      self:Reset()
    end
  end

  if self.db.profile.hidepvp then
    if is_in_pvp() then
      Skada:SetActive(false)
    elseif wasinpvp then
      Skada:SetActive(true)
    end
  end

  if isininstance then
    wasininstance=true
  else
    wasininstance=false
  end

  if isinpvp then
    wasinpvp=true
  else
    wasinpvp=false
  end
end

function Skada:PLAYER_ENTERING_WORLD()
  self:ZoneCheck()
  wasinparty=IsInGroup()
  self:CheckGroup()
end

do
  local function check_for_join_and_leave()
    if not IsInGroup() and wasinparty then
      if Skada.db.profile.reset.leave==3 and Skada:CanReset() then
        Skada:ShowPopup()
      elseif Skada.db.profile.reset.leave==2 and Skada:CanReset() then
        Skada:Reset()
      end

      if Skada.db.profile.hidesolo then
        Skada:SetActive(false)
      end
    end

    if IsInGroup() and not wasinparty then
      if Skada.db.profile.reset.join==3 and Skada:CanReset() then
        Skada:ShowPopup()
      elseif Skada.db.profile.reset.join==2 and Skada:CanReset() then
        Skada:Reset()
      end

      if Skada.db.profile.hidesolo and not (Skada.db.profile.hidepvp and is_in_pvp()) then
        Skada:SetActive(true)
      end
    end

    wasinparty=not not IsInGroup()
  end

  function Skada:PARTY_MEMBERS_CHANGED()
    check_for_join_and_leave()
    self:CheckGroup()
  end
  Skada.RAID_ROSTER_UPDATE=Skada.PARTY_MEMBERS_CHANGED
end

function Skada:UNIT_PET()
  self:CheckGroup()
end

-- ======================================================= --

function Skada:Reset()
  self:Wipe()
  players, pets={}, {}
  self:CheckGroup()
  
  if self.current~=nil then
    wipe(self.current)
    self.current=createSet(L["Current"])
  end

  if self.total~=nil then
    wipe(self.total)
    self.total=createSet(L["Total"])
    self.char.total=self.total
  end
  self.last=nil

  for i=tmaxn(self.char.sets), 1, -1 do
    if not self.char.sets[i].keep then
      wipe(tremove(self.char.sets, i))
    end
  end

  for _, win in ipairs(windows) do
    if win.selectedset~="total" then
      win.selectedset="current"
      win.changed=true
    end
  end

  dataobj.text="n/&"
  self:UpdateDisplay(true)
  self:Print(L["All data has been reset."])
  
  if not InCombatLockdown() then
    collectgarbage("collect")
  end
end

function Skada:UpdateDisplay(force)
  if force then
    changed=true
  end

  if selectedfeed~=nil then
    local feedtext=selectedfeed()
    if feedtext then
      dataobj.text=feedtext
    end
  end

  for i, win in ipairs(windows) do
    if (changed or win.changed) or self.current then
      win.changed=false

      if win.selectedmode then
        local set=win:get_selected_set()

        if set then
          win:UpdateInProgress()

          if win.selectedmode.Update then
            win.selectedmode:Update(win, set)
          elseif win.selectedmode.GetName then
            self:Print("Mode "..win.selectedmode:GetName().." does not have an Update function!")
          end

          if self.db.profile.showtotals and win.selectedmode.GetSetSummary then
            local total, existing=0
            
            for i, data in ipairs(win.dataset) do
              if data.id then
                total=total+data.value
              end
              if not existing and not data.id then
                existing=data
              end
            end
            total=total+1

            local d=existing or {}
            d.id="total"
            d.label=L["Total"]
            d.ignore=true
            d.icon=dataobj.icon
            d.value=total
            d.valuetext=win.selectedmode:GetSetSummary(set)
            if not existing then tinsert(win.dataset, 1, d) end
          end
        end

        win:UpdateDisplay()

      elseif win.selectedset then
        local set=win:get_selected_set()

        for i, mode in ipairs(modes) do
          local d=win.dataset[i] or {}
          win.dataset[i]=d

          d.id=mode:GetName()
          d.label=mode:GetName()
          d.value=1

          if set and mode.GetSetSummary~=nil then
            d.valuetext=mode:GetSetSummary(set)
          end
          if mode.metadata and mode.metadata.icon then
            d.icon=mode.metadata.icon
          end
        end

        win.metadata.ordersort=true

        if set then
          win.metadata.is_modelist=true
        end

        win:UpdateDisplay()
      else
        local nr=1
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id="total"
        d.label=L["Total"]
        d.value=1

        nr=nr+1
        local d=win.dataset[nr] or {}
        win.dataset[nr]=d

        d.id="current"
        d.label=L["Current"]
        d.value=1

        for i, set in ipairs(self.char.sets) do
          nr=nr+1
          local d=win.dataset[nr] or {}
          win.dataset[nr]=d

          d.id=tostring(set.starttime)
          d.label=set.name
          d.valuetext=date("%H:%M",set.starttime).." - "..date("%H:%M",set.endtime)
          d.value=1
          if set.keep then
            d.emphathize=true
          end
        end

        win.metadata.ordersort=true
        win:UpdateDisplay()
      end
    end
  end

  changed=false
end

-- ======================================================= --

function Skada:FormatNumber(number)
  if number then
    if self.db.profile.numberformat==1 then
      if number>1000000 then
        return format("%02.2fM", number/1000000)
      else
        return format("%02.1fK", number/1000)
      end
    else
      return math.floor(number)
    end
  end
end

function Skada:FormatValueText(...)
  local value1, bool1, value2, bool2, value3, bool3=...

  if bool1 and bool2 and bool3 then
    return value1.." ("..value2..", "..value3..")"
  elseif bool1 and bool2 then
    return value1.." ("..value2..")"
  elseif bool1 and bool3 then
    return value1.." ("..value3..")"
  elseif bool2 and bool3 then
    return value2.." ("..value3..")"
  elseif bool2 then
    return value2
  elseif bool1 then
    return value1
  elseif bool3 then
    return value3
  end
end

do
  local numsetfmts=8

  local function SetLabelFormat(name, starttime, endtime, fmt)
    fmt=fmt or Skada.db.profile.setformat
    local namelabel=name
    if fmt<1 or fmt>numsetfmts then fmt=3 end
    
    local timelabel=""
    if starttime and endtime and fmt>1 then
      local duration=SecondsToTime(endtime-starttime, false, false, 2)
      
      Skada.getsetlabel_fs=Skada.getsetlabel_fs or UIParent:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
      Skada.getsetlabel_fs:SetText(duration)
      duration="("..Skada.getsetlabel_fs:GetText()..")"

      if fmt==2 then
        timelabel=duration
      elseif fmt==3 then
        timelabel=date("%H:%M",starttime).." "..duration
      elseif fmt==4 then
        timelabel=date("%I:%M",starttime).." "..duration
      elseif fmt==5 then
        timelabel=date("%H:%M",starttime).." - "..date("%H:%M",endtime)
      elseif fmt==6 then
        timelabel=date("%I:%M",starttime).." - "..date("%I:%M",endtime)
      elseif fmt==7 then
        timelabel=date("%H:%M:%S",starttime).." - "..date("%H:%M:%S",endtime)
      elseif fmt==8 then
        timelabel=date("%H:%M",starttime).." - "..date("%H:%M",endtime).." "..duration
      end
    end

    local comb
    if #namelabel==0 or #timelabel==0 then
      comb=namelabel..timelabel
    elseif timelabel:match("^%p") then
      comb=namelabel.." "..timelabel
    else
      comb=namelabel..": "..timelabel
    end

    return comb, namelabel, timelabel
  end

  function Skada:SetLabelFormats()
    local ret, start={}, 1000007900
    for i=1,numsetfmts do
      ret[i]=SetLabelFormat("Hogger", start, start+380, i)
    end
    return ret
  end

  function Skada:GetSetLabel(set)
    if not set then return "" end
    return SetLabelFormat(set.name or "Unknown", set.starttime, set.endtime or time())
  end
end

-- ======================================================= --

function dataobj:OnEnter()
  GameTooltip:SetOwner(self, "ANCHOR_NONE")
  GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
  GameTooltip:ClearLines()

  local set
  if Skada.current then
    set=Skada.current
  else
    set=Skada.char.sets[1]
  end
  if set then
    GameTooltip:AddLine(L["Skada summary"], 0, 1, 0)
    for i, mode in ipairs(modes) do
      if mode.AddToTooltip~=nil then
        mode:AddToTooltip(set, GameTooltip)
      end
    end
  end

  GameTooltip:AddLine(L["Hint: Left-Click to toggle Skada window."], 0, 1, 0)
  GameTooltip:AddLine(L["Shift+Left-Click to reset."], 0, 1, 0)
  GameTooltip:AddLine(L["Right-click to open menu"], 0, 1, 0)

  GameTooltip:Show()
end

function dataobj:OnLeave()
  GameTooltip:Hide()
end

function dataobj:OnClick(button)
  if button=="LeftButton" and IsShiftKeyDown() then
    Skada:Reset()
  elseif button=="LeftButton" then
    Skada:ToggleWindow()
  elseif button=="RightButton" then
    Skada:OpenMenu()
  end
end


function Skada:OpenOptions()
  InterfaceOptionsFrame_OpenToCategory("Skada")
end

function Skada:RefreshMMButton()
  if ICON then
    ICON:Refresh("Skada", self.db.profile.icon)
    if self.db.profile.icon.hide then
      ICON:Hide("Skada")
    else
      ICON:Show("Skada")
    end
  end
end

function Skada:ApplySettings()
  for i, win in ipairs(windows) do
    win.display:ApplySettings(win)
  end

  if (self.db.profile.hidesolo and is_solo()) or (self.db.profile.hidepvp and is_in_pvp())then
    self:SetActive(false)
  else
    self:SetActive(true)

    for i, win in ipairs(windows) do
      if win.db.hidden and win:IsShown() then
        win:Hide()
      end
    end
  end

  self:UpdateDisplay(true)
end

function Skada:ReloadSettings()
  for i, win in ipairs(windows) do
    win:destroy()
  end
  windows={}

  for i, win in ipairs(self.db.profile.windows) do
    self:CreateWindow(win.name, win)
  end

  self.total=self.char.total

  Skada:ClearAllIndexes()

  if ICON and not ICON:IsRegistered("Skada") then
    ICON:Register("Skada", dataobj, self.db.profile.icon)
  end
  self:RefreshMMButton()
  self:ApplySettings()
end

-- ======================================================= --

function Skada:ApplyBorder(frame, texture, color, thickness, padtop, padbottom, padleft, padright)
  local borderbackdrop={}
  
  if not frame.borderFrame then
    frame.borderFrame=CreateFrame("Frame", nil, frame)
    frame.borderFrame:SetFrameLevel(0)
  end

  frame.borderFrame:SetPoint("TOPLEFT", frame, -thickness-(padleft or 0), thickness+(padtop or 0))
  frame.borderFrame:SetPoint("BOTTOMRIGHT", frame, thickness+(padright or 0), -thickness-(padbottom or 0))

  if texture and thickness > 0 then
    borderbackdrop.edgeFile=LSM:Fetch("border", texture)
  else
    borderbackdrop.edgeFile=nil
  end

  borderbackdrop.edgeSize=thickness
  frame.borderFrame:SetBackdrop(borderbackdrop)
  if color then
    frame.borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
  end
end

function Skada:FrameSettings(db, include_dimensions)
  local obj={
    type="group",
    name=L["Window"],
    order=2,
    args={

      bgheader={
        type="header",
        name=L["Background"],
        order=1
      },

      texture={
        type="select",
        dialogControl="LSM30_Background",
        name=L["Background texture"],
        desc=L["The texture used as the background."],
        order=1.1,
        width="double",
        values=AceGUIWidgetLSMlists.background,
        get=function() return db.background.texture end,
        set=function(win,key) db.background.texture=key; Skada:ApplySettings() end
      },

      tile={
        type="toggle",
        name=L["Tile"],
        desc=L["Tile the background texture."],
        order=1.2,
        get=function() return db.background.tile end,
        set=function(win,key) db.background.tile=key; Skada:ApplySettings() end
      },

      tilesize={
        type="range",
        name=L["Tile size"],
        desc=L["The size of the texture pattern."],
        order=1.3,
        min=0,
        max=math.floor(GetScreenWidth()),
        step=1.0,
        get=function() return db.background.tilesize end,
        set=function(win, val) db.background.tilesize=val; Skada:ApplySettings() end
      },

      color={
        type="color",
        name=L["Background color"],
        desc=L["The color of the background."],
        order=1.4,
        hasAlpha=true,
        get=function(i)
          local c=db.background.color
          return c.r, c.g, c.b, c.a
        end,
        set=function(i, r,g,b,a)
          db.background.color={["r"]=r, ["g"]=g, ["b"]=b, ["a"]=a}
          Skada:ApplySettings()
        end
      },

      borderheader={
        type="header",
        name=L["Border"],
        order=2
      },

      bordertexture={
        type="select",
        dialogControl="LSM30_Border",
        name=L["Border texture"],
        desc=L["The texture used for the borders."],
        order=2.1,
        width="double",
        values=AceGUIWidgetLSMlists.border,
        get=function() return db.background.bordertexture end,
        set=function(win,key) db.background.bordertexture=key; Skada:ApplySettings() end
      },

      bordercolor={
        type="color",
        name=L["Border color"],
        desc=L["The color used for the border."],
        order=2.2,
        hasAlpha=true,
        get=function(i)
          local c=db.background.bordercolor or {r=0,g=0,b=0,a=1}
          return c.r, c.g, c.b, c.a
        end,
        set=function(i, r,g,b,a)
          db.background.bordercolor={["r"]=r, ["g"]=g, ["b"]=b, ["a"]=a}
          Skada:ApplySettings()
        end
      },

      thickness={
        type="range",
        name=L["Border thickness"],
        desc=L["The thickness of the borders."],
        order=2.3,
        min=0,
        max=50,
        step=0.5,
        get=function() return db.background.borderthickness end,
        set=function(win, val) db.background.borderthickness=val; Skada:ApplySettings() end
      },

      optionheader={
        type="header",
        name=L["General"],
        order=3
      },

      scale={
        type="range",
        name=L["Scale"],
        desc=L["Sets the scale of the window."],
        order=3.1,
        min=0.1,
        max=3,
        step=0.01,
        get=function() return db.scale end,
        set=function(win, val) db.scale=val; Skada:ApplySettings() end
      },

      strata={
        type="select",
        name=L["Strata"],
        desc=L["This determines what other frames will be in front of the frame."],
        order=3.2,
        values={["BACKGROUND"]="BACKGROUND", ["LOW"]="LOW", ["MEDIUM"]="MEDIUM", ["HIGH"]="HIGH", ["DIALOG"]="DIALOG", ["FULLSCREEN"]="FULLSCREEN", ["FULLSCREEN_DIALOG"]="FULLSCREEN_DIALOG"},
        get=function() return db.strata end,
        set=function(win, val) db.strata=val; Skada:ApplySettings() end
      }
    }
  }

  if include_dimensions then
    obj.args.width={
      type="range",
      name=L["Width"],
      order=3.3,
      min=100,
      max=GetScreenWidth(),
      step=1.0,
      get=function() return db.width end,
      set=function(win,key) db.width=key; Skada:ApplySettings() end
    }

    obj.args.height={
      type="range",
      name=L["Height"],
      order=3.4,
      min=16,
      max=400,
      step=1.0,
      get=function() return db.height end,
      set=function(win,key) db.height=key; Skada:ApplySettings() end
    }
  end

  return obj
end

-- ======================================================= --

function Skada:OnInitialize()
  LSM:Register("font", "ABF", [[Interface\Addons\Skada\media\fonts\ABF.ttf]])
  LSM:Register("font", "Accidental Presidency", [[Interface\Addons\Skada\media\fonts\Accidental Presidency.ttf]])
  LSM:Register("font", "Adventure", [[Interface\Addons\Skada\media\fonts\Adventure.ttf]])
  LSM:Register("font", "Diablo", [[Interface\Addons\Skada\media\fonts\Diablo.ttf]])

  LSM:Register("statusbar", "Aluminium", [[Interface\Addons\Skada\media\statusbar\Aluminium]])
  LSM:Register("statusbar", "Armory", [[Interface\Addons\Skada\media\statusbar\Armory]])
  LSM:Register("statusbar", "BantoBar", [[Interface\Addons\Skada\media\statusbar\BantoBar]])
  LSM:Register("statusbar", "Details", [[Interface\AddOns\Skada\media\statusbar\Details]])
  LSM:Register("statusbar", "Glass", [[Interface\AddOns\Skada\media\statusbar\Glass]])
  LSM:Register("statusbar", "Gloss", [[Interface\Addons\Skada\media\statusbar\Gloss]])
  LSM:Register("statusbar", "Graphite", [[Interface\Addons\Skada\media\statusbar\Graphite]])
  LSM:Register("statusbar", "Grid", [[Interface\Addons\Skada\media\statusbar\Grid]])
  LSM:Register("statusbar", "Healbot", [[Interface\Addons\Skada\media\statusbar\Healbot]])
  LSM:Register("statusbar", "LiteStep", [[Interface\Addons\Skada\media\statusbar\LiteStep]])
  LSM:Register("statusbar", "Minimalist", [[Interface\Addons\Skada\media\statusbar\Minimalist]])
  LSM:Register("statusbar", "Otravi", [[Interface\Addons\Skada\media\statusbar\Otravi]])
  LSM:Register("statusbar", "Outline", [[Interface\Addons\Skada\media\statusbar\Outline]])
  LSM:Register("statusbar", "Round", [[Interface\Addons\Skada\media\statusbar\Round]])
  LSM:Register("statusbar", "Serenity", [[Interface\AddOns\Skada\media\statusbar\Serenity]])
  LSM:Register("statusbar", "Smooth", [[Interface\Addons\Skada\media\statusbar\Smooth]])
  LSM:Register("statusbar", "Smooth v2", [[Interface\Addons\Skada\media\statusbar\Smoothv2]])
  LSM:Register("statusbar", "TukTex", [[Interface\Addons\Skada\media\statusbar\TukTex]])
  LSM:Register("statusbar", "WorldState Score", [[Interface\WorldStateFrame\WORLDSTATEFINALSCORE-HIGHLIGHT]])

  LSM:Register("sound", "Cartoon FX", [[Sound\Doodad\Goblin_Lottery_Open03.wav]])
  LSM:Register("sound", "Cheer", [[Sound\Event Sounds\OgreEventCheerUnique.wav]])
  LSM:Register("sound", "Explosion", [[Sound\Doodad\Hellfire_Raid_FX_Explosion05.wav]])
  LSM:Register("sound", "Fel Nova", [[Sound\Spells\SeepingGaseous_Fel_Nova.wav]])
  LSM:Register("sound", "Fel Portal", [[Sound\Spells\Sunwell_Fel_PortalStand.wav]])
  LSM:Register("sound", "Humm", [[Sound\Spells\SimonGame_Visual_GameStart.wav]])
  LSM:Register("sound", "Rubber Ducky", [[Sound\Doodad\Goblin_Lottery_Open01.wav]])
  LSM:Register("sound", "Shing!", [[Sound\Doodad\PortcullisActive_Closed.wav]])
  LSM:Register("sound", "Short Circuit", [[Sound\Spells\SimonGame_Visual_BadPress.wav]])
  LSM:Register("sound", "Simon Chime", [[Sound\Doodad\SimonGame_LargeBlueTree.wav]])
  LSM:Register("sound", "War Drums", [[Sound\Event Sounds\Event_wardrum_ogre.wav]])
  LSM:Register("sound", "Wham!", [[Sound\Doodad\PVP_Lordaeron_Door_Open.wav]])
  LSM:Register("sound", "You Will Die!", [[Sound\Creature\CThun\CThunYouWillDIe.wav]])

  self.db=LibStub("AceDB-3.0"):New("SkadaDB", self.defaults, "Default")

  SkadaCharDB=SkadaCharDB or {}
  self.char=SkadaCharDB
  self.char.sets=self.char.sets or {}

  AceConfig:RegisterOptionsTable("Skada", self.options)
  self.optionsFrame=ACD:AddToBlizOptions("Skada", "Skada")

  -- Profiles
  AceConfig:RegisterOptionsTable("Skada-Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db))
  self.profilesFrame=ACD:AddToBlizOptions("Skada-Profiles", "Profiles", "Skada")

  self:RegisterChatCommand("skada", "Command")
  
  self.db.RegisterCallback(self, "OnProfileChanged", "ReloadSettings")
  self.db.RegisterCallback(self, "OnProfileCopied", "ReloadSettings")
  self.db.RegisterCallback(self, "OnProfileReset", "ReloadSettings")
  self.db.RegisterCallback(self, "OnDatabaseShutdown", "ClearAllIndexes")

  self:ReloadSettings()
  self:ScheduleTimer("ApplySettings", 2)
end

function Skada:MemoryCheck()
  UpdateAddOnMemoryUsage()
  local mem=GetAddOnMemoryUsage("Skada")
  if mem>30000 then
    self:Print(L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."])
  end
end

function Skada:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("PARTY_MEMBERS_CHANGED")
  self:RegisterEvent("RAID_ROSTER_UPDATE")
  self:RegisterEvent("UNIT_PET")
  self:RegisterEvent("PLAYER_REGEN_DISABLED")
  self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatLogEvent")

  if type(CUSTOM_CLASS_COLORS)=="table" then
    Skada.classcolors=CUSTOM_CLASS_COLORS
  end

  if self.modulelist then
    for i=1, #self.modulelist do
      self.modulelist[i](self, L)
    end
    self.modulelist=nil
  end

  self:ScheduleTimer("MemoryCheck", 3)
end

-- ======================================================= --

do
  function IsRaidInCombat()
    local incombat=false
    local t, count=GetGroupTypeAndCount()

    if count>0 then
      for i=1, count, 1 do
        if UnitExists(t..i) and UnitAffectingCombat(t..i) then
          incombat=true
          break
        end
      end
    elseif UnitAffectingCombat("player") then
      incombat=true
    end

    return incombat
  end

  function IsRaidDead()
    local iswipe=true  
    local t, count=GetGroupTypeAndCount()
    
    if count>0 then
      for i=1, count, 1 do
        if UnitExists(t..i) and not UnitIsDeadOrGhost(t..i) then
          iswipe=true
          break
        end
      end
    elseif not UnitIsDeadOrGhost("player") then
      iswipe=false
    end

    return iswipe
  end

  function Skada:Tick()
    if not disabled and self.current and not InCombatLockdown() and not IsRaidInCombat() then
      self:EndSegment()
    end
  end

  function Skada:PLAYER_REGEN_DISABLED()
    if not disabled and not self.current then
      self:StartCombat()
    end
  end

  function Skada:NewSegment()
    if self.current then
      self:EndSegment()
      self:StartCombat()
    end
  end

  function Skada:EndSegment()
    if not self.current then return end

    if not self.db.profile.onlykeepbosses or self.current.gotboss then
      if self.current.mobname~=nil and time()-self.current.starttime>5 then
        self.current.endtime=self.current.endtime or time()
        self.current.time=self.current.endtime-self.current.starttime
        setPlayerActiveTimes(self.current)
        self.current.stopped=nil

        local setname=self.current.mobname
        if self.db.profile.setnumber then
          local max=0
          for _, set in ipairs(self.char.sets) do
            if set.name==setname and max==0 then
              max=1
            else
              local n, c=set.name:match("^(.-)%s*%((%d+)%)$")
              if n==setname then max=math.max(max,tonumber(c) or 0) end
            end
          end
          if max>0 then
            setname=format("%s (%s)", setname, max+1)
          end
        end
        self.current.name=setname
        -- self.current.name=self.current.mobname

        for i, mode in ipairs(modes) do
          if mode.SetComplete then
            mode:SetComplete(self.current)
          end
        end

        tinsert(self.char.sets, 1, self.current)
      end
    end

    self.last=self.current

    self.total.time=self.total.time+self.current.time
    setPlayerActiveTimes(self.total)

    for i, player in ipairs(self.total.players) do
      player.first=nil
      player.last=nil
    end

    self.current=nil

    local numsets=0
    for i, set in ipairs(self.char.sets) do
      if not set.keep then
        numsets=numsets+1
      end
    end

    for i=tmaxn(self.char.sets), 1, -1 do
      if numsets>self.db.profile.setstokeep and not self.char.sets[i].keep then
        tremove(self.char.sets, i)
        numsets=numsets-1
      end
    end

    for i, win in ipairs(windows) do
      win:Wipe()
      change=true

      if win.db.wipemode~="" and IsRaidDead() then
        self:RestoreView(win, "current", win.db.wipemode)
      elseif win.db.returnaftercombat and win.restore_mode and win.restore_set then
        if win.restore_set~=win.selectedset or win.restore_mode~=win.selectedmode then
          self:RestoreView(win, win.restore_set, win.restore_mode)

          win.restore_mode, win.restore_set=nil, nil
        end
      end

      if not win.db.hidden and self.db.profile.hidecombat and (not self.db.profile.hidesolo or IsInGroup()) then
        win:Hide()
      end
    end

    self:UpdateDisplay(true)
    self:CancelTimer(update_timer, true)
    self:CancelTimer(tick_timer, true)
    update_timer, tick_timer=nil, nil
  end

  function Skada:StopSegment()
    if self.current then
      self.current.stopped=true
      self.current.endtime=time()
      self.current.time=self.current.endtime-self.current.starttime
    end
  end

  function Skada:ResumeSegment()
    if self.current and self.current.stopped then
      self.current.stopped=nil
      self.current.endtime=nil
      self.current.time=nil
    end
  end
end

-- ======================================================= --

do
  local tentative, tentativehandle
  local deathcounter, startingmembers=0, 0

  function Skada:StartCombat()
    deathcounter=0
    local _, members=GetGroupTypeAndCount()
    startingmembers=members

    if tentativehandle~=nil then
      self:CancelTimer(tentativehandle)
      tentativehandle=nil
    end

    if update_timer then
      self:EndSegment()
    end

    self:Wipe()

    if not self.current then
      self.current=createSet(L["Current"])
    end

    if self.total==nil then
      self.total=createSet(L["Total"])
      self.char.total=self.total
    end

    for i, win in ipairs(windows) do
      if win.db.modeincombat~="" then
        local mymode=find_mode(win.db.modeincombat)

        if mymode~=nil then
          if win.db.returnaftercombat then
            if win.selectedset then
              win.restore_set=win.selectedset
            end
            if win.selectedmode then
              win.restore_mode=win.selectedmode:GetName()
            end
          end

          win.selectedset="current"
          win:DisplayMode(mymode)
        end
      end

      if not win.db.hidden and self.db.profile.hidecombat then
        win:Hide()
      end
    end

    self:UpdateDisplay(true)

    update_timer=self:ScheduleRepeatingTimer("UpdateDisplay", self.db.profile.updatefrequency or 0.25)
    tick_timer=self:ScheduleRepeatingTimer("Tick", 1)
  end

  local PET_FLAGS=bit.bor(COMBATLOG_OBJECT_TYPE_PET, COMBATLOG_OBJECT_TYPE_GUARDIAN)
  local RAID_FLAGS=bit.bor(COMBATLOG_OBJECT_AFFILIATION_MINE, COMBATLOG_OBJECT_AFFILIATION_PARTY, COMBATLOG_OBJECT_AFFILIATION_RAID)
  local SHAM_FLAGS=bit.bor(COMBATLOG_OBJECT_TYPE_NPC+COMBATLOG_OBJECT_CONTROL_NPC)

  -- list of combat events that we don't care about
  local ignoredevents={
    ["SPELL_AURA_APPLIED_DOSE"]=true,
    ["SPELL_AURA_REMOVED_DOSE"]=true,
    ["SPELL_CAST_START"]=true,
    ["SPELL_CAST_SUCCESS"]=true,
    ["SPELL_CAST_FAILED"]=true,
    ["SPELL_DRAIN"]=true,
    ["PARTY_KILL"]=true,
    ["SPELL_PERIODIC_DRAIN"]=true,
    ["SPELL_DISPEL_FAILED"]=true,
    ["SPELL_DURABILITY_DAMAGE"]=true,
    ["SPELL_DURABILITY_DAMAGE_ALL"]=true,
    ["ENCHANT_APPLIED"]=true,
    ["ENCHANT_REMOVED"]=true,
    ["SPELL_CREATE"]=true,
    ["SPELL_BUILDING_DAMAGE"]=true
  }

  -- events used to trigger combat
  local triggerevents={
    ["RANGE_DAMAGE"]         =true,
    ["SPELL_BUILDING_DAMAGE"]=true,
    ["SPELL_DAMAGE"]         =true,
    ["SPELL_PERIODIC_DAMAGE"]=true,
    ["SWING_DAMAGE"]         =true,
  }

  local combatlogevents={}

  function Skada:RegisterForCL(func, event, flags)
    combatlogevents[event]=combatlogevents[event] or {}
    tinsert(combatlogevents[event], {["func"]=func, ["flags"]=flags})
  end

  function Skada:IsBoss(GUID)
    return GUID and BOSS.BossIDs[tonumber(GUID:sub(9, 12), 16)]
  end

  function Skada:CombatLogEvent(_, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    if ignoredevents[eventtype] then return end

    local src_is_interesting=nil
    local dst_is_interesting=nil

    if not self.current and self.db.profile.tentativecombatstart and srcName and dstName and srcGUID~=dstGUID and triggerevents[eventtype] then
      src_is_interesting=band(srcFlags, RAID_FLAGS)~=0 or (band(srcFlags, PET_FLAGS)~=0 and pets[srcGUID]) or players[srcGUID]

      if eventtype~="SPELL_PERIODIC_DAMAGE" then
        dst_is_interesting=band(dstFlags, RAID_FLAGS)~=0 or (band(dstFlags, PET_FLAGS)~=0 and pets[dstGUID]) or players[dstGUID]
      end

      if src_is_interesting or dst_is_interesting then
        self.current=createSet(L["Current"])

        if not self.total then
          self.total=createSet(L["Total"])
        end
        tentativehandle=self:ScheduleTimer(function()
          tentative=nil
          tentativehandle=nil
          self.current=nil
        end, 1)
        tentative=0
      end
    end

    if self.current and self.db.profile.autostop then
      if self.current and eventtype=="UNIT_DIED" and ((band(srcFlags, RAID_FLAGS)~=0 and band(srcFlags, PET_FLAGS)==0) or players[srcGUID]) then
        deathcounter=deathcounter+1
        -- If we reached the treshold for stopping the segment, do so.
        if deathcounter>0 and deathcounter/startingmembers>=0.5 and not self.current.stopped then
          self:Print("Stopping for wipe.")
          self:StopSegment()
        end
      end

      if self.current and eventtype=="SPELL_RESURRECT" and ((band(srcFlags, RAID_FLAGS)~=0 and band(srcFlags, PET_FLAGS)==0) or players[srcGUID]) then
        deathcounter=deathcounter-1
      end
    end

    if self.current and combatlogevents[eventtype] then
      if self.current.stopped then return end

      for i, mod in ipairs(combatlogevents[eventtype]) do
        local fail=false

        if mod.flags.src_is_interesting_nopets then
          local src_is_interesting_nopets=(band(srcFlags, RAID_FLAGS)~=0 and band(srcFlags, PET_FLAGS)==0) or players[srcGUID]

          if src_is_interesting_nopets then
            src_is_interesting=true
          else
            fail=true
          end
        end

        if not fail and mod.flags.dst_is_interesting_nopets then
          local dst_is_interesting_nopets=(band(dstFlags, RAID_FLAGS)~=0 and band(dstFlags, PET_FLAGS)==0) or players[dstGUID]
          if dst_is_interesting_nopets then
            dst_is_interesting=true
          else
            fail=true
          end
        end

        if not fail and mod.flags.src_is_interesting or mod.flags.src_is_not_interesting then
          if not src_is_interesting then
            src_is_interesting=band(srcFlags, RAID_FLAGS)~=0 or (band(srcFlags, PET_FLAGS)~=0 and pets[srcGUID]) or players[srcGUID]
          end

          if mod.flags.src_is_interesting and not src_is_interesting then
            fail=true
          end

          if mod.flags.src_is_not_interesting and src_is_interesting then
            fail=true
          end
        end

        if not fail and mod.flags.dst_is_interesting or mod.flags.dst_is_not_interesting then
          if not dst_is_interesting then
            dst_is_interesting=band(dstFlags, RAID_FLAGS)~=0 or (band(dstFlags, PET_FLAGS)~=0 and pets[dstGUID]) or players[dstGUID]
          end

          if mod.flags.dst_is_interesting and not dst_is_interesting then
            fail=true
          end

          if mod.flags.dst_is_not_interesting and dst_is_interesting then
            fail=true
          end
        end

        if not fail then
          mod.func(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)

          if tentative~=nil then
            tentative=tentative+1
            if tentative==5 then
              self:CancelTimer(tentativehandle)
              tentativehandle=nil
              self:StartCombat()
            end
          end
        end
      end
    end

    if self.current and src_is_interesting and not self.current.gotboss then
      if bit.band(dstFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY)==0 then
        self.current.mobname=dstName
        if not self.current.gotboss and self:IsBoss(dstGUID) then
          self.current.gotboss=true
        end
      end
    end

    if eventtype=="SPELL_SUMMON" and (band(srcFlags, RAID_FLAGS)~=0 or band(srcFlags, PET_FLAGS)~=0 or band(srcFlags, SHAM_FLAGS)~=0 or (band(dstFlags, PET_FLAGS)~=0 and pets[dstGUID])) then
      pets[dstGUID]={id=srcGUID, name=srcName}
      local changed = true -- try to fix the table
      while changed do
        changed=false
        for pet, owner in pairs(pets) do
          if pets[owner.id] then
            Skada:AssignPet(pets[owner.id].id, pets[owner.id].name, pet);
            changed=true
          end
        end
      end
    end
  end
end
