local Skada = Skada

local pairs, max = pairs, math.max
local getmetatable, setmetatable = getmetatable, setmetatable
local new, clear = Skada.newTable, Skada.clearTable

-- a dummy table used as fallback
local dummyTable = {}
Skada.dummyTable = dummyTable

-- this one should be used at modules level
local cacheTable, cacheTable2 = {}, {}
Skada.cacheTable = cacheTable
Skada.cacheTable2 = cacheTable2

-- prototypes declaration
local setPrototype = {} -- sets
Skada.setPrototype = setPrototype

local actorPrototype = {} -- common to actors
actorPrototype.mt = {__index = actorPrototype}
Skada.actorPrototype = actorPrototype

local playerPrototype = setmetatable({}, actorPrototype.mt) -- players
Skada.playerPrototype = playerPrototype

local enemyPrototype = setmetatable({}, actorPrototype.mt) -- enemies
Skada.enemyPrototype = enemyPrototype

-------------------------------------------------------------------------------
-- segment/set prototype & functions

local BITMASK_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x00000010
local band, tremove = bit.band, tremove or table.remove

-- binds a set table to set prototype
function setPrototype:Bind(obj)
	if not obj or getmetatable(obj) == self then
		return obj
	end

	if obj.players then
		for i = #obj.players, 1, -1 do
			local p = obj.players[i]
			if p and p.flag and band(p.flag, BITMASK_FRIENDLY) == 0 then
				tremove(obj.players, i) -- postfix
			elseif p then
				playerPrototype:Bind(p, obj)
			end
		end
	end

	if obj.enemies then
		for i = #obj.enemies, 1, -1 do
			enemyPrototype:Bind(obj.enemies[i], obj)
		end
	end

	setmetatable(obj, self)
	self.__index = self
	return obj
end

-- returns the segment's time
function setPrototype:GetTime()
	return Skada:GetSetTime(self)
end

-- returns the actor's time if found (player or enemy)
function setPrototype:GetActorTime(id, name, active)
	local actor = self:GetActor(name, id)
	return actor and actor:GetTime(active) or self:GetTime()
end

-- attempts to retrieve a player
function setPrototype:GetPlayer(id, name)
	return Skada:FindPlayer(self, id, name, true)
end

-- attempts to retrieve an enemy
function setPrototype:GetEnemy(name, id)
	return Skada:FindEnemy(self, name, id)
end

-- attempts to find an actor (player or enemy)
function setPrototype:GetActor(name, id)
	return Skada:FindActor(self, id, name)
end

-- returns the actor's time
function setPrototype:GetActorTime(id, name, active)
	local actor = self:GetActor(name, id)
	return actor and actor:GetTime(active) or 0
end

-- fills the give table with actor's details
function setPrototype:_fill_actor_table(t, name)
	if t and not t.class then
		local actor = self:GetActor(name)
		if actor then
			t.id = actor.id
			t.class = actor.class
			t.role = actor.role
			t.spec = actor.spec
		end
		return actor
	end
end

-- ------------------------------------
-- damage done functions
-- ------------------------------------

-- returns the set's damage amount
function setPrototype:GetDamage(useful)
	local damage = 0

	-- players
	if Skada.db.profile.absdamage and self.totaldamage then
		damage = self.totaldamage
	elseif self.damage then
		damage = self.damage
	end

	if useful and self.overkill then
		damage = max(0, damage - self.overkill)
	end

	-- arena damage
	if Skada.forPVP and self.type == "arena" then
		if Skada.db.profile.absdamage and self.etotaldamage then
			damage = damage + self.etotaldamage
		elseif self.edamage then
			damage = damage + self.edamage
		end

		if useful and self.eoverkill then
			damage = max(0, damage - self.eoverkill)
		end
	end

	return damage
end

-- returns set's dps and damage amount
function setPrototype:GetDPS(useful)
	local dps, damage = 0, self:GetDamage(useful)

	if damage > 0 then
		dps = damage / self:GetTime()
	end

	return dps, damage
end

-- returns the set's overkill
function setPrototype:GetOverkill()
	local overkill = self.overkill or 0

	if Skada.forPVP and self.type == "arena" and self.eoverkill then
		overkill = overkill + self.eoverkill
	end

	return overkill
