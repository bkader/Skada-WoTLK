assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Nickname", function(Skada, L)
	if Skada:IsDisabled("Nickname") then return end

	local mod = Skada:NewModule(L["Nickname"], "AceHook-3.0")
	local Translit = LibStub("LibTranslit-1.0", true)

	local type, time = type, time
	local strlen, strfind, strgsub = string.len, string.find, string.gsub
	local UnitGUID, UnitName = UnitGUID, UnitName
	local unitName, unitGUID = UnitName("player"), UnitGUID("player")
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

	-- module options
	local options = {
		type = "group",
		name = L["Nickname"],
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
					return Skada.db.profile.nickname or UnitName("player")
				end,
				set = function(_, val)
					local okey, nickname = CheckNickname(val)
					if okey == true then
						Skada.db.profile.nickname = (nickname == "") and unitName or nickname
						mod:SetNickname(unitGUID, nickname, true)
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
					[1] = NAME,
					[2] = L["Nickname"],
					[3] = NAME .. " (" .. L["Nickname"] .. ")",
					[4] = L["Nickname"] .. " (" .. NAME .. ")"
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
					Skada.db.global.nicknames = wipe(Skada.db.global.nicknames or {})
					mod.db.nicknames = Skada.db.global.nicknames
				end
			}
		}
	}

	function mod:OnInitialize()
		Skada.options.args.modules.args.nickname = options
		if Skada.db.profile.namedisplay == nil then
			Skada.db.profile.namedisplay = 2
		end
	end

	function mod:OnEnable()
		self:SetCacheTable()

		Skada.RegisterCallback(self, "OnCommNicknameRequest")
		Skada.RegisterCallback(self, "OnCommNicknameResponse")
		Skada.RegisterCallback(self, "OnCommNicknameChange")
		self:Hook(Skada, "FixPlayer")
		self:RawHook(Skada, "FormatName")
	end

	function mod:OnDisable()
		Skada.db.global.nicknames, self.db = nil, nil
		Skada.UnregisterAllCallbacks(self)
		self:UnHook(Skada, "find_player")
	end

	-----------------------------------------------------------
	-- hooked functions

	function mod:FormatName(_, name, guid)
		local nickname = guid and self.db.nicknames[guid]
		if not nickname and name == unitName then
			nickname = Skada.db.profile.nickname
		end

		if Skada.db.profile.translit and Translit then
			if nickname and nickname ~= name then
				nickname = Translit:Transliterate(nickname, "!")
			end
			name = Translit:Transliterate(name, "!")
		end

		if nickname and nickname ~= name and Skada.db.profile.namedisplay > 1 then
			if Skada.db.profile.namedisplay == 2 then
				name = nickname
			elseif Skada.db.profile.namedisplay == 3 then
				name = name .. " (" .. nickname .. ")"
			elseif Skada.db.profile.namedisplay == 4 then
				name = nickname .. " (" .. name .. ")"
			end
		end

		return name
	end

	-- we make sure to add the player's nickname if not set.
	-- if it's the player themselves, we use what's stored.
	-- otherwise we requrest the nickname from the other skada user.
	function mod:FixPlayer(_, player)
		if Skada.db.profile.ignorenicknames or Skada:IsPet(player.id, player.flags) then
			return
		end
		if player.id == unitGUID and player.name == unitName then
			return
		end
		if player.id and player.name and not self.db.nicknames[player.id] then
			Skada:SendComm("WHISPER", player.name, "NicknameRequest")
		end
	end

	-----------------------------------------------------------
	-- sync functions

	-- called whenever we receive a nickname request.
	function mod:OnCommNicknameRequest(event, sender)
		if event ~= "OnCommNicknameRequest" then
			return
		end
		Skada:SendComm("WHISPER", sender, "NicknameResponse", unitGUID, Skada.db.profile.nickname)
	end

	-- called whenever we receive a nickname response
	function mod:OnCommNicknameResponse(event, sender, playerid, nickname)
		if event ~= "OnCommNicknameResponse" then
			return
		end
		-- the player didn't send us the nickname or doesn't
		-- have a nickname set? Set it to his/her name anyways.
		if not nickname or nickname == "" then
			nickname = sender
		end
		self:SetNickname(playerid, nickname)
	end

	-- if someone in our group changes the nickname, we update the cache
	function mod:OnCommNicknameChange(event, sender, playerid, nickname)
		if event ~= "OnCommNicknameChange" then
			return
		end
		if not nickname or nickname == "" then
			nickname = sender
		end
		if not self.db then
			self:SetCacheTable()
		end
		self.db.nicknames[playerid] = nickname
	end

	-----------------------------------------------------------

	function mod:SetNickname(guid, nickname, sync)
		self.db.nicknames[guid] = nickname
		if guid == unitGUID and sync then
			Skada:SendComm(nil, nil, "NicknameChange", guid, nickname)
		end
	end

	-----------------------------------------------------------
	-- cache table functions

	function mod:SetCacheTable()
		self.db = Skada.db.global.nicknames or {nicknames = {}}
		Skada.db.global.nicknames = self.db
		self:CheckForReset()
	end

	function mod:CheckForReset()
		if not self.db then
			self.db = Skada.db.global.nicknames or {nicknames = {}}
			Skada.db.global.nicknames = self.db
		end

		if not self.db.nextreset then
			self.db.nextreset = time() + (60 * 60 * 24 * 15)
			self.db.nicknames = {}
		elseif time() > self.db.nextreset then
			self.db.nextreset = time() + (60 * 60 * 24 * 15)
			self.db.nicknames = {}
		end
	end
end)