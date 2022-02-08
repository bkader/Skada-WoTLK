local Skada = Skada

local L = LibStub("AceLocale-3.0"):GetLocale("Skada")

local select, pairs, ipairs = select, pairs, ipairs
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
	for class in pairs(self.classcolors) do
		self.validclass[class] = true
	end

	-- Skada custom class colors!
	self.classcolors.BOSS = {r = 0.203, g = 0.345, b = 0.525, colorStr = "ff345886"}
	self.classcolors.ENEMY = {r = 0.94117, g = 0, b = 0.0196, colorStr = "fff00005"}
	self.classcolors.MONSTER = {r = 0.549, g = 0.388, b = 0.404, colorStr = "ff8c6367"}
	self.classcolors.PET = {r = 0.3, g = 0.4, b = 0.5, colorStr = "ff4c0566"}
	self.classcolors.PLAYER = {r = 0.94117, g = 0, b = 0.0196, colorStr = "fff00005"}
	self.classcolors.UNKNOWN = {r = 0.2, g = 0.2, b = 0.2, colorStr = "ff333333"}
	-- arena class colors
	self.classcolors.ARENA_GOLD = {r = 1, g = 0.82, b = 0, colorStr = "ffffd100"}
	self.classcolors.ARENA_GREEN = {r = 0.1, g = 1, b = 0.1, colorStr = "ff19ff19"}
	-- purple color instead of green for color blind mode.
	if GetCVar("colorblindMode") == "1" then
		self.classcolors.ARENA_GREEN.r = 0.686
		self.classcolors.ARENA_GREEN.g = 0.384
		self.classcolors.ARENA_GREEN.b = 1
		self.classcolors.ARENA_GREEN.colorStr = "ffae61ff"
	end

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

	-- we ignore roles & specs on Project Ascension since players
	-- have a custom module to set their own colors & icons.
	if not self.Ascension and not self.AscensionCoA then
		-- role icon file and texture coordinates
		self.roleicons = [[Interface\AddOns\Skada\Media\Textures\icon-roles]]
		self.rolecoords = {
			LEADER = {0, 0.25, 0, 1},
			DAMAGER = {0.25, 0.5, 0, 1},
			TANK = {0.5, 0.75, 0, 1},
			HEALER = {0.75, 1, 0, 1},
			NONE = ""
		}

		-- specialization icons
		self.specicons = [[Interface\AddOns\Skada\Media\Textures\icon-specs]]
		self.speccoords = {
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
		}
	end
end

