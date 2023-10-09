local _, Skada = ...
local Private = Skada.Private
Skada:RegisterModule("Parry-Haste", function(L, P, _, _, M, O)
	local mode = Skada:NewModule("Parry-Haste")
	local mode_target = mode:NewModule("Target List")
	local pairs, format, uformat = pairs, string.format, Private.uformat
	local classfmt = Skada.classcolors.format
	local mode_cols = nil

	local parrybosses = {
		[10184] = true, -- Onyxia
		[34797] = true, -- Icehowl
		[34799] = true, -- Dreadscale
		[35144] = true, -- Acidmaw
		[36853] = true, -- Sindragosa
		[36855] = true, -- Lady Deathwhisper
		[39863] = true, -- Halion
		-- UNCONFIRMED BOSSES - by shoggoth#9796
		[15932] = true, -- Gluth
		[15989] = true, -- Sapphiron
		[15990] = true, -- Kel'Thuzad
		[33271] = true, -- General Vezax
	}

	local function format_valuetext(d, total, metadata, subview)
		d.valuetext = Skada:FormatValueCols(
			mode_cols.Count and d.value,
			mode_cols[subview and "sPercent" or "Percent"] and Skada:FormatPercent(d.value, total)
		)

		if metadata and d.value > metadata.maxvalue then
			metadata.maxvalue = d.value
		end
	end

	local function log_parry(set, actorname, actorid, actorflags, dstName)
		local actor = Skada:GetActor(set, actorname, actorid, actorflags)
		if not actor then return end

		actor.parry = (actor.parry or 0) + 1
		set.parry = (set.parry or 0) + 1

		-- saving this to total set may become a memory hog deluxe.
		if (set == Skada.total and not P.totalidc) or not dstName then return end

		actor.parrytargets = actor.parrytargets or {}
		actor.parrytargets[dstName] = (actor.parrytargets[dstName] or 0) + 1

		if M.parryannounce and set ~= Skada.total then
			Skada:SendChat(format(L["%s parried %s (%s)"], dstName, actorname, actor.parrytargets[dstName] or 1), M.parrychannel, "preset")
		end
	end

	local GetCreatureId = Skada.GetCreatureId
	local function is_parry_boss(name, guid)
		if parrybosses[name] or parrybosses[GetCreatureId(guid)] then
			parrybosses[name] = parrybosses[name] or true -- cache it
			return true
		end
		return false
	end

	local function spell_missed(t)
		if t.misstype == "PARRY" and t.dstName and is_parry_boss(t.dstName, t.dstGUID) then
			local actorid, actorname, actorflags = Skada:FixMyPets(t.srcGUID, t.srcName, t.srcFlags)
			Skada:DispatchSets(log_parry, actorname, actorid, actorflags, t.dstName)
		end
	end

	function mode_target:Enter(win, id, label, class)
		win.actorid, win.actorname, win.actorclass = id, label, class
		win.title = format(L["%s's targets"], classfmt(class, label))
	end

	function mode_target:Update(win, set)
		win.title = uformat(L["%s's targets"], classfmt(win.actorclass, win.actorname))
		if not set or not win.actorname then return end

		local actor = set:GetActor(win.actorname, win.actorid)
		local total = (actor and not actor.enemy) and actor.parry
		local targets = (total and total > 0) and actor.parrytargets

		if not targets then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		for targetname, count in pairs(targets) do
			nr = nr + 1

			local d = win:actor(nr, targetname)
			d.class = "BOSS" -- what else can it be?
			d.value = count
			format_valuetext(d, total, win.metadata, true)
		end
	end

	function mode:Update(win, set)
		win.title = win.class and format("%s (%s)", L["Parry-Haste"], L[win.class]) or L["Parry-Haste"]

		local total = set and set:GetTotal(win.class, nil, "parry")
		if not total or total == 0 then
			return
		elseif win.metadata then
			win.metadata.maxvalue = 0
		end

		local nr = 0
		local actors = set.actors

		for actorname, actor in pairs(actors) do
			if win:show_actor(actor, set, true) and actor.parry then
				nr = nr + 1

				local d = win:actor(nr, actor, actor.enemy, actorname)
				d.value = actor.parry
				format_valuetext(d, total, win.metadata)
			end
		end
	end

	function mode:GetSetSummary(set, win)
		if not set then return end
		return set:GetTotal(win and win.class, nil, "parry") or 0
	end

	function mode:OnEnable()
		self.metadata = {
			showspots = true,
			ordersort = true,
			filterclass = true,
			click1 = mode_target,
			columns = {Count = true, Percent = false, sPercent = false},
			icon = [[Interface\ICONS\ability_parry]]
		}

		mode_cols = self.metadata.columns

		-- no total click.
		mode_target.nototal = true

		Skada:RegisterForCL(
			spell_missed,
			{src_is_interesting = true, dst_is_not_interesting = true},
			"SPELL_MISSED",
			"SWING_MISSED"
		)

		Skada:AddMode(self)
	end

	function mode:OnDisable()
		Skada:RemoveMode(self)
	end

	function mode:OnInitialize()
		M.parrychannel = M.parrychannel or "AUTO"

		O.modules.args.Parry = {
			type = "group",
			name = self.localeName,
			desc = format(L["Options for %s."], self.localeName),
			args = {
				header = {
					type = "description",
					name = self.localeName,
					fontSize = "large",
					image = [[Interface\ICONS\ability_parry]],
					imageWidth = 18,
					imageHeight = 18,
					imageCoords = Skada.cropTable,
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
					name = format(L["Announce %s"], self.localeName),
					order = 10,
					width = "double"
				},
				parrychannel = {
					type = "select",
					name = L["Channel"],
					values = {AUTO = L["Instance"], SELF = L["Self"]},
					order = 20,
					width = "double"
				}
			}
		}
	end
end)
