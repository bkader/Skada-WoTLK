local L = LibStub("AceLocale-3.0"):NewLocale("Skada", "koKR", false)
if not L then return end

-- L["A damage meter."] = ""
-- L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."] = ""

-- L["Skada: Modes"] = ""
-- L["Skada: Fights"] = ""

-- L["Error: No options selected"] = ""

-- L["Profiles"] = ""
-- L["Enable"] = ""
-- L["ENABLED"] = ""
-- L["Disable"] = ""
-- L["DISABLED"] = ""

-- common lines
-- L["Active Time"] = ""
-- L["Segment Time"] = ""
-- L["Click for"] = ""
-- L["Shift-Click for"] = ""
-- L["Control-Click for"] = ""
-- L["Minimum"] = ""
-- L["Minimum hit:"] = ""
-- L["Maximum"] = ""
-- L["Maximum hit:"] = ""
-- L["Average"] = ""
-- L["Average hit:"] = ""
-- L["Total hits:"] = ""
-- L["Count"] = ""
-- L["Percent"] = ""

-- spell schools
-- L["Arcane"] = ""
-- L["Fire"] = ""
-- L["Frost"] = ""
-- L["Frostfire"] = ""
-- L["Holy"] = ""
-- L["Nature"] = ""
-- L["Naturefire"] = ""
-- L["Physical"] = ""
-- L["Shadow"] = ""

-- L["General options"] = ""

-- windows section:
-- L["Window"] = ""
-- L["Windows"] = ""

-- L["Create window"] = ""
-- L["Enter the name for the new window."] = ""

-- L["Delete window"] = ""
-- L["Choose the window to be deleted."] = ""

-- L["Deletes the chosen window."] = ""

-- L["Rename window"] = ""
-- L["Enter the name for the window."] = ""
-- L["Lock window"] = ""
-- L["Locks the bar window in place."] = ""
-- L["Hide window"] = ""
-- L["Hides the window."] = ""
-- L["Display system"] = ""
-- L["Choose the system to be used for displaying data in this window."] = ""

-- bars
-- L["Bars"] = ""
-- L["Bar font"] = ""
-- L["The font used by all bars."] = ""
-- L["Bar font size"] = ""
-- L["The font size of all bars."] = ""

-- L["Values font"] = ""
-- L["The font used by bar values."] = ""
-- L["Values font size"] = ""
-- L["The font size of bar values."] = ""

-- L["Font flags"] = ""
-- L["Sets the font flags."] = ""
-- L["None"] = ""
-- L["Outline"] = ""
-- L["Thick outline"] = ""
-- L["Monochrome"] = ""
-- L["Outlined monochrome"] = ""
-- L["Bar texture"] = ""
-- L["The texture used by all bars."] = ""
-- L["Bar spacing"] = ""
-- L["Distance between bars."] = ""
-- L["Bar height"] = ""
-- L["The height of the bars."] = ""
-- L["Bar width"] = ""
-- L["The width of the bars."] = ""
-- L["Bar orientation"] = ""
-- L["The direction the bars are drawn in."] = ""
-- L["Left to right"] = ""
-- L["Right to left"] = ""
-- L["Reverse bar growth"] = ""
-- L["Bars will grow up instead of down."] = ""
-- L["Bar color"] = ""
-- L["Choose the default color of the bars."] = ""
-- L["Background color"] = ""
-- L["Choose the background color of the bars."] = ""
-- L["Spell school colors"] = ""
-- L["Use spell school colors where applicable."] = ""
-- L["Class color bars"] = ""
-- L["When possible, bars will be colored according to player class."] = ""
-- L["Class color text"] = ""
-- L["When possible, bar text will be colored according to player class."] = ""
-- L["Class icons"] = ""
-- L["Use class icons where applicable."] = ""
-- L["Spec icons"] = ""
-- L["Use specialization icons where applicable."] = ""
-- L["Role icons"] = ""
-- L["Use role icons where applicable."] = ""
-- L["Clickthrough"] = ""
-- L["Disables mouse clicks on bars."] = ""
-- L["Smooth bars"] = ""
-- L["Animate bar changes smoothly rather than immediately."] = ""

