local Skada = Skada

local pairs, wipe, max = pairs, wipe, math.max
local getmetatable, setmetatable, time = getmetatable, setmetatable, time

-- a dummy table used as fallback
local dummyTable = {}
Skada.dummyTable = dummyTable

-- this one should be used at modules level
local T = Skada.Table
local cacheTable = T.get("Skada_CacheTable")
Skada.cacheTable = cacheTable

-- prototypes declaration
local setPrototype = {} -- sets
Skada.setPrototype = setPrototype

local actorPrototype = {} -- common to actors
local actorPrototype_mt = {__index = actorPrototype}
Skada.actorPrototype = actorPrototype

local playerPrototype = setmetatable({}, actorPrototype_mt) -- players
Skada.playerPrototype = playerPrototype

local enemyPrototype = setmetatable({}, actorPrototype_mt) -- enemies
Skada.enemyPrototype = enemyPrototype

-------------------------------------------------------------------------------
-- segment/set prototype & functions

-- binds a set table to set prototype
function setPrototype:Bind(obj)
	if obj and getmetatable(obj) ~= self then
		setmetatable(obj, self)
		self.__index = self

		if obj.players then
			for i = 1, #obj.players do
				playerPrototype:Bind(obj.players[i], obj)
			end
		end

		if obj.enemies then
			for i = 1, #obj.enemies do
				enemyPrototype:Bind(obj.enemies[i], obj)
			end
		end
	end
	return obj
end

-- returns the segment's time
function setPrototype:GetTime()
	return max((self.time and self.time > 0) and self.time or (time() - self.starttime), 0.1)
end

-- returns the actor's time if found (player or enemy)
function setPrototype:GetActorTime(id, name, active)
	local actor = self:GetActor(name, id)
	return actor and actor:GetTime(active) or self:GetTime()
end

-- attempts to retrieve a player
function setPrototype:GetPlayer(id, name)
	if self.players and ((id and id ~= "total") or name) then
		for i = 1, #self.players do
			local actor = self.players[i]
			if actor and ((id and actor.id == id) or (name and actor.name == name)) then
				return playerPrototype:Bind(actor, self)
			end
		end
	end

	-- couldn't be found, rely on skada.
	local actor = Skada:FindPlayer(self, id, name, true)
	return actor and playerPrototype:Bind(actor, self)
end

-- attempts to retrieve an enemy
function setPrototype:GetEnemy(name, id)
	if self.enemies and name then
		for i = 1, #self.enemies do
			local actor = self.enemies[i]
			if actor and ((name and actor.name == name) or (id and actor.id == id)) then
				return enemyPrototype:Bind(actor, self)
			end
		end
	end

	-- couldn't be found, rely on skada.
	local actor = Skada:FindEnemy(self, name, id)
	return actor and enemyPrototype:Bind(actor, self)
end

-- attempts to find an actor (player or enemy)
function setPrototype:GetActor(name, id)
	-- player first.
	if self.players and ((id and id ~= "total") or name) then
		for i = 1, #self.players do
			local actor = self.players[i]
			if actor and ((id and actor.id == id) or (name and actor.name == name)) then
				return playerPrototype:Bind(actor, self)
			end
		end
	end

	-- enemy second
	if self.enemies and name then
		for i = 1, #self.enemies do
			local actor = self.enemies[i]
			if actor and ((name and actor.name == name) or (id and actor.id == id)) then
				return enemyPrototype:Bind(actor, self), true
			end
		end
	end

	-- couldn't be found, rely on skada.
	return Skada:FindActor(self, id, name)
end

