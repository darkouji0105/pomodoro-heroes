class_name TaskDetailPanel
extends VBoxContainer

# タスクを詳しく決める紙の中身（2026-10-05・人間「⚠ 詳しいこともポモドーロ中に決められるように」）。
#
# ⚠ 前はタスクの画面の右の紙（`task_screen.gd`）が持っていた。⚠ ポモドーロのサイドバーの「詳しく」の窓でも同じものを使う。
# ⚠ 決められるもの（`TK-7`）：⚠ 名前 ／ 期限（なし・今日・明日・今週中・日付を選ぶ＝カレンダー・`TK-17`）／ 色（`TK-12`）／ メモ ／ タグ。
#   ⚠ 下に「これまでの集中」（`TK-5`）と ⚠ 「このタスクを消す」（`show_delete`＝タスクの画面だけ。⚠ 消すのは確かめの窓を挟む＝持ち主が `delete_requested` を受ける）。
# ⚠ 名前とメモは打つたびに書く（⚠ 打っている欄は描き直さない）。⚠ 期限・色・タグは書いたら次のフレームで描き直す。
# ⚠ 書き換えは全部 `GameManager` の口。⚠ 再描画に await を持たせない（CLAUDE.md 5番）。
# ⚠ タスクの画面とポモドーロで使う＝scenes/ui/components/（AGENTS.md）。⚠ `.new()` で作る。

signal delete_requested(task_id: String)

const THEME_TYPE: StringName = &"Task"

# ⚠ 「このタスクを消す」を出すか（⚠ 窓の上に確かめの窓は重ねられない＝窓の中では出さない）。
var show_delete: bool = true
# ⚠ 中の送りの高さ（⚠ 0 なら広がる＝タスクの画面の紙。⚠ 窓では決めた高さ）。
var scroll_height: float = 0.0

var _task_id: String = ""
var _calendar: TaskCalendar = null
var _body: VBoxContainer = null
var _dirty: bool = false


static func create(task_id: String, p_show_delete: bool = true, p_scroll_height: float = 0.0) -> TaskDetailPanel:
	var panel: TaskDetailPanel = TaskDetailPanel.new()
	panel.name = "TaskDetailPanel"
	panel._task_id = task_id
	panel.show_delete = p_show_delete
	panel.scroll_height = p_scroll_height
	return panel


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_calendar = TaskCalendar.new()
	_calendar.date_picked.connect(_on_calendar_picked)
	add_child(_calendar)
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_body)
	_rebuild()


func get_task_id() -> String:
	return _task_id


# 別のタスクを出す（⚠ "" なら「左のタスクを押すと」の案内）。
func set_task(task_id: String) -> void:
	_task_id = task_id
	queue_rebuild()


func queue_rebuild() -> void:
	if _dirty:
		return
	_dirty = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_dirty = false
	if _body == null or not is_inside_tree():
		return
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var task: Dictionary = GameManager.get_task(_task_id)
	if task.is_empty():
		_task_id = ""
		var none: Label = _caption("ui_task_detail_none")
		none.name = "DetailNone"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(none)
		return
	var task_id: String = _task_id
	# ⚠ 中は送る（⚠ 紙を縦 720 に収める）。⚠ 下の「これまでの集中」と「消す」は送りの外。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if scroll_height > 0.0:
		scroll.custom_minimum_size.y = scroll_height
	else:
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	var fields: VBoxContainer = VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(fields)
	fields.add_child(_caption("ui_task_field_title"))
	var title_edit: LineEdit = LineEdit.new()
	title_edit.name = "TitleEdit"
	title_edit.max_length = Balance.pomodoro.session_title_max_length
	title_edit.text = str(task.get(GameStateKeys.TASK_TITLE, ""))
	title_edit.text_changed.connect(_on_title_changed.bind(task_id))
	fields.add_child(title_edit)
	fields.add_child(_due_line(task))
	fields.add_child(_due_choices(task))
	fields.add_child(_caption("ui_task_field_color"))
	fields.add_child(_color_row(task))
	fields.add_child(_caption("ui_task_field_memo"))
	var memo: TextEdit = TextEdit.new()
	memo.name = "MemoEdit"
	memo.custom_minimum_size.y = float(get_theme_constant(&"memo_height", THEME_TYPE))
	memo.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	memo.placeholder_text = tr("ui_task_memo_placeholder")
	memo.text = str(task.get(GameStateKeys.TASK_MEMO, ""))
	memo.text_changed.connect(_on_memo_changed.bind(memo, task_id))
	fields.add_child(memo)
	fields.add_child(_tag_row(task))
	# ⚠ 下：これまでの集中（`TK-5`＝時間）・消す（`TK-15`・赤）。
	_body.add_child(HSeparator.new())
	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "FootRow"
	var total: Label = Label.new()
	total.name = "FocusTotalLabel"
	total.text = tr("ui_task_focus_total") % GameManager.task_focus_text(int(task.get(GameStateKeys.TASK_FOCUS_SEC, 0)))
	total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(total)
	if show_delete:
		var delete: UiButton = UiButton.create(UiButton.Variant.DANGER, "ui_task_delete_this")
		delete.name = "DeleteButton"
		delete.pressed.connect(_on_delete_pressed.bind(task_id))
		foot.add_child(delete)
	_body.add_child(foot)


