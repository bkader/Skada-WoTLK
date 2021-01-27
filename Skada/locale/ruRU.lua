local L = LibStub("AceLocale-3.0"):NewLocale("Skada", "ruRU", false)
if not L then return end

L["A damage meter."] = "Измеритель урона."
L["Memory usage is high. You may want to reset Skada, and enable one of the automatic reset options."] = "Использование памяти слишком высокое. Вы можете сбросить данные Skada и включить один из вариантов автоматического сброса."

L["Skada: Modes"] = "Skada: Режимы"
L["Skada: Fights"] = "Skada: Бои"

L["Error: No options selected"] = "Ошибка: параметры не выбраны"

L["Profiles"] = "Профили"
L["Enable"] = "Включить"
L["ENABLED"] = "ВКЛЮЧЕН"
L["Disable"] = "Отключить"
L["DISABLED"] = "ВЫКЛЮЧЕН"

-- common lines
L["Active Time"] = "Время активности"
L["Segment Time"] = "Время сегмента"
L["Click for"] = "Click -"
L["Shift-Click for"] = "Shift-Click -"
L["Control-Click for"] = "Control-Click - "
L["Minimum"] = "Минимум"
L["Minimum hit:"] = "Минимальное попадание:"
L["Maximum"] = "Максимум"
L["Maximum hit:"] = "Максимальное попадание:"
L["Average"] = "В среднем"
L["Average hit:"] = "Среднее попадание:"
L["Total hits:"] = "Всего попаданий:"
L["Count"] = "Количество"
L["Percent"] = "Процент"

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

L["General options"] = "Основные настройки"

-- windows section:
L["Window"] = "Окно"
L["Windows"] = "Окна"

L["Create window"] = "Создать окно"
L["Enter the name for the new window."] = "Введите имя нового окна."

L["Delete window"] = "Удалить окно"
L["Choose the window to be deleted."] = "Выберите окно для удаления."

L["Deletes the chosen window."] = "Удалить выбранное окно."

L["Rename window"] = "Переименовать окно"
L["Enter the name for the window."] = "Введите новое имя для окна."
L["Lock window"] = "Заблокировать окно"
L["Locks the bar window in place."] = "Зафиксировать окно"
L["Hide window"] = "Скрыть окно"
L["Hides the window."] = "Скрыть окно"
L["Display system"] = "Система отображения"
L["Choose the system to be used for displaying data in this window."] = "Выберите систему используемую для отображения данных в окне."

-- bars
L["Bars"] = "Полосы"
L["Bar font"] = "Шрифт на полосах"
L["The font used by all bars."] = "Шрифт всех полос."
L["Bar font size"] = "Размер шрифта на полосах"
L["The font size of all bars."] = "Размер шрифта для всех полос."

L["Values font"] = "Шрифт чисел"
L["The font used by bar values."] = "Шрифт, используемый для столбцов значений."
L["Values font size"] = "Размер шрифта чисел"
L["The font size of bar values."] = "Шрифт, используемый для номеров столбцов."

L["Font flags"] = "Флаги шрифта"
L["Sets the font flags."] = "Установить флаги шрифта."
L["None"] = "Нет"
L["Outline"] = "Окантовка"
L["Thick outline"] = "Толстая окантовка"
L["Monochrome"] = "Черно-белое"
L["Outlined monochrome"] = "Черно-белое с окантовкой"
L["Bar texture"] = "Текстура полос"
L["The texture used by all bars."] = "Текстура всех полос."
L["Bar spacing"] = "Промежуток между полосами"
L["Distance between bars."] = "Расстояние между полосами"
L["Bar height"] = "Высота полос"
L["The height of the bars."] = "Высота полос."
L["Bar width"] = "Длина полос"
L["The width of the bars."] = "Длина всех полос."
L["Bar orientation"] = "Ориентация полос"
L["The direction the bars are drawn in."] = "Направление заполнения полос."
L["Left to right"] = "Слева направо"
L["Right to left"] = "Справа налево"
L["Reverse bar growth"] = "Обратный рост полос"
L["Bars will grow up instead of down."] = "Полосы будут расти вверх, а не вниз."
L["Bar color"] = "Цвет полос"
L["Choose the default color of the bars."] = "Выберите цвет полос по умолчанию."
L["Background color"] = "Цвет фона"
L["Choose the background color of the bars."] = "Выберите цвет фона для строк."
L["Spell school colors"] = "Цвет школы заклинания"
L["Use spell school colors where applicable."] = "Использовать цвет школы заклинания, если возможно."
L["Class color bars"] = "Полосы по цвету класса"
L["When possible, bars will be colored according to player class."] = "Когда это возможно, полосы будут окрашены в соответствии с классом игрока."
L["Class color text"] = "Текст по цвету класса"
L["When possible, bar text will be colored according to player class."] = "Когда это возможно, текст полос будет окрашен в соответствии с классом игрока."
L["Class icons"] = "Иконки класса"
L["Use class icons where applicable."] = "Использовать иконки класса, когда это приемлимо."
L["Spec icons"] = "Иконки талантов"
L["Use specialization icons where applicable."] = "Использовать иконки талантов, когда это приемлимо."
L["Role icons"] = "Иконки ролей"
L["Use role icons where applicable."] = "Использовать иконки ролей (если возможно)."
L["Show spark effect"] = "Показать эффект искры"
L["Clickthrough"] = "Сквозной клик"
L["Disables mouse clicks on bars."] = "Отключить клики мышкой по полоскам."
L["Smooth bars"] = "Плавные полосы"
L["Animate bar changes smoothly rather than immediately."] = "Анимация полосы меняется плавно, а не сразу."

