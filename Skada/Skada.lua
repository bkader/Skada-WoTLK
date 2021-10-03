local Skada = LibStub("AceAddon-3.0"):NewAddon("Skada", "AceEvent-3.0", "AceHook-3.0", "AceComm-3.0", "LibCompat-1.0")
_G.Skada = Skada

Skada.callbacks = Skada.callbacks or LibStub("CallbackHandler-1.0"):New(Skada)
Skada.version = GetAddOnMetadata("Skada", "Version")
Skada.website = GetAddOnMetadata("Skada", "X-Website") or "https://github.com/bkader/Skada-WoTLK"
Skada.discord = GetAddOnMetadata("Skada", "X-Discord") or "https://bit.ly/skada-rev"
Skada.locale = Skada.locale or GetLocale()

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local ACD = LibStub("AceConfigDialog-3.0")
local DBI = LibStub("LibDBIcon-1.0", true)
local LBB = LibStub("LibBabble-Boss-3.0"):GetUnstrictLookupTable()
local LBI = LibStub("LibBossIDs-1.0")
local LDB = LibStub("LibDataBroker-1.1")
local LSM = LibStub("LibSharedMedia-3.0")
local Translit = LibStub("LibTranslit-1.0", true)

-- cache frequently used globlas
local tsort, tinsert, tremove, tmaxn = table.sort, table.insert, table.remove, table.maxn
local next, pairs, ipairs, type = next, pairs, ipairs, type
local tonumber, tostring, format, strsplit = tonumber, tostring, string.format, strsplit
local floor, max, min, band, bor, time = math.floor, math.max, math.min, bit.band, bit.bor, time
local setmetatable, newTable, delTable = setmetatable, Skada.newTable, Skada.delTable
local GetNumPartyMembers, GetNumRaidMembers = GetNumPartyMembers, GetNumRaidMembers
local IsInInstance, UnitAffectingCombat, InCombatLockdown = IsInInstance, UnitAffectingCombat, InCombatLockdown
local UnitExists, UnitGUID, UnitName, UnitClass, UnitIsConnected = UnitExists, UnitGUID, UnitName, UnitClass, UnitIsConnected
local GetSpellInfo, GetSpellLink = GetSpellInfo, GetSpellLink
local CloseDropDownMenus = L_CloseDropDownMenus or CloseDropDownMenus
local UnitGroupRolesAssigned, GetInspectSpecialization = Skada.UnitGroupRolesAssigned, Skada.GetInspectSpecialization
local GetGroupTypeAndCount, GetNumGroupMembers = Skada.GetGroupTypeAndCount, Skada.GetNumGroupMembers
local GetUnitIdFromGUID, UnitIterator, IsGroupInCombat, IsGroupDead = Skada.GetUnitIdFromGUID, Skada.UnitIterator, Skada.IsGroupInCombat, Skada.IsGroupDead
local After, NewTimer, NewTicker, CancelTimer = Skada.After, Skada.NewTimer, Skada.NewTicker, Skada.CancelTimer

local dataobj = LDB:NewDataObject("Skada", {
	label = "Skada",
	type = "data source",
	icon = "Interface\\Icons\\Spell_Lightning_LightningBolt01",
	text = "n/a"
})

-- Keybindings
BINDING_HEADER_SKADA = "Skada"
BINDING_NAME_SKADA_TOGGLE = L["Toggle Windows"]
BINDING_NAME_SKADA_SHOWHIDE = L["Show/Hide Windows"]
BINDING_NAME_SKADA_RESET = RESET
BINDING_NAME_SKADA_NEWSEGMENT = L["Start New Segment"]
BINDING_NAME_SKADA_STOP = L["Stop"]

-- Skada-Revisited flag
Skada.revisited = true

-- available display types
Skada.displays = {}

-- flag to check if disabled
local disabled = false

-- update & tick timers
local update_timer, tick_timer, version_timer
local checkVersion, convertVersion
local check_for_join_and_leave

-- list of players, pets and vehicles
local players, pets, vehicles = {}, {}, {}
local queuedFixes, queuedData, queuedUnits

-- list of feeds & selected feed
local feeds, selectedfeed = {}

-- lists of modules and windows
local modes, windows = {}, {}

-- flags for party, instance and ovo
local wasinparty, wasininstance, wasinpvp = false

local COMBATLOG_OBJECT_AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local COMBATLOG_OBJECT_AFFILIATION_PARTY = COMBATLOG_OBJECT_AFFILIATION_PARTY or 0x00000002
local COMBATLOG_OBJECT_AFFILIATION_RAID = COMBATLOG_OBJECT_AFFILIATION_RAID or 0x00000004
local COMBATLOG_OBJECT_AFFILIATION_MASK = COMBATLOG_OBJECT_AFFILIATION_MASK or 0x0000000F

local COMBATLOG_OBJECT_REACTION_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x00000010
local COMBATLOG_OBJECT_REACTION_NEUTRAL = COMBATLOG_OBJECT_REACTION_NEUTRAL or 0x00000020
local COMBATLOG_OBJECT_REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x00000040
local COMBATLOG_OBJECT_REACTION_MASK = COMBATLOG_OBJECT_REACTION_MASK or 0x000000F0

local COMBATLOG_OBJECT_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER or 0x00000100
local COMBATLOG_OBJECT_CONTROL_NPC = COMBATLOG_OBJECT_CONTROL_NPC or 0x00000200
local COMBATLOG_OBJECT_CONTROL_MASK = COMBATLOG_OBJECT_CONTROL_MASK or 0x00000300

local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400
local COMBATLOG_OBJECT_TYPE_NPC = COMBATLOG_OBJECT_TYPE_NPC or 0x00000800
local COMBATLOG_OBJECT_TYPE_PET = COMBATLOG_OBJECT_TYPE_PET or 0x00001000
local COMBATLOG_OBJECT_TYPE_GUARDIAN = COMBATLOG_OBJECT_TYPE_GUARDIAN or 0x00002000

local BITMASK_GROUP = bor(COMBATLOG_OBJECT_AFFILIATION_MINE, COMBATLOG_OBJECT_AFFILIATION_PARTY, COMBATLOG_OBJECT_AFFILIATION_RAID)
local BITMASK_PETS = bor(COMBATLOG_OBJECT_TYPE_PET, COMBATLOG_OBJECT_TYPE_GUARDIAN)
local BITMASK_OWNERS = bor(COMBATLOG_OBJECT_AFFILIATION_MASK, COMBATLOG_OBJECT_REACTION_MASK, COMBATLOG_OBJECT_CONTROL_MASK)
local BITMASK_ENEMY = bor(COMBATLOG_OBJECT_REACTION_NEUTRAL, COMBATLOG_OBJECT_REACTION_HOSTILE)

-- to allow external usage
Skada.BITMASK_GROUP = BITMASK_GROUP
Skada.BITMASK_PETS = BITMASK_PETS
Skada.BITMASK_OWNERS = BITMASK_OWNERS
Skada.BITMASK_ENEMY = BITMASK_ENEMY

-- ================ --
-- custom functions --
-- ================ --

function Skada.UnitClass(guid, flags, set, nocache)
	set = set or Skada.current

	if set then
		-- an existing player
		for _, p in ipairs(set.players) do
			if p.id == guid then
				return Skada.classnames[p.class], p.class, p.role, p.spec
			end
		end
		set._classes = set._classes or {}

		-- a cached class
		for id, class in pairs(set._classes) do
			if id == guid then
				return Skada.classnames[class], class
			end
		end
	end

	local locClass, engClass = Skada.classnames.UNKNOWN, "UNKNOWN"

	if Skada:IsPlayer(guid, flags) then
		if tonumber(guid) ~= 0 then
			local class = select(2, GetPlayerInfoByGUID(guid))
			if class then
				locClass, engClass = Skada.classnames[class], class
			end
		end

		if not engClass then
			locClass, engClass = Skada.classnames.PLAYER, "PLAYER"
		end
	elseif Skada:IsPet(guid, flags) then
		locClass, engClass = Skada.classnames.PET, "PET"
	elseif Skada:IsBoss(guid) then
		locClass, engClass = Skada.classnames.BOSS, "BOSS"
	elseif Skada:IsCreature(guid, flags) then
		locClass, engClass = Skada.classnames.MONSTER, "MONSTER"
	end

	if not nocache and (set and set._classes[guid] ~= engClass) then
		set._classes[guid] = engClass
	end

	return locClass, engClass
end

-------------------------------------------------------------------------------
-- Active / Effetive time functions

-- returns the selected set time.
function Skada:GetSetTime(set)
	return set and max((set.time or 0) > 0 and set.time or (time() - set.starttime), 0.1) or 0
end

-- returns a formmatted set time
function Skada:GetFormatedSetTime(set)
	return self:FormatTime(self:GetSetTime(set))
end

-- returns the player active/effective time
function Skada:PlayerActiveTime(set, player, active)
	if (self.db.profile.timemesure ~= 2 or active) and player and player.time then
		return max(0.1, player.time)
	end
	return self:GetSetTime(set)
end

-- updates the player's active time
function Skada:AddActiveTime(player, cond, diff)
	if player and cond then
		local now = GetTime()
		local delta = now - player.last

		if (diff or 0) > 0 and delta > diff then
			delta = diff
		elseif delta > 3.5 then
			delta = 3.5
		end

		delta = floor(100 * delta + 0.5) / 100
		player.last = now
		player.time = (player.time or 0) + delta
	end
end

-------------------------------------------------------------------------------
-- popup dialogs

-- creates generic dialog
function Skada:ConfirmDialog(text, accept, cancel, override)
	local t = wipe(StaticPopupDialogs["SkadaCommonConfirmDialog"] or {})
	StaticPopupDialogs["SkadaCommonConfirmDialog"] = t

	local dialog, strata
	t.OnAccept = function(self)
		if type(accept) == "function" then
			(accept)(self)
		end
		if dialog and strata then
			dialog:SetFrameStrata(strata)
		end
	end
	t.OnCancel = function(self)
		if type(cancel) == "function" then
			(cancel)(self)
		end
		if dialog and strata then
			dialog:SetFrameStrata(strata)
		end
	end

	t.preferredIndex = STATICPOPUP_NUMDIALOGS
	t.text = text
	t.button1 = ACCEPT
	t.button2 = CANCEL
	t.timeout = 0
	t.whileDead = 1
	t.hideOnEscape = 1

	if type(override) == "table" then
		self.tCopy(t, override)
	end

	dialog = StaticPopup_Show("SkadaCommonConfirmDialog")
	if dialog then
		strata = dialog:GetFrameStrata()
		dialog:SetFrameStrata("TOOLTIP")
	end
end

-- skada reset dialog
function Skada:ShowPopup(win, popup)
	if Skada.db.profile.skippopup and not popup then
		Skada:Reset(IsShiftKeyDown())
		return
	end

	Skada:ConfirmDialog(
		L["Do you want to reset Skada?\nHold SHIFT to reset all data."],
		function() Skada:Reset(IsShiftKeyDown()) end,
		nil,
		{timeout = 30, whileDead = 0}
	)
end

-- new window creation dialog
function Skada:NewWindow()
	if not StaticPopupDialogs["SkadaCreateWindowDialog"] then
		StaticPopupDialogs["SkadaCreateWindowDialog"] = {
			text = L["Enter the name for the new window."],
			button1 = CREATE,
			button2 = CANCEL,
			timeout = 30,
			whileDead = 0,
			hideOnEscape = 1,
			hasEditBox = 1,
			OnShow = function(self)
				self.button1:Disable()
				self.editBox:SetText("")
				self.editBox:SetFocus()
			end,
			OnHide = function(self)
				self.editBox:SetText("")
				self.editBox:ClearFocus()
			end,
			EditBoxOnEscapePressed = function(self)
				self:GetParent():Hide()
			end,
			EditBoxOnTextChanged = function(self)
				local name = self:GetText()
				if not name or name:trim() == "" then
					self:GetParent().button1:Disable()
				else
					self:GetParent().button1:Enable()
				end
			end,
			EditBoxOnEnterPressed = function(self)
				local name = self:GetText()
				if name:trim() ~= "" then
					Skada:CreateWindow(name)
				end
				self:GetParent():Hide()
			end,
			OnAccept = function(self)
				local name = self.editBox:GetText()
				if name:trim() ~= "" then
					Skada:CreateWindow(name)
				end
				self:Hide()
			end
		}
	end
	StaticPopup_Show("SkadaCreateWindowDialog")
end

-------------------------------------------------------------------------------
-- Windo functions

