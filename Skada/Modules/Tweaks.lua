local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Tweaks", function(L, P, _, _, _, O)
	local mode = Skada:NewModule("Tweaks", "AceHook-3.0")

	local format = string.format
	local GetSpellInfo = Private.SpellInfo or GetSpellInfo
	local channel_events, fofrostmourne

	---------------------------------------------------------------------------
	-- OnCombatEvent Hook

	do
		local Skada_OnCombatEvent = Skada.OnCombatEvent
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

			return Skada_OnCombatEvent(self, args)
		end
	end

	---------------------------------------------------------------------------
	-- DPSLink filter

	do
		local find, gsub, split, tonumber = string.find, string.gsub, string.split, tonumber
		local ShowUIPanel, GetTime = ShowUIPanel, GetTime
		local ItemRefTooltip = ItemRefTooltip

		local firstlines = {
			-- Skada
			"^Sh?kada report on (.+) for (.+), (.+) to (.+):$", -- enUS
			"^Sh?kada: (.+) for (.+):$", -- enUS
			"^Sh?kada: (.+) für (.+):$", -- deDE
			"^Sh?kada: (.+) por (.+):$", -- esES/ptBR
			"^Sh?kada: (.+) pour (.+):$", -- frFR
			"^Sh?kada: (.+) для (.+):$", -- ruRU
			"^Sh?kada:(.+)來自(.+):$", -- zhTW
			"^Sh?kada报告(.+)的(.+), (.+)到(.+):$", -- zhCN
			"^Sh?kada报告(.+)的(.+):$", -- zhCN
			"^(.+) - (.+)의 Sh?kada 보고, (.+) ~ (.+):$", -- koKR
			"^(.+)的報告來自(.+)，從(.+)到(.+)：$", -- zhTW
			"^Отчёт Sh?kada: (.+), с (.+):$", -- ruRU
			"^(.+) 의 Sh?kada 보고 (.+):$", -- koKR
			"^Sh?kada: (.+) for (.+), (.+) - (.+):$", -- Better Skada support player details
			-- TinyDPS
			"^(.+) Done for (.+)$", -- TinyDPS enUS
			"^(.+) für (.+)$", -- TinyDPS deDE
			"데미지량 -(.+)$", -- TinyDPS koKR
			"힐량 -(.+)$", -- TinyDPS koKR
			"Урон:(.+)$", -- TinyDPS ruRU
			"Исцеление:(.+)$", -- TinyDPS ruRU
			-- Other damage meters.
			"^Details!: (.+)$", -- Details!
			"^Details! Report for (.+)$", -- Details!
			"^Recount - (.+)$", -- Recount
			"^# (.+) - (.+)$", -- Numeration
			"alDamageMeter : (.+)$" -- alDamageMeter
		}

		local nextlines = {
			"^(%d+)%. (.+)$", -- Recount, Details! and Skada
			"^ (%d+). (.+)$", -- Skada (default)
			"^[+-]?%d+..+$", -- Skada (deaths) (credits: @ridepad)
			"^(.+)%s%s%s(.+)$", -- Additional Skada details
			"^.*%%%)$", --Skada player details
			"^[+-]%d+.%d", -- Numeration deathlog details
			"^(%d+). (.+):(.+)(%d+)(.+)(%d+)%%(.+)%((%d+)%)$" -- TinyDPS
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

		function Private.ParseChatEvent(_, event, msg, sender, ...)
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
				if self.timer then
					Skada:CancelTimer(self.timer, true)
					self.timer = nil
				end
			end
		end

		function mode:CombatEnter()
			if not P.combatlogfix then return end
			frame.timer = frame.timer or Skada:ScheduleTimer(CombatLogClearEntries, 0.1)
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

	function mode:ApplySettings()
		-- fury of frostmourne
		fofrostmourne = fofrostmourne or GetSpellInfo(72350)

		-- filter dps meters
		if P.spamage then
			if not self:IsHooked("SetItemRef") then
				self:RawHook("SetItemRef", "ParseLink", true)
			end
			for i = 1, #channel_events do
				ChatFrame_AddMessageEventFilter(channel_events[i], Private.ParseChatEvent)
			end
		elseif self:IsHooked("SetItemRef") then
			self:Unhook("SetItemRef")
			for i = 1, #channel_events do
				ChatFrame_RemoveMessageEventFilter(channel_events[i], Private.ParseChatEvent)
			end
		end

		-- combatlog fix
		self:CombatLogFix()
	end
	mode.OnEnable = mode.ApplySettings

	function mode:OnDisable()
		self:UnhookAll()
		Skada.UnregisterAllCallbacks(self)
		Skada.UnregisterAllMessages(self)
	end

	function mode:OnInitialize()
		local function set_value(i, val)
			P[i[#i]] = val
			mode:ApplySettings()
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

		local gen_opt = O.tweaks.args.general -- Tweaks > General
		local adv_opt = O.tweaks.args.advanced -- Tweaks > Advanced

		-- options.
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
end)
