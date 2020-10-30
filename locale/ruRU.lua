local L = LibStub("AceLocale-3.0"):NewLocale("Skada", "ruRU", false)

if not L then return end

L["Disable"] = "Отключить"
L["Profiles"] = "Профили"
L["Hint: Left-Click to toggle Skada window."] = "Подсказка: [Левый клик] открывает/закрывает окно Skada."
L["Shift + Left-Click to reset."] = "Shift + ЛКМ для сброса."
L["Right-click to open menu"] = "ПКМ для меню"
L["Options"] = "Опции"
L["Appearance"] = "Внешний вид"
L["A damage meter."] = "Измеритель урона."
L["Skada summary"] = "Skada: Сводка"


L["opens the configuration window"] = "открывает окно конфигурации"
L["resets all data"] = "сбрасывает все данные"

L["Current"] = "Текущий"
L["Total"] = "Всего"


L["All data has been reset."] = "Все данные были сброшены."
L["Skada: Modes"] = "Skada: Режимы"
L["Skada: Fights"] = "Skada: Бои"

-- Options
L["Bar font"] = "Шрифт на полосах"
L["The font used by all bars."] = "Шрифт всех полос."
L["Bar font size"] = "Размер шрифта на полосах"
L["The font size of all bars."] = "Размер шрифта для всех полос."
L["Bar texture"] = "Текстура полос"
L["The texture used by all bars."] = "Текстура всех полос."
L["Bar spacing"] = "Промежуток между полосами"
L["Distance between bars."] = "Расстояние между полосами"
L["Bar height"] = "Высота полос"
L["The height of the bars."] = "Высота полос."
L["Bar width"] = "Длина полос"
L["The width of the bars."] = "Длина всех полос."
L["Bar color"] = "Цвет полос"
L["Choose the default color of the bars."] = "Выберите цвет полос по умолчанию."
L["Max bars"] = "Макс полос"
L["The maximum number of bars shown."] = "Максимальное количество отображаемых полос."
L["Bar orientation"] = "Ориентация полос"
L["The direction the bars are drawn in."] = "Направление заполнения полос."
L["Left to right"] = "Слева направо"
L["Right to left"] = "Справа налево"
L["Combat mode"] = "Режим битвы"
L["Automatically switch to set 'Current' and this mode when entering combat."] = "Автоматически переключаться на 'Текущую' установку и этот режим при входе в бой."
L["None"] = "нету"
L["Return after combat"] = "Возврат после боя"
L["Return to the previous set and mode after combat ends."] = "Возврат к предыдущей установке и режиму после окончания боя."
L["Show minimap button"] = "Показывать кнопку на миникарте"
L["Toggles showing the minimap button."] = "Отобразить/скрыть кнопку у мини-карты."

L["reports the active mode"] = "Сообщить активный режим"
L["Skada report on %s for %s, %s to %s:"] = "Отчёт Skada: %s - %s, с %s до %s:"
L["Only keep boss fighs"] = "Хранить только бои с боссами"
L["Boss fights will be kept with this on, and non-boss fights are discarded."] = "При включении этой опции бои с боссами будут сохраняться, а бои с не-боссами будут игнорироваться."
L["Show raw threat"] = "Show raw threat"
L["Shows raw threat percentage relative to tank instead of modified for range."] = "Shows raw threat percentage relative to tank instead of modified for range."

L["Lock window"] = "Заблокировать окно"
L["Locks the bar window in place."] = "Зафиксировать окно"
L["Reverse bar growth"] = "Обратный рост полос"
L["Bars will grow up instead of down."] = "Полосы будут расти вверх, а не вниз."
L["Number format"] = "Формат чисел"
L["Controls the way large numbers are displayed."] = "Выбор вида отображения цифр."
L["Reset on entering instance"] = "Сбрасывать при входе в подземелье"
L["Controls if data is reset when you enter an instance."] = "Управление сбросом данных при входе в подземелье."
L["Reset on joining a group"] = "Сбрасывать при присоединении к группе"
L["Controls if data is reset when you join a group."] = "Управление сбросом данных при присоединении к группе."
L["Reset on leaving a group"] = "Сбрасывать при покидании группы"
L["Controls if data is reset when you leave a group."] = "Управление сбросом данных после выхода из группы."
L["General options"] = "Основные настройки"
L["Mode switching"] = "Смена режима"
L["Data resets"] = "Сброс данных"
L["Bars"] = "Полосы"

