--[[
Credit to: SpamageMeters
Authors: Wrug and Cybey
URL: https://www.curseforge.com/wow/addons/spamagemeters
]] --

assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Spamage", "Suppresses chat messages from damage meters and provides single chat-link damage statistics in a popup.", function(Skada, L)
	if Skada:IsDisabled("Spamage") then return end

	local mod = Skada:NewModule(L["Spamage"], "AceHook-3.0")

	-- cache frequently used global
	local find, format, gsub, split = string.find, string.format, string.gsub, string.split
	local tinsert = table.insert
	local ipairs, tonumber, GetTime = ipairs, tonumber, GetTime
	local ShowUIPanel = ShowUIPanel

	local ItemRefTooltip = ItemRefTooltip

	local valuestable = {[1] = L["Do Nothing"], [2] = L["Compress"], [3] = L["Suppress"]}

	local options = {
		type = "group",
		name = L["Spamage"],
		get = function(i)
			return Skada.db.profile.spamage[i[#i]]
		end,
		set = function(i, val)
			Skada.db.profile.spamage[i[#i]] = val
		end,
		args = {
			CHAT_MSG_RAID = {
				type = "select",
				name = L["Filter Raid"],
				desc = L["Selects the action to perform when encountering damage meter data in raid chat"],
				order = 1,
				values = valuestable
			},
			CHAT_MSG_PARTY = {
				type = "select",
				name = L["Filter Party"],
				desc = L["Selects the action to perform when encountering damage meter data in party chat"],
				order = 2,
				values = valuestable,
				set = function(_, val)
					Skada.db.profile.spamage.CHAT_MSG_PARTY = val
					Skada.db.profile.spamage.CHAT_MSG_PARTY_LEADER = val
				end
			},
			CHAT_MSG_GUILD = {
				type = "select",
				name = L["Filter Guild"],
				desc = L["Selects the action to perform when encountering damage meter data in guild chat"],
				order = 3,
				values = valuestable
			},
			CHAT_MSG_OFFICER = {
				type = "select",
				name = L["Filter Officer"],
				desc = L["Selects the action to perform when encountering damage meter data in officer chat"],
				order = 4,
				values = valuestable
			},
			CHAT_MSG_SAY = {
				type = "select",
				name = L["Filter Say"],
				desc = L["Selects the action to perform when encountering damage meter data in say chat"],
				order = 5,
				values = valuestable
			},
			CHAT_MSG_YELL = {
				type = "select",
				name = L["Filter Yell"],
				desc = L["Selects the action to perform when encountering damage meter data in yell chat"],
				order = 6,
				values = valuestable
			},
			CHAT_MSG_WHISPER = {
				type = "select",
				name = L["Filter Whisper"],
				desc = L["Selects the action to perform when encountering damage meter whisper"],
				order = 7,
				values = valuestable
			},
			CHAT_MSG_CHANNEL = {
				type = "select",
				name = L["Filter Custom Channels"],
				desc = L["Selects the action to perform when encountering damage meter data in custom channels"],
				order = 8,
				values = valuestable
			},
			captureDelay = {
				type = "range",
				name = L["Capture Delay"],
				desc = L['How many seconds the addon waits after "Skada: *" lines before it assumes spam burst is over. 1 seems to work in most cases'],
				order = 99,
				width = "double",
				min = 1,
				max = 5,
				step = 0.1
			}
		}
	}

	function mod:OnInitialize()
		-- we make sure to add default options if not set
		if not Skada.db.profile.spamage then
			Skada.db.profile.spamage = {
				CHAT_MSG_CHANNEL = 2,
				CHAT_MSG_GUILD = 2,
				CHAT_MSG_OFFICER = 2,
				CHAT_MSG_PARTY = 2,
				CHAT_MSG_PARTY_LEADER = 2,
				CHAT_MSG_RAID = 2,
				CHAT_MSG_RAID_LEADER = 2,
				CHAT_MSG_SAY = 2,
				CHAT_MSG_WHISPER = 2,
				CHAT_MSG_YELL = 2,
				captureDelay = 1.0
			}
		end

		-- we add module's options.
		Skada.options.args.modules.args.spamage = options
	end

	-- ================================================

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
		"^(%d+)%. (.*)$", -- Recount, Skada
		"^ (%d+). (.*)$", -- Skada
		"^(%d+). (.*)$", -- Recount, Details! and Skada
		"^(.*)  (.*)$", -- Additional Skada
		"^.*%%%)$", --Skada player details
		"^[+-]%d+.%d", -- Numeration deathlog details
		"^(%d+). (.*):(.*)(%d+)(.*)(%d+)%%(.*)%((%d+)%)$" -- TinyDPS
	}

	local events = {
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

	function mod:OnEnable()
		for _, e in ipairs(events) do
			ChatFrame_AddMessageEventFilter(e, self.ParseChatEvent)
		end
		self:RawHook("SetItemRef", "ParseLink", true)
	end

	function mod:OnDisable()
		Skada.db.profile.spamage = nil
		for _, e in ipairs(events) do
			ChatFrame_RemoveMessageEventFilter(e, self.ParseChatEvent)
		end
	end

	-- the real deal --

	function mod:FilterLine(event, source, msg, ...)
		for _, line in ipairs(nextlines) do
			if msg:match(line) then
				local curtime = GetTime()

				for _, meter in ipairs(meters) do
					local elapsed = curtime - meter.time

					if meter.src == source and meter.evt == event and elapsed < Skada.db.profile.spamage.captureDelay then
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

					if meter.src == source and meter.evt == event and elapsed < Skada.db.profile.spamage.captureDelay then
						newID = id
						return true, true, format("|HSKSP:%1$d|h|cFFFFFF00[%2$s]|r|h", newID or 0, msg or "nil")
					end
				end

				tinsert(meters, {src = source, evt = event, time = curtime, data = {}, title = msg})

				for id, meter in ipairs(meters) do
					if meter.src == source and meter.evt == event and meter.time == curtime then
						newID = id
					end
				end

				return true, true, format("|HSKSP:%1$d|h|cFFFFFF00[%2$s]|r|h", newID or 0, msg or "nil")
			end
		end

		return false, false, nil
	end

	function mod:ParseChatEvent(event, msg, sender, ...)
		if Skada.db.profile.spamage == nil then
			Skada.db.profile.spamage = {}
		end

		local hide = false
		for _, e in ipairs(events) do
			if event == e then
				if Skada.db.profile.spamage[event] and Skada.db.profile.spamage[event] > 1 then
					local ismeter, isfirstline, message = mod:FilterLine(event, sender, msg)
					if ismeter then
						if isfirstline then
							msg = message
						else
							hide = true
						end
					end
				end
				break
			end
		end

		if not hide then
			return false, msg, sender, ...
		end

		return true
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

			for _, line in ipairs(meters[meterid].data) do
				ItemRefTooltip:AddLine(line, 1, 1, 1)
			end

			ItemRefTooltip:Show()
		else
			return mod.hooks.SetItemRef(link, text, button, chatframe)
		end
	end
end)