-- title bar
L["Title bar"] = "Полоса заголовка"
L["Enables the title bar."] = "Включить полосу заголовка."
L["Include set"] = "Текущий режим"
L["Include set name in title bar"] = "Отображать в полосе заголовка текущий режим"
L["Title height"] = "Высота заголовка"
L["The height of the title frame."] = "Высота заголовка окна."
L["Title font size"] = "Размер шрифта заголовка"
L["The font size of the title bar."] = "Размер шрифта строки заголовка."
L["Title color"] = "Цвет заголовка"
L["The text color of the title."] = "Цвет текста для заголовка."
L["The texture used as the background of the title."] = "Текстура, используемая для фона заголовка."
L["The background color of the title."] = "Цвет фона заголовка."
L["Border texture"] = "Текстура рамки"
L["The texture used for the borders."] = "Текстура, используемая для рамок."
L["The texture used for the border of the title."] = "Текстура, используемая для рамки заглавия."
L["Border color"] = "Цвет рамки"
L["The color used for the border."] = "Цвет, используемый для рамок."
L["Buttons"] = "Кнопки"

-- general window
L["Background"] = "Фон"
L["Background texture"] = "Текстура фона"
L["The texture used as the background."] = "Текстура, используемая для фона."
L["Tile"] = "Заполнение"
L["Tile the background texture."] = "Заполнение фоновой текстуры"
L["Tile size"] = "Размер заполнения"
L["The size of the texture pattern."] = "Размер шаблона текстуры."
L["Background color"] = "Цвет фона"
L["The color of the background."] = "Цвет фона."
L["Border"] = "Рамка"
L["Border thickness"] = "Толщина рамки"
L["The thickness of the borders."] = "Толщина рамок."
L["General"] = "Общие"
L["Scale"] = "Масштаб"
L["Sets the scale of the window."] = "Установка масштаба окна"
L["Strata"] = "Слой"
L["This determines what other frames will be in front of the frame."] = "Это определяет, что другие окна будут перед этим окном."
L["Width"] = "Ширина"
L["Height"] = "Высота"

-- switching
L["Mode switching"] = "Смена режима"
L["Combat mode"] = "Режим битвы"
L["Automatically switch to set 'Current' and this mode when entering combat."] = "Автоматически переключаться на 'Текущую' установку и этот режим при входе в бой."
L["Return after combat"] = "Возврат после боя"
L["Return to the previous set and mode after combat ends."] = "Возврат к предыдущей установке и режиму после окончания боя."
L["Wipe mode"] = "Режим вайпа"
L["Automatically switch to set 'Current' and this mode after a wipe."] = "Автоматически переключиться в этот режим и \"Текущий бой\" после вайпа."

