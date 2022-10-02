local _, Skada = ...
local private = Skada.private

local pairs, max, select = pairs, math.max, select
local getmetatable, setmetatable = getmetatable, setmetatable
local new, clear = private.newTable, private.clearTable

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

local band, tremove = bit.band, tremove or table.remove
local BITMASK_FRIENDLY = private.BITMASK_FRIENDLY or 0x00000010

-- binds a set table to set prototype
function setPrototype:Bind(obj)
	if not obj then
		return
	elseif getmetatable(obj) == self then
		self.__arena = (Skada.forPVP and obj.type == "arena")
		return obj
	end

	local actors = obj.players -- players
	if actors then
		for i = #actors, 1, -1 do
			local p = actors[i]
			if p and p.flag and band(p.flag, BITMASK_FRIENDLY) == 0 then
				tremove(actors, i) -- postfix
			elseif p then
				playerPrototype:Bind(p, obj)
			end
		end
	end

	actors = obj.enemies -- enemies
	if actors then
		for i = #actors, 1, -1 do
			enemyPrototype:Bind(actors[i], obj)
		end
	end

	setmetatable(obj, self)
	self.__index = self
	self.__arena = (Skada.forPVP and obj.type == "arena")
	return obj
end

-- returns the segment's time
function setPrototype:GetTime(active)
	return Skada:GetSetTime(self, active)
end

-- returns the actor's time if found (player or enemy)
function setPrototype:GetActorTime(id, name, active)
	local actor = self:GetActor(name, id)
	return actor and actor:GetTime(active) or self:GetTime(active)
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
function setPrototype:GetActor(name, id, no_strict)
	return Skada:FindActor(self, id, name, no_strict)
end

-- returns the actor's time
function setPrototype:GetActorTime(id, name, active)
	local actor = self:GetActor(name, id)
	return actor and actor:GetTime(active) or 0
end

do
	local function calc_set_total(set, key, class, arena)
		local total = set[key] or 0

		if class then
			total = 0

			local actors = set.players -- players
			for i = 1, #actors do
				local actor = actors[i]
				if actor and actor.class == class and actor[key] then
					total = total + actor[key]
				end
			end

			actors = arena and set.enemies or nil -- arena enemies
			if actors then
				for i = 1, #actors do
					local actor = actors[i]
					if actor and actor.class == class and actor[key] then
						total = total + actor[key]
					end
				end
			end
		elseif arena and set["e" .. key] then
			total = total + set["e" .. key]
		end

		return total
	end

	-- returns the total value by given key/class
	function setPrototype:GetTotal(class, arena, ...)
		if not ... then return end
		local __arena = (arena and self.__arena)

		local total = 0
		for i = 1, select("#", ...) do
			local key = select(i, ...)
			total = total + calc_set_total(self, key, class, __arena)
		end
		return total
	end
end

-- fills the give table with actor's details
function setPrototype:_fill_actor_table(t, name, actortime, no_strict)
	if t and (not t.class or (actortime and not t.time)) then
		local actor = self:GetActor(name, nil, no_strict)
		if not actor then return end

		t.id = t.id or actor.id
		t.class = t.class or actor.class
		t.role = t.role or actor.role
		t.spec = t.spec or actor.spec

		-- should add time?
		if actortime then
			t.time = t.time or actor:GetTime()
		end

		return actor
	end
end

-- ------------------------------------
-- damage done functions
-- ------------------------------------

-- returns the set's damage amount
function setPrototype:GetDamage(useful, class)
	local inc_absorbed = Skada.db.profile.absdamage
	local total = self:GetTotal(class, true, inc_absorbed and "totaldamage" or "damage")
	if useful then
		local overkill = self:GetTotal(class, true, "overkill")
		if overkill then
			total = max(0, total - overkill)
		end
	end
	return total
end

-- returns set's dps and damage amount
function setPrototype:GetDPS(useful, class)
	local total = self:GetDamage(useful, class)
	if total == 0 then
		return 0, total
	end

	return total / self:GetTime(), total
end

-- returns the set's overkill
function setPrototype:GetOverkill(class)
	return self:GetTotal(class, true, "overkill")
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
function setPrototype:GetDamageTaken(class)
	local inc_absorbed = Skada.db.profile.absdamage
	local key = (inc_absorbed and "total" or "") .. (self.damagetaken and "damagetaken" or "damaged")
	return self:GetTotal(class, true, key)
end

