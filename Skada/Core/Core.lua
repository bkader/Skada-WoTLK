local folder, ns = ...
local Skada = LibStub("AceAddon-3.0"):NewAddon(ns, folder, "AceEvent-3.0", "AceTimer-3.0", "AceBucket-3.0", "AceHook-3.0", "AceConsole-3.0", "AceComm-3.0", "LibCompat-1.0-Skada")
_G[folder] = ns

local ACD = LibStub("AceConfigDialog-3.0")
local ACR = LibStub("AceConfigRegistry-3.0")
local DBI = LibStub("LibDBIcon-1.0", true)

-- cache frequently used globals
local Private = ns.Private
local _G, GetAddOnMetadata = _G, GetAddOnMetadata
local TempTable, new, del, copy = Private.TempTable, Private.newTable, Private.delTable, Private.tCopy
local tsort, tinsert, tremove, wipe = table.sort, table.insert, Private.tremove, wipe
local next, pairs, type, setmetatable = next, pairs, type, setmetatable
local tonumber, tostring, strmatch, format, gsub, lower, find = tonumber, tostring, strmatch, string.format, string.gsub, string.lower, string.find
local max, min, abs = math.max, math.min, math.abs
local IsInInstance, GetInstanceInfo, GetBattlefieldArenaFaction = IsInInstance, GetInstanceInfo, GetBattlefieldArenaFaction
local InCombatLockdown, IsGroupInCombat = InCombatLockdown, Skada.IsGroupInCombat
local UnitExists, UnitGUID, UnitClass, UnitFullName = UnitExists, UnitGUID, UnitClass, Private.UnitFullName
local GameTooltip, ReloadUI, GetScreenWidth = GameTooltip, ReloadUI, GetScreenWidth
local GetSpellLink, spellnames, spellicons = GetSpellLink, Skada.spellnames, Skada.spellicons
local SecondsToTime, time, GetTime = SecondsToTime, time, GetTime
local IsInGroup, IsInRaid, IsInPvP = Skada.IsInGroup, Skada.IsInRaid, Skada.IsInPvP
local GetNumGroupMembers, GetGroupTypeAndCount = Skada.GetNumGroupMembers, Skada.GetGroupTypeAndCount
local GetCreatureId, UnitIterator, IsGroupDead = Skada.GetCreatureId, Skada.UnitIterator, Skada.IsGroupDead
local CheckDuplicate, uformat, EscapeStr = Private.CheckDuplicate, Private.uformat, Private.EscapeStr
local AddCombatant, IsPlayer, IsPet = Private.AddCombatant, Private.IsPlayer, Private.IsPet
local L, callbacks, O = Skada.Locale, Skada.callbacks, Skada.options.args
local P, G, _

local LDB = LibStub("LibDataBroker-1.1")
local dataobj = LDB:NewDataObject(folder, {
	label = folder,
	type = "data source",
	icon = Skada.logo,
	text = "n/a"
})

-- Keybindings
BINDING_HEADER_SKADA = folder
BINDING_NAME_SKADA_TOGGLE = L["Toggle Windows"]
BINDING_NAME_SKADA_SHOWHIDE = L["Show/Hide Windows"]
BINDING_NAME_SKADA_RESET = L["Reset"]
BINDING_NAME_SKADA_NEWSEGMENT = L["Start New Segment"]
BINDING_NAME_SKADA_NEWPHASE = L["Start New Phase"]
BINDING_NAME_SKADA_STOP = L["Stop"]

-- things we need
local userGUID = UnitGUID("player")
Skada.userGUID = userGUID

local userName = UnitFullName("player")
Skada.userName = userName

local _, userClass = UnitClass("player")
Skada.userClass = userClass

-- available display types
local displays = ns.displays or {}
ns.displays = displays

-- update & tick timers
local update_timer, tick_timer, toggle_timer, version_timer
local check_version, convert_version
local check_for_join_and_leave

-- list of players, pets and vehicles
local guidToClass = Private.guidToClass
local guidToName = Private.guidToName
local vehicles = {}

-- targets table used when detecting boss fights.
local _targets = nil

-- list of feeds & selected feed
local feeds, selected_feed = {}, nil

-- window prototype
local Window = ns.Window

-- lists of modules and windows
local windows = ns.windows or {}
ns.windows = windows
local modes = ns.modes or {}
ns.modes = modes

-- flags for party, instance and ovo
local was_in_party = nil

-- prototypes and references
local setPrototype = ns.setPrototype
local classcolors = ns.classcolors

-------------------------------------------------------------------------------
-- local functions.

local StartWatching = Private.StartWatching
local StopWatching = Private.StopWatching
local set_active, add_window_options
local set_window_child, set_window_mode_title
local restore_view, restore_window_view
local check_group, combat_end, combat_start

-- verifies a set
local function verify_set(mode, set)
	if not mode or not set then return end

	if mode.AddSetAttributes then
		mode:AddSetAttributes(set)
	end

	if mode.AddPlayerAttributes or mode.AddEnemyAttributes then
		local actors = set.actors
		if not actors then return end
		for _, actor in pairs(actors) do
			if actor.enemy and mode.AddEnemyAttributes then
				mode:AddEnemyAttributes(actor, set)
			elseif not actor.enemy and mode.mode.AddPlayerAttributes then
				mode:AddPlayerAttributes(actor, set)
			end
		end
	end
end

local create_set
local delete_set
do
	-- recycle sets
	local recycle_bin = setmetatable({}, {__mode = "k"})

	-- cleans a set before reusing or deleting
	local clear = Private.clearTable
	local function clean_set(set)
		if set then
			if set.actors then
				for k, v in pairs(set.actors) do
					set.actors[k] = clear(v)
					setmetatable(v, nil)
				end
			end
			setmetatable(set, nil)
		end
		return set
	end

	-- creates a new set
	-- @param 	setname 	the segment name
	-- @param 	set 		the set to override/reuse
	function create_set(setname, set)
		if set then
			Skada:Debug("create_set: Reuse", set.name, setname)
			set = clean_set(set)
		else
			Skada:Debug("create_set: New", setname)
			set = next(recycle_bin) or {}
			recycle_bin[set] = nil
		end

		-- add stuff.
		set.name = setname
		set.starttime = time()
		set.time = 0
		set.actors = wipe(set.actors or {})

		-- last alterations before returning.
		for i = 1, #modes do
			verify_set(modes[i], set)
		end

		callbacks:Fire("Skada_SetCreated", set)
		return setPrototype:Bind(set)
	end

	-- deletes a set
	function delete_set(set)
		if set then
			recycle_bin[clean_set(set)] = true
		end
		return nil
	end
end

-- prepares the given set name.
local function check_set_name(set)
	local setname = set.mobname or L["Unknown"]

	if set.phase then
		setname = format(L["%s - Phase %s"], setname, set.phase)
		set.phase = nil
	end

	if P.setnumber then
		setname = CheckDuplicate(setname, Skada.sets, "name")
	end

	set.name = setname
	return setname -- return reference.
end

-- process the given set and stores into sv.
local function process_set(set, curtime, mobname)
	if not set then
		set = delete_set(set) -- just in case
		return
	end

	curtime = curtime or time()

	-- remove any additional keys.
	set.started, set.stopped = nil, nil
	set.gotboss = set.gotboss or nil -- remove false

	if not P.onlykeepbosses or set.gotboss then
		set.mobname = mobname or set.mobname -- override name
		if set.mobname ~= nil and curtime - set.starttime >= (P.minsetlength or 5) then
			set.endtime = set.endtime or curtime
			set.time = max(1, set.endtime - set.starttime)
			set.name = check_set_name(set)

			-- always keep boss fights
			if set.gotboss and P.alwayskeepbosses then
				set.keep = true
			end

			for i = 1, #modes do
				local mode = modes[i]
				if mode and mode.SetComplete then
					mode:SetComplete(set)
				end
			end

			-- do you want to do something?
			callbacks:Fire("Skada_SetComplete", set, curtime)

			tinsert(Skada.sets, 1, set)
			Skada:Debug("Segment Saved:", set.name)
		else
			set = delete_set(set)
		end
	end

	-- the segment didn't have the chance to get saved
	if set and set.endtime == nil then
		set.endtime = curtime
		set.time = max(1, set.endtime - set.starttime)
	end