end

-- returns the actor's damage amount
function setPrototype:GetActorDamage(id, name, useful)
	local actor = self:GetActor(name, id)
	return actor and actor:GetDamage(useful) or 0
end

-- returns the actor's dps and damage amount.
function setPrototype:GetActorDPS(id, name, useful, active)
	local actor = self:GetActor(name, id)
	if actor then
		return actor:GetDPS(useful, active)
	end
	return 0, 0
end

-- returns the actor's damage spells table if found
function setPrototype:GetActorDamageSpells(id, name)
	local actor = self:GetActor(name, id)
	if actor then
		return actor.damagespells, actor
	end
end

-- returns the actor's damage targets table if found
function setPrototype:GetActorDamageTargets(id, name, tbl)
	local actor = self:GetActor(name, id)
	if actor then
		return actor:GetDamageTargets(tbl), actor
	end
end

-- returns the actor's damage on the given target
function setPrototype:GetActorDamageOnTarget(id, name, targetname)
	local actor = self:GetActor(name, id)
	if actor then
		return actor:GetDamageOnTarget(targetname)
	end
	return 0, 0, 0
end

-- ------------------------------------
-- damage taken functions
-- ------------------------------------

-- returns the set's damage taken amount
function setPrototype:GetDamageTaken()
	local damage = 0

	-- players
	if Skada.db.profile.absdamage and (self.totaldamaged or self.totaldamagetaken) then
		damage = self.totaldamaged or self.totaldamagetaken
	elseif self.damaged or self.damagetaken then
		damage = self.damaged or self.damagetaken
	end

	-- arena damage
	if Skada.forPVP and self.type == "arena" and self.GetEnemyDamageTaken then
		damage = damage + self:GetEnemyDamageTaken()
	end

	return damage
end

-- returns the set's dtps and damage taken amount
function setPrototype:GetDTPS()
	local dtps, damage = 0, self:GetDamageTaken()

	if damage > 0 then
		dtps = damage / self:GetTime()
	end

	return dtps, damage
end

-- returns the actor's damage taken amount
function setPrototype:GetActorDamageTaken(id, name)
	local actor = self:GetActor(name, id)
	return actor and actor:GetDamageTaken()
end

-- returns the actor's dtps and damage taken amount
function setPrototype:GetActorDTPS(id, name, active)
	local actor = self:GetActor(name, id)
	if actor then
		return actor:GetDTPS(active)
	end
	return 0, 0
end

-- returns the actor's damage taken spells table if found
function setPrototype:GetActorDamageTakenSpells(id, name)
	local actor = self:GetActor(name, id)
	if actor then
		return actor.damagedspells or actor.damagetakenspells
	end
end

-- returns the actor's damage taken sources table if found
function setPrototype:GetActorDamageSources(id, name, tbl)
	local actor = self:GetActor(name, id)
	if actor then
		return actor:GetDamageSources(tbl), actor
	end
end

-- returns the damage, overkill and useful
function setPrototype:GetActorDamageFromSource(id, name, targetname)
	local actor = self:GetActor(name, id)
	if actor then
		return actor:GetDamageFromSource(targetname)
	end
	return 0, 0, 0
end

-- ------------------------------------
-- absorb and healing functions
-- ------------------------------------

-- returns the set's heal amount
function setPrototype:GetHeal()
	local heal = self.heal or 0

	-- include enemies healing in arena
	if Skada.forPVP and self.type == "arena" and self.eheal then
		heal = heal + self.eheal
	end

	return heal
end

-- returns the set's hps and heal amount
function setPrototype:GetHPS()
	local heal = self:GetHeal()
	if heal > 0 then
		return heal / self:GetTime(), heal
	end
	return 0, heal
end

-- returns the set's overheal amount
function setPrototype:GetOverheal()
	local overheal = self.overheal or 0

	-- include enemies healing in arena
	if Skada.forPVP and self.type == "arena" and self.eoverheal then
		overheal = overheal + self.eoverheal
	end

	return overheal
end

-- returns the set's overheal per second and overheal amount
function setPrototype:GetOHPS()
	local overheal = self:GetOverheal()
	if overheal > 0 then
		return overheal / self:GetTime(), overheal
	end
	return 0, overheal