-- title bar
-- L["Title bar"] = ""
-- L["Enables the title bar."] = ""
-- L["Include set"] = ""
-- L["Include set name in title bar"] = ""
-- L["Title height"] = ""
-- L["The height of the title frame."] = ""
-- L["Title font size"] = ""
-- L["The font size of the title bar."] = ""
-- L["Title color"] = ""
-- L["The text color of the title."] = ""
-- L["The texture used as the background of the title."] = ""
-- L["The background color of the title."] = ""
-- L["Border texture"] = ""
-- L["The texture used for the borders."] = ""
-- L["The texture used for the border of the title."] = ""
-- L["Border color"] = ""
-- L["The color used for the border."] = ""
-- L["Buttons"] = ""

-- general window
-- L["Background"] = ""
-- L["Background texture"] = ""
-- L["The texture used as the background."] = ""
-- L["Tile"] = ""
-- L["Tile the background texture."] = ""
-- L["Tile size"] = ""
-- L["The size of the texture pattern."] = ""
-- L["Background color"] = ""
-- L["The color of the background."] = ""
-- L["Border"] = ""
-- L["Border thickness"] = ""
-- L["The thickness of the borders."] = ""
-- L["General"] = ""
-- L["Scale"] = ""
-- L["Sets the scale of the window."] = ""
-- L["Strata"] = ""
-- L["This determines what other frames will be in front of the frame."] = ""
-- L["Width"] = ""
-- L["Height"] = ""

-- switching
-- L["Mode switching"] = ""
-- L["Combat mode"] = ""
-- L["Automatically switch to set 'Current' and this mode when entering combat."] = ""
-- L["Return after combat"] = ""
-- L["Return to the previous set and mode after combat ends."] = ""
-- L["Wipe mode"] = ""
-- L["Automatically switch to set 'Current' and this mode after a wipe."] = ""

-- L["Inline bar display"] = ""
-- L["Inline display is a horizontal window style."] = ""
-- L["Text"] = ""
-- L["Font Color"] = ""
-- L["Font Color. \nClick \"Use class colors\" to begin."] = ""
-- L["Width of bars. This only applies if the \"Fixed bar width\" option is used."] = ""
-- L["Fixed bar width"] = ""
-- L["If checked, bar width is fixed. Otherwise, bar width depends on the text width."] = ""
-- L["Use class colors"] = ""
-- L["Class colors:\n|cFFF58CBAKader|r - 5.71M (21.7K)\n\nWithout:\nKader - 5.71M (21.7K)"] = ""
-- L["Put values on new line."] = ""
-- L["New line:\nKader\n5.71M (21.7K)\n\nDivider:\nKader - 5.71M (21.7K)"] = ""
-- L["Use ElvUI skin if avaliable."] = ""
-- L["Check this to use ElvUI skin instead. \nDefault: checked"] = ""
-- L["Use solid background."] = ""
-- L["Un-check this for an opaque background."] = ""

-- L["Data text"] = ""
-- L["Text color"] = ""
-- L["Choose the default color."] = ""
-- L["Hint: Left-Click to set active mode."] = ""
-- L["Right-click to set active set."] = ""
-- L["Shift+Left-Click to open menu."] = ""

-- data resets
-- L["Data resets"] = ""
-- L["Reset on entering instance"] = ""
-- L["Controls if data is reset when you enter an instance."] = ""
-- L["Reset on joining a group"] = ""
-- L["Controls if data is reset when you join a group."] = ""
-- L["Reset on leaving a group"] = ""
-- L["Controls if data is reset when you leave a group."] = ""
-- L["Ask"] = ""
-- L["Do you want to reset Skada?"] = ""
-- L["All data has been reset."] = ""