L["Inline bar display"] = "Полосы в одну линию"
L["Inline display is a horizontal window style."] = "Отображение в одну линию является горизонтальным стилем окна."
L["Text"] = "Текст"
L["Font Color"] = "Цвет шрифта"
L["Font Color. \nClick \"Use class colors\" to begin."] = "Цвет шрифта. \nЧтобы начать, нажмите \"Использовать цвета класса\"."
L["Width of bars. This only applies if the \"Fixed bar width\" option is used."] = "Ширина штанг. Это применимо, только если используется опция \"Фиксированная ширина полос\"."
L["Fixed bar width"] = "Фиксированная ширина полос"
L["If checked, bar width is fixed. Otherwise, bar width depends on the text width."] = "Если включено, то ширина полосы зафиксирована. В противном случае, ширина полосы зависит от ширины текста."
L["Use class colors"] = "Использовать цвета класса"
L["Class colors:\n|cFFF58CBAKader|r - 5.71M (21.7K)\n\nWithout:\nKader - 5.71M (21.7K)"] = "Цвета класса:\n|cFFF58CBAKader|r - 5.71M (21.7K)\nБез:\nKader - 5.71M (21.7K)"
L["Put values on new line."] = "Поместите значения в новую строку."
L["New line:\nKader\n5.71M (21.7K)\n\nDivider:\nKader - 5.71M (21.7K)"] = "Новая линия:\nKader\n5.71M (21.7K)\n\nРазделитель:\nKader - 5.71M (21.7K)"
L["Use ElvUI skin if avaliable."] = "Если возможно, используйте скин ElvUI."
L["Check this to use ElvUI skin instead. \nDefault: checked"] = "Установите этот флажок, чтобы вместо этого использовать скин ElvUI. \nПо умолчанию: проверено"
L["Use solid background."] = "Используйте сплошной фон."
L["Un-check this for an opaque background."] = "Снимите флажок для непрозрачного фона."

L["Data text"] = "Текстовые данные"
L["Text color"] = "Цвет текста"
L["Choose the default color."] = "Выберите цвет по умолчанию."
L["Hint: Left-Click to set active mode."] = "Подсказка: ЛКМ для выбора активного режима."
L["Right-click to set active set."] = "ПКМ для установки активного набора."
L["Shift+Left-Click to open menu."] = "Shift+ЛКМ, чтобы открыть меню."

-- data resets
L["Data resets"] = "Сброс данных"
L["Reset on entering instance"] = "Сбрасывать при входе в подземелье"
L["Controls if data is reset when you enter an instance."] = "Управление сбросом данных при входе в подземелье."
L["Reset on joining a group"] = "Сбрасывать при присоединении к группе"
L["Controls if data is reset when you join a group."] = "Управление сбросом данных при присоединении к группе."
L["Reset on leaving a group"] = "Сбрасывать при покидании группы"
L["Controls if data is reset when you leave a group."] = "Управление сбросом данных после выхода из группы."
L["Ask"] = "Уточнить"
L["Do you want to reset Skada?"] = "Вы хотите сбросить Scada?"
L["All data has been reset."] = "Все данные были сброшены."

-- general options
L["Show minimap button"] = "Показывать кнопку у миникарты"
L["Toggles showing the minimap button."] = "Отобразить/скрыть кнопку у мини-карты."
L["Shorten menus"] = "Сокращенное меню"
L["Removes mode and segment menus from Skada menu to reduce its height. Menus are still accessible using window buttons."] = "Удалены режимы и сегментные меню из меню Skada для уменьшения высоты. Доступ к меню по-прежнему можно получить с помощью оконных кнопок."
L["Translit"] = "Транслит"
L["Make those russian letters that no one understand to be presented as western letters."] = "Пусть эти русские буквы, которые никто не понимает, будут представлены как латинские буквы."
L["Merge pets"] = "Объединять питомцев"
L["Merges pets with their owners. Changing this only affects new data."] = "Считать урон от атак питомцев вместе с их хозяевами. Изменение опции повлияет только на новые данные."
L["Show totals"] = "Показывать итог"
L["Shows a extra row with a summary in certain modes."] = "Отображение дополнительной строки с суммарной информацией в некоторых режимах."
L["Only keep boss fighs"] = "Хранить только бои с боссами"
L["Boss fights will be kept with this on, and non-boss fights are discarded."] = "При включении этой опции бои с боссами будут сохраняться, а бои с не-боссами будут игнорироваться."
L["Hide when solo"] = "Скрывать когда один"
L["Hides Skada's window when not in a party or raid."] = "Скрывать окно Skada, если вы не состоите в группе или рейде."
L["Hide in PvP"] = "Скрывать в PvP"
L["Hides Skada's window when in Battlegrounds/Arenas."] = "Скрывать окно Skada на аренах/полях сражений."
L["Hide in combat"] = "Скрывать в бою"
L["Hides Skada's window when in combat."] = "Скрывать окно Skada в бою"
L["Disable while hidden"] = "Отключить когда скрыт"
L["Skada will not collect any data when automatically hidden."] = "Skada не будет собирать данные, когда окно автоматически скрывается."
L["Sort modes by usage"] = "Упорядочить режимы по использованию"
L["The mode list will be sorted to reflect usage instead of alphabetically."] = "Сортировка списка режимов по частоте использования, вместо алфавитного."
L["Show rank numbers"] = "Показать номер линии"
L["Shows numbers for relative ranks for modes where it is applicable."] = "Показывает номера линий в режимах, где это применимо."
L["Aggressive combat detection"] = "Агрессивное определение режима боя"
L["Skada usually uses a very conservative (simple) combat detection scheme that works best in raids. With this option Skada attempts to emulate other damage meters. Useful for running dungeons. Meaningless on boss encounters."] = "Обычно Skada использует простую схему определения начала боя, которая работает лучше всего в рейдах. С этой опцией Skada будет действовать как другие аддоны для подсчета урона. Полезно для подземелий. Бессмысленно на рейдовых боссах."
L["Autostop"] = "Останавливать в начале вайпа"
L["Automatically stops the current segment after half of all raid members have died."] = "Автоматически останавливает текущий сегмент после смерти половины всех участников рейда."
L["Always show self"] = "Всегда показывать себя"
L["Keeps the player shown last even if there is not enough space."] = "Сохранять игрока видимым, даже если места недостаточно."
L["Number format"] = "Формат чисел"
L["Controls the way large numbers are displayed."] = "Выбор вида отображения цифр."
L["Condensed"] = "Кратко"
L["Detailed"] = "Детально"
L["Data feed"] = "Подача данных"
L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."] = "Выберите, какие данные выводить в DataBroker. Для этого требуется, модификация которая поддерживает отображение LDB, к примеру Titan Panel."
L["Number set duplicates"] = "Количество дубликатов"
L["Append a count to set names with duplicate mob names."] = "Добавлять счетчик для мобов с одинаковыми именами"
L["Set format"] = "Установить формат"
L["Memory Check"] = "Проверка памяти"
L["Checks memory usage and warns you if it is greater than or equal to 30mb."] = "Проверяет использование памяти и предупреждает, если оно больше или равно 30 МБ."
L["Controls the way set names are displayed."] = "Настройка форматирования заголовков для боя"
L["Data segments to keep"] = "Сегменты для хранения"
L["The number of fight segments to keep. Persistent segments are not included in this."] = "Хранимое число сегментов боёв. В это число не входят сохраненные сегменты."
L["Update frequency"] = "Частота обновления"
L["How often windows are updated. Shorter for faster updates. Increases CPU usage."] = "Частота обновления окон. Меньшее значение способствует более быстрому обновлению. Увеличивает нагрузку процессора."

