local L = LibStub("AceLocale-3.0"):NewLocale("Skada", "frFR", false)

if not L then return end

L["Disable"] = "Désactiver"
L["Profiles"] = "Profils"
L["Hint: Left-Click to toggle Skada window."] = "Astuce : clic-gauche pour afficher/cacher la fenêtre de Skada."
L["Shift + Left-Click to reset."] = "Shift+clic-gauche pour réinitialiser."
L["Right-click to open menu"] = "Clic-droit pour ouvrir le menu."
L["Options"] = "Options"
L["Appearance"] = "Apparence"
L["A damage meter."] = "Un \"damage meter\"."
L["Skada summary"] = "Résumé Skada"


L["opens the configuration window"] = "ouvre la fenêtre de configuration"
L["resets all data"] = "réinitialise toutes les données"

L["Current"] = "Actuel"
L["Total"] = "Total"


L["All data has been reset."] = "Toutes les données ont été réinitialisées."
L["Skada: Modes"] = "Skada : modes"
L["Skada: Fights"] = "Skada : combats"

-- Options
L["Bar font"] = "Police des barres"
L["The font used by all bars."] = "La police d'écriture utilisée par toutes les barres."
L["Bar font size"] = "Taille police des barres"
L["The font size of all bars."] = "La taille de la police d'écriture pour toutes les barres."
L["Bar texture"] = "Texture des barres"
L["The texture used by all bars."] = "La texture utilisée par toutes les barres."
L["Bar spacing"] = "Espacement des barres"
L["Distance between bars."] = "La distance entre les barres."
L["Bar height"] = "Hauteur des barres"
L["The height of the bars."] = "La hauteur des barres."
L["Bar width"] = "Largeur des barres"
L["The width of the bars."] = "La largeur des barres."
L["Bar color"] = "Couleur des barres"
L["Choose the default color of the bars."] = "Choissisez la couleur par défaut des barres."
L["Max bars"] = "Nbre max. de barres"
L["The maximum number of bars shown."] = "Le nombre maximal de barres à afficher."
L["Bar orientation"] = "Orientation des barres"
L["The direction the bars are drawn in."] = "La direction vers laquelle les barres sont dessinées"
L["Left to right"] = "Gauche vers la droite"
L["Right to left"] = "Droite vers la gauche"
L["Combat mode"] = "Mode en combat"
L["Automatically switch to set 'Current' and this mode when entering combat."] = "Passe automatiquement à la vue 'Actuel' et au mode choisi ci-dessous quand vous entrez en combat."
L["None"] = "Aucun"
L["Return after combat"] = "Retour après combat"
L["Return to the previous set and mode after combat ends."] = "Retourne au mode et à la vue précédente une fois le combat terminé."
L["Show minimap button"] = "Bouton de la minicarte"
L["Toggles showing the minimap button."] = "Affiche ou non l'icône de la minicarte."

L["reports the active mode"] = "fait un rapport du mode actif"
L["Skada report on %s for %s, %s to %s:"] = "Skada : %s pour %s, de %s à %s :"
L["Only keep boss fighs"] = "Ne garder que les boss"
L["Boss fights will be kept with this on, and non-boss fights are discarded."] = "Les combats contre les boss seront conservés avec ceci d'activé, le reste sera jeté."
L["Show raw threat"] = "Menace brute"
L["Shows raw threat percentage relative to tank instead of modified for range."] = "Affiche le pourcentage brut de menace par rapport au tank au lieu de celui modifié selon la portée."

L["Lock window"] = "Verrouiller la fenêtre"
L["Locks the bar window in place."] = "Verrouille la fenêtre des barres à sa position actuelle."
L["Reverse bar growth"] = "Inverser sens d'ajout"
L["Bars will grow up instead of down."] = "Les barres s'ajouteront vers le haut au lieu de vers le bas."
L["Number format"] = "Format des nombres"
L["Controls the way large numbers are displayed."] = "Détermine la façon dont les nombres sont affichés."
L["Reset on entering instance"] = "RÀZ en entrant en instance"
L["Controls if data is reset when you enter an instance."] = "Détermine si les données doivent être réinitialisées quand vous entrez dans une instance."
L["Reset on joining a group"] = "RÀZ en rejoignant un groupe"
L["Controls if data is reset when you join a group."] = "Détermine si les données doivent être réinitialisées quand vous rejoignez un groupe."
L["Reset on leaving a group"] = "RÀZ en quittant un groupe"
L["Controls if data is reset when you leave a group."] = "Détermine si les données doivent être réinitialisées quand vous quittez un groupe."
L["General options"] = "Options générales"
L["Mode switching"] = "Changement de vue"
L["Data resets"] = "RÀZ des données"
L["Bars"] = "Barres"

