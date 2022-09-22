-- Tables.lua
-- Contains all tables used by different files and modules.
local folder, Skada = ...
local L = LibStub("AceLocale-3.0"):GetLocale(folder)

-------------------------------------------------------------------------------
-- table we need.

-->> START OF PROTECTED CODE <<--

local ignoredSpells = {} -- a table of spells that are ignored per module.
local creatureToFight = {} -- a table of creatures IDs used to fix segments names.
local creatureToBoss = {} -- a table of adds used to deternmine the main boss in encounters.

-- use LibBossIDs-1.0 as backup plan
local LBI = LibStub("LibBossIDs-1.0", true)
if LBI then
	setmetatable(creatureToBoss, {__index = LBI.BossIDs})
end

-- add to Skada scope.
Skada.ignoredSpells = ignoredSpells
Skada.creatureToFight = creatureToFight
Skada.creatureToBoss = creatureToBoss

-->> END OF PROTECTED CODE <<--

-->> START OF EDITABLE CODE <<--

-------------------------------------------------------------------------------
-- ingoredSpells

-- entries should be like so:
-- [spellid] = true

-- [[ absorbs modules ]] --
-- ignoredSpells.absorbs = {}

-- [[ buffs module ]] --
ignoredSpells.buffs = {
	[57819] = true, -- Tabard of the Argent Crusade
	[57820] = true, -- Tabard of the Ebon Blade
	[57821] = true, -- Tabard of the Kirin Tor
	[57822] = true, -- Tabard of the Wyrmrest Accord
	[57940] = true, -- Essence of Wintergrasp
	[72968] = true, -- Precious's Ribbon

	-- uncertain about the follwing spells:
	-- [73816] = true, -- Hellscream's Warsong (ICC-Horde 5%)
	-- [73818] = true, -- Hellscream's Warsong (ICC-Horde 10%)
	-- [73819] = true, -- Hellscream's Warsong (ICC-Horde 15%)
	-- [73820] = true, -- Hellscream's Warsong (ICC-Horde 20%)
	-- [73821] = true, -- Hellscream's Warsong (ICC-Horde 25%)
	-- [73822] = true, -- Hellscream's Warsong (ICC-Horde 30%)
	-- [73762] = true, -- Hellscream's Warsong (ICC-Alliance 5%)
	-- [73824] = true, -- Hellscream's Warsong (ICC-Alliance 10%)
	-- [73825] = true, -- Hellscream's Warsong (ICC-Alliance 15%)
	-- [73826] = true, -- Hellscream's Warsong (ICC-Alliance 20%)
	-- [73827] = true, -- Hellscream's Warsong (ICC-Alliance 25%)
	-- [73828] = true, -- Hellscream's Warsong (ICC-Alliance 30%)
}

-- [[ debuffs module ]] --
ignoredSpells.debuffs = {
	[57723] = true, -- Exhaustion (Heroism)
	[57724] = true -- Sated (Bloodlust)
}

-- [[ damage / enemy damage taken modules ]] --
-- ignoredSpells.damage = {}

-- [[ damage taken / enemy damage done modules ]] --
-- ignoredSpells.damagetaken = {}

-- [[ dispels module ]] --
-- ignoredSpells.dispels = {}

-- [[ fails module ]] --
-- ignoredSpells.fails = {}

-- [[ friendly fire module ]] --
-- ignoredSpells.friendfire = {}

-- [[ healing / enemy healing done modules ]] --
-- ignoredSpells.heals = {}

-- [[ interrupts module ]] --
-- ignoredSpells.interrupts = {}

-- [[ resources module ]] --
-- ignoredSpells.power = {}

-- [[ first hit ignored spells ]] --
ignoredSpells.firsthit = {
	[1130] = true, -- Hunter's Mark (rank 1)
	[14323] = true, -- Hunter's Mark (rank 2)
	[14324] = true, -- Hunter's Mark (rank 3)
	[14325] = true, -- Hunter's Mark (rank 4)
	[53338] = true, -- Hunter's Mark (rank 5)
	[56190] = true, -- Shadow Jade Focusing Lens
	[56191] = true, -- Shadow Jade Focusing Lens
	[60122] = true -- Baby Spice
}

