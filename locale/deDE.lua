local L = LibStub("AceLocale-3.0"):NewLocale("Skada", "deDE", false)

if not L then return end

L["Disable"] = "Deaktivieren"
L["Profiles"] = "Profile"
L["Hint: Left-Click to toggle Skada window."] = "Linksklick zum Ein-/Ausblenden des Skada-Fensters."
L["Shift + Left-Click to reset."] = "Shift + Linksklick zum Zurücksetzen."
L["Right-click to open menu"] = "Rechtsklick zum Öffnen des Menüs"
L["Options"] = "Optionen"
L["Appearance"] = "Aussehen"
L["A damage meter."] = "Eine Schadensanzeige."
L["Skada summary"] = "Skada Zusammenfassung"
L["Timestamp"] = "Zeitstempel"

L["opens the configuration window"] = "öffnet das Konfigurationsfenster"
L["resets all data"] = "setzt alle Daten zurück"

L["Current"] = "Momentaner Kampf"
L["Total"] = "Gesamt"

L["Error: No options selected"] = "Fehler: Keine Optionen gewählt"
L["All data has been reset."] = "Alle Daten wurden zurückgesetzt."
L["Skada: Modes"] = "Skada: Modi"
L["Skada: Fights"] = "Skada: Kämpfe"

-- Options
L["Bar font"] = "Leistenschriftart"
L["The font used by all bars."] = "Die Schrift aller Leisten."
L["Bar font size"] = "Leistenschriftgröße"
L["The font size of all bars."] = "Die Schriftgröße aller Leisten."
L["Bar texture"] = "Leistentextur"
L["The texture used by all bars."] = "Textur der Leisten."
L["Bar spacing"] = "Leistenabstand"
L["Distance between bars."] = "Abstand zwischen den Leisten."
L["Bar height"] = "Leistenhöhe"
L["The height of the bars."] = "Die Höhe der Leisten."
L["Bar width"] = "Leistenbreite"
L["The width of the bars."] = "Die Breite der Leisten."
L["Bar color"] = "Leistenfarbe"
L["Choose the default color of the bars."] = "Standard Leistenfarbe auswählen."
L["Max bars"] = "Max. Leisten"
L["The maximum number of bars shown."] = "Die maximale Anzahl an angezeigten Leisten."
L["Bar orientation"] = "Leistenausrichtung"
L["The direction the bars are drawn in."] = "Die Richtung in welche die Leisten erstellt werden."
L["Left to right"] = "Links nach Rechts"
L["Right to left"] = "Rechts nach Links"
L["Combat mode"] = "Kampfmodus"
L["Automatically switch to set 'Current' and this mode when entering combat."] = "Wechselt automatisch auf das Segment des momentanen Kampfes und den eingestellten Anzeigemodus."
L["None"] = "Kein"
L["Return after combat"] = "Zurück nach Kampf"
L["Return to the previous set and mode after combat ends."] = "Nach dem Kampf wieder zur vorherigen Ansicht wechseln."
L["Show minimap button"] = "Zeige Minimap Knopf"
L["Toggles showing the minimap button."] = "Wechselt die Anzeige des Minimap-Knopfes."

L["reports the active mode"] = "berichtet den aktiven Modus"
L["Skada report on %s for %s, %s to %s:"] = "Skada: %s für %s, %s - %s:"
L["Only keep boss fighs"] = "Nur Bosskämpfe"
L["Boss fights will be kept with this on, and non-boss fights are discarded."] = "Nur Bosskämpfe werden gespeichert. Nicht-Bosskämpfe werden verworfen."
L["Show raw threat"] = "Nettobedrohung"
L["Shows raw threat percentage relative to tank instead of modified for range."] = "Zeigt Bedrohungsanteil im Vergleich zum Tank und nicht nach Entfernung."

