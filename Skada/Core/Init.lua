local folder, ns = ...

local GetAddOnMetadata = GetAddOnMetadata
ns.author = GetAddOnMetadata(folder, "Author")
ns.version = GetAddOnMetadata(folder, "Version")
ns.date = GetAddOnMetadata(folder, "X-Date")
ns.website = "https://github.com/bkader/Skada-WoTLK"
ns.logo = [[Interface\ICONS\spell_lightning_lightningbolt01]]
ns.revisited = true -- Skada-Revisited flag
ns.Private = {} -- holds private stuff
ns.Locale = LibStub("AceLocale-3.0"):GetLocale(folder)
ns.callbacks = LibStub("CallbackHandler-1.0"):New(ns)

-- cache frequently used globals
local pairs, ipairs = pairs, ipairs
local select, next, max = select, next, math.max
local band, tonumber, type = bit.band, tonumber, type
local strsplit, format, strmatch, gsub = strsplit, string.format, string.match, string.gsub
local setmetatable, rawset, wipe = setmetatable, rawset, wipe
local EmptyFunc = Multibar_EmptyFunc
local Private, L = ns.Private, ns.Locale
local _

-- location of media files (textures, fonts...)
ns.mediapath = format([[Interface\AddOns\%s\Media]], folder)

-- options table
ns.options = {
	type = "group",
	name = format("%s \124cffffffff%s\124r", folder, ns.version),
	get = true,
	set = true,
	args = {}
}

-- common weak table
do
	local weaktable = {__mode = "kv"}
	function Private.WeakTable(t)
		return setmetatable(t or {}, weaktable)
	end
end

-- some tables we need
ns.dummyTable = {} -- a dummy table used as fallback
ns.cacheTable = {} -- primary cache table
ns.cacheTable2 = {} -- secondary cache table

-- table used to crop mode options images.
ns.cropTable = {0.06, 0.94, 0.06, 0.94}

-------------------------------------------------------------------------------
-- flags/bitmasks

do
	local bit_bor = bit.bor

	------------------------------------------------------
	-- generic flag check function
	------------------------------------------------------
	local function HasFlag(flags, flag)
		return (band(flags or 0, flag) ~= 0)
	end
	Private.HasFlag = HasFlag

	------------------------------------------------------
	-- self-affilation
	------------------------------------------------------
	local BITMASK_MINE = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
	Private.BITMASK_MINE = BITMASK_MINE

	function ns:IsMine(flags)
		return (band(flags or 0, BITMASK_MINE) ~= 0)
	end

	------------------------------------------------------
	-- group affilation
	------------------------------------------------------
	local BITMASK_PARTY = COMBATLOG_OBJECT_AFFILIATION_PARTY or 0x00000002
	local BITMASK_RAID = COMBATLOG_OBJECT_AFFILIATION_RAID or 0x00000004
	local BITMASK_GROUP = bit_bor(BITMASK_MINE, BITMASK_PARTY, BITMASK_RAID)
	Private.BITMASK_GROUP = BITMASK_GROUP

	function ns:InGroup(flags)
		return (band(flags or 0, BITMASK_GROUP) ~= 0)
	end

	------------------------------------------------------
	-- pets and guardiands
	------------------------------------------------------
	local BITMASK_TYPE_PET = COMBATLOG_OBJECT_TYPE_PET or 0x00001000
	local BITMASK_TYPE_GUARDIAN = COMBATLOG_OBJECT_TYPE_GUARDIAN or 0x00002000
	local BITMASK_PETS = bit_bor(BITMASK_TYPE_PET, BITMASK_TYPE_GUARDIAN)
	Private.BITMASK_PETS = BITMASK_PETS

	function ns:IsPet(flags)
		return (band(flags or 0, BITMASK_PETS) ~= 0)
	end

	------------------------------------------------------
	-- reactions: friendly, neutral and hostile
	------------------------------------------------------
	local BITMASK_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x00000010
	local BITMASK_NEUTRAL = COMBATLOG_OBJECT_REACTION_NEUTRAL or 0x00000020
	local BITMASK_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x00000040
	Private.BITMASK_FRIENDLY = BITMASK_FRIENDLY
	Private.BITMASK_NEUTRAL = BITMASK_NEUTRAL
	Private.BITMASK_HOSTILE = BITMASK_HOSTILE

	function ns:IsFriendly(flags)
		return (band(flags or 0, BITMASK_FRIENDLY) ~= 0)
	end

	function ns:IsNeutral(flags)
		return (band(flags or 0, BITMASK_NEUTRAL) ~= 0)
	end

	function ns:IsHostile(flags)
		return (band(flags or 0, BITMASK_HOSTILE) ~= 0)
	end

	------------------------------------------------------
	-- object type: player, npc and none
	------------------------------------------------------
	local BITMASK_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400
	local BITMASK_NPC = COMBATLOG_OBJECT_TYPE_NPC or 0x00000800
	local BITMASK_NONE = COMBATLOG_OBJECT_NONE or 0x80000000
	Private.BITMASK_PLAYER = BITMASK_PLAYER
	Private.BITMASK_NPC = BITMASK_NPC
	Private.BITMASK_NONE = BITMASK_NONE

	function ns:IsPlayer(flags)
		return (band(flags or 0, BITMASK_PLAYER) == BITMASK_PLAYER)
	end

	function ns:IsNPC(flags)
		return (band(flags or 0, BITMASK_NPC) ~= 0)
	end

	function ns:IsNone(flags)
		return (band(flags or 0, BITMASK_NONE) ~= 0)
	end

	------------------------------------------------------
	-- masks used for ownership
	------------------------------------------------------
	do
		local BITMASK_AFFILIATION = COMBATLOG_OBJECT_AFFILIATION_MASK or 0x0000000F
		local BITMASK_REACTION = COMBATLOG_OBJECT_REACTION_MASK or 0x000000F0
		local BITMASK_CONTROL = COMBATLOG_OBJECT_CONTROL_MASK or 0x00000300
		local BITMASK_OWNERSHIP = bit_bor(BITMASK_AFFILIATION, BITMASK_REACTION, BITMASK_CONTROL)
		local BITMASK_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER or 0x00000100

		function ns:GetOwnerFlags(flags)
			local ownerFlags = band(flags or 0, BITMASK_OWNERSHIP)
			if band(ownerFlags, BITMASK_CONTROL_PLAYER) ~= 0 then
				return bit_bor(ownerFlags, BITMASK_PLAYER)
			end
			return bit_bor(ownerFlags, BITMASK_NPC)
		end
	end

	------------------------------------------------------
	-- default flags used mainly for scan
	------------------------------------------------------
	Private.DEFAULT_FLAGS = 0x00000417
end

-------------------------------------------------------------------------------
-- table pools

