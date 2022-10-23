-- Tables.lua
-- Contains all tables used by different files and modules.
local folder, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale(folder)

-------------------------------------------------------------------------------
-- table we need.

-->> START OF PROTECTED CODE <<--

-- a dummy table used as fallback
local dummyTable = {}
ns.dummyTable = dummyTable

-- this one should be used at modules level
local cacheTable, cacheTable2 = {}, {}
ns.cacheTable = cacheTable
ns.cacheTable2 = cacheTable2

local ignored_spells = {} -- a table of spells that are ignored per module.
local creature_to_fight = {} -- a table of creatures IDs used to fix segments names.
local creature_to_boss = {} -- a table of adds used to deternmine the main boss in encounters.

-- use LibBossIDs-1.0 as backup plan
local LBI = LibStub("LibBossIDs-1.0", true)
if LBI then
	setmetatable(creature_to_boss, {__index = LBI.BossIDs})
end

-- add to Skada scope.
ns.ignored_spells = ignored_spells
ns.creature_to_fight = creature_to_fight
ns.creature_to_boss = creature_to_boss

-->> END OF PROTECTED CODE <<--

-->> START OF EDITABLE CODE <<--

-------------------------------------------------------------------------------
-- ingoredSpells

-- entries should be like so:
-- [spellid] = true

-- [[ absorbs modules ]] --
-- ignored_spells.absorbs = {}

