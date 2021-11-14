local Skada = Skada

local pairs, ipairs = pairs, ipairs
local getmetatable = getmetatable
local setmetatable = setmetatable

-- a dummy table used as fallback
local dummyTable = {}
Skada.dummyTable = dummyTable

-- this one should be used at modules level
Skada.cacheTable = Skada.WeakTable()

-------------------------------------------------------------------------------
-- player prototype & functions

Skada.playerPrototype = Skada.playerPrototype or {}
local playerPrototype = Skada.playerPrototype

function playerPrototype:Bind(obj, set)
	if obj then
		if getmetatable(obj) ~= self then
			setmetatable(obj, self)
			self.__index = self
			obj.super = set
		end
		return obj
	end
end

function playerPrototype:GetTime(active)
	return Skada:PlayerActiveTime(self.super, self, active)
end

-------------------------------------------------------------------------------
-- enemy prototype & functions

Skada.enemyPrototype = Skada.enemyPrototype or {}
local enemyPrototype = Skada.enemyPrototype

function enemyPrototype:Bind(obj, set)
	if obj then
		if getmetatable(obj) ~= self then
			setmetatable(obj, self)
			self.__index = self
			obj.super = set
		end
		return obj
	end
end

function enemyPrototype:GetTime()
	return Skada:GetSetTime(self.super)
end

-------------------------------------------------------------------------------
-- segment/set prototype & functions

Skada.setPrototype = Skada.setPrototype or {}
local setPrototype = Skada.setPrototype

function setPrototype:Bind(obj)
	if obj then
		if getmetatable(obj) ~= self then
			setmetatable(obj, self)
			self.__index = self

			if obj.players then
				for i, p in ipairs(obj.players) do
					playerPrototype:Bind(p, obj)
				end
			end

			if obj.enemies then
				for i, e in ipairs(obj.enemies) do
					enemyPrototype:Bind(e, obj)
				end
			end
		end

		return obj
	end
end

function setPrototype:GetLabel()
	return Skada:GetSetLabel(self)
end

function setPrototype:GetTime()
	return Skada:GetSetTime(self)
end

function setPrototype:GetFormatedTime()
	return Skada:FormatTime(Skada:GetSetTime(self))
end

function setPrototype:GetPlayer(id, name)
	if self.players and ((id and id ~= "total") or name) then
		for _, actor in ipairs(self.players) do
			if (id and actor.id == id) or (name and actor.name == name) then
				return actor
			end
		end
	end

	-- couldn't be found, rely on skada.
	local actor = Skada:FindPlayer(self, id, name, true)
	return actor and playerPrototype:Bind(actor, self)
end

function setPrototype:GetEnemy(name, id)
	if self.enemies and name then
		for _, actor in ipairs(self.enemies) do
			if (name and actor.name == name) or (id and actor.id == id) then
				return actor
			end
		end
	end

	-- couldn't be found, rely on skada.
	local actor = Skada:FindEnemy(self, name, id)
	return actor and enemyPrototype:Bind(actor, self)
end

function setPrototype:GetActor(name, id, strict)
	return self:GetPlayer(id, name) or self:GetEnemy(name, id)
end

function setPrototype:IteratPlayers()
	return ipairs(self.players)
end

-------------------------------------------------------------------------------
-- Skada functions

function Skada:GetSet(s)
	local set = nil
	if s == "current" then
		set = self.current or self.last or self.char.sets[1]
	elseif s == "total" then
		set = self.total
	else
		set = self.char.sets[s]
	end

	return set and setPrototype:Bind(set)
end

function Skada:GetSets()
	for _, set in ipairs(self.char.sets) do
		set =  setPrototype:Bind(set)
	end
	return self.char.sets
end

function Skada:IterateSets()
	return ipairs(self:GetSets())
end

-- finds a player that was already recorded
function Skada:FindPlayer(set, id, name, strict)
	if set and set.players and id and id ~= "total" then
		set._playeridx = set._playeridx or {}

		local player = set._playeridx[id]
		if player then
			return playerPrototype:Bind(player, set)
		end

		-- search the set
		for _, p in ipairs(set.players) do
			if (id and p.id == id) or (name and p.name == name) then
				set._playeridx[id] = playerPrototype:Bind(p, set)
				return p
			end
		end

		-- needed for certain bosses
		local isboss, _, npcname = self:IsBoss(id, name)
		if isboss then
			player = {id = id, name = npcname or name, class = "BOSS"}
			set._playeridx[id] = playerPrototype:Bind(player, set)
			return player
		end

		-- our last hope!
		if not strict then
			player = playerPrototype:Bind({id = id, name = name or UNKNOWN, class = "PET"}, set)
		end

		return player
	end
end

-- finds an enemy unit
function Skada:FindEnemy(set, name, id)
	if set and set.enemies and name then
		set._enemyidx = set._enemyidx or {}

		local enemy = set._enemyidx[name]
		if enemy then
			return enemyPrototype:Bind(enemy, set)
		end

		for _, e in ipairs(set.enemies) do
			if (id and id == e.id) or (name and e.name == name) then
				set._enemyidx[name] = enemyPrototype:Bind(e, set)
				return e
			end
		end
	end
end

function Skada:FindActor(set, id, name)
	local actor = self:FindPlayer(set, id, name, true)
	if not actor then
		actor = self:FindEnemy(set, name, id)
	end
	return actor
end

function Skada:GetActor(set, id, name, flag)
	local actor = self:FindActor(set, id, name)
	-- creates it if not found
	if not actor then
		if self:IsPlayer(id, flag, name) == 1 or self:IsPet(id, flag) == 1 then -- group members or group pets
			actor = self:GetPlayer(set, id, name, flag)
		else -- an outsider maybe?
			actor = self:GetEnemy(set, name, id, flag)
		end
	end
	return actor
end

do
	local function ClearIndexes(set, mt)
		if set then
			set._playeridx = nil
			set._enemyidx = nil

			-- delete our metatables.
			if mt then
				if set.players then
					for _, p in ipairs(set.players) do
						if p.super then
							p.super = nil
						end
					end
				end

				if set.enemies then
					for _, e in ipairs(set.enemies) do
						if e.super then
							e.super = nil
						end
					end
				end
			end
		end
	end

	function Skada:ClearIndexes()
		ClearIndexes(Skada.current)
		ClearIndexes(Skada.char.total)
		for _, set in ipairs(Skada.char.sets) do
			ClearIndexes(set)
		end
	end

	function Skada:ClearAllIndexes()
		ClearIndexes(Skada.current, true)
		ClearIndexes(Skada.char.total, true)
		for _, set in ipairs(Skada.char.sets) do
			ClearIndexes(set, true)
		end
	end
end