# res://scenes/base/task_screen.gd
# タスクの画面（2026-10-04・DECISIONS.md `TK-1`〜`TK-13`・PLAN_TASK_MEMO.md §3-2）。
#
# ⚠ 左の紙＝一覧（足す・チェック・並べ替え・タグで絞る）／ ⚠ 右の紙＝選んだタスクを詳しく（名前・メモ・期限・色・タグ）。
#   ⚠ 決められるのは メモ ／ 期限 ／ 並べる順 ／ 色・タグ（`TK-7`）。⚠ 見込みのポモドーロ数は入れない。
# ⚠ 終えたタスクはその日のうちは線を引いて残る（`TK-6`）。⚠ 朝4:00 の移しは開いたときに走らせる。
# ⚠ 期限を過ぎた・今日が期限のものは判（`TK-13`）。⚠ 並びは自分で決めた順のまま。
# ⚠ 入口は拠点の壁の紙（`TK-3`）。⚠ 「戻る」で拠点。⚠ 書き換えは全部 `GameManager` の口（⚠ ここで TASKS を触らない）。
# ⚠ 再描画に await を持たせない（CLAUDE.md 5番）。⚠ 押した札を押している最中に外さない＝⚠ 描き直しは次のフレーム。

class_name TaskScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const THEME_TYPE: StringName = &"Task"
const SECONDS_PER_DAY: int = 86400

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var list_sheet: PaperSheet = $Margin/Layout/Main/ListSheet
@onready var list_body: VBoxContainer = $Margin/Layout/Main/ListSheet/ListBody
@onready var detail_sheet: PaperSheet = $Margin/Layout/Main/DetailSheet
@onready var detail_body: VBoxContainer = $Margin/Layout/Main/DetailSheet/DetailBody

var _selected_id: String = ""
# ⚠ 絞り込みのタグ（⚠ "" なら全部・`TK-12`）。
var _filter_tag: String = ""
var _list_heading: SheetHeading = null
var _new_edit: LineEdit = null
var _filter_box: HFlowContainer = null
var _list: VBoxContainer = null
var _list_dirty: bool = false
var _detail_dirty: bool = false


func _ready() -> void:
	SceneManager.consume_transfer_data()
	var _moved: int = GameManager.roll_over_done_tasks()
	header.back_pressed.connect(_on_back_pressed)
	list_sheet.custom_minimum_size.x = float(get_theme_constant(&"list_width", THEME_TYPE))
	detail_sheet.custom_minimum_size.x = float(get_theme_constant(&"detail_width", THEME_TYPE))
	_build_list_frame()
	GameManager.tasks_changed.connect(_on_tasks_changed)
	_rebuild_list()
	_rebuild_detail()


# --- 左：一覧 ----------------------------------------------------------------

# ⚠ 動かない部分（見出し・足す行・絞り込みの置き場・送りの器）。⚠ 描き直すのは中身だけ。
func _build_list_frame() -> void:
	_list_heading = SheetHeading.new()
	_list_heading.name = "ListHeading"
	_list_heading.title_key = "ui_task_list_title"
	list_body.add_child(_list_heading)
	var add_row: HBoxContainer = HBoxContainer.new()
	add_row.name = "AddRow"
	list_body.add_child(add_row)
	_new_edit = LineEdit.new()
	_new_edit.name = "NewTaskEdit"
	_new_edit.max_length = Balance.pomodoro.session_title_max_length
	_new_edit.placeholder_text = tr("ui_task_new_placeholder")
	_new_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_edit.text_submitted.connect(_on_new_submitted)
	add_row.add_child(_new_edit)
	var add_button: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_task_add")
	add_button.name = "AddTaskButton"
	add_button.pressed.connect(_on_add_pressed)
	add_row.add_child(add_button)
	_filter_box = HFlowContainer.new()
	_filter_box.name = "TagFilter"
	list_body.add_child(_filter_box)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func _on_tasks_changed() -> void:
	_queue_list()


func _queue_list() -> void:
	if _list_dirty:
		return
	_list_dirty = true
	_rebuild_list.call_deferred()


func _queue_detail() -> void:
	if _detail_dirty:
		return
	_detail_dirty = true
	_rebuild_detail.call_deferred()


func _rebuild_list() -> void:
	_list_dirty = false
	if not is_inside_tree():
		return
	var tasks: Array = GameManager.get_tasks()
	var tags: Array[String] = GameManager.get_task_tags()
	if _filter_tag != "" and not (_filter_tag in tags):
		_filter_tag = ""
	_list_heading.right_text = tr("ui_task_count") % GameManager.get_open_tasks().size()
	_rebuild_filter(tags)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if tasks.is_empty():
		_list.add_child(EmptyState.create("ui_task_list_empty", "ui_task_list_empty_hint"))
		return
	for i: int in range(tasks.size()):
		var task: Dictionary = tasks[i] as Dictionary
		if _filter_tag != "" and not (_filter_tag in (task.get(GameStateKeys.TASK_TAGS, []) as Array)):
			continue
		_list.add_child(_task_row(task, i == 0, i == tasks.size() - 1))


