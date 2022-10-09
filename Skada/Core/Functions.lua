local folder, Skada = ...
local private = Skada.private

local select, pairs, type = select, pairs, type
local tonumber, format = tonumber, string.format
local setmetatable, wipe, band = setmetatable, wipe, bit.band
local next, print = next, print
local _

local L = LibStub("AceLocale-3.0"):GetLocale(folder)
local UnitClass, GetPlayerInfoByGUID = UnitClass, GetPlayerInfoByGUID
local GetClassFromGUID = Skada.GetClassFromGUID
local new, del = private.newTable, private.delTable
local clear, copy = private.clearTable, private.tCopy

local COMBATLOG_OBJECT_TYPE_NPC = COMBATLOG_OBJECT_TYPE_NPC or 0x00000800

-------------------------------------------------------------------------------
-- debug function

function Skada:Debug(...)
	if self.db.profile.debug then
		print("\124cff33ff99Skada Debug\124r:", ...)
	end
end

-------------------------------------------------------------------------------
-- boss and creature functions

do
	local creatureToFight = Skada.creatureToFight or Skada.dummyTable
	local creatureToBoss = Skada.creatureToBoss or Skada.dummyTable
	local GetCreatureId = Skada.GetCreatureId

	-- checks if the provided guid is a boss
	function Skada:IsBoss(guid, strict)
		local id = GetCreatureId(guid)
		if creatureToBoss[id] and creatureToBoss[id] ~= true then
			if strict then
				return false
			end
			return true, id
		elseif creatureToBoss[id] or creatureToFight[id] then
			return true, id
		end
		return false
	end

	function Skada:IsEncounter(guid, name)
		local isboss, id = self:IsBoss(guid)
		if isboss and id then
			if creatureToBoss[id] and creatureToBoss[id] ~= true then
				return true, creatureToBoss[id], creatureToFight[id] or name
			end

			if creatureToFight[id] then
				return true, true, creatureToFight[id] or name
			end

			return true, id, creatureToFight[id] or name
		end
		return false
	end
end

-------------------------------------------------------------------------------
-- class, role and spec functions

do
	local is_player = private.is_player
	local is_pet = private.is_pet
	local is_creature = private.is_creature

	function private.unit_class(guid, flag, set, db, name)
		set = set or Skada.current
		if set then
			-- an existing player?
			local actors = set.players
			if actors then
				for i = 1, #actors do
					local p = actors[i]
					if p and p.id == guid then
						return p.class, p.role, p.spec
					elseif p and name and p.name == name and p.class and Skada.validclass[p.class] then
						return p.class, p.role, p.spec
					end
				end
			end
			-- an existing enemy?
			actors = set.enemies
			if actors then
				for i = 1, #actors do
					local e = actors[i]
					if e and ((e.id == guid or e.name == guid)) and e.class then
						return e.class
					end
				end
			end
		end

		local class = "UNKNOWN"
		if is_player(guid, flag, name) then
			class = name and select(2, UnitClass(name))
			if not class and tonumber(guid) then
				class = GetClassFromGUID(guid, "group")
				class = class or select(2, GetPlayerInfoByGUID(guid))
			end
		elseif is_pet(guid, flag) then
			class = "PET"
		elseif Skada:IsBoss(guid, true) then
			class = "BOSS"
		elseif is_creature(guid, flag) then
			class = "MONSTER"
		end

		if class and db and db.class == nil then
			db.class = class
		end

		return class
	end
end

-------------------------------------------------------------------------------
-- test mode

