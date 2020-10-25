local L = LibStub("AceLocale-3.0"):NewLocale("Skada", "enUS", true)

if not L then return end

L["Disable"] = true
L["Profiles"] = true
L["Hint: Left-Click to toggle Skada window."] = true
L["Shift + Left-Click to reset."] = true
L["Right-click to open menu"] = true
L["Options"] = true
L["Appearance"] = true
L["A damage meter."] = true
L["Skada summary"] = true
L["Timestamp"] = true

L["opens the configuration window"] = true
L["resets all data"] = true

L["Current"] = "Current fight"
L["Total"] = "Total"

L["Error: No options selected"] = true
L["All data has been reset."] = true
L["Skada: Modes"] = true
L["Skada: Fights"] = true

-- Options
L["Bar font"] = true
L["The font used by all bars."] = true
L["Bar font size"] = true
L["The font size of all bars."] = true
L["Bar texture"] = true
L["The texture used by all bars."] = true
L["Bar spacing"] = true
L["Distance between bars."] = true
L["Bar height"] = true
L["The height of the bars."] = true
L["Bar width"] = true
L["The width of the bars."] = true
L["Bar color"] = true
L["Choose the default color of the bars."] = true
L["Max bars"] = true
L["The maximum number of bars shown."] = true
L["Bar orientation"] = true
L["The direction the bars are drawn in."] = true
L["Left to right"] = true
L["Right to left"] = true
L["Combat mode"] = true
L["Automatically switch to set 'Current' and this mode when entering combat."] = true
L["None"] = true
L["Return after combat"] = true
L["Return to the previous set and mode after combat ends."] = true
L["Show minimap button"] = true
L["Toggles showing the minimap button."] = true

L["reports the active mode"] = true
L["Skada report on %s for %s, %s to %s:"] = "Skada: %s for %s, %s - %s:"
L["Only keep boss fighs"] = "Only keep boss fights"
L["Boss fights will be kept with this on, and non-boss fights are discarded."] = true
L["Show raw threat"] = true
L["Shows raw threat percentage relative to tank instead of modified for range."] = true

L["Lock window"] = "Lock window"
L["Locks the bar window in place."] = "Locks the bar window in place."
L["Reverse bar growth"] = "Reverse bar growth"
L["Bars will grow up instead of down."] = "Bars will grow up instead of down."
L["Number format"] = "Number format"
L["Controls the way large numbers are displayed."] = "Controls the way large numbers are displayed."
L["Reset on entering instance"] = "Reset on entering instance"
L["Controls if data is reset when you enter an instance."] = "Controls if data is reset when you enter an instance."
L["Reset on joining a group"] = "Reset on joining a group"
L["Controls if data is reset when you join a group."] = "Controls if data is reset when you join a group."
L["Reset on leaving a group"] = "Reset on leaving a group"
L["Controls if data is reset when you leave a group."] = "Controls if data is reset when you leave a group."
L["General options"] = "General options"
L["Mode switching"] = "Mode switching"
L["Data resets"] = "Data resets"
L["Bars"] = "Bars"

L["Yes"] = "Yes"
L["No"] = "No"
L["Ask"] = "Ask"
L["Condensed"] = "Condensed"
L["Detailed"] = "Detailed"

L["Hide when solo"] = "Hide when solo"
L["Hides Skada's window when not in a party or raid."] = "Hides Skada's window when not in a party or raid."

L["Title bar"] = "Title bar"
L["Background texture"] = "Background texture"
L["The texture used as the background of the title."] = "The texture used as the background of the title."
L["Border texture"] = "Border texture"
L["The texture used for the border of the title."] = "The texture used for the border of the title."
L["Border thickness"] = "Border thickness"
L["The thickness of the borders."] = "The thickness of the borders."
L["Background color"] = "Background color"
L["The background color of the title."] = "The background color of the title."

