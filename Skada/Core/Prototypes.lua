local _, Skada = ...
local Private = Skada.Private

local pairs, max, select = pairs, math.max, select
local getmetatable, setmetatable = getmetatable, setmetatable
local new, clear = Private.newTable, Private.clearTable
local cacheTable = Skada.cacheTable

-- prototypes
local setPrototype = Skada.setPrototype
local actorPrototype = Skada.actorPrototype

-------------------------------------------------------------------------------
-- segment/set prototype & functions

-- returns the segment's time
function setPrototype:GetTime()
	return Skada:GetSetTime(self)
end

-- returns the actor's time if found (player or enemy)
function setPrototype:GetActorTime(name, id, active)
	local actor = self:GetActor(name, id)
	return actor and actor:GetTime(self, active) or self:GetTime()
end

-- attempts to find an actor (player or enemy)
function setPrototype:GetActor(name, id, no_strict)
	return Skada:FindActor(self, name, id, no_strict)
end

do
	local function calc_set_total(set, key, class, arena)
		local total = set[key] -- can be nil

		if class then
			total = nil

			local actors = set.actors
			for _, actor in pairs(actors) do
				local value = actor.class == class and (not actor.enemy or arena) and actor[key]
				if value then total = (total or 0) + value end
			end
			return total
		end

		if arena then
			key = format("e%s", key)
			if set[key] then
				total = (total or 0) + set[key]
			end
		end

		return total
	end

	-- returns the total value by given key/class
	function setPrototype:GetTotal(class, arena, ...)
		if not ... then return end
		local combined = (arena and self.type == "arena")

		local total = nil
		for i = 1, select("#", ...) do
			local key = select(i, ...)
			local value = calc_set_total(self, key, class, combined)
			if value then total = (total or 0) + value end
		end
		return total
	end
end

-- fills the give table with actor's details
function setPrototype:_fill_actor_table(t, name, actortime, no_strict)
	if t and (not t.class or (actortime and not t.time)) then
		local actor = self:GetActor(name, name, no_strict)
		if not actor then return end

		t.id = t.id or actor.id
		t.class = t.class or actor.class
		t.role = t.role or actor.role
		t.spec = t.spec or actor.spec
		t.enemy = t.enemy or actor.enemy

		-- should add time?
		if actortime then
			t.time = t.time or actor:GetTime(self)
		end

		return actor
	end
end

-- ------------------------------------
-- damage done functions
-- ------------------------------------

-- returns the set's damage amount
function setPrototype:GetDamage(class, useful)
	local absdamage = Skada.profile.absdamage
	local total = absdamage and self:GetTotal(class, true, "totaldamage") or self:GetTotal(class, true, "damage")
	if useful and total then
		local overkill = self:GetTotal(class, true, "overkill")
		if overkill then total = max(0, total - overkill) end
	end
	return total
end

-- returns set's dps and damage amount
function setPrototype:GetDPS(useful, class)
	local total = Skada.profile.absdamage and self:GetTotal(class, true, "totaldamage") or self:GetTotal(class, true, "damage")
	if total and useful then
		local overkill = self:GetTotal(class, true, "overkill")
		total = overkill and max(0, total - overkill) or total
	end
	if not total or total == 0 then
		return 0, 0
	end
	return total / self:GetTime(), total
end

-- returns the set's overkill
function setPrototype:GetOverkill(class)
	return self:GetTotal(class, true, "overkill")
end

-- returns the actor's damage amount
function setPrototype:GetActorDamage(name, id, useful)
	local actor = self:GetActor(name, id)
	return actor and actor:GetDamage(useful) or 0
end

-- returns the actor's dps and damage amount.
function setPrototype:GetActorDPS(name, id, useful, active)
	local actor = self:GetActor(name, id)
	if actor then
		return actor:GetDPS(self, useful, active)
	end
	return 0, 0
end

-- returns the actor's damage targets table if found
function setPrototype:GetActorDamageTargets(name, id, tbl)
	local actor = self:GetActor(name, id)
	if actor then
		local targets, total, overkill = actor:GetDamageTargets(self, tbl)
		return targets, total, actor, overkill
	end
end

-- ------------------------------------
-- damage taken functions
-- ------------------------------------

