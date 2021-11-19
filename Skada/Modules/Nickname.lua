local Skada = Skada
Skada:AddLoadableModule("Nickname", function(L)
	if Skada:IsDisabled("Nickname") then return end

	local mod = Skada:NewModule(L["Nickname"], "AceTimer-3.0")

	local type, time = type, time
	local strlen, strfind, strgsub, format = string.len, string.find, string.gsub, string.format
	local UnitGUID, UnitName = UnitGUID, UnitName
	local CheckNickname

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
			self:ScheduleTimer("SendNickname", 30)
		else
			self:SendNickname()
		end
	end

	function mod:SendNickname(nocooldown)
		self:SetCacheTable()

		if not nocooldown then
			self.sendCooldown = time() + 29
		end

		Skada:SendComm(nil, nil, "Nickname", Skada.userGUID, Skada.db.profile.nickname)
		-- backward compatibility
		Skada:SendComm(nil, nil, "NicknameChange", Skada.userGUID, Skada.db.profile.nickname)
	end

	function mod:OnCommNickname(event, sender, guid, nickname)
		self:SetCacheTable()
		if Skada.db.profile.ignorenicknames then return end
		if sender and guid and guid ~= Skada.userGUID and nickname and CheckNickname(nickname) then
			self.db.cache[guid] = (nickname ~= sender) and nickname or nil
		end
	end

	function mod:OnInitialize()
		if Skada.db.profile.namedisplay == nil then
			Skada.db.profile.namedisplay = 2
		end

		Skada.options.args.tweaks.args.advanced.args.nickname = {
			type = "group",
			name = self.moduleName,
			desc = format(L["Options for %s."], self.moduleName),
			order = 900,
			get = function(i)
				return Skada.db.profile[i[#i]]
			end,
			set = function(i, val)
				Skada.db.profile[i[#i]] = val
				Skada:ApplySettings()
			end,
			args = {
				description = {
					type = "description",
					name = L["Nicknames are sent to group members and Skada can use them instead of your character name."],
					fontSize = "medium",
					width = "full",
					order = 0
				},
				nickname = {
					type = "input",
					name = L["Nickname"],
					desc = L["Set a nickname for you."],
					order = 10,
					get = function()
						return Skada.db.profile.nickname or Skada.userName
					end,
					set = function(_, val)
						local okey, nickname = CheckNickname(val)
						if okey == true then
							Skada.db.profile.nickname = (nickname == "") and Skada.userName or nickname
							mod:SendNickname(true)
							Skada:ApplySettings()
						else
							Skada:Print(nickname)
						end
					end
				},
				namedisplay = {
					type = "select",
					name = L["Name display"],
					desc = L["Choose how names are shown on your bars."],
					order = 20,
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
					order = 30,
					width = "full"
				},
				reset = {
					type = "execute",
					name = L["Clear Cache"],
					order = 100,
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

		Skada.RegisterCallback(self, "Skada_UpdateCore", "Reset")
		Skada.RegisterCallback(self, "OnCommNickname")

		Skada:RegisterMessage("GROUP_ROSTER_UPDATE", self.OnEvent, self)
		self:OnEvent()

		-- backward compatibility
		Skada.RegisterCallback(self, "OnCommNicknameRequest")
		Skada.RegisterCallback(self, "OnCommNicknameChange")
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:UnregisterAllMessages(self)
	end

	-----------------------------------------------------------
	-- Format name functions

	do
		-- modify this if you want to change the way nicknames are displayed
		local nicknameFormats = {[1] = "%1$s", [2] = "%2$s", [3] = "%1$s (%2$s)", [4] = "%2$s (%1$s)"}
		local FormatName = Skada.FormatName

		function Skada:FormatName(name, guid)
			if not self.db.profile.ignorenicknames and (self.db.profile.namedisplay or 0) > 1 and name and guid then
				if not mod.db then mod:SetCacheTable() end

				local nickname
				if guid == self.userGUID then
					nickname = self.db.profile.nickname
				elseif mod.db and mod.db.cache[guid] then
					nickname = mod.db.cache[guid]
				end

				if nickname and nickname ~= name then
					name = format(nicknameFormats[self.db.profile.namedisplay], name, nickname)
				end
			end

			return FormatName(self, name)
		end
	end

	-----------------------------------------------------------
	-- backward compatibility functions

	-- called whenever we receive a nickname request.
	function mod:OnCommNicknameRequest(event, sender)
		if not sender then return end
		Skada:SendComm("WHISPER", sender, "NicknameResponse", Skada.userGUID, Skada.db.profile.nickname)
	end

	-- if someone in our group changes the nickname, we update the cache
	function mod:OnCommNicknameChange(event, sender, playerid, nickname)
		self:SetCacheTable()
		if Skada.db.profile.ignorenicknames then return end
		if sender and playerid and playerid ~= Skada.userGUID and nickname and CheckNickname(nickname) then
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
		if event == "Skada_UpdateCore" then
			if Skada.db.profile.namedisplay == nil then
				Skada.db.profile.namedisplay = 2
			end
			Skada.db.global.nicknames = nil
			self:SetCacheTable()
		end
	end
end)