end

-- returns the set's total heal amount, including overheal amount
function setPrototype:GetTotalHeal()
	local heal = self.heal or 0

	if self.overheal then
		heal = heal + self.overheal
	end

	-- include enemies in arena
	if Skada.forPVP and self.type == "arena" and self.eheal then
		heal = heal + self.eheal
	end

	return heal
end

-- returns the set's total hps and heal
function setPrototype:GetTHPS()
	local heal = self:GetTotalHeal()
	if heal > 0 then
		return heal / self:GetTime(), heal
	end
	return 0, heal
end

-- returns the set's absorb amount
function setPrototype:GetAbsorb()
	local absorb = self.absorb or 0

	-- include enemies in arena
	if Skada.forPVP and self.type == "arena" and self.eabsorb then
		absorb = absorb + self.eabsorb
	end

	return absorb
end

-- returns the set's absorb per second and absorb amount
function setPrototype:GetAPS()
	local absorb = self:GetAbsorb()
	if absorb > 0 then
		return absorb / self:GetTime(), absorb
	end
	return 0, absorb
end

-- returns the set's amount of heal and absorb combined
function setPrototype:GetAbsorbHeal()
	local heal = self.heal or 0

	if self.absorb then
		heal = heal + self.absorb
	end

	-- include enemies healing in arena
	if Skada.forPVP and self.type == "arena" then
		if self.eheal then
			heal = heal + self.eheal
		end
		if self.eabsorb then
			heal = heal + self.eabsorb
		end
	end

	return heal
end

-- returns the set's absorb and heal per sec
function setPrototype:GetAHPS()
	local heal = self:GetAbsorbHeal()
	if heal > 0 then
		return heal / self:GetTime(), heal
	end
	return 0, heal
end

-------------------------------------------------------------------------------
-- common actors functions

-- binds a table to the prototype table
function actorPrototype:Bind(obj, set)
	if obj and getmetatable(obj) ~= self then
		setmetatable(obj, self)
		self.__index = self
		obj.super = set
	end
	return obj
end

-- for better dps calculation, we use active time for Arena/BGs.
function actorPrototype:GetTime(active)
	return Skada:GetActiveTime(self.super, self, active)
end

-- ------------------------------------
-- damage done functions
-- ------------------------------------

-- returns the actor's damage amount
function actorPrototype:GetDamage(useful)
	local damage = 0

	if Skada.db.profile.absdamage and self.totaldamage then
		damage = self.totaldamage
	elseif self.damage then
		damage = self.damage
	end

	if useful and self.overkill then
		damage = max(0, damage - self.overkill)
	end

	return damage
end

-- returns the actor's dps and damage amount
function actorPrototype:GetDPS(useful, active)
	local damage = self:GetDamage(useful)
	if damage > 0 then
		return damage / max(1, self:GetTime(active)), damage
	end
	return 0, damage
end

-- returns the actor's overkill
function actorPrototype:GetOverkill()
	return self.overkill or 0
end

-- returns the actor's damage targets table if found
do
	local function fill_damage_targets_table(set, t, name, info)
		local tbl = t[name]
		if not tbl then
			tbl = new()
			tbl.amount = info.amount
			tbl.total = info.total
			tbl.o_amt = info.o_amt or info.overkill
			t[name] = tbl
		else
			tbl.amount = tbl.amount + info.amount
			if info.total then
				tbl.total = (tbl.total or 0) + info.total
			end
			if info.o_amt or info.overkill then
				tbl.o_amt = (tbl.o_amt or 0) + (info.o_amt or info.overkill)
			end
		end

		set:_fill_actor_table(tbl, name)
	end

	function actorPrototype:GetDamageTargets(tbl)
		local damage = 0
		if not self.damagespells then
			return nil, damage
		elseif Skada.db.profile.absdamage and self.totaldamage then
			damage = self.totaldamage
		elseif self.damage then
			damage = self.damage
		end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(self.damagespells) do
			if spell.targets then
				for name, target in pairs(spell.targets) do
					fill_damage_targets_table(self.super, tbl, name, target)
				end
			end
		end
		return tbl, damage
	end
end

