assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Nickname", function(Skada, L)
	if Skada:IsDisabled("Nickname") then return end

	local mod = Skada:NewModule(L["Nickname"], "AceEvent-3.0", "AceHook-3.0")
	local Translit = LibStub("LibTranslit-1.0", true)

	local type, time = type, time
	local strlen, strfind, strgsub, format = string.len, string.find, string.gsub, string.format
	local UnitGUID, UnitName = UnitGUID, UnitName
	local NewTimer = Skada.NewTimer
	local CheckNickname

	-- modify this if you want to change the way nicknames are displayed
	local nicknameFormats = {[1] = "%1$s", [2] = "%2$s", [3] = "%1$s (%2$s)", [4] = "%2$s (%1$s)"}

	do
		local function trim(str)
			local from = str:match("^%s*()")
			return from > #str and "" or str:match(".*%S", from)
		end

		local function titlecase(first, rest)
			return first:upper() .. rest:lower()
		end

		local have_repeated = false
		local count_spaces = 0

		local function check_repeated(char)
			if char == "  " then
				have_repeated = true
			elseif strlen(char) > 2 then
				have_repeated = true
			elseif char == " " then
				count_spaces = count_spaces + 1
			end
		end

		function CheckNickname(name)
			if type(name) ~= "string" then
				return false, L["Nickname isn't a valid string."]
			end

			name = trim(name)

			local len = strlen(name)
			if len > 12 then
				return false, L["Your nickname is too long, max of 12 characters is allowed."]
			end

			local notallow = strfind(name, "[^a-zA-Z�������%s]")
			if notallow then
				return false, L["Only letters and two spaces are allowed."]
			end

			have_repeated = false
			count_spaces = 0
			strgsub(name, ".", "\0%0%0"):gsub("(.)%z%1", "%1"):gsub("%z.([^%z]+)", check_repeated)
			if count_spaces > 2 then
				have_repeated = true
			end
			if have_repeated then
				return false, L["You can't use the same letter three times consecutively, two spaces consecutively or more then two spaces."]
			end

			return true, name:gsub("(%a)([%w_']*)", titlecase)
		end
	end

	function mod:OnEvent(event)
		if self.sendCooldown > time() then
			if not self.sendTimer or self.sendTimer._cancelled then
				self.sendTimer = NewTimer(30, function() self:SendNickname() end)
			end
		else
			self:SendNickname()
		end
	end

	function mod:SendNickname(keepTimer)
		self:SetCacheTable()

		if not keepTimer then
			if self.sendTimer and not self.sendTimer._cancelled then
				self.sendTimer:Cancel()
			end
			self.sendTimer, self.sendCooldown = nil, time() + 29
		end

		Skada:SendComm(nil, nil, "Nickname", Skada.userGUID, Skada.db.profile.nickname)
		-- backward compatibility
		Skada:SendComm(nil, nil, "NicknameChange", Skada.userGUID, Skada.db.profile.nickname)
	end

	function mod:OnCommNickname(event, sender, guid, nickname)
		self:SetCacheTable()
		if Skada.db.profile.ignorenicknames then
			return
		end
		if sender and guid and guid ~= Skada.userGUID and nickname then
			self.db.cache[guid] = nickname
		end
	end

	function mod:OnInitialize()
		if Skada.db.profile.namedisplay == nil then
			Skada.db.profile.namedisplay = 2
		end

		Skada.options.args.modules.args.nickname = {
			type = "group",
			name = self.moduleName,
			desc = format(L["Options for %s."], self.moduleName),
			get = function(i)
				return Skada.db.profile[i[#i]]
			end,
			set = function(i, val)
				Skada.db.profile[i[#i]] = val
			end,
			args = {
				nickname = {
					type = "input",
					name = L["Nickname"],
					desc = L["Set a nickname for you.\nNicknames are sent to group members and Skada can use them instead of your character name."],
					order = 1,
					get = function()
						return Skada.db.profile.nickname or Skada.userName
					end,
					set = function(_, val)
						local okey, nickname = CheckNickname(val)
						if okey == true then
							Skada.db.profile.nickname = (nickname == "") and Skada.userName or nickname
							mod:SendNickname(true)
						else
							Skada:Print(nickname)
						end
					end
				},
				namedisplay = {
					type = "select",
					name = L["Name display"],
					desc = L["Choose how names are shown on your bars."],
					order = 2,
					values = {
						[1] = L["Name"],
						[2] = L["Nickname"],
						[3] = L["Name"] .. " (" .. L["Nickname"] .. ")",
						[4] = L["Nickname"] .. " (" .. L["Name"] .. ")"
					}
				},
				ignorenicknames = {
					type = "toggle",
					name = L["Ignore Nicknames"],
					desc = L["When enabled, nicknames set by Skada users are ignored."],
					order = 3,
					width = "full"
				},
				reset = {
					type = "execute",
					name = L["Clear Cache"],
					order = 4,
					width = "double",
					confirm = function()
						return L["Are you sure you want clear cached nicknames?"]
					end,
					func = function()
						Skada.db.global.nicknames.reset = nil
						Skada.db.global.nicknames.cache = wipe(Skada.db.global.nicknames.cache or {})
						mod:SetCacheTable()
					end
				}
			}
		}
	end

	function mod:OnEnable()
		self.sendCooldown = 0
		self:SetCacheTable()

		Skada.RegisterCallback(self, "SKADA_CORE_UPDATE", "Reset")
		Skada.RegisterCallback(self, "OnCommNickname")

		self:RegisterEvent("PARTY_MEMBERS_CHANGED", "OnEvent")
		self:RegisterEvent("RAID_ROSTER_UPDATE", "OnEvent")
		self:OnEvent()

		self:RawHook(Skada, "FormatName")

		-- backward compatibility
		Skada.RegisterCallback(self, "OnCommNicknameRequest")
		Skada.RegisterCallback(self, "OnCommNicknameChange")
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		self:UnregisterAllEvents()
		self:UnhookAll(Skada)
	end

	-----------------------------------------------------------
	-- hooked functions
	function mod:FormatName(_, name, guid)
		local nickname

		if not Skada.db.profile.ignorenicknames then
			nickname = guid and self.db.cache[guid]
			if not nickname and guid == Skada.userGUID then
				nickname = Skada.db.profile.nickname
			end
		end

		if Skada.db.profile.translit and Translit then
			if nickname and nickname ~= name then
				nickname = Translit:Transliterate(nickname, "!")
			end
			name = Translit:Transliterate(name, "!")
		end

		if nickname and nickname ~= name and (Skada.db.profile.namedisplay or 0) > 1 then
			return format(nicknameFormats[Skada.db.profile.namedisplay], name, nickname)
		end
		return name
	end

	-----------------------------------------------------------
	-- backward compatibility functions

	-- called whenever we receive a nickname request.
	function mod:OnCommNicknameRequest(event, sender)
		if not sender then
			return
		end
		Skada:SendComm("WHISPER", sender, "NicknameResponse", Skada.userGUID, Skada.db.profile.nickname)
	end

	-- if someone in our group changes the nickname, we update the cache
	function mod:OnCommNicknameChange(event, sender, playerid, nickname)
		self:SetCacheTable()
		if Skada.db.profile.ignorenicknames then
			return
		end
		if sender and playerid and playerid ~= Skada.userGUID and nickname then
			self.db.cache[playerid] = nickname
		end
	end

	-----------------------------------------------------------
	-- cache table functions

	function mod:SetCacheTable()
		if not self.db then
			self.db = Skada.db.global.nicknames or {cache = {}}
			Skada.db.global.nicknames = self.db
		end
		self:CheckForReset()
	end

	function mod:CheckForReset()
		if not self.db.reset then
			self.db.reset = time() + (60 * 60 * 24 * 15)
			self.db.cache = {}
		elseif time() > self.db.reset then
			self.db.reset = time() + (60 * 60 * 24 * 15)
			self.db.cache = {}
		end
	end

	function mod:Reset(event)
		if event == "SKADA_CORE_UPDATE" then
			if Skada.db.profile.namedisplay == nil then
				Skada.db.profile.namedisplay = 2
			end
			Skada.db.global.nicknames = nil
			self:SetCacheTable()
		end
	end
end)