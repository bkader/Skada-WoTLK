local folder, Skada = ...
local private = Skada.private

local select, pairs, type = select, pairs, type
local tonumber, format = tonumber, string.format
local setmetatable, wipe, band = setmetatable, wipe, bit.band
local next, print = next, print
local _

local L = LibStub("AceLocale-3.0"):GetLocale(folder)
local UnitClass, GetPlayerInfoByGUID = UnitClass, GetPlayerInfoByGUID
local GetClassFromGUID = Skada.GetClassFromGUID
local T = Skada.Table

local COMBATLOG_OBJECT_TYPE_NPC = COMBATLOG_OBJECT_TYPE_NPC or 0x00000800

-------------------------------------------------------------------------------
-- debug function

function Skada:Debug(...)
	if self.db.profile.debug then
		print("\124cff33ff99Skada Debug\124r:", ...)
	end
end

-------------------------------------------------------------------------------
-- Classes, Specs and Schools

function private.register_classes()
	private.register_classes = nil -- remove it

	-- class colors & coordinates
	local classcolors, classcoords = Skada.GetClassColorsTable()
	Skada.GetClassColorsTable = nil

	-- valid classes!
	local validclass = {}
	for class, classTable in pairs(classcolors) do
		validclass[class] = true
		-- localized class names.
		L[class] = classTable.className
	end
	Skada.validclass = validclass

	-- Skada custom class colors!
	classcolors.BOSS = {r = 0.203, g = 0.345, b = 0.525, colorStr = "ff345886"}
	classcolors.ENEMY = {r = 0.94117, g = 0, b = 0.0196, colorStr = "fff00005"}
	classcolors.MONSTER = {r = 0.549, g = 0.388, b = 0.404, colorStr = "ff8c6367"}
	classcolors.PET = {r = 0.3, g = 0.4, b = 0.5, colorStr = "ff4c0566"}
	classcolors.PLAYER = {r = 0.94117, g = 0, b = 0.0196, colorStr = "fff00005"}
	classcolors.UNKNOWN = {r = 0.2, g = 0.2, b = 0.2, colorStr = "ff333333"}

	local RGBPercToHex = Skada.RGBPercToHex
	local P = Skada.db.profile

	Skada.classcolors = setmetatable(classcolors, {__call = function(t, class, arg)
		local color = HIGHLIGHT_FONT_COLOR
		if class and t[class] then
			color = t[class]
			-- using a custom color?
			if P.usecustomcolors and P.customcolors and P.customcolors[class] then
				color = P.customcolors[class]
			end
		end
		-- missing colorStr?
		if not color.colorStr then
			color.colorStr = RGBPercToHex(color.r, color.g, color.b, true)
		end

		return (arg == nil) and color or (type(arg) == "string") and format("\124c%s%s\124r", color.colorStr, arg) or color.colorStr
	end})

	-- set classes icon file & Skada custom classes.
	Skada.classicons = [[Interface\AddOns\Skada\Media\Textures\icon-classes]]

	-- custom class coordinates
	if not classcoords.BOSS then
		classcoords.BOSS = {0.5, 0.75, 0.5, 0.75}
		classcoords.MONSTER = {0.75, 1, 0.5, 0.75}
		classcoords.ENEMY = {0, 0.25, 0.75, 1}
		classcoords.PET = {0.25, 0.5, 0.75, 1}
		classcoords.PLAYER = {0.75, 1, 0.75, 1}
		classcoords.UNKNOWN = {0.5, 0.75, 0.75, 1}
	end

	-- common metatable for coordinates tables.
	local coords_mt = {__call = function(t, key)
		if key and t[key] then
			return t[key][1], t[key][2], t[key][3], t[key][4]
		end
		return 0, 1, 0, 1
	end}
	Skada.classcoords = setmetatable(classcoords, coords_mt)

	-- role icon file and texture coordinates
	Skada.roleicons = [[Interface\AddOns\Skada\Media\Textures\icon-roles]]
	Skada.rolecoords = setmetatable({
		LEADER = {0, 0.25, 0, 1},
		DAMAGER = {0.25, 0.5, 0, 1},
		TANK = {0.5, 0.75, 0, 1},
		HEALER = {0.75, 1, 0, 1},
		NONE = {0.25, 0.5, 0, 1} -- fallback to damager
	}, coords_mt)

	-- specialization icons
	Skada.specicons = [[Interface\AddOns\Skada\Media\Textures\icon-specs]]
	Skada.speccoords = setmetatable({
		[62] = {0.25, 0.375, 0.25, 0.5}, --> Mage: Arcane
		[63] = {0.375, 0.5, 0.25, 0.5}, --> Mage: Fire
		[64] = {0.5, 0.625, 0.25, 0.5}, --> Mage: Frost
		[65] = {0.625, 0.75, 0.25, 0.5}, --> Paladin: Holy
		[66] = {0.75, 0.875, 0.25, 0.5}, --> Paladin: Protection
		[70] = {0.875, 1, 0.25, 0.5}, --> Paladin: Retribution
		[71] = {0.5, 0.625, 0.75, 1}, --> Warrior: Arms
		[72] = {0.625, 0.75, 0.75, 1}, --> Warrior: Fury
		[73] = {0.75, 0.875, 0.75, 1}, --> Warrior: Protection
		[102] = {0.375, 0.5, 0, 0.25}, --> Druid: Balance
		[103] = {0.5, 0.625, 0, 0.25}, --> Druid: Feral
		[104] = {0.625, 0.75, 0, 0.25}, --> Druid: Tank
		[105] = {0.75, 0.875, 0, 0.25}, --> Druid: Restoration
		[250] = {0, 0.125, 0, 0.25}, --> Death Knight: Blood
		[251] = {0.125, 0.25, 0, 0.25}, --> Death Knight: Frost
		[252] = {0.25, 0.375, 0, 0.25}, --> Death Knight: Unholy
		[253] = {0.875, 1, 0, 0.25}, --> Hunter: Beastmastery
		[254] = {0, 0.125, 0.25, 0.5}, --> Hunter: Marksmalship
		[255] = {0.125, 0.25, 0.25, 0.5}, --> Hunter: Survival
		[256] = {0, 0.125, 0.5, 0.75}, --> Priest: Discipline
		[257] = {0.125, 0.25, 0.5, 0.75}, --> Priest: Holy
		[258] = {0.25, 0.375, 0.5, 0.75}, --> Priest: Shadow
		[259] = {0.375, 0.5, 0.5, 0.75}, --> Rogue: Assassination
		[260] = {0.5, 0.625, 0.5, 0.75}, --> Rogue: Combat
		[261] = {0.625, 0.75, 0.5, 0.75}, --> Rogue: Subtlty
		[262] = {0.75, 0.875, 0.5, 0.75}, --> Shaman: Elemental
		[263] = {0.875, 1, 0.5, 0.75}, --> Shaman: Enhancement
		[264] = {0, 0.125, 0.75, 1}, --> Shaman: Restoration
		[265] = {0.125, 0.25, 0.75, 1}, --> Warlock: Affliction
		[266] = {0.25, 0.375, 0.75, 1}, --> Warlock: Demonology
		[267] = {0.375, 0.5, 0.75, 1} --> Warlock: Destruction
	}, coords_mt)

	-- customize class colors
	local disabled = function()
		return not P.usecustomcolors
	end

	local colorsOpt = {
		type = "group",
		name = L["Colors"],
		desc = format(L["Options for %s."], L["Colors"]),
		order = 1000,
		get = function(i)
			local color = classcolors[i[#i]]
			if P.customcolors and P.customcolors[i[#i]] then
				color = P.customcolors[i[#i]]
			end
			return color.r, color.g, color.b
		end,
		set = function(i, r, g, b)
			local class = i[#i]
			P.customcolors = P.customcolors or {}
			P.customcolors[class] = P.customcolors[class] or {}
			P.customcolors[class].r = r
			P.customcolors[class].g = g
			P.customcolors[class].b = b
			P.customcolors[class].colorStr = RGBPercToHex(r, g, b, true)
		end,
		args = {
			enable = {
				type = "toggle",
				name = L["Enable"],
				width = "double",
				order = 10,
				get = function()
					return P.usecustomcolors
				end,
				set = function(_, val)
					if val then
						P.usecustomcolors = true
					else
						P.usecustomcolors = nil
						P.customcolors = nil -- free it
					end
				end
			},
			class = {
				type = "group",
				name = L["Class Colors"],
				order = 20,
				hidden = disabled,
				disabled = disabled,
				args = {}
			},
			custom = {
				type = "group",
				name = L["Custom Colors"],
				order = 30,
				hidden = disabled,
				disabled = disabled,
				args = {}
			},
			reset = {
				type = "execute",
				name = L["Reset"],
				width = "double",
				order = 90,
				disabled = disabled,
				confirm = function() return L["Are you sure you want to reset all colors?"] end,
				func = function()
					P.customcolors = wipe(P.customcolors or {})
				end
			}
		}
	}

	for class, data in pairs(classcolors) do
		if validclass[class] then
			colorsOpt.args.class.args[class] = {
				type = "color",
				name = L[class],
				desc = format(L["Color for %s."], L[class])
			}
		else
			colorsOpt.args.custom.args[class] = {
				type = "color",
				name = L[class],
				desc = format(L["Color for %s."], L[class])
			}
		end
	end

	Skada.options.args.tweaks.args.advanced.args.colors = colorsOpt
end

function private.register_schools()
	private.register_schools = nil -- remove it

	local spellschools = {}

	-- handles adding spell schools
	local order = {}
	local function add_school(key, name, r, g, b)
		if key and name and not spellschools[key] then
			spellschools[key] = {r = r or 1, g = g or 1, b = b or 1, name = name:match("%((.+)%)") or name}
			order[#order + 1] = key
		end
	end

	-- main school
	local SCHOOL_NONE = SCHOOL_MASK_NONE or 0x00 -- None
	local SCHOOL_PHYSICAL = SCHOOL_MASK_PHYSICAL or 0x01 -- Physical
	local SCHOOL_HOLY = SCHOOL_MASK_HOLY or 0x02 -- Holy
	local SCHOOL_FIRE = SCHOOL_MASK_FIRE or 0x04 -- Fire
	local SCHOOL_NATURE = SCHOOL_MASK_NATURE or 0x08 -- Nature
	local SCHOOL_FROST = SCHOOL_MASK_FROST or 0x10 -- Frost
	local SCHOOL_SHADOW = SCHOOL_MASK_SHADOW or 0x20 -- Shadow
	local SCHOOL_ARCANE = SCHOOL_MASK_ARCANE or 0x40 -- Arcane

	-- Single Schools
	add_school(SCHOOL_NONE, STRING_SCHOOL_UNKNOWN, 1, 1, 1) -- Unknown
	add_school(SCHOOL_PHYSICAL, STRING_SCHOOL_PHYSICAL, 1, 1, 0) -- Physical
	add_school(SCHOOL_HOLY, STRING_SCHOOL_HOLY, 1, 0.9, 0.5) -- Holy
	add_school(SCHOOL_FIRE, STRING_SCHOOL_FIRE, 1, 0.5, 0) -- Fire
	add_school(SCHOOL_NATURE, STRING_SCHOOL_NATURE, 0.3, 1, 0.3) -- Nature
	add_school(SCHOOL_FROST, STRING_SCHOOL_FROST, 0.5, 1, 1) -- Frost
	add_school(SCHOOL_SHADOW, STRING_SCHOOL_SHADOW, 0.5, 0.5, 1) -- Shadow
	add_school(SCHOOL_ARCANE, STRING_SCHOOL_ARCANE, 1, 0.5, 1) -- Arcane

	-- reference to CombatLog_String_SchoolString
	local colorFunc = CombatLog_Color_ColorArrayBySchool
	local function get_school_name(key)
		if not nameFunc then -- late availability
			nameFunc = CombatLog_String_SchoolString
		end

		local name = nameFunc(key)
		local isnone = (name == STRING_SCHOOL_UNKNOWN)
		return name:match("%((.+)%)") or name, isnone
	end

	-- reference to COMBATLOG_DEFAULT_COLORS.schoolColoring
	local colorTable = COMBATLOG_DEFAULT_COLORS and COMBATLOG_DEFAULT_COLORS.schoolColoring
	local function get_school_color(key)
		if not colorTable then -- late availability
			colorTable = COMBATLOG_DEFAULT_COLORS and COMBATLOG_DEFAULT_COLORS.schoolColoring
		end

		local r, g, b = 1.0, 1.0, 1.0

		if colorTable and colorTable[key] then
			r = colorTable[key].r or r
			g = colorTable[key].g or g
			b = colorTable[key].b or b
		elseif colorTable then
			for i = #order, 1, -1 do
				local k = order[i]
				if band(key, k) == k then
					r = colorTable[k].r or r
					g = colorTable[k].g or g
					b = colorTable[k].b or b
					break
				end
			end
		end

		return r, g, b
	end

	Skada.spellschools = setmetatable(spellschools, {
		__index = function(t, key)
			local name, isnone = get_school_name(key)
			if not isnone then
				local r, g, b = get_school_color(key)
				t[key] = {name = name, r = r, g = g, b = b}
				return t[key]
			end
			return t[0x00] -- unknown
		end,
		__call = function(t, key)
			local school = t[key]
			return school.name, school.r, school.g, school.b
		end
	})
end

-------------------------------------------------------------------------------
-- creates generic dialog

function private.confirm_dialog(text, accept, cancel, override)
	if type(cancel) == "table" and override == nil then
		override = cancel
		cancel = nil
	end

	local t = wipe(StaticPopupDialogs["SkadaCommonConfirmDialog"] or {})
	StaticPopupDialogs["SkadaCommonConfirmDialog"] = t

	local dialog, strata
	t.OnAccept = function(self)
		if type(accept) == "function" then
			(accept)(self)
		end
		if dialog and strata then
			dialog:SetFrameStrata(strata)
		end
	end
	t.OnCancel = function(self)
		if type(cancel) == "function" then
			(cancel)(self)
		end
		if dialog and strata then
			dialog:SetFrameStrata(strata)
		end
	end

	t.preferredIndex = STATICPOPUP_NUMDIALOGS
	t.text = text
	t.button1 = ACCEPT
	t.button2 = CANCEL
	t.timeout = 0
	t.whileDead = 1
	t.hideOnEscape = 1

	if type(override) == "table" then
		Skada.tCopy(t, override)
	end

	dialog = StaticPopup_Show("SkadaCommonConfirmDialog")
	if dialog then
		strata = dialog:GetFrameStrata()
		dialog:SetFrameStrata("TOOLTIP")
	end
end

-------------------------------------------------------------------------------
-- boss and creature functions

do
	local creatureToFight = Skada.creatureToFight or Skada.dummyTable
	local creatureToBoss = Skada.creatureToBoss or Skada.dummyTable

	-- checks if the provided guid is a boss
	function Skada:IsBoss(guid, strict)
		local id = self.GetCreatureId(guid)
		if creatureToBoss[id] and creatureToBoss[id] ~= true then
			if strict then
				return false
			end
			return true, id
		elseif creatureToBoss[id] or creatureToFight[id] then
			return true, id
		end
		return false
	end

	function Skada:IsEncounter(guid, name)
		local isboss, id = self:IsBoss(guid, nil, "IsEncounter")
		if isboss and id then
			if creatureToBoss[id] and creatureToBoss[id] ~= true then
				return true, creatureToBoss[id], creatureToFight[id] or name
			end

			if creatureToFight[id] then
				return true, true, creatureToFight[id] or name
			end

			return true, id, creatureToFight[id] or name
		end
		return false
	end
end

function private.is_creature(guid, flag)
	if tonumber(guid) then
		return (band(guid:sub(1, 5), 0x00F) == 3 or band(guid:sub(1, 5), 0x00F) == 5)
	end
	if tonumber(flag) then
		return (band(flag, COMBATLOG_OBJECT_TYPE_NPC) ~= 0)
	end
	return false
end

-------------------------------------------------------------------------------
-- class, role and spec functions

function private.unit_class(guid, flag, set, db, name)
	set = set or Skada.current
	if set then
		-- an existing player?
		local actors = set.players
		if actors then
			for i = 1, #actors do
				local p = actors[i]
				if p and p.id == guid then
					return p.class, p.role, p.spec
				elseif p and name and p.name == name and p.class and Skada.validclass[p.class] then
					return p.class, p.role, p.spec
				end
			end
		end
		-- an existing enemy?
		actors = set.enemies
		if actors then
			for i = 1, #actors do
				local e = actors[i]
				if e and ((e.id == guid or e.name == guid)) and e.class then
					return e.class
				end
			end
		end
	end

	local class = "UNKNOWN"
	if Skada:IsPlayer(guid, flag, name) then
		class = name and select(2, UnitClass(name))
		if not class and tonumber(guid) then
			class = GetClassFromGUID(guid, "group")
			class = class or select(2, GetPlayerInfoByGUID(guid))
		end
	elseif Skada:IsPet(guid, flag) then
		class = "PET"
	elseif Skada:IsBoss(guid, true) then
		class = "BOSS"
	elseif private.is_creature(guid, flag) then
		class = "MONSTER"
	end

	if class and db and db.class == nil then
		db.class = class
	end

	return class
end

-------------------------------------------------------------------------------
-- spell functions

do
	local GetSpellInfo, GetSpellLink = GetSpellInfo, GetSpellLink
	local customSpells = {
		[3] = {L["Falling"], [[Interface\Icons\ability_rogue_quickrecovery]]},
		[4] = {L["Drowning"], [[Interface\Icons\spell_shadow_demonbreath]]},
		[5] = {L["Fatigue"], [[Interface\Icons\ability_creature_cursed_05]]},
		[6] = {L["Fire"], [[Interface\Icons\spell_fire_fire]]},
		[7] = {L["Lava"], [[Interface\Icons\spell_shaman_lavaflow]]},
		[8] = {L["Slime"], [[Interface\Icons\inv_misc_slime_01]]}
	}

	function private.spell_info(spellid)
		local res1, res2, res3, res4, res5, res6, res7, res8, res9
		if spellid then
			if customSpells[spellid] then
				res1, res3 = customSpells[spellid][1], customSpells[spellid][2]
			else
				res1, res2, res3, res4, res5, res6, res7, res8, res9 = GetSpellInfo(spellid)
				if spellid == 75 then
					res3 = [[Interface\Icons\INV_Weapon_Bow_07]]
				elseif spellid == 6603 then
					res1, res3 = L["Melee"], [[Interface\Icons\INV_Sword_04]]
				elseif spellid == 47882 or spellid == 27240 or spellid == 20761 or spellid == 20760 or spellid == 20759 or spellid == 20758 or spellid == 3026 then
					res3 = [[Interface\Icons\Spell_Shadow_Soulgem]]
				end
			end
		end
		return res1, res2, res3, res4, res5, res6, res7, res8, res9
	end

	function private.spell_link(spellid)
		if not customSpells[spellid] then
			return GetSpellLink(spellid)
		end
	end
end

-------------------------------------------------------------------------------
-- test mode

do
	local random = math.random
	local IsGroupInCombat = Skada.IsGroupInCombat
	local InCombatLockdown = InCombatLockdown
	local setPrototype = Skada.setPrototype
	local playerPrototype = Skada.playerPrototype

	local fakeSet, updateTimer = {}, nil

	-- there was no discrimination with classes and specs
	-- the only reason this group composition was made is
	-- to have all 10 classes displayed on windows.
	local fake_players
	do
		local playersTable = nil
		function fake_players()
			if not playersTable then
				playersTable = {
					-- Tanks & Healers
					{"Deafknight", "DEATHKNIGHT", "TANK", 250}, -- Blood Death Knight
					{"Bubbleboy", "PRIEST", "HEALER", 256}, -- Discipline Priest
					{"Channingtotem", "SHAMAN", "HEALER", 264}, -- Restoration Shaman
					-- Damagers
					{"Shiftycent", "DRUID", "DAMAGER", 102}, -- Balance Druid
					{"Beargrills", "HUNTER", "DAMAGER", 254}, -- Marksmanship Hunter
					{"Foodanddps", "MAGE", "DAMAGER", 63}, -- Fire Mage
					{"Retryhard", "PALADIN", "DAMAGER", 70}, -- Retribution Paladin
					{"Stabass", "ROGUE", "DAMAGER", 260}, -- Combat Rogue
					{"Summonbot", "WARLOCK", "DAMAGER", 266}, -- Demonology Warlock
					{"Chuggernaut", "WARRIOR", "DAMAGER", 72} -- Fury Warrior
				}
			end

			return playersTable
		end
	end

	local function generate_fake_data()
		wipe(fakeSet)
		fakeSet.name = "Fake Fight"
		fakeSet.starttime = time() - 120
		fakeSet.damage = 0
		fakeSet.heal = 0
		fakeSet.absorb = 0
		fakeSet.players = wipe(fakeSet.players or {})

		local players = fake_players()
		for i = 1, #players do
			local name, class, role, spec = players[i][1], players[i][2], players[i][3], players[i][4]
			local damage, heal, absorb = 0, 0, 0

			if role == "TANK" then
				damage = random(1e5, 1e5 * 2)
				heal = random(10000, 20000)
				absorb = random(5000, 100000)
			elseif role == "HEALER" then
				damage = random(1000, 3000)
				if spec == 256 then -- Discipline Priest
					heal = random(1e5, 1e5 * 2)
					absorb = random(1e6, 1e6 * 2)
				else -- Other healers
					heal = random(1e6, 1e6 * 2)
					absorb = random(1000, 5000)
				end
			else
				damage = random(1e6, 1e6 * 2)
				heal = random(250, 1500)
			end

			fakeSet.players[#fakeSet.players + 1] = {
				id = name,
				name = name,
				class = class,
				role = role,
				spec = spec,
				damage = damage,
				heal = heal,
				absorb = absorb
			}

			fakeSet.damage = fakeSet.damage + damage
			fakeSet.heal = fakeSet.heal + heal
			fakeSet.absorb = fakeSet.absorb + absorb
		end

		return setPrototype:Bind(fakeSet)
	end

	local function randomize_fake_data(set, coef)
		set.time = time() - set.starttime

		local players = set.players
		for i = 1, #players do
			local player = playerPrototype:Bind(players[i], set)
			if player then
				local damage, heal, absorb = 0, 0, 0

				if player.role == "HEALER" then
					damage = coef * random(0, 1500)
					if player.spec == 256 then
						heal = coef * random(500, 1500)
						absorb = coef * random(2500, 20000)
					else
						heal = coef * random(2500, 15000)
						absorb = coef * random(0, 150)
					end
				elseif player.role == "TANK" then
					damage = coef * random(1000, 10000)
					heal = coef * random(500, 1500)
					absorb = coef * random(1000, 1500)
				else
					damage = coef * random(8000, 18000)
					heal = coef * random(150, 1500)
				end

				player.damage = (player.damage or 0) + damage
				player.heal = (player.heal or 0) + heal
				player.absorb = (player.absorb or 0) + absorb

				set.damage = set.damage + damage
				set.heal = set.heal + heal
				set.absorb = set.absorb + absorb
			end
		end
	end

	local function update_fake_data(self)
		randomize_fake_data(self.current, self.db.profile.updatefrequency or 0.25)
		self:UpdateDisplay(true)
	end

	function Skada:TestMode()
		if InCombatLockdown() or IsGroupInCombat() then
			wipe(fakeSet)
			self.testMode = nil
			if updateTimer then
				self:CancelTimer(updateTimer)
				updateTimer = nil
			end
			self:CleanGarbage()
			return
		end
		self.testMode = not self.testMode
		if not self.testMode then
			wipe(fakeSet)
			if updateTimer then
				self:CancelTimer(updateTimer)
				updateTimer = nil
			end
			self.current = nil
			self:CleanGarbage()
			return
		end

		self:Wipe()
		self.current = generate_fake_data()
		updateTimer = self:ScheduleRepeatingTimer(update_fake_data, self.db.profile.updatefrequency or 0.25, self)
	end
end

-------------------------------------------------------------------------------
-- LibSharedMedia Helpers

do
	local LSM = LibStub("LibSharedMedia-3.0")

	function Skada:MediaFetch(mediatype, key, default)
		return (key and LSM:Fetch(mediatype, key)) or (default and LSM:Fetch(mediatype, default)) or default
	end

	function Skada:MediaList(mediatype)
		return LSM:HashTable(mediatype)
	end

	function private.register_medias()
		private.register_medias = nil -- remove it

		-- fonts
		LSM:Register("font", "ABF", [[Interface\Addons\Skada\Media\Fonts\ABF.ttf]])
		LSM:Register("font", "Accidental Presidency", [[Interface\Addons\Skada\Media\Fonts\Accidental Presidency.ttf]])
		LSM:Register("font", "Adventure", [[Interface\Addons\Skada\Media\Fonts\Adventure.ttf]])
		LSM:Register("font", "Diablo", [[Interface\Addons\Skada\Media\Fonts\Diablo.ttf]])
		LSM:Register("font", "Forced Square", [[Interface\Addons\Skada\Media\Fonts\FORCED SQUARE.ttf]])
		LSM:Register("font", "Hooge", [[Interface\Addons\Skada\Media\Fonts\Hooge.ttf]])

		-- statusbars
		LSM:Register("statusbar", "Aluminium", [[Interface\Addons\Skada\Media\Statusbar\Aluminium]])
		LSM:Register("statusbar", "Armory", [[Interface\Addons\Skada\Media\Statusbar\Armory]])
		LSM:Register("statusbar", "BantoBar", [[Interface\Addons\Skada\Media\Statusbar\BantoBar]])
		LSM:Register("statusbar", "Flat", [[Interface\Addons\Skada\Media\Statusbar\Flat]])
		LSM:Register("statusbar", "Gloss", [[Interface\Addons\Skada\Media\Statusbar\Gloss]])
		LSM:Register("statusbar", "Graphite", [[Interface\Addons\Skada\Media\Statusbar\Graphite]])
		LSM:Register("statusbar", "Grid", [[Interface\Addons\Skada\Media\Statusbar\Grid]])
		LSM:Register("statusbar", "Healbot", [[Interface\Addons\Skada\Media\Statusbar\Healbot]])
		LSM:Register("statusbar", "LiteStep", [[Interface\Addons\Skada\Media\Statusbar\LiteStep]])
		LSM:Register("statusbar", "Minimalist", [[Interface\Addons\Skada\Media\Statusbar\Minimalist]])
		LSM:Register("statusbar", "Otravi", [[Interface\Addons\Skada\Media\Statusbar\Otravi]])
		LSM:Register("statusbar", "Outline", [[Interface\Addons\Skada\Media\Statusbar\Outline]])
		LSM:Register("statusbar", "Round", [[Interface\Addons\Skada\Media\Statusbar\Round]])
		LSM:Register("statusbar", "Serenity", [[Interface\AddOns\Skada\Media\Statusbar\Serenity]])
		LSM:Register("statusbar", "Smooth", [[Interface\Addons\Skada\Media\Statusbar\Smooth]])
		LSM:Register("statusbar", "Solid", [[Interface\Buttons\WHITE8X8]])
		LSM:Register("statusbar", "TukTex", [[Interface\Addons\Skada\Media\Statusbar\TukTex]])

		-- borders
		LSM:Register("border", "Glow", [[Interface\Addons\Skada\Media\Border\Glow]])
		LSM:Register("border", "Roth", [[Interface\Addons\Skada\Media\Border\Roth]])

		-- sounds
		LSM:Register("sound", "Cartoon FX", [[Sound\Doodad\Goblin_Lottery_Open03.wav]])
		LSM:Register("sound", "Cheer", [[Sound\Event Sounds\OgreEventCheerUnique.wav]])
		LSM:Register("sound", "Explosion", [[Sound\Doodad\Hellfire_Raid_FX_Explosion05.wav]])
		LSM:Register("sound", "Fel Nova", [[Sound\Spells\SeepingGaseous_Fel_Nova.wav]])
		LSM:Register("sound", "Fel Portal", [[Sound\Spells\Sunwell_Fel_PortalStand.wav]])
		LSM:Register("sound", "Humm", [[Sound\Spells\SimonGame_Visual_GameStart.wav]])
		LSM:Register("sound", "Rubber Ducky", [[Sound\Doodad\Goblin_Lottery_Open01.wav]])
		LSM:Register("sound", "Shing!", [[Sound\Doodad\PortcullisActive_Closed.wav]])
		LSM:Register("sound", "Short Circuit", [[Sound\Spells\SimonGame_Visual_BadPress.wav]])
		LSM:Register("sound", "Simon Chime", [[Sound\Doodad\SimonGame_LargeBlueTree.wav]])
		LSM:Register("sound", "War Drums", [[Sound\Event Sounds\Event_wardrum_ogre.wav]])
		LSM:Register("sound", "Wham!", [[Sound\Doodad\PVP_Lordaeron_Door_Open.wav]])
		LSM:Register("sound", "You Will Die!", [[Sound\Creature\CThun\CThunYouWillDIe.wav]])
	end
end

-------------------------------------------------------------------------------
-- Notifications stuff!

do
	local LibToast = LibStub("SpecializedLibToast-1.0", true)
	local toast_opt = nil

	-- initialize LibToast
	function private.register_toast()
		private.register_toast = nil -- remove it
		if not LibToast then return end

		-- install default options
		local P = Skada.db.profile
		if not P.toast then
			P.toast = Skada.defaults.toast
		end

		LibToast:Register("SkadaToastFrame", function(toast, text, title, icon, urgency)
			toast:SetTitle(title or folder)
			toast:SetText(text or L["A damage meter."])
			toast:SetIconTexture(icon or Skada.logo)
			toast:SetUrgencyLevel(urgency or "normal")
		end)
		if P.toast then
			LibToast.config.hide_toasts = P.toast.hide_toasts
			LibToast.config.spawn_point = P.toast.spawn_point or "TOP"
			LibToast.config.duration = P.toast.duration or 7
			LibToast.config.opacity = P.toast.opacity or 0.75
		end
	end

	-- returns toast options
	function private.toast_options()
		private.toast_options = nil -- remove it

		if not LibToast or toast_opt then
			return toast_opt
		end

		toast_opt = {
			type = "group",
			name = L["Notifications"],
			get = function(i)
				return Skada.db.profile.toast[i[#i]] or LibToast.config[i[#i]]
			end,
			set = function(i, val)
				Skada.db.profile.toast[i[#i]] = val
				LibToast.config[i[#i]] = val
			end,
			order = 990,
			args = {
				toastdesc = {
					type = "description",
					name = L["opt_toast_desc"],
					fontSize = "medium",
					width = "full",
					order = 0
				},
				empty_1 = {
					type = "description",
					name = " ",
					width = "full",
					order = 1
				},
				hide_toasts = {
					type = "toggle",
					name = L["Disable"],
					order = 10
				},
				spawn_point = {
					type = "select",
					name = L["Position"],
					order = 20,
					values = {
						TOPLEFT = L["Top Left"],
						TOPRIGHT = L["Top Right"],
						BOTTOMLEFT = L["Bottom Left"],
						BOTTOMRIGHT = L["Bottom Right"],
						TOP = L["Top"],
						BOTTOM = L["Bottom"],
						LEFT = L["Left"],
						RIGHT = L["Right"]
					}
				},
				duration = {
					type = "range",
					name = L["Duration"],
					min = 5,
					max = 15,
					step = 1,
					order = 30
				},
				opacity = {
					type = "range",
					name = L["Opacity"],
					min = 0,
					max = 1,
					step = 0.01,
					isPercent = true,
					order = 40
				},
				empty_2 = {
					type = "description",
					name = " ",
					width = "full",
					order = 50
				},
				test = {
					type = "execute",
					name = L["Test Notifications"],
					func = function() Skada:Notify() end,
					disabled = function() return Skada.db.profile.toast.hide_toasts end,
					width = "double",
					order = 60
				}
			}
		}

		return toast_opt
	end

	-- shows notifications or simply uses Print method.
	function Skada:Notify(text, title, icon, urgency)
		if not (LibToast and LibToast:Spawn("SkadaToastFrame", text, title, icon, urgency)) then
			self:Print(text)
		end
	end
end

-------------------------------------------------------------------------------
-- Total segment stuff!

do
	local total_opt = nil

	function private.total_options()
		private.total_options = nil -- remove it

		if total_opt then
			return total_opt
		end

		local values = {al = 0x10, rb = 0x01, rt = 0x02, db = 0x04, dt = 0x08}
		local disabled = function()
			return band(Skada.db.profile.totalflag, values.al) ~= 0
		end

		total_opt = {
			type = "group",
			name = L["Total Segment"],
			desc = format(L["Options for %s."], L["Total Segment"]),
			order = 970,
			args = {
				collection = {
					type = "group",
					name = L["Data Collection"],
					inline = true,
					order = 10,
					get = function(i)
						return (band(Skada.db.profile.totalflag, values[i[#i]]) ~= 0)
					end,
					set = function(i, val)
						local v = values[i[#i]]
						if val and band(Skada.db.profile.totalflag, v) == 0 then
							Skada.db.profile.totalflag = Skada.db.profile.totalflag + v
						elseif not val and band(Skada.db.profile.totalflag, v) ~= 0 then
							Skada.db.profile.totalflag = Skada.db.profile.totalflag - v
						end
					end,
					args = {
						al = {
							type = "toggle",
							name = L["All Segments"],
							desc = L["opt_tweaks_total_all_desc"],
							width = "full",
							order = 10
						},
						rb = {
							type = "toggle",
							name = L["Raid Bosses"],
							desc = format(L["opt_tweaks_total_fmt_desc"], L["Raid Bosses"]),
							order = 20,
							disabled = disabled
						},
						rt = {
							type = "toggle",
							name = L["Raid Trash"],
							desc = format(L["opt_tweaks_total_fmt_desc"], L["Raid Trash"]),
							order = 30,
							disabled = disabled
						},
						db = {
							type = "toggle",
							name = L["Dungeon Bosses"],
							desc = format(L["opt_tweaks_total_fmt_desc"], L["Dungeon Bosses"]),
							order = 40,
							disabled = disabled
						},
						dt = {
							type = "toggle",
							name = L["Dungeon Trash"],
							desc = format(L["opt_tweaks_total_fmt_desc"], L["Dungeon Trash"]),
							order = 50,
							disabled = disabled
						}
					}
				},
				totalidc = {
					type = "toggle",
					name = L["Detailed total segment"],
					desc = L["opt_tweaks_total_full_desc"],
					order = 20
				}
			}
		}

		return total_opt
	end

	function private.total_noclick(set, mode)
		return (not Skada.db.profile.totalidc and set == "total" and type(mode) == "table" and mode.nototal == true)
	end

	local function total_record(set)
		local totalflag = Skada.total and set and Skada.db.profile.totalflag

		-- something missing
		if not totalflag then
			return false
		end

		-- raid bosses - 0x01
		if band(totalflag, 0x01) ~= 0 then
			if set.type == "raid" and set.gotboss then
				return true
			end
		end

		-- raid trash - 0x02
		if band(totalflag, 0x02) ~= 0 then
			if set.type == "raid" and not set.gotboss then
				return true
			end
		end

		-- dungeon boss - 0x04
		if band(totalflag, 0x04) ~= 0 then
			if set.type == "party" and set.gotboss then
				return true
			end
		end

		-- dungeon trash - 0x08
		if band(totalflag, 0x08) ~= 0 then
			if set.type == "party" and not set.gotboss then
				return true
			end
		end

		-- any combat - 0x10
		if band(totalflag, 0x10) ~= 0 then
			return true
		end

		-- battlegrouns/arenas or nothing
		return (set.type == "pvp" or set.type == "arena")
	end

	function Skada:DispatchSets(func, ...)
		if not self.current or type(func) ~= "function" then return end

		func(self.current, ...) -- record to current
		if total_record(self.current) then -- record to total
			func(self.total, ...)
		end

		-- record to phases
		if not self.tempsets then return end
		for i = 1, #self.tempsets do
			local set = self.tempsets[i]
			if set and not set.stopped then
				func(set, ...)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- units fix function.
--
-- on certain servers, certain spells are not assigned properly and
-- in order to work around this, these functions were added.
--
-- for example, Death Knight' "Mark of Blood" healing is not considered
-- by Skada because the healing is attributed to the boss and not to the
-- player who used the spell, so in some modules you will find a table
-- called "queued_spells" in which you can store a table of [spellid] = spellid
-- used by other modules.
-- In the case of "Mark of Blood" (49005), the healing from the spell 50424
-- is attributed to the target instead of the DK, so whenever Skada detects
-- a healing from 50424 it will check queued units, if found the player data
-- will be used.

do
	local new, del, tLength = Skada.newTable, Skada.delTable, Skada.tLength
	local queued_units = nil

	function Skada:QueueUnit(spellid, srcGUID, srcName, srcFlags, dstGUID)
		if spellid and srcName and srcGUID and dstGUID and srcGUID ~= dstGUID then
			queued_units = queued_units or T.get("Skada_QueuedUnits")
			queued_units[spellid] = queued_units[spellid] or new()
			queued_units[spellid][dstGUID] = queued_units[spellid][dstGUID] or new()
			queued_units[spellid][dstGUID].id = srcGUID
			queued_units[spellid][dstGUID].name = srcName
			queued_units[spellid][dstGUID].flag = srcFlags
		end
	end

	function Skada:UnqueueUnit(spellid, dstGUID)
		if spellid and dstGUID and queued_units and queued_units[spellid] then
			if queued_units[spellid][dstGUID] then
				queued_units[spellid][dstGUID] = del(queued_units[spellid][dstGUID])
			end
			if tLength(queued_units[spellid]) == 0 then
				queued_units[spellid] = del(queued_units[spellid])
			end
		end
	end

	function Skada:FixUnit(spellid, guid, name, flag)
		if spellid and guid and queued_units and queued_units[spellid] and queued_units[spellid][guid] then
			flag = queued_units[spellid][guid].flag or flag
			name = queued_units[spellid][guid].name or name
			guid = queued_units[spellid][guid].id or guid
		end
		return guid, name, flag
	end

	function private.is_queued_unit(guid)
		if queued_units and tonumber(guid) then
			for _, units in pairs(queued_units) do
				for id, _ in pairs(units) do
					if id == guid then
						return true
					end
				end
			end
		end
		return false
	end

	function private.clear_queued_units()
		T.free("Skada_QueuedUnits", queued_units, nil, del, true)
	end
end

-------------------------------------------------------------------------------
-- frame borders

function Skada:ApplyBorder(frame, texture, color, thickness, padtop, padbottom, padleft, padright)
	if not frame.borderFrame then
		frame.borderFrame = CreateFrame("Frame", "$parentBorder", frame)
		frame.borderFrame:SetFrameLevel(frame:GetFrameLevel() - 1)
	end

	thickness = thickness or 0
	padtop = padtop or 0
	padbottom = padbottom or padtop
	padleft = padleft or padtop
	padright = padright or padtop

	frame.borderFrame:SetPoint("TOPLEFT", frame, -thickness - padleft, thickness + padtop)
	frame.borderFrame:SetPoint("BOTTOMRIGHT", frame, thickness + padright, -thickness - padbottom)

	local borderbackdrop = T.get("Skada_BorderBackdrop")
	borderbackdrop.edgeFile = (texture and thickness > 0) and self:MediaFetch("border", texture) or nil
	borderbackdrop.edgeSize = thickness
	frame.borderFrame:SetBackdrop(borderbackdrop)
	T.free("Skada_BorderBackdrop", borderbackdrop)
	if color then
		frame.borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, color.a)
	end
end

-------------------------------------------------------------------------------
-- data serialization

do
	local AS = LibStub("AceSerializer-3.0")
	local LC = LibStub("LibCompress")
	local LD = LibStub("LibDeflate")
	local LL = {level = 9}

	local encodeTable = nil

	function private.serialize(hex, title, ...)
		local result = LD:CompressDeflate(AS:Serialize(...), LL)
		if hex then
			return LD:EncodeForPrint(result)
		end
		return LD:EncodeForWoWChatChannel(result)
	end

	function private.deserialize(data, hex)
		local result = hex and LD:DecodeForPrint(data) or LD:DecodeForWoWChatChannel(data)
		result = result and LD:DecompressDeflate(result) or nil
		if result then
			return AS:Deserialize(result)
		end

		-- backwards compatibility
		local err
		if hex then
			data, err = Skada.HexDecode(data)
		else
			encodeTable = encodeTable or LC:GetAddonEncodeTable()
			data, err = encodeTable:Decode(data), "Error decoding"
		end

		if data then
			data, err = LC:DecompressHuffman(data)
			if data then
				return AS:Deserialize(data)
			end
		end
		return false, err
	end
end

-------------------------------------------------------------------------------
-- addon communication

do
	local UnitIsConnected = UnitIsConnected
	local IsInGroup, IsInRaid = Skada.IsInGroup, Skada.IsInRaid
	local collectgarbage = collectgarbage

	local function create_progress_window()
		local frame = CreateFrame("Frame", "SkadaProgressWindow", UIParent)
		frame:SetFrameStrata("TOOLTIP")

		local elem = frame:CreateTexture(nil, "BORDER")
		elem:SetTexture([[Interface\Buttons\WHITE8X8]])
		elem:SetVertexColor(0, 0, 0, 1)
		elem:SetPoint("TOPLEFT")
		elem:SetPoint("RIGHT")
		elem:SetHeight(25)
		frame.head = elem

		elem = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		elem:SetJustifyH("CENTER")
		elem:SetJustifyV("MIDDLE")
		elem:SetPoint("TOPLEFT", frame.head, "TOPLEFT", 25, 0)
		elem:SetPoint("BOTTOMRIGHT", frame.head, "BOTTOMRIGHT", -25, 0)
		elem:SetText(L["Progress"])
		frame.title = elem

		elem = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		elem:SetWidth(24)
		elem:SetHeight(24)
		elem:SetPoint("RIGHT", frame.head, "RIGHT", -4, 0)
		frame.close = elem

		elem = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		elem:SetJustifyH("CENTER")
		elem:SetJustifyV("MIDDLE")
		elem:SetPoint("TOPLEFT", frame.head, "BOTTOMLEFT", 0, -10)
		elem:SetPoint("TOPRIGHT", frame.head, "BOTTOMRIGHT", 0, -10)
		frame.text = elem

		elem = CreateFrame("StatusBar", nil, frame)
		elem:SetMinMaxValues(0, 100)
		elem:SetPoint("TOPLEFT", frame.text, "BOTTOMLEFT", 20, -15)
		elem:SetPoint("TOPRIGHT", frame.text, "BOTTOMRIGHT", -20, -15)
		elem:SetHeight(5)
		elem:SetStatusBarTexture([[Interface\AddOns\Skada\Media\Statusbar\Flat.tga]])
		elem:SetStatusBarColor(0, 1, 0)
		frame.bar = elem

		elem = frame.bar:CreateTexture(nil, "BACKGROUND")
		elem:SetTexture([[Interface\Buttons\WHITE8X8]])
		elem:SetVertexColor(1, 1, 1, 0.2)
		elem:SetAllPoints(true)

		elem = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		elem:SetPoint("TOP", frame.bar, "BOTTOM", 0, -15)
		frame.size = elem

		frame:SetBackdrop {
			bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
			edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
			edgeSize = 16,
			insets = {left = 4, right = 4, top = 4, bottom = 4}
		}
		frame:SetBackdropColor(0, 0, 0, 0.6)
		frame:SetBackdropBorderColor(0, 0, 0, 1)
		frame:SetPoint("CENTER", 0, 0)
		frame:SetWidth(360)
		frame:SetHeight(110)

		frame:SetScript("OnShow", function(self)
			self.size:SetText(format(L["Data Size: \124cffffffff%.1f\124rKB"], self.total / 1000))
		end)

		frame:SetScript("OnHide", function(self)
			self.total = 0
			self.text:SetText(self.fmt)
			self.size:SetText("")
			self.bar:SetValue(0)
			collectgarbage()
		end)

		frame.fmt = L["Transmision Progress: %02.f%%"]
		frame:Hide()
		return frame
	end

	local function show_progress_window(self, sent, total)
		local progress = self.ProgressWindow or create_progress_window()
		self.ProgressWindow = progress
		if not progress:IsShown() then
			progress.total = total
			progress:Show()
		end

		if sent < total then
			local p = sent * 100 / total
			progress.text:SetText(format(progress.fmt, p))
			progress.bar:SetValue(p)
		else
			progress.text:SetText(L["Transmission Completed"])
			progress.bar:SetValue(100)
		end
	end

	-- "PURR" is a special key to whisper with progress window.
	local function send_comm_message(self, channel, target, ...)
		if target == self.userName then
			return -- to yourself? really...
		elseif channel ~= "WHISPER" and channel ~= "PURR" and not IsInGroup() then
			return -- only for group members!
		elseif (channel == "WHISPER" or channel == "PURR") and not (target and UnitIsConnected(target)) then
			return -- whisper target must be connected!
		end

		-- not channel provided?
		if not channel then
			channel = IsInRaid() and "RAID" or "PARTY" -- default

			-- arena or battlegrounds?
			if self.insType == "pvp" or self.insType == "arena" then
				channel = "BATTLEGROUND"
			end
		end

		if channel == "PURR" then
			self:SendCommMessage(folder, private.serialize(nil, nil, ...), "WHISPER", target, "NORMAL", show_progress_window, self)
		elseif channel then
			self:SendCommMessage(folder, private.serialize(nil, nil, ...), channel, target)
		end
	end

	local function dispatch_comm(sender, ok, const, ...)
		if ok and Skada.comms and type(const) == "string" and Skada.comms[const] then
			for self, funcs in pairs(Skada.comms[const]) do
				for func in pairs(funcs) do
					if type(self[func]) == "function" then
						self[func](self, sender, ...)
					elseif type(func) == "function" then
						func(sender, ...)
					end
				end
			end
		end
	end

	local function on_comm_received(self, prefix, message, channel, sender)
		if prefix == folder and channel and sender and sender ~= self.userName then
			dispatch_comm(sender, private.deserialize(message))
		end
	end

	function Skada:RegisterComms(enable)
		if enable then
			self.SendComm = send_comm_message
			self.OnCommReceived = on_comm_received
			self:RegisterComm(folder)
			self:AddComm("VersionCheck")
		else
			self.SendComm = self.EmptyFunc
			self.OnCommReceived = self.EmptyFunc
			self:UnregisterAllComm()
			self:RemoveAllComms()
		end

		self.callbacks:Fire("Skada_UpdateComms", enable)
	end

	function Skada.AddComm(self, const, func)
		if self and const then
			Skada.comms = Skada.comms or {}
			Skada.comms[const] = Skada.comms[const] or {}
			Skada.comms[const][self] = Skada.comms[const][self] or {}
			Skada.comms[const][self][func or const] = true
		end
	end

	function Skada.RemoveComm(self, func)
		if self and Skada.comms then
			for const, selfs in pairs(Skada.comms) do
				if selfs[self] then
					selfs[self][func] = nil

					-- remove the table if empty
					if next(selfs[self]) == nil then
						selfs[self] = nil
					end

					break
				end
			end
		end
	end

	function Skada.RemoveAllComms(self)
		if self and Skada.comms then
			for const, selfs in pairs(Skada.comms) do
				for _self in pairs(selfs) do
					if self == _self then
						selfs[self] = nil
						break
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- instance difficulty

do
	local GetRaidDifficulty = GetRaidDifficulty
	local GetDungeonDifficulty = GetDungeonDifficulty

	function Skada:GetInstanceDiff()
		local _, insType, diff, _, count, dynDiff, isDynamic = GetInstanceInfo()
		if insType == "none" then
			return diff == 1 and "wb" or "NaN" -- World Boss
		elseif insType == "raid" and isDynamic then
			if diff == 1 or diff == 3 then
				return (dynDiff == 0) and "10n" or (dynDiff == 1) and "10h" or "NaN"
			elseif diff == 2 or diff == 4 then
				return (dynDiff == 0) and "25n" or (dynDiff == 1) and "25h" or "NaN"
			end
		elseif insType then
			if diff == 1 then
				local comp_diff = GetRaidDifficulty()
				if diff ~= comp_diff and (comp_diff == 2 or comp_diff == 4) then
					return "tw" -- timewalker
				else
					return count and format("%dn", count) or "10n"
				end
			else
				return diff == 2 and "25n" or diff == 3 and "10h" or diff == 4 and "25h" or "NaN"
			end
		elseif insType == "party" then
			if diff == 1 then
				return "5n"
			elseif diff == 2 then
				local comp_diff = GetDungeonDifficulty()
				return comp_diff == 3 and "mc" or "5h" -- mythic or heroic 5man
			end
		end
	end
end