-- columns
L["Columns"] = "Колонки"

-- tooltips
L["Tooltips"] = "Подсказки"
L["Show tooltips"] = "Показывать подсказки"
L["Shows tooltips with extra information in some modes."] = "В некоторых режимах показывать подсказки с дополнительной информацией."
L["Informative tooltips"] = "Информационная подсказка"
L["Shows subview summaries in the tooltips."] = "Отображение строк информации с деталями в подсказках."
L["Subview rows"] = "Количество строк в подсказках"
L["The number of rows from each subview to show when using informative tooltips."] = "Количество отображаемых строк с деталями, когда используются информационные подсказки."
L["Tooltip position"] = "Позиция подсказки"
L["Position of the tooltips."] = "Позиция подсказок."
L["Default"] = "По умолчанию"
L["Top right"] = "Вверху справа"
L["Top left"] = "Вверху слева"
L["Bottom right"] = "Внизу справа"
L["Bottom left"] = "Внизу левый"
L["Smart"] = "Умный"
L["Follow Cursor"] = "Курсор мыши"

-- disabled modules
L["Modules"] = "Модули"
L["Disabled Modules"] = "Отключение модулей"
L["Tick the modules you want to disable."] = "Выберите модули, которые хотите отключить."
L["This change requires a UI reload. Are you sure?"] = "Это изменение требует перезагрузки UI. Вы уверены?"
L["Adds a set of standard themes to Skada. Custom themes can also be used."] = "Добавляет набор стандартных тем для Skada. Также могут быть использованы пользовательские темы."

-- themes module
L["Theme"] = "Тема"
L["Themes"] = "Темы"
L["Apply theme"] = "Применить тему"
L["Theme applied!"] = "Тема применена!"
L["Name of your new theme."] = "Название вашей новой темы."
L["Save theme"] = "Сохранить тему"
L["Delete theme"] = "Удалить тему"

-- scroll module
L["Scroll"] = "Прокрутка"
L["Mouse"] = "Мышь"
L["Scrolling speed"] = "Скорость прокрутки"
L["Scroll icon"] = "Значок прокрутки"
L["Scroll mouse button"] = "Кнопка прокрутки мыши"
L["Keybinding"] = "Привязка клавиш"
L["Key scrolling speed"] = "Привязки клавиш"

