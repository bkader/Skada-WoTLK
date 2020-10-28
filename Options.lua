local Skada=Skada
if not Skada then return end

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local media = LibStub("LibSharedMedia-3.0")

Skada.resetoptions = {[1] = L["No"], [2] = L["Yes"], [3] = L["Ask"]}

Skada.windowdefaults = {
  name = "Skada",

  barmax=10,
  barspacing=0,
  bartexture="BantoBar",
  barfont="Accidental Presidency",
  barfontsize=11,
  barheight=15,
  barwidth=220,
  barorientation=1,
  barcolor = {r = 0.3, g = 0.3, b = 0.8, a=1},
  baraltcolor = {r = 0.45, g = 0.45, b = 0.8, a = 1},
  barslocked=false,

  classcolorbars = true,
  classcolortext = false,
  
  spark = true,
  
  title = {menubutton = true, font="Accidental Presidency", fontsize=11,margin=0, texture="Round", bordertexture="None", borderthickness=2, color = {r=0,g=0,b=0,a=0.6}},
  background = {margin=0, height=150, texture="None", bordertexture="None", borderthickness=0, color = {r=0,g=0,b=0.5,a=0.5}},

  reversegrowth=false,
  modeincombat="",
  returnaftercombat=false,
  
  hidden = false,
  enabletitle = true, 
  enablebackground = false,
  
  set = "current",
  mode = nil,
  
  display = "bar",
}

local windefaultscopy = {}
Skada:tcopy(windefaultscopy, Skada.windowdefaults)

Skada.defaults = {
  profile = {
    reset={instance=1, join=3, leave=1},
    icon = {hide = false, radius = 80, minimapPos = 195},
    numberformat=1,
    showranks=true,
    setstokeep=10,
    tooltips=true,
    tooltippos="default",
    tooltiprows=3,
    informativetooltips=true,
    onlykeepbosses=false,
    tentativecombatstart=false,
    tentativetimer=3,
    hidesolo=false,
    hidepvp=false,
    hidedisables=true,
    hidecombat=false,
    feed = "",
    sets = {},
    total = nil,
    updatefrequency = 0.5,

    modules = {},
    columns = {},
    report = {mode = "Damage", set = "current", channel = "Say", chantype = "preset", number = 10},
    modulesBlocked={},

    windows = {windefaultscopy},
  }
}

-- Adds column configuration options for a mode.
function Skada:AddColumnOptions(mod)
  local db = self.db.profile.columns

  if mod.metadata and mod.metadata.columns then
    local cols = {
      type = "group",
      name = mod:GetName(),
      order=0,
      inline=true,
      args = {}
    }

    for colname, value in pairs(mod.metadata.columns) do
      local c = mod:GetName().."_"..colname

      -- Set initial value from db if available, otherwise use mod default value.
      if db[c] ~= nil then
        mod.metadata.columns[colname] = db[c]
      end

      -- Add column option.
      local col = {
        type="toggle",
        name=L[colname] or colname,
        get=function() return mod.metadata.columns[colname] end,
        set=function()
        mod.metadata.columns[colname] = not mod.metadata.columns[colname]
        db[c] = mod.metadata.columns[colname]
        Skada:UpdateDisplay(true)
        end,
      }
      cols.args[c] = col
    end

    Skada.options.args.columns.args[mod:GetName()] = cols
  end

end

function Skada:AddLoadableModuleCheckbox(mod, name, description)
  local new = {
    type = "toggle",
    name = name,
    desc = description,
    order = 1,
  }
  Skada.options.args.modules.args[mod] = new
end

local deletewindow = nil