-- [[ no active time spells ]] --
ignoredSpells.activeTime = {
	-- Retribution Aura
	[7294] = true, -- Rank 1
	[7294] = true, -- Rank 1
	[10298] = true, -- Rank 2
	[10299] = true, -- Rank 3
	[10300] = true, -- Rank 4
	[10301] = true, -- Rank 5
	[27150] = true, -- Rank 6
	[54043] = true, -- Rank 7
	-- Molten Armor
	[34913] = true, -- Rank 1
	[43043] = true, -- Rank 2
	[43044] = true, -- Rank 3
	-- Lightning Shield
	[26364] = true, -- Rank 1
	[26365] = true, -- Rank 2
	[26366] = true, -- Rank 3
	[26367] = true, -- Rank 5
	[26370] = true, -- Rank 6
	[26363] = true, -- Rank 7
	[26371] = true, -- Rank 8
	[26372] = true, -- Rank 9
	[49278] = true, -- Rank 10
	[49279] = true, -- Rank 11
	-- Fire Shield
	[2947] = true, -- Rank 1
	[8316] = true, -- Rank 2
	[8317] = true, -- Rank 3
	[11770] = true, -- Rank 4
	[11771] = true, -- Rank 5
	[27269] = true, -- Rank 6
	[47983] = true, -- Rank 7
}

-------------------------------------------------------------------------------
-- creatureToFight

-- [[ Icecrown Citadel ]] --
creatureToFight[36960] = L["Icecrown Gunship Battle"] -- Kor'kron Sergeant
creatureToFight[36968] = L["Icecrown Gunship Battle"] -- Kor'kron Axethrower
creatureToFight[36982] = L["Icecrown Gunship Battle"] -- Kor'kron Rocketeer
creatureToFight[37117] = L["Icecrown Gunship Battle"] -- Kor'kron Battle-Mage
creatureToFight[37215] = L["Icecrown Gunship Battle"] -- Orgrim's Hammer
creatureToFight[36961] = L["Icecrown Gunship Battle"] -- Skybreaker Sergeant
creatureToFight[36969] = L["Icecrown Gunship Battle"] -- Skybreaker Rifleman
creatureToFight[36978] = L["Icecrown Gunship Battle"] -- Skybreaker Mortar Soldier
creatureToFight[37116] = L["Icecrown Gunship Battle"] -- Skybreaker Sorcerer
creatureToFight[37540] = L["Icecrown Gunship Battle"] -- The Skybreaker
creatureToFight[37970] = L["Blood Prince Council"] -- Prince Valanar
creatureToFight[37972] = L["Blood Prince Council"] -- Prince Keleseth
creatureToFight[37973] = L["Blood Prince Council"] -- Prince Taldaram
creatureToFight[36789] = L["Valithria Dreamwalker"] -- Valithria Dreamwalker
creatureToFight[36791] = L["Valithria Dreamwalker"] -- Blazing Skeleton
creatureToFight[37868] = L["Valithria Dreamwalker"] -- Risen Archmage
creatureToFight[37886] = L["Valithria Dreamwalker"] -- Gluttonous Abomination
creatureToFight[37934] = L["Valithria Dreamwalker"] -- Blistering Zombie
creatureToFight[37985] = L["Valithria Dreamwalker"] -- Dream Cloud

-- [[ Naxxramas ]] --
creatureToFight[16062] = L["The Four Horsemen"] -- Highlord Mograine
creatureToFight[16063] = L["The Four Horsemen"] -- Sir Zeliek
creatureToFight[16064] = L["The Four Horsemen"] -- Thane Korth'azz
creatureToFight[16065] = L["The Four Horsemen"] -- Lady Blaumeux
creatureToFight[15930] = L["Thaddius"] -- Feugen
creatureToFight[15929] = L["Thaddius"] -- Stalagg
creatureToFight[15928] = L["Thaddius"] -- Thaddius