end

local function clean_sets(force)
	local numsets = 0
	local maxsets = 0
	local sets = Skada.sets

	for i = 1, #sets do
		local set = sets[i]
		if set then
			maxsets = maxsets + 1
			if not set.keep then
				numsets = numsets + 1
			end
		end
	end

	-- we trim segments without touching persistent ones.
	for i = #sets, 1, -1 do
		if (force or numsets > P.setstokeep) and not sets[i].keep then
			delete_set(tremove(sets, i))
			numsets = numsets - 1
			maxsets = maxsets - 1
		end
	end

	-- because some players may enable the "always keep boss fights" option,
	-- the amount of segments kept can grow big, so we make sure to keep
	-- the player reasonable, otherwise they'll encounter memory issues.
	while maxsets > Skada.maxsets and sets[maxsets] do
		delete_set(tremove(Skada.sets, maxsets))
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

-- returns a formmatted set time
local function formatted_set_time(set)
	return Skada:FormatTime(Skada:GetSetTime(set))
end

local dismiss_pet
do
	local function dismiss_handler(guid)
		guidToClass[guid] = nil
	end
	function dismiss_pet(guid, delay)
		if guid and guidToClass[guid] and not guidToName[guid] then
			Skada:ScheduleTimer(dismiss_handler, delay or 0.1, guid)
		end
	end
end

-------------------------------------------------------------------------------
-- Windo functions

