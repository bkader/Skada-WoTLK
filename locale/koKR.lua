local L = LibStub("AceLocale-3.0"):NewLocale("Skada", "koKR", false)

if not L then return end

L["Disable"] = "비활성화"
L["Profiles"] = "프로필"
L["Hint: Left-Click to toggle Skada window."] = "힌트: 좌-클릭으로 Skada 창을 표시/숨김 합니다."
L["Shift + Left-Click to reset."] = "Shift + 좌-클릭으로 초기화 합니다."
L["Right-click to open menu"] = "우-클릭으로 메뉴를 엽니다."
L["Options"] = "옵션"
L["Appearance"] = "발표"
L["A damage meter."] = "데미지 미터기입니다."
L["Skada summary"] = "Skada 요약"


L["opens the configuration window"] = "설정 창 열기"
L["resets all data"] = "모든 자료 초기화"

L["Current"] = "현재"
L["Total"] = "전체"


L["All data has been reset."] = "모든 자료가 초기화 되었습니다."
L["Skada: Modes"] = "Skada: 모드"
L["Skada: Fights"] = "Skada: 전투"

-- Options
L["Bar font"] = "바 글꼴"
L["The font used by all bars."] = "모든 바에 사용되는 글꼴입니다."
L["Bar font size"] = "바 글꼴 크기"
L["The font size of all bars."] = "모든 바의 글꼴 크기입니다."
L["Bar texture"] = "바 무늬"
L["The texture used by all bars."] = "모든 바에 사용되는 바 무늬입니다."
L["Bar spacing"] = "바 간격"
L["Distance between bars."] = "바 사이의 간격입니다."
L["Bar height"] = "바 높이"
L["The height of the bars."] = "바의 높이입니다."
L["Bar width"] = "바 너비"
L["The width of the bars."] = "바의 너비입니다."
L["Bar color"] = "바 색상"
L["Choose the default color of the bars."] = "바의 기본 색상을 선택합니다."
L["Max bars"] = "최대 바"
L["The maximum number of bars shown."] = "표시할 바의 최대 수치입니다."
L["Bar orientation"] = "바 진행 방향"
L["The direction the bars are drawn in."] = "바의 진행 방향입니다."
L["Left to right"] = "좌에서 우"
L["Right to left"] = "우에서 좌"
L["Combat mode"] = "전투 모드"
L["Automatically switch to set 'Current' and this mode when entering combat."] = "전투 시작시 '현재'전투의 설정한 모드에 따라 자동적으로 전환합니다."
L["None"] = "없음"
L["Return after combat"] = "전투 후 돌아가기"
L["Return to the previous set and mode after combat ends."] = "전투 종료 후에 이전 설정 및 모드으로 돌아갑니다."
L["Show minimap button"] = "미니맵 버튼 표시"
L["Toggles showing the minimap button."] = "미니맵 버튼 표시를 전환합니다."

L["reports the active mode"] = "활성화된 모드 보고"
L["Skada report on %s for %s, %s to %s:"] = "%s - %s의 Skada 보고, %s ~ %s:" -- Needs review
L["Only keep boss fighs"] = "보스 전투만 기록"
L["Boss fights will be kept with this on, and non-boss fights are discarded."] = "보스와의 전투에서만 기록되며, 보스와의 전투가 아니면 기록하지 않습니다."
L["Show raw threat"] = "기본 위협 표시"
L["Shows raw threat percentage relative to tank instead of modified for range."] = "탱커 범위에 대한 수정된 퍼센트로 대신하여 표시합니다."

L["Lock window"] = "창 고정"
L["Locks the bar window in place."] = "바 창을 고정합니다."
L["Reverse bar growth"] = "바 성장 방향 반대"
L["Bars will grow up instead of down."] = "바를 아래 대신에 위로 쌓게 합니다."
L["Number format"] = "숫자 형식"
L["Controls the way large numbers are displayed."] = "큰 수의 표시 방식을 설정합니다."
L["Reset on entering instance"] = "인던 진입시 초기화"
L["Controls if data is reset when you enter an instance."] = "인던에 진입할 경우에 자료를 초기화 하도록 설정합니다."
L["Reset on joining a group"] = "파티/공격대 참여시 초기화"
L["Controls if data is reset when you join a group."] = "파티/공격대에 참여할 경우에 자료를 초기화 하도록 설정합니다."
L["Reset on leaving a group"] = "파티/공격대 탈퇴시 초기화"
L["Controls if data is reset when you leave a group."] = "파티/공격대에서 떠날 경우에 자료를 초기화 하도록 설정합니다."
L["General options"] = "일반 설정"
L["Mode switching"] = "모드 전환"
L["Data resets"] = "자료 초기화"
L["Bars"] = "바"