-- returns the set's damage taken amount
function setPrototype:GetDamageTaken(class, enemy)
	local absdamage = Skada.profile.absdamage
	if enemy then
		return absdamage and self:GetTotal(class, true, "etotaldamaged") or self:GetTotal(class, true, "edamaged")
	end
	return absdamage and self:GetTotal(class, true, "totaldamaged") or self:GetTotal(class, true, "damaged")
end

-- returns the set's dtps and damage taken amount
function setPrototype:GetDTPS(class, enemy)
	local total = self:GetDamageTaken(class, enemy)
	if not total or total == 0 then
		return 0, total
	end
	return total / self:GetTime(), total
end

-- returns the actor's damage taken sources table if found
function setPrototype:GetActorDamageSources(name, id, tbl)
	local actor = self:GetActor(name, id)
	if actor then
		local sources, total = actor:GetDamageSources(self, tbl)
		return sources, total, actor
	end
end

-- returns the damage, overkill and useful
function setPrototype:GetActorDamageFromSource(name, id, targetname)
	local actor = self:GetActor(name, id)
	if actor then
		return actor:GetDamageFromSource(targetname)
	end
	return 0, 0, 0
end

-- actor heal targets
function setPrototype:GetActorHealTargets(name, id, tbl)
	local actor = self:GetActor(name, id)
	if actor then
		local targets, total = actor:GetHealTargets(self, tbl)
		return targets, total, actor
	end
end

-- ------------------------------------
-- absorb and healing functions
-- ------------------------------------

-- returns the set's heal amount
function setPrototype:GetHeal(class, enemy)
	return self:GetTotal(class, true, enemy and "eheal" or "heal")
end

-- returns the set's hps and heal amount
function setPrototype:GetHPS(class, enemy)
	local total = self:GetTotal(class, true, enemy and "eheal" or "heal")
	if not total or total == 0 then
		return 0, 0
	end
	return total / self:GetTime(), total
end

-- returns the set's overheal amount
function setPrototype:GetOverheal(class)
	return self:GetTotal(class, true, "overheal")
end

-- returns the set's overheal per second and overheal amount
function setPrototype:GetOHPS(class)
	local total = self:GetTotal(class, true, "overheal")
	if not total or total == 0 then
		return 0, 0
	end
	return total / self:GetTime(), total
end

-- returns the set's total heal amount, including overheal amount
function setPrototype:GetTotalHeal(class)
	return self:GetTotal(class, true, "heal", "overheal")
end

-- returns the set's total hps and heal
function setPrototype:GetTHPS(class)
	local total = self:GetTotal(class, true, "heal", "overheal")
	if not total or total == 0 then
		return 0, 0
	end
	return total / self:GetTime(), total
end

-- returns the set's absorb amount
function setPrototype:GetAbsorb(class, enemy)
	return self:GetTotal(class, true, enemy and "eabsorb" or "absorb")
end

-- returns the set's absorb per second and absorb amount
function setPrototype:GetAPS(class, enemy)
	local total = self:GetTotal(class, true, enemy and "eabsorb" or "absorb")
	if not total or total == 0 then
		return 0, 0
	end
	return total / self:GetTime(), total
end

-- returns the set's amount of heal and absorb combined
function setPrototype:GetAbsorbHeal(class, enemy)
	return (self:GetHeal(class, enemy) or 0) + (self:GetAbsorb(class, enemy) or 0)
end

-- returns the set's absorb and heal per sec
function setPrototype:GetAHPS(class, enemy)
	local total = (self:GetHeal(class, enemy) or 0) + (self:GetAbsorb(class, enemy) or 0)
	if not total or total == 0 then
		return 0, 0
	end
	return total / self:GetTime(), total
end

-------------------------------------------------------------------------------
-- common actors functions

-- for better dps calculation, we use active time for Arena/BGs.
function actorPrototype:GetTime(set, active)
	return Skada:GetActiveTime(set, self, active)
end

-- calculate total for the given actor.
function actorPrototype:GetTotal(...)
	local total = nil
	for i = 1, select("#", ...) do
		local value = self[select(i, ...)]
		if value then total = (total or 0) + value end
	end
	return total
end

-- ------------------------------------
-- damage done functions
-- ------------------------------------

