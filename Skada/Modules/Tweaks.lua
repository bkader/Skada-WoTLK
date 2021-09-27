assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Tweaks", function(Skada, L)
	if Skada:IsDisabled("Tweaks") then return end

	local mod = Skada:NewModule(L["Tweaks"], "AceHook-3.0")

	local select, band, format = select, bit.band, string.format
	local UnitExists, UnitName, UnitClass = UnitExists, UnitName, UnitClass
	local GetSpellLink, GetSpellInfo = Skada.GetSpellLink, Skada.GetSpellInfo
	local After, NewTimer = Skada.After, Skada.NewTimer

	local BITMASK_GROUP = Skada.BITMASK_GROUP or bit.bor(COMBATLOG_OBJECT_AFFILIATION_MINE, COMBATLOG_OBJECT_AFFILIATION_PARTY, COMBATLOG_OBJECT_AFFILIATION_RAID)
	local pull_timer, channelEvents, fofrostmourne

	local ignoredspells = {
		[1130] = true, -- Hunter's Mark (rank 1)
		[14323] = true, -- Hunter's Mark (rank 2)
		[14324] = true, -- Hunter's Mark (rank 3)
		[14325] = true, -- Hunter's Mark (rank 4)
		[53338] = true, -- Hunter's Mark (rank 5)
		[60122] = true, -- Baby Spice
		[56191] = true -- Shadow Jade Focusing Lens
	}

	-- thank you Details!
	local function WhoPulled(self)
		-- first hit
		local hitline = self.HitBy or L["|cffffbb00First Hit|r: *?*"]
		Skada:Print(hitline)

		-- firt boss target
		local targetline
		for i = 1, 4 do
			local boss = "boss" .. i
			if not UnitExists(boss) then
				break -- no need
			end

			local target = UnitName(boss .. "target")
			if target then
				local class = select(2, UnitClass(boss .. "target"))

				if class and Skada.classcolors[class] then
					target = "|c" .. Skada.classcolors[class].colorStr .. target .. "|r"
				end
				targetline = format(L["|cffffbb00Boss First Target|r: %s (%s)"], target, UnitName(boss) or UNKNOWN)
				break -- no need
			end
		end

		if targetline then
			Skada:Print(targetline)
		end
	end

	---------------------------------------------------------------------------
	-- CombatLogEvent Hook

	do
		local triggerevents = {
			["RANGE_DAMAGE"] = true,
			["SPELL_BUILDING_DAMAGE"] = true,
			["SPELL_DAMAGE"] = true,
			["SWING_DAMAGE"] = true
		}

		function mod:CombatLogEvent(_, _, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
			-- The Lich King fight & Fury of Frostmourne
			if select(1, ...) == 72350 or select(2, ...) == fofrostmourne then
				-- the segment should be flagged as success.
				if Skada.current and not Skada.current.success then
					local set = Skada.current -- catch it before it goes away
					After(Skada.db.profile.updatefrequency or 0.25, function()
						set.success = true
						Skada.callbacks:Fire("COMBAT_BOSS_DEFEATED", set)
					end)
				end
				-- ignore the spell
				if Skada.db.profile.fofrostmourne then return end
			end

			-- first hit
			if Skada.db.profile.firsthit and (triggerevents[eventtype] or eventtype == "SPELL_CAST_SUCCESS") and not pull_timer and not ignoredspells[select(1, ...)] then
				if srcName and dstName and ((band(srcFlags, BITMASK_GROUP) ~= 0 and Skada:IsBoss(dstGUID)) or (band(dstFlags, BITMASK_GROUP) ~= 0 and Skada:IsBoss(srcGUID))) then
					local puller

					-- close distance?
					if Skada:IsBoss(srcGUID) then
						puller = srcName -- the boss name
						if Skada:IsPet(dstGUID, dstFlags) then
							puller = puller .. " (" .. (dstName or UNKNOWN) .. ")"
						elseif dstName then
							local class = select(2, UnitClass(dstName))
							if class and Skada.classcolors[class] then
								puller = puller .. " (|c" .. Skada.classcolors[class].colorStr .. dstName .. "|r)"
							else
								puller = puller .. " (" .. dstName .. ")"
							end
						end
					else
						local owner = Skada:GetPetOwner(srcGUID)
						if owner then
							local class = select(2, UnitClass(owner.name))
							if class and Skada.classcolors[class] then
								puller = "|c" .. Skada.classcolors[class].colorStr .. owner.name .. "|r (" .. PET .. ")"
							else
								puller = owner.name .. " (" .. PET .. ")"
							end
						elseif srcName then
							local class = select(2, UnitClass(srcName))
							if class and Skada.classcolors[class] then
								puller = "|c" .. Skada.classcolors[class].colorStr .. srcName .. "|r"
							else
								puller = srcName
							end
						end
					end

					if puller then
						local link = (eventtype == "SWING_DAMAGE") and GetSpellLink(6603) or GetSpellLink(select(1, ...)) or GetSpellInfo(select(1, ...))
						pull_timer = NewTimer(0.5, WhoPulled)
						pull_timer.HitBy = format(L["|cffffff00First Hit|r: %s from %s"], link or "", puller)
					end
				end
			end

			self.hooks[Skada].CombatLogEvent(Skada, nil, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		end
	end

	function mod:EndSegment()
		if pull_timer then
			pull_timer:Cancel()
			pull_timer = nil
		end
	end

	---------------------------------------------------------------------------
	-- DPSLink filter

	do
		local find, gsub, split, tonumber = string.find, string.gsub, string.split, tonumber
		local GetTime = GetTime
		local ShowUIPanel = ShowUIPanel
		local ItemRefTooltip = ItemRefTooltip

		local firstlines = {
			"^Details!: (.*)$", -- Details!
			"^Skada report on (.*) for (.*), (.*) to (.*):$", -- Skada enUS
			"^(.*) - (.*)의 Skada 보고, (.*) ~ (.*):$", -- Skada koKR
			"^Skada报告(.*)的(.*), (.*)到(.*):$", -- Skada zhCN
			"^(.*)的報告來自(.*)，從(.*)到(.*)：$", -- Skada zhTW
			"^Skada: (.*) for (.*), (.*) - (.*):$", -- Better Skada support player details
			"^Recount - (.*)$", -- Recount
			"^Skada: (.*) for (.*):$", -- Skada enUS
			"^Skada: (.*) für (.*):$", -- Skada deDE
			"^Skada: (.*) pour (.*):$", -- Skada frFR
			"^Skada: (.*) для (.*):$", -- Skada ruRU
			"^Отчёт Skada: (.*), с (.*):$", -- Skada ruRU
			"^Skada: (.*) por (.*):$", -- Skada esES/ptBR
			"^(.*) 의 Skada 보고 (.*):$", -- Skada koKR
			"^Skada报告(.*)的(.*):$", -- Skada zhCN
			"^Skada:(.*)來自(.*):$", -- Skada zhTW
			"^(.*) Done for (.*)$", -- TinyDPS enUS
			"^(.*) für (.*)$", -- TinyDPS deDE
			"데미지량 -(.*)$", -- TinyDPS koKR
			"힐량 -(.*)$", -- TinyDPS koKR
			"Урон:(.*)$", -- TinyDPS ruRU
			"Исцеление:(.*)$", -- TinyDPS ruRU
			"^# (.*) - (.*)$", -- Numeration
			"alDamageMeter : (.*)$", -- alDamageMeter
			"^Details! Report for (.*)$" -- Details!
		}

		local nextlines = {
			"^(%d+)%. (.*)$", -- Recount, Details! and Skada
			"^ (%d+). (.*)$", -- Skada (default)
			"^(.*)%s%s%s(.*)$", -- Additional Skada details
			"^.*%%%)$", --Skada player details
			"^[+-]%d+.%d", -- Numeration deathlog details
			"^(%d+). (.*):(.*)(%d+)(.*)(%d+)%%(.*)%((%d+)%)$" -- TinyDPS
		}

		channelEvents = {
			"CHAT_MSG_CHANNEL",
			"CHAT_MSG_GUILD",
			"CHAT_MSG_OFFICER",
			"CHAT_MSG_PARTY",
			"CHAT_MSG_PARTY_LEADER",
			"CHAT_MSG_RAID",
			"CHAT_MSG_RAID_LEADER",
			"CHAT_MSG_SAY",
			"CHAT_MSG_WHISPER",
			"CHAT_MSG_WHISPER_INFORM",
			"CHAT_MSG_BN_WHISPER",
			"CHAT_MSG_BN_WHISPER_INFORM",
			"CHAT_MSG_YELL"
		}

		local meters = {}

		function mod:FilterLine(event, source, msg, ...)
			for i, line in ipairs(firstlines) do
				local newID = 0
				if msg:match(line) then
					local curtime = GetTime()
					if find(msg, "|cff(.+)|r") then
						msg = gsub(msg, "|cff%w%w%w%w%w%w", "")
						msg = gsub(msg, "|r", "")
					end
					for id, meter in ipairs(meters) do
						local elapsed = curtime - meter.time
						if meter.src == source and meter.evt == event and elapsed < 1 then
							newID = id
							return true, true, format("|HSKSP:%1$d|h|cffffff00[%2$s]|r|h", newID or 0, msg or "nil")
						end
					end
					tinsert(meters, {src = source, evt = event, time = curtime, data = {}, title = msg})
					for id, meter in ipairs(meters) do
						if meter.src == source and meter.evt == event and meter.time == curtime then
							newID = id
						end
					end
					return true, true, format("|HSKSP:%1$d|h|cffffff00[%2$s]|r|h", newID or 0, msg or "nil")
				end
			end

			for _, line in ipairs(nextlines) do
				if msg:match(line) then
					local curtime = GetTime()
					for _, meter in ipairs(meters) do
						local elapsed = curtime - meter.time
						if meter.src == source and meter.evt == event and elapsed < 1 then
							local toInsert = true
							for _, b in ipairs(meter.data) do
								if b == msg then
									toInsert = false
								end
							end
							if toInsert then
								tinsert(meter.data, msg)
							end
							return true, false, nil
						end
					end
				end
			end

			return false, false, nil
		end

		function mod:ParseChatEvent(event, msg, sender, ...)
			local ismeter, isfirstline, message = mod:FilterLine(event, sender, msg)
			if ismeter then
				if isfirstline then
					return false, message, sender, ...
				else
					return true
				end
			end
		end

		function mod:ParseLink(link, text, button, chatframe)
			local linktype, id = split(":", link)
			if linktype == "SKSP" then
				local meterid = tonumber(id)
				ShowUIPanel(ItemRefTooltip)
				if not ItemRefTooltip:IsShown() then
					ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
				end
				ItemRefTooltip:ClearLines()
				ItemRefTooltip:AddLine(meters[meterid].title)
				ItemRefTooltip:AddLine(format(L["Reported by: %s"], meters[meterid].src))
				ItemRefTooltip:AddLine(" ")
				for _, line in ipairs(meters[meterid].data) do
					ItemRefTooltip:AddLine(line, 1, 1, 1)
				end
				ItemRefTooltip:Show()
			else
				return mod.hooks.SetItemRef(link, text, button, chatframe)
			end
		end
	end

	---------------------------------------------------------------------------
	-- CombatLog Fix

	do
		local setmetatable, rawset, rawget = setmetatable, rawset, rawget
		local GetTime, CombatLogClearEntries, CombatLogGetNumEntries = GetTime, CombatLogClearEntries, CombatLogGetNumEntries

		local frame, zonetype, throttle
		local playerspells = setmetatable({}, {__index = function(t, name)
			local cost = select(4, GetSpellInfo(name))
			rawset(t, name, not (not (cost and cost > 0)))
			return rawget(t, name)
		end})

		local function OnUpdate(self, elapsed)
			self.timeout = (self.timeout or 0) - elapsed
			if self.timeout > 0 then return end
			self:Hide()

			-- was the last combat event within a second of cast succeeding?
			if self.lastEvent and (GetTime() - self.lastEvent) <= 1 then return end

			if not throttle or throttle < GetTime() then
				Skada:Debug(format("%d filtered/%d events found. Cleared combat log, as it broke.", CombatLogGetNumEntries(), CombatLogGetNumEntries(true)))
				throttle = GetTime() + 60
			end

			Skada:Debug("CombatLogClearEntries: Tweaks")
			After(0.1, CombatLogClearEntries)
		end

		local function OnEvent(self, event, ...)
			if event == "COMBAT_LOG_EVENT_UNFILTERED" then
				self.lastEvent = ... -- timestamp
			elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
				local unit, spellname = ...
				if unit == "player" and spellname and playerspells[spellname] then
					self.timeout = 0.5
					self:Show()
				end
			elseif event == "ZONE_CHANGED_NEW_AREA" then
				local zt = select(2, IsInInstance())
				if zonetype and zt ~= zonetype then
					After(0.5, CombatLogClearEntries)
				end
				zonetype = zt
			end
		end

		function mod:COMBAT_PLAYER_ENTER()
			if Skada.db.profile.combatlogfix then
				After(0.5, CombatLogClearEntries)
			end
		end

		function mod:CombatLogFix()
			if Skada.db.profile.combatlogfix and not frame then
				frame = CreateFrame("Frame")
				frame:SetScript("OnUpdate", OnUpdate)
				frame:SetScript("OnEvent", OnEvent)
				frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
				frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
				frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
				frame:Hide()

				Skada.RegisterCallback(self, "COMBAT_PLAYER_ENTER")
			elseif not Skada.db.profile.combatlogfix and frame then
				frame:UnregisterAllEvents()
				frame:SetScript("OnUpdate", nil)
				frame:SetScript("OnEvent", nil)
				frame = nil

				Skada.UnregisterCallback(self, "COMBAT_PLAYER_ENTER")
			end
		end
	end

	---------------------------------------------------------------------------

	function mod:OnInitialize()
		-- first hit.
		if Skada.db.profile.firsthit == nil then
			Skada.db.profile.firsthit = true
		end
		-- smart stop & duration
		if Skada.db.profile.smartstop == nil then
			Skada.db.profile.smartstop = false
		end
		if Skada.db.profile.smartwait == nil then
			Skada.db.profile.smartwait = 5
		end
		-- combatlog fix
		if Skada.db.profile.combatlogfix == nil then
			Skada.db.profile.combatlogfix = true
		end

		-- old spamage module
		if type(Skada.db.profile.spamage) == "table" or Skada.db.profile.spamage == nil then
			Skada.db.profile.spamage = false
		end

		-- Fury of Frostmourne
		fofrostmourne = fofrostmourne or GetSpellInfo(72351)

		-- options.
		Skada.options.args.Tweaks = {
			type = "group",
			name = L["Tweaks"],
			desc = format(L["Options for %s."], L["Tweaks"]),
			get = function(i)
				return Skada.db.profile[i[#i]]
			end,
			set = function(i, val)
				Skada.db.profile[i[#i]] = val
				mod:ApplySettings()
			end,
			order = 900,
			args = {
				firsthit = {
					type = "toggle",
					name = L["First hit"],
					desc = L["Prints a message of the first hit before combat.\nOnly works for boss encounters."],
					order = 10
				},
				moduleicons = {
					type = "toggle",
					name = L["Module Icons"],
					desc = L["Enable this if you want to show module icons on windows and menus."],
					order = 20
				},
				spamage = {
					type = "toggle",
					name = L["Filter DPS meters Spam"],
					desc = L["Suppresses chat messages from damage meters and provides single chat-link damage statistics in a popup."],
					order = 30
				},
				combatlogfix = {
					type = "toggle",
					name = L["Fix Combat Log"],
					desc = L["Keeps the combat log from breaking without munging it completely."],
					order = 40
				},
				fofrostmourne = {
					type = "toggle",
					name = fofrostmourne,
					desc = format(L["Enable this if you want to ignore |cffffbb00%s|r."], fofrostmourne),
					order = 50
				},
				smartsep = {
					type = "description",
					name = " ",
					order = 95,
					width = "full"
				},
				smartheader = {
					type = "header",
					name = L["Smart Stop"],
					order = 95.1
				},
				smartdesc = {
					type = "description",
					name = L["Automatically stops the current segment after the boss has died.\nUseful to avoid collecting data in case of a combat bug."],
					fontSize = "medium",
					order = 95.2,
					width = "full"
				},
				smartstop = {
					type = "toggle",
					name = L["Enable"],
					order = 95.3
				},
				smartwait = {
					type = "range",
					name = L["Duration"],
					desc = L["For how long Skada should wait before stopping the segment."],
					disabled = function()
						return not Skada.db.profile.smartstop
					end,
					min = 0,
					max = 10,
					step = 0.01,
					bigStep = 0.1,
					order = 95.4
				}
			}
		}
	end

	function mod:BossDefeated(event, set)
		if event == "COMBAT_BOSS_DEFEATED" and set and not set.stopped then
			After(Skada.db.profile.smartwait or 5, function()
				if not set.endtime then
					Skada:Print(L["Smart Stop"])
					Skada:StopSegment()
					Skada:RegisterEvent("PLAYER_REGEN_ENABLED")
				end
			end)
		end
	end

	function Skada:PLAYER_REGEN_ENABLED()
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		if self.current and self.current.stopped then
			self:EndSegment()
		end
	end

	function mod:ModuleIconsBar(_, bar, mode)
		if bar and mode and mode.metadata then
			bar.icon = mode.metadata.icon
		end
	end

	function mod:ModuleIconsMenu(_, info, mode)
		if info and mode and mode.metadata then
			info.icon = mode.metadata and mode.metadata.icon
			info.tCoordLeft = 0.065
			info.tCoordRight = 0.935
			info.tCoordTop = 0.065
			info.tCoordBottom = 0.935
			info.padding = 8
		end
	end

	function mod:ApplySettings()
		fofrostmourne = fofrostmourne or GetSpellInfo(72351)

		-- first hit or fury of frostmourne
		if (Skada.db.profile.firsthit or Skada.db.profile.fofrostmourne) then
			if not self:IsHooked(Skada, "CombatLogEvent") then
				self:RawHook(Skada, "CombatLogEvent", true)
			end
			if Skada.db.profile.firsthit and not self:IsHooked(Skada, "EndSegment") then
				self:SecureHook(Skada, "EndSegment")
			end
		else
			if self:IsHooked(Skada, "CombatLogEvent") then
				self:Unhook(Skada, "CombatLogEvent")
			end
			if self:IsHooked(Skada, "EndSegment") then
				self:EndSegment() -- remove timer
				self:Unhook(Skada, "EndSegment")
			end
		end

		-- combatlog fix
		self:CombatLogFix()

		-- smart stop
		if Skada.db.profile.smartstop then
			Skada.RegisterCallback(self, "COMBAT_BOSS_DEFEATED", "BossDefeated")
		else
			Skada.UnregisterCallback(self, "COMBAT_BOSS_DEFEATED")
		end

		-- module icons
		if Skada.db.profile.moduleicons then
			Skada.RegisterCallback(self, "SKADA_MODE_BAR", "ModuleIconsBar")
			Skada.RegisterCallback(self, "SKADA_MODE_MENU", "ModuleIconsMenu")
		else
			Skada.UnregisterCallback(self, "SKADA_MODE_BAR", "ModuleIconsBar")
			Skada.UnregisterCallback(self, "SKADA_MODE_MENU", "ModuleIconsMenu")
		end

		-- filter dps meters
		if Skada.db.profile.spamage then
			if not self:IsHooked("SetItemRef") then
				self:RawHook("SetItemRef", "ParseLink", true)
			end
			for _, e in ipairs(channelEvents) do
				ChatFrame_AddMessageEventFilter(e, self.ParseChatEvent)
			end
		elseif self:IsHooked("SetItemRef") then
			self:Unhook("SetItemRef")
			for _, e in ipairs(channelEvents) do
				ChatFrame_RemoveMessageEventFilter(e, self.ParseChatEvent)
			end
		end
	end

	function mod:OnEnable()
		self:ApplySettings()
	end

	function mod:OnDisable()
		self:UnhookAll()
		Skada.UnregisterAllCallbacks(self)
	end
end)