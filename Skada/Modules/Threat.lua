local Skada = Skada
Skada:AddLoadableModule("Threat", function(L)
	if Skada:IsDisabled("Threat") then return end

	local mod = Skada:NewModule(L["Threat"])

	local ipairs, select, format, max = ipairs, select, string.format, math.max
	local GroupIterator, UnitExists, UnitIsFriend = Skada.GroupIterator, UnitExists, UnitIsFriend
	local UnitName, UnitClass, UnitGUID = UnitName, UnitClass, UnitGUID
	local GetUnitRole, GetUnitSpec = Skada.GetUnitRole, Skada.GetUnitSpec
	local UnitDetailedThreatSituation = UnitDetailedThreatSituation
	local InCombatLockdown, IsGroupInCombat = InCombatLockdown, Skada.IsGroupInCombat
	local PlaySoundFile = PlaySoundFile
	local T = Skada.TablePool

	local aggroColor = {r = 0.95, g = 0, b = 0.02}
	local aggroIcon = [[Interface\Icons\ability_physical_taunt]]

	do
		local CheckInteractDistance, ItemRefTooltip = CheckInteractDistance, ItemRefTooltip
		local GetItemInfo, IsItemInRange = GetItemInfo, IsItemInRange
		local nr, maxthreat, last_warn, mypercent = 1, 0, time(), nil
		local threatUnits, threatTable = {"focus", "focustarget", "target", "targettarget"}
		local tankThreat, tankValue, rubyAcorn, queried

		local function add_to_threattable(unit, owner, target, win)
			if unit == "AGGRO" then
				if mod.db.showAggroBar and (tankThreat or 0) > 0 then
					rubyAcorn = rubyAcorn or GetItemInfo(37727)

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = "AGGRO"
					d.label = L["> Pull Aggro <"]
					d.text = nil

					d.icon = aggroIcon
					d.color = aggroColor
					d.ignore = true

					d.class = nil
					d.role = nil
					d.spec = nil
					d.isTanking = nil

					if rubyAcorn then
						d.threat = tankThreat * (IsItemInRange(37727, target) == 1 and 1.1 or 1.3)
						d.value = tankValue * (IsItemInRange(37727, target) == 1 and 1.1 or 1.3)
					else
						d.threat = tankThreat * (CheckInteractDistance(target, 3) and 1.1 or 1.3)
						d.value = tankValue * (CheckInteractDistance(target, 3) and 1.1 or 1.3)
						if not queried and not ItemRefTooltip:IsVisible() then
							ItemRefTooltip:SetHyperlink("item:37727")
							queried = true
						end
					end
					nr = nr + 1
				end
			elseif not mod.db.ignorePets or (mod.db.ignorePets and owner == nil) then
				local guid = UnitGUID(unit)
				local player = threatTable and threatTable[guid]

				if not player then
					player = {id = guid, unit = unit, name = UnitName(unit)}
					if owner ~= nil then
						player.name = player.name .. " (" .. UnitName(owner) .. ")"
						player.class = "PET"
					else
						player.class = select(2, UnitClass(unit))
						player.role = GetUnitRole(unit, player.class)
						player.spec = GetUnitSpec(unit, player.class)
					end

					-- cache the player.
					threatTable = threatTable or T.fetch("Threat_Table")
					threatTable[guid] = player
				end

				if player and player.unit then
					local isTanking, _, threatpct, _, threatvalue = UnitDetailedThreatSituation(player.unit, target)

					if threatvalue then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = player.id or player.name
						d.label = player.name
						d.text = player.id and Skada:FormatName(player.name, player.id)

						d.icon = nil
						d.color = nil
						d.ignore = nil

						d.class = player.class
						d.role = player.role
						d.spec = player.spec
						d.isTanking = isTanking

						if mod.db.rawvalue then
							if threatvalue < 0 then
								d.value = threatvalue + 410065408
								d.threat = threatvalue + 410065408
								d.color = {r = 0.5, g = 0.5, b = 0.5}
							else
								d.value = threatvalue
								d.threat = threatvalue
								d.color = nil
							end
						elseif threatpct then
							d.value = threatpct
							d.threat = threatvalue
						end

						if d.value > maxthreat then
							maxthreat = d.value
							tankThreat = d.threat
							tankValue = d.value
						end
						nr = nr + 1
					end
				end
			end
		end

		local function format_threatvalue(value)
			if value == nil then
				return "0"
			elseif value >= 100000 then
				return format("%2.1fk", value / 100000)
			else
				return format("%d", value / 100)
			end
		end

		local function find_threat_unit()
			local n = mod.db.focustarget and 1 or 3
			for i = n, 4 do
				local u = threatUnits[i]
				if UnitExists(u) and not UnitIsPlayer(u) and UnitCanAttack("player", u) and UnitHealth(u) > 0 then
					return u
				end
			end
		end

		local function getTPS(threatvalue)
			local tps = "0"
			if Skada.current then
				local totaltime = time() - (Skada.current.starttime or 0)
				tps = format_threatvalue(threatvalue / max(1, totaltime))
			end
			return tps
		end

		function mod:Update(win, set)
			if not self.db then
				self.db = Skada.db.profile.modules.threat
			end

			win.title = L["Threat"]

			if not IsGroupInCombat() then return end

			local target = find_threat_unit()

			if target then
				win.title = UnitName(target) or L["Threat"]

				-- reset stuff & check group
				maxthreat, nr = 0, 1
				GroupIterator(add_to_threattable, target, win)
				if maxthreat > 0 then
					add_to_threattable("AGGRO", nil, target, win)
				end

				-- If we are going by raw threat we got the max threat from above; otherwise it's always 100.
				if not self.db.rawvalue then
					maxthreat = 100
				end

				if win.metadata then
					win.metadata.maxvalue = maxthreat
				end

				local we_should_warn = false
				-- We now have a a complete threat table.
				-- Now we need to add valuetext.
				for _, data in ipairs(win.dataset) do
					if data.id == "AGGRO" then
						if self.db.showAggroBar and (tankThreat or 0) > 0 then
							data.valuetext = Skada:FormatValueText(
								format_threatvalue(data.threat),
								self.metadata.columns.Threat,
								getTPS(data.threat),
								self.metadata.columns.TPS,
								Skada:FormatPercent(data.value, max(0.000001, maxthreat)),
								self.metadata.columns.Percent
							)

							if win.metadata then
								win.metadata.maxvalue = self.db.rawvalue and data.threat or data.value
							end
						else
							data.id = nil
						end
					elseif data.id then
						if data.threat and data.threat > 0 then
							-- Warn if this is ourselves and we are over the treshold.
							local percent = 100 * data.value / max(0.000001, maxthreat)
							if data.id == Skada.userGUID then
								mypercent = percent
								if self.db.threshold and self.db.threshold < percent and (not data.isTanking or not self.db.notankwarnings) then
									we_should_warn = (data.color == nil)
								end
							end

							data.valuetext = Skada:FormatValueText(
								format_threatvalue(data.threat),
								self.metadata.columns.Threat,
								getTPS(data.threat),
								self.metadata.columns.TPS,
								Skada:FormatPercent(percent),
								self.metadata.columns.Percent
							)
						else
							data.id = nil
						end
					end
				end

				-- Warn
				if we_should_warn and time() - last_warn > (self.db.frequency or 2) then
					self:Warn(self.db.sound, self.db.flash, self.db.shake, mypercent and format(THREAT_TOOLTIP, mypercent) or COMBAT_THREAT_INCREASE_1)
					last_warn = time()
				end
			end
		end

		function mod:SetComplete(set)
			tankThreat, tankValue = nil, nil
			T.release("Threat_Table", threatTable)
		end
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
			flasher.texture:SetTexture([[Interface\FullScreenTextures\LowHealth]])
			flasher.texture:SetAllPoints(UIParent)
			flasher.texture:SetBlendMode("ADD")
			flasher:SetScript("OnShow", function(self)
				self.elapsed = 0
				self:SetAlpha(0)
			end)
			flasher:SetScript("OnUpdate", function(self, elapsed)
				elapsed = self.elapsed + elapsed
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
						self.originalPoints[#self.originalPoints + 1] = {WorldFrame:GetPoint(i)}
					end
				end
				self.elapsed = 0
			end)
			shaker:SetScript("OnUpdate", function(self, elapsed)
				elapsed = self.elapsed + elapsed
				local x, y = 0, 0 -- Resets to original position if we're supposed to stop.
				if elapsed >= 0.8 then
					self:Hide()
				else
					x, y = random(-8, 8), random(-8, 8)
				end
				if WorldFrame:IsProtected() and InCombatLockdown() then
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

	-- prints warning messages
	do
		local CombatText_StandardScroll = CombatText_StandardScroll
		local RaidNotice_AddMessage = RaidNotice_AddMessage
		local UIErrorsFrame = UIErrorsFrame
		local white = {r = 1, g = 1, b = 1}

		local handlers = {
			-- Default
			[1] = function(text, r, g, b, font, size, outline, sticky)
				if tostring(SHOW_COMBAT_TEXT) ~= "0" then
					CombatText_AddMessage(text, CombatText_StandardScroll, r, g, b, sticky and "crit" or nil, false)
				else
					UIErrorsFrame:AddMessage(text, r, g, b, 1.0)
				end
			end,
			-- Raid Warnings
			[2] = function(text, r, g, b)
				if r or g or b then
					local c = "|cff" .. format("%02x%02x%02x", (r or 0) * 255, (g or 0) * 255, (b or 0) * 255)
					text = c .. text .. "|r"
				end
				RaidNotice_AddMessage(RaidWarningFrame, text, white)
			end,
			-- UIError Frame
			[3] = function(text, r, g, b)
				UIErrorsFrame:AddMessage(text, r, g, b, 1.0)
			end,
			-- Chat Frame
			[4] = function(text, r, g, b)
				DEFAULT_CHAT_FRAME:AddMessage(text, r, g, b)
			end
		}

		function mod:Pour(text, r, g, b, ...)
			local func = handlers[self.db.output or 4]
			func(text, r or 1, g or 1, b or 1, ...)
		end
	end

	-- Shamelessly copied from Omen - thanks!
	function mod:Warn(sound, flash, shake, message)
		if sound then
			PlaySoundFile(Skada:MediaFetch("sound", self.db.soundfile))
		end
		if flash then
			self:Flash()
		end
		if shake then
			self:Shake()
		end
		if self.db.message and message then
			self:Pour(message, 1, 0, 0, nil, 24, "OUTLINE", true)
		end
	end

	do
		local opts = {
			type = "group",
			name = mod.moduleName,
			desc = format(L["Options for %s."], mod.moduleName),
			get = function(i)
				return mod.db[i[#i]]
			end,
			set = function(i, val)
				mod.db[i[#i]] = val
			end,
			args = {
				header = {
					type = "description",
					name = mod.moduleName,
					fontSize = "large",
					image = aggroIcon,
					imageWidth = 18,
					imageHeight = 18,
					imageCoords = {0.05, 0.95, 0.05, 0.95},
					width = "full",
					order = 0
				},
				sep = {
					type = "description",
					name = " ",
					width = "full",
					order = 1,
				},
				warning = {
					type = "group",
					name = L["Threat Warning"],
					inline = true,
					order = 10,
					args = {
						flash = {
							type = "toggle",
							name = L["Flash Screen"],
							desc = L["This will cause the screen to flash as a threat warning."],
							order = 10
						},
						shake = {
							type = "toggle",
							name = L["Shake Screen"],
							desc = L["This will cause the screen to shake as a threat warning."],
							order = 20
						},
						message = {
							type = "toggle",
							name = L["Warning Message"],
							desc = L["Print a message to screen when you accumulate too much threat."],
							order = 30
						},
						sound = {
							type = "toggle",
							name = L["Play sound"],
							desc = L["This will play a sound as a threat warning."],
							order = 40
						},
						output = {
							type = "select",
							name = L["Message Output"],
							desc = L["Choose where warning messages should be displayed."],
							order = 50,
							width = "double",
							values = {DEFAULT, RAID_WARNING, L["Blizzard Error Frame"], L["Chat Frame"]},
							hidden = function()
								return not mod.db.message
							end,
							disabled = function()
								return not mod.db.message
							end
						},
						soundfile = {
							type = "select",
							name = L["Threat sound"],
							desc = L["The sound that will be played when your threat percentage reaches a certain point."],
							order = 60,
							width = "double",
							dialogControl = "LSM30_Sound",
							values = AceGUIWidgetLSMlists.sound,
							hidden = function()
								return not mod.db.sound
							end,
							disabled = function()
								return not mod.db.sound
							end
						},
						frequency = {
							type = "range",
							name = L["Warning Frequency"],
							order = 70,
							min = 2,
							max = 15,
							step = 1
						},
						threshold = {
							type = "range",
							name = L["Threat Threshold"],
							desc = L["When your threat reaches this level, relative to tank, warnings are shown."],
							order = 80,
							min = 60,
							max = 130,
							step = 1
						}
					}
				},
				rawvalue = {
					type = "toggle",
					name = L["Show raw threat"],
					desc = L["Shows raw threat percentage relative to tank instead of modified for range."],
					order = 20
				},
				focustarget = {
					type = "toggle",
					name = L["Use focus target"],
					desc = L["Tells Skada to additionally check your 'focus' and 'focustarget' before your 'target' and 'targettarget' in that order for threat display."],
					order = 30
				},
				notankwarnings = {
					type = "toggle",
					name = L["Disable while tanking"],
					desc = L["Do not give out any warnings if Defensive Stance, Bear Form, Righteous Fury or Frost Presence is active."],
					order = 40
				},
				ignorePets = {
					type = "toggle",
					name = L["Ignore Pets"],
					desc = L["Disable tracking pets threat and only watch players."],
					order = 50,
				},
				showAggroBar = {
					type = "toggle",
					name = L["Show Pull Aggro Bar"],
					desc = L["Show a bar for the amount of threat you will need to reach in order to pull aggro."],
					order = 60
				},
				sep = {
					type = "description",
					name = " ",
					width = "full",
					order = 70
				},
				test = {
					type = "execute",
					name = L["Test Warnings"],
					width = "double",
					order = 80,
					func = function()
						mod:Warn(mod.db.sound, mod.db.flash, mod.db.shake, mod.db.message and L["Test Warnings"])
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
					output = 1,
					frequency = 2,
					threshold = 90,
					soundfile = "Fel Nova",
					rawvalue = false,
					focustarget = false,
					notankwarnings = true,
					ignorePets = true,
					showAggroBar = true
				}
			end
			if Skada.db.profile.modules.threat.sinkOptions then
				Skada.db.profile.modules.threat.sinkOptions = nil
			end
			if Skada.db.profile.modules.threat.output == nil then
				Skada.db.profile.modules.threat.output = 1
			end

			self.db = Skada.db.profile.modules.threat
			Skada.options.args.modules.args.threat = opts
		end
	end

	do
		local function add_threat_feed()
			if Skada.current and UnitExists("target") then
				local threatpct = select(3, UnitDetailedThreatSituation("player", "target"))
				return threatpct and Skada:FormatPercent(threatpct)
			end
		end

		function mod:OnEnable()
			self.db = self.db or Skada.db.profile.modules.threat
			self.metadata = {
				wipestale = true,
				columns = {Threat = true, TPS = false, Percent = true},
				icon = aggroIcon
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