-- minimap button
L["Skada summary"] = "Skada: Сводка"
L["Left-Click to toggle windows."] = "Щелкните левой кнопкой мыши, чтобы показать или скрыть окна."
L["Shift+Left-Click to reset."] = "Shift+ЛКМ для сброса."
L["Right-click to open menu"] = "ПКМ для открытия меню"

-- skada menu
L["Skada Menu"] = "Меню Skada"
L["Delete segment"] = "Удалить сегмент"
L["Keep segment"] = "Хранить сегмент"
L["Toggle window"] = "Открыть/закрыть окно"
L["Start new segment"] = "Начать новый сегмент"

-- window buttons
L["Configure"] = "Конфигурация"
L["Opens the configuration window."] = "Открывает окно конфигурации."
L["Resets all fight data except those marked as kept."] = "Сбрасывает все данные боя, кроме отмеченных как сохраненные."
L["Segment"] = "Сегмент"
L["Jump to a specific segment."] = "Перейти к определенному сегменту."
L["Mode"] = "Режим"
L["Jump to a specific mode."] = "Перейти в определенный режим."
L["Report"] = "Отчет"
L["Opens a dialog that lets you report your data to others in various ways."] = "Открывает диалоговое окно, в котором можно различными способами сообщать свои данные другим пользователям."
L["Stop"] = "Остановить"
L["Stops or resumes the current segment. Useful for discounting data after a wipe. Can also be set to automatically stop in the settings."] = "Останавливает или возобновляет запись текущего сегмента. Полезна для сокращения объема данных при вайпе. Возможна настройка автоматической остановки в настройках."

-- default segments
L["Total"] = "Всего"
L["Current"] = "Текущий"

-- report module and window
L["Skada: %s for %s:"] = "Skada: %s для %s:"
L["Channel"] = "Канал"
L["Self"] = "Себе"
L["Party"] = "Группа"
L["Whisper"] = "Шепот"
L["Say"] = "Сказать"
L["Whisper Target"] = "Цель Шепота"
L["Raid"] = "Рейд"
L["Guild"] = "Гильдия"
L["Officer"] = "Офицер"
L["Lines"] = "Строки"
L["There is nothing to report."] = "Нет данных для отчета."
L["No mode or segment selected for report."] = "Для отчёта не выбран режим или сегмент."

-- ================== --
-- Bar Display Module --
-- ================== --

L["Bar display"] = "Отображение полос"
L["Bar display is the normal bar window used by most damage meters. It can be extensively styled."] = "Отображение полос - это обычное окно с полосами, которое использует большинство измерителей урона. Имеет множество возможностей для кастомизации."

-- ============= --
-- Threat Module --
-- ============= --

L["Threat"] = "Угроза"
L["Threat warning"] = "Предупреждение об угрозе"
L["Do not warn while tanking"] = "Не предупреждать при танковании"
L["Flash screen"] = "Мигание экрана"
L["This will cause the screen to flash as a threat warning."] = "Предупреждение об угрозе будет производиться посредством мигания экрана."
L["Shake screen"] = "Тряска экрана"
L["This will cause the screen to shake as a threat warning."] = "Предупреждение об угрозе будет производиться посредством тряски экрана."
L["Play sound"] = "Проиграть звук"
L["This will play a sound as a threat warning."] = "Предупреждение об угрозе будет производиться посредством звукового сигнала."
L["Threat sound"] = "Звук угрозы"
L["The sound that will be played when your threat percentage reaches a certain point."] = "Этот звук будет воспроизводиться, когда процент угрозы достигнет определенной точки."
L["Threat threshold"] = "Порог угрозы"
L["When your threat reaches this level, relative to tank, warnings are shown."] = "При достижении угрозы до этого уровня, по сравнению с танком, будут показаны предупреждения."
L["Show raw threat"] = "Показать чистою угрозу"
L["Shows raw threat percentage relative to tank instead of modified for range."] = "Показывать процент угрозы по сравнению с танковой."
L["Use focus target"] = "Исп. цель фокуса"
L["Shows threat on focus target, or focus target's target, when available."] = "Показывает угрозу цели фокуса, или цели цели фокуса, если доступно."
L["TPS"] = "УгВС"
L["Threat: Personal Threat"] = "Угроза: Своя Угроза"

-- ======================== --
-- Absorbs & Healing Module --
-- ======================== --

L["Healing"] = "Исцеление"
L["Healed player list"] = "Исцелённые игроки"
L["Healing spell list"] = "Список исцеляющих заклинаний"
L["%s's healing"] = "%s - Исцеление"
L["%s's healing spells"] = "%s - исцеляющие заклинания"
L["%s's healed players"] = "%s - исцелил игроков"
L["HPS"] = "ИВС"

