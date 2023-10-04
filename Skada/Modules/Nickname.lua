local _, Skada = ...
Skada:RegisterModule("Nickname", function(L, P, G, _, _, O)
	local mode = Skada:NewModule("Nickname")
	local CONST_COMM_MOD = "Nickname"

	local time, wipe = time, wipe
	local strlower, format = string.lower, string.format
	local check_nickname, cached_nickname

	do
		local type, strlen = type, strlenutf8 or string.len
		local strfind, strmatch = string.find, string.match
		local strupper, strgsub = string.upper, string.gsub

		local function str_trim(str)
			local from = strmatch(str, "^%s*()")
			return from > #str and "" or strmatch(str, ".*%S", from)
		end

		local function title_case(first, rest)
			return format("%s%s", strupper(first), strlower(rest))
		end

		local have_repeated = false
		local count_spaces = 0

		local blacklist = {
			"abort",
			"abuse",
			"anal",
			"arse",
			"ass",
			"azz",
			"ball",
			"bang",
			"basst",
			"bastard",
			"beastal",
			"beat",
			"bestial",
			"biat",
			"bigass",
			"bitc",
			"blow",
			"boner",
			"boob",
			"booty",
			"breast",
			"bugg",
			"bum",
			"bung",
			"butt",
			"byatch",
			"camel",
			"cawk",
			"chesticle",
			"clit",
			"clog",
			"clunge",
			"cnts",
			"cntz",
			"cock",
			"coitus",
			"cok",
			"commie",
			"cooch",
			"coon",
			"cooter",
			"copul",
			"crack",
			"crap",
			"crotch",
			"cum",
			"cunil",
			"cunni",
			"cunt",
			"dammit",
			"damn",
			"darkie",
			"darky",
			"dick",
			"dike",
			"dild",
			"dipshit",
			"dipstick",
			"dixied",
			"doggie",
			"doggy",
			"dooch",
			"douch",
			"dragqueen",
			"dragqween",
			"dumass",
			"dumb",
			"ejacul",
			"excrement",
			"facist",
			"fag",
			"faig",
			"fark",
			"fart",
			"fatass",
			"felatio",
			"felch",
			"fellatio",
			"feltch",
			"fister",
			"flamer",
			"flasher",
			"fornicate",
			"fucck",
			"fuck",
			"fuk",
			"fukin",
			"fukk",
			"fuuck",
			"gay",
			"godammit",
			"goddammit",
			"goddamn",
			"goddamned",
			"goddamnes",
			"goddamnit",
			"gringo",
			"hells",
			"herpes",
			"hindoo",
			"hitler",
			"hobo",
			"hoe",
			"hole",
			"homo",
			"hookers",
			"hoor",
			"hore",
			"horne",
			"horni",
			"horny",
			"hunk",
			"hymen",
			"idiot",
			"incest",
			"insest",
			"jackass",
			"jackoff",
			"jackshit",
			"jag",
			"jerk",
			"jihad",
			"kidd",
			"kinky",
			"kooch",
			"kootch",
			"krap",
			"kunilingus",
			"kunnilingus",
			"kunt",
			"labia",
			"lactate",
			"lesb",
			"lezb",
			"lickm",
			"lmfao",
			"lube",
			"masochist",
			"massterbait",
			"masstrbait",
			"masstrbate",
			"mastabate",
			"mastabater",
			"masterbaiter",
			"masterbate",
			"masterbates",
			"mastrabator",
			"masturbate",
			"masturbating",
			"milf",
			"mofo",
			"molest",
			"moron",
			"nastt",
			"nasty",
			"nazi",
			"necro",
			"negro",
			"nigaboo",
			"nigga",
			"nigge",
			"niggl",
			"niggo",
			"niggu",
			"niglet",
			"nigr",
			"nigur",
			"niig",
			"nippl",
			"nlgg",
			"nonce",
			"nook",
			"nudg",
			"nut",
			"orgas",
			"orgi",
			"orgy",
			"peedo",
			"peeenus",
			"peenus",
			"peinus",
			"penas",
			"penile",
			"penus",
			"penuus",
			"perv",
			"phuck",
			"phuk",
			"phuq",
			"pimp",
			"piss",
			"plumper",
			"poon",
			"poop",
			"porn",
			"pric",
			"prik",
			"pube",
			"puke",
			"punan",
			"punta",
			"puss",
			"pusy",
			"puuke",
			"queef",
			"queer",
			"qweer",
			"qweir",
			"rape",
			"rapist",
			"recktum",
			"rectum",
			"redneck",
			"ruski",
			"russki",
			"sadist",
			"sadom",
			"sandm",
			"schlong",
			"screw",
			"scrotum",
			"scum",
			"seaman",
			"semen",
			"sex",
			"shag",
			"shat",
			"shhit",
			"shit",
			"shiz",
			"shyt",
			"sissy",
			"skeet",
			"skirt",
			"skum",
			"slop",
			"slut",
			"smeg",
			"snot",
			"sodom",
			"sperm",
			"stabb",
			"stiff",
			"suck",
			"tampon",
			"tard",
			"testic",
			"threes",
			"tits",
			"titti",
			"titty",
			"torture",
			"trots",
			"trouser",
			"tunnel",
			"turd",
			"twat",
			"urin",
			"uteru",
			"vagi",
			"vomit",
			"vullv",
			"vulva",
			"wank",
			"whitey",
			"whoor",
			"whore",
			"wife",
			"wog",
			"ziga",
			"zipp",
			"name",
			L["Name"],
			"nickname",
			L["Nickname"]
		}

		local function check_repeated(char)
			if char == "  " then
				have_repeated = true
			elseif strlen(char) > 2 then
				have_repeated = true
			elseif char == " " then
				count_spaces = count_spaces + 1
			end
		end

		function check_nickname(name)
			if type(name) ~= "string" then
				return false, L["Nickname isn't a valid string."]
			end

			name = str_trim(name)

			local len = strlen(name)
			if len == 0 then
				return true, nil
			elseif len > 12 then
				return false, L["Your nickname is too long, max of 12 characters is allowed."]
			end

			local notallow = strfind(name, "[^a-zA-Z�������%s]")
			if notallow then
				return false, L["Only letters and two spaces are allowed."]
			end

			for _, word in pairs(blacklist) do
				if strfind(strlower(name), word) then
					return false, L["Your nickname contains a forbidden word."]
				end
			end

			have_repeated = false
			count_spaces = 0
			strgsub(strgsub(strgsub(name, ".", "\0%0%0"), "(.)%z%1", "%1"), "%z.([^%z]+)", check_repeated)
			if count_spaces > 2 then
				have_repeated = true
			end
			if have_repeated then
				return false, L["You can't use the same letter three times consecutively, two spaces consecutively or more then two spaces."]
			end

			return true, strgsub(name, "(%a)([%w_']*)", title_case)
		end
	end

	function mode:OnEvent(event)
		if self.sendCooldown > time() then
			self.nicknameTimer = self.nicknameTimer or Skada.ScheduleTimer(self, "SendNickname", 30)
		else
			self:SendNickname()
		end
	end

	function mode:SendNickname(nocooldown)
		self:SetCacheTable()

		if not nocooldown then
			self.sendCooldown = time() + 29
		end

		if self.nicknameTimer then
			Skada.CancelTimer(self, "SendNickname", true)
			self.nicknameTimer = nil
		end

		Skada:SendComm(nil, nil, CONST_COMM_MOD, Skada.userGUID, G.nickname)
	end

	local function remove_nickname(guid)
		if mode.db.cache[guid] then
			mode.db.cache[guid] = nil
		end
		cached_nickname[guid] = false
	end

	function mode:OnCommNickname(sender, guid, nickname)
		self:SetCacheTable()
		if not P.ignorenicknames and sender and guid then
			-- no nickname or removed?
			if not nickname then
				remove_nickname(guid)
				return
			end

			local okey = nil
			okey, nickname = check_nickname(nickname)
			-- received an invalid nickname?
			if not okey or not nickname or nickname == "" then
				remove_nickname(guid)
				return
			end

			-- so far so good? update...
			self.db.cache[guid] = nickname -- only change if different
			cached_nickname[guid] = nickname -- cache it and we're done!
		end
	end

	function mode:OnInitialize()
		P.namedisplay = P.namedisplay or 2

		-- move nickname to global
		if P.nickname then
			G.nickname = G.nickname or P.nickname
			P.nickname = nil
		end

		O.tweaks.args.advanced.args.nickname = {
			type = "group",
			name = self.localeName,
			desc = format(L["Options for %s."], self.localeName),
			order = 900,
			get = function(i)
				return P[i[#i]]
			end,
			set = function(i, val)
				P[i[#i]] = val
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
						return G.nickname
					end,
					set = function(_, val)
						local okey, nickname = check_nickname(val)
						if okey == true then
							G.nickname = nickname
							cached_nickname[Skada.userGUID] = nickname or false
							mode:SendNickname(true)
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
						[3] = format("%s (%s)", L["Name"], L["Nickname"]),
						[4] = format("%s (%s)", L["Nickname"], L["Name"])
					}
				},
				ignorenicknames = {
					type = "toggle",
					name = L["Ignore Nicknames"],
					desc = L["When enabled, nicknames set by Skada users are ignored."],
					set = function(_, value)
						P.ignorenicknames = value
						mode:UpdateComms(nil, not P.syncoff)
						Skada:ApplySettings()
					end,
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
						G.nicknames.reset = nil
						G.nicknames.cache = wipe(G.nicknames.cache or {})
						mode:SetCacheTable()
					end,
					disabled = function()
						return (not G.nicknames or next(G.nicknames.cache) == nil)
					end
				}
			}
		}
	end

	function mode:UpdateComms(_, enable)
		if enable and not P.ignorenicknames then
			Skada.AddComm(self, CONST_COMM_MOD, "OnCommNickname")
			Skada.RegisterMessage(self, "GROUP_ROSTER_UPDATE", "OnEvent")
			Skada:Debug(format("%s Comms: \124cff00ff00%s\124r", self.localeName, L["ENABLED"]))
		else
			Skada.RemoveAllComms(self)
			Skada.UnregisterAllMessages(self)
			Skada:Debug(format("%s Comms: \124cffff0000%s\124r", self.localeName, L["DISABLED"]))
		end
	end

	function mode:OnEnable()
		self.sendCooldown = 0
		self:SetCacheTable()

		Skada.RegisterCallback(self, "Skada_UpdateCore", "Reset")
		Skada.RegisterCallback(self, "Skada_UpdateComms", "UpdateComms")

		self:UpdateComms(nil, not P.syncoff)
	end

	function mode:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:UnregisterAllMessages(self)
		Skada.RemoveAllComms(self)
	end

	-----------------------------------------------------------
	-- Format name functions

	do
		-- modify this if you want to change the way nicknames are displayed
		local nickname_fmt = {[1] = "%1$s", [2] = "%2$s", [3] = "%1$s (%2$s)", [4] = "%2$s (%1$s)"}

		cached_nickname = setmetatable({}, {__mode = "kv", __index = function(t, guid)
			if not mode.db then mode:SetCacheTable() end -- why wasn't it available yet?!

			local nickname = false

			-- ignoring nicknames and it's not me?
			if P.ignorenicknames and guid ~= Skada.userGUID then
				nickname = false
			-- me?
			elseif guid == Skada.userGUID then
				nickname = G.nickname or false
			-- well! we've got one!
			elseif mode.db and mode.db.cache[guid] then
				nickname = mode.db and mode.db.cache[guid] or false
			end

			-- cache it and move on!
			t[guid] = nickname
			return nickname
		end})

		Skada.oFormatName = Skada.FormatName
		Skada.FormatName = function(self, name, guid)
			-- missing guid or showing only names?
			if not guid or P.namedisplay <= 1 then
				return self:oFormatName(name)
			end

			-- cache table handles the worse part!
			local nickname = cached_nickname[guid]
			if nickname and nickname ~= name then
				name = format(nickname_fmt[P.namedisplay], name, nickname)
			end

			-- leave the rest to the original func!
			return self:oFormatName(name)
		end
	end

	-----------------------------------------------------------
	-- cache table functions

	local function check_for_reset()
		if not mode.db.reset or time() > mode.db.reset then
			mode.db.reset = time() + (60 * 60 * 24 * 15)
			mode.db.cache = wipe(mode.db.cache or {})
		end
	end

	function mode:SetCacheTable()
		if not self.db then
			G.nicknames = G.nicknames or {cache = {}}
			self.db = G.nicknames
		end
		check_for_reset()
	end

	function mode:Reset()
		P.namedisplay = P.namedisplay or 2

		G.nicknames = G.nicknames or {cache = {}}
		G.nicknames.reset = time() + (60 * 60 * 24 * 15)
		G.nicknames.cache = wipe(G.nicknames.cache or {})
		self.db = G.nicknames
	end
end)
