local Skada = LibStub("AceAddon-3.0"):NewAddon("Skada", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")
_G.Skada = Skada
Skada.callbacks = Skada.callbacks or LibStub("CallbackHandler-1.0"):New(Skada)

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)
local ACD = LibStub("AceConfigDialog-3.0")
local DBI = LibStub("LibDBIcon-1.0", true)
local LBB = LibStub("LibBabble-Boss-3.0"):GetLookupTable()
local LBI = LibStub("LibBossIDs-1.0")
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LGT = LibStub("LibGroupTalents-1.0")
local LSM = LibStub("LibSharedMedia-3.0")
local Translit = LibStub("LibTranslit-1.0")

-- holds additional bosses or NPCs.
local bossNames

local dataobj = LDB:NewDataObject("Skada", {
    label = "Skada",
    type = "data source",
    icon = "Interface\\Icons\\Spell_Lightning_LightningBolt01",
    text = "n/a"
})

-- Keybindings
BINDING_HEADER_SKADA = "Skada"
BINDING_NAME_SKADA_TOGGLE = L["Toggle window"]
BINDING_NAME_SKADA_RESET = RESET
BINDING_NAME_SKADA_NEWSEGMENT = L["Start new segment"]
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
local update_timer, tick_timer

-- spell schools
Skada.schoolcolors = {
    [1] = {a = 1.0, r = 1.00, g = 1.00, b = 0.00}, -- Physical
    [2] = {a = 1.0, r = 1.00, g = 0.90, b = 0.50}, -- Holy
    [4] = {a = 1.0, r = 1.00, g = 0.50, b = 0.00}, -- Fire
    [8] = {a = 1.0, r = 0.30, g = 1.00, b = 0.30}, -- Nature
    [16] = {a = 1.0, r = 0.50, g = 1.00, b = 1.00}, -- Frost
    [20] = {a = 1.0, r = 0.50, g = 1.00, b = 1.00}, -- Frostfire
    [32] = {a = 1.0, r = 0.50, g = 0.50, b = 1.00}, -- Shadow
    [64] = {a = 1.0, r = 1.00, g = 0.50, b = 1.00} -- Arcane
}

Skada.schoolnames = {
    [1] = STRING_SCHOOL_PHYSICAL,
    [2] = STRING_SCHOOL_HOLY,
    [4] = STRING_SCHOOL_FIRE,
    [8] = STRING_SCHOOL_NATURE,
    [16] = STRING_SCHOOL_FROST,
    [20] = STRING_SCHOOL_FROSTFIRE,
    [32] = STRING_SCHOOL_SHADOW,
    [64] = STRING_SCHOOL_ARCANE
}

-- list of plyaers and pets
local players, pets = {}, {}

-- list of feeds & selected feed
local feeds, selectedfeed = {}

-- lists of modules and windows
local modes, windows = {}, {}

-- flags for party, instance and ovo
local wasinparty, wasininstance, wasinpvp = false

-- cache frequently used globlas
local tsort, tinsert, tremove, tmaxn = table.sort, table.insert, table.remove, table.maxn
local next, pairs, ipairs, type = next, pairs, ipairs, type
local tonumber, tostring, format, strsplit = tonumber, tostring, string.format, strsplit
local math_floor, math_max = math.floor, math.max
local band, time = bit.band, time
local GetNumPartyMembers, GetNumRaidMembers = GetNumPartyMembers, GetNumRaidMembers
local IsInInstance, UnitAffectingCombat, InCombatLockdown = IsInInstance, UnitAffectingCombat, InCombatLockdown
local UnitGUID, UnitName, UnitClass, UnitIsConnected = UnitGUID, UnitName, UnitClass, UnitIsConnected
local CombatLogClearEntries = CombatLogClearEntries

local RAID_FLAGS = COMBATLOG_OBJECT_AFFILIATION_MINE + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_RAID
local PET_FLAGS = COMBATLOG_OBJECT_TYPE_PET + COMBATLOG_OBJECT_TYPE_GUARDIAN
local SHAM_FLAGS = COMBATLOG_OBJECT_TYPE_NPC + COMBATLOG_OBJECT_CONTROL_NPC

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
        return (GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0)
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

-- because of Auto Shot, this function was added.
function Skada.GetSpellInfo(spellid)
    local res1, res2, res3, res4, res5, res6, res7, res8, res9
    if spellid then
        res1, res2, res3, res4, res5, res6, res7, res8, res9 = GetSpellInfo(spellid)
        if spellid == 75 then
            res3 = "Interface\\Icons\\Ability_Whirlwind"
        end
    end
    return res1, res2, res3, res4, res5, res6, res7, res8, res9
end

-- ============= --
-- needed locals --
-- ============= --

local createSet, verify_set
local find_mode, sort_modes
local IsRaidInCombat, IsRaidDead

-- party/group

local function is_in_pvp()
    local t = select(2, IsInInstance())
    return (t == "pvp" or t == "arena")
end

local function setPlayerActiveTimes(set)
    for i, player in ipairs(set.players) do
        if player.last then
            player.time = math_max(player.time + (player.last - player.first), 0.1)
        end
    end
end

function Skada:PlayerActiveTime(set, player)
    local maxtime = (player.time > 0) and player.time or 0
    if (not set.endtime or set.stopped) and player.first then
        maxtime = maxtime + player.last - player.first
    end
    return maxtime
end

-- utilities

