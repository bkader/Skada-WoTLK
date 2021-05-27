assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Friendly Fire", function(Skada, L)
	if Skada:IsDisabled("Friendly Fire") then return end

	local mod = Skada:NewModule(L["Friendly Fire"])
	local spellmod = mod:NewModule(L["Damage spell list"])
	local targetmod = mod:NewModule(L["Damage target list"])

	local _pairs, _select, _format = pairs, select, string.format
	local _UnitClass, _GetSpellInfo = Skada.UnitClass, Skada.GetSpellInfo or GetSpellInfo

	local function log_damage(set, dmg)
		local player = Skada:get_player(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if player then
			-- add player and set friendly fire:
			player.friendfire = player.friendfire or {amount = 0}
			player.friendfire.amount = (player.friendfire.amount or 0) + dmg.amount
			set.friendfire = (set.friendfire or 0) + dmg.amount

			-- save the spell first.
			if dmg.spellid then
				player.friendfire.spells = player.friendfire.spells or {}
				if not player.friendfire.spells[dmg.spellid] then
					player.friendfire.spells[dmg.spellid] = {school = dmg.spellschool, amount = dmg.amount}
				else
					player.friendfire.spells[dmg.spellid].amount = (player.friendfire.spells[dmg.spellid].amount or 0) + dmg.amount
				end
			end

			-- record targets
			if dmg.dstName then
				player.friendfire.targets = player.friendfire.targets or {}
				if not player.friendfire.targets[dmg.dstName] then
					player.friendfire.targets[dmg.dstName] = {id = dmg.dstGUID, flags = data.dstFlags, amount = dmg.amount}
				else
					player.friendfire.targets[dmg.dstName].amount = (player.friendfire.targets[dmg.dstName].amount or 0) + dmg.amount
				end
			end
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local spellid, spellname, spellschool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...

			dmg.playerid = srcGUID
			dmg.playername = srcName
			dmg.playerflags = srcFlags

			dmg.dstGUID = dstGUID
			dmg.dstName = dstName
			dmg.dstFlags = dstFlags

			dmg.spellid = spellid
			dmg.spellschool = school
			dmg.amount = (amount or 0) + (overkill or 0) + (absorbed or 0)

			log_damage(Skada.current, dmg)
			log_damage(Skada.total, dmg)
		end
	end

	local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local amount, overkill, school, resisted, blocked, absorbed = ...
			dmg.playerid = srcGUID
			dmg.playername = srcName
			dmg.playerflags = srcFlags

			dmg.dstGUID = dstGUID
			dmg.dstName = dstName
			dmg.dstFlags = dstFlags

			dmg.spellid = 6603
			dmg.spellschool = 1
			dmg.amount = (amount or 0) + (overkill or 0) + (absorbed or 0)

			log_damage(Skada.current, dmg)
			log_damage(Skada.total, dmg)
		end
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's targets"], player.name)
			local total = player.friendfire and player.friendfire.amount or 0

			if total > 0 and player.friendfire.targets then
				local maxvalue, nr = 0, 1

				for targetname, target in _pairs(player.friendfire.targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = target.id or targetname
					d.label = targetname
					d.class, d.role, d.spec = _select(2, _UnitClass(target.id, target.flags, set))

					d.value = target.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(target.amount),
						mod.metadata.columns.Damage,
						_format("%.1f%%", 100 * target.amount / total),
						mod.metadata.columns.Percent
					)

					if target.amount > maxvalue then
						maxvalue = target.amount
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = _format(L["%s's damage"], label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = _format(L["%s's damage"], player.name)
			local total = player.friendfire and player.friendfire.amount or 0

			if total > 0 and player.friendfire.spells then
				local maxvalue, nr = 0, 1

				for spellid, spell in _pairs(player.friendfire.spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					local spellname, _, spellicon = _GetSpellInfo(spellid)
					d.id = spellid
					d.spellid = spellid
					d.label = spellname
					d.icon = spellicon
					d.spellschool = spell.school

					d.value = spell.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(spell.amount),
						mod.metadata.columns.Damage,
						_format("%.1f%%", 100 * spell.amount / total),
						mod.metadata.columns.Percent
					)

					if spell.amount > maxvalue then
						maxvalue = spell.amount
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function mod:Update(win, set)
		win.title = L["Friendly Fire"]
		local total = set.friendfire or 0

		if total > 0 then
			local maxvalue, nr = 0, 1

			for _, player in Skada:IteratePlayers(set) do
				if player.friendfire and (player.friendfire.amount or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.altname or player.name
					d.class = player.class or "PET"
					d.role = player.role
					d.spec = player.spec

					d.value = player.friendfire.amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(player.friendfire.amount),
						self.metadata.columns.Damage,
						_format("%.1f%%", 100 * player.friendfire.amount / total),
						self.metadata.columns.Percent
					)

					if player.friendfire.amount > maxvalue then
						maxvalue = player.friendfire.amount
					end

					nr = nr + 1
				end
			end
			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		targetmod.metadata = {showspots = true}
		self.metadata = {
			showspots = true,
			click1 = spellmod,
			click2 = targetmod,
			columns = {Damage = true, Percent = true},
			icon = "Interface\\Icons\\inv_gizmo_supersappercharge"
		}

		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return Skada:FormatNumber(set.friendfire or 0)
	end
end)