L["Yes"] = "Да"
L["No"] = "Нет"
L["Ask"] = "Уточнить"
L["Condensed"] = "Кратко"
L["Detailed"] = "Детально"

L["Hide when solo"] = "Скрывать когда один"
L["Hides Skada's window when not in a party or raid."] = "Скрывать окно Skada, если вы не состоите в группе или рейде."

L["Title bar"] = "Полоса заглавия"
L["Background texture"] = "Текстура фона"
L["The texture used as the background of the title."] = "Текстура, используемая для фона заглавия."
L["Border texture"] = "Текстура краёв"
L["The texture used for the border of the title."] = "Текстура, используемая для краёв заглавия."
L["Border thickness"] = "Толщина краёв"
L["The thickness of the borders."] = "Толщина краёв."
L["Background color"] = "Цвет фона"
L["The background color of the title."] = "Цвет фона заголовка"

L["'s "] = " - "
L["Do you want to reset Skada?"] = "Вы действительно хотите сбросить данные?"
L["The margin between the outer edge and the background texture."] = "Разница между наружным краем и текстурой фона."
L["Margin"] = "Граница"
L["Window height"] = "Высота окна"
L["The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."] = "Высота окна. Если значение высоты равно нулю, то она будет изменяться в соответствии с количеством существующих полос."
L["Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."] = "Добавляет фон за полосами. Высота фона регулируется количеством отображаемых полос. Это аннулирует настройки максимального количества полос."
L["Enable"] = "Включить"
L["Background"] = "Фон"
L["The texture used as the background."] = "Текстура фона."
L["The texture used for the borders."] = "Текстура краёв."
L["The color of the background."] = "Цвет фона."
L["Data feed"] = "Подача данных"
L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."] = "Выберите, какие данные выводить в DataBroker. Для этого требуется, модификация которая поддерживает отображение LDB, к примеру Titan Panel."
L["RDPS"] = "РУВС"
L["Damage: Personal DPS"] = "Урон: собственный УВС"
L["Damage: Raid DPS"] = "Урон: УВС рейда"
L["Threat: Personal Threat"] = "Угроза: своя угроза"

L["Data segments to keep"] = "Сегменты для хранения"
L["The number of fight segments to keep. Persistent segments are not included in this."] = "Хранимое число сегментов боёв. Длительные сегменты не входят в это."

L["Alternate color"] = "Альтернативный цвет"
L["Choose the alternate color of the bars."] = "Выберите альтернативный цвет полос."

L["Threat warning"] = "Предупреждение об угрозе"
L["Flash screen"] = "Мигание экрана"
L["This will cause the screen to flash as a threat warning."] = "Предупреждение об угрозе будет производиться посредством мигания экрана."
L["Shake screen"] = "Тряска экрана"
L["This will cause the screen to shake as a threat warning."] = "Предупреждение об угрозе будет производиться посредством тряски экрана."
L["Play sound"] = "Проиграть звук"
L["This will play a sound as a threat warning."] = "Предупреждение об угрозе будет производиться посредством звукового сигнала."
L["Threat sound"] = "Звук угрозы"
L["The sound that will be played when your threat percentage reaches a certain point."] = "Будет воспроизводиться звук, когда процент угрозы достигнет определенной точки."
L["Threat threshold"] = "Порог угрозы"
L["When your threat reaches this level, relative to tank, warnings are shown."] = "При достижении угрозы до этого уровня, по сравнению с танком, будут показаны предупреждения."

L["Enables the title bar."] = "Включить заглавную полосу."

L["Total healing"] = "Всего исцеления"

