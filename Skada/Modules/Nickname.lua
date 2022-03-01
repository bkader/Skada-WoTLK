local Skada = Skada
Skada:AddLoadableModule("Nickname", function(L)
	if Skada:IsDisabled("Nickname") then return end

	local mod = Skada:NewModule(L["Nickname"], "AceTimer-3.0")
	local Translit = LibStub("LibTranslit-1.0", true)

	local time, wipe, format = time, wipe, string.format
	local CheckNickname

	do
		local type, strlen, strfind, strgsub = type, string.len, string.find, string.gsub

		local function _trim(str)
			local from = str:match("^%s*()")
			return from > #str and "" or str:match(".*%S", from)
		end

		local function titlecase(first, rest)
			return first:upper() .. rest:lower()
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
			"Fukin",
			"Fukk",
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
			"zipp"
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

		function CheckNickname(name)
			if type(name) ~= "string" then
				return false, L["Nickname isn't a valid string."]
			end

			name = _trim(name)

			local len = strlen(name)
			if len > 12 then
				return false, L["Your nickname is too long, max of 12 characters is allowed."]
			end

			local notallow = strfind(name, "[^a-zA-Z�������%s]")
			if notallow then
				return false, L["Only letters and two spaces are allowed."]
			end

			for _, word in ipairs(blacklist) do
				if strfind(name, word) then
					return false, L["Your nickname contains a forbidden word."]
				end
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
	end

	function mod:OnCommNickname(event, sender, guid, nickname)
		self:SetCacheTable()
		if Skada.db.profile.ignorenicknames then return end
		if sender and guid and guid ~= Skada.userGUID and nickname then
			local okey, nickname = CheckNickname(nickname)
			if not okey or nickname == "" then
				self.db.cache[guid] = nil -- remove if invalid or empty
			elseif not self.db.cache[guid] or self.db.cache[guid] ~= nickname then
				self.db.cache[guid] = nickname -- only change if different
			end
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
						return Skada.db.profile.nickname
					end,
					set = function(_, val)
						local okey, nickname = CheckNickname(val)
						if okey == true then
							Skada.db.profile.nickname = nickname
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
					end,
					disabled = function()
						return (not Skada.db.global.nicknames or next(Skada.db.global.nicknames.cache) == nil)
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

		function Skada:FormatName(name, guid)
			if not self.db.profile.ignorenicknames and (self.db.profile.namedisplay or 0) > 1 and name and guid then
				if not mod.db then mod:SetCacheTable() end

				local nickname
				if guid == self.userGUID then
					nickname = self.db.profile.nickname
				elseif mod.db and mod.db.cache[guid] then
					nickname = mod.db.cache[guid]
				end

				if nickname and nickname ~= name and nickname ~= "" then
					name = format(nicknameFormats[self.db.profile.namedisplay], name, nickname)
				end
			end

			return (self.db.profile.translit and Translit) and Translit:Transliterate(name, "!") or name
		end
	end

	-----------------------------------------------------------
	-- cache table functions

	local function CheckForReset()
		if not mod.db.reset then
			mod.db.reset = time() + (60 * 60 * 24 * 15)
			mod.db.cache = {}
		elseif time() > mod.db.reset then
			mod.db.reset = time() + (60 * 60 * 24 * 15)
			wipe(mod.db.cache)
		end
	end

	function mod:SetCacheTable()
		if not self.db then
			if not Skada.db.global.nicknames then
				Skada.db.global.nicknames = {cache = {}}
			end
			self.db = Skada.db.global.nicknames
		end
		CheckForReset()
	end

	function mod:Reset(event)
		if event == "Skada_UpdateCore" then
			if Skada.db.profile.namedisplay == nil then
				Skada.db.profile.namedisplay = 2
			end

			if not Skada.db.global.nicknames then
				Skada.db.global.nicknames = {cache = {}}
			else
				Skada.db.global.nicknames.reset = time() + (60 * 60 * 24 * 15)
				wipe(Skada.db.global.nicknames.cache)
			end

			self.db = Skada.db.global.nicknames
		end
	end
end)