-- returns the set's dtps and damage taken amount
function setPrototype:GetDTPS(class)
	local total = self:GetDamageTaken(class)
	if total == 0 then
		return 0, total
	end

	return total / self:GetTime(), total
end

-- returns the actor's damage taken amount
function setPrototype:GetActorDamageTaken(id, name)
	local actor = self:GetActor(name, id)
	return actor and actor:GetDamageTaken()
end

-- returns the actor's dtps and damage taken amount
function setPrototype:GetActorDTPS(id, name)
	local actor = self:GetActor(name, id)
	if actor then
		return actor:GetDTPS()
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
function setPrototype:GetHeal(class)
	return self:GetTotal(class, true, "heal")
end

-- returns the set's hps and heal amount
function setPrototype:GetHPS(class)
	local total = self:GetHeal(class)
	if total == 0 then
		return 0, total
	end

	return total / self:GetTime(), total
end

-- returns the set's overheal amount
function setPrototype:GetOverheal(class)
	return self:GetTotal(class, true, "overheal")
end

-- returns the set's overheal per second and overheal amount
function setPrototype:GetOHPS(class)
	local total = self:GetOverheal(class)
	if total == 0 then
		return 0, total
	end

	return total / self:GetTime(), total
end

-- returns the set's total heal amount, including overheal amount
function setPrototype:GetTotalHeal(class)
	return self:GetTotal(class, true, "heal", "overheal")
end

-- returns the set's total hps and heal
function setPrototype:GetTHPS(class)
	local total = self:GetTotalHeal(class)
	if total == 0 then
		return 0, total
	end

	return total / self:GetTime(), total
end

-- returns the set's absorb amount
function setPrototype:GetAbsorb(class)
	return self:GetTotal(class, true, "absorb")
end

-- returns the set's absorb per second and absorb amount
function setPrototype:GetAPS(class)
	local total = self:GetAbsorb(class)
	if total == 0 then
		return 0, total
	end

	return total / self:GetTime(), total
end

-- returns the set's amount of heal and absorb combined
function setPrototype:GetAbsorbHeal(class)
	return (self:GetHeal(class) or 0) + (self:GetAbsorb(class) or 0)
end

-- returns the set's absorb and heal per sec
function setPrototype:GetAHPS(class)
	local total = self:GetAbsorbHeal(class)
	if total == 0 then
		return 0, total
	end

	return total / self:GetTime(), total
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
	local total = 0

	if Skada.db.profile.absdamage and self.totaldamage then
		total = self.totaldamage
	elseif self.damage then
		total = self.damage
	end

	if useful and self.overkill then
		total = max(0, total - self.overkill)
	end

	return total
end

-- returns the actor's dps and damage amount
function actorPrototype:GetDPS(useful, active, no_calc)
	local total = self:GetDamage(useful)
	if total == 0 or no_calc then
		return 0, total
	end

	return total / self:GetTime(active), total
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
function actorPrototype:GetDTPS(no_calc)
	local total = self:GetDamageTaken()
	if total == 0 or no_calc then
		return 0, total
	end

	return total / self:GetTime(), total
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
		local spells = self.damagedspells or self.damagetakenspells
		if not spells then return end

		local total = 0
		if Skada.db.profile.absdamage and (self.totaldamaged or self.totaldamagetaken) then
			total = self.totaldamaged or self.totaldamagetaken
		elseif self.damaged or self.damagetaken then
			total = self.damaged or self.damagetaken
		end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(spells) do
			if spell.sources then
				for name, source in pairs(spell.sources) do
					fill_damage_sources_table(self.super, tbl, name, source)
				end
			end
		end

		return tbl, total
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
function actorPrototype:GetHPS(active, no_calc)
	local total = self.heal or 0
	if total == 0 or no_calc then
		return 0, total
	end

	return total / self:GetTime(active), total
end

-- returns the actor's overheal amount
function actorPrototype:GetOverheal()
	return self.overheal or 0
end

-- returns the actor's overheal per second and overheal amount
function actorPrototype:GetOHPS(active, no_calc)
	local total = self.overheal or 0
	if total == 0 or no_calc then
		return 0, total
	end

	return total / self:GetTime(active), total
end

-- returns the actor's total heal, including overheal
function actorPrototype:GetTotalHeal()
	local total = self.heal or 0

	if self.overheal then
		total = total + self.overheal
	end

	return total
end

-- returns the actor's total hps and heal
function actorPrototype:GetTHPS(active, no_calc)
	local total = self:GetTotalHeal()
	if total == 0 or no_calc then
		return 0, total
	end

	return total / self:GetTime(active), total
