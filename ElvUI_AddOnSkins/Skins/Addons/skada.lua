local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

local function LoadSkin()
  if not E.private.addOnSkins.Skada then return end

  hooksecurefunc(Skada.displays.bar, "AddDisplayOptions", function(_, _, options)
    options.titleoptions.args.texture = nil
    options.titleoptions.args.bordertexture = nil
    options.titleoptions.args.thickness = nil
    options.titleoptions.args.margin = nil
    options.titleoptions.args.color = nil
    options.windowoptions = nil
  end)

  local db = E.db.addOnSkins

  hooksecurefunc(Skada.displays.bar, "ApplySettings", function(_, win)
    local skada = win.bargroup

    -- Skada Title Frame
    if win.db.enabletitle then
      skada.button:SetBackdrop(nil)

      if not skada.button.backdrop then
        skada.button:CreateBackdrop()
        skada.button.backdrop:SetFrameLevel(skada.button:GetFrameLevel())
      end

      if skada.button.backdrop then
        skada.button:SetTemplate(E.db.addOnSkins.skadaTitleTemplate, E.db.addOnSkins.skadaTitleTemplate == "Default" and E.db.addOnSkins.skadaTitleTemplateGloss or false)
        skada.button.backdrop:ClearAllPoints()

        if win.db.reversegrowth then
          skada.button.backdrop:Point("TOPLEFT", skada.button, "TOPLEFT", -E.Border, -2)
          skada.button.backdrop:Point("BOTTOMRIGHT", skada.button, "BOTTOMRIGHT", E.Border, -1)
        else
          skada.button.backdrop:Point("TOPLEFT", skada.button, "TOPLEFT", -E.Border, 1)
          skada.button.backdrop:Point("BOTTOMRIGHT", skada.button, "BOTTOMRIGHT", E.Border, 2)
        end
      end
    end

    -- Skada Frame
    skada:SetBackdrop(nil)

    if not skada.backdrop then
      skada:CreateBackdrop()
    end

    if skada.backdrop then
      skada:SetTemplate(E.db.addOnSkins.skadaTemplate, E.db.addOnSkins.skadaTemplate == "Default" and E.db.addOnSkins.skadaTemplateGloss or false)
      skada.backdrop:ClearAllPoints()

      if win.db.reversegrowth then
        skada.backdrop:Point("TOPLEFT", skada, "TOPLEFT", -E.Border, 0)
        skada.backdrop:Point("BOTTOMRIGHT", skada, "BOTTOMRIGHT", E.Border, -1)
      else
        skada.backdrop:Point("TOPLEFT", skada, "TOPLEFT", -E.Border, E.Border)
        skada.backdrop:Point("BOTTOMRIGHT", skada, "BOTTOMRIGHT", E.Border, 0)
      end

      if not db.backdrop then
        skada.backdrop:Hide()
      else
        skada.backdrop:Show()
      end
    end
  end)

  -- hooks functions
  local EMB = E:GetModule("EmbedSystem")
  if EMB and AS.addons.skada then
    hooksecurefunc(Skada, "CreateWindow", function()
      EMB:EmbedSkada()
    end)
    hooksecurefunc(Skada, "DeleteWindow", function()
      EMB:EmbedSkada()
    end)
    hooksecurefunc(Skada, "UpdateDisplay", function()
      if not InCombatLockdown() then EMB:EmbedSkada() end
    end)
  end

  hooksecurefunc(Skada, "SetTooltipPosition", function(self, tt)
    local p = self.db.profile.tooltippos

    if p == "default" then
      if not E:HasMoverBeenMoved("TooltipMover") then
        if ElvUI_ContainerFrame and ElvUI_ContainerFrame:IsShown() then
          tt:Point("BOTTOMRIGHT", ElvUI_ContainerFrame, "TOPRIGHT", 0, 18)
        elseif RightChatPanel:GetAlpha() == 1 and RightChatPanel:IsShown() then
          tt:Point("BOTTOMRIGHT", RightChatPanel, "TOPRIGHT", 0, 18)
        else
          tt:Point("BOTTOMRIGHT", RightChatPanel, "BOTTOMRIGHT", 0, 18)
        end
      else
        local point = E:GetScreenQuadrant(TooltipMover)
        if point == "TOPLEFT" then
          tt:Point("TOPLEFT", TooltipMover)
        elseif point == "TOPRIGHT" then
          tt:Point("TOPRIGHT", TooltipMover)
        elseif point == "BOTTOMLEFT" or point == "LEFT" then
          tt:Point("BOTTOMLEFT", TooltipMover)
        else
          tt:Point("BOTTOMRIGHT", TooltipMover)
        end
      end
     end
  end)
end

S:AddCallbackForAddon("Skada", "Skada", LoadSkin)