Skada.options = {
  type="group",
  name="Skada",
  plugins = {},
  args={
    d = {
      type="description",
      name=L["A damage meter."],
      order=0,
    },

    windows = {
      type = "group",
      name = L["Windows"],
      order=0,
      args = {

        create = {
          type="input",
          name=L["Create window"],
          desc=L["Enter the name for the new window."],
          set=function(self, val) if val and val ~= "" then Skada:CreateWindow(val) end end,
          order=1,
        },

        delete = {
          type="select",
          name=L["Delete window"],
          desc=L["Choose the window to be deleted."],
          values= function()
          local windows = {}
          for i, win in ipairs(Skada:GetWindows()) do
            windows[win.db.name] = win.db.name
          end
          return windows
          end,
          get=function() return deletewindow end,
          set=function(self, val) deletewindow = val end,
          order=2,
        },
        deleteexecute = {
          type="execute",
          name=L["Delete window"],
          desc=L["Deletes the chosen window."],
          func=function(self) if deletewindow then Skada:DeleteWindow(deletewindow) end end,
          order=3,
        },

      },
    },

    resetoptions = {
      type = "group",
      name = L["Data resets"],
      order=2,
      args = {

        resetinstance = {
          type="select",
          name=L["Reset on entering instance"],
          desc=L["Controls if data is reset when you enter an instance."],
          values= function() return Skada.resetoptions end,
          get=function() return Skada.db.profile.reset.instance end,
          set=function(self, opt) Skada.db.profile.reset.instance = opt end,
          order=30,
        },

        resetjoin = {
          type="select",
          name=L["Reset on joining a group"],
          desc=L["Controls if data is reset when you join a group."],
          values= function() return Skada.resetoptions end,
          get=function() return Skada.db.profile.reset.join end,
          set=function(self, opt) Skada.db.profile.reset.join = opt end,
          order=31,
        },

        resetleave = {
          type="select",
          name=L["Reset on leaving a group"],
          desc=L["Controls if data is reset when you leave a group."],
          values= function() return Skada.resetoptions end,
          get=function() return Skada.db.profile.reset.leave end,
          set=function(self, opt) Skada.db.profile.reset.leave = opt end,
          order=32,
        },

      }

    },

    tooltips = {
      type = "group",
      name = L["Tooltips"],
      order=4,
      args = {
        tooltips = {
          type="toggle",
          name=L["Show tooltips"],
          desc=L["Shows tooltips with extra information in some modes."],
          order=1,
          get=function() return Skada.db.profile.tooltips end,
          set=function() Skada.db.profile.tooltips = not Skada.db.profile.tooltips end,
        },

        informative = {
          type="toggle",
          name=L["Informative tooltips"],
          desc=L["Shows subview summaries in the tooltips."],
          order=2,
          get=function() return Skada.db.profile.informativetooltips end,
          set=function() Skada.db.profile.informativetooltips = not Skada.db.profile.informativetooltips end,
        },

        rows = {
          type="range",
          name=L["Subview rows"],
          desc=L["The number of rows from each subview to show when using informative tooltips."],
          min=1,
          max=10,
          step=1,
          get=function() return Skada.db.profile.tooltiprows end,
          set=function(self, val) Skada.db.profile.tooltiprows = val end,
          order=3,
        },

        tooltippos = {
          type="select",
          name=L["Tooltip position"],
          desc=L["Position of the tooltips."],
          values= {["default"] = L["Default"], ["topright"] = L["Top right"], ["topleft"] = L["Top left"], ["bottomright"] = L["Bottom right"], ["bottomleft"] = L["Bottom left"], ["cursor"] = L["Follow cursor"]},
          get=function() return Skada.db.profile.tooltippos end,
          set=function(self, opt) Skada.db.profile.tooltippos = opt end,
          order=4,
        },
      }
    },

    generaloptions = {
      type = "group",
      name = L["General options"],
      order=3,
      args = {

        mmbutton = {
          type="toggle",
          name=L["Show minimap button"],
          desc=L["Toggles showing the minimap button."],
          order=1,
          get=function() return not Skada.db.profile.icon.hide end,
          set=function()
          Skada.db.profile.icon.hide = not Skada.db.profile.icon.hide
          Skada:RefreshMMButton()
          end,
        },



        onlykeepbosses = {
          type="toggle",
          name=L["Only keep boss fighs"],
          desc=L["Boss fights will be kept with this on, and non-boss fights are discarded."],
          order=3,
          get=function() return Skada.db.profile.onlykeepbosses end,
          set=function() Skada.db.profile.onlykeepbosses = not Skada.db.profile.onlykeepbosses end,
        },

        hidesolo = {
          type="toggle",
          name=L["Hide when solo"],
          desc=L["Hides Skada's window when not in a party or raid."],
          order=4,
          get=function() return Skada.db.profile.hidesolo end,
          set=function()
          Skada.db.profile.hidesolo = not Skada.db.profile.hidesolo
          Skada:ApplySettings()
          end,
        },

        hidepvp = {
          type="toggle",
          name=L["Hide in PvP"],
          desc=L["Hides Skada's window when in Battlegrounds/Arenas."],
          order=5,
          get=function() return Skada.db.profile.hidepvp end,
          set=function()
          Skada.db.profile.hidepvp = not Skada.db.profile.hidepvp
          Skada:ApplySettings()
          end,
        },

        hidecombat = {
          type="toggle",
          name=L["Hide in combat"],
          desc=L["Hides Skada's window when in combat."],
          order=6,
          get=function() return Skada.db.profile.hidecombat end,
          set=function()
          Skada.db.profile.hidecombat = not Skada.db.profile.hidecombat
          Skada:ApplySettings()
          end,
        },

        disablewhenhidden = {
          type="toggle",
          name=L["Disable while hidden"],
          desc=L["Skada will not collect any data when automatically hidden."],
          order=7,
          get=function() return Skada.db.profile.hidedisables end,
          set=function()
          Skada.db.profile.hidedisables = not Skada.db.profile.hidedisables
          Skada:ApplySettings()
          end,
        },

        showranks = {
          type="toggle",
          name=L["Show rank numbers"],
          desc=L["Shows numbers for relative ranks for modes where it is applicable."],
          order=9,
          get=function() return Skada.db.profile.showranks end,
          set=function()
          Skada.db.profile.showranks = not Skada.db.profile.showranks
          Skada:ApplySettings()
          end,
        },

        tentativecombatstart = {
          type="toggle",
          name=L["Aggressive combat detection"],
          desc=L["Skada usually uses a very conservative (simple) combat detection scheme that works best in raids. With this option Skada attempts to emulate other damage meters. Useful for running dungeons. Meaningless on boss encounters."],
          order=10,
          get=function() return Skada.db.profile.tentativecombatstart end,
          set=function() Skada.db.profile.tentativecombatstart = not Skada.db.profile.tentativecombatstart end,
        },

        tentativetimer = {
          type="range",
          name=L["Tentative Timer"],
          desc=L["The number of seconds to wait for combat events when engaging combat.\nSkada only creates a new segment if there are enough combat events during a set amount of time.\n\nOnly applies if 'Aggressive combat detection' is turned off."],
          min=1,
          max=5,
          step=1,
          get=function() return Skada.db.profile.tentativetimer end,
          set=function(self, val) Skada.db.profile.tentativetimer = val end,
          order=11,
        },

        numberformat = {
          type="select",
          name=L["Number format"],
          desc=L["Controls the way large numbers are displayed."],
          values= function() return {[1] = L["Condensed"], [2] = L["Detailed"]} end,
          get=function() return Skada.db.profile.numberformat end,
          set=function(self, opt) Skada.db.profile.numberformat = opt end,
          order=12,
        },

        datafeed = {
          type="select",
          name=L["Data feed"],
          desc=L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."],
          values= function()
          local feeds = {}
          feeds[""] = L["None"]
          for name, func in pairs(Skada:GetFeeds()) do feeds[name] = name end
          return feeds
          end,
          get=function() return Skada.db.profile.feed end,
          set=function(self, feed)
          Skada.db.profile.feed = feed
          if feed ~= "" then Skada:SetFeed(Skada:GetFeeds()[feed]) end
          end,
          order=13,
        },

        setstokeep = {
          type="range",
          name=L["Data segments to keep"],
          desc=L["The number of fight segments to keep. Persistent segments are not included in this."],
          min=0,
          max=30,
          step=1,
          get=function() return Skada.db.profile.setstokeep end,
          set=function(self, val) Skada.db.profile.setstokeep = val end,
          order=14,
        },

        updatefrequency = {
          type="range",
          name=L["Update frequency"],
          desc=L["How often windows are updated. Shorter for faster updates. Increases CPU usage."],
          min = 0.10,
          max = 1,
          step = 0.05,
          get=function() return Skada.db.profile.updatefrequency end,
          set=function(self, val) Skada.db.profile.updatefrequency = val end,
          order=14,
          width="double",
        }
      }
    },

    columns = {
      type = "group",
      name = L["Columns"],
      order=4,
      args = {}
    },

    modules = {
      type = "group",
      name = L["Disabled Modules"],
      order=6,
      get = function(i) return Skada.db.profile.modulesBlocked[i[#i]] end,
      set = function(i, value) Skada.db.profile.modulesBlocked[i[#i]] = value; Skada.options.args.modules.args.apply.disabled=false end,
      args = {
        desc = {
          type="description",
          name=L["Tick the modules you want to disable."],
          width="full",
          order=0,
        },
        apply = {
          type="execute",
          name=APPLY,
          width="full",
          func=ReloadUI,
          confirm = function()
            return L["This change requires a UI reload. Are you sure?"]
          end,
          disabled = true,
          order=99,
        },
      },
    }
  }
}