-- general options
-- L["Show minimap button"] = ""
-- L["Toggles showing the minimap button."] = ""
-- L["Shorten menus"] = ""
-- L["Removes mode and segment menus from Skada menu to reduce its height. Menus are still accessible using window buttons."] = ""
-- L["Translit"] = ""
-- L["Make those russian letters that no one understand to be presented as western letters."] = ""
-- L["Merge pets"] = ""
-- L["Merges pets with their owners. Changing this only affects new data."] = ""
-- L["Show totals"] = ""
-- L["Shows a extra row with a summary in certain modes."] = ""
-- L["Only keep boss fighs"] = ""
-- L["Boss fights will be kept with this on, and non-boss fights are discarded."] = ""
-- L["Hide when solo"] = ""
-- L["Hides Skada's window when not in a party or raid."] = ""
-- L["Hide in PvP"] = ""
-- L["Hides Skada's window when in Battlegrounds/Arenas."] = ""
-- L["Hide in combat"] = ""
-- L["Hides Skada's window when in combat."] = ""
-- L["Disable while hidden"] = ""
-- L["Skada will not collect any data when automatically hidden."] = ""
-- L["Sort modes by usage"] = ""
-- L["The mode list will be sorted to reflect usage instead of alphabetically."] = ""
-- L["Show rank numbers"] = ""
-- L["Shows numbers for relative ranks for modes where it is applicable."] = ""
-- L["Aggressive combat detection"] = ""
-- L["Skada usually uses a very conservative (simple) combat detection scheme that works best in raids. With this option Skada attempts to emulate other damage meters. Useful for running dungeons. Meaningless on boss encounters."] = ""
-- L["Autostop"] = ""
-- L["Automatically stops the current segment after half of all raid members have died."] = ""
-- L["Always show self"] = ""
-- L["Keeps the player shown last even if there is not enough space."] = ""
-- L["Number format"] = ""
-- L["Controls the way large numbers are displayed."] = ""
-- L["Condensed"] = ""
-- L["Detailed"] = ""
-- L["Data feed"] = ""
-- L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."] = ""
-- L["Number set duplicates"] = ""
-- L["Append a count to set names with duplicate mob names."] = ""
-- L["Set format"] = ""
-- L["Controls the way set names are displayed."] = ""
-- L["Memory Check"] = ""
-- L["Checks memory usage and warns you if it is greater than or equal to 30mb."] = ""
-- L["Data segments to keep"] = ""
-- L["The number of fight segments to keep. Persistent segments are not included in this."] = ""
-- L["Update frequency"] = ""
-- L["How often windows are updated. Shorter for faster updates. Increases CPU usage."] = ""

-- columns
-- L["Columns"] = ""

-- tooltips
-- L["Tooltips"] = ""
-- L["Show tooltips"] = ""
-- L["Shows tooltips with extra information in some modes."] = ""
-- L["Informative tooltips"] = ""
-- L["Shows subview summaries in the tooltips."] = ""
-- L["Subview rows"] = ""
-- L["The number of rows from each subview to show when using informative tooltips."] = ""
-- L["Tooltip position"] = ""
-- L["Position of the tooltips."] = ""
-- L["Default"] = ""
-- L["Top right"] = ""
-- L["Top left"] = ""
-- L["Bottom right"] = ""
-- L["Bottom left"] = ""
-- L["Smart"] = ""
-- L["Follow Cursor"] = ""

-- disabled modules
-- L["Disabled Modules"] = ""
-- L["Tick the modules you want to disable."] = ""
-- L["This change requires a UI reload. Are you sure?"] = ""
-- L["Adds a set of standard themes to Skada. Custom themes can also be used."] = ""

-- themes module
-- L["Theme"] = ""
-- L["Themes"] = ""
-- L["Apply theme"] = ""
-- L["Theme applied!"] = ""
-- L["Name of your new theme."] = ""
-- L["Save theme"] = ""
-- L["Delete theme"] = ""