-- [[ buffs module ]] --
ignored_spells.buffs = {
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
ignored_spells.debuffs = {
	[57723] = true, -- Exhaustion (Heroism)
	[57724] = true -- Sated (Bloodlust)
}

-- [[ damage / enemy damage taken modules ]] --
-- ignored_spells.damage = {}

-- [[ damage taken / enemy damage done modules ]] --
-- ignored_spells.damagetaken = {}

-- [[ dispels module ]] --
-- ignored_spells.dispels = {}

-- [[ fails module ]] --
-- ignored_spells.fails = {}

-- [[ friendly fire module ]] --
-- ignored_spells.friendfire = {}

-- [[ healing / enemy healing done modules ]] --
-- ignored_spells.heals = {}

-- [[ interrupts module ]] --
-- ignored_spells.interrupts = {}

-- [[ resources module ]] --
-- ignored_spells.power = {}

-- [[ first hit ignored spells ]] --
ignored_spells.firsthit = {
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
ignored_spells.activeTime = {
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
-- creature_to_fight

-- [[ Icecrown Citadel ]] --
creature_to_fight[36960] = L["Icecrown Gunship Battle"] -- Kor'kron Sergeant
creature_to_fight[36968] = L["Icecrown Gunship Battle"] -- Kor'kron Axethrower
creature_to_fight[36982] = L["Icecrown Gunship Battle"] -- Kor'kron Rocketeer
creature_to_fight[37117] = L["Icecrown Gunship Battle"] -- Kor'kron Battle-Mage
creature_to_fight[37215] = L["Icecrown Gunship Battle"] -- Orgrim's Hammer
creature_to_fight[36961] = L["Icecrown Gunship Battle"] -- Skybreaker Sergeant
creature_to_fight[36969] = L["Icecrown Gunship Battle"] -- Skybreaker Rifleman
creature_to_fight[36978] = L["Icecrown Gunship Battle"] -- Skybreaker Mortar Soldier
creature_to_fight[37116] = L["Icecrown Gunship Battle"] -- Skybreaker Sorcerer
creature_to_fight[37540] = L["Icecrown Gunship Battle"] -- The Skybreaker
creature_to_fight[37970] = L["Blood Prince Council"] -- Prince Valanar
creature_to_fight[37972] = L["Blood Prince Council"] -- Prince Keleseth
creature_to_fight[37973] = L["Blood Prince Council"] -- Prince Taldaram
creature_to_fight[36789] = L["Valithria Dreamwalker"] -- Valithria Dreamwalker
creature_to_fight[36791] = L["Valithria Dreamwalker"] -- Blazing Skeleton
creature_to_fight[37868] = L["Valithria Dreamwalker"] -- Risen Archmage
creature_to_fight[37886] = L["Valithria Dreamwalker"] -- Gluttonous Abomination
creature_to_fight[37934] = L["Valithria Dreamwalker"] -- Blistering Zombie
creature_to_fight[37985] = L["Valithria Dreamwalker"] -- Dream Cloud

-- [[ Naxxramas ]] --
creature_to_fight[16062] = L["The Four Horsemen"] -- Highlord Mograine
creature_to_fight[16063] = L["The Four Horsemen"] -- Sir Zeliek
creature_to_fight[16064] = L["The Four Horsemen"] -- Thane Korth'azz
creature_to_fight[16065] = L["The Four Horsemen"] -- Lady Blaumeux
creature_to_fight[15930] = L["Thaddius"] -- Feugen
creature_to_fight[15929] = L["Thaddius"] -- Stalagg
creature_to_fight[15928] = L["Thaddius"] -- Thaddius

-- [[ Trial of the Crusader ]] --
creature_to_fight[34796] = L["The Northrend Beasts"] -- Gormok
creature_to_fight[35144] = L["The Northrend Beasts"] -- Acidmaw
creature_to_fight[34799] = L["The Northrend Beasts"] -- Dreadscale
creature_to_fight[34797] = L["The Northrend Beasts"] -- Icehowl

-- Champions of the Alliance
creature_to_fight[34461] = L["Faction Champions"] -- Tyrius Duskblade <Death Knight>
creature_to_fight[34460] = L["Faction Champions"] -- Kavina Grovesong <Druid>
creature_to_fight[34469] = L["Faction Champions"] -- Melador Valestrider <Druid>
creature_to_fight[34467] = L["Faction Champions"] -- Alyssia Moonstalker <Hunter>
creature_to_fight[34468] = L["Faction Champions"] -- Noozle Whizzlestick <Mage>
creature_to_fight[34465] = L["Faction Champions"] -- Velanaa <Paladin>
creature_to_fight[34471] = L["Faction Champions"] -- Baelnor Lightbearer <Paladin>
creature_to_fight[34466] = L["Faction Champions"] -- Anthar Forgemender <Priest>
creature_to_fight[34473] = L["Faction Champions"] -- Brienna Nightfell <Priest>
creature_to_fight[34472] = L["Faction Champions"] -- Irieth Shadowstep <Rogue>
creature_to_fight[34463] = L["Faction Champions"] -- Shaabad <Shaman>
creature_to_fight[34470] = L["Faction Champions"] -- Saamul <Shaman>
creature_to_fight[34474] = L["Faction Champions"] -- Serissa Grimdabbler <Warlock>
creature_to_fight[34475] = L["Faction Champions"] -- Shocuul <Warrior>
creature_to_fight[35465] = L["Faction Champions"] -- Zhaagrym <Harkzog's Minion / Serissa Grimdabbler's Minion>

-- Champions of the Horde
creature_to_fight[34441] = L["Faction Champions"] -- Vivienne Blackwhisper <Priest>
creature_to_fight[34444] = L["Faction Champions"] -- Thrakgar <Shaman>
creature_to_fight[34445] = L["Faction Champions"] -- Liandra Suncaller <Paladin>
creature_to_fight[34447] = L["Faction Champions"] -- Caiphus the Stern <Priest>
creature_to_fight[34448] = L["Faction Champions"] -- Ruj'kah <Hunter>
creature_to_fight[34449] = L["Faction Champions"] -- Ginselle Blightslinger <Mage>
creature_to_fight[34450] = L["Faction Champions"] -- Harkzog <Warlock>
creature_to_fight[34451] = L["Faction Champions"] -- Birana Stormhoof <Druid>
creature_to_fight[34453] = L["Faction Champions"] -- Narrhok Steelbreaker <Warrior>
creature_to_fight[34454] = L["Faction Champions"] -- Maz'dinah <Rogue>
creature_to_fight[34455] = L["Faction Champions"] -- Broln Stouthorn <Shaman>
creature_to_fight[34456] = L["Faction Champions"] -- Malithas Brightblade <Paladin>
creature_to_fight[34458] = L["Faction Champions"] -- Gorgrim Shadowcleave <Death Knight>
creature_to_fight[34459] = L["Faction Champions"] -- Erin Misthoof <Druid>
creature_to_fight[35610] = L["Faction Champions"] -- Cat <Ruj'kah's Pet / Alyssia Moonstalker's Pet>

creature_to_fight[34496] = L["Twin Val'kyr"] -- Eydis Darkbane
creature_to_fight[34497] = L["Twin Val'kyr"] -- Fjola Lightbane

-- [[ Ulduar ]] --
creature_to_fight[32857] = L["The Iron Council"] -- Stormcaller Brundir
creature_to_fight[32867] = L["The Iron Council"] -- Steelbreaker
creature_to_fight[32927] = L["The Iron Council"] -- Runemaster Molgeim
creature_to_fight[32930] = L["Kologarn"] -- Kologarn
creature_to_fight[32933] = L["Kologarn"] -- Left Arm
creature_to_fight[32934] = L["Kologarn"] -- Right Arm
creature_to_fight[33515] = L["Auriaya"] -- Auriaya
creature_to_fight[34014] = L["Auriaya"] -- Sanctum Sentry
creature_to_fight[34035] = L["Auriaya"] -- Feral Defender
creature_to_fight[32882] = L["Thorim"] -- Jormungar Behemoth
creature_to_fight[33288] = L["Yogg-Saron"] -- Yogg-Saron
creature_to_fight[33890] = L["Yogg-Saron"] -- Brain of Yogg-Saron
creature_to_fight[33136] = L["Yogg-Saron"] -- Guardian of Yogg-Saron
creature_to_fight[33350] = L["Mimiron"] -- Mimiron
creature_to_fight[33432] = L["Mimiron"] -- Leviathan Mk II
creature_to_fight[33651] = L["Mimiron"] -- VX-001
creature_to_fight[33670] = L["Mimiron"] -- Aerial Command Unit

-------------------------------------------------------------------------------
-- creature_to_boss

-- [[ Icecrown Citadel ]] --
creature_to_boss[36960] = 37215 -- Kor'kron Sergeant > Orgrim's Hammer
creature_to_boss[36968] = 37215 -- Kor'kron Axethrower > Orgrim's Hammer
creature_to_boss[36982] = 37215 -- Kor'kron Rocketeer > Orgrim's Hammer
creature_to_boss[37117] = 37215 -- Kor'kron Battle-Mage > Orgrim's Hammer
creature_to_boss[36961] = 37540 -- Skybreaker Sergeant > The Skybreaker
creature_to_boss[36969] = 37540 -- Skybreaker Rifleman > The Skybreaker
creature_to_boss[36978] = 37540 -- Skybreaker Mortar Soldier > The Skybreaker
creature_to_boss[37116] = 37540 -- Skybreaker Sorcerer > The Skybreaker
creature_to_boss[36791] = 36789 -- Blazing Skeleton
creature_to_boss[37868] = 36789 -- Risen Archmage
creature_to_boss[37886] = 36789 -- Gluttonous Abomination
creature_to_boss[37934] = 36789 -- Blistering Zombie
creature_to_boss[37985] = 36789 -- Dream Cloud

-- [[ Naxxramas ]] --
creature_to_boss[15930] = 15928 -- Feugen > Thaddius
creature_to_boss[15929] = 15928 -- Stalagg > Thaddius

-- [[ Trial of the Crusader ]] --
creature_to_boss[34796] = 34797 -- Gormok > Icehowl
creature_to_boss[35144] = 34797 -- Acidmaw > Icehowl
creature_to_boss[34799] = 34797 -- Dreadscale > Icehowl

-- [[ Ulduar ]] --
creature_to_boss[32933] = 32930 -- Left Arm > Kologarn
creature_to_boss[32934] = 32930 -- Right Arm > Kologarn
creature_to_boss[34014] = 33515 -- Sanctum Sentry > Auriaya
creature_to_boss[34035] = 33515 -- Feral Defender > Auriaya
creature_to_boss[32882] = 32865 -- Jormungar Behemoth > Thorim
creature_to_boss[33890] = 33288 -- Brain of Yogg-Saron > Yogg-Saron
creature_to_boss[33136] = 33288 -- Guardian of Yogg-Saron > Yogg-Saron
creature_to_boss[33432] = 33350 -- Leviathan Mk II > Mimiron
creature_to_boss[33651] = 33350 -- VX-001 > Mimiron
creature_to_boss[33670] = 33350 -- Aerial Command Unit > Mimiron

-->> END OF EDITABLE CODE <<--

-->> DO NOT TOUCH CODE BELOW <<--

-------------------------------------------------------------------------------
-- misc tables

-- miss type to table key
ns.missTypes = {
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

-- resurrect spells
ns.ress_spells = {
	-- Rebirth
	[20484] = 0x08,
	[20739] = 0x08,
	[20742] = 0x08,
	[20747] = 0x08,
	[20748] = 0x08,
	[26994] = 0x08,
	[48477] = 0x08,
	-- Reincarnation
	[16184] = 0x08,
	[16209] = 0x08,
	[20608] = 0x08,
	[21169] = 0x08,
	-- Use Soulstone
	[3026] = 0x01,
	[20758] = 0x01,
	[20759] = 0x01,
	[20760] = 0x01,
	[20761] = 0x01,
	[27240] = 0x01,
	[47882] = 0x01
}
