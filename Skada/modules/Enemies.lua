local Skada = Skada

-- cache frequently used globals
local _pairs, _ipairs = pairs, ipairs
local _format, _select = string.format, select
local _GetSpellInfo = GetSpellInfo

-- list of miss types
local misstypes = {"ABSORB", "BLOCK", "DEFLECT", "DODGE", "EVADE", "IMMUNE", "MISS", "PARRY", "REFLECT", "RESIST"}

-- ======================== --
-- Enemy damage taken module --
-- ======================== --

Skada:AddLoadableModule(
	"Enemy damage taken",
	function(Skada, L)
		if Skada:IsDisabled("Damage", "Enemy damage taken") then
			return
		end

		local mod = Skada:NewModule(L["Enemy damage taken"])
		local playermod = mod:NewModule(L["Damage taken per player"])

		local cached

		function playermod:Enter(win, id, label)
			self.mobname = label
			self.title = _format(L["Damage on %s"], label)
		end

		function playermod:Update(win, set)
			local max = 0

			if self.mobname and cached[self.mobname] then
				local total = cached[self.mobname].amount
				local nr = 1

				for playername, player in _pairs(cached[self.mobname].players) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or playername
					d.label = playername
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.amount
					d.valuetext =
						Skada:FormatValueText(
						Skada:FormatNumber(player.amount),
						mod.metadata.columns.Damage,
						_format("%02.1f%%", 100 * player.amount / total),
						mod.metadata.columns.Percent
					)

					if player.amount > max then
						max = player.amount
					end

					nr = nr + 1
				end
			end

			win.metadata.maxvalue = max
		end

		function mod:Update(win, set)
			if set.damagedone > 0 then
				cached = {}

				for _, player in _ipairs(set.players) do
					if player.damagedone.amount > 0 then
						for targetname, amount in _pairs(player.damagedone.targets) do
							-- add damage amount to target, but before, we create it if it doesn't exist
							cached[targetname] = cached[targetname] or {amount = 0, players = {}}
							cached[targetname].amount = cached[targetname].amount + amount

							-- add the player to the list and add his/her damage
							if not cached[targetname].players[player.name] then
								cached[targetname].players[player.name] = {
									id = player.id,
									class = player.class,
									role = player.role,
									spec = player.spec,
									amount = 0
								}
							end
							cached[targetname].players[player.name].amount =
								cached[targetname].players[player.name].amount + amount
						end
					end
				end
			end

			local max = 0

			if cached then
				local nr = 1

				for targetname, target in _pairs(cached) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = targetname
					d.label = targetname
					d.value = target.amount
					d.valuetext =
						Skada:FormatValueText(
						Skada:FormatNumber(target.amount),
						mod.metadata.columns.Damage,
						_format("%02.1f%%", 100 * target.amount / set.damagedone),
						mod.metadata.columns.Percent
					)

					if target.amount > max then
						max = target.amount
					end

					nr = nr + 1
				end
			end

			win.metadata.maxvalue = max
		end

		function mod:OnEnable()
			playermod.metadata = {showspots = true}
			mod.metadata = {click1 = playermod, columns = {Damage = true, Percent = true}}

			Skada:AddMode(self, L["Damage done"])
		end

		function mod:OnDisable()
			Skada:RemoveMode(self)
		end

		function mod:GetSetSummary(set)
			return Skada:FormatNumber(set.damagedone or 0)
		end
	end
)

-- ========================= --
-- Enemy damage done module --
-- ========================= --