L["'s "] = "'s "
L["Do you want to reset Skada?"] = "Do you want to reset Skada?"
L["The margin between the outer edge and the background texture."] = "The margin between the outer edge and the background texture."
L["Margin"] = "Margin"
L["Window height"] = "Window height"
L["The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."] = "The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."
L["Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."] = "Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."
L["Enable"] = "Enable"
L["Background"] = "Background"
L["The texture used as the background."] = "The texture used as the background."
L["The texture used for the borders."] = "The texture used for the borders."
L["The color of the background."] = "The color of the background."
L["Data feed"] = "Data feed"
L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."] = "Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."
L["RDPS"] = "RDPS"
L["Damage: Personal DPS"] = "Damage: Personal DPS"
L["Damage: Raid DPS"] = "Damage: Raid DPS"
L["Threat: Personal Threat"] = "Threat: Personal Threat"

L["Data segments to keep"] = "Data segments to keep"
L["The number of fight segments to keep. Persistent segments are not included in this."] = "The number of fight segments to keep. Persistent segments are not included in this."

L["Alternate color"] = "Alternate color"
L["Choose the alternate color of the bars."] = "Choose the alternate color of the bars."

L["Threat warning"] = "Threat warning"
L["Flash screen"] = "Flash screen"
L["This will cause the screen to flash as a threat warning."] = "This will cause the screen to flash as a threat warning."
L["Shake screen"] = "Shake screen"
L["This will cause the screen to shake as a threat warning."] = "This will cause the screen to shake as a threat warning."
L["Play sound"] = "Play sound"
L["This will play a sound as a threat warning."] = "This will play a sound as a threat warning."
L["Threat sound"] = "Threat sound"
L["The sound that will be played when your threat percentage reaches a certain point."] = "The sound that will be played when your threat percentage reaches a certain point."
L["Threat threshold"] = "Threat threshold"
L["When your threat reaches this level, relative to tank, warnings are shown."] = "When your threat reaches this level, relative to tank, warnings are shown."

L["Enables the title bar."] = "Enables the title bar."

L["Total healing"] = "Total healing"

L["Skada Menu"] = "Skada Menu"
L["Switch to mode"] = "Switch to mode"
L["Report"] = "Report"
L["Toggle window"] = "Toggle window"
L["Configure"] = "Configure"
L["Delete segment"] = "Delete segment"
L["Keep segment"] = "Keep segment"
L["Mode"] = "Mode"
L["Lines"] = "Lines"
L["Channel"] = "Channel"
L["Send report"] = "Send report"
L["No mode selected for report."] = "No mode selected for report."
L["Say"] = "Say"
L["Raid"] = "Raid"
L["Party"] = "Party"
L["Guild"] = "Guild"
L["Officer"] = "Officer"
L["Self"] = "Self"

L["'s Healing"] = "'s Healing"

L["Delete window"] = "Delete window"
L["Deletes the chosen window."] = "Deletes the chosen window."
L["Choose the window to be deleted."] = "Choose the window to be deleted."
L["Enter the name for the new window."] = "Enter the name for the new window."
L["Create window"] = "Create window"
L["Windows"] = "Windows"

L["Switch to segment"] = "Switch to segment"
L["Segment"] = "Segment"

L["Whisper"] = "Whisper"
L["Whisper Target"] = "Whisper Target"
L["No mode or segment selected for report."] = "No mode or segment selected for report."
L["Name of recipient"] = "Name of recipient"

L["Resist"] = "Resist"
L["Reflect"] = "Reflect"
L["Parry"] = "Parry"
L["Immune"] = "Immune"
L["Evade"] = "Evade"
L["Dodge"] = "Dodge"
L["Deflect"] = "Deflect"
L["Block"] = "Block"
L["Absorb"] = "Absorb"

L["Last fight"] = "Last fight"
L["Disable while hidden"] = "Disable while hidden"
L["Skada will not collect any data when automatically hidden."] = "Skada will not collect any data when automatically hidden."

L["Rename window"] = "Rename window"
L["Enter the name for the window."] = "Enter the name for the window."

L["Bar display"] = "Bar display"
L["Display system"] = "Display system"
L["Choose the system to be used for displaying data in this window."] = "Choose the system to be used for displaying data in this window."

L["Hides HPS from the Healing modes."] = "Hides HPS from the Healing modes."
L["Do not show HPS"] = "Do not show HPS"