-- returns the actor's time
function setPrototype:GetActorTime(id, name, active)
	local actor = self:GetActor(name, id)
	return actor and actor:GetTime(active) or 0
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
		dps = damage / max(1, self:GetTime())
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
	if Skada.db.profile.absdamage and self.totaldamagetaken then
		damage = self.totaldamagetaken
	elseif self.damagetaken then
		damage = self.damagetaken
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
		dtps = damage / max(1, self:GetTime())
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
	return actor and actor.damagetakenspells
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
		return heal / max(1, self:GetTime()), heal
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
		return overheal / max(1, self:GetTime()), overheal
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
		return heal / max(1, self:GetTime()), heal
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
		return absorb / max(1, self:GetTime()), absorb
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
		return heal / max(1, self:GetTime()), heal
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
	active = active or (self.super.type == "pvp") or (self.super.type == "arena")
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
function actorPrototype:GetDamageTargets(tbl)
	if self.damagespells then
		tbl = wipe(tbl or cacheTable)

		for _, spell in pairs(self.damagespells) do
			if spell.targets then
				for name, tar in pairs(spell.targets) do
					if not tbl[name] then
						tbl[name] = {amount = tar.amount, total = tar.total, overkill = tar.overkill}
					else
						tbl[name].amount = tbl[name].amount + tar.amount
						if tar.total then
							tbl[name].total = (tbl[name].total or 0) + tar.total
						end
						if tar.overkill then
							tbl[name].overkill = (tbl[name].overkill or 0) + tar.overkill
						end
					end

					-- attempt to get actor details
					if not tbl[name].class then
						local actor = self.super:GetActor(name)
						if actor then
							tbl[name].id = actor.id
							tbl[name].class = actor.class
							tbl[name].role = actor.role
							tbl[name].spec = actor.spec
						end
					end
				end
			end
		end
	end

	return tbl
end

-- returns the damage on the given target
function actorPrototype:GetDamageOnTarget(name)
	local damage, overkill, useful = 0, 0, 0

	if self.damagespells and name then
		for _, spell in pairs(self.damagespells) do
			if spell.targets and spell.targets[name] then
				-- damage
				if Skada.db.profile.absdamage and spell.targets[name].total then
					damage = damage + spell.targets[name].total
				elseif spell.targets[name].amount then
					damage = damage + spell.targets[name].amount
				end

				-- overkill
				if spell.targets[name].overkill then
					overkill = overkill + spell.targets[name].overkill
				end

				-- useful
				if spell.targets[name].useful then
					useful = useful + spell.targets[name].useful
				end
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
	if Skada.db.profile.absdamage and self.totaldamagetaken then
		return self.totaldamagetaken
	end
	return self.damagetaken or 0
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
function actorPrototype:GetDamageSources(tbl)
	if self.damagetakenspells then
		tbl = wipe(tbl or cacheTable)

		for _, spell in pairs(self.damagetakenspells) do
			if spell.sources then
				for name, source in pairs(spell.sources) do
					if not tbl[name] then
						tbl[name] = {
							amount = source.amount,
							total = source.total,
							overkill = source.overkill, -- nil for players
							useful = source.useful, -- nil for enemies
						}
					else
						tbl[name].amount = tbl[name].amount + source.amount
						if source.total then
							tbl[name].total = (tbl[name].total or 0) + source.total
						end
						if source.overkill then -- nil for players
							tbl[name].overkill = (tbl[name].overkill or 0) + source.overkill
						end
						if source.useful then -- nil for enemies
							tbl[name].useful = (tbl[name].useful or 0) + source.useful
						end
					end

					-- attempt to get actor details
					if not tbl[name].class then
						local actor = self.super:GetActor(name)
						if actor then
							tbl[name].id = actor.id
							tbl[name].class = actor.class
							tbl[name].role = actor.role
							tbl[name].spec = actor.spec
						end
					end
				end
			end
		end
	end

	return tbl
end

-- returns the actors damage from the given source
function actorPrototype:GetDamageFromSource(name)
	local damage, overkill, useful = 0, 0, 0

	if self.damagetakenspells and name then
		for _, spell in pairs(self.damagetakenspells) do
			if spell.sources and spell.sources[name] then
				-- damage
				if Skada.db.profile.absdamage and spell.sources[name].total then
					damage = damage + spell.sources[name].total
				elseif spell.sources[name].amount then
					damage = damage + spell.sources[name].amount
				end

				-- overkill
				if spell.sources[name].overkill then
					overkill = overkill + spell.sources[name].overkill
				end

				-- useful
				if spell.sources[name].useful then
					useful = useful + spell.sources[name].useful
				end
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