L["Yes"] = "Oui"
L["No"] = "Non"
L["Ask"] = "Demander"
L["Condensed"] = "Condensé"
L["Detailed"] = "Détaillé"

L["Hide when solo"] = "Masquer quand seul"
L["Hides Skada's window when not in a party or raid."] = "Masque la fenêtre de Skada quand vous n'êtes pas dans un groupe ou un raid."

L["Title bar"] = "Barre du titre"
L["Background texture"] = "Texture de l'arrière-plan"
L["The texture used as the background of the title."] = "La texture utilisée comme arrière-plan du titre."
L["Border texture"] = "Texture de la bordure"
L["The texture used for the border of the title."] = "La texture utilisée pour la bordure du titre."
L["Border thickness"] = "Épaisseur de la bordure"
L["The thickness of the borders."] = "L'épaisseur des bordures."
L["Background color"] = "Couleur arrière-plan"
L["The background color of the title."] = "La couleur de l'arrière-plan du titre."

L["'s "] = " : "
L["Do you want to reset Skada?"] = "Voulez-vous réinitialiser Skada ?"
L["The margin between the outer edge and the background texture."] = "La marge entre le bord extérieur et la texture de l'arrière-plan."
L["Margin"] = "Marge"
L["Window height"] = "Hauteur de la fenêtre"
L["The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."] = "La hauteur de la fenêtre. Si mit à 0, la hauteur sera dynamiquement changée selon le nombre de barres existantes."
L["Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."] = "Ajoute un arrière-plan en dessous des barres. La hauteur du cadre de l'arrière-plan détermine le nombre de barres affichées. Ceci outrepasse donc le paramètre \"Nbre max. de barres\"."
L["Enable"] = "Activer"
L["Background"] = "Arrière-plan"
L["The texture used as the background."] = "La texture utilisée comme arrière-plan."
L["The texture used for the borders."] = "La texture utilisée pour les bordures."
L["The color of the background."] = "La couleur de l'arrière-plan."
L["Data feed"] = "Flux de données"
L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."] = "Choississez le flux de données à afficher sur le greffon DataBlocker. Ceci nécessite un addon d'affichage LDB, tel que Titan Panel."
L["RDPS"] = "RDPS"
L["Damage: Personal DPS"] = "Dégâts : DPS personnel"
L["Damage: Raid DPS"] = "Dégâts : DPS du raid"
L["Threat: Personal Threat"] = "Menace : Menace perso."

L["Data segments to keep"] = "Segments à garder"
L["The number of fight segments to keep. Persistent segments are not included in this."] = "Le nombre de segments de combat à garder. Les segments persistants ne sont pas comptés avec."

L["Alternate color"] = "Couleur alternative"
L["Choose the alternate color of the bars."] = "Choississez la couleur alternative des barres."

L["Threat warning"] = "Avertissement de la menace"
L["Flash screen"] = "Flasher l'écran"
L["This will cause the screen to flash as a threat warning."] = "Ceci fera clignoter l'écran pour en faire un avertissement sur la menace."
L["Shake screen"] = "Secouer l'écran"
L["This will cause the screen to shake as a threat warning."] = "Ceci fera secouer l'écran pour en faire un avertissement sur la menace."
L["Play sound"] = "Jouer un son"
L["This will play a sound as a threat warning."] = "Ceci jouera un son pour en faire un avertissement sur la menace"
L["Threat sound"] = "Son de menace"
L["The sound that will be played when your threat percentage reaches a certain point."] = "Le son qui sera joué chaque fois que votre pourcentage de menace atteint un certain point."
L["Threat threshold"] = "Seuil de menace"
L["When your threat reaches this level, relative to tank, warnings are shown."] = "Quand votre menace atteint ce niveau par rapport au tank, les avertissements sont affichés."

L["Enables the title bar."] = "Active la barre-titre."

L["Total healing"] = "Total des soins"