L["Hide window"] = "Fenster verstecken"
L["Lock window"] = "Fenster sperren"
L["Locks the bar window in place."] = "Sperrt das Fenster gegen unbeabsichtigtes Verschieben."
L["Reverse bar growth"] = "Umgekehrter Leistenanstieg"
L["Bars will grow up instead of down."] = "Leisten wachsen nach oben, anstatt nach unten."
L["Number format"] = "Zahlenformat"
L["Controls the way large numbers are displayed."] = "Legt fest, wie große Zahlen angezeigt werden."
L["Reset on entering instance"] = "Beim Betreten einer Instanz:"
L["Controls if data is reset when you enter an instance."] = "Legt fest, ob die Daten zurückgesetzt werden, wenn Du eine Instanz betrittst."
L["Reset on joining a group"] = "Beim Beitritt in eine Gruppe:"
L["Controls if data is reset when you join a group."] = "Legt fest, ob die Daten zurückgesetzt werden, wenn Du einer Gruppe beitrittst."
L["Reset on leaving a group"] = "Beim Verlassen einer Gruppe:"
L["Controls if data is reset when you leave a group."] = "Legt fest, ob die Daten zurückgesetzt werden, wenn Du eine Gruppe verlässt."
L["General options"] = "Allgemeine Optionen"
L["Mode switching"] = "Moduswechsel"
L["Data resets"] = "Daten zurücksetzen"
L["Bars"] = "Leisten"

L["Yes"] = "Ja"
L["No"] = "Nein"
L["Ask"] = "Nachfragen"
L["Condensed"] = "Zusammengefasst"
L["Detailed"] = "Detailliert"

L["Hide when solo"] = "Verstecken, wenn Solo"
L["Hides Skada's window when not in a party or raid."] = "Versteckt das Skada-Fenster, wenn Du in keiner Gruppe oder in keinem Schlachtzug ist."

L["Title bar"] = "Titelleiste"
L["Background texture"] = "Hintergrundtextur"
L["The texture used as the background of the title."] = "Die Hintergrundtextur der Titelleiste."
L["Border texture"] = "Rahmentextur"
L["The texture used for the border of the title."] = "Die Rahmentextur der Titelleiste."
L["Border thickness"] = "Rahmenbreite"
L["The thickness of the borders."] = "Die Breite der Rahmen."
L["Background color"] = "Hintergrundfarbe"
L["The background color of the title."] = "Die Hintergrundfarbe der Titelleiste."

L["'s "] = "'s "
L["Do you want to reset Skada?"] = "Möchtest du Skada zurücksetzen?"
L["The margin between the outer edge and the background texture."] = "Der Rand zwischen der äußeren Kante und der Hintergrund-Textur."
L["Margin"] = "Seitenrand"
L["Window height"] = "Fensterhöhe"
L["The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."] = "Die Höhe des Fensters. Setzt man den Wert auf 0, wird die Höhe dynamisch geändert (abhängig davon wieviele Leisten existieren)."
L["Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."] = "Fügt den Leisten einen Hintergrund hinzu. Die Höhe des Hintergrund bestimmt wieviele Leisten angezeigt werden. Dies überschreibt die Einstellung für die maximale Anzahl an gezeigten Leisten."
L["Enable"] = "Aktivieren"
L["Background"] = "Hintergrund"
L["The texture used as the background."] = "Die als Hintergrund verwendete Textur."
L["The texture used for the borders."] = "Die für die Ränder verwendete Textur."
L["The color of the background."] = "Die Farbe des Hintergrunds."
L["Data feed"] = "Datenquelle"
L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."] = "Auswählen welche Datensammlung in der DataBroker-Ansicht angezeigt werden soll. Dies erfordert ein LDB-Anzeige-Addon, wie zum Beispiel 'Titan Panel'."
L["RDPS"] = "RDPS"
L["Damage: Personal DPS"] = "Schaden: Persönliche DPS"
L["Damage: Raid DPS"] = "Schaden: Raid-DPS"
L["Threat: Personal Threat"] = "Bedrohung: Persönliche Bedrohung"

L["Data segments to keep"] = "Zu behaltende Datensegmente"
L["The number of fight segments to keep. Persistent segments are not included in this."] = "Die Anzahl der Kampfsegmente die behalten werden sollen. Ständige Segmente sind hier nicht enthalten."

L["Alternate color"] = "Alternative Leistenfarbe"
L["Choose the alternate color of the bars."] = "Alternative Leistenfarbe auswählen"

