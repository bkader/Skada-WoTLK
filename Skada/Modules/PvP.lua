local Skada = Skada
Skada:AddLoadableModule("PVP", function(L)
	if Skada:IsDisabled("PVP") then return end

	local mod = Skada:NewModule(PVP)

	local format, wipe = string.format, wipe
	local GetCVar, UnitIsPlayer = GetCVar, UnitIsPlayer
	local UnitGUID, UnitBuff = UnitGUID, UnitBuff
	local GetSpellInfo, UnitCastingInfo = GetSpellInfo, UnitCastingInfo

	local teamGreen = {r = 0.1, g = 1, b = 0.1, colorStr = "ff19ff19"}
	local teamYellow = {r = 1, g = 0.82, b = 0, colorStr = "ffffd100"}
	local specsCache, spellsTable, aurasTable, _ = {}, nil, nil, nil

	-- table used to determine enemies roles.
	-- Except for healers and some tanks, all enemies are damagers.
	local specsRoles = {
		[105] = "HEALER", -- Druid: Restoration
		[256] = "HEALER", -- Priest: Discipline
		[257] = "HEALER", -- Priest: Holy
		[264] = "HEALER", -- Shaman: Restoration
		[65] = "HEALER", -- Paladin: Holy
		[66] = "TANK", -- Paladin: Protection
		[73] = "TANK", -- Warrior: Protection
	}

	local function BuildSpellsList()
		if not aurasTable then
			aurasTable = {
				-- WARRIOR
				[GetSpellInfo(56638)] = 71, -- Taste for Blood
				[GetSpellInfo(64976)] = 71, -- Juggernaut
				[GetSpellInfo(29801)] = 72, -- Rampage
				[GetSpellInfo(50227)] = 73, -- Sword and Board
				-- PALADIN
				[GetSpellInfo(68020)] = 70, -- Seal of Command
				[GetSpellInfo(31801)] = 70, -- Seal of Vengeance
				-- ROGUE
				[GetSpellInfo(58427)] = 259, -- Overkill
				[GetSpellInfo(36554)] = 261, -- Shadowstep
				[GetSpellInfo(31223)] = 261, -- Master of Subtlety
				-- PRIEST
				[GetSpellInfo(52795)] = 256, -- Borrowed Time
				[GetSpellInfo(47788)] = 257, -- Guardian Spirit
				[GetSpellInfo(15473)] = 258, -- Shadowform
				[GetSpellInfo(15286)] = 258, -- Vampiric Embrace
				-- DEATHKNIGHT
				[GetSpellInfo(49016)] = 250, -- Hysteria
				[GetSpellInfo(53138)] = 250, -- Abomination's Might
				[GetSpellInfo(55610)] = 251, -- Imp. Icy Talons
				[GetSpellInfo(49222)] = 252, -- Bone Shield
				-- MAGE
				[GetSpellInfo(11426)] = 62, -- Ice Barrier
				[GetSpellInfo(11129)] = 63, -- Combustion
				[GetSpellInfo(31583)] = 64, -- Arcane Empowerment
				-- WARLOCK
				[GetSpellInfo(30299)] = 267, -- Nether Protection
				-- SHAMAN
				[GetSpellInfo(51470)] = 262, -- Elemental Oath
				[GetSpellInfo(30802)] = 263, -- Unleashed Rage
				[GetSpellInfo(974)] = 264, -- Earth Shield
				-- HUNTER
				[GetSpellInfo(20895)] = 253, -- Spirit Bond
				[GetSpellInfo(19506)] = 254, -- Trueshot Aura
				-- DRUID
				[GetSpellInfo(24907)] = 102, -- Moonkin Aura
				[GetSpellInfo(24932)] = 103, -- Leader of the Pack
				[GetSpellInfo(33891)] = 105, -- Tree of Life
				[GetSpellInfo(48438)] = 105 -- Wild Growth
			}
		end

		if not spellsTable then
			spellsTable = {
				-- WARRIOR
				[GetSpellInfo(12294)] = 71, -- Mortal Strike
				[GetSpellInfo(46924)] = 71, -- Bladestorm
				[GetSpellInfo(1680)] = 72, -- Whirlwind
				[GetSpellInfo(23881)] = 72, -- Bloodthirst
				[GetSpellInfo(47475)] = 72, -- Slam
				[GetSpellInfo(12809)] = 73, -- Concussion Blow
				[GetSpellInfo(47498)] = 73, -- Devastate
				-- PALADIN
				[GetSpellInfo(20473)] = 65, -- Holy Shock
				[GetSpellInfo(53563)] = 65, -- Beacon of Light
				[GetSpellInfo(31935)] = 66, -- Avenger's Shield
				[GetSpellInfo(35395)] = 70, -- Crusader Strike
				[GetSpellInfo(53385)] = 70, -- Divine Storm
				[GetSpellInfo(20066)] = 70, -- Repentance
				-- ROGUE
				[GetSpellInfo(1329)] = 259, -- Mutilate
				[GetSpellInfo(51662)] = 259, -- Hunger For Blood
				[GetSpellInfo(51690)] = 260, -- Killing Spree
				[GetSpellInfo(13877)] = 260, -- Blade Flurry
				[GetSpellInfo(13750)] = 260, -- Adrenaline Rush
				[GetSpellInfo(16511)] = 261, -- Hemorrhage
				[GetSpellInfo(51713)] = 261, -- Shadow Dance
				-- PRIEST
				[GetSpellInfo(47540)] = 256, -- Penance
				[GetSpellInfo(10060)] = 256, -- Power Infusion
				[GetSpellInfo(33206)] = 256, -- Pain Suppression
				[GetSpellInfo(34861)] = 257, -- Circle of Healing
				[GetSpellInfo(15487)] = 258, -- Silence
				[GetSpellInfo(34914)] = 258, -- Vampiric Touch
				-- DEATHKNIGHT
				[GetSpellInfo(45902)] = 250, -- Heart Strike
				[GetSpellInfo(49203)] = 251, -- Hungering Cold
				[GetSpellInfo(49143)] = 251, -- Frost Strike
				[GetSpellInfo(49184)] = 251, -- Howling Blast
				[GetSpellInfo(55090)] = 252, -- Scourge Strike
				-- MAGE
				[GetSpellInfo(44425)] = 62, -- Arcane Barrage
				[GetSpellInfo(44457)] = 63, -- Living Bomb
				[GetSpellInfo(42859)] = 63, -- Scorch
				[GetSpellInfo(31661)] = 63, -- Dragon's Breath
				[GetSpellInfo(11113)] = 63, -- Blast Wave
				[GetSpellInfo(44572)] = 64, -- Deep Freeze
				-- WARLOCK
				[GetSpellInfo(48181)] = 265, -- Haunt
				[GetSpellInfo(30108)] = 265, -- Unstable Affliction
				[GetSpellInfo(59672)] = 266, -- Metamorphosis
				[GetSpellInfo(50769)] = 267, -- Chaos Bolt
				[GetSpellInfo(30283)] = 267, -- Shadowfury
				-- SHAMAN
				[GetSpellInfo(51490)] = 262, -- Thunderstorm
				[GetSpellInfo(16166)] = 262, -- Elemental Mastery
				[GetSpellInfo(51533)] = 263, -- Feral Spirit
				[GetSpellInfo(30823)] = 263, -- Shamanistic Rage
				[GetSpellInfo(17364)] = 263, -- Stormstrike
				[GetSpellInfo(61295)] = 264, -- Riptide
				[GetSpellInfo(51886)] = 264, -- Cleanse Spirit
				-- HUNTER
				[GetSpellInfo(19577)] = 253, -- Intimidation
				[GetSpellInfo(34490)] = 254, -- Silencing Shot
				[GetSpellInfo(53209)] = 254, -- Chimera Shot
				[GetSpellInfo(53301)] = 255, -- Explosive Shot
				[GetSpellInfo(19386)] = 255, -- Wyvern Sting
				-- DRUID
				[GetSpellInfo(48505)] = 102, -- Starfall
				[GetSpellInfo(50516)] = 102, -- Typhoon
				[GetSpellInfo(33876)] = 103, -- Mangle (Cat)
				[GetSpellInfo(33878)] = 104, -- Mangle (Bear)
				[GetSpellInfo(18562)] = 105 -- Swiftmend
			}
		end
	end

	function Skada:ToggleSpecDetection(enable)
		wipe(specsCache)

		if enable then
			BuildSpellsList()
			self:RegisterEvent("UNIT_AURA")
			self:RegisterEvent("UNIT_SPELLCAST_START")
		else
			self:UnregisterEvent("UNIT_AURA")
			self:UnregisterEvent("UNIT_SPELLCAST_START")
		end
	end

	function Skada:UNIT_AURA(event, unit)
		if self.instanceType ~= "pvp" and self.instanceType ~= "arena" then
			self:UnregisterEvent("UNIT_AURA")
		elseif unit and UnitIsPlayer(unit) then
			if not specsCache[UnitGUID(unit)] then
				local i = 1
				local name = UnitBuff(unit, i)
				while name do
					if aurasTable[name] then
						specsCache[UnitGUID(unit)] = aurasTable[name]
						break
					end
					i = i + 1
					name = UnitBuff(unit, i)
				end
			end
		end
	end

	function Skada:UNIT_SPELLCAST_START(event, unit)
		if self.instanceType ~= "pvp" and self.instanceType ~= "arena" then
			self:UnregisterEvent("UNIT_SPELLCAST_START")
		elseif unit and UnitIsPlayer(unit) then
			if not specsCache[UnitGUID(unit)] then
				local spell = UnitCastingInfo(unit)
				if spell and spellsTable[spell] then
					specsCache[UnitGUID(unit)] = spellsTable[spell]
				end
			end
		end
	end

	local Skada_CheckZone = Skada.CheckZone
	function Skada:CheckZone()
		Skada_CheckZone(self)
		self:ToggleSpecDetection(self.instanceType == "pvp" or self.instanceType == "arena")
	end

	local Skada_GetEnemy = Skada.GetEnemy
	function Skada:GetEnemy(set, name, guid, flag)
		local enemy = Skada_GetEnemy(self, set, name, guid, flag)

		if
			enemy and
			enemy.class and
			Skada.validclass[enemy.class] and
			(self.instanceType == "pvp" or self.instanceType == "arena")
		then
			if enemy.spec == nil then
				enemy.spec = specsCache[enemy.id]
			end

			if enemy.spec and (enemy.role == nil or enemy.role == "NONE") then
				enemy.role = specsRoles[enemy.spec] or "DAMAGER"
			end
		end

		return enemy
	end

	---------------------------------------------------------------------------
	-- modules functions.

	function mod:Group_DamageUpdate(win, set)
		win.title = L["Damage"]

		local total = 0
		if set then
			total = set:GetDamage()
			-- in arena, we make sure to add enemies damage too.
			if set.type == "arena" and set.GetEnemyDamageDone then
				total = total + set:GetEnemyDamageDone()
			end
		end

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			-- group damage.
			for _, player in ipairs(set.players) do
				local dps, amount = player:GetDPS()
				if amount > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					if set.type == "arena" then
						d.color = set.team and teamYellow or teamGreen
					end

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Damage,
						Skada:FormatNumber(dps),
						self.metadata.columns.DPS,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			-- enemies damage.
			if set.type == "arena" and set.GetEnemyDamageDone then
				for _, enemy in ipairs(set.enemies) do
					local dps, amount = enemy:GetDPS()
					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = enemy.id or enemy.name
						d.label = enemy.name
						d.text = nil
						d.class = enemy.class
						d.role = enemy.role
						d.spec = enemy.spec
						d.color = set.team and teamGreen or teamYellow

						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							self.metadata.columns.Damage,
							Skada:FormatNumber(dps),
							self.metadata.columns.DPS,
							Skada:FormatPercent(d.value, total),
							self.metadata.columns.Percent
						)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end
		end
	end

	function mod:Group_DamageSummary(set)
		if not set then return end
		local dps, amount = set:GetDPS()

		if set.type == "arena" and set.GetEnemyDPS then
			local edps, eamount = set:GetEnemyDPS()
			dps, amount = dps + edps, amount + eamount
		end

		return Skada:FormatValueText(
			Skada:FormatNumber(amount),
			self.metadata.columns.Damage,
			Skada:FormatNumber(dps),
			self.metadata.columns.DPS
		), amount
	end

	function mod:Player_DamageSpells(win, set, parentmod)
		win.title = format(L["%s's damage"], win.playername or L.Unknown)
		local found = false -- flag to stop the rest of the code later.

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player:GetDamage() or 0

		if total > 0 and player.damagespells then
			found = true

			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for spellname, spell in pairs(player.damagespells) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellname
				d.spellid = spell.id
				d.label = spellname
				d.icon = select(3, GetSpellInfo(spell.id))
				d.spellschool = spell.school

				d.value = Skada.db.profile.absdamage and spell.total or spell.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					parentmod.metadata.columns.Damage,
					Skada:FormatPercent(d.value, total),
					parentmod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end

		if not found and set.type == "arena" then
			player = set and set:GetEnemy(win.playername, win.playerid)
			total = player and player:GetDamage() or 0

			if total > 0 and player.damagespells then
				found = true

				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for spellid, spell in pairs(player.damagespells) do
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.spellschool = spell.school
					d.label, _, d.icon = GetSpellInfo(spellid)

					d.value = Skada.db.profile.absdamage and spell.total or spell.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						parentmod.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						parentmod.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:Player_DamageTargets(win, set, parentmod)
		win.title = format(L["%s's targets"], win.playername or L.Unknown)
		local found = false

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player:GetDamage() or 0
		local targets = (total > 0) and player:GetDamageTargets()

		if targets then
			found = true

			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, target in pairs(targets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = target.id or targetname
				d.label = targetname
				d.class = target.class
				d.role = target.role
				d.spec = target.spec

				d.value = Skada.db.profile.absdamage and target.total or target.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					parentmod.metadata.columns.Damage,
					Skada:FormatPercent(d.value, total),
					parentmod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end

		if not found and set and set.type == "arena" then
			player = set and set:GetEnemy(win.playername, win.playername)
			total = player and player:GetDamage() or 0
			targets = (total > 0) and player:GetDamageTargets()

			if targets then
				found = true

				if win.metadata then
					win.metadata.maxvalue = 0
				end

				local nr = 0
				for targetname, target in pairs(targets) do
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class = target.class
					d.role = target.role
					d.spec = target.spec

					d.value = Skada.db.profile.absdamage and target.total or target.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						parentmod.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						parentmod.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:Group_HealingUpdate(win, set)
		win.title = L["Absorbs and Healing"]

		local total = 0
		if set and set.GetAbsorbHeal then
			total = set:GetAbsorbHeal()
			if set.type == "arena" and set.GetEnemyHeal then
				total = total + set:GetEnemyHeal()
			end
		end

		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0

			for _, player in ipairs(set.players) do
				local hps, amount = player:GetAHPS()

				if amount > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					if set.type == "arena" then
						d.color = set.team and teamYellow or teamGreen
					end

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Healing,
						Skada:FormatNumber(hps),
						self.metadata.columns.HPS,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end

			if set.type == "arena" and set.GetEnemyHeal then
				for _, enemy in ipairs(set.enemies) do
					local hps, amount = enemy:GetHPS()

					if amount > 0 then
						nr = nr + 1

						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = enemy.id or enemy.name
						d.label = enemy.name
						d.text = nil
						d.class = enemy.class
						d.role = enemy.role
						d.spec = enemy.spec
						d.color = set.team and teamGreen or teamYellow

						d.value = amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							self.metadata.columns.Healing,
							Skada:FormatNumber(hps),
							self.metadata.columns.HPS,
							Skada:FormatPercent(d.value, total),
							self.metadata.columns.Percent
						)

						if win.metadata and d.value > win.metadata.maxvalue then
							win.metadata.maxvalue = d.value
						end
					end
				end
			end
		end
	end

	function mod:Group_HealingSummary(set)
		if not set then return end
		local hps, amount = set:GetAHPS()

		if set.type == "arena" and set.GetEnemyHPS then
			local ehps, eamount = set:GetEnemyHPS()
			hps, amount = hps + ehps, amount + eamount
		end

		return Skada:FormatValueText(
			Skada:FormatNumber(amount),
			self.metadata.columns.Healing,
			Skada:FormatNumber(hps),
			self.metadata.columns.HPS
		), amount
	end

	function mod:OnEnable()
		-- hook to damage done
		local damage = Skada:GetModule(L["Damage"], true)
		if damage then
			damage.Update = mod.Group_DamageUpdate
			damage.GetSetSummary = mod.Group_DamageSummary

			-- spells & targets lists
			local playermod = damage:GetModule(L["Damage spell list"], true)
			if playermod then
				playermod.Update = function(_, win, set)
					mod:Player_DamageSpells(win, set, damage)
				end
			end
			local targetmod = damage:GetModule(L["Damage target list"], true)
			if targetmod then
				targetmod.Update = function(_, win, set)
					mod:Player_DamageTargets(win, set, damage)
				end
			end
		end

		local heal = Skada:GetModule(L["Absorbs and Healing"], true)
		if heal then
			heal.Update = mod.Group_HealingUpdate
			heal.GetSetSummary = mod.Group_HealingSummary
		end

		-- purple color for color blind mode.
		if GetCVar("colorblindMode") == "1" then
			teamGreen.r = 0.686
			teamGreen.g = 0.384
			teamGreen.b = 1
			teamGreen.colorStr = "ffae61ff"
		end
	end

	function mod:OnDisable()
		self:UnhookAll()
	end
end)