L["Skada Menu"] = "Меню Skada"
L["Switch to mode"] = "Переключить режим"
L["Report"] = "Отчет"
L["Toggle window"] = "Открыть/закрыть окно"
L["Configure"] = "Конфигурация"
L["Delete segment"] = "Удалить сегмент"
L["Keep segment"] = "Хранить сегмент"
L["Mode"] = "Режим"
L["Lines"] = "Строки"
L["Channel"] = "Канал"
L["Send report"] = "Отослать отчёт"
L["No mode selected for report."] = "Для отчета не выбран режим."
L["Say"] = "Сказать"
L["Raid"] = "Рейд"
L["Party"] = "Группа"
L["Guild"] = "Гильдия"
L["Officer"] = "Офицер"
L["Self"] = "Себе"

L["'s Healing"] = " - Исцеление"

L["Delete window"] = "Удалить окно"
L["Deletes the chosen window."] = "Удалить все выбранные окна."
L["Choose the window to be deleted."] = "Выберите окно для удаления."
L["Enter the name for the new window."] = "Введите имя нового окна."
L["Create window"] = "Создать окно"
L["Windows"] = "Окна"

L["Switch to segment"] = "Переключиться на сегмент"
L["Segment"] = "Сегмент"

L["Whisper"] = "Шепот"

L["No mode or segment selected for report."] = "Для отчёта не выбран режим или сегмент."
L["Name of recipient"] = "Имя получателя"

L["Resist"] = "Сопротивление"
L["Reflect"] = "Отражение"
L["Parry"] = "Парир."
L["Immune"] = "Невоспр."
L["Evade"] = "Мимо"
L["Dodge"] = "Уклонение"
L["Deflect"] = "Отражение"
L["Block"] = "Блок"
L["Absorb"] = "Поглощение"

L["Last fight"] = "Последняя битва"
L["Disable while hidden"] = "Отключить когда скрыт"
L["Skada will not collect any data when automatically hidden."] = "Skada не будет собирать данные, когда скрыт."

L["Rename window"] = "Переименовать окно"
L["Enter the name for the window."] = "Введите новое имя для окна."

L["Bar display"] = "Отображение полос"
L["Display system"] = "Система отображения"
L["Choose the system to be used for displaying data in this window."] = "Выберите систему используемую для отображения данных в окне."

L["Hides HPS from the Healing modes."] = "Скрыть ИВС (HPS) из режима исцеления."
L["Do not show HPS"] = "Не отображать ИВС"

L["Do not show DPS"] = "Не показывать УВС"
L["Hides DPS from the Damage mode."] = "Скрыть УВС в режиме урона."

L["Class color bars"] = "Полосы по цвету класса"
L["When possible, bars will be colored according to player class."] = "Когда это возможно, полосы будут окрашены в соответствии с классом игрока."
L["Class color text"] = "Текст по цвету класса"
L["When possible, bar text will be colored according to player class."] = "Когда это возможно, текст полос будет окрашен в соответствии с классом игрока."

L["Reset"] = "Сброс"
L["Show tooltips"] = "Показывать подсказки"

L["Shows tooltips with extra information in some modes."] = "В некоторых режимах показывать подсказки с дополнительной информацией."


L["Minimum hit:"] = "Минимальное попадание:"
L["Maximum hit:"] = "Максимальное попадание:"
L["Average hit:"] = "Среднее попадание:"
L["Absorbs"] = "Поглощения"
L["'s Absorbs"] = " - Поглощения"

L["Do not show TPS"] = "Не показывать TPS (ГУВС)"
L["Do not warn while tanking"] = "Не извещать при танковании"

L["Hide in PvP"] = "Скрывать в PvP"
L["Hides Skada's window when in Battlegrounds/Arenas."] = "Скрывать окно Skada на аренах/полях сражений."

L["Healed players"] = "Исцелённые игроки"
L["Healed by"] = "Healed by"
L["Absorb details"] = "Детали поглот."
L["Spell details"] = "Детали заклинаний"
L["Healing spell list"] = "Список исцеляющих заклинаний"
L["Healing spell details"] = "Детали исцеляющих заклинаний"
L["Debuff spell list"] = "Список отрицательных эффектов"







L["Click for"] = "Клик -"
L["Shift-Click for"] = "Shift+Клик -"
L["Control-Click for"] = "Control+Клик - "
L["Default"] = "По умолчанию"
L["Top right"] = "Вверху справа"
L["Top left"] = "Вверху слева"



L["Position of the tooltips."] = "Позиция подсказки"
L["Tooltip position"] = "Позиция подсказки"