function Skada:ShowPopup()
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
    if not StaticPopupDialogs["SkadaWindowDialog"] then
        StaticPopupDialogs["SkadaWindowDialog"] = {
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
    StaticPopup_Show("SkadaWindowDialog")
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
            name = function()
                return db.name
            end,
            args = {
                rename = {
                    type = "input",
                    name = L["Rename window"],
                    desc = L["Enter the name for the window."],
                    order = 1,
                    width = "full",
                    get = function()
                        return db.name
                    end,
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
                    name = L["Display system"],
                    desc = L["Choose the system to be used for displaying data in this window."],
                    order = 2,
                    values = function()
                        local list = {}
                        for name, display in pairs(Skada.displays) do
                            list[name] = display.name
                        end
                        return list
                    end,
                    get = function()
                        return db.display
                    end,
                    set = function(_, display)
                        db.display = display
                        Skada:ReloadSettings()
                    end
                },
                locked = {
                    type = "toggle",
                    name = L["Lock window"],
                    desc = L["Locks the bar window in place."],
                    order = 4,
                    get = function()
                        return db.barslocked
                    end,
                    set = function()
                        db.barslocked = not db.barslocked
                        Skada:ApplySettings()
                    end
                },
                hidden = {
                    type = "toggle",
                    name = L["Hide window"],
                    desc = L["Hides the window."],
                    order = 5,
                    get = function()
                        return db.hidden
                    end,
                    set = function()
                        db.hidden = not db.hidden
                        Skada:ApplySettings()
                    end
                },
                separator1 = {
                    type = "description",
                    name = " ",
                    order = 7,
                    width = "full"
                },
                copywin = {
                    type = "select",
                    name = L["Copy settings"],
                    desc = L["Choose the window from which you want to copy the settings."],
                    order = 8,
                    values = function()
                        local list = {}
                        for _, win in ipairs(windows) do
                            if win.db.name ~= db.name and win.db.display == db.display then
                                list[win.db.name] = win.db.name
                            end
                        end
                        return list
                    end,
                    get = function()
                        return copywindow
                    end,
                    set = function(_, val)
                        copywindow = val
                    end
                },
                copyexec = {
                    type = "execute",
                    name = L["Copy settings"],
                    order = 9,
                    func = function()
                        local newdb = {}
                        if copywindow then
                            for _, win in ipairs(windows) do
                                if win.db.name == copywindow and win.db.display == db.display then
                                    Skada:tcopy(newdb, win.db, {"name", "snapped", "x", "y", "point"})
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
                    order = 10,
                    width = "full"
                },
                delete = {
                    type = "execute",
                    name = L["Delete window"],
                    desc = L["Choose the window to be deleted."],
                    order = 9,
                    width = "full",
                    confirm = function()
                        return L["Are you sure you want to delete this window?"]
                    end,
                    func = function()
                        Skada:DeleteWindow(db.name)
                    end
                }
            }
        }

        if db.display == "bar" then
            options.args.child = {
                type = "select",
                name = L["Child window"],
                desc = L["A child window will replicate the parent window actions."],
                order = 3,
                values = function()
                    local list = {[""] = NONE}
                    for _, win in ipairs(windows) do
                        if win.db.name ~= db.name and win.db.child ~= db.name and win.db.display == db.display then
                            list[win.db.name] = win.db.name
                        end
                    end
                    return list
                end,
                get = function()
                    return db.child or ""
                end,
                set = function(_, child)
                    db.child = child == "" and nil or child
                    Skada:ReloadSettings()
                end
            }

            options.args.snapto = {
                type = "toggle",
                name = L["Snap window"],
                desc = L["Allows the window to snap to other Skada windows."],
                order = 6,
                get = function()
                    return db.snapto
                end,
                set = function()
                    db.snapto = not db.snapto
                    if not db.snapto then
                        for _, win in ipairs(windows) do
                            if win.db.snapped[db.name] then
                                win.db.snapped[db.name] = nil
                            end
                        end
                    end
                    Skada:ApplySettings()
                end
            }
        end

        options.args.switchoptions = {
            type = "group",
            name = L["Mode switching"],
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
                    end,
                    get = function()
                        return db.modeincombat
                    end,
                    set = function(_, mode)
                        db.modeincombat = mode
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
                    end,
                    get = function()
                        return db.wipemode
                    end,
                    set = function(_, mode)
                        db.wipemode = mode
                    end
                },
                returnaftercombat = {
                    type = "toggle",
                    name = L["Return after combat"],
                    desc = L["Return to the previous set and mode after combat ends."],
                    order = 3,
                    width = "full",
                    get = function()
                        return db.returnaftercombat
                    end,
                    set = function()
                        db.returnaftercombat = not db.returnaftercombat
                    end,
                    disabled = function()
                        return db.returnaftercombat == nil
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
        for _, w in ipairs(windows) do
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
    for _, data in ipairs(self.dataset) do
        wipe(data)
    end
end

function Window:Wipe()
    self:Reset()
    self.display:Wipe(self)

    if self.child then
        self.child:Wipe()
    end
end

function Window:get_selected_set()
    return Skada:find_set(self.selectedset)
end

function Window:set_selected_set(set)
    self.selectedset = set
    if self.child then
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
                return (Skada.db.profile.modeclicks[a:GetName()] or 0) >
                    (Skada.db.profile.modeclicks[b:GetName()] or 0)
            else
                return a:GetName() < b:GetName()
            end
        end)
    end

    local function click_on_mode(win, id, _, button)
        if button == "LeftButton" then
            local mode = find_mode(id)
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
end

-- ================================================== --

function Skada:GetWindows()
    return windows
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

function Skada:CreateWindow(name, db, display)
    local isnew = false
    if not db then
        db, isnew = {}, true
        self:tcopy(db, Skada.windowdefaults)
        tinsert(self.db.profile.windows, db)
    end

    if display then
        db.display = display
    end

    if not db.barbgcolor then
        db.barbgcolor = {r = 0.3, g = 0.3, b = 0.3, a = 0.6}
    end

    if not db.buttons then
        db.buttons = {menu = true, reset = true, report = true, mode = true, segment = true, stop = false}
    end

    if not db.scale then
        db.scale = 1
    end

    if not db.snapped then
        db.snapped = {}
    end

    local window = Window:new()
    window.db = db
    window.db.name = name

    if self.displays[window.db.display] then
        window:SetDisplay(window.db.display or "bar")
        window.display:Create(window)
        tinsert(windows, window)
        window:DisplaySets()

        if isnew and find_mode(L["Damage"]) then
            self:RestoreView(window, "current", L["Damage"])
        elseif window.db.set or window.db.mode then
            self:RestoreView(window, window.db.set, window.db.mode)
        end
    else
        self:Print("Window '" .. name .. "' was not loaded because its display module, '" .. window.db.display .. "' was not found.")
    end

    isnew = nil
    self:ApplySettings()
    return window
end

function Skada:DeleteWindow(name)
    for i, win in ipairs(windows) do
        if win.db.name == name then
            win:destroy()
            wipe(tremove(windows, i))
        elseif win.db.child == name then
            win.db.child, win.child = nil, nil
        end
    end

    for i, win in ipairs(self.db.profile.windows) do
        if win.name == name then
            tremove(self.db.profile.windows, i)
        end
    end
end

function Skada:ToggleWindow()
    for _, win in ipairs(windows) do
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
        win:DisplayMode(find_mode(themode) or win.selectedset)
    else
        win:DisplayModes(win.selectedset)
    end
end

function Skada:Wipe()
    for _, win in ipairs(windows) do
        win:Wipe()
    end