L["Do not show DPS"] = "Do not show DPS"
L["Hides DPS from the Damage mode."] = "Hides DPS from the Damage mode."

L["Class color bars"] = "Class color bars"
L["When possible, bars will be colored according to player class."] = "When possible, bars will be colored according to player class."
L["Class color text"] = "Class color text"
L["When possible, bar text will be colored according to player class."] = "When possible, bar text will be colored according to player class."

L["Reset"] = "Reset"
L["Show tooltips"] = "Show tooltips"
L["Power gained"] = "Power gained"
L["Shows tooltips with extra information in some modes."] = "Shows tooltips with extra information in some modes."

L["Total hits:"] = "Total hits:"
L["Minimum hit:"] = "Minimum hit:"
L["Maximum hit:"] = "Maximum hit:"
L["Average hit:"] = "Average hit:"
L["Absorbs"] = "Absorbs"
L["'s Absorbs"] = "'s Absorbs"

L["Do not show TPS"] = "Do not show TPS"
L["Do not warn while tanking"] = "Do not warn while tanking"

L["Hide in PvP"] = "Hide in PvP"
L["Hides Skada's window when in Battlegrounds/Arenas."] = "Hides Skada's window when in Battlegrounds/Arenas."

L["Healed players"] = "Healed players"
L["Healed by"] = "Healed by"
L["Absorb details"] = "Absorb details"
L["Spell details"] = "Spell details"
L["Healing spell list"] = "Healing spell list"
L["Healing spell details"] = "Healing spell details"
L["Debuff spell list"] = "Debuff spell list"
L["Buff spell list"] = "Buff spell list"

L["Power"] = true
L["gained %s"] = true
L["Power gained: %s"] = true
L["Power gain spell list"] = "Power gain spell list"

L["Click for"] = "Click for"
L["Shift-Click for"] = "Shift-Click for"
L["Control-Click for"] = "Control-Click for"
L["Default"] = "Default"
L["Top right"] = "Top right"
L["Top left"] = "Top left"
L["Bottom right"] = "Bottom right"
L["Bottom left"] = "Bottom left"
L["Follow cursor"] = "Follow cursor"
L["Position of the tooltips."] = "Position of the tooltips."
L["Tooltip position"] = "Tooltip position"

L["Damaged players"] = "Damaged players"
L["Shows a button for opening the menu in the window title bar."] = "Shows a button for opening the menu in the window title bar."
L["Show menu button"] = "Show menu button"


L["DTPS"] = true
L["Attack"] = true
L["Damage"] = true
L["Hit"] = true
L["Critical"] = true
L["Missed"] = true
L["Resisted"] = true
L["Blocked"] = true
L["Glancing"] = true
L["Crushing"] = "Crushing"
L["Absorbed"] = true
L["HPS"] = "HPS"
L["Healing"] = true
L["'s Healing"] = true
L["Overhealing"] = true
L["Threat"] = true

L["Announce CC breaking to party"] = true
L["Ignore Main Tanks"] = true
L["%s on %s removed by %s's %s"]= true
L["%s on %s removed by %s"]= true

L["Start new segment"] = true
L["Columns"] = "Columns"
L["Overheal"] = "Overheal"
L["Percent"] = "Percent"
L["TPS"] = "TPS"

L["%s dies"] = "%s dies"
L["Change"] = "Change"
L["Health"] = "Health"

L["Hide in combat"] = "Hide in combat"
L["Hides Skada's window when in combat."] = "Hides Skada's window when in combat."

L["Tooltips"] = "Tooltips"
L["Informative tooltips"] = "Informative tooltips"
L["Shows subview summaries in the tooltips."] = "Shows subview summaries in the tooltips."
L["Subview rows"] = "Subview rows"
L["The number of rows from each subview to show when using informative tooltips."] = "The number of rows from each subview to show when using informative tooltips."

L["Damage done"] = "Damage done"
L["Active Time"] = "Active Time"
L["Segment Time"] = "Segment Time"
L["Absorbs and healing"] = "Absorbs and healing"
L["'s Absorbs and healing"] = "'s Absorbs and healing"
L["Healed and absorbed players"] = "Healed and absorbed players"
L["Healing and absorbs spell list"] = "Healing and absorbs spell list"