L["Shows a button for opening the menu in the window title bar."] = "Shows a button for opening the menu in the window title bar."
L["Show menu button"] = "Показывать кнопку меню"



L["Attack"] = "Атака"
L["Damage"] = "Нанесённый урон"
L["Hit"] = "Попадание"
L["Critical"] = "Крит"
L["Missed"] = "Промах"
L["Resisted"] = "Отражено"
L["Blocked"] = "Заблокировано"
L["Glancing"] = "Вскользь"
L["Crushing"] = "Сокр. удар"
L["Absorbed"] = "Поглощено"
L["HPS"] = "ИВС"
L["Healing"] = "Исцеление"

L["Overhealing"] = "Избыточное лечение"
L["Threat"] = "Угроза"

L["Announce CC breaking to party"] = "Announce CC breaking to party"
L["Ignore Main Tanks"] = "Игнорировать танков"
L["%s on %s removed by %s's %s"] = "%s on %s removed by %s's %s"
L["%s on %s removed by %s"] = "%s on %s removed by %s"

L["Start new segment"] = "Начать новый сегмент"
L["Columns"] = "Колонки"
L["Overheal"] = "Переисцеление"
L["Percent"] = "Процент"
L["TPS"] = "УгВС"

L["%s dies"] = "%s смертей"
L["Change"] = "Изменение"
L["Health"] = "Здоровье"

L["Hide in combat"] = "Скрывать в бою"
L["Hides Skada's window when in combat."] = "Скрывать окно Skada в бою"

L["Tooltips"] = "Подсказки"
L["Informative tooltips"] = "Информационная подсказка"
L["Shows subview summaries in the tooltips."] = "Shows subview summaries in the tooltips."
L["Subview rows"] = "Subview rows"
L["The number of rows from each subview to show when using informative tooltips."] = "The number of rows from each subview to show when using informative tooltips."

L["Damage done"] = "Нанесено урона"
L["Active Time"] = "Время активности"
L["Segment Time"] = "Время сегментировано"
L["Absorbs and healing"] = "Лечение и Поглощение"




L["Show rank numbers"] = "Показать номер линии"
L["Shows numbers for relative ranks for modes where it is applicable."] = "Показывает номера линий в режимах, где это применимо."

L["Use focus target"] = "Исп. цель фокуса"
L["Shows threat on focus target, or focus target's target, when available."] = "Показывает угрозу цели фокуса, или цели цели фокуса, если доступно."

L["Show spark effect"] = "Показать эффект искры"










-- Scroll








-- =================== --
-- damage module lines --
-- =================== --

L["DPS"] = "УВС"


L["Damage on"] = "Урон по"




L["Damage Taken"] = "Полученный урон"
L["Damage from"] = "Урон от"



L["Enemy damage done"] = "Нанесено урона врагом"
L["Enemy damage taken"] = "Получено урона врагом"

L["%s's Damage"] = "%s - Урон"











L["Damage taken by spell"] = "Урон, полученный от заклинания"





L["Damage done per player"] = "Нанесено урона каждым играком"
L["Damage taken per player"] = "Получено урона каждым играком"

-- ================== --
-- auras module lines --
-- ================== --














-- ======================= --
-- interrupts module lines --
-- ======================= --

L["Interrupts"] = "Прерывание"




-- ==================== --
-- failbot module lines --
-- ==================== --

L["Fails"] = "Неудачи"
L["%s's Fails"] = "%s - Неудачи"



-- ======================== --
-- improvement module lines --
-- ======================== --








-- =================== --
-- deaths module lines --
-- =================== --

L["Deaths"] = "Смерти"
L["%s's Death"] = "%s - Смерть"

L["Death log"] = "Журнал смертей"






-- ==================== --
-- dispels module lines --
-- ==================== --

L["Dispels"] = "Рассеивания"









-- ======================= --
-- cc tracker module lines --
-- ======================= --

L["CC"] = "СС"


L["CC Breakers"] = "CC Breakers"







-- CC Done:








-- CC Taken








-- ====================== --
-- resurrect module lines --
-- ====================== --













-- ====================== --
-- Avoidance & Mitigation --
-- ====================== --




