# 絞り込みの札（⚠ 全部 ＋ 一覧に出てくるタグ）。⚠ タグが1つも無ければ出さない。
func _rebuild_filter(tags: Array[String]) -> void:
	for child: Node in _filter_box.get_children():
		_filter_box.remove_child(child)
		child.queue_free()
	_filter_box.visible = not tags.is_empty()
	if tags.is_empty():
		return
	var all: Button = UiButton.create_paper_choice("ui_task_filter_all")
	all.name = "Filter_all"
	if _filter_tag == "":
		all.theme_type_variation = &"PaperChoiceSelected"
	all.pressed.connect(_on_filter_pressed.bind(""))
	_filter_box.add_child(all)
	for tag: String in tags:
		var choice: Button = UiButton.create_paper_choice("")
		choice.name = "Filter_" + tag
		choice.text = tr("ui_task_tag") % tag
		if tag == _filter_tag:
			choice.theme_type_variation = &"PaperChoiceSelected"
		choice.pressed.connect(_on_filter_pressed.bind(tag))
		_filter_box.add_child(choice)


func _task_row(task: Dictionary, is_first: bool, is_last: bool) -> LedgerRow:
	var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
	var done: bool = int(task.get(GameStateKeys.TASK_DONE_AT, 0)) != 0
	var row: LedgerRow = LedgerRow.new()
	row.name = "Task_" + task_id
	row.compact = true
	row.selected = task_id == _selected_id
	row.pressed.connect(_on_row_pressed.bind(task_id))
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	# ⚠ 終わったかは自分でチェック（`TK-4`）。
	var check: CheckBox = CheckBox.new()
	check.name = "DoneCheck"
	check.button_pressed = done
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.toggled.connect(_on_done_toggled.bind(task_id))
	line.add_child(check)
	line.add_child(TaskColorMark.create(int(task.get(GameStateKeys.TASK_COLOR, 0))))
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(column)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = str(task.get(GameStateKeys.TASK_TITLE, ""))
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if done:
		# ⚠ 終えたものは薄墨＋線（`TK-6`）。
		title.theme_type_variation = &"TaskDoneLabel"
		title.draw.connect(_draw_strike.bind(title))
	column.add_child(title)
	var note: String = _row_note(task)
	if note != "":
		var caption: Label = Label.new()
		caption.name = "NoteLabel"
		caption.theme_type_variation = &"CaptionLabel"
		caption.text = note
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(caption)
	var stamp_key: String = TaskWallNote.due_stamp_key(GameManager.get_task_due_state(task))
	if stamp_key != "":
		var stamp: Stamp = Stamp.new()
		stamp.name = "DueStamp"
		stamp.label_key = stamp_key
		stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(stamp)
	# ⚠ 並べ替え（`TK-7`）。⚠ 絞っているときは押せない（⚠ 見えていない行と入れ替わるため）。
	for spec: Array in [["UpButton", "ui_task_move_up", -1, is_first], ["DownButton", "ui_task_move_down", 1, is_last]]:
		var move: Button = UiButton.create_paper_choice(str(spec[1]))
		move.name = str(spec[0])
		move.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		move.disabled = bool(spec[3]) or _filter_tag != ""
		move.pressed.connect(_on_move_pressed.bind(task_id, int(spec[2])))
		line.add_child(move)
	return row


# 行の下の小さな字：⚠ 期限 ・ タグ ・ 🍅の数（⚠ 0 なら出さない）。
func _row_note(task: Dictionary) -> String:
	var parts: Array[String] = []
	var due: String = str(task.get(GameStateKeys.TASK_DUE, ""))
	if due != "":
		parts.append(tr("ui_task_due_short") % due)
	for tag: Variant in task.get(GameStateKeys.TASK_TAGS, []):
		parts.append(tr("ui_task_tag") % str(tag))
	var count: int = int(task.get(GameStateKeys.TASK_POMODORO_COUNT, 0))
	if count > 0:
		parts.append(tr("ui_task_pomodoro_count") % count)
	return tr("ui_task_note_separator").join(parts)


func _draw_strike(label: Label) -> void:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var width: float = minf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, label.size.x)
	var y: float = label.size.y * 0.5
	label.draw_line(Vector2(0.0, y), Vector2(width, y), label.get_theme_color(&"font_color"), float(get_theme_constant(&"strike", THEME_TYPE)))


func _on_new_submitted(_text: String) -> void:
	_on_add_pressed()


