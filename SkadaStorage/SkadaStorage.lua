local Skada = _G.Skada
if not Skada then return end

local AddOnName = ...
local L = LibStub("AceLocale-3.0"):GetLocale("Skada")

local function SetupStorage(self)
	self.sets = self.sets or _G.SkadaStorageDB
end

local function CheckMemory(self)
	if not self.profile.memorycheck then return end
	UpdateAddOnMemoryUsage()
	local memory = GetAddOnMemoryUsage(AddOnName)
	if memory > (self.maxmeme * 1024) then
		self:Notify(L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."], L["Memory Check"], nil, "emergency")
	end
end

local LoadFrame = CreateFrame("Frame")
LoadFrame:RegisterEvent("ADDON_LOADED")
LoadFrame:SetScript("OnEvent", function(_, event, name)
	if name == AddOnName then
		SkadaStorageDB = SkadaStorageDB or {}
		Skada.SetupStorage = SetupStorage
		Skada.CheckMemory = CheckMemory
	end
end)