L["Yes"] = "예"
L["No"] = "아니오"
L["Ask"] = "질문"
L["Condensed"] = "요약"
L["Detailed"] = "상세"

L["Hide when solo"] = "솔로잉시 숨김"
L["Hides Skada's window when not in a party or raid."] = "파티 또는 공격대가 아닐때 Skada 창을 숨깁니다."

L["Title bar"] = "제목 바"
L["Background texture"] = "배경 무늬"
L["The texture used as the background of the title."] = "제목의 배경에 사용할 무늬를 설정합니다."
L["Border texture"] = "테두리 무늬"
L["The texture used for the border of the title."] = "제목의 테두리에 사용할 무늬를 설정합니다."
L["Border thickness"] = "테두리 두께"
L["The thickness of the borders."] = "테두리의 두께를 설정합니다."
L["Background color"] = "배경 색상"
L["The background color of the title."] = "제목의 배경 색상을 설정합니다."

L["'s "] = "의"
L["Do you want to reset Skada?"] = "Skada를 초기화 하시겠습니까?"
L["The margin between the outer edge and the background texture."] = "바깥쪽 가장자리와 배경 무늬 사이의 여백을 설정합니다."
L["Margin"] = "여백"
L["Window height"] = "창 높이"
L["The height of the window. If this is 0 the height is dynamically changed according to how many bars exist."] = "창의 높이를 설정합니다. 만약 0이면 바의 수만큼 조절됩니다."
L["Adds a background frame under the bars. The height of the background frame determines how many bars are shown. This will override the max number of bars setting."] = "바 아래의 배경 프레임을 추가합니다. 배경 프레임의 높이가 얼마나 많은 바 표시를 결정합니다. 바의 최대 수 설정보다 우선합니다."
L["Enable"] = "활성화"
L["Background"] = "배경"
L["The texture used as the background."] = "배경에 사용할 무늬를 설정합니다."
L["The texture used for the borders."] = "테두리에 사용할 무늬를 설정합니다."
L["The color of the background."] = "배경의 색상을 설정합니다."
L["Data feed"] = "자료 표시"
L["Choose which data feed to show in the DataBroker view. This requires an LDB display addon, such as Titan Panel."] = "DataBroker로 보려면 자료 표시를 선택하세요. 이것은 타이탄 패널과 같은 LDB 디스플레이 애드온이 필요합니다."
L["RDPS"] = "RDPS"
L["Damage: Personal DPS"] = "피해량: 자신의 DPS"
L["Damage: Raid DPS"] = "피해량: 공격대 DPS"
L["Threat: Personal Threat"] = "위협: 자신의 위협"

L["Data segments to keep"] = "자료 세분화 유지"
L["The number of fight segments to keep. Persistent segments are not included in this."] = "전투 세분화의 수를 유지합니다. 이것은 지속성의 구분은 포함하지 않습니다."

L["Alternate color"] = "색상 변경"
L["Choose the alternate color of the bars."] = "바의 다른 색상을 선택합니다."

L["Threat warning"] = "위협 경고"
L["Flash screen"] = "화면 깜박임"
L["This will cause the screen to flash as a threat warning."] = "위협 경고로 화면을 깜박입니다."
L["Shake screen"] = "화면 진동"
L["This will cause the screen to shake as a threat warning."] = "위협 경고로 화면을 흔듭니다."
L["Play sound"] = "소리 재생"
L["This will play a sound as a threat warning."] = "위협 경고로 소리를 재생합니다."
L["Threat sound"] = "위협 소리"
L["The sound that will be played when your threat percentage reaches a certain point."] = "당신의 위협 수준이 특정 지점에 도달했을때 소리를 재생합니다."
L["Threat threshold"] = "위협 경계"
L["When your threat reaches this level, relative to tank, warnings are shown."] = "탱커와 비교하여 위협 수준이 해당 레벨에 도달하면 경고를 표시합니다."

L["Enables the title bar."] = "제목 표시줄을 활성화 합니다."