end

-- returns the amount of heal and overheal on the given target
function actorPrototype:GetHealOnTarget(name, inc_overheal)
	local spells = name and self.healspells
	if not spells and inc_overheal then
		return 0, 0
	elseif not spells then
		return 0
	end

	local heal = 0
	local overheal = inc_overheal and 0 or nil

	for _, spell in pairs(spells) do
		local target = spell.targets and spell.targets[name]
		if type(target) == "number" then
			heal = heal + target
		elseif target then
			heal = heal + target.amount
			if inc_overheal and (target.o_amt or target.overheal) then
				overheal = overheal + (target.o_amt or target.overheal)
			end
		end
	end

	return heal, overheal
end

-- returns the amount of overheal on the given target
function actorPrototype:GetOverhealOnTarget(name)
	local spells = self.overheal and name and self.healspells
	if not spells then
		return 0
	end

	local total = 0
	for _, spell in pairs(spells) do
		local o_amt = spell.o_amt or spell.overheal
		o_amt = (o_amt and o_amt > 0) and spell.targets and spell.targets[name] and (spell.targets[name].o_amt or spell.targets[name].overheal)
		if o_amt then
			total = total + o_amt
		end
	end
	return total
end

-- returns the total heal amount on the given target
function actorPrototype:GetTotalHealOnTarget(name)
	local spells = name and self.healspells
	if not spells then
		return 0
	end

	local total = 0
	for _, spell in pairs(spells) do
		local target = spell.targets and spell.targets[name]
		if type(target) == "number" then
			total = total + target
		elseif target then
			total = total + target.amount
			if target.o_amt or target.overheal then
				total = total + (target.o_amt or target.overheal)
			end
		end
	end

	return total
end

-- returns the actor's absorb amount
function actorPrototype:GetAbsorb()
	return self.absorb or 0
end

-- returns the actor's absorb per second and absorb amount
function actorPrototype:GetAPS(active, no_calc)
	local total = self.absorb or 0
	if total == 0 or no_calc then
		return 0, total
	end

	return total / self:GetTime(active), total
end

-- returns the actor's amount of heal and absorb combined
function actorPrototype:GetAbsorbHeal()
	local total = self.heal or 0
	if not self.absorb then
		return total
	end

	total = total + self.absorb
	return total
end

-- returns the actor's absorb and heal per sec
function actorPrototype:GetAHPS(active, no_calc)
	local total = self:GetAbsorbHeal()
	if total == 0 or no_calc then
		return 0, total
	end

	return total / self:GetTime(active), total
end

-- returns the amount of absorb and heal on the given target
function actorPrototype:GetAbsorbHealOnTarget(name, inc_overheal)
	if not name or not (self.absorbspells or self.healspells) then
		return 0, inc_overheal and 0 or nil
	end

	local heal = 0
	local overheal = inc_overheal and 0 or nil

	local spells = self.absorbspells -- absorb spells
	if spells then
		for _, spell in pairs(spells) do
			if spell.targets and spell.targets[name] then
				heal = heal + spell.targets[name]
			end
		end
	end

	spells = self.healspells -- heal spells
	if spells then
		for _, spell in pairs(spells) do
			local target = spell.targets and spell.targets[name]
			if type(target) == "number" then
				heal = heal + target
			elseif target then
				heal = heal + target.amount
				if inc_overheal and (target.o_amt or target.overheal) then
					overheal = overheal + (target.o_amt or target.overheal)
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
		local spells = self.absorbspells
		if not spells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(spells) do
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
		local spells = self.healspells
		if not spells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(spells) do
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
		if not (self.healspells or self.absorbspells) then return end

		tbl = clear(tbl or cacheTable)

		local spells = self.absorbspells -- absorb spells
		if spells then
			for _, spell in pairs(spells) do
				if spell.targets then
					for name, amount in pairs(spell.targets) do
						fill_absorb_targets_table(self.super, tbl, name, amount)
					end
				end
			end
		end

		spells = self.healspells -- heal spells
		if spells then
			for _, spell in pairs(spells) do
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
		local spells = self.overheal and self.healspells
		if not spells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(spells) do
			local o_amt = spell.o_amt or spell.overheal
			if o_amt and o_amt > 0 and spell.targets then
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
		local spells = self.healspells
		if not spells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(spells) do
			if spell.targets then
				for name, target in pairs(spell.targets) do
					fill_total_heal_targets_table(self.super, tbl, name, target)
				end
			end
		end
		return tbl
	end
end
