class_name TaskWallNote
extends PaperSheet

# 拠点の壁の紙（2026-10-04・DECISIONS.md `TK-3`・`TK-13`・PLAN_TASK_MEMO.md §3-2）。
#
# ⚠ まだのタスクを**全部**出す（⚠ 件数で切らない・⚠ 溢れたら紙の中で送る＝`TK-3`）。⚠ 並びは一覧と同じ（`TK-13`）。
# ⚠ 期限を過ぎた・今日が期限のものは小さい判（`TK-13`）。⚠ 行か「ひらく」を押すとタスクの画面へ（⚠ `SceneManager` 経由）。
# ⚠ 2026-10-05（モック1）：⚠ 見出しの右に赤で「期限切れ 1　今日まで 1」・⚠ 判を小さくして題を切らない・⚠ 下に「下にあと◯件」。
# ⚠ 紙の大きさは Theme の `Task/wall_*`。⚠ 拠点の画面だけで使う＝scenes/base/（AGENTS.md 置き場のルール）。
# ⚠ 描き直しに await を持たせない（CLAUDE.md 5番＝`remove_child()` してから `queue_free()`）。

const TASK_SCREEN_PATH: String = "res://scenes/base/task_screen.tscn"
const THEME_TYPE: StringName = &"Task"

var _heading: SheetHeading = null
var _due_summary: Label = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _more: Label = null


static func create() -> TaskWallNote:
	var note: TaskWallNote = TaskWallNote.new()
	note.name = "TaskWallNote"
	return note


func _ready() -> void:
	custom_minimum_size = Vector2(float(get_theme_constant(&"wall_width", THEME_TYPE)), float(get_theme_constant(&"wall_height", THEME_TYPE)))
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	add_child(body)
	_heading = SheetHeading.new()
	_heading.name = "NoteHeading"
	_heading.title_key = "ui_task_wall_title"
	body.add_child(_heading)
	_due_summary = Label.new()
	_due_summary.name = "DueSummary"
	_due_summary.theme_type_variation = &"ErrorLabel"
	_due_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_heading.add_before_right(_due_summary)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled)
	_scroll.resized.connect(_update_more)
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 行が並び終わると大きさが変わる＝⚠ そのとき数え直す（⚠ 並ぶ前に数えると 0 になる）。
	_list.resized.connect(_update_more)
	_scroll.add_child(_list)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	body.add_child(foot)
	_more = Label.new()
	_more.name = "MoreLabel"
	_more.theme_type_variation = &"CaptionLabel"
	_more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_more)
	var open: Button = UiButton.create_paper_choice("ui_task_wall_open")
	open.name = "OpenTasksButton"
	open.pressed.connect(_open_task_screen)
	foot.add_child(open)
	GameManager.tasks_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var open_tasks: Array = GameManager.get_open_tasks()
	_heading.right_text = tr("ui_task_count") % open_tasks.size()
	var overdue: int = 0
	var today: int = 0
	for raw: Variant in open_tasks:
		match GameManager.get_task_due_state(raw as Dictionary):
			GameManager.TASK_DUE_OVERDUE:
				overdue += 1
			GameManager.TASK_DUE_TODAY:
				today += 1
	var summary: Array[String] = []
	if overdue > 0:
		summary.append(tr("ui_task_summary_overdue") % overdue)
	if today > 0:
		summary.append(tr("ui_task_summary_today") % today)
	_due_summary.text = tr("ui_task_note_separator").join(summary)
	_due_summary.visible = not summary.is_empty()
	if open_tasks.is_empty():
		_list.add_child(EmptyState.create("ui_task_wall_empty", "ui_task_wall_empty_hint"))
	for raw: Variant in open_tasks:
		var task: Dictionary = raw as Dictionary
		var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
		var row: LedgerRow = LedgerRow.new()
		row.name = "Note_" + task_id
		row.compact = true
		row.pressed.connect(_open_task_screen)
		var line: HBoxContainer = HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		line.add_child(TaskColorMark.create(int(task.get(GameStateKeys.TASK_COLOR, 0))))
		var title: Label = Label.new()
		title.name = "TitleLabel"
		title.text = str(task.get(GameStateKeys.TASK_TITLE, ""))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(title)
		var stamp: Stamp = TaskParts.due_stamp(task)
		if stamp != null:
			line.add_child(stamp)
		_list.add_child(row)
	_update_more.call_deferred()


func _on_scrolled(_value: float) -> void:
	_update_more()


# 「下にあと◯件」＝送りの下に隠れている行の数（⚠ 0 なら出さない）。
func _update_more() -> void:
	if _list == null or not is_inside_tree():
		return
	var bottom: float = float(_scroll.scroll_vertical) + _scroll.size.y
	var hidden: int = 0
	for row: Node in _list.get_children():
		if row is LedgerRow and (row as Control).position.y + (row as Control).size.y * 0.5 > bottom:
			hidden += 1
	_more.text = tr("ui_task_wall_more") % hidden if hidden > 0 else ""


func _open_task_screen() -> void:
	SceneManager.change_scene(TASK_SCREEN_PATH)