-- returns the actor's damage amount
function actorPrototype:GetDamage(useful)
	local total = Skada.profile.absdamage and self.totaldamage or self.damage
	if total and useful and self.overkill then
		return max(0, total - self.overkill)
	end
	return total or 0
end

-- returns the actor's dps and damage amount
function actorPrototype:GetDPS(set, useful, active, no_calc)
	local total = Skada.profile.absdamage and self.totaldamage or self.damage
	if total and useful and self.overkill then
		total = max(0, total - self.overkill)
	end
	if not total or total == 0 or no_calc then
		return 0, total or 0
	end
	return total / self:GetTime(set, active), total
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
			tbl.o_amt = info.o_amt
			t[name] = tbl
		else
			tbl.amount = tbl.amount + info.amount
			if info.total then
				tbl.total = (tbl.total or 0) + info.total
			end
			if info.o_amt then
				tbl.o_amt = (tbl.o_amt or 0) + info.o_amt
			end
		end

		set:_fill_actor_table(tbl, name)
	end

	function actorPrototype:GetDamageTargets(set, tbl)
		if not self.damagespells then
			return nil, 0, 0
		end

		local damage = Skada.profile.absdamage and self.totaldamage or self.damage
		if not damage then
			return nil, 0, 0
		end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(self.damagespells) do
			if spell.targets then
				for name, target in pairs(spell.targets) do
					fill_damage_targets_table(set, tbl, name, target)
				end
			end
		end
		return tbl, damage, self.overkill or 0
	end
end

-- returns the damage on the given target
function actorPrototype:GetDamageOnTarget(name)
	if not name or not self.damagespells then
		return 0, 0, 0
	end

	local damage, overkill, useful = 0, 0, 0
	for _, spell in pairs(self.damagespells) do
		if spell.targets and spell.targets[name] then
			-- damage
			if Skada.profile.absdamage and spell.targets[name].total then
				damage = damage + spell.targets[name].total
			elseif spell.targets[name].amount then
				damage = damage + spell.targets[name].amount
			end

			-- overkill
			if spell.targets[name].o_amt then
				overkill = overkill + spell.targets[name].o_amt
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
	return Skada.profile.absdamage and self.totaldamaged or self.damaged or 0
end

-- returns the actor's dtps and damage taken amount
function actorPrototype:GetDTPS(set, no_calc)
	local total = Skada.profile.absdamage and self.totaldamaged or self.damaged
	if not total or total == 0 or no_calc then
		return 0, total or 0
	end
	return total / self:GetTime(set), total
end

-- returns the actors damage sources
do
	local function fill_damage_sources_table(set, t, name, info)
		local tbl = t[name]
		if not tbl then
			tbl = new()
			tbl.amount = info.amount
			tbl.total = info.total
			tbl.o_amt = info.o_amt -- nil for players
			tbl.useful = info.useful -- nil for enemies
			t[name] = tbl
		else
			tbl.amount = tbl.amount + info.amount
			if info.total then
				tbl.total = (tbl.total or 0) + info.total
			end
			if info.o_amt then -- nil for players
				tbl.o_amt = (tbl.o_amt or 0) + info.o_amt
			end
			if info.useful then -- nil for enemies
				tbl.useful = (tbl.useful or 0) + info.useful
			end
		end

		set:_fill_actor_table(tbl, name)
	end

	function actorPrototype:GetDamageSources(set, tbl)
		local spells = self.damagedspells
		if not spells then return end

		local total = Skada.profile.absdamage and self.totaldamaged or self.damaged
		if not total then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(spells) do
			if spell.sources then
				for name, source in pairs(spell.sources) do
					fill_damage_sources_table(set, tbl, name, source)
				end
			end
		end
		return tbl, total
	end
end

-- returns the actors damage from the given source
function actorPrototype:GetDamageFromSource(name)
	local spells = name and self.damagedspells
	if not spells then
		return 0, 0, 0
	end

	local damage, overkill, useful = 0, 0, 0
	for _, spell in pairs(spells) do
		local source = spell.sources and spell.sources[name]
		if source then
			if source.total or source.amount then -- damage
				damage = damage + (Skada.profile.absdamage and source.total or source.amount)
			end
			if source.o_amt then -- overkill
				overkill = overkill + source.o_amt
			end
			if source.useful then -- useful
				useful = useful + source.useful
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
function actorPrototype:GetHPS(set, active, no_calc)
	local total = self.heal
	if not total or total == 0 or no_calc then
		return 0, total or 0
	end
	return total / self:GetTime(set, active), total