func _on_add_pressed() -> void:
	var task_id: String = GameManager.add_task(_new_edit.text)
	if task_id == "":
		return
	_new_edit.text = ""
	_selected_id = task_id
	_queue_detail()


func _on_row_pressed(task_id: String) -> void:
	if task_id == _selected_id:
		return
	_selected_id = task_id
	_queue_list()
	_queue_detail()


func _on_done_toggled(pressed: bool, task_id: String) -> void:
	var _changed: bool = GameManager.set_task_done(task_id, pressed)


func _on_move_pressed(task_id: String, delta: int) -> void:
	var _moved: bool = GameManager.move_task(task_id, delta)


func _on_filter_pressed(tag: String) -> void:
	if tag == _filter_tag:
		return
	_filter_tag = tag
	_queue_list()


# --- 右：詳しく ----------------------------------------------------------------

func _rebuild_detail() -> void:
	_detail_dirty = false
	if not is_inside_tree():
		return
	for child: Node in detail_body.get_children():
		detail_body.remove_child(child)
		child.queue_free()
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "DetailHeading"
	heading.title_key = "ui_task_detail_title"
	heading.ornament = true
	detail_body.add_child(heading)
	var task: Dictionary = GameManager.get_task(_selected_id)
	if task.is_empty():
		_selected_id = ""
		var none: Label = Label.new()
		none.name = "DetailNone"
		none.theme_type_variation = &"CaptionLabel"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.text = tr("ui_task_detail_none")
		detail_body.add_child(none)
		return
	var task_id: String = _selected_id
	# ⚠ 名前とメモは打つたびに書く（⚠ 右の紙は描き直さない＝打っている欄を消さない）。
	detail_body.add_child(_caption("ui_task_field_title"))
	var title_edit: LineEdit = LineEdit.new()
	title_edit.name = "TitleEdit"
	title_edit.max_length = Balance.pomodoro.session_title_max_length
	title_edit.text = str(task.get(GameStateKeys.TASK_TITLE, ""))
	title_edit.text_changed.connect(_on_title_changed.bind(task_id))
	detail_body.add_child(title_edit)
	detail_body.add_child(_caption("ui_task_field_memo"))
	var memo: TextEdit = TextEdit.new()
	memo.name = "MemoEdit"
	memo.custom_minimum_size.y = float(get_theme_constant(&"memo_height", THEME_TYPE))
	memo.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	memo.placeholder_text = tr("ui_task_memo_placeholder")
	memo.text = str(task.get(GameStateKeys.TASK_MEMO, ""))
	memo.text_changed.connect(_on_memo_changed.bind(memo, task_id))
	detail_body.add_child(memo)
	detail_body.add_child(_due_row(task))
	detail_body.add_child(_color_row(task))
	detail_body.add_child(_tag_row(task))
	var count: Label = Label.new()
	count.name = "PomodoroCountLabel"
	count.theme_type_variation = &"CaptionLabel"
	count.text = tr("ui_task_pomodoro_total") % int(task.get(GameStateKeys.TASK_POMODORO_COUNT, 0))
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# ⚠ 消す（2026-10-04・`TK-15`）。⚠ 取り返しがつかない＝赤（`MD-5`）・確かめの窓を挟む。
	#   ⚠ ポモドーロの回数と同じ行（⚠ 行を増やすと紙が縦 720 に収まらず、画面ごと上へ押し上がった＝撮った絵）。
	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "FootRow"
	foot.add_child(count)
	var delete: UiButton = UiButton.create(UiButton.Variant.DANGER, "ui_task_delete")
	delete.name = "DeleteButton"
	delete.pressed.connect(_on_delete_pressed.bind(task_id))
	foot.add_child(delete)
	detail_body.add_child(foot)