-- scroll module
-- L["Scroll"] = ""
-- L["Mouse"] = ""
-- L["Scrolling speed"] = ""
-- L["Scroll icon"] = ""
-- L["Scroll mouse button"] = ""
-- L["Keybinding"] = ""
-- L["Key scrolling speed"] = ""

-- minimap button
-- L["Skada summary"] = ""
-- L["Left-Click to toggle windows."] = ""
-- L["Shift+Left-Click to reset."] = ""
-- L["Right-click to open menu"] = ""

-- skada menu
-- L["Skada Menu"] = ""
-- L["Delete segment"] = ""
-- L["Keep segment"] = ""
-- L["Toggle window"] = ""
-- L["Start new segment"] = ""

-- window buttons
-- L["Configure"] = ""
-- L["Opens the configuration window."] = ""
-- L["Resets all fight data except those marked as kept."] = ""
-- L["Segment"] = ""
-- L["Jump to a specific segment."] = ""
-- L["Mode"] = ""
-- L["Jump to a specific mode."] = ""
-- L["Report"] = ""
-- L["Opens a dialog that lets you report your data to others in various ways."] = ""
-- L["Stop"] = ""
-- L["Stops or resumes the current segment. Useful for discounting data after a wipe. Can also be set to automatically stop in the settings."] = ""

-- default segments
-- L["Total"] = ""
-- L["Current"] = "Current fight"

-- report module and window
-- L["Skada: %s for %s:"] = ""
-- L["Channel"] = ""
-- L["Self"] = ""
-- L["Party"] = ""
-- L["Whisper"] = ""
-- L["Say"] = ""
-- L["Whisper Target"] = ""
-- L["Raid"] = ""
-- L["Guild"] = ""
-- L["Officer"] = ""
-- L["Lines"] = ""
-- L["There is nothing to report."] = ""
-- L["No mode or segment selected for report."] = ""

-- ================== --
-- Bar Display Module --
-- ================== --

-- L["Bar display"] = ""
-- L["Bar display is the normal bar window used by most damage meters. It can be extensively styled."] = ""

-- ============= --
-- Threat Module --
-- ============= --
-- L["Threat"] = ""
-- L["Threat warning"] = ""
-- L["Do not warn while tanking"] = ""
-- L["Flash screen"] = ""
-- L["This will cause the screen to flash as a threat warning."] = ""
-- L["Shake screen"] = ""
-- L["This will cause the screen to shake as a threat warning."] = ""
-- L["Play sound"] = ""
-- L["This will play a sound as a threat warning."] = ""
-- L["Threat sound"] = ""
-- L["The sound that will be played when your threat percentage reaches a certain point."] = ""
-- L["Threat threshold"] = ""
-- L["When your threat reaches this level, relative to tank, warnings are shown."] = ""
-- L["Show raw threat"] = ""
-- L["Shows raw threat percentage relative to tank instead of modified for range."] = ""
-- L["Use focus target"] = ""
-- L["Shows threat on focus target, or focus target's target, when available."] = ""
-- L["TPS"] = ""
-- L["Threat: Personal Threat"] = ""

-- ======================== --
-- Absorbs & Healing Module --
-- ======================== --
-- L["Healing"] = ""
-- L["Healed player list"] = ""
-- L["Healing spell list"] = ""
-- L["%s's healing"] = ""
-- L["%s's healing spells"] = ""
-- L["%s's healed players"] = ""
-- L["HPS"] = ""

-- L["Total healing"] = ""

-- L["Overhealing"] = ""
-- L["Overheal"] = ""
-- L["Overhealed player list"] = ""
-- L["Overhealing spell list"] = ""
-- L["%s's overhealing spells"] = ""
-- L["%s's overhealed players"] = ""

