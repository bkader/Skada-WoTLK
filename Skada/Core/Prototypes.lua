local Skada = Skada

local pairs, ipairs = pairs, ipairs
local getmetatable = getmetatable
local setmetatable = setmetatable

-- a dummy table used as fallback
local dummyTable = {}
Skada.dummyTable = dummyTable

-- this one should be used at modules level
local T = Skada.Table
Skada.cacheTable = T.get("Skada_CacheTable")

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

-- for better dps calculation, we use active time for Arena/BGs.
function playerPrototype:GetTime(active)
	return Skada:GetActiveTime(self.super, self, active or self.super.type == "pvp" or self.super.type == "arena")
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

function enemyPrototype:GetTime(active)
	return Skada:GetActiveTime(self.super, self, active or self.super.type == "pvp" or self.super.type == "arena")
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

function setPrototype:GetActorTime(id, name, active)
	local actor = self:GetActor(name, id)
	return (actor and actor.GetTime) and actor:GetTime(active) or 0
end

function setPrototype:GetFormatedTime()
	return Skada:FormatTime(Skada:GetSetTime(self))
end

function setPrototype:GetPlayer(id, name)
	if self.players and ((id and id ~= "total") or name) then
		for _, actor in ipairs(self.players) do
			if (id and actor.id == id) or (name and actor.name == name) then
				return playerPrototype:Bind(actor, self)
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
				return enemyPrototype:Bind(actor, self)
			end
		end
	end

	-- couldn't be found, rely on skada.
	local actor = Skada:FindEnemy(self, name, id)
	return actor and enemyPrototype:Bind(actor, self)
end

function setPrototype:GetActor(name, id)
	return self:GetPlayer(id, name) or self:GetEnemy(name, id)
end