local _, Skada = ...
Skada:AddLoadableModule("Tweaks", function(Skada, L)
	if Skada:IsDisabled("Tweaks") then return end

	local mod = Skada:NewModule(L["Tweaks"], "AceHook-3.0")

	local select, band, format = select, bit.band, string.format
	local UnitExists, UnitName, UnitClass = UnitExists, UnitName, UnitClass
	local GetSpellLink, GetSpellInfo = Skada.GetSpellLink, Skada.GetSpellInfo

	local BITMASK_GROUP = Skada.BITMASK_GROUP
	local BITMASK_PETS = Skada.BITMASK_PETS
	local BITMASK_OWNERS = Skada.BITMASK_OWNERS
	local BITMASK_ENEMY = Skada.BITMASK_ENEMY

	local pull_timer

	local ignoredspells = {
		[1130] = true,
		[14323] = true,
		[14324] = true,
		[14325] = true,
		[53338] = true
	}

	-- thank you Details!
	local function WhoPulled(self)
		-- first hit
		local hitline = self.HitBy or L["|cffffbb00First Hit|r: *?*"]
		Skada:Print(hitline)

		-- firt boss target
		local targetline
		for i = 1, 4 do
			local boss = "boss" .. i
			if not UnitExists(boss) then
				break -- no need
			end

			local target = UnitName(boss .. "target")
			if target then
				local class = select(2, UnitClass(boss .. "target"))

				if class and Skada.classcolors[class] then
					target = "|c" .. Skada.classcolors[class].colorStr .. target .. "|r"
				end
				targetline = L:F("|cffffbb00Boss First Target|r: %s (%s)", target, UnitName(boss) or UNKNOWN)
				break -- no need
			end
		end

		if targetline then
			Skada:Print(targetline)
		end
	end

	do
		local triggerevents = {
			["RANGE_DAMAGE"] = true,
			["SPELL_BUILDING_DAMAGE"] = true,
			["SPELL_DAMAGE"] = true,
			["SPELL_PERIODIC_DAMAGE"] = true,
			["SWING_DAMAGE"] = true
		}

		function mod:CombatLogEvent(_, _, timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
			-- pull timer
			if Skada.db.profile.firsthit and (triggerevents[eventtype] or eventtype == "SPELL_CAST_SUCCESS") and not pull_timer then
				if ignoredspells[select(1, ...)] then return end
				if srcName and dstName and ((band(srcFlags, BITMASK_GROUP) ~= 0 and Skada:IsBoss(dstGUID)) or (band(dstFlags, BITMASK_GROUP) ~= 0 and Skada:IsBoss(srcGUID))) then
					local puller

					-- close distance?
					if Skada:IsBoss(srcGUID) then
						puller = srcName -- the boss name
						if Skada:IsPet(dstGUID, dstFlags) then
							puller = puller .. " (" .. (dstName or UNKNOWN) .. ")"
						elseif dstName then
							local class = select(2, UnitClass(dstName))
							if class and Skada.classcolors[class] then
								puller = puller .. " (|c" .. Skada.classcolors[class].colorStr .. dstName .. "|r)"
							else
								puller = puller .. " (" .. dstName .. ")"
							end
						end
					else
						local owner = Skada:GetPetOwner(srcGUID)
						if owner then
							local class = select(2, UnitClass(owner.name))
							if class and Skada.classcolors[class] then
								puller = "|c" .. Skada.classcolors[class].colorStr .. owner.name .. "|r (" .. PET .. ")"
							else
								puller = owner.name .. " (" .. PET .. ")"
							end
						elseif srcName then
							local class = select(2, UnitClass(srcName))
							if class and Skada.classcolors[class] then
								puller = "|c" .. Skada.classcolors[class].colorStr .. srcName .. "|r"
							else
								puller = srcName
							end
						end
					end

					if puller then
						local link = (eventtype == "SWING_DAMAGE") and GetSpellLink(6603) or GetSpellLink(select(1, ...)) or GetSpellInfo(select(1, ...))
						pull_timer = Skada.NewTimer(0.5, function() WhoPulled(pull_timer) end)
						pull_timer.HitBy = L:F("|cffffff00First Hit|r: %s from %s", link or "", puller)
					end
				end
			end
		end
	end

	function mod:EndSegment()
		if pull_timer then
			pull_timer:Cancel()
			pull_timer = nil
		end
	end

	---------------------------------------------------------------------------

	function mod:OnInitialize()
		-- first hit.
		if Skada.db.profile.firsthit == nil then
			Skada.db.profile.firsthit = true
		end
		-- smart stop & duration
		if Skada.db.profile.smartstop == nil then
			Skada.db.profile.smartstop = false
		end
		if Skada.db.profile.smartwait == nil then
			Skada.db.profile.smartwait = 5
		end

		-- options.
		Skada.options.args.Tweaks = {
			type = "group",
			name = L["Tweaks"],
			get = function(i)
				return Skada.db.profile[i[#i]]
			end,
			set = function(i, val)
				Skada.db.profile[i[#i]] = val
				Skada:ApplySettings()
			end,
			order = 997,
			args = {
				firsthit = {
					type = "toggle",
					name = L["First hit"],
					desc = L["Prints a message of the first hit before combat.\nOnly works for boss encounters."],
					order = 1
				},
				moduleicons = {
					type = "toggle",
					name = L["Module Icons"],
					desc = L["Enable this if you want to show module icons on windows and menus."],
					order = 2
				},
				smartsep = {
					type = "description",
					name = " ",
					order = 95,
					width = "full"
				},
				smartheader = {
					type = "header",
					name = L["Smart Stop"],
					order = 95.1
				},
				smartdesc = {
					type = "description",
					name = L["Automatically stops the current segment after the boss has died.\nUseful to avoid collecting data in case of a combat bug."],
					fontSize = "medium",
					order = 95.2,
					width = "full"
				},
				smartstop = {
					type = "toggle",
					name = L["Enable"],
					order = 95.3
				},
				smartwait = {
					type = "range",
					name = L["Duration"],
					desc = L["For how long Skada should wait before stopping the segment."],
					disabled = function() return not Skada.db.profile.smartstop end,
					min = 0, max = 10, step = 0.01, bigStep = 0.1,
					order = 95.4
				}
			}
		}
	end

	function mod:BossDefeated(event, set)
		if not (event == "COMBAT_BOSS_DEFEATED" and set) then
			return
		end

		if Skada.db.profile.smartstop then
			Skada.After(Skada.db.profile.smartwait or 5, function()
				if not set.endtime then
					Skada:Print(L["Smart Stop"])
					Skada:StopSegment()
				end
			end)
		end
	end

	function mod:OnEnable()
		self:SecureHook(Skada, "CombatLogEvent")
		self:SecureHook(Skada, "EndSegment")
		Skada.RegisterCallback(self, "COMBAT_BOSS_DEFEATED", "BossDefeated")
	end

	function mod:OnDisable()
		self:UnhookAll()
		Skada.UnregisterAllCallbacks(self)
	end
end)