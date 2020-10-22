Skada = LibStub("AceAddon-3.0"):NewAddon("Skada", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local icon = LibStub("LibDBIcon-1.0", true)
local media = LibStub("LibSharedMedia-3.0")
local boss = LibStub("LibBossIDs-1.0")
local AceGUI = LibStub("AceGUI-3.0")

local dataobj = ldb:NewDataObject("Skada", {label = "Skada", type = "data source", icon = "Interface\\Icons\\Spell_Lightning_LightningBolt01", text = "n/a"})

-- Keybindings
BINDING_HEADER_Skada = "Skada"
BINDING_NAME_SKADA_TOGGLE = L["Toggle window"]
BINDING_NAME_SKADA_RESET = L["Reset"]
BINDING_NAME_SKADA_NEWSEGMENT = L["Start new segment"]

-- All saved sets
local sets = {}

-- The current set
Skada.current = nil

-- The total set
Skada.total = nil

-- The last set
Skada.last = nil

-- Modes - these are modules, really. Modeules?
local modes = {}

-- Pets; an array of pets and their owners.
local pets = {}

-- Flag marking if we need an update.
local changed = true

-- Flag for if we were in a prarty/raid. Set first time in PLAYER_ENTERING_WORLD.
local wasinparty = false

-- By default we just use RAID_CLASS_COLORS as class colors.
Skada.classcolors = RAID_CLASS_COLORS

-- class icons and coordinates
Skada.petIcon = [[Interface\ICONS\Ability_racial_cannibalize]]
Skada.classIcon = [[Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES]]
Skada.classCoords = CLASS_ICON_TCOORDS

-- The selected data feed.
local selectedfeed = nil

-- A list of data feeds available. Modules add to it.
local feeds = {}

-- Disabled flag.
local disabled = false

-- Our windows.
local windows = {}

-- Our display providers.
Skada.displays = {}

-- Timer for updating windows.
local update_timer = nil

-- Timer for checking for combat end.
local tick_timer = nil

function Skada:GetWindows()
	return windows
end

local function find_mode(name)
	for i, mode in ipairs(modes) do
		if mode:GetName() == name then
			return mode
		end
	end
end

-- Our window type.
local Window = {}

local mt = {__index = Window}

function Window:new()
   return setmetatable(
   		{
			-- The selected mode and set
			selectedmode = nil,
			selectedset = nil,

			-- Mode and set to return to after combat.
			restore_mode = nil,
			restore_set = nil,

			usealt = true,

			-- Our dataset.
			dataset = {},

			-- Metadata about our dataset.
			metadata = {},

			-- Our display provider.
			display = nil,

			-- Our mode traversing history.
			history = {},

	   	 }, mt)
end

function Window:AddOptions()
	local db = self.db

	local options = {
	        type="group",
			name=function() return db.name end,
	        args={

				rename = {
					type="input",
					name=L["Rename window"],
					desc=L["Enter the name for the window."],
					get=function() return db.name end,
					set=function(win, val) if val ~= db.name and val ~= "" then db.name = val end end,
					order=1,
				},

				display = {
					type="select",
					name=L["Display system"],
					desc=L["Choose the system to be used for displaying data in this window."],
					values=	function()
								local list = {}
								for name, display in pairs(Skada.displays) do
									list[name] = display.name
								end
								return list
							end,
					get=function()
						return db.display end,
					set=function(i, display)
							self:SetDisplay(display)
						end,
					order=21,
				},

				locked = {
				       type="toggle",
				       name=L["Lock window"],
				       desc=L["Locks the bar window in place."],
				       order=18,
				       get=function() return db.barslocked end,
				       set=function()
				       		db.barslocked = not db.barslocked
				       			Skada:ApplySettings()
				       	end,
				}


	        }
	}

	options.args.switchoptions = {
		type = "group",
		name = L["Mode switching"],
		order=4,
		args = {

			modeincombat = {
				type="select",
				name=L["Combat mode"],
				desc=L["Automatically switch to set 'Current' and this mode when entering combat."],
				values=	function()
							local modes = {}
							modes[""] = L["None"]
							for i, mode in ipairs(Skada:GetModes()) do
								modes[mode:GetName()] = mode:GetName()
							end
							return modes
						end,
				get=function() return db.modeincombat end,
				set=function(win, mode) db.modeincombat = mode end,
				order=21,
			},

			returnaftercombat = {
				type="toggle",
               	name=L["Return after combat"],
             			desc=L["Return to the previous set and mode after combat ends."],
                order=22,
     			        get=function() return db.returnaftercombat end,
         			    set=function() db.returnaftercombat = not db.returnaftercombat end,
         			    disabled=function() return db.returnaftercombat == nil end,
			},
		}
	}

	self.display:AddDisplayOptions(self, options.args)

	Skada.options.args.windows.args[self.db.name] = options
end

function Window:destroy()
	self.dataset = nil

	self.display:Destroy(self)
end

function Window:SetDisplay(name)
	-- Don't do anything if nothing actually changed.
	if name ~= self.db.display or self.display == nil then
		if self.display then
			-- Destroy old display.
			self.display:Destroy(self)
		end

		-- Set new display.
		self.db.display = name
		self.display = Skada.displays[self.db.display]

		-- Add options. Replaces old options.
		self:AddOptions()
	end
end

-- Tells window to update the display of its dataset, using its display provider.
function Window:UpdateDisplay()
	-- Fetch max value if our mode has not done this itself.
	if not self.metadata.maxvalue then
		self.metadata.maxvalue = 0
		for i, data in ipairs(self.dataset) do
			if data.id and data.value > self.metadata.maxvalue then
				self.metadata.maxvalue = data.value
			end
		end
	end

	-- Display it.
	self.display:Update(self)
end

-- Called before dataset is updated.
function Window:UpdateInProgress()
	for i, data in ipairs(self.dataset) do
		data.id = nil
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
	for i, data in ipairs(self.dataset) do
		wipe(data)
	end
end

function Window:Wipe()
	-- Clear dataset.
	self:Reset()

	-- Clear display.
	self.display:Wipe(self)
end

-- If selectedset is "current", returns current set if we are in combat, otherwise returns the last set.
function Window:get_selected_set()
	return Skada:find_set(self.selectedset)
end

-- Sets up the mode view.
function Window:DisplayMode(mode)
	self:Wipe()

	self.selectedplayer = nil
	self.selectedspell = nil
	self.selectedmode = mode

	self.metadata = {}

	-- Apply mode's metadata.
	if mode.metadata then
		for key, value in pairs(mode.metadata) do
			self.metadata[key] = value
		end
	end

	local name = mode.title or mode:GetName()

	-- Save for posterity.
	self.db.mode = name
	self.metadata.title = name

	Skada:UpdateDisplay(true)
end

local function click_on_mode(win, id, label, button)
	if button == "LeftButton" then
		local mode = find_mode(id)
		if mode then
			win:DisplayMode(mode)
		end
	elseif button == "RightButton" then
		win:RightClick()
	end
end

-- Sets up the mode list.
function Window:DisplayModes(settime)
	self.history = {}
	self:Wipe()

	self.selectedplayer = nil
	self.selectedmode = nil

	self.metadata = {}

	self.metadata.title = L["Skada: Modes"]

	-- Save for posterity.
	self.db.set = settime

	-- Find the selected set
	if settime == "current" or settime == "total" then
		self.selectedset = settime
	else
		for i, set in ipairs(sets) do
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
	self.metadata.sortfunc = function(a,b) return a.name < b.name end

	Skada:UpdateDisplay(true)
end

local function click_on_set(win, id, label, button)
	if button == "LeftButton" then
		win:DisplayModes(id)
	elseif button == "RightButton" then
		win:RightClick()
	end
end

-- Sets up the set list.
function Window:DisplaySets()
	self.history = {}
	self:Wipe()

	self.metadata = {}

	self.selectedplayer = nil
	self.selectedmode = nil
	self.selectedset = nil

	self.metadata.title = L["Skada: Fights"]

	self.metadata.click = click_on_set
	self.metadata.maxvalue = 1
--	self.metadata.sortfunc = function(a,b) return a.name < b.name end

	Skada:UpdateDisplay(true)
end

-- Default "right-click" behaviour in case no special click function is defined:
-- 1) If there is a mode traversal history entry, go to the last mode.
-- 2) Go to modes list if we are in a mode.
-- 3) Go to set list.
function Window:RightClick(group, button)
	if self.selectedmode then
		-- If mode traversal history exists, go to last entry, else mode list.
		if #self.history > 0 then
			self:DisplayMode(tremove(self.history))
		else
			self:DisplayModes(self.selectedset)
		end
	elseif self.selectedset then
		self:DisplaySets()
	end
end

