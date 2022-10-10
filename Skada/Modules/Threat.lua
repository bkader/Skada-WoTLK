local _, Skada = ...
local private = Skada.private
Skada:RegisterModule("Threat", function(L, P, _, _, M)
	local mod = Skada:NewModule("Threat")

	local format, max = string.format, math.max
	local UnitExists, UnitName = UnitExists, UnitName
	local UnitDetailedThreatSituation, InCombatLockdown = UnitDetailedThreatSituation, InCombatLockdown
	local GroupIterator, GetUnitRole, GetUnitSpec = Skada.GroupIterator, Skada.GetUnitRole, Skada.GetUnitSpec
	local PlaySoundFile = PlaySoundFile
	local new, del, clear = private.newTable, private.delTable, private.clearTable
	local mod_cols = nil

	local aggro_icon = [[Interface\Icons\ability_physical_taunt]]

	do
		local CheckInteractDistance, ItemRefTooltip = CheckInteractDistance, ItemRefTooltip
		local GetItemInfo, IsItemInRange = GetItemInfo, IsItemInRange
		local UnitGUID, UnitClass = UnitGUID, UnitClass
		local nr, max_threat, last_warn, my_percent = 0, 0, time(), nil
		local threat_table, we_should_warn = nil, false
		local tank_threat, tank_value, ruby_acorn, queried

		-- bar colors
		local aggro_color = RED_FONT_COLOR
		local negative_color = GRAY_FONT_COLOR

		local function add_to_threattable(unit, owner, target, win)
			if unit == "AGGRO" then
				if not mod.db.showAggroBar or not tank_threat or tank_threat == 0 then return end

				if not ruby_acorn then
					ruby_acorn = GetItemInfo(37727)
				end

				nr = nr + 1
				local d = win:nr(nr)

				d.id = "AGGRO"
				d.label = L["> Pull Aggro <"]
				d.icon = aggro_icon
				d.color = aggro_color
				d.ignore = true
				d.changed = nil
				d.isTanking = nil

				if ruby_acorn then
					d.threat = tank_threat * (IsItemInRange(37727, target) == 1 and 1.1 or 1.3)
					d.value = tank_value * (IsItemInRange(37727, target) == 1 and 1.1 or 1.3)
				else
					d.threat = tank_threat * (CheckInteractDistance(target, 3) and 1.1 or 1.3)
					d.value = tank_value * (CheckInteractDistance(target, 3) and 1.1 or 1.3)
					if not queried and not ItemRefTooltip:IsVisible() then
						ItemRefTooltip:SetHyperlink("item:37727")
						queried = true
					end
				end

				return
			elseif mod.db.ignorePets and owner then -- ignore pets
				return
			end

			local guid = UnitGUID(unit)
			local player = threat_table and threat_table[guid]

			if not player then
				player = new()
				player.id = guid
				player.unit = unit
				player.name = UnitName(unit)

				if owner ~= nil then
					player.name = player.name .. " (" .. UnitName(owner) .. ")"
					player.class = "PET"
				else
					_, player.class = UnitClass(unit)
					player.role = GetUnitRole(guid)
					player.spec = GetUnitSpec(guid)
				end

				-- cache the player.
				threat_table = threat_table or {}
				threat_table[guid] = player
			end

			if not player or not player.unit then return end

			local isTanking, _, threatpct, _, threatvalue = UnitDetailedThreatSituation(player.unit, target)
			if threatvalue then
				nr = nr + 1
				local d = win:nr(nr)

				d.id = player.id or player.name
				d.label = player.name
				d.text = player.id and Skada:FormatName(player.name, player.id)

				d.class = player.class
				d.role = player.role
				d.spec = player.spec
				d.isTanking = isTanking

				if mod.db.rawvalue then
					if threatvalue < 0 then
						d.value = threatvalue + 410065408
						d.threat = threatvalue + 410065408
						d.color = negative_color
						d.changed = true
					else
						d.value = threatvalue
						d.threat = threatvalue
					end
				elseif threatpct then
					d.value = threatpct
					d.threat = threatvalue
				end

				if d.value > max_threat then
					max_threat = d.value
					tank_threat = d.threat
					tank_value = d.value
				end
			end
		end

		local function format_threatvalue(value)
			if value == nil then
				return "0"
			elseif value >= 100000 then
				return format("%2.1fk", value * 1e-05)
			else
				return format("%d", value * 0.01)
			end
		end

		local function get_tps(threatvalue)
			return Skada.current and format_threatvalue(threatvalue / Skada.current:GetTime()) or "0"
		end

		function mod:Update(win, set)
			win.title = L["Threat"]

			if Skada.inCombat and self.unitID and UnitExists(self.unitID) then
				self.unitName = self.unitName or UnitName(self.unitID)
				win.title = self.unitName or win.title

				-- reset stuff & check group
				max_threat, nr = 0, 0
				GroupIterator(add_to_threattable, self.unitID, win)
				if max_threat > 0 and self.db.showAggroBar then
					add_to_threattable("AGGRO", nil, self.unitID, win)
				end

				-- nothing was added.
				if nr == 0 then return end

				-- If we are going by raw threat we got the max threat from above; otherwise it's always 100.
				max_threat = self.db.rawvalue and max_threat or 100

				if win.metadata then
					win.metadata.maxvalue = max_threat
				end

				we_should_warn = false
				-- We now have a a complete threat table.
				-- Now we need to add valuetext.
				for i = 1, #win.dataset do
					local data = win.dataset[i]
					if data and data.id == "AGGRO" then
						if self.db.showAggroBar and tank_threat and tank_threat > 0 then
							data.valuetext = Skada:FormatValueCols(
								mod_cols.Threat and format_threatvalue(data.threat),
								mod_cols.TPS and get_tps(data.threat),
								mod_cols.Percent and Skada:FormatPercent(data.value, max(0.000001, max_threat))
							)

							if win.metadata then
								win.metadata.maxvalue = self.db.rawvalue and data.threat or data.value
							end
						else
							data.id = nil
						end
					elseif data and data.id then
						if data.threat and data.threat > 0 then
							-- Warn if this is ourselves and we are over the treshold.
							local percent = 100 * data.value / max(0.000001, max_threat)
							if data.id == Skada.userGUID then
								my_percent = percent
								if self.db.threshold and self.db.threshold < percent and (not data.isTanking or not self.db.notankwarnings) then
									we_should_warn = (data.color == nil)
								end
							end

							data.valuetext = Skada:FormatValueCols(
								mod_cols.Threat and format_threatvalue(data.threat),
								mod_cols.TPS and get_tps(data.threat),
								mod_cols.Percent and Skada:FormatPercent(percent)
							)
						else
							data.id = nil
						end
					end
				end

				-- Warn
				if we_should_warn and time() - last_warn > (self.db.frequency or 2) then
					self:Warn(self.db.sound, self.db.flash, self.db.shake, my_percent and format(L["%d%% Threat"], my_percent) or L["High Threat"])
					last_warn = time()
				end
			end
		end

		function mod:CombatLeave()
			tank_threat, tank_value = nil, nil
			clear(threat_table)
			self.unitID, self.unitName = nil, nil
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
		local WrapTextInColorCode = private.WrapTextInColorCode
		local RGBPercToHex = private.RGBPercToHex
		local white = HIGHLIGHT_FONT_COLOR

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
					text = WrapTextInColorCode(text, RGBPercToHex(r or 0, g or 0, b or 0, true))
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
			name = mod.localeName,
			desc = format(L["Options for %s."], mod.localeName),
			get = function(i)
				return mod.db[i[#i]]
			end,
			set = function(i, val)
				mod.db[i[#i]] = val
				mod:ApplySettings()
			end,
			args = {
				header = {
					type = "description",
					name = mod.localeName,
					fontSize = "large",
					image = aggro_icon,
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
					order = 1
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
							desc = L["opt_threat_soundfile_desc"],
							order = 60,
							width = "double",
							dialogControl = "LSM30_Sound",
							values = Skada:MediaList("sound"),
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
							desc = L["opt_threat_threshold_desc"],
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
					desc = L["opt_threat_rawvalue_desc"],
					order = 20
				},
				focustarget = {
					type = "toggle",
					name = L["Use focus target"],
					desc = L["opt_threat_focustarget_desc"],
					order = 30
				},
				notankwarnings = {
					type = "toggle",
					name = L["Disable while tanking"],
					desc = L["opt_threat_notankwarnings_desc"],
					order = 40
				},
				ignorePets = {
					type = "toggle",
					name = L["Ignore Pets"],
					desc = L["opt_threat_ignorepets_desc"],
					order = 50
				},
				showAggroBar = {
					type = "toggle",
					name = L["Show Pull Aggro Bar"],
					desc = L["opt_threat_showaggrobar_desc"],
					order = 60
				},
				sep = {
					type = "description",
					name = " ",
					width = "full",
					order = 90
				},
				test = {
					type = "execute",
					name = L["Test Warnings"],
					width = "double",
					order = 100,
					func = function()
						mod:Warn(mod.db.sound, mod.db.flash, mod.db.shake, mod.db.message and L["Test Warnings"])
					end
				}
			}
		}

		function mod:OnInitialize()
			if not M.threat then
				M.threat = {
					sound = true,
					flash = true,
					output = 1,
					frequency = 2,
					threshold = 90,
					soundfile = "Fel Nova",
					notankwarnings = true,
					ignorePets = true,
					showAggroBar = true
				}
			end
			if M.threat.sinkOptions then
				M.threat.sinkOptions = nil
			end

			M.threat.output = M.threat.output or 1
			self.db = M.threat
			Skada.options.args.modules.args.threat = opts
		end
	end

	do
		local function add_threat_feed()
			if Skada.current and UnitExists("target") then
				local _, _, threatpct = UnitDetailedThreatSituation("player", "target")
				return threatpct and Skada:FormatPercent(threatpct)
			end
		end

		function mod:OnEnable()
			self.metadata = {
				wipestale = true,
				columns = {Threat = true, TPS = false, Percent = true},
				notitleset = true, -- ignore title set
				icon = aggro_icon
			}

			mod_cols = self.metadata.columns

			Skada.RegisterBucketEvent(self, "UNIT_THREAT_LIST_UPDATE", 0.1, "SetUnit")
			Skada.RegisterBucketEvent(self, "UNIT_THREAT_SITUATION_UPDATE", 0.1, "SetUnit")
			Skada.RegisterBucketEvent(self, "PLAYER_TARGET_CHANGED", 0.1, "SetUnit")

			Skada.RegisterCallback(self, "Skada_ApplySettings", "ApplySettings")
			Skada.RegisterMessage(self, "COMBAT_PLAYER_LEAVE", "CombatLeave")

			Skada:AddFeed(L["Threat: Personal Threat"], add_threat_feed)
			Skada:AddMode(self)
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllBuckets(self)
		Skada.UnregisterAllCallbacks(self)
		Skada.UnregisterAllMessages(self)

		Skada:RemoveFeed(L["Threat: Personal Threat"])
		Skada:RemoveMode(self)
	end

	function mod:ApplySettings()
		self.db = self.db or M.threat
		if self.db.focustarget then
			Skada.RegisterEvent(self, "UNIT_TARGET")
		else
			Skada.UnregisterEvent(self, "UNIT_TARGET")
		end
	end

	do
		local UnitIsPlayer = UnitIsPlayer
		local UnitCanAttack = UnitCanAttack
		local UnitHealth = UnitHealth

		local throttleFrame = CreateFrame("Frame")
		local threatUnits = {"focus", "focustarget", "target", "targettarget"}

		local function find_threat_unit()
			mod.unitID, mod.unitName = nil, nil -- reset

			local n = mod.db.focustarget and 1 or 3
			for i = n, 4 do
				local unit = threatUnits[i]
				if UnitExists(unit) and not UnitIsPlayer(unit) and UnitCanAttack("player", unit) and UnitHealth(unit) > 0 then
					mod.unitID = unit
					mod.unitName = UnitName(unit)
					break
				end
			end

			throttleFrame:Hide()
		end

		throttleFrame:Hide()
		throttleFrame:SetScript("OnUpdate", find_threat_unit)

		function mod:SetUnit()
			throttleFrame:Show()
		end

		function mod:UNIT_TARGET(_, unit)
			if unit == "focus" and self.db.focustarget and self.unitID == "focustarget" then
				throttleFrame:Show()
			end
		end
	end
end)