-- returns the damage on the given target
function actorPrototype:GetDamageOnTarget(name)
	local damage, overkill, useful = 0, 0, 0
	if not name or not self.damagespells then
		return damage, overkill, useful
	end

	for _, spell in pairs(self.damagespells) do
		if spell.targets and spell.targets[name] then
			-- damage
			if Skada.db.profile.absdamage and spell.targets[name].total then
				damage = damage + spell.targets[name].total
			elseif spell.targets[name].amount then
				damage = damage + spell.targets[name].amount
			end

			-- overkill
			if spell.targets[name].o_amt or spell.targets[name].overkill then
				overkill = overkill + (spell.targets[name].o_amt or spell.targets[name].overkill)
			end

			-- useful
			if spell.targets[name].useful then
				useful = useful + spell.targets[name].useful
			end
		end
	end
	return damage, overkill, useful
end

-- ------------------------------------
-- damage taken functions
-- ------------------------------------

-- returns the actor's damage taken amount
function actorPrototype:GetDamageTaken()
	if Skada.db.profile.absdamage and (self.totaldamaged or self.totaldamagetaken) then
		return self.totaldamaged or self.totaldamagetaken
	end
	return self.damaged or self.damagetaken or 0
end

-- returns the actor's dtps and damage taken amount
function actorPrototype:GetDTPS(active)
	local damage = self:GetDamageTaken()
	if damage > 0 then
		return damage / max(1, self:GetTime(active)), damage
	end
	return 0, damage
end

-- returns the actors damage sources
do
	local function fill_damage_sources_table(set, t, name, info)
		local tbl = t[name]
		if not tbl then
			tbl = new()
			tbl.amount = info.amount
			tbl.total = info.total
			tbl.o_amt = info.o_amt or info.overkill -- nil for players
			tbl.useful = info.useful -- nil for enemies
			t[name] = tbl
		else
			tbl.amount = tbl.amount + info.amount
			if info.total then
				tbl.total = (tbl.total or 0) + info.total
			end
			if info.o_amt or info.overkill then -- nil for players
				tbl.o_amt = (tbl.o_amt or 0) + (info.o_amt or info.overkill)
			end
			if info.useful then -- nil for enemies
				tbl.useful = (tbl.useful or 0) + info.useful
			end
		end

		set:_fill_actor_table(tbl, name)
	end

	function actorPrototype:GetDamageSources(tbl)
		local damage, spells = 0, self.damagedspells or self.damagetakenspells

		if not spells then
			return nil, 0
		end

		if spells then
			if Skada.db.profile.absdamage and (self.totaldamaged or self.totaldamagetaken) then
				damage = self.totaldamaged or self.totaldamagetaken
			elseif self.damaged or self.damagetaken then
				damage = self.damaged or self.damagetaken
			end

			tbl = clear(tbl or cacheTable)
			for _, spell in pairs(spells) do
				if spell.sources then
					for name, source in pairs(spell.sources) do
						fill_damage_sources_table(self.super, tbl, name, source)
					end
				end
			end
		end

		return tbl, damage
	end
end

-- returns the actors damage from the given source
function actorPrototype:GetDamageFromSource(name)
	local damage, overkill, useful = 0, 0, 0
	local spells = self.damagedspells or self.damagetakenspells

	if not name or not spells then
		return damage, overkill, useful
	end

	for _, spell in pairs(spells) do
		if spell.sources and spell.sources[name] then
			-- damage
			if Skada.db.profile.absdamage and spell.sources[name].total then
				damage = damage + spell.sources[name].total
			elseif spell.sources[name].amount then
				damage = damage + spell.sources[name].amount
			end

			-- overkill
			if spell.sources[name].o_amt or spell.sources[name].overkill then
				overkill = overkill + (spell.sources[name].o_amt or spell.sources[name].overkill)
			end

			-- useful
			if spell.sources[name].useful then
				useful = useful + spell.sources[name].useful
			end
		end
	end
	return damage, overkill, useful
end

-- ------------------------------------
-- absorb and healing functions
-- ------------------------------------

-- returns the actor' heal amount
function actorPrototype:GetHeal()
	return self.heal or 0
end

-- returns the actor's hps and heal amount
function actorPrototype:GetHPS(active)
	local heal = self.heal or 0
	if heal > 0 then
		return heal / max(1, self:GetTime(active)), heal
	end
	return 0, heal
