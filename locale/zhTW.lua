-------------------------------------------------------------------------------
--- Traditional Chinese localization --by andy52005
-------------------------------------------------------------------------------
local L = LibStub("AceLocale-3.0"):NewLocale("Skada", "zhTW", false)

if not L then return end

L["Disable"] = "停用"
L["Profiles"] = "設定檔"
L["Hint: Left-Click to toggle Skada window."] = "提示:左鍵點擊切換Skada視窗。"
L["Shift + Left-Click to reset."] = "Shift+左鍵點擊進行重置。"
L["Right-click to open menu"] = "右鍵點擊開啟選單"
L["Options"] = "選項"
L["Appearance"] = "外觀"
L["A damage meter."] = "一個傷害統計。"
L["Skada summary"] = "Skada一覽"


L["opens the configuration window"] = "開啟設定視窗"
L["resets all data"] = "重置所有資料"

L["Current"] = "當前的"
L["Total"] = "總體的"


L["All data has been reset."] = "所有資料已重置。"
L["Skada: Modes"] = "Skada:模組"
L["Skada: Fights"] = "Skada:作戰"

-- Options
L["Bar font"] = "計量條的字型"
L["The font used by all bars."] = "所有計量條使用這個字型。"
L["Bar font size"] = "計量條的字型大小"
L["The font size of all bars."] = "所有計量條的字型大小。"
L["Bar texture"] = "計量條的材質"
L["The texture used by all bars."] = "所有計量條使用這個材質。"
L["Bar spacing"] = "計量條的間距"
L["Distance between bars."] = "計量條之間的距離。"
L["Bar height"] = "計量條的高度"
L["The height of the bars."] = "計量條的高度。"
L["Bar width"] = "計量條的寬度"
L["The width of the bars."] = "計量條的寬度。"
L["Bar color"] = "計量條的顏色"
L["Choose the default color of the bars."] = "變更計量條預設的顏色。"
L["Max bars"] = "最多計量條數量"
L["The maximum number of bars shown."] = "顯示最多數量的計量條。"
L["Bar orientation"] = "計量條的方向"
L["The direction the bars are drawn in."] = "計量條的增長方向。"
L["Left to right"] = "由左到右"
L["Right to left"] = "由右到左"
L["Combat mode"] = "戰鬥模組"
L["Automatically switch to set 'Current' and this mode when entering combat."] = "當進入戰鬥時，自動切換'當前的'以及選擇的模組。"
L["None"] = "無"
L["Return after combat"] = "戰鬥後返回"
L["Return to the previous set and mode after combat ends."] = "戰鬥結束後返回原先的設定和模組。"
L["Show minimap button"] = "顯示小地圖按鈕"
L["Toggles showing the minimap button."] = "切換顯示小地圖按鈕。"

L["reports the active mode"] = "報告目前的模組"
L["Skada report on %s for %s, %s to %s:"] = "Skada:%s來自%s，%s - %s:"
L["Only keep boss fighs"] = "只保留首領戰"
L["Boss fights will be kept with this on, and non-boss fights are discarded."] = "保留與首領之間的戰鬥紀錄，與非首領的戰鬥紀錄將會被消除。"
L["Show raw threat"] = "顯示原始威脅值"
L["Shows raw threat percentage relative to tank instead of modified for range."] = "顯示與坦克之間的原始威脅值百分比。"

L["Lock window"] = "鎖定視窗"
L["Locks the bar window in place."] = "鎖定計量條視窗位置。"
L["Reverse bar growth"] = "計量條反向增長"
L["Bars will grow up instead of down."] = "計量條將向上增長。"
L["Number format"] = "數字格式"
L["Controls the way large numbers are displayed."] = "大量數字的顯示方式。"
L["Reset on entering instance"] = "進入副本時重置"
L["Controls if data is reset when you enter an instance."] = "當你進入副本時資料是否要重置。"
L["Reset on joining a group"] = "加入團體時重置"
L["Controls if data is reset when you join a group."] = "當你加入團體時資料是否要重置。"
L["Reset on leaving a group"] = "離開團體時重置"
L["Controls if data is reset when you leave a group."] = "當你離開團體時控制資料是否要重置。"
L["General options"] = "一般選項"
L["Mode switching"] = "轉換模組"
L["Data resets"] = "資料重置"
L["Bars"] = "計量條"