-- returns the actor's heal targets table if found
function actorPrototype:GetHealTargets(tbl)
	if self.healspells then
		tbl = wipe(tbl or cacheTable)

		for _, spell in pairs(self.healspells) do
			if spell.targets then
				for name, target in pairs(spell.targets) do
					if type(target) == "number" then
						if not tbl[name] then
							tbl[name] = {amount = target}
						else
							tbl[name].amount = tbl[name].amount + target
						end
					else
						if not tbl[name] then
							tbl[name] = {amount = target.amount, overheal = target.overheal}
						else
							tbl[name].amount = tbl[name].amount + target.amount
							if target.overheal then
								tbl[name].overheal = (tbl[name].overheal or 0) + target.overheal
							end
						end
					end

					-- attempt to get actor details
					if not tbl[name].class then
						local actor = self.super:GetActor(name)
						if actor then
							tbl[name].id = actor.id
							tbl[name].class = actor.class
							tbl[name].role = actor.role
							tbl[name].spec = actor.spec
						end
					end
				end
			end
		end
	end

	return tbl
end

-- returns the amount of heal and overheal on the given target
function actorPrototype:GetHealOnTarget(name)
	local heal, overheal = 0, 0

	if self.healspells and name then
		for _, spell in pairs(self.healspells) do
			if spell.targets and spell.targets[name] then
				if type(spell.targets[name]) == "number" then
					heal = heal + spell.targets[name]
				else
					heal = heal + spell.targets[name].amount
					if spell.targets[name].overheal then
						overheal = overheal + spell.targets[name].overheal
					end
				end
			end
		end
	end

	return heal, overheal
end

