-- Tables.lua
-- Contains all tables used by different files and modules.
local _, ns = ...
local L = ns.Locale
local setmetatable = setmetatable

-------------------------------------------------------------------------------
-- ingored spells
-- a table of spells that are ignored per module.
-- entries should be like so: [spellid] = true

local ignored_spells = {
	-- [[ absorbs modules ]] --
	-- absorb = {},

	-- [[ buffs module ]] --
	buff = {
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
	},

	-- [[ debuffs module ]] --
	debuff = {
		[57723] = true, -- Exhaustion (Heroism)
		[57724] = true, -- Sated (Bloodlust)
	},

	-- [[ damage / enemy damage taken modules ]] --
	-- damage = {},

	-- [[ damage taken / enemy damage done modules ]] --
	-- damagetaken = {},

	-- [[ dispels module ]] --
	-- dispel = {},

	-- [[ fails module ]] --
	-- fail = {},

	-- [[ friendly fire module ]] --
	-- friendfire = {},

	-- [[ healing / enemy healing done modules ]] --
	-- heal = {
	-- 	[20267] = true, -- Judgement of Light
	-- },

	-- [[ interrupts module ]] --
	-- interrupt = {},

	-- [[ resources module ]] --
	-- power = {},

	-- [[ first hit ignored spells ]] --
	firsthit = {
		[1130] = true, -- Hunter's Mark (rank 1)
		[14323] = true, -- Hunter's Mark (rank 2)
		[14324] = true, -- Hunter's Mark (rank 3)
		[14325] = true, -- Hunter's Mark (rank 4)
		[53338] = true, -- Hunter's Mark (rank 5)
		[56190] = true, -- Shadow Jade Focusing Lens
		[56191] = true, -- Shadow Jade Focusing Lens
		[60122] = true, -- Baby Spice
	},

	-- [[ no active time spells ]] --
	time = {
		-- Retribution Aura
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
}

-------------------------------------------------------------------------------
-- ignored creautre ids (use creature ID: [cretureID] = true)
-- a list of creature IDs of which CLEU <<DAMAGE>> events are ignored.

local ignored_creatures = {}

-------------------------------------------------------------------------------
-- misc tables

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
	[47882] = 0x01,
}

-- list of crowd control spells
ns.cc_spells = {
	[118] = 0x40, -- Polymorph (rank 1)
	[676] = 0x01, -- Disarm
	[710] = 0x20, -- Banish (Rank 1)
	[2070] = 0x01, -- Sap (rank 2)
	[2637] = 0x08, -- Hibernate (rank 1)
	[3355] = 0x10, -- Freezing Trap Effect (rank 1)
	[6358] = 0x20, -- Seduction (succubus)
	[6770] = 0x01, -- Sap (rank 1)
	[9485] = 0x02, -- Shackle Undead (rank 2)
	[9484] = 0x02, -- Shackle Undead (rank 1)
	[10955] = 0x02, -- Shackle Undead (rank 3)
	[11297] = 0x01, -- Sap (rank 3)
	[12809] = 0x01, -- Concussion Blow
	[12824] = 0x40, -- Polymorph (rank 2)
	[12825] = 0x40, -- Polymorph (rank 3)
	[12826] = 0x40, -- Polymorph (rank 4)
	[14308] = 0x10, -- Freezing Trap Effect (rank 2)
	[14309] = 0x10, -- Freezing Trap Effect (rank 3)
	[18647] = 0x20, -- Banish (Rank 2)
	[18657] = 0x08, -- Hibernate (rank 2)
	[18658] = 0x08, -- Hibernate (rank 3)
	[20066] = 0x02, -- Repentance
	[28271] = 0x40, -- Polymorph (rank 1:turtle)
	[28272] = 0x40, -- Polymorph (rank 1:pig)
	[33786] = 0x08, -- Cyclone
	[45524] = 0x10, -- Chains of Ice
	[51514] = 0x08, -- Hex
	[51722] = 0x01, -- Dismantle
	[53308] = 0x08, -- Entangling Roots
	[60210] = 0x10, -- Freezing Arrow (rank 1)
}