function Skada:RegisterSchools()
	self.RegisterSchools = nil -- remove it

	-- spell school colors
	self.schoolcolors = {
		[1] = {a = 1.00, r = 1.00, g = 1.00, b = 0.00}, -- Physical
		[2] = {a = 1.00, r = 1.00, g = 0.90, b = 0.50}, -- Holy
		[4] = {a = 1.00, r = 1.00, g = 0.50, b = 0.00}, -- Fire
		[8] = {a = 1.00, r = 0.30, g = 1.00, b = 0.30}, -- Nature
		[16] = {a = 1.00, r = 0.50, g = 1.00, b = 1.00}, -- Frost
		[20] = {a = 1.00, r = 0.50, g = 1.00, b = 1.00}, -- Frostfire
		[32] = {a = 1.00, r = 0.50, g = 0.50, b = 1.00}, -- Shadow
		[64] = {a = 1.00, r = 1.00, g = 0.50, b = 1.00} -- Arcane
	}

	-- spell school names
	self.schoolnames = {
		[1] = STRING_SCHOOL_PHYSICAL:gsub("%(", ""):gsub("%)", ""),
		[2] = STRING_SCHOOL_HOLY:gsub("%(", ""):gsub("%)", ""),
		[4] = STRING_SCHOOL_FIRE:gsub("%(", ""):gsub("%)", ""),
		[8] = STRING_SCHOOL_NATURE:gsub("%(", ""):gsub("%)", ""),
		[16] = STRING_SCHOOL_FROST:gsub("%(", ""):gsub("%)", ""),
		[20] = STRING_SCHOOL_FROSTFIRE:gsub("%(", ""):gsub("%)", ""),
		[32] = STRING_SCHOOL_SHADOW:gsub("%(", ""):gsub("%)", ""),
		[64] = STRING_SCHOOL_ARCANE:gsub("%(", ""):gsub("%)", "")
	}
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

	t.enterClicksFirstButton = 1
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

	-- table of adds used to fix segment name
	local creatureToFight = {
		-- [[ Icecrown Citadel ]] --
		[36960] = L["Icecrown Gunship Battle"], -- Kor'kron Sergeant
		[36968] = L["Icecrown Gunship Battle"], -- Kor'kron Axethrower
		[36982] = L["Icecrown Gunship Battle"], -- Kor'kron Rocketeer
		[37117] = L["Icecrown Gunship Battle"], -- Kor'kron Battle-Mage
		[37215] = L["Icecrown Gunship Battle"], -- Orgrim's Hammer
		[36961] = L["Icecrown Gunship Battle"], -- Skybreaker Sergeant
		[36969] = L["Icecrown Gunship Battle"], -- Skybreaker Rifleman
		[36978] = L["Icecrown Gunship Battle"], -- Skybreaker Mortar Soldier
		[37116] = L["Icecrown Gunship Battle"], -- Skybreaker Sorcerer
		[37540] = L["Icecrown Gunship Battle"], -- The Skybreaker
		[37970] = L["Blood Prince Council"], -- Prince Valanar
		[37972] = L["Blood Prince Council"], -- Prince Keleseth
		[37973] = L["Blood Prince Council"], -- Prince Taldaram
		[36789] = L["Valithria Dreamwalker"], -- Valithria Dreamwalker
		[36791] = L["Valithria Dreamwalker"], -- Blazing Skeleton
		[37868] = L["Valithria Dreamwalker"], -- Risen Archmage
		[37886] = L["Valithria Dreamwalker"], -- Gluttonous Abomination
		[37934] = L["Valithria Dreamwalker"], -- Blistering Zombie
		[37985] = L["Valithria Dreamwalker"], -- Dream Cloud
		-- [[ Naxxramas ]] --
		[16062] = L["The Four Horsemen"], -- Highlord Mograine
		[16063] = L["The Four Horsemen"], -- Sir Zeliek
		[16064] = L["The Four Horsemen"], -- Thane Korth'azz
		[16065] = L["The Four Horsemen"], -- Lady Blaumeux
		[15930] = L["Thaddius"], -- Feugen
		[15929] = L["Thaddius"], -- Stalagg
		[15928] = L["Thaddius"], -- Thaddius
		-- [[ Trial of the Crusader ]] --
		[34796] = L["The Northrend Beasts"], -- Gormok
		[35144] = L["The Northrend Beasts"], -- Acidmaw
		[34799] = L["The Northrend Beasts"], -- Dreadscale
		[34797] = L["The Northrend Beasts"], -- Icehowl
		-- Champions of the Alliance
		[34461] = L["Faction Champions"], -- Tyrius Duskblade <Death Knight>
		[34460] = L["Faction Champions"], -- Kavina Grovesong <Druid>
		[34469] = L["Faction Champions"], -- Melador Valestrider <Druid>
		[34467] = L["Faction Champions"], -- Alyssia Moonstalker <Hunter>
		[34468] = L["Faction Champions"], -- Noozle Whizzlestick <Mage>
		[34465] = L["Faction Champions"], -- Velanaa <Paladin>
		[34471] = L["Faction Champions"], -- Baelnor Lightbearer <Paladin>
		[34466] = L["Faction Champions"], -- Anthar Forgemender <Priest>
		[34473] = L["Faction Champions"], -- Brienna Nightfell <Priest>
		[34472] = L["Faction Champions"], -- Irieth Shadowstep <Rogue>
		[34463] = L["Faction Champions"], -- Shaabad <Shaman>
		[34470] = L["Faction Champions"], -- Saamul <Shaman>
		[34474] = L["Faction Champions"], -- Serissa Grimdabbler <Warlock>
		[34475] = L["Faction Champions"], -- Shocuul <Warrior>
		[35465] = L["Faction Champions"], -- Zhaagrym <Harkzog's Minion / Serissa Grimdabbler's Minion>
		-- Champions of the Horde
		[34441] = L["Faction Champions"], -- Vivienne Blackwhisper <Priest>
		[34444] = L["Faction Champions"], -- Thrakgar <Shaman>
		[34445] = L["Faction Champions"], -- Liandra Suncaller <Paladin>
		[34447] = L["Faction Champions"], -- Caiphus the Stern <Priest>
		[34448] = L["Faction Champions"], -- Ruj'kah <Hunter>
		[34449] = L["Faction Champions"], -- Ginselle Blightslinger <Mage>
		[34450] = L["Faction Champions"], -- Harkzog <Warlock>
		[34451] = L["Faction Champions"], -- Birana Stormhoof <Druid>
		[34453] = L["Faction Champions"], -- Narrhok Steelbreaker <Warrior>
		[34454] = L["Faction Champions"], -- Maz'dinah <Rogue>
		[34455] = L["Faction Champions"], -- Broln Stouthorn <Shaman>
		[34456] = L["Faction Champions"], -- Malithas Brightblade <Paladin>
		[34458] = L["Faction Champions"], -- Gorgrim Shadowcleave <Death Knight>
		[34459] = L["Faction Champions"], -- Erin Misthoof <Druid>
		[35610] = L["Faction Champions"], -- Cat <Ruj'kah's Pet / Alyssia Moonstalker's Pet>
		[34496] = L["Twin Val'kyr"], -- Eydis Darkbane
		[34497] = L["Twin Val'kyr"], -- Fjola Lightbane
		-- [[ Ulduar ]] --
		[32857] = L["The Iron Council"], -- Stormcaller Brundir
		[32867] = L["The Iron Council"], -- Steelbreaker
		[32927] = L["The Iron Council"], -- Runemaster Molgeim
		[32930] = L["Kologarn"], -- Kologarn
		[32933] = L["Kologarn"], -- Left Arm
		[32934] = L["Kologarn"], -- Right Arm
		[33515] = L["Auriaya"], -- Auriaya
		[34014] = L["Auriaya"], -- Sanctum Sentry
		[34035] = L["Auriaya"], -- Feral Defender
		[32882] = L["Thorim"], -- Jormungar Behemoth
		[33288] = L["Yogg-Saron"], -- Yogg-Saron
		[33890] = L["Yogg-Saron"], -- Brain of Yogg-Saron
		[33136] = L["Yogg-Saron"], -- Guardian of Yogg-Saron
		[33350] = L["Mimiron"], -- Mimiron
		[33432] = L["Mimiron"], -- Leviathan Mk II
		[33651] = L["Mimiron"], -- VX-001
		[33670] = L["Mimiron"] -- Aerial Command Unit
	}

	-- list of adds used to determine the main boss
	local creatureToBoss = {
		-- [[ Icecrown Citadel ]] --
		[36960] = 37215, -- Kor'kron Sergeant > Orgrim's Hammer
		[36968] = 37215, -- Kor'kron Axethrower > Orgrim's Hammer
		[36982] = 37215, -- Kor'kron Rocketeer > Orgrim's Hammer
		[37117] = 37215, -- Kor'kron Battle-Mage > Orgrim's Hammer
		[36961] = 37540, -- Skybreaker Sergeant > The Skybreaker
		[36969] = 37540, -- Skybreaker Rifleman > The Skybreaker
		[36978] = 37540, -- Skybreaker Mortar Soldier > The Skybreaker
		[37116] = 37540, -- Skybreaker Sorcerer > The Skybreaker
		[36791] = 36789, -- Blazing Skeleton
		[37868] = 36789, -- Risen Archmage
		[37886] = 36789, -- Gluttonous Abomination
		[37934] = 36789, -- Blistering Zombie
		[37985] = 36789, -- Dream Cloud
		-- [[ Naxxramas ]] --
		[15930] = 15928, -- Feugen > Thaddius
		[15929] = 15928, -- Stalagg > Thaddius
		-- [[ Trial of the Crusader ]] --
		[34796] = 34797, -- Gormok > Icehowl
		[35144] = 34797, -- Acidmaw > Icehowl
		[34799] = 34797, -- Dreadscale > Icehowl
		-- [[ Ulduar ]] --
		[32933] = 32930, -- Left Arm > Kologarn
		[32934] = 32930, -- Right Arm > Kologarn
		[34014] = 33515, -- Sanctum Sentry > Auriaya
		[34035] = 33515, -- Feral Defender > Auriaya
		[32882] = 32865, -- Jormungar Behemoth > Thorim
		[33890] = 33288, -- Brain of Yogg-Saron > Yogg-Saron
		[33136] = 33288, -- Guardian of Yogg-Saron > Yogg-Saron
		[33432] = 33350, -- Leviathan Mk II > Mimiron
		[33651] = 33350, -- VX-001 > Mimiron
		[33670] = 33350 -- Aerial Command Unit > Mimiron
	}

	-- checks if the provided guid is a boss
	-- returns a boolean, boss id and boss name
	function Skada:IsBoss(guid, name)
		local isboss, npcid, npcname = false, 0, nil
		local id = self.GetCreatureId(guid)
		if id and (LBI.BossIDs[id] or creatureToFight[id] or creatureToBoss[id]) then
			isboss, npcid = true, creatureToBoss[id] or id
			if creatureToFight[id] then
				npcname = (name and name ~= creatureToFight[id]) and name or creatureToFight[id]
			end
		elseif self:IsCreature(guid) then
			npcid = id
		end
		return isboss, npcid, npcname
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
		for _, p in ipairs(set.players) do
			if p.id == guid then
				return p.class, p.role, p.spec
			elseif name and p.name == name and p.class and Skada.validclass[p.class] then
				return p.class, p.role, p.spec
			end
		end
		if set.enemies then
			for _, e in ipairs(set.enemies) do
				if (e.id == guid or e.name == guid) and e.class then
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
	local GetSpellInfo, GetSpellLink = GetSpellInfo, GetSpellLink

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
					res1, res3 = L.Melee, [[Interface\Icons\INV_Sword_04]]
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
	local unpack = unpack
	local random = math.random
	local IsGroupInCombat = Skada.IsGroupInCombat
	local InCombatLockdown = InCombatLockdown
	local setPrototype = Skada.setPrototype
	local playerPrototype = Skada.playerPrototype

	local fakeSet, updateTimer = {}, nil

	-- there was no discrimination with classes and specs
	-- the only reason this group composition was made is
	-- to have all 10 classes displayed on windows.
	local fakePlayers = {
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
	local fakePlayersAscension = {
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

	local function GenerateFakeData()
		wipe(fakeSet)
		fakeSet.name = "Fake Fight"
		fakeSet.starttime = time() - 120
		fakeSet.endtime = time()
		fakeSet.damage = 0
		fakeSet.heal = 0
		fakeSet.absorb = 0
		fakeSet.players = wipe(fakeSet.players or {})

		local players = Skada.AscensionCoA and fakePlayersAscension or fakePlayers
		for i = 1, #players do
			local name, class, role, spec = unpack(players[i])
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

			tinsert(fakeSet.players, {
				id = name,
				name = name,
				class = class,
				role = role,
				spec = spec,
				damage = damage,
				heal = heal,
				absorb = absorb
			})

			fakeSet.damage = fakeSet.damage + damage
			fakeSet.heal = fakeSet.heal + heal
			fakeSet.absorb = fakeSet.absorb + absorb
		end

		return setPrototype:Bind(fakeSet)
	end

	local function RandomizeFakeData(set, coef)
		for _, player in ipairs(set.players) do
			if getmetatable(player) ~= playerPrototype then
				playerPrototype:Bind(player, set)
			end

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
				order = 10000,
				args = {
					toastdesc = {
						type = "description",
						name = L["Uses visual notifications instead of chat window messages whenever applicable."],
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

	function Skada:QueueUnit(spellid, srcGUID, srcName, srcFlags, dstGUID)
		if spellid and srcName and srcGUID and dstGUID and srcGUID ~= dstGUID then
			queued_units = queued_units or T.get("Skada_QueuedUnits")
			queued_units[spellid] = queued_units[spellid] or {}
			queued_units[spellid][dstGUID] = {id = srcGUID, name = srcName, flag = srcFlags}
		end
	end

	function Skada:UnqueueUnit(spellid, dstGUID)
		if spellid and dstGUID and queued_units and queued_units[spellid] then
			if queued_units[spellid][dstGUID] then
				queued_units[spellid][dstGUID] = nil
			end
			if Skada.tLength(queued_units[spellid]) == 0 then
				queued_units[spellid] = nil
			end
		end
	end

	function Skada:FixUnit(spellid, guid, name, flag)
		if spellid and guid and queued_units and queued_units[spellid] and queued_units[spellid][guid] then
			return queued_units[spellid][guid].id or guid, queued_units[spellid][guid].name or name, queued_units[spellid][guid].flag or flag
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
		T.free("Skada_QueuedUnits", queued_units)
	end
end