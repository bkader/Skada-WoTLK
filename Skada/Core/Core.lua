local Skada = LibStub("AceAddon-3.0"):NewAddon("Skada", "AceEvent-3.0", "AceTimer-3.0", "AceBucket-3.0", "AceHook-3.0", "AceConsole-3.0", "AceComm-3.0", "LibCompat-1.0-Skada")
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
local Translit = LibStub("LibTranslit-1.0", true)

-- cache frequently used globlas
local tsort, tinsert, tremove, tmaxn, tconcat, wipe = table.sort, table.insert, table.remove, table.maxn, table.concat, wipe
local next, pairs, ipairs, unpack, type, setmetatable = next, pairs, ipairs, unpack, type, setmetatable
local tonumber, tostring, strmatch, format, gsub, lower, find = tonumber, tostring, strmatch, string.format, string.gsub, string.lower, string.find
local floor, max, min, abs, band, time, GetTime = math.floor, math.max, math.min, math.abs, bit.band, time, GetTime
local IsInInstance, GetInstanceInfo, GetBattlefieldArenaFaction = IsInInstance, GetInstanceInfo, GetBattlefieldArenaFaction
local InCombatLockdown, IsGroupInCombat = InCombatLockdown, Skada.IsGroupInCombat
local UnitExists, UnitGUID, UnitName, UnitClass = UnitExists, UnitGUID, UnitName, UnitClass
local GameTooltip, ReloadUI, GetScreenWidth = GameTooltip, ReloadUI, GetScreenWidth
local GetSpellInfo, GetSpellLink = GetSpellInfo, GetSpellLink
local CloseDropDownMenus, SecondsToTime = CloseDropDownMenus, SecondsToTime
local IsInGroup, IsInRaid, IsInPvP = Skada.IsInGroup, Skada.IsInRaid, Skada.IsInPvP
local GetNumGroupMembers, GetGroupTypeAndCount = Skada.GetNumGroupMembers, Skada.GetGroupTypeAndCount
local GetUnitIdFromGUID, GetUnitSpec, GetUnitRole = Skada.GetUnitIdFromGUID, Skada.GetUnitSpec, Skada.GetUnitRole
local UnitIterator, IsGroupDead = Skada.UnitIterator, Skada.IsGroupDead
local pformat, EscapeStr, GetCreatureId = Skada.pformat, Skada.EscapeStr, Skada.GetCreatureId
local T, _ = Skada.Table, nil

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
BINDING_NAME_SKADA_RESET = L["Reset"]
BINDING_NAME_SKADA_NEWSEGMENT = L["Start New Segment"]
BINDING_NAME_SKADA_NEWPHASE = L["Start New Phase"]
BINDING_NAME_SKADA_STOP = L["Stop"]

-- Skada-Revisited flag
Skada.revisited = true

-- things we need
Skada.userName = UnitName("player")
_, Skada.userClass = UnitClass("player")

-- reusable tables
local new, del, clear = Skada.TablePool("kv")
Skada.newTable, Skada.delTable, Skada.clearTable = new, del, clear

-- available display types
local displays = {}
Skada.displays = displays -- make externally available

-- update & tick timers
local update_timer, tick_timer, toggle_timer, version_timer
local check_version, convert_version
local check_for_join_and_leave

-- list of players, pets and vehicles
local players, pets, vehicles = {}, {}, {}

-- targets table used when detecting boss fights.
local _targets = nil

-- format funtions.
local set_numeral_format, set_value_format

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

-- verifies a set
local function verify_set(mode, set)
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
local function create_set(setname, set)
	if set then
		Skada:Debug("create_set: Reuse", set.name, setname)
		setmetatable(set, nil)
		for k, v in pairs(set) do
			if type(v) == "table" then
				set[k] = wipe(v)
			else
				set[k] = nil
			end
		end
	else
		Skada:Debug("create_set: New", setname)
		set = {}
	end

	-- add stuff.
	set.name = setname
	set.starttime = time()
	set.time = 0
	set.players = set.players or {}
	if setname ~= L["Total"] or Skada.db.profile.totalidc then
		set.last_action = set.starttime
		set.last_time = GetTime()
	end

	-- last alterations before returning.
	for i = 1, #modes do
		verify_set(modes[i], set)
	end

	Skada.callbacks:Fire("Skada_SetCreated", set)
	return Skada.setPrototype:Bind(set)
end

-- prepares the given set name.
local function check_set_name(set)
	local setname = set.mobname or L["Unknown"]

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
local function process_set(set, curtime, mobname)
	if not set then return end
	_bound_sets = nil -- to refresh mt

	curtime = curtime or time()

	-- remove any additional keys.
	set.started, set.stopped = nil, nil
	set.gotboss = set.gotboss or nil -- remove false

	if not Skada.db.profile.onlykeepbosses or set.gotboss then
		set.mobname = mobname or set.mobname -- override name
		if set.mobname ~= nil and curtime - set.starttime >= (Skada.db.profile.minsetlength or 5) then
			set.endtime = set.endtime or curtime
			set.time = max(1, set.endtime - set.starttime)
			set.name = check_set_name(set)

			-- always keep boss fights
			if set.gotboss and Skada.db.profile.alwayskeepbosses then
				set.keep = true
			end

			for i = 1, #modes do
				local mode = modes[i]
				if mode and mode.SetComplete then
					mode:SetComplete(set)
				end
			end

			-- do you want to do something?
			Skada.callbacks:Fire("Skada_SetComplete", set, curtime)

			tinsert(Skada.char.sets, 1, set)
			Skada:Debug("Segment Saved:", set.name)
		end
	end

	-- the segment didn't have the chance to get saved
	if set.endtime == nil then
		set.endtime = curtime
		set.time = max(1, set.endtime - set.starttime)
	end
end

local function clean_sets(force)
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
			del(tremove(Skada.char.sets, i), true)
			numsets = numsets - 1
			maxsets = maxsets - 1
		end
	end

	-- because some players may enable the "always keep boss fights" option,
	-- the amount of segments kept can grow big, so we make sure to keep
	-- the player reasonable, otherwise they'll encounter memory issues.
	while maxsets > Skada.maxsets and Skada.char.sets[maxsets] do
		del(tremove(Skada.char.sets, maxsets), true)
		maxsets = maxsets - 1
	end
end

-- finds a mode
local function find_mode(name)
	for i = 1, #modes do
		local mode = modes[i]
		if mode and (mode.moduleName == name or mode.localeName == name) then
			return mode
		end
	end
end

-------------------------------------------------------------------------------
-- Active / Effetive time functions

-- returns the selected set time.
function Skada:GetSetTime(set)
	return (set and set.time) and max(1, set.time > 0 and set.time or (time() - set.starttime)) or 0
end

-- returns a formmatted set time
function Skada:GetFormatedSetTime(set)
	return self:FormatTime(self:GetSetTime(set))
end

-- returns the actor's active/effective time
function Skada:GetActiveTime(set, actor, active)
	active = active or (set.type == "pvp") or (set.type == "arena") -- force active for pvp/arena

	-- active: actor's time.
	if (self.db.profile.timemesure ~= 2 or active) and actor.time and actor.time > 0 then
		return max(1, actor.time)
	end

	-- effective: combat time.
	return (set and set.time) and max(1, set.time > 0 and set.time or (time() - set.starttime)) or 0
end

