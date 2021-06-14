local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("Skada") then return end

-- Skada r301
-- https://www.curseforge.com/wow/addons/skada/files/458800

S:AddCallbackForAddon("Skada", "Skada", function()
	if not E.private.addOnSkins.Skada then return end

	if Skada.revisited then
		hooksecurefunc(Skada.displays.bar, "AddDisplayOptions", function(_, _, options)
			options.windowoptions = nil
			options.titleoptions.args.texture = nil
			options.titleoptions.args.bordertexture = nil
			options.titleoptions.args.thickness = nil
			options.titleoptions.args.margin = nil
			options.titleoptions.args.color = nil
		end)
	end

	hooksecurefunc(Skada.displays["bar"], "ApplySettings", function(_, win)
		local skada = win.bargroup
		if win.db.enabletitle then
			skada.button:SetBackdrop(nil)

			if not skada.button.backdrop then
				skada.button:CreateBackdrop()
				skada.button.backdrop:SetFrameLevel(skada.button:GetFrameLevel())
			end

			skada.button.backdrop:SetTemplate(E.db.addOnSkins.skadaTitleTemplate, E.db.addOnSkins.skadaTitleTemplate == "Default" and E.db.addOnSkins.skadaTitleTemplateGloss or false)
		end

		if Skada.revisited then
			skada:SetBackdrop(nil) -- remove default backdrop
			if not skada.backdrop then
				skada:CreateBackdrop(E.db.addOnSkins.skadaTemplate, E.db.addOnSkins.skadaTemplate == "Default" and E.db.addOnSkins.skadaTemplateGloss or false)
			end

			if skada.backdrop then
				skada.backdrop:SetTemplate(E.db.addOnSkins.skadaTemplate, E.db.addOnSkins.skadaTemplate == "Default" and E.db.addOnSkins.skadaTemplateGloss or false)
				skada.backdrop:ClearAllPoints()

				if win.db.reversegrowth then
					skada.backdrop:SetPoint("LEFT", skada, "LEFT", -E.Border, 0)
					skada.backdrop:SetPoint("RIGHT", skada, "RIGHT", E.Border, 0)
					skada.backdrop:SetPoint("BOTTOM", skada.button, "TOP", 0, -((win.db.enabletitle and win.db.title.height or 0) + E.Border))
				else
					skada.backdrop:SetPoint("LEFT", skada, "LEFT", -E.Border, 0)
					skada.backdrop:SetPoint("RIGHT", skada, "RIGHT", E.Border, 0)
					skada.backdrop:SetPoint("TOP", skada.button, "BOTTOM", 0, (win.db.enabletitle and win.db.title.height or 0) + E.Border)
				end
			end
		elseif win.db.enablebackground then
			skada.bgframe:SetTemplate(E.db.addOnSkins.skadaTemplate, E.db.addOnSkins.skadaTemplate == "Default" and E.db.addOnSkins.skadaTemplateGloss or false)

			if skada.bgframe then
				skada.bgframe:ClearAllPoints()
				if win.db.reversegrowth then
					skada.bgframe:SetPoint("LEFT", skada.button, "LEFT", -E.Border, 0)
					skada.bgframe:SetPoint("RIGHT", skada.button, "RIGHT", E.Border, 0)
					skada.bgframe:SetPoint("BOTTOM", skada.button, "TOP", 0, -margin)
				else
					skada.bgframe:SetPoint("LEFT", skada.button, "LEFT", -E.Border, 0)
					skada.bgframe:SetPoint("RIGHT", skada.button, "RIGHT", E.Border, 0)
					skada.bgframe:SetPoint("TOP", skada.button, "BOTTOM", 0, margin)
				end
			end
		end
	end)

	local EMB = E:GetModule("EmbedSystem")
	hooksecurefunc(Skada, "CreateWindow", function()
		if EMB:CheckEmbed("Skada") then
			EMB:EmbedSkada()
		end
	end)

	hooksecurefunc(Skada, "DeleteWindow", function()
		if EMB:CheckEmbed("Skada") then
			EMB:EmbedSkada()
		end
	end)

	if Skada.revisited then
		hooksecurefunc(Skada, "UpdateDisplay", function()
			if EMB:CheckEmbed("Skada") then
				EMB:EmbedSkada()
			end
		end)
	end

	hooksecurefunc(Skada, "SetTooltipPosition", function(self, tt, frame)
		if self.db.profile.tooltippos == "default" then
			if not E:HasMoverBeenMoved("ElvTooltipMover") then
				if ElvUI_ContainerFrame and ElvUI_ContainerFrame:IsShown() then
					tt:Point("BOTTOMRIGHT", ElvUI_ContainerFrame, "TOPRIGHT", 0, 18)
				elseif RightChatPanel:IsShown() and RightChatPanel:GetAlpha() == 1 then
					tt:Point("BOTTOMRIGHT", RightChatPanel, "TOPRIGHT", 0, 18)
				else
					tt:Point("BOTTOMRIGHT", RightChatPanel, "BOTTOMRIGHT", 0, 18)
				end
			else
				local point = E:GetScreenQuadrant(ElvTooltipMover)

				if point == "TOPLEFT" then
					tt:SetPoint("TOPLEFT", ElvTooltipMover)
				elseif point == "TOPRIGHT" then
					tt:SetPoint("TOPRIGHT", ElvTooltipMover)
				elseif point == "BOTTOMLEFT" or point == "LEFT" then
					tt:SetPoint("BOTTOMLEFT", ElvTooltipMover)
				else
					tt:SetPoint("BOTTOMRIGHT", ElvTooltipMover)
				end
			end
		end
	end)
end)