end

-- returns the actor's overheal amount
function actorPrototype:GetOverheal()
	return self.overheal or 0
end

-- returns the actor's overheal per second and overheal amount
function actorPrototype:GetOHPS(set, active, no_calc)
	local total = self.overheal
	if not total or total == 0 or no_calc then
		return 0, total or 0
	end
	return total / self:GetTime(set, active), total
end

-- returns the actor's total heal, including overheal
function actorPrototype:GetTotalHeal()
	local total = self.heal
	if self.overheal then
		return total and total + self.overheal or self.overheal
	end
	return total or 0
end

-- returns the actor's total hps and heal
function actorPrototype:GetTHPS(set, active, no_calc)
	local total = self.heal
	if self.overheal then
		total = total and total + self.overheal or self.overheal
	end
	if not total or total == 0 or no_calc then
		return 0, total or 0
	end
	return total / self:GetTime(set, active), total
end

-- returns the amount of heal and overheal on the given target
function actorPrototype:GetHealOnTarget(name, inc_overheal)
	local spells = name and self.healspells
	if not spells then
		return 0, inc_overheal and 0
	end

	local heal, overheal = 0, inc_overheal and 0
	for _, spell in pairs(spells) do
		local target = spell.targets and spell.targets[name]
		if target then
			heal = heal + target.amount
			if inc_overheal and target.o_amt then
				overheal = overheal + target.o_amt
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
		local o_amt = (spell.o_amt and spell.o_amt > 0) and spell.targets and spell.targets[name] and spell.targets[name].o_amt
		if o_amt then
			total = total + o_amt
		end
	end
	return total
end

-- returns the total heal amount on the given target
function actorPrototype:GetTotalHealOnTarget(name)
	local heal, overheal = self:GetHealOnTarget(name, true)
	return overheal and heal + overheal or heal
end

-- returns the actor's absorb amount
function actorPrototype:GetAbsorb()
	return self.absorb or 0
end

-- returns the actor's absorb per second and absorb amount
function actorPrototype:GetAPS(set, active, no_calc)
	local total = self.absorb
	if not total or total == 0 or no_calc then
		return 0, total or 0
	end
	return total / self:GetTime(set, active), total
end

-- returns the actor's amount of heal and absorb combined
function actorPrototype:GetAbsorbHeal()
	local total = self.heal
	if self.absorb then
		total = total and total + self.absorb
	end
	return total or 0
end

-- returns the actor's absorb and heal per sec
function actorPrototype:GetAHPS(set, active, no_calc)
	local total = self.heal
	if self.absorb then
		total = total and total + self.absorb
	end
	if not total or total == 0 or no_calc then
		return 0, total or 0
	end
	return total / self:GetTime(set, active), total
end

