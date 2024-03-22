local folder, Skada = ...
local Private = Skada.Private

local select, pairs, type = select, pairs, type
local tonumber, format, gsub = tonumber, string.format, string.gsub
local setmetatable, wipe = setmetatable, wipe
local next, time, GetTime = next, time, GetTime
local _

local UnitGUID, UnitClass, UnitFullName = UnitGUID, UnitClass, Private.UnitFullName
local IsInGroup, IsInRaid = Skada.IsInGroup, Skada.IsInRaid
local tablePool, TempTable = Skada.tablePool, Private.TempTable
local new, del = Private.newTable, Private.delTable
local L, callbacks = Skada.Locale, Skada.callbacks
local guidToName, guidToClass, guidToOwner = Private.guidToName, Private.guidToClass, Private.guidToOwner

-------------------------------------------------------------------------------
-- debug function

do
	local Print = Private.Print
	local debug_str = format("\124cff33ff99%s Debug\124r:", folder)
	function Skada:Debug(...)
		if not self.profile.debug then return end
		Print(debug_str, ...)
	end
end

-------------------------------------------------------------------------------
-- modules and display functions

do
	local tconcat = table.concat
	local function module_table(...)
		local args = TempTable(...)
		if #args >= 2 then
			-- name must always be first
			local name = args:remove(1)
			if type(name) ~= "string" then
				args:free()
				return
			end

			-- second arg can be the desc or the callback
			local func = nil
			local desc = args:remove(1)
			if type(desc) == "string" then
				func = args:remove(1)
				desc = L[desc]
			elseif type(desc) == "function" then
				func = desc
				desc = nil
			end

			-- double check just in case
			if type(func) ~= "function" then
				args:free()
				return
			end

			local module = new()
			module.name = name
			module.func = func

			-- treat args left as dependencies
			local args_rem = #args
			if args_rem > 0 then
				module.deps = {}
				local localized_deps = new()
				for i = 1, #args do
					module.deps[i] = args[i]
					localized_deps[i] = L[args[i]] -- localize
				end

				-- format module's description
				if desc then
					desc = format("%s\n%s", desc, format(L["\124cff00ff00Requires\124r: %s"], tconcat(localized_deps, ", ")))
				else
					desc = format(L["\124cff00ff00Requires\124r: %s"], tconcat(localized_deps, ", "))
				end
				del(localized_deps)
			end
			module.desc = desc
			args:free()

			return module
		end

		args:free()
	end

	-- adds a module to the loadable modules table.
	local unpack = unpack
	function Skada:RegisterModule(...)
		local module = module_table(...)
		if not module then return end

		-- add to loadable modules table
		self.LoadableModules = self.LoadableModules or new()
		self.LoadableModules[#self.LoadableModules + 1] = module

		-- add its check button
		self.options.args.modules.args.blocked.args[module.name] = {
			type = "toggle",
			name = function()
				if module.deps and self:IsDisabled(unpack(module.deps)) then
					return format("\124cffff0000%s\124r", L[module.name])
				end
				return L[module.name]
			end,
			desc = module.desc
		}

		-- return it so that RegisterDisplay changes order
		return self.options.args.modules.args.blocked.args[module.name]
	end

	-- when modules are created w make sure to save
	-- their english "name" then localize "moduleName"
	function Skada:OnModuleCreated(module)
		module.localeName = L[module.moduleName]
		module.OnModuleCreated = module.OnModuleCreated or self.OnModuleCreated
		module.isParent = (self == Skada)
	end

	do
		local cbxorder = 910

		-- registers a loadable display system
		function Skada:RegisterDisplay(...)
			local args = self:RegisterModule(...)
			if not args then return end
			args.order = cbxorder
			cbxorder = cbxorder + 10
		end

		local displays = Skada.displays
		local display_with_totals = Skada.display_with_totals
		local numorder = 80

		-- adds a display system
		function Skada:AddDisplaySystem(key, mod, has_totals)
			displays[key] = mod
			if mod.description then
				self.options.args.windows.args[format("%sdesc", key)] = {
					type = "description",
					name = format("\n\124cffffd700%s\124r:\n%s", mod.localeName, mod.description),
					fontSize = "small",
					order = numorder
				}
				numorder = numorder + 10
			end
			display_with_totals[key] = (has_totals == true)
		end
	end

	-- checks whether the select module(s) are disabled
	function Skada:IsDisabled(...)
		for i = 1, select("#", ...) do
			if self.profile.modulesBlocked[select(i, ...)] == true then
				return true
			end
		end
		return false
	end

	-- loads registered modules
	function Skada:LoadModules(release)
		-- loadable modules
		if self.LoadableModules then
			local mod = tremove(self.LoadableModules, 1)
			while mod do
				if mod.name and mod.func and not self:IsDisabled(mod.name) and not (mod.deps and self:IsDisabled(unpack(mod.deps))) then
					mod.func(L, self.profile, self.global, self.cacheTable, self.profile.modules, self.options.args)
				end
				mod = tremove(self.LoadableModules, 1)
			end
		end

		if not release then return end
		self.LoadableModules = del(self.LoadableModules)
	end
end

-------------------------------------------------------------------------------
-- format functions

do
	local reverse = string.reverse
	local numbersystem = nil
	function Private.SetNumberFormat(system)
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
					return format("%.1f%s", num * 0.001, symbol_1k)
				end
				return format("%.0f", num)
			end
		end

		Skada.FormatNumber = function(self, num, fmt)
			if not num then return end
			fmt = fmt or self.profile.numberformat or 1

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
	dec = dec or self.profile.decimals or 1

	-- no value? 0%
	if not value then
		return format(format("%%.%df%%%%", dec), 0)
	end

	-- correct values.
	value, total = total and (100 * value) or value, max(1, total or 0)

	-- below 0? clamp to -999
	if value <= 0 then
		return format(format("%%.%df%%%%", dec), max(-999, value / total))
	-- otherwise, clamp to 999
	else
		return format(format("%%.%df%%%%", dec), min(999, value / total))
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
		local s = floor(sec - h * 3600 - m * 60)
		return format("%02.f:%02.f:%02.f", h, m, s)
	else
		return format("%02.f:%02.f", floor(sec / 60), floor((sec % 60) + 0.5))
	end
end

local Translit = LibStub("LibTranslit-1.0", true)
function Skada:FormatName(name)
	name = self.profile.realmless and gsub(name, ("%-.*"), "") or name
	return self.profile.translit and Translit and Translit:Transliterate(name, "!") or name
end

do
	-- brackets and separators
	local brackets = {"(%s)", "{%s}", "[%s]", "<%s>", "%s"}
	local separators = {"%s, %s", "%s. %s", "%s; %s", "%s - %s", "%s \124\124 %s", "%s / %s", "%s \\ %s", "%s ~ %s", "%s %s"}

	-- formats default values
	local format_2 = "%s (%s)"
	local format_3 = "%s (%s, %s)"

	function Private.SetValueFormat(bracket, separator)
		format_2 = brackets[bracket or 1]
		format_3 = format("%%s %s", format(format_2, separators[separator or 1]))
		format_2 = format("%%s %s", format_2)
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
-- report function

do
	local tsort = table.sort
	local SendChatMessage, BNSendWhisper = SendChatMessage, BNSendWhisper
	local Window, windows = Skada.Window, Skada.windows
	local EscapeStr = Private.EscapeStr

	function Skada:SendChat(msg, chan, chantype, noescape)
		if strlower(chan) == "self" or strlower(chantype) == "self" then
			Skada:Print(msg)
			return
		end
		if strlower(chan) == "auto" then
			if not IsInGroup() then return end
			chan = (Skada.insType == "pvp" or Skada.insType == "arena") and "battleground" or IsInRaid() and "raid" or "party"
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

	local strrep = strrep or string.rep
	local tinsert = table.insert
	local SpellLink = Private.SpellLink

	local function BuildReportTable(mode, firstline, dataset, maxlines, fmt, barid)
		local temp = TempTable(EscapeStr(firstline))

		local num = #dataset
		local nr, max_length = 0, 0
		for i = 1, num do
			if nr >= maxlines then break end

			local data = dataset[i]
			if data and not data.ignore and ((barid and barid == data.id) or (data.id and not barid)) then
				nr = nr + 1
				local label = nil
				if Skada.profile.reportlinks and (data.spellid or data.hyperlink) then
					if data.reportlabel and data.spellid then
						label = data.reportlabel:gsub(data.label, SpellLink(data.spellid))
					else
						label = data.hyperlink or SpellLink(data.spellid) or data.reportlabel or data.label
					end
					label = TempTable(EscapeStr(label), "   ")
				else
					label = TempTable(EscapeStr(data.reportlabel or data.label), "   ")
				end

				if label then
					label[#label + 1] = EscapeStr(data.reportvalue or data.valuetext)
					if mode.metadata and mode.metadata.showspots then
						if fmt and maxlines >= 10 and num >= 10 and not barid then
							label[1] = format(nr >= 10 and "%s. %s" or " %s. %s", nr, label[1])
						else
							label[1] = format("%s. %s", nr, label[1])
						end
					end
				end

				label.n = #label[1]
				if label[3] then
					label.n = label.n + #label[3]
				end

				if label.n > max_length then
					max_length = label.n
				end

				temp[#temp + 1] = label

				if barid then break end
			end
		end

		for i = #temp, 2, -1 do
			local label = tremove(temp, i)
			if label[2] and fmt then
				label[2] = strrep(" ", max_length - label.n + 3)
			end
			tinsert(temp, i, label:concat(""))
			label = label:free()
		end

		return temp
	end

	local function value_id_sort(a, b)
		if not a or a.value == nil or a.id == nil then
			return false
		elseif not b or b.value == nil or b.id == nil then
			return true
		else
			return a.value > b.value
		end
	end

	local strupper, strlower = string.upper, string.lower
	local function camel_case(first, rest)
		return format("%s%s", strupper(first), strlower(rest))
	end

	local GetChannelList = GetChannelList
	local OpenExport = Private.ImportExport

	function Skada:Report(channel, chantype, modename, setname, maxlines, window, barid)
		if maxlines == 0 then return end

		if chantype == "channel" then
			local list = TempTable(GetChannelList())
			for i = 1, #list * 0.5 do
				if (self.profile.report.channel == list[i * 2]) then
					channel = list[i * 2 - 1]
					break
				end
			end
			list:free()
		end

		chantype = chantype or "preset"
		local set, mode = nil, nil

		if window == nil then
			set = self:GetSet(setname or "current")
			if set == nil then
				self:Print(L["No mode or segment selected for report."])
				return
			end

			modename = modename and gsub(gsub(modename, "_", " "), "(%a)([%w_']*)", camel_case) or "Damage"
			mode = self.modules[modename] or self.modules[strupper(modename)] or self.modules[strlower(modename)]
			if not mode then return end
			window = Window.new(true)
			mode:Update(window, set)
		elseif type(window) == "string" then
			for i = 1, #windows do
				local win = windows[i]
				local db = win and win.db
				if db and strlower(db.name) == strlower(window) then
					window = win
					set = win:GetSelectedSet()
					mode = win.selectedmode
					break
				end
			end
		else
			set = window:GetSelectedSet()
			mode = window.selectedmode
		end

		if not set then
			Skada:Print(L["There is nothing to report."])
			return
		end

		local metadata = window.metadata
		local dataset = window.dataset

		if not metadata or not metadata.ordersort then
			tsort(dataset, value_id_sort)
		end

		if not mode then
			self:Print(L["No mode or segment selected for report."])
			return
		end

		local title = (window and window.title) or mode.title or mode.localeName
		if window.parentmode and title ~= window.parentmode.localeName then
			title = format("%s - %s", window.parentmode.localeName, title)
		end
		local label = (modename == L["Improvement"]) and self.userName or Skada:GetSetLabel(set)
		maxlines = maxlines or 10

		local firstline = format(L["Skada: %s for %s:"], EscapeStr(title, true), label)
		local temp = BuildReportTable(mode, firstline, dataset, maxlines, channel == "text", barid)

		if channel == "text" then
			tinsert(temp, 2, "") -- extra line
			OpenExport(nil, temp:concat("\n"), nil, 12)
		else
			for i = 1, #temp do
				self:SendChat(temp[i], channel, chantype)
			end
		end

		temp = temp:free()
	end
end

-------------------------------------------------------------------------------
-- boss and creature functions

do
	local creature_to_fight = Skada.creature_to_fight or Skada.dummyTable
	local creature_to_boss = Skada.creature_to_boss or Skada.dummyTable
	local GetCreatureId = Skada.GetCreatureId

	-- checks if the provided guid is a boss
	function Skada:IsBoss(guid, strict)
		local id = GetCreatureId(guid)
		if creature_to_boss[id] and creature_to_boss[id] ~= true then
			if strict then
				return false
			end
			return true, id
		elseif creature_to_boss[id] or creature_to_fight[id] then
			return true, id
		end
		return false
	end

	function Skada:IsEncounter(guid, name)
		local isboss, id = self:IsBoss(guid)
		if isboss and id then
			if creature_to_boss[id] and creature_to_boss[id] ~= true then
				return true, creature_to_boss[id], creature_to_fight[id] or name
			end

			if creature_to_fight[id] then
				return true, true, creature_to_fight[id] or name
			end

			return true, id, creature_to_fight[id] or name
		end
		return false
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

	local fake_set, update_timer = nil, nil

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
					Deafknight = {"DEATHKNIGHT", "TANK", 250}, -- Blood Death Knight
					Bubbleboy = {"PRIEST", "HEALER", 256}, -- Discipline Priest
					Channingtotem = {"SHAMAN", "HEALER", 264}, -- Restoration Shaman
					-- Damagers
					Shiftycent = {"DRUID", "DAMAGER", 102}, -- Balance Druid
					Beargrills = {"HUNTER", "DAMAGER", 254}, -- Marksmanship Hunter
					Foodanddps = {"MAGE", "DAMAGER", 63}, -- Fire Mage
					Retryhard = {"PALADIN", "DAMAGER", 70}, -- Retribution Paladin
					Stabass = {"ROGUE", "DAMAGER", 260}, -- Combat Rogue
					Summonbot = {"WARLOCK", "DAMAGER", 266}, -- Demonology Warlock
					Chuggernaut = {"WARRIOR", "DAMAGER", 72} -- Fury Warrior
				}
			end

			return actorsTable
		end
	end

	local function generate_fake_data()
		fake_set = tablePool.acquireHash(
			"name", "Fake Fight",
			"starttime", time() - 120,
			"damage", 0,
			"heal", 0,
			"absorb", 0,
			"type", "raid",
			"actors", new()
		)

		local actors = fake_actors()
		for name, info in pairs(actors) do
			local class, role, spec = info[1], info[2], info[3]
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

			local actor = tablePool.acquireHash(
				"id", name, "name", name, "class", class, "role", role, "spec", spec,
				"damage", damage, "heal", heal, "absorb", absorb
			)
			fake_set.actors[name] = playerPrototype:Bind(actor)

			fake_set.damage = fake_set.damage + damage
			fake_set.heal = fake_set.heal + heal
			fake_set.absorb = fake_set.absorb + absorb
		end

		return setPrototype:Bind(fake_set)
	end

	local function randomize_fake_data(set, coef)
		set.time = time() - set.starttime

		local actors = set.actors
		for actorname, actor in pairs(actors) do
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

	local function update_fake_data(self)
		randomize_fake_data(self.current, self.profile.updatefrequency or 0.25)
		self:UpdateDisplay(true)
	end

	function Skada:TestMode()
		if InCombatLockdown() or IsGroupInCombat() then
			fake_set = del(fake_set, true)
			self.testMode = nil
			if update_timer then
				self:CancelTimer(update_timer)
				update_timer = nil
			end
			return
		end
		self.testMode = not self.testMode
		if not self.testMode then
			fake_set = del(fake_set, true)
			if update_timer then
				self:CancelTimer(update_timer)
				update_timer = nil
			end
			self.current = del(self.current, true)
			return
		end

		self:Wipe()
		self.current = generate_fake_data()
		update_timer = update_timer or self:ScheduleRepeatingTimer(update_fake_data, self.profile.updatefrequency or 0.25, self)
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
		elem:SetStatusBarTexture(format([[%s\Statusbar\Flat.tga]], Skada.mediapath))
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
	local serialize = Private.serialize
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
			self:SendCommMessage(folder, serialize(true, ...), "WHISPER", target, "NORMAL", show_progress_window, self)
		elseif channel then
			self:SendCommMessage(folder, serialize(true, ...), channel, target)
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

	local deserialize = Private.deserialize
	local function on_comm_received(self, prefix, message, channel, sender)
		if prefix == folder and channel and sender and sender ~= self.userName then
			dispatch_comm(sender, deserialize(message, true))
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

		callbacks:Fire("Skada_UpdateComms", enable)
	end

	function Skada.AddComm(self, const, func)
		if not self or not const then return end

		Skada.comms = Skada.comms or {}
		Skada.comms[const] = Skada.comms[const] or {}
		Skada.comms[const][self] = Skada.comms[const][self] or {}
		Skada.comms[const][self][func or const] = true
	end

	function Skada.RemoveComm(self, func)
		if not self or not Skada.comms then return end

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

	function Skada.RemoveAllComms(self)
		if not self or not Skada.comms then return end

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
		elseif insType == "raid" then
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
function Skada:GetSetTime(set)
	local settime = set and set.time
	return not settime and 0 or (settime >= 1) and settime or max(1, time() - set.starttime)
end

-- returns the actor's active/effective time
function Skada:GetActiveTime(set, actor, active)
	-- force active for pvp/arena
	active = active or (set and (set.type == "pvp" or set.type == "arena"))

	-- use settime to clamp
	local settime = self:GetSetTime(set)

	-- active: actor's time.
	if (self.profile.timemesure ~= 2 or active) and actor.time and actor.time > 0 then
		return max(1, min(actor.time, settime))
	end

	-- effective: combat time.
	return settime
end

-- updates the actor's active time
function Skada:AddActiveTime(set, actor, target, override)
	if not actor or not actor.last then return end

	local curtime = Skada._Time or GetTime()
	local delta = curtime - actor.last
	actor.last = curtime

	if override and override > 0 and override <= delta then
		delta = override
	elseif delta > 3.5 then
		delta = 3.5
	end

	local adding = floor(100 * delta + 0.5) * 0.01
	actor.time = (actor.time or 0) + adding

	-- to save up memory, we only record the rest to the current set.
	if (set == self.total and not self.profile.totalidc) or not target then return end

	actor.timespent = actor.timespent or {}
	actor.timespent[target] = (actor.timespent[target] or 0) + adding
end

-------------------------------------------------------------------------------
-- popup dialogs

-- skada reset dialog
do
	local ConfirmDialog = Private.ConfirmDialog

	local t = {timeout = 30, whileDead = 0}
	local f = function() Skada:Reset(IsShiftKeyDown()) end

	function Skada:ShowPopup(win, popup)
		if Skada.testMode then return end

		if Skada.profile.skippopup and not popup then
			Skada:Reset(IsShiftKeyDown())
			return
		end

		ConfirmDialog(L["Do you want to reset Skada?\nHold SHIFT to reset all data."], f, t)
	end
end

-- new window creation dialog
local copy = Private.tCopy
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
	local ConfirmDialog = Private.ConfirmDialog

	local t = {timeout = 15, whileDead = 0}
	local f = function()
		if Skada.data.profiles then
			wipe(Skada.data.profiles)
		end
		if Skada.data.profileKeys then
			wipe(Skada.data.profileKeys)
		end

		Skada.global.reinstall = true
		ReloadUI()
	end

	function Skada:Reinstall()
		ConfirmDialog(L["Are you sure you want to reinstall Skada?"], f, t)
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

			self:Debug("\124cffffbb00COMBAT_BOSS_DEFEATED\124r: BigWigs")
			self:SendMessage("COMBAT_BOSS_DEFEATED", self.current)

			self:StopSegment(L["Smart Stop"])
			self:SetModes()
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

			self:Debug("\124cffffbb00COMBAT_BOSS_DEFEATED\124r: DBM")
			self:SendMessage("COMBAT_BOSS_DEFEATED", set)

			self:StopSegment(L["Smart Stop"])
			self:SetModes()
		end
	end
end

-------------------------------------------------------------------------------
-- misc functions

-- memory usage check
function Skada:CheckMemory()
	if self.__memory_timer then
		self:CancelTimer(self.__memory_timer, true)
		self.__memory_timer = nil
	end

	if not self.profile.memorycheck then return end
	UpdateAddOnMemoryUsage()
	local memory = GetAddOnMemoryUsage(folder)
	if memory > (self.maxmeme * 1024) then
		self:Notify(L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."], L["Memory Check"], nil, "emergency")
	end
end

-- clean garbage
do
	local InCombatLockdown = InCombatLockdown
	local collectgarbage = collectgarbage
	function Skada:CleanGarbage()
		if self.__garbage_timer then
			self:CancelTimer(self.__garbage_timer, true)
			self.__garbage_timer = nil
		end

		if InCombatLockdown() then return end
		collectgarbage("collect")
		self:Debug("Garbage \124cffffbb00Cleaned\124r!")
	end
end

-------------------------------------------------------------------------------
-- player & enemies functions

do
	local UnitLevel = UnitLevel
	local GetUnitRole = Skada.GetUnitRole
	local GetUnitSpec = Skada.GetUnitSpec
	local GetUnitIdFromGUID = Skada.GetUnitIdFromGUID
	local actorPrototype = Skada.actorPrototype
	local playerPrototype = Skada.playerPrototype
	local enemyPrototype = Skada.enemyPrototype
	local modes = Skada.modes

	local dummy_actor = {} -- used as fallback

	-- attempts to find and actor
	function Skada:FindActor(set, actorname, actorid, is_strict)
		-- make sure we have all data
		actorid = actorid or actorname
		actorname = actorname or actorid

		-- why? I don't know...
		if actorid == "total" or actorname == L["Total"] then return end

		-- no set/actors table?
		if not set or not set.actors then return end

		-- already cached?
		local actor = set.actors[actorname]
		if actor then
			return (actor.enemy and enemyPrototype or playerPrototype):Bind(actor)
		end

		-- is_strict means we don't use our dummy_actor
		if is_strict then return end

		-- speed up things with pets
		if strmatch(actorname, "%<(%a+)%>") then
			dummy_actor.id = actorid
			dummy_actor.class = "PET"
			return actorPrototype:Bind(dummy_actor)
		end

		-- well.. our last hope!
		dummy_actor.id = actorid
		dummy_actor.class = (set.mobname == actorname) and "ENEMY" or "UNKNOWN" -- can be wrong
		return actorPrototype:Bind(dummy_actor)
	end

	-- generic: finds a player/enemy or creates it.
	function Skada:GetActor(set, actorname, actorid, actorflags)
		-- no set/actors table, sorry!
		if not set or not set.actors then return end

		-- attempt to find the actor (true: no dummy_actor)
		local actor = self:FindActor(set, actorname, actorid, true)

		-- not found? try to creat it then
		if not actor then
			-- at least the name should be provided!
			if not actorname then return end

			-- make sure we have all data
			actorid = actorid or actorname

			-- create a new actor table...
			actor = new()
			actor.id = actorid
			actor.__new = true

			-- is it me? move on..
			if actorid == self.userGUID then
				actor.class = self.userClass
				actor.spec, actor.talent = GetUnitSpec(self.userGUID)
				actor.role = GetUnitRole(self.userGUID)
			end

			-- actorflags:true => fake actor
			if not actor.class and actorflags == true then
				actor.enemy = true
				actor.class = "ENEMY"
				actor.fake = true
			end

			-- a group member/pet?
			if not actor.class and guidToClass[actorid] then
				actor.class = guidToClass[actorid]
				if guidToName[actor.class] then
					actor.class = "PET"
				else
					actor.spec, actor.talent = GetUnitSpec(actorid)
					actor.role = GetUnitRole(actorid)
				end
			end

			-- was it a player? (pvp scenario)
			if not actor.class and self:IsPlayer(actorflags) then
				local unit = GetUnitIdFromGUID(actorid, true)
				if unit then -- found a valid unit?
					_, actor.class = UnitClass(unit)
				else
					actor.class = "PLAYER"
				end
				if not self:IsFriendly(actorflags) or not self:InGroup(actorflags) then
					actor.enemy = true
				end
			end

			-- avoid "nil" stuff
			if not actor.class and not self:IsNone(actorflags) then
				local unit = GetUnitIdFromGUID(actorid)
				local level = unit and UnitLevel(unit)
				if level == -1 or self:IsBoss(actorid, true) then
					actor.class = "BOSS"
				elseif self:IsPet(actorflags) then
					actor.class = "PET"
				elseif self:IsNeutral(actorflags) then
					actor.class = "NEUTRAL"
				else
					actor.class = "MONSTER"
				end
				if not self:IsFriendly(actorflags) or not self:InGroup(actorflags) then
					actor.enemy = true
				end
			end

			-- last hope!
			if not actor.class then
				actor.enemy = true
				actor.class = "UNKNOWN"
				self:Debug(format("Unknown unit detected: \124cffffbb00%s\124r (%s)", actorname, actorid))
			end

			for _, mode in pairs(modes) do
				-- common
				if mode.AddActorAttributes then
					mode:AddActorAttributes(actor, set)
				end

				if mode.AddEnemyAttributes and actor.enemy then
					mode:AddEnemyAttributes(actor, set) -- enemies
				elseif mode.AddPlayerAttributes and not actor.enemy then
					mode:AddPlayerAttributes(actor, set) -- players
				end
			end

			set.actors[actorname] = actor
		end

		-- add more details to the actor...
		if guidToClass[actor.id] then
			if self.validclass[actor.class] then
				-- missing spec?
				if actor.spec == nil then
					actor.spec = GetUnitSpec(actor.id)
					actor.__mod = true
				end
				-- missing role?
				if actor.role == nil or actor.role == "NONE" then
					actor.role = GetUnitRole(actor.id)
					actor.__mod = true
				end
			end

			-- total set has "last" always removed.
			if not actor.last then
				actor.last = Skada._Time or GetTime()
				actor.__mod = true
			end
		end

		-- pvp enabled
		if self.validclass[actor.class] and self.forPVP and not actor.spec then
			actor.__mod = true
		end

		-- remove __mod key and fire callbacks
		if actor.__new or actor.__mod then
			actor.__mod = nil
			callbacks:Fire(actor.enemy and "Skada_GetEnemy" or "Skada_GetPlayer", actor, set)
		end

		-- trigger addon change status
		self.changed = true

		-- remove the __new key after binding the actor
		if actor.__new then
			actor.__new = nil
			return (actor.enemy and enemyPrototype or playerPrototype):Bind(actor), true
		end
		return actor
	end
end

-------------------------------------------------------------------------------
-- pet functions

do
	do
		local GetPetOwnerFromTooltip
		do
			local pettooltip = CreateFrame("GameTooltip", format("%sPetTooltip", folder), nil, "GameTooltipTemplate")

			local ValidatePetOwner
			do
				local ownerPatterns = {}
				do
					local i = 1
					local title = _G[format("UNITNAME_SUMMON_TITLE%s", i)]
					while (title and title ~= "%s" and find(title, "%s")) do
						ownerPatterns[#ownerPatterns + 1] = title
						i = i + 1
						title = _G[format("UNITNAME_SUMMON_TITLE%s", i)]
					end
				end

				local EscapeStr = Private.EscapeStr
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
			local GetNumDeclensionSets, DeclineName = GetNumDeclensionSets, DeclineName
			local function FindNameDeclension(text, actorname)
				for gender = 2, 3 do
					for decset = 1, GetNumDeclensionSets(actorname, gender) do
						local ownerName = DeclineName(actorname, gender, decset)
						if ValidatePetOwner(text, ownerName) or find(text, ownerName) then
							return true
						end
					end
				end
				return false
			end

			-- attempt to get the pet's owner from tooltip
			function GetPetOwnerFromTooltip(guid)
				local set = guid and Skada.current
				local actors = set and set.actors
				if not actors then return end

				pettooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
				pettooltip:ClearLines()
				pettooltip:SetHyperlink(format("unit:%s", guid))

				-- we only need to scan the 2nd line.
				local text = _G["SkadaPetTooltipTextLeft2"] and _G["SkadaPetTooltipTextLeft2"]:GetText()
				if not text or text == "" then return end

				for actorname, actor in pairs(actors) do
					local name = not actor.enemy and gsub(actorname, "%-.*", "")
					if name and ((LOCALE_ruRU and FindNameDeclension(text, name)) or ValidatePetOwner(text, name)) then
						return actor.id, actorname
					end
				end
			end
		end

		local UnitIterator = Skada.UnitIterator
		local function GetPetOwnerUnit(guid)
			for unit, owner in UnitIterator() do
				if owner ~= nil and UnitGUID(unit) == guid then
					return owner
				end
			end
		end

		local function FixPetsHandler(guid, flag)
			local guidOrClass = guid and guidToClass[guid]
			if guidOrClass and guidToName[guidOrClass] then
				return guidOrClass, guidToName[guidOrClass]
			end

			-- flag is provided and it is mine.
			if guid and flag and Skada:IsMine(flag) then
				guidToOwner[guid] = Skada.userGUID
				return Skada.userGUID, Skada.userName
			end

			-- no owner yet?
			if not guid then return end

			-- guess the pet from roster.
			local ownerUnit = GetPetOwnerUnit(guid)
			if ownerUnit then
				local ownerGUID = UnitGUID(ownerUnit)
				guidToOwner[guid] = ownerGUID
				return ownerGUID, UnitFullName(ownerUnit)
			end

			-- guess the pet from tooltip.
			local ownerGUID, ownerName = GetPetOwnerFromTooltip(guid)
			if ownerGUID and ownerName then
				guidToOwner[guid] = ownerGUID
				return ownerGUID, ownerName
			end
		end

		local IsPlayer = Private.IsPlayer
		function Skada:FixPets(action)
			if not action then return end
			action.petname = nil -- clear it

			-- 1: group member / true: player / false: everything else
			if IsPlayer(action.actorid, action.actorname, action.actorflags) ~= false then return end

			local ownerGUID, ownerName = FixPetsHandler(action.actorid, action.actorflags)
			if ownerGUID and ownerName then
				if self.profile.mergepets then
					action.petname = action.actorname
					action.actorid = ownerGUID
					action.actorname = ownerName

					if action.actorflags then
						action.actorflags = self:GetOwnerFlags(action.actorflags)
					end
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

		local IsPet = Private.IsPet
		function Skada:FixMyPets(guid, name, flags)
			if not IsPet(guid, flags) then
				return guid, name, flags
			end

			local ownerGUID, ownerName = FixPetsHandler(guid, flags)
			if ownerGUID and ownerName then
				return ownerGUID, ownerName, self:GetOwnerFlags(flags)
			end

			return guid, name, flags
		end

		function Skada:FixPetsName(guid, name, flags)
			local _, ownerName = self:FixMyPets(guid, name, flags)
			return (name and ownerName and ownerName ~= name) and format("%s <%s>", name, ownerName) or name
		end
	end

	function Skada:GetPetOwner(petGUID)
		local guidOrClass = guidToClass[petGUID]
		if guidOrClass and guidToName[guidOrClass] then
			return guidOrClass, guidToName[guidOrClass], guidToClass[guidOrClass]
		end
	end
end

-------------------------------------------------------------------------------
-- combat log parser

do
	local loadstring, rawset = loadstring, rawset
	local strsub, strlen, strlower = string.sub, string.len, string.lower

	-- args associated to each event name prefix
	local PREFIXES = {
		SWING = "",
		RANGE = ", spellid, spellname, spellschool",
		SPELL = ", spellid, spellname, spellschool",
		SPELL_PERIODIC = ", spellid, spellname, spellschool",
		SPELL_BUILDING = ", spellid, spellname, spellschool",
		ENVIRONMENTAL = ", envtype"
	}

	-- args associated to each event name suffix
	local SUFFIXES = {
		DAMAGE = ", amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing",
		MISSED = ", misstype, amount",
		HEAL = ", amount, overheal, absorbed, critical",
		ENERGIZE = ", amount, powertype",
		DRAIN = ", amount, powertype, extraamount",
		LEECH = ", amount, powertype, extraamount",
		INTERRUPT = ", extraspellid, extraspellname, extraschool",
		DISPEL = ", extraspellid, extraspellname, extraschool, auratype",
		DISPEL_FAILED = ", extraspellid, extraspellname, extraschool",
		STOLEN = ", extraspellid, extraspellname, extraschool, auratype",
		EXTRA_ATTACKS = ", amount",
		AURA_APPLIED = ", auratype, amount",
		AURA_REMOVED = ", auratype, amount",
		AURA_APPLIED_DOSE = ", auratype, amount",
		AURA_REMOVED_DOSE = ", auratype, amount",
		AURA_REFRESH = ", auratype, amount",
		AURA_BROKEN = ", auratype",
		AURA_BROKEN_SPELL = ", extraspellid, extraspellname, extraschool, auratype",
		CAST_START = "",
		CAST_SUCCESS = "",
		CAST_FAILED = ", failtype",
		INSTAKILL = "",
		DURABILITY_DAMAGE = "",
		DURABILITY_DAMAGE_ALL = "",
		CREATE = "",
		SUMMON = "",
		RESURRECT = ""
	}

	-- aliases of events that don't follow prefix_suffix
	local ALIASES = {
		DAMAGE_SHIELD = "SPELL_DAMAGE",
		DAMAGE_SPLIT = "SPELL_DAMAGE",
		DAMAGE_SHIELD_MISSED = "SPELL_MISSED"
	}

	-- creates dispatchers
	local code = [[local wipe = wipe; return function(e, %s) wipe(e); e.%s = %s; return e; end]]
	local Dispatchers = setmetatable({}, {__index = function(self, args)
		local dispatcher = loadstring(format(code, args, gsub(args, ", ", ", e."), args), args)()
		rawset(self, args, dispatcher)
		return dispatcher
	end})

	local DEFAULTS = "timestamp, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags"
	local Handlers = setmetatable({}, {__index = function(self, event)
		local args = DEFAULTS -- default args first
		event = ALIASES[event] or event

		for prefix, prefix_args in pairs(PREFIXES) do
			local len = strlen(prefix)
			if strsub(event, 1, len) == prefix then
				local suffix_args = SUFFIXES[strsub(event, len + 2)]
				if suffix_args then
					args = format("%s%s%s", args, prefix_args, suffix_args)
					break
				end
			end
		end

		local handler = Dispatchers[args]
		rawset(self, event, handler)
		return handler
	end})

	-- environment fake spell ids
	local environment_ids = {
		falling = 3,
		drowning = 4,
		fatigue = 5,
		fire = 6,
		lava = 7,
		slime = 8
	}

	-- environmental types/names
	local environment_names = {
		falling = L["Falling"],
		drowning = L["Drowning"],
		fatigue = L["Fatigue"],
		fire = L["Fire"],
		lava = L["Lava"],
		slime = L["Slime"]
	}

	-- environmental fake spell schools
	local environment_schools = {
		falling = 0x01,
		drowning = 0x01,
		fatigue = 0x01,
		fire = 0x04,
		lava = 0x04,
		slime = 0x08
	}

	local ext_attacks = {} -- extra attacks table

	local function create_extra_attack(args)
		if ext_attacks[args.srcName] then return end

		ext_attacks[args.srcName] = tablePool.acquireHash(
			"proc_id", args.spellid, "proc_name", args.spellname,
			"proc_amount", args.amount, "proc_time", GetTime()
		)
	end

	local function check_extra_attack(args)
		-- no extra attack was recorded
		if not ext_attacks[args.srcName] then
			return

		-- it was missing a spell?
		elseif not ext_attacks[args.srcName].spellname then
			ext_attacks[args.srcName].spellname = args.spellname

		-- valid so fat?
		elseif ext_attacks[args.srcName].spellname and args.spellid == 6603 then
			-- expired proc?
			if ext_attacks[args.srcName].proc_time < GetTime() - 5 then
				ext_attacks[args.srcName] = del(ext_attacks[args.srcName])
				return
			end

			local spellid = args.spellid -- to generate spellstring
			args.spellid = ext_attacks[args.srcName].proc_id
			args.spellname = format("%s (%s)", ext_attacks[args.srcName].spellname, ext_attacks[args.srcName].proc_name)
			args.spellstring = format("%s.%s.%s", args.spellid, args.spellschool, spellid)

			ext_attacks[args.srcName].proc_amount = ext_attacks[args.srcName].proc_amount - 1
			if ext_attacks[args.srcName].proc_amount == 0 then
				ext_attacks[args.srcName] = del(ext_attacks[args.srcName])
			end
		end
	end

	local ARGS = {} -- reusable args table
	do
		local bit_band = bit.band
		local ARGS_MT = {}

		do -- source or destination in the group
			local BITMASK_GROUP = Private.BITMASK_GROUP
			local BITMASK_PETS = Private.BITMASK_PETS

			function ARGS_MT.SourceInGroup(args, nopets)
				if args._srcInGroup == nil then
					if guidToName[args.srcGUID] ~= nil then
						args._srcInGroup = true
						args._srcInGroupNopets = true
						args._srcIsPet = false
						args._srcIsGroupPet = false
					else
						args._srcInGroup = (bit_band(args.srcFlags, BITMASK_GROUP) ~= 0)
					end
				end

				if args._srcInGroupNopets == nil then
					if bit_band(args.srcFlags, BITMASK_PETS) == 0 then
						args._srcInGroupNopets = args._srcInGroup
						args._srcIsPet = false
						args._srcIsGroupPet = false
					else
						args._srcInGroupNopets = false
						args._srcIsPet = true
						args._srcIsGroupPet = (guidToOwner[args.srcGUID] ~= nil)
					end
				end

				if nopets then
					return args._srcInGroupNopets
				end
				return args._srcInGroup
			end

			function ARGS_MT.DestInGroup(args, nopets)
				if args._dstInGroup == nil then
					if guidToName[args.dstGUID] ~= nil then
						args._dstInGroup = true
						args._dstInGroupNopets = true
						args._dstIsPet = false
						args._dstIsGroupPet = false
						args._dstIsOwnedPet = false
					else
						args._dstInGroup = (bit_band(args.dstFlags, BITMASK_GROUP) ~= 0)
					end
				end

				if args._dstInGroupNopets == nil then
					if bit_band(args.dstFlags, BITMASK_PETS) == 0 then
						args._dstInGroupNopets = args._dstInGroup
						args._dstIsPet = false
						args._dstIsGroupPet = false
						args._dstIsOwnedPet = false
					else
						args._dstInGroupNopets = false
						args._dstIsPet = true
						args._dstIsGroupPet = (guidToOwner[args.dstGUID] ~= nil)
					end
				end

				if nopets then
					return args._dstInGroupNopets
				end
				return args._dstInGroup
			end

			function ARGS_MT.IsGroupEvent(args, nopets)
				return args:SourceInGroup(nopets) or args:DestInGroup(nopets)
			end

			function ARGS_MT.SourceIsPet(args, ingroup)
				if args._srcIsPet == nil then
					args._srcIsPet = (bit_band(args.srcFlags, BITMASK_PETS) ~= 0)
				end

				if not args._srcIsPet then
					return false
				elseif args._srcIsGroupPet == nil then
					args._srcIsGroupPet = (guidToOwner[args.srcGUID] ~= nil)
				end

				if ingroup then
					return args._srcIsGroupPet
				end
				return args._srcIsPet
			end

			-- owner=true? acts like "ingroup" (SourceIsPet)
			function ARGS_MT.DestIsPet(args, owner)
				if args._dstIsPet == nil then
					args._dstIsPet = (bit_band(args.dstFlags, BITMASK_PETS) ~= 0)
				end

				if not args._dstIsPet then
					return false
				elseif owner == true then
					if args._dstIsGroupPet == nil then
						args._dstIsGroupPet = (guidToOwner[args.dstGUID] ~= nil)
					end
					return args._dstIsGroupPet
				elseif owner then
					if args._dstIsOwnedPet == nil then
						args._dstIsOwnedPet = (bit_band(args.srcFlags, BITMASK_GROUP) ~= 0) -- owner is a group member?
						args._dstIsOwnedPet = args._dstIsOwnedPet or (bit_band(args.srcFlags, BITMASK_PETS) ~= 0) -- summoned by another pet?
						args._dstIsOwnedPet = args._dstIsOwnedPet or (guidToClass[args.dstGUID] ~= nil) -- already known pet
					end
					return args._dstIsOwnedPet
				else
					return args._dstIsPet
				end
			end
		end

		do -- source or destination are players
			local BITMASK_PLAYER = Private.BITMASK_PLAYER
			function ARGS_MT.SourceIsPlayer(args)
				if args._srcIsPlayer == nil then
					args._srcIsPlayer = (guidToName[args.srcGUID] ~= nil) or (bit_band(args.srcFlags, BITMASK_PLAYER) == BITMASK_PLAYER)
				end
				return args._srcIsPlayer
			end
			function ARGS_MT.DestIsPlayer(args)
				if args._dstIsPlayer == nil then
					args._dstIsPlayer = (guidToName[args.dstGUID] ~= nil) or (bit_band(args.dstFlags, BITMASK_PLAYER) == BITMASK_PLAYER)
				end
				return args._dstIsPlayer
			end
		end

		do -- source or destination are bosses
			local BossIDs = Skada.BossIDs
			local GetCreatureId = Skada.GetCreatureId

			function ARGS_MT.SourceIsBoss(args)
				if args._srcIsBoss == nil then
					args._srcIsBoss = BossIDs[GetCreatureId(args.srcGUID)] or false
				end
				return args._srcIsBoss
			end
			function ARGS_MT.DestIsBoss(args)
				if args._dstIsBoss == nil then
					args._dstIsBoss = BossIDs[GetCreatureId(args.dstGUID)] or false
				end
				return args._dstIsBoss
			end
			function ARGS_MT.IsBossEvent(args)
				return args:SourceIsBoss() or args:DestIsBoss()
			end
		end

		do -- source and destination reactions
			local BITMASK_FRIENDLY = Private.BITMASK_FRIENDLY
			function ARGS_MT.SourceIsFriendly(args)
				if args._srcIsFriendly == nil then
					args._srcIsFriendly = (bit_band(args.srcFlags, BITMASK_FRIENDLY) ~= 0)
					if args._srcIsFriendly then
						args._srcIsNeutral = false
						args._srcIsHostile = false
					end
				end
				return args._srcIsFriendly
			end
			function ARGS_MT.DestIsFriendly(args)
				if args._dstIsFriendly == nil then
					args._dstIsFriendly = (bit_band(args.dstFlags, BITMASK_FRIENDLY) ~= 0)
					if args._dstIsFriendly then
						args._dstIsNeutral = false
						args._dstIsHostile = false
					end
				end
				return args._dstIsFriendly
			end

			local BITMASK_NEUTRAL = Private.BITMASK_NEUTRAL
			function ARGS_MT.SourceIsNeutral(args)
				if args._srcIsNeutral == nil then
					args._srcIsNeutral = (bit_band(args.srcFlags, BITMASK_NEUTRAL) ~= 0)
					if args._srcIsNeutral then
						args._srcIsFriendly = false
						args._srcIsHostile = false
					end
				end
				return args._srcIsNeutral
			end
			function ARGS_MT.DestIsNeutral(args)
				if args._dstIsNeutral == nil then
					args._dstIsNeutral = (bit_band(args.dstFlags, BITMASK_NEUTRAL) ~= 0)
					if args._dstIsNeutral then
						args._dstIsFriendly = false
						args._dstIsHostile = false
					end
				end
				return args._dstIsNeutral
			end

			local BITMASK_HOSTILE = Private.BITMASK_HOSTILE
			function ARGS_MT.SourceIsHostile(args)
				if args._srcIsHostile == nil then
					args._srcIsHostile = (bit_band(args.srcFlags, BITMASK_HOSTILE) ~= 0)
					if args._srcIsHostile then
						args._srcIsFriendly = false
						args._srcIsNeutral = false
					end
				end
				return args._srcIsHostile
			end
			function ARGS_MT.DestIsHostile(args)
				if args._dstIsHostile == nil then
					args._dstIsHostile = (bit_band(args.dstFlags, BITMASK_HOSTILE) ~= 0)
					if args._dstIsHostile then
						args._dstIsFriendly = false
						args._dstIsNeutral = false
					end
				end
				return args._dstIsHostile
			end
		end

		setmetatable(ARGS, {__index = ARGS_MT})
		ARGS_MT.__index = ARGS_MT
	end

	-- trigger events used for first hit check
	-- Edit Skada\Core\Tables.lua <trigger_events>
	local TRIGGER_EVENTS = Skada.trigger_events

	-- specific events used for specific reasons.
	local SWING_EVENTS = {SWING_DAMAGE = true, SWING_MISSED = true}
	local ENVIRONMENT_EVENTS = {ENVIRONMENTAL_DAMAGE = true, ENVIRONMENTAL_MISSED = true}
	local DOT_EVENTS = {SPELL_PERIODIC_DAMAGE = true, SPELL_PERIODIC_MISSED = true}
	local HOT_EVENTS = {SPELL_PERIODIC_HEAL = true--[[, SPELL_PERIODIC_ENERGIZE = true--]]}

	-- combat log handler
	function Skada:ParseCombatLog(_, timestamp, event, ...)
		-- disabled or test mode?
		if self.disabled or self.testMode then return end

		local args = Handlers[event](ARGS, timestamp, event, ...)

		if event == "SPELL_EXTRA_ATTACKS" then
			create_extra_attack(args)
			return -- queue for later!
		end

		if SWING_EVENTS[event] then
			args.spellid = 6603
			args.spellname = L["Melee"]
			args.spellschool = 0x01
		elseif ENVIRONMENT_EVENTS[event] and args.envtype then
			local envtype = strlower(args.envtype)
			args.spellid = environment_ids[envtype]
			args.spellname = environment_names[envtype]
			args.spellschool = environment_schools[envtype]
			args.srcName = L["Environment"]
		elseif DOT_EVENTS[event] or args.auratype == "DEBUFF" then
			args.is_dot = true
		elseif HOT_EVENTS[event] then
			args.is_hot = true
		end

		-- check for extra attack
		check_extra_attack(args)

		-- process some miss types!
		if args.misstype == "ABSORB" and args.amount then
			args.absorbed = args.amount
			args.amount = 0
		elseif args.misstype == "BLOCK" and args.amount then
			args.blocked = args.amount
			args.amount = 0
		elseif args.misstype == "RESIST" and args.amount then
			args.resisted = args.amount
			args.amount = 0
		elseif args.misstype and not args.amount then
			args.amount = 0
		end

		if args.spellid and args.spellschool and not args.spellstring then
			args.spellstring = format((args.is_dot or args.is_hot) and "-%s.%s" or "%s.%s", args.spellid, args.spellschool)
		end

		if args.extraspellid and args.extraschool and not args.extrastring then
			args.extrastring = format("%s.%s", args.extraspellid, args.extraschool)
		end

		-- the event happens within the group?
		args.inside_event = args:IsGroupEvent()
		self.LastEvent = args

		-- not really? skip everything else...
		if not args.inside_event then
			return self:OnCombatEvent(args)
		end

		if args.spellstring then
			callbacks:Fire("Skada_SpellString", args, args.spellid, args.spellstring)
		end

		if args.extrastring then
			callbacks:Fire("Skada_SpellString", args, args.extraspellid, args.extrastring)
		end

		-- check first hit!
		if self.profile.firsthit and not self.firsthit and TRIGGER_EVENTS[args.event] then
			self:CheckFirstHit(args)
		end

		return self:OnCombatEvent(args)
	end
end

-------------------------------------------------------------------------------
-- group buffs scanner

do
	local UnitIsDeadOrGhost, UnitBuff = UnitIsDeadOrGhost, UnitBuff
	local UnitIterator = Skada.UnitIterator
	local actorflags = Private.DEFAULT_FLAGS
	local clear = Private.clearTable

	local function ScanUnitBuffs(unit, owner, t)
		if UnitIsDeadOrGhost(unit) then return end

		t.dstGUID = UnitGUID(unit)
		t.dstName = UnitFullName(unit, owner)
		t.dstFlags = not owner and actorflags or nil

		t.class = guidToClass[t.dstGUID]
		if guidToName[t.class] then
			t.class = "PET"
		end

		t.unit, t.owner = unit, owner
		t.auras = clear(t.auras) or new()

		for i = 1, 41 do
			local name, _, icon, _, _, duration, expires, source, _, _, id = UnitBuff(unit, i)
			if not id then
				break -- nothing found
			elseif source then
				local aura = new()
				aura.srcGUID = UnitGUID(source)
				aura.srcName = UnitFullName(source)
				aura.srcFlags = actorflags
				aura.id = id
				aura.name = name
				aura.icon = icon
				aura.duration = duration
				aura.expires = expires
				t.auras[#t.auras + 1] = aura
			end
		end

		if next(t.auras) then
			callbacks:Fire("Skada_UnitBuffs", t)
		end
	end


	local function ScanGroupBuffs(self, timestamp)
		if self.global.inCombat then return end

		local t = new()
		t.event = "SPELL_AURA_APPLIED"
		t.timestamp = timestamp
		t.time = self._time
		t.Time = self._time

		for unit, owner in UnitIterator() do
			if not UnitIsDeadOrGhost(unit) then
				ScanUnitBuffs(unit, owner, t)
			end
		end
		t = del(t, true)
	end

	Skada.ScanGroupBuffs = Skada.EmptyFunc
	function callbacks:OnUsed(_, event)
		if event == "Skada_UnitBuffs" then
			Skada.ScanGroupBuffs = ScanGroupBuffs
		end
	end
end

-------------------------------------------------------------------------------
-- first hit check

do
	local UnitExists, SpellLink = UnitExists, Private.SpellLink or GetSpellLink
	local IsPet, uformat = Private.IsPet, Private.uformat
	local ignored_spells = Skada.ignored_spells.firsthit
	local firsthit_fmt = {"%s (%s)", "%s (\124c%s%s\124r)", "\124c%s%s\124r", "\124c%s%s\124r (%s)"}

	local boss_units = Skada.Units.boss
	local function WhoPulled(hit_line)
		hit_line = hit_line or L["\124cffffbb00First Hit\124r: *?*"] -- first hit

		local target_table = nil
		for _, unit in next, boss_units do
			if not UnitExists(unit) then break end

			local target_unit = format("%starget", unit)
			local target = UnitFullName(target_unit)
			if target then
				local _, class = UnitClass(target_unit)
				if class then
					target = Skada.classcolors.format(class, target)
				end

				target_table = target_table or TempTable()
				target_table:insert(uformat("%s > %s", UnitFullName(unit), target))
			end
		end

		local target_line = nil
		if target_table then
			target_line = format(L["\124cffffbb00Boss First Target\124r: %s"], target_table:concat(" \124\124 "))
			target_table = target_table:free()
		end

		return hit_line, target_line
	end

	function Skada:CheckFirstHit(t)
		-- ignored spell?
		if t.event ~= "SWING_DAMAGE" and t.spellid and ignored_spells[t.spellid] then return end

		local output = nil -- initial ouptut

		if self:IsBoss(t.srcGUID) then -- boss started?
			if IsPet(t.dstGUID, t.dstFlags) then
				output = uformat(firsthit_fmt[1], t.srcName, t.dstName)
			elseif t.dstName then
				local _, class = UnitClass(t.dstName)
				if class then
					output = uformat(firsthit_fmt[2], t.srcName, self.classcolors.str(class), t.dstName)
				else
					output = uformat(firsthit_fmt[1], t.srcName, t.dstName)
				end
			end
		elseif self:IsBoss(t.dstGUID) then -- a player/pet started?
			local _, ownerName, ownerClass = self:GetPetOwner(t.srcGUID)
			if ownerName then
				if ownerClass then
					output = uformat(firsthit_fmt[4], self.classcolors.str(ownerClass), ownerName, L["PET"])
				else
					output = uformat(firsthit_fmt[1], ownerName, L["PET"])
				end
			elseif t.srcName then
				local _, class = UnitClass(t.srcName)
				if class and self.classcolors[class] then
					output = uformat(firsthit_fmt[3], self.classcolors.str(class), t.srcName)
				else
					output = t.srcName
				end
			end
		end

		if output then
			local spell = SpellLink(t.spellid) or t.spellname or L["Unknown"]
			self.firsthit = self.firsthit or TempTable()
			self.firsthit.hitline = WhoPulled(uformat(L["\124cffffff00First Hit\124r: %s from %s"], spell, output))
		end
	end

	do
		local firsthit_timer = nil
		local function PrintFirstHit()
			local t = Skada.firsthit
			if t then
				t.hitline, t.targetline = WhoPulled(t.hitline)
				Skada:Print(t.hitline)
				if t.targetline then
					Skada:Print(t.targetline)
				end
				Skada:Debug("\124cffffbb00First Hit\124r: Printed!")
			end
		end

		function Skada:PrintFirstHit()
			if not self.profile.firsthit then
				return self:ClearFirstHit()
			end

			firsthit_timer = firsthit_timer or self:ScheduleTimer(PrintFirstHit, 0.5)
		end

		function Skada:ClearFirstHit()
			if self.firsthit then
				self.firsthit = self.firsthit:free()
				self:Debug("\124cffffbb00First Hit\124r: Cleared!")
			end
			if firsthit_timer then
				self:CancelTimer(firsthit_timer, true)
				firsthit_timer = nil
			end
		end
	end
end

-------------------------------------------------------------------------------
-- smart stop

do
	local smartstop_timer = nil
	-- list of creature IDs to be ignored
	local ignored_creature = {
		[37217] = true, -- ICC: Precious
		[37025] = true -- iCC: Stinky
	}

	local function SmartStop(set)
		if smartstop_timer then
			Skada:CancelTimer(smartstop_timer, true)
			smartstop_timer = nil
		end

		if set.endtime then return end
		Skada:StopSegment(L["Smart Stop"])
		Skada:SetModes()
	end

	function Skada:SmartStop(set)
		if
			not self.profile.smartstop and -- feature disabled?
			not set or set.stopped and -- no set or already stopped?
			not set.gotboss and -- not a boss fight?
			not ignored_creature[set.gotboss] -- an ignored boss fight?
		then
			return
		end

		-- (re)schedule smart stop.
		if smartstop_timer then
			Skada:CancelTimer(smartstop_timer, true)
			smartstop_timer = nil
		end
		smartstop_timer = self:ScheduleTimer(SmartStop, self.profile.smartwait or 3, set)
	end
end
