local Skada = Skada
Skada:AddLoadableModule("Parry-Haste", function(L)
	if Skada:IsDisabled("Parry-Haste") then return end

	local mod = Skada:NewModule(L["Parry-Haste"])
	local targetmod = mod:NewModule(L["Parry target list"])

	local pairs, ipairs, select = pairs, ipairs, select
	local tostring, format = tostring, string.format

	local parrybosses = {
		[L["Acidmaw"]] = true,
		[L["Dreadscale"]] = true,
		[L["Icehowl"]] = true,
		[L["Onyxia"]] = true,
		[L["Lady Deathwhisper"]] = true,
		[L["Sindragosa"]] = true,
		[L["Halion"]] = true,
		-- UNCONFIRMED BOSSES
		-- Suggested by shoggoth#9796
		[L["General Vezax"]] = true,
		[L["Gluth"]] = true,
		[L["Kel'Thuzad"]] = true,
		[L["Sapphiron"]] = true,
	}

	local function log_parry(set, data)
		local player = Skada:GetPlayer(set, data.playerid, data.playername, data.playerflags)
		if player then
			player.parry = (player.parry or 0) + 1
			set.parry = (set.parry or 0) + 1

			-- saving this to total set may become a memory hog deluxe.
			if set == Skada.current then
				player.parrytargets = player.parrytargets or {}
				player.parrytargets[data.dstName] = (player.parrytargets[data.dstName] or 0) + 1

				if Skada.db.profile.modules.parryannounce then
					Skada:SendChat(format(L["%s parried %s (%s)"], data.dstName, data.playername, player.parrytargets[data.dstName] or 1), Skada.db.profile.modules.parrychannel, "preset", true)
				end
			end
		end
	end

	local data = {}

	local function SpellMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		if parrybosses[dstName] and srcGUID ~= dstGUID and select(4, ...) == "PARRY" then
			srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName, srcFlags)

			data.playerid = srcGUID
			data.playername = srcName
			data.playerflags = srcFlags
			data.dstName = dstName

			log_parry(Skada.current, data)
			log_parry(Skada.total, data)
		end
	end

	local function SwingMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
		SpellMissed(ts, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, nil, nil, nil, ...)
	end

	function targetmod:Enter(win, id, label)
		win.playerid, win.playername = id, label
		win.title = format(L["%s's parry targets"], label)
	end

	function targetmod:Update(win, set)
		win.title = format(L["%s's parry targets"], win.playername or L.Unknown)

		local player = set and set:GetPlayer(win.playerid, win.playername)
		local total = player and player.parry or 0

		if total > 0 and player.parrytargets then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for targetname, count in pairs(player.parrytargets) do
				nr = nr + 1

				local d = win.dataset[nr] or {}
				win.dataset[nr] = d

				d.id = targetname
				d.label = targetname
				d.class = "BOSS" -- what else can it be?

				d.value = count
				d.valuetext = Skada:FormatValueText(
					d.value,
					mod.metadata.columns.Count,
					Skada:FormatPercent(d.value, total),
					mod.metadata.columns.Percent
				)

				if win.metadata and d.value > win.metadata.maxvalue then
					win.metadata.maxvalue = d.value
				end
			end
		end
	end

	function mod:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Parry-Haste"], L[win.class]) or L["Parry-Haste"]

		local total = set.parry or 0
		if total > 0 then
			if win.metadata then
				win.metadata.maxvalue = 0
			end

			local nr = 0
			for _, player in ipairs(set.players) do
				if (not win.class or win.class == player.class) and (player.parry or 0) > 0 then
					nr = nr + 1

					local d = win.dataset[nr] or {}
					win.dataset[nr] = d

					d.id = player.id or player.name
					d.label = player.name
					d.text = player.id and Skada:FormatName(player.name, player.id)
					d.class = player.class
					d.role = player.role
					d.spec = player.spec

					d.value = player.parry
					d.valuetext = Skada:FormatValueText(
						d.value,
						self.metadata.columns.Count,
						Skada:FormatPercent(d.value, total),
						self.metadata.columns.Percent
					)

					if win.metadata and d.value > win.metadata.maxvalue then
						win.metadata.maxvalue = d.value
					end
				end
			end
		end
	end

	function mod:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			click1 = targetmod,
			click4 = Skada.ToggleFilter,
			click4_label = L["Toggle Class Filter"],
			nototalclick = {targetmod},
			columns = {Count = true, Percent = false},
			icon = [[Interface\Icons\ability_parry]]
		}

		Skada:RegisterForCL(SpellMissed, "SPELL_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})
		Skada:RegisterForCL(SwingMissed, "SWING_MISSED", {src_is_interesting = true, dst_is_not_interesting = true})

		Skada:AddMode(self)
	end

	function mod:OnDisable()
		Skada:RemoveMode(self)
	end

	function mod:GetSetSummary(set)
		return tostring(set.parry or 0), set.parry or 0
	end

	function mod:OnInitialize()
		if not Skada.db.profile.modules.parrychannel then
			Skada.db.profile.modules.parrychannel = "AUTO"
		end
		Skada.options.args.modules.args.Parry = {
			type = "group",
			name = self.moduleName,
			desc = format(L["Options for %s."], self.moduleName),
			args = {
				header = {
					type = "description",
					name = self.moduleName,
					fontSize = "large",
					image = [[Interface\Icons\ability_parry]],
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
				parryannounce = {
					type = "toggle",
					name = format(L["Announce %s"], self.moduleName),
					order = 10,
					width = "double"
				},
				parrychannel = {
					type = "select",
					name = L["Channel"],
					values = {AUTO = INSTANCE, SELF = L["Self"]},
					order = 20,
					width = "double"
				}
			}
		}
	end
end)