-- updates the actor's active time
function Skada:AddActiveTime(set, actor, cond, diff)
	if actor and actor.last and cond then
		local curtime = set.last_time or GetTime()
		local delta = curtime - actor.last

		if diff and diff > 0 and diff < delta then
			delta = diff
		elseif delta > 3.5 then
			delta = 3.5
		end

		actor.last = curtime
		actor.time = (actor.time or 0) + floor(100 * delta + 0.5) / 100
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
function Skada:NewWindow(window)
	if not StaticPopupDialogs["SkadaCreateWindowDialog"] then
		local function create_window(name, win)
			name = name and name:trim()
			if not name or name == "" then return end

			if IsShiftKeyDown() and win and win.db then
				local w = Skada:CreateWindow(name, nil, win.db.display)
				Skada.tCopy(w.db, win.db, "name", "sticked", "point", "snapped", "child", "childmode")
				w.db.x, w.db.y = 0, 0
				Skada:ApplySettings(name)
			else
				Skada:CreateWindow(name)
			end
		end

		StaticPopupDialogs["SkadaCreateWindowDialog"] = {
			text = L["Enter the name for the new window."],
			button1 = L["Create"],
			button2 = L["Cancel"],
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
			EditBoxOnEnterPressed = function(self, win)
				create_window(self:GetText(), win)
				self:GetParent():Hide()
			end,
			OnAccept = function(self, win)
				create_window(self.editBox:GetText(), win)
				self:Hide()
			end
		}
	end
	StaticPopup_Show("SkadaCreateWindowDialog", nil, nil, window)
end

-- reinstall the addon
do
	local t = {timeout = 15, whileDead = 0}
	local f = function()
		if Skada.db.profiles then
			wipe(Skada.db.profiles)
		end
		if Skada.db.profileKeys then
			wipe(Skada.db.profileKeys)
		end

		Skada.db.global.reinstall = true
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
							list[name] = display.localeName
						end
						return list
					end,
					set = function(_, display)
						self.db.display = display
						Skada:ReloadSettings()
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
						local list = {[""] = L["None"]}
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
				return format("\124cffff0000%s\124r - %s", self.db.name, L["ERROR"])
			end
			options.args.display.name = format("%s - \124cffff0000%s\124r", L["Display System"], L["ERROR"])
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
	self.dataset = del(self.dataset, true)

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
	-- hidden window? nothing to do... unless update is forced!
	if not self:IsShown() and not self._forceUpdate then
		return
	elseif self.selectedmode then
		local set = self:GetSelectedSet()
		if set then
			self:UpdateInProgress()

			if self.selectedmode.Update then
				if set then
					self.selectedmode:Update(self, set)
				else
					Skada:Printf("No set available to pass to %s Update function! Try to reset Skada.", self.selectedmode.localeName or self.selectedmode.moduleName)
				end
			else
				Skada:Printf("Mode \124cffffbb00%s\124r does not have an Update function!", self.selectedmode.localeName or self.selectedmode.moduleName)
			end

			if
				(self.db.display == "bar" or self.display.display == "inline") and
				(Skada.db.profile.showtotals or self.db.showtotals) and
				self.selectedmode.GetSetSummary and
				((set.type and set.type ~= "none") or set.name == L["Total"])
			then
				local valuetext, value = self.selectedmode:GetSetSummary(set, self)
				if valuetext or value then
					local existing = nil -- an existing bar?

					if not value then
						value = 0
						for j = 1, #self.dataset do
							local data = self.dataset[j]
							if data and data.id then
								value = value + data.value
							end
							if data and not existing and not data.id then
								existing = data
							end
						end
					end
					value = value + 1

					local d = existing or {}
					d.id = "total"
					d.label = L["Total"]
					d.text = nil
					d.ignore = true
					d.value = value
					d.valuetext = valuetext or tostring(d.value)

					if Skada.db.profile.moduleicons and self.selectedmode.metadata and self.selectedmode.metadata.icon then
						d.icon = self.selectedmode.metadata.icon
					else
						d.icon = dataobj.icon
					end
					if not existing then
						tinsert(self.dataset, 1, d)
					end
				end
			end
		end
	elseif self.selectedset then
		local set = self:GetSelectedSet()

		for j = 1, #modes do
			local mode = modes[j]
			if mode then
				local d = self:nr(j)

				d.id = mode.moduleName
				d.label = mode.localeName
				d.value = 1

				if Skada.db.profile.moduleicons and mode.metadata and mode.metadata.icon then
					d.icon = mode.metadata.icon
				end

				if set and mode.GetSetSummary then
					local valuetext, value = mode:GetSetSummary(set, self)
					d.valuetext = valuetext or tostring(value)
				end
			end
		end

		self.metadata.ordersort = true

		if set then
			self.metadata.is_modelist = true
		end
	else
		local nr = 1
		local d = self:nr(nr)

		d.id = "total"
		d.label = L["Total"]
		d.value = 1

		nr = nr + 1
		d = self:nr(nr)

		d.id = "current"
		d.label = L["Current"]
		d.value = 1

		for j = 1, #Skada.char.sets do
			local set = Skada.char.sets[j]
			if set then
				nr = nr + 1
				d = self:nr(nr)

				d.id = tostring(set.starttime)
				_, d.label, d.valuetext = Skada:GetSetLabel(set)
				d.value = 1
				d.emphathize = set.keep
			end
		end

		self.metadata.ordersort = true
	end

	if not self.metadata.maxvalue then
		self.metadata.maxvalue = 0
		if self.dataset then
			for i = 1, #self.dataset do
				local data = self.dataset[i]
				if data and data.id and data.value and data.value > self.metadata.maxvalue then
					self.metadata.maxvalue = data.value
				end
			end
		end
	end

	self.changed = nil
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

function Window:IsShown()
	return self.display:IsShown(self)
end

function Window:Show()
	self.display:Show(self)
	if self.changed then
		self:UpdateDisplay()
	end
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
		(self.db.hideauto == 5 and (Skada.insType == "raid" or Skada.insType == "party")) or
		(self.db.hideauto == 6 and Skada.insType ~= "raid" and Skada.insType ~= "party")
	then
		self:Hide()
	else
		self:Show()
	end
end

-- creates or reuses a dataset table
function Window:nr(i)
	local d = self.dataset[i] or {}
	self.dataset[i] = d
	return d
end

-- generates spell's dataset
function Window:spell(d, spellid, spell, school, isheal, no_suffix)
	if d and spellid then
		-- create the dataset?
		if type(d) == "number" then
			d = self:nr(d)
		end

		if school == true then
			isheal = true
			school = nil
		end

		d.id = spellid

		if type(spellid) == "number" or not spell then
			d.spellid = spellid
			d.label, _, d.icon = GetSpellInfo(abs(d.spellid))

			if (spell and spell.ishot) and not no_suffix then
				d.label = format("%s%s", d.label, L["HoT"])
			elseif spellid < 0 and not no_suffix then
				d.label = format("%s%s", d.label, isheal and L["HoT"] or L["DoT"])
			end
			if spell and spell.school then
				d.spellschool = spell.school
			elseif school then
				d.spellschool = school
			end
			return d
		end

		if type(spell) == "table" then
			d.spellid = spell.id
			d.label = spellid
			_, _, d.icon = GetSpellInfo(abs(d.spellid))

			if spell and (spell.ishot or d.spellid < 0) and not no_suffix then
				d.label = format("%s%s", d.label, L["HoT"])
			end
			if spell and spell.school then
				d.spellschool = spell.school
			elseif school then
				d.spellschool = school
			end
			return d
		end

		-- fallback
		d.label = spellid
		d.spellschool = school
	end
	return d
end

-- generates actor's dataset
function Window:actor(d, actor, enemy, actorname)
	if d and actor then
		-- create the dataset?
		if type(d) == "number" then
			d = self:nr(d)
		end

		if type(actor) == "string" then
			d.id = actor
			d.label = actorname or actor
			return d
		end

		d.id = actor.id or actor.name or actorname
		d.label = actor.name or actorname or L["Unknown"]
		d.class = actor.class
		d.role = actor.role
		d.spec = actor.spec

		if not enemy and actor.id and d.class and Skada.validclass[d.class] then
			d.text = Skada:FormatName(actor.name or actorname, actor.id)
		elseif d.text then
			d.text = nil
		elseif not enemy and not d.class then -- fallback to pets
			d.class = "PET"
		end
	end
	return d
end

