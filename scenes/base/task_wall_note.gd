class_name TaskWallNote
extends PaperSheet

# 拠点の壁の紙（2026-10-04・DECISIONS.md `TK-3`・`TK-13`・PLAN_TASK_MEMO.md §3-2）。
#
# ⚠ まだのタスクを**全部**出す（⚠ 件数で切らない・⚠ 溢れたら紙の中で送る＝`TK-3`）。⚠ 並びは一覧と同じ（`TK-13`）。
# ⚠ 期限を過ぎた・今日が期限のものは判を押す（`TK-13`）。⚠ 行か「ひらく」を押すとタスクの画面へ（⚠ `SceneManager` 経由）。
# ⚠ 紙の大きさは Theme の `Task/wall_*`。⚠ 拠点の画面だけで使う＝scenes/base/（AGENTS.md 置き場のルール）。
# ⚠ 描き直しに await を持たせない（CLAUDE.md 5番＝`remove_child()` してから `queue_free()`）。

const TASK_SCREEN_PATH: String = "res://scenes/base/task_screen.tscn"
const THEME_TYPE: StringName = &"Task"

var _heading: SheetHeading = null
var _list: VBoxContainer = null


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
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var open: Button = UiButton.create_paper_choice("ui_task_wall_open")
	open.name = "OpenTasksButton"
	open.size_flags_horizontal = Control.SIZE_SHRINK_END
	open.pressed.connect(_open_task_screen)
	body.add_child(open)
	GameManager.tasks_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var open_tasks: Array = GameManager.get_open_tasks()
	_heading.right_text = tr("ui_task_count") % open_tasks.size()
	if open_tasks.is_empty():
		_list.add_child(EmptyState.create("ui_task_wall_empty", "ui_task_wall_empty_hint"))
		return
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
		var stamp_key: String = TaskWallNote.due_stamp_key(GameManager.get_task_due_state(task))
		if stamp_key != "":
			var stamp: Stamp = Stamp.new()
			stamp.name = "DueStamp"
			stamp.label_key = stamp_key
			stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(stamp)
		_list.add_child(row)


# 期限の判の字（⚠ タスクの画面と同じ字を使う）。⚠ 判を押さないなら ""。
static func due_stamp_key(due_state: int) -> String:
	match due_state:
		GameManager.TASK_DUE_OVERDUE:
			return "ui_task_due_overdue"
		GameManager.TASK_DUE_TODAY:
			return "ui_task_due_today"
	return ""


func _open_task_screen() -> void:
	SceneManager.change_scene(TASK_SCREEN_PATH)