L["Total healing"] = "Всего исцеления"

L["Overhealing"] = "Избыточное исцеление"
L["Overheal"] = "Переисцеление"
L["Overhealed player list"] = "Сверхлеченные игроки"
L["Overhealing spell list"] = "Заклинания избыточного исцеления"
L["%s's overhealing spells"] = "%s - Заклинания избыточного исцеления"
L["%s's overhealed players"] = "%s - Сверхлеченные игроки"

L["Healing and Overhealing"] = "Исцеление и Избыточное исцеление"
-- L["Healing and overhealing spells"] = ""
-- L["Healed and overhealed players"] = ""
-- L["%s's healing and overhealing spells"] = ""
-- L["%s's healed and overhealed players"] = ""

L["Absorbs"] = "Поглощение"
L["Absorbed player list"] = "Поглощено на игроках"
L["Absorb spell list"] = "Список заклинаний поглощения"
L["%s's absorbed players"] = "%s - Поглощено на игроках"
L["%s's absorb spells"] = "%s - Заклинания поглощения"

L["Absorbs and healing"] = "Поглощение и исцеление"
L["Absorbs and healing spell list"] = "Список заклинаний поглощения и исцеления"
L["Absorbed and healed players"] = "Поглощение и исцеление игроков"
L["%s's absorb and healing spells"] = "%s - Заклинания поглощения и исцеления"
L["%s's absorbed and healed players"] = "%s - Поглощение и исцеление игроков"

-- ============ --
-- Auras Module --
-- ============ --

L["Uptime"] = "Время"

L["Buffs and Debuffs"] = "Баффы и Дебаффы"
L["Buffs"] = "Баффы"
L["Buff spell list"] = "Список баффов"
L["%s's buffs"] = "%s - Баффы"

L["Debuffs"] = "Дебаффы"
L["Debuff spell list"] = "Список дебаффов"
L["Debuff target list"] = "Цели дебаффа"
L["%s's debuffs"] = "%s - Дебаффы"
L["%s's debuff targets"] = "%s - Цели дебаффа"
L["%s's <%s> targets"] = "%s <%s> цели"

L["Sunder Counter"] = "Раскол брони"
L["Sunder target list"] = "Раскол брони список целей"

-- ================= --
-- CC Tracker Module --
-- ================= --

L["CC Tracker"] = "Отслеживание Контроля"

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

L["CC Breaks"] = "Прерываний контроля"
L["CC Breakers"] = "Прерыватели контроля"
-- L["CC Break spells"] = ""
-- L["CC Break spell targets"] = ""
-- L["CC Break targets"] = ""
-- L["CC Break target spells"] = ""
-- L["%s's CC Break <%s> spells"] = ""
-- L["%s's CC Break <%s> targets"] = ""
-- L["%s's CC Break spells"] = ""
-- L["%s's CC Break targets"] = ""

-- options
L["CC"] = "Контроль"
L["Announce CC breaking to party"] = "Объявлять прерывания контроля в группу"
L["Ignore Main Tanks"] = "Игнорировать танков"
L["%s on %s removed by %s"] = "%s на %s прервал %s"
L["%s on %s removed by %s's %s"] = "%s на %s прервал %s (%s)"

-- ============= --
-- Damage Module --
-- ============= --

-- damage done module
L["Damage"] = "Урон"
L["Damage target list"] = "Урон по врагам"
L["Damage spell list"] = "Список заклинаний"
L["Damage spell details"] = "Детали боевых заклинаний"
L["Damage spell targets"] = "Цели заклинаний"
L["Damage done"] = "Нанесено урона"
L["%s's damage"] = "%s - урона"
L["%s's <%s> damage"] = "%s <%s> урона"

L["Useful damage"] = "Полезный урон"

L["Damage done by spell"] = "Урон от заклинания"
-- L["%s's sources"] = ""

L["DPS"] = "УВС"
L["Damage: Personal DPS"] = "Урон: собственный УВС"

L["RDPS"] = "РУВС"
L["Damage: Raid DPS"] = "Урон: УВС рейда"

-- damage taken module
L["Damage taken"] = "Получено урона"
L["Damage taken by %s"] = "%s - Полученный урон"
L["<%s> damage on %s"] = "Урон %s по %s"

L["Damage source list"] = "Список источников повреждений"
L["Damage spell sources"] = "Источники заклинаний"
L["Damage taken by spell"] = "Урон, полученный от заклинания"
L["%s's targets"] = "%s - цели"
L["DTPS"] = "ПУВС"