L["Threat warning"] = "Bedrohungswarnung"
L["Flash screen"] = "Aufblitzen"
L["This will cause the screen to flash as a threat warning."] = "Lässt den Bildschirm aufblitzen als Aggrowarnung."
L["Shake screen"] = "Beben"
L["This will cause the screen to shake as a threat warning."] = "Lässt den Bildschirm beben als Aggrowarnung."
L["Play sound"] = "Sound"
L["This will play a sound as a threat warning."] = "Spielt einen Sound als Aggrowarnung."
L["Threat sound"] = "Bedrohungssound"
L["The sound that will be played when your threat percentage reaches a certain point."] = "Der Sound, der gespielt wird, wenn die Bedrohung einen gewissen Wert erreicht."
L["Threat threshold"] = "Bedrohungsgrenzwert"
L["When your threat reaches this level, relative to tank, warnings are shown."] = "Wenn die eigene Bedrohung gegenüber dem Tank diesen Wert erreicht werden Warnungen angezeigt."

L["Enables the title bar."] = "Aktiviert die Titelleiste."

L["Total healing"] = "Gesamte Heilung"

L["Skada Menu"] = "Skada Menü"
L["Switch to mode"] = "Wechsel zu Modus"
L["Report"] = "Bericht"
L["Toggle window"] = "Fenster ein/ausblenden"
L["Configure"] = "Konfigurieren"
L["Delete segment"] = "Segment löschen"
L["Keep segment"] = "Segment behalten"
L["Mode"] = "Modus"
L["Lines"] = "Zeilen"
L["Channel"] = "Kanal"
L["Send report"] = "Bericht senden"
L["No mode selected for report."] = "Kein Modus zum Berichten ausgewählt."
L["Say"] = "Sagen"
L["Raid"] = "Schlachtzug"
L["Party"] = "Gruppe"
L["Guild"] = "Gilde"
L["Officer"] = "Offizier"
L["Self"] = "Lokal"

L["'s Healing"] = " : Heilung"

L["Delete window"] = "Fenster löschen"
L["Deletes the chosen window."] = "Das ausgewählte Fenster löschen."
L["Choose the window to be deleted."] = "Wähle das Fenster, welches gelöscht werden soll."
L["Enter the name for the new window."] = "Den Namen für das neue Fenster eingeben."
L["Create window"] = "Fenster erstellen"
L["Windows"] = "Fenster"

L["Switch to segment"] = "Zu Segment wechseln"
L["Segment"] = "Segment"

L["Whisper"] = "Flüstern"
L["Whisper Target"] = "Ziel anflüstern???"
L["No mode or segment selected for report."] = "Kein Modus oder Segment zum Berichten ausgewählt."
L["Name of recipient"] = "Name des Empfängers"

L["Resist"] = "Widerstehen"
L["Reflect"] = "Reflektieren"
L["Parry"] = "Parieren"
L["Immune"] = "Immun"
L["Evade"] = "Entkommen"
L["Dodge"] = "Ausweichen"
L["Deflect"] = "Ablenken"
L["Block"] = "Blocken"
L["Absorb"] = "Absorbieren"

L["Last fight"] = "Letzter Kampf"
L["Disable while hidden"] = "Deaktivieren wenn versteckt"
L["Skada will not collect any data when automatically hidden."] = "Skada sammelt keine Daten wenn automatisch versteckt."

L["Rename window"] = "Fenster umbenennen"
L["Enter the name for the window."] = "Gib den Namen für das Fenster ein."

L["Bar display"] = "Leisten-Anzeige"
L["Display system"] = "Anzeige-System"
L["Choose the system to be used for displaying data in this window."] = "Wähle das System, dass für die Anzeige der Daten in diesem Fenster verwendet werden soll."

L["Hides HPS from the Healing modes."] = "Versteckt HPS im Heilmodus"
L["Do not show HPS"] = "HPS nicht anzeigen"

L["Do not show DPS"] = "DPS nicht anzeigen"
L["Hides DPS from the Damage mode."] = "Versteckt DPS im Schadenmodus."

L["Class color bars"] = "Klassen farbige Leisten"
L["When possible, bars will be colored according to player class."] = "Wenn möglich, werden die Leisten entsprechend der Klasse eingefärbt."
L["Class color text"] = "Klassen farbiger Text"
L["When possible, bar text will be colored according to player class."] = "Wenn möglich, wird der Leistentext entsprechend der Klasse eingefärbt."

