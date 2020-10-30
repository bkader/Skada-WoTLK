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
L["Total"] = true

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

L["Hide window"] = true
L["Lock window"] = true
L["Locks the bar window in place."] = true
L["Reverse bar growth"] = true
L["Bars will grow up instead of down."] = true
L["Number format"] = true
L["Controls the way large numbers are displayed."] = true
L["Reset on entering instance"] = true
L["Controls if data is reset when you enter an instance."] = true
L["Reset on joining a group"] = true
L["Controls if data is reset when you join a group."] = true
L["Reset on leaving a group"] = true
L["Controls if data is reset when you leave a group."] = true
L["General options"] = true
L["Mode switching"] = true
L["Data resets"] = true
L["Bars"] = true

L["Yes"] = true
L["No"] = true
L["Ask"] = true
L["Condensed"] = true
L["Detailed"] = true

L["Hide when solo"] = true
L["Hides Skada's window when not in a party or raid."] = true

L["Title bar"] = true
L["Background texture"] = true
L["The texture used as the background of the title."] = true
L["Border texture"] = true
L["The texture used for the border of the title."] = true
L["Border thickness"] = true
L["The thickness of the borders."] = true
L["Background color"] = true
L["The background color of the title."] = true

L["'s "] = true
L["Do you want to reset Skada?"] = true
L["The margin between the outer edge and the background texture."] = true
L["Margin"] = true
L["Window height"] = true
L["The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."] = true
L["Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."] = true
L["Enable"] = true
L["Background"] = true
L["The texture used as the background."] = true
L["The texture used for the borders."] = true
L["The color of the background."] = true
L["Data feed"] = true
L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."] = true
L["RDPS"] = true
L["Damage: Personal DPS"] = true
L["Damage: Raid DPS"] = true
L["Threat: Personal Threat"] = true

L["Data segments to keep"] = true
L["The number of fight segments to keep. Persistent segments are not included in this."] = true

L["Alternate color"] = true
L["Choose the alternate color of the bars."] = true

L["Threat warning"] = true
L["Flash screen"] = true
L["This will cause the screen to flash as a threat warning."] = true
L["Shake screen"] = true
L["This will cause the screen to shake as a threat warning."] = true
L["Play sound"] = true
L["This will play a sound as a threat warning."] = true
L["Threat sound"] = true
L["The sound that will be played when your threat percentage reaches a certain point."] = true
L["Threat threshold"] = true
L["When your threat reaches this level, relative to tank, warnings are shown."] = true

L["Enables the title bar."] = true

L["Total healing"] = true

L["Skada Menu"] = true
L["Switch to mode"] = true
L["Report"] = true
L["Toggle window"] = true
L["Configure"] = true
L["Delete segment"] = true
L["Keep segment"] = true
L["Mode"] = true
L["Lines"] = true
L["Channel"] = true
L["Send report"] = true
L["No mode selected for report."] = true
L["Say"] = true
L["Raid"] = true
L["Party"] = true
L["Guild"] = true
L["Officer"] = true
L["Self"] = true

L["'s Healing"] = true

L["Delete window"] = true
L["Deletes the chosen window."] = true
L["Choose the window to be deleted."] = true
L["Enter the name for the new window."] = true
L["Create window"] = true
L["Windows"] = true

L["Switch to segment"] = true
L["Segment"] = true

L["Whisper"] = true
L["Whisper Target"] = true
L["No mode or segment selected for report."] = true
L["Name of recipient"] = true

L["Resist"] = true
L["Reflect"] = true
L["Parry"] = true
L["Immune"] = true
L["Evade"] = true
L["Dodge"] = true
L["Deflect"] = true
L["Block"] = true
L["Absorb"] = true

L["Last fight"] = true
L["Disable while hidden"] = true
L["Skada will not collect any data when automatically hidden."] = true

L["Rename window"] = true
L["Enter the name for the window."] = true

L["Bar display"] = true
L["Display system"] = true
L["Choose the system to be used for displaying data in this window."] = true

L["Hides HPS from the Healing modes."] = true
L["Do not show HPS"] = true

L["Do not show DPS"] = true
L["Hides DPS from the Damage mode."] = true

L["Class color bars"] = true
L["When possible, bars will be colored according to player class."] = true
L["Class color text"] = true
L["When possible, bar text will be colored according to player class."] = true

L["Reset"] = true
L["Show tooltips"] = true
L["Power gained"] = true
L["Shows tooltips with extra information in some modes."] = true

L["Total hits:"] = true
L["Minimum hit:"] = true
L["Maximum hit:"] = true
L["Average hit:"] = true
L["Absorbs"] = true
L["'s Absorbs"] = true