L["Total healing"] = "총 치유량"

L["Skada Menu"] = "Skada 메뉴"
L["Switch to mode"] = "모드 전환"
L["Report"] = "보고서"
L["Toggle window"] = "창 토글"
L["Configure"] = "설정"
L["Delete segment"] = "세분화 삭제"
L["Keep segment"] = "세분화 유지"
L["Mode"] = "모드"
L["Lines"] = "줄"
L["Channel"] = "채널"
L["Send report"] = "보고서 출력"
L["No mode selected for report."] = "보고서를 위한 모드가 선택되지 않았습니다."
L["Say"] = "일반 대화"
L["Raid"] = "공격대"
L["Party"] = "파티"
L["Guild"] = "길드"
L["Officer"] = "길드 관리자"
L["Self"] = "자신"

L["'s Healing"] = "의 치유"

L["Delete window"] = "창 삭제"
L["Deletes the chosen window."] = "선택 창을 삭제합니다."
L["Choose the window to be deleted."] = "삭제할 창을 선택합니다."
L["Enter the name for the new window."] = "새 창의 이름을 입력합니다."
L["Create window"] = "창 생성"
L["Windows"] = "창"

L["Switch to segment"] = "세분화 전환"
L["Segment"] = "세분화"

L["Whisper"] = "귓속말"

L["No mode or segment selected for report."] = "보고서를 위한 모드나 세분화가 선택되지 않았습니다."
L["Name of recipient"] = "받는 사람의 이름"

L["Resist"] = "저항"
L["Reflect"] = "반사"
L["Parry"] = "무기막기"
L["Immune"] = "면역"
L["Evade"] = "회피"
L["Dodge"] = "회피"
L["Deflect"] = "빗나감"
L["Block"] = "방어"
L["Absorb"] = "흡수"

L["Last fight"] = "마지막 전투"
L["Disable while hidden"] = "미사용시 숨김"
L["Skada will not collect any data when automatically hidden."] = "Skada에서 자료를 수집하지 않을때 자동으로 숨깁니다."

L["Rename window"] = "창 이름 바꾸기"
L["Enter the name for the window."] = "창의 이름을 입력합니다."

L["Bar display"] = "바 표시"
L["Display system"] = "표시 시스템"
L["Choose the system to be used for displaying data in this window."] = "창안에 표시되는 자료에 사용할 시스템을 선택합니다."

L["Hides HPS from the Healing modes."] = "치유 모드에서 HPS를 숨깁니다."
L["Do not show HPS"] = "HPS를 표시하지 않음"

L["Do not show DPS"] = "DPS를 표시하지 않음"
L["Hides DPS from the Damage mode."] = "데미지 모드에서 DPS를 숨깁니다."

L["Class color bars"] = "직업 색상 바"
L["When possible, bars will be colored according to player class."] = "바를 플레이어의 직업 색상으로 표시합니다."
L["Class color text"] = "직업 색상 문자"
L["When possible, bar text will be colored according to player class."] = "바의 문자를 플레이어의 직업 색상으로 표시합니다."

L["Reset"] = "초기화"
L["Show tooltips"] = "툴팁 표시"

L["Shows tooltips with extra information in some modes."] = "일부 모드에 기타 정보를 보여주는 툴팁을 표시합니다."


L["Minimum hit:"] = "최소 타격:"
L["Maximum hit:"] = "최대 타격:"
L["Average hit:"] = "평균 타격:"
L["Absorbs"] = "흡수"
L["'s Absorbs"] = "의 흡수"

L["Do not show TPS"] = "TPS를 표시하지 않음"
L["Do not warn while tanking"] = "탱킹중일땐 경고하지 않음"

L["Hide in PvP"] = "PvP시 숨기기"
L["Hides Skada's window when in Battlegrounds/Arenas."] = "전장/투기장에서 Skada 창 숨기기"

L["Healed players"] = "치유된 플레이어"
L["Healed by"] = "치유량 - "
L["Absorb details"] = "흡수  세부"
L["Spell details"] = "주문 세부"
L["Healing spell list"] = "치유 주문 목록"
L["Healing spell details"] = "치유 주문 세부"
L["Debuff spell list"] = "디버프 주문 목록"







