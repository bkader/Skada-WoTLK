local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Tweaks", function(L, P)
	local mode = Skada:NewModule("Tweaks", "AceHook-3.0")

	local format, uformat = string.format, Private.uformat
	local UnitClass, GetTime = UnitClass, GetTime
	local GetSpellInfo = Private.spell_info or GetSpellInfo
	local GetSpellLink = Private.spell_link or GetSpellLink
	local TempTable, classcolors = Private.TempTable, Skada.classcolors

	local channel_events, fofrostmourne

	---------------------------------------------------------------------------
	-- CombatLogEvent Hook

	do
		local BITMASK_GROUP = Private.BITMASK_GROUP or 0x00000007
		local MAX_BOSS_FRAMES = MAX_BOSS_FRAMES or 5
		local firsthit_fmt = {"%s (%s)", "%s (\124c%s%s\124r)", "\124c%s%s\124r", "\124c%s%s\124r (%s)"}
		local is_pet = Private.is_pet
		local firsthit, firsthittimer = nil, nil

		-- thank you Details!
		local trigger_events = {
			RANGE_DAMAGE = true,
			SPELL_BUILDING_DAMAGE = true,
			SPELL_CAST_SUCCESS = true,
			SPELL_DAMAGE = true,
			SWING_DAMAGE = true
		}

		local who_pulled
		do
			local UnitExists, UnitName = UnitExists, UnitName

			function who_pulled(hitline)
				-- first hit
				hitline = hitline or L["\124cffffbb00First Hit\124r: *?*"]

				-- firt boss target
				local targetline = nil
				local targettable = nil

				for i = 1, MAX_BOSS_FRAMES do
					local boss = format("boss%d", i)
					if not UnitExists(boss) then break end

					local bosstarget = format("boss%dtarget", i)
					local target = UnitName(bosstarget)
					if target then
						local _, class = UnitClass(bosstarget)
						if class and classcolors[class] then
							target = classcolors.format(class, target)
						end

						targettable = targettable or TempTable()
						targettable:insert(uformat("%s > %s", UnitName(boss), target))
					end
				end

				if targettable then
					targetline = format(L["\124cffffbb00Boss First Target\124r: %s"], targettable:concat(" \124\124 "))
					targettable = targettable:free()
				end

				return hitline, targetline
			end
		end

		local ignored_spells = Skada.ignored_spells.firsthit -- Edit Skada\Core\Tables.lua
		local function firsthit_check(args)
			-- src or dst must be in a group
			if not args:SourceInGroup() and not args:DestInGroup() then
				return
			end

			-- ignore spell?
			if args.event ~= "SWING_DAMAGE" and args.spellid and ignored_spells[args.spellid] then
				return
			end

			local output = nil -- initial output

			if Skada:IsBoss(args.srcGUID) then -- boss started?
				if is_pet(args.dstGUID, args.dstFlags) then
					output = uformat(firsthit_fmt[1], args.srcName, args.dstName)
				elseif args.dstName then
					local _, class = UnitClass(args.dstName)
					if class and classcolors[class] then
						output = format(firsthit_fmt[2], args.srcName, classcolors.str(class), args.dstName)
					else
						output = format(firsthit_fmt[1], args.srcName, args.dstName)
					end
				else
					output = args.srcName
				end
			elseif Skada:IsBoss(args.dstGUID) then -- a player started?
				local _, ownerName, ownerClass = Skada:GetPetOwner(args.srcGUID)
				if ownerName then
					if ownerClass then
						output = format(firsthit_fmt[4], classcolors.str(ownerClass), ownerName, L["PET"])
					else
						output = format(firsthit_fmt[1], ownerName, L["PET"])
					end
				elseif args.srcName then
					local _, class = UnitClass(args.srcName)
					if class and classcolors[class] then
						output = format(firsthit_fmt[3], classcolors.str(class), args.srcName)
					else
						output = args.srcName
					end
				end
			end

			if output then
				local spell = GetSpellLink(args.spellid) or args.spellname
				firsthit = firsthit or TempTable()
				firsthit.hitline, firsthit.targetline = who_pulled(uformat(L["\124cffffff00First Hit\124r: %s from %s"], spell, output))
				firsthit.checked = true -- once only
			end
		end

		function Skada:OnCombatEvent(args)
			-- The Lich King fight & Fury of Frostmourne
			if args.spellid == 72350 or args.spellname == fofrostmourne then
				if self.current and not self.current.success then
					self.current.success = true
					self:SendMessage("COMBAT_BOSS_DEFEATED", self.current)

					if self.tempsets then -- phases
						for i = 1, #self.tempsets do
							local set = self.tempsets[i]
							if set and not set.success then
								set.success = true
								self:SendMessage("COMBAT_BOSS_DEFEATED", set)
							end
						end
					end
				end
				-- ignore the spell
				if P.fofrostmourne then return end
			end

			-- first hit
			if P.firsthit and trigger_events[args.event] and args.srcName and args.dstName and (not firsthit or not firsthit.checked) then
				firsthit_check(args)
			end

			return self:CombatLogEvent(args)
		end

		do
			local function firsthit_print()
				firsthit.hitline, firsthit.targetline = who_pulled(firsthit.hitline)
				Skada:Print(firsthit.hitline)
				if firsthit.targetline then
					Skada:Print(firsthit.targetline)
				end
				Skada:Debug("First Hit: Printed!")
			end

			function mode:PrintFirstHit()
				if firsthit and firsthit.hitline and not firsthittimer then
					firsthittimer = Skada:ScheduleTimer(firsthit_print, 0.25)
				end
			end

			function mode:ClearFirstHit()
				firsthit = firsthit:free()
				if firsthittimer then
					Skada:CancelTimer(firsthittimer, true)
					firsthittimer = nil
				end
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

		local function filter_chat_line(event, source, msg, ...)
			for i = 1, #firstlines do
				local line = firstlines[i]
				if line and msg:match(line) then
					local newID = 0
					local curtime = GetTime()
					if find(msg, "\124cff(.+)\124r") then
						msg = gsub(msg, "\124cff%w%w%w%w%w%w", "")
						msg = gsub(msg, "\124r", "")
					end
					for j = 1, #meters do
						local meter = meters[j]
						local elapsed = meter and (curtime - meter.time) or 0
						if meter and meter.src == source and meter.evt == event and elapsed < 1 then
							newID = j
							return true, true, format("\124HSKSP:%1$d\124h\124cffffff00[%2$s]\124r\124h", newID or 0, msg or "nil")
						end
					end
					meters[#meters + 1] = {src = source, evt = event, time = curtime, data = {}, title = msg}
					for j = 1, #meters do
						local meter = meters[j]
						if meter and meter.src == source and meter.evt == event and meter.time == curtime then
							newID = j
						end
					end
					return true, true, format("\124HSKSP:%1$d\124h\124cffffff00[%2$s]\124r\124h", newID or 0, msg or "nil")
				end
			end

			for i = 1, #nextlines do
				local line = nextlines[i]
				if line and msg:match(line) then
					local curtime = GetTime()
					for j = 1, #meters do
						local meter = meters[j]
						local elapsed = meter and (curtime - meter.time) or 0
						if meter and meter.src == source and meter.evt == event and elapsed < 1 then
							local toInsert = true
							for k = 1, #meter.data do
								local b = meter.data[k]
								if b and b == msg then
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

		function Private.parse_chat_event(_, event, msg, sender, ...)
			local ismeter, isfirstline, message = filter_chat_line(event, sender, msg)
			if ismeter and isfirstline then
				return false, message, sender, ...
			elseif ismeter then
				return true
			end
		end

		function mode:ParseLink(link, text, button, chatframe)
			local linktype, id = split(":", link)
			if linktype ~= "SKSP" then
				return mode.hooks.SetItemRef(link, text, button, chatframe)
			end

			local meterid = tonumber(id)
			ShowUIPanel(ItemRefTooltip)
			if not ItemRefTooltip:IsShown() then
				ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
			end
			ItemRefTooltip:ClearLines()
			ItemRefTooltip:AddLine(meters[meterid].title)
			ItemRefTooltip:AddLine(format(L["Reported by: %s"], meters[meterid].src))
			ItemRefTooltip:AddLine(" ")
			for i = 1, #meters[meterid].data do
				local line = meters[meterid].data[i]
				if line then
					ItemRefTooltip:AddLine(line, 1, 1, 1)
				end
			end
			ItemRefTooltip:Show()
		end
	end

	---------------------------------------------------------------------------
	-- CombatLog Fix

	do
		local CombatLogClearEntries = CombatLogClearEntries
		local frame = nil

		local function frame_OnUpdate(self, elapsed)
			self.timeout = self.timeout + elapsed
			if self.timeout >= P.combatlogfixtime then
				CombatLogClearEntries()
				self.timeout = 0
			end
		end

		function mode:CombatEnter()
			if not P.combatlogfix then return end
			Skada:ScheduleTimer(CombatLogClearEntries, 0.1)
		end

		function mode:CombatLogFix()
			if P.combatlogfix then
				Skada.RegisterMessage(self, "COMBAT_PLAYER_ENTER", "CombatEnter")

				frame = frame or CreateFrame("Frame")
				frame.timeout = 0
				frame:SetScript("OnUpdate", frame_OnUpdate)
				frame:Show()
			else
				Skada.UnregisterMessage(self, "COMBAT_PLAYER_ENTER", "CombatEnter")
				if frame then
					frame:UnregisterAllEvents()
					frame:SetScript("OnUpdate", nil)
					frame:Hide()
				end
			end
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

		local function smart_stop(set)
			if set.endtime then return end
			Skada:StopSegment(L["Smart Stop"])
		end

		function mode:BossDefeated(_, set)
			if not set or set.stopped or not set.gotboss or ignoredBosses[set.gotboss] then return end
			Skada:ScheduleTimer(smart_stop, P.smartwait or 3, set)
		end
	end

	---------------------------------------------------------------------------

	function mode:ApplySettings()
		-- First Hit!
		if P.firsthit then
			Skada.RegisterMessage(self, "COMBAT_ENCOUNTER_START", "PrintFirstHit")
			Skada.RegisterMessage(self, "COMBAT_ENCOUNTER_END", "ClearFirstHit")
		else
			Skada.UnregisterMessage(self, "COMBAT_ENCOUNTER_START")
			Skada.UnregisterMessage(self, "COMBAT_ENCOUNTER_END")
		end

		-- fury of frostmourne
		fofrostmourne = fofrostmourne or GetSpellInfo(72350)

		-- smart stop
		if P.smartstop then
			Skada.RegisterMessage(self, "COMBAT_BOSS_DEFEATED", "BossDefeated")
		else
			Skada.UnregisterMessage(self, "COMBAT_BOSS_DEFEATED")
		end

		-- filter dps meters
		if P.spamage then
			if not self:IsHooked("SetItemRef") then
				self:RawHook("SetItemRef", "ParseLink", true)
			end
			for i = 1, #channel_events do
				ChatFrame_AddMessageEventFilter(channel_events[i], Private.parse_chat_event)
			end
		elseif self:IsHooked("SetItemRef") then
			self:Unhook("SetItemRef")
			for i = 1, #channel_events do
				ChatFrame_RemoveMessageEventFilter(channel_events[i], Private.parse_chat_event)
			end
		end

		-- combatlog fix
		self:CombatLogFix()
	end
	mode.OnEnable = mode.ApplySettings

	do
		local function set_value(i, val)
			P[i[#i]] = val
			mode:ApplySettings()
		end

		function mode:OnInitialize()
			-- class colors table
			classcolors = classcolors or Skada.classcolors

			-- first hit.
			if P.firsthit == nil then
				P.firsthit = true
			end
			-- smart stop & duration
			if P.smartwait == nil then
				P.smartwait = 3
			end
			-- combatlog fix
			if P.combatlogfixtime == nil then
				P.combatlogfixtime = 2
			end

			-- old unused data
			if P.combatlogfixalt then
				P.combatlogfixalt = nil
			end
			if type(P.spamage) == "table" then
				P.spamage = nil
			end

			-- Fury of Frostmourne
			fofrostmourne = fofrostmourne or GetSpellInfo(72350)

			local gen_opt = Skada.options.args.tweaks.args.general -- Tweaks > General
			local adv_opt = Skada.options.args.tweaks.args.advanced -- Tweaks > Advanced

			-- options.
			gen_opt.args.firsthit = {
				type = "toggle",
				name = L["First hit"],
				desc = L["opt_tweaks_firsthit_desc"],
				set = set_value,
				order = 10
			}
			gen_opt.args.moduleicons = {
				type = "toggle",
				name = L["Modes Icons"],
				desc = L["Show modes icons on bars and menus."],
				set = set_value,
				order = 20
			}
			gen_opt.args.spamage = {
				type = "toggle",
				name = L["Filter DPS meters Spam"],
				desc = L["opt_tweaks_spamage_desc"],
				set = set_value,
				order = 30
			}
			gen_opt.args.fofrostmourne = {
				type = "toggle",
				name = fofrostmourne,
				desc = format(L["Enable this if you want to ignore \124cffffbb00%s\124r."], fofrostmourne),
				set = set_value,
				order = 40
			}

			adv_opt.args.smarthalt = {
				type = "group",
				name = L["Smart Stop"],
				desc = format(L["Options for %s."], L["Smart Stop"]),
				set = set_value,
				order = 10,
				args = {
					smartdesc = {
						type = "description",
						name = L["opt_tweaks_smarthalt_desc"],
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
						desc = L["opt_tweaks_smartwait_desc"],
						disabled = function()
							return not P.smartstop
						end,
						min = 0,
						max = 10,
						step = 0.01,
						bigStep = 0.1,
						order = 30
					}
				}
			}

			adv_opt.args.combatlog = {
				type = "group",
				name = L["Combat Log"],
				desc = format(L["Options for %s."], L["Combat Log"]),
				set = set_value,
				order = 20,
				args = {
					desc = {
						type = "description",
						name = L["opt_tweaks_combatlogfix_desc"],
						fontSize = "medium",
						order = 10,
						width = "full"
					},
					combatlogfix = {
						type = "toggle",
						name = L["Enable"],
						order = 20
					},
					combatlogfixtime = {
						type = "range",
						name = L["Duration"],
						min = 2,
						max = 60,
						step = 1,
						disabled = function()
							return not P.combatlogfix
						end,
						order = 30
					}
				}
			}
		end
	end

	function mode:OnDisable()
		self:UnhookAll()
		Skada.UnregisterAllCallbacks(self)
		Skada.UnregisterAllMessages(self)
	end
end)
