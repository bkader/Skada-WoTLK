local folder, Skada = ...
local Private = Skada.Private

local L = Skada.Locale
local ACD = LibStub("AceConfigDialog-3.0")
local ACR = LibStub("AceConfigRegistry-3.0")

local min, max = math.min, math.max
local next, format = next, format or string.format
local wipe, del = wipe, Private.delTable
local ConfirmDialog = Private.ConfirmDialog
local _

-- references: windows, modes
local windows = Skada.windows
local modes = Skada.modes

Skada.windowdefaults = {
	name = folder,
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
	baroffset = 0,
	barorientation = 1,
	barcolor = {r = 0.3, g = 0.3, b = 0.8, a = 1},
	barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
	spellschoolcolors = true,
	classcolorbars = true,
	classicons = true,
	specicons = true,
	spark = true,
	-- buttons
	buttons = {menu = true, reset = true, report = true, mode = true, segment = true},
	-- title options
	title = {
		height = 20,
		font = "Accidental Presidency",
		fontsize = 13,
		fontflags = "",
		color = {r = 0.15, g = 0.15, b = 0.15, a = 1},
		texture = "Armory",
		textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1},
		bordercolor = {r = 0, g = 0, b = 0, a = 1},
		bordertexture = "None",
		borderthickness = 2,
		borderinsets = 0,
		toolbar = 2,
		spacing = 1
	},
	background = {
		tilesize = 0,
		color = {r = 0, g = 0, b = 0, a = 0.4},
		texture = "Solid",
		bordercolor = {r = 0, g = 0, b = 0, a = 0.5},
		bordertexture = "None",
		borderthickness = 1,
		borderinsets = 0,
		height = 200
	},
	strata = "LOW",
	scale = 1,
	modeincombat = "",
	wipemode = "",
	enabletitle = true,
	titleset = true,
	set = "current",
	display = "bar",
	child = "",
	sticky = true,
	clamped = true,
	tooltippos = "NONE",
	hideauto = 1,
	-- inline bar display
	isusingclasscolors = true,
	height = 30,
	width = 600,
	color = {r = 0.3, g = 0.3, b = 0.3, a = 0.6},
	isusingelvuiskin = true,
	-- data broker display
	textcolor = {r = 0.9, g = 0.9, b = 0.9},
	useframe = true,
	-- legacy display
	baraltcolor = {r = 0.45, g = 0.45, b = 0.8, a = 1},
	menubutton = true,
	barmax = 10
}

local windefaultscopy = {}
Private.tCopy(windefaultscopy, Skada.windowdefaults)

Skada.defaults = {
	profile = {
		firsthit = true,
		hidedisables = true,
		informativetooltips = true,
		memorycheck = true,
		mergepets = true,
		setnumber = true,
		realmless = true,
		showranks = true,
		tooltips = true,
		brackets = 1,
		decimals = 1,
		minsetlength = 5,
		numberformat = 1,
		numbersystem = 1,
		separator = 1,
		setformat = 3,
		setslimit = 15,
		setstokeep = 15,
		smartwait = 3,
		timemesure = 2,
		tooltiprows = 3,
		totalflag = 0x10,
		updatefrequency = 0.5,
		feed = "",
		tooltippos = "smart",
		columns = {},
		icon = {radius = 80, minimapPos = 195},
		modules = {},
		report = {mode = "Damage", set = "current", channel = "Say", chantype = "preset", number = 10},
		reset = {instance = 1, join = 3, leave = 1},
		toast = {spawn_point = "BOTTOM", duration = 5, opacity = 0.75},
		modulesBlocked = {
			["Absorbed Damage"] = true,
			["Avoidance & Mitigation"] = true,
			["CC Breaks"] = true,
			["Casts"] = true,
			["DTPS"] = true,
			["Damage Done By School"] = true,
			["Damage Done By Spell"] = true,
			["Enemy Buffs"] = true,
			["Enemy Debuffs"] = true,
			["Enemy Healing Done"] = true,
			["HPS"] = true,
			["Healing Done By Spell"] = true,
			["Healing Taken"] = true,
			["Healthstones"] = true,
			["Improvement"] = true,
			["Killing Blows"] = true,
			["My Spells"] = true,
			["Overhealing"] = true,
			["Overkill"] = true,
			["Player vs. Player"] = true,
			["Themes"] = true,
			["Total Healing"] = true,
			["Useful Damage"] = true,
			-- display systems
			["Inline Bar Display"] = true,
			["Legacy Bar Display"] = true,
			["Data Text"] = true
		},
		windows = {windefaultscopy}
	}
}

-------------------------------------------------------------------------------

local optionsValues = {
	RESETOPT = {
		L["No"], -- [1]
		L["Yes"], -- [2]
		L["Ask"], -- [3]
	},
	STRATA = {
		BACKGROUND = "BACKGROUND",
		LOW = "LOW",
		MEDIUM = "MEDIUM",
		HIGH = "HIGH",
		DIALOG = "DIALOG",
		FULLSCREEN = "FULLSCREEN",
		FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG"
	},
	AUTOHIDE = {
		L["None"], -- [1]
		L["While in combat"], -- [2]
		L["While out of combat"], -- [3]
		L["While not in a group"], -- [4]
		L["While inside an instance"], -- [5]
		L["While not inside an instance"], -- [6]
		L["In Battlegrounds"], -- [7]
	},
	CHILDMODE = {
		L["All"],  -- [1]
		L["Segment"],  -- [2]
		L["Mode"], -- [3]
	},
	TOOLTIPPOS = {
		NONE = L["None"],
		BOTTOM = L["Bottom"],
		BOTTOMLEFT = L["Bottom Left"],
		BOTTOMRIGHT = L["Bottom Right"],
		TOP = L["Top"],
		TOPLEFT = L["Top Left"],
		TOPRIGHT = L["Top Right"],
	}
}