-- returns the table of overheal targets if found
function actorPrototype:GetOverhealTargets(tbl)
	if self.overheal and self.healspells then
		tbl = wipe(tbl or cacheTable)

		for _, spell in pairs(self.healspells) do
			if spell.overheal and spell.overheal > 0 and spell.targets then
				for name, target in pairs(spell.targets) do
					if target.overheal and target.overheal > 0 then
						if not tbl[name] then
							tbl[name] = {amount = target.overheal, total = target.amount + target.overheal}
						else
							tbl[name].amount = tbl[name].amount + target.overheal
							tbl[name].total = tbl[name].total + target.amount + target.overheal
						end

						-- attempt to get actor details
						if not tbl[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								tbl[name].id = actor.id
								tbl[name].class = actor.class
								tbl[name].role = actor.role
								tbl[name].spec = actor.spec
							end
						end
					end
				end
			end
		end
	end

	return tbl
end

-- returns the amount of overheal on the given target
function actorPrototype:GetOverhealOnTarget(name)
	local overheal = 0

	if self.overheal and self.healspells and name then
		for _, spell in pairs(self.healspells) do
			if spell.overheal and spell.overheal > 0 and spell.targets and spell.targets[name] and spell.targets[name].overheal then
				overheal = overheal + spell.targets[name].overheal
			end
		end
	end

	return overheal
end

-- returns the total heal amount on the given target
function actorPrototype:GetTotalHealTargets(tbl)
	if self.healspells then
		tbl = wipe(tbl or cacheTable)

		for _, spell in pairs(self.healspells) do
			if spell.targets then
				for name, target in pairs(spell.targets) do
					if type(target) == "number" then
						if not tbl[name] then
							tbl[name] = {amount = target}
						else
							tbl[name].amount = tbl[name].amount + target
						end
					else
						if not tbl[name] then
							tbl[name] = {amount = target.amount + target.overheal}
						else
							tbl[name].amount = tbl[name].amount + target.amount + target.overheal
						end
					end

					-- attempt to get actor details
					if not tbl[name].class then
						local actor = self.super:GetActor(name)
						if actor then
							tbl[name].id = actor.id
							tbl[name].class = actor.class
							tbl[name].role = actor.role
							tbl[name].spec = actor.spec
						end
					end
				end
			end
		end
	end

	return tbl
end

-- returns the total heal amount on the given target
function actorPrototype:GetTotalHealOnTarget(name)
	local heal = 0

	if self.healspells and name then
		for _, spell in pairs(self.healspells) do
			if spell.targets and spell.targets[name] then
				if type(spell.targets[name]) == "number" then
					heal = heal + spell.targets[name]
				else
					heal = heal + spell.targets[name].amount + spell.targets[name].overheal
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

-- returns the actor's absorb targets table if found
function actorPrototype:GetAbsorbTargets(tbl)
	if self.absorbspells then
		tbl = wipe(tbl or cacheTable)

		for _, spell in pairs(self.absorbspells) do
			if spell.targets then
				for name, amount in pairs(spell.targets) do
					if not tbl[name] then
						tbl[name] = {amount = amount}
					else
						tbl[name].amount = tbl[name].amount + amount
					end

					-- attempt to get actor details
					if not tbl[name].class then
						local actor = self.super:GetActor(name)
						if actor then
							tbl[name].id = actor.id
							tbl[name].class = actor.class
							tbl[name].role = actor.role
							tbl[name].spec = actor.spec
						end
					end
				end
			end
		end
	end

	return tbl
end

-- returns the actor's absorb and heal targets table if found
function actorPrototype:GetAbsorbHealTargets(tbl)
	if self.healspells or self.absorbspells then
		tbl = wipe(tbl or cacheTable)

		-- absorb targets
		if self.absorbspells then
			for _, spell in pairs(self.absorbspells) do
				if spell.targets then
					for name, amount in pairs(spell.targets) do
						if not tbl[name] then
							tbl[name] = {amount = amount}
						else
							tbl[name].amount = tbl[name].amount + amount
						end

						-- attempt to get actor details
						if not tbl[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								tbl[name].id = actor.id
								tbl[name].class = actor.class
								tbl[name].role = actor.role
								tbl[name].spec = actor.spec
							end
						end
					end
				end
			end
		end

		-- heal targets
		if self.healspells then
			for _, spell in pairs(self.healspells) do
				if spell.targets then
					for name, target in pairs(spell.targets) do
						if type(target) == "number" then
							if not tbl[name] then
								tbl[name] = {amount = target}
							else
								tbl[name].amount = tbl[name].amount + target
							end
						else
							if not tbl[name] then
								tbl[name] = {amount = target.amount, overheal = target.overheal}
							else
								tbl[name].amount = tbl[name].amount + target.amount
								if target.overheal then
									tbl[name].overheal = (tbl[name].overheal or 0) + target.overheal
								end
							end
						end

						-- attempt to get actor details
						if not tbl[name].class then
							local actor = self.super:GetActor(name)
							if actor then
								tbl[name].id = actor.id
								tbl[name].class = actor.class
								tbl[name].role = actor.role
								tbl[name].spec = actor.spec
							end
						end
					end
				end
			end
		end
	end

	return tbl
end

-- returns the amount of absorb and heal on the given target
function actorPrototype:GetAbsorbHealOnTarget(name)
	local heal, overheal = 0, 0

	-- absorb spells
	if name and self.absorbspells then
		for _, spell in pairs(self.absorbspells) do
			if spell.targets and spell.targets[name] then
				heal = heal + spell.targets[name]
			end
		end
	end

	-- heal spells
	if self.healspells and name then
		for _, spell in pairs(self.healspells) do
			if spell.targets and spell.targets[name] then
				if type(spell.targets[name]) == "number" then
					heal = heal + spell.targets[name]
				else
					heal = heal + spell.targets[name].amount
					if spell.targets[name].overheal then
						overheal = overheal + spell.targets[name].overheal
					end
				end
			end
		end
	end

	return heal, overheal
end