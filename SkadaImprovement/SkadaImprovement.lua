local Skada = _G.Skada
if not Skada then return end
Skada:RegisterModule("Improvement", function(L)
	local mod = Skada:NewModule("Improvement")
	local mod_modes = mod:NewModule("Improvement modes")
	local mod_comparison = mod:NewModule("Improvement comparison")

	local pairs, date, tostring = pairs, date, tostring
	local windows = Skada.windows
	local userGUID = Skada.userGUID or UnitGUID("player")

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

	updaters.ActiveTime = function(set, actor)
		return Skada:GetActiveTime(set, actor, true)
	end

	updaters.Damage = function(set, actor)
		return actor.damage
	end

	updaters.DamageTaken = function(set, actor)
		return actor.damaged
	end

	updaters.Deaths = function(set, actor)
		return actor.deaths or actor.death
	end

	updaters.Healing = function(set, actor)
		if actor.heal or actor.absorb then
			return (actor.heal or 0) + (actor.absorb or 0)
		end
	end

	updaters.Overhealing = function(set, actor)
		return actor.overheal
	end

	updaters.Interrupts = function(set, actor)
		return actor.interrupt
	end

	updaters.Dispels = function(set, actor)
		return actor.dispel
	end

	updaters.Fails = function(set, actor)
		return actor.fail
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
		for i = 1, #boss.encounters do
			local encounter = boss.encounters[i]
			if encounter and encounter.starttime == starttime then
				return encounter
			end
		end

		boss.encounters[#boss.encounters + 1] = {starttime = starttime, data = {}}
		return find_encounter_data(boss, starttime)
	end

	function mod_comparison:Enter(win, id, label)
		win.targetid, win.modename = id, revlocalized[label] or label
		win.title = (win.targetname or L["Unknown"]) .. " - " .. label
	end

	function mod_comparison:Update(win, set)
		win.title = (win.targetname or L["Unknown"]) .. " - " .. (localized[win.modename] or win.modename)
		local boss = win.modename and win.targetname and find_boss_data(win.targetname)

		if not boss or not boss.encounters then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for i = 1, #boss.encounters do
			local encounter = boss.encounters[i]
			local value = encounter and encounter.data and encounter.data[win.modename]
			if value and value > 0 then
				nr = nr + 1

				local d = win:nr(nr)
				d.id = i
				d.label = date("%x %X", encounter.starttime)
				d.value = value
				if win.modename == "ActiveTime" then
					d.valuetext = Skada:FormatTime(d.value)
				elseif win.modename == "Deaths" or win.modename == "Interrupts" or win.modename == "Fails" then
					d.valuetext = tostring(d.value)
				else
					d.valuetext = Skada:FormatValueCols(
						Skada:FormatNumber(d.value),
						Skada:FormatNumber((d.value) / max(1, encounter.data.ActiveTime or 0))
					)
				end

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod_modes:Enter(win, id, label)
		win.targetid, win.targetname = id, label
		win.title = L["%s's overall data"]:format(label)
	end

	function mod_modes:Update(win, set)
		win.title = L["%s's overall data"]:format(win.targetname or L["Unknown"])
		local boss = win.targetname and find_boss_data(win.targetname)

		if not boss then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 1
		end

		local nr = 0
		for i = 1, #modes do
			local mode = modes[i]
			local value = 0
			for j = 1, #boss.encounters do
				value = value + (boss.encounters[j].data[mode] or 0)
			end
			if value > 0 then
				nr = nr + 1

				local d = win:nr(nr)
				d.id = i
				d.label = localized[mode] or mode
				d.value = value

				if mode == "ActiveTime" then
					d.valuetext = Skada:FormatTime(d.value)
				elseif mode == "Deaths" or mode == "Interrupts" or mode == "Fails" then
					d.valuetext = tostring(d.value)
				else
					d.valuetext = Skada:FormatNumber(d.value)
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Improvement"]
		if not self.db then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for name, data in pairs(self.db) do
			nr = nr + 1

			local d = win:nr(nr)
			d.id = name
			d.label = name
			d.class = "BOSS"
			d.value = data.count
			d.valuetext = tostring(data.count)

			if win.metadata and d.value > win.metadata.maxvalue then
				win.metadata.maxvalue = d.value
			end
		end
	end

	function mod:OnInitialize()
		if self.db then return end

		SkadaImprovementDB = SkadaImprovementDB or {}
		self.db = SkadaImprovementDB
	end

	function mod:BossDefeated(_, set)
		if not set or set.type ~= "raid" or not set.success then return end

		local boss = find_boss_data(set.mobname)
		if not boss then return end

		local encounter = find_encounter_data(boss, set.starttime)
		if not encounter then return end

		local actors = set.actors
		for _, actor in pairs(actors) do
			if actor.id == userGUID then
				for j = 1, #modes do
					local mode = modes[j]
					if mode and updaters[mode] then
						encounter.data[mode] = updaters[mode](set, actor)
					elseif mode then
						encounter.data[mode] = actor[mode:lower()]
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

	function mod:OnEnable()
		userGUID = userGUID or Skada.userGUID or UnitGUID("player")
		self:OnInitialize()

		mod_comparison.metadata = {notitleset = true}
		mod_modes.metadata = {click1 = mod_comparison, notitleset = true}
		self.metadata = {
			click1 = mod_modes,
			notitleset = true, -- ignore title set
			icon = [[Interface\ICONS\ability_warrior_intensifyrage]]
		}

		Skada.RegisterMessage(self, "COMBAT_BOSS_DEFEATED", "BossDefeated")
		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada.UnregisterAllMessages(self)
		Skada:RemoveMode(self)
	end

	local function ask_for_reset()
		if not StaticPopupDialogs["SkadaResetImprovementDialog"] then
			StaticPopupDialogs["SkadaResetImprovementDialog"] = {
				text = L["Do you want to reset your improvement data?"],
				button1 = L["Accept"],
				button2 = L["Cancel"],
				timeout = 30,
				whileDead = 0,
				hideOnEscape = 1,
				OnAccept = function()
					mod:Reset()
				end
			}
		end
		StaticPopup_Show("SkadaResetImprovementDialog")
	end

	function mod:Reset()
		Skada:Wipe()
		SkadaImprovementDB = wipe(SkadaImprovementDB or {})
		self.db = SkadaImprovementDB
		self:OnInitialize()

		for i = 1, #windows do
			local win = windows[i]
			local mode = (win and win.db) and win.db.mode or nil
			if mode == "Improvement" or mode == "Improvement modes" or mode == "Improvement comparison" then
				win:DisplayMode(mod)
			end
		end

		Skada:UpdateDisplay(true)
		Skada:Print(L["All data has been reset."])
	end

	local Default_ShowPopup = Skada.ShowPopup
	function Skada:ShowPopup(win, force)
		if win and win.db and win.db.mode == "Improvement" then
			ask_for_reset()
			return
		end

		return Default_ShowPopup(Skada, win, force)
	end
end)
