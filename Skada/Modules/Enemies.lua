assert(Skada, "Skada not found!")

local Enemies = Skada:NewModule("Enemies")
local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)

-- frequently used globals --
local pairs, ipairs, select = pairs, ipairs, select
local format, min, max = string.format, math.min, math.max
local UnitClass, GetSpellInfo = Skada.UnitClass, Skada.GetSpellInfo

do
	local function setEnemyActiveTimes(set)
		for _, e in ipairs(set.enemies or {}) do
			if e.last then
				e.time = max(e.time + (e.last - e.first), 0.1)
			end
		end
	end

	-- returns the enemy active time
	function Skada:EnemyActiveTime(set, enemy, active)
		local settime = Skada:GetSetTime(set)
		if Skada.effectivetime and not active then
			return settime
		end

		if enemy then
			local maxtime = ((enemy.time or 0) > 0) and enemy.time or 0
			if set and (not set.endtime or set.stopped) and enemy.first then
				maxtime = maxtime + (enemy.last or 0) - enemy.first
			end
			settime = min(maxtime, settime)
		end

		return settime
	end

	function Enemies:EndSegment(_, set)
		if set and not Skada.db.profile.onlykeepbosses or Skada.current.gotboss then
			if set.mobname ~= nil and time() - set.starttime > 5 then
				setEnemyActiveTimes(set)
			end
		end
	end
end

function Skada:find_enemy(set, name)
	if set and name then
		set._enemyidx = set._enemyidx or {}

		local enemy = set._enemyidx[name]
		if enemy then
			return enemy
		end

		for _, e in pairs(set.enemies) do
			if e.name == name then
				set._enemyidx[name] = e
				return e
			end
		end
	end
end

function Skada:get_enemy(set, guid, name, flags)
	if set and guid then
		local enemy = self:find_enemy(set, name)
		local now = time()

		if not enemy then
			if not name then return end
			enemy = {
				id = guid,
				name = name,
				class = select(2, UnitClass(guid, flags)),
				first = now,
				time = 0
			}
			tinsert(set.enemies, enemy)
		end

		enemy.first = enemy.first or now
		enemy.last = now
		self.changed = true
		return enemy
	end
end

function Skada:IterateEnemies(set)
	return ipairs(set and set.enemies or {})
end

local function EnemyClass(name, set)
	local class = "UNKNOWN"
	local e = Skada:find_enemy(set, name)
	if e and e.class then
		class = e.class
	end
	return class
end

function Enemies:CreateSet(_, set)
	if set and set.name == L["Current"] then
		set.enemies = set.enemies or {}
	end
end

function Enemies:ClearIndexes(_, set)
	if set then
		set._enemyidx = nil
	end
end

function Enemies:OnEnable()
	Skada.RegisterCallback(self, "SKADA_DATA_SETCREATED", "CreateSet")
	Skada.RegisterCallback(self, "SKADA_DATA_CLEARSETINDEX", "ClearIndexes")
	Skada.RegisterCallback(self, "COMBAT_PLAYER_LEAVE", "EndSegment")
end

function Enemies:OnDisable()
	Skada.UnregisterAllCallbacks(self)
end

---------------------------------------------------------------------------
-- Enemy Damage Taken

