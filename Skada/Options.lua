assert(Skada, "Skada not found!")

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local fmt = string.format

local windefaultscopy = {}
local resetoptions = {[1] = NO, [2] = YES, [3] = L["Ask"]}
local newdisplay, deletewindow = "bar"

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
	showself = false,
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
	disablehighlight = false,
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
	child = "",
	snapto = false,
	sticky = true,
	sticked = {},
	clamped = true,
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
Skada.tCopy(windefaultscopy, Skada.windowdefaults)

Skada.defaults = {
	profile = {
		reset = {instance = 1, join = 3, leave = 1},
		skippopup = false,
		icon = {hide = false, radius = 80, minimapPos = 195},
		numberformat = 1,
		decimals = 1,
		setformat = 3,
		setnumber = true,
		showranks = true,
		showself = false,
		setstokeep = 15,
		reportlinks = false,
		memorycheck = true,
		tooltips = true,
		tooltippos = "smart",
		tooltiprows = 3,
		informativetooltips = true,
		onlykeepbosses = false,
		alwayskeepbosses = false,
		tentativetimer = 3,
		tentativecombatstart = false,
		timemesure = 2,
		hidesolo = false,
		hidepvp = false,
		hidedisables = true,
		hidecombat = false,
		showcombat = false,
		translit = false,
		mergepets = true,
		shortmenu = true,
		feed = "",
		showtotals = false,
		autostop = false,
		sortmodesbyusage = false,
		updatefrequency = 0.5,
		modules = {},
		columns = {},
		report = {mode = "Damage", set = "current", channel = "Say", chantype = "preset", number = 10},
		modulesBlocked = {
			["Absorbed Damage"] = true,
			["Avoidance & Mitigation"] = true,
			["Damage Done By Spell"] = true,
			["Damage Mitigated"] = true,
			["DTPS"] = true,
			["Enemy Healing Done"] = true,
			["Healing and Overhealing"] = true,
			["Healing Done By Spell"] = true,
			["HPS"] = true,
			["Improvement"] = true,
			["Overhealing"] = true,
			["Overkill"] = true,
			["Themes"] = true
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
				name = _G[colname] or L[colname],
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

function Skada:AddLoadableModuleCheckbox(mod, name, description)
	self.options.args.disabled.args[mod] = {
		type = "toggle",
		name = _G[name] or L[name],
		desc = description and L[description]
	}
end

Skada.options = {
	type = "group",
	name = fmt("Skada |cffffffff%s|r", Skada.version),
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
		windows = {
			type = "group",
			name = L["Windows"],
			desc = fmt(L["Options for %s."], L["Windows"]),
			order = 1,
			args = {
				create = {
					type = "input",
					name = L["Create Window"],
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
					name = L["Display System"],
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
				}
			}
		},
		resetoptions = {
			type = "group",
			name = L["Data Resets"],
			desc = fmt(L["Options for %s."], L["Data Resets"]),
			order = 2,
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
					values = resetoptions
				},
				join = {
					type = "select",
					name = L["Reset on joining a group"],
					desc = L["Controls if data is reset when you join a group."],
					order = 2,
					width = "double",
					values = resetoptions
				},
				leave = {
					type = "select",
					name = L["Reset on leaving a group"],
					desc = L["Controls if data is reset when you leave a group."],
					order = 3,
					width = "double",
					values = resetoptions
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
					desc = L["Enable this if you want Skada to reset without the confirmation dialog."],
					descStyle = "inline",
					order = 5,
					width = "double",
					get = function() return Skada.db.profile.skippopup end,
					set = function() Skada.db.profile.skippopup = not Skada.db.profile.skippopup end
				}
			}
		},
		tooltips = {
			type = "group",
			name = L["Tooltips"],
			desc = fmt(L["Options for %s."], L["Tooltips"]),
			order = 3,
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
					order = 2,
					disabled = function() return not Skada.db.profile.tooltips end
				},
				tooltiprows = {
					type = "range",
					name = L["Subview rows"],
					desc = L["The number of rows from each subview to show when using informative tooltips."],
					order = 3,
					min = 1,
					max = 10,
					step = 1,
					disabled = function() return not Skada.db.profile.tooltips end
				},
				tooltippos = {
					type = "select",
					name = L["Tooltip position"],
					desc = L["Position of the tooltips."],
					order = 4,
					values = {
						["default"] = L["Default"],
						["smart"] = L["Smart"],
						["topright"] = L["Top right"],
						["topleft"] = L["Top left"],
						["bottomright"] = L["Bottom right"],
						["bottomleft"] = L["Bottom left"],
						["cursor"] = L["Follow Cursor"]
					},
					disabled = function() return not Skada.db.profile.tooltips end
				}
			}
		},
		generaloptions = {
			type = "group",
			name = L["General Options"],
			desc = fmt(L["Options for %s."], L["General Options"]),
			order = 4,
			args = {
				mmbutton = {
					type = "toggle",
					name = L["Show minimap button"],
					desc = L["Toggles showing the minimap button."],
					order = 1,
					get = function() return not Skada.db.profile.icon.hide end,
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
				alwayskeepbosses = {
					type = "toggle",
					name = L["Always keep boss fights"],
					desc = L["Boss fights will be kept with this on and will not be affected by Skada reset."],
					order = 6
				},
				hidesolo = {
					type = "toggle",
					name = L["Hide when solo"],
					desc = L["Hides Skada's window when not in a party or raid."],
					order = 7
				},
				hidepvp = {
					type = "toggle",
					name = L["Hide in PvP"],
					desc = L["Hides Skada's window when in Battlegrounds/Arenas."],
					order = 8
				},
				hidecombat = {
					type = "toggle",
					name = L["Hide in combat"],
					desc = L["Hides Skada's window when in combat."],
					order = 9,
					set = function()
						Skada.db.profile.hidecombat = not Skada.db.profile.hidecombat
						if Skada.db.profile.hidecombat then
							Skada.db.profile.showcombat = false
						end
						Skada:ApplySettings()
					end
				},
				showcombat = {
					type = "toggle",
					name = L["Show in combat"],
					desc = L["Shows Skada's window when in combat."],
					order = 10,
					set = function()
						Skada.db.profile.showcombat = not Skada.db.profile.showcombat
						if Skada.db.profile.showcombat then
							Skada.db.profile.hidecombat = false
						end
						Skada:ApplySettings()
					end
				},
				hidedisables = {
					type = "toggle",
					name = L["Disable while hidden"],
					desc = L["Skada will not collect any data when automatically hidden."],
					order = 11
				},
				sortmodesbyusage = {
					type = "toggle",
					name = L["Sort modes by usage"],
					desc = L["The mode list will be sorted to reflect usage instead of alphabetically."],
					order = 12
				},
				showranks = {
					type = "toggle",
					name = L["Show rank numbers"],
					desc = L["Shows numbers for relative ranks for modes where it is applicable."],
					order = 13
				},
				showself = {
					type = "toggle",
					name = L["Always show self"],
					desc = L["Keeps the player shown last even if there is not enough space."],
					order = 14
				},
				autostop = {
					type = "toggle",
					name = L["Autostop"],
					desc = L["Automatically stops the current segment after half of all raid members have died."],
					order = 15
				},
				tentativecombatstart = {
					type = "toggle",
					name = L["Aggressive combat detection"],
					desc = L["Skada usually uses a very conservative (simple) combat detection scheme that works best in raids. With this option Skada attempts to emulate other damage meters. Useful for running dungeons. Meaningless on boss encounters."],
					order = 16
				},
				tentativetimer = {
					type = "range",
					name = L["Tentative Timer"],
					desc = L['The number of seconds Skada should wait after combat start to create a new segment.\n\nOnly works if "Agressive combat detection" is enabled.'],
					order = 17,
					min = 1,
					max = 10,
					step = 0.1,
					bigStep = 1,
					width = "double",
					disabled = function() return not Skada.db.profile.tentativecombatstart end,
					hidden = function() return not Skada.db.profile.tentativecombatstart end
				},
				timemesure = {
					type = "select",
					name = L["Time measure"],
					desc = L.timemesure_desc,
					order = 18,
					width = "double",
					values = {[1] = L["Activity time"], [2] = L["Effective time"]},
					get = function() return Skada.db.profile.timemesure or 1 end
				},
				numberformat = {
					type = "select",
					name = L["Number format"],
					desc = L["Controls the way large numbers are displayed."],
					values = {[1] = L["Condensed"], [2] = L["Comma"], [3] = L["Detailed"]},
					order = 19
				},
				decimals = {
					type = "range",
					name = L["Number of decimals"],
					desc = L["Controls the way percentages are displayed."],
					min = 0,
					max = 3,
					step = 1,
					order = 20
				},
				setformat = {
					type = "select",
					name = L["Set format"],
					desc = L["Controls the way set names are displayed."],
					order = 21,
					width = "double",
					values = Skada:SetLabelFormats()
				},
				setnumber = {
					type = "toggle",
					name = L["Number set duplicates"],
					desc = L["Append a count to set names with duplicate mob names."],
					order = 22
				},
				translit = {
					type = "toggle",
					name = L["Translit"],
					desc = L["Make those russian letters that no one understands to be presented as western letters."],
					order = 23
				},
				feed = {
					type = "select",
					name = L["Data feed"],
					desc = L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."],
					order = 24,
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
					order = 95,
					width = "full"
				},
				reportlinks = {
					type = "toggle",
					name = L["Links in reports"],
					desc = L["When possible, use links in the report messages."],
					order = 96
				},
				memorycheck = {
					type = "toggle",
					name = L["Memory Check"],
					desc = function()
						if Skada.db.profile.setstokeep == 0 then
							return fmt(L["Checks memory usage and warns you if it is greater than or equal to %dmb."], 30)
						end
						return fmt(L["Checks memory usage and warns you if it is greater than or equal to %dmb."], 30 + (Skada.db.profile.setstokeep * 1.25))
					end,
					order = 97
				},
				setstokeep = {
					type = "range",
					name = L["Data segments to keep"],
					desc = L["The number of fight segments to keep. Persistent segments are not included in this."],
					width = "double",
					min = 0,
					max = 30,
					step = 1,
					order = 98
				},
				updatefrequency = {
					type = "range",
					name = L["Update frequency"],
					desc = L["How often windows are updated. Shorter for faster updates. Increases CPU usage."],
					width = "double",
					min = 0.10,
					max = 1,
					step = 0.05,
					bigStep = 0.1,
					order = 99
				}
			}
		},
		columns = {
			type = "group",
			name = L["Columns"],
			desc = fmt(L["Options for %s."], L["Columns"]),
			order = 5,
			args = {}
		},
		disabled = {
			type = "group",
			name = L["Disabled Modules"],
			desc = fmt(L["Options for %s."], L["Disabled Modules"]),
			order = 6,
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
					fontSize = "medium",
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
			desc = fmt(L["Options for %s."], L["Modules"]),
			order = 7,
			width = "double",
			disabled = function()
				return next(Skada.options.args.modules.args) == nil
			end,
			args = {}
		},
		profiles = {
			type = "group",
			name = L["Profiles"],
			desc = fmt(L["Options for %s."], L["Profiles"]),
			childGroups = "tab",
			order = 980,
			args = {}
		},
		about = {
			type = "group",
			name = L["About"],
			order = 990,
			args = {
				title = {
					type = "description",
					name = fmt("|cffffd200Skada|r %s", Skada.version),
					fontSize = "large",
					image = "Interface\\Icons\\Spell_Lightning_LightningBolt01",
					imageWidth = 16,
					imageHeight = 16,
					imageCoords = {0.05, 0.95, 0.05, 0.95},
					width = "full",
					order = 0
				}
			}
		}
	}
}