end

-- returns the actor's overheal amount
function actorPrototype:GetOverheal()
	return self.overheal or 0
end

-- returns the actor's overheal per second and overheal amount
function actorPrototype:GetOHPS(active)
	local overheal = self.overheal or 0
	if overheal > 0 then
		return overheal / max(1, self:GetTime(active)), overheal
	end
	return 0, overheal
end

-- returns the actor's total heal, including overheal
function actorPrototype:GetTotalHeal()
	local heal = self.heal or 0

	if self.overheal then
		heal = heal + self.overheal
	end

	return heal
end

-- returns the actor's total hps and heal
function actorPrototype:GetTHPS(active)
	local heal = self:GetTotalHeal()
	if heal > 0 then
		return heal / max(1, self:GetTime(active)), heal
	end
	return 0, heal
end

-- returns the amount of heal and overheal on the given target
function actorPrototype:GetHealOnTarget(name)
	local heal, overheal = 0, 0
	if not name or not self.healspells then
		return heal, overheal
	end

	for _, spell in pairs(self.healspells) do
		if spell.targets and spell.targets[name] then
			if type(spell.targets[name]) == "number" then
				heal = heal + spell.targets[name]
			else
				heal = heal + spell.targets[name].amount
				if spell.targets[name].o_amt or spell.targets[name].overheal then
					overheal = overheal + (spell.targets[name].o_amt or spell.targets[name].overheal)
				end
			end
		end
	end
	return heal, overheal
end

-- returns the amount of overheal on the given target
function actorPrototype:GetOverhealOnTarget(name)
	if not self.overheal or not self.healspells or not name then
		return 0
	end

	local overheal = 0
	for _, spell in pairs(self.healspells) do
		if
			((spell.o_amt and spell.o_amt > 0) or (spell.overheal and spell.overheal > 0)) and
			spell.targets and
			spell.targets[name] and
			(spell.targets[name].o_amt or spell.targets[name].overheal) then
			overheal = overheal + (spell.targets[name].o_amt or spell.targets[name].overheal)
		end
	end
	return overheal
end

-- returns the total heal amount on the given target
function actorPrototype:GetTotalHealOnTarget(name)
	if not name or not self.healspells then
		return 0
	end

	local heal = 0
	for _, spell in pairs(self.healspells) do
		if spell.targets and spell.targets[name] then
			if type(spell.targets[name]) == "number" then
				heal = heal + spell.targets[name]
			else
				heal = heal + spell.targets[name].amount
				if spell.targets[name].o_amt or spell.targets[name].overheal then
					heal = heal + (spell.targets[name].o_amt or spell.targets[name].overheal)
				end
			end
		end
	end
	return heal
end

-- returns the actor's absorb amount
function actorPrototype:GetAbsorb()
	return self.absorb or 0
end

-- returns the actor's absorb per second and absorb amount
function actorPrototype:GetAPS(active)
	local absorb = self.absorb or 0
	if absorb > 0 then
		return absorb / max(1, self:GetTime(active)), absorb
	end
	return 0, absorb
end

-- returns the actor's amount of heal and absorb combined
function actorPrototype:GetAbsorbHeal()
	local heal = self.heal or 0

	if self.absorb then
		heal = heal + self.absorb
	end

	return heal
end

-- returns the actor's absorb and heal per sec
function actorPrototype:GetAHPS(active)
	local heal = self:GetAbsorbHeal()
	if heal > 0 then
		return heal / max(1, self:GetTime(active)), heal
	end
	return 0, heal
end

-- returns the amount of absorb and heal on the given target
function actorPrototype:GetAbsorbHealOnTarget(name)
	local heal, overheal = 0, 0
	if not name then
		return heal, overheal
	end

	-- absorb spells
	if self.absorbspells then
		for _, spell in pairs(self.absorbspells) do
			if spell.targets and spell.targets[name] then
				heal = heal + spell.targets[name]
			end
		end
	end

	-- heal spells
	if self.healspells then
		for _, spell in pairs(self.healspells) do
			if spell.targets and spell.targets[name] then
				if type(spell.targets[name]) == "number" then
					heal = heal + spell.targets[name]
				else
					heal = heal + spell.targets[name].amount
					if spell.targets[name].o_amt or spell.targets[name].overheal then
						overheal = overheal + (spell.targets[name].o_amt or spell.targets[name].overheal)
					end
				end
			end
		end
	end

	return heal, overheal