Skada:AddLoadableModule("Enemy Damage Taken", function(Skada, L)
	if Skada:IsDisabled("Enemy Damage Taken") then return end

	local mod = Skada:NewModule(L["Enemy Damage Taken"])
	local enemymod = mod:NewModule(L["Damage taken per player"])
	local spellmod = mod:NewModule(L["Damage spell details"])
	local playermod = mod:NewModule(L["Damage spell list"])
	local detailmod = mod:NewModule(L["Damage Breakdown"])

	local LBB = LibStub("LibBabble-Boss-3.0"):GetLookupTable()
	local groupName, validTarget, instanceDiff
	local valkyrsTable, valkyrMaxHP, valkyrHalfHP

	local function GetRaidDiff()
		if not instanceDiff then
			local _, instanceType, difficulty, _, _, dynamicDiff, isDynamic = GetInstanceInfo()
			if instanceType == "raid" and isDynamic then
				if difficulty == 1 or difficulty == 3 then -- 10man raid
					instanceDiff = (dynamicDiff == 0) and "10n" or ((dynamicDiff == 1) and "10h" or "unknown")
				elseif difficulty == 2 or difficulty == 4 then -- 25main raid
					instanceDiff = (dynamicDiff == 0) and "25n" or ((dynamicDiff == 1) and "25h" or "unknown")
				end
			else
				local insDiff = GetInstanceDifficulty()
				if insDiff == 1 then
					instanceDiff = "10n"
				elseif insDiff == 2 then
					instanceDiff = "25n"
				elseif insDiff == 3 then
					instanceDiff = "10h"
				elseif insDiff == 4 then
					instanceDiff = "25h"
				end
			end
		end

		return instanceDiff
	end

	local function IsValkyr(guid, skip)
		local isvalkyr = tonumber(guid) and (tonumber(guid:sub(9, 12), 16) == 36609) or false
		if isvalkyr and not skip then
			return (GetRaidDiff() == "10h" or GetRaidDiff() == "25h") or false
		end
		return isvalkyr
	end

	local function ValkyrHealthMax()
		if not valkyrMaxHP then
			local prefix, min_member, max_member = Skada:GetGroupTypeAndCount()
			for i = min_member, max_member do
				local unit = ((i == 0) and "player" or prefix .. i) .. "target"
				if UnitExists(unit) and IsValkyr(UnitGUID(unit), true) then
					valkyrMaxHP = UnitHealthMax(unit)
					valkyrHalfHP = floor(valkyrMaxHP / 2)
					return valkyrMaxHP
				end
			end

			-- fallback values
			valkyrMaxHP = (GetRaidDiff() == "25h") and 2992000 or 1417500
			valkyrHalfHP = floor(valkyrMaxHP / 2)
			return valkyrMaxHP
		end

		return valkyrMaxHP
	end

	local function log_custom_damage(set, guid, name, flags, srcGUID, srcName, spellid, spellname, spellschool, amount)
		local e = Skada:get_enemy(set, guid, name, flags)
		if e then
			e.damagetaken = e.damagetaken or {}
			e.damagetaken.amount = (e.damagetaken.amount or 0) + amount

			-- spell
			local spell = e.damagetaken.spells and e.damagetaken.spells[spellname]
			if not spell then
				e.damagetaken.spells = e.damagetaken.spells or {}
				e.damagetaken.spells[spellname] = {id = spellid, school = spellschool, amount = 0}
				spell = e.damagetaken.spells[spellname]
			end
			spell.amount = spell.amount + amount

			spell.sources = spell.sources or {}
			if not spell.sources[srcName] then
				spell.sources[srcName] = {amount = amount}
			else
				spell.sources[srcName].amount = spell.sources[srcName].amount + amount
			end

			e.damagetaken.sources = e.damagetaken.sources or {}
			if not e.damagetaken.sources[srcName] then
				e.damagetaken.sources[srcName] = {id = srcGUID, amount = amount}
			else
				e.damagetaken.sources[srcName].amount = e.damagetaken.sources[srcName].amount + amount
			end
		end
	end

	local function log_damage(set, dmg, tick)
		local enemy = Skada:get_enemy(set, dmg.enemyid, dmg.enemyname, dmg.enemyflags)
		if enemy then
			enemy.damagetaken = enemy.damagetaken or {}
			enemy.damagetaken.amount = (enemy.damagetaken.amount or 0) + dmg.amount
			set.edamagetaken = (set.edamagetaken or 0) + dmg.amount

			local spellname = dmg.spellname .. (tick and L["DoT"] or "")
			local spell = enemy.damagetaken.spells and enemy.damagetaken.spells[spellname]
			if not spell then
				enemy.damagetaken.spells = enemy.damagetaken.spells or {}
				spell = {id = dmg.spellid, school = dmg.spellschool, amount = 0, overkill = 0}
				enemy.damagetaken.spells[spellname] = spell
			elseif dmg.spellid and dmg.spellid ~= spell.id then
				if dmg.spellschool and dmg.spellschool ~= spell.school then
					spellname = spellname .. " (" .. (Skada.schoolnames[dmg.spellschool] or OTHER) .. ")"
				else
					spellname = GetSpellInfo(dmg.spellid)
				end
				if not enemy.damagetaken.spells[spellname] then
					enemy.damagetaken.spells[spellname] = {id = dmg.spellid, school = dmg.spellschool, amount = 0, overkill = 0}
				end
				spell = enemy.damagetaken.spells[spellname]
			end

			spell.amount = spell.amount + dmg.amount
			spell.overkill = spell.overkill + dmg.overkill

			if dmg.srcName and dmg.amount > 0 then
				spell.sources = spell.sources or {}
				if not spell.sources[dmg.srcName] then
					spell.sources[dmg.srcName] = {amount = dmg.amount, overkill = dmg.overkill}
				else
					spell.sources[dmg.srcName].amount = spell.sources[dmg.srcName].amount + dmg.amount
					spell.sources[dmg.srcName].overkill = spell.sources[dmg.srcName].overkill + dmg.overkill
				end

				enemy.damagetaken.sources = enemy.damagetaken.sources or {}
				if not enemy.damagetaken.sources[dmg.srcName] then
					enemy.damagetaken.sources[dmg.srcName] = {
						id = dmg.srcGUID,
						amount = dmg.amount,
						overkill = dmg.overkill
					}
				else
					enemy.damagetaken.sources[dmg.srcName].amount = enemy.damagetaken.sources[dmg.srcName].amount + dmg.amount
					enemy.damagetaken.sources[dmg.srcName].overkill = enemy.damagetaken.sources[dmg.srcName].overkill + dmg.overkill
				end

				if validTarget[dmg.enemyname] then
					-- 10h and 25h valkyrs.
					if IsValkyr(dmg.enemyid) then
						if not (valkyrsTable and valkyrsTable[dmg.enemyid]) then
							valkyrsTable = valkyrsTable or Skada:WeakTable()
							valkyrsTable[dmg.enemyid] = ValkyrHealthMax() - dmg.amount

							-- useful damage
							enemy.damagetaken.useful = (enemy.damagetaken.useful or 0) + dmg.amount
							enemy.damagetaken.sources[dmg.srcName].useful = (enemy.damagetaken.sources[dmg.srcName].useful or 0) + dmg.amount
						else
							if valkyrsTable[dmg.enemyid] <= valkyrHalfHP then
								log_custom_damage(set, dmg.enemyid, L["Valkyrs overkilling"], dmg.enemyflags, dmg.srcGUID, dmg.srcName, dmg.spellid, spellname, dmg.spellschool, dmg.amount - dmg.overkill)
								return
							end

							valkyrsTable[dmg.enemyid] = valkyrsTable[dmg.enemyid] - dmg.amount
							enemy.damagetaken.useful = (enemy.damagetaken.useful or 0) + dmg.amount
							enemy.damagetaken.sources[dmg.srcName].useful = (enemy.damagetaken.sources[dmg.srcName].useful or 0) + dmg.amount

							if valkyrsTable[dmg.enemyid] <= valkyrHalfHP then
								local amount = valkyrHalfHP - valkyrsTable[dmg.enemyid] - dmg.overkill
								log_custom_damage(set, dmg.enemyid, L["Valkyrs overkilling"], dmg.enemyflags, dmg.srcGUID, dmg.srcName, dmg.spellid, spellname, dmg.spellschool, amount)
								enemy.damagetaken.useful = enemy.damagetaken.useful - amount
								enemy.damagetaken.sources[dmg.srcName].useful =
									enemy.damagetaken.sources[dmg.srcName].useful - amount
							end
						end
					end

					local altname = groupName[validTarget[dmg.enemyname]]
					if not altname or altname == dmg.enemyname then return end
					if altname == L["Halion and Inferno"] and GetRaidDiff() ~= "25h" then return end

					local amount = (altname == L["Princes overkilling"]) and dmg.overkill or dmg.amount
					log_custom_damage(set, dmg.enemyid, altname, dmg.enemyflags, dmg.srcGUID, dmg.srcName, dmg.spellid, spellname, dmg.spellschool, amount)
				end
			end
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, amount, overkill = ...
		if srcName and dstName then
			srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)

			dmg.enemyid = dstGUID
			dmg.enemyname = dstName
			dmg.enemyflags = dstFlags
			dmg.srcGUID = srcGUID
			dmg.srcName = srcName

			dmg.spellid = spellid
			dmg.spellname = spellname
			dmg.spellschool = spellschool
			dmg.amount = amount
			dmg.overkill = overkill

			log_damage(Skada.current, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
		end
	end

	local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellDamage(nil, nil, srcGUID, srcName, nil, dstGUID, dstName, dstFlags, 6603, L["Auto Attack"], 1, ...)
	end

	local function getDTPS(set, enemy)
		local amount = enemy.damagetaken and enemy.damagetaken.amount or 0
		return amount / max(1, Skada:EnemyActiveTime(set, enemy)), amount
	end

	local function getEnemiesDTPS(set)
		return (set.edamagetaken or 0) / max(1, Skada:GetSetTime(set)), (set.edamagetaken or 0)
	end

	local function add_detail_bar(win, nr, label, value)
		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = label
		d.label = label
		d.value = value
		d.valuetext = Skada:FormatValueText(
			Skada:FormatNumber(value),
			mod.metadata.columns.Damage,
			format("%.1f%%", 100 * value / win.metadata.maxvalue),
			mod.metadata.columns.Percent
		)

		nr = nr + 1
		return nr
	end

	function detailmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's damage on %s"], label, win.targetname or UNKNOWN)
	end

	function detailmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		local enemy = Skada:find_enemy(set, win.targetname)
		if player and enemy then
			win.title = format(L["%s's damage on %s"], player.name, enemy.name)
			local total = 0

			if enemy.damagetaken and enemy.damagetaken.sources then
				total = enemy.damagetaken.sources[player.name].amount or 0
			end

			if total > 0 then
				win.metadata.maxvalue = total
				local nr = add_detail_bar(win, 1, L["Damage Done"], total)

				-- useful damage
				if (enemy.damagetaken.sources[player.name].useful or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Useful Damage"], enemy.damagetaken.sources[player.name].useful)
				elseif (enemy.damagetaken.sources[player.name].overkill or 0) > 0 then
					nr = add_detail_bar(win, nr, L["Useful Damage"], max(0, total - enemy.damagetaken.sources[player.name].overkill))
					nr = add_detail_bar(win, nr, L["Overkill"], enemy.damagetaken.sources[player.name].overkill)
				end
			end
		end
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's damage on %s"], label, win.targetname or UNKNOWN)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's damage on %s"], player.name, win.targetname or UNKNOWN)
			local total, enemy = 0, Skada:find_enemy(set, win.targetname)
			if enemy and enemy.damagetaken and enemy.damagetaken.sources and enemy.damagetaken.sources[player.name] then
				total = enemy.damagetaken.sources[player.name].amount or 0
			end

			if total > 0 and enemy.damagetaken.spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in pairs(enemy.damagetaken.spells) do
					if spell.sources and spell.sources[player.name] then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						d.icon = select(3, GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = spell.sources[player.name].amount
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							format("%.1f%%", 100 * d.value / total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function enemymod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["Damage on %s"], label)
	end

	function enemymod:Update(win, set)
		win.title = format(L["Damage on %s"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getDTPS(set, enemy)) or 0

		if total > 0 and enemy.damagetaken.sources then
			local maxvalue, nr = 0, 1

			for playername, player in pairs(enemy.damagetaken.sources) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = Skada:FormatName(playername)
				d.class, d.role, d.spec = select(2, UnitClass(player.id, nil, set))

				d.value = player.amount or 0
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
					format("%.1f%%", 100 * d.value / total),
					mod.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["Damage on %s"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["Damage on %s"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getDTPS(set, enemy)) or 0

		if total > 0 and enemy.damagetaken.spells then
			local maxvalue, nr = 0, 1

			for spellname, spell in pairs(enemy.damagetaken.spells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellname
				d.spellid = spell.id
				d.label = spellname
				d.icon = select(3, GetSpellInfo(spell.id))
				d.spellschool = spell.school

				d.value = spell.amount or 0
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
					format("%.1f%%", 100 * d.value / total),
					mod.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:Update(win, set)
		win.title = L["Enemy Damage Taken"]
		local total = select(2, getEnemiesDTPS(set))
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, enemy in ipairs(set.enemies) do
				local dtps, amount = getDTPS(set, enemy)
				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = enemy.name
					d.label = enemy.name
					d.class = enemy.class

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.Damage,
						Skada:FormatNumber(dtps),
						self.metadata.columns.DTPS,
						format("%.1f%%", 100 * amount / total),
						self.metadata.columns.Percent
					)

					if amount > maxvalue then
						maxvalue = amount
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		enemymod.metadata = {showspots = true, click1 = playermod, click2 = detailmod}
		self.metadata = {
			click1 = enemymod,
			click2 = spellmod,
			nototalclick = {enemymod, spellmod},
			columns = {Damage = true, DTPS = false, Percent = true},
			icon = "Interface\\Icons\\spell_fire_felflamebolt"
		}

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_EXTRA_ATTACKS", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {src_is_interesting = true, dst_is_not_interesting = true})

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:SetComplete(set)
		instanceDiff, valkyrsTable, valkyrMaxHP, valkyrHalfHP = nil, nil, nil, nil
	end

	function mod:OnInitialize()
		if not groupName then
			groupName = {
				[LBB["The Lich King"]] = L["Useful targets"],
				[LBB["Professor Putricide"]] = L["Oozes"],
				[LBB["Blood Prince Council"]] = L["Princes overkilling"],
				[LBB["Lady Deathwhisper"]] = L["Adds"],
				[LBB["Halion"]] = L["Halion and Inferno"]
			}
		end

		if not validTarget then
			validTarget = {
				-- The Lich King fight
				[LBB["The Lich King"]] = LBB["The Lich King"],
				[LBB["Raging Spirit"]] = LBB["The Lich King"],
				[LBB["Ice Sphere"]] = LBB["The Lich King"],
				[LBB["Val'kyr Shadowguard"]] = LBB["The Lich King"],
				[L["Wicked Spirit"]] = LBB["The Lich King"],
				-- Professor Putricide
				[L["Gas Cloud"]] = LBB["Professor Putricide"],
				[L["Volatile Ooze"]] = LBB["Professor Putricide"],
				-- Blood Prince Council
				[LBB["Prince Valanar"]] = LBB["Blood Prince Council"],
				[LBB["Prince Taldaram"]] = LBB["Blood Prince Council"],
				[LBB["Prince Keleseth"]] = LBB["Blood Prince Council"],
				-- Lady Deathwhisper
				[L["Cult Adherent"]] = LBB["Lady Deathwhisper"],
				[L["Empowered Adherent"]] = LBB["Lady Deathwhisper"],
				[L["Reanimated Adherent"]] = LBB["Lady Deathwhisper"],
				[L["Cult Fanatic"]] = LBB["Lady Deathwhisper"],
				[L["Deformed Fanatic"]] = LBB["Lady Deathwhisper"],
				[L["Reanimated Fanatic"]] = LBB["Lady Deathwhisper"],
				[L["Darnavan"]] = LBB["Lady Deathwhisper"],
				-- Halion
				[LBB["Halion"]] = LBB["Halion"],
				[L["Living Inferno"]] = LBB["Halion"]
			}
		end
	end
end)

---------------------------------------------------------------------------
-- Enemy Damage Done

Skada:AddLoadableModule("Enemy Damage Done", function(Skada, L)
	if Skada:IsDisabled("Enemy Damage Done") then return end

	local mod = Skada:NewModule(L["Enemy Damage Done"])
	local enemymod = mod:NewModule(L["Damage taken per player"])
	local spellmod = mod:NewModule(L["Damage spell list"])
	local playermod = mod:NewModule(L["Damage spell details"])

	local function log_damage(set, dmg, tick)
		local enemy = Skada:get_enemy(set, dmg.enemyid, dmg.enemyname, dmg.enemyflags)
		if enemy then
			enemy.damagedone = enemy.damagedone or {}
			enemy.damagedone.amount = (enemy.damagedone.amount or 0) + dmg.amount
			set.edamagedone = (set.edamagedone or 0) + dmg.amount

			local spellname = dmg.spellname .. (tick and L["DoT"] or "")
			local spell = enemy.damagedone.spells and enemy.damagedone.spells[spellname]
			if not spell then
				enemy.damagedone.spells = enemy.damagedone.spells or {}
				spell = {id = dmg.spellid, school = dmg.spellschool, amount = 0, overkill = 0}
				enemy.damagedone.spells[spellname] = spell
			elseif dmg.spellid and dmg.spellid ~= spell.id then
				if dmg.spellschool and dmg.spellschool ~= spell.school then
					spellname = spellname .. " (" .. (Skada.schoolnames[dmg.spellschool] or OTHER) .. ")"
				else
					spellname = GetSpellInfo(dmg.spellid)
				end
				if not enemy.damagedone.spells[spellname] then
					enemy.damagedone.spells[spellname] = {
						id = dmg.spellid,
						school = dmg.spellschool,
						amount = 0,
						overkill = 0
					}
				end
				spell = enemy.damagedone.spells[spellname]
			end

			spell.amount = spell.amount + dmg.amount

			if dmg.dstName and dmg.amount > 0 then
				spell.targets = spell.targets or {}
				spell.targets[dmg.dstName] = (spell.targets[dmg.dstName] or 0) + dmg.amount

				enemy.damagedone.targets = enemy.damagedone.targets or {}
				if not enemy.damagedone.targets[dmg.dstName] then
					enemy.damagedone.targets[dmg.dstName] = {id = dmg.dstGUID, amount = dmg.amount}
				else
					enemy.damagedone.targets[dmg.dstName].amount = enemy.damagedone.targets[dmg.dstName].amount + dmg.amount
				end
			end
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, amount = ...
		if srcName and dstName then
			dmg.enemyid = srcGUID
			dmg.enemyname = srcName
			dmg.enemyflags = srcFlags
			dmg.dstGUID = dstGUID
			dmg.dstName = dstName

			dmg.spellid = spellid
			dmg.spellname = spellname
			dmg.spellschool = spellschool
			dmg.amount = amount

			log_damage(Skada.current, dmg, eventtype == "SPELL_PERIODIC_DAMAGE")
		end
	end

	local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellDamage(nil, nil, srcGUID, srcName, nil, dstGUID, dstName, dstFlags, 6603, L["Auto Attack"], 1, ...)
	end

	local function getDPS(set, enemy)
		local amount = enemy.damagedone and enemy.damagedone.amount or 0
		return amount / max(1, Skada:EnemyActiveTime(set, enemy)), amount
	end

	local function getEnemiesDPS(set)
		return (set.edamagedone or 0) / max(1, Skada:GetSetTime(set)), (set.edamagedone or 0)
	end

	local function add_detail_bar(win, nr, label, value)
		local d = win.dataset[nr] or {}
		win.dataset[nr] = d

		d.id = label
		d.label = label
		d.value = value
		d.valuetext = Skada:FormatValueText(
			Skada:FormatNumber(value),
			mod.metadata.columns.Damage,
			format("%.1f%%", 100 * value / win.metadata.maxvalue),
			mod.metadata.columns.Percent
		)

		nr = nr + 1
		return nr
	end

	function playermod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's damage on %s"], win.targetname or UNKNOWN, label)
	end

	function playermod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's damage on %s"], win.targetname or UNKNOWN, player.name)
			local total, enemy = 0, Skada:find_enemy(set, win.targetname)
			if enemy and enemy.damagedone and enemy.damagedone.targets and enemy.damagedone.targets[player.name] then
				total = enemy.damagedone.targets[player.name].amount or 0
			end

			if total > 0 and enemy.damagedone.spells then
				local maxvalue, nr = 0, 1

				for spellname, spell in pairs(enemy.damagedone.spells) do
					if spell.targets and (spell.targets[player.name] or 0) > 0 then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = spellname
						d.spellid = spell.id
						d.label = spellname
						d.icon = select(3, GetSpellInfo(spell.id))
						d.spellschool = spell.school

						d.value = spell.targets[player.name]
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							mod.metadata.columns.Damage,
							format("%.1f%%", 100 * d.value / total),
							mod.metadata.columns.Percent
						)

						if d.value > maxvalue then
							maxvalue = d.value
						end
						nr = nr + 1
					end
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function enemymod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["Damage from %s"], label)
	end

	function enemymod:Update(win, set)
		win.title = format(L["Damage from %s"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getDPS(set, enemy)) or 0

		if total > 0 and enemy.damagedone.targets then
			local maxvalue, nr = 0, 1

			for playername, player in pairs(enemy.damagedone.targets) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = player.id
				d.label = Skada:FormatName(playername)
				d.class, d.role, d.spec = select(2, UnitClass(player.id, nil, set))

				d.value = player.amount or 0
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
					format("%.1f%%", 100 * d.value / total),
					mod.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["%s's damage"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's damage"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getDPS(set, enemy)) or 0

		if total > 0 and enemy.damagedone.spells then
			local maxvalue, nr = 0, 1

			for spellname, spell in pairs(enemy.damagedone.spells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellname
				d.spellid = spell.id
				d.label = spellname
				d.icon = select(3, GetSpellInfo(spell.id))
				d.spellschool = spell.school

				d.value = spell.amount or 0
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(d.value),
					mod.metadata.columns.Damage,
					format("%.1f%%", 100 * d.value / total),
					mod.metadata.columns.Percent
				)

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:Update(win, set)
		win.title = L["Enemy Damage Done"]
		local total = select(2, getEnemiesDPS(set))
		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, enemy in ipairs(set.enemies) do
				local dtps, amount = getDPS(set, enemy)
				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = enemy.name
					d.label = enemy.name
					d.class = enemy.class

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.Damage,
						Skada:FormatNumber(dtps),
						self.metadata.columns.DPS,
						format("%.1f%%", 100 * amount / total),
						self.metadata.columns.Percent
					)

					if amount > maxvalue then
						maxvalue = amount
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		enemymod.metadata = {showspots = true, click1 = playermod}
		self.metadata = {
			click1 = enemymod,
			click2 = spellmod,
			nototalclick = {enemymod, spellmod},
			columns = {Damage = true, DPS = false, Percent = true},
			icon = "Interface\\Icons\\spell_shadow_shadowbolt"
		}

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_EXTRA_ATTACKS", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true, src_is_not_interesting = true})

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)

---------------------------------------------------------------------------
-- Enemy Healing Done

Skada:AddLoadableModule("Enemy Healing Done", function(Skada, L)
	if Skada:IsDisabled("Enemy Healing Done") then return end

	local mod = Skada:NewModule(L["Enemy Healing Done"])
	local targetmod = mod:NewModule(L["Healed player list"])
	local spellmod = mod:NewModule(L["Healing spell list"])

	local function log_heal(set, data, tick)
		local e = Skada:get_enemy(set, data.enemyid, data.enemyname, data.enemyflags)
		if e then
			e.healing = e.healing or {}
			e.healing.amount = (e.healing.amount or 0) + data.amount
			set.ehealing = (set.ehealing or 0) + data.amount

			-- spell
			local spellname = data.spellname .. (tick and L["HoT"] or "")
			local spell = e.healing.spells and e.healing.spells[spellname]
			if not spell then
				e.healing.spells = e.healing.spells or {}
				e.healing.spells[spellname] = {id = data.spellid, school = data.spellschool, amount = data.amount}
			else
				spell.amount = spell.amount + data.amount
			end

			-- target
			if data.dstName then
				local target = e.healing.targets and e.healing.targets[data.dstName]
				if not target then
					e.healing.targets = e.healing.targets or {}
					e.healing.targets[data.dstName] = {amount = data.amount}
					e.healing.targets[data.dstName].class, e.healing.targets[data.dstName].role, e.healing.targets[data.dstName].spec = select(2, UnitClass(data.dstGUID, data.dstFlags, set))
				else
					target.amount = target.amount + data.amount
				end
			end
		end
	end

	local heal = {}

	local function SpellHeal(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		local spellid, spellname, spellschool, amount, overheal = ...

		heal.enemyid = srcGUID
		heal.enemyname = srcName
		heal.enemyflags = srcFlags

		heal.dstGUID = dstGUID
		heal.dstName = dstName
		heal.dstFlags = dstFlags

		heal.spellid = spellid
		heal.spellname = spellname
		heal.spellschool = spellschool
		heal.amount = max(0, amount - overheal)

		log_heal(Skada.current, heal, eventtype == "SPELL_PERIODIC_HEAL")
	end

	local function getHPS(set, enemy)
		local amount = enemy.healing and enemy.healing.amount or 0
		return amount / max(1, Skada:EnemyActiveTime(set, enemy)), amount
	end

	local function getEnemiesHPS(set)
		return (set.ehealing or 0) / max(1, Skada:GetSetTime(set)), (set.ehealing or 0)
	end

	function targetmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["%s's healed players"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's healed players"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getHPS(set, enemy)) or 0

		if total > 0 and enemy.healing.targets then
			local maxvalue, nr = 0, 1

			for targetname, target in pairs(enemy.healing.targets) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = targetname
				d.label = targetname
				d.class = EnemyClass(targetname, set)

				d.value = target.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(target.amount),
					mod.metadata.columns.Healing,
					format("%.1f%%", 100 * target.amount / total),
					mod.metadata.columns.Percent
				)

				if target.amount > maxvalue then
					maxvalue = target.amount
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function spellmod:Enter(win, id, label)
		win.targetname = label
		win.title = format(L["%s's healing spells"], label)
	end

	function spellmod:Update(win, set)
		win.title = format(L["%s's healing spells"], win.targetname or UNKNOWN)
		local enemy = Skada:find_enemy(set, win.targetname)
		local total = enemy and select(2, getHPS(set, enemy)) or 0

		if total > 0 and enemy.healing.spells then
			local maxvalue, nr = 0, 1

			for spellname, spell in pairs(enemy.healing.spells) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = spellname
				d.spellid = spell.id
				d.label = spellname
				d.icon = select(3, GetSpellInfo(spell.id))
				d.spellschool = spell.school

				d.value = spell.amount
				d.valuetext = Skada:FormatValueText(
					Skada:FormatNumber(spell.amount),
					mod.metadata.columns.Healing,
					format("%.1f%%", 100 * spell.amount / total),
					mod.metadata.columns.Percent
				)

				if spell.amount > maxvalue then
					maxvalue = spell.amount
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:Update(win, set)
		win.title = L["Enemy Healing Done"]
		local total = select(2, getEnemiesHPS(set))

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, enemy in ipairs(set.enemies) do
				local hps, amount = getHPS(set, enemy)
				if amount > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = enemy.id
					d.label = enemy.name
					d.class = enemy.class

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(amount),
						self.metadata.columns.Healing,
						Skada:FormatNumber(hps),
						self.metadata.columns.HPS,
						format("%.1f%%", 100 * amount / total),
						self.metadata.columns.Percent
					)

					if amount > maxvalue then
						maxvalue = amount
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			click1 = spellmod,
			click2 = targetmod,
			nototalclick = {spellmod, targetmod},
			columns = {Healing = true, HPS = false, Percent = true},
			icon = "Interface\\Icons\\spell_nature_healingtouch"
		}

		Skada:RegisterForCL(SpellHeal, "SPELL_HEAL", {src_is_not_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SpellHeal, "SPELL_PERIODIC_HEAL", {src_is_not_interesting = true, dst_is_not_interesting = true})

		Skada:AddMode(self, L["Enemies"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end
end)