local Window = {}
do
	local mt = {__index = Window}
	local copywindow = nil

	-- create a new window
	function Window:new()
		return setmetatable({
			dataset = {},
			metadata = {},
			history = {},
			changed = false
		}, mt)
	end

	-- add window options
	function Window:AddOptions()
		local db = self.db

		local options = {
			type = "group",
			name = function() return db.name end,
			desc = function() return format(L["Options for %s."], db.name) end,
			get = function(i) return db[i[#i]] end,
			set = function(i, val)
				db[i[#i]] = val
				Skada:ApplySettings(db.name)
			end,
			args = {
				name = {
					type = "input",
					name = L["Rename Window"],
					desc = L["Enter the name for the window."],
					order = 1,
					width = "double",
					set = function(_, val)
						if val ~= db.name and val ~= "" then
							local oldname = db.name
							db.name = val
							Skada.options.args.windows.args[val] = Skada.options.args.windows.args[oldname]
							Skada.options.args.windows.args[oldname] = nil
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
					set = function(_, display)
						db.display = display
						Skada:ReloadSettings()
					end
				},
				barslocked = {
					type = "toggle",
					name = L["Lock Window"],
					desc = L["Locks the bar window in place."],
					order = 4
				},
				hidden = {
					type = "toggle",
					name = L["Hide Window"],
					desc = L["Hides the window."],
					order = 5
				},
				clamped = {
					type = "toggle",
					name = L["Clamped To Screen"],
					desc = L["Toggle whether to permit movement out of screen."],
					order = 8
				},
				separator1 = {
					type = "description",
					name = " ",
					order = 9,
					width = "full"
				},
				copywin = {
					type = "select",
					name = L["Copy Settings"],
					desc = L["Choose the window from which you want to copy the settings."],
					order = 10,
					values = function()
						local list = {[""] = NONE}
						for _, win in Skada:IterateWindows() do
							if win.db.name ~= db.name and win.db.display == db.display then
								list[win.db.name] = win.db.name
							end
						end
						return list
					end,
					get = function() return copywindow or "" end,
					set = function(_, val) copywindow = (val == "") and nil or val end
				},
				copyexec = {
					type = "execute",
					name = L["Copy Settings"],
					order = 11,
					disabled = function()
						return (copywindow == nil)
					end,
					func = function()
						local newdb = {}
						if copywindow then
							for _, win in Skada:IterateWindows() do
								if win.db.name == copywindow and win.db.display == db.display then
									Skada.tCopy(newdb, win.db, {"name", "sticked", "x", "y", "point", "snapped"})
									break
								end
							end
						end
						for k, v in pairs(newdb) do
							db[k] = v
						end
						Skada:ApplySettings(db.name)
						copywindow = nil
					end
				},
				separator2 = {
					type = "description",
					name = " ",
					order = 98,
					width = "full"
				},
				delete = {
					type = "execute",
					name = L["Delete Window"],
					desc = L["Choose the window to be deleted."],
					order = 99,
					width = "double",
					confirm = function() return L["Are you sure you want to delete this window?"] end,
					func = function() Skada:DeleteWindow(db.name, true) end
				}
			}
		}

		if db.display == "bar" then
			options.args.child = {
				type = "select",
				name = L["Child Window"],
				desc = L["A child window will replicate the parent window actions."],
				order = 3,
				values = function()
					local list = {[""] = NONE}
					for _, win in Skada:IterateWindows() do
						if win.db.name ~= db.name and win.db.child ~= db.name and win.db.display == db.display then
							list[win.db.name] = win.db.name
						end
					end
					return list
				end,
				get = function() return db.child or "" end,
				set = function(_, child)
					db.child = child == "" and nil or child
					Skada:ReloadSettings()
				end
			}

			options.args.childmode = {
				type = "select",
				name = L["Child Window Mode"],
				order = 4,
				values = {[0] = ALL, [1] = L["Segment"], [2] = L["Mode"]},
				get = function() return db.childmode or 0 end,
				disabled = function() return not (db.child and db.child ~= "") end
			}

			options.args.sticky = {
				type = "toggle",
				name = L["Sticky Window"],
				desc = L["Allows the window to stick to other Skada windows."],
				order = 6,
				set = function()
					db.sticky = not db.sticky
					if not db.sticky then
						for _, win in Skada:IterateWindows() do
							if win.db.sticked[db.name] then
								win.db.sticked[db.name] = nil
							end
						end
					end
					Skada:ApplySettings(db.name)
				end
			}

			options.args.snapto = {
				type = "toggle",
				name = L["Snap to best fit"],
				desc = L["Snaps the window size to best fit when resizing."],
				order = 7
			}
		end

		options.args.switchoptions = {
			type = "group",
			name = L["Mode Switching"],
			desc = format(L["Options for %s."], L["Mode Switching"]),
			order = 99,
			args = {
				modeincombat = {
					type = "select",
					name = L["Combat mode"],
					desc = L["Automatically switch to set 'Current' and this mode when entering combat."],
					order = 1,
					values = function()
						local m = {[""] = NONE}
						for _, mode in Skada:IterateModes() do
							m[mode:GetName()] = mode:GetName()
						end
						return m
					end
				},
				wipemode = {
					type = "select",
					name = L["Wipe mode"],
					desc = L["Automatically switch to set 'Current' and this mode after a wipe."],
					order = 2,
					values = function()
						local m = {[""] = NONE}
						for _, mode in Skada:IterateModes() do
							m[mode:GetName()] = mode:GetName()
						end
						return m
					end
				},
				returnaftercombat = {
					type = "toggle",
					name = L["Return after combat"],
					desc = L["Return to the previous set and mode after combat ends."],
					order = 3,
					width = "double",
					disabled = function() return (db.modeincombat == "" and db.wipemode == "") end
				}
			}
		}

		self.display:AddDisplayOptions(self, options.args)
		Skada.options.args.windows.args[self.db.name] = options
	end
end

-- sets the selected window as a child to the current window
function Window:SetChild(win)
	if not win then
		return
	elseif type(win) == "table" then
		self.child = win
	elseif type(win) == "string" and win:trim() ~= "" then
		for _, w in Skada:IterateWindows() do
			if w.db.name == win then
				self.child = w
				return
			end
		end
	end
end

-- destroy a window
function Window:destroy()
	self.dataset = nil
	if self.display then
		self.display:Destroy(self)
	end

	local name = self.db.name or Skada.windowdefaults.name
	Skada.options.args.windows.args[name] = nil
	name = nil
end

-- change window display
function Window:SetDisplay(name)
	if name ~= self.db.display or self.display == nil then
		if self.display then
			self.display:Destroy(self)
		end

		self.db.display = name
		self.display = Skada.displays[self.db.display]
		self:AddOptions()
	end
end

-- tell window to update the display of its dataset, using its display provider.
function Window:UpdateDisplay()
	if not self.metadata.maxvalue then
		self.metadata.maxvalue = 0
		for _, data in ipairs(self.dataset) do
			if data.id and data.value > self.metadata.maxvalue then
				self.metadata.maxvalue = data.value
			end
		end
	end

	self.display:Update(self)
	self:set_mode_title()
end

-- called before dataset is updated.
function Window:UpdateInProgress()
	for _, data in ipairs(self.dataset) do
		if data.ignore then
			data.icon = nil
		end
		data.id = nil
		data.ignore = nil
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
	if self.dataset then
		for i, data in ipairs(self.dataset) do
			self.dataset[i] = wipe(data)
		end
	end
end

function Window:Wipe()
	self:Reset()
	if self.display then
		self.display:Wipe(self)
	end

	if self.child and self.db.childmode == 0 then
		self.child:Wipe()
	end
end

function Window:get_selected_set()
	return Skada:GetSet(self.selectedset)
end

function Window:set_selected_set(set, step)
	if step ~= nil then
		local count = #Skada.char.sets
		if count > 0 then
			if type(self.selectedset) == "number" then
				set = self.selectedset + step
				if set < 1 then
					set = "current"
				elseif set > count then
					set = "total"
				end
			elseif self.selectedset == "current" then
				set = (step == 1) and 1 or "total"
			elseif self.selectedset == "total" then
				set = (step == 1) and "current" or count
			end
		elseif self.selectedset == "total" then
			set = "current"
		elseif self.selectedset == "current" then
			set = "total"
		end
	end

	self.selectedset = set
	self:RestoreView()
	if self.child and self.db.childmode <= 1 then
		self.child:set_selected_set(set)
	end
end

function Window:DisplayMode(mode)
	if type(mode) ~= "table" then
		return
	end
	self:Wipe()

	self.selectedmode = mode
	self.metadata = wipe(self.metadata or {})

	if mode and self.parentmode ~= mode and Skada:GetModule(mode:GetName(), true) then
		self.parentmode = mode
	end

	if mode.metadata then
		for key, value in pairs(mode.metadata) do
			self.metadata[key] = value
		end
	end

	self.changed = true
	self:set_mode_title()

	if self.child and self.db.childmode ~= 1 then
		self.child:DisplayMode(mode)
	end

	Skada:UpdateDisplay(false)
end

do
	local function click_on_mode(win, id, _, button)
		if button == "LeftButton" then
			local mode = Skada:find_mode(id)
			if mode then
				if Skada.db.profile.sortmodesbyusage then
					Skada.db.profile.modeclicks = Skada.db.profile.modeclicks or {}
					Skada.db.profile.modeclicks[id] = (Skada.db.profile.modeclicks[id] or 0) + 1
					Skada:SortModes()
				end
				win:DisplayMode(mode)
				mode = nil
			end
		elseif button == "RightButton" then
			win:RightClick()
		end
	end

	function Skada:SortModes()
		tsort(modes, function(a, b)
			if self.db.profile.sortmodesbyusage and self.db.profile.modeclicks then
				return (self.db.profile.modeclicks[a:GetName()] or 0) >
					(self.db.profile.modeclicks[b:GetName()] or 0)
			else
				return a:GetName() < b:GetName()
			end
		end)
	end

	function Window:DisplayModes(settime)
		self.history = wipe(self.history or {})
		self:Wipe()

		self.selectedmode = nil

		self.metadata = wipe(self.metadata or {})
		self.metadata.title = L["Skada: Modes"]

		self.db.set = settime

		if settime == "current" or settime == "total" then
			self.selectedset = settime
		else
			for i, set in Skada:IterateSets() do
				if tostring(set.starttime) == settime then
					if set.name == L["Current"] then
						self.selectedset = "current"
					elseif set.name == L["Total"] then
						self.selectedset = "total"
					else
						self.selectedset = i
					end
				end
			end
		end

		self.metadata.click = click_on_mode
		self.metadata.maxvalue = 1
		self.metadata.sortfunc = function(a, b)
			return a.name < b.name
		end

		self.display:SetTitle(self, self.metadata.title)
		self.changed = true

		if self.child and self.db.childmode == 0 then
			self.child:DisplayModes(settime)
		end

		Skada:UpdateDisplay(false)
	end
end

do
	local function click_on_set(win, id, _, button)
		if button == "LeftButton" then
			win:DisplayModes(id)
		elseif button == "RightButton" then
			win:RightClick()
		end
	end

	function Window:DisplaySets()
		self.history = wipe(self.history or {})
		self:Wipe()

		self.selectedmode = nil
		self.selectedset = nil

		self.metadata = wipe(self.metadata or {})
		self.metadata.title = L["Skada: Fights"]
		self.display:SetTitle(self, self.metadata.title)

		self.metadata.click = click_on_set
		self.metadata.maxvalue = 1
		self.changed = true

		if self.child and self.db.childmode == 0 then
			self.child:DisplaySets()
		end

		Skada:UpdateDisplay(false)
	end
end

function Window:RightClick(_, button)
	if self.selectedmode then
		if #self.history > 0 then
			self:DisplayMode(tremove(self.history))
		else
			self:DisplayModes(self.selectedset)
		end
	elseif self.selectedset then
		self:DisplaySets()
	end
	CloseDropDownMenus() -- always close
end

-------------------------------------------------------------------------------
-- windows and misc

function Skada:GetWindows()
	return windows
end

function Skada:CreateWindow(name, db, display)
	name = name and name:trim() or "Skada"
	if not name or name == "" then
		name = "Skada" -- default
	end

	local isnew = false
	if not db then
		db, isnew = {}, true
		self.tCopy(db, Skada.windowdefaults)
		tinsert(self.db.profile.windows, db)
	end

	if display then
		db.display = display
	end

	db.barbgcolor = db.barbgcolor or {r = 0.3, g = 0.3, b = 0.3, a = 0.6}
	db.buttons = db.buttons or {menu = true, reset = true, report = true, mode = true, segment = true, stop = false}
	db.scale = db.scale or 1

	-- backward compatibility
	if db.snapped or not db.sticked then
		db.sticky, db.sticked = true, {}
		db.snapto, db.snapped = false, nil
	end

	-- child window mode
	db.childmode = db.childmode or 0
	db.tooltippos = db.tooltippos or "NONE"

	local window = Window:new()
	window.db = db

	-- avoid duplicate names
	do
		local num = 0
		for _, win in Skada:IterateWindows() do
			if win.db.name == name and num == 0 then
				num = 1
			else
				local n, c = win.db.name:match("^(.-)%s*%((%d+)%)$")
				if n == name then
					num = max(num, tonumber(c) or 0)
				end
			end
		end
		if num > 0 then
			name = format("%s (%s)", name, num + 1)
		end
	end

	window.db.name = name

	if self.displays[window.db.display] then
		window:SetDisplay(window.db.display or "bar")
		window.display:Create(window)
		tinsert(windows, window)
		window:DisplaySets()

		if isnew and self:find_mode(L["Damage"]) then
			self:RestoreView(window, "current", L["Damage"])
		elseif window.db.set or window.db.mode then
			self:RestoreView(window, window.db.set, window.db.mode)
		end
	else
		self:Printf("Window '%s' was not loaded because its display module, '%s' was not found.", name, window.db.display or UNKNOWN)
	end

	self:ApplySettings()
	return window
end

-- window deletion
do
	local function DeleteWindow(name)
		for i, win in Skada:IterateWindows() do
			if win.db.name == name then
				win:destroy()
				wipe(tremove(windows, i))
			elseif win.db.child == name then
				win.db.child, win.child = nil, nil
			end
		end

		for i, win in ipairs(Skada.db.profile.windows) do
			if win.name == name then
				tremove(Skada.db.profile.windows, i)
			elseif win.sticked and win.sticked[name] then
				win.sticked[name] = nil
			end
		end
	end

	function Skada:DeleteWindow(name, internal)
		if internal then
			return DeleteWindow(name)
		end

		if not StaticPopupDialogs["SkadaDeleteWindowDialog"] then
			StaticPopupDialogs["SkadaDeleteWindowDialog"] = {
				text = L["Are you sure you want to delete this window?"],
				button1 = YES,
				button2 = NO,
				timeout = 30,
				whileDead = 0,
				hideOnEscape = 1,
				OnAccept = function(self, data)
					CloseDropDownMenus()
					ACD:Close("Skada") -- to avoid errors
					return DeleteWindow(data)
				end
			}
		end
		StaticPopup_Show("SkadaDeleteWindowDialog", nil, nil, name)
	end
end

-- toggles windows visibility
function Skada:ToggleWindow()
	if self.db.profile.hidden then
		self.db.profile.hidden = false
		self:ApplySettings()
	else
		for _, win in self:IterateWindows() do
			if win:IsShown() then
				win.db.hidden = true
				win:Hide()
			else
				win.db.hidden = false
				win:Show()
			end
		end
	end
end

-- global show/hide windows
function Skada:ShowHide()
	self.db.profile.hidden = not self.db.profile.hidden
	self:ApplySettings()
end

-- restores a view for the selected window
function Skada:RestoreView(win, theset, themode)
	if theset and type(theset) == "string" and (theset == "current" or theset == "total" or theset == "last") then
		win.selectedset = theset
	elseif theset and type(theset) == "number" and theset <= #self.char.sets then
		win.selectedset = theset
	else
		win.selectedset = "current"
	end

	self.changed = true

	if themode then
		win:DisplayMode(self:find_mode(themode) or win.selectedset)
	else
		win:DisplayModes(win.selectedset)
	end
end

-- wipes all windows
function Skada:Wipe()
	for _, win in self:IterateWindows() do
		win:Wipe()
	end
end

function Skada:SetActive(enable)
	if enable and self.db.profile.hidden then
		enable = false
	end

	if enable then
		for _, win in self:IterateWindows() do
			win:Show()
		end
	else
		for _, win in self:IterateWindows() do
			win:Hide()
		end
	end

	if not enable and self.db.profile.hidedisables then
		if not disabled then
			self:Debug(L["Data Collection"] .. " " .. "|cFFFF0000" .. L["DISABLED"] .. "|r")
		end
		disabled = true
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		if disabled then
			self:Debug(L["Data Collection"] .. " " .. "|cFF00FF00" .. L["ENABLED"] .. "|r")
		end
		disabled = false
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatLogEvent")
	end

	self:UpdateDisplay(true)
end

-------------------------------------------------------------------------------
-- print and debug

function Skada:Debug(...)
	if self.db.profile.debug then
		local msg = ""
		for i = 1, select("#", ...) do
			local v = tostring(select(i, ...))
			if #msg > 0 then
				msg = msg .. ", "
			end
			msg = msg .. v
		end
		print("|cff33ff99Skada Debug|r: " .. msg)
	end
end

-------------------------------------------------------------------------------
-- mode functions

function Skada:find_mode(name)
	for _, mode in Skada:IterateModes() do
		if mode:GetName() == name then
			return mode
		end
	end
end

do
	-- scane modes to add column options
	local function scan_for_columns(mode)
		if not mode.scanned then
			mode.scanned = true

			if mode.metadata then
				-- add columns if available
				if mode.metadata.columns then
					Skada:AddColumnOptions(mode)
				end

				-- scan for linked modes
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
	end

	function Skada:AddMode(mode, category)
		if self.total then
			self:VerifySet(mode, self.total)
		end

		if self.current then
			self:VerifySet(mode, self.current)
		end

		for _, set in self:IterateSets() do
			self:VerifySet(mode, set)
		end

		mode.category = category or OTHER
		tinsert(modes, mode)

		for _, win in self:IterateWindows() do
			if mode:GetName() == win.db.mode then
				self:RestoreView(win, win.db.set, mode:GetName())
			end
		end

		if selectedfeed == nil and self.db.profile.feed ~= "" then
			for name, feed in pairs(feeds) do
				if name == self.db.profile.feed then
					self:SetFeed(feed)
				end
			end
		end

		scan_for_columns(mode)
		Skada:SortModes()

		for _, win in self:IterateWindows() do
			win:Wipe()
		end

		self.changed = true
	end
end

function Skada:RemoveMode(mode)
	tremove(modes, mode)
end

function Skada:GetModes()
	return modes
end

-------------------------------------------------------------------------------
-- iteration functions

function Skada:IterateModes()
	return ipairs(modes)
end

function Skada:IterateSets()
	return ipairs(self.char.sets)
end

function Skada:IterateWindows()
	return ipairs(windows)
end

-------------------------------------------------------------------------------
-- modules functions

-- adds a module to the loadable modules table.
function Skada:AddLoadableModule(name, description, func)
	self.modulelist = self.modulelist or {}

	if type(description) == "function" then
		self.modulelist[#self.modulelist + 1] = description
		self:AddLoadableModuleCheckbox(name, name)
	else
		self.modulelist[#self.modulelist + 1] = func
		self:AddLoadableModuleCheckbox(name, name, description)
	end
end

-- checks whether the select module(s) are disabled
function Skada:IsDisabled(...)
	for i = 1, select("#", ...) do
		if self.db.profile.modulesBlocked[select(i, ...)] == true then
			return true
		end
	end
	return false
end

-- add a display system
do
	local numorder = 3
	function Skada:AddDisplaySystem(key, mod)
		self.displays[key] = mod
		if mod.description then
			Skada.options.args.windows.args[key .. "desc"] = {
				type = "description",
				name = format("\n|cffffd700%s|r:\n%s", mod.name, mod.description),
				fontSize = "medium",
				order = numorder
			}
			numorder = numorder + 1
		end
	end
end

-------------------------------------------------------------------------------
-- set functions

-- creates a new set
function Skada:CreateSet(setname, starttime)
	starttime = starttime or time()
	local set = {players = {}, name = setname, starttime = starttime, last_action = starttime, time = 0}
	for _, mode in self:IterateModes() do
		self:VerifySet(mode, set)
	end
	self.callbacks:Fire("SKADA_DATA_SETCREATED", set, starttime)
	return set
end

-- verifies a set
function Skada:VerifySet(mode, set)
	if mode.AddSetAttributes then
		mode:AddSetAttributes(set)
	end

	if mode.AddPlayerAttributes then
		for _, player in ipairs(set.players) do
			mode:AddPlayerAttributes(player, set)
		end
	end
end

-- returns all sets, excluding total
function Skada:GetSets()
	return self.char.sets
end

-- returns the number of sets and how many are kept
function Skada:GetNumSets()
	local num, kept = 0, 0

	for _, s in self:IterateSets() do
		num = num + 1
		if s.keep then
			kept = kept + 1
		end
	end

	return num, kept, num - kept
end

-- returns the selected set table.
function Skada:GetSet(s)
	if s == "current" then
		return self.current or self.last or self.char.sets[1]
	elseif s == "total" then
		return self.total
	else
		return self.char.sets[s]
	end
end

-- deletes a set
function Skada:DeleteSet(set, index)
	if not (set and index) then
		for i, s in self:IterateSets() do
			if (i == index) or (set == s) then
				set = set or s
				index = index or i
				break
			end
		end
	end

	if set and index then
		self.callbacks:Fire("SKADA_DATA_SETDELETED", index, tremove(self.char.sets, index))

		if set == self.last then
			self.last = nil
		end

		-- Don't leave windows pointing to a deleted sets
		for _, win in self:IterateWindows() do
			if win.selectedset == index or win:get_selected_set() == set then
				win.selectedset = "current"
				win.changed = true
			elseif (tonumber(win.selectedset) or 0) > index then
				win.selectedset = win.selectedset - 1
				win.changed = true
			end
			win:RestoreView()
		end

		self:Wipe()
		self:UpdateDisplay(true)
	end
end

-- clears cached player indexes
function Skada:ClearIndexes(set)
	if set then
		set._playeridx = nil
		self.callbacks:Fire("SKADA_DATA_CLEARSETINDEX", set)
	end
end

function Skada:ClearAllIndexes()
	self:ClearIndexes(self.current)
	self:ClearIndexes(self.char.total)
	for _, set in self:IterateSets() do
		self:ClearIndexes(set)
	end
end

-------------------------------------------------------------------------------
-- player functions

-- finds a player that was already recorded
function Skada:find_player(set, playerid, playername, strict)
	if set and playerid and playerid ~= "total" then
		set._playeridx = set._playeridx or {}

		local player = set._playeridx[playerid]
		if player then
			return player
		end

		-- search the set
		for _, p in ipairs(set.players) do
			if p.id == playerid then
				set._playeridx[playerid] = p
				return p
			end
		end

		-- needed for certain bosses
		local isboss, _, npcname = self:IsBoss(playerid, playername)
		if isboss then
			player = {id = playerid, name = npcname or playername, class = "BOSS"}
			set._playeridx[playerid] = player
			return player
		end

		if strict then
			return player
		end

		-- last hope
		return {id = playerid, name = playername or UNKNOWN, class = "PET"}
	end
end

do
	local function fix_player(player, unit)
		if player.id and player.name then
			unit = unit or GetUnitIdFromGUID(player.id, "group")

			if not player.class then
				if Skada:IsPet(player.id, player.flags) then
					player.class = "PET"
				elseif Skada:IsBoss(player.id) then
					player.class = "BOSS"
				elseif Skada:IsCreature(player.id, player.flags) then
					player.class = "MONSTER"
				elseif Skada:IsPlayer(player.id, player.flags, player.name) then
					local class = select(2, UnitClass(unit or player.name))
					player.class = class or Skada.GetClassFromGUID(player.id)
					player.name = player.name or select(6, GetPlayerInfoByGUID(player.id))
				else
					player.class = "UNKNOWN"
				end
			end

			-- if the player has been assigned a valid class,
			-- we make sure to assign his/her role and spec
			if Skada.validclass[player.class] then
				players[player.id] = players[player.id] or unit
				player.role = (player.role ~= nil and player.role ~= "NONE") and player.role or UnitGroupRolesAssigned(unit)
				player.spec = player.spec or GetInspectSpecialization(players[player.id], player.class)
			end
		end
	end

	-- finds a player table or creates it if not found
	function Skada:get_player(set, playerid, playername, playerflags)
		if not set or not playerid then return end

		local player = self:find_player(set, playerid, playername, true)

		if not player then
			if not playername then return end

			player = {id = playerid, name = playername or UNKNOWNOBJECT, flags = playerflags, time = 0}

			-- set class right away
			if players[playerid] then
				player.class = select(2, UnitClass(players[playerid]))
			end

			fix_player(player, players[playerid])

			for _, mode in self:IterateModes() do
				if mode.AddPlayerAttributes ~= nil then
					mode:AddPlayerAttributes(player, set)
				end
			end

			tinsert(set.players, player)
		end

		-- not all modules provide playerflags
		if player.flags == nil and playerflags then
			player.flags = playerflags
		end

		-- attempt to fix player name:
		if
			(player.name == UNKNOWNOBJECT and playername ~= UNKNOWNOBJECT) or -- unknown unit
			(player.name == UKNOWNBEING and playername ~= UKNOWNBEING) or -- unknown unit
			(player.name == player.id and playername ~= player.id) -- GUID is the same as the name
		then
			player.name = (player.id == self.userGUID or playerid == self.userGUID) and self.userName or playername
		end

		-- fix players created before their info was received
		if player.class and Skada.validclass[player.class] and player.spec == nil then
			if queuedData and queuedData[player.id] then
				player.spec, player.role = unpack(queuedData[player.id])
				queuedData[player.id] = nil
			elseif set.name == L["Current"] and not (queuedFixes and queuedFixes[player.id]) then
				queuedFixes = queuedFixes or newTable()
				queuedFixes[player.id] = NewTicker(5, function() fix_player(player, players[player.id]) end)
			end
		elseif queuedFixes and queuedFixes[player.id] then
			queuedData = queuedData or newTable()
			queuedData[player.id] = {player.spec, player.role}
			queuedFixes[player.id] = CancelTimer(queuedFixes[player.id]) -- no longer needed
		end

		-- total set has "last" always removed.
		player.last = player.last or GetTime()

		self.changed = true
		self.callbacks:Fire("SKADA_PLAYER_GET", player)
		return player
	end
end

-- checks if the unit is a player
function Skada:IsPlayer(guid, flags, name)
	if guid and players[guid] then
		return true
	end
	if name and UnitIsPlayer(name) then
		return true
	end
	if tonumber(flags) then
		return (band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0)
	end
	return false
end

-------------------------------------------------------------------------------
-- boss and creature functions

do
	local custom = {
		-- [[ Icecrown Citadel ]] --
		[36960] = LBB["Icecrown Gunship Battle"], -- Kor'kron Sergeant
		[36961] = LBB["Icecrown Gunship Battle"], -- Skybreaker Sergeant
		[36968] = LBB["Icecrown Gunship Battle"], -- Kor'kron Axethrower
		[36969] = LBB["Icecrown Gunship Battle"], -- Skybreaker Rifleman
		[36978] = LBB["Icecrown Gunship Battle"], -- Skybreaker Mortar Soldier
		[36982] = LBB["Icecrown Gunship Battle"], -- Kor'kron Rocketeer
		[37116] = LBB["Icecrown Gunship Battle"], -- Skybreaker Sorcerer
		[37117] = LBB["Icecrown Gunship Battle"], -- Kor'kron Battle-Mage
		[37215] = LBB["Icecrown Gunship Battle"], -- Orgrim's Hammer
		[37540] = LBB["Icecrown Gunship Battle"], -- The Skybreaker
		[37970] = LBB["Blood Prince Council"], -- Prince Valanar
		[37972] = LBB["Blood Prince Council"], -- Prince Keleseth
		[37973] = LBB["Blood Prince Council"], -- Prince Taldaram
		[36789] = LBB["Valithria Dreamwalker"], -- Valithria Dreamwalker
		[36791] = LBB["Valithria Dreamwalker"], -- Blazing Skeleton
		[37868] = LBB["Valithria Dreamwalker"], -- Risen Archmage
		[37886] = LBB["Valithria Dreamwalker"], -- Gluttonous Abomination
		[37934] = LBB["Valithria Dreamwalker"], -- Blistering Zombie
		[37985] = LBB["Valithria Dreamwalker"], -- Dream Cloud
		-- [[ Naxxramas ]] --
		[16062] = LBB["The Four Horsemen"], -- Highlord Mograine
		[16063] = LBB["The Four Horsemen"], -- Sir Zeliek
		[16064] = LBB["The Four Horsemen"], -- Thane Korth'azz
		[16065] = LBB["The Four Horsemen"], -- Lady Blaumeux
		[15930] = LBB["Thaddius"], -- Feugen
		[15929] = LBB["Thaddius"], -- Stalagg
		[15928] = LBB["Thaddius"], -- Thaddius
		-- [[ Trial of the Crusader ]] --
		[34796] = LBB["The Beasts of Northrend"], -- Gormok
		[35144] = LBB["The Beasts of Northrend"], -- Acidmaw
		[34799] = LBB["The Beasts of Northrend"], -- Dreadscale
		[34797] = LBB["The Beasts of Northrend"], -- Icehowl
		[34441] = LBB["Faction Champions"], -- Vivienne Blackwhisper <Priest>
		[34444] = LBB["Faction Champions"], -- Thrakgar <Shaman>
		[34445] = LBB["Faction Champions"], -- Liandra Suncaller <Paladin>
		[34447] = LBB["Faction Champions"], -- Caiphus the Stern <Priest>
		[34448] = LBB["Faction Champions"], -- Ruj'kah <Hunter>
		[34449] = LBB["Faction Champions"], -- Ginselle Blightslinger <Mage>
		[34450] = LBB["Faction Champions"], -- Harkzog <Warlock>
		[34451] = LBB["Faction Champions"], -- Birana Stormhoof <Druid>
		[34453] = LBB["Faction Champions"], -- Narrhok Steelbreaker <Warrior>
		[34454] = LBB["Faction Champions"], -- Maz'dinah <Rogue>
		[34455] = LBB["Faction Champions"], -- Broln Stouthorn <Shaman>
		[34456] = LBB["Faction Champions"], -- Malithas Brightblade <Paladin>
		[34458] = LBB["Faction Champions"], -- Gorgrim Shadowcleave <Death Knight>
		[34459] = LBB["Faction Champions"], -- Erin Misthoof <Druid>
		[34460] = LBB["Faction Champions"], -- Kavina Grovesong <Druid>
		[34461] = LBB["Faction Champions"], -- Tyrius Duskblade <Death Knight>
		[34463] = LBB["Faction Champions"], -- Shaabad <Shaman>
		[34465] = LBB["Faction Champions"], -- Velanaa <Paladin>
		[34466] = LBB["Faction Champions"], -- Anthar Forgemender <Priest>
		[34467] = LBB["Faction Champions"], -- Alyssia Moonstalker <Hunter>
		[34468] = LBB["Faction Champions"], -- Noozle Whizzlestick <Mage>
		[34469] = LBB["Faction Champions"], -- Melador Valestrider <Druid>
		[34470] = LBB["Faction Champions"], -- Saamul <Shaman>
		[34471] = LBB["Faction Champions"], -- Baelnor Lightbearer <Paladin>
		[34472] = LBB["Faction Champions"], -- Irieth Shadowstep <Rogue>
		[34473] = LBB["Faction Champions"], -- Brienna Nightfell <Priest>
		[34474] = LBB["Faction Champions"], -- Serissa Grimdabbler <Warlock>
		[34475] = LBB["Faction Champions"], -- Shocuul <Warrior>
		[35465] = LBB["Faction Champions"], -- Zhaagrym <Harkzog's Minion / Serissa Grimdabbler's Minion>
		[35610] = LBB["Faction Champions"], -- Cat <Ruj'kah's Pet / Alyssia Moonstalker's Pet>
		[34496] = LBB["The Twin Val'kyr"], -- Eydis Darkbane
		[34497] = LBB["The Twin Val'kyr"], -- Fjola Lightbane
		-- [[ Ulduar ]] --
		[32857] = LBB["The Iron Council"], -- Stormcaller Brundir
		[32867] = LBB["The Iron Council"], -- Steelbreaker
		[32927] = LBB["The Iron Council"], -- Runemaster Molgeim
		[32930] = LBB["Kologarn"], -- Kologarn
		[32933] = LBB["Kologarn"], -- Left Arm
		[32934] = LBB["Kologarn"], -- Right Arm
		[33515] = LBB["Auriaya"], -- Auriaya
		[34014] = LBB["Auriaya"], -- Sanctum Sentry
		[34035] = LBB["Auriaya"], -- Feral Defender
		[32882] = LBB["Thorim"], -- Jormungar Behemoth
		[33288] = LBB["Yogg-Saron"], -- Yogg-Saron
		[33890] = LBB["Yogg-Saron"], -- Brain of Yogg-Saron
		[33136] = LBB["Yogg-Saron"], -- Guardian of Yogg-Saron
		[33350] = LBB["Mimiron"], -- Mimiron
		[33432] = LBB["Mimiron"], -- Leviathan Mk II
		[33651] = LBB["Mimiron"], -- VX-001
		[33670] = LBB["Mimiron"] -- Aerial Command Unit
	}

	-- checks if the provided guid is a boss
	-- returns a boolean, boss id and boss name or custom name
	function Skada:IsBoss(guid, name)
		local isboss, npcid, npcname = false, 0, nil
		local id = self.GetCreatureId(guid)
		if id and (LBI.BossIDs[id] or custom[id]) then
			isboss, npcid = true, id
			if custom[id] then
				npcname = (name and name ~= custom[id]) and name or custom[id]
			end
		elseif self:IsCreature(guid) then
			npcid = id
		end
		return isboss, npcid, npcname
	end

	-- checks if the unit is a creature
	function Skada:IsCreature(guid, flags)
		if tonumber(guid) then
			return (band(guid:sub(1, 5), 0x00F) == 3 or band(guid:sub(1, 5), 0x00F) == 5)
		end
		if tonumber(flags) then
			return (band(flags, COMBATLOG_OBJECT_TYPE_NPC) ~= 0)
		end
		return false
	end
end

-------------------------------------------------------------------------------
-- pet functions

do
	local GetPetOwnerFromTooltip
	do
		local pettooltip = CreateFrame("GameTooltip", "SkadaPetTooltip", nil, "GameTooltipTemplate")
		local GetNumDeclensionSets, DeclineName = GetNumDeclensionSets, DeclineName

		local ValidatePetOwner
		do
			local ownerPatterns = {}
			do
				local i = 1
				local title = _G["UNITNAME_SUMMON_TITLE" .. i]
				while (title and title ~= "%s" and title:find("%s")) do
					local pattern = title:gsub("%%s", "(.-)")
					tinsert(ownerPatterns, pattern)
					i = i + 1
					title = _G["UNITNAME_SUMMON_TITLE" .. i]
				end
			end

			function ValidatePetOwner(text, name)
				for _, pattern in ipairs(ownerPatterns) do
					local owner = text:match(pattern)
					if owner and owner == name then
						return true
					end
				end
				return false
			end
		end

		-- attempts to find the player guid on Russian clients.
		local function FindNameDeclension(text, playername)
			for gender = 2, 3 do
				for decset = 1, GetNumDeclensionSets(playername, gender) do
					local ownerName = DeclineName(playername, gender, decset)
					if ValidatePetOwner(text, ownerName) or text:find(ownerName) then
						return true
					end
				end
			end
			return false
		end

		-- attempt to get the pet's owner from tooltip
		function GetPetOwnerFromTooltip(guid)
			if Skada.current and Skada.current.players then
				pettooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
				pettooltip:ClearLines()
				pettooltip:SetHyperlink("unit:" .. (guid or ""))

				for i = 2, pettooltip:NumLines() do
					local text = _G["SkadaPetTooltipTextLeft" .. i]:GetText()
					if text and text ~= "" then
						for _, p in ipairs(Skada.current.players) do
							local playername = p.name:gsub("%-.*", "")
							if (Skada.locale == "ruRU" and FindNameDeclension(text, playername)) or ValidatePetOwner(text, playername) then
								return p.id, p.name
							end
						end
					end
				end
			end
		end
	end

	local function GetPetOwnerUnit(guid)
		for unit, owner in UnitIterator() do
			if owner ~= nil and UnitGUID(unit) == guid then
				return owner
			end
		end
	end

	local function CommonFixPets(guid, flags)
		if guid and pets[guid] then
			return pets[guid]
		end

		-- flags is provided and it is mine.
		if guid and flags and band(flags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 then
			pets[guid] = {id = Skada.userGUID, name = Skada.userName}
			return pets[guid]
		end

		-- no owner yet?
		if guid then
			-- guess the pet from roster.
			local ownerUnit = GetPetOwnerUnit(guid)
			if ownerUnit then
				pets[guid] = {id = UnitGUID(ownerUnit), name = UnitName(ownerUnit)}
				return pets[guid]
			end

			-- guess the pet from tooltip.
			local ownerGUID, ownerName = GetPetOwnerFromTooltip(guid)
			if ownerGUID and ownerName then
				pets[guid] = {id = ownerGUID, name = ownerName}
				return pets[guid]
			end
		end

		return nil
	end

	function Skada:FixPets(action)
		if action and self:IsPet(action.playerid, action.playerflags) then
			local owner = pets[action.playerid] or CommonFixPets(action.playerid, action.playerflags)

			if owner then
				action.petname = action.playername

				if self.db.profile.mergepets then
					if action.spellname then
						action.spellname = action.spellname .. " (" .. action.playername .. ")"
					end
					action.playerid = owner.id
					action.playername = owner.name
				else
					-- just append the creature id to the player
					action.playerid = owner.id .. tonumber(action.playerid:sub(9, 12), 16)
					action.playername = action.playername .. " (" .. owner.name .. ")"
				end
			else
				-- if for any reason we fail to find the pets, we simply
				-- adds them separately as a single entry.
				action.playerid = action.playername
			end
		end
	end

	function Skada:FixMyPets(playerid, playername, playerflags)
		if players[playerid] or not self:IsPet(playerid, playername, playerflags) then
			return playerid, playername
		end

		if pets[playerid] then
			return pets[playerid].id or playerid, pets[playerid].name or playername
		end

		local owner = CommonFixPets(playerid, playerflags)
		if owner then
			return owner.id or playerid, owner.name or playername
		end

		return playerid, playername
	end
end

function Skada:AssignPet(ownerGUID, ownerName, petGUID)
	if ownerGUID and ownerName and petGUID and not pets[petGUID] then
		pets[petGUID] = {id = ownerGUID, name = ownerName}
	end
end

function Skada:DismissPet(petGUID, delay)
	if petGUID and pets[petGUID] then
		-- delayed for a reason (2 x MAINMENU_SLIDETIME).
		After(delay or 0.6, function() pets[petGUID] = nil end)
	end
end

function Skada:GetPetOwner(petGUID)
	return pets[petGUID]
end

function Skada:IsPet(petGUID, petFlags)
	return (petGUID and pets[petGUID]) or (tonumber(petFlags) and band(petFlags, BITMASK_PETS) ~= 0)
end

function Skada:PetDebug()
	self:CheckGroup()
	self:Print(PETS)
	for pet, owner in pairs(pets) do
		self:Printf("pet %s belongs to %s, %s", pet, owner.id, owner.name)
	end
end

-------------------------------------------------------------------------------
-- units fix function.
--
-- on certain servers, certain spells are not assigned properly and
-- in order to work around this, these functions were added.
--
-- for example, Death Knight' "Mark of Blood" healing is not considered
-- by Skada because the healing is attributed to the boss and not to the
-- player who used the spell, so in some modules you will find a table
-- called "queuedSpells" in which you can store a table of [spellid] = spellid
-- used by other modules.
-- In the case of "Mark of Blood" (49005), the healing from the spell 50424
-- is attributed to the target instead of the DK, so whenever Skada detects
-- a healing from 50424 it will check queued units, if found the player data
-- will be used.

function Skada:QueueUnit(spellid, srcGUID, srcName, srcFlags, dstGUID)
	if spellid and srcName and srcGUID and dstGUID and srcGUID ~= dstGUID then
		queuedUnits = queuedUnits or newTable()
		queuedUnits[spellid] = queuedUnits[spellid] or {}
		queuedUnits[spellid][dstGUID] = {id = srcGUID, name = srcName, flags = srcFlags}
	end
end

function Skada:UnqueueUnit(spellid, dstGUID)
	if spellid and dstGUID and queuedUnits and queuedUnits[spellid] then
		if queuedUnits[spellid][dstGUID] then
			queuedUnits[spellid][dstGUID] = nil
		end
		if Skada.tLength(queuedUnits[spellid]) == 0 then
			queuedUnits[spellid] = nil
		end
	end
end

function Skada:FixUnit(spellid, guid, name, flags)
	if spellid and guid and queuedUnits and queuedUnits[spellid] and queuedUnits[spellid][guid] then
		return queuedUnits[spellid][guid].id or guid, queuedUnits[spellid][guid].name or name, queuedUnits[spellid][guid].flags or flags
	end
	return guid, name, flags
end

function Skada:IsQueuedUnit(guid)
	if queuedUnits and tonumber(guid) then
		for _, units in pairs(queuedUnits) do
			for id, _ in pairs(units) do
				if id == guid then
					return true
				end
			end
		end
	end
	return false
end

-------------------------------------------------------------------------------
-- tooltip functions

-- sets the tooltip position
function Skada:SetTooltipPosition(tooltip, frame, display, win)
	if win and win.db.tooltippos ~= "NONE" then
		local anchor = win.db.tooltippos:find("TOP") and "TOP" or "BOTTOM"
		anchor = anchor .. (win.db.tooltippos:find("LEFT") and "RIGHT" or "LEFT")
		tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		tooltip:SetPoint(anchor, frame, win.db.tooltippos)
	elseif self.db.profile.tooltippos == "default" then
		tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		tooltip:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -40, 40)
	elseif self.db.profile.tooltippos == "cursor" then
		tooltip:SetOwner(frame, "ANCHOR_CURSOR")
	elseif self.db.profile.tooltippos == "smart" and frame then
		if display == "inline" then
			tooltip:SetOwner(frame, "ANCHOR_CURSOR")
			return
		end

		-- use effective scale so the tooltip doesn't become dumb
		-- if the window is scaled up.
		local s = frame:GetEffectiveScale() + 0.5
		if (frame:GetLeft() * s) < (GetScreenWidth() / 2) then
			tooltip:SetOwner(frame, "ANCHOR_NONE")
			tooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT", 10, 0)
		else
			tooltip:SetOwner(frame, "ANCHOR_NONE")
			tooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT", -10, 0)
		end
	else
		local anchor = self.db.profile.tooltippos:find("top") and "TOP" or "BOTTOM"
		anchor = anchor .. (self.db.profile.tooltippos:find("left") and "RIGHT" or "LEFT")
		tooltip:SetOwner(frame, "ANCHOR_NONE")
		tooltip:SetPoint(anchor, frame, self.db.profile.tooltippos)
	end
end

do
	local function value_sort(a, b)
		if not a or a.value == nil then
			return false
		elseif not b or b.value == nil then
			return true
		else
			return a.value > b.value
		end
	end

	function Skada.valueid_sort(a, b)
		if not a or a.value == nil or a.id == nil then
			return false
		elseif not b or b.value == nil or b.id == nil then
			return true
		else
			return a.value > b.value
		end
	end

	local white, ttwin = {r = 1, g = 1, b = 1}

	function Skada:AddSubviewToTooltip(tooltip, win, mode, id, label)
		if not (mode and mode.Update) then
			return
		end

		ttwin = win.ttwin or Window:new()
		win.ttwin = ttwin
		wipe(ttwin.dataset)

		if mode.Enter then
			mode:Enter(ttwin, id, label)
		end

		mode:Update(ttwin, win:get_selected_set())

		if not mode.metadata or not mode.metadata.ordersort then
			tsort(ttwin.dataset, value_sort)
		end

		if #ttwin.dataset > 0 then
			tooltip:AddLine(ttwin.title or mode.title or mode:GetName())
			local nr = 0

			for _, data in ipairs(ttwin.dataset) do
				if data.id and nr < Skada.db.profile.tooltiprows then
					nr = nr + 1
					local color = white

					if data.color then
						color = data.color
					elseif data.class and Skada.validclass[data.class] then
						color = Skada.classcolors[data.class]
					end

					local title = data.text or data.label
					if mode.metadata and mode.metadata.showspots then
						title = "|cffffffff" .. nr .. ".|r " .. title
					end
					tooltip:AddDoubleLine(title, data.valuetext, color.r, color.g, color.b)
					color, title = nil, nil
				end
			end

			if mode.Enter then
				tooltip:AddLine(" ")
			end
		end
	end

	local function ignoredTotalClick(win, click)
		if win and win.selectedset == "total" and win.metadata and win.metadata.nototalclick and click then
			return tContains(win.metadata.nototalclick, click)
		end
	end

	function Skada:ShowTooltip(win, id, label)
		local t = GameTooltip

		if self.db.profile.tooltips then
			if win.metadata.is_modelist and self.db.profile.informativetooltips then
				t:ClearLines()
				self:AddSubviewToTooltip(t, win, self:find_mode(id), id, label)
				t:Show()
			elseif win.metadata.click1 or win.metadata.click2 or win.metadata.click3 or win.metadata.tooltip then
				t:ClearLines()
				local hasClick = win.metadata.click1 or win.metadata.click2 or win.metadata.click3

				if win.metadata.tooltip then
					local numLines = t:NumLines()
					win.metadata.tooltip(win, id, label, t)

					if t:NumLines() ~= numLines and hasClick then
						t:AddLine(" ")
					end
				end

				if self.db.profile.informativetooltips then
					if win.metadata.click1 and not ignoredTotalClick(win, win.metadata.click1) then
						self:AddSubviewToTooltip(t, win, win.metadata.click1, id, label)
					end
					if win.metadata.click2 and not ignoredTotalClick(win, win.metadata.click2) then
						self:AddSubviewToTooltip(t, win, win.metadata.click2, id, label)
					end
					if win.metadata.click3 and not ignoredTotalClick(win, win.metadata.click3) then
						self:AddSubviewToTooltip(t, win, win.metadata.click3, id, label)
					end
				end

				if win.metadata.post_tooltip then
					local numLines = t:NumLines()
					win.metadata.post_tooltip(win, id, label, t)

					if t:NumLines() ~= numLines and hasClick then
						t:AddLine(" ")
					end
				end

				if win.metadata.click1 and not ignoredTotalClick(win, win.metadata.click1) then
					t:AddLine(L["Click for"] .. " |cff00ff00" .. (win.metadata.click1.label or win.metadata.click1:GetName()) .. "|r.", 1, 0.82, 0)
				end
				if win.metadata.click2 and not ignoredTotalClick(win, win.metadata.click2) then
					t:AddLine(L["Shift-Click for"] .. " |cff00ff00" .. (win.metadata.click2.label or win.metadata.click2:GetName()) .. "|r.", 1, 0.82, 0)
				end
				if win.metadata.click3 and not ignoredTotalClick(win, win.metadata.click3) then
					t:AddLine(L["Control-Click for"] .. " |cff00ff00" .. (win.metadata.click3.label or win.metadata.click3:GetName()) .. "|r.", 1, 0.82, 0)
				end

				t:Show()
			end
		end
	end
end

-------------------------------------------------------------------------------
-- slash commands

local function SlashCommandHandler(cmd)
	if cmd == "pets" then
		Skada:PetDebug()
	elseif cmd == "reset" then
		Skada:Reset(IsShiftKeyDown())
	elseif cmd == "newsegment" then
		Skada:NewSegment()
	elseif cmd == "toggle" then
		Skada:ToggleWindow()
	elseif cmd == "show" then
		if Skada.db.profile.hidden then
			Skada.db.profile.hidden = false
			Skada:ApplySettings()
		end
	elseif cmd == "hide" then
		if not Skada.db.profile.hidden then
			Skada.db.profile.hidden = true
			Skada:ApplySettings()
		end
	elseif cmd == "debug" then
		Skada.db.profile.debug = not Skada.db.profile.debug
		Skada:Print("Debug mode " .. (Skada.db.profile.debug and ("|cFF00FF00" .. L["ENABLED"] .. "|r") or ("|cFFFF0000" .. L["DISABLED"] .. "|r")))
	elseif cmd == "config" then
		Skada:OpenOptions()
	elseif cmd == "clear" or cmd == "clean" then
		Skada:CleanGarbage()
	elseif cmd == "import" and Skada.OpenImport then
		Skada:OpenImport()
	elseif cmd == "export" and Skada.ExportProfile then
		Skada:ExportProfile()
	elseif cmd == "about" or cmd == "info" then
		Skada:OpenOptions(nil, "about")
	elseif cmd == "website" or cmd == "github" then
		Skada:Printf("|cffffbb00%s|r", Skada.website)
	elseif cmd == "discord" then
		Skada:Printf("|cffffbb00%s|r", Skada.discord)
	elseif cmd == "timemesure" or cmd == "measure" then
		if Skada.db.profile.timemesure == 2 then
			Skada.db.profile.timemesure = 1
			Skada:Print(L["Time measure"] .. ": " .. L["Activity time"])
			Skada:ApplySettings()
		elseif Skada.db.profile.timemesure == 1 then
			Skada.db.profile.timemesure = 2
			Skada:Print(L["Time measure"] .. ": " .. L["Effective time"])
			Skada:ApplySettings()
		end
	elseif cmd == "numformat" then
		Skada.db.profile.numberformat = Skada.db.profile.numberformat + 1
		if Skada.db.profile.numberformat > 3 then
			Skada.db.profile.numberformat = 1
		end
		Skada:ApplySettings()
	elseif cmd:sub(1, 6) == "report" then
		cmd = cmd:sub(7):trim()

		local w1, w2, w3 = strsplit(" ", cmd, 3)

		local chan = w1 and w1:trim() or "say"
		local report_mode_name = w2 or L["Damage"]
		local num = tonumber(w3 or 10)

		-- Sanity checks.
		if chan and (chan == "say" or chan == "guild" or chan == "raid" or chan == "party" or chan == "officer") and (report_mode_name and Skada:find_mode(report_mode_name)) then
			Skada:Report(chan, "preset", report_mode_name, "current", num)
		else
			Skada:Print("Usage:")
			Skada:Printf("%-20s", "/skada report [raid|guild|party|officer|say] [mode] [max lines]")
		end
	else
		Skada:Print("Usage:")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33report|r [raid|guild|party|officer|say] [mode] [max lines]")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33reset|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33toggle|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33show|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33hide|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33newsegment|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33numformat|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33measure|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33config|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33clean|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33import|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33export|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33about|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33website|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33discord|r")
		Skada:Printf("%-20s", "|cffffaeae/skada|r |cffffff33debug|r")
	end
end

-------------------------------------------------------------------------------
-- report function

do
	local SendChatMessage = SendChatMessage

	function Skada:SendChat(msg, chan, chantype)
		if chantype == "self" then
			Skada:Print(msg)
		elseif chantype == "channel" then
			SendChatMessage(msg, "CHANNEL", nil, chan)
		elseif chantype == "preset" then
			SendChatMessage(msg, chan:upper())
		elseif chantype == "whisper" then
			SendChatMessage(msg, "WHISPER", nil, chan)
		elseif chantype == "bnet" then
			BNSendWhisper(chan, msg)
		end
	end

	function Skada:Report(channel, chantype, report_mode_name, report_set_name, maxlines, window, barid)
		if chantype == "channel" then
			local list = {GetChannelList()}
			for i = 1, table.getn(list) / 2 do
				if (self.db.profile.report.channel == list[i * 2]) then
					channel = list[i * 2 - 1]
					break
				end
			end
			list = nil
		end

		local report_table, report_set, report_mode

		if not window then
			report_mode = self:find_mode(report_mode_name or L["Damage"])
			report_set = self:GetSet(report_set_name or "current")
			if report_set == nil then
				return
			end

			report_table = Window:new()
			report_mode:Update(report_table, report_set)
		else
			report_table = window
			report_set = window:get_selected_set()
			report_mode = window.selectedmode
		end

		if not report_set then
			Skada:Print(L["There is nothing to report."])
			return
		end

		if not report_table.metadata.ordersort then
			tsort(report_table.dataset, Skada.valueid_sort)
		end

		if not report_mode then
			self:Print(L["No mode or segment selected for report."])
			return
		end

		local title = (window and window.title) or report_mode.title or report_mode:GetName()
		local label = (report_mode_name == L["Improvement"]) and self.userName or Skada:GetSetLabel(report_set)
		self:SendChat(format(L["Skada: %s for %s:"], title, label), channel, chantype)

		maxlines = maxlines or 10
		local nr = 1
		for _, data in ipairs(report_table.dataset) do
			if ((barid and barid == data.id) or (data.id and not barid)) and not data.ignore then
				local label
				if data.reportlabel then
					label = data.reportlabel
				elseif self.db.profile.reportlinks and (data.spellid or data.hyperlink) then
					label = format("%s   %s", data.hyperlink or self.GetSpellLink(data.spellid) or data.label, data.valuetext)
				else
					label = format("%s   %s", data.label, data.valuetext)
				end

				if label and report_mode.metadata and report_mode.metadata.showspots then
					self:SendChat(format("%s. %s", nr, label), channel, chantype)
				elseif label then
					self:SendChat(label, channel, chantype)
				end

				if barid then
					break
				end

				nr = nr + 1
			end

			if nr > maxlines then
				break
			end
		end
		title, label, nr = nil, nil, nil
	end
end

-------------------------------------------------------------------------------
-- feed functions

function Skada:SetFeed(feed)
	selectedfeed = feed
	self:UpdateDisplay()
end

function Skada:AddFeed(name, func)
	feeds[name] = func
end

function Skada:RemoveFeed(name)
	for i, feed in ipairs(feeds) do
		if feed.name == name then
			tremove(feeds, i)
		end
	end
end

function Skada:GetFeeds()
	return feeds
end

-------------------------------------------------------------------------------

function Skada:CheckGroup(petsOnly)
	for unit, owner in UnitIterator() do
		local guid = UnitGUID(unit)
		if guid and owner == nil and not petsOnly then
			players[guid] = unit
		elseif guid and owner then
			Skada:AssignPet(UnitGUID(owner), UnitName(owner), guid)
		end
	end
end

do
	local inInstance, isininstance, isinpvp

	function Skada:CheckZone()
		inInstance, self.instanceType = IsInInstance()
		isininstance = inInstance and (self.instanceType == "party" or self.instanceType == "raid")
		isinpvp = self.IsInPvP()

		if isininstance and wasininstance ~= nil and not wasininstance and self.db.profile.reset.instance ~= 1 and self:CanReset() then
			if self.db.profile.reset.instance == 3 then
				self:ShowPopup(nil, true)
			else
				self:Reset()
			end
		end

		if self.db.profile.hidepvp then
			if isinpvp then
				self:SetActive(false)
			elseif wasinpvp then
				self:SetActive(true)
			end
		end

		wasininstance = (isininstance == true)
		wasinpvp = (isinpvp == true)
		wasinparty = self.IsInGroup()
		self.callbacks:Fire("SKADA_ZONE_CHECK")
	end
end

do
	local version_count = 0

	function checkVersion()
		Skada:SendComm(nil, nil, "VersionCheck", Skada.version)
		version_timer = CancelTimer(version_timer)
	end

	function convertVersion(ver)
		return tonumber(type(ver) == "string" and ver:gsub("%.", "") or ver)
	end

	function Skada:OnCommVersionCheck(sender, version)
		if sender and sender ~= self.userName and version then
			version = convertVersion(version)
			local ver = convertVersion(self.version)
			if not (version and ver) or self.versionChecked then
				return
			end

			if (version > ver) then
				self:Printf(L["Skada is out of date. You can download the newest version from |cffffbb00%s|r"], self.website)
			elseif (version < ver) then
				self:SendComm("WHISPER", sender, "VersionCheck", self.version)
			end

			self.versionChecked = true
		end
	end

	function check_for_join_and_leave()
		if not Skada.IsInGroup() and wasinparty then
			if Skada.db.profile.reset.leave == 3 and Skada:CanReset() then
				Skada:ShowPopup(nil, true)
			elseif Skada.db.profile.reset.leave == 2 and Skada:CanReset() then
				Skada:Reset()
			end

			if Skada.db.profile.hidesolo then
				Skada:SetActive(false)
			end
		end

		if Skada.IsInGroup() and not wasinparty then
			if Skada.db.profile.reset.join == 3 and Skada:CanReset() then
				Skada:ShowPopup(nil, true)
			elseif Skada.db.profile.reset.join == 2 and Skada:CanReset() then
				Skada:Reset()
			end

			if Skada.db.profile.hidesolo and not (Skada.db.profile.hidepvp and Skada.IsInPvP()) then
				Skada:SetActive(true)
			end
		end

		wasinparty = not (not Skada.IsInGroup())
	end

	function Skada:PARTY_MEMBERS_CHANGED()
		check_for_join_and_leave()
		self:CheckGroup()

		-- version check
		local t, _, count = GetGroupTypeAndCount()
		if t == "party" then
			count = count + 1
		end
		if count ~= version_count then
			if count > 1 and count > version_count then
				version_timer = version_timer or NewTimer(10, checkVersion)
			end
			version_count = count
		end
	end
	Skada.RAID_ROSTER_UPDATE = Skada.PARTY_MEMBERS_CHANGED
end

do
	local UnitHasVehicleUI = UnitHasVehicleUI
	local ignoredUnits = {"target", "focus", "npc", "NPC", "mouseover"}

	function Skada:UNIT_PET(_, unit)
		if unit and not tContains(ignoredUnits, unit) then
			self:CheckGroup(true)
		end
	end

	function Skada:CheckVehicle(_, unit)
		if unit and not tContains(ignoredUnits, unit) then
			local guid = UnitGUID(unit)
			if guid and players[guid] then
				if UnitHasVehicleUI(unit) then
					local prefix, id, suffix = unit:match("([^%d]+)([%d]*)(.*)")
					local vUnitId = prefix .. "pet" .. id .. suffix
					if UnitExists(vUnitId) then
						self:AssignPet(guid, UnitName(unit), UnitGUID(vUnitId))
						vehicles[guid] = UnitGUID(vUnitId)
					end
				elseif vehicles[guid] then
					self:DismissPet(vehicles[guid])
				end
			end
		end
	end
end

-------------------------------------------------------------------------------

function Skada:CanReset()
	local totalplayers = self.total and self.total.players
	if totalplayers and next(totalplayers) then
		return true
	end

	for _, set in self:IterateSets() do
		if not set.keep then
			return true
		end
	end

	return false
end

function Skada:Reset(force)
	if force then
		self.char.sets = wipe(self.char.sets or {})
		self.char.total = nil
		self:Reset()
		After(3, self.ReloadSettings)
		return
	end

	self:Wipe()

	pets = wipe(pets or {})
	players = wipe(players or {})
	vehicles = wipe(vehicles or {})

	self:CheckGroup()

	if self.current ~= nil then
		wipe(self.current)
		self.current = self:CreateSet(L["Current"])
	end

	if self.total ~= nil then
		wipe(self.total)
		self.total = self:CreateSet(L["Total"])
		self.char.total = self.total
	end
	self.last = nil

	for i = tmaxn(self.char.sets), 1, -1 do
		if not self.char.sets[i].keep then
			wipe(tremove(self.char.sets, i))
		end
	end

	for _, win in self:IterateWindows() do
		if win.selectedset ~= "total" then
			win.selectedset = "current"
			win.changed = true
			win:RestoreView()
		end
	end

	dataobj.text = "n/a"
	self:UpdateDisplay(true)
	self:CleanGarbage()
	self:Print(L["All data has been reset."])
	CloseDropDownMenus()

	self.callbacks:Fire("SKADA_DATA_RESET")
end

function Skada:UpdateDisplay(force)
	if force then
		self.changed = true
	end

	if selectedfeed ~= nil then
		local feedtext = selectedfeed()
		if feedtext then
			dataobj.text = feedtext
		end
	end

	for _, win in self:IterateWindows() do
		if (self.changed or win.changed) or self.current then
			win.changed = false

			if win.selectedmode then
				local set = win:get_selected_set()

				if set then
					win:UpdateInProgress()

					if win.selectedmode.Update then
						if set then
							win.selectedmode:Update(win, set)
						else
							self:Printf("No set available to pass to %s Update function! Try to reset Skada.", win.selectedmode:GetName())
						end
					elseif win.selectedmode.GetName then
						self:Print("Mode %s does not have an Update function!", win.selectedmode:GetName())
					end

					if self.db.profile.showtotals and win.selectedmode.GetSetSummary then
						local valuetext, total = win.selectedmode:GetSetSummary(set)
						local existing = nil  -- an existing bar?

						if not total then
							total = 0
							for _, data in ipairs(win.dataset) do
								if data.id then
									total = total + data.value
								end
								if not existing and not data.id then
									existing = data
								end
							end
						end
						total = total + 1

						local d = existing or {}
						d.id = "total"
						d.label = L["Total"]
						d.icon = dataobj.icon
						d.ignore = true
						d.value = total
						d.valuetext = valuetext
						if not existing then tinsert(win.dataset, 1, d) end
						self.callbacks:Fire("SKADA_MODE_BAR", d, win.selectedmode)
					end
				end

				win:UpdateDisplay()
			elseif win.selectedset then
				local set = win:get_selected_set()

				for m, mode in self:IterateModes() do
					local d = win.dataset[m] or {}
					win.dataset[m] = d

					d.id = mode:GetName()
					d.label = mode:GetName()
					d.value = 1

					if set and mode.GetSetSummary ~= nil then
						d.valuetext = mode:GetSetSummary(set)
					end
					self.callbacks:Fire("SKADA_MODE_BAR", d, mode)
				end

				win.metadata.ordersort = true

				if set then
					win.metadata.is_modelist = true
				end

				win:UpdateDisplay()
			else
				local nr = 1
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = "total"
				d.label = L["Total"]
				d.value = 1

				nr = nr + 1
				d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = "current"
				d.label = L["Current"]
				d.value = 1

				for _, set in self:IterateSets() do
					nr = nr + 1
					d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = tostring(set.starttime)
					d.label = set.name
					d.valuetext = date("%H:%M", set.starttime) .. " - " .. date("%H:%M", set.endtime)
					d.value = 1
					if set.keep then
						d.emphathize = true
					end
				end

				win.metadata.ordersort = true
				win:UpdateDisplay()
			end
		end
	end

	self.changed = nil
end

-------------------------------------------------------------------------------
-- format functions

function Skada:FormatNumber(number, fmt)
	if number then
		fmt = fmt or self.db.profile.numberformat or 1
		if fmt == 1 then
			if number > 999999999 or number < -999999999 then
				return format("%02.3fB", number / 1000000000)
			elseif number > 999999 or number < -999999 then
				return format("%02.2fM", number / 1000000)
			elseif number > 999 or number < -999 then
				return format("%02.1fK", number / 1000)
			end
			return floor(number)
		elseif fmt == 2 then
			local left, num, right = tostring(floor(number)):match("^([^%d]*%d)(%d*)(.-)$")
			return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
		else
			return floor(number)
		end
	end
end

function Skada:FormatPercent(value, total, dec)
	dec = dec or self.db.profile.decimals or 1
	if total == nil then
		return format("%." .. dec .. "f%%", value)
	end
	return format("%." .. dec .. "f%%", 100 * value / max(1, total))
end

function Skada:FormatTime(sec)
	if sec then
		if sec >= 3600 then
			local h = floor(sec / 3600)
			local m = floor(sec / 60 - (h * 60))
			local s = floor(sec - h * 3600 - m * 60)
			return format("%02.f:%02.f:%02.f", h, m, s)
		end

		return format("%02.f:%02.f", floor(sec / 60), floor(sec % 60))
	end
end

function Skada:FormatName(name, guid)
	if self.db.profile.translit and Translit then
		name = Translit:Transliterate(name, "!")
	end
	return name
end

function Skada:FormatValueText(...)
	local value1, bool1, value2, bool2, value3, bool3 = ...

	if bool1 and bool2 and bool3 then
		return value1 .. " (" .. value2 .. ", " .. value3 .. ")"
	elseif bool1 and bool2 then
		return value1 .. " (" .. value2 .. ")"
	elseif bool1 and bool3 then
		return value1 .. " (" .. value3 .. ")"
	elseif bool2 and bool3 then
		return value2 .. " (" .. value3 .. ")"
	elseif bool2 then
		return value2
	elseif bool1 then
		return value1
	elseif bool3 then
		return value3
	end
end

do
	local numsetfmts, fakeFrame = 8

	local function SetLabelFormat(name, starttime, endtime, fmt)
		fmt = fmt or Skada.db.profile.setformat
		local namelabel = name
		if fmt < 1 or fmt > numsetfmts then
			fmt = 3
		end

		local timelabel = ""
		if starttime and endtime and fmt > 1 then
			fakeFrame = fakeFrame or CreateFrame("Frame")
			local duration = SecondsToTime(endtime - starttime, false, false, 2)
			Skada.getsetlabel_fs = Skada.getsetlabel_fs or fakeFrame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
			Skada.getsetlabel_fs:SetText(duration)
			duration = "(" .. Skada.getsetlabel_fs:GetText() .. ")"

			if fmt == 2 then
				timelabel = duration
			elseif fmt == 3 then
				timelabel = date("%H:%M", starttime) .. " " .. duration
			elseif fmt == 4 then
				timelabel = date("%I:%M %p", starttime) .. " " .. duration
			elseif fmt == 5 then
				timelabel = date("%H:%M", starttime) .. " - " .. date("%H:%M", endtime)
			elseif fmt == 6 then
				timelabel = date("%I:%M %p", starttime) .. " - " .. date("%I:%M %p", endtime)
			elseif fmt == 7 then
				timelabel = date("%H:%M:%S", starttime) .. " - " .. date("%H:%M:%S", endtime)
			elseif fmt == 8 then
				timelabel = date("%H:%M", starttime) .. " - " .. date("%H:%M", endtime) .. " " .. duration
			end
		end

		local comb
		if #namelabel == 0 or #timelabel == 0 then
			comb = namelabel .. timelabel
		else
			comb = namelabel .. (timelabel:match("^%p") and " " or ": ") .. timelabel
		end

		return comb, namelabel, timelabel
	end

	function Skada:SetLabelFormats()
		local ret, start = {}, 1631547006
		for i = 1, numsetfmts do
			ret[i] = SetLabelFormat(LBB["Hogger"], start, start + 380, i)
		end
		return ret
	end

	function Skada:GetSetLabel(set)
		if not set then
			return ""
		end
		return SetLabelFormat(set.name or UNKNOWN, set.starttime, set.endtime or time())
	end

	function Window:set_mode_title()
		if
			not self.db.enabletitle or -- title bar disabled
			not self.selectedmode or -- window has no selected mode
			not self.selectedmode.GetName or -- selected mode isn't a valid mode
			not self.selectedset  -- window has no selected set
		then
			return
		end

		local name = (self.parentmode and self.parentmode:GetName()) or self.selectedmode.title or self.selectedmode:GetName()

		-- save window settings for RestoreView after reload
		self.db.set = self.selectedset
		local savemode = name
		if self.history[1] then -- can't currently preserve a nested mode, use topmost one
			savemode = self.history[1].title or self.history[1]:GetName()
		end
		self.db.mode = savemode

		name = self.title or name

		if self.db.display == "bar" and not self.selectedmode.notitleset then
			-- title set enabled?
			if self.db.titleset then
				if self.selectedset == "current" then
					name = name .. ": " .. L["Current"]
				elseif self.selectedset == "total" then
					name = name .. ": " .. L["Total"]
				else
					local set = self:get_selected_set()
					if set then
						name = name .. ": " .. Skada:GetSetLabel(set)
					end
				end
			end
			-- combat timer enabled?
			if self.db.combattimer and (self.selectedset == "current" or self.selectedset == "last") and (Skada.current or Skada.last) then
				name = format("[%s] %s", Skada:GetFormatedSetTime(Skada.current or Skada.last), name)
			end
		end

		self.metadata.title = name
		self.display:SetTitle(self, name)
	end
end

function Window:RestoreView(theset, themode)
	if self.history[1] then
		-- clear history and title
		self.history, self.title = wipe(self.history or {}), nil

		-- all all stuff that were registered by modules
		self.datakey = nil
		self.playerid, self.playername = nil, nil
		self.spellid, self.spellname = nil, nil
		self.targetid, self.targetname = nil, nil
	end

	-- force menu to close and let Skada handle the rest
	CloseDropDownMenus()
	Skada:RestoreView(self, theset or self.selectedset, themode or self.db.mode)
end

-------------------------------------------------------------------------------

function dataobj:OnEnter()
	self.tooltip = self.tooltip or GameTooltip
	self.tooltip:SetOwner(self, "ANCHOR_NONE")
	self.tooltip:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT")
	self.tooltip:ClearLines()

	local set
	if Skada.current then
		set = Skada.current
	else
		set = Skada.char.sets[1]
	end
	if set then
		self.tooltip:AddDoubleLine(L["Skada Summary"], Skada.version)
		self.tooltip:AddLine(" ")
		self.tooltip:AddDoubleLine(L["Segment Time"], Skada:GetFormatedSetTime(set), 1, 1, 1)
		for _, mode in Skada:IterateModes() do
			if mode.AddToTooltip ~= nil then
				mode:AddToTooltip(set, self.tooltip)
			end
		end
		self.tooltip:AddLine(" ")
	else
		self.tooltip:AddDoubleLine("Skada", Skada.version)
	end

	self.tooltip:AddLine(L["|cffeda55fLeft-Click|r to toggle windows."], 0.2, 1, 0.2)
	self.tooltip:AddLine(L["|cffeda55fCtrl+Left-Click|r to show/hide windows."], 0.2, 1, 0.2)
	self.tooltip:AddLine(L["|cffeda55fShift+Left-Click|r to reset."], 0.2, 1, 0.2)
	self.tooltip:AddLine(L["|cffeda55fRight-Click|r to open menu."], 0.2, 1, 0.2)

	self.tooltip:Show()
end

function dataobj:OnLeave()
	self.tooltip:Hide()
end

function dataobj:OnClick(button)
	if button == "LeftButton" and IsControlKeyDown() then
		Skada.db.profile.hidden = not Skada.db.profile.hidden
		Skada:ApplySettings()
	elseif button == "LeftButton" and IsShiftKeyDown() then
		Skada:ShowPopup()
	elseif button == "LeftButton" then
		Skada:ToggleWindow()
	elseif button == "RightButton" then
		Skada:OpenMenu()
	end
end

function Skada:OpenOptions(win, tab)
	if win then
		ACD:Open("Skada")
		ACD:SelectGroup("Skada", "windows", win.db.name)
	elseif tab then
		ACD:Open("Skada")
		ACD:SelectGroup("Skada", tab)
	elseif not ACD:Close("Skada") then
		ACD:Open("Skada")
	end
end

function Skada:RefreshMMButton()
	if DBI then
		DBI:Refresh("Skada", self.db.profile.icon)
		if self.db.profile.icon.hide then
			DBI:Hide("Skada")
		else
			DBI:Show("Skada")
		end
	end
end

function Skada:ApplySettings(name)
	for _, win in Skada:IterateWindows() do
		if name == nil or (name and win.db.name == name) then
			win:SetChild(win.db.child)
			win.display:ApplySettings(win)
		end
	end

	if (Skada.db.profile.hidesolo and not Skada.IsInGroup()) or (Skada.db.profile.hidepvp and Skada.IsInPvP()) then
		Skada:SetActive(false)
	else
		Skada:SetActive(true)

		for _, win in Skada:IterateWindows() do
			if (win.db.hidden or (not win.db.hidden and Skada.db.profile.showcombat)) and win:IsShown() then
				win:Hide()
			end
		end
	end

	Skada:UpdateDisplay(true)

	-- in case of future code change or database structure changes, this
	-- code here will be used to perform any database modifications.
	local curversion = convertVersion(Skada.version)
	if type(Skada.db.global.version) ~= "number" or curversion > Skada.db.global.version then
		Skada.callbacks:Fire("SKADA_CORE_UPDATE", Skada.db.global.version)
		Skada.db.global.version = curversion
	end
	if type(Skada.char.version) ~= "number" or (curversion - Skada.char.version) >= 5 then
		Skada.callbacks:Fire("SKADA_DATA_UPDATE", Skada.char.version)
		Skada:Reset(true)
		Skada.char.version = curversion
	end
end

function Skada:ReloadSettings()
	for _, win in Skada:IterateWindows() do
		win:destroy()
	end
	windows = {}

	for _, win in ipairs(Skada.db.profile.windows) do
		Skada:CreateWindow(win.name, win)
	end

	Skada.total = Skada.char.total

	Skada:ClearAllIndexes()

	if DBI and not DBI:IsRegistered("Skada") then
		DBI:Register("Skada", dataobj, Skada.db.profile.icon)
	end
	Skada:RefreshMMButton()
	Skada:ApplySettings()

	-- fix setstokeep
	if (Skada.db.profile.setstokeep or 0) > 30 then
		Skada.db.profile.setstokeep = 30
	end

	-- fix time measure
	if Skada.db.profile.timemesure == nil then
		Skada.db.profile.timemesure = 1
	end

	-- remove old improvement data
	if Skada.char.improvement then
		if Skada.char.improvement.bosses then
			SkadaImprovementDB = CopyTable(Skada.char.improvement.bosses or {})
		else
			SkadaImprovementDB = CopyTable(Skada.char.improvement)
		end
		Skada.char.improvement = nil
	end
end

-------------------------------------------------------------------------------

function Skada:ApplyBorder(frame, texture, color, thickness, padtop, padbottom, padleft, padright)
	local borderbackdrop = newTable()

	if not frame.borderFrame then
		frame.borderFrame = CreateFrame("Frame", nil, frame)
		frame.borderFrame:SetFrameLevel(0)
	end

	frame.borderFrame:SetPoint("TOPLEFT", frame, -thickness - (padleft or 0), thickness + (padtop or 0))
	frame.borderFrame:SetPoint("BOTTOMRIGHT", frame, thickness + (padright or 0), -thickness - (padbottom or 0))

	if texture and thickness > 0 then
		borderbackdrop.edgeFile = LSM:Fetch("border", texture)
	else
		borderbackdrop.edgeFile = nil
	end

	borderbackdrop.edgeSize = thickness
	frame.borderFrame:SetBackdrop(borderbackdrop)
	delTable(borderbackdrop)
	if color then
		frame.borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
	end
end

function Skada:FrameSettings(db, include_dimensions)
	local obj = {
		type = "group",
		name = L["Window"],
		desc = format(L["Options for %s."], L["Window"]),
		get = function(i)
			return db[i[#i]]
		end,
		set = function(i, val)
			db[i[#i]] = val
			Skada:ApplySettings(db.name)
		end,
		order = 3,
		args = {
			position = {
				type = "group",
				name = L["Position Settings"],
				inline = true,
				order = 0,
				args = {
					scale = {
						type = "range",
						name = L["Scale"],
						desc = L["Sets the scale of the window."],
						order = 5,
						width = "double",
						min = 0.1,
						max = 3,
						step = 0.01,
						bigStep = 0.1
					},
					strata = {
						type = "select",
						name = L["Strata"],
						desc = L["This determines what other frames will be in front of the frame."],
						order = 6,
						values = {
							["BACKGROUND"] = "BACKGROUND",
							["LOW"] = "LOW",
							["MEDIUM"] = "MEDIUM",
							["HIGH"] = "HIGH",
							["DIALOG"] = "DIALOG",
							["FULLSCREEN"] = "FULLSCREEN",
							["FULLSCREEN_DIALOG"] = "FULLSCREEN_DIALOG"
						}
					},
					tooltippos = {
						type = "select",
						name = L["Tooltip position"],
						desc = L["Position of the tooltips."],
						order = 7,
						values = {
							["NONE"] = NONE,
							["TOPRIGHT"] = L["Top right"],
							["TOPLEFT"] = L["Top left"],
							["BOTTOMRIGHT"] = L["Bottom right"],
							["BOTTOMLEFT"] = L["Bottom left"]
						},
						get = function()
							return db.tooltippos or "NONE"
						end
					}
				}
			},
			background = {
				type = "group",
				name = L["Background"],
				inline = true,
				order = 1,
				args = {
					texture = {
						type = "select",
						dialogControl = "LSM30_Background",
						name = L["Background texture"],
						desc = L["The texture used as the background."],
						order = 1,
						width = "double",
						values = AceGUIWidgetLSMlists.background,
						get = function()
							return db.background.texture
						end,
						set = function(_, key)
							db.background.texture = key
							Skada:ApplySettings(db.name)
						end
					},
					tile = {
						type = "toggle",
						name = L["Tile"],
						desc = L["Tile the background texture."],
						order = 2,
						width = "double",
						get = function()
							return db.background.tile
						end,
						set = function(_, key)
							db.background.tile = key
							Skada:ApplySettings(db.name)
						end
					},
					tilesize = {
						type = "range",
						name = L["Tile size"],
						desc = L["The size of the texture pattern."],
						order = 3,
						width = "double",
						min = 0,
						max = floor(GetScreenWidth()),
						step = 0.1,
						bigStep = 1,
						get = function()
							return db.background.tilesize
						end,
						set = function(_, val)
							db.background.tilesize = val
							Skada:ApplySettings(db.name)
						end
					},
					color = {
						type = "color",
						name = L["Background color"],
						desc = L["The color of the background."],
						order = 4,
						width = "double",
						hasAlpha = true,
						get = function()
							local c = db.background.color
							return c.r, c.g, c.b, c.a
						end,
						set = function(_, r, g, b, a)
							db.background.color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
							Skada:ApplySettings(db.name)
						end
					}
				}
			},
			border = {
				type = "group",
				name = L["Border"],
				inline = true,
				order = 2,
				args = {
					bordertexture = {
						type = "select",
						dialogControl = "LSM30_Border",
						name = L["Border texture"],
						desc = L["The texture used for the borders."],
						order = 1,
						width = "double",
						values = AceGUIWidgetLSMlists.border,
						get = function()
							return db.background.bordertexture
						end,
						set = function(_, key)
							db.background.bordertexture = key
							if key == "None" then
								db.background.borderthickness = 1
							end
							Skada:ApplySettings(db.name)
						end
					},
					bordercolor = {
						type = "color",
						name = L["Border color"],
						desc = L["The color used for the border."],
						order = 2,
						width = "double",
						hasAlpha = true,
						get = function()
							local c = db.background.bordercolor or {r = 0, g = 0, b = 0, a = 1}
							return c.r, c.g, c.b, c.a
						end,
						set = function(_, r, g, b, a)
							db.background.bordercolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
							Skada:ApplySettings(db.name)
						end
					},
					thickness = {
						type = "range",
						name = L["Border thickness"],
						desc = L["The thickness of the borders."],
						order = 3,
						width = "double",
						min = 0,
						max = 50,
						step = 0.01,
						bigStep = 0.5,
						get = function()
							return db.background.borderthickness
						end,
						set = function(_, val)
							db.background.borderthickness = val
							Skada:ApplySettings(db.name)
						end
					}
				}
			}
		}
	}

	if include_dimensions then
		obj.args.position.args.width = {
			type = "range",
			name = L["Width"],
			order = 1,
			min = 100,
			max = floor(GetScreenWidth()),
			step = 0.01,
			bigStep = 1
		}

		obj.args.position.args.height = {
			type = "range",
			name = L["Height"],
			order = 2,
			min = 16,
			max = 400,
			step = 0.01,
			bigStep = 1
		}
	end

	return obj
end

-------------------------------------------------------------------------------

function Skada:OnInitialize()
	LSM:Register("font", "ABF", [[Interface\Addons\Skada\Media\Fonts\ABF.ttf]])
	LSM:Register("font", "Accidental Presidency", [[Interface\Addons\Skada\Media\Fonts\Accidental Presidency.ttf]])
	LSM:Register("font", "Adventure", [[Interface\Addons\Skada\Media\Fonts\Adventure.ttf]])
	LSM:Register("font", "Continuum Medium", [[Interface\Addons\Skada\Media\Fonts\ContinuumMedium.ttf]])
	LSM:Register("font", "Diablo", [[Interface\Addons\Skada\Media\Fonts\Diablo.ttf]])
	LSM:Register("font", "Forced Square", [[Interface\Addons\Skada\Media\Fonts\FORCED SQUARE.ttf]])
	LSM:Register("font", "FrancoisOne", [[Interface\Addons\Skada\Media\Fonts\FrancoisOne.ttf]])
	LSM:Register("font", "Hooge", [[Interface\Addons\Skada\Media\Fonts\Hooge.ttf]])

	LSM:Register("statusbar", "Aluminium", [[Interface\Addons\Skada\Media\Statusbar\Aluminium]])
	LSM:Register("statusbar", "Armory", [[Interface\Addons\Skada\Media\Statusbar\Armory]])
	LSM:Register("statusbar", "BantoBar", [[Interface\Addons\Skada\Media\Statusbar\BantoBar]])
	LSM:Register("statusbar", "Flat", [[Interface\Addons\Skada\Media\Statusbar\Flat]])
	LSM:Register("statusbar", "Glass", [[Interface\AddOns\Skada\Media\Statusbar\Glass]])
	LSM:Register("statusbar", "Gloss", [[Interface\Addons\Skada\Media\Statusbar\Gloss]])
	LSM:Register("statusbar", "Graphite", [[Interface\Addons\Skada\Media\Statusbar\Graphite]])
	LSM:Register("statusbar", "Grid", [[Interface\Addons\Skada\Media\Statusbar\Grid]])
	LSM:Register("statusbar", "Healbot", [[Interface\Addons\Skada\Media\Statusbar\Healbot]])
	LSM:Register("statusbar", "LiteStep", [[Interface\Addons\Skada\Media\Statusbar\LiteStep]])
	LSM:Register("statusbar", "Minimalist", [[Interface\Addons\Skada\Media\Statusbar\Minimalist]])
	LSM:Register("statusbar", "Otravi", [[Interface\Addons\Skada\Media\Statusbar\Otravi]])
	LSM:Register("statusbar", "Outline", [[Interface\Addons\Skada\Media\Statusbar\Outline]])
	LSM:Register("statusbar", "Round", [[Interface\Addons\Skada\Media\Statusbar\Round]])
	LSM:Register("statusbar", "Serenity", [[Interface\AddOns\Skada\Media\Statusbar\Serenity]])
	LSM:Register("statusbar", "Smooth v2", [[Interface\Addons\Skada\Media\Statusbar\Smoothv2]])
	LSM:Register("statusbar", "Smooth", [[Interface\Addons\Skada\Media\Statusbar\Smooth]])
	LSM:Register("statusbar", "Solid", [[Interface\Buttons\WHITE8X8]])
	LSM:Register("statusbar", "TukTex", [[Interface\Addons\Skada\Media\Statusbar\TukTex]])
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

	self.db = LibStub("AceDB-3.0"):New("SkadaDB", self.defaults, "Default")

	if type(SkadaCharDB) ~= "table" then
		SkadaCharDB = {}
	end
	self.char = SkadaCharDB
	self.char.sets = self.char.sets or {}

	-- Profiles
	local AceDBOptions = LibStub("AceDBOptions-3.0", true)
	if AceDBOptions then
		self.options.args.profiles.args.general = AceDBOptions:GetOptionsTable(self.db)
		self.options.args.profiles.args.general.name = L["General"]
		self.options.args.profiles.args.general.order = 0

		-- import/export profile if found.
		if self.AdvancedProfile then
			self:AdvancedProfile(self.options.args.profiles.args)
		end
	end

	LibStub("AceConfig-3.0"):RegisterOptionsTable("Skada", self.options)
	self.optionsFrame = ACD:AddToBlizOptions("Skada", "Skada")
	ACD:SetDefaultSize("Skada", 615, 500)

	-- Slash Command Handler
	SLASH_SKADA1 = "/skada"
	SlashCmdList.SKADA = SlashCommandHandler

	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadSettings")
	self.db.RegisterCallback(self, "OnDatabaseShutdown", "ClearAllIndexes")

	-- spell school colors
	self.schoolcolors = {
		[1] = {a = 1.00, r = 1.00, g = 1.00, b = 0.00}, -- Physical
		[2] = {a = 1.00, r = 1.00, g = 0.90, b = 0.50}, -- Holy
		[4] = {a = 1.00, r = 1.00, g = 0.50, b = 0.00}, -- Fire
		[8] = {a = 1.00, r = 0.30, g = 1.00, b = 0.30}, -- Nature
		[16] = {a = 1.00, r = 0.50, g = 1.00, b = 1.00}, -- Frost
		[20] = {a = 1.00, r = 0.50, g = 1.00, b = 1.00}, -- Frostfire
		[32] = {a = 1.00, r = 0.50, g = 0.50, b = 1.00}, -- Shadow
		[64] = {a = 1.00, r = 1.00, g = 0.50, b = 1.00} -- Arcane
	}

	-- spell school names
	self.schoolnames = {
		[1] = STRING_SCHOOL_PHYSICAL:gsub("%(", ""):gsub("%)", ""),
		[2] = STRING_SCHOOL_HOLY:gsub("%(", ""):gsub("%)", ""),
		[4] = STRING_SCHOOL_FIRE:gsub("%(", ""):gsub("%)", ""),
		[8] = STRING_SCHOOL_NATURE:gsub("%(", ""):gsub("%)", ""),
		[16] = STRING_SCHOOL_FROST:gsub("%(", ""):gsub("%)", ""),
		[20] = STRING_SCHOOL_FROSTFIRE:gsub("%(", ""):gsub("%)", ""),
		[32] = STRING_SCHOOL_SHADOW:gsub("%(", ""):gsub("%)", ""),
		[64] = STRING_SCHOOL_ARCANE:gsub("%(", ""):gsub("%)", "")
	}

	-- valid classes
	self.validclass = {
		DEATHKNIGHT = true,
		DRUID = true,
		HUNTER = true,
		MAGE = true,
		PALADIN = true,
		PRIEST = true,
		ROGUE = true,
		SHAMAN = true,
		WARLOCK = true,
		WARRIOR = true
	}

	-- class names
	self.classnames = {}
	for k, v in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		self.classnames[k] = v
	end
	-- custom
	self.classnames.ENEMY = ENEMY
	self.classnames.MONSTER = EXAMPLE_TARGET_MONSTER
	self.classnames.BOSS = BOSS
	self.classnames.PLAYER = PLAYER
	self.classnames.PET = PET
	self.classnames.UNKNOWN = UNKNOWN
	self.classnames.AGGRO = L["> Pull Aggro <"]

	-- class colors
	self.classcolors = self.GetClassColorsTable()
	-- custom
	self.classcolors.ENEMY = {r = 0.94117, g = 0, b = 0.0196, colorStr = "fff00005"}
	self.classcolors.MONSTER = {r = 0.549, g = 0.388, b = 0.404, colorStr = "ff8c6367"}
	self.classcolors.BOSS = {r = 0.203, g = 0.345, b = 0.525, colorStr = "345886"}
	self.classcolors.PLAYER = {r = 0.94117, g = 0, b = 0.0196, colorStr = "fff00005"}
	self.classcolors.PET = {r = 0.3, g = 0.4, b = 0.5, colorStr = "ff4c0566"}
	self.classcolors.UNKNOWN = {r = 0.2, g = 0.2, b = 0.2, colorStr = "ff333333"}
	self.classcolors.AGGRO = {r = 0.95, g = 0, b = 0.02, colorStr = "fff00005"}
end

function Skada:OnEnable()
	-- well, me!
	self.userGUID, self.userName = UnitGUID("player"), UnitName("player")

	self:ReloadSettings()

	self:RegisterComm("Skada")

	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("RAID_ROSTER_UPDATE")
	self:RegisterEvent("UNIT_PET")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckZone")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatLogEvent")
	self:RegisterEvent("UNIT_ENTERED_VEHICLE", "CheckVehicle")
	self:RegisterEvent("UNIT_EXITED_VEHICLE", "CheckVehicle")

	if self.modulelist then
		for i = 1, #self.modulelist do
			self.modulelist[i](self, L)
		end
		self.modulelist = nil
	end

	After(2, self.ApplySettings)
	After(3, self.CheckMemory)

	if _G.BigWigs then
		self:RegisterMessage("BigWigs_Message", "BigWigs")
		self.bossmod = "BigWigs"
	elseif _G.DBM and _G.DBM.EndCombat then
		self:SecureHook(DBM, "EndCombat", "DBM")
		self.bossmod = "DBM"
	elseif self.bossmod then
		self.bossmod = nil
	end

	After(1, function()
		self:CheckZone()
		self:CheckGroup()
	end)
	if not wasinparty then
		After(2, check_for_join_and_leave)
	end

	version_timer = NewTimer(10, checkVersion)
end

function Skada:BigWigs(_, _, event, message)
	if event == "bosskill" and message and self.current and self.current.gotboss then
		if message:find(self.current.mobname) ~= nil then
			self:Debug("COMBAT_BOSS_DEFEATED: BigWigs")
			self.current.success = true
			self.callbacks:Fire("COMBAT_BOSS_DEFEATED", self.current)
		end
	end
end

function Skada:DBM(_, mod, wipe)
	if not wipe and mod and mod.combatInfo and self.current and self.current.gotboss then
		if mod.combatInfo.name and mod.combatInfo.name:find(self.current.mobname) ~= nil then
			self:Debug("COMBAT_BOSS_DEFEATED: DBM")
			self.current.success = true
			self.callbacks:Fire("COMBAT_BOSS_DEFEATED", self.current)
		end
	end
end

function Skada:CheckMemory()
	if Skada.db.profile.memorycheck then
		UpdateAddOnMemoryUsage()

		local compare = 30 + (Skada.db.profile.setstokeep * 1.25)
		if GetAddOnMemoryUsage("Skada") > (compare * 1024) then
			Skada:Print(L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."])
		end
	end
end

-- this can be used to clear combat log and garbage.
-- note that "collect" isn't used because it blocks all execution for too long.
function Skada:CleanGarbage()
	CombatLogClearEntries()
	if not InCombatLockdown() then
		collectgarbage()
	end
end

-------------------------------------------------------------------------------
-- AddOn Synchronization

do
	local AceSerializer = LibStub("AceSerializer-3.0")
	local LibCompress = LibStub("LibCompress")
	local encodeTable

	function Skada:Serialize(hex, title, ...)
		local result = LibCompress:CompressHuffman(AceSerializer:Serialize(...))
		if hex then
			return self.HexEncode(result, title)
		else
			encodeTable = encodeTable or LibCompress:GetAddonEncodeTable()
			return encodeTable:Encode(result)
		end

	end

	function Skada:Deserialize(data, hex)
		local err
		if hex then
			data, err = self.HexDecode(data)
		else
			encodeTable = encodeTable or LibCompress:GetAddonEncodeTable()
			data, err = encodeTable:Decode(data), "Error decoding"
		end

		if data then
			data, err = LibCompress:DecompressHuffman(data)
			if data then
				return AceSerializer:Deserialize(data)
			end
		end
		return false, err
	end

	function Skada:SendComm(channel, target, ...)
		if target == self.userName then return end

		if not channel then
			local t = GetGroupTypeAndCount()
			if t == nil then
				return -- with whom you want to sync man!
			elseif t == "raid" then
				channel = "RAID"
			elseif t == "party" then
				channel = "PARTY"
			else
				local zoneType = select(2, IsInInstance())
				if zoneType == "pvp" or zoneType == "arena" then
					channel = "BATTLEGROUND"
				end
			end
		end

		if channel == "WHISPER" and not (target and UnitIsConnected(target)) then
			return
		elseif channel then
			self:SendCommMessage("Skada", self:Serialize(false, nil, ...), channel, target)
		end
	end

	local function DispatchComm(sender, ok, commType, ...)
		if ok and type(commType) == "string" then
			local func = "OnComm" .. commType

			if type(Skada[func]) ~= "function" then
				Skada.callbacks:Fire(func, sender, ...)
				return
			end

			Skada[func](Skada, sender, ...)
		end
	end

	function Skada:OnCommReceived(prefix, message, channel, sender)
		if prefix == "Skada" and channel and sender and sender ~= self.userName then
			DispatchComm(sender, self:Deserialize(message))
		end
	end
end

-------------------------------------------------------------------------------

function Skada:PLAYER_REGEN_DISABLED()
	if not disabled and not self.current then
		self:Debug("StartCombat: PLAYER_REGEN_DISABLED")
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
	queuedFixes = delTable(queuedFixes)
	queuedData = delTable(queuedData)
	queuedUnits = delTable(queuedUnits)

	local now = time()
	if not self.db.profile.onlykeepbosses or self.current.gotboss then
		if self.current.mobname ~= nil and now - self.current.starttime > 5 then
			self.current.endtime = self.current.endtime or now
			self.current.time = max(0.1, self.current.endtime - self.current.starttime)
			self.current.started, self.current.stopped = nil, nil

			local setname = self.current.mobname
			if self.db.profile.setnumber then
				local num = 0
				for _, set in self:IterateSets() do
					if set.name == setname and num == 0 then
						num = 1
					else
						local n, c = set.name:match("^(.-)%s*%((%d+)%)$")
						if n == setname then
							num = max(num, tonumber(c) or 0)
						end
					end
				end
				if num > 0 then
					setname = format("%s (%s)", setname, num + 1)
				end
			end
			self.current.name = setname

			for _, mode in self:IterateModes() do
				if mode.SetComplete then
					mode:SetComplete(self.current)
				end
			end

			tinsert(self.char.sets, 1, self.current)
		end
	end

	self.callbacks:Fire("COMBAT_PLAYER_LEAVE", self.current, self.total)
	if self.current.gotboss then
		self.callbacks:Fire("COMBAT_ENCOUNTER_END", self.current, self.total)
	end

	self.last = self.current
	self.total.time = self.total.time + self.current.time
	self.current = nil

	for _, player in ipairs(self.total.players) do
		player.last = nil
	end

	local maxsets, _, numsets = self:GetNumSets()
	if numsets > 0 then
		for i = maxsets, 1, -1 do
			if numsets > self.db.profile.setstokeep and not self.char.sets[i].keep then
				tremove(self.char.sets, i)
				numsets = numsets - 1
			end
		end
	end

	for _, win in self:IterateWindows() do
		win:Wipe()
		self.changed = true

		if win.db.wipemode ~= "" and IsGroupDead() then
			win:RestoreView("current", win.db.wipemode)
		elseif win.db.returnaftercombat and win.restore_mode and win.restore_set then
			if win.restore_set ~= win.selectedset or win.restore_mode ~= win.selectedmode then
				win:RestoreView(win.restore_set, win.restore_mode)
				win.restore_mode, win.restore_set = nil, nil
			end
		end

		if not win.db.hidden and (not self.db.profile.hidesolo or self.IsInGroup()) then
			if self.db.profile.showcombat and win:IsShown() then
				win:Hide()
			elseif self.db.profile.hidecombat and not win:IsShown() then
				win:Show()
			end
		end
	end

	self:UpdateDisplay(true)

	update_timer = CancelTimer(update_timer)
	tick_timer = CancelTimer(tick_timer)
	After(3, Skada.CheckMemory)
end

function Skada:StopSegment(completed)
	if self.current then
		self.current.stopped = true
		self.current.endtime = time()
		self.current.time = max(0.1, self.current.endtime - self.current.starttime)
	end
end

function Skada:ResumeSegment()
	if self.current and self.current.stopped then
		self.current.stopped = nil
		self.current.endtime = nil
		self.current.time = 0
	end
end

do
	local tentative, tentativehandle
	local deathcounter, startingmembers = 0, 0

	function Skada:Tick()
		self.callbacks:Fire("COMBAT_PLAYER_TICK", self.current, self.total)
		if not disabled and self.current and not InCombatLockdown() and not IsGroupInCombat() then
			self:Debug("EndSegment: Tick")
			self:EndSegment()
		end
	end

	function Skada:StartCombat()
		deathcounter = 0
		startingmembers = GetNumGroupMembers()
		tentativehandle = CancelTimer(tentativehandle)

		if update_timer then
			self:Debug("EndSegment: StartCombat")
			self:EndSegment()
		end

		self:Wipe()

		local starttime = time()

		if not self.current then
			self.current = self:CreateSet(L["Current"], starttime)
		end

		if self.total == nil then
			self.total = self:CreateSet(L["Total"], starttime)
			self.char.total = self.total
		end

		for _, win in self:IterateWindows() do
			if win.db.modeincombat ~= "" then
				local mymode = self:find_mode(win.db.modeincombat)

				if mymode ~= nil then
					if win.db.returnaftercombat then
						if win.selectedset then
							win.restore_set = win.selectedset
						end
						if win.selectedmode then
							win.restore_mode = win.selectedmode:GetName()
						end
					end

					win.selectedset = "current"
					win:DisplayMode(mymode)
				end
			end

			if not win.db.hidden then
				if self.db.profile.showcombat and not win:IsShown() then
					win:Show()
				elseif self.db.profile.hidecombat and win:IsShown() then
					win:Hide()
				end
			end
		end

		self:UpdateDisplay(true)

		update_timer = NewTicker(self.db.profile.updatefrequency or 0.25, function() self:UpdateDisplay() end)
		tick_timer = NewTicker(1, function() self:Tick() end)
	end

	-- list of combat events that we don't care about
	local ignoredevents = {
		["SPELL_AURA_REMOVED_DOSE"] = true,
		["SPELL_CAST_START"] = true,
		["SPELL_CAST_FAILED"] = true,
		["SPELL_DRAIN"] = true,
		["PARTY_KILL"] = true,
		["SPELL_PERIODIC_DRAIN"] = true,
		["SPELL_DISPEL_FAILED"] = true,
		["SPELL_DURABILITY_DAMAGE"] = true,
		["SPELL_DURABILITY_DAMAGE_ALL"] = true,
		["ENCHANT_APPLIED"] = true,
		["ENCHANT_REMOVED"] = true,
		["SPELL_CREATE"] = true,
		["SPELL_BUILDING_DAMAGE"] = true
	}

	-- events used to trigger combat for aggressive combat detection
	local triggerevents = {
		["RANGE_DAMAGE"] = true,
		["SPELL_BUILDING_DAMAGE"] = true,
		["SPELL_DAMAGE"] = true,
		["SPELL_PERIODIC_DAMAGE"] = true,
		["SWING_DAMAGE"] = true
	}

	local combatlogevents = {}

	function Skada:RegisterForCL(func, event, flags)
		combatlogevents[event] = combatlogevents[event] or {}
		tinsert(combatlogevents[event], {["func"] = func, ["flags"] = flags})
	end

	function Skada:CombatLogEvent(_, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if ignoredevents[eventtype] then return end

		local src_is_interesting = nil
		local dst_is_interesting = nil
		local now = time()

		if not self.current and self.db.profile.tentativecombatstart and triggerevents[eventtype] and srcName and dstName and srcGUID ~= dstGUID then
			src_is_interesting = band(srcFlags, BITMASK_GROUP) ~= 0 or (band(srcFlags, BITMASK_PETS) ~= 0 and pets[srcGUID]) or players[srcGUID]

			if eventtype ~= "SPELL_PERIODIC_DAMAGE" then
				dst_is_interesting = band(dstFlags, BITMASK_GROUP) ~= 0 or (band(dstFlags, BITMASK_PETS) ~= 0 and pets[dstGUID]) or players[dstGUID]
			end

			if src_is_interesting or dst_is_interesting then
				self.current = self:CreateSet(L["Current"], now)
				if not self.total then
					self.total = self:CreateSet(L["Total"], now)
				end

				tentativehandle = NewTimer(self.db.profile.tentativetimer or 3, function()
					tentative = nil
					tentativehandle = nil
					self.current = nil
				end)
				tentative = 0
			end
		end

		if self.current and not self.current.started then
			self.callbacks:Fire("COMBAT_PLAYER_ENTER", self.current, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
			self.current.started = true
			if self.instanceType == nil then self:CheckZone() end
			self.current.type = self.instanceType or "unknown"
		end

		if self.current and self.db.profile.autostop then
			if eventtype == "UNIT_DIED" and ((band(srcFlags, BITMASK_GROUP) ~= 0 and band(srcFlags, BITMASK_PETS) == 0) or players[srcGUID]) then
				deathcounter = deathcounter + 1
				-- If we reached the treshold for stopping the segment, do so.
				if deathcounter > 0 and deathcounter / startingmembers >= 0.5 and not self.current.stopped then
					self.callbacks:Fire("COMBAT_PLAYER_WIPE", self.current)
					self:Print(L["Stopping for wipe."])
					self:StopSegment()
				end
			elseif eventtype == "SPELL_RESURRECT" and ((band(srcFlags, BITMASK_GROUP) ~= 0 and band(srcFlags, BITMASK_PETS) == 0) or players[srcGUID]) then
				deathcounter = deathcounter - 1
			end
		end

		if self.current and combatlogevents[eventtype] then
			if self.current.stopped then return end

			for _, mod in ipairs(combatlogevents[eventtype]) do
				local fail = false

				if mod.flags.src_is_interesting_nopets then
					local src_is_interesting_nopets = (band(srcFlags, BITMASK_GROUP) ~= 0 and band(srcFlags, BITMASK_PETS) == 0) or players[srcGUID]

					if src_is_interesting_nopets then
						src_is_interesting = true
					else
						fail = true
					end
				end

				if not fail and mod.flags.dst_is_interesting_nopets then
					local dst_is_interesting_nopets = (band(dstFlags, BITMASK_GROUP) ~= 0 and band(dstFlags, BITMASK_PETS) == 0) or players[dstGUID]
					if dst_is_interesting_nopets then
						dst_is_interesting = true
					else
						fail = true
					end
				end

				if not fail and mod.flags.src_is_interesting or mod.flags.src_is_not_interesting then
					if not src_is_interesting then
						src_is_interesting = band(srcFlags, BITMASK_GROUP) ~= 0 or (band(srcFlags, BITMASK_PETS) ~= 0 and pets[srcGUID]) or players[srcGUID] or self:IsQueuedUnit(srcGUID)
					end

					if (mod.flags.src_is_interesting and not src_is_interesting) or (mod.flags.src_is_not_interesting and src_is_interesting) then
						fail = true
					end
				end

				if not fail and mod.flags.dst_is_interesting or mod.flags.dst_is_not_interesting then
					if not dst_is_interesting then
						dst_is_interesting = band(dstFlags, BITMASK_GROUP) ~= 0 or (band(dstFlags, BITMASK_PETS) ~= 0 and pets[dstGUID]) or players[dstGUID]
					end

					if (mod.flags.dst_is_interesting and not dst_is_interesting) or (mod.flags.dst_is_not_interesting and dst_is_interesting) then
						fail = true
					end
				end

				if not fail then
					mod.func(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)

					if tentative ~= nil then
						tentative = tentative + 1
						if tentative == 5 then
							tentativehandle = CancelTimer(tentativehandle)
							self:Debug("StartCombat: tentative combat")
							self:StartCombat()
						end
					end
				end
			end
		end

		if self.current and src_is_interesting and not self.current.gotboss then
			if band(dstFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then
				local isboss, bossid, bossname = self:IsBoss(dstGUID)
				if not self.current.gotboss and isboss then
					self.current.mobname = bossname or dstName
					self.current.gotboss = bossid or true
					if self.db.profile.alwayskeepbosses then
						self.current.keep = true
					end
					self.callbacks:Fire("COMBAT_ENCOUNTER_START", self.current)
				elseif not self.current.mobname then
					self.current.mobname = dstName
				end
			end
		end

		if eventtype == "SPELL_SUMMON" and (band(srcFlags, BITMASK_GROUP) ~= 0 or band(srcFlags, BITMASK_PETS) ~= 0 or (band(dstFlags, BITMASK_PETS) ~= 0 and pets[dstGUID])) then
			-- we assign the pet the normal way
			self:AssignPet(srcGUID, srcName, dstGUID)

			-- we fix the table by searching through the complete list
			local fixed = true
			while fixed do
				fixed = false
				for pet, owner in pairs(pets) do
					if pets[owner.id] then
						pets[pet] = {id = pets[owner.id].id, name = pets[owner.id].name}
						fixed = true
					end
				end
			end
		end

		if self.current and self.current.gotboss and (eventtype == "UNIT_DIED" or eventtype == "UNIT_DESTROYED") then
			if dstName and self.current.mobname == dstName then
				local set = self.current -- catch it before it goes away
				After(self.db.profile.updatefrequency or 0.25, function()
					if set and set.success == nil then
						set.success = true
						self.callbacks:Fire("COMBAT_BOSS_DEFEATED", set)
					end
				end)
			end
		end
	end
end