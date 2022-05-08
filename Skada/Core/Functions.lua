local Skada = Skada

local L = LibStub("AceLocale-3.0"):GetLocale("Skada")

local select, pairs = select, pairs
local tostring, tonumber, format = tostring, tonumber, string.format
local setmetatable, getmetatable, wipe, band = setmetatable, getmetatable, wipe, bit.band
local print = print

local GetNumRaidMembers, GetNumPartyMembers = GetNumRaidMembers, GetNumPartyMembers
local UnitExists, UnitGUID, UnitClass = UnitExists, UnitGUID, UnitClass
local UnitAffectingCombat, UnitIsDeadOrGhost = UnitAffectingCombat, UnitIsDeadOrGhost
local GetSpellInfo, GetSpellLink = GetSpellInfo, GetSpellLink
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetClassFromGUID = Skada.GetClassFromGUID
local T = Skada.Table

local COMBATLOG_OBJECT_TYPE_NPC = COMBATLOG_OBJECT_TYPE_NPC or 0x00000800

-------------------------------------------------------------------------------
-- debug function

function Skada:Debug(...)
	if self.db.profile.debug then
		print("|cff33ff99Skada Debug|r:", ...)
	end
end

-------------------------------------------------------------------------------
-- Classes, Specs and Schools

function Skada:RegisterClasses()
	self.RegisterClasses = nil -- remove it

	-- class colors & coordinates
	self.classcolors, self.classcoords = self.GetClassColorsTable()

	-- valid classes!
	self.validclass = {}
	for class, classTable in pairs(self.classcolors) do
		self.validclass[class] = true
		-- localized class names.
		L[class] = classTable.className
	end

	-- Skada custom class colors!
	self.classcolors.BOSS = {r = 0.203, g = 0.345, b = 0.525, colorStr = "ff345886"}
	self.classcolors.ENEMY = {r = 0.94117, g = 0, b = 0.0196, colorStr = "fff00005"}
	self.classcolors.MONSTER = {r = 0.549, g = 0.388, b = 0.404, colorStr = "ff8c6367"}
	self.classcolors.PET = {r = 0.3, g = 0.4, b = 0.5, colorStr = "ff4c0566"}
	self.classcolors.PLAYER = {r = 0.94117, g = 0, b = 0.0196, colorStr = "fff00005"}
	self.classcolors.UNKNOWN = {r = 0.2, g = 0.2, b = 0.2, colorStr = "ff333333"}

	setmetatable(self.classcolors, {__call = function(t, class, arg)
		local color = HIGHLIGHT_FONT_COLOR
		if class and t[class] then
			color = t[class]
			-- using a custom color?
			if Skada.db.profile.usecustomcolors and Skada.db.profile.customcolors and Skada.db.profile.customcolors[class] then
				color = Skada.db.profile.customcolors[class]
			end
		end
		-- missing colorStr?
		if not color.colorStr then
			color.colorStr = Skada.RGBPercToHex(color.r, color.g, color.b, true)
		end

		return (arg == nil) and color or (type(arg) == "string") and format("|c%s%s|r", color.colorStr, arg) or color.colorStr
	end})

	-- set classes icon file & Skada custom classes.
	if self.AscensionCoA then
		self.classicons = [[Interface\AddOns\Skada\Media\Textures\icon-classes-coa]]

		-- custom class coordinates
		if not self.classcoords.BOSS then
			self.classcoords.BOSS = {0, 0.125, 0.875, 1}
			self.classcoords.MONSTER = {0.125, 0.25, 0.875, 1}
			self.classcoords.ENEMY = {0.25, 0.375, 0.875, 1}
			self.classcoords.PET = {0.375, 0.5, 0.875, 1}
			self.classcoords.UNKNOWN = {0.5, 0.625, 0.875, 1}
			self.classcoords.PLAYER = {0.625, 0.75, 0.875, 1}
		end
	else
		self.classicons = [[Interface\AddOns\Skada\Media\Textures\icon-classes]]

		-- custom class coordinates
		if not self.classcoords.BOSS then
			self.classcoords.BOSS = {0.5, 0.75, 0.5, 0.75}
			self.classcoords.MONSTER = {0.75, 1, 0.5, 0.75}
			self.classcoords.ENEMY = {0, 0.25, 0.75, 1}
			self.classcoords.PET = {0.25, 0.5, 0.75, 1}
			self.classcoords.PLAYER = {0.75, 1, 0.75, 1}
			self.classcoords.UNKNOWN = {0.5, 0.75, 0.75, 1}
		end
	end

	-- common metatable for coordinates tables.
	local coords_mt = {__call = function(t, key)
		if key and t[key] then
			return t[key][1], t[key][2], t[key][3], t[key][4]
		end
		return 0, 1, 0, 1
	end}
	setmetatable(self.classcoords, coords_mt)

	-- we ignore roles & specs on Project Ascension since players
	-- have a custom module to set their own colors & icons.
	if not self.Ascension and not self.AscensionCoA then
		-- role icon file and texture coordinates
		self.roleicons = [[Interface\AddOns\Skada\Media\Textures\icon-roles]]
		self.rolecoords = setmetatable({
			LEADER = {0, 0.25, 0, 1},
			DAMAGER = {0.25, 0.5, 0, 1},
			TANK = {0.5, 0.75, 0, 1},
			HEALER = {0.75, 1, 0, 1},
			NONE = ""
		}, coords_mt)

		-- specialization icons
		self.specicons = [[Interface\AddOns\Skada\Media\Textures\icon-specs]]
		self.speccoords = setmetatable({
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
	end

	-- customize class colors
	if not self.Ascension or not self.AscensionCoA then
		local disabled = function()
			return not self.db.profile.usecustomcolors
		end

		local colorsOpt = {
			type = "group",
			name = L["Colors"],
			desc = format(L["Options for %s."], L["Colors"]),
			order = 1000,
			get = function(i)
				local color = self.classcolors[i[#i]]
				if self.db.profile.customcolors and self.db.profile.customcolors[i[#i]] then
					color = self.db.profile.customcolors[i[#i]]
				end
				return color.r, color.g, color.b
			end,
			set = function(i, r, g, b)
				local class = i[#i]
				self.db.profile.customcolors = self.db.profile.customcolors or {}
				self.db.profile.customcolors[class] = self.db.profile.customcolors[class] or {}
				self.db.profile.customcolors[class].r = r
				self.db.profile.customcolors[class].g = g
				self.db.profile.customcolors[class].b = b
				self.db.profile.customcolors[class].colorStr = self.RGBPercToHex(r, g, b, true)
			end,
			args = {
				enable = {
					type = "toggle",
					name = L["Enable"],
					width = "double",
					order = 10,
					get = function()
						return self.db.profile.usecustomcolors
					end,
					set = function(_, val)
						if val then
							self.db.profile.usecustomcolors = true
						else
							self.db.profile.usecustomcolors = nil
							self.db.profile.customcolors = nil -- free it
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
						self.db.profile.customcolors = wipe(self.db.profile.customcolors or {})
					end
				}
			}
		}

		for class, data in pairs(self.classcolors) do
			if self.validclass[class] then
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

		self.options.args.tweaks.args.advanced.args.colors = colorsOpt
	end
end

function Skada:RegisterSchools()
	self.RegisterSchools = nil -- remove it
	self.spellschools = self.spellschools or {}

	-- handles adding spell schools
	local function add_school(key, name, r, g, b)
		if key and name and not self.spellschools[key] then
			self.spellschools[key] = {r = r or 1, g = g or 1, b = b or 1, name = name:match("%((.+)%)") or name}
		end
	end

	-- main school
	local SCHOOL_PHYSICAL = SCHOOL_MASK_PHYSICAL or 0x01 -- Physical
	local SCHOOL_HOLY = SCHOOL_MASK_HOLY or 0x02 -- Holy
	local SCHOOL_FIRE = SCHOOL_MASK_FIRE or 0x04 -- Fire
	local SCHOOL_NATURE = SCHOOL_MASK_NATURE or 0x08 -- Nature
	local SCHOOL_FROST = SCHOOL_MASK_FROST or 0x10 -- Frost
	local SCHOOL_SHADOW = SCHOOL_MASK_SHADOW or 0x20 -- Shadow
	local SCHOOL_ARCANE = SCHOOL_MASK_ARCANE or 0x40 -- Arcane

	-- Single Schools
	add_school(SCHOOL_PHYSICAL, STRING_SCHOOL_PHYSICAL, 1, 1, 0) -- Physical
	add_school(SCHOOL_HOLY, STRING_SCHOOL_HOLY, 1, 0.9, 0.5) -- Holy
	add_school(SCHOOL_FIRE, STRING_SCHOOL_FIRE, 1, 0.5, 0) -- Fire
	add_school(SCHOOL_NATURE, STRING_SCHOOL_NATURE, 0.3, 1, 0.3) -- Nature
	add_school(SCHOOL_FROST, STRING_SCHOOL_FROST, 0.5, 1, 1) -- Frost
	add_school(SCHOOL_SHADOW, STRING_SCHOOL_SHADOW, 0.5, 0.5, 1) -- Shadow
	add_school(SCHOOL_ARCANE, STRING_SCHOOL_ARCANE, 1, 0.5, 1) -- Arcane

	-- Multiple Schools (can be extended if needed)
	add_school(SCHOOL_FIRE + SCHOOL_FROST, STRING_SCHOOL_FROSTFIRE, 0.5, 1, 1) -- Frostfire
	add_school(SCHOOL_PHYSICAL + SCHOOL_SHADOW, STRING_SCHOOL_SHADOWSTRIKE, 0.5, 0.5, 1) -- Shadowstrike

	setmetatable(self.spellschools, {__call = function(t, school)
		if school and t[school] then
			return t[school].name, t[school].r, t[school].g, t[school].b
		end
		return L["Unknown"], 1, 1, 1
	end})
end

-------------------------------------------------------------------------------
-- creates generic dialog

function Skada:ConfirmDialog(text, accept, cancel, override)
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
	local LBI = LibStub("LibBossIDs-1.0")
	local creatureToFight = Skada.creatureToFight or Skada.dummyTable
	local creatureToBoss = Skada.creatureToBoss or Skada.dummyTable

	-- checks if the provided guid is a boss
	-- returns a boolean, boss id and boss name
	function Skada:IsBoss(guid, name)
		local id = self.GetCreatureId(guid)

		if LBI.BossIDs[id] or creatureToFight[id] or creatureToBoss[id] then
			-- should fix id?
			if creatureToBoss[id] and creatureToBoss[id] ~= true then
				id = creatureToBoss[id]
			end

			-- should fix name?
			if creatureToFight[id] and name ~= creatureToFight[id] then
				name = creatureToFight[id]
			end

			return true, id, name
		end

		return false, (self:IsCreature(guid) and id or 0), name
	end
end

function Skada:IsCreature(guid, flag)
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

function Skada.unitClass(guid, flag, set, db, name)
	set = set or Skada.current
	if set then
		-- an existing player
		for i = 1, #set.players do
			local p = set.players[i]
			if p and p.id == guid then
				return p.class, p.role, p.spec
			elseif p and name and p.name == name and p.class and Skada.validclass[p.class] then
				return p.class, p.role, p.spec
			end
		end
		if set.enemies then
			for i = 1, #set.enemies do
				local e = set.enemies[i]
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
	elseif Skada:IsBoss(guid) then
		class = "BOSS"
	elseif Skada:IsCreature(guid, flag) then
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
	local customSpells = {
		[3] = {ACTION_ENVIRONMENTAL_DAMAGE_FALLING, [[Interface\Icons\ability_rogue_quickrecovery]]},
		[4] = {ACTION_ENVIRONMENTAL_DAMAGE_DROWNING, [[Interface\Icons\spell_shadow_demonbreath]]},
		[5] = {ACTION_ENVIRONMENTAL_DAMAGE_FATIGUE, [[Interface\Icons\ability_creature_cursed_05]]},
		[6] = {ACTION_ENVIRONMENTAL_DAMAGE_FIRE, [[Interface\Icons\spell_fire_fire]]},
		[7] = {ACTION_ENVIRONMENTAL_DAMAGE_LAVA, [[Interface\Icons\spell_shaman_lavaflow]]},
		[8] = {ACTION_ENVIRONMENTAL_DAMAGE_SLIME, [[Interface\Icons\inv_misc_slime_01]]}
	}

	function Skada.GetSpellInfo(spellid)
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
				end
			end
		end
		return res1, res2, res3, res4, res5, res6, res7, res8, res9
	end

	function Skada.GetSpellLink(spellid)
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
	local FakePlayers
	do
		local playersTable = nil
		function FakePlayers()
			if not playersTable and Skada.AscensionCoA then
				playersTable = {
					{"Necromancer", "NECROMANCER"},
					{"Sun Cleric", "SUNCLERIC"},
					{"Starcaller", "STARCALLER"},
					{"Reaper", "REAPER"},
					{"Tinker", "TINKER"},
					{"Stormbringer", "STORMBRINGER"},
					{"Knight of Xoroth", "FLESHWARDEN"},
					{"Barbarian", "BARBARIAN"},
					{"Cultist", "CULTIST"},
					{"Pyromancer", "PYROMANCER"},
					{"Ranger", "RANGER"},
					{"Runemaster", "SPIRITMAGE"},
					{"Demon Hunter", "DEMONHUNTER"},
					{"Guardian", "GUARDIAN"},
					{"Witch Hunter", "WITCHHUNTER"},
					{"Son of Arugal", "SONOFARUGAL"},
					{"Monk", "MONK"},
					{"Chronomancer", "CHRONOMANCER"},
					{"Venomancer", "PROPHET"},
					{"Primalist", "WILDWALKER"},
					{"Witch Doctor", "WITCHDOCTOR"}
				}
			elseif not playersTable then
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

	local function GenerateFakeData()
		wipe(fakeSet)
		fakeSet.name = "Fake Fight"
		fakeSet.starttime = time() - 120
		fakeSet.endtime = time()
		fakeSet.damage = 0
		fakeSet.heal = 0
		fakeSet.absorb = 0
		fakeSet.players = wipe(fakeSet.players or {})

		local players = FakePlayers()
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

	local function RandomizeFakeData(set, coef)
		for i = 1, #set.players do
			local player = playerPrototype:Bind(set.players[i], set)
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
		self.current = GenerateFakeData()
		updateTimer = self:ScheduleRepeatingTimer(function()
			RandomizeFakeData(self.current, self.db.profile.updatefrequency or 0.25)
			self:UpdateDisplay(true)
		end, self.db.profile.updatefrequency or 0.25)
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

	function Skada:RegisterMedia(mediatype, key, path)
		LSM:Register(mediatype, key, path)
	end

	function Skada:RegisterMedias()
		self.RegisterMedias = nil -- remove it

		-- fonts
		LSM:Register("font", "ABF", [[Interface\Addons\Skada\Media\Fonts\ABF.ttf]])
		LSM:Register("font", "Accidental Presidency", [[Interface\Addons\Skada\Media\Fonts\Accidental Presidency.ttf]])
		LSM:Register("font", "Adventure", [[Interface\Addons\Skada\Media\Fonts\Adventure.ttf]])
		LSM:Register("font", "Continuum Medium", [[Interface\Addons\Skada\Media\Fonts\ContinuumMedium.ttf]])
		LSM:Register("font", "Diablo", [[Interface\Addons\Skada\Media\Fonts\Diablo.ttf]])
		LSM:Register("font", "Forced Square", [[Interface\Addons\Skada\Media\Fonts\FORCED SQUARE.ttf]])
		LSM:Register("font", "FrancoisOne", [[Interface\Addons\Skada\Media\Fonts\FrancoisOne.ttf]])
		LSM:Register("font", "Hooge", [[Interface\Addons\Skada\Media\Fonts\Hooge.ttf]])

		-- statusbars
		LSM:Register("statusbar", "Aluminium", [[Interface\Addons\Skada\Media\Statusbar\Aluminium]])
		LSM:Register("statusbar", "Armory", [[Interface\Addons\Skada\Media\Statusbar\Armory]])
		LSM:Register("statusbar", "BantoBar", [[Interface\Addons\Skada\Media\Statusbar\BantoBar]])
		LSM:Register("statusbar", "Flat", [[Interface\Addons\Skada\Media\Statusbar\Flat]])
		LSM:Register("statusbar", "Glass", [[Interface\AddOns\Skada\Media\Statusbar\Glass]])
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
		LSM:Register("statusbar", "Smooth v2", [[Interface\Addons\Skada\Media\Statusbar\Smoothv2]])
		LSM:Register("statusbar", "Smooth", [[Interface\Addons\Skada\Media\Statusbar\Smooth]])
		LSM:Register("statusbar", "Solid", [[Interface\Buttons\WHITE8X8]])
		LSM:Register("statusbar", "TukTex", [[Interface\Addons\Skada\Media\Statusbar\TukTex]])
		LSM:Register("statusbar", "WorldState Score", [[Interface\WorldStateFrame\WORLDSTATEFINALSCORE-HIGHLIGHT]])

		-- borders
		LSM:Register("border", "Glow", [[Interface\Addons\Skada\Media\Border\Glow]])
		LSM:Register("border", "Roth", [[Interface\Addons\Skada\Media\Border\Roth]])
		LSM:Register("background", "Copper", [[Interface\Addons\Skada\Media\Background\copper]])

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
	function Skada:RegisterToast()
		if LibToast then
			-- install default options
			if not self.db.profile.toast then
				self.db.profile.toast = self.defaults.toast
			end

			LibToast:Register("SkadaToastFrame", function(toast, text, title, icon, urgency)
				toast:SetTitle(title or "Skada")
				toast:SetText(text or L["A damage meter."])
				toast:SetIconTexture(icon or self.logo)
				toast:SetUrgencyLevel(urgency or "normal")
			end)
			if self.db.profile.toast then
				LibToast.config.hide_toasts = self.db.profile.toast.hide_toasts
				LibToast.config.spawn_point = self.db.profile.toast.spawn_point or "TOP"
				LibToast.config.duration = self.db.profile.toast.duration or 7
				LibToast.config.opacity = self.db.profile.toast.opacity or 0.75
			end
		end
		self.RegisterToast = nil
	end

	-- returns toast options
	function Skada:GetToastOptions()
		self.GetToastOptions = nil -- remove it

		if LibToast and not toast_opt then
			toast_opt = {
				type = "group",
				name = L["Notifications"],
				get = function(i)
					return self.db.profile.toast[i[#i]] or LibToast.config[i[#i]]
				end,
				set = function(i, val)
					self.db.profile.toast[i[#i]] = val
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
					empty_1 = {
						type = "description",
						name = " ",
						width = "full",
						order = 50
					},
					test = {
						type = "execute",
						name = L["Test Notifications"],
						func = function() self:Notify() end,
						disabled = function() return self.db.profile.toast.hide_toasts end,
						width = "double",
						order = 60
					}
				}
			}
		end

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

	function Skada:GetTotalOptions()
		self.GetTotalOptions = nil -- remove it

		if not total_opt then
			local values = {al = 0x10, rb = 0x01, rt = 0x02, db = 0x04, dt = 0x08}

			local disabled = function()
				return band(self.db.profile.totalflag, values.al) ~= 0
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
							return (band(self.db.profile.totalflag, values[i[#i]]) ~= 0)
						end,
						set = function(i, val)
							local v = values[i[#i]]
							if val and band(self.db.profile.totalflag, v) == 0 then
								self.db.profile.totalflag = self.db.profile.totalflag + v
							elseif not val and band(self.db.profile.totalflag, v) ~= 0 then
								self.db.profile.totalflag = self.db.profile.totalflag - v
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
					}
				}
			}
		end

		return total_opt
	end

	function Skada:NoTotalClick(set, mode)
		return (set == "total" and type(mode) == "table" and mode.nototal == true)
	end

	function Skada:CanRecordTotal(set)
		if set then
			-- just in case
			if not self.db.profile.totalflag then
				self.db.profile.totalflag = 0x10
			end

			-- raid bosses - 0x01
			if band(self.db.profile.totalflag, 0x01) ~= 0 then
				if set.type == "raid" and set.gotboss then
					if set.time >= self.db.profile.minsetlength then
						return true
					end
				end
			end

			-- raid trash - 0x02
			if band(self.db.profile.totalflag, 0x02) ~= 0 then
				if set.type == "raid" and not set.gotboss then
					return true
				end
			end

			-- dungeon boss - 0x04
			if band(self.db.profile.totalflag, 0x04) ~= 0 then
				if set.type == "party" and self.db.profile.gotboss then
					return true
				end
			end

			-- dungeon trash - 0x08
			if band(self.db.profile.totalflag, 0x08) ~= 0 then
				if set.type == "party" and not self.db.profile.gotboss then
					return true
				end
			end

			-- any combat - 0x10
			if band(self.db.profile.totalflag, 0x10) ~= 0 then
				return true
			end

			-- battlegrouns/arenas or nothing
			return (set.type == "pvp" or set.type == "arena")
		end

		return false
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
-- called "queuedSpells" in which you can store a table of [spellid] = spellid
-- used by other modules.
-- In the case of "Mark of Blood" (49005), the healing from the spell 50424
-- is attributed to the target instead of the DK, so whenever Skada detects
-- a healing from 50424 it will check queued units, if found the player data
-- will be used.

do
	local queued_units = nil
	local new, del = Skada.newTable, Skada.delTable

	function Skada:QueueUnit(spellid, srcGUID, srcName, srcFlags, dstGUID)
		if spellid and srcName and srcGUID and dstGUID and srcGUID ~= dstGUID then
			queued_units = queued_units or T.get("Skada_QueuedUnits")
			queued_units[spellid] = queued_units[spellid] or new()
			queued_units[spellid][dstGUID] = new()
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
			if Skada.tLength(queued_units[spellid]) == 0 then
				queued_units[spellid] = del(queued_units[spellid])
			end
		end
	end

	function Skada:FixUnit(spellid, guid, name, flag)
		if spellid and guid and queued_units and queued_units[spellid] and queued_units[spellid][guid] then
			guid = queued_units[spellid][guid].id or guid
			name = queued_units[spellid][guid].name or name
			flag = queued_units[spellid][guid].flag or flag
		end
		return guid, name, flag
	end

	function Skada:IsQueuedUnit(guid)
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

	function Skada:ClearQueueUnits()
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