L["Reset"] = "Zurücksetzen"
L["Show tooltips"] = "Tooltips anzeigen"
L["Power gained"] = "Erhaltene Energie"
L["Shows tooltips with extra information in some modes."] = "Zeigt Tooltips mit zusätzlicher Information in einigen Modi."

L["Total hits:"] = "Gesamte Treffer:???"
L["Minimum hit:"] = "Minimaler Treffer:"
L["Maximum hit:"] = "Maximaler Treffer:"
L["Average hit:"] = "Durchschnittlicher Treffer:"
L["Absorbs"] = "Absorptionen"
L["'s Absorbs"] = ": Absorptionen"

L["Do not show TPS"] = "TPS nicht anzeigen"
L["Do not warn while tanking"] = "Nicht warnen während des Tankens"

L["Hide in PvP"] = "Im PVP verstecken"
L["Hides Skada's window when in Battlegrounds/Arenas."] = "Skada-Fenster in Schlachtfeldern/Arenen verstecken"

L["Healed players"] = "Geheilte Spieler"
L["Healed by"] = "Geheilt von"
L["Absorb details"] = "Details der Schadensabsorption"
L["Spell details"] = "Zauberdetails"
L["Healing spell list"] = "Liste der Heilzauber"
L["Healing spell details"] = "Heilzauberdetails"
L["Debuff spell list"] = "Liste der Debuffs"
L["Buff spell list"] = "Liste der Buffs"

L["Power"] = "Energie"
L["gained %s"] = "%s erhalten"
L["Power gained: %s"] = "Erhaltene Energie: %s"
L["Power gain spell list"] = "Erhaltene Energie Zauberliste"
L["Power gained: Mana"] = "Erhaltene Energie: Mana"
L["Power gained: Rage"] = "Erhaltene Energie: Wut"
L["Power gained: Energy"] = "Erhaltene Energie: Energie"
L["Power gained: Runic Power"] = "Erhaltene Energie: Runenmacht"

L["Click for"] = "Klick für"
L["Shift-Click for"] = "Shift-Klick für"
L["Control-Click for"] = "Strg-Klick für"
L["Default"] = "Standard"
L["Top right"] = "Oben rechts"
L["Top left"] = "Oben links"
L["Bottom right"] = "Unten rechts"
L["Bottom left"] = "Unten links"
L["Follow cursor"] = "Zeigerposition"
L["Position of the tooltips."] = "Position der Tooltips"
L["Tooltip position"] = "Tooltipposition"

L["Damaged players"] = "Attackierte Spieler"
L["Shows a button for opening the menu in the window title bar."] = "Zeige Menüknopf in der Titelleiste"
L["Show menu button"] = "Zeige Menüknöpfe"


L["DTPS"] = "DTPS???"
L["Attack"] = "Nahkampf"
L["Damage"] = "Schaden"
L["Hit"] = "Treffer"
L["Critical"] = "Kritischer Treffer"
L["Missed"] = "Verfehlt"
L["Resisted"] = "Widerstanden"
L["Blocked"] = "Geblockt"
L["Glancing"] = "Gestreift"
L["Crushing"] = "Schmetternd"
L["Absorbed"] = "Absorbiert"
L["HPS"] = "HPS"
L["Healing"] = "Heilung"
L["'s Healing"] = "'s Heilung"
L["Overhealing"] = "Überheilung"
L["Threat"] = "Bedrohung"

L["Announce CC breaking to party"] = "CC Unterbrechungen der Gruppe ankündigen"
L["Ignore Main Tanks"] = "Maintanks ignorieren"
L["%s on %s removed by %s's %s"] = "%s auf %s entfernt durch %s's %s"
L["%s on %s removed by %s"] = "%s auf %s entfernt von %s"

L["Start new segment"] = "Neues Segment starten"
L["Columns"] = "Spalten"
L["Overheal"] = "Überheilung"
L["Percent"] = "Prozent"
L["TPS"] = "TPS"

L["%s dies"] = "%s stirbt"
L["Change"] = "Ändern"
L["Health"] = "Gesundheit"

L["Hide in combat"] = "Im Kampf verbergen"
L["Hides Skada's window when in combat."] = "Das Skada-Fenster im Kampf verstecken."