-- creates a table pool
function Private.TablePool()
	local pool = {tables = Private.WeakTable()}

	-- reuses or creates a table
	pool.new = function()
		local t = next(pool.tables)
		if t then pool.tables[t] = nil end
		return t or {}
	end

	-- deletes a table to be reused later
	pool.del = function(t, deep)
		if type(t) == "table" then
			for k, v in pairs(t) do
				if deep and type(v) == "table" then
					pool.del(v)
				end
				t[k] = nil
			end
			t[""] = true
			t[""] = nil
			pool.tables[t] = true
		end
		return nil
	end

	-- clears/wipes the given table
	pool.clear = function(t)
		if type(t) == "table" then
			for k, v in pairs(t) do
				t[k] = pool.del(v, true)
			end
		end
		return t
	end

	-- creates a table a fills it with args passed
	pool.acquire = function(...)
		local t, n = pool.new(), select("#", ...)
		for i = 1, n do t[i] = select(i, ...) end
		return t
	end

	-- creates a table and fills it with key-value args
	pool.acquireHash = function(...)
		local t, n = pool.new(), select("#", ...)
		for i = 1, n, 2 do
			local k, v = select(i, ...)
			t[k] = v
		end
		return t
	end

	-- populates the given table with args passed
	pool.populate = function(t, ...)
		if type(t) == "table" then
			for i = 1, select("#", ...) do
				t[#t + 1] = select(i, ...)
			end
		end
		return t
	end

	-- populates the given table with key-value args
	pool.populateHash = function(t, ...)
		if type(t) == "table" then
			for i = 1, select("#", ...), 2 do
				local k, v = select(i, ...)
				t[k] = v
			end
		end
		return t
	end

	-- deep copies a table.
	pool.copy = function(orig)
		local orig_type, copy = type(orig), nil
		if orig_type == "table" then
			copy = {}
			for k, v in next, orig, nil do
				copy[pool.copy(k)] = pool.copy(v)
			end
			setmetatable(copy, pool.copy(getmetatable(orig)))
		else
			copy = orig
		end
		return copy
	end

	return pool
end

-- create addon's default table pool
do
	local tablePool = Private.TablePool()
	ns.tablePool = tablePool

	Private.newTable = tablePool.new
	Private.delTable = tablePool.del
	Private.clearTable = tablePool.clear
	Private.copyTable = tablePool.copy
end

-- alternative table reuse
do
	local tables = {}
	local table_mt = {
		__index = {
			free = function(t, no_recurse)
				if not no_recurse then
					for k, v in pairs(t) do
						if type(v) == "table" and getmetatable(t) == "TempTable" then
							v:free()
						end
					end
				end
				wipe(t)
				tables[t] = true
				return nil -- to assign input reference
			end,
			-- aliases --
			concat = table.concat,
			insert = table.insert,
			remove = table.remove,
			sort = table.sort,
			wipe = table.wipe,
		},
		__metatable = "TempTable"
	}

	function Private.TempTable(...)
		local t = next(tables)
		if t then
			tables[t] = nil
		else
			t = setmetatable({}, table_mt)
		end
		for i = 1, select("#", ...) do
			t[i] = (select(i, ...))
		end
		return t
	end
end

-------------------------------------------------------------------------------
-- class, roles ans specs registration

function Private.RegisterClasses()
	Private.RegisterClasses = nil

	-- class, role and spec icons (sprite)
	ns.classicons = format([[%s\Textures\icons]], ns.mediapath)
	ns.roleicons = ns.classicons
	ns.specicons = ns.classicons

	-- class colors/names and valid classes
	local classcolors, validclass = {}, {}
	local CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	for _, class in pairs(CLASS_SORT_ORDER) do
		local info = CLASS_COLORS[class]
		classcolors[class] = {r = info.r, g = info.g, b = info.b, colorStr = info.colorStr}
		L[class] = LOCALIZED_CLASS_NAMES_MALE[class]
		validclass[class] = true
	end
	ns.validclass = validclass -- used to validate classes

	-- custom class colors
	classcolors.BOSS = {r = 0.203, g = 0.345, b = 0.525}
	classcolors.ENEMY = {r = 0.94117, g = 0, b = 0.0196}
	classcolors.MONSTER = {r = 0.549, g = 0.388, b = 0.404}
	classcolors.NEUTRAL = {r = 1.0, g = 1.0, b = 0.1}
	classcolors.PET = {r = 0.09, g = 0.61, b = 0.55}

	-- generate colorStr
	local RGBPercToHex = Private.RGBPercToHex
	for class, info in pairs(classcolors) do
		if not info.colorStr then
			info.colorStr = RGBPercToHex(info.r, info.g, info.b, true)
		end
	end
	-- alias to enemy for now...
	classcolors.PLAYER = classcolors.ENEMY

	local P = ns.profile

	-- some useful functions
	local classcolors_mt = {
		unpack = function(class) -- returns class RGB
			local color = class and classcolors(class)
			if not color then return end
			return color.r, color.g, color.b
		end,
		str = function(class) -- returns color string.
			local color = class and classcolors(class)
			return color and color.colorStr or "ffffffff"
		end,
		format = function(class, text) -- class colored text.
			local color = class and classcolors(class)
			return color and format("\124c%s%s\124r", color.colorStr or "ffffffff", text) or text
		end
	}

	-- missing class? use uknown.
	local unknown_classcolor = {r = 0.353, g = 0.067, b = 0.027, colorStr = "ff5a1107"}
	setmetatable(classcolors_mt, {__index = function(t, class)
		rawset(t, class, unknown_classcolor)
		return unknown_classcolor
	end})

	setmetatable(classcolors, {
		__index = classcolors_mt,
		__call = function(t, class)
			local color = P.usecustomcolors and P.customcolors and P.customcolors[class] or t[class]
			color.colorStr = color.colorStr or RGBPercToHex(color.r, color.g, color.b, true)
			return color
		end
	})
	ns.classcolors = classcolors

	-- common __call for coordinates
	local coords__call = function(t, key)
		local coords = t[key]
		return coords[1], coords[2], coords[3], coords[4]
	end

	-- class icons and coordinates
	local classcoords_mt = {
		__index = function(t, class)
			-- neutral: monster
			if class == "NEUTRAL" then
				local coords = t.MONSTER
				rawset(t, class, coords)
				return coords
			end

			local coords = {384/512, 448/512, 64/512, 128/512} -- unknown
			rawset(t, class, coords)
			return coords
		end,
		__call = coords__call
	}
	ns.classcoords = setmetatable({
		-- default classes
		DEATHKNIGHT = {64/512, 128/512, 128/512, 192/512},
		DRUID = {192/512, 256/512, 0/512, 64/512},
		HUNTER = {0/512, 64/512, 64/512, 128/512},
		MAGE = {64/512, 128/512, 0/512, 64/512},
		PALADIN = {0/512, 64/512, 128/512, 192/512},
		PRIEST = {128/512, 192/512, 64/512, 128/512},
		ROGUE = {128/512, 192/512, 0/512, 64/512},
		SHAMAN = {64/512, 128/512, 64/512, 128/512},
		WARLOCK = {192/512, 256/512, 64/512, 128/512},
		WARRIOR = {0/512, 64/512, 0/512, 64/512},
		-- custom classes
		BOSS = {320/512, 384/512, 0/512, 64/512},
		ENEMY = {448/512, 512/512, 0/512, 64/512},
		MONSTER = {384/512, 448/512, 0/512, 64/512},
		PET = {320/512, 384/512, 64/512, 128/512},
		PLAYER = {448/512, 512/512, 64/512, 128/512}
	}, classcoords_mt)

	-- role icons and coordinates
	local rolecoords_mt = {
		__index = function(t, role)
			local coords = {480/512, 512/512, 128/512, 160/512}
			rawset(t, role, coords)
			return coords
		end,
		__call = coords__call
	}
	ns.rolecoords = setmetatable({
		DAMAGER = {480/512, 512/512, 128/512, 160/512},
		HEALER = {480/512, 512/512, 160/512, 192/512},
		LEADER = {448/512, 480/512, 128/512, 160/512},
		TANK = {448/512, 480/512, 160/512, 192/512}
	}, rolecoords_mt)

	-- spec icons and coordinates
	local speccoords_mt = {__call = coords__call}
	ns.speccoords = setmetatable({
		[62] = {192/512, 256/512, 192/512, 256/512}, --> Mage: Arcane
		[63] = {256/512, 320/512, 192/512, 256/512}, --> Mage: Fire
		[64] = {320/512, 384/512, 192/512, 256/512}, --> Mage: Frost
		[65] = {64/512, 128/512, 384/512, 448/512}, --> Paladin: Holy
		[66] = {128/512, 192/512, 384/512, 448/512}, --> Paladin: Protection
		[70] = {192/512, 256/512, 384/512, 448/512}, --> Paladin: Retribution
		[71] = {0/512, 64/512, 192/512, 256/512}, --> Warrior: Arms
		[72] = {64/512, 128/512, 192/512, 256/512}, --> Warrior: Fury
		[73] = {128/512, 192/512, 192/512, 256/512}, --> Warrior: Protection
		[102] = {64/512, 128/512, 256/512, 320/512}, --> Druid: Balance
		[103] = {128/512, 192/512, 256/512, 320/512}, --> Druid: Feral
		[104] = {192/512, 256/512, 256/512, 320/512}, --> Druid: Guardian
		[105] = {256/512, 320/512, 256/512, 320/512}, --> Druid: Restoration
		[250] = {256/512, 320/512, 384/512, 448/512}, --> Death Knight: Blood
		[251] = {320/512, 384/512, 384/512, 448/512}, --> Death Knight: Frost
		[252] = {384/512, 448/512, 384/512, 448/512}, --> Death Knight: Unholy
		[253] = {320/512, 384/512, 256/512, 320/512}, --> Hunter: Beastmastery
		[254] = {384/512, 448/512, 256/512, 320/512}, --> Hunter: Marksmalship
		[255] = {448/512, 512/512, 256/512, 320/512}, --> Hunter: Survival
		[256] = {192/512, 256/512, 320/512, 384/512}, --> Priest: Discipline
		[257] = {256/512, 320/512, 320/512, 384/512}, --> Priest: Holy
		[258] = {320/512, 384/512, 320/512, 384/512}, --> Priest: Shadow
		[259] = {384/512, 448/512, 192/512, 256/512}, --> Rogue: Assassination
		[260] = {448/512, 512/512, 192/512, 256/512}, --> Rogue: Combat
		[261] = {0/512, 64/512, 256/512, 320/512}, --> Rogue: Subtlty
		[262] = {0/512, 64/512, 320/512, 384/512}, --> Shaman: Elemental
		[263] = {64/512, 128/512, 320/512, 384/512}, --> Shaman: Enhancement
		[264] = {128/512, 192/512, 320/512, 384/512}, --> Shaman: Restoration
		[265] = {384/512, 448/512, 320/512, 384/512}, --> Warlock: Affliction
		[266] = {448/512, 512/512, 320/512, 384/512}, --> Warlock: Demonology
		[267] = {0/512, 64/512, 384/512, 448/512} --> Warlock: Destruction
	}, speccoords_mt)

	--------------------------
	-- custom class options --
	--------------------------

	local function no_custom()
		return not P.usecustomcolors
	end

	local colorsOpt = {
		type = "group",
		name = L["Colors"],
		desc = format(L["Options for %s."], L["Colors"]),
		order = 1000,
		get = function(i)
			return classcolors.unpack(i[#i])
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
				hidden = no_custom,
				disabled = no_custom,
				args = {}
			},
			custom = {
				type = "group",
				name = L["Custom Colors"],
				order = 30,
				hidden = no_custom,
				disabled = no_custom,
				args = {}
			},
			reset = {
				type = "execute",
				name = L["Reset"],
				width = "double",
				order = 90,
				disabled = no_custom,
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
		elseif type(data) == "table" then
			colorsOpt.args.custom.args[class] = {
				type = "color",
				name = L[class],
				desc = format(L["Color for %s."], L[class])
			}
		end
	end

	ns.options.args.tweaks.args.advanced.args.colors = colorsOpt
end

-------------------------------------------------------------------------------
-- spell schools registration

function Private.RegisterSchools()
	Private.RegisterSchools = nil

	local spellschools = {}

	-- handles adding spell schools
	local order = {}
	local function add_school(key, name, r, g, b)
		if key and name and not spellschools[key] then
			spellschools[key] = {r = r or 1, g = g or 1, b = b or 1, name = strmatch(name, "%((.+)%)") or name}
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
		return strmatch(name, "%((.+)%)") or name, isnone
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
				if band(key, k) ~= 0 then
					r = colorTable[k].r or r
					g = colorTable[k].g or g
					b = colorTable[k].b or b
					break
				end
			end
		end

		return r, g, b
	end

	ns.spellschools = setmetatable(spellschools, {
		__index = function(t, key)
			local name, isnone = get_school_name(key)
			if not isnone then
				local r, g, b = get_school_color(key)
				local school = {name = name, r = r, g = g, b = b}
				rawset(t, key, school)
				return school
			end
			return t[0x00] -- unknown
		end,
		__call = function(t, key)
			local school = t[key]
			return school.name, school.r, school.g, school.b
		end
	})

	ns.tooltip_school = function(tooltip, spellid)
		local _, school = strsplit(".", spellid, 3)
		if not school then return end
		tooltip:AddLine(spellschools(tonumber(school)))
	end
end

-------------------------------------------------------------------------------
-- register LibSharedMedia stuff

function Private.RegisterMedias()
	Private.RegisterMedias = nil

	local LSM = LibStub("LibSharedMedia-3.0", true)
	if not LSM then
		ns.MediaFetch = EmptyFunc
		ns.MediaList = EmptyFunc
		return
	end

	-- fonts
	LSM:Register("font", "ABF", format([[%s\Fonts\ABF.ttf]], ns.mediapath))
	LSM:Register("font", "Accidental Presidency", format([[%s\Fonts\Accidental Presidency.ttf]], ns.mediapath))
	LSM:Register("font", "Adventure", format([[%s\Fonts\Adventure.ttf]], ns.mediapath))
	LSM:Register("font", "Diablo", format([[%s\Fonts\Diablo.ttf]], ns.mediapath))
	LSM:Register("font", "FORCED SQUARE", format([[%s\Fonts\FORCED SQUARE.ttf]], ns.mediapath))
	LSM:Register("font", "Hooge", format([[%s\Fonts\Hooge.ttf]], ns.mediapath))

	-- statusbars
	LSM:Register("statusbar", "Aluminium", format([[%s\Statusbar\Aluminium]], ns.mediapath))
	LSM:Register("statusbar", "Armory", format([[%s\Statusbar\Armory]], ns.mediapath))
	LSM:Register("statusbar", "BantoBar", format([[%s\Statusbar\BantoBar]], ns.mediapath))
	LSM:Register("statusbar", "Flat", format([[%s\Statusbar\Flat]], ns.mediapath))
	LSM:Register("statusbar", "Gloss", format([[%s\Statusbar\Gloss]], ns.mediapath))
	LSM:Register("statusbar", "Graphite", format([[%s\Statusbar\Graphite]], ns.mediapath))
	LSM:Register("statusbar", "Grid", format([[%s\Statusbar\Grid]], ns.mediapath))
	LSM:Register("statusbar", "Healbot", format([[%s\Statusbar\Healbot]], ns.mediapath))
	LSM:Register("statusbar", "LiteStep", format([[%s\Statusbar\LiteStep]], ns.mediapath))
	LSM:Register("statusbar", "Minimalist", format([[%s\Statusbar\Minimalist]], ns.mediapath))
	LSM:Register("statusbar", "Otravi", format([[%s\Statusbar\Otravi]], ns.mediapath))
	LSM:Register("statusbar", "Outline", format([[%s\Statusbar\Outline]], ns.mediapath))
	LSM:Register("statusbar", "Round", format([[%s\Statusbar\Round]], ns.mediapath))
	LSM:Register("statusbar", "Serenity", format([[%s\Statusbar\Serenity]], ns.mediapath))
	LSM:Register("statusbar", "Smooth", format([[%s\Statusbar\Smooth]], ns.mediapath))
	LSM:Register("statusbar", "Solid", [[Interface\Buttons\WHITE8X8]])
	LSM:Register("statusbar", "TukTex", format([[%s\Statusbar\TukTex]], ns.mediapath))

	-- borders
	LSM:Register("border", "Glow", format([[%s\Border\Glow]], ns.mediapath))
	LSM:Register("border", "Roth", format([[%s\Border\Roth]], ns.mediapath))

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

	-- fetches media by type
	ns.MediaFetch = function(self, mediatype, key, default)
		return (key and LSM:Fetch(mediatype, key)) or (default and LSM:Fetch(mediatype, default)) or default
	end

	-- lists media by type
	ns.MediaList = function(self, mediatype)
		return LSM:HashTable(mediatype)
	end
end

-------------------------------------------------------------------------------
-- color manipulation

-- converts RGB colors to HEX.
function Private.RGBPercToHex(r, g, b, prefix)
	r = r and r <= 1 and r >= 0 and r or 0
	g = g and g <= 1 and g >= 0 and g or 0
	b = b and b <= 1 and b >= 0 and b or 0
	return format(prefix and "ff%02x%02x%02x" or "%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- generates a color depending on the given percent
function Private.PercentToRGB(perc, reverse, hex)
	-- clamp first
	perc = min(100, max(0, perc or 0))

	-- start with full red
	local r, g, b = 1, 0, 0

	-- reversed?
	if reverse then
		r, g = 0, 1

		if perc <= 50 then -- increment red channel
			r = r + (perc * 0.02)
		else -- set red to 1 and decrement green channel
			r, g = 1, g - ((perc - 50) * 0.02)
		end
	elseif perc <= 50 then -- increment green channel
		g = g + (perc * 0.02)
	else -- set green to 1 and decrement red channel
		r, g = r - ((perc - 50) * 0.02), 1
	end

	-- return hex? channels will be as of 2nd param.
	if hex then
		return Private.RGBPercToHex(r, g, b, true), r, g, b
	end

	-- return only channels.
	return r, g, b
end

-------------------------------------------------------------------------------
-- table functions

-- alternative to table.remove
local error = error
local tremove = table.remove
function Private.tremove(t, index)
	if index then
		return tremove(t, index)
	elseif type(t) ~= "table" then
		error("bad argument #1 to 'tremove' (table expected, got number)")
	end

	local n = #t
	local val = t[n]
	t[n] = nil
	return val
end

-- returns the length of the given table
Private.tLength = _G.tLength
if not Private.tLength then
	Private.tLength = function(t)
		local len = 0
		if t then
			for _ in pairs(t) do
				len = len + 1
			end
		end
		return len
	end
end

-- copies a table from another
function Private.tCopy(to, from, ...)
	for k, v in pairs(from) do
		local skip = false
		if ... then
			if type(...) == "table" then
				for _, j in ipairs(...) do
					if j == k then
						skip = true
						break
					end
				end
			else
				for i = 1, select("#", ...) do
					if select(i, ...) == k then
						skip = true
						break
					end
				end
			end
		end
		if not skip then
			if type(v) == "table" then
				to[k] = {}
				Private.tCopy(to[k], v, ...)
			else
				to[k] = v
			end
		end
	end
end

-- prevents duplicates in a table to format strings
function Private.CheckDuplicate(value, tbl, key)
	if type(tbl) == "table" then
		local num = 0
		local is_array = (#tbl > 0)

		for k, v in pairs(tbl) do
			local val = is_array and type(v) == "table" and v[key] or k
			if val == value and num == 0 then
				num = 1
			elseif val then
				local n, c = strmatch(val, "^(.-)%s*%((%d+)%)$")
				if n == value then
					num = max(num, tonumber(c), 0)
				end
			end
		end

		if num > 0 then
			value = format("%s (%d)", value, num + 1)
		end
	end

	return value
end

-------------------------------------------------------------------------------
-- string functions

do
	-- we a fake frame/fontstring to escape the string
	local escape_fs = nil
	function Private.EscapeStr(str, plain)
		escape_fs = escape_fs or UIParent:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
		escape_fs:SetText(str)
		str = escape_fs:GetText()
		escape_fs:SetText("")
		if plain then
			str = gsub(str, "|c%x%x%x%x%x%x%x%x", "")
			str = gsub(str, "|c%x%x %x%x%x%x%x", "")
			return gsub(str, "|r", "")
		end
		return str
	end

	local function replace(cap1)
		return cap1 == "%" and L["Unknown"]
	end

	local pcall = pcall
	function Private.uformat(fstr, ...)
		local ok, str = pcall(format, fstr, ...)
		return ok and str or gsub(gsub(fstr, "(%%+)([^%%%s<]+)", replace), "%%%%", "%%")
	end

	Private.WrapTextInColorCode = _G.WrapTextInColorCode
	if not Private.WrapTextInColorCode then
		Private.WrapTextInColorCode = function(text, colorHexString)
			return format("\124c%s%s\124r", colorHexString, text)
		end
	end
end

-- alternative to lua <print>
do
	local tostring = tostring
	local tconcat = table.concat
	local tmp, nr = {}, 0
	function Private.Print(...)
		nr = 0
		for i = 1, select("#", ...) do
			nr = nr + 1
			tmp[nr] = tostring(select(i, ...))
		end
		DEFAULT_CHAT_FRAME:AddMessage(tconcat(tmp, " ", 1, nr))
	end
end

-------------------------------------------------------------------------------
-- Save/Restore frame positions to/from db

do
	local floor = math.floor
	local GetScreenWidth, GetScreenHeight = GetScreenWidth, GetScreenHeight

	function Private.SavePosition(f, db)
		if f and f.GetCenter and db then
			local x, y = f:GetCenter()
			local scale = f:GetEffectiveScale()
			local uscale = UIParent:GetScale()

			db.x = ((x * scale) - (GetScreenWidth() * uscale) * 0.5) / uscale
			db.y = ((y * scale) - (GetScreenHeight() * uscale) * 0.5) / uscale
			db.scale = floor(f:GetScale() * 100) * 0.01
		end
	end

	function Private.RestorePosition(f, db)
		if f and f.SetPoint and db then
			local scale = f:GetEffectiveScale()
			local uscale = UIParent:GetScale()
			local x = (db.x or 0) * uscale / scale
			local y = (db.y or 0) * uscale / scale

			f:ClearAllPoints()
			f:SetPoint("CENTER", UIParent, "CENTER", x, y)
			f:SetScale(db.scale or 1)
		end
	end
end

-------------------------------------------------------------------------------
-- toast and notifications

do
	local LibToast = LibStub("SpecializedLibToast-1.0", true)
	local toast_opt = nil

	-- initialize LibToast
	function Private.RegisterToast()
		Private.RegisterToast = nil -- remove it

		if not LibToast then
			ns.Notify = ns.Print
			return
		end

		-- install default options
		local P = ns.profile
		P.toast = P.toast or ns.defaults.toast

		LibToast:Register(format("%sToastFrame", folder), function(toast, text, title, icon, urgency)
			toast:SetTitle(title or folder)
			toast:SetText(text or L["A damage meter."])
			toast:SetIconTexture(icon or ns.logo)
			toast:SetUrgencyLevel(urgency or "normal")
		end)
		if P.toast then
			LibToast.config.hide_toasts = P.toast.hide_toasts
			LibToast.config.spawn_point = P.toast.spawn_point or "TOP"
			LibToast.config.duration = P.toast.duration or 7
			LibToast.config.opacity = P.toast.opacity or 0.75
		end

		-- shows notifications or simply uses Print method.
		local toast_name = format("%sToastFrame", folder)
		function ns:Notify(text, title, icon, urgency)
			if not (LibToast and LibToast:Spawn(toast_name, text, title, icon, urgency)) then
				self:Print(text)
			end
		end
	end

	-- returns toast options
	function Private.ToastOptions()
		Private.ToastOptions = nil -- remove it

		if not LibToast or toast_opt then
			return toast_opt
		end

		toast_opt = {
			type = "group",
			name = L["Notifications"],
			get = function(i)
				return ns.profile.toast[i[#i]] or LibToast.config[i[#i]]
			end,
			set = function(i, val)
				ns.profile.toast[i[#i]] = val
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
					func = function() ns:Notify() end,
					disabled = function() return ns.profile.toast.hide_toasts end,
					width = "double",
					order = 60
				}
			}
		}

		return toast_opt
	end
end

-------------------------------------------------------------------------------
-- Total segment stuff!

do
	local total_opt = nil

	function Private.TotalOptions()
		Private.TotalOptions = nil -- remove it

		if total_opt then
			return total_opt
		end

		local values = {al = 0x10, rb = 0x01, rt = 0x02, db = 0x04, dt = 0x08}
		local disabled = function()
			return (band(ns.profile.totalflag or 0, values.al) ~= 0)
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
						return (band(ns.profile.totalflag or 0, values[i[#i]]) ~= 0)
					end,
					set = function(i, val)
						local v = values[i[#i]]
						if val and band(ns.profile.totalflag or 0, v) == 0 then
							ns.profile.totalflag = (ns.profile.totalflag or 0) + v
						elseif not val and band(ns.profile.totalflag or 0, v) ~= 0 then
							ns.profile.totalflag = max(0, (ns.profile.totalflag or 0) - v)
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

	function Private.total_noclick(set, mode)
		return (not ns.profile.totalidc and set == "total" and type(mode) == "table" and mode.nototal == true)
	end

	local function total_record(set)
		local totalflag = ns.total and set and ns.profile.totalflag

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

	function ns:DispatchSets(func, ...)
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
-- creates generic dialog

local dialog_name = format("%sCommonConfirmDialog", folder)
function Private.ConfirmDialog(text, accept, cancel, override)
	if type(cancel) == "table" and override == nil then
		override = cancel
		cancel = nil
	end

	local t = wipe(StaticPopupDialogs[dialog_name] or {})
	StaticPopupDialogs[dialog_name] = t

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
	t.button1 = L["Accept"]
	t.button2 = L["Cancel"]
	t.timeout = 0
	t.whileDead = 1
	t.hideOnEscape = 1

	if type(override) == "table" then
		Private.tCopy(t, override)
	end

	dialog = StaticPopup_Show(dialog_name)
	if dialog then
		strata = dialog:GetFrameStrata()
		dialog:SetFrameStrata("TOOLTIP")
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

	local strbyte, strchar = string.byte, string.char
	local lshift, tconcat = bit.lshift, table.concat

	-- only used for backwards compatibility
	local function HexDecode(str)
		str = gsub(gsub(str, "%[.-%]", ""), "[^0123456789ABCDEF]", "")
		if (#str == 0) or (#str % 2 ~= 0) then
			return false, "Invalid Hex string"
		end

		local t, bl, bh = {}
		local i = 1
		repeat
			bl = strbyte(str, i)
			bl = bl >= 65 and bl - 55 or bl - 48
			i = i + 1
			bh = strbyte(str, i)
			bh = bh >= 65 and bh - 55 or bh - 48
			i = i + 1
			t[#t + 1] = strchar(lshift(bh, 4) + bl)
		until i >= #str
		return tconcat(t)
	end

	function Private.serialize(comm, ...)
		local result = LD:CompressDeflate(AS:Serialize(...), LL)
		if comm then
			return LD:EncodeForWoWChatChannel(result)
		end
		return LD:EncodeForPrint(result)
	end

	function Private.deserialize(data, comm)
		local result = comm and LD:DecodeForWoWChatChannel(data) or LD:DecodeForPrint(data)
		result = result and LD:DecompressDeflate(result) or nil
		if result then
			return AS:Deserialize(result)
		end

		-- backwards compatibility
		local err
		if comm then
			encodeTable = encodeTable or LC:GetAddonEncodeTable()
			data, err = encodeTable:Decode(data), "Error decoding"
		else
			data, err = HexDecode(data)
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
-- custom "GetSpellInfo" and "GetSpellLink"

do
	local math_abs = math.abs
	local GetSpellInfo, GetSpellLink = GetSpellInfo, GetSpellLink

	local customSpells = {
		[3] = {L["Falling"], [[Interface\ICONS\ability_rogue_quickrecovery]]},
		[4] = {L["Drowning"], [[Interface\ICONS\spell_shadow_demonbreath]]},
		[5] = {L["Fatigue"], [[Interface\ICONS\spell_nature_sleep]]},
		[6] = {L["Fire"], [[Interface\ICONS\spell_fire_fire]]},
		[7] = {L["Lava"], [[Interface\ICONS\spell_shaman_lavaflow]]},
		[8] = {L["Slime"], [[Interface\ICONS\inv_misc_slime_01]]}
	}
	local customIcons = {
		[75] = [[Interface\ICONS\inv_weapon_bow_07]], --> Auto Shot
		[6603] = [[Interface\ICONS\inv_sword_04]], --> Melee
		[3026] = [[Interface\ICONS\spell_shadow_soulgem]], --> Use Soulstone
		[20758] = [[Interface\ICONS\spell_shadow_soulgem]], --> Use Soulstone
		[20759] = [[Interface\ICONS\spell_shadow_soulgem]], --> Use Soulstone
		[20760] = [[Interface\ICONS\spell_shadow_soulgem]], --> Use Soulstone
		[20761] = [[Interface\ICONS\spell_shadow_soulgem]], --> Use Soulstone
		[27240] = [[Interface\ICONS\spell_shadow_soulgem]], --> Use Soulstone
		[31786] = [[Interface\ICONS\spell_holy_revivechampion]], --> Spiritual Attunement
		[47882] = [[Interface\ICONS\spell_shadow_soulgem]], --> Use Soulstone
		[49088] = [[Interface\ICONS\spell_shadow_antimagicshell]], --> Anti-Magic Shell
		[54755] = [[Interface\ICONS\inv_glyph_majordruid]], --> Glyph of Rejuvenation
		[54968] = [[Interface\ICONS\inv_glyph_majorpaladin]], --> Glyph of Holy Light
		[56160] = [[Interface\ICONS\inv_glyph_majorpriest]], --> Glyph of Power Word: Shield
		[58362] = [[Interface\ICONS\inv_glyph_majorwarrior]], --> Glyph of Heroic Strike
		[61607] = [[Interface\ICONS\ability_hunter_rapidkilling]], --> Mark of Blood
		[67545] = [[Interface\ICONS\spell_fire_flamebolt]] --> Empowered Fire
	}

	local strfind = string.find
	-- used to split spell: [id].[school].[petname]
	local function SpellSplit(spellid)
		if type(spellid) == "string" and strfind(spellid, ".") then
			local id, school, petname = strsplit(".", spellid, 3)
			return tonumber(id), tonumber(school), petname
		end
		return spellid
	end
	Private.SpellSplit = SpellSplit

	function Private.SpellInfo(spellid)
		if spellid then
			spellid = math_abs(SpellSplit(spellid))
			local res1, res2, res3, res4, res5, res6, res7, res8, res9
			if customSpells[spellid] then
				res1, res3 = customSpells[spellid][1], customSpells[spellid][2]
			else
				res1, res2, res3, res4, res5, res6, res7, res8, res9 = GetSpellInfo(spellid)
				if spellid == 6603 then
					res1 = L["Melee"]
				end
				res3 = customIcons[spellid] or res3
			end
			return res1, res2, res3, res4, res5, res6, res7, res8, res9
		end
	end

	function Private.SpellLink(spellid)
		if not customSpells[spellid] then
			return GetSpellLink(math_abs(spellid))
		end
	end

	-- spell icon and name to speed up things
	local SpellInfo = Private.SpellInfo
	ns.spellnames = setmetatable({}, {
		__mode = "kv",
		__index = function(t, spellid)
			local name, _, icon = SpellInfo(spellid)
			name = name or L["Unknown"]
			icon = icon or [[Interface\ICONS\INV_Misc_QuestionMark]]
			rawset(t, spellid, name)
			rawset(ns.spellicons, spellid, icon)
			return name
		end,
		__newindex = function(t, spellid, name)
			rawset(t, spellid, name)
		end
	})
	ns.spellicons = setmetatable({}, {
		__mode = "kv",
		__index = function(t, spellid)
			local name, _, icon = SpellInfo(spellid)
			name = name or L["Unknown"]
			icon = icon or [[Interface\ICONS\INV_Misc_QuestionMark]]
			rawset(t, spellid, icon)
			rawset(ns.spellnames, spellid, name)
			return icon
		end,
		__newindex = function(t, spellid, icon)
			rawset(t, spellid, icon)
		end
	})
end

-------------------------------------------------------------------------------
-- creatures, players and pets checkers

do
	local strsub = string.sub
	local UnitGUID, UnitName = UnitGUID, UnitName
	local UnitClass, UnitIsPlayer = UnitClass, UnitIsPlayer

	local BITMASK_GROUP = Private.BITMASK_GROUP
	local BITMASK_PETS = Private.BITMASK_PETS
	local BITMASK_FRIENDLY = Private.BITMASK_FRIENDLY
	local BITMASK_NPC = Private.BITMASK_NPC
	local BITMASK_PLAYER = Private.BITMASK_PLAYER

	ns.userGUID = UnitGUID("player")
	_, ns.userClass = UnitClass("player")
	ns.userName = UnitName("player")
	ns.userRealm = gsub(GetRealmName(), "%s", "")

	-- checks if the given guid/flags are those of a creature.
	function Private.IsCreature(guid, flags)
		if tonumber(guid) then
			return (band(strsub(guid, 1, 5), 0x00F) == 3 or band(strsub(guid, 1, 5), 0x00F) == 5)
		end
		return (band(flags or 0, BITMASK_NPC) ~= 0)
	end

	-- used to protect tables
	local table_mt = {__metatable = true}

	-- players & pets [guid] = UnitID
	local guidToUnit = setmetatable(Private.guidToUnit or {}, table_mt)
	Private.guidToUnit = guidToUnit

	-- players: [guid] = class / pets: [guid] = owner guid
	local guidToClass = setmetatable(Private.guidToClass or {}, table_mt)
	Private.guidToClass = guidToClass

	-- players only: [guid] = name
	local guidToName = setmetatable(Private.guidToName or {}, table_mt)
	Private.guidToName = guidToName

	-- pets only: [pet guid] = owner guid
	local guidToOwner = setmetatable(Private.guidToOwner or {}, {
		__metatable = true,
		__newindex = function(t, guid, owner)
			rawset(guidToClass, guid, owner)
			rawset(t, guid, owner)
		end
	})
	Private.guidToOwner = guidToOwner

	do
		-- tables used to cached results in order to speed up check
		local __t1 = Private.WeakTable() -- cached players
		local __t2 = Private.WeakTable() -- cached pets

		-- checks if the guid is a player (extra: helps IsPet)
		function Private.IsPlayer(guid, name, flags)
			-- already cached?
			if __t1[guid] ~= nil then
				return __t1[guid]
			end

			-- group member?
			if guidToName[guid] then
				__t1[guid] = 1
				__t2[guid] = (__t2[guid] == nil) and false or __t2[guid]
				return 1
			end

			-- group pet?
			if guidToClass[guid] then
				__t1[guid] = false
				__t2[guid] = __t2[guid] or 1
				return false
			end

			-- player by flgs?
			if band(flags or 0, BITMASK_PLAYER) == BITMASK_PLAYER then
				__t1[guid] = true
				__t2[guid] = (__t2[guid] == nil) and false or __t2[guid]
				return true
			end

			-- player by UnitIsPlayer?
			if name and UnitIsPlayer(name) then
				__t1[guid] = true
				__t2[guid] = (__t2[guid] == nil) and false or __t2[guid]
				return true
			end

			-- just set it to false
			__t1[guid] = false
			return false
		end

		-- checks if the guid is a pet (extra: helps IsPlayer)
		function Private.IsPet(guid, flags)
			-- already cached?
			if __t2[guid] ~= nil then
				return __t2[guid]
			end

			-- just in case
			if guidToName[guid] then
				__t2[guid] = false
				__t1[guid] = 1
				return false
			end

			-- grouped pet?
			if guidToClass[guid] then
				__t2[guid] = 1
				__t1[guid] = false
				return 1
			end

			-- ungrouped pet?
			if band(flags or 0, BITMASK_PETS) ~= 0 then
				local res = (band(flags or 0, BITMASK_FRIENDLY) ~= 0) and 1 or true
				__t2[guid] = res
				__t1[guid] = false
				return res
			end

			__t2[guid] = false
			return false
		end
	end

	-- returns unit's full name
	local function UnitFullName(unit, ownerUnit, fmt)
		if ownerUnit and fmt then
			local name, realm = UnitName(ownerUnit)
			return format("%s <%s>", UnitName(unit), realm and realm ~= "" and format("%s-%s", name, realm) or name)
		end

		local name, realm = UnitName(unit)
		return not ownerUnit and realm and realm ~= "" and format("%s-%s", name, realm) or name
	end
	Private.UnitFullName = UnitFullName

	-- adds a combatant
	function Private.AddCombatant(unit, ownerUnit)
		local guid = UnitGUID(unit)
		if not guid then return end
		guidToUnit[guid] = unit -- store the unit.

		-- for pets...
		if ownerUnit then
			guidToOwner[guid] = UnitGUID(ownerUnit)
			return
		end

		-- for players...
		local _, class = UnitClass(unit)
		guidToClass[guid] = class
		guidToName[guid] = UnitFullName(unit)
	end
end

-------------------------------------------------------------------------------
-- generic import and export window

do
	local AceGUI = nil

	local frame_name = format("%sImportExportFrame", folder)
	local function open_window(title, data, clickfunc, fontsize)
		AceGUI = AceGUI or LibStub("AceGUI-3.0")
		local frame = AceGUI:Create("Frame")
		frame:SetTitle(L["Import/Export"])
		frame:SetLayout("Flow")
		frame:SetCallback("OnClose", function(widget)
			AceGUI:Release(widget)
			collectgarbage()
		end)
		frame:SetWidth(535)
		frame:SetHeight(350)

		local editbox = AceGUI:Create("MultiLineEditBox")
		editbox.editBox:SetFontObject(GameFontHighlightSmall)
		local fontpath = ns:MediaFetch("font", "Fira Mono Medium")
		if fontpath then editbox.editBox:SetFont(fontpath, fontsize or 10, "") end
		editbox:SetLabel(title)
		editbox:SetFullWidth(true)
		editbox:SetFullHeight(true)
		frame:AddChild(editbox)

		if type(data) == "function" then
			clickfunc = data
			data = nil
		end

		if data then
			frame:SetStatusText(L["Press CTRL-C to copy the text to your clipboard."])
			editbox:DisableButton(true)
			editbox:SetText(data)
			editbox.editBox:SetFocus()
			editbox.editBox:HighlightText()
			editbox:SetCallback("OnLeave", function(widget)
				widget.editBox:HighlightText()
				widget.editBox:SetFocus()
			end)
			editbox:SetCallback("OnEnter", function(widget)
				widget.editBox:HighlightText()
				widget.editBox:SetFocus()
			end)
		else
			frame:SetStatusText(L["Press CTRL-V to paste the text from your clipboard."])
			editbox:DisableButton(false)
			editbox.editBox:SetFocus()
			editbox.button:SetScript("OnClick", function(widget)
				clickfunc(editbox:GetText())
				AceGUI:Release(frame)
				collectgarbage()
			end)
		end
		-- close on escape
		_G[frame_name] = frame.frame
		UISpecialFrames[#UISpecialFrames + 1] = frame_name
	end

	function Private.ImportExport(title, data, clickfunc, fontsize)
		return open_window(title, data, clickfunc, fontsize)
	end
end

-------------------------------------------------------------------------------
-- prototypes and binding functions

do
	local getmetatable = getmetatable

	-- fight/set prototype
	local setPrototype = {}
	ns.setPrototype = setPrototype

	-- common actors prototype
	local actorPrototype = {}
	local actorPrototype_mt = {__index = actorPrototype}
	ns.actorPrototype = actorPrototype

	-- player prototype
	local playerPrototype = setmetatable({}, actorPrototype_mt)
	ns.playerPrototype = playerPrototype

	-- enemy prototype
	local enemyPrototype = setmetatable({}, actorPrototype_mt)
	ns.enemyPrototype = enemyPrototype

	local function bind_set_actors(actors)
		if not actors then return end
		for _, actor in pairs(actors) do
			if actor.enemy then
				enemyPrototype:Bind(actor)
			elseif not actor.enemy then
				playerPrototype:Bind(actor)
			end
		end
	end

	-- bind a set table to the set prototype
	function setPrototype:Bind(obj)
		if obj and getmetatable(obj) ~= self then
			setmetatable(obj, self)
			self.__index = self
			bind_set_actors(obj.actors)
		end
		self.arena = (ns.forPVP and obj and obj.type == "arena")
		return obj
	end

	-- bind an actor table to the prototype
	function actorPrototype:Bind(obj)
		if obj and getmetatable(obj) ~= self then
			setmetatable(obj, self)
			self.__index = self
		end
		return obj
	end
end

-------------------------------------------------------------------------------
-- combat log watch functions

do
	local IsWatching = false

	function Private.StartWatching(obj)
		if not IsWatching then
			obj:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "ParseCombatLog")
			IsWatching = true
		end
	end

	function Private.StopWatching(obj)
		if IsWatching then
			obj:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			IsWatching = false
		end
	end
end

-------------------------------------------------------------------------------
-- temporary flags check bypass

do
	local new = Private.newTable
	local del = Private.delTable
	local clear = Private.clearTable
	local temp_units = nil

	-- adds a temporary unit with optional info
	function Private.AddTempUnit(guid, info)
		if not guid then return end
		temp_units = temp_units or new()
		temp_units[guid] = info or true
	end

	-- deletes a temporary unit if found
	function Private.DelTempUnit(guid)
		if guid and temp_units and temp_units[guid] then
			temp_units[guid] = del(temp_units[guid])
		end
	end

	-- returns the temporary unit stored "info" or false
	function Private.GetTempUnit(guid)
		return guid and temp_units and temp_units[guid]
	end

	-- clears all store temporary units
	function Private.ClearTempUnits()
		temp_units = clear(temp_units)
	end
end

-------------------------------------------------------------------------------
-- window table
do
	local Window = {}
	ns.Window = Window

	-- yet another recycle bin
	local window_bin = Private.WeakTable()

	-- creates a new window
	local new = Private.newTable
	local window_mt = {
		__index = Window,
		__newindex = function(self, key, value)
			rawset(self, key, value)
			if not self.ttwin or key == "ttwin" then return end
			rawset(self.ttwin, key, value)
		end
	}
	local tooltip_mt = {__index = setmetatable({}, window_mt)}

	function Window.new(parent)
		local win = next(window_bin) or {}
		window_bin[win] = nil

		if parent then
			win.super = parent
			win.dataset = new()
			return setmetatable(win, tooltip_mt)
		end

		win.super = nil
		win.dataset = new()
		win.history = new()
		win.metadata = new()
		return setmetatable(win, window_mt)
	end

	-- deletes a window and recycles its tables
	local del = Private.delTable
	function Window.del(win)
		win.super = nil
		win.dataset = del(win.dataset)
		if not win.super then
			win.history = del(win.history)
			win.metadata = del(win.metadata)
		end
		if win.ttwin then -- tooltip
			win.ttwin = Window.del(win.ttwin)
		end
		setmetatable(win, nil)
		window_bin[win] = true
		return nil -- assign input reference
	end

	-- creates or reuses a dataset table
	function Window:nr(index)
		local d = self.dataset[index]
		if d then
			if d.ignore then
				d.icon = nil
				d.color = nil
			end
			d.id = nil
			d.text = nil
			d.class = nil
			d.role = nil
			d.spec = nil
			d.ignore = nil
			d.reportlabel = nil
			d.reportvalue = nil
			return d
		end

		d = new()
		self.dataset[index] = d
		return d
	end

	-- wipes window's dataset table
	function Window:reset()
		self.title = nil -- reset title
		if not self.dataset then return end
		for i = #self.dataset, 0, -1 do
			if self.dataset[i] then
				wipe(self.dataset[i])
			end
		end
	end

	-- cleans window from what was set by modules.
	function Window:clean()
		self.actorid, self.actorname, self.actorclass = nil, nil, nil
		self.otherid, self.othername, self.otherclass = nil, nil, nil
		self.targetid, self.targetname, self.targetclass = nil, nil, nil
		self.spellid, self.spellname = nil, nil
	end

	-- generates a spell dataset/bar.
	local SpellSplit = Private.SpellSplit
	local spellnames = ns.spellnames
	local spellicons = ns.spellicons
	function Window:spell(d, spell, is_hot)
		if d and spell then
			-- create the dataset?
			if type(d) == "number" then
				d = self:nr(d)
			end

			d.id = spell -- locked!

			local spellid, school, suffix = SpellSplit(spell)
			d.spellid = spellid
			d.spellschool = school
			d.icon = spellicons[spellid]

			-- for SPELL_EXTRA_ATTACKS
			if tonumber(suffix) then
				d.label = format("%s (%s)", spellnames[suffix], spellnames[spellid])
			else
				d.label = spellnames[spellid]
				if suffix then -- has a suffix?
					d.label = format("%s (%s)", d.label, suffix)
				end
			end

			-- hots and dots?
			if spellid < 0 and is_hot ~= false then
				d.label = format("%s (%s)", d.label, is_hot and L["HoT"] or L["DoT"])
			end
		end
		return d
	end

	-- generates actor's dataset/bar
	function Window:actor(d, actor, is_enemy, actorname)
		if d and actor then
			-- create the dataset?
			if type(d) == "number" then
				d = self:nr(d)
			end

			if type(actor) == "string" then
				d.id = actor
				d.label = actorname or actor
				return d
			end

			d.id = actor.id or actorname
			d.label = actorname or L["Unknown"]

			-- speed up things if it's a pet/enemy.
			if strmatch(d.label, "%<(%a+)%>") then
				d.class = "PET"
				return d
			end

			-- no need to go further for enemies
			if is_enemy then
				d.class = actor.class or "ENEMY"
				d.role = actor.role
				d.spec = actor.spec
				d.talent = actor.talent
				return d
			end

			d.class = actor.class or "UNKNOWN"
			d.role = actor.role
			d.spec = actor.spec
			d.talent = actor.talent

			if ns.validclass[d.class] then
				d.text = ns:FormatName(d.label, actor.id)
			end
		end
		return d
	end

	-- determines whehter an actor's bar should be shown or not
	-- prevents repeated code to check for class
	function Window:show_actor(actor, set, strict)
		if not actor then
			return false
		elseif self.class and actor.class ~= self.class then
			return false
		elseif strict and actor.fake then
			return false
		elseif strict and actor.enemy and not set.arena then
			return false
		else
			return true
		end
	end

	-- colorizes a database/bar for arena fights
	function Window:color(d, set, is_enemy)
		if not d or not set then
			return
		elseif set.arena and is_enemy then
			d.color = ns.classcolors(set.faction and "ARENA_GREEN" or "ARENA_GOLD")
		elseif set.arena then
			d.color = ns.classcolors(set.faction and "ARENA_GOLD" or "ARENA_GREEN")
		elseif d.color then
			d.color = nil
		end
	end
end
