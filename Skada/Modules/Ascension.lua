-- Project Ascension module
-- this module allows players on classless realms to choose their
-- own custom icons and colors that best represent their builds.
local Skada = Skada
if not Skada.Ascension or Skada.AscensionCoA then return end
Skada:AddLoadableModule("Project Ascension", function(L)
	if Skada:IsDisabled("Project Ascension") then return end

	local mod = Skada:NewModule("Project Ascension", "AceTimer-3.0")

	local type, next = type, next
	local time, wipe, format = time, wipe, string.format
	local RGBPercToHex = Skada.RGBPercToHex

	local patternIcon = [[Interface\Icons\%s]]

	-- a table to hold temporary data.
	local tempData = {}

	local function CheckAscension(data)
		return (type(data) == "table" and type(data[5]) == "string")
	end

	local function round(num)
		return floor(num * 100 + 0.5) / 100
	end

	function mod:OnEvent(event)
		if self.sendCooldown > time() then
			self:ScheduleTimer("SendAscension", 30)
		else
			self:SendAscension()
		end
	end

	function mod:SendAscension(nocooldown)
		self:SetCacheTable()
		if not nocooldown then
			self.sendCooldown = time() + 30
		end
		Skada:SendComm(nil, nil, "Ascension", Skada.userGUID, self.db.player[Skada.userGUID])
	end

	function mod:OnCommAscension(event, sender, guid, data)
		if sender and guid and guid ~= Skada.userGUID and data and CheckAscension(data) then
			self.db.others[guid] = self.db.others[guid] or {}
			for i = 1, #data do
				self.db.others[guid][i] = data[i]
			end
		end
	end

	---------------------------------------------------------------------------
	-- functions that override displays

	local function Ascension_BarDisplay(self, win)
		if win and win.bargroup then
			if not mod.db then
				mod:SetCacheTable()
			end

			for i = 1, #win.dataset do
				local data = win.dataset[i]
				if data and data.id and not (data.ignore or data.spellid or data.hyperlink) then
					if mod.db.others[data.id] then
						if mod.db.others[data.id][1] then
							data.icon = format(patternIcon, mod.db.others[data.id][1])
						end
						data.color = {
							r = mod.db.others[data.id][2],
							g = mod.db.others[data.id][3],
							b = mod.db.others[data.id][4],
							colorStr = mod.db.others[data.id][5]
						}
					elseif mod.db.player[data.id] then
						if mod.db.player[data.id][1] then
							data.icon = format(patternIcon, mod.db.player[data.id][1])
						end
						data.color = {
							r = mod.db.player[data.id][2],
							g = mod.db.player[data.id][3],
							b = mod.db.player[data.id][4],
							colorStr = mod.db.player[data.id][5]
						}
					end
				end
			end

			return self:Orig_Update(win)
		end
	end

	local function Ascension_OthereDisplay(self, win)
		if win and win.frame then
			if not mod.db then
				mod:SetCacheTable()
			end

			for i = 1, #win.dataset do
				local data = win.dataset[i]
				if data and data.id and not data.ignore then
					if mod.db.others[data.id] then
						data.color = {
							r = mod.db.others[data.id][2],
							g = mod.db.others[data.id][3],
							b = mod.db.others[data.id][4],
							colorStr = mod.db.others[data.id][5]
						}
					elseif mod.db.player[data.id] then
						data.color = {
							r = mod.db.player[data.id][2],
							g = mod.db.player[data.id][3],
							b = mod.db.player[data.id][4],
							colorStr = mod.db.player[data.id][5]
						}
					end
				end
			end

			return self:Orig_Update(win)
		end
	end

	function mod:OnEnable()
		self.sendCooldown = 0
		self:SetCacheTable()

		Skada.RegisterCallback(self, "Skada_UpdateCore", "Reset")
		Skada.RegisterCallback(self, "OnCommAscension")
		Skada:RegisterMessage("GROUP_ROSTER_UPDATE", self.OnEvent, self)
		self:OnEvent()

		-- override display modules.
		local display = Skada:GetModule("BarDisplay", true)
		if display then
			display.Orig_Update = display.Update
			display.Update = Ascension_BarDisplay
		end
		display = Skada:GetModule("InlineDisplay", true)
		if display then
			display.Orig_Update = display.Update
			display.Update = Ascension_OthereDisplay
		end
		display = Skada:GetModule(L["Data Text"], true)
		if display then
			display.Orig_Update = display.Update
			display.Update = Ascension_OthereDisplay
		end
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada.UnregisterAllMessages(self)
	end

	function mod:OnInitialize()
		self:SetCacheTable()

		Skada.options.args.tweaks.args.advanced.args.ascension = {
			type = "group",
			name = self.moduleName,
			desc = format(L["Options for %s."], self.moduleName),
			order = 0,
			args = {
				ascensionlogo = {
					type = "description",
					name = "",
					image = [[Interface\AddOns\Skada\Media\Textures\icon-ascension]],
					imageWidth = 32,
					imageHeight = 32,
					imageCoords = {0.062, 0.938, 0.062, 0.938},
					width = "full",
					order = 0
				},
				ascensiondesc = {
					type = "description",
					name = L["project_ascension_desc"],
					fontSize = "medium",
					width = "full",
					order = 10
				},
				empty_1 = {
					type = "description",
					name = " ",
					width = "full",
					order = 20
				},
				icon = {
					type = "input",
					name = L["Icon"],
					desc = format(
						"%s\n\n|cffffbb00Interface\\Icons\\|r<%s>",
						format(L["Choose the %s that fits your character's build."], L["Icon"]),
						L["Icon"]
					),
					get = function()
						return tempData[1] or Skada.db.global.ascension.player[Skada.userGUID][1]
					end,
					set = function(_, val)
						tempData[1] = val:trim() ~= "" and val
					end,
					order = 30
				},
				color = {
					type = "color",
					name = L["Color"],
					desc = format(L["Choose the %s that fits your character's build."], L["Color"]),
					get = function()
						local r = tempData[2] or Skada.db.global.ascension.player[Skada.userGUID][2]
						local g = tempData[3] or Skada.db.global.ascension.player[Skada.userGUID][3]
						local b = tempData[4] or Skada.db.global.ascension.player[Skada.userGUID][4]
						return r, g, b
					end,
					set = function(_, r, g, b)
						tempData[2] = round(r) or 1
						tempData[3] = round(g) or 1
						tempData[4] = round(b) or 1
						tempData[5] = RGBPercToHex(tempData[2], tempData[3], tempData[4], true)
					end,
					order = 40
				},
				preview = {
					type = "description",
					name = "",
					width = "full",
					image = function()
						return format(patternIcon, tempData[1] or Skada.db.global.ascension.player[Skada.userGUID][1] or "Spell_Lightning_LightningBolt01")
					end,
					imageWidth = 32,
					imageHeight = 32,
					imageCoords = {0.125, 0.875, 0.125, 0.875},
					order = 60
				},
				apply = {
					type = "execute",
					name = SAVE,
					func = function()
						if tempData[1] ~= nil then
							Skada.db.global.ascension.player[Skada.userGUID][1] = tempData[1]
						end
						if tempData[2] ~= nil then
							Skada.db.global.ascension.player[Skada.userGUID][2] = round(tempData[2]) or 1
							Skada.db.global.ascension.player[Skada.userGUID][3] = round(tempData[3]) or 1
							Skada.db.global.ascension.player[Skada.userGUID][4] = round(tempData[4]) or 1
							Skada.db.global.ascension.player[Skada.userGUID][5] = RGBPercToHex(
								Skada.db.global.ascension.player[Skada.userGUID][2],
								Skada.db.global.ascension.player[Skada.userGUID][3],
								Skada.db.global.ascension.player[Skada.userGUID][4],
								true
							)
						end
						wipe(tempData)
						self:SendAscension(true)
						Skada:ApplySettings()
					end,
					disabled = function()
						return (tempData[1] == nil and tempData[2] == nil)
					end,
					width = "double",
					order = 80
				},
				empty_2 = {
					type = "description",
					name = " ",
					width = "full",
					order = 82
				},
				reset = {
					type = "execute",
					name = L["Clear Cache"],
					width = "double",
					order = 90,
					confirm = function()
						return L["Are you sure you want clear cached icons and colors?"]
					end,
					func = function()
						Skada.db.global.ascension.reset = time() + (60 * 60 * 24 * 15)
						wipe(Skada.db.global.ascension.others)
						mod.db = Skada.db.global.ascension
					end,
					disabled = function()
						return next(Skada.db.global.ascension.others) == nil
					end
				}
			}
		}
	end

	---------------------------------------------------------------------------
	-- cache table functions

	do
		local function CheckForReset()
			if not mod.db.reset then
				mod.db.reset = time() + (60 * 60 * 24 * 15)
				mod.db.others = {}
			elseif time() > mod.db.reset then
				mod.db.reset = time() + (60 * 60 * 24 * 15)
				wipe(mod.db.others)
			end
		end

		function mod:SetCacheTable()
			if not self.db then
				if not Skada.db.global.ascension then
					Skada.db.global.ascension = {others = {}, player = {}}
				end

				-- add the curent character data is missing
				if not Skada.db.global.ascension.player[Skada.userGUID] then
					Skada.db.global.ascension.player[Skada.userGUID] = {}

					local mycolor = Skada.classcolors(Skada.userClass)
					Skada.db.global.ascension.player[Skada.userGUID][2] = round(mycolor.r)
					Skada.db.global.ascension.player[Skada.userGUID][3] = round(mycolor.g)
					Skada.db.global.ascension.player[Skada.userGUID][4] = round(mycolor.b)
					Skada.db.global.ascension.player[Skada.userGUID][5] = RGBPercToHex(
						Skada.db.global.ascension.player[Skada.userGUID][2],
						Skada.db.global.ascension.player[Skada.userGUID][3],
						Skada.db.global.ascension.player[Skada.userGUID][4],
						true
					)
				end

				self.db = Skada.db.global.ascension
			end

			CheckForReset()
		end

		function mod:Reset(event)
			if event == "Skada_UpdateCore" then
				if not Skada.db.global.ascension then
					Skada.db.global.ascension = {others = {}, player = {}}
				else
					Skada.db.global.ascension.reset = time() + (60 * 60 * 24 * 15)
					wipe(Skada.db.global.ascension.others)
				end

				-- add the curent character data is missing
				if not Skada.db.global.ascension.player[Skada.userGUID] then
					Skada.db.global.ascension.player[Skada.userGUID] = {}

					local mycolor = Skada.classcolors(Skada.userClass)
					Skada.db.global.ascension.player[Skada.userGUID][2] = round(mycolor.r)
					Skada.db.global.ascension.player[Skada.userGUID][3] = round(mycolor.g)
					Skada.db.global.ascension.player[Skada.userGUID][4] = round(mycolor.b)
					Skada.db.global.ascension.player[Skada.userGUID][5] = RGBPercToHex(
						Skada.db.global.ascension.player[Skada.userGUID][2],
						Skada.db.global.ascension.player[Skada.userGUID][3],
						Skada.db.global.ascension.player[Skada.userGUID][4],
						true
					)
				end

				self.db = Skada.db.global.ascension
			end
		end
	end
end)