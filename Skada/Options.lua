assert(Skada, "Skada not found!")

local Skada = Skada
Skada.version = GetAddOnMetadata("Skada", "Version")
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local fmt = string.format

Skada.resetoptions = {[1] = NO, [2] = YES, [3] = L["Ask"]}

Skada.windowdefaults = {
    name = "Skada",
    barspacing = 0,
    bartexture = "BantoBar",
    barfont = "Accidental Presidency",
    barfontflags = "",
    barfontsize = 13,
    numfont = "Accidental Presidency",
    numfontflags = "",
    numfontsize = 13,
    barheight = 18,
    barwidth = 240,
    barorientation = 1,
    barcolor = {r = 0.3, g = 0.3, b = 0.8, a = 1},
    barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
    barslocked = false,
    clickthrough = false,
    spellschoolcolors = true,
    classcolorbars = true,
    classcolortext = false,
    classicons = true,
    roleicons = false,
    specicons = true,
    spark = true,
    showself = true,
    -- buttons
    buttons = {menu = true, reset = true, report = true, mode = true, segment = true, stop = false},
    -- title options
    title = {
        height = 20,
        font = "Accidental Presidency",
        fontsize = 13,
        fontflags = "",
        color = {r = 0.3, g = 0.3, b = 0.3, a = 1},
        texture = "Armory",
        textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1},
        bordertexture = "None",
        borderthickness = 2,
        bordercolor = {r = 0, g = 0, b = 0, a = 1},
        hovermode = false
    },
    background = {
        tile = false,
        tilesize = 0,
        color = {r = 0, g = 0, b = 0, a = 0.4},
        texture = "Solid",
        bordercolor = {r = 0, g = 0, b = 0, a = 0.5},
        bordertexture = "None",
        borderthickness = 1,
        height = 200
    },
    strata = "LOW",
    scale = 1,
    reversegrowth = false,
    modeincombat = "",
    returnaftercombat = false,
    wipemode = "",
    hidden = false,
    enabletitle = true,
    titleset = true,
    combattimer = false,
    set = "current",
    mode = nil,
    display = "bar",
    snapto = true,
    snapped = {},
    smoothing = false,
    -- inline bar display
    isonnewline = false,
    isusingclasscolors = true,
    height = 30,
    width = 600,
    color = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
    isusingelvuiskin = true,
    issolidbackdrop = false,
    fixedbarwidth = false,
    -- data broker display
    textcolor = {r = 0.9, g = 0.9, b = 0.9},
    useframe = true
}

local windefaultscopy = {}
Skada:tcopy(windefaultscopy, Skada.windowdefaults)

Skada.defaults = {
    profile = {
        reset = {instance = 1, join = 3, leave = 1},
        icon = {hide = false, radius = 80, minimapPos = 195},
        numberformat = 1,
        setformat = 3,
        setnumber = true,
        showranks = true,
        setstokeep = 15,
        memorycheck = true,
        tooltips = true,
        tooltippos = "smart",
        tooltiprows = 3,
        informativetooltips = true,
        onlykeepbosses = false,
        tentativetimer = 1,
        tentativecombatstart = false,
        hidesolo = false,
        hidepvp = false,
        hidedisables = true,
        hidecombat = false,
        translit = false,
        mergepets = true,
        shortmenu = true,
        feed = "",
        showtotals = false,
        autostop = false,
        smartstop = false,
        sortmodesbyusage = false,
        updatefrequency = 0.25,
        modules = {},
        columns = {},
        report = {mode = "Damage", set = "current", channel = "Say", chantype = "preset", number = 10},
        modulesBlocked = {
            ["Spamage"] = true,
            ["Useful damage"] = true,
            ["Damage done by spell"] = true,
            ["Avoidance & Mitigation"] = true
        },
        windows = {windefaultscopy}
    }
}