-- [[ Trial of the Crusader ]] --
creatureToFight[34796] = L["The Northrend Beasts"] -- Gormok
creatureToFight[35144] = L["The Northrend Beasts"] -- Acidmaw
creatureToFight[34799] = L["The Northrend Beasts"] -- Dreadscale
creatureToFight[34797] = L["The Northrend Beasts"] -- Icehowl

-- Champions of the Alliance
creatureToFight[34461] = L["Faction Champions"] -- Tyrius Duskblade <Death Knight>
creatureToFight[34460] = L["Faction Champions"] -- Kavina Grovesong <Druid>
creatureToFight[34469] = L["Faction Champions"] -- Melador Valestrider <Druid>
creatureToFight[34467] = L["Faction Champions"] -- Alyssia Moonstalker <Hunter>
creatureToFight[34468] = L["Faction Champions"] -- Noozle Whizzlestick <Mage>
creatureToFight[34465] = L["Faction Champions"] -- Velanaa <Paladin>
creatureToFight[34471] = L["Faction Champions"] -- Baelnor Lightbearer <Paladin>
creatureToFight[34466] = L["Faction Champions"] -- Anthar Forgemender <Priest>
creatureToFight[34473] = L["Faction Champions"] -- Brienna Nightfell <Priest>
creatureToFight[34472] = L["Faction Champions"] -- Irieth Shadowstep <Rogue>
creatureToFight[34463] = L["Faction Champions"] -- Shaabad <Shaman>
creatureToFight[34470] = L["Faction Champions"] -- Saamul <Shaman>
creatureToFight[34474] = L["Faction Champions"] -- Serissa Grimdabbler <Warlock>
creatureToFight[34475] = L["Faction Champions"] -- Shocuul <Warrior>
creatureToFight[35465] = L["Faction Champions"] -- Zhaagrym <Harkzog's Minion / Serissa Grimdabbler's Minion>

-- Champions of the Horde
creatureToFight[34441] = L["Faction Champions"] -- Vivienne Blackwhisper <Priest>
creatureToFight[34444] = L["Faction Champions"] -- Thrakgar <Shaman>
creatureToFight[34445] = L["Faction Champions"] -- Liandra Suncaller <Paladin>
creatureToFight[34447] = L["Faction Champions"] -- Caiphus the Stern <Priest>
creatureToFight[34448] = L["Faction Champions"] -- Ruj'kah <Hunter>
creatureToFight[34449] = L["Faction Champions"] -- Ginselle Blightslinger <Mage>
creatureToFight[34450] = L["Faction Champions"] -- Harkzog <Warlock>
creatureToFight[34451] = L["Faction Champions"] -- Birana Stormhoof <Druid>
creatureToFight[34453] = L["Faction Champions"] -- Narrhok Steelbreaker <Warrior>
creatureToFight[34454] = L["Faction Champions"] -- Maz'dinah <Rogue>
creatureToFight[34455] = L["Faction Champions"] -- Broln Stouthorn <Shaman>
creatureToFight[34456] = L["Faction Champions"] -- Malithas Brightblade <Paladin>
creatureToFight[34458] = L["Faction Champions"] -- Gorgrim Shadowcleave <Death Knight>
creatureToFight[34459] = L["Faction Champions"] -- Erin Misthoof <Druid>
creatureToFight[35610] = L["Faction Champions"] -- Cat <Ruj'kah's Pet / Alyssia Moonstalker's Pet>

creatureToFight[34496] = L["Twin Val'kyr"] -- Eydis Darkbane
creatureToFight[34497] = L["Twin Val'kyr"] -- Fjola Lightbane