end

do
	local function fill_absorb_targets_table(set, t, name, amount)
		local tbl = t[name]
		if not tbl then
			tbl = new()
			tbl.amount = amount
			t[name] = tbl
		else
			tbl.amount = tbl.amount + amount
		end

		set:_fill_actor_table(tbl, name)
	end

	local function fill_heal_targets_table(set, t, name, info)
		local tbl = t[name] or new()
		t[name] = tbl

		if type(info) == "number" then
			tbl.amount = (tbl.amount or 0) + info
		else
			tbl.amount = (tbl.amount or 0) + info.amount
			if info.o_amt or info.overheal then
				tbl.o_amt = (tbl.o_amt or 0) + (info.o_amt or info.overheal)
			end
		end

		set:_fill_actor_table(tbl, name)
	end

	-- returns the actor's absorb targets table if found
	function actorPrototype:GetAbsorbTargets(tbl)
		if not self.absorbspells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(self.absorbspells) do
			if spell.targets then
				for name, amount in pairs(spell.targets) do
					fill_absorb_targets_table(self.super, tbl, name, amount)
				end
			end
		end
		return tbl
	end

	-- returns the actor's heal targets table if found
	function actorPrototype:GetHealTargets(tbl)
		if not self.healspells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(self.healspells) do
			if spell.targets then
				for name, target in pairs(spell.targets) do
					fill_heal_targets_table(self.super, tbl, name, target)
				end
			end
		end
		return tbl
	end

	-- returns the actor's absorb and heal targets table if found
	function actorPrototype:GetAbsorbHealTargets(tbl)
		if not self.healspells and not self.absorbspells then return end

		tbl = clear(tbl or cacheTable)

		-- absorb targets
		if self.absorbspells then
			for _, spell in pairs(self.absorbspells) do
				if spell.targets then
					for name, amount in pairs(spell.targets) do
						fill_absorb_targets_table(self.super, tbl, name, amount)
					end
				end
			end
		end

		-- heal targets
		if self.healspells then
			for _, spell in pairs(self.healspells) do
				if spell.targets then
					for name, target in pairs(spell.targets) do
						fill_heal_targets_table(self.super, tbl, name, target)
					end
				end
			end
		end

		return tbl
	end
end

-- returns the table of overheal targets if found
do
	local function fill_overheal_targets_table(set, t, name, info)
		local amt = info.o_amt or info.overheal
		if not amt or amt == 0 then return end

		local tbl = t[name]
		if not tbl then
			tbl = new()
			tbl.amount = amt
			tbl.total = info.amount + amt
			t[name] = tbl
		else
			tbl.amount = tbl.amount + amt
			tbl.total = tbl.total + info.amount + amt
		end

		set:_fill_actor_table(tbl, name)
	end

	function actorPrototype:GetOverhealTargets(tbl)
		if not self.overheal or not self.healspells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(self.healspells) do
			if ((spell.o_amt and spell.o_amt > 0) or (spell.overheal and spell.overheal > 0)) and spell.targets then
				for name, target in pairs(spell.targets) do
					fill_overheal_targets_table(self.super, tbl, name, target)
				end
			end
		end
		return tbl
	end
end

-- returns the total heal amount on the given target
do
	local function fill_total_heal_targets_table(set, t, name, info)
		local tbl = t[name] or new()
		t[name] = tbl

		if type(info) == "number" then
			tbl.amount = (tbl.amount or 0) + info
		else
			tbl.amount = (tbl.amount or 0) + info.amount
			if info.o_amt or info.overheal then
				tbl.amount = tbl.amount + (info.o_amt or info.overheal)
			end
		end

		set:_fill_actor_table(tbl, name)
	end

	function actorPrototype:GetTotalHealTargets(tbl)
		if not self.healspells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(self.healspells) do
			if spell.targets then
				for name, target in pairs(spell.targets) do
					fill_total_heal_targets_table(self.super, tbl, name, target)
				end
			end
		end
		return tbl
	end
end