-- returns the amount of absorb and heal on the given target
function actorPrototype:GetAbsorbHealOnTarget(name, inc_overheal)
	if not name or not (self.absorbspells or self.healspells) then
		return 0, inc_overheal and 0 or nil
	end

	local heal, overheal = 0, inc_overheal and 0 or nil

	local spells = self.healspells -- heal spells
	if spells then
		for _, spell in pairs(spells) do
			local target = spell.targets and spell.targets[name]
			if target then
				heal = heal + target.amount
				if inc_overheal and target.o_amt then
					overheal = overheal + target.o_amt
				end
			end
		end
	end

	spells = self.absorbspells -- absorb spells
	if not spells then
		return heal, overheal
	end

	for _, spell in pairs(spells) do
		if spell.targets and spell.targets[name] then
			heal = heal + spell.targets[name]
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

		tbl.amount = (tbl.amount or 0) + info.amount
		if info.o_amt then
			tbl.o_amt = (tbl.o_amt or 0) + info.o_amt
		end

		set:_fill_actor_table(tbl, name)
	end

	-- returns the actor's absorb targets table if found
	function actorPrototype:GetAbsorbTargets(set, tbl)
		local spells = self.absorbspells
		if not spells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(spells) do
			if spell.targets then
				for name, amount in pairs(spell.targets) do
					fill_absorb_targets_table(set, tbl, name, amount)
				end
			end
		end
		return tbl
	end

	-- returns the actor's heal targets table if found
	function actorPrototype:GetHealTargets(set, tbl)
		local spells = self.healspells
		if not spells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(spells) do
			if spell.targets then
				for name, target in pairs(spell.targets) do
					fill_heal_targets_table(set, tbl, name, target)
				end
			end
		end
		return tbl, self.heal or 0
	end

	-- returns the actor's absorb and heal targets table if found
	function actorPrototype:GetAbsorbHealTargets(set, tbl)
		if not (self.healspells or self.absorbspells) then return end

		tbl = clear(tbl or cacheTable)

		local spells = self.healspells -- heal spells
		if spells then
			for _, spell in pairs(spells) do
				if spell.targets then
					for name, target in pairs(spell.targets) do
						fill_heal_targets_table(set, tbl, name, target)
					end
				end
			end
		end

		spells = self.absorbspells -- absorb spells
		if not spells then
			return tbl
		end

		for _, spell in pairs(spells) do
			if spell.targets then
				for name, amount in pairs(spell.targets) do
					fill_absorb_targets_table(set, tbl, name, amount)
				end
			end
		end
		return tbl
	end
end

-- returns the table of overheal targets if found
do
	local function fill_overheal_targets_table(set, t, name, info)
		local amt = info.o_amt
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

	function actorPrototype:GetOverhealTargets(set, tbl)
		local spells = self.overheal and self.healspells
		if not spells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(spells) do
			if spell.o_amt and spell.o_amt > 0 and spell.targets then
				for name, target in pairs(spell.targets) do
					fill_overheal_targets_table(set, tbl, name, target)
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

		tbl.amount = (tbl.amount or 0) + info.amount
		if info.o_amt then
			tbl.amount = tbl.amount + info.o_amt
		end

		set:_fill_actor_table(tbl, name)
	end

	function actorPrototype:GetTotalHealTargets(set, tbl)
		local spells = self.healspells
		if not spells then return end

		tbl = clear(tbl or cacheTable)
		for _, spell in pairs(spells) do
			if spell.targets then
				for name, target in pairs(spell.targets) do
					fill_total_heal_targets_table(set, tbl, name, target)
				end
			end
		end
		return tbl
	end
end

-------------------------------------------------------------------------------
-- display prototype & functions

do
	local displayPrototype = {}
	Skada.displayPrototype = displayPrototype

	function displayPrototype:IsShown(win)
		local frame = win and win.frame or win.bargroup
		if not frame then
			return
		elseif frame:IsShown() then
			return true, frame
		else
			return false, frame
		end
	end

	function displayPrototype:Show(win)
		local isshown, frame = self:IsShown(win)
		if isshown or not frame then return end

		frame:Show()
		if frame.SortBars then
			frame:SortBars()
		end
	end

	function displayPrototype:Hide(win)
		local isshown, frame = self:IsShown(win)
		if isshown and frame then
			frame:Hide()
		end
	end

	function displayPrototype:Wipe(win)
		if not win then
			return
		elseif win.frame then -- broker/inline
			if win.obj then -- broker
				if win.obj.text then
					win.obj.text = ""
				end
				return true
			end
			return -- inline
		elseif win.bargroup then -- bar/legacy
			win.bargroup:SetSortFunction(nil)
			win.bargroup:SetBarOffset(0)
			local bars = win.bargroup:GetBars()
			if bars then
				for _, bar in pairs(bars) do
					bar:Hide()
					win.bargroup:RemoveBar(bar)
				end
			end
			win.bargroup:SortBars()
			return true
		end
		return false
	end

	function displayPrototype:Destroy(win)
		if win and win.bargroup then -- bar/legacy
			win.bargroup:Hide()
			win.bargroup.bgframe = nil
			win.bargroup = nil
			return true
		elseif win and win.frame then -- broker/inline
			if win.obj then -- broker
				if win.obj.text then
					win.obj.text = ""
				end
				win.obj = nil
			end
			win.frame:Hide()
			win.frame = nil
			return true
		end
		return false
	end
end