end

function Skada:SetActive(enable)
    if enable then
        for _, win in ipairs(windows) do
            win:Show()
        end
    else
        for _, win in ipairs(windows) do
            win:Hide()
        end
    end

    if not enable and self.db.profile.hidedisables then
        disabled = true
        self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        disabled = false
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatLogEvent")
    end

    self:UpdateDisplay(true)
end

-- =============== --
-- MODES FUNCTIONS --
-- =============== --

function find_mode(name)
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
            verify_set(mode, self.total)
        end

        if self.current then
            verify_set(mode, self.current)
        end

        for _, set in ipairs(self.char.sets) do
            verify_set(mode, set)
        end

        mode.category = category or OTHER
        tinsert(modes, mode)

        for _, win in ipairs(windows) do
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

        for _, win in ipairs(windows) do
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

function Skada:AddLoadableModule(name, description, func)
    if type(description) == "function" then
        func = description
        description = nil
    end

    self.modulelist = self.modulelist or {}
    self.modulelist[#self.modulelist + 1] = func

    self:AddLoadableModuleCheckbox(name, L[name], description and L[description])
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

function createSet(setname, starttime)
    starttime = starttime or time()
    local set = {players = {}, name = setname, starttime = starttime, last_action = starttime, time = 0}
    for _, mode in ipairs(modes) do
        verify_set(mode, set)
    end
    return set
end

function verify_set(mode, set)
    if mode.AddSetAttributes then
        mode:AddSetAttributes(set)
    end

    if mode.AddPlayerAttributes then
        for _, player in ipairs(set.players) do
            mode:AddPlayerAttributes(player, set)
        end
    end
end

function Skada:get_sets()
    return self.char.sets
end

function Skada:find_set(s)
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
    if not set then
        return
    end

    for i, s in ipairs(self.char.sets) do
        if s == set then
            wipe(tremove(self.char.sets, i))

            if set == self.last then
                self.last = nil
            end

            -- Don't leave windows pointing to deleted sets
            for _, win in ipairs(windows) do
                if win.selectedset == i or win:get_selected_set() == set then
                    win.selectedset = "current"
                    win.changed = true
                elseif (tonumber(win.selectedset) or 0) > i then
                    win.selectedset = win.selectedset - 1
                    win.changed = true
                end
            end
            break
        end
    end

    self:Wipe()
    self:CleanGarbage(true)
    self:UpdateDisplay(true)
end

function Skada:GetSetTime(set)
    if set.time and set.time > 0 then
        return set.time
    end

    return math_max(time() - set.starttime, 0.1)
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
        local points = LGT:UnitHasTalent(unit, GetSpellInfo(57881), LGT:GetActiveTalentGroup(unit))
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
    function Skada:FixPlayer(player)
        if player.id and player.name then
            -- collect some info from the player's guid
            local name, class, _

            -- the only way to fix this error is to literally
            -- ignore it if we don't have a valid GUID.
            if player.id and #player.id ~= 18 then
                self.callbacks:Fire("FixPlayer", player)
                return player
            elseif player.id and #player.id == 18 then
                class, _, _, _, name = select(2, GetPlayerInfoByGUID(player.id))
            end

            -- fix the name
            if player.id == player.name and name and name ~= player.name then
                player.name = name
            end

            -- use LibTranslit to convert cyrillic letters into western letters.
            if self.db.profile.translit and Translit then
                player.name = Translit:Transliterate(player.name, "!")
            end

            -- fix the pet classes
            if pets[player.id] then
                -- fix classes for others
                player.class = "PET"
                player.role = "DAMAGER"
                player.spec = 1
                player.owner = pets[player.id]
            elseif self:IsBoss(player.id) then
                player.class = "MONSTER"
                player.role = "DAMAGER"
                player.spec = 3
            end

            -- still no class assigned?
            if not player.class then
                -- class already received from GetPlayerInfoByGUID?
                if class then
                    -- it's a real player?
                    player.class = class
                elseif UnitIsPlayer(player.name) then
                    player.class = select(2, UnitClass(player.name))
                elseif player.flag and band(player.flag, 0x00000400) ~= 0 then
                    -- pets?
                    player.class = "UNGROUPPLAYER"
                    player.role = "DAMAGER"
                    player.spec = 2
                elseif player.flag and band(player.flag, 0x00003000) ~= 0 then
                    --  last solution
                    player.class = "PET"
                    player.role = "DAMAGER"
                    player.owner = pets[player.id]
                    player.spec = 1
                else
                    player.class = "UNKNOWN"
                    player.role = "DAMAGER"
                    player.spec = 2
                end
            end

            -- if the player has been assigned a valid class,
            -- we make sure to assign his/her role and spec
            if self.validclass[player.class] then
                if not player.role then
                    player.role = self:UnitGroupRolesAssigned(player.name)
                end
                if not player.spec then
                    player.spec = self:GetPlayerSpecID(player.name, player.class)
                end
            else
                player.role = player.role or "DAMAGER" -- damager fallback
                player.spec = player.spec or 2 -- unknown fallback
            end

            self.callbacks:Fire("FixPlayer", player)
            name, class = nil, nil
        end
    end
end

function Skada:find_player(set, playerid, playername)
    if set and playerid then
        set._playeridx = set._playeridx or {}
        local player = set._playeridx[playerid]
        if player then
            return player
        end
        for _, p in ipairs(set.players) do
            if p.id == playerid then
                set._playeridx[playerid] = p
                return p
            end
        end
        -- needed for bosses.
        if self:IsBoss(playerid) and playername then
            player = {
                id = playerid,
                name = playername,
                class = "MONSTER",
                role = "DAMAGER",
                spec = 3
            }
            set._playeridx[playerid] = player
            return player
        end
    end
end

function Skada:get_player(set, playerid, playername, playerflag)
    local player = self:find_player(set, playerid, playername)

    local now = time()

    if not player then
        if not playername then
            return
        end

        player = {
            id = playerid,
            name = playername,
            flag = playerflag,
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

    player.first = player.first or now
    player.last = now
    changed = true
    return player
end

function Skada:IsPlayer(playerid)
    return players[playerid]
end

function Skada:IsBoss(GUID)
    return GUID and LBI.BossIDs[tonumber(GUID:sub(9, 12), 16)]
end

-- ================== --
-- FIX PETS FUNCTIONS --
-- ================== --
do
    -- create our scan tooltip
    local tooltip = CreateFrame("GameTooltip", "SkadaPetTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

    local ownerPatterns = {}
    for i = 1, 44 do
        local title = _G["UNITNAME_SUMMON_TITLE" .. i]
        if title and title ~= "%s" and title:find("%s", nil, true) then
            local pattern = title:gsub("%%s", "(.-)")
            tinsert(ownerPatterns, pattern)
            title, pattern = nil, nil
        end
    end

    local function GetPetOwner(guid)
        tooltip:SetHyperlink("unit:" .. guid)
        for i = 2, tooltip:NumLines() do
            local text = _G["SkadaPetTooltipTextLeft" .. i]:GetText()
            if text then
                for _, pattern in next, ownerPatterns do
                    local owner = text:match(pattern)
                    if owner then
                        return owner
                    end
                end
            end
        end
    end

    function Skada:FixPets(action)
        if not action or not action.playername or not action.playerid then
            return
        end

        local owner = pets[action.playerid]

        -- we try to associate pets and and guardians with their owner
        if not owner and action.playerflags and band(action.playerflags, PET_FLAGS) ~= 0 and band(action.playerflags, RAID_FLAGS) ~= 0 then
            if band(action.playerflags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0 then
                owner = {id = UnitGUID("player"), name = UnitName("player")}
                pets[action.playerid] = owner
            else
                local ownerName = GetPetOwner(action.playerid)
                if ownerName then
                    local guid = UnitGUID(ownerName)
                    if players[guid] then
                        owner = {id = guid, name = ownerName}
                        pets[action.playerid] = owner
                    end
                    ownerName, guid = nil, nil
                end
            end

            if not owner then
                action.playerid = action.playername
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
                action.playername = action.playername .. " (" .. owner.name .. ")"
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
    local p = self.db.profile.tooltippos
    if p == "default" then
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -40, 40)
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
    elseif p == "smart" and frame then
        if display == "inline" then
            tooltip:SetOwner(frame, "ANCHOR_CURSOR")
        elseif frame:GetLeft() < (GetScreenWidth() / 2) then
            tooltip:SetOwner(frame, "ANCHOR_NONE")
            tooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT", 10, 0)
        else
            tooltip:SetOwner(frame, "ANCHOR_NONE")
            tooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT", -10, 0)
        end
    end
    p = nil
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
        if not mode then
            return
        end

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
                    elseif data.class and Skada.classcolors[data.class] then
                        color = Skada.classcolors[data.class]
                    end

                    local title = data.label
                    if mode.metadata and mode.metadata.showspots then
                        title = nr .. ". " .. title
                    end
                    tooltip:AddDoubleLine(title, data.valuetext, color.r, color.g, color.b)
                    color, title = nil, nil
                end
            end
            nr = nil

            if mode.Enter then
                tooltip:AddLine(" ")
            end
        end
    end
end

function Skada:ShowTooltip(win, id, label)
    local t = GameTooltip

    if Skada.db.profile.tooltips then
        if win.metadata.is_modelist and Skada.db.profile.informativetooltips then
            t:ClearLines()
            Skada:AddSubviewToTooltip(t, win, find_mode(id), id, label)
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

            if Skada.db.profile.informativetooltips then
                if win.metadata.click1 then
                    Skada:AddSubviewToTooltip(t, win, win.metadata.click1, id, label)
                end
                if win.metadata.click2 then
                    Skada:AddSubviewToTooltip(t, win, win.metadata.click2, id, label)
                end
                if win.metadata.click3 then
                    Skada:AddSubviewToTooltip(t, win, win.metadata.click3, id, label)
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
                t:AddLine(L["Click for"] .. " " .. win.metadata.click1:GetName() .. ".", 0.2, 1, 0.2)
            end
            if win.metadata.click2 then
                t:AddLine(L["Shift-Click for"] .. " " .. win.metadata.click2:GetName() .. ".", 0.2, 1, 0.2)
            end
            if win.metadata.click3 then
                t:AddLine(L["Control-Click for"] .. " " .. win.metadata.click3:GetName() .. ".", 0.2, 1, 0.2)
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
    elseif param == "config" then
        self:OpenOptions()
    elseif param == "clear" or param == "clean" then
        self:CleanGarbage(true)
    elseif param:sub(1, 6) == "report" then
        param = param:sub(7)

        local w1, w2, w3 = self:GetArgs(param, 3)

        local chan = w1 or "say"
        local report_mode_name = w2 or L["Damage"]
        local max = tonumber(w3 or 10)
        w1, w2, w3 = nil, nil, nil

        -- Sanity checks.
        if chan and (chan == "say" or chan == "guild" or chan == "raid" or chan == "party" or chan == "officer") and (report_mode_name and find_mode(report_mode_name)) then
            self:Report(chan, "preset", report_mode_name, "current", max)
        else
            self:Print("Usage:")
            self:Print(format("%-20s", "/skada report [raid|guild|party|officer|say] [mode] [max lines]"))
        end
    else
        self:Print("Usage:")
        self:Print(format("%-20s", "/skada report [raid|guild|party|officer|say] [mode] [max lines]"))
        self:Print(format("%-20s", "/skada reset"))
        self:Print(format("%-20s", "/skada toggle"))
        self:Print(format("%-20s", "/skada newsegment"))
        self:Print(format("%-20s", "/skada config"))
        self:Print(format("%-20s", "/skada clear"))
    end
end

-- =============== --
-- REPORT FUNCTION --
-- =============== --
do
    local SendChatMessage = SendChatMessage

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
            Skada:Print(msg)
        elseif chantype == "channel" then
            SendChatMessage(msg, "CHANNEL", nil, chan)
        elseif chantype == "preset" then
            SendChatMessage(msg, string.upper(chan))
        elseif chantype == "whisper" then
            SendChatMessage(msg, "WHISPER", nil, chan)
        elseif chantype == "bnet" then
            BNSendWhisper(chan, msg)
        end
    end

    function Skada:Report(channel, chantype, report_mode_name, report_set_name, max, window)
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
            report_mode = find_mode(report_mode_name)
            report_set = self:find_set(report_set_name)
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

        local title = window.title or report_mode.title or report_mode:GetName()
        local label = (report_mode_name == L["Improvement"]) and UnitName("player") or Skada:GetSetLabel(report_set)
        sendchat(format(L["Skada: %s for %s:"], title, label), channel, chantype)

        local nr = 1
        for _, data in ipairs(report_table.dataset) do
            if data.id and not data.ignore then
                if report_mode.metadata and report_mode.metadata.showspots then
                    sendchat(format("%2u. %s   %s", nr, data.label, data.valuetext), channel, chantype)
                else
                    sendchat(format("%s   %s", data.label, data.valuetext), channel, chantype)
                end
                nr = nr + 1
            end
            if nr > max then
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

function Skada:AssignPet(ownerGUID, ownerName, petGUID)
    pets[petGUID] = {id = ownerGUID, name = ownerName}
end

function Skada:GetPetOwner(petGUID)
    return pets[petGUID]
end

function Skada:IsPet(petGUID)
    return (pets[petGUID] ~= nil)
end

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
                    pets[petGUID] = {id = unitGUID, name = select(1, UnitName(unit))}
                end
            end
        end
    end

    local unitGUID = UnitGUID("player")
    if unitGUID then
        players[unitGUID] = true
        local petGUID = UnitGUID("pet")
        if petGUID and not pets[petGUID] then
            pets[petGUID] = {id = unitGUID, name = select(1, UnitName("player"))}
        end
    end
end

function Skada:ZoneCheck()
    local inInstance, instanceType = IsInInstance()
    local isininstance = inInstance and (instanceType == "party" or instanceType == "raid")
    local isinpvp = is_in_pvp()

    if isininstance and wasininstance ~= nil and not wasininstance and self.db.profile.reset.instance ~= 1 and Skada:CanReset() then
        if self.db.profile.reset.instance == 3 then
            self:ShowPopup()
        else
            self:Reset()
        end
    end

    if self.db.profile.hidepvp then
        if is_in_pvp() then
            Skada:SetActive(false)
        elseif wasinpvp then
            Skada:SetActive(true)
        end
    end

    if isininstance then
        wasininstance = true
    else
        wasininstance = false
    end

    if isinpvp then
        wasinpvp = true
    else
        wasinpvp = false
    end
end

function Skada:PLAYER_ENTERING_WORLD()
    self:ZoneCheck()
    wasinparty = IsInGroup()
    self:CheckGroup()
end

do
    local function check_for_join_and_leave()
        if not IsInGroup() and wasinparty then
            if Skada.db.profile.reset.leave == 3 and Skada:CanReset() then
                Skada:ShowPopup()
            elseif Skada.db.profile.reset.leave == 2 and Skada:CanReset() then
                Skada:Reset()
            end

            if Skada.db.profile.hidesolo then
                Skada:SetActive(false)
            end
        end

        if IsInGroup() and not wasinparty then
            if Skada.db.profile.reset.join == 3 and Skada:CanReset() then
                Skada:ShowPopup()
            elseif Skada.db.profile.reset.join == 2 and Skada:CanReset() then
                Skada:Reset()
            end

            if Skada.db.profile.hidesolo and not (Skada.db.profile.hidepvp and is_in_pvp()) then
                Skada:SetActive(true)
            end
        end

        wasinparty = not (not IsInGroup())
    end

    function Skada:PARTY_MEMBERS_CHANGED()
        check_for_join_and_leave()
        self:CheckGroup()
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

function Skada:Reset()
    self:Wipe()
    players, pets = {}, {}
    self:CheckGroup()

    if self.current ~= nil then
        wipe(self.current)
        self.current = createSet(L["Current"])
    end

    if self.total ~= nil then
        wipe(self.total)
        self.total = createSet(L["Total"])
        self.char.total = self.total
    end
    self.last = nil

    for i = tmaxn(self.char.sets), 1, -1 do
        if not self.char.sets[i].keep then
            wipe(tremove(self.char.sets, i))
        end
    end

    for _, win in ipairs(windows) do
        if win.selectedset ~= "total" then
            win.selectedset = "current"
            win.changed = true
        end
    end

    dataobj.text = "n/a"
    self:UpdateDisplay(true)
    self:Print(L["All data has been reset."])
    L_CloseDropDownMenus()

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

    for _, win in ipairs(windows) do
        if (changed or win.changed) or self.current then
            win.changed = false
            win:SetChild(win.db.child)

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
                        d.icon = dataobj.icon
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
                    if mode.metadata and mode.metadata.icon then
                        d.icon = mode.metadata.icon
                    end
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
        return SetLabelFormat(set.name or "Unknown", set.starttime, set.endtime or time())
    end

    function Window:set_mode_title()
        if not self.selectedmode or not self.selectedset then
            return
        end
        if not self.selectedmode.GetName then
            return
        end
        local name = self.title or self.selectedmode.title or self.selectedmode:GetName()

        -- save window settings for RestoreView after reload
        self.db.set = self.selectedset
        local savemode = name
        if self.history[1] then -- can't currently preserve a nested mode, use topmost one
            savemode = self.history[1].title or self.history[1]:GetName()
        end
        self.db.mode = savemode
        savemode = nil

        if self.db.titleset and self.db.display ~= "inline" then
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
        end
        self.metadata.title = name
        self.display:SetTitle(self, name)
        name = nil
    end
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
        self.tooltip:AddLine(L["Skada summary"], 0, 1, 0)
        self.tooltip:AddDoubleLine(L["Segment Time"], Skada:GetFormatedSetTime(set), 1, 1, 1)
        for _, mode in ipairs(modes) do
            if mode.AddToTooltip ~= nil then
                mode:AddToTooltip(set, self.tooltip)
            end
        end
        self.tooltip:AddLine(" ")
    else
        self.tooltip:AddLine("Skada", 1, 1, 1)
    end

    self.tooltip:AddLine(L["Left-Click to toggle windows."])
    self.tooltip:AddLine(L["Shift+Left-Click to reset."])
    self.tooltip:AddLine(L["Right-click to open menu"])

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
    for _, win in ipairs(windows) do
        win.display:ApplySettings(win)
    end

    if (self.db.profile.hidesolo and not IsInGroup()) or (self.db.profile.hidepvp and is_in_pvp()) then
        self:SetActive(false)
    else
        self:SetActive(true)

        for _, win in ipairs(windows) do
            if win.db.hidden and win:IsShown() then
                win:Hide()
            end
        end
    end

    self:UpdateDisplay(true)
end

function Skada:ReloadSettings()
    for _, win in ipairs(windows) do
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
        order = 2,
        args = {
            bgheader = {
                type = "header",
                name = L["Background"],
                order = 1,
                width = "full"
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
                width = "full",
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
                width = "full",
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
                width = "full",
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
                width = "full"
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
                width = "full",
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
                width = "full",
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
                width = "full"
            },
            scale = {
                type = "range",
                name = L["Scale"],
                desc = L["Sets the scale of the window."],
                order = 11,
                width = "full",
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
                width = "full",
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
    LSM:Register("font", "ABF", [[Interface\Addons\Skada\media\fonts\ABF.ttf]])
    LSM:Register("font", "Accidental Presidency", [[Interface\Addons\Skada\media\fonts\Accidental Presidency.ttf]])
    LSM:Register("font", "Adventure", [[Interface\Addons\Skada\media\fonts\Adventure.ttf]])
    LSM:Register("font", "Diablo", [[Interface\Addons\Skada\media\fonts\Diablo.ttf]])
    LSM:Register("font", "Forced Square", [[Interface\Addons\Skada\media\fonts\FORCED SQUARE.ttf]])
    LSM:Register("font", "Hooge", [[Interface\Addons\Skada\media\fonts\Hooge.ttf]])

    LSM:Register("statusbar", "Aluminium", [[Interface\Addons\Skada\media\statusbar\Aluminium]])
    LSM:Register("statusbar", "Armory", [[Interface\Addons\Skada\media\statusbar\Armory]])
    LSM:Register("statusbar", "BantoBar", [[Interface\Addons\Skada\media\statusbar\BantoBar]])
    LSM:Register("statusbar", "Details", [[Interface\AddOns\Skada\media\statusbar\Details]])
    LSM:Register("statusbar", "Flat", [[Interface\Addons\Skada\media\statusbar\Flat]])
    LSM:Register("statusbar", "Glass", [[Interface\AddOns\Skada\media\statusbar\Glass]])
    LSM:Register("statusbar", "Gloss", [[Interface\Addons\Skada\media\statusbar\Gloss]])
    LSM:Register("statusbar", "Graphite", [[Interface\Addons\Skada\media\statusbar\Graphite]])
    LSM:Register("statusbar", "Grid", [[Interface\Addons\Skada\media\statusbar\Grid]])
    LSM:Register("statusbar", "Healbot", [[Interface\Addons\Skada\media\statusbar\Healbot]])
    LSM:Register("statusbar", "LiteStep", [[Interface\Addons\Skada\media\statusbar\LiteStep]])
    LSM:Register("statusbar", "Minimalist", [[Interface\Addons\Skada\media\statusbar\Minimalist]])
    LSM:Register("statusbar", "Otravi", [[Interface\Addons\Skada\media\statusbar\Otravi]])
    LSM:Register("statusbar", "Outline", [[Interface\Addons\Skada\media\statusbar\Outline]])
    LSM:Register("statusbar", "Round", [[Interface\Addons\Skada\media\statusbar\Round]])
    LSM:Register("statusbar", "Serenity", [[Interface\AddOns\Skada\media\statusbar\Serenity]])
    LSM:Register("statusbar", "Smooth v2", [[Interface\Addons\Skada\media\statusbar\Smoothv2]])
    LSM:Register("statusbar", "Smooth", [[Interface\Addons\Skada\media\statusbar\Smooth]])
    LSM:Register("statusbar", "TukTex", [[Interface\Addons\Skada\media\statusbar\TukTex]])
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
end

function Skada:MemoryCheck()
    if self.db.profile.memorycheck then
        UpdateAddOnMemoryUsage()
        local mem = GetAddOnMemoryUsage("Skada")
        if mem > 30000 then
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

function Skada:OnEnable()
    self:RegisterComm("Skada")
    self:ReloadSettings()

    if not self.classcolors then
        self.classcolors = {
            ["DEATHKNIGHT"] = {r = 0.77, g = 0.12, b = 0.23},
            ["DRUID"] = {r = 1, g = 0.49, b = 0.04},
            ["ENEMY"] = {r = 0.94117, g = 0, 0.0196, b = 1},
            ["HUNTER"] = {r = 0.67, g = 0.83, b = 0.45},
            ["MAGE"] = {r = 0.41, g = 0.8, b = 0.94},
            ["NEUTRAL"] = {r = 1, g = 1, b = 0},
            ["PALADIN"] = {r = 0.96, g = 0.55, b = 0.73},
            ["PET"] = {r = 0.3, g = 0.4, b = 0.5},
            ["PRIEST"] = {r = 1, g = 1, b = 1},
            ["ROGUE"] = {r = 1, g = 0.96, b = 0.41},
            ["SHAMAN"] = {r = 0, g = 0.44, b = 0.87},
            ["UNKNOWN"] = {r = 0.2, g = 0.2, b = 0.2},
            ["WARLOCK"] = {r = 0.58, g = 0.51, b = 0.79},
            ["WARRIOR"] = {r = 0.78, g = 0.61, b = 0.43}
        }
    end

    if not self.validclass then
        self.validclass = {
            ["DEATHKNIGHT"] = true,
            ["DRUID"] = true,
            ["HUNTER"] = true,
            ["MAGE"] = true,
            ["PALADIN"] = true,
            ["PRIEST"] = true,
            ["ROGUE"] = true,
            ["SHAMAN"] = true,
            ["WARLOCK"] = true,
            ["WARRIOR"] = true
        }
    end

    -- please do not localize this line!
    L["Auto Attack"] = select(1, GetSpellInfo(6603))

    -- Gunship
    LBI.BossIDs[37215] = true -- Orgrim's Hammer
    LBI.BossIDs[37540] = true -- The Skybreaker

    LBB["Kor'kron Sergeant"] = L["Kor'kron Sergeant"]
    LBB["Kor'kron Axethrower"] = L["Kor'kron Axethrower"]
    LBB["Kor'kron Rocketeer"] = L["Kor'kron Rocketeer"]
    LBB["Kor'kron Battle-Mage"] = L["Kor'kron Battle-Mage"]
    LBB["Skybreaker Sergeant"] = L["Skybreaker Sergeant"]
    LBB["Skybreaker Rifleman"] = L["Skybreaker Rifleman"]
    LBB["Skybreaker Mortar Soldier"] = L["Skybreaker Mortar Soldier"]
    LBB["Skybreaker Sorcerer"] = L["Skybreaker Sorcerer"]

    -- we add some adds to LibBabble-Boss so we can fix the
    -- set name later to use the "real" boss name instead
    LBB["Dream Cloud"] = L["Dream Cloud"]
    LBB["Blazing Skeleton"] = L["Blazing Skeleton"]
    LBB["Blistering Zombie"] = L["Blistering Zombie"]
    LBB["Gluttonous Abomination"] = L["Gluttonous Abomination"]

    if not bossNames then
        bossNames = {
            -- Icecrown Gunship Battle
            [LBB["Kor'kron Sergeant"]] = LBB["Icecrown Gunship Battle"],
            [LBB["Kor'kron Axethrower"]] = LBB["Icecrown Gunship Battle"],
            [LBB["Kor'kron Rocketeer"]] = LBB["Icecrown Gunship Battle"],
            [LBB["Kor'kron Battle-Mage"]] = LBB["Icecrown Gunship Battle"],
            [LBB["Skybreaker Sergeant"]] = LBB["Icecrown Gunship Battle"],
            [LBB["Skybreaker Rifleman"]] = LBB["Icecrown Gunship Battle"],
            [LBB["Skybreaker Mortar Soldier"]] = LBB["Icecrown Gunship Battle"],
            [LBB["Skybreaker Sorcerer"]] = LBB["Icecrown Gunship Battle"],
            -- Blood Prince Council
            [LBB["Prince Valanar"]] = LBB["Blood Prince Council"],
            [LBB["Prince Taldaram"]] = LBB["Blood Prince Council"],
            [LBB["Prince Keleseth"]] = LBB["Blood Prince Council"],
            -- Valithria Dreamwalker
            [LBB["Dream Cloud"]] = LBB["Valithria Dreamwalker"],
            [LBB["Blazing Skeleton"]] = LBB["Valithria Dreamwalker"],
            [LBB["Blistering Zombie"]] = LBB["Valithria Dreamwalker"],
            [LBB["Gluttonous Abomination"]] = LBB["Valithria Dreamwalker"]
        }
    end

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("RAID_ROSTER_UPDATE")
    self:RegisterEvent("UNIT_PET")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
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
end

-- ======================================================= --
-- AddOn Synchronization

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

do
    local function DispatchComm(sender, ok, commType, ...)
        if ok and type(commType) == "string" then
            Skada.callbacks:Fire("OnComm" .. commType, sender, ...)
        end
    end

    function Skada:OnCommReceived(prefix, message, channel, sender)
        if channel then
            DispatchComm(sender, self:Deserialize(message))
        end
    end
end

-- ======================================================= --

do
    function IsRaidInCombat()
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

    function IsRaidDead()
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
        if not self.current then
            return
        end

        local now = time()

        if not self.db.profile.onlykeepbosses or self.current.gotboss then
            if self.current.mobname ~= nil and now - self.current.starttime > 5 then
                self.current.endtime = self.current.endtime or now
                self.current.time = math_max(self.current.endtime - self.current.starttime, 0.1)
                setPlayerActiveTimes(self.current)
                self.current.stopped = nil

                -- try to fix Gunship and Valithria set names.
                if bossNames[self.current.mobname] then
                    self.current.mobname = bossNames[self.current.mobname]
                end

                local setname = self.current.mobname
                if self.db.profile.setnumber then
                    local max = 0
                    for _, set in ipairs(self.char.sets) do
                        if set.name == setname and max == 0 then
                            max = 1
                        else
                            local n, c = set.name:match("^(.-)%s*%((%d+)%)$")
                            if n == setname then
                                max = math_max(max, tonumber(c) or 0)
                            end
                        end
                    end
                    if max > 0 then
                        setname = format("%s (%s)", setname, max + 1)
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

        self.total.time = self.total.time + self.current.time
        setPlayerActiveTimes(self.total)

        for _, player in ipairs(self.total.players) do
            player.first = nil
            player.last = nil
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

        for _, win in ipairs(windows) do
            win:Wipe()
            changed = true

            if win.db.wipemode ~= "" and IsRaidDead() then
                self:RestoreView(win, "current", win.db.wipemode)
            elseif win.db.returnaftercombat and win.restore_mode and win.restore_set then
                if win.restore_set ~= win.selectedset or win.restore_mode ~= win.selectedmode then
                    self:RestoreView(win, win.restore_set, win.restore_mode)

                    win.restore_mode, win.restore_set = nil, nil
                end
            end

            if not win.db.hidden and self.db.profile.hidecombat and (not self.db.profile.hidesolo or IsInGroup()) then
                win:Hide()
            end
        end

        self:UpdateDisplay(true)
        if update_timer and not update_timer._cancelled then
            update_timer:Cancel()
        end
        if tick_timer and not tick_timer._cancelled then
            tick_timer:Cancel()
        end
        update_timer, tick_timer = nil, nil

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
end

-- ======================================================= --

do
    local tentative, tentativehandle
    local deathcounter, startingmembers = 0, 0

    local function combat_tick()
        if not disabled and Skada.current and not InCombatLockdown() and not IsRaidInCombat() then
            Skada.callbacks:Fire("ENCOUNTER_END", Skada.current)
            Skada.After(1, function() Skada:EndSegment() end)
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
            self:EndSegment()
        end

        self:Wipe()

        local starttime = time()

        if not self.current then
            self.current = createSet(L["Current"], starttime)
        end

        if self.total == nil then
            self.total = createSet(L["Total"], starttime)
            self.char.total = self.total
        end

        for _, win in ipairs(windows) do
            if win.db.modeincombat ~= "" then
                local mymode = find_mode(win.db.modeincombat)

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

            if not win.db.hidden and self.db.profile.hidecombat then
                win:Hide()
            end
        end

        self:UpdateDisplay(true)

        update_timer = self.NewTicker(self.db.profile.updatefrequency or 0.25, function() self:UpdateDisplay() end)
        tick_timer = self.NewTicker(1, combat_tick)
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

    -- events used to trigger combat
    local triggerevents = {
        ["RANGE_DAMAGE"] = true,
        ["SPELL_BUILDING_DAMAGE"] = true,
        ["SPELL_DAMAGE"] = true,
        ["SPELL_PERIODIC_DAMAGE"] = true,
        ["SWING_DAMAGE"] = true
    }

    -- bosses to be be ignored for smart stop feature
    -- this was added because the following NPCs are
    -- used to fix segment names, as soon as they die
    -- skada will stop collecting and to prevent this
    -- we have to ignore them.
    local dumbbosses = {
        -- Icecrown Gunship Battle
        [LBB["Icecrown Gunship Battle"]] = true,
        [L["Kor'kron Sergeant"]] = true,
        [L["Kor'kron Axethrower"]] = true,
        [L["Kor'kron Rocketeer"]] = true,
        [L["Kor'kron Battle-Mage"]] = true,
        [L["Skybreaker Sergeant"]] = true,
        [L["Skybreaker Rifleman"]] = true,
        [L["Skybreaker Mortar Soldier"]] = true,
        [L["Skybreaker Sorcerer"]] = true,
        -- Valithria Dreamwalker
        [LBB["Valithria Dreamwalker"]] = true,
        [L["Dream Cloud"]] = true,
        [L["Blazing Skeleton"]] = true,
        [L["Blistering Zombie"]] = true,
        [L["Gluttonous Abomination"]] = true
    }

    local combatlogevents = {}

    function Skada:RegisterForCL(func, event, flags)
        combatlogevents[event] = combatlogevents[event] or {}
        tinsert(combatlogevents[event], {["func"] = func, ["flags"] = flags})
    end

    function Skada:IsBoss(GUID)
        return GUID and LBI.BossIDs[tonumber(GUID:sub(9, 12), 16)]
    end

    function Skada:CombatLogEvent(_, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
        if ignoredevents[eventtype] then
            return
        end

        local src_is_interesting = nil
        local dst_is_interesting = nil
        local now = time()

        if not self.current and self.db.profile.tentativecombatstart and srcName and dstName and srcGUID ~= dstGUID and triggerevents[eventtype] then
            src_is_interesting = band(srcFlags, RAID_FLAGS) ~= 0 or (band(srcFlags, PET_FLAGS) ~= 0 and pets[srcGUID]) or players[srcGUID]

            if eventtype ~= "SPELL_PERIODIC_DAMAGE" then
                dst_is_interesting = band(dstFlags, RAID_FLAGS) ~= 0 or (band(dstFlags, PET_FLAGS) ~= 0 and pets[dstGUID]) or players[dstGUID]
            end

            if src_is_interesting or dst_is_interesting then
                self.current = createSet(L["Current"], now)

                if not self.total then
                    self.total = createSet(L["Total"], now)
                end
                tentativehandle = self.NewTimer(self.db.profile.tentativetimer or 1, function()
                    tentative = nil
                    tentativehandle = nil
                    self.current = nil
                end)
                tentative = 0
            end
        end

        -- ENCOUNTER_START custom event
        if self.current and not self.current.started then
            self.callbacks:Fire("ENCOUNTER_START", timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
            self.current.started = true
        end

        if self.current and self.db.profile.autostop then
            if self.current and eventtype == "UNIT_DIED" and ((band(srcFlags, RAID_FLAGS) ~= 0 and band(srcFlags, PET_FLAGS) == 0) or players[srcGUID]) then
                deathcounter = deathcounter + 1
                -- If we reached the treshold for stopping the segment, do so.
                if deathcounter > 0 and deathcounter / startingmembers >= 0.5 and not self.current.stopped then
                    self:Print("Stopping for wipe.")
                    self:StopSegment()
                end
            end

            if self.current and eventtype == "SPELL_RESURRECT" and ((band(srcFlags, RAID_FLAGS) ~= 0 and band(srcFlags, PET_FLAGS) == 0) or players[srcGUID]) then
                deathcounter = deathcounter - 1
            end
        end

        if self.current and combatlogevents[eventtype] then
            if self.current.stopped then
                return
            end

            for _, mod in ipairs(combatlogevents[eventtype]) do
                local fail = false

                if mod.flags.src_is_interesting_nopets then
                    local src_is_interesting_nopets = (band(srcFlags, RAID_FLAGS) ~= 0 and band(srcFlags, PET_FLAGS) == 0) or players[srcGUID]

                    if src_is_interesting_nopets then
                        src_is_interesting = true
                    else
                        fail = true
                    end
                end

                if not fail and mod.flags.dst_is_interesting_nopets then
                    local dst_is_interesting_nopets = (band(dstFlags, RAID_FLAGS) ~= 0 and band(dstFlags, PET_FLAGS) == 0) or players[dstGUID]
                    if dst_is_interesting_nopets then
                        dst_is_interesting = true
                    else
                        fail = true
                    end
                end

                if not fail and mod.flags.src_is_interesting or mod.flags.src_is_not_interesting then
                    if not src_is_interesting then
                        src_is_interesting =
                            band(srcFlags, RAID_FLAGS) ~= 0 or (band(srcFlags, PET_FLAGS) ~= 0 and pets[srcGUID]) or
                            players[srcGUID]
                    end

                    if mod.flags.src_is_interesting and not src_is_interesting then
                        fail = true
                    end

                    if mod.flags.src_is_not_interesting and src_is_interesting then
                        fail = true
                    end
                end

                if not fail and mod.flags.dst_is_interesting or mod.flags.dst_is_not_interesting then
                    if not dst_is_interesting then
                        dst_is_interesting =
                            band(dstFlags, RAID_FLAGS) ~= 0 or (band(dstFlags, PET_FLAGS) ~= 0 and pets[dstGUID]) or
                            players[dstGUID]
                    end

                    if mod.flags.dst_is_interesting and not dst_is_interesting then
                        fail = true
                    end

                    if mod.flags.dst_is_not_interesting and dst_is_interesting then
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
                            self:StartCombat()
                        end
                    end
                end
            end
        end

        if self.current and src_is_interesting and not self.current.gotboss then
            if band(dstFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0 then
                self.current.mobname = dstName
                if not self.current.gotboss and self:IsBoss(dstGUID) then
                    self.current.gotboss = true
                end
            end
        end

        if eventtype == "SPELL_SUMMON" and (band(srcFlags, RAID_FLAGS) ~= 0 or band(srcFlags, PET_FLAGS) ~= 0 or ((band(dstFlags, PET_FLAGS) ~= 0 or band(srcFlags, SHAM_FLAGS) ~= 0) and pets[dstGUID])) then
            -- we assign the pet the normal way
            self:AssignPet(srcGUID, srcName, dstGUID)

            -- we fix the table by searching through the complete list
            local fixed = true
            while fixed do
                fixed = false
                for pet, owner in pairs(pets) do
                    if pets[owner.id] then
                        Skada:AssignPet(pets[owner.id].id, pets[owner.id].name, pet)
                        fixed = true
                    end
                end
            end
        end

        if self.current and self.current.gotboss and self.current.mobname == dstName and (eventtype == "UNIT_DIED" or eventtype == "UNIT_DESTROYED") then
            self.current.success = true
            if self.db.profile.smartstop and not dumbbosses[dstName] then
                self.callbacks:Fire("ENCOUNTER_END", self.current)
                self.After(1, function() self:StopSegment() end)
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