L["Yes"] = "是"
L["No"] = "否"
L["Ask"] = "詢問"
L["Condensed"] = "簡易的"
L["Detailed"] = "詳細的"

L["Hide when solo"] = "單練時隱藏"
L["Hides Skada's window when not in a party or raid."] = "當不在隊伍或團隊時隱藏Skada的視窗。"

L["Title bar"] = "標題條"
L["Background texture"] = "背景的材質"
L["The texture used as the background of the title."] = "使用於標題的背景材質。"
L["Border texture"] = "邊框的材質"
L["The texture used for the border of the title."] = "使用於標題的邊框材質。"
L["Border thickness"] = "邊框的厚度"
L["The thickness of the borders."] = "邊框的厚度。"
L["Background color"] = "背景的顏色"
L["The background color of the title."] = "標題的背景顏色。"

L["'s "] = "的"
L["Do you want to reset Skada?"] = "你要重置Skada嗎？"
L["The margin between the outer edge and the background texture."] = "外框和背景材質之間的邊距。"
L["Margin"] = "邊距"
L["Window height"] = "視窗的高度"
L["The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."] = "視窗的高度。若設定為0則依照計量條的多寡自動調整。"
L["Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."] = "新增一個計量條的背景框架。背景框架的高度將決定顯示多少個計量條。這會忽略計量條的最多數量的設定。"
L["Enable"] = "啟用"
L["Background"] = "背景"
L["The texture used as the background."] = "使用於背景的材質。"
L["The texture used for the borders."] = "使用於邊框的材質。"
L["The color of the background."] = "背景的顏色。"
L["Data feed"] = "資料來源"
L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."] = "選擇需要顯示在DataBroker上的資料來源。需要一個LDB的顯示插件，例如Titan Panel。"
L["RDPS"] = "團隊DPS"
L["Damage: Personal DPS"] = "傷害:個人的DPS"
L["Damage: Raid DPS"] = "傷害:團隊的DPS"
L["Threat: Personal Threat"] = "威脅值:個人的威脅值"

L["Data segments to keep"] = "保留分段的資料"
L["The number of fight segments to keep. Persistent segments are not included in this."] = "保留多少戰鬥資料分段的數量，不包含連續的分段。"

L["Alternate color"] = "相間的顏色"
L["Choose the alternate color of the bars."] = "選擇計量條相間的顏色。"

L["Threat warning"] = "威脅值的警告"
L["Flash screen"] = "螢幕閃爍"
L["This will cause the screen to flash as a threat warning."] = "這將顯示螢幕閃爍的威脅值警告。"
L["Shake screen"] = "螢幕震動"
L["This will cause the screen to shake as a threat warning."] = "這將顯示螢幕振動的威脅值警告。"
L["Play sound"] = "播放音效"
L["This will play a sound as a threat warning."] = "這將使用播放音效的威脅值警告。"
L["Threat sound"] = "威脅值的音效"
L["The sound that will be played when your threat percentage reaches a certain point."] = "當你的威脅值達到一定的百分比時播放音效。"
L["Threat threshold"] = "威脅值的條件"
L["When your threat reaches this level, relative to tank, warnings are shown."] = "當你的威脅值與坦克相同時顯示警告。"

L["Enables the title bar."] = "啟用標題條。"

L["Total healing"] = "總體治療"

L["Skada Menu"] = "Skada 選單"
L["Switch to mode"] = "模組切換到"
L["Report"] = "報告"
L["Toggle window"] = "切換視窗"
L["Configure"] = "設定"
L["Delete segment"] = "刪除分段資料"
L["Keep segment"] = "保留分段資料"
L["Mode"] = "模組"
L["Lines"] = "行數"
L["Channel"] = "頻道"
L["Send report"] = "發送報告"
L["No mode selected for report."] = "沒有選擇可報告的模組。"
L["Say"] = "說"
L["Raid"] = "團隊"
L["Party"] = "隊伍"
L["Guild"] = "公會"
L["Officer"] = "幹部"
L["Self"] = "自己"

