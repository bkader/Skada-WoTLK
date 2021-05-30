local Skada = LibStub("AceAddon-3.0"):NewAddon("Skada", "AceEvent-3.0", "AceHook-3.0", "AceConsole-3.0", "AceComm-3.0")
_G.Skada = Skada
Skada.callbacks = Skada.callbacks or LibStub("CallbackHandler-1.0"):New(Skada)
Skada.version = GetAddOnMetadata("Skada", "Version")
Skada.website = GetAddOnMetadata("Skada", "X-Website")

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local ACD = LibStub("AceConfigDialog-3.0")
local DBI = LibStub("LibDBIcon-1.0", true)
local LBB = LibStub("LibBabble-Boss-3.0"):GetUnstrictLookupTable()
local LBI = LibStub("LibBossIDs-1.0")
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LGT = LibStub("LibGroupTalents-1.0")
local LSM = LibStub("LibSharedMedia-3.0")
local Translit = LibStub("LibTranslit-1.0")

-- cache frequently used globlas
local tsort, tinsert, tremove, tmaxn = table.sort, table.insert, table.remove, table.maxn
local next, pairs, ipairs, type = next, pairs, ipairs, type
local tonumber, tostring, format, strsplit = tonumber, tostring, string.format, strsplit
local math_floor, math_max, math_min = math.floor, math.max, math.min
local band, bor, time, setmetatable = bit.band, bit.bor, time, setmetatable
local GetNumPartyMembers, GetNumRaidMembers = GetNumPartyMembers, GetNumRaidMembers
local IsInInstance, UnitAffectingCombat, InCombatLockdown = IsInInstance, UnitAffectingCombat, InCombatLockdown
local UnitGUID, GetUnitName, UnitClass, UnitIsConnected = UnitGUID, GetUnitName, UnitClass, UnitIsConnected
local CombatLogClearEntries = CombatLogClearEntries
local GetSpellInfo, GetSpellLink = GetSpellInfo, GetSpellLink

-- weak table
local weaktable = {__mode = "v"}
Skada.weaktable = weaktable

local dataobj = LDB:NewDataObject("Skada", {
	label = "Skada",
	type = "data source",
	icon = "Interface\\Icons\\Spell_Lightning_LightningBolt01",
	text = "n/a"
})

-- Keybindings
BINDING_HEADER_SKADA = "Skada"
BINDING_NAME_SKADA_TOGGLE = L["Toggle Windows"]
BINDING_NAME_SKADA_RESET = RESET
BINDING_NAME_SKADA_NEWSEGMENT = L["Start New Segment"]
BINDING_NAME_SKADA_STOP = L["Stop"]

-- Skada-Revisited flag
Skada.revisited = true

-- available display types
Skada.displays = {}

-- flag to check if disabled
local disabled = false

-- flag used to check if we need an update
local changed = true

-- update & tick timers
local update_timer, tick_timer, clean_timer
local checkVersion, convertVersion

-- list of players and pets
local players, pets = {}, {}

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

-- =================== --
-- add missing globals --
-- =================== --

local IsInRaid = _G.IsInRaid
if not IsInRaid then
	IsInRaid = function()
		return GetNumRaidMembers() > 0
	end
	_G.IsInRaid = IsInRaid
end

local IsInGroup = _G.IsInGroup
if not IsInGroup then
	IsInGroup = function()
		return (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0)
	end
	_G.IsInGroup = IsInGroup
end

-- returns the group type and count
local function GetGroupTypeAndCount()
	local count, t = GetNumRaidMembers(), "raid"
	if count == 0 then -- no raid? maybe party!
		count, t = GetNumPartyMembers(), "party"
	end
	if count == 0 then -- still 0? Then solo
		t = "player"
	end
	return t, count
end

-- we need to use custom icons for certain spells.
do
	local custom = {
		[3] = {ACTION_ENVIRONMENTAL_DAMAGE_FALLING, "Interface\\Icons\\ability_rogue_quickrecovery"},
		[4] = {ACTION_ENVIRONMENTAL_DAMAGE_DROWNING, "Interface\\Icons\\spell_shadow_demonbreath"},
		[5] = {ACTION_ENVIRONMENTAL_DAMAGE_FATIGUE, "Interface\\Icons\\ability_creature_cursed_05"},
		[6] = {ACTION_ENVIRONMENTAL_DAMAGE_FIRE, "Interface\\Icons\\spell_fire_fire"},
		[7] = {ACTION_ENVIRONMENTAL_DAMAGE_LAVA, "Interface\\Icons\\spell_shaman_lavaflow"},
		[8] = {ACTION_ENVIRONMENTAL_DAMAGE_SLIME, "Interface\\Icons\\inv_misc_slime_01"}
	}

	function Skada.GetSpellInfo(spellid)
		local res1, res2, res3, res4, res5, res6, res7, res8, res9
		if spellid then
			if custom[spellid] then
				res1, res3 = unpack(custom[spellid])
			else
				res1, res2, res3, res4, res5, res6, res7, res8, res9 = GetSpellInfo(spellid)
				if spellid == 75 then
					res3 = "Interface\\Icons\\INV_Weapon_Bow_07"
				elseif spellid == 6603 then
					res3 = "Interface\\Icons\\INV_Sword_04"
				end
			end
		end
		return res1, res2, res3, res4, res5, res6, res7, res8, res9
	end

	function Skada.GetSpellLink(spellid)
		if not custom[spellid] then
			return GetSpellLink(spellid)
		end
	end
end

function Skada.UnitClass(guid, flags, set)
	local locClass, engClass

	if guid then
		set = set or Skada.current

		if set then
			-- an exisiting player?
			for _, player in Skada:IteratePlayers(set) do
				if player.id == guid then
					return Skada.classnames[player.class], player.class, player.role, player.spec
				end
			end

			-- make sure to create the classes table.
			set._classes = set._classes or {}

			-- an already cached unit
			for id, class in pairs(set._classes) do
				if id == guid then
					return Skada.classnames[class], class
				end
			end

			-- a pet? This only works for current segment
			if pets[guid] then
				locClass, engClass = Skada.classnames.PET, "PET"
			end
		end

		-- a valid guid?
		if not engClass and tonumber(guid) ~= nil then
			-- real player?
			local class = select(2, GetPlayerInfoByGUID(guid))
			if class then
				locClass, engClass = Skada.classnames[class], class
			else
				local isboss, npcid = Skada:IsBoss(guid)
				-- possible boss?
				if isboss then
					-- possible npc (monster or pet)
					locClass, engClass = Skada.classnames.BOSS, "BOSS"
				elseif (npcid or 0) > 0 then
					-- player maybe?
					-- use the flags first
					if flags and band(flags, BITMASK_PETS) ~= 0 then
						locClass, engClass = Skada.classnames.PET, "PET"
					else
						locClass, engClass = Skada.classnames.MONSTER, "MONSTER"
					end
				elseif npcid == 0 and flags and band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 then
					locClass, engClass = Skada.classnames.PLAYER, "PLAYER"
				end
			end
		end

		if not engClass and flags then
			if band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 then
				locClass, engClass = Skada.classnames.PLAYER, "PLAYER"
			elseif band(flags, BITMASK_PETS) ~= 0 then
				locClass, engClass = Skada.classnames.PET, "PET"
			elseif band(flags, COMBATLOG_OBJECT_TYPE_NPC) ~= 0 then
				locClass, engClass = Skada.classnames.MONSTER, "MONSTER"
			elseif band(flags, BITMASK_ENEMY) ~= 0 then
				locClass, engClass = Skada.classnames.ENEMY, "ENEMY"
			end
		end

		-- everything failed!
		if not engClass then
			locClass, engClass = Skada.classnames.UNKNOWN, "UNKNOWN"
		end

		if set and not set._classes[guid] then
			set._classes[guid] = engClass
		end
	end

	return locClass, engClass
end

-- ============= --
-- needed locals --
-- ============= --

local sort_modes

-- party/group
function Skada:IsInPVP()
	local instanceType = select(2, IsInInstance())
	return (instanceType == "pvp" or instanceType == "arena")
end

local function setPlayerActiveTimes(set)
	for _, player in Skada:IteratePlayers(set) do
		if player.last then
			player.time = math_max(player.time + (player.last - player.first), 0.1)
		end
	end
end

function Skada:PlayerActiveTime(set, player, active)
	local settime = self:GetSetTime(set)
	if self.effectivetime and not active then
		return settime
	end

	if player then
		local maxtime = ((player.time or 0) > 0) and player.time or 0
		if set and (not set.endtime or set.stopped) and player.first then
			maxtime = maxtime + (player.last or 0) - player.first
		end
		settime = math_min(maxtime, settime)
	end

	return settime
end

-- utilities

function Skada:ShowPopup(win, popup)
	if Skada.db.profile.skippopup and not popup then
		Skada:Reset()
		return
	end

	if not StaticPopupDialogs["SkadaResetDialog"] then
		StaticPopupDialogs["SkadaResetDialog"] = {
			text = L["Do you want to reset Skada?"],
			button1 = ACCEPT,
			button2 = CANCEL,
			timeout = 30,
			whileDead = 0,
			hideOnEscape = 1,
			OnAccept = function()
				Skada:Reset()
			end
		}
	end
	StaticPopup_Show("SkadaResetDialog")