-- enemy damage done module
L["Enemy damage done"] = "Урон, нанесенный противником"
L["Damage done per player"] = "Получено урона игроками"
L["Damage from %s"] = "Урон от %s"
L["%s's damage on %s"] = "Урон %s по %s"

-- enemy damage taken module
L["Enemy damage taken"] = "Получено урона врагом"
L["Damage taken per player"] = "Получено урона от игроков"
L["Damage on %s"] = "Урон по %s"
L["%s's damage sources"] = "%s - Источники повреждений"

-- avoidance and mitigation module
L["Avoidance & Mitigation"] = "Избегание и уменьшение урона"
L["Damage breakdown"] = "Детали повреждений"
L["%s's damage breakdown"] = "%s - Детали повреждений"

-- friendly fire module
L["Friendly Fire"] = "Урон по союзникам"

L["Critical"] = "Крит"
L["Glancing"] = "Вскользь"
L["Crushing"] = "Сокр. удар"

-- useful damage targets
-- L["Useful targets"] = ""
-- L["Oozes"] = ""
-- L["Princes overkilling"] = ""
-- L["Adds"] = ""
-- L["Halion and Inferno"] = ""
-- L["Valkyrs overkilling"] = ""

-- missing bosses entries
L["Cult Adherent"] = "Приверженец культа"
L["Cult Fanatic"] = "Фанатик культа"
L["Darnavan"] = "Дарнаван"
L["Deformed Fanatic"] = "Кособокий фанатик"
L["Empowered Adherent"] = "Могущественный последователь"
L["Gas Cloud"] = "Облако газа"
L["Living Inferno"] = "Живое адское пламя"
L["Reanimated Adherent"] = "Воскрешенный последователь"
L["Reanimated Fanatic"] = "Воскрешенный фанатик"
L["Volatile Ooze"] = "Неустойчивый слизнюк"
L["Wicked Spirit"] = "Зловещий дух"

L["Kor'kron Sergeant"] = "Кор'кронский сержант"
L["Kor'kron Axethrower"] = "Кор'кронский метатель топоров"
L["Kor'kron Rocketeer"] = "Кор'кронский ракетчик"
L["Kor'kron Battle-Mage"] = "Кор'кронский боевой маг"
L["Skybreaker Sergeant"] = "Сержант с \"Усмирителя небес\""
L["Skybreaker Rifleman"] = "Ружейник с \"Усмирителя небес\""
L["Skybreaker Mortar Soldier"] = "Оружейник с \"Усмирителя небес\""
L["Skybreaker Sorcerer"] = "Колдун с \"Усмирителя небес\""
L["Stinky"] = "Вонючка"
L["Precious"] = "Прелесть"
L["Dream Cloud"] = "Облако снов"
L["Risen Archmage"] = "Воскрешенный верховный маг"
L["Blazing Skeleton"] = "Исторгающий пламя скелет"
L["Blistering Zombie"] = "Волдырный зомби"
L["Gluttonous Abomination"] = "Прожорливое поганище"

-- ============= --
-- Deaths Module --
-- ============= --
L["Deaths"] = "Смерти"
L["%s's death"] = "%s - Смерть"
L["%s's deaths"] = "%s - Смерти"
L["Death log"] = "Журнал смертей"
L["%s's death log"] = "%s - Журнал смерти"
L["Player's deaths"] = "Смерть игрока"
L["%s dies"] = "%s умирает"
L["Spell details"] = "Детали заклинания"
L["Spell"] = "Заклинание"
L["Amount"] = "Количество"
L["Source"] = "Источник"
L["Health"] = "Здоровье"
L["Change"] = "Изменение"

-- activity module
L["Activity"] = "Активность"
L["Activity per target"] = "Активность на цель"

-- ==================== --
-- dispels module lines --
-- ==================== --

L["Dispels"] = "Рассеивания"

L["Dispel spell list"] = "Список заклинаний рассеивания"
L["Dispelled spell list"] = "Список рассеянных заклинаний"
L["Dispelled target list"] = "Список целей рассеивания"

L["%s's dispel spells"] = "%s - Заклинания рассеивания"
L["%s's dispelled spells"] = "%s - Рассеянные заклинания"
L["%s's dispelled targets"] = "%s - Цели рассеивания"

-- ==================== --
-- failbot module lines --
-- ==================== --

L["Fails"] = "Неудачи"
L["%s's fails"] = "%s - Неудачи"
L["Player's failed events"] = "Неудачи события игрока"
L["Event's failed players"] = "Неудачи игроки события"

-- ======================== --
-- improvement module lines --
-- ======================== --