func _caption(key: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"CaptionLabel"
	label.text = tr(key)
	return label


func _row_caption(label_name: String, text: String) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.theme_type_variation = &"CaptionLabel"
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _on_title_changed(text: String, task_id: String) -> void:
	var _renamed: bool = GameManager.rename_task(task_id, text)


func _on_memo_changed(memo: TextEdit, task_id: String) -> void:
	var _written: bool = GameManager.set_task_memo(task_id, memo.text)


# 期限の行：⚠ 「期限　10/03（土）」＋ ⚠ 判（期限切れ・今日まで）か「あと n日」。
func _due_line(task: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "DueRow"
	var caption: Label = _caption("ui_task_field_due")
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var due: String = str(task.get(GameStateKeys.TASK_DUE, ""))
	var value: Label = Label.new()
	value.name = "DueLabel"
	value.text = TaskParts.long_date(due) if due != "" else tr("ui_task_due_none")
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	var stamp: Stamp = TaskParts.due_stamp(task)
	if stamp != null:
		row.add_child(stamp)
	elif due != "":
		row.add_child(_row_caption("DaysLeftLabel", tr("ui_task_days_left") % TaskParts.days_from_today(due)))
	return row


# 期限の札（モック3）：⚠ なし ／ 今日 ／ 明日 ／ 今週中（⚠ 設定の「週の終わりの日」＝`TK-17`）／ 日付を選ぶ ▼（カレンダー）。
func _due_choices(task: Dictionary) -> HFlowContainer:
	var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
	var due: String = str(task.get(GameStateKeys.TASK_DUE, ""))
	var today: String = GameDate.get_game_date_string()
	var box: HFlowContainer = HFlowContainer.new()
	box.name = "DueChoices"
	for spec: Array in [
		["DueNone", "ui_task_due_none", ""],
		["DueToday", "ui_task_due_set_today", today],
		["DueTomorrow", "ui_task_due_tomorrow", TaskParts.shift_date(today, 1)],
		["DueWeek", "ui_task_due_week", TaskParts.week_end_date()],
	]:
		var button: Button = UiButton.create_paper_choice(str(spec[1]))
		button.name = str(spec[0])
		if str(spec[2]) == due:
			button.theme_type_variation = &"PaperChoiceSelected"
		button.pressed.connect(_on_due_pressed.bind(task_id, str(spec[2])))
		box.add_child(button)
	var pick: Button = UiButton.create_paper_choice("ui_task_due_pick")
	pick.name = "DuePick"
	pick.pressed.connect(_on_due_pick_pressed.bind(pick, due))
	box.add_child(pick)
	return box


func _on_due_pressed(task_id: String, due: String) -> void:
	if GameManager.set_task_due(task_id, due):
		queue_rebuild()


func _on_due_pick_pressed(anchor: Control, due: String) -> void:
	_calendar.open_under(anchor, due)


func _on_calendar_picked(date: String) -> void:
	_on_due_pressed(_task_id, date)


# 色（`TK-12`）：⚠ 決まった色から1つ（⚠ 数は Config）。⚠ 選んでいる札は `PaperChoiceSelected`。
func _color_row(task: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ColorRow"
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
		button.custom_minimum_size = Vector2(float(swatch), float(swatch)) * 1.4
		button.pressed.connect(_on_color_pressed.bind(str(task.get(GameStateKeys.TASK_ID, "")), i))
		row.add_child(button)
	return row


func _on_color_pressed(task_id: String, color: int) -> void:
	if GameManager.set_task_color(task_id, color):
		queue_rebuild()


# タグ（`TK-12`）：⚠ 自由に打てる・複数。⚠ 札を押すと外す。⚠ 札と打つ欄を1行に流す（モック2）。
func _tag_row(task: Dictionary) -> VBoxContainer:
	var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "TagRow"
	box.add_child(_caption("ui_task_field_tags"))
	var line: HFlowContainer = HFlowContainer.new()
	line.name = "TagChips"
	box.add_child(line)
	for tag: Variant in task.get(GameStateKeys.TASK_TAGS, []):
		var chip: Button = UiButton.create_paper_choice("")
		chip.name = "Tag_" + str(tag)
		chip.text = tr("ui_task_tag_remove") % str(tag)
		chip.pressed.connect(_on_tag_remove_pressed.bind(task_id, str(tag)))
		line.add_child(chip)
	var edit: LineEdit = LineEdit.new()
	edit.name = "TagEdit"
	edit.placeholder_text = tr("ui_task_tag_placeholder")
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size.x = 200.0
	edit.text_submitted.connect(_on_tag_submitted.bind(edit, task_id))
	line.add_child(edit)
	var add: Button = UiButton.create_paper_choice("ui_task_add")
	add.name = "AddTagButton"
	add.pressed.connect(_on_tag_add_pressed.bind(edit, task_id))
	line.add_child(add)
	return box


func _on_tag_submitted(_text: String, edit: LineEdit, task_id: String) -> void:
	_on_tag_add_pressed(edit, task_id)


func _on_tag_add_pressed(edit: LineEdit, task_id: String) -> void:
	if GameManager.add_task_tag(task_id, edit.text):
		queue_rebuild()


func _on_tag_remove_pressed(task_id: String, tag: String) -> void:
	if GameManager.remove_task_tag(task_id, tag):
		queue_rebuild()


func _on_delete_pressed(task_id: String) -> void:
	delete_requested.emit(task_id)