Skada:AddLoadableModule(
	"Enemy damage done",
	function(Skada, L)
		if Skada:IsDisabled("Damage taken", "Enemy damage done") then
			return
		end

		local mod = Skada:NewModule(L["Enemy damage done"])
		local sourcemod = mod:NewModule(L["Damage done per player"])
		local playermod = mod:NewModule(L["Damage spell list"])
		local spellmod = mod:NewModule(L["Damage spell details"])

		local cached

		local function spellmod_tooltip(win, id, label, tooltip)
			if label == CRIT_ABBR or label == HIT or label == ABSORB or label == BLOCK or label == RESIST then
				local player = Skada:find_player(win:get_selected_set(), playermod.playerid, playermod.playername)
				if not player then
					return
				end

				local spell = player.damagetaken.spells[spellmod.spellname]

				if spell then
					tooltip:AddLine(player.name .. " - " .. spellmod.spellname)

					if spell.school then
						local c = Skada.schoolcolors[spell.school]
						local n = Skada.schoolnames[spell.school]
						if c and n then
							tooltip:AddLine(L[n], c.r, c.g, c.b)
						end
					end

					if label == CRIT_ABBR and spell.criticalamount then
						tooltip:AddDoubleLine(L["Minimum"], Skada:FormatNumber(spell.criticalmin), 255, 255, 255)
						tooltip:AddDoubleLine(L["Maximum"], Skada:FormatNumber(spell.criticalmax), 255, 255, 255)
						tooltip:AddDoubleLine(L["Average"], Skada:FormatNumber(spell.criticalamount / spell.critical), 255, 255, 255)
					end

					if label == HIT and spell.hitamount then
						tooltip:AddDoubleLine(L["Minimum hit:"], Skada:FormatNumber(spell.hitmin), 255, 255, 255)
						tooltip:AddDoubleLine(L["Maximum hit:"], Skada:FormatNumber(spell.hitmax), 255, 255, 255)
						tooltip:AddDoubleLine(L["Average hit:"], Skada:FormatNumber(spell.hitamount / spell.hit), 255, 255, 255)
					elseif label == ABSORB and spell.absorbed > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.absorbed), 255, 255, 255)
					elseif label == BLOCK and spell.blocked > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.blocked), 255, 255, 255)
					elseif label == RESISTED and spell.resisted > 0 then
						tooltip:AddDoubleLine(L["Amount"], Skada:FormatNumber(spell.resisted), 255, 255, 255)
					end
				end
			end
		end

		local function add_detail_bar(win, nr, title, value)
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.id = title
			d.label = title
			d.value = value
			d.valuetext =
				Skada:FormatValueText(
				value,
				mod.metadata.columns.Damage,
				_format("%02.1f%%", value / win.metadata.maxvalue * 100),
				mod.metadata.columns.Percent
			)
		end

		function spellmod:Enter(win, id, label)
			self.spellname = label
			self.title = _format(L["%s's damage on %s"], label, playermod.playername)
		end

		function spellmod:Update(win, set)
			local player = Skada:find_player(set, playermod.playerid)

			if player then
				local nr = 1

				for spellname, spell in _pairs(player.damagetaken.spells) do
					if spellname == self.spellname then
						win.metadata.maxvalue = spell.totalhits

						if spell.hit and spell.hit > 0 then
							add_detail_bar(win, nr, HIT, spell.hit)
							nr = nr + 1
						end

						if spell.critical and spell.critical > 0 then
							add_detail_bar(win, nr, CRIT_ABBR, spell.critical)
							nr = nr + 1
						end

						if spell.glancing and spell.glancing > 0 then
							add_detail_bar(win, nr, L["Glancing"], spell.glancing)
							nr = nr + 1
						end

						if spell.crushing and spell.crushing > 0 then
							add_detail_bar(win, nr, L["Crushing"], spell.crushing)
							nr = nr + 1
						end

						for i, misstype in _ipairs(misstypes) do
							if spell[misstype] and spell[misstype] > 0 then
								local title = _G[misstype] or _G["ACTION_SPELL_MISSED" .. misstype] or misstype
								add_detail_bar(win, nr, title, spell[misstype])
								nr = nr + 1
							end
						end
					end
				end
			end
		end

		function playermod:Enter(win, id, label)
			self.playerid = id
			self.playername = label
			self.title = _format(L["%s's damage on %s"], sourcemod.mobname, label)
		end

		function playermod:Update(win, set)
			local max = 0

			if cached[sourcemod.mobname] and cached[sourcemod.mobname].targets[self.playerid] then
				local player = Skada:find_player(set, self.playerid)
				if player then
					local nr = 1
					local total = cached[sourcemod.mobname].targets[self.playerid]

					for spellname, spell in _pairs(player.damagetaken.spells) do
						if spell.source == sourcemod.mobname or spellname:find(sourcemod.mobname) then
							local d = win.dataset[nr] or {}
							win.dataset[nr] = d

							d.id = spellname
							d.spellid = spell.id
							d.label = spellname
							d.icon = _select(3, _GetSpellInfo(spell.id))

							d.value = spell.amount
							d.valuetext =
								Skada:FormatValueText(
								Skada:FormatNumber(spell.amount),
								mod.metadata.columns.Damage,
								_format("%02.1f%%", 100 * spell.amount / total),
								mod.metadata.columns.Percent
							)

							if spell.amount > max then
								max = spell.amount
							end

							nr = nr + 1
						end
					end
				end
			end

			win.metadata.maxvalue = max
		end

		function sourcemod:Enter(win, id, label)
			self.mobname = label
			self.title = _format(L["Damage from %s"], label)
		end

		function sourcemod:Update(win, set)
			local max = 0

			if self.mobname and cached[self.mobname] then
				local mob = cached[self.mobname]
				local nr = 1

				for playerid, amount in _pairs(mob.targets) do
					local player = Skada:find_player(set, playerid)
					if player then
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d

						d.id = playerid
						d.label = player.name
						d.class = player.class
						d.role = player.role
						d.spec = player.spec

						d.value = amount
						d.valuetext =
							Skada:FormatValueText(
							Skada:FormatNumber(amount),
							mod.metadata.columns.Damage,
							_format("%02.1f%%", 100 * amount / mob.amount),
							mod.metadata.columns.Percent
						)

						if amount > max then
							max = amount
						end

						nr = nr + 1
					end
				end
			end

			win.metadata.maxvalue = max
		end

		function mod:Update(win, set)
			if set.damagetaken > 0 then
				cached = {}

				for _, player in _ipairs(set.players) do
					if player.damagetaken.amount > 0 then
						for sourcename, amount in _pairs(player.damagetaken.sources) do
							-- add the mob
							local source = cached[sourcename] or {amount = 0, targets = {}}
							cached[sourcename] = source
							source.amount = source.amount + amount

							-- add the player
							if not source.targets[player.id] then
								source.targets[player.id] = amount
							else
								source.targets[player.id] = source.targets[player.id] + amount
							end
						end
					end
				end
			end

			local max = 0

			if cached then
				local nr = 1

				for sourcename, source in _pairs(cached) do
					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = sourcename
					d.label = sourcename
					d.value = source.amount
					d.valuetext =
						Skada:FormatValueText(
						Skada:FormatNumber(source.amount),
						mod.metadata.columns.Damage,
						_format("%02.1f%%", 100 * source.amount / set.damagetaken),
						mod.metadata.columns.Percent
					)

					if source.amount > max then
						max = source.amount
					end

					nr = nr + 1
				end
			end

			win.metadata.maxvalue = max
		end

		function mod:OnEnable()
			spellmod.metadata = {tooltip = spellmod_tooltip}
			playermod.metadata = {click1 = spellmod}
			sourcemod.metadata = {showspots = true, click1 = playermod}
			mod.metadata = {click1 = sourcemod, columns = {Damage = true, Percent = true}}

			Skada:AddMode(self, L["Damage taken"])
		end

		function mod:OnDisable()
			Skada:RemoveMode(self)
		end

		function mod:GetSetSummary(set)
			return Skada:FormatNumber(set.damagetaken or 0)
		end
	end
)