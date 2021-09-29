assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Friendly Fire", function(Skada, L)
	if Skada:IsDisabled("Friendly Fire") then return end

	local mod = Skada:NewModule(L["Friendly Fire"])
	local spellmod = mod:NewModule(L["Damage spell list"])
	local targetmod = mod:NewModule(L["Damage target list"])

	local pairs, ipairs, select, format = pairs, ipairs, select, string.format
	local GetSpellInfo, tContains = Skada.GetSpellInfo or GetSpellInfo, tContains
	local _

	-- spells in the following table will be ignored.
	local ignoredSpells = {}

	local function log_damage(set, dmg)
		if dmg.spellid and tContains(ignoredSpells, dmg.spellid) then return end

		local player = Skada:get_player(set, dmg.playerid, dmg.playername, dmg.playerflags)
		if player then
			Skada:AddActiveTime(player, dmg.amount > 0)

			player.friendfire = (player.friendfire or 0) + dmg.amount
			set.friendfire = (set.friendfire or 0) + dmg.amount

			-- spell
			player.friendfire_spells = player.friendfire_spells or {}
			player.friendfire_spells[dmg.spellid] = (player.friendfire_spells[dmg.spellid] or 0) + dmg.amount

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.current and dmg.dstName then
				player.friendfire_targets = player.friendfire_targets or {}
				player.friendfire_targets[dmg.dstName] = (player.friendfire_targets[dmg.dstName] or 0) + dmg.amount
			end
		end
	end

	local dmg = {}

	local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if srcGUID ~= dstGUID then
			local spellid, _, _, amount, overkill, _, _, _, absorbed = ...

			dmg.playerid = srcGUID
			dmg.playername = srcName
			dmg.playerflags = srcFlags

			dmg.dstName = dstName
			dmg.spellid = spellid
			dmg.amount = (amount or 0) + (overkill or 0) + (absorbed or 0)

			log_damage(Skada.current, dmg)
			log_damage(Skada.total, dmg)
		end
	end

	local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, 6603, nil, nil, ...)
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's targets"], label)
	end

	function targetmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's targets"], player.name)
			local total = player.friendfire or 0

			if total > 0 and player.friendfire_targets then
				local maxvalue, nr = 0, 1

				for targetname, amount in pairs(player.friendfire_targets) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end

				win.metadata.maxvalue = maxvalue
			end
		end
	end

	function spellmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's damage"], label)
	end

	function spellmod:Update(win, set)
		local player = Skada:find_player(set, win.playerid, win.playername)
		if player then
			win.title = format(L["%s's damage"], player.name)
			local total = player.friendfire or 0

			if total > 0 and player.friendfire_spells then
				local maxvalue, nr = 0, 1

				for spellid, amount in pairs(player.friendfire_spells) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = spellid
					d.spellid = spellid
					d.label, _, d.icon = GetSpellInfo(spellid)

					d.value = amount
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						mod.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						mod.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
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

			for _, player in ipairs(set.players) do
				if (player.friendfire or 0) > 0 then
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id
					d.label = player.name
					d.text = Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.friendfire
					d.valuetext = Skada:FormatValueText(
						Skada:FormatNumber(d.value),
						self.metadata.columns.Damage,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if d.value > maxvalue then
						maxvalue = d.value
					end
					nr = nr + 1
				end
			end
			win.metadata.maxvalue = maxvalue
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			click1 = spellmod,
			click2 = targetmod,
			nototalclick = {targetmod},
			columns = {Damage = true, Percent = true},
			icon = "Interface\\Icons\\inv_gizmo_supersappercharge"
		}

		Skada:RegisterForCL(SpellDamage, "DAMAGE_SHIELD", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "DAMAGE_SPLIT", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "RANGE_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_BUILDING_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_EXTRA_ATTACKS", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SpellDamage, "SPELL_PERIODIC_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
		Skada:RegisterForCL(SwingDamage, "SWING_DAMAGE", {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})

		Skada:AddMode(self, L["Damage Done"])
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		local value = set.friendfire or 0
		return Skada:FormatNumber(value), value
	end
end)