-- Adds column configuration options for a mode.
function Skada:AddColumnOptions(mod)
    local db = self.db.profile.columns

    if mod.metadata and mod.metadata.columns then
        local cols = {
            type = "group",
            name = mod:GetName(),
            order = 0,
            width = "double",
            inline = true,
            args = {}
        }

        for colname, _ in pairs(mod.metadata.columns) do
            local c = mod:GetName() .. "_" .. colname

            -- Set initial value from db if available, otherwise use mod default value.
            if db[c] ~= nil then
                mod.metadata.columns[colname] = db[c]
            end

            -- Add column option.
            local col = {
                type = "toggle",
                name = L[colname] or colname,
                get = function()
                    return mod.metadata.columns[colname]
                end,
                set = function()
                    mod.metadata.columns[colname] = not mod.metadata.columns[colname]
                    db[c] = mod.metadata.columns[colname]
                    Skada:UpdateDisplay(true)
                end
            }
            cols.args[c] = col
        end

        Skada.options.args.columns.args[mod:GetName()] = cols
    end
end

do
    local numorder = 1
    function Skada:AddLoadableModuleCheckbox(mod, name, description)
        local new = {
            type = "toggle",
            name = name,
            desc = description,
            order = numorder
        }
        self.options.args.disabled.args[mod] = new
        numorder = numorder + 1
    end
end

local deletewindow = nil
local newdisplay = "bar"

