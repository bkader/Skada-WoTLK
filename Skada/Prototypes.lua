local Skada = Skada

local pairs, ipairs = pairs, ipairs
local setmetatable = setmetatable

local newTable, delTable = Skada.newTable, Skada.delTable

-- a dummy table used as fallback
local dummyTable = {}
Skada.dummyTable = dummyTable

-- cache tables used and reused instead of
-- constantly creating tables.
local upperCacheTable = Skada.WeakTable()
-- this one should be used at modules level
Skada.cacheTable = Skada.WeakTable()

-------------------------------------------------------------------------------
-- player prototype & functions

local playerPrototype = {}
Skada.playerPrototype = playerPrototype

function playerPrototype:Bind(obj, set)
	if obj then
		local o = setmetatable(obj, self)
		self.__index = self
		o.super = set
		return o
	end
end

function playerPrototype:GetTime(active)
	return Skada:PlayerActiveTime(self.super, self, active)
end

-------------------------------------------------------------------------------
-- enemy prototype & functions

local enemyPrototype = {}
Skada.enemyPrototype = enemyPrototype

function enemyPrototype:Bind(obj, set)
	if obj then
		local o = setmetatable(obj, self)
		self.__index = self
		o.super = set
		return o
	end
end

function enemyPrototype:GetTime()
	return Skada:GetSetTime(self.super)
end

-------------------------------------------------------------------------------
-- segment/set prototype & functions

local setPrototype = {}
Skada.setPrototype = setPrototype

function setPrototype:Bind(obj)
	if obj then
		local o = setmetatable(obj, self)
		self.__index = self
		return o
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

function setPrototype:GetPlayers()
	if self.players then
		wipe(upperCacheTable)
		for i, p in ipairs(self.players) do
			upperCacheTable[i] = playerPrototype:Bind(p, self)
		end
		return upperCacheTable
	end
	return dummyTable
end

function setPrototype:GetEnemies()
	if self.enemies then
		wipe(upperCacheTable)
		for i, e in ipairs(self.enemies) do
			upperCacheTable[i] = enemyPrototype:Bind(e, self)
		end
		return upperCacheTable
	end
	return dummyTable
end

function setPrototype:IteratePlayers()
	return ipairs(self:GetPlayers())
end

function setPrototype:IterateEnemies()
	return ipairs(self:GetEnemies())
end

function setPrototype:GetPlayer(id, name)
	for _, p in self:IteratePlayers() do
		if (id and p.id == id) or (name and p.name == name) then
			return p
		end
	end
end

function setPrototype:GetEnemy(name, id)
	for _, e in self:IterateEnemies() do
		if (id and e.id == id) or (name and e.name == name) then
			return e
		end
	end
end

function setPrototype:GetActor(name, id)
	local actor = self:GetPlayer(id, name)
	if actor then
		return actor
	end

	actor = self:GetEnemy(name, id)
	if actor then
		return actor
	end

	actor = Skada:FindPlayer(self, id, name, true)
	if actor then
		return playerPrototype:Bind(actor, self)
	end

	actor = Skada:FindEnemy(self, name, id)
	if actor then
		return enemyPrototype:Bind(actor, self)
	end
end

-------------------------------------------------------------------------------
-- Skada functions

function Skada:GetSet(s)
	if s == "current" then
		return setPrototype:Bind(self.current or self.last or self.char.sets[1])
	elseif s == "total" then
		return setPrototype:Bind(self.total)
	else
		return setPrototype:Bind(self.char.sets[s])
	end
end

function Skada:GetSets()
	wipe(upperCacheTable)
	for i, set in ipairs(self.char.sets) do
		upperCacheTable[i] = setPrototype:Bind(set)
	end
	return upperCacheTable
end

function Skada:IterateSets()
	return ipairs(self:GetSets())
end

-- finds a player that was already recorded
function Skada:FindPlayer(set, id, name, strict)
	if set and set.players and id and id ~= "total" then
		set._playeridx = set._playeridx or newTable()

		local player = set._playeridx[id]
		if player then
			return player
		end

		-- search the set
		for _, p in ipairs(set.players) do
			if p.id == id then
				set._playeridx[id] = p
				return p
			end
		end

		-- needed for certain bosses
		local isboss, _, npcname = self:IsBoss(id, name)
		if isboss then
			player = {id = id, name = npcname or name, class = "BOSS"}
			set._playeridx[id] = player
			return player
		end

		if strict then
			return player
		end

		-- last hope
		return {id = id, name = name or UNKNOWN, class = "PET"}
	end
end

-- finds an enemy unit
function Skada:FindEnemy(set, name, id)
	if set and set.enemies and name then
		set._enemyidx = set._enemyidx or newTable()

		local enemy = set._enemyidx[name]
		if enemy then
			return enemy
		end

		for _, e in ipairs(set.enemies) do
			if (id and id == e.id) or (e.name == name) then
				set._enemyidx[name] = e
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
	local actor = self:FindActor(set, id, name, flag)
	-- creates it if not found
	if not actor then
		if self:IsPlayer(id, flag, name) == 1 then -- group member
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
			set._playeridx = delTable(set._playeridx)
			set._enemyidx = delTable(set._enemyidx)
			if not mt then return end

			-- clear created metatable ref.
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