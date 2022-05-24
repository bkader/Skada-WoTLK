local Skada = Skada

local L = LibStub("AceLocale-3.0"):GetLocale("Skada")
local ACD = LibStub("AceConfigDialog-3.0")
local ACR = LibStub("AceConfigRegistry-3.0")

local fmt = string.format
local next = next

-- references: windows, modes
local windows = nil
local modes = nil

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
		color = {r = 0.3, g = 0.3, b = 0.3, a = 1},
		texture = "Armory",
		textcolor = {r = 0.9, g = 0.9, b = 0.9, a = 1},
		bordercolor = {r = 0, g = 0, b = 0, a = 1},
		bordertexture = "None",
		borderthickness = 2,
		borderinsets = 0,
		toolbar = 1,
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
	useframe = true
}

local windefaultscopy = {}
Skada.tCopy(windefaultscopy, Skada.windowdefaults)

Skada.defaults = {
	profile = {
		reset = {instance = 1, join = 3, leave = 1},
		icon = {radius = 80, minimapPos = 195},
		numberformat = 1,
		decimals = 1,
		setformat = 3,
		setnumber = true,
		numbersystem = 1,
		brackets = 1,
		separator = 1,
		showranks = true,
		setstokeep = 15,
		setslimit = 15,
		memorycheck = true,
		tooltips = true,
		tooltippos = "smart",
		tooltiprows = 3,
		informativetooltips = true,
		timemesure = 2,
		hidedisables = true,
		mergepets = true,
		feed = "",
		updatefrequency = 0.5,
		minsetlength = 5,
		totalflag = 0x10,
		modules = {},
		columns = {},
		toast = {spawn_point = "BOTTOM", duration = 5, opacity = 0.75},
		report = {mode = "Damage", set = "current", channel = "Say", chantype = "preset", number = 10},
		modulesBlocked = {
			["Avoidance & Mitigation"] = true,
			["CC Breaks"] = true,
			["Damage Done By Spell"] = true,
			["DTPS"] = true,
			["Enemy Healing Done"] = true,
			["Healing Done By Spell"] = true,
			["Healing Taken"] = true,
			["Healthstones"] = true,
			["HPS"] = true,
			["Total Healing"] = true,
			["Improvement"] = true,
			["My Spells"] = true,
			["Overhealing"] = true,
			["Overkill"] = true,
			["Project Ascension"] = true,
			["Player vs. Player"] = true,
			["Themes"] = true,
			["Useful Damage"] = true
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

local function GetValue(i)
	return Skada.db.profile[i[#i]]
end

local function SetValue(i, val)
	Skada.db.profile[i[#i]] = val
	Skada:ApplySettings()

	if i[#i] == "showtotals" then
		Skada:Wipe()
		Skada:UpdateDisplay(true)
	elseif i[#i] == "syncoff" then
		Skada:SetupNetwork(val ~= true)
	end
end

Skada.options = {
	type = "group",
	name = fmt("Skada |cffffffff%s|r", Skada.version),
	get = GetValue,
	set = SetValue,
	args = {
		windows = {
			type = "group",
			name = L["Windows"],
			desc = fmt(L["Options for %s."], L["Windows"]),
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
							set = function(_, val)
								if val and val:trim() ~= "" then
									newwindow = val
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
				}
			}
		},
		generaloptions = {
			type = "group",
			name = L["General Options"],
			desc = fmt(L["Options for %s."], L["General Options"]),
			childGroups = "tab",
			order = 20,
			args = {
				general = {
					type = "group",
					name = L["General"],
					desc = fmt(L["General options for %s."], "Skada"),
					order = 10,
					args = {
						mmbutton = {
							type = "toggle",
							name = L["Show minimap button"],
							desc = L["Toggles showing the minimap button."],
							order = 10,
							get = function()
								return not Skada.db.profile.icon.hide
							end,
							set = function()
								Skada.db.profile.icon.hide = not Skada.db.profile.icon.hide
								Skada:RefreshMMButton()
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
							name = L["Always keep boss fights"],
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
							set = function(_, val)
								Skada.db.profile.hidecombat = val or nil
								if Skada.db.profile.hidecombat then
									Skada.db.profile.showcombat = nil
								end
								Skada:ApplySettings()
							end
						},
						showcombat = {
							type = "toggle",
							name = L["Show in combat"],
							desc = L["Shows Skada's window when in combat."],
							order = 90,
							set = function(_, val)
								Skada.db.profile.showcombat = val or nil
								if Skada.db.profile.showcombat then
									Skada.db.profile.hidecombat = nil
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
							desc = fmt(L["Options for %s."], L["Tooltips"]),
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
										return not Skada.db.profile.tooltips
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
										return not Skada.db.profile.tooltips
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
										return not Skada.db.profile.tooltips
									end
								}
							}
						}
					}
				},
				format = {
					type = "group",
					name = L["Format"],
					desc = fmt(L["Format options for %s."], "Skada"),
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
							values = {",", ".", ";", "-", "|", "/", "\\", "~", L["None"]},
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
						}
					}
				},
				advanced = {
					type = "group",
					name = L["Advanced"],
					desc = fmt(L["Advanced options for %s."], "Skada"),
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
						setstokeep = {
							type = "range",
							name = L["Segments to keep"],
							desc = L["The number of fight segments to keep. Persistent segments are not included in this."],
							min = 1,
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
						memorycheck = {
							type = "toggle",
							name = L["Memory Check"],
							desc = function() return fmt(L["Checks memory usage and warns you if it is greater than or equal to %dmb."], 10 + (Skada.db.profile.setstokeep + Skada.db.profile.setslimit) * 2) end,
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
		},
		columns = {
			type = "group",
			name = L["Columns"],
			desc = fmt(L["Options for %s."], L["Columns"]),
			childGroups = "select",
			order = 30,
			args = {}
		},
		resetoptions = {
			type = "group",
			name = L["Data Resets"],
			desc = fmt(L["Options for %s."], L["Data Resets"]),
			order = 40,
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
					get = GetValue,
					set = SetValue
				}
			}
		},
		modules = {
			type = "group",
			name = L["Modules Options"],
			desc = fmt(L["Options for %s."], L["Modules"]),
			order = 50,
			width = "double",
			get = function(i)
				return Skada.db.profile.modules[i[#i]]
			end,
			set = function(i, val)
				Skada.db.profile.modules[i[#i]] = val or nil
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
					name = APPLY,
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
					get = function(i)
						return Skada.db.profile.modulesBlocked[i[#i]]
					end,
					set = function(i, val)
						Skada.db.profile.modulesBlocked[i[#i]] = val
						Skada.options.args.modules.args.apply.disabled = nil
					end,
					args = {}
				}
			}
		},
		tweaks = {
			type = "group",
			name = L["Tweaks"],
			desc = fmt(L["Options for %s."], L["Tweaks"]),
			childGroups = "tab",
			order = 950,
			args = {
				general = {
					type = "group",
					name = L["General"],
					desc = fmt(L["General options for %s."], L["Tweaks"]),
					order = 10,
					args = {
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
					desc = fmt(L["Advanced options for %s."], L["Tweaks"]),
					order = 900,
					args = {
						toast_opt = Skada:GetToastOptions(),
						total_opt = Skada:GetTotalOptions()
					}
				}
			}
		},
		profiles = {
			type = "group",
			name = L["Profiles"],
			desc = fmt(L["Options for %s."], L["Profiles"]),
			childGroups = "tab",
			order = 1000,
			args = {}
		}
	}
}

-- initial options for blizzard interface options
do
	local GetAddOnMetadata = GetAddOnMetadata
	local initOptions

	local function GetInitOptions()
		if not initOptions then
			initOptions = {
				type = "group",
				name = fmt("|T%s:18:18:0:0:32:32:2:30:2:30|t |cffffd200Skada|r |cffffffff%s|r", Skada.logo, Skada.version),
				args = {
					open = {
						type = "execute",
						name = L["Open Config"],
						width = "full",
						order = 0,
						func = Skada.OpenOptions
					}
				}
			}

			-- about args
			local fields = {"Version", "Date", "Author", "Credits", "Donate", "License", "Website", "Discord", "Localizations", "Thanks"}
			for i = 1, #fields do
				local field = fields[i]
				local meta = GetAddOnMetadata("Skada", field) or GetAddOnMetadata("Skada", "X-" .. field)
				if meta then
					if meta:match("^http[s]://[a-zA-Z0-9_/]-%.[a-zA-Z]") or meta:match("^[%w.]+@%w+%.%w+$") then
						meta = format("|cff20ff20%s|r", meta)
					end
					initOptions.args[field] = {
						type = "description",
						name = fmt("\n|cffffd200%s|r:  %s", L[field], meta),
						fontSize = "medium",
						width = "double",
						order = i
					}
				end
			end
		end
		return initOptions
	end

	function Skada:RegisterInitOptions()
		LibStub("AceConfig-3.0"):RegisterOptionsTable("Skada Dialog", GetInitOptions)
		self.optionsFrame = ACD:AddToBlizOptions("Skada Dialog", "Skada")
		self.RegisterInitOptions = nil
	end
end

function Skada:OpenOptions(win)
	if not ACR:GetOptionsTable("Skada") then
		LibStub("AceConfig-3.0"):RegisterOptionsTable("Skada", Skada.options)
		ACD:SetDefaultSize("Skada", 630, 500)
	end

	if not ACD:Close("Skada") then
		HideUIPanel(InterfaceOptionsFrame)
		HideUIPanel(GameMenuFrame)
		if type(win) == "table" then
			ACD:Open("Skada")
			ACD:SelectGroup("Skada", "windows", win.db.name)
		else
			ACD:Open("Skada")
			ACD:SelectGroup("Skada", win or "generaloptions")
		end
	end
end

-- Adds column configuration options for a mode.
function Skada:AddColumnOptions(mod)
	if not (mod and mod.metadata and mod.metadata.columns) then return end

	local db = self.db.profile.columns
	local category = mod.category or L["Other"]

	if not Skada.options.args.columns.args[category] then
		Skada.options.args.columns.args[category] = {type = "group", name = category, args = {}}
	end

	local moduleName = mod.localeName
	if mod.metadata.icon or mod.icon then
		moduleName = fmt("|T%s:18:18:-5:0:32:32:2:30:2:30|t %s", mod.metadata.icon or mod.icon, moduleName)
	end

	local cols = {
		type = "group",
		name = moduleName,
		inline = true,
		get = function(i)
			return mod.metadata.columns[i[#i]]
		end,
		set = function(i, val)
			local colname = i[#i]
			mod.metadata.columns[colname] = val
			db[mod.name .. "_" .. colname] = val
			Skada:UpdateDisplay(true)
		end,
		args = {}
	}

	local order = 0
	for colname in next, mod.metadata.columns do
		local c = mod.name .. "_" .. colname

		-- Set initial value from db if available, otherwise use mod default value.
		if db[c] ~= nil then
			mod.metadata.columns[colname] = db[c]
		end

		-- Add column option.
		local col = {type = "toggle", name = _G[colname] or L[colname]}

		-- proper and reasonable columns order.
		if col.name == L["APS"] or col.name == L["DPS"] or col.name == L["DTPS"] or col.name == L["HPS"] or col.name == L["TPS"] then
			col.order = 6
		elseif col.name == L["sAPS"] or col.name == L["sDPS"] or col.name == L["sDTPS"] or col.name == L["sHPS"] then
			col.order = 8
		elseif col.name == L["Percent"] then
			col.order = 7
		elseif col.name == L["sPercent"] then
			col.order = 9
		else
			order = order + 1
			col.order = order
		end

		cols.args[colname] = col
	end

	Skada.options.args.columns.args[category].args[mod.name] = cols
end

function Skada:AddLoadableModuleCheckbox(mod, name, description)
	self.options.args.modules.args.blocked.args[mod] = {type = "toggle", name = _G[name] or L[name]}
	if description then
		self.options.args.modules.args.blocked.args[mod].desc = L[description]
	end
end

local getScreenWidth
do
	local floor = math.floor
	local GetScreenWidth = GetScreenWidth
	local screenWidth = nil
	function getScreenWidth()
		screenWidth = screenWidth or floor(GetScreenWidth() / 20) * 20
		return screenWidth
	end
end

local modesList = nil
function Skada:FrameSettings(db, include_dimensions)
	local obj = {
		type = "group",
		name = L["Window"],
		desc = format(L["Options for %s."], L["Window"]),
		childGroups = "tab",
		order = 30,
		get = function(i)
			return db[i[#i]]
		end,
		set = function(i, val)
			db[i[#i]] = val
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
						get = function(i)
							return db.background[i[#i]]
						end,
						set = function(i, val)
							db.background[i[#i]] = val
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
								max = getScreenWidth(),
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
						get = function(i)
							return db.background[i[#i]]
						end,
						set = function(i, val)
							db.background[i[#i]] = val
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
								values = function()
									if not modesList then
										modesList = {[""] = L["None"]}
										local modes = Skada:GetModes()
										for i = 1, #modes do
											if modes[i] then
												modesList[modes[i].moduleName] = modes[i].localeName
											end
										end
									end
									return modesList
								end
							},
							wipemode = {
								type = "select",
								name = L["Wipe Mode"],
								desc = L["opt_wipemode_desc"],
								order = 20,
								values = function()
									if not modesList then
										modesList = {[""] = L["None"]}
										local modes = Skada:GetModes()
										for i = 1, #modes do
											if modes[i] then
												modesList[modes[i].moduleName] = modes[i].localeName
											end
										end
									end
									return modesList
								end
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
			set = function(_, val)
				db.sticky = val
				if not db.sticky then
					windows = Skada:GetWindows()
					for i = 1, #windows do
						local win = windows[i]
						if win and win.db and win.db.sticked then
							if win.db.sticked[db.name] then
								win.db.sticked[db.name] = nil
							end
							if next(win.db.sticked) == nil then
								win.db.sticked = nil
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
						windows = Skada:GetWindows()
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
						Skada:ReloadSettings()
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
			max = getScreenWidth(),
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

-------------------------------------------------------------------------------
-- profile import, export and sharing

do
	local collectgarbage = collectgarbage
	local AceGUI

	local function getProfileName(str)
		local header = strsub(str, 1, 64)
		local name = (header:match("%[(.-)%]") or header):gsub("=", ""):gsub("profile", ""):trim()
		return (name ~= "") and name
	end

	local temp = {}
	local function SerializeProfile()
		wipe(temp)
		Skada.tCopy(temp, Skada.db.profile, "modeclicks")
		return Skada:Serialize(true, fmt("%s profile", Skada.db:GetCurrentProfile()), temp)
	end

	local function UnserializeProfile(data)
		return Skada:Deserialize(data, true)
	end

	local function OpenImportExportWindow(title, subtitle, data)
		AceGUI = AceGUI or LibStub("AceGUI-3.0")
		local frame = AceGUI:Create("Frame")
		frame:SetTitle(L["Profile Import/Export"])
		frame:SetStatusText(subtitle)
		frame:SetLayout("Flow")
		frame:SetCallback("OnClose", function(widget)
			AceGUI:Release(widget)
			collectgarbage()
		end)
		frame:SetWidth(535)
		frame:SetHeight(350)

		local editbox = AceGUI:Create("MultiLineEditBox")
		editbox.editBox:SetFontObject(GameFontHighlightSmall)
		editbox:SetLabel(title)
		editbox:SetFullWidth(true)
		editbox:SetFullHeight(true)
		frame:AddChild(editbox)

		if data then
			editbox:DisableButton(true)
			editbox:SetText(data)
			editbox.editBox:SetFocus()
			editbox.editBox:HighlightText()
			editbox:SetCallback("OnLeave", function(widget)
				widget.editBox:HighlightText()
				widget.editBox:SetFocus()
			end)
			editbox:SetCallback("OnEnter", function(widget)
				widget.editBox:HighlightText()
				widget.editBox:SetFocus()
			end)
		else
			editbox:DisableButton(false)
			editbox.editBox:SetFocus()
			editbox.button:SetScript("OnClick", function(widget)
				Skada:ImportProfile(editbox:GetText())
				AceGUI:Release(frame)
				collectgarbage()
			end)
		end
		-- close on escape
		_G["SkadaImportExportFrame"] = frame.frame
		UISpecialFrames[#UISpecialFrames + 1] = "SkadaImportExportFrame"
	end

	function Skada:OpenImport()
		OpenImportExportWindow(
			L["Paste here a profile in text format."],
			L["Press CTRL-V to paste a Skada configuration text."]
		)
	end

	function Skada:ExportProfile()
		OpenImportExportWindow(
			L["This is your current profile in text format."],
			L["Press CTRL-C to copy the configuration to your clipboard."],
			SerializeProfile()
		)
	end

	function Skada:ImportProfile(data)
		if type(data) ~= "string" then
			Skada:Print("Import profile failed, data supplied must be a string.")
			return false
		end

		local profileName = getProfileName(data)
		local success
		success, data = UnserializeProfile(data)

		if not success then
			Skada:Print("Import profile failed:", data)
			return false
		end

		local Old_ReloadSettings = Skada.ReloadSettings
		Skada.ReloadSettings = function(self)
			self.ReloadSettings = Old_ReloadSettings
			self.tCopy(self.db.profile, data)
			self:ReloadSettings()
			ACR:NotifyChange("Skada")
		end
		Skada.db:SetProfile(profileName)
		Skada:ReloadSettings()
		Skada:Wipe()
		Skada:UpdateDisplay(true)
		return true
	end

	function Skada:AdvancedProfile(args)
		if not args then
			return
		end
		args.advanced = {
			type = "group",
			name = L["Advanced"],
			order = 10,
			args = {
				importexport = {
					type = "group",
					name = L["Profile Import/Export"],
					inline = true,
					order = 10,
					args = {
						importbtn = {
							type = "execute",
							name = L["Import Profile"],
							order = 10,
							func = Skada.OpenImport
						},
						exportbtn = {
							type = "execute",
							name = L["Export Profile"],
							order = 20,
							func = Skada.ExportProfile
						}
					}
				}
			}
		}
	end
end