Skada.options = {
    type = "group",
    name = "Skada |cffffffff" .. Skada.version .. "|r by |cfff58cbaKader|r",
    get = function(i)
        return Skada.db.profile[i[#i]]
    end,
    set = function(i, val)
        Skada.db.profile[i[#i]] = val
        if i[#i] == "showtotals" then
            Skada:ReloadSettings()
        else
            Skada:ApplySettings()
        end
    end,
    plugins = {},
    args = {
        discord = {
            type = "header",
            name = "Discord Server : |c007289d9https://bitly.com/skada-rev|r",
            order = 1
        },
        windows = {
            type = "group",
            name = L["Windows"],
            order = 2,
            args = {
                create = {
                    type = "input",
                    name = L["Create window"],
                    desc = L["Enter the name for the new window."],
                    order = 1,
                    width = "double",
                    set = function(_, val)
                        if val and val ~= "" then
                            Skada:CreateWindow(val, nil, newdisplay)
                        end
                    end
                },
                display = {
                    type = "select",
                    name = L["Display system"],
                    desc = L["Choose the system to be used for displaying data in this window."],
                    order = 2,
                    width = "double",
                    values = function()
                        local list = {}
                        for name, display in pairs(Skada.displays) do
                            list[name] = display.name
                        end
                        return list
                    end,
                    get = function()
                        return newdisplay
                    end,
                    set = function(_, display)
                        newdisplay = display
                    end
                },
                separator1 = {
                    type = "description",
                    name = " ",
                    order = 3,
                    width = "full"
                }
            }
        },
        resetoptions = {
            type = "group",
            name = L["Data resets"],
            order = 3,
            get = function(i)
                return Skada.db.profile.reset[i[#i]]
            end,
            set = function(i, val)
                Skada.db.profile.reset[i[#i]] = val
            end,
            args = {
                instance = {
                    type = "select",
                    name = L["Reset on entering instance"],
                    desc = L["Controls if data is reset when you enter an instance."],
                    order = 1,
                    width = "double",
                    values = function()
                        return Skada.resetoptions
                    end
                },
                join = {
                    type = "select",
                    name = L["Reset on joining a group"],
                    desc = L["Controls if data is reset when you join a group."],
                    order = 2,
                    width = "double",
                    values = function()
                        return Skada.resetoptions
                    end
                },
                leave = {
                    type = "select",
                    name = L["Reset on leaving a group"],
                    desc = L["Controls if data is reset when you leave a group."],
                    order = 3,
                    width = "double",
                    values = function()
                        return Skada.resetoptions
                    end
                }
            }
        },
        tooltips = {
            type = "group",
            name = L["Tooltips"],
            order = 4,
            args = {
                tooltips = {
                    type = "toggle",
                    name = L["Show tooltips"],
                    desc = L["Shows tooltips with extra information in some modes."],
                    order = 1
                },
                informativetooltips = {
                    type = "toggle",
                    name = L["Informative tooltips"],
                    desc = L["Shows subview summaries in the tooltips."],
                    order = 2
                },
                tooltiprows = {
                    type = "range",
                    name = L["Subview rows"],
                    desc = L["The number of rows from each subview to show when using informative tooltips."],
                    order = 3,
                    width = "double",
                    min = 1,
                    max = 10,
                    step = 1
                },
                tooltippos = {
                    type = "select",
                    name = L["Tooltip position"],
                    desc = L["Position of the tooltips."],
                    order = 4,
                    width = "double",
                    values = {
                        ["default"] = L["Default"],
                        ["smart"] = L["Smart"],
                        ["topright"] = L["Top right"],
                        ["topleft"] = L["Top left"],
                        ["bottomright"] = L["Bottom right"],
                        ["bottomleft"] = L["Bottom left"],
                        ["cursor"] = L["Follow Cursor"]
                    }
                }
            }
        },
        generaloptions = {
            type = "group",
            name = L["General options"],
            order = 5,
            args = {
                mmbutton = {
                    type = "toggle",
                    name = L["Show minimap button"],
                    desc = L["Toggles showing the minimap button."],
                    order = 1,
                    get = function()
                        return not Skada.db.profile.icon.hide
                    end,
                    set = function()
                        Skada.db.profile.icon.hide = not Skada.db.profile.icon.hide
                        Skada:RefreshMMButton()
                    end
                },
                shortmenu = {
                    type = "toggle",
                    name = L["Shorten menus"],
                    desc = L["Removes mode and segment menus from Skada menu to reduce its height. Menus are still accessible using window buttons."],
                    order = 2
                },
                mergepets = {
                    type = "toggle",
                    name = L["Merge pets"],
                    desc = L["Merges pets with their owners. Changing this only affects new data."],
                    order = 3
                },
                showtotals = {
                    type = "toggle",
                    name = L["Show totals"],
                    desc = L["Shows a extra row with a summary in certain modes."],
                    order = 4
                },
                onlykeepbosses = {
                    type = "toggle",
                    name = L["Only keep boss fighs"],
                    desc = L["Boss fights will be kept with this on, and non-boss fights are discarded."],
                    order = 5
                },
                hidesolo = {
                    type = "toggle",
                    name = L["Hide when solo"],
                    desc = L["Hides Skada's window when not in a party or raid."],
                    order = 6
                },
                hidepvp = {
                    type = "toggle",
                    name = L["Hide in PvP"],
                    desc = L["Hides Skada's window when in Battlegrounds/Arenas."],
                    order = 7
                },
                hidecombat = {
                    type = "toggle",
                    name = L["Hide in combat"],
                    desc = L["Hides Skada's window when in combat."],
                    order = 8
                },
                hidedisables = {
                    type = "toggle",
                    name = L["Disable while hidden"],
                    desc = L["Skada will not collect any data when automatically hidden."],
                    order = 9
                },
                sortmodesbyusage = {
                    type = "toggle",
                    name = L["Sort modes by usage"],
                    desc = L["The mode list will be sorted to reflect usage instead of alphabetically."],
                    order = 10
                },
                showranks = {
                    type = "toggle",
                    name = L["Show rank numbers"],
                    desc = L["Shows numbers for relative ranks for modes where it is applicable."],
                    order = 11
                },
                showself = {
                    type = "toggle",
                    name = L["Always show self"],
                    desc = L["Keeps the player shown last even if there is not enough space."],
                    order = 12
                },
                autostop = {
                    type = "toggle",
                    name = L["Autostop"],
                    desc = L["Automatically stops the current segment after half of all raid members have died."],
                    order = 13
                },
                tentativecombatstart = {
                    type = "toggle",
                    name = L["Aggressive combat detection"],
                    desc = L["Skada usually uses a very conservative (simple) combat detection scheme that works best in raids. With this option Skada attempts to emulate other damage meters. Useful for running dungeons. Meaningless on boss encounters."],
                    order = 15
                },
                tentativetimer = {
                    type = "range",
                    name = L["Tentative Timer"],
                    desc = L['The number of seconds Skada should wait after combat start to create a new segment.\n\nOnly works if "Agressive combat detection" is enabled.'],
                    order = 16,
                    min = 1,
                    max = 5,
                    step = 1,
                    width = "double",
                    disabled = function()
                        return not Skada.db.profile.tentativecombatstart
                    end,
                    hidden = function()
                        return not Skada.db.profile.tentativecombatstart
                    end
                },
                timemesure = {
                    type = "select",
                    name = L["Time measure"],
                    desc = L.timemesure_desc,
                    order = 17,
                    width = "double",
                    values = {[1] = L["Activity time"], [2] = L["Effective time"]},
                    get = function()
                        return Skada.db.profile.timemesure or 1
                    end
                },
                numberformat = {
                    type = "select",
                    name = L["Number format"],
                    desc = L["Controls the way large numbers are displayed."],
                    order = 18,
                    width = "double",
                    values = function()
                        return {[1] = L["Condensed"], [2] = L["Detailed"]}
                    end
                },
                setformat = {
                    type = "select",
                    name = L["Set format"],
                    desc = L["Controls the way set names are displayed."],
                    order = 19,
                    width = "double",
                    values = Skada:SetLabelFormats()
                },
                setnumber = {
                    type = "toggle",
                    name = L["Number set duplicates"],
                    desc = L["Append a count to set names with duplicate mob names."],
                    order = 20
                },
                translit = {
                    type = "toggle",
                    name = L["Translit"],
                    desc = L["Make those russian letters that no one understand to be presented as western letters."],
                    order = 21
                },
                feed = {
                    type = "select",
                    name = L["Data feed"],
                    desc = L[
                        "Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."
                    ],
                    order = 22,
                    width = "double",
                    values = function()
                        local feeds = {[""] = NONE}
                        for name, _ in pairs(Skada:GetFeeds()) do
                            feeds[name] = name
                        end
                        return feeds
                    end
                },
                separator1 = {
                    type = "description",
                    name = " ",
                    order = 23,
                    width = "full"
                },
                memorycheck = {
                    type = "toggle",
                    name = L["Memory Check"],
                    desc = function()
                        if Skada.db.profile.setstokeep == 0 then
                            return fmt(L["Checks memory usage and warns you if it is greater than or equal to %dmb."], 30)
                        end

                        return fmt(L["Checks memory usage and warns you if it is greater than or equal to %dmb."], (Skada.db.profile.setstokeep * 1.25) + 5)
                    end,
                    order = 97,
                    width = "double"
                },
                setstokeep = {
                    type = "range",
                    name = L["Data segments to keep"],
                    desc = L["The number of fight segments to keep. Persistent segments are not included in this."],
                    order = 98,
                    width = "double",
                    min = 0,
                    max = 99,
                    step = 1
                },
                updatefrequency = {
                    type = "range",
                    name = L["Update frequency"],
                    desc = L["How often windows are updated. Shorter for faster updates. Increases CPU usage."],
                    order = 99,
                    width = "double",
                    min = 0.10,
                    max = 1,
                    step = 0.05,
                    bigStep = 0.1
                }
            }
        },
        columns = {
            type = "group",
            name = L["Columns"],
            order = 6,
            args = {}
        },
        disabled = {
            type = "group",
            name = L["Disabled Modules"],
            order = 7,
            width = "double",
            get = function(i)
                return Skada.db.profile.modulesBlocked[i[#i]]
            end,
            set = function(i, value)
                Skada.db.profile.modulesBlocked[i[#i]] = value
                Skada.options.args.disabled.args.apply.disabled = false
            end,
            args = {
                desc = {
                    type = "description",
                    name = L["Tick the modules you want to disable."],
                    width = "double",
                    order = 0
                },
                apply = {
                    type = "execute",
                    name = APPLY,
                    width = "double",
                    func = ReloadUI,
                    confirm = function()
                        return L["This change requires a UI reload. Are you sure?"]
                    end,
                    disabled = true,
                    order = 99
                }
            }
        },
        modules = {
            type = "group",
            name = L["Modules"],
            order = 8,
            width = "double",
            disabled = function()
                return next(Skada.options.args.modules.args) == nil
            end,
            args = {}
        }
    }
}