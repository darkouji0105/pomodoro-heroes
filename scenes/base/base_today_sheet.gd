class_name BaseTodaySheet
extends PaperSheet

# 本部の机の「今日の紙」（2026-10-07・回HB-1・`NAV-21`・人間「⚠ ５あ」）。
#
# ⚠⚠ 10-18（回UI-1018-6・web版の手本 `05_base_desk.png`・`NAV-34`）：⚠ 机の左の1枚に**まとめた**。
#   ⚠ 上から：⚠ 見出し（今日の日付）／ ⚠ 今日の集中（⚠ 1日の目標があれば「◯ / ◯ 分」と棒）／ ⚠ やること（`TaskWallNote`）／ ⚠ 知らせ。
# ⚠⚠ 10-19（回SEE29-B・`NAV-36`・人間「⚠ ３ア」）：⚠ 「知らせ」の欄はメールボックス（`MailboxWindow`）へ移した＝⚠ 空いたぶん「やること」が広がる。
#   ⚠ 用事の一覧（`current_errands()`）はここに残す（⚠ メールボックスの「いまの用事」が引く）。
# ⚠ 知らせ＝用事のある施設（⚠ 1行＝1つの用事。⚠ 押すとその画面へ）。
#   ⚠ 用事の判定は帯のしおり紐と**同じ口**（`BaseFacilityBar.attention_of()`）＝⚠ ここに2本目を書かない。
#   ⚠ 帯の紐が「どこに用事があるか」、⚠ この紙が「何の用事か」を読ませる。
# ⚠ 大きさは Theme の `BaseDesk` 型。⚠ 拠点の画面だけで使う＝scenes/base/（AGENTS.md 置き場のルール）。
# ⚠ 描き直しに await を持たせない（CLAUDE.md 5番＝`remove_child()` してから `queue_free()`）。

const THEME_TYPE: StringName = &"BaseDesk"
const KEY_ID: String = "id"
const KEY_TEXT: String = "text"
const KEY_PATH: String = "path"

# ⚠ 並び＝帯の並び。⚠ 鍛冶場の用事は作業場の完成＝「作る」タブ（作業場の画面）へ。
static func errands() -> Array[Dictionary]:
	return [
		{KEY_ID: BaseFacilityBar.HQ, KEY_TEXT: "ui_base_today_hq", KEY_PATH: "res://scenes/base/chest_screen.tscn"},
		{KEY_ID: BaseFacilityBar.TRAINING, KEY_TEXT: "ui_base_today_training", KEY_PATH: "res://scenes/guild/training_list_screen.tscn"},
		{KEY_ID: BaseFacilityBar.FORGE, KEY_TEXT: "ui_base_today_forge", KEY_PATH: "res://scenes/guild/workshop_screen.tscn"},
		{KEY_ID: BaseFacilityBar.RESEARCH, KEY_TEXT: "ui_base_today_research", KEY_PATH: "res://scenes/guild/research_screen.tscn"},
		{KEY_ID: BaseFacilityBar.BELONGINGS, KEY_TEXT: "ui_base_today_belongings", KEY_PATH: "res://scenes/guild/warehouse_screen.tscn"},
		{KEY_ID: BaseFacilityBar.SHOP, KEY_TEXT: "ui_base_today_shop", KEY_PATH: "res://scenes/guild/shop_screen.tscn"},
	]


static func create() -> BaseTodaySheet:
	var sheet: BaseTodaySheet = BaseTodaySheet.new()
	sheet.name = "TodaySheet"
	return sheet


func _ready() -> void:
	custom_minimum_size.x = float(get_theme_constant(&"today_width", THEME_TYPE))
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	add_child(body)
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "TodayHeading"
	heading.title_key = "ui_base_today_title"
	heading.right_text = TaskParts.long_date(GameDate.get_game_date_string())
	body.add_child(heading)
	_add_focus(body)
	var note: TaskWallNote = TaskWallNote.create()
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(note)


# ⚠ 今日の集中（⚠ 1日の目標＝設定の `daily_goal_minutes`・0 なら棒を出さない）。
func _add_focus(body: VBoxContainer) -> void:
	var minutes: int = GameManager.get_cumulative_focus_minutes_today()
	var goal: int = GameSettings.daily_goal_minutes()
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "FocusRow"
	body.add_child(row)
	var caption: Label = Label.new()
	caption.text = tr("ui_records_focus_today")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(caption)
	var big: Label = Label.new()
	big.name = "FocusMinutes"
	big.theme_type_variation = &"DeskBigNumberLabel"
	big.text = str(minutes)
	row.add_child(big)
	var unit: Label = Label.new()
	unit.theme_type_variation = &"CaptionLabel"
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	unit.text = tr("ui_hq_focus_goal") % goal if goal > 0 else tr("ui_hq_focus_unit")
	row.add_child(unit)
	if goal <= 0:
		return
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "FocusGoalBar"
	bar.theme_type_variation = &"DeskGoalBar"
	bar.show_percentage = false
	bar.max_value = float(goal)
	bar.value = float(mini(minutes, goal))
	body.add_child(bar)


# ⚠ いま出す用事（⚠ 検査からも引く）。
static func current_errands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in errands():
		var id: String = str(entry[KEY_ID])
		if BaseFacilityBar.is_open(id) and BaseFacilityBar.attention_of(id):
			result.append(entry)
	return result