L["'s Healing"] = "的治療"

L["Delete window"] = "刪除視窗"
L["Deletes the chosen window."] = "刪除已選擇的視窗。"
L["Choose the window to be deleted."] = "選擇的視窗已刪除。"
L["Enter the name for the new window."] = "為新視窗輸入名稱。"
L["Create window"] = "建立視窗"
L["Windows"] = "視窗"

L["Switch to segment"] = "轉換到分段資料"
L["Segment"] = "分段"

L["Whisper"] = "悄悄話"

L["No mode or segment selected for report."] = "沒有選擇可報告的模組或分段資料。"
L["Name of recipient"] = "接收者的名稱"

L["Resist"] = "抵抗"
L["Reflect"] = "反射"
L["Parry"] = "招架"
L["Immune"] = "免疫"
L["Evade"] = "閃避"
L["Dodge"] = "閃躲"
L["Deflect"] = "偏斜"
L["Block"] = "格擋"
L["Absorb"] = "吸收"

L["Last fight"] = "最後的戰鬥"
L["Disable while hidden"] = "停用時隱藏"
L["Skada will not collect any data when automatically hidden."] = "當自動隱藏時，Skada將不會紀錄任何資料。"

L["Rename window"] = "重新命名視窗"
L["Enter the name for the window."] = "輸入視窗名稱。"

L["Bar display"] = "顯示計量條"
L["Display system"] = "顯示方式"
L["Choose the system to be used for displaying data in this window."] = "在視窗中選擇顯示資料的使用方式。"

L["Hides HPS from the Healing modes."] = "在治療模組中不顯示每秒治療。"
L["Do not show HPS"] = "不顯示每秒治療"

L["Do not show DPS"] = "不顯示每秒傷害"
L["Hides DPS from the Damage mode."] = "在傷害模組中不顯示每秒傷害。"

L["Class color bars"] = "計量條的職業顏色"
L["When possible, bars will be colored according to player class."] = "依照玩家職業來調整計量條的顏色。"
L["Class color text"] = "文字的職業顏色"
L["When possible, bar text will be colored according to player class."] = "依照玩家職業來調整計量條文字的顏色。"

L["Reset"] = "重置"
L["Show tooltips"] = "顯示提示訊息"

L["Shows tooltips with extra information in some modes."] = "在一些模組中顯示提示訊息以及額外的訊息。"


L["Minimum hit:"] = "最小值:"
L["Maximum hit:"] = "最大值:"
L["Average hit:"] = "平均值:"
L["Absorbs"] = "吸收量"
L["'s Absorbs"] = "的吸收"

L["Do not show TPS"] = "不顯示每秒威脅值"
L["Do not warn while tanking"] = "坦克時不警告"

L["Hide in PvP"] = "在PvP中隱藏"
L["Hides Skada's window when in Battlegrounds/Arenas."] = "當處於戰場/競技場時隱藏Skada的視窗。"

L["Healed players"] = "被治療的玩家"
L["Healed by"] = "被治療"
L["Absorb details"] = "吸收細節"
L["Spell details"] = "法術細節"
L["Healing spell list"] = "治療法術列表"
L["Healing spell details"] = "治療法術細節"
L["Debuff spell list"] = "減益法術的列表"







L["Click for"] = "點擊後為"
L["Shift-Click for"] = "Shift+點擊後為"
L["Control-Click for"] = "Ctrl+點擊後為"
L["Default"] = "預設值"
L["Top right"] = "右上"
L["Top left"] = "左上"



L["Position of the tooltips."] = "提示訊息的位置。"
L["Tooltip position"] = "提示訊息的位置"


L["Shows a button for opening the menu in the window title bar."] = "在視窗標題條上顯示一個按鈕以開啟選單。"
L["Show menu button"] = "顯示選單按鈕"