L["Do not show TPS"] = true
L["Do not warn while tanking"] = true

L["Hide in PvP"] = true
L["Hides Skada's window when in Battlegrounds/Arenas."] = true

L["Healed players"] = true
L["Healed by"] = true
L["Absorb details"] = true
L["Spell details"] = true
L["Healing spell list"] = true
L["Healing spell details"] = true
L["Debuff spell list"] = true
L["Buff spell list"] = true

L["Power"] = true
L["gained %s"] = true
L["Power gained: %s"] = true
L["Power gain spell list"] = true
L["Power gained: Mana"] = true
L["Power gained: Rage"] = true
L["Power gained: Energy"] = true
L["Power gained: Runic Power"] = true

L["Click for"] = true
L["Shift-Click for"] = true
L["Control-Click for"] = true
L["Default"] = true
L["Top right"] = true
L["Top left"] = true
L["Bottom right"] = true
L["Bottom left"] = true
L["Follow cursor"] = true
L["Position of the tooltips."] = true
L["Tooltip position"] = true

L["Damaged players"] = true
L["Shows a button for opening the menu in the window title bar."] = true
L["Show menu button"] = true


L["DTPS"] = true
L["Attack"] = true
L["Damage"] = true
L["Hit"] = true
L["Critical"] = true
L["Missed"] = true
L["Resisted"] = true
L["Blocked"] = true
L["Glancing"] = true
L["Crushing"] = true
L["Absorbed"] = true
L["HPS"] = true
L["Healing"] = true
L["'s Healing"] = true
L["Overhealing"] = true
L["Threat"] = true

L["Announce CC breaking to party"] = true
L["Ignore Main Tanks"] = true
L["%s on %s removed by %s's %s"]= true
L["%s on %s removed by %s"]= true

L["Start new segment"] = true
L["Columns"] = true
L["Overheal"] = true
L["Percent"] = true
L["TPS"] = true

L["%s dies"] = true
L["Change"] = true
L["Health"] = true

L["Hide in combat"] = true
L["Hides Skada's window when in combat."] = true

L["Tooltips"] = true
L["Informative tooltips"] = true
L["Shows subview summaries in the tooltips."] = true
L["Subview rows"] = true
L["The number of rows from each subview to show when using informative tooltips."] = true

L["Damage done"] = true
L["Active Time"] = true
L["Segment Time"] = true
L["Absorbs and healing"] = true
L["'s Absorbs and healing"] = true
L["Healed and absorbed players"] = true
L["Healing and absorbs spell list"] = true

L["Show rank numbers"] = true
L["Shows numbers for relative ranks for modes where it is applicable."] = true

L["Use focus target"] = true
L["Shows threat on focus target, or focus target's target, when available."] = true

L["Show spark effect"] = true

L["Aggressive combat detection"] = true
L["Skada usually uses a very conservative (simple) combat detection scheme that works best in raids. With this option Skada attempts to emulate other damage meters. Useful for running dungeons. Meaningless on boss encounters."] = true

L["Tentative Timer"] = true
L["The number of seconds to wait for combat events when engaging combat.\nSkada only creates a new segment if there are enough combat events during a set amount of time.\n\nOnly applies if 'Aggressive combat detection' is turned off."] = true

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
L["Damage on"] = true
L["Damage on %s"] = true
L["Damage Done: %s"] = true
L["Damage spell details"] = true

L["Damage Taken"] = true
L["Damage from"] = true
L["Damage from %s"] = true
L["Damage Taken: %s"] = true

L["Enemy damage done"] = true
L["Enemy damage taken"] = true

L["%s's Damage"] = true
L["%s's Damage taken"] = true
L["'s Sources"] = true
L["%s's Damage sources"] = true

L["Friendly Fire"] = true

L["%s's Targets"] = true
L["Targets"] = true
L["Damage Targets"] = true

L["Damage done by spell"] = true
L["Damage taken by spell"] = true

L["Damage spell list"] = true
L["Damage spell sources"] = true
L["Damage spell targets"] = true

L["Damage done per player"] = true
L["Damage taken per player"] = true

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

L["Interrupts"] = true
L["Interrupt spells"] = true
L["Interrupted spells"] = true
L["Interrupted targets"] = true

-- ==================== --
-- failbot module lines --
-- ==================== --

L["Fails"] = true
L["%s's Fails"] = true
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
L["%s's Death"] = true
L["%s's Deaths"] = true
L["Death log"] = true
L["%s's Death log"] = true
L["Player's deaths"] = true
L["Spell"] = true
L["Amount"] = true
L["Source"] = true

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


L["Disabled Modules"] = true
L["Tick the modules you want to disable."] = true
L["This change requires a UI reload. Are you sure?"] = true
L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."] = true