-- L["Healing and Overhealing"] = ""
-- L["Healing and overhealing spells"] = ""
-- L["Healed and overhealed players"] = ""
-- L["%s's healing and overhealing spells"] = ""
-- L["%s's healed and overhealed players"] = ""

-- L["Absorbs"] = ""
-- L["Absorbed player list"] = ""
-- L["Absorb spell list"] = ""
-- L["%s's absorbed players"] = ""
-- L["%s's absorb spells"] = ""

-- L["Absorbs and healing"] = ""
-- L["Absorbs and healing spell list"] = ""
-- L["Absorbed and healed players"] = ""
-- L["%s's absorb and healing spells"] = ""
-- L["%s's absorbed and healed players"] = ""

-- ============ --
-- Auras Module --
-- ============ --

-- L["Uptime"] = ""

-- L["Buffs and Debuffs"] = ""
-- L["Buffs"] = ""
-- L["Buff spell list"] = ""
-- L["%s's buffs"] = ""

-- L["Debuffs"] = ""
-- L["Debuff spell list"] = ""
-- L["Debuff target list"] = ""
-- L["%s's debuffs"] = ""
-- L["%s's debuff targets"] = ""
-- L["%s's <%s> targets"] = ""

-- L["Sunder Counter"] = ""
-- L["Sunder target list"] = ""

-- ================= --
-- CC Tracker Module --
-- ================= --

-- L["CC Tracker"] = ""

-- CC Done:
-- L["CC Done"] = ""
-- L["CC Done spells"] = ""
-- L["CC Done spell targets"] = ""
-- L["CC Done targets"] = ""
-- L["CC Done target spells"] = ""
-- L["%s's CC Done <%s> targets"] = ""
-- L["%s's CC Done <%s> spells"] = ""
-- L["%s's CC Done spells"] = ""
-- L["%s's CC Done targets"] = ""

-- CC Taken
-- L["CC Taken"] = ""
-- L["CC Taken spells"] = ""
-- L["CC Taken spell sources"] = ""
-- L["CC Taken sources"] = ""
-- L["CC Taken source spells"] = ""
-- L["%s's CC Taken <%s> sources"] = ""
-- L["%s's CC Taken <%s> spells"] = ""
-- L["%s's CC Taken spells"] = ""
-- L["%s's CC Taken sources"] = ""

-- L["CC Breaks"] = ""
-- L["CC Breakers"] = ""
-- L["CC Break spells"] = ""
-- L["CC Break spell targets"] = ""
-- L["CC Break targets"] = ""
-- L["CC Break target spells"] = ""
-- L["%s's CC Break <%s> spells"] = ""
-- L["%s's CC Break <%s> targets"] = ""
-- L["%s's CC Break spells"] = ""
-- L["%s's CC Break targets"] = ""

-- options
-- L["CC"] = ""
-- L["Announce CC breaking to party"] = ""
-- L["Ignore Main Tanks"] = ""
-- L["%s on %s removed by %s"] = ""
-- L["%s on %s removed by %s's %s"] = ""

-- ============= --
-- Damage Module --
-- ============= --

-- damage done module
-- L["Damage"] = ""
-- L["Damage target list"] = ""
-- L["Damage spell list"] = ""
-- L["Damage spell details"] = ""
-- L["Damage spell targets"] = ""
-- L["Damage done"] = ""
-- L["%s's damage"] = ""
-- L["%s's <%s> damage"] = ""

-- L["Useful damage"] = ""

-- L["Damage done by spell"] = ""
-- L["%s's sources"] = ""

-- L["DPS"] = ""
-- L["Damage: Personal DPS"] = ""

-- L["RDPS"] = ""
-- L["Damage: Raid DPS"] = ""

-- damage taken module
-- L["Damage taken"] = ""
-- L["Damage taken by %s"] = ""
-- L["<%s> damage on %s"] = ""