L["Attack"] = "近戰攻擊"
L["Damage"] = "傷害"
L["Hit"] = "擊中"
L["Critical"] = "致命一擊"
L["Missed"] = "未擊中"
L["Resisted"] = "已抵抗"
L["Blocked"] = "已格擋"
L["Glancing"] = "偏斜"
L["Crushing"] = "碾壓"
L["Absorbed"] = "已吸收"
L["HPS"] = "每秒治療"
L["Healing"] = "治療"

L["Overhealing"] = "過量治療"
L["Threat"] = "威脅值"

L["Announce CC breaking to party"] = "控場被破除時通知到隊伍頻道中"
L["Ignore Main Tanks"] = "忽略主坦克"
L["%s on %s removed by %s's %s"] = "%s在%s被%s的%s移除了"
L["%s on %s removed by %s"] = "%s在%s被%s移除了"

L["Start new segment"] = "開始新的分段資料"
L["Columns"] = "計量條上"
L["Overheal"] = "過量治療"
L["Percent"] = "百分比"
L["TPS"] = "每秒威脅值"

L["%s dies"] = "%s已死亡"
L["Change"] = "變化"
L["Health"] = "生命力"

L["Hide in combat"] = "戰鬥中隱藏"
L["Hides Skada's window when in combat."] = "當處於戰鬥狀態時隱藏Skada的視窗。"

L["Tooltips"] = "提示訊息"
L["Informative tooltips"] = "提示訊息的資訊"
L["Shows subview summaries in the tooltips."] = "在提示訊息中顯示即時資訊。"
L["Subview rows"] = "資訊行數"
L["The number of rows from each subview to show when using informative tooltips."] = "當使用提示訊息的資訊時需要多少行數來顯示資訊。"

L["Damage done"] = "總傷害"
L["Active Time"] = "活耀時間"
L["Segment Time"] = "分段時間"
L["Absorbs and healing"] = "吸收和治療"




L["Show rank numbers"] = "顯示排名"
L["Shows numbers for relative ranks for modes where it is applicable."] = "在模組何處顯示適用的相對排名。"

L["Use focus target"] = "使用專注目標"
L["Shows threat on focus target, or focus target's target, when available."] = "當有設定時可顯示專注目標或專注目標的目標的威脅值。"

L["Show spark effect"] = "顯示觸發效果"










-- Scroll








-- =================== --
-- damage module lines --
-- =================== --

L["DPS"] = "每秒傷害"


L["Damage on"] = "傷害於"




L["Damage Taken"] = "承受傷害"
L["Damage from"] = "傷害於"



L["Enemy damage done"] = "敵方的傷害"
L["Enemy damage taken"] = "敵方的承受傷害"

L["%s's Damage"] = "%s 的傷害"











L["Damage taken by spell"] = "承受法術傷害"





L["Damage done per player"] = "每位玩家的傷害"
L["Damage taken per player"] = "每位玩家的承受傷害"

-- ================== --
-- auras module lines --
-- ================== --














-- ======================= --
-- interrupts module lines --
-- ======================= --

L["Interrupts"] = "中斷"




-- ==================== --
-- failbot module lines --
-- ==================== --

L["Fails"] = "失誤"
L["%s's Fails"] = "%s 的失誤"



-- ======================== --
-- improvement module lines --
-- ======================== --








-- =================== --
-- deaths module lines --
-- =================== --

L["Deaths"] = "死亡紀錄"
L["%s's Death"] = "%s 的死亡紀錄"

L["Death log"] = "死亡紀錄表"






-- ==================== --
-- dispels module lines --
-- ==================== --

L["Dispels"] = "驅散"









-- ======================= --
-- cc tracker module lines --
-- ======================= --

L["CC"] = "控場"


L["CC Breakers"] = "控場破除者"







-- CC Done:








-- CC Taken








-- ====================== --
-- resurrect module lines --
-- ====================== --













-- ====================== --
-- Avoidance & Mitigation --
-- ====================== --




