-- extended list of crowd control spells
ns.extra_cc_spells = setmetatable({
	-- Warrior
	[5246] = 0x01, -- Initmidating Shout
	[6552] = 0x01, -- Pummel
	[7922] = 0x01, -- Charge
	[12323] = 0x01, -- Piercing Howl
	[46968] = 0x01, -- Shockwave
	[47995] = 0x01, -- Intercept (Stun)--needs review
	[58357] = 0x01, -- Heroic Throw silence
	-- Death Knight
	[47476] = 0x20, -- Strangulate
	[47481] = 0x01, -- Gnaw
	[49203] = 0x10, -- Hungering Cold
	[49560] = 0x01, -- Death Grip
	-- Paladin
	[853] = 0x02, -- Hammer of Justice (rank 1)
	[2812] = 0x02, -- Holy Wrath (rank 1)
	[5588] = 0x02, -- Hammer of Justice (rank 2)
	[5589] = 0x02, -- Hammer of Justice (rank 3)
	[10308] = 0x02, -- Hammer of Justice (rank 4)
	[10318] = 0x02, -- Holy Wrath (rank 2)
	[10326] = 0x02, -- Turn Evil
	[27319] = 0x02, -- Holy Wrath (rank 3)
	[31935] = 0x02, -- Avengers Shield
	[48816] = 0x02, -- Holy Wrath (rank 4)
	[48817] = 0x02, -- Holy Wrath (rank 5)
	-- Priest
	[605] = 0x20, -- Dominate Mind (Mind Control)
	[8122] = 0x20, -- Psychic Scream (rank 1)
	[8124] = 0x20, -- Psychic Scream (rank 2)
	[10888] = 0x20, -- Psychic Scream (rank 3)
	[10890] = 0x20, -- Psychic Scream (rank 4)
	[15487] = 0x20, -- Silence
	[64044] = 0x20, -- Psychic Horror
	-- Shaman
	[3600] = 0x08, -- Earthbind (Earthbind Totem)
	[8034] = 0x10, -- Frostbrand Weapon (rank 1)
	[8037] = 0x10, -- Frostbrand Weapon (rank 2)
	[8056] = 0x10, -- Frost Shock (rank 1)
	[8058] = 0x10, -- Frost Shock (rank 2)
	[10458] = 0x10, -- Frostbrand Weapon (rank 3)
	[10472] = 0x10, -- Frost Shock (rank 3)
	[10473] = 0x10, -- Frost Shock (rank 4)
	[16352] = 0x10, -- Frostbrand Weapon (rank 4)
	[16353] = 0x10, -- Frostbrand Weapon (rank 5)
	[25464] = 0x10, -- Frost Shock (rank 5)
	[25501] = 0x10, -- Frostbrand Weapon (rank 6)
	[39796] = 0x01, -- Stoneclaw Stun (Stoneclaw Totem)
	[49235] = 0x10, -- Frost Shock (rank 6)
	[49236] = 0x10, -- Frost Shock (rank 7)
	[58797] = 0x10, -- Frostbrand Weapon (rank 7)
	[58798] = 0x10, -- Frostbrand Weapon (rank 8)
	[58799] = 0x10, -- Frostbrand Weapon (rank 9)
	[64695] = 0x08, -- Earthgrab
	-- Druid
	[339] = 0x08, -- Entangling Roots (rank 1)
	[1062] = 0x08, -- Entangling Roots (rank 2)
	[5195] = 0x08, -- Entangling Roots (rank 3)
	[5196] = 0x08, -- Entangling Roots (rank 4)
	[8983] = 0x01, -- Bash
	[9852] = 0x08, -- Entangling Roots (rank 5)
	[9853] = 0x08, -- Entangling Roots (rank 6)
	[16979] = 0x01, -- Feral Charge - Bear
	[19970] = 0x08, -- Entangling Roots (Nature's Grasp rank 6)
	[19971] = 0x08, -- Entangling Roots (Nature's Grasp rank 5)
	[19972] = 0x08, -- Entangling Roots (Nature's Grasp rank 4)
	[19973] = 0x08, -- Entangling Roots (Nature's Grasp rank 3)
	[19974] = 0x08, -- Entangling Roots (Nature's Grasp rank 2)
	[19975] = 0x08, -- Entangling Roots (Nature's Grasp rank 1)
	[22570] = 0x01, -- Maim (rank 1)
	[26989] = 0x08, -- Entangling Roots (rank 7)
	[27010] = 0x08, -- Entangling Roots (Nature's Grasp rank 7)
	[45334] = 0x01, -- Feral Charge Effect
	[49802] = 0x01, -- Maim (rank 2)
	[49803] = 0x01, -- Pounce
	[53313] = 0x08, -- Entangling Roots (Nature's Grasp)
	[66070] = 0x08, -- Entangling Roots (Force of Nature)
	-- Rogue
	[408] = 0x01, -- Kidney Shot (rank 1)
	[1330] = 0x01, -- Garrote - Silence
	[1776] = 0x01, -- Gouge
	[1833] = 0x01, -- Cheap Shot
	[2094] = 0x01, -- Blind
	[8643] = 0x01, -- Kidney Shot (rank 2)
	[51724] = 0x01, -- Sap
	-- Mage
	[122] = 0x10, -- Frost Nova (rank 1)
	[865] = 0x10, -- Frost Nova (rank 2)
	[6131] = 0x10, -- Frost Nova (rank 3)
	[10230] = 0x10, -- Frost Nova (rank 4)
	[27088] = 0x10, -- Frost Nova (rank 5)
	[31661] = 0x04, -- Dragon's Breath
	[33395] = 0x10, -- Freeze (Frost Water Elemental)
	[42917] = 0x10, -- Frost Nova (rank 6)
	[44572] = 0x10, -- Deep Freeze
	[55021] = 0x40, -- Silenced - Improved Counterspell
	[61305] = 0x40, -- Polymorph Cat
	[61721] = 0x40, -- Polymorph Rabbit
	[61780] = 0x40, -- Polymorph Turkey
	-- Warlock
	[5484] = 0x20, -- Howl of Terror
	[6215] = 0x20, -- Fear
	[6789] = 0x20, -- Death Coil (rank 1)
	[17925] = 0x20, -- Death Coil (rank 2)
	[17926] = 0x20, -- Death Coil (rank 3)
	[22703] = 0x04, -- Infernal Awakening
	[24259] = 0x20, -- Spell Lock
	[27223] = 0x20, -- Death Coil (rank 4)
	[30283] = 0x20, -- Shadowfury
	[47859] = 0x20, -- Death Coil (rank 5)
	[47860] = 0x20, -- Death Coil (rank 6)
	-- Hunter
	[1513] = 0x08, -- Scare Beast
	[4167] = 0x01, -- Web (Spider)
	[5116] = 0x01, -- Concussive Shot
	[19386] = 0x08, -- Wyvern Sting (rank 1)
	[19503] = 0x01, -- Scatter Shot
	[19577] = 0x08, -- Intimidation (stun)
	[24132] = 0x08, -- Wyvern Sting (rank 2)
	[24133] = 0x08, -- Wyvern Sting (rank 3)
	[24394] = 0x01, -- Intimidation
	[26090] = 0x08, -- Pummel (Gorilla)
	[27068] = 0x08, -- Wyvern Sting (rank 4)
	[49011] = 0x08, -- Wyvern Sting (rank 5)
	[49012] = 0x08, -- Wyvern Sting (rank 6)
	[50541] = 0x01, -- Clench (Scorpid)
	[53543] = 0x01, -- Snatch (Bird of Prey)
	[53548] = 0x01, -- Pin (Crab)
	[53562] = 0x01, -- Ravage (Ravager)
	[53568] = 0x08, -- Sonic Blast (Bat)
	[53575] = 0x01, -- Tendon Rip (Hyena)
	[53589] = 0x20, -- Nether Shock (Nether Ray)
	[55492] = 0x10, -- Froststorm Breath (Chimaera)
	[55509] = 0x08, -- Venom Web Spray (Silithid)
	[64803] = 0x01, -- Entrapment
	-- Racials
	[20549] = 0x01, -- War Stomp (Tauren)
	[28730] = 0x40, -- Arcane Torrent (Bloodelf)
	[47779] = 0x40, -- Arcane Torrent (Bloodelf)
	[50613] = 0x40, -- Arcane Torrent (Bloodelf)
	-- Engineering
	[67890] = 0x04, -- Cobalt Frag Bomb
}, {__index = ns.cc_spells})

-- deathlog tracked buffs.
do
	local spellnames = ns.spellnames
	ns.deathlog_tracked_buff = {
		-- Warrior
		[spellnames[871]] = true, -- Shield Wall
		[spellnames[2565]] = true, -- Shield Block
		[spellnames[12975]] = true, -- Last Stand
		[spellnames[23920]] = true, -- Spell Reflection
		[spellnames[58374]] = true, -- Glyph of Blocking
		-- Death Knight
		[spellnames[42650]] = true, -- Army of the Dead
		[spellnames[45529]] = true, -- Blood Tap
		[spellnames[48707]] = true, -- Anti-Magic Shell
		[spellnames[48792]] = true, -- Icebound Fortitude
		[spellnames[48982]] = true, -- Rune Tap
		[spellnames[49039]] = true, -- Lichborne
		[spellnames[49182]] = true, -- Blade Barrier
		[spellnames[49222]] = true, -- Bone Shield
		[spellnames[51052]] = true, -- Anti-Magic Zone
		[spellnames[51271]] = true, -- Unbreakable Armor
		[spellnames[54223]] = true, -- Shadow of Death
		[spellnames[55233]] = true, -- Vampiric Blood
		[spellnames[70654]] = true, -- Blood Armor
		-- Paladin
		[spellnames[498]] = true, -- Divine Protection
		[spellnames[633]] = true, -- Lay on Hands
		[spellnames[642]] = true, -- Divine Shield
		[spellnames[1022]] = true, -- Hand of Protection
		[spellnames[1038]] = true, -- Hand of Salvation
		[spellnames[1044]] = true, -- Hand of Freedom
		[spellnames[6940]] = true, -- Hand of Sacrifice
		[spellnames[19752]] = true, -- Divine Intervention
		[spellnames[20925]] = true, -- Holy Shield
		[spellnames[31821]] = true, -- Aura Mastery
		[spellnames[31850]] = true, -- Ardent Defender
		[spellnames[31884]] = true, -- Avenging Wrath
		[spellnames[64205]] = true, -- Divine Sacrifice
		[spellnames[70940]] = true, -- Divine Guardian
		-- Priest
		[spellnames[17]] = true, -- Power Word: Shield
		[spellnames[586]] = true, -- Fade
		[spellnames[14893]] = true, -- Inspiration
		[spellnames[27827]] = true, -- Spirit of Redemption
		[spellnames[33206]] = true, -- Pain Suppression
		[spellnames[47585]] = true, -- Dispersion
		[spellnames[47788]] = true, -- Guardian Spirit
		[spellnames[64843]] = true, -- Divine Hymn
		-- Shaman
		[spellnames[16177]] = true, -- Ancestral Fortitude
		[spellnames[30823]] = true, -- Shamanistic Rage
		-- Druid
		[spellnames[5487]] = true, -- Bear Form
		[spellnames[8998]] = true, -- Cower
		[spellnames[9634]] = true, -- Dire Bear Form
		[spellnames[22812]] = true, -- Barkskin
		[spellnames[22842]] = true, -- Frenzied Regeneration
		[spellnames[61336]] = true, -- Survival Instincts
		[spellnames[62606]] = true, -- Savage Defense
		[spellnames[70725]] = true, -- Enraged Defense
		-- Rogue
		[spellnames[1856]] = true, -- Vanish
		[spellnames[1966]] = true, -- Feint
		[spellnames[5277]] = true, -- Evasion
		[spellnames[31224]] = true, -- Cloak of Shadows
		-- Mage
		[spellnames[66]] = true, -- Invisibility
		[spellnames[543]] = true, -- Fire Ward
		[spellnames[1463]] = true, -- Mana shield
		[spellnames[1953]] = true, -- Blink
		[spellnames[6143]] = true, -- Frost Ward
		[spellnames[11426]] = true, -- Ice Barrier
		[spellnames[45438]] = true, -- Ice Block
		[spellnames[55342]] = true, -- Mirror Image
		-- Warlock
		[spellnames[6229]] = true, -- Shadow Ward
		-- Hunter
		[spellnames[781]] = true, -- Disengage
		[spellnames[5384]] = true, -- Feign Death
		[spellnames[19263]] = true, -- Deterrence
		-- Items
		[spellnames[54861]] = true, -- Nitro Boosts
		[spellnames[60180]] = true, -- Repelling Charge (Resolute)
		[spellnames[60286]] = true, -- Defender's Code
		[spellnames[64763]] = true, -- Heart of Iron
		[spellnames[65011]] = true, -- Furnace Stone
		[spellnames[65012]] = true, -- Royal Seal of King Llane
		[spellnames[67596]] = true, -- Battlemaster's PvP (Tremendous Fortitude)
		[spellnames[67631]] = true, -- The Black Heart (Aegis)
		[spellnames[67694]] = true, -- Glyph of Indomitability (Defensive Tactics)
		[spellnames[67753]] = true, -- Juggernaut's Vitality/Satrina's Impeding Scarab (Fortitude)
		[spellnames[68443]] = true, -- Brawler's Souvenir (Drunken Evasiveness)
		[spellnames[71569]] = true, -- Ick's Rotting Thumb (Increased Fortitude)
		[spellnames[71586]] = true, -- Corroded Skeleton Key (Hardened Skin)
		[spellnames[71638]] = true, -- Sindragosa's Flawless Fang (Aegis of Dalaran)
		[spellnames[71639]] = true, -- Corpse Tongue Coin (Thick Skin)
		[spellnames[75480]] = true, -- Petrified Twilight Scale (Scaly Nimbleness)
	}
end

-------------------------------------------------------------------------------
-- grouped and custom units

do
	------------------------------------------------------
	-- grouped units (fake)
	------------------------------------------------------
	--
	-- holds the units to which the damage done is collected
	-- into a single standalone fake unit.
	--
	-- table structure:
	-- option #1:	[creature id] = "Group Name"
	-- option #2:	[creature name] = "Group Name"
	--

	local grouped_units = {
		-- EXPERIMENTAL: instance bosses and trash grouped units.
		-- IMPORTANT: only recorded to the total segment.
		BOSS = true,
		TRASH = true,

		-- The Lich King: Important targets
		[36597] = L["Important targets"], -- The Lich King
		[36609] = L["Important targets"], -- Val'kyr Shadowguard
		[36633] = L["Important targets"], -- Ice Sphere
		[36701] = L["Important targets"], -- Raging Spirit
		[39190] = L["Important targets"], -- Wicked Spirit

		-- Professor Putricide: Oozes
		[37562] = L["Oozes"], -- Gas Cloud (Red Ooze)
		[37697] = L["Oozes"], -- Volatile Ooze (Green Ooze)

		-- Blood Prince Council: Princes overkilling
		[37970] = L["Princes overkilling"], -- Prince Valanar
		[37972] = L["Princes overkilling"], -- Prince Keleseth
		[37973] = L["Princes overkilling"], -- Prince Taldaram

		-- Lady Deathwhisper: Adds
		[37949] = L["Adds"], -- Cult Adherent
		[38136] = L["Adds"], -- Empowered Adherent
		[38010] = L["Adds"], -- Reanimated Adherent
		[37890] = L["Adds"], -- Cult Fanatic
		[38135] = L["Adds"], -- Deformed Fanatic
		[38009] = L["Adds"], -- Reanimated Fanatic
		[38472] = L["Adds"], -- Darnavan

		-- Halion: Halion and Inferno
		[39863] = L["Halion and Inferno"], -- Halion
		[40681] = L["Halion and Inferno"], -- Living Inferno

		-- Anub'arak: Adds
		[34605] = L["Adds"], -- Swarm Scarab
		[34607] = L["Adds"], -- Nerubian Burrower
	}

	------------------------------------------------------
	-- custom units (fake)
	------------------------------------------------------
	--
	-- holds units that should craete a fake unit at certain
	-- health or power percentage.
	-- Useful in case you want to collect stuff done to units
	-- at certain encounter phases for example.
	--
	-- table structure (all fields are optional and will be generated and cached by the addon)
	--	start: 		when to start collecting (0.01 = 1%, default: 100%)
	--	stop:		when to stop collecting (0.01 = 1%, default: 0%)
	--	power:		whether to track the speficied power or health
	--		0 - Mana
	--		1 - Rage
	--		2 - Focus
	--		3 - Energy
	--		4 - Happiness
	--		5 - Runes
	--		6 - Runic Power
	--
	-- 	name: 		name of the fake unit (optional)
	-- 	text: 		text to use *format()* with (optional)
	-- 	values: 	table of difficulties to max health (optional)
	-- 	diff: 		table of whitelisted difficulties (optional, default: all)
	--		{["10h"] = true, ["25h"] = true}
	--
	-- **optional** fields will be generated and cached by the addon.
	--
	local custom_units = {
		-- ICC: Lady Deathwhisper
		[36855] = {
			{text = L["%s - Phase 1"], start = 1, power = 0},
			{text = L["%s - Phase 2"], start = 0, power = 0}
		},

		-- ICC: Professor Putricide
		[36678] = {
			text = L["%s - Phase 3"],
			start = 0.35
		},

		-- ICC: Sindragosa
		[36853] = {
			text = L["%s - Phase 2"],
			start = 0.35
		},

		-- ICC: The Lich King
		[36597] = {
			text = L["%s - Phase 3"],
			start = 0.4,
			stop = 0.1
		},

		-- ICC: Valkyrs overkilling
		[36609] = {
			name = L["Valkyrs overkilling"],
			start = 0.5,
			useful = true,
			diff = {["10h"] = true, ["25h"] = true}
		},

		-- ToC: Anub'arak
		[34564] = {
			text = L["%s - Phase 2"],
			start = 0.3
		},

		-- Baltharus the Warborn
		[39751] = {
			text = L["%s (Main Boss)"]
		}
	}

	------------------------------------------------------

	ns.grouped_units = grouped_units
	ns.custom_units = custom_units
end

-------------------------------------------------------------------------------
-- DO NOT EDIT THE CODE BELOW (unless you know what you're doing)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- creature_to_fight
-- a table of creatures IDs used to fix segments names.

ns.creature_to_fight = {
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
	[33670] = L["Mimiron"], -- Aerial Command Unit
}

-------------------------------------------------------------------------------
-- creature_to_boss
-- a table of adds used to deternmine the main boss in encounters.

ns.creature_to_boss = {
	-- [[ Icecrown Citadel ]] --
	[36960] = 37215, -- Kor'kron Sergeant > Orgrim's Hammer
	[36968] = 37215, -- Kor'kron Axethrower > Orgrim's Hammer
	[36982] = 37215, -- Kor'kron Rocketeer > Orgrim's Hammer
	[37117] = 37215, -- Kor'kron Battle-Mage > Orgrim's Hammer
	[36961] = 37540, -- Skybreaker Sergeant > The Skybreaker
	[36969] = 37540, -- Skybreaker Rifleman > The Skybreaker
	[36978] = 37540, -- Skybreaker Mortar Soldier > The Skybreaker
	[37116] = 37540, -- Skybreaker Sorcerer > The Skybreaker
	[36791] = 36789, -- Blazing Skeleton > Valithria Dreamwalker
	[37868] = 36789, -- Risen Archmage > Valithria Dreamwalker
	[37886] = 36789, -- Gluttonous Abomination > Valithria Dreamwalker
	[37934] = 36789, -- Blistering Zombie > Valithria Dreamwalker
	[37985] = 36789, -- Dream Cloud > Valithria Dreamwalker

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
	[33670] = 33350, -- Aerial Command Unit > Mimiron
}

-- use LibBossIDs-1.0 as backup plan
local LBI = LibStub("LibBossIDs-1.0")
setmetatable(ns.creature_to_boss, {__index = LBI.BossIDs})
ns.BossIDs = LBI.BossIDs -- needed for some CLEU stuff.

-------------------------------------------------------------------------------

-- ignored spells table
local dummyTable = ns.dummyTable
ns.ignored_spells = setmetatable(ignored_spells, {__index = function(t, key)
	return dummyTable
end})

-- ignored creatures table
ns.ignored_creatures = ignored_creatures

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
	RESIST = "res_n",
}

-- list of combat events that we don't care about
ns.ignored_events = {
	ENCHANT_APPLIED = true,
	ENCHANT_REMOVED = true,
	PARTY_KILL = true,
	SPELL_AURA_REMOVED_DOSE = true,
	SPELL_CAST_FAILED = true,
	SPELL_CAST_START = true,
	SPELL_CAST_SUCCESS = true,
	SPELL_CREATE = true,
	SPELL_DISPEL_FAILED = true,
	SPELL_DRAIN = true,
	SPELL_DURABILITY_DAMAGE = true,
	SPELL_DURABILITY_DAMAGE_ALL = true,
	SPELL_PERIODIC_DRAIN = true
}

-- events used to start combat in aggressive combat detection
-- mode as well as boss encounter detection.
ns.trigger_events = {
	SWING_DAMAGE = true,
	SPELL_DAMAGE = true,
	RANGE_DAMAGE = true,
    DAMAGE_SHIELD = true,
	SPELL_BUILDING_DAMAGE = true
}

-- local segment types used for set tooltips.
ns.segment_types = {
	arena = L["Arena"],
	group = L["Group"],
	none = L["None"],
	party = L["Dungeon"],
	pvp = L["Battleground"],
	raid = L["Raid"]
}
