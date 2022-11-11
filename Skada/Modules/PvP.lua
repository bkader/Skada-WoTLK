local _, Skada = ...
Skada:RegisterModule("Player vs. Player", "mod_pvp_desc", function(L, P)
	local mode = Skada:NewModule("Player vs. Player")

	local format, wipe, GetTime = string.format, wipe, GetTime
	local UnitGUID, UnitClass, UnitBuff, UnitIsPlayer = UnitGUID, UnitClass, UnitBuff, UnitIsPlayer
	local spellnames, UnitCastingInfo = Skada.spellnames, UnitCastingInfo

	local specsCache, specsRoles = nil, nil
	local spellsTable, aurasTable = nil, nil

	local function build_spell_list()
		if not specsRoles then
			specsRoles = {
				[105] = "HEALER", -- Druid: Restoration
				[256] = "HEALER", -- Priest: Discipline
				[257] = "HEALER", -- Priest: Holy
				[264] = "HEALER", -- Shaman: Restoration
				[65] = "HEALER", -- Paladin: Holy
				[66] = "TANK", -- Paladin: Protection
				[73] = "TANK" -- Warrior: Protection
			}
		end

		if not aurasTable then
			aurasTable = {
				WARRIOR = {
					[spellnames[56638]] = 71, -- Taste for Blood
					[spellnames[64976]] = 71, -- Juggernaut
					[spellnames[29801]] = 72, -- Rampage
					[spellnames[50227]] = 73 -- Sword and Board
				},
				PALADIN = {
					[spellnames[68020]] = 70, -- Seal of Command
					[spellnames[31801]] = 70 -- Seal of Vengeance
				},
				ROGUE = {
					[spellnames[58427]] = 259, -- Overkill
					[spellnames[36554]] = 261, -- Shadowstep
					[spellnames[31223]] = 261 -- Master of Subtlety
				},
				PRIEST = {
					[spellnames[52795]] = 256, -- Borrowed Time
					[spellnames[47788]] = 257, -- Guardian Spirit
					[spellnames[15473]] = 258, -- Shadowform
					[spellnames[15286]] = 258 -- Vampiric Embrace
				},
				DEATHKNIGHT = {
					[spellnames[49016]] = 250, -- Hysteria
					[spellnames[53138]] = 250, -- Abomination's Might
					[spellnames[55610]] = 251, -- Imp. Icy Talons
					[spellnames[49222]] = 252 -- Bone Shield
				},
				MAGE = {
					[spellnames[11426]] = 62, -- Ice Barrier
					[spellnames[11129]] = 63, -- Combustion
					[spellnames[31583]] = 64 -- Arcane Empowerment
				},
				WARLOCK = {
					[spellnames[30299]] = 267 -- Nether Protection
				},
				SHAMAN = {
					[spellnames[51470]] = 262, -- Elemental Oath
					[spellnames[30802]] = 263, -- Unleashed Rage
					[spellnames[974]] = 264 -- Earth Shield
				},
				HUNTER = {
					[spellnames[20895]] = 253, -- Spirit Bond
					[spellnames[19506]] = 254 -- Trueshot Aura
				},
				DRUID = {
					[spellnames[24907]] = 102, -- Moonkin Aura
					[spellnames[24932]] = 103, -- Leader of the Pack
					[spellnames[33891]] = 105, -- Tree of Life
					[spellnames[48438]] = 105 -- Wild Growth
				}
			}
		end

		if not spellsTable then
			spellsTable = {
				WARRIOR = {
					[spellnames[12294]] = 71, -- Mortal Strike
					[spellnames[46924]] = 71, -- Bladestorm
					[spellnames[1680]] = 72, -- Whirlwind
					[spellnames[23881]] = 72, -- Bloodthirst
					[spellnames[47475]] = 72, -- Slam
					[spellnames[12809]] = 73, -- Concussion Blow
					[spellnames[47498]] = 73 -- Devastate
				},
				PALADIN = {
					[spellnames[20473]] = 65, -- Holy Shock
					[spellnames[53563]] = 65, -- Beacon of Light
					[spellnames[31935]] = 66, -- Avenger's Shield
					[spellnames[35395]] = 70, -- Crusader Strike
					[spellnames[53385]] = 70, -- Divine Storm
					[spellnames[20066]] = 70 -- Repentance
				},
				ROGUE = {
					[spellnames[1329]] = 259, -- Mutilate
					[spellnames[51662]] = 259, -- Hunger For Blood
					[spellnames[51690]] = 260, -- Killing Spree
					[spellnames[13877]] = 260, -- Blade Flurry
					[spellnames[13750]] = 260, -- Adrenaline Rush
					[spellnames[16511]] = 261, -- Hemorrhage
					[spellnames[51713]] = 261 -- Shadow Dance
				},
				PRIEST = {
					[spellnames[47540]] = 256, -- Penance
					[spellnames[10060]] = 256, -- Power Infusion
					[spellnames[33206]] = 256, -- Pain Suppression
					[spellnames[34861]] = 257, -- Circle of Healing
					[spellnames[15487]] = 258, -- Silence
					[spellnames[34914]] = 258 -- Vampiric Touch
				},
				DEATHKNIGHT = {
					[spellnames[45902]] = 250, -- Heart Strike
					[spellnames[49203]] = 251, -- Hungering Cold
					[spellnames[49143]] = 251, -- Frost Strike
					[spellnames[49184]] = 251, -- Howling Blast
					[spellnames[55090]] = 252 -- Scourge Strike
				},
				MAGE = {
					[spellnames[44425]] = 62, -- Arcane Barrage
					[spellnames[44457]] = 63, -- Living Bomb
					[spellnames[42859]] = 63, -- Scorch
					[spellnames[31661]] = 63, -- Dragon's Breath
					[spellnames[11113]] = 63, -- Blast Wave
					[spellnames[44572]] = 64 -- Deep Freeze
				},
				WARLOCK = {
					[spellnames[48181]] = 265, -- Haunt
					[spellnames[30108]] = 265, -- Unstable Affliction
					[spellnames[59672]] = 266, -- Metamorphosis
					[spellnames[50769]] = 267, -- Chaos Bolt
					[spellnames[30283]] = 267 -- Shadowfury
				},
				SHAMAN = {
					[spellnames[51490]] = 262, -- Thunderstorm
					[spellnames[16166]] = 262, -- Elemental Mastery
					[spellnames[51533]] = 263, -- Feral Spirit
					[spellnames[30823]] = 263, -- Shamanistic Rage
					[spellnames[17364]] = 263, -- Stormstrike
					[spellnames[61295]] = 264, -- Riptide
					[spellnames[51886]] = 264 -- Cleanse Spirit
				},
				HUNTER = {
					[spellnames[19577]] = 253, -- Intimidation
					[spellnames[34490]] = 254, -- Silencing Shot
					[spellnames[53209]] = 254, -- Chimera Shot
					[spellnames[53301]] = 255, -- Explosive Shot
					[spellnames[19386]] = 255 -- Wyvern Sting
				},
				DRUID = {
					[spellnames[48505]] = 102, -- Starfall
					[spellnames[50516]] = 102, -- Typhoon
					[spellnames[33876]] = 103, -- Mangle (Cat)
					[spellnames[33878]] = 104, -- Mangle (Bear)
					[spellnames[18562]] = 105 -- Swiftmend
				}
			}
		end
	end

	function mode:UNIT_AURA(_, unit)
		if Skada.insType ~= "pvp" and Skada.insType ~= "arena" then
			Skada.UnregisterEvent(self, "UNIT_AURA")
		elseif unit and UnitIsPlayer(unit) and not specsCache[UnitGUID(unit)] then
			local _, class = UnitClass(unit)
			if Skada.validclass[class] then
				local i = 1
				local name = UnitBuff(unit, i)
				while name do
					if aurasTable[class] and aurasTable[class][name] then
						specsCache[UnitGUID(unit)] = aurasTable[class][name]
						break -- found
					end
					i = i + 1
					name = UnitBuff(unit, i)
				end
			end
		end
	end

	function mode:UNIT_SPELLCAST_START(_, unit)
		if Skada.insType ~= "pvp" and Skada.insType ~= "arena" then
			Skada.UnregisterEvent(self, "UNIT_SPELLCAST_START")
		elseif unit and UnitIsPlayer(unit) and not specsCache[UnitGUID(unit)] then
			local _, class = UnitClass(unit)
			local spell = UnitCastingInfo(unit)
			if Skada.validclass[class] and spellsTable[class] and spellsTable[class][spell] then
				specsCache[UnitGUID(unit)] = spellsTable[class][spell]
			end
		end
	end

	function mode:CheckZone(_, current, previous)
		if current == previous then return end

		specsCache = wipe(specsCache or {})

		if current == "arena" or current == "pvp" then
			build_spell_list()
			Skada.RegisterEvent(self, "UNIT_AURA")
			Skada.RegisterEvent(self, "UNIT_SPELLCAST_START")
			Skada.RegisterCallback(self, "Skada_GetEnemy", "GetEnemy")
		else
			Skada.UnregisterEvent(self, "UNIT_AURA")
			Skada.UnregisterEvent(self, "UNIT_SPELLCAST_START")
			Skada.UnregisterCallback(self, "Skada_GetEnemy", "GetEnemy")
		end
	end

	function mode:GetEnemy(_, actor, set)
		if actor and not actor.fake and Skada.validclass[actor.class] then
			if actor.spec == nil then
				actor.spec = specsCache[actor.id]
			end

			if actor.spec and (actor.role == nil or actor.role == "NONE") then
				actor.role = specsRoles[actor.spec] or "DAMAGER"
			end

			if actor.time == nil then
				actor.time = 0
			end

			if actor.last == nil then
				actor.last = Skada._Time or GetTime()
			end
		end
	end

	function mode:OnEnable()
		Skada.forPVP = true
		specsCache = specsCache or {}
		Skada.RegisterMessage(self, "ZONE_TYPE_CHANGED", "CheckZone")
	end

	function mode:OnDisable()
		Skada.forPVP = nil
		Skada.UnregisterAllMessages(self)
	end

	---------------------------------------------------------------------------

	function mode:OnInitialize()
		if P.modules.arena then
			P.modules.arena = nil
		end

		-- add custom colors to tweaks
		Skada.options.args.tweaks.args.advanced.args.colors.args.arean = {
			type = "group",
			name = L["Arena Teams"],
			order = 40,
			hidden = Skada.options.args.tweaks.args.advanced.args.colors.args.custom.disabled,
			disabled = Skada.options.args.tweaks.args.advanced.args.colors.args.custom.disabled,
			args = {
				ARENA_GOLD = {
					type = "color",
					name = L["ARENA_GOLD"],
					desc = format(L["Color for %s."], L["ARENA_GOLD"])
				},
				ARENA_GREEN = {
					type = "color",
					name = L["ARENA_GREEN"],
					desc = format(L["Color for %s."], L["ARENA_GREEN"])
				}
			}
		}
	end

	---------------------------------------------------------------------------

	-- arena custom colors
	local classcolors = Skada.classcolors or {}
	Skada.classcolors = classcolors

	classcolors.ARENA_GOLD = {r = 1, g = 0.82, b = 0, colorStr = "ffffd100"}
	classcolors.ARENA_GREEN = {r = 0.1, g = 1, b = 0.1, colorStr = "ff19ff19"}

	-- purple color instead of green for color blind mode.
	if GetCVar("colorblindMode") == "1" then
		classcolors.ARENA_GREEN.r = 0.686
		classcolors.ARENA_GREEN.g = 0.384
		classcolors.ARENA_GREEN.b = 1
		classcolors.ARENA_GREEN.colorStr = "ffae61ff"
	end

	-- localize arena team colors (just in case)
	L["ARENA_GREEN"] = L["Green Team"]
	L["ARENA_GOLD"] = L["Gold Team"]
end)
