local L = LibStub("AceLocale-3.0"):NewLocale("Skada", "zhCN", false)

if not L then return end

L["Disable"] = "禁用"
L["Profiles"] = "配置文件"
L["Hint: Left-Click to toggle Skada window."] = "提示: 左键点击打开窗口"
L["Shift + Left-Click to reset."] = "Shift+左键点击重置"
L["Right-click to open menu"] = "右键点击打开菜单"
L["Options"] = "选项"
L["Appearance"] = "外观"
L["A damage meter."] = "伤害统计"
L["Skada summary"] = "Skada总揽"


L["opens the configuration window"] = "打开配置窗口"
L["resets all data"] = "重置所有数据"

L["Current"] = "当前"
L["Total"] = "总体"


L["All data has been reset."] = "所有数据已被重置"
L["Skada: Modes"] = "Skada: 模式"
L["Skada: Fights"] = "Skada: 战斗"

-- Options
L["Bar font"] = "计量条字体"
L["The font used by all bars."] = "所有条的字体"
L["Bar font size"] = "计量条字体大小"
L["The font size of all bars."] = "所有条的字体大小"
L["Bar texture"] = "计量条材质"
L["The texture used by all bars."] = "所有条的材质"
L["Bar spacing"] = "计量条间距"
L["Distance between bars."] = "条与条之间的距离"
L["Bar height"] = "计量条高度"
L["The height of the bars."] = "条的高度"
L["Bar width"] = "计量条宽度"
L["The width of the bars."] = "条的宽度"
L["Bar color"] = "计量条颜色"
L["Choose the default color of the bars."] = "条的颜色"
L["Max bars"] = "最大条数量"
L["The maximum number of bars shown."] = "显示条的最大数量"
L["Bar orientation"] = "计量条方向"
L["The direction the bars are drawn in."] = "条的显示方向"
L["Left to right"] = "从左到右"
L["Right to left"] = "从右到左"
L["Combat mode"] = "战斗模式"
L["Automatically switch to set 'Current' and this mode when entering combat."] = "当进入战斗后自动切换到设置'当前'和此模块."
L["None"] = "无"
L["Return after combat"] = "战斗后返回"
L["Return to the previous set and mode after combat ends."] = "当战斗结束后返回原先的设置和模式"
L["Show minimap button"] = "显示小地图按钮"
L["Toggles showing the minimap button."] = "显示/隐藏小地图按钮"

L["reports the active mode"] = "报告当前的模式"
L["Skada report on %s for %s, %s to %s:"] = "Skada报告%s的%s, %s到%s:" -- Needs review
L["Only keep boss fighs"] = "只保留Boss战"
L["Boss fights will be kept with this on, and non-boss fights are discarded."] = "只保留Boss战的纪录, 非Boss战的纪录将被丢弃."
L["Show raw threat"] = "显示默认仇恨值"
L["Shows raw threat percentage relative to tank instead of modified for range."] = "显示相对于坦克的仇恨值百分比."

L["Lock window"] = "锁定窗口"
L["Locks the bar window in place."] = "在当前位置锁定窗口"
L["Reverse bar growth"] = "反转条增长方向"
L["Bars will grow up instead of down."] = "计量条向上增长"
L["Number format"] = "数字格式"
L["Controls the way large numbers are displayed."] = "控制大量数字显示的方式."
L["Reset on entering instance"] = "进入副本时重置"
L["Controls if data is reset when you enter an instance."] = "控制当你进入一个副本时重置数据."
L["Reset on joining a group"] = "加入一个队伍时重置"
L["Controls if data is reset when you join a group."] = "控制当你进入一个队伍时重置数据."
L["Reset on leaving a group"] = "离开一个队伍时重置"
L["Controls if data is reset when you leave a group."] = "控制当你离开一个副本时重置数据."
L["General options"] = "一般选项"
L["Mode switching"] = "模式切换"
L["Data resets"] = "数据重置"
L["Bars"] = "计量条"

L["Yes"] = "是"
L["No"] = "否"
L["Ask"] = "询问"
L["Condensed"] = "概要"
L["Detailed"] = "详情"

L["Hide when solo"] = "当SOLO时隐藏"
L["Hides Skada's window when not in a party or raid."] = "当不在小队或团队时隐藏Skada窗口."

L["Title bar"] = "标题栏"
L["Background texture"] = "背景材质"
L["The texture used as the background of the title."] = "标题的背景材质"
L["Border texture"] = "边框材质"
L["The texture used for the border of the title."] = "标题的边框材质"
L["Border thickness"] = "边框粗细"
L["The thickness of the borders."] = "边框的粗细"
L["Background color"] = "背景颜色"
L["The background color of the title."] = "标题的背景颜色"