-- L["Damage source list"] = ""
-- L["Damage spell sources"] = ""
-- L["Damage taken by spell"] = ""
-- L["%s's targets"] = ""
-- L["DTPS"] = ""

-- enemy damage done module
-- L["Enemy damage done"] = ""
-- L["Damage done per player"] = ""
-- L["Damage from %s"] = ""
-- L["%s's damage on %s"] = ""

-- enemy damage taken module
-- L["Enemy damage taken"] = ""
-- L["Damage taken per player"] = ""
-- L["Damage on %s"] = ""
-- L["%s's damage sources"] = ""

-- avoidance and mitigation module
-- L["Avoidance & Mitigation"] = ""
-- L["Damage breakdown"] = ""
-- L["%s's damage breakdown"] = ""

-- friendly fire module
-- L["Friendly Fire"] = ""

-- L["Critical"] = ""
-- L["Glancing"] = ""
-- L["Crushing"] = ""

-- useful damage targets
-- L["Useful targets"] = ""
-- L["Oozes"] = ""
-- L["Princes overkilling"] = ""
-- L["Adds"] = ""
-- L["Halion and Inferno"] = ""
-- L["Valkyrs overkilling"] = ""

-- missing bosses entries
-- L["Cult Adherent"] = ""
-- L["Cult Fanatic"] = ""
-- L["Darnavan"] = ""
-- L["Deformed Fanatic"] = ""
-- L["Empowered Adherent"] = ""
-- L["Gas Cloud"] = ""
-- L["Living Inferno"] = ""
-- L["Reanimated Adherent"] = ""
-- L["Reanimated Fanatic"] = ""
-- L["Volatile Ooze"] = ""
-- L["Wicked Spirit"] = ""

-- L["Kor'kron Sergeant"] = ""
-- L["Kor'kron Axethrower"] = ""
-- L["Kor'kron Rocketeer"] = ""
-- L["Kor'kron Battle-Mage"] = ""
-- L["Skybreaker Sergeant"] = ""
-- L["Skybreaker Rifleman"] = ""
-- L["Skybreaker Mortar Soldier"] = ""
-- L["Skybreaker Sorcerer"] = ""
-- L["Stinky"] = ""
-- L["Precious"] = ""
-- L["Dream Cloud"] = ""
-- L["Risen Archmage"] = ""
-- L["Blazing Skeleton"] = ""
-- L["Blistering Zombie"] = ""
-- L["Gluttonous Abomination"] = ""

-- ============= --
-- Deaths Module --
-- ============= --
-- L["Deaths"] = ""
-- L["%s's death"] = ""
-- L["%s's deaths"] = ""
-- L["Death log"] = ""
-- L["%s's death log"] = ""
-- L["Player's deaths"] = ""
-- L["%s dies"] = ""
-- L["Spell details"] = ""
-- L["Spell"] = ""
-- L["Amount"] = ""
-- L["Source"] = ""
-- L["Health"] = ""
-- L["Change"] = ""

-- activity module
-- L["Activity"] = ""
-- L["Activity per target"] = ""

-- ==================== --
-- dispels module lines --
-- ==================== --

-- L["Dispels"] = ""

-- L["Dispel spell list"] = ""
-- L["Dispelled spell list"] = ""
-- L["Dispelled target list"] = ""

-- L["%s's dispel spells"] = ""
-- L["%s's dispelled spells"] = ""
-- L["%s's dispelled targets"] = ""

-- ==================== --
-- failbot module lines --
-- ==================== --

-- L["Fails"] = ""
-- L["%s's fails"] = ""
-- L["Player's failed events"] = ""
-- L["Event's failed players"] = ""

-- ======================== --
-- improvement module lines --
-- ======================== --

-- L["Improvement"] = ""
-- L["Improvement modes"] = ""
-- L["Improvement comparison"] = ""
-- L["Do you want to reset your improvement data?"] = ""
-- L["%s's overall data"] = ""