do
	local random = math.random
	local IsGroupInCombat = Skada.IsGroupInCombat
	local InCombatLockdown = InCombatLockdown
	local setPrototype = Skada.setPrototype
	local playerPrototype = Skada.playerPrototype

	local fakeSet, updateTimer = {}, nil

	-- there was no discrimination with classes and specs
	-- the only reason this group composition was made is
	-- to have all 10 classes displayed on windows.
	local fake_players
	do
		local playersTable = nil
		function fake_players()
			if not playersTable then
				playersTable = {
					-- Tanks & Healers
					{"Deafknight", "DEATHKNIGHT", "TANK", 250}, -- Blood Death Knight
					{"Bubbleboy", "PRIEST", "HEALER", 256}, -- Discipline Priest
					{"Channingtotem", "SHAMAN", "HEALER", 264}, -- Restoration Shaman
					-- Damagers
					{"Shiftycent", "DRUID", "DAMAGER", 102}, -- Balance Druid
					{"Beargrills", "HUNTER", "DAMAGER", 254}, -- Marksmanship Hunter
					{"Foodanddps", "MAGE", "DAMAGER", 63}, -- Fire Mage
					{"Retryhard", "PALADIN", "DAMAGER", 70}, -- Retribution Paladin
					{"Stabass", "ROGUE", "DAMAGER", 260}, -- Combat Rogue
					{"Summonbot", "WARLOCK", "DAMAGER", 266}, -- Demonology Warlock
					{"Chuggernaut", "WARRIOR", "DAMAGER", 72} -- Fury Warrior
				}
			end

			return playersTable
		end
	end

	local function generate_fake_data()
		fakeSet.name = "Fake Fight"
		fakeSet.starttime = time() - 120
		fakeSet.damage = 0
		fakeSet.heal = 0
		fakeSet.absorb = 0
		fakeSet.type = "raid"
		fakeSet.players = clear(fakeSet.players) or new()

		local players = fake_players()
		for i = 1, #players do
			local name, class, role, spec = players[i][1], players[i][2], players[i][3], players[i][4]
			local damage, heal, absorb = 0, 0, 0

			if role == "TANK" then
				damage = random(1e5, 1e5 * 2)
				heal = random(10000, 20000)
				absorb = random(5000, 100000)
			elseif role == "HEALER" then
				damage = random(1000, 3000)
				if spec == 256 then -- Discipline Priest
					heal = random(1e5, 1e5 * 2)
					absorb = random(1e6, 1e6 * 2)
				else -- Other healers
					heal = random(1e6, 1e6 * 2)
					absorb = random(1000, 5000)
				end
			else
				damage = random(1e6, 1e6 * 2)
				heal = random(250, 1500)
			end

			local player = new()
			player.id = name
			player.name = name
			player.class = class
			player.role = role
			player.spec = spec
			player.damage = damage
			player.heal = heal
			player.absorb = absorb
			fakeSet.players[#fakeSet.players + 1] = player

			fakeSet.damage = fakeSet.damage + damage
			fakeSet.heal = fakeSet.heal + heal
			fakeSet.absorb = fakeSet.absorb + absorb
		end

		return setPrototype:Bind(fakeSet)
	end

	local function randomize_fake_data(set, coef)
		set.time = time() - set.starttime

		local players = set.players
		for i = 1, #players do
			local player = playerPrototype:Bind(players[i], set)
			if player then
				local damage, heal, absorb = 0, 0, 0

				if player.role == "HEALER" then
					damage = coef * random(0, 1500)
					if player.spec == 256 then
						heal = coef * random(500, 1500)
						absorb = coef * random(2500, 20000)
					else
						heal = coef * random(2500, 15000)
						absorb = coef * random(0, 150)
					end
				elseif player.role == "TANK" then
					damage = coef * random(1000, 10000)
					heal = coef * random(500, 1500)
					absorb = coef * random(1000, 1500)
				else
					damage = coef * random(8000, 18000)
					heal = coef * random(150, 1500)
				end

				player.damage = (player.damage or 0) + damage
				player.heal = (player.heal or 0) + heal
				player.absorb = (player.absorb or 0) + absorb

				set.damage = set.damage + damage
				set.heal = set.heal + heal
				set.absorb = set.absorb + absorb
			end
		end
	end

	local function update_fake_data(self)
		randomize_fake_data(self.current, self.db.profile.updatefrequency or 0.25)
		self:UpdateDisplay(true)
	end

	function Skada:TestMode()
		if InCombatLockdown() or IsGroupInCombat() then
			clear(fakeSet)
			self.testMode = nil
			if updateTimer then
				self:CancelTimer(updateTimer)
				updateTimer = nil
			end
			return
		end
		self.testMode = not self.testMode
		if not self.testMode then
			clear(fakeSet)
			if updateTimer then
				self:CancelTimer(updateTimer)
				updateTimer = nil
			end
			self.current = del(self.current, true)
			return
		end

		self:Wipe()
		self.current = generate_fake_data()
		updateTimer = self:ScheduleRepeatingTimer(update_fake_data, self.db.profile.updatefrequency or 0.25, self)
	end
end

-------------------------------------------------------------------------------
-- temporary flags check bypass

do
	local temp_units = nil

	-- adds a temporary unit with optional info
	function private.add_temp_unit(guid, info)
		if not guid then return end
		temp_units = temp_units or new()
		temp_units[guid] = info or true
	end

	-- deletes a temporary unit if found
	function private.del_temp_unit(guid)
		if guid and temp_units and temp_units[guid] then
			temp_units[guid] = del(temp_units[guid])
		end
	end

	-- returns the temporary unit stored "info" or false
	function private.get_temp_unit(guid)
		return guid and temp_units and temp_units[guid]
	end

	-- clears all store temporary units
	function private.clear_temp_units()
		temp_units = clear(temp_units)
	end
end

-------------------------------------------------------------------------------
-- frame borders

function Skada:ApplyBorder(frame, texture, color, thickness, padtop, padbottom, padleft, padright)
	if not frame.borderFrame then
		frame.borderFrame = CreateFrame("Frame", "$parentBorder", frame)
		frame.borderFrame:SetFrameLevel(frame:GetFrameLevel() - 1)
	end

	thickness = thickness or 0
	padtop = padtop or 0
	padbottom = padbottom or padtop
	padleft = padleft or padtop
	padright = padright or padtop

	frame.borderFrame:SetPoint("TOPLEFT", frame, -thickness - padleft, thickness + padtop)
	frame.borderFrame:SetPoint("BOTTOMRIGHT", frame, thickness + padright, -thickness - padbottom)

	local borderbackdrop = new()
	borderbackdrop.edgeFile = (texture and thickness > 0) and self:MediaFetch("border", texture) or nil
	borderbackdrop.edgeSize = thickness
	frame.borderFrame:SetBackdrop(borderbackdrop)
	del(borderbackdrop)
	if color then
		frame.borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
	end
end

-------------------------------------------------------------------------------
-- addon communication

do
	local UnitIsConnected = UnitIsConnected
	local IsInGroup, IsInRaid = Skada.IsInGroup, Skada.IsInRaid
	local collectgarbage = collectgarbage

	local function create_progress_window()
		local frame = CreateFrame("Frame", "SkadaProgressWindow", UIParent)
		frame:SetFrameStrata("TOOLTIP")

		local elem = frame:CreateTexture(nil, "BORDER")
		elem:SetTexture([[Interface\Buttons\WHITE8X8]])
		elem:SetVertexColor(0, 0, 0, 1)
		elem:SetPoint("TOPLEFT")
		elem:SetPoint("RIGHT")
		elem:SetHeight(25)
		frame.head = elem

		elem = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		elem:SetJustifyH("CENTER")
		elem:SetJustifyV("MIDDLE")
		elem:SetPoint("TOPLEFT", frame.head, "TOPLEFT", 25, 0)
		elem:SetPoint("BOTTOMRIGHT", frame.head, "BOTTOMRIGHT", -25, 0)
		elem:SetText(L["Progress"])
		frame.title = elem

		elem = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		elem:SetWidth(24)
		elem:SetHeight(24)
		elem:SetPoint("RIGHT", frame.head, "RIGHT", -4, 0)
		frame.close = elem

		elem = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		elem:SetJustifyH("CENTER")
		elem:SetJustifyV("MIDDLE")
		elem:SetPoint("TOPLEFT", frame.head, "BOTTOMLEFT", 0, -10)
		elem:SetPoint("TOPRIGHT", frame.head, "BOTTOMRIGHT", 0, -10)
		frame.text = elem

		elem = CreateFrame("StatusBar", nil, frame)
		elem:SetMinMaxValues(0, 100)
		elem:SetPoint("TOPLEFT", frame.text, "BOTTOMLEFT", 20, -15)
		elem:SetPoint("TOPRIGHT", frame.text, "BOTTOMRIGHT", -20, -15)
		elem:SetHeight(5)
		elem:SetStatusBarTexture([[Interface\AddOns\Skada\Media\Statusbar\Flat.tga]])
		elem:SetStatusBarColor(0, 1, 0)
		frame.bar = elem

		elem = frame.bar:CreateTexture(nil, "BACKGROUND")
		elem:SetTexture([[Interface\Buttons\WHITE8X8]])
		elem:SetVertexColor(1, 1, 1, 0.2)
		elem:SetAllPoints(true)

		elem = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		elem:SetPoint("TOP", frame.bar, "BOTTOM", 0, -15)
		frame.size = elem

		frame:SetBackdrop {
			bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
			edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
			edgeSize = 16,
			insets = {left = 4, right = 4, top = 4, bottom = 4}
		}
		frame:SetBackdropColor(0, 0, 0, 0.6)
		frame:SetBackdropBorderColor(0, 0, 0, 1)
		frame:SetPoint("CENTER", 0, 0)
		frame:SetWidth(360)
		frame:SetHeight(110)

		frame:SetScript("OnShow", function(self)
			self.size:SetText(format(L["Data Size: \124cffffffff%.1f\124rKB"], self.total * 0.001))
		end)

		frame:SetScript("OnHide", function(self)
			self.total = 0
			self.text:SetText(self.fmt)
			self.size:SetText("")
			self.bar:SetValue(0)
			collectgarbage()
		end)

		frame.fmt = L["Transmision Progress: %02.f%%"]
		frame:Hide()
		return frame
	end

	local function show_progress_window(self, sent, total)
		local progress = self.ProgressWindow or create_progress_window()
		self.ProgressWindow = progress
		if not progress:IsShown() then
			progress.total = total
			progress:Show()
		end

		if sent < total then
			local p = sent * (100 / total)
			progress.text:SetText(format(progress.fmt, p))
			progress.bar:SetValue(p)
		else
			progress.text:SetText(L["Transmission Completed"])
			progress.bar:SetValue(100)
		end
	end

	-- "PURR" is a special key to whisper with progress window.
	local function send_comm_message(self, channel, target, ...)
		if target == self.userName then
			return -- to yourself? really...
		elseif channel ~= "WHISPER" and channel ~= "PURR" and not IsInGroup() then
			return -- only for group members!
		elseif (channel == "WHISPER" or channel == "PURR") and not (target and UnitIsConnected(target)) then
			return -- whisper target must be connected!
		end

		-- not channel provided?
		if not channel then
			channel = IsInRaid() and "RAID" or "PARTY" -- default

			-- arena or battlegrounds?
			if self.insType == "pvp" or self.insType == "arena" then
				channel = "BATTLEGROUND"
			end
		end

		if channel == "PURR" then
			self:SendCommMessage(folder, private.serialize(nil, nil, ...), "WHISPER", target, "NORMAL", show_progress_window, self)
		elseif channel then
			self:SendCommMessage(folder, private.serialize(nil, nil, ...), channel, target)
		end
	end

	local function dispatch_comm(sender, ok, const, ...)
		if ok and Skada.comms and type(const) == "string" and Skada.comms[const] then
			for self, funcs in pairs(Skada.comms[const]) do
				for func in pairs(funcs) do
					if type(self[func]) == "function" then
						self[func](self, sender, ...)
					elseif type(func) == "function" then
						func(sender, ...)
					end
				end
			end
		end
	end

	local function on_comm_received(self, prefix, message, channel, sender)
		if prefix == folder and channel and sender and sender ~= self.userName then
			dispatch_comm(sender, private.deserialize(message))
		end
	end

	function Skada:RegisterComms(enable)
		if enable then
			self.SendComm = send_comm_message
			self.OnCommReceived = on_comm_received
			self:RegisterComm(folder)
			self:AddComm("VersionCheck")
		else
			self.SendComm = self.EmptyFunc
			self.OnCommReceived = self.EmptyFunc
			self:UnregisterAllComm()
			self:RemoveAllComms()
		end

		self.callbacks:Fire("Skada_UpdateComms", enable)
	end

	function Skada.AddComm(self, const, func)
		if self and const then
			Skada.comms = Skada.comms or {}
			Skada.comms[const] = Skada.comms[const] or {}
			Skada.comms[const][self] = Skada.comms[const][self] or {}
			Skada.comms[const][self][func or const] = true
		end
	end

	function Skada.RemoveComm(self, func)
		if self and Skada.comms then
			for const, selfs in pairs(Skada.comms) do
				if selfs[self] then
					selfs[self][func] = nil

					-- remove the table if empty
					if next(selfs[self]) == nil then
						selfs[self] = nil
					end

					break
				end
			end
		end
	end

	function Skada.RemoveAllComms(self)
		if self and Skada.comms then
			for const, selfs in pairs(Skada.comms) do
				for _self in pairs(selfs) do
					if self == _self then
						selfs[self] = nil
						break
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- instance difficulty

do
	local GetRaidDifficulty = GetRaidDifficulty
	local GetDungeonDifficulty = GetDungeonDifficulty

	function Skada:GetInstanceDiff()
		local _, insType, diff, _, count, dynDiff, isDynamic = GetInstanceInfo()
		if insType == "none" then
			return diff == 1 and "wb" or "NaN" -- World Boss
		elseif insType == "raid" and isDynamic then
			if diff == 1 or diff == 3 then
				return (dynDiff == 0) and "10n" or (dynDiff == 1) and "10h" or "NaN"
			elseif diff == 2 or diff == 4 then
				return (dynDiff == 0) and "25n" or (dynDiff == 1) and "25h" or "NaN"
			end
		elseif insType then
			if diff == 1 then
				local comp_diff = GetRaidDifficulty()
				if diff ~= comp_diff and (comp_diff == 2 or comp_diff == 4) then
					return "tw" -- timewalker
				else
					return count and format("%dn", count) or "10n"
				end
			else
				return diff == 2 and "25n" or diff == 3 and "10h" or diff == 4 and "25h" or "NaN"
			end
		elseif insType == "party" then
			if diff == 1 then
				return "5n"
			elseif diff == 2 then
				local comp_diff = GetDungeonDifficulty()
				return comp_diff == 3 and "mc" or "5h" -- mythic or heroic 5man
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Active / Effetive time functions

-- returns the selected set time.
function Skada:GetSetTime(set, active)
	if not set or not set.time then
		return 0
	end

	local settime = active and set.activetime or set.time
	return (settime >= 1) and settime or max(1, time() - set.starttime)
end

-- returns the actor's active/effective time
function Skada:GetActiveTime(set, actor, active)
	active = active or (set.type == "pvp") or (set.type == "arena") -- force active for pvp/arena

	-- use settime to clamp
	local settime = self:GetSetTime(set, active)

	-- active: actor's time.
	if (self.db.profile.timemesure ~= 2 or active) and actor.time and actor.time > 0 then
		return max(1, min(actor.time, settime))
	end

	-- effective: combat time.
	return settime
end

-- updates the actor's active time
function Skada:AddActiveTime(set, actor, target, override)
	if not actor or not actor.last then return end

	local curtime = set.last_time or GetTime()
	local delta = curtime - actor.last
	actor.last = curtime

	if override and override > 0 and override <= delta then
		delta = override
	elseif delta > 3.5 then
		delta = 3.5
	end

	local adding = floor(100 * delta + 0.5) * 0.01
	actor.time = (actor.time or 0) + adding
	set.activetime = (set.activetime or 0) + adding

	-- to save up memory, we only record the rest to the current set.
	if (set == self.total and not self.db.profile.totalidc) or not target then return end

	actor.timespent = actor.timespent or {}
	actor.timespent[target] = (actor.timespent[target] or 0) + adding
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

		private.confirm_dialog(L["Do you want to reset Skada?\nHold SHIFT to reset all data."], f, t)
	end
end

-- new window creation dialog
local dialog_name = nil
function Skada:NewWindow(window)
	dialog_name = dialog_name or format("%sCreateWindowDialog", folder)
	if not StaticPopupDialogs[dialog_name] then
		local function create_window(name, win)
			name = name and name:trim()
			if not name or name == "" then return end

			local db = win and win.db
			if db and IsShiftKeyDown() then
				local w = Skada:CreateWindow(name, nil, db.display)
				copy(w.db, db, "name", "sticked", "point", "snapped", "child", "childmode")
				w.db.x, w.db.y = 0, 0
				Skada:ApplySettings(name)
			else
				Skada:CreateWindow(name)
			end
		end

		StaticPopupDialogs[dialog_name] = {
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
	StaticPopup_Show(dialog_name, nil, nil, window)
end

-- reinstall the addon
do
	local ReloadUI = ReloadUI
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
		private.confirm_dialog(L["Are you sure you want to reinstall Skada?"], f, t)
	end
end

-------------------------------------------------------------------------------
-- bossmods callbacks

local find, lower = string.find, string.lower

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

-------------------------------------------------------------------------------
-- memory check

function Skada:CheckMemory()
	if not self.db.profile.memorycheck then return end
	UpdateAddOnMemoryUsage()
	local memory = GetAddOnMemoryUsage(folder)
	if memory > (self.maxmeme * 1024) then
		self:Notify(L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."], L["Memory Check"], nil, "emergency")
	end
end

-------------------------------------------------------------------------------

do
	local function clear_indexes(set, mt)
		if set then
			set._playeridx = del(set._playeridx)
			set._enemyidx = del(set._enemyidx)

			-- should clear metatables?
			if not mt then return end

			local actors = set.players -- players
			if actors then
				for i = 1, #actors do
					local actor = actors[i]
					if actor and actor.super then
						actor.super = nil
						setmetatable(actor, nil)
					end
				end
			end

			actors = set.enemies -- enemies
			if actors then
				for i = 1, #actors do
					local actor = actors[i]
					if actor and actor.super then
						actor.super = nil
						setmetatable(actor, nil)
					end
				end
			end
		end
	end

	function Skada:ClearAllIndexes(mt)
		clear_indexes(Skada.current, mt)
		clear_indexes(Skada.total, mt)

		local sets = Skada.char.sets
		if sets then
			for i = 1, #sets do
				clear_indexes(sets[i], mt)
			end
		end

		if Skada.tempsets then
			for i = 1, #Skada.tempsets do
				clear_indexes(Skada.tempsets[i], mt)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- profile import, export and sharing

do
	local ipairs, strmatch, uformat = ipairs, strmatch, private.uformat
	local UnitName, GetRealmName = UnitName, GetRealmName
	local open_window = private.open_import_export
	local serialize_profile = nil

	local function get_profile_name(str)
		str = strmatch(strsub(str, 1, 64), "%[(.-)%]")
		str = str and str:gsub("=", ""):gsub("profile", ""):trim()
		return (str ~= "") and str
	end

	local function check_profile_name(name)
		local profiles = Skada.db:GetProfiles()
		local ProfileExists = function(name)
			if name then
				for _, v in ipairs(profiles) do
					if name == v then
						return true
					end
				end
			end
		end

		name = name or format("%s - %s", UnitName("player"), GetRealmName())

		local n, i = name, 1
		while ProfileExists(name) do
			i = i + 1
			name = format("%s (%d)", n, i)
		end

		return name
	end

	local temp = {}
	function serialize_profile()
		wipe(temp)
		copy(temp, Skada.db.profile, "modeclicks")
		temp.__name = Skada.db:GetCurrentProfile()
		return private.serialize(true, format("%s profile", temp.__name), temp)
	end

	local function import_profile(data, name)
		if type(data) ~= "string" then
			Skada:Print("Import profile failed, data supplied must be a string.")
			return false
		end

		local success, profile = private.deserialize(data, true)
		if not success or profile.numbersystem == nil then -- sanity check!
			Skada:Print("Import profile failed!")
			return false
		end

		name = name or get_profile_name(data)
		if profile.__name then
			name = name or profile.__name
			profile.__name = nil
		end
		local profileName = check_profile_name(name)

		-- backwards compatibility
		if profile[folder] and type(profile[folder]) == "table" then
			profile = profile[folder]
		end

		local old_reload_settings = private.reload_settings
		private.reload_settings = function()
			private.reload_settings = old_reload_settings
			copy(Skada.db.profile, profile)
			private.reload_settings()
			LibStub("AceConfigRegistry-3.0"):NotifyChange(folder)
		end

		Skada.db:SetProfile(profileName)
		private.reload_settings()
		Skada:Wipe()
		Skada:UpdateDisplay(true)
		return true
	end

	function Skada:ProfileImport()
		return open_window(L["Paste here a profile in text format."], import_profile)
	end

	function Skada:ProfileExport()
		return open_window(L["This is your current profile in text format."], serialize_profile())
	end

	function private.advanced_profile(args)
		if not args then return end
		private.advanced_profile = nil -- remove it
		local CONST_COMM_PROFILE = "PR"

		local Share = {}

		function Share:Enable(receive)
			if receive then
				self.enabled = true
				Skada.AddComm(self, CONST_COMM_PROFILE, "Receive")
			else
				self.enabled = nil
				Skada.RemoveAllComms(self)
			end
		end

		function Share:Receive(sender, profileStr)
			local acceptfunc = function()
				import_profile(profileStr, sender)
				collectgarbage()
				Share:Enable(false) -- disable receiving
				Share.target = nil -- reset target
			end
			private.confirm_dialog(uformat(L["opt_profile_received"], sender), acceptfunc)
		end

		function Share:Send(profileStr, target)
			Skada:SendComm("PURR", target, CONST_COMM_PROFILE, profileStr)
		end

		args.advanced = {
			type = "group",
			name = L["Advanced"],
			order = 10,
			args = {
				sharing = {
					type = "group",
					name = L["Network Sharing"],
					inline = true,
					order = 10,
					hidden = function() return Skada.db.profile.syncoff end,
					args = {
						name = {
							type = "input",
							name = L["Player Name"],
							get = function()
								return Share.target or ""
							end,
							set = function(_, value)
								Share.target = value:trim()
							end,
							order = 10
						},
						send = {
							type = "execute",
							name = L["Send Profile"],
							func = function()
								if Share.target and Share.target ~= "" then
									Share:Send(serialize_profile(), Share.target)
								end
							end,
							disabled = function() return (not Share.target or Share.target == "") end,
							order = 20
						},
						accept = {
							type = "toggle",
							name = L["Accept profiles from other players."],
							get = function() return Share.enabled end,
							set = function() Share:Enable(not Share.enabled) end,
							width = "full",
							order = 30
						}
					}
				},
				importexport = {
					type = "group",
					name = L["Profile Import/Export"],
					inline = true,
					order = 20,
					args = {
						importbtn = {
							type = "execute",
							name = L["Import Profile"],
							order = 10,
							func = Skada.ProfileImport
						},
						exportbtn = {
							type = "execute",
							name = L["Export Profile"],
							order = 20,
							func = Skada.ProfileExport
						}
					}
				}
			}
		}
	end
end