-- about about args
for i, field in ipairs({"Version", "Date", "Author", "Category", "License", "Email", "Website", "Discord", "Credits", "Localizations", "Donate"}) do
	local meta = GetAddOnMetadata("Skada", field) or GetAddOnMetadata("Skada", "X-" .. field)
	if meta then
		Skada.options.args.about.args[field] = {
			type = "description",
			name = fmt("\n|cffffd200%s|r:  %s", L[field], meta),
			fontSize = "medium",
			width = "double",
			order = i
		}
	end
end

-------------------------------------------------------------------------------
-- profile import, export and sharing
do
	local pairs, ipairs = pairs, ipairs
	local collectgarbage = collectgarbage
	local AceGUI

	local function getProfileName(str)
		local header = strsub(str, 1, 64)
		local name = (header:match("%[(.-)%]") or header):gsub("=", ""):gsub("profile", ""):trim()
		return (name ~= "") and name
	end

	local function SerializeProfile()
		local data = {Skada = {}}
		Skada.tCopy(data.Skada, Skada.db.profile, {"nickname"})
		for k, v in Skada:IterateModules() do
			if v.db and v.db.profile then
				data[k] = v.db.profile
			end
		end
		return Skada:Serialize(true, fmt("%s profile", Skada.db:GetCurrentProfile()), data)
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
			editbox.button:SetScript("OnClick", function(widget)
				Skada:ImportProfile(editbox:GetText())
				AceGUI:Release(frame)
				collectgarbage()
			end)
		end
		-- close on escape
		_G["SkadaImportExportFrame"] = frame.frame
		tinsert(UISpecialFrames, "SkadaImportExportFrame")
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
			for k, v in pairs(data) do
				local db = (k == "Skada") and Skada.db or (self:GetModule(k, true) and self.db:GetNamespace(k, true))
				if db then
					Skada.tCopy(db.profile, v)
				end
			end
			self:ReloadSettings()
			LibStub("AceConfigRegistry-3.0"):NotifyChange("Skada")
		end
		Skada.db:SetProfile(profileName)
		Skada:ReloadSettings()
		return true
	end

	function Skada:AdvancedProfile(args)
		if not args then return end
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