func _caption(key: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"CaptionLabel"
	label.text = tr(key)
	return label


func _on_title_changed(text: String, task_id: String) -> void:
	var _renamed: bool = GameManager.rename_task(task_id, text)


func _on_memo_changed(memo: TextEdit, task_id: String) -> void:
	var _written: bool = GameManager.set_task_memo(task_id, memo.text)


# 期限（`TK-7`）：⚠ 日付 ／ なし ／ 今日 ／ −1日 ／ ＋1日。⚠ 期限なしから −1・＋1 を押すと今日から数える。
func _due_row(task: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "DueRow"
	var caption: Label = _caption("ui_task_field_due")
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var due: String = str(task.get(GameStateKeys.TASK_DUE, ""))
	var value: Label = Label.new()
	value.name = "DueLabel"
	value.text = due if due != "" else tr("ui_task_due_none")
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	var today: String = GameDate.get_game_date_string()
	var base: String = due if due != "" else today
	for spec: Array in [
		["DueNone", "ui_task_due_none", ""],
		["DueToday", "ui_task_due_set_today", today],
		["DueMinus", "ui_task_due_minus", _shift_date(base, -1)],
		["DuePlus", "ui_task_due_plus", _shift_date(base, 1)],
	]:
		var button: Button = UiButton.create_paper_choice(str(spec[1]))
		button.name = str(spec[0])
		button.pressed.connect(_on_due_pressed.bind(str(task.get(GameStateKeys.TASK_ID, "")), str(spec[2])))
		row.add_child(button)
	return row


static func _shift_date(date: String, days: int) -> String:
	var unix: int = Time.get_unix_time_from_datetime_string(date + "T12:00:00") + days * SECONDS_PER_DAY
	return Time.get_date_string_from_unix_time(unix)


func _on_due_pressed(task_id: String, due: String) -> void:
	if GameManager.set_task_due(task_id, due):
		_queue_detail()


# 色（`TK-12`）：⚠ 決まった色から1つ（⚠ 数は Config）。⚠ 選んでいる札は `PaperChoiceSelected`。
func _color_row(task: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ColorRow"
	var caption: Label = _caption("ui_task_field_color")
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var current: int = int(task.get(GameStateKeys.TASK_COLOR, 0))
	var swatch: int = get_theme_constant(&"swatch", THEME_TYPE)
	for i: int in range(GameManager.get_task_color_count()):
		var button: Button = UiButton.create_paper_choice("")
		button.name = "Color_%d" % i
		button.tooltip_text = tr("ui_task_color_%d" % i)
		if i == current:
			button.theme_type_variation = &"PaperChoiceSelected"
		# ⚠ ボタンは器ではない＝⚠ 真ん中に置く器を全面に敷いて、その中に丸。
		var center: CenterContainer = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(TaskColorMark.create(i, swatch))
		button.add_child(center)
		button.custom_minimum_size = Vector2(float(swatch), float(swatch)) * 1.5
		button.pressed.connect(_on_color_pressed.bind(str(task.get(GameStateKeys.TASK_ID, "")), i))
		row.add_child(button)
	return row


func _on_color_pressed(task_id: String, color: int) -> void:
	if GameManager.set_task_color(task_id, color):
		_queue_detail()


# タグ（`TK-12`）：⚠ 自由に打てる・複数。⚠ 札を押すと外す。
func _tag_row(task: Dictionary) -> VBoxContainer:
	var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "TagRow"
	box.add_child(_caption("ui_task_field_tags"))
	var chips: HFlowContainer = HFlowContainer.new()
	chips.name = "TagChips"
	box.add_child(chips)
	for tag: Variant in task.get(GameStateKeys.TASK_TAGS, []):
		var chip: Button = UiButton.create_paper_choice("")
		chip.name = "Tag_" + str(tag)
		chip.text = tr("ui_task_tag_remove") % str(tag)
		chip.pressed.connect(_on_tag_remove_pressed.bind(task_id, str(tag)))
		chips.add_child(chip)
	var add_line: HBoxContainer = HBoxContainer.new()
	box.add_child(add_line)
	var edit: LineEdit = LineEdit.new()
	edit.name = "TagEdit"
	edit.placeholder_text = tr("ui_task_tag_placeholder")
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_submitted.connect(_on_tag_submitted.bind(edit, task_id))
	add_line.add_child(edit)
	var add: Button = UiButton.create_paper_choice("ui_task_tag_add")
	add.name = "AddTagButton"
	add.pressed.connect(_on_tag_add_pressed.bind(edit, task_id))
	add_line.add_child(add)
	return box


func _on_tag_submitted(_text: String, edit: LineEdit, task_id: String) -> void:
	_on_tag_add_pressed(edit, task_id)


func _on_tag_add_pressed(edit: LineEdit, task_id: String) -> void:
	if GameManager.add_task_tag(task_id, edit.text):
		_queue_detail()


func _on_tag_remove_pressed(task_id: String, tag: String) -> void:
	if GameManager.remove_task_tag(task_id, tag):
		_queue_detail()


# ⚠ 状態を触るのは「消す」を押したあと（CLAUDE.md 6番）。⚠ 窓を待つ間に画面を離れたら何もしない。
func _on_delete_pressed(task_id: String) -> void:
	var title: String = str(GameManager.get_task(task_id).get(GameStateKeys.TASK_TITLE, ""))
	var ok: bool = await Modal.confirm(self, "ui_task_delete_confirm", [title], false, {
		Modal.OPTION_TITLE: tr("ui_task_delete"),
		Modal.OPTION_DANGER: true,
		Modal.OPTION_CONFIRM_LABEL: "ui_task_delete",
	})
	if not ok or not is_inside_tree():
		return
	if GameManager.delete_task(task_id) and task_id == _selected_id:
		_selected_id = ""
		_queue_detail()


func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