L["Click for"] = "클릭 ->"
L["Shift-Click for"] = "쉬프트-클릭 ->"
L["Control-Click for"] = "콘트롤-클릭 ->"
L["Default"] = "초기값"
L["Top right"] = "상단-우측"
L["Top left"] = "상단-좌측"



L["Position of the tooltips."] = "툴팁의 위치입니다."
L["Tooltip position"] = "툴팁 위치"


L["Shows a button for opening the menu in the window title bar."] = "창 제목 바에 메뉴를 여는 버튼을 표시합니다."
L["Show menu button"] = "메뉴 버튼 표시"



L["Attack"] = "공격"
L["Damage"] = "데미지"
L["Hit"] = "일반"
L["Critical"] = "치명타"
L["Missed"] = "빚맞힘"
L["Resisted"] = "저항"
L["Blocked"] = "방어"
L["Glancing"] = "빗맞음"
L["Crushing"] = "강타"
L["Absorbed"] = "흡수"
L["HPS"] = "HPS"
L["Healing"] = "치유"

L["Overhealing"] = "초과치유"
L["Threat"] = "위협"

L["Announce CC breaking to party"] = "파티에 군중 제어 해제를 알림"
L["Ignore Main Tanks"] = "메인 탱커 무시"
L["%s on %s removed by %s's %s"] = "%3$s-%4$s의 %1$s - %2$s 삭제"
L["%s on %s removed by %s"] = "%3$s의 %1$s - %2$s 삭제"

L["Start new segment"] = "새로운 세부화 시작"
L["Columns"] = "세로(칸)"
L["Overheal"] = "초과치유"
L["Percent"] = "퍼센트"
L["TPS"] = "TPS"

L["%s dies"] = "%s 죽음"
L["Change"] = "변경"
L["Health"] = "체력"

L["Hide in combat"] = "전투중 숨김"
L["Hides Skada's window when in combat."] = "전투중일시 Skada창을 숨깁니다."

L["Tooltips"] = "툴팁"
L["Informative tooltips"] = "정보제공 툴팁"
L["Shows subview summaries in the tooltips."] = "툴팁에 subview 요약을 보여줍니다."
L["Subview rows"] = "subview 열"
L["The number of rows from each subview to show when using informative tooltips."] = "각 subview에서 열 번호를 사용하여 정보를 툴팁을 표시합니다."

L["Damage done"] = "데미지" -- Needs review
L["Active Time"] = "활동 시간" -- Needs review
L["Segment Time"] = "구분 시간" -- Needs review
L["Absorbs and healing"] = "흡수량과 치유량"




L["Show rank numbers"] = "레벨 숫자 표시" -- Needs review


L["Use focus target"] = "주시 대상 사용"
L["Shows threat on focus target, or focus target's target, when available."] = "주시대상 또는 주시 대상의 대상을 사용할 때 위협을 표시합니다."












-- Scroll








-- =================== --
-- damage module lines --
-- =================== --

L["DPS"] = "DPS"


L["Damage on"] = "피해 ->"




L["Damage Taken"] = "받은 피해"
L["Damage from"] = "~으로부터 피해 ->"



L["Enemy damage done"] = "적 피해"
L["Enemy damage taken"] = "적이 받은 피해"

L["%s's Damage"] = "%s 의 데미지"

















L["Damage done per player"] = "플레이어별 받은 피해량"
L["Damage taken per player"] = "플레이어별 입힌 피해량"

-- ================== --
-- auras module lines --
-- ================== --














-- ======================= --
-- interrupts module lines --
-- ======================= --

L["Interrupts"] = "방해"




-- ==================== --
-- failbot module lines --
-- ==================== --

L["Fails"] = "실수"
L["%s's Fails"] = "%s 의 실수"



-- ======================== --
-- improvement module lines --
-- ======================== --








-- =================== --
-- deaths module lines --
-- =================== --

L["Deaths"] = "죽음"
L["%s's Death"] = "%s 의 죽음"

L["Death log"] = "죽음 로그"






-- ==================== --
-- dispels module lines --
-- ==================== --

L["Dispels"] = "해제"









-- ======================= --
-- cc tracker module lines --
-- ======================= --

L["CC"] = "군중 제어"


L["CC Breakers"] = "군중 제어 해제"







-- CC Done:








-- CC Taken








-- ====================== --
-- resurrect module lines --
-- ====================== --













-- ====================== --
-- Avoidance & Mitigation --
-- ====================== --




