L["Tooltips"] = "Tooltips"
L["Informative tooltips"] = "Informative Tooltips"
L["Shows subview summaries in the tooltips."] = "Zeigt die Zusammenfassungen der Unteransichten in den Tooltips."
L["Subview rows"] = "Unteransicht Zeilen"
L["The number of rows from each subview to show when using informative tooltips."] = "Die Anzahl der anzuzeigenden Zeilen von jeder Unteransicht, wenn mit informativen Tooltips gearbeitet wird."

L["Damage done"] = "Schaden verursacht"
L["Active Time"] = "Aktive Zeit"
L["Segment Time"] = "Segmentzeit"
L["Absorbs and healing"] = "Absorptionen und Heilungen"
L["'s Absorbs and healing"] = "'s Absorptionen und Heilungen"
L["Healed and absorbed players"] = "Geheilte und absorbierende Spieler"
L["Healing and absorbs spell list"] = "Heilung und Absorptionen Zauberliste"

L["Show rank numbers"] = "Zeige Platzierungen"
L["Shows numbers for relative ranks for modes where it is applicable."] = "Zeige relative Platzierungen für Modis bei denen dies möglich ist."

L["Use focus target"] = "Benutze Fokusziel"
L["Shows threat on focus target, or focus target's target, when available."] = "Zeige Bedrohung des Fokuszieles, oder dessen Zieles, falls verfügbar."

L["Show spark effect"] = "Glanz Effekt anzeigen"

L["Aggressive combat detection"] = "Aggressive Kampferkennung"
L["Skada usually uses a very conservative (simple) combat detection scheme that works best in raids. With this option Skada attempts to emulate other damage meters. Useful for running dungeons. Meaningless on boss encounters."] = "Skada nutzt normalerweise einen sehr defensiven (einfache) Kampferkennungsmechanismus der am besten in Raids funktioniert. Mit dieser Option versucht Skada andere Damage Meter zu emulieren. Nützlich in Dungeons, ohne Effekt bei Bosskämpfen."

L["Tentative Timer"] = true
L["The number of seconds to wait for combat events when engaging combat.\nSkada only creates a new segment if there are enough combat events during a set amount of time.\n\nOnly applies if 'Aggressive combat detection' is turned off."] = true

L["Activity"] = "Aktivität"
L["Activity per target"] = "Aktivität pro Ziel"

-- Scroll
L["Key scrolling speed"] = true
L["Scroll"] = true
L["Scroll icon"] = true
L["Scrolling speed"] = true
L["Scroll mouse button"] = true
L["Mouse"] = true
L["Keybinding"] = true

-- =================== --
-- damage module lines --
-- =================== --

L["DPS"] = "DPS"

L["Damage Done"] = true
L["Damage on"] = "Schaden auf"
L["Damage on %s"] = true
L["Damage Done: %s"] = true
L["Damage spell details"] = true

L["Damage Taken"] = "Schaden erhalten"
L["Damage from"] = "Schaden von"
L["Damage from %s"] = true
L["Damage Taken: %s"] = true

L["Enemy damage done"] = "Ausgeteilter gegnerischer Schaden"
L["Enemy damage taken"] = "Erhaltener gegnerischer Schaden"

L["%s's Damage"] = " : Schaden"
L["%s's Damage taken"] = true
L["'s Sources"] = true
L["%s's Damage sources"] = true

L["Friendly Fire"] = true

L["%s's Targets"] = true
L["Targets"] = true
L["Damage Targets"] = true

L["Damage done by spell"] = true
L["Damage taken by spell"] = "Schaden erhalten durch Zauber"

L["Damage spell list"] = true
L["Damage spell sources"] = true
L["Damage spell targets"] = true

L["Damage done per player"] = "Ausgeteilter Schaden pro Spieler"
L["Damage taken per player"] = "Erhaltener Schaden pro Spieler"

-- ================== --
-- auras module lines --
-- ================== --

L["Auras: Buff uptime"] = true
L["Auras: Debuff uptime"] = true
L["Auras: Sunders Counter"] = true
L["Auras spell list"] = true
L["Auras target list"] = true
L["Buff Uptime"] = true
L["Debuff Uptime"] = true
L["%s's buff uptime"] = true
L["%s's debuff uptime"] = true
L["%s's debuff targets"] = true
L["%s's <%s> targets"] = true
L["Refreshes"] = true