local newdisplay = "bar"
local newwindow = nil

local options = Skada.options

options.get = function(info)
	return Skada.profile[info[#info]]
end

options.set = function(info, value)
	local key = info[#info]
	Skada.profile[key] = value
	Skada:ApplySettings()

	if key == "showtotals" then
		Skada:Wipe()
		Skada:UpdateDisplay(true)
	elseif key == "syncoff" then
		Skada:RegisterComms(value ~= true)
	elseif key == "setstokeep" or key == "setslimit" then
		Skada.maxsets = Skada.profile.setstokeep + Skada.profile.setslimit
		Skada.maxmeme = min(60, max(30, Skada.maxsets + 10))
	elseif key == "sortmodesbyusage" then
		if not value then -- clear the table.
			Skada.profile.modeclicks = del(Skada.profile.modeclicks)
		end
	end
end

-- windows options
local tremove = Private.tremove
local function delete_all_windows()
	local win = tremove(windows)
	while win do
		win:Destroy()
		win = tremove(windows)
	end

	local wins = Skada.profile.windows
	win = tremove(wins)
	while win do
		Skada.options.args.windows.args[win.name] = del(Skada.options.args.windows.args[win.name], true)
		win = tremove(wins)
	end
	Skada:NotifyChange()
	Skada:CleanGarbage()
end

options.args.windows = {
	type = "group",
	name = L["Windows"],
	desc = format(L["Options for %s."], L["Windows"]),
	order = 10,
	args = {
		create = {
			type = "group",
			name = L["Create Window"],
			inline = true,
			order = 0,
			args = {
				name = {
					type = "input",
					name = L["Window Name"],
					desc = L["Enter the name for the new window."],
					order = 10,
					get = function() return newwindow end,
					set = function(_, value)
						if value and value:trim() ~= "" then
							newwindow = value
						end
					end
				},
				display = {
					type = "select",
					name = L["Display System"],
					desc = L["Choose the system to be used for displaying data in this window."],
					order = 20,
					values = function()
						local list = {}
						for name, display in next, Skada.displays do
							list[name] = display.localeName
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
				exec = {
					type = "execute",
					name = L["Create"],
					width = "double",
					order = 30,
					disabled = function() return (newdisplay == nil or newwindow == nil) end,
					func = function()
						if newdisplay and newwindow then
							Skada:CreateWindow(newwindow, nil, newdisplay)
							newdisplay = "bar"
							newwindow = nil
						end
					end
				}
			}
		},
		delete = {
			type = "execute",
			name = L["Delete All Windows"],
			width = "full",
			order = 1,
			disabled = function() return (not windows or #windows <= 0) end,
			func = function()
				ConfirmDialog(L["Are you sure you want to delete all windows?"], delete_all_windows)
			end
		}
	}
}

-- general options
options.args.generaloptions = {
	type = "group",
	name = L["General Options"],
	desc = format(L["Options for %s."], L["General Options"]),
	childGroups = "tab",
	order = 20,
	args = {
		general = {
			type = "group",
			name = L["General"],
			desc = format(L["General options for %s."], folder),
			order = 10,
			args = {
				mmbutton = {
					type = "toggle",
					name = L["Show minimap button"],
					desc = L["Toggles showing the minimap button."],
					order = 10,
					get = function()
						return not Skada.profile.icon.hide
					end,
					set = function()
						Skada.profile.icon.hide = not Skada.profile.icon.hide
						Private.RefreshButton()
					end
				},
				mergepets = {
					type = "toggle",
					name = L["Merge pets"],
					desc = L["Merges pets with their owners. Changing this only affects new data."],
					order = 20
				},
				showtotals = {
					type = "toggle",
					name = L["Show totals"],
					desc = L["Shows a extra row with a summary in certain modes."],
					order = 30
				},
				onlykeepbosses = {
					type = "toggle",
					name = L["Only keep boss fighs"],
					desc = L["Boss fights will be kept with this on, and non-boss fights are discarded."],
					order = 40
				},
				alwayskeepbosses = {
					type = "toggle",
					name = L["Always save boss fights"],
					desc = L["Boss fights will be kept with this on and will not be affected by Skada reset."],
					order = 50
				},
				hidesolo = {
					type = "toggle",
					name = L["Hide when solo"],
					desc = L["Hides Skada's window when not in a party or raid."],
					order = 60
				},
				hidepvp = {
					type = "toggle",
					name = L["Hide in PvP"],
					desc = L["Hides Skada's window when in Battlegrounds/Arenas."],
					order = 70
				},
				hidecombat = {
					type = "toggle",
					name = L["Hide in combat"],
					desc = L["Hides Skada's window when in combat."],
					order = 80,
					set = function(_, value)
						Skada.profile.hidecombat = value or nil
						if Skada.profile.hidecombat then
							Skada.profile.showcombat = nil
						end
						Skada:ApplySettings()
					end
				},
				showcombat = {
					type = "toggle",
					name = L["Show in combat"],
					desc = L["Shows Skada's window when in combat."],
					order = 90,
					set = function(_, value)
						Skada.profile.showcombat = value or nil
						if Skada.profile.showcombat then
							Skada.profile.hidecombat = nil
						end
						Skada:ApplySettings()
					end
				},
				hidedisables = {
					type = "toggle",
					name = L["Disable while hidden"],
					desc = L["Skada will not collect any data when automatically hidden."],
					order = 100
				},
				sortmodesbyusage = {
					type = "toggle",
					name = L["Sort modes by usage"],
					desc = L["The mode list will be sorted to reflect usage instead of alphabetically."],
					order = 110
				},
				showranks = {
					type = "toggle",
					name = L["Show rank numbers"],
					desc = L["Shows numbers for relative ranks for modes where it is applicable."],
					order = 120
				},
				showself = {
					type = "toggle",
					name = L["Always show self"],
					desc = L["opt_showself_desc"],
					order = 130
				},
				reportlinks = {
					type = "toggle",
					name = L["Links in reports"],
					desc = L["When possible, use links in the report messages."],
					order = 140
				},
				autostop = {
					type = "toggle",
					name = L["Autostop"],
					desc = L["opt_autostop_desc"],
					order = 150
				},
				tentativecombatstart = {
					type = "toggle",
					name = L["Aggressive combat detection"],
					desc = L["opt_tentativecombatstart_desc"],
					order = 160
				},
				sep_850 = {
					type = "description",
					name = " ",
					width = "full",
					order = 850
				},
				tooltips = {
					type = "group",
					name = L["Tooltips"],
					desc = format(L["Options for %s."], L["Tooltips"]),
					inline = true,
					order = 900,
					args = {
						tooltips = {
							type = "toggle",
							name = L["Show Tooltips"],
							desc = L["Shows tooltips with extra information in some modes."],
							order = 1
						},
						informativetooltips = {
							type = "toggle",
							name = L["Informative Tooltips"],
							desc = L["Shows subview summaries in the tooltips."],
							order = 2,
							disabled = function()
								return not Skada.profile.tooltips
							end
						},
						tooltiprows = {
							type = "range",
							name = L["Subview Rows"],
							desc = L["The number of rows from each subview to show when using informative tooltips."],
							order = 3,
							min = 1,
							max = 10,
							step = 1,
							disabled = function()
								return not Skada.profile.tooltips
							end
						},
						tooltippos = {
							type = "select",
							name = L["Tooltip Position"],
							desc = L["Position of the tooltips."],
							order = 4,
							values = {
								["default"] = L["Default"],
								["smart"] = L["Smart"],
								["topright"] = L["Top Right"],
								["topleft"] = L["Top Left"],
								["bottomright"] = L["Bottom Right"],
								["bottomleft"] = L["Bottom Left"],
								["cursor"] = L["Follow Cursor"]
							},
							disabled = function()
								return not Skada.profile.tooltips
							end
						}
					}
				}
			}
		},
		format = {
			type = "group",
			name = L["Format"],
			desc = format(L["Format options for %s."], folder),
			order = 20,
			args = {
				numberformat = {
					type = "select",
					name = L["Number format"],
					desc = L["Controls the way large numbers are displayed."],
					values = {[1] = L["Condensed"], [2] = L["Comma"], [3] = L["Detailed"]},
					order = 10
				},
				numbersystem = {
					type = "select",
					name = L["Numeral system"],
					desc = L["Select which numeral system to use."],
					values = {[1] = L["Auto"], [2] = L["Western"], [3] = L["East Asia"]},
					order = 20
				},
				brackets = {
					type = "select",
					name = L["Brackets"],
					desc = L["Choose which type of brackets to use."],
					values = {"(", "{", "[", "<", L["None"]},
					order = 30
				},
				separator = {
					type = "select",
					name = L["Separator"],
					desc = L["Choose which character is used to separator values between brackets."],
					values = {",", ".", ";", "-", "\124", "/", "\\", "~", L["None"]},
					order = 40
				},
				decimals = {
					type = "range",
					name = L["Number of decimals"],
					desc = L["Controls the way percentages are displayed."],
					min = 0,
					max = 3,
					step = 1,
					width = "double",
					order = 50
				},
				setformat = {
					type = "select",
					name = L["Set Format"],
					desc = L["Controls the way set names are displayed."],
					width = "double",
					values = Skada:SetLabelFormats(),
					order = 60
				},
				setnumber = {
					type = "toggle",
					name = L["Number set duplicates"],
					desc = L["Append a count to set names with duplicate mob names."],
					order = 70
				},
				translit = {
					type = "toggle",
					name = L["Transliterate"],
					desc = L["Converts Cyrillic letters into Latin letters."],
					order = 80
				},
				realmless = {
					type = "toggle",
					name = L["Remove realm name"],
					desc = L["opt_realmless_desc"],
					order = 90
				}
			}
		},
		advanced = {
			type = "group",
			name = L["Advanced"],
			desc = format(L["Advanced options for %s."], folder),
			order = 30,
			args = {
				timemesure = {
					type = "select",
					name = L["Time Measure"],
					desc = L["opt_timemesure_desc"],
					values = {[1] = L["Activity Time"], [2] = L["Effective Time"]},
					order = 10
				},
				feed = {
					type = "select",
					name = L["Data Feed"],
					desc = L["opt_feed_desc"],
					values = function()
						local list = {[""] = L["None"]}
						local feeds = Skada:GetFeeds()
						for name in next, feeds do
							list[name] = name
						end
						return list
					end,
					order = 20
				},
				setscount = {
					type = "header",
					name = function() return format("%s: \124cffffffff%d\r", L["All Segments"], Skada.maxsets) end,
					order = 200
				},
				setstokeep = {
					type = "range",
					name = L["Segments to keep"],
					desc = L["The number of fight segments to keep. Persistent segments are not included in this."],
					min = 0,
					max = 25,
					step = 1,
					order = 210
				},
				setslimit = {
					type = "range",
					name = L["Persistent segments"],
					desc = L["The number of persistent fight segments to keep."],
					min = 0,
					max = 25,
					step = 1,
					order = 220
				},
				empty_1 = {
					type = "description",
					name = " ",
					width = "full",
					order =  300
				},
				updatefrequency = {
					type = "range",
					name = L["Update frequency"],
					desc = L["How often windows are updated. Shorter for faster updates. Increases CPU usage."],
					min = 0.05,
					max = 3,
					step = 0.01,
					order = 310
				},
				minsetlength = {
					type = "range",
					name = L["Minimum segment length"],
					desc = L["The minimum length required in seconds for a segment to be saved."],
					min = 3,
					max = 30,
					step = 1,
					order = 320
				},
				empty_2 = {
					type = "description",
					name = " ",
					width = "full",
					order =  400
				},
				memorycheck = {
					type = "toggle",
					name = L["Memory Check"],
					desc = function() return format(L["Checks memory usage and warns you if it is greater than or equal to %dmb."], Skada.maxmeme) end,
					order = 410
				},
				syncoff = {
					type = "toggle",
					name = L["Disable Comms"],
					order = 420
				}
			}
		}
	}
}

-- columns options
options.args.columns = {
	type = "group",
	name = L["Columns"],
	desc = format(L["Options for %s."], L["Columns"]),
	childGroups = "select",
	order = 30,
	args = {}
}

-- rest options
options.args.resetoptions = {
	type = "group",
	name = L["Data Resets"],
	desc = format(L["Options for %s."], L["Data Resets"]),
	order = 40,
	get = function(info)
		return Skada.profile.reset[info[#info]]
	end,
	set = function(info, value)
		Skada.profile.reset[info[#info]] = value
	end,
	args = {
		instance = {
			type = "select",
			name = L["Reset on entering instance"],
			desc = L["Controls if data is reset when you enter an instance."],
			order = 1,
			width = "double",
			values = optionsValues.RESETOPT
		},
		join = {
			type = "select",
			name = L["Reset on joining a group"],
			desc = L["Controls if data is reset when you join a group."],
			order = 2,
			width = "double",
			values = optionsValues.RESETOPT
		},
		leave = {
			type = "select",
			name = L["Reset on leaving a group"],
			desc = L["Controls if data is reset when you leave a group."],
			order = 3,
			width = "double",
			values = optionsValues.RESETOPT
		},
		sep = {
			type = "description",
			name = " ",
			order = 4,
			width = "full"
		},
		skippopup = {
			type = "toggle",
			name = L["Skip reset dialog"],
			desc = L["opt_skippopup_desc"],
			descStyle = "inline",
			order = 5,
			width = "double",
			get = options.get,
			set = options.set
		}
	}
}

-- modules options
options.args.modules = {
	type = "group",
	name = L["Modules Options"],
	desc = format(L["Options for %s."], L["Modules"]),
	order = 50,
	width = "double",
	get = function(info)
		return Skada.profile.modules[info[#info]]
	end,
	set = function(info, value)
		Skada.profile.modules[info[#info]] = value or nil
		Skada:ApplySettings()
	end,
	args = {
		header = {
			type = "header",
			name = L["Disabled Modules"],
			order = 10
		},
		apply = {
			type = "execute",
			name = L["Apply"],
			width = "full",
			func = ReloadUI,
			confirm = function() return L["This change requires a UI reload. Are you sure?"] end,
			disabled = true,
			order = 20
		},
		blocked = {
			type = "group",
			name = L["Tick the modules you want to disable."],
			inline = true,
			order = 30,
			get = function(info)
				Skada.profile.modulesBlocked = Skada.profile.modulesBlocked or {}
				return Skada.profile.modulesBlocked[info[#info]]
			end,
			set = function(info, value)
				Skada.profile.modulesBlocked[info[#info]] = value
				options.args.modules.args.apply.disabled = nil
			end,
			args = {
				modes_header = {
					type = "header",
					name = L["Skada: Modes"],
					order = 0
				},
				display_header = {
					type = "header",
					name = L["Display System"],
					order = 900
				}
			}
		},
		enableall = {
			type = "execute",
			name = L["Enable All"],
			func = function()
				for name in pairs(options.args.modules.args.blocked.args) do
					if Skada.defaults.profile.modulesBlocked[name] then
						Skada.profile.modulesBlocked[name] = false
					else
						Skada.profile.modulesBlocked[name] = nil
					end
				end
				options.args.modules.args.apply.disabled = nil
			end,
			order = 40,
		},
		disable = {
			type = "execute",
			name = L["Disable All"],
			func = function()
				for name in pairs(options.args.modules.args.blocked.args) do
					Skada.profile.modulesBlocked[name] = true
				end
				options.args.modules.args.apply.disabled = nil
			end,
			order = 50,
		}
	}
}

-- tweaks options
options.args.tweaks = {
	type = "group",
	name = L["Tweaks"],
	desc = format(L["Options for %s."], L["Tweaks"]),
	childGroups = "tab",
	order = 950,
	args = {
		general = {
			type = "group",
			name = L["General"],
			desc = format(L["General options for %s."], L["Tweaks"]),
			order = 10,
			args = {
				firsthit = {
					type = "toggle",
					name = L["First hit"],
					desc = L["opt_tweaks_firsthit_desc"],
					order = 10
				},
				absdamage = {
					type = "toggle",
					name = L["Absorbed Damage"],
					desc = L["Enable this if you want the damage absorbed to be included in the damage done."],
					order = 100
				}
			}
		},
		advanced = {
			type = "group",
			name = L["Advanced"],
			desc = format(L["Advanced options for %s."], L["Tweaks"]),
			order = 900,
			args = {
				smarthalt = {
					type = "group",
					name = L["Smart Stop"],
					desc = format(L["Options for %s."], L["Smart Stop"]),
					order = 10,
					args = {
						smartdesc = {
							type = "description",
							name = L["opt_tweaks_smarthalt_desc"],
							fontSize = "medium",
							order = 10,
							width = "full"
						},
						smartstop = {
							type = "toggle",
							name = L["Enable"],
							order = 20
						},
						smartwait = {
							type = "range",
							name = L["Duration"],
							desc = L["opt_tweaks_smartwait_desc"],
							disabled = function()
								return not Skada.profile.smartstop
							end,
							min = 0,
							max = 10,
							step = 0.01,
							bigStep = 0.1,
							order = 30
						}
					}
				},
				toast_opt = Private.ToastOptions(),
				total_opt = Private.TotalOptions()
			}
		}
	}
}

-- profiles
options.args.profiles = {
	type = "group",
	name = L["Profiles"],
	desc = format(L["Options for %s."], L["Profiles"]),
	childGroups = "tab",
	order = 1000,
	args = {}
}

-- initial options for blizzard interface options
do
	local GetAddOnMetadata = GetAddOnMetadata
	local initOptions

	local function get_init_options()
		if not initOptions then
			initOptions = {
				type = "group",
				name = format("\124T%s:18:18:0:0:32:32:2:30:2:30\124t \124cffffd200Skada\124r \124cffffffff%s\124r", Skada.logo, L["A damage meter."]),
				args = {
					open = {
						type = "execute",
						name = L["Open Config"],
						width = "full",
						order = 0,
						func = Private.OpenOptions
					},
					version = {
						type = "description",
						name = format("\n\124cffffd200%s\124r:  %s", L["Version"], Skada.version),
						fontSize = "medium",
						width = "double",
						order = 10
					},
					date = {
						type = "description",
						name = format("\n\124cffffd200%s\124r:  %s", L["Date"], Skada.date),
						fontSize = "medium",
						width = "double",
						order = 20
					},
					author = {
						type = "description",
						name = format("\n\124cffffd200%s\124r:  %s", L["Author"], Skada.author),
						fontSize = "medium",
						width = "double",
						order = 30
					},
					license = {
						type = "description",
						name = format("\n\124cffffd200%s\124r:  %s", L["License"], GetAddOnMetadata(folder, "X-License")),
						fontSize = "medium",
						width = "double",
						order = 40
					},
					credits = {
						type = "description",
						name = format("\n\124cffffd200%s\124r:  %s", L["Credits"], GetAddOnMetadata(folder, "X-Credits")),
						fontSize = "medium",
						width = "double",
						order = 50
					}
				}
			}
		end
		return initOptions
	end

	function Private.InitOptions()
		Private.InitOptions = nil -- remove it

		local frame_name = format("%s Dialog", folder)
		LibStub("AceConfig-3.0"):RegisterOptionsTable(frame_name, get_init_options)
		Skada.optionsFrame = ACD:AddToBlizOptions(frame_name, folder)
	end
end

function Private.OpenOptions(win)
	if not ACR:GetOptionsTable(folder) then
		LibStub("AceConfig-3.0"):RegisterOptionsTable(folder, options)
		ACD:SetDefaultSize(folder, 630, 500)
	end

	if not ACD:Close(folder) then
		HideUIPanel(InterfaceOptionsFrame)
		HideUIPanel(GameMenuFrame)
		Skada:CloseMenus()

		ACD:Open(folder)
		if type(win) == "table" and win.db then
			ACD:SelectGroup(folder, "windows", win.db.name)
		else
			ACD:SelectGroup(folder, type(win) == "string" and win or "generaloptions")
		end
	end
end

-- Adds column configuration options for a mode.
do
	local col_order = {
		APS = 6, DPS = 6, DTPS = 6, HPS = 6, TPS = 6,
		Percent = 7,
		sAPS = 8, sDPS = 8, sDTPS = 8, sHPS = 8,
		sPercent = 9
	}
	function Skada:AddColumnOptions(mod)
		local metadata = mod and mod.metadata
		local columns = metadata and metadata.columns
		if not columns then return end

		local db = self.profile.columns
		local category = mod.category or "Other"

		if not options.args.columns.args[category] then
			options.args.columns.args[category] = {type = "group", name = L[category], args = {}}
		end

		local moduleName = mod.localeName
		if metadata.icon or mod.icon then
			moduleName = format("\124T%s:18:18:-5:0:32:32:2:30:2:30\124t %s", metadata.icon or mod.icon, moduleName)
		end

		local cols = {
			type = "group",
			name = moduleName,
			inline = true,
			get = function(info)
				return columns[info[#info]]
			end,
			set = function(info, value)
				local colname = info[#info]
				columns[colname] = value
				db[format("%s_%s", mod.name, colname)] = value
				Skada:UpdateDisplay(true)
			end,
			args = {}
		}

		local order = 0
		for colname in next, columns do
			local c = format("%s_%s", mod.name, colname)

			-- Set initial value from db if available, otherwise use mod default value.
			if db[c] ~= nil then
				columns[colname] = db[c]
			end

			-- Add column option.
			local col = {type = "toggle", name = _G[colname] or L[colname]}

			-- proper and reasonable columns order.
			if col_order[colname] then
				col.order = col_order[colname]
			else
				order = order + 1
				col.order = order
			end

			cols.args[colname] = col
		end

		options.args.columns.args[category].args[mod.name] = cols
	end
end

-------------------------------------------------------------------------------
-- frame/window options

do
	local get_screen_width
	do
		local floor = math.floor
		local GetScreenWidth = GetScreenWidth
		local screenWidth = nil
		function get_screen_width()
			screenWidth = screenWidth or floor(GetScreenWidth() * 0.05) * 20
			return screenWidth
		end
	end

	local modesList, modeValues
	function Private.FrameOptions(db, include_dimensions)
		if not modeValues then
			modeValues = function()
				if not modesList then
					modesList = {[""] = L["None"]}
					for i = 1, #modes do
						if modes[i] then
							modesList[modes[i].moduleName] = modes[i].localeName
						end
					end
				end
				return modesList
			end
		end

		local obj = {
			type = "group",
			name = L["Window"],
			desc = format(L["Options for %s."], L["Window"]),
			childGroups = "tab",
			order = 30,
			get = function(info)
				return db[info[#info]]
			end,
			set = function(info, value)
				db[info[#info]] = value
				Skada:ApplySettings(db.name)
			end,
			args = {
				appearance = {
					type = "group",
					name = L["Appearance"],
					desc = format(L["Appearance options for %s."], db.name),
					order = 10,
					args = {
						scale = {
							type = "range",
							name = L["Scale"],
							desc = L["Sets the scale of the window."],
							order = 10,
							width = "double",
							min = 0.5,
							max = 2,
							step = 0.01,
							isPercent = true
						},
						background = {
							type = "group",
							name = L["Background"],
							inline = true,
							order = 20,
							get = function(info)
								return db.background[info[#info]]
							end,
							set = function(info, value)
								db.background[info[#info]] = value
								Skada:ApplySettings(db.name)
							end,
							args = {
								texture = {
									type = "select",
									dialogControl = "LSM30_Background",
									name = L["Background Texture"],
									desc = L["The texture used as the background."],
									order = 10,
									width = "double",
									values = Skada:MediaList("background")
								},
								color = {
									type = "color",
									name = L["Background Color"],
									desc = L["The color of the background."],
									order = 20,
									hasAlpha = true,
									get = function()
										local c = db.background.color or Skada.windowdefaults.background.color
										return c.r, c.g, c.b, c.a
									end,
									set = function(_, r, g, b, a)
										db.background.color = db.background.color or {}
										db.background.color.r = r
										db.background.color.g = g
										db.background.color.b = b
										db.background.color.a = a
										Skada:ApplySettings(db.name)
									end
								},
								tile = {
									type = "toggle",
									name = L["Tile"],
									desc = L["Tile the background texture."],
									order = 30
								},
								tilesize = {
									type = "range",
									name = L["Tile Size"],
									desc = L["The size of the texture pattern."],
									order = 40,
									width = "double",
									min = 0,
									max = get_screen_width(),
									step = 0.1,
									bigStep = 1
								}
							}
						},
						border = {
							type = "group",
							name = L["Border"],
							inline = true,
							order = 30,
							get = function(info)
								return db.background[info[#info]]
							end,
							set = function(info, value)
								db.background[info[#info]] = value
								Skada:ApplySettings(db.name)
							end,
							args = {
								bordertexture = {
									type = "select",
									dialogControl = "LSM30_Border",
									name = L["Border texture"],
									desc = L["The texture used for the borders."],
									order = 10,
									values = Skada:MediaList("border"),
									set = function(_, key)
										db.background.bordertexture = key
										if key == "None" then
											db.background.borderthickness = 0
											db.background.borderinsets = 0
										end
										Skada:ApplySettings(db.name)
									end
								},
								bordercolor = {
									type = "color",
									name = L["Border Color"],
									desc = L["The color used for the border."],
									order = 20,
									hasAlpha = true,
									get = function()
										local c = db.background.bordercolor or Skada.windowdefaults.background.bordercolor
										return c.r, c.g, c.b, c.a
									end,
									set = function(_, r, g, b, a)
										db.background.bordercolor = db.background.bordercolor or {}
										db.background.bordercolor.r = r
										db.background.bordercolor.g = g
										db.background.bordercolor.b = b
										db.background.bordercolor.a = a
										Skada:ApplySettings(db.name)
									end
								},
								borderthickness = {
									type = "range",
									name = L["Border Thickness"],
									desc = L["The thickness of the borders."],
									order = 30,
									min = 0,
									max = 50,
									step = 0.01,
									bigStep = 0.5
								},
								borderinsets = {
									type = "range",
									name = L["Border Insets"],
									desc = L["The distance between the window and its border."],
									order = 40,
									min = -32,
									max = 32,
									step = 0.01,
									bigStep = 1
								}
							}
						}
					}
				},
				position = {
					type = "group",
					name = L["Position"],
					desc = format(L["Position settings for %s."], db.name),
					order = 20,
					args = {
						barslocked = {
							type = "toggle",
							name = L["Lock Window"],
							desc = L["Locks the bar window in place."],
							order = 10
						},
						hidden = {
							type = "toggle",
							name = L["Hide Window"],
							desc = L["Hides the window."],
							order = 20
						},
						clamped = {
							type = "toggle",
							name = L["Clamped To Screen"],
							desc = L["Toggle whether to permit movement out of screen."],
							order = 50
						},
						sep = {
							type = "description",
							name = " ",
							width = "full",
							order = 60
						},
						strata = {
							type = "select",
							name = L["Strata"],
							desc = L["This determines what other frames will be in front of the frame."],
							order = 110,
							values = optionsValues.STRATA
						},
						tooltippos = {
							type = "select",
							name = L["Tooltip Position"],
							desc = L["Position of the tooltips."],
							order = 120,
							values = optionsValues.TOOLTIPPOS,
							get = function()
								return db.tooltippos or "NONE"
							end
						},
						hideauto = {
							type = "select",
							name = L["Auto Hide"],
							values = optionsValues.AUTOHIDE,
							width = "double",
							order = 999
						}
					}
				},
				advanced = {
					type = "group",
					name = L["Advanced"],
					desc = format(L["Advanced options for %s."], db.name),
					order = 30,
					args = {
						switch = {
							type = "group",
							name = L["Mode Switching"],
							desc = format(L["Options for %s."], L["Mode Switching"]),
							inline = true,
							order = 10,
							args = {
								modeincombat = {
									type = "select",
									name = L["Combat Mode"],
									desc = L["opt_combatmode_desc"],
									order = 10,
									values = modeValues
								},
								wipemode = {
									type = "select",
									name = L["Wipe Mode"],
									desc = L["opt_wipemode_desc"],
									order = 20,
									values = modeValues
								},
								returnaftercombat = {
									type = "toggle",
									name = L["Return after combat"],
									desc = L["Return to the previous set and mode after combat ends."],
									order = 30,
									disabled = function() return (db.modeincombat == "" and db.wipemode == "") end
								},
								autocurrent = {
									type = "toggle",
									name = L["Auto switch to current"],
									desc = L["opt_autocurrent_desc"],
									order = 40
								}
							}
						}
					}
				}
			}
		}

		if db.display == "bar" then
			obj.args.position.args.sticky = {
				type = "toggle",
				name = L["Sticky Window"],
				desc = L["Allows the window to stick to other Skada windows."],
				order = 30,
				set = function(_, value)
					db.sticky = value
					if not db.sticky then
						for i = 1, #windows do
							local win = windows[i]
							if win and win.db and win.db.sticked then
								if win.db.sticked[db.name] then
									win.db.sticked[db.name] = nil
								end
								if next(win.db.sticked) == nil then
									win.db.sticked = del(win.db.sticked)
								end
							end
						end
					end
					Skada:ApplySettings(db.name)
				end
			}

			obj.args.position.args.snapto = {
				type = "toggle",
				name = L["Snap to best fit"],
				desc = L["Snaps the window size to best fit when resizing."],
				order = 40
			}

			obj.args.position.args.noresize = {
				type = "toggle",
				name = L["Disable Resize Buttons"],
				desc = L["Resize and lock/unlock buttons won't show up when you hover over the window."],
				order = 51
			}

			obj.args.position.args.nostrech = {
				type = "toggle",
				name = L["Disable stretch button"],
				desc = L["Stretch button won't show up when you hover over the window."],
				order = 52
			}

			obj.args.position.args.botstretch = {
				type = "toggle",
				name = L["Reverse window stretch"],
				desc = L["opt_botstretch_desc"],
				order = 53
			}

			obj.args.advanced.args.childoptions = {
				type = "group",
				name = L["Child Window"],
				inline = true,
				order = 100,
				args = {
					desc = {
						type = "description",
						name = L["A child window will replicate the parent window actions."],
						width = "full",
						order = 0
					},
					child = {
						type = "select",
						name = L["Window"],
						order = 10,
						values = function()
							local list = {[""] = L["None"]}
							for i = 1, #windows do
								local win = windows[i]
								if win and win.db and win.db.name ~= db.name and win.db.child ~= db.name and win.db.display == db.display then
									list[win.db.name] = win.db.name
								end
							end
							return list
						end,
						get = function() return db.child or "" end,
						set = function(_, child)
							db.child = (child == "") and nil or child
							db.childmode = db.child and (db.childmode or 1) or nil
							Private.ReloadSettings()
						end
					},
					childmode = {
						type = "select",
						name = L["Child Window Mode"],
						order = 20,
						values = optionsValues.CHILDMODE,
						get = function() return db.childmode or 1 end,
						disabled = function() return not (db.child and db.child ~= "") end
					}
				}
			}
		end

		if include_dimensions then
			obj.args.position.args.width = {
				type = "range",
				name = L["Width"],
				order = 70,
				min = 100,
				max = get_screen_width(),
				step = 0.01,
				bigStep = 1
			}

			obj.args.position.args.height = {
				type = "range",
				name = L["Height"],
				order = 80,
				min = 16,
				max = 400,
				step = 0.01,
				bigStep = 1
			}
		end

		return obj
	end
end

-------------------------------------------------------------------------------
-- profile import, export and sharing

do
	local ipairs, strmatch, uformat, collectgarbage = ipairs, strmatch, Private.uformat, collectgarbage
	local serialize, deserialize = Private.serialize, Private.deserialize
	local copy, open_window = Private.tCopy, Private.ImportExport
	local serialize_profile = nil

	local function get_profile_name(str)
		str = strmatch(strsub(str, 1, 64), "%[(.-)%]")
		str = str and str:gsub("=", ""):gsub("profile", ""):trim()
		return (str ~= "") and str
	end

	local function check_profile_name(name)
		local profiles = Skada.data:GetProfiles()
		local ProfileExists = function(name)
			if name then
				for _, v in ipairs(profiles) do
					if name == v then
						return true
					end
				end
			end
		end

		name = name or Skada.userName

		local n, i = name, 1
		while ProfileExists(name) do
			i = i + 1
			name = format("%s (%d)", n, i)
		end

		return name
	end

	local temp = {}
	function serialize_profile()
		wipe(temp)
		copy(temp, Skada.profile, "modeclicks")
		temp.__name = Skada.data:GetCurrentProfile()
		return serialize(false, temp)
	end

	local function import_profile(data, name)
		if type(data) ~= "string" then
			Skada:Print("Import profile failed, data supplied must be a string.")
			return false
		end

		local success, profile = deserialize(data)
		if not success or profile.numbersystem == nil then -- sanity check!
			Skada:Print("Import profile failed!")
			return false
		end

		name = name or get_profile_name(data)
		if profile.__name then
			name = name or profile.__name
			profile.__name = nil
		end
		local profileName = check_profile_name(name)

		-- backwards compatibility
		if profile[folder] and type(profile[folder]) == "table" then
			profile = profile[folder]
		end

		local Old_ReloadSettings = Private.ReloadSettings
		Private.ReloadSettings = function()
			Private.ReloadSettings = Old_ReloadSettings
			copy(Skada.profile, profile)
			Private.ReloadSettings()
			Skada:NotifyChange()
		end

		Skada.data:SetProfile(profileName)
		Private.ReloadSettings()
		Skada:Wipe()
		Skada:UpdateDisplay(true)
		return true
	end

	function Skada:ProfileImport()
		return open_window(L["Paste here a profile in text format."], import_profile)
	end

	function Skada:ProfileExport()
		return open_window(L["This is your current profile in text format."], serialize_profile())
	end

	function Private.AdvancedProfile(args)
		if not args then return end
		Private.AdvancedProfile = nil -- remove it
		local CONST_COMM_PROFILE = "PR"

		local Share = {}

		function Share:Enable(receive)
			if receive then
				self.enabled = true
				Skada.AddComm(self, CONST_COMM_PROFILE, "Receive")
			else
				self.enabled = nil
				Skada.RemoveAllComms(self)
			end
		end

		function Share:Receive(sender, profileStr)
			local acceptfunc = function()
				import_profile(profileStr, sender)
				collectgarbage()
				Share:Enable(false) -- disable receiving
				Share.target = nil -- reset target
			end
			ConfirmDialog(uformat(L["opt_profile_received"], sender), acceptfunc)
		end

		function Share:Send(profileStr, target)
			Skada:SendComm("PURR", target, CONST_COMM_PROFILE, profileStr)
		end

		args.advanced = {
			type = "group",
			name = L["Advanced"],
			order = 10,
			args = {
				sharing = {
					type = "group",
					name = L["Network Sharing"],
					inline = true,
					order = 10,
					hidden = function() return Skada.profile.syncoff end,
					args = {
						name = {
							type = "input",
							name = L["Player Name"],
							get = function()
								return Share.target or ""
							end,
							set = function(_, value)
								Share.target = value:trim()
							end,
							order = 10
						},
						send = {
							type = "execute",
							name = L["Send Profile"],
							func = function()
								if Share.target and Share.target ~= "" then
									Share:Send(serialize_profile(), Share.target)
								end
							end,
							disabled = function() return (not Share.target or Share.target == "") end,
							order = 20
						},
						accept = {
							type = "toggle",
							name = L["Accept profiles from other players."],
							get = function() return Share.enabled end,
							set = function() Share:Enable(not Share.enabled) end,
							width = "full",
							order = 30
						}
					}
				},
				importexport = {
					type = "group",
					name = L["Profile Import/Export"],
					inline = true,
					order = 20,
					args = {
						importbtn = {
							type = "execute",
							name = L["Import Profile"],
							order = 10,
							func = Skada.ProfileImport
						},
						exportbtn = {
							type = "execute",
							name = L["Export Profile"],
							order = 20,
							func = Skada.ProfileExport
						}
					}
				}
			}
		}
	end
end
