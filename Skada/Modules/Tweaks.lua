local Skada = Skada
Skada:AddLoadableModule("Tweaks", function(L)
	if Skada:IsDisabled("Tweaks") then return end

	local mod = Skada:NewModule(L["Tweaks"], "AceHook-3.0")

	local ipairs, select, band, format = ipairs, select, bit.band, string.format
	local UnitExists, UnitName, UnitClass = UnitExists, UnitName, UnitClass
	local GetSpellInfo = Skada.GetSpellInfo or GetSpellInfo
	local GetSpellLink = Skada.GetSpellLink or GetSpellLink
	local GetTime = GetTime

	local BITMASK_GROUP = Skada.BITMASK_GROUP
	if not BITMASK_GROUP then
		local COMBATLOG_OBJECT_AFFILIATION_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
		local COMBATLOG_OBJECT_AFFILIATION_PARTY = COMBATLOG_OBJECT_AFFILIATION_PARTY or 0x00000002
		local COMBATLOG_OBJECT_AFFILIATION_RAID = COMBATLOG_OBJECT_AFFILIATION_RAID or 0x00000004
		BITMASK_GROUP = COMBATLOG_OBJECT_AFFILIATION_MINE + COMBATLOG_OBJECT_AFFILIATION_PARTY + COMBATLOG_OBJECT_AFFILIATION_RAID
		Skada.BITMASK_GROUP = BITMASK_GROUP
	end

	local channel_events, considerFoF, fofrostmourne

	local ignoredspells = {
		[1130] = true, -- Hunter's Mark (rank 1)
		[14323] = true, -- Hunter's Mark (rank 2)
		[14324] = true, -- Hunter's Mark (rank 3)
		[14325] = true, -- Hunter's Mark (rank 4)
		[53338] = true, -- Hunter's Mark (rank 5)
		[56191] = true, -- Shadow Jade Focusing Lens
		[60122] = true -- Baby Spice
	}

	---------------------------------------------------------------------------
	-- CombatLogEvent Hook

	do
		local MAX_BOSS_FRAMES = MAX_BOSS_FRAMES or 5
		local T = Skada.Table
		local firsthit = T.get("Skada_FirstHit")
		local hitformats = {"%s (%s)", "%s (|c%s%s|r)", "|c%s%s|r", "|c%s%s|r (%s)"}

		-- thank you Details!
		local Skada_CombatLogEvent = Skada.CombatLogEvent
		local trigger_events = {
			RANGE_DAMAGE = true,
			SPELL_BUILDING_DAMAGE = true,
			SPELL_DAMAGE = true,
			SWING_DAMAGE = true
		}

		local function WhoPulled(hitline)
			-- first hit
			hitline = hitline or L["|cffffbb00First Hit|r: *?*"]

			-- firt boss target
			local targetline
			for i = 1, MAX_BOSS_FRAMES do
				local boss = format("boss%d", i)
				if not UnitExists(boss) then break end

				local target = UnitName(boss .. "target")
				if target then
					local class = select(2, UnitClass(boss .. "target"))

					if class and Skada.classcolors[class] then
						target = "|c" .. Skada.classcolors[class].colorStr .. target .. "|r"
					end
					targetline = format(L["|cffffbb00Boss First Target|r: %s (%s)"], target, UnitName(boss) or L.Unknown)
					break -- no need
				end
			end

			return hitline, targetline
		end

		function Skada:CombatLogEvent(_, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
			-- The Lich King fight & Fury of Frostmourne
			if considerFoF and (... == 72350 or select(2, ...) == fofrostmourne) then
				-- the segment should be flagged as success.
				if self.current and not self.current.success then
					self.current.success = true
					self:SendMessage("COMBAT_BOSS_DEFEATED", self.current)

					if self.tempsets then -- phases
						for _, set in ipairs(self.tempsets) do
							set.success = true
							self:SendMessage("COMBAT_BOSS_DEFEATED", set)
						end
					end
				end
				-- ignore the spell
				if self.db.profile.fofrostmourne then return end
			end

			-- first hit
			if
				self.db.profile.firsthit and
				not self.current and
				firsthit.hitline == nil and
				(trigger_events[eventtype] or eventtype == "SPELL_CAST_SUCCESS") and
				srcName and
				dstName and
				not ignoredspells[(select(1, ...))]
			then
				if
					(band(srcFlags, BITMASK_GROUP) ~= 0 and self:IsBoss(dstGUID, dstName)) or
					(band(dstFlags, BITMASK_GROUP) ~= 0 and self:IsBoss(srcGUID, dstName))
				then
					local output

					-- close distance?
					if self:IsBoss(srcGUID, dstName) then
						if self:IsPet(dstGUID, dstFlags) then
							output = format(hitformats[1], srcName, dstName or L.Unknown)
						elseif dstName then
							local class = select(2, UnitClass(dstName))
							if class and self.classcolors[class] then
								output = format(hitformats[2], srcName, self.classcolors[class].colorStr, dstName)
							else
								output = format(hitformats[1], srcName, dstName)
							end
						else
							output = srcName
						end
					else
						local owner = self:GetPetOwner(srcGUID)
						if owner then
							local class = select(2, UnitClass(owner.name))
							if class and self.classcolors[class] then
								output = format(hitformats[4], self.classcolors[class].colorStr, owner.name, PET)
							else
								output = format(hitformats[1], owner.name, PET)
							end
						elseif srcName then
							local class = select(2, UnitClass(srcName))
							if class and self.classcolors[class] then
								output = format(hitformats[3], self.classcolors[class].colorStr, srcName)
							else
								output = srcName
							end
						end
					end

					if output then
						local link = (eventtype == "SWING_DAMAGE") and GetSpellLink(6603) or (GetSpellLink((select(1, ...))) or GetSpellInfo((select(1, ...))))
						firsthit.hitline, firsthit.targetline = WhoPulled(format(L["|cffffff00First Hit|r: %s from %s"], link or "", output))
					end
				end
			end

			-- use the original function
			Skada_CombatLogEvent(self, nil, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		end

		function mod:PrintFirstHit()
			if firsthit.hitline then
				Skada:Print(firsthit.hitline)
				if firsthit.targetline then
					Skada:Print(firsthit.targetline)
				end
				Skada:Debug("First Hit: Printed!")
			end
		end

		function mod:ClearFirstHit()
			if firsthit.hitline then
				T.free("Skada_FirstHit", firsthit)
				Skada:Debug("First Hit: Cleared!")
			end
		end
	end

	---------------------------------------------------------------------------
	-- DPSLink filter

	do
		local find, gsub, split, tonumber = string.find, string.gsub, string.split, tonumber
		local ShowUIPanel = ShowUIPanel
		local ItemRefTooltip = ItemRefTooltip

		local firstlines = {
			"^Details!: (.-)$", -- Details!
			"^Skada report on (.-) for (.-), (.-) to (.-):$", -- Skada enUS
			"^(.-) - (.-)의 Skada 보고, (.-) ~ (.-):$", -- Skada koKR
			"^Skada报告(.-)的(.-), (.-)到(.-):$", -- Skada zhCN
			"^(.-)的報告來自(.-)，從(.-)到(.-)：$", -- Skada zhTW
			"^Skada: (.-) for (.-), (.-) - (.-):$", -- Better Skada support player details
			"^Recount - (.-)$", -- Recount
			"^Skada: (.-) for (.-):$", -- Skada enUS
			"^Skada: (.-) für (.-):$", -- Skada deDE
			"^Skada: (.-) pour (.-):$", -- Skada frFR
			"^Skada: (.-) для (.-):$", -- Skada ruRU
			"^Отчёт Skada: (.-), с (.-):$", -- Skada ruRU
			"^Skada: (.-) por (.-):$", -- Skada esES/ptBR
			"^(.-) 의 Skada 보고 (.-):$", -- Skada koKR
			"^Skada报告(.-)的(.-):$", -- Skada zhCN
			"^Skada:(.-)來自(.-):$", -- Skada zhTW
			"^(.-) Done for (.-)$", -- TinyDPS enUS
			"^(.-) für (.-)$", -- TinyDPS deDE
			"데미지량 -(.-)$", -- TinyDPS koKR
			"힐량 -(.-)$", -- TinyDPS koKR
			"Урон:(.-)$", -- TinyDPS ruRU
			"Исцеление:(.-)$", -- TinyDPS ruRU
			"^# (.-) - (.-)$", -- Numeration
			"alDamageMeter : (.-)$", -- alDamageMeter
			"^Details! Report for (.-)$" -- Details!
		}

		local nextlines = {
			"^(%d+)%. (.-)$", -- Recount, Details! and Skada
			"^ (%d+). (.-)$", -- Skada (default)
			"^(.-)%s%s%s(.-)$", -- Additional Skada details
			"^.*%%%)$", --Skada player details
			"^[+-]%d+.%d", -- Numeration deathlog details
			"^(%d+). (.-):(.-)(%d+)(.-)(%d+)%%(.-)%((%d+)%)$" -- TinyDPS
		}

		channel_events = {
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
					meters[#meters + 1] = {src = source, evt = event, time = curtime, data = {}, title = msg}
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
								meter.data[#meter.data + 1] = msg
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
		local CombatLogClearEntries, CombatLogGetNumEntries = CombatLogClearEntries, CombatLogGetNumEntries
		local frame, playerspells

		local function AggressiveOnUpdate(self, elapsed)
			self.timeout = self.timeout + elapsed
			if self.timeout >= 2 then
				CombatLogClearEntries()
				self.timeout = 0
			end
		end

		local function ConservativeOnUpdate(self, elapsed)
			self.timeout = (self.timeout or 0) - elapsed
			if self.timeout > 0 then return end
			self:Hide()

			-- was the last combat event within a second of cast succeeding?
			if self.lastEvent and (GetTime() - self.lastEvent) <= 1 then return end

			if Skada.db.profile.combatlogfixverbose then
				if not self.throttle or self.throttle < GetTime() then
					Skada:Print(format(
						L["%d filtered / %d events found. Cleared combat log, as it broke."],
						CombatLogGetNumEntries(),
						CombatLogGetNumEntries(true)
					))
					self.throttle = GetTime() + 60
				end
			elseif self.throttle then
				self.throttle = nil
			end

			Skada:ScheduleTimer(CombatLogClearEntries, 0.1)
		end

		local function OnEvent(self, event, unit, spellname)
			if event == "COMBAT_LOG_EVENT_UNFILTERED" then
				self.lastEvent = unit -- timestamp
			elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
				if unit == "player" and spellname and playerspells[spellname] then
					self.timeout = 0.5
					self:Show()
				end
			elseif event == "ZONE_CHANGED_NEW_AREA" then
				local zt = select(2, IsInInstance())
				if self.zonetype and zt ~= self.zonetype then
					Skada:ScheduleTimer(CombatLogClearEntries, 0.01)
				end
				self.zonetype = zt
			end
		end

		function mod:COMBAT_PLAYER_ENTER()
			if Skada.db.profile.combatlogfix then
				Skada:ScheduleTimer(CombatLogClearEntries, 0.01)
			end
		end

		function mod:CombatLogFix()
			if Skada.db.profile.combatlogfix then
				frame = frame or CreateFrame("Frame")
				if Skada.db.profile.combatlogfixalt then
					frame:UnregisterAllEvents()
					frame.timeout = 0
					frame:SetScript("OnUpdate", AggressiveOnUpdate)
					frame:SetScript("OnEvent", nil)
					frame:Show()
				else
					-- construct player's spells
					if playerspells == nil then
						playerspells = setmetatable({}, {__index = function(t, name)
							local cost = select(4, GetSpellInfo(name))
							rawset(t, name, not (not (cost and cost > 0)))
							return rawget(t, name)
						end})
					end

					frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
					frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
					frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
					frame.timeout = 0
					frame:SetScript("OnUpdate", ConservativeOnUpdate)
					frame:SetScript("OnEvent", OnEvent)
					frame:Hide()
				end

				Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER")
			else
				if frame then
					frame:UnregisterAllEvents()
					frame:SetScript("OnUpdate", nil)
					frame:SetScript("OnEvent", nil)
					frame:Hide()
					frame = nil
				end
				Skada.UnregisterMessage(self, "COMBAT_PLAYER_ENTER")
			end
		end
	end

	---------------------------------------------------------------------------

	do
		local function SetValue(i, val)
			Skada.db.profile[i[#i]] = val
			mod:ApplySettings()
		end

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
				Skada.db.profile.smartwait = 3
			end
			-- combatlog fix
			if Skada.db.profile.combatlogfix == nil then
				Skada.db.profile.combatlogfix = true
				Skada.db.profile.combatlogfixverbose = false
				Skada.db.profile.combatlogfixalt = false
			end

			-- old spamage module
			if type(Skada.db.profile.spamage) == "table" or Skada.db.profile.spamage == nil then
				Skada.db.profile.spamage = false
			end

			-- Fury of Frostmourne
			fofrostmourne = fofrostmourne or GetSpellInfo(72351)

			-- options.
			Skada.options.args.tweaks.args.general.args.firsthit = {
				type = "toggle",
				name = L["First hit"],
				desc = L["Prints a message of the first hit before combat.\nOnly works for boss encounters."],
				set = SetValue,
				order = 10
			}
			Skada.options.args.tweaks.args.general.args.moduleicons = {
				type = "toggle",
				name = L["Modes Icons"],
				desc = L["Show modes icons on bars and menus."],
				set = SetValue,
				order = 20
			}
			Skada.options.args.tweaks.args.general.args.spamage = {
				type = "toggle",
				name = L["Filter DPS meters Spam"],
				desc = L["Suppresses chat messages from damage meters and provides single chat-link damage statistics in a popup."],
				set = SetValue,
				order = 30
			}
			Skada.options.args.tweaks.args.general.args.fofrostmourne = {
				type = "toggle",
				name = fofrostmourne,
				desc = format(L["Enable this if you want to ignore |cffffbb00%s|r."], fofrostmourne),
				hidden = Skada.Ascension,
				set = SetValue,
				order = 40
			}

			Skada.options.args.tweaks.args.advanced.args.smarthalt = {
				type = "group",
				name = L["Smart Stop"],
				desc = format(L["Options for %s."], L["Smart Stop"]),
				set = SetValue,
				order = 10,
				args = {
					smartdesc = {
						type = "description",
						name = L["Automatically stops the current segment after the boss has died.\nUseful to avoid collecting data in case of a combat bug."],
						fontSize = "medium",
						order = 10,
						width = "full"
					},
					smartstop = {
						type = "toggle",
						name = L["Enable"],
						order = 20
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
						order = 30
					}
				}
			}

			Skada.options.args.tweaks.args.advanced.args.combatlog = {
				type = "group",
				name = L["Combat Log"],
				desc = format(L["Options for %s."], L["Combat Log"]),
				set = SetValue,
				order = 20,
				args = {
					desc = {
						type = "description",
						name = L["Keeps the combat log from breaking without munging it completely."],
						fontSize = "medium",
						order = 10,
						width = "full"
					},
					combatlogfix = {
						type = "toggle",
						name = L["Enable"],
						order = 20
					},
					combatlogfixalt = {
						type = "toggle",
						name = L["Aggressive Mode"],
						desc = L["Constantly clear the combat log instead of only when it breaks."],
						disabled = function()
							return not Skada.db.profile.combatlogfix
						end,
						order = 30
					},
					combatlogfixverbose = {
						type = "toggle",
						name = L["Verbose Mode"],
						desc = format(L["Enable verbose mode for %s."], L["Combat Log"]),
						disabled = function()
							return Skada.db.profile.combatlogfixalt or not Skada.db.profile.combatlogfix
						end,
						order = 40
					}
				}
			}
		end
	end

	---------------------------------------------------------------------------
	-- Smart stop

	do
		-- list of creature IDs to be ignored
		local ignoredBosses = {
			[37217] = true, -- Precious
			[37025] = true -- Stinky
		}

		function mod:BossDefeated(_, set)
			if set and not set.stopped and set.gotboss and not ignoredBosses[set.gotboss] then
				Skada:ScheduleTimer(function()
					if not set.endtime then
						Skada:StopSegment(L["Smart Stop"])
					end
				end,
				Skada.db.profile.smartwait or 3)
			end
		end
	end

	function mod:ApplySettings()
		-- First Hit!
		if Skada.db.profile.firsthit then
			Skada.RegisterMessage(self, "COMBAT_ENCOUNTER_START", "PrintFirstHit")
			Skada.RegisterMessage(self, "COMBAT_ENCOUNTER_END", "ClearFirstHit")
		else
			Skada.UnregisterMessage(self, "COMBAT_ENCOUNTER_START")
			Skada.UnregisterMessage(self, "COMBAT_ENCOUNTER_END")
		end

		-- fury of frostmourne
		fofrostmourne = fofrostmourne or GetSpellInfo(72351)
		considerFoF = not (Skada.Ascension or Skada.AscensionCoA)

		-- smart stop
		if Skada.db.profile.smartstop then
			Skada.RegisterMessage(self, "COMBAT_BOSS_DEFEATED", "BossDefeated")
		else
			Skada.UnregisterMessage(self, "COMBAT_BOSS_DEFEATED")
		end

		-- filter dps meters
		if Skada.db.profile.spamage then
			if not self:IsHooked("SetItemRef") then
				self:RawHook("SetItemRef", "ParseLink", true)
			end
			for _, e in ipairs(channel_events) do
				ChatFrame_AddMessageEventFilter(e, self.ParseChatEvent)
			end
		elseif self:IsHooked("SetItemRef") then
			self:Unhook("SetItemRef")
			for _, e in ipairs(channel_events) do
				ChatFrame_RemoveMessageEventFilter(e, self.ParseChatEvent)
			end
		end

		-- combatlog fix
		self:CombatLogFix()
	end

	function mod:OnEnable()
		self:ApplySettings()
	end

	function mod:OnDisable()
		self:UnhookAll()
		Skada.UnregisterAllCallbacks(self)
		Skada.UnregisterAllMessages(self)
	end
end)