end

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

-- ================= --
-- WINDOWS FUNCTIONS --
-- ================= --
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
			get = function(i) return db[i[#i]] end,
			set = function(i, val)
				db[i[#i]] = val
				Skada:ApplySettings()
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
				separator1 = {
					type = "description",
					name = " ",
					order = 8,
					width = "full"
				},
				copywin = {
					type = "select",
					name = L["Copy Settings"],
					desc = L["Choose the window from which you want to copy the settings."],
					order = 9,
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
					order = 10,
					disabled = function() return (copywindow == nil) end,
					func = function()
						local newdb = {}
						if copywindow then
							for _, win in Skada:IterateWindows() do
								if win.db.name == copywindow and win.db.display == db.display then
									Skada:tcopy(newdb, win.db, {"name", "sticked", "x", "y", "point", "snapped"})
									break
								end
							end
						end
						for k, v in pairs(newdb) do
							db[k] = v
						end
						Skada:ApplySettings()
						copywindow = nil
					end
				},
				separator2 = {
					type = "description",
					name = " ",
					order = 11,
					width = "full"
				},
				delete = {
					type = "execute",
					name = L["Delete Window"],
					desc = L["Choose the window to be deleted."],
					order = 12,
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
					Skada:ApplySettings()
				end
			}

			-- options.args.snapto = {
			-- 	type = "toggle",
			-- 	name = L["Snap to best fit"],
			-- 	desc = L["Snaps the window size to best fit when resizing."],
			-- 	order = 7,
			-- 	disabled = true
			-- }
		end

		options.args.switchoptions = {
			type = "group",
			name = L["Mode Switching"],
			order = 4,
			args = {
				modeincombat = {
					type = "select",
					name = L["Combat mode"],
					desc = L["Automatically switch to set 'Current' and this mode when entering combat."],
					order = 1,
					values = function()
						local m = {[""] = NONE}
						for _, mode in ipairs(Skada:GetModes()) do
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
						for _, mode in ipairs(Skada:GetModes()) do
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
					disabled = function()
						return (db.modeincombat == "" and db.wipemode == "")
					end
				}
			}
		}

		self.display:AddDisplayOptions(self, options.args)
		Skada.options.args.windows.args[self.db.name] = options
	end
end

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
	self.display:Destroy(self)

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
	for _, data in ipairs(self.dataset or {}) do
		wipe(data)
	end
end

function Window:Wipe()
	self:Reset()
	if self.display then
		self.display:Wipe(self)
	end

	if self.child then
		self.child:Wipe()
	end
end

function Window:get_selected_set()
	return Skada:GetSet(self.selectedset)
end

function Window:set_selected_set(set)
	self.selectedset = set
	self:RestoreView()
	if self.child then
		self.child:set_selected_set(set)
	end
end

function Window:DisplayMode(mode)
	if type(mode) ~= "table" then return end
	self:Wipe()

	self.selectedmode = mode
	self.metadata = wipe(self.metadata or {})

	if mode and self.parenttitle ~= mode:GetName() and Skada:GetModule(mode:GetName(), true) then
		self.parenttitle = mode:GetName()
	end

	if mode.metadata then
		for key, value in pairs(mode.metadata) do
			self.metadata[key] = value
		end
	end

	self.changed = true
	self:set_mode_title()

	if self.child then
		self.child:DisplayMode(mode)
	end

	Skada:UpdateDisplay(false)
end

do
	function sort_modes()
		tsort(modes, function(a, b)
			if Skada.db.profile.sortmodesbyusage and Skada.db.profile.modeclicks then
				return (Skada.db.profile.modeclicks[a:GetName()] or 0) > (Skada.db.profile.modeclicks[b:GetName()] or 0)
			else
				return a:GetName() < b:GetName()
			end
		end)
	end

	local function click_on_mode(win, id, _, button)
		if button == "LeftButton" then
			local mode = Skada:find_mode(id)
			if mode then
				if Skada.db.profile.sortmodesbyusage then
					Skada.db.profile.modeclicks = Skada.db.profile.modeclicks or {}
					Skada.db.profile.modeclicks[id] = (Skada.db.profile.modeclicks[id] or 0) + 1
					sort_modes()
				end
				win:DisplayMode(mode)
				mode = nil
			end
		elseif button == "RightButton" then
			win:RightClick()
		end
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
			for i, set in ipairs(Skada.char.sets) do
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

		if self.child then
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

		if self.child then
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
	L_CloseDropDownMenus() -- always close
end

-- ================================================== --

function Skada:tlength(tbl)
	local len = 0
	for _ in pairs(tbl) do
		len = len + 1
	end
	return len
end

function Skada:WeakTable(tbl)
	return setmetatable(tbl or {}, weaktable)
end

function Skada:tcopy(to, from, ...)
	for k, v in pairs(from) do
		local skip = false
		if ... then
			for i, j in ipairs(...) do
				if j == k then
					skip = true
					break
				end
			end
		end
		if not skip then
			if type(v) == "table" then
				to[k] = {}
				Skada:tcopy(to[k], v, ...)
			else
				to[k] = v
			end
		end
	end
end

-- ================================================== --

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
		self:tcopy(db, Skada.windowdefaults)
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
					num = math_max(num, tonumber(c) or 0)
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
		self:Print("Window '" .. name .. "' was not loaded because its display module, '" .. (window.db.display or UNKNOWN) .. "' was not found.")
	end

	self:ApplySettings()
	return window
end

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
					L_CloseDropDownMenus()
					ACD:Close("Skada") -- to avoid errors
					return DeleteWindow(data)
				end
			}
		end
		StaticPopup_Show("SkadaDeleteWindowDialog", nil, nil, name)
	end
end

function Skada:ToggleWindow()
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

function Skada:RestoreView(win, theset, themode)
	if theset and type(theset) == "string" and (theset == "current" or theset == "total" or theset == "last") then
		win.selectedset = theset
	elseif theset and type(theset) == "number" and theset <= #self.char.sets then
		win.selectedset = theset
	else
		win.selectedset = "current"
	end

	changed = true

	if themode then
		win:DisplayMode(self:find_mode(themode) or win.selectedset)
	else
		win:DisplayModes(win.selectedset)
	end
end

function Skada:Wipe()
	for _, win in self:IterateWindows() do
		win:Wipe()
	end
end

function Skada:SetActive(enable)
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

		print("|cFF33FF99Skada Debug|r: " .. msg)
	end
end

-- =============== --
-- MODES FUNCTIONS --
-- =============== --

function Skada:find_mode(name)
	for _, mode in ipairs(modes) do
		if mode:GetName() == name then
			return mode
		end
	end
end

do
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

		for _, set in ipairs(self.char.sets) do
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
		sort_modes()

		for _, win in self:IterateWindows() do
			win:Wipe()
		end

		changed = true
	end
end

function Skada:RemoveMode(mode)
	tremove(modes, mode)
end

function Skada:GetModes()
	return modes
end

-- iteration functions

function Skada:IterateModes()
	return ipairs(modes)
end

function Skada:IterateSets()
	return ipairs(self.char.sets or {})
end

function Skada:IterateWindows()
	return ipairs(windows)
end

function Skada:IteratePlayers(set)
	return ipairs(set and set.players or {})
end

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

function Skada:IsDisabled(...)
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		if self.db.profile.modulesBlocked[name] == true then
			name = nil
			return true
		end
	end
	return false
end

do
	local numorder = 5
	function Skada:AddDisplaySystem(key, mod)
		self.displays[key] = mod
		if mod.description then
			Skada.options.args.windows.args[key .. "desc"] = {
				type = "description",
				name = format("|cffffd700%s|r: %s", mod.name, mod.description),
				fontSize = "medium",
				order = numorder
			}
			numorder = numorder + 1
		end
	end
end

-- =============== --
-- SETS FUNCTIONS --
-- =============== --

function Skada:CreateSet(setname, starttime)
	starttime = starttime or time()
	local set = {players = {}, name = setname, starttime = starttime, last_action = starttime, time = 0}
	for _, mode in ipairs(modes) do
		self:VerifySet(mode, set)
	end
	self.callbacks:Fire("SKADA_DATA_SETCREATED", set)
	return set
end

function Skada:VerifySet(mode, set)
	if mode.AddSetAttributes then
		mode:AddSetAttributes(set)
	end

	if mode.AddPlayerAttributes then
		for _, player in self:IteratePlayers(set) do
			mode:AddPlayerAttributes(player, set)
		end
	end
end

function Skada:GetSets()
	return self.char.sets
end

function Skada:GetSet(s)
	if s == "current" then
		if self.current ~= nil then
			return self.current
		elseif self.last ~= nil then
			return self.last
		else
			return self.char.sets[1]
		end
	elseif s == "total" then
		return self.total
	else
		return self.char.sets[s]
	end
end

function Skada:DeleteSet(set)
	if set then
		for i, s in ipairs(self.char.sets) do
			if s == set then
				local todel = tremove(self.char.sets, i)
				self.callbacks:Fire("SKADA_DATA_SETDELETED", i, todel)

				if set == self.last then
					self.last = nil
				end

				-- Don't leave windows pointing to deleted sets
				for _, win in self:IterateWindows() do
					if win.selectedset == i or win:get_selected_set() == set then
						win.selectedset = "current"
						win.changed = true
					elseif (tonumber(win.selectedset) or 0) > i then
						win.selectedset = win.selectedset - 1
						win.changed = true
					end
					win:RestoreView()
				end
				break
			end
		end

		self:Wipe()
		self:CleanGarbage(true)
		self:UpdateDisplay(true)
	end
end

function Skada:GetSetTime(set)
	local settime = 0
	if set then
		if (set.time or 0) > 0 then
			settime = set.time
		else
			settime = math_max(time() - set.starttime, 0.1)
		end
	end
	return settime
end

function Skada:GetFormatedSetTime(set)
	return self:FormatTime(self:GetSetTime(set))
end

-- ================ --
-- GETTER FUNCTIONS --
-- ================ --

function Skada:ClearIndexes(set)
	if set then
		set._playeridx = nil
	end
end

function Skada:ClearAllIndexes()
	Skada:ClearIndexes(self.current)
	Skada:ClearIndexes(self.char.total)
	for _, set in pairs(self.char.sets) do
		Skada:ClearIndexes(set)
	end
end

do
	local specIDs = {
		["MAGE"] = {62, 63, 64},
		["PRIEST"] = {256, 257, 258},
		["ROGUE"] = {259, 260, 261},
		["WARLOCK"] = {265, 266, 267},
		["WARRIOR"] = {71, 72, 73},
		["PALADIN"] = {65, 66, 70},
		["DEATHKNIGHT"] = {250, 251, 252},
		["DRUID"] = {102, 103, 104, 105},
		["HUNTER"] = {253, 254, 255},
		["SHAMAN"] = {262, 263, 264}
	}

	local function GetDruidSubSpec(unit)
		-- 57881 : Natural Reaction -- used by druid tanks
		local points = LGT:UnitHasTalent(unit, Skada.GetSpellInfo(57881), LGT:GetActiveTalentGroup(unit))
		if points and points > 0 then
			return 3 -- druid tank
		else
			return 2
		end
	end

	function Skada:GetPlayerSpecID(playername, playerclass)
		local specIdx = 0

		if playername then
			playerclass = playerclass or select(2, UnitClass(playername))
			if playerclass and specIDs[playerclass] then
				local talantGroup = LGT:GetActiveTalentGroup(playername)
				local maxPoints, index = 0, 0

				for i = 1, MAX_TALENT_TABS do
					local name, icon, pointsSpent = LGT:GetTalentTabInfo(playername, i, talantGroup)
					if pointsSpent ~= nil then
						if maxPoints < pointsSpent then
							maxPoints = pointsSpent
							if playerclass == "DRUID" and i >= 2 then
								if i == 3 then
									index = 4
								elseif i == 2 then
									index = GetDruidSubSpec(playername)
								end
							else
								index = i
							end
						end
					end
				end

				if specIDs[playerclass][index] then
					specIdx = specIDs[playerclass][index]
				end
				talantGroup, maxPoints, index = nil, nil, nil
			end
		end

		return specIdx
	end

	-- proper way of getting role icon using LibGroupTalents
	function Skada:UnitGroupRolesAssigned(unit)
		local role = LGT:GetUnitRole(unit) or "NONE"
		if role == "melee" or role == "caster" then
			role = "DAMAGER"
		elseif role == "tank" then
			role = "TANK"
		elseif role == "healer" then
			role = "HEALER"
		end
		return role
	end

	-- sometimes GUID are shown instead of proper players names
	-- this function is called and used only once per player
	function Skada:FixPlayer(player, force)
		if player.id and player.name then
			-- collect some info from the player's guid
			local name, class, _

			-- the only way to fix this error is to literally
			-- ignore it if we don't have a valid GUID.
			if player.id and #player.id ~= 18 then
				self.callbacks:Fire("SKADA_PLAYER_FIX", player)
				return player
			elseif player.id and #player.id == 18 then
				class, _, _, _, name = select(2, GetPlayerInfoByGUID(player.id))
			end

			-- fix the name
			if player.id == player.name and name and name ~= player.name then
				player.name = name
			end

			-- use LibTranslit to convert cyrillic letters into western letters.
			if self.db.profile.translit and Translit and not force then
				player.altname = Translit:Transliterate(player.name, "!")
			end

			-- fix the pet classes
			if pets[player.id] then
				-- fix classes for others
				player.class = "PET"
				player.owner = pets[player.id]
			else
				local isboss, npcid = self:IsBoss(player.id)
				if isboss then
					player.class = "BOSS"
				elseif (npcid or 0) > 0 then
					player.class = "MONSTER"
				end
			end

			-- still no class assigned?
			if force or not player.class then
				-- class already received from GetPlayerInfoByGUID?
				if class then
					player.class = class
				-- it's a real player?
				elseif UnitIsPlayer(player.name) or self:IsPlayer(player.id, player.flags) then
					player.class = select(2, UnitClass(player.name))
				elseif player.flags and band(player.flags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 then
					player.class = "PLAYER"
				-- pets?
				elseif player.flags and band(player.flags, BITMASK_PETS) ~= 0 then
					player.class = "PET"
					player.owner = pets[player.id]
				--  last solution
				else
					player.class = "UNKNOWN"
				end
			end

			-- if the player has been assigned a valid class,
			-- we make sure to assign his/her role and spec
			if self.validclass[player.class] then
				if force or not player.role then
					player.role = self:UnitGroupRolesAssigned(player.name)
				end
				if force or not player.spec then
					player.spec = self:GetPlayerSpecID(player.name, player.class)
				end
			end

			self.callbacks:Fire("SKADA_PLAYER_FIX", player)
			name, class = nil, nil
		end
	end
end

function Skada:find_player(set, playerid, playername, strict)
	if set and playerid and playerid ~= "total" then
		set._playeridx = set._playeridx or {}

		local player = set._playeridx[playerid]
		if player then
			return player
		end

		-- search the set
		for _, p in self:IteratePlayers(set) do
			if p.id == playerid then
				set._playeridx[playerid] = p
				return p
			end
		end

		-- needed for certain bosses
		local isboss, npcid, npcname = self:IsBoss(playerid, playername)
		if isboss then
			player = {
				id = playerid,
				name = npcname or playername,
				class = "BOSS"
			}
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

function Skada:get_player(set, playerid, playername, playerflags)
	if not set or not playerid then return end

	local player = self:find_player(set, playerid, playername, true)
	local now = time()

	if not player then
		if not playername then return end

		player = {
			id = playerid,
			name = playername,
			flags = playerflags,
			first = now,
			time = 0
		}

		self:FixPlayer(player)

		for _, mode in ipairs(modes) do
			if mode.AddPlayerAttributes ~= nil then
				mode:AddPlayerAttributes(player, set)
			end
		end

		tinsert(set.players, player)
	end

	-- not all modules provide playerflags
	if playerflags and not (player.flags or player.flags == playerflags) then
		player.flags = playerflags
	end

	player.first = player.first or now
	player.last = now
	changed = true
	self.callbacks:Fire("SKADA_PLAYER_GET", player)
	return player
end

function Skada:IsPlayer(guid, flags)
	if guid and players[guid] then
		return true
	end
	if flags and band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 then
		return true
	end
	return false
end

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
		[32930] = LBB["Kologarn"], -- Kologarn
		[32933] = LBB["Kologarn"], -- Left Arm
		[32934] = LBB["Kologarn"], -- Right Arm
		[33288] = LBB["Yogg-Saron"], -- Yogg-Saron
		[33890] = LBB["Yogg-Saron"], -- Brain of Yogg-Saron
		[33136] = LBB["Yogg-Saron"] -- Guardian of Yogg-Saron
	}

	function Skada:IsBoss(guid, name)
		local isboss, npcid, npcname = false, 0, nil
		if guid then
			local id = tonumber(guid:sub(9, 12), 16)
			if id and (LBI.BossIDs[id] or custom[id]) then
				isboss, npcid = true, id
				if custom[id] then
					npcname = (name and name ~= custom[id]) and name or custom[id]
				end
			elseif (id or 0) > 0 then
				npcid = id
			end
		end
		return isboss, npcid, npcname
	end
end

-- ================== --
-- PETS FUNCTIONS --
-- ================== --

do
	-- create our scan tooltip
	local tooltip = CreateFrame("GameTooltip", "SkadaPetTooltip", nil, "GameTooltipTemplate")
	tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

	function GetRussianPetOwner(text, name)
		for gender = 2, 3 do
			for decset = 1, GetNumDeclensionSets(name, gender) do
				local genitive = DeclineName(name, gender, decset)
				if text:find(genitive) then
					return true
				end
			end
		end
		return false
	end

	local GAME_LOCALE = GetLocale()
	local function GetPetOwnerFromTooltip(guid)
		if not Skada.current then return end
		tooltip:SetHyperlink("unit:" .. guid)

		for i = 2, tooltip:NumLines() do
			local text = _G["SkadaPetTooltipTextLeft" .. i] and _G["SkadaPetTooltipTextLeft" .. i]:GetText()
			if text and text ~= "" then
				for _, p in Skada:IteratePlayers(Skada.current) do
					local playername = p.name:gsub("%-.*", "") -- remove realm
					if GAME_LOCALE == "ruRU" then
						if text and GetRussianPetOwner(text, playername) then
							return {id = p.id, name = p.name}
						else
							if text:find(playername) then
								return {id = p.id, name = p.name}
							end
						end
					else
						if text:find(playername) then
							return {id = p.id, name = p.name}
						end
					end
				end
			end
		end
	end

	function Skada:AssignPet(ownerGUID, ownerName, petGUID)
		pets[petGUID] = {id = ownerGUID, name = ownerName}
		self.callbacks:Fire("SKADA_PET_ASSIGN", petGUID, ownerGUID, ownerName)
	end

	function Skada:GetPetOwner(petGUID)
		return pets[petGUID] or GetPetOwnerFromTooltip(petGUID)
	end

	function Skada:IsPet(petGUID, petFlags)
		if petGUID and (pets[petGUID] or GetPetOwnerFromTooltip(petGUID)) then
			return true
		end

		if petFlags and band(petFlags, BITMASK_PETS) ~= 0 then
			return true
		end

		return false
	end

	function Skada:FixPets(action)
		if action and action.playerid and action.playername then
			local owner = pets[action.playerid]

			-- we try to associate pets and and guardians with their owner
			if not owner and action.playerflags and band(action.playerflags, BITMASK_PETS) ~= 0 and band(action.playerflags, BITMASK_GROUP) ~= 0 then
				-- my own pets or guardians?
				if band(action.playerflags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 then
					owner = {id = UnitGUID("player"), name = GetUnitName("player")}
				end

				-- not found? our last hope is the tooltip
				if not owner then
					owner = GetPetOwnerFromTooltip(action.playerid)
				end

				if not owner then
					-- action.playerid = action.playername -- in order to create a single entry
					action = wipe(action or {}) -- ignore them
				elseif not pets[action.playerid] then
					pets[action.playerid] = owner
				end
			end

			if owner then
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
			end
		end
	end
end

function Skada:FixMyPets(playerid, playername)
	if pets[playerid] then
		return pets[playerid].id, pets[playerid].name
	end
	return playerid, playername
end

function Skada:PetDebug()
	self:CheckGroup()
	self:Print("pets:")
	for pet, owner in pairs(pets) do
		self:Print("pet " .. pet .. " belongs to " .. owner.id .. ", " .. owner.name)
	end
end

-- ================= --
-- TOOLTIP FUNCTIONS --
-- ================= --

function Skada:SetTooltipPosition(tooltip, frame, display)
	if self.db.profile.tooltippos == "default" then
		tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		tooltip:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -40, 40)
	elseif self.db.profile.tooltippos == "topleft" then
		tooltip:SetOwner(frame, "ANCHOR_NONE")
		tooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT")
	elseif self.db.profile.tooltippos == "topright" then
		tooltip:SetOwner(frame, "ANCHOR_NONE")
		tooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT")
	elseif self.db.profile.tooltippos == "bottomleft" then
		tooltip:SetOwner(frame, "ANCHOR_NONE")
		tooltip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT")
	elseif self.db.profile.tooltippos == "bottomright" then
		tooltip:SetOwner(frame, "ANCHOR_NONE")
		tooltip:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT")
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

	local ttwin = Window:new()
	local white = {r = 1, g = 1, b = 1}

	function Skada:AddSubviewToTooltip(tooltip, win, mode, id, label)
		if not mode then return end

		local ttwin = win.ttwin or Window:new()
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
				numLines = nil
			end

			if self.db.profile.informativetooltips then
				if win.metadata.click1 then
					self:AddSubviewToTooltip(t, win, win.metadata.click1, id, label)
				end
				if win.metadata.click2 then
					self:AddSubviewToTooltip(t, win, win.metadata.click2, id, label)
				end
				if win.metadata.click3 then
					self:AddSubviewToTooltip(t, win, win.metadata.click3, id, label)
				end
			end

			if win.metadata.post_tooltip then
				local numLines = t:NumLines()
				win.metadata.post_tooltip(win, id, label, t)

				if t:NumLines() ~= numLines and hasClick then
					t:AddLine(" ")
				end
				numLines = nil
			end
			hasClick = nil

			if win.metadata.click1 then
				t:AddLine(L["Click for"] .. " |cff00ff00" .. win.metadata.click1:GetName() .. "|r.", 1, 0.82, 0)
			end
			if win.metadata.click2 then
				t:AddLine(L["Shift-Click for"] .. " |cff00ff00" .. win.metadata.click2:GetName() .. "|r.", 1, 0.82, 0)
			end
			if win.metadata.click3 then
				t:AddLine(L["Control-Click for"] .. " |cff00ff00" .. win.metadata.click3:GetName() .. "|r.", 1, 0.82, 0)
			end

			t:Show()
		end
	end
end

-- ============== --
-- SLACH COMMANDS --
-- ============== --

function Skada:Command(param)
	if param == "pets" then
		self:PetDebug()
	elseif param == "test" then
		Skada:Notify("test")
	elseif param == "reset" then
		self:Reset()
	elseif param == "newsegment" then
		self:NewSegment()
	elseif param == "toggle" then
		self:ToggleWindow()
	elseif param == "debug" then
		self.db.profile.debug = not self.db.profile.debug
		Skada:Print("Debug mode "..(self.db.profile.debug and ("|cFF00FF00"..L["ENABLED"].."|r") or ("|cFFFF0000"..L["DISABLED"].."|r")))
	elseif param == "config" then
		self:OpenOptions()
	elseif param == "clear" or param == "clean" then
		self:CleanGarbage(true)
	elseif param == "website" or param == "github" then
		self:Print(format("|cffffbb00%s|r", self.website))
	elseif param:sub(1, 6) == "report" then
		param = param:sub(7)

		local w1, w2, w3 = self:GetArgs(param, 3)

		local chan = w1 or "say"
		local report_mode_name = w2 or L["Damage"]
		local num = tonumber(w3 or 10)
		w1, w2, w3 = nil, nil, nil

		-- Sanity checks.
		if chan and (chan == "say" or chan == "guild" or chan == "raid" or chan == "party" or chan == "officer") and (report_mode_name and self:find_mode(report_mode_name)) then
			self:Report(chan, "preset", report_mode_name, "current", num)
		else
			self:Print("Usage:")
			self:Print(format("%-20s", "/skada report [raid|guild|party|officer|say] [mode] [max lines]"))
		end
	else
		self:Print("Usage:")
		self:Print(format("%-20s", "|cffffaeae/skada|r |cffffff33report|r [raid|guild|party|officer|say] [mode] [max lines]"))
		self:Print(format("%-20s", "|cffffaeae/skada|r |cffffff33reset|r"))
		self:Print(format("%-20s", "|cffffaeae/skada|r |cffffff33toggle|r"))
		self:Print(format("%-20s", "|cffffaeae/skada|r |cffffff33newsegment|r"))
		self:Print(format("%-20s", "|cffffaeae/skada|r |cffffff33config|r"))
		self:Print(format("%-20s", "|cffffaeae/skada|r |cffffff33clean|r"))
		self:Print(format("%-20s", "|cffffaeae/skada|r |cffffff33website|r"))
		self:Print(format("%-20s", "|cffffaeae/skada|r |cffffff33debug|r"))
	end
end

-- =============== --
-- REPORT FUNCTION --
-- =============== --
do
	local SendChatMessage = SendChatMessage

	local function sendchat(msg, chan, chantype)
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
			report_mode = self:find_mode(report_mode_name)
			report_set = self:GetSet(report_set_name)
			if report_set == nil then return end

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
		local label = (report_mode_name == L["Improvement"]) and GetUnitName("player") or Skada:GetSetLabel(report_set)
		sendchat(format(L["Skada: %s for %s:"], title, label), channel, chantype)

		local nr = 1
		for _, data in ipairs(report_table.dataset) do
			if ((barid and barid == data.id) or (data.id and not barid)) and not data.ignore then
				local label
				if data.reportlabel then
					label = data.reportlabel
				elseif self.db.profile.reportlinks and (data.spellid or data.hyperlink) then
					label = format("%s   %s", data.hyperlink or self.GetSpellLink(data.spellid) or data.text or data.label, data.valuetext)
				else
					label = format("%s   %s", data.text or data.label, data.valuetext)
				end

				if label and report_mode.metadata and report_mode.metadata.showspots then
					sendchat(format("%s. %s", nr, label), channel, chantype)
				elseif label then
					sendchat(label, channel, chantype)
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

-- ============== --
-- FEED FUNCTIONs --
-- ============== --

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

-- ======================================================= --

function Skada:CheckGroup()
	local prefix, count = GetGroupTypeAndCount()
	if count > 0 then
		for i = 1, count, 1 do
			local unit = ("%s%d"):format(prefix, i)
			local unitGUID = UnitGUID(unit)
			if unitGUID then
				players[unitGUID] = true
				local petGUID = UnitGUID(unit .. "pet")
				if petGUID and not pets[petGUID] then
					self:AssignPet(unitGUID, GetUnitName(unit), petGUID)
				end
			end
		end
	end

	local playerGUID = UnitGUID("player")
	if playerGUID then
		players[playerGUID] = true
		local petGUID = UnitGUID("pet")
		if petGUID and not pets[petGUID] then
			self:AssignPet(playerGUID, GetUnitName("player"), petGUID)
		end
	end
end

function Skada:ZoneCheck()
	local inInstance, instanceType = IsInInstance()

	local isininstance = inInstance and (instanceType == "party" or instanceType == "raid")
	local isinpvp = self:IsInPVP()

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
	wasinparty = (IsInGroup() or IsInRaid())
end

do
	local version_count, version_timer = 0

	function checkVersion()
		Skada:SendComm(nil, nil, "VersionCheck", Skada.version)
		if version_timer then
			version_timer:Cancel()
			version_timer = nil
		end
	end

	function convertVersion(ver)
		return tonumber(type(ver) == "string" and ver:gsub("%.", "") or ver)
	end

	function Skada:OnCommVersionCheck(sender, version)
		if sender and sender ~= GetUnitName("player") and version then
			version = convertVersion(version)
			local ver = convertVersion(self.version)
			if not (version and ver) or self.versionChecked then return end

			if (version > ver) then
				self:Print(format(L["Skada is out of date. You can download the newest version from |cffffbb00%s|r"], self.website))
			elseif (version < ver) then
				self:SendComm("WHISPER", sender, "VersionCheck", self.version)
			end

			self.versionChecked = true
		end
	end

	local function check_for_join_and_leave()
		if not IsInGroup() and wasinparty then
			if Skada.db.profile.reset.leave == 3 and Skada:CanReset() then
				Skada:ShowPopup(nil, true)
			elseif Skada.db.profile.reset.leave == 2 and Skada:CanReset() then
				Skada:Reset()
			end

			if Skada.db.profile.hidesolo then
				Skada:SetActive(false)
			end
		end

		if IsInGroup() and not wasinparty then
			if Skada.db.profile.reset.join == 3 and Skada:CanReset() then
				Skada:ShowPopup(nil, true)
			elseif Skada.db.profile.reset.join == 2 and Skada:CanReset() then
				Skada:Reset()
			end

			if Skada.db.profile.hidesolo and not (Skada.db.profile.hidepvp and Skada:IsInPVP()) then
				Skada:SetActive(true)
			end
		end

		wasinparty = not (not IsInGroup())
	end

	function Skada:PLAYER_ENTERING_WORLD()
		self:ZoneCheck()
		if not wasinparty then
			self.After(2, function()
				check_for_join_and_leave()
				self:CheckGroup()
			end)
		end

		version_timer = self.NewTimer(10, checkVersion)
		clean_timer = self.NewTicker(60, function() collectgarbage("collect") end)
	end

	function Skada:PARTY_MEMBERS_CHANGED()
		check_for_join_and_leave()
		self:CheckGroup()

		-- version check
		local t, count = GetGroupTypeAndCount()
		if t == "party" then
			count = count + 1
		end
		if count ~= version_count then
			if count > 1 and count > version_count then
				version_timer = version_timer or self.NewTimer(10, checkVersion)
			end
			version_count = count
		end
	end
	Skada.RAID_ROSTER_UPDATE = Skada.PARTY_MEMBERS_CHANGED
end

function Skada:UNIT_PET()
	self:CheckGroup()
end

-- ======================================================= --

function Skada:CanReset()
	local totalplayers = self.total and self.total.players
	if totalplayers and next(totalplayers) then
		return true
	end

	for _, set in ipairs(self.char.sets) do
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
		self.After(3, function() self:ReloadSettings() end)
		return
	end

	self:Wipe()
	players, pets = {}, {}
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
	self:Print(L["All data has been reset."])
	L_CloseDropDownMenus()

	self.callbacks:Fire("SKADA_DATA_RESET")
	self:CleanGarbage(true)
end

function Skada:UpdateDisplay(force)
	if force then
		changed = true
	end

	if selectedfeed ~= nil then
		local feedtext = selectedfeed()
		if feedtext then
			dataobj.text = feedtext
		end
	end

	for _, win in self:IterateWindows() do
		if (changed or win.changed) or self.current then
			win.changed = false

			if win.selectedmode then
				local set = win:get_selected_set()

				if set then
					win:UpdateInProgress()

					if win.selectedmode.Update then
						if set then
							win.selectedmode:Update(win, set)
						else
							self:Print("No set available to pass to " .. win.selectedmode:GetName() .. " Update function! Try to reset Skada.")
						end
					elseif win.selectedmode.GetName then
						self:Print("Mode " .. win.selectedmode:GetName() .. " does not have an Update function!")
					end

					if self.db.profile.showtotals and win.selectedmode.GetSetSummary then
						local total, existing = 0, nil

						for _, data in ipairs(win.dataset) do
							if data.id then
								total = total + data.value
							end
							if not existing and not data.id then
								existing = data
							end
						end
						total = total + 1

						local d = existing or {}
						d.id = "total"
						d.label = L["Total"]
						d.ignore = true
						d.icon = (self.db.profile.moduleicons and win.selectedmode.metadata) and win.selectedmode.metadata.icon or dataobj.icon
						d.value = total
						d.valuetext = win.selectedmode:GetSetSummary(set)
						if not existing then
							tinsert(win.dataset, 1, d)
						end
					end
				end

				win:UpdateDisplay()
			elseif win.selectedset then
				local set = win:get_selected_set()

				for m, mode in ipairs(modes) do
					local d = win.dataset[m] or {}
					win.dataset[m] = d

					d.id = mode:GetName()
					d.label = mode:GetName()
					d.value = 1

					if set and mode.GetSetSummary ~= nil then
						d.valuetext = mode:GetSetSummary(set)
					end
					d.icon = (self.db.profile.moduleicons and mode.metadata) and mode.metadata.icon
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

				for _, set in ipairs(self.char.sets) do
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

	changed = false
end

-- ======================================================= --

function Skada:FormatNumber(number)
	if number then
		if self.db.profile.numberformat == 1 then
			if number > 1000000000 then
				return format("%02.3fB", number / 1000000000)
			elseif number > 1000000 then
				return format("%02.2fM", number / 1000000)
			elseif number > 1000 then
				return format("%02.1fK", number / 1000)
			else
				return math_floor(number)
			end
		elseif self.db.profile.numberformat == 2 then
			local left, num, right = tostring(math_floor(number)):match("^([^%d]*%d)(%d*)(.-)$")
			return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
		else
			return math_floor(number)
		end
	end
end

function Skada:FormatTime(sec)
	if sec then
		if sec >= 3600 then
			local h = math_floor(sec / 3600)
			local m = math_floor(sec / 60 - (h * 60))
			local s = math_floor(sec - h * 3600 - m * 60)
			return format("%02.f:%02.f:%02.f", h, m, s)
		end

		return format("%02.f:%02.f", math_floor(sec / 60), math_floor(sec % 60))
	end
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
	local numsetfmts = 8

	local function SetLabelFormat(name, starttime, endtime, fmt)
		fmt = fmt or Skada.db.profile.setformat
		local namelabel = name
		if fmt < 1 or fmt > numsetfmts then
			fmt = 3
		end

		local timelabel = ""
		if starttime and endtime and fmt > 1 then
			local duration = SecondsToTime(endtime - starttime, false, false, 2)

			Skada.getsetlabel_fs = Skada.getsetlabel_fs or UIParent:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
			Skada.getsetlabel_fs:SetText(duration)
			duration = "(" .. Skada.getsetlabel_fs:GetText() .. ")"

			if fmt == 2 then
				timelabel = duration
			elseif fmt == 3 then
				timelabel = date("%H:%M", starttime) .. " " .. duration
			elseif fmt == 4 then
				timelabel = date("%I:%M", starttime) .. " " .. duration
			elseif fmt == 5 then
				timelabel = date("%H:%M", starttime) .. " - " .. date("%H:%M", endtime)
			elseif fmt == 6 then
				timelabel = date("%I:%M", starttime) .. " - " .. date("%I:%M", endtime)
			elseif fmt == 7 then
				timelabel = date("%H:%M:%S", starttime) .. " - " .. date("%H:%M:%S", endtime)
			elseif fmt == 8 then
				timelabel = date("%H:%M", starttime) .. " - " .. date("%H:%M", endtime) .. " " .. duration
			end
		end

		local comb
		if #namelabel == 0 or #timelabel == 0 then
			comb = namelabel .. timelabel
		elseif timelabel:match("^%p") then
			comb = namelabel .. " " .. timelabel
		else
			comb = namelabel .. ": " .. timelabel
		end

		return comb, namelabel, timelabel
	end

	function Skada:SetLabelFormats()
		local ret, start = {}, 1000007900
		for i = 1, numsetfmts do
			ret[i] = SetLabelFormat("Hogger", start, start + 380, i)
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
		if not self.selectedmode or not self.selectedset then return end
		if not self.selectedmode.GetName then return end
		local name = self.parenttitle or self.selectedmode.title or self.selectedmode:GetName()

		-- save window settings for RestoreView after reload
		self.db.set = self.selectedset
		local savemode = name
		if self.history[1] then -- can't currently preserve a nested mode, use topmost one
			savemode = self.history[1].title or self.history[1]:GetName()
		end
		self.db.mode = savemode
		savemode = nil

		name = self.title or name
		if self.db.titleset and not self.selectedmode.notitleset and self.db.display ~= "inline" then
			local setname
			if self.selectedset == "current" then
				setname = L["Current"]
			elseif self.selectedset == "total" then
				setname = L["Total"]
			else
				local set = self:get_selected_set()
				if set then
					setname = Skada:GetSetLabel(set)
				end
			end
			if setname then
				name = name .. ": " .. setname
			end
		end
		if disabled and (self.selectedset == "current" or self.selectedset == "total") then
			-- indicate when data collection is disabled
			name = name .. "  |cFFFF0000" .. L["DISABLED"] .. "|r"
		elseif not self.selectedmode.notitleset and self.db.enabletitle and self.db.combattimer and (self.selectedset == "current" or self.selectedset == "last") and (Skada.current or Skada.last) then
			-- thanks Details! for the idea.
			name = format("[%s] %s", Skada:GetFormatedSetTime(Skada.current or Skada.last), name)
		end
		self.metadata.title = name
		self.display:SetTitle(self, name)
		name = nil
	end
end

function Window:RestoreView(theset, themode)
	if self.history[1] then
		-- clear history and title
		self.history, self.title = wipe(self.history or {}), nil

		-- all all stuff that were registered by modules
		self.playerid, self.playername = nil, nil
		self.spellid, self.spellname = nil, nil
		self.targetid, self.targetname = nil, nil
	end

	-- force menu to close and let Skada handle the rest
	L_CloseDropDownMenus()
	Skada:RestoreView(self, theset or self.selectedset, themode or self.db.mode)
end

-- ======================================================= --

function dataobj:OnEnter()
	self.tooltip = self.tooltip or GameTooltip
	self.tooltip:SetOwner(self, "ANCHOR_NONE")
	self.tooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
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
		for _, mode in ipairs(modes) do
			if mode.AddToTooltip ~= nil then
				mode:AddToTooltip(set, self.tooltip)
			end
		end
		self.tooltip:AddLine(" ")
	else
		self.tooltip:AddDoubleLine("Skada", Skada.version)
	end

	self.tooltip:AddLine(L["|cffeda55fLeft-Click|r to toggle windows."], 0.2, 1, 0.2)
	self.tooltip:AddLine(L["|cffeda55fShift+Left-Click|r to reset."], 0.2, 1, 0.2)
	self.tooltip:AddLine(L["|cffeda55fRight-Click|r to open menu."], 0.2, 1, 0.2)

	self.tooltip:Show()
end

function dataobj:OnLeave()
	self.tooltip:Hide()
end

function dataobj:OnClick(button)
	if button == "LeftButton" and IsShiftKeyDown() then
		Skada:ShowPopup()
	elseif button == "LeftButton" then
		Skada:ToggleWindow()
	elseif button == "RightButton" then
		Skada:OpenMenu()
	end
end

function Skada:OpenOptions(win)
	ACD:SetDefaultSize("Skada", 610, 500)
	if win then
		ACD:Open("Skada")
		ACD:SelectGroup("Skada", "windows", win.db.name)
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

function Skada:ApplySettings()
	for _, win in self:IterateWindows() do
		win:SetChild(win.db.child)
		win.display:ApplySettings(win)
	end

	if (self.db.profile.hidesolo and not IsInGroup()) or (self.db.profile.hidepvp and self:IsInPVP()) then
		self:SetActive(false)
	else
		self:SetActive(true)

		for _, win in self:IterateWindows() do
			if (win.db.hidden or (not win.db.hidden and self.db.profile.showcombat)) and win:IsShown() then
				win:Hide()
			end
		end
	end

	self.effectivetime = (self.db.profile.timemesure == 2)
	self:UpdateDisplay(true)

	-- in case of future code change or database structure changes, this
	-- code here will be used to perform any database modifications.
	local curversion = convertVersion(self.version)
	if type(self.db.global.version) ~= "number" or curversion > self.db.global.version then
		self.callbacks:Fire("SKADA_CORE_UPDATE", self.db.global.version)
		self.db.global.version = curversion
	end
	if type(self.char.version) ~= "number" or curversion > self.char.version then
		self.callbacks:Fire("SKADA_DATA_UPDATE", self.char.version)
		self:Reset(true)
		self.char.version = curversion
	end
end

function Skada:ReloadSettings()
	for _, win in self:IterateWindows() do
		win:destroy()
	end
	windows = {}

	for _, win in ipairs(self.db.profile.windows) do
		self:CreateWindow(win.name, win)
	end

	self.total = self.char.total

	Skada:ClearAllIndexes()

	if DBI and not DBI:IsRegistered("Skada") then
		DBI:Register("Skada", dataobj, self.db.profile.icon)
	end
	self:RefreshMMButton()
	self:ApplySettings()
end

-- ======================================================= --

function Skada:ApplyBorder(frame, texture, color, thickness, padtop, padbottom, padleft, padright)
	local borderbackdrop = {}

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
	if color then
		frame.borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
	end
end

function Skada:FrameSettings(db, include_dimensions)
	local obj = {
		type = "group",
		name = L["Window"],
		order = 3,
		args = {
			bgheader = {
				type = "header",
				name = L["Background"],
				order = 1,
				width = "double"
			},
			texture = {
				type = "select",
				dialogControl = "LSM30_Background",
				name = L["Background texture"],
				desc = L["The texture used as the background."],
				order = 2,
				width = "double",
				values = AceGUIWidgetLSMlists.background,
				get = function()
					return db.background.texture
				end,
				set = function(_, key)
					db.background.texture = key
					Skada:ApplySettings()
				end
			},
			tile = {
				type = "toggle",
				name = L["Tile"],
				desc = L["Tile the background texture."],
				order = 3,
				width = "double",
				get = function()
					return db.background.tile
				end,
				set = function(_, key)
					db.background.tile = key
					Skada:ApplySettings()
				end
			},
			tilesize = {
				type = "range",
				name = L["Tile size"],
				desc = L["The size of the texture pattern."],
				order = 4,
				width = "double",
				min = 0,
				max = math_floor(GetScreenWidth()),
				step = 1.0,
				get = function()
					return db.background.tilesize
				end,
				set = function(_, val)
					db.background.tilesize = val
					Skada:ApplySettings()
				end
			},
			color = {
				type = "color",
				name = L["Background color"],
				desc = L["The color of the background."],
				order = 5,
				width = "double",
				hasAlpha = true,
				get = function(_)
					local c = db.background.color
					return c.r, c.g, c.b, c.a
				end,
				set = function(_, r, g, b, a)
					db.background.color = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings()
				end
			},
			borderheader = {
				type = "header",
				name = L["Border"],
				order = 6,
				width = "double"
			},
			bordertexture = {
				type = "select",
				dialogControl = "LSM30_Border",
				name = L["Border texture"],
				desc = L["The texture used for the borders."],
				order = 7,
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
					Skada:ApplySettings()
				end
			},
			bordercolor = {
				type = "color",
				name = L["Border color"],
				desc = L["The color used for the border."],
				order = 8,
				width = "double",
				hasAlpha = true,
				get = function(_)
					local c = db.background.bordercolor or {r = 0, g = 0, b = 0, a = 1}
					return c.r, c.g, c.b, c.a
				end,
				set = function(_, r, g, b, a)
					db.background.bordercolor = {["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a}
					Skada:ApplySettings()
				end
			},
			thickness = {
				type = "range",
				name = L["Border thickness"],
				desc = L["The thickness of the borders."],
				order = 9,
				width = "double",
				min = 0,
				max = 50,
				step = 0.5,
				get = function()
					return db.background.borderthickness
				end,
				set = function(_, val)
					db.background.borderthickness = val
					Skada:ApplySettings()
				end
			},
			optionheader = {
				type = "header",
				name = L["General"],
				order = 10,
				width = "double"
			},
			scale = {
				type = "range",
				name = L["Scale"],
				desc = L["Sets the scale of the window."],
				order = 11,
				width = "double",
				min = 0.1,
				max = 3,
				step = 0.01,
				get = function()
					return db.scale
				end,
				set = function(_, val)
					db.scale = val
					Skada:ApplySettings()
				end
			},
			strata = {
				type = "select",
				name = L["Strata"],
				desc = L["This determines what other frames will be in front of the frame."],
				order = 12,
				width = "double",
				values = {
					["BACKGROUND"] = "BACKGROUND",
					["LOW"] = "LOW",
					["MEDIUM"] = "MEDIUM",
					["HIGH"] = "HIGH",
					["DIALOG"] = "DIALOG",
					["FULLSCREEN"] = "FULLSCREEN",
					["FULLSCREEN_DIALOG"] = "FULLSCREEN_DIALOG"
				},
				get = function()
					return db.strata
				end,
				set = function(_, val)
					db.strata = val
					Skada:ApplySettings()
				end
			}
		}
	}

	if include_dimensions then
		obj.args.width = {
			type = "range",
			name = L["Width"],
			order = 4.3,
			min = 100,
			max = math_floor(GetScreenWidth()),
			step = 1.0,
			get = function()
				return db.width
			end,
			set = function(_, key)
				db.width = key
				Skada:ApplySettings()
			end
		}

		obj.args.height = {
			type = "range",
			name = L["Height"],
			order = 4.4,
			min = 16,
			max = 400,
			step = 1.0,
			get = function()
				return db.height
			end,
			set = function(_, key)
				db.height = key
				Skada:ApplySettings()
			end
		}
	end

	return obj
end

-- ======================================================= --

function Skada:OnInitialize()
	LSM:Register("font", "ABF", [[Interface\Addons\Skada\Media\Fonts\ABF.ttf]])
	LSM:Register("font", "Accidental Presidency", [[Interface\Addons\Skada\Media\Fonts\Accidental Presidency.ttf]])
	LSM:Register("font", "Adventure", [[Interface\Addons\Skada\Media\Fonts\Adventure.ttf]])
	LSM:Register("font", "Diablo", [[Interface\Addons\Skada\Media\Fonts\Diablo.ttf]])
	LSM:Register("font", "Forced Square", [[Interface\Addons\Skada\Media\Fonts\FORCED SQUARE.ttf]])
	LSM:Register("font", "Hooge", [[Interface\Addons\Skada\Media\Fonts\Hooge.ttf]])

	LSM:Register("statusbar", "Aluminium", [[Interface\Addons\Skada\Media\Statusbar\Aluminium]])
	LSM:Register("statusbar", "Armory", [[Interface\Addons\Skada\Media\Statusbar\Armory]])
	LSM:Register("statusbar", "BantoBar", [[Interface\Addons\Skada\Media\Statusbar\BantoBar]])
	LSM:Register("statusbar", "Details", [[Interface\AddOns\Skada\Media\Statusbar\Details]])
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
		self.options.args.profiles = AceDBOptions:GetOptionsTable(self.db)
		self.options.args.profiles.order = 999
	end

	LibStub("AceConfig-3.0"):RegisterOptionsTable("Skada", self.options)
	self.optionsFrame = ACD:AddToBlizOptions("Skada", "Skada")
	self:RegisterChatCommand("skada", "Command")

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

	-- class colors
	self.classcolors = {
		-- valid
		DEATHKNIGHT = {r = 0.77, g = 0.12, b = 0.23, colorStr = "ffc41f3b"},
		DRUID = {r = 1, g = 0.49, b = 0.04, colorStr = "ffff7d0a"},
		HUNTER = {r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473"},
		MAGE = {r = 0.41, g = 0.8, b = 0.94, colorStr = "ff3fc7eb"},
		PALADIN = {r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba"},
		PRIEST = {r = 1, g = 1, b = 1, colorStr = "ffffffff"},
		ROGUE = {r = 1, g = 0.96, b = 0.41, colorStr = "fffff569"},
		SHAMAN = {r = 0, g = 0.44, b = 0.87, colorStr = "ff0070de"},
		WARLOCK = {r = 0.58, g = 0.51, b = 0.79, colorStr = "ff8788ee"},
		WARRIOR = {r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e"},
		-- custom
		ENEMY = {r = 0.94117, g = 0, b = 0.0196, colorStr = "fff00005"},
		MONSTER = {r = 0.549, g = 0.388, b = 0.404, colorStr = "ff8c6367"},
		BOSS = {r = 0.203, g = 0.345, b = 0.525, colorStr = "345886"},
		PLAYER = {r = 0.94117, g = 0, b = 0.0196, colorStr = "fff00005"},
		PET = {r = 0.3, g = 0.4, b = 0.5, colorStr = "ff4c0566"},
		UNKNOWN = {r = 0.2, g = 0.2, b = 0.2, colorStr = "ff333333"}
	}

	-- class icon file & coordinates
	self.classiconfile = [[Interface\AddOns\Skada\Media\Textures\icon-classes]]
	self.classicontcoords = {}
	for class, coords in pairs(CLASS_ICON_TCOORDS) do
		self.classicontcoords[class] = coords
	end
	self.classicontcoords.ENEMY = {0, 0.25, 0.75, 1}
	self.classicontcoords.BOSS = {0.75, 1, 0.5, 0.75}
	self.classicontcoords.MONSTER = {0, 0.25, 0.75, 1}
	self.classicontcoords.PET = {0.25, 0.5, 0.75, 1}
	self.classicontcoords.PLAYER = {0.75, 1, 0.75, 1}
	self.classicontcoords.UNKNOWN = {0.5, 0.75, 0.75, 1}

	-- role icon file and coordinates
	self.roleiconfile = [[Interface\LFGFrame\UI-LFG-ICON-PORTRAITROLES]]
	self.roleicontcoords = {
		DAMAGER = {0.3125, 0.63, 0.3125, 0.63},
		HEALER = {0.3125, 0.63, 0.015625, 0.3125},
		TANK = {0, 0.296875, 0.3125, 0.63},
		LEADER = {0, 0.296875, 0.015625, 0.3125},
		NONE = ""
	}
end

function Skada:OnEnable()
	self:RegisterComm("Skada")
	self:ReloadSettings()

	-- we use this to be able to localize it
	L["Auto Attack"] = MELEE

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("RAID_ROSTER_UPDATE")
	self:RegisterEvent("UNIT_PET")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ZoneCheck")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatLogEvent")

	if self.modulelist then
		for i = 1, #self.modulelist do
			self.modulelist[i](self, L)
		end
		self.modulelist = nil
	end

	self.NewTicker(2, function() self:CleanGarbage() end)
	self.After(2, function() self:ApplySettings() end)
	self.After(3, function() self:MemoryCheck() end)

	if _G.BigWigs then
		self:RegisterMessage("BigWigs_Message", "BigWigs")
		self.bossmod = true
	elseif _G.DBM and _G.DBM.EndCombat then
		self:SecureHook(DBM, "EndCombat", "DBM")
		self.bossmod = true
	elseif self.bossmod then
		self.bossmod = nil
	end
end

function Skada:BigWigs(_, _, event)
	if event == "bosskill" and self.current and self.current.gotboss then
		self:Debug("COMBAT_BOSS_DEFEATED: BigWigs")
		self.current.success = true
		self.callbacks:Fire("COMBAT_BOSS_DEFEATED", self.current)
	end
end

function Skada:DBM(_, mod, wipe)
	if self.current and self.current.gotboss and not wipe and (mod and mod.combatInfo) then
		self:Debug("COMBAT_BOSS_DEFEATED: DBM")
		self.current.success = true
		self.callbacks:Fire("COMBAT_BOSS_DEFEATED", self.current)
	end
end

function Skada:MemoryCheck()
	if self.db.profile.memorycheck then
		UpdateAddOnMemoryUsage()

		local compare = 30 + (self.db.profile.setstokeep * 1.25)
		if GetAddOnMemoryUsage("Skada") > (compare * 1024) then
			self:Print(L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."])
		end
	end
end

function Skada:CleanGarbage(clean)
	CombatLogClearEntries()
	if clean and not InCombatLockdown() then
		collectgarbage("collect")
	end
end

-- ======================================================= --
-- AddOn Synchronization

do
	local AceSerializer = LibStub("AceSerializer-3.0")
	local LibCompress = LibStub("LibCompress")
	local encodeTable

	function Skada:Serialize(...)
		encodeTable = encodeTable or LibCompress:GetAddonEncodeTable()

		local result = LibCompress:CompressHuffman(AceSerializer:Serialize(...))
		return encodeTable:Encode(result)
	end

	function Skada:Deserialize(data)
		encodeTable = encodeTable or LibCompress:GetAddonEncodeTable()

		local err
		data, err = encodeTable:Decode(data), "Error decoding"
		if data then
			data, err = LibCompress:DecompressHuffman(data)
			if data then
				return AceSerializer:Deserialize(data)
			end
		end
		return false, err
	end

	function Skada:SendComm(channel, target, ...)
		if not channel then
			local groupType, _ = GetGroupTypeAndCount()
			if groupType == "player" then
				return -- with whom you want to sync man!
			elseif groupType == "raid" then
				channel = "RAID"
			elseif groupType == "party" then
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
			self:SendCommMessage("Skada", self:Serialize(...), channel, target)
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
		if prefix == "Skada" and channel and sender then
			DispatchComm(sender, self:Deserialize(message))
		end
	end
end

-- ======================================================= --

function Skada:IsRaidInCombat()
	if InCombatLockdown() then
		return true
	end

	local prefix, count = GetGroupTypeAndCount()
	if count > 0 then
		for i = 1, count, 1 do
			if UnitExists(prefix .. i) and UnitAffectingCombat(prefix .. i) then
				return true
			end
		end
	elseif UnitAffectingCombat("player") then
		return true
	end

	return false
end

function Skada:IsRaidDead()
	local prefix, count = GetGroupTypeAndCount()
	if count > 0 then
		for i = 1, count, 1 do
			if UnitExists(prefix .. i) and not UnitIsDeadOrGhost(prefix .. i) then
				return false
			end
		end
	elseif not UnitIsDeadOrGhost("player") then
		return false
	end

	return true
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

function Skada:EndSegment()
	if not self.current then return end

	local now = time()
	if not self.db.profile.onlykeepbosses or self.current.gotboss then
		if self.current.mobname ~= nil and now - self.current.starttime > 5 then
			self.current.endtime = self.current.endtime or now
			self.current.time = math_max(self.current.endtime - self.current.starttime, 0.1)
			setPlayerActiveTimes(self.current)
			self.current.stopped = nil

			local setname = self.current.mobname
			if self.db.profile.setnumber then
				local num = 0
				for _, set in ipairs(self.char.sets) do
					if set.name == setname and num == 0 then
						num = 1
					else
						local n, c = set.name:match("^(.-)%s*%((%d+)%)$")
						if n == setname then
							num = math_max(num, tonumber(c) or 0)
						end
					end
				end
				if num > 0 then
					setname = format("%s (%s)", setname, num + 1)
				end
			end
			self.current.name = setname

			for _, mode in ipairs(modes) do
				if mode.SetComplete then
					mode:SetComplete(self.current)
				end
			end

			tinsert(self.char.sets, 1, self.current)
		end
	end

	self.last = self.current
	self.last.started = nil

	if self.last.gotboss and self.db.profile.alwayskeepbosses then
		self.last.keep = true
	end

	self.total.time = self.total.time + self.current.time
	setPlayerActiveTimes(self.total)

	for _, player in ipairs(self.total.players) do
		player.first = nil
		player.last = nil
	end

	self.callbacks:Fire("COMBAT_PLAYER_LEAVE", self.current)
	if self.current.gotboss then
		self.callbacks:Fire("COMBAT_ENCOUNTER_END", self.current)
	end

	self.current = nil

	local numsets = 0
	for _, set in ipairs(self.char.sets) do
		if not set.keep then
			numsets = numsets + 1
		end
	end

	for i = tmaxn(self.char.sets), 1, -1 do
		if numsets > self.db.profile.setstokeep and not self.char.sets[i].keep then
			tremove(self.char.sets, i)
			numsets = numsets - 1
		end
	end

	for _, win in self:IterateWindows() do
		win:Wipe()
		changed = true

		if win.db.wipemode ~= "" and self:IsRaidDead() then
			win:RestoreView("current", win.db.wipemode)
		elseif win.db.returnaftercombat and win.restore_mode and win.restore_set then
			if win.restore_set ~= win.selectedset or win.restore_mode ~= win.selectedmode then
				win:RestoreView(win.restore_set, win.restore_mode)
				win.restore_mode, win.restore_set = nil, nil
			end
		end

		if not win.db.hidden and (not self.db.profile.hidesolo or IsInGroup()) then
			if self.db.profile.showcombat and win:IsShown() then
				win:Hide()
			elseif self.db.profile.hidecombat and not win:IsShown() then
				win:Show()
			end
		end
	end

	self:UpdateDisplay(true)

	if update_timer then
		if not update_timer._cancelled then
			update_timer:Cancel()
		end
		update_timer = nil
	end

	if tick_timer then
		if not tick_timer._cancelled then
			tick_timer:Cancel()
		end
		tick_timer = nil
	end

	if not clean_timer then
		clean_timer = self.NewTicker(60, function() collectgarbage("collect") end)
	end

	self.After(2, function() self:CleanGarbage(true) end)
	self.After(3, function() self:MemoryCheck() end)
end

function Skada:StopSegment()
	if self.current then
		self.current.stopped = true
		self.current.endtime = time()
		self.current.time = math_max(self.current.endtime - self.current.starttime, 0.1)
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
		self.callbacks:Fire("COMBAT_ENCOUNTER_TICK", self.current)
		if not disabled and self.current and not self:IsRaidInCombat() then
			self:Debug("EndSegment: Tick")
			self:EndSegment()
		end

		if clean_timer then
			clean_timer:Cancel()
			clean_timer = nil
		end
	end

	function Skada:StartCombat()
		deathcounter = 0
		startingmembers = select(2, GetGroupTypeAndCount())

		if tentativehandle and not tentativehandle._cancelled then
			tentativehandle:Cancel()
			tentativehandle = nil
		end

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

		update_timer = self.NewTicker(self.db.profile.updatefrequency or 0.25, function() self:UpdateDisplay() end)
		tick_timer = self.NewTicker(1, function() Skada:Tick() end)
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
				tentativehandle = self.NewTimer(self.db.profile.tentativetimer or 3, function()
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
		end

		if self.current and self.db.profile.autostop then
			if eventtype == "UNIT_DIED" and ((band(srcFlags, BITMASK_GROUP) ~= 0 and band(srcFlags, BITMASK_PETS) == 0) or players[srcGUID]) then
				deathcounter = deathcounter + 1
				-- If we reached the treshold for stopping the segment, do so.
				if deathcounter > 0 and deathcounter / startingmembers >= 0.5 and not self.current.stopped then
					self.callbacks:Fire("COMBAT_PLAYER_WIPE", self.current)
					self:Print("Stopping for wipe.")
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
						src_is_interesting = band(srcFlags, BITMASK_GROUP) ~= 0 or (band(srcFlags, BITMASK_PETS) ~= 0 and pets[srcGUID]) or players[srcGUID]
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
							tentativehandle:Cancel()
							tentativehandle = nil
							self:Debug("StartCombat: tentative combat")
							self:StartCombat()
						end
					end
				end
			end
		end

		if self.current and src_is_interesting and not self.current.gotboss then
			if band(dstFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then
				local isboss, _, bossname = self:IsBoss(dstGUID)
				if not self.current.gotboss and isboss then
					self.current.mobname = bossname or dstName
					self.current.gotboss = true
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
						self:AssignPet(pets[owner.id].id, pets[owner.id].name, pet)
						fixed = true
					end
				end
			end
		end

		if not self.bossmod and self.current and self.current.gotboss and (eventtype == "UNIT_DIED" or eventtype == "UNIT_DESTROYED") then
			if dstName and self.current.mobname == dstName then
				self.current.success = true
				self.callbacks:Fire("COMBAT_BOSS_DEFEATED", self.current)
			end
		end
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--> Mimic C_Timer instead of using AceTimer
do
	local TickerPrototype = {}
	local TickerMetatable = {__index = TickerPrototype, __metatable = true}
	local waitTable = {}

	local waitFrame = _G.SkadaTimerFrame or CreateFrame("Frame", "SkadaTimerFrame", UIParent)
	waitFrame:SetScript("OnUpdate", function(self, elapsed)
		local total = #waitTable
		for i = 1, total do
			local ticker = waitTable[i]

			if ticker then
				if ticker._cancelled then
					tremove(waitTable, i)
				elseif ticker._delay > elapsed then
					ticker._delay = ticker._delay - elapsed
					i = i + 1
				else
					ticker._callback(ticker)

					if ticker._remainingIterations == -1 then
						ticker._delay = ticker._duration
						i = i + 1
					elseif ticker._remainingIterations > 1 then
						ticker._remainingIterations = ticker._remainingIterations - 1
						ticker._delay = ticker._duration
						i = i + 1
					elseif ticker._remainingIterations == 1 then
						tremove(waitTable, i)
						total = total - 1
					end
				end
			end
		end

		if #waitTable == 0 then
			self:Hide()
		end
	end)

	local function AddDelayedCall(ticker, oldTicker)
		if oldTicker and type(oldTicker) == "table" then
			ticker = oldTicker
		end

		tinsert(waitTable, ticker)
		waitFrame:Show()
	end

	local function CreateTicker(duration, callback, iterations)
		local ticker = setmetatable({}, TickerMetatable)
		ticker._remainingIterations = iterations or -1
		ticker._duration = duration
		ticker._delay = duration
		ticker._callback = callback

		AddDelayedCall(ticker)
		return ticker
	end

	Skada.After = function(duration, callback)
		AddDelayedCall({
			_remainingIterations = 1,
			_delay = duration,
			_callback = callback
		})
	end

	Skada.NewTimer = function(duration, callback)
		return CreateTicker(duration, callback, 1)
	end

	Skada.NewTicker = function(duration, callback, iterations)
		return CreateTicker(duration, callback, iterations)
	end

	function TickerPrototype:Cancel()
		self._cancelled = true
	end
end