-- ======================= --
-- interrupts module lines --
-- ======================= --

L["Interrupts"] = "Unterbrechungen"
L["Interrupt spells"] = true
L["Interrupted spells"] = "Unterbrochene Zauber"
L["Interrupted targets"] = "Unterbrochene Ziele"

-- ==================== --
-- failbot module lines --
-- ==================== --

L["Fails"] = "Fehler"
L["%s's Fails"] = "%s : Fehlgeschlagen"
L["Player's failed events"] = true
L["Event's failed players"] = true

-- ======================== --
-- improvement module lines --
-- ======================== --

L["Modes"] = true
L["Improvement"] = true
L["Improvement modes"] = true
L["Improvement comparison"] = true
L["Do you want to reset your improvement data?"] = true
L["Overall data"] = true

-- =================== --
-- deaths module lines --
-- =================== --

L["Deaths"] = "Tode"
L["%s's Death"] = "%s : Tode"
L["%s's Deaths"] = true
L["Death log"] = "Todesaufzeichnung"
L["%s's Death log"] = true
L["Player's deaths"] = true
L["Spell"] = true
L["Amount"] = true
L["Source"] = true

-- ==================== --
-- dispels module lines --
-- ==================== --

L["Dispels"] = "Entzauberungen"

L["Dispel spell list"] = true
L["Dispelled spell list"] = true
L["Dispelled target list"] = true

L["%s's dispel spells"] = true
L["%s's dispelled spells"] = true
L["%s's dispelled targets"] = true

-- ======================= --
-- cc tracker module lines --
-- ======================= --

L["CC"] = "CC"

L["CC Breaks"] = true
L["CC Breakers"] = "CC Unterbrecher"
L["CC Break Spells"] = true
L["CC Break Spell Targets"] = true
L["CC Break Targets"] = true
L["CC Break Target Spells"] = true
L["%s's CC Break <%s> spells"] = true
L["%s's CC Break <%s> targets"] = true

-- CC Done:
L["CC Done"] = true
L["CC Done Spells"] = true
L["CC Done Spell Targets"] = true
L["CC Done Targets"] = true
L["CC Done Target Spells"] = true
L["%s's CC Done <%s> targets"] = true
L["%s's CC Done <%s> spells"] = true

-- CC Taken
L["CC Taken"] = true
L["CC Taken Spells"] = true
L["CC Taken Spell Sources"] = true
L["CC Taken Sources"] = true
L["CC Taken Source Spells"] = true
L["%s's CC Taken <%s> sources"] = true
L["%s's CC Taken <%s> spells"] = true

-- ====================== --
-- resurrect module lines --
-- ====================== --

L["Resurrects"] = true
L["Resurrect spell list"] = true
L["Resurrect spell target list"] = true
L["Resurrect target list"] = true
L["Resurrect target spell list"] = true
L["received resurrects"] = true

L["%s's resurrect spells"] = true
L["%s's resurrect targets"] = true
L["%s's received resurrects"] = true
L["%s's resurrect <%s> targets"] = true

-- ====================== --
-- Avoidance & Mitigation --
-- ====================== --

L["Avoidance & Mitigation"] = true
L["Damage breakdown"] = true
L["%s's damage breakdown"] = "%s's Schadensverteilung"
L["ABSORB"] = "Absorb"
L["Auto Attack"] = "Automatischer Angriff"
L["BLOCK"] = "Block"
L["CRIT"] = "Crit"
L["CRUSH"] = "Crush"
L["DEFLECT"] = "Deflect"
L["DODGE"] = "Dodge"
L["EVADE"] = "Evade"
L["FULL ABSORB"] = "Full Absorb"
L["HIT"] = "Hit"
L["IMMUNE"] = "Immune"
L["MISS"] = "Miss"
L["PARRY"] = "Parry"
L["REFLECT"] = "Reflect"
L["RESIST"] = "Resist"
L["'s "] = true


L["Disabled Modules"] = "Deaktivierte Module"
L["Tick the modules you want to disable."] = true
L["This change requires a UI reload. Are you sure?"] = true
L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."] = "Hohe Speicherauslastung. Du solltest Skada zurücksetzen und automatisches zurücksetzen aktivieren"
