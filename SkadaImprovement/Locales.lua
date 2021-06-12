if not _G.Skada then return end

local L = LibStub("AceLocale-3.0"):NewLocale("Skada", "enUS")
if L then
    L["Improvement"] = true
    L["Improvement modes"] = true
    L["Improvement comparison"] = true
    L["Do you want to reset your improvement data?"] = true
    L["%s's overall data"] = true
    return
end

L = LibStub("AceLocale-3.0"):NewLocale("Skada", "deDE")
if L then
    L["Improvement"] = "Verbesserung"
    L["Improvement modes"] = "Verbesserungsmodi"
    L["Improvement comparison"] = "Verbesserungsvergleich"
    L["Do you want to reset your improvement data?"] = "Möchten Sie Ihre Verbesserungsdaten zurücksetzen?"
    L["%s's overall data"] = "%s Gesamtdaten"
    return
end

L = LibStub("AceLocale-3.0"):NewLocale("Skada", "esES")
if L then
    L["Improvement"] = "Mejora"
    L["Improvement modes"] = "Modos de mejora"
    L["Improvement comparison"] = "Comparación de mejoras"
    L["Do you want to reset your improvement data?"] = "¿Quieres restablecer tus datos de mejora?"
    L["%s's overall data"] = "Datos generales de %s"
    return
end

L = LibStub("AceLocale-3.0"):NewLocale("Skada", "esMX")
if L then
    L["Improvement"] = "Mejora"
    L["Improvement modes"] = "Modos de mejora"
    L["Improvement comparison"] = "Comparación de mejoras"
    L["Do you want to reset your improvement data?"] = "¿Quieres restablecer tus datos de mejora?"
    L["%s's overall data"] = "Datos generales de %s"
    return
end

L = LibStub("AceLocale-3.0"):NewLocale("Skada", "frFR")
if L then
    L["Improvement"] = "Amélioration"
    L["Improvement modes"] = "Modes d'amélioration"
    L["Improvement comparison"] = "Comparaison des améliorations"
    L["Do you want to reset your improvement data?"] = "Voulez-vous réinitialiser vos données d'améliorations?"
    L["%s's overall data"] = "Données globales de %s"
    return
end

L = LibStub("AceLocale-3.0"):NewLocale("Skada", "koKR")
if L then
	-- L["Improvement"] = ""
	-- L["Improvement modes"] = ""
	-- L["Improvement comparison"] = ""
	-- L["Do you want to reset your improvement data?"] = ""
	-- L["%s's overall data"] = ""
end

L = LibStub("AceLocale-3.0"):NewLocale("Skada", "ruRU")
if L then
    L["Improvement"] = "Улучшение"
    L["Improvement modes"] = "Режимы улучшения"
    L["Improvement comparison"] = "Сравнение улучшений"
    L["Do you want to reset your improvement data?"] = "Вы хотите сбросить данные об улучшении?"
    L["%s's overall data"] = "%s - Данные об улучшении"
end

L = LibStub("AceLocale-3.0"):NewLocale("Skada", "zhCN")
if L then
    L["Improvement"] = "提升"
    L["Improvement modes"] = "提升模式"
    L["Improvement comparison"] = "提升比较"
    L["Do you want to reset your improvement data?"] = "确定要重置你的提升数据？"
    L["%s's overall data"] = "%s的总体数据"
end

L = LibStub("AceLocale-3.0"):NewLocale("Skada", "zhTW")
if L then
	-- L["Improvement"] = ""
	-- L["Improvement modes"] = ""
	-- L["Improvement comparison"] = ""
	-- L["Do you want to reset your improvement data?"] = ""
	-- L["%s's overall data"] = ""
end