do
	local copywindow = nil

	-- add window options
	function add_window_options(self)
		local templist = {}
		local db = self.db

		local opt = {
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
						val = val:trim()
						if val ~= db.name and val ~= "" then
							local oldname = db.name
							db.name = CheckDuplicate(val, windows, "name")
							if db.name ~= oldname then
								-- move options table
								O.windows.args[db.name] = O.windows.args[oldname]
								O.windows.args[oldname] = nil

								-- rename window frame
								for i = 1, #windows do
									local win = windows[i]
									if win and win.name == oldname then
										win.name = db.name
										break -- stop
									end
								end
							end

							Skada:ApplySettings(db.name)
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
						db.display = display
						Private.ReloadSettings()
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
							local _db = windows[i] and windows[i].db
							if _db and _db.name ~= db.name and _db.display == db.display then
								list[_db.name] = _db.name
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
								local _db = windows[i] and windows[i].db
								if _db and _db.name == copywindow and _db.display == db.display then
									copy(templist, _db, "name", "sticked", "x", "y", "point", "snapped", "child", "childmode")
									break
								end
							end
						end
						for k, v in pairs(templist) do
							db[k] = v
						end
						wipe(templist)
						Skada:ApplySettings(db.name)
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
					func = function() Skada:DeleteWindow(db.name, true) end
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
			opt.args.copywin.hidden = nil
			opt.args.copyexec.hidden = nil
			opt.args.separator2.hidden = nil
			opt.args.delete.width = nil
			opt.args.testmode.hidden = nil

			self.display:AddDisplayOptions(self, opt.args)
		else
			opt.name = function()
				return format("\124cffff0000%s\124r - %s", db.name, L["ERROR"])
			end
			opt.args.display.name = format("%s - \124cffff0000%s\124r", L["Display System"], L["ERROR"])
		end

		O.windows.args[db.name] = opt
	end

	-- fires a callback event
	function Window:Fire(event, ...)
		if self.bargroup and self.bargroup.callbacks then
			self.callbacks:Fire(event, self, ...)
		elseif self.frame and self.frame.callbacks then
			self.callbacks:Fire(event, self, ...)
		end
	end
end

-- sets the selected window as a child to the current window
function set_window_child(self, win)
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
	if self.display then
		self.display:Destroy(self)
	end

	self.name = nil
	self.display = nil
	self.parentmode = nil
	self.selectedset = nil
	self.selectedmode = nil

	local name = self.db.name or Skada.windowdefaults.name
	O.windows.args[name] = nil

	Window.del(self)
end

-- change window display
function Window:SetDisplay(name)
	if name ~= self.db.display or self.display == nil then
		if self.display then
			self.display:Destroy(self)
		end

		self.db.display = name
		self.display = displays[self.db.display]
		add_window_options(self)
	end
end

-- checks if the window can show total bar/text
local function can_show_total(win, set)
	if not P.showtotals and not win.db.showtotals then
		return false
	elseif not win.selectedmode.GetSetSummary then
		return false
	elseif win.db.display ~= "bar" and win.db.display ~= "inline" then
		return false
	elseif not set.type or set.type == "none" and set.name ~= L["Total"] then
		return false
	else
		return true
	end
end

-- tell window to update the display of its dataset, using its display provider.
function Window:UpdateDisplay()
	-- hidden window? nothing to do.
	if not self:IsShown() then
		return
	elseif self.selectedmode then
		local set = self:GetSelectedSet()
		if set then
			if self.selectedmode.Update then
				self.selectedmode:Update(self, set)
			else
				Skada:Printf("Mode \124cffffbb00%s\124r does not have an Update function!", self.selectedmode.localeName or self.selectedmode.moduleName)
			end

			if can_show_total(self, set) then
				local value, valuetext = self.selectedmode:GetSetSummary(set, self)
				if value or valuetext then
					if not value then
						value = 0
						for i = 1, #self.dataset do
							local data = self.dataset[i]
							if data and data.id then
								value = value + data.value
							end
						end
					end

					local d = self:nr(0)
					d.id = "total"
					d.label = L["Total"]
					d.text = self.class and format("%s (%s)", d.label, L[self.class]) or nil
					d.ignore = true
					d.value = value + 1 -- to be always first
					d.valuetext = valuetext or tostring(value)
					d.icon = P.moduleicons and self.selectedmode.metadata and self.selectedmode.metadata.icon or ns.logo
				end
			end
		end
	elseif self.selectedset then
		local set = self:GetSelectedSet()

		for i = 1, #modes do
			local mode = modes[i]
			if mode then
				local d = self:nr(i)

				d.id = mode.moduleName
				d.label = mode.localeName
				d.icon = P.moduleicons and mode.metadata and mode.metadata.icon or nil
				d.value = 1

				if set and mode.GetSetSummary then
					local value, valuetext = mode:GetSetSummary(set, self)
					d.valuetext = valuetext or tostring(value)
				end
			end
		end

		self.metadata.ordersort = true
		self.metadata.is_modelist = set and true or nil
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

		local sets = Skada.sets
		for i = 1, #sets do
			local set = sets[i]
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
	set_window_mode_title(self)
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
		P.hidden or
		self.db.hidden or
		((P.hidesolo or self.db.hideauto == 4) and not IsInGroup()) or
		((P.hidepvp or self.db.hideauto == 7) and IsInPvP()) or
		((P.showcombat or self.db.hideauto == 3) and not IsGroupInCombat()) or
		((P.hidecombat or self.db.hideauto == 2) and IsGroupInCombat()) or
		(self.db.hideauto == 5 and (Skada.insType == "raid" or Skada.insType == "party")) or
		(self.db.hideauto == 6 and Skada.insType ~= "raid" and Skada.insType ~= "party")
	then
		self:Hide()
	else
		self:Show()
	end
end

function Window:Wipe(changed)
	self:reset()
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

function Window:SetSelectedSet(set, step)
	if step ~= nil then
		local count = #Skada.sets
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
		restore_window_view(self)
		if self.child and (self.db.childmode == 1 or self.db.childmode == 2) then
			self.child:SetSelectedSet(set)
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
	set_window_mode_title(self)

	if self.child and (self.db.childmode == 1 or self.db.childmode == 3) then
		if self.db.childmode == 1 and self.child.selectedset ~= self.selectedset then
			self.child.selectedset = self.selectedset
			self.child.changed = true
		end
		self.child:DisplayMode(mode)
	end

	Skada:UpdateDisplay()
end

local user_sort_func
do
	local function default_sort_func(a, b)
		return a.localeName < b.localeName
	end

	function user_sort_func(a, b)
		if P.sortmodesbyusage and P.modeclicks then
			return (P.modeclicks[a.moduleName] or 0) > (P.modeclicks[b.moduleName] or 0)
		end
		return a.localeName < b.localeName
	end

	local function click_on_mode(win, id, _, button)
		if button == "LeftButton" then
			local mode = find_mode(id)
			if mode then
				if P.sortmodesbyusage then
					P.modeclicks = P.modeclicks or {}
					P.modeclicks[id] = (P.modeclicks[id] or 0) + 1
				end
				win:DisplayMode(mode)
			end
			tsort(modes, default_sort_func)
		elseif button == "RightButton" then
			win:RightClick()
		end
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
			local sets = Skada.sets
			for i = 1, #sets do
				local set = sets[i]
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

		tsort(modes, user_sort_func)
		self.metadata.click = click_on_mode
		self.metadata.maxvalue = 1
		self.changed = true
		self.display:SetTitle(self, self.metadata.title)

		if self.child then
			if self.db.childmode == 1 or self.db.childmode == 3 then
				self.child:DisplayModes(settime)
			elseif self.db.childmode == 2 then
				self.child:SetSelectedSet(self.selectedset)
			end
		end

		Skada:UpdateDisplay()
	end
end

do
	local function click_on_set(win, id, _, button)
		if button == "LeftButton" then
			local mode = find_mode(id)
			if mode then -- fix odd behavior
				win:DisplayMode(mode)
			else
				win:DisplayModes(id)
			end
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
	Skada:CloseMenus()
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
		db, isnew = new(), true
		copy(db, self.windowdefaults)

		local wins = P.windows
		wins[#wins + 1] = db
	end

	if display then
		db.display = display
	end

	db.barbgcolor = db.barbgcolor or self.windowdefaults.barbgcolor
	db.buttons = db.buttons or self.windowdefaults.buttons
	db.scale = db.scale or self.windowdefaults.scale or 1

	-- child window mode
	db.tooltippos = db.tooltippos or self.windowdefaults.tooltippos or "NONE"

	local window = Window.new()
	window.db = db

	name = CheckDuplicate(name, windows, "name")
	window.db.name = name
	window.name = name
	if G.reinstall then
		G.reinstall = nil
		window.db.mode = "Damage"
	end

	window:SetDisplay(window.db.display or "bar")
	if window.db.display and displays[window.db.display] then
		window.display:Create(window, isnew)
		windows[#windows + 1] = window
		window:DisplaySets()

		if isnew and find_mode("Damage") then
			restore_view(window, "current", "Damage")
		elseif window.db.set or window.db.mode then
			restore_view(window, window.db.set, window.db.mode)
		end
	else
		self:Printf("Window \"\124cffffbb00%s\124r\" was not loaded because its display module, \"\124cff00ff00%s\124r\" was not found.", name, window.db.display or L["Unknown"])
	end

	ACR:NotifyChange(folder)
	self:ApplySettings()
	return window
end

-- window deletion
do
	local function delete_window(name)
		for i = 1, #windows do
			local win = windows[i]
			local db = win and win.db
			if db and db.name == name then
				win:Destroy()
				tremove(windows, i)
			elseif db and db.child == name then
				db.child, db.childmode, win.child = nil, nil, nil
			end
		end

		local wins = P.windows
		for i = 1, #wins do
			local win = wins[i]
			if win and win.name == name then
				tremove(wins, i)
			elseif win and win.sticked and win.sticked[name] then
				win.sticked[name] = nil
			end
		end
	end

	function Skada:DeleteWindow(name, internal)
		if internal then
			delete_window(name)
			Skada:CloseMenus()
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
					Skada:CloseMenus()
					ACR:NotifyChange(folder)
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
	if P.hidden then
		P.hidden = false
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
	P.hidden = not P.hidden
	self:ApplySettings()
end

-- restores a view for the selected window
function restore_view(win, theset, themode)
	if theset and type(theset) == "string" and (theset == "current" or theset == "total" or theset == "last") then
		win.selectedset = theset
	elseif theset and type(theset) == "number" and theset <= #Skada.sets then
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

function set_active(enable)
	if enable and P.hidden then
		enable = false
	end

	for i = 1, #windows do
		local win = windows[i]
		local db = win and win.db
		if db and enable and not db.hidden and not win:IsShown() then
			win:Show()
		elseif db and not enable or not db.hidden and win:IsShown() then
			win:Hide()
		end
	end

	if not enable and P.hidedisables then
		if not Skada.disabled then
			Skada:Debug(format("%s \124cffff0000%s\124r", L["Data Collection"], L["DISABLED"]))
		end
		Skada.disabled = true
		StopWatching(Skada)
	else
		if Skada.disabled then
			Skada:Debug(format("%s \124cff00ff00%s\124r", L["Data Collection"], L["ENABLED"]))
		end
		Skada.disabled = nil
		StartWatching(Skada)
	end

	Skada:UpdateDisplay(true)
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

		local sets = self.sets
		for i = 1, #sets do
			verify_set(mode, sets[i])
		end

		mode.Reload = mode.Reload or reload_mode
		mode.category = category or "Other"
		modes[#modes + 1] = mode

		if selected_feed == nil and P.feed ~= "" then
			self:SetFeed(P.feed)
		end

		scan_for_columns(mode)

		local modename = mode.moduleName
		for i = 1, #windows do
			local win = windows[i]
			if win then
				if win.db and modename == win.db.mode then
					restore_view(win, win.db.set, modename)
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
-- set functions

-- deletes a set
function Skada:DeleteSet(set, index)
	local sets = self.sets

	if not (set and index) then
		for i = 1, #sets do
			local s = sets[i]
			if s and ((i == index) or (set == s)) then
				set = set or s
				index = index or i
				break
			end
		end
	end

	if set and index then
		local s = tremove(sets, index)
		callbacks:Fire("Skada_SetDeleted", index, s)
		s = delete_set(s)

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
				restore_window_view(win)
			end
		end

		self:Wipe()
		self:UpdateDisplay(true)
	end
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
		local function find_name_declension(text, actorname)
			for gender = 2, 3 do
				for decset = 1, GetNumDeclensionSets(actorname, gender) do
					local ownerName = DeclineName(actorname, gender, decset)
					if validate_pet_owner(text, ownerName) or find(text, ownerName) then
						return true
					end
				end
			end
			return false
		end

		-- attempt to get the pet's owner from tooltip
		function get_pet_owner_from_tooltip(guid)
			local set = guid and Skada.current
			local actors = set and set.actors
			if not actors then return end

			pettooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
			pettooltip:ClearLines()
			pettooltip:SetHyperlink(format("unit:%s", guid))

			-- we only need to scan the 2nd line.
			local text = _G["SkadaPetTooltipTextLeft2"] and _G["SkadaPetTooltipTextLeft2"]:GetText()
			if text and text ~= "" then
				for actorname, actor in pairs(actors) do
					local name = not actor.enemy and gsub(actorname, "%-.*", "")
					if name and ((LOCALE_ruRU and find_name_declension(text, name)) or validate_pet_owner(text, name)) then
						return actor.id, actor.name
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

	local function fix_pets_handler(guid, flag)
		local guidOrClass = guid and guidToClass[guid]
		if guidOrClass and guidToName[guidOrClass] then
			return guidOrClass, guidToName[guidOrClass]
		end

		-- flag is provided and it is mine.
		if guid and flag and Skada:IsMine(flag) then
			guidToClass[guid] = userGUID
			return userGUID, userName
		end

		-- no owner yet?
		if guid then
			-- guess the pet from roster.
			local ownerUnit = get_pet_owner_unit(guid)
			if ownerUnit then
				local ownerGUID = UnitGUID(ownerUnit)
				guidToClass[guid] = UnitGUID(ownerUnit)
				return ownerGUID, UnitFullName(ownerUnit)
			end

			-- guess the pet from tooltip.
			local ownerGUID, ownerName = get_pet_owner_from_tooltip(guid)
			if ownerGUID and ownerName then
				guidToClass[guid] = ownerGUID
				return ownerGUID, ownerName
			end
		end
	end

	function Skada:FixPets(action)
		if not action then return end
		action.petname = nil -- clear it

		-- 1: group member / true: player / false: everything else
		if IsPlayer(action.actorid, action.actorname, action.actorflags) ~= false then return end

		local ownerGUID, ownerName = fix_pets_handler(action.actorid, action.actorflags)
		if ownerGUID and ownerName then
			if P.mergepets then
				action.petname = action.actorname
				action.actorid = ownerGUID
				action.actorname = ownerName

				if action.spellid and action.petname then
					action.spellid = format("%s.%s", action.spellid, action.petname)
				end
				if action.spellname and action.petname then
					action.spellname = format("%s (%s)", action.spellname, action.petname)
				end
			else
				action.actorname = format("%s <%s>", action.actorname, ownerName)
			end
		else
			-- if for any reason we fail to find the pets, we simply
			-- adds them separately as a single entry.
			action.actorid = action.actorname
		end
	end

	function Skada:FixMyPets(guid, name, flags)
		if not IsPet(guid, flags) then
			return guid, name, flags
		end

		local ownerGUID, ownerName = fix_pets_handler(guid, flags)
		if ownerGUID and ownerName then
			return ownerGUID or guid, ownerName or name, flags
		end

		return guid, name, flags
	end

	function Skada:FixPetsName(guid, name, flags)
		local _, ownerName = self:FixMyPets(guid, name, flags)
		if ownerName and ownerName ~= name then
			return format("%s <%s>", name, ownerName)
		end
		return name
	end
end

function Skada:GetPetOwner(petGUID)
	local guidOrClass = guidToClass[petGUID]
	if guidOrClass and guidToName[guidOrClass] then
		return guidOrClass, guidToName[guidOrClass], guidToClass[guidOrClass]
	end
end

local function debug_pets()
	check_group()
	Skada:Print(L["Pets"])
	for guid, guidOrClass in pairs(guidToClass) do
		if guidToName[guidOrClass] then
			Skada:Printf("%s > %s", guid, classcolors.format(guidToClass[guidOrClass], guidToName[guidOrClass]))
		end
	end
end

-------------------------------------------------------------------------------
-- tooltip functions

-- sets the tooltip position
function Skada:SetTooltipPosition(tooltip, frame, display, win)
	local db = win and win.db
	if db and db.tooltippos and db.tooltippos ~= "NONE" then
		tooltip:SetOwner(UIParent, "ANCHOR_NONE")

		local anchor = find(db.tooltippos, "TOP") and "TOP" or "BOTTOM"
		if find(db.tooltippos, "LEFT") or find(db.tooltippos, "RIGHT") then
			anchor = format("%s%s", anchor, find(db.tooltippos, "LEFT") and "RIGHT" or "LEFT")
			tooltip:SetPoint(anchor, frame, db.tooltippos)
		elseif anchor == "TOP" then
			tooltip:SetPoint("BOTTOM", frame, anchor)
		else
			tooltip:SetPoint("TOP", frame, anchor)
		end
	elseif P.tooltippos == "default" then
		tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		tooltip:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -40, 40)
	elseif P.tooltippos == "cursor" then
		tooltip:SetOwner(frame, "ANCHOR_CURSOR")
	elseif P.tooltippos == "smart" and frame then
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

		if (frame:GetLeft() * s) < (GetScreenWidth() * 0.5) then
			tooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT")
		else
			tooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT")
		end
	else
		local anchor = find(P.tooltippos, "top") and "TOP" or "BOTTOM"
		anchor = format("%s%s", anchor, find(P.tooltippos, "left") and "RIGHT" or "LEFT")
		tooltip:SetOwner(frame, "ANCHOR_NONE")
		tooltip:SetPoint(anchor, frame, P.tooltippos)
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
	local function add_subview_lines(tooltip, win, mode, id, label)
		if not (type(mode) == "table" and mode.Update) then return end

		local set = win and win:GetSelectedSet()
		if not set then return end

		-- windows should have separate tooltip tables in order
		-- to display different numbers for same spells for example.
		win.ttwin = win.ttwin or Window.new(true)
		win.ttwin:reset()

		if mode.Enter then
			mode:Enter(win.ttwin, id, label)
		end

		-- tooltip title
		tooltip:AddLine(win.ttwin.title or mode.title or mode.localeName)

		-- mode:Update(win, set, info1)
		if mode.Tooltip then
			mode:Update(win.ttwin, set, mode:Tooltip(win.ttwin, set, id, label, tooltip))
		else
			mode:Update(win.ttwin, set)
		end

		local dataset = win.ttwin.dataset
		local num_dataset = dataset and #dataset
		if not num_dataset or num_dataset == 0 then
			return
		elseif not mode.metadata or not mode.metadata.ordersort then
			tsort(dataset, value_sort)
		end

		local nr = 0
		for i = 1, num_dataset do
			local data = dataset[i]
			if data and data.id and not data.ignore and nr < P.tooltiprows then
				nr = nr + 1
				local color = white

				if data.color then
					color = data.color
				elseif Skada.validclass[data.class] then
					color = classcolors(data.class)
				end

				local title = data.text or data.label
				if mode.metadata and mode.metadata.showspots then
					title = format("\124cffffffff%d.\124r %s", nr, title)
				end
				tooltip:AddDoubleLine(title, data.valuetext, color.r, color.g, color.b)
			elseif nr >= P.tooltiprows then
				break -- no need to continue
			end
		end

		if mode.Enter then
			tooltip:AddLine(" ")
		end
	end

	local function add_submode_lines(mode, win, id, label, tooltip)
		if mode and not Private.total_noclick(win.selectedset, mode) then
			add_subview_lines(tooltip, win, mode, id, label)
		end
	end

	local function add_click_lines(mode, label, win, t, fmt)
		if type(mode) == "function" then
			t:AddLine(uformat(fmt, label))
		elseif not Private.total_noclick(win.selectedset, mode) then
			t:AddLine(format(fmt, label or mode.localeName))
		end
	end

	function Skada:ShowTooltip(win, id, label, bar)
		if self.testMode or not P.tooltips or (bar and bar.ignore) then return end

		local md = win and win.metadata
		local t = md and GameTooltip
		if not t then return end

		if md.is_modelist and P.informativetooltips then
			t:ClearLines()
			add_subview_lines(t, win, find_mode(id), id, label)
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

			if P.informativetooltips then
				add_submode_lines(md.click1, win, id, label, t)
				add_submode_lines(md.click2, win, id, label, t)
				add_submode_lines(md.click3, win, id, label, t)
				add_submode_lines(md.click4, win, id, label, t)
			end

			if md.post_tooltip then
				local numLines = t:NumLines()
				md.post_tooltip(win, id, label, t)

				if numLines > 0 and t:NumLines() ~= numLines and hasClick then
					t:AddLine(" ")
				end
			end

			if md.click1 then
				add_click_lines(md.click1, md.click1_label, win, t, L["Click for \124cff00ff00%s\124r"])
			end
			if md.click2 then
				add_click_lines(md.click2, md.click2_label, win, t, L["Shift-Click for \124cff00ff00%s\124r"])
			end
			if md.click3 then
				add_click_lines(md.click3, md.click3_label, win, t, L["Control-Click for \124cff00ff00%s\124r"])
			end
			if md.click4 then
				add_click_lines(md.click4, md.click4_label, win, t, L["Alt-Click for \124cff00ff00%s\124r"])
			end

			t:Show()
		end
	end
end

-------------------------------------------------------------------------------
-- slash commands

local function generate_total()
	local sets = Skada.sets
	if not sets or #sets == 0 then return end

	Skada.sets[0] = create_set(L["Total"], Skada.sets[0])
	Skada.total = Skada.sets[0]

	local total = Skada.total
	total.starttime = nil
	total.endtime = nil

	for i = 1, #sets do
		local set = sets[i]
		for k, v in pairs(set) do
			if k == "starttime" and (not total.starttime or v < total.starttime) then
				total.starttime = v
			elseif k == "endtime" and (not total.endtime or v > total.endtime) then
				total.endtime = v
			elseif type(v) == "number" and k ~= "starttime" and k ~= "endtime" then
				total[k] = (total[k] or 0) + v
			end
		end

		local set_actors = set.actors
		local total_actors = total.actors

		for name, p in pairs(set_actors) do
			if not p.enemy then
				local actor = total_actors[name] or new()

				for k, v in pairs(p) do
					if (type(v) == "string" or k == "spec" or k == "flag") then
						actor[k] = actor[k] or v
					elseif type(v) == "number" then
						actor[k] = (actor[k] or 0) + v
					end
				end

				total_actors[name] = actor
			end
		end
	end

	ReloadUI()
end

local Print = Private.Print
local function slash_command(param)
	local cmd, arg1, arg2, arg3 = Skada:GetArgs(param, 4)
	cmd = (cmd and cmd ~= "") and lower(cmd) or cmd

	if cmd == "pets" then
		debug_pets()
	elseif cmd == "reset" then
		Skada:Reset(IsShiftKeyDown())
	elseif cmd == "reinstall" then
		Skada:Reinstall()
	elseif cmd == "newsegment" or cmd == "new" then
		Skada:NewSegment()
	elseif cmd == "newphase" or cmd == "phase" then
		Skada:NewPhase()
	elseif cmd == "stopsegment" or cmd == "stop" then
		Skada:StopSegment(nil, arg1)
	elseif cmd == "resumesegment" or cmd == "resume" then
		Skada:ResumeSegment(nil, arg1)
	elseif cmd == "toggle" then
		Skada:ToggleWindow()
	elseif cmd == "show" then
		if P.hidden then
			P.hidden = false
			Skada:ApplySettings()
		end
	elseif cmd == "hide" then
		if not P.hidden then
			P.hidden = true
			Skada:ApplySettings()
		end
	elseif cmd == "debug" then
		P.debug = not P.debug
		Skada:Print("Debug mode " .. (P.debug and ("\124cff00ff00" .. L["ENABLED"] .. "\124r") or ("\124cffff0000" .. L["DISABLED"] .. "\124r")))
	elseif cmd == "config" or cmd == "options" then
		Private.OpenOptions()
	elseif cmd == "memorycheck" or cmd == "memory" or cmd == "ram" then
		Skada:CheckMemory()
	elseif cmd == "import" and Skada.ProfileImport then
		Skada:ProfileImport()
	elseif cmd == "export" and Skada.ProfileExport then
		Skada:ProfileExport()
	elseif cmd == "about" or cmd == "info" then
		InterfaceOptionsFrame_OpenToCategory(folder)
	elseif cmd == "version" or cmd == "checkversion" then
		Skada:Printf("\124cffffbb00%s\124r: %s - \124cffffbb00%s\124r: %s", L["Version"], Skada.version, L["Date"], GetAddOnMetadata(folder, "X-Date"))
		check_version()
	elseif cmd == "website" or cmd == "github" then
		Skada:Printf("\124cffffbb00%s\124r", Skada.website)
	elseif cmd == "discord" then
		Skada:Printf("\124cffffbb00%s\124r", Skada.discord)
	elseif cmd == "timemesure" or cmd == "measure" then
		if P.timemesure == 2 then
			P.timemesure = 1
			Skada:Printf("%s: %s", L["Time Measure"], L["Activity Time"])
			Skada:ApplySettings()
		elseif P.timemesure == 1 then
			P.timemesure = 2
			Skada:Printf("%s: %s", L["Time Measure"], L["Effective Time"])
			Skada:ApplySettings()
		end
	elseif cmd == "numformat" then
		P.numberformat = P.numberformat + 1
		if P.numberformat > 3 then
			P.numberformat = 1
		end
		Skada:ApplySettings()
	elseif cmd == "total" or cmd == "generate" then
		generate_total()
	elseif cmd == "report" then
		if not Skada:CanReset() then
			Skada:Print(L["There is nothing to report."])
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
			Skada:Report(chan, "preset", report_mode_name, "current", num)
		else
			Skada:Print(L["Usage:"])
			Skada:Printf("%-20s", "/skada report [channel] [mode] [lines]")
		end
	else
		Skada:Print(L["Commands:"])
		Print("\124cffffaeae/skada\124r \124cffffff33report\124r [channel] [mode] [lines]")
		Print("\124cffffaeae/skada\124r \124cffffff33toggle\124r / \124cffffff33show\124r / \124cffffff33hide\124r")
		Print("\124cffffaeae/skada\124r \124cffffff33newsegment\124r / \124cffffff33newphase\124r")
		Print("\124cffffaeae/skada\124r \124cffffff33numformat\124r / \124cffffff33measure\124r")
		Print("\124cffffaeae/skada\124r \124cffffff33import\124r / \124cffffff33export\124r")
		Print("\124cffffaeae/skada\124r \124cffffff33about\124r / \124cffffff33version\124r / \124cffffff33website\124r / \124cffffff33discord\124r")
		Print("\124cffffaeae/skada\124r \124cffffff33reset\124r / \124cffffff33reinstall\124r")
		Print("\124cffffaeae/skada\124r \124cffffff33config\124r / \124cffffff33debug\124r")
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

	local GetChannelList = GetChannelList
	function Skada:Report(channel, chantype, report_mode_name, report_set_name, maxlines, window, barid)
		if chantype == "channel" then
			local list = TempTable(GetChannelList())
			for i = 1, table.getn(list) * 0.5 do
				if (P.report.channel == list[i * 2]) then
					channel = list[i * 2 - 1]
					break
				end
			end
			list:free()
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

			report_table = Window.new(true)
			report_mode:Update(report_table, report_set)
		elseif type(window) == "string" then
			for i = 1, #windows do
				local win = windows[i]
				local db = win and win.db
				if db and lower(db.name) == lower(window) then
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

		local metadata = report_table.metadata
		local dataset = report_table.dataset

		if metadata and not metadata.ordersort then
			tsort(dataset, value_id_sort)
		end

		if not report_mode then
			self:Print(L["No mode or segment selected for report."])
			return
		end

		local title = (window and window.title) or report_mode.title or report_mode.localeName
		local label = (report_mode_name == L["Improvement"]) and userName or Skada:GetSetLabel(report_set)
		self:SendChat(format(L["Skada: %s for %s:"], title, label), channel, chantype)

		maxlines = maxlines or 10
		local nr = 0
		for i = 1, #dataset do
			local data = dataset[i]
			if data and not data.ignore and ((barid and barid == data.id) or (data.id and not barid)) and nr < maxlines then
				nr = nr + 1
				label = nil

				if data.reportlabel then
					label = data.reportlabel
				elseif P.reportlinks and (data.spellid or data.hyperlink) then
					label = format("%s   %s", data.hyperlink or GetSpellLink(abs(data.spellid)) or data.label, data.valuetext)
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

		report_table, report_set, report_mode = nil, nil, nil
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
	userGUID = self.userGUID or UnitGUID("player")
	self.userGUID = userGUID

	self._Time = GetTime()
	self._time = time()

	Skada:CheckZone()
	if was_in_party == nil then
		Skada:ScheduleTimer("UpdateRoster", 1)
	end

	-- force reset for old structure
	if self.sets.sets then
		self:Reset(true)
	end

	tsort(modes, user_sort_func)
	self:ApplySettings()
end

local last_check_group
function check_group()
	-- throttle group check.
	local checkTime = GetTime()
	if not last_check_group or (checkTime - last_check_group) > 0.5 then
		last_check_group = checkTime

		wipe(guidToClass)
		wipe(guidToName)

		for unit, owner in UnitIterator() do
			AddCombatant(unit, owner)
		end
	end
end

do
	local inInstance, instanceType, isininstance, isinpvp
	local was_in_instance, was_in_pvp

	function Skada:CheckZone()
		inInstance, instanceType = IsInInstance()
		isininstance = inInstance and (instanceType == "party" or instanceType == "raid")
		isinpvp = IsInPvP()

		if isininstance and was_in_instance ~= nil and not was_in_instance and P.reset.instance ~= 1 and self:CanReset() then
			if P.reset.instance == 3 then
				self:ShowPopup(nil, true)
			else
				self:Reset()
			end
		end

		if P.hidepvp then
			if isinpvp then
				set_active(false)
			elseif was_in_pvp then
				set_active(true)
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
			if P.reset.leave == 3 and Skada:CanReset() then
				Skada:ShowPopup(nil, true)
			elseif P.reset.leave == 2 and Skada:CanReset() then
				Skada:Reset()
			end

			if P.hidesolo then
				set_active(false)
			end
		end

		if IsInGroup() and not was_in_party then
			if P.reset.join == 3 and Skada:CanReset() then
				Skada:ShowPopup(nil, true)
			elseif P.reset.join == 2 and Skada:CanReset() then
				Skada:Reset()
			end

			if P.hidesolo and not (P.hidepvp and IsInPvP()) then
				set_active(true)
			end
		end

		was_in_party = IsInGroup()
	end

	function Skada:UpdateRoster()
		check_for_join_and_leave()
		check_group()

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

		Skada:SendMessage("GROUP_ROSTER_UPDATE")
	end
end

do
	local UnitHasVehicleUI = UnitHasVehicleUI
	local ignoredUnits = {target = true, focus = true, npc = true, NPC = true, mouseover = true}

	local function get_pet_from_owner(owner)
		if owner == "player" then
			return "pet"
		elseif find(owner, "raid") then
			return gsub(owner, "raid", "raidpet")
		elseif find(owner, "party") then
			return gsub(owner, "party", "partypet")
		else
			return nil
		end
	end

	function Skada:UNIT_PET(owners)
		for owner in pairs(owners) do
			local unit = not ignoredUnits[owner] and get_pet_from_owner(owner)
			if unit and UnitExists(unit) then
				guidToClass[UnitGUID(unit)] = UnitGUID(owner)
			end
		end
	end

	local function process_check_vehicle(unit)
		local guid = unit and not ignoredUnits[unit] and UnitGUID(unit)
		if not guid or not guidToName[guid] then
			return
		elseif UnitHasVehicleUI(unit) then
			local prefix, id, suffix = strmatch(unit, "([^%d]+)([%d]*)(.*)")
			local vUnitId = format("%spet%s%s", prefix, id, suffix)
			if UnitExists(vUnitId) then
				guidToClass[UnitGUID(vUnitId)] = guid
				vehicles[guid] = UnitGUID(vUnitId)
			end
		elseif vehicles[guid] then
			-- delayed for a reason (2 x MAINMENU_SLIDETIME).
			dismiss_pet(vehicles[guid], 0.6)
		end
	end

	function Skada:CheckVehicle(units)
		for unit in pairs(units) do
			process_check_vehicle(unit)
		end
	end
end

-------------------------------------------------------------------------------

function Skada:CanReset()
	local total_actors = self.total and self.total.actors
	if total_actors and next(total_actors) then
		return true
	end

	local sets = self.sets
	for i = 1, #sets do
		local set = sets[i]
		if set and not set.keep then
			return true
		end
	end

	return false
end

function Skada:Reset(force)
	if self.testMode then return end

	if force then
		wipe(self.sets)
	elseif not self:CanReset() then
		self:Wipe()
		self:UpdateDisplay(true)
		self:Print(L["There is no data to reset."])
		return
	end

	self:Wipe()
	check_group()

	if self.current ~= nil then
		self.current = create_set(L["Current"], self.current)
	end

	if self.total ~= nil then
		self.total = create_set(L["Total"], self.total)
		self.sets[0] = self.total
	end

	self.last = nil

	clean_sets(true)

	for i = 1, #windows do
		local win = windows[i]
		if win and win.selectedset ~= "total" then
			win.selectedset = "current"
			win.changed = true
			restore_window_view(win)
		end
	end

	dataobj.text = "n/a"
	self:UpdateDisplay(true)
	self:Notify(L["All data has been reset."])
	callbacks:Fire("Skada_DataReset")
	StaticPopup_Hide("SkadaCommonConfirmDialog")
	self:CloseMenus()
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
	local function set_label_format(name, starttime, endtime, fmt, dye)
		fmt = max(1, min(8, fmt or P.setformat or 3))

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

	function set_window_mode_title(self)
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
				name = format("[%s] %s", formatted_set_time(Skada.current or Skada.last), name)
			end
		end

		self.metadata.title = name
		self.display:SetTitle(self, name)
	end
end

function restore_window_view(self, theset, themode)
	if self.history[1] then
		-- clear history and title
		wipe(self.history)
		self.title = nil

		-- all all stuff that were registered by modules
		self.actorid, self.actorname = nil, nil
		self.spellid, self.spellname = nil, nil
		self.targetid, self.targetname = nil, nil
	end

	-- force menu to close and let Skada handle the rest
	Skada:CloseMenus()
	restore_view(self, theset or self.selectedset, themode or self.db.mode)
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
		self.tooltip:AddDoubleLine(L["Segment Time"], formatted_set_time(set), 1, 1, 1)
		for i = 1, #modes do
			local mode = modes[i]
			if mode and mode.AddToTooltip then
				mode:AddToTooltip(set, self.tooltip)
			end
		end
		self.tooltip:AddLine(" ")
	else
		self.tooltip:AddDoubleLine(folder, Skada.version, nil, nil, nil, 0, 1, 0)
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
		P.hidden = not P.hidden
		Skada:ApplySettings()
	elseif button == "LeftButton" and IsShiftKeyDown() then
		Skada:ShowPopup()
	elseif button == "LeftButton" then
		Skada:ToggleWindow()
	elseif button == "RightButton" then
		Skada:OpenMenu()
	end
end

function Private.RefreshButton()
	if not DBI then return end

	DBI:Refresh(folder, Skada.data.profile.icon)
	if Skada.data.profile.icon.hide then
		DBI:Hide(folder)
	else
		DBI:Show(folder)
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
		Skada:CloseMenus()
	end

	-- fire callback in case modules need it
	callbacks:Fire("Skada_ApplySettings")

	for i = 1, #windows do
		local win = windows[i]
		local db = win and win.db
		if db and name and db.name == name then
			set_window_child(win, db.child)
			win.display:ApplySettings(win)
			win:Toggle()
			Skada:UpdateDisplay(true)
			return
		elseif db then
			set_window_child(win, db.child)
			win.display:ApplySettings(win)
		end
	end

	if (P.hidesolo and not IsInGroup()) or (P.hidepvp and IsInPvP()) then
		set_active(false)
	else
		set_active(true)

		for i = 1, #windows do
			local win = windows[i]
			if win then
				win:Toggle()
			end
		end
	end

	Private.SetNumberFormat(P.numbersystem)
	Private.SetValueFormat(P.brackets, P.separator)

	-- unset the global combat flag.
	if G.inCombat and not InCombatLockdown() and not IsGroupInCombat() then
		G.inCombat = false
	end

	Skada:UpdateDisplay(true)
end

function Private.ReloadSettings()
	for i = #windows, 1, -1 do
		local win = windows[i]
		if win and win.Destroy then
			win:Destroy()
		end
		tremove(windows, i)
	end

	-- refresh refrences
	P = Skada.data.profile
	G = Skada.data.global

	local wins = P.windows
	for i = 1, #wins do
		local win = wins[i]
		if win then
			Skada:CreateWindow(win.name, win)
		end
	end

	if DBI and not DBI:IsRegistered(folder) then
		DBI:Register(folder, dataobj, P.icon)
	end

	Private.RefreshButton()
	Skada.total = Skada.sets[0]
	Skada:ApplySettings()
end

-------------------------------------------------------------------------------

function Skada:OnInitialize()
	self.data = LibStub("AceDB-3.0"):New("SkadaDB", self.defaults, true)

	if type(SkadaCharDB) ~= "table" then
		SkadaCharDB = {}
	end

	-- Profiles
	local AceDBOptions = LibStub("AceDBOptions-3.0", true)
	if AceDBOptions then
		local LDS = LibStub("LibDualSpec-1.0", true)
		if LDS then LDS:EnhanceDatabase(self.data, folder) end

		O.profiles.args.general = AceDBOptions:GetOptionsTable(self.data)
		O.profiles.args.general.order = 0

		if LDS then LDS:EnhanceOptions(O.profiles.args.general, self.data) end

		-- import/export profile if found.
		if Private.AdvancedProfile then
			Private.AdvancedProfile(O.profiles.args)
		end
	end

	-- global references
	self.db = self.data.profile
	self.global = self.data.global

	-- local references
	P = self.data.profile
	G = self.data.global

	self:RegisterChatCommand("skada", slash_command, true) -- force flag set
	self.data.RegisterCallback(self, "OnProfileChanged", Private.ReloadSettings)
	self.data.RegisterCallback(self, "OnProfileCopied", Private.ReloadSettings)
	self.data.RegisterCallback(self, "OnProfileReset", Private.ReloadSettings)

	Private.InitOptions()
	Private.RegisterMedias()
	Private.RegisterClasses()
	Private.RegisterSchools()
	Private.RegisterToast()
	self:RegisterComms(not P.syncoff)

	-- fix things and remove others
	P.setstokeep = min(25, max(0, P.setstokeep or 0))
	P.setslimit = min(25, max(0, P.setslimit or 0))
	P.timemesure = min(2, max(1, P.timemesure or 0))
	P.totalflag = P.totalflag or 0x10
	G.version, G.revision = nil, nil

	-- sets limit
	self.maxsets = P.setstokeep + P.setslimit
	self.maxmeme = min(60, max(30, self.maxsets + 10))

	-- update references
	GetSpellLink = Private.SpellLink or GetSpellLink
	classcolors = self.classcolors

	-- early loading of modules
	self:LoadModules()
end

function Skada:SetupStorage()
	self.sets = self.sets or _G.SkadaCharDB
end

function Skada:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckZone")
	self:RegisterBucketEvent("UNIT_PET", 0.2)
	self:RegisterBucketEvent("UNIT_ENTERED_VEHICLE", 0.1, "CheckVehicle")
	self:RegisterBucketEvent("UNIT_EXITED_VEHICLE", 0.1, "CheckVehicle")
	self:RegisterBucketEvent("PARTY_MEMBERS_CHANGED", 0.2, "UpdateRoster")
	self:RegisterBucketEvent("RAID_ROSTER_UPDATE", 0.2, "UpdateRoster")
	StartWatching(self)

	-- late loading of modules
	self:LoadModules(true)

	if _G.BigWigs then
		self:RegisterMessage("BigWigs_Message", "BigWigs")
		self.bossmod = "BigWigs"
	elseif _G.DBM and _G.DBM.EndCombat then
		self:SecureHook(_G.DBM, "EndCombat", "DBM")
		self.bossmod = "DBM"
	elseif self.bossmod then
		self.bossmod = nil
	end

	self:SetupStorage()
	Private.ReloadSettings()
	self:ScheduleTimer("CheckMemory", 3)
	self:ScheduleTimer("CleanGarbage", 4)
end

local collectgarbage = collectgarbage
function Skada:CleanGarbage()
	if InCombatLockdown() then return end
	collectgarbage("collect")
	self:Debug("CleanGarbage")
end

-- called on boss defeat
local function BossDefeated()
	local set = Skada.current
	if not set or set.success then return end

	set.success = true

	-- phase segments.
	if Skada.tempsets then
		for i = 1, #Skada.tempsets do
			local s = Skada.tempsets[i]
			if s and not s.success then
				s.success = true
			end
		end
	end

	Skada:Debug("COMBAT_BOSS_DEFEATED: Skada")
	Skada:SendMessage("COMBAT_BOSS_DEFEATED", set)
end

-------------------------------------------------------------------------------
-- Getters & Iterators

function Skada:GetWindows()
	return windows
end

function Skada:GetModes()
	return modes
end

function Skada:GetFeeds()
	return feeds
end

function Skada:GetSet(s)
	local set = nil
	if s == "current" then
		set = self.current or self.last or self.sets[1]
	elseif s == "total" then
		set = self.total
	else
		set = self.sets[s]
	end

	return setPrototype:Bind(set)
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
		combat_end()
	end
end

function Skada:PLAYER_REGEN_DISABLED()
	if not self.disabled and not self.current then
		self:Debug("StartCombat: PLAYER_REGEN_DISABLED")
		combat_start()
	end
end

function Skada:NewSegment()
	if self.current then
		combat_end()
		combat_start()
	end
end

function Skada:NewPhase()
	if not self.current then return end
	self.tempsets = self.tempsets or new()

	local set = create_set(L["Current"])
	set.mobname = self.current.mobname
	set.gotboss = self.current.gotboss
	set.started = self.current.started
	set.phase = 2 + #self.tempsets

	self.tempsets[#self.tempsets + 1] = set

	self:Printf(L["\124cffffbb00%s\124r - \124cff00ff00Phase %s\124r started."], set.mobname or L["Unknown"], set.phase)
end

function combat_end()
	if not Skada.current then return end
	Private.ClearTempUnits()

	-- trigger events.
	local curtime = time()
	Skada:SendMessage("COMBAT_PLAYER_LEAVE", Skada.current, curtime)
	if Skada.current.gotboss then
		Skada:SendMessage("COMBAT_ENCOUNTER_END", Skada.current, curtime)
	end

	-- process segment
	process_set(Skada.current, curtime)

	-- process phase segments
	if Skada.tempsets then
		local setname = Skada.current.name
		for i = 1, #Skada.tempsets do
			local set = Skada.tempsets[i]
			process_set(set, curtime, setname)
		end
		Skada.tempsets = del(Skada.tempsets)
	end

	-- clear total semgnt
	if P.totalidc then
		for i = 1, #modes do
			local mode = modes[i]
			if mode and mode.SetComplete then
				mode:SetComplete(Skada.total)
			end
		end
	end

	-- remove players ".last" key from total segment.
	local actors = Skada.total and Skada.total.actors
	if actors then
		for _, actor in pairs(actors) do
			if actor.last then
				actor.last = nil
			end
		end
	end

	if Skada.current.time and Skada.current.time >= P.minsetlength then
		Skada.total.time = (Skada.total.time or 0) + Skada.current.time
	end

	Skada.last = Skada.current
	Skada.current = nil
	Skada.inCombat = false
	G.inCombat = false
	_targets = del(_targets)

	clean_sets()
	wipe(vehicles)

	for i = 1, #windows do
		local win = windows[i]
		if win then
			if win.selectedset ~= "current" and win.selectedset ~= "total" then
				win:SetSelectedSet(nil, 1) -- move to next set
			end

			win:Wipe()
			Skada.changed = true

			if win.db.wipemode ~= "" and IsGroupDead() then
				restore_window_view(win, "current", win.db.wipemode)
			elseif win.db.returnaftercombat and win.restore_mode and win.restore_set then
				if win.restore_set ~= win.selectedset or win.restore_mode ~= win.selectedmode then
					restore_window_view(win, win.restore_set, win.restore_mode)
					win.restore_mode, win.restore_set = nil, nil
				end
			end

			win:Toggle()
		end
	end

	Skada:UpdateDisplay(true)

	if update_timer then
		Skada:CancelTimer(update_timer, true)
		update_timer = nil
	end

	if tick_timer then
		Skada:CancelTimer(tick_timer, true)
		tick_timer = nil
	end

	if toggle_timer then
		Skada:CancelTimer(toggle_timer, true)
		toggle_timer = nil
	end
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

-------------------------------------------------------------------------------

do
	local tentative, tentative_set, tentative_timer
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
	function Skada:RegisterForCL(func, flags, ...)
		if func and flags then
			local index = 1
			local event = select(index, ...)

			while event do
				combatlog_events[event] = combatlog_events[event] or {}
				combatlog_events[event][func] = flags

				index = index + 1
				event = select(index, ...)
			end
		end
	end

	local function combat_tick()
		if not Skada.disabled and Skada.current and not InCombatLockdown() and not IsGroupInCombat() and Skada.insType ~= "pvp" and Skada.insType ~= "arena" then
			Skada:Debug("EndSegment: combat tick")
			combat_end()
		end
	end

	function combat_start()
		death_counter = 0
		starting_members = GetNumGroupMembers()

		if tentative_timer then
			Skada:CancelTimer(tentative_timer, true)
			tentative_timer = nil
		end

		if update_timer then
			Skada:Debug("EndSegment: StartCombat")
			combat_end()
		end

		if Skada.current == nil then
			Skada:Debug("StartCombat: Segment Created!")
			Skada.current = create_set(L["Current"], tentative_set)
		end
		tentative_set = delete_set(tentative_set)

		if Skada.total == nil then
			Skada.total = create_set(L["Total"])
			Skada.sets[0] = Skada.total
		end

		-- not yet flagged as started?
		if not Skada.current.started then
			Skada.current.started = true
			local t = Skada.LastEvent
			Skada:ScanGroupBuffs(t and t.timestamp)
			Skada:SendMessage("COMBAT_PLAYER_ENTER", Skada.current, t)
		end

		Skada.inCombat = true
		G.inCombat = true
		Skada:Wipe()

		for i = 1, #windows do
			local win = windows[i]
			local db = win and win.db
			if db then
				-- combat mode switch
				if db.modeincombat ~= "" then
					local mymode = find_mode(db.modeincombat)

					if mymode ~= nil then
						if db.returnaftercombat then
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
				if db.autocurrent and win.selectedset ~= "current" then
					win:SetSelectedSet("current")
				end
			end

			if win and not P.tentativecombatstart then
				win:Toggle()
			end
		end

		Skada:UpdateDisplay(true)

		update_timer = Skada:ScheduleRepeatingTimer("UpdateDisplay", P.updatefrequency or 0.5)
		tick_timer = Skada:ScheduleRepeatingTimer(combat_tick, 1)

		if P.tentativecombatstart then
			toggle_timer = Skada:ScheduleTimer("Toggle", 0.1)
		end
	end

	local BITMASK_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER or 0x00000100
	local HasFlag = Private.HasFlag
	local function check_boss_fight(set, t, src_is_interesting, dst_is_interesting)
		-- set mobname
		if not set.mobname then
			if Skada.insType == "pvp" or Skada.insType == "arena" then
				set.type = Skada.insType
				set.gotboss = false -- skip boss check
				set.mobname = GetInstanceInfo()
				set.faction = GetBattlefieldArenaFaction()
				if set.type == "arena" then
					Skada:SendMessage("COMBAT_ARENA_START", set, set.mobname)
				end
			elseif src_is_interesting and not t:DestIsFriendly() then
				set.mobname = t.dstName
				if HasFlag(t.dstFlags, BITMASK_CONTROL_PLAYER) then
					set.type = "pvp"
					set.gotboss = false
				end
			elseif dst_is_interesting and not t:SourceIsFriendly() then
				set.mobname = t.srcName
				if HasFlag(t.srcFlags, BITMASK_CONTROL_PLAYER) then
					set.type = "pvp"
					set.gotboss = false
				end
			end
		end

		-- set type
		if not set.type then
			if Skada.insType == nil then Skada:CheckZone() end
			set.type = (Skada.insType == "none" and IsInGroup()) and "group" or Skada.insType
		end

		-- don't go further for arena/pvp
		if set.type == "pvp" or set.type == "arena" then
			return
		end

		-- boss already detected?
		if set.gotboss then
			-- default boss defeated event? (no DBM/BigWigs)
			if not Skada.bossmod and death_events[t.event] and set.gotboss == GetCreatureId(t.dstGUID) then
				Skada:ScheduleTimer(BossDefeated, P.updatefrequency or 0.5)
			end
			return
		end

		-- marking set as boss fights relies only on src_is_interesting
		if trigger_events[t.event] and src_is_interesting and not t:DestIsFriendly() then
			if set.gotboss == nil then
				if not _targets or not _targets[t.dstName] then
					local isboss, bossid, bossname = Skada:IsEncounter(t.dstGUID, t.dstName)
					if isboss then -- found?
						set.mobname = bossname or set.mobname or t.dstName
						set.gotboss = bossid or true
						Skada:SendMessage("COMBAT_ENCOUNTER_START", set)
						_targets = del(_targets)
					else
						_targets = _targets or new()
						_targets[t.dstName] = true
						set.gotboss = false
					end
				end
			elseif _targets and not _targets[t.dstName] then
				_targets[t.dstName] = true
				set.gotboss = nil
			end
		end
	end

	local function check_autostop(set, event, src_is_interesting_nopets)
		if event == "UNIT_DIED" and src_is_interesting_nopets then
			death_counter = death_counter + 1
			-- If we reached the treshold for stopping the segment, do so.
			if death_counter >= starting_members * 0.5 and not set.stopped then
				Skada:SendMessage("COMBAT_PLAYER_WIPE", set)
				Skada:StopSegment(L["Stopping for wipe."])
			end
		elseif event == "SPELL_RESURRECT" and src_is_interesting_nopets then
			death_counter = death_counter - 1
		end
	end

	local function tentative_handler()
		tentative_set = Skada.current
		Skada.current = delete_set(Skada.current)
		Skada:CancelTimer(tentative_timer, true)
		tentative_timer = nil
		tentative = nil
	end

	function Skada:CombatLogEvent(t)
		-- ignored combat event?
		if (not t.event or ignored_events[t.event]) and not (spellcast_events[t.event] and self.current) then return end

		local src_is_interesting = nil
		local dst_is_interesting = nil

		if not self.current and trigger_events[t.event] and t.srcName and t.dstName and t.srcGUID ~= t.dstGUID then
			src_is_interesting = t:SourceInGroup()

			if t.event ~= "SPELL_PERIODIC_DAMAGE" then
				dst_is_interesting = t:DestInGroup()
			end

			if src_is_interesting or dst_is_interesting then
				self.current = create_set(L["Current"], tentative_set)
				if not self.total then
					self.total = create_set(L["Total"])
				end

				tentative_timer = self:ScheduleTimer(tentative_handler, 1)
				tentative = P.tentativecombatstart and 4 or 0

				check_boss_fight(self.current, t, src_is_interesting, dst_is_interesting)
			end
		end

		-- pet summons.
		if t.event == "SPELL_SUMMON" and t:DestIsPet(true) then
			guidToClass[t.dstGUID] = t.srcGUID
		-- pet died?
		elseif death_events[t.event] and t:SourceIsPet() then
			dismiss_pet(t.srcGUID)
		end

		-- current segment not created?
		if not self.current then return end

		-- autostop on wipe enabled?
		if P.autostop and (t.event == "UNIT_DIED" or t.event == "SPELL_RESURRECT") then
			check_autostop(self.current, t.event, t:SourceInGroup(true))
		end

		-- stopped or invalid events?
		if self.current.stopped or not combatlog_events[t.event] then return end

		self._Time = GetTime()
		self._time = time()

		for func, flags in next, combatlog_events[t.event] do
			local fail = false

			if flags.src_is_interesting_nopets then
				local src_is_interesting_nopets = t:SourceInGroup(true)

				if src_is_interesting_nopets then
					src_is_interesting = true
				else
					fail = true
				end
			end

			if not fail and flags.dst_is_interesting_nopets then
				local dst_is_interesting_nopets = t:DestInGroup(true)
				if dst_is_interesting_nopets then
					dst_is_interesting = true
				else
					fail = true
				end
			end

			if not fail and flags.src_is_interesting or flags.src_is_not_interesting then
				if not src_is_interesting then
					src_is_interesting = t:SourceInGroup() or Private.GetTempUnit(t.srcGUID)
				end

				if (flags.src_is_interesting and not src_is_interesting) or (flags.src_is_not_interesting and src_is_interesting) then
					fail = true
				end
			end

			if not fail and flags.dst_is_interesting or flags.dst_is_not_interesting then
				if not dst_is_interesting then
					dst_is_interesting = t:DestInGroup()
				end

				if (flags.dst_is_interesting and not dst_is_interesting) or (flags.dst_is_not_interesting and dst_is_interesting) then
					fail = true
				end
			end

			if not fail then
				if tentative ~= nil then
					tentative = tentative + 1
					self:Debug(format("Tentative: %s (%d)", t.event, tentative))
					if tentative >= 5 then
						self:CancelTimer(tentative_timer, true)
						tentative_timer = nil
						tentative = nil
						self:Debug("StartCombat: tentative combat")
						combat_start()
					end
				end

				func(t)
			end
		end

		check_boss_fight(self.current, t, src_is_interesting, dst_is_interesting)
	end
end
