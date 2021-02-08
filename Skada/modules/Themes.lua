local Skada = Skada
Skada:AddLoadableModule(
    "Themes",
    "Adds a set of standard themes to Skada. Custom themes can also be used.",
    function(Skada, L)
        if Skada:IsDisabled("Themes") then
            return
        end

        local mod = Skada:NewModule(L["Themes"])
        local _ipairs, tinsert, tremove = ipairs, table.insert, table.remove

        local themes = {
            {
                name = "Skada default (Legion)",
                barspacing = 0,
                bartexture = "BantoBar",
                barfont = "Accidental Presidency",
                barfontflags = "",
                barfontsize = 13,
                barheight = 18,
                barwidth = 240,
                barorientation = 1,
                barcolor = {r = 0.3, g = 0.3, b = 0.8, a = 1},
                barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
                barslocked = false,
                clickthrough = false,
                classcolorbars = true,
                classcolortext = false,
                classicons = true,
                roleicons = false,
                showself = true,
                buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
                title = {
                    textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1},
                    height = 20,
                    font = "Accidental Presidency",
                    fontsize = 13,
                    texture = "Armory",
                    bordercolor = {r = 0, g = 0, b = 0, a = 1},
                    bordertexture = "None",
                    borderthickness = 2,
                    color = {r = 0.3, g = 0.3, b = 0.3, a = 1},
                    fontflags = ""
                },
                background = {
                    height = 200,
                    texture = "Solid",
                    bordercolor = {r = 0, g = 0, b = 0, a = 1},
                    bordertexture = "Blizzard Party",
                    borderthickness = 2,
                    color = {r = 0, g = 0, b = 0, a = 0.4},
                    tile = false,
                    tilesize = 0
                },
                strata = "LOW",
                scale = 1,
                hidden = false,
                enabletitle = true,
                titleset = true,
                display = "bar",
                snapto = true,
                version = 1
            },
            {
                name = "Minimalistic",
                barspacing = 0,
                bartexture = "Armory",
                barfont = "Accidental Presidency",
                barfontflags = "",
                barfontsize = 12,
                barheight = 16,
                barwidth = 240,
                barorientation = 1,
                barcolor = {r = 0.3, g = 0.3, b = 0.8, a = 1},
                barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
                barslocked = false,
                clickthrough = false,
                classcolorbars = true,
                classcolortext = false,
                classicons = true,
                roleicons = false,
                showself = true,
                buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
                title = {
                    textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1},
                    height = 18,
                    font = "Accidental Presidency",
                    fontsize = 12,
                    texture = "Armory",
                    bordercolor = {r = 0, g = 0, b = 0, a = 1},
                    bordertexture = "None",
                    borderthickness = 0,
                    color = {r = 0.6, g = 0.6, b = 0.8, a = 1},
                    fontflags = ""
                },
                background = {
                    height = 195,
                    texture = "None",
                    bordercolor = {r = 0, g = 0, b = 0, a = 1},
                    bordertexture = "Blizzard Party",
                    borderthickness = 0,
                    color = {r = 0, g = 0, b = 0, a = 0.4},
                    tile = false,
                    tilesize = 0
                },
                strata = "LOW",
                scale = 1,
                hidden = false,
                enabletitle = true,
                titleset = true,
                display = "bar",
                snapto = true,
                version = 1
            },
            {
                name = "All glowy 'n stuff",
                barspacing = 0,
                bartexture = "LiteStep",
                barfont = "ABF",
                barfontflags = "",
                barfontsize = 12,
                barheight = 16,
                barwidth = 240,
                barorientation = 1,
                barcolor = {r = 0.3, g = 0.3, b = 0.8, a = 1},
                barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
                barslocked = false,
                clickthrough = false,
                classcolorbars = true,
                classcolortext = false,
                classicons = true,
                roleicons = false,
                showself = true,
                buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
                title = {
                    textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1},
                    height = 20,
                    font = "ABF",
                    fontsize = 12,
                    texture = "Aluminium",
                    bordercolor = {r = 0, g = 0, b = 0, a = 1},
                    bordertexture = "None",
                    borderthickness = 0,
                    color = {r = 0.6, g = 0.6, b = 0.8, a = 1},
                    fontflags = ""
                },
                background = {
                    height = 195,
                    texture = "None",
                    bordercolor = {r = 0.9, g = 0.9, b = 0.5, a = 0.6},
                    bordertexture = "Glow",
                    borderthickness = 5,
                    color = {r = 0, g = 0, b = 0, a = 0.4},
                    tile = false,
                    tilesize = 0
                },
                strata = "LOW",
                scale = 1,
                hidden = false,
                enabletitle = true,
                titleset = true,
                display = "bar",
                snapto = true
            },
            {
                name = "Recount",
                barspacing = 0,
                bartexture = "BantoBar",
                barfont = "Arial Narrow",
                barfontflags = "",
                barfontsize = 12,
                barheight = 18,
                barwidth = 240,
                barorientation = 1,
                barcolor = {r = 0.3, g = 0.3, b = 0.8, a = 1},
                barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
                barslocked = false,
                clickthrough = false,
                classcolorbars = true,
                classcolortext = false,
                classicons = true,
                roleicons = false,
                showself = true,
                buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
                title = {
                    textcolor = {r = 1, g = 1, b = 1, a = 1},
                    height = 18,
                    font = "Arial Narrow",
                    fontsize = 12,
                    texture = "Gloss",
                    bordercolor = {r = 0, g = 0, b = 0, a = 1},
                    bordertexture = "None",
                    borderthickness = 0,
                    color = {r = 1, g = 0, b = 0, a = 0.75},
                    fontflags = ""
                },
                background = {
                    height = 150,
                    texture = "Solid",
                    bordercolor = {r = 0.9, g = 0.9, b = 0.5, a = 0.6},
                    bordertexture = "None",
                    borderthickness = 5,
                    color = {r = 0, g = 0, b = 0, a = 0.4},
                    tile = false,
                    tilesize = 0
                },
                strata = "LOW",
                scale = 1,
                hidden = false,
                enabletitle = true,
                titleset = true,
                display = "bar",
                snapto = true
            }
        }

        local selectedwindow, selectedtheme
        local savewindow, savename, deletetheme

        local options = {
            type = "group",
            name = L["Themes"],
            args = {
                header2 = {
                    type = "header",
                    name = L["Apply theme"],
                    order = 1,
                    width = "full"
                },
                applytheme = {
                    type = "select",
                    name = L["Theme"],
                    order = 1.1,
                    width = "full",
                    values = function()
                        local list = {}
                        for i, theme in _ipairs(themes) do
                            list[theme.name] = theme.name
                        end
                        if Skada.db.global.themes then
                            for i, theme in _ipairs(Skada.db.global.themes) do
								if theme.name then list[theme.name] = theme.name end
                            end
                        end
                        return list
                    end,
                    get = function() return selectedtheme end,
                    set = function(_, name) selectedtheme = name end
                },
                applywindow = {
                    type = "select",
                    name = L["Window"],
                    order = 1.2,
                    width = "full",
                    values = function()
                        local list = {}
                        for i, win in _ipairs(Skada:GetWindows()) do
                            list[win.db.name] = win.db.name
                        end
                        return list
                    end,
                    get = function() return selectedwindow end,
                    set = function(_, name) selectedwindow = name end
                },
                applybutton = {
                    type = "execute",
                    name = APPLY,
                    order = 1.3,
                    width = "full",
                    func = function()
                        if selectedwindow and selectedtheme then
                            local thetheme = nil
                            for i, theme in _ipairs(themes) do
                                if theme.name == selectedtheme then
                                    thetheme = theme
                                    break
                                end
                            end
                            if Skada.db.global.themes then
                                for i, theme in _ipairs(Skada.db.global.themes) do
                                    if theme.name == selectedtheme then
                                        thetheme = theme
                                        break
                                    end
                                end
                            end

                            if thetheme then
                                for _, win in _ipairs(Skada:GetWindows()) do
                                    if win.db.name == selectedwindow then
                                        Skada:tcopy(win.db, thetheme, {"name", "modeincombat", "display", "set", "mode", "wipemode", "returnaftercombat", "x", "y", "snapped"})
                                        Skada:ApplySettings()
                                        Skada:Print(L["Theme applied!"])
                                    end
                                end
                            end
                        end
                        selectedwindow, selectedtheme = nil, nil
                    end
                },
                header3 = {
                    type = "header",
                    name = L["Save theme"],
                    order = 2,
                    width = "full"
                },
                savewindow = {
                    type = "select",
                    name = L["Window"],
                    order = 2.1,
                    width = "full",
                    values = function()
                        local list = {}
                        for i, win in _ipairs(Skada:GetWindows()) do
                            list[win.db.name] = win.db.name
                        end
                        return list
                    end,
                    get = function() return savewindow end,
                    set = function(_, name) savewindow = name end
                },
                savenametext = {
                    type = "input",
                    name = NAME,
                    desc = L["Name of your new theme."],
                    order = 2.2,
                    width = "full",
                    get = function() return savename end,
                    set = function(_, val) savename = val end
                },
                savebutton = {
                    type = "execute",
                    name = SAVE,
                    order = 2.3,
                    width = "full",
                    func = function()
                        for i, win in _ipairs(Skada:GetWindows()) do
                            if win.db.name == savewindow then
                                Skada.db.global.themes = Skada.db.global.themes or {}
                                local theme = {}
                                Skada:tcopy(theme, win.db, {"name", "snapped", "x", "y", "point"})
                                theme.name = savename or win.db.name
                                tinsert(Skada.db.global.themes, theme)
                            end
                        end
                        savewindow = nil
                        savename = nil
                    end
                },
                header4 = {
                    type = "header",
                    name = L["Delete theme"],
                    order = 3,
                    width = "full"
                },
                deltheme = {
                    type = "select",
                    name = L["Theme"],
                    order = 3.1,
                    width = "full",
                    values = function()
                        local list = {}
                        if Skada.db.global.themes then
                            for i, theme in _ipairs(Skada.db.global.themes) do
								if theme.name then list[theme.name] = theme.name end
                            end
                        end
                        return list
                    end,
                    get = function() return deletetheme end,
                    set = function(_, name) deletetheme = name end
                },
                deletebutton = {
                    type = "execute",
                    name = DELETE,
                    order = 3.2,
                    width = "full",
                    func = function()
                        if Skada.db.global.themes then
                            for i, theme in _ipairs(Skada.db.global.themes) do
                                if theme.name == deletetheme then
                                    tremove(Skada.db.global.themes, i)
                                    break
                                end
                            end
                        end
                        deletetheme = nil
                    end
                }
            }
        }

        function mod:OnInitialize()
			if not Skada.db.global.themes then
				Skada.db.global.themes = {}
				if type(Skada.db.profile.themes) == "table" then
					Skada:tcopy(Skada.db.global.themes, Skada.db.profile.themes)
					Skada.db.profile.themes = nil
				end
			end
            Skada.options.args.modules.args.themes = options
        end
    end
)