L["Show rank numbers"] = "Show rank numbers"
L["Shows numbers for relative ranks for modes where it is applicable."] = "Shows numbers for relative ranks for modes where it is applicable."

L["Use focus target"] = "Use focus target"
L["Shows threat on focus target, or focus target's target, when available."] = "Shows threat on focus target, or focus target's target, when available."

L["Show spark effect"] = "Show spark effect"

L["Aggressive combat detection"] = "Aggressive combat detection"
L["Skada usually uses a very conservative (simple) combat detection scheme that works best in raids. With this option Skada attempts to emulate other damage meters. Useful for running dungeons. Meaningless on boss encounters."] = "Skada usually uses a very conservative (simple) combat detection scheme that works best in raids. With this option Skada attempts to emulate other damage meters. Useful for running dungeons. Meaningless on boss encounters."

L["Tentative Timer"] = "Tentative Timer"
L["The number of seconds to wait for combat events when engaging combat.\nSkada only creates a new segment if there are enough combat events during a set amount of time.\n\nOnly applies if 'Aggressive combat detection' is turned off."] = "The number of seconds to wait for combat events when engaging combat.\nSkada only creates a new segment if there are enough combat events during a set amount of time.\n\nOnly applies if 'Aggressive combat detection' is turned off."

L["Activity"] = true
L["Activity per target"] = true

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

L["DPS"] = true

L["Damage Done"] = true
L["Damage on"] = "Damage on"
L["Damage on %s"] = true
L["Damage Done: %s"] = true
L["Damage spell details"] = "Damage spell details"

L["Damage Taken"] = true
L["Damage from"] = "Damage from"
L["Damage from %s"] = true
L["Damage Taken: %s"] = true

L["Enemy damage done"] = "Enemy damage done"
L["Enemy damage taken"] = "Enemy damage taken"

L["%s's Damage"] = true
L["%s's Damage taken"] = true
L["'s Sources"] = true
L["%s's Damage sources"] = "%s's Damage sources"

L["Friendly Fire"] = true

L["%s's Targets"] = true
L["Targets"] = true
L["Damage Targets"] = "Damage Targets"

L["Damage done by spell"] = "Damage done by spell"
L["Damage taken by spell"] = "Damage taken by spell"

L["Damage spell list"] = "Damage spell list"
L["Damage spell sources"] = "Damage spell sources"
L["Damage spell targets"] = "Damage spell targets"

L["Damage done per player"] = "Damage done per player"
L["Damage taken per player"] = "Damage taken per player"

-- ================== --
-- auras module lines --
-- ================== --

L["Auras: Buff uptime"] = true
L["Auras: Debuff uptime"] = true
L["Auras: Sunders Counter"] = true
L["Auras spell list"] = "Auras spell list"
L["Auras target list"] = "Auras target list"
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

L["Interrupts"] = true
L["Interrupt spells"] = true
L["Interrupted spells"] = true
L["Interrupted targets"] = true

-- ==================== --
-- failbot module lines --
-- ==================== --

L["Fails"] = true
L["%s's Fails"] = "%s's Fails"
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

L["Deaths"] = true
L["%s's Death"] = "%s's Death"
L["%s's Deaths"] = "%s's Deaths"
L["Death log"] = "Death log"
L["%s's Death log"] = "%s's Death log"
L["Player's deaths"] = "Player's deaths"
L["Spell"] = "Spell"
L["Amount"] = "Amount"
L["Source"] = "Source"

-- ==================== --
-- dispels module lines --
-- ==================== --

L["Dispels"] = true

L["Dispel spell list"] = true
L["Dispelled spell list"] = true
L["Dispelled target list"] = true

L["%s's dispel spells"] = true
L["%s's dispelled spells"] = true
L["%s's dispelled targets"] = true

-- ======================= --
-- cc tracker module lines --
-- ======================= --

L["CC"] = true

L["CC Breaks"] = true
L["CC Breakers"] = true
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
L["%s's damage breakdown"] = true
L["ABSORB"] = "Absorb"
L["Auto Attack"] = true
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
