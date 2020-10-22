local MAJOR, MINOR = "LibFail-1.0", tonumber("255") or 999

assert(LibStub, MAJOR.." requires LibStub")

local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
local callbacks = lib.callbacks

lib.frame = lib.frame or CreateFrame("Frame")
local frame = lib.frame

frame:RegisterEvent("PLAYER_ENTERING_WORLD")

--- Fail Events.
--@description The list of supported events
--@class table
--@name fail_events
--@field 1  Fail_Deconstructor_Light
--@field 2  Fail_Deconstructor_Gravity
--@field 3  Fail_Frogger
--@field 4  Fail_Heigan_Dance
--@field 5  Fail_KelThuzad_VoidZone
--@field 6  Fail_Mimiron_BombBots
--@field 7  Fail_Mimiron_Rocket
--@field 8  Fail_Mimiron_Shock
--@field 9  Fail_Sapphiron_Breath
--@field 10 Fail_Sartharion_LavaWaves
--@field 11 Fail_Sartharion_VoidZone
--@field 12 Fail_Thaddius_Jump
--@field 13 Fail_Thaddius_PolaritySwitch
--@field 14 Fail_Thorim_LightningChain
--@field 15 Fail_Thorim_LightningCharge
--@field 16 Fail_Thorim_Smash
--@field 17 Fail_Vezax_ShadowCrash
--@field 18 Fail_Vezax_Saronite
--@field 19 Fail_Hodir_FlashFreeze
--@field 20 Fail_Vezax_Leech
--@field 21 Fail_Mimiron_LaserBarrage
--@field 22 Fail_Mimiron_Flames
--@field 23 Fail_Council_Overload
--@field 24 Fail_Hodir_Icicle
--@field 25 Fail_Grobbulus_PoisonCloud
--@field 26 Fail_Freya_NatureBomb
--@field 27 Fail_Thorim_Blizzard
--@field 28 Fail_Yogg_Sanity
--@field 29 Fail_Yogg_DeathRay
--@field 30 Fail_Razorscale_Flame
--@field 31 Fail_Kologarn_Eyebeam
--@field 32 Fail_Auriaya_Voidzone
--@field 33 Fail_Hodir_BitingCold
--@field 34 Fail_Malygos_Dot
--@field 35 Fail_Gormok_FireBomb
--@field 36 Fail_Acidmaw_SlimePool
--@field 37 Fail_Acidmaw_AcidicSpew
--@field 38 Fail_Acidmaw_ParalyticToxin
--@field 39 Fail_Dreadscale_MoltenSpew
--@field 40 Fail_Icehowl_Trample
--@field 41 Fail_Jaraxxus_FelInferno
--@field 42 Fail_Jaraxxus_LegionFlame
--@field 43 Fail_FactionChampions_Hellfire
--@field 44 Fail_Valkyr_Orb
--@field 45 Fail_Valkyr_Vortex
--@field 46 Fail_Anubarak_Impale
--@field 47 Fail_Mimiron_WaterSpray
--@field 48 Fail_Mimiron_ProximityMine
--@field 49 Fail_Mimiron_FrostBomb
--@field 50 Fail_Yogg_LunaticGaze
--@field 51 Fail_Algalon_BigBang
--@field 52 Fail_Mimiron_Siren
--@field 53 Fail_Koralon_MeteorFist
--@field 54 Fail_Horsemen_VoideZone
--@field 55 Fail_Horsemen_Mark
--@field 56 Fail_Onyxia_FlameBreath
--@field 57 Fail_Onyxia_TailSweep
--@field 58 Fail_Archavon_ChokingCloud
--@field 59 Fail_Emalon_LightningNova
--@field 60 Fail_Emalon_ChainLightning
--@field 61 Fail_Koralon_FlameCinder
--@field 62 Fail_Auriaya_SonicScreech
--@field 63 Fail_Onyxia_DeepBreath
--@field 64 Fail_Algalon_CosmicSmash
--@field 65 Fail_Mimiron_NapalmShell
--@field 66 Fail_Freya_UnstableEnergy
--@field 67 Fail_Council_RuneOfDeath
--@field 68 Fail_Grobbulus_MutatingInjection
--@field 69 Fail_Yogg_OminousCloud
--@field 70 Fail_Marrowgar_Coldflame
--@field 71 Fail_Rotface_StickyOoze
--@field 72 Fail_Rotface_OozeExplosion
--@field 73 Fail_Onyxia_WarderNova
--@field 74 Fail_Onyxia_WarderCleave
--@field 75 Fail_Onyxia_Cleave
--@field 76 Fail_Malygos_ArcaneBreath
--@field 77 Fail_Algalon_Blackhole
--@field 78 Fail_Yogg_Malady
--@field 79 Fail_Freya_GroundTremor
--@field 80 Fail_Ignis_FlameJets
--@field 81 Fail_Freya_BindLife
--@field 82 Fail_Deconstructor_Voidzone
--@field 83 Fail_Marrowgar_Whirlwind
--@field 84 Fail_Marrowgar_SaberLash
--@field 85 Fail_Festergut_VileGas
--@field 86 Fail_Festergut_PungentBlight
--@field 87 Fail_Sartharion_Breath
--@field 88 Fail_Sartharion_TailLash
--@field 89 Fail_Deathwhisper_DeathNDecay
--@field 90 Fail_Sapphiron_TailSweep
--@field 91 Fail_Sapphiron_Cleave
--@field 92 Fail_Sindragosa_TailSmash
--@field 93 Fail_Sindragosa_FrostBreath
--@field 94 Fail_Sindragosa_BlisteringCold
--@field 96 Fail_Sindragosa_Cleave
--@field 97 Fail_Sindragosa_Instability
--@field 98 Fail_Sindragosa_FrostBomb
--@field 99 Fail_Sindragosa_IceTomb
--@field 100 Fail_Professor_MutatedSlime
--@field 101 Fail_LanaThel_UncontrollableFrenzy
--@field 102 Fail_LanaThel_BloodboltSplash
--@field 103 Fail_BloodPrinces_SystemicShockVortex
--@field 104 Fail_LanaThel_DeliriousSlash
--@field 105 Fail_Gunship_Explosion
--@field 106 Fail_Gunship_Explosion_Knockback
--@field 107 Fail_FactionChampions_Bladestorm
--@field 108 Fail_Saurfang_Rune
--@field 109 Fail_Saurfang_Beasts
--@field 110 Fail_Deathwhisper_Shade
--@field 111 Fail_Professor_MalleableGoo
--@field 112 Fail_Rotface_SlimeSpray
--@field 113 Fail_BloodPrinces_Flames
--@field 114 Fail_LanaThel_Pact
--@field 115 Fail_LanaThel_SwarmingShadows
--@field 116 Fail_ColdflameTrap
--@field 117 Fail_Professor_ChokingGas
--@field 118 Fail_Valithria_ColumnofFrost
--@field 119 Fail_TheLichKing_IceBurst
--@field 120 Fail_Sindragosa_ChilledtotheBone
--@field 121 Fail_TheLichKing_RemorselessWinter
--@field 122 Fail_TheLichKing_NecroticPlague
--@field 123 Fail_TheLichKing_ShadowTrap
--@field 124 Fail_Festergut_MalleableGoo
--@field 125 Fail_TheLichKing_Defile
--@field 126 Fail_TheLichKing_Shockwave
--@field 127 Fail_TheLichKing_SpiritBomb
--@field 128 Fail_Deathwhisper_ShadeExplosion
--@field 129 Fail_Halion_TwilightCutter
--@field 129 Fail_Halion_MeteorStrike
--@field 130 Fail_Sindragosa_MysticBuffet
--@field 131 Fail_Valithria_EmeraldVigor
--@field 132 Fail_TheLichKing_SoulShriek
--@field 133 Fail_BloodPrinces_KineticBomb

local fail_events = {
    "Fail_Deconstructor_Light",
    "Fail_Deconstructor_Gravity",
    "Fail_Frogger",
    "Fail_Heigan_Dance",
    "Fail_KelThuzad_VoidZone",
    "Fail_Mimiron_BombBots",
    "Fail_Mimiron_Rocket",
    "Fail_Mimiron_Shock",
    "Fail_Sapphiron_Breath",
    "Fail_Sartharion_LavaWaves",
    "Fail_Sartharion_VoidZone",
    "Fail_Thaddius_Jump",
    "Fail_Thaddius_PolaritySwitch",
    "Fail_Thorim_LightningChain",
    "Fail_Thorim_LightningCharge",
    "Fail_Thorim_Smash",
    "Fail_Vezax_ShadowCrash",
    "Fail_Vezax_Saronite",
    "Fail_Vezax_Leech",
    "Fail_Hodir_FlashFreeze",
    "Fail_Mimiron_LaserBarrage",
    "Fail_Mimiron_Flames",
    "Fail_Council_Overload",
    "Fail_Hodir_Icicle",
    "Fail_Grobbulus_PoisonCloud",
    "Fail_Freya_NatureBomb",
    "Fail_Thorim_Blizzard",
    "Fail_Yogg_Sanity",
    "Fail_Yogg_DeathRay",
    "Fail_Razorscale_Flame",
    "Fail_Kologarn_Eyebeam",
    "Fail_Auriaya_Voidzone",
    "Fail_Hodir_BitingCold",
    "Fail_Malygos_Dot",
    "Fail_Gormok_FireBomb",
    "Fail_Acidmaw_SlimePool",
    "Fail_Acidmaw_AcidicSpew",
    "Fail_Acidmaw_ParalyticToxin",
    "Fail_Dreadscale_MoltenSpew",
    "Fail_Icehowl_Trample",
    "Fail_Jaraxxus_FelInferno",
    "Fail_Jaraxxus_LegionFlame",
    "Fail_FactionChampions_Hellfire",
    "Fail_Valkyr_Orb",
    "Fail_Valkyr_Vortex",
    "Fail_Anubarak_Impale",
    "Fail_Mimiron_WaterSpray",
    "Fail_Mimiron_ProximityMine",
    "Fail_Mimiron_FrostBomb",
    "Fail_Yogg_LunaticGaze",
    "Fail_Algalon_BigBang",
    "Fail_Mimiron_Siren",
    "Fail_Koralon_MeteorFist",
    "Fail_Horsemen_VoideZone",
    "Fail_Horsemen_Mark",
    "Fail_Onyxia_FlameBreath",
    "Fail_Onyxia_TailSweep",
    "Fail_Archavon_ChokingCloud",
    "Fail_Emalon_LightningNova",
    "Fail_Emalon_ChainLightning",
    "Fail_Koralon_FlameCinder",
    "Fail_Auriaya_SonicScreech",
    "Fail_Onyxia_DeepBreath",
    "Fail_Algalon_CosmicSmash",
    "Fail_Mimiron_NapalmShell",
    "Fail_Freya_UnstableEnergy",
    "Fail_Council_RuneOfDeath",
    "Fail_Grobbulus_MutatingInjection",
    "Fail_Yogg_OminousCloud",
    "Fail_Marrowgar_Coldflame",
    "Fail_Rotface_StickyOoze",
    "Fail_Rotface_OozeExplosion",
    "Fail_Onyxia_WarderNova",
    "Fail_Onyxia_WarderCleave",
    "Fail_Onyxia_Cleave",
    "Fail_Malygos_ArcaneBreath",
    "Fail_Algalon_Blackhole",
    "Fail_Yogg_Malady",
    "Fail_Freya_GroundTremor",
    "Fail_Ignis_FlameJets",
    "Fail_Freya_BindLife",
    "Fail_Deconstructor_Voidzone",
    "Fail_Marrowgar_Whirlwind",
    "Fail_Marrowgar_SaberLash",
    "Fail_Festergut_VileGas",
    "Fail_Festergut_PungentBlight",
    "Fail_Sartharion_Breath",
    "Fail_Sartharion_TailLash",
    "Fail_Deathwhisper_DeathNDecay",
    "Fail_Sapphiron_TailSweep",
    "Fail_Sapphiron_Cleave",
    "Fail_Sindragosa_TailSmash",
    "Fail_Sindragosa_FrostBreath",
    "Fail_Sindragosa_BlisteringCold",
    "Fail_Sindragosa_Cleave",
    "Fail_Sindragosa_Instability",
    "Fail_Sindragosa_FrostBomb",
    "Fail_Sindragosa_IceTomb",
    "Fail_Professor_MutatedSlime",
    "Fail_LanaThel_UncontrollableFrenzy",
    "Fail_LanaThel_BloodboltSplash",
    "Fail_BloodPrinces_SystemicShockVortex",
    "Fail_LanaThel_DeliriousSlash",
    "Fail_Gunship_Explosion",
    "Fail_Gunship_Explosion_Knockback",
    "Fail_FactionChampions_Bladestorm",
    "Fail_Saurfang_Rune",
    "Fail_Saurfang_Beasts",
    "Fail_Deathwhisper_Shade",
    "Fail_Professor_MalleableGoo",
    "Fail_Rotface_SlimeSpray",
    "Fail_BloodPrinces_Flames",
    "Fail_LanaThel_Pact",
    "Fail_LanaThel_SwarmingShadows",
    "Fail_ColdflameTrap",
    "Fail_Professor_ChokingGas",
    "Fail_Valithria_ColumnofFrost",
    "Fail_TheLichKing_IceBurst",
    "Fail_Sindragosa_ChilledtotheBone",
    "Fail_TheLichKing_RemorselessWinter",
    "Fail_TheLichKing_NecroticPlague",
    "Fail_TheLichKing_ShadowTrap",
    "Fail_TheLichKing_SoulShriek",
    "Fail_Festergut_MalleableGoo",
    "Fail_TheLichKing_Defile",
    "Fail_TheLichKing_Shockwave",
    "Fail_TheLichKing_SpiritBomb",
    "Fail_Deathwhisper_ShadeExplosion",
    "Fail_Halion_TwilightCutter",
    "Fail_Halion_MeteorStrike",
    "Fail_Sindragosa_MysticBuffet",
    "Fail_Valithria_EmeraldVigor",
    "Fail_BloodPrinces_KineticBomb",
}