-- ======================= --
-- interrupts module lines --
-- ======================= --

-- L["Interrupts"] = ""
-- L["Interrupt spells"] = ""
-- L["Interrupted spells"] = ""
-- L["Interrupted targets"] = ""
-- L["%s's interrupt spells"] = ""
-- L["%s's interrupted spells"] = ""
-- L["%s's interrupted targets"] = ""

-- =================== --
-- Power gained module --
-- =================== --

-- L["Power"] = ""
-- L["Power gained"] = ""
-- L["%s's gained %s"] = ""
-- L["Power gained: Mana"] = ""
-- L["Mana gained spell list"] = ""
-- L["Power gained: Rage"] = ""
-- L["Rage gained spell list"] = ""
-- L["Power gained: Energy"] = ""
-- L["Energy gained spell list"] = ""
-- L["Power gained: Runic Power"] = ""
-- L["Runic Power gained spell list"] = ""

-- ==================== --
-- Parry module lines --
-- ==================== --

-- L["Parry"] = ""
-- L["Parry target list"] = ""
-- L["%s's parry targets"] = ""

-- ==================== --
-- Potions module lines --
-- ==================== --

-- L["Potions"] = ""
-- L["Potions list"] = ""
-- L["Players list"] = ""
-- L["%s's used potions"] = ""

-- ====================== --
-- resurrect module lines --
-- ====================== --

-- L["Resurrects"] = ""
-- L["Resurrect spell list"] = ""
-- L["Resurrect spell target list"] = ""
-- L["Resurrect target list"] = ""
-- L["Resurrect target spell list"] = ""

-- L["%s's resurrect spells"] = ""
-- L["%s's resurrect targets"] = ""
-- L["%s's received resurrects"] = ""
-- L["%s's resurrect <%s> targets"] = ""

-- ==================== --
-- spamage module lines --
-- ==================== --

-- L["Spamage"] = ""
-- L["Suppresses chat messages from damage meters and provides single chat-link damage statistics in a popup."] = ""
-- L["Capture Delay"] = ""
-- L["How many seconds the addon waits after \"Skada: *\" lines before it assumes spam burst is over. 1 seems to work in most cases"] = ""
-- L["Filter Custom Channels"] = ""
-- L["Selects the action to perform when encountering damage meter data in custom channels"] = ""
L["Filter Guild"] = "길드 필터"
L["Selects the action to perform when encountering damage meter data in guild chat"] = "길드 대화로 미터기의 데이터를 보낼 방식을 선택합니다."
L["Filter Officer"] = "길드 관리자 필터"
L["Selects the action to perform when encountering damage meter data in officer chat"] = "길드 관리자 대화로 미터기의 데이터를 보낼 방식을 선택합니다."
L["Filter Party"] = "파티 필터"
L["Selects the action to perform when encountering damage meter data in party chat"] = "파티 대화로 미터기의 데이터를 보낼 방식을 선택합니다."
L["Filter Raid"] = "공격대 필터"
L["Selects the action to perform when encountering damage meter data in raid chat"] = "공격대 대화로 미터기의 데이터를 보낼 방식을 선택합니다."
L["Filter Say"] = "일반 필터"
L["Selects the action to perform when encountering damage meter data in say chat"] = "일반 대화로 미터기의 데이터를 보낼 방식을 선택합니다."
L["Filter Whisper"] = "귓속말 필터"
L["Selects the action to perform when encountering damage meter whisper"] = "귓속말로 미터기의 데이터를 보낼 방식을 선택합니다."
L["Filter Yell"] = "외침 필터"
L["Selects the action to perform when encountering damage meter data in yell chat"] = "외침으로 미터기의 데이터를 보낼 방식을 선택합니다."
L["Do Nothing"] = "링크 미사용"
L["Compress"] = "요약 링크"
L["Suppress"] = "보고하지 않음"
L["Reported by: %s"] = "%s의 보고"