function Skada:OnInitialize()
	-- Register some SharedMedia goodies.
  media:Register("font", "ABF", [[Interface\Addons\Skada\fonts\ABF.ttf]])
  media:Register("font", "Accidental Presidency", [[Interface\Addons\Skada\fonts\Accidental Presidency.ttf]])
  media:Register("font", "Adventure", [[Interface\Addons\Skada\fonts\Adventure.ttf]])
  media:Register("font", "Diablo", [[Interface\Addons\Skada\fonts\Avqest.ttf]])
  media:Register("font", "Vera Serif", [[Interface\Addons\Skada\fonts\VeraSe.ttf]])

  media:Register("statusbar", "Aluminium", [[Interface\Addons\Skada\statusbar\Aluminium]])
  media:Register("statusbar", "Armory", [[Interface\Addons\Skada\statusbar\Armory]])
  media:Register("statusbar", "BantoBar", [[Interface\Addons\Skada\statusbar\BantoBar]])
  media:Register("statusbar", "Details", [[Interface\AddOns\Skada\statusbar\Details]])
  media:Register("statusbar", "Flat", [[Interface\AddOns\Skada\statusbar\Flat]])
  media:Register("statusbar", "Glaze2", [[Interface\Addons\Skada\statusbar\Glaze2]])
  media:Register("statusbar", "Gloss", [[Interface\Addons\Skada\statusbar\Gloss]])
  media:Register("statusbar", "Graphite", [[Interface\Addons\Skada\statusbar\Graphite]])
  media:Register("statusbar", "Grid", [[Interface\Addons\Skada\statusbar\Grid]])
  media:Register("statusbar", "Healbot", [[Interface\Addons\Skada\statusbar\Healbot]])
  media:Register("statusbar", "LiteStep", [[Interface\Addons\Skada\statusbar\LiteStep]])
  media:Register("statusbar", "Minimalist", [[Interface\Addons\Skada\statusbar\Minimalist]])
  media:Register("statusbar", "Otravi", [[Interface\Addons\Skada\statusbar\Otravi]])
  media:Register("statusbar", "Outline", [[Interface\Addons\Skada\statusbar\Outline]])
  media:Register("statusbar", "Perl", [[Interface\Addons\Skada\statusbar\Perl]])
  media:Register("statusbar", "Round", [[Interface\Addons\Skada\statusbar\Round]])
  media:Register("statusbar", "Serenity", [[Interface\AddOns\Skada\statusbar\Serenity]])
  media:Register("statusbar", "Smooth", [[Interface\Addons\Skada\statusbar\Smooth]])
  media:Register("statusbar", "TukTex", [[Interface\Addons\Skada\statusbar\normTex]])
  media:Register("statusbar", "WorldState Score", [[Interface\WorldStateFrame\WORLDSTATEFINALSCORE-HIGHLIGHT]])

	-- Some sounds (copied from Omen).
  media:Register("sound", "Cartoon FX", [[Sound\Doodad\Goblin_Lottery_Open03.wav]])
  media:Register("sound", "Cheer", [[Sound\Event Sounds\OgreEventCheerUnique.wav]])
  media:Register("sound", "Explosion", [[Sound\Doodad\Hellfire_Raid_FX_Explosion05.wav]])
  media:Register("sound", "Fel Nova", [[Sound\Spells\SeepingGaseous_Fel_Nova.wav]])
  media:Register("sound", "Fel Portal", [[Sound\Spells\Sunwell_Fel_PortalStand.wav]])
  media:Register("sound", "Humm", [[Sound\Spells\SimonGame_Visual_GameStart.wav]])
  media:Register("sound", "Rubber Ducky", [[Sound\Doodad\Goblin_Lottery_Open01.wav]])
  media:Register("sound", "Shing!", [[Sound\Doodad\PortcullisActive_Closed.wav]])
  media:Register("sound", "Short Circuit", [[Sound\Spells\SimonGame_Visual_BadPress.wav]])
  media:Register("sound", "Simon Chime", [[Sound\Doodad\SimonGame_LargeBlueTree.wav]])
  media:Register("sound", "War Drums", [[Sound\Event Sounds\Event_wardrum_ogre.wav]])
  media:Register("sound", "Wham!", [[Sound\Doodad\PVP_Lordaeron_Door_Open.wav]])
  media:Register("sound", "You Will Die!", [[Sound\Creature\CThun\CThunYouWillDIe.wav]])

	-- DB
	self.db = LibStub("AceDB-3.0"):New("SkadaDB", self.defaults, "Default")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("Skada", self.options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Skada", "Skada")

	-- Profiles
	LibStub("AceConfig-3.0"):RegisterOptionsTable("Skada-Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db))
	self.profilesFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Skada-Profiles", "Profiles", "Skada")

	self:RegisterChatCommand("skada", "Command")
	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadSettings")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadSettings")

	self:ReloadSettings()

	-- Instead of listening for callbacks on SharedMedia we simply wait a few seconds and then re-apply settings
	-- to catch any missing media. Lame? Yes.
	self:ScheduleTimer("ApplySettings", 2)
end

function Skada:tcopy(to, from)
  for k,v in pairs(from) do
    if(type(v)=="table") then
      to[k] = {}
      Skada:tcopy(to[k], v);
    else
      to[k] = v;
    end
  end
end

function Skada:CreateWindow(name, db)
	if not db then
		db = {}
		self:tcopy(db, Skada.windowdefaults)
		table.insert(self.db.profile.windows, db)
	end

	local window = Window:new()
	window.db = db
	window.db.name = name

	-- Set the window's display and call it's Create function.
	window:SetDisplay(window.db.display or "bar")

	window.display:Create(window)

	table.insert(windows, window)

	-- Set initial view, set list.
	window:DisplaySets()

	self:ApplySettings()
end

-- Deleted named window from our windows table, and also from db.
function Skada:DeleteWindow(name)
	for i, win in ipairs(windows) do
		if win.db.name == name then
			win:destroy()
			wipe(table.remove(windows, i))
		end
	end
	for i, win in ipairs(self.db.profile.windows) do
		if win.name == name then
			table.remove(self.db.profile.windows, i)
		end
	end
	self.options.args.windows.args[name] = nil
end

function Skada:Command(param)
	if param == "pets" then
		self:PetDebug()
	elseif param == "test" then
		self:OpenMenu()
	elseif param == "reset" then
		self:Reset()
	elseif param == "newsegment" then
		self:NewSegment()
	elseif param == "toggle" then
		self:ToggleWindow()
	elseif param == "config" then
		self:OpenOptions()
	elseif param:sub(1,6) == "report" then
		param = param:sub(7)
		local chan = "say"
		local max = 0
		local chantype = "preset"

		local w1, w2, w3, w4 = self:GetArgs(param, 4)

		local chan = w1 or "say"
		local report_mode_name = w2 or L["Damage"]
		local max = tonumber(w3 or 10)

		-- Sanity checks.
		if chan and (chan == "say" or chan == "guild" or chan == "raid" or chan == "party" or chan == "officer") and (report_mode_name and find_mode(report_mode_name)) then
			self:Report(chan, "preset", report_mode_name, "current", max)
		else
			self:Print("Usage:")
			self:Print(("%-20s"):format("/skada report [raid|guild|party|officer|say] [mode] [max lines]"))
		end
	else
		self:Print("Usage:")
		self:Print(("%-20s"):format("/skada report [raid|guild|party|officer|say] [mode] [max lines]"))
		self:Print(("%-20s"):format("/skada reset"))
		self:Print(("%-20s"):format("/skada toggle"))
		self:Print(("%-20s"):format("/skada newsegment"))
		self:Print(("%-20s"):format("/skada config"))
	end
end

local function escapestr(str)
  local newstr = ""
  for i = 1, str:len() do
    local n = str:sub(i, i)
    newstr = newstr .. n
    if n == "|" then
      newstr = newstr .. n
    end
  end
  return (newstr ~= "") and newstr or str
end

local function sendchat(msg, chan, chantype)
  msg = escapestr(msg)
	if chantype == "self" then
		-- To self.
		Skada:Print(msg)
	elseif chantype == "channel" then
		-- To channel.
		SendChatMessage(msg, "CHANNEL", nil, chan)
	elseif chantype == "preset" then
		-- To a preset channel id (say, guild, etc).
		SendChatMessage(msg, string.upper(chan))
	elseif chantype == "whisper" then
		-- To player.
		SendChatMessage(msg, "WHISPER", nil, chan)
	end
end

function Skada:Report(channel, chantype, report_mode_name, report_set_name, max, window)

	if(chantype == "channel") then
		local list = {GetChannelList()}
		for i=1,table.getn(list)/2 do
			if(Skada.db.profile.report.channel == list[i*2]) then
				channel = list[i*2-1]
				break
			end
		end
	end

	local report_table
	local report_set
	local report_mode
	if not window then
		report_mode = find_mode(report_mode_name)
		report_set = Skada:find_set(report_set_name)
		if report_set == nil then
			return
		end
		-- Create a temporary fake window.
		report_table = Window:new()

		-- Tell our mode to populate our dataset.
		report_mode:Update(report_table, report_set)
	else
		report_table = window
		report_set = window:get_selected_set()
		report_mode = window.selectedmode
	end

	-- Sort our temporary table according to value unless ordersort is set.
	if not report_table.metadata.ordersort then
		table.sort(report_table.dataset, function(a,b) return a and b and a.id and b.id and a.value > b.value end)
	end

	-- Title
	local endtime = report_set.endtime or time()
	sendchat(string.format(L["Skada report on %s for %s, %s to %s:"], report_mode.title or report_mode:GetName(), report_set.name, date("%X",report_set.starttime), date("%X",endtime)), channel, chantype)

	-- For each item in dataset, print label and valuetext.
	local nr = 1
	for i, data in ipairs(report_table.dataset) do
		if data.id then
			if report_mode.metadata and report_mode.metadata.showspots then
				sendchat(("%2u. %s   %s"):format(nr, data.label, data.valuetext), channel, chantype)
			else
				sendchat(("%s   %s"):format(data.label, data.valuetext), channel, chantype)
			end
			nr = nr + 1
		end
		if nr > max then
			break
		end
	end

end

function Skada:RefreshMMButton()
	if icon then
		icon:Refresh("Skada", self.db.profile.icon)
		if self.db.profile.icon.hide then
			icon:Hide("Skada")
		else
			icon:Show("Skada")
		end
	end
end

function Skada:OpenOptions()
	InterfaceOptionsFrame_OpenToCategory("Skada")
end

function Skada:PetDebug()
	self:CheckPets()
	self:Print("pets:")
	for pet, owner in pairs(pets) do
		self:Print("pet "..pet.." belongs to ".. owner.id..", "..owner.name)
	end
end

function Skada:SetActive(enable)
	if enable then
		for i, win in ipairs(windows) do
			win:Show()
		end
		disabled = false
	else
		for i, win in ipairs(windows) do
			win:Hide()
		end
		if self.db.profile.hidedisables then
			disabled = true
		end
	end
end

function Skada:OnEnable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED")
	self:RegisterEvent("RAID_ROSTER_UPDATE")
	self:RegisterEvent("UNIT_PET")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

	if type(CUSTOM_CLASS_COLORS) == "table" then
		Skada.classcolors = CUSTOM_CLASS_COLORS
	end

  if type(CLASS_ICON_TCOORDS) == "table" then
    Skada.classCoords = CLASS_ICON_TCOORDS
  end
end

local function CheckPet(unit, pet)
--	DEFAULT_CHAT_FRAME:AddMessage("checking out "..pet)

	local petGUID = UnitGUID(pet)
	local unitGUID = UnitGUID(unit)
	local unitName = UnitName(unit)

	-- Add to pets if it does not already exist.
	-- TODO: We have a problem here with stale data. We could remove
	-- any existing pet when we add one, but this would not work with Mirror Image
	-- and other effects with multiple pets per player.
	if petGUID and unitGUID and unitName and not pets[petGUID] then
		pets[petGUID] = {id = unitGUID, name = unitName}
	end
end

function Skada:CheckPets()
	if GetNumRaidMembers() > 0 then
		-- In raid.
		for i = 1, GetNumRaidMembers(), 1 do
			if UnitExists("raid"..i.."pet") then
				CheckPet("raid"..i, "raid"..i.."pet")
			end
		end
	elseif GetNumPartyMembers() > 0 then
		-- In party.
		for i = 1, GetNumPartyMembers(), 1 do
			if UnitExists("party"..i.."pet") then
				CheckPet("party"..i, "party"..i.."pet")
			end
		end
	end

	-- Solo. Always check.
	if UnitExists("pet") then
		CheckPet("player", "pet")
	end
end

-- Ask a mode to verify the contents of a set.
local function verify_set(mode, set)
	if mode.AddSetAttributes ~= nil then
		mode:AddSetAttributes(set)
	end
	for j, player in ipairs(set.players) do
		if mode.AddPlayerAttributes ~= nil then
			mode:AddPlayerAttributes(player)
		end
	end
end

local wasininstance
local wasinpvp

local function ask_for_reset()
	StaticPopupDialogs["ResetSkadaDialog"] = {
    text = L["Do you want to reset Skada?"],
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 30,
    whileDead = 0,
    hideOnEscape = 1,
    OnAccept = function() Skada:Reset() end,
  }
	StaticPopup_Show("ResetSkadaDialog")
end

-- Are we in a PVP zone?
local function is_in_pvp()
	return select(2,IsInInstance()) == "pvp" or select(2,IsInInstance()) == "arena"
end

-- Are we solo?
local function is_solo()
	return GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0
end

-- Fired on entering a zone.
function Skada:PLAYER_ENTERING_WORLD()
	-- Check if we are entering an instance.
	local inInstance, instanceType = IsInInstance()
	local isininstance = inInstance and (instanceType == "party" or instanceType == "raid")
	local isinpvp = is_in_pvp()

	-- If we are entering an instance, and we were not previously in an instance, and we got this event before... and we have some data...
	if isininstance and wasininstance ~= nil and not wasininstance and self.db.profile.reset.instance ~= 1 and total ~= nil then
		if self.db.profile.reset.instance == 3 then
			ask_for_reset()
		else
			self:Reset()
		end
	end

	-- Hide in PvP. Hide if entering a PvP instance, show if we are leaving one.
	if self.db.profile.hidepvp then
		if is_in_pvp() then
			Skada:SetActive(false)
		elseif wasinpvp then
			Skada:SetActive(true)
		end
	end

	-- Save a flag marking our previous (current) instance status.
	if isininstance then
		wasininstance = true
	else
		wasininstance = false
	end

	-- Save a flag marking out previous (current) pvp status.
	if isinpvp then
		wasinpvp = true
	else
		wasinpvp = false
	end

	-- Mark our last party status. This is done so that the flag is set to correct value on relog/reloadui.
	wasinparty = (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0)

	-- Check for pets.
	self:CheckPets()
end

-- Check if we join a party/raid.
local function check_for_join_and_leave()
	if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 and wasinparty then
		-- We left a party.

		if Skada.db.profile.reset.leave == 3 then
			ask_for_reset()
		elseif Skada.db.profile.reset.leave == 2 then
			Skada:Reset()
		end

		-- Hide window if we have enabled the "Hide when solo" option.
		if Skada.db.profile.hidesolo then
			Skada:SetActive(false)
		end
	end

	if (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0) and not wasinparty then
		-- We joined a raid.

		if Skada.db.profile.reset.join == 3 then
			ask_for_reset()
		elseif Skada.db.profile.reset.join == 2 then
			Skada:Reset()
		end

		-- Show window if we have enabled the "Hide when solo" option.
		if Skada.db.profile.hidesolo then
			Skada:SetActive(true)
		end
	end

	-- Mark our last party status.
	wasinparty = (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0)
end

function Skada:PARTY_MEMBERS_CHANGED()
	check_for_join_and_leave()

	-- Check for new pets.
	self:CheckPets()
end

function Skada:RAID_ROSTER_UPDATE()
	check_for_join_and_leave()

	-- Check for new pets.
	self:CheckPets()
end

function Skada:UNIT_PET()
	-- Check for new pets.
	self:CheckPets()
end

function Skada:OnDisable()
	-- Save some settings.
	self.db.profile.selectedset = selectedset
	if selectedmode then
		self.db.profile.set = selectedmode.name
	else
		self.db.profile.mode = nil
	end
end

-- Toggles all windows.
function Skada:ToggleWindow()
	for i, win in ipairs(windows) do
		if win:IsShown() then
			win.db.hidden = true
			win:Hide()
		else
			win.db.hidden = false
			win:Show()
		end
	end
end


local function createSet(setname)
	local set = {players = {}, name = setname, starttime = time(), ["time"] = 0, last_action = time()}

	-- Tell each mode to apply its needed attributes.
	for i, mode in ipairs(modes) do verify_set(mode, set) end

	return set
end

function Skada:Reset()
	self:Wipe()

	pets = {}
	self:CheckPets()

	if self.current ~= nil then
		wipe(self.current)
		self.current = createSet(L["Current"])
	end
	if self.total ~= nil then
		wipe(self.total)
		self.total = createSet(L["Total"])
		self.db.profile.total = self.total
	end
	self.last = nil

	-- Delete sets that are not marked as persistent.
	for i=table.maxn(sets), 1, -1 do
		if not sets[i].keep then
			wipe(table.remove(sets, i))
		end
	end

	self:UpdateDisplay(true)
	self:Print(L["All data has been reset."])
	collectgarbage("collect")
end

-- Delete a set.
function Skada:DeleteSet(set)
	if not set then return end

	for i, s in ipairs(sets) do
		if s == set then
			wipe(table.remove(sets, i))
		end
	end
	self:Wipe()
	self:UpdateDisplay(true)
end

-- Open a menu. Supply a window to tailor it to that window, else generic.
function Skada:OpenMenu(window)
	if not self.skadamenu then
		self.skadamenu = CreateFrame("Frame", "SkadaMenu")
	end
	local skadamenu = self.skadamenu

	skadamenu.displayMode = "MENU"
	local info = UIDropDownMenu_CreateInfo()
	skadamenu.initialize = function(self, level)
	    if not level then return end
	    wipe(info)
	    if level == 1 then
	        -- Create the title of the menu
	        info.isTitle = 1
	        info.text = L["Skada Menu"]
	        info.notCheckable = 1
	        UIDropDownMenu_AddButton(info, level)

			for i, win in ipairs(windows) do
		        wipe(info)
		        info.text = win.db.name
		        info.hasArrow = 1
		        info.value = win
		        info.notCheckable = 1
		        UIDropDownMenu_AddButton(info, level)
			end

	        -- Add a blank separator
	        wipe(info)
	        info.disabled = 1
	        info.notCheckable = 1
	        UIDropDownMenu_AddButton(info, level)

			-- Can't report if we are not in a mode.
			if not window or (window or window.selectedmode) then
		        wipe(info)
		        info.text = L["Report"]
		        info.hasArrow = 1
		        info.value = "report"
		        info.notCheckable = 1
		        UIDropDownMenu_AddButton(info, level)
		    end

	        wipe(info)
	        info.text = L["Delete segment"]
	        info.func = function() Skada:DeleteSet() end
	        info.hasArrow = 1
	        info.notCheckable = 1
	        info.value = "delete"
	        UIDropDownMenu_AddButton(info, level)

	        wipe(info)
	        info.text = L["Keep segment"]
	        info.func = function() Skada:KeepSet() end
	        info.notCheckable = 1
	        info.hasArrow = 1
	        info.value = "keep"
	        UIDropDownMenu_AddButton(info, level)

	        -- Add a blank separator
	        wipe(info)
	        info.disabled = 1
	        info.notCheckable = 1
	        UIDropDownMenu_AddButton(info, level)

	        wipe(info)
	        info.text = L["Toggle window"]
	        info.func = function() Skada:ToggleWindow() end
	        info.notCheckable = 1
	        UIDropDownMenu_AddButton(info, level)

	        wipe(info)
	        info.text = L["Reset"]
	        info.func = function() Skada:Reset() end
	        info.notCheckable = 1
	        UIDropDownMenu_AddButton(info, level)

	        wipe(info)
	        info.text = L["Start new segment"]
	        info.func = function() Skada:NewSegment() end
	        info.notCheckable = 1
	        UIDropDownMenu_AddButton(info, level)


	        wipe(info)
	        info.text = L["Configure"]
	        info.func = function() Skada:OpenOptions() end
	        info.notCheckable = 1
	        UIDropDownMenu_AddButton(info, level)

	        -- Close menu item
	        wipe(info)
	        info.text         = CLOSE
	        info.func         = function() CloseDropDownMenus() end
	        info.checked      = nil
	        info.notCheckable = 1
	        UIDropDownMenu_AddButton(info, level)
	    elseif level == 2 then
	    	if type(UIDROPDOWNMENU_MENU_VALUE) == "table" then
	    		local window = UIDROPDOWNMENU_MENU_VALUE
	    		-- Display list of modes with current ticked; let user switch mode by checking one.
		        wipe(info)
		        info.isTitle = 1
		        info.text = L["Mode"]
		        UIDropDownMenu_AddButton(info, level)

		        for i, module in ipairs(Skada:GetModes()) do
			        wipe(info)
		            info.text = module:GetName()
		            info.func = function() window:DisplayMode(module) end
		            info.checked = (window.selectedmode == module)
		            UIDropDownMenu_AddButton(info, level)
		        end

		        -- Separator
		        wipe(info)
		        info.disabled = 1
		        info.notCheckable = 1
		        UIDropDownMenu_AddButton(info, level)

		        -- Display list of sets with current ticked; let user switch set by checking one.
		        wipe(info)
		        info.isTitle = 1
		        info.text = L["Segment"]
		        UIDropDownMenu_AddButton(info, level)

		        wipe(info)
	            info.text = L["Total"]
	            info.func = function()
	            				window.selectedset = "total"
	            				Skada:Wipe()
	            				Skada:UpdateDisplay(true)
	            			end
	            info.checked = (window.selectedset == "total")
	            UIDropDownMenu_AddButton(info, level)
		        wipe(info)
	            info.text = L["Current"]
	            info.func = function()
	            				window.selectedset = "current"
	            				Skada:Wipe()
	            				Skada:UpdateDisplay(true)
	            			end
	            info.checked = (window.selectedset == "current")
	            UIDropDownMenu_AddButton(info, level)

		        for i, set in ipairs(sets) do
			        wipe(info)
		            info.text = set.name..": "..date("%H:%M",set.starttime).." - "..date("%H:%M",set.endtime)
		            info.func = function()
		            				window.selectedset = i
		            				Skada:Wipe()
		            				Skada:UpdateDisplay(true)
		            			end
		            info.checked = (window.selectedset == set.starttime)
		            UIDropDownMenu_AddButton(info, level)
		        end

		        -- Add a blank separator
		        wipe(info)
		        info.disabled = 1
		        info.notCheckable = 1
		        UIDropDownMenu_AddButton(info, level)

		        wipe(info)
	            info.text = L["Lock window"]
	            info.func = function()
	            				window.db.barslocked = not window.db.barslocked
	            				Skada:ApplySettings()
	            			end
	            info.checked = window.db.barslocked
		        UIDropDownMenu_AddButton(info, level)

		    elseif UIDROPDOWNMENU_MENU_VALUE == "delete" then
		        for i, set in ipairs(sets) do
			        wipe(info)
		            info.text = set.name..": "..date("%H:%M",set.starttime).." - "..date("%H:%M",set.endtime)
		            info.func = function() Skada:DeleteSet(set) end
			        info.notCheckable = 1
		            UIDropDownMenu_AddButton(info, level)
		        end
		    elseif UIDROPDOWNMENU_MENU_VALUE == "keep" then
		        for i, set in ipairs(sets) do
			        wipe(info)
		            info.text = set.name..": "..date("%H:%M",set.starttime).." - "..date("%H:%M",set.endtime)
		            info.func = function()
		            				set.keep = not set.keep
		            				Skada:Wipe()
		            				Skada:UpdateDisplay(true)
		            			end
		            info.checked = set.keep
		            UIDropDownMenu_AddButton(info, level)
		        end
		    elseif UIDROPDOWNMENU_MENU_VALUE == "report" then
		    	if not window then
			        wipe(info)
			        info.text = L["Mode"]
			        info.hasArrow = 1
			        info.value = "modes"
			        info.notCheckable = 1
			        UIDropDownMenu_AddButton(info, level)

			        wipe(info)
			        info.hasArrow = 1
			        info.value = "segment"
			        info.notCheckable = 1
			        info.text = L["Segment"]
			        UIDropDownMenu_AddButton(info, level)
			    end

		        wipe(info)
		        info.text = L["Channel"]
		        info.hasArrow = 1
		        info.value = "channel"
		        info.notCheckable = 1
		        UIDropDownMenu_AddButton(info, level)

		        wipe(info)
		        info.text = L["Lines"]
		        info.hasArrow = 1
		        info.value = "number"
		        info.notCheckable = 1
		        UIDropDownMenu_AddButton(info, level)

		        wipe(info)
		        info.text = L["Send report"]
		        info.func = function()
		        				if Skada.db.profile.report.mode ~= nil and Skada.db.profile.report.set ~= nil then

									if Skada.db.profile.report.chantype == "whisper" then
										StaticPopupDialogs["SkadaReportDialog"] = {
															text = L["Name of recipient"],
															button1 = ACCEPT,
															button2 = CANCEL,
															hasEditBox = 1,
															timeout = 30,
															hideOnEscape = 1,
															OnAccept = 	function()
																			Skada.db.profile.report.channel = getglobal(this:GetParent():GetName().."EditBox"):GetText()
																			Skada:Report(Skada.db.profile.report.channel, Skada.db.profile.report.chantype, Skada.db.profile.report.mode, Skada.db.profile.report.set, Skada.db.profile.report.number, window)
																		end,
														}
										StaticPopup_Show("SkadaReportDialog")
									else
										Skada:Report(Skada.db.profile.report.channel, Skada.db.profile.report.chantype, Skada.db.profile.report.mode, Skada.db.profile.report.set, Skada.db.profile.report.number, window)
									end
								else
									Skada:Print(L["No mode or segment selected for report."])
								end
		        			end
		        info.notCheckable = 1
		        UIDropDownMenu_AddButton(info, level)
		    end
		elseif level == 3 then
		    if UIDROPDOWNMENU_MENU_VALUE == "modes" then

		        for i, module in ipairs(Skada:GetModes()) do
			        wipe(info)
		            info.text = module:GetName()
		            info.checked = (Skada.db.profile.report.mode == module:GetName())
		            info.func = function() Skada.db.profile.report.mode = module:GetName() end
		            UIDropDownMenu_AddButton(info, level)
		        end
		    elseif UIDROPDOWNMENU_MENU_VALUE == "segment" then
		        wipe(info)
	            info.text = L["Total"]
	            info.func = function() Skada.db.profile.report.set = "total" end
	            info.checked = (Skada.db.profile.report.set == "total")
	            UIDropDownMenu_AddButton(info, level)

	            info.text = L["Current"]
	            info.func = function() Skada.db.profile.report.set = "current" end
	            info.checked = (Skada.db.profile.report.set == "current")
	            UIDropDownMenu_AddButton(info, level)

		        for i, set in ipairs(sets) do
		            info.text = set.name..": "..date("%H:%M",set.starttime).." - "..date("%H:%M",set.endtime)
		            info.func = function() Skada.db.profile.report.set = i end
		            info.checked = (Skada.db.profile.report.set == i)
		            UIDropDownMenu_AddButton(info, level)
		        end
		    elseif UIDROPDOWNMENU_MENU_VALUE == "number" then
		        for i = 1,25 do
			        wipe(info)
		            info.text = i
		            info.checked = (Skada.db.profile.report.number == i)
		            info.func = function() Skada.db.profile.report.number = i end
		            UIDropDownMenu_AddButton(info, level)
		        end
		    elseif UIDROPDOWNMENU_MENU_VALUE == "channel" then
		        wipe(info)
		        info.text = L["Whisper"]
		        info.checked = (Skada.db.profile.report.chantype == "whisper")
		        info.func = function() Skada.db.profile.report.channel = "Whisper"; Skada.db.profile.report.chantype = "whisper" end
		        UIDropDownMenu_AddButton(info, level)

		        info.text = L["Say"]
		        info.checked = (Skada.db.profile.report.channel == "Say")
		        info.func = function() Skada.db.profile.report.channel = "Say"; Skada.db.profile.report.chantype = "preset" end
		        UIDropDownMenu_AddButton(info, level)

	            info.text = L["Raid"]
	            info.checked = (Skada.db.profile.report.channel == "Raid")
	            info.func = function() Skada.db.profile.report.channel = "Raid"; Skada.db.profile.report.chantype = "preset" end
	            UIDropDownMenu_AddButton(info, level)

	            info.text = L["Party"]
	            info.checked = (Skada.db.profile.report.channel == "Party")
	            info.func = function() Skada.db.profile.report.channel = "Party"; Skada.db.profile.report.chantype = "preset" end
	            UIDropDownMenu_AddButton(info, level)

	            info.text = L["Guild"]
	            info.checked = (Skada.db.profile.report.channel == "Guild")
	            info.func = function() Skada.db.profile.report.channel = "Guild"; Skada.db.profile.report.chantype = "preset" end
	            UIDropDownMenu_AddButton(info, level)

	            info.text = L["Officer"]
	            info.checked = (Skada.db.profile.report.channel == "Officer")
	            info.func = function() Skada.db.profile.report.channel = "Officer"; Skada.db.profile.report.chantype = "preset" end
	            UIDropDownMenu_AddButton(info, level)

	            info.text = L["Self"]
	            info.checked = (Skada.db.profile.report.chantype == "self")
	            info.func = function() Skada.db.profile.report.channel = "Self"; Skada.db.profile.report.chantype = "self" end
	            UIDropDownMenu_AddButton(info, level)

				local list = {GetChannelList()}
				for i=1,table.getn(list)/2 do
					info.text = list[i*2]
					info.checked = (Skada.db.profile.report.channel == list[i*2])
					info.func = function() Skada.db.profile.report.channel = list[i*2]; Skada.db.profile.report.chantype = "channel" end
					UIDropDownMenu_AddButton(info, level)
				end

		    end

	    end
	end

	local x,y = GetCursorPosition(UIParent);
	ToggleDropDownMenu(1, nil, skadamenu, "UIParent", x / UIParent:GetEffectiveScale() , y / UIParent:GetEffectiveScale())
end

-- Opens segments menu
function Skada:SegmentMenu(window)
  self.segmentsmenu = self.segmentsmenu or CreateFrame("Frame", "SkadaSegmentsMenu")

  local segmentsmenu = self.segmentsmenu
  segmentsmenu.displayMode = "MENU"
  local info = UIDropDownMenu_CreateInfo()
  
  segmentsmenu.initialize = function(self, level)
    if not level then return end
    info.isTitle = 1
    info.text = L["Segment"]
    UIDropDownMenu_AddButton(info, level)
    info.isTitle = nil

    wipe(info)
    info.text = L["Total"]
    info.func = function()
      window.selectedset = "total"
      Skada:Wipe()
      Skada:UpdateDisplay(true)
    end
    info.checked = (window.selectedset == "total")
    UIDropDownMenu_AddButton(info, level)

    wipe(info)
    info.text = L["Current"]
    info.func = function()
      window.selectedset = "current"
      Skada:Wipe()
      Skada:UpdateDisplay(true)
    end
    info.checked = (window.selectedset == "current")
    UIDropDownMenu_AddButton(info, level)

    for i, set in ipairs(Skada.db.profile.sets) do
      wipe(info)
      info.text = set.name..": "..date("%H:%M", set.starttime).." - "..date("%H:%M", set.endtime)
      info.func = function()
        window.selectedset = i
        Skada:Wipe()
        Skada:UpdateDisplay(true)
      end
      info.checked = (window.selectedset == i)
      UIDropDownMenu_AddButton(info, level)
    end
  end

  local x,y = GetCursorPosition(UIParent)
  ToggleDropDownMenu(1, nil, segmentsmenu, "UIParent", x / UIParent:GetEffectiveScale() , y / UIParent:GetEffectiveScale())
end

-- Opens mode menu.
function Skada:ModeMenu(window)
  self.modesmenu = self.modesmenu or CreateFrame("Frame", "SkadaModesMenu")
  
  local modesmenu = self.modesmenu
  modesmenu.displayMode = "MENU"
  local info = UIDropDownMenu_CreateInfo()
  
  modesmenu.initialize = function(self, level)
    if not level then return end

    info.isTitle = true
    info.text = L["Mode"]
    UIDropDownMenu_AddButton(info, level)

    for i, module in ipairs(Skada:GetModes()) do
      wipe(info)
      info.text = module:GetName()
      info.func = function() window:DisplayMode(module) end
      info.checked = (window.selectedmode == module)
      UIDropDownMenu_AddButton(info, level)
    end
  end

  local x, y = GetCursorPosition(UIParent)
  ToggleDropDownMenu(1, nil, modesmenu, "UIParent", x / UIParent:GetEffectiveScale() , y / UIParent:GetEffectiveScale())
end

-- Skada report window
do
  -- destroys the report window
  local function destroy_report_window()
    if Skada.reportwindow then
      Skada.reportwindow:ReleaseChildren()
      Skada.reportwindow:Hide()
      Skada.reportwindow:Release()
    end
    Skada.reportwindow = nil
  end

  -- creates the report window
  local function create_report_window(window)
    Skada.reportwindow = AceGUI:Create("Window")

    local frame = Skada.reportwindow
    frame:SetLayout("Flow")
    frame:EnableResize(nil)
    frame:SetWidth(250)
    frame:SetHeight(300)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetTitle(L["Report"] .. (" - %s"):format(window.db.name))
    frame:SetCallback("OnClose", destroy_report_window)

    local lines = AceGUI:Create("Slider")
    lines:SetFullWidth(true)
    lines:SetLabel(L["Lines"])
    lines:SetValue(Skada.db.profile.report.number ~= nil and Skada.db.profile.report.number  or 10)
    lines:SetSliderValues(1, 25, 1)
    lines:SetCallback("OnValueChanged", function(self, event, value)
      Skada.db.profile.report.number = value
    end)

    local channeltext = AceGUI:Create("Label")
    channeltext:SetText(L["Channel"])
    channeltext:SetFullWidth(true)
    frame:AddChildren(lines, channeltext)

    local channellist = {
      {"Whisper", "whisper"},
      {"Whisper Target", "whisper"},
      {"Say", "preset"},
      {"Raid", "preset"},
      {"Party", "preset"},
      {"Guild", "preset"},
      {"Officer", "preset"},
      {"Self", "self"}
    }

    local list = {GetChannelList()}
    
    for i = 2, #list, 2 do
      if list[i] ~= "Trade" and list[i] ~= "General" and list[i] ~= "LookingForGroup" then
        channellist[#channellist+1] = {list[i], "channel"}
      end
    end

    for i = 1, #channellist do
      local checkbox = AceGUI:Create("CheckBox")
      _G["SkadaReportCheck" .. i] = checkbox
      checkbox:SetType("radio")
      checkbox:SetRelativeWidth(0.5)

      if Skada.db.profile.report.chantype == "channel" then
        if channellist[i][1] == Skada.db.profile.report.channel then
          frame.channel = channellist[i][1]
          frame.chantype = channellist[i][2]
          checkbox:SetValue(true)
        end

      elseif Skada.db.profile.report.chantype == "whisper" then
        if channellist[i][1] == "Whisper" then
          frame.chantype = channellist[i][2]
          checkbox:SetValue(true)
        end

      elseif Skada.db.profile.report.chantype == "preset" then
        if rawget(L, channellist[i][1]) and L[channellist[i][1]] == Skada.db.profile.report.channel then
          frame.channel = channellist[i][1]
          frame.chantype = channellist[i][2]
          checkbox:SetValue(true)
        end

      elseif Skada.db.profile.report.chantype == "self" then
        if channellist[i][2] == "self" then
          frame.channel = channellist[i][1]
          frame.chantype = channellist[i][2]
          checkbox:SetValue(true)
        end
      end

      if i == 2 or i >= 9 then
        checkbox:SetLabel(channellist[i][1])
      else
        checkbox:SetLabel(L[channellist[i][1]])
      end

      checkbox:SetCallback("OnValueChanged", function(value)
        for i=1, #channellist do
          local c = getglobal("SkadaReportCheck"..i)
          if c ~= nil and c ~= checkbox then
            c:SetValue(false)
          end
          if c == checkbox then
            frame.channel = channellist[i][1]
            frame.chantype = channellist[i][2]
          end
        end
      end)
      frame:AddChild(checkbox)
    end

    local whisperbox = AceGUI:Create("EditBox")
    whisperbox:SetLabel(L["Whisper Target"])

    if Skada.db.profile.report.chantype == "whisper" and Skada.db.profile.report.channel ~= L["Whisper"] then
      whisperbox:SetText(Skada.db.profile.report.channel)
      frame.target = Skada.db.profile.report.channel
    end

    whisperbox:SetCallback("OnEnterPressed", function(box, event, text) frame.target = text frame.button.frame:Click() end)
    whisperbox:SetCallback("OnTextChanged", function(box, event, text) frame.target = text end)
    whisperbox:SetFullWidth(true)

    local report = AceGUI:Create("Button")
    frame.button = report
    report:SetText(L["Report"])
    report:SetCallback("OnClick", function()
      if frame.channel == "Whisper" then
        frame.channel = frame.target
      end
      if frame.channel == "Whisper Target" then
        if UnitExists("target") then
          frame.channel = UnitName("target")
        else
          frame.channel = nil
        end
      end

      if frame.channel and frame.chantype and window.db.mode then
        Skada.db.profile.report.channel = frame.channel
        Skada.db.profile.report.chantype = frame.chantype

        Skada:Report(frame.channel, frame.chantype, window.db.mode, Skada.db.profile.report.set, Skada.db.profile.report.number, window)
        frame:Hide()
      else
        Skada:Print(L["Error: No options selected"])
      end
    end)

    report:SetFullWidth(true)
    frame:AddChildren(whisperbox, report)
    frame:SetHeight(180 + 27* math.ceil(#channellist/2))
  end

  -- opens report window
  function Skada:OpenReportWindow(window)
    if not self.reportwindow then
      create_report_window(window)
    end
    self.reportwindow:Show()
  end
end

function Skada:ReloadSettings()
	-- Delete all existing windows in case of a profile change.
	for i, win in ipairs(windows) do
		win:destroy()
	end
	windows = {}

	-- Re-create windows
	-- As this can be called from a profile change as well as login, re-use windows when possible.
	for i, win in ipairs(self.db.profile.windows) do
		self:CreateWindow(win.name, win)
	end

	self.total = self.db.profile.total
	sets = self.db.profile.sets

	-- Minimap button.
	if icon and not icon:IsRegistered("Skada") then
		icon:Register("Skada", dataobj, self.db.profile.icon)
	end

	self:RefreshMMButton()

	self:ApplySettings()
end

-- Applies settings to things like the bar window.
function Skada:ApplySettings()
	for i, win in ipairs(windows) do
		win.display:ApplySettings(win)
	end

	-- Don't show window if we are solo, option.
	-- Don't show window in a PvP instance, option.
	if (self.db.profile.hidesolo and is_solo()) or (self.db.profile.hidepvp and is_in_pvp())then
		self:SetActive(false)
	else
		self:SetActive(true)

		-- Hide specific windows if window is marked as hidden (ie, if user manually hid the window, keep hiding it).
		for i, win in ipairs(windows) do
			if win.db.hidden and win:IsShown() then
				win:Hide()
			end
		end
	end

	self:UpdateDisplay(true)
end

-- Set a data feed as selectedfeed.
function Skada:SetFeed(feed)
	selectedfeed = feed
	self:UpdateDisplay()
end

-- Iterates over all players in a set and adds to the "time" variable
-- the time between first and last action.
local function setPlayerActiveTimes(set)
	for i, player in ipairs(set.players) do
		if player.last then
			player.time = player.time + (player.last - player.first)
		end
	end
end

-- Starts a new segment, saving the current one first.
-- Does nothing if we are out of combat.
-- Useful for multi-part fights where you want individual segments for each part.
function Skada:NewSegment()
	if self.current then
		self:EndSegment()
		self:StartCombat()
	end
end

local function IsRaidInCombat()
	if GetNumRaidMembers() > 0 then
		-- We are in a raid.
		for i = 1, GetNumRaidMembers(), 1 do
			if UnitExists("raid"..i) and UnitAffectingCombat("raid"..i) then
				return true
			end
		end
	elseif GetNumPartyMembers() > 0 then
		-- In party.
		for i = 1, GetNumPartyMembers(), 1 do
			if UnitExists("party"..i) and UnitAffectingCombat("party"..i) then
				return true
			end
		end
	end
end

-- Our scheme for segmenting fights:
-- Each second, if player is not in combat and is not dead and we have an active set (current),
-- check if anyone in raid is in combat; if so, close up shop.
-- We can not simply rely on PLAYER_REGEN_ENABLED since it is fired if we die and the fight continues.
function Skada:Tick()
	if not disabled and self.current and not InCombatLockdown() and not UnitIsDead("player") and not IsRaidInCombat() then
		self:EndSegment()
	end
end

function Skada:EndSegment()
	-- Save current set unless this a trivial set, or if we have the Only keep boss fights options on, and no boss in fight.
	-- A set is trivial if we have no mob name saved, or if total time for set is not more than 5 seconds.
	if not self.db.profile.onlykeepbosses or self.current.gotboss then
		if self.current.mobname ~= nil and time() - self.current.starttime > 5 then
			-- End current set.
			self.current.endtime = time()
			self.current.time = self.current.endtime - self.current.starttime
			setPlayerActiveTimes(self.current)
			self.current.name = self.current.mobname

			-- Tell each mode that set has finished and do whatever it wants to do about it.
			for i, mode in ipairs(modes) do
				if mode.SetComplete ~= nil then
					mode:SetComplete(self.current)
				end
			end

			-- Add set to sets.
			table.insert(sets, 1, self.current)

		end

	end

	-- Make set last set.
	self.last = self.current

	-- Add time spent to total set as well.
	self.total.time = self.total.time + self.current.time
	setPlayerActiveTimes(self.total)

	-- Set player.first and player.last to nil in total set.
	-- Neccessary since first and last has no relevance over an entire raid.
	-- Modes should look at the "time" value if available.
	for i, player in ipairs(self.total.players) do
		player.first = nil
		player.last = nil
	end

	-- Reset current set.
	self.current = nil

	-- Find out number of non-persistent sets.
	local numsets = 0
	for i, set in ipairs(sets) do if not set.keep then numsets = numsets + 1 end end

	-- Trim segments; don't touch persistent sets.
	for i=table.maxn(sets), 1, -1 do
		if numsets > self.db.profile.setstokeep and not sets[i].keep then
			table.remove(sets, i)
			numsets = numsets - 1
		end
	end

	for i, win in ipairs(windows) do
		win:Wipe()
		changed = true

		-- Auto-switch back to previous set/mode.
		if win.db.returnaftercombat and win.restore_mode and win.restore_set then
			if win.restore_set ~= win.selectedset or win.restore_mode ~= win.selectedmode then

				self:RestoreView(win, win.restore_set, win.restore_mode)

				win.restore_mode = nil
				win.restore_set = nil
			end
		end
	end

	self:UpdateDisplay()
	self:CancelTimer(update_timer, true)
	self:CancelTimer(tick_timer, true)

	-- Hide in combat option.
	if self.db.profile.hidecombat then
		self:SetActive(true)
	end
end

function Skada:PLAYER_REGEN_DISABLED()
	-- Start a new set if we are not in one already.
	if not disabled and not self.current then
		self:StartCombat()
	end
end

-- This flag is used to mark a possible combat start.
-- It is a count of captured events.
-- When we hit our treshold (let's say 5), combat starts.
-- If we have not hit our treshold after a certain time (let's say 3 seconds) combat start failed.
local tentative = nil

-- AceTimer handle for reverting combat start.
local tentativehandle= nil

function Skada:StartCombat()
	-- Cancel cancelling combat if needed.
	if tentativehandle ~= nil then
		self:CancelTimer(tentativehandle)
		tentativehandle = nil
	end

	-- Remove old bars.
	self:Wipe()

	-- Create a new current set unless we are already have one (combat detection kicked in).
	if not self.current then
		self.current = createSet(L["Current"])
	end

	-- Also start the total set if it is nil.
	if self.total == nil then
		self.total = createSet(L["Total"])
		self.db.profile.total = self.total
	end

	-- Auto-switch set/mode if configured.
	for i, win in ipairs(windows) do
		if win.db.modeincombat ~= "" then
			-- First, get the mode. The mode may not actually be available.
			local mymode = find_mode(win.db.modeincombat)

			-- If the mode exists, switch to current set and this mode. Save current set/mode so we can return after combat if configured.
			if mymode ~= nil then
	--				self:Print("Switching to "..mymode.name.." mode.")

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
	end

	-- Force immediate update.
	self:UpdateDisplay(true)

	-- Schedule timers for updating windows and detecting combat end.
	update_timer = self:ScheduleRepeatingTimer("UpdateDisplay", 0.5)
	tick_timer = self:ScheduleRepeatingTimer("Tick", 1)

	-- Hide in combat option.
	if self.db.profile.hidecombat then
		self:SetActive(false)
	end
end

-- Simply calls the same function on all windows.
function Skada:Wipe()
	for i, win in ipairs(windows) do
		win:Wipe()
	end
end

-- Attempts to restore a view (set and mode).
-- Set is either the set name ("total", "current"), or an index.
-- Mode is the name of a mode.
function Skada:RestoreView(win, theset, themode)
	-- Set the... set. If no such set exists, set to current.
	if theset and type(theset) == "string" and (theset == "current" or theset == "total" or theset == "last") then
		win.selectedset = theset
	elseif theset and type(theset) == "number" and theset <= table.maxn(sets) then
		win.selectedset = theset
	else
		win.selectedset = "current"
	end

	-- Force an update.
	changed = true

	-- Find the mode. The mode may not actually be available.
	if themode then
		local mymode = find_mode(themode)

		-- If the mode exists, switch to this mode.
		-- If not, show modes.
		if mymode then
			win:DisplayMode(mymode)
		else
			win:DisplayModes(win.selectedset)
		end
	else
		win:DisplayModes(win.selectedset)
	end
end

-- If set is "current", returns current set if we are in combat, otherwise returns the last set.
function Skada:find_set(s)
	if s == "current" then
		if Skada.current ~= nil then
			return Skada.current
		elseif Skada.last ~= nil then
			return Skada.last
		else
			return sets[1]
		end
	elseif s == "total" then
		return Skada.total
	else
		return sets[s]
	end
end

-- added by Earwin
function Skada:get_sets()
  return sets
end

-- Returns a player from the current. Safe to use to simply view a player without creating an entry.
function Skada:find_player(set, playerid)
	local player = nil
	for i, p in ipairs(set.players) do
		if p.id == playerid then
			return p
		end
	end
end

-- Returns or creates a player in the current.
function Skada:get_player(set, playerid, playername)
	-- Add player to set if it does not exist.
	local player = nil
	for i, p in ipairs(set.players) do
		if p.id == playerid then
			player = p
		end
	end

	if not player then
		-- If we do not supply a playername (often the case in submodes), we can not create an entry.
		if not playername then
			return
		end
		player = {id = playerid, class = select(2, UnitClass(playername)), name = playername, first = time(), ["time"] = 0}

		-- Tell each mode to apply its needed attributes.
		for i, mode in ipairs(modes) do
			if mode.AddPlayerAttributes ~= nil then
				mode:AddPlayerAttributes(player)
			end
		end

		table.insert(set.players, player)
	end

	-- The total set clears out first and last timestamps.
	if not player.first then
		player.first = time()
	end

	-- Mark now as the last time player did something worthwhile.
	player.last = time()
	changed = true
	return player
end

local combatlogevents = {}
function Skada:RegisterForCL(func, event, flags)
	if not combatlogevents[event] then
		combatlogevents[event] = {}
	end
	tinsert(combatlogevents[event], {["func"] = func, ["flags"] = flags})
end

local band = bit.band
local PET_FLAGS = COMBATLOG_OBJECT_TYPE_PET + COMBATLOG_OBJECT_TYPE_GUARDIAN
local RAID_FLAGS = COMBATLOG_OBJECT_AFFILIATION_MINE + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_RAID

-- The basic idea for CL processing:
-- Modules register for interest in a certain event, along with the function to call and the flags determining if the particular event is interesting.
-- On a new event, loop through the interested parties.
-- The flags are checked, and the flag value (say, that the SRC must be interesting, ie, one of the raid) is only checked once, regardless
-- of how many modules are interested in the event. The check is also only done on the first flag that requires it.
function Skada:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	if disabled then
		return
	end

	local src_is_interesting = nil
	local dst_is_interesting = nil
	local src_is_interesting_nopets = nil
	local dst_is_interesting_nopets = nil

		-- Tentative combat detection.
        if not self.current and srcName and dstName and srcGUID ~= dstGUID and (eventtype == 'SPELL_DAMAGE' or eventtype == 'SPELL_BUILDING_DAMAGE' or eventtype == 'RANGE_DAMAGE' or eventtype == 'SWING_DAMAGE' or eventtype == 'SPELL_PERIODIC_DAMAGE') then
          src_is_interesting = band(srcFlags, RAID_FLAGS) ~= 0 or (band(srcFlags, PET_FLAGS) ~= 0 and pets[srcGUID])
      -- AWS: To avoid incoming periodic damage (e.g. from a debuff) triggering combat, we simply do not initialize
      --      dst_is_interesting for periodic damage...
      if eventtype ~= 'SPELL_PERIODIC_DAMAGE' then
        dst_is_interesting = band(dstFlags, RAID_FLAGS) ~= 0 or (band(dstFlags, PET_FLAGS) ~= 0 and pets[dstGUID])
      end
      if src_is_interesting or dst_is_interesting then
        -- Create a current set and set our "tentative" flag to true.
        self.current = createSet(L["Current"])
      
        -- Also create total set if needed.
        if not self.total then
        self.total = createSet(L["Total"])
      end
      
      -- Schedule an end to this tentative combat situation in 3 seconds.
      tentativehandle = self:ScheduleTimer(
                function()
                  tentative = nil
                  tentativehandle = nil
                  self.current = nil
                  --self:Print("tentative combat start FAILED!")
                end, Skada.db.profile.tentativetimer or 3)
      
                      tentative = (Skada.db.profile.tentativecombatstart and 4) or 0
      --self:Print("tentative combat start INIT!")
      end
    end

	if self.current and combatlogevents[eventtype] then
		for i, mod in ipairs(combatlogevents[eventtype]) do
			local fail = false

--			self:Print("event, "..eventtype)
			-- Lua can not use assignments as expressions... grmbl.
			if not fail and mod.flags.src_is_interesting_nopets then
				if src_is_interesting_nopets == nil then
					src_is_interesting_nopets = band(srcFlags, RAID_FLAGS) ~= 0 and band(srcFlags, PET_FLAGS) == 0
					if src_is_interesting_nopets then
						src_is_interesting = true
					end
				end
				-- Lua does not have a "continue"... grmbl.
				if not src_is_interesting_nopets then
--				self:Print("fail on src_is_interesting_nopets")
					fail = true
				end
			end
			if not fail and mod.flags.dst_is_interesting_nopets then
				if dst_is_interesting_nopets == nil then
					dst_is_interesting_nopets = band(dstFlags, RAID_FLAGS) ~= 0 and band(dstFlags, PET_FLAGS) == 0
					if dst_is_interesting_nopets then
						dst_is_interesting = true
					end
				end
				if not dst_is_interesting_nopets then
--				self:Print("fail on dst_is_interesting_nopets")
					fail = true
				end
			end
			if not fail and mod.flags.src_is_interesting or mod.flags.src_is_not_interesting then
				if src_is_interesting == nil then
					src_is_interesting = band(srcFlags, RAID_FLAGS) ~= 0 or (band(srcFlags, PET_FLAGS) ~= 0 and pets[srcGUID])
				end
				if mod.flags.src_is_interesting and not src_is_interesting then
--				self:Print("fail on src_is_interesting")
					fail = true
				end
				if mod.flags.src_is_not_interesting and src_is_interesting then
					fail = true
				end
			end
			if not fail and mod.flags.dst_is_interesting or mod.flags.dst_is_not_interesting then
				if dst_is_interesting_ == nil then
					dst_is_interesting = band(dstFlags, RAID_FLAGS) ~= 0 or (band(dstFlags, PET_FLAGS) ~= 0 and pets[dstGUID])
				end
				if mod.flags.dst_is_interesting and not dst_is_interesting then
--				self:Print("fail on dst_is_interesting")
					fail = true
				end
				if mod.flags.dst_is_not_interesting and dst_is_interesting then
					fail = true
				end
			end

			-- Pass along event if it did not fail our tests.
			if not fail then
				mod.func(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)

				-- If our "tentative" flag is set and reached the treshold, this means combat really did start.
				if tentative ~= nil then
					tentative = tentative + 1
					if tentative == 5 then
						--self:Print("tentative combat start SUCCESS!")
						self:CancelTimer(tentativehandle)
						tentativehandle = nil
						self:StartCombat()
					end
				end
			end

		end
	end

  -- Note: relies on src_is_interesting having been checked.
  if self.current and src_is_interesting and not self.current.gotboss then
    -- Store mob name for set name. For now, just save first unfriendly name available, or first boss available.
    if bit.band(dstFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~=0 then
      if not self.current.gotboss and boss.BossIDs[tonumber(dstGUID:sub(9, 12), 16)] then
        self.current.mobname = dstName
        self.current.gotboss = true
      elseif not self.current.mobname then
        self.current.mobname = dstName
      end
    end
  end

	-- Pet summons.
	-- Pet scheme: save the GUID in a table along with the GUID of the owner.
	-- Note to self: this needs 1) to be made self-cleaning so it can't grow too much, and 2) saved persistently.
	-- Now also done on raid roster/party changes.
	if eventtype == 'SPELL_SUMMON' and band(srcFlags, RAID_FLAGS) ~= 0 then
		pets[dstGUID] = {id = srcGUID, name = srcName}
	end

end

--
-- Data broker
--

function dataobj:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
    GameTooltip:ClearLines()

    local set
    if Skada.current then
    	set = Skada.current
    else
    	set = sets[1]
    end
    if set then
	    GameTooltip:AddLine(L["Skada summary"], 0, 1, 0)
	    for i, mode in ipairs(modes) do
	    	if mode.AddToTooltip ~= nil then
	    		mode:AddToTooltip(set, GameTooltip)
	    	end
	    end
 	end

    GameTooltip:AddLine(L["Hint: Left-Click to toggle Skada window."], 0, 1, 0)
    GameTooltip:AddLine(L["Shift + Left-Click to reset."], 0, 1, 0)
    GameTooltip:AddLine(L["Right-click to open menu"], 0, 1, 0)

    GameTooltip:Show()
end

function dataobj:OnLeave()
    GameTooltip:Hide()
end

function dataobj:OnClick(button)
	if button == "LeftButton" and IsShiftKeyDown() then
		Skada:Reset()
	elseif button == "LeftButton" then
		Skada:ToggleWindow()
	elseif button == "RightButton" then
		Skada:OpenMenu()
	end
end

function Skada:UpdateDisplay(force)
	-- Force an update by setting our "changed" flag to true.
	if force then
		changed = true
	end

	-- Update data feed.
	-- This is done even if our set has not changed, since for example DPS changes even though the data does not.
	-- Does not update feed text if nil.
	if selectedfeed ~= nil then
		local feedtext = selectedfeed()
		if feedtext then
			dataobj.text = feedtext
		end
	end

	-- Return if we have not changed anything, and we are not in combat.
	if not changed and not self.current then
		return
	end

	for i, win in ipairs(windows) do
		if win.selectedmode then

			local set = win:get_selected_set()

			-- If we have a set, go on.
			if set then
				-- Inform window that a data update will take place.
				win:UpdateInProgress()

				-- Let mode update data.
				if win.selectedmode.Update then
					win.selectedmode:Update(win, set)
				else
					self:Print("Mode "..win.selectedmode:GetName().." does not have an Update function!")
				end

				-- Let window display the data.
				win:UpdateDisplay()
			end

		elseif win.selectedset then
			local set = win:get_selected_set()

			-- View available modes.
			for i, mode in ipairs(modes) do

				local d = win.dataset[i] or {}
				win.dataset[i] = d

				d.id = mode:GetName()
				d.label = mode:GetName()
				d.value = 1
				if set and mode.GetSetSummary ~= nil then
					d.valuetext = mode:GetSetSummary(set)
				end
			end

			-- Tell window to sort by our data order. Our modes are in alphabetical order already.
			win.metadata.ordersort = true

			-- Let window display the data.
			win:UpdateDisplay()
		else
			-- View available sets.
			local nr = 1
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.id = "total"
			d.label = L["Total"]
			d.value = 1

			nr = nr + 1
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.id = "current"
			d.label = L["Current"]
			d.value = 1

			for i, set in ipairs(sets) do
				nr = nr + 1
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = tostring(set.starttime)
				d.label = set.name
				d.valuetext = date("%H:%M",set.starttime).." - "..date("%H:%M",set.endtime)
				d.value = 1
				if set.keep then
					d.emphathize = true
				end
			end

			win.metadata.ordersort = true

			-- Let window display the data.
			win:UpdateDisplay()
		end

	end

	-- Mark as unchanged.
	changed = false
end

function Skada:GetModes()
	return modes
end

--[[

API
Everything below this is OK to use in modes.

--]]

-- Formats a number into human readable form.
function Skada:FormatNumber(number)
	if number then
		if self.db.profile.numberformat == 1 then
			if number > 1000000 then
				return 	("%02.2fM"):format(number / 1000000)
			else
				return 	("%02.1fK"):format(number / 1000)
			end
		else
			return number
		end
	end
end

local function scan_for_columns(mode)
	-- Only process if not already scanned.
	if not mode.scanned then
		mode.scanned = true

		-- Add options for this mode if available.
		if mode.metadata and mode.metadata.columns then
			Skada:AddColumnOptions(mode)
		end

		-- Scan any linked modes.
		if mode.metadata then
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

-- Register a mode.
function Skada:AddMode(mode)
	-- Ask mode to verify our sets.
	-- Needed in case we enable a mode and we have old data.
	if self.total then
		verify_set(mode, self.total)
	end
	if self.current then
		verify_set(mode, self.current)
	end
	for i, set in ipairs(sets) do
		verify_set(mode, set)
	end

	table.insert(modes, mode)

	-- Set this mode as the active mode if it matches the saved one.
	-- Bit of a hack.
	for i, win in ipairs(windows) do
		if mode:GetName() == win.db.mode then
			self:RestoreView(win, win.db.set, mode:GetName())
		end
	end

	-- Find if we now have our chosen feed.
	-- Also a bit ugly.
	if selectedfeed == nil and self.db.profile.feed ~= "" then
		for name, feed in pairs(feeds) do
			if name == self.db.profile.feed then
				self:SetFeed(feed)
			end
		end
	end

	-- Add column configuration if available.
	if mode.metadata then
		scan_for_columns(mode)
	end

	-- Sort modes.
	table.sort(modes, function(a, b) return a.name < b.name end)

	-- Remove all bars and start over to get ordering right.
	-- Yes, this all sucks - the problem with this and the above is that I don't know when
	-- all modules are loaded. :/
	for i, win in ipairs(windows) do
		win:Wipe()
	end
	changed = true
end

-- Unregister a mode.
function Skada:RemoveMode(mode)
	table.remove(modes, mode)
end

function Skada:GetFeeds()
	return feeds
end

-- Register a data feed.
function Skada:AddFeed(name, func)
	feeds[name] = func
end

-- Unregister a data feed.
function Skada:RemoveFeed(name, func)
	for i, feed in ipairs(feeds) do
		if feed.name == name then
			table.remove(feeds, i)
		end
	end
end

--[[

Sets

--]]

function Skada:GetSetTime(set)
	if set.time then
		return set.time
	else
		return (time() - set.starttime)
	end
end

-- Returns the time (in seconds) a player has been active for a set.
function Skada:PlayerActiveTime(set, player)
	local maxtime = 0

	-- Add recorded time (for total set)
	if player.time > 0 then
		maxtime = player.time
	end

	-- Add in-progress time if set is not ended.
	if not set.endtime and player.first then
		maxtime = maxtime + player.last - player.first
	end
	return maxtime
end

-- Modify objects if they are pets.
-- Expects to find "playerid", "playername", and optionally "spellname" in the object.
-- Playerid and playername are exchanged for the pet owner's, and spellname is modified to include pet name.
function Skada:FixPets(action)

  action.playerid=action.playerid or action.srcGUID
  action.playername=action.playername or action.srcName

	if action and not UnitIsPlayer(action.playername) then

		if not pets[action.playerid] then
			-- Fix for guardians; requires "playerflags" to be set from CL.
			if action.playerflags and bit.band(action.playerflags, COMBATLOG_OBJECT_TYPE_GUARDIAN) ~= 0 then
				if bit.band(action.playerflags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~=0 then
					if action.spellname then
						action.spellname = action.playername..": "..action.spellname
					end
					action.playername = UnitName("player")
					action.playerid = UnitGUID("player")
				else
					-- Nothing decent in place here yet. Modify guid so that there will only be 1 similar entry at least. Yes, it won't work for cross-realm.
					action.playerid = action.playername
				end
			end
		end

		local pet = pets[action.playerid]
		if pet then
			if action.spellname then
				action.spellname = action.playername..": "..action.spellname
			end
			action.playername = pet.name
			action.playerid = pet.id
		end
	end
end

function Skada:SetTooltipPosition(tooltip, frame)
	local p = self.db.profile.tooltippos
	if p == "default" then
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		tooltip:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -40, 40);
	elseif p == "topleft" then
    tooltip:SetOwner(frame, "ANCHOR_NONE")
    tooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT")
	elseif p == "topright" then
    tooltip:SetOwner(frame, "ANCHOR_NONE")
    tooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT")
  elseif p == "bottomleft" then
    tooltip:SetOwner(frame, "ANCHOR_NONE")
    tooltip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT")
  elseif p == "bottomright" then
    tooltip:SetOwner(frame, "ANCHOR_NONE")
    tooltip:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT")
  elseif p == "cursor" then
    tooltip:SetOwner(frame, "ANCHOR_CURSOR")
  end
end

-- Same thing, only takes two arguments and returns two arguments.
function Skada:FixMyPets(playerGUID, playerName)
	if not UnitIsPlayer(playerName) then
		local pet = pets[playerGUID]
		if pet then
			return pet.id, pet.name
		end
	end
	-- No pet match - return the player.
	return playerGUID, playerName
end

-- Format value text in a standardized way. Up to 3 value and boolean (show/don't show) combinations are accepted.
-- Values are rendered from left to right.
-- Idea: "compile" a function on the fly instead and store in mode for re-use.
function Skada:FormatValueText(...)
	local value1, bool1, value2, bool2, value3, bool3 = ...

	-- This construction is a little silly.
	if bool1 and bool2 and bool3 then
		return value1.." ("..value2..", "..value3..")"
	elseif bool1 and bool2 then
		return value1.." ("..value2..")"
	elseif bool1 and bool3 then
		return value1.." ("..value3..")"
	elseif bool2 and bool3 then
		return value2.." ("..value3..")"
	elseif bool2 then
		return value2
	elseif bool1 then
		return value1
	elseif bool3 then
		return value3
	end
end

local function value_sort(a,b)
	if not a or a.value == nil then
		return false
	elseif not b or b.value == nil then
		return true
	else
		return a.value > b.value
	end
end

-- Tooltip display. Shows subview data for a specific row.
-- Using a fake window, the subviews are asked to populate the window's dataset normally.
local ttwin = Window:new()
function Skada:AddSubviewToTooltip(tooltip, win, mode, id, label)
	-- Clean dataset.
	wipe(ttwin.dataset)

	-- Tell mode we are entering our real window.
	mode:Enter(win, id, label)

	-- Ask mode to populate dataset in our fake window.
	mode:Update(ttwin, win:get_selected_set())

	-- Sort dataset unless we are using ordersort.
	if not mode.metadata or not mode.metadata.ordersort then
		table.sort(ttwin.dataset, value_sort)
	end

	-- Show title and data if we have data.
	if #ttwin.dataset > 0 then
		tooltip:AddLine(mode.title or mode:GetName(), 1,1,1)

		-- Display the top X, default 3, rows.
		local nr = 0
		for i, data in ipairs(ttwin.dataset) do
			if data.id and nr < Skada.db.profile.tooltiprows then
				nr = nr + 1

				local color = {r = 1, g = 1, b = 1}
				if data.color then
					-- Explicit color from dataset.
					color = data.color
				elseif data.class then
					-- Class color.
					local color = Skada.classcolors[data.class]
				end

				tooltip:AddDoubleLine(nr..". "..data.label, data.valuetext, color.r, color.g, color.b)
			end
		end

		-- Add an empty line.
		tooltip:AddLine(" ")
	end
end


-- A minimal mode showing test data. Used by the config.
--[[
local testmod = {
	name = "Test",
	Update = function(self, win, set)
				for i=1,i<10,1 do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d
					d.value = math.random(100)
					d.label = "Test"
					d.class = math
					d.id = player.id
					d.valuetext = tostring(player.dispells)
				end
			end
}
--]]