L["Skada Menu"] = "Menu Skada"
L["Switch to mode"] = "Passer au mode"
L["Report"] = "Rapport"
L["Toggle window"] = "Afficher la fenêtre"
L["Configure"] = "Configurer"
L["Delete segment"] = "Supprimer segment"
L["Keep segment"] = "Garder segment"
L["Mode"] = "Mode"
L["Lines"] = "Lignes"
L["Channel"] = "Canal"
L["Send report"] = "Envoyer rapport"
L["No mode selected for report."] = "Aucun mode n'a été sélectionné pour le rapport"
L["Say"] = "Dire"
L["Raid"] = "Raid"
L["Party"] = "Groupe"
L["Guild"] = "Guilde"
L["Officer"] = "Officier"
L["Self"] = "Soi-même"

L["'s Healing"] = " : soins"

L["Delete window"] = "Supprimer la fenêtre"
L["Deletes the chosen window."] = "Supprime la fenêtre choisie."
L["Choose the window to be deleted."] = "Choississez la fenêtre à supprimer."
L["Enter the name for the new window."] = "Entrez le nom de la nouvelle fenêtre."
L["Create window"] = "Créer une fenêtre"
L["Windows"] = "Fenêtres"

L["Switch to segment"] = "Passer au segment"
L["Segment"] = "Segment"

L["Whisper"] = "Chuchoter"

L["No mode or segment selected for report."] = "Aucun mode ou segment n'a été sélectionné pour le rapport."
L["Name of recipient"] = "Nom du destinataire"

L["Resist"] = "Résiste"
L["Reflect"] = "Renvoie"
L["Parry"] = "Parade"
L["Immune"] = "Insensible"
L["Evade"] = "Évite"
L["Dodge"] = "Esquive"
L["Deflect"] = "Dévie"
L["Block"] = "Blocage"
L["Absorb"] = "Absorbe"

L["Last fight"] = "Dernier combat"
L["Disable while hidden"] = "Désactiver qd caché"
L["Skada will not collect any data when automatically hidden."] = "Skada ne récoltera aucune donnée quand il est automatiquement caché."

L["Rename window"] = "Renommer la fenêtre"
L["Enter the name for the window."] = "Entrez le nom de la fenêtre."

L["Bar display"] = "Affichage par barres"
L["Display system"] = "Système d'affichage"
L["Choose the system to be used for displaying data in this window."] = "Choississez le système à utiliser pour l'affichage des données dans cette fenêtre."

L["Hides HPS from the Healing modes."] = "Masque le SPS du mode Soins prodigués."
L["Do not show HPS"] = "Ne pas afficher le SPS"

L["Do not show DPS"] = "Ne pas afficher le DPS"
L["Hides DPS from the Damage mode."] = "Masque le DPS du mode Dégâts infligés."

L["Class color bars"] = "Barres : couleur de classe"
L["When possible, bars will be colored according to player class."] = "Quand cela est possible les barres seront coloriées selon la classe des joueurs représentés."
L["Class color text"] = "Texte : couleur de classe"
L["When possible, bar text will be colored according to player class."] = "Quand cela est possible, le texte des barres sera colorié selon la classe du joueur représenté."

L["Reset"] = "Réinitialiser"
L["Show tooltips"] = "Afficher les bulles"

L["Shows tooltips with extra information in some modes."] = "Affiche les bulles d'aide contenant des informations supplémentaires dans certains modes."


L["Minimum hit:"] = "Minimum :"
L["Maximum hit:"] = "Maximum :"
L["Average hit:"] = "Moyenne :"
L["Absorbs"] = "Absorptions"
L["'s Absorbs"] = " : absorptions"

L["Do not show TPS"] = "Ne pas afficher la MPS"
L["Do not warn while tanking"] = "Ne pas prévenir en tankant"

L["Hide in PvP"] = "Masquer en JcJ"
L["Hides Skada's window when in Battlegrounds/Arenas."] = "Masque la fenêtre de Skada quand vous êtes dans un champ de bataille ou une arène."

L["Healed players"] = "Joueurs soignés"
L["Healed by"] = "Soigné par"
L["Absorb details"] = "Détails d'absorption"
L["Spell details"] = "Détails de la technique"
L["Healing spell list"] = "Liste des techniques de soin"
L["Healing spell details"] = "Détails des techniques de soin"
L["Debuff spell list"] = "Liste des techniques d'affaiblissement"







L["Click for"] = "Clic gauche pour"
L["Shift-Click for"] = "Shift-clic gauche pour"
L["Control-Click for"] = "Ctrl-clic gauche pour"
L["Default"] = "Défaut"
L["Top right"] = "En haut à droite"
L["Top left"] = "En haut à gauche"



L["Position of the tooltips."] = "La position des bulles d'aide."
L["Tooltip position"] = "Position bulle d'aide"


