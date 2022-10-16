local folder, Skada = ...
local Private = Skada.Private

local select, pairs, type = select, pairs, type
local tonumber, format = tonumber, string.format
local setmetatable, wipe, band = setmetatable, wipe, bit.band
local next, print = next, print
local _

local L = LibStub("AceLocale-3.0"):GetLocale(folder)
local UnitClass, GetPlayerInfoByGUID = UnitClass, GetPlayerInfoByGUID
local GetClassFromGUID = Skada.GetClassFromGUID
local new, del = Private.newTable, Private.delTable
local clear, copy = Private.clearTable, Private.tCopy

local COMBATLOG_OBJECT_TYPE_NPC = COMBATLOG_OBJECT_TYPE_NPC or 0x00000800

-------------------------------------------------------------------------------
-- debug function

function Skada:Debug(...)
	if self.db.profile.debug then
		print("\124cff33ff99Skada Debug\124r:", ...)
	end
end

-------------------------------------------------------------------------------
-- format functions

do
	local reverse = string.reverse
	local numbersystem = nil
	function Private.set_numeral_format(system)
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
			if not num then return end
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

local Translit = LibStub("LibTranslit-1.0", true)
function Skada:FormatName(name)
	if self.db.profile.realmless then
		name = gsub(name, ("%-.*"), "")
	end
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

	function Private.set_value_format(bracket, separator)
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
	local is_player = Private.is_player
	local is_pet = Private.is_pet
	local is_creature = Private.is_creature

	function Private.unit_class(guid, flag, set, db, name)
		set = set or Skada.current

		-- an existing actor?
		local actors = set and set.actors
		if actors then
			for i = 1, #actors do
				local actor = actors[i]
				if actor and actor.id == guid then
					return actor.class, actor.role, actor.spec
				elseif actor and actor.name == name and actor.class and Skada.validclass[actor.class] then
					return actor.class, actor.role, actor.spec
				end
			end
		end

		local class = "UNKNOWN"
		if is_player(guid, name, flag) then
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
	local fake_actors
	do
		local actorsTable = nil
		function fake_actors()
			if not actorsTable then
				actorsTable = {
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

			return actorsTable
		end
	end

	local function generate_fake_data()
		fakeSet.name = "Fake Fight"
		fakeSet.starttime = time() - 120
		fakeSet.damage = 0
		fakeSet.heal = 0
		fakeSet.absorb = 0
		fakeSet.type = "raid"
		fakeSet.actors = clear(fakeSet.actors) or new()

		local actors = fake_actors()
		for i = 1, #actors do
			local name, class, role, spec = actors[i][1], actors[i][2], actors[i][3], actors[i][4]
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

			local actor = new()
			actor.id = name
			actor.name = name
			actor.class = class
			actor.role = role
			actor.spec = spec
			actor.damage = damage
			actor.heal = heal
			actor.absorb = absorb
			fakeSet.actors[#fakeSet.actors + 1] = actor

			fakeSet.damage = fakeSet.damage + damage
			fakeSet.heal = fakeSet.heal + heal
			fakeSet.absorb = fakeSet.absorb + absorb
		end

		return setPrototype:Bind(fakeSet)
	end

	local function randomize_fake_data(set, coef)
		set.time = time() - set.starttime

		local actors = set.actors
		for i = 1, #actors do
			local actor = playerPrototype:Bind(actors[i], set)
			if actor then
				local damage, heal, absorb = 0, 0, 0

				if actor.role == "HEALER" then
					damage = coef * random(0, 1500)
					if actor.spec == 256 then
						heal = coef * random(500, 1500)
						absorb = coef * random(2500, 20000)
					else
						heal = coef * random(2500, 15000)
						absorb = coef * random(0, 150)
					end
				elseif actor.role == "TANK" then
					damage = coef * random(1000, 10000)
					heal = coef * random(500, 1500)
					absorb = coef * random(1000, 1500)
				else
					damage = coef * random(8000, 18000)
					heal = coef * random(150, 1500)
				end

				actor.damage = (actor.damage or 0) + damage
				actor.heal = (actor.heal or 0) + heal
				actor.absorb = (actor.absorb or 0) + absorb

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
	function Private.add_temp_unit(guid, info)
		if not guid then return end
		temp_units = temp_units or new()
		temp_units[guid] = info or true
	end

	-- deletes a temporary unit if found
	function Private.del_temp_unit(guid)
		if guid and temp_units and temp_units[guid] then
			temp_units[guid] = del(temp_units[guid])
		end
	end

	-- returns the temporary unit stored "info" or false
	function Private.get_temp_unit(guid)
		return guid and temp_units and temp_units[guid]
	end

	-- clears all store temporary units
	function Private.clear_temp_units()
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
			self:SendCommMessage(folder, Private.serialize(nil, nil, ...), "WHISPER", target, "NORMAL", show_progress_window, self)
		elseif channel then
			self:SendCommMessage(folder, Private.serialize(nil, nil, ...), channel, target)
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
			dispatch_comm(sender, Private.deserialize(message))
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

		Private.confirm_dialog(L["Do you want to reset Skada?\nHold SHIFT to reset all data."], f, t)
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
		Private.confirm_dialog(L["Are you sure you want to reinstall Skada?"], f, t)
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
-- misc functions

-- memory usage check
function Skada:CheckMemory()
	if not self.db.profile.memorycheck then return end
	UpdateAddOnMemoryUsage()
	local memory = GetAddOnMemoryUsage(folder)
	if memory > (self.maxmeme * 1024) then
		self:Notify(L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."], L["Memory Check"], nil, "emergency")
	end
end

do
	local function clear_indexes(set)
		if not set then return end
		set._actoridx = del(set._actoridx)
	end

	-- clearing indexes
	function Skada:ClearAllIndexes()
		clear_indexes(Skada.current)
		clear_indexes(Skada.total)

		local sets = Skada.char.sets
		if sets then
			for i = 1, #sets do
				clear_indexes(sets[i])
			end
		end

		sets = Skada.tempsets
		if sets then
			for i = 1, #sets do
				clear_indexes(sets[i])
			end
		end
	end
end

-- filters by class
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
-- profile import, export and sharing

do
	local ipairs, strmatch, uformat = ipairs, strmatch, Private.uformat
	local UnitName, GetRealmName = UnitName, GetRealmName
	local open_window = Private.open_import_export
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
		return Private.serialize(true, format("%s profile", temp.__name), temp)
	end

	local function import_profile(data, name)
		if type(data) ~= "string" then
			Skada:Print("Import profile failed, data supplied must be a string.")
			return false
		end

		local success, profile = Private.deserialize(data, true)
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

		local old_reload_settings = Private.reload_settings
		Private.reload_settings = function()
			Private.reload_settings = old_reload_settings
			copy(Skada.db.profile, profile)
			Private.reload_settings()
			LibStub("AceConfigRegistry-3.0"):NotifyChange(folder)
		end

		Skada.db:SetProfile(profileName)
		Private.reload_settings()
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

	function Private.advanced_profile(args)
		if not args then return end
		Private.advanced_profile = nil -- remove it
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
			Private.confirm_dialog(uformat(L["opt_profile_received"], sender), acceptfunc)
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