L["'s "] = "的"
L["Do you want to reset Skada?"] = "你是否想重置Skada?"
L["The margin between the outer edge and the background texture."] = "外边缘和背景材质之间的空白."
L["Margin"] = "边距"
L["Window height"] = "窗体高度"
L["The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."] = "窗体的高度.如果是0则窗体将根据存在多少计量条来动态改变."
L["Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."] = "增加一个计量条的背景框体.背景框体的高度决定了计量条的显示数量,并将覆盖最大计量条数量的设置选项."
L["Enable"] = "启用"
L["Background"] = "背景"
L["The texture used as the background."] = "用作背景的材质."
L["The texture used for the borders."] = "用作边框的材质."
L["The color of the background."] = "背景的颜色."
L["Data feed"] = "数据聚合"
L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."] = "选择需要显示在DataBroker上的数据聚合.需要一个LDB显示插件,如Titan Panel泰坦信息条."
L["RDPS"] = "团队DPS"
L["Damage: Personal DPS"] = "伤害:个人DPS"
L["Damage: Raid DPS"] = "伤害:团队DPS"
L["Threat: Personal Threat"] = "仇恨: 个人仇恨"

L["Data segments to keep"] = "保留的分段数据"
L["The number of fight segments to keep. Persistent segments are not included in this."] = "需要保留的战斗数据分段数量.不包括持续的分段."

L["Alternate color"] = "交替颜色"
L["Choose the alternate color of the bars."] = "选择计量条的交替颜色."

L["Threat warning"] = "仇恨警报"
L["Flash screen"] = "闪光屏幕"
L["This will cause the screen to flash as a threat warning."] = "闪光屏幕来仇恨警报."
L["Shake screen"] = "震动屏幕"
L["This will cause the screen to shake as a threat warning."] = "震动屏幕来仇恨警报."
L["Play sound"] = "播放音效"
L["This will play a sound as a threat warning."] = "仇恨警报来播放音效."
L["Threat sound"] = "仇恨音效"
L["The sound that will be played when your threat percentage reaches a certain point."] = "当你的仇恨百分比到达一个固定点时播放音效."
L["Threat threshold"] = "仇恨阀值"
L["When your threat reaches this level, relative to tank, warnings are shown."] = "当你的仇恨值相对于坦克到达这个阀值时显示警报."

L["Enables the title bar."] = "启用标题栏."

L["Total healing"] = "总体治疗"

L["Skada Menu"] = "Skada菜单"
L["Switch to mode"] = "切换到模式"
L["Report"] = "报告"
L["Toggle window"] = "开启/关闭窗口"
L["Configure"] = "配置"
L["Delete segment"] = "删除分段数据"
L["Keep segment"] = "保留分段数据"
L["Mode"] = "模式"
L["Lines"] = "行"
L["Channel"] = "频道"
L["Send report"] = "发送报告"
L["No mode selected for report."] = "没有选择报告的模式."
L["Say"] = "说"
L["Raid"] = "团队"
L["Party"] = "小队"
L["Guild"] = "公会"
L["Officer"] = "官员"
L["Self"] = "自身"

L["'s Healing"] = "的治疗"

L["Delete window"] = "删除窗口"
L["Deletes the chosen window."] = "删除已选择的窗口."
L["Choose the window to be deleted."] = "选择要删除的窗口."
L["Enter the name for the new window."] = "输入新窗口的名字."
L["Create window"] = "创建窗口"
L["Windows"] = "窗口"

L["Switch to segment"] = "切换到分段"
L["Segment"] = "分段"

L["Whisper"] = "密语"

L["No mode or segment selected for report."] = "没有选择报告的模式或者片段."
L["Name of recipient"] = "接收者的名字"

L["Resist"] = "抵抗"
L["Reflect"] = "反射"
L["Parry"] = "招架"
L["Immune"] = "免疫"
L["Evade"] = "闪避"
L["Dodge"] = "躲闪"
L["Deflect"] = "偏斜"
L["Block"] = "格档"
L["Absorb"] = "吸收"

L["Last fight"] = "最后一场战斗"
L["Disable while hidden"] = "当隐藏时禁用"
L["Skada will not collect any data when automatically hidden."] = "当自动隐藏时Skada将不收集任何数据."

L["Rename window"] = "重命名窗口"
L["Enter the name for the window."] = "输入窗口的名字."

L["Bar display"] = "计量条显示"
L["Display system"] = "显示系统"
L["Choose the system to be used for displaying data in this window."] = "选择在窗口中需要显示数据的系统."

L["Hides HPS from the Healing modes."] = "在治疗模式中隐藏HPS（每秒治疗）."
L["Do not show HPS"] = "不显示HPS"

L["Do not show DPS"] = "不显示DPS"
L["Hides DPS from the Damage mode."] = "在伤害模式中隐藏DPS（每秒伤害）."

L["Class color bars"] = "按职业着色计量条"
L["When possible, bars will be colored according to player class."] = "计量条颜色按玩家颜色显示."
L["Class color text"] = "按职业着色文本"
L["When possible, bar text will be colored according to player class."] = "计量条文本颜色按玩家颜色显示."

L["Reset"] = "重置"
L["Show tooltips"] = "显示提示信息"

L["Shows tooltips with extra information in some modes."] = "在一些模块显示额外的提示信息."