-- wipes windown's dataset table
function Window:Reset()
	if self.dataset then
		for i = 1, #self.dataset do
			if self.dataset[i] then
				wipe(self.dataset[i])
			end
		end
	end
end

function Window:Wipe(changed)
	self:Reset()
	if self.display then
		self.display:Wipe(self)
	end

	self.changed = changed or self.changed
	if self.child and self.db.childmode == 1 then
		self.child:Wipe(changed)
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
		if self.db.childmode == 1 and self.child.selectedset ~= self.selectedset then
			self.child.selectedset = self.selectedset
			self.child.changed = true
		end
		self.child:DisplayMode(mode)
	end

	Skada:UpdateDisplay()
end

do
	local function click_on_mode(win, id, _, button)
		if button == "LeftButton" then
			local mode = find_mode(id)
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

	local function default_sort_func(a, b)
		return a.name < b.name
	end

	local function sort_func(a, b)
		if Skada.db.profile.sortmodesbyusage and Skada.db.profile.modeclicks then
			return (Skada.db.profile.modeclicks[a.moduleName] or 0) > (Skada.db.profile.modeclicks[b.moduleName] or 0)
		else
			return a.moduleName < b.moduleName
		end
	end

	function Skada:SortModes()
		tsort(modes, sort_func)
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

		self.metadata.click = click_on_mode
		self.metadata.maxvalue = 1
		self.metadata.sortfunc = default_sort_func

		self.changed = true
		self.display:SetTitle(self, self.metadata.title)

		if self.child then
			if self.db.childmode == 1 or self.db.childmode == 3 then
				self.child:DisplayModes(settime)
			elseif self.db.childmode == 2 then
				self.child:set_selected_set(self.selectedset)
			end
		end

		Skada:UpdateDisplay()
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
		wipe(self.metadata)
		wipe(self.history)
		self:Wipe()

		self.selectedmode = nil
		self.selectedset = nil

		self.metadata.title = L["Skada: Fights"]
		self.display:SetTitle(self, self.metadata.title)

		self.metadata.click = click_on_set
		self.metadata.maxvalue = 1
		self.changed = true

		if self.child and self.db.childmode == 1 then
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
	name = name and name:trim() or db.name or self.windowdefaults.name
	if not name or name == "" then
		name = self.windowdefaults.name -- default
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
	if self.db.global.reinstall then
		self.db.global.reinstall = nil
		window.db.mode = "Damage"
	end

	window:SetDisplay(window.db.display or "bar")
	if window.db.display and displays[window.db.display] then
		window.display:Create(window, isnew)
		windows[#windows + 1] = window
		window:DisplaySets()

		if isnew and find_mode("Damage") then
			self:RestoreView(window, "current", "Damage")
		elseif window.db.set or window.db.mode then
			self:RestoreView(window, window.db.set, window.db.mode)
		end
	else
		self:Printf("Window \"\124cffffbb00%s\124r\" was not loaded because its display module, \"\124cff00ff00%s\124r\" was not found.", name, window.db.display or L["Unknown"])
	end

	ACR:NotifyChange("Skada")
	self:ApplySettings()
	return window
end

-- window deletion
do
	local function delete_window(name)
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
			delete_window(name)
			CloseDropDownMenus()
			return
		end

		if not StaticPopupDialogs["SkadaDeleteWindowDialog"] then
			StaticPopupDialogs["SkadaDeleteWindowDialog"] = {
				text = L["Are you sure you want to delete this window?"],
				button1 = L["Yes"],
				button2 = L["No"],
				timeout = 30,
				whileDead = 0,
				hideOnEscape = 1,
				OnAccept = function(self, data)
					CloseDropDownMenus()
					ACR:NotifyChange("Skada")
					return delete_window(data)
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

	if toggle_timer then
		self:CancelTimer(toggle_timer, true)
		toggle_timer = nil
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

	win.changed = true

	if themode then
		win:DisplayMode(find_mode(themode) or win.selectedset)
	else
		win:DisplayModes(win.selectedset)
	end
end

-- wipes all windows
function Skada:Wipe(changed)
	for i = 1, #windows do
		local win = windows[i]
		if win and win.Wipe then
			win:Wipe(changed)
		end
	end
end

function Skada:SetActive(enable)
	if enable and self.db.profile.hidden then
		enable = false
	end

	for i = 1, #windows do
		local win = windows[i]
		if win and enable and not win.db.hidden and not win:IsShown() then
			win:Show()
		elseif win and not enable or not win.db.hidden and win:IsShown() then
			win:Hide()
		end
	end

	if not enable and self.db.profile.hidedisables then
		if not self.disabled then
			self:Debug(format("%s \124cffff0000%s\124r", L["Data Collection"], L["DISABLED"]))
		end
		self.disabled = true
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		if self.disabled then
			self:Debug(format("%s \124cff00ff00%s\124r", L["Data Collection"], L["ENABLED"]))
		end
		self.disabled = nil
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatEvent")
	end

	self:UpdateDisplay(true)
end

-------------------------------------------------------------------------------
-- mode functions

do
	-- scane modes to add column options
	local function scan_for_columns(mode)
		if type(mode) == "table" and not mode.scanned then
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
				if mode.metadata.click4 then
					scan_for_columns(mode.metadata.click4)
				end
			end
		end
	end

	local function reload_mode(self)
		if self.metadata then
			for i = 1, #windows do
				local win = windows[i]
				if win and win.selectedmode == self and win.metadata then
					for key, value in pairs(self.metadata) do
						win.metadata[key] = value
					end
				end
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

		for i = 1, #self.char.sets do
			verify_set(mode, self.char.sets[i])
		end

		mode.Reload = mode.Reload or reload_mode
		mode.category = category or L["Other"]
		modes[#modes + 1] = mode

		if selected_feed == nil and self.db.profile.feed ~= "" then
			self:SetFeed(self.db.profile.feed)
		end

		scan_for_columns(mode)
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

-- when modules are created w make sure to save
-- their english "name" then localize "moduleName"
local function on_module_created(self, module)
	module.localeName = L[module.moduleName]
	module.OnModuleCreated = module.OnModuleCreated or on_module_created
end
Skada.OnModuleCreated = on_module_created

-- adds a module to the loadable modules table.
function Skada:RegisterModule(...)
	local args = new()
	for i = 1, select("#", ...) do
		args[i] = select(i, ...)
	end

	if #args >= 2 then
		-- name must always be first.
		local name = tremove(args, 1)
		if type(name) ~= "string" then
			return
		end

		-- second arg can be string (desc) or callback (init)
		local func = nil
		local desc = tremove(args, 1)
		if type(desc) == "string" then
			func = tremove(args, 1) -- func is the next arg
			desc = L[desc]
		elseif type(desc) == "function" then
			func = desc
			desc = nil
		end

		-- double check func is a callback
		if type(func) ~= "function" then
			return
		end

		local module = new()
		module.name = name
		module.func = func

		if #args > 0 then
			module.deps = new()
			for i = 1, #args do
				module.deps[i] = args[i]
				args[i] = L[args[i]] -- localize
			end

			if desc then
				desc = format("%s\n%s", desc, format(L["\124cff00ff00Requires\124r: %s"], tconcat(args, ", ")))
			else
				desc = format(L["\124cff00ff00Requires\124r: %s"], tconcat(args, ", "))
			end
		end

		self.LoadableModules = self.LoadableModules or new()
		self.LoadableModules[#self.LoadableModules + 1] = module

		self.options.args.modules.args.blocked.args[name] = {type = "toggle", name = L[name], desc = desc}
	end

	args = del(args)
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

do
	-- adds a display system
	local numorder = 80
	function Skada:AddDisplaySystem(key, mod)
		displays[key] = mod
		if mod.description then
			Skada.options.args.windows.args[format("%sdesc", key)] = {
				type = "description",
				name = format("\n\124cffffd700%s\124r:\n%s", mod.localeName, mod.description),
				fontSize = "medium",
				order = numorder
			}
			numorder = numorder + 10
		end
	end

	-- registers a loadable display system
	local cbxorder = 910
	function Skada:RegisterDisplay(name, desc, func)
		if type(desc) == "function" then
			func = desc
			desc = nil
		end

		self.LoadableDisplay = self.LoadableDisplay or new()
		self.LoadableDisplay[name] = func
		self.options.args.modules.args.blocked.args[name] = {
			type = "toggle",
			name = L[name],
			desc = desc and L[desc],
			order = cbxorder
		}
		cbxorder = cbxorder + 10
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
		local s = tremove(self.char.sets, index)
		self.callbacks:Fire("Skada_SetDeleted", index, s)
		del(s, true)

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
	if set and set.players and ((id and id ~= "total") or (name and name ~= L["Total"])) then
		id = id or name -- fallback

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

		-- search friendly enemies
		local e = self:FindEnemy(set, name, id)
		if e and e.flag and band(e.flag, COMBATLOG_OBJECT_REACTION_FRIENDLY) ~= 0 then
			set._playeridx[id] = e
			return e
		end

		-- our last hope!
		if not strict and not player then
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
			_, player.class = UnitClass(players[guid])
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
	if player.class and Skada.validclass[player.class] and (player.role == nil or player.role == "NONE" or player.spec == nil) then
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
	player.last = player.last or set.last_time or GetTime()

	self.changed = true
	self.callbacks:Fire("Skada_GetPlayer", player, set)
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
function Skada:GetEnemy(set, name, guid, flag, create)
	if not set or not name then return end -- no set and now name
	if not set.enemies and not create then return end -- no enemies table

	local enemy = self:FindEnemy(set, name, guid)
	if not enemy then
		-- should create table?
		if create and not set.enemies then
			set.enemies = {}
		end

		enemy = {id = guid or name, name = name, flag = flag}
		if guid or flag then
			enemy.class = self.unitClass(guid, flag)
		else
			enemy.class = "ENEMY"
		end

		for i = 1, #modes do
			local mode = modes[i]
			if mode and mode.AddEnemyAttributes then
				mode:AddEnemyAttributes(enemy, set)
			end
		end

		set.enemies[#set.enemies + 1] = enemy
	end

	self.changed = true
	self.callbacks:Fire("Skada_GetEnemy", enemy, set)
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
	local get_pet_owner_from_tooltip
	do
		local pettooltip = CreateFrame("GameTooltip", "SkadaPetTooltip", nil, "GameTooltipTemplate")
		local GetNumDeclensionSets, DeclineName = GetNumDeclensionSets, DeclineName

		local validate_pet_owner
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

			function validate_pet_owner(text, name)
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
		local function find_name_declension(text, playername)
			for gender = 2, 3 do
				for decset = 1, GetNumDeclensionSets(playername, gender) do
					local ownerName = DeclineName(playername, gender, decset)
					if validate_pet_owner(text, ownerName) or find(text, ownerName) then
						return true
					end
				end
			end
			return false
		end

		-- attempt to get the pet's owner from tooltip
		function get_pet_owner_from_tooltip(guid)
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
						if playername and ((LOCALE_ruRU and find_name_declension(text, playername)) or validate_pet_owner(text, playername)) then
							return p.id, p.name
						end
					end
				end
			end
		end
	end

	local function get_pet_owner_unit(guid)
		for unit, owner in UnitIterator() do
			if owner ~= nil and UnitGUID(unit) == guid then
				return owner
			end
		end
	end

	local function common_fix_pets(guid, flag)
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
			local ownerUnit = get_pet_owner_unit(guid)
			if ownerUnit then
				pets[guid] = {id = UnitGUID(ownerUnit), name = UnitName(ownerUnit)}
				return pets[guid]
			end

			-- guess the pet from tooltip.
			local ownerGUID, ownerName = get_pet_owner_from_tooltip(guid)
			if ownerGUID and ownerName then
				pets[guid] = {id = ownerGUID, name = ownerName}
				return pets[guid]
			end
		end

		return nil
	end

	function Skada:FixPets(action)
		if action and self:IsPlayer(action.playerid, action.playerflags, action.playername) == false then
			local owner = pets[action.playerid] or common_fix_pets(action.playerid, action.playerflags)

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

		local owner = common_fix_pets(playerid, playerflags)
		if owner then
			return owner.id or playerid, owner.name or playername
		end

		return playerid, playername
	end
end

function Skada:AssignPet(ownerGUID, ownerName, petGUID)
	pets[petGUID] = pets[petGUID] or new()
	pets[petGUID].id = ownerGUID
	pets[petGUID].name = ownerName
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
					pets[pet] = new()
					pets[pet].id = pets[owner.id].id
					pets[pet].name = pets[owner.id].name
					self.fixsummon = true
				end
			end
		end
	end
end

function Skada:DismissPet(petGUID, delay)
	if petGUID and pets[petGUID] then
		-- delayed for a reason (2 x MAINMENU_SLIDETIME).
		Skada:ScheduleTimer(function() pets[petGUID] = del(pets[petGUID]) end, delay or 0.6)
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
	if win and win.db.tooltippos and win.db.tooltippos ~= "NONE" then
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

local value_id_sort
do
	local function value_sort(a, b)
		if not a or a.value == nil then
			return false
		elseif not b or b.value == nil then
			return true
		elseif a.value < b.value then
			return false
		elseif a.value > b.value then
			return true
		elseif not a.label then
			return false
		elseif not b.label then
			return true
		else
			return a.label > b.label
		end
	end

	function value_id_sort(a, b)
		if not a or a.value == nil or a.id == nil then
			return false
		elseif not b or b.value == nil or b.id == nil then
			return true
		else
			return a.value > b.value
		end
	end

	local white = HIGHLIGHT_FONT_COLOR
	function Skada:AddSubviewToTooltip(tooltip, win, mode, id, label)
		if not (type(mode) == "table" and mode.Update) then return end

		-- windows should have separate tooltip tables in order
		-- to display different numbers for same spells for example.
		win.ttwin = win.ttwin or Window:New(true)
		win.ttwin:Reset()

		if mode.Enter then
			mode:Enter(win.ttwin, id, label)
		end

		mode:Update(win.ttwin, win:GetSelectedSet())

		if not mode.metadata or not mode.metadata.ordersort then
			tsort(win.ttwin.dataset, value_sort)
		end

		if #win.ttwin.dataset > 0 then
			tooltip:AddLine(win.ttwin.title or mode.title or mode.localeName)
			local nr = 0

			for i = 1, #win.ttwin.dataset do
				local data = win.ttwin.dataset[i]
				if data and data.id and not data.ignore and nr < self.db.profile.tooltiprows then
					nr = nr + 1
					local color = white

					if data.color then
						color = data.color
					elseif data.class and self.validclass[data.class] then
						color = self.classcolors(data.class)
					end

					local title = data.text or data.label
					if mode.metadata and mode.metadata.showspots then
						title = format("\124cffffffff%d.\124r %s", nr, title)
					end
					tooltip:AddDoubleLine(title, data.valuetext, color.r, color.g, color.b)
				elseif nr >= self.db.profile.tooltiprows then
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
				self:AddSubviewToTooltip(t, win, find_mode(id), id, label)
				t:Show()
			elseif md.click1 or md.click2 or md.click3 or md.click4 or md.tooltip then
				t:ClearLines()
				local hasClick = md.click1 or md.click2 or md.click3 or md.click4 or nil

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
					if md.click4 and not self:NoTotalClick(win.selectedset, md.click4) then
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

				if not self.testMode then
					if type(md.click1) == "function" then
						t:AddLine(pformat(L["Click for \124cff00ff00%s\124r"], md.click1_label))
					elseif md.click1 and not self:NoTotalClick(win.selectedset, md.click1) then
						t:AddLine(format(L["Click for \124cff00ff00%s\124r"], md.click1_label or md.click1.localeName))
					end

					if type(md.click2) == "function" then
						t:AddLine(pformat(L["Shift-Click for \124cff00ff00%s\124r"], md.click2_label))
					elseif md.click2 and not self:NoTotalClick(win.selectedset, md.click2) then
						t:AddLine(format(L["Shift-Click for \124cff00ff00%s\124r"], md.click2_label or md.click2.localeName))
					end

					if type(md.click3) == "function" then
						t:AddLine(pformat(L["Control-Click for \124cff00ff00%s\124r"], md.click3_label))
					elseif md.click3 and not self:NoTotalClick(win.selectedset, md.click3) then
						t:AddLine(format(L["Control-Click for \124cff00ff00%s\124r"], md.click3_label or md.click3.localeName))
					end

					if type(md.click4) == "function" then
						t:AddLine(pformat(L["Alt-Click for \124cff00ff00%s\124r"], md.click4_label))
					elseif md.click4 and not self:NoTotalClick(win.selectedset, md.click4) then
						t:AddLine(format(L["Alt-Click for \124cff00ff00%s\124r"], md.click4_label or md.click4.localeName))
					end
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

local function generate_total()
	if #Skada.char.sets == 0 then return end

	Skada.char.total = create_set(L["Total"], Skada.char.total)
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

function Skada:SlashCommand(param)
	local cmd, arg1, arg2, arg3 = self:GetArgs(param, 4)
	cmd = (cmd and cmd ~= "") and lower(cmd) or cmd

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
		self:Print("Debug mode " .. (self.db.profile.debug and ("\124cff00ff00" .. L["ENABLED"] .. "\124r") or ("\124cffff0000" .. L["DISABLED"] .. "\124r")))
	elseif cmd == "config" or cmd == "options" then
		self:OpenOptions()
	elseif cmd == "memorycheck" or cmd == "memory" or cmd == "ram" then
		self:CheckMemory()
	elseif cmd == "clear" or cmd == "clean" then
		self:CleanGarbage()
	elseif cmd == "import" and self.OpenImport then
		self:OpenImport()
	elseif cmd == "export" and self.ExportProfile then
		self:ExportProfile()
	elseif cmd == "about" or cmd == "info" then
		InterfaceOptionsFrame_OpenToCategory("Skada")
	elseif cmd == "version" or cmd == "checkversion" then
		self:Printf("\124cffffbb00%s\124r: %s - \124cffffbb00%s\124r: %s", L["Version"], self.version, L["Date"], GetAddOnMetadata("Skada", "X-Date"))
		check_version()
	elseif cmd == "website" or cmd == "github" then
		self:Printf("\124cffffbb00%s\124r", self.website)
	elseif cmd == "discord" then
		self:Printf("\124cffffbb00%s\124r", self.discord)
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
	elseif cmd == "total" or cmd == "generate" then
		generate_total()
	elseif cmd == "report" then
		if not self:CanReset() then
			self:Print(L["There is nothing to report."])
			return
		end

		local chan = arg1 and arg1:trim()
		local report_mode_name = arg2 or "Damage"
		local num = tonumber(arg3) or 10

		-- automatic
		if chan == "auto" and IsInGroup() then
			chan = IsInRaid() and "raid" or "party"
		end

		-- Sanity checks.
		if chan and (chan == "say" or chan == "guild" or chan == "raid" or chan == "party" or chan == "officer") and (report_mode_name and find_mode(report_mode_name)) then
			self:Report(chan, "preset", report_mode_name, "current", num)
		else
			self:Print("Usage:")
			self:Printf("%-20s", "/skada report [channel] [mode] [lines]")
		end
	else
		self:Print(L["Usage:"])
		print("\124cffffaeae/skada\124r \124cffffff33report\124r [channel] [mode] [lines]")
		print("\124cffffaeae/skada\124r \124cffffff33toggle\124r / \124cffffff33show\124r / \124cffffff33hide\124r")
		print("\124cffffaeae/skada\124r \124cffffff33newsegment\124r / \124cffffff33newphase\124r")
		print("\124cffffaeae/skada\124r \124cffffff33numformat\124r / \124cffffff33measure\124r")
		print("\124cffffaeae/skada\124r \124cffffff33import\124r / \124cffffff33export\124r")
		print("\124cffffaeae/skada\124r \124cffffff33about\124r / \124cffffff33version\124r / \124cffffff33website\124r / \124cffffff33discord\124r")
		print("\124cffffaeae/skada\124r \124cffffff33reset\124r / \124cffffff33clean\124r / \124cffffff33reinstall\124r")
		print("\124cffffaeae/skada\124r \124cffffff33config\124r / \124cffffff33debug\124r")
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
			elseif Skada.insType == "pvp" or Skada.insType == "arena" then
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
			report_mode = find_mode(report_mode_name or "Damage")
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
			tsort(report_table.dataset, value_id_sort)
		end

		if not report_mode then
			self:Print(L["No mode or segment selected for report."])
			return
		end

		local title = (window and window.title) or report_mode.title or report_mode.localeName
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
					label = format("%s   %s", data.hyperlink or self.GetSpellLink(abs(data.spellid)) or data.label, data.valuetext)
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
	local version = convert_version(self.version)
	if version ~= self.db.global.version then
		self.callbacks:Fire("Skada_UpdateCore", self.db.global.version, version)
		self.db.global.version = version
	end

	-- character-specific addon version
	if version ~= self.char.version then
		if (version - self.char.version) >= 3 or (version - self.char.version) <= -3 then
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
	if lastCheckGroup and (checkTime - lastCheckGroup) <= 0.5 then
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
	Skada.userSpec = GetUnitSpec("player", Skada.userClass) or Skada.userSpec
	Skada.userRole = GetUnitRole("player", Skada.userClass) or Skada.userRole
end

do
	local inInstance, instanceType, isininstance, isinpvp
	local was_in_instance, was_in_pvp

	function Skada:CheckZone()
		inInstance, instanceType = IsInInstance()
		isininstance = inInstance and (instanceType == "party" or instanceType == "raid")
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

		if self.insType == "arena" and instanceType ~= "arena" then
			self:SendMessage("COMBAT_ARENA_END")
		elseif self.insType ~= instanceType then
			self:SendMessage("ZONE_TYPE_CHANGED", instanceType, self.insType)
		end
		self.insType = instanceType

		was_in_instance = (isininstance == true)
		was_in_pvp = (isinpvp == true)
		self:Toggle()
	end
end

do
	local version_count = 0

	function check_version()
		Skada:SendComm(nil, nil, "VersionCheck", Skada.version)
		if version_timer then
			Skada:CancelTimer(version_timer, true)
			version_timer = nil
		end
	end

	function convert_version(ver)
		return tonumber(type(ver) == "string" and gsub(ver, "%.", "", 2) or ver) or 0
	end

	function Skada:VersionCheck(sender, version)
		if sender and version then
			version = convert_version(version)
			local ver = convert_version(self.version)
			if not (version and ver) or self.versionChecked then
				return
			elseif version > ver then
				self:Printf(L["Skada is out of date. You can download the newest version from \124cffffbb00%s\124r"], self.website)
			elseif version < ver then
				self:SendComm("WHISPER", sender, "VersionCheck", self.version)
			end

			self.versionChecked = true
		end
	end

	function check_for_join_and_leave()
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
		check_for_join_and_leave()
		Skada:CheckGroup()

		-- version check
		local t, _, count = GetGroupTypeAndCount()
		if t == "party" then
			count = count + 1
		end

		if count ~= version_count then
			if count > 1 and count > version_count then
				version_timer = version_timer or Skada:ScheduleTimer(check_version, 10)
			end
			version_count = count
		end

		Skada:SendMessage("GROUP_ROSTER_UPDATE", players, pets)
	end
end

do
	local UnitHasVehicleUI = UnitHasVehicleUI
	local ignoredUnits = {target = true, focus = true, npc = true, NPC = true, mouseover = true}

	function Skada:UNIT_PET(_, unit)
		if unit and not ignoredUnits[unit] then
			self:CheckGroup()
		end
	end

	function Skada:CheckVehicle(_, unit)
		if unit and not ignoredUnits[unit] then
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
		self:Wipe()
		self:UpdateDisplay(true)
		self:Print(L["There is no data to reset."])
		return
	end

	self:Wipe()
	self:CheckGroup()

	if self.current ~= nil then
		self.current = create_set(L["Current"], self.current)
	end

	if self.total ~= nil then
		self.total = create_set(L["Total"], self.total)
		self.char.total = self.total
	end

	self.last = nil

	clean_sets(true)

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
	self.callbacks:Fire("Skada_DataReset")
	self:CleanGarbage()
	StaticPopup_Hide("SkadaCommonConfirmDialog")
	CloseDropDownMenus()
end

function Skada:UpdateDisplay(force)
	self.changed = self.changed or force

	if type(selected_feed) == "function" then
		local feedtext = selected_feed()
		if feedtext then
			dataobj.text = feedtext
		end
	end

	for i = 1, #windows do
		local win = windows[i]
		if win and (self.changed or win.changed or (self.current and (win.selectedset == "current" or win.selectedset == "total"))) then
			win:UpdateDisplay()
		end
	end

	self.changed = nil
end

-------------------------------------------------------------------------------
-- format functions

do
	local reverse = string.reverse
	local numbersystem = nil
	function set_numeral_format(system)
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

function Skada:FormatTime(sec, alt, ...)
	if sec then
		if alt then
			return SecondsToTime(sec, ...)
		elseif sec >= 3600 then
			local h = floor(sec / 3600)
			local m = floor(sec / 60 - (h * 60))
			local s = floor(sec - h * 3600 - m * 60 + 0.5)
			return format("%02.f:%02.f:%02.f", h, m, s)
		else
			return format("%02.f:%02.f", floor(sec / 60), floor(sec % 60 + 0.5))
		end
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
	local separators = {"%s, %s", "%s. %s", "%s; %s", "%s - %s", "%s \124\124 %s", "%s / %s", "%s \\ %s", "%s ~ %s", "%s %s"}

	-- formats default values
	local format_2 = "%s (%s)"
	local format_3 = "%s (%s, %s)"

	function set_value_format(bracket, separator)
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
	local function set_label_format(name, starttime, endtime, fmt, dye)
		fmt = max(1, min(8, fmt or Skada.db.profile.setformat or 3))

		local namelabel, timelabel = name or L["Unknown"], ""
		if starttime and endtime and fmt > 1 then
			local duration = SecondsToTime(endtime - starttime, false, false, 2)

			if fmt == 2 then
				timelabel = dye and format("\124cffffff00%s\124r", duration) or duration
			elseif fmt == 3 then
				timelabel = format(dye and "%s \124cffffff00(%s)\124r" or "%s (%s)", date("%H:%M", starttime), duration)
			elseif fmt == 4 then
				timelabel = format(dye and "%s \124cffffff00(%s)\124r" or "%s (%s)", date("%I:%M %p", starttime), duration)
			elseif fmt == 5 then
				timelabel = format(dye and "\124cffffff00%s - %s\124r" or "%s - %s", date("%H:%M", starttime), date("%H:%M", endtime))
			elseif fmt == 6 then
				timelabel = format(dye and "\124cffffff00%s - %s\124r" or "%s - %s", date("%I:%M %p", starttime), date("%I:%M %p", endtime))
			elseif fmt == 7 then
				timelabel = format(dye and "\124cffffff00%s - %s\124r" or "%s - %s", date("%H:%M:%S", starttime), date("%H:%M:%S", endtime))
			elseif fmt == 8 then
				timelabel = format(dye and "\124cffffff00%s - %s\124r \124cffffff00(%s)\124r" or "%s - %s (%s)", date("%H:%M", starttime), date("%H:%M", endtime), duration)
			end
		end

		if #namelabel == 0 or #timelabel == 0 then
			return format("%s%s", namelabel, timelabel), namelabel, timelabel
		elseif strmatch(timelabel, "^%p") then
			return format("%s %s", namelabel, timelabel), namelabel, timelabel
		else
			return format("%s: %s", namelabel, timelabel), namelabel, timelabel
		end
	end

	function Skada:SetLabelFormats()
		local ret, start = {}, 1631547006
		for i = 1, 8 do
			ret[i] = set_label_format(L["Hogger"], start, start + 380, i)
		end
		return ret
	end

	function Skada:GetSetLabel(set, dye)
		if not set then return "" end
		return set_label_format(set.name, set.starttime, set.endtime or time(), nil, dye)
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

		local name = self.selectedmode.title or self.selectedmode.localeName
		local savemode = self.selectedmode.moduleName

		if self.parentmode then
			name = self.selectedmode.localeName or name
			savemode = self.selectedmode.moduleName or savemode
		end

		-- save window settings for RestoreView after reload
		self.db.set = self.selectedset
		if self.history[1] then -- can't currently preserve a nested mode, use topmost one
			savemode = self.history[1].moduleName or savemode
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
		self._forceUpdate = nil
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

	self.tooltip:AddLine(L["\124cff00ff00Left-Click\124r to toggle windows."], 1, 1, 1)
	self.tooltip:AddLine(L["\124cff00ff00Ctrl+Left-Click\124r to show/hide windows."], 1, 1, 1)
	self.tooltip:AddLine(L["\124cff00ff00Shift+Left-Click\124r to reset."], 1, 1, 1)
	self.tooltip:AddLine(L["\124cff00ff00Right-Click\124r to open menu."], 1, 1, 1)

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
	Skada.callbacks:Fire("Skada_ApplySettings")

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

	set_numeral_format(Skada.db.profile.numbersystem)
	set_value_format(Skada.db.profile.brackets, Skada.db.profile.separator)

	Skada:UpdateDisplay(true)
end

function Skada:ReloadSettings()
	for i = 1, #windows do
		local win = windows[i]
		if win and win.Destroy then
			win:Destroy()
		end
	end
	wipe(windows)

	for i = 1, #self.db.profile.windows do
		local win = self.db.profile.windows[i]
		if win then
			self:CreateWindow(win.name, win)
		end
	end

	if DBI and not DBI:IsRegistered("Skada") then
		DBI:Register("Skada", dataobj, self.db.profile.icon)
	end

	self:ClearAllIndexes()
	self:RefreshMMButton()
	self.total = self.char.total
	self:ApplySettings()
end

-------------------------------------------------------------------------------

function Skada:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("SkadaDB", self.defaults, "Default")

	if type(SkadaCharDB) ~= "table" then
		SkadaCharDB = {}
	end

	-- Profiles
	local AceDBOptions = LibStub("AceDBOptions-3.0", true)
	if AceDBOptions then
		local LDS = LibStub("LibDualSpec-1.0", true)
		if LDS then LDS:EnhanceDatabase(self.db, "Skada") end

		self.options.args.profiles.args.general = AceDBOptions:GetOptionsTable(self.db)
		self.options.args.profiles.args.general.order = 0

		if LDS then LDS:EnhanceOptions(self.options.args.profiles.args.general, self.db) end

		-- import/export profile if found.
		if self.AdvancedProfile then
			self:AdvancedProfile(self.options.args.profiles.args)
		end
	end

	self:RegisterChatCommand("skada", "SlashCommand", true) -- force flag set
	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadSettings")
	self.db.RegisterCallback(self, "OnDatabaseShutdown", "ClearAllIndexes")

	self:RegisterInitOptions()
	self:RegisterMedias()
	self:RegisterClasses()
	self:RegisterSchools()
	self:RegisterToast()
	self:RegisterComms(not self.db.profile.syncoff)

	if self.LoadableDisplay then
		for name, func in pairs(self.LoadableDisplay) do
			if not self:IsDisabled(name) then
				func(L, self.db.profile, self.db.global, self.cacheTable, new, del, clear)
			end
		end
		self.LoadableDisplay = del(self.LoadableDisplay)
	end

	-- fix setstokeep, setslimit and timemesure and remove old stuff
	self.db.profile.setstokeep = min(25, max(0, self.db.profile.setstokeep or 0))
	self.db.profile.setslimit = min(25, max(0, self.db.profile.setslimit or 0))
	self.db.profile.timemesure = min(2, max(1, self.db.profile.timemesure or 0))
	self.db.global.revision = nil

	-- store the version
	self.db.global.version = self.db.global.version or 0

	-- sets limit
	self.maxsets = self.db.profile.setstokeep + self.db.profile.setslimit
	self.maxmeme = min(60, max(30, self.maxsets + 10))

	-- use our custom functions
	GetSpellInfo = self.GetSpellInfo or GetSpellInfo
	GetSpellLink = self.GetSpellLink or GetSpellLink
end

function Skada:SetupStorage()
	self.char = self.char or SkadaCharDB
	self.char.sets = self.char.sets or {}

	-- remove old stuff.
	if self.char.improvement then
		self.char.improvement = nil
	end
	if self.char.revision then
		self.char.revision = nil
	end
	self.char.version = self.char.version or 0
end

function Skada:OnEnable()
	self.userGUID = self.userGUID or UnitGUID("player")

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("UNIT_PET")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckZone")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatEvent")
	self:RegisterEvent("UNIT_ENTERED_VEHICLE", "CheckVehicle")
	self:RegisterEvent("UNIT_EXITED_VEHICLE", "CheckVehicle")
	self:RegisterBucketEvent({"PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE"}, 0.25, "UpdateRoster")

	if self.LoadableModules then
		for i = 1, #self.LoadableModules do
			local mod = self.LoadableModules[i]
			if mod.name and mod.func and not self:IsDisabled(mod.name) and not (mod.deps and self:IsDisabled(unpack(mod.deps))) then
				mod.func(L, self.db.profile, self.db.global, self.cacheTable, new, del, clear)
			end
		end
		self.LoadableModules = del(self.LoadableModules, true)
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

	self:SetupStorage()
	self:ReloadSettings()

	-- SharedMedia is sometimes late, we wait few seconds then re-apply settings.
	self:ScheduleTimer("ApplySettings", 2)
	self:ScheduleTimer("CheckMemory", 3)
end

-- called on boss defeat
function Skada:BossDefeated()
	if self.current and not self.current.success then
		self.current.success = true

		-- phase segments.
		if self.tempsets then
			for i = 1, #self.tempsets do
				local set = self.tempsets[i]
				if set and not set.success then
					set.success = true
				end
			end
		end

		self:Debug("COMBAT_BOSS_DEFEATED: Skada")
		self:SendMessage("COMBAT_BOSS_DEFEATED", self.current)
	end
end

function Skada:BigWigs(_, _, event, message)
	if event == "bosskill" and message and self.current and self.current.gotboss then
		if find(lower(message), lower(self.current.mobname)) ~= nil and not self.current.success then
			self.current.success = true

			if self.tempsets then -- phases
				for i = 1, #self.tempsets do
					local set = self.tempsets[i]
					if set and not set.success then
						set.success = true
					end
				end
			end

			self:Debug("COMBAT_BOSS_DEFEATED: BigWigs")
			self:SendMessage("COMBAT_BOSS_DEFEATED", self.current)
		end
	end
end

function Skada:DBM(_, mod, wipe)
	if not wipe and mod and mod.combatInfo then
		local set = self.current or self.last -- just in case DBM was late.
		if set and not set.success and mod.combatInfo.name and (not set.mobname or find(lower(set.mobname), lower(mod.combatInfo.name)) ~= nil) then
			set.success = true
			set.gotboss = set.gotboss or mod.combatInfo.creatureId or true
			set.mobname = (not set.mobname or set.mobname == L["Unknown"]) and mod.combatInfo.name or set.mobname

			if self.tempsets then -- phases
				for i = 1, #self.tempsets do
					local s = self.tempsets[i]
					if s and not s.success then
						s.success = true
						s.gotboss = s.gotboss or mod.combatInfo.creatureId or true
						s.mobname = (not s.mobname or s.mobname == L["Unknown"]) and mod.combatInfo.name or s.mobname
					end
				end
			end

			self:Debug("COMBAT_BOSS_DEFEATED: DBM")
			self:SendMessage("COMBAT_BOSS_DEFEATED", set)
		end
	end
end

function Skada:CheckMemory(clean)
	self:CleanGarbage() -- collect garbage first.

	if self.db.profile.memorycheck then
		UpdateAddOnMemoryUsage()
		local memory = GetAddOnMemoryUsage("Skada")
		if memory > (self.maxmeme * 1024) then
			self:Notify(L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."], L["Memory Check"], nil, "emergency")
		end
	end
end

-- this can be used to clear combat log and garbage.
-- note that "collect" isn't used because it blocks all execution for too long.
function Skada:CleanGarbage()
	if self.db.profile.memorycheck and not InCombatLockdown() then
		collectgarbage("collect")
		self:Debug("CleanGarbage")
	end
end

-------------------------------------------------------------------------------

do
	local function clear_indexes(set)
		if set then
			set._playeridx = nil
			set._enemyidx = nil
		end
	end

	function Skada:ClearAllIndexes()
		clear_indexes(Skada.current)
		clear_indexes(Skada.total)

		if Skada.char.sets then
			for i = 1, #Skada.char.sets do
				clear_indexes(Skada.char.sets[i])
			end
		end

		if Skada.tempsets then
			for i = 1, #Skada.tempsets do
				clear_indexes(Skada.tempsets[i])
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
	if not self.disabled and not self.current then
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

		local set = create_set(L["Current"])
		set.mobname = self.current.mobname
		set.gotboss = self.current.gotboss
		set.started = self.current.started
		set.phase = 2 + #self.tempsets

		self.tempsets[#self.tempsets + 1] = set

		self:Printf(L["\124cffffbb00%s\124r - \124cff00ff00Phase %s\124r started."], set.mobname or L["Unknown"], set.phase)
	end
end

function Skada:EndSegment()
	if not self.current then return end
	self:ClearQueueUnits()

	-- trigger events.
	local curtime = time()
	Skada:SendMessage("COMBAT_PLAYER_LEAVE", self.current, curtime)
	if self.current.gotboss then
		Skada:SendMessage("COMBAT_ENCOUNTER_END", self.current, curtime)
	end

	-- process segment
	process_set(self.current, curtime)

	-- process phase segments
	if self.tempsets then
		for i = 1, #self.tempsets do
			process_set(self.tempsets[i], curtime, self.current.name)
		end
		T.free("Skada_TempSegments", self.tempsets)
	end

	-- clear total semgnt
	if self.db.profile.totalidc then
		for i = 1, #modes do
			local mode = modes[i]
			if mode and mode.SetComplete then
				mode:SetComplete(self.total)
			end
		end
	end

	-- remove players ".last" key from total segment.
	for i = 1, #self.total.players do
		if self.total.players[i] then
			self.total.players[i].last = nil
		end
	end

	if self.current.time >= self.db.profile.minsetlength then
		self.total.time = self.total.time + self.current.time
	end

	self.last = self.current
	self.current = nil
	self.inCombat = nil
	_targets = del(_targets)

	clean_sets()

	for i = 1, #windows do
		local win = windows[i]
		if win then
			if win.selectedset ~= "current" and win.selectedset ~= "total" then
				win:set_selected_set(nil, 1) -- move to next set
			end

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

	self:ScheduleTimer("CleanGarbage", 5)
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
				set.time = max(1, set.endtime - set.starttime)
				self:Printf(L["\124cffffbb00%s\124r - \124cff00ff00Phase %s\124r stopped."], set.mobname or L["Unknown"], set.phase)
			end
			return
		end

		-- stop current segment?
		if not self.current.stopped then
			self.current.stopped = true
			self.current.endtime = curtime
			self.current.time = max(1, self.current.endtime - self.current.starttime)

			-- stop phase segments?
			if self.tempsets and not phase then
				for i = 1, #self.tempsets do
					local set = self.tempsets[i]
					if set and not set.stopped then
						set.stopped = true
						set.endtime = curtime
						set.time = max(1, set.endtime - set.starttime)
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
				self:Printf(L["\124cffffbb00%s\124r - \124cff00ff00Phase %s\124r resumed."], set.mobname or L["Unknown"], set.phase)
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

function Skada:DispatchSets(func, ...)
	if self.current and type(func) == "function" then
		-- record to current
		func(self.current, ...)

		-- record to total
		if self:CanRecordTotal(self.current) then
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

	-- events used to trigger deaths
	local death_events = {
		UNIT_DIED = true,
		UNIT_DESTROYED = true,
		UNIT_DISSIPATES = true
	}

	-- list of registered combat log event functions.
	local combatlog_events = {}

	function Skada:RegisterForCL(...)
		local args = new()
		for i = 1, select("#", ...) do
			args[i] = select(i, ...)
		end

		if #args >= 3 then
			-- first arg must always be the callback.
			local callback = tremove(args, 1)
			if type(callback) ~= "function" then
				args = del(args)
				return
			end

			-- last arg must always be the flags table.
			local flags = tremove(args)
			if type(flags) ~= "table" then
				args = del(args)
				return
			end

			-- register events.
			for _, event in ipairs(args) do
				combatlog_events[event] = combatlog_events[event] or {}
				combatlog_events[event][callback] = flags
			end

		end

		args = del(args)
	end

	function Skada:Tick()
		self.inCombat = true
		if not self.disabled and self.current and not InCombatLockdown() and not IsGroupInCombat() and self.insType ~= "pvp" and self.insType ~= "arena" then
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
			self.current = create_set(L["Current"])
		end

		if self.total == nil then
			self.total = create_set(L["Total"])
			self.char.total = self.total
		end

		for i = 1, #windows do
			local win = windows[i]
			if win and win.db then
				-- combat mode switch
				if win.db.modeincombat ~= "" then
					local mymode = find_mode(win.db.modeincombat)

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

	function Skada:OnCombatEvent(_, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		-- disabled or test mode?
		if self.disabled or self.testMode then return end

		return self:CombatLogEvent(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	end

	function Skada:CombatLogEvent(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)

		-- ignored combat event?
		if (not eventtype or ignored_events[eventtype]) and not (spellcast_events[eventtype] and self.current) then return end

		local src_is_interesting = nil
		local dst_is_interesting = nil

		if not self.current and self.db.profile.tentativecombatstart and trigger_events[eventtype] and srcName and dstName and srcGUID ~= dstGUID then
			src_is_interesting = band(srcFlags, BITMASK_GROUP) ~= 0 or (band(srcFlags, BITMASK_PETS) ~= 0 and pets[srcGUID]) or players[srcGUID]

			if eventtype ~= "SPELL_PERIODIC_DAMAGE" then
				dst_is_interesting = band(dstFlags, BITMASK_GROUP) ~= 0 or (band(dstFlags, BITMASK_PETS) ~= 0 and pets[dstGUID]) or players[dstGUID]
			end

			if src_is_interesting or dst_is_interesting then
				self.current = create_set(L["Current"])
				if not self.total then
					self.total = create_set(L["Total"])
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
				if self.insType == nil then self:CheckZone() end
				self.current.type = (self.insType == "none" and IsInGroup()) and "group" or self.insType
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

			-- valid combatlog event
			if combatlog_events[eventtype] then
				if self.current.stopped then return end

				self.current.last_action = time()
				self.current.last_time = GetTime()

				if self.db.profile.totalidc then -- add to total segment
					self.total.last_action = self.current.last_action
					self.total.last_time = self.current.last_time
				end

				if self.tempsets then -- add to phases
					for j = 1, #self.tempsets do
						local set = self.tempsets[j]
						if set and not set.stopped then
							set.last_action = self.current.last_action
							set.last_time = self.current.last_time
						end
					end
				end

				for func, flags in next, combatlog_events[eventtype] do
					local fail = false

					if flags.src_is_interesting_nopets then
						local src_is_interesting_nopets = (band(srcFlags, BITMASK_GROUP) ~= 0 and band(srcFlags, BITMASK_PETS) == 0) or players[srcGUID]

						if src_is_interesting_nopets then
							src_is_interesting = true
						else
							fail = true
						end
					end

					if not fail and flags.dst_is_interesting_nopets then
						local dst_is_interesting_nopets = (band(dstFlags, BITMASK_GROUP) ~= 0 and band(dstFlags, BITMASK_PETS) == 0) or players[dstGUID]
						if dst_is_interesting_nopets then
							dst_is_interesting = true
						else
							fail = true
						end
					end

					if not fail and flags.src_is_interesting or flags.src_is_not_interesting then
						if not src_is_interesting then
							src_is_interesting = band(srcFlags, BITMASK_GROUP) ~= 0 or (band(srcFlags, BITMASK_PETS) ~= 0 and pets[srcGUID]) or players[srcGUID] or self:IsQueuedUnit(srcGUID)
						end

						if (flags.src_is_interesting and not src_is_interesting) or (flags.src_is_not_interesting and src_is_interesting) then
							fail = true
						end
					end

					if not fail and flags.dst_is_interesting or flags.dst_is_not_interesting then
						if not dst_is_interesting then
							dst_is_interesting = band(dstFlags, BITMASK_GROUP) ~= 0 or (band(dstFlags, BITMASK_PETS) ~= 0 and pets[dstGUID]) or players[dstGUID]
						end

						if (flags.dst_is_interesting and not dst_is_interesting) or (flags.dst_is_not_interesting and dst_is_interesting) then
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

						func(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
					end
				end
			end

			-- set mobname
			if not self.current.mobname then
				if self.current.type == "pvp" then
					self.current.gotboss = false -- skip boss check
					self.current.mobname = GetInstanceInfo()
				elseif self.current.type == "arena" then
					self.current.gotboss = false -- skip boss check
					self.current.mobname = GetInstanceInfo()
					self.current.gold = GetBattlefieldArenaFaction()
					self:SendMessage("COMBAT_ARENA_START", self.current, self.current.mobname)
				elseif src_is_interesting and band(dstFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then
					self.current.mobname = dstName
				elseif dst_is_interesting and band(srcFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then
					self.current.mobname = srcName
				end
			end

			-- check for boss fights
			if not self.current.gotboss and not spellcast_events[eventtype] then
				-- marking set as boss fights relies only on src_is_interesting
				if src_is_interesting and band(dstFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then
					if self.current.gotboss == nil then
						if not _targets or not _targets[dstName] then
							local isboss, bossid, bossname = self:IsEncounter(dstGUID, dstName)
							if isboss then -- found?
								self.current.mobname = bossname or dstName
								self.current.gotboss = bossid or true
								self:SendMessage("COMBAT_ENCOUNTER_START", self.current)
								_targets = del(_targets)
							else
								_targets = _targets or new()
								_targets[dstName] = true
								self.current.gotboss = false
							end
						end
					elseif _targets and not _targets[dstName] then
						_targets = _targets or new()
						_targets[dstName] = true
						self.current.gotboss = nil
					end
				end
			-- default boss defeated event? (no DBM/BigWigs)
			elseif not self.bossmod and self.current.gotboss and death_events[eventtype] and self.current.gotboss == GetCreatureId(dstGUID) then
				self:ScheduleTimer("BossDefeated", self.db.profile.updatefrequency or 0.5)
			end
		end
	end
end
