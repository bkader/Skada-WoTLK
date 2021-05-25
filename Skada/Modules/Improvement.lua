assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Improvement", function(Skada, L)
	if Skada:IsDisabled("Improvement") then return end

	local mod = Skada:NewModule(L["Improvement"])
	local mod_modes = mod:NewModule(L["Improvement modes"])
	local mod_comparison = mod:NewModule(L["Improvement comparison"])

	local _UnitGUID, _GetUnitName, _UnitClass = UnitGUID, GetUnitName, UnitClass
	local _pairs, _ipairs, _select = pairs, ipairs, select
	local _format, _tostring = string.format, tostring
	local date = date

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
		return player.damagedone and player.damagedone.amount or 0
	end

	updaters.DamageTaken = function(set, player)
		return player.damagetaken and player.damagetaken.amount or 0
	end

	updaters.Deaths = function(set, player)
		return player.deaths or 0
	end

	updaters.Healing = function(set, player)
		local total = 0
		if player.healing then
			total = total + player.healing.amount
		end
		if player.absorbs then
			total = total + player.absorbs.amount
		end
		return total
	end

	updaters.Overhealing = function(set, player)
		return player.healing and player.healing.overhealing or 0
	end

	updaters.Interrupts = function(set, player)
		return player.interrupts and player.interrupts.count or 0
	end

	updaters.Dispels = function(set, player)
		return player.dispels and player.dispels.count or 0
	end

	updaters.Fails = function(set, player)
		return player.fails and player.fails.count or 0
	end

	local function find_boss_data(bossname)
		if not bossname then
			return
		end
		mod.db = mod.db or {}
		mod.db.bosses = mod.db.bosses or {}
		for k, v in _pairs(mod.db.bosses) do
			if k == bossname then
				return v
			end
		end

		mod.db.bosses[bossname] = {count = 0, encounters = {}}
		return find_boss_data(bossname)
	end

	local function find_encounter_data(boss, starttime)
		for i, encounter in _ipairs(boss.encounters) do
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
		local boss = find_boss_data(win.targetname)
		if boss then
			win.title = (win.targetname or UNKNOWN) .. " - " .. (localized[win.modename] or win.modename)
			local maxvalue, nr = 0, 1

			for i = 1, boss.count do
				local encounter = boss.encounters[i]
				if encounter then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = i
					d.label = date("%x %X", encounter.starttime)

					local value = encounter.data[win.modename]
					d.value = value or 0
					if win.modename == "ActiveTime" then
						d.valuetext = Skada:FormatTime(d.value)
					elseif win.modename == "Deaths" or win.modename == "Interrupts" or win.modename == "Fails" then
						d.valuetext = _tostring(d.value)
					else
						d.valuetext = Skada:FormatValueText(
							Skada:FormatNumber(d.value),
							true,
							Skada:FormatNumber((d.value) / encounter.data.ActiveTime),
							true
						)
					end

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod_modes:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = _format(L["%s's overall data"], label)
	end

	function mod_modes:Update(win, set)
		local boss = find_boss_data(win.targetname)
		if boss then
			win.title = _format(L["%s's overall data"], win.targetname or UNKNOWN)
			local maxvalue, nr = 0, 1

			for i, mode in _ipairs(modes) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = i
				d.label = localized[mode] or mode

				local value, active = 0, 0

				for _, encounter in _ipairs(boss.encounters) do
					value = value + (encounter.data[mode] or 0)
					active = active + (encounter.data.ActiveTime or 0)
				end

				d.value = value

				if mode == "ActiveTime" then
					d.valuetext = Skada:FormatTime(d.value)
				elseif mode == "Deaths" or mode == "Interrupts" or mode == "Fails" then
					d.valuetext = _tostring(d.value)
				else
					d.valuetext = Skada:FormatNumber(d.value)
				end

				if i > maxvalue then
					maxvalue = i
				end

				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:Update(win, set)
		win.title = L["Improvement"]

		if self.db and self.db.bosses then
			local maxvalue, nr = 0, 1

			for name, data in _pairs(self.db.bosses) do
				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = name
				d.label = name
				d.class = "BOSS"
				d.value = data.count
				d.valuetext = _tostring(data.count)

				if data.count > maxvalue then
					maxvalue = data.count
				end

				nr = nr + 1
			end

			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnInitialize()
		-- make our DB local
		Skada.char.improvement = Skada.char.improvement or {}
		if next(Skada.char.improvement) == nil then
			Skada.char.improvement = {
				id = _UnitGUID("player"),
				name = _GetUnitName("player"),
				class = _select(2, _UnitClass("player")),
				bosses = {}
			}
		end
		self.db = Skada.char.improvement
	end

	function mod:BossDefeated(event, set)
		if event == "COMBAT_BOSS_DEFEATED" and set then
			-- we only record raid bosses, nothing else.
			local inInstance, instanceType = IsInInstance()
			if not inInstance or instanceType ~= "raid" then return end

			local boss = find_boss_data(set.mobname)
			if not boss then return end

			local encounter = find_encounter_data(boss, set.starttime)
			if not encounter then return end

			for _, player in Skada:IteratePlayers(set) do
				if player.id == self.db.id then
					for _, mode in _ipairs(modes) do
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
		Skada.char.improvement = {}
		self:OnInitialize()
		collectgarbage("collect")
		for _, win in _ipairs(Skada:GetWindows()) do
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