L["Shows a button for opening the menu in the window title bar."] = "Affiche un bouton permettant d'ouvrir le menu sur la barre du titre de la fenêtre."
L["Show menu button"] = "Aff. bouton Menu"



L["Attack"] = "Attaque"
L["Damage"] = "Dégâts infligés"
L["Hit"] = "Touche"
L["Critical"] = "Critique"
L["Missed"] = "Raté"
L["Resisted"] = "Résisté"
L["Blocked"] = "Bloqué"
L["Glancing"] = "Érafle"
L["Crushing"] = "Écrasement"
L["Absorbed"] = "Absorbé"
L["HPS"] = "SPS"
L["Healing"] = "Soins prodigués"

L["Overhealing"] = "Soins en excès"
L["Threat"] = "Menace"

L["Announce CC breaking to party"] = "Annoncer les casseurs de contrôle au groupe"
L["Ignore Main Tanks"] = "Ignorer les tanks principaux"
L["%s on %s removed by %s's %s"] = "%s sur %s enlevé(e) par %s avec %s"
L["%s on %s removed by %s"] = "%s sur %s enlevé(e) par %s"

L["Start new segment"] = "Lancer nv segment"
L["Columns"] = "Colonnes"
L["Overheal"] = "Soin en excès"
L["Percent"] = "Pourcent"
L["TPS"] = "MPS"

L["%s dies"] = "%s meurt"
L["Change"] = "Changer"
L["Health"] = "Vie"

L["Hide in combat"] = "Masquer en combat"
L["Hides Skada's window when in combat."] = "Masque la fenêtre de Skada quand vous êtes en combat."

L["Tooltips"] = "Bulles d'aide"
L["Informative tooltips"] = "Bulles d'aide informatives"
L["Shows subview summaries in the tooltips."] = "Affiche le résumé des sous-vues dans les bulles d'aide."
L["Subview rows"] = "Rangées sous-vue"
L["The number of rows from each subview to show when using informative tooltips."] = "Le nombre de rangées de chaque sous-vue afficher lors de l'utilisation des bulles d'aide informatives."

L["Damage done"] = "Dégâts infligés"
L["Active Time"] = "Active le temps"
L["Segment Time"] = "Segment de temps"
L["Absorbs and healing"] = "Absorption et soins"




L["Show rank numbers"] = "Affiche les n° des rangs"
L["Shows numbers for relative ranks for modes where it is applicable."] = "Affiche les numéros pour les rangs relative pour les modes où c'est applicable."

L["Use focus target"] = "Utiliser la cible de la focal."
L["Shows threat on focus target, or focus target's target, when available."] = "Affiche la menace sur la cible focus, ou focus la cible de la cible le cas échéant. "

L["Show spark effect"] = "Affiche une effet de lueur "










-- Scroll








-- =================== --
-- damage module lines --
-- =================== --

L["DPS"] = "DPS"


L["Damage on"] = "Dégâts sur"




L["Damage Taken"] = "Dégâts subis"
L["Damage from"] = "Dégâts |2"



L["Enemy damage done"] = "Dégâts infligés (ennemis)"
L["Enemy damage taken"] = "Dégâts subis (ennemis)"

L["%s's Damage"] = "%s : dégâts"











L["Damage taken by spell"] = "Dégâts reçus par sort"





L["Damage done per player"] = "Dégâts infligés par joueur"
L["Damage taken per player"] = "Dégâts reçus par joueur"

-- ================== --
-- auras module lines --
-- ================== --














-- ======================= --
-- interrupts module lines --
-- ======================= --

L["Interrupts"] = "Interruptions"




-- ==================== --
-- failbot module lines --
-- ==================== --

L["Fails"] = "Échecs"
L["%s's Fails"] = "%s : échecs"



-- ======================== --
-- improvement module lines --
-- ======================== --








-- =================== --
-- deaths module lines --
-- =================== --

L["Deaths"] = "Morts"
L["%s's Death"] = "%s : mort"

L["Death log"] = "Journalisation des morts"






-- ==================== --
-- dispels module lines --
-- ==================== --

L["Dispels"] = "Dissipations"









-- ======================= --
-- cc tracker module lines --
-- ======================= --

L["CC"] = "CC"


L["CC Breakers"] = "Casseurs de contrôle"







-- CC Done:








-- CC Taken








-- ====================== --
-- resurrect module lines --
-- ====================== --













-- ====================== --
-- Avoidance & Mitigation --
-- ====================== --




















