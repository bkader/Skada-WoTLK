assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Tweaks", function(Skada, L)
	if Skada:IsDisabled("Tweaks") then return end

	local mod = Skada:NewModule(L["Tweaks"], "AceHook-3.0")

	local select, band, format = select, bit.band, string.format
	local UnitExists, GetUnitName, UnitClass = UnitExists, GetUnitName, UnitClass
	local GetSpellLink, GetSpellInfo = Skada.GetSpellLink, Skada.GetSpellInfo

	local BITMASK_GROUP = Skada.BITMASK_GROUP
	local BITMASK_PETS = Skada.BITMASK_PETS
	local BITMASK_OWNERS = Skada.BITMASK_OWNERS
	local BITMASK_ENEMY = Skada.BITMASK_ENEMY

	local pull_timer

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

			local target = GetUnitName(boss .. "target")
			if target then
				local class = select(2, UnitClass(boss .. "target"))

				if class and Skada.classcolors[class] then
					target = "|c" .. Skada.classcolors[class].colorStr .. target .. "|r"
				end
				targetline = format(L["|cffffbb00Boss First Target|r: %s (%s)"], target, GetUnitName(boss) or UNKNOWN)
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
				if (band(srcFlags, BITMASK_GROUP) ~= 0 and Skada:IsBoss(dstGUID)) or Skada:IsBoss(srcGUID) then
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
					elseif srcGUID then
						local owner = Skada:GetPetOwner(srcGUID)
						if owner then
							local class = select(2, UnitClass(owner.name))
							if class and Skada.classcolors[class] then
								puller =
									"|c" .. Skada.classcolors[class].colorStr .. owner.name .. "|r (" .. PET .. ")"
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
						pull_timer.HitBy = format(L["|cffffff00First Hit|r: %s from %s"], link or "", puller)
					end
				end
			end
		end
	end

	function mod:EndSegment()
		if pull_timer then
			if not pull_timer._cancelled then
				pull_timer:Cancel()
			end
			pull_timer = nil
		end
	end

	---------------------------------------------------------------------------

	function mod:OnInitialize()
		-- first hit.
		if Skada.db.profile.firsthit == nil then
			Skada.db.profile.firsthit = true
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
				}
			}
		}
	end

	function mod:OnEnable()
		self:SecureHook(Skada, "CombatLogEvent")
		self:SecureHook(Skada, "EndSegment")
	end
end)