-- [[ Ulduar ]] --
creatureToFight[32857] = L["The Iron Council"] -- Stormcaller Brundir
creatureToFight[32867] = L["The Iron Council"] -- Steelbreaker
creatureToFight[32927] = L["The Iron Council"] -- Runemaster Molgeim
creatureToFight[32930] = L["Kologarn"] -- Kologarn
creatureToFight[32933] = L["Kologarn"] -- Left Arm
creatureToFight[32934] = L["Kologarn"] -- Right Arm
creatureToFight[33515] = L["Auriaya"] -- Auriaya
creatureToFight[34014] = L["Auriaya"] -- Sanctum Sentry
creatureToFight[34035] = L["Auriaya"] -- Feral Defender
creatureToFight[32882] = L["Thorim"] -- Jormungar Behemoth
creatureToFight[33288] = L["Yogg-Saron"] -- Yogg-Saron
creatureToFight[33890] = L["Yogg-Saron"] -- Brain of Yogg-Saron
creatureToFight[33136] = L["Yogg-Saron"] -- Guardian of Yogg-Saron
creatureToFight[33350] = L["Mimiron"] -- Mimiron
creatureToFight[33432] = L["Mimiron"] -- Leviathan Mk II
creatureToFight[33651] = L["Mimiron"] -- VX-001
creatureToFight[33670] = L["Mimiron"] -- Aerial Command Unit

-------------------------------------------------------------------------------
-- creatureToBoss

-- [[ Icecrown Citadel ]] --
creatureToBoss[36960] = 37215 -- Kor'kron Sergeant > Orgrim's Hammer
creatureToBoss[36968] = 37215 -- Kor'kron Axethrower > Orgrim's Hammer
creatureToBoss[36982] = 37215 -- Kor'kron Rocketeer > Orgrim's Hammer
creatureToBoss[37117] = 37215 -- Kor'kron Battle-Mage > Orgrim's Hammer
creatureToBoss[36961] = 37540 -- Skybreaker Sergeant > The Skybreaker
creatureToBoss[36969] = 37540 -- Skybreaker Rifleman > The Skybreaker
creatureToBoss[36978] = 37540 -- Skybreaker Mortar Soldier > The Skybreaker
creatureToBoss[37116] = 37540 -- Skybreaker Sorcerer > The Skybreaker
creatureToBoss[36791] = 36789 -- Blazing Skeleton
creatureToBoss[37868] = 36789 -- Risen Archmage
creatureToBoss[37886] = 36789 -- Gluttonous Abomination
creatureToBoss[37934] = 36789 -- Blistering Zombie
creatureToBoss[37985] = 36789 -- Dream Cloud

-- [[ Naxxramas ]] --
creatureToBoss[15930] = 15928 -- Feugen > Thaddius
creatureToBoss[15929] = 15928 -- Stalagg > Thaddius

-- [[ Trial of the Crusader ]] --
creatureToBoss[34796] = 34797 -- Gormok > Icehowl
creatureToBoss[35144] = 34797 -- Acidmaw > Icehowl
creatureToBoss[34799] = 34797 -- Dreadscale > Icehowl

-- [[ Ulduar ]] --
creatureToBoss[32933] = 32930 -- Left Arm > Kologarn
creatureToBoss[32934] = 32930 -- Right Arm > Kologarn
creatureToBoss[34014] = 33515 -- Sanctum Sentry > Auriaya
creatureToBoss[34035] = 33515 -- Feral Defender > Auriaya
creatureToBoss[32882] = 32865 -- Jormungar Behemoth > Thorim
creatureToBoss[33890] = 33288 -- Brain of Yogg-Saron > Yogg-Saron
creatureToBoss[33136] = 33288 -- Guardian of Yogg-Saron > Yogg-Saron
creatureToBoss[33432] = 33350 -- Leviathan Mk II > Mimiron
creatureToBoss[33651] = 33350 -- VX-001 > Mimiron
creatureToBoss[33670] = 33350 -- Aerial Command Unit > Mimiron

-->> END OF EDITABLE CODE <<--

-->> DO NOT TOUCH CODE BELOW <<--

-------------------------------------------------------------------------------
-- CLEU Miss Types

Skada.missTypes = {
	ABSORB = "abs_n",
	BLOCK = "blo_n",
	DEFLECT = "def_n",
	DODGE = "dod_n",
	EVADE = "eva_n",
	IMMUNE = "imm_n",
	MISS = "mis_n",
	PARRY = "par_n",
	REFLECT = "ref_n",
	RESIST = "res_n"
}
