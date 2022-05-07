local Skada = LibStub("AceAddon-3.0"):NewAddon("Skada", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0", "AceConsole-3.0", "AceComm-3.0", "LibCompat-1.0-Skada")
_G.Skada = Skada

Skada.callbacks = Skada.callbacks or LibStub("CallbackHandler-1.0"):New(Skada)

local GetAddOnMetadata = GetAddOnMetadata
Skada.version = GetAddOnMetadata("Skada", "Version")
Skada.website = GetAddOnMetadata("Skada", "X-Website")
Skada.discord = GetAddOnMetadata("Skada", "X-Discord")
Skada.logo = [[Interface\Icons\Spell_Lightning_LightningBolt01]]

local L = LibStub("AceLocale-3.0"):GetLocale("Skada")
local ACD = LibStub("AceConfigDialog-3.0")
local ACR = LibStub("AceConfigRegistry-3.0")
local DBI = LibStub("LibDBIcon-1.0", true)
local LDS = LibStub("LibDualSpec-1.0", true)
local Translit = LibStub("LibTranslit-1.0", true)

-- cache frequently used globlas
local tsort, tinsert, tremove, tmaxn, wipe, setmetatable = table.sort, table.insert, table.remove, table.maxn, wipe, setmetatable
local next, pairs, ipairs, type = next, pairs, ipairs, type
local tonumber, tostring, strmatch, format, gsub, lower, find = tonumber, tostring, strmatch, string.format, string.gsub, string.lower, string.find
local floor, max, min, band, time, GetTime = math.floor, math.max, math.min, bit.band, time, GetTime
local IsInInstance, GetInstanceInfo, GetBattlefieldArenaFaction = IsInInstance, GetInstanceInfo, GetBattlefieldArenaFaction
local InCombatLockdown, IsGroupInCombat = InCombatLockdown, Skada.IsGroupInCombat
local UnitExists, UnitGUID, UnitName, UnitClass, UnitIsConnected = UnitExists, UnitGUID, UnitName, UnitClass, UnitIsConnected
local ReloadUI, GetScreenWidth = ReloadUI, GetScreenWidth
local GetSpellInfo, GetSpellLink = GetSpellInfo, GetSpellLink
local CloseDropDownMenus = CloseDropDownMenus
local IsInGroup, IsInRaid, IsInPvP = Skada.IsInGroup, Skada.IsInRaid, Skada.IsInPvP
local GetNumGroupMembers, GetGroupTypeAndCount = Skada.GetNumGroupMembers, Skada.GetGroupTypeAndCount
local GetUnitIdFromGUID, GetUnitSpec, GetUnitRole = Skada.GetUnitIdFromGUID, Skada.GetUnitSpec, Skada.GetUnitRole
local UnitIterator, IsGroupDead = Skada.UnitIterator, Skada.IsGroupDead
local EscapeStr, GetCreatureId, T = Skada.EscapeStr, Skada.GetCreatureId, Skada.Table

local LDB = LibStub("LibDataBroker-1.1")
local dataobj = LDB:NewDataObject("Skada", {
	label = "Skada",
	type = "data source",
	icon = Skada.logo,
	text = "n/a"
})

-- Keybindings
BINDING_HEADER_SKADA = "Skada"
BINDING_NAME_SKADA_TOGGLE = L["Toggle Windows"]
BINDING_NAME_SKADA_SHOWHIDE = L["Show/Hide Windows"]
BINDING_NAME_SKADA_RESET = L.Reset
BINDING_NAME_SKADA_NEWSEGMENT = L["Start New Segment"]
BINDING_NAME_SKADA_NEWPHASE = L["Start New Phase"]
BINDING_NAME_SKADA_STOP = L.Stop

-- Skada-Revisited flag
Skada.revisited = true

-- things we need
Skada.userName = UnitName("player")
Skada.userClass = select(2, UnitClass("player"))

-- available display types
Skada.displays = {}
local displays = Skada.displays

-- flag to check if disabled
local disabled = false

-- update & tick timers
local update_timer, tick_timer, toggle_timer, version_timer
local CheckVersion, ConvertVersion
local CheckForJoinAndLeave

-- list of players, pets and vehicles
local players, pets, vehicles = {}, {}, {}

-- format funtions.
local SetNumeralFormat, SetValueFormat

-- list of feeds & selected feed
local feeds, selected_feed = {}, nil

-- lists of modules and windows
local modes, windows = {}, {}

-- flags for party, instance and ovo
local was_in_party = nil

-- secret flags
local _bound_sets = nil

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
local COMBATLOG_OBJECT_TYPE_PET = COMBATLOG_OBJECT_TYPE_PET or 0x00001000
local COMBATLOG_OBJECT_TYPE_GUARDIAN = COMBATLOG_OBJECT_TYPE_GUARDIAN or 0x00002000

local BITMASK_GROUP = COMBATLOG_OBJECT_AFFILIATION_MINE + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_RAID
local BITMASK_PETS = COMBATLOG_OBJECT_TYPE_PET + COMBATLOG_OBJECT_TYPE_GUARDIAN
local BITMASK_OWNERS = COMBATLOG_OBJECT_AFFILIATION_MASK + COMBATLOG_OBJECT_REACTION_MASK + COMBATLOG_OBJECT_CONTROL_MASK
local BITMASK_ENEMY = COMBATLOG_OBJECT_REACTION_NEUTRAL + COMBATLOG_OBJECT_REACTION_HOSTILE

-- to allow external usage
Skada.BITMASK_GROUP = BITMASK_GROUP
Skada.BITMASK_PETS = BITMASK_PETS
Skada.BITMASK_OWNERS = BITMASK_OWNERS
Skada.BITMASK_ENEMY = BITMASK_ENEMY

-------------------------------------------------------------------------------
-- local functions.

Skada.newTable, Skada.delTable = Skada.TablePool("kv")
local new, del = Skada.newTable, Skada.delTable

-- verifies a set
local function VerifySet(mode, set)
	if not mode or not set then return end

	if mode.AddSetAttributes then
		mode:AddSetAttributes(set)
	end

	if mode.AddPlayerAttributes and set.players then
		for i = 1, #set.players do
			mode:AddPlayerAttributes(set.players[i], set)
		end
	end

	if mode.AddEnemyAttributes and set.enemies then
		for i = 1, #set.enemies do
			mode:AddEnemyAttributes(set.enemies[i], set)
		end
	end
end

-- creates a new set
-- @param 	setname 	the segment name
-- @param 	set 		the set to override/reuse
local function CreateSet(setname, set)
	if set then
		Skada:Debug("CreateSet: Reuse", set.name, setname)
		setmetatable(set, nil)
		for k, v in pairs(set) do
			if type(v) == "table" then
				set[k] = wipe(v)
			else
				set[k] = nil
			end
		end
	else
		Skada:Debug("CreateSet: New", setname)
		set = {}
	end

	-- add stuff.
	set.name = setname
	set.starttime = time()
	set.time = 0
	set.players = set.players or {}

	-- only for current segment
	if setname ~= L["Total"] then
		set.last_action = set.last_action or set.starttime
		set.enemies = set.enemies or {}
	end

	-- last alterations before returning.
	for i = 1, #modes do
		VerifySet(modes[i], set)
	end

	Skada.callbacks:Fire("Skada_SetCreated", set)
	return Skada.setPrototype:Bind(set)
end

-- prepares the given set name.
local function CheckSetName(set)
	local setname = set.mobname or L.Unknown

	if set.phase then
		setname = format(L["%s - Phase %s"], setname, set.phase)
		set.phase = nil
	end

	if Skada.db.profile.setnumber then
		local num = 0
		for i = 1, #Skada.char.sets do
			local s = Skada.char.sets[i]
			if s and s.name == setname and num == 0 then
				num = 1
			elseif s then
				local n, c = strmatch(s.name, "^(.-)%s*%((%d+)%)$")
				if n == setname then
					num = max(num, tonumber(c) or 0)
				end
			end
		end
		if num > 0 then
			setname = format("%s (%s)", setname, num + 1)
		end
	end

	set.name = setname
	return setname -- return reference.
end

-- process the given set and stores into sv.
local function ProcessSet(set, curtime, mobname)
	if not set then return end
	_bound_sets = nil -- to refresh mt

	curtime = curtime or time()

	-- remove any additional keys.
	set.started, set.stopped = nil, nil

	-- trigger events.
	Skada:SendMessage("COMBAT_PLAYER_LEAVE", set, curtime)
	if set.gotboss then
		Skada:SendMessage("COMBAT_ENCOUNTER_END", set, curtime)
	end

	if not Skada.db.profile.onlykeepbosses or set.gotboss then
		set.mobname = mobname or set.mobname -- override name
		if set.mobname ~= nil and curtime - set.starttime >= (Skada.db.profile.minsetlength or 5) then
			set.endtime = set.endtime or curtime
			set.time = max(0.1, set.endtime - set.starttime)
			set.name = CheckSetName(set)

			for i = 1, #modes do
				local mode = modes[i]
				if mode and mode.SetComplete then
					mode:SetComplete(set)
				end
			end

			-- do you want to do something?
			Skada.callbacks:Fire("Skada_SetCompleted", set)

			tinsert(Skada.char.sets, 1, set)
			Skada:Debug("Segment Saved:", set.name)
		end
	end

	-- the segment didn't have the chance to get saved
	if set.endtime == nil then
		set.endtime = curtime
		set.time = max(0.1, set.endtime - set.starttime)
	end
end

local function CleanSets(force)
	local maxsets, numsets = 0, 0
	for i = 1, #Skada.char.sets do
		local set = Skada.char.sets[i]
		if set then
			maxsets = maxsets + 1
			if not set.keep then
				numsets = numsets + 1
			end
		end
	end

	-- we trim segments without touching persistent ones.
	for i = #Skada.char.sets, 1, -1 do
		if (force or numsets > Skada.db.profile.setstokeep) and not Skada.char.sets[i].keep then
			tremove(Skada.char.sets, i)
			numsets = numsets - 1
			maxsets = maxsets - 1
		end
	end

	-- because some players may enable the "always keep boss fights" option,
	-- the amount of segments kept can grow big, so we make sure to keep
	-- the player reasonable, otherwise they'll encounter memory issues.
	local limit = Skada.db.profile.setstokeep + (Skada.db.profile.setslimit or 10)
	while maxsets > limit and Skada.char.sets[maxsets] do
		tremove(Skada.char.sets, maxsets)
		maxsets = maxsets - 1
	end
end

-- finds a mode
local function FindMode(name)
	for i = 1, #modes do
		local mode = modes[i]
		if mode and mode.moduleName == name then
			return mode
		end
	end
end

-- called on boss defeat
local function BossDefeated()
	if Skada.current and not Skada.current.success then
		Skada.current.success = true
		Skada:SendMessage("COMBAT_BOSS_DEFEATED", Skada.current)

		if Skada.tempsets then
			for i = 1, #Skada.tempsets do
				local set = Skada.tempsets[i]
				if set and not set.success then
					set.success = true
					Skada:SendMessage("COMBAT_BOSS_DEFEATED", set)
				end
			end
		end
	end
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
function Skada:GetActiveTime(set, player, active)
	if (self.db.profile.timemesure ~= 2 or active) and player and (player.time or 0) > 0 then
		return max(0.1, player.time)
	end
	return self:GetSetTime(set)
end

-- updates the player's active time
function Skada:AddActiveTime(player, cond, diff)
	if player and player.last and cond then
		local curtime = GetTime()
		local delta = curtime - player.last

		if (diff or 0) > 0 and delta > diff then
			delta = diff
		elseif delta > 3.5 then
			delta = 3.5
		end

		player.last = curtime
		player.time = (player.time or 0) + floor(100 * delta + 0.5) / 100
	end
end

-------------------------------------------------------------------------------
-- popup dialogs

-- skada reset dialog
do
	local t = {timeout = 30, whileDead = 0}
	local f = function() Skada:Reset(IsShiftKeyDown()) end

	function Skada:ShowPopup(win, popup)
		if Skada.testMode then return end

		if Skada.db.profile.skippopup and not popup then
			Skada:Reset(IsShiftKeyDown())
			return
		end

		Skada:ConfirmDialog(L["Do you want to reset Skada?\nHold SHIFT to reset all data."], f, t)
	end
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

-- reinstall the addon
do
	local t = {timeout = 15, whileDead = 0}
	local f = function()
		if SkadaDB.profiles then
			wipe(SkadaDB.profiles)
		end
		if SkadaDB.profileKeys then
			wipe(SkadaDB.profileKeys)
		end
		ReloadUI()
	end

	function Skada:Reinstall()
		Skada:ConfirmDialog(L["Are you sure you want to reinstall Skada?"], f, t)
	end
end

-------------------------------------------------------------------------------
-- Windo functions

local Window = {}
do
	local window_mt = {__index = Window}
	local copywindow = nil

	-- create a new window
	function Window:New(ttwin)
		local win = {}

		win.dataset = {}
		if not ttwin then -- regular window?
			win.metadata = {}
			win.history = {}
		end

		return setmetatable(win, window_mt)
	end

	-- creates or reuses a dataset table
	function Window:nr(i)
		local d = self.dataset[i] or {}
		self.dataset[i] = d
		return d
	end

	-- add window options
	function Window:AddOptions()
		local templist = {}

		local options = {
			type = "group",
			name = function() return self.db.name end,
			desc = function() return format(L["Options for %s."], self.db.name) end,
			get = function(i) return self.db[i[#i]] end,
			set = function(i, val)
				self.db[i[#i]] = val
				Skada:ApplySettings(self.db.name)
			end,
			args = {
				name = {
					type = "input",
					name = L["Rename Window"],
					desc = L["Enter the name for the window."],
					order = 1,
					width = "double",
					set = function(_, val)
						val = val:trim()
						if val ~= self.db.name and val ~= "" then
							local oldname = self.db.name

							-- avoid duplicate names
							local num = 0
							for i = 1, #windows do
								local win = windows[i]
								if win and win.db and win.db.name == val and num == 0 then
									num = 1
								elseif win and win.db then
									local n, c = strmatch(win.db.name, "^(.-)%s*%((%d+)%)$")
									if n == val then
										num = max(num, tonumber(c) or 0)
									end
								end
							end
							if num > 0 then
								val = format("%s (%s)", val, num + 1)
							end

							self.db.name = val
							Skada.options.args.windows.args[val] = Skada.options.args.windows.args[oldname]
							Skada.options.args.windows.args[oldname] = nil
							Skada:ApplySettings(self.db.name)
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
						local list = wipe(templist)
						for name, display in pairs(displays) do
							list[name] = display.name
						end
						return list
					end,
					set = function(_, display)
						self.db.display = display
						Skada:ReloadSettings(self)
					end
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
					hidden = true,
					values = function()
						local list = {[""] = L.None}
						for i = 1, #windows do
							local win = windows[i]
							if win and win.db and win.db.name ~= self.db.name and win.db.display == self.db.display then
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
					hidden = true,
					disabled = function()
						return (copywindow == nil)
					end,
					func = function()
						wipe(templist)
						if copywindow then
							for i = 1, #windows do
								local win = windows[i]
								if win and win.db and win.db.name == copywindow and win.db.display == self.db.display then
									Skada.tCopy(templist, win.db, "name", "sticked", "x", "y", "point", "snapped", "child", "childmode")
									break
								end
							end
						end
						for k, v in pairs(templist) do
							self.db[k] = v
						end
						wipe(templist)
						Skada:ApplySettings(self.db.name)
						copywindow = nil
					end
				},
				separator2 = {
					type = "description",
					name = " ",
					order = 98,
					hidden = true,
					width = "full"
				},
				delete = {
					type = "execute",
					name = L["Delete Window"],
					desc = L["Choose the window to be deleted."],
					order = 998,
					width = "double",
					confirm = function() return L["Are you sure you want to delete this window?"] end,
					func = function() Skada:DeleteWindow(self.db.name, true) end
				},
				testmode = {
					type = "execute",
					name = L["Test Mode"],
					desc = L["Creates fake data to help you configure your windows."],
					order = 999,
					hidden = true,
					disabled = function() return (InCombatLockdown() or IsGroupInCombat()) end,
					func = function() Skada:TestMode() end
				}
			}
		}

		if self.display and self.display.AddDisplayOptions then
			options.args.copywin.hidden = nil
			options.args.copyexec.hidden = nil
			options.args.separator2.hidden = nil
			options.args.delete.width = nil
			options.args.testmode.hidden = nil

			self.display:AddDisplayOptions(self, options.args)
		else
			options.name = function()
				return format("|cffff0000%s|r - %s", self.db.name, ERROR_CAPS)
			end
			options.args.display.name = format("%s - |cffff0000%s|r", L["Display System"], ERROR_CAPS)
		end

		Skada.options.args.windows.args[self.db.name] = options
	end

	-- fires a callback event
	function Window:Fire(event, ...)
		if self.bargroup and self.bargroup.callbacks then
			self.bargroup.callbacks:Fire(event, self, ...)
		elseif self.frame and self.frame.callbacks then
			self.frame.callbacks:Fire(event, self, ...)
		end
	end
end

-- sets the selected window as a child to the current window
function Window:SetChild(win)
	if not win then
		return
	elseif type(win) == "table" then
		self.child = win
	elseif type(win) == "string" and win:trim() ~= "" then
		for i = 1, #windows do
			local w = windows[i]
			if w and w.db and w.db.name == win then
				self.child = w
				return
			end
		end
	end
end

-- destroy a window
function Window:Destroy()
	self.dataset = nil
	if self.display then
		self.display:Destroy(self)
	end

	local name = self.db.name or Skada.windowdefaults.name
	Skada.options.args.windows.args[name] = nil
end

-- change window display
function Window:SetDisplay(name)
	if name ~= self.db.display or self.display == nil then
		if self.display then
			self.display:Destroy(self)
		end

		self.db.display = name
		self.display = displays[self.db.display]
		self:AddOptions()
	end
end

-- tell window to update the display of its dataset, using its display provider.
function Window:UpdateDisplay()
	if not self.metadata.maxvalue then
		self.metadata.maxvalue = 0
		if self.dataset then
			for i = 1, #self.dataset do
				local data = self.dataset[i]
				if data and data.id and data.value > self.metadata.maxvalue then
					self.metadata.maxvalue = data.value
				end
			end
		end
	end

	self.display:Update(self)
	self:set_mode_title()
end

-- called before dataset is updated.
function Window:UpdateInProgress()
	for i = 1, #self.dataset do
		local data = self.dataset[i]
		if data then
			if data.ignore then
				data.icon = nil
			end
			data.id = nil
			data.ignore = nil
		end
	end
end

function Window:Show()
	self.display:Show(self)
end

function Window:Hide()
	self.display:Hide(self)
end

-- toggles window visibility
function Window:Toggle()
	if
		Skada.db.profile.hidden or
		self.db.hidden or
		((Skada.db.profile.hidesolo or self.db.hideauto == 4) and not IsInGroup()) or
		((Skada.db.profile.hidepvp or self.db.hideauto == 7) and IsInPvP()) or
		((Skada.db.profile.showcombat or self.db.hideauto == 3) and not IsGroupInCombat()) or
		((Skada.db.profile.hidecombat or self.db.hideauto == 2) and IsGroupInCombat()) or
		(self.db.hideauto == 5 and (Skada.instanceType == "raid" or Skada.instanceType == "party")) or
		(self.db.hideauto == 6 and Skada.instanceType ~= "raid" and Skada.instanceType ~= "party")
	then
		self.display:Hide(self)
	else
		self.display:Show(self)
	end
end

function Window:IsShown()
	return self.display:IsShown(self)
end

function Window:Reset()
	if self.dataset then
		for i = 1, #self.dataset do
			wipe(self.dataset[i])
		end
	end
end

function Window:Wipe()
	self:Reset()
	if self.display then
		self.display:Wipe(self)
	end

	if self.child and self.db.childmode == 1 then
		self.child:Wipe()
	end
end

function Window:GetSelectedSet()
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

	if set and self.selectedset ~= set then
		self.selectedset = set
		self:RestoreView()
		if self.child and (self.db.childmode == 1 or self.db.childmode == 2) then
			self.child:set_selected_set(set)
		end
	end
end

function Window:DisplayMode(mode, class)
	if type(mode) ~= "table" then return end

	-- remove filter for the same mode
	if class and not self.class then
		self.class = class
	elseif not class and self.class and self.selectedmode == mode then
		self.class = nil
	end

	self:Wipe()

	self.selectedset = self.selectedset or "current"
	self.selectedmode = mode
	wipe(self.metadata)

	if mode and self.parentmode ~= mode and Skada:GetModule(mode.moduleName, true) then
		self.parentmode = mode
	end

	if mode.metadata then
		for key, value in pairs(mode.metadata) do
			self.metadata[key] = value
		end
	end

	self.changed = true
	self:set_mode_title()

	if self.child and (self.db.childmode == 1 or self.db.childmode == 3) then
		self.child:DisplayMode(mode)
	end

	Skada:UpdateDisplay()
end

do
	local function ClickOnMode(win, id, _, button)
		if button == "LeftButton" then
			local mode = FindMode(id)
			if mode then
				if Skada.db.profile.sortmodesbyusage then
					Skada.db.profile.modeclicks = Skada.db.profile.modeclicks or {}
					Skada.db.profile.modeclicks[id] = (Skada.db.profile.modeclicks[id] or 0) + 1
					Skada:SortModes()
				end
				win:DisplayMode(mode)
			end
		elseif button == "RightButton" then
			win:RightClick()
		end
	end

	local function sortFunc(a, b)
		if Skada.db.profile.sortmodesbyusage and Skada.db.profile.modeclicks then
			return (Skada.db.profile.modeclicks[a.moduleName] or 0) > (Skada.db.profile.modeclicks[b.moduleName] or 0)
		else
			return a.moduleName < b.moduleName
		end
	end

	function Skada:SortModes()
		tsort(modes, sortFunc)
	end

	function Window:DisplayModes(settime)
		wipe(self.metadata)
		wipe(self.history)
		self:Wipe()

		self.selectedmode = nil
		self.metadata.title = L["Skada: Modes"]

		self.db.set = settime

		if settime == "current" or settime == "total" then
			self.selectedset = settime
		else
			for i = 1, #Skada.char.sets do
				local set = Skada.char.sets[i]
				if set and tostring(set.starttime) == settime then
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

		self.metadata.click = ClickOnMode
		self.metadata.maxvalue = 1
		self.metadata.sortfunc = function(a, b) return a.name < b.name end

		self.changed = true
		self.display:SetTitle(self, self.metadata.title)

		if self.child and (self.db.childmode == 1 or self.db.childmode == 3) then
			self.child:DisplayModes(settime)
		end

		Skada:UpdateDisplay()
	end
end

do
	local function ClickOnSet(win, id, _, button)
		if button == "LeftButton" then
			win:DisplayModes(id)
		elseif button == "RightButton" then
			win:RightClick()
		end
	end

	function Window:DisplaySets()
		wipe(self.metadata)
		wipe(self.history)
		self:Wipe()

		self.selectedmode = nil
		self.selectedset = nil

		self.metadata.title = L["Skada: Fights"]
		self.display:SetTitle(self, self.metadata.title)

		self.metadata.click = ClickOnSet
		self.metadata.maxvalue = 1
		self.changed = true

		if self.child and (self.db.childmode == 1 or self.db.childmode == 2) then
			self.child:DisplaySets()
		end

		Skada:UpdateDisplay()
	end
end

function Window:RightClick(bar, button)
	if self.selectedmode then
		if #self.history > 0 then
			self:DisplayMode(tremove(self.history))
		elseif self.class then
			Skada:FilterClass(self)
		else
			self.class = nil
			self:DisplayModes(self.selectedset)
		end
	elseif self.selectedset then
		self.class = nil
		self:DisplaySets()
	end
	CloseDropDownMenus() -- always close
end

-------------------------------------------------------------------------------
-- windows and misc

function Skada:CreateWindow(name, db, display)
	name = name and name:trim() or "Skada"
	if not name or name == "" then
		name = "Skada" -- default
	else
		name = gsub(name, "^%l", strupper, 1)
	end

	local isnew = false
	if not db then
		db, isnew = {}, true
		self.tCopy(db, Skada.windowdefaults)
		self.db.profile.windows[#self.db.profile.windows + 1] = db
	end

	if display then
		db.display = display
	end

	db.barmax = db.barmax or self.windowdefaults.barmax
	db.barbgcolor = db.barbgcolor or self.windowdefaults.barbgcolor
	db.buttons = db.buttons or self.windowdefaults.buttons
	db.scale = db.scale or self.windowdefaults.scale or 1

	-- child window mode
	db.tooltippos = db.tooltippos or self.windowdefaults.tooltippos or "NONE"

	local window = Window:New()
	window.db = db

	-- avoid duplicate names
	do
		local num = 0
		for i = 1, #windows do
			local win = windows[i]
			if win and win.db and win.db.name == name and num == 0 then
				num = 1
			elseif win and win.db then
				local n, c = strmatch(win.db.name, "^(.-)%s*%((%d+)%)$")
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

	window:SetDisplay(window.db.display or "bar")
	if window.db.display and displays[window.db.display] then
		window.display:Create(window)
		windows[#windows + 1] = window
		window:DisplaySets()

		if isnew and FindMode(L["Damage"]) then
			self:RestoreView(window, "current", L["Damage"])
		elseif window.db.set or window.db.mode then
			self:RestoreView(window, window.db.set, window.db.mode)
		end
	else
		self:Printf("Window \"|cffffbb00%s|r\" was not loaded because its display module, \"|cff00ff00%s|r\" was not found.", name, window.db.display or L.Unknown)
	end

	ACR:NotifyChange("Skada")
	self:ApplySettings()
	return window
end

-- window deletion
do
	local function DeleteWindow(name)
		for i = 1, #windows do
			local win = windows[i]
			if win and win.db and win.db.name == name then
				win:Destroy()
				tremove(windows, i)
			elseif win and win.db and win.db.child == name then
				win.db.child, win.db.childmode, win.child = nil, nil, nil
			end
		end

		for i = 1, #Skada.db.profile.windows do
			local win = Skada.db.profile.windows[i]
			if win and win.name == name then
				tremove(Skada.db.profile.windows, i)
			elseif win and win.sticked and win.sticked[name] then
				win.sticked[name] = nil
			end
		end

		-- clean garbage afterwards
		Skada:CleanGarbage()
	end

	function Skada:DeleteWindow(name, internal)
		if internal then
			return DeleteWindow(name)
		end

		if not StaticPopupDialogs["SkadaDeleteWindowDialog"] then
			StaticPopupDialogs["SkadaDeleteWindowDialog"] = {
				text = L["Are you sure you want to delete this window?"],
				button1 = L.Yes,
				button2 = L.No,
				timeout = 30,
				whileDead = 0,
				hideOnEscape = 1,
				OnAccept = function(self, data)
					CloseDropDownMenus()
					ACR:NotifyChange("Skada")
					return DeleteWindow(data)
				end
			}
		end
		StaticPopup_Show("SkadaDeleteWindowDialog", nil, nil, name)
	end
end

-- toggles windows visiblity
function Skada:Toggle()
	for i = 1, #windows do
		local win = windows[i]
		if win then
			win:Toggle()
		end
	end
end

-- toggles windows visibility
function Skada:ToggleWindow()
	if self.db.profile.hidden then
		self.db.profile.hidden = false
		self:ApplySettings()
	else
		for i = 1, #windows do
			local win = windows[i]
			if win and win:IsShown() then
				win.db.hidden = true
				win:Hide()
			elseif win then
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
		win:DisplayMode(FindMode(themode) or win.selectedset)
	else
		win:DisplayModes(win.selectedset)
	end
end

-- wipes all windows
function Skada:Wipe()
	for i = 1, #windows do
		local win = windows[i]
		if win and win.Wipe then
			win:Wipe()
		end
	end
end

function Skada:SetActive(enable)
	if enable and self.db.profile.hidden then
		enable = false
	end

	for i = 1, #windows do
		local win = windows[i]
		if win and enable and not win:IsShown() then
			win:Show()
		elseif win and not enable and win:IsShown() then
			win:Hide()
		end
	end

	if not enable and self.db.profile.hidedisables then
		if not disabled then
			self:Debug(format("%s |cffff0000%s|r", L["Data Collection"], L["DISABLED"]))
		end
		disabled = true
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		if disabled then
			self:Debug(format("%s |cff00ff00%s|r", L["Data Collection"], L["ENABLED"]))
		end
		disabled = false
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatLogEvent")
	end

	self:UpdateDisplay(true)
end

-------------------------------------------------------------------------------
-- mode functions

do
	-- scane modes to add column options
	local function ScanForColumns(mode)
		if type(mode) == "table" and not mode.scanned then
			mode.scanned = true

			if mode.metadata then
				-- add columns if available
				if mode.metadata.columns then
					Skada:AddColumnOptions(mode)
				end

				-- scan for linked modes
				if mode.metadata.click1 then
					ScanForColumns(mode.metadata.click1)
				end
				if mode.metadata.click2 then
					ScanForColumns(mode.metadata.click2)
				end
				if mode.metadata.click3 then
					ScanForColumns(mode.metadata.click3)
				end
				if not Skada.Ascension and mode.metadata.click4 then
					ScanForColumns(mode.metadata.click4)
				end
			end
		end
	end

	function Skada:AddMode(mode, category)
		if self.total then
			VerifySet(mode, self.total)
		end

		if self.current then
			VerifySet(mode, self.current)
		end

		for i = 1, #self.char.sets do
			VerifySet(mode, self.char.sets[i])
		end

		mode.category = category or OTHER
		modes[#modes + 1] = mode

		if selected_feed == nil and self.db.profile.feed ~= "" then
			self:SetFeed(self.db.profile.feed)
		end

		ScanForColumns(mode)
		Skada:SortModes()

		for i = 1, #windows do
			local win = windows[i]
			if win then
				if win.db and mode.moduleName == win.db.mode then
					self:RestoreView(win, win.db.set, mode.moduleName)
				end
				if win.Wipe then
					win:Wipe()
				end
			end
		end

		self.changed = true
	end
end

function Skada:RemoveMode(mode)
	for i = 1, #modes do
		if modes[i] == mode then
			tremove(modes, i)
		end
	end
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
	local numorder = 80
	function Skada:AddDisplaySystem(key, mod)
		displays[key] = mod
		if mod.description then
			Skada.options.args.windows.args[format("%sdesc", key)] = {
				type = "description",
				name = format("\n|cffffd700%s|r:\n%s", mod.name, mod.description),
				fontSize = "medium",
				order = numorder
			}
			numorder = numorder + 10
		end
	end
end

-------------------------------------------------------------------------------
-- set functions

-- deletes a set
function Skada:DeleteSet(set, index)
	if not (set and index) then
		for i = 1, #self.char.sets do
			local s = self.char.sets[i]
			if s and ((i == index) or (set == s)) then
				set = set or s
				index = index or i
				break
			end
		end
	end

	if set and index then
		self.callbacks:Fire("Skada_SetDeleted", index, tremove(self.char.sets, index))

		if set == self.last then
			self.last = nil
		end

		-- Don't leave windows pointing to a deleted sets
		for i = 1, #windows do
			local win = windows[i]
			if win then
				if win.selectedset == index or win:GetSelectedSet() == set then
					win.selectedset = "current"
					win.changed = true
				elseif (tonumber(win.selectedset) or 0) > index then
					win.selectedset = win.selectedset - 1
					win.changed = true
				end
				win:RestoreView()
			end
		end

		self:Wipe()
		self:UpdateDisplay(true)

		-- clean garbage afterwards
		self:CleanGarbage()
	end
end

-------------------------------------------------------------------------------
-- player & enemies functions

-- finds a player that was already recorded
function Skada:FindPlayer(set, id, name, strict)
	if set and set.players and id and id ~= "total" then
		set._playeridx = set._playeridx or {}

		local player = set._playeridx[id]
		if player then
			return self.playerPrototype:Bind(player, set)
		end

		-- search the set
		for i = 1, #set.players do
			local p = set.players[i]
			if p and ((id and p.id == id) or (name and p.name == name)) then
				set._playeridx[id] = self.playerPrototype:Bind(p, set)
				return p
			end
		end

		-- needed for certain bosses
		local isboss, _, npcname = self:IsBoss(id, name)
		if isboss then
			player = {id = id, name = npcname or name, class = "BOSS"}
			set._playeridx[id] = self.playerPrototype:Bind(player, set)
			return player
		end

		-- our last hope!
		if not strict then
			player = self.playerPrototype:Bind({id = id, name = name or UNKNOWN, class = "PET"}, set)
		end

		return player
	end
end

-- returns the unit id from guid (priority players and pets)
function Skada:GetUnitId(guid, filter, strict)
	-- pets?
	if guid and pets[guid] and players[pets[guid].id] then
		return players[pets[guid].id] .. "pet"
	end

	-- player?
	if guid and players[guid] then
		return players[guid]
	end

	return strict and nil or GetUnitIdFromGUID(guid, filter)
end

-- finds a player table or creates it if not found
function Skada:GetPlayer(set, guid, name, flag)
	if not (set and set.players and guid) then return end

	local player = self:FindPlayer(set, guid, name, true)

	if not player then
		if not name then return end

		player = {id = guid, name = name, flag = flag, time = 0}

		if players[guid] then
			player.class = select(2, UnitClass(players[guid]))
		elseif pets[guid] then
			player.class = "PET"
		else
			player.class = self.unitClass(guid, flag, nil, nil, name)
		end

		for i = 1, #modes do
			local mode = modes[i]
			if mode and mode.AddPlayerAttributes then
				mode:AddPlayerAttributes(player, set)
			end
		end

		set.players[#set.players + 1] = player
	end

	-- not all modules provide playerflags
	if player.flag == nil and flag then
		player.flag = flag
	end

	-- attempt to fix player name:
	if
		(player.name == UNKNOWNOBJECT and name ~= UNKNOWNOBJECT) or -- unknown unit
		(player.name == UKNOWNBEING and name ~= UKNOWNBEING) or -- unknown unit
		(player.name == player.id and name ~= player.id) -- GUID is the same as the name
	then
		player.name = (player.id == self.userGUID or guid == self.userGUID) and self.userName or name
	end

	-- fix players created before their info was received
	-- roles and specs are temporary disabled for Project Ascension
	if not self.Ascension and not self.AscensionCoA and player.class and Skada.validclass[player.class] then
		if player.role == nil or player.role == "NONE" then
			if player.id == self.userGUID and self.userRole then
				player.role = self.userRole
			else
				player.role = GetUnitRole(players[player.id] or player.name, player.class)
			end
		end
		if player.spec == nil then
			if player.id == self.userGUID and self.userSpec then
				player.spec = self.userSpec
			else
				player.spec = GetUnitSpec(players[player.id] or player.name, player.class)
			end
		end
	end

	-- total set has "last" always removed.
	player.last = player.last or GetTime()

	self.changed = true
	self.callbacks:Fire("Skada_GetPlayer", player)
	return self.playerPrototype:Bind(player, set)
end

-- finds an enemy unit
function Skada:FindEnemy(set, name, id)
	if set and set.enemies and name then
		set._enemyidx = set._enemyidx or {}

		local enemy = set._enemyidx[name]
		if enemy then
			return self.enemyPrototype:Bind(enemy, set)
		end

		for i = 1, #set.enemies do
			local e = set.enemies[i]
			if e and ((id and id == e.id) or (name and e.name == name)) then
				set._enemyidx[name] = self.enemyPrototype:Bind(e, set)
				return e
			end
		end
	end
end

-- finds or create an enemy entry
-- function Skada:FindEnemy(set, name, guid)
function Skada:GetEnemy(set, name, guid, flag)
	if not (set and set.enemies and name) then return end
	local enemy = self:FindEnemy(set, name, guid)
	if not enemy then
		enemy = {id = guid or name, name = name, flag = flag}
		if guid or flag then
			enemy.class = self.unitClass(guid, flag)
		else
			enemy.class = "ENEMY"
		end

		set.enemies[#set.enemies + 1] = enemy
	end

	self.changed = true
	self.callbacks:Fire("Skada_GetEnemy", enemy)
	return self.enemyPrototype:Bind(enemy, set)
end

-- generic find a player or an enemey
function Skada:FindActor(set, id, name)
	local actor, enemy = self:FindPlayer(set, id, name, true), nil
	if not actor then
		actor, enemy = self:FindEnemy(set, name, id), true
	end
	return actor, enemy
end

-- generic: finds a player/enemy or creates it.
function Skada:GetActor(set, id, name, flag)
	local actor, enemy = self:FindActor(set, id, name)
	-- creates it if not found
	if not actor then
		if self:IsPlayer(id, flag, name) == 1 or self:IsPet(id, flag) == 1 then -- group members or group pets
			actor = self:GetPlayer(set, id, name, flag)
		else -- an outsider maybe?
			actor, enemy = self:GetEnemy(set, name, id, flag), true
		end
	end
	return actor, enemy
end

-- checks if the unit is a player
function Skada:IsPlayer(guid, flag, name)
	if guid and (players[guid] or pets[guid]) then
		return players[guid] and 1 or false -- 1 for player, else false
	end
	if name and UnitIsPlayer(name) then
		return true
	end
	if tonumber(flag) and band(flag, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 then
		return true
	end
	return false
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
				while (title and title ~= "%s" and find(title, "%s")) do
					ownerPatterns[#ownerPatterns + 1] = title
					i = i + 1
					title = _G["UNITNAME_SUMMON_TITLE" .. i]
				end
			end

			function ValidatePetOwner(text, name)
				for i = 1, #ownerPatterns do
					local pattern = ownerPatterns[i]
					if pattern and EscapeStr(format(pattern, name)) == text then
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
					if ValidatePetOwner(text, ownerName) or find(text, ownerName) then
						return true
					end
				end
			end
			return false
		end

		-- attempt to get the pet's owner from tooltip
		function GetPetOwnerFromTooltip(guid)
			if Skada.current and Skada.current.players and guid then
				pettooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
				pettooltip:ClearLines()
				pettooltip:SetHyperlink(format("unit:%s", guid))

				-- we only need to scan the 2nd line.
				local text = _G["SkadaPetTooltipTextLeft2"] and _G["SkadaPetTooltipTextLeft2"]:GetText()
				if text and text ~= "" then
					for i = 1, #Skada.current.players do
						local p = Skada.current.players[i]
						local playername = p and gsub(p.name, "%-.*", "")
						if playername and ((LOCALE_ruRU and FindNameDeclension(text, playername)) or ValidatePetOwner(text, playername)) then
							return p.id, p.name
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

	local function CommonFixPets(guid, flag)
		if guid and pets[guid] then
			return pets[guid]
		end

		-- flag is provided and it is mine.
		if guid and flag and band(flag, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 then
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
		if action and self:IsPlayer(action.playerid, action.playerflags, action.playername) == false then
			local owner = pets[action.playerid] or CommonFixPets(action.playerid, action.playerflags)

			if owner then
				action.petname = action.playername

				if self.db.profile.mergepets then
					if action.spellname and action.playername then
						action.spellname = format("%s (%s)", action.spellname, action.playername)
					end
					action.playerid = owner.id
					action.playername = owner.name
				else
					-- just append the creature id to the player
					action.playerid = format("%s%s", owner.id, GetCreatureId(action.playerid))
					action.playername = format("%s (%s)", action.playername, owner.name)
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
	if pets[petGUID] then
		pets[petGUID].id = ownerGUID
		pets[petGUID].name = ownerName
	else
		pets[petGUID] = {id = ownerGUID, name = ownerName}
	end
end

function Skada:SummonPet(petGUID, petFlags, ownerGUID, ownerName, ownerFlags)
	if band(ownerFlags, BITMASK_GROUP) ~= 0 or band(ownerFlags, BITMASK_PETS) ~= 0 or (band(petFlags, BITMASK_PETS) ~= 0 and pets[petGUID]) then
		-- we assign the pet the normal way
		self:AssignPet(ownerGUID, ownerName, petGUID)

		-- we fix the table by searching through the complete list
		self.fixsummon = true
		while self.fixsummon do
			self.fixsummon = nil
			for pet, owner in pairs(pets) do
				if pets[owner.id] then
					pets[pet] = {id = pets[owner.id].id, name = pets[owner.id].name}
					self.fixsummon = true
				end
			end
		end
	end
end

function Skada:DismissPet(petGUID, delay)
	if petGUID and pets[petGUID] then
		-- delayed for a reason (2 x MAINMENU_SLIDETIME).
		Skada:ScheduleTimer(function() pets[petGUID] = nil end, delay or 0.6)
	end
end

function Skada:GetPetOwner(petGUID)
	return pets[petGUID]
end

function Skada:IsPet(guid, flag)
	if guid and pets[guid] then
		return 1 -- group pet
	end
	if tonumber(flag) and (band(flag, BITMASK_PETS) ~= 0) then
		-- we return 1 for a friendly pet (probably group's) or true.
		return (band(flag, COMBATLOG_OBJECT_REACTION_FRIENDLY) ~= 0) and 1 or true
	end
	return false
end

function Skada:PetDebug()
	self:CheckGroup()
	self:Print(PETS)
	for pet, owner in pairs(pets) do
		self:Printf("pet %s belongs to %s, %s", pet, owner.id, owner.name)
	end
end

-------------------------------------------------------------------------------
-- tooltip functions

-- sets the tooltip position
function Skada:SetTooltipPosition(tooltip, frame, display, win)
	if win and win.db.tooltippos ~= "NONE" then
		tooltip:SetOwner(UIParent, "ANCHOR_NONE")

		local anchor = find(win.db.tooltippos, "TOP") and "TOP" or "BOTTOM"
		if find(win.db.tooltippos, "LEFT") or find(win.db.tooltippos, "RIGHT") then
			anchor = format("%s%s", anchor, find(win.db.tooltippos, "LEFT") and "RIGHT" or "LEFT")
			tooltip:SetPoint(anchor, frame, win.db.tooltippos)
		elseif anchor == "TOP" then
			tooltip:SetPoint("BOTTOM", frame, anchor)
		else
			tooltip:SetPoint("TOP", frame, anchor)
		end
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
		local top = frame:GetTop() * s -- frame top

		tooltip:SetOwner(frame, "ANCHOR_PRESERVE")
		tooltip:ClearAllPoints()

		if (frame:GetLeft() * s) < (GetScreenWidth() / 2) then
			tooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT")
		else
			tooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT")
		end
	else
		local anchor = find(self.db.profile.tooltippos, "top") and "TOP" or "BOTTOM"
		anchor = format("%s%s", anchor, find(self.db.profile.tooltippos, "left") and "RIGHT" or "LEFT")
		tooltip:SetOwner(frame, "ANCHOR_NONE")
		tooltip:SetPoint(anchor, frame, self.db.profile.tooltippos)
	end
end

local ValueIdSort
do
	local function ValueSort(a, b)
		if not a or a.value == nil then
			return false
		elseif not b or b.value == nil then
			return true
		else
			return a.value > b.value
		end
	end

	function ValueIdSort(a, b)
		if not a or a.value == nil or a.id == nil then
			return false
		elseif not b or b.value == nil or b.id == nil then
			return true
		else
			return a.value > b.value
		end
	end

	local white = {r = 1, g = 1, b = 1}
	function Skada:AddSubviewToTooltip(tooltip, win, mode, id, label)
		if not (type(mode) == "table" and mode.Update) then return end

		-- windows should have separate tooltip tables in order
		-- to display different numbers for same spells for example.
		if not win.ttwin then
			win.ttwin = Window:New(true)
		end

		win.ttwin:Reset()

		if mode.Enter then
			mode:Enter(win.ttwin, id, label)
		end

		mode:Update(win.ttwin, win:GetSelectedSet())

		if not mode.metadata or not mode.metadata.ordersort then
			tsort(win.ttwin.dataset, ValueSort)
		end

		if #win.ttwin.dataset > 0 then
			tooltip:AddLine(win.ttwin.title or mode.title or mode.moduleName)
			local nr = 0

			for i = 1, #win.ttwin.dataset do
				local data = win.ttwin.dataset[i]
				if data and data.id and not data.ignore and nr < Skada.db.profile.tooltiprows then
					nr = nr + 1
					local color = white

					if data.color then
						color = data.color
					elseif data.class and Skada.validclass[data.class] then
						color = Skada:ClassColor(data.class)
					end

					local title = data.text or data.label
					if mode.metadata and mode.metadata.showspots then
						title = format("|cffffffff%d.|r %s", nr, title)
					end
					tooltip:AddDoubleLine(title, data.valuetext, color.r, color.g, color.b)
				elseif nr >= Skada.db.profile.tooltiprows then
					break -- no need to continue
				end
			end

			if mode.Enter then
				tooltip:AddLine(" ")
			end
		end
	end

	function Skada:ShowTooltip(win, id, label, bar)
		if self.db.profile.tooltips and win and win.metadata and not (bar and bar.ignore) then
			local t, md = GameTooltip, win.metadata

			if md.is_modelist and self.db.profile.informativetooltips then
				t:ClearLines()
				self:AddSubviewToTooltip(t, win, FindMode(id), id, label)
				t:Show()
			elseif md.click1 or md.click2 or md.click3 or (not self.Ascension and md.click4) or md.tooltip then
				t:ClearLines()
				local hasClick = md.click1 or md.click2 or md.click3 or md.click4

				if md.tooltip then
					local numLines = t:NumLines()
					md.tooltip(win, id, label, t)

					if t:NumLines() ~= numLines and hasClick then
						t:AddLine(" ")
					end
				end

				if self.db.profile.informativetooltips then
					if md.click1 and not self:NoTotalClick(win.selectedset, md.click1) then
						self:AddSubviewToTooltip(t, win, md.click1, id, label)
					end
					if md.click2 and not self:NoTotalClick(win.selectedset, md.click2) then
						self:AddSubviewToTooltip(t, win, md.click2, id, label)
					end
					if md.click3 and not self:NoTotalClick(win.selectedset, md.click3) then
						self:AddSubviewToTooltip(t, win, md.click3, id, label)
					end
					if not self.Ascension and md.click4 and not self:NoTotalClick(win.selectedset, md.click4) then
						self:AddSubviewToTooltip(t, win, md.click4, id, label)
					end
				end

				if md.post_tooltip then
					local numLines = t:NumLines()
					md.post_tooltip(win, id, label, t)

					if numLines > 0 and t:NumLines() ~= numLines and hasClick then
						t:AddLine(" ")
					end
				end

				if type(md.click1) == "function" then
					t:AddLine(format(L["Click for |cff00ff00%s|r"], md.click1_label or L.Unknown))
				elseif md.click1 and not self:NoTotalClick(win.selectedset, md.click1) then
					t:AddLine(format(L["Click for |cff00ff00%s|r"], md.click1_label or md.click1.moduleName))
				end

				if type(md.click2) == "function" then
					t:AddLine(format(L["Shift-Click for |cff00ff00%s|r"], md.click2_label or L.Unknown))
				elseif md.click2 and not self:NoTotalClick(win.selectedset, md.click2) then
					t:AddLine(format(L["Shift-Click for |cff00ff00%s|r"], md.click2_label or md.click2.moduleName))
				end

				if type(md.click3) == "function" then
					t:AddLine(format(L["Control-Click for |cff00ff00%s|r"], md.click3_label or L.Unknown))
				elseif md.click3 and not self:NoTotalClick(win.selectedset, md.click3) then
					t:AddLine(format(L["Control-Click for |cff00ff00%s|r"], md.click3_label or md.click3.moduleName))
				end

				if not self.Ascension and type(md.click4) == "function" then
					t:AddLine(format(L["Alt-Click for |cff00ff00%s|r"], md.click4_label or L.Unknown))
				elseif not self.Ascension and md.click4 and not self:NoTotalClick(win.selectedset, md.click4) then
					t:AddLine(format(L["Alt-Click for |cff00ff00%s|r"], md.click4_label or md.click4.moduleName))
				end

				t:Show()
			end
		end
	end
end

function Skada:FilterClass(win, id, label)
	if win.class then
		win:DisplayMode(win.selectedmode, nil)
	elseif win.GetSelectedSet and id then
		local set = win:GetSelectedSet()
		local actor = set and set:GetPlayer(id, label)
		win:DisplayMode(win.selectedmode, actor and actor.class)
	end
end

-------------------------------------------------------------------------------
-- slash commands

local function GenerateTotal()
	if #Skada.char.sets == 0 then return end

	Skada.char.total = CreateSet(L["Total"], Skada.char.total)
	Skada.total = Skada.char.total
	Skada.total.starttime = nil
	Skada.total.endtime = nil

	for i = 1, #Skada.char.sets do
		local set = Skada.char.sets[i]
		for k, v in pairs(set) do
			if k == "starttime" and (not Skada.total.starttime or v < Skada.total.starttime) then
				Skada.total.starttime = v
			elseif k == "endtime" and (not Skada.total.endtime or v > Skada.total.endtime) then
				Skada.total.endtime = v
			elseif type(v) == "number" and k ~= "starttime" and k ~= "endtime" then
				Skada.total[k] = (Skada.total[k] or 0) + v
			end
		end

		for j = 1, #set.players do
			local p = set.players[j]
			if p then
				local index = nil
				for k = 1, #Skada.total.players do
					local a = Skada.total.players[k]
					if a and a.id == p.id then
						index = k
						break
					end
				end

				local player = index and Skada.total.players[index] or {}

				for k, v in pairs(p) do
					if (type(v) == "string" or k == "spec" or k == "flag") then
						player[k] = player[k] or v
					elseif type(v) == "number" then
						player[k] = (player[k] or 0) + v
					end
				end

				if not index then
					Skada.total.players[#Skada.total.players + 1] = player
				end
			end
		end
	end

	ReloadUI()
end

function Skada:Command(param)
	local cmd, arg1, arg2, arg3 = self:GetArgs(param, 4)
	if cmd == "pets" then
		self:PetDebug()
	elseif cmd == "reset" then
		self:Reset(IsShiftKeyDown())
	elseif cmd == "reinstall" then
		self:Reinstall()
	elseif cmd == "newsegment" or cmd == "new" then
		self:NewSegment()
	elseif cmd == "newphase" or cmd == "phase" then
		self:NewPhase()
	elseif cmd == "stopsegment" or cmd == "stop" then
		self:StopSegment(nil, arg1)
	elseif cmd == "resumesegment" or cmd == "resume" then
		self:ResumeSegment(nil, arg1)
	elseif cmd == "toggle" then
		self:ToggleWindow()
	elseif cmd == "show" then
		if self.db.profile.hidden then
			self.db.profile.hidden = false
			self:ApplySettings()
		end
	elseif cmd == "hide" then
		if not self.db.profile.hidden then
			self.db.profile.hidden = true
			self:ApplySettings()
		end
	elseif cmd == "debug" then
		self.db.profile.debug = not self.db.profile.debug
		self:Print("Debug mode " .. (self.db.profile.debug and ("|cff00ff00" .. L["ENABLED"] .. "|r") or ("|cffff0000" .. L["DISABLED"] .. "|r")))
	elseif cmd == "config" or cmd == "options" then
		self:OpenOptions()
	elseif cmd == "clear" or cmd == "clean" then
		self:CleanGarbage()
	elseif cmd == "import" and self.OpenImport then
		self:OpenImport()
	elseif cmd == "export" and self.ExportProfile then
		self:ExportProfile()
	elseif cmd == "about" or cmd == "info" then
		self:OpenOptions("about")
	elseif cmd == "version" or cmd == "checkversion" then
		self:Printf("|cffffbb00%s|r: %s - |cffffbb00%s|r: %s", L["Version"], self.version, L["Date"], GetAddOnMetadata("Skada", "X-Date"))
		CheckVersion()
	elseif cmd == "website" or cmd == "github" then
		self:Printf("|cffffbb00%s|r", self.website)
	elseif cmd == "discord" then
		self:Printf("|cffffbb00%s|r", self.discord)
	elseif cmd == "timemesure" or cmd == "measure" then
		if self.db.profile.timemesure == 2 then
			self.db.profile.timemesure = 1
			self:Printf("%s: %s", L["Time Measure"], L["Activity Time"])
			self:ApplySettings()
		elseif self.db.profile.timemesure == 1 then
			self.db.profile.timemesure = 2
			self:Printf("%s: %s", L["Time Measure"], L["Effective Time"])
			self:ApplySettings()
		end
	elseif cmd == "numformat" then
		self.db.profile.numberformat = self.db.profile.numberformat + 1
		if self.db.profile.numberformat > 3 then
			self.db.profile.numberformat = 1
		end
		self:ApplySettings()
	elseif cmd == "raise" and arg1 then
		if tonumber(arg1) then self.db.profile.setslimit = max(0, min(50, arg1)) end
		self:Print(L["Persistent segments"], self.db.profile.setslimit)
	elseif cmd == "total" or cmd == "generate" then
		GenerateTotal()
	elseif cmd == "report" then
		if not self:CanReset() then
			self:Print(L["There is nothing to report."])
			return
		end

		local chan = arg1 and arg1:trim()
		local report_mode_name = arg2 or L["Damage"]
		local num = tonumber(arg3) or 10

		-- automatic
		if chan == "auto" and IsInGroup() then
			chan = IsInRaid() and "raid" or "party"
		end

		-- Sanity checks.
		if chan and (chan == "say" or chan == "guild" or chan == "raid" or chan == "party" or chan == "officer") and (report_mode_name and FindMode(report_mode_name)) then
			self:Report(chan, "preset", report_mode_name, "current", num)
		else
			self:Print("Usage:")
			self:Printf("%-20s", "/skada report [channel] [mode] [lines]")
		end
	else
		self:Print(L["Usage:"])
		print("|cffffaeae/skada|r |cffffff33report|r [channel] [mode] [lines]")
		print("|cffffaeae/skada|r |cffffff33toggle|r / |cffffff33show|r / |cffffff33hide|r")
		print("|cffffaeae/skada|r |cffffff33newsegment|r / |cffffff33newphase|r")
		print("|cffffaeae/skada|r |cffffff33numformat|r / |cffffff33measure|r")
		print("|cffffaeae/skada|r |cffffff33import|r / |cffffff33export|r")
		print("|cffffaeae/skada|r |cffffff33about|r / |cffffff33version|r / |cffffff33website|r / |cffffff33discord|r")
		print("|cffffaeae/skada|r |cffffff33reset|r / |cffffff33clean|r / |cffffff33reinstall|r")
		print("|cffffaeae/skada|r |cffffff33config|r / |cffffff33debug|r")
	end
end

-------------------------------------------------------------------------------
-- report function

do
	local SendChatMessage = SendChatMessage

	function Skada:SendChat(msg, chan, chantype, noescape)
		if lower(chan) == "self" or lower(chantype) == "self" then
			Skada:Print(msg)
			return
		elseif lower(chan) == "auto" then
			if not IsInGroup() then
				return
			elseif Skada.instanceType == "pvp" or Skada.instanceType == "arena" then
				chan = "battleground"
			else
				chan = IsInRaid() and "raid" or "party"
			end
		end

		if not noescape then
			msg = EscapeStr(msg)
		end

		if chantype == "channel" then
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
		elseif chantype == nil then
			chantype = "preset"
		end

		local report_table, report_set, report_mode

		if window == nil then
			report_mode = FindMode(report_mode_name or L["Damage"])
			report_set = self:GetSet(report_set_name or "current")
			if report_set == nil then
				self:Print(L["No mode or segment selected for report."])
				return
			end

			report_table = Window:New(true)
			report_mode:Update(report_table, report_set)
		elseif type(window) == "string" then
			for i = 1, #windows do
				local win = windows[i]
				if win and win.db and lower(win.db.name) == lower(window) then
					report_table = win
					report_set = win:GetSelectedSet()
					report_mode = win.selectedmode
					break
				end
			end
		else
			report_table = window
			report_set = window:GetSelectedSet()
			report_mode = window.selectedmode
		end

		if not report_set then
			Skada:Print(L["There is nothing to report."])
			return
		end

		if report_table.metadata and not report_table.metadata.ordersort then
			tsort(report_table.dataset, ValueIdSort)
		end

		if not report_mode then
			self:Print(L["No mode or segment selected for report."])
			return
		end

		local title = (window and window.title) or report_mode.title or report_mode.moduleName
		local label = (report_mode_name == L["Improvement"]) and self.userName or Skada:GetSetLabel(report_set)
		self:SendChat(format(L["Skada: %s for %s:"], title, label), channel, chantype)

		maxlines = maxlines or 10
		local nr = 0
		for i = 1, #report_table.dataset do
			local data = report_table.dataset[i]
			if data and not data.ignore and ((barid and barid == data.id) or (data.id and not barid)) and nr < maxlines then
				nr = nr + 1
				label = nil

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
			elseif nr >= maxlines then
				break
			end
		end

		-- clean garbage afterwards
		report_table, report_set, report_mode = nil, nil, nil
		self:CleanGarbage()
	end
end

-------------------------------------------------------------------------------
-- feed functions

function Skada:SetFeed(name)
	if name and feeds[name] then
		selected_feed = feeds[name]
		self:UpdateDisplay()
	end
end

function Skada:AddFeed(name, func)
	feeds[name] = func
end

function Skada:RemoveFeed(name)
	feeds[name] = nil
end

-------------------------------------------------------------------------------

function Skada:PLAYER_ENTERING_WORLD()
	Skada:CheckZone()
	if was_in_party == nil then
		Skada:ScheduleTimer("UpdateRoster", 1)
	end

	-- account-wide addon version
	local version = ConvertVersion(self.version)
	if version ~= self.db.global.version then
		self.callbacks:Fire("Skada_UpdateCore", self.db.global.version, version)
		self.db.global.version = version
	end

	-- character-specific addon version
	if version ~= self.char.version then
		if (version - self.char.version) >= 5 or (version - self.char.version) <= -5 then
			self:Reset(true)
		end
		self.callbacks:Fire("Skada_UpdateData", self.char.version, version)
		self.char.version = version
	end
end

local lastCheckGroup
function Skada:CheckGroup()
	-- throttle group check.
	local checkTime = GetTime()
	if lastCheckGroup and (checkTime - lastCheckGroup) <= 0.25 then
		return
	end
	lastCheckGroup = checkTime

	for unit, owner in UnitIterator() do
		if owner == nil then
			players[UnitGUID(unit)] = unit
		else
			Skada:AssignPet(UnitGUID(owner), UnitName(owner), UnitGUID(unit))
		end
	end

	-- update my spec and role.
	if not Skada.Ascension and not Skada.AscensionCoA then
		Skada.userSpec = GetUnitSpec("player", Skada.userClass)
		Skada.userRole = GetUnitRole("player", Skada.userClass)
	end
end

do
	local inInstance, isininstance, isinpvp
	local was_in_instance, was_in_pvp

	function Skada:CheckZone()
		inInstance, self.instanceType = IsInInstance()
		isininstance = inInstance and (self.instanceType == "party" or self.instanceType == "raid")
		isinpvp = IsInPvP()

		if isininstance and was_in_instance ~= nil and not was_in_instance and self.db.profile.reset.instance ~= 1 and self:CanReset() then
			if self.db.profile.reset.instance == 3 then
				self:ShowPopup(nil, true)
			else
				self:Reset()
			end
		end

		if self.db.profile.hidepvp then
			if isinpvp then
				self:SetActive(false)
			elseif was_in_pvp then
				self:SetActive(true)
			end
		end

		was_in_instance = (isininstance == true)
		was_in_pvp = (isinpvp == true)
		self.callbacks:Fire("Skada_ZoneCheck")
		self:Toggle()
	end
end

do
	local version_count = 0

	function CheckVersion()
		Skada:SendComm(nil, nil, "VersionCheck", Skada.version)
		if version_timer then
			Skada:CancelTimer(version_timer, true)
			version_timer = nil
		end
	end

	function ConvertVersion(ver)
		return tonumber(type(ver) == "string" and gsub(ver, "%.", "") or ver) or 0
	end

	function Skada:OnCommVersionCheck(sender, version)
		if sender and sender ~= self.userName and version then
			version = ConvertVersion(version)

			local ver = ConvertVersion(self.version)
			if not (version and ver) or self.versionChecked then
				return
			end

			if version > ver then
				self:Printf(L["Skada is out of date. You can download the newest version from |cffffbb00%s|r"], self.website)
			elseif version < ver then
				self:SendComm("WHISPER", sender, "VersionCheck", self.version)
			end

			self.versionChecked = true
		end
	end

	function CheckForJoinAndLeave()
		if not IsInGroup() and was_in_party then
			if Skada.db.profile.reset.leave == 3 and Skada:CanReset() then
				Skada:ShowPopup(nil, true)
			elseif Skada.db.profile.reset.leave == 2 and Skada:CanReset() then
				Skada:Reset()
			end

			if Skada.db.profile.hidesolo then
				Skada:SetActive(false)
			end
		end

		if IsInGroup() and not was_in_party then
			if Skada.db.profile.reset.join == 3 and Skada:CanReset() then
				Skada:ShowPopup(nil, true)
			elseif Skada.db.profile.reset.join == 2 and Skada:CanReset() then
				Skada:Reset()
			end

			if Skada.db.profile.hidesolo and not (Skada.db.profile.hidepvp and IsInPvP()) then
				Skada:SetActive(true)
			end
		end

		was_in_party = IsInGroup()
	end

	function Skada:UpdateRoster()
		CheckForJoinAndLeave()
		Skada:CheckGroup()

		-- version check
		local t, _, count = GetGroupTypeAndCount()
		if t == "party" then
			count = count + 1
		end

		if count ~= version_count then
			if count > 1 and count > version_count then
				version_timer = version_timer or Skada:ScheduleTimer(CheckVersion, 10)
			end
			version_count = count
		end

		Skada:SendMessage("GROUP_ROSTER_UPDATE", players, pets)
	end
end

do
	local UnitHasVehicleUI = UnitHasVehicleUI
	local ignoredUnits = {"target", "focus", "npc", "NPC", "mouseover"}

	function Skada:UNIT_PET(_, unit)
		if unit and not tContains(ignoredUnits, unit) then
			self:CheckGroup()
		end
	end

	function Skada:CheckVehicle(_, unit)
		if unit and not tContains(ignoredUnits, unit) then
			local guid = UnitGUID(unit)
			if guid and players[guid] then
				if UnitHasVehicleUI(unit) then
					local prefix, id, suffix = strmatch(unit, "([^%d]+)([%d]*)(.*)")
					local vUnitId = format("%spet%s%s", prefix, id, suffix)
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

	for i = 1, #self.char.sets do
		local set = self.char.sets[i]
		if set and not set.keep then
			return true
		end
	end

	return false
end

function Skada:Reset(force)
	if self.testMode then return end

	if force then
		wipe(self.char.sets)
		self.char.total = nil
	elseif not self:CanReset() then
		self:Print(L["There is no data to reset."])
		return
	end

	self:Wipe()
	self:CheckGroup()

	if self.current ~= nil then
		self.current = CreateSet(L["Current"], self.current)
	end

	if self.total ~= nil then
		self.total = CreateSet(L["Total"], self.total)
		self.char.total = self.total
	end

	self.last = nil

	CleanSets(true)

	for i = 1, #windows do
		local win = windows[i]
		if win and win.selectedset ~= "total" then
			win.selectedset = "current"
			win.changed = true
			win:RestoreView()
		end
	end

	dataobj.text = "n/a"
	self:UpdateDisplay(true)
	self:Notify(L["All data has been reset."])
	self:CleanGarbage()
	StaticPopup_Hide("SkadaCommonConfirmDialog")
	CloseDropDownMenus()
end

function Skada:UpdateDisplay(force)
	if force then
		self.changed = true
	end

	if type(selected_feed) == "function" then
		local feedtext = selected_feed()
		if feedtext then
			dataobj.text = feedtext
		end
	end

	for i = 1, #windows do
		local win = windows[i]
		if win and (self.changed or win.changed or (self.current and (win.selectedset == "current" or win.selectedset == "total"))) then
			win.changed = false

			if win.selectedmode then
				local set = win:GetSelectedSet()

				if set then
					win:UpdateInProgress()

					if win.selectedmode.Update then
						if set then
							win.selectedmode:Update(win, set)
						else
							self:Printf("No set available to pass to %s Update function! Try to reset Skada.", win.selectedmode.moduleName)
						end
					elseif win.selectedmode.moduleName then
						self:Print("Mode %s does not have an Update function!", win.selectedmode.moduleName)
					end

					if
						self.db.profile.showtotals and
						win.selectedmode.GetSetSummary and
						((set.type and set.type ~= "none") or set.name == L.Total)
					then
						local valuetext, total = win.selectedmode:GetSetSummary(set, win)
						if valuetext or total then
							local existing = nil  -- an existing bar?

							if not total then
								total = 0
								for j = 1, #win.dataset do
									local data = win.dataset[j]
									if data and data.id then
										total = total + data.value
									end
									if data and not existing and not data.id then
										existing = data
									end
								end
							end
							total = total + 1

							local d = existing or {}
							d.id = "total"
							d.label = L["Total"]
							d.text = nil
							d.ignore = true
							d.value = total
							d.valuetext = valuetext or total

							if self.db.profile.moduleicons and win.selectedmode.metadata and win.selectedmode.metadata.icon then
								d.icon = win.selectedmode.metadata.icon
							else
								d.icon = dataobj.icon
							end

							if not existing then tinsert(win.dataset, 1, d) end
						end
					end
				end

				win:UpdateDisplay()
			elseif win.selectedset then
				local set = win:GetSelectedSet()

				for j = 1, #modes do
					local mode = modes[j]
					if mode then
						local d = win:nr(j)

						d.id = mode.moduleName
						d.label = mode.moduleName
						d.value = 1

						if self.db.profile.moduleicons and mode.metadata and mode.metadata.icon then
							d.icon = mode.metadata.icon
						end

						if set and mode.GetSetSummary then
							d.valuetext = mode:GetSetSummary(set, win)
						end
					end
				end

				win.metadata.ordersort = true

				if set then
					win.metadata.is_modelist = true
				end

				win:UpdateDisplay()
			else
				local nr = 1
				local d = win:nr(nr)

				d.id = "total"
				d.label = L["Total"]
				d.value = 1

				nr = nr + 1
				d = win:nr(nr)

				d.id = "current"
				d.label = L["Current"]
				d.value = 1

				for j = 1, #self.char.sets do
					local set = self.char.sets[j]
					if set then
						nr = nr + 1
						d = win:nr(nr)

						d.id = tostring(set.starttime)
						d.label, d.valuetext = select(2, self:GetSetLabel(set))
						d.value = 1
						d.emphathize = set.keep
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

do
	local reverse = string.reverse
	local numbersystem = nil
	function SetNumeralFormat(system)
		system = system or numbersystem
		if numbersystem == system then return end
		numbersystem = system

		local ShortenValue = function(num)
			if num >= 1e9 or num <= -1e9 then
				return format("%.2fB", num / 1e9)
			elseif num >= 1e6 or num <= -1e6 then
				return format("%.2fM", num / 1e6)
			elseif num >= 1e3 or num <= -1e3 then
				return format("%.1fK", num / 1e3)
			end
			return format("%.0f", num)
		end

		if system == 3 or (system == 1 and (LOCALE_koKR or LOCALE_zhCN or LOCALE_zhTW)) then
			-- default to chinese, even for western clients.
			local symbol_1k, symbol_10k, symbol_1b = "千", "万", "亿"
			if LOCALE_koKR then
				symbol_1k, symbol_10k, symbol_1b = "천", "만", "억"
			elseif LOCALE_zhTW then
				symbol_1k, symbol_10k, symbol_1b = "千", "萬", "億"
			end

			ShortenValue = function(num)
				if num >= 1e8 or num <= -1e8 then
					return format("%.2f%s", num / 1e8, symbol_1b)
				elseif num >= 1e4 or num <= -1e4 then
					return format("%.2f%s", num / 1e4, symbol_10k)
				elseif num >= 1e3 or num <= -1e3 then
					return format("%.1f%s", num / 1e4, symbol_1k)
				end
				return format("%.0f", num)
			end
		end

		Skada.FormatNumber = function(self, num, fmt)
			if num then
				fmt = fmt or self.db.profile.numberformat or 1
				if fmt == 1 and (num >= 1e3 or num <= -1e3) then
					return ShortenValue(num)
				elseif fmt == 2 and (num >= 1e3 or num <= -1e3) then
					local left, mid, right = strmatch(tostring(floor(num)), "^([^%d]*%d)(%d*)(.-)$")
					return format("%s%s%s", left, reverse(gsub(reverse(mid), "(%d%d%d)", "%1,")), right)
				else
					return format("%.0f", num)
				end
			end
		end
	end
end

function Skada:FormatPercent(value, total, dec)
	dec = dec or self.db.profile.decimals or 1

	-- no value? 0%
	if not value then
		return format("%." .. dec .. "f%%", 0)
	end

	-- correct values.
	value, total = total and (100 * value) or value, max(1, total or 0)

	-- below 0? clamp to -999
	if value <= 0 then
		return format("%." .. dec .. "f%%", max(-999, value / total))
	-- otherwise, clamp to 999
	else
		return format("%." .. dec .. "f%%", min(999, value / total))
	end
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

function Skada:FormatName(name)
	if self.db.profile.translit and Translit then
		return Translit:Transliterate(name, "!")
	end
	return name
end

do
	-- brackets and separators
	local brackets = {"(%s)", "{%s}", "[%s]", "<%s>", "%s"}
	local separators = {"%s, %s", "%s. %s", "%s; %s", "%s - %s", "%s || %s", "%s / %s", "%s \\ %s", "%s ~ %s", "%s %s"}

	-- formats default values
	local format_2 = "%s (%s)"
	local format_3 = "%s (%s, %s)"

	function SetValueFormat(bracket, separator)
		format_2 = brackets[bracket or 1]
		format_3 = "%s " .. format(format_2, separators[separator or 1])
		format_2 = "%s " .. format_2
	end

	function Skada:FormatValueText(v1, b1, v2, b2, v3, b3)
		if b1 and b2 and b3 then
			return format(format_3, v1, v2, v3)
		elseif b1 and b2 then
			return format(format_2, v1, v2)
		elseif b1 and b3 then
			return format(format_2, v1, v3)
		elseif b2 and b3 then
			return format(format_2, v2, v3)
		elseif b2 then
			return v2
		elseif b1 then
			return v1
		elseif b3 then
			return v3
		end
	end

	function Skada:FormatValueCols(col1, col2, col3)
		if col1 and col2 and col3 then
			return format(format_3, col1, col2, col3)
		elseif col1 and col2 then
			return format(format_2, col1, col2)
		elseif col1 and col3 then
			return format(format_2, col1, col3)
		elseif col2 and col3 then
			return format(format_2, col2, col3)
		elseif col2 then
			return col2
		elseif col1 then
			return col1
		elseif col3 then
			return col3
		end
	end
end

do
	local function SetLabelFormat(name, starttime, endtime, fmt)
		fmt = fmt or Skada.db.profile.setformat
		local namelabel = name
		if fmt < 1 or fmt > 8 then
			fmt = 3
		end

		local timelabel = ""
		if starttime and endtime and fmt > 1 then
			local duration = SecondsToTime(endtime - starttime, false, false, 2)

			if fmt == 2 then
				timelabel = duration
			elseif fmt == 3 then
				timelabel = format("%s (%s)", date("%H:%M", starttime), duration)
			elseif fmt == 4 then
				timelabel = format("%s (%s)", date("%I:%M %p", starttime), duration)
			elseif fmt == 5 then
				timelabel = format("%s - %s", date("%H:%M", starttime), date("%H:%M", endtime))
			elseif fmt == 6 then
				timelabel = format("%s - %s", date("%I:%M %p", starttime), date("%I:%M %p", endtime))
			elseif fmt == 7 then
				timelabel = format("%s - %s", date("%H:%M:%S", starttime), date("%H:%M:%S", endtime))
			elseif fmt == 8 then
				timelabel = format("%s - %s (%s)", date("%H:%M", starttime), date("%H:%M", endtime), duration)
			end
		end

		if #namelabel == 0 or #timelabel == 0 then
			return format("%s%s", namelabel, timelabel), namelabel, timelabel
		end

		return format("%s%s%s", namelabel, strmatch(timelabel, "^%p") and " " or ": ", timelabel), namelabel, timelabel
	end

	function Skada:SetLabelFormats()
		local ret, start = {}, 1631547006
		for i = 1, 8 do
			ret[i] = SetLabelFormat(L["Hogger"], start, start + 380, i)
		end
		return ret
	end

	function Skada:GetSetLabel(set)
		if not set then
			return ""
		end
		return SetLabelFormat(set.name or L.Unknown, set.starttime, set.endtime or time())
	end

	function Window:set_mode_title()
		if
			not self.db.enabletitle or -- title bar disabled
			not self.selectedmode or -- window has no selected mode
			not self.selectedmode.moduleName or -- selected mode isn't a valid mode
			not self.selectedset  -- window has no selected set
		then
			return
		end

		local name = (self.parentmode and self.parentmode.moduleName) or self.selectedmode.title or self.selectedmode.moduleName

		-- save window settings for RestoreView after reload
		self.db.set = self.selectedset
		local savemode = name
		if self.history[1] then -- can't currently preserve a nested mode, use topmost one
			savemode = self.history[1].title or self.history[1].moduleName
		end
		self.db.mode = savemode

		if self.changed and self.title then
			self.title = nil
		elseif self.title and self.title ~= name then
			name = self.title
		end

		if self.db.display == "bar" then
			-- title set enabled?
			if self.db.titleset and self.selectedmode.metadata and not self.selectedmode.metadata.notitleset then
				if self.selectedset == "current" then
					name = format("%s%s %s", name, find(name, ":") and " -" or ":", L["Current"])
				elseif self.selectedset == "total" then
					name = format("%s%s %s", name, find(name, ":") and " -" or ":", L["Total"])
				else
					local set = self:GetSelectedSet()
					if set then
						name = format("%s%s %s", name, find(name, ":") and " -" or ":", Skada:GetSetLabel(set))
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
		wipe(self.history)
		self.title = nil

		-- all all stuff that were registered by modules
		self.datakey = nil
		self.actorid, self.actorname = nil, nil
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

	local set = Skada:GetSet("current")
	if set then
		self.tooltip:AddDoubleLine(L["Skada Summary"], Skada.version)
		self.tooltip:AddLine(" ")
		self.tooltip:AddDoubleLine(L["Segment Time"], Skada:GetFormatedSetTime(set), 1, 1, 1)
		for i = 1, #modes do
			local mode = modes[i]
			if mode and mode.AddToTooltip then
				mode:AddToTooltip(set, self.tooltip)
			end
		end
		self.tooltip:AddLine(" ")
	else
		self.tooltip:AddDoubleLine("Skada", Skada.version, nil, nil, nil, 0, 1, 0)
	end

	self.tooltip:AddLine(L["|cff00ff00Left-Click|r to toggle windows."], 1, 1, 1)
	self.tooltip:AddLine(L["|cff00ff00Ctrl+Left-Click|r to show/hide windows."], 1, 1, 1)
	self.tooltip:AddLine(L["|cff00ff00Shift+Left-Click|r to reset."], 1, 1, 1)
	self.tooltip:AddLine(L["|cff00ff00Right-Click|r to open menu."], 1, 1, 1)

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

function Skada:ApplySettings(name, hidemenu)
	if type(name) == "table" and name.db and name.db.name then
		name = name.db.name
	elseif type(name) == "boolean" then
		hidemenu = name
		name = nil
	end

	-- close dropdown menus?
	if hidemenu == true then
		CloseDropDownMenus()
	end

	-- fire callback in case modules need it
	Skada.callbacks:Fire("Skada_UpdateConfig")

	for i = 1, #windows do
		local win = windows[i]
		if win and win.db and name and win.db.name == name then
			win:SetChild(win.db.child)
			win.display:ApplySettings(win)
			win:Toggle()
			Skada:UpdateDisplay(true)
			return
		elseif win and win.db then
			win:SetChild(win.db.child)
			win.display:ApplySettings(win)
		end
	end

	if (Skada.db.profile.hidesolo and not IsInGroup()) or (Skada.db.profile.hidepvp and IsInPvP()) then
		Skada:SetActive(false)
	else
		Skada:SetActive(true)

		for i = 1, #windows do
			local win = windows[i]
			if win then
				win:Toggle()
			end
		end
	end

	SetNumeralFormat(Skada.db.profile.numbersystem)
	SetValueFormat(Skada.db.profile.brackets, Skada.db.profile.separator)

	Skada:UpdateDisplay(true)
end

function Skada:ReloadSettings(win)
	if win then
		if type(win) == "string" then
			for i = 1, #windows do
				local w = windows[i]
				if w.db.name == win then
					win = w
					break
				end
			end
		end

		win:Destroy()

		for i = 1, #windows do
			if win == windows[i] then
				tremove(windows, i)
				break
			end
		end

		for i = 1, #Skada.db.profile.windows do
			local w = Skada.db.profile.windows[i]
			if w and w.name == win.db.name then
				Skada:CreateWindow(w.name, w)
				break
			end
		end
	else
		for i = 1, #windows do
			local w = windows[i]
			if w then
				w:Destroy()
			end
		end
		wipe(windows)

		for i = 1, #Skada.db.profile.windows do
			local w = Skada.db.profile.windows[i]
			if w then
				Skada:CreateWindow(w.name, w)
			end
		end

		if DBI and not DBI:IsRegistered("Skada") then
			DBI:Register("Skada", dataobj, Skada.db.profile.icon)
		end

		Skada:ClearAllIndexes()
		Skada:RefreshMMButton()
	end

	Skada.total = Skada.char.total
	Skada:ApplySettings(win)
end

-------------------------------------------------------------------------------

function Skada:ApplyBorder(frame, texture, color, thickness, padtop, padbottom, padleft, padright)
	if not frame.borderFrame then
		frame.borderFrame = CreateFrame("Frame", "$parentBorder", frame)
		frame.borderFrame:SetFrameLevel(frame:GetFrameLevel() - 1)
	end
	frame.borderFrame:SetPoint("TOPLEFT", frame, -thickness - (padleft or 0), thickness + (padtop or 0))
	frame.borderFrame:SetPoint("BOTTOMRIGHT", frame, thickness + (padright or 0), -thickness - (padbottom or 0))

	local borderbackdrop = T.get("Skada_BorderBackdrop")
	borderbackdrop.edgeFile = (texture and thickness > 0) and self:MediaFetch("border", texture) or nil
	borderbackdrop.edgeSize = thickness
	frame.borderFrame:SetBackdrop(borderbackdrop)
	T.free("Skada_BorderBackdrop", borderbackdrop)
	if color then
		frame.borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
	end
end

-------------------------------------------------------------------------------

function Skada:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SkadaDB", self.defaults, "Default")

	if type(SkadaCharDB) ~= "table" then
		SkadaCharDB = {}
	end
	self.char = SkadaCharDB
	self.char.sets = self.char.sets or {}

	-- Profiles
	local AceDBOptions = LibStub("AceDBOptions-3.0", true)
	if AceDBOptions then
		if LDS then LDS:EnhanceDatabase(self.db, "Skada") end

		self.options.args.profiles.args.general = AceDBOptions:GetOptionsTable(self.db)
		self.options.args.profiles.args.general.name = L["General"]
		self.options.args.profiles.args.general.order = 0

		if LDS then LDS:EnhanceOptions(self.options.args.profiles.args.general, self.db) end

		-- import/export profile if found.
		if self.AdvancedProfile then
			self:AdvancedProfile(self.options.args.profiles.args)
		end
	end

	self:RegisterChatCommand("skada", "Command")
	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadSettings")
	self.db.RegisterCallback(self, "OnDatabaseShutdown", "ClearAllIndexes", true)

	self:RegisterInitOptions()

	self:RegisterMedias()
	self:RegisterClasses()
	self:RegisterSchools()
	self:RegisterToast()

	-- fix setstokeep, setslimit and timemesure.
	if (self.db.profile.setstokeep or 0) > 30 then
		self.db.profile.setstokeep = 30
	end
	if not self.db.profile.setslimit then
		self.db.profile.setslimit = 15
	end
	if not self.db.profile.timemesure then
		self.db.profile.timemesure = 2
	end

	-- remove old stuff.
	if self.char.improvement then
		self.char.improvement = nil
	end
	if self.db.global.revision or self.char.revision then
		self.db.global.revision = nil
		self.char.revision = nil
	end

	self.db.global.version = self.db.global.version or 0
	self.char.version = self.char.version or 0
end

function Skada:OnEnable()
	-- well, my ID!
	self.userGUID = UnitGUID("player")

	self:ReloadSettings()
	self:RegisterComm("Skada")

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateRoster")
	self:RegisterEvent("RAID_ROSTER_UPDATE", "UpdateRoster")
	self:RegisterEvent("UNIT_PET")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckZone")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatLogEvent")
	self:RegisterEvent("UNIT_ENTERED_VEHICLE", "CheckVehicle")
	self:RegisterEvent("UNIT_EXITED_VEHICLE", "CheckVehicle")

	if self.modulelist then
		for i = 1, #self.modulelist do
			self.modulelist[i](L)
		end
		self.modulelist = nil
	end

	if _G.BigWigs then
		self:RegisterMessage("BigWigs_Message", "BigWigs")
		self.bossmod = "BigWigs"
	elseif _G.DBM and _G.DBM.EndCombat then
		self:SecureHook(DBM, "EndCombat", "DBM")
		self.bossmod = "DBM"
	elseif self.bossmod then
		self.bossmod = nil
	end

	-- SharedMedia is sometimes late, we wait few seconds then re-apply settings.
	self:ScheduleTimer("ApplySettings", 2)
	self:ScheduleTimer("CheckMemory", 3)
end

function Skada:BigWigs(_, _, event, message)
	if event == "bosskill" and message and self.current and self.current.gotboss then
		if find(lower(message), lower(self.current.mobname)) ~= nil and not self.current.success then
			self:Debug("COMBAT_BOSS_DEFEATED: BigWigs")
			self.current.success = true
			self:SendMessage("COMBAT_BOSS_DEFEATED", self.current)

			if self.tempsets then -- phases
				for i = 1, #self.tempsets do
					local set = self.tempsets[i]
					if set and not set.success then
						set.success = true
						self:SendMessage("COMBAT_BOSS_DEFEATED", set)
					end
				end
			end
		end
	end
end

function Skada:DBM(_, mod, wipe)
	if not wipe and mod and mod.combatInfo then
		local set = self.current or self.last -- just in case DBM was late.
		if set and not set.success and mod.combatInfo.name and find(lower(set.mobname), lower(mod.combatInfo.name)) ~= nil then
			self:Debug("COMBAT_BOSS_DEFEATED: DBM")
			set.success = true
			self:SendMessage("COMBAT_BOSS_DEFEATED", set)

			if self.tempsets then -- phases
				for i = 1, #self.tempsets do
					local s = self.tempsets[i]
					if s and not s.success then
						s.success = true
						self:SendMessage("COMBAT_BOSS_DEFEATED", s)
					end
				end
			end
		end
	end
end

function Skada:CheckMemory()
	if Skada.db.profile.memorycheck then
		UpdateAddOnMemoryUsage()

		local compare = 10 + (Skada.db.profile.setstokeep + Skada.db.profile.setslimit) * 2
		if GetAddOnMemoryUsage("Skada") > (compare * 1024) then
			Skada:Notify(L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."], L["Memory Check"], nil, "emergency")
		end
	end
	Skada:CleanGarbage() -- optional
end

-- this can be used to clear combat log and garbage.
-- note that "collect" isn't used because it blocks all execution for too long.
function Skada:CleanGarbage()
	CombatLogClearEntries()
	if not InCombatLockdown() then
		collectgarbage("collect")
		Skada:Debug("CleanGarbage")
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
		if target == self.userName or not IsInGroup() then return end

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

do
	local function ClearIndexes(set, mt)
		if set then
			set._playeridx = nil
			set._enemyidx = nil

			-- delete our metatables.
			if mt then
				if set.players then
					for i = 1, #set.players do
						local p = set.players[i]
						if p and p.super then
							p.super = nil
						end
					end
				end

				if set.enemies then
					for i = 1, #set.enemies do
						local e = set.enemies[i]
						if e and e.super then
							e.super = nil
						end
					end
				end
			end
		end
	end

	function Skada:ClearAllIndexes(mt)
		ClearIndexes(Skada.current, mt)
		ClearIndexes(Skada.total, mt)

		if Skada.char.sets then
			for i = 1, #Skada.char.sets do
				ClearIndexes(Skada.char.sets[i], mt)
			end
		end

		if Skada.tempsets then
			for i = 1, #Skada.tempsets do
				ClearIndexes(Skada.tempsets[i], mt)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Getters & Iterators

function Skada:GetWindows()
	return windows
end

function Skada:IterateWindows()
	return ipairs(windows)
end

function Skada:GetModes()
	return modes
end

function Skada:IterateModes()
	return ipairs(modes)
end

function Skada:GetFeeds()
	return feeds
end

function Skada:IterateFeeds()
	return pairs(feeds)
end

function Skada:GetSet(s)
	local set = nil
	if s == "current" then
		set = self.current or self.last or self.char.sets[1]
	elseif s == "total" then
		set = self.total
	else
		set = self.char.sets[s]
	end

	return self.setPrototype:Bind(set)
end

function Skada:GetSets()
	if _bound_sets then
		return self.char.sets
	end

	_bound_sets = true
	for i = 1, #self.char.sets do
		self.char.sets[i] = self.setPrototype:Bind(self.char.sets[i])
	end
	return self.char.sets
end

function Skada:IterateSets()
	return ipairs(self:GetSets())
end

-------------------------------------------------------------------------------

-- never initially registered.
function Skada:PLAYER_REGEN_ENABLED()
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	if not self.current then return end

	-- we make sure to end the segment only if:
	-- 	1. the segment was previously stopped.
	-- 	2. the player and the group aren't in combat
	if self.current.stopped or (not InCombatLockdown() and not IsGroupInCombat()) then
		self:Debug("EndSegment: PLAYER_REGEN_ENABLED")
		self:EndSegment()
	end
end

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

function Skada:NewPhase()
	if self.current and (time() - self.current.starttime) >= (self.db.profile.minsetlength or 5) then
		self.tempsets = self.tempsets or T.get("Skada_TempSegments")

		local set = CreateSet(L["Current"])
		set.mobname = self.current.mobname
		set.gotboss = self.current.gotboss
		set.started = self.current.started
		set.phase = 2 + #self.tempsets

		self.tempsets[#self.tempsets + 1] = set

		self:Printf(L["|cffffbb00%s|r - |cff00ff00Phase %s|r started."], set.mobname or L.Unknown, set.phase)
	end
end

function Skada:EndSegment()
	if not self.current then return end
	self:ClearQueueUnits()

	local curtime = time()
	ProcessSet(self.current, curtime)

	if self.tempsets then
		for i = 1, #self.tempsets do
			ProcessSet(self.tempsets[i], curtime, self.current.name)
		end
		T.free("Skada_TempSegments", self.tempsets)
	end

	-- remove players ".last" key from total segment.
	for i = 1, #self.total.players do
		if self.total.players[i] then
			self.total.players[i].last = nil
		end
	end

	self.last = self.current
	self.total.time = self.total.time + self.current.time
	self.current = nil
	CleanSets()

	for i = 1, #windows do
		local win = windows[i]
		if win then
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

			win:Toggle()
		end
	end

	self:UpdateDisplay(true)

	if update_timer then
		self:CancelTimer(update_timer, true)
		update_timer = nil
	end

	if tick_timer then
		self:CancelTimer(tick_timer, true)
		tick_timer = nil
	end

	if toggle_timer then
		self:CancelTimer(toggle_timer, true)
		toggle_timer = nil
	end

	self:ScheduleTimer("CheckMemory", 3)
end

function Skada:StopSegment(msg, phase)
	if self.current then
		local curtime = time()

		-- stop phase segment?
		if phase and self.tempsets and #self.tempsets > 0 then
			local set = self.tempsets[tonumber(phase) or 0] or self.tempsets[#self.tempsets]
			if set and not set.stopped then
				set.stopped = true
				set.endtime = curtime
				set.time = max(0.1, set.endtime - set.starttime)
				self:Printf(L["|cffffbb00%s|r - |cff00ff00Phase %s|r stopped."], set.mobname or L.Unknown, set.phase)
			end
			return
		end

		-- stop current segment?
		if not self.current.stopped then
			self.current.stopped = true
			self.current.endtime = curtime
			self.current.time = max(0.1, self.current.endtime - self.current.starttime)

			-- stop phase segments?
			if self.tempsets and not phase then
				for i = 1, #self.tempsets do
					local set = self.tempsets[i]
					if set and not set.stopped then
						set.stopped = true
						set.endtime = curtime
						set.time = max(0.1, set.endtime - set.starttime)
					end
				end
			end

			self:Print(msg or L["Segment Stopped."])
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
	end
end

function Skada:ResumeSegment(msg, phase)
	if self.current then
		-- resume phase segment?
		if phase and self.tempsets and #self.tempsets > 0 then
			local set = self.tempsets[tonumber(phase) or 0] or self.tempsets[#self.tempsets]
			if set and set.stopped then
				set.stopped = nil
				set.endtime = nil
				set.time = 0
				self:Printf(L["|cffffbb00%s|r - |cff00ff00Phase %s|r resumed."], set.mobname or L.Unknown, set.phase)
			end
			return
		end

		-- resume current segment?
		if self.current.stopped then
			self.current.stopped = nil
			self.current.endtime = nil
			self.current.time = 0

			-- resume phase segments?
			if self.tempsets and not phase then
				for i = 1, #self.tempsets do
					local set = self.tempsets[i]
					if set and set.stopped then
						set.stopped = nil
						set.endtime = nil
						set.time = 0
					end
				end
			end

			self:Print(msg or L["Segment Resumed."])
		end
	end
end

function Skada:DispatchSets(func, total, ...)
	if self.current and type(func) == "function" then
		-- record to current
		func(self.current, ...)

		-- record to total
		if total and self.total and self:CanRecordTotal(self.current) then
			func(self.total, ...)
		end

		-- record to phases
		if self.tempsets then -- phases
			for i = 1, #self.tempsets do
				local set = self.tempsets[i]
				if set and not set.stopped then
					func(set, ...)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------

do
	local tentative, tentative_handle
	local death_counter, starting_members = 0, 0

	-- list of combat events that we don't care about
	local ignored_events = {
		SPELL_AURA_APPLIED_DOSE = true,
		SPELL_AURA_REMOVED_DOSE = true,
		SPELL_CAST_START = true,
		SPELL_CAST_SUCCESS = true,
		SPELL_CAST_FAILED = true,
		SPELL_DRAIN = true,
		PARTY_KILL = true,
		SPELL_PERIODIC_DRAIN = true,
		SPELL_DISPEL_FAILED = true,
		SPELL_DURABILITY_DAMAGE = true,
		SPELL_DURABILITY_DAMAGE_ALL = true,
		ENCHANT_APPLIED = true,
		ENCHANT_REMOVED = true,
		SPELL_CREATE = true
	}

	-- events used to trigger combat for aggressive combat detection
	local trigger_events = {
		RANGE_DAMAGE = true,
		SPELL_BUILDING_DAMAGE = true,
		SPELL_DAMAGE = true,
		SPELL_PERIODIC_DAMAGE = true,
		SWING_DAMAGE = true
	}

	-- events used to count spell casts.
	local spellcast_events = {
		SPELL_CAST_START = true,
		SPELL_CAST_SUCCESS = true
	}

	-- list of registered combat log event functions.
	local combatlog_events = {}

	function Skada:RegisterForCL(...)
		local args = {...}
		if #args >= 3 then
			-- first arg must always be the callback.
			local callback = tremove(args, 1)
			if type(callback) ~= "function" then
				return
			end

			-- last arg must always be the flags table.
			local flags = tremove(args)
			if type(flags) ~= "table" then
				return
			end

			-- register events.
			for _, event in ipairs(args) do
				combatlog_events[event] = combatlog_events[event] or {}
				combatlog_events[event][#combatlog_events[event] + 1] = {func = callback, flags = flags}
			end
		end
	end

	function Skada:Tick()
		if not disabled and self.current and not InCombatLockdown() and not IsGroupInCombat() and self.instanceType ~= "pvp" and self.instanceType ~= "arena" then
			self:Debug("EndSegment: Tick")
			self:EndSegment()
		end
	end

	function Skada:StartCombat()
		death_counter = 0
		starting_members = GetNumGroupMembers()

		if tentative_handle then
			self:CancelTimer(tentative_handle, true)
			tentative_handle = nil
		end

		if update_timer then
			self:Debug("EndSegment: StartCombat")
			self:EndSegment()
		end

		self:Wipe()

		if self.current == nil then
			self:Debug("StartCombat: Segment Created!")
			self.current = CreateSet(L["Current"])
		end

		if self.total == nil then
			self.total = CreateSet(L["Total"])
			self.char.total = self.total
		end

		for i = 1, #windows do
			local win = windows[i]
			if win and win.db then
				-- combat mode switch
				if win.db.modeincombat ~= "" then
					local mymode = FindMode(win.db.modeincombat)

					if mymode ~= nil then
						if win.db.returnaftercombat then
							if win.selectedset then
								win.restore_set = win.selectedset
							end
							if win.selectedmode then
								win.restore_mode = win.selectedmode.moduleName
							end
						end

						win.selectedset = "current"
						win:DisplayMode(mymode)
					end
				end

				-- combat switch to current
				if win.db.autocurrent and win.selectedset ~= "current" then
					win:set_selected_set("current")
				end
			end

			if win and not self.db.profile.tentativecombatstart then
				win:Toggle()
			end
		end

		self:UpdateDisplay(true)

		update_timer = self:ScheduleRepeatingTimer("UpdateDisplay", self.db.profile.updatefrequency or 0.5)
		tick_timer = self:ScheduleRepeatingTimer("Tick", 1)
		if self.db.profile.tentativecombatstart then
			toggle_timer = self:ScheduleTimer("Toggle", 0.1)
		end
	end

	function Skada:CombatLogEvent(_, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		-- disabled module or test mode?
		if disabled or self.testMode then return end

		-- ignored combat event?
		if ignored_events[eventtype] and not (spellcast_events[eventtype] and self.current) then return end

		local src_is_interesting = nil
		local dst_is_interesting = nil

		if not self.current and self.db.profile.tentativecombatstart and trigger_events[eventtype] and srcName and dstName and srcGUID ~= dstGUID then
			src_is_interesting = band(srcFlags, BITMASK_GROUP) ~= 0 or (band(srcFlags, BITMASK_PETS) ~= 0 and pets[srcGUID]) or players[srcGUID]

			if eventtype ~= "SPELL_PERIODIC_DAMAGE" then
				dst_is_interesting = band(dstFlags, BITMASK_GROUP) ~= 0 or (band(dstFlags, BITMASK_PETS) ~= 0 and pets[dstGUID]) or players[dstGUID]
			end

			if src_is_interesting or dst_is_interesting then
				self.current = CreateSet(L["Current"])
				if not self.total then
					self.total = CreateSet(L["Total"])
				end

				tentative_handle = self:ScheduleTimer(function()
					tentative = nil
					tentative_handle = nil
					self.current = nil
				end, 1)
				tentative = 0
			end
		end

		-- pet summons.
		if eventtype == "SPELL_SUMMON" then
			self:SummonPet(dstGUID, dstFlags, srcGUID, srcName, srcFlags)
		end

		-- current segment created?
		if self.current then
			-- segment not yet flagged as started?
			if not self.current.started then
				self.current.started = true
				if self.instanceType == nil then self:CheckZone() end
				self.current.type = (self.instanceType == "none" and IsInGroup()) and "group" or self.instanceType
				self:SendMessage("COMBAT_PLAYER_ENTER", self.current, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
			end

			-- autostop on wipe enabled?
			if self.db.profile.autostop then
				if eventtype == "UNIT_DIED" and ((band(srcFlags, BITMASK_GROUP) ~= 0 and band(srcFlags, BITMASK_PETS) == 0) or players[srcGUID]) then
					death_counter = death_counter + 1
					-- If we reached the treshold for stopping the segment, do so.
					if death_counter > 0 and death_counter / starting_members >= 0.5 and not self.current.stopped then
						self:SendMessage("COMBAT_PLAYER_WIPE", self.current)
						self:StopSegment(L["Stopping for wipe."])
					end
				elseif eventtype == "SPELL_RESURRECT" and ((band(srcFlags, BITMASK_GROUP) ~= 0 and band(srcFlags, BITMASK_PETS) == 0) or players[srcGUID]) then
					death_counter = death_counter - 1
				end
			end

			-- check for boss fights
			if not self.current.gotboss then
				-- marking set as boss fights relies only on src_is_interesting
				if src_is_interesting and band(dstFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then
					local isboss, bossid, bossname = self:IsBoss(dstGUID)
					if isboss then
						self.current.mobname = bossname or dstName
						self.current.gotboss = bossid or true
						self.current.keep = self.db.profile.alwayskeepbosses or nil
						self:SendMessage("COMBAT_ENCOUNTER_START", self.current)
					end
				end
			-- default boss defeated event? (no DBM/BigWigs)
			elseif (eventtype == "UNIT_DIED" or eventtype == "UNIT_DESTROYED") and self.current.gotboss == GetCreatureId(dstGUID) then
				self:ScheduleTimer(BossDefeated, self.db.profile.updatefrequency or 0.5)
			end

			-- set mobname
			if not self.current.mobname then
				if self.current.type == "pvp" then
					self.current.mobname = GetInstanceInfo()
				elseif self.current.type == "arena" then
					self.current.mobname = GetInstanceInfo()
					self.current.gold = GetBattlefieldArenaFaction()
				elseif (src_is_interesting or band(srcFlags, BITMASK_GROUP) ~= 0) and band(dstFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then
					self.current.mobname = dstName
				elseif (dst_is_interesting or band(dstFlags, BITMASK_GROUP) ~= 0) and band(srcFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then
					self.current.mobname = srcName
				end
			end

			-- valid combatlog event
			if combatlog_events[eventtype] then
				if self.current.stopped then return end

				for i = 1, #combatlog_events[eventtype] do
					local mod = combatlog_events[eventtype][i]
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
						if tentative ~= nil then
							tentative = tentative + 1
							self:Debug(format("Tentative: %s (%d)", eventtype, tentative))
							if tentative == 5 then
								self:CancelTimer(tentative_handle, true)
								tentative_handle = nil
								tentative = nil
								self:Debug("StartCombat: tentative combat")
								self:StartCombat()
							end
						end

						self.current.last_action = time()
						mod.func(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
					end
				end
			end
		end
	end
end