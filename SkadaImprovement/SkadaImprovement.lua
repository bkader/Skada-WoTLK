local Skada = _G.Skada
if not Skada then return end
Skada:AddLoadableModule("Improvement", function(Skada, L)
	if Skada:IsDisabled("Improvement") then return end

	local mod = Skada:NewModule(L["Improvement"])
	local mod_modes = mod:NewModule(L["Improvement modes"])
	local mod_comparison = mod:NewModule(L["Improvement comparison"])

	local pairs, ipairs, select = pairs, ipairs, select
	local date, tostring = date, tostring
	local playerid = UnitGUID("player")

	local modes = {
		"ActiveTime",
		"Damage",
		"DamageTaken",
		"Deaths",
		"Dispels",
		"Fails",
		"Healing",
		"Interrupts",
		"Overhealing"
	}

	local localized = {
		ActiveTime = L["Active Time"],
		Damage = L["Damage Done"],
		DamageTaken = L["Damage Taken"],
		Deaths = L["Deaths"],
		Dispels = L["Dispels"],
		Fails = L["Fails"],
		Healing = L["Healing"],
		Interrupts = L["Interrupts"],
		Overhealing = L["Overhealing"]
	}

	local revlocalized = {
		[L["Active Time"]] = "ActiveTime",
		[L["Damage Done"]] = "Damage",
		[L["Damage Taken"]] = "DamageTaken",
		[L["Deaths"]] = "Deaths",
		[L["Dispels"]] = "Dispels",
		[L["Fails"]] = "Fails",
		[L["Healing"]] = "Healing",
		[L["Interrupts"]] = "Interrupts",
		[L["Overhealing"]] = "Overhealing"
	}

	local updaters = {}

	updaters.ActiveTime = function(set, player)
		return Skada:PlayerActiveTime(set, player, true)
	end

	updaters.Damage = function(set, player)
		return player.damage or 0
	end

	updaters.DamageTaken = function(set, player)
		return player.damagetaken or 0
	end

	updaters.Deaths = function(set, player)
		return player.deaths or 0
	end

	updaters.Healing = function(set, player)
		return (player.heal or 0) + (player.absorb or 0)
	end

	updaters.Overhealing = function(set, player)
		return player.overheal or 0
	end

	updaters.Interrupts = function(set, player)
		return player.interrupt or 0
	end

	updaters.Dispels = function(set, player)
		return player.dispel or 0
	end

	updaters.Fails = function(set, player)
		return player.fail or 0
	end

	local function find_boss_data(bossname)
		if not bossname then
			return
		end
		mod.db = mod.db or {}
		for k, v in pairs(mod.db) do
			if k == bossname then
				return v
			end
		end

		mod.db[bossname] = {count = 0, encounters = {}}
		return find_boss_data(bossname)
	end

	local function find_encounter_data(boss, starttime)
		for i, encounter in ipairs(boss.encounters) do
			if encounter.starttime == starttime then
				return encounter
			end
		end

		tinsert(boss.encounters, {starttime = starttime, data = {}})
		return find_encounter_data(boss, starttime)
	end

	function mod_comparison:Enter(win, id, label)
		win.targetid, win.modename = id, revlocalized[label] or label
		win.title = (win.targetname or UNKNOWN) .. " - " .. label
	end

	function mod_comparison:Update(win, set)
		win.title = (win.targetname or UNKNOWN) .. " - " .. (localized[win.modename] or win.modename)
		local boss = find_boss_data(win.targetname)

		if boss and boss.encounters then
			local maxvalue, nr = 0, 1

			for i, encounter in ipairs(boss.encounters) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = i
				d.label = date("%x %X", encounter.starttime)

				d.value = encounter.data[win.modename] or 0
				if win.modename == "ActiveTime" then
					d.valuetext = Skada:FormatTime(d.value)
				elseif win.modename == "Deaths" or win.modename == "Interrupts" or win.modename == "Fails" then
					d.valuetext = tostring(d.value)
				else
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value), true,
						Skada:FormatNumber((d.value) / max(1, encounter.data.ActiveTime or 0)), true
					)
				end

				if d.value > maxvalue then
					maxvalue = d.value
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod_modes:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["%s's overall data"]:format(label)
	end

	function mod_modes:Update(win, set)
		win.title = L["%s's overall data"]:format(win.targetname or UNKNOWN)
		local boss = find_boss_data(win.targetname)

		if boss then
			win.metadata.maxvalue = 1
			local nr = 1
			for i, mode in ipairs(modes) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = i
				d.label = localized[mode] or mode

				local value, active = 0, 0

				for _, encounter in ipairs(boss.encounters) do
					value = value + (encounter.data[mode] or 0)
					active = active + (encounter.data.ActiveTime or 0)
				end

				d.value = value

				if mode == "ActiveTime" then
					d.valuetext = Skada:FormatTime(d.value)
				elseif mode == "Deaths" or mode == "Interrupts" or mode == "Fails" then
					d.valuetext = tostring(d.value)
				else
					d.valuetext = Skada:FormatNumber(d.value)
				end
				nr = nr + 1
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Improvement"]

		if self.db then
			local maxvalue, nr = 0, 1

			for name, data in pairs(self.db) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = name
				d.label = name
				d.class = "BOSS"
				d.value = data.count
				d.valuetext = tostring(data.count)

				if data.count > maxvalue then
					maxvalue = data.count
				end
				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnInitialize()
		if not self.db then
			SkadaImprovementDB = SkadaImprovementDB or {}

			-- get back old data
			if Skada.char.improvement then
				if Skada.char.improvement.bosses then
					SkadaImprovementDB = CopyTable(Skada.char.improvement.bosses or {})
				else
					SkadaImprovementDB = CopyTable(Skada.char.improvement)
				end
				Skada.char.improvement = nil
			end

			self.db = SkadaImprovementDB
		end
	end

	function mod:BossDefeated(event, set)
		if event == "COMBAT_BOSS_DEFEATED" and set and set.success then
			-- we only record raid bosses, nothing else.
			local inInstance, instanceType = IsInInstance()
			if not inInstance or instanceType ~= "raid" then return end

			local boss = find_boss_data(set.mobname)
			if not boss then return end

			local encounter = find_encounter_data(boss, set.starttime)
			if not encounter then return end

			for _, player in ipairs(set.players) do
				if player.id == playerid then
					for _, mode in ipairs(modes) do
						if updaters[mode] then
							encounter.data[mode] = updaters[mode](set, player)
						else
							encounter.data[mode] = player[mode:lower()]
						end
					end
					-- increment boss count and stop
					boss.count = boss.count + 1
					if boss.count ~= #boss.encounters then
						boss.count = #boss.encounters
					end
					break
				end
			end
		end
	end

	function mod:OnEnable()
		playerid = playerid or UnitGUID("player")
		self:OnInitialize()

		mod_comparison.metadata = {}
		mod_modes.metadata = {click1 = mod_comparison}
		self.metadata = {click1 = mod_modes, icon = "Interface\\Icons\\ability_warrior_intensifyrage"}

		-- ignore title set
		self.notitleset = true
		mod_modes.notitleset = true
		mod_comparison.notitleset = true

		Skada.RegisterCallback(self, "COMBAT_BOSS_DEFEATED", "BossDefeated")
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada.UnregisterAllCallbacks(self)
		Skada:RemoveMode(self)
	end

	local function ask_for_reset()
		StaticPopupDialogs["ResetImprovementDialog"] = {
			text = L["Do you want to reset your improvement data?"],
			button1 = ACCEPT,
			button2 = CANCEL,
			timeout = 30,
			whileDead = 0,
			hideOnEscape = 1,
			OnAccept = function()
				mod:Reset()
			end
		}
		StaticPopup_Show("ResetImprovementDialog")
	end

	function mod:Reset()
		Skada:Wipe()
		SkadaImprovementDB = wipe(SkadaImprovementDB or {})
		self.db = nil
		self:OnInitialize()
		collectgarbage("collect")
		for _, win in ipairs(Skada:GetWindows()) do
			local mode = win.db.mode
			if mode == L["Improvement"] or mode == L["Improvement modes"] or mode == L["Improvement comparison"] then
				win:DisplayMode(mod)
			end
		end
		Skada:UpdateDisplay(true)
		Skada:Print(L["All data has been reset."])
	end

	local Default_ShowPopup = Skada.ShowPopup
	function Skada:ShowPopup(win, force)
		if win and win.db and win.db.mode == L["Improvement"] then
			ask_for_reset()
			return
		end

		return Default_ShowPopup(Skada, win, force)
	end
end)