local folder, ns = ...
local private = ns.private

local Skada = LibStub("AceAddon-3.0"):NewAddon(ns, folder, "AceEvent-3.0", "AceTimer-3.0", "AceBucket-3.0", "AceHook-3.0", "AceConsole-3.0", "AceComm-3.0", "LibCompat-1.0-Skada")
Skada.callbacks = Skada.callbacks or LibStub("CallbackHandler-1.0"):New(Skada)
_G[folder] = ns

local L = LibStub("AceLocale-3.0"):GetLocale(folder)
local ACD = LibStub("AceConfigDialog-3.0")
local ACR = LibStub("AceConfigRegistry-3.0")
local DBI = LibStub("LibDBIcon-1.0", true)
local Translit = LibStub("LibTranslit-1.0", true)

-- cache frequently used globals
local _G, GetAddOnMetadata = _G, GetAddOnMetadata
local new, del = private.newTable, private.delTable
local tsort, tinsert, tremove, tconcat, wipe = table.sort, table.insert, private.tremove, table.concat, wipe
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
local GetUnitSpec, GetUnitRole = Skada.GetUnitSpec, Skada.GetUnitRole
local UnitIterator, IsGroupDead = Skada.UnitIterator, Skada.IsGroupDead
local uformat, EscapeStr, GetCreatureId = private.uformat, private.EscapeStr, Skada.GetCreatureId
local T, P, G = Skada.Table, nil, nil
local _

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

local userName = UnitName("player")
Skada.userName = userName

local _, userClass = UnitClass("player")
Skada.userClass = userClass

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

-- bitmasks
local BITMASK_MINE = private.BITMASK_MINE
local BITMASK_GROUP = private.BITMASK_GROUP
local BITMASK_PETS = private.BITMASK_PETS
local BITMASK_FRIENDLY = private.BITMASK_FRIENDLY
local BITMASK_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400

-------------------------------------------------------------------------------
-- local functions.

local set_active, start_watching, stop_watching
local new_window, reset_window, add_window_options
local set_window_child, set_window_mode_title
local restore_view, restore_window_view
local sort_modes, check_group
local combat_end, combat_start

-- verifies a set
local function verify_set(mode, set)
	if not mode or not set then return end

	if mode.AddSetAttributes then
		mode:AddSetAttributes(set)
	end

	local actors = mode.AddPlayerAttributes and set.players -- players
	if actors then
		for i = 1, #actors do
			mode:AddPlayerAttributes(actors[i], set)
		end
	end

	actors = mode.AddEnemyAttributes and set.enemies -- enemies
	if actors then
		for i = 1, #actors do
			mode:AddEnemyAttributes(actors[i], set)
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
	if setname ~= L["Total"] or P.totalidc then
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

	if P.setnumber then
		local num = 0
		local sets = Skada.char.sets

		for i = 1, #sets do
			local s = sets[i]
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
	local numsets = 0
	local maxsets = 0
	local sets = Skada.char.sets

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
			del(tremove(sets, i), true)
			numsets = numsets - 1
			maxsets = maxsets - 1
		end
	end

	-- because some players may enable the "always keep boss fights" option,
	-- the amount of segments kept can grow big, so we make sure to keep
	-- the player reasonable, otherwise they'll encounter memory issues.
	while maxsets > Skada.maxsets and sets[maxsets] do
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

-- returns a formmatted set time
local function formatted_set_time(set)
	return Skada:FormatTime(Skada:GetSetTime(set))
end

local function assign_pet(ownerGUID, ownerName, petGUID)
	pets[petGUID] = pets[petGUID] or new()
	pets[petGUID].id = ownerGUID
	pets[petGUID].name = ownerName
end

local dismiss_pet
do
	local function dismiss_handler(petGUID)
		pets[petGUID] = del(pets[petGUID])
	end

	function dismiss_pet(guid, delay)
		if not guid or not pets[guid] then return end
		Skada:ScheduleTimer(dismiss_handler, delay or 0.1, guid)
	end
end

-------------------------------------------------------------------------------
-- Windo functions

