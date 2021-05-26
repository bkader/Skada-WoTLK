assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Threat", function(Skada, L)
	if Skada:IsDisabled("Threat") then return end

	local mod = Skada:NewModule(L["Threat"], "LibSink-2.0")
	local LSM = LibStub("LibSharedMedia-3.0")

	local _ipairs, _select, _format = ipairs, select, string.format
	local tinsert, math_max = table.insert, math.max
	local _UnitExists, _UnitIsFriend = UnitExists, UnitIsFriend
	local _GetUnitName, _UnitClass, _UnitGUID = GetUnitName, UnitClass, UnitGUID
	local _UnitDetailedThreatSituation = UnitDetailedThreatSituation
	local _InCombatLockdown = InCombatLockdown
	local _PlaySoundFile = PlaySoundFile
	local _GetNumPartyMembers, _GetNumRaidMembers = GetNumPartyMembers, GetNumRaidMembers
	local mypercent

	do
		local nr, maxthreat = 1, 0

		local threatTable = Skada:WeakTable()

		local function add_to_threattable(win, unit, target)
			local guid = _UnitGUID(unit)
			local player = threatTable[guid]

			if not player and _UnitExists(unit) then
				local name = _GetUnitName(unit)

				-- is is a pet?
				local owner = Skada:GetPetOwner(guid)
				if owner then
					player = {
						id = guid,
						name = name .. " (" .. owner.name .. ")",
						class = "PET",
						unit = unit
					}
				else
					local class = _select(2, _UnitClass(unit))
					player = {
						id = guid,
						name = name,
						class = class,
						unit = unit
					}
				end

				-- cache the player.
				threatTable[guid] = player
			end

			if player and _UnitExists(player.unit) then
				local isTanking, status, threatpct, rawthreatpct, threatvalue = _UnitDetailedThreatSituation(player.unit, target)

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				if mod.db.rawvalue and threatvalue then
					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class

					d.threat = threatvalue
					d.isTanking = isTanking

					if threatvalue < 0 then
						-- Show real threat.
						d.value = threatvalue + 410065408
						d.threat = threatvalue + 410065408
					else
						d.value = threatvalue
					end

					if threatvalue > maxthreat then
						maxthreat = threatvalue
					end
				elseif threatpct then
					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class

					d.value = threatpct
					d.isTanking = isTanking
					d.threat = threatvalue
				end
				nr = nr + 1
			end
		end

		local function format_threatvalue(value)
			if value == nil then
				return "0"
			elseif value >= 100000 then
				return _format("%2.1fk", value / 100000)
			else
				return _format("%d", value / 100)
			end
		end

		local function getTPS(threatvalue)
			local tps = "0"
			if Skada.current then
				local totaltime = time() - (Skada.current.starttime or 0)
				tps = format_threatvalue(threatvalue / math_max(1, totaltime))
			end
			return tps
		end

		local last_warn = time()

		function mod:Update(win, set)
			win.title = L["Threat"]

			if not Skada:IsRaidInCombat() then return end

			local target = nil
			if _UnitExists("target") and not _UnitIsFriend("player", "target") then
				target = "target"
			elseif self.db.focustarget and _UnitExists("focus") and not _UnitIsFriend("player", "focus") then
				target = "focus"
			elseif self.db.focustarget and _UnitExists("focustarget") and not _UnitIsFriend("player", "focustarget") then
				target = "focustarget"
			elseif _UnitExists("target") and _UnitIsFriend("player", "target") and _UnitExists("targettarget") and not _UnitIsFriend("player", "targettarget") then
				target = "targettarget"
			end

			if target then
				win.title = _GetUnitName(target) or L["Threat"]

				-- Reset our counter which we use to keep track of current index in the dataset.
				nr = 1

				-- Reset out max threat value.
				maxthreat = 0

				local _pref, _min, _max = "raid", 1, _GetNumRaidMembers()
				if _max == 0 then
					_pref, _min, _max = "party", 0, _GetNumPartyMembers()
				end

				for i = _min, _max do
					local unit = (i == 0) and "player" or _pref .. i
					if _UnitExists(unit) then
						add_to_threattable(win, unit, target)

						if _UnitExists(unit .. "pet") then
							add_to_threattable(win, unit .. "pet", target)
						end
					end
				end

				-- If we are going by raw threat we got the max threat from above; otherwise it's always 100.
				if not self.db.rawvalue then
					maxthreat = 100
				end

				win.metadata.maxvalue = maxthreat
				local we_should_warn = false

				-- We now have a a complete threat table.
				-- Now we need to add valuetext.
				for _, data in _ipairs(win.dataset) do
					if data.id then
						if data.threat and data.threat > 0 then
							-- Warn if this is ourselves and we are over the treshold.
							local percent = 100 * data.value / math_max(0.000001, maxthreat)
							if data.label == _GetUnitName("player") then
								mypercent = percent
								if self.db.threshold and self.db.threshold < percent and (not data.isTanking or not self.db.notankwarnings) then
									we_should_warn = true
								end
							end

							data.valuetext = Skada:FormatValueText(
								format_threatvalue(data.threat),
								self.metadata.columns.Threat,
								getTPS(data.threat),
								self.metadata.columns.TPS,
								_format("%02.1f%%", percent),
								self.metadata.columns.Percent
							)
						else
							data.id = nil
						end
					end
				end

				-- Warn
				if we_should_warn and time() - last_warn > 2 then
					self:Warn(
						self.db.sound,
						self.db.flash,
						self.db.shake,
						self.db.message and (mypercent and _format(THREAT_TOOLTIP, mypercent) or COMBAT_THREAT_INCREASE_1)
					)
					last_warn = time()
				end
			end
		end

		function mod:AddSetAttributes(set)
			threatTable = Skada:WeakTable()
		end
		mod.SetComplete = mod.AddSetAttributes
	end

	-- Shamelessly copied from Omen - thanks!
	function mod:Flash()
		if not self.FlashFrame then
			local flasher = CreateFrame("Frame", "SkadaThreatFlashFrame")
			flasher:SetToplevel(true)
			flasher:SetFrameStrata("FULLSCREEN_DIALOG")
			flasher:SetAllPoints(UIParent)
			flasher:EnableMouse(false)
			flasher:Hide()
			flasher.texture = flasher:CreateTexture(nil, "BACKGROUND")
			flasher.texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
			flasher.texture:SetAllPoints(UIParent)
			flasher.texture:SetBlendMode("ADD")
			flasher:SetScript("OnShow", function(self) self:SetAlpha(0) end)
			flasher:SetScript("OnUpdate", function(self, elapsed)
				elapsed = (self.elapsed or 0) + elapsed
				if elapsed < 2.6 then
					local alpha = elapsed % 1.3
					if alpha < 0.15 then
						self:SetAlpha(alpha / 0.15)
					elseif alpha < 0.9 then
						self:SetAlpha(1 - (alpha - 0.15) / 0.6)
					else
						self:SetAlpha(0)
					end
				else
					self:Hide()
				end
				self.elapsed = elapsed
			end)
			self.FlashFrame = flasher
		end

		self.FlashFrame:Show()
	end

	-- Shamelessly copied from Omen (which copied from BigWigs) - thanks!
	function mod:Shake()
		local shaker = self.ShakerFrame
		if not shaker then
			shaker = CreateFrame("Frame", "SkadaThreatShaker", UIParent)
			shaker:Hide()
			shaker:SetScript("OnShow", function(self)
				-- Store old worldframe positions, we need them all, people have frame modifiers for it
				if not self.originalPoints then
					self.originalPoints = {}
					for i = 1, WorldFrame:GetNumPoints() do
						tinsert(self.originalPoints, {WorldFrame:GetPoint(i)})
					end
				end
			end)
			shaker:SetScript("OnUpdate", function(self, elapsed)
				elapsed = (self.elapsed or 0) + elapsed
				local x, y = 0, 0 -- Resets to original position if we're supposed to stop.
				if elapsed >= 0.8 then
					self:Hide()
				else
					x, y = random(-8, 8), random(-8, 8)
				end
				if WorldFrame:IsProtected() and _InCombatLockdown() then
					if not shaker.fail then
						shaker.fail = true
					end
					self:Hide()
				else
					WorldFrame:ClearAllPoints()
					for i = 1, #self.originalPoints do
						local v = self.originalPoints[i]
						WorldFrame:SetPoint(v[1], v[2], v[3], v[4] + x, v[5] + y)
					end
				end
				self.elapsed = elapsed
			end)
			self.ShakerFrame = shaker
		end

		shaker:Show()
	end

	-- Shamelessly copied from Omen - thanks!
	function mod:Warn(sound, flash, shake, message)
		if sound then
			_PlaySoundFile(LSM:Fetch("sound", self.db.soundfile))
		end
		if flash then
			self:Flash()
		end
		if shake then
			self:Shake()
		end
		if message then
			self:Pour(message, 1, 0, 0, nil, 24, "OUTLINE", true)
		end
	end

	do
		local opts = {
			type = "group",
			name = L["Threat"],
			get = function(i)
				return mod.db[i[#i]]
			end,
			set = function(i, val)
				mod.db[i[#i]] = val
			end,
			args = {
				warning = {
					type = "group",
					name = L["Threat warning"],
					inline = true,
					order = 1,
					args = {
						flash = {
							type = "toggle",
							name = L["Flash screen"],
							desc = L["This will cause the screen to flash as a threat warning."],
							order = 1
						},
						shake = {
							type = "toggle",
							name = L["Shake screen"],
							desc = L["This will cause the screen to shake as a threat warning."],
							order = 2
						},
						message = {
							type = "toggle",
							name = L["Warning Message"],
							desc = L["Print a message to screen when you accumulate too much threat."],
							order = 3
						},
						sound = {
							type = "toggle",
							name = L["Play sound"],
							desc = L["This will play a sound as a threat warning."],
							order = 4
						},
						soundfile = {
							type = "select",
							name = L["Threat sound"],
							desc = L[
								"The sound that will be played when your threat percentage reaches a certain point."
							],
							order = 5,
							dialogControl = "LSM30_Sound",
							values = AceGUIWidgetLSMlists.sound
						},
						threshold = {
							type = "range",
							name = L["Threat threshold"],
							desc = L["When your threat reaches this level, relative to tank, warnings are shown."],
							order = 6,
							min = 60,
							max = 130,
							step = 1
						}
					}
				},
				output = mod:GetSinkAce3OptionsDataTable(),
				rawvalue = {
					type = "toggle",
					name = L["Show raw threat"],
					desc = L["Shows raw threat percentage relative to tank instead of modified for range."],
					order = 3
				},
				focustarget = {
					type = "toggle",
					name = L["Use focus target"],
					desc = L["Shows threat on focus target, or focus target's target, when available."],
					order = 4
				},
				notankwarnings = {
					type = "toggle",
					name = L["Disable while tanking"],
					order = 5
				},
				test = {
					type = "execute",
					name = L["Test warnings"],
					order = 6,
					func = function()
						mod:Warn(mod.db.sound, mod.db.flash, mod.db.shake, mod.db.message and L["Test warnings"])
					end
				}
			}
		}

		function mod:OnInitialize()
			if not Skada.db.profile.modules.threat then
				Skada.db.profile.modules.threat = {
					sound = true,
					flash = true,
					shake = false,
					message = false,
					sinkOptions = {},
					threshold = 90,
					soundfile = "Fel Nova",
					notankwarnings = true
				}
			end
			self.db = Skada.db.profile.modules.threat
			self:SetSinkStorage(mod.db.sinkOptions)
			Skada.options.args.modules.args.threat = opts

			Skada.options.args.modules.args.threat.args.output.order = 2
			Skada.options.args.modules.args.threat.args.output.inline = true
			Skada.options.args.modules.args.threat.args.output.hidden = function()
				return not self.db.message
			end
			Skada.options.args.modules.args.threat.args.output.disabled = function()
				return not self.db.message
			end
		end
	end

	do
		local function add_threat_feed()
			if Skada.current and _UnitExists("target") then
				local isTanking, status, threatpct, rawthreatpct, threatvalue =
					_UnitDetailedThreatSituation("player", "target")
				if threatpct then
					return _format("%02.1f%%", threatpct)
				end
			end
		end

		function mod:OnEnable()
			self.metadata = {
				wipestale = true,
				columns = {Threat = true, TPS = false, Percent = true},
				icon = "Interface\\Icons\\ability_physical_taunt"
			}
			self.notitleset = true
			Skada:AddFeed(L["Threat: Personal Threat"], add_threat_feed)
			Skada:AddMode(self)
		end
	end

	function mod:OnDisable()
		Skada:RemoveFeed(L["Threat: Personal Threat"])
		Skada:RemoveMode(self)
	end
end)