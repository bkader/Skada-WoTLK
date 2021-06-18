local Skada = Skada
if not Skada then return end

local L = Skada.L

-- default to enUS/enGB
L["Improvement"] = true
L["Improvement modes"] = true
L["Improvement comparison"] = true
L["Do you want to reset your improvement data?"] = true
L["%s's overall data"] = true

-- deDE
if Skada.locale == "deDE" then
    L["Improvement"] = "Verbesserung"
    L["Improvement modes"] = "Verbesserungsmodi"
    L["Improvement comparison"] = "Verbesserungsvergleich"
    L["Do you want to reset your improvement data?"] = "Möchten Sie Ihre Verbesserungsdaten zurücksetzen?"
    L["%s's overall data"] = "%s Gesamtdaten"

-- esES/esMX
elseif Skada.locale == "esES" or Skada.locale == "esMX" then
    L["Improvement"] = "Mejora"
    L["Improvement modes"] = "Modos de mejora"
    L["Improvement comparison"] = "Comparación de mejoras"
    L["Do you want to reset your improvement data?"] = "¿Quieres restablecer tus datos de mejora?"
    L["%s's overall data"] = "Datos generales de %s"

-- frFR
elseif Skada.locale == "frFR" then
    L["Improvement"] = "Amélioration"
    L["Improvement modes"] = "Modes d'amélioration"
    L["Improvement comparison"] = "Comparaison des améliorations"
    L["Do you want to reset your improvement data?"] = "Voulez-vous réinitialiser vos données d'améliorations?"
    L["%s's overall data"] = "Données globales de %s"

-- koKR
elseif Skada.locale == "koKR" then
	-- L["Improvement"] = ""
	-- L["Improvement modes"] = ""
	-- L["Improvement comparison"] = ""
	-- L["Do you want to reset your improvement data?"] = ""
	-- L["%s's overall data"] = ""

-- ruRU
elseif Skada.locale == "ruRU" then
    L["Improvement"] = "Улучшение"
    L["Improvement modes"] = "Режимы улучшения"
    L["Improvement comparison"] = "Сравнение улучшений"
    L["Do you want to reset your improvement data?"] = "Вы хотите сбросить данные об улучшении?"
    L["%s's overall data"] = "%s - Данные об улучшении"

-- zhCN
elseif Skada.locale == "zhCN" then
    L["Improvement"] = "提升"
    L["Improvement modes"] = "提升模式"
    L["Improvement comparison"] = "提升比较"
    L["Do you want to reset your improvement data?"] = "确定要重置你的提升数据？"
    L["%s's overall data"] = "%s的总体数据"

-- zhTW
elseif Skada.locale == "zhTW" then
	-- L["Improvement"] = ""
	-- L["Improvement modes"] = ""
	-- L["Improvement comparison"] = ""
	-- L["Do you want to reset your improvement data?"] = ""
	-- L["%s's overall data"] = ""
end