local Window = {}
do
	local window_mt = {__index = Window}
	local copywindow = nil

	-- create a new window
	function new_window(ttwin)
		local win = {}

		win.dataset = {}
		if not ttwin then -- regular window?
			win.metadata = {}
			win.history = {}
		end

		return setmetatable(win, window_mt)
	end

	-- add window options
	function add_window_options(self)
		local templist = {}
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
						val = val:trim()
						if val ~= db.name and val ~= "" then
							local oldname = db.name

							-- avoid duplicate names
							local num = 0
							for i = 1, #windows do
								local _db = windows[i] and windows[i].db
								local win = windows[i]
								if _db and _db.name == val and num == 0 then
									num = 1
								elseif _db then
									local n, c = strmatch(_db.name, "^(.-)%s*%((%d+)%)$")
									if n == val then
										num = max(num, tonumber(c) or 0)
									end
								end
							end
							if num > 0 then
								val = format("%s (%s)", val, num + 1)
							end

							db.name = val
							Skada.options.args.windows.args[val] = Skada.options.args.windows.args[oldname]
							Skada.options.args.windows.args[oldname] = nil
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
						private.reload_settings()
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
									private.tCopy(templist, _db, "name", "sticked", "x", "y", "point", "snapped", "child", "childmode")
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
			options.args.copywin.hidden = nil
			options.args.copyexec.hidden = nil
			options.args.separator2.hidden = nil
			options.args.delete.width = nil
			options.args.testmode.hidden = nil

			self.display:AddDisplayOptions(self, options.args)
		else
			options.name = function()
				return format("\124cffff0000%s\124r - %s", db.name, L["ERROR"])
			end
			options.args.display.name = format("%s - \124cffff0000%s\124r", L["Display System"], L["ERROR"])
		end

		Skada.options.args.windows.args[db.name] = options
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
		add_window_options(self)
	end
end

-- called before dataset is updated.
local function update_in_progress(self)
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

-- tell window to update the display of its dataset, using its display provider.
function Window:UpdateDisplay()
	-- hidden window? nothing to do.
	if not self:IsShown() then
		return
	elseif self.selectedmode then
		local set = self:GetSelectedSet()
		if set then
			update_in_progress(self)

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
				(P.showtotals or self.db.showtotals) and
				self.selectedmode.GetSetSummary and
				((set.type and set.type ~= "none") or set.name == L["Total"])
			then
				local value, valuetext = self.selectedmode:GetSetSummary(set, self)
				if value or valuetext then
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

					local d = existing or {}
					d.id = "total"
					d.label = L["Total"]
					d.text = nil
					d.ignore = true
					d.value = value + 1 -- to be always first
					d.valuetext = valuetext or tostring(value)

					if P.moduleicons and self.selectedmode.metadata and self.selectedmode.metadata.icon then
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

				if P.moduleicons and mode.metadata and mode.metadata.icon then
					d.icon = mode.metadata.icon
				end

				if set and mode.GetSetSummary then
					local value, valuetext = mode:GetSetSummary(set, self)
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

		-- speed up things if it's a pet/enemy.
		if strmatch(d.label, "%<(%a+)%>") then
			d.class = "PET"
			return d
		elseif enemy then
			d.class = actor.class or "ENEMY"
			d.role = actor.role
			d.spec = actor.spec
			return d
		end

		d.class = actor.class or "UNKNOWN"
		d.role = actor.role
		d.spec = actor.spec

		if actor.id and Skada.validclass[d.class] then
			d.text = Skada:FormatName(actor.name or actorname, actor.id)
		elseif d.text then
			d.text = nil
		end
	end
	return d
end

-- wipes windown's dataset table
function reset_window(self)
	if self.dataset then
		for i = 1, #self.dataset do
			if self.dataset[i] then
				wipe(self.dataset[i])
			end
		end
	end
end

function Window:Wipe(changed)
	reset_window(self)
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

do
	local function click_on_mode(win, id, _, button)
		if button == "LeftButton" then
			local mode = find_mode(id)
			if mode then
				if P.sortmodesbyusage then
					P.modeclicks = P.modeclicks or {}
					P.modeclicks[id] = (P.modeclicks[id] or 0) + 1
					sort_modes()
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
		if P.sortmodesbyusage and P.modeclicks then
			return (P.modeclicks[a.moduleName] or 0) > (P.modeclicks[b.moduleName] or 0)
		else
			return a.moduleName < b.moduleName
		end
	end

	function sort_modes()
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
			local sets = Skada.char.sets
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

		self.metadata.click = click_on_mode
		self.metadata.maxvalue = 1
		self.metadata.sortfunc = default_sort_func

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
		private.tCopy(db, self.windowdefaults)

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

	local window = new_window()
	window.db = db

	-- avoid duplicate names
	do
		local num = 0
		for i = 1, #windows do
			local _db = windows[i] and windows[i].db
			if _db and _db.name == name and num == 0 then
				num = 1
			elseif _db then
				local n, c = strmatch(_db.name, "^(.-)%s*%((%d+)%)$")
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
	elseif theset and type(theset) == "number" and theset <= #Skada.char.sets then
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

do
	local is_watching = nil

	function start_watching()
		if not is_watching then
			Skada:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatEvent")
			is_watching = true
		end
	end

	function stop_watching()
		if is_watching then
			Skada:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			is_watching = nil
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
		stop_watching()
	else
		if Skada.disabled then
			Skada:Debug(format("%s \124cff00ff00%s\124r", L["Data Collection"], L["ENABLED"]))
		end
		Skada.disabled = nil
		start_watching()
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

		local sets = self.char.sets
		for i = 1, #sets do
			verify_set(mode, sets[i])
		end

		mode.Reload = mode.Reload or reload_mode
		mode.category = category or L["Other"]
		modes[#modes + 1] = mode

		if selected_feed == nil and P.feed ~= "" then
			self:SetFeed(P.feed)
		end

		scan_for_columns(mode)
		sort_modes()

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
		if P.modulesBlocked[select(i, ...)] == true then
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
	local sets = self.char.sets

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
				restore_window_view(win)
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
local dummy_pet = {class = "PET"} -- used as fallback
function Skada:FindPlayer(set, id, name, is_create)
	id = id or name -- fallback

	local actors = set and (id ~= "total") and (name ~= L["Total"]) and set.players
	if not actors then
		return
	elseif not set._playeridx then
		set._playeridx = {}
	end

	-- already cached player?
	local player = set._playeridx[id]
	if player then
		return self.playerPrototype:Bind(player, set)
	end

	-- search the set
	for i = 1, #actors do
		local actor = actors[i]
		if actor and ((id and actor.id == id) or (name and actor.name == name)) then
			set._playeridx[id] = actor
			return actor
		end
	end

	if is_create then return end

	-- speed up things with pets
	local ownerName = strmatch(name, "%<(%a+)%>")
	if ownerName then
		dummy_pet.id = id
		dummy_pet.name = name
		dummy_pet.owner = ownerName
		return self.playerPrototype:Bind(dummy_pet, set)
	end

	-- search friendly enemies
	local enemy = self:FindEnemy(set, name, id)
	if enemy and enemy.flag and band(enemy.flag, BITMASK_FRIENDLY) ~= 0 then
		set._playeridx[id] = enemy
		return enemy
	end

	-- our last hope!
	dummy_pet.id = id
	dummy_pet.name = name or L["Unknown"]
	return self.playerPrototype:Bind(dummy_pet, set)
end

-- finds a player table or creates it if not found
function Skada:GetPlayer(set, guid, name, flag)
	if not (set and set.players and guid) then return end

	local player = self:FindPlayer(set, guid, name, true)
	if player or not name then
		return player
	end

	player = {id = guid, name = name, flag = flag, time = 0}

	if players[guid] then
		_, player.class = UnitClass(players[guid])
	elseif pets[guid] then
		player.class = "PET"
	else
		player.class = private.unit_class(guid, flag, nil, nil, name)
	end

	for i = 1, #modes do
		local mode = modes[i]
		if mode and mode.AddPlayerAttributes then
			mode:AddPlayerAttributes(player, set)
		end
	end

	set.players[#set.players + 1] = player

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
		player.name = (player.id == userGUID or guid == userGUID) and userName or name
	end

	-- fix players created before their info was received
	if player.class and Skada.validclass[player.class] and (player.role == nil or player.role == "NONE" or player.spec == nil) then
		if player.role == nil or player.role == "NONE" then
			player.role = GetUnitRole(player.id)
		end
		if player.spec == nil then
			player.spec = GetUnitSpec(player.id)
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
	local actors = name and set and set.enemies
	if not actors then
		return
	elseif not set._enemyidx then
		set._enemyidx = {}
	end

	local enemy = set._enemyidx[name]
	if enemy then
		return self.enemyPrototype:Bind(enemy, set)
	end

	for i = 1, #actors do
		local actor = actors[i]
		if actor and ((id and id == actor.id) or (name and actor.name == name)) then
			set._enemyidx[name] = self.enemyPrototype:Bind(actor, set)
			return actor
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
			enemy.class = private.unit_class(guid, flag)
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
function Skada:FindActor(set, id, name, no_strict)
	local actor = self:FindPlayer(set, id, name, not no_strict)
	if not actor then
		return self:FindEnemy(set, name, id), true
	end
	return actor
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
			local _players = Skada.current and guid and Skada.current.players
			if not _players then return end

			pettooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
			pettooltip:ClearLines()
			pettooltip:SetHyperlink(format("unit:%s", guid))

			-- we only need to scan the 2nd line.
			local text = _G["SkadaPetTooltipTextLeft2"] and _G["SkadaPetTooltipTextLeft2"]:GetText()
			if text and text ~= "" then
				for i = 1, #_players do
					local p = _players[i]
					local playername = p and gsub(p.name, "%-.*", "")
					if playername and ((LOCALE_ruRU and find_name_declension(text, playername)) or validate_pet_owner(text, playername)) then
						return p.id, p.name
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
		if guid and pets[guid] then
			return pets[guid]
		end

		-- flag is provided and it is mine.
		if guid and flag and band(flag, BITMASK_MINE) ~= 0 then
			assign_pet(userGUID, userName, guid)
			return pets[guid]
		end

		-- no owner yet?
		if guid then
			-- guess the pet from roster.
			local ownerUnit = get_pet_owner_unit(guid)
			if ownerUnit then
				assign_pet(UnitGUID(ownerUnit), UnitName(ownerUnit), guid)
				return pets[guid]
			end

			-- guess the pet from tooltip.
			local ownerGUID, ownerName = get_pet_owner_from_tooltip(guid)
			if ownerGUID and ownerName then
				assign_pet(ownerGUID, ownerName, guid)
				return pets[guid]
			end
		end

		return nil
	end

	function Skada:FixPets(action)
		if not action then return end
		action.petname = nil -- clear it

		-- 1: group member / true: player / false: everything else
		if self:IsPlayer(action.playerid, action.playerflags, action.playername) ~= false then return end

		local owner = fix_pets_handler(action.playerid, action.playerflags)
		if owner then
			action.petname = action.playername

			if P.mergepets then
				action.playerid = owner.id
				action.playername = owner.name

				if action.spellname and action.playername then
					action.spellname = format("%s (%s)", action.spellname, action.petname)
				end
			else
				-- just append the creature id to the player
				action.playerid = format("%s%s", owner.id, GetCreatureId(action.playerid))
				action.playername = format("%s <%s>", action.playername, owner.name)
			end
		else
			-- if for any reason we fail to find the pets, we simply
			-- adds them separately as a single entry.
			action.playerid = action.playername
		end
	end

	function Skada:FixMyPets(guid, name, flags)
		if players[guid] or not self:IsPet(guid, name, flags) then
			return guid, name, flags
		end

		local owner = fix_pets_handler(guid, flags)
		if owner then
			return owner.id or guid, owner.name or name, owner.flag or flags
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

local function summon_pet(petGUID, petFlags, ownerGUID, ownerName, ownerFlags)
	if band(ownerFlags, BITMASK_GROUP) ~= 0 or band(ownerFlags, BITMASK_PETS) ~= 0 or (band(petFlags, BITMASK_PETS) ~= 0 and pets[petGUID]) then
		-- we assign the pet the normal way
		assign_pet(ownerGUID, ownerName, petGUID)

		-- we fix the table by searching through the complete list
		local fixsummon = true
		while fixsummon do
			fixsummon = nil
			for pet, owner in pairs(pets) do
				if pets[owner.id] then
					pets[pet] = new()
					pets[pet].id = pets[owner.id].id
					pets[pet].name = pets[owner.id].name
					fixsummon = true
				end
			end
		end
	end
end

function Skada:GetPetOwner(petGUID)
	return pets[petGUID]
end

local function debug_pets()
	check_group()
	Skada:Print(L["Pets"])
	for pet, owner in pairs(pets) do
		Skada:Printf("pet %s belongs to %s, %s", pet, owner.id, owner.name)
	end
end

-------------------------------------------------------------------------------
-- players and pets checkers

do
	-- since IsPlayer and IsPet are called lots of times
	-- it is better if we cache results to speed up things.
	local weaktable = private.weaktable
	local _players = setmetatable({}, weaktable)
	local _pets = setmetatable({}, weaktable)

	-- checks if the unit is a player (extra: helps IsPet)
	function Skada:IsPlayer(guid, flag, name)
		-- already cached?
		if _players[guid] ~= nil then
			return _players[guid]
		end

		-- group member?
		if players[guid] then
			_players[guid] = 1
			_pets[guid] = (_pets[guid] == nil) and false or _pets[guid]
			return _players[guid]
		end

		-- group pet?
		if pets[guid] then
			_players[guid] = false
			_pets[guid] = _pets[guid] or 1
			return _players[guid]
		end

		-- player by UnitIsPlayer?
		if name and UnitIsPlayer(name) then
			_players[guid] = true
			_pets[guid] = (_pets[guid] == nil) and false or _pets[guid]
			return _players[guid]
		end

		-- player by flgs?
		if tonumber(flag) and band(flag, BITMASK_PLAYER) ~= 0 then
			_players[guid] = true
			_pets[guid] = (_pets[guid] == nil) and false or _pets[guid]
			return _players[guid]
		end

		-- just set it to false
		_players[guid] = false
		return _players[guid]
	end

	-- checks if the guid is a pet (extra: helps IsPlayer)
	function Skada:IsPet(guid, flag)
		-- already cached?
		if _pets[guid] ~= nil then
			return _pets[guid]
		end

		-- just in case
		if players[guid] then
			_pets[guid] = false
			_players[guid] = 1
			return _pets[guid]
		end

		-- grouped pet?
		if pets[guid] then
			_pets[guid] = 1
			_players[guid] = false
			return _pets[guid]
		end

		-- ungrouped pet?
		if tonumber(flag) and (band(flag, BITMASK_PETS) ~= 0) then
			_pets[guid] = (band(flag, BITMASK_FRIENDLY) ~= 0) and 1 or true
			_players[guid] = false
			return _pets[guid]
		end

		_pets[guid] = false
		return _pets[guid]
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

		-- windows should have separate tooltip tables in order
		-- to display different numbers for same spells for example.
		win.ttwin = win.ttwin or new_window(true)
		reset_window(win.ttwin)

		if mode.Enter then
			mode:Enter(win.ttwin, id, label)
		end

		mode:Update(win.ttwin, win:GetSelectedSet())

		local dataset = win.ttwin.dataset
		if not mode.metadata or not mode.metadata.ordersort then
			tsort(dataset, value_sort)
		end

		if #dataset > 0 then
			tooltip:AddLine(win.ttwin.title or mode.title or mode.localeName)
			local nr = 0

			for i = 1, #dataset do
				local data = dataset[i]
				if data and data.id and not data.ignore and nr < P.tooltiprows then
					nr = nr + 1
					local color = white

					if data.color then
						color = data.color
					elseif data.class and Skada.validclass[data.class] then
						color = Skada.classcolors(data.class)
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
	end

	local function add_submode_lines(mode, win, id, label, tooltip)
		if mode and not private.total_noclick(win.selectedset, mode) then
			add_subview_lines(tooltip, win, mode, id, label)
		end
	end

	local function add_click_lines(mode, label, win, t, fmt)
		if type(mode) == "function" then
			t:AddLine(uformat(fmt, label))
		elseif not private.total_noclick(win.selectedset, mode) then
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

function Skada:FilterClass(win, id, label)
	if win.class then
		win:DisplayMode(win.selectedmode, nil)
	elseif win.GetSelectedSet and id then
		local set = win:GetSelectedSet()
		local actor = set and set:GetActor(label, id)
		win:DisplayMode(win.selectedmode, actor and actor.class)
	end
end

-------------------------------------------------------------------------------
-- slash commands

local function generate_total()
	local sets = Skada.char.sets
	if not sets or #sets == 0 then return end

	Skada.char.total = create_set(L["Total"], Skada.char.total)
	Skada.total = Skada.char.total

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

		local set_players = set.players
		local total_players = total.players

		for j = 1, #set_players do
			local p = set_players[j]
			if p then
				local index = nil
				for k = 1, #total_players do
					local a = total_players[k]
					if a and a.id == p.id then
						index = k
						break
					end
				end

				local player = index and total_players[index] or {}

				for k, v in pairs(p) do
					if (type(v) == "string" or k == "spec" or k == "flag") then
						player[k] = player[k] or v
					elseif type(v) == "number" then
						player[k] = (player[k] or 0) + v
					end
				end

				if not index then
					total_players[#total_players + 1] = player
				end
			end
		end
	end

	ReloadUI()
end

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
		private.open_options()
	elseif cmd == "memorycheck" or cmd == "memory" or cmd == "ram" then
		Skada:CheckMemory()
	elseif cmd == "clear" or cmd == "clean" then
		Skada:CleanGarbage()
	elseif cmd == "import" and private.open_import then
		private.open_import()
	elseif cmd == "export" and private.open_export then
		private.open_export()
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
			Skada:Print("Usage:")
			Skada:Printf("%-20s", "/skada report [channel] [mode] [lines]")
		end
	else
		Skada:Print(L["Usage:"])
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

	local get_channel_list
	do
		local list = {}
		function get_channel_list(...)
			wipe(list)
			for i = 1, select("#", ...) do
				list[i] = select(i, ...)
			end
			return list
		end
	end

	function Skada:Report(channel, chantype, report_mode_name, report_set_name, maxlines, window, barid)
		if chantype == "channel" then
			local list = get_channel_list(GetChannelList())
			for i = 1, table.getn(list) * 0.5 do
				if (P.report.channel == list[i * 2]) then
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

			report_table = new_window(true)
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
	if version ~= G.version then
		self.callbacks:Fire("Skada_UpdateCore", G.version, version)
		G.version = version
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

local last_check_group
function check_group()
	-- throttle group check.
	local checkTime = GetTime()
	if last_check_group and (checkTime - last_check_group) <= 0.5 then
		return
	end
	last_check_group = checkTime

	for unit, owner in UnitIterator() do
		if owner == nil then
			players[UnitGUID(unit)] = unit
		else
			assign_pet(UnitGUID(owner), UnitName(owner), UnitGUID(unit))
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

		Skada:SendMessage("GROUP_ROSTER_UPDATE", players, pets)
	end
end

do
	local UnitHasVehicleUI = UnitHasVehicleUI
	local ignoredUnits = {target = true, focus = true, npc = true, NPC = true, mouseover = true}

	function Skada:UNIT_PET(_, unit)
		if unit and not ignoredUnits[unit] then
			check_group()
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
						assign_pet(guid, UnitName(unit), UnitGUID(vUnitId))
						vehicles[guid] = UnitGUID(vUnitId)
					end
				elseif vehicles[guid] then
					-- delayed for a reason (2 x MAINMENU_SLIDETIME).
					dismiss_pet(vehicles[guid], 0.6)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------

function Skada:CanReset()
	local total_players = self.total and self.total.players
	if total_players and next(total_players) then
		return true
	end

	local sets = self.char.sets
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
		wipe(self.char.sets)
		self.char.total = nil
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
		self.char.total = self.total
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
				return format("%.2fB", num * 1e-09)
			elseif num >= 1e6 or num <= -1e6 then
				return format("%.2fM", num * 1e-06)
			elseif num >= 1e3 or num <= -1e3 then
				return format("%.1fK", num * 0.001)
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
					return format("%.2f%s", num * 1e-08, symbol_1b)
				elseif num >= 1e4 or num <= -1e4 then
					return format("%.2f%s", num * 0.0001, symbol_10k)
				elseif num >= 1e3 or num <= -1e3 then
					return format("%.1f%s", num * 0.0001, symbol_1k)
				end
				return format("%.0f", num)
			end
		end

		Skada.FormatNumber = function(self, num, fmt)
			if not num then
				return
			else
				fmt = fmt or P.numberformat or 1
			end

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

function Skada:FormatPercent(value, total, dec)
	dec = dec or P.decimals or 1

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
	if not sec then
		return
	elseif alt then
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

function Skada:FormatName(name)
	if P.translit and Translit then
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
	CloseDropDownMenus()
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

function private.refresh_button()
	if not DBI then return end

	DBI:Refresh(folder, Skada.db.profile.icon)
	if Skada.db.profile.icon.hide then
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
		CloseDropDownMenus()
	end

	-- fire callback in case modules need it
	Skada.callbacks:Fire("Skada_ApplySettings")

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

	set_numeral_format(P.numbersystem)
	set_value_format(P.brackets, P.separator)

	Skada:UpdateDisplay(true)
end

function private.reload_settings()
	for i = 1, #windows do
		local win = windows[i]
		if win and win.Destroy then
			win:Destroy()
		end
	end
	wipe(windows)

	-- refresh refrences
	P = Skada.db.profile
	G = Skada.db.global

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

	Skada:ClearAllIndexes()
	private.refresh_button()
	Skada.total = Skada.char.total
	Skada:ApplySettings()
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
		if LDS then LDS:EnhanceDatabase(self.db, folder) end

		self.options.args.profiles.args.general = AceDBOptions:GetOptionsTable(self.db)
		self.options.args.profiles.args.general.order = 0

		if LDS then LDS:EnhanceOptions(self.options.args.profiles.args.general, self.db) end

		-- import/export profile if found.
		if private.advanced_profile then
			private.advanced_profile(self.options.args.profiles.args)
		end
	end

	P = self.db.profile
	G = self.db.global

	self:RegisterChatCommand("skada", slash_command, true) -- force flag set
	self.db.RegisterCallback(self, "OnProfileChanged", private.reload_settings)
	self.db.RegisterCallback(self, "OnProfileCopied", private.reload_settings)
	self.db.RegisterCallback(self, "OnProfileReset", private.reload_settings)
	self.db.RegisterCallback(self, "OnDatabaseShutdown", "ClearAllIndexes", true)

	private.init_options()
	private.register_medias()
	private.register_classes()
	private.register_schools()
	private.register_toast()
	self:RegisterComms(not P.syncoff)

	if self.LoadableDisplay then
		for name, func in pairs(self.LoadableDisplay) do
			if not self:IsDisabled(name) then
				func(L, P, G, self.cacheTable)
			end
		end
		self.LoadableDisplay = del(self.LoadableDisplay)
	end

	-- fix things and remove others
	P.setstokeep = min(25, max(0, P.setstokeep or 0))
	P.setslimit = min(25, max(0, P.setslimit or 0))
	P.timemesure = min(2, max(1, P.timemesure or 0))
	P.totalflag = P.totalflag or 0x10
	G.revision = nil

	-- store the version
	G.version = G.version or 0

	-- sets limit
	self.maxsets = P.setstokeep + P.setslimit
	self.maxmeme = min(60, max(30, self.maxsets + 10))

	-- use our custom functions
	GetSpellInfo = private.spell_info or GetSpellInfo
	GetSpellLink = private.spell_link or GetSpellLink
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
	userGUID = userGUID or UnitGUID("player")
	self.userGUID = userGUID

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("UNIT_PET")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckZone")
	self:RegisterEvent("UNIT_ENTERED_VEHICLE", "CheckVehicle")
	self:RegisterEvent("UNIT_EXITED_VEHICLE", "CheckVehicle")
	self:RegisterBucketEvent({"PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE"}, 0.25, "UpdateRoster")
	start_watching()

	if self.LoadableModules then
		for i = 1, #self.LoadableModules do
			local mod = self.LoadableModules[i]
			if mod.name and mod.func and not self:IsDisabled(mod.name) and not (mod.deps and self:IsDisabled(unpack(mod.deps))) then
				mod.func(L, P, G, self.cacheTable, P.modules)
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
	private.reload_settings()

	-- SharedMedia is sometimes late, we wait few seconds then re-apply settings.
	self:ScheduleTimer("ApplySettings", 2)
	self:ScheduleTimer("CheckMemory", 3)
end

-- called on boss defeat
function private.boss_defeated()
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

	local sets = self.char.sets
	for i = 1, #sets do
		sets[i] = self.setPrototype:Bind(sets[i])
	end

	return sets
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
	if self.current and (time() - self.current.starttime) >= (P.minsetlength or 5) then
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

function combat_end()
	if not Skada.current then return end
	private.clear_queued_units()

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
		for i = 1, #Skada.tempsets do
			process_set(Skada.tempsets[i], curtime, Skada.current.name)
		end
		T.free("Skada_TempSegments", Skada.tempsets)
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
	if Skada.total.players then
		for i = 1, #Skada.total.players do
			if Skada.total.players[i] then
				Skada.total.players[i].last = nil
			end
		end
	end

	if Skada.current.time >= P.minsetlength then
		Skada.total.time = Skada.total.time + Skada.current.time
	end

	Skada.last = Skada.current
	Skada.current = nil
	Skada.inCombat = nil
	_targets = del(_targets)

	clean_sets()

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

	Skada:ScheduleTimer("CleanGarbage", 5)
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
	local tentative, tentative_timer
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

	local function combat_tick()
		Skada.inCombat = true
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

		Skada:Wipe()

		if Skada.current == nil then
			Skada:Debug("StartCombat: Segment Created!")
			Skada.current = create_set(L["Current"])
		end

		if Skada.total == nil then
			Skada.total = create_set(L["Total"])
			Skada.char.total = Skada.total
		end

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

	function Skada:OnCombatEvent(_, ...)
		-- disabled or test mode?
		if self.disabled or self.testMode then return end
		return self:CombatLogEvent(...)
	end

	local function check_flags_interest(guid, flags, nopets)
		local is_interesting = (players[guid] ~= nil)

		if not is_interesting and band(flags, BITMASK_GROUP) ~= 0 then
			if nopets then
				is_interesting = band(flags, BITMASK_PETS) == 0
			else
				is_interesting = true
			end
		end

		if not is_interesting and not nopets and band(flags, BITMASK_PETS) ~= 0 and pets[guid] then
			is_interesting = true
		end

		return is_interesting
	end

	local function check_boss_fight(set, event, srcName, srcFlags, src_is_interesting, dstGUID, dstName, dstFlags, dst_is_interesting)
		-- set mobname
		if not set.mobname then
			if set.type == "pvp" then
				set.gotboss = false -- skip boss check
				set.mobname = GetInstanceInfo()
			elseif set.type == "arena" then
				set.gotboss = false -- skip boss check
				set.mobname = GetInstanceInfo()
				set.gold = GetBattlefieldArenaFaction()
				Skada:SendMessage("COMBAT_ARENA_START", set, set.mobname)
			elseif src_is_interesting and band(dstFlags, BITMASK_FRIENDLY) == 0 then
				set.mobname = dstName
			elseif dst_is_interesting and band(srcFlags, BITMASK_FRIENDLY) == 0 then
				set.mobname = srcName
			end
		end

		-- check for boss fights
		if not set.gotboss and not spellcast_events[event] then
			-- marking set as boss fights relies only on src_is_interesting
			if src_is_interesting and band(dstFlags, BITMASK_FRIENDLY) == 0 then
				if set.gotboss == nil then
					if not _targets or not _targets[dstName] then
						local isboss, bossid, bossname = Skada:IsEncounter(dstGUID, dstName)
						if isboss then -- found?
							set.mobname = bossname or dstName
							set.gotboss = bossid or true
							Skada:SendMessage("COMBAT_ENCOUNTER_START", set)
							_targets = del(_targets)
						else
							_targets = _targets or new()
							_targets[dstName] = true
							set.gotboss = false
						end
					end
				elseif _targets and not _targets[dstName] then
					_targets[dstName] = true
					set.gotboss = nil
				end
			end
		-- default boss defeated event? (no DBM/BigWigs)
		elseif not Skada.bossmod and set.gotboss and death_events[event] and set.gotboss == GetCreatureId(dstGUID) then
			Skada:ScheduleTimer(private.boss_defeated, P.updatefrequency or 0.5)
		end
	end

	local function check_autostop(set, event, guid, flags)
		if event == "UNIT_DIED" and check_flags_interest(guid, flags, true) then
			death_counter = death_counter + 1
			-- If we reached the treshold for stopping the segment, do so.
			if death_counter >= starting_members * 0.5 and not set.stopped then
				Skada:SendMessage("COMBAT_PLAYER_WIPE", set)
				Skada:StopSegment(L["Stopping for wipe."])
			end
		elseif event == "SPELL_RESURRECT" and check_flags_interest(guid, flags, true) then
			death_counter = death_counter - 1
		end
	end

	local function tentative_handler()
		Skada:CancelTimer(tentative_timer, true)
		tentative_timer = nil
		tentative = nil
		Skada.current = nil
	end

	function Skada:CombatLogEvent(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		-- ignored combat event?
		if (not eventtype or ignored_events[eventtype]) and not (spellcast_events[eventtype] and self.current) then return end

		local src_is_interesting = nil
		local dst_is_interesting = nil

		if not self.current and P.tentativecombatstart and trigger_events[eventtype] and srcName and dstName and srcGUID ~= dstGUID then
			src_is_interesting = check_flags_interest(srcGUID, srcFlags)

			if eventtype ~= "SPELL_PERIODIC_DAMAGE" then
				dst_is_interesting = check_flags_interest(dstGUID, dstFlags)
			end

			if src_is_interesting or dst_is_interesting then
				self.current = create_set(L["Current"])
				if not self.total then
					self.total = create_set(L["Total"])
				end

				tentative_timer = self:ScheduleTimer(tentative_handler, 1)
				tentative = 0

				check_boss_fight(self.current, eventtype, srcName, srcFlags, src_is_interesting, dstGUID, dstName, dstFlags, dst_is_interesting)
			end
		end

		-- pet summons.
		if eventtype == "SPELL_SUMMON" then
			summon_pet(dstGUID, dstFlags, srcGUID, srcName, srcFlags)
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
			if P.autostop and (eventtype == "UNIT_DIED" or eventtype == "SPELL_RESURRECT") then
				check_autostop(self.current, eventtype, srcGUID, srcFlags)
			end

			-- valid combatlog event
			if combatlog_events[eventtype] then
				if self.current.stopped then return end

				self.current.last_action = time()
				self.current.last_time = GetTime()

				if P.totalidc then -- add to total segment
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
						local src_is_interesting_nopets = check_flags_interest(srcGUID, srcFlags, true)

						if src_is_interesting_nopets then
							src_is_interesting = true
						else
							fail = true
						end
					end

					if not fail and flags.dst_is_interesting_nopets then
						local dst_is_interesting_nopets = check_flags_interest(dstGUID, dstFlags, true)
						if dst_is_interesting_nopets then
							dst_is_interesting = true
						else
							fail = true
						end
					end

					if not fail and flags.src_is_interesting or flags.src_is_not_interesting then
						if not src_is_interesting then
							src_is_interesting = check_flags_interest(srcGUID, srcFlags) or private.is_queued_unit(srcGUID)
						end

						if (flags.src_is_interesting and not src_is_interesting) or (flags.src_is_not_interesting and src_is_interesting) then
							fail = true
						end
					end

					if not fail and flags.dst_is_interesting or flags.dst_is_not_interesting then
						if not dst_is_interesting then
							dst_is_interesting = check_flags_interest(dstGUID, dstFlags)
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
								self:CancelTimer(tentative_timer, true)
								tentative_timer = nil
								tentative = nil
								self:Debug("StartCombat: tentative combat")
								combat_start()
							end
						end

						func(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
					end
				end
			end

			check_boss_fight(self.current, eventtype, srcName, srcFlags, src_is_interesting, dstGUID, dstName, dstFlags, dst_is_interesting)
		end
	end
end