L["Minimum hit:"] = "最小伤害:"
L["Maximum hit:"] = "最大伤害:"
L["Average hit:"] = "平均伤害:"
L["Absorbs"] = "吸收"
L["'s Absorbs"] = "的吸收"

L["Do not show TPS"] = "不显示TPS"
L["Do not warn while tanking"] = "当坦克时不警报"

L["Hide in PvP"] = "在PvP中隐藏"
L["Hides Skada's window when in Battlegrounds/Arenas."] = "当在战场/竞技场中隐藏Skada'窗口."

L["Healed players"] = "被治疗的玩家"
L["Healed by"] = "被治疗"
L["Absorb details"] = "吸收详情"
L["Spell details"] = "法术详情"
L["Healing spell list"] = "治疗法术列表"
L["Healing spell details"] = "治疗法术详情"
L["Debuff spell list"] = "Debuff法术列表"







L["Click for"] = "点击后为"
L["Shift-Click for"] = "Shift+点击后为"
L["Control-Click for"] = "Ctrl+点击后为"
L["Default"] = "默认"
L["Top right"] = "顶部右方"
L["Top left"] = "顶部左方"



L["Position of the tooltips."] = "提示信息的位置."
L["Tooltip position"] = "提示信息位置"


L["Shows a button for opening the menu in the window title bar."] = "在窗口标题条显示打开菜单的按钮。"
L["Show menu button"] = "显示菜单按钮"



L["Attack"] = "攻击"
L["Damage"] = "伤害"
L["Hit"] = "命中"
L["Critical"] = "暴击"
L["Missed"] = "未命中"
L["Resisted"] = "抵抗"
L["Blocked"] = "格档"
L["Glancing"] = "偏斜"
L["Crushing"] = "碾压"
L["Absorbed"] = "吸收"
L["HPS"] = "每秒治疗"
L["Healing"] = "治疗"

L["Overhealing"] = "过量治疗"
L["Threat"] = "仇恨值"

L["Announce CC breaking to party"] = "通报控场技能被打破到小队"
L["Ignore Main Tanks"] = "忽略主坦克"
L["%s on %s removed by %s's %s"] = "%s 在 %s 被 %s 的 %s 移除"
L["%s on %s removed by %s"] = "%s 在 %s 被 %s 移除"

L["Start new segment"] = "开始新的分段纪录"
L["Columns"] = "列"
L["Overheal"] = "过量治疗"
L["Percent"] = "百分比"
L["TPS"] = "每秒仇恨"

L["%s dies"] = "%s 次死亡"
L["Change"] = "修改"
L["Health"] = "生命"

L["Hide in combat"] = "战斗中隐藏"
L["Hides Skada's window when in combat."] = "当在战斗中隐藏 Skada 窗口."

L["Tooltips"] = "提示信息"
L["Informative tooltips"] = "信息提示"
L["Shows subview summaries in the tooltips."] = "在提示信息中显示即时资讯。"
L["Subview rows"] = "资讯行数"
L["The number of rows from each subview to show when using informative tooltips."] = "当使用提示信息资讯的时候要显示的资讯行数。"

L["Damage done"] = "造成伤害"
L["Active Time"] = "活跃时间"
L["Segment Time"] = "分段时间"
L["Absorbs and healing"] = "吸收和治疗"







L["Use focus target"] = "使用焦点目标"
L["Shows threat on focus target, or focus target's target, when available."] = "当可用时显示对于焦点目标或焦点目标的目标的仇恨."












-- Scroll








-- =================== --
-- damage module lines --
-- =================== --

L["DPS"] = "每秒伤害"


L["Damage on"] = "伤害在"




L["Damage Taken"] = "受到伤害"
L["Damage from"] = "伤害来自"



L["Enemy damage done"] = "敌对伤害"
L["Enemy damage taken"] = "敌对受到伤害"

L["%s's Damage"] = "%s 的伤害"

















L["Damage done per player"] = "每位玩家的伤害输出"
L["Damage taken per player"] = "每位玩家承受的伤害"

-- ================== --
-- auras module lines --
-- ================== --














-- ======================= --
-- interrupts module lines --
-- ======================= --

L["Interrupts"] = "打断"




-- ==================== --
-- failbot module lines --
-- ==================== --

L["Fails"] = "失误"
L["%s's Fails"] = "%s 的失误"



-- ======================== --
-- improvement module lines --
-- ======================== --








-- =================== --
-- deaths module lines --
-- =================== --

L["Deaths"] = "死亡"
L["%s's Death"] = "%s 的死亡"

L["Death log"] = "死亡纪录"






-- ==================== --
-- dispels module lines --
-- ==================== --

L["Dispels"] = "驱散"









-- ======================= --
-- cc tracker module lines --
-- ======================= --

L["CC"] = "控场技能"


L["CC Breakers"] = "控场技能打破者"







-- CC Done:








-- CC Taken








-- ====================== --
-- resurrect module lines --
-- ====================== --













-- ====================== --
-- Avoidance & Mitigation --
-- ====================== --




