--[===[@debug@
function lib:Test(overrideName)
    local e = math.floor(math.random() * #fail_events) + 1
    local p = math.floor(math.random() * 5) + 1

    self:FailEvent(fail_events[e], overrideName or "Test"..p, lib.FAIL_TYPE_MOVING)
end
--@end-debug@]===]

local zones_with_fails = {
    ["The Ruby Sanctum"] = {
        "Fail_Halion_TwilightCutter",
        "Fail_Halion_MeteorStrike",
    },
    ["Icecrown Citadel"] = {
        "Fail_Rotface_StickyOoze",
        "Fail_Rotface_OozeExplosion",
        "Fail_Marrowgar_Whirlwind",
        "Fail_Marrowgar_Coldflame",
        "Fail_Marrowgar_SaberLash",
        "Fail_Festergut_VileGas",
        "Fail_Festergut_PungentBlight",
        "Fail_Deathwhisper_DeathNDecay",
        "Fail_Sindragosa_TailSmash",
        "Fail_Sindragosa_FrostBreath",
        "Fail_Sindragosa_BlisteringCold",
        "Fail_Sindragosa_Cleave",
        "Fail_Sindragosa_Instability",
        "Fail_Sindragosa_FrostBomb",
        "Fail_Sindragosa_IceTomb",
        "Fail_Sindragosa_MysticBuffet",
        "Fail_Professor_MutatedSlime",
        "Fail_LanaThel_UncontrollableFrenzy",
        "Fail_LanaThel_BloodboltSplash",
        "Fail_BloodPrinces_SystemicShockVortex",
        "Fail_BloodPrinces_KineticBomb",
        "Fail_LanaThel_DeliriousSlash",
        "Fail_Gunship_Explosion",
        "Fail_Gunship_Explosion_Knockback",
        "Fail_Saurfang_Rune",
        "Fail_Saurfang_Beasts",
        "Fail_Deathwhisper_Shade",
        "Fail_Professor_MalleableGoo",
        "Fail_Rotface_SlimeSpray",
        "Fail_BloodPrinces_Flames",
        "Fail_LanaThel_Pact",
        "Fail_LanaThel_SwarmingShadows",
        "Fail_ColdflameTrap",
        "Fail_Professor_ChokingGas",
        "Fail_Valithria_ColumnofFrost",
        "Fail_Valithria_EmeraldVigor",
        "Fail_TheLichKing_IceBurst",
        "Fail_Sindragosa_ChilledtotheBone",
        "Fail_TheLichKing_RemorselessWinter",
        "Fail_TheLichKing_NecroticPlague",
        "Fail_TheLichKing_ShadowTrap",
        "Fail_TheLichKing_SoulShriek",
        "Fail_Festergut_MalleableGoo",
        "Fail_TheLichKing_Defile",
        "Fail_TheLichKing_Shockwave",
        "Fail_TheLichKing_SpiritBomb",
        "Fail_Deathwhisper_ShadeExplosion",
    },
    ["Onyxia's Lair"] = {
        "Fail_Onyxia_FlameBreath",
        "Fail_Onyxia_TailSweep",
        "Fail_Onyxia_DeepBreath",
        "Fail_Onyxia_WarderNova",
        "Fail_Onyxia_WarderCleave",
        "Fail_Onyxia_Cleave",
    },
    ["Trial of the Crusader"] = {
        "Fail_Gormok_FireBomb",
        "Fail_Acidmaw_SlimePool",
        "Fail_Acidmaw_AcidicSpew",
        "Fail_Acidmaw_ParalyticToxin",
        "Fail_Dreadscale_MoltenSpew",
        "Fail_Icehowl_Trample",
        "Fail_Jaraxxus_FelInferno",
        "Fail_Jaraxxus_LegionFlame",
        "Fail_FactionChampions_Hellfire",
        "Fail_Valkyr_Orb",
        "Fail_Valkyr_Vortex",
        "Fail_Anubarak_Impale",
        "Fail_FactionChampions_Bladestorm",
    },
    Ulduar = {
        "Fail_Deconstructor_Light",
        "Fail_Deconstructor_Gravity",
        "Fail_Hodir_FlashFreeze",
        "Fail_Hodir_BitingCold",
        "Fail_Hodir_Icicle",
        "Fail_Mimiron_BombBots",
        "Fail_Mimiron_Rocket",
        "Fail_Mimiron_Shock",
        "Fail_Mimiron_LaserBarrage",
        "Fail_Mimiron_Flames",
        "Fail_Thorim_LightningChain",
        "Fail_Thorim_LightningCharge",
        "Fail_Thorim_Smash",
        "Fail_Thorim_Blizzard",
        "Fail_Vezax_Leech",
        "Fail_Vezax_ShadowCrash",
        "Fail_Vezax_Saronite",
        "Fail_Council_Overload",
        "Fail_Freya_NatureBomb",
        "Fail_Yogg_Sanity",
        "Fail_Yogg_DeathRay",
        "Fail_Razorscale_Flame",
        "Fail_Kologarn_Eyebeam",
        "Fail_Auriaya_Voidzone",
        "Fail_Mimiron_WaterSpray",
        "Fail_Mimiron_ProximityMine",
        "Fail_Mimiron_FrostBomb",
        "Fail_Yogg_LunaticGaze",
        "Fail_Algalon_BigBang",
        "Fail_Mimiron_Siren",
        "Fail_Auriaya_SonicScreech",
        "Fail_Algalon_CosmicSmash",
        "Fail_Mimiron_NapalmShell",
        "Fail_Freya_UnstableEnergy",
        "Fail_Council_RuneOfDeath",
        "Fail_Yogg_OminousCloud",
        "Fail_Algalon_Blackhole",
        "Fail_Yogg_Malady",
        "Fail_Freya_GroundTremor",
        "Fail_Ignis_FlameJets",
        "Fail_Freya_BindLife",
        "Fail_Deconstructor_Voidzone",
    },
    Naxxramas = {
        "Fail_Frogger",
        "Fail_Heigan_Dance",
        "Fail_KelThuzad_VoidZone",
        "Fail_Sapphiron_Breath",
        "Fail_Thaddius_Jump",
        "Fail_Thaddius_PolaritySwitch",
        "Fail_Horsemen_VoideZone",
        "Fail_Horsemen_Mark",
        "Fail_Grobbulus_MutatingInjection",
        "Fail_Grobbulus_PoisonCloud",
        "Fail_Sapphiron_TailSweep",
        "Fail_Sapphiron_Cleave",
    },
    ["The Obsidian Sanctum"] = {
        "Fail_Sartharion_LavaWaves",
        "Fail_Sartharion_VoidZone",
        "Fail_Sartharion_Breath",
        "Fail_Sartharion_TailLash",
    },
    ["Eye of Eternity"] = {
        "Fail_Malygos_Dot",
        "Fail_Malygos_ArcaneBreath",
    },
    ["Vault of Archavon"] = {
        "Fail_Koralon_MeteorFist",
        "Fail_Archavon_ChokingCloud",
        "Fail_Emalon_LightningNova",
        "Fail_Emalon_ChainLightning",
        "Fail_Koralon_FlameCinder",
    }
}

local fails_where_tanks_dont_fail = {
    "Fail_Onyxia_FlameBreath",
    "Fail_Onyxia_WarderNova",
    "Fail_Onyxia_WarderCleave",
    "Fail_Onyxia_Cleave",
    "Fail_Acidmaw_AcidicSpew",
    "Fail_Dreadscale_MoltenSpew",
    "Fail_Mimiron_BombBots",
    "Fail_Yogg_OminousCloud",
    "Fail_Razorscale_Flame",
    "Fail_Mimiron_ProximityMine",
    "Fail_Koralon_MeteorFist",
    "Fail_Emalon_LightningNova",
    "Fail_Malygos_ArcaneBreath",
    "Fail_Marrowgar_SaberLash",
    "Fail_Sartharion_Breath",
    "Fail_Sapphiron_Cleave",
    "Fail_Sindragosa_FrostBreath",
    "Fail_Sindragosa_BlisteringCold",
    "Fail_Sindragosa_Cleave",
    "Fail_Auriaya_SonicScreech",
    "Fail_LanaThel_DeliriousSlash",
    "Fail_Deathwhisper_Shade",
    "Fail_Rotface_SlimeSpray",
    "Fail_TheLichKing_NecroticPlague",
    "Fail_TheLichKing_Shockwave",
    "Fail_Deathwhisper_ShadeExplosion",
    "Fail_Marrowgar_Coldflame",
    "Fail_Festergut_MalleableGoo",
    "Fail_TheLichKing_SoulShriek",
    "Fail_BloodPrinces_KineticBomb",
}

-- Spell id's to use for default localizations
local event_spellids = {
    Fail_Acidmaw_AcidicSpew = 66819,
    Fail_Acidmaw_ParalyticToxin = 67618,
    Fail_Acidmaw_SlimePool = 66881,
    Fail_Algalon_BigBang = 64584,
    Fail_Algalon_CosmicSmash = 62311,
    Fail_Anubarak_Impale = 67860,
    Fail_Archavon_ChokingCloud = 58965,
    Fail_Auriaya_SonicScreech = 64688,
    Fail_Auriaya_Voidzone = 64459,
    Fail_Council_Overload = 61878,
    Fail_Council_RuneOfDeath = 63490,
    Fail_Deconstructor_Light = 65120,
    Fail_Deconstructor_Gravity = 64233,
    Fail_Dreadscale_MoltenSpew = 66820,
    Fail_Emalon_ChainLightning = 64213,
    Fail_Emalon_LightningNova = 65279,
    Fail_FactionChampions_Hellfire = 65817,
    Fail_Freya_NatureBomb = 64650,
    Fail_Freya_UnstableEnergy = 62865,
    Fail_Frogger = 28433,
    Fail_Gormok_FireBomb = 67472,
    Fail_Grobbulus_MutatingInjection = 28169,
    Fail_Grobbulus_PoisonCloud = 28158,
    Fail_Heigan_Dance = 29371,
    Fail_Hodir_BitingCold = 62038,
    Fail_Hodir_FlashFreeze = 61969,
    Fail_Hodir_Icicle = 62457,
    Fail_Horsemen_Mark = 28836,
    Fail_Horsemen_VoideZone = 28865,
    Fail_Icehowl_Trample = 66734,
    Fail_Jaraxxus_FelInferno = 68718,
    Fail_Jaraxxus_LegionFlame = 67072,
    Fail_KelThuzad_VoidZone = 27812,
    Fail_Kologarn_Eyebeam = 63976,
    Fail_Koralon_FlameCinder = 67332,
    Fail_Koralon_MeteorFist = 68161,
    Fail_Malygos_Dot = 56092,
    Fail_Mimiron_BombBots = 63811,
    Fail_Mimiron_Flames = 64566,
    Fail_Mimiron_FrostBomb = 65333,
    Fail_Mimiron_LaserBarrage = 63293,
    Fail_Mimiron_NapalmShell = 65026,
    Fail_Mimiron_ProximityMine = 63009,
    Fail_Mimiron_Rocket = 63041,
    Fail_Mimiron_Shock = 63631,
    Fail_Mimiron_Siren = 64616,
    Fail_Mimiron_WaterSpray = 64619,
    Fail_Onyxia_DeepBreath = 17086,
    Fail_Onyxia_FlameBreath = 68970,
    Fail_Onyxia_TailSweep = 69286,
    Fail_Onyxia_WarderCleave = 15284,
    Fail_Onyxia_WarderNova = 68958,
    Fail_Onyxia_Cleave = 68868,
    Fail_Razorscale_Flame = 64733,
    Fail_Rotface_OozeExplosion = 69839,
    Fail_Rotface_StickyOoze = 69778,
    Fail_Sapphiron_Breath = 28524,
    Fail_Sartharion_LavaWaves = 57491,
    Fail_Sartharion_VoidZone = 57581,
    Fail_Sartharion_Breath = 56908,
    Fail_Sartharion_TailLash = 56910,
    Fail_Thaddius_Jump = 28801,
    Fail_Thaddius_PolaritySwitch = 28089, -- 'polarity switch' spell id
    Fail_Thorim_Blizzard = 62602,
    Fail_Thorim_LightningChain = 64390,
    Fail_Thorim_LightningCharge = 62466,
    Fail_Thorim_Smash = 62465,
    Fail_Valkyr_Orb = 67174,
    Fail_Valkyr_Vortex = 67155,
    Fail_Vezax_Leech = 63278,
    Fail_Vezax_Saronite = 63338,
    Fail_Vezax_ShadowCrash = 62659,
    Fail_Yogg_DeathRay = 63884,
    Fail_Yogg_LunaticGaze = 64168,
    Fail_Yogg_OminousCloud = 60977,
    Fail_Yogg_Sanity = 63120,
    Fail_Malygos_ArcaneBreath = 56272,
    Fail_Algalon_Blackhole = 62169,
    Fail_Yogg_Malady = 63881,
    Fail_Freya_GroundTremor = 62859,
    Fail_Ignis_FlameJets = 62681,
    Fail_Freya_BindLife = 63559,
    Fail_Deconstructor_Voidzone = 64206,
    Fail_Marrowgar_Whirlwind = 69075,
    Fail_Marrowgar_Coldflame = 69138, -- the spellid of the summond "npc" that cralls, not the damage dealing spell
    Fail_Marrowgar_SaberLash = 69055,
    Fail_Festergut_VileGas = 71218,
    Fail_Festergut_PungentBlight = 71219,
    Fail_Deathwhisper_DeathNDecay = 71001,
    Fail_Sapphiron_TailSweep = 55696,
    Fail_Sapphiron_Cleave = 19983,
    Fail_Sindragosa_TailSmash = 71077,
    Fail_Sindragosa_FrostBreath = 69649,
    Fail_Sindragosa_BlisteringCold = 70123,
    Fail_Sindragosa_Cleave = 19983,
    Fail_Sindragosa_Instability = 69766,
    Fail_Sindragosa_FrostBomb = 69846,
    Fail_Sindragosa_IceTomb = 70157,
    Fail_Sindragosa_MysticBuffet = 70127,
    Fail_Professor_MutatedSlime = 72456,
    Fail_LanaThel_UncontrollableFrenzy = 70923,
    Fail_LanaThel_BloodboltSplash = 71481,
    Fail_BloodPrinces_SystemicShockVortex = 72815,
    Fail_LanaThel_DeliriousSlash = 71624,
    Fail_Gunship_Explosion = 69680,
    Fail_Gunship_Explosion_Knockback = 69689,
    Fail_FactionChampions_Bladestorm = 65946,
    Fail_Saurfang_Rune = 72410,
    Fail_Saurfang_Beasts = 72173, --the spellid of Call Blood Beast, not the actual fail.
    Fail_Deathwhisper_Shade = 71426, --the spellid of Summon Spirit, not the actual fail.
    Fail_Professor_MalleableGoo = 72458,
    Fail_Rotface_SlimeSpray = 73190,
    Fail_BloodPrinces_Flames = 72789,
    Fail_LanaThel_Pact = 71341,
    Fail_LanaThel_SwarmingShadows = 72635,
    Fail_ColdflameTrap = 70461,
    Fail_Professor_ChokingGas = 72620,
    Fail_Valithria_ColumnofFrost = 72020,
    Fail_Valithria_EmeraldVigor = 70873,
    Fail_TheLichKing_IceBurst = 73773,
    Fail_Sindragosa_ChilledtotheBone = 70106,
    Fail_TheLichKing_RemorselessWinter = 74270,
    Fail_TheLichKing_NecroticPlague = 73913,
    Fail_TheLichKing_ShadowTrap = 73529,
    Fail_Festergut_MalleableGoo = 72550,
    Fail_TheLichKing_Defile = 73708,
    Fail_TheLichKing_Shockwave = 73794,
    Fail_TheLichKing_SpiritBomb = 73572,
    Fail_Deathwhisper_ShadeExplosion = 71544,
    Fail_Halion_TwilightCutter = 77845,
    Fail_Halion_MeteorStrike = 75952,
    Fail_TheLichKing_SoulShriek = 73800,
    Fail_BloodPrinces_KineticBomb = 72802,
}

--[===[@debug@
--FAIL = lib
function lib:TestEventIds()
    for k,v in pairs(event_spellids) do
        local spell = GetSpellInfo(v) or ""
        print(k.." = "..spell)
    end
end
--@end-debug@]===]

--- Get a list of supported events.
-- @see fail_events
-- @return a table of event names which can be fired
function lib:GetSupportedEvents() return fail_events end

--- Get a list of supported events in the current zone
-- @see fail_events
-- @return a table of event names which can be fired
function lib:GetSupportedZoneEvents(name) return zones_with_fails[name] end

--- Get a spell id which can be used for a default event string by calling GetSpellInfo()
-- @see fail_events
-- @param event_name the event name
-- @return a spell id represting this failure
function lib:GetEventSpellId(event_name) return event_spellids[event_name] end

--- Get a list of events where tanks do not fail, it is the responsibility of the hosting addon to determine who constitutes as a tank and ignore the event fired
-- @see fail_events
-- @return a table of event names which can be fired
function lib:GetFailsWhereTanksDoNotFail() return fails_where_tanks_dont_fail end

-- mainly for the Faction Champions - Hellfire event but could be usefull
local snare_effects = {
    [1]  = GetSpellInfo(65857), -- Entangling Roots
    [2]  = GetSpellInfo(66071), -- Natures Grasp
    [3]  = GetSpellInfo(65545), -- Psychic Horror
    [4]  = GetSpellInfo(65543), -- Psychic Scream
    [5]  = GetSpellInfo(65792), -- Frost Nova
    [6]  = GetSpellInfo(65809), -- Fear
    [7]  = GetSpellInfo(66613), -- Hammer of Justice
    [8]  = GetSpellInfo(65930), -- Intimidating Shout
    [9]  = GetSpellInfo(65880), -- Frost Trap
    [10] = GetSpellInfo(66207), -- Wing Clip
    [11] = GetSpellInfo(66020), -- Chains of Ice
--- ICC
    [12] = GetSpellInfo(71615), -- Tear Gas -- Professor Putricide
    [13] = GetSpellInfo(70447), -- Volatile Ooze Adhesive -- Professor Putricide
}

function lib:IsSnared(target)
    for _, debuff in ipairs(snare_effects) do
        if debuff == UnitDebuff(target, debuff) then return true end
    end

    return false
end

function lib:SaurfangCheck()
    local bossId = lib:findTargetByGUID(37813)
    if not bossId then return end
    local target = UnitName(bossId .. "target")
    if target then
        if UnitIsUnit(target, lib.SaurfangTarget) then -- after 1 sec or many sec target is still same (2nd tank is failing)
            lib.SaurfangTimer = lib.SaurfangTimer + 1 -- increase the variable so we know how much he is failing
            lib:ScheduleTimer("SaurfangCheck", lib.SaurfangCheck, 1) -- check again in 1 sec if he is still failing
        else -- after 1 sec or many sec we got a new target someone either didnt fail at 1st check or this is not the 1st check so someone already failed time to report it
            if lib.SaurfangTimer > 1 then -- not the 1st check aka someone failed
                lib:FailEvent("Fail_Saurfang_Rune", lib.SaurfangTarget, lib.FAIL_TYPE_SWITCHING)
                lib.SaurfangTimer = 0 -- reset the timer after reporting
            end -- do nothing if we got a new target at the 1st check
        end
    end
end

function lib:GetMobId(GUID)
    if not GUID then return end

    return tonumber(GUID:sub(-12, -7), 16)
end

function lib:findTargetByGUID(id)
	local idType = type(id)
	for i, unit in next, lib.targetlist do
		if UnitExists(unit) and not UnitIsPlayer(unit) then
			local unitId = UnitGUID(unit)
			if idType == "number" then unitId = tonumber(unitId:sub(-12, -7), 16) end
			if unitId == id then return unit end
		end
	end
end

function lib:InitVariables()
    if not self.active then return end

    self.ChargeCounter = {}
    self.MalygosAlive = true
    self.BigbangCasting = false
    self.ThreePeopleHugging = false -- emalon chain lightning thing, needs a better name
    self.VezaxLeechTarget = nil
    self.DeathTime = 0
    self.RaidTable = {} -- Mostly for the Auriaya fail, but could be usefull
    self.SindragosaSingleBeacon = 0
    self.SindragosaBeaconTarget = nil
    self.TheLichKingNecroticPlagueTarget = {}
    self.TheLichKingNecroticPlagueDispelCounter = 0
    self.TheLichKingShadowTrapTarget = nil
    self.DefileCastStart = 0
    self.SaurfangTimer = 0
    self.SaurfangTarget = nil
    self.ValithriaEmeraldVigor = {}

    self.LastEvent = {}

    self.targetlist = {"target", "targettarget", "focus", "focustarget", "mouseover", "mouseovertarget"}
    for i = 1, 4 do self.targetlist[#self.targetlist+1] = string.format("boss%d", i) end
    for i = 1, 4 do self.targetlist[#self.targetlist+1] = string.format("party%dtarget", i) end
    for i = 1, 40 do self.targetlist[#self.targetlist+1] = string.format("raid%dtarget", i) end

    -- Last whatever
    for i=1, #fail_events do
        self.LastEvent[fail_events[i]] = {}
    end

end

function lib:InitRaidTable()
    if next(self.RaidTable) then return end
    local difficulty = GetRaidDifficulty()

    for raidindex = 1, GetNumRaidMembers() do
        local name, _, group, _, _, _, _, online = GetRaidRosterInfo(raidindex)

        if difficulty <= 2 and group <= 2 and online then -- 10 man
            self.RaidTable[name] = true
        elseif group <= 5 and online then -- 25 man
            self.RaidTable[name] = true
        end
    end
end

do
    frame:Hide()
    frame:SetScript("OnUpdate", function(self, elapsed)
        for name, timer in pairs(lib.timers) do
            timer.elapsed = timer.elapsed + elapsed
            if timer.elapsed > timer.delay then
                timer.func()
                lib:CancelTimer(name)
            end
        end
    end)
end

function lib:ScheduleTimer(name, func, delay)
    if not self.timers then self.timers = {} end
    self.timers[name] = {
        elapsed = 0,
        func = func,
        delay = delay,
    }

    if not frame:IsShown() then frame:Show() end
end

function lib:CancelTimer(name)
    if not name then
        self.timers = {}
        return frame:Hide()
    end

    self.timers[name] = nil
    if not next(self.timers) then self:CancelTimer() end
end

function lib:IsTimerRunning(name)
    return (self.timers and self.timers[name]) and true or false
end

lib.FAIL_TYPE_NOTMOVING     = "notmoving" -- fails at not moving with probably something on him that triggers on movement
lib.FAIL_TYPE_MOVING        = "moving" -- fails at moving out of shit
lib.FAIL_TYPE_NOTSPREADING  = "notspreading" -- fails at standing together (think auriaya)
lib.FAIL_TYPE_SPREADING     = "spreading" -- fails at not having enough distance between people
lib.FAIL_TYPE_DISPELLING    = "dispelling" -- fails at not dispelling something you should be dispelling (not very usable yes, but for completeness)
lib.FAIL_TYPE_NOTDISPELLING = "notdispelling" -- fails at dispelling something you should NOT be dispelling
lib.FAIL_TYPE_WRONGPLACE    = "wrongplace" -- being in the wrong place in the wrong time (cleave, etc)
lib.FAIL_TYPE_NOTCASTING    = "notcasting" -- casting spells when you shouldnt have
lib.FAIL_TYPE_NOTATTACKING  = "notattacking" -- attacking when you shouldnt have
lib.FAIL_TYPE_CASTING       = "casting" -- not casting spells when you should have (think malygos phase3)
lib.FAIL_TYPE_SWITCHING     = "switching" -- not taunting/switching tanks when you're supposed to

lib.BLOODPRINCES_FLAMES         = 25000 -- make 25k default for achievment
lib.THADDIUS_JUMP_WINDOW        = 120
lib.THADDIUS_JUMP_RETRY_WINDOW  = 5
lib.FROGGER_DEATH_WINDOW        = 4
lib.YOGGSARON_GAZE_THRESHOLD    = 15 -- after how many ticks do we fail?
lib.VEZAX_LEECH_THRESHOLD       = 400000 -- how much heal is "acceptable"
lib.EMALON_NOVA_THRESHOLD       = 15000 -- on being hit by lightning nova, above what dmg does it take for it to be a fail (think DK-s with AMS)
lib.ONYXIA_DEEPBREATH_THRESHOLD = 5000 -- same as above
lib.COUNCIL_OVERLOAD_THRESHOLD  = 4000 -- ^
lib.ALGALON_SMASH_THRESHOLD     = 7000
lib.COUNCIL_RUNE_THRESHOLD      = 3 -- the player got 3 seconds to move out of Rune of Death
lib.SINDRAGOSA_FROSTBOMB_THRESHOLD  = 5000
lib.SINDRAGOSA_BLISTERINGCOLD_THRESHOLD = 10000
lib.SINDRAGOSA_MYSTICBUFFET_THRESHOLD  = 14 -- how many stacks is still not a fail (set to 5 for "all you can eat" achievement)
lib.HODIR_COLD_THRESHOLD = 2 -- stacks needed for a fail

do
    local _, etype, f

    frame:SetScript("OnEvent", function (self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            _, etype = ...
            if etype == "SPELL_MISSED" then  -- lets hack the misses onto the damage event
                local timestamp, _, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, missType,  amountMissed = ...
                local damage, overkill = 0, 0

                lib.SPELL_DAMAGE(lib, timestamp, etype, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, damage, overkill, missType, amountMissed)

                return
            end

            f = lib[etype]

            if f then
                f(lib, ...)
            end

            return
        end

        f = lib[event]

        if f then
            f(lib, ...)
        end

    end)
end

function lib:FailEvent(failname, playername, failtype, ...)
    callbacks:Fire(failname, playername, failtype, ...)
    callbacks:Fire("AnyFail", failname, playername, failtype, ...)
end

function lib:GoActive()
    if self.active then return end

    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
    self:InitVariables()

    self.active = true

    callbacks:Fire("Fail_Active")
end

function lib:GoInactive()
    if not self.active then return end

    self:InitVariables()

    self.active = nil

    frame:RegisterEvent("RAID_ROSTER_UPDATE")
    frame:UnregisterEvent("CHAT_MSG_MONSTER_EMOTE")
    frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:UnregisterEvent("PLAYER_REGEN_ENABLED")

    callbacks:Fire("Fail_Inactive")
end

lib.active = true
lib:GoInactive()

function lib:PLAYER_ENTERING_WORLD(...)
    if GetNumRaidMembers() > 0 then
        self:GoActive()
    else
        self:GoInactive()
    end
end

function lib:RAID_ROSTER_UPDATE(...)
    if GetNumRaidMembers() > 0 then
        self:GoActive()
    else
        self:GoInactive()
    end
end

function lib:PLAYER_REGEN_ENABLED()
    self:InitVariables()
end

local ominous_cloud_name = GetSpellInfo(60977)
function lib:CHAT_MSG_MONSTER_EMOTE(message, sourceName, language, channelName, destName, ...)
    -- Yogg-Saron - Ominous Cloud (spawning new mobs in phase 1)
    if sourceName:find(ominous_cloud_name) then
        self:FailEvent("Fail_Yogg_OminousCloud", destName, self.FAIL_TYPE_NOTMOVING)
    end
end

local onyxia_breath_name = GetSpellInfo(18351)
function lib:SPELL_DAMAGE(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, damage, overkill)
    -- Guardian activities ignored after this point
    --5/7 21:13:33.865  SPELL_DAMAGE,0xF1300079F0003A98,"Mirror Image",0x2114,0xF130008092003842,"Elder Stonebark",0xa48,59637,"Fire Blast",0x4,139,0,4,0,0,0,nil,nil,nil
    --5/7 21:13:36.092  SPELL_HEAL,0x01800000007C56B2,"Blackknite",0x512,0xF1300079F0003A97,"Mirror Image",0x2114,54968,"Glyph of Holy Light",0x2,1240,1240,nil
    if bit.band(sourceFlags or 0, COMBATLOG_OBJECT_TYPE_GUARDIAN) > 0 or bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_GUARDIAN) > 0 or not spellId then return end
    local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
    damage = damage ~= "ABSORB" and damage or 0
    overkill = overkill or 0

    -- Malygos - Arcane Breath(the cone attack, credits to mysticalos and Aviana)
    if (spellId == 56272 or spellId == 60072) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Malygos_ArcaneBreath", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Halion - Twilight Cutter
    if (spellId == 74769 or spellId == 77844 or spellId == 77845 or spellId == 77846) and is_playerevent then
        self:FailEvent("Fail_Halion_TwilightCutter", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

	-- Halion - Meteor Strike (first 4 are impact, you died cause you let meteor land on you, rest are from standing in fire after impact. Seems to have various spellids for range from center)
	if (spellId == 74648 or spellId == 75877 or spellId == 75878 or spellId == 75879
     or spellId == 75952 or spellId == 75951 or spellId == 75950 or spellId == 75949 or spellId == 75948 or spellId == 75947) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Halion_MeteorStrike", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Icecrown Citadel

    -- The Lich King - Shockwave
    if (spellId == 73794 or spellId == 73795 or spellId == 72149 or spellId == 73796) and is_playerevent then
        self:FailEvent("Fail_TheLichKing_Shockwave", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- The Lich King - Defile

    if (spellId == 73708 or spellId == 73709 or spellId == 72754 or spellId == 73710) and is_playerevent then
        if (((timestamp - self.DefileCastStart) > 3.3) and ((timestamp - self.DefileCastStart) < 5)) then -- cast time is 2 sec, and we are only interested in fails at the first 3 sec, after that its just all spam, but lets give you 1.3 sec to move out
            self:FailEvent("Fail_TheLichKing_Defile", destName, self.FAIL_TYPE_NOTMOVING)
        end

        return
    end

    -- The Lich King - Spirit Bomb
    if (spellId == 73804 or spellId == 73805) and is_playerevent then
        self:FailEvent("Fail_TheLichKing_SpiritBomb", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- The Lich King - Soul Shriek
    if (spellId == 69242 or spellId == 73800 or spellId == 73801 or spellId == 73802) and is_playerevent then
        self:FailEvent("Fail_TheLichKing_SoulShriek", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end


    -- The Lich King - Shadow Trap
    if spellId == 73529 and is_playerevent then
        if self.LastEvent.Fail_TheLichKing_ShadowTrap[destName] == nil then
            self:FailEvent("Fail_TheLichKing_ShadowTrap", destName, self.FAIL_TYPE_NOTMOVING)
            self.LastEvent.Fail_TheLichKing_ShadowTrap[destName] = timestamp
        else
            if (timestamp - self.LastEvent.Fail_TheLichKing_ShadowTrap[destName]) > 5 then
                self:FailEvent("Fail_TheLichKing_ShadowTrap", destName, self.FAIL_TYPE_NOTMOVING)
            end
        end

        self.LastEvent.Fail_TheLichKing_ShadowTrap[destName] = timestamp

        return
    end

    -- Frogger like fail for the Coldflame Trap after Deathbringers Rise
    if spellId == 70461 and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_ColdflameTrap", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Gunship -- Explosion Knockback (heroic only)
    if (spellId == 69688 or spellId == 69689) and is_playerevent then
        self:FailEvent("Fail_Gunship_Explosion_Knockback", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

   -- Gunship -- Explosion (it's still avoidable so optional fail for normal mode)
    if (spellId == 69680 or spellId == 69687) and is_playerevent then
        self:FailEvent("Fail_Gunship_Explosion", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    --11/13 19:42:32.500  SPELL_DAMAGE,0x0100000000004105,"Fenitalol",0x514,0x010000000004AB38,"Belth",0x514,72815,"Systemic Shock Vortex",0x1,4477,227,1,0,0,0,nil,nil,nil
    -- Blood Princes -- Systemic Shock Vortex
    if (spellId == 72815 or spellId == 72816 or spellId == 72817 or spellId == 72038) and is_playerevent and overkill > 0 then
        if bit.band(sourceFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then
            self:FailEvent("Fail_BloodPrinces_SystemicShockVortex", destName, self.FAIL_TYPE_NOTSPREADING)
        end

        return
    end

    -- Blood Princes -- Kinetic Bomb Explosion
    if (spellId == 72052 or spellId == 72800 or spellId == 72801 or spellId == 72802) and is_playerevent then
        self:FailEvent("Fail_BloodPrinces_KineticBomb", destName, self.FAIL_TYPE_CASTING)

        return
    end

    -- Blood Princes -- Flames
    if spellId == 72789 and is_playerevent and damage > self.BLOODPRINCES_FLAMES then
        self:FailEvent("Fail_BloodPrinces_Flames", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Blood Queen Lana'thel -- Swarming Shadows
    if (spellId == 71268 or spellId == 72635 or spellId == 72636 or spellId == 72637) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_LanaThel_SwarmingShadows", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Blood Queen Lana'thel - Pact of the Darkfallen
    if spellId == 71341 and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_LanaThel_Pact", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Blood Queen Lana'thel - Bloodbolt Splash
    if (spellId == 71447 or spellId == 71481 or spellId == 71482 or spellId == 71483) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_LanaThel_BloodboltSplash", destName, self.FAIL_TYPE_NOTSPREADING)

        return
    end

    -- Valithria Dreamwalker - Column of Frost
    if (spellId == 70702 or spellId == 71746 or spellId == 72019 or spellId == 72020) and is_playerevent then
        self:FailEvent("Fail_Valithria_ColumnofFrost", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Festergut - Pungent Blight
    if (spellId == 71219 or spellId == 69195) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Festergut_PungentBlight", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Lady Deathwhisper Vengeful Shades Explosion(Melee are responsible for not standing in this if they target a tank.)
    -- Tanks exempt though because a tank isn't going to kite the boss or adds around room just to dodge these
    if (spellId == 71544 or spellId == 72010 or spellId == 72011 or spellId == 72012) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Deathwhisper_ShadeExplosion", destName, self.FAIL_TYPE_MOVING)

        self.LastEvent.Fail_Deathwhisper_ShadeExplosion[destName] = timestamp

        return
    end


    -- Lord Marrowgar - Whirlwind
    if (spellId == 69075 or (spellId >= 70834 and spellId <= 70836)) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Marrowgar_Whirlwind", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Lord Marrowgar - Saber Lash (69055 trash mobs leading to marrowgar, other 2 marrowgar. Leaving all 3 since announcing fails on the trash still amusing)
    if (spellId == 69055 or spellId == 70814 or spellId == 71021) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Marrowgar_SaberLash", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Rotface - Sticky Ooze (the slime pools)
    if (spellId == 69778 or spellId == 71208 or spellId == 69776 or spellId == 69774) and is_playerevent then
        if self.LastEvent.Fail_Rotface_StickyOoze[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Rotface_StickyOoze[destName]) > 3 then
                self:FailEvent("Fail_Rotface_StickyOoze", destName, self.FAIL_TYPE_NOTMOVING)
            end
        end

        self.LastEvent.Fail_Rotface_StickyOoze[destName] = timestamp

        return
    end

    -- Rotface - Slime Spray
    if (spellId == 69507 or spellId == 71213 or spellId == 73189 or spellId == 73190) and is_playerevent then
        if self.LastEvent.Fail_Rotface_SlimeSpray[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Rotface_SlimeSpray[destName]) > 3 then
                self:FailEvent("Fail_Rotface_SlimeSpray", destName, self.FAIL_TYPE_NOTMOVING)
            end
        end

        self.LastEvent.Fail_Rotface_SlimeSpray[destName] = timestamp

        return
    end

    -- Rotface - Unstable Ooze Explosion
    if (spellId == 69839 or spellId == 71209 or spellId == 69833 or spellId == 69832) and is_playerevent then
        self:FailEvent("Fail_Rotface_OozeExplosion", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Sindragosa - Tail Smash
    if (spellId == 71077) and is_playerevent then
        self:FailEvent("Fail_Sindragosa_TailSmash", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Sindragosa - Frost Breath
    if (spellId == 69649 or spellId == 71056 or spellId == 71057 or spellId == 71058
     or spellId == 73061 or spellId == 73062 or spellId == 73063 or spellId == 73064) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Sindragosa_FrostBreath", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Sindragosa - Blistering Cold
    if (spellId == 70123 or spellId == 71047 or spellId == 71048 or spellId == 71049) and is_playerevent and damage > self.SINDRAGOSA_BLISTERINGCOLD_THRESHOLD then
        self:FailEvent("Fail_Sindragosa_BlisteringCold", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Sindragosa - Cleave
    if spellId == 19983 and is_playerevent and overkill > 0 then
        if self:GetMobId(sourceGUID) ~= 36853 then return end

        self:FailEvent("Fail_Sindragosa_Cleave", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Sindragosa - Frost Bomb
    if (spellId == 69845 or spellId == 71053 or spellId == 71054 or spellId == 71055) and is_playerevent and damage > self.SINDRAGOSA_FROSTBOMB_THRESHOLD then
        self:FailEvent("Fail_Sindragosa_FrostBomb", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Sindragosa - Backlash (the damage part of Unchained Magic/Instability stacks)
    if (spellId == 69770 or spellId == 71044) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Sindragosa_Instability", destName, self.FAIL_TYPE_NOTCASTING)

        return
    end

    -- Sindragosa - Backlash-Heroic (This damages you AND anyone near you. this fail means you killed everyone near you) UNTESTED
    if (spellId == 71045 or spellId == 71046) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Sindragosa_Instability", sourceName, self.FAIL_TYPE_NOTCASTING)

        return
    end

    -- Saurfang Rune of Blood (More than 1 heal per taunt, 1 is super hard to avoid no matter how fast you taunt)
    if (spellId == 72409 or spellId == 72447 or spellId == 72448 or spellId == 72449) and is_playerevent then

        self.SaurfangTarget = destName
        lib:ScheduleTimer("SaurfangCheck", lib.SaurfangCheck, 1) -- start the check in 1 sec

        return

    end

    -- The Lich King - Ice Burst
    if spellId == 73773 and is_playerevent then
        self:FailEvent("Fail_TheLichKing_IceBurst", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- The Lich King - Remorseless Winter
    if (spellId == 68981 or spellId == 68983 or spellId == 73791 or spellId == 73792 or spellId == 73793) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_TheLichKing_RemorselessWinter", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Professor - Mutated Slime
    if spellId == 72456 and is_playerevent and damage > 0 then--Only one spellid seems needed, it seems the other IDs are server side and only thing sent to combat log is a dummyID for any difficulty
        if self:IsSnared(destName) then return end
        if self.LastEvent.Fail_Professor_MutatedSlime[destName] ~= nil then
 	    local deltaT = (timestamp - self.LastEvent.Fail_Professor_MutatedSlime[destName])
            if (((deltaT) > 3) and ((deltaT) < 9)) then--If >3 times threshold reset timestamp since it's probably from earlier fight and not genuine fail.
                self:FailEvent("Fail_Professor_MutatedSlime", destName, self.FAIL_TYPE_NOTMOVING)
    	    else
                self.LastEvent.Fail_Professor_MutatedSlime[destName] = timestamp
            end
        end

        self.LastEvent.Fail_Professor_MutatedSlime[destName] = timestamp

        return
    end

    -- Festergut Heroic -- Malleable goo (Debuff)
    if (spellId == 72549 or spellId == 72550) and is_playerevent and (damage > 10000 or overkill > 0) then
        if self.LastEvent.Fail_Festergut_MalleableGoo[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Festergut_MalleableGoo[destName]) > 3 then
                self:FailEvent("Fail_Festergut_MalleableGoo", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
            self:FailEvent("Fail_Festergut_MalleableGoo", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Festergut_MalleableGoo[destName] = timestamp

        return
    end

    -- Professor - Malleable Goo (Debuff)
    if (spellId == 70853 or spellId == 72458 or spellId == 72873 or spellId == 72874) and is_playerevent and (damage > 10000 or overkill > 0) then
    	if self:IsSnared(destName) then return end
        if self.LastEvent.Fail_Professor_MalleableGoo[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Professor_MalleableGoo[destName]) > 3 then
                self:FailEvent("Fail_Professor_MalleableGoo", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
            self:FailEvent("Fail_Professor_MalleableGoo", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Professor_MalleableGoo[destName] = timestamp

        return
    end

    -- Professor - Choking Gas (Damage)
    if (spellId == 72460 or spellId == 72619 or spellId == 72620 or spellId == 71278
     or spellId == 71279 or spellId == 72459 or spellId == 72621 or spellId == 72622) and is_playerevent and overkill > 0 then
     	if self:IsSnared(destName) then return end
        self:FailEvent("Fail_Professor_ChokingGas", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- VAULT OF ARCHAVON

    -- Emalon - Lightning Nova
    if (spellId == 65279 or spellId == 64216) and is_playerevent and damage >= self.EMALON_NOVA_THRESHOLD then
        self:FailEvent("Fail_Emalon_LightningNova", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Emalon - Chain Lightning
    if (spellId == 64213 or spellId == 64215) and is_playerevent then
        if damage >= 10000 then -- at least 3 ppl hugging, and I think highest damage appears in combat log first always (Maat @Ensidiafails)
            self.ThreePeopleHugging = true
            self:ScheduleTimer("EmalonChainLightning", function() lib.ThreePeopleHugging = false end, 3)
        end
        if self.ThreePeopleHugging then
            if self.LastEvent.Fail_Emalon_ChainLightning.time ~= nil then
                if (timestamp - self.LastEvent.Fail_Emalon_ChainLightning.time) < 1 then
                    self:FailEvent("Fail_Emalon_ChainLightning", destName, self.FAIL_TYPE_NOTSPREADING)
                end
            end

            self.LastEvent.Fail_Emalon_ChainLightning.time = timestamp

        end

        return
    end

    -- Koralon - Flame Cinder
    if (spellId == 67332 or spellId == 66684) and is_playerevent then
        if self.LastEvent.Fail_Koralon_FlameCinder[destName] ~= nil then
 	    local deltaT = (timestamp - self.LastEvent.Fail_Koralon_FlameCinder[destName])
            if (((deltaT) > 2) and ((deltaT) < 6)) then--If >3 times threshold reset timestamp since it's probably from earlier fight and not genuine fail.
                self:FailEvent("Fail_Koralon_FlameCinder", destName, self.FAIL_TYPE_NOTMOVING)
    	    else
                self.LastEvent.Fail_Koralon_FlameCinder[destName] = timestamp
            end
        end

        self.LastEvent.Fail_Koralon_FlameCinder[destName] = timestamp

        return
    end

    -- ONYXIA'S LAIR

    -- Onyxian Lair Guard - Blast Nova
    if spellId == 68958 and overkill > 0 and is_playerevent then
        self:FailEvent("Fail_Onyxia_WarderNova", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Onyxian Warder - Cleave
    --10/21 21:44:57.024  SPELL_DAMAGE,0xF130002F610053DF,"Onyxian Warder",0xa48,0x05000000025092DE,"Nopher",0x514,15284,"Cleave",0x1,8816,0,1,0,0,2120,nil,nil,nil
    if spellId == 15284 and overkill > 0 and is_playerevent then
        if self:GetMobId(sourceGUID) ~= 12129 then return end

        self:FailEvent("Fail_Onyxia_WarderCleave", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Onyxia - Cleave
    if spellId == 68868 and overkill > 0 and is_playerevent then
        if UnitDebuff(destName, GetSpellInfo(18431)) then return end -- target afflicted by fear, dont fail it
        self:FailEvent("Fail_Onyxia_Cleave", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Onyxia - Deep Breath (when flying)
    -- The deal with the spellIds is that it depends on WHERE onyxia is, from that point
    -- every breath has 8 corresponding spellIds (the farther you are the less dmg, well
    -- those are seperate spells, there are ~90 spellids, so we check for the name instead (idea by mysticalos))
    if spellName == onyxia_breath_name and is_playerevent then
        if overkill > 0 or damage >= self.ONYXIA_DEEPBREATH_THRESHOLD then
            if self.LastEvent.Fail_Onyxia_DeepBreath[destName] ~= nil then
                if (timestamp - self.LastEvent.Fail_Onyxia_DeepBreath[destName]) > 5 then
                    self:FailEvent("Fail_Onyxia_DeepBreath", destName, self.FAIL_TYPE_NOTMOVING)
                end
            else
                self:FailEvent("Fail_Onyxia_DeepBreath", destName, self.FAIL_TYPE_NOTMOVING)
            end

            self.LastEvent.Fail_Onyxia_DeepBreath[destName] = timestamp
        end

        return
    end

    -- Onyxia - Flame Breath (the cone attack)
    if (spellId == 68970 or spellId == 18435) and is_playerevent then -- not a fail for tanks, but we dont care about that here
        if UnitDebuff(destName, GetSpellInfo(18431)) then return end -- target afflicted by fear, dont fail it
        self:FailEvent("Fail_Onyxia_FlameBreath", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Onyxia - Tail Sweep
    if (spellId == 69286 or spellId == 68867) and is_playerevent then
        if UnitDebuff(destName, GetSpellInfo(18431)) then return end -- target afflicted by fear, dont fail it
        self:FailEvent("Fail_Onyxia_TailSweep", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- TRIAL OF THE CRUSADER

    -- Northrend Beasts - Gormok - Fire Bomb
    if spellId == 66317 and is_playerevent then -- the initial damage from whence you have 2 seconds to move
        self.LastEvent.Fail_Gormok_FireBomb[destName] = timestamp

        return
    elseif (spellId == 67472 or spellId == 66320 or spellId == 67475 or spellId == 67473) and is_playerevent then
        if not self.LastEvent.Fail_Gormok_FireBomb[destName] then
            -- no initial damage, so the failer managed to go into the flame on the ground, good job
            self.LastEvent.Fail_Gormok_FireBomb[destName] = timestamp
        end
        if (timestamp - self.LastEvent.Fail_Gormok_FireBomb[destName]) > 2 then
            self:FailEvent("Fail_Gormok_FireBomb", destName, self.FAIL_TYPE_NOTMOVING)
            self.LastEvent.Fail_Gormok_FireBomb[destName] = timestamp -- so as not to spam
        end

        return
    end

    -- Northrend Beasts - Acidmaw - Slime Pool (only trigger on damage, touching the slime pool should'nt be a fail)
    if (spellId == 66881 or spellId == 67638 or spellId == 67639 or spellId == 67640) and is_playerevent then
        if UnitDebuff(destName, GetSpellInfo(67618)) then return end -- Paralytic Toxin (if the dude can't move, let's not fail him/her)

        if self.LastEvent.Fail_Acidmaw_SlimePool[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Acidmaw_SlimePool[destName]) > 3 then
                self:FailEvent("Fail_Acidmaw_SlimePool", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
            self:FailEvent("Fail_Acidmaw_SlimePool", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Acidmaw_SlimePool[destName] = timestamp

        return
    end

    -- Northrend Beasts - Dreadscale - Molten Spew (the cone attack (breath))
    if (spellId == 66820 or spellId == 67635 or spellId == 67636 or spellId == 67637) and overkill > 0 and is_playerevent then
        self:FailEvent("Fail_Dreadscale_MoltenSpew", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Northrend Beasts - Acidmaw - Acidic Spew (the cone attack (breath))
    if (spellId == 66819 or spellId == 67609 or spellId == 67610 or spellId == 67611) and overkill > 0 and is_playerevent then
        self:FailEvent("Fail_Acidmaw_AcidicSpew", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Northrend Beasts - Icehowl - Trample
    if spellId == 66734 and is_playerevent then
        self:FailEvent("Fail_Icehowl_Trample", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Lord Jaraxxus - Legion Flame
    if (spellId == 67072 or spellId == 67070 or spellId == 66877 or spellId == 67071) and overkill > 0 and is_playerevent then
        self:FailEvent("Fail_Jaraxxus_LegionFlame", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Lord Jaraxxus - Fel Inferno
    if (spellId == 68718 or spellId == 66496 or spellId == 68716 or spellId == 68717) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Jaraxxus_FelInferno", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Faction Champions - Hellfire
    if (spellId == 65817 or spellId == 68142 or spellId == 68143 or spellId == 68144) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_FactionChampions_Hellfire", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Faction Champions - Bladestorm
    if spellId == 65946 and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_FactionChampions_Bladestorm", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Twin Val'kyr - Unleashed Light / Dark (the orbs, only from heroic)
    if (spellId == 67174 or spellId == 67240 or spellId == 67173 or spellId == 67239) and is_playerevent and damage > 0 and overkill > 0 then
        self:FailEvent("Fail_Valkyr_Orb", destName, self.FAIL_TYPE_NOTMOVING)

        return
    -- Twin Val'kyr - Unleashed Light / Dark (the rest of the orbs)
    elseif (spellId == 65808 or spellId == 67172 or spellId == 65795 or spellId == 67238) and is_playerevent and damage > 0 and overkill > 0 then
        self:FailEvent("Fail_Valkyr_Orb", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Twin Val'kyr - Light / Dark Vortex - Non-Heroic (it's a fail only on death)
    -- When you have the correct color you resist the vortex with 100% chance
    -- but because we hax the SPELL_MISS event onto the SPELL_DAMAGE event, we must
    -- check for the damage done
    if (spellId == 67155 or spellId == 67203 or spellId == 66048 or spellId == 66059) and damage > 0 and overkill > 0 and is_playerevent then
        self:FailEvent("Fail_Valkyr_Vortex", destName, self.FAIL_TYPE_NOTMOVING)

        return
    -- Twin Val'kyr - Light / Dark Vortex - Heroic
    elseif (spellId == 67205 or spellId == 67157 or spellId == 67156 or spellId == 67204) and damage > 0 and overkill > 0 and is_playerevent then
        self:FailEvent("Fail_Valkyr_Vortex", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Anub'arak - Impale
    if (spellId == 65919 or spellId == 67860 or spellId == 67858 or spellId == 67859) and overkill > 0 and is_playerevent then
        self:FailEvent("Fail_Anubarak_Impale", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- ULDUAR

    -- Kologarn Eyebeam
    if (spellId == 63976 or spellId == 63346) and is_playerevent then
        if self.LastEvent.Fail_Kologarn_Eyebeam[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Kologarn_Eyebeam[destName]) > 5 then
                self:FailEvent("Fail_Kologarn_Eyebeam", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
           self:FailEvent("Fail_Kologarn_Eyebeam", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Kologarn_Eyebeam[destName] = timestamp

        return
    end

    -- Auriaya - Sonic Screech (not standing in it is a fail)
    -- Look in CAST_START for the details
    if (spellId == 64688 or spellId == 64422) and is_playerevent then
        self.RaidTable[destName] = false

        return
    end

    -- Auriaya Void Zone (not a fail if stunned by the kitty)
    if (spellId == 64459 or spellId == 64675) and is_playerevent then
        if UnitDebuff(destName, GetSpellInfo(64386)) then return end
        if self.LastEvent.Fail_Auriaya_Voidzone[destName] ~= nil then
 	    local deltaT = (timestamp - self.LastEvent.Fail_Auriaya_Voidzone[destName])
            if (((deltaT) > 3) and ((deltaT) < 9)) then--If >3 times threshold reset timestamp since it's probably from earlier fight and not genuine fail.
                self:FailEvent("Fail_Auriaya_Voidzone", destName, self.FAIL_TYPE_NOTMOVING)
    	    else
                self.LastEvent.Fail_Auriaya_Voidzone[destName] = timestamp
            end
        end

        self.LastEvent.Fail_Auriaya_Voidzone[destName] = timestamp

        return
    end

    -- Razorscale Flame
    if (spellId == 64733 or spellId == 64704) and is_playerevent then
        if self.LastEvent.Fail_Razorscale_Flame[destName] ~= nil then
 	    local deltaT = (timestamp - self.LastEvent.Fail_Razorscale_Flame[destName])
            if (((deltaT) > 2) and ((deltaT) < 6)) then--If >3 times threshold reset timestamp since it's probably from earlier fight and not genuine fail.
                self:FailEvent("Fail_Razorscale_Flame", destName, self.FAIL_TYPE_NOTMOVING)
    	    else
                self.LastEvent.Fail_Razorscale_Flame[destName] = timestamp
            end
        end

        self.LastEvent.Fail_Razorscale_Flame[destName] = timestamp

        return
    end

    -- Yogg Saron Death Ray
    if (spellId == 63884 or spellId == 63891) and is_playerevent then
        if self.LastEvent.Fail_Yogg_DeathRay[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Yogg_DeathRay[destName]) > 5 then
                self:FailEvent("Fail_Yogg_DeathRay", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
           self:FailEvent("Fail_Yogg_DeathRay", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Yogg_DeathRay[destName] = timestamp

        return
    end

    -- Yogg-Saron - Lunatic Gaze
    if (spellId == 64168 or spellId == 64164) and is_playerevent then
        if not self.LastEvent.Fail_Yogg_LunaticGaze[destName] then self.LastEvent.Fail_Yogg_LunaticGaze[destName] = 1 end

        if spellId == 64168 then -- Yogg-Saron's lunatic gaze, not so serious
            self.LastEvent.Fail_Yogg_LunaticGaze[destName] = self.LastEvent.Fail_Yogg_LunaticGaze[destName] + 1
        else -- Laughing Skull's lunatic gaze, more serious
            self.LastEvent.Fail_Yogg_LunaticGaze[destName] = self.LastEvent.Fail_Yogg_LunaticGaze[destName] + 2
        end

        if self.LastEvent.Fail_Yogg_LunaticGaze[destName] >= self.YOGGSARON_GAZE_THRESHOLD then
            self.LastEvent.Fail_Yogg_LunaticGaze[destName] = 0
            self:FailEvent("Fail_Yogg_LunaticGaze", destName, self.FAIL_TYPE_NOTMOVING)
        end

        return
    end

    -- Algalon - Cosmic Smash
    if (spellId == 62311 or spellId == 64596) and is_playerevent and damage >= self.ALGALON_SMASH_THRESHOLD then
        if self.LastEvent.Fail_Algalon_CosmicSmash[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Algalon_CosmicSmash[destName]) > 2 then
                self:FailEvent("Fail_Algalon_CosmicSmash", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
            self:FailEvent("Fail_Algalon_CosmicSmash", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Algalon_CosmicSmash[destName] = timestamp

        return
    end

    -- Algalon - Big Bang
    if (spellId == 64584 or spellId == 64443) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Algalon_BigBang", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Freya Nature Bomb
    if (spellId == 64650 or spellId == 64587) and is_playerevent then
        if UnitDebuff(destName, GetSpellInfo(62861)) then return end

        self:FailEvent("Fail_Freya_NatureBomb", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Hodir Icicle (aka Ice Shards)
    if (spellId == 62457 or spellId == 65370) and is_playerevent then
        self:FailEvent("Fail_Hodir_Icicle", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- EnsidiaFails - Maat
    -- Hodir Biting Cold
    if (spellId == 62038 or spellId == 62188) and is_playerevent then
        local stack = select(4, UnitDebuff(destName, GetSpellInfo(62039)))

        if stack ~= nil and stack > self.HODIR_COLD_THRESHOLD then
            if self.LastEvent.Fail_Hodir_BitingCold[destName] == nil or (timestamp - self.LastEvent.Fail_Hodir_BitingCold[destName]) > 5 then
                self:FailEvent("Fail_Hodir_BitingCold", destName, self.FAIL_TYPE_NOTMOVING)
                self.LastEvent.Fail_Hodir_BitingCold[destName] = timestamp
            end
        end

        return
    end

    -- Council Overload
    if (spellId == 61878 or spellId == 63480) and is_playerevent and damage >= self.COUNCIL_OVERLOAD_THRESHOLD then -- DKs with AMS shouln't fail
        if self:GetMobId(sourceGUID) ~= 32857 then return end

        self:FailEvent("Fail_Council_Overload", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- XT-002 Deconstructor: Light Bomb
    if (spellId == 65120 or spellId == 63023) and sourceGUID ~= destGUID and is_playerevent then
        if self.LastEvent.Fail_Deconstructor_Light[sourceName] ~= nil then
        	if (timestamp - self.LastEvent.Fail_Deconstructor_Light[sourceName]) > 9 then--Reset timestamp if you were out of it for a while to prevent instant fails from outdated timestamps from earlier fight.
    			self.LastEvent.Fail_Deconstructor_Light[sourceName] = timestamp
    		elseif (timestamp - self.LastEvent.Fail_Deconstructor_Light[sourceName]) > 3 then
                self:FailEvent("Fail_Deconstructor_Light", sourceName, self.FAIL_TYPE_NOTMOVING)
            end
        end

        self.LastEvent.Fail_Deconstructor_Light[sourceName] = timestamp

        return
    end

    -- XT-002 Deconstructor: Gravity Bomb (bomb part)
    if (spellId == 64233 or spellId == 63025) and sourceGUID ~= destGUID and is_playerevent then
        if self.LastEvent.Fail_Deconstructor_Gravity[sourceName] ~= nil then
            self:FailEvent("Fail_Deconstructor_Gravity", sourceName, self.FAIL_TYPE_NOTMOVING)
            self.LastEvent.Fail_Deconstructor_Gravity[sourceName] = nil
        end

        return
    end

    -- XT-002 Deconstructor - Void Zone (on heroic, what the gravity bomb leaves behind)
    --5/7 18:19:04.078  SPELL_DAMAGE,0xF1300084D1002E23,"Void Zone",0xa48,0x0300000001D3239F,"Diomache",0x514,64208,"Consumption",0x20,6258,0,32,0,0,0,nil,nil,nil
    if (spellId == 64208 or spellId == 64206) and is_playerevent then
        self:FailEvent("Fail_Deconstructor_Voidzone", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

   -- Failbot - Viiv
   -- 4/16 22:06:17.885  SPELL_DAMAGE,0xF1300081F702D928,"General Vezax",0x10a48,0x05000000027FCDFE,"Kosie",0x514,62659,"Shadow Crash",0x20,9413,0,32,2285,0,0,nil,nil,nil
   -- Vezax Shadow Crash
    if (spellId == 62659 or spellId == 63277) and is_playerevent and damage > 0 then
        self:FailEvent("Fail_Vezax_ShadowCrash", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Vezax Saronite Vapor Suicide
    if spellId == 63338 and is_playerevent then
         self.LastEvent.Fail_Vezax_Saronite[destName] = timestamp

         return
    end

   -- Failbot - Viiv
   -- 4/16 18:20:24.295  SPELL_DAMAGE,0xF130008061018374,"Thorim",0x8010a48,0x0500000001E8AF39,"Thefeint",0x514,62466,"Lightning Charge",0x8,8977,0,8,3966,0,0,nil,nil,nil
   -- Thorim Lightning Charge
    if spellId == 62466 and is_playerevent then
        if self:GetMobId(sourceGUID) ~= 32865 then return end -- it's not from Thorim
        self:FailEvent("Fail_Thorim_LightningCharge", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Thorim Chain Lightning
    if (spellId == 64390 or spellId == 62131) and is_playerevent then
        if damage > 10000 then
            self.ThreePeopleHugging = true
            self:ScheduleTimer("ThorimChainLightning", function() lib.ThreePeopleHugging = false end, 3)
        end

        if self.ThreePeopleHugging then
            if self.LastEvent.Fail_Thorim_LightningChain[destName] ~= nil then
                if (timestamp - self.LastEvent.Fail_Thorim_LightningChain[destName]) < 1 then
                    self:FailEvent("Fail_Thorim_LightningChain", destName, self.FAIL_TYPE_NOTSPREADING)
                end
            end

            self.LastEvent.Fail_Thorim_LightningChain[destName] = timestamp

        end

        return
    end

    -- 4/16 01:06:26.414  SPELL_DAMAGE,0x0000000000000000,nil,0x80000000,0x05000000027ECA9C,"Cn",0x514,62465,"Runic Smash",0x4,6544,0,4,3116,0,0,nil,nil,nil
    -- Thorim Hallway Smash
    if spellId == 62465 and is_playerevent then
        self:FailEvent("Fail_Thorim_Smash", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Failbot - Viiv
    -- 4/16 18:50:56.578  SPELL_DAMAGE,0x0000000000000000,nil,0x80000000,0x05000000027ECB89,"Logicalness",0x514,64875,"Sapper Explosion",0x40,67542,45099,64,28421,0,0,nil,nil,nil
    -- Mimiron Trash - Sapper Explosion
    if spellId == 64875 and is_playerevent then
        self:FailEvent("Fail_Boss_Sapper", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Mimiron - Flames
    if spellId == 64566 and is_playerevent and damage > 0 then
        if self.LastEvent.Fail_Mimiron_Flames[destName] ~= nil then
 	    local deltaT = (timestamp - self.LastEvent.Fail_Mimiron_Flames[destName])
            if (((deltaT) > 3) and ((deltaT) < 9)) then--If >3 times threshold reset timestamp since it's probably from earlier fight and not genuine fail.
                self:FailEvent("Fail_Mimiron_Flames", destName, self.FAIL_TYPE_NOTMOVING)
    	    else
                self.LastEvent.Fail_Mimiron_Flames[destName] = timestamp
            end
        end

        self.LastEvent.Fail_Mimiron_Flames[destName] = timestamp

        return
    end

    -- Mimiron - Napalm Shell
    -- Two or more people getting damage usually triggers this
    if (spellId == 65026 or spellId == 63666) and is_playerevent then
        if self.LastEvent.Fail_Mimiron_NapalmShell[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Mimiron_NapalmShell[destName]) < 1 then
                self:FailEvent("Fail_Mimiron_NapalmShell", destName, self.FAIL_TYPE_MOVING)
            end
        end

        self.LastEvent.Fail_Mimiron_NapalmShell[destName] = timestamp

        return
    end


    -- Mimiron - Water Spray
    if spellId == 64619 and is_playerevent then
        self:FailEvent("Fail_Mimiron_WaterSpray", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Mimiron - Proximity Mine (should check for sourcename == proximity mine?)
    if (spellId == 63009 or spellId == 66351) and is_playerevent then
        if self:GetMobId(sourceGUID) ~= 34362 then return end -- Explosion not from mines

        if self.LastEvent.Fail_Mimiron_ProximityMine[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Mimiron_ProximityMine[destName]) > 3 then
                self:FailEvent("Fail_Mimiron_ProximityMine", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
            self:FailEvent("Fail_Mimiron_ProximityMine", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Mimiron_ProximityMine[destName] = timestamp

        return
    end

    -- Mimiron - Frost Bomb
    if (spellId == 65333 or spellId == 64626) and is_playerevent then
        if self:GetMobId(sourceGUID) ~= 34149 then return end --Explosion not from Frost Bomb

        self:FailEvent("Fail_Mimiron_FrostBomb", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Mimiron Laser Barrage
    if spellId == 63293 and is_playerevent then
        if self.LastEvent.Fail_Mimiron_LaserBarrage[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Mimiron_LaserBarrage[destName]) > 10 then
                self:FailEvent("Fail_Mimiron_LaserBarrage", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
           self:FailEvent("Fail_Mimiron_LaserBarrage", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Mimiron_LaserBarrage[destName] = timestamp

        return
    end

    -- Mimiron Rocket Strike
    if spellId == 63041 and is_playerevent then
        self:FailEvent("Fail_Mimiron_Rocket", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

   -- Failbot - Viiv
   -- 4/16 13:35:12.750  SPELL_DAMAGE,0xF13000842C0094E3,"Bomb Bot",0xa48,0x05000000027ECCA5,"Naddia",0x512,63801,"Bomb Bot",0x4,20216,4025,4,5054,0,0,nil,nil,nil
   -- Mimiron Bomb Bots
   if spellId == 63801 and is_playerevent and damage > 0 then
       self:FailEvent("Fail_Mimiron_BombBots", destName, self.FAIL_TYPE_NOTMOVING)

       return
   end

    -- 3/13 21:17:23.756  SPELL_DAMAGE,0xF150008298002210,"Leviathan Mk II",0x10a48,0xF1300007AC0025A9,"Treant",0x1114,63631,"Shock Blast",0x8,97000,92908,8,0,0,0,nil,nil,nil
    -- Mimiron Shock Blast
    if spellId == 63631 and is_playerevent and damage > 0 then
        self:FailEvent("Fail_Mimiron_Shock", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- OBSIDIAN SANCTUM

    -- Sartharion Lava Waves: Flame Tsunami
    if spellId == 57491 and is_playerevent and damage > 0 then
        if self.LastEvent.Fail_Sartharion_LavaWaves[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Sartharion_LavaWaves[destName]) > 10 then
                self:FailEvent("Fail_Sartharion_LavaWaves", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
            self:FailEvent("Fail_Sartharion_LavaWaves", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Sartharion_LavaWaves[destName] = timestamp

        return
    end

    -- Sartharion - Void Zone
    if (spellId == 57581 or spellId == 59128) and damage > 0 and is_playerevent then
        self:FailEvent("Fail_Sartharion_VoidZone", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Sartharion - Flame Breath
    if (spellId == 56908 or spellId == 58956) and is_playerevent then
        self:FailEvent("Fail_Sartharion_Breath", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Sartharion - Tail Lash
    if (spellId == 56910 or spellId == 58957) and is_playerevent then
        self:FailEvent("Fail_Sartharion_TailLash", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- NAXXRAMAS

    -- Grobbulus - Poison (the cloud that the injection leaves behind)
    -- When the Mutating Injection ends or Grobbulus thinks its time to take a shit under itself,
    -- it SPELL_SUMMON's a Grobbulus Cloud (which is the cloud and it grows) and applies a buff to itself called Posion
    -- Poison is what damages people, and that is why you don't get out of combat until all the clouds disappear
    if (spellId == 28158 or spellId == 54362) and is_playerevent then
        if self.LastEvent.Fail_Grobbulus_PoisonCloud[destName] ~= nil then
 	    local deltaT = (timestamp - self.LastEvent.Fail_Grobbulus_PoisonCloud[destName])
            if (((deltaT) > 3) and ((deltaT) < 9)) then--If >3 times threshold reset timestamp since it's probably from earlier fight and not genuine fail.
                self:FailEvent("Fail_Grobbulus_PoisonCloud", destName, self.FAIL_TYPE_NOTMOVING)
    	    else
                self.LastEvent.Fail_Grobbulus_PoisonCloud[destName] = timestamp
            end
        end

        self.LastEvent.Fail_Grobbulus_PoisonCloud[destName] = timestamp

        return
    end

    -- The Four Horsemen - Void Zone
    if spellId == 28865 and damage > 0 and is_playerevent then
        if self.LastEvent.Fail_Horsemen_VoideZone[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Horsemen_VoideZone[destName]) > 3 then
                self:FailEvent("Fail_Horsemen_VoideZone", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
            self:FailEvent("Fail_Horsemen_VoideZone", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Horsemen_VoideZone[destName] = timestamp

        return
    end

    -- The Four Horsemen - Mark death
    if spellId == 28836 and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Horsemen_Mark", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Heigan - Eruption (aka dance fail)
    if spellId == 29371 and is_playerevent then
        self:FailEvent("Fail_Heigan_Dance", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Kel'Thuzad - Void Blast (aka Void Zone)
    if spellId == 27812 and is_playerevent then
        self:FailEvent("Fail_KelThuzad_VoidZone", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Sapphiron - Frost Breath
    if (spellId == 28524 or spellId == 29318) and is_playerevent then
        self:FailEvent("Fail_Sapphiron_Breath", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Sartharion - Tail Sweep
    if (spellId == 55696 or spellId == 55697) and is_playerevent then
        self:FailEvent("Fail_Sapphiron_TailSweep", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Sartharion - Cleave
    if spellId == 19983 and overkill > 0 and is_playerevent then
        if self:GetMobId(sourceGUID) ~= 15989 then return end

        self:FailEvent("Fail_Sapphiron_Cleave", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    if spellId == 28433 and is_playerevent then
        if overkill > 0 then
            self:FailEvent("Fail_Frogger", destName, self.FAIL_TYPE_WRONGPLACE)
        else
            self.LastEvent.Fail_Frogger[destName] = timestamp
        end

        return
    end

    -- Thaddius Polarity Switch
    -- 28062 Positive Charge
    -- 28085 Negative Charge
    if spellId == 28062 or spellId == 28085 then
        if self.ChargeCounter[sourceName] == nil then
            self.ChargeCounter[sourceName] = 1
            self.LastEvent.Fail_Thaddius_PolaritySwitch[sourceName] = timestamp
        elseif (timestamp - self.LastEvent.Fail_Thaddius_PolaritySwitch[sourceName]) < 2 then
            self.ChargeCounter[sourceName] = self.ChargeCounter[sourceName] + 1
            self.LastEvent.Fail_Thaddius_PolaritySwitch[sourceName] = timestamp
        else
            self.ChargeCounter[sourceName] = 1
            self.LastEvent.Fail_Thaddius_PolaritySwitch[sourceName] = timestamp
        end

        if self.ChargeCounter[sourceName] == 3 then
            self:FailEvent("Fail_Thaddius_PolaritySwitch", sourceName, self.FAIL_TYPE_NOTMOVING)
        end

        return
    end
end

function lib:SWING_DAMAGE(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, damage, overkill)
    local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
    damage = damage ~= "ABSORB" and damage or 0
    overkill = overkill or 0

--12/26 20:27:36.560  SWING_DAMAGE,0xF13000966C005B92,"Blood Beast",0x10a48,0x040000000396C708,"Outofcontrol",0x2000514,5033,0,1,0,0,1258,nil,nil,nil
    -- Saurfang Blood Beasts
    if self:GetMobId(sourceGUID) == 38508 and is_playerevent and damage > 0 then
        self:FailEvent("Fail_Saurfang_Beasts", destName, self.FAIL_TYPE_MOVING)

        self.LastEvent.Fail_Saurfang_Beasts[destName] = timestamp

        return
    end

    -- Lady Deathwhisper Vengeful Shades
    -- The shade will swing (and hit or miss) its target after it catches up with it, then explode.  Fail should be given to the player that failed to avoid the shade, not necessarily others within the explosion range (which is 20 yards in 25 heroic)
    if self:GetMobId(sourceGUID) == 38222 and is_playerevent then
        self:FailEvent("Fail_Deathwhisper_Shade", destName, self.FAIL_TYPE_MOVING)

        self.LastEvent.Fail_Deathwhisper_Shade[destName] = timestamp

        return
    end
end

function lib:SWING_MISSED(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0

    -- Lady Deathwhisper Vengeful Shades
    -- The shade will swing (and hit or miss) its target after it catches up with it, then explode.  Fail should be given to the player that failed to avoid the shade, not necessarily others within the explosion range (which is 20 yards in 25 heroic)
    if self:GetMobId(sourceGUID) == 38222 and is_playerevent then
        self:FailEvent("Fail_Deathwhisper_Shade", destName, self.FAIL_TYPE_MOVING)

        self.LastEvent.Fail_Deathwhisper_Shade[destName] = timestamp

        return
    end
end

function lib:ENVIRONMENTAL_DAMAGE(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, dmgType)
    local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0

    -- Thaddius Falling
    if (timestamp - self.DeathTime) < self.THADDIUS_JUMP_WINDOW and dmgType == "FALLING" and is_playerevent then
        self:FailEvent("Fail_Thaddius_Jump", destName, self.FAIL_TYPE_MOVING)

        self.LastEvent.Fail_Thaddius_Jump[destName] = timestamp

        return
    end
end

-- Thaddius Polarity Shift
function lib:SPELL_CAST_START(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool)
    -- local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0

    -- Auriaya - Sonic Screech
    -- The raid table is initialized in this form: "playername" => true
    -- in SPELL_DAMAGE above, we set those to false who get the damage
    -- and check here for who is still true, we also reset the whole thing
    -- so it can be reused in in the fight (InitRaidtable will return
    -- if the table is already filled)
    if spellId == 64688 or spellId == 64422 then
        self:InitRaidTable()
        self:ScheduleTimer("AuriayaScreech", function()
            for name, failed in pairs(lib.RaidTable) do
                if failed then
                    lib:FailEvent("Fail_Auriaya_SonicScreech", name, self.FAIL_TYPE_MOVING)
                else
                    lib.RaidTable[name] = true
                end
            end
        end, 4)
        return
    end

    -- Algalon - Big Bang timer
    if spellId == 64584 or spellId == 64443 then
        self.BigbangCasting = true
        self:ScheduleTimer("Algalon_BigBang", function() lib.BigbangCasting = false end, 8)

        return
    end

    -- The Lich King - Defile timer
    if spellId == 72762 then
        self.DefileCastStart = timestamp

        return
    end
end

function lib:UNIT_DIED(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
    local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
    local mobid = self:GetMobId(destGUID)

    -- 15929 stalagg 15930 feugen for thaddius fails
    if mobid == 15929 or mobid == 15930 then
        self.DeathTime = timestamp

        return
    end

    if self.LastEvent.Fail_Frogger[destName] then
        if (timestamp - self.LastEvent.Fail_Frogger[destName]) < self.FROGGER_DEATH_WINDOW and is_playerevent then
           self:FailEvent("Fail_Frogger", destName, self.FAIL_TYPE_WRONGPLACE)
        end

        self.LastEvent.Fail_Frogger[destName] = nil

        return
    end

    -- Saronite Vapor Suicide (Fail_Vezax_Saronite) death within 2sec of saronite damage
    if self.LastEvent.Fail_Vezax_Saronite[destName] then
        if (timestamp - self.LastEvent.Fail_Vezax_Saronite[destName]) < 2 then
            self:FailEvent("Fail_Vezax_Saronite", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Vezax_Saronite[destName] = nil

        return
    end


end

function lib:SPELL_PERIODIC_DAMAGE(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, damage, overkill)
    local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
    damage = damage ~= "ABSORB" and damage or 0
    overkill = overkill or 0

    -- Sindragosa - Chilled to the Bone (Melee debuff from attacking too much without clearing it)
    if spellId == 70106 and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Sindragosa_ChilledtotheBone", destName, self.FAIL_TYPE_NOTATTACKING)

        return
    end

    -- Lady Deathwhisper - Death and Decay
    if (spellId == 71001 or spellId == 72108 or spellId == 72109 or spellId == 72110) and is_playerevent then
        if self.LastEvent.Fail_Deathwhisper_DeathNDecay[destName] ~= nil then
 	    local deltaT = (timestamp - self.LastEvent.Fail_Deathwhisper_DeathNDecay[destName])
            if (((deltaT) > 3) and ((deltaT) < 9)) then--If >3 times threshold reset timestamp since it's probably from earlier fight and not genuine fail.
                self:FailEvent("Fail_Deathwhisper_DeathNDecay", destName, self.FAIL_TYPE_NOTMOVING)
    	    else
                self.LastEvent.Fail_Deathwhisper_DeathNDecay[destName] = timestamp
            end
        end

        self.LastEvent.Fail_Deathwhisper_DeathNDecay[destName] = timestamp

        return
    end

 --[==[    -- Festergut - Vile Gas (disabled until a more reliable method is found)
    if (spellId == 71218 or spellId == 69240 or spellId == 69244 or spellId == 69248) and is_playerevent then
        if self.LastEvent.Fail_Festergut_VileGas[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Festergut_VileGas[destName]) > 3 then
                self:FailEvent("Fail_Festergut_VileGas", destName, self.FAIL_TYPE_NOTMOVING)
            end
        end

        self.LastEvent.Fail_Festergut_VileGas[destName] = timestamp

        return
    end]==]

    -- Archavon - Choking Cloud
    if (spellId == 58965 or spellId == 61672) and overkill > 0 and is_playerevent then
         self:FailEvent("Fail_Archavon_ChokingCloud", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Northrend Beasts - Acidmaw - Paralytic Toxin
    if (spellId == 67618 or spellId == 67619 or spellId == 67620 or spellId == 66823) and overkill > 0 and is_playerevent then
        self:FailEvent("Fail_Acidmaw_ParalyticToxin", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Freya - Unstable Energy
    if (spellId == 62865 or spellId == 62451) and is_playerevent then
        local hasroots = UnitDebuff(destName, GetSpellInfo(62861))

        if self.LastEvent.Fail_Freya_UnstableEnergy[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Freya_UnstableEnergy[destName]) > 4  and not hasroots then
                self:FailEvent("Fail_Freya_UnstableEnergy", destName, self.FAIL_TYPE_NOTMOVING)
            end
        elseif not hasroots then
            self:FailEvent("Fail_Freya_UnstableEnergy", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Freya_UnstableEnergy[destName] = timestamp

        return
    end

    -- Thorim Blizzard
    if (spellId == 62602 or spellId == 62576) and is_playerevent then
        if self.LastEvent.Fail_Thorim_Blizzard[destName] == nil then
           self.LastEvent.Fail_Thorim_Blizzard[destName] = 0
        end

        self.LastEvent.Fail_Thorim_Blizzard[destName] = self.LastEvent.Fail_Thorim_Blizzard[destName] + 1

        if self.LastEvent.Fail_Thorim_Blizzard[destName] == 2 then
           self:FailEvent("Fail_Thorim_Blizzard", destName, self.FAIL_TYPE_NOTMOVING)
           self.LastEvent.Fail_Thorim_Blizzard[destName] = 0
        end

        return
    end

    -- The Iron Council - Rune of Death
    if (spellId == 63490 or spellId == 62269) and is_playerevent then
        if self.LastEvent.Fail_Council_RuneOfDeath[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Council_RuneOfDeath[destName]) > self.COUNCIL_RUNE_THRESHOLD then
                self:FailEvent("Fail_Council_RuneOfDeath", destName, self.FAIL_TYPE_NOTMOVING)
            end
        end

        self.LastEvent.Fail_Council_RuneOfDeath[destName] = timestamp

        return
    end

    -- Lord Marrowgar - Coldflame
    if (spellId == 69146 or (spellId >= 70823 and spellId <= 70825)) and is_playerevent then
        if self.LastEvent.Fail_Marrowgar_Coldflame[destName] ~= nil then
    		if (timestamp - self.LastEvent.Fail_Marrowgar_Coldflame[destName]) > 4 then--Reset timestamp if you were out of it for 2 times fail threshold to prevent instant fails from out of date timestamps.
    			self.LastEvent.Fail_Marrowgar_Coldflame[destName] = timestamp
    		elseif (timestamp - self.LastEvent.Fail_Marrowgar_Coldflame[destName]) > 2 then
                self:FailEvent("Fail_Marrowgar_Coldflame", destName, self.FAIL_TYPE_NOTMOVING)
            end
        end

        self.LastEvent.Fail_Marrowgar_Coldflame[destName] = timestamp

        return
    end
end

function lib:SPELL_HEAL(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, damage)
    -- local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0

    -- Vezax Mark of the Faceless
    if spellId == 63278 then
        if self.LastEvent.Fail_Vezax_Leech > self.VEZAX_LEECH_THRESHOLD then
            self:FailEvent("Fail_Vezax_Leech", self.VezaxLeechTarget, self.FAIL_TYPE_NOTMOVING)
            self.LastEvent.Fail_Vezax_Leech = 0
        end

        self.LastEvent.Fail_Vezax_Leech = self.LastEvent.Fail_Vezax_Leech + damage

        return
    end
end

function lib:SPELL_AURA_APPLIED(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, auraType)
    local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0

    -- Festergut Heroic -- Malleable goo (Debuff)
    if (spellId == 72549 or spellId == 72550) and is_playerevent then
        if self.LastEvent.Fail_Festergut_MalleableGoo[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Festergut_MalleableGoo[destName]) > 3 then
                self:FailEvent("Fail_Festergut_MalleableGoo", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
            self:FailEvent("Fail_Festergut_MalleableGoo", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Festergut_MalleableGoo[destName] = timestamp

        return
    end

    -- Professor - Malleable Goo (Debuff)
    if (spellId == 70853 or spellId == 72458 or spellId == 72873 or spellId == 72874) and is_playerevent then
    	if self:IsSnared(destName) then return end
        if self.LastEvent.Fail_Professor_MalleableGoo[destName] ~= nil then
            if (timestamp - self.LastEvent.Fail_Professor_MalleableGoo[destName]) > 3 then
                self:FailEvent("Fail_Professor_MalleableGoo", destName, self.FAIL_TYPE_NOTMOVING)
            end
        else
            self:FailEvent("Fail_Professor_MalleableGoo", destName, self.FAIL_TYPE_NOTMOVING)
        end

        self.LastEvent.Fail_Professor_MalleableGoo[destName] = timestamp

        return
    end

    -- Professor - Choking Gas (Debuff)
    if (spellId == 72460 or spellId == 72619 or spellId == 72620 or spellId == 71278) and is_playerevent then
    	if self:IsSnared(destName) then return end
        self:FailEvent("Fail_Professor_ChokingGas", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Blood Queen Lana'thel - Delirious Slash
    if spellId == 71624 and is_playerevent then
        self:FailEvent("Fail_LanaThel_DeliriousSlash", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end

    -- Blood Queen Lana'thel - Uncontrollable Frenzy
    if (spellId == 70923 or spellId == 70924) then
        self:FailEvent("Fail_LanaThel_UncontrollableFrenzy", destName, self.FAIL_TYPE_CASTING)

        return
    end

    -- Sindragosa - Frost Beacon (detecting if only one people got it)
    if spellId == 70126 and is_playerevent then
        if self.SindragosaSingleBeacon ~= 0 then
            self.SindragosaSingleBeacon = false

            return
        end

        if self.SindragosaSingleBeacon == 0 then
            self.SindragosaSingleBeacon = true
            self.SindragosaBeaconTarget = destName

            self:ScheduleTimer("Sindragosa_SingleBeacon", function() lib.SindragosaSingleBeacon = 0 end, 10)
        end

    -- Sindragosa - Ice Tomb (print the message only once)
    elseif spellId == 70157 and is_playerevent then
        if not self.SindragosaSingleBeacon or self:IsTimerRunning("Sindragosa_TombFail") or lib.SindragosaBeaconTarget == destName then return end

        self:ScheduleTimer("Sindragosa_TombFail", function()
            lib:FailEvent("Fail_Sindragosa_IceTomb", lib.SindragosaBeaconTarget, lib.FAIL_TYPE_NOTMOVING)
        end, 0.2)

    end

    -- Vezax Mark of the Faceless
    if spellId == 63276 and is_playerevent then
        -- save the name of the player who gains mark of the faceless
        self.VezaxLeechTarget = destName
        self.LastEvent.Fail_Vezax_Leech = 0

        return
   end

   -- Hodir Flash Freeze
    if (spellId == 61969 or spellId == 61990) and is_playerevent and auraType ~= "BUFF" then
        self:FailEvent("Fail_Hodir_FlashFreeze", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Yogg Saron Sanity Lost
    if spellId == 63120 and is_playerevent then
        self:FailEvent("Fail_Yogg_Sanity", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Yogg Saron Malady aka Death Coil
    if spellId == 63881 and is_playerevent then
        self:FailEvent("Fail_Yogg_Malady", destName, self.FAIL_TYPE_MOVING)

        return
    end

    -- Thaddius Jump
    if spellId == 28801 and (timestamp - self.DeathTime) < self.THADDIUS_JUMP_WINDOW and is_playerevent then
        if self.LastEvent.Fail_Thaddius_Jump[destName] == nil then
            self:FailEvent("Fail_Thaddius_Jump", destName, self.FAIL_TYPE_NOTMOVING)
        elseif (timestamp - self.LastEvent.Fail_Thaddius_Jump[destName]) > self.THADDIUS_JUMP_RETRY_WINDOW then
            self:FailEvent("Fail_Thaddius_Jump", destName, self.FAIL_TYPE_NOTMOVING)
        end

        return
    end

    -- Algalon - Black Hole (if big bang is not casting, it's a fail)
    if spellId == 62169 and is_playerevent and not self.BigbangCasting then
        self:FailEvent("Fail_Algalon_Blackhole", destName, self.FAIL_TYPE_MOVING)

        return
    end

    -- Light Bomb
    if (spellId == 65120 or spellId == 63023) and is_playerevent then
        self.LastLight[destName] = timestamp

        return
    end

    -- Mimiron - Deafening Siren
    if spellId == 64616 and is_playerevent then
        self:FailEvent("Fail_Mimiron_Siren", destName, self.FAIL_TYPE_NOTMOVING)

        return
    end

    -- Koralon the Flame Watcher - Meteor Fist (a fail if a non-tank gets it, let "userspace" handle it)
    if (spellId == 67333 or spellId == 66765) and is_playerevent and overkill > 0 then
        self:FailEvent("Fail_Koralon_MeteorFist", destName, self.FAIL_TYPE_WRONGPLACE)

        return
    end
end

function lib:SPELL_AURA_APPLIED_DOSE(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, auraType, amount)
    local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0

    -- Sindragosa - Mystic Buffet (Debuff)
    if (spellId == 70127 or spellId == 70128 or spellId == 72528 or spellId == 72529 or spellId == 72530) and is_playerevent then
        if (amount > self.SINDRAGOSA_MYSTICBUFFET_THRESHOLD) then
          self:FailEvent("Fail_Sindragosa_MysticBuffet", destName, self.FAIL_TYPE_NOTMOVING)
        end

        return
    end

end

function lib:SPELL_INTERRUPT(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, extraSpellId)
    local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0

    -- Flame Jets -- Ignis
    if spellId == 62681 and is_playerevent then
        self:FailEvent("Fail_Ignis_FlameJets", destName, self.FAIL_TYPE_NOTCASTING)

        return
    end

    -- Ground Tremor -- Freya and Elder
    if (spellId == 62859 or spellId == 62437 or spellId == 62325 or spellId == 62932) and is_playerevent then
        self:FailEvent("Fail_Freya_GroundTremor", destName, self.FAIL_TYPE_NOTCASTING)

        return
    end
end

function lib:SPELL_SUMMON(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName)
    -- local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0

    --SPELL_SUMMON,0xF15000838601084D,"Aerial Command Unit",0xa48,0xF13000842C010A24,"Bomb Bot",0xa28,63811,"Bomb Bot",0x1
    if spellId == 63811 then
        -- could add the GUID for each bot if this doesnt work.
        self.LastEvent.Fail_Mimiron_BombBots = timestamp + 30

        return
    end
end

--70337, 73912, 73913, 73914 are cast success IDs (from lich king)
--70338, 73785, 73786, 73787 are jump spellids (from another player, these don't show in combat log when they jump, only do damage)
function lib:SPELL_CAST_SUCCESS(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool)
    -- The Lich King - Necrotic Plague
    if spellId == 70337 or spellId == 73912 or spellId == 73913 or spellId == 73914 then
        if self.LastEvent.TheLichKing_NecroticPlague and timestamp - self.LastEvent.TheLichKing_NecroticPlague > 35 then
            self.TheLichKingNecroticPlagueDispelCounter = 0
            self.TheLichKingNecroticPlagueTarget = {}
        else
            if self.TheLichKingNecroticPlagueDispelCounter > 1 then
                for i=0, self.TheLichKingNecroticPlagueDispelCounter do
                    self:FailEvent("Fail_TheLichKing_NecroticPlague", self.TheLichKingNecroticPlagueTarget[i], self.FAIL_TYPE_NOTMOVING)
                end
            end
            self.TheLichKingNecroticPlagueDispelCounter = 0
            self.TheLichKingNecroticPlagueTarget = {}
        end
        self.LastEvent.TheLichKing_NecroticPlague = timestamp
    end
end

local necrotic_plague = GetSpellInfo(73912)
function lib:SPELL_DISPEL(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, extraSpellId, extraSpellName)
    -- Grobbulus - Mutating Injection
    if extraSpellId == 28169 then
        self:FailEvent("Fail_Grobbulus_MutatingInjection", sourceName, self.FAIL_TYPE_NOTDISPELLING)

        return
    end

    -- Bind Life - Freya Trash
    if extraSpellId == 63559 then
        self:FailEvent("Fail_Freya_BindLife", sourceName, self.FAIL_TYPE_NOTDISPELLING)

        return
    end

    -- The Lich King - Necrotic Plague
    if extraSpellName == necrotic_plague and is_playerevent then
        if UnitHealthMax(destName) < 50000 then -- poor mans tank check (you really should't do LK Heroic if your tank has less than 50k HP)
            self.TheLichKingNecroticPlagueTarget[self.TheLichKingNecroticPlagueDispelCounter] = destName
            self.TheLichKingNecroticPlagueDispelCounter = self.TheLichKingNecroticPlagueDispelCounter + 1
        end
    end
end

function lib:SPELL_AURA_REMOVED(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool)
    local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0

    -- Malygos Phase3 Dot
    -- fail when you let the dot expire
    if (spellId == 56092 or spellId == 61621) and self.MalygosAlive then
        local failer = nil

        for raidid = 1, GetNumRaidMembers() do
            local pet = format("%s%d", "raidpet", raidid);

            if (UnitGUID(pet) == sourceGUID) then
                if UnitHealth(pet) > 0 then
                    local member = format("%s%d", "raid", raidid);
                    failer = UnitName(member);
                else
                    failer = nil;
                end
            end
        end

        if failer ~= nil then
            self:FailEvent("Fail_Malygos_Dot", failer, self.FAIL_TYPE_CASTING)
        end

        return
    end

    -- Thaddius Jump
    if spellId == 28801 and (timestamp - self.DeathTime) < self.THADDIUS_JUMP_WINDOW and is_playerevent then
        self.LastEvent.Fail_Thaddius_Jump[destName] = timestamp

        return
    end

    -- Light Bomb
    if spellId == 65120 or spellId == 63026 then
        self.LastEvent.Fail_Deconstructor_Light[destName] = nil

        return
    end

    -- Gravity Bomb
    if spellId == 64233 or spellId == 63025 then
        self.LastEvent.Fail_Deconstructor_Gravity[destName] = timestamp

        return
    end

    -- Valithria Dreamwalker - Emerald Vigor stacks fell off, and we saw it happen
    if (spellId == 70873 or spellId == 71941) and is_playerevent then
        if UnitAffectingCombat(destName) then  -- dont report when unit is dead or fight is over
          self:FailEvent("Fail_Valithria_EmeraldVigor", destName, self.FAIL_TYPE_NOTMOVING)
        end
        self.ValithriaEmeraldVigor[destName] = nil;
        return
    end
end

function lib:SPELL_PERIODIC_ENERGIZE(timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, amount, powerType)
    local is_playerevent = bit.band(destFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0

    -- Valithria Dreamwalker - Emerald Vigor (Debuff)
    -- detect cases where Emerald Vigor stacks fell off on a toon in the opposite phase, where SPELL_AURA_REMOVED wont reach us
    if (spellId == 70873 or spellId == 71941) and is_playerevent then
        local stack
        for k,v in pairs(self.ValithriaEmeraldVigor) do
          stack = select(4, UnitDebuff(k, GetSpellInfo(70873))) or select(4, UnitDebuff(k, GetSpellInfo(71941)))

          if v and (stack == nil or (stack < v)) then
            if UnitAffectingCombat(k) then  -- dont report when unit is dead or fight is over
               self:FailEvent("Fail_Valithria_EmeraldVigor", k, self.FAIL_TYPE_NOTMOVING)
            end
            self.ValithriaEmeraldVigor[k] = stack;
          end
        end
        stack = select(4, UnitDebuff(destName, GetSpellInfo(70873))) or select(4, UnitDebuff(destName, GetSpellInfo(71941)))
        self.ValithriaEmeraldVigor[destName] = stack;
        return
    end

end