L["Improvement"] = "Улучшение"
L["Improvement modes"] = "Режимы улучшение"
L["Improvement comparison"] = "Сравнение улучшений"
L["Do you want to reset your improvement data?"] = "Вы хотите сбросить данные об улучшении?"
L["%s's overall data"] = "%s - Данные об улучшении"

-- ======================= --
-- interrupts module lines --
-- ======================= --

L["Interrupts"] = "Прерывания"
L["Interrupt spells"] = "Заклинания прерывания"
L["Interrupted spells"] = "Прерванные заклинания"
L["Interrupted targets"] = "Цели прерывания"
L["%s's interrupt spells"] = "%s - Заклинания прерывания"
L["%s's interrupted spells"] = "%s - Прерванные заклинания"
L["%s's interrupted targets"] = "%s - Цели прерывания"

-- =================== --
-- Power gained module --
-- =================== --

L["Power"] = "Энергия"
L["Power gained"] = "Получено энергии"
L["%s's gained %s"] = "Получено %s: %s"
L["Power gained: Mana"] = "Получено энергии: Мана"
-- L["Mana gained spell list"] = ""
L["Power gained: Rage"] = "Получено энергии: Ярость"
-- L["Rage gained spell list"] = ""
L["Power gained: Energy"] = "Получено энергии: Энергия"
-- L["Energy gained spell list"] = ""
L["Power gained: Runic Power"] = "Получено энергии: Сила рун"
-- L["Runic Power gained spell list"] = ""

-- ==================== --
-- Parry module lines --
-- ==================== --

L["Parry-haste"] = "Парирование"
L["Parry target list"] = "Список целей парирования"
L["%s's parry targets"] = "%s парирует цели"

-- ==================== --
-- Potions module lines --
-- ==================== --

L["Potions"] = "Зелья"
L["Potions list"] = "Список зелий"
L["Players list"] = "Список игроков"
L["%s's used potions"] = "%s - Использованные зелья"

-- ====================== --
-- resurrect module lines --
-- ====================== --

L["Resurrects"] = "Воскрешения"
L["Resurrect spell list"] = "Список заклинаний воскрешения"
L["Resurrect spell target list"] = "Список целей заклинания воскрешения"
L["Resurrect target list"] = "Список целей воскрешения"
L["Resurrect target spell list"] = "Список заклинаний воскрешения по цели"

-- L["%s's resurrect spells"] = ""
-- L["%s's resurrect targets"] = ""
-- L["%s's received resurrects"] = ""
-- L["%s's resurrect <%s> targets"] = ""

-- ==================== --
-- spamage module lines --
-- ==================== --

L["Spamage"] = "Спам"
L["Suppresses chat messages from damage meters and provides single chat-link damage statistics in a popup."] = "Подавляет сообщения чата от счетчиков урона и предоставляет статистику в одном всплывающем окне."
L["Capture Delay"] = "Задержка захвата"
L["How many seconds the addon waits after \"Skada: *\" lines before it assumes spam burst is over. 1 seems to work in most cases"] = "Кол-во секунд, которое аддон будет ожидать после начала спама от Skada. 1сек достаточно в большинстве случаев"
L["Filter Custom Channels"] = "Произвольный канал"
L["Selects the action to perform when encountering damage meter data in custom channels"] = "Отслеживать информацию в произвольном канале"
L["Filter Guild"] = "Канал гильдии"
L["Selects the action to perform when encountering damage meter data in guild chat"] = "Отслеживать информацию в канале гильдии"
L["Filter Officer"] = "Офицерский канал"
L["Selects the action to perform when encountering damage meter data in officer chat"] = "Отслеживать информацию в канале офицеров"
L["Filter Party"] = "Канал группы"
L["Selects the action to perform when encountering damage meter data in party chat"] = "Отслеживать информацию в канале группы"
L["Filter Raid"] = "Канал рейда"
L["Selects the action to perform when encountering damage meter data in raid chat"] = "Отслеживать информацию в канале рейда"
L["Filter Say"] = "Канал \"сказать\""
L["Selects the action to perform when encountering damage meter data in say chat"] = "Отслеживать информацию в канале \"сказать\""
L["Filter Whisper"] = "Канал \"шепот\""
L["Selects the action to perform when encountering damage meter whisper"] = "Отслеживать информацию в канале \"шепот\""
L["Filter Yell"] = "Канал \"крик\""
L["Selects the action to perform when encountering damage meter data in yell chat"] = "Отслеживать информацию в канале \"крик\""
L["Do Nothing"] = "Не активно"
L["Compress"] = "Слежение"
L["Suppress"] = "Блокировать"
L